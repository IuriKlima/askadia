import {generateStrategy} from './strategy';
import { BadRequestException, ServiceUnavailableException, Body, Controller, Get, Param, Post, Req, Res, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { beginCompanySchema,normalizePhone,guidedAnswers,onboardingReplySchema,profilePatchSchema,type OnboardingSnapshot,type PlaceSearchResult } from '@askadia/contracts';
import { AuthGuard,type AuthRequest,type AuthenticatedActor } from '../identity/auth';
import { result } from '../identity/service';
import { extractWebsite,publicWebsiteUrl,interpret,interpreterConfigured,places } from './providers';
const uuid=(v:string)=>{const parsed=z.uuid().safeParse(v);if(!parsed.success)throw new BadRequestException('Identificador inválido.');return parsed.data;};
function parse<T>(schema:z.ZodType<T>,body:unknown):T{const r=schema.safeParse(body);if(!r.success)throw new BadRequestException('Revise os dados enviados.');return r.data;}
async function snapshot(actor:AuthenticatedActor,id:string){
 const state=result<OnboardingSnapshot>(await actor.client.rpc('company_onboarding_read',{p_company_id:id}));
 return {...state,question:currentQuestion(state),provider:{mode:interpreterConfigured()?'configured' as const:'guided' as const,message:interpreterConfigured()?'Interpretação por IA sujeita ao limite autorizado da empresa. Todas as informações passam pela sua confirmação.':'Conversa guiada: a interpretação por IA ainda depende de configuração. Suas respostas continuam sendo salvas.'}};
}
function currentQuestion(state:OnboardingSnapshot){return state.step==='identity'&&state.state.facts.city?.status==='provided'?'Qual é o nome do seu negócio?':state.question;}
async function reserve(actor:AuthenticatedActor,id:string,requestId:string,kind:string){const value=await actor.client.rpc('reserve_onboarding_provider',{p_company_id:id,p_request_id:requestId,p_kind:kind});if(value.error?.message==='Daily account allowance exhausted')return false;return result<boolean>(value);}
async function capability(actor:AuthenticatedActor,id:string,action:string){const cap=result<{actions:string[]}>(await actor.client.rpc('company_capabilities',{p_company_id:id}));if(!cap.actions.includes(action))throw new (await import('@nestjs/common')).ForbiddenException('Seu perfil não permite esta ação.');return cap;}
@Controller('onboarding')
@UseGuards(AuthGuard)
export class OnboardingController {
 @Post('companies') async begin(@Req() req:AuthRequest,@Body() body:unknown){const input=parse(beginCompanySchema,body);return result(await req.actor.client.rpc('begin_company_onboarding',{p_request_id:input.requestId,p_workspace_id:input.workspaceId}));}
 @Get('companies/:id') read(@Req() req:AuthRequest,@Param('id') id:string){return snapshot(req.actor,uuid(id));}
 @Post('companies/:id/answers') async answer(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){
  uuid(id);const input=parse(onboardingReplySchema,body);await capability(req.actor,id,'marketing.write');
  const current=await snapshot(req.actor,id);let answers=input.answers;let source='user';let providerMessage=current.provider.message;
  if(input.action==='reply'){
   answers={...guidedAnswers(current.step,input.message),...answers};
   if(interpreterConfigured()&&current.state.revision===input.revision){
    const reserved=await reserve(req.actor,id,input.requestId,'interpretation');
    if(reserved){try{const interpreted=await interpret(current,input.message);answers={...answers,...interpreted.answers,...input.answers};source=Object.keys(interpreted.answers).length?'assistant_suggestion':'user';await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'interpretation',p_outcome:interpreted.outcome,p_usage:interpreted.usage});if(interpreted.outcome!=='completed')providerMessage='A IA não interpretou esta resposta. Ela foi salva pela conversa guiada.';}catch{providerMessage='A IA está indisponível. Sua resposta foi salva pela conversa guiada.';await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'interpretation',p_outcome:'failed'});}}
    else providerMessage='Limite de interpretação por IA indisponível. Sua resposta foi salva pela conversa guiada.';
   }
  }
  const saved=result<OnboardingSnapshot>(await req.actor.client.rpc('save_company_onboarding',{p_company_id:id,p_request_id:input.requestId,p_revision:input.revision,p_message:input.message,p_patch:parse(profilePatchSchema,answers),p_action:input.action,p_source:source}));
  return {...saved,question:currentQuestion(saved),provider:{...current.provider,message:providerMessage}};
 }
 @Post('companies/:id/places') async search(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown):Promise<PlaceSearchResult>{
  uuid(id);const input=parse(z.object({requestId:z.uuid(),kind:z.enum(['location','competitors'])}).strict(),body);await capability(req.actor,id,'marketing.write');const current=await snapshot(req.actor,id);
  const fallback={status:'unconfigured' as const,places:[],radius:null,message:'A pesquisa automática de endereços ainda não está ativada na Askadia. Abra o Google Maps para conferir o estabelecimento e informe o endereço na conversa.'};
  if(!process.env.GOOGLE_PLACES_SERVER_KEY)return fallback;
  if(!await reserve(req.actor,id,input.requestId,'places'))return {...fallback,status:'unavailable',message:'O limite de pesquisas desta empresa ou conta foi atingido. Você pode conferir no Google Maps e continuar manualmente.'};
  try{const found=await places(current,input.kind);await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'places',p_outcome:'completed'});return found;}catch{await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'places',p_outcome:'failed'});return {...fallback,status:'unavailable',message:'A pesquisa falhou. Nenhum resultado foi inventado. Você pode informar os dados manualmente.'};}
 }
 @Post('companies/:id/website') async website(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){
  uuid(id);const input=parse(z.object({url:z.string().max(2000),requestId:z.uuid()}).strict(),body);await capability(req.actor,id,'marketing.write');try{publicWebsiteUrl(input.url);}catch{throw new BadRequestException('Informe um site público HTTPS sem credenciais, porta ou parâmetros.');}
  if(!interpreterConfigured()||!await reserve(req.actor,id,input.requestId,'interpretation'))return {status:'unavailable',facts:[],message:'A leitura do site depende de IA configurada e limite disponível. Informe os dados manualmente.'};
  try{const r=await extractWebsite(input.url);await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'interpretation',p_outcome:'completed',p_usage:r.usage});return {status:'available',facts:r.facts,message:r.facts.length?'Sugestões do site: selecione apenas o que continua válido.':'Nenhum fato verificável foi encontrado. Informe os dados manualmente.'};}catch{await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'interpretation',p_outcome:'failed'});return {status:'unavailable',facts:[],message:'Não foi possível consultar o site agora. Você pode informar os dados na conversa.'};}
 }
 @Post('companies/:id/strategy') async strategy(@Req() req:AuthRequest,@Param('id') id:string){return result(await req.actor.client.rpc('prepare_company_strategy',{p_company_id:uuid(id)}));}
 @Post('companies/:id/strategy/generate') async generate(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){
  uuid(id);const input=parse(z.object({requestId:z.uuid()}).strict(),body);await capability(req.actor,id,'marketing.write');
  if(!process.env.OPENAI_API_KEY||!process.env.OPENAI_MODEL_STRATEGY)throw new ServiceUnavailableException('Configure OpenAI e o modelo de estratégia no servidor.');
  const brief=result<{facts:OnboardingSnapshot['state']['facts']}>(await req.actor.client.rpc('start_company_strategy',{p_company_id:id,p_request_id:input.requestId}));
  let output:Awaited<ReturnType<typeof generateStrategy>>;
  try{output=await generateStrategy(brief.facts);}catch{
   await req.actor.client.rpc('finish_company_strategy',{p_company_id:id,p_request_id:input.requestId,p_output:null,p_model:process.env.OPENAI_MODEL_STRATEGY,p_response_id:null});await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'strategy',p_outcome:'failed'});throw new ServiceUnavailableException('A geração não retornou uma proposta válida. O briefing continua salvo. Tente novamente.');
  }
  const saved=result(await req.actor.client.rpc('finish_company_strategy',{p_company_id:id,p_request_id:input.requestId,p_output:output.output,p_model:output.model,p_response_id:output.responseId}));
  await req.actor.client.rpc('finish_onboarding_provider',{p_company_id:id,p_request_id:input.requestId,p_kind:'strategy',p_outcome:'completed',p_usage:output.usage});return saved;
 }
 @Post('companies/:id/strategy/approve') async approve(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const input=parse(z.object({briefId:z.uuid(),generation:z.number().int().positive()}).strict(),body);return result(await req.actor.client.rpc('approve_company_strategy',{p_company_id:uuid(id),p_brief_id:input.briefId,p_generation:input.generation}));}
 @Get('companies/:id/strategy') async strategies(@Req() req:AuthRequest,@Param('id') id:string){await capability(req.actor,uuid(id),'marketing.read');return result(await req.actor.client.from('company_strategy_briefs').select('*').eq('company_id',id).order('created_at',{ascending:false}).limit(10));}
 @Get('companies/:id/crm') async crm(@Req() req:AuthRequest,@Param('id') id:string){await capability(req.actor,uuid(id),'crm.read');const [contacts,opportunities,conversations,notes,links]=await Promise.all([req.actor.client.from('contacts').select('*').eq('company_id',id).order('created_at',{ascending:false}).limit(1000),req.actor.client.from('opportunities').select('*').eq('company_id',id).order('created_at',{ascending:false}).limit(1000),req.actor.client.from('company_conversations').select('*').eq('company_id',id).order('updated_at',{ascending:false}).limit(200),req.actor.client.from('company_conversation_notes').select('*').eq('company_id',id).order('created_at',{ascending:false}).limit(200),req.actor.client.from('company_contact_channels').select('contact_id,remote_id,last_message_at,last_preview').eq('company_id',id).order('last_message_at',{ascending:false}).limit(1000)]);return {contacts:result(contacts),opportunities:result(opportunities),conversations:result(conversations),notes:result(notes),links:result(links).map((l:{contact_id:string;remote_id:string;last_message_at:string;last_preview:string})=>({contactId:l.contact_id,thread:Buffer.from(l.remote_id).toString('base64url'),time:l.last_message_at,preview:l.last_preview}))};}
 @Post('companies/:id/crm/contacts') async contact(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const input=parse(z.object({requestId:z.uuid(),name:z.string().trim().min(2).max(150),phone:z.string().max(25).default(''),email:z.union([z.email(),z.literal('')]).default(''),interest:z.string().max(2000).default('')}).strict(),body);let phone='';try{phone=input.phone?normalizePhone(input.phone):'';}catch{throw new BadRequestException('Informe um telefone válido com DDD.');}return result(await req.actor.client.rpc('save_crm_contact',{p_company_id:uuid(id),p_request_id:input.requestId,p_name:input.name,p_phone:phone,p_email:input.email,p_interest:input.interest}));}
 @Post('companies/:id/crm/stage') async stage(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const input=parse(z.object({id:z.uuid(),stage:z.enum(['new','in_progress','qualified','referred','scheduled','attended','enrolled','lost']),reason:z.string().trim().min(2).max(2000)}).strict(),body);return result(await req.actor.client.rpc('move_crm_opportunity',{p_company_id:uuid(id),p_id:input.id,p_stage:input.stage,p_reason:input.reason}));}
 @Post('companies/:id/crm/conversations') async conversation(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const input=parse(z.object({contactId:z.uuid()}).strict(),body);return result(await req.actor.client.rpc('open_company_conversation',{p_company_id:uuid(id),p_contact_id:input.contactId}));}
 @Post('companies/:id/crm/mode') async mode(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const input=parse(z.object({id:z.uuid(),revision:z.number().int().min(0),mode:z.enum(['human','closed'])}).strict(),body);return result(await req.actor.client.rpc('set_conversation_mode',{p_company_id:uuid(id),p_id:input.id,p_revision:input.revision,p_mode:input.mode}));}
 @Post('companies/:id/crm/notes') async note(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const input=parse(z.object({id:z.uuid(),requestId:z.uuid(),body:z.string().trim().min(1).max(6000)}).strict(),body);return result(await req.actor.client.rpc('add_conversation_note',{p_company_id:uuid(id),p_id:input.id,p_request_id:input.requestId,p_body:input.body}));}
 @Post('companies/:id/attachments/:attachmentId') async upload(@Req() req:AuthRequest & {body:Buffer;headers:Record<string,string|undefined>},@Param('id') id:string,@Param('attachmentId') attachmentId:string){
  uuid(id);uuid(attachmentId);await capability(req.actor,id,'marketing.write');const bytes=req.body;const mime=req.headers['content-type']?.split(';')[0]??'';
  const extensions:Record<string,string>={'image/png':'png','image/jpeg':'jpg','image/webp':'webp','application/pdf':'pdf'};
  const ext=extensions[mime];const magic=Buffer.isBuffer(bytes)&&((mime==='image/png'&&bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))||(mime==='image/jpeg'&&bytes[0]===255&&bytes[1]===216&&bytes[2]===255)||(mime==='image/webp'&&bytes.toString('ascii',0,4)==='RIFF'&&bytes.toString('ascii',8,12)==='WEBP')||(mime==='application/pdf'&&bytes.toString('ascii',0,5)==='%PDF-'));
  if(!ext||!magic||bytes.length<1||bytes.length>10485760)throw new BadRequestException('Envie PNG, JPEG, WebP ou PDF de até 10 MB.');
  let name:string;try{name=decodeURIComponent(req.headers['x-file-name']??'');}catch{throw new BadRequestException('Nome inválido.');}if(!name.trim()||name.length>180)throw new BadRequestException('Nome inválido.');
  const objectPath=id+'/onboarding/'+attachmentId+'.'+ext;
  const existing=await req.actor.client.from('onboarding_attachments').select('*').eq('company_id',id).eq('id',attachmentId).maybeSingle();if(result(existing))return existing.data;
  const upload=await req.actor.client.storage.from('company-assets').upload(objectPath,bytes,{contentType:mime,upsert:false});
  if(upload.error&&upload.error.message!=='The resource already exists')throw new BadRequestException('Não foi possível salvar o arquivo. Confira o acesso e o limite do armazenamento.');
  return result(await req.actor.client.rpc('record_onboarding_attachment',{p_company_id:id,p_id:attachmentId,p_name:name,p_mime:mime,p_size:bytes.length,p_path:objectPath}));
 }
 @Get('companies/:id/attachments/:attachmentId') async download(@Req() req:AuthRequest,@Param('id') id:string,@Param('attachmentId') attachmentId:string,@Res() res:{setHeader:(name:string,value:string)=>void;send:(bytes:Buffer)=>void}){
  await capability(req.actor,uuid(id),'marketing.read');const record=result<{object_path:string;name:string;mime:string}|null>(await req.actor.client.from('onboarding_attachments').select('object_path,name,mime').eq('company_id',id).eq('id',uuid(attachmentId)).maybeSingle());if(!record)throw new BadRequestException('Arquivo indisponível.');
  const file=await req.actor.client.storage.from('company-assets').download(record.object_path);if(file.error||!file.data)throw new BadRequestException('Arquivo indisponível.');res.setHeader('Content-Type',record.mime);res.setHeader('Content-Disposition',"attachment; filename*=UTF-8''"+encodeURIComponent(record.name));res.setHeader('Cache-Control','private, no-store');res.send(Buffer.from(await file.data.arrayBuffer()));
 }
 @Get('access/:sessionId') async internal(@Req() req:AuthRequest,@Param('sessionId') sessionId:string){return result(await req.actor.client.rpc('internal_onboarding_context',{p_session_id:uuid(sessionId)}));}
 @Post('access/:sessionId/meetings') async meeting(@Req() req:AuthRequest,@Param('sessionId') sessionId:string,@Body() body:unknown){const input=parse(z.object({requestId:z.uuid(),date:z.iso.datetime(),participants:z.string().trim().min(2).max(1000),decisions:z.string().trim().min(2).max(6000),nextActions:z.string().trim().min(2).max(6000)}).strict(),body);return result(await req.actor.client.rpc('record_followup_meeting',{p_session_id:uuid(sessionId),p_request_id:input.requestId,p_date:input.date.slice(0,10),p_participants:input.participants,p_decisions:input.decisions,p_next_actions:input.nextActions}));}
}
