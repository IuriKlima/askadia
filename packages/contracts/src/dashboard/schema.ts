import { z } from 'zod';
export const daySchema=z.iso.date();
export const timezoneSchema=z.string().max(80).refine(v=>{try{new Intl.DateTimeFormat('pt-BR',{timeZone:v});return true;}catch{return false;}},'Fuso inválido');
export const dashboardQuerySchema=z.object({
 companyId:z.uuid(),start:daySchema,end:daySchema,timezone:timezoneSchema,
 comparison:z.enum(['previous','year','none']).default('previous'),channel:z.enum(['all','meta_ads','google_ads','organic','unknown']).default('all'),
 account:z.string().max(100).default(''),campaign:z.string().max(100).default(''),
 mode:z.enum(['period','cohort']).default('period'),observationEnd:daySchema.optional(),
 socialMode:z.enum(['published','activity']).default('published'),section:z.enum(['overview','trends','instagram','traffic','site','funnel','finance']).default('overview'),
 access:z.uuid().optional(),
}).strict().refine(v=>v.start<=v.end&&Date.parse(v.end)-Date.parse(v.start)<=366*86400000,'Selecione até 367 dias em ordem cronológica.')
.refine(v=>!v.observationEnd||v.observationEnd>=v.end,'Observação deve terminar após a coorte.');
export type DashboardQuery=z.infer<typeof dashboardQuerySchema>;
export const qualityStates=['available','partial','estimated','no_history','no_basis','stale','disconnected','unsupported','forbidden'] as const;
export type QualityState=typeof qualityStates[number];
export type Metric={id:string;label:string;value:number|null;unit:'BRL'|'count'|'percent'|'multiple';state:QualityState;reason:string|null;formula:string;bases:Record<string,number|null>;source:string;updatedAt:string|null;better:'higher'|'lower'|'neutral'};
const id=z.string().trim().min(1).max(150),count=z.number().int().nonnegative().max(1e12),money=z.number().int().nonnegative().max(1e12);
export const adFactSchema=z.object({kind:z.literal('ads'),id,date:daySchema,provider:z.enum(['meta_ads','google_ads']),accountId:id,campaignId:id,campaignName:z.string().max(200),timezone:timezoneSchema,currency:z.literal('BRL'),spendCents:money,impressions:count,clicks:count,clickType:z.enum(['all','link']),reportedConversions:z.number().nonnegative().nullable(),dateBasis:z.enum(['interaction','conversion']),attribution:z.string().max(300)}).strict();
export const paymentFactSchema=z.object({kind:z.literal('payment'),id,date:daySchema,customerId:id,netCents:money,variableCostCents:money.nullable(),acquisitionDate:daySchema.nullable(),customerHistoryKnown:z.boolean(),customerPreexisting:z.boolean(),channel:z.enum(['meta_ads','google_ads','organic','unknown']),campaignId:z.string().max(150),evidence:z.string().max(250),classification:z.enum(['acquisition','renewal','reactivation','unknown'])}).strict();
export const refundFactSchema=z.object({kind:z.literal('refund'),id,date:daySchema,paymentId:id,cents:money,variableCostReversalCents:money.nullable()}).strict();
export const costFactSchema=z.object({kind:z.literal('cost'),id,date:daySchema,category:z.enum(['media','other_acquisition']),cents:money,channel:z.enum(['all','meta_ads','google_ads','organic','unknown']),campaignId:z.string().max(150),allocation:z.string().min(3).max(300),estimated:z.boolean()}).strict();
export const socialFactSchema=z.object({kind:z.literal('social'),id,date:daySchema,accountId:id,publishedAt:z.iso.datetime(),caption:z.string().max(2200),permalink:z.url().refine(v=>/^https:\/\/(www\.)?instagram\.com\//.test(v)),format:z.enum(['image','carousel','reel','story','video']),temporal:z.enum(['lifetime','interval']),intervalStart:daySchema.nullable(),intervalEnd:daySchema.nullable(),reach:count.nullable(),likes:count.nullable(),comments:count.nullable(),saves:count.nullable(),shares:count.nullable(),views:count.nullable(),collectedAt:z.iso.datetime()}).strict();
export const webFactSchema=z.object({kind:z.literal('web'),id,date:daySchema,provider:z.enum(['ga4','search_console','askadia_forms']),resource:id,metric:z.enum(['sessions','users','key_events','forms_received','clicks','impressions']),value:count,timezone:timezoneSchema,coverage:z.enum(['complete','partial'])}).strict();
export const trendFactSchema=z.object({kind:z.literal('trend'),id,date:daySchema,term:z.string().min(1).max(150),termType:z.enum(['search_term','topic']),region:z.string().min(2).max(150),language:z.string().max(30),searchType:z.string().max(30),batchId:id,scale:z.enum(['relative_0_100','consistent']),value:z.number().nonnegative().nullable(),coverage:z.enum(['sufficient','insufficient']),sourceUrl:z.url().refine(v=>v.startsWith('https://trends.google.com/')),collectedAt:z.iso.datetime()}).strict().refine(v=>v.scale!=='relative_0_100'||v.value===null||v.value<=100);
export const dashboardFactSchema=z.discriminatedUnion('kind',[adFactSchema,paymentFactSchema,refundFactSchema,costFactSchema,socialFactSchema,webFactSchema,trendFactSchema]);
export type DashboardFact=z.infer<typeof dashboardFactSchema>;
export type AdFact=z.infer<typeof adFactSchema>;
export type PaymentFact=z.infer<typeof paymentFactSchema>;
export type SocialFact=z.infer<typeof socialFactSchema>;
export type TrendFact=z.infer<typeof trendFactSchema>;
export const importSchema=z.object({
 source:z.string().trim().min(2).max(100),domain:z.enum(['digital','finance','trends']),
 coverageStart:daySchema,coverageEnd:daySchema,coverage:z.enum(['partial','complete']),note:z.string().trim().min(5).max(500),
 records:z.array(dashboardFactSchema).min(1).max(1000),
}).strict().superRefine((v,c)=>{
 if(v.coverageStart>v.coverageEnd)c.addIssue({code:'custom',message:'Período inválido'});
 const ids=new Set<string>();
 for(const row of v.records){
  if(ids.has(row.kind+':'+row.id))c.addIssue({code:'custom',message:'ID duplicado no arquivo'});
  ids.add(row.kind+':'+row.id);
  const domain=['payment','refund','cost'].includes(row.kind)?'finance':row.kind==='trend'?'trends':'digital';
  if(domain!==v.domain)c.addIssue({code:'custom',message:'Arquivo mistura domínios'});
  if(row.date<v.coverageStart||row.date>v.coverageEnd)c.addIssue({code:'custom',message:'Registro fora da cobertura'});
 }
});
export type DashboardImport=z.infer<typeof importSchema>;
export type Coverage={source:string;domain:'digital'|'finance'|'trends';start:string;end:string;complete:boolean;updatedAt:string;note:string};
export type DashboardData={facts:DashboardFact[];coverage:Coverage[]};
export const financeInputsSchema=z.object({mediaCents:money.nullable(),otherAcquisitionCents:money.nullable(),newCustomers:count.nullable(),mediaCustomers:count.nullable(),attributedNetCents:money.nullable(),mediaAttributedNetCents:money.nullable(),variableCostCents:money.nullable(),scopeComplete:z.boolean()}).strict();
export type FinanceInputs=z.infer<typeof financeInputsSchema>;
