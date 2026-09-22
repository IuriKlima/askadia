import { createHash } from 'node:crypto';
import type { DashboardSnapshot } from './engine';
export function diagnosisInput(snapshot:DashboardSnapshot){
 // No customer IDs, payment IDs, names, email addresses or access tokens leave this boundary.
 const input={methodVersion:snapshot.methodVersion,filters:{...snapshot.filters,access:undefined},metrics:snapshot.metrics,sources:snapshot.sources.map(s=>({source:s.source,domain:s.domain,start:s.start,end:s.end,complete:s.complete,updatedAt:s.updatedAt})),limitations:snapshot.limitations,financialNote:snapshot.financialNote,funnelNote:snapshot.funnelNote,attributionCoverage:snapshot.attributionCoverage};
 return {input,key:createHash('sha256').update(JSON.stringify(input)).digest('hex')};
}
export type DashboardDiagnosis={status:'pending_configuration'|'available';snapshotKey:string;summary:string|null;limitations:string[];actions:{label:string;evidenceMetricIds:string[];destination:string}[]};
export interface DashboardDiagnosisProvider{interpret(input:ReturnType<typeof diagnosisInput>['input']):Promise<Omit<DashboardDiagnosis,'snapshotKey'>>;}
export function pendingDiagnosis(snapshot:DashboardSnapshot):DashboardDiagnosis{return {status:'pending_configuration',snapshotKey:diagnosisInput(snapshot).key,summary:null,limitations:['Serviço de análise e armazenamento de cache ainda não configurados para este dashboard.'],actions:[]};}
