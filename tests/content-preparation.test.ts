import {afterAll,beforeAll,describe,expect,it} from 'vitest';
import {PGlite} from '@electric-sql/pglite';
import {readFileSync,readdirSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
let db:PGlite,company:string,otherCompany:string;const owner=randomUUID(),other=randomUUID();
async function as(id:string){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec('set role authenticated');}
async function server(){await db.exec('reset role;set role service_role');}
async function scalar<T=unknown>(sql:string,args:unknown[]=[]):Promise<T>{return Object.values((await db.query<Record<string,T>>(sql,args)).rows[0]!)[0]!;}
type Job={id:string;token:string;runId:string;companyId:string;kind:string;frame:number;context:{items:{id:string}[];item:{id:string}}};
const claim=()=>scalar<Job|null>('select public.claim_content_preparation_server()');
const finish=(j:Job,result:unknown)=>scalar('select public.finish_content_preparation_server($1,$2,$3)',[j.id,j.token,result]);
const details={title:'Treino',caption:'Conheça a estrutura',cta:'Fale conosco',designBrief:'Use a foto real e a identidade confirmada',slides:[],videoScript:'',clientMaterials:[],unknowns:[],hashtags:[]};
const strategy={positioning:'Academia local',objectives:[],ads:[],keywords:Array.from({length:20},(_,i)=>'termo '+i),unknowns:[],calendar:Array.from({length:8},(_,i)=>({week:Math.floor(i/2)+1,format:'imagem',theme:'Tema '+i,brief:'Direção '+i}))};
describe('Durable content preparation without automatic approval',()=>{
 beforeAll(async()=>{db=new PGlite();await db.exec(`create role anon nologin;create role authenticated nologin;create role service_role nologin;create schema auth;create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant usage on schema auth to authenticated,anon;grant execute on function auth.uid() to authenticated,anon;create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);alter table storage.objects enable row level security;grant usage on schema storage to authenticated,anon;grant select,insert,update,delete on storage.objects to authenticated;`);for(const f of readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort())await db.exec(readFileSync('supabase/migrations/'+f,'utf8').replace('create extension if not exists pgcrypto;',''));
 for(const id of [owner,other]){await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[id,id+'@example.test']);await db.query('insert into public.profiles(id,display_name) values($1,$2)',[id,'Teste']);}
 await as(owner);company=(await scalar<{companyId:string}>('select public.begin_company_onboarding($1)',[randomUUID()])).companyId;
 await as(other);otherCompany=(await scalar<{companyId:string}>('select public.begin_company_onboarding($1)',[randomUUID()])).companyId;
 await as(owner);await db.exec('reset role');await db.query("insert into public.company_profile_versions(company_id,version,facts,confirmed_by) values($1,1,'{}',$2)",[company,owner]);await db.query('update public.company_onboarding set profile_version=1,confirmed_revision=revision where company_id=$1',[company]);
 },120000);
 afterAll(async()=>{await db?.close();});
 it('queues confirmation once and denies foreign tenants and client worker calls',async()=>{
  await as(owner);expect(await scalar('select count(*)::int from public.company_content_preparations where company_id=$1',[company])).toBe(1);
  await scalar('select public.enqueue_content_preparation($1)',[company]);expect(await scalar('select count(*)::int from public.company_content_preparations where company_id=$1',[company])).toBe(1);
  await expect(claim()).rejects.toThrow();await as(other);expect(await scalar('select count(*)::int from public.company_content_preparations where company_id=$1',[company])).toBe(0);await expect(scalar('select public.enqueue_content_preparation($1)',[company])).rejects.toThrow('Access denied');await expect(scalar('select public.enqueue_content_preparation($1)',[otherCompany])).rejects.toThrow('Confirm');
 });
 it('prepares strategy and content as drafts starting today, with two dates per week',async()=>{
  await server();const j=(await claim())!;expect(j.kind).toBe('strategy');expect(j.companyId).toBe(company);expect(await claim()).toBeNull();expect(await finish({...j,token:randomUUID()},null)).toBe(false);
  expect(await finish(j,{output:strategy,model:'fixture',responseId:'fixture',usage:{}})).toBe(true);
  const content=(await claim())!;expect(content.kind).toBe('details');expect(content.context.items).toHaveLength(8);
  await db.exec('reset role');expect(await scalar("select min(planned_date)>=(now() at time zone 'America/Sao_Paulo')::date from public.company_calendar_items where company_id=$1",[company])).toBe(true);
  expect(await scalar("select max(n)::int from (select count(*) n from public.company_calendar_items where company_id=$1 group by date_trunc('week',planned_date::timestamp)) x",[company])).toBeLessThanOrEqual(2);
  expect(await scalar('select status from public.company_strategy_briefs where company_id=$1',[company])).toBe('review');
  await server();expect(await finish(content,{items:content.context.items.map(i=>({id:i.id,details})),model:'fixture'})).toBe(true);
  await as(owner);expect(await scalar("select count(*)::int from public.company_calendar_items where company_id=$1 and status='draft' and approved_revision is null",[company])).toBe(8);
  await expect(scalar('select public.approve_calendar_item($1,$2,2)',[company,content.context.items[0]!.id])).rejects.toThrow();
 });
 it('recovers an expired lease, rejects the old worker and saves only the current creative',async()=>{
  await server();const old=(await claim())!;expect(old.kind).toBe('design');await db.exec('reset role');await db.query("update public.company_content_preparations set lease_until=now()-interval '1 minute' where id=$1",[old.id]);await server();const current=(await claim())!;expect(current.token).not.toBe(old.token);expect(current.runId).not.toBe(old.runId);expect(await finish(old,null)).toBe(false);
  await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name) values('company-assets',$1)",[company+'/generated/'+current.runId+'.png']);await server();expect(await finish(current,{mime:'image/png',model:'fixture'})).toBe(true);await db.exec('reset role');expect(await scalar('select count(*)::int from public.company_creatives where company_id=$1',[company])).toBe(1);
 });
 it('finishes all missing frames once and never approves or publishes',async()=>{
  await server();for(let n=0;n<7;n++){const j=(await claim())!;expect(j.kind).toBe('design');await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name) values('company-assets',$1)",[company+'/generated/'+j.runId+'.png']);await server();await finish(j,{mime:'image/png',model:'fixture'});}
  expect(await claim()).toBeNull();expect(await claim()).toBeNull();await as(owner);expect(await scalar('select status from public.company_content_preparations where company_id=$1',[company])).toBe('completed');expect(await scalar("select count(*)::int from public.company_calendar_items where company_id=$1 and approved_revision is not null",[company])).toBe(0);
 });
 it('rejects completion after profile changes and preserves existing material',async()=>{
  await as(owner);const brief=await scalar<{id:string;generation:number}>('select to_jsonb(b) from public.company_strategy_briefs b where company_id=$1',[company]);await scalar('select public.edit_company_strategy($1,$2,$3,$4)',[company,brief.id,brief.generation,strategy]);await scalar('select public.enqueue_content_preparation($1)',[company]);await server();const j=(await claim())!;expect(j.kind).toBe('details');await db.exec('reset role');await db.query('update public.company_onboarding set confirmed_revision=null where company_id=$1',[company]);await server();expect(await finish(j,{mime:'image/png',model:'fixture'})).toBe(false);await db.exec('reset role');expect(await scalar('select status from public.company_content_preparations where company_id=$1',[company])).toBe('stale');expect(await scalar('select count(*)::int from public.company_creatives where company_id=$1',[company])).toBe(8);
 });
});
