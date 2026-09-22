Requisitos do sistema de marketing fitness com IA

Especificação funcional e técnica para desenvolvimento

Responsável pelo produto  Iuri
Versão 1.0  •  21 de setembro de 2026

O sistema deve permitir que uma empresa planeje, produza, aprove e execute seu marketing em uma plataforma única. A operação reúne estratégia por IA, conteúdo, site, anúncios e CRM. Um plano superior acrescenta atendimento e triagem de leads pelo WhatsApp e Instagram.

Este documento define o comportamento esperado para orientar o desenvolvimento, a validação e o lançamento. A presença de um requisito aqui não significa que a funcionalidade já esteja implementada.

Escopo comercial definido

Oferta

Preço mensal

Definição

Marketing básico

R$ 497 por empresa

Marketing automatizado com aprovação do cliente

Marketing com atendimento

A definir

Acrescenta agente de triagem e chat integrado

Acompanhamento semanal

Adicional de R$ 1.000

Participação do cliente junto à equipe


O lançamento atende o segmento fitness. A especialização inicial em academias e estúdios é a proposta de implementação; a estrutura deve permitir outros segmentos e métodos no futuro.

Como ler este documento

As decisões explicitamente combinadas aparecem como escopo definido. Detalhes novos de implementação são propostas de especificação e devem ser validados no piloto. Preço do plano superior, franquias e regras comerciais ainda abertas estão reunidos no final.

O conteúdo segue a jornada do cliente: empresas e cobrança; acessos; onboarding; pesquisa; agentes; produção; publicação; site e domínio; CRM; atendimento; anúncios; resultados; integrações; segurança; implantação.


Requisitos do produto  |  

1 Área de trabalho e cobrança por empresa

A área de trabalho reúne empresas e usuários. A empresa é a unidade de contratação e de isolamento operacional. Um usuário pode ter acesso a mais de uma área de trabalho, sempre conforme suas permissões.

Requisitos de organização

EMP 01 Permitir criar, editar, selecionar e arquivar empresas. Criar o cadastro gera um rascunho; a assinatura só começa após a contratação ser confirmada.

EMP 02 Manter para cada empresa sua identidade, onboarding, arquivos, CRM, conversas, site, domínio, campanhas, integrações, estratégia e histórico de IA.

EMP 03 Exibir a empresa ativa de forma clara em todas as telas e ações. A troca deve atualizar dados e permissões sem reaproveitar informações de outra empresa.

EMP 04 Permitir que empresas da mesma área tenham planos, adicionais e responsáveis diferentes. Uma visão consolidada deve respeitar a autorização de acesso a cada empresa.

Requisitos de assinatura

FIN 01 Cobrar R$ 497 mensais por empresa no básico. Manter preço e franquias do plano superior configuráveis até sua definição.

FIN 02 Oferecer acompanhamento semanal como adicional de R$ 1.000. A contratação por empresa é a proposta adotada nesta especificação.

FIN 03 Mostrar plano, valor, vencimento, situação, histórico de cobranças, adicionais e consumo. Recursos pagos devem ser validados no servidor.

FIN 04 Alterar, cancelar ou suspender somente a assinatura correspondente. Receber eventos de pagamento sem duplicar cobrança ou ativação; reconciliar divergências.

FIN 05 Separar mensalidade, verba de anúncios e possíveis custos variáveis. Não iniciar gasto adicional sem apresentar a regra ao cliente.

Exemplo de contratação

Total mensal

Duas empresas no plano básico

R$ 994

Duas empresas no básico com acompanhamento em uma

R$ 1.994


Critério de aceite

Duas empresas podem operar com planos independentes. Cancelar ou alterar uma delas não modifica o acesso, os dados nem a assinatura da outra. A política de retenção após cancelamento ainda será definida.


Requisitos do produto  |  

2 Usuários permissões e experiência de uso

O sistema deve separar administração da área de trabalho, acesso aos dados da empresa, aprovação e atendimento. Ser responsável pelo pagamento não precisa conceder acesso às conversas comerciais.

Perfil proposto

Permissões principais

Proprietário da área

Gerenciar empresas, membros e contratação

Administrador da empresa

Configurações e equipe da empresa autorizada

Aprovador

Aprovar conteúdos e campanhas no limite concedido

Atendente

Organizar leads, tarefas e conversas permitidas

Leitor

Consultar informações e relatórios autorizados

Equipe de acompanhamento

Revisar empresas explicitamente vinculadas

Operação da plataforma

Suporte e administração com acesso auditado


Acesso e responsabilidade

