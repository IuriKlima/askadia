import {afterEach,beforeEach,describe,it,expect,vi} from 'vitest';
import {randomUUID} from 'node:crypto';
import {metaPages,ChannelsController,sealChannel,openChannel} from '../apps/api/src/onboarding/channels';
import type {AuthRequest} from '../apps/api/src/identity/auth';
import {recoverMetaSelection,clearMetaSelection} from '../apps/web/lib/meta-selection';
const company=randomUUID(),other=randomUUID(),session=randomUUID();
const storage=()=>{const values=new Map<string,string>();return {getItem:(key:string)=>values.get(key)??null,setItem:(key:string,value:string)=>{values.set(key,value);},removeItem:(key:string)=>{values.delete(key);}};};
const page={id:'123',name:'Academia de teste',access_token:'fixture-page-token',tasks:['MANAGE']};
function request(allowed=true,scopes=['pages_show_list']){
 const rpc=vi.fn(async(name:string,args:Record<string,unknown>)=>{
  if(name==='company_capabilities')return {data:{actions:allowed?['billing.manage']:[]},error:null};
  if(name==='read_meta_selection')return args.p_company_id===company&&args.p_id===session?{data:sealChannel(company,{pages:[page],userToken:'fixture-user-token',scopes,expiresAt:null}),error:null}:{data:null,error:{code:'42501',message:'OAuth state unavailable'}};
  return {data:true,error:null};
 });return {rpc,req:{actor:{client:{rpc}}} as unknown as AuthRequest};
}
beforeEach(()=>{vi.stubEnv('WEB_ORIGIN','https://example.test');vi.stubEnv('META_APP_ID','fixture-app');vi.stubEnv('META_APP_SECRET','fixture-secret');vi.stubEnv('META_GRAPH_API_VERSION','v23.0');vi.stubEnv('SECRETS_ENCRYPTION_KEY','a'.repeat(64));});
afterEach(()=>{vi.unstubAllEnvs();vi.unstubAllGlobals();});
describe('Temporary Meta selection survives navigation without trusting browser data',()=>{
 it('recovers only the same company and expires without extending on reload',()=>{
  const store=storage(),now=1000;expect(recoverMetaSelection(store,company,session,now)).toBe(session);
  expect(recoverMetaSelection(store,company,null,now+100)).toBe(session);expect(recoverMetaSelection(store,other,null,now+100)).toBeNull();
  expect(recoverMetaSelection(store,company,session,now+599000)).toBe(session);
  expect(recoverMetaSelection(store,company,session,now+600001)).toBeNull();expect(recoverMetaSelection(store,company,null,now+600002)).toBeNull();
 });
 it('rejects malformed hints, clears completed selections and tolerates blocked storage',()=>{
  const store=storage();expect(recoverMetaSelection(store,company,'https://foreign.test')).toBeNull();recoverMetaSelection(store,company,session);clearMetaSelection(store,company);expect(recoverMetaSelection(store,company,null)).toBeNull();
  expect(recoverMetaSelection(null,company,session)).toBe(session);
 });
});
describe('Meta page discovery and safe selector responses',()=>{
 it('paginates using cursors without following provider URLs and keeps authorized pages',async()=>{
  const calls=vi.fn().mockResolvedValueOnce(Response.json({data:[page],paging:{next:'https://foreign.test/steal',cursors:{after:'cursor'}}})).mockResolvedValueOnce(Response.json({data:[{...page,id:'456'}]}));vi.stubGlobal('fetch',calls);
  const found=await metaPages('fixture-user-token',['pages_show_list']);expect(found.pages.map(p=>p.id)).toEqual(['123','456']);expect(found.instagramUnavailable).toBe(true);
  const second=new URL(calls.mock.calls[1]![0]);expect(second.origin).toBe('https://graph.facebook.com');expect(second.searchParams.get('after')).toBe('cursor');expect(second.searchParams.get('fields')).not.toContain('instagram');expect(second.searchParams.has('access_token')).toBe(false);
 });
 it('falls back to Facebook Pages if optional Instagram fields are denied',async()=>{
  const calls=vi.fn().mockResolvedValueOnce(Response.json({error:{code:200,message:'Fixture denied'}},{status:403})).mockResolvedValueOnce(Response.json({data:[page]}));vi.stubGlobal('fetch',calls);
  const found=await metaPages('fixture-user-token',['pages_show_list','instagram_basic']);expect(found.pages).toHaveLength(1);expect(found.instagramUnavailable).toBe(true);expect(new URL(calls.mock.calls[1]![0]).searchParams.get('fields')).toBe('id,name,access_token,tasks');
 });
 it('does not turn expired tokens or invalid provider responses into an empty list',async()=>{
  const calls=vi.fn().mockResolvedValue(Response.json({error:{code:190}},{status:400}));vi.stubGlobal('fetch',calls);
  await expect(metaPages('expired',['instagram_basic'])).rejects.toThrow('expirou');expect(calls).toHaveBeenCalledTimes(1);
  calls.mockResolvedValue(Response.json({data:[{name:'Missing page ID'}]}));await expect(metaPages('fixture',[])).rejects.toThrow('lista válida');
 });
 it('returns only public page fields and requires owner and company-bound OAuth session',async()=>{
  const controller=new ChannelsController(),{req,rpc}=request();
  const result=await controller.pages(req,company,{sessionId:session});expect(result.pages).toEqual([{id:'123',name:page.name,instagramId:undefined,instagramName:undefined,canConnect:true}]);expect(JSON.stringify(result)).not.toContain('token');
  expect(rpc).toHaveBeenCalledWith('read_meta_selection',{p_company_id:company,p_id:session});
  await expect(controller.pages(request(false).req,company,{sessionId:session})).rejects.toThrow('proprietário');
  await expect(controller.pages(req,other,{sessionId:session})).rejects.toThrow('expirou');
  await expect(controller.select(req,company,{sessionId:session,pageId:'999'})).rejects.toThrow('autorizada');
 });
 it('keeps a Page visible but prevents connection when Meta supplies no Page credential',async()=>{
  const {req,rpc}=request();rpc.mockImplementation(async(name:string)=>name==='company_capabilities'?{data:{actions:['billing.manage']},error:null}:name==='read_meta_selection'?{data:sealChannel(company,{pages:[{id:'123',name:page.name}],scopes:['pages_show_list'],expiresAt:null}),error:null}:{data:true,error:null});
  const calls=vi.fn();vi.stubGlobal('fetch',calls);const controller=new ChannelsController();
  expect((await controller.pages(req,company,{sessionId:session})).pages[0]).toMatchObject({id:'123',canConnect:false});
  await expect(controller.select(req,company,{sessionId:session,pageId:'123'})).rejects.toThrow('não liberou acesso');expect(calls).not.toHaveBeenCalled();
 });
 it('refreshes only the existing authorized session and keeps tokens encrypted',async()=>{
  const calls=vi.fn().mockResolvedValueOnce(Response.json({data:[{permission:'pages_show_list',status:'granted'}]})).mockResolvedValueOnce(Response.json({data:[{...page,id:'456'}]}));vi.stubGlobal('fetch',calls);
  const {req,rpc}=request();const result=await new ChannelsController().pages(req,company,{sessionId:session,refresh:true});expect(result.pages[0]!.id).toBe('456');
  const saved=rpc.mock.calls.find(([name])=>name==='save_meta_selection')![1]!;expect(saved.p_id).toBe(session);expect(String(saved.p_cipher)).not.toContain('fixture-user-token');expect(openChannel<{pages:{id:string}[]}>(company,String(saved.p_cipher)).pages[0]!.id).toBe('456');
 });
});
