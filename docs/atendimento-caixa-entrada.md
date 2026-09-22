# Caixa de entrada e Configuração de Atendimento

## Jornada e navegação

`/empresa/:id/atendimento` abre a caixa da empresa. Lista de contatos, busca, filtros por canal, conversa, paginação, modo de tela cheia e atalhos rápidos ficam na mesma área. `Configuração de Atendimento`, em Aquisição, abre `/empresa/:id/configuracao-atendimento`. O menu reduzido de atendentes preserva somente caixa/CRM.

WhatsApp consulta `POST /chat/findChats/:instance` e `POST /chat/findMessages/:instance` na Evolution 2.3.7. O histórico permanece no servidor Evolution, não no localStorage; ele não é um backup no Supabase. A disponibilidade de mensagens antigas depende da retenção/sincronização da instância. Grupos têm leitura. Imagens, documentos e áudios podem ser abertos sob demanda; envio de arquivos até 8 MB exige tomada humana. Downloads revalidam empresa, conversa e ID da mensagem. Arquivos de visualização única não são abertos. Contatos sem nome informado pelo provedor usam seu identificador. Lista: 60 conversas por página; mensagens: 50 por página, atualização enquanto a tela está visível. Cada requisição revalida o acesso à empresa.

O cliente visualiza flags WhatsApp, Instagram, Facebook e TikTok. Instagram/Facebook ainda dependem de integração de mensagens, permissões e webhook Meta; o OAuth de publicação não autoriza automaticamente Direct/Messenger. TikTok depende do acesso à API de mensagens e implementação do adaptador. Nenhum destes canais retorna contatos fictícios.

## Matriz de permissões

| Operação | Permissão no servidor/banco |
| --- | --- |
| Ler conversas, histórico, atalhos e configuração | `crm.read` |
| Assumir atendimento, preparar IA e enviar texto | `crm.write` |
| Alterar prompts, fluxos e atalhos | `marketing.write` e `crm.read` |
| Conectar uma instância | Proprietário, como no fluxo de Integrações |

RLS isola settings, atalhos, responsáveis, tentativas de IA e solicitações de envio. API usa o JWT da sessão e deriva a instância `askadia-{companyId}` do vínculo autorizado. Não aceita URL, instância, credencial nem empresa de destino fornecidas pelo contato. Revogar o vínculo remove acesso às rotas e às tabelas. RPCs também revalidam permissões.

## Contrato do atendimento

`company_service_settings`: chave `(company_id, channel)`, `mode` (human/ai/flow), `prompt` até 8.000 caracteres, `rules` (até 12 regras ordenadas de expressão, resposta e encaminhamento), `fallback` e revisão otimista. Não compartilha estado entre empresas ou canais. Salvar com revisão antiga retorna conflito.

`company_quick_replies`: até 100 atalhos por empresa, identificador UUID, `/shortcut`, título e texto. A escolha insere no compositor; não envia automaticamente. Atendentes podem usar, proprietários/gerentes autorizados configuram.

`inbox_handoffs`: responsável por empresa/canal/conversa. `inbox_dispatches`: reserva persistida com UUID único, texto, autor e estado. Enviar exige assumir, vínculo ativo, WhatsApp aberto e conversa existente. Cliques repetidos não disparam novamente. Timeout ou confirmação ambígua ficam incertos e não são repetidos automaticamente. O histórico Evolution é a fonte da confirmação; a resposta inicial só significa aceitação pelo provedor, não entrega/leitura.

O assistente usa **`gpt-4o-mini`**, independente dos modelos da estratégia/onboarding. Recebe somente a configuração do canal, a última versão confirmada do perfil da mesma empresa e até 16 mensagens textuais da conversa selecionada. Não recebe o catálogo de clientes, credenciais nem contextos de outras empresas. `store:false`, limite de saída e sem repetição automática da chamada; cota inicial de 100 preparações por empresa/dia. Informações ausentes devem ser encaminhadas à equipe. A configuração oferece um teste fictício que não envia mensagens.

**Resposta automática opcional.** O consumidor da API consulta novas mensagens da Evolution a cada 15 segundos, com reservas duráveis no banco. Requer INBOX_AUTOMATION_ENABLED=true, chave de serviço Supabase privada e migração 202609220003. Uma consulta bem-sucedida recente ao banco libera o controle na interface; somente marcar e salvar ativa o canal. Limite inicial de 100 respostas/dia/empresa. Histórico anterior à ativação ou retomada não recebe resposta. Tomada humana, mensagens enviadas pelo celular, alteração de configuração, perfil ou revogação são revalidadas antes do despacho. Retorno ambíguo fica incerto, sem reenvio automático. Um despacho já iniciado impede a tomada humana até sua conclusão, para evitar respostas simultâneas.

O canvas persiste nós, posições e arestas, valida caminhos e impede ciclos. Cada mensagem percorre o fluxo desde o início; não é um motor de conversas com estado entre etapas. Condições têm saídas Sim/Não; blocos de mensagem se acumulam em uma resposta; Atendente encerra e pausa a automação. Há edição de conexões por seletores para teclado. Regras legadas são convertidas preservando a ordem.

Gerar prompt usa apenas o perfil comercial confirmado, sem orçamento interno ou identificadores dos operadores. O texto precisa ser revisado e salvo. Cada canal e empresa mantém sua própria revisão. A caixa oferece Assumir e enviar, anexos, prévia de mídia, atalhos e retorno à IA.

## Instalação e validação

Migração nova: `supabase/migrations/202609220001_inbox.sql`. A migração 006 do CRM pode ainda estar ausente em bases existentes. `node scripts/build-inbox-migration.mjs` prepara `.local/askadia-caixa-entrada.sql`, em transação: instala 006 somente se suas tabelas não existem e instala a nova estrutura. Executar uma única vez após 001–005 e 007/008; preservar o controle de migrações. Não apagar nem recriar empresas.

Validação automatizada em `tests/inbox.test.ts`: instala o pacote em uma base sem 006, testa configuração por empresa/canal, revisão, RLS, revogação, atalhos, idempotência, tomada humana, cota de IA, normalização/paginação, fluxo ordenado e modelo/contexto OpenAI com transporte simulado. Testes nunca enviam WhatsApp real.

Referências verificadas: [rotas Evolution 2.3.7](https://github.com/EvolutionAPI/evolution-api/blob/2.3.7/src/api/routes/chat.router.ts), [GPT-4o mini](https://developers.openai.com/api/docs/models/gpt-4o-mini).

Migrações incrementais adicionais: 002 canvas/prompt, 003 automação, 004 vínculo CRM–WhatsApp e 005 datas/vídeos do calendário. Aplicadas no Supabase em 22/09/2026. Não reaplicar em base já instalada.
