import {createHash} from 'node:crypto';
import {siteDomain} from '@askadia/contracts';
export function hostingConfigured(){return Boolean(process.env.EASYPANEL_API_URL&&process.env.EASYPANEL_API_TOKEN&&process.env.EASYPANEL_SITE_PROJECT&&process.env.EASYPANEL_SITE_SERVICE&&process.env.EASYPANEL_CERTIFICATE_RESOLVER);}
/** Server-owned destination only: callers cannot select another service, port or certificate resolver. */
export async function provisionSiteDomain(company:string,host:string){
 if(!hostingConfigured())return false;
 const base=new URL(process.env.EASYPANEL_API_URL!);if(base.protocol!=='https:'&&!(base.protocol==='http:'&&['127.0.0.1','localhost','easypanel'].includes(base.hostname)))throw new Error('Configure HTTPS or the internal Easypanel service');
 const hostname=siteDomain(host),projectName=process.env.EASYPANEL_SITE_PROJECT!,serviceName=process.env.EASYPANEL_SITE_SERVICE!;
 async function request(path:string,body?:unknown){const r=await fetch(new URL(base.pathname.replace(/\/$/,'')+'/'+path,base.origin),{method:body?'POST':'GET',headers:{Authorization:'Bearer '+process.env.EASYPANEL_API_TOKEN,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(15000),redirect:'error'});if(!r.ok)throw new Error('Hosting unavailable');return r.json() as Promise<unknown>;}
 const list=await request('listDomains?'+new URLSearchParams({projectName,serviceName}));if(!Array.isArray(list))throw new Error('Unsupported Easypanel API response');
 const existing=list.find((d:Record<string,unknown>)=>d.host===hostname);if(existing){const dest=existing.serviceDestination as Record<string,unknown>|undefined;if(existing.https!==true||dest?.projectName!==projectName||dest.serviceName!==serviceName||dest.port!==3000)throw new Error('Existing domain differs');return true;}
 await request('createDomain',{id:'askadia-site-'+createHash('sha256').update(company+':'+hostname).digest('hex').slice(0,24),host:hostname,https:true,path:'/',wildcard:false,middlewares:[],certificateResolver:process.env.EASYPANEL_CERTIFICATE_RESOLVER,destinationType:'service',serviceDestination:{projectName,serviceName,protocol:'http',port:3000}});return true;
}
