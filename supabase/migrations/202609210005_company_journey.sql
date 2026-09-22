-- Jornada persistente: aplicar depois de product_foundation e draft_import.
begin;
create table public.company_onboarding(
 company_id uuid primary key references public.companies(id),revision integer not null default 0 check(revision>=0),facts jsonb not null default '{}' check(jsonb_typeof(facts)='object'),
 location_confirmed boolean not null default false,competitors_reviewed boolean not null default false,references_reviewed boolean not null default false,
 confirmed_revision integer,profile_version integer not null default 0,updated_at timestamptz not null default now()
);
create table public.company_profile_versions(company_id uuid not null references public.companies(id),version integer not null check(version>0),facts jsonb not null,confirmed_by uuid not null references public.profiles(id),confirmed_at timestamptz not null default now(),primary key(company_id,version));
create table public.onboarding_messages(id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),role text not null check(role in ('user','assistant')),body text not null check(length(body) between 1 and 6000),actor_id uuid references public.profiles(id),request_id uuid,created_at timestamptz not null default now(),unique(company_id,request_id,role));
create table public.onboarding_attachments(id uuid primary key,company_id uuid not null references public.companies(id),name text not null check(length(name) between 1 and 180),mime text not null check(mime in ('image/jpeg','image/png','image/webp','application/pdf')),size integer not null check(size between 1 and 10485760),object_path text not null unique,uploaded_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create table public.company_creation_requests(actor_id uuid not null references public.profiles(id),request_id uuid not null,company_id uuid not null references public.companies(id),created_at timestamptz not null default now(),primary key(actor_id,request_id));
create table public.company_profile_impacts(id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),from_version integer not null,to_version integer not null,reason text not null,created_at timestamptz not null default now());
create table public.company_strategy_briefs(id uuid primary key default gen_random_uuid(),company_id uuid not null,profile_version integer not null,facts jsonb not null,requested_by uuid not null references public.profiles(id),status text not null default 'awaiting_configuration' check(status in ('awaiting_configuration','generating','review','approved','failed','superseded')),generation integer not null default 0,request_id uuid,output jsonb,model text,provider_response_id text,approved_by uuid references public.profiles(id),approved_generation integer,generated_at timestamptz,created_at timestamptz not null default now(),foreign key(company_id,profile_version) references public.company_profile_versions(company_id,version),unique(company_id,profile_version));
create table public.onboarding_provider_attempts(company_id uuid not null references public.companies(id),request_id uuid not null,kind text not null check(kind in ('interpretation','places','strategy')),actor_id uuid not null references public.profiles(id),created_at timestamptz not null default now(),primary key(company_id,request_id,kind));

create function private.onboarding_step(s public.company_onboarding) returns text language plpgsql immutable set search_path='' as $$
declare k text;
begin
 if s.confirmed_revision=s.revision then return 'complete'; end if;
 if coalesce(s.facts->'name'->>'status','')<>'provided' then return 'identity'; end if;
 if coalesce(s.facts->'city'->>'status','')<>'provided' then return 'city'; end if;
 if coalesce(s.facts->'businessType'->>'status','')<>'provided' then return 'businessType'; end if;
 if not s.location_confirmed then return 'location'; end if;
 if not s.competitors_reviewed then return 'competitors'; end if;
 if not s.references_reviewed then return 'references'; end if;
 foreach k in array array['services','audience','objective','structure','hours','offers','sales','history','budget','brand','channels','video','management'] loop
  if not s.facts ? k then return k; end if;
 end loop;
 return 'review';
