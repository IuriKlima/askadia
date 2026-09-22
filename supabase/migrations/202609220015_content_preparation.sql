begin;
-- Preparation never grants strategy approval or publication permission.
create function private.calendar_preparable(c uuid,b uuid,g integer,v integer) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.company_strategy_briefs x join public.company_onboarding s on s.company_id=x.company_id where x.company_id=c and x.id=b and x.generation=g and x.status in ('review','approved') and x.output is not null and x.profile_version=v and s.profile_version=v and s.confirmed_revision=s.revision);
$$;
create function private.start_prepared_content(p_company_id uuid,p_request_id uuid,p_kind text,p_item_id uuid default null,p_frame integer default 0,p_materials uuid[] default array[]::uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare snap jsonb;i public.company_calendar_items;b public.company_strategy_briefs;s public.company_onboarding;
begin
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
create function private.finish_prepared_details(p_company_id uuid,p_request_id uuid,p_items jsonb,p_model text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.company_content_runs;x jsonb;i public.company_calendar_items;expected jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.company_content_runs where id=p_request_id and company_id=p_company_id and actor_id=auth.uid() and kind='details' and status='running' for update;
 if r.id is null then raise exception 'Run changed' using errcode='40001';end if;
 if p_items is null then update public.company_content_runs set status='failed' where id=r.id;return jsonb_build_object('status','failed');end if;
 if jsonb_typeof(p_items)<>'array' or length(p_items::text)>200000 or jsonb_array_length(p_items)<>jsonb_array_length(r.snapshot->'items') or (select count(distinct y->>'id') from jsonb_array_elements(p_items) y)<>jsonb_array_length(p_items) then raise exception 'Invalid detail output' using errcode='22023';end if;
 for x in select value from jsonb_array_elements(p_items) loop
  select value into expected from jsonb_array_elements(r.snapshot->'items') where value->>'id'=x->>'id';
  select * into i from public.company_calendar_items where id=(x->>'id')::uuid and company_id=p_company_id for update;
  if expected is null or i.id is null or i.revision<>(expected->>'revision')::integer or not private.calendar_preparable(p_company_id,i.brief_id,i.generation,i.profile_version) then update public.company_content_runs set status='stale' where id=r.id;return jsonb_build_object('status','stale');end if;
  if jsonb_typeof(x->'details')<>'object' or not (x->'details' ?& array['title','caption','cta','designBrief','slides','videoScript','clientMaterials','unknowns','hashtags']) or length(coalesce(x->'details'->>'caption','')) not between 1 and 2200 or length(coalesce(x->'details'->>'designBrief','')) not between 1 and 4000 then raise exception 'Invalid content' using errcode='22023';end if;
 end loop;
 for x in select value from jsonb_array_elements(p_items) loop
  update public.company_calendar_items set details=x->'details',status='draft',revision=revision+1,approved_revision=null,approved_by=null where id=(x->>'id')::uuid returning * into i;
  insert into public.company_calendar_history(item_id,revision,details,planned_date,actor_id) values(i.id,i.revision,i.details,i.planned_date,auth.uid());
 end loop;
 update public.company_content_runs set status='completed',model=p_model where id=r.id;return jsonb_build_object('status','completed');
end;$$;
create function private.finish_prepared_design(p_company_id uuid,p_request_id uuid,p_mime text,p_model text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.company_content_runs;i public.company_calendar_items;path text;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.company_content_runs where company_id=p_company_id and id=p_request_id and actor_id=auth.uid() and kind='design' and status='running' for update;
 if r.id is null then raise exception 'Run changed' using errcode='40001';end if;
 if p_mime is null then update public.company_content_runs set status='failed' where id=r.id;return jsonb_build_object('status','failed');end if;
 select * into i from public.company_calendar_items where id=r.item_id and company_id=p_company_id;
 if i.revision<>(r.snapshot->'item'->>'revision')::integer or not private.calendar_preparable(p_company_id,i.brief_id,i.generation,i.profile_version) then update public.company_content_runs set status='stale' where id=r.id;return jsonb_build_object('status','stale');end if;
 path=p_company_id::text||'/generated/'||r.id::text||case p_mime when 'image/png' then '.png' when 'image/jpeg' then '.jpg' when 'image/webp' then '.webp' else '' end;
 if p_mime not in ('image/png','image/jpeg','image/webp') or not exists(select 1 from storage.objects where bucket_id='company-assets' and name=path) then raise exception 'Upload creative first' using errcode='22023';end if;
 insert into public.company_creatives(id,company_id,item_id,revision,frame,mime,object_path,model) values(r.id,p_company_id,i.id,i.revision,r.frame,p_mime,path,p_model);
 update public.company_calendar_items set status='draft',approved_revision=null,approved_by=null where id=i.id;
 update public.company_content_runs set status='completed',model=p_model where id=r.id;return jsonb_build_object('status','completed');
end;$$;
revoke all on function private.calendar_preparable(uuid,uuid,integer,integer),private.start_prepared_content(uuid,uuid,text,uuid,integer,uuid[]),private.finish_prepared_details(uuid,uuid,jsonb,text),private.finish_prepared_design(uuid,uuid,text,text) from public,anon,authenticated;
create table public.company_content_preparations(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),profile_version integer not null,
 actor_id uuid not null references public.profiles(id),status text not null default 'pending' check(status in ('pending','running','completed','failed','stale')),
 stage text not null default 'strategy',attempts integer not null default 0,token uuid,run_id uuid,lease_until timestamptz,next_attempt_at timestamptz not null default now(),
 brief_id uuid,generation integer,error text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(company_id,profile_version),foreign key(company_id,profile_version) references public.company_profile_versions(company_id,version)
);
alter table public.company_content_preparations enable row level security;
revoke all on public.company_content_preparations from public,anon,authenticated;
grant select on public.company_content_preparations to authenticated;
create policy company_read on public.company_content_preparations for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create index content_preparation_queue on public.company_content_preparations(status,next_attempt_at);
create function public.enqueue_content_preparation(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;j public.company_content_preparations;b public.company_strategy_briefs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if s.profile_version<1 or s.confirmed_revision is distinct from s.revision then raise exception 'Confirm the current profile first' using errcode='22023';end if;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
 insert into public.company_content_preparations(company_id,profile_version,actor_id) values(p_company_id,s.profile_version,auth.uid()) on conflict do nothing;
 select * into j from public.company_content_preparations where company_id=p_company_id and profile_version=s.profile_version for update;
 if j.status in ('failed','stale') or (j.generation is not null and b.generation is distinct from j.generation) then
  update public.company_content_preparations set status='pending',actor_id=auth.uid(),attempts=0,token=null,lease_until=null,next_attempt_at=now(),brief_id=null,generation=null,error=null,updated_at=now() where id=j.id returning * into j;
 end if;
 return jsonb_build_object('id',j.id,'status',j.status,'stage',j.stage);
end;$$;
create function private.queue_after_onboarding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if coalesce(private.can_company_action(new.company_id,'marketing.write'),false) and new.profile_version>0 and new.confirmed_revision=new.revision and (old.profile_version is distinct from new.profile_version or old.confirmed_revision is distinct from new.confirmed_revision) then perform public.enqueue_content_preparation(new.company_id);end if;return new;
end;$$;
create trigger prepare_after_onboarding after update of confirmed_revision,profile_version on public.company_onboarding for each row execute function private.queue_after_onboarding();
revoke all on function private.queue_after_onboarding() from public,anon,authenticated;
revoke all on function public.enqueue_content_preparation(uuid) from public,anon;
grant execute on function public.enqueue_content_preparation(uuid) to authenticated;
create function private.preparation_actor(j public.company_content_preparations) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',j.actor_id,'role','authenticated')::text,true);
 return coalesce(private.can_company_action(j.company_id,'marketing.write'),false) and exists(select 1 from public.company_onboarding s where s.company_id=j.company_id and s.profile_version=j.profile_version and s.confirmed_revision=s.revision);
end;$$;
revoke all on function private.preparation_actor(public.company_content_preparations) from public,anon,authenticated;
create function public.claim_content_preparation_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_content_preparations;b public.company_strategy_briefs;i public.company_calendar_items;context jsonb;kind text;run uuid:=gen_random_uuid();lease uuid:=gen_random_uuid();frame_no integer;refs uuid[];d date:=(now() at time zone 'America/Sao_Paulo')::date;error_code text;
begin
 select * into j from public.company_content_preparations where (status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now()) order by updated_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;
 if not found then return null;end if;
 select * into j from public.company_content_preparations where id=j.id and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;
 if not found then return null;end if;
 if not private.preparation_actor(j) then update public.company_content_preparations set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return null;end if;
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
  if exists(select 1 from public.company_calendar_items where company_id=j.company_id and brief_id=b.id and generation=b.generation and details is null) then kind:='details';context:=private.start_prepared_content(j.company_id,run,'details');
  else
   select c.* into i from public.company_calendar_items c cross join lateral generate_series(0,case when c.format='carrossel' then jsonb_array_length(c.details->'slides')-1 else 0 end) f(n)
    where c.company_id=j.company_id and c.brief_id=b.id and c.generation=b.generation and c.format<>'video' and c.details is not null
    and not exists(select 1 from public.company_creatives a where a.item_id=c.id and a.revision=c.revision and a.frame=f.n) order by c.position,f.n limit 1;
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
create function public.finish_content_preparation_server(p_id uuid,p_token uuid,p_result jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.company_content_preparations;saved jsonb;ok boolean:=p_result is not null;
begin
 select * into j from public.company_content_preparations where id=p_id and status='running' and token=p_token and lease_until>now();
 if not found then return false;end if;
 perform 1 from public.companies where id=j.company_id for update;
 select * into j from public.company_content_preparations where id=p_id and status='running' and token=p_token and lease_until>now() for update;
 if not found then return false;end if;
 if not private.preparation_actor(j) then update public.company_content_preparations set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return false;end if;
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
revoke all on function public.claim_content_preparation_server(),public.finish_content_preparation_server(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.claim_content_preparation_server(),public.finish_content_preparation_server(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
