-- Dashboard: append-only revisions and tenant-scoped verified/manual facts.
-- Local migration only; apply after product_foundation. No external synchronization is activated.
begin;
create table public.dashboard_permissions(
 company_id uuid not null references public.companies(id),
 user_id uuid not null references public.profiles(id),
 financial_details boolean not null default false,
 manage_costs boolean not null default false,
 granted_by uuid not null references public.profiles(id),
 primary key(company_id,user_id),
 check(not manage_costs or financial_details)
);
create function private.dashboard_can(c uuid,scope text,s uuid default null) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.companies where id=c and archived_at is null) and (
  private.company_owner(c)
  or (private.company_role(c) is not null and (
   (scope='digital' and private.can_company_action(c,'marketing.read'))
   or (scope='write_digital' and private.can_company_action(c,'marketing.write'))
   or (scope in ('finance','write_finance') and exists(select 1 from public.dashboard_permissions where company_id=c and user_id=auth.uid() and financial_details and (scope='finance' or manage_costs)))
  ))
  or (scope in ('digital','finance') and exists(
   select 1 from public.internal_access_sessions a where a.id=s and a.company_id=c and a.operator_id=auth.uid()
    and a.ended_at is null and a.expires_at>now() and private.assigned_to(c)
    and (scope='digital' or private.staff_role()='platform_admin')
  ))
 );
$$;
create table public.dashboard_imports(
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id),
 source text not null check(length(source) between 2 and 100),
 domain text not null check(domain in ('digital','finance','trends')),
 checksum text not null,
 actor_id uuid not null references public.profiles(id),
 coverage_start date not null,coverage_end date not null,
 complete boolean not null default false,note text not null,
 created_at timestamptz not null default now(),
 unique(company_id,checksum),unique(company_id,id),
 check(coverage_start<=coverage_end)
);
create table public.dashboard_facts(
 company_id uuid not null references public.companies(id),
 source text not null,kind text not null check(kind in ('ads','payment','refund','cost','social','web','trend')),
 external_id text not null check(length(external_id) between 1 and 150),
 domain text not null check(domain in ('digital','finance','trends')),
 occurred_on date not null,
 payload jsonb not null check(jsonb_typeof(payload)='object'),
 revision integer not null default 1,
 import_id uuid not null,
 updated_at timestamptz not null default now(),
 primary key(company_id,source,kind,external_id),
 foreign key(company_id,import_id) references public.dashboard_imports(company_id,id)
);
create table public.dashboard_fact_revisions(
 company_id uuid not null,source text not null,kind text not null,external_id text not null,
 revision integer not null,payload jsonb not null,import_id uuid not null,created_at timestamptz not null default now(),
 primary key(company_id,source,kind,external_id,revision),
 foreign key(company_id,import_id) references public.dashboard_imports(company_id,id)
);
create table public.dashboard_exports(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 actor_id uuid not null references public.profiles(id),internal_session_id uuid references public.internal_access_sessions(id),
 filters jsonb not null,method_version text not null,snapshot jsonb not null,
 created_at timestamptz not null default now()
);
create index dashboard_facts_period_idx on public.dashboard_facts(company_id,domain,occurred_on);
alter table public.dashboard_permissions enable row level security;
alter table public.dashboard_imports enable row level security;
alter table public.dashboard_facts enable row level security;
alter table public.dashboard_fact_revisions enable row level security;
alter table public.dashboard_exports enable row level security;
revoke all on public.dashboard_permissions,public.dashboard_imports,public.dashboard_facts,public.dashboard_fact_revisions,public.dashboard_exports from anon,authenticated;
grant select on public.dashboard_permissions,public.dashboard_imports,public.dashboard_facts,public.dashboard_fact_revisions,public.dashboard_exports to authenticated;
create policy dashboard_permissions_read on public.dashboard_permissions for select to authenticated using(private.company_owner(company_id) or user_id=auth.uid());
create policy dashboard_imports_read on public.dashboard_imports for select to authenticated using(private.dashboard_can(company_id,case when domain='finance' then 'finance' else 'digital' end));
create policy dashboard_facts_read on public.dashboard_facts for select to authenticated using(private.dashboard_can(company_id,case when domain='finance' then 'finance' else 'digital' end));
create policy dashboard_revisions_read on public.dashboard_fact_revisions for select to authenticated using(private.dashboard_can(company_id,case when kind in ('payment','refund','cost') then 'finance' else 'digital' end));
create policy dashboard_exports_read on public.dashboard_exports for select to authenticated using(private.dashboard_can(company_id,'finance') and actor_id=auth.uid());