end;$$;
create or replace function private.onboarding_prompt(p_step text) returns text language sql immutable set search_path=public as $$ select case p_step when 'identity' then 'Vamos conhecer sua empresa para preparar seu marketing. Qual é o nome do negócio e em qual cidade ele fica?' when 'city' then 'Em qual cidade ou região sua empresa atende?' when 'businessType' then 'Que tipo de negócio é o seu: academia, estúdio ou outra atividade?' when 'location' then 'Vamos confirmar a localização da empresa. Informe o endereço ou a região atendida. Você pode conferir as opções no Google ou continuar manualmente.' when 'competitors' then 'Agora vamos conhecer os concorrentes locais. Revise os resultados da pesquisa ou indique quem disputa o mesmo público na sua região.' when 'references' then 'Quais marcas ou empresas você admira, mesmo de outras regiões? Conte o que gosta na comunicação, oferta, estética ou atendimento delas.' when 'services' then 'Quais serviços, aulas ou modalidades sua empresa oferece?' when 'audience' then 'Quem você quer atrair? Conte sobre o público, suas necessidades e principais objeções.' when 'objective' then 'Qual é o principal objetivo do marketing agora? Se souber, inclua uma meta e quantas pessoas sua equipe consegue atender.' when 'structure' then 'O que diferencia sua empresa? Conte sobre instalações, equipamentos, equipe e acessibilidade.' when 'hours' then 'Quais são os horários de funcionamento e os períodos que precisam de mais movimento?' when 'offers' then 'Quais planos, preços e condições podemos comunicar? Inclua validade e restrições das promoções. O que não souber fica pendente.' when 'sales' then 'Como uma pessoa interessada é atendida? Quem responde, em quais horários e como agenda uma visita ou aula experimental?' when 'history' then 'O que sua empresa já fez de marketing? Conte o que funcionou e o que gostaria de mudar.' when 'budget' then 'Existe um orçamento disponível para anúncios? Informar um valor aqui não autoriza nenhum gasto.' when 'brand' then 'Como sua marca deve se apresentar? Conte sobre cores, estilo e tom de voz. Você pode anexar logo, fotos e materiais autorizados agora ou depois.' when 'channels' then 'Sua empresa tem site, Instagram, Facebook ou WhatsApp? Informe os endereços ou diga quais ainda precisa criar. Isso não conecta as contas.' when 'video' then 'Sua equipe consegue gravar vídeos? Quem seria responsável e com qual frequência? Conteúdos estáticos também são uma opção.' when 'management' then 'Qual sistema de gestão sua empresa utiliza? Essa informação ajuda a planejar uma futura integração, sem conectar nada automaticamente.' when 'review' then 'Confira o resumo do seu negócio. Corrija o que precisar e confirme apenas as informações que podem orientar o trabalho dos agentes.' when 'complete' then 'Seu perfil está confirmado. O próximo passo é preparar a estratégia inicial desta empresa.' else 'Confira o resumo do seu negócio. Corrija o que precisar e confirme apenas as informações que podem orientar o trabalho dos agentes.' end $$;

create function private.seed_company_onboarding() returns trigger language plpgsql security definer set search_path='' as $$
declare f jsonb='{}';
begin
 if new.name<>'Nova empresa' then
 f=jsonb_build_object('name',jsonb_build_object('value',new.name,'status','provided','source','existing','actorId',null,'updatedAt',now()),'businessType',jsonb_build_object('value',case new.segment when 'gym' then 'Academia' when 'studio' then 'Estúdio' else 'Outro' end,'status','provided','source','existing','actorId',null,'updatedAt',now()));
 if trim(coalesce(new.city,''))<>'' then f=f||jsonb_build_object('city',jsonb_build_object('value',new.city,'status','provided','source','existing','actorId',null,'updatedAt',now()));end if;
 end if;
 insert into public.company_onboarding(company_id,facts) values(new.id,f) on conflict do nothing;
 insert into public.onboarding_messages(company_id,role,body) select new.id,'assistant',private.onboarding_prompt(private.onboarding_step(s)) from public.company_onboarding s where s.company_id=new.id;
 return new;
