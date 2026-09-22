Marketing Fitness IA — arquitetura e roteiro para o Codex

Versão de planejamento: 20/09/2026. Documento de especificação; nenhuma integração ou implementação foi executada neste trabalho.

1. Decisões confirmadas e propostas

Confirmado com o fundador:

Lançar no segmento fitness e expandir depois.

Marketing básico: R$ 497/mês por empresa.

Acompanhamento semanal: adicional de R$ 1.000/mês, com participação do cliente e da equipe.

Plano superior com atendimento e triagem de leads por IA, WhatsApp e Instagram; preço ainda não definido.

Área de trabalho permite adicionar várias empresas.

CRM para organizar os leads recebidos.

Aprovação de planejamento, peças e orçamento pelo cliente ou responsável autorizado.

Vídeos: roteiro, instruções de gravação e edição, upload do vídeo final e programação. Edição automática fora da primeira versão.

Integração com Meta Ads e Google Ads.

Site institucional para empresas que não possuem site.

Agente estrategista mensal, acionável manualmente.

Propostas deste desenho, ainda ajustáveis:

CRM básico em todos os planos; caixa de entrada e agente de triagem no superior.

Adicional semanal contratado por empresa.

Primeiros métodos especializados para academias e estúdios.

Uma assinatura independente por empresa, permitindo planos diferentes na mesma área.

Franquias, preço superior, política de inadimplência e regra para unidades/filiais permanecem configuráveis. Não usar números provisórios como limites comerciais definitivos.

2. Área de trabalho, empresa e cobrança

Workspace é o contêiner de gestão. Company é a unidade de assinatura e isolamento operacional. Usuário pode pertencer a vários workspaces e ter acessos diferentes nas empresas.

Um workspace pode ter empresas A e B no básico: 2 × R$ 497 = R$ 994/mês. Com acompanhamento em apenas A: R$ 1.994/mês. Verba de mídia e eventual consumo variável não estão nesses valores.

Cada empresa possui onboarding, marca, arquivos, CRM, credenciais, campanhas, calendários, memória de IA, assinatura, adicionais e medidores de consumo próprios.

Adicionar empresa cria um rascunho e apresenta o preço antes da contratação. Não ativar uma assinatura apenas pelo clique em adicionar. Mudança de plano, cancelamento e inadimplência afetam somente a empresa correspondente. Cancelar não significa apagar dados imediatamente; retenção, exportação e encerramento devem ter regras explícitas.

Uma empresa pode futuramente ter filiais. Não confundir company_id com CNPJ nem cobrar automaticamente por filial sem decisão comercial.

Papéis:

Proprietário do workspace: gerencia empresas, membros e cobrança.

Administrador da empresa: configura empresa e acessos autorizados.

Aprovador: aprova conteúdo e campanhas conforme permissão.

Atendente: acessa CRM e conversas autorizadas.

Leitor: consulta relatórios permitidos.

Equipe de acompanhamento: recebe acesso explícito a empresas contratantes, com auditoria.

Operação da plataforma: privilégios administrativos excepcionais e auditados, sem acesso indiscriminado pela interface comum.

A permissão de pagar uma assinatura não precisa conceder acesso a conversas. Toda permissão deve ser verificada no servidor e no banco quando aplicável.

3. Arquitetura escolhida

Monorepositório TypeScript com pnpm.

apps/web: Next.js, React, Tailwind e shadcn/ui.

apps/api: NestJS com módulos de negócio.

apps/worker: processos BullMQ para IA, mídia, mensagens, publicação e métricas.

packages/contracts: esquemas Zod e contratos compartilhados.

packages/ui: componentes e tokens.

packages/integrations: adaptadores de provedores.

supabase/migrations: migrações SQL versionadas, incluindo RLS.

docs: PRD, arquitetura, contratos, decisões, testes e progresso.

PostgreSQL/Supabase, Auth e Storage. Redis para filas; PostgreSQL como fonte persistente do estado do negócio. Realtime pode atualizar CRM e caixa de entrada, com autorização por empresa.

Backend modular inicialmente; workers podem escalar independentemente. Não iniciar com microserviços por agente. Agentes são rotinas especializadas, com ferramentas restritas, contexto por empresa e contratos de saída.

Acesso de usuários pode usar JWT e RLS. Se uma conexão de backend ou ORM ignorar RLS, aplicar autorização explícita, papéis de banco apropriados e testes. Nunca assumir que Prisma ou outro ORM aplica automaticamente as políticas do Supabase.

