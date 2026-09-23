'use client';
import {useState} from 'react';
/** Official embed URL observed from Google's own Share → Embed control (23/09/2026).
 * No scraping, private endpoints or arbitrary executable HTML. */
export function TrendsEmbed({geo,query}:{geo:string;query:string}){
 const [view,setView]=useState<'RELATED_QUERIES'|'TIMESERIES'>('RELATED_QUERIES');
 if(!/^BR-[A-Z]{2}$/.test(geo))return null;
 const req={comparisonItem:[{keyword:query,geo,time:'today 3-m'}],category:0,property:''};
 const params=new URLSearchParams({req:JSON.stringify(req),tz:'180',forceMobileMode:'true',hl:'pt-BR',eq:new URLSearchParams({geo,date:'today 3-m',q:query,hl:'pt-BR'}).toString()});
 return <div><div role="group" aria-label="Visualização Google Trends" style={{display:'flex',gap:8,margin:'18px 0',flexWrap:'wrap'}}><button className={'button '+(view==='RELATED_QUERIES'?'button-primary':'button-outline')} onClick={()=>setView('RELATED_QUERIES')} aria-pressed={view==='RELATED_QUERIES'}>Pesquisas relacionadas</button><button className={'button '+(view==='TIMESERIES'?'button-primary':'button-outline')} onClick={()=>setView('TIMESERIES')} aria-pressed={view==='TIMESERIES'}>Interesse no tempo</button></div><iframe key={geo+query+view} title={view==='RELATED_QUERIES'?'Pesquisas relacionadas no Google Trends':'Interesse ao longo do tempo no Google Trends'} src={'https://trends.google.com/trends/embed/explore/'+view+'?'+params} style={{width:'100%',height:425,border:0,borderRadius:12,background:'white'}} loading="eager" referrerPolicy="strict-origin-when-cross-origin"/><p style={{fontSize:11,lineHeight:1.7,color:'var(--muted)'}}>Visualização oficial do Google Trends. Escolha “Principais” e use as setas para percorrer as pesquisas. A quantidade disponível e a paginação são definidas pelo Google. Se o gráfico for bloqueado no navegador, abra o link abaixo.</p></div>;
}
