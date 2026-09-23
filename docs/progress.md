# Progresso — 21/09/2026

> Registro histórico da primeira implementação. O prompt mestre recebido posteriormente e o estado atual estão em `askadia-requisitos.md`, `askadia-progresso.md` e `askadia-aceite.md`. Esses documentos substituem conflitos abaixo, incluindo acesso operacional do proprietário e ordem das etapas.

## Evolução pelo prompt mestre

Fundação de perfis internos/carteira, sessões auditadas, planos por empresa, delegações e importação transacional de rascunhos implementadas. 53 testes passaram; homologação com contas Supabase e integrações externas permanece pendente. O arquivo `.local/askadia-update.sql` contém somente as migrações incrementais 003 e 004 e deve ser aplicado depois da instalação inicial. Os demais módulos permanecem no escopo consolidado.

## Entrega atual
Etapas 0 e 1 executáveis. A implementação da etapa 2 (identidade, empresas e acessos) foi acrescentada; homologação com Supabase real ainda pendente.
A especificação funcional v1 do usuário foi preservada em docs/requirements-v1.md e mapeada em docs/requirements-map.md.

## Disponível na prévia local
Dashboard sem métricas fictícias, empresas em rascunho, conteúdo manual com revisão/versionamento, calendário, CRM de teste e catálogo de integrações. Rascunhos ficam no navegador e não migram automaticamente para a conta.

## Nova implementação de identidade
- /login: login, cadastro, recuperação e troca de senha via Supabase no servidor. Sem configuração, formulários ficam indisponíveis com explicação.
- /workspace: área autenticada com workspaces, seletor de empresa por usuário, criação/edição, arquivamento e restauração.
- Criar/restaurar empresa não ativa assinatura.
- Gestão de membros, convite por link válido por 7 dias, aceite vinculado ao e-mail confirmado, revogação e registro de alterações.
- Token de convite armazenado apenas como hash; link completo exibido uma vez, sem envio de e-mail.
- Proteção do último administrador e permissões explícitas por empresa.
- Proprietário do workspace gerencia metadados/equipe, sem acesso operacional automático.
- Sessão em cookies HttpOnly; BFF com validação de origem, lista de rotas e cache desativado.
- API Nest valida o token no Supabase e opera com JWT do usuário, sem service_role.
- Políticas RLS de dados, bucket privado com prefixo da empresa e RPCs transacionais auditados.
- Exportação autenticada e auditada do perfil da empresa; exportação CRM conectada vem em outra etapa.
- Seleção descarta a equipe anterior e ignora respostas atrasadas da empresa anterior.

## Validações executadas
- pnpm check: passou novamente com .env configurado e correção do retorno RPC .single(), código 0 — lint, tipos e build de web/API/worker.
- 37 testes passaram: 14 de domínio local, 9 de API/autenticação/contratos e 14 de PostgreSQL/RLS.
- PostgreSQL real via PGlite: duas empresas no mesmo workspace e uma em outro; leitura/alteração/exportação cruzadas; membro removido; escalada direta de permissão; arquivos; convites expirados/revogados/repetidos; e-mail não confirmado; último administrador; arquivamento; FK cruzada.
- HTTP Nest usa um adaptador de identidade controlado para provar os bloqueios de rota. Isso não é uma prova de login real no fornecedor.
- Arquivo consolidado .local/supabase-setup.sql aplicado em PostgreSQL/PGlite: dez tabelas criadas; segunda execução bloqueada pelo preflight. Auth/Storage usam as mesmas fixtures da suíte.
- Requisição ao servidor local GET /identity sem token: 401.
- POST /api/auth com Origin externa: 403.
- POST /api/auth com origem local e Supabase ausente: 503, sem sucesso simulado.
- Build Next gerou /login, /workspace, /preview, /auth/callback, /auth/update-password e rotas API.
- Login inspecionado no navegador a 1440×1000 e 390×844; campos bloqueados sem configuração; alternância cadastro/login verificada.
- A revisão de banco encontrou e corrigiu conflito com o identificador SQL current_role na proteção do último admin. A suíte passou após a correção.
- Concorrência: aquisição de locks padronizada entre aceite de convite, criação e alteração de membros; o aceite revalida o convite após o bloqueio. Teste multi-conexão ainda pendente em Supabase.

## Limites reais
- .env local configurado com URL e chave pública fornecidas; chave service_role não armazenada. Auth/settings respondeu 200, cadastro por e-mail habilitado e confirmação obrigatória. Consulta sem registros a workspaces respondeu PGRST205: tabela ausente no cache do esquema. Migrações remotas pendentes de execução pelo usuário.
- PGlite usa fixtures de auth/storage; não prova Auth hospedado, PostgREST, SMTP, download real ou cookies com o fornecedor.
- Fluxo completo da UI autenticada com contas reais ainda não homologado.
- Realtime não é usado por esta interface; autorização de canais e prova de revogação ao vivo continuam pendentes.
- Uploads e validação binária ficam na etapa de onboarding/arquivos.
- Convites são compartilhados manualmente. Nenhum e-mail foi enviado.
- Billing, IA, pesquisa, conteúdo multimídia, sites/domínios, anúncios e mensagens continuam pendentes.
- Nenhuma publicação, gasto em anúncios, cobrança, DNS, deploy, merge ou migração destrutiva foi executada.
- API/worker permanecem bloqueados para produção até homologação e decisão de lançamento.

## Próxima etapa
O usuário escolheu executar o SQL no painel. Arquivo .local/supabase-setup.sql reúne as três migrações em uma transação, com bloqueio inicial de objetos conflitantes. Aplicar e seguir docs/identity-setup.md para configurar URLs do Auth. Validar com contas reais o percurso cadastro → e-mail confirmado → workspace → duas empresas → convite → mudança/revogação → acesso negado em API/banco/arquivos.
Após esse aceite, iniciar etapa 3: assinatura por empresa com Asaas sandbox, entitlements e reconciliação.

