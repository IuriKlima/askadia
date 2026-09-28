-- Aquisição gratuita, contratação por empresa e liberação explícita de IA.
-- Checkout exclusivamente simulado; não representa recebimento financeiro.
begin;
alter table public.plan_catalog drop constraint plan_catalog_id_check;
alter table public.plan_catalog add constraint plan_catalog_id_check check(id in ('basic','premium','weekly','askadia_monthly','askadia_annual'));
alter table public.company_subscriptions drop constraint company_subscriptions_plan_id_check;
alter table public.company_subscriptions add constraint company_subscriptions_plan_id_check check(plan_id in ('basic','premium','askadia_monthly','askadia_annual'));
insert into public.plan_catalog(id,name,kind,price_cents,features,quotas) values
 ('askadia_monthly','Askadia Mensal','plan',149700,array['strategy','content','crm','sites','inbox','triage','ads','campaigns','analytics'],'{}'),
 ('askadia_annual','Askadia Anual · 12 parcelas','plan',99800,array['strategy','content','crm','sites','inbox','triage','ads','campaigns','analytics'],'{}');

create table public.company_test_checkouts(
 id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),
 plan_id text not null references public.plan_catalog(id) check(plan_id in ('askadia_monthly','askadia_annual')),
 mode text not null default 'test' check(mode='test'),status text not null default 'pending' check(status in ('pending','test_approved','declined','cancelled')),
 installment_cents integer not null,installments integer not null,total_cents integer not null,
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '30 minutes',resolved_at timestamptz,
 check((plan_id='askadia_monthly' and installment_cents=149700 and installments=1 and total_cents=149700) or (plan_id='askadia_annual' and installment_cents=99800 and installments=12 and total_cents=1197600))
);
create index company_test_checkouts_recent on public.company_test_checkouts(company_id,created_at desc);
create table private.company_test_access(company_id uuid primary key references public.companies(id),checkout_id uuid not null unique references public.company_test_checkouts(id),valid_until timestamptz not null);
revoke all on private.company_test_access from public,anon,authenticated;
create table public.company_setup(company_id uuid primary key references public.companies(id),completed_at timestamptz not null,completed_by uuid not null references public.profiles(id));
alter table public.company_test_checkouts enable row level security;
alter table public.company_setup enable row level security;
revoke all on public.company_test_checkouts,public.company_setup from anon,authenticated;
grant select on public.company_test_checkouts,public.company_setup to authenticated;
create policy checkout_read on public.company_test_checkouts for select to authenticated using(private.can_company_action(company_id,'billing.manage'));
create policy setup_read on public.company_setup for select to authenticated using(private.can_company_action(company_id,'company.read'));

create function private.company_ai_access(c uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.companies where id=c and archived_at is null) and (
 exists(select 1 from public.company_subscriptions where company_id=c and status='active' and current_period_end>now()) or
 exists(select 1 from private.company_test_access t join public.company_test_checkouts x on x.id=t.checkout_id and x.company_id=t.company_id where t.company_id=c and t.valid_until>now() and x.status='test_approved'));
