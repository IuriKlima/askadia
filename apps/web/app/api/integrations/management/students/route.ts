import {NextResponse} from 'next/server';
export async function POST(request:Request){
 const authorization=request.headers.get('authorization');if(!authorization||!/^Bearer ask_mgmt_[A-Za-z0-9_-]{43}$/.test(authorization))return NextResponse.json({message:'Credencial de integração inválida.'},{status:401});
 if(!request.headers.get('content-type')?.startsWith('application/json'))return NextResponse.json({message:'Use application/json.'},{status:415});
 const reader=request.body?.getReader();if(!reader)return NextResponse.json({message:'Corpo obrigatório.'},{status:400});const chunks:Uint8Array[]=[];let size=0;
 try{for(;;){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>250000){await reader.cancel();return NextResponse.json({message:'Envie até 250 KB por lote.'},{status:413});}chunks.push(part.value);}}finally{reader.releaseLock();}
 try{const response=await fetch((process.env.API_INTERNAL_URL||'http://127.0.0.1:4000')+'/integrations/management/students',{method:'POST',headers:{Authorization:authorization,'Content-Type':'application/json'},body:Buffer.concat(chunks),cache:'no-store',signal:AbortSignal.timeout(30000)});return NextResponse.json(await response.json(),{status:response.status,headers:{'Cache-Control':'no-store'}});}catch{return NextResponse.json({message:'Serviço temporariamente indisponível.'},{status:503});}
}
