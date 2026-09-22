import { InternalDenied,PortfolioPanel } from '../../../components/internal-panel';
import { staffIdentity } from '../../../lib/auth/staff';
export const dynamic='force-dynamic';
export default async function PortfolioPage(){
  const {user,role,unavailable}=await staffIdentity();
  if(!role)return <InternalDenied unavailable={unavailable}/>;
  return <PortfolioPanel admin={role==='platform_admin'} email={user.email??''}/>;
}
