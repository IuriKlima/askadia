# Aquisição e planos — 27/09/2026

Decisão posterior do usuário: cadastro e conversa gratuitos; nenhuma IA antes da confirmação do plano. Anual em **12 parcelas** (não mensalidade anual recorrente). Esta decisão substitui os valores comerciais anteriores para novas contratações. Evolution mantida para testes.

## Experiência implementada

- CTAs “Começar grátis” e página pública `/planos`, com recursos, condições por empresa e FAQ.
- Conta confirmada sem empresa segue para `/comecar`: viagem espacial em CSS, boas-vindas personalizadas e entrevista em tela cheia. Um rascunho inicial é reutilizado pelo RPC existente.
- Briefing confirmado passa por animação de ferramentas de sete segundos. Os textos anunciam as próximas etapas; não afirmam que pesquisas ou gerações já aconteceram. A IA continua bloqueada.
- Escolha do plano, checkout de teste e resultados de aprovação, recusa ou cancelamento. Não há captura de cartão nem provedor de cobrança real.
- Confirmação simulada libera o processamento e abre as cinco etapas da estratégia em tela cheia. Cada etapa conserva aprovação por versão. Entrada no sistema exige as cinco aprovações atuais, verificadas no banco.
- Perfil, conexões e ajuste do calendário continuam acessíveis durante a configuração, com retorno explícito à jornada. Retornos OAuth preservam o contexto da empresa e retomam o onboarding em tela cheia quando incompleto.
- Navegação entre telas retorna ao topo e move o foco para o título. Animações respeitam `prefers-reduced-motion`.

## Condições comerciais

| Plano | Pagamento | Total | Escopo |
| --- | --- | --- | --- |
| Mensal | R$ 1.497/mês, recorrente | R$ 1.497 por mês | Todas as funcionalidades, por empresa |
| Anual | 12 parcelas de R$ 998 | R$ 11.976 em 12 meses | Todas as funcionalidades, por empresa |

Verba de mídia, serviços externos e limites de uso não são confundidos com assinatura ilimitada. Catálogo e assinaturas legadas são preservados; a UI comercial usa os novos planos. Nenhuma renovação real foi implementada neste checkout simulado.

## Autorização e processamento

Migração `202609270003_commerce_onboarding.sql`:

- Preços e quantidade de parcelas fixados no banco; cliente envia apenas plano e identificador idempotente. Checkout exige dono do workspace e briefing confirmado.
- Estado persistente por empresa, expiração de checkout em 30 minutos, estados terminais sem reconfirmação divergente e auditoria. Um novo checkout cancela os anteriores pendentes.
- Confirmação é RPC exclusiva de `service_role`, com ator autenticado passado pelo servidor e autorização empresarial novamente conferida. RLS impede escrita direta do cliente.
- Liberação de teste separada de `company_subscriptions`: modo `test`, duração de sete dias, sem registrar receita ou assinatura real como ativa. Acesso real existente continua dependente de assinatura ativa e período válido.
- Gate de IA no banco cobre interpretação, pesquisa Instagram com IA, diagnóstico, calendário, imagens, site, propostas de anúncios, contexto de atendimento e geração de prompt. Filas de conteúdo, lançamento, edição visual, descrição de anexos e preparação de anúncios ignoram empresas sem acesso; nenhuma tentativa é consumida. Pausa/compensação de anúncios existentes continua possível.
- Onboarding gratuito usa interpretação determinística. Busca Google Places e conexão de canais não são chamadas de IA. Uploads são salvos, mas suas descrições automáticas aguardam liberação.
- Proxy autenticado inclui rotas exatas de compra, estratégia guiada, Instagram, edição visual e execução de anúncios, mantendo verificação de origem e sessão. Corrigida a ausência dessas rotas anteriores no encaminhamento web.

## Configuração e implantação

`CHECKOUT_MODE=test` habilita as simulações na API. Foi aplicado somente ao `.env` local; `.env.example` documenta a opção. Qualquer outro valor bloqueia novas simulações. Acessos de teste já emitidos expiram em sete dias; para encerrá-los antes, revogue explicitamente suas linhas em `private.company_test_access` por operação administrativa autorizada. Desabilitar novas simulações não converte acessos de teste em assinaturas reais.

Aplicar todas as migrações pendentes antes de iniciar a nova API e os workers, e publicar web/API da mesma revisão. A checagem de plano falha fechada se a migração estiver ausente. O pacote local `.local/askadia-update-2026-09-27.sql` inclui a migração comercial e as cinco anteriores pendentes. Não reaplicar esse pacote se parte dele já tiver sido executada; use o histórico de migrações.

O checkout real exigirá adaptador de pagamento, verificação de webhook assinado, correlação empresa/checkout/valor, conciliação e eventos de inadimplência/cancelamento. O parâmetro de teste do frontend jamais deve ser aceito como comprovante de pagamento real.

## Validação e limites

Testes PostgreSQL locais cobrem negação de IA antes do pagamento, filas retidas, zero consumo de franquia, preço imutável, anual em 12 parcelas, isolamento por empresa, papéis, confirmação exclusiva do servidor, idempotência, recusa, cancelamento, expiração e conclusão somente após aprovação. Os cenários anteriores de IA agora declaram explicitamente uma assinatura de fixture paga, sem alterar as regras reais de autorização.

Teste do proxy verifica encaminhamento das rotas e rejeição antes da chamada externa para origem indevida, sessão ausente e operações não listadas. Revisão do navegador usou apenas empresa fictícia e respostas locais: boas-vindas, planos, recusa, confirmação explícita, estratégia, resumo da entrevista e animação. Largura 390 px: cartões empilhados, sem overflow horizontal.

Não foram executados migração remota, push, deploy, cobrança, mensagens, anúncios ou geração paga nesta etapa. Permanecem os bloqueios de acesso remoto documentados em `trafego-execucao-2026-09-27.md`. O fluxo foi implementado e validado localmente; homologação com Auth, banco e provedores do ambiente publicado permanece pendente.

Resultado final: `pnpm check` aprovado com 242 testes em 29 arquivos, lint, tipos e builds completos. Após os últimos ajustes, 11 testes dirigidos, build web e lint novamente aprovados.
