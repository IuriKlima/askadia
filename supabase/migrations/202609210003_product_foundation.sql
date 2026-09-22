-- Prompt mestre v1: equipe interna, carteira, perfis e estrutura comercial.
-- Incremental: aplicar depois das três migrações iniciais. Nenhum dado é apagado.
begin;

alter table public.company_members drop constraint company_members_role_check;
alter table public.company_members add constraint company_members_role_check
  check(role in ('admin','marketing','approver','attendant','reader','support'));
alter table public.company_invitations drop constraint company_invitations_role_check;
alter table public.company_invitations add constraint company_invitations_role_check
  check(role in ('admin','marketing','approver','attendant','reader','support'));

create table public.platform_staff (
  user_id uuid primary key references public.profiles(id),
  role text not null check(role in ('platform_admin','support')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.company_assignments (
  company_id uuid not null references public.companies(id),
  staff_id uuid not null references public.platform_staff(user_id),
  assigned_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key(company_id,staff_id)
);
create table public.internal_access_sessions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  operator_id uuid not null references public.platform_staff(user_id),
  reason text not null check(length(trim(reason)) between 8 and 500),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '30 minutes',
  ended_at timestamptz
);
create index internal_access_operator_idx on public.internal_access_sessions(operator_id,expires_at);
create table public.platform_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id),
  company_id uuid references public.companies(id),
  session_id uuid references public.internal_access_sessions(id),
  action text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create table public.plan_catalog (
  id text primary key check(id in ('basic','premium','weekly')),
  name text not null,
  kind text not null check(kind in ('plan','addon')),
  price_cents integer check(price_cents>=0),
  currency text not null default 'BRL' check(currency='BRL'),
  checkout_enabled boolean not null default false,
  features text[] not null default '{}',
  quotas jsonb not null default '{}'
);
insert into public.plan_catalog(id,name,kind,price_cents,features,quotas) values
('basic','Marketing básico','plan',49700,array['strategy','content','crm','sites'],
 '{"ai_tokens":null,"images":null,"storage_bytes":null,"members":null,"regenerations":null,"messages":null}'),
('premium','Marketing com atendimento','plan',null,array['strategy','content','crm','sites','inbox','triage'],
 '{"ai_tokens":null,"images":null,"storage_bytes":null,"members":null,"regenerations":null,"messages":null}'),
('weekly','Acompanhamento semanal','addon',100000,array['weekly_support'],'{}');
create table public.company_subscriptions (
  company_id uuid primary key references public.companies(id),
  plan_id text not null references public.plan_catalog(id) check(plan_id in ('basic','premium')),
  status text not null default 'draft' check(status in ('draft','pending','active','past_due','canceled','suspended')),
  weekly_support boolean not null default false,
  current_period_end timestamptz,
  provider text,
  external_id text unique,
  updated_at timestamptz not null default now()
);
create table public.company_quota_overrides (
  company_id uuid not null references public.companies(id),
  resource text not null check(resource in ('ai_tokens','images','storage_bytes','members','regenerations','messages')),
  limit_value bigint not null check(limit_value>=0),
  primary key(company_id,resource)
);
create table public.company_permission_grants (
  company_id uuid not null,
  user_id uuid not null,
  action text not null check(action in ('crm.read','crm.write','content.approve','strategy.approve','site.approve','ads.approve')),
  budget_limit_cents bigint check(budget_limit_cents>=0),
  expires_at timestamptz,
  granted_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key(company_id,user_id,action),
  foreign key(company_id,user_id) references public.company_members(company_id,user_id) on delete cascade,
  check(action='ads.approve' or budget_limit_cents is null)
);

create function private.staff_role() returns text language sql stable security definer set search_path='' as $$
  select role from public.platform_staff where user_id=auth.uid() and active;
$$;
create function private.assigned_to(c uuid) returns boolean language sql stable security definer set search_path='' as $$
  select coalesce(private.staff_role()='platform_admin',false)
    or (private.staff_role()='support' and exists(select 1 from public.company_assignments where company_id=c and staff_id=auth.uid()));
$$;
create function private.company_owner(c uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.companies where id=c and private.workspace_owner(workspace_id));
$$;
create or replace function private.company_access(c uuid,roles text[]) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.companies where id=c and archived_at is null
    and (private.company_owner(c) or coalesce(private.company_role(c)=any(roles),false)));
$$;
create function private.can_company_action(c uuid,a text) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.companies where id=c and archived_at is null) and
  a in ('company.read','marketing.read','marketing.write','crm.read','crm.write','billing.manage','content.approve','strategy.approve','site.approve','ads.approve') and (
    private.company_owner(c)
    or (private.company_role(c)='admin' and a not in ('billing.manage','ads.approve'))
    or (private.company_role(c)='marketing' and a in ('company.read','marketing.read','marketing.write'))
    or (private.company_role(c)='attendant' and a in ('company.read','crm.read','crm.write'))
    or (private.company_role(c) in ('reader','support') and a in ('company.read','marketing.read'))
    or (private.company_role(c)='approver' and a in ('company.read','marketing.read','content.approve','strategy.approve','site.approve'))
    or exists(select 1 from public.company_permission_grants where company_id=c and user_id=auth.uid() and action=a and (expires_at is null or expires_at>now()))
  );
