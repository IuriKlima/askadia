# Arquitetura

## Auditoria em 20/09/2026
A pasta ASKADIA estava vazia: sem código, .git, AGENTS.md ou dependências. Não havia componentes a preservar nem remoto para criar branch/PR.
Node 24.13.1 e pnpm 10.33.0 disponíveis.

## Base
Monorepositório pnpm. Next.js 16.3.5 e React 19.3.0 para web. NestJS 11 para API, mantido nesta linha para compatibilidade CommonJS dos pacotes internos. Workers BullMQ independentes. Contratos Zod compilados, UI compartilhada e adaptadores.
Dependências fixadas pelo pnpm-lock.yaml; atualizações devem repetir verificação de build e domínio.

A prévia /preview usa localStorage com contrato versionado. A área /workspace usa Supabase Auth no servidor, BFF Next e rotas de identidade Nest. O BFF mantém tokens em cookies HttpOnly e encaminha somente rotas permitidas. A API valida getUser e acessa o banco com o JWT do usuário. Credenciais não entram no bundle do navegador.

## Segurança implementada e evolução planejada
- JWT verificado no servidor, membership por empresa e permissões específicas.
- PostgreSQL como fonte persistente; RLS, Storage e Realtime coerentes.
- Chaves compostas nos relacionamentos operacionais.
- Nenhuma credencial de serviço no frontend.
- Criação externa somente após autorização, entitlements, versão aprovada e orçamento.
- Webhooks autenticados, vínculo de ativo resolvido no servidor, deduplicação e outbox.
- Timeout externo exige reconciliação antes de repetir.
- IAM/roles para backend que possa ignorar RLS; testes negativos reais obrigatórios.

## Migração inicial
A primeira migração cria workspaces, profiles, memberships, companies, contacts, opportunities e stage_history com acesso fechado. As migrações da etapa 2 acrescentam convites, auditoria, políticas por vínculo explícito, RPCs transacionais e Storage privado. Nenhuma migração foi aplicada ao Supabase remoto.
PostgreSQL/PGlite valida as regras com fixtures de auth/storage. As demais entidades do blueprint, canais Realtime e homologação dos serviços Supabase ainda estão pendentes.
Operações de criação/edição de empresa retornam uma linha composta; o adaptador solicita .single() ao PostgREST para entregar um objeto ao frontend. As funções SQL garantem criação em draft e proíbem alteração de empresa/workspace por DML direto.

## Workers
Filas messages, ai, media, publishing e metrics. Sem Redis: health idle. Redis configurado: registry de filas e health pronto/indisponível conforme conexão. Não existem consumidores de negócio nesta etapa. Separação evita mensagens atrás de pesquisa e geração.

## Aprovação local
O conteúdo possui versão, status e approvedVersion. Editar incrementa versão e remove aprovação. O protótipo preserva apenas a versão atual; armazenamento imutável de todas as versões será feito no banco. Aprovação local não é autorização para publicar.

## Hospedagem
Ainda não escolhida. Servidores locais escutam loopback; não foram implantados. Web, API e worker precisarão de serviços adequados, Redis persistente, Supabase separado por ambiente e HTTPS para webhooks.

## Referências verificadas
- https://nextjs.org/docs/app/getting-started/installation
- https://docs.nestjs.com/first-steps
Consulta em 20/09/2026. A documentação informa que o lint deve ser executado separadamente do build do Next; o pipeline faz ambos. Nenhum escopo ou versão de provedor externo foi inferido.

## Referências da etapa 2 (21/09/2026)
- https://supabase.com/docs/guides/auth/server-side
- https://supabase.com/docs/guides/auth/server-side/advanced-guide
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/reference/javascript/using-modifiers-single
- https://postgrest.org/en/latest/references/api/functions.html

Guia operacional e limitações: docs/identity-setup.md.
