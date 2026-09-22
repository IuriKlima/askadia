begin;
-- Service-only bridge: encrypted material never reaches browser/JWT clients.
create function public.read_company_meta_server(p_company_id uuid,p_actor uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare previous text;allowed boolean;payload jsonb;
begin
 if p_actor is null or p_action not in ('crm.read','crm.write','marketing.read','marketing.write','billing.manage') then raise exception 'Access denied' using errcode='42501';end if;
 previous:=current_setting('request.jwt.claim.sub',true);perform set_config('request.jwt.claim.sub',p_actor::text,true);
 allowed:=coalesce(private.can_company_action(p_company_id,p_action),false);
 perform set_config('request.jwt.claim.sub',coalesce(previous,''),true);
 if not allowed then raise exception 'Access denied' using errcode='42501';end if;
 select jsonb_build_object('remote_id',c.remote_id,'metadata',c.metadata,'cipher',s.cipher) into payload from public.company_channels c join private.channel_secrets s on s.channel_id=c.id where c.company_id=p_company_id and c.provider='meta' and c.status='connected';return payload;
end;$$;
revoke all on function public.read_company_meta_server(uuid,uuid,text) from public,anon,authenticated;
do $$begin if exists(select 1 from pg_roles where rolname='service_role') then grant execute on function public.read_company_meta_server(uuid,uuid,text) to service_role;end if;end;$$;
create function public.reserve_meta_dispatch(p_company_id uuid,p_channel text,p_thread text,p_id uuid,p_body text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'crm.write'),false) or p_channel not in ('instagram','facebook') or not exists(select 1 from public.inbox_handoffs where company_id=p_company_id and channel=p_channel and thread=p_thread and actor_id=auth.uid() and released_at is null) then raise exception 'Take over first' using errcode='42501';end if;
 if not exists(select 1 from public.company_channels where company_id=p_company_id and provider='meta' and status='connected') then raise exception 'Channel unavailable' using errcode='42501';end if;
 if p_thread !~ '^meta:[a-f0-9]{64}$' or p_id is null or length(trim(p_body)) not between 1 and 1000 then raise exception 'Invalid dispatch' using errcode='22023';end if;
 if exists(select 1 from public.inbox_dispatches where id=p_id) then return false;end if;
 if (select count(*) from public.inbox_dispatches where company_id=p_company_id and created_at>now()-interval '1 minute')>=30 then raise exception 'Dispatch rate limit' using errcode='22023';end if;
 insert into public.inbox_dispatches(id,company_id,thread,actor_id,body) values(p_id,p_company_id,p_thread,auth.uid(),trim(p_body));return true;
end;$$;
revoke all on function public.reserve_meta_dispatch(uuid,text,text,uuid,text) from public,anon;
grant execute on function public.reserve_meta_dispatch(uuid,text,text,uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