create function public.dashboard_grant(p_company_id uuid,p_user_id uuid,p_financial_details boolean,p_manage_costs boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.company_owner(p_company_id) then raise exception 'Owner required' using errcode='42501';end if;
 if not exists(select 1 from public.company_members where company_id=p_company_id and user_id=p_user_id) then raise exception 'Member unavailable' using errcode='22023';end if;
 insert into public.dashboard_permissions(company_id,user_id,financial_details,manage_costs,granted_by)
 values(p_company_id,p_user_id,p_financial_details,p_manage_costs,auth.uid())
 on conflict(company_id,user_id) do update set financial_details=excluded.financial_details,manage_costs=excluded.manage_costs,granted_by=auth.uid();
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
 select workspace_id,id,auth.uid(),'dashboard.permission_changed',jsonb_build_object('userId',p_user_id,'financialDetails',p_financial_details,'manageCosts',p_manage_costs) from public.companies where id=p_company_id;
end;$$;

create function public.dashboard_import(p_company_id uuid,p_document jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare source_name text;domain_name text;v_checksum text;batch uuid;record jsonb;existing public.dashboard_facts;total integer:=0;kind_name text;external_key text;expected_domain text;allowed_keys text[];
begin
 source_name:=p_document->>'source';domain_name:=p_document->>'domain';
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.dashboard_can(p_company_id,case when domain_name='finance' then 'write_finance' else 'write_digital' end),false) then raise exception 'Access denied' using errcode='42501';end if;
 if jsonb_typeof(p_document->'records') is distinct from 'array' or jsonb_array_length(p_document->'records') not between 1 and 1000 or octet_length(p_document::text)>2000000 then raise exception 'Invalid import size' using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(p_document->'records') r group by r->>'kind',r->>'id' having count(*)>1) then raise exception 'Duplicate source keys in document' using errcode='22023';end if;
 v_checksum:=encode(sha256(convert_to(p_document::text,'UTF8')),'hex');
 select id into batch from public.dashboard_imports where company_id=p_company_id and dashboard_imports.checksum=v_checksum;
 if batch is not null then return jsonb_build_object('id',batch,'duplicate',true,'written',0);end if;
 insert into public.dashboard_imports(company_id,source,domain,checksum,actor_id,coverage_start,coverage_end,complete,note)
 values(p_company_id,source_name,domain_name,v_checksum,auth.uid(),(p_document->>'coverageStart')::date,(p_document->>'coverageEnd')::date,p_document->>'coverage'='complete',p_document->>'note') returning id into batch;
 for record in select value from jsonb_array_elements(p_document->'records') loop
  kind_name:=record->>'kind';external_key:=record->>'id';
  allowed_keys:=case kind_name
   when 'payment' then array['kind','id','date','customerId','netCents','variableCostCents','acquisitionDate','customerHistoryKnown','customerPreexisting','channel','campaignId','evidence','classification']
   when 'refund' then array['kind','id','date','paymentId','cents','variableCostReversalCents']
   when 'cost' then array['kind','id','date','category','cents','channel','campaignId','allocation','estimated']
   when 'ads' then array['kind','id','date','provider','accountId','campaignId','campaignName','timezone','currency','spendCents','impressions','clicks','clickType','reportedConversions','dateBasis','attribution']
   when 'social' then array['kind','id','date','accountId','publishedAt','caption','permalink','format','temporal','intervalStart','intervalEnd','reach','likes','comments','saves','shares','views','collectedAt']
   when 'web' then array['kind','id','date','provider','resource','metric','value','timezone','coverage']
   when 'trend' then array['kind','id','date','term','termType','region','language','searchType','batchId','scale','value','coverage','sourceUrl','collectedAt'] else null end;
  if allowed_keys is null or jsonb_typeof(record) is distinct from 'object' or record-allowed_keys<>'{}'::jsonb or not record ?& allowed_keys then raise exception 'Invalid record fields' using errcode='22023';end if;
  expected_domain:=case when kind_name in ('payment','refund','cost') then 'finance' when kind_name='trend' then 'trends' else 'digital' end;
  if expected_domain<>domain_name or length(external_key) not between 1 and 150 or (record->>'date')::date not between (p_document->>'coverageStart')::date and (p_document->>'coverageEnd')::date then raise exception 'Invalid record scope' using errcode='22023';end if;
  select * into existing from public.dashboard_facts where company_id=p_company_id and source=source_name and kind=kind_name and external_id=external_key;
  if existing.payload is not distinct from record then continue;end if;
  insert into public.dashboard_facts(company_id,source,kind,external_id,domain,occurred_on,payload,revision,import_id)
  values(p_company_id,source_name,kind_name,external_key,domain_name,(record->>'date')::date,record,coalesce(existing.revision,0)+1,batch)
  on conflict(company_id,source,kind,external_id) do update set payload=excluded.payload,occurred_on=excluded.occurred_on,revision=excluded.revision,import_id=batch,updated_at=now();
  insert into public.dashboard_fact_revisions(company_id,source,kind,external_id,revision,payload,import_id)
  values(p_company_id,source_name,kind_name,external_key,coalesce(existing.revision,0)+1,record,batch);
  total:=total+1;
 end loop;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
 select workspace_id,id,auth.uid(),'dashboard.imported',jsonb_build_object('importId',batch,'written',total,'domain',domain_name,'source',source_name) from public.companies where id=p_company_id;
 return jsonb_build_object('id',batch,'duplicate',false,'written',total);
