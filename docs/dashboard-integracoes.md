# Dashboard Askadia — integrações e ativação

Atualização de 23/09/2026: a nova visão geral consulta CRM/campanhas, IBGE e Google Places reais. Estado atual, Google Trends, dependências Maps/Meta e situação da migração de BI estão em [visao-geral-bi.md](visao-geral-bi.md). As seções abaixo documentam a fundação do módulo financeiro/importações.

## Situação verificável
O dashboard autenticado está em `/dashboard` e `/resultados`; ambas usam o mesmo motor. O menu Empresas inclui o acesso. O caminho atualmente utilizável após as migrações é **importação CSV auditada → PostgreSQL → API autorizada → dashboard e exportação**.

Nenhuma API externa de marketing/gestão está homologada com uma conta real neste trabalho. Nenhuma credencial nova foi armazenada; nenhuma sincronização, mensagem, publicação, anúncio, cobrança ou deploy foi ativado. Supabase remoto depende das migrações e da homologação de Auth já previstas no projeto principal.

## Banco e permissões
Aplicar `supabase/migrations/202609219001_dashboard.sql` depois das migrações de identidade e fundação do produto. É uma migração aditiva; não foi aplicada remotamente. Não execute isoladamente em banco sem as dependências.

Tabelas: dashboard_permissions, dashboard_imports, dashboard_facts, dashboard_fact_revisions, dashboard_exports e dashboard_keyword_profiles. Escrita ocorre por RPC com checagem de empresa e escopo. Nenhuma escrita direta é concedida a authenticated. Fonte + tipo + ID externo identifica um fato dentro da empresa. Repetição exata do lote é idempotente; alterações geram revisão e log. Perfil de palavras-chave é confirmado e auditado.

Proprietário recebe acesso próprio. Marketing acessa métricas digitais; detalhes financeiros exigem `dashboard_grant(company,user,financial_details,manage_costs)`, disponível somente ao proprietário. A interface de equipe ainda não incorpora esses dois controles; a chamada autenticada da RPC é o mecanismo implementado. Não forneça service_role ao navegador. Suporte/admin usam sessão interna auditada, vinculada ao operador e empresa; somente platform_admin pode consultar finanças nesse fluxo. Exportação é reautorizada no banco.

Os testes exercitam PostgreSQL real via PGlite com fixtures locais de Auth/Storage. Isso não substitui homologação no PostgREST hospedado, cookies, rede e contas reais.

## Importação assistida
1. Entre no dashboard, selecione a empresa e o período coberto.
2. Escolha Importar dados. Baixe um modelo vazio para anúncios, pagamentos, estornos, custos, Instagram ou site; preencha com dados exportados da fonte. Os arquivos em `apps/web/public/templates/dashboard` não contêm exemplos financeiros.
3. Use uma fonte estável (ex.: fornecedor-unidade), o mesmo ID externo nas correções, datas ISO, centavos inteiros, true/false para booleanos e campos vazios somente onde nulos são admitidos.
4. Informe se a cobertura é parcial ou completa e descreva origem, descontos/deduções, limitações e classificação de custos. A declaração de cobertura é responsabilidade de quem importa.
5. Valide, confira quantidade/fonte/empresa/período e confirme. A API repete validação e autorização ao salvar; prévia não autoriza escrita futura.
6. Arquivos com tipos diferentes usam importações separadas. Pagamentos e estornos do mesmo fornecedor devem manter o mesmo identificador de fonte.
7. Google Trends usa CSV temporal do produto, não o modelo normalizado. Região informada deve coincidir com o cabeçalho. Lotes independentes conservam escala própria. Exportações mensais com datas YYYY-MM ainda não são aceitas pelo parser ISO diário; use uma série com datas completas.
8. Para sugestões, confirme os serviços realmente oferecidos em Tendências. Sugestões são editoriais até existir pesquisa medida.

Máximo: 1,5 MB de texto CSV, até 1.000 registros. O corpo JSON possui limites adicionais no BFF/API. Nenhum dado clínico, ficha de treino, documento, telefone ou e-mail é necessário no modelo financeiro. Campos extras são recusados.

## Adaptadores de leitura
`packages/integrations/src/reporting.ts` implementa portas TrendsProvider, SocialMetricsProvider, AdsReportingProvider, WebAnalyticsProvider e ManagementSystemProvider. Os adaptadores abaixo fazem somente consultas; eles **não estão ligados a uma conexão ativa nem persistem suas respostas automaticamente**.

