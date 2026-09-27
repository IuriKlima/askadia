begin;
alter table public.company_strategy_briefs add column competitor_review_token uuid;
alter table public.company_launch_jobs add column approval_token uuid;
create table public.company_marketing_journeys(company_id uuid not null references public.companies(id),profile_version integer not null,created_at timestamptz not null default now(),primary key(company_id,profile_version),foreign key(company_id,profile_version) references public.company_profile_versions(company_id,version));
create table public.company_marketing_approvals(company_id uuid not null,profile_version integer not null,stage integer not null check(stage between 1 and 5),basis text not null,token uuid not null default gen_random_uuid(),snapshot jsonb not null,approved_by uuid not null references public.profiles(id),approved_at timestamptz not null default now(),primary key(company_id,profile_version,stage),foreign key(company_id,profile_version) references public.company_marketing_journeys(company_id,profile_version));
alter table public.company_marketing_journeys enable row level security;
alter table public.company_marketing_approvals enable row level security;
revoke all on public.company_marketing_journeys,public.company_marketing_approvals from public,anon,authenticated;
grant select on public.company_marketing_journeys,public.company_marketing_approvals to authenticated;
create policy company_read on public.company_marketing_journeys for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create policy company_read on public.company_marketing_approvals for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create function private.journey_after_confirmation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.profile_version>0 and new.confirmed_revision=new.revision then insert into public.company_marketing_journeys(company_id,profile_version) values(new.company_id,new.profile_version) on conflict do nothing;end if;return new;
end;$$;
create trigger journey_after_confirmation after update of confirmed_revision,profile_version on public.company_onboarding for each row execute function private.journey_after_confirmation();
insert into public.company_marketing_journeys(company_id,profile_version) select company_id,profile_version from public.company_onboarding where profile_version>0 and confirmed_revision=revision on conflict do nothing;
-- The review payload and its fingerprint are returned together; hourly refreshes do not silently alter approval.
create function private.competitor_review(c uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'username',username,'label',label,'kind',kind,'snapshot',snapshot,'previous',previous,'status',status,'error',error,'next_attempt_at',next_attempt_at) order by id),'[]'::jsonb) from public.company_instagram_watches where company_id=c
$$;
revoke all on function private.competitor_review(uuid) from public,anon,authenticated;
create function private.journey_basis(c uuid,n integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v integer;data jsonb;prev jsonb;
begin
 select profile_version into v from public.company_onboarding where company_id=c;
 select coalesce(jsonb_agg(jsonb_build_object('stage',stage,'token',token) order by stage),'[]'::jsonb) into prev from public.company_marketing_approvals where company_id=c and profile_version=v and stage<n;
 if n=1 then select coalesce(jsonb_agg(jsonb_build_object('id',id,'username',username,'label',label,'kind',kind) order by id),'[]'::jsonb) into data from public.company_instagram_watches where company_id=c;
 elsif n=2 then select jsonb_build_object('id',id,'generation',generation,'output',output,'analysisCurrent',competitor_review_token is not distinct from (select token from public.company_marketing_approvals where company_id=c and profile_version=v and stage=1)) into data from public.company_strategy_briefs where company_id=c and profile_version=v;
 elsif n=3 then select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'date',i.planned_date,'idea',i.idea,'direction',i.direction,'format',i.format) order by i.position),'[]'::jsonb) into data from public.company_calendar_items i join public.company_strategy_briefs b on b.id=i.brief_id and b.generation=i.generation where i.company_id=c and b.profile_version=v;
 else select case when n=4 then jsonb_build_object('whatsapp',output->'whatsapp','messages',output->'messages') else output->'traffic' end into data from public.company_launch_jobs where company_id=c and profile_version=v and kind='recommendations' and status='completed';end if;
 return jsonb_build_object('profileVersion',v,'previous',prev,'data',data);
end;$$;
create function private.journey_valid(c uuid,n integer) returns boolean language plpgsql stable security definer set search_path='' as $$
declare s public.company_onboarding;k integer;
begin
 select * into s from public.company_onboarding where company_id=c;
 if s.confirmed_revision is distinct from s.revision then return false;end if;
 -- Older callers without a confirmed guided journey retain their existing safeguards.
 if not exists(select 1 from public.company_marketing_journeys where company_id=c and profile_version=s.profile_version) then return true;end if;
 for k in 1..n loop
  if not exists(select 1 from public.company_marketing_approvals a where a.company_id=c and a.profile_version=s.profile_version and a.stage=k and a.basis=md5(private.journey_basis(c,k)::text)) then return false;end if;
 end loop;return true;