Hospedagem: decidir um provedor para web, API e workers após confirmar o ambiente do repositório. Workers devem ter processo adequado a tarefas longas. Redis e banco precisam de persistência e recuperação. Ambientes separados: desenvolvimento, homologação e produção.

4. APIs e integrações

Integração proposta

Uso

Pré-requisito ou cuidado

OpenAI Responses API

Onboarding, estratégia, textos, triagem e ferramentas

Credencial no servidor, modelos configuráveis e orçamento por tarefa

OpenAI Structured Outputs

Entregas em esquemas validados

Esquema válido não prova que o conteúdo é verdadeiro

OpenAI Image Generation

Geração/edição de imagens quando necessária

Preservar logos, texto e produtos com composição controlada e revisão

OpenAI web search

Pesquisa pública com fontes

Cobertura não garantida, registrar data e evidências permitidas

Google Places API (New)

Descoberta local de concorrentes

Billing, restrição da chave, campos mínimos, regras de retenção e atribuição

Meta Marketing API

Campanhas, anúncios e indicadores

Contas autorizadas, permissões e aprovação aplicáveis ao app

Instagram API e APIs de Pages

Publicação e métricas dos formatos suportados

Validar fluxo de login, conta, formatos e permissões em prova técnica

WhatsApp Cloud API

Mensagens, recebimento e status

Número/conta empresarial elegíveis, políticas, templates e custos

WhatsApp Embedded Signup

Conexão de empresas clientes

Validar requisitos como fornecedor de tecnologia e coexistência/migração

Instagram Messaging

Caixa de entrada e resposta

Validar elegibilidade, permissões e regras de janela/iniciação

Meta Lead Ads

Entrada de formulários de anúncio no CRM

Webhook e recuperação autorizada dos dados; validar permissões específicas

Google Ads API

Campanhas de pesquisa inicialmente e relatórios

OAuth, projeto Cloud e nível de acesso de produção autorizado

Google Lead Form Webhook

Leads de formulários nativos, quando usados

Validar chave do webhook e disponibilidade do formato

Google Analytics Data API

Relatórios GA4

Propriedade autorizada e instrumentação prévia; API não instala rastreamento

Asaas API

Assinaturas por empresa e cobranças

Sandbox, webhooks e reconciliação de pagamentos

Resend API

Convites e notificações transacionais

Domínio verificado e tratamento de falhas

CRM, calendário, site e aprovações são módulos próprios; não exigem contratar uma API de CRM. Renderizar artes com templates, SVG/HTML e ferramentas de imagem. Não é necessário usar Canva na primeira versão.

Não há uma API universal que entregue todo o conteúdo, investimento e resultados dos concorrentes. Usar pesquisa pública e interfaces autorizadas; mostrar dados indisponíveis em vez de inventá-los. Não persistir conteúdos do Places como um acervo ilimitado; respeitar as condições da fonte.

Medição avançada posterior: avaliar Meta Conversions API e recursos de conversões do Google Ads, com verificação da versão vigente, consentimento aplicável, eventos reais e deduplicação. Não são pré-requisitos para o primeiro CRM.

Documentação detalhada de alguns endpoints Meta apresentou bloqueio nesta pesquisa. As coleções oficiais confirmam os produtos e operações gerais; nomes exatos de escopos, elegibilidade e regras devem ser confirmados antes da implementação. Não fixar no código versões de API copiadas de exemplos antigos.

5. Provas técnicas antes da promessa comercial

Iniciar pedidos de acesso cedo. Homologação de terceiros é dependência externa e não é resolvida somente com programação.

Para cada conector, registrar em docs/integrations-status.md:

Produto e documentação oficial consultada.

Versão de API e data de revisão.

Permissões solicitadas, justificativa e status.

Ativos elegíveis e conta de teste utilizada.

Operações testadas de verdade, operações simuladas e operações bloqueadas.

Fluxos de autorização, renovação/reconexão e revogação.

Cobertura de tipos de campanha, mídia e mensagem.

Limites, custos conhecidos e requisitos pendentes.

Provas mínimas: conectar empresa; identificar ativo correto; receber webhook; consultar métricas; enviar mensagem autorizada de teste; criar campanha pausada; publicar material somente em conta de teste com autorização.

Não iniciar gasto em anúncios como parte de um teste automático.

6. CRM e atendimento

CRM básico:

Kanban e lista com filtros, busca e paginação.

