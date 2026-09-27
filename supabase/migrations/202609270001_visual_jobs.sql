begin;
create table public.company_visual_jobs(
 id uuid primary key,company_id uuid not null references public.companies(id),actor_id uuid not null references public.profiles(id),profile_version integer not null,
 kind text not null check(kind in ('site_image','campaign_creative')),source_attachment_id uuid references public.onboarding_attachments(id),plan_id uuid references public.company_paid_plans(id),campaign_index integer,
 instructions text not null default '' check(length(instructions)<=2000),ratio text not null check(ratio in ('16:9','4:5','1:1','9:16')),reference_ids uuid[] not null default '{}',request jsonb not null,
 status text not null default 'pending' check(status in ('pending','running','completed','failed','stale')),attempts integer not null default 0,token uuid,lease_until timestamptz,next_attempt_at timestamptz not null default now(),
 result_attachment_id uuid references public.onboarding_attachments(id),error text,model text,provider_usage jsonb,image_quality text,image_size text,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.company_visual_jobs enable row level security;
revoke all on public.company_visual_jobs from public,anon,authenticated;
grant select on public.company_visual_jobs to authenticated;
create policy visual_read on public.company_visual_jobs for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create index visual_job_queue on public.company_visual_jobs(next_attempt_at) where status in ('pending','running');
create table private.visual_attempts(id uuid primary key default gen_random_uuid(),company_id uuid not null,actor_id uuid not null,created_at timestamptz not null default now());
revoke all on private.visual_attempts from public,anon,authenticated;

create function public.enqueue_visual_job(p_company_id uuid,p_data jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;p public.company_paid_plans;old public.company_visual_jobs;refs uuid[];source uuid;kind text:=p_data->>'kind';
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if s.profile_version<1 or s.confirmed_revision is distinct from s.revision then raise exception 'Confirm current profile' using errcode='22023';end if;
 if p_data is null or kind not in ('site_image','campaign_creative') or p_data->>'ratio' not in ('16:9','4:5','1:1','9:16') or length(coalesce(p_data->>'instructions',''))>2000 or jsonb_typeof(p_data->'references') is distinct from 'array' or jsonb_array_length(p_data->'references')>5 then raise exception 'Invalid visual request' using errcode='22023';end if;
 select * into old from public.company_visual_jobs where id=(p_data->>'id')::uuid;
 if found then if old.company_id<>p_company_id or old.actor_id<>auth.uid() or old.request<>p_data then raise exception 'Request changed' using errcode='40001';end if;return old.id;end if;
 if (select count(*) from public.company_visual_jobs where company_id=p_company_id and created_at>now()-interval '1 day')>=30 then raise exception 'Daily account allowance exhausted' using errcode='22023';end if;
 select coalesce(array_agg(value::uuid),'{}') into refs from jsonb_array_elements_text(p_data->'references');source:=(p_data->>'sourceId')::uuid;
 if kind='site_image' then
  if source is null or length(trim(coalesce(p_data->>'instructions','')))<5 or p_data->>'planId' is not null then raise exception 'Original photo required' using errcode='22023';end if;refs:=array_prepend(source,refs);
 else
  select * into p from public.company_paid_plans where company_id=p_company_id and id=(p_data->>'planId')::uuid and status='ready';
  if p.id is null or p.profile_version<>s.profile_version or (p_data->>'campaignIndex')::integer is null or (p_data->>'campaignIndex')::integer<0 or (p_data->>'campaignIndex')::integer>=jsonb_array_length(p.output->'campaigns') or source is not null then raise exception 'Current campaign required' using errcode='22023';end if;
 end if;
 if kind='campaign_creative' and cardinality(refs)=0 then
  select coalesce(array_agg(a.id),'{}') into refs from (select id from public.onboarding_attachments a where a.company_id=p_company_id and a.mime in ('image/png','image/jpeg','image/webp') and not exists(select 1 from public.company_visual_jobs j where j.result_attachment_id=a.id) order by a.created_at desc limit 5) a;
 end if;
 if exists(select 1 from unnest(refs) x where not exists(select 1 from public.onboarding_attachments a where a.id=x and a.company_id=p_company_id and a.mime in ('image/png','image/jpeg','image/webp'))) then raise exception 'Company materials required' using errcode='42501';end if;
 insert into public.company_visual_jobs(id,company_id,actor_id,profile_version,kind,source_attachment_id,plan_id,campaign_index,instructions,ratio,reference_ids,request)
 values((p_data->>'id')::uuid,p_company_id,auth.uid(),s.profile_version,kind,source,p.id,(p_data->>'campaignIndex')::integer,coalesce(p_data->>'instructions',''),p_data->>'ratio',refs,p_data);
 return (p_data->>'id')::uuid;
end;$$;

create function private.visuals_after_paid_plan() returns trigger language plpgsql security definer set search_path='' as $$
declare refs jsonb;i integer;previous text;
begin
 if new.status<>'ready' or new.output is null or old.status='ready' then return new;end if;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',new.actor_id::text,true);
 select coalesce(jsonb_agg(id),'[]') into refs from (select id from public.onboarding_attachments where company_id=new.company_id and mime in ('image/png','image/jpeg','image/webp') and not exists(select 1 from public.company_visual_jobs j where j.result_attachment_id=onboarding_attachments.id) order by created_at desc limit 5) x;
 for i in 0..least(jsonb_array_length(new.output->'campaigns'),8)-1 loop
  begin
   perform public.enqueue_visual_job(new.company_id,jsonb_build_object('id',gen_random_uuid(),'kind','campaign_creative','sourceId',null,'planId',new.id,'campaignIndex',i,'instructions','','ratio',case when new.output->'campaigns'->i->>'provider'='meta' then '4:5' else '16:9' end,'references',refs));
  exception when sqlstate '22023' then exit;end;
 end loop;
 perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);return new;
end;$$;
create trigger visuals_after_paid_plan after update of status on public.company_paid_plans for each row execute function private.visuals_after_paid_plan();

create function public.claim_visual_job_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_visual_jobs;s public.company_onboarding;refs jsonb;campaign jsonb;t uuid:=gen_random_uuid();
begin
 select * into j from public.company_visual_jobs where (status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now()) order by next_attempt_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;if not found then return null;end if;
 select * into j from public.company_visual_jobs where id=j.id and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);
 select * into s from public.company_onboarding where company_id=j.company_id;
 if not coalesce(private.can_company_action(j.company_id,'marketing.write'),false) or s.profile_version<>j.profile_version or s.confirmed_revision is distinct from s.revision then update public.company_visual_jobs set status='stale',token=null,error='O perfil ou as permissões mudaram. Revise antes de solicitar novamente.' where id=j.id;return null;end if;
 if j.kind='campaign_creative' and not private.journey_valid(j.company_id,5) then update public.company_visual_jobs set next_attempt_at=now()+interval '1 minute',status='pending',error='A produção aguarda a aprovação das cinco etapas da estratégia.' where id=j.id;return null;end if;
 if j.attempts>=3 then update public.company_visual_jobs set status='failed',token=null,error='A geração não concluiu após três tentativas. O material original foi preservado.' where id=j.id;return null;end if;
 if (select count(*) from private.visual_attempts where company_id=j.company_id and created_at>now()-interval '1 day')>=12 or (select count(*) from private.visual_attempts where actor_id=j.actor_id and created_at>now()-interval '1 day')>=30 then update public.company_visual_jobs set status='pending',next_attempt_at=now()+interval '1 hour',error='Aguardando renovação do limite diário de geração de imagens.' where id=j.id;return null;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'mime',a.mime,'path',a.object_path) order by ref.n),'[]') into refs from unnest(j.reference_ids) with ordinality ref(id,n) join public.onboarding_attachments a on a.id=ref.id and a.company_id=j.company_id;
 if jsonb_array_length(refs)<>cardinality(j.reference_ids) then update public.company_visual_jobs set status='failed',error='Um material selecionado não está mais disponível.' where id=j.id;return null;end if;
 if j.plan_id is not null then select output->'campaigns'->j.campaign_index into campaign from public.company_paid_plans where id=j.plan_id and company_id=j.company_id and profile_version=j.profile_version and status='ready';end if;
 insert into private.visual_attempts(company_id,actor_id) values(j.company_id,j.actor_id);
 update public.company_visual_jobs set status='running',token=t,lease_until=now()+interval '5 minutes',attempts=attempts+1,error=null,updated_at=now() where id=j.id;
 return jsonb_build_object('id',j.id,'companyId',j.company_id,'token',t,'request',jsonb_build_object('kind',j.kind,'ratio',j.ratio,'instructions',j.instructions,'facts',s.facts,'campaign',campaign),'references',refs);