$$;
alter policy contacts_read on public.contacts using(private.can_company_action(company_id,'crm.read'));
alter policy opportunities_read on public.opportunities using(private.can_company_action(company_id,'crm.read'));
alter policy history_read on public.stage_history using(private.can_company_action(company_id,'crm.read'));
alter policy company_assets_read on storage.objects using(bucket_id='company-assets' and private.file_access(name,array['admin','marketing','approver','support']));
alter policy company_assets_insert on storage.objects with check(bucket_id='company-assets' and private.file_access(name,array['admin','marketing']));
alter policy company_assets_update on storage.objects using(bucket_id='company-assets' and private.file_access(name,array['admin','marketing'])) with check(bucket_id='company-assets' and private.file_access(name,array['admin','marketing']));
alter policy company_assets_delete on storage.objects using(bucket_id='company-assets' and private.file_access(name,array['admin','marketing']));

alter table public.platform_staff enable row level security;
alter table public.company_assignments enable row level security;
alter table public.internal_access_sessions enable row level security;
alter table public.platform_audit enable row level security;
alter table public.plan_catalog enable row level security;
alter table public.company_subscriptions enable row level security;
alter table public.company_quota_overrides enable row level security;
alter table public.company_permission_grants enable row level security;
revoke all on public.platform_staff,public.company_assignments,public.internal_access_sessions,public.platform_audit,
  public.plan_catalog,public.company_subscriptions,public.company_quota_overrides,public.company_permission_grants from anon,authenticated;
grant select on public.platform_staff,public.company_assignments,public.internal_access_sessions,public.platform_audit,
  public.plan_catalog,public.company_subscriptions,public.company_quota_overrides,public.company_permission_grants to authenticated;
create policy staff_read on public.platform_staff for select to authenticated using(user_id=auth.uid() or private.staff_role()='platform_admin');
create policy assignments_read on public.company_assignments for select to authenticated using(staff_id=auth.uid() or private.staff_role()='platform_admin');
create policy internal_sessions_read on public.internal_access_sessions for select to authenticated using(operator_id=auth.uid() or private.staff_role()='platform_admin');
create policy platform_audit_read on public.platform_audit for select to authenticated using(private.staff_role()='platform_admin');
create policy plan_read on public.plan_catalog for select to authenticated using(true);
create policy subscription_read on public.company_subscriptions for select to authenticated using(private.company_owner(company_id) or private.company_role(company_id) is not null);
create policy quota_read on public.company_quota_overrides for select to authenticated using(private.company_owner(company_id) or private.company_role(company_id) is not null);
create policy grants_read on public.company_permission_grants for select to authenticated using(user_id=auth.uid() or private.company_manager(company_id));