end;$$;
create function public.read_marketing_journey(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;steps jsonb:='[]';k integer;b jsonb;a public.company_marketing_approvals;
begin
 if not coalesce(private.can_company_action(p_company_id,'marketing.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 for k in 1..5 loop
  b:=private.journey_basis(p_company_id,k);
  select * into a from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=k;
  steps:=steps||jsonb_build_array(jsonb_build_object('stage',k,'basis',md5(b::text),'data',b->'data','approved',private.journey_valid(p_company_id,k) and a.stage is not null,'approvedAt',a.approved_at));
 end loop;
 return jsonb_build_object('profileVersion',s.profile_version,'confirmed',s.profile_version>0 and s.confirmed_revision=s.revision,'stages',steps,'canApprove',coalesce(private.can_company_action(p_company_id,'strategy.approve'),false),'competitorReview',jsonb_build_object('watches',private.competitor_review(p_company_id),'basis',md5(private.competitor_review(p_company_id)::text)),'analysis',(select snapshot from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=1));
end;$$;
create function public.approve_marketing_stage(p_company_id uuid,p_stage integer,p_basis text,p_limitations text default '',p_evidence_basis text default null) returns void language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;b jsonb;snap jsonb;brief public.company_strategy_briefs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'strategy.approve'),false) then raise exception 'Approval permission required' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if p_stage is null or p_stage not between 1 and 5 or s.profile_version<1 or s.confirmed_revision is distinct from s.revision then raise exception 'Confirm current profile' using errcode='22023';end if;
 if p_stage>1 and not private.journey_valid(p_company_id,p_stage-1) then raise exception 'Approve previous stages first' using errcode='40001';end if;
 if p_stage=1 and p_evidence_basis is distinct from md5(private.competitor_review(p_company_id)::text) then raise exception 'A coleta mudou. Revise os dados atualizados antes de aprovar.' using errcode='40001';end if;
 b:=private.journey_basis(p_company_id,p_stage);if p_basis is distinct from md5(b::text) then raise exception 'Proposal changed; review current version' using errcode='40001';end if;
 -- Repeating the approval of an unchanged version must not invalidate downstream work.
 if private.journey_valid(p_company_id,p_stage) and exists(select 1 from public.company_marketing_approvals a where a.company_id=p_company_id and a.profile_version=s.profile_version and a.stage=p_stage and a.basis=p_basis) then return;end if;
 if p_stage=1 then
  if (not exists(select 1 from public.company_instagram_watches where company_id=p_company_id) or exists(select 1 from public.company_instagram_watches where company_id=p_company_id and snapshot is null)) and length(trim(coalesce(p_limitations,'')))<10 then raise exception 'Review missing competitor data explicitly' using errcode='22023';end if;
  if length(coalesce(p_limitations,''))>1000 then raise exception 'Invalid limitation' using errcode='22023';end if;
  select jsonb_build_object('profiles',coalesce(jsonb_agg(jsonb_build_object('username',username,'label',label,'kind',kind,'snapshot',snapshot) order by id),'[]'::jsonb),'limitations',p_limitations) into snap from public.company_instagram_watches where company_id=p_company_id;
 elsif p_stage=2 then
  select * into brief from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
  if brief.competitor_review_token is distinct from (select token from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=1) then raise exception 'A análise mudou. Gere um novo diagnóstico.' using errcode='40001';end if;
  if brief.output is null or brief.status not in ('review','approved') then raise exception 'Strategy not ready' using errcode='22023';end if;
  update public.company_launch_jobs set status='pending',attempts=0,output=null,token=null,next_attempt_at=now(),updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and kind='recommendations' and status in ('completed','stale','failed');
  if brief.status='review' then perform public.approve_company_strategy(p_company_id,brief.id,brief.generation);end if;snap:=b->'data';
 elsif p_stage=3 then
  if jsonb_array_length(b->'data')=0 or exists(select 1 from jsonb_array_elements(b->'data') x where nullif(x->>'date','') is null or (x->>'date')::date<(now() at time zone 'America/Sao_Paulo')::date+7) then raise exception 'Plan dates at least seven days ahead' using errcode='22023';end if;snap:=b->'data';
 else if p_stage=5 and exists(select 1 from public.company_calendar_items i join public.company_strategy_briefs x on x.id=i.brief_id and x.generation=i.generation where i.company_id=p_company_id and x.profile_version=s.profile_version and i.planned_date<(now() at time zone 'America/Sao_Paulo')::date+7) then raise exception 'Atualize as primeiras datas para reservar sete dias de produção e revisão.' using errcode='22023';end if;
  if b->'data' is null or b->'data'='null'::jsonb then raise exception 'Suggestions not ready' using errcode='22023';end if;snap:=b->'data';end if;
 insert into public.company_marketing_approvals(company_id,profile_version,stage,basis,snapshot,approved_by) values(p_company_id,s.profile_version,p_stage,p_basis,snap,auth.uid())
 on conflict(company_id,profile_version,stage) do update set basis=excluded.basis,snapshot=excluded.snapshot,token=gen_random_uuid(),approved_by=auth.uid(),approved_at=now();
 update public.company_content_preparations set next_attempt_at=now(),updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and status='pending';
 update public.company_launch_jobs set next_attempt_at=now(),updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and status='pending';
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'marketing.stage.approved',jsonb_build_object('stage',p_stage,'profileVersion',s.profile_version,'basis',p_basis) from public.companies where id=p_company_id;
end;$$;
revoke all on function private.journey_after_confirmation(),private.journey_basis(uuid,integer),private.journey_valid(uuid,integer) from public,anon,authenticated;
revoke all on function public.read_marketing_journey(uuid),public.approve_marketing_stage(uuid,integer,text,text,text) from public,anon;
grant execute on function public.read_marketing_journey(uuid),public.approve_marketing_stage(uuid,integer,text,text,text) to authenticated;
-- Additional worker and manual-generation gates follow below.

create or replace function public.claim_content_preparation_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_content_preparations;b public.company_strategy_briefs;i public.company_calendar_items;context jsonb;kind text;run uuid:=gen_random_uuid();lease uuid:=gen_random_uuid();frame_no integer;refs uuid[];d date:=(now() at time zone 'America/Sao_Paulo')::date+7;error_code text;
begin
 select * into j from public.company_content_preparations where (status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now()) order by updated_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;
 if not found then return null;end if;
 select * into j from public.company_content_preparations where id=j.id and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;
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
create or replace function public.finish_content_preparation_server(p_id uuid,p_token uuid,p_result jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.company_content_preparations;saved jsonb;ok boolean:=p_result is not null;
begin
 select * into j from public.company_content_preparations where id=p_id and status='running' and token=p_token and lease_until>now();
 if not found then return false;end if;
 perform 1 from public.companies where id=j.company_id for update;
 select * into j from public.company_content_preparations where id=p_id and status='running' and token=p_token and lease_until>now() for update;
 if not found then return false;end if;
 if not private.preparation_actor(j) or not private.journey_valid(j.company_id,case when j.stage='strategy' then 1 else 5 end) then update public.company_content_preparations set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return false;end if;
 if j.stage='strategy' then
  saved:=public.finish_company_strategy(j.company_id,j.run_id,p_result->'output',coalesce(p_result->>'model','unavailable'),p_result->>'responseId');
  perform public.finish_onboarding_provider(j.company_id,j.run_id,'strategy',case when ok then 'completed' else 'failed' end,coalesce(p_result->'usage','{}'::jsonb));
 elsif j.stage='details' then saved:=private.finish_prepared_details(j.company_id,j.run_id,p_result->'items',p_result->>'model');
 elsif j.stage='design' then saved:=private.finish_prepared_design(j.company_id,j.run_id,p_result->>'mime',p_result->>'model');
 else raise exception 'Invalid preparation stage';end if;
 update public.company_content_preparations set status=case when saved->>'status' in ('stale','superseded') then 'stale' when not ok and attempts>=3 then 'failed' else 'pending' end,
  token=null,run_id=null,lease_until=null,attempts=case when ok then 0 else attempts end,next_attempt_at=now()+case when ok then interval '0 seconds' else interval '1 minute' end,
  error=case when ok then null else 'A geração desta etapa falhou. As peças concluídas foram preservadas.' end,updated_at=now() where id=j.id;
 return true;
end;$$;
create or replace function public.claim_company_launch_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_launch_jobs;t uuid:=gen_random_uuid();s public.company_sites;facts jsonb;
begin
 select * into j from public.company_launch_jobs where (status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now()) order by updated_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;if not found then return null;end if;
 select * into j from public.company_launch_jobs where id=j.id and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
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
create or replace function public.finish_company_launch_server(p_id uuid,p_token uuid,p_output jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.company_launch_jobs;
begin
 select * into j from public.company_launch_jobs where id=p_id and status='running' and token=p_token and lease_until>now();if not found then return false;end if;
 perform 1 from public.companies where id=j.company_id for update;
 select * into j from public.company_launch_jobs where id=p_id and status='running' and token=p_token and lease_until>now() for update;if not found then return false;end if;
 if j.approval_token is distinct from (select token from public.company_marketing_approvals where company_id=j.company_id and profile_version=j.profile_version and stage=case when j.kind='site' then 5 else 2 end) or not private.launch_actor(j) or not private.journey_valid(j.company_id,case when j.kind='site' then 5 else 2 end) then update public.company_launch_jobs set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return false;end if;
 if p_output is null then
 update public.company_launch_jobs set status=case when attempts>=3 then 'failed' else 'pending' end,token=null,lease_until=null,next_attempt_at=now()+interval '1 minute',error='Esta etapa não terminou. As outras entregas foram preservadas.',updated_at=now() where id=j.id;return true;
 end if;
 if j.kind='site' then
  if coalesce((select revision from public.company_sites where company_id=j.company_id),0)<>j.expected_revision then update public.company_launch_jobs set status='stale',token=null,error='O site foi editado durante a geração. A edição foi preservada.',updated_at=now() where id=j.id;return false;end if;
  perform public.save_company_site(j.company_id,j.expected_revision,j.profile_version,p_output);
 elsif jsonb_typeof(p_output)<>'object' or length(p_output::text)>60000 or not(p_output ?& array['summary','whatsapp','messages','traffic','unknowns']) then raise exception 'Invalid recommendations' using errcode='22023';
 end if;
 update public.company_launch_jobs set status='completed',output=case when kind='recommendations' then p_output else null end,token=null,lease_until=null,error=null,updated_at=now() where id=j.id;return true;
end;$$;

create or replace function public.start_company_strategy(p_company_id uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;b public.company_strategy_briefs;
begin
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
create or replace function public.finish_content_details(p_company_id uuid,p_request_id uuid,p_items jsonb,p_model text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.company_content_runs;x jsonb;i public.company_calendar_items;expected jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.company_content_runs where id=p_request_id and company_id=p_company_id and actor_id=auth.uid() and kind='details' and status='running' for update;
 if not private.journey_valid(p_company_id,5) then update public.company_content_runs set status='stale' where id=p_request_id and company_id=p_company_id and actor_id=auth.uid();return jsonb_build_object('status','stale');end if;
 if r.id is null then raise exception 'Run changed' using errcode='40001';end if;
 if p_items is null then update public.company_content_runs set status='failed' where id=r.id;return jsonb_build_object('status','failed');end if;
 if jsonb_typeof(p_items)<>'array' or length(p_items::text)>200000 or jsonb_array_length(p_items)<>jsonb_array_length(r.snapshot->'items') or (select count(distinct y->>'id') from jsonb_array_elements(p_items) y)<>jsonb_array_length(p_items) then raise exception 'Invalid detail output' using errcode='22023';end if;
 for x in select value from jsonb_array_elements(p_items) loop
  select value into expected from jsonb_array_elements(r.snapshot->'items') where value->>'id'=x->>'id';
  select * into i from public.company_calendar_items where id=(x->>'id')::uuid and company_id=p_company_id for update;
  if expected is null or i.id is null or i.revision<>(expected->>'revision')::integer or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then update public.company_content_runs set status='stale' where id=r.id;return jsonb_build_object('status','stale');end if;
  if jsonb_typeof(x->'details')<>'object' or not (x->'details' ?& array['title','caption','cta','designBrief','slides','videoScript','clientMaterials','unknowns','hashtags']) or length(coalesce(x->'details'->>'caption','')) not between 1 and 2200 or length(coalesce(x->'details'->>'designBrief','')) not between 1 and 4000 then raise exception 'Invalid content' using errcode='22023';end if;
 end loop;
 for x in select value from jsonb_array_elements(p_items) loop
  update public.company_calendar_items set details=x->'details',status='draft',revision=revision+1,approved_revision=null,approved_by=null where id=(x->>'id')::uuid returning * into i;
  insert into public.company_calendar_history(item_id,revision,details,planned_date,actor_id) values(i.id,i.revision,i.details,i.planned_date,auth.uid());
 end loop;
 update public.company_content_runs set status='completed',model=p_model where id=r.id;return jsonb_build_object('status','completed');
end;$$;
create or replace function public.finish_content_design(p_company_id uuid,p_request_id uuid,p_mime text,p_model text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.company_content_runs;i public.company_calendar_items;path text;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.company_content_runs where company_id=p_company_id and id=p_request_id and actor_id=auth.uid() and kind='design' and status='running' for update;
 if not private.journey_valid(p_company_id,5) then update public.company_content_runs set status='stale' where id=p_request_id and company_id=p_company_id and actor_id=auth.uid();return jsonb_build_object('status','stale');end if;
 if r.id is null then raise exception 'Run changed' using errcode='40001';end if;
 if p_mime is null then update public.company_content_runs set status='failed' where id=r.id;return jsonb_build_object('status','failed');end if;
 select * into i from public.company_calendar_items where id=r.item_id and company_id=p_company_id;
 if i.revision<>(r.snapshot->'item'->>'revision')::integer or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then update public.company_content_runs set status='stale' where id=r.id;return jsonb_build_object('status','stale');end if;
 path=p_company_id::text||'/generated/'||r.id::text||case p_mime when 'image/png' then '.png' when 'image/jpeg' then '.jpg' when 'image/webp' then '.webp' else '' end;
 if p_mime not in ('image/png','image/jpeg','image/webp') or not exists(select 1 from storage.objects where bucket_id='company-assets' and name=path) then raise exception 'Upload creative first' using errcode='22023';end if;
 insert into public.company_creatives(id,company_id,item_id,revision,frame,mime,object_path,model) values(r.id,p_company_id,i.id,i.revision,r.frame,p_mime,path,p_model);
 update public.company_calendar_items set status='draft',approved_revision=null,approved_by=null where id=i.id;
 update public.company_content_runs set status='completed',model=p_model where id=r.id;return jsonb_build_object('status','completed');
end;$$;

create or replace function public.finish_company_strategy(p_company_id uuid,p_request_id uuid,p_output jsonb,p_model text,p_response_id text) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.company_strategy_briefs;s public.company_onboarding;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and request_id=p_request_id and status='generating' for update;
 if b.id is null then raise exception 'Generation unavailable' using errcode='40001';end if;
 if p_output is not null and (jsonb_typeof(p_output)<>'object' or length(p_output::text)>100000 or not (p_output ?& array['positioning','objectives','calendar','ads','keywords','unknowns']) or jsonb_typeof(p_output->'keywords')<>'array' or jsonb_array_length(p_output->'keywords')<>20 or length(coalesce(p_model,'')) not between 1 and 100 or length(coalesce(p_response_id,'')) not between 1 and 200) then raise exception 'Invalid strategy' using errcode='22023';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 update public.company_strategy_briefs set status=case when b.competitor_review_token is distinct from (select token from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=1) then 'superseded' when s.profile_version<>b.profile_version or s.confirmed_revision is distinct from s.revision then 'superseded' when p_output is null then 'failed' else 'review' end,output=p_output,model=p_model,provider_response_id=p_response_id,generated_at=now() where id=b.id returning * into b;
 if p_output is not null then insert into public.company_strategy_history(company_id,brief_id,generation,profile_version,output,model) values(p_company_id,b.id,b.generation,b.profile_version,p_output,p_model);end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'strategy.generated',jsonb_build_object('briefId',b.id,'generation',b.generation,'status',b.status) from public.companies where id=p_company_id;
 return to_jsonb(b);
end;$$;
create or replace function public.reserve_site_generation(p_company_id uuid,p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not private.journey_valid(p_company_id,5) then raise exception 'Conclua as aprovações da estratégia antes de gerar o site.' using errcode='40001';end if;
 if (select count(*) from private.site_generation_runs where company_id=p_company_id and created_at>date_trunc('day',now()))>=5 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 insert into private.site_generation_runs(id,company_id,actor_id) values(p_id,p_company_id,auth.uid());
end;$$;
notify pgrst,'reload schema';
commit;
