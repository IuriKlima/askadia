# Jornada do cliente — revisão de UI, UX e funcionamento

Revisão de 23/09/2026. Base: código, contratos, permissões, testes e navegação autenticada em produção. A revisão não envia mensagens, ativa anúncios, aprova estratégia, publica sites nem altera cadastros reais. Estados remotos abaixo representam a empresa examinada, não todas as empresas da plataforma.

## Direção da experiência

Entrada → escolher empresa → conhecer e confirmar o negócio → acompanhar preparação → revisar estratégia → criar/revisar peças → aprovar cada versão → conectar canal → executar quando a integração estiver disponível. Atendimento, CRM, campanhas e site são áreas paralelas com seus próprios pré-requisitos. A confirmação do perfil não autoriza gasto, publicação ou envio.

O cliente deve identificar onde está, qual o próximo passo, o que está pronto e por que uma ação está bloqueada. A interface usa o estado persistido; dados indisponíveis não devem aparecer como zero ou como uma tarefa concluída.

## Problemas corrigidos nesta revisão

| Prioridade | Evidência | Correção |
|---|---|---|
| Alta | Proxy de renovação de sessão não incluía `/empresa`, `/entrada` e APIs da jornada. | Inclusão dessas rotas na renovação existente, preservando Auth/RLS e permissões dos endpoints. Renovação com token realmente expirado ainda exige ensaio controlado; não foi forçada na conta real. |
| Alta | Falha HTML de proxy/deploy gerava erro de JSON para o cliente, inclusive antes de reconhecer 401. | Leitura compartilhada com mensagens de sessão expirada, indisponibilidade e limitação; mantém mensagens de conflito/validação. |
| Alta | Avisos do domínio eram renderizados apenas dentro da aba de prévia, invisível durante a configuração. | Feedback visível nas duas abas e tentativa de recarga para falhas iniciais. |
| Alta | Salvar/verificar domínio chamava a recarga geral que substituía conteúdo do site ainda não salvo. | Operações do domínio bloqueadas enquanto há alterações no conteúdo, com orientação para salvar; alerta ao fechar/recarregar com rascunho não salvo. |
| Média | Uma imagem indisponível descartava também todas as imagens carregadas com sucesso. | Carregamento independente preserva as prévias disponíveis e informa falha parcial. |
| Média | Navegação inteira mudava de “Primeiros passos” para menu completo em cada carregamento. | Menu estável baseado nas permissões; progresso fica na visão geral. Marca/empresa fixas, rolagem própria dos links e atalhos de teclado. |
| Média | Visão geral com texto genérico e consulta de estratégia cuja falha era ignorada. | Próximo passo e lista de pendências com calendário, materiais, conexões e site; falhas parciais identificadas, sem bloquear outras áreas. |
| Média | Vários componentes usavam `actions` sem classe definida no CSS. | Barra de ações reutilizada com espaçamento, quebra de linha e botões legíveis no celular. |
| Média | Calendário mudava sozinho para o mês mais antigo da estratégia e não tinha navegação anterior/próximo/hoje. | Mês atual em São Paulo como padrão; navegação de meses e retorno ao mês do dia aberto. |
| Média | Grade com textos de 8px no celular. | Visão em lista automática no celular, seleção manual mês/lista, miniaturas, datas e status legíveis. |
| Média | Falha inicial do calendário deixava uma seção quase vazia; dias vazios não orientavam o usuário. | Carregamento, erro recuperável e estados vazios com caminho de retorno. |
| Média | Estratégia longa, acesso à revisão pouco evidente, botões de edição abriam formulários abaixo da área visível. | Índice por seção, atalho para revisão e foco/rolagem para o formulário de edição/refação. Estratégias de perfil anterior não são apresentadas como atuais. |
| Média | Aviso de webhook ausente era fixo, mesmo com serviço de automação operacional. Tabela afirmava design pendente apesar de artes geradas. | Remoção dos avisos estáticos contraditórios; orientação para a configuração do canal e passos seguintes. |
| Média | CRM não explicava busca sem resultados e campanhas exibiam zero alunos enquanto carregavam. | Estado vazio com limpar busca, recarga do CRM/campanhas e dados apresentados após consulta. |
| Baixa | Página pública apresentava design/atendimento inteiros como futuros. | Descrição da jornada atual e dependências de execução, sem prometer integrações homologadas. |