## Sequência restante
3. Cobrança por empresa.
4. CRM persistente e captura/importação.
5. Onboarding, conhecimento e arquivos.
6–7. Pesquisa e estratégia com fontes/versões.
8–9. Conteúdo, vídeo, site e domínio.
10–11. Publicação e atendimento multicanal.
12–13. Tráfego, indicadores e acompanhamento.
14. Homologação completa e piloto.

## Dashboard — etapa local de 21/09/2026

Escopo independente do trabalho de fundação: reaproveitados identidade, empresas, permissões, CRM, sessão interna e componentes; protótipo /preview preservado. Sem alterações de credenciais, deploy ou execução de SQL remoto.

Entregas:
- /dashboard e /resultados, visual neutro, filtros compartilhados, 6–8 KPIs, comparação, tabelas, proteção contra resposta atrasada e memória de cálculo.
- Importação CSV assistida e auditada com modelos vazios, fatos idempotentes, correções versionadas e cobertura declarada.
- Motor de CAC/ROAS/ROI com centavos, ausência distinta de zero, escopos explícitos, clientes antigos excluídos, primeira aquisição pagante e estornos tardios rastreáveis.
- Perfil confirmado para 20 candidatos editoriais e Trends por lote/região/escala, sem ranking global falso.
- CSV/PDF privados com snapshot/metodologia e permissão financeira revalidada.
- Migração aditiva 202609219001_dashboard.sql e adaptadores/contratos de leitura, sincronização e diagnóstico.

Validação final: pnpm check passou (lint, typecheck, 91 testes em 7 arquivos e build de API/worker/web). Testes novos de dashboard cobrem finanças, períodos, corridas, CSV, Trends, temporalidade social, PostgreSQL/RLS, importação/revisões, permissões/exportações, consultas HTTP com fixtures, revogação/retry do processador e estrutura do PDF. Resultado numérico de ROI 75% confirmado. Testes não fazem chamadas reais a provedores.

Navegador: /dashboard sem sessão redirecionou para /login; aba temporária de inspeção encerrada. Não houve homologação visual autenticada, móvel ou com contas externas reais.

Limites: migração remota pendente; APIs não homologadas. Cofre/OAuth, normalização e persistência automática, repositório de jobs/checkpoints e ativação do consumidor ainda pendentes. Gestão não informada. Conciliação automática de CRM, fila de ambiguidades, atribuição automática, rateio por coorte, métricas individuais do atendente e IA ativa ainda não implementados. O botão Atualizar leitura consulta o banco, sem simular job externo. CSV é o caminho funcional inicial após aplicar as migrações. Permissões financeiras possuem RPC, mas a tela de equipe ainda não expõe esses controles.

Próxima etapa concreta: aplicar as migrações na ordem, validar dois tenants com usuários reais e importar um relatório pequeno conciliável; depois definir fornecedor/unidade e autorizações das contas para implementar e homologar o fluxo automático. Detalhes em docs/dashboard-auditoria.md, docs/dashboard-metricas.md e docs/dashboard-integracoes.md.

## Correção do cadastro — 21/09/2026
O endpoint POST /identity/workspaces retornava o UUID como texto/html pelo Nest. O proxy web esperava JSON e exibia 503 depois de o banco já ter criado a área. Corrigido para responder {id}, com consumo correspondente na tela. Adicionado teste HTTP que falhou antes da correção (Content-Type text/html) e passou depois (201, application/json, ID correto e uma chamada à RPC). Os 10 testes de identidade/API passaram.
Na sessão autenticada do usuário, foram encontradas duas áreas resultantes das tentativas anteriores, ambas sem empresas. Foi usada a primeira área existente para cadastrar a empresa solicitada; a interface confirmou o registro persistido como rascunho, sem contratação. A área duplicada foi preservada. Nenhuma migração foi necessária para esta correção.

Validação final da correção de cadastro: `pnpm check` passou integralmente (código 0): lint, tipos, 92 testes e builds de web/API/worker. Cadastro da empresa solicitada confirmado na interface autenticada do Supabase; nenhuma cobrança ativada.

## Página pública na raiz — 21/09/2026
A rota / passa a apresentar o site institucional da Askadia, sem redirecionar automaticamente para o painel e sem carregar a prévia local. Apresentação, recursos disponíveis, evolução do produto e perguntas frequentes usam a identidade neutra existente. Todos os botões de entrada levam a /login; /workspace e demais áreas conectadas mantêm autenticação. /preview continua separado. A página pública não consulta dados privados nem depende do Supabase para renderizar. Nenhum DNS ou deploy foi alterado. Esta entrega não conclui os formulários comerciais e as demais páginas institucionais do escopo mestre.


## Jornada por empresa — 21/09/2026
Onboarding persistido, perfil confirmado/versionado, anexos privados, briefing/estratégia OpenAI, áreas por papel e reuniões de acompanhamento implementados. CRM e tomada humana em migração 006; execução remota ainda sem confirmação. Migração 005 executada pelo usuário. Auditoria, navegação e contrato em docs/jornada-auditoria.md e docs/jornada-contrato.md; relatório em docs/jornada-entrega.md.
Validação: pnpm check passou (lint, tipos, 114 testes, builds); após ajustes finais de texto/Maps, tipos de API/web e 22 testes da jornada passaram. Navegador autenticado confirmou criação → conversa → recarga → etapas manuais → perfil v1 → início da mesma empresa → briefing persistido, além de PNG privado presente após recarga.
OpenAI continuou retornando 429 sem créditos após recarga informada. Gemini Pro retornou 429 free tier com limite zero nas duas tentativas reais de imagem; nenhuma imagem gerada. Google Places/Embed sem chaves, com busca externa manual e aviso específico. Não há homologação de geração, publicação, envio WhatsApp ou cobrança.


