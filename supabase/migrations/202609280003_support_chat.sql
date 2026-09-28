-- Chamados autenticados: não envia mensagens externas nem consome IA.
begin;
create table public.support_tickets(
 id uuid primary key, number bigint generated always as identity unique,
 company_id uuid references public.companies(id), created_by uuid not null references public.profiles(id),
 subject text not null check(length(trim(subject)) between 5 and 160),
 status text not null default 'open' check(status in ('open','in_progress','waiting_customer','resolved')),
 page text not null check(length(page)<=160 and page ~ '^/[a-zA-Z0-9/_-]*$'),
 transcript jsonb not null default '[]' check(jsonb_typeof(transcript)='array' and jsonb_array_length(transcript)<=8 and octet_length(transcript::text)<=24000),
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index support_tickets_actor on public.support_tickets(created_by,updated_at desc);
create index support_tickets_company on public.support_tickets(company_id,updated_at desc);
create table public.support_messages(
 id uuid primary key, ticket_id uuid not null references public.support_tickets(id),
 author_id uuid not null references public.profiles(id), author_kind text not null check(author_kind in ('customer','staff')),
 body text not null check(length(trim(body)) between 1 and 4000), created_at timestamptz not null default now()
);
create index support_messages_ticket on public.support_messages(ticket_id,created_at,id);
create function private.support_ticket_visible(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.support_tickets x where x.id=t and (
  (x.created_by=auth.uid() and (x.company_id is null or private.can_company_action(x.company_id,'company.read')))
  or private.assigned_to(x.company_id)));
$$;
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
revoke all on public.support_tickets,public.support_messages from public,anon,authenticated;
grant select on public.support_tickets,public.support_messages to authenticated;
create policy support_tickets_read on public.support_tickets for select to authenticated using(private.support_ticket_visible(id));
create policy support_messages_read on public.support_messages for select to authenticated using(private.support_ticket_visible(ticket_id));

create function public.support_ticket_detail(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare ticket jsonb;messages jsonb;
begin
 if not coalesce(private.support_ticket_visible(p_id),false) then raise exception 'Access denied' using errcode='42501';end if;
 select to_jsonb(t)||jsonb_build_object('company_name',c.name) into ticket from public.support_tickets t left join public.companies c on c.id=t.company_id where t.id=p_id;
 select coalesce(jsonb_agg(to_jsonb(m) order by m.created_at,m.id),'[]') into messages from (select * from public.support_messages where ticket_id=p_id order by created_at desc,id desc limit 100) m;
 return jsonb_build_object('ticket',ticket,'messages',messages);
end;$$;
create function public.support_ticket_list(p_team boolean default false,p_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;
begin
 if auth.uid() is null or (p_team and private.staff_role() is null) then raise exception 'Access denied' using errcode='42501';end if;
 if p_offset is null or p_offset<0 or p_offset>10000 then raise exception 'Invalid offset' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.updated_at desc,t.id),'[]') into rows from (
  select x.*,c.name company_name from public.support_tickets x left join public.companies c on c.id=x.company_id
  where case when p_team then coalesce(private.assigned_to(x.company_id),false) else x.created_by=auth.uid() and private.support_ticket_visible(x.id) end
  order by x.updated_at desc,x.id limit 20 offset p_offset
 ) t;
 return rows;
end;$$;
create function public.create_support_ticket(p_id uuid,p_company_id uuid,p_subject text,p_message text,p_page text,p_transcript jsonb default '[]') returns jsonb language plpgsql security definer set search_path='' as $$
declare existing public.support_tickets;item jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid()) or (p_company_id is not null and not coalesce(private.can_company_action(p_company_id,'company.read'),false)) then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.profiles where id=auth.uid() for update;
 if p_id is null or p_subject is null or length(trim(p_subject)) not between 5 and 160 or p_message is null or length(trim(p_message)) not between 10 and 4000 or p_page is null or length(p_page)>160 or p_page !~ '^/[a-zA-Z0-9/_-]*$' or p_transcript is null or jsonb_typeof(p_transcript)<>'array' then raise exception 'Invalid ticket' using errcode='22023';end if;
 if jsonb_array_length(p_transcript)>8 or octet_length(p_transcript::text)>24000 then raise exception 'Invalid transcript' using errcode='22023';end if;
 for item in select value from jsonb_array_elements(p_transcript) loop
  if jsonb_typeof(item)<>'object' or not(item ? 'role' and item ? 'text') or jsonb_typeof(item->'role')<>'string' or item->>'role' not in ('user','assistant') or jsonb_typeof(item->'text')<>'string' or length(trim(item->>'text')) not between 1 and 2000 or (select count(*) from jsonb_object_keys(item))<>2 then raise exception 'Invalid transcript' using errcode='22023';end if;
 end loop;
 select * into existing from public.support_tickets where id=p_id;
 if found then
  if existing.created_by<>auth.uid() or existing.company_id is distinct from p_company_id or existing.subject<>trim(p_subject) or existing.page<>p_page or existing.transcript<>p_transcript or not exists(select 1 from public.support_messages where id=p_id and ticket_id=p_id and body=trim(p_message)) then raise exception 'Ticket request conflict' using errcode='23505';end if;
  return public.support_ticket_detail(p_id);
 end if;
 if (select count(*) from public.support_tickets where created_by=auth.uid() and created_at>now()-interval '1 hour')>=10 then raise exception 'Support rate limit' using errcode='P0429';end if;
 insert into public.support_tickets(id,company_id,created_by,subject,page,transcript) values(p_id,p_company_id,auth.uid(),trim(p_subject),p_page,p_transcript);
 insert into public.support_messages(id,ticket_id,author_id,author_kind,body) values(p_id,p_id,auth.uid(),'customer',trim(p_message));
 insert into public.platform_audit(actor_id,company_id,action,details) values(auth.uid(),p_company_id,'support.ticket_created',jsonb_build_object('ticketId',p_id));
 return public.support_ticket_detail(p_id);
