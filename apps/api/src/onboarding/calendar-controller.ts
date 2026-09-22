import {BadRequestException,Body,Controller,Get,Param,Post,Req,Res,ServiceUnavailableException,UseGuards,ForbiddenException} from '@nestjs/common';
import {z} from 'zod';
import {detailedPostSchema,type CalendarItem,type CreativeAsset} from '@askadia/contracts';
import {AuthGuard,type AuthRequest} from '../identity/auth';
import {result} from '../identity/service';
import {detailCalendar,designCreative,type DetailContext} from './content';
function parse<T>(schema:z.ZodType<T>,input:unknown){const r=schema.safeParse(input);if(!r.success)throw new BadRequestException('Confira os dados do conteúdo.');return r.data;}
const id=(s:string)=>parse(z.uuid(),s);
const requestSchema=z.object({requestId:z.uuid()}).strict();
@Controller('onboarding/companies/:companyId')
@UseGuards(AuthGuard)
export class CalendarController{
 @Get('calendar') async read(@Req() r:AuthRequest,@Param('companyId') company:string){
  const cap=result<{actions:string[]}>(await r.actor.client.rpc('company_capabilities',{p_company_id:id(company)}));if(!cap.actions.includes('marketing.read'))throw new ForbiddenException();
  const [items,assets,brief]=await Promise.all([r.actor.client.from('company_calendar_items').select('*').eq('company_id',company).order('created_at',{ascending:false}).order('position'),r.actor.client.from('company_creatives').select('*').eq('company_id',company).order('created_at',{ascending:false}),r.actor.client.from('company_strategy_briefs').select('id,generation,status,profile_version').eq('company_id',company).order('created_at',{ascending:false}).limit(1)]);
  for(const response of [items,assets,brief]){if(response.error?.code==='PGRST205'||response.error?.code==='42P01')throw new ServiceUnavailableException('O calendário aguarda a atualização do banco de dados (migração 007). Seus dados existentes foram preservados.');}
  const materials=result(await r.actor.client.from('onboarding_attachments').select('id,name,mime,size').eq('company_id',company).in('mime',['image/png','image/jpeg','image/webp']).order('created_at',{ascending:false}));
  return {items:result(items) as CalendarItem[],assets:result(assets) as CreativeAsset[],current:result(brief)[0]??null,materials};
 }
 @Post('calendar/generate') async details(@Req() r:AuthRequest,@Param('companyId') company:string,@Body() body:unknown){
  const input=parse(requestSchema,body);if(!process.env.OPENAI_API_KEY)throw new ServiceUnavailableException('Configure a OpenAI para detalhar o calendário.');
  const context=result<DetailContext>(await r.actor.client.rpc('start_content_run',{p_company_id:id(company),p_request_id:input.requestId,p_kind:'details'}));
  let output:Awaited<ReturnType<typeof detailCalendar>>;
  try{output=await detailCalendar(context);}catch{await r.actor.client.rpc('finish_content_details',{p_company_id:company,p_request_id:input.requestId,p_items:null,p_model:null});throw new ServiceUnavailableException('O detalhamento não foi concluído pela OpenAI. A estratégia aprovada e as ideias continuam salvas. Tente novamente no calendário.');}
  const saved=result<{status:string}>(await r.actor.client.rpc('finish_content_details',{p_company_id:company,p_request_id:input.requestId,p_items:output.items,p_model:output.model}));if(saved.status==='stale')throw new BadRequestException('O conteúdo ou perfil mudou durante a geração. Nenhuma edição foi substituída.');return saved;
 }
 @Post('calendar/edit') async edit(@Req() r:AuthRequest,@Param('companyId') company:string,@Body() body:unknown){const input=parse(z.object({id:z.uuid(),revision:z.number().int().positive(),details:detailedPostSchema,date:z.iso.date().nullable()}).strict(),body);return result(await r.actor.client.rpc('edit_calendar_item',{p_company_id:id(company),p_id:input.id,p_revision:input.revision,p_details:input.details,p_date:input.date}));}
 @Post('calendar/approve') async approve(@Req() r:AuthRequest,@Param('companyId') company:string,@Body() body:unknown){const input=parse(z.object({id:z.uuid(),revision:z.number().int().positive()}).strict(),body);return result(await r.actor.client.rpc('approve_calendar_item',{p_company_id:id(company),p_id:input.id,p_revision:input.revision}));}
 @Post('calendar/design') async design(@Req() r:AuthRequest,@Param('companyId') company:string,@Body() body:unknown){
  const input=parse(z.object({requestId:z.uuid(),id:z.uuid(),frame:z.number().int().min(0).max(5),materials:z.array(z.uuid()).max(5).default([])}).strict(),body);if(!process.env.GEMINI_API_KEY)throw new ServiceUnavailableException('Configure o Gemini para gerar criativos.');
  const references:{mime:string;data:string;name:string}[]=[];let total=0;
  for(const attachment of [...new Set(input.materials)]){const record=result<{object_path:string;mime:string;name:string;size:number}|null>(await r.actor.client.from('onboarding_attachments').select('object_path,mime,name,size').eq('company_id',id(company)).eq('id',attachment).maybeSingle());if(!record||!['image/png','image/jpeg','image/webp'].includes(record.mime))throw new BadRequestException('Selecione imagens disponíveis nesta empresa.');total+=record.size;if(total>12582912)throw new BadRequestException('Selecione até 12 MB de imagens de referência por geração.');const file=await r.actor.client.storage.from('company-assets').download(record.object_path);if(file.error||!file.data)throw new BadRequestException('Não foi possível abrir um material selecionado. Nenhuma geração foi iniciada.');references.push({mime:record.mime,name:record.name,data:Buffer.from(await file.data.arrayBuffer()).toString('base64')});}
  const context=result<Parameters<typeof designCreative>[0]>(await r.actor.client.rpc('start_content_run',{p_company_id:id(company),p_request_id:input.requestId,p_kind:'design',p_item_id:input.id,p_frame:input.frame,p_materials:input.materials}));
  let image:Awaited<ReturnType<typeof designCreative>>;
  try{image=await designCreative(context,input.frame,references);}catch(e){await r.actor.client.rpc('finish_content_design',{p_company_id:company,p_request_id:input.requestId,p_mime:null,p_model:null});throw new ServiceUnavailableException(e instanceof Error?e.message:'O criativo não foi gerado.');}
  const extension=image.mime==='image/png'?'png':image.mime==='image/jpeg'?'jpg':'webp';const path=company+'/generated/'+input.requestId+'.'+extension;
  const upload=await r.actor.client.storage.from('company-assets').upload(path,image.bytes,{contentType:image.mime,upsert:false});
  if(upload.error){await r.actor.client.rpc('finish_content_design',{p_company_id:company,p_request_id:input.requestId,p_mime:null,p_model:null});throw new ServiceUnavailableException('Não foi possível guardar o criativo no armazenamento privado.');}
  const saved=result<{status:string}>(await r.actor.client.rpc('finish_content_design',{p_company_id:company,p_request_id:input.requestId,p_mime:image.mime,p_model:image.model}));if(saved.status==='stale')throw new BadRequestException('O conteúdo mudou. A imagem não foi vinculada à versão atual.');return saved;
 }
 @Get('creatives/:assetId') async asset(@Req() r:AuthRequest,@Param('companyId') company:string,@Param('assetId') asset:string,@Res() res:{setHeader:(k:string,v:string)=>void;send:(b:Buffer)=>void}){
  const row=result<CreativeAsset|null>(await r.actor.client.from('company_creatives').select('*').eq('company_id',id(company)).eq('id',id(asset)).maybeSingle());if(!row)throw new ForbiddenException('Criativo indisponível.');const file=await r.actor.client.storage.from('company-assets').download(row.object_path);if(file.error||!file.data)throw new BadRequestException('Arquivo indisponível.');res.setHeader('Content-Type',row.mime);res.setHeader('Cache-Control','private, no-store');res.setHeader('X-Content-Type-Options','nosniff');res.send(Buffer.from(await file.data.arrayBuffer()));
 }
}
