begin;
create or replace function private.onboarding_step(s public.company_onboarding) returns text language plpgsql immutable set search_path='' as $$
declare k text;
begin
 if s.confirmed_revision=s.revision then return 'complete'; end if;
 if coalesce(s.facts->'name'->>'status','')<>'provided' then return 'identity'; end if;
 if coalesce(s.facts->'city'->>'status','')<>'provided' then return 'city'; end if;
 if not s.location_confirmed then return 'location'; end if;
 if coalesce(s.facts->'businessType'->>'status','')<>'provided' then return 'businessType'; end if;
 if not s.competitors_reviewed then return 'competitors'; end if;
 if not s.references_reviewed then return 'references'; end if;
 foreach k in array array['services','audience','objective','structure','hours','offers','sales','history','budget','brand','channels','video','management'] loop
  if not s.facts ? k then return k; end if;
 end loop;
 return 'review';
end;$$;
create or replace function private.onboarding_prompt(p_step text) returns text language sql immutable set search_path=public as $$ select case p_step when 'identity' then 'Qual é o nome do negócio? Vamos começar pela sua academia.' when 'city' then 'Em qual cidade fica sua academia? Se puder, informe também o estado.' when 'businessType' then 'Que tipo de negócio é o seu: academia, estúdio ou outra atividade?' when 'location' then 'Vamos confirmar a localização da empresa. Informe o endereço ou a região atendida. Você pode conferir as opções no Google ou continuar manualmente.' when 'competitors' then 'Agora vamos conhecer os concorrentes locais. Revise os resultados da pesquisa ou indique quem disputa o mesmo público na sua região.' when 'references' then 'Quais marcas ou empresas você admira, mesmo de outras regiões? Conte o que gosta na comunicação, oferta, estética ou atendimento delas.' when 'services' then 'Quais serviços, aulas ou modalidades sua empresa oferece?' when 'audience' then 'Quem você quer atrair? Conte sobre o público, suas necessidades e principais objeções.' when 'objective' then 'Qual é o principal objetivo do marketing agora? Se souber, inclua uma meta e quantas pessoas sua equipe consegue atender.' when 'structure' then 'O que diferencia sua empresa? Conte sobre instalações, equipamentos, equipe e acessibilidade.' when 'hours' then 'Quais são os horários de funcionamento e os períodos que precisam de mais movimento?' when 'offers' then 'Quais planos, preços e condições podemos comunicar? Inclua validade e restrições das promoções. O que não souber fica pendente.' when 'sales' then 'Como uma pessoa interessada é atendida? Quem responde, em quais horários e como agenda uma visita ou aula experimental?' when 'history' then 'O que sua empresa já fez de marketing? Conte o que funcionou e o que gostaria de mudar.' when 'budget' then 'Existe um orçamento disponível para anúncios? Informar um valor aqui não autoriza nenhum gasto.' when 'brand' then 'Como sua marca deve se apresentar? Conte sobre cores, estilo e tom de voz. Você pode anexar logo, fotos e materiais autorizados agora ou depois.' when 'channels' then 'Sua empresa tem site, Instagram, Facebook ou WhatsApp? Informe os endereços ou diga quais ainda precisa criar. Isso não conecta as contas.' when 'video' then 'Sua equipe consegue gravar vídeos? Quem seria responsável e com qual frequência? Conteúdos estáticos também são uma opção.' when 'management' then 'Qual sistema de gestão sua empresa utiliza? Essa informação ajuda a planejar uma futura integração, sem conectar nada automaticamente.' when 'review' then 'Confira o resumo do seu negócio. Corrija o que precisar e confirme apenas as informações que podem orientar o trabalho dos agentes.' when 'complete' then 'Seu perfil está confirmado. O próximo passo é preparar a estratégia inicial desta empresa.' else 'Confira o resumo do seu negócio. Corrija o que precisar e confirme apenas as informações que podem orientar o trabalho dos agentes.' end $$;


