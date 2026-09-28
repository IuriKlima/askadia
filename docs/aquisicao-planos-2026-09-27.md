# Aquisição e planos — atualizado em 28/09/2026

Decisão posterior do usuário: cadastro e conversa gratuitos; nenhuma IA antes da confirmação do plano. A oferta atual é mensal de R$ 1.597 ou semestral de R$ 8.000 em até seis parcelas. A decisão de 28/09 substitui o anual em 12 parcelas para novas contratações. Evolution mantida para testes.

## Experiência implementada

- Onboarding em formato de chat com altura da tela, histórico com rolagem interna e campo de resposta fixo. Os cartões comerciais continuam visíveis se o checkout estiver desabilitado.
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
| Mensal | R$ 1.597/mês, recorrente | R$ 1.597 por mês | Todas as funcionalidades, por empresa |
| Semestral | Até 6x no cartão: 5 de R$ 1.333,33 + última de R$ 1.333,35 | R$ 8.000 em 6 meses | Todas as funcionalidades, por empresa |

Implementação Assistida: R$ 3.500, como brinde para os 100 primeiros clientes. A simulação não reserva vagas da promoção. O controle dos brindes deve acompanhar a futura contratação real.

Verba de mídia, serviços externos e limites de uso não são confundidos com assinatura ilimitada. Catálogo e assinaturas legadas são preservados; a UI comercial usa os novos planos. Nenhuma renovação real foi implementada neste checkout simulado.

## Autorização e processamento

Migrações `202609270003_commerce_onboarding.sql` e `202609280001_pricing_semiannual.sql`:

- Preços e total fixados no banco; cliente envia plano, identificador idempotente e quantidade de parcelas (1–6 no semestral, somente uma no mensal). O arredondamento fica na última parcela; mudanças de plano ou parcelas exigem novo aceite. Checkout exige dono do workspace e briefing confirmado.
- Estado persistente por empresa, expiração de checkout em 30 minutos, estados terminais sem reconfirmação divergente e auditoria. Um novo checkout cancela os anteriores pendentes.
- Confirmação é RPC exclusiva de `service_role`, com ator autenticado passado pelo servidor e autorização empresarial novamente conferida. RLS impede escrita direta do cliente.
- Liberação de teste separada de `company_subscriptions`: modo `test`, duração de sete dias, sem registrar receita ou assinatura real como ativa. Acesso real existente continua dependente de assinatura ativa e período válido.
- Gate de IA no banco cobre interpretação, pesquisa Instagram com IA, diagnóstico, calendário, imagens, site, propostas de anúncios, contexto de atendimento e geração de prompt. Filas de conteúdo, lançamento, edição visual, descrição de anexos e preparação de anúncios ignoram empresas sem acesso; nenhuma tentativa é consumida. Pausa/compensação de anúncios existentes continua possível.
- Onboarding gratuito usa interpretação determinística. Busca Google Places e conexão de canais não são chamadas de IA. Uploads são salvos, mas suas descrições automáticas aguardam liberação.
- Proxy autenticado inclui rotas exatas de compra, estratégia guiada, Instagram, edição visual e execução de anúncios, mantendo verificação de origem e sessão. Corrigida a ausência dessas rotas anteriores no encaminhamento web.

## Configuração e implantação

`CHECKOUT_MODE=test` habilita as simulações na API. Foi aplicado somente ao `.env` local; `.env.example` documenta a opção. Qualquer outro valor bloqueia novas simulações. Acessos de teste já emitidos expiram em sete dias; para encerrá-los antes, revogue explicitamente suas linhas em `private.company_test_access` por operação administrativa autorizada. Desabilitar novas simulações não converte acessos de teste em assinaturas reais.

Aplicar todas as migrações pendentes antes de iniciar a nova API e os workers, e publicar web/API da mesma revisão. A checagem de plano falha fechada se a migração estiver ausente. O pacote local `.local/askadia-update-2026-09-27.sql` inclui a migração comercial de 27/09 e as cinco anteriores pendentes. A migração incremental `202609280001_pricing_semiannual.sql` deve ser aplicada depois; o pacote anterior não a inclui. Não reaplicar esse pacote se parte dele já tiver sido executada; use o histórico de migrações.

O checkout real exigirá adaptador de pagamento, verificação de webhook assinado, correlação empresa/checkout/valor, conciliação e eventos de inadimplência/cancelamento. O parâmetro de teste do frontend jamais deve ser aceito como comprovante de pagamento real.

## Validação e limites

Testes PostgreSQL locais cobrem negação de IA antes do pagamento, filas retidas, zero consumo de franquia, preço imutável, semestral em até seis parcelas com total exato, isolamento por empresa, papéis, confirmação exclusiva do servidor, idempotência, recusa, cancelamento, expiração e conclusão somente após aprovação. Os cenários anteriores de IA agora declaram explicitamente uma assinatura de fixture paga, sem alterar as regras reais de autorização.

Teste do proxy verifica encaminhamento das rotas e rejeição antes da chamada externa para origem indevida, sessão ausente e operações não listadas. Revisão do navegador usou apenas empresa fictícia e respostas locais: boas-vindas, planos, recusa, confirmação explícita, estratégia, resumo da entrevista e animação. Largura 390 px: cartões empilhados, sem overflow horizontal.

Não foram executados migração remota, deploy, cobrança, mensagens, anúncios ou geração paga nesta etapa. Permanecem os bloqueios de acesso remoto documentados em `trafego-execucao-2026-09-27.md`. O fluxo foi implementado e validado localmente; homologação com Auth, banco e provedores do ambiente publicado permanece pendente.

Resultado de 28/09: `pnpm check` aprovado com 243 testes em 29 arquivos, lint, tipos e builds completos. Ver `docs/progress.md` para os cenários da revisão visual atual.
