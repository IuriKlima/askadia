import type {SupabaseClient} from '@supabase/supabase-js';
import type {CalendarItem} from '@askadia/contracts';
export type CreativeReference={mime:string;data:string;name:string;description?:unknown;role?:'material'|'style'};
/** The first frame of this same item/revision anchors the remaining carousel. */
export async function carouselReference(db:SupabaseClient,company:string,item:CalendarItem,frame:number):Promise<CreativeReference[]>{
 if(item.format!=='carrossel'||frame===0)return [];
 const found=await db.from('company_creatives').select('mime,object_path').eq('company_id',company).eq('item_id',item.id).eq('revision',item.revision).eq('frame',0).order('created_at',{ascending:false}).limit(1).maybeSingle();
 if(found.error||!found.data)throw new Error('Gere a primeira página deste carrossel antes das demais.');
 const file=await db.storage.from('company-assets').download(found.data.object_path);
 if(file.error||!file.data||file.data.size>10485760)throw new Error('Não foi possível abrir a referência visual do carrossel.');
 return [{mime:found.data.mime,data:Buffer.from(await file.data.arrayBuffer()).toString('base64'),name:'Primeira página deste carrossel',role:'style'}];
}