Contatos separados das oportunidades: uma pessoa pode ter mais de um interesse/negociação.

Nome, telefone normalizado, e-mail, interesse, origem, responsável, tags e próximas tarefas.

Histórico de alterações, notas, atividades e motivo de perda.

Origem original e pontos de contato posteriores, com UTM e IDs externos quando disponíveis.

Importação CSV com prévia e exportação autorizada.

Formulários do site, captura manual e conectores de formulários nativos.

Agendamento confirmado, comparecimento e matrícula confirmada.

Indicadores de tempo de resposta, conversão por etapa e origem.

Funil padrão: Novo → Em atendimento → Qualificado → Encaminhado → Visita agendada → Compareceu → Matriculado. Perdido é uma saída com motivo. Manter histórico de transição para medir conversão; não depender apenas da etapa atual.

Plano superior:

WhatsApp/Instagram em caixa de entrada com canal visível.

Agente responde somente com fatos e ofertas aprovados.

Triagem de interesse e encaminhamento a humano; suporte a alunos atuais é encaminhado ao canal responsável.

Modo IA, aguardando humano, humano ativo e encerrado.

Assumir conversa cancela respostas automáticas pendentes antes do envio.

Encaminhamento só é concluído após atribuição persistida e confirmação da notificação; falhas ficam visíveis.

Follow-up respeita autorização, opt-out e regras atuais do canal.

Um nome parecido não autoriza fundir contatos. Duplicidade por telefone/ID de canal dentro da mesma empresa; fusão entre canais exige evidência ou ação humana.

O mesmo telefone em empresas diferentes permanece em registros separados.

Matrícula só é confirmada por evidência operacional ou usuário autorizado.

Áudio e outras modalidades de atendimento podem ser extensão futura; não estão implicitamente incluídos na primeira entrega.

7. Modelo de dados mínimo

Domínio

Entidades

Identidade

users/profiles, workspaces, workspace_members, companies, company_members

Comercial SaaS

plans, company_subscriptions, company_addons, billing_events, usage_ledger

Conhecimento

company_profiles, offers, brand_kits, knowledge_documents, onboarding_answers

Pesquisa

competitors, research_runs, source_references

Planejamento

playbooks, strategy_versions, campaigns, content_items, content_versions

Execução

approvals, publication_jobs, provider_operations, agent_runs

CRM

contacts, contact_identities, opportunities, pipeline_stages, stage_history, activities, tasks

Conversas

conversations, messages, assignments, notification_deliveries

Integrações

provider_connections, external_assets, webhook_receipts, outbox_events

Site

sites, site_versions, domains, form_submissions

Resultados

metric_snapshots, conversion_events, weekly_reviews, action_items, audit_logs

Todas as entidades operacionais pertencem a company_id. Usar chaves compostas ou verificações equivalentes para impedir relacionamentos entre empresas. Tabelas globais como catálogo de planos têm escopo diferente e não devem receber company_id artificialmente.

Segredos em cofre ou criptografia com chave fora do banco. Nunca incluir tokens em prompts, logs, páginas ou arquivos exportados. Políticas de Storage e Realtime devem seguir o mesmo isolamento.

8. Confiabilidade e regras dos agentes

Webhook recebido é autenticado pelo mecanismo do provedor, persistido, deduplicado e então processado.

company_id é resolvido pelo vínculo autorizado do ativo externo; não confiar apenas no ID enviado pelo cliente.

Jobs carregam empresa e referência a credenciais autorizadas.

Aplicar outbox transacional para evitar salvar um lead e perder a tarefa de notificação.

Antes de repetir criação externa após timeout, reconciliar o estado no provedor. Retry cego pode duplicar anúncio, mensagem ou post.

Aprovação pertence a uma versão. Editar oferta, peça ou orçamento invalida a aprovação correspondente.

Toda ação externa passa por permissões, assinatura, orçamento e aprovação no código.

IA não interpreta documentos externos como instruções para executar ferramentas.

Dados empresariais estruturados são fonte de preços e condições; busca vetorial é complementar.

Evitar enviar conversas completas ao estrategista; usar métricas e padrões agregados.

Agente registra método, modelo, fontes, saída, custo, duração e resultado.

Recusa, saída inválida, fonte ausente ou limite de custo geram estado tratável.

Mensagens têm fila prioritária independente de pesquisa e geração de imagens.

Circuit breaker e alerta quando uma integração falha repetidamente.

