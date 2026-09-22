import { redirect } from 'next/navigation';
import { serverSupabase } from './server';
import { authConfigured } from './config';
export async function staffIdentity(){
  if(!authConfigured())redirect('/login');
  const client=await serverSupabase();
  const {data}=await client.auth.getUser();
  if(!data.user?.email_confirmed_at)redirect('/login');
  const {data:staff,error}=await client.from('platform_staff').select('role,active').eq('user_id',data.user.id).maybeSingle();
  return {user:data.user,role:staff?.active?staff.role:null,unavailable:Boolean(error)};
}
