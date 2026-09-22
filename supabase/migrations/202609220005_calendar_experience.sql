begin;
update storage.buckets set file_size_limit=52428800,allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf','video/mp4'] where id='company-assets';
create table public.company_final_videos(id uuid primary key,company_id uuid not null references public.companies(id),item_id uuid not null references public.company_calendar_items(id),revision integer not null,object_path text not null unique,size bigint not null check(size between 1 and 52428800),name text not null,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
alter table public.company_final_videos enable row level security;revoke all on public.company_final_videos from public,anon,authenticated;grant select on public.company_final_videos to authenticated;
create policy video_read on public.company_final_videos for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create function public.finish_calendar_video(p_company_id uuid,p_item uuid,p_revision integer,p_upload uuid,p_size bigint,p_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.company_calendar_items;path text;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into i from public.company_calendar_items where company_id=p_company_id and id=p_item;
 if i.id is null or i.revision<>p_revision or i.format<>'video' or i.details is null or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then raise exception 'Content changed' using errcode='40001';end if;
 path:=p_company_id::text||'/final-video/'||p_upload::text||'.mp4';
 if not exists(select 1 from storage.objects where bucket_id='company-assets' and name=path) then raise exception 'Upload video first' using errcode='22023';end if;
 update public.company_calendar_items set revision=revision+1,status='draft',approved_revision=null,approved_by=null where id=i.id returning * into i;
 insert into public.company_final_videos values(p_upload,p_company_id,i.id,i.revision,path,p_size,left(p_name,150),auth.uid(),now());
 insert into public.company_calendar_history(item_id,revision,details,planned_date,actor_id) values(i.id,i.revision,i.details,i.planned_date,auth.uid());
 return to_jsonb(i);
end;$$;
create or replace function public.approve_calendar_item(p_company_id uuid,p_id uuid,p_revision integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.company_calendar_items;n integer;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'content.approve'),false) then raise exception 'Approval permission required' using errcode='42501';end if;
 select * into i from public.company_calendar_items where id=p_id and company_id=p_company_id for update;
 if i.id is null or i.revision<>p_revision or i.details is null or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) then raise exception 'Content changed' using errcode='40001';end if;
 if i.format='video' then
 if not exists(select 1 from public.company_final_videos where company_id=p_company_id and item_id=i.id and revision=i.revision) then raise exception 'Final media required' using errcode='22023';end if;
 else
 select count(distinct frame) into n from public.company_creatives where item_id=i.id and revision=i.revision;
 if n<(case when i.format='carrossel' then greatest(2,jsonb_array_length(i.details->'slides')) else 1 end) then raise exception 'Final media required' using errcode='22023';end if;
 end if;
 update public.company_calendar_items set status='approved',approved_revision=revision,approved_by=auth.uid() where id=i.id returning * into i;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'calendar.approved',jsonb_build_object('itemId',i.id,'revision',i.revision) from public.companies where id=p_company_id;return to_jsonb(i);
end;$$;
create table public.calendar_date_runs(id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),month date not null,snapshot jsonb not null,status text not null default 'running',created_at timestamptz not null default now());
alter table public.calendar_date_runs enable row level security;revoke all on public.calendar_date_runs from public,anon,authenticated;
create function public.start_calendar_dates(p_company_id uuid,p_id uuid,p_month date) returns jsonb language plpgsql security definer set search_path='' as $$
declare items jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_month<>date_trunc('month',p_month)::date or p_month<date_trunc('month',now())::date or p_month>date_trunc('month',now())::date+interval '12 months' then raise exception 'Invalid planning month' using errcode='22023';end if;
 if exists(select 1 from public.calendar_date_runs where company_id=p_company_id and status='running' and created_at>now()-interval '2 minutes') then raise exception 'Generation running' using errcode='40001';end if;
 if (select count(*) from public.calendar_date_runs where company_id=p_company_id and created_at>date_trunc('day',now()))>=4 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select jsonb_agg(jsonb_build_object('id',id,'revision',revision,'idea',idea,'format',format,'week',week,'position',position)) into items from public.company_calendar_items i where company_id=p_company_id and planned_date is null and private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version);
 if items is null then raise exception 'No pending dates' using errcode='22023';end if;
 insert into public.calendar_date_runs(id,company_id,actor_id,month,snapshot) values(p_id,p_company_id,auth.uid(),p_month,items);
 return jsonb_build_object('month',p_month,'items',items,'facts',(select facts from public.company_profile_versions where company_id=p_company_id order by version desc limit 1));
end;$$;
create function public.finish_calendar_dates(p_company_id uuid,p_id uuid,p_dates jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.calendar_date_runs;d jsonb;i public.company_calendar_items;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.calendar_date_runs where id=p_id and company_id=p_company_id and actor_id=auth.uid() and status='running' for update;if r.id is null then raise exception 'Run changed' using errcode='40001';end if;
 if p_dates is null then update public.calendar_date_runs set status='failed' where id=r.id;return jsonb_build_object('status','failed');end if;
 if jsonb_typeof(p_dates) is distinct from 'array' or jsonb_array_length(p_dates)<>jsonb_array_length(r.snapshot) or (select count(distinct value->>'id') from jsonb_array_elements(p_dates))<>jsonb_array_length(r.snapshot) then raise exception 'Invalid dates' using errcode='22023';end if;
 for d in select value from jsonb_array_elements(p_dates) loop
  if not coalesce(d->>'date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$',false) then raise exception 'Invalid date' using errcode='22023';end if;
  if not exists(select 1 from jsonb_array_elements(r.snapshot) s where s->>'id'=d->>'id') or (d->>'date')::date<r.month or (d->>'date')::date>=r.month+interval '1 month' or (d->>'date')::date<(now() at time zone 'America/Sao_Paulo')::date then raise exception 'Invalid date' using errcode='22023';end if;
  select * into i from public.company_calendar_items where company_id=p_company_id and id=(d->>'id')::uuid;
  if i.planned_date is not null or not private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version) or not exists(select 1 from jsonb_array_elements(r.snapshot) s where (s->>'id')::uuid=i.id and (s->>'revision')::integer=i.revision) then raise exception 'Content changed' using errcode='40001';end if;
  update public.company_calendar_items set planned_date=(d->>'date')::date where id=i.id;
 end loop;
 update public.calendar_date_runs set status='completed' where id=r.id;return jsonb_build_object('status','completed');
end;$$;
create function public.move_calendar_date(p_company_id uuid,p_item uuid,p_revision integer,p_date date) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_date is null or p_date<(now() at time zone 'America/Sao_Paulo')::date or p_date>current_date+400 then raise exception 'Invalid date' using errcode='22023';end if;
 update public.company_calendar_items i set planned_date=p_date where company_id=p_company_id and id=p_item and revision=p_revision and private.calendar_current(p_company_id,i.brief_id,i.generation,i.profile_version);if not found then raise exception 'Content changed' using errcode='40001';end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'calendar.date',jsonb_build_object('itemId',p_item,'date',p_date) from public.companies where id=p_company_id;
end;$$;
revoke all on function public.finish_calendar_video(uuid,uuid,integer,uuid,bigint,text),public.start_calendar_dates(uuid,uuid,date),public.finish_calendar_dates(uuid,uuid,jsonb),public.move_calendar_date(uuid,uuid,integer,date) from public,anon;
grant execute on function public.finish_calendar_video(uuid,uuid,integer,uuid,bigint,text),public.start_calendar_dates(uuid,uuid,date),public.finish_calendar_dates(uuid,uuid,jsonb),public.move_calendar_date(uuid,uuid,integer,date) to authenticated;
notify pgrst,'reload schema';
commit;