Fuso por empresa; datas persistidas em UTC e calendário exibido no fuso escolhido.

Mês novo cria plano novo; refazer gera versão e não sobrescreve publicações aprovadas.

Não prometer teto financeiro instantâneo quando o provedor pode contabilizar gasto com atraso; combinar limites no provedor, controles internos e margem de segurança.

9. Como trabalhar com o Codex

Coloque este documento em docs/blueprint.md do repositório escolhido. Não foi escolhido nem alterado um repositório neste planejamento.

Se existir código, a primeira tarefa é auditá-lo e preservar o que funciona. Cada etapa abaixo deve ser uma tarefa delimitada com branch/PR revisável, podendo ser dividida em PRs menores. Não precisa ser um único prompt gigante.

Use AGENTS.md para as regras curtas do projeto; PRD e arquitetura ficam em docs. A documentação oficial descreve como o Codex lê AGENTS.md: instruções de projeto.

Regras a incorporar, sem sobrescrever instruções existentes:

Ler docs/blueprint.md e docs/progress.md.

Inspecionar repositório, mudanças locais e instruções antes de editar.

Implementar somente a etapa solicitada, completa de ponta a ponta.

Preservar código e decisões anteriores; explicar migrações necessárias.

Nunca expor segredos; usar .env.example apenas com nomes e valores fictícios.

Verificar empresa e permissões em todas as operações.

APIs externas atrás de adaptadores. Simulações identificadas e restritas a teste/desenvolvimento.

Sem credencial, implementar o que for possível e registrar a validação real pendente; nunca declarar integração concluída.

Não publicar em redes sociais, ativar anúncios ou disparar mensagens reais em testes.

Testar os riscos específicos do módulo e apresentar evidências.

Atualizar progresso com concluído, pendente, validações e comandos executados.

Não fazer deploy de produção, merge ou migração destrutiva sem a autorização correspondente.

Modelo de encerramento de cada tarefa:

O que funciona.

Como validar.

Testes executados e resultados.

Integrações reais versus simuladas.

Pendências e limitações.

Próxima etapa.

10. Prompts sequenciais

Cada bloco abaixo pressupõe este guia salvo em docs/blueprint.md. Execute na ordem, revendo o resultado antes de iniciar o próximo. A etapa 0 permite começar sem credenciais; ela documenta os acessos que precisam ser providenciados.

Etapa 0 — Auditoria e plano do repositório

Leia as instruções existentes e docs/blueprint.md. Audite a estrutura, dependências, autenticação, banco, telas e testes existentes. Se o repositório estiver vazio, proponha a estrutura descrita no guia. Crie docs/prd.md, docs/architecture.md, docs/progress.md e docs/integrations-status.md com as decisões confirmadas, propostas e pendências. Proponha alterações pequenas no AGENTS.md sem apagar regras anteriores. Não reescreva a aplicação nesta etapa. Identifique riscos concretos e descreva os comandos de desenvolvimento. Critério de aceite: plano de implementação que distingue reaproveitamento, código novo e acesso externo pendente.

Etapa 1 — Base executável

Implemente a base Next.js, NestJS, worker, contratos e componentes compartilhados conforme a auditoria. Configure ambiente local, migrações, validação de ambiente, lint, tipos, build e CI. Crie interface em português com navegação, estados de carregamento/erro/vazio e visual moderno com transparências discretas, contraste e acessibilidade. Não preencha dashboards com números inventados. Prepare adaptadores para provedores e filas separadas. Critério: web, API e worker iniciam pelo README, healthchecks funcionam e build passa.

Etapa 2 — Workspaces e empresas

Implemente login Supabase, workspaces, empresas, convites, membros e permissões por empresa. Criar empresa gera rascunho sem cobrança. Implemente seletor persistente de empresa e autorização server-side. Adicione RLS, políticas de arquivos e canais de atualização autorizados. O frontend não pode escolher livremente company_id para obter dados. Teste usuário de A tentando consultar, alterar e exportar dados de B, inclusive dentro do mesmo workspace. Teste membro removido. Critério: duas empresas isoladas funcionam e acesso cruzado é negado em API, banco e arquivos.

Etapa 3 — Assinatura por empresa

