import {describe,expect,it,vi,afterEach} from 'vitest';
import {instagramUsername,instagramEngagement,type InstagramSnapshot} from '../packages/contracts/src/instagram';
import {inspectInstagram} from '../apps/api/src/onboarding/instagram-provider';
afterEach(()=>{vi.unstubAllGlobals();vi.unstubAllEnvs();});
describe('Instagram public analysis',()=>{
 it('accepts profile handles and rejects arbitrary hosts, posts and Graph field injection',()=>{
  expect(instagramUsername('https://www.instagram.com/Minha.Academia/?igsh=share')).toBe('minha.academia');expect(instagramUsername('@ACADEMIA')).toBe('academia');
  for(const value of ['https://instagram.com.attacker.test/gym/','https://user:pass@instagram.com/gym','https://instagram.com/p/ABC/','gym){id}','a..b','../admin','https://127.0.0.1/gym'])expect(()=>instagramUsername(value)).toThrow();
 });
 it('distinguishes hidden counts, zero engagement and missing followers',()=>{
  const s:InstagramSnapshot={username:'gym',name:'Gym',collectedAt:new Date().toISOString(),followers:100,mediaCount:3,posts:[{id:'1',timestamp:null,url:null,likes:10,comments:2},{id:'2',timestamp:null,url:null,likes:null,comments:5},{id:'3',timestamp:null,url:null,likes:0,comments:0}]};
  expect(instagramEngagement(s)).toEqual({sampleSize:3,measuredPosts:2,meanInteractions:6,engagementPercent:6});
  expect(instagramEngagement({...s,followers:0}).engagementPercent).toBeNull();expect(instagramEngagement({...s,posts:[]}).meanInteractions).toBeNull();
 });
 it('uses official business discovery, limits the sample and never fabricates missing metrics',async()=>{
  vi.stubEnv('META_GRAPH_API_VERSION','v26.0');const fetcher=vi.fn().mockResolvedValue(new Response(JSON.stringify({business_discovery:{username:'gym',name:'Gym',media:{data:[{id:'1',comments_count:0}]}}}),{status:200}));vi.stubGlobal('fetch',fetcher);
  const snapshot=await inspectInstagram('123','private-token','gym');expect(snapshot.followers).toBeNull();expect(snapshot.posts[0]?.likes).toBeNull();expect(snapshot.posts[0]?.comments).toBe(0);
  const url=new URL(String(fetcher.mock.calls[0]?.[0]));expect(url.hostname).toBe('graph.facebook.com');expect(url.searchParams.get('fields')).toContain('media.limit(25)');expect(url.searchParams.has('access_token')).toBe(false);
 });
});
