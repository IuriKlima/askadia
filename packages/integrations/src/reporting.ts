/** Read-only reporting ports. Credentials are resolved by the server after tenant authorization. */
export type ReportScope={companyId:string;connectionId:string;resource:string;start:string;end:string;timezone:string};
export type ReportPage={rows:unknown[];cursor:string|null;temporal:'interval'|'lifetime';coverage:'partial'|'complete';limitations:string[]};
export type Capability={operation:string;supported:boolean;reason?:string};
export type ProviderHealth={state:'unconfigured'|'pending_validation'|'available'|'revoked';capabilities:Capability[];historicalStart:string|null;lastSuccess:string|null;reason?:string};
export interface ReportingProvider {readonly provider:string;read(scope:ReportScope,cursor?:string):Promise<ReportPage>;}
export interface TrendsProvider extends ReportingProvider {readonly normalization:'consistent'|'relative_0_100';}
export interface SocialMetricsProvider extends ReportingProvider {readonly supportsIntervalActivity:boolean;}
export interface AdsReportingProvider extends ReportingProvider {readonly currencySource:'account';}
export interface WebAnalyticsProvider extends ReportingProvider {readonly installsInstrumentation:false;}
export interface ManagementSystemProvider{
 readonly provider:string;
 testConnection(companyId:string):Promise<ProviderHealth>;
 listBusinessUnits(companyId:string):Promise<{id:string;name:string}[]>;
 syncCustomers(scope:ReportScope,cursor?:string):Promise<ReportPage>;
 syncSales(scope:ReportScope,cursor?:string):Promise<ReportPage>;
 syncPayments(scope:ReportScope,cursor?:string):Promise<ReportPage>;
 syncRefunds(scope:ReportScope,cursor?:string):Promise<ReportPage>;
 getSyncStatus(companyId:string):Promise<ProviderHealth>;
}
export class PendingManagementProvider implements ManagementSystemProvider{
 readonly provider='management_vendor_pending';
 async testConnection(_companyId:string):Promise<ProviderHealth>{return {state:'unconfigured',capabilities:['customers','sales','payments','refunds','webhooks'].map(operation=>({operation,supported:false,reason:'Fornecedor, unidade, credenciais e contrato de dados pendentes.'})),historicalStart:null,lastSuccess:null,reason:'Importação CSV auditada disponível separadamente.'};}
 async listBusinessUnits(_companyId:string):Promise<{id:string;name:string}[]>{throw new Error('MANAGEMENT_VENDOR_NOT_CONFIGURED');}
 async syncCustomers(_scope:ReportScope,_cursor?:string):Promise<ReportPage>{throw new Error('MANAGEMENT_VENDOR_NOT_CONFIGURED');}
 async syncSales(_scope:ReportScope,_cursor?:string):Promise<ReportPage>{throw new Error('MANAGEMENT_VENDOR_NOT_CONFIGURED');}
 async syncPayments(_scope:ReportScope,_cursor?:string):Promise<ReportPage>{throw new Error('MANAGEMENT_VENDOR_NOT_CONFIGURED');}
 async syncRefunds(_scope:ReportScope,_cursor?:string):Promise<ReportPage>{throw new Error('MANAGEMENT_VENDOR_NOT_CONFIGURED');}
 getSyncStatus(companyId:string){return this.testConnection(companyId);}
}
export class ReportError extends Error{constructor(readonly code:'revoked'|'rate_limited'|'provider_error'|'invalid_response',readonly retryAfterSeconds=0){super(code);}}
export interface ReportingSecurity {
 /** Must verify active company membership/role, connection ownership, resource mapping and revocation. */
 authorize(scope:ReportScope):Promise<void>;
 /** Must resolve encrypted credentials. Values must never be persisted in jobs or returned to the client. */
 credentials(connectionId:string):Promise<{accessToken:string;developerToken?:string;loginCustomerId?:string}>;
}
type Transport=typeof fetch;
function validScope(scope:ReportScope){if(!scope.companyId||!scope.connectionId||!/^\d{4}-\d{2}-\d{2}$/.test(scope.start)||!/^\d{4}-\d{2}-\d{2}$/.test(scope.end)||scope.start>scope.end)throw new Error('Invalid reporting scope');}
function object(value:unknown):Record<string,unknown>{if(!value||typeof value!=='object'||Array.isArray(value))throw new ReportError('invalid_response');return value as Record<string,unknown>;}
function list(value:unknown):unknown[]{if(!Array.isArray(value))throw new ReportError('invalid_response');return value;}
abstract class ReadAdapter implements ReportingProvider{
 abstract readonly provider:string;
 constructor(protected readonly security:ReportingSecurity,protected readonly transport:Transport=fetch){}
 abstract read(scope:ReportScope,cursor?:string):Promise<ReportPage>;
 protected async query(scope:ReportScope,url:string,body?:unknown,extraHeaders:Record<string,string>={}){
  validScope(scope);await this.security.authorize(scope);
  const token=await this.security.credentials(scope.connectionId);
  const response=await this.transport(url,{method:body===undefined?'GET':'POST',headers:{Authorization:'Bearer '+token.accessToken,'Content-Type':'application/json',...extraHeaders},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000),redirect:'error',cache:'no-store'});
  if(response.status===401||response.status===403)throw new ReportError('revoked');
  if(response.status===429)throw new ReportError('rate_limited',Math.min(3600,Math.max(1,Number(response.headers.get('retry-after'))||60)));
  if(!response.ok)throw new ReportError('provider_error');
  // Never return/log the provider error body: it may contain tokens or personal data.
  return object(await response.json());
 }
}
export class Ga4ReportingAdapter extends ReadAdapter implements WebAnalyticsProvider{
 readonly provider='ga4';readonly installsInstrumentation=false;
 async read(scope:ReportScope,cursor='0'):Promise<ReportPage>{
  if(!/^\d+$/.test(scope.resource)||!/^\d+$/.test(cursor))throw new Error('Invalid GA4 resource or cursor');
  const data=await this.query(scope,'https://analyticsdata.googleapis.com/v1beta/properties/'+scope.resource+':runReport',{dateRanges:[{startDate:scope.start,endDate:scope.end}],dimensions:[{name:'date'}],metrics:[{name:'sessions'},{name:'totalUsers'},{name:'keyEvents'}],limit:10000,offset:Number(cursor),orderBys:[{dimension:{dimensionName:'date'}}]});
  const rows=data.rows===undefined?[]:list(data.rows),total=Number(data.rowCount);
  if(!Number.isInteger(total)||total<0)throw new ReportError('invalid_response');
  const next=Number(cursor)+rows.length<total?String(Number(cursor)+rows.length):null;
  return {rows,cursor:next,temporal:'interval',coverage:'partial',limitations:['Fuso da propriedade deve coincidir com o da empresa. Usuários únicos não são somados por dia. Metadados de thresholding e retenção exigem homologação.']};
 }
}
export class SearchConsoleReportingAdapter extends ReadAdapter implements WebAnalyticsProvider{
 readonly provider='search_console';readonly installsInstrumentation=false;
 async read(scope:ReportScope,cursor='0'):Promise<ReportPage>{
  if(!/^\d+$/.test(cursor)||!/^https?:\/\/|^sc-domain:/.test(scope.resource))throw new Error('Invalid Search Console resource or cursor');
  const data=await this.query(scope,'https://www.googleapis.com/webmasters/v3/sites/'+encodeURIComponent(scope.resource)+'/searchAnalytics/query',{startDate:scope.start,endDate:scope.end,dimensions:['date','page'],rowLimit:25000,startRow:Number(cursor),dataState:'final'});
  const rows=data.rows===undefined?[]:list(data.rows);
  return {rows,cursor:rows.length===25000?String(Number(cursor)+25000):null,temporal:'interval',coverage:'partial',limitations:['Search Analytics pode retornar apenas as principais linhas. Datas seguem o fuso da fonte; não pressupor horário da empresa.']};
 }
}
export class GoogleAdsReportingAdapter extends ReadAdapter implements AdsReportingProvider{
 readonly provider='google_ads';readonly currencySource='account';
 constructor(security:ReportingSecurity,private readonly version:string,transport:Transport=fetch){super(security,transport);if(!/^v\d+$/.test(version))throw new Error('Configure a supported Google Ads API version');}
 async read(scope:ReportScope,cursor?:string):Promise<ReportPage>{
  validScope(scope);if(!/^\d+$/.test(scope.resource))throw new Error('Invalid Google Ads customer');
  await this.security.authorize(scope);const credentials=await this.security.credentials(scope.connectionId);
  if(!credentials.developerToken)throw new Error('Developer token required');
  const data=await this.query(scope,'https://googleads.googleapis.com/'+this.version+'/customers/'+scope.resource+'/googleAds:search',{query:"SELECT segments.date, customer.currency_code, customer.time_zone, campaign.id, campaign.name, metrics.cost_micros, metrics.impressions, metrics.clicks, metrics.conversions FROM campaign WHERE segments.date BETWEEN '"+scope.start+"' AND '"+scope.end+"' ORDER BY segments.date, campaign.id",...(cursor?{pageToken:cursor}:{})},{'developer-token':credentials.developerToken,...(credentials.loginCustomerId?{'login-customer-id':credentials.loginCustomerId}:{})});
  return {rows:data.results===undefined?[]:list(data.results),cursor:typeof data.nextPageToken==='string'?data.nextPageToken:null,temporal:'interval',coverage:'partial',limitations:['Conversões da plataforma não confirmam clientes. Micros monetários exigem conversão exata antes da persistência. Janela de atribuição exige leitura da configuração.']};
 }
}
export class MetaAdsReportingAdapter extends ReadAdapter implements AdsReportingProvider{
 readonly provider='meta_ads';readonly currencySource='account';
 constructor(security:ReportingSecurity,private readonly version:string,transport:Transport=fetch){super(security,transport);if(!/^v\d+\.\d+$/.test(version))throw new Error('Configure a supported Graph API version');}
 async read(scope:ReportScope,cursor?:string):Promise<ReportPage>{
  if(!/^\d+$/.test(scope.resource))throw new Error('Invalid Meta account');
  const params=new URLSearchParams({fields:'date_start,date_stop,account_id,account_currency,campaign_id,campaign_name,spend,impressions,clicks',level:'campaign',time_range:JSON.stringify({since:scope.start,until:scope.end}),time_increment:'1',action_report_time:'impression',limit:'500',...(cursor?{after:cursor}:{})});
  const data=await this.query(scope,'https://graph.facebook.com/'+this.version+'/act_'+scope.resource+'/insights?'+params);
  const paging=data.paging?object(data.paging):null,cursors=paging?.cursors?object(paging.cursors):null;
  return {rows:list(data.data),cursor:paging?.next&&typeof cursors?.after==='string'?cursors.after:null,temporal:'interval',coverage:'partial',limitations:['Cliques totais. Alcance não é somado. Fuso e atribuição da conta exigem leitura e validação antes do consolidado.']};
 }
}
export class InstagramMediaReportingAdapter extends ReadAdapter implements SocialMetricsProvider{
 readonly provider='instagram';readonly supportsIntervalActivity=false;
 constructor(security:ReportingSecurity,private readonly version:string,transport:Transport=fetch){super(security,transport);if(!/^v\d+\.\d+$/.test(version))throw new Error('Configure a supported Graph API version');}
 async read(scope:ReportScope,cursor?:string):Promise<ReportPage>{
  if(!/^\d+$/.test(scope.resource))throw new Error('Invalid Instagram professional account');
  const params=new URLSearchParams({fields:'id,caption,media_type,permalink,timestamp,like_count,comments_count',limit:'100',...(cursor?{after:cursor}:{})});
  const data=await this.query(scope,'https://graph.facebook.com/'+this.version+'/'+scope.resource+'/media?'+params);
  const paging=data.paging?object(data.paging):null,cursors=paging?.cursors?object(paging.cursors):null;
  return {rows:list(data.data),cursor:paging?.next&&typeof cursors?.after==='string'?cursors.after:null,temporal:'lifetime',coverage:'partial',limitations:['Somente modalidade Facebook Login vinculada a conta profissional. Publicação no período difere de atividade no período. Alcance, salvamentos, compartilhamentos e visualizações dependem de Insights homologado por formato; permanecem ausentes.']};
 }
}
