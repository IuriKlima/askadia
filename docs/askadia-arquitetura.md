# Arquitetura consolidada

A especificação normativa está em askadia-requisitos.md. A auditoria está em askadia-auditoria.md.

- Next.js 16.3.5 / React 19.3 para produto, site público e BFF. Nest 11 para regras. Supabase PostgreSQL/Auth/Storage; JWT do usuário preserva RLS. Nenhuma service_role necessária ao login.
- Identidade existente preservada. Papéis legados por empresa continuam válidos. Gerente de marketing é acrescentado. Proprietário é determinado pela relação no workspace.
- Equipe interna usa tabela separada de membros de clientes. Administração global é provisionada somente por operador confiável de banco; não há autoelevação por cadastro/convite.
- Carteira interna explicitamente atribuída. Sessões internas têm operador, empresa, motivo, início, fim e expiração, verificadas a cada leitura. O painel interno não troca a identidade do operador.
- Catálogo, assinaturas e limites persistem por empresa. Estado ausente é rascunho/bloqueado; preço null exige consulta e não autoriza checkout. Limite null não é ilimitado.
- Métodos e ações de IA, aprovação, publicação e orçamento permanecerão distintos. Jobs não poderão transformar acesso de equipe em autorização do cliente.
- OpenAI: estratégia, texto, análise, triagem via adaptador oficial. Gemini: imagens via @google/genai, modelo configurável e sem fallback de provedor. Não implementados/homologados nesta fundação.
- Outbox, workers e scheduler serão acrescentados antes de efeitos externos duráveis. O worker atual não tem consumidores de negócio.
- Rascunhos locais continuam auxiliares. Importação exige destino explícito, validação, prévia e deduplicação. Falha do banco não autoriza fallback automático para demo.

## Fontes verificadas

- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security): grants e políticas se complementam; tabelas públicas devem ter RLS.
- [PostgREST Transactions](https://docs.postgrest.org/en/stable/references/transactions.html): contexto de requisição e transações.
- Documentação local instalada do Next.js em apps/web/node_modules/next/dist/docs, conforme AGENTS.md.

Decisões comerciais abertas permanecem abertas: preço superior, quotas, inadimplência/retenção, reuniões, filiais, domínio e custo operacional.
