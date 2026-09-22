begin;
create table public.company_contact_channels(company_id uuid not null,contact_id uuid not null,channel text not null check(channel='whatsapp'),remote_id text not null,last_message_at timestamptz,last_preview text not null default '',updated_at timestamptz not null default now(),primary key(company_id,channel,remote_id),foreign key(company_id,contact_id) references public.contacts(company_id,id));
alter table public.company_contact_channels enable row level security;revoke all on public.company_contact_channels from public,anon,authenticated;grant select on public.company_contact_channels to authenticated;
create policy crm_channel_read on public.company_contact_channels for select to authenticated using(private.can_company_action(company_id,'crm.read'));
create function public.sync_whatsapp_crm(p_company_id uuid,p_contacts jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare v jsonb;c uuid;phone text;added integer:=0;linked integer:=0;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not exists(select 1 from public.company_channels where company_id=p_company_id and provider='evolution' and status='connected' and remote_id='askadia-'||p_company_id::text) then raise exception 'Channel unavailable' using errcode='42501';end if;
 if jsonb_typeof(p_contacts) is distinct from 'array' or jsonb_array_length(p_contacts)>200 then raise exception 'Invalid sync' using errcode='22023';end if;
 for v in select value from jsonb_array_elements(p_contacts) loop
  if not coalesce(v->>'jid' ~ '^[0-9]{6,20}@(s.whatsapp.net|lid)$',false) or length(coalesce(v->>'name','')) not between 1 and 150 or length(coalesce(v->>'preview',''))>1000 then raise exception 'Invalid contact' using errcode='22023';end if;
  c:=null;phone:=case when v->>'jid' ~ '^[1-9][0-9]{7,14}@s.whatsapp.net$' then '+'||split_part(v->>'jid','@',1) else null end;
  select contact_id into c from public.company_contact_channels where company_id=p_company_id and channel='whatsapp' and remote_id=v->>'jid';
  if c is null and phone is not null then select id into c from public.contacts where company_id=p_company_id and phone_e164=phone;end if;
  if c is null then insert into public.contacts(company_id,name,phone_e164) values(p_company_id,v->>'name',phone) returning id into c;added:=added+1;end if;
  insert into public.company_contact_channels(company_id,contact_id,channel,remote_id,last_message_at,last_preview) values(p_company_id,c,'whatsapp',v->>'jid',(v->>'time')::timestamptz,coalesce(v->>'preview','')) on conflict(company_id,channel,remote_id) do update set last_message_at=excluded.last_message_at,last_preview=excluded.last_preview,updated_at=now();
  if not exists(select 1 from public.opportunities where company_id=p_company_id and contact_id=c) then insert into public.opportunities(company_id,contact_id,interest,original_source) values(p_company_id,c,'Contato recebido pelo WhatsApp','whatsapp');end if;
  linked:=linked+1;
 end loop;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'crm.whatsapp_sync',jsonb_build_object('added',added,'linked',linked) from public.companies where id=p_company_id;
 return jsonb_build_object('added',added,'linked',linked);
end;$$;
revoke all on function public.sync_whatsapp_crm(uuid,jsonb) from public,anon;grant execute on function public.sync_whatsapp_crm(uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
