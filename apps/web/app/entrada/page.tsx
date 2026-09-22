import Link from 'next/link';
import { redirect } from 'next/navigation';
import { serverSupabase } from '../../lib/auth/server';
import { authConfigured } from '../../lib/auth/config';
export const dynamic='force-dynamic';
export default async function Entry(){
 if(!authConfigured())redirect('/login');const client=await serverSupabase();const {data}=await client.auth.getUser();if(!data.user?.email_confirmed_at)redirect('/login');
 const [{data:staff},{data:companies,error}]=await Promise.all([client.from('platform_staff').select('role,active').eq('user_id',data.user.id).maybeSingle(),client.from('companies').select('id,name').is('archived_at',null).order('name')]);
 if(error)return <main className="internal-shell"><h1>Não foi possível carregar seus acessos.</h1><Link href="/workspace">Tentar novamente</Link></main>;
 const internal=staff?.active?(staff.role==='platform_admin'?'/admin':'/acompanhamento/carteira'):null;
 if(internal&&!companies?.length)redirect(internal);
 if(!internal&&!companies?.length)redirect('/workspace');
 if(!internal&&companies?.length===1)redirect('/empresa/'+companies[0]!.id);
 return <main className="internal-shell"><Link className="brand" href="/"><span className="brand-mark">a</span>askadia.</Link><div className="page-heading"><div><p className="page-eyebrow">ESCOLHA SEU CONTEXTO</p><h1>Onde vamos trabalhar agora?</h1><p>Cada contexto possui seus próprios dados e permissões.</p></div></div><div className="tenant-company-grid">{internal&&<section className="panel tenant-company-card"><h2>{staff?.role==='platform_admin'?'Administração Askadia':'Minha carteira de clientes'}</h2><p>Acesso interno identificado e auditado.</p><Link className="button button-primary" href={internal}>Abrir operação interna</Link></section>}{companies?.map(c=><section key={c.id} className="panel tenant-company-card"><h2>{c.name}</h2><p>Entrar com seu vínculo nesta empresa.</p><Link className="button button-outline" href={'/empresa/'+c.id}>Abrir empresa</Link></section>)}</div><p><Link className="button button-outline" href="/workspace">Gerenciar empresas e acessos</Link></p></main>;
}
