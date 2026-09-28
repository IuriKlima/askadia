import {readApiResponse} from './response';
export const finalVideoMaxBytes=50*1024*1024;
export function finalVideoError(file:Pick<File,'size'|'type'|'name'>){
 if(!file.size)return 'O arquivo está vazio. Escolha um vídeo MP4.';
 if(file.size>finalVideoMaxBytes)return 'Use um vídeo MP4 de até 50 MB.';
 if(file.type!=='video/mp4'&&!(file.name.toLowerCase().endsWith('.mp4')&&['','application/octet-stream'].includes(file.type)))return 'Escolha um arquivo MP4. Converta o vídeo para esse formato antes de enviar.';
 return null;
}
export function videoUploadBlock({write,current,details}:{write:boolean;current:boolean;details:boolean}){
 if(!write)return 'Seu perfil não permite enviar vídeos. Peça acesso ao responsável pela empresa.';
 if(!current)return 'Aprove a estratégia atual para enviar o vídeo desta publicação.';
 if(!details)return 'Aguarde a preparação do texto e do roteiro desta publicação.';
 return null;
}
export async function uploadPublicationVideo({companyId,itemId,revision,file,uploadId}:{companyId:string;itemId:string;revision:number;file:File;uploadId:string}){
 const invalid=finalVideoError(file);if(invalid)throw new Error(invalid);
 const response=await fetch('/api/onboarding/companies/'+companyId+'/calendar/video/'+itemId+'/'+uploadId,{method:'POST',headers:{'Content-Type':'video/mp4','X-File-Name':encodeURIComponent(file.name),'X-Revision':String(revision)},body:file});
 if(response.status===401){window.location.assign('/login');throw new Error('Sua sessão expirou. Entre novamente para enviar o vídeo.');}
 if(response.status===409)throw new Error('A publicação mudou durante o envio. Atualize a página e confira a nova versão antes de tentar novamente.');
 return readApiResponse(response);
}
