import type { DashboardQuery } from './schema';
export function dateInZone(value:Date,timezone:string){
 const p=new Intl.DateTimeFormat('en-CA',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(value);
 return ['year','month','day'].map(k=>p.find(v=>v.type===k)!.value).join('-');
}
export function shiftDay(day:string,days:number){const d=new Date(day+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10);}
export function countDays(start:string,end:string){return Math.round((Date.parse(end)-Date.parse(start))/86400000)+1;}
export function presetPeriod(preset:string,today:string){
 const startMonth=today.slice(0,8)+'01';
 if(preset==='today')return {start:today,end:today};
 if(preset==='yesterday')return {start:shiftDay(today,-1),end:shiftDay(today,-1)};
 if(preset==='month')return {start:startMonth,end:today};
 if(preset==='last_month'){const end=shiftDay(startMonth,-1);return {start:end.slice(0,8)+'01',end};}
 const days=preset==='7'?7:preset==='90'?90:30;return {start:shiftDay(today,1-days),end:today};
}
export function comparisonPeriod(query:Pick<DashboardQuery,'start'|'end'|'comparison'>){
 if(query.comparison==='none')return null;
 if(query.comparison==='previous')return {start:shiftDay(query.start,-countDays(query.start,query.end)),end:shiftDay(query.start,-1)};
 const year=(day:string)=>{const [y,m,d]=day.split('-').map(Number);const last=new Date(Date.UTC(y!-1,m!,0)).getUTCDate();return String(y!-1)+'-'+String(m).padStart(2,'0')+'-'+String(Math.min(d!,last)).padStart(2,'0');};
 return {start:year(query.start),end:year(query.end)};
}
export function within(day:string,start:string,end:string){return day>=start&&day<=end;}
export function requestKey(q:DashboardQuery){return JSON.stringify(Object.entries(q).sort(([a],[b])=>a.localeCompare(b)));}
export class LatestRequest {
 private version=0;private controller:AbortController|null=null;
 begin(){this.controller?.abort();const version=++this.version;this.controller=new AbortController();return {signal:this.controller.signal,current:()=>version===this.version&&!this.controller!.signal.aborted};}
 cancel(){this.version++;this.controller?.abort();}
}
