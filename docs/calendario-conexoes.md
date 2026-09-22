# Calendário, designer e conexões por empresa

## Jornada e contrato

Estratégia (`/empresa/:id/estrategia`) propõe 12 ideias, com tema, formato e intenção. O modelo configurado é `gpt-5.4`. Aprovar materializa as ideias no calendário, sem publicar nem aprovar peças. Estratégias antigas mantêm sua quantidade original; não há expansão silenciosa de versões aprovadas.

Calendário (`/empresa/:id/conteudo`) detalha as ideias aprovadas usando o perfil confirmado e OpenAI (`OPENAI_MODEL_COPY`, atualmente `gpt-5.4-mini`). Cada item guarda legenda, CTA, hashtags, briefing visual, slides ou roteiro, materiais necessários e pendências. Detalhamento não sobrescreve itens já editados. Mudanças geram revisão e invalidam aprovação.

Designer usa o briefing detalhado, direção estratégica, marca confirmada e até cinco imagens selecionadas dos anexos privados da mesma empresa (12 MB no total). Os bytes das fotos/logos são enviados como referências ao Gemini; não apenas seus nomes. O registro da geração preserva os IDs/caminhos dos materiais escolhidos. Modelo configurado: `gemini-3-pro-image`. Cada slide de carrossel é gerado separadamente e exige revisão visual de consistência. Saída fica privada e vinculada à revisão do conteúdo; respostas atrasadas não substituem edições. Imagem gerada exige aprovação humana, inclusive fidelidade do logo e texto. Arquivos enviados durante uma corrida de revogação/perfil podem permanecer órfãos privados; limpeza por retenção ainda pendente.

Vídeo recebe roteiro e orientação de edição. Upload/aprovação do vídeo final no calendário ainda não implementados: a interface informa a pendência e bloqueia aprovação sem mídia.

## Permissões

| Operação | Exigência |
|---|---|
| Consultar calendário/arquivos/metadados de conexão | `marketing.read` da empresa; RLS e rota privada |
| Detalhar, editar e gerar criativo | `marketing.write`; perfil e estratégia atuais aprovados |
| Aprovar peça final | `content.approve`, mesma revisão e mídia existente |
| Autorizar Meta, parear Evolution e ler credencial cifrada | Proprietário da empresa; sem concessão ao gerente/atendente |
| Receber mensagens/enviar/publicar/ativar Ads | Não habilitado por este incremento |

## Banco

Migração 007: calendário, histórico, reservas limitadas de geração, arquivos e aprovação. Migração 008: conexões, cofre cifrado e sessões OAuth de uso único. Preservam empresas, materiais e versões anteriores. Exigem fundação/jornada 005 já instalada. A migração 006 é necessária para o CRM/handoff, mas o calendário não depende de suas tabelas. Não reaplicar migrações já executadas.

Arquivos preparados para execução manual no SQL Editor: `.local/askadia-calendario.sql` e `.local/askadia-conexoes.sql`. Executar cada arquivo inteiro; envoltos em transação para evitar instalação parcial. Nunca incluir `.env` no SQL nem no repositório.

## Meta: criação do aplicativo

1. Entrar em https://developers.facebook.com/apps/ e criar o app Askadia com o e-mail do responsável. Escolher o caso de uso que oferece a API Instagram com Facebook Login e gerenciamento de Páginas; a nomenclatura deve ser conferida na tela atual. Não escolher apenas anúncios se a prioridade é conteúdo/insights.
2. Para este conector, a empresa precisa de Página e Instagram profissional vinculado. Cada cliente autoriza sua própria conta; não compartilha senha.
3. Configurar `META_APP_ID`, `META_APP_SECRET` e a versão suportada mostrada no painel em `META_GRAPH_API_VERSION`. Segredo somente no servidor. Configurar a origem real em `WEB_ORIGIN`.
4. Callback implementado: `{WEB_ORIGIN}/api/connections/meta/callback`. Cadastrar a URL exata no login Meta. Para ambiente público, usar HTTPS; não registrar localhost como domínio de produção. Domínio público da Askadia ainda precisa ser informado/hospedado.
5. Revisar permissões requeridas pelo caso de uso: `pages_show_list`, `pages_read_engagement`, `pages_manage_posts`, `read_insights`, `instagram_basic`, `instagram_content_publish`, `instagram_manage_insights`. A disponibilidade e o acesso avançado dependem do painel, revisão e verificação exigidas pela Meta; não se consideram concedidos por preencher a configuração.
6. Informar URLs reais de política de privacidade, termos e exclusão de dados; preparar demonstração e usuários de teste para a análise. Em desenvolvimento, homologar com os papéis de teste permitidos. Liberar clientes externos somente após os requisitos da Meta.
7. Em Integrações, o proprietário autoriza no Facebook, escolhe a Página e vê o vínculo do Instagram. O `state` expira em dez minutos e é de uso único. Tokens são cifrados AES-256-GCM com vínculo à empresa; a chave do cofre deve permanecer estável e ter backup privado. Troca por token de longa duração/renovação ainda pendente. Não imprimir tokens nem URLs de callback com códigos em logs.