| Fonte | Implementado | Pendente para produção |
|---|---|---|
| GA4 | runReport por data, sessions/totalUsers/keyEvents, paginação, erros sanitizados | OAuth/cofre, propriedade, instrumentação, fuso, metadados de limiar, normalização/persistência e teste real |
| Search Console | searchanalytics.query por data/página, cursor por offset, cobertura parcial | OAuth, propriedade validada, fuso da fonte, normalização/persistência e teste real |
| Google Ads | googleAds:search, conta/campanha/dia, gasto em micros, métricas e paginação | Developer token, OAuth, versão suportada, conta/MCC, regras de conversão de micros, configuração de atribuição e homologação |
| Meta Ads | Insights de campanha/dia, gasto/impressões/cliques, cursor; URLs next não são seguidas | App aprovado, ads_read, OAuth/cofre, versão suportada, moeda/fuso, normalização/persistência e homologação |
| Instagram | Listagem de mídia profissional via Facebook Login, curtidas/comentários acumulados | App/permissões, vínculo da conta, Insights por formato para alcance/saves/shares/views, persistência e homologação |
| Google Trends | CSV temporal auditado e candidatos editoriais; contrato de provider | Acesso aprovado à API alpha. Não há scraping nem API pública presumida |
| Gestão | Interface completa e PendingManagementProvider, CSV financeiro versionado | Fornecedor/unidade, documentação, credenciais, histórico, pagamentos, estornos, custos e reconciliação |
| Formulários | Modelo de fato e importação de eventos confirmados | Instrumentação e ingestão automática real do site |

Os adaptadores recebem uma porta obrigatória de autorização e resolução de credenciais do servidor. Nenhum token entra em URL, jobs ou resposta do dashboard. Destinos de rede são fixos; redirecionamentos são recusados. Erros externos não retornam corpos potencialmente sensíveis. Versões de API são configuradas explicitamente, não presumidas como atuais.

## Sincronização
`reporting-sync.ts` fornece processador de página com reivindicação idempotente, revalidação de autorização após a chamada, checkpoint e página transacionais via porta de repositório, retry limitado e respeito a Retry-After. Testes usam repositório em memória exclusivamente como fixture.

**Ainda falta implementar e homologar** o repositório persistente de conexões/jobs/checkpoints, cofre criptografado, fluxo OAuth e configuração de unidade, normalizadores de resposta, cron/quota e registro do consumidor BullMQ. O worker existente permanece com processing:false. O botão Atualizar leitura refaz consulta ao banco; não finge agendar uma sincronização inexistente. Não há webhook de fornecedor presumido.

Correspondência automática com CRM, janela de último toque, fila de casos ambíguos, fechamento conciliado por oportunidade e regras de rateio de coorte continuam pendentes. A origem atual é declarada na importação com evidência textual; não é prova automática de match.

## IA
`apps/api/src/dashboard/diagnosis.ts` define snapshot sem dados de alunos, chave SHA-256 por conteúdo e contrato de interpretação. Sem serviço/cache configurado, retorna configuração pendente, sem texto inventado e sem chamada paga. Ainda não há endpoint de geração ativa nem cache persistente. Nenhuma publicação ou mudança de verba é disparada.

## Referências oficiais consultadas
- [Google Trends API alpha](https://developers.google.com/search/apis/trends): acesso depende de aprovação; escala de API não é presumida equivalente ao CSV.
- [Instagram API — coleção oficial Meta](https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api): modalidades de login e conta profissional.
- [Marketing API — coleção oficial Meta](https://www.postman.com/meta/facebook-marketing-api/documentation/0zr4mes/facebook-marketing-api-mapi): relatórios Insights.
- [Google Ads reporting](https://developers.google.com/google-ads/api/docs/reporting/overview) e [Search REST](https://developers.google.com/google-ads/api/rest/common/search).
- [GA4 runReport](https://developers.google.com/analytics/devguides/reporting/data/v1/rest/v1beta/properties/runReport).
- [Search Console query](https://developers.google.com/webmaster-tools/v1/searchanalytics/query): resultado pode representar principais linhas, não universo completo.

## Próxima homologação
Aplicar migrações autorizadas, entrar com duas empresas e papéis diferentes, importar relatórios reais pequenos e conciliar com os totais das fontes. Confirmar fornecedor de gestão e acesso às contas de marketing. Implementar cofre/OAuth/jobs/normalização antes de ativar qualquer rotina externa. Homologar PDF, interface móvel/teclado e revogação em contas reais; os testes locais não constituem esse aceite.
