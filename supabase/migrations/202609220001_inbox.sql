-- Inbox configuration is independent of the legacy manual CRM (006).
begin;
create table public.company_service_settings (
 company_id uuid not null references public.companies(id),channel text not null check(channel in ('whatsapp','instagram','facebook','tiktok')),
 mode text not null default 'human' check(mode in ('human','ai','flow')),prompt text not null default '' check(length(prompt)<=8000),
 rules jsonb not null default '[]' check(jsonb_typeof(rules)='array' and jsonb_array_length(rules)<=12),fallback text not null default '' check(length(fallback)<=2000),
 revision integer not null default 1,updated_at timestamptz not null default now(),primary key(company_id,channel)
);
create table public.company_quick_replies(id uuid primary key,company_id uuid not null references public.companies(id),shortcut text not null check(shortcut ~ '^[a-z0-9_-]{1,30}$'),title text not null check(length(title) between 1 and 80),body text not null check(length(body) between 1 and 3000),unique(company_id,shortcut));
create table public.inbox_handoffs(company_id uuid not null references public.companies(id),channel text not null check(channel in ('whatsapp','instagram','facebook','tiktok')),thread text not null check(length(thread) between 1 and 200),actor_id uuid not null references public.profiles(id),revision integer not null default 1,updated_at timestamptz not null default now(),primary key(company_id,channel,thread));
create table public.inbox_dispatches(id uuid primary key,company_id uuid not null references public.companies(id),thread text not null,actor_id uuid not null references public.profiles(id),body text not null check(length(body) between 1 and 6000),state text not null default 'reserved' check(state in ('reserved','sent','uncertain','failed')),provider_id text,created_at timestamptz not null default now());
create table public.inbox_ai_attempts(id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now());
do $$declare t text;begin foreach t in array array['company_service_settings','company_quick_replies','inbox_handoffs','inbox_dispatches','inbox_ai_attempts'] loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('create policy inbox_read on public.%I for select to authenticated using(private.can_company_action(company_id,''crm.read''))',t);
end loop;end;$$;
-- CRM operators can see connection status, never vault material.
create policy company_channels_crm_read on public.company_channels for select to authenticated using(private.can_company_action(company_id,'crm.read'));
create function public.save_service_settings(p_company_id uuid,p_settings jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_service_settings;rule jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write') and private.can_company_action(p_company_id,'crm.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_settings is null or p_settings->>'channel' is null or p_settings->>'mode' is null or jsonb_typeof(p_settings->'rules') is distinct from 'array' then raise exception 'Invalid settings' using errcode='22023';end if;
 for rule in select value from jsonb_array_elements(p_settings->'rules') loop
 if length(trim(coalesce(rule->>'match',''))) not between 1 and 120 or length(trim(coalesce(rule->>'reply',''))) not between 1 and 2000 or jsonb_typeof(rule->'handoff') is distinct from 'boolean' then raise exception 'Invalid rule' using errcode='22023';end if;end loop;
 select * into s from public.company_service_settings where company_id=p_company_id and channel=p_settings->>'channel';
 if coalesce(s.revision,0) is distinct from (p_settings->>'revision')::integer then raise exception 'Settings changed' using errcode='40001';end if;
 insert into public.company_service_settings(company_id,channel,mode,prompt,rules,fallback) values(p_company_id,p_settings->>'channel',p_settings->>'mode',coalesce(p_settings->>'prompt',''),p_settings->'rules',coalesce(p_settings->>'fallback','')) on conflict(company_id,channel) do update set mode=excluded.mode,prompt=excluded.prompt,rules=excluded.rules,fallback=excluded.fallback,revision=company_service_settings.revision+1,updated_at=now() returning * into s;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'inbox.settings',jsonb_build_object('channel',s.channel,'revision',s.revision) from public.companies where id=p_company_id;
 return to_jsonb(s);
end;$$;
create function public.save_quick_reply(p_company_id uuid,p_reply jsonb) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write') and private.can_company_action(p_company_id,'crm.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (p_reply->>'remove')::boolean then delete from public.company_quick_replies where company_id=p_company_id and id=(p_reply->>'id')::uuid;return;end if;
 if (select count(*) from public.company_quick_replies where company_id=p_company_id)>=100 and not exists(select 1 from public.company_quick_replies where company_id=p_company_id and id=(p_reply->>'id')::uuid) then raise exception 'Reply limit' using errcode='22023';end if;
 insert into public.company_quick_replies values((p_reply->>'id')::uuid,p_company_id,p_reply->>'shortcut',p_reply->>'title',p_reply->>'body') on conflict(id) do update set shortcut=excluded.shortcut,title=excluded.title,body=excluded.body where company_quick_replies.company_id=p_company_id;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
end;$$;
create function public.take_inbox_conversation(p_company_id uuid,p_channel text,p_thread text) returns jsonb language plpgsql security definer set search_path='' as $$
declare h public.inbox_handoffs;
begin
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 insert into public.inbox_handoffs(company_id,channel,thread,actor_id) values(p_company_id,p_channel,p_thread,auth.uid()) on conflict(company_id,channel,thread) do update set actor_id=excluded.actor_id,revision=inbox_handoffs.revision+1,updated_at=now() returning * into h;return to_jsonb(h);
end;$$;
create function public.reserve_inbox_dispatch(p_company_id uuid,p_thread text,p_id uuid,p_body text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) or not exists(select 1 from public.inbox_handoffs where company_id=p_company_id and channel='whatsapp' and thread=p_thread and actor_id=auth.uid()) then raise exception 'Take over first' using errcode='42501';end if;
 if not exists(select 1 from public.company_channels where company_id=p_company_id and provider='evolution' and status='connected' and remote_id='askadia-'||p_company_id::text) then raise exception 'Channel unavailable' using errcode='42501';end if;
 if p_thread !~ '^[0-9]{6,20}@(s.whatsapp.net|lid)$' or p_id is null or length(trim(p_body)) not between 1 and 6000 then raise exception 'Invalid dispatch' using errcode='22023';end if;
 if exists(select 1 from public.inbox_dispatches where id=p_id) then return false;end if;
 if (select count(*) from public.inbox_dispatches where company_id=p_company_id and created_at>now()-interval '1 minute')>=30 then raise exception 'Dispatch rate limit' using errcode='22023';end if;
 insert into public.inbox_dispatches(id,company_id,thread,actor_id,body) values(p_id,p_company_id,p_thread,auth.uid(),trim(p_body));return true;
end;$$;
create function public.finish_inbox_dispatch(p_company_id uuid,p_id uuid,p_state text,p_provider_id text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) or p_state not in ('sent','uncertain','failed') then raise exception 'Access denied' using errcode='42501';end if;
 update public.inbox_dispatches set state=p_state,provider_id=left(p_provider_id,200) where id=p_id and company_id=p_company_id and actor_id=auth.uid() and state='reserved';
end;$$;
create function public.inbox_ai_context(p_company_id uuid,p_channel text) returns jsonb language plpgsql security definer set search_path='' as $$
declare settings public.company_service_settings;profile jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (select count(*) from public.inbox_ai_attempts where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select * into settings from public.company_service_settings where company_id=p_company_id and channel=p_channel;
 if settings.company_id is null or settings.mode='human' then raise exception 'Configure assistance first' using errcode='22023';end if;
 select v.facts into profile from public.company_profile_versions v where v.company_id=p_company_id order by version desc limit 1;
 insert into public.inbox_ai_attempts(company_id,actor_id) values(p_company_id,auth.uid());
 return jsonb_build_object('settings',to_jsonb(settings),'profile',profile);
end;$$;
revoke all on function public.save_service_settings(uuid,jsonb),public.save_quick_reply(uuid,jsonb),public.take_inbox_conversation(uuid,text,text),public.reserve_inbox_dispatch(uuid,text,uuid,text),public.finish_inbox_dispatch(uuid,uuid,text,text),public.inbox_ai_context(uuid,text) from public,anon;
grant execute on function public.save_service_settings(uuid,jsonb),public.save_quick_reply(uuid,jsonb),public.take_inbox_conversation(uuid,text,text),public.reserve_inbox_dispatch(uuid,text,uuid,text),public.finish_inbox_dispatch(uuid,uuid,text,text),public.inbox_ai_context(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
