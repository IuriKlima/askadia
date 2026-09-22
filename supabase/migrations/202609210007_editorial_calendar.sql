-- Incremental: preserves all earlier strategy/profile versions and approved material.
create table public.company_calendar_items (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 brief_id uuid not null, generation integer not null, profile_version integer not null,
 position integer not null check(position between 1 and 24), week integer not null check(week between 1 and 5),
 format text not null check(format in ('imagem','carrossel','video')), idea text not null, direction text not null,
 details jsonb, revision integer not null default 1, planned_date date,
 status text not null default 'idea' check(status in ('idea','draft','approved')), approved_revision integer,
 approved_by uuid references public.profiles(id), created_at timestamptz not null default now(),
 foreign key(brief_id,generation) references public.company_strategy_history(brief_id,generation),
 unique(brief_id,generation,position)
);
create table public.company_calendar_history(item_id uuid not null references public.company_calendar_items(id),revision integer not null,details jsonb not null,planned_date date,actor_id uuid references public.profiles(id),created_at timestamptz not null default now(),primary key(item_id,revision));
create table public.company_content_runs(id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),kind text not null check(kind in ('details','design')),item_id uuid references public.company_calendar_items(id),frame integer not null default 0,snapshot jsonb not null,status text not null default 'running' check(status in ('running','completed','failed','stale')),model text,created_at timestamptz not null default now());
create table public.company_creatives(id uuid primary key references public.company_content_runs(id),company_id uuid not null references public.companies(id),item_id uuid not null references public.company_calendar_items(id),revision integer not null,frame integer not null,mime text not null check(mime in ('image/png','image/jpeg','image/webp')),object_path text not null unique,model text not null,created_at timestamptz not null default now());

create function private.calendar_current(c uuid,b uuid,g integer,v integer) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.company_strategy_briefs x join public.company_onboarding s on s.company_id=x.company_id where x.company_id=c and x.id=b and x.generation=g and x.status='approved' and x.approved_generation=g and x.profile_version=v and s.profile_version=v and s.confirmed_revision=s.revision);
$$;
-- Approval history is updated after the brief. Defer materialization until history exists.
create function private.calendar_after_approval() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.approved_at is not null then
  insert into public.company_calendar_items(company_id,brief_id,generation,profile_version,position,week,format,idea,direction)
  select new.company_id,new.brief_id,new.generation,new.profile_version,n::integer,(x->>'week')::integer,x->>'format',x->>'theme',coalesce(x->>'brief','') from jsonb_array_elements(new.output->'calendar') with ordinality e(x,n)
  on conflict(brief_id,generation,position) do nothing;
 end if;return new;
end;$$;
create trigger calendar_on_approval after insert or update of approved_at on public.company_strategy_history for each row execute function private.calendar_after_approval();
-- Preserve existing approvals exactly; never invent missing posts to reach twelve.
insert into public.company_calendar_items(company_id,brief_id,generation,profile_version,position,week,format,idea,direction)
select h.company_id,h.brief_id,h.generation,h.profile_version,n::integer,(x->>'week')::integer,x->>'format',x->>'theme',coalesce(x->>'brief','') from public.company_strategy_history h cross join lateral jsonb_array_elements(h.output->'calendar') with ordinality e(x,n) where h.approved_at is not null on conflict do nothing;

