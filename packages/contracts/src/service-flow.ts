import {z} from 'zod';
const identifier=z.string().regex(/^[a-zA-Z0-9_-]{1,64}$/);
export const serviceFlowSchema=z.object({version:z.literal(1),nodes:z.array(z.object({id:identifier,kind:z.enum(['start','condition','message','handoff']),label:z.string().max(80),text:z.string().max(2000),position:z.object({x:z.number().finite().min(-10000).max(10000),y:z.number().finite().min(-10000).max(10000)}).strict()}).strict()).min(2).max(50),edges:z.array(z.object({id:identifier,source:identifier,target:identifier,port:z.enum(['next','yes','no'])}).strict()).max(100)}).strict().superRefine((graph,ctx)=>{
 const fail=(message:string)=>ctx.addIssue({code:'custom',message});
 const ids=new Set(graph.nodes.map(n=>n.id));
 if(ids.size!==graph.nodes.length||new Set(graph.edges.map(e=>e.id)).size!==graph.edges.length)fail('Existem identificadores repetidos.');
 const starts=graph.nodes.filter(n=>n.kind==='start');if(starts.length!==1)fail('O fluxo precisa de um único início.');
 for(const edge of graph.edges)if(!ids.has(edge.source)||!ids.has(edge.target)||graph.nodes.find(n=>n.id===edge.target)?.kind==='start')fail('Uma conexão aponta para um bloco inválido.');
 for(const node of graph.nodes){const out=graph.edges.filter(e=>e.source===node.id);const ports=out.map(e=>e.port);
  if(new Set(ports).size!==ports.length)fail('Cada saída pode ter apenas uma conexão.');
  if(node.kind==='condition'&&(ports.length!==2||!ports.includes('yes')||!ports.includes('no')))fail('Conecte as saídas Sim e Não de cada condição.');
  if(node.kind==='start'&&(ports.length!==1||ports[0]!=='next'))fail('Conecte o bloco de início.');
  if(node.kind==='handoff'&&out.length)fail('O encaminhamento encerra o fluxo.');
  if(node.kind==='message'&&(ports.length>1||ports.some(p=>p!=='next')))fail('A mensagem permite uma única saída.');
  if(node.kind!=='start'&&!node.text.trim())fail('Preencha o texto dos blocos.');
  if(node.kind==='condition'&&node.text.length>120)fail('A condição aceita até 120 caracteres.');
 }
 const visiting=new Set<string>(),visited=new Set<string>();let cycle=false;
 function visit(id:string){if(visiting.has(id)){cycle=true;return;}if(visited.has(id))return;visiting.add(id);for(const e of graph.edges.filter(e=>e.source===id))visit(e.target);visiting.delete(id);visited.add(id);}
 if(starts[0])visit(starts[0].id);if(cycle)fail('Remova o ciclo: o fluxo deve chegar a uma resposta ou encaminhamento.');if(visited.size!==graph.nodes.length)fail('Conecte todos os blocos ao início.');
 // Bound combined text before it reaches a provider.
 if(graph.nodes.filter(n=>n.kind!=='condition').reduce((sum,n)=>sum+n.text.length,0)>6000)fail('As mensagens do fluxo devem somar até 6.000 caracteres.');
});
export type ServiceFlow=z.infer<typeof serviceFlowSchema>;
export function runServiceFlow(graph:ServiceFlow,text:string){
 const checked=serviceFlowSchema.safeParse(graph);if(!checked.success)throw new Error(checked.error.issues[0]?.message??'Fluxo inválido.');
 const normalize=(v:string)=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
 let node=graph.nodes.find(n=>n.kind==='start');const parts:string[]=[];let handoff=false;
 for(let step=0;node&&step<50;step++){
  if(node.kind==='message'||node.kind==='handoff')parts.push(node.text.trim());
  if(node.kind==='handoff'){handoff=true;break;}
  const port=node.kind==='condition'?(normalize(text).includes(normalize(node.text.trim()))?'yes':'no'):'next';
  const next=graph.edges.find(e=>e.source===node?.id&&e.port===port);node=next?graph.nodes.find(n=>n.id===next.target):undefined;
 }
 return {text:parts.join('\n\n'),handoff};
}
export function flowFromRules(rules:{match:string;reply:string;handoff:boolean}[],fallback:string):ServiceFlow{
 const nodes:ServiceFlow['nodes']=[{id:'start',kind:'start',label:'Mensagem recebida',text:'',position:{x:40,y:160}}];const edges:ServiceFlow['edges']=[];
 const connect=(source:string,target:string,port:'next'|'yes'|'no')=>edges.push({id:source+'_'+port,source,target,port});
 if(!rules.length){nodes.push({id:'reply',kind:'message',label:'Boas-vindas',text:'Olá! Como podemos ajudar?',position:{x:350,y:160}});connect('start','reply','next');return {version:1,nodes,edges};}
 rules.forEach((rule,i)=>{nodes.push({id:'rule'+i,kind:'condition',label:'Opção '+(i+1),text:rule.match,position:{x:340+i*310,y:160}},{id:'reply'+i,kind:rule.handoff?'handoff':'message',label:rule.handoff?'Encaminhar à equipe':'Responder',text:rule.reply,position:{x:340+i*310,y:410}});connect('rule'+i,'reply'+i,'yes');connect('rule'+i,i===rules.length-1?'fallback':'rule'+(i+1),'no');});
 connect('start','rule0','next');nodes.push({id:'fallback',kind:'handoff',label:'Outros assuntos',text:fallback||'Vou encaminhar sua mensagem para nossa equipe.',position:{x:340+rules.length*310,y:160}});return {version:1,nodes,edges};
}