end;$$;
create trigger seed_company_onboarding after insert on public.companies for each row execute function private.seed_company_onboarding();
insert into public.company_onboarding(company_id,facts) select id,
 jsonb_build_object('name',jsonb_build_object('value',name,'status','provided','source','existing','actorId',null,'updatedAt',now()),'businessType',jsonb_build_object('value',case segment when 'gym' then 'Academia' when 'studio' then 'Estúdio' else 'Outro' end,'status','provided','source','existing','actorId',null,'updatedAt',now()))||case when trim(coalesce(city,''))<>'' then jsonb_build_object('city',jsonb_build_object('value',city,'status','provided','source','existing','actorId',null,'updatedAt',now())) else '{}'::jsonb end from public.companies;
insert into public.onboarding_messages(company_id,role,body) select company_id,'assistant',private.onboarding_prompt(private.onboarding_step(s)) from public.company_onboarding s;

create function public.begin_company_onboarding(p_request_id uuid,p_workspace_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.companies;w uuid;
begin
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023';end if;
 perform private.ensure_profile();perform 1 from public.profiles where id=auth.uid() for update;
 select companies.* into c from public.company_creation_requests r join public.companies companies on companies.id=r.company_id where r.actor_id=auth.uid() and r.request_id=p_request_id;
 if found then
  if not private.workspace_owner(c.workspace_id) or c.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
  return jsonb_build_object('companyId',c.id,'workspaceId',c.workspace_id,'resumed',true);
 end if;
 w=p_workspace_id;
 if w is null then select workspace_id into w from public.workspace_members where user_id=auth.uid() and role='owner' order by workspace_id limit 1;
  if w is null then w=public.create_workspace('Meus negócios');end if;
 end if;
 perform 1 from public.workspaces where id=w for update;
 if not private.workspace_owner(w) then raise exception 'Only workspace owner creates companies' using errcode='42501';end if;
 -- Repeated clicks/two tabs resume the same untouched draft even with different request IDs.
 select companies.* into c from public.companies companies join public.company_onboarding s on s.company_id=companies.id
 where companies.workspace_id=w and companies.archived_at is null and companies.name='Nova empresa' and not s.facts ? 'name' order by companies.created_at limit 1;
 if not found then c=public.create_company(w,'Nova empresa','other','','America/Sao_Paulo');end if;
 insert into public.company_creation_requests(actor_id,request_id,company_id) values(auth.uid(),p_request_id,c.id);
 return jsonb_build_object('companyId',c.id,'workspaceId',w,'resumed',false);
end;$$;

create function public.company_onboarding_read(p_company_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.company_onboarding;
begin
 if not coalesce(private.can_company_action(p_company_id,'marketing.read'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if not found then raise exception 'Onboarding unavailable' using errcode='22023';end if;
 return jsonb_build_object('state',to_jsonb(s),'step',private.onboarding_step(s),'question',private.onboarding_prompt(private.onboarding_step(s)),
 'messages',coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at,m.role desc,m.id) from public.onboarding_messages m where company_id=p_company_id),'[]'),
 'attachments',coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at) from public.onboarding_attachments a where company_id=p_company_id),'[]'),
 'confirmedProfile',(select to_jsonb(v) from public.company_profile_versions v where company_id=p_company_id order by version desc limit 1),'capabilities',public.company_capabilities(p_company_id));
end;$$;

