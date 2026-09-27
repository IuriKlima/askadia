# Operação guiada por aprovação — 26/09/2026

## Decisões do cliente nesta conversa

O onboarding concentra informações e autorizações das contas. Ao terminar, o cliente entra na estratégia, com um guia e cinco etapas: (1) concorrentes locais, referências e análise dos perfis; (2) diagnóstico posterior à análise, plano macro ligado às metas, médio e curto prazo; (3) sugestões de publicações e datas; (4) relacionamento com alunos e vendas por mensagens; (5) tráfego pago. Cada etapa exige aprovação da versão apresentada.

Após as aprovações, a Askadia prepara as entregas. Artes entram em produção na semana anterior à data planejada; cada peça precisa de aprovação própria antes de publicação. Aprovar uma campanha específica com público, texto/criativo, orçamento quando aplicável e programação autoriza a execução programada sem um segundo comando. Falta de saldo ou impedimento de cobrança informado pela Meta deve interromper a execução e gerar aviso destacado. Aprovar uma direção estratégica com lacunas **não** equivale a aprovar investimento ou envio a um público ainda indefinido.

## Implementação desta etapa

- Seleção de perfis locais/de inspiração no onboarding e área Concorrentes. Busca por nome/cidade via pesquisa web, aceitando somente URLs de perfis presentes nas fontes retornadas. Identidade exige conferência do cliente; nunca derivamos um @ do nome comercial.
- Adaptador Instagram Business Discovery para perfis profissionais acessíveis. Até 25 posts retornados, seguidores, curtidas e comentários públicos; valores ausentes permanecem nulos. Taxa exibida = média de curtidas + comentários dos posts com ambas as contagens / seguidores atuais. A amostra e a coleta são explícitas. A comparação é entre as duas últimas coletas, não uma série histórica completa.
- Fila de monitoramento por empresa, com credenciais no cofre, revalidação de permissões, intervalo aproximado de uma hora, lease e token. `INSTAGRAM_MONITOR_ENABLED` permanece desabilitado por padrão até homologação. Anúncios comerciais brasileiros têm acesso à Biblioteca Meta por link, identificado como consulta manual; não existe coleta integral presumida pela API.
- Jornada com cinco aprovações persistidas, base da proposta, autor e registro de auditoria. Mudança nos perfis selecionados, estratégia ou calendário invalida as aprovações dependentes. O diagnóstico recebe a cópia de evidências revisada, com data e lacunas. A aprovação compara a impressão dos dados exibidos com a coleta atual e recusa alterações durante a revisão; a repetição de uma aprovação válida não reinicia entregas. Nova revisão de concorrentes exige diagnóstico atualizado.
- Diagnóstico e planos por prazo; sugestões de WhatsApp/mensagens/tráfego baseadas no plano aprovado. Site e produção de conteúdo aguardam as cinco etapas. Filas continuam no servidor, têm limites e recuperam interrupções. Edições de site feitas durante uma geração são preservadas.
- Preparação das artes somente na janela de sete dias anterior à data planejada. Datas iniciais propostas começam com sete dias de antecedência. Falhas do provedor podem atrasar a produção e são exibidas; não há garantia artificial de entrega.
- Carrosséis em 2K, briefing compartilhado, sequência completa de páginas e primeira página usada como referência visual nas seguintes, sempre do mesmo item e revisão. Sem a primeira página, a geração das demais é recusada.
- Sites com direção editorial de maior raciocínio, títulos de seção específicos e duas composições controladas: editorial e imersiva. HTML continua escapado; IDs de fotos e logo precisam pertencer à empresa.
- Conexões Meta, Google Ads e QR do WhatsApp dentro do onboarding. Retorno OAuth retoma a conversa quando o perfil ainda está em edição. Permissões e consentimentos externos continuam sendo concedidos pelo titular da conta.
- Avisos de ações pendentes em início, estratégia, conteúdo, campanhas, site e preparação. Consulta da situação da conta Meta em campanhas e início; conta ativa não é evidência de saldo disponível.

## Modelos e qualidade

Recomendação atual: `gpt-6-astra` para coordenação estratégica e direção do site, preservando modelos menores para interpretação/buscas e tarefas rotineiras. Em 26/09, o gerador visual era `gemini-3-pro-image`. Em 27/09, por decisão do cliente, geração e edição foram migradas para `gpt-image-2.5-sunburst` (OpenAI). A escolha do modelo não resolve sozinha a inconsistência entre slides: referência visual, texto conciso, composição e revisão continuam necessários. `.env.example` documenta os modelos; nenhuma chave ou configuração secreta foi alterada. Acesso aos modelos e resultado visual real ainda precisam de homologação. Atualização de 27/09: os nomes dos modelos foram aplicados no .env local e o acesso a Astra, Sol e Luna foi confirmado por consultas de leitura; edição de fotos e criativos de campanhas foram acrescentados, agora com OpenAI; acesso ao Sunburst também confirmado no catálogo. Detalhes e limites em [modelos-imagens-trafego-2026-09-27.md](modelos-imagens-trafego-2026-09-27.md).

Fontes oficiais consultadas em 26/09/2026:

- https://developers.openai.com/api/docs/guides/latest-model
- https://developers.openai.com/api/docs/guides/model-selection
- https://ai.google.dev/gemini-api/docs/image-generation
- https://www.postman.com/meta/instagram/folder/u4g5a2a/instagram-api-with-facebook-login
- https://www.facebook.com/ads/library/api/
- https://raw.githubusercontent.com/facebook/facebook-nodejs-business-sdk/main/src/objects/ad-account.js

## Limites que impedem declarar a operação toda pronta

As migrações `202609260001`, `202609260002` e `202609260003` precisam ser aplicadas em ambiente de homologação antes da publicação desta versão. Não foram executadas no banco remoto nem foi feito deploy de produção nesta etapa.

A execução agendada de campanhas de mensagens já tem consumidor próprio, com configuração, consentimento, limites e revisão exigidos no fluxo existente. A tela agora reúne período, horário, fuso, limite e destinatários em “Aprovar e programar envio”; não exige um segundo início. Os testes desta etapa não enviam mensagens reais. O publicador de posts e a criação/ativação automática de campanhas de tráfego **ainda não estão implementados**; as propostas não são apresentadas como campanhas em veiculação. Precisam de adaptadores homologados, identificação remota persistida, reconciliação após respostas incertas, programação, orçamento aprovado por versão e consulta de restrições antes da ativação. Google Ads e Meta têm contratos distintos.

A consulta de `account_status` detecta restrição de conta; não prova especificamente falta de saldo. O campo `balance` não é tratado como crédito disponível. Aviso específico de saldo insuficiente deve ser baseado em resposta verificável do provedor, integrado ao futuro executor e persistido como tarefa, sem repetir ativações incertas. Não foi acrescentada uma simulação de saldo.

Integrações de sistema de gestão, Wellhub/TotalPass, domínio próprio/DNS e acessos avançados dos aplicativos dependem de credenciais e configurações externas. Colocar os controles no onboarding não elimina esses requisitos. O fluxo mostra pendências, sem declarar conexões inexistentes como concluídas.

## Validação

Testes locais de sequência e isolamento cobrem: bloqueio antes de aprovação, impedimento de saltar etapas, alterações invalidando versões, reserva por token, não sobrescrever edição de site, restrição de produção por calendário e perfis Instagram sem métricas inventadas. A validação completa e a revisão visual estão registradas em `docs/progress.md`. As telas foram exercitadas em prévia isolada com dados fictícios, sem chamadas a provedores externos.
