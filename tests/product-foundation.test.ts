import { afterAll,beforeAll,describe,expect,it } from 'vitest';
import { Test } from '@nestjs/testing';
import { AppModule } from '../apps/api/src/app';
import { AuthService } from '../apps/api/src/identity/auth';
import { PGlite } from '@electric-sql/pglite';
import { readdirSync,readFileSync } from 'node:fs';
import { delegationSchema } from '../packages/contracts/src/foundation';
const users={owner:'30000000-0000-4000-8000-000000000001',other:'30000000-0000-4000-8000-000000000002',marketing:'30000000-0000-4000-8000-000000000003',attendant:'30000000-0000-4000-8000-000000000004',admin:'30000000-0000-4000-8000-000000000005',support:'30000000-0000-4000-8000-000000000006'};
let db:PGlite,a:string,b:string,c:string;
async function as(user:string){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);await db.exec('set role authenticated');}
async function scalar<T>(sql:string,params:unknown[]=[]):Promise<T>{return Object.values((await db.query<Record<string,T>>(sql,params)).rows[0]!)[0]!;}
describe('Consolidated product foundation: all migrations, real PostgreSQL with local Auth/Storage fixtures',()=>{
  beforeAll(async()=>{
    db=new PGlite();
    await db.exec(`
      create role anon nologin;create role authenticated nologin;
      create schema auth;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated,anon;grant execute on function auth.uid() to authenticated,anon;
      create schema storage;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
      alter table storage.objects enable row level security;
      grant usage on schema storage to authenticated,anon;grant select,insert,update,delete on storage.objects to authenticated;
    `);
    for(const file of readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort()){
      await db.exec(readFileSync('supabase/migrations/'+file,'utf8').replace('create extension if not exists pgcrypto;',''));
    }
    for(const [name,id] of Object.entries(users)){
      await db.query("insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())",[id,name+'@example.test']);
      await db.query('insert into public.profiles(id,display_name) values($1,$2)',[id,name]);
    }
    await as(users.owner);
    const w=await scalar<string>("select public.create_workspace('Grupo proprietário')");
    a=(await scalar<{id:string}>("select row_to_json(public.create_company($1,'Empresa A','gym','','America/Sao_Paulo'))",[w])).id;
    b=(await scalar<{id:string}>("select row_to_json(public.create_company($1,'Empresa B','studio','','America/Sao_Paulo'))",[w])).id;
    await as(users.other);
    const otherW=await scalar<string>("select public.create_workspace('Outro grupo')");
    c=(await scalar<{id:string}>("select row_to_json(public.create_company($1,'Empresa C','gym','','America/Sao_Paulo'))",[otherW])).id;
    await db.exec('reset role');
    await db.query("insert into public.company_members(company_id,user_id,role) values($1,$2,'marketing'),($1,$3,'attendant')",[a,users.marketing,users.attendant]);
    await db.query("insert into public.platform_staff(user_id,role) values($1,'platform_admin'),($2,'support')",[users.admin,users.support]);
    await db.query("insert into public.contacts(company_id,name) values($1,'A'),($2,'B'),($3,'C')",[a,b,c]);
  },60000);
  afterAll(async()=>{await db?.close();});
  it('owner accesses owned companies, while unrelated companies stay isolated',async()=>{
    await as(users.owner);
    expect((await db.query('select * from public.contacts')).rows).toHaveLength(2);
    expect((await db.query('select * from public.contacts where company_id=$1',[c])).rows).toHaveLength(0);
    const cap=await scalar<{actions:string[]}>('select public.company_capabilities($1)',[b]);
    expect(cap.actions).toContain('billing.manage');
  });
  it('marketing cannot manage billing, access CRM by default, or promote itself to platform admin',async()=>{
    await as(users.marketing);
    const cap=await scalar<{actions:string[]}>('select public.company_capabilities($1)',[a]);
    expect(cap.actions).toContain('marketing.write');expect(cap.actions).not.toContain('billing.manage');expect(cap.actions).not.toContain('crm.read');expect(cap.actions).not.toContain('content.approve');
    expect((await db.query('select * from public.contacts')).rows).toHaveLength(0);
    await expect(db.query("insert into public.platform_staff(user_id,role) values($1,'platform_admin')",[users.marketing])).rejects.toThrow();
    await expect(db.query("select public.internal_portfolio('',0)")).rejects.toThrow('Staff access required');
    await expect(db.query('select public.start_internal_access($1,$2)',[a,'Tentativa indevida'])).rejects.toThrow('Access denied');
  });
  it('attendant gets CRM only in its assigned company',async()=>{
    await as(users.attendant);
    const cap=await scalar<{actions:string[]}>('select public.company_capabilities($1)',[a]);
    expect(cap.actions).toContain('crm.write');expect(cap.actions).not.toContain('marketing.write');expect(cap.actions).not.toContain('billing.manage');
    expect((await db.query('select * from public.contacts')).rows).toHaveLength(1);
    await expect(db.query('select public.company_capabilities($1)',[b])).rejects.toThrow('Access denied');
  });
  it('explicit delegation is revocable and budget approval requires a bound',async()=>{
    await as(users.owner);
    await db.query("select public.set_company_permission($1,$2,'crm.read',true)",[a,users.marketing]);
    await as(users.marketing);expect((await db.query('select * from public.contacts')).rows).toHaveLength(1);
    await expect(db.query("select public.set_company_permission($1,$2,'crm.write',true)",[a,users.marketing])).rejects.toThrow('Only owner');
    await as(users.owner);await db.query("select public.set_company_permission($1,$2,'crm.read',false)",[a,users.marketing]);
    await expect(db.query("select public.set_company_permission($1,$2,'ads.approve',true)",[a,users.marketing])).rejects.toThrow('Budget limit required');
    await as(users.marketing);expect((await db.query('select * from public.contacts')).rows).toHaveLength(0);
  });
  it('draft subscriptions cannot grant resources, premium price is unknown and checkout is disabled',async()=>{
    await as(users.owner);
    const cap=await scalar<{features:string[];billingEnabled:boolean;subscription:{status:string}}>('select public.company_capabilities($1)',[a]);
    expect(cap.features).toEqual([]);expect(cap.billingEnabled).toBe(false);expect(cap.subscription.status).toBe('draft');
    expect(await scalar("select price_cents from public.plan_catalog where id='premium'")).toBeNull();
    expect(await scalar("select bool_or(checkout_enabled) from public.plan_catalog")).toBe(false);
    await expect(db.query("select public.authorize_company_feature($1,'crm','crm.write')",[a])).rejects.toThrow('Feature blocked');
    await expect(db.query("insert into public.company_subscriptions(company_id,plan_id,status) values($1,'basic','active')",[a])).rejects.toThrow();
  });
  it('subscription status and limits stay separate per company and expiry blocks entitlement',async()=>{
    await db.exec('reset role');
    await db.query("insert into public.company_subscriptions(company_id,plan_id,status,current_period_end) values($1,'basic','active',now()+interval '1 day')",[a]);
    await as(users.owner);
    await db.query("select public.authorize_company_feature($1,'crm','crm.write')",[a]);
    await expect(db.query("select public.authorize_company_feature($1,'crm','crm.write')",[b])).rejects.toThrow('Feature blocked');
    const cap=await scalar<{quotas:Record<string,number|null>}>('select public.company_capabilities($1)',[a]);
    expect(cap.quotas.images).toBeNull();
    await db.exec('reset role');await db.query("update public.company_subscriptions set current_period_end=now()-interval '1 second' where company_id=$1",[a]);
    await as(users.owner);await expect(db.query("select public.authorize_company_feature($1,'crm','crm.write')",[a])).rejects.toThrow('Feature blocked');
  });
  it('support sees only assigned portfolio and cannot assign itself elsewhere',async()=>{
    await as(users.support);
    expect((await scalar<{companies:unknown[]}>("select public.internal_portfolio('',0)")).companies).toHaveLength(0);
    await expect(db.query('select public.set_company_assignment($1,$2,true)',[a,users.support])).rejects.toThrow('Platform admin required');
    await as(users.admin);await db.query('select public.set_company_assignment($1,$2,true)',[a,users.support]);
    await as(users.support);
    const result=await scalar<{companies:{id:string}[]}>("select public.internal_portfolio('',0)");
    expect(result.companies.map(c=>c.id)).toEqual([a]);
    await expect(db.query('select public.start_internal_access($1,$2)',[b,'Revisão fora da carteira'])).rejects.toThrow('Access denied');
    expect((await db.query('select * from public.contacts')).rows).toHaveLength(0);
  });
  it('internal sessions preserve operator, reject session theft and are read-only',async()=>{
    await as(users.support);
    const session=await scalar<string>('select public.start_internal_access($1,$2)',[a,'Revisão de configuração']);
    const context=await scalar<{session:{operator_id:string};scope:string;company:{id:string}}>('select public.internal_company_context($1)',[session]);
    expect(context.session.operator_id).toBe(users.support);expect(context.company.id).toBe(a);expect(context.scope).toBe('read_only');
    await as(users.admin);await expect(db.query('select public.internal_company_context($1)',[session])).rejects.toThrow('Internal session unavailable');
    const audit=await db.query<{actor_id:string}>("select actor_id from public.platform_audit where session_id=$1",[session]);
    expect(audit.rows[0]?.actor_id).toBe(users.support);
    await as(users.support);await db.query('select public.end_internal_access($1)',[session]);
    await expect(db.query('select public.internal_company_context($1)',[session])).rejects.toThrow('Internal session unavailable');
  });
  it('assignment removal revokes already-issued internal sessions',async()=>{
    await as(users.support);const session=await scalar<string>('select public.start_internal_access($1,$2)',[a,'Acompanhar cliente atribuído']);
    await as(users.admin);await db.query('select public.set_company_assignment($1,$2,false)',[a,users.support]);
    await as(users.support);await expect(db.query('select public.internal_company_context($1)',[session])).rejects.toThrow('Internal session unavailable');
  });
  it('expiration and staff deactivation deny existing internal sessions',async()=>{
    await as(users.admin);const session=await scalar<string>('select public.start_internal_access($1,$2)',[b,'Revisar empresa do cliente']);
    await db.exec('reset role');await db.query("update public.internal_access_sessions set expires_at=now()-interval '1 second' where id=$1",[session]);
    await as(users.admin);await expect(db.query('select public.internal_company_context($1)',[session])).rejects.toThrow('Internal session unavailable');
    const activeSession=await scalar<string>('select public.start_internal_access($1,$2)',[b,'Nova revisão do cliente']);
    await db.exec('reset role');await db.query('update public.platform_staff set active=false where user_id=$1',[users.admin]);
    await as(users.admin);await expect(db.query('select public.internal_company_context($1)',[activeSession])).rejects.toThrow('Internal session unavailable');
  });
  it('does not allow tenant invitations to grant platform administration',async()=>{
    await as(users.owner);
    await expect(db.query("select public.create_company_invitation($1,'person@example.test','platform_admin')",[a])).rejects.toThrow('Invalid invitation');
    const invitation=await scalar<{token:string}>("select public.create_company_invitation($1,'new@example.test','marketing')",[a]);
    expect(invitation.token).toHaveLength(64);
    await db.exec('reset role');await db.exec('set role anon');
    await expect(db.query("select public.internal_portfolio('',0)")).rejects.toThrow();
  });

  it('enforces portfolio, assignment and company scope through direct Nest HTTP calls',async()=>{
    const module=await Test.createTestingModule({imports:[AppModule]}).overrideProvider(AuthService).useValue({
      async verify(header?:string){
        const user=header==='Bearer owner-test'?users.owner:header==='Bearer support-test'?users.support:null;
        if(!user)return new AuthService({}).verify(undefined);
        return {id:user,email:'test@example.test',client:{async rpc(name:string,args:Record<string,unknown>={}){
          if(!/^[a-z_]+$/.test(name)||!Object.keys(args).every(k=>/^p_[a-z_]+$/.test(k)))throw new Error('Invalid RPC');
          await as(user);
          try{return {data:await scalar('select public.'+name+'('+Object.keys(args).map((k,i)=>k+' => '+String.fromCharCode(36)+(i+1)).join(',')+')',Object.values(args)),error:null};}
          catch(e){return {data:null,error:{code:(e as {code:string}).code,message:'Database rejected request'}};}
        }}};
      }
    }).compile();
    const app=module.createNestApplication();await app.listen(0,'127.0.0.1');const url=await app.getUrl();
    try{
      expect((await fetch(url+'/operations/portfolio')).status).toBe(401);
      expect((await fetch(url+'/operations/portfolio',{headers:{Authorization:'Bearer owner-test'}})).status).toBe(403);
      expect((await fetch(url+'/operations/companies/'+c+'/capabilities',{headers:{Authorization:'Bearer owner-test'}})).status).toBe(403);
      expect((await fetch(url+'/operations/companies/'+a+'/assignments',{method:'POST',headers:{Authorization:'Bearer support-test','Content-Type':'application/json'},body:JSON.stringify({staffId:users.support,assigned:true})})).status).toBe(403);
      expect((await fetch(url+'/operations/access',{method:'POST',headers:{Authorization:'Bearer support-test','Content-Type':'application/json'},body:JSON.stringify({companyId:b,reason:'Fora da carteira'})})).status).toBe(403);
      expect((await fetch(url+'/operations/access',{method:'POST',headers:{Authorization:'Bearer owner-test','Content-Type':'application/json'},body:JSON.stringify({companyId:a,reason:'Verificar acesso',role:'platform_admin'})})).status).toBe(400);
    }finally{await app.close();}
  },30000);

  it('imports drafts transactionally, resets local approvals/enrollments, and deduplicates repeats',async()=>{
    await as(users.owner);
    const source='40000000-0000-4000-8000-000000000001';
    const contact='40000000-0000-4000-8000-000000000002';
    const payload={sourceCompanyId:source,contacts:[{id:contact,companyId:source,name:'Lead importado',phone:'+5511999991234',email:'lead@example.test'}],
      opportunities:[{id:'40000000-0000-4000-8000-000000000003',companyId:source,contactId:contact,interest:'Plano mensal',stage:'Matriculado'}],
      contents:[{id:'40000000-0000-4000-8000-000000000004',companyId:source,title:'Campanha local',caption:'Texto aprovado apenas na prévia.',format:'Imagem',date:'2026-10-01',version:8,status:'approved',approvedVersion:8}]};
    expect(await scalar('select public.import_local_drafts($1,$2)',[a,JSON.stringify(payload)])).toEqual({contacts:1,opportunities:1,contents:1,skipped:0});
    expect(await scalar('select public.import_local_drafts($1,$2)',[a,JSON.stringify(payload)])).toEqual({contacts:0,opportunities:0,contents:0,skipped:3});
    const draft=(await db.query<{status:string;version:number}>('select status,version from public.editorial_drafts where company_id=$1',[a])).rows[0];
    expect(draft).toEqual({status:'draft',version:1});
    expect(await scalar("select stage from public.opportunities where company_id=$1 and original_source='local_import'",[a])).toBe('new');
    expect(await scalar('select public.import_local_drafts($1,$2)',[b,JSON.stringify(payload)])).toEqual({contacts:1,opportunities:1,contents:1,skipped:0});
    const rows=await db.query<{id:string}>("select id from public.contacts where phone_e164='+5511999991234'");
    expect(new Set(rows.rows.map(r=>r.id)).size).toBe(2);
  });
  it('rolls back a whole import on invalid content and cannot reuse another company contact mapping',async()=>{
    await as(users.owner);
    const source='40000000-0000-4000-8000-000000000001';
    const payload={sourceCompanyId:source,contacts:[{id:'40000000-0000-4000-8000-000000000099',companyId:source,name:'Should rollback',phone:'+5511999999999'}],opportunities:[],contents:[{id:'40000000-0000-4000-8000-000000000098',companyId:source,title:'Invalid content date',caption:'',format:'Imagem',date:'not-a-date'}]};
    await expect(db.query('select public.import_local_drafts($1,$2)',[a,JSON.stringify(payload)])).rejects.toThrow();
    expect(await scalar("select count(*)::int from public.contacts where phone_e164='+5511999999999'")).toBe(0);
    const invalid={sourceCompanyId:source,contacts:[],contents:[],opportunities:[{id:crypto.randomUUID(),companyId:source,contactId:'40000000-0000-4000-8000-000000000099',interest:''}]};
    await expect(db.query('select public.import_local_drafts($1,$2)',[a,JSON.stringify(invalid)])).rejects.toThrow('Contact not imported');
  });
  it('checks import permissions at the database boundary and rejects mixed tenant payloads',async()=>{
    const source='40000000-0000-4000-8000-000000000001';
    const payload={sourceCompanyId:source,contacts:[],opportunities:[],contents:[{id:crypto.randomUUID(),companyId:source,title:'Unauthorized content',caption:'',format:'Imagem',date:''}]};
    await as(users.attendant);
    await expect(db.query('select public.import_local_drafts($1,$2)',[a,JSON.stringify(payload)])).rejects.toThrow('Marketing permission required');
    await as(users.owner);
    await expect(db.query('select public.import_local_drafts($1,$2)',[c,JSON.stringify(payload)])).rejects.toThrow('Access denied');
    payload.contents[0]!.companyId=crypto.randomUUID();
    await expect(db.query('select public.import_local_drafts($1,$2)',[a,JSON.stringify(payload)])).rejects.toThrow('Invalid source content');
  });
  it('strict delegation contracts reject unbounded budgets and role injection',()=>{
    expect(delegationSchema.safeParse({userId:users.marketing,action:'ads.approve',enabled:true}).success).toBe(false);
    expect(delegationSchema.safeParse({userId:users.marketing,action:'crm.read',enabled:true,role:'platform_admin'}).success).toBe(false);
  });
});
