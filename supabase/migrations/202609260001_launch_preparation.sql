begin;
create table public.company_launch_jobs(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),profile_version integer not null,
 actor_id uuid not null references public.profiles(id),kind text not null check(kind in ('site','recommendations')),
 status text not null default 'pending' check(status in ('pending','running','completed','failed','stale')),
 attempts integer not null default 0,token uuid,lease_until timestamptz,next_attempt_at timestamptz not null default now(),
 expected_revision integer not null default 0,output jsonb,error text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(company_id,profile_version,kind),foreign key(company_id,profile_version) references public.company_profile_versions(company_id,version)
);
create table private.launch_runs(id uuid primary key default gen_random_uuid(),company_id uuid not null,actor_id uuid not null,created_at timestamptz not null default now());
alter table public.company_launch_jobs enable row level security;
revoke all on public.company_launch_jobs,private.launch_runs from public,anon,authenticated;
grant select on public.company_launch_jobs to authenticated;
create policy company_read on public.company_launch_jobs for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create index launch_queue on public.company_launch_jobs(status,next_attempt_at);
create function public.enqueue_company_launch(p_company_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if s.profile_version<1 or s.confirmed_revision is distinct from s.revision then raise exception 'Confirm the current profile first' using errcode='22023';end if;
 insert into public.company_launch_jobs(company_id,profile_version,actor_id,kind) select p_company_id,s.profile_version,auth.uid(),k from unnest(array['site','recommendations']) k on conflict do nothing;
 update public.company_launch_jobs set status='pending',attempts=0,actor_id=auth.uid(),token=null,lease_until=null,next_attempt_at=now(),error=null,updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and status in ('failed','stale');
end;$$;
create function private.launch_after_onboarding() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if coalesce(private.can_company_action(new.company_id,'marketing.write'),false) and new.profile_version>0 and new.confirmed_revision=new.revision and (old.profile_version is distinct from new.profile_version or old.confirmed_revision is distinct from new.confirmed_revision) then perform public.enqueue_company_launch(new.company_id);end if;return new;
end;$$;
create trigger launch_after_onboarding after update of confirmed_revision,profile_version on public.company_onboarding for each row execute function private.launch_after_onboarding();
create function private.launch_actor(j public.company_launch_jobs) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',j.actor_id,'role','authenticated')::text,true);
 return coalesce(private.can_company_action(j.company_id,'marketing.write'),false) and exists(select 1 from public.company_onboarding s where s.company_id=j.company_id and s.profile_version=j.profile_version and s.confirmed_revision=s.revision);
end;$$;
create function public.claim_company_launch_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_launch_jobs;t uuid:=gen_random_uuid();s public.company_sites;facts jsonb;
begin
 select * into j from public.company_launch_jobs where (status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now()) order by updated_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;if not found then return null;end if;
 select * into j from public.company_launch_jobs where id=j.id and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
 if not private.launch_actor(j) then update public.company_launch_jobs set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return null;end if;
 perform 1 from public.profiles where id=j.actor_id for update;
 if j.attempts>=3 or (select count(*) from private.launch_runs where company_id=j.company_id and created_at>now()-interval '1 day')>=10 or (select count(*) from private.launch_runs where actor_id=j.actor_id and created_at>now()-interval '1 day')>=30 then
 update public.company_launch_jobs set status='failed',token=null,error='Limite de tentativas atingido. Retome após revisar as pendências.',updated_at=now() where id=j.id;return null;end if;
 select * into s from public.company_sites where company_id=j.company_id;
 -- Preserve any existing draft, including edits made outside this preparation.
 if j.kind='site' and s.draft is not null then update public.company_launch_jobs set status='completed',error='O site existente foi preservado. Confira se corresponde ao perfil atual.',token=null,updated_at=now() where id=j.id;return null;end if;
 if j.kind='site' then perform public.reserve_site_generation(j.company_id,t);end if;
 insert into private.launch_runs(company_id,actor_id) values(j.company_id,j.actor_id);
 select p.facts into facts from public.company_profile_versions p where p.company_id=j.company_id and p.version=j.profile_version;
 update public.company_launch_jobs set status='running',attempts=attempts+1,token=t,lease_until=now()+interval '5 minutes',expected_revision=coalesce(s.revision,0),error=null,updated_at=now() where id=j.id;
 return jsonb_build_object('id',j.id,'companyId',j.company_id,'profileVersion',j.profile_version,'token',t,'kind',j.kind,'facts',facts);
end;$$;
create function public.finish_company_launch_server(p_id uuid,p_token uuid,p_output jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.company_launch_jobs;
begin
 select * into j from public.company_launch_jobs where id=p_id and status='running' and token=p_token and lease_until>now();if not found then return false;end if;
 perform 1 from public.companies where id=j.company_id for update;
 select * into j from public.company_launch_jobs where id=p_id and status='running' and token=p_token and lease_until>now() for update;if not found then return false;end if;
 if not private.launch_actor(j) then update public.company_launch_jobs set status='stale',token=null,error='O perfil ou as permissões mudaram.',updated_at=now() where id=j.id;return false;end if;
 if p_output is null then
 update public.company_launch_jobs set status=case when attempts>=3 then 'failed' else 'pending' end,token=null,lease_until=null,next_attempt_at=now()+interval '1 minute',error='Esta etapa não terminou. As outras entregas foram preservadas.',updated_at=now() where id=j.id;return true;
 end if;
 if j.kind='site' then
  if coalesce((select revision from public.company_sites where company_id=j.company_id),0)<>j.expected_revision then update public.company_launch_jobs set status='stale',token=null,error='O site foi editado durante a geração. A edição foi preservada.',updated_at=now() where id=j.id;return false;end if;
  perform public.save_company_site(j.company_id,j.expected_revision,j.profile_version,p_output);
 elsif jsonb_typeof(p_output)<>'object' or length(p_output::text)>60000 or not(p_output ?& array['summary','whatsapp','messages','traffic','unknowns']) then raise exception 'Invalid recommendations' using errcode='22023';
 end if;
 update public.company_launch_jobs set status='completed',output=case when kind='recommendations' then p_output else null end,token=null,lease_until=null,error=null,updated_at=now() where id=j.id;return true;
end;$$;
revoke all on function private.launch_after_onboarding(),private.launch_actor(public.company_launch_jobs) from public,anon,authenticated;
revoke all on function public.enqueue_company_launch(uuid) from public,anon;
grant execute on function public.enqueue_company_launch(uuid) to authenticated;
revoke all on function public.claim_company_launch_server(),public.finish_company_launch_server(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.claim_company_launch_server(),public.finish_company_launch_server(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