## Google Places — chave configurada em 21/09/2026
Chave fornecida pelo usuário salva apenas em GOOGLE_PLACES_SERVER_KEY no .env ignorado. Consulta real ao endpoint Places Text Search retornou HTTP 403 PERMISSION_DENIED / SERVICE_DISABLED: Places API (New) está desativada no projeto associado à chave. Usuário recebeu link direto de ativação. A chave não foi exposta como chave de navegador; Maps Embed ainda depende de credencial própria restrita. API local sinalizada para recarregar ambiente. Sem alterações em dados da empresa, sem seleção/confirmacão automática de local. Não houve mudança funcional de código nem nova suíte; teste de integração real identificou bloqueio externo antes da busca.


## Google Places ativado — 21/09/2026
Nova consulta real com a chave de servidor já configurada retornou HTTP 200 e um estabelecimento para a busca da empresa. A ativação resolveu o SERVICE_DISABLED anterior. A nova credencial fornecida em print do Gemini foi testada no Places e retornou 401 UNAUTHENTICATED; não substituiu a chave funcional. Nenhum segredo ou conteúdo integral do Places foi salvo no relatório. GOOGLE_MAPS_BROWSER_KEY ainda ausente: mapa incorporado pendente, link externo disponível. Sem mudanças de código nesta validação de integração.


## Atualização da chave Gemini — 21/09/2026
Nova credencial Gemini fornecida pelo usuário salva somente no .env privado. Teste real com gemini-3-pro-image retornou novamente HTTP 429 RESOURCE_EXHAUSTED, métricas de free tier com limite zero. Nenhuma imagem gerada. A chave funcional do Google Places foi preservada. Faturamento/quota do projeto Gemini permanece como dependência externa. Sem mudanças de código; teste específico da integração executado.


## Novo teste real OpenAI e Gemini — 2026-09-21T19:53:27.763Z
OpenAI: interpretação estruturada de resposta fictícia concluída com sucesso; nome, cidade e tipo extraídos, 359 tokens totais (275 de entrada e 84 de saída). O bloqueio de crédito deixou de ocorrer nesse teste. Isso homologa a interpretação do onboarding; geração completa de estratégia permanece sem validação real nesta execução. Gemini Nano Banana Pro (gemini-3-pro-image): HTTP 429 RESOURCE_EXHAUSTED, métricas free tier com limite zero; nenhuma imagem gerada. Nenhum dado real de cliente enviado; sem alteração de código nesta verificação.


## Calendário editorial, designer e conexões — 21/09/2026
Estratégia exige 12 ideias. Aprovação materializa o calendário; OpenAI detalha somente itens pendentes. Designer Gemini recebe briefing, marca e bytes dos materiais privados selecionados (até 5 imagens/12 MB), com referência aos anexos no registro da geração. Revisões invalidam aprovação; respostas atrasadas não substituem edições. Calendário e arquivos isolados por empresa. Implementado OAuth Meta com state descartável, seleção de Página e cofre AES-GCM; Evolution procura/cria instância determinística por empresa apenas ao conectar WhatsApp e oferece QR/status. Sem consumidor de webhook, envio real, publicação ou insights sincronizados neste incremento.
Validação completa: pnpm check passou, incluindo lint, tipos, 120 testes e builds. Testes cobrem 12 ideias, aprovação prévia, edição/revisão, mídia privada, geração atrasada, materiais, isolamento, OAuth replay e cofre. Integrações externas ainda dependem de homologação.
Erro de Conteúdo confirmado: tabelas 007/008 ausentes (PGRST205). Usuário executou ambos os SQLs preparados, consulta posterior confirmou presença com acesso anônimo negado por permissões. Nenhum dado de empresa foi alterado por testes de navegador. App Meta Askadia Marketing (1061475423356674) criado com Instagram, Páginas e três casos de uso Marketing API; usuário autorizou aceite de termos. App antigo preservado. App ID salvo no .env; segredo, origem HTTPS, portfólio Askadia/verificação e análise Meta pendentes. Gemini: última geração real ainda 429; não afirmar design homologado.
Contrato, permissões e instruções em docs/calendario-conexoes.md. Upload do vídeo final e consistência visual entre slides continuam pendentes.


## Homologação de calendário/Meta/Evolution — continuação
Calendário verificado no navegador autenticado após 007/008: quatro publicações da estratégia legada, revisões v2, legendas, briefing visual, slides/roteiros e três materiais de referência. Não houve expansão da estratégia aprovada; novos resultados exigem 12 ideias.
Meta: usuário forneceu segredo, salvo apenas no .env; Graph v26.0 confirmado no painel. Callback HTTPS https://askadia.com.br/api/connections/meta/callback salvo e confirmado após recarga, mantendo HTTPS e modo estrito. OAuth local bloqueado até WEB_ORIGIN HTTPS para não encaminhar clientes a callback inválido. Cinco testes do adaptador passaram após esse ajuste e tipos de API passaram. App em desenvolvimento, portfólio e revisão ainda pendentes.
Registro oficial confirmou domínio askadia.com.br ativo, DNS a.auto.dns.br/b.auto.dns.br, consulta DNS pública sem registro A. IP do host Evolution: 2.25.204.218. Usuário escolheu hospedar no mesmo Easypanel; painel aberto e aguardando autenticação. Hospedagem NÃO executada: API e worker ainda possuem bloqueios explícitos de produção que exigem revisão de lançamento; não removidos.
Evolution: servidor 2.3.7 retorna 404 ao buscar uma instância inexistente. Corrigido para criar nesse caso, distinguir erro de credencial e reutilizar a instância existente. Testes verificam 404→criação, reutilização sem duplicação e 401 sem tentativa de criação. Sete testes do adaptador e tipos de API passaram. Validação real pela interface criou askadia-{UUID da empresa Gaviões Varginha}, persistiu vínculo pendente e exibiu QR code. Não houve leitura do QR pelo agente, envio de mensagem ou configuração de webhook.

