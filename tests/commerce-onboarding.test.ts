import {afterAll,beforeAll,describe,expect,it} from 'vitest';
import {PGlite} from '@electric-sql/pglite';
import {readFileSync,readdirSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {commercePlans} from '../packages/contracts/src/commerce';
let db:PGlite,company:string,second:string;const owner=randomUUID(),outsider=randomUUID(),reader=randomUUID();
async function as(id:string){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec('set role authenticated');}
async function server(){await db.exec('reset role;set role service_role');}
async function scalar<T=unknown>(sql:string,args:unknown[]=[]):Promise<T>{return Object.values((await db.query<Record<string,T>>(sql,args)).rows[0]!)[0]!;}
async function begin(plan='askadia_annual',id=randomUUID(),c=company){await as(owner);return scalar<{id:string;status:string;installment_cents:number;installments:number;total_cents:number}>('select public.begin_test_checkout($1,$2,$3)',[c,id,plan]);}
async function resolve(id:string,outcome='approved',actor=owner,c=company){await server();return scalar<{status:string}>('select public.complete_test_checkout_server($1,$2,$3,$4,$5)',[c,id,actor,outcome,true]);}
async function state(c=company){return scalar<{aiAllowed:boolean;accessMode:string;setupComplete:boolean;planId:string;latestCheckout:{id:string}|null}>('select public.company_purchase_state($1)',[c]);}
describe('Free onboarding, company billing and payment-gated AI',()=>{
 beforeAll(async()=>{db=new PGlite();await db.exec(`create role anon nologin;create role authenticated nologin;create role service_role nologin;create schema auth;create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant usage on schema auth to authenticated,anon;grant execute on function auth.uid() to authenticated,anon;create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);alter table storage.objects enable row level security;grant usage on schema storage to authenticated,anon;grant select,insert,update,delete on storage.objects to authenticated;`);
 for(const f of readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort())await db.exec(readFileSync('supabase/migrations/'+f,'utf8').replace('create extension if not exists pgcrypto;',''));
 for(const id of [owner,outsider,reader]){await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[id,id+'@example.test']);await db.query('insert into public.profiles(id,display_name) values($1,$2)',[id,'Teste']);}
 await as(owner);company=(await scalar<{companyId:string}>('select public.begin_company_onboarding($1)',[randomUUID()])).companyId;const w=await scalar<string>("select public.create_workspace('Segunda empresa')");second=(await scalar<{companyId:string}>('select public.begin_company_onboarding($1,$2)',[randomUUID(),w])).companyId;
 await db.exec('reset role');await db.query("insert into public.company_members(company_id,user_id,role) values($1,$2,'reader')",[company,reader]);
 },120000);
 afterAll(async()=>{await db?.close();});
 it('keeps onboarding free but rejects AI entrypoints before payment and does not spend quota',async()=>{
  await as(owner);expect((await state()).aiAllowed).toBe(false);expect(await scalar('select public.company_onboarding_read($1)',[company])).toBeTruthy();await expect(begin()).rejects.toThrow('Confirm onboarding');
  for(const [sql,args] of [
   ['select public.reserve_onboarding_provider($1,$2,$3)',[company,randomUUID(),'interpretation']],
   ['select public.start_company_strategy($1,$2)',[company,randomUUID()]],
   ['select public.start_content_run($1,$2,$3)',[company,randomUUID(),'details']],
   ['select public.start_calendar_dates($1,$2,$3)',[company,randomUUID(),'2026-10-01']],
   ['select public.reserve_site_generation($1,$2)',[company,randomUUID()]],
   ['select public.begin_paid_plan($1,$2,$3,$4)',[company,randomUUID(),100,30]],
   ['select public.inbox_ai_context($1,$2)',[company,'whatsapp']],
   ['select public.inbox_prompt_context($1)',[company]],
  ] as [string,unknown[]][]){await expect(scalar(sql,args)).rejects.toThrow('Payment required');}
  await db.exec('reset role');expect(await scalar('select count(*)::int from public.onboarding_provider_attempts where company_id=$1',[company])).toBe(0);
 });
 it('holds queued work before payment without consuming attempts',async()=>{
  await db.exec('reset role');for(const c of [company,second]){await db.query("insert into public.company_profile_versions(company_id,version,facts,confirmed_by) values($1,1,'{}',$2)",[c,owner]);await db.query('update public.company_onboarding set profile_version=1,confirmed_revision=revision where company_id=$1',[c]);}
  await db.query("insert into public.company_visual_jobs(id,company_id,actor_id,profile_version,kind,ratio,request) values($1,$2,$3,1,'site_image','16:9','{}')",[randomUUID(),company,owner]);
  const attachment=randomUUID();await db.query("insert into public.onboarding_attachments(id,company_id,name,mime,size,object_path,uploaded_by) values($1,$2,'fixture.png','image/png',8,$3,$4)",[attachment,company,company+'/onboarding/'+attachment+'.png',owner]);
  await as(owner);await scalar('select public.enqueue_content_preparation($1)',[company]);await scalar('select public.enqueue_company_launch($1)',[company]);
  await server();for(const name of ['claim_content_preparation_server','claim_company_launch_server','claim_visual_job_server','claim_image_description_server','claim_ad_plan_seed_server'])expect(await scalar('select public.'+name+'()')).toBeNull();expect(await scalar("select public.claim_ad_execution_server('prepare')")).toBeNull();expect(await scalar('select public.inbox_auto_targets()')).toEqual([]);
  await as(owner);expect(await scalar('select max(attempts)::int from public.company_content_preparations where company_id=$1',[company])).toBe(0);
 });
 it('fixes prices server-side, persists resumable checkout and isolates every company',async()=>{
  const c=await begin();expect([c.installment_cents,c.installments,c.total_cents]).toEqual([99800,12,1197600]);expect(commercePlans[1].totalCents).toBe(c.total_cents);expect(await begin('askadia_annual',c.id)).toEqual(c);expect((await state()).latestCheckout?.id).toBe(c.id);
  await expect(begin('askadia_monthly',c.id)).rejects.toThrow('conflict');await as(outsider);await expect(state()).rejects.toThrow('Access denied');await as(reader);await expect(scalar('select public.begin_test_checkout($1,$2,$3)',[company,randomUUID(),'askadia_monthly'])).rejects.toThrow('Access denied');expect((await state()).latestCheckout).toBeNull();
  await as(owner);await expect(scalar('select public.complete_test_checkout_server($1,$2,$3,$4,true)',[company,c.id,owner,'approved'])).rejects.toThrow('permission denied');await expect(scalar("update public.company_test_checkouts set status='test_approved' where id=$1 returning id",[c.id])).rejects.toThrow('permission denied');await expect(resolve(c.id,'approved',outsider)).rejects.toThrow('Access denied');await expect(resolve(c.id,'approved',owner,second)).rejects.toThrow('unavailable');
  await resolve(c.id,'declined');await as(owner);expect((await state()).aiAllowed).toBe(false);await expect(resolve(c.id)).rejects.toThrow('resolved');
 });
 it('supports cancel, expiry, monthly recurrence and annual installments without a real subscription',async()=>{
  const monthly=await begin('askadia_monthly');expect([monthly.installment_cents,monthly.installments,monthly.total_cents]).toEqual([149700,1,149700]);await resolve(monthly.id,'cancelled');
  const expired=await begin();await db.exec('reset role');await db.query("update public.company_test_checkouts set expires_at=now()-interval '1 minute' where id=$1",[expired.id]);await expect(resolve(expired.id)).rejects.toThrow('expired');
  const approved=await begin();expect((await resolve(approved.id)).status).toBe('test_approved');expect((await resolve(approved.id)).status).toBe('test_approved');await as(owner);expect(await state()).toMatchObject({aiAllowed:true,accessMode:'test',planId:'askadia_annual',setupComplete:false});expect((await state(second)).aiAllowed).toBe(false);expect(await scalar("select count(*)::int from public.company_subscriptions where company_id=$1 and status='active'",[company])).toBe(0);
  await expect(scalar('select public.finish_company_setup($1)',[company])).rejects.toThrow('Approve all');
  // AI is now allowed; downstream approval/quota guards still apply.
  await expect(scalar('select public.reserve_site_generation($1,$2)',[company,randomUUID()])).rejects.toThrow('aprovações');
  await db.exec('reset role');await db.query("update private.company_test_access set valid_until=now()-interval '1 second' where company_id=$1",[company]);await as(owner);expect((await state()).aiAllowed).toBe(false);await expect(scalar('select public.inbox_prompt_context($1)',[company])).rejects.toThrow('Payment required');
 });
});
