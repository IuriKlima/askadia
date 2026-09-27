begin;
alter table public.company_ad_connections add column login_customer_id text check(login_customer_id is null or login_customer_id ~ '^[0-9]{6,20}$');
create or replace function public.ad_credentials_server(p_company_id uuid,p_actor uuid,p_provider text,p_write jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;payload jsonb;begin
 if p_actor is null or p_provider not in ('google','meta') then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.companies where id=p_company_id for update;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);
 allowed:=case when p_write is null then private.can_company_action(p_company_id,'marketing.read') else private.company_owner(p_company_id) end;
 perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 if not coalesce(allowed,false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_write is not null then
 insert into public.company_ad_connections(company_id,provider,account_id,name,source_page,status,login_customer_id) values(p_company_id,p_provider,p_write->>'accountId',coalesce(p_write->>'name',''),p_write->>'sourcePage',coalesce(p_write->>'status','pending'),p_write->>'managerId') on conflict(company_id,provider) do update set account_id=excluded.account_id,name=excluded.name,source_page=excluded.source_page,status=excluded.status,login_customer_id=excluded.login_customer_id,updated_at=now();
 if p_write ? 'cipher' then insert into private.ad_credentials values(p_company_id,p_provider,p_write->>'cipher') on conflict(company_id,provider) do update set cipher=excluded.cipher;end if;
 if p_write->>'status'='disconnected' then delete from private.ad_credentials where company_id=p_company_id and provider=p_provider;end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,p_actor,'ads.connection',jsonb_build_object('provider',p_provider,'accountId',p_write->>'accountId','status',p_write->>'status') from public.companies where id=p_company_id;
 end if;
 select to_jsonb(c)||jsonb_build_object('cipher',s.cipher) into payload from public.company_ad_connections c left join private.ad_credentials s using(company_id,provider) where c.company_id=p_company_id and c.provider=p_provider;return payload;
end;$$;
create table public.company_ad_executions(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),plan_id uuid not null references public.company_paid_plans(id),campaign_index integer not null check(campaign_index between 0 and 7),provider text not null check(provider in ('meta','google')),actor_id uuid not null references public.profiles(id),profile_version integer not null,
 revision integer not null default 1,spec jsonb,status text not null default 'preparing' check(status in ('preparing','draft','approved','scheduled','active','paused','cancelled','completed','blocked','reconciling','stale')),
 approved_revision integer,approved_by uuid references public.profiles(id),approved_hash text,approved_basis text,approved_at timestamptz,
 desired text not null default 'run' check(desired in ('run','pause','cancel')),remote jsonb not null default '{}',observed jsonb,checked_at timestamptz,error text,error_kind text,
 lease_token uuid,lease_until timestamptz,next_attempt_at timestamptz not null default now(),attempts integer not null default 0,copy_attempts integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(plan_id,campaign_index)
);
create index ad_execution_due on public.company_ad_executions(next_attempt_at) where status not in ('draft','cancelled','completed','stale','paused');
create table private.ad_execution_steps(execution_id uuid not null references public.company_ad_executions(id),revision integer not null,step text not null,request_hash text not null,status text not null check(status in ('started','succeeded','rejected')),external_id text,created_at timestamptz not null default now(),primary key(execution_id,revision,step));
alter table public.company_ad_executions enable row level security;
revoke all on public.company_ad_executions,private.ad_execution_steps from public,anon,authenticated;
grant select on public.company_ad_executions to authenticated;
create policy ad_execution_read on public.company_ad_executions for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create function private.queue_paid_execution() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='ready' and old.status is distinct from 'ready' then
 insert into public.company_ad_executions(company_id,plan_id,campaign_index,provider,actor_id,profile_version)
 select new.company_id,new.id,(i-1)::integer,c->>'provider',new.actor_id,new.profile_version from jsonb_array_elements(new.output->'campaigns') with ordinality as x(c,i) where i<=8 and c->>'provider' in ('meta','google') on conflict do nothing;
 end if;return new;
end;$$;
create trigger queue_paid_execution after update of status on public.company_paid_plans for each row execute function private.queue_paid_execution();
-- Add review-only drafts for the latest existing proposal. This never approves spending.
insert into public.company_ad_executions(company_id,plan_id,campaign_index,provider,actor_id,profile_version)
 select p.company_id,p.id,(i-1)::integer,c->>'provider',p.actor_id,p.profile_version from public.company_paid_plans p join public.company_onboarding o on o.company_id=p.company_id and o.profile_version=p.profile_version cross join lateral jsonb_array_elements(p.output->'campaigns') with ordinality as x(c,i)
 where p.status='ready' and i<=8 and c->>'provider' in ('meta','google') and not exists(select 1 from public.company_paid_plans n where n.company_id=p.company_id and n.status='ready' and n.created_at>p.created_at) on conflict do nothing;