Meta (configuração no painel): adicionado conjunto obrigatório de conteúdo Instagram com Facebook Login; instagram_basic, instagram_content_publish, pages_read_engagement, pages_show_list e business_management apareceram prontos para teste. Tentativa de adicionar instagram_manage_insights retornou modal da Meta “Ocorreu um erro. Tente novamente mais tarde.”; permissão NÃO habilitada. Configuração de Login para Empresas não finalizada (nenhum config_id gerado); demais permissões Pages/insights, revisão/portfólio e homologação OAuth continuam pendentes. Painel Easypanel ainda sem sessão autenticada. Domínio público/produção não alterados.

## Versionamento para hospedagem — 22/09/2026
Repositório local inicializado em main e origin configurado para https://github.com/IuriKlima/askadia.git, que estava vazio. Primeiro snapshot reúne aplicação, contratos, migrações, documentação, testes e CI. .gitignore ampliado para excluir cache pnpm e logs; .env, .local, dependências e builds continuam excluídos. README atualizado para distinguir implementação atual, validações e dependências de produção.
Validação antes do commit: pnpm check passou integralmente (lint, tipos, 123 testes em 9 arquivos e builds dos três aplicativos). Inspeção dos 157 arquivos preparados não encontrou valores das credenciais configuradas nem padrões comuns de chaves privadas, tokens GitHub, Google/OpenAI/Gemini ou JWTs. .env.example contém apenas placeholders e configuração pública de exemplo.
Este registro não representa deploy. Permanecem pendentes a preparação dos serviços para containers, revisão dos bloqueios explícitos de produção, configuração segura no Easypanel, DNS/HTTPS e homologação das integrações. Nenhuma migração remota, publicação, mensagem ou campanha foi executada nesta etapa.

## Caixa de entrada e assistência por empresa — 22/09/2026
Causa confirmada: a Evolution estava conectada e tinha histórico, mas a tela anterior só consultava registros internos da migração 006, ausente na base remota (PGRST205). Nova caixa consulta o histórico real da instância autorizada, em duas colunas, com flags de canais, busca, paginação, leitura de grupos, atalhos e tela cheia. Envio textual requer tomada humana e reserva idempotente; não foi enviado texto a contatos durante a validação.
Adicionada Configuração de Atendimento por empresa/canal, com prompt GPT-4o mini, regras ordenadas de fluxo e teste sem envio. Histórico fica na Evolution; configurações, atalhos e responsáveis ficam no Supabase. IA atualmente sugere para revisão humana; automação por webhook/consumidor e Direct Meta/TikTok continuam dependências de implementação/homologação, exibidas na interface.
Migração 202609220001 e pacote condicional 006 testados em PGlite. Pacote aplicado no projeto Supabase autenticado pelo navegador; SQL Editor confirmou sucesso. Acesso anônimo a company_conversations, company_service_settings e company_quick_replies retorna 401/42501. Interface real reconheceu WhatsApp conectado e 1.745 conversas, abriu mensagens e alternou para tela cheia. Chave Gemini atualizada apenas no .env privado e API sinalizada para recarga.
Contrato, navegação, permissões e limites em docs/atendimento-caixa-entrada.md. pnpm check passou (131 testes, lint, tipos e builds); ajustes posteriores de apresentação/limpeza de erro transitório serão verificados antes da entrega.

## Verificação adicional de interface e IA
No navegador autenticado: WhatsApp reconhecido como conectado, consulta real de histórico, alternância de tela cheia e layout desktop verificados. Prompt inicial de atendimento salvo para WhatsApp da empresa aberta; alternar para Instagram mostrou configuração independente. Teste sem envio com pergunta fictícia sobre modalidades retornou resposta real do GPT-4o mini coerente com o perfil confirmado (musculação, pilates, luta e natação). Não houve envio para um contato. Ajustado aviso transitório de leitura para não manter erro após recuperação nem apagar alertas de envio incerto.

## Atendimento, CRM e calendário — atualização de 22/09/2026
Correção de ativação: SUPABASE_SERVICE_ROLE_KEY estava vazia; configurada no ambiente privado e RPC inbox_auto_targets validada (HTTP 200). Consumidor disponível; ativação continua explícita por canal. Interface atualiza disponibilidade sem substituir formulários não salvos e informa a causa de bloqueios.
Entregues: canvas com validação no servidor/banco, prompt gerado pelo perfil, tomada humana/retomada e consumidor durável; leitura/envio de imagem, áudio e documento até 8 MB; chat ocupa a área da página; CRM Kanban/lista e sincronização manual idempotente do WhatsApp; calendário mensal com miniaturas, página por dia, datas pela IA na aprovação da estratégia, geração sequencial do mês, upload privado de MP4 até 50 MB e aprovação da versão final.
Migrações 002–005 aplicadas no Supabase com sucesso. Testes adicionais verificam automação idempotente, pausa humana, isolamento, sincronização sem alterar etapas, datas sem substituir edições e aprovação de vídeo versionada. Nenhuma mensagem real foi enviada pelo agente.
Limitações: geração mensal de peças depende da aba aberta, mas resultados concluídos persistem; pode retomar somente o que falta. Fluxo inicia a cada mensagem, não retém etapa entre mensagens. CRM mostra até 1.000 contatos recentes; sincronização é acionada pelo usuário. Meta/Instagram/Facebook e TikTok ainda exigem homologação dos canais; calendário planeja datas e aprova material, mas não possui publicador automático nesta versão. Não considerar a publicação automática entregue.
Dockerfile e runner de produção adicionados para Next+API, com autenticação, HTTPS e cofre obrigatórios. Worker de protótipos não é iniciado em produção. Deploy autorizado pelo usuário; registrar resultado após execução.