create function public.company_capabilities(p_company_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actions jsonb; subscription public.company_subscriptions; plan public.plan_catalog; quotas jsonb; enabled boolean;
begin
  if not coalesce(private.can_company_action(p_company_id,'company.read'),false) then raise exception 'Access denied' using errcode='42501'; end if;
  select jsonb_agg(a) into actions from unnest(array['company.read','marketing.read','marketing.write','crm.read','crm.write','billing.manage','content.approve','strategy.approve','site.approve','ads.approve']) a where private.can_company_action(p_company_id,a);
  select * into subscription from public.company_subscriptions where company_id=p_company_id;
  select * into plan from public.plan_catalog where id=subscription.plan_id;
  select coalesce(jsonb_object_agg(resource,limit_value),'{}') into quotas from public.company_quota_overrides where company_id=p_company_id;
  enabled:=coalesce(subscription.status='active' and subscription.current_period_end>now(),false);
  return jsonb_build_object('companyId',p_company_id,'actions',coalesce(actions,'[]'),'subscription',jsonb_build_object('planId',subscription.plan_id,'status',coalesce(subscription.status,'draft'),'weeklySupport',coalesce(subscription.weekly_support,false),'periodEnd',subscription.current_period_end),
    'features',case when enabled then to_jsonb(plan.features||case when subscription.weekly_support then array['weekly_support'] else array[]::text[] end) else '[]'::jsonb end,
    'quotas',coalesce(plan.quotas,'{}')||quotas,'billingEnabled',false);
end;
$$;
create function public.authorize_company_feature(p_company_id uuid,p_feature text,p_action text) returns void
language plpgsql stable security definer set search_path='' as $$
declare allowed boolean;
begin
  if not coalesce(private.can_company_action(p_company_id,p_action),false) then raise exception 'Access denied' using errcode='42501'; end if;
  select exists(select 1 from public.company_subscriptions s join public.plan_catalog p on p.id=s.plan_id
    where s.company_id=p_company_id and s.status='active' and s.current_period_end>now() and p_feature=any(p.features)) into allowed;
  if not allowed then raise exception 'Feature blocked by subscription' using errcode='42501'; end if;
end;
$$;

create function public.set_company_permission(p_company_id uuid,p_user_id uuid,p_action text,p_enabled boolean,p_budget_limit_cents bigint default null,p_expires_at timestamptz default null)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.companies where id=p_company_id for update;
  if not private.company_owner(p_company_id) then raise exception 'Only owner delegates permissions' using errcode='42501'; end if;
  if not exists(select 1 from public.company_members where company_id=p_company_id and user_id=p_user_id) then raise exception 'Member unavailable' using errcode='22023'; end if;
  if p_expires_at<=now() then raise exception 'Invalid expiry' using errcode='22023'; end if;
  if p_action='ads.approve' and p_enabled and p_budget_limit_cents is null then raise exception 'Budget limit required' using errcode='22023'; end if;
  if p_enabled then
    insert into public.company_permission_grants(company_id,user_id,action,budget_limit_cents,expires_at,granted_by)
    values(p_company_id,p_user_id,p_action,p_budget_limit_cents,p_expires_at,auth.uid())
    on conflict(company_id,user_id,action) do update set budget_limit_cents=excluded.budget_limit_cents,expires_at=excluded.expires_at,granted_by=auth.uid(),created_at=now();
  else
    delete from public.company_permission_grants where company_id=p_company_id and user_id=p_user_id and action=p_action;
  end if;
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
    select workspace_id,id,auth.uid(),'permission.changed',jsonb_build_object('userId',p_user_id,'permission',p_action,'enabled',p_enabled,'budgetLimitCents',p_budget_limit_cents) from public.companies where id=p_company_id;
end;
$$;

create function public.internal_portfolio(p_search text default '',p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare rows jsonb; total integer;
begin
  if private.staff_role() is null then raise exception 'Staff access required' using errcode='42501'; end if;
  if length(p_search)>100 or p_offset<0 then raise exception 'Invalid pagination' using errcode='22023'; end if;
  select count(*) into total from public.companies c where private.assigned_to(c.id) and c.name ilike '%'||p_search||'%';
  select coalesce(jsonb_agg(r),'[]') into rows from (
    select c.id,c.name,c.city,c.segment,c.workspace_id,c.archived_at,c.created_at,w.name workspace_name,
      coalesce(s.status,'draft') subscription_status,s.plan_id,coalesce(s.weekly_support,false) weekly_support
    from public.companies c join public.workspaces w on w.id=c.workspace_id left join public.company_subscriptions s on s.company_id=c.id
    where private.assigned_to(c.id) and c.name ilike '%'||p_search||'%'
    order by c.created_at desc,c.id limit 30 offset p_offset
  ) r;
  return jsonb_build_object('role',private.staff_role(),'companies',rows,'total',total,'offset',p_offset,'pageSize',30);
end;
$$;
create function public.set_company_assignment(p_company_id uuid,p_staff_id uuid,p_assigned boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  if private.staff_role() is distinct from 'platform_admin' then raise exception 'Platform admin required' using errcode='42501'; end if;
  perform 1 from public.companies where id=p_company_id for update;
  if not found then raise exception 'Company unavailable' using errcode='22023'; end if;
  if not exists(select 1 from public.platform_staff where user_id=p_staff_id and active and role='support') then raise exception 'Support member unavailable' using errcode='22023'; end if;
  if p_assigned then
    insert into public.company_assignments(company_id,staff_id,assigned_by) values(p_company_id,p_staff_id,auth.uid()) on conflict do nothing;
  else
    delete from public.company_assignments where company_id=p_company_id and staff_id=p_staff_id;
    update public.internal_access_sessions set ended_at=now() where company_id=p_company_id and operator_id=p_staff_id and ended_at is null;
  end if;
  insert into public.platform_audit(actor_id,company_id,action,details) values(auth.uid(),p_company_id,'assignment.changed',jsonb_build_object('staffId',p_staff_id,'assigned',p_assigned));
end;
$$;
create function public.start_internal_access(p_company_id uuid,p_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare session_id uuid;
begin
  perform 1 from public.companies where id=p_company_id for update;
  if not found or not coalesce(private.assigned_to(p_company_id),false) then raise exception 'Access denied' using errcode='42501'; end if;
  insert into public.internal_access_sessions(company_id,operator_id,reason) values(p_company_id,auth.uid(),trim(p_reason)) returning id into session_id;
  insert into public.platform_audit(actor_id,company_id,session_id,action) values(auth.uid(),p_company_id,session_id,'internal_access.started');
  return session_id;
end;
$$;
create function public.internal_company_context(p_session_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.internal_access_sessions; company jsonb; subscription jsonb; history jsonb; team jsonb;
begin
  select * into s from public.internal_access_sessions where id=p_session_id and operator_id=auth.uid() and ended_at is null and expires_at>now();
  if s.id is null or not coalesce(private.assigned_to(s.company_id),false) then raise exception 'Internal session unavailable' using errcode='42501'; end if;
  select to_jsonb(c) into company from public.companies c where id=s.company_id;
  select jsonb_build_object('planId',plan_id,'status',status,'weeklySupport',weekly_support,'periodEnd',current_period_end) into subscription from public.company_subscriptions where company_id=s.company_id;
  select coalesce(jsonb_agg(x),'[]') into team from (select p.display_name,m.role from public.company_members m join public.profiles p on p.id=m.user_id where m.company_id=s.company_id order by p.display_name) x;
  select coalesce(jsonb_agg(x),'[]') into history from (select action,actor_id,created_at from public.audit_logs where company_id=s.company_id order by created_at desc limit 30) x;
  return jsonb_build_object('session',to_jsonb(s),'company',company,'subscription',coalesce(subscription,'{"status":"draft"}'),'team',team,'history',history,'operatorRole',private.staff_role(),'scope','read_only');
end;
$$;
create function public.end_internal_access(p_session_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare c uuid;
begin
  update public.internal_access_sessions set ended_at=now() where id=p_session_id and operator_id=auth.uid() and ended_at is null returning company_id into c;
  if c is not null then insert into public.platform_audit(actor_id,company_id,session_id,action) values(auth.uid(),c,p_session_id,'internal_access.ended'); end if;
end;
$$;

revoke all on function private.staff_role(),private.assigned_to(uuid),private.company_owner(uuid),private.can_company_action(uuid,text) from public,anon;
grant execute on function private.staff_role(),private.assigned_to(uuid),private.company_owner(uuid),private.can_company_action(uuid,text) to authenticated;
revoke all on function public.company_capabilities(uuid),public.authorize_company_feature(uuid,text,text),
 public.set_company_permission(uuid,uuid,text,boolean,bigint,timestamptz),public.internal_portfolio(text,integer),
 public.set_company_assignment(uuid,uuid,boolean),public.start_internal_access(uuid,text),public.internal_company_context(uuid),public.end_internal_access(uuid) from public,anon;
grant execute on function public.company_capabilities(uuid),public.authorize_company_feature(uuid,text,text),
 public.set_company_permission(uuid,uuid,text,boolean,bigint,timestamptz),public.internal_portfolio(text,integer),
 public.set_company_assignment(uuid,uuid,boolean),public.start_internal_access(uuid,text),public.internal_company_context(uuid),public.end_internal_access(uuid) to authenticated;

create or replace function public.create_company_invitation(p_company_id uuid,p_email text,p_role text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare token text; invitation public.company_invitations; w uuid;
begin
  select workspace_id into w from public.companies where id=p_company_id and archived_at is null for update;
  if w is null or not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  if p_role not in ('admin','marketing','approver','attendant','reader','support') or length(p_email)>254 or position('@' in p_email)<2 then raise exception 'Invalid invitation' using errcode='22023'; end if;
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

create or replace function public.change_company_member(p_company_id uuid,p_user_id uuid,p_role text) returns void
language plpgsql security definer set search_path='' as $$
declare v_member_role text; w uuid;
begin
  select workspace_id into w from public.companies where id=p_company_id for update;
  if not private.company_manager(p_company_id) then raise exception 'Access denied' using errcode='42501'; end if;
  select role into v_member_role from public.company_members where company_id=p_company_id and user_id=p_user_id;
  if v_member_role is null then raise exception 'Member unavailable' using errcode='22023'; end if;
  if p_role is not null and p_role not in ('admin','marketing','approver','attendant','reader','support') then raise exception 'Invalid role' using errcode='22023'; end if;
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


create function public.company_assignment_roster(p_company_id uuid)
returns table(user_id uuid,display_name text,assigned boolean)
language plpgsql stable security definer set search_path='' as $$
begin
  if private.staff_role() is distinct from 'platform_admin' then raise exception 'Platform admin required' using errcode='42501'; end if;
  return query select s.user_id,p.display_name,exists(select 1 from public.company_assignments a where a.company_id=p_company_id and a.staff_id=s.user_id)
    from public.platform_staff s join public.profiles p on p.id=s.user_id where s.role='support' and s.active order by p.display_name;
end;
$$;
revoke all on function public.company_assignment_roster(uuid) from public,anon;
grant execute on function public.company_assignment_roster(uuid) to authenticated;

commit;