$$;
create function private.require_ai_access(c uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.can_company_action(c,'company.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not private.company_ai_access(c) then raise exception 'Payment required before AI processing' using errcode='P0402';end if;
end;$$;
create function public.company_purchase_state(p_company_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.company_subscriptions;t private.company_test_access;x public.company_test_checkouts;o public.company_onboarding;live boolean;
begin
 if not coalesce(private.can_company_action(p_company_id,'company.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_subscriptions where company_id=p_company_id;
 select * into t from private.company_test_access where company_id=p_company_id;
 select * into o from public.company_onboarding where company_id=p_company_id;
 if private.can_company_action(p_company_id,'billing.manage') then select * into x from public.company_test_checkouts where company_id=p_company_id order by created_at desc,id desc limit 1;end if;
 live:=coalesce(s.status='active' and s.current_period_end>now(),false);
 return jsonb_build_object('companyId',p_company_id,'aiAllowed',private.company_ai_access(p_company_id),'accessMode',case when live then 'live' when t.valid_until>now() then 'test' else 'none' end,
 'testUntil',t.valid_until,'planId',case when live then s.plan_id else (select plan_id from public.company_test_checkouts where id=t.checkout_id) end,
 'onboardingComplete',coalesce(o.profile_version>0 and o.confirmed_revision=o.revision,false),'setupComplete',exists(select 1 from public.company_setup where company_id=p_company_id),
 'canPurchase',private.can_company_action(p_company_id,'billing.manage'),'canWrite',private.can_company_action(p_company_id,'marketing.write'),'latestCheckout',case when x.id is null then null else to_jsonb(x) end);
end;$$;
create function public.begin_test_checkout(p_company_id uuid,p_id uuid,p_plan text) returns jsonb language plpgsql security definer set search_path='' as $$
declare x public.company_test_checkouts;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'billing.manage'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not exists(select 1 from public.company_onboarding where company_id=p_company_id and profile_version>0 and confirmed_revision=revision) then raise exception 'Confirm onboarding first' using errcode='22023';end if;
 if p_id is null or p_plan is null or p_plan not in ('askadia_monthly','askadia_annual') then raise exception 'Invalid checkout' using errcode='22023';end if;
 select * into x from public.company_test_checkouts where id=p_id;
 if found then
  if x.company_id<>p_company_id or x.actor_id<>auth.uid() or x.plan_id<>p_plan then raise exception 'Checkout conflict' using errcode='22023';end if;
  return to_jsonb(x);
 end if;
 if private.company_ai_access(p_company_id) then raise exception 'Company already activated' using errcode='22023';end if;
 update public.company_test_checkouts set status='cancelled',resolved_at=now() where company_id=p_company_id and status='pending';
 insert into public.company_test_checkouts(id,company_id,actor_id,plan_id,installment_cents,installments,total_cents) values
 (p_id,p_company_id,auth.uid(),p_plan,case when p_plan='askadia_annual' then 99800 else 149700 end,case when p_plan='askadia_annual' then 12 else 1 end,case when p_plan='askadia_annual' then 1197600 else 149700 end) returning * into x;
 return to_jsonb(x);
end;$$;
create function public.complete_test_checkout_server(p_company_id uuid,p_id uuid,p_actor uuid,p_outcome text,p_accepted boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare x public.company_test_checkouts;previous text;allowed boolean;target text;
begin
 perform 1 from public.companies where id=p_company_id for update;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);
 allowed:=private.can_company_action(p_company_id,'billing.manage');
 if not coalesce(allowed,false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into x from public.company_test_checkouts where id=p_id and company_id=p_company_id and actor_id=p_actor for update;
 if not found then raise exception 'Checkout unavailable' using errcode='22023';end if;
 if p_outcome is null or p_outcome not in ('approved','declined','cancelled') or (p_outcome='approved' and not coalesce(p_accepted,false)) then raise exception 'Confirm checkout terms' using errcode='22023';end if;
 target:=case when p_outcome='approved' then 'test_approved' else p_outcome end;
 if x.status=target then perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);return to_jsonb(x);end if;
 if x.status<>'pending' or x.expires_at<=now() then raise exception 'Checkout expired or resolved' using errcode='22023';end if;
 if not exists(select 1 from public.company_onboarding where company_id=p_company_id and profile_version>0 and confirmed_revision=revision) then raise exception 'Confirm onboarding first' using errcode='22023';end if;
 update public.company_test_checkouts set status=target,resolved_at=now() where id=x.id returning * into x;
 if target='test_approved' then
  insert into private.company_test_access(company_id,checkout_id,valid_until) values(p_company_id,x.id,now()+interval '7 days') on conflict(company_id) do update set checkout_id=excluded.checkout_id,valid_until=excluded.valid_until;
  perform public.enqueue_content_preparation(p_company_id);
  perform public.enqueue_company_launch(p_company_id);
 end if;
 insert into public.platform_audit(actor_id,company_id,action,details) values(p_actor,p_company_id,'checkout.test.'||p_outcome,jsonb_build_object('checkoutId',x.id,'planId',x.plan_id,'totalCents',x.total_cents,'installments',x.installments));
 perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);return to_jsonb(x);
end;$$;
create function public.finish_company_setup(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'strategy.approve'),false) then raise exception 'Access denied' using errcode='42501';end if;
 perform private.require_ai_access(p_company_id);
 if not private.journey_valid(p_company_id,5) then raise exception 'Approve all strategy stages first' using errcode='22023';end if;
 insert into public.company_setup(company_id,completed_at,completed_by) values(p_company_id,now(),auth.uid()) on conflict do nothing;
 return public.company_purchase_state(p_company_id);
end;$$;
revoke all on function private.company_ai_access(uuid),private.require_ai_access(uuid) from public,anon,authenticated;
revoke all on function public.company_purchase_state(uuid),public.begin_test_checkout(uuid,uuid,text),public.complete_test_checkout_server(uuid,uuid,uuid,text,boolean),public.finish_company_setup(uuid) from public,anon,authenticated;
grant execute on function public.company_purchase_state(uuid),public.begin_test_checkout(uuid,uuid,text),public.finish_company_setup(uuid) to authenticated;
grant execute on function public.complete_test_checkout_server(uuid,uuid,uuid,text,boolean) to service_role;

-- AI gates appended below; preserve existing role, version and lease checks.

create or replace function public.start_company_strategy(p_company_id uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;b public.company_strategy_briefs;
begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not private.journey_valid(p_company_id,1) then raise exception 'Revise os concorrentes antes do diagnóstico.' using errcode='40001';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if s.confirmed_revision is distinct from s.revision then raise exception 'Confirm the current profile first' using errcode='22023';end if;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
 if b.id is null then perform public.prepare_company_strategy(p_company_id);select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;end if;
 if b.status='generating' and b.created_at>now()-interval '5 minutes' then raise exception 'Generation already running' using errcode='40001';end if;
 if not public.reserve_onboarding_provider(p_company_id,p_request_id,'strategy') then raise exception 'Strategy usage allowance unavailable' using errcode='22023';end if;
 update public.company_strategy_briefs set competitor_review_token=(select token from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=1),status='generating',request_id=p_request_id,generation=generation+1,output=null,approved_by=null,approved_generation=null,created_at=now() where id=b.id returning * into b;
 return to_jsonb(b)||jsonb_build_object('competitorEvidence',(select snapshot from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=1));
end;$$;

create or replace function public.start_content_run(p_company_id uuid,p_request_id uuid,p_kind text,p_item_id uuid default null,p_frame integer default 0,p_materials uuid[] default array[]::uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare snap jsonb;i public.company_calendar_items;b public.company_strategy_briefs;s public.company_onboarding;
begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not private.journey_valid(p_company_id,5) then raise exception 'Aprove as etapas da estratégia antes da produção.' using errcode='40001';end if;
 if p_kind='design' and exists(select 1 from public.company_marketing_journeys j join public.company_onboarding ob on ob.company_id=j.company_id and ob.profile_version=j.profile_version where j.company_id=p_company_id) and not exists(select 1 from public.company_calendar_items where company_id=p_company_id and id=p_item_id and planned_date between (now() at time zone 'America/Sao_Paulo')::date and (now() at time zone 'America/Sao_Paulo')::date+7) then raise exception 'A criação acontece na semana anterior à publicação.' using errcode='22023';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if p_kind not in ('details','design') or p_request_id is null or p_frame not between 0 and 5 then raise exception 'Invalid run' using errcode='22023';end if;
 if exists(select 1 from public.company_content_runs where id=p_request_id) then raise exception 'Request already used' using errcode='40001';end if;
 if (select count(*) from public.company_content_runs where company_id=p_company_id and kind=p_kind and created_at>date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') >= (case when p_kind='details' then 3 else 36 end) or (select count(*) from public.company_content_runs where actor_id=auth.uid() and kind=p_kind and created_at>date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') >= (case when p_kind='details' then 9 else 72 end) then raise exception 'Content allowance exhausted' using errcode='22023';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
 if b.id is null or not private.calendar_current(p_company_id,b.id,b.generation,b.profile_version) then raise exception 'Approve the current strategy first' using errcode='40001';end if;
 if p_kind='details' then
  if exists(select 1 from public.company_content_runs where company_id=p_company_id and kind='details' and status='running' and created_at>now()-interval '3 minutes') then raise exception 'Generation running' using errcode='40001';end if;
  select jsonb_build_object('facts',b.facts,'briefId',b.id,'generation',b.generation,'items',jsonb_agg(to_jsonb(c) order by c.position)) into snap from public.company_calendar_items c where c.company_id=p_company_id and c.brief_id=b.id and c.generation=b.generation and c.details is null;
  if snap->'items' is null or snap->'items'='null'::jsonb then raise exception 'No pending content' using errcode='22023';end if;
 else
  select * into i from public.company_calendar_items where company_id=p_company_id and id=p_item_id;
  if i.id is null or i.details is null or i.format='video' or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) or (i.format='imagem' and p_frame<>0) or (i.format='carrossel' and p_frame>=jsonb_array_length(i.details->'slides')) then raise exception 'Review content before design' using errcode='22023';end if;
  if exists(select 1 from public.company_content_runs where item_id=i.id and kind='design' and frame=p_frame and status='running' and created_at>now()-interval '5 minutes') then raise exception 'Generation running' using errcode='40001';end if;
  if cardinality(p_materials)>5 or exists(select 1 from unnest(p_materials) m where not exists(select 1 from public.onboarding_attachments a where a.id=m and a.company_id=p_company_id and a.mime in ('image/png','image/jpeg','image/webp'))) then raise exception 'Company materials required' using errcode='42501';end if;
  snap=jsonb_build_object('facts',b.facts,'item',to_jsonb(i),'materials',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'object_path',a.object_path)) from public.onboarding_attachments a where a.company_id=p_company_id and a.id=any(p_materials)),'[]'::jsonb));
 end if;
 insert into public.company_content_runs(id,company_id,actor_id,kind,item_id,frame,snapshot) values(p_request_id,p_company_id,auth.uid(),p_kind,p_item_id,p_frame,snap);
 return snap;
