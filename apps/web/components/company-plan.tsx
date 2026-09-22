'use client';
import { useEffect,useState } from 'react';
import { ShieldCheck } from 'lucide-react';
import type { CompanyCapabilities,PlanRecord } from '@askadia/contracts';
import { connectedApi } from '../lib/api-client';
const resources:Record<string,string>={ai_tokens:'Tokens de IA',images:'Imagens',storage_bytes:'Armazenamento (bytes)',members:'Usuários',regenerations:'Regenerações',messages:'Mensagens'};
const featureNames:Record<string,string>={strategy:'Estratégia',content:'Conteúdo',crm:'CRM',sites:'Sites',inbox:'Caixa de entrada',triage:'Triagem',weekly_support:'Acompanhamento'};
export function CompanyPlan({companyId}:{companyId:string}){
  const [data,setData]=useState<{plans:PlanRecord[];capabilities:CompanyCapabilities}|null>(null),[error,setError]=useState('');
  useEffect(()=>{
    const controller=new AbortController();setData(null);setError('');
    Promise.all([connectedApi<PlanRecord[]>('plans',{signal:controller.signal}),connectedApi<CompanyCapabilities>('companies/'+companyId+'/capabilities',{signal:controller.signal})])
      .then(([plans,capabilities])=>{if(!controller.signal.aborted)setData({plans,capabilities});})
      .catch(e=>{if(!controller.signal.aborted)setError(e.message);});
    return ()=>controller.abort();
  },[companyId]);
  if(error)return <div className="error-banner" role="alert">{error}</div>;
  if(!data)return <div className="tenant-loading" role="status">Carregando plano e permissões…</div>;
  return <><div className="section-heading"><h2>Plano e recursos desta empresa</h2><span className="tag">{data.capabilities.subscription.status==='draft'?'Sem contratação':data.capabilities.subscription.status}</span></div>
    <div className="tenant-company-grid">{data.plans.map(plan=><section className="panel tenant-company-card" key={plan.id}><span className="tag">{plan.kind==='addon'?'Adicional opcional':'Por empresa'}</span><h2>{plan.name}</h2><div className="plan-price">{plan.price_cents===null?'Sob consulta':new Intl.NumberFormat('pt-BR',{style:'currency',currency:plan.currency}).format(plan.price_cents/100)}{plan.price_cents!==null&&<small>/mês</small>}</div><p>{plan.features.map(f=>featureNames[f]??f).join(' · ')}</p><p className="plan-availability">Contratação ainda indisponível. Nenhuma cobrança será iniciada aqui.</p></section>)}</div>
    <div className="info-note"><ShieldCheck size={18}/><p>{data.capabilities.features.length?'Recursos contratados: '+data.capabilities.features.map(f=>featureNames[f]??f).join(', ')+'.':'Esta empresa ainda não tem recursos pagos liberados. Criar uma empresa não ativa uma assinatura.'} Acesso, plano e limites são verificados separadamente no servidor.</p></div>
    <section className="panel table-panel"><table><thead><tr><th>Recurso</th><th>Franquia configurada</th></tr></thead><tbody>{Object.entries(resources).map(([key,label])=><tr key={key}><td>{label}</td><td>{data.capabilities.quotas[key]===null||data.capabilities.quotas[key]===undefined?'A definir':data.capabilities.quotas[key]!.toLocaleString('pt-BR')}</td></tr>)}</tbody></table></section><p className="form-note">Franquia não definida não significa uso ilimitado. Consumo e cobrança serão habilitados após configuração e homologação.</p>
  </>;
}