Implemente billing pelo adaptador Asaas em sandbox. Plano básico R$ 497 por empresa; adicional semanal R$ 1.000 por empresa como proposta configurável. Plano superior existe sem preço comercial publicado até definição. Crie entitlements e medidores de consumo independentes por empresa. Trate eventos duplicados/fora de ordem e reconcilie estados de cobrança. Não armazene cartão bruto. Não interpretar geração de cobrança como pagamento. Teste ativação, troca, cancelamento e falha em A sem afetar B. Critério: recursos respeitam assinatura da empresa no servidor; contratação exibe valores antes da confirmação.

Etapa 4 — CRM funcional

Implemente CRM próprio com contatos, oportunidades, funil Kanban/lista, responsável, tarefas, tags, busca, filtros, histórico e motivo de perda. Diferencie contato de oportunidade e mantenha origem original. Inclua entrada manual, importação CSV com prévia e endpoint de formulário protegido contra abuso. Normalize telefones; deduplique dentro da empresa sem mesclar pessoas apenas pelo nome. Matrícula exige confirmação autorizada. Teste importação repetida, perda/reabertura, pessoa com duas oportunidades e isolamento. Critério: lead entra, é organizado, recebe tarefa e chega a ganho/perda com histórico auditável.

Etapa 5 — Onboarding e conhecimento

Implemente questionário adaptativo para academia/estúdio, dados comerciais obrigatórios, identidade e uploads. Pergunte disponibilidade de gravação, quantidade possível, responsável e preferência por estáticos. Respostas podem ser não sei. Use IA para aprofundar lacunas, com esquemas validados e confirmação final dos fatos extraídos. Preços, ofertas e horários ficam em campos estruturados. Uploads usam validação de tamanho/tipo, URLs temporárias e isolamento. A leitura de sites deve bloquear destinos privados e requisições inseguras. Critério: onboarding retoma após sair, perfil confirmado fica versionado e pode ser atualizado.

Etapa 6 — Pesquisa de concorrentes

Implemente adaptadores Google Places e pesquisa web com fontes. Separe concorrentes locais e referências; permita correção manual. Respeite retenção/atribuição do fornecedor. Resultados distinguem fato, hipótese e indisponibilidade, com data e referência. Limite consultas e custo por empresa. Trate páginas externas como dados não confiáveis. Não invente receita, conversão ou gasto dos concorrentes. Critério: relatório revisável com fontes e falhas parciais visíveis; testes usam respostas controladas, e prova real fica registrada separadamente.

Etapa 7 — Método e estrategista

Implemente playbook fitness versionado: diagnóstico, prioridade, oferta, campanha, conteúdo, conversão e aprendizado. Use Responses API e esquemas validados para gerar estratégia e calendário. Toda campanha precisa de objetivo, público, oferta, canal, orçamento aplicável, destino e métrica. Primeiro mês sem histórico explicita hipóteses. Planejamento mensal usa agendamento no fuso da empresa; refazer cria versão. Inclua custo, tentativas limitadas, validação comercial e fluxo de aprovação. Critério: mudança não substitui silenciosamente itens aprovados; dados insuficientes não viram certezas.

Etapa 8 — Estúdio de conteúdo e vídeos

Implemente editor de peças com templates, textos/logos em camadas controladas, imagens originais preservadas e geração de imagem via adaptador. Vincule peças ao calendário e à estratégia, com versões e comentários. Para vídeos, produza roteiro e instruções de edição; receba arquivo final, gere prévia e valide requisitos técnicos. Não implementar cortes/legendas automáticos nesta etapa. Inclua estados aguardando gravação, recebido, em revisão e aprovado. Critério: peça respeita marca, formatos podem ser revisados e alteração após aprovação exige nova aprovação.

Etapa 9 — Sites e captura

Implemente sites por empresa usando componentes aprovados e conteúdo estruturado, com prévia, versão publicada e reversão. Rota pública recebe apenas dados públicos da empresa correta. Comece com subdomínio e prepare domínio personalizado com prova de propriedade. Formulários criam contatos/oportunidades no CRM, preservando UTM quando disponível, consentimentos necessários e proteção contra abuso. Não publicar avaliações fictícias. Critério: formulário chega à empresa correta; reversão restaura versão anterior e dados privados nunca entram na renderização pública.

Etapa 10 — Publicação e formulários de anúncios

Implemente autorização Meta e conectores de Instagram/Pages conforme documentação e permissões atuais. Registre matriz real de formatos suportados. Publique apenas versões aprovadas, com agendamento por fuso, processamento de mídia, estados reais do provedor e reconciliação após timeout. Adicione entrada Meta Lead Ads e Google Lead Form Webhook onde disponível, com autenticação do evento e deduplicação. Critério: webhook repetido não duplica lead; job repetido não duplica publicação; conexão revogada bloqueia ações e orienta reconexão. Provas reais somente em contas autorizadas.

