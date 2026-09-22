begin;
-- Internal visual catalog; existing attachment RLS and upload permissions remain unchanged.
alter table public.onboarding_attachments
 add column visual_description jsonb,
 add column description_status text not null default 'pending' check(description_status in ('pending','processing','ready','failed','unsupported')),
 add column description_attempts integer not null default 0,
 add column description_token uuid,
 add column description_updated_at timestamptz,
 add column description_model text;
update public.onboarding_attachments set description_status='unsupported' where mime not in ('image/jpeg','image/png','image/webp');
create index attachment_description_queue on public.onboarding_attachments(description_status,created_at);
create function public.claim_image_description_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.onboarding_attachments;t uuid:=gen_random_uuid();
begin
 select * into a from public.onboarding_attachments x where x.mime in ('image/jpeg','image/png','image/webp')
 and x.description_status in ('pending','processing','failed') and x.description_attempts<3
 and (x.description_updated_at is null or x.description_updated_at<now()-interval '5 minutes')
 order by x.description_attempts,x.created_at for update skip locked limit 1;
 if not found then return null;end if;
 update public.onboarding_attachments set description_status='processing',description_attempts=description_attempts+1,
 description_token=t,description_updated_at=now() where id=a.id and company_id=a.company_id;
 return jsonb_build_object('id',a.id,'companyId',a.company_id,'path',a.object_path,'mime',a.mime,'token',t);
end;$$;
create function public.finish_image_description_server(p_company_id uuid,p_id uuid,p_token uuid,p_description jsonb,p_model text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if p_description is not null and (jsonb_typeof(p_description)<>'object' or length(p_description::text)>12000
 or coalesce(length(p_description->>'description'),0)=0) then raise exception 'Invalid description';end if;
 update public.onboarding_attachments set description_status=case when p_description is null then 'failed' else 'ready' end,
 visual_description=p_description,description_model=left(p_model,120),description_updated_at=now(),description_token=null
 where company_id=p_company_id and id=p_id and description_token=p_token and description_status='processing';
 return found;
end;$$;
revoke all on function public.claim_image_description_server(),public.finish_image_description_server(uuid,uuid,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.claim_image_description_server(),public.finish_image_description_server(uuid,uuid,uuid,jsonb,text) to service_role;
commit;
