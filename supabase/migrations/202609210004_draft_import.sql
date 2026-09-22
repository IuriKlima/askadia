-- Importação assistida. Nenhuma aprovação ou matrícula local vira autorização operacional.
begin;
create table public.editorial_drafts (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id),
 title text not null check(length(trim(title)) between 3 and 160),
 caption text not null check(length(caption)<=5000),
 format text not null check(format in ('Imagem','Carrossel','Vídeo')),
 planned_date date,
 version integer not null default 1 check(version>0),
 status text not null default 'draft' check(status='draft'),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 unique(company_id,id)
);
create table public.local_draft_imports (
 company_id uuid not null references public.companies(id),
 source_company_id uuid not null,
 object_type text not null check(object_type in ('contact','opportunity','content')),
 source_id uuid not null,
 record_id uuid not null,
 imported_by uuid not null references public.profiles(id),
 imported_at timestamptz not null default now(),
 primary key(company_id,source_company_id,object_type,source_id)
);
alter table public.editorial_drafts enable row level security;
alter table public.local_draft_imports enable row level security;
revoke all on public.editorial_drafts,public.local_draft_imports from anon,authenticated;
grant select on public.editorial_drafts,public.local_draft_imports to authenticated;
create policy drafts_read on public.editorial_drafts for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create policy imports_read on public.local_draft_imports for select to authenticated using(private.company_manager(company_id));

create function public.import_local_drafts(p_company_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare source_company uuid; item jsonb; record uuid; linked_contact uuid; phone text;
  inserted_contacts integer:=0;inserted_opportunities integer:=0;inserted_contents integer:=0;skipped integer:=0;w uuid;
begin
 select workspace_id into w from public.companies where id=p_company_id and archived_at is null for update;
 if w is null or not coalesce(private.can_company_action(p_company_id,'company.read'),false) then raise exception 'Access denied' using errcode='42501'; end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>262144 then raise exception 'Invalid import' using errcode='22023'; end if;
 source_company:=(p_payload->>'sourceCompanyId')::uuid;
 if source_company is null or jsonb_typeof(p_payload->'contacts') is distinct from 'array'
  or jsonb_typeof(p_payload->'opportunities') is distinct from 'array' or jsonb_typeof(p_payload->'contents') is distinct from 'array'
  or jsonb_array_length(p_payload->'contacts')>100 or jsonb_array_length(p_payload->'opportunities')>100 or jsonb_array_length(p_payload->'contents')>30 then
  raise exception 'Invalid import limits' using errcode='22023';
 end if;
 if (jsonb_array_length(p_payload->'contacts')>0 or jsonb_array_length(p_payload->'opportunities')>0) and not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'CRM permission required' using errcode='42501'; end if;
 if jsonb_array_length(p_payload->'contents')>0 and not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Marketing permission required' using errcode='42501'; end if;
 for item in select value from jsonb_array_elements(p_payload->'contacts') loop
  if (item->>'companyId')::uuid is distinct from source_company or item->>'id' is null or length(trim(item->>'name')) not between 2 and 100 or item->>'name' is null then raise exception 'Invalid source contact' using errcode='22023'; end if;
  if exists(select 1 from public.local_draft_imports where company_id=p_company_id and source_company_id=source_company and object_type='contact' and source_id=(item->>'id')::uuid) then skipped:=skipped+1;continue;end if;
  phone:=nullif(trim(item->>'phone'),'');
  if phone is not null and phone !~ '^\+[1-9][0-9]{9,14}$' then raise exception 'Invalid phone' using errcode='22023'; end if;
  if length(coalesce(item->>'email',''))>254 then raise exception 'Invalid email' using errcode='22023'; end if;
  record:=null;
  if phone is not null then select id into record from public.contacts where company_id=p_company_id and phone_e164=phone;end if;
  if record is null then
   insert into public.contacts(company_id,name,phone_e164,email) values(p_company_id,trim(item->>'name'),phone,nullif(trim(item->>'email'),'')) returning id into record;
   inserted_contacts:=inserted_contacts+1;
  else skipped:=skipped+1;
  end if;
  insert into public.local_draft_imports(company_id,source_company_id,object_type,source_id,record_id,imported_by) values(p_company_id,source_company,'contact',(item->>'id')::uuid,record,auth.uid());
 end loop;
 for item in select value from jsonb_array_elements(p_payload->'opportunities') loop
  if (item->>'companyId')::uuid is distinct from source_company or item->>'id' is null or length(coalesce(item->>'interest',''))>200 then raise exception 'Invalid source opportunity' using errcode='22023'; end if;
  if exists(select 1 from public.local_draft_imports where company_id=p_company_id and source_company_id=source_company and object_type='opportunity' and source_id=(item->>'id')::uuid) then skipped:=skipped+1;continue;end if;
  select record_id into linked_contact from public.local_draft_imports where company_id=p_company_id and source_company_id=source_company and object_type='contact' and source_id=(item->>'contactId')::uuid;
  if linked_contact is null then raise exception 'Contact not imported to this company' using errcode='22023'; end if;
  insert into public.opportunities(company_id,contact_id,interest,original_source,stage) values(p_company_id,linked_contact,coalesce(item->>'interest',''),'local_import','new') returning id into record;
  insert into public.stage_history(company_id,opportunity_id,stage,reason,actor_id) values(p_company_id,record,'new','Rascunho local importado; etapa reiniciada para validação humana.',auth.uid());
  insert into public.local_draft_imports(company_id,source_company_id,object_type,source_id,record_id,imported_by) values(p_company_id,source_company,'opportunity',(item->>'id')::uuid,record,auth.uid());
  inserted_opportunities:=inserted_opportunities+1;
 end loop;
 for item in select value from jsonb_array_elements(p_payload->'contents') loop
  if (item->>'companyId')::uuid is distinct from source_company or item->>'id' is null then raise exception 'Invalid source content' using errcode='22023'; end if;
  if exists(select 1 from public.local_draft_imports where company_id=p_company_id and source_company_id=source_company and object_type='content' and source_id=(item->>'id')::uuid) then skipped:=skipped+1;continue;end if;
  insert into public.editorial_drafts(company_id,title,caption,format,planned_date,created_by) values(p_company_id,trim(item->>'title'),coalesce(item->>'caption',''),item->>'format',nullif(item->>'date','')::date,auth.uid()) returning id into record;
  insert into public.local_draft_imports(company_id,source_company_id,object_type,source_id,record_id,imported_by) values(p_company_id,source_company,'content',(item->>'id')::uuid,record,auth.uid());
  inserted_contents:=inserted_contents+1;
 end loop;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) values(w,p_company_id,auth.uid(),'drafts.imported',jsonb_build_object('sourceCompanyId',source_company,'contacts',inserted_contacts,'opportunities',inserted_opportunities,'contents',inserted_contents,'skipped',skipped));
 return jsonb_build_object('contacts',inserted_contacts,'opportunities',inserted_opportunities,'contents',inserted_contents,'skipped',skipped);
end;
$$;
revoke all on function public.import_local_drafts(uuid,jsonb) from public,anon;
grant execute on function public.import_local_drafts(uuid,jsonb) to authenticated;
commit;
