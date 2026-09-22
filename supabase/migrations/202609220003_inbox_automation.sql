begin;
alter table public.company_service_settings add column automatic boolean not null default false,add column automated_by uuid references public.profiles(id),add column enabled_since timestamptz;
alter table public.inbox_handoffs alter column actor_id drop not null;
alter table public.inbox_handoffs add column released_at timestamptz;
create table public.inbox_auto_jobs(company_id uuid not null references public.companies(id),message_id text not null,thread text not null,revision integer not null,profile_version integer not null,token uuid not null default gen_random_uuid(),state text not null check(state in ('generating','dispatching','sent','canceled','failed','uncertain')),body text,provider_id text,handoff boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),primary key(company_id,message_id));
alter table public.inbox_auto_jobs enable row level security;
revoke all on public.inbox_auto_jobs from public,anon,authenticated;
grant select on public.inbox_auto_jobs to authenticated;
create policy auto_job_read on public.inbox_auto_jobs for select to authenticated using(private.can_company_action(company_id,'crm.read'));
create function private.can_automate(company uuid,actor uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;
begin
 if actor is null then return false;end if;
 previous:=current_setting('request.jwt.claim.sub',true);
 perform set_config('request.jwt.claim.sub',actor::text,true);
 allowed:=coalesce(private.can_company_action(company,'marketing.write') and private.can_company_action(company,'crm.write'),false);
 perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);return allowed;
