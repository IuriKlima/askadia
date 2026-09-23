import {readApiResponse} from './response';
export async function connectedApi<T>(path:string,options:{method?:string;body?:unknown;signal?:AbortSignal}={}):Promise<T>{
  const response=await fetch('/api/operations/'+path,{method:options.method??'GET',headers:{'Content-Type':'application/json'},...(options.body!==undefined?{body:JSON.stringify(options.body)}:{}),signal:options.signal,cache:'no-store'});
  if(response.status===401)window.location.assign('/login');
  return readApiResponse<T>(response);
}
