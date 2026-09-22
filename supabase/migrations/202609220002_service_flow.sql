-- Visual service flows and least-privilege context for assistance.
begin;
create function private.valid_service_flow(g jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare n jsonb;e jsonb;ports text[];start_id text;reached integer;cycle boolean;
begin
 if g is null or g='null'::jsonb then return true;end if;
 if jsonb_typeof(g) is distinct from 'object' or g->>'version' is distinct from '1' or jsonb_typeof(g->'nodes') is distinct from 'array' or jsonb_typeof(g->'edges') is distinct from 'array' then return false;end if;
 if jsonb_array_length(g->'nodes') not between 2 and 50 or jsonb_array_length(g->'edges')>100 then return false;end if;
 if (select count(distinct value->>'id') from jsonb_array_elements(g->'nodes'))<>jsonb_array_length(g->'nodes') or (select count(distinct value->>'id') from jsonb_array_elements(g->'edges'))<>jsonb_array_length(g->'edges') then return false;end if;
 if (select count(*) from jsonb_array_elements(g->'nodes') where value->>'kind'='start')<>1 then return false;end if;
 select value->>'id' into start_id from jsonb_array_elements(g->'nodes') where value->>'kind'='start';
 for n in select value from jsonb_array_elements(g->'nodes') loop
  if not coalesce(n->>'id' ~ '^[a-zA-Z0-9_-]{1,64}$',false) or not coalesce(n->>'kind' in ('start','condition','message','handoff'),false) or jsonb_typeof(n->'label') is distinct from 'string' or length(n->>'label')>80 or jsonb_typeof(n->'text') is distinct from 'string' or length(n->>'text')>2000 then return false;end if;
  if n->>'kind'<>'start' and length(trim(n->>'text'))=0 then return false;end if;
  if n->>'kind'='condition' and length(n->>'text')>120 then return false;end if;
  if jsonb_typeof(n->'position'->'x') is distinct from 'number' or jsonb_typeof(n->'position'->'y') is distinct from 'number' then return false;end if;
  if abs((n->'position'->>'x')::numeric)>10000 or abs((n->'position'->>'y')::numeric)>10000 then return false;end if;
  select coalesce(array_agg(value->>'port'),array[]::text[]) into ports from jsonb_array_elements(g->'edges') where value->>'source'=n->>'id';
  if cardinality(ports)<>(select count(distinct p) from unnest(ports) p) then return false;end if;
  if n->>'kind'='start' and ports<>array['next'] then return false;end if;
  if n->>'kind'='condition' and (cardinality(ports)<>2 or not ports @> array['yes','no']) then return false;end if;
  if n->>'kind'='handoff' and cardinality(ports)<>0 then return false;end if;
  if n->>'kind'='message' and (cardinality(ports)>1 or not ports <@ array['next']) then return false;end if;
 end loop;
 for e in select value from jsonb_array_elements(g->'edges') loop
  if not coalesce(e->>'id' ~ '^[a-zA-Z0-9_-]{1,64}$',false) or not coalesce(e->>'port' in ('next','yes','no'),false) or e->>'target'=start_id then return false;end if;
  if not exists(select 1 from jsonb_array_elements(g->'nodes') where value->>'id'=e->>'source') or not exists(select 1 from jsonb_array_elements(g->'nodes') where value->>'id'=e->>'target') then return false;end if;
 end loop;
 -- UNION deduplicates converging paths, bounding traversal even for malformed cycles.
 with recursive reach(id) as(select start_id union select e.value->>'target' from reach r cross join jsonb_array_elements(g->'edges') e where e.value->>'source'=r.id) select count(*) into reached from reach;
 if reached<>jsonb_array_length(g->'nodes') then return false;end if;
 with recursive closure(src,dst) as(select value->>'source',value->>'target' from jsonb_array_elements(g->'edges') union select c.src,e.value->>'target' from closure c cross join jsonb_array_elements(g->'edges') e where e.value->>'source'=c.dst) select exists(select 1 from closure where src=dst) into cycle;
 if cycle then return false;end if;
 return (select coalesce(sum(length(value->>'text')),0)<=6000 from jsonb_array_elements(g->'nodes') where value->>'kind'<>'condition');
end;$$;
alter table public.company_service_settings add column flow jsonb check(private.valid_service_flow(flow));
alter function public.save_service_settings(uuid,jsonb) rename to save_service_settings_legacy;
revoke all on function public.save_service_settings_legacy(uuid,jsonb) from public,anon,authenticated;
create function public.save_service_settings(p_company_id uuid,p_settings jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare saved jsonb;
begin
 if not coalesce(private.can_company_action(p_company_id,'marketing.write') and private.can_company_action(p_company_id,'crm.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not private.valid_service_flow(p_settings->'flow') then raise exception 'Invalid service flow' using errcode='22023';end if;
 saved:=public.save_service_settings_legacy(p_company_id,p_settings);
 if p_settings ? 'flow' then update public.company_service_settings set flow=nullif(p_settings->'flow','null'::jsonb) where company_id=p_company_id and channel=p_settings->>'channel' returning to_jsonb(company_service_settings.*) into saved;end if;
 return saved;
end;$$;
create function private.service_profile(p_company_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select (select jsonb_object_agg(key,jsonb_build_object('value',value->'value','status',value->'status')) from jsonb_each(v.facts) where key in ('name','businessType','city','address','services','structure','hours','offers','channels','sales')) from public.company_profile_versions v where company_id=p_company_id order by version desc limit 1;
$$;
revoke all on function private.service_profile(uuid) from public,anon,authenticated;
create or replace function public.inbox_ai_context(p_company_id uuid,p_channel text) returns jsonb language plpgsql security definer set search_path='' as $$
declare settings public.company_service_settings;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if (select count(*) from public.inbox_ai_attempts where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select * into settings from public.company_service_settings where company_id=p_company_id and channel=p_channel;
 if settings.company_id is null or settings.mode='human' then raise exception 'Configure assistance first' using errcode='22023';end if;
 insert into public.inbox_ai_attempts(company_id,actor_id) values(p_company_id,auth.uid());
 return jsonb_build_object('settings',to_jsonb(settings),'profile',private.service_profile(p_company_id));
end;$$;
create function public.inbox_prompt_context(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare profile jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write') and private.can_company_action(p_company_id,'crm.read') and private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 profile:=private.service_profile(p_company_id);
 if profile is null then raise exception 'Confirm company profile first' using errcode='22023';end if;
 if (select count(*) from public.inbox_ai_attempts where company_id=p_company_id and created_at>date_trunc('day',now()))>=100 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 insert into public.inbox_ai_attempts(company_id,actor_id) values(p_company_id,auth.uid());return profile;
end;$$;
revoke all on function public.save_service_settings(uuid,jsonb),public.inbox_prompt_context(uuid) from public,anon;
grant execute on function public.save_service_settings(uuid,jsonb),public.inbox_prompt_context(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
