import { notFound } from 'next/navigation';
import { InternalCompanyPanel,InternalDenied } from '../../../components/internal-panel';
import { staffIdentity } from '../../../lib/auth/staff';
export const dynamic='force-dynamic';
export default async function OperationPage({params}:{params:Promise<{id:string}>}){
  const {id}=await params;
  if(!/^[a-f0-9-]{36}$/i.test(id))notFound();
  const {user,role,unavailable}=await staffIdentity();
  if(!role)return <InternalDenied unavailable={unavailable}/>;
  return <InternalCompanyPanel sessionId={id} email={user.email??''}/>;
}
