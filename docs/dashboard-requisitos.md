Você é o engenheiro responsável por transformar o dashboard existente da Askadia em uma central de desempenho digital e comercial para cada empresa. Implemente a interface, os contratos, as integrações de leitura, a persistência, os cálculos e os testes necessários. Preserve a identidade visual e a arquitetura existente.
Este trabalho trata somente do dashboard e da infraestrutura necessária para alimentar seus indicadores. Não recrie onboarding, estúdio de design, site institucional, atendimento ou gestão de campanhas. Reutilize esses módulos como fontes e destinos de navegação. O dashboard deve responder: o que está acontecendo no mercado, quais conteúdos funcionam, quanto estamos investindo, quantos clientes conquistamos e qual retorno conseguimos medir.
Leia os arquivos AGENTS.md e inspecione o repositório antes de editar. Identifique a página Visão geral, o módulo Resultados, filtros, gráficos, autenticação, empresas, CRM, conexões, filas e tabelas existentes. Reaproveite componentes e serviços; não crie duas fontes de verdade para as métricas.
Nos prints anteriores, o dashboard tinha indicadores locais, um hero grande e pouca informação operacional. Isso é evidência visual, não comprovação da situação atual do código. Confirme o estado real e registre as lacunas em docs/dashboard-auditoria.md.
Implemente estas áreas:
1. Visão executiva do negócio.
2. Google Trends e 20 palavras-chave prioritárias do segmento.
3. Conteúdos e desempenho do Instagram.
4. Relatório de tráfego Meta Ads e Google Ads.
5. Site e pesquisa orgânica, quando GA4 e Search Console estiverem conectados.
6. Funil CRM até cliente adquirido.
7. Integração com o sistema de gestão da empresa.
8. Receita, CAC, ROAS e ROI de marketing.
9. Diagnóstico da IA, alertas e relatórios exportáveis.
Não use dados fictícios em produção. Sem conexão, mostre a ausência e o caminho para conectar. Dados de demonstração só em ambiente separado e identificado. Conector implementado não significa conector homologado.
Preserve o estilo Askadia: fundo claro, cinzas frios, títulos escuros, cartões brancos, bordas discretas, cantos arredondados, sombras suaves e glassmorphism sutil. Use tokens existentes. A prioridade passa a ser leitura dos indicadores e ação, reduzindo a área do hero promocional para clientes ativos.
Organize um resumo principal com aprofundamento em abas ou seções: Visão geral, Tendências, Instagram, Tráfego, Site, Funil e Retorno financeiro. Se Resultados já existir, use a mesma camada de dados e links de aprofundamento.
Ordem sugerida na Visão geral:
1. Empresa, período, comparação e última atualização.
2. Resumo executivo com seis a oito KPIs selecionáveis.
3. Gráfico de investimento, aquisição e retorno, com unidades claras.
4. Funil até matrícula/primeira compra confirmada.
5. Resumos de Instagram e campanhas.
6. Tendências e palavras-chave.
7. Oportunidades, alertas, pendências e saúde das conexões.
Cards principais: investimento em mídia, leads únicos, novos clientes pagantes, receita atribuída, CAC completo, ROAS e ROI de marketing. Se o denominador, custo ou atribuição estiver ausente, o card deve explicar a pendência em vez de mostrar zero.
Cada card mostra valor, unidade, período, variação, fonte, atualização e acesso à memória de cálculo. Mostre fórmula e bases no detalhamento. O usuário deve conseguir descobrir de onde veio um número sem conhecer APIs.
Layout responsivo, navegação por teclado, contraste adequado, gráficos com legendas e alternativa em tabela. Cores de melhora/piora dependem do indicador: redução de CAC geralmente é favorável; queda de receita geralmente é desfavorável. Não use verde apenas porque a variação é positiva.
Filtros globais: empresa/unidade autorizada, período, comparação e fuso. Filtros por seção: canal, conta, campanha, formato de conteúdo, região pesquisada, oferta e origem do lead, conforme aplicabilidade.
- Atalhos: hoje, ontem, últimos 7/30/90 dias, mês atual, mês anterior e intervalo personalizado.
- Comparar com período anterior de duração equivalente e mesmo período do ano anterior quando existir histórico.
- Exibir datas exatas e marcar período em andamento. Não comparar mês parcial com mês anterior completo sem aviso e opção de ajuste.
- Persistir filtros na URL ou estado compartilhável sem expor tokens. Aplicar os mesmos filtros em cards, gráficos, tabelas e exportações.
- Definir datas no fuso da empresa; armazenar instantes em UTC. Se a API fornecer apenas agregados no fuso da conta, mostrar essa limitação, sem inventar reagrupamento impossível.
- Filtros não aplicáveis a uma seção devem ser indicados. Filtrar campanha não altera artificialmente os dados gerais do Google Trends.
- Ao trocar de empresa, limpar caches e respostas pendentes do contexto anterior.
- Se base anterior for zero, mostrar “sem base para variação percentual”, nunca infinito. Se houver valor zero válido, preservá-lo.
- Cancelar consultas obsoletas e impedir que resposta atrasada sobrescreva o período escolhido depois.
Crie a seção “Tendências e oportunidades de busca”. Use o segmento, serviços, cidade e região confirmados no perfil da empresa. O objetivo é mostrar 20 termos prioritários para acompanhar e transformar em oportunidades de conteúdo e campanhas.
A página oficial consultada em 21/09/2026 informa que a Google Trends API está em acesso alpha mediante solicitação; não presuma acesso público. Ela também distingue a escala consistente da API da normalização 0–100 do site. Confira disponibilidade e contrato na implementação: [Google Trends API](https://developers.google.com/search/apis/trends).
Prioridade de acesso:
1. API oficial, se a conta tiver acesso aprovado.
2. Importação de CSV exportado do Google Trends, com período, região, termos, escala e data de coleta explícitos.
3. Provedor licenciado já contratado e validado, se existir; identificar o fornecedor.
Sem fonte utilizável, mostrar “pesquisa pendente” e sugestões não medidas. Não inventar endpoint, automatizar acesso burlando restrições ou depender de scraping não oficial como solução garantida. Não bloquear os outros módulos pela falta de Trends.
- Gere candidatos a partir dos serviços reais, intenção comercial, localização e termos relacionados disponíveis na fonte.
- Diferencie termo de pesquisa de tópico do Google Trends; registre idioma e tipo de busca quando utilizados.
- Exiba até 20 termos com evidência disponível e complete a lista de trabalho com sugestões claramente separadas se faltarem dados. Nunca chame sugestões de “mais pesquisadas”.
- Título recomendado: “20 palavras-chave prioritárias”. Explique se a ordenação é por interesse observado, crescimento ou prioridade editorial.
- O ranking é dos candidatos pesquisados, não uma prova das 20 maiores buscas de todo o mercado.
- Só ordenar índices de interesse entre termos quando forem comparáveis na mesma escala, contexto, região e período. Não juntar rankings de CSVs normalizados separadamente como se seus números fossem equivalentes.
- Comparações entre lotes importados exigem metodologia validada; se não houver, mostrar lotes separados e não produzir ranking único falso.
- Não interpretar interesse relativo como volume absoluto de buscas. Volume estimado, se integrado por fonte própria como planejamento de palavras-chave, precisa de coluna, fonte e período separados.
- Quando cidade/bairro não tiver cobertura suficiente, oferecer estado ou país e explicitar a mudança de região; não apresentar dado nacional como local.
- Não converter dado insuficiente em zero interesse. Evitar taxas explosivas de crescimento sobre bases mínimas sem sinalização.
- O cliente pode fixar, excluir ou adicionar termos. Termos fixados não ganham posição artificial no ranking medido.
Tabela de termos: posição, termo/tópico, intenção, região efetiva, interesse e escala, variação quando comparável, cobertura de dados, motivo da prioridade, fonte, atualização e ações.
Gráfico de evolução para termos selecionados, respeitando comparabilidade. Permita abrir a pesquisa de origem e gerar briefing no módulo de estratégia. O botão propõe conteúdo ou campanha; não publica nem ativa anúncios.
Use os 20 itens abaixo somente como candidatos iniciais, sem afirmar que são os mais buscados. Adapte ao tipo de empresa e ao que ela oferece:
1. academia perto de mim
2. academia em [cidade]
3. academia em [bairro]
4. academia 24 horas
5. preço de academia
6. plano de academia
7. musculação
8. musculação para iniciantes
9. treino para emagrecer
10. treino para hipertrofia
11. personal trainer
12. treinamento funcional
13. aula experimental de academia
14. academia com aulas coletivas
15. pilates perto de mim
16. estúdio de pilates
17. aula de spinning
18. aula de dança fitness
19. academia com TotalPass
20. academia com Wellhub
Os placeholders devem ser substituídos pela região real antes de pesquisar. Remova termos incompatíveis: não sugerir academia 24 horas, pilates, TotalPass ou Wellhub se a empresa não oferece esses serviços/convênios. Para estúdio, box ou outro segmento, gere outra lista de candidatos.
Conecte contas profissionais autorizadas por integração oficial da Meta. Audite o fluxo de login e permissões já usado, sem misturar contratos de modalidades diferentes. Verifique métricas suportadas na versão vigente; não presuma que todo formato retorna os mesmos campos. Referência: [coleção oficial da Meta para Instagram](https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api).
Resumo desejado, conforme disponibilidade: seguidores, crescimento líquido, alcance, visualizações, visitas ao perfil, cliques, interações e quantidade de conteúdos publicados. Separe métricas do perfil das métricas das publicações.
Lista de conteúdos com miniatura, trecho da legenda, link, data, formato, vínculo com calendário, indicação orgânico/impulsionado quando comprovável e métricas suportadas: curtidas, comentários, salvamentos, compartilhamentos, alcance, visualizações e retenção/tempo de reprodução quando disponível.
Filtros: período, formato, campanha editorial, origem e ordenação por alcance, interações, salvamentos, taxa de engajamento ou leads rastreáveis. Permita abrir cada publicação e comparar conteúdos de contexto e idade semelhantes.
Dois modos temporais obrigatórios:
1. Conteúdos publicados no período: filtra data de publicação; números podem ser acumulados até a última coleta, claramente rotulados.
2. Desempenho ocorrido no período: usa métricas que a fonte realmente fornece para aquele intervalo, mesmo para posts antigos.
Não rotule métricas lifetime como desempenho mensal. Snapshots não tornam alcance único acumulado em alcance único do intervalo por simples subtração. Para contadores em que deltas sejam válidos, registre método, lacunas e correções; sem histórico, declare a indisponibilidade retroativa.
Regras de agregação:
- Alcance único não é somável entre dias/posts/contas para obter pessoas únicas totais. Use agregado oficial quando disponível ou rotule soma de alcances sem deduplicação.
- Taxa de engajamento por alcance = interações consideradas / alcance correspondente × 100. Explicite quais interações entram e preserve o mesmo recorte.
- Se exibir média entre posts, informe que é média de taxas; não confundir com taxa consolidada do perfil.
- Crescimento de seguidores exige bases históricas comparáveis. Não inventar seguidores do período anterior.
- Leads atribuídos a um post exigem vínculo verificável, como UTM ou referência do canal; likes não equivalem a leads.
- Não somar alcance orgânico e pago como audiência única; conteúdo impulsionado exige cuidado com sobreposição.
- Stories e histórico dependem da cobertura real da API/coleta. Não prometer recuperação de tudo antes da conexão.
Ofereça rankings por objetivo e formato, evitando declarar que “o melhor conteúdo” é sempre o com mais curtidas. Mostrar amostra e tempo de exposição antes de recomendar um padrão.
Unifique leitura de Meta Ads e Google Ads em tabelas comparáveis, mantendo as definições originais e a possibilidade de separar plataformas.
Campos: plataforma, conta, campanha, objetivo, status, período, orçamento quando disponível, gasto, impressões, alcance quando suportado, cliques com tipo definido, CTR, CPC, CPM, conversões reportadas, leads identificados no CRM, clientes confirmados no sistema de gestão, receita atribuída, CPL, CAC de mídia, CAC completo quando possível e ROAS.
Fórmulas básicas:
- CTR = cliques do tipo escolhido / impressões × 100.
- CPC = gasto / cliques correspondentes.
- CPM = gasto / impressões × 1.000.
- CPL = gasto / leads únicos atribuídos ao mesmo escopo.
Se mostrar custo por lead reportado pela plataforma, nomeie separadamente do CPL calculado com CRM. Recalcule taxas usando numeradores e denominadores agregados; não faça média simples de CPC/CTR entre campanhas.
Gráficos: investimento por dia e canal; leads/clientes por canal; evolução de custo de aquisição; campanhas com maior gasto e melhor retorno observado. Unidades financeiras e contagens devem ficar claras, sem sobreposição visual enganosa.
Regras:
- Não somar conversões do Meta e Google como vendas únicas. Mantenha “conversões reportadas” e “clientes confirmados” separados.
- Apresente janela, modelo de atribuição e data-base quando esses dados alterarem a interpretação.
- Explicite se o resultado foi reportado por data de interação ou de conversão; preserve a semântica dos provedores.
- Não somar métricas de níveis campanha/grupo/anúncio de forma duplicada.
- Valores com moedas diferentes não se consolidam sem conversão explícita, fonte e data da taxa.
- “Pausada hoje” não apaga gasto histórico no período.
- O dashboard consulta e aprofunda. Alterar campanha ou orçamento abre o módulo próprio e segue as aprovações existentes.
A API de relatórios do Google Ads permite consultar desempenho de campanhas e outros recursos; implemente consultas compatíveis com dimensões e métricas suportadas, sem gerar combinações inválidas. Referência: [Google Ads Reporting](https://developers.google.com/google-ads/api/docs/reporting/overview).
Quando conectados, incluir:
- GA4: usuários, sessões, canais, páginas de entrada, eventos-chave e formulários do site, com suas definições.
- Search Console: consultas e páginas com cliques, impressões, CTR e posição média no Google, para propriedades autorizadas.
- Sites Askadia: formulários efetivamente recebidos e vínculo com o CRM, mesmo quando GA4 estiver ausente.
Não confundir Google Trends, que indica interesse de pesquisa, com Search Console, que mostra desempenho da propriedade. Não afirmar cobertura completa de todas as consultas se a fonte devolver apenas parte dos dados.
GA4 precisa de instrumentação prévia: consultar a API não instala tags ou cria histórico. Clique no botão WhatsApp, envio de formulário, conversa recebida e venda são eventos diferentes.
Conectores opcionais não bloqueiam ROI/CAC quando suas bases necessárias já estão disponíveis por outras fontes. Informações de Perfil da Empresa no Google/Facebook podem aparecer somente se houver integração implementada e autorização real, sem criar indicadores fictícios para preencher espaço.
Referências: [GA4 Data API](https://developers.google.com/analytics/devguides/reporting/data/v1) e [Search Console Search Analytics](https://developers.google.com/webmaster-tools/v1/searchanalytics/query).
Criar um adaptador por fornecedor para importar dados comerciais e financeiros. O fornecedor ainda não foi definido: não presumir API universal, endpoint conhecido ou conector homologado. Inspecione integrações existentes e implemente uma interface extensível.
Fluxo: escolher fornecedor suportado → informar credenciais de forma segura → testar leitura → selecionar empresa/unidade externa → revisar campos e regras → executar carga inicial → ativar sincronização → mostrar cobertura e saúde.
Dados necessários, conforme disponibilizados:
- ID externo de cliente, data de cadastro e identificadores mínimos para correspondência.
- ID de unidade, contrato/matrícula/venda, plano/produto, data, valor e status.
- Primeiro pagamento válido, pagamentos posteriores, vencimentos, valores recebidos, descontos, estornos e reembolsos.
- Cancelamentos e reativações.
- Origem/ID de campanha/lead quando existir no sistema externo.
- Custos, comissões, tributos e dados de margem, se disponíveis e pertinentes ao cálculo.
Regras de engenharia:
- Integração inicialmente de leitura; não cobrar, cancelar contrato ou editar aluno no sistema de gestão por meio do dashboard.
- Credenciais e mapeamento de unidades isolados por empresa, com acesso no servidor.
- Sincronização incremental com paginação/cursor, checkpoints, rate limit, retries, reconciliação e reprocessamento idempotente.
- Webhooks autenticados quando existirem; polling como alternativa suportada. Não depender exclusivamente de eventos para recuperar falhas históricas.
- Chaves únicas por empresa + fornecedor + objeto + ID externo. Estorno recebido depois atualiza o resultado sem criar uma segunda venda.
- Guardar origem, período coberto, última atualização e erros, sem expor payloads com dados pessoais no dashboard.
- Importação CSV assistida e auditada pode ser alternativa temporária; sua origem deve continuar identificada.
- Se a API não fornecer custos/margens, permitir lançamentos manuais e estimativas declaradas, sujeitos às permissões e versões.
- Não importar informações clínicas, fichas de treino ou dados sem finalidade para este dashboard.
Defina interfaces equivalentes a testConnection, listBusinessUnits, syncCustomers, syncSales, syncPayments, syncRefunds e getSyncStatus, adaptando às capacidades reais do fornecedor. Operação não suportada deve ser declarada, não simulada.
Relacione mídia → visita/formulário/conversa → contato → oportunidade → matrícula/primeira compra → pagamento, quando houver evidência. Use IDs externos, referência de lead, UTMs e identificadores de clique permitidos; e-mail/telefone normalizados podem ajudar na correspondência dentro da empresa. Nome isolado não é suficiente.
Crie fila para correspondências ambíguas, com revisão autorizada e trilha de auditoria. Defina uma fonte de verdade para cada fato: o CRM organiza relacionamento; o sistema de gestão confirma contratos e pagamentos; plataformas de anúncio reportam suas próprias conversões.
- Modelo de atribuição inicial documentado e versionado, por exemplo último toque não direto observado antes da aquisição dentro da janela configurada.
- Origem inicial pode coexistir com atribuição do último toque. São campos e leituras diferentes.
- Não atribuir vendas automaticamente ao canal com maior gasto.
- Receita e clientes sem evidência permanecem “origem não identificada”.
- Mostrar cobertura: clientes com origem / novos clientes elegíveis; receita atribuída / receita elegível. Baixa cobertura limita conclusões.
- Evitar contagem dupla de cliente, venda e pagamento em múltiplos canais. Se adotar atribuição fracionada no futuro, pesos por evento devem totalizar 1 e ficar visíveis.
- Atribuição observada não comprova impacto incremental causado pelo marketing. Não chamar toda receita atribuída de receita adicional gerada.
- Importar histórico suficiente ou saldo de “cliente preexistente” para não contar aluno antigo como novo só porque apareceu na primeira sincronização.
- Cancelamento posterior não deve reescrever silenciosamente a data histórica de aquisição; reflita estornos e retenção segundo regra documentada.
Padrão inicial sugerido: “novo cliente pagante” é a primeira aquisição com primeiro pagamento válido confirmado. Renovações e reativações ficam em grupos próprios. Compra repetida não aumenta o denominador do CAC.
Implemente cálculos determinísticos no backend, com testes e memória de cálculo. A IA apenas interpreta os números. Separe custo de mídia, custo completo de aquisição, receita e margem.
Permita escolher regime: caixa realizado (recebido) ou competência reconhecida, quando os dados suportarem. O padrão pode ser caixa realizado, explicitamente rotulado. Nunca misture contratos futuros, recebimentos e receita reconhecida no mesmo indicador.
Receita líquida deve ter regra explícita: receita elegível menos descontos ainda não abatidos, estornos/devoluções e deduções definidas. Não descontar duas vezes um valor já líquido. Tributos e taxas entram uma única vez, com classificação visível.
Custo completo de aquisição pode incluir mídia, parcela de ferramentas/Askadia destinada à aquisição, acompanhamento/agência, produção, comissões de aquisição e equipe comercial/marketing alocada. Registrar item, valor, período, origem, empresa, campanha quando aplicável e critério de rateio. Não ratear todo salário ou assinatura por campanha sem regra.
Se uma comissão já entrou como custo de aquisição, não repeti-la como custo variável na margem. Custos desconhecidos não podem ser tratados silenciosamente como zero.
ROAS observado = receita atribuída à mídia / investimento em mídia
Mostrar como múltiplo, por exemplo 3,2x. Informar se receita é bruta/líquida, caixa/competência, período, coorte e modelo de atribuição. Se o número vier direto da plataforma, exibir “ROAS reportado pela plataforma”, separado do conciliado com o sistema de gestão.
CAC completo = custos de aquisição de marketing e vendas / novos clientes adquiridos
CAC de mídia = investimento em mídia / novos clientes atribuídos à mídia
CAC não é gasto dividido por leads; isso é CPL. Se só houver gasto com anúncios, não chamar o resultado de CAC completo. O escopo de custo e clientes deve corresponder: não dividir gasto de uma campanha por todas as matrículas da academia.
Definição do produto:
Margem de contribuição atribuída = receita líquida atribuída − custos variáveis de entrega dessa receita
ROI de marketing observado (%) = (margem de contribuição atribuída − custos de aquisição correspondentes) / custos de aquisição correspondentes × 100
Rotular como ROI de marketing, com regime e janela; não apresentar como ROI contábil de toda a empresa nem retorno causal comprovado. Mostrar custos incluídos e excluídos. O conceito geral de ROI exige custos, não apenas receita: [orientação do Google Ads sobre ROI](https://support.google.com/google-ads/answer/1722066?hl=pt-BR). A fórmula acima é a definição operacional específica da Askadia.
Se faltar custo variável/margem, o ROI deve aparecer indisponível ou estimado com premissas informadas. Ter API de gestão conectada não garante dados suficientes para ROI. Não substituir por (receita − mídia) / mídia e chamar de ROI completo.
Oferecer duas leituras sem misturá-las:
- Operacional do período: custos e novos clientes do intervalo selecionado. Avisar que o ciclo de venda pode atravessar meses; é uma leitura de gestão, não pareamento perfeito de cada gasto com cada venda.
- Por coorte de aquisição: selecionar clientes adquiridos em determinado período e acompanhar receita/margem acumulada em janela de observação explícita, com custo de aquisição daquela coorte documentado.
Não usar receita de todos os alunos antigos para inflar ROI dos anúncios atuais. Renovações de uma coorte podem compor seu retorno acumulado quando a regra permitir, sem virar novas aquisições. Coortes recentes devem mostrar maturidade e não ser comparadas a coortes antigas sem janela equivalente.
Para CAC de canal/coorte, só calcular quando os custos puderem ser alocados de forma defensável; caso contrário, limitar a visão ao período ou sinalizar estimativa. Nunca “descobrir” alocação precisa por IA.
Dados exclusivamente de teste, no mesmo escopo e janela:
- Mídia: R$ 3.000.
- Outros custos de aquisição: R$ 1.000.
- Novos clientes pagantes, todos atribuídos à mídia neste exemplo: 20.
- Receita líquida atribuída: R$ 10.000.
- Custos variáveis de entrega, sem duplicação dos custos de aquisição: R$ 3.000.
Resultados esperados:
- CAC de mídia: R$ 150.
- CAC completo: R$ 200.
- ROAS sobre receita líquida atribuída: aproximadamente 3,33x.
- Margem de contribuição atribuída: R$ 7.000.
- ROI de marketing observado: 75%.
Zero clientes ou custo denominador zero gera indicador sem base, nunca infinito. Ausência de dados é diferente de valor confirmado igual a zero. Usar inteiros em centavos/decimais adequados e arredondar apenas na apresentação.
Exibir leads, qualificados, encaminhados, visitas agendadas, comparecimentos e novos clientes pagantes. Mostrar quantidade, taxa, tempo médio/mediano quando houver amostra e origem dos dados.
Distinguir funil de coorte de leads de movimentos no período. Não dividir visitas agendadas neste mês por leads que entraram neste mês se forem populações diferentes e chamar isso de taxa de conversão da coorte.
Oferecer detalhamento autorizado até campanha, oportunidade e registro conciliado. Sem permissão financeira, ocultar receitas individuais e permitir apenas agregados autorizados. Inadimplência, cancelamento e reativação podem aparecer como contexto para retorno/retenção quando importados, sem transformar o dashboard em um sistema de gestão completo.
Reutilize o serviço OpenAI da Askadia, se já estiver configurado; caso contrário, implemente o contrato e sinalize a configuração pendente, sem simular análises reais. A análise recebe um snapshot dos indicadores calculados, fontes, filtros, atualização, cobertura e premissas. Não envie desnecessariamente dados pessoais de todos os alunos.
Gerar resumo curto com:
- O que melhorou e piorou.
- Conteúdos e termos com oportunidade observada.
- Campanhas que precisam de revisão.
- Gargalos entre lead, atendimento, visita e matrícula.
- Limitações que impedem conclusão.
- Próximas ações com evidência e destino no sistema.
Não fazer cálculo financeiro com texto livre do modelo; usar os números do backend. Não afirmar causalidade por correlação, recomendar pausa só por campanha recente sem maturidade ou comparar resultados incompatíveis.
“Criar briefing”, “Revisar campanha” e “Abrir leads sem atendimento” encaminham ao módulo correspondente. Qualquer publicação ou alteração de verba continua sujeita às aprovações já existentes. Abertura do dashboard não deve gerar nova chamada paga de IA toda vez; cache por snapshot e atualização explícita/controlada.
Reaproveite a infraestrutura existente. Proponha contratos como TrendsProvider, SocialMetricsProvider, AdsReportingProvider, WebAnalyticsProvider e ManagementSystemProvider. Cada adaptador declara capacidades, período disponível, credenciais e limites.
Mantenha um dicionário de métricas: nome interno, origem, definição, unidade, granularidade, temporalidade (intervalo/acumulado/snapshot), agregação permitida, cobertura e versão.
Persistir ou adaptar:
- Séries de métricas por empresa, conta, recurso, data e dimensões.
- Publicações e snapshots compatíveis com a fonte.
- Consultas de Trends, candidatos, região, escala, lote e origem da pesquisa.
- Clientes/vendas/pagamentos externos e correspondências com CRM.
- Custos adicionais, rateios, premissas e versões da regra financeira.
- Atribuições, coortes, cobertura e fatos não conciliados.
- Execuções de sincronização, checkpoints, erros e relatórios gerados.
Definir chaves únicas que incluam as dimensões necessárias. Não duplicar métricas ao reprocessar nem somar uma nova coleta cumulativa ao valor já salvo. Permitir correções retroativas e reconciliação de eventos tardios.
Workers sincronizam em intervalos configuráveis conforme quota e prioridade. Dashboard lê dados persistidos e cacheados; botão Atualizar agenda sincronização com limite de frequência. Exibir atualização por fonte, não um único selo de “atualizado” quando apenas um provedor terminou.
Relatórios financeiros devem reter versão da metodologia e snapshot/referências que permitam reproduzir o número após correções.
Respeitar os cinco perfis existentes: administrativo geral, acompanhamento, proprietário, gerente de marketing e atendente.
- Proprietário acessa indicadores das próprias empresas e configuração de custos.
- Gerente acessa métricas digitais; dados financeiros detalhados e configuração de margem dependem de permissão específica.
- Acompanhamento vê empresas atribuídas e apenas dados autorizados para a revisão.
- Atendente vê indicadores operacionais de sua atuação; não recebe acesso financeiro por padrão.
- Administrativo acessa por fluxo interno auditado, sem exposição de segredos.
Validar empresa/permissões em toda API, exportação, cache e job. Tokens ficam no servidor, criptografados conforme infraestrutura. Um filtro de URL não é autorização. Revogar integração impede novas sincronizações e sinaliza histórico desatualizado.
Exportações financeiras e individuais precisam de autorização e logs. Minimize dados pessoais importados, respeite políticas de retenção e registre origem de importações manuais.
Ofereça CSV das tabelas e PDF executivo que reflitam os filtros. Exportações incluem empresa, intervalo, data de geração, fontes, cobertura, regime financeiro, modelo de atribuição, fórmulas e premissas relevantes.
Estados por indicador: disponível, parcial, estimado, sem histórico, sem base de cálculo, desatualizado, integração desconectada e não suportado. Uma falha no Instagram não deve esconder receita já conciliada.
Não armazenar PDFs públicos com dados privados. Relatório compartilhado somente por fluxo autorizado. O dashboard pode gerar um relatório para revisão semanal, mas não enviar mensagens externas automaticamente como parte desta tarefa.
Ordem de execução:
1. Auditar dashboard/fontes atuais e definir dicionário de métricas.
2. Implementar layout, filtros compartilhados e contratos de dados reais.
3. Integrar Instagram e relatórios Meta/Google Ads.
4. Implementar Trends com capacidade oficial/importação e lista de 20 termos.
5. Integrar GA4/Search Console e formulários quando disponíveis.
6. Criar adaptador do sistema de gestão, sincronização e conciliação com CRM.
7. Implementar custos, atribuição e cálculos de CAC/ROAS/ROI.
8. Adicionar diagnóstico, relatórios, estados de qualidade e homologação.
Se o fornecedor de gestão ou acesso ao Trends faltar, implemente interfaces, configuração, fallback de importação, testes e estados honestos, e prossiga nas outras fontes. Não marque esses conectores como homologados.
Testes obrigatórios:
- Troca de empresa/período sem vazamento ou resposta atrasada.
- Filtros iguais em gráfico, card, tabela e exportação.
- Comparações com período parcial, zero e ausência de base.
- Separação entre data de publicação, métricas lifetime e atividade no intervalo.
- Alcance único não somado indevidamente; CTR/CPC recalculados pelos agregados.
- Índices Trends de escalas diferentes não geram ranking conjunto falso; dados nacionais não se passam por locais.
- Lista de 20 candidatos respeita serviços da empresa e distingue pesquisa de sugestão.
- Webhooks/importações repetidos não duplicam vendas ou pagamentos.
- Clientes preexistentes, renovações e reativações não viram novos clientes automaticamente.
- Venda reportada por duas plataformas continua sendo um cliente confirmado no sistema de gestão.
- Estorno tardio recalcula receita e retorno de forma rastreável.
- Cálculos reproduzem o exemplo numérico de 75% e tratam dados/custos ausentes.
- Receita de alunos antigos não entra no retorno de uma nova coorte sem regra explícita.
- Taxa do funil usa população compatível e atribuição incompleta fica visível.
- Permissões financeiras, exportações e tokens protegidos no servidor.
- Interface utilizável no celular e por teclado, com textos e gráficos legíveis.
Entregar código integrado, migrações necessárias, testes e documentação em docs/dashboard-auditoria.md, docs/dashboard-metricas.md e docs/dashboard-integracoes.md. Documentar quais APIs foram homologadas, cobertura histórica disponível e qual informação ainda falta do sistema de gestão.
Comece pela auditoria e siga com implementação. O resultado precisa ser um dashboard conectado a fatos verificáveis, capaz de relacionar presença digital, investimento e aquisição real de clientes, preservando os limites de cada fonte.