-- Stage 2: identity, explicit company membership, transactional writes and audit.
-- Apply only to a development/homologation Supabase project after reviewing.
begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

alter table public.companies add column city text not null default '';
alter table public.companies add column archived_at timestamptz;
alter table public.companies add constraint company_city_length check(length(city) <= 100);

create table public.company_invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  email text not null check(email = lower(trim(email))),
  role text not null check(role in ('admin','approver','attendant','reader','support')),
  token_hash text not null unique,
  invited_by uuid not null references public.profiles(id),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  company_id uuid,
  actor_id uuid not null references public.profiles(id),
  action text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now(),
  foreign key(workspace_id,company_id) references public.companies(workspace_id,id)
);
alter table public.company_invitations enable row level security;
alter table public.audit_logs enable row level security;
create index invitations_company_idx on public.company_invitations(company_id,created_at);
create index company_members_user_idx on public.company_members(user_id,company_id);
create index audit_company_idx on public.audit_logs(company_id,created_at);

create function private.workspace_member(w uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.workspace_members where workspace_id=w and user_id=(select auth.uid()));
$$;
create function private.workspace_owner(w uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.workspace_members where workspace_id=w and user_id=(select auth.uid()) and role='owner');
$$;
create function private.company_role(c uuid) returns text
language sql stable security definer set search_path = '' as $$
  select role from public.company_members where company_id=c and user_id=(select auth.uid());
$$;
create function private.company_manager(c uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.company_role(c)='admin',false)
    or exists(select 1 from public.companies where id=c and private.workspace_owner(workspace_id));
