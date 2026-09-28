import {readApiResponse} from './response';
export async function identityApi<T>(path='',method='GET',body?:unknown,signal?:AbortSignal):Promise<T>{
 const response=await fetch('/api/identity'+(path?'/'+path:''),{method,headers:{'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{}),cache:'no-store',signal});
 if(response.status===401)window.location.assign('/login');
 return readApiResponse<T>(response);
}
