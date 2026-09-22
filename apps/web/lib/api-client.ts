export async function connectedApi<T>(path:string,options:{method?:string;body?:unknown;signal?:AbortSignal}={}):Promise<T>{
  const response=await fetch('/api/operations/'+path,{method:options.method??'GET',headers:{'Content-Type':'application/json'},...(options.body!==undefined?{body:JSON.stringify(options.body)}:{}),signal:options.signal,cache:'no-store'});
  const result=await response.json();
  if(response.status===401){window.location.assign('/login');throw new Error('Sua sessão expirou.');}
  if(!response.ok)throw new Error(result.message??'Não foi possível concluir a operação.');
  return result as T;
}