ACE 01 Implementar login, recuperação de acesso, convites com validade, aceite de convite e remoção de membros. Registrar quem alterou permissões.

ACE 02 Conferir permissões na API, nos arquivos e nas atualizações em tempo real. Ocultar um botão não é suficiente para impedir uma ação.

ACE 03 Acesso da equipe de acompanhamento deve ser concedido por empresa. Delegação de aprovação exige autorização explícita e revogável.

Interface do cliente

UX 01 Interface em português, responsiva e utilizável no celular para aprovar conteúdos, enviar vídeos e atender leads.

UX 02 Menu com visão geral, estratégia, calendário, conteúdos, site, campanhas, CRM, atendimento, resultados, acompanhamento e configurações, conforme plano e permissões.

UX 03 Mostrar estados vazios, carregamento, erro, processamento e sucesso real. Integração desconectada deve mostrar como reconectar.

UX 04 Central de pendências com aprovações, gravações, falhas de publicação, leads sem responsável e decisões da semana. Alertas devem ter prioridade e evitar repetição.

Critério de aceite

Um atendente não altera cobrança ou orçamento sem permissão. Um membro removido perde acesso efetivo. A interface mantém navegação, contraste, foco de teclado e leitura adequados.


Requisitos do produto  |  

3 Onboarding inteligente da empresa

O cadastro conduz a um questionário adaptativo. A IA deve usar um conjunto mínimo de informações por segmento, aproveitar respostas existentes e aprofundar somente as lacunas relevantes.

Bloco

Informações a coletar

Empresa e região

Nome, tipo de negócio, endereço, região atendida, horários e unidades

Oferta

Planos, modalidades, serviços, preços, condições e validade das ofertas

Público e posicionamento

Perfil de cliente, necessidades, objeções e diferenciais reais

Operação comercial

Responsáveis, canais, processo de venda, capacidade e horários ociosos

Objetivos e recursos

Metas, orçamento de mídia, histórico e recursos disponíveis

Marca e presença

Logo, cores, fontes, fotos, site, redes e referências

Produção de vídeos

Disponibilidade, responsável, frequência possível e acervo existente


Comportamento obrigatório

ONB 01 Permitir salvar e retomar o questionário. Aceitar “não sei” e explicar quais informações precisam de confirmação, sem bloquear por detalhes não essenciais.

ONB 02 Perguntar se o cliente pode gravar vídeos ou prefere somente estáticos. A capacidade informada deve limitar o calendário proposto.

ONB 03 Receber fotos da empresa, produtos, equipe e instalações. Organizar arquivos por finalidade, preservando originais e registrando a autorização de uso informada.

ONB 04 Permitir informar o site e sugerir dados extraídos. Esses dados devem ser confirmados pelo cliente antes de virar fonte de preços, ofertas ou promessas.

ONB 05 Apresentar um resumo editável para confirmação. Registrar versão, responsável e data da confirmação.

ONB 06 Permitir atualizar o perfil e solicitar uma checagem mensal curta de novidades, preços, eventos, capacidade e disponibilidade de gravação.

Critério de aceite

Uma academia com capacidade ociosa pela manhã e sem disponibilidade para gravar recebe um diagnóstico compatível. A IA não repete perguntas já respondidas nem inventa dados ausentes.


Requisitos do produto  |  

4 Conhecimento da empresa e pesquisa de mercado

Os agentes compartilham uma base de conhecimento por empresa. Dados comerciais confirmados prevalecem sobre suposições e referências externas.

Base de conhecimento

CON 01 Armazenar fatos confirmados, ofertas, regras da marca, documentos, dúvidas frequentes, estratégias, peças aprovadas e resultados.

CON 02 Registrar origem, data, validade e responsável. Ao alterar um preço ou oferta, identificar conteúdos e campanhas que podem precisar de revisão.

CON 03 Manter memória de decisões e correções do cliente. Recuperar somente contexto relevante da empresa atual, sem misturar dados de outros clientes.

Pesquisa de concorrentes

PES 01 Descobrir concorrentes locais usando atividade e localização; identificar também concorrentes de público semelhante e marcas de referência.

PES 02 Permitir adicionar, remover e corrigir concorrentes. Explicar por que cada empresa foi selecionada.

PES 03 Analisar posicionamento, ofertas públicas, diferenciais, temas de conteúdo e presença digital disponível. Dados de redes sociais dependem de acesso permitido e cobertura da fonte.

PES 04 Associar conclusões às fontes e à data da observação. Distinguir fato observado, hipótese e dado indisponível.

