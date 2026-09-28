import {afterEach,describe,expect,it,vi} from 'vitest';
import {createRequire} from 'node:module';
import type {CalendarItem} from '@askadia/contracts';
import {CalendarPost} from '../apps/web/components/editorial-calendar';
import {finalVideoError,uploadPublicationVideo,videoUploadBlock} from '../apps/web/lib/publication-video';
const require=createRequire(new URL('../apps/web/package.json',import.meta.url));
const React=require('react');const {renderToStaticMarkup}=require('react-dom/server');
afterEach(()=>vi.unstubAllGlobals());
const file=new File([new Uint8Array([0,0,0,20,102,116,121,112,105,115,111,109])],'tour final.mp4',{type:'video/mp4'});
describe('Final video uploads remain available during background preparation',()=>{
 it('renders the enabled upload ahead of the script while other manual edits are locked',()=>{
  vi.stubGlobal('React',React);
  const item={id:'item',revision:2,position:1,format:'video',idea:'Tour da academia',status:'draft',planned_date:'2026-10-08',details:{title:'Tour',caption:'Conheça a academia',cta:'',hashtags:[],slides:[],designBrief:'Guia de edição',videoScript:'Roteiro da publicação',clientMaterials:[],unknowns:[]}} as unknown as CalendarItem;
  const html=renderToStaticMarkup(React.createElement(CalendarPost,{item,assets:[],videos:[],companyId:'company',current:true,write:false,uploadAllowed:true,approve:true,busy:false,reload:vi.fn(),action:vi.fn()}));
  expect(html).toMatch(/<button(?![^>]*disabled)[^>]*>.*?Enviar vídeo<\/button>/);
  expect(html.indexOf('Enviar vídeo')).toBeLessThan(html.indexOf('Texto e orientação criativa'));
  expect(html).not.toContain('Editar conteúdo e data');
  expect(html).toMatch(/<button[^>]*disabled[^>]*>Aprovar peça final<\/button>/);
 });
 it('keeps permission, current strategy and detailed content requirements',()=>{
  expect(videoUploadBlock({write:false,current:true,details:true})).toContain('perfil');
  expect(videoUploadBlock({write:true,current:false,details:true})).toContain('estratégia');
  expect(videoUploadBlock({write:true,current:true,details:false})).toContain('roteiro');
  expect(videoUploadBlock({write:true,current:true,details:true})).toBeNull();
 });
 it('rejects unsupported and oversized files before sending any bytes',async()=>{
  const fetcher=vi.fn();vi.stubGlobal('fetch',fetcher);
  expect(finalVideoError({name:'video.mp4',type:'video/mp4',size:0})).toContain('vazio');
  expect(finalVideoError({name:'video.mp4',type:'video/mp4',size:50*1024*1024+1})).toContain('50 MB');
  expect(finalVideoError({name:'video.MP4',type:'',size:100})).toBeNull();
  await expect(uploadPublicationVideo({companyId:'a',itemId:'b',revision:2,uploadId:'c',file:new File(['bad'],'video.mov',{type:'video/quicktime'})})).rejects.toThrow('MP4');
  expect(fetcher).not.toHaveBeenCalled();
 });
 it('sends the exact file, company, item and reviewed revision through the authenticated proxy',async()=>{
  const fetcher=vi.fn().mockResolvedValue(new Response(JSON.stringify({revision:3})));vi.stubGlobal('fetch',fetcher);
  expect(await uploadPublicationVideo({companyId:'a',itemId:'b',revision:2,uploadId:'c',file})).toEqual({revision:3});
  expect(fetcher).toHaveBeenCalledWith('/api/onboarding/companies/a/calendar/video/b/c',expect.objectContaining({method:'POST',body:file,headers:{'Content-Type':'video/mp4','X-File-Name':'tour%20final.mp4','X-Revision':'2'}}));
 });
 it('requires review again when the content version changed during upload',async()=>{
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response('{}',{status:409})));
  await expect(uploadPublicationVideo({companyId:'a',itemId:'b',revision:2,uploadId:'c',file})).rejects.toThrow('publicação mudou');
 });
});
