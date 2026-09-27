> Atualização posterior de 27/09/2026: criação e execução de anúncios agora implementadas localmente; geração real validada. O estado atual, os limites de formato e os bloqueios de implantação estão em [trafego-execucao-2026-09-27.md](trafego-execucao-2026-09-27.md). As seções abaixo registram a entrega anterior.

# Modelos, edição de imagens e automação de tráfego — 27/09/2026

## Entrega implementada

Modelos resolvidos em tempo de execução em apps/api/src/ai/models.ts, inclusive quando o ambiente é carregado após os imports:

| Função | Modelo configurado |
| --- | --- |
| Estratégia, orquestração, sites, propostas de tráfego | gpt-6-astra |
| Textos de conteúdo e organização de datas | gpt-6-sol |
| Conversa de onboarding, busca de perfis e atendimento | gpt-6-luna |
| Artes e edição de imagens | gpt-image-2.5-sunburst, qualidade high |

A configuração local .env foi atualizada somente nos nomes dos modelos; nenhuma chave foi substituída. .env.example documenta os valores. O atendimento deixou de fixar gpt-4o-mini, resolve OPENAI_MODEL_ATTENDANCE em cada chamada e usa max_completion_tokens. Consultas autenticadas somente de leitura a /v1/models retornaram HTTP 200 para Astra, Sol e Luna. Isso verifica disponibilidade na conta, não qualidade de geração ou acesso do ambiente de produção. Não houve geração paga nesta validação. Após solicitação adicional, a geração/edição de imagens foi migrada para GPT Image 2.5 Sunburst, inclusive carrosséis. O catálogo confirmou HTTP 200 para esse modelo. OPENAI_MODEL_IMAGE e OPENAI_IMAGE_QUALITY foram aplicados no .env local; GEMINI_IMAGE_MODEL deixou de ser usado. A descrição visual dos uploads continua separada.

Meu site → Editar site → Editar fotos com IA: selecionar uma foto, descrever ajustes e escolher formato. A API envia o original como referência ao provedor. O resultado cria outro anexo privado, conserva o original e só entra no rascunho por ação do cliente. Salvar o rascunho não publica. Aplicação de foto respeita limite de oito, evita duplicatas e substitui o original quando já selecionado. Publicação mantém a revisão e autorização existentes.

Tráfego pago → Proposta de investimento: cada campanha ganhou painel de criativos, prévia, download e solicitação de variações. Novas propostas prontas enfileiram uma peça por campanha (máximo oito), preservando plano, índice, perfil e empresa. A geração aguarda as cinco etapas da estratégia aprovadas. O trigger e a solicitação manual usam materiais originais autorizados da empresa; imagens geradas anteriormente não entram automaticamente como fotos documentais. Google recebe peça horizontal, Meta peça vertical, com variações quadradas e Stories disponíveis. Uma peça visual genérica não equivale a um anúncio Google Pesquisa nem a uma campanha ativada.

Fila em company_visual_jobs, migração 202609270001_visual_jobs.sql: RLS, autorização marketing.write revalidada pelo servidor/banco, origem pertencente à empresa, pedido idempotente, lease e token, até três tentativas, limites de pedidos e geração, invalidação após mudança de perfil/aprovação/permissão, storage privado e auditoria. Worker depende de OPENAI_API_KEY, SUPABASE_SERVICE_ROLE_KEY e VISUAL_JOBS_ENABLED diferente de false. Provedor indisponível mantém erro e material original. O adaptador usa /v1/images/generations ou /v1/images/edits com referências reais multipart; solicita PNG, valida a assinatura do arquivo e mantém metadados de uso reportados nos novos jobs. Não troca de provedor silenciosamente. Dimensões: feed 1536×1920, horizontal 2048×1152, quadrado 1792×1792 e Stories 1152×2048. Tempo máximo da chamada: quatro minutos, dentro do lease de cinco; proxy manual ampliado para permitir essa duração. Nenhum resultado é aplicado ou publicado automaticamente.

## Como completar o tráfego automático (ainda pendente)

A autorização do cliente já está definida: aprovar a versão exata, orçamento, público, texto, criativo e programação permite iniciar automaticamente, sem segundo comando. A aprovação genérica da etapa cinco não autoriza gastar com parâmetros ainda desconhecidos.

