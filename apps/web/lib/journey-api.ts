import {readApiResponse} from './response';
export class JourneyError extends Error{constructor(message:string,public status:number){super(message);}}
export async function journeyApi<T>(path:string,body?:unknown,signal?:AbortSignal):Promise<T>{
 const response=await fetch('/api/onboarding/'+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json'},...(body!==undefined?{body:JSON.stringify(body)}:{}),cache:'no-store',signal});
 if(response.status===401)window.location.assign('/login');
 try{return await readApiResponse<T>(response);}catch(error){throw new JourneyError(error instanceof Error?error.message:'Não foi possível concluir.',response.status);}
}
