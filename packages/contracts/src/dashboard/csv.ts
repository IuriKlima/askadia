import { importSchema,trendFactSchema,type DashboardImport,type TrendFact } from './schema';
export function parseCsv(text:string):string[][]{
 if(text.length>1500000)throw new Error('CSV excede 1,5 MB.');
 const firstLine=text.split(/\r?\n/).find(line=>line.includes(',')||line.includes(';'))??'';
 const delimiter=firstLine.split(';').length>firstLine.split(',').length?';':',';
 const rows:string[][]=[];let row:string[]=[],cell='',quoted=false;
 for(let i=0;i<text.length;i++){
  const c=text[i]!;
  if(c==='"'){if(quoted&&text[i+1]==='"'){cell+='"';i++;}else quoted=!quoted;}
  else if(c===delimiter&&!quoted){row.push(cell);cell='';}
  else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);if(row.some(v=>v.trim()))rows.push(row);row=[];cell='';}
  else cell+=c;
 }
 if(quoted)throw new Error('Aspas não fechadas no CSV.');
 row.push(cell);if(row.some(v=>v.trim()))rows.push(row);
 if(rows.length>1002)throw new Error('Importe até 1.000 linhas por arquivo.');
 return rows;
}
const numericFields=new Set(['spendCents','impressions','clicks','reportedConversions','netCents','variableCostCents','cents','variableCostReversalCents','reach','likes','comments','saves','shares','views','value']);
const booleanFields=new Set(['customerHistoryKnown','customerPreexisting','estimated']);
export function parseDashboardCsv(text:string,metadata:Omit<DashboardImport,'records'>){
 const rows=parseCsv(text);const headers=rows.shift()?.map(s=>s.replace(/^\uFEFF/,'').trim())??[];
 if(!headers.includes('kind')||!headers.includes('id')||!headers.includes('date'))throw new Error('Use o modelo CSV com kind, id e date.');
 if(new Set(headers).size!==headers.length)throw new Error('Colunas duplicadas.');
 const records=rows.map((row,index)=>{
  if(row.length!==headers.length)throw new Error('Quantidade de colunas inválida na linha '+(index+2));
  return Object.fromEntries(headers.map((key,i)=>{
   const v=row[i]!.trim();if(numericFields.has(key)){if(!v||v==='null')return [key,null];if(!/^-?\d+(\.\d+)?$/.test(v))throw new Error('Número inválido na linha '+(index+2));return [key,Number(v)];}
   if(booleanFields.has(key)){if(v!=='true'&&v!=='false')throw new Error('Use true ou false na linha '+(index+2));return [key,v==='true'];}
   return [key,['acquisitionDate','intervalStart','intervalEnd'].includes(key)&&!v?null:v];
  }));
 });
 const result=importSchema.safeParse({...metadata,records});if(!result.success)throw new Error('CSV inválido: '+result.error.issues.slice(0,3).map(i=>i.path.join('.')+': '+i.message).join('; '));
 return result.data;
}
export function parseTrendsCsv(text:string,meta:{batchId:string;region:string;collectedAt:string;sourceUrl:string;language:string;searchType:string;termType:'search_term'|'topic'}):TrendFact[]{
 const rows=parseCsv(text);const headerAt=rows.findIndex(r=>/^(Day|Week|Month|Dia|Semana|Mês)$/i.test(r[0]?.replace(/^\uFEFF/,'').trim()??''));
 if(headerAt<0)throw new Error('CSV de interesse ao longo do tempo não reconhecido. Exporte uma série temporal do Google Trends.');
 const header=rows[headerAt]!,result:TrendFact[]=[];
 const regions=header.slice(1).map(h=>h.match(/: \(([^)]+)\)$/)?.[1]?.trim());
 if(regions.some(region=>!region||region.toLocaleLowerCase()!==meta.region.trim().toLocaleLowerCase()))throw new Error('A região declarada deve ser idêntica à região no cabeçalho do CSV. Não converta cobertura nacional em local.');
 for(const row of rows.slice(headerAt+1)){
  if(row.length!==header.length)throw new Error('Colunas incompatíveis no CSV Trends.');
  for(let i=1;i<header.length;i++){
   const term=header[i]!.trim().replace(/: \([^)]*\)$/,'');
   const raw=row[i]!.trim();const sufficient=/^\d+(\.\d+)?$/.test(raw);
   result.push(trendFactSchema.parse({kind:'trend',id:meta.batchId+':'+i+':'+row[0],date:row[0],term,termType:meta.termType,region:meta.region,language:meta.language,searchType:meta.searchType,batchId:meta.batchId,scale:'relative_0_100',value:sufficient?Number(raw):null,coverage:sufficient?'sufficient':'insufficient',sourceUrl:meta.sourceUrl,collectedAt:meta.collectedAt}));
  }
 }
 if(result.length>1000)throw new Error('A importação excede 1.000 pontos; divida por períodos sem misturar escalas.');
 return result;
}