end;$$;

create or replace function private.start_prepared_content(p_company_id uuid,p_request_id uuid,p_kind text,p_item_id uuid default null,p_frame integer default 0,p_materials uuid[] default array[]::uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare snap jsonb;i public.company_calendar_items;b public.company_strategy_briefs;s public.company_onboarding;
begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if p_kind not in ('details','design') or p_request_id is null or p_frame not between 0 and 5 then raise exception 'Invalid run' using errcode='22023';end if;
 if exists(select 1 from public.company_content_runs where id=p_request_id) then raise exception 'Request already used' using errcode='40001';end if;
 if (select count(*) from public.company_content_runs where company_id=p_company_id and kind=p_kind and created_at>date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') >= (case when p_kind='details' then 3 else 36 end) or (select count(*) from public.company_content_runs where actor_id=auth.uid() and kind=p_kind and created_at>date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') >= (case when p_kind='details' then 9 else 72 end) then raise exception 'Content allowance exhausted' using errcode='22023';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
 if b.id is null or not private.calendar_preparable(p_company_id,b.id,b.generation,b.profile_version) then raise exception 'Approve the current strategy first' using errcode='40001';end if;
 if p_kind='details' then
  if exists(select 1 from public.company_content_runs where company_id=p_company_id and kind='details' and status='running' and created_at>now()-interval '3 minutes') then raise exception 'Generation running' using errcode='40001';end if;
  select jsonb_build_object('facts',b.facts,'briefId',b.id,'generation',b.generation,'items',jsonb_agg(to_jsonb(c) order by c.position)) into snap from public.company_calendar_items c where c.company_id=p_company_id and c.brief_id=b.id and c.generation=b.generation and c.details is null;
  if snap->'items' is null or snap->'items'='null'::jsonb then raise exception 'No pending content' using errcode='22023';end if;
 else
  select * into i from public.company_calendar_items where company_id=p_company_id and id=p_item_id;
  if i.id is null or i.details is null or i.format='video' or not private.calendar_preparable(p_company_id,i.brief_id,i.generation,i.profile_version) or (i.format='imagem' and p_frame<>0) or (i.format='carrossel' and p_frame>=jsonb_array_length(i.details->'slides')) then raise exception 'Review content before design' using errcode='22023';end if;
  if exists(select 1 from public.company_content_runs where item_id=i.id and kind='design' and frame=p_frame and status='running' and created_at>now()-interval '5 minutes') then raise exception 'Generation running' using errcode='40001';end if;
  if cardinality(p_materials)>5 or exists(select 1 from unnest(p_materials) m where not exists(select 1 from public.onboarding_attachments a where a.id=m and a.company_id=p_company_id and a.mime in ('image/png','image/jpeg','image/webp'))) then raise exception 'Company materials required' using errcode='42501';end if;
  snap=jsonb_build_object('facts',b.facts,'item',to_jsonb(i),'materials',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'object_path',a.object_path)) from public.onboarding_attachments a where a.company_id=p_company_id and a.id=any(p_materials)),'[]'::jsonb));
 end if;
 insert into public.company_content_runs(id,company_id,actor_id,kind,item_id,frame,snapshot) values(p_request_id,p_company_id,auth.uid(),p_kind,p_item_id,p_frame,snap);
 return snap;
