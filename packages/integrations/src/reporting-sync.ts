import type { ReportingProvider,ReportScope,ReportPage } from './reporting';
export type ReportingJob={id:string;scope:ReportScope;cursor:string|null;attempt:number;generation:number};
/** Repository implementation must use a tenant lock and commit page+checkpoint atomically.
 * This handler is deliberately not registered until the encrypted credential store and repository are deployed. */
export interface ReportingJobStore{
 claim(job:ReportingJob):Promise<boolean>;
 authorized(job:ReportingJob):Promise<boolean>;
 commitPage(job:ReportingJob,page:ReportPage):Promise<void>;
 fail(job:ReportingJob,code:string,retryAt:string|null):Promise<void>;
}
export async function processReportingPage(job:ReportingJob,provider:ReportingProvider,store:ReportingJobStore,now=new Date()){
 if(!await store.claim(job))return 'duplicate' as const;
 if(!await store.authorized(job)){await store.fail(job,'revoked',null);return 'revoked' as const;}
 try{
  const page=await provider.read(job.scope,job.cursor??undefined);
  // Revocation can happen while the provider request is in flight.
  if(!await store.authorized(job)){await store.fail(job,'revoked',null);return 'revoked' as const;}
  if(page.cursor&&page.cursor===job.cursor)throw new Error('cursor_stalled');
  await store.commitPage(job,page);
  return page.cursor?'more' as const:'complete' as const;
 }catch(error){
  const code=error&&typeof error==='object'&&'code' in error?String(error.code):'provider_error';
  const retryable=['rate_limited','provider_error'].includes(code)&&job.attempt<5;
  const delay=error&&typeof error==='object'&&'retryAfterSeconds' in error?Number(error.retryAfterSeconds):0;
  const retryAt=retryable?new Date(now.getTime()+Math.max(Math.min(delay||0,3600),Math.min(3600,30*2**job.attempt))*1000).toISOString():null;
  await store.fail(job,code,retryAt);return retryAt?'retry' as const:'failed' as const;
 }
}