PES 05 Não apresentar faturamento, retorno de anúncio, conversões ou investimento privado de concorrentes como se fossem dados conhecidos.

PES 06 Atualizar a pesquisa no planejamento mensal e por solicitação, com limites de consumo e registro de falhas parciais. Respeitar as regras de armazenamento e atribuição das fontes.

Saída esperada

O diagnóstico deve reunir oportunidades, ameaças, diferenciais a explorar e perguntas em aberto. A pesquisa alimenta o estrategista, mas não autoriza copiar materiais de concorrentes ou publicar afirmações não confirmadas.

Critério de aceite

O cliente consegue verificar a origem das principais conclusões e corrigir a seleção de concorrentes. Se uma fonte estiver indisponível, o relatório continua com essa limitação visível.


Requisitos do produto  |  

5 Método e responsabilidades dos agentes

Os agentes devem seguir um método versionado. Cada execução recebe entradas definidas, produz uma saída verificável e possui limite de custo, prazo e tentativas.

Etapa do método

Entrega obrigatória

Diagnosticar

Situação atual, lacunas e gargalo comercial

Priorizar

Objetivo, público e oferta prioritária

Planejar

Campanhas, canais, orçamento e hipóteses

Produzir

Peças, textos, roteiros e páginas coerentes

Validar

Checagem de fatos, marca, qualidade e autorização

Executar

Publicações e ações aprovadas

Aprender

Resultados e propostas para o próximo ciclo


Divisão de responsabilidade

IA 01 Onboarding coleta e valida o perfil; pesquisador reúne evidências; estrategista define prioridades e calendário.

IA 02 Redator cria textos, legendas e roteiros; designer produz peças a partir da identidade e dos arquivos aprovados.

IA 03 Agente de tráfego propõe campanhas e ajustes; analista consolida resultados; revisor verifica critérios antes da aprovação.

IA 04 Agente de atendimento atua no plano superior, usando fatos comerciais confirmados para responder e qualificar leads.

IA 05 O orquestrador controla dependências, estados, tentativas, aprovações e retomada de tarefas. Essa responsabilidade deve ser implementada em código.

IA 06 Registrar empresa, método, modelo, fontes, custo, duração e resultado. Recusas, saídas inválidas e dados insuficientes devem gerar estados recuperáveis.

Os papéis não exigem modelos ou servidores separados. O aprendizado inicial ocorre por memória, avaliações e revisão dos métodos; treinamento de um modelo próprio não faz parte do escopo inicial.

Critério de aceite

Uma resposta da IA não publica conteúdo nem altera orçamento diretamente. Todas as ações passam por validação, autorização e regras do backend.


Requisitos do produto  |  

6 Estratégia mensal e calendário editorial

O estrategista deve combinar perfil confirmado, capacidade operacional, pesquisa, resultados anteriores e decisões do cliente. No primeiro ciclo, deve explicitar a falta de histórico e as hipóteses que serão testadas.

Planejamento

EST 01 Gerar automaticamente um planejamento a cada ciclo mensal, no fuso da empresa, e permitir acionamento manual para revisão.

EST 02 Definir objetivo comercial, público, oferta, canais, temas, frequência, verba proposta e indicadores de sucesso. Considerar sazonalidade relevante e capacidade real de atender.

EST 03 Cada campanha deve ter hipótese, destino do lead, duração, responsáveis e critério de revisão. Relacionar as peças do calendário à campanha ou ao objetivo.

EST 04 Criar nova versão ao refazer o mês. Exibir diferenças e impactos sobre tarefas, agendamentos e campanhas em andamento antes de substituir itens aprovados.

Calendário e tarefas

CAL 01 Exibir mês, semana e lista, com canal, formato, data, horário, objetivo, responsável e status de cada conteúdo.

CAL 02 Permitir criar conteúdos pontuais, mover datas, editar briefings, comentar, cancelar e duplicar como novo rascunho.

CAL 03 Gerar tarefas de gravação com roteiro, instruções, responsável e prazo. Se não houver capacidade de gravação, priorizar formatos estáticos.

CAL 04 Avisar sobre materiais atrasados, aprovações pendentes e falhas. Oferecer alternativa estática para gravação atrasada, sujeita às regras de aprovação.

CAL 05 Atualizar métricas diariamente quando disponíveis; propor ajustes semanais e consolidar a estratégia mensal. Falta de amostra deve impedir conclusões fortes.

Estados de produção

Rascunho, aguardando material, em produção, em revisão, alterações solicitadas, aprovado, agendado, publicado, falha e cancelado. A transição registra data e responsável.

Critério de aceite