end;$$;


-- Confirmed marketing profile for editorial keyword candidates, separate from measured Trends facts.
create table public.dashboard_keyword_profiles(
 company_id uuid primary key references public.companies(id),
 services text[] not null default '{}',neighborhood text not null default '',
 confirmed_by uuid not null references public.profiles(id),confirmed_at timestamptz not null default now(),
 revision integer not null default 1
);
alter table public.dashboard_keyword_profiles enable row level security;
revoke all on public.dashboard_keyword_profiles from anon,authenticated;
grant select on public.dashboard_keyword_profiles to authenticated;
create policy dashboard_keywords_read on public.dashboard_keyword_profiles for select to authenticated using(private.dashboard_can(company_id,'digital'));
create function public.dashboard_set_keywords(p_company_id uuid,p_services text[],p_neighborhood text default '') returns void
language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.dashboard_can(p_company_id,'write_digital'),false) then raise exception 'Marketing permission required' using errcode='42501';end if;
 if p_services is null or cardinality(p_services)>20 or length(p_neighborhood)>100 or exists(select 1 from unnest(p_services) s where s not in ('musculação','pilates','funcional','spinning','dança','personal','24 horas','totalpass','wellhub')) then raise exception 'Invalid confirmed services' using errcode='22023';end if;
 insert into public.dashboard_keyword_profiles(company_id,services,neighborhood,confirmed_by) values(p_company_id,p_services,p_neighborhood,auth.uid())
 on conflict(company_id) do update set services=excluded.services,neighborhood=excluded.neighborhood,confirmed_by=auth.uid(),confirmed_at=now(),revision=dashboard_keyword_profiles.revision+1;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
 select workspace_id,id,auth.uid(),'dashboard.keywords_confirmed',jsonb_build_object('services',p_services,'neighborhood',p_neighborhood) from public.companies where id=p_company_id;
end;$$;
revoke all on function public.dashboard_set_keywords(uuid,text[],text) from public,anon;
grant execute on function public.dashboard_set_keywords(uuid,text[],text) to authenticated;

