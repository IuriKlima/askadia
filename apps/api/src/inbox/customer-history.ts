import type {InboxMessage} from '@askadia/contracts';

/** A received burst is answered by the first following outgoing message. */
export function conversationMetrics(input:InboxMessage[]){
 const messages=[...new Map(input.map(m=>[m.id,m])).values()].filter(m=>m.time&&Number.isFinite(Date.parse(m.time))).sort((a,b)=>Date.parse(a.time!)-Date.parse(b.time!));
 let waiting:number|null=null;const durations:number[]=[];
 for(const m of messages){const time=Date.parse(m.time!);if(!m.fromMe){waiting??=time;}else if(waiting!==null){durations.push(time-waiting);waiting=null;}}
 return {firstAvailableAt:messages[0]?.time??null,firstResponseMs:durations[0]??null,averageResponseMs:durations.length?Math.round(durations.reduce((a,b)=>a+b,0)/durations.length):null,responseCount:durations.length,awaitingSince:waiting===null?null:new Date(waiting).toISOString(),lastInbound:messages.filter(m=>!m.fromMe).at(-1)??null,lastOutbound:messages.filter(m=>m.fromMe).at(-1)??null};
}