create function public.save_company_onboarding(p_company_id uuid,p_request_id uuid,p_revision integer,p_message text,p_patch jsonb,p_action text default 'reply',p_source text default 'user') returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;pair record;f jsonb;new_version integer;k text;location_changed boolean=false;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id for update;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023';end if;
 if exists(select 1 from public.onboarding_messages where company_id=p_company_id and request_id=p_request_id and role='user') then return public.company_onboarding_read(p_company_id);end if;
 if p_revision is null or s.revision<>p_revision then raise exception 'Profile changed; reload before saving' using errcode='40001';end if;
 if p_message is null or length(trim(p_message)) not between 1 and 6000 or p_patch is null or jsonb_typeof(p_patch)<>'object' or length(p_patch::text)>40000 or p_action is null or p_action not in ('reply','confirm_location','review_competitors','review_references','edit','confirm','reopen') or p_source is null or p_source not in ('user','assistant_suggestion') then raise exception 'Invalid reply' using errcode='22023';end if;
 if p_action='confirm' and p_patch<>'{}'::jsonb then raise exception 'Save edits before confirming' using errcode='22023';end if;
 for pair in select * from jsonb_each(p_patch) loop
  if pair.key not in ('name','city','businessType','address','services','audience','objective','structure','hours','offers','sales','history','budget','brand','channels','video','management','competitors','references','placeId','competitorPlaceIds') or jsonb_typeof(pair.value)<>'object' or coalesce(pair.value->>'status','') not in ('provided','unknown','deferred') then raise exception 'Invalid fact' using errcode='22023';end if;
  if (pair.value->>'status'='provided' and (jsonb_typeof(pair.value->'value')<>'string' or length(trim(coalesce(pair.value->>'value',''))) not between 1 and 6000)) or (pair.key in ('name','city','businessType') and length(coalesce(pair.value->>'value',''))>100) then raise exception 'Invalid fact value' using errcode='22023';end if;
  if pair.key in ('city','address','placeId') and coalesce(s.facts->pair.key->>'value','')<>coalesce(pair.value->>'value','') then location_changed=true;end if;
  f=jsonb_build_object('value',case when pair.value->>'status'='provided' then pair.value->>'value' else null end,'status',pair.value->>'status','source',p_source,'updatedAt',now(),'actorId',auth.uid());
  s.facts=jsonb_set(s.facts,array[pair.key],f);
 end loop;
 if location_changed then s.location_confirmed=false;s.competitors_reviewed=false;end if;
 if p_action='confirm_location' then
  if coalesce(s.facts->'name'->>'status','')<>'provided' or coalesce(s.facts->'city'->>'status','')<>'provided' then raise exception 'Name and region required' using errcode='22023';end if;
  s.location_confirmed=true;
 elsif p_action='review_competitors' then
  if not s.location_confirmed then raise exception 'Confirm location first' using errcode='22023';end if;s.competitors_reviewed=true;
 elsif p_action='review_references' then
  if not s.competitors_reviewed then raise exception 'Review local competitors first' using errcode='22023';end if;s.references_reviewed=true;
 elsif p_action='confirm' then
  if not s.location_confirmed or not s.competitors_reviewed or not s.references_reviewed then raise exception 'Review location, competitors and references' using errcode='22023';end if;
  foreach k in array array['name','city','businessType','services','audience','objective'] loop
   if coalesce(s.facts->k->>'status','')<>'provided' or trim(coalesce(s.facts->k->>'value',''))='' then raise exception 'Missing essential profile fact: %',k using errcode='22023';end if;
  end loop;
  new_version=s.profile_version+1;
  insert into public.company_profile_versions(company_id,version,facts,confirmed_by) values(p_company_id,new_version,s.facts,auth.uid());
  if s.profile_version>0 then
   insert into public.company_profile_impacts(company_id,from_version,to_version,reason) values(p_company_id,s.profile_version,new_version,'Perfil atualizado: revisar estratégia e materiais sem alterar aprovações.');
   update public.company_strategy_briefs set status='superseded' where company_id=p_company_id and profile_version<new_version;
  end if;
  s.profile_version=new_version;s.confirmed_revision=s.revision+1;
 else s.confirmed_revision=null;
 end if;
 s.revision=s.revision+1;
 update public.company_onboarding set revision=s.revision,facts=s.facts,location_confirmed=s.location_confirmed,competitors_reviewed=s.competitors_reviewed,references_reviewed=s.references_reviewed,confirmed_revision=s.confirmed_revision,profile_version=s.profile_version,updated_at=now() where company_id=p_company_id;
 if s.facts->'name'->>'status'='provided' then update public.companies set name=s.facts->'name'->>'value',city=coalesce(s.facts->'city'->>'value',city),segment=case when lower(s.facts->'businessType'->>'value') like '%academia%' then 'gym' when lower(s.facts->'businessType'->>'value') similar to '%(estúdio|estudio|studio|pilates)%' then 'studio' else segment end where id=p_company_id;end if;
 insert into public.onboarding_messages(company_id,role,body,actor_id,request_id) values(p_company_id,'user',trim(p_message),auth.uid(),p_request_id),(p_company_id,'assistant',private.onboarding_prompt(private.onboarding_step(s)),null,p_request_id);
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),case when p_action='confirm' then 'profile.confirmed' else 'onboarding.updated' end,jsonb_build_object('revision',s.revision,'version',s.profile_version,'action',p_action) from public.companies where id=p_company_id;
 return public.company_onboarding_read(p_company_id);
