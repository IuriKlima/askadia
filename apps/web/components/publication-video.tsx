'use client';
import {useRef,useState} from 'react';
import {Upload,Video,LoaderCircle} from 'lucide-react';
import {Button} from '@askadia/ui';
import {journeyApi} from '../lib/journey-api';
import {uploadPublicationVideo,videoUploadBlock} from '../lib/publication-video';
import styles from './publication-workflow.module.css';
type FinalVideo={id:string;name:string;size:number};
export function PublicationVideo({companyId,itemId,revision,videos,write,current,details,busy,reload,onUploading}:{companyId:string;itemId:string;revision:number;videos:FinalVideo[];write:boolean;current:boolean;details:boolean;busy:boolean;reload:()=>Promise<unknown>;onUploading:(value:boolean)=>void}){
 const input=useRef<HTMLInputElement>(null),lock=useRef(false);
 const [uploading,setUploading]=useState(false),[viewing,setViewing]=useState(false),[error,setError]=useState(''),[videoUrl,setVideoUrl]=useState('');
 const blocked=videoUploadBlock({write,current,details});
 async function upload(file:File){
  if(lock.current||busy||blocked)return;lock.current=true;setUploading(true);onUploading(true);setError('');
  try{await uploadPublicationVideo({companyId,itemId,revision,file,uploadId:crypto.randomUUID()});setVideoUrl('');await reload();}
  catch(e){setError(e instanceof Error?e.message:'Não foi possível enviar o vídeo. Tente novamente.');}
  finally{lock.current=false;setUploading(false);onUploading(false);}
 }
 async function preview(id:string){setViewing(true);setError('');try{const result=await journeyApi<{url:string}>('companies/'+companyId+'/videos/'+id);setVideoUrl(result.url);}catch(e){setError(e instanceof Error?e.message:'Não foi possível abrir o vídeo.');}finally{setViewing(false);}}
 return <section className={styles.videoUpload} aria-label="Vídeo da publicação" aria-busy={uploading}>
  <div className={styles.videoHeading}><Video size={24} aria-hidden="true"/><div><h4>{videos.length?'Vídeo recebido para revisão':'Envie o vídeo desta publicação'}</h4><p>Selecione o vídeo final editado no celular ou computador. MP4 · até 50 MB.</p></div></div>
  <div className={styles.videoActions}><Button type="button" disabled={Boolean(blocked)||busy||uploading} onClick={()=>input.current?.click()}>{uploading?<LoaderCircle size={17} aria-hidden="true"/>:<Upload size={17} aria-hidden="true"/>}{uploading?'Enviando vídeo…':videos.length?'Substituir vídeo':'Enviar vídeo'}</Button><input ref={input} type="file" accept="video/mp4,.mp4" hidden aria-label="Selecionar vídeo MP4" disabled={Boolean(blocked)||busy||uploading} onChange={event=>{const file=event.target.files?.[0];event.target.value='';if(file)void upload(file);}}/>
   {videos.map(video=><Button key={video.id} variant="outline" type="button" disabled={viewing||uploading} onClick={()=>void preview(video.id)}>Ver vídeo · {video.name}</Button>)}
  </div>
  {blocked?<p className={styles.videoHint}>{blocked}</p>:<p className={styles.videoHint}>Você pode enviar o vídeo enquanto as outras publicações são preparadas. Substituir o arquivo exige uma nova aprovação.</p>}
  {uploading&&<p role="status">Enviando o arquivo. Aguarde a confirmação antes de sair desta página.</p>}
  {error&&<p className="form-error" role="alert">{error}</p>}
  {videoUrl&&<video controls preload="metadata" src={videoUrl} className={styles.videoPreview} onError={()=>setError('O vídeo não pôde ser reproduzido. Clique em Ver vídeo para renovar o acesso ou confira o formato do arquivo.')}/>}
 </section>;
}
