# Auditoria da jornada — 21/09/2026

A reorganização solicitada pelo usuário passa a priorizar empresa → conversa → perfil confirmado → estratégia → aprovações → leads/resultados. Mantém stack, dados, identidade visual e decisões de provedores.

| Evidência | Problema confirmado | Correção desta jornada |
|---|---|---|
| app/page.tsx e /login | Raiz anteriormente era painel/preview | Página institucional pública recém-implementada; entrada em /login |
| components/tenant-workspace.tsx, identity/controller.ts | Criação exige workspace e formulário de empresa; encerra na listagem | Criação atômica de workspace quando necessário e rascunho idempotente; abrir chat imediatamente |
| /workspace | Todos os papéis começam na gestão; menu mistura cadastro, plano e resultados | Resolver contextos autorizados e oferecer início por perfil; selecionar contexto explicitamente |
| /preview e lib/workspace.ts | Estratégia/calendário/CRM de demonstração usam localStorage | Preservar demonstração separada; não apresentar dados locais como operação persistente |
| migrations 003, internal-panel.tsx | Carteira e sessões internas auditadas existem; escopo interno só consulta | Reutilizar sem impersonação e sem transformar papel interno em aprovação |
| Nenhuma tabela de conversa/perfil | Não há onboarding nem fonte única de fatos | Conversa, fatos estruturados, anexos privados, versão confirmada, revisão otimista e trilha |
| DashboardModule, /dashboard e /resultados | Indicadores persistentes com importação e fontes; rota separada da jornada | Preservar dashboard completo em Resultados e ligação contextual no Início |
| integrations/src/index.ts | Adaptadores externos indisponíveis | Contrato de interpretação OpenAI e busca Google; alternativas manuais sem sucesso simulado |
| company_permission_grants e RLS | Permissões reais existentes; UI ainda exibe seções inadequadas | Menu por capabilities e bloqueio no servidor/banco/arquivos; cobrança exclusiva do proprietário |

Não há migração de rascunhos locais automática. Não haverá publicação, cobrança, anúncio ou mensagem real como teste. As migrações incrementais serão entregues para execução pelo usuário, conforme escolha anterior.

## Evidências da implementação

- `packages/contracts/src/onboarding.ts`, `apps/api/src/onboarding/{controller,providers,strategy}.ts`, `apps/web/components/{company-journey,onboarding-chat}.tsx` e migração `202609210005_company_journey.sql`: jornada persistida, entrevista por lacunas, perfil versionado, anexos privados, contexto de estratégia, interpretação estruturada OpenAI e pesquisa Google com alternativa manual. Migração 005 executada pelo usuário com sucesso.
- `/entrada` resolve contextos sem impor criação de negócio ao convidado. `/empresa/[id]/[[...section]]` autoriza a seção no servidor; menu deriva das mesmas capacidades. Papéis internos mantêm sessões auditadas. `followup-panel.tsx` registra encontros, participantes, decisões e próximas ações.
- `202609210006_crm_handoff.sql`, `crm-panel.tsx`: contatos, oportunidades, histórico de estágios, conversas manuais e notas no servidor. Tomada humana cancela trabalhos de IA pendentes; o consumidor deve revalidar revisão e perfil antes de enviar. Transporte e consumidor externo ainda não existem. Aplicação remota da migração 006 aguardando confirmação do usuário.
- `tests/company-journey.test.ts`: transações, repetição/idempotência, revisões concorrentes, isolamento, cinco papéis, revogação, anexos, orçamento de provedores, aprovação vinculada à geração e handoff. Fixtures de PostgreSQL/Auth/Storage não equivalem a homologação de todas as contas no Supabase hospedado.
- Corrigidas falhas observadas: edição de resumo não fecha em erro de gravação; resultado tardio de busca não entra em etapa diferente; menu móvel fechado sai da navegação por teclado; link de convite preservado no callback de confirmação de e-mail; localização isolada não vira nome no modo guiado.

## Provedores testados de verdade

Em 21/09/2026, consultas de metadados autenticadas retornaram 200 para OpenAI e Gemini. Isso comprova acesso aos endpoints, não geração. A interpretação sintética OpenAI retornou 429 sem créditos, inclusive após o usuário informar recarga. Duas tentativas de imagem com `gemini-3-pro-image` retornaram 429 `RESOURCE_EXHAUSTED`, métricas `generate_content_free_tier_*` com limite zero, inclusive após confirmação de faturamento pago. Nenhuma imagem ou estratégia gerada por esses testes. Não foram transmitidos dados reais de clientes nessas chamadas de homologação.

Google Places/Maps ainda sem chaves; pesquisa de site depende de OpenAI disponível. Evolution depende de servidor, instância, credencial e webhook autenticado. Fluxos de publicação, execução de mídia, cobrança e consumidores agendados continuam não homologados; a reorganização não os apresenta como conectados.
