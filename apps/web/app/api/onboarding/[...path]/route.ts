import { NextResponse } from 'next/server';
import { serverSupabase } from '../../../../lib/auth/server';
import { appOrigin,authConfigured } from '../../../../lib/auth/config';
const uuid='[a-fA-F0-9-]{36}';
const allowed:Record<string,RegExp[]>={
GET:[new RegExp('^companies/'+uuid+'(/(channels|calendar|creatives/'+uuid+'|strategy|crm|attachments/'+uuid+'))?$'),new RegExp('^access/'+uuid+'$')],
POST:[/^companies$/,new RegExp('^companies/'+uuid+'/(channels/meta/start|channels/meta/pages|channels/meta/select|channels/evolution/connect|channels/evolution/status|channels/disconnect|calendar/generate|calendar/edit|calendar/approve|calendar/design|answers|places|website|strategy|strategy/generate|strategy/approve|crm/contacts|crm/stage|crm/conversations|crm/mode|crm/notes|attachments/'+uuid+')$'),new RegExp('^access/'+uuid+'/meetings$')],
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
  const isFile=path.includes('/attachments/')||path.includes('/creatives/');
  const body=request.method==='GET'?undefined:await request.arrayBuffer();
  if(body&&body.byteLength>(isFile?10485760:65536))return NextResponse.json({message:'Solicitação muito grande.'},{status:413});
  const query=new URL(request.url).search;
  try{
    const response=await fetch((process.env.API_INTERNAL_URL||'http://127.0.0.1:4000')+'/onboarding/'+path+query,{
      method:request.method,headers:{Authorization:'Bearer '+data.session.access_token,'Content-Type':isFile?(request.headers.get('content-type')??'application/octet-stream'):'application/json','X-File-Name':request.headers.get('x-file-name')??''},
      body,cache:'no-store',signal:AbortSignal.timeout(path.endsWith('/calendar/design')?150000:path.endsWith('/calendar/generate')?110000:path.endsWith('/strategy/generate')?60000:path.includes('/channels/')?60000:20000),
    });
    if(isFile&&request.method==='GET'&&response.ok)return new Response(response.body,{status:response.status,headers:{'Content-Type':response.headers.get('content-type')??'application/octet-stream','Content-Disposition':response.headers.get('content-disposition')??'attachment','Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
    return NextResponse.json(await response.json(),{status:response.status,headers:{'Cache-Control':'private, no-store'}});
  }catch{return NextResponse.json({message:'Não foi possível acessar o servidor.'},{status:503});}
}
export const GET=forward;
export const POST=forward;