create function public.start_content_run(p_company_id uuid,p_request_id uuid,p_kind text,p_item_id uuid default null,p_frame integer default 0,p_materials uuid[] default array[]::uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
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

create function public.finish_content_details(p_company_id uuid,p_request_id uuid,p_items jsonb,p_model text) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if expected is null or i.id is null or i.revision<>(expected->>'revision')::integer or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then update public.company_content_runs set status='stale' where id=r.id;return jsonb_build_object('status','stale');end if;
  if jsonb_typeof(x->'details')<>'object' or not (x->'details' ?& array['title','caption','cta','designBrief','slides','videoScript','clientMaterials','unknowns','hashtags']) or length(coalesce(x->'details'->>'caption','')) not between 1 and 2200 or length(coalesce(x->'details'->>'designBrief','')) not between 1 and 4000 then raise exception 'Invalid content' using errcode='22023';end if;
 end loop;
 for x in select value from jsonb_array_elements(p_items) loop
  update public.company_calendar_items set details=x->'details',status='draft',revision=revision+1,approved_revision=null,approved_by=null where id=(x->>'id')::uuid returning * into i;
  insert into public.company_calendar_history(item_id,revision,details,planned_date,actor_id) values(i.id,i.revision,i.details,i.planned_date,auth.uid());
 end loop;
 update public.company_content_runs set status='completed',model=p_model where id=r.id;return jsonb_build_object('status','completed');
end;$$;

create function public.edit_calendar_item(p_company_id uuid,p_id uuid,p_revision integer,p_details jsonb,p_date date) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.company_calendar_items;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into i from public.company_calendar_items where company_id=p_company_id and id=p_id for update;
 if i.id is null or i.revision<>p_revision or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then raise exception 'Content changed' using errcode='40001';end if;
 if p_details is null or jsonb_typeof(p_details)<>'object' or length(p_details::text)>24000 or not (p_details ?& array['title','caption','cta','designBrief','slides','videoScript','clientMaterials','unknowns','hashtags']) or length(coalesce(p_details->>'caption','')) not between 1 and 2200 or length(coalesce(p_details->>'designBrief','')) not between 1 and 4000 then raise exception 'Invalid content' using errcode='22023';end if;
 update public.company_calendar_items set details=p_details,planned_date=p_date,revision=revision+1,status='draft',approved_revision=null,approved_by=null where id=i.id returning * into i;
 insert into public.company_calendar_history(item_id,revision,details,planned_date,actor_id) values(i.id,i.revision,i.details,i.planned_date,auth.uid());return to_jsonb(i);
end;$$;

create function public.finish_content_design(p_company_id uuid,p_request_id uuid,p_mime text,p_model text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.company_content_runs;i public.company_calendar_items;path text;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.company_content_runs where company_id=p_company_id and id=p_request_id and actor_id=auth.uid() and kind='design' and status='running' for update;
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

create function public.approve_calendar_item(p_company_id uuid,p_id uuid,p_revision integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.company_calendar_items;n integer;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'content.approve'),false) then raise exception 'Approval permission required' using errcode='42501';end if;
 select * into i from public.company_calendar_items where id=p_id and company_id=p_company_id for update;
 if i.id is null or i.revision<>p_revision or i.details is null or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then raise exception 'Content changed' using errcode='40001';end if;
 select count(distinct frame) into n from public.company_creatives where item_id=i.id and revision=i.revision;
 if i.format='video' or n<(case when i.format='carrossel' then greatest(2,jsonb_array_length(i.details->'slides')) else 1 end) then raise exception 'Final media required' using errcode='22023';end if;
 update public.company_calendar_items set status='approved',approved_revision=revision,approved_by=auth.uid() where id=i.id returning * into i;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'calendar.approved',jsonb_build_object('itemId',i.id,'revision',i.revision,'assets',(select jsonb_agg(id) from public.company_creatives where item_id=i.id and revision=i.revision)) from public.companies where id=p_company_id;return to_jsonb(i);
end;$$;

do $$declare t text;begin
 foreach t in array array['company_calendar_items','company_content_runs','company_creatives'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('create policy tenant_read on public.%I for select to authenticated using(private.can_company_action(company_id,''marketing.read''))',t);
 end loop;end;$$;
alter table public.company_calendar_history enable row level security;
revoke all on public.company_calendar_history from public,anon,authenticated;
grant select on public.company_calendar_history to authenticated;
create policy tenant_read on public.company_calendar_history for select to authenticated using(exists(select 1 from public.company_calendar_items i where i.id=item_id and private.can_company_action(i.company_id,'marketing.read')));
revoke all on function private.calendar_current(uuid,uuid,integer,integer),private.calendar_after_approval() from public,anon,authenticated;
revoke all on function public.start_content_run(uuid,uuid,text,uuid,integer,uuid[]),public.finish_content_details(uuid,uuid,jsonb,text),public.edit_calendar_item(uuid,uuid,integer,jsonb,date),public.finish_content_design(uuid,uuid,text,text),public.approve_calendar_item(uuid,uuid,integer) from public,anon;
grant execute on function public.start_content_run(uuid,uuid,text,uuid,integer,uuid[]),public.finish_content_details(uuid,uuid,jsonb,text),public.edit_calendar_item(uuid,uuid,integer,jsonb,date),public.finish_content_design(uuid,uuid,text,text),public.approve_calendar_item(uuid,uuid,integer) to authenticated;
notify pgrst,'reload schema';