Refazer a estratégia preserva o histórico e não substitui silenciosamente conteúdos já aprovados. O calendário não solicita mais vídeos do que a capacidade informada sem sinalizar a divergência.


Requisitos do produto  |  

7 Artes roteiros e arquivos de vídeo

A produção precisa manter a identidade e a fidelidade dos materiais reais. Imagens geradas podem compor cenários e conceitos, enquanto preços, textos e logos devem permanecer controláveis e revisáveis.

Design e textos

DES 01 Manter kit de marca por empresa com logo, cores, fontes, tom de voz, referências aprovadas e restrições de uso.

DES 02 Criar peças do calendário e demandas pontuais. Produzir variações para feed, stories e outros formatos efetivamente suportados.

DES 03 Preservar os arquivos originais e usar layouts editáveis para textos, preços e logos. Evitar deformação de produtos, rostos e instalações reais.

DES 04 Permitir revisão de texto, imagem, composição e formato. Manter versões e motivo da alteração; verificar legibilidade, cortes e dados comerciais.

DES 05 Gerar legenda, chamada para ação e texto alternativo quando aplicável. Exportar peças e textos para uso autorizado fora da plataforma.

Vídeos enviados pelo cliente

VID 01 Entregar objetivo, público, roteiro, falas, sequência de cenas, duração sugerida e orientações de enquadramento, luz e áudio.

VID 02 Orientar a edição pelo cliente: cortes sugeridos, textos na tela, ritmo e encerramento. A plataforma não executa edição automática na primeira versão.

VID 03 Receber o arquivo final por celular ou computador, com progresso de envio, validação técnica, prévia e indicação de correções necessárias.

VID 04 Vincular vídeo, capa e legenda ao item do calendário. O upload não significa autorização para publicar.

VID 05 Controlar consumo de armazenamento e duração/tamanho aceitos conforme franquias futuras. Informar limites antes de uploads que não possam ser processados.

Critério de aceite

Uma peça pode ser corrigida sem perder o original. Um vídeo final enviado pelo cliente só segue para programação depois da revisão e aprovação correspondentes.


Requisitos do produto  |  

8 Aprovação programação e publicação

O cliente participa das aprovações. O acompanhamento semanal não transfere automaticamente à equipe o direito de aprovar conteúdos ou autorizar verba.

Ação

Regra inicial

Pesquisar e produzir rascunho

Automático dentro dos limites de consumo

Aprovar estratégia e peça

Cliente ou responsável expressamente autorizado

Agendar e publicar

Somente a versão aprovada no canal autorizado

Ativar anúncio

Oferta, período e orçamento aprovados

Aumentar verba

Nova aprovação ou limite pré-autorizado

Delegar aprovação

Autorização explícita, revogável e registrada


Requisitos de aprovação

APR 01 Registrar item, versão, aprovador, data, comentários e decisão. Aprovação deve ser separada de mera visualização.

APR 02 Alteração material na peça, oferta, destino ou orçamento invalida a aprovação correspondente e exige nova revisão.

APR 03 Exibir comparação de versões e permitir aprovar, solicitar alterações ou rejeitar, inclusive pelo celular.

Execução da publicação

PUB 01 Conectar os ativos corretos da empresa e manter uma matriz dos formatos realmente suportados por cada canal.

PUB 02 Programar pelo fuso da empresa, respeitar processamento de mídia e acompanhar confirmação do provedor, armazenando referência e link quando disponíveis.

PUB 03 Não marcar como publicado apenas porque a tarefa entrou na fila. Mostrar erro, motivo, orientação e possibilidade de retomada.

PUB 04 Impedir duplicidade em reprocessamentos. Após timeout, verificar se a publicação já ocorreu antes de tentar criá-la novamente.

PUB 05 Permitir cancelar agendamentos ainda não enviados. Conexão revogada bloqueia novas ações e cria pendência de reconexão.

Critério de aceite

Dois processamentos da mesma tarefa não produzem dois posts. Um material alterado depois da aprovação não pode ser publicado usando a autorização anterior.


Requisitos do produto  |  

9 Sites e domínio próprio do cliente

Empresas sem site devem receber um site institucional gerado a partir dos dados confirmados. A solução deve usar componentes controlados, com identidade própria, conteúdo editável e captura de leads.

Criação e manutenção

SIT 01 Gerar páginas ou seções com apresentação, serviços/modalidades, diferenciais, fotos, localização, horários e contato. Não inventar depoimentos, números ou certificações.

SIT 02 Oferecer prévia, edição, aprovação, publicação, histórico e reversão de versões. Em empresas com site existente, permitir páginas específicas de campanha.