-- Google responses are not archived. Store place IDs and the names confirmed by the client.
create table public.company_competitor_research(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 place_id text not null check(place_id ~ '^[A-Za-z0-9_-]{5,200}$'),label text not null check(length(label) between 1 and 160),city text not null,
 actor_id uuid not null references public.profiles(id),status text not null default 'pending' check(status in ('pending','running','ready','failed','stale')),
 candidates jsonb not null default '[]',selected_username text,attempts integer not null default 0,token uuid,lease_until timestamptz,
 next_attempt_at timestamptz not null default now(),error text,collected_at timestamptz,confirmed_at timestamptz not null default now(),unique(company_id,place_id)
);
alter table public.company_competitor_research enable row level security;
revoke all on public.company_competitor_research from public,anon,authenticated;
grant select on public.company_competitor_research to authenticated;
create policy company_read on public.company_competitor_research for select to authenticated using(private.can_company_action(company_id,'marketing.read'));
create index competitor_research_queue on public.company_competitor_research(next_attempt_at) where status in ('pending','running');
alter table public.company_instagram_watches add column place_id text;

create function public.review_onboarding_competitors(p_company_id uuid,p_request_id uuid,p_revision integer,p_places jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;p jsonb;ids text;names text;saved jsonb;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 if exists(select 1 from public.onboarding_messages where company_id=p_company_id and request_id=p_request_id and role='user') then return public.company_onboarding_read(p_company_id);end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if not s.location_confirmed then raise exception 'Confirm location first' using errcode='22023';end if;
 if p_places is null or jsonb_typeof(p_places)<>'array' or jsonb_array_length(p_places)>10 or length(p_places::text)>8000 then raise exception 'Select up to ten competitors' using errcode='22023';end if;
 for p in select value from jsonb_array_elements(p_places) loop
  if jsonb_typeof(p)<>'object' or coalesce(p->>'placeId','') !~ '^[A-Za-z0-9_-]{5,200}$' or length(trim(coalesce(p->>'label',''))) not between 1 and 160 or p->>'placeId'=s.facts->'placeId'->>'value' then raise exception 'Invalid competitor' using errcode='22023';end if;
 end loop;
 if (select count(distinct value->>'placeId') from jsonb_array_elements(p_places))<>jsonb_array_length(p_places) then raise exception 'Duplicate competitor' using errcode='22023';end if;
 select string_agg(value->>'placeId',E'
' order by n),string_agg(value->>'label',E'
' order by n) into ids,names from jsonb_array_elements(p_places) with ordinality x(value,n);
 saved:=public.save_company_onboarding(p_company_id,p_request_id,p_revision,'Conferi os nomes e selecionei os concorrentes locais.',jsonb_build_object('competitorPlaceIds',jsonb_build_object('value',ids,'status',case when ids is null then 'deferred' else 'provided' end),'competitors',case when names is null then coalesce(s.facts->'competitors',jsonb_build_object('value',null,'status','deferred')) else jsonb_build_object('value',names,'status','provided') end),'review_competitors');
 delete from public.company_instagram_watches where company_id=p_company_id and place_id is not null and not exists(select 1 from jsonb_array_elements(p_places) x where x->>'placeId'=place_id);
 delete from public.company_competitor_research where company_id=p_company_id and not exists(select 1 from jsonb_array_elements(p_places) x where x->>'placeId'=place_id);
 for p in select value from jsonb_array_elements(p_places) loop
  delete from public.company_instagram_watches w using public.company_competitor_research r where w.company_id=p_company_id and r.company_id=w.company_id and w.place_id=r.place_id and r.place_id=p->>'placeId' and (r.label is distinct from trim(p->>'label') or r.city is distinct from s.facts->'city'->>'value');
  insert into public.company_competitor_research(company_id,place_id,label,city,actor_id) values(p_company_id,p->>'placeId',trim(p->>'label'),s.facts->'city'->>'value',auth.uid())
  on conflict(company_id,place_id) do update set label=excluded.label,city=excluded.city,actor_id=excluded.actor_id,
   status=case when company_competitor_research.label=excluded.label and company_competitor_research.city=excluded.city and company_competitor_research.status='ready' then 'ready' else 'pending' end,
   candidates=case when company_competitor_research.label=excluded.label and company_competitor_research.city=excluded.city and company_competitor_research.status='ready' then company_competitor_research.candidates else '[]'::jsonb end,
   attempts=0,token=null,lease_until=null,next_attempt_at=now(),error=null,confirmed_at=now();
 end loop;
 return saved;
end;$$;

-- Clear stale identifiers when the client changes the business or its location.
create function private.reset_onboarding_location() returns trigger language plpgsql security definer set search_path='' as $$
declare changed boolean;
begin
 changed:=(old.facts->'name'->>'value' is not null and new.facts->'name'->>'value' is distinct from old.facts->'name'->>'value') or (new.facts->'city'->>'value' is distinct from old.facts->'city'->>'value') or (new.facts->'address'->>'value' is distinct from old.facts->'address'->>'value');
 if changed and old.facts->'placeId'->>'value' is not null and new.facts->'placeId' is not distinct from old.facts->'placeId' then
  new.facts:=new.facts-'placeId';new.location_confirmed:=false;new.competitors_reviewed:=false;
 end if;
 if (old.location_confirmed and not new.location_confirmed) or (old.facts->'placeId'->>'value' is not null and new.facts->'placeId'->>'value' is distinct from old.facts->'placeId'->>'value') then
  new.facts:=new.facts-'competitorPlaceIds'-'competitors';new.competitors_reviewed:=false;
 end if;
 return new;
end;$$;
create trigger reset_onboarding_location before update of facts on public.company_onboarding for each row execute function private.reset_onboarding_location();
revoke all on function private.reset_onboarding_location() from public,anon,authenticated;

-- Changing the place or region must not carry research from the previous location.
create function private.invalidate_onboarding_research() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not new.location_confirmed or new.facts->'city'->>'value' is distinct from old.facts->'city'->>'value' or new.facts->'placeId'->>'value' is distinct from old.facts->'placeId'->>'value' then
  update public.company_competitor_research set status='stale',token=null,candidates='[]',selected_username=null,error='A localização mudou. Revise os concorrentes locais.' where company_id=new.company_id;
  delete from public.company_instagram_watches where company_id=new.company_id and place_id is not null;
 end if;return new;
end;$$;
create trigger invalidate_onboarding_research after update of facts,location_confirmed on public.company_onboarding for each row execute function private.invalidate_onboarding_research();

create function public.claim_competitor_research_server() returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.company_competitor_research;t uuid:=gen_random_uuid();allowed boolean;
begin
 update public.company_competitor_research set status='failed',token=null,lease_until=null,error='A pesquisa foi interrompida. Tente novamente.' where status='running' and lease_until<now() and attempts>=3;
 select r.* into j from public.company_competitor_research r join public.company_onboarding s on s.company_id=r.company_id
 where private.company_ai_access(r.company_id) and s.confirmed_revision=s.revision and s.competitors_reviewed and r.selected_username is null and r.attempts<3 and ((r.status='pending' and r.next_attempt_at<=now()) or (r.status='running' and r.lease_until<now())) order by r.next_attempt_at limit 1;
 if not found then return null;end if;
 perform 1 from public.companies where id=j.company_id for update skip locked;if not found then return null;end if;
 select * into j from public.company_competitor_research where id=j.id and selected_username is null and attempts<3 and ((status='pending' and next_attempt_at<=now()) or (status='running' and lease_until<now())) for update skip locked;if not found then return null;end if;
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',j.actor_id,'role','authenticated')::text,true);
 if not coalesce(private.can_company_action(j.company_id,'marketing.write'),false) then update public.company_competitor_research set status='stale',token=null,error='A permissão mudou. Revise a seleção.' where id=j.id;return null;end if;
 if not private.company_ai_access(j.company_id) or not exists(select 1 from public.company_onboarding where company_id=j.company_id and confirmed_revision=revision and competitors_reviewed and location_confirmed) then return null;end if;
 begin allowed:=public.reserve_onboarding_provider(j.company_id,t,'interpretation');exception when sqlstate '22023' then allowed:=false;end;
 if not allowed then update public.company_competitor_research set next_attempt_at=now()+interval '1 hour',error='A pesquisa será retomada quando o limite estiver disponível.' where id=j.id;return null;end if;
 update public.company_competitor_research set status='running',token=t,lease_until=now()+interval '2 minutes',attempts=attempts+1,error=null where id=j.id;
 return jsonb_build_object('id',j.id,'companyId',j.company_id,'token',t,'query',j.label,'city',j.city);
end;$$;
create function public.finish_competitor_research_server(p_id uuid,p_token uuid,p_candidates jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare j public.company_competitor_research;p jsonb;
begin
 select * into j from public.company_competitor_research where id=p_id and status='running' and token=p_token and lease_until>now();if not found then return false;end if;
 perform 1 from public.companies where id=j.company_id for update;
 select * into j from public.company_competitor_research where id=p_id and status='running' and token=p_token and lease_until>now() for update;if not found then return false;end if;
 perform set_config('request.jwt.claim.sub',j.actor_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',j.actor_id,'role','authenticated')::text,true);
 if not coalesce(private.can_company_action(j.company_id,'marketing.write'),false) or not private.company_ai_access(j.company_id) or not exists(select 1 from public.company_onboarding where company_id=j.company_id and confirmed_revision=revision and competitors_reviewed and location_confirmed) then
  update public.company_competitor_research set status='pending',token=null,lease_until=null,next_attempt_at=now()+interval '1 hour',error='A pesquisa aguarda perfil, plano e acesso válidos.' where id=j.id;return false;
 end if;
 if p_candidates is not null then
  if jsonb_typeof(p_candidates)<>'array' or jsonb_array_length(p_candidates)>8 or length(p_candidates::text)>20000 then raise exception 'Invalid candidates' using errcode='22023';end if;
  for p in select value from jsonb_array_elements(p_candidates) loop
   if coalesce(p->>'username','') !~ '^[a-z0-9_][a-z0-9_.]{0,29}$' or p->>'url' is distinct from 'https://www.instagram.com/'||(p->>'username')||'/' then raise exception 'Invalid candidate source' using errcode='22023';end if;
  end loop;
 end if;
 perform public.finish_onboarding_provider(j.company_id,p_token,'interpretation',case when p_candidates is null then 'failed' else 'completed' end);
 update public.company_competitor_research set status=case when p_candidates is not null then 'ready' when attempts>=3 then 'failed' else 'pending' end,
 candidates=coalesce(p_candidates,candidates),collected_at=case when p_candidates is not null then now() else collected_at end,token=null,lease_until=null,next_attempt_at=now()+interval '5 minutes',
 error=case when p_candidates is null then 'Não foi possível encontrar os perfis agora. Você pode informar o @ ou tentar novamente.' else null end where id=j.id;return true;
end;$$;

create function public.select_competitor_instagram(p_company_id uuid,p_place_id text,p_username text,p_remove boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare j public.company_competitor_research;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 select * into j from public.company_competitor_research where company_id=p_company_id and place_id=p_place_id and status<>'stale' for update;
 if not found then raise exception 'Review local competitor first' using errcode='22023';end if;
 if p_remove and j.selected_username is distinct from p_username then raise exception 'Profile link changed; reload before removing' using errcode='40001';end if;
 if exists(select 1 from public.company_instagram_watches where company_id=p_company_id and username=p_username and place_id is not null and place_id<>p_place_id) then raise exception 'Profile already linked to another competitor' using errcode='22023';end if;
 if j.selected_username is not null and (j.selected_username<>p_username or p_remove) then delete from public.company_instagram_watches where company_id=p_company_id and place_id=p_place_id;end if;
 perform public.save_instagram_watch(p_company_id,p_username,j.label,'local',p_remove);
 if not p_remove then update public.company_instagram_watches set place_id=p_place_id where company_id=p_company_id and username=p_username;end if;
 update public.company_competitor_research set selected_username=case when p_remove then null else p_username end where id=j.id;
end;$$;
create function private.clear_competitor_instagram_link() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.place_id is not null then update public.company_competitor_research set selected_username=null where company_id=old.company_id and place_id=old.place_id and selected_username=old.username;end if;
 return old;
end;$$;
create trigger clear_competitor_instagram_link after delete on public.company_instagram_watches for each row execute function private.clear_competitor_instagram_link();
revoke all on function private.clear_competitor_instagram_link() from public,anon,authenticated;
create function public.retry_competitor_research(p_company_id uuid,p_place_id text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'marketing.write'),false) then raise exception 'Access denied' using errcode='42501';end if;
 perform private.require_ai_access(p_company_id);
 update public.company_competitor_research set status='pending',attempts=0,next_attempt_at=now(),error=null where company_id=p_company_id and place_id=p_place_id and status in ('failed','ready');
end;$$;
revoke all on function public.review_onboarding_competitors(uuid,uuid,integer,jsonb),public.select_competitor_instagram(uuid,text,text,boolean),public.retry_competitor_research(uuid,text) from public,anon;
grant execute on function public.review_onboarding_competitors(uuid,uuid,integer,jsonb),public.select_competitor_instagram(uuid,text,text,boolean),public.retry_competitor_research(uuid,text) to authenticated;
revoke all on function public.claim_competitor_research_server(),public.finish_competitor_research_server(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.claim_competitor_research_server(),public.finish_competitor_research_server(uuid,uuid,jsonb) to service_role;
revoke all on function private.invalidate_onboarding_research() from public,anon,authenticated;
create or replace function private.journey_basis(c uuid,n integer) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v integer;data jsonb;prev jsonb;
begin
 select profile_version into v from public.company_onboarding where company_id=c;
 select coalesce(jsonb_agg(jsonb_build_object('stage',stage,'token',token) order by stage),'[]'::jsonb) into prev from public.company_marketing_approvals where company_id=c and profile_version=v and stage<n;
 if n=1 then
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'username',username,'label',label,'kind',kind) order by id),'[]'::jsonb) into data from public.company_instagram_watches where company_id=c;
  if exists(select 1 from public.company_competitor_research where company_id=c and status<>'stale') then
 select jsonb_build_object('profiles',coalesce((select jsonb_agg(jsonb_build_object('id',id,'username',username,'label',label,'kind',kind,'placeId',place_id) order by id) from public.company_instagram_watches where company_id=c),'[]'::jsonb),'localCompetitors',coalesce((select jsonb_agg(jsonb_build_object('placeId',place_id,'label',label,'city',city,'username',selected_username) order by place_id) from public.company_competitor_research where company_id=c and status<>'stale'),'[]'::jsonb)) into data;
  end if;
 elsif n=2 then select jsonb_build_object('id',id,'generation',generation,'output',output,'analysisCurrent',competitor_review_token is not distinct from (select token from public.company_marketing_approvals where company_id=c and profile_version=v and stage=1)) into data from public.company_strategy_briefs where company_id=c and profile_version=v;
 elsif n=3 then select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'date',i.planned_date,'idea',i.idea,'direction',i.direction,'format',i.format) order by i.position),'[]'::jsonb) into data from public.company_calendar_items i join public.company_strategy_briefs b on b.id=i.brief_id and b.generation=i.generation where i.company_id=c and b.profile_version=v;
 else select case when n=4 then jsonb_build_object('whatsapp',output->'whatsapp','messages',output->'messages') else output->'traffic' end into data from public.company_launch_jobs where company_id=c and profile_version=v and kind='recommendations' and status='completed';end if;
 return jsonb_build_object('profileVersion',v,'previous',prev,'data',data);
