import { AuthPanel } from '../../components/auth-panel';
import { authConfigured } from '../../lib/auth/config';
export const dynamic='force-dynamic';
export default async function Login({searchParams}:{searchParams:Promise<{error?:string}>}){return <AuthPanel configured={authConfigured()} callbackError={Boolean((await searchParams).error)}/>;}