end;$$;

create function public.finish_visual_job_server(p_id uuid,p_token uuid,p_result jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.company_visual_jobs;s public.company_onboarding;path text;asset uuid;
begin
 select * into j from public.company_visual_jobs where id=p_id;if not found then return false;end if;
 perform 1 from public.companies where id=j.company_id for update;
 select * into j from public.company_visual_jobs where id=p_id and status='running' and token=p_token and lease_until>now() for update;if not found then return false;end if;
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);select * into s from public.company_onboarding where company_id=j.company_id;
 if not coalesce(private.can_company_action(j.company_id,'marketing.write'),false) or s.profile_version<>j.profile_version or s.confirmed_revision is distinct from s.revision or (j.kind='campaign_creative' and not private.journey_valid(j.company_id,5)) then update public.company_visual_jobs set status='stale',token=null,error='A versão ou autorização mudou durante a geração.' where id=j.id;return false;end if;
 if p_result is null then update public.company_visual_jobs set status=case when attempts<3 then 'pending' else 'failed' end,token=null,next_attempt_at=now()+interval '1 minute',error='O provedor não concluiu a imagem. O original foi preservado.',updated_at=now() where id=j.id;return true;end if;
 asset:=(p_result->>'attachmentId')::uuid;path:=j.company_id::text||'/onboarding/'||asset::text||case p_result->>'mime' when 'image/jpeg' then '.jpg' when 'image/png' then '.png' when 'image/webp' then '.webp' else '' end;
 if asset is null or p_result->>'mime' not in ('image/jpeg','image/png','image/webp') or (p_result->>'size')::integer not between 1 and 10485760 or not exists(select 1 from storage.objects where bucket_id='company-assets' and name=path) then raise exception 'Stored image required' using errcode='22023';end if;
 insert into public.onboarding_attachments(id,company_id,name,mime,size,object_path,uploaded_by) values(asset,j.company_id,case j.kind when 'site_image' then 'Foto editada' else 'Criativo da campanha' end||' · '||j.ratio||' · '||left(j.id::text,8),p_result->>'mime',(p_result->>'size')::integer,path,j.actor_id);
 update public.company_visual_jobs set status='completed',token=null,result_attachment_id=asset,model=left(p_result->>'model',100),provider_usage=nullif(p_result->'usage','null'::jsonb),image_quality=left(p_result->>'quality',20),image_size=left(p_result->>'dimensions',30),error=null,updated_at=now() where id=j.id;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,j.actor_id,'visual.completed',jsonb_build_object('jobId',j.id,'kind',j.kind,'attachmentId',asset,'sourceId',j.source_attachment_id) from public.companies where id=j.company_id;
 return true;
end;$$;
revoke all on function public.enqueue_visual_job(uuid,jsonb) from public,anon;
grant execute on function public.enqueue_visual_job(uuid,jsonb) to authenticated;
revoke all on function private.visuals_after_paid_plan(),public.claim_visual_job_server(),public.finish_visual_job_server(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.claim_visual_job_server(),public.finish_visual_job_server(uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
