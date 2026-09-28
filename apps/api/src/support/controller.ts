import {BadRequestException,Body,Controller,Get,HttpException,Param,Post,Query,Req,UseGuards} from '@nestjs/common';
import {z} from 'zod';
import {supportReplySchema,supportStatuses,supportTicketSchema} from '@askadia/contracts';
import {AuthGuard,type AuthRequest} from '../identity/auth';
import {result} from '../identity/service';
function parse<T>(schema:z.ZodType<T>,value:unknown):T{const parsed=schema.safeParse(value);if(!parsed.success)throw new BadRequestException('Confira os dados do chamado.');return parsed.data;}
export function supportWhatsappUrl(value=process.env.PUBLIC_SUPPORT_WHATSAPP){const digits=value?.replace(/[\s()+-]/g,'')??'';return /^[1-9]\d{10,14}$/.test(digits)?'https://wa.me/'+digits:null;}
function supportResult<T>(value:Parameters<typeof result<T>>[0]):T{if(value.error?.code==='P0429')throw new HttpException('Muitas solicitações. Aguarde um pouco ou continue pelo WhatsApp.',429);if(value.error?.code==='40001')throw new HttpException('O chamado foi atualizado. Atualize antes de mudar o status.',409);return result(value);}
@Controller('operations/support')
@UseGuards(AuthGuard)
export class SupportController{
 @Get('config') config(){return {whatsappUrl:supportWhatsappUrl()};}
 @Get('tickets') async list(@Req() req:AuthRequest,@Query() query:unknown){const q=parse(z.object({team:z.enum(['true','false']).optional(),offset:z.coerce.number().int().min(0).max(10000).default(0)}).strict(),query);return supportResult(await req.actor.client.rpc('support_ticket_list',{p_team:q.team==='true',p_offset:q.offset}));}
 @Get('tickets/:id') async detail(@Req() req:AuthRequest,@Param('id') id:string){return supportResult(await req.actor.client.rpc('support_ticket_detail',{p_id:parse(z.uuid(),id)}));}
 @Post('tickets') async create(@Req() req:AuthRequest,@Body() body:unknown){const v=parse(supportTicketSchema,body);return supportResult(await req.actor.client.rpc('create_support_ticket',{p_id:v.requestId,p_company_id:v.companyId,p_subject:v.subject,p_message:v.message,p_page:v.page,p_transcript:v.transcript}));}
 @Post('tickets/:id/reply') async reply(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const v=parse(supportReplySchema,body);return supportResult(await req.actor.client.rpc('reply_support_ticket',{p_ticket_id:parse(z.uuid(),id),p_id:v.requestId,p_message:v.message}));}
 @Post('tickets/:id/status') async status(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){const v=parse(z.object({status:z.enum(supportStatuses),version:z.number().int().min(1)}).strict(),body);return supportResult(await req.actor.client.rpc('set_support_ticket_status',{p_id:parse(z.uuid(),id),p_status:v.status,p_version:v.version}));}
}
