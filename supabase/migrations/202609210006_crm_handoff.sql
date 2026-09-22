begin;
-- Persistent CRM operations and the human/AI handoff boundary. Channel delivery remains disconnected.
create table public.company_conversations(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,contact_id uuid not null,
 channel text not null default 'manual' check(channel in ('manual','whatsapp','instagram')),
 mode text not null default 'human' check(mode in ('ai','human','closed')),revision integer not null default 0,
 assigned_to uuid references public.profiles(id),triage_summary text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(company_id,id),foreign key(company_id,contact_id) references public.contacts(company_id,id)
);
create table public.company_conversation_notes(id uuid primary key,company_id uuid not null,conversation_id uuid not null,actor_id uuid not null references public.profiles(id),body text not null check(length(trim(body)) between 1 and 6000),created_at timestamptz not null default now(),foreign key(company_id,conversation_id) references public.company_conversations(company_id,id));
create table public.company_reply_jobs(id uuid primary key default gen_random_uuid(),company_id uuid not null,conversation_id uuid not null,conversation_revision integer not null,profile_version integer not null,state text not null default 'pending' check(state in ('pending','claimed','canceled')),created_at timestamptz not null default now(),foreign key(company_id,conversation_id) references public.company_conversations(company_id,id),foreign key(company_id,profile_version) references public.company_profile_versions(company_id,version));
create table public.crm_requests(company_id uuid not null references public.companies(id),request_id uuid not null,actor_id uuid not null references public.profiles(id),result jsonb not null,primary key(company_id,request_id));
create function public.save_crm_contact(p_company_id uuid,p_request_id uuid,p_name text,p_phone text,p_email text,p_interest text) returns jsonb language plpgsql security definer set search_path='' as $$
declare contact public.contacts;opportunity public.opportunities;prior jsonb;r jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_request_id is null or p_name is null or length(trim(p_name)) not between 2 and 150 or length(coalesce(p_phone,''))>20 or (nullif(p_phone,'') is not null and p_phone !~ '^\+[1-9][0-9]{7,14}$') or length(coalesce(p_email,''))>254 or length(coalesce(p_interest,''))>2000 then raise exception 'Invalid contact' using errcode='22023';end if;
 select result into prior from public.crm_requests where company_id=p_company_id and request_id=p_request_id;if found then return prior;end if;
 if nullif(p_phone,'') is not null then select * into contact from public.contacts where company_id=p_company_id and phone_e164=p_phone;end if;
 if contact.id is null then insert into public.contacts(company_id,name,phone_e164,email) values(p_company_id,trim(p_name),nullif(p_phone,''),nullif(p_email,'')) returning * into contact;end if;
 select * into opportunity from public.opportunities where company_id=p_company_id and contact_id=contact.id and stage not in ('lost','enrolled') order by created_at desc limit 1;
 if opportunity.id is null then insert into public.opportunities(company_id,contact_id,interest,original_source) values(p_company_id,contact.id,coalesce(p_interest,''),'manual') returning * into opportunity;end if;
 r=jsonb_build_object('contact',to_jsonb(contact),'opportunity',to_jsonb(opportunity));
 insert into public.crm_requests values(p_company_id,p_request_id,auth.uid(),r);
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'crm.contact_saved',jsonb_build_object('contactId',contact.id,'opportunityId',opportunity.id) from public.companies where id=p_company_id;return r;
end;$$;
create function public.move_crm_opportunity(p_company_id uuid,p_id uuid,p_stage text,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.opportunities;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_stage is null or p_stage not in ('new','in_progress','qualified','referred','scheduled','attended','enrolled','lost') or length(trim(coalesce(p_reason,''))) not between 2 and 2000 then raise exception 'Stage and reason required' using errcode='22023';end if;
 select * into o from public.opportunities where id=p_id and company_id=p_company_id for update;if o.id is null then raise exception 'Opportunity unavailable' using errcode='42501';end if;
 if o.stage=p_stage then return to_jsonb(o);end if;
 update public.opportunities set stage=p_stage where id=p_id returning * into o;
 insert into public.stage_history(company_id,opportunity_id,stage,reason,actor_id) values(p_company_id,p_id,p_stage,p_reason,auth.uid());return to_jsonb(o);
end;$$;
create function public.open_company_conversation(p_company_id uuid,p_contact_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.company_conversations;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) or not exists(select 1 from public.contacts where company_id=p_company_id and id=p_contact_id) then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.company_conversations where company_id=p_company_id and contact_id=p_contact_id and mode<>'closed' order by created_at desc limit 1;
 if c.id is null then insert into public.company_conversations(company_id,contact_id,assigned_to) values(p_company_id,p_contact_id,auth.uid()) returning * into c;end if;return to_jsonb(c);
end;$$;
create function public.set_conversation_mode(p_company_id uuid,p_id uuid,p_revision integer,p_mode text) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.company_conversations;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.company_conversations where id=p_id and company_id=p_company_id for update;
 if c.id is null then raise exception 'Conversation unavailable' using errcode='42501';end if;
 if p_revision is distinct from c.revision then raise exception 'Conversation changed' using errcode='40001';end if;
 -- AI reactivation depends on a connected channel/worker and is deliberately not exposed to a manual conversation.
 if p_mode is null or p_mode not in ('human','closed') then raise exception 'Invalid mode' using errcode='22023';end if;
 update public.company_conversations set mode=p_mode,assigned_to=auth.uid(),revision=revision+1,updated_at=now() where id=p_id returning * into c;
 update public.company_reply_jobs set state='canceled' where company_id=p_company_id and conversation_id=p_id and state in ('pending','claimed');
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'conversation.'||p_mode,jsonb_build_object('conversationId',p_id,'revision',c.revision) from public.companies where id=p_company_id;return to_jsonb(c);
end;$$;
create function public.add_conversation_note(p_company_id uuid,p_id uuid,p_request_id uuid,p_body text) returns jsonb language plpgsql security definer set search_path='' as $$
declare n public.company_conversation_notes;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) or not exists(select 1 from public.company_conversations where id=p_id and company_id=p_company_id and mode='human' and assigned_to=auth.uid()) then raise exception 'Take over the conversation first' using errcode='42501';end if;
 if p_request_id is null or p_body is null or length(trim(p_body)) not between 1 and 6000 then raise exception 'Invalid note' using errcode='22023';end if;
 insert into public.company_conversation_notes values(p_request_id,p_company_id,p_id,auth.uid(),trim(p_body),now()) on conflict do nothing;
 select * into n from public.company_conversation_notes where id=p_request_id and company_id=p_company_id and conversation_id=p_id and actor_id=auth.uid();if n.id is null then raise exception 'Request unavailable' using errcode='42501';end if;return to_jsonb(n);
