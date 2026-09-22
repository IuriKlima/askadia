import { redirect } from 'next/navigation';
import { DashboardPanel } from '../../components/dashboard';
import { serverSupabase } from '../../lib/auth/server';
import { authConfigured } from '../../lib/auth/config';
import { dashboardQuerySchema,dateInZone,presetPeriod } from '@askadia/contracts';
export const dynamic='force-dynamic';
export default async function DashboardPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 if(!authConfigured())redirect('/login');
 const client=await serverSupabase();const {data}=await client.auth.getUser();
 if(!data.user?.email_confirmed_at)redirect('/login');
 const {data:companies,error}=await client.from('companies').select('id,name,timezone,city,segment').is('archived_at',null).order('name');
 if(error)return <main className="auth-page"><h1>Dashboard indisponível</h1><p>Não foi possível consultar suas empresas. Verifique a configuração do banco.</p></main>;
 const params=await searchParams,first=companies?.find(c=>c.id===params.companyId)??companies?.[0];
 const today=dateInZone(new Date(),first?.timezone??'America/Sao_Paulo');
 const filters=dashboardQuerySchema.safeParse({...presetPeriod('30',today),...Object.fromEntries(Object.entries(params).filter(([,v])=>typeof v==='string')),companyId:first?.id,timezone:first?.timezone});
 return <DashboardPanel companies={companies??[]} today={today} initial={filters.success?filters.data:{}}/>;
}
