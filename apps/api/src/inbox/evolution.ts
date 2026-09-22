import {ServiceUnavailableException} from '@nestjs/common';
import type {InboxMessage,InboxThread} from '@askadia/contracts';
import {evolutionRequest} from '../onboarding/channels';
type RecordValue=Record<string,unknown>;
export const record=(v:unknown):RecordValue=>v&&typeof v==='object'&&!Array.isArray(v)?v as RecordValue:{};
const string=(v:unknown)=>typeof v==='string'?v:'';
export const validJid=(s:string)=>/^\d{6,20}@(s\.whatsapp\.net|lid|g\.us)$/.test(s);
export function messageText(value:unknown):{body:string;kind:string}{
 let m=record(value);for(let i=0;i<3;i++){const wrapped=record(m.ephemeralMessage??m.viewOnceMessage??m.viewOnceMessageV2??m.documentWithCaptionMessage);if(!wrapped.message)break;m=record(wrapped.message);}
 if(typeof m.conversation==='string')return {body:m.conversation.slice(0,6000),kind:'text'};
 const extended=record(m.extendedTextMessage);if(typeof extended.text==='string')return {body:extended.text.slice(0,6000),kind:'text'};
 for(const [field,label] of [['imageMessage','Imagem'],['videoMessage','Vídeo'],['audioMessage','Áudio'],['documentMessage','Documento'],['stickerMessage','Figurinha'],['contactMessage','Contato'],['locationMessage','Localização']]){if(m[field!]){const media=record(m[field!]);return {body:('['+label+'] '+string(media.caption||media.fileName)).trim().slice(0,6000),kind:field!};}}
 return {body:'[Mensagem não textual — consulte no WhatsApp]',kind:'unsupported'};
}
function timestamp(value:unknown){const n=typeof value==='number'?value:Number(value);if(!Number.isFinite(n)||n<=0)return null;const d=new Date(n<1e12?n*1000:n);return Number.isNaN(d.getTime())?null:d.toISOString();}
export function normalizeMessage(raw:unknown):InboxMessage|null{const m=record(raw),key=record(m.key);const id=string(key.id);if(!id)return null;return {id,...messageText(m.message),fromMe:key.fromMe===true,time:timestamp(m.messageTimestamp),status:string(m.status)||string(record(Array.isArray(m.MessageUpdate)?m.MessageUpdate[0]:null).status)||'received'};}
export function normalizeChats(raw:unknown):InboxThread[]{if(!Array.isArray(raw))throw new ServiceUnavailableException('A Evolution retornou um histórico inválido.');const seen=new Set<string>();return raw.flatMap(v=>{const c=record(v),jid=string(c.remoteJid);if(!validJid(jid)||seen.has(jid))return [];seen.add(jid);const last=normalizeMessage(c.lastMessage);return [{id:Buffer.from(jid).toString('base64url'),channel:'whatsapp' as const,name:(string(c.pushName)||(record(record(c.lastMessage).key).fromMe!==true?string(record(c.lastMessage).pushName):'')||jid.split('@')[0]!).slice(0,150),preview:last?.body??'Sem mensagem disponível',time:last?.time??null,unread:Math.max(0,Number(c.unreadCount)||0),group:jid.endsWith('@g.us')}];}).sort((a,b)=>(b.time??'').localeCompare(a.time??''));}
export function decodeThread(id:string){if(!/^[A-Za-z0-9_-]{1,160}$/.test(id))throw new Error('Invalid thread');const jid=Buffer.from(id,'base64url').toString('utf8');if(!validJid(jid)||Buffer.from(jid).toString('base64url')!==id)throw new Error('Invalid thread');return jid;}
export async function evolutionChats(instance:string){return normalizeChats(await evolutionRequest('/chat/findChats/'+encodeURIComponent(instance),{}));}
export async function evolutionMessages(instance:string,jid:string,page:number){const raw=await evolutionRequest('/chat/findMessages/'+encodeURIComponent(instance),{where:{key:{remoteJid:jid}},page,offset:50});const collection=record(raw.messages);if(!Array.isArray(collection.records))throw new ServiceUnavailableException('A Evolution não retornou o histórico desta conversa.');const messages=collection.records.flatMap(v=>{const key=record(record(v).key);if(key.remoteJid!==jid)return [];const m=normalizeMessage(v);return m?[m]:[];});return {messages:messages.sort((a,b)=>(a.time??'').localeCompare(b.time??'')),hasMore:page<(Number(collection.pages)||1),totalPages:Math.max(1,Math.min(10000,Math.trunc(Number(collection.pages)||1)))};}