create function public.dashboard_read(p_company_id uuid,p_internal_session uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare digital boolean;finance boolean;facts jsonb;coverage jsonb;company jsonb;crm jsonb;
begin
 digital:=coalesce(private.dashboard_can(p_company_id,'digital',p_internal_session),false);
 finance:=coalesce(private.dashboard_can(p_company_id,'finance',p_internal_session),false);
 if not digital and not finance then raise exception 'Dashboard access denied' using errcode='42501';end if;
 if (select count(*) from public.dashboard_facts where company_id=p_company_id)>10000 then raise exception 'Dashboard requires paginated aggregation above 10000 records' using errcode='54000';end if;
 select jsonb_build_object('id',id,'name',name,'city',city,'segment',segment,'timezone',timezone) into company from public.companies where id=p_company_id;
 select coalesce(jsonb_agg(jsonb_build_object('source',source,'revision',revision,'payload',payload,'updatedAt',updated_at)),'[]') into facts
 from public.dashboard_facts where company_id=p_company_id and case when domain='finance' then finance else digital end;
 select coalesce(jsonb_agg(jsonb_build_object('source',source,'domain',domain,'start',coverage_start,'end',coverage_end,'complete',complete,'updatedAt',created_at,'note',note)),'[]') into coverage
 from (select distinct on(source,domain,coverage_start,coverage_end) * from public.dashboard_imports where company_id=p_company_id and case when domain='finance' then finance else digital end order by source,domain,coverage_start,coverage_end,created_at desc) x;
 if (select count(*) from public.opportunities where company_id=p_company_id)>10000 then raise exception 'CRM aggregation requires pagination above 10000 opportunities' using errcode='54000';end if;
 -- CRM aggregate source: no names, phones or email are returned. Attendant personal analytics awaits responsible assignment.
 if private.company_owner(p_company_id) or (private.company_role(p_company_id) is distinct from 'attendant' and private.can_company_action(p_company_id,'crm.read')) then
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'contactId',contact_id,'createdAt',created_at,'stage',stage,'source',original_source)),'[]') into crm from public.opportunities where company_id=p_company_id;
 end if;
 return jsonb_build_object('company',company,'keywordProfile',(select jsonb_build_object('services',services,'neighborhood',neighborhood,'confirmedAt',confirmed_at,'revision',revision) from public.dashboard_keyword_profiles where company_id=p_company_id and digital),'facts',facts,'coverage',coverage,'crm',crm,'permissions',jsonb_build_object('digital',digital,'finance',finance,'writeDigital',coalesce(private.dashboard_can(p_company_id,'write_digital'),false),'writeFinance',coalesce(private.dashboard_can(p_company_id,'write_finance'),false)));
end;$$;

create function public.dashboard_record_export(p_company_id uuid,p_filters jsonb,p_snapshot jsonb,p_method text,p_internal_session uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare export_id uuid;
begin
 if not coalesce(private.dashboard_can(p_company_id,'finance',p_internal_session),false) then raise exception 'Financial export permission required' using errcode='42501';end if;
 if p_filters->>'companyId' is distinct from p_company_id::text or p_snapshot->'company'->>'id' is distinct from p_company_id::text then raise exception 'Export company mismatch' using errcode='22023';end if;
 if octet_length(p_snapshot::text)>2000000 then raise exception 'Export too large' using errcode='22023';end if;
 insert into public.dashboard_exports(company_id,actor_id,internal_session_id,filters,method_version,snapshot)
 values(p_company_id,auth.uid(),p_internal_session,p_filters,p_method,p_snapshot) returning id into export_id;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details)
 select workspace_id,id,auth.uid(),'dashboard.exported',jsonb_build_object('exportId',export_id,'method',p_method) from public.companies where id=p_company_id;
 return export_id;
end;$$;
revoke all on function private.dashboard_can(uuid,text,uuid) from public,anon;
grant execute on function private.dashboard_can(uuid,text,uuid) to authenticated;
revoke all on function public.dashboard_grant(uuid,uuid,boolean,boolean),public.dashboard_import(uuid,jsonb),public.dashboard_read(uuid,uuid),public.dashboard_record_export(uuid,jsonb,jsonb,text,uuid) from public,anon;
grant execute on function public.dashboard_grant(uuid,uuid,boolean,boolean),public.dashboard_import(uuid,jsonb),public.dashboard_read(uuid,uuid),public.dashboard_record_export(uuid,jsonb,jsonb,text,uuid) to authenticated;
commit;