1. Durante o onboarding, o titular concede OAuth e seleciona a conta de anúncios. Meta requer acesso efetivo de gerenciamento de anúncios e página; Google requer OAuth, developer token, versão de API e acesso à conta. Os segredos ficam no servidor/cofre. No ambiente inspecionado, OAuth e developer token Google ainda estão ausentes. Meta tem configuração de aplicativo, mas isso não comprova permissões concedidas às contas dos clientes ou liberação para operar todos os anunciantes.
2. Implementar o registro versionado da campanha executável: conta, destino, objetivo, público concreto, recursos de texto/imagem, orçamento total, moeda, início/fim e fuso. Exibir todos os parâmetros para aprovação final com ads.approve e limite de investimento autorizado. Mudança de qualquer parâmetro invalida essa aprovação.
3. Criar objetos remotos pausados e persistir cada ID. Meta: campanha, conjunto, criativo e anúncio. Google: orçamento, campanha, grupo, segmentação e anúncios/recursos conforme o tipo. A imagem desta entrega atende a criação de peças visuais; Pesquisa exige seus próprios títulos, descrições e palavras-chave.
4. Worker durável aguarda a programação, revalida aprovação, conta, permissões, teto de investimento e impedimentos de cobrança, e ativa somente a versão aprovada. O retorno da API diferencia programada, em análise, ativa e bloqueada; criação não comprova veiculação. Respostas incertas exigem reconciliação antes de repetir criação, evitando campanhas duplicadas.
5. Falta de saldo explicitamente informada pelo provedor bloqueia a execução e cria uma pendência persistente em destaque no dashboard e em Tráfego, com link para faturamento. Não adicionar crédito automaticamente, aumentar orçamento, trocar conta ou alterar forma de pagamento. Recuperação só dentro da janela e condições aprovadas. Conta ativa e AdAccount.balance não comprovam crédito disponível; dados desconhecidos precisam ser apresentados como desconhecidos. Rejeição de pagamento e restrição de conta são avisos diferentes de saldo insuficiente.
6. Consultar entrega/gasto/resultados com data e cobertura; permitir pausa/cancelamento e reconciliar alterações externas. Otimizações que alterem escopo ou verba voltam para aprovação. Pixel/Conversions API e tags/conversões Google dependem de acesso, objetivo e configuração do site/conta.

Google documenta orçamento total com CUSTOM_PERIOD e total_amount_micros em tipos compatíveis, com início/fim no fuso da conta. Homologar a disponibilidade para o tipo e a conta escolhidos. Não converter silenciosamente o teto total aprovado em um orçamento diário médio: a semântica de gastos difere.

O executor de criação/ativação, a aprovação específica dos anúncios e o aviso persistente de saldo insuficiente **não estão entregues nesta revisão**. As integrações atuais consultam contas/hierarquia e produzem propostas. A consulta Meta existente apresenta restrição ou saldo não confirmado. O envio programado de mensagens continua no executor já existente; nenhum anúncio, post ou mensagem real foi enviado nos testes.

## Validação e implantação

Validação final com OpenAI: pnpm check passou, incluindo lint, tipos, 220 testes em 26 arquivos e builds de API, worker e Next. Os seis novos cenários cobrem isolamento entre empresas, idempotência, origem preservada, publicação não efetuada, mudança do perfil durante geração, enfileiramento/gate da campanha, resolução dinâmica do modelo, envio da imagem original e falhas/quota do provedor. Testes utilizam PostgreSQL local (PGlite), Auth/Storage e provedores controlados.

Prévia isolada nas larguras 1440 e 390: edição solicitada com o original, aplicação/salvamento sem publicação e variação vinculada ao plano/índice corretos; sem erros de página ou transbordamento horizontal. Capturas e relatório em .local/visual-qa (fixtures identificados, não avaliação de qualidade de uma arte real gerada). Consulta real de disponibilidade dos três modelos separada dos testes de geração.

Não houve deploy nem migração remota. Aplicar primeiro as migrações 202609260001–202609260003 e depois 202609270001 em homologação, provisionar os nomes dos modelos no ambiente de destino e reiniciar os processos. Confirmar geração real e revisão do cliente antes de disponibilizar em produção. O .env local não altera as variáveis do Easypanel. A publicação social automática e demais lacunas do blueprint continuam registradas em onboarding-operacao-guiada.md.

## Fontes primárias consultadas

- OpenAI: https://developers.openai.com/api/docs/guides/latest-model
- Gemini, geração e edição: https://ai.google.dev/gemini-api/docs/image-generation
- OAuth e developer token Google: https://developers.google.com/google-ads/api/docs/oauth/overview
- Orçamentos Google: https://developers.google.com/google-ads/api/docs/campaigns/budgets/create-budgets
- SDK oficial Meta, objetos de anúncios: https://github.com/facebook/facebook-php-business-sdk/blob/main/src/FacebookAds/Object/AdAccount.php
