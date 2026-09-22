import {z} from 'zod';
export const detailedPostSchema=z.object({title:z.string().min(1).max(300),caption:z.string().min(1).max(2200),cta:z.string().max(500),hashtags:z.array(z.string().max(100)).max(12),designBrief:z.string().min(1).max(4000),slides:z.array(z.object({text:z.string().max(500),visual:z.string().max(1500)})).max(6),videoScript:z.string().max(6000),clientMaterials:z.array(z.string().max(500)).max(12),unknowns:z.array(z.string().max(500)).max(12)}).strict();
export const detailedCalendarSchema=z.object({items:z.array(z.object({id:z.uuid(),details:detailedPostSchema})).min(1).max(24)}).strict();
export type DetailedPost=z.infer<typeof detailedPostSchema>;
export type CalendarItem={id:string;company_id:string;brief_id:string;generation:number;profile_version:number;position:number;week:number;format:'imagem'|'carrossel'|'video';idea:string;direction:string;details:DetailedPost|null;revision:number;planned_date:string|null;status:'idea'|'draft'|'approved';approved_revision:number|null;created_at:string};
export type CreativeAsset={id:string;item_id:string;revision:number;frame:number;mime:string;object_path:string;model:string;created_at:string};
