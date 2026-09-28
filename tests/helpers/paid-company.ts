import type {PGlite} from '@electric-sql/pglite';
/** Local PostgreSQL fixture only. Existing AI tests exercise post-payment behavior. */
export async function paidCompanyFixture(db:PGlite,companyId:string){
 const role=(await db.query<{current_user:string}>('select current_user')).rows[0]!.current_user;
 await db.exec('reset role');
 try{await db.query("insert into public.company_subscriptions(company_id,plan_id,status,current_period_end,provider) values($1,'askadia_monthly','active',now()+interval '30 days','local-test-fixture') on conflict(company_id) do update set status='active',current_period_end=excluded.current_period_end,provider=excluded.provider",[companyId]);}
 finally{await db.query("select set_config('role',$1,false)",[role]);}
}
