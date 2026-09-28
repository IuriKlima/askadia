-- Novas ofertas; mantém o histórico das contratações anteriores.
begin;
alter table public.plan_catalog drop constraint plan_catalog_id_check;
alter table public.plan_catalog add constraint plan_catalog_id_check check(id in ('basic','premium','weekly','askadia_monthly','askadia_annual','askadia_semiannual'));
alter table public.company_subscriptions drop constraint company_subscriptions_plan_id_check;
alter table public.company_subscriptions add constraint company_subscriptions_plan_id_check check(plan_id in ('basic','premium','askadia_monthly','askadia_annual','askadia_semiannual'));
update public.plan_catalog set price_cents=159700 where id='askadia_monthly';
insert into public.plan_catalog(id,name,kind,price_cents,features,quotas) values
 ('askadia_semiannual','Askadia Semestral · até 6 parcelas','plan',800000,array['strategy','content','crm','sites','inbox','triage','ads','campaigns','analytics'],'{}');
alter table public.company_test_checkouts drop constraint company_test_checkouts_plan_id_check;
alter table public.company_test_checkouts add constraint company_test_checkouts_plan_id_check check(plan_id in ('askadia_monthly','askadia_annual','askadia_semiannual'));
alter table public.company_test_checkouts drop constraint company_test_checkouts_check;
alter table public.company_test_checkouts add constraint company_test_checkouts_check check(
 (plan_id='askadia_monthly' and installments=1 and installment_cents=total_cents and total_cents in (149700,159700)) or
 (plan_id='askadia_annual' and installment_cents=99800 and installments=12 and total_cents=1197600) or
 (plan_id='askadia_semiannual' and installments between 1 and 6 and total_cents=800000 and installment_cents=800000/installments)
);
-- Um checkout antigo pendente não pode liberar a oferta substituída.
update public.company_test_checkouts set status='cancelled',resolved_at=now() where status='pending' and (plan_id='askadia_annual' or (plan_id='askadia_monthly' and total_cents=149700));
drop function public.begin_test_checkout(uuid,uuid,text);
create function public.begin_test_checkout(p_company_id uuid,p_id uuid,p_plan text,p_installments integer default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare x public.company_test_checkouts;n integer;total integer;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'billing.manage'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if not exists(select 1 from public.company_onboarding where company_id=p_company_id and profile_version>0 and confirmed_revision=revision) then raise exception 'Confirm onboarding first' using errcode='22023';end if;
 if p_id is null or p_plan is null or p_plan not in ('askadia_monthly','askadia_semiannual') then raise exception 'Invalid checkout' using errcode='22023';end if;
 n:=coalesce(p_installments,case when p_plan='askadia_semiannual' then 6 else 1 end);
 if n not between 1 and 6 or (p_plan='askadia_monthly' and n<>1) then raise exception 'Invalid installments' using errcode='22023';end if;
 total:=case when p_plan='askadia_semiannual' then 800000 else 159700 end;
 select * into x from public.company_test_checkouts where id=p_id;
 if found then
  if x.company_id<>p_company_id or x.actor_id<>auth.uid() or x.plan_id<>p_plan or x.installments<>n or x.total_cents<>total then raise exception 'Checkout conflict' using errcode='22023';end if;
  return to_jsonb(x);
 end if;
 if private.company_ai_access(p_company_id) then raise exception 'Company already activated' using errcode='22023';end if;
 update public.company_test_checkouts set status='cancelled',resolved_at=now() where company_id=p_company_id and status='pending';
 insert into public.company_test_checkouts(id,company_id,actor_id,plan_id,installment_cents,installments,total_cents) values
 (p_id,p_company_id,auth.uid(),p_plan,total/n,n,total) returning * into x;
 return to_jsonb(x);
end;$$;
revoke all on function public.begin_test_checkout(uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function public.begin_test_checkout(uuid,uuid,text,integer) to authenticated;
notify pgrst,'reload schema';
commit;