end;$$;

create or replace function public.start_calendar_dates(p_company_id uuid,p_id uuid,p_month date) returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb;existing jsonb;
begin
 perform private.require_ai_access(p_company_id);
 context:=public.start_calendar_dates_base(p_company_id,p_id,p_month);
 select coalesce(jsonb_agg(i.planned_date),'[]'::jsonb) into existing from public.company_calendar_items i where i.company_id=p_company_id and i.planned_date is not null and private.calendar_current(i.company_id,i.brief_id,i.generation,i.profile_version);
 return context||jsonb_build_object('existingDates',existing);
end;$$;

create or replace function public.reserve_site_generation(p_company_id uuid,p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not private.journey_valid(p_company_id,5) then raise exception 'Conclua as aprovações da estratégia antes de gerar o site.' using errcode='40001';end if;
 if (select count(*) from private.site_generation_runs where company_id=p_company_id and created_at>date_trunc('day',now()))>=5 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 insert into private.site_generation_runs(id,company_id,actor_id) values(p_id,p_company_id,auth.uid());
end;$$;

create or replace function public.begin_paid_plan(p_company_id uuid,p_id uuid,p_budget numeric,p_days integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.company_profile_versions;begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (select count(*) from public.company_paid_plans where company_id=p_company_id and created_at>now()-interval '1 day')>=5 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select * into v from public.company_profile_versions where company_id=p_company_id order by version desc limit 1;
 if v.company_id is null then raise exception 'Confirm company profile first' using errcode='22023';end if;
 insert into public.company_paid_plans(id,company_id,actor_id,profile_version,budget,days) values(p_id,p_company_id,auth.uid(),v.version,p_budget,p_days);return jsonb_build_object('facts',v.facts,'version',v.version);
end;$$;

create or replace function public.inbox_ai_context(p_company_id uuid,p_channel text) returns jsonb language plpgsql security definer set search_path='' as $$
declare settings public.company_service_settings;
begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (select count(*) from public.inbox_ai_attempts where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select * into settings from public.company_service_settings where company_id=p_company_id and channel=p_channel;
 if settings.company_id is null or settings.mode='human' then raise exception 'Configure assistance first' using errcode='22023';end if;
 insert into public.inbox_ai_attempts(company_id,actor_id) values(p_company_id,auth.uid());
 return jsonb_build_object('settings',to_jsonb(settings),'profile',private.service_profile(p_company_id));
end;$$;

create or replace function public.reserve_onboarding_provider(p_company_id uuid,p_request_id uuid,p_kind text) returns boolean language plpgsql security definer set search_path='' as $$
declare allowance integer;
begin
 if p_kind<>'places' then perform private.require_ai_access(p_company_id);end if;
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_request_id is null or p_kind is null or p_kind not in ('interpretation','places','strategy') then raise exception 'Invalid provider request' using errcode='22023';end if;
 select daily_calls into allowance from public.onboarding_provider_limits where company_id=p_company_id and kind=p_kind;
 if coalesce(allowance,0)=0 or exists(select 1 from public.onboarding_provider_attempts where company_id=p_company_id and request_id=p_request_id and kind=p_kind) or (select count(*) from public.onboarding_provider_attempts where company_id=p_company_id and kind=p_kind and created_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=allowance then return false;end if;
 insert into public.onboarding_provider_attempts(company_id,request_id,kind,actor_id) values(p_company_id,p_request_id,p_kind,auth.uid());return true;
end;$$;

create or replace function public.inbox_auto_claim(p_company_id uuid,p_thread text,p_message_id text,p_time timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_service_settings;j public.inbox_auto_jobs;v integer;
begin
 if not private.company_ai_access(p_company_id) then return null;end if;
 perform 1 from public.companies where id=p_company_id for update;
 select * into s from public.company_service_settings where company_id=p_company_id and channel='whatsapp';
 if not coalesce(s.automatic,false) or s.mode='human' or not private.can_automate(p_company_id,s.automated_by) or p_time<=s.enabled_since or p_time<now()-interval '5 minutes' or p_time>now()+interval '1 minute' then return null;end if;
 if p_thread !~ '^[0-9]{6,20}@(s.whatsapp.net|lid)$' or p_message_id is null or length(p_message_id) not between 1 and 200 then return null;end if;
 if exists(select 1 from public.inbox_handoffs where company_id=p_company_id and channel='whatsapp' and thread=p_thread and (released_at is null or p_time<=released_at)) then return null;end if;
 if exists(select 1 from public.inbox_auto_jobs where company_id=p_company_id and thread=p_thread and state in ('generating','dispatching')) then return null;end if;
 if (select count(*) from public.inbox_auto_jobs where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then return null;end if;
 select version into v from public.company_profile_versions where company_id=p_company_id order by version desc limit 1;if v is null then return null;end if;
 insert into public.inbox_auto_jobs(company_id,message_id,thread,revision,profile_version,state) values(p_company_id,p_message_id,p_thread,s.revision,v,'generating') on conflict do nothing returning * into j;
 if j.token is null then return null;end if;
 return jsonb_build_object('token',j.token,'settings',to_jsonb(s),'profile',private.service_profile(p_company_id));
end;$$;

create or replace function public.inbox_auto_targets() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 update public.inbox_auto_jobs set state=case when state='dispatching' then 'uncertain' else 'failed' end,updated_at=now() where state in ('generating','dispatching') and updated_at<now()-interval '2 minutes';
 return coalesce((select jsonb_agg(jsonb_build_object('companyId',s.company_id,'since',s.enabled_since,'instance',c.remote_id)) from public.company_service_settings s join public.company_channels c on c.company_id=s.company_id and c.provider='evolution' where private.company_ai_access(s.company_id) and s.channel='whatsapp' and s.automatic and c.status='connected' and c.remote_id='askadia-'||s.company_id::text and private.can_automate(s.company_id,s.automated_by)),'[]'::jsonb);
end;$$;

create or replace function public.claim_image_description_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.onboarding_attachments;t uuid:=gen_random_uuid();
begin
 select * into a from public.onboarding_attachments x where private.company_ai_access(x.company_id) and x.mime in ('image/jpeg','image/png','image/webp')
 and x.description_status in ('pending','processing','failed') and x.description_attempts<3
 and (x.description_updated_at is null or x.description_updated_at<now()-interval '5 minutes')
 order by x.description_attempts,x.created_at for update skip locked limit 1;
 if not found then return null;end if;
 update public.onboarding_attachments set description_status='processing',description_attempts=description_attempts+1,
 description_token=t,description_updated_at=now() where id=a.id and company_id=a.company_id;
 return jsonb_build_object('id',a.id,'companyId',a.company_id,'path',a.object_path,'mime',a.mime,'token',t);
end;$$;

create or replace function public.claim_content_preparation_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_content_preparations;b public.company_strategy_briefs;i public.company_calendar_items;context jsonb;kind text;run uuid:=gen_random_uuid();lease uuid:=gen_random_uuid();frame_no integer;refs uuid[];d date:=(now() at time zone 'America/Sao_Paulo')::date+7;error_code text;
begin
 select * into j from public.company_content_preparations where private.company_ai_access(company_id) and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) order by updated_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;
 if not found then return null;end if;
 select * into j from public.company_content_preparations where id=j.id and private.company_ai_access(company_id) and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;
 if not found then return null;end if;
 if not private.preparation_actor(j) then update public.company_content_preparations set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return null;end if;
 if not private.journey_valid(j.company_id,1) then update public.company_content_preparations set status='pending',stage='approval',token=null,next_attempt_at=now()+interval '1 minute',error='Revise a análise dos concorrentes na primeira etapa da estratégia.',updated_at=now() where id=j.id;return null;end if;
 -- A worker restart may leave an old reserved run. It cannot finish after token replacement.
 if j.run_id is not null then
  update public.company_content_runs set status='failed' where id=j.run_id and company_id=j.company_id and status='running';
  update public.company_strategy_briefs set status='failed' where company_id=j.company_id and request_id=j.run_id and status='generating';
 end if;
 if j.attempts>=3 then update public.company_content_preparations set status='failed',error='A preparação foi pausada após três tentativas. Retome para tentar novamente.',token=null,updated_at=now() where id=j.id;return null;end if;
 select * into b from public.company_strategy_briefs where company_id=j.company_id and profile_version=j.profile_version;
 if b.status='generating' then update public.company_content_preparations set status='pending',next_attempt_at=now()+interval '30 seconds',updated_at=now() where id=j.id;return null;end if;
 if j.generation is not null and b.generation is distinct from j.generation then update public.company_content_preparations set status='stale',token=null,error='A estratégia mudou. Retome a preparação da nova versão.',updated_at=now() where id=j.id;return null;end if;
 begin
 if b.id is null or b.output is null or b.status in ('awaiting_configuration','failed') then
  kind:='strategy';context:=public.start_company_strategy(j.company_id,run);
 else
  if not private.calendar_preparable(j.company_id,b.id,b.generation,b.profile_version) then raise exception 'Strategy unavailable';end if;
  insert into public.company_calendar_items(company_id,brief_id,generation,profile_version,position,week,format,idea,direction)
  select j.company_id,b.id,b.generation,b.profile_version,n::integer,(x->>'week')::integer,x->>'format',x->>'theme',coalesce(x->>'brief','') from jsonb_array_elements(b.output->'calendar') with ordinality e(x,n) on conflict do nothing;
  -- Rolling dates start today, preserve dates already reviewed, and span months if needed.
  for i in select * from public.company_calendar_items where company_id=j.company_id and brief_id=b.id and generation=b.generation and planned_date is null order by position loop
   while exists(select 1 from public.company_calendar_items c where c.company_id=j.company_id and c.brief_id=b.id and c.generation=b.generation and c.planned_date=d)
    or (select count(*) from public.company_calendar_items c where c.company_id=j.company_id and c.brief_id=b.id and c.generation=b.generation and date_trunc('week',c.planned_date::timestamp)=date_trunc('week',d::timestamp))>=2 loop d:=d+1;end loop;
   update public.company_calendar_items set planned_date=d where id=i.id;d:=d+3;
  end loop;
  if not private.journey_valid(j.company_id,5) then update public.company_content_preparations set status='pending',stage='approval',token=null,next_attempt_at=now()+interval '1 minute',error='Aprove as etapas da estratégia para iniciar a produção.',updated_at=now() where id=j.id;return null;end if;
  if exists(select 1 from public.company_calendar_items where company_id=j.company_id and brief_id=b.id and generation=b.generation and details is null) then kind:='details';context:=private.start_prepared_content(j.company_id,run,'details');
  else
   select c.* into i from public.company_calendar_items c cross join lateral generate_series(0,case when c.format='carrossel' then jsonb_array_length(c.details->'slides')-1 else 0 end) f(n)
    where c.company_id=j.company_id and c.brief_id=b.id and c.generation=b.generation and c.format<>'video' and c.details is not null
    and c.planned_date between (now() at time zone 'America/Sao_Paulo')::date and (now() at time zone 'America/Sao_Paulo')::date+7
    and not exists(select 1 from public.company_creatives a where a.item_id=c.id and a.revision=c.revision and a.frame=f.n) order by c.position,f.n limit 1;
   if i.id is null and exists(select 1 from public.company_calendar_items c cross join lateral generate_series(0,case when c.format='carrossel' then jsonb_array_length(c.details->'slides')-1 else 0 end) f(n) where c.company_id=j.company_id and c.brief_id=b.id and c.generation=b.generation and c.format<>'video' and not exists(select 1 from public.company_creatives a where a.item_id=c.id and a.revision=c.revision and a.frame=f.n)) then update public.company_content_preparations set status='pending',stage='scheduled',token=null,run_id=null,next_attempt_at=now()+interval '6 hours',error='As artes serão preparadas na semana anterior a cada publicação. Confira datas vencidas no calendário.',updated_at=now() where id=j.id;return null;end if;
   if i.id is null then update public.company_content_preparations set status='completed',stage='ready',attempts=0,token=null,run_id=null,error=null,updated_at=now() where id=j.id;return null;end if;
   select f.n into frame_no from generate_series(0,case when i.format='carrossel' then jsonb_array_length(i.details->'slides')-1 else 0 end) f(n) where not exists(select 1 from public.company_creatives a where a.item_id=i.id and a.revision=i.revision and a.frame=f.n) order by f.n limit 1;
   select coalesce(array_agg(id),'{}'::uuid[]) into refs from (select a.id,sum(a.size) over(order by case when a.visual_description->>'category'='logo' then 0 else 1 end,a.created_at desc) total,row_number() over(order by case when a.visual_description->>'category'='logo' then 0 else 1 end,a.created_at desc) n from public.onboarding_attachments a where a.company_id=j.company_id and a.mime in ('image/png','image/jpeg','image/webp')) m where n<=5 and total<=12582912;
   kind:='design';context:=private.start_prepared_content(j.company_id,run,'design',i.id,frame_no,refs);
  end if;
 end if;
 exception when others then
  get stacked diagnostics error_code=returned_sqlstate;
  update public.company_content_preparations set status='failed',stage=coalesce(kind,'strategy'),error=case when error_code='22023' then 'Limite de geração ou dados pendentes. Confira a estratégia e retome depois.' else 'Não foi possível preparar esta etapa. Revise a estratégia e retome.' end,token=null,updated_at=now() where id=j.id;return null;
 end;
 update public.company_content_preparations set status='running',stage=kind,attempts=attempts+1,token=lease,run_id=run,lease_until=now()+interval '5 minutes',brief_id=case when kind='strategy' then null else b.id end,generation=case when kind='strategy' then null else b.generation end,error=null,updated_at=now() where id=j.id;
 return jsonb_build_object('id',j.id,'companyId',j.company_id,'token',lease,'runId',run,'kind',kind,'frame',frame_no,'context',context,'today',(now() at time zone 'America/Sao_Paulo')::date);
end;$$;

create or replace function public.claim_company_launch_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_launch_jobs;t uuid:=gen_random_uuid();s public.company_sites;facts jsonb;
begin
 select * into j from public.company_launch_jobs where private.company_ai_access(company_id) and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) order by updated_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;if not found then return null;end if;
 select * into j from public.company_launch_jobs where id=j.id and private.company_ai_access(company_id) and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
 if not private.launch_actor(j) then update public.company_launch_jobs set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return null;end if;
 if not private.journey_valid(j.company_id,case when j.kind='site' then 5 else 2 end) then update public.company_launch_jobs set status='pending',token=null,next_attempt_at=now()+interval '1 minute',error='Aguardando aprovação das etapas da estratégia.',updated_at=now() where id=j.id;return null;end if;
 perform 1 from public.profiles where id=j.actor_id for update;
 if j.attempts>=3 or (select count(*) from private.launch_runs where company_id=j.company_id and created_at>now()-interval '1 day')>=10 or (select count(*) from private.launch_runs where actor_id=j.actor_id and created_at>now()-interval '1 day')>=30 then
 update public.company_launch_jobs set status='failed',token=null,error='Limite de tentativas atingido. Retome após revisar as pendências.',updated_at=now() where id=j.id;return null;end if;
 select * into s from public.company_sites where company_id=j.company_id;
 -- Preserve any existing draft, including edits made outside this preparation.
 if j.kind='site' and s.draft is not null then update public.company_launch_jobs set status='completed',error='O site existente foi preservado. Confira se corresponde ao perfil atual.',token=null,updated_at=now() where id=j.id;return null;end if;
 if j.kind='site' then begin perform public.reserve_site_generation(j.company_id,t);exception when others then update public.company_launch_jobs set status='failed',token=null,error='Limite de geração de site atingido. Tente novamente após o período de limite.',updated_at=now() where id=j.id;return null;end;end if;
 insert into private.launch_runs(company_id,actor_id) values(j.company_id,j.actor_id);
 select p.facts into facts from public.company_profile_versions p where p.company_id=j.company_id and p.version=j.profile_version;
 update public.company_launch_jobs set status='running',attempts=attempts+1,token=t,lease_until=now()+interval '5 minutes',expected_revision=coalesce(s.revision,0),approval_token=(select token from public.company_marketing_approvals where company_id=j.company_id and profile_version=j.profile_version and stage=case when j.kind='site' then 5 else 2 end),error=null,updated_at=now() where id=j.id;
 return jsonb_build_object('id',j.id,'companyId',j.company_id,'profileVersion',j.profile_version,'token',t,'kind',j.kind,'facts',facts,'strategy',(select output from public.company_strategy_briefs where company_id=j.company_id and profile_version=j.profile_version and status='approved'));
end;$$;

create or replace function public.claim_visual_job_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_visual_jobs;s public.company_onboarding;refs jsonb;campaign jsonb;t uuid:=gen_random_uuid();
begin
 select * into j from public.company_visual_jobs where private.company_ai_access(company_id) and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) order by next_attempt_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;if not found then return null;end if;
 select * into j from public.company_visual_jobs where id=j.id and private.company_ai_access(company_id) and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);
 select * into s from public.company_onboarding where company_id=j.company_id;
 if not coalesce(private.can_company_action(j.company_id,'marketing.write'),false) or s.profile_version<>j.profile_version or s.confirmed_revision is distinct from s.revision then update public.company_visual_jobs set status='stale',token=null,error='O perfil ou as permissões mudaram. Revise antes de solicitar novamente.' where id=j.id;return null;end if;
 if j.kind='campaign_creative' and not private.journey_valid(j.company_id,5) then update public.company_visual_jobs set next_attempt_at=now()+interval '1 minute',status='pending',error='A produção aguarda a aprovação das cinco etapas da estratégia.' where id=j.id;return null;end if;
 if j.attempts>=3 then update public.company_visual_jobs set status='failed',token=null,error='A geração não concluiu após três tentativas. O material original foi preservado.' where id=j.id;return null;end if;
 if (select count(*) from private.visual_attempts where company_id=j.company_id and created_at>now()-interval '1 day')>=12 or (select count(*) from private.visual_attempts where actor_id=j.actor_id and created_at>now()-interval '1 day')>=30 then update public.company_visual_jobs set status='pending',next_attempt_at=now()+interval '1 hour',error='Aguardando renovação do limite diário de geração de imagens.' where id=j.id;return null;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'mime',a.mime,'path',a.object_path) order by ref.n),'[]') into refs from unnest(j.reference_ids) with ordinality ref(id,n) join public.onboarding_attachments a on a.id=ref.id and a.company_id=j.company_id;
 if jsonb_array_length(refs)<>cardinality(j.reference_ids) then update public.company_visual_jobs set status='failed',error='Um material selecionado não está mais disponível.' where id=j.id;return null;end if;
 if j.plan_id is not null then select output->'campaigns'->j.campaign_index into campaign from public.company_paid_plans where id=j.plan_id and company_id=j.company_id and profile_version=j.profile_version and status='ready';end if;
 insert into private.visual_attempts(company_id,actor_id) values(j.company_id,j.actor_id);
 update public.company_visual_jobs set status='running',token=t,lease_until=now()+interval '5 minutes',attempts=attempts+1,error=null,updated_at=now() where id=j.id;
 return jsonb_build_object('id',j.id,'companyId',j.company_id,'token',t,'request',jsonb_build_object('kind',j.kind,'ratio',j.ratio,'instructions',j.instructions,'facts',s.facts,'campaign',campaign),'references',refs);
