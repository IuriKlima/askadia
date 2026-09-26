'use client';
import {BrandWordmark,BrandMark} from './brand';

import {CompanyOverview} from './company-overview';
import {LoadState} from './load-state';
import {SiteBuilder} from './site-builder';
import {StrategyWorkspace} from './strategy-workspace';
import {CampaignsPanel} from './campaigns-panel';
import {ManagementIntegration} from './management-integration';
import {CompanyChannels} from './company-channels';

import Link from 'next/link';
import { useEffect,useRef,useState } from 'react';
import { ArrowRight,Building2,Menu,X,LayoutDashboard,Compass,CalendarDays,Megaphone,Users,MessageCircle,SlidersHorizontal,ChartNoAxesCombined,Palette,Globe,Plug,ShieldCheck,CreditCard } from 'lucide-react';
import { type OnboardingSnapshot } from '@askadia/contracts';
import { EditorialCalendar } from './editorial-calendar';
import {InboxPanel} from './inbox-panel';
import {AttendanceSettings} from './attendance-settings';
import { CrmPanel } from './crm-panel';
import { OnboardingChat } from './onboarding-chat';
import { DraftImportPanel } from './draft-import';
import { CompanyPlan } from './company-plan';
import { journeyApi } from '../lib/journey-api';
import styles from './journey.module.css';
const navigationIcons:Record<string,typeof LayoutDashboard>={inicio:LayoutDashboard,estrategia:Compass,conteudo:CalendarDays,campanhas:Megaphone,crm:Users,atendimento:MessageCircle,'configuracao-atendimento':SlidersHorizontal,resultados:ChartNoAxesCombined,perfil:Palette,site:Globe,integracoes:Plug,equipe:ShieldCheck,assinatura:CreditCard};
const titles:Record<string,string>={inicio:'Visão geral',agentes:'Agentes da sua empresa.',estrategia:'Estratégia',conteudo:'Calendário e publicações',campanhas:'Campanhas',crm:'CRM',atendimento:'Conversas da sua empresa.','configuracao-atendimento':'Configuração de Atendimento.',integracoes:'Integrações',site:'Meu site.',assinatura:'Assinatura da empresa.'};
export function CompanyJourney({company,area,actions,email,calendarDay}:{calendarDay?:string;company:{id:string;name:string};area:string;actions:string[];email:string}){
 const [data,setData]=useState<OnboardingSnapshot|null>(null),[error,setError]=useState(''),[mobile,setMobile]=useState(false);
 const marketing=actions.includes('marketing.read'),write=actions.includes('marketing.write'),billing=actions.includes('billing.manage');
 const [reload,setReload]=useState(0);

 const menuButton=useRef<HTMLButtonElement>(null);
 useEffect(()=>{if(!mobile)return;document.getElementById('company-navigation')?.querySelector<HTMLAnchorElement>('a')?.focus();const close=(e:KeyboardEvent)=>{if(e.key==='Escape'){setMobile(false);requestAnimationFrame(()=>menuButton.current?.focus());}};document.addEventListener('keydown',close);return()=>document.removeEventListener('keydown',close);},[mobile]);
 const base='/empresa/'+company.id;
 useEffect(()=>{if(!marketing)return;setError('');const c=new AbortController();journeyApi<OnboardingSnapshot>('companies/'+company.id,undefined,c.signal).then(r=>{if(!c.signal.aborted)setData(r);}).catch(e=>{if(!c.signal.aborted)setError(e.message);});return()=>c.abort();},[company.id,marketing,reload]);
 const complete=data?.step==='complete';const interviewing=['onboarding','perfil'].includes(area);
 const groups=[{title:'Início',items:[['inicio','Visão geral']]},{title:'Planejamento',items:[['estrategia','Estratégia']]},{title:'Conteúdo',items:[['conteudo','Calendário e publicações']]},{title:'Aquisição',items:[['campanhas','Campanhas'],...(actions.includes('crm.read')?[['crm','CRM'],['atendimento','Caixa de entrada'],...(write?[['configuracao-atendimento','Configuração de Atendimento']]:[])]:[])]},{title:'Resultados',items:[['resultados','Desempenho e retorno']]},{title:'Empresa',items:[['perfil','Perfil e marca'],['site','Meu site'],['integracoes','Integrações'],...(billing||actions.includes('members.manage')?[['equipe','Equipe e acessos']]:[]),...(billing?[['assinatura','Assinatura']]:[])]}];
 const nav=marketing?groups:[{title:'Atendimento',items:[['atendimento','Caixa de entrada'],['crm','CRM']]}];
 const href=(key:string)=>key==='resultados'?'/dashboard?companyId='+company.id:key==='equipe'?'/workspace?companyId='+company.id+'&view=team':base+(key==='inicio'?'':'/'+key);
 return <div className={styles.shell}><a className={styles.skipLink} href="#company-content">Pular para o conteúdo</a>
  {mobile&&<button className={styles.scrim} aria-label="Fechar menu" onClick={()=>{setMobile(false);requestAnimationFrame(()=>menuButton.current?.focus());}}/>}
  <aside id="company-navigation" className={styles.sidebar} data-open={mobile}><div className={styles.brandRow}><Link href="/" className="brand"><BrandWordmark/></Link><button className={styles.mobileButton} aria-label="Fechar menu" onClick={()=>setMobile(false)}><X size={20}/></button></div><Link className={styles.context} href="/entrada"><Building2 size={18}/><span><small>EMPRESA ATUAL</small><strong>{data?.state.facts.name?.value??company.name}</strong><small>Trocar empresa ou contexto</small></span></Link><nav aria-label="Navegação da empresa" onClick={()=>setMobile(false)}>{nav.map(g=><div className={styles.navGroup} key={g.title}><small>{g.title}</small>{g.items.map(([key,label])=>{const Icon=navigationIcons[key!]??Compass;return <Link key={key} href={href(key!)} aria-current={area===key?'page':undefined}><Icon size={17} aria-hidden="true"/><span>{label}</span></Link>;})}</div>)}</nav><footer><small>{email}</small><Link href="/workspace">Gerenciar meus negócios</Link></footer></aside>
  <div className={styles.main} inert={mobile}><header className={styles.topbar}><button ref={menuButton} className={styles.mobileButton} aria-expanded={mobile} aria-controls="company-navigation" aria-label="Abrir menu" onClick={()=>setMobile(true)}><Menu size={22}/></button><span>{company.name}</span><small>{billing?'Proprietário':marketing?'Marketing':'Atendente'} · acesso verificado</small></header><main id="company-content" tabIndex={-1} className={area==='atendimento'?styles.inboxContent:styles.content}>
   {interviewing?<OnboardingChat companyId={company.id} readOnly={!write} summaryOnly={area==='perfil'}/>:<>{area!=='atendimento'&&<div className={styles.pageHeading}><p className="page-eyebrow">{marketing?'SUA AGÊNCIA DE MARKETING COM IA':'SUA OPERAÇÃO COMERCIAL'}</p><h1>{titles[area]??'Sua empresa.'}</h1></div>}{area!=='atendimento'&&error&&<LoadState error={error} retry={()=>setReload(v=>v+1)}/>}
   {area==='inicio'&&!data&&!error&&<LoadState label="Carregando a visão geral…"/>}{area==='inicio'&&data&&<CompanyOverview key={company.id} companyId={company.id} profile={data}/>}
   {area==='agentes'&&<><section className={styles.nextAction}><div className={styles.orb}><BrandMark/></div><div><h2>Conhecer minha empresa</h2><p>Converse, consulte o histórico e atualize as informações que orientam os agentes.</p><Link className="button button-primary" href={base+'/onboarding'}>{complete?'Consultar e atualizar':'Continuar onboarding'}<ArrowRight size={16}/></Link></div></section><section className={styles.moduleCard}><h2>Estratégia e tráfego pago · OpenAI</h2><p>A estratégia começa pelo perfil confirmado. Publicação e orçamento continuam sujeitos às aprovações autorizadas.</p><Link href={base+'/estrategia'}>Preparar o planejamento</Link><h2>Design · Nano Banana Pro</h2><p>Materiais visuais usam o Gemini. A geração depende do fluxo de criação, do limite da empresa e da disponibilidade do provedor.</p><Link href={base+'/conteudo'}>Abrir conteúdo</Link></section></>}
   {area==='estrategia'&&<StrategyWorkspace companyId={company.id} data={data} write={write} approve={actions.includes('strategy.approve')}/>}
   {area==='conteudo'&&<><EditorialCalendar day={calendarDay} key={company.id} companyId={company.id} write={write} approve={actions.includes('content.approve')}/><details className={styles.moduleCard}><summary>Acervo e importação de rascunhos anteriores</summary><DraftImportPanel companyId={company.id} companyName={company.name}/></details></>}
   {area==='assinatura'&&<CompanyPlan companyId={company.id}/>}
   {area==='crm'&&<CrmPanel companyId={company.id} inbox={false} write={actions.includes('crm.write')}/>}
   {area==='atendimento'&&<InboxPanel key={company.id} companyId={company.id} companyName={company.name}/>}
   {area==='configuracao-atendimento'&&<AttendanceSettings key={company.id} companyId={company.id} companyName={company.name}/>}
   {area==='campanhas'&&<CampaignsPanel key={company.id} companyId={company.id} profile={data?.confirmedProfile} crm={actions.includes('crm.read')}/>}

   {area==='site'&&<SiteBuilder key={company.id} companyId={company.id} profile={data}/>}
   {area==='integracoes'&&<><CompanyChannels key={company.id} companyId={company.id}/><ManagementIntegration key={'management-'+company.id} companyId={company.id} owner={billing}/></>}
   {area==='integracoes'&&<section className={styles.moduleCard}><h2>Continue após conectar</h2><div className={styles.overview}><section><h3>Atendimento</h3><p>Veja as conversas e configure a IA por canal.</p><Link href={base+'/atendimento'}>Abrir caixa de entrada →</Link></section><section><h3>Conteúdo</h3><p>Revise as peças antes de aprovar. As datas do calendário são de planejamento.</p><Link href={base+'/conteudo'}>Abrir calendário →</Link></section><section><h3>Campanhas</h3><p>Confira destinatários ou revise as propostas de investimento.</p><Link href={base+'/campanhas'}>Abrir campanhas →</Link></section></div></section>}
   </>}
  </main></div>
 </div>;
}
