import {z} from 'zod';
export function instagramUsername(input:string):string{
 let value=input.trim();
 if(/^https?:\/\//i.test(value)){
  const url=new URL(value);
  if(url.protocol!=='https:'||!['instagram.com','www.instagram.com'].includes(url.hostname)||url.username||url.password||url.port||!/^\/[a-z0-9_.]{1,30}\/?$/i.test(url.pathname))throw new Error('Use o endereço do perfil no Instagram.');
  value=url.pathname.replaceAll('/','');
 }else value=value.replace(/^@/,'');
 if(!/^[a-z0-9_](?:[a-z0-9_.]{0,28}[a-z0-9_])?$/i.test(value)||value.includes('..')||['p','reel','reels','stories','explore','accounts','direct','about'].includes(value.toLowerCase()))throw new Error('Informe um @ ou endereço de perfil válido.');
 return value.toLowerCase();
}
export const instagramSnapshotSchema=z.object({username:z.string().min(1).max(30),name:z.string().max(200),followers:z.number().int().nonnegative().nullable(),mediaCount:z.number().int().nonnegative().nullable(),collectedAt:z.iso.datetime(),posts:z.array(z.object({id:z.string().max(100),timestamp:z.string().nullable(),url:z.string().max(2000).nullable(),likes:z.number().int().nonnegative().nullable(),comments:z.number().int().nonnegative().nullable()})).max(25)});
export type InstagramSnapshot=z.infer<typeof instagramSnapshotSchema>;
export function instagramEngagement(snapshot:InstagramSnapshot){
 const measured=snapshot.posts.filter(p=>p.likes!==null&&p.comments!==null);
 const mean=measured.length?measured.reduce((sum,p)=>sum+p.likes!+p.comments!,0)/measured.length:null;
 return {sampleSize:snapshot.posts.length,measuredPosts:measured.length,meanInteractions:mean,engagementPercent:mean!==null&&snapshot.followers!==null&&snapshot.followers>0?mean/snapshot.followers*100:null};
}
export type InstagramCandidate={username:string;name:string;url:string;context:string};
export type InstagramWatch={id:string;place_id?:string|null;username:string;label:string;kind:'local'|'inspiration';status:string;error:string|null;next_attempt_at:string;snapshot:InstagramSnapshot|null;previous:InstagramSnapshot|null};
