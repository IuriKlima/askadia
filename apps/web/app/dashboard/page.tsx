import {redirect} from 'next/navigation';
export const dynamic='force-dynamic';
// Preserve old bookmarks without exposing the retired reporting screens.
export default async function DashboardPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const {companyId}=await searchParams;
 redirect(typeof companyId==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(companyId)?'/empresa/'+companyId:'/entrada');
}
