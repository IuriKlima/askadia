import 'reflect-metadata';
import { config } from 'dotenv';
import { resolve } from 'node:path';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { z } from 'zod';
import { AppModule } from './app';
config({path:resolve(__dirname,'../../../.env'),quiet:true});
const env=z.object({
  NODE_ENV:z.enum(['development','test','production']).default('development'),
  API_PORT:z.coerce.number().int().min(1).max(65535).default(4000),
  WEB_ORIGIN:z.url().default('http://127.0.0.1:3000'),
  SUPABASE_URL:z.union([z.url(),z.literal('')]).optional(),
  SUPABASE_ANON_KEY:z.string().optional(),
  SUPABASE_PUBLISHABLE_KEY:z.string().optional(),
}).parse(process.env);
if(Boolean(env.SUPABASE_URL)!==Boolean(env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_ANON_KEY)) throw new Error('Configure SUPABASE_URL and SUPABASE_ANON_KEY together.');
if(env.NODE_ENV==='production') throw new Error('Production disabled until full Supabase homologation and launch review.');
async function bootstrap(){
  const app=await NestFactory.create<NestExpressApplication>(AppModule);
  app.useBodyParser('raw',{limit:'10mb',type:request=>Boolean(request.url?.match(/^\/onboarding\/companies\/[^/]+\/attachments\/[^/]+$/))});
  app.useBodyParser('json',{limit:'2mb',type:request=>request.url?.startsWith('/dashboard/imports')??false});
  app.useBodyParser('json',{limit:'256kb'});
  app.enableCors({origin:env.WEB_ORIGIN});
  app.enableShutdownHooks();
  await app.listen(env.API_PORT,'127.0.0.1');
}
bootstrap().catch(()=>{console.error('API initialization failed. Check environment configuration.');process.exit(1);});
