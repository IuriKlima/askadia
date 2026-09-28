import Link from 'next/link';
import {ArrowRight,Check,ShieldCheck} from 'lucide-react';
import {commercePlans,commerceFeatures,type CommercePlanId} from '@askadia/contracts';
import s from './purchase.module.css';
export const brl=(cents:number)=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0}).format(cents/100);
export function PricingCards({onSelect,busy=false}:{onSelect?:(id:CommercePlanId)=>void;busy?:boolean}){
 return <div className={s.plans}>{commercePlans.map(p=><article key={p.id} className={p.installments===12?s.annual:s.plan}>
  <div className={s.planTop}><span>{p.name}</span>{p.installments===12&&<small>Economize R$ 5.988 no ano</small>}</div><h2>{p.installments===12&&<small>12 parcelas de</small>}{brl(p.installmentCents)}{p.installments===1&&<small>/mês</small>}</h2>
  <p>{p.installments===12?'Contrato anual · total de R$ 11.976':'Assinatura mensal recorrente'}</p><p className={s.planDescription}>{p.description}</p><ul><li><Check size={17}/>Todas as funcionalidades</li><li><Check size={17}/>Estratégia, conteúdo e site com IA</li><li><Check size={17}/>Campanhas, atendimento e CRM</li><li><Check size={17}/>Você aprova antes da execução</li></ul>
  {onSelect?<button className={s.primary} disabled={busy} onClick={()=>onSelect(p.id)}>{busy?'Preparando…':'Escolher '+p.name.toLowerCase()}<ArrowRight size={18}/></button>:<Link className={s.primary} href="/login?modo=cadastro">Começar grátis<ArrowRight size={18}/></Link>}<small className={s.perCompany}>Valor por empresa criada no workspace</small>
 </article>)}</div>;
}
export function PricingFeatures(){return <section className={s.features}><div className={s.sectionTitle}><span>TUDO CONECTADO AO SEU NEGÓCIO</span><h2>Menos tarefas soltas.<br/>Mais direção para crescer.</h2><p>Os mesmos recursos nos dois planos. Escolha a forma de pagamento que combina com a sua empresa.</p></div><div className={s.featureGrid}>{commerceFeatures.map(([title,description],i)=><article key={title}><span>{String(i+1).padStart(2,'0')}</span><h3>{title}</h3><p>{description}</p></article>)}</div><p className={s.disclosure}><ShieldCheck size={20}/>A verba de anúncios e os custos dos provedores conectados são separados da assinatura. Recursos dependem das integrações e permissões disponíveis. Uso de IA sujeito aos limites da conta; nenhum plano promete uso ilimitado.</p></section>;}