end;$$;
-- A future consumer must claim immediately before dispatch. It must not trust the job payload's tenant or earlier authorization.
create function public.claim_company_reply(p_company_id uuid,p_job_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_reply_jobs;c public.company_conversations;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into j from public.company_reply_jobs where id=p_job_id and company_id=p_company_id for update;if j.id is null then raise exception 'Job unavailable' using errcode='42501';end if;
 select * into c from public.company_conversations where id=j.conversation_id and company_id=p_company_id for update;
 if j.state<>'pending' or c.mode<>'ai' or c.revision<>j.conversation_revision or not exists(select 1 from public.company_onboarding where company_id=p_company_id and profile_version=j.profile_version and confirmed_revision=revision) then update public.company_reply_jobs set state='canceled' where id=j.id;return null;end if;
 update public.company_reply_jobs set state='claimed' where id=j.id returning * into j;return to_jsonb(j);
end;$$;
do $$declare t text;begin
 foreach t in array array['company_conversations','company_conversation_notes','company_reply_jobs'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('create policy company_read on public.%I for select to authenticated using(private.can_company_action(company_id,''crm.read''))',t);
 end loop;
end;$$;
alter table public.crm_requests enable row level security;revoke all on public.crm_requests from public,anon,authenticated;
revoke all on function public.save_crm_contact(uuid,uuid,text,text,text,text),public.move_crm_opportunity(uuid,uuid,text,text),public.open_company_conversation(uuid,uuid),public.set_conversation_mode(uuid,uuid,integer,text),public.add_conversation_note(uuid,uuid,uuid,text),public.claim_company_reply(uuid,uuid) from public,anon;
grant execute on function public.save_crm_contact(uuid,uuid,text,text,text,text),public.move_crm_opportunity(uuid,uuid,text,text),public.open_company_conversation(uuid,uuid),public.set_conversation_mode(uuid,uuid,integer,text),public.add_conversation_note(uuid,uuid,uuid,text),public.claim_company_reply(uuid,uuid) to authenticated;
-- Bound free onboarding usage across all companies owned/operated by one account as well.
create function private.guard_provider_actor_budget() returns trigger language plpgsql security definer set search_path='' as $$
declare ceiling integer;
begin
 perform 1 from public.profiles where id=new.actor_id for update;
 ceiling=case new.kind when 'interpretation' then 100 when 'places' then 30 when 'strategy' then 4 else 0 end;
 if (select count(*) from public.onboarding_provider_attempts where actor_id=new.actor_id and kind=new.kind and created_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=ceiling then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;return new;
end;$$;
create trigger provider_actor_budget before insert on public.onboarding_provider_attempts for each row execute function private.guard_provider_actor_budget();
revoke all on function private.guard_provider_actor_budget() from public,anon,authenticated;
notify pgrst,'reload schema';
commit;
