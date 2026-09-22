create table public.company_channels(id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),provider text not null check(provider in ('meta','evolution')),remote_id text not null,name text not null,status text not null check(status in ('pending','connected','disconnected')),metadata jsonb not null default '{}',updated_at timestamptz not null default now(),unique(company_id,provider),unique(provider,remote_id));
create table private.channel_secrets(channel_id uuid primary key references public.company_channels(id),cipher text not null);
create table private.meta_sessions(id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),state_hash text not null,cipher text,consumed boolean not null default false,expires_at timestamptz not null default now()+interval '10 minutes');
revoke all on private.channel_secrets,private.meta_sessions from public,anon,authenticated;
alter table public.company_channels enable row level security;
revoke all on public.company_channels from public,anon,authenticated;
grant select on public.company_channels to authenticated;
create policy company_channels_read on public.company_channels for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create function public.begin_meta_session(p_company_id uuid,p_id uuid,p_hash text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 if p_hash!~'^[a-f0-9]{64}$' then raise exception 'Invalid state' using errcode='22023';end if;
 delete from private.meta_sessions where actor_id=auth.uid() and company_id=p_company_id;
 insert into private.meta_sessions(id,company_id,actor_id,state_hash) values(p_id,p_company_id,auth.uid(),p_hash);
end;$$;
create function public.consume_meta_session(p_id uuid,p_hash text) returns uuid language plpgsql security definer set search_path='' as $$
declare s private.meta_sessions;
begin
 select * into s from private.meta_sessions where id=p_id and actor_id=auth.uid() and state_hash=p_hash and not consumed and expires_at>now() for update;
 if s.id is null or not coalesce(private.company_owner(s.company_id),false) then raise exception 'OAuth state unavailable' using errcode='42501';end if;
 update private.meta_sessions set consumed=true where id=s.id;return s.company_id;
end;$$;
create function public.save_meta_selection(p_id uuid,p_cipher text) returns void language plpgsql security definer set search_path='' as $$
begin
 if length(p_cipher) not between 10 and 200000 then raise exception 'Invalid token' using errcode='22023';end if;
 update private.meta_sessions set cipher=p_cipher where id=p_id and actor_id=auth.uid() and consumed and expires_at>now() and private.company_owner(company_id);
 if not found then raise exception 'OAuth state unavailable' using errcode='42501';end if;
end;$$;
create function public.read_meta_selection(p_company_id uuid,p_id uuid) returns text language plpgsql security definer set search_path='' as $$
declare c text;begin
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 select cipher into c from private.meta_sessions where company_id=p_company_id and id=p_id and actor_id=auth.uid() and consumed and expires_at>now();
 if c is null then raise exception 'OAuth state unavailable' using errcode='42501';end if;return c;
end;$$;
create function public.save_company_channel(p_company_id uuid,p_provider text,p_remote text,p_name text,p_status text,p_metadata jsonb,p_cipher text,p_session uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.company_channels;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 if p_provider not in ('meta','evolution') or length(p_remote) not between 1 and 150 or length(p_name) not between 1 and 200 or p_status not in ('pending','connected','disconnected') or length(p_metadata::text)>12000 or length(p_cipher)>200000 then raise exception 'Invalid connection' using errcode='22023';end if;
 if p_provider='evolution' and p_remote<>'askadia-'||p_company_id::text then raise exception 'Company instance required' using errcode='22023';end if;
 if p_provider='meta' and p_status<>'disconnected' and not exists(select 1 from private.meta_sessions where id=p_session and company_id=p_company_id and actor_id=auth.uid() and consumed and expires_at>now() and cipher is not null) then raise exception 'OAuth authorization required' using errcode='42501';end if;
 insert into public.company_channels(company_id,provider,remote_id,name,status,metadata) values(p_company_id,p_provider,p_remote,p_name,p_status,p_metadata) on conflict(company_id,provider) do update set remote_id=excluded.remote_id,name=excluded.name,status=excluded.status,metadata=excluded.metadata,updated_at=now() returning * into c;
 if p_status='disconnected' then delete from private.channel_secrets where channel_id=c.id;else insert into private.channel_secrets values(c.id,p_cipher) on conflict(channel_id) do update set cipher=excluded.cipher;end if;
 if p_provider='meta' then delete from private.meta_sessions where id=p_session and company_id=p_company_id;end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'channel.'||p_status,jsonb_build_object('provider',p_provider,'channelId',c.id) from public.companies where id=p_company_id;return to_jsonb(c);
end;$$;
create function public.read_channel_secret(p_company_id uuid,p_provider text) returns text language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 return (select s.cipher from private.channel_secrets s join public.company_channels c on c.id=s.channel_id where c.company_id=p_company_id and c.provider=p_provider and c.status<>'disconnected');
end;$$;
create function public.disconnect_company_channel(p_company_id uuid,p_provider text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 delete from private.channel_secrets where channel_id in(select id from public.company_channels where company_id=p_company_id and provider=p_provider);
 update public.company_channels set status='disconnected',metadata='{}',updated_at=now() where company_id=p_company_id and provider=p_provider;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'channel.disconnected',jsonb_build_object('provider',p_provider) from public.companies where id=p_company_id;
end;$$;
revoke all on function public.begin_meta_session(uuid,uuid,text),public.consume_meta_session(uuid,text),public.save_meta_selection(uuid,text),public.read_meta_selection(uuid,uuid),public.save_company_channel(uuid,text,text,text,text,jsonb,text,uuid),public.read_channel_secret(uuid,text),public.disconnect_company_channel(uuid,text) from public,anon;
grant execute on function public.begin_meta_session(uuid,uuid,text),public.consume_meta_session(uuid,text),public.save_meta_selection(uuid,text),public.read_meta_selection(uuid,uuid),public.save_company_channel(uuid,text,text,text,text,jsonb,text,uuid),public.read_channel_secret(uuid,text),public.disconnect_company_channel(uuid,text) to authenticated;
notify pgrst,'reload schema';