Validação final desta etapa: pnpm check passou (145 testes em 11 arquivos, lint, tipos e builds). Navegador confirmou checkbox automático habilitado, fluxo salvo respondeu ao teste fictício sem envio, calendário exibiu 12 datas persistidas após chamada real OpenAI. Revisão dos 182 arquivos não encontrou credenciais do ambiente.

Deploy confirmado em 22/09/2026: commit 746dad1 construído e implantado no Easypanel askadia/askadia; HTTPS askadia.com.br e /login 200, API inbox sem sessão 401. Domínio principal e destino 3000 configurados, variáveis privadas salvas, Supabase Site URL e callbacks ajustados. Ver docs/deploy-easypanel.md.

## E-mails da conta — 22/09/2026
Preparados 13 modelos HTML em português com logo textual, cores e tipografia da Askadia, layout por tabelas, estilos inline e fallback de links. Gerador único em scripts/build-account-emails.mjs e configuração dos assuntos/avisos em supabase/templates/auth-config.json. Prévia desktop e 390 px conferida. Painel Supabase confirmou bloqueio de personalização sem SMTP próprio; credencial Resend/remetente ausentes. Configuração remota e entrega continuam pendentes do provedor e domínio verificado; nenhum e-mail real enviado. Documentação: docs/emails-da-conta.md.

Validação dos modelos: geração consistente dos 13 HTMLs, variáveis e links de autenticação preservados; pnpm check passou (145 testes, lint, tipos e builds). Envio real e aplicação remota não executados, pendentes de SMTP próprio.

## Campanhas, gestão e Meta — trabalho em andamento, 22/09/2026
Implementação local das duas áreas de campanhas, condições de aniversário/ausência, importação CSV e API de recebimento por empresa com chave revogável. Consumidor com aprovação de versão, consentimento, atualização, janela de horário e proteção de duplicação. Migrações 006–008 ainda NÃO aplicadas remotamente; MESSAGE_CAMPAIGNS_ENABLED permanece desligado por padrão. Ver docs/campanhas-relacionamento.md. Validação final pendente.
Meta: causa do Invalid Scopes confirmada no painel: pages_manage_posts e read_insights ainda não adicionados ao caso de uso. Ambas adicionadas e verificadas como Pronto para teste; instagram_manage_messages, pages_manage_metadata e pages_messaging também confirmados. Caso de uso Messenger incluído com autorização explícita do usuário. Código local passa a solicitar grupos de permissões escolhidos e informar acesso recebido por recurso. App continua não publicado; contas externas dependem da revisão/portfólio. Publicador, sincronização de insights, operação de anúncios e canais de mensagem Meta ainda não estão implementados de ponta a ponta.
E-mails: usuário escolheu Resend. Aba de cadastro aberta e aguardando conclusão pelo usuário; modelos e SMTP ainda NÃO aplicados, envio personalizado não ativo.

Validação local concluída: pnpm check passou (151 testes em 12 arquivos, lint, tipos e builds). Navegador público avançou para o diálogo normal do Facebook Login sem Invalid Scopes; autorização/seleção de ativos ainda não concluída. Isso confirma a remoção do bloqueio de escopos, não a operação completa dos recursos Meta.

Execução das migrações remotas bloqueada pela revisão automática: autorização anterior interpretada como execução pelo próprio usuário. Pacote .local/askadia-campanhas.sql inserido e conferido no SQL Editor, mas NÃO executado. Consulta prévia confirmou ambas as tabelas principais ausentes. Solicitada autorização específica; aguardando resposta. Não implantar as rotas novas antes da instalação do banco.

Após autorização explícita “Autorizo executar as migrações”, pacote 006–008 aplicado em transação no Supabase. SQL Editor confirmou “Success. No rows returned”. O alerta genérico do editor não reconheceu a configuração dinâmica de RLS; o SQL executado habilita RLS nas três tabelas públicas e revoga acesso às tabelas privadas. Nenhuma campanha foi criada/ativada e nenhum aluno foi importado durante a migração.

Deploy concluído: commit 6189426, Easypanel Success em 22/09/2026 17:52:20 UTC. Site/login 200; APIs sem autenticação 401. MESSAGE_CAMPAIGNS_ENABLED=true autorizado separadamente, salvo e conferido ao reabrir Environment. RLS confirmada nas três tabelas públicas pelo SQL Editor. Página de campanhas autenticada carregou as duas opções, zero alunos e fuso America/Sao_Paulo; nenhuma importação/campanha real criada, ativada ou enviada durante testes. E-mails continuam pendentes de conclusão do cadastro/login Resend. Não considerar SMTP, homologação de entrega ou operação completa Meta/Wellhub/TotalPass entregues.

Conferência adicional em produção: formulário Nova campanha abre com data e fuso corretos; selecionar ausência exibe o campo de dias; cancelar não grava rascunho. Aba Tráfego Pago exibe propostas reais da estratégia, explicitamente sem anúncios ativos. Resend permanece na tela de cadastro, aguardando usuário; envio com identidade visual ainda não ativado.