SIT 03 Criar formulários que enviam leads ao CRM correto e preservam origem/UTM disponíveis. Botão de WhatsApp não deve contar automaticamente como conversa ou venda.

SIT 04 Prever navegação móvel, acessibilidade, títulos e descrições, sitemap, conteúdo indexável e dados estruturados coerentes. Não prometer posição em buscadores.

Conexão do domínio

DOM 01 Disponibilizar endereço da plataforma e conexão de domínio ou subdomínio próprio. Manter um domínio principal e redirecionar aliases aprovados.

DOM 02 Em Site e domínio, receber o endereço, gerar instruções DNS específicas, verificar propriedade e apontamento, emitir HTTPS e acompanhar a situação.

DOM 03 Exibir aguardando configuração, verificando, certificado em emissão, ativo, erro e desconectado. Só servir o site quando o vínculo e o certificado estiverem válidos.

DOM 04 Impedir o mesmo domínio em empresas diferentes. Ao remover, limpar o vínculo de hospedagem; uma nova associação exige nova verificação.

DOM 05 Preservar registros de e-mail. Explicar que apontar o domínio principal substitui o site exibido; um subdomínio pode manter o site atual.

O domínio permanece do cliente. Compra e renovação ficam sob sua responsabilidade na proposta comercial. Incluir uma conexão de domínio no básico e usar Vercel são propostas técnicas/comerciais, não contratação de fornecedor já realizada.

Critério de aceite

O domínio validado mostra somente o site da empresa vinculada, com HTTPS. Um envio de formulário cria o lead naquela empresa e uma reversão recupera a versão publicada anterior.


Requisitos do produto  |  

10 CRM para organização dos leads

O CRM é o registro comercial central. Sua inclusão no básico é a proposta de produto; o plano superior adiciona chat e triagem por IA. Contatos e oportunidades devem ser separados para preservar negociações diferentes da mesma pessoa.

Cadastro e organização

CRM 01 Oferecer Kanban e lista com busca, filtros por etapa/origem/responsável/período, paginação e visualização dos próximos passos.

CRM 02 Registrar nome, telefone, e-mail, interesse, responsável, etiquetas e observações. A oportunidade reúne etapa, oferta de interesse, tarefas e motivo de encerramento.

CRM 03 Receber leads manualmente, por formulário do site, importação CSV e formulários nativos de anúncios quando conectados. No superior, incluir conversas dos canais.

CRM 04 Normalizar identificadores e detectar duplicidade dentro da empresa. Prévia de importação deve mostrar erros e possíveis duplicados antes da confirmação.

CRM 05 Manter origem original, campanha e pontos de contato posteriores quando disponíveis. Permitir origem desconhecida sem fabricar atribuição.

Funil e rotina comercial

Funil proposto: Novo → Em atendimento → Qualificado → Encaminhado → Visita agendada → Compareceu → Matriculado. Perdido é uma saída com motivo. Registrar o histórico das transições e permitir reabertura controlada.

CRM 06 Criar tarefas com prazo, responsável e lembrete; registrar notas internas, interações, agendamentos e pendências de resposta.

CRM 07 Distribuir leads e permitir reatribuição. A regra inicial pode ser manual ou uma fila configurada; não presumir que todo cliente usa rodízio.

CRM 08 Exigir confirmação humana ou integração operacional para marcar matrícula. Uma promessa de compra no chat não equivale a venda.

CRM 09 Exportar dados mediante permissão e registrar a operação. Exibir indicadores de conversão por etapa, perdas e tarefas atrasadas.

Critério de aceite

O mesmo telefone pode existir em duas empresas sem compartilhar histórico. Um contato pode ter duas oportunidades. Evento repetido não duplica o lead, e mudanças de etapa permanecem auditáveis.


Requisitos do produto  |  

11 Chat integrado e agente de triagem

O plano superior deve receber e responder leads interessados pelo WhatsApp e Instagram. O agente faz atendimento inicial e triagem comercial; demandas de alunos sobre financeiro, cancelamento ou suporte são encaminhadas ao responsável.

Caixa de entrada

CHA 01 Exibir canal, contato, histórico, responsável, etapa do CRM, notas internas, pendências e status reais de envio/entrega quando disponíveis.

CHA 02 Usar estados IA ativa, aguardando humano, humano ativo e encerrado. O botão Assumir atendimento deve impedir envios automáticos inclusive de respostas em geração.

CHA 03 Permitir devolver a conversa à IA explicitamente, usando resumo atualizado. Preservar autoria de cada mensagem e histórico da transferência.