## Estado funcional e pendências

| Área | Evidência e estado | Próxima melhoria ou dependência |
|---|---|---|
| Cadastro, login e recuperação | Fluxos implementados; login local renderiza. Não foi criado usuário nem disparado e-mail nesta revisão. | Resend/SMTP e identidade visual dos e-mails dependem da configuração remota já registrada. |
| Empresas, equipe e permissões | APIs com autorização; testes existentes cobrem isolamento/revogação. | Ensaio com contas de papéis distintos em ambiente controlado. Não confundir testes locais com homologação de cada papel em produção. |
| Onboarding e materiais | Conversa, resumo, reabertura e upload múltiplo implementados. Perfil remoto v3 e três materiais observados. | Google Maps JavaScript tinha configuração pendente; não houve nova homologação do mapa nem consumo de IA nesta revisão. Melhorar agrupamento do resumo extenso em uma etapa futura. |
| Estratégia | Proposta em revisão observada na visão geral e calendário. | Aprovação é decisão do cliente. Regeneração e alterações reais não foram acionadas na auditoria. |
| Preparação e calendário | Produção mostrou preparação concluída, oito ideias e três publicações em setembro a partir do dia 23. | Vídeos finais dependem de gravação/upload. Não há publicador social automático completo: datas são planejamento, não comprovante de postagem. |
| CRM | Kanban, lista, histórico e links internos presentes no código; revisão anterior já verificou abertura do chat. | Nesta revisão, leitura visual da lista completa ficou limitada por instabilidade do navegador. Limite de mil contatos recentes e sincronização manual permanecem. |
| WhatsApp e IA | Configuração remota mostrou WhatsApp conectado e automação disponível, canal em “Somente atendimento humano”. | Escolher IA/fluxo, revisar prompt e ativar conscientemente. Não foi alterado nem enviado nada na auditoria. |
| Instagram/Facebook/TikTok | Meta aguardava autorização/seleção da Página; Instagram/Facebook mostravam permissão de mensagens pendente. TikTok indicava integração pendente. | Acessos, análise/homologação e conexão por empresa. Não afirmar que um filtro de canal significa integração ativa. |
| Campanhas de mensagens | Tela carregou zero alunos e nenhuma campanha, com criar/importar. | Dados e consentimentos, revisão de destinatários, ativação pelo cliente. Não houve campanha real de teste. |
| Tráfego pago | Propostas da estratégia carregaram. Contas Meta/Google não selecionadas; Google OAuth/desenvolvedor pendentes. | Homologar conexões, consulta real e execução supervisionada. Código atual de propostas/consulta não equivale a criação/ativação de anúncios completa. |
| Sites | Rascunho, prévia e publicação versionada implementados. Última verificação remota: não publicado, WhatsApp ausente. | Preencher contato e revisar. Automação Easypanel aguarda autorização da chave/API; wildcard foi rejeitado pelo Registro.br. Subdomínio reservado não prova DNS/HTTPS. |
| Resultados | Dashboard separado com origem de dados/importações no código e testes existentes. | Homologar coleta por provedor; revisar navegação unificada e filtros em rodada específica. Nenhum resultado financeiro foi presumido. |
| Assinatura | Consulta de catálogo/permissões implementada; contratação informada como indisponível. | Checkout, webhooks e cobrança real continuam pendentes. |

## Critérios de validação

- Rodar `pnpm check`: lint, tipos, testes e builds. Testes novos cobrem respostas não JSON, 401, validação/conflito e navegação mensal/fuso.
- Conferir após deploy: visão geral, menu estável, calendário mês/lista, retorno do dia, domínio com avisos visíveis, estratégia e navegação mobile.
- Não testar publicação/envio/ativação com efeitos reais. Testes de adaptadores não homologam provedores externos.
- O navegador local exigiu login; a validação autenticada das telas alteradas será realizada na sessão existente em produção após o deploy autorizado.

Resultado final de testes e implantação: consultar `docs/progress.md`.
