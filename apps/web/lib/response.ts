/** Proxies can return HTML during a restart. Never surface raw HTML/parser errors to a customer. */
export async function readApiResponse<T>(response:Response):Promise<T>{
 const text=await response.text();
 let payload:unknown;
 try{payload=text?JSON.parse(text):null;}catch{payload=null;}
 if(!response.ok){
  const message=payload&&typeof payload==='object'&&'message' in payload?(payload as {message:unknown}).message:null;
  const readable=typeof message==='string'?message:Array.isArray(message)?message.filter(v=>typeof v==='string').join(' · '):'';
  throw new Error(response.status===401?'Sua sessão expirou. Entre novamente para continuar.':response.status===403?'Seu acesso não permite esta ação. Peça ao proprietário para revisar suas permissões.':response.status===429?'Muitas solicitações neste momento. Aguarde um pouco e tente novamente.':readable||'O serviço está temporariamente indisponível. Tente novamente em instantes.');
 }
 if(payload===null&&response.status!==204)throw new Error('Não foi possível carregar a resposta do serviço. Tente novamente em instantes.');
 return payload as T;
}
