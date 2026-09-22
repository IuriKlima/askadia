begin;
create table public.campaign_students(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),external_id text not null,
 name text not null,phone text not null,birthday date,last_attendance timestamptz,status text not null check(status in ('active','inactive')),
 consent boolean not null default false,tag text not null default '',source text not null,updated_at timestamptz not null default now(),
 unique(company_id,external_id),unique(company_id,phone),check(length(external_id) between 1 and 100),check(length(name) between 1 and 150),check(phone~'^\+[1-9][0-9]{7,14}$')
);
create table public.message_campaigns(
 id uuid primary key,company_id uuid not null references public.companies(id),name text not null,revision integer not null default 1,
 trigger text not null check(trigger in ('birthday','absence')),absence_days integer not null check(absence_days between 1 and 365),send_time time not null,
 message text not null check(length(message) between 1 and 2000),tag text not null default '',active_only boolean not null default true,
 start_date date not null,end_date date,max_data_age_days integer not null check(max_data_age_days between 1 and 30),daily_limit integer not null check(daily_limit between 1 and 200),
 status text not null default 'draft' check(status in ('draft','active','paused')),approved_by uuid references public.profiles(id),updated_at timestamptz not null default now(),check(end_date is null or end_date>=start_date)
);
create table public.message_campaign_deliveries(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),campaign_id uuid not null references public.message_campaigns(id),student_id uuid not null references public.campaign_students(id),
 revision integer not null,event_key text not null,phone text not null,body text not null,state text not null check(state in ('reserved','sending','sent','uncertain','canceled')),
 claim_token uuid not null default gen_random_uuid(),provider_id text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(campaign_id,phone,event_key)
);
do $$declare t text;begin foreach t in array array['campaign_students','message_campaigns','message_campaign_deliveries'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy campaign_read on public.%I for select to authenticated using(private.can_company_action(company_id,''marketing.read'') and private.can_company_action(company_id,''crm.read''))',t);
end loop;end;$$;
create function private.campaign_authorized(c uuid) returns boolean language sql stable security definer set search_path='' as $$ select coalesce(private.can_company_action(c,'marketing.write') and private.can_company_action(c,'crm.write'),false); $$;
create function public.import_campaign_students(p_company_id uuid,p_students jsonb,p_source text default 'csv') returns integer language plpgsql security definer set search_path='' as $$
declare s jsonb;n integer:=0;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 if p_source not in ('csv','api','wellhub','totalpass') or jsonb_typeof(p_students) is distinct from 'array' or jsonb_array_length(p_students) not between 1 and 500 then raise exception 'Invalid import' using errcode='22023';end if;
 for s in select value from jsonb_array_elements(p_students) loop
 if jsonb_typeof(s->'consent') is distinct from 'boolean' or s->>'status' not in ('active','inactive') or length(coalesce(s->>'externalId','')) not between 1 and 100 or length(coalesce(s->>'name','')) not between 1 and 150 or coalesce(s->>'phone','')!~'^\+[1-9][0-9]{7,14}$' or (s->>'birthday')::date>current_date or (s->>'lastAttendance')::timestamptz>now()+interval '5 minutes' then raise exception 'Invalid student' using errcode='22023';end if;
 insert into public.campaign_students(company_id,external_id,name,phone,birthday,last_attendance,status,consent,tag,source)
 values(p_company_id,s->>'externalId',s->>'name',s->>'phone',(s->>'birthday')::date,(s->>'lastAttendance')::timestamptz,s->>'status',(s->>'consent')::boolean,left(coalesce(s->>'tag',''),80),p_source)
 on conflict(company_id,external_id) do update set name=excluded.name,phone=excluded.phone,birthday=excluded.birthday,last_attendance=excluded.last_attendance,status=excluded.status,consent=excluded.consent,tag=excluded.tag,source=excluded.source,updated_at=now();n:=n+1;
 end loop;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'campaign.students_imported',jsonb_build_object('count',n,'source',p_source) from public.companies where id=p_company_id;return n;
end;$$;
create function public.save_message_campaign(p_company_id uuid,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.message_campaigns;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.message_campaigns where id=(p_data->>'id')::uuid;
 if c.id is not null and c.company_id<>p_company_id then raise exception 'Access denied' using errcode='42501';end if;
 if coalesce(c.revision,0) is distinct from (p_data->>'revision')::integer then raise exception 'Campaign changed' using errcode='40001';end if;
 if length(trim(coalesce(p_data->>'name',''))) not between 1 and 120 or jsonb_typeof(p_data->'activeOnly') is distinct from 'boolean' or exists(select 1 from regexp_matches(p_data->>'message','\{\{([^}]+)\}\}','g') m where trim(m[1]) not in ('nome','academia','dias_ausente')) then raise exception 'Invalid campaign' using errcode='22023';end if;
 insert into public.message_campaigns(id,company_id,name,trigger,absence_days,send_time,message,tag,active_only,start_date,end_date,max_data_age_days,daily_limit)
 values((p_data->>'id')::uuid,p_company_id,p_data->>'name',p_data->>'trigger',(p_data->>'absenceDays')::integer,(p_data->>'sendTime')::time,p_data->>'message',left(coalesce(p_data->>'tag',''),80),(p_data->>'activeOnly')::boolean,(p_data->>'startDate')::date,(p_data->>'endDate')::date,(p_data->>'maxDataAgeDays')::integer,(p_data->>'dailyLimit')::integer)
 on conflict(id) do update set name=excluded.name,trigger=excluded.trigger,absence_days=excluded.absence_days,send_time=excluded.send_time,message=excluded.message,tag=excluded.tag,active_only=excluded.active_only,start_date=excluded.start_date,end_date=excluded.end_date,max_data_age_days=excluded.max_data_age_days,daily_limit=excluded.daily_limit,revision=message_campaigns.revision+1,status='draft',approved_by=null,updated_at=now() returning * into c;
 update public.message_campaign_deliveries set state='canceled',updated_at=now() where campaign_id=c.id and state='reserved';return to_jsonb(c);
end;$$;
create function private.message_campaign_candidates(p_id uuid,p_now timestamptz) returns table(student_id uuid,name text,phone text,days_absent integer,event_key text) language sql stable security definer set search_path='' as $$
 select s.id,s.name,s.phone,(p_now at time zone co.timezone)::date-(s.last_attendance at time zone co.timezone)::date,
 case when c.trigger='birthday' then 'birthday:'||extract(year from p_now at time zone co.timezone)::text else 'absence:'||s.last_attendance::text end
 from public.message_campaigns c join public.companies co on co.id=c.company_id join public.campaign_students s on s.company_id=c.company_id
 where c.id=p_id and co.archived_at is null and s.consent and (not c.active_only or s.status='active') and (c.tag='' or c.tag=s.tag)
 and s.updated_at>=p_now-make_interval(days=>c.max_data_age_days)
 and (p_now at time zone co.timezone)::date>=c.start_date and (c.end_date is null or (p_now at time zone co.timezone)::date<=c.end_date)
 and ((c.trigger='birthday' and to_char(s.birthday,'MM-DD')=to_char(p_now at time zone co.timezone,'MM-DD')) or (c.trigger='absence' and s.last_attendance is not null and (p_now at time zone co.timezone)::date-(s.last_attendance at time zone co.timezone)::date>=c.absence_days))
 and not exists(select 1 from public.message_campaign_deliveries d where d.campaign_id=c.id and d.phone=s.phone and d.event_key=case when c.trigger='birthday' then 'birthday:'||extract(year from p_now at time zone co.timezone)::text else 'absence:'||s.last_attendance::text end and d.state<>'canceled');
$$;
create function public.preview_message_campaign(p_company_id uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.message_campaigns;begin
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.message_campaigns where company_id=p_company_id and id=p_id;if c.id is null then raise exception 'Unavailable' using errcode='42501';end if;
 return jsonb_build_object('revision',c.revision,'total',(select count(*) from private.message_campaign_candidates(p_id,now())),'students',coalesce((select jsonb_agg(to_jsonb(s)) from(select * from private.message_campaign_candidates(p_id,now()) order by student_id limit 30)s),'[]'::jsonb));
end;$$;
create function public.activate_message_campaign(p_company_id uuid,p_id uuid,p_revision integer,p_active boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 if p_active and not exists(select 1 from public.company_channels where company_id=p_company_id and provider='evolution' and status='connected' and remote_id='askadia-'||p_company_id::text) then raise exception 'Connect WhatsApp first' using errcode='22023';end if;
 update public.message_campaigns set status=case when p_active then 'active' else 'paused' end,approved_by=case when p_active then auth.uid() else null end,updated_at=now() where id=p_id and company_id=p_company_id and revision=p_revision;
 if not found then raise exception 'Campaign changed' using errcode='40001';end if;
 if not p_active then update public.message_campaign_deliveries set state='canceled',updated_at=now() where campaign_id=p_id and state='reserved';end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'campaign.activation',jsonb_build_object('campaignId',p_id,'revision',p_revision,'active',p_active) from public.companies where id=p_company_id;
end;$$;
revoke all on function public.import_campaign_students(uuid,jsonb,text),public.save_message_campaign(uuid,jsonb),public.preview_message_campaign(uuid,uuid),public.activate_message_campaign(uuid,uuid,integer,boolean) from public,anon;
grant execute on function public.import_campaign_students(uuid,jsonb,text),public.save_message_campaign(uuid,jsonb),public.preview_message_campaign(uuid,uuid),public.activate_message_campaign(uuid,uuid,integer,boolean) to authenticated;
revoke all on function private.campaign_authorized(uuid),private.message_campaign_candidates(uuid,timestamptz) from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