Etapa 11 — Chat e agente de triagem

Implemente WhatsApp Cloud API e Instagram Messaging por adaptadores, conexão por empresa, caixa de entrada e estados de entrega. Adicione triagem por IA baseada em ofertas confirmadas, captura de interesse, atualização do CRM e encaminhamento humano. Não automatizar financeiro/cancelamento de alunos. Controle concorrência: assumir conversa deve impedir resposta da IA que já estava em geração de ser enviada. Use filas por conversa, deduplicação, histórico e notificação confirmada. Follow-up respeita janela, templates, autorização e opt-out conforme canal. Critério: mensagem duplicada não duplica resposta; transferência não fica marcada concluída se falhar; assinatura básica não executa automação premium.

Etapa 12 — Tráfego supervisionado

Implemente Meta Marketing API e Google Ads API inicialmente para formatos definidos na matriz de suporte. Importe campanhas como leitura; controle só após autorização por campanha/conta. Preparar campanha pausada com orçamento, período, público, destino e criativos aprovados. Toda ação passa por autorização, versão aprovada, limites e validação no backend. Faça reconciliação de alterações externas e timeouts; nunca repetir criação sem verificar resultado. Separe proposta, envio, aceitação e reprovação. Critério: orçamento não aprovado é bloqueado, conta errada é negada e criação pausada é comprovada; não ativar gasto em teste.

Etapa 13 — Resultados e acompanhamento semanal

Integre métricas dos conectores e, quando configurado, GA4 Data API. Mostre origem, data de atualização, ausência de dados e janela de atribuição. Separe conversões informadas pelo provedor de matrículas confirmadas; evite somá-las como vendas independentes. Crie painel do cliente e área da equipe de acompanhamento, com pauta semanal, participantes, decisões, responsáveis e prazos. Cliente participa e mantém aprovações salvo delegação explícita. Critério: encontro cria tarefas rastreáveis; equipe acessa apenas empresas autorizadas; estratégia consulta métricas e decisões confirmadas.

Etapa 14 — Homologação e piloto

Execute o percurso cadastro → empresa → assinatura sandbox → onboarding → estratégia → peça/vídeo → aprovação → programação → lead → CRM → triagem → humano → matrícula confirmada. Revise isolamento, webhooks, retomada de jobs, expiração de conexão, consumo, backup e restauração. Verifique acessibilidade e uso no celular. Meça custo por geração, atendimento e empresa; não invente margens. Prepare runbook, evidências, limitações e checklist de implantação. Critério: funcionalidades anunciadas foram comprovadas; integrações pendentes estão sinalizadas; produção permanece uma decisão explícita de lançamento.

11. O que providenciar para as etapas externas

Repositório e acesso do Codex ao código escolhido.

Projeto Supabase de homologação.

Projeto OpenAI API com limite de gasto; assinatura do ChatGPT/Codex não deve ser tratada como crédito de API.

App Meta, ativos de teste e permissões compatíveis; iniciar verificações necessárias.

Projeto Google Cloud, consentimento OAuth, Places e Google Ads habilitados com acessos apropriados.

Contas de anúncios próprias dos clientes, autorizadas por conexão; nunca pedir a senha das redes sociais.

Conta sandbox Asaas e domínio de envio de e-mail.

Domínio e hospedagem da aplicação com endpoints HTTPS para webhooks.

Uma academia/estúdio piloto com informações e materiais reais autorizados.

Credenciais são inseridas em variáveis de ambiente ou cofre, nunca em prompts, commits ou planilhas públicas.

12. Fontes consultadas

Codex e AGENTS.md

OpenAI Responses API

Structured Outputs

Image Generation

OpenAI web search

Meta Marketing API — coleção oficial

Instagram — workspace oficial

WhatsApp — coleções oficiais e Embedded Signup

WhatsApp — preços e categorias

Google Ads — introdução

Google Ads — acesso e permissões

Google Lead Form Webhook

Google Places — Text Search

Google Places — políticas

Google Analytics Data API

Asaas — assinaturas

Supabase — RLS

Resend — API

A arquitetura e a sequência são recomendações de engenharia deste documento. As fontes sustentam capacidades dos provedores, não uma garantia de aprovação, disponibilidade para toda conta ou custo final.