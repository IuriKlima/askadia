export function currentCalendarDate(now=new Date()){
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now);
 const part=(type:string)=>parts.find(p=>p.type===type)!.value;
 return `${part('year')}-${part('month')}-${part('day')}`;
}
export function calendarMonth(value:string|null|undefined){return value&&/^\d{4}-(0[1-9]|1[0-2])$/.test(value)&&Number(value.slice(0,4))>=2000&&Number(value.slice(0,4))<=2100?value:null;}
export function shiftCalendarMonth(month:string,amount:number){const [year,m]=month.split('-').map(Number);const d=new Date(Date.UTC(year!,m!-1+amount,1));return d.toISOString().slice(0,7);}
