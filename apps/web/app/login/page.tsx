import { AuthPanel } from '../../components/auth-panel';
import { authConfigured } from '../../lib/auth/config';
export const dynamic='force-dynamic';
export default async function Login({searchParams}:{searchParams:Promise<{error?:string;modo?:string}>}){const params=await searchParams;return <AuthPanel configured={authConfigured()} callbackError={Boolean(params.error)} initialMode={params.modo==='cadastro'?'signup':'login'}/>;}
