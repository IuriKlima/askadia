begin;
create table public.company_instagram_watches(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),
 username text not null check(username ~ '^[a-z0-9_][a-z0-9_.]{0,29}$'),label text not null check(length(label) between 1 and 160),kind text not null check(kind in ('local','inspiration')),
 status text not null default 'pending' check(status in ('pending','running','available','unavailable','paused')),token uuid,lease_until timestamptz,next_attempt_at timestamptz not null default now(),
 snapshot jsonb,previous jsonb,error text,created_at timestamptz not null default now(),unique(company_id,username)
);
alter table public.company_instagram_watches enable row level security;
revoke all on public.company_instagram_watches from public,anon,authenticated;
grant select on public.company_instagram_watches to authenticated;
create policy company_read on public.company_instagram_watches for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create index instagram_watch_queue on public.company_instagram_watches(next_attempt_at) where status<>'paused';
create function public.save_instagram_watch(p_company_id uuid,p_username text,p_label text,p_kind text,p_remove boolean default false) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_username is null or p_username !~ '^[a-z0-9_][a-z0-9_.]{0,29}$' or p_username like '%..%' or p_label is null or length(p_label) not between 1 and 160 or p_kind not in ('local','inspiration') then raise exception 'Invalid profile' using errcode='22023';end if;
 if p_remove then delete from public.company_instagram_watches where company_id=p_company_id and username=p_username;return;end if;
 if not exists(select 1 from public.company_instagram_watches where company_id=p_company_id and username=p_username) and (select count(*) from public.company_instagram_watches where company_id=p_company_id)>=10 then raise exception 'Maximum of ten profiles' using errcode='22023';end if;
 insert into public.company_instagram_watches(company_id,actor_id,username,label,kind) values(p_company_id,auth.uid(),p_username,p_label,p_kind)
 on conflict(company_id,username) do update set label=excluded.label,kind=excluded.kind,actor_id=excluded.actor_id,status=case when company_instagram_watches.status='paused' then 'pending' else company_instagram_watches.status end;
end;$$;
create function public.claim_instagram_watch_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.company_instagram_watches;t uuid:=gen_random_uuid();channel jsonb;
begin
 select * into w from public.company_instagram_watches where (status in ('pending','available','unavailable') and next_attempt_at<=now()) or (status='running' and lease_until<now()) order by next_attempt_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=w.company_id for update skip locked;if not found then return null;end if;
 select * into w from public.company_instagram_watches where id=w.id and ((status in ('pending','available','unavailable') and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
 perform set_config('request.jwt.claim.sub',w.actor_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',w.actor_id,'role','authenticated')::text,true);
 if not coalesce(private.can_company_action(w.company_id,'marketing.write'),false) then update public.company_instagram_watches set status='paused',token=null,error='O acesso de quem selecionou o perfil mudou. Selecione o perfil novamente.' where id=w.id;return null;end if;
 channel:=public.read_company_meta_server(w.company_id,w.actor_id,'marketing.write');
 if channel is null or nullif(channel->'metadata'->>'instagramId','') is null then update public.company_instagram_watches set status='unavailable',token=null,next_attempt_at=now()+interval '1 hour',error='Conecte a Página e o Instagram profissional da empresa no onboarding ou em Integrações.' where id=w.id;return null;end if;
 update public.company_instagram_watches set status='running',token=t,lease_until=now()+interval '2 minutes' where id=w.id;
 return jsonb_build_object('id',w.id,'companyId',w.company_id,'token',t,'username',w.username,'actorId',w.actor_id,'channel',channel);
end;$$;
create function public.finish_instagram_watch_server(p_id uuid,p_token uuid,p_snapshot jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare w public.company_instagram_watches;
begin
 select * into w from public.company_instagram_watches where id=p_id and status='running' and token=p_token and lease_until>now();if not found then return false;end if;
 perform 1 from public.companies where id=w.company_id for update;
 select * into w from public.company_instagram_watches where id=p_id and status='running' and token=p_token and lease_until>now() for update;if not found then return false;end if;
 perform set_config('request.jwt.claim.sub',w.actor_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',w.actor_id,'role','authenticated')::text,true);
 if not coalesce(private.can_company_action(w.company_id,'marketing.write'),false) or public.read_company_meta_server(w.company_id,w.actor_id,'marketing.write') is null then update public.company_instagram_watches set status='paused',token=null,error='A conexão ou as permissões mudaram.' where id=w.id;return false;end if;
 if p_snapshot is not null and (jsonb_typeof(p_snapshot)<>'object' or p_snapshot->>'username' is distinct from w.username or length(p_snapshot::text)>40000 or not(p_snapshot ?& array['followers','mediaCount','collectedAt','posts'])) then raise exception 'Invalid snapshot' using errcode='22023';end if;
 update public.company_instagram_watches set status=case when p_snapshot is null then 'unavailable' else 'available' end,token=null,lease_until=null,
 previous=case when p_snapshot is not null then snapshot else previous end,snapshot=coalesce(p_snapshot,snapshot),next_attempt_at=now()+interval '1 hour',
 error=case when p_snapshot is null then 'Consulta indisponível: confira autorização Meta e se o perfil é profissional e público. Dados anteriores foram preservados.' else null end where id=w.id;return true;
end;$$;
revoke all on function public.save_instagram_watch(uuid,text,text,text,boolean) from public,anon;
grant execute on function public.save_instagram_watch(uuid,text,text,text,boolean) to authenticated;
revoke all on function public.claim_instagram_watch_server(),public.finish_instagram_watch_server(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.claim_instagram_watch_server(),public.finish_instagram_watch_server(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
