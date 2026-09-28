# Onboarding e pesquisa de concorrentes — 28/09/2026

## Fluxo entregue

1. A conversa pede primeiro o nome do negócio e depois a cidade/estado. Respostas que já contenham ambos continuam aceitas. A busca do Google começa automaticamente antes de perguntar o tipo do negócio.
2. O Google Places retorna opções reais com endereço, tipo, telefone, site, horários, nota, quantidade de avaliações, situação do estabelecimento, link e atribuições, conforme disponibilidade. O cliente confirma qual é sua academia e os dados comerciais. Endereço, tipo, horários e canais preenchem campos ainda vazios; respostas existentes permanecem. Local não encontrado/provedor indisponível permite cadastro manual.
3. Após confirmar o local e o tipo, começa a pesquisa de concorrentes. O backend exclui a própria unidade, duplicatas, locais permanentemente fechados e resultados fora do raio. Outra unidade da mesma marca não é removida apenas por ter o mesmo nome. Sem local confirmado no Google, a busca por cidade é identificada como sem raio verificado.
4. Até dez concorrentes confirmados ficam vinculados à empresa, com Place ID, nome conferido, cidade e responsável. A seleção é atômica, versionada e idempotente; revisão antiga não sobrescreve respostas novas.
5. A pesquisa no Instagram fica em **Estratégia → Concorrentes e análise**. Uma fila persistente busca cada nome + cidade separadamente, após perfil confirmado e plano habilitado. Não há IA durante o onboarding gratuito. Fechar a aba não cancela a fila. Falhas têm até três tentativas, controle de consumo e retomada manual.
6. Resultados do Instagram são candidatos com URL efetivamente encontrada e evidência de correspondência. O cliente confirma a identidade antes de acompanhar. Também pode informar um @ conhecido. Não se presume que nomes parecidos são a mesma empresa.
7. Perfis confirmados usam o monitor Meta existente. Dados públicos coletados e seleção local entram numa cópia versionada da análise aprovada, usada pelo diagnóstico/estratégia. Alterar o perfil confirmado invalida a aprovação anterior. Dados ausentes exigem limitação explícita, nunca viram métricas zero.

## Persistência e fontes

Migração incremental: supabase/migrations/202609280002_onboarding_research.sql. Aplicar depois das migrações anteriores e antes de implantar esta versão da API/web.

A tabela company_competitor_research tem RLS por empresa, sem escrita direta pelo navegador. As funções de execução da fila são exclusivas do serviço. Confirmações exigem marketing.write no servidor e no banco. Mudança de cidade/local invalida a pesquisa anterior e remove vínculos locais, preservando os dados já versionados da estratégia anterior.

Dados próprios confirmados pelo cliente ficam no perfil comercial; nomes declarados/confirmados dos concorrentes e Place IDs ficam na seleção. Respostas brutas do Google, notas, contagens de avaliações e horários de concorrentes não são arquivados como uma cópia permanente do Places. A ficha do Google é exibida na consulta ao vivo e mantém link/atribuição. Fotos, textos de avaliações e e-mails não são coletados neste incremento. O fato de uma informação ser pública não significa que a API a disponibilize ou permita seu armazenamento irrestrito.

Referências oficiais conferidas: [Place Details](https://developers.google.com/maps/documentation/places/web-service/place-details), [Text Search](https://developers.google.com/maps/documentation/places/web-service/text-search), [políticas e exceção para Place IDs](https://developers.google.com/maps/documentation/places/web-service/policies).

## Configuração e limites

- Google: GOOGLE_PLACES_SERVER_KEY na API, Places API (New) habilitada, faturamento/quota disponíveis. Máscara explícita inclui campos comerciais; evitar wildcard. Campos detalhados podem ter SKU diferente da busca anterior.
- Busca Instagram: OPENAI_API_KEY e SUPABASE_SERVICE_ROLE_KEY; CONTENT_AUTOPREP_ENABLED não pode ser false. Usa o adaptador de busca existente e a franquia de interpretation.
- Métricas Instagram: INSTAGRAM_MONITOR_ENABLED=true, conexão autorizada com Página/Instagram profissional, permissões Meta e cofre configurados. Descobrir um perfil público não comprova acesso a métricas pela API. Coleta existente aproximadamente horária; não é tempo real.
- Estratégia e animações mantêm a jornada compacta em 100dvh. A pesquisa não cria uma página externa longa; análises extensas usam o painel interno. O CSS de tela cheia/animações não foi removido.

## Validação

Testes locais cobrem sequência nome/cidade, busca sem IA, campos ausentes, URLs inseguras, distância, deduplicação, unidade própria, seleção atômica/replay, isolamento, bloqueio antes do pagamento, perfil confirmado, fila durável, resultado atrasado, confirmação do Instagram, evidências fornecidas à estratégia e invalidação de aprovações.

A validação completa, a consulta real e os limites de homologação estão registrados na entrada correspondente de docs/progress.md. Nenhuma mensagem, anúncio ou cobrança real foi executada nesta alteração.