end;$$;
revoke all on function private.can_automate(uuid,uuid) from public,anon,authenticated;
alter function public.save_service_settings(uuid,jsonb) rename to save_service_settings_visual;
revoke all on function public.save_service_settings_visual(uuid,jsonb) from public,anon,authenticated;
create function public.save_service_settings(p_company_id uuid,p_settings jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare saved jsonb;enabled boolean;
begin
 if not coalesce(private.can_company_action(p_company_id,'marketing.write') and private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_settings ? 'automatic' and jsonb_typeof(p_settings->'automatic') is distinct from 'boolean' then raise exception 'Invalid settings' using errcode='22023';end if;
 enabled:=coalesce((p_settings->>'automatic')::boolean,false);
 if enabled and (p_settings->>'channel'<>'whatsapp' or p_settings->>'mode'='human' or private.service_profile(p_company_id) is null) then raise exception 'Automatic channel unavailable' using errcode='22023';end if;
 if enabled and not exists(select 1 from public.company_channels where company_id=p_company_id and provider='evolution' and status='connected' and remote_id='askadia-'||p_company_id::text) then raise exception 'Automatic channel unavailable' using errcode='22023';end if;
 saved:=public.save_service_settings_visual(p_company_id,p_settings);
 update public.company_service_settings set automatic=enabled,automated_by=case when enabled then auth.uid() else automated_by end,enabled_since=case when enabled and not automatic then now() else enabled_since end where company_id=p_company_id and channel=p_settings->>'channel' returning to_jsonb(company_service_settings.*) into saved;
 update public.inbox_auto_jobs set state='canceled',updated_at=now() where company_id=p_company_id and state='generating';
 return saved;
end;$$;
create or replace function public.take_inbox_conversation(p_company_id uuid,p_channel text,p_thread text) returns jsonb language plpgsql security definer set search_path='' as $$
declare h public.inbox_handoffs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if exists(select 1 from public.inbox_auto_jobs where company_id=p_company_id and thread=p_thread and state='dispatching' and updated_at>now()-interval '2 minutes') then raise exception 'Automatic reply in flight' using errcode='40001';end if;
 insert into public.inbox_handoffs(company_id,channel,thread,actor_id) values(p_company_id,p_channel,p_thread,auth.uid()) on conflict(company_id,channel,thread) do update set actor_id=excluded.actor_id,released_at=null,revision=inbox_handoffs.revision+1,updated_at=now() returning * into h;
 update public.inbox_auto_jobs set state='canceled',updated_at=now() where company_id=p_company_id and thread=p_thread and state='generating';return to_jsonb(h);
end;$$;
create function public.release_inbox_conversation(p_company_id uuid,p_thread text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 update public.inbox_handoffs set actor_id=null,released_at=now(),revision=revision+1,updated_at=now() where company_id=p_company_id and channel='whatsapp' and thread=p_thread;
end;$$;
create function public.inbox_auto_targets() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 update public.inbox_auto_jobs set state=case when state='dispatching' then 'uncertain' else 'failed' end,updated_at=now() where state in ('generating','dispatching') and updated_at<now()-interval '2 minutes';
 return coalesce((select jsonb_agg(jsonb_build_object('companyId',s.company_id,'since',s.enabled_since,'instance',c.remote_id)) from public.company_service_settings s join public.company_channels c on c.company_id=s.company_id and c.provider='evolution' where s.channel='whatsapp' and s.automatic and c.status='connected' and c.remote_id='askadia-'||s.company_id::text and private.can_automate(s.company_id,s.automated_by)),'[]'::jsonb);
end;$$;
create function public.inbox_auto_claim(p_company_id uuid,p_thread text,p_message_id text,p_time timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_service_settings;j public.inbox_auto_jobs;v integer;
begin
 perform 1 from public.companies where id=p_company_id for update;
 select * into s from public.company_service_settings where company_id=p_company_id and channel='whatsapp';
 if not coalesce(s.automatic,false) or s.mode='human' or not private.can_automate(p_company_id,s.automated_by) or p_time<=s.enabled_since or p_time<now()-interval '5 minutes' or p_time>now()+interval '1 minute' then return null;end if;
 if p_thread !~ '^[0-9]{6,20}@(s.whatsapp.net|lid)$' or p_message_id is null or length(p_message_id) not between 1 and 200 then return null;end if;
 if exists(select 1 from public.inbox_handoffs where company_id=p_company_id and channel='whatsapp' and thread=p_thread and (released_at is null or p_time<=released_at)) then return null;end if;
 if exists(select 1 from public.inbox_auto_jobs where company_id=p_company_id and thread=p_thread and state in ('generating','dispatching')) then return null;end if;
 if (select count(*) from public.inbox_auto_jobs where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then return null;end if;
 select version into v from public.company_profile_versions where company_id=p_company_id order by version desc limit 1;if v is null then return null;end if;
 insert into public.inbox_auto_jobs(company_id,message_id,thread,revision,profile_version,state) values(p_company_id,p_message_id,p_thread,s.revision,v,'generating') on conflict do nothing returning * into j;
 if j.token is null then return null;end if;
 return jsonb_build_object('token',j.token,'settings',to_jsonb(s),'profile',private.service_profile(p_company_id));
end;$$;
create function public.inbox_auto_prepare(p_company_id uuid,p_message_id text,p_token uuid,p_body text,p_handoff boolean) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.inbox_auto_jobs;s public.company_service_settings;v integer;
begin
 perform 1 from public.companies where id=p_company_id for update;
 select * into j from public.inbox_auto_jobs where company_id=p_company_id and message_id=p_message_id and token=p_token and state='generating';if j.token is null then return false;end if;
 select * into s from public.company_service_settings where company_id=p_company_id and channel='whatsapp';
 select version into v from public.company_profile_versions where company_id=p_company_id order by version desc limit 1;
 if not s.automatic or s.revision<>j.revision or v is distinct from j.profile_version or not private.can_automate(p_company_id,s.automated_by) or exists(select 1 from public.inbox_handoffs where company_id=p_company_id and channel='whatsapp' and thread=j.thread and released_at is null) or not exists(select 1 from public.company_channels where company_id=p_company_id and provider='evolution' and status='connected' and remote_id='askadia-'||p_company_id::text) then
 update public.inbox_auto_jobs set state='canceled',updated_at=now() where company_id=p_company_id and message_id=p_message_id;return false;end if;
 if length(trim(p_body)) not between 1 and 6000 then raise exception 'Invalid reply' using errcode='22023';end if;
 update public.inbox_auto_jobs set state='dispatching',body=p_body,handoff=p_handoff,updated_at=now() where company_id=p_company_id and message_id=p_message_id;return true;
end;$$;
create function public.inbox_auto_finish(p_company_id uuid,p_message_id text,p_token uuid,p_state text,p_provider_id text) returns void language plpgsql security definer set search_path='' as $$
declare j public.inbox_auto_jobs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if p_state not in ('sent','failed','uncertain','canceled') then raise exception 'Invalid state' using errcode='22023';end if;
 update public.inbox_auto_jobs set state=p_state,provider_id=left(p_provider_id,200),updated_at=now() where company_id=p_company_id and message_id=p_message_id and token=p_token and state in ('generating','dispatching') returning * into j;
 if j.handoff and p_state='sent' then insert into public.inbox_handoffs(company_id,channel,thread,actor_id) values(p_company_id,'whatsapp',j.thread,null) on conflict(company_id,channel,thread) do update set actor_id=null,released_at=null,revision=inbox_handoffs.revision+1,updated_at=now();end if;
end;$$;
create function public.inbox_auto_observe_human(p_company_id uuid,p_thread text,p_message_id text,p_time timestamptz) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not exists(select 1 from public.company_service_settings where company_id=p_company_id and channel='whatsapp' and automatic and enabled_since<p_time) then return;end if;
 if exists(select 1 from public.inbox_auto_jobs where company_id=p_company_id and provider_id=p_message_id) then return;end if;
 if exists(select 1 from public.inbox_handoffs where company_id=p_company_id and channel='whatsapp' and thread=p_thread and (released_at is null or released_at>=p_time)) then return;end if;
 insert into public.inbox_handoffs(company_id,channel,thread,actor_id) values(p_company_id,'whatsapp',p_thread,null) on conflict(company_id,channel,thread) do update set actor_id=null,released_at=null,revision=inbox_handoffs.revision+1,updated_at=now();
 update public.inbox_auto_jobs set state='canceled',updated_at=now() where company_id=p_company_id and thread=p_thread and state='generating';
end;$$;
revoke all on function public.inbox_auto_targets(),public.inbox_auto_claim(uuid,text,text,timestamptz),public.inbox_auto_prepare(uuid,text,uuid,text,boolean),public.inbox_auto_finish(uuid,text,uuid,text,text),public.inbox_auto_observe_human(uuid,text,text,timestamptz) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.inbox_auto_targets(),public.inbox_auto_claim(uuid,text,text,timestamptz),public.inbox_auto_prepare(uuid,text,uuid,text,boolean),public.inbox_auto_finish(uuid,text,uuid,text,text),public.inbox_auto_observe_human(uuid,text,text,timestamptz) to service_role;end if;end;$$;
revoke all on function public.save_service_settings(uuid,jsonb),public.release_inbox_conversation(uuid,text) from public,anon;
grant execute on function public.save_service_settings(uuid,jsonb),public.release_inbox_conversation(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
