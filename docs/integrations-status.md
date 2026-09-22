# Integrações — atualizado em 21/09/2026
Todas as integrações externas estão **não configuradas e não homologadas**. Não há chamadas reais nem respostas de sucesso simuladas. O catálogo visual não é uma implementação de OAuth ou de APIs de negócio.

| Provedor | Uso previsto | Status / dependência |
| --- | --- | --- |
| Supabase | Auth, Postgres, Storage, Realtime | Auth/API/RLS/Storage implementados e testados localmente; projeto e homologação real pendentes |
| OpenAI | Estratégia, textos, triagem, imagens | Adaptador futuro; chave no servidor, modelo e limites por tarefa |
| Google Places | Pesquisa local | Billing, campos, atribuição e retenção a validar |
| Meta Ads | Campanhas e leads | App, autorização de ativos, permissões e conta de teste |
| Instagram / Pages | Publicação e métricas | Login, conta elegível e matriz de formatos |
| WhatsApp | Atendimento | Cloud API, Embedded Signup e regras de canais |
| Instagram Messaging | Caixa de entrada | Permissões e janelas de conversa |
| Google Ads | Pesquisa e métricas | Projeto, OAuth e acesso de desenvolvedor |
| Google Lead Form | Entrada de leads | Webhook autenticado e formato elegível |
| GA4 Data API | Resultados | Propriedade autorizada e instrumentação prévia |
| Asaas | Assinaturas | Conta sandbox e reconciliação de webhooks |
| Resend | Convites e avisos | Domínio verificado e credencial |

## Evidência atual
- Catálogo de nove grupos de integração na interface e em GET /integrations.
- UnconfiguredAdapter.health retorna available=false.
- UnconfiguredAdapter.execute lança erro; nenhum efeito externo.
- Nenhuma versão de API, escopo, elegibilidade ou preço variável foi fixado por suposição.
- Supabase: cliente oficial instalado, código de Auth e gestão implementado, 37 testes passaram. Não houve chamada real ao fornecedor. Ver docs/identity-setup.md.

## Registro obrigatório por prova técnica futura
Documentação oficial e data de consulta; versão exata da API; permissões justificadas e status; conta/ativo de teste; operações reais/simuladas/bloqueadas; autorização/renovação/revogação; tipos suportados; limites/custos; evidências e pendências.
Provas devem usar contas autorizadas. Anúncios ficam pausados e nenhum teste inicia gasto.

## Dependências para a próxima etapa
Projeto Supabase de homologação e variáveis de ambiente configuradas localmente. Não enviar chaves secretas na conversa.