end;$$;

create or replace function public.claim_ad_plan_seed_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_ad_plan_seeds;facts jsonb;suggestions jsonb;existing uuid;previous text;allowed boolean;
begin
 select * into s from public.company_ad_plan_seeds where private.company_ai_access(company_id) and (status='pending' or (status='running' and lease_until<now())) and attempts<3 order by updated_at for update skip locked limit 1;
 if s.company_id is null then return null;end if;
 if not private.journey_valid(s.company_id,5) or not exists(select 1 from public.company_onboarding where company_id=s.company_id and profile_version=s.profile_version and confirmed_revision=revision) then update public.company_ad_plan_seeds set status='stale',error='Atualize a estratégia aprovada.' where company_id=s.company_id and profile_version=s.profile_version;return null;end if;
 select id into existing from public.company_paid_plans where company_id=s.company_id and profile_version=s.profile_version and status='ready' order by created_at desc limit 1;
 if existing is not null then update public.company_ad_plan_seeds set status='completed',plan_id=existing where company_id=s.company_id and profile_version=s.profile_version;return null;end if;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',s.actor_id::text,true);allowed:=private.can_company_action(s.company_id,'marketing.write');perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 if not coalesce(allowed,false) then update public.company_ad_plan_seeds set status='blocked',error='A preparação precisa de autorização de marketing.' where company_id=s.company_id and profile_version=s.profile_version;return null;end if;
 update public.company_ad_plan_seeds set token=gen_random_uuid(),lease_until=now()+interval '5 minutes',status='running',attempts=attempts+1,updated_at=now() where company_id=s.company_id and profile_version=s.profile_version returning * into s;
 select f.facts,l.output->'traffic' into facts,suggestions from public.company_profile_versions f join public.company_launch_jobs l on l.company_id=f.company_id and l.profile_version=f.version and l.kind='recommendations' and l.status='completed' where f.company_id=s.company_id and f.version=s.profile_version;
 return to_jsonb(s)||jsonb_build_object('facts',facts,'suggestions',suggestions);
