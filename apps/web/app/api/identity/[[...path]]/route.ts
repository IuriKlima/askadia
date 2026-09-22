import { NextResponse } from 'next/server';
import { serverSupabase } from '../../../../lib/auth/server';
import { appOrigin,authConfigured } from '../../../../lib/auth/config';
const uuid='[a-fA-F0-9-]{36}';
const allowed:Record<string,RegExp[]>={GET:[/^$/,new RegExp('^companies/'+uuid+'/team$')],POST:[/^workspaces$/,/^companies$/,/^invitations\/accept$/,new RegExp('^companies/'+uuid+'/(invitations|export)$'),new RegExp('^companies/'+uuid+'/invitations/'+uuid+'/revoke$')],PATCH:[new RegExp('^companies/'+uuid+'$'),new RegExp('^companies/'+uuid+'/members/'+uuid+'$')]};
async function forward(request:Request,context:{params:Promise<{path?:string[]}>}){
  const path=(await context.params).path?.join('/')??'';
  if(!allowed[request.method]?.some(pattern=>pattern.test(path))) return NextResponse.json({message:'Rota não disponível.'},{status:404});
  if(request.method!=='GET' && request.headers.get('origin')!==appOrigin()) return NextResponse.json({message:'Origem não autorizada.'},{status:403});
  if(!authConfigured()) return NextResponse.json({message:'O acesso conectado ainda não foi configurado.'},{status:503});
  const client=await serverSupabase();
  const {data:verified,error}=await client.auth.getUser();
  if(error || !verified.user?.email_confirmed_at) return NextResponse.json({message:'Faça login para continuar.'},{status:401});
  const {data:session}=await client.auth.getSession();
  if(!session.session) return NextResponse.json({message:'Sessão expirada.'},{status:401});
  const body=request.method==='GET'?undefined:await request.text();
  if(body && body.length>16384) return NextResponse.json({message:'Solicitação muito grande.'},{status:413});
  try{
    const response=await fetch((process.env.API_INTERNAL_URL||'http://127.0.0.1:4000')+'/identity'+(path?'/'+path:''),{
      method:request.method,headers:{Authorization:'Bearer '+session.session.access_token,'Content-Type':'application/json'},
      body,cache:'no-store',signal:AbortSignal.timeout(15000),
    });
    const payload=await response.json();
    return NextResponse.json(payload,{status:response.status,headers:{'Cache-Control':'private, no-store'}});
  }catch{return NextResponse.json({message:'Não foi possível acessar o servidor. Tente novamente.'},{status:503});}
}
export const GET=forward;
export const POST=forward;
export const PATCH=forward;
