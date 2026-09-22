import { NextResponse } from 'next/server';
import { serverSupabase } from '../../../../lib/auth/server';
import { authConfigured,appOrigin } from '../../../../lib/auth/config';
const allowed:Record<string,RegExp[]>={GET:[/^$/],POST:[/^imports(\/preview)?$/,/^exports$/,/^keywords$/]};
async function forward(request:Request,context:{params:Promise<{path?:string[]}>}){
 const path=(await context.params).path?.join('/')??'';
 if(!allowed[request.method]?.some(p=>p.test(path)))return NextResponse.json({message:'Rota indisponível.'},{status:404});
 if(request.method!=='GET'&&request.headers.get('origin')!==appOrigin())return NextResponse.json({message:'Origem não autorizada.'},{status:403});
 if(!authConfigured())return NextResponse.json({message:'Supabase ainda não configurado.'},{status:503});
 const client=await serverSupabase();const {data,error}=await client.auth.getUser();
 if(error||!data.user?.email_confirmed_at)return NextResponse.json({message:'Faça login para continuar.'},{status:401});
 const {data:session}=await client.auth.getSession();
 if(!session.session)return NextResponse.json({message:'Sessão expirada.'},{status:401});
 const body=request.method==='GET'?undefined:await request.text();
 if(body&&Buffer.byteLength(body,'utf8')>1900000)return NextResponse.json({message:'Importação acima do limite.'},{status:413});
 try{
  const response=await fetch((process.env.API_INTERNAL_URL||'http://127.0.0.1:4000')+'/dashboard'+(path?'/'+path:'')+new URL(request.url).search,{method:request.method,headers:{Authorization:'Bearer '+session.session.access_token,'Content-Type':'application/json'},body,cache:'no-store',signal:AbortSignal.timeout(30000)});
  return new Response(await response.arrayBuffer(),{status:response.status,headers:{'Content-Type':response.headers.get('content-type')||'application/json','Content-Disposition':response.headers.get('content-disposition')||'inline','Cache-Control':'private, no-store'}});
 }catch{return NextResponse.json({message:'Não foi possível consultar o dashboard.'},{status:503});}
}
export const GET=forward;export const POST=forward;
