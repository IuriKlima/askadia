begin;
create table public.company_sites(company_id uuid primary key references public.companies(id),slug text unique,revision integer not null default 0,profile_version integer,draft jsonb,published jsonb,published_revision integer,published_at timestamptz,updated_at timestamptz not null default now());
create table public.company_site_domains(company_id uuid primary key references public.companies(id),hostname text not null unique,verification_token uuid not null default gen_random_uuid(),dns_verified_at timestamptz,routing_configured_at timestamptz,created_at timestamptz not null default now());
create table private.site_generation_runs(id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null,created_at timestamptz not null default now());
alter table public.company_sites enable row level security;
alter table public.company_site_domains enable row level security;
revoke all on public.company_sites,public.company_site_domains from public,anon,authenticated;
grant select on public.company_sites,public.company_site_domains to authenticated;
create policy sites_read on public.company_sites for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create policy site_domains_read on public.company_site_domains for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
revoke all on private.site_generation_runs from public,anon,authenticated;
create function public.reserve_site_generation(p_company_id uuid,p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (select count(*) from private.site_generation_runs where company_id=p_company_id and created_at>date_trunc('day',now()))>=5 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 insert into private.site_generation_runs(id,company_id,actor_id) values(p_id,p_company_id,auth.uid());
end;$$;
create function public.save_company_site(p_company_id uuid,p_revision integer,p_profile_version integer,p_content jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_sites;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_profile_version is null or p_profile_version is distinct from (select max(version) from public.company_profile_versions where company_id=p_company_id) then raise exception 'Profile changed' using errcode='40001';end if;
 if p_content is null or jsonb_typeof(p_content)<>'object' or length(p_content::text)>40000 or not(p_content ?& array['name','headline','intro','about','services','address','hours','offer','whatsapp','cta','color','background','images','logo']) or jsonb_typeof(p_content->'images')<>'array' or jsonb_array_length(p_content->'images')>8 then raise exception 'Invalid site' using errcode='22023';end if;
 if exists(select 1 from (select value::uuid id from jsonb_array_elements_text(p_content->'images') union select nullif(p_content->>'logo','')::uuid) chosen where chosen.id is not null and not exists(select 1 from public.onboarding_attachments a where a.id=chosen.id and a.company_id=p_company_id and a.mime in ('image/png','image/jpeg','image/webp'))) then raise exception 'Company materials required' using errcode='42501';end if;
 insert into public.company_sites(company_id,slug) values(p_company_id,'academia-'||replace(p_company_id::text,'-','')) on conflict do nothing;
 select * into s from public.company_sites where company_id=p_company_id for update;
 if s.revision<>p_revision then raise exception 'Site changed' using errcode='40001';end if;
 update public.company_sites set draft=p_content,profile_version=p_profile_version,revision=revision+1,updated_at=now() where company_id=p_company_id returning * into s;
 return to_jsonb(s);
end;$$;
create function public.publish_company_site(p_company_id uuid,p_revision integer,p_publish boolean) returns void language plpgsql security definer set search_path='' as $$
declare s public.company_sites;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'content.approve'),false) then raise exception 'Approval permission required' using errcode='42501';end if;
 select * into s from public.company_sites where company_id=p_company_id for update;
 if s.company_id is null or s.revision<>p_revision or s.draft is null then raise exception 'Site changed' using errcode='40001';end if;
 if p_publish and (s.profile_version is distinct from (select max(version) from public.company_profile_versions where company_id=p_company_id) or nullif(s.draft->>'whatsapp','') is null) then raise exception 'Confirm profile and WhatsApp before publishing' using errcode='22023';end if;
 update public.company_sites set published=case when p_publish then draft else null end,published_revision=case when p_publish then revision else null end,published_at=case when p_publish then now() else null end where company_id=p_company_id;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),case when p_publish then 'site.published' else 'site.unpublished' end,jsonb_build_object('revision',p_revision) from public.companies where id=p_company_id;
end;$$;
create function public.set_site_domain(p_company_id uuid,p_hostname text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 if p_hostname is null then delete from public.company_site_domains where company_id=p_company_id;return;end if;
 if p_hostname<>lower(p_hostname) or length(p_hostname)>253 or p_hostname!~'^[a-z0-9][a-z0-9.-]+\.[a-z]{2,}$' then raise exception 'Invalid domain' using errcode='22023';end if;
 insert into public.company_site_domains(company_id,hostname) values(p_company_id,p_hostname) on conflict(company_id) do update set hostname=excluded.hostname,verification_token=gen_random_uuid(),dns_verified_at=null,routing_configured_at=null;
end;$$;
create function public.verify_site_domain_server(p_company_id uuid,p_actor uuid,p_hostname text,p_token uuid,p_routed boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;
begin
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);allowed:=private.company_owner(p_company_id);perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 if not coalesce(allowed,false) then raise exception 'Owner required' using errcode='42501';end if;
 update public.company_site_domains set dns_verified_at=now(),routing_configured_at=case when p_routed then now() else routing_configured_at end where company_id=p_company_id and hostname=p_hostname and verification_token=p_token;
end;$$;
-- Public serving returns only the explicitly published snapshot, never drafts or profile data.
create function public.read_published_site_server(p_company_id uuid default null,p_hostname text default null,p_slug text default null) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('companyId',s.company_id,'content',s.published,'revision',s.published_revision) from public.company_sites s join public.companies c on c.id=s.company_id where c.archived_at is null and s.published is not null and ((p_company_id is not null and s.company_id=p_company_id) or (p_slug is not null and s.slug=p_slug) or (p_hostname is not null and exists(select 1 from public.company_site_domains d where d.company_id=s.company_id and d.hostname=p_hostname and d.dns_verified_at is not null))) limit 1;
$$;
revoke all on function public.reserve_site_generation(uuid,uuid),public.save_company_site(uuid,integer,integer,jsonb),public.publish_company_site(uuid,integer,boolean),public.set_site_domain(uuid,text) from public,anon;
grant execute on function public.reserve_site_generation(uuid,uuid),public.save_company_site(uuid,integer,integer,jsonb),public.publish_company_site(uuid,integer,boolean),public.set_site_domain(uuid,text) to authenticated;
revoke all on function public.verify_site_domain_server(uuid,uuid,text,uuid,boolean),public.read_published_site_server(uuid,text,text) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.verify_site_domain_server(uuid,uuid,text,uuid,boolean),public.read_published_site_server(uuid,text,text) to service_role;end if;end;$$;
create function public.set_site_slug(p_company_id uuid,p_slug text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.company_owner(p_company_id),false) then raise exception 'Owner required' using errcode='42501';end if;
 if p_slug is null or p_slug!~'^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$' or p_slug=any(array['www','app','api','admin','mail','smtp','ftp','sites','panel','easypanel','login','auth','support','suporte','status','askadia']) then raise exception 'Invalid subdomain' using errcode='22023';end if;
 insert into public.company_sites(company_id,slug) values(p_company_id,p_slug) on conflict(company_id) do update set slug=excluded.slug;
end;$$;
revoke all on function public.set_site_slug(uuid,text) from public,anon;
grant execute on function public.set_site_slug(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
