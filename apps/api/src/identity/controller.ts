import { BadRequestException, Body, Controller, Get, Inject, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { acceptInvitationSchema, createCompanyInputSchema, createWorkspaceSchema, invitationInputSchema, memberInputSchema, updateCompanyInputSchema } from '@askadia/contracts';
import { AuthGuard, type AuthRequest } from './auth';
import { IdentityService } from './service';
function parse<T>(schema:z.ZodType<T>,body:unknown):T {const result=schema.safeParse(body);if(!result.success) throw new BadRequestException('Confira os campos informados.');return result.data;}
const id=(value:string)=>parse(z.uuid(),value);
@Controller('identity')
@UseGuards(AuthGuard)
export class IdentityController {
  constructor(@Inject(IdentityService) private readonly identity:IdentityService) {}
  @Get() snapshot(@Req() req:AuthRequest){return this.identity.snapshot(req.actor);}
  @Post('workspaces') async workspace(@Req() req:AuthRequest,@Body() body:unknown){return {id:await this.identity.workspace(req.actor,parse(createWorkspaceSchema,body).name)};}
  @Post('companies') company(@Req() req:AuthRequest,@Body() body:unknown){return this.identity.createCompany(req.actor,parse(createCompanyInputSchema,body));}
  @Patch('companies/:id') update(@Req() req:AuthRequest,@Param('id') companyId:string,@Body() body:unknown){return this.identity.updateCompany(req.actor,id(companyId),parse(updateCompanyInputSchema,body));}
  @Get('companies/:id/team') team(@Req() req:AuthRequest,@Param('id') companyId:string){return this.identity.team(req.actor,id(companyId));}
  @Post('companies/:id/invitations') invite(@Req() req:AuthRequest,@Param('id') companyId:string,@Body() body:unknown){const input=parse(invitationInputSchema,body);return this.identity.invite(req.actor,id(companyId),input.email,input.role);}
  @Post('companies/:id/invitations/:invitationId/revoke') revoke(@Req() req:AuthRequest,@Param('id') companyId:string,@Param('invitationId') invitationId:string){return this.identity.revoke(req.actor,id(companyId),id(invitationId));}
  @Patch('companies/:id/members/:userId') member(@Req() req:AuthRequest,@Param('id') companyId:string,@Param('userId') userId:string,@Body() body:unknown){return this.identity.changeMember(req.actor,id(companyId),id(userId),parse(memberInputSchema,body).role);}
  @Post('invitations/accept') accept(@Req() req:AuthRequest,@Body() body:unknown){return this.identity.accept(req.actor,parse(acceptInvitationSchema,body).token);}
  @Post('companies/:id/export') export(@Req() req:AuthRequest,@Param('id') companyId:string){return this.identity.exportMetadata(req.actor,id(companyId));}
}
