# Auditoria do dashboard — 21/09/2026

Escopo: dashboard e infraestrutura de indicadores. Especificação recebida em dashboard-requisitos.md. Alterações da fundação em andamento na tarefa principal são preservadas; nenhuma sessão, servidor, credencial ou processo da outra tarefa será alterado.

| Área | Evidência atual | Lacuna |
|---|---|---|
| Visão geral | apps/web/components/workspace.tsx; hero, quatro cards e localStorage | Sem métricas externas persistidas |
| Resultados | Item de navegação e estado explicativo no mesmo componente | Nenhuma camada própria de métricas |
| Autenticação/empresa | Supabase SSR, BFF, Nest AuthGuard, RLS, companies | Reutilizar JWT e contexto; nunca aceitar filtro como autorização |
| Perfis | company_members, platform_staff, company_assignments, internal_access_sessions em migração | Permissão financeira deve ser específica; sessão interna conserva operador |
| CRM | contacts, opportunities, stage_history | Sem sistema de gestão; matriculado não comprova pagamento |
| Conexões | packages/integrations: catálogo e UnconfiguredAdapter | Sem OAuth, tokens de ativos ou coleta homologada |
| Filas | BullMQ registra filas; processing=false | Não existem consumidores de sincronização |
| Planos | Catálogo/estrutura em desenvolvimento separado | Não pressupor planos ativos |
| Visual | --bg #f7f8fa, --surface #fff, --ink #242528, --muted #72757e, --line #e8e9ed, --radius 16px | Reusar tokens e componentes; reduzir hero na área operacional |
| Fontes financeiras | Nenhuma tabela operacional de pagamentos/custos/atribuição | Capturar origem, cobertura, idempotência, versões e limitações |
| IA | OpenAI apenas catálogo | Não gerar análise fictícia nem chamada paga ao abrir dashboard |

## Estratégia de implementação

Módulo isolado dashboard no Nest; contratos e cálculos determinísticos compartilhados; rotas /dashboard e /resultados apontam à mesma interface/fonte. Migração nova e aditiva, sem aplicar banco remoto nesta tarefa. Demo não alimenta indicadores oficiais.

Importações assistidas exigem validação, prévia, empresa de destino e persistência auditada. Correções substituem a versão atual da mesma chave externa e preservam a anterior. Ausência de fonte não significa zero. CSV manual não é homologação da API.

APIs consultadas em 21/09/2026:
- Google Trends: https://developers.google.com/search/apis/trends — acesso alpha; nenhuma credencial aprovada fornecida.
- Google Ads: https://developers.google.com/google-ads/api/docs/reporting/overview
- Instagram (coleção oficial Meta): https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api
- GA4: https://developers.google.com/analytics/devguides/reporting/data/v1
- Search Console: https://developers.google.com/webmaster-tools/v1/searchanalytics/query
- ROI: https://support.google.com/google-ads/answer/1722066?hl=pt-BR

Fórmula financeira normativa: prompt do usuário. Interpretação não representa causalidade nem ROI contábil da empresa.

## Resultado da etapa local do dashboard

Entregue:
- Rotas autenticadas /dashboard e /resultados com a mesma fonte e navegação a partir do workspace; acesso interno reutiliza a sessão auditada.
- Interface neutra responsiva, seleção de 6–8 KPIs, filtros de URL, cancelamento e descarte de consultas antigas, memória de cálculo legível e tabelas alternativas às séries.
- Importação CSV com modelos vazios, validação/prévia/confirmação, isolamento de empresa, chave externa estável, revisões e logs.
- Métricas financeiras determinísticas, distinção entre zero e ausência, proteção contra custos desconhecidos, duplicação de mídia, receita de clientes antigos e estornos inválidos.
- Separação entre métricas sociais acumuladas e atividade no intervalo; taxas de anúncios calculadas pelos totais.
- Perfil confirmado e auditado para 20 candidatos editoriais; importação Trends preserva região, lote e escala.
- Exportação CSV/PDF privada e auditada com snapshot e método.
- Adaptadores de consulta de leitura, contratos de gestão/IA e processador de sincronização por portas, testados com fixtures isoladas.

Não é uma entrega completa de conectores em produção:
- OAuth/cofre, persistência de conexões/jobs/checkpoints, normalização das respostas reais e ativação dos consumidores continuam pendentes.
- Sistema de gestão não informado; nenhuma API de gestão presumida.
- Insights completos do Instagram, aprovação da API Trends e acesso real a Meta/Google/GA4/Search Console pendentes.
- Reconciliação automática com CRM, fila de ambiguidade, atribuição automática, rateio de coortes e diagnóstico de IA ativo ainda não implementados.
- O funil exibe etapas atuais; não inventa tempos médios, taxas históricas ou indicadores individuais sem eventos e responsáveis disponíveis.
- Permissões financeiras possuem RPC e RLS, mas ainda não há controles correspondentes na tela de equipe.
- Banco remoto não recebeu esta migração. No navegador local, /dashboard redirecionou corretamente para /login; homologação visual autenticada e uso em celular com dados reais continuam pendentes.

Documentos operacionais: dashboard-metricas.md (definições) e dashboard-integracoes.md (ativação, capacidades e limites). Nenhum registro financeiro de teste foi inserido na aplicação.

Validação final desta etapa: pnpm check passou com lint, tipos, 91 testes em 7 arquivos e build completo. Fixtures de testes são isoladas; nenhuma API de marketing/gestão foi homologada em conta real.