end;$$;

create function public.record_onboarding_attachment(p_company_id uuid,p_id uuid,p_name text,p_mime text,p_size integer,p_path text) returns jsonb language plpgsql security definer set search_path='' as $$
declare expected text;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 expected=p_company_id::text||'/onboarding/'||p_id::text||case p_mime when 'image/jpeg' then '.jpg' when 'image/png' then '.png' when 'image/webp' then '.webp' when 'application/pdf' then '.pdf' else '' end;
 if p_path is null or p_path<>expected or not exists(select 1 from storage.objects where bucket_id='company-assets' and name=p_path) then raise exception 'Upload the file first' using errcode='22023';end if;
 if not exists(select 1 from public.onboarding_attachments where id=p_id and company_id=p_company_id) then
  if (select count(*) from public.onboarding_attachments where company_id=p_company_id)>=50 or (select coalesce(sum(size),0)+p_size from public.onboarding_attachments where company_id=p_company_id)>104857600 then raise exception 'Attachment technical limit reached' using errcode='22023';end if;
  insert into public.onboarding_attachments(id,company_id,name,mime,size,object_path,uploaded_by) values(p_id,p_company_id,p_name,p_mime,p_size,p_path,auth.uid());
  insert into public.onboarding_messages(company_id,role,body,actor_id,request_id) values(p_company_id,'user','Material anexado: '||p_name,auth.uid(),p_id);
  insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'onboarding.attachment_added',jsonb_build_object('attachmentId',p_id) from public.companies where id=p_company_id;
 end if;
 return (select to_jsonb(a) from public.onboarding_attachments a where id=p_id and company_id=p_company_id);
end;$$;