Conexão não equivale à implementação de publicação/insights: workers de publicação, renovação, sincronização de métricas, tratamento de revogação e homologação real permanecem pendentes.

Referência oficial Meta: https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api

## Evolution

Servidor configurado foi consultado somente para leitura: versão 2.3.7, nenhuma instância retornada à credencial. `EVOLUTION_API_URL` usa a raiz do servidor, sem `/manager/`; chave global fica no servidor. Nenhuma instância foi criada durante os testes.

Cadastrar empresa não cria instância. O proprietário seleciona Conectar WhatsApp em Integrações: a API procura/cria `askadia-{UUID da empresa}` e solicita QR code. Cada empresa tem sua instância; reconexão usa o mesmo nome. Instâncias existentes com nomes diferentes não são importadas automaticamente, para evitar vincular número alheio. Pareamento se confirma consultando `connectionState`; QR code não significa conexão concluída.

Recebimento e envio pelo CRM exigem endpoint público HTTPS, autenticação de webhook por instância, persistência/deduplicação de eventos e associação validada à empresa, além de revalidar tomada humana antes de qualquer envio. Esse consumidor ainda não está implementado. A interface exibe `webhookReady: false`; a configuração não ativa respostas automáticas. Desvincular localmente não executa logout/exclusão remotos. Não usar a chave global como token de webhook.

Contrato oficial consultado: rotas `/instance/create`, `/instance/fetchInstances`, `/instance/connect/:instance`, `/instance/connectionState/:instance` no repositório https://github.com/evolution-foundation/evolution-api. Homologação de criação/QR com a versão instalada ainda pendente.

## Evidência desta entrega
`pnpm check` passou com 120 testes, lint, tipos e builds. Usuário confirmou a aplicação das migrações 007/008; antes retornavam PGRST205, depois 42501 para consulta anônima, como esperado. Aplicativo Meta criado: Askadia Marketing, ID 1061475423356674, sem portfólio por escolha do usuário. Configuração e homologação OAuth ainda pendentes de segredo e origem pública. Nenhuma publicação, anúncio ou mensagem real foi disparada.


## Homologação de calendário/Meta/Evolution — continuação
Calendário verificado no navegador autenticado após 007/008: quatro publicações da estratégia legada, revisões v2, legendas, briefing visual, slides/roteiros e três materiais de referência. Não houve expansão da estratégia aprovada; novos resultados exigem 12 ideias.
Meta: usuário forneceu segredo, salvo apenas no .env; Graph v26.0 confirmado no painel. Callback HTTPS https://askadia.com.br/api/connections/meta/callback salvo e confirmado após recarga, mantendo HTTPS e modo estrito. OAuth local bloqueado até WEB_ORIGIN HTTPS para não encaminhar clientes a callback inválido. Cinco testes do adaptador passaram após esse ajuste e tipos de API passaram. App em desenvolvimento, portfólio e revisão ainda pendentes.
Registro oficial confirmou domínio askadia.com.br ativo, DNS a.auto.dns.br/b.auto.dns.br, consulta DNS pública sem registro A. IP do host Evolution: 2.25.204.218. Usuário escolheu hospedar no mesmo Easypanel; painel aberto e aguardando autenticação. Hospedagem NÃO executada: API e worker ainda possuem bloqueios explícitos de produção que exigem revisão de lançamento; não removidos.
Evolution: servidor 2.3.7 retorna 404 ao buscar uma instância inexistente. Corrigido para criar nesse caso, distinguir erro de credencial e reutilizar a instância existente. Testes verificam 404→criação, reutilização sem duplicação e 401 sem tentativa de criação. Sete testes do adaptador e tipos de API passaram. Validação real pela interface criou askadia-{UUID da empresa Gaviões Varginha}, persistiu vínculo pendente e exibiu QR code. Não houve leitura do QR pelo agente, envio de mensagem ou configuração de webhook.

Meta (configuração no painel): adicionado conjunto obrigatório de conteúdo Instagram com Facebook Login; instagram_basic, instagram_content_publish, pages_read_engagement, pages_show_list e business_management apareceram prontos para teste. Tentativa de adicionar instagram_manage_insights retornou modal da Meta “Ocorreu um erro. Tente novamente mais tarde.”; permissão NÃO habilitada. Configuração de Login para Empresas não finalizada (nenhum config_id gerado); demais permissões Pages/insights, revisão/portfólio e homologação OAuth continuam pendentes. Painel Easypanel ainda sem sessão autenticada. Domínio público/produção não alterados.