create function private.ad_journey_basis(c uuid) returns text language sql stable security definer set search_path='' as $$
 select md5(coalesce(string_agg(a.token::text,',' order by a.stage),'')) from public.company_marketing_approvals a join public.company_onboarding o on o.company_id=a.company_id and o.profile_version=a.profile_version where a.company_id=c;
$$;
create function private.ad_permission(c uuid,u uuid,amount bigint) returns boolean language plpgsql security definer set search_path='' as $$
declare prev text;ok boolean;
begin
 prev:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',u::text,true);
 ok:=private.can_company_action(c,'ads.approve') and (private.company_owner(c) or exists(select 1 from public.company_permission_grants where company_id=c and user_id=u and action='ads.approve' and budget_limit_cents>=amount and (expires_at is null or expires_at>now())));
 perform set_config('request.jwt.claim.sub',coalesce(prev,''),true);return coalesce(ok,false);
end;$$;
create function private.ad_approval_valid(e public.company_ad_executions) returns boolean language plpgsql security definer set search_path='' as $$
declare total bigint;
begin
 if e.spec is null or e.approved_revision is distinct from e.revision or e.approved_hash is distinct from md5(e.spec::text) or e.approved_by is null or e.approved_basis is distinct from private.ad_journey_basis(e.company_id) then return false;end if;
 select round(budget*100)::bigint into total from public.company_paid_plans where id=e.plan_id and company_id=e.company_id;
 return private.ad_permission(e.company_id,e.approved_by,total) and private.journey_valid(e.company_id,5)
 and exists(select 1 from public.company_onboarding where company_id=e.company_id and profile_version=e.profile_version and confirmed_revision=revision)
 and exists(select 1 from public.company_ad_connections where company_id=e.company_id and provider=e.provider and status='connected' and account_id=e.spec->>'accountId' and (e.provider<>'meta' or source_page=e.spec->>'pageId'))
 and (e.spec->>'siteRevision' is null or exists(select 1 from public.company_sites where company_id=e.company_id and published_revision=(e.spec->>'siteRevision')::integer));
end;$$;
create function private.validate_ad_spec(e public.company_ad_executions,s jsonb) returns void language plpgsql security definer set search_path='' as $$
declare plan public.company_paid_plans;amount bigint;start_at timestamptz;end_at timestamptz;
begin
 if s is null or jsonb_typeof(s)<>'object' or length(s::text)>24000 or not (s ?& array['name','format','accountId','currency','budgetCents','startsAt','endsAt','timezone','destination','location','copy','imageId','imageSha256','siteRevision']) then raise exception 'Invalid campaign' using errcode='22023';end if;
 select * into plan from public.company_paid_plans where id=e.plan_id and company_id=e.company_id and status='ready';
 amount:=(s->>'budgetCents')::bigint;start_at:=(s->>'startsAt')::timestamptz;end_at:=(s->>'endsAt')::timestamptz;
 if plan.id is null or s->>'currency'<>'BRL' or amount<100 or amount>round((plan.output->'campaigns'->e.campaign_index->>'investment')::numeric*100) or start_at is null or end_at is null or end_at-start_at not between interval '1 day' and interval '90 days' or s->>'destination'!~'^https://[^/@[:space:]]+\.[^/@[:space:]]+' or length(s->>'name') not between 3 and 100 or not exists(select 1 from pg_timezone_names where name=s->>'timezone') then raise exception 'Invalid budget, dates or destination' using errcode='22023';end if;
 if not exists(select 1 from public.company_ad_connections where company_id=e.company_id and provider=e.provider and status='connected' and account_id=s->>'accountId' and (e.provider<>'meta' or source_page=s->>'pageId')) then raise exception 'Account changed or disconnected' using errcode='40001';end if;
 if (e.provider='meta' and s->>'format'<>'meta_traffic_image') or (e.provider='google' and s->>'format'<>'google_search') then raise exception 'Unsupported format' using errcode='22023';end if;
 if e.provider='meta' and (s->>'imageId' is null or s->>'imageSha256'!~'^[a-f0-9]{64}$' or not exists(select 1 from public.onboarding_attachments where id=(s->>'imageId')::uuid and company_id=e.company_id and mime in ('image/png','image/jpeg','image/webp'))) then raise exception 'Company creative required' using errcode='22023';end if;
 if s->>'format'='google_search' and end_at-start_at<interval '3 days' then raise exception 'Google Pesquisa com orçamento total exige entre 3 e 90 dias.' using errcode='22023';end if;
 if (s->'location'->>'latitude')::numeric not between -90 and 90 or (s->'location'->>'longitude')::numeric not between -180 and 180 or (s->'copy'->>'radiusKm')::integer not between 1 and 50 or jsonb_typeof(s->'copy')<>'object' then raise exception 'Invalid targeting' using errcode='22023';end if;
