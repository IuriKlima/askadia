# Campanhas de relacionamento e integração de gestão

## Implementação local — 22/09/2026

A página Campanhas separa mensagens para alunos de propostas de tráfego pago. Mensagens usam a instância WhatsApp da mesma empresa. Tráfego pago reaproveita as propostas da estratégia; criação/ativação de anúncios pela API ainda não foi entregue.

Fluxo: importar/receber alunos → salvar regra → revisar destinatários e mensagem → ativar. Toda edição cria nova revisão e volta a rascunho. Pausar cancela reservas, mas uma requisição já em andamento pode concluir.

Condições disponíveis: aniversário, ausência por X dias, grupo, situação ativa, intervalo de datas, horário no fuso da empresa, idade máxima dos dados e limite diário. Consentimento explícito obrigatório. Aniversário desconhecido e última presença desconhecida não são inferidos. Aniversários em 29/02 são elegíveis somente em 29/02; não há deslocamento implícito para outra data.

A execução ocorre na janela de uma hora após o horário configurado e limita cada empresa a um envio por minuto. Portanto, o limite diário é um teto, não uma garantia de volume. A indisponibilidade da conexão não provoca disparos retroativos fora dessa janela. Cada aniversário só é enviado uma vez ao ano por campanha/telefone; ausência é enviada uma vez por registro da última presença. Uma nova presença abre outro período. Resultado incerto não é reenviado automaticamente.

## API de entrada

POST /api/integrations/management/students. Authorization: Bearer <chave exclusiva da empresa>. A chave é gerada pelo proprietário nas integrações, armazenada somente como SHA-256 e exibida uma vez. Rotação/revogação remove o acesso anterior. O remetente não escolhe companyId.

Corpo: eventId (UUID), observedAt (data/hora ISO com fuso), students (1–500). Campos de cada aluno: externalId, name, phone em E.164, birthday AAAA-MM-DD ou null, lastAttendance ISO ou null, status active/inactive, consent boolean, tag opcional. Até 250 KB; dez lotes por minuto por chave. Observações anteriores a 24h, futuras ou anteriores ao último lote são recusadas. O mesmo eventId com os mesmos dados é idempotente; com dados diferentes é recusado. Use horários observados iguais para as páginas do mesmo lote lógico e um eventId por página.

IDs existentes atualizam registros; alunos ausentes no lote não são apagados nem ficam inativos automaticamente. A origem deve enviar alterações de situação e autorização. Registros que deixam de ser atualizados são excluídos dos disparos pela regra de atualização máxima. Telefones duplicados para IDs diferentes são recusados.

É um contrato de recebimento, não um coletor universal que compreende qualquer API. Cada ERP pode enviar esse formato ou usar um adaptador. O CSV alternativo utiliza cabeçalho e exemplo disponibilizados na página.

## Permissões e execução

Leitura: marketing.read + crm.read. Escrita e aprovação: marketing.write + crm.write. Chave de integração: proprietário. Tabelas com RLS; mutações via RPC. Consumidor e ingestão exigem service_role no servidor, inacessível ao navegador. Aprovação e vínculo são revalidados antes de cada envio. Dados e consentimento são conferidos novamente imediatamente antes da chamada ao provedor.

Migrações necessárias: 202609220006, 202609220007, 202609220008. São aditivas e não removem cadastros. O processo API executa o consumidor somente com MESSAGE_CAMPAIGNS_ENABLED=true, Supabase service_role e credenciais Evolution. A interface mantém ativação bloqueada se o consumidor não tiver consultado a fila recentemente. Nenhuma campanha é ativada por deploy.

## Wellhub e TotalPass

Conectores diretos ainda não implementados/homologados. A interface informa essa pendência. As APIs de academia são voltadas a controle de acesso e reservas; não pressupor disponibilidade de aniversário nem histórico completo. TotalPass exige chave de parceiro e de unidade e homologação; Wellhub exige liberação da integração fitness. Não usar endpoints de consumo/validação de check-in em testes de leitura.

Fontes: https://developers.gympass.com/ e https://dev.totalpass.com/docs/getting-started.

## Validação e pendências

Testes locais exercitam isolamento, autorização, consentimento, atualização dos dados, versões, duplicação, mudança de presença, resultado incerto, chave revogada e repetição de importações. Não enviam mensagens reais. A aplicação das três migrações no Supabase, a homologação pela interface e o deploy ainda devem ser confirmados antes de declarar o fluxo disponível em produção.
