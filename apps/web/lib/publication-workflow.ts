import type {CalendarItem,CreativeAsset} from '@askadia/contracts';
export function publicationStage(item:CalendarItem,assets:Pick<CreativeAsset,'item_id'|'revision'|'frame'>[],videos:{item_id:string;revision:number}[]){
 if(!item.details)return 1;
 const frames=item.format==='carrossel'?item.details.slides.length:1;
 const ready=item.format==='video'?videos.some(v=>v.item_id===item.id&&v.revision===item.revision):frames>0&&Array.from({length:frames},(_,frame)=>assets.some(a=>a.item_id===item.id&&a.revision===item.revision&&a.frame===frame)).every(Boolean);
 if(!ready)return 1;
 return item.status==='approved'&&item.approved_revision===item.revision?4:2;
}
export const publicationSteps=['Planejar','Criar','Revisar','Aprovar','Programar'];
