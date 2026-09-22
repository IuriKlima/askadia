import Link from 'next/link';
import { notFound,redirect } from 'next/navigation';
import { serverSupabase } from '../../../../lib/auth/server';
import { CompanyJourney } from '../../../../components/company-journey';
export const dynamic='force-dynamic';
export default async function CompanyPage({params}:{params:Promise<{id:string;section?:string[]}>}){
 const {id,section}=await params; if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))notFound();
 const day=section?.[0]==='conteudo'&&section.length===2?section[1]:undefined;if(day&&day!=='sem-data'&&(!/^\d{4}-\d{2}-\d{2}$/.test(day)||Number.isNaN(Date.parse(day))||new Date(day).toISOString().slice(0,10)!==day))notFound();const area=day?'conteudo':section?.join('/')||'inicio';
 const permissions:Record<string,string>={inicio:'company.read',agentes:'marketing.read',onboarding:'marketing.read',perfil:'marketing.read',estrategia:'marketing.read',conteudo:'marketing.read',campanhas:'marketing.read',site:'marketing.read',integracoes:'marketing.read',crm:'crm.read',atendimento:'crm.read','configuracao-atendimento':'marketing.write',assinatura:'billing.manage'};
 if(!permissions[area])notFound();
 const client=await serverSupabase();const {data:auth}=await client.auth.getUser();if(!auth.user?.email_confirmed_at)redirect('/login');
 const {data:cap,error}=await client.rpc('company_capabilities',{p_company_id:id});
 if(error||!cap?.actions?.includes(permissions[area])||(area==='configuracao-atendimento'&&!cap?.actions?.includes('crm.read')))return <main className="internal-shell"><section className="panel internal-empty"><h1>Acesso indisponível.</h1><p>Seu perfil não permite abrir esta área ou o vínculo não está mais ativo.</p><Link className="button button-outline" href="/entrada">Trocar contexto</Link></section></main>;
 const {data:company}=await client.from('companies').select('id,name').eq('id',id).is('archived_at',null).maybeSingle();if(!company)notFound();
 if(area==='inicio'&&!cap.actions.includes('marketing.read'))redirect('/empresa/'+id+'/atendimento');
 return <CompanyJourney key={id+':'+area} company={company} area={area} calendarDay={day} actions={cap.actions} email={auth.user.email??''}/>;
}