## Experiência, CRM, Meta, anúncios e sites — 22/09/2026
Implementadas a estratégia detalhada com revisão/feedback e checklist, redirecionamento de Agentes, chat de onboarding reabrível, seleção de locais por mapa/raio/lista, limite de duas publicações semanais em novos planejamentos e separação de textos/designs. CRM com histórico e métricas da amostra; campanhas para contatos selecionados com consentimento; leitura/resposta textual Meta; OAuth e hierarquia real Google Ads/Meta, propostas de investimento limitadas ao teto.
Meu site agora gera rascunho a partir do perfil confirmado, permite editar, selecionar materiais, visualizar desktop/mobile, baixar HTML, publicar versão e retirar do ar. Hospedagem em /s/[empresa], domínio próprio verificado por TXT/CNAME/A e subdomínio exclusivo da Askadia. Encaminhamento HTTPS automático preparado via API Easypanel; credencial administrativa e DNS wildcard ainda pendentes.
Validação: pnpm check passou (164 testes em 14 arquivos, lint, tipos e builds). Alterações finais de mapa padrão e upload múltiplo terão verificação adicional antes do commit. As migrações 009–013 foram inicialmente bloqueadas pelo revisor automático por falta de autorização específica; após resposta explícita “sim”, pacote integral conferido (34.035 caracteres) e executado no Supabase: “Success. No rows returned”. Nenhum cadastro apagado, envio/campanha ativado ou site real publicado no teste. Navegador local confirmou histórico de onboarding e botão para refazer entrevista.
Relatório, navegação, capacidades e dependências: docs/experiencia-sites-integracoes.md. Deploy/commit ainda pendentes nesta etapa.
`nVerificação adicional: lint passou; diagnóstico real do Google retornou ApiNotActivatedMapError na chave de navegador. Habilitação de Maps JavaScript API solicitada ao usuário. Interface mantém mapa padrão, informa bloqueio de autorização e oferece lista. Meu site carregou os controles após migração.

Complemento solicitado: Meu site separado em Prévia e Domínio, editor fechado por padrão; layout com capa fotográfica ampla, faixas na cor da academia e seções de serviços/galeria/contato. GPT-5 específico para site. Descrições internas com Gemini 3.5 Flash-Lite; 2.5 Flash-Lite aparecia na consulta de modelos, mas a geração real retornou 404 com orientação de migração. A geração real com 3.5 respondeu 200. Migração 014 executada no SQL Editor com Success; fila confirmou três imagens existentes em ready, com modelo persistido. As descrições são observações visuais, não fatos comerciais nem autorização de uso.
Validação adicional: oito testes de sites/fila passaram. Primeira suíte completa após 014 revelou ausência do papel service_role em quatro fixtures antigas; fixtures atualizadas para representar o Supabase. Reexecução e build em andamento. Navegador integrado passou a não responder; recuperação solicitada ao usuário para validar visualmente e concluir deploy. Nenhum site real publicado nem mensagem enviada.
Validação final: lint e typecheck passaram; após ajuste dos quatro fixtures, 165 testes em 14 arquivos passaram e o build completo API/worker/Next terminou com sucesso. Varredura dos arquivos alterados não encontrou valores de credenciais do .env. Pacotes 009–014 aplicados remotamente; três imagens da empresa verificadas em ready com Gemini 3.5 Flash-Lite. O usuário acionou um deploy antes do envio deste commit; esse deploy não contém estas alterações locais. Navegador integrado indisponível na etapa final, portanto implantação desta revisão ainda precisa ser confirmada.

## Ficha do lead e orientação editorial — 22/09/2026
CRM: ficha redesenhada com identificação, etapa, contato, indicadores da amostra, últimas interações e linha do tempo. Botão destacado abre a conversa interna; link funciona também para conversas fora da primeira página. Nomes reais disponíveis no histórico/chat substituem identificadores numéricos na apresentação, sem sobrescrever nomes manuais nem tratar LID como telefone. Vínculos são consultados pelos contatos exibidos, em lotes limitados e com filtro de empresa/canal.
Calendário: diagnóstico autenticado confirmou estratégia do perfil v2 de outubro em review, com oito ideias e aprovação pendente; nenhuma estratégia foi aprovada pelo agente. Nova trilha Planejar → Criar → Revisar → Aprovar → Programar, aviso e acesso à revisão no topo e prévia dos temas da estratégia. Geração de textos precede a organização das datas, preservando textos se o planejamento falhar. Status considera mídia e aprovação da revisão atual. Programação automática continua explicitamente pendente da integração de publicação; data planejada não é agendamento confirmado. Nenhuma migração adicional necessária.
Validação em andamento: testes de nomes/autor de mensagens e revisão dos criativos adicionados. Calendário local conferido visualmente com o aviso das oito ideias. Commit/deploy desta revisão ainda pendentes.
Validação concluída: pnpm check passou, com 169 testes em 16 arquivos, lint, typecheck e builds de API/worker/Next. Conferência no navegador confirmou estratégia de outubro em review e a nova trilha no calendário. Não houve aprovação, publicação ou mensagem de teste real. O acesso ao servidor local oscilou durante a conferência da ficha; validação após deploy ainda pendente.

## Preparação automática após onboarding — 22/09/2026
Deploy anterior 5147526 concluído no Easypanel (Success, 22/09/2026 21:36:19 UTC). Conferência local da ficha com dados reais e abertura da conversa pelo botão concluídas, sem envio. Nova solicitação: preparação automática de estratégia, textos e designs em rascunho após confirmação do perfil, sem aprovação implícita.
Migração 015 adiciona fila durável por empresa/versão, RLS, autorização do solicitante revalidada, lease e token, até três tentativas por etapa e preservação de quotas existentes. Rotinas de preparação privadas permitem rascunhos antes da revisão da estratégia; aprovação final continua usando as validações originais. Datas novas partem do dia atual em America/Sao_Paulo, avançam entre meses com máximo de duas por semana e preservam datas existentes. Vídeos recebem roteiro e aguardam upload humano. Worker servidor retoma peças ausentes após reinício; estado/progresso aparece no calendário, que passa a ser o destino após onboarding. Não há serviço de publicação automática nesta mudança.
Cinco testes da fila passaram (incluindo conclusão de todas as artes sem aprovação/publicação): isolamento, confirmação idempotente, limite semanal/data atual, rascunhos sem aprovação, recuperação de lease, rejeição de worker antigo e invalidação por mudança do perfil. Oito testes existentes de sites/permissões passaram com a nova migração. Validação completa e instalação remota da 015 pendentes.

Validação completa: pnpm check passou (lint, typecheck, 174 testes em 17 arquivos e builds API/worker/Next). Nenhuma credencial do .env foi encontrada nos arquivos alterados. A conexão CDP das abas Supabase e Easypanel expirou repetidamente, inclusive ao tentar uma aba nova; reabertura solicitada ao usuário. Migração 015 e deploy ainda não executados. A produção permanece na revisão 5147526.
Navegador recuperado após o build. Migração 015 conferida integralmente no editor (checksum normalizado igual ao arquivo local) e executada no Supabase: Success. No rows returned. Sem exclusão de cadastros, aprovação de peças ou publicação. Deploy desta revisão será realizado em seguida.
Deploy 43d51af acionado e build concluído no Easypanel em 23/09/2026 11:47:54 UTC. Validação após build encontrou falha real de inicialização da API: Production requires HTTPS origin, Supabase authentication and the configured encryption vault. O editor Environment Variables foi confirmado vazio por leitura do conteúdo visível. Domínio ainda apresenta interface anterior; não considerar a nova automação operacional em produção. Arquivo ignorado .local/easypanel-production.env preparado com credenciais locais existentes (mesma chave de cofre), WEB_ORIGIN HTTPS e CONTENT_AUTOPREP_ENABLED=true. Solicitado ao usuário preencher/salvar o ambiente, sem enviar segredos no chat. Após salvar, refazer deploy e validar calendário/fila. Nenhuma publicação aprovada ou enviada nesta verificação.
23/09/2026 — Cadastro automático de domínio ao publicar: o endpoint de publicação agora chama o adaptador Easypanel somente após a transação de publicação aprovada. Usa o subdomínio já reservado e apenas domínios próprios com DNS verificado, reutiliza mapeamentos existentes e preserva a publicação se a hospedagem falhar. A interface apresenta o resultado da hospedagem separadamente da publicação. Seis testes de adaptador adicionados (requisições simuladas, sem criar domínio/site real). pnpm check em andamento. Painel v2.34.0 mostra somente usuário ADMIN e Generate API Key; usuários adicionais restritos exigem Growth/Business. Confirmação solicitada antes de conceder à aplicação uma chave administrativa ampla. DNS wildcard no Registro.br e homologação real da API continuam pendentes.
Validação do cadastro ao publicar: pnpm check concluído com sucesso (lint, tipos, 180 testes em 18 arquivos e builds API/worker/Next). Os testes de hospedagem usam respostas simuladas; acesso real aguarda autorização da chave de API e configuração do DNS. Não foi publicado site real para testar.
Deploy do commit ae75d79 concluído no Easypanel em 23/09/2026 12:41:25 UTC (Success / App deployed). Página autenticada Meu site recarregada após implantação: dados, editor e prévias desktop/mobile carregaram. O rascunho da empresa ainda não está publicado e a interface exige informar o WhatsApp para liberar Publicar. Não houve publicação de teste. Cadastro automático de domínio permanece pendente da autorização para chave administrativa e do DNS wildcard no Registro.br; a execução real da API não foi homologada.

## Auditoria da jornada e melhorias de UI/UX — 23/09/2026
Revisão da entrada, onboarding, estratégia, calendário, CRM, atendimento, campanhas, integrações, site, resultados e assinatura. Relatório: docs/auditoria-ui-ux-2026-09-23.md. Nova visão geral orientada por pendências reais, menu estável, tipografia e ações responsivas, índice/revisão na estratégia, calendário com mês atual de São Paulo, anterior/próximo/hoje e lista legível no celular. Estados de carregamento, erro, repetição e busca vazia mais claros.
Corrigidos: renovação da sessão nas rotas da jornada; leitura segura de erros não JSON; mensagens de domínio ocultas; recarga de domínio que apagava edições não salvas; perda de todas as imagens quando apenas uma falhava; avisos estáticos contraditórios sobre integrações. Sem mudança de RLS, aprovações ou ativação de envios.
Validação: pnpm check passou integralmente (lint, tipos, 186 testes em 19 arquivos e builds API/worker/Next). Seis testes novos cobrem respostas de API e navegação mensal/fuso. Revisão prévia autenticada confirmou preparação concluída, estratégia em revisão, WhatsApp conectado em modo humano, ausência de campanhas e pendências Meta/Google. Nenhuma mensagem enviada, campanha ativada, estratégia aprovada ou site publicado durante a auditoria. Validação visual da nova versão e implantação serão registradas abaixo.

Deploy e conferência final: aplicação e789eb9 enviada para main; Easypanel confirmou Success / App deployed em 23/09/2026 14:29:10 UTC. Produção autenticada mostrou nova visão geral, pendências, edição de estratégia com foco, navegação de meses/Hoje/retorno do dia, menu mobile e lista automática no calendário. Em viewport de 390 px, calendário e site sem transbordamento horizontal. Meu site exibiu as duas abas, prévias e bloqueio por WhatsApp ausente; CRM exibiu busca sem resultado e restaurou os cartões ao limpar. Caixa de entrada carregou conversas sem erro de console observado. Nenhuma alteração de dados reais nas verificações. API de desenvolvimento iniciada pelo agente encerrada; servidor Next já existente do usuário mantido. SMTP/Resend, Maps, Meta/Google Ads e infraestrutura de domínio continuam com as dependências documentadas; publicação social automática completa e cobrança real não estão entregues.

## Site comercial e landing pages — 23/09/2026
Página pública refeita com foco na solução para academias e copy de aquisição. Novas rotas: /lp/marketing-fitness, /lp/atendimento-fitness, /sobre, /contato e /suporte. Header/rodapé compartilhados, navegação mobile, prévias ilustrativas identificadas, FAQ, metadados por página e sitemap. CTAs abrem diretamente o cadastro via /login?modo=cadastro, preservando login e recuperação. Sem métricas, clientes, depoimentos ou garantias de resultado inventados; recursos em evolução descritos nas perguntas pertinentes.
Contato usa apenas canais oficiais configurados por PUBLIC_SALES_WHATSAPP, PUBLIC_CONTACT_EMAIL e PUBLIC_SUPPORT_EMAIL. Proprietário foi consultado e ainda não informou esses canais. Formulário preparado para abrir mensagem no WhatsApp/e-mail, com confirmação de envio pelo próprio visitante; não simula recebimento nem persiste leads. Sem canais, cadastro e central de ajuda permanecem disponíveis, com atendimento direto explicitamente pendente. Ver docs/site-comercial-askadia.md.
Validação local: pnpm check passou integralmente (lint, tipos, 186 testes em 19 arquivos e todos os builds). Prévia desktop da home e LP de marketing, duas LPs em 390 px, Sobre/Contato/Suporte sem transbordamento horizontal. CTA abriu formulário de cadastro real e FAQ de suporte abriu a orientação correta. Nenhuma conta, mensagem, e-mail ou campanha criada/enviada no teste. Implantação autorizada em andamento.

Deploy concluído: commit 7cf4c26 enviado para main, Easypanel confirmou Success / App deployed em 23/09/2026 15:28:07 UTC. Conferência em askadia.com.br confirmou a nova home, ambas as landing pages, Sobre, Contato e Suporte, com títulos próprios. CTA abriu o formulário de cadastro e a pergunta de suporte sobre WhatsApp/IA expandiu a orientação correspondente. Nenhum formulário enviado. Canais oficiais de WhatsApp/e-mail continuam pendentes de informação do proprietário; atendimento direto não foi declarado ativo. Aba pública da nova home mantida disponível para revisão.

## Visão geral: BI e inteligência regional — 23/09/2026
Dashboard de CRM/campanhas com filtros de período/fuso, gráficos, contagens exatas, bloco financeiro reutilizando o BI autorizado, população/densidade IBGE, consulta Google Places por raio, lista e mapa de concorrentes, Facebook Pages Search e visualização oficial Google Trends ao lado do mapa. Ranking próprio de até 20 via adaptador opcional, sem scraping nem valores simulados. Fontes, datas e coberturas parciais explícitas. Próximos passos da jornada preservados.
`pnpm check` passou: lint, tipos, 198 testes em 20 arquivos e builds. Homologação de leitura: 1.735 contatos no CRM; Google retornou 19 concorrentes em 3 km e cinco em 1 km; IBGE confirmou São Paulo, população/densidade do Censo 2022. Corrigida resposta Google sem types em componente de endereço. Isolamento por empresa, revalidação de permissões e limites de consumo testados.
Pendências: Maps JavaScript API desativada e Cloud sem login; Facebook não autorizou Pages Search; ranking próprio Trends requer provedor. BI financeiro depende da migração existente 9001: pacote conferido no editor, execução bloqueada pela revisão automática por falta de autorização específica; confirmação solicitada, sem execução. Detalhes em docs/visao-geral-bi.md. Deploy e validação responsiva em conclusão.

Implantação concluída: commit 20064b3 enviado para main; Easypanel confirmou Success em 23/09/2026 16:53:41 UTC. Produção autenticada exibiu os indicadores de CRM/campanhas, filtro de sete dias, IBGE e 19 locais em 3 km. Google Trends incorporado renderizou pesquisas relacionadas e barras reais em produção. Layout mobile conferido em largura CSS de 375 px sem transbordamento horizontal. Controles de período e raio conferidos. As dependências Maps/Meta e a migração financeira bloqueada continuam explícitas. Servidores locais preexistentes preservados; tentativas duplicadas iniciadas pelo agente encerradas.

Verificação adicional encontrou falha do SDK Maps ao selecionar um concorrente depois de ApiNotActivatedMapError: o descarte de um marcador incompleto lançava getRootNode e derrubava o componente. Correção isola falhas de limpeza de recursos externos e impede inicialização após falha de autorização; lista permanece utilizável. Teste de regressão específico passou e typecheck web passou. A repetição integral de pnpm check foi interrompida durante typecheck por lentidão do ambiente/navegador, após lint passar; a suíte de 198 testes e builds anteriores permanece registrada, sem atribuir esse resultado ao novo teste. Build e publicação da correção em andamento.

Correção c49a7f9 enviada para main. O build local adicional não concluiu e foi interrompido; build Docker e deploy dessa correção ainda pendentes. O navegador passou a expirar inclusive ao selecionar o Easypanel, apesar de recuperação da sessão e fechamento das abas auxiliares. Solicitado ao usuário reabrir o painel ou acionar Deploy. A revisão 20064b3 permanece como último deploy confirmado; não declarar a correção do descarte do mapa ativa em produção. A migração 9001 não foi executada: continua aguardando a autorização específica solicitada após bloqueio automático. Nenhuma mensagem, anúncio, site ou publicação real enviado/ativado nos testes.
