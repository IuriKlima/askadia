# Requisitos v1 — rastreabilidade

Fonte: docs/requirements-v1.md, recebida em 21/09/2026, complementar ao blueprint.
Em caso de detalhamento novo, usar requisitos v1. Decisões comerciais abertas continuam abertas.

| Requisito | Implementação atual | Prova / pendência |
| --- | --- | --- |
| EMP 01 | CRUD limitado a criar/editar/arquivar/restaurar empresas, sem cobrança | SQL/HTTP local; homologação Supabase pendente |
| EMP 02 | company_id, chaves compostas, RLS e bucket privado | Demais entidades serão implementadas por módulo |
| EMP 03 | Seletor por usuário, dados e equipe descartados na troca | Testes e revisão de UI conectada com contas reais pendentes |
| EMP 04 | Vínculos por empresa e proprietário separado de operação | Billing e visão consolidada pendentes |
| ACE 01 | Login/cadastro/recuperação, convites, aceite, remoção e auditoria | SMTP/Auth real pendente; convite por link manual |
| ACE 02 | Verificação Nest + RLS + Storage | Realtime ainda não usado; prova de serviço hospedado pendente |
| ACE 03 | Perfil support e approver explicitamente atribuídos por empresa | Entitlement de acompanhamento/plano será aplicado na cobrança |
| UX 01 | Interface neutra, português e layouts responsivos | Login revisado em desktop/celular; UI conectada depende de projeto |
| UX 02–04 | Navegação base e mensagens de estados reais | Pendências operacionais e acompanhamento serão módulos posteriores |
| SEG 01 | JWT verificado, DB com JWT do usuário, RPCs limitados, CSRF no BFF | Sem credencial privilegiada nesta etapa |
| SEG 03 | RLS Storage e exportação de metadados restrita/auditada | Uploads, exportação CRM, retenção e exclusão posteriores |
| TEC 02 | Relações compostas e políticas por empresa | Jobs, conhecimento e Realtime posteriores |
| VAL 01 | Testes locais de acesso negativo e separação | Billing e homologação integral pendentes |
| DOM 01–05 | Especificação incorporada | Futuro módulo site/domínio; nenhum DNS alterado |
| Demais requisitos | Planejados no blueprint | Não implementados ou não homologados nesta entrega |
