import {BadRequestException,Body,Controller,Get,Param,Post,Req,ServiceUnavailableException,UseGuards} from '@nestjs/common';
import {z} from 'zod';
import type {PurchaseState} from '@askadia/contracts';
import {AuthGuard,type AuthRequest} from '../identity/auth';
import {result} from '../identity/service';
import {serviceDb} from '../campaigns/ads';
export const testCheckoutEnabled=()=>process.env.CHECKOUT_MODE==='test';
function parse<T>(schema:z.ZodType<T>,value:unknown):T{const r=schema.safeParse(value);if(!r.success)throw new BadRequestException('Confira a empresa, o plano e a confirmação.');return r.data;}
@Controller('onboarding/companies/:id/purchase')
@UseGuards(AuthGuard)
export class PurchaseController{
 @Get() async read(@Req() r:AuthRequest,@Param('id') company:string){parse(z.uuid(),company);const state=result<PurchaseState>(await r.actor.client.rpc('company_purchase_state',{p_company_id:company}));return {...state,testCheckoutEnabled:testCheckoutEnabled()};}
 @Post('checkout') async start(@Req() r:AuthRequest,@Param('id') company:string,@Body() body:unknown){parse(z.uuid(),company);if(!testCheckoutEnabled())throw new ServiceUnavailableException('O checkout está em preparação. Nenhuma cobrança foi iniciada.');const input=parse(z.object({requestId:z.uuid(),planId:z.enum(['askadia_monthly','askadia_annual'])}).strict(),body);return result(await r.actor.client.rpc('begin_test_checkout',{p_company_id:company,p_id:input.requestId,p_plan:input.planId}));}
 @Post('checkout/confirm') async confirm(@Req() r:AuthRequest,@Param('id') company:string,@Body() body:unknown){parse(z.uuid(),company);if(!testCheckoutEnabled())throw new ServiceUnavailableException('A simulação de checkout está desabilitada.');const input=parse(z.object({checkoutId:z.uuid(),outcome:z.enum(['approved','declined','cancelled']),accepted:z.boolean()}).strict(),body);if(input.outcome==='approved'&&!input.accepted)throw new BadRequestException('Confirme o plano e o valor para simular o pagamento.');result(await r.actor.client.rpc('company_purchase_state',{p_company_id:company}));return result(await serviceDb().rpc('complete_test_checkout_server',{p_company_id:company,p_id:input.checkoutId,p_actor:r.actor.id,p_outcome:input.outcome,p_accepted:input.accepted}));}
 @Post('finish') async finish(@Req() r:AuthRequest,@Param('id') company:string){parse(z.uuid(),company);return result(await r.actor.client.rpc('finish_company_setup',{p_company_id:company}));}
}
