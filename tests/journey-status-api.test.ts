import {beforeEach,describe,it,expect,vi} from 'vitest';
import type {AuthRequest} from '../apps/api/src/identity/auth';
vi.mock('../apps/api/src/campaigns/ads',()=>({adsAccess:vi.fn(),serviceDb:vi.fn()}));
import {adsAccess} from '../apps/api/src/campaigns/ads';
import {LaunchController} from '../apps/api/src/onboarding/launch';
const output={diagnosis:'Fixture: diagnóstico pronto'};
const journey={profileVersion:6,stages:[{stage:2,data:{id:'brief',generation:1,output}}]};
function request(generation=1){
 const queries:{table:string;filters:Record<string,unknown>}[]=[];
 const client={rpc:vi.fn().mockResolvedValue({data:journey,error:null}),from:vi.fn((table:string)=>{
  const query={table,filters:{}};queries.push(query);
  const builder={select:()=>builder,eq:(name:string,value:unknown)=>{(query.filters as Record<string,unknown>)[name]=value;return builder;},maybeSingle:async()=>({data:table==='company_strategy_briefs'?{id:'brief',generation,profile_version:6,status:'review',created_at:'2026-09-28T16:00:00Z'}:{status:'pending',error:null},error:null})};return builder;
 })};
 return {req:{actor:{client}} as unknown as AuthRequest,client,queries};
}
describe('Journey progress uses authorized company and reviewed snapshot',()=>{
 beforeEach(()=>vi.clearAllMocks());
 it('combines the exact approval output with company-scoped generation status',async()=>{
  const {req,queries}=request();const value=await new LaunchController().journey(req,'company-a');
  expect(adsAccess).toHaveBeenCalledWith(req,'company-a');
  expect(value.strategy).toMatchObject({id:'brief',generation:1,output});
  expect(queries).toHaveLength(3);
  expect(queries.every(q=>q.filters.company_id==='company-a'&&q.filters.profile_version===6)).toBe(true);
  expect(queries.find(q=>q.table==='company_launch_jobs')?.filters.kind).toBe('recommendations');
 });
 it('does not display a new generation under an older approval basis',async()=>{
  const {req}=request(2);expect((await new LaunchController().journey(req,'company-a')).strategy).toBeNull();
 });
 it('stops before reading company data when access is denied',async()=>{
  vi.mocked(adsAccess).mockRejectedValueOnce(new Error('Access denied'));
  const {req,client}=request();await expect(new LaunchController().journey(req,'company-b')).rejects.toThrow('Access denied');
  expect(client.rpc).not.toHaveBeenCalled();expect(client.from).not.toHaveBeenCalled();
 });
});
