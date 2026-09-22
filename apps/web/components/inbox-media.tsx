'use client';
import {useEffect,useRef,useState} from 'react';
import {Download,FileText,Headphones,Image as ImageIcon} from 'lucide-react';
import {Button} from '@askadia/ui';
import {journeyApi} from '../lib/journey-api';
import s from './inbox.module.css';
export function InboxMedia({base,thread,messageId,kind}:{base:string;thread:string;messageId:string;kind:string}){
 const [media,setMedia]=useState<{url:string;fileName:string;mimetype:string}|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState('');const request=useRef<AbortController|null>(null),url=useRef<string|null>(null);
 useEffect(()=>()=>{request.current?.abort();if(url.current)URL.revokeObjectURL(url.current);},[]);
 if(!['imageMessage','audioMessage','documentMessage'].includes(kind))return <small>Este tipo de mensagem pode ser consultado no WhatsApp.</small>;
 async function load(){if(busy)return;setBusy(true);setError('');const c=new AbortController();request.current=c;try{const r=await journeyApi<{base64:string;fileName:string;mimetype:string}>(base+'/media?thread='+encodeURIComponent(thread)+'&messageId='+encodeURIComponent(messageId),undefined,c.signal);if(c.signal.aborted)return;const decoded=atob(r.base64),bytes=new Uint8Array(decoded.length);for(let i=0;i<decoded.length;i++)bytes[i]=decoded.charCodeAt(i);url.current=URL.createObjectURL(new Blob([bytes],{type:r.mimetype}));setMedia({url:url.current,fileName:r.fileName,mimetype:r.mimetype});}catch(e){if(!c.signal.aborted)setError(e instanceof Error?e.message:'Arquivo indisponível.');}finally{if(!c.signal.aborted)setBusy(false);}}
 return <div className={s.media}>{!media?<Button size="small" variant="outline" disabled={busy} onClick={()=>void load()}>{kind==='imageMessage'?<ImageIcon size={15}/>:kind==='audioMessage'?<Headphones size={15}/>:<FileText size={15}/>} {busy?'Carregando…':kind==='imageMessage'?'Ver imagem':kind==='audioMessage'?'Carregar áudio':'Abrir documento'}</Button>:<>{media.mimetype.startsWith('image/')&&<a href={media.url} target="_blank" rel="noreferrer"><img src={media.url} alt="Imagem enviada nesta conversa"/></a>}{media.mimetype.startsWith('audio/')&&<audio controls preload="metadata" src={media.url}>Seu navegador não reproduz este áudio. Use o download.</audio>}{kind==='documentMessage'&&<a href={media.url} target="_blank" rel="noreferrer">Abrir {media.fileName}</a>}<a href={media.url} download={media.fileName}><Download size={13}/>Baixar {media.fileName}</a></>}{error&&<p role="alert">{error}</p>}</div>;
}
