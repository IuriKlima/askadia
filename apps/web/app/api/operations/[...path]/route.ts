import { NextResponse } from 'next/server';
import { serverSupabase } from '../../../../lib/auth/server';
import { appOrigin,authConfigured } from '../../../../lib/auth/config';
const uuid='[a-fA-F0-9-]{36}';
const allowed:Record<string,RegExp[]>={
  GET:[/^(me|plans|portfolio|staff)$/,new RegExp('^companies/'+uuid+'/(capabilities|delegations|assignments|drafts)$'),new RegExp('^access/'+uuid+'$')],
  POST:[/^access$/,new RegExp('^access/'+uuid+'/end$'),new RegExp('^companies/'+uuid+'/(assignments|delegations|import)$')],
};
async function forward(request:Request,context:{params:Promise<{path:string[]}>}){
  const path=(await context.params).path.join('/');
  if(!allowed[request.method]?.some(pattern=>pattern.test(path)))return NextResponse.json({message:'Rota não disponível.'},{status:404});
  if(request.method!=='GET'&&request.headers.get('origin')!==appOrigin())return NextResponse.json({message:'Origem não autorizada.'},{status:403});
  if(!authConfigured())return NextResponse.json({message:'Acesso conectado indisponível.'},{status:503});
  const client=await serverSupabase();
  const {data:verified,error}=await client.auth.getUser();
  if(error||!verified.user?.email_confirmed_at)return NextResponse.json({message:'Faça login para continuar.'},{status:401});
  const {data}=await client.auth.getSession();
  if(!data.session)return NextResponse.json({message:'Sessão expirada.'},{status:401});
  const body=request.method==='GET'?undefined:await request.text();
  if(body&&new TextEncoder().encode(body).byteLength>(path.endsWith('/import')?262144:16384))return NextResponse.json({message:'Solicitação muito grande.'},{status:413});
  const query=new URL(request.url).search;
  try{
    const response=await fetch((process.env.API_INTERNAL_URL||'http://127.0.0.1:4000')+'/operations/'+path+query,{
      method:request.method,headers:{Authorization:'Bearer '+data.session.access_token,'Content-Type':'application/json'},
      body,cache:'no-store',signal:AbortSignal.timeout(15000),
    });
    return NextResponse.json(await response.json(),{status:response.status,headers:{'Cache-Control':'private, no-store'}});
  }catch{return NextResponse.json({message:'Não foi possível acessar o servidor.'},{status:503});}
}
export const GET=forward;
export const POST=forward;
