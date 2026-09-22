import {BadRequestException,ServiceUnavailableException} from '@nestjs/common';
import {createHash} from 'node:crypto';
import {evolutionRequest} from '../onboarding/channels';
import {record} from './evolution';
export const MAX_INBOX_MEDIA=8*1024*1024;
const mimeExtensions:Record<string,string[]>={
 'image/jpeg':['jpg','jpeg'],'image/png':['png'],'image/webp':['webp'],'image/gif':['gif'],
 'audio/mpeg':['mp3'],'audio/ogg':['ogg','oga','opus'],'audio/wav':['wav'],'audio/x-wav':['wav'],'audio/mp4':['m4a','mp4'],'audio/webm':['webm'],
 'application/pdf':['pdf'],'text/plain':['txt'],'text/csv':['csv'],
 'application/msword':['doc'],'application/vnd.ms-excel':['xls'],
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':['docx'],
 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':['xlsx'],
 'application/vnd.openxmlformats-officedocument.presentationml.presentation':['pptx'],
};
export function validateMedia(input:{base64:string;mimetype:string;fileName:string}){
 const mime=input.mimetype.split(';')[0]!.trim().toLowerCase(),ext=input.fileName.split('.').at(-1)?.toLowerCase();
 if(!mimeExtensions[mime]||!ext||!mimeExtensions[mime]!.includes(ext))throw new BadRequestException('Formato não permitido. Use imagem JPG, PNG, WebP, GIF, áudio MP3, OGG, WAV, M4A, WebM ou documento PDF, Office, TXT ou CSV.');
 if(!input.base64||input.base64.length>Math.ceil(MAX_INBOX_MEDIA/3)*4||(input.base64.length%4!==0||!/^[A-Za-z0-9+/]*={0,2}$/.test(input.base64)))throw new BadRequestException('Arquivo inválido ou acima de 8 MB.');
 const bytes=Buffer.from(input.base64,'base64');if(!bytes.length||bytes.length>MAX_INBOX_MEDIA)throw new BadRequestException('Arquivo inválido ou acima de 8 MB.');
 const head=bytes.subarray(0,16),ascii=head.toString('latin1');let valid=false;
 if(mime==='image/jpeg')valid=head[0]===255&&head[1]===216&&head[2]===255;
 else if(mime==='image/png')valid=head.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
 else if(mime==='image/webp')valid=ascii.startsWith('RIFF')&&ascii.slice(8,12)==='WEBP';
 else if(mime==='image/gif')valid=/^GIF8[79]a/.test(ascii);
 else if(mime==='application/pdf')valid=ascii.startsWith('%PDF-');
 else if(mime==='audio/mpeg')valid=ascii.startsWith('ID3')||(head[0]===255&&((head[1]??0)&224)===224);
 else if(mime==='audio/ogg')valid=ascii.startsWith('OggS');
 else if(mime==='audio/wav'||mime==='audio/x-wav')valid=ascii.startsWith('RIFF')&&ascii.slice(8,12)==='WAVE';
 else if(mime==='audio/mp4')valid=ascii.slice(4,8)==='ftyp';
 else if(mime==='audio/webm')valid=head.subarray(0,4).equals(Buffer.from([26,69,223,163]));
 else if(mime.includes('openxmlformats'))valid=head.subarray(0,4).equals(Buffer.from([80,75,3,4]));
 else if(mime==='application/msword'||mime==='application/vnd.ms-excel')valid=head.subarray(0,8).equals(Buffer.from([208,207,17,224,161,177,26,225]));
 else if(mime.startsWith('text/'))valid=!bytes.includes(0)&&!/^\s*(<!doctype html|<html|<script|<svg)/i.test(bytes.subarray(0,1024).toString());
 if(!valid)throw new BadRequestException('O conteúdo do arquivo não corresponde ao formato informado.');
 const fileName=input.fileName.replace(/[^\p{L}\p{N}._ -]/gu,'_').slice(0,150);
 return {base64:input.base64,mimetype:mime,fileName,kind:mime.startsWith('image/')?'image':mime.startsWith('audio/')?'audio':'document',hash:createHash('sha256').update(bytes).digest('hex')};
}
export async function evolutionMedia(instance:string,jid:string,messageId:string){
 const found=await evolutionRequest('/chat/findMessages/'+encodeURIComponent(instance),{where:{key:{remoteJid:jid,id:messageId}},page:1,offset:1});
 const rows=record(found.messages).records;const message=Array.isArray(rows)?rows.map(record).find(m=>record(m.key).remoteJid===jid&&record(m.key).id===messageId):undefined;
 if(!message)throw new BadRequestException('Arquivo não encontrado nesta conversa.');
 let content=record(message.message);for(let i=0;i<3;i++){if(content.viewOnceMessage||content.viewOnceMessageV2)throw new BadRequestException('Mídia de visualização única deve ser aberta no WhatsApp.');if(!content.ephemeralMessage)break;content=record(record(content.ephemeralMessage).message);}
 const metadata=record(content.imageMessage??content.audioMessage??content.documentMessage??record(record(content.documentWithCaptionMessage).message).documentMessage);
 if(!Object.keys(metadata).length)throw new BadRequestException('Esta mensagem não contém imagem, áudio ou documento disponível.');
 if(Number(metadata.fileLength)>MAX_INBOX_MEDIA)throw new BadRequestException('Este arquivo ultrapassa 8 MB. Abra-o no WhatsApp.');
 try{const media=await evolutionRequest('/chat/getBase64FromMediaMessage/'+encodeURIComponent(instance),{message:{key:message.key,message:message.message},convertToMp4:false},{timeout:45000,maxBytes:12*1024*1024});
 const validated=validateMedia({base64:typeof media.base64==='string'?media.base64:'',mimetype:String(media.mimetype??''),fileName:String(media.fileName??'arquivo')});return {base64:validated.base64,mimetype:validated.mimetype,fileName:validated.fileName};
 }catch(e){if(e instanceof BadRequestException)throw e;throw new ServiceUnavailableException('O arquivo não está disponível na Evolution agora. Ele pode ter expirado; tente abrir no WhatsApp.');}
}