CHA 04 Não unir automaticamente perfil do Instagram e telefone do WhatsApp por semelhança de nome. A fusão exige evidência ou confirmação humana.

Método de atendimento

ATD 01 Responder à dúvida inicial, compreender o interesse, coletar dados mínimos e orientar com planos, condições e horários confirmados.

ATD 02 Não repetir perguntas já respondidas nem inventar preços, descontos, vagas ou disponibilidade. Quando faltar informação, encaminhar com contexto.

ATD 03 Convidar para visita, aula experimental ou conversa com responsável. Confirmar horário somente com agenda real disponível; caso contrário, registrar solicitação.

ATD 04 Criar ou atualizar lead e oportunidade, registrar interesse e próxima ação. Respeitar pedido de falar com humano.

ATD 05 Concluir encaminhamento somente após atribuição persistida e confirmação da notificação. Falhas devem aparecer como pendência operacional.

ATD 06 Fazer follow-up conforme regras configuradas, autorização, opt-out, janela e templates do canal. Não fixar intervalos não definidos pelo produto.

Critério de aceite

Mensagens recebidas novamente não provocam respostas duplicadas. Ao assumir, o humano interrompe a IA antes do envio. O agente não executa cancelamentos ou operações financeiras de alunos.


Requisitos do produto  |  

12 Gestão de campanhas Meta e Google Ads

O sistema deve centralizar campanhas, criativos, propostas de ajuste e indicadores. O requisito comercial é atender Meta e Google Ads; a cobertura por tipo de campanha e operação precisa ser explícita na implementação.

Conexão e preparação

ADS 01 Autorizar contas por empresa, listar ativos disponíveis e confirmar os selecionados. Manter contas de anúncios e cobrança de mídia sob responsabilidade do cliente.

ADS 02 Importar campanhas existentes inicialmente para leitura. Alterações automáticas exigem ativação explícita da gestão para a conta ou campanha.

ADS 03 Criar propostas com objetivo, público/região, oferta, orçamento, período, destino, textos e criativos. Verificar coerência entre anúncio, página e atendimento.

ADS 04 Priorizar na primeira implementação geração de leads no Meta e pesquisa no Google. Outros tipos entram por expansão da matriz de suporte.

Execução e controle

ADS 05 Preparar campanhas pausadas e ativar somente após aprovação adequada. Registrar envio, aceitação, análise, reprovação e execução conforme status do provedor.

ADS 06 Permitir consultar, pausar e alterar operações suportadas. Exibir claramente as operações ainda indisponíveis.

ADS 07 Controlar orçamento, limites de alteração, período, contas permitidas e condições de pausa no backend. A IA não pode ampliar sua própria autorização.

ADS 08 Registrar cada alteração e reconciliar mudanças realizadas fora da plataforma. Após timeout, verificar o resultado antes de repetir criação.

ADS 09 Monitorar consumo e falhas, respeitando atraso na contabilização dos provedores. Combinar limites externos, controles internos e alertas; não prometer bloqueio financeiro instantâneo absoluto.

Evolução da autonomia

Começar com propostas e execução supervisionada. Ajustes autônomos entram depois, dentro de limites aprovados e com evidência de qualidade. Cancelar aprovação ou desconectar conta impede novas ações.

Critério de aceite

Campanha sem aprovação de oferta e orçamento não é ativada. Testes não geram gasto real. Uma falha de rede não cria campanhas duplicadas nem marca uma ação rejeitada como concluída.


Requisitos do produto  |  

13 Resultados e acompanhamento semanal

O painel deve mostrar o que foi produzido, executado e convertido. O objetivo é aproximar decisões de marketing dos resultados comerciais, sem confundir cliques, conversas e matrículas.

Indicadores

RES 01 Mostrar investimento, alcance, impressões, cliques, leads, custo por lead e demais métricas disponíveis, com fonte e data da última atualização.

RES 02 No CRM, medir tempo de resposta, qualificação, agendamento, comparecimento, matrícula e perdas. Informar denominadores e período dos indicadores.

RES 03 Separar conversões reportadas pelas plataformas de matrículas confirmadas. Não somar os mesmos eventos como vendas independentes.

RES 04 Mostrar receita e retorno somente quando houver dados confiáveis suficientes. Custo por aquisição deve informar quais custos foram incluídos.

RES 05 Comparar períodos equivalentes e distinguir ausência de dados de resultado zero. Recomendações devem explicitar hipóteses e limitações de amostra.

Acompanhamento contratado

ACO 01 Habilitar área de acompanhamento para empresas com o adicional. Vincular integrantes autorizados da equipe e representantes do cliente.

