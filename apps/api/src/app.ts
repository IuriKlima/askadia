import {ImageDescriptions} from './onboarding/image-descriptions';
import {CompanySiteController,PublicSiteController} from './sites/controller';
import {AdsController} from './campaigns/ads-controller';
import {MetaInboxController} from './inbox/meta-controller';
import {CustomerHistoryController} from './inbox/customer-controller';
import {ManagementController,ManagementIngestionController} from './campaigns/management';
import {CampaignsController} from './campaigns/controller';
import {CampaignDelivery} from './campaigns/delivery';
import {InboxAutomation} from './inbox/automation';
import {InboxController} from './inbox/controller';
import { ChannelsController } from './onboarding/channels';
import { OnboardingController } from './onboarding/controller';
import { CalendarController } from './onboarding/calendar-controller';
import { DashboardModule } from './dashboard/controller';
import 'reflect-metadata';
import { OperationsController } from './operations/controller';
import { Controller, Get, Module } from '@nestjs/common';
import { providers } from '@askadia/integrations';
import { AUTH_CONFIG, AuthGuard, AuthService } from './identity/auth';
import { IdentityController } from './identity/controller';
import { IdentityService } from './identity/service';
@Controller()
export class HealthController {
  @Get('health') health(){return {status:'ok',service:'askadia-api',mode:process.env.NODE_ENV??'development',authentication:process.env.SUPABASE_URL && (process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY) ? 'configured-not-homologated':'not-configured'};}
  @Get('integrations') integrations(){return providers.map(provider=>({...provider,status:'unconfigured'}));}
}
@Module({
  imports:[DashboardModule],
  controllers:[CompanySiteController,PublicSiteController,AdsController,MetaInboxController,CustomerHistoryController,ManagementController,ManagementIngestionController,CampaignsController,InboxController,ChannelsController,CalendarController,OnboardingController,HealthController,IdentityController,OperationsController],
  providers:[ImageDescriptions,CampaignDelivery,InboxAutomation,IdentityService,AuthService,AuthGuard,{provide:AUTH_CONFIG,useFactory:()=>({url:process.env.SUPABASE_URL,key:(process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY)})}],
})
export class AppModule {}
