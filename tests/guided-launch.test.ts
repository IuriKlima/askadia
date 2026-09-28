import {paidCompanyFixture} from './helpers/paid-company';
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
const finish=(j:Job,output:unknown)=>scalar('select public.finish_content_preparation_server($1,$2,$3)',[j.id,j.token,output]);
async function journey(){return scalar<{stages:{stage:number;basis:string;approved:boolean;data:unknown}[];competitorReview:{basis:string}}>('select public.read_marketing_journey($1)',[company]);}
async function approve(stage:number){const value=await journey();await scalar('select public.approve_marketing_stage($1,$2,$3,$4,$5)',[company,stage,value.stages[stage-1]!.basis,'Teste local: métricas não conectadas.',value.competitorReview.basis]);}
const strategy={positioning:'Academia local',objectives:[],ads:[],keywords:Array.from({length:20},(_,i)=>'termo '+i),unknowns:[],calendar:Array.from({length:8},(_,i)=>({week:Math.floor(i/2)+1,format:'imagem',theme:'Tema '+i,brief:'Direção '+i}))};
const details={title:'Treino',caption:'Conheça a estrutura',cta:'Fale conosco',designBrief:'Use a foto real',slides:[],videoScript:'',clientMaterials:[],unknowns:[],hashtags:[]};
const recommendations={summary:'Propostas',whatsapp:[],messages:[],traffic:[],unknowns:[]};
describe('Guided approvals, durable preparation and tenant boundaries',()=>{
 beforeAll(async()=>{db=new PGlite();await db.exec(`create role anon nologin;create role authenticated nologin;create role service_role nologin;create schema auth;create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant usage on schema auth to authenticated,anon;grant execute on function auth.uid() to authenticated,anon;create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);alter table storage.objects enable row level security;grant usage on schema storage to authenticated,anon;grant select,insert,update,delete on storage.objects to authenticated;`);for(const f of readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort())await db.exec(readFileSync('supabase/migrations/'+f,'utf8').replace('create extension if not exists pgcrypto;',''));
 for(const id of [owner,other]){await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[id,id+'@example.test']);await db.query('insert into public.profiles(id,display_name) values($1,$2)',[id,'Teste']);}
 await as(owner);company=(await scalar<{companyId:string}>('select public.begin_company_onboarding($1)',[randomUUID()])).companyId;
 await as(other);otherCompany=(await scalar<{companyId:string}>('select public.begin_company_onboarding($1)',[randomUUID()])).companyId;
 await as(owner);await db.exec('reset role');await db.query("insert into public.company_profile_versions(company_id,version,facts,confirmed_by) values($1,1,'{}',$2)",[company,owner]);await db.query('update public.company_onboarding set profile_version=1,confirmed_revision=revision where company_id=$1',[company]);
 await paidCompanyFixture(db,company);},120000);

 afterAll(async()=>{await db?.close();});
 it('queues work but requires reviewed competitors before diagnosis and all approvals before production',async()=>{
  await as(owner);expect(await scalar('select count(*)::int from public.company_marketing_journeys where company_id=$1',[company])).toBe(1);
  await expect(approve(5)).rejects.toThrow('previous');await expect(scalar('select public.claim_company_launch_server()')).rejects.toThrow();
  await server();expect(await claim()).toBeNull();expect(await scalar('select public.claim_company_launch_server()')).toBeNull();
  await as(other);expect(await scalar('select count(*)::int from public.company_launch_jobs where company_id=$1',[company])).toBe(0);await expect(scalar('select public.read_marketing_journey($1)',[company])).rejects.toThrow('Access denied');await expect(scalar('select public.enqueue_company_launch($1)',[otherCompany])).rejects.toThrow('Confirm');
  await as(owner);await approve(1);await server();const j=(await claim())!;expect(j.kind).toBe('strategy');expect(await finish({...j,token:randomUUID()},null)).toBe(false);expect(await finish(j,{output:strategy,model:'fixture',responseId:'fixture',usage:{}})).toBe(true);
  expect(await claim()).toBeNull();await as(owner);expect(await scalar('select count(*)::int from public.company_creatives where company_id=$1',[company])).toBe(0);expect(await scalar("select min(planned_date)>=(now() at time zone 'America/Sao_Paulo')::date+7 from public.company_calendar_items where company_id=$1",[company])).toBe(true);
 });
 it('approves each version in order and creates no site until stage five',async()=>{
  await as(owner);await approve(2);await server();let j=await scalar<Job|null>('select public.claim_company_launch_server()');if(!j)j=await scalar<Job|null>('select public.claim_company_launch_server()');expect(j?.kind).toBe('recommendations');expect(await scalar('select public.finish_company_launch_server($1,$2,$3)',[j!.id,j!.token,recommendations])).toBe(true);
  await as(owner);const oldBasis=(await journey()).stages[2]!.basis;await approve(3);await approve(4);await expect(scalar('select public.approve_marketing_stage($1,5,$2)',[company,oldBasis])).rejects.toThrow('changed');await approve(5);expect((await journey()).stages.every(s=>s.approved)).toBe(true);expect(await scalar('select public.finish_company_setup($1)',[company])).toMatchObject({setupComplete:true,aiAllowed:true});
  await server();const site=await scalar<Job>('select public.claim_company_launch_server()');expect(site.kind).toBe('site');await as(owner);const content={name:'Teste',headline:'Seu treino',intro:'',about:'',services:[],address:'',hours:'',offer:'',whatsapp:'',cta:'',color:'#123456',background:'light',images:[],logo:null};await scalar('select public.save_company_site($1,0,1,$2)',[company,content]);await server();expect(await scalar('select public.finish_company_launch_server($1,$2,$3)',[site.id,site.token,{...content,headline:'Substituição indevida'}])).toBe(false);await as(owner);expect(await scalar("select draft->>'headline' from public.company_sites where company_id=$1",[company])).toBe('Seu treino');expect(await scalar('select published from public.company_sites where company_id=$1',[company])).toBeNull();
 });
 it('produces only the next week, requires individual approval and rejects obsolete completions',async()=>{
  await server();const j=(await claim())!;expect(j.kind).toBe('details');await finish(j,{items:j.context.items.map(i=>({id:i.id,details})),model:'fixture'});const art=(await claim())!;expect(art.kind).toBe('design');
  await db.exec('reset role');await db.query("update public.company_calendar_items set planned_date=planned_date+1 where id=$1",[art.context.item.id]);await server();expect(await finish(art,{mime:'image/png',model:'fixture'})).toBe(false);
  await as(owner);const state=await journey();expect(state.stages[1]!.approved).toBe(true);expect(state.stages[2]!.approved).toBe(false);expect(state.stages[4]!.approved).toBe(false);expect(await scalar('select count(*)::int from public.company_calendar_items where company_id=$1 and approved_revision is not null',[company])).toBe(0);
 });
 it('protects Instagram selections, retains missing data and invalidates competitor review on selection changes',async()=>{
  await as(other);await expect(scalar('select public.save_instagram_watch($1,$2,$3,$4)',[company,'gym','Gym','local'])).rejects.toThrow('Access denied');await as(owner);await scalar('select public.save_instagram_watch($1,$2,$3,$4)',[company,'gym','Gym','local']);expect((await journey()).stages[0]!.approved).toBe(false);await expect(scalar('select public.claim_instagram_watch_server()')).rejects.toThrow();await server();expect(await scalar('select public.claim_instagram_watch_server()')).toBeNull();await as(owner);expect(await scalar('select snapshot from public.company_instagram_watches where company_id=$1',[company])).toBeNull();expect(await scalar('select status from public.company_instagram_watches where company_id=$1',[company])).toBe('unavailable');await as(other);expect(await scalar('select count(*)::int from public.company_instagram_watches where company_id=$1',[company])).toBe(0);
 });
 it('requires the displayed evidence and keeps repeated approvals idempotent',async()=>{
  await as(owner);const before=await journey();
  await db.exec('reset role');await db.query("update public.company_instagram_watches set snapshot=$2 where company_id=$1",[company,{username:'gym',name:'Gym',followers:50,mediaCount:3,collectedAt:new Date().toISOString(),posts:[]}]);await as(owner);
  await expect(scalar('select public.approve_marketing_stage($1,1,$2,$3,$4)',[company,before.stages[0]!.basis,'Revisão fictícia',before.competitorReview.basis])).rejects.toThrow('coleta mudou');
  await approve(1);const token=await scalar('select token from public.company_marketing_approvals where company_id=$1 and stage=1',[company]);await approve(1);expect(await scalar('select token from public.company_marketing_approvals where company_id=$1 and stage=1',[company])).toBe(token);
 });

});