ACO 02 Preparar pauta semanal com resultados, conteúdos pendentes, qualidade dos leads, campanhas e dificuldades operacionais.

ACO 03 Registrar encontro, participantes, decisões, responsáveis e prazos. O cliente participa da revisão junto à equipe.

ACO 04 Converter decisões em tarefas e propostas de atualização. Publicações, ofertas e verba continuam sujeitas às permissões e aprovações existentes.

ACO 05 Permitir acompanhar tarefas entre encontros e consultar histórico. Duração, formato das reuniões e volume de revisões ainda precisam de definição comercial.

Ciclo de melhoria

O estrategista recebe resultados agregados, objeções recorrentes, ofertas atualizadas e decisões confirmadas. Conversas privadas completas não precisam ser enviadas a todos os agentes para produzir esse aprendizado.

Critério de aceite

Uma decisão semanal gera ação com responsável e prazo. A equipe só vê empresas autorizadas. O painel nunca apresenta intenção de compra como matrícula confirmada.


Requisitos do produto  |  

14 Integrações previstas

As integrações abaixo são escolhas técnicas propostas para executar o escopo. Credenciais, elegibilidade, permissões e cobertura devem ser verificadas em homologação antes de disponibilizar cada operação ao cliente.

Integração

Função no sistema

OpenAI Responses e saídas estruturadas

Onboarding, estratégia, textos, triagem e entregas validadas

OpenAI geração de imagens e pesquisa

Produção visual e pesquisa pública com fontes

Google Places

Descoberta de concorrentes locais

Meta Marketing API

Campanhas, anúncios e indicadores

Instagram API e APIs de Pages

Publicação e métricas dos formatos suportados

WhatsApp Cloud API e Embedded Signup

Conexão de empresas, mensagens e status

Instagram Messaging

Caixa de entrada e respostas no Instagram

Meta Lead Ads e Google Lead Form Webhook

Entrada de formulários nativos no CRM

Google Ads API

Gestão de campanhas e relatórios

Google Analytics Data API

Consulta de métricas de propriedades autorizadas

Asaas

Assinaturas e eventos de cobrança por empresa

Resend

Convites e notificações por e-mail

Vercel API ou provedor equivalente

Domínios, hospedagem e certificados do site


Regras para todos os conectores

INT 01 Conectar, validar, reconectar e revogar acesso por empresa. Guardar credenciais fora do frontend e dos prompts.

INT 02 Manter status, última sincronização, permissões, operações suportadas e orientação sobre falhas.

INT 03 Validar eventos externos pelo mecanismo de cada fornecedor e resolver a empresa pelo ativo vinculado. Não confiar apenas em um company_id recebido na requisição.

INT 04 Tratar duplicidade, ordem de eventos, limites, expiração e reconciliação. Simulações de desenvolvimento devem ser identificadas.

Critério de aceite

Cada função anunciada possui prova real registrada ou aparece como indisponível. Dados de Analytics exigem instrumentação prévia; a API de relatórios não instala rastreamento automaticamente.


Requisitos do produto  |  

15 Arquitetura dados e segurança

A proposta é um backend modular com workers separados. Agentes, CRM, campanhas e sites compartilham contratos e autorização, com dados isolados por empresa.

Camada

Escolha técnica proposta

Interface

Next.js, React, TypeScript, Tailwind e shadcn/ui

Backend e contratos

NestJS e Zod

Dados e acesso

PostgreSQL no Supabase, Auth, Storage e RLS

Tarefas em segundo plano

BullMQ e Redis, com filas por finalidade

Código e ambientes

Monorepositório, migrações e ambientes separados


Dados e confiabilidade

TEC 01 Organizar empresas/membros/assinaturas; perfis/ofertas/marca; estratégias/campanhas/conteúdos/aprovações; contatos/oportunidades/conversas; sites/domínios; métricas e auditoria.

TEC 02 Associar entidades operacionais à empresa e impedir relações cruzadas. Aplicar isolamento também em arquivos, filas, buscas de conhecimento e atualizações em tempo real.

TEC 03 Persistir o estado de negócio no banco. Salvar eventos e tarefas de forma confiável, com tentativas limitadas e reconciliação de efeitos externos.

TEC 04 Priorizar mensagens sobre gerações demoradas. Registrar duração, erros, custo e consumo por empresa; limitar concorrência e orçamento de execução.

Proteção e operação

SEG 01 Validar autorização no servidor; conexões privilegiadas que ignoram RLS precisam de controles explícitos e testes. Proteger tokens em cofre ou criptografia apropriada.

