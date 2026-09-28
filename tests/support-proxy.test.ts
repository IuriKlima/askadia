import {afterEach,describe,expect,it,vi} from 'vitest';
const auth=vi.hoisted(()=>({user:true}));
vi.mock('../apps/web/lib/auth/server',()=>({serverSupabase:async()=>({auth:{getUser:async()=>({data:{user:auth.user?{id:'fixture',email_confirmed_at:'confirmed'}:null},error:null}),getSession:async()=>({data:{session:{access_token:'fixture-session'}}})}})}));
vi.mock('../apps/web/lib/auth/config',()=>({appOrigin:()=> 'https://example.test',authConfigured:()=>true}));
import {GET,POST} from '../apps/web/app/api/operations/[...path]/route';
const id='10000000-0000-4000-8000-000000000001';
const request=(method:string,path:string,origin='https://example.test')=>new Request('https://example.test/api/operations/'+path,{method,headers:{Origin:origin,'Content-Type':'application/json'},...(method==='POST'?{body:'{}'}:{})});
const context=(path:string)=>({params:Promise.resolve({path:path.split('/')})});
afterEach(()=>{vi.unstubAllGlobals();auth.user=true;});
describe('Support proxy authorization and route boundaries',()=>{
 it('forwards help, tickets, replies and status without dropping authentication',async()=>{const calls=vi.fn(async()=>new Response('{}'));vi.stubGlobal('fetch',calls);for(const path of ['support/config','support/tickets','support/tickets/'+id])expect((await GET(request('GET',path),context(path))).status).toBe(200);for(const path of ['support/tickets','support/tickets/'+id+'/reply','support/tickets/'+id+'/status'])expect((await POST(request('POST',path),context(path))).status).toBe(200);expect(calls).toHaveBeenCalledTimes(6);expect(calls).toHaveBeenLastCalledWith(expect.stringContaining('/operations/support/tickets/'+id+'/status'),expect.objectContaining({headers:expect.objectContaining({Authorization:'Bearer fixture-session'})}));});
 it('rejects sessionless, cross-origin and unlisted operations',async()=>{const calls=vi.fn();vi.stubGlobal('fetch',calls);const path='support/tickets';expect((await POST(request('POST',path,'https://foreign.test'),context(path))).status).toBe(403);auth.user=false;expect((await GET(request('GET',path),context(path))).status).toBe(401);auth.user=true;for(const invalid of ['support/send-whatsapp','support/tickets/'+id+'/delete','support/tickets/'+id+'/reply/extra'])expect((await POST(request('POST',invalid),context(invalid))).status).toBe(404);expect(calls).not.toHaveBeenCalled();});
});
