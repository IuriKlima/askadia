import { afterAll,beforeAll,beforeEach,describe,expect,it } from 'vitest';
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
const ids={owner:'10000000-0000-4000-8000-000000000001',other:'10000000-0000-4000-8000-000000000002',agent:'10000000-0000-4000-8000-000000000003',invitee:'10000000-0000-4000-8000-000000000004',unverified:'10000000-0000-4000-8000-000000000005'};
let db:PGlite;let workspace:string;let a:string;let b:string;let c:string;
async function as(user:string){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);await db.exec('set role authenticated');}
async function root(){await db.exec('reset role');}
async function scalar<T>(sql:string,params:unknown[]=[]):Promise<T>{const result=await db.query<Record<string,T>>(sql,params);return Object.values(result.rows[0]!)[0]!;}
async function invite(email='invited@example.test',role='reader'){return scalar<{id:string;token:string;expires_at:string}>('select public.create_company_invitation($1,$2,$3)',[a,email,role]);}
describe('PostgreSQL RLS and identity transactions (PGlite, isolated auth/storage fixtures)',()=>{
  beforeAll(async()=>{
    db=new PGlite();
    await db.exec(`
      create role anon nologin;create role authenticated nologin;
      create schema auth;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated,anon;
      grant execute on function auth.uid() to authenticated,anon;
      create schema storage;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
      alter table storage.objects enable row level security;
      grant usage on schema storage to authenticated,anon;
      grant select,insert,update,delete on storage.objects to authenticated;
    `);
    // pgcrypto extension is not used by this schema; gen_random_uuid and sha256 are PostgreSQL core.
    const base=readFileSync('supabase/migrations/202609200001_foundation.sql','utf8').replace('create extension if not exists pgcrypto;','');
    await db.exec(base);
    await db.exec(readFileSync('supabase/migrations/202609210001_identity.sql','utf8'));
    await db.exec(readFileSync('supabase/migrations/202609210002_storage.sql','utf8'));
    await db.exec(readFileSync('supabase/migrations/202609210003_product_foundation.sql','utf8'));
    for(const [key,id] of Object.entries(ids)){
      await db.query("insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values($1,$2,$3,$4)",[id,key==='invitee'?'invited@example.test':key+'@example.test',key==='unverified'?null:new Date().toISOString(),JSON.stringify({name:key})]);
      await db.query('insert into public.profiles(id,display_name) values($1,$2)',[id,key]);
    }
    await as(ids.owner);
    workspace=await scalar<string>("select public.create_workspace('Workspace A')");
    a=(await scalar<{id:string}>("select row_to_json(public.create_company($1,'Empresa A','gym','São Paulo','America/Sao_Paulo'))",[workspace])).id;
    b=(await scalar<{id:string}>("select row_to_json(public.create_company($1,'Empresa B','studio','São Paulo','America/Sao_Paulo'))",[workspace])).id;
    await as(ids.other);
    const w2=await scalar<string>("select public.create_workspace('Workspace B')");
    c=(await scalar<{id:string}>("select row_to_json(public.create_company($1,'Empresa C','gym','','America/Sao_Paulo'))",[w2])).id;
    await root();
    await db.query("insert into public.workspace_members values($1,$2,'member'),($1,$3,'member')",[workspace,ids.agent,ids.other]);
    await db.query("insert into public.company_members values($1,$2,'attendant'),($3,$4,'admin')",[a,ids.agent,b,ids.other]);
    // No direct membership in B; the consolidated owner rule grants access through the workspace.
    await db.query('delete from public.company_members where company_id=$1 and user_id=$2',[b,ids.owner]);
    for(const company of [a,b,c]){
      await db.query("insert into public.contacts(company_id,name,phone_e164) values($1,'Teste','+5511999991111')",[company]);
      await db.query("insert into storage.objects(bucket_id,name) values('company-assets',$1)",[company+'/logo.png']);
    }
  },60000);
  beforeEach(async()=>{await as(ids.owner);});
  afterAll(async()=>{await db?.close();});
  it('creates company as draft without a subscription',async()=>{
    const rows=await db.query<{status:string}>('select status from public.companies where id=$1',[a]);
    expect(rows.rows[0]?.status).toBe('draft');
  });
  it('does not expose another workspace',async()=>{
    expect((await db.query('select * from public.companies where id=$1',[c])).rows).toHaveLength(0);
    await expect(db.query("select public.update_company($1,'Hacked','gym','','UTC',false)",[c])).rejects.toThrow('Access denied');
  });
  it('workspace owner accesses owned company B while unrelated company C stays isolated',async()=>{
    expect((await db.query('select * from public.companies where id=$1',[b])).rows).toHaveLength(1);
    expect((await db.query('select * from public.contacts where company_id=$1',[b])).rows).toHaveLength(1);
    expect((await db.query('select * from storage.objects where name=$1',[b+'/logo.png'])).rows).toHaveLength(1);
    await db.query('select public.record_company_export($1)',[b]);
    await expect(db.query('select public.record_company_export($1)',[c])).rejects.toThrow('Access denied');
  });
  it('attendant sees only company A even in the same workspace',async()=>{
    await as(ids.agent);
    const companies=await db.query<{id:string}>('select id from public.companies');
    expect(companies.rows.map(r=>r.id)).toEqual([a]);
    expect((await db.query('select * from public.contacts')).rows).toHaveLength(1);
    expect((await db.query('select * from public.contacts where company_id=$1',[b])).rows).toHaveLength(0);
    await expect(db.query('select public.create_company_invitation($1,$2,$3)',[a,'x@example.test','admin'])).rejects.toThrow('Access denied');
    await expect(db.query('select public.record_company_export($1)',[a])).rejects.toThrow('Access denied');
  });
  it('blocks direct role escalation and unauthorized company creation',async()=>{
    await as(ids.agent);
    await expect(db.query("update public.company_members set role='admin' where user_id=$1",[ids.agent])).rejects.toThrow();
    await expect(db.query("select public.create_company($1,'Unauthorized','gym','','UTC')",[workspace])).rejects.toThrow('Access denied');
  });
  it('protects company file paths on reads, inserts and cross-company moves',async()=>{
    expect((await db.query('select * from storage.objects')).rows).toHaveLength(2);
    await expect(db.query("insert into storage.objects(bucket_id,name) values('company-assets',$1)",[c+'/injected.png'])).rejects.toThrow();
    await expect(db.query('update storage.objects set name=$1 where name=$2',[c+'/moved.png',a+'/logo.png'])).rejects.toThrow();
    await db.query("insert into storage.objects(bucket_id,name) values('company-assets',$1)",[a+'/allowed.png']);
  });
  it('hides invitation token hashes and never writes a token to audit',async()=>{
    const inv=await invite();
    await expect(db.query('select token_hash from public.company_invitations')).rejects.toThrow();
    const audit=await db.query('select details from public.audit_logs');
    expect(JSON.stringify(audit.rows)).not.toContain(inv.token);
  });
  it('binds invitations to verified email and makes acceptance single-use',async()=>{
    const inv=await invite();
    await as(ids.agent);
    await expect(db.query('select public.accept_company_invitation($1)',[inv.token])).rejects.toThrow('Invitation unavailable');
    await as(ids.invitee);
    expect(await scalar('select public.accept_company_invitation($1)',[inv.token])).toBe(a);
    expect(await scalar('select role from public.company_members where user_id=$1 and company_id=$2',[ids.invitee,a])).toBe('reader');
    await expect(db.query('select public.accept_company_invitation($1)',[inv.token])).rejects.toThrow('Invitation unavailable');
    // Removal is checked from membership, with the same already-issued user identity.
    await as(ids.owner);await db.query('select public.change_company_member($1,$2,null)',[a,ids.invitee]);
    await as(ids.invitee);expect((await db.query('select * from public.companies')).rows).toHaveLength(0);
  });
  it('rejects expired, revoked and superseded invitations',async()=>{
    const expired=await invite();await root();
    await db.query("update public.company_invitations set expires_at=now()-interval '1 minute' where id=$1",[expired.id]);
    await as(ids.invitee);await expect(db.query('select public.accept_company_invitation($1)',[expired.token])).rejects.toThrow('Invitation unavailable');
    await as(ids.owner);const revoked=await invite();await db.query('select public.revoke_company_invitation($1,$2)',[a,revoked.id]);
    await as(ids.invitee);await expect(db.query('select public.accept_company_invitation($1)',[revoked.token])).rejects.toThrow('Invitation unavailable');
    await as(ids.owner);const first=await invite();await invite();
    await as(ids.invitee);await expect(db.query('select public.accept_company_invitation($1)',[first.token])).rejects.toThrow('Invitation unavailable');
  });
  it('rejects unconfirmed email',async()=>{
    const inv=await invite('unverified@example.test');
    await as(ids.unverified);await expect(db.query('select public.accept_company_invitation($1)',[inv.token])).rejects.toThrow('Verified email required');
  });
  it('keeps the last administrator and rejects anonymous RPCs',async()=>{
    await expect(db.query('select public.change_company_member($1,$2,null)',[a,ids.owner])).rejects.toThrow('Keep at least one administrator');
    await root();await db.exec('set role anon');
    await expect(db.query("select public.create_workspace('Unauthorized')")).rejects.toThrow();
  });
  it('archives without deleting and blocks operational access until restored',async()=>{
    await db.query("select public.update_company($1,'Empresa A','gym','São Paulo','America/Sao_Paulo',true)",[a]);
    expect((await db.query('select * from public.contacts where company_id=$1',[a])).rows).toHaveLength(0);
    expect((await db.query('select * from storage.objects where name=$1',[a+'/logo.png'])).rows).toHaveLength(0);
    await db.query("select public.update_company($1,'Empresa A','gym','São Paulo','America/Sao_Paulo',false)",[a]);
    expect((await db.query('select * from public.contacts where company_id=$1',[a])).rows).toHaveLength(1);
  });
  it('rejects cross-company foreign keys even with privileged writes',async()=>{
    await root();
    const contactId=await scalar<string>('select id from public.contacts where company_id=$1',[a]);
    await expect(db.query("insert into public.opportunities(company_id,contact_id,original_source) values($1,$2,'manual')",[b,contactId])).rejects.toThrow();
  });
  it('revokes operational access of a removed member without depending on a new JWT',async()=>{
    await as(ids.agent);expect((await db.query('select * from public.contacts')).rows).toHaveLength(1);
    await as(ids.owner);await db.query('select public.change_company_member($1,$2,null)',[a,ids.agent]);
    await as(ids.agent);expect((await db.query('select * from public.contacts')).rows).toHaveLength(0);
    expect((await db.query('select * from public.companies')).rows).toHaveLength(0);
  });
});