SEG 02 Tratar páginas e documentos como dados não confiáveis. Bloquear leitura de endereços internos pelo extrator de sites e instruções externas que tentem comandar ferramentas.

SEG 03 Validar uploads, usar links temporários e restringir exportações. Prever consentimentos, opt-out, retenção e exclusão conforme regras definidas para o produto.

SEG 04 Manter logs sem segredos, trilha de auditoria, backups e restauração testada. Definir metas de disponibilidade, desempenho e recuperação antes do lançamento.

Critério de aceite

Testes comprovam isolamento entre empresas em API, banco, arquivos e jobs. Uma restauração é demonstrada e ações sensíveis possuem responsável e histórico.


Requisitos do produto  |  

16 Desenvolvimento e homologação com Codex

O desenvolvimento deve avançar em entregas pequenas e verificáveis. A primeira tarefa inspeciona o repositório existente; funcionalidades aproveitáveis não devem ser reescritas sem necessidade.

Fase

Entrega

Validação principal

0 e 1

Auditoria e base executável

Projeto inicia e compila

2 e 3

Empresas, acessos e cobrança

Isolamento e assinatura independente

4 e 5

CRM e onboarding

Lead organizado e perfil confirmado

6 e 7

Pesquisa e estratégia

Fontes, método e versões

8 e 9

Conteúdo, vídeo, site e domínio

Prévia, aprovação e captura correta

10 e 11

Publicação e atendimento

Sem duplicidade e com passagem humana

12 e 13

Anúncios, métricas e revisão semanal

Verba autorizada e resultados rastreáveis

14

Piloto de ponta a ponta

Escopo anunciado comprovado


Critérios mínimos de liberação

VAL 01 Cadastrar duas empresas e provar que dados, permissões, cobrança e credenciais não se misturam.

VAL 02 Completar onboarding, gerar planejamento, revisar peça, enviar vídeo final e aprovar versões corretas.

VAL 03 Receber formulário no domínio da empresa e localizar o lead correto no CRM, com origem disponível.

VAL 04 Repetir webhook e job sem duplicar lead, resposta, publicação ou anúncio.

VAL 05 Assumir atendimento humano durante geração da IA e comprovar que a resposta automática não é enviada.

VAL 06 Bloquear campanha sem autorização e testar conexão revogada, falha de publicação, orçamento e limites de consumo.

VAL 07 Registrar matrícula confirmada, atualizar indicadores e gerar tarefas a partir de uma revisão semanal.

A cada entrega, o Codex deve registrar o que funciona, testes executados, integrações reais ou simuladas e pendências. AGENTS.md reúne instruções curtas; requisitos, decisões e progresso permanecem versionados no repositório.

Critério de aceite

O piloto usa contas e materiais autorizados. Testes não ativam gasto publicitário ou publicação real sem autorização. Integração pendente não é apresentada como pronta.


Requisitos do produto  |  

17 Decisões abertas e limites do lançamento

As decisões abaixo precisam ser resolvidas antes de transformar a especificação em oferta comercial definitiva. Elas não impedem a implementação da fundação e dos módulos já definidos.

Decisão

Situação

Preço do plano com atendimento

A definir após estimar consumo e validar valor

Franquias de conteúdo e revisões

A definir; não prometer produção ilimitada

Uso de IA e mensagens

Definir franquia, excedentes e apresentação ao cliente

Armazenamento e tamanho de vídeos

Definir limites e retenção

Filiais e unidades

Definir quando exigem empresa/assinatura adicional

Acompanhamento semanal

Definir duração, formato, suporte e revisões incluídas

Domínio próprio no básico

Proposta de uma conexão por empresa

Cancelamento e inadimplência

Definir carência, suspensão, exportação e retenção

Metas operacionais

Definir disponibilidade, latência, recuperação e suporte


Fora da primeira versão

Edição automática de vídeos; geração de episódios completos por IA; financeiro/cancelamento de alunos pelo agente; sistema de gestão da academia; operação de todos os tipos de anúncio sem matriz de suporte; treinamento de modelo próprio; expansão imediata para todos os segmentos.

Referências técnicas de apoio

A documentação dos fornecedores orienta as integrações. Versões, permissões e condições comerciais devem ser conferidas ao implementar. As escolhas de arquitetura e os critérios deste documento são propostas de engenharia para o produto.

Codex e instruções AGENTS.md

Meta Marketing API e coleções oficiais

WhatsApp Business Platform e conexão de empresas

Google Ads API e gestão de campanhas

Vercel e domínios personalizados

Supabase e isolamento por políticas de acesso