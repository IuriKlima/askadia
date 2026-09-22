-- Foundation only. Not applied to a remote database.
-- RLS is enabled with NO client policies: deny by default until stage 2.
begin;
create extension if not exists pgcrypto;
create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 100),
  created_at timestamptz not null default now()
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  created_at timestamptz not null default now()
);
create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner','member')),
  primary key (workspace_id,user_id)
);
create table public.companies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  name text not null check (length(trim(name)) between 2 and 100),
  segment text not null check (segment in ('gym','studio','other')),
  timezone text not null default 'America/Sao_Paulo',
  status text not null default 'draft' check (status in ('draft','active','suspended','archived')),
  created_at timestamptz not null default now(),
  unique(workspace_id,id)
);
create table public.company_members (
  company_id uuid not null references public.companies(id),
  user_id uuid not null references public.profiles(id),
  role text not null check (role in ('admin','approver','attendant','reader','support')),
  primary key(company_id,user_id)
);
create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  name text not null,
  phone_e164 text,
  email text,
  created_at timestamptz not null default now(),
  unique(company_id,id),
  unique(company_id,phone_e164)
);
create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  contact_id uuid not null,
  interest text not null default '',
  original_source text not null,
  stage text not null default 'new' check(stage in ('new','in_progress','qualified','referred','scheduled','attended','enrolled','lost')),
  created_at timestamptz not null default now(),
  unique(company_id,id),
  foreign key(company_id,contact_id) references public.contacts(company_id,id)
);
create table public.stage_history (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id),
  opportunity_id uuid not null,
  stage text not null,
  reason text,
  actor_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  foreign key(company_id,opportunity_id) references public.opportunities(company_id,id)
);
create index companies_workspace_idx on public.companies(workspace_id);
create index opportunities_company_stage_idx on public.opportunities(company_id,stage);
alter table public.workspaces enable row level security;
alter table public.profiles enable row level security;
alter table public.workspace_members enable row level security;
alter table public.companies enable row level security;
alter table public.company_members enable row level security;
alter table public.contacts enable row level security;
alter table public.opportunities enable row level security;
alter table public.stage_history enable row level security;
-- No grants, subscription activation, public insert policy, or bootstrap privilege.
commit;
