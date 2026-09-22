import type { TrendFact } from './schema';
export function keywordCandidates(profile:{segment:string;city:string;neighborhood?:string;services:string[];confirmed:boolean}){
 if(!profile.confirmed)return [];
 const services=new Set(profile.services.map(s=>s.toLowerCase()));const place=profile.city.trim();if(!place)return [];
 const type=profile.segment==='studio'?'estúdio':profile.segment==='gym'?'academia':profile.segment;
 const candidates=[type+' perto de mim',type+' em '+place,'preço de '+type,'planos de '+type,'aula experimental de '+type,type+' para iniciantes',type+' horários',type+' avaliações',type+' mensalidade',type+' matrícula',type+' planos mensais',type+' planos anuais',type+' telefone',type+' endereço',type+' localização',type+' atendimento',type+' estrutura',type+' em '+place+' preços',type+' em '+place+' horários',type+' em '+place+' avaliações'];
 if(profile.neighborhood?.trim())candidates.push(type+' em '+profile.neighborhood.trim());
 for(const [service,terms] of Object.entries({musculação:['musculação','musculação para iniciantes','treino para hipertrofia','musculação em '+place],pilates:['pilates perto de mim','estúdio de pilates','pilates em '+place],funcional:['treinamento funcional','treinamento funcional em '+place],spinning:['aula de spinning','spinning em '+place],dança:['aula de dança fitness'],personal:['personal trainer','personal trainer em '+place],'24 horas':['academia 24 horas'],totalpass:['academia com TotalPass'],wellhub:['academia com Wellhub']})){
   if(services.has(service))candidates.unshift(...terms);
 }
 return [...new Set(candidates)].slice(0,20).map((term,index)=>({term,priority:index+1,measured:false as const,reason:'Sugestão editorial baseada no perfil confirmado; pesquisa pendente.'}));
}
export function trendGroups(rows:TrendFact[]){
 const groups=new Map<string,TrendFact[]>();
 for(const row of rows){const key=[row.batchId,row.scale,row.region,row.searchType,row.language].join('|');groups.set(key,[...(groups.get(key)??[]),row]);}
 return [...groups.entries()].map(([key,items])=>{
  const terms=new Map<string,TrendFact[]>();for(const row of items)terms.set(row.termType+':'+row.term,[...(terms.get(row.termType+':'+row.term)??[]),row]);
  const dates=[...new Set(items.map(i=>i.date))].sort().join(',');
  const ranking=[...terms.values()].map(points=>{const valid=points.filter(p=>p.value!==null&&p.coverage==='sufficient');return {term:points[0]!.term,termType:points[0]!.termType,interest:valid.length===points.length&&points.map(p=>p.date).sort().join(',')===dates?valid.reduce((a,b)=>a+b.value!,0)/valid.length:null,points};}).sort((a,b)=>(b.interest??-1)-(a.interest??-1));
  return {key,batchId:items[0]!.batchId,region:items[0]!.region,scale:items[0]!.scale,ranking};
 });
}
