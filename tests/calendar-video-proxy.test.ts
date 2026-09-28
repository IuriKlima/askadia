import {afterEach,describe,expect,it,vi} from 'vitest';
const auth=vi.hoisted(()=>({user:true}));
vi.mock('../apps/web/lib/auth/server',()=>({serverSupabase:async()=>({auth:{getUser:async()=>({data:{user:auth.user?{id:'fixture',email_confirmed_at:'confirmed'}:null},error:null}),getSession:async()=>({data:{session:{access_token:'fixture-session'}}})}})}));
vi.mock('../apps/web/lib/auth/config',()=>({appOrigin:()=> 'https://example.test',authConfigured:()=>true}));
import {POST} from '../apps/web/app/api/onboarding/[...path]/route';
const company='10000000-0000-4000-8000-000000000001',item='20000000-0000-4000-8000-000000000002',upload='30000000-0000-4000-8000-000000000003';
const path='companies/'+company+'/calendar/video/'+item+'/'+upload;
const context=()=>({params:Promise.resolve({path:path.split('/')})});
const request=(bytes:Uint8Array,origin='https://example.test')=>new Request('https://example.test/api/onboarding/'+path,{method:'POST',headers:{Origin:origin,'Content-Type':'video/mp4','X-Revision':'3','X-File-Name':'video.mp4'},body:bytes});
afterEach(()=>{auth.user=true;vi.unstubAllGlobals();});
describe('Private final video proxy',()=>{
 it('preserves a file above 10 MB and its company, version and authorization',async()=>{
  const bytes=new Uint8Array(12*1024*1024+20);bytes[bytes.length-1]=123;
  const calls=vi.fn(async()=>new Response(JSON.stringify({revision:4})));vi.stubGlobal('fetch',calls);
  expect((await POST(request(bytes),context())).status).toBe(200);
  expect(calls).toHaveBeenCalledWith(expect.stringContaining('/onboarding/'+path),expect.objectContaining({headers:expect.objectContaining({Authorization:'Bearer fixture-session','Content-Type':'video/mp4','X-Revision':'3','X-File-Name':'video.mp4'})}));
  const body=(calls.mock.calls[0] as unknown as [string,{body:Uint8Array}])[1].body;
  expect(body.byteLength).toBe(bytes.byteLength);expect(body[body.length-1]).toBe(123);
 });
 it('refuses cross-origin, unsigned and oversized uploads without forwarding',async()=>{
  const calls=vi.fn();vi.stubGlobal('fetch',calls);
  expect((await POST(request(new Uint8Array(12),'https://foreign.test'),context())).status).toBe(403);
  auth.user=false;expect((await POST(request(new Uint8Array(12)),context())).status).toBe(401);
  auth.user=true;expect((await POST(request(new Uint8Array(50*1024*1024+1)),context())).status).toBe(413);
  expect(calls).not.toHaveBeenCalled();
 });
});