end;$$;
create function public.edit_ad_execution(p_company_id uuid,p_id uuid,p_revision integer,p_spec jsonb) returns void language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into e from public.company_ad_executions where id=p_id and company_id=p_company_id for update;
 if e.id is null or e.revision<>p_revision or e.status not in ('draft','approved','blocked') or e.remote<>'{}'::jsonb or e.lease_until>now() or exists(select 1 from private.ad_execution_steps where execution_id=e.id) then raise exception 'Pause the existing campaign and create a new proposal' using errcode='40001';end if;
 perform private.validate_ad_spec(e,p_spec);
 -- Account, assets and provenance are server-owned; normal edits only change reviewed copy, dates and budget.
 if (p_spec-array['name','budgetCents','startsAt','endsAt','copy']) is distinct from (e.spec-array['name','budgetCents','startsAt','endsAt','copy']) then raise exception 'Campaign references changed' using errcode='22023';end if;
 update public.company_ad_executions set spec=p_spec,revision=revision+1,status='draft',approved_revision=null,approved_by=null,approved_hash=null,approved_basis=null,error=null,error_kind=null,updated_at=now() where id=e.id;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'ads.revised',jsonb_build_object('executionId',e.id,'revision',e.revision+1) from public.companies where id=p_company_id;
end;$$;
create function public.approve_ad_execution(p_company_id uuid,p_id uuid,p_revision integer) returns void language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;amount bigint;
begin
 perform 1 from public.companies where id=p_company_id for update;
 select * into e from public.company_ad_executions where id=p_id and company_id=p_company_id for update;
 select round(budget*100)::bigint into amount from public.company_paid_plans where id=e.plan_id;
 if e.id is null or not private.ad_permission(p_company_id,auth.uid(),amount) then raise exception 'Budget approval permission required' using errcode='42501';end if;
 if e.revision<>p_revision then raise exception 'Campaign changed' using errcode='40001';end if;
 if e.approved_revision=e.revision and e.status in ('approved','scheduled','active') then return;end if;
 if e.status<>'draft' or not private.journey_valid(p_company_id,5) or not exists(select 1 from public.company_onboarding where company_id=p_company_id and profile_version=e.profile_version and confirmed_revision=revision) then raise exception 'Review current strategy and campaign' using errcode='40001';end if;
 perform private.validate_ad_spec(e,e.spec);
 if (e.spec->>'startsAt')::timestamptz<now()+interval '5 minutes' then raise exception 'Schedule at least five minutes ahead' using errcode='22023';end if;
 if e.spec->>'siteRevision' is not null and not exists(select 1 from public.company_sites where company_id=e.company_id and published_revision=(e.spec->>'siteRevision')::integer) then raise exception 'Publish and review the destination site first' using errcode='40001';end if;
 update public.company_ad_executions set status='approved',approved_revision=revision,approved_by=auth.uid(),approved_hash=md5(spec::text),approved_basis=private.ad_journey_basis(p_company_id),approved_at=now(),desired='run',next_attempt_at=now(),updated_at=now(),error=null,error_kind=null where id=p_id;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'ads.approved',jsonb_build_object('executionId',e.id,'revision',e.revision,'snapshot',e.spec,'startsAutomatically',true) from public.companies where id=p_company_id;
