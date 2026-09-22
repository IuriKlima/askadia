import type { FinanceInputs,Metric } from './schema';
export const methodVersion='askadia-dashboard-v1';
export function safeSum(values:number[]){const n=values.reduce((a,b)=>a+b,0);if(!Number.isSafeInteger(n))throw new Error('Total fora da precisão permitida.');return n;}
export function calculateFinance(input:FinanceInputs,source='Sistema de gestão e custos',updatedAt:string|null=null):Metric[]{
 const total=input.mediaCents===null||input.otherAcquisitionCents===null?null:input.mediaCents+input.otherAcquisitionCents;
 const margin=input.attributedNetCents===null||input.variableCostCents===null?null:input.attributedNetCents-input.variableCostCents;
 const make=(id:string,label:string,value:number|null,unit:Metric['unit'],formula:string,bases:Metric['bases'],better:Metric['better']='higher',reason:string|null=null):Metric=>({id,label,value,unit,formula,bases,better,source,updatedAt,state:value===null?'no_basis':input.scopeComplete?'available':'partial',reason:value===null?reason??'Faltam bases compatíveis para calcular.':input.scopeComplete?null:'Cobertura parcial; resultado limitado à base informada.'});
 return [
  make('media','Investimento em mídia',input.mediaCents===null?null:input.mediaCents/100,'BRL','Soma do gasto de mídia no mesmo escopo',{mediaCents:input.mediaCents},'neutral'),
  make('customers','Novos clientes pagantes',input.newCustomers,'count','Clientes distintos com primeira aquisição e pagamento válido; histórico conhecido',{newCustomers:input.newCustomers}),
  make('revenue','Receita líquida atribuída',input.attributedNetCents===null?null:input.attributedNetCents/100,'BRL','Recebimentos líquidos elegíveis − estornos elegíveis',{netCents:input.attributedNetCents}),
  make('cac_media','CAC de mídia',input.mediaCents!==null&&input.mediaCustomers!==null&&input.mediaCustomers>0?input.mediaCents/input.mediaCustomers/100:null,'BRL','Investimento em mídia ÷ novos clientes atribuídos à mídia',{mediaCents:input.mediaCents,mediaCustomers:input.mediaCustomers},'lower','Falta investimento ou clientes atribuídos; denominador deve ser maior que zero.'),
  make('cac','CAC completo',total!==null&&input.newCustomers!==null&&input.newCustomers>0?total/input.newCustomers/100:null,'BRL','(Mídia + demais custos de aquisição) ÷ novos clientes pagantes',{mediaCents:input.mediaCents,otherAcquisitionCents:input.otherAcquisitionCents,newCustomers:input.newCustomers},'lower','Informe todos os custos de aquisição e clientes do mesmo escopo.'),
  make('roas','ROAS observado',input.mediaAttributedNetCents!==null&&input.mediaCents!==null&&input.mediaCents>0?input.mediaAttributedNetCents/input.mediaCents:null,'multiple','Receita líquida atribuída à mídia ÷ investimento em mídia',{mediaAttributedNetCents:input.mediaAttributedNetCents,mediaCents:input.mediaCents},'higher','Falta receita atribuída à mídia ou investimento maior que zero.'),
  make('margin','Margem atribuída',margin===null?null:margin/100,'BRL','Receita líquida atribuída − custos variáveis dessa receita',{attributedNetCents:input.attributedNetCents,variableCostCents:input.variableCostCents}),
  make('roi','ROI de marketing',margin!==null&&total!==null&&total>0?(margin-total)/total*100:null,'percent','(Margem de contribuição atribuída − custos de aquisição) ÷ custos de aquisição × 100',{marginCents:margin,acquisitionCents:total},'higher','Informe custos variáveis, aquisição completa e receita atribuída compatível.'),
 ];
}
export function compareMetric(current:Metric,previous:Metric){
 if(current.value===null||previous.value===null)return {percent:null,label:'Sem histórico comparável',direction:'neutral'};
 if(previous.value===0)return {percent:null,label:'Sem base para variação percentual',direction:'neutral'};
 const percent=(current.value-previous.value)/Math.abs(previous.value)*100;
 return {percent,label:percent.toLocaleString('pt-BR',{maximumFractionDigits:1})+'%',direction:percent===0||current.better==='neutral'?'neutral':(percent>0)===(current.better==='higher')?'better':'worse'};
}
export function aggregateAds(rows:{spendCents:number;impressions:number;clicks:number;clickType:string;currency:string;timezone:string;dateBasis:string}[]){
 const mixed=(key:'clickType'|'currency'|'timezone'|'dateBasis')=>new Set(rows.map(r=>r[key])).size>1;
 if(mixed('currency')||mixed('timezone')||mixed('dateBasis'))throw new Error('Contas com moeda, fuso ou data-base incompatíveis devem ser apresentadas separadamente.');
 const spendCents=safeSum(rows.map(r=>r.spendCents)),impressions=safeSum(rows.map(r=>r.impressions));
 const clicks=mixed('clickType')?null:safeSum(rows.map(r=>r.clicks));
 return {spendCents,impressions,clicks,ctr:clicks!==null&&impressions>0?clicks/impressions*100:null,cpc:clicks!==null&&clicks>0?spendCents/clicks/100:null,cpm:impressions>0?spendCents/impressions*1000/100:null};
}
export function engagement(interactions:(number|null)[],reach:number|null){
 if(reach===null||reach<=0||interactions.some(v=>v===null))return null;
 return interactions.reduce<number>((a,b)=>a+(b??0),0)/reach*100;
}
export function csvCell(value:unknown){const text=String(value??'');return '"'+(/^[\s]*[=+@-]/.test(text)?"'"+text:text).replaceAll('"','""')+'"';}
