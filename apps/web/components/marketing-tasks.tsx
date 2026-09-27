'use client';
import Link from 'next/link';
import {AdExecutions} from './ad-executions';
import {useEffect,useState} from 'react';
import {BellRing} from 'lucide-react';
import type {CalendarItem} from '@askadia/contracts';
import {journeyApi} from '../lib/journey-api';
import type {MarketingJourney} from './guided-strategy';
export function MarketingTasks({companyId,area}:{companyId:string;area:string}){
 const [tasks,setTasks]=useState<{label:string;href:string}[]>([]);
 useEffect(()=>{const c=new AbortController();let timer:ReturnType<typeof setTimeout>;async function refresh(){try{const [journey,calendar]=await Promise.all([journeyApi<MarketingJourney>('companies/'+companyId+'/launch/journey',undefined,c.signal),journeyApi<{items:CalendarItem[];current:{id:string;generation:number}|null}>('companies/'+companyId+'/calendar',undefined,c.signal)]);if(c.signal.aborted)return;const result:{label:string;href:string}[]=[];const pending=journey.stages.find(s=>!s.approved);if(pending&&['inicio','estrategia','campanhas','preparacao'].includes(area)){const names=['Revisar concorrentes e análise','Aprovar diagnóstico e planos','Aprovar publicações e datas','Revisar relacionamento e vendas','Revisar propostas de tráfego'];if(area!=='campanhas'||pending.stage>=4)result.push({label:names[pending.stage-1]!,href:'estrategia'});}const items=calendar.items.filter(i=>i.brief_id===calendar.current?.id&&i.generation===calendar.current.generation&&i.details&&i.approved_revision!==i.revision);if(items.length&&['inicio','conteudo','preparacao'].includes(area))result.push({label:items.length+' publicação(ões) aguardando sua aprovação',href:'conteudo'});if(['inicio','site'].includes(area)){const site=await journeyApi<{site:{draft:unknown;revision:number;published_revision:number|null}|null}>('companies/'+companyId+'/site',undefined,c.signal);if(site.site?.draft&&site.site.revision!==site.site.published_revision)result.push({label:'Revisar e aprovar a publicação do site',href:'site'});}if(!c.signal.aborted)setTasks(result);}catch{/* The module itself retains its own load/error states. */}finally{if(!c.signal.aborted)timer=setTimeout(()=>void refresh(),30000);}}void refresh();return()=>{c.abort();clearTimeout(timer);};},[companyId,area]);
 const adsNotice=['inicio','campanhas'].includes(area)?<AdExecutions companyId={companyId} noticesOnly/>:null;
 if(!tasks.length)return adsNotice;
 return <>{adsNotice}<aside style={{padding:20,border:'1px solid #b6d58d',borderRadius:16,background:'#edf7df',marginBottom:24}} aria-label="Tarefas que precisam da sua decisão"><strong style={{display:'flex',alignItems:'center',gap:9}}><BellRing size={18}/>Sua próxima ação</strong><ul style={{marginBottom:0,lineHeight:1.9}}>{tasks.map(t=><li key={t.label}><Link href={'/empresa/'+companyId+'/'+t.href}>{t.label} →</Link></li>)}</ul></aside></>;
}