end;$$;

create or replace function public.approve_marketing_stage(p_company_id uuid,p_stage integer,p_basis text,p_limitations text default '',p_evidence_basis text default null) returns void language plpgsql security definer set search_path='' as $$
declare s public.company_onboarding;b jsonb;snap jsonb;brief public.company_strategy_briefs;
begin
 perform 1 from public.companies where id=p_company_id for update;
 if not coalesce(private.can_company_action(p_company_id,'strategy.approve'),false) then raise exception 'Approval permission required' using errcode='42501';end if;
 select * into s from public.company_onboarding where company_id=p_company_id;
 if p_stage is null or p_stage not between 1 and 5 or s.profile_version<1 or s.confirmed_revision is distinct from s.revision then raise exception 'Confirm current profile' using errcode='22023';end if;
 if p_stage>1 and not private.journey_valid(p_company_id,p_stage-1) then raise exception 'Approve previous stages first' using errcode='40001';end if;
 if p_stage=1 and p_evidence_basis is distinct from md5(private.competitor_review(p_company_id)::text) then raise exception 'A coleta mudou. Revise os dados atualizados antes de aprovar.' using errcode='40001';end if;
 b:=private.journey_basis(p_company_id,p_stage);if p_basis is distinct from md5(b::text) then raise exception 'Proposal changed; review current version' using errcode='40001';end if;
 -- Repeating the approval of an unchanged version must not invalidate downstream work.
 if private.journey_valid(p_company_id,p_stage) and exists(select 1 from public.company_marketing_approvals a where a.company_id=p_company_id and a.profile_version=s.profile_version and a.stage=p_stage and a.basis=p_basis) then return;end if;
 if p_stage=1 then
  if (exists(select 1 from public.company_competitor_research where company_id=p_company_id and status<>'stale' and selected_username is null) or not exists(select 1 from public.company_instagram_watches where company_id=p_company_id) or exists(select 1 from public.company_instagram_watches where company_id=p_company_id and snapshot is null)) and length(trim(coalesce(p_limitations,'')))<10 then raise exception 'Review missing competitor data explicitly' using errcode='22023';end if;
  if length(coalesce(p_limitations,''))>1000 then raise exception 'Invalid limitation' using errcode='22023';end if;
  select jsonb_build_object('profiles',coalesce(jsonb_agg(jsonb_build_object('username',username,'label',label,'kind',kind,'snapshot',snapshot) order by id),'[]'::jsonb),'limitations',p_limitations) into snap from public.company_instagram_watches where company_id=p_company_id;
 snap:=snap||jsonb_build_object('localCompetitors',coalesce(b->'data'->'localCompetitors','[]'::jsonb));
 elsif p_stage=2 then
  select * into brief from public.company_strategy_briefs where company_id=p_company_id and profile_version=s.profile_version;
  if brief.competitor_review_token is distinct from (select token from public.company_marketing_approvals where company_id=p_company_id and profile_version=s.profile_version and stage=1) then raise exception 'A análise mudou. Gere um novo diagnóstico.' using errcode='40001';end if;
  if brief.output is null or brief.status not in ('review','approved') then raise exception 'Strategy not ready' using errcode='22023';end if;
  update public.company_launch_jobs set status='pending',attempts=0,output=null,token=null,next_attempt_at=now(),updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and kind='recommendations' and status in ('completed','stale','failed');
  if brief.status='review' then perform public.approve_company_strategy(p_company_id,brief.id,brief.generation);end if;snap:=b->'data';
 elsif p_stage=3 then
  if jsonb_array_length(b->'data')=0 or exists(select 1 from jsonb_array_elements(b->'data') x where nullif(x->>'date','') is null or (x->>'date')::date<(now() at time zone 'America/Sao_Paulo')::date+7) then raise exception 'Plan dates at least seven days ahead' using errcode='22023';end if;snap:=b->'data';
 else if p_stage=5 and exists(select 1 from public.company_calendar_items i join public.company_strategy_briefs x on x.id=i.brief_id and x.generation=i.generation where i.company_id=p_company_id and x.profile_version=s.profile_version and i.planned_date<(now() at time zone 'America/Sao_Paulo')::date+7) then raise exception 'Atualize as primeiras datas para reservar sete dias de produção e revisão.' using errcode='22023';end if;
  if b->'data' is null or b->'data'='null'::jsonb then raise exception 'Suggestions not ready' using errcode='22023';end if;snap:=b->'data';end if;
 insert into public.company_marketing_approvals(company_id,profile_version,stage,basis,snapshot,approved_by) values(p_company_id,s.profile_version,p_stage,p_basis,snap,auth.uid())
 on conflict(company_id,profile_version,stage) do update set basis=excluded.basis,snapshot=excluded.snapshot,token=gen_random_uuid(),approved_by=auth.uid(),approved_at=now();
 update public.company_content_preparations set next_attempt_at=now(),updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and status='pending';
 update public.company_launch_jobs set next_attempt_at=now(),updated_at=now() where company_id=p_company_id and profile_version=s.profile_version and status='pending';
 insert into public.audit_logs(workspace_id,company_id,actor_id,action,details) select workspace_id,id,auth.uid(),'marketing.stage.approved',jsonb_build_object('stage',p_stage,'profileVersion',s.profile_version,'basis',p_basis) from public.companies where id=p_company_id;
end;$$;
notify pgrst,'reload schema';
commit;
