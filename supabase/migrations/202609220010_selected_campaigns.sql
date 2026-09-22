begin;
alter table public.message_campaigns drop constraint message_campaigns_trigger_check;
alter table public.message_campaigns add constraint message_campaigns_trigger_check check(trigger in ('birthday','absence','selected'));
alter table public.message_campaigns add column recipient_ids uuid[] not null default '{}';
alter function public.save_message_campaign(uuid,jsonb) rename to save_message_campaign_base;
revoke all on function public.save_message_campaign_base(uuid,jsonb) from public,anon,authenticated;
create function public.save_message_campaign(p_company_id uuid,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare saved jsonb;ids uuid[];
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 if p_data->>'trigger'='selected' then
 if jsonb_typeof(p_data->'recipientIds') is distinct from 'array' or jsonb_array_length(p_data->'recipientIds') not between 1 and 500 then raise exception 'Select recipients' using errcode='22023';end if;
 select array_agg(distinct value::uuid) into ids from jsonb_array_elements_text(p_data->'recipientIds');
 if exists(select 1 from unnest(ids) chosen(recipient_id) where not exists(select 1 from public.campaign_students s where s.id=chosen.recipient_id and s.company_id=p_company_id)) then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 saved:=public.save_message_campaign_base(p_company_id,p_data);
 update public.message_campaigns set recipient_ids=coalesce(ids,'{}'),active_only=case when trigger='selected' then false else active_only end where id=(p_data->>'id')::uuid returning to_jsonb(message_campaigns.*) into saved;
 return saved;
end;$$;
revoke all on function public.save_message_campaign(uuid,jsonb) from public,anon;
grant execute on function public.save_message_campaign(uuid,jsonb) to authenticated;
alter function private.message_campaign_candidates(uuid,timestamptz) rename to recurring_message_candidates;
create function private.message_campaign_candidates(p_id uuid,p_now timestamptz) returns table(student_id uuid,name text,phone text,days_absent integer,event_key text) language sql stable security definer set search_path='' as $$
 select * from private.recurring_message_candidates(p_id,p_now)
 union all
 select s.id,s.name,s.phone,null::integer,'selected:'||c.id::text
 from public.message_campaigns c join public.companies co on co.id=c.company_id join public.campaign_students s on s.company_id=c.company_id and s.id=any(c.recipient_ids)
 where c.id=p_id and c.trigger='selected' and co.archived_at is null and s.consent
 and (c.tag='' or c.tag=s.tag) and s.updated_at>=p_now-make_interval(days=>c.max_data_age_days)
 and (p_now at time zone co.timezone)::date>=c.start_date and (c.end_date is null or (p_now at time zone co.timezone)::date<=c.end_date)
 and not exists(select 1 from public.message_campaign_deliveries d where d.campaign_id=c.id and d.phone=s.phone and d.event_key='selected:'||c.id::text and d.state<>'canceled');
$$;
revoke all on function private.message_campaign_candidates(uuid,timestamptz) from public,anon,authenticated;
-- The existing prepare function revalidates consent, phone, dates and permissions.
alter function public.prepare_message_campaign(uuid,uuid) rename to prepare_message_campaign_base;
revoke all on function public.prepare_message_campaign_base(uuid,uuid) from public,anon,authenticated;
create function public.prepare_message_campaign(p_id uuid,p_token uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare d public.message_campaign_deliveries;c public.message_campaigns;
begin
 select * into d from public.message_campaign_deliveries where id=p_id and claim_token=p_token and state='reserved';if d.id is null then return false;end if;
 perform 1 from public.companies where id=d.company_id for update;
 select * into c from public.message_campaigns where id=d.campaign_id for update;
 if c.trigger='selected' and (not d.student_id=any(c.recipient_ids) or d.event_key<>'selected:'||c.id::text) then update public.message_campaign_deliveries set state='canceled' where id=d.id;return false;end if;
 return public.prepare_message_campaign_base(p_id,p_token);
end;$$;
revoke all on function public.prepare_message_campaign(uuid,uuid) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then revoke all on function public.prepare_message_campaign_base(uuid,uuid) from service_role;grant execute on function public.prepare_message_campaign(uuid,uuid) to service_role;end if;end;$$;
-- Explicit consent registration; synchronizing WhatsApp alone never opts contacts in.
create function public.register_campaign_contacts(p_company_id uuid,p_contacts uuid[],p_evidence text) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.contacts;s public.campaign_students;ids uuid[]:='{}';
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 if coalesce(array_length(p_contacts,1),0) not between 1 and 500 or length(trim(coalesce(p_evidence,''))) not between 5 and 500 then raise exception 'Consent evidence required' using errcode='22023';end if;
 if exists(select 1 from unnest(p_contacts) chosen(contact_id) where not exists(select 1 from public.contacts c where c.company_id=p_company_id and c.id=chosen.contact_id and c.phone_e164~'^\+[1-9][0-9]{7,14}$')) then raise exception 'Invalid contact' using errcode='22023';end if;
 for c in select * from public.contacts where company_id=p_company_id and id=any(p_contacts) loop
 select * into s from public.campaign_students where company_id=p_company_id and phone=c.phone_e164;
 if s.id is null then insert into public.campaign_students(company_id,external_id,name,phone,status,consent,source) values(p_company_id,'crm:'||c.id::text,c.name,c.phone_e164,'inactive',true,'crm') returning * into s;
 else update public.campaign_students set consent=true,updated_at=now() where id=s.id returning * into s;end if;
 ids:=array_append(ids,s.id);
 end loop;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'campaign.consent_recorded',jsonb_build_object('contacts',p_contacts,'evidence',trim(p_evidence)) from public.companies where id=p_company_id;
 return to_jsonb(ids);
end;$$;
create function public.revoke_campaign_contact(p_company_id uuid,p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not private.campaign_authorized(p_company_id) then raise exception 'Access denied' using errcode='42501';end if;
 update public.campaign_students set consent=false,updated_at=now() where company_id=p_company_id and id=p_id;
 update public.message_campaign_deliveries set state='canceled' where company_id=p_company_id and student_id=p_id and state='reserved';
end;$$;
revoke all on function public.register_campaign_contacts(uuid,uuid[],text),public.revoke_campaign_contact(uuid,uuid) from public,anon;
grant execute on function public.register_campaign_contacts(uuid,uuid[],text),public.revoke_campaign_contact(uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