end;$$;
create function public.control_ad_execution(p_company_id uuid,p_id uuid,p_revision integer,p_action text) returns void language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;
begin
 if not coalesce(private.can_company_action(p_company_id,'ads.approve'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into e from public.company_ad_executions where id=p_id and company_id=p_company_id for update;
 if e.id is null or e.revision<>p_revision or p_action not in ('pause','cancel','retry') then raise exception 'Campaign changed' using errcode='40001';end if;
 if p_action='retry' then
  if e.status not in ('blocked','reconciling') then raise exception 'No pending retry' using errcode='40001';end if;
  update public.company_ad_executions set next_attempt_at=now(),attempts=0 where id=p_id;
 else
  update public.company_ad_executions set desired=p_action,next_attempt_at=now(),updated_at=now(),approved_revision=null where id=p_id;
 end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'ads.'||p_action,jsonb_build_object('executionId',e.id,'revision',e.revision) from public.companies where id=p_company_id;
end;$$;
create function public.claim_ad_execution_server(p_mode text default 'all') returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;prev text;allowed boolean;action text;facts jsonb;proposal jsonb;
begin
 select * into e from public.company_ad_executions where (p_mode='all' or (p_mode='prepare' and spec is null and desired='run') or (p_mode='execute' and (spec is not null or desired<>'run'))) and (lease_until is null or lease_until<now()) and next_attempt_at<=now() and ((status not in ('draft','paused','cancelled','completed','stale')) or (desired<>'run' and status not in ('paused','cancelled','completed','stale'))) order by case when desired<>'run' then 0 when status='active' then 1 else 2 end,next_attempt_at for update skip locked limit 1;
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
create function public.ad_execution_guard_server(p_id uuid,p_token uuid,p_require_approval boolean default true) returns boolean language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;
begin
 select * into e from public.company_ad_executions where id=p_id and lease_token=p_token and lease_until>now() for update;
 if e.id is null then return false;end if;
 if p_require_approval and (e.desired<>'run' or not private.ad_approval_valid(e) or (e.spec->>'endsAt')::timestamptz<=now()) then return false;end if;
 update public.company_ad_executions set lease_until=now()+interval '5 minutes' where id=p_id;return true;
end;$$;
create function public.ad_step_server(p_id uuid,p_token uuid,p_step text,p_hash text,p_result text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;s private.ad_execution_steps;
begin
 select * into e from public.company_ad_executions where id=p_id and lease_token=p_token and lease_until>now() for update;
 if e.id is null or length(p_step)>40 or p_hash!~'^[a-f0-9]{64}$' then raise exception 'Lease expired' using errcode='40001';end if;
 select * into s from private.ad_execution_steps where execution_id=p_id and revision=e.revision and step=p_step for update;
 if s.execution_id is not null and s.request_hash<>p_hash then raise exception 'External request changed' using errcode='40001';end if;
 if p_result is not null then
  if s.execution_id is null then raise exception 'Step missing';end if;
  if p_result='__rejected__' then update private.ad_execution_steps set status='rejected' where execution_id=p_id and revision=e.revision and step=p_step;
  else
   if length(p_result)>200 then raise exception 'Invalid provider id';end if;
   update private.ad_execution_steps set status='succeeded',external_id=p_result where execution_id=p_id and revision=e.revision and step=p_step;
   update public.company_ad_executions set remote=remote||jsonb_build_object(p_step,p_result),updated_at=now() where id=p_id;
  end if;return jsonb_build_object('status','saved');
 end if;
 if s.status='succeeded' then return jsonb_build_object('status','done','id',s.external_id);end if;
 if not private.ad_approval_valid(e) or e.desired<>'run' then raise exception 'Approval changed' using errcode='40001';end if;
 if s.status='started' then return jsonb_build_object('status','reconcile');end if;
 insert into private.ad_execution_steps(execution_id,revision,step,request_hash,status) values(p_id,e.revision,p_step,p_hash,'started') on conflict(execution_id,revision,step) do update set status='started';
 return jsonb_build_object('status','execute');
end;$$;
create function public.finish_ad_execution_server(p_id uuid,p_token uuid,p_result jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;state text;valid boolean;
begin
 select * into e from public.company_ad_executions where id=p_id and lease_token=p_token and lease_until>now() for update;
 if e.id is null then return false;end if;
 state:=p_result->>'status';if state not in ('draft','scheduled','active','paused','cancelled','completed','blocked','reconciling','stale') then raise exception 'Invalid state';end if;
 if state='draft' then
  if e.spec is not null then raise exception 'Draft already exists';end if;perform private.validate_ad_spec(e,p_result->'spec');
  if not private.journey_valid(e.company_id,5) then state:='stale';end if;
 elsif state in ('scheduled','active') and (e.desired<>'run' or not private.ad_approval_valid(e)) then
  -- Persist the observation, keep the immediate compensating pause queued.
  update public.company_ad_executions set lease_token=null,lease_until=null,next_attempt_at=now(),desired='pause',error='A aprovação mudou durante a execução. Pausa pendente.',error_kind='approval',updated_at=now() where id=p_id;return false;
 end if;
 update public.company_ad_executions set status=state,spec=case when state='draft' then p_result->'spec' else spec end,
 remote=case when p_result->>'complete'='true' then remote||'{"complete":"true"}'::jsonb else remote end,
 observed=coalesce(p_result->'observed',observed),checked_at=case when p_result ? 'observed' then now() else checked_at end,error=left(p_result->>'error',1000),error_kind=left(p_result->>'kind',60),lease_token=null,lease_until=null,
 next_attempt_at=case when state in ('blocked','reconciling') then now()+interval '15 minutes' when state='active' then now()+interval '5 minutes' else now()+interval '20 seconds' end,updated_at=now() where id=p_id;
 if state is distinct from e.status or p_result->>'kind' is distinct from e.error_kind then insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,coalesce(e.approved_by,e.actor_id),'ads.execution',jsonb_build_object('executionId',e.id,'revision',e.revision,'status',state,'errorKind',p_result->>'kind') from public.companies where id=e.company_id;end if;
 return true;
end;$$;
revoke all on function private.queue_paid_execution(),private.ad_journey_basis(uuid),private.ad_permission(uuid,uuid,bigint),private.ad_approval_valid(public.company_ad_executions),private.validate_ad_spec(public.company_ad_executions,jsonb) from public,anon,authenticated;
revoke all on function public.edit_ad_execution(uuid,uuid,integer,jsonb),public.approve_ad_execution(uuid,uuid,integer),public.control_ad_execution(uuid,uuid,integer,text),public.claim_ad_execution_server(text),public.ad_execution_guard_server(uuid,uuid,boolean),public.ad_step_server(uuid,uuid,text,text,text),public.finish_ad_execution_server(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.edit_ad_execution(uuid,uuid,integer,jsonb),public.approve_ad_execution(uuid,uuid,integer),public.control_ad_execution(uuid,uuid,integer,text) to authenticated;
grant execute on function public.claim_ad_execution_server(text),public.ad_execution_guard_server(uuid,uuid,boolean),public.ad_step_server(uuid,uuid,text,text,text),public.finish_ad_execution_server(uuid,uuid,jsonb) to service_role;

create function public.ad_execution_context_server(p_id uuid,p_token uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.company_ad_executions;c public.company_ad_connections;channel public.company_channels;secret text;
begin
 select * into e from public.company_ad_executions where id=p_id and lease_token=p_token and lease_until>now();if e.id is null then raise exception 'Lease expired' using errcode='40001';end if;
 select * into c from public.company_ad_connections where company_id=e.company_id and provider=e.provider and status='connected';
 if c.account_id is null or (e.spec is not null and c.account_id<>e.spec->>'accountId') then raise exception 'Advertising account disconnected or changed' using errcode='40001';end if;
 if e.provider='meta' then
  select * into channel from public.company_channels where company_id=e.company_id and provider='meta' and status='connected' and remote_id=c.source_page;
  if channel.id is null or (e.spec is not null and channel.remote_id<>e.spec->>'pageId') then raise exception 'Meta page changed' using errcode='40001';end if;
  select cipher into secret from private.channel_secrets where channel_id=channel.id;
 else select cipher into secret from private.ad_credentials where company_id=e.company_id and provider=e.provider;end if;
 if secret is null then raise exception 'Reconnect advertising account' using errcode='40001';end if;
 return jsonb_build_object('accountId',c.account_id,'accountName',c.name,'pageId',channel.remote_id,'metadata',channel.metadata,'managerId',c.login_customer_id,'cipher',secret);
end;$$;
revoke all on function public.ad_execution_context_server(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ad_execution_context_server(uuid,uuid) to service_role;

create table public.company_ad_plan_seeds(company_id uuid not null references public.companies(id),profile_version integer not null,actor_id uuid not null,status text not null default 'pending' check(status in ('pending','running','blocked','completed','stale')),token uuid,lease_until timestamptz,attempts integer not null default 0,error text,plan_id uuid,updated_at timestamptz not null default now(),primary key(company_id,profile_version));
alter table public.company_ad_plan_seeds enable row level security;
revoke all on public.company_ad_plan_seeds from public,anon,authenticated;
grant select on public.company_ad_plan_seeds to authenticated;
create policy ad_seeds_read on public.company_ad_plan_seeds for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create function private.queue_ad_plan_seed() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.stage=5 then insert into public.company_ad_plan_seeds(company_id,profile_version,actor_id) values(new.company_id,new.profile_version,new.approved_by) on conflict do nothing;end if;return new;
end;$$;
create trigger queue_ad_plan_seed after insert or update on public.company_marketing_approvals for each row execute function private.queue_ad_plan_seed();
insert into public.company_ad_plan_seeds(company_id,profile_version,actor_id) select company_id,profile_version,approved_by from public.company_marketing_approvals where stage=5 on conflict do nothing;
create function public.claim_ad_plan_seed_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_ad_plan_seeds;facts jsonb;suggestions jsonb;existing uuid;previous text;allowed boolean;
begin
 select * into s from public.company_ad_plan_seeds where (status='pending' or (status='running' and lease_until<now())) and attempts<3 order by updated_at for update skip locked limit 1;
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
create function public.finish_ad_plan_seed_server(p_company_id uuid,p_version integer,p_token uuid,p_budget bigint,p_output jsonb,p_model text,p_error text default null) returns boolean language plpgsql security definer set search_path='' as $$
declare s public.company_ad_plan_seeds;p uuid;total numeric;prev text;allowed boolean;
begin
 perform 1 from public.companies where id=p_company_id for update;
 select * into s from public.company_ad_plan_seeds where company_id=p_company_id and profile_version=p_version and token=p_token and lease_until>now() for update;
 if s.company_id is null then return false;end if;
 prev:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',s.actor_id::text,true);allowed:=private.can_company_action(p_company_id,'marketing.write');perform set_config('request.jwt.claim.sub',coalesce(prev,''),true);
 if not coalesce(allowed,false) or not private.journey_valid(p_company_id,5) or not exists(select 1 from public.company_onboarding where company_id=p_company_id and profile_version=p_version and confirmed_revision=revision) then update public.company_ad_plan_seeds set status='stale',token=null,lease_until=null where company_id=p_company_id and profile_version=p_version;return false;end if;
 if p_output is null then update public.company_ad_plan_seeds set status='blocked',error=left(coalesce(p_error,'Não foi possível preparar as campanhas. Revise o orçamento no onboarding ou gere uma proposta em Tráfego pago.'),500),token=null,lease_until=null where company_id=p_company_id and profile_version=p_version;return false;end if;
 if p_budget is null or p_budget not between 100 and 100000000 or jsonb_typeof(p_output->'campaigns')<>'array' or jsonb_array_length(p_output->'campaigns') not between 1 and 8 then raise exception 'Invalid proposal';end if;
 select sum(round((v->>'investment')::numeric*100)) into total from jsonb_array_elements(p_output->'campaigns') v;
 if total>p_budget or total<=0 or exists(select 1 from jsonb_array_elements(p_output->'campaigns') v where (v->>'investment')::numeric<=0 or v->>'investment' is null or v->>'provider' not in ('meta','google')) then raise exception 'Budget exceeded';end if;
 if exists(select 1 from public.company_paid_plans where company_id=p_company_id and profile_version=p_version and status='ready') then update public.company_ad_plan_seeds set status='completed',token=null,lease_until=null where company_id=p_company_id and profile_version=p_version;return true;end if;
 p:=gen_random_uuid();insert into public.company_paid_plans(id,company_id,actor_id,profile_version,budget,days,status) values(p,p_company_id,s.actor_id,p_version,p_budget/100.0,30,'generating');
 update public.company_paid_plans set output=p_output,model=p_model,status='ready' where id=p;
 update public.company_ad_plan_seeds set status='completed',plan_id=p,token=null,lease_until=null,error=null,updated_at=now() where company_id=p_company_id and profile_version=p_version;return true;
end;$$;
revoke all on function private.queue_ad_plan_seed(),public.claim_ad_plan_seed_server(),public.finish_ad_plan_seed_server(uuid,integer,uuid,bigint,jsonb,text,text) from public,anon,authenticated;
grant execute on function public.claim_ad_plan_seed_server(),public.finish_ad_plan_seed_server(uuid,integer,uuid,bigint,jsonb,text,text) to service_role;

create function public.reserve_ad_copy_server(p_id uuid,p_token uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 update public.company_ad_executions set copy_attempts=copy_attempts+1 where id=p_id and lease_token=p_token and lease_until>now() and spec is null and copy_attempts<3;return found;
end;$$;
revoke all on function public.reserve_ad_copy_server(uuid,uuid) from public,anon,authenticated;
grant execute on function public.reserve_ad_copy_server(uuid,uuid) to service_role;
notify pgrst,'reload schema';
commit;
