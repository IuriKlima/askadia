-- Questionnaire with CEP; preserves existing companies and authorization/versioning.
begin;
create or replace function private.onboarding_step(s public.company_onboarding) returns text language plpgsql immutable set search_path='' as $$
declare k text;
begin
 if s.confirmed_revision=s.revision then return 'complete'; end if;
 if coalesce(s.facts->'name'->>'status','')<>'provided' then return 'identity'; end if;
 if coalesce(s.facts->'city'->>'status','')<>'provided' and coalesce(s.facts->'postalCode'->>'status','')<>'provided' then
  if s.facts ? 'postalCode' then return 'city'; else return 'postalCode'; end if;
 end if;
 if not s.location_confirmed then return 'location'; end if;
 if coalesce(s.facts->'businessType'->>'status','')<>'provided' then return 'businessType'; end if;
 if not s.competitors_reviewed then return 'competitors'; end if;
 if not s.references_reviewed then return 'references'; end if;
 foreach k in array array['services','audience','objective','structure','hours','offers','sales','history','budget','brand','channels','video','management'] loop
  if not s.facts ? k then return k; end if;
 end loop;
 return 'review';
end;$$;
create or replace function private.onboarding_prompt(p_step text) returns text language sql immutable set search_path=public as $$ select case p_step when 'identity' then 'Qual é o nome do negócio? Vamos começar pela sua academia.' when 'postalCode' then 'Qual é o CEP da sua empresa?' when 'city' then 'Em qual cidade fica sua academia? Se puder, informe também o estado.' when 'businessType' then 'Que tipo de negócio é o seu: academia, estúdio ou outra atividade?' when 'location' then 'Vamos confirmar a localização da empresa. Informe o endereço ou a região atendida. Você pode conferir as opções no Google ou continuar manualmente.' when 'competitors' then 'Agora vamos conhecer os concorrentes locais. Revise os resultados da pesquisa ou indique quem disputa o mesmo público na sua região.' when 'references' then 'Quais marcas ou empresas você admira, mesmo de outras regiões? Conte o que gosta na comunicação, oferta, estética ou atendimento delas.' when 'services' then 'Quais serviços, aulas ou modalidades sua empresa oferece?' when 'audience' then 'Quem você quer atrair? Conte sobre o público, suas necessidades e principais objeções.' when 'objective' then 'Qual é o principal objetivo do marketing agora? Se souber, inclua uma meta e quantas pessoas sua equipe consegue atender.' when 'structure' then 'O que diferencia sua empresa? Conte sobre instalações, equipamentos, equipe e acessibilidade.' when 'hours' then 'Quais são os horários de funcionamento e os períodos que precisam de mais movimento?' when 'offers' then 'Quais planos, preços e condições podemos comunicar? Inclua validade e restrições das promoções. O que não souber fica pendente.' when 'sales' then 'Como uma pessoa interessada é atendida? Quem responde, em quais horários e como agenda uma visita ou aula experimental?' when 'history' then 'O que sua empresa já fez de marketing? Conte o que funcionou e o que gostaria de mudar.' when 'budget' then 'Existe um orçamento disponível para anúncios? Informar um valor aqui não autoriza nenhum gasto.' when 'brand' then 'Como sua marca deve se apresentar? Conte sobre cores, estilo e tom de voz. Você pode anexar logo, fotos e materiais autorizados agora ou depois.' when 'channels' then 'Sua empresa tem site, Instagram, Facebook ou WhatsApp? Informe os endereços ou diga quais ainda precisa criar. Isso não conecta as contas.' when 'video' then 'Sua equipe consegue gravar vídeos? Quem seria responsável e com qual frequência? Conteúdos estáticos também são uma opção.' when 'management' then 'Qual sistema de gestão sua empresa utiliza? Essa informação ajuda a planejar uma futura integração, sem conectar nada automaticamente.' when 'review' then 'Confira o resumo do seu negócio. Corrija o que precisar e confirme apenas as informações que podem orientar o trabalho dos agentes.' when 'complete' then 'Seu perfil está confirmado. O próximo passo é preparar a estratégia inicial desta empresa.' else 'Confira o resumo do seu negócio. Corrija o que precisar e confirme apenas as informações que podem orientar o trabalho dos agentes.' end $$;


create or replace function public.save_company_onboarding(p_company_id uuid,p_request_id uuid,p_revision integer,p_message text,p_patch jsonb,p_action text default 'reply',p_source text default 'user') returns jsonb language plpgsql security definer set search_path='' as $$
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
  if pair.key not in ('name','postalCode','city','businessType','address','services','audience','objective','structure','hours','offers','sales','history','budget','brand','channels','video','management','competitors','references','placeId','competitorPlaceIds') or jsonb_typeof(pair.value)<>'object' or coalesce(pair.value->>'status','') not in ('provided','unknown','deferred') then raise exception 'Invalid fact' using errcode='22023';end if;
  if (pair.value->>'status'='provided' and (jsonb_typeof(pair.value->'value')<>'string' or length(trim(coalesce(pair.value->>'value',''))) not between 1 and 6000)) or (pair.key in ('name','city','businessType') and length(coalesce(pair.value->>'value',''))>100) then raise exception 'Invalid fact value' using errcode='22023';end if;
  if pair.key='postalCode' and pair.value->>'status'='provided' and coalesce(pair.value->>'value','') !~ '^[0-9]{5}-?[0-9]{3}$' then raise exception 'Invalid postal code' using errcode='22023';end if;
  if pair.key='postalCode' and s.facts->'postalCode'->>'value' is distinct from pair.value->>'value' then
   if not p_patch ? 'city' then s.facts:=s.facts-'city';end if;
   if not p_patch ? 'address' then s.facts:=s.facts-'address';end if;
  end if;
  if pair.key in ('postalCode','city','address','placeId') and coalesce(s.facts->pair.key->>'value','')<>coalesce(pair.value->>'value','') then location_changed=true;end if;
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

create or replace function private.reset_onboarding_location() returns trigger language plpgsql security definer set search_path='' as $$
declare changed boolean;
begin
 changed:=(new.facts->'postalCode'->>'value' is distinct from old.facts->'postalCode'->>'value') or (old.facts->'name'->>'value' is not null and new.facts->'name'->>'value' is distinct from old.facts->'name'->>'value') or (new.facts->'city'->>'value' is distinct from old.facts->'city'->>'value') or (new.facts->'address'->>'value' is distinct from old.facts->'address'->>'value');
 if changed and old.facts->'placeId'->>'value' is not null and new.facts->'placeId' is not distinct from old.facts->'placeId' then
  new.facts:=new.facts-'placeId';new.location_confirmed:=false;new.competitors_reviewed:=false;
 end if;
 if (old.location_confirmed and not new.location_confirmed) or (old.facts->'placeId'->>'value' is not null and new.facts->'placeId'->>'value' is distinct from old.facts->'placeId'->>'value') then
  new.facts:=new.facts-'competitorPlaceIds'-'competitors';new.competitors_reviewed:=false;
 end if;
 return new;
end;$$;

commit;
