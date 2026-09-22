begin;
create table private.management_ingestion_keys(id uuid primary key,company_id uuid not null unique references public.companies(id),token_hash text not null unique,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),revoked_at timestamptz,last_received_at timestamptz,last_observed_at timestamptz);
create table private.management_ingestion_events(key_id uuid references private.management_ingestion_keys(id),event_id uuid,body_hash text not null,received_at timestamptz not null default now(),primary key(key_id,event_id));
revoke all on private.management_ingestion_keys,private.management_ingestion_events from public,anon,authenticated;
create function public.management_ingestion_status(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin if not coalesce(private.can_company_action(p_company_id,'marketing.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 return coalesce((select jsonb_build_object('id',id,'active',revoked_at is null,'createdAt',created_at,'lastReceivedAt',last_received_at,'lastObservedAt',last_observed_at) from private.management_ingestion_keys where company_id=p_company_id),'null'::jsonb);end;$$;
create function public.set_management_ingestion_key(p_company_id uuid,p_id uuid,p_hash text) returns void language plpgsql security definer set search_path='' as $$
begin perform 1 from public.companies where id=p_company_id for update;if not coalesce(private.company_owner(p_company_id),false) or not private.campaign_authorized(p_company_id) then raise exception 'Owner required' using errcode='42501';end if;
 if p_hash is null then update private.management_ingestion_keys set revoked_at=now() where company_id=p_company_id;
 else
 if p_hash!~'^[a-f0-9]{64}$' or p_id is null then raise exception 'Invalid key' using errcode='22023';end if;
 insert into private.management_ingestion_keys(id,company_id,token_hash,created_by) values(p_id,p_company_id,p_hash,auth.uid()) on conflict(company_id) do update set token_hash=excluded.token_hash,created_by=excluded.created_by,created_at=now(),revoked_at=null;
 end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'management.key_changed',jsonb_build_object('revoked',p_hash is null) from public.companies where id=p_company_id;
end;$$;
create function public.ingest_management_students(p_hash text,p_event uuid,p_observed_at timestamptz,p_students jsonb,p_body_hash text) returns jsonb language plpgsql security definer set search_path='' as $$
declare k private.management_ingestion_keys;previous text;n integer;old_hash text;
begin
 select * into k from private.management_ingestion_keys where token_hash=p_hash and revoked_at is null;
 if k.id is null then raise exception 'Invalid integration authorization' using errcode='42501';end if;
 perform 1 from public.companies where id=k.company_id for update;
 select * into k from private.management_ingestion_keys where token_hash=p_hash and revoked_at is null for update;
 if k.id is null or not private.can_run_campaign(k.company_id,k.created_by) then raise exception 'Invalid integration authorization' using errcode='42501';end if;
 if p_event is null or p_observed_at is null or p_observed_at>now()+interval '5 minutes' or p_observed_at<now()-interval '24 hours' or p_body_hash!~'^[a-f0-9]{64}$' then raise exception 'Invalid integration data' using errcode='22023';end if;
 select body_hash into old_hash from private.management_ingestion_events where key_id=k.id and event_id=p_event;if old_hash is not null then if old_hash<>p_body_hash then raise exception 'Event changed' using errcode='40001';end if;return jsonb_build_object('duplicate',true,'imported',0);end if;
 if k.last_observed_at>p_observed_at then raise exception 'Outdated snapshot' using errcode='40001';end if;
 if (select count(*) from private.management_ingestion_events where key_id=k.id and received_at>now()-interval '1 minute')>=10 then raise exception 'Rate limit' using errcode='22023';end if;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',k.created_by::text,true);
 n:=public.import_campaign_students(k.company_id,p_students,'api');perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 update public.campaign_students set updated_at=p_observed_at where company_id=k.company_id and external_id in(select value->>'externalId' from jsonb_array_elements(p_students));
 insert into private.management_ingestion_events(key_id,event_id,body_hash) values(k.id,p_event,p_body_hash);
 update private.management_ingestion_keys set last_received_at=now(),last_observed_at=p_observed_at where id=k.id;
 return jsonb_build_object('duplicate',false,'imported',n);
exception when others then perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);raise;
end;$$;
revoke all on function public.management_ingestion_status(uuid),public.set_management_ingestion_key(uuid,uuid,text) from public,anon;
grant execute on function public.management_ingestion_status(uuid),public.set_management_ingestion_key(uuid,uuid,text) to authenticated;
revoke all on function public.ingest_management_students(text,uuid,timestamptz,jsonb,text) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.ingest_management_students(text,uuid,timestamptz,jsonb,text) to service_role;end if;end;$$;
notify pgrst,'reload schema';
commit;
