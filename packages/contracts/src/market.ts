import {z} from 'zod';
import type {PlaceSearchResult} from './onboarding';
export const marketQuerySchema=z.object({radius:z.coerce.number().pipe(z.union([z.literal(1000),z.literal(3000),z.literal(5000),z.literal(10000)])).default(3000)}).strict();
export type SourceState='available'|'unconfigured'|'unavailable'|'pending'|'forbidden';
export type Demographics={municipalityId:string;municipality:string;uf:string;year:string;population:number|null;areaKm2:number|null;density:number|null;collectedAt:string;sourceUrl:string};
export type SearchRanking={term:string;interest:number};
export type MarketSnapshot={
 companyId:string;profileVersion:number;collectedAt:string|null;radius:number;
 demographics:{state:SourceState;data:Demographics|null;message:string};
 competitors:{state:SourceState;search:PlaceSearchResult|null;count:number|null;limited:boolean;message:string};
 facebook:{state:SourceState;count:number|null;places:{id:string;name:string;url:string;distance:number}[];message:string};
 trends:{state:SourceState;rows:SearchRanking[];region:string|null;geo:string|null;query:string;period:string;sourceUrl:string;collectedAt:string|null;message:string};
};
export type BusinessOverview={companyId:string;generatedAt:string;days:number;start:string;end:string;timezone:string;crm:null|{totalContacts:number;newContacts:number;stages:{key:string;label:string;count:number}[];daily:{date:string;count:number}[]};campaigns:null|{active:number;sent:number;uncertain:number;students:number};failures:string[]};
export function distanceMeters(a:{latitude:number;longitude:number},b:{latitude:number;longitude:number}){const r=(x:number)=>x*Math.PI/180;const h=Math.sin(r(b.latitude-a.latitude)/2)**2+Math.cos(r(a.latitude))*Math.cos(r(b.latitude))*Math.sin(r(b.longitude-a.longitude)/2)**2;return 6371000*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)));}
/** First instant of a local date, including DST transitions; never assume UTC or a fixed offset. */
export function utcStartOfDay(day:string,timezone:string){const f=new Intl.DateTimeFormat('en-CA',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit'});const date=(ms:number)=>{const p=f.formatToParts(new Date(ms));return ['year','month','day'].map(k=>p.find(v=>v.type===k)!.value).join('-');};const noon=Date.parse(day+'T12:00:00Z');let lo=noon-2*86400000,hi=noon+2*86400000;while(lo<hi){const mid=Math.floor((lo+hi)/2);if(date(mid)<day)lo=mid+1;else hi=mid;}return new Date(lo).toISOString();}