end;$$;

create or replace function public.claim_ad_execution_server(p_mode text default 'all') returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;prev text;allowed boolean;action text;facts jsonb;proposal jsonb;
begin
 select * into e from public.company_ad_executions where (spec is not null or desired<>'run' or private.company_ai_access(company_id)) and (p_mode='all' or (p_mode='prepare' and spec is null and desired='run') or (p_mode='execute' and (spec is not null or desired<>'run'))) and (lease_until is null or lease_until<now()) and next_attempt_at<=now() and ((status not in ('draft','paused','cancelled','completed','stale')) or (desired<>'run' and status not in ('paused','cancelled','completed','stale'))) order by case when desired<>'run' then 0 when status='active' then 1 else 2 end,next_attempt_at for update skip locked limit 1;
 if e.id is null then return null;end if;
 if e.desired<>'run' then action:='stop';
 elsif e.spec is null then
  prev:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',e.actor_id::text,true);allowed:=private.can_company_action(e.company_id,'marketing.write');perform set_config('request.jwt.claim.sub',coalesce(prev,''),true);
  if not coalesce(allowed,false) or not exists(select 1 from public.company_onboarding where company_id=e.company_id and profile_version=e.profile_version and confirmed_revision=revision) then update public.company_ad_executions set status='stale',error='Perfil ou autorização mudou.',updated_at=now() where id=e.id;return null;end if;
  if not private.journey_valid(e.company_id,5) then update public.company_ad_executions set next_attempt_at=now()+interval '1 minute' where id=e.id;return null;end if;action:='prepare';
 elsif not private.ad_approval_valid(e) then action:='invalidate';
 elsif (e.spec->>'endsAt')::timestamptz<=now() then action:='end';
 elsif e.remote->>'complete' is distinct from 'true' then action:='provision';
 elsif e.status='active' then action:='monitor';
 elsif (e.spec->>'startsAt')::timestamptz<=now() then action:='activate';
 else update public.company_ad_executions set status='scheduled',next_attempt_at=least((e.spec->>'startsAt')::timestamptz,now()+interval '1 minute') where id=e.id;return null;
 end if;
 update public.company_ad_executions set lease_token=gen_random_uuid(),lease_until=now()+interval '5 minutes',attempts=attempts+1,updated_at=now() where id=e.id returning * into e;
 select f.facts,p.output->'campaigns'->e.campaign_index into facts,proposal from public.company_profile_versions f join public.company_paid_plans p on p.id=e.plan_id where f.company_id=e.company_id and f.version=e.profile_version;
 return to_jsonb(e)||jsonb_build_object('action',action,'facts',facts,'proposal',proposal);
end;$$;

create or replace function public.reserve_ad_copy_server(p_id uuid,p_token uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 update public.company_ad_executions set copy_attempts=copy_attempts+1 where private.company_ai_access(company_id) and id=p_id and lease_token=p_token and lease_until>now() and spec is null and copy_attempts<3;return found;
end;$$;
create or replace function public.inbox_prompt_context(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare profile jsonb;
begin
 perform private.require_ai_access(p_company_id);
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write') and private.can_company_action(p_company_id,'crm.read') and private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 profile:=private.service_profile(p_company_id);
 if profile is null then raise exception 'Confirm company profile first' using errcode='22023';end if;
 if (select count(*) from public.inbox_ai_attempts where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 insert into public.inbox_ai_attempts(company_id,actor_id) values(p_company_id,auth.uid());return profile;
end;$$;
notify pgrst,'reload schema';
commit;
