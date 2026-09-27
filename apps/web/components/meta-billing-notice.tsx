'use client';
import {useEffect,useState} from 'react';
import {journeyApi} from '../lib/journey-api';
type Status={status:'unavailable'|'restricted'|'unverified';message:string;checkedAt:string;url:string};
export function MetaBillingNotice({companyId}:{companyId:string}){
 const [data,setData]=useState<Status|null>(null);
 useEffect(()=>{const c=new AbortController();let timer:ReturnType<typeof setTimeout>;async function refresh(){try{const d=await journeyApi<Status>('companies/'+companyId+'/ads/billing',undefined,c.signal);if(!c.signal.aborted)setData(d);}catch{if(!c.signal.aborted)setData(null);}finally{if(!c.signal.aborted)timer=setTimeout(()=>void refresh(),300000);}}void refresh();return()=>{c.abort();clearTimeout(timer);};},[companyId]);
 if(!data)return null;return <aside role={data.status==='restricted'?'alert':'status'} className={data.status==='restricted'?'error-banner':'info-note'} style={{marginBottom:20}}><strong>{data.status==='restricted'?'Atenção: conta Meta com restrição':'Faturamento Meta'}</strong><p>{data.message}</p><a href={data.url} target="_blank" rel="noreferrer">Conferir pagamentos na Meta ↗</a><p><small>Consulta em {new Date(data.checkedAt).toLocaleString('pt-BR')}</small></p></aside>;
}
