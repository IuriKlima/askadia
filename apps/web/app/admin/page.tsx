import { InternalDenied,PortfolioPanel } from '../../components/internal-panel';
import { staffIdentity } from '../../lib/auth/staff';
export const dynamic='force-dynamic';
export default async function AdminPage(){
  const {user,role,unavailable}=await staffIdentity();
  if(role!=='platform_admin')return <InternalDenied unavailable={unavailable}/>;
  return <PortfolioPanel admin email={user.email??''}/>;
}
