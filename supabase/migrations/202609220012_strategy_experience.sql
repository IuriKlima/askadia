begin;
alter table public.company_strategy_briefs add column feedback text not null default '' check(length(feedback)<=3000);
create function public.strategy_feedback(p_company_id uuid,p_request uuid,p_feedback text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 update public.company_strategy_briefs set feedback=p_feedback where company_id=p_company_id and request_id=p_request and status='generating';
end;$$;
create function public.edit_company_strategy(p_company_id uuid,p_id uuid,p_generation integer,p_output jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.company_strategy_briefs;s public.company_onboarding;begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into b from public.company_strategy_briefs where id=p_id and company_id=p_company_id for update;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if b.id is null or b.generation<>p_generation or b.status not in ('review','approved') or b.profile_version<>s.profile_version or s.confirmed_revision is distinct from s.revision then raise exception 'Strategy changed' using errcode='40001';end if;
 if p_output is null or jsonb_typeof(p_output)<>'object' or length(p_output::text)>100000 or not(p_output ?& array['positioning','objectives','calendar','ads','keywords','unknowns']) or jsonb_typeof(p_output->'calendar')<>'array' or jsonb_array_length(p_output->'calendar') not between 8 and 12 then raise exception 'Invalid strategy' using errcode='22023';end if;
 update public.company_strategy_briefs set output=p_output,generation=generation+1,status='review',approved_by=null,approved_generation=null,model='human-edit',created_at=now() where id=b.id returning * into b;
 insert into public.company_strategy_history(company_id,brief_id,generation,profile_version,output,model) values(p_company_id,b.id,b.generation,b.profile_version,p_output,'human-edit');
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'strategy.edited',jsonb_build_object('briefId',b.id,'generation',b.generation) from public.companies where id=p_company_id;return to_jsonb(b);
end;$$;
-- New strategies obey two posts per ISO week. Existing approved calendars are untouched.
create function private.calendar_week_limit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.planned_date is not null and (tg_op='INSERT' or old.planned_date is distinct from new.planned_date) and exists(select 1 from public.company_strategy_briefs b where b.id=new.brief_id and b.output ? 'diagnosis') then
 perform 1 from public.companies where id=new.company_id for update;
 if (select count(*) from public.company_calendar_items i where i.company_id=new.company_id and i.id<>new.id and i.planned_date is not null and date_trunc('week',i.planned_date::timestamp)=date_trunc('week',new.planned_date::timestamp) and private.calendar_current(i.company_id,i.brief_id,i.generation,i.profile_version))>=2 then raise exception 'Weekly publication limit' using errcode='22023';end if;
 end if;return new;
end;$$;
create trigger calendar_week_limit before insert or update of planned_date on public.company_calendar_items for each row execute function private.calendar_week_limit();
revoke all on function private.calendar_week_limit() from public,anon,authenticated;
revoke all on function public.strategy_feedback(uuid,uuid,text),public.edit_company_strategy(uuid,uuid,integer,jsonb) from public,anon;
grant execute on function public.strategy_feedback(uuid,uuid,text),public.edit_company_strategy(uuid,uuid,integer,jsonb) to authenticated;
alter function public.start_calendar_dates(uuid,uuid,date) rename to start_calendar_dates_base;
revoke all on function public.start_calendar_dates_base(uuid,uuid,date) from public,anon,authenticated;
create function public.start_calendar_dates(p_company_id uuid,p_id uuid,p_month date) returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb;existing jsonb;
begin
 context:=public.start_calendar_dates_base(p_company_id,p_id,p_month);
 select coalesce(jsonb_agg(i.planned_date),'[]'::jsonb) into existing from public.company_calendar_items i where i.company_id=p_company_id and i.planned_date is not null and private.calendar_current(i.company_id,i.brief_id,i.generation,i.profile_version);
 return context||jsonb_build_object('existingDates',existing);
end;$$;
revoke all on function public.start_calendar_dates(uuid,uuid,date) from public,anon;
grant execute on function public.start_calendar_dates(uuid,uuid,date) to authenticated;
notify pgrst,'reload schema';
commit;