$$;
create function private.company_access(c uuid, roles text[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.companies where id=c and archived_at is null
    and coalesce(private.company_role(c)=any(roles),false));
$$;
create function private.file_access(path text, roles text[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.companies where id::text=split_part(path,'/',1)
    and private.company_access(id,roles) and split_part(path,'/',2)<>'');
$$;
revoke all on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- Metadata visibility never implies operational access to conversations or contacts.
create policy workspace_read on public.workspaces for select to authenticated
  using(private.workspace_member(id));
create policy own_profile_read on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy workspace_members_read on public.workspace_members for select to authenticated
  using(user_id=(select auth.uid()) or private.workspace_owner(workspace_id));
create policy company_read on public.companies for select to authenticated
  using(private.company_role(id) is not null or private.workspace_owner(workspace_id));
create policy company_members_read on public.company_members for select to authenticated
  using(user_id=(select auth.uid()) or private.company_manager(company_id));
create policy invitations_read on public.company_invitations for select to authenticated
  using(private.company_manager(company_id));
create policy audit_read on public.audit_logs for select to authenticated
  using(private.workspace_owner(workspace_id) or (company_id is not null and private.company_role(company_id)='admin'));
create policy contacts_read on public.contacts for select to authenticated
  using(private.company_access(company_id,array['admin','attendant']));
create policy opportunities_read on public.opportunities for select to authenticated
  using(private.company_access(company_id,array['admin','attendant']));
create policy history_read on public.stage_history for select to authenticated
  using(private.company_access(company_id,array['admin','attendant']));

-- No direct DML on identity, roles, invitation, audit or CRM tables.
revoke all on public.workspaces,public.profiles,public.workspace_members,public.companies,
  public.company_members,public.company_invitations,public.audit_logs,
  public.contacts,public.opportunities,public.stage_history from anon,authenticated;
grant select on public.workspaces,public.profiles,public.workspace_members,public.companies,
  public.company_members,public.audit_logs,public.contacts,public.opportunities,public.stage_history to authenticated;
-- token hashes are never returned to clients, even to administrators.
grant select(id,company_id,email,role,invited_by,expires_at,accepted_at,revoked_at,created_at)
  on public.company_invitations to authenticated;

create function private.ensure_profile() returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  insert into public.profiles(id,display_name)
    select id, left(coalesce(raw_user_meta_data->>'name','Usuário'),100)
    from auth.users where id=auth.uid() on conflict(id) do nothing;
end;
$$;
revoke all on function private.ensure_profile() from public,anon,authenticated;

create function public.create_workspace(p_name text) returns uuid
language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
  perform private.ensure_profile();
  if length(trim(p_name)) not between 2 and 100 then raise exception 'Invalid name' using errcode='22023'; end if;
  insert into public.workspaces(name) values(trim(p_name)) returning id into w;
  insert into public.workspace_members(workspace_id,user_id,role) values(w,auth.uid(),'owner');
  insert into public.audit_logs(workspace_id,actor_id,action) values(w,auth.uid(),'workspace.created');
  return w;
end;
$$;

create function public.create_company(p_workspace_id uuid,p_name text,p_segment text,p_city text,p_timezone text)
returns public.companies language plpgsql security definer set search_path='' as $$
declare result public.companies;
begin
  if not private.workspace_owner(p_workspace_id) then raise exception 'Access denied' using errcode='42501'; end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'Invalid timezone' using errcode='22023'; end if;
  insert into public.companies(workspace_id,name,segment,city,timezone,status)
    values(p_workspace_id,trim(p_name),p_segment,trim(p_city),p_timezone,'draft') returning * into result;
  -- Explicit initial data membership; workspace owners of other companies do not get this implicitly.
  insert into public.company_members(company_id,user_id,role) values(result.id,auth.uid(),'admin');
  insert into public.audit_logs(workspace_id,company_id,actor_id,action)
    values(p_workspace_id,result.id,auth.uid(),'company.created');
  return result;
end;
$$;

create function public.update_company(p_company_id uuid,p_name text,p_segment text,p_city text,p_timezone text,p_archived boolean)
returns public.companies language plpgsql security definer set search_path='' as $$
declare result public.companies;
begin
  perform 1 from public.companies where id=p_company_id for update;
  if not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone) then raise exception 'Invalid timezone' using errcode='22023'; end if;
  update public.companies set name=trim(p_name),segment=p_segment,city=trim(p_city),timezone=p_timezone,
    archived_at=case when p_archived then coalesce(archived_at,now()) else null end
    where id=p_company_id returning * into result;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    values(result.workspace_id,result.id,auth.uid(),'company.updated',jsonb_build_object('archived',p_archived));
  return result;
end;
$$;

create function public.company_roster(p_company_id uuid) returns table(user_id uuid,role text,display_name text)
language plpgsql stable security definer set search_path='' as $$
begin
  if not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  return query select m.user_id,m.role,p.display_name from public.company_members m join public.profiles p on p.id=m.user_id where m.company_id=p_company_id;
end;
$$;

create function public.create_company_invitation(p_company_id uuid,p_email text,p_role text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare token text; invitation public.company_invitations; w uuid;
begin
  select workspace_id into w from public.companies where id=p_company_id and archived_at is null for update;
  if w is null or not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  if p_role not in ('admin','approver','attendant','reader','support') or length(p_email)>254 or position('@' in p_email)<2 then raise exception 'Invalid invitation' using errcode='22023'; end if;
  -- Reissuing supersedes old unused invitations for this email in this company.
  update public.company_invitations set revoked_at=now() where company_id=p_company_id and email=lower(trim(p_email)) and accepted_at is null and revoked_at is null;
  token:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  insert into public.company_invitations(company_id,email,role,token_hash,invited_by)
    values(p_company_id,lower(trim(p_email)),p_role,encode(sha256(convert_to(token,'UTF8')),'hex'),auth.uid()) returning * into invitation;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    values(w,p_company_id,auth.uid(),'member.invited',jsonb_build_object('invitationId',invitation.id,'role',p_role));
  return jsonb_build_object('id',invitation.id,'token',token,'expires_at',invitation.expires_at);
end;
$$;

create function public.accept_company_invitation(p_token text) returns uuid
language plpgsql security definer set search_path='' as $$
declare invitation public.company_invitations; w uuid; user_email text;
begin
  perform private.ensure_profile();
  select lower(email) into user_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
  if user_email is null then raise exception 'Verified email required' using errcode='42501'; end if;
  select * into invitation from public.company_invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  if invitation.id is null then raise exception 'Invitation unavailable' using errcode='42501'; end if;
  -- Lock company before invitation, consistently with create/revoke/member operations.
  select workspace_id into w from public.companies where id=invitation.company_id and archived_at is null for update;
  if w is null then raise exception 'Company unavailable' using errcode='42501'; end if;
  select * into invitation from public.company_invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
  if invitation.id is null or invitation.email<>user_email or invitation.revoked_at is not null or invitation.accepted_at is not null or invitation.expires_at<=now() then
    raise exception 'Invitation unavailable' using errcode='42501';
  end if;
  -- Issuer removal invalidates still-pending invitations.
  if not exists(select 1 from public.company_members where company_id=invitation.company_id and user_id=invitation.invited_by and role='admin')
    and not exists(select 1 from public.workspace_members where workspace_id=w and user_id=invitation.invited_by and role='owner') then
    raise exception 'Invitation unavailable' using errcode='42501';
  end if;
  if exists(select 1 from public.company_members where company_id=invitation.company_id and user_id=auth.uid()) then raise exception 'Already a member' using errcode='23505'; end if;
  insert into public.workspace_members(workspace_id,user_id,role) values(w,auth.uid(),'member') on conflict do nothing;
  insert into public.company_members(company_id,user_id,role) values(invitation.company_id,auth.uid(),invitation.role);
  update public.company_invitations set accepted_at=now() where id=invitation.id;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    values(w,invitation.company_id,auth.uid(),'member.joined',jsonb_build_object('invitationId',invitation.id,'role',invitation.role));
  return invitation.company_id;
end;
$$;

create function public.revoke_company_invitation(p_company_id uuid,p_invitation_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  update public.company_invitations set revoked_at=now() where id=p_invitation_id and company_id=p_company_id and accepted_at is null;
  if not found then raise exception 'Invitation unavailable' using errcode='22023'; end if;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    select workspace_id,id,auth.uid(),'invitation.revoked',jsonb_build_object('invitationId',p_invitation_id) from public.companies where id=p_company_id;
end;
$$;

create function public.change_company_member(p_company_id uuid,p_user_id uuid,p_role text) returns void
language plpgsql security definer set search_path='' as $$
declare v_member_role text; w uuid;
begin
  select workspace_id into w from public.companies where id=p_company_id for update;
  if not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  select role into v_member_role from public.company_members where company_id=p_company_id and user_id=p_user_id;
  if v_member_role is null then raise exception 'Member unavailable' using errcode='22023'; end if;
  if p_role is not null and p_role not in ('admin','approver','attendant','reader','support') then raise exception 'Invalid role' using errcode='22023'; end if;
  if v_member_role='admin' and p_role is distinct from 'admin' and (select count(*) from public.company_members where company_id=p_company_id and role='admin')<=1 then
    raise exception 'Keep at least one administrator' using errcode='22023';
  end if;
  if p_role is null then
    delete from public.company_members where company_id=p_company_id and user_id=p_user_id;
    update public.company_invitations set revoked_at=now() where company_id=p_company_id and invited_by=p_user_id and accepted_at is null and revoked_at is null;
  else
    update public.company_members set role=p_role where company_id=p_company_id and user_id=p_user_id;
  end if;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    values(w,p_company_id,auth.uid(),case when p_role is null then 'member.removed' else 'member.role_changed' end,jsonb_build_object('userId',p_user_id,'previousRole',v_member_role,'role',p_role));
end;
$$;

create function public.record_company_export(p_company_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not private.company_access(p_company_id,array['admin']) then raise exception 'Access denied' using errcode='42501'; end if;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    select workspace_id,id,auth.uid(),'company.export_requested','{"scope":"company_metadata"}'::jsonb from public.companies where id=p_company_id;
end;
$$;

revoke all on function public.create_workspace(text),public.create_company(uuid,text,text,text,text),
  public.update_company(uuid,text,text,text,text,boolean),public.company_roster(uuid),
  public.create_company_invitation(uuid,text,text),public.accept_company_invitation(text),
  public.revoke_company_invitation(uuid,uuid),public.change_company_member(uuid,uuid,text),
  public.record_company_export(uuid) from public,anon;
grant execute on function public.create_workspace(text),public.create_company(uuid,text,text,text,text),
  public.update_company(uuid,text,text,text,text,boolean),public.company_roster(uuid),
  public.create_company_invitation(uuid,text,text),public.accept_company_invitation(text),
  public.revoke_company_invitation(uuid,uuid),public.change_company_member(uuid,uuid,text),
  public.record_company_export(uuid) to authenticated;
commit;
