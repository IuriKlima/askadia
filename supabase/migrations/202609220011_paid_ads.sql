begin;
create table public.company_ad_connections(company_id uuid not null references public.companies(id),provider text not null check(provider in ('meta','google')),account_id text,name text not null default '',source_page text,status text not null default 'pending' check(status in ('pending','connected','disconnected')),updated_at timestamptz not null default now(),primary key(company_id,provider));
create table private.ad_credentials(company_id uuid not null,provider text not null,cipher text not null,primary key(company_id,provider),foreign key(company_id,provider) references public.company_ad_connections(company_id,provider));
create table private.google_ads_sessions(id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null,state_hash text not null,consumed boolean not null default false,expires_at timestamptz not null default now()+interval '10 minutes');
create table public.company_paid_plans(id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null,profile_version integer not null,budget numeric not null check(budget>0 and budget<=1000000),days integer not null check(days between 1 and 90),status text not null default 'generating' check(status in ('generating','ready','failed')),output jsonb,model text,created_at timestamptz not null default now());
alter table public.company_ad_connections enable row level security;
alter table public.company_paid_plans enable row level security;
revoke all on public.company_ad_connections,public.company_paid_plans from public,anon,authenticated;
grant select on public.company_ad_connections,public.company_paid_plans to authenticated;
create policy ad_connections_read on public.company_ad_connections for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create policy paid_plans_read on public.company_paid_plans for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
revoke all on private.ad_credentials,private.google_ads_sessions from public,anon,authenticated;
create function public.begin_google_ads(p_company_id uuid,p_id uuid,p_hash text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 if p_hash!~'^[a-f0-9]{64}$' then raise exception 'Invalid state' using errcode='22023';end if;
 delete from private.google_ads_sessions where company_id=p_company_id and actor_id=auth.uid();
 insert into private.google_ads_sessions(id,company_id,actor_id,state_hash) values(p_id,p_company_id,auth.uid(),p_hash);
end;$$;
create function public.consume_google_ads(p_id uuid,p_hash text) returns uuid language plpgsql security definer set search_path='' as $$
declare s private.google_ads_sessions;begin
 select * into s from private.google_ads_sessions where id=p_id and actor_id=auth.uid() and state_hash=p_hash and not consumed and expires_at>now() for update;
 if s.id is null or not coalesce(private.company_owner(s.company_id),false) then raise exception 'OAuth state unavailable' using errcode='42501';end if;
 update private.google_ads_sessions set consumed=true where id=p_id;return s.company_id;
end;$$;
create function public.ad_credentials_server(p_company_id uuid,p_actor uuid,p_provider text,p_write jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;payload jsonb;begin
 if p_actor is null or p_provider not in ('google','meta') then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.companies where id=p_company_id for update;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);
 allowed:=case when p_write is null then private.can_company_action(p_company_id,'marketing.read') else private.company_owner(p_company_id) end;
 perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 if not coalesce(allowed,false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_write is not null then
 insert into public.company_ad_connections(company_id,provider,account_id,name,source_page,status) values(p_company_id,p_provider,p_write->>'accountId',coalesce(p_write->>'name',''),p_write->>'sourcePage',coalesce(p_write->>'status','pending')) on conflict(company_id,provider) do update set account_id=excluded.account_id,name=excluded.name,source_page=excluded.source_page,status=excluded.status,updated_at=now();
 if p_write ? 'cipher' then insert into private.ad_credentials values(p_company_id,p_provider,p_write->>'cipher') on conflict(company_id,provider) do update set cipher=excluded.cipher;end if;
 if p_write->>'status'='disconnected' then delete from private.ad_credentials where company_id=p_company_id and provider=p_provider;end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,p_actor,'ads.connection',jsonb_build_object('provider',p_provider,'accountId',p_write->>'accountId','status',p_write->>'status') from public.companies where id=p_company_id;
 end if;
 select to_jsonb(c)||jsonb_build_object('cipher',s.cipher) into payload from public.company_ad_connections c left join private.ad_credentials s using(company_id,provider) where c.company_id=p_company_id and c.provider=p_provider;return payload;
end;$$;
create function public.begin_paid_plan(p_company_id uuid,p_id uuid,p_budget numeric,p_days integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.company_profile_versions;begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (select count(*) from public.company_paid_plans where company_id=p_company_id and created_at>now()-interval '1 day')>=5 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select * into v from public.company_profile_versions where company_id=p_company_id order by version desc limit 1;
 if v.company_id is null then raise exception 'Confirm company profile first' using errcode='22023';end if;
 insert into public.company_paid_plans(id,company_id,actor_id,profile_version,budget,days) values(p_id,p_company_id,auth.uid(),v.version,p_budget,p_days);return jsonb_build_object('facts',v.facts,'version',v.version);
end;$$;
create function public.finish_paid_plan_server(p_company_id uuid,p_actor uuid,p_id uuid,p_output jsonb,p_model text) returns void language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;begin
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);allowed:=private.can_company_action(p_company_id,'marketing.write');perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 if not coalesce(allowed,false) then raise exception 'Access denied' using errcode='42501';end if;
 update public.company_paid_plans set output=p_output,model=p_model,status=case when p_output is null then 'failed' else 'ready' end where id=p_id and company_id=p_company_id and actor_id=p_actor and status='generating' and (p_output is null or profile_version=(select max(version) from public.company_profile_versions where company_id=p_company_id));
 if not found then raise exception 'Profile changed' using errcode='40001';end if;
end;$$;
revoke all on function public.begin_google_ads(uuid,uuid,text),public.consume_google_ads(uuid,text),public.begin_paid_plan(uuid,uuid,numeric,integer) from public,anon;
grant execute on function public.begin_google_ads(uuid,uuid,text),public.consume_google_ads(uuid,text),public.begin_paid_plan(uuid,uuid,numeric,integer) to authenticated;
revoke all on function public.ad_credentials_server(uuid,uuid,text,jsonb),public.finish_paid_plan_server(uuid,uuid,uuid,jsonb,text) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.ad_credentials_server(uuid,uuid,text,jsonb),public.finish_paid_plan_server(uuid,uuid,uuid,jsonb,text) to service_role;end if;end;$$;
notify pgrst,'reload schema';
commit;
