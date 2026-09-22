begin;
create function private.can_run_campaign(p_company uuid,p_actor uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;
begin
 if p_actor is null then return false;end if;previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);
 allowed:=private.campaign_authorized(p_company);perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);return allowed;
exception when others then perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);raise;
end;$$;
create function public.claim_message_campaign() returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.message_campaigns;co public.companies;s record;d public.message_campaign_deliveries;body text;local_now timestamp;n integer;
begin
 for c in select * from public.message_campaigns where status='active' order by updated_at loop
 -- Shared lock order: company, campaign, delivery, student.
 perform 1 from public.companies where id=c.company_id for update skip locked;
 if not found then continue;end if;
 update public.message_campaign_deliveries set state='uncertain',updated_at=now() where company_id=c.company_id and state='sending' and updated_at<now()-interval '5 minutes';
 update public.message_campaign_deliveries set state='canceled',updated_at=now() where company_id=c.company_id and state='reserved' and updated_at<now()-interval '5 minutes';
 select * into c from public.message_campaigns where id=c.id and status='active' for update;
 if not found then continue;end if;
 if not private.can_run_campaign(c.company_id,c.approved_by) then continue;end if;
 select * into co from public.companies where id=c.company_id;local_now:=now() at time zone co.timezone;
 if local_now::time<c.send_time or local_now>=local_now::date+c.send_time+interval '1 hour' then continue;end if;
 if not exists(select 1 from public.company_channels where company_id=c.company_id and provider='evolution' and status='connected' and remote_id='askadia-'||c.company_id::text) then continue;end if;
 -- At most one outgoing campaign message per company/minute, even across workers.
 perform 1 from public.companies where id=c.company_id for update;
 if exists(select 1 from public.message_campaign_deliveries where company_id=c.company_id and created_at>now()-interval '1 minute' and state<>'canceled') then continue;end if;
 select count(*) into n from public.message_campaign_deliveries where campaign_id=c.id and (created_at at time zone co.timezone)::date=local_now::date and state<>'canceled';if n>=c.daily_limit then continue;end if;
 select * into s from private.message_campaign_candidates(c.id,now()) order by student_id limit 1;if s.student_id is null then continue;end if;
 body:=replace(replace(replace(c.message,'{{nome}}',s.name),'{{academia}}',co.name),'{{dias_ausente}}',coalesce(s.days_absent::text,''));
 insert into public.message_campaign_deliveries(company_id,campaign_id,student_id,revision,event_key,phone,body,state) values(c.company_id,c.id,s.student_id,c.revision,s.event_key,s.phone,body,'reserved')
 on conflict(campaign_id,phone,event_key) do update set revision=excluded.revision,body=excluded.body,state='reserved',claim_token=gen_random_uuid(),created_at=now(),updated_at=now() where message_campaign_deliveries.state='canceled' returning * into d;
 if d.id is not null then return jsonb_build_object('id',d.id,'token',d.claim_token,'companyId',d.company_id,'instance','askadia-'||d.company_id::text,'phone',d.phone,'body',d.body);end if;
 end loop;return null;
end;$$;
create function public.prepare_message_campaign(p_id uuid,p_token uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare d public.message_campaign_deliveries;c public.message_campaigns;s public.campaign_students;co public.companies;
begin
 select * into d from public.message_campaign_deliveries where id=p_id and claim_token=p_token and state='reserved';if d.id is null then return false;end if;
 perform 1 from public.companies where id=d.company_id for update;
 perform 1 from public.message_campaigns where id=d.campaign_id for update;
 select * into d from public.message_campaign_deliveries where id=p_id and claim_token=p_token and state='reserved' for update;if d.id is null then return false;end if;
 select * into c from public.message_campaigns where id=d.campaign_id for update;select * into s from public.campaign_students where id=d.student_id for update;select * into co from public.companies where id=d.company_id;
 if co.archived_at is not null or (now() at time zone co.timezone)::date<c.start_date or (c.end_date is not null and (now() at time zone co.timezone)::date>c.end_date)
 or (now() at time zone co.timezone)::time<c.send_time or (now() at time zone co.timezone)>=(now() at time zone co.timezone)::date+c.send_time+interval '1 hour'
 or c.status<>'active' or c.revision<>d.revision or not private.can_run_campaign(c.company_id,c.approved_by) or not s.consent or s.phone<>d.phone or (c.active_only and s.status<>'active') or (c.tag<>'' and c.tag<>s.tag) or s.updated_at<now()-make_interval(days=>c.max_data_age_days)
 or (c.trigger='absence' and ('absence:'||s.last_attendance::text is distinct from d.event_key or (now() at time zone co.timezone)::date-(s.last_attendance at time zone co.timezone)::date<c.absence_days))
 or (c.trigger='birthday' and (to_char(s.birthday,'MM-DD') is distinct from to_char(now() at time zone co.timezone,'MM-DD') or d.event_key<>'birthday:'||extract(year from now() at time zone co.timezone)::text))
 or not exists(select 1 from public.company_channels where company_id=d.company_id and provider='evolution' and status='connected') then update public.message_campaign_deliveries set state='canceled',updated_at=now() where id=d.id;return false;end if;
 update public.message_campaign_deliveries set state='sending',updated_at=now() where id=d.id;return true;
end;$$;
create function public.finish_message_campaign(p_id uuid,p_token uuid,p_sent boolean,p_provider_id text) returns void language plpgsql security definer set search_path='' as $$
begin update public.message_campaign_deliveries set state=case when p_sent and length(p_provider_id)>0 then 'sent' else 'uncertain' end,provider_id=left(p_provider_id,200),updated_at=now() where id=p_id and claim_token=p_token and state='sending';end;$$;
revoke all on function private.can_run_campaign(uuid,uuid),public.claim_message_campaign(),public.prepare_message_campaign(uuid,uuid),public.finish_message_campaign(uuid,uuid,boolean,text) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.claim_message_campaign(),public.prepare_message_campaign(uuid,uuid),public.finish_message_campaign(uuid,uuid,boolean,text) to service_role;end if;end;$$;
notify pgrst,'reload schema';
commit;
