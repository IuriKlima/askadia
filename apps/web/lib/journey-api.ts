export class JourneyError extends Error{constructor(message:string,public status:number){super(message);}}
export async function journeyApi<T>(path:string,body?:unknown,signal?:AbortSignal):Promise<T>{
 const response=await fetch('/api/onboarding/'+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json'},...(body!==undefined?{body:JSON.stringify(body)}:{}),cache:'no-store',signal});
 const result=await response.json();if(response.status===401){window.location.assign('/login');throw new JourneyError('Sessão expirada.',401);}if(!response.ok)throw new JourneyError(result.message??'Não foi possível concluir.',response.status);return result;
}