create function public.prepare_company_strategy(p_company_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;b public.company_strategy_briefs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id for update;
 if s.confirmed_revision is null or s.confirmed_revision<>s.revision or s.profile_version<1 then raise exception 'Confirm the current profile first' using errcode='22023';end if;
 insert into public.company_strategy_briefs(company_id,profile_version,facts,requested_by) values(p_company_id,s.profile_version,s.facts,auth.uid()) on conflict(company_id,profile_version) do nothing;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
 return to_jsonb(b);
end;$$;

create table public.onboarding_provider_limits(company_id uuid not null references public.companies(id),kind text not null check(kind in ('interpretation','places','strategy')),daily_calls integer not null check(daily_calls between 0 and 200),primary key(company_id,kind));
alter table public.onboarding_provider_attempts add column outcome text,add column usage jsonb;
-- Technical daily ceilings for the onboarding included in a draft. No customer subscription or charge is created.
insert into public.onboarding_provider_limits(company_id,kind,daily_calls) select c.id,v.kind,v.calls from public.companies c cross join (values ('interpretation',40),('places',10),('strategy',2)) as v(kind,calls) on conflict do nothing;
create function private.seed_onboarding_limits() returns trigger language plpgsql security definer set search_path='' as $$begin insert into public.onboarding_provider_limits(company_id,kind,daily_calls) values(new.id,'interpretation',40),(new.id,'places',10),(new.id,'strategy',2);return new;end;$$;
create trigger seed_onboarding_limits after insert on public.companies for each row execute function private.seed_onboarding_limits();
revoke all on function private.seed_onboarding_limits() from public,anon,authenticated;
create function public.reserve_onboarding_provider(p_company_id uuid,p_request_id uuid,p_kind text) returns boolean language plpgsql security definer set search_path='' as $$
declare allowance integer;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_request_id is null or p_kind is null or p_kind not in ('interpretation','places','strategy') then raise exception 'Invalid provider request' using errcode='22023';end if;
 select daily_calls into allowance from public.onboarding_provider_limits where company_id=p_company_id and kind=p_kind;
 if coalesce(allowance,0)=0 or exists(select 1 from public.onboarding_provider_attempts where company_id=p_company_id and request_id=p_request_id and kind=p_kind) or (select count(*) from public.onboarding_provider_attempts where company_id=p_company_id and kind=p_kind and created_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=allowance then return false;end if;
 insert into public.onboarding_provider_attempts(company_id,request_id,kind,actor_id) values(p_company_id,p_request_id,p_kind,auth.uid());return true;
end;$$;
create function public.finish_onboarding_provider(p_company_id uuid,p_request_id uuid,p_kind text,p_outcome text,p_usage jsonb default '{}') returns void language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if p_outcome is null or p_usage is null or p_outcome not in ('completed','failed','refused','incomplete') or length(p_usage::text)>2000 then raise exception 'Invalid outcome' using errcode='22023';end if;
 update public.onboarding_provider_attempts set outcome=p_outcome,usage=p_usage where company_id=p_company_id and request_id=p_request_id and kind=p_kind and actor_id=auth.uid() and outcome is null;
end;$$;

create table public.company_followup_meetings(id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),session_id uuid not null references public.internal_access_sessions(id),operator_id uuid not null references public.profiles(id),request_id uuid not null,meeting_date date not null,participants text not null check(length(participants) between 2 and 1000),decisions text not null check(length(decisions) between 2 and 6000),next_actions text not null check(length(next_actions) between 2 and 6000),created_at timestamptz not null default now(),unique(operator_id,request_id));
create function public.internal_onboarding_context(p_session_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare context jsonb;c uuid;
begin
 context=public.internal_company_context(p_session_id);c=(context->'company'->>'id')::uuid;
 if (context->'company'->>'archived_at') is not null then raise exception 'Archived company' using errcode='42501';end if;
 return jsonb_build_object('companyId',c,'profile',(select to_jsonb(s) from public.company_onboarding s where company_id=c),'confirmedProfile',(select to_jsonb(v) from public.company_profile_versions v where company_id=c order by version desc limit 1),'meetings',coalesce((select jsonb_agg(to_jsonb(m) order by created_at desc) from public.company_followup_meetings m where company_id=c),'[]'));
end;$$;
create function public.record_followup_meeting(p_session_id uuid,p_request_id uuid,p_date date,p_participants text,p_decisions text,p_next_actions text) returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb;c uuid;m public.company_followup_meetings;
begin
 context=public.internal_onboarding_context(p_session_id);c=(context->>'companyId')::uuid;
 perform 1 from public.companies where id=c for update;
 context=public.internal_onboarding_context(p_session_id);
 insert into public.company_followup_meetings(company_id,session_id,operator_id,request_id,meeting_date,participants,decisions,next_actions) values(c,p_session_id,auth.uid(),p_request_id,p_date,p_participants,p_decisions,p_next_actions) on conflict(operator_id,request_id) do nothing;
 select * into m from public.company_followup_meetings where operator_id=auth.uid() and request_id=p_request_id and company_id=c;
 if not found then raise exception 'Request belongs to another company' using errcode='22023';end if;
 insert into public.platform_audit(actor_id,company_id,session_id,action,details) values(auth.uid(),c,p_session_id,'followup.meeting_recorded',jsonb_build_object('meetingId',m.id));return to_jsonb(m);
end;$$;

-- Clients can read only their current authorized company data. All writes use RPCs.
do $$ declare t text;begin
 foreach t in array array['company_onboarding','company_profile_versions','onboarding_messages','onboarding_attachments','company_profile_impacts','company_strategy_briefs','company_followup_meetings'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('create policy company_read on public.%I for select to authenticated using (private.can_company_action(company_id,''marketing.read''))',t);
 end loop;
 foreach t in array array['company_creation_requests','onboarding_provider_limits','onboarding_provider_attempts'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);
 end loop;
end;$$;
revoke all on function private.onboarding_step(public.company_onboarding),private.onboarding_prompt(text),private.seed_company_onboarding() from public,anon,authenticated;
revoke all on function public.begin_company_onboarding(uuid,uuid),public.company_onboarding_read(uuid),public.save_company_onboarding(uuid,uuid,integer,text,jsonb,text,text),public.record_onboarding_attachment(uuid,uuid,text,text,integer,text),public.prepare_company_strategy(uuid),public.reserve_onboarding_provider(uuid,uuid,text),public.finish_onboarding_provider(uuid,uuid,text,text,jsonb),public.internal_onboarding_context(uuid),public.record_followup_meeting(uuid,uuid,date,text,text,text) from public,anon;
grant execute on function public.begin_company_onboarding(uuid,uuid),public.company_onboarding_read(uuid),public.save_company_onboarding(uuid,uuid,integer,text,jsonb,text,text),public.record_onboarding_attachment(uuid,uuid,text,text,integer,text),public.prepare_company_strategy(uuid),public.reserve_onboarding_provider(uuid,uuid,text),public.finish_onboarding_provider(uuid,uuid,text,text,jsonb),public.internal_onboarding_context(uuid),public.record_followup_meeting(uuid,uuid,date,text,text,text) to authenticated;
-- Maintain a single profile when a legacy metadata endpoint is used.
create function private.sync_company_metadata() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding; f jsonb='{}';
begin
 select * into s from public.company_onboarding where company_id=new.id for update;
 if not found then return new;end if;
 if old.name is distinct from new.name and s.facts->'name'->>'value' is distinct from new.name then f=f||jsonb_build_object('name',jsonb_build_object('value',new.name,'status','provided','source','user','actorId',auth.uid(),'updatedAt',now()));end if;
 if old.city is distinct from new.city and s.facts->'city'->>'value' is distinct from new.city then f=f||jsonb_build_object('city',jsonb_build_object('value',nullif(new.city,''),'status',case when new.city='' then 'unknown' else 'provided' end,'source','user','actorId',auth.uid(),'updatedAt',now()));end if;
 if f<>'{}' then
  update public.company_onboarding set facts=facts||f,revision=revision+1,confirmed_revision=null,location_confirmed=case when f?'city' then false else location_confirmed end,competitors_reviewed=case when f?'city' then false else competitors_reviewed end,updated_at=now() where company_id=new.id;
  insert into public.onboarding_messages(company_id,role,body) values(new.id,'assistant','O cadastro da empresa foi atualizado. Revise o perfil antes de confirmar uma nova versão.');
 end if;return new;
end;$$;
create trigger sync_company_metadata after update of name,city on public.companies for each row execute function private.sync_company_metadata();
revoke all on function private.sync_company_metadata() from public,anon,authenticated;

create table public.company_strategy_history(company_id uuid not null references public.companies(id),brief_id uuid not null references public.company_strategy_briefs(id),generation integer not null,profile_version integer not null,output jsonb not null,model text not null,approved_by uuid references public.profiles(id),approved_at timestamptz,created_at timestamptz not null default now(),primary key(brief_id,generation));
alter table public.company_strategy_history enable row level security;
revoke all on public.company_strategy_history from public,anon,authenticated;
grant select on public.company_strategy_history to authenticated;
create policy company_read on public.company_strategy_history for select to authenticated using(private.can_company_action(company_id,'marketing.read'));

create function public.start_company_strategy(p_company_id uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;b public.company_strategy_briefs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if s.confirmed_revision is distinct from s.revision then raise exception 'Confirm the current profile first' using errcode='22023';end if;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
 if b.id is null then perform public.prepare_company_strategy(p_company_id);select * into b from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;end if;
 if b.status='generating' and b.created_at>now()-interval '5 minutes' then raise exception 'Generation already running' using errcode='40001';end if;
 if not public.reserve_onboarding_provider(p_company_id,p_request_id,'strategy') then raise exception 'Strategy usage allowance unavailable' using errcode='22023';end if;
 update public.company_strategy_briefs set status='generating',request_id=p_request_id,generation=generation+1,output=null,approved_by=null,approved_generation=null,created_at=now() where id=b.id returning * into b;
 return to_jsonb(b);
end;$$;
create function public.finish_company_strategy(p_company_id uuid,p_request_id uuid,p_output jsonb,p_model text,p_response_id text) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.company_strategy_briefs;s public.company_onboarding;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into b from public.company_strategy_briefs where company_id=p_company_id and request_id=p_request_id and status='generating' for update;
 if b.id is null then raise exception 'Generation unavailable' using errcode='40001';end if;
 if p_output is not null and (jsonb_typeof(p_output)<>'object' or length(p_output::text)>100000 or not (p_output ?& array['positioning','objectives','calendar','ads','keywords','unknowns']) or jsonb_typeof(p_output->'keywords')<>'array' or jsonb_array_length(p_output->'keywords')<>20 or length(coalesce(p_model,'')) not between 1 and 100 or length(coalesce(p_response_id,'')) not between 1 and 200) then raise exception 'Invalid strategy' using errcode='22023';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 update public.company_strategy_briefs set status=case when s.profile_version<>b.profile_version or s.confirmed_revision is distinct from s.revision then 'superseded' when p_output is null then 'failed' else 'review' end,output=p_output,model=p_model,provider_response_id=p_response_id,generated_at=now() where id=b.id returning * into b;
 if p_output is not null then insert into public.company_strategy_history(company_id,brief_id,generation,profile_version,output,model) values(p_company_id,b.id,b.generation,b.profile_version,p_output,p_model);end if;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'strategy.generated',jsonb_build_object('briefId',b.id,'generation',b.generation,'status',b.status) from public.companies where id=p_company_id;
 return to_jsonb(b);
end;$$;
create function public.approve_company_strategy(p_company_id uuid,p_brief_id uuid,p_generation integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare b public.company_strategy_briefs;s public.company_onboarding;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'strategy.approve'),false) then raise exception 'Approval permission required' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 select * into b from public.company_strategy_briefs where id=p_brief_id and company_id=p_company_id for update;
 if b.id is null or b.status<>'review' or b.generation is distinct from p_generation or b.profile_version<>s.profile_version or s.confirmed_revision is distinct from s.revision then raise exception 'Strategy changed; review current version' using errcode='40001';end if;
 update public.company_strategy_briefs set status='approved',approved_by=auth.uid(),approved_generation=generation where id=b.id returning * into b;
 update public.company_strategy_history set approved_by=auth.uid(),approved_at=now() where brief_id=b.id and generation=b.generation;
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'strategy.approved',jsonb_build_object('briefId',b.id,'generation',b.generation) from public.companies where id=p_company_id;
 return to_jsonb(b);
end;$$;
revoke all on function public.start_company_strategy(uuid,uuid),public.finish_company_strategy(uuid,uuid,jsonb,text,text),public.approve_company_strategy(uuid,uuid,integer) from public,anon;
grant execute on function public.start_company_strategy(uuid,uuid),public.finish_company_strategy(uuid,uuid,jsonb,text,text),public.approve_company_strategy(uuid,uuid,integer) to authenticated;

notify pgrst,'reload schema';
commit;
