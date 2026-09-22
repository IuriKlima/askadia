import { BadRequestException,Body,Controller,Get,Inject,Param,Post,Query,Req,UseGuards,ForbiddenException } from '@nestjs/common';
import { z } from 'zod';
import { assignmentSchema,draftImportSchema,delegationSchema,internalAccessSchema,portfolioQuerySchema } from '@askadia/contracts';
import { AuthGuard,type AuthRequest } from '../identity/auth';
import { IdentityService,result } from '../identity/service';

function parse<T>(schema:z.ZodType<T>,body:unknown):T{
  const input=schema.safeParse(body);
  if(!input.success)throw new BadRequestException('Confira os campos informados.');
  return input.data;
}
const uuid=(id:string)=>parse(z.uuid(),id);

@Controller('operations')
@UseGuards(AuthGuard)
export class OperationsController {
  constructor(@Inject(IdentityService) private readonly identity:IdentityService){}
  @Get('me') async me(@Req() req:AuthRequest){
    return result(await req.actor.client.from('platform_staff').select('role,active').eq('user_id',req.actor.id).maybeSingle());
  }
  @Get('plans') async plans(@Req() req:AuthRequest){
    return result(await req.actor.client.from('plan_catalog').select('*').order('price_cents'));
  }
  @Get('companies/:id/capabilities') async capabilities(@Req() req:AuthRequest,@Param('id') id:string){
    return result(await req.actor.client.rpc('company_capabilities',{p_company_id:uuid(id)}));
  }
  @Post('companies/:id/import') async importDrafts(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){
    const input=parse(draftImportSchema,body);
    return result(await req.actor.client.rpc('import_local_drafts',{p_company_id:uuid(id),p_payload:input}));
  }
  @Get('companies/:id/drafts') async drafts(@Req() req:AuthRequest,@Param('id') id:string){
    result(await req.actor.client.rpc('company_capabilities',{p_company_id:uuid(id)}));
    return result(await req.actor.client.from('editorial_drafts').select('*').eq('company_id',id).order('created_at',{ascending:false}).limit(100));
  }
  @Get('companies/:id/delegations') async delegations(@Req() req:AuthRequest,@Param('id') id:string){
    await this.identity.requireManager(req.actor,uuid(id));
    return result(await req.actor.client.from('company_permission_grants').select('company_id,user_id,action,budget_limit_cents,expires_at').eq('company_id',id));
  }
  @Post('companies/:id/delegations') async delegate(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){
    const input=parse(delegationSchema,body);
    result(await req.actor.client.rpc('set_company_permission',{p_company_id:uuid(id),p_user_id:input.userId,p_action:input.action,p_enabled:input.enabled,p_budget_limit_cents:input.budgetLimitCents,p_expires_at:input.expiresAt}));
    return {ok:true};
  }
  @Get('portfolio') async portfolio(@Req() req:AuthRequest,@Query() query:unknown){
    const input=parse(portfolioQuerySchema,query);
    return result(await req.actor.client.rpc('internal_portfolio',{p_search:input.search,p_offset:input.offset}));
  }
  @Get('staff') async staff(@Req() req:AuthRequest){
    const role=result<{role:string;active:boolean}|null>(await req.actor.client.from('platform_staff').select('role,active').eq('user_id',req.actor.id).maybeSingle());
    if(!role?.active||role.role!=='platform_admin')throw new ForbiddenException('Administração geral necessária.');
    return result(await req.actor.client.from('platform_staff').select('user_id,role').eq('active',true).eq('role','support'));
  }
  @Get('companies/:id/assignments') async assignments(@Req() req:AuthRequest,@Param('id') id:string){
    return result(await req.actor.client.rpc('company_assignment_roster',{p_company_id:uuid(id)}));
  }
  @Post('companies/:id/assignments') async assign(@Req() req:AuthRequest,@Param('id') id:string,@Body() body:unknown){
    const input=parse(assignmentSchema,body);
    result(await req.actor.client.rpc('set_company_assignment',{p_company_id:uuid(id),p_staff_id:input.staffId,p_assigned:input.assigned}));
    return {ok:true};
  }
  @Post('access') async start(@Req() req:AuthRequest,@Body() body:unknown){
    const input=parse(internalAccessSchema,body);
    return {sessionId:result(await req.actor.client.rpc('start_internal_access',{p_company_id:input.companyId,p_reason:input.reason}))};
  }
  @Get('access/:id') async context(@Req() req:AuthRequest,@Param('id') id:string){
    return result(await req.actor.client.rpc('internal_company_context',{p_session_id:uuid(id)}));
  }
  @Post('access/:id/end') async end(@Req() req:AuthRequest,@Param('id') id:string){
    result(await req.actor.client.rpc('end_internal_access',{p_session_id:uuid(id)}));
    return {ok:true};
  }
}