end;$$;
create function public.reply_support_ticket(p_ticket_id uuid,p_id uuid,p_message text) returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.support_tickets;m public.support_messages;staff boolean;
begin
 if not coalesce(private.support_ticket_visible(p_ticket_id),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into t from public.support_tickets where id=p_ticket_id for update;
 if p_id is null or p_message is null or length(trim(p_message)) not between 1 and 4000 then raise exception 'Invalid reply' using errcode='22023';end if;
 select * into m from public.support_messages where id=p_id;
 if found then
  if m.ticket_id<>p_ticket_id or m.author_id<>auth.uid() or m.body<>trim(p_message) then raise exception 'Reply request conflict' using errcode='23505';end if;
  return public.support_ticket_detail(p_ticket_id);
 end if;
 if (select count(*) from public.support_messages where author_id=auth.uid() and ticket_id=p_ticket_id and created_at>now()-interval '1 hour')>=30 then raise exception 'Support rate limit' using errcode='P0429';end if;
 staff:=t.created_by<>auth.uid() and coalesce(private.assigned_to(t.company_id),false);
 insert into public.support_messages(id,ticket_id,author_id,author_kind,body) values(p_id,p_ticket_id,auth.uid(),case when staff then 'staff' else 'customer' end,trim(p_message));
 update public.support_tickets set status=case when staff then 'waiting_customer' else 'open' end,version=version+1,updated_at=now() where id=p_ticket_id;
 insert into public.platform_audit(actor_id,company_id,action,details) values(auth.uid(),t.company_id,'support.ticket_replied',jsonb_build_object('ticketId',p_ticket_id));
 return public.support_ticket_detail(p_ticket_id);
end;$$;
create function public.set_support_ticket_status(p_id uuid,p_status text,p_version integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.support_tickets;
begin
 select * into t from public.support_tickets where id=p_id for update;
 if not found or not coalesce(private.assigned_to(t.company_id),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_status is null or p_status not in ('open','in_progress','waiting_customer','resolved') or p_version is null then raise exception 'Invalid status' using errcode='22023';end if;
 if t.version<>p_version then raise exception 'Ticket changed' using errcode='40001';end if;
 update public.support_tickets set status=p_status,version=version+1,updated_at=now() where id=p_id;
 insert into public.platform_audit(actor_id,company_id,action,details) values(auth.uid(),t.company_id,'support.ticket_status',jsonb_build_object('ticketId',p_id,'status',p_status));
 return public.support_ticket_detail(p_id);
end;$$;
revoke all on function public.support_ticket_detail(uuid),public.support_ticket_list(boolean,integer),public.create_support_ticket(uuid,uuid,text,text,text,jsonb),public.reply_support_ticket(uuid,uuid,text),public.set_support_ticket_status(uuid,text,integer) from public,anon,authenticated;
grant execute on function public.support_ticket_detail(uuid),public.support_ticket_list(boolean,integer),public.create_support_ticket(uuid,uuid,text,text,text,jsonb),public.reply_support_ticket(uuid,uuid,text),public.set_support_ticket_status(uuid,text,integer) to authenticated;
notify pgrst,'reload schema';
commit;
