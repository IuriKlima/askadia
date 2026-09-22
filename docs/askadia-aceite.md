# Aceite verificável

| Cenário | Evidência atual | Estado |
|---|---|---|
| Isolamento entre empresas/workspaces | PGlite com JWT simulado; SQL real | Testado localmente, pendente Supabase |
| Convite, expiração, revogação, último admin | 14 testes SQL + 9 API | Testado localmente |
| Supabase real | Auth/settings 200; workspaces 401/42501; platform_staff/editorial_drafts PGRST205 | Configurado; atualização do banco e conta real pendentes |
| UI login desktop/celular | Inspeção navegador 1440×1000 e 390×844 | Validado visualmente; login real pendente |
| Perfis, carteira e acesso interno | SQL real: proprietário/marketing/atendente/admin/suporte; sessão auditada; API direta bloqueia escopo indevido | Fundação testada localmente; painéis operacionais completos pendentes |
| Planos e delegações | Assinaturas independentes, expiração, ausência de assinatura, revogação e limite de orçamento | Testado localmente; checkout indisponível |
| Importação de rascunhos | SQL real: deduplicação por empresa, vínculo de contatos, rollback integral, descarte de aprovação local | Testado localmente; importação com conta hospedada pendente |
| Formulários públicos | Ainda ausentes | Pendente |
| Onboarding/Google/OpenAI/Gemini | Nenhum teste externo | Pendente |
| Publicação, atendimento e anúncios | Adaptadores indisponíveis | Pendente |
| Domínios/assinaturas/backup | Nenhum teste externo | Pendente |

Testes determinísticos não serão classificados como homologação de API externa. Não há prontidão de produção.

## Execução de 21/09/2026

- `pnpm test`: 53 testes passaram (14 domínio, 9 API de identidade, 14 identidade/RLS, 16 fundação/importação). PostgreSQL executado via PGlite com fixtures mínimas de Auth/Storage; HTTP Nest usa autenticação controlada.
- Verificação TypeScript isolada dos componentes e rotas da fundação/importação passou. Não substitui compilação completa do projeto.
- Login configurado inspecionado no navegador, com campos habilitados. Grupos de integrações da Askadia e da empresa inspecionados em 390×844; Gemini aparece como não configurado.
- Nenhum cadastro, envio de e-mail, publicação, anúncio, cobrança ou migração remota foi executado nesta validação.

- Validação conjunta: lint e tipos globais passaram, os 53 testes passaram novamente, builds de contratos, integrações, API e worker passaram. O build web apontou reexportação inválida de configuração na rota /resultados; após correção pontual, `pnpm --filter @askadia/web build` passou, incluindo TypeScript e geração das rotas. O comando composto original terminou com esse erro e não foi reportado como execução única bem-sucedida.
- SQL consolidado de atualização comparado às migrações 003 e 004: conteúdo idêntico, com uma transação externa.

- Após reiniciar o desenvolvimento: API /health e worker /health responderam 200; /login carregou no navegador com campos habilitados. Nenhuma sessão real foi criada. Viewport temporário de teste restaurado.

Validação final da correção de cadastro: `pnpm check` passou integralmente (código 0): lint, tipos, 92 testes e builds de web/API/worker. Cadastro da empresa solicitada confirmado na interface autenticada do Supabase; nenhuma cobrança ativada.
