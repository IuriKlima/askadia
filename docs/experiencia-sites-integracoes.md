# Jornada, CRM, campanhas e sites — setembro de 2026

## Alterações e evidências

- `company-journey.tsx`: Agentes sai da navegação; rota antiga redireciona para Estratégia. O banner Conhecer minha empresa fica em `strategy-workspace.tsx`. O chat não força mais o resumo quando o perfil está completo (`onboarding-chat.tsx`); é possível ver histórico, reabrir, corrigir e confirmar outra versão.
- `strategy-workspace.tsx` / `onboarding/strategy.ts`: diagnóstico, concorrentes confirmados, objetivos, indicadores, plano de ação, ideias sazonais, anúncios, palavras-chave e lacunas; revisão manual e nova geração com feedback invalidam aprovação. Confirmação de onboarding abre preparação; aprovação abre calendário. A regra esclarecida pelo usuário é **no máximo duas publicações por semana**, priorizada sobre o pedido anterior de 12/mês. Novas estratégias contêm oito ideias em quatro semanas. Calendários anteriores são preservados.
- `places-map.tsx` / `onboarding/providers.ts`: mapa com marcadores selecionáveis, círculo de raio e seleção equivalente por lista. Pesquisa por raio depende de coordenadas do local confirmado. Mapa interativo requer **Maps JavaScript API** na chave de navegador; Places e alternativa manual seguem independentes. Sem resultados inventados.
- `editorial-calendar.tsx`: separação entre gerar textos/roteiros e criar designs com a marca de produto **Askadia Image 1.0**; provedor real continua Gemini configurado. Datas geradas contam a semana ISO e datas já existentes na estratégia vigente. Banco impede terceira publicação semanal em novos planejamentos, inclusive por edição manual. Temas mensais são editoriais, não fatos sobre eventos locais; datas móveis ficam pendentes de confirmação.
- `customer-history.tsx` / `inbox/customer-controller.ts`: card CRM abre histórico, primeiro contato disponível, tempos de resposta da amostra, últimas mensagens e notas. Histórico do provedor pode ser parcial; indicadores informam essa limitação e não inventam datas anteriores.
- `inbox/meta*.ts`: lista e lê conversas autorizadas da Página/Messenger e Instagram por polling. Resposta textual exige tomada humana, janela de 24 horas e reserva idempotente. Identificador assinado vincula empresa, Página, canal, conversa e contato; revalidação de acesso no servidor. Mídias e resposta automática da IA **Meta** ainda não estão implementadas. Não confundir autorização para publicar com permissão de mensagens.
- `campaign-recipients.tsx` / migração 010: campanhas de vendas/marketing para seleção explícita de contatos. Sincronizar WhatsApp não concede consentimento. Registro exige evidência, permite revogação e valida a empresa. Cada destinatário recebe no máximo uma vez por campanha selecionada; alteração de versão não repete envios concluídos/incertos. Consumidor existente revalida consentimento, horário, atualização e autorização antes de enviar.
- `paid-ads.tsx` / `campaigns/ads*.ts`: propostas de investimento distribuído dentro de um teto, público, região, mídias e briefing; contas Meta/Google vinculadas por empresa; leitura da hierarquia real de campanhas/grupos/anúncios, com aviso de paginação parcial. Google Performance Max apresenta grupos de recursos. **Criação/alteração/ativação externa de anúncios e sincronização de métricas ainda não estão entregues por essas rotas.** Não há gasto por gerar proposta ou conectar conta.

## Meu site e hospedagem

`sites/controller.ts`, `site-builder.tsx`, `contracts/site.ts` e migração 013 oferecem:

1. Geração de rascunho a partir da versão confirmada do perfil, com OpenAI configurada e limite de cinco gerações por dia/empresa.
2. Edição de textos, serviços, WhatsApp, cores, aparência, logo e até oito fotos já anexadas à própria empresa. Modelo não produz JavaScript nem HTML executável: os textos estruturados são escapados em um template HTML responsivo.
3. Prévia isolada em iframe e exportação HTML com imagens embutidas. Alterações ficam em rascunho até a publicação explícita.
4. Publicação em `/s/[companyId]`, hospedada na aplicação Askadia. Somente o snapshot publicado e seus materiais selecionados ficam públicos. Retirar do ar desabilita também a leitura de imagens pela rota pública.
5. Um domínio/subdomínio por empresa, exclusivo, com token TXT `_askadia.DOMINIO` e CNAME para `SITES_CNAME_TARGET` (padrão: domínio de `WEB_ORIGIN`); domínio raiz pode usar A para `SITES_SERVER_IP` ou ALIAS/ANAME. Verificação DNS não é apresentada como confirmação de certificado HTTPS.
6. Roteamento do host no caminho `/` para a página publicada da empresa com DNS verificado. O domínio raiz da **plataforma Askadia** continua institucional.

Para encaminhamento e HTTPS automáticos, configurar no servidor `EASYPANEL_API_URL` (base `/api`), `EASYPANEL_API_TOKEN` (usuário restrito ao projeto quando suportado), `EASYPANEL_SITE_PROJECT`, `EASYPANEL_SITE_SERVICE` e `EASYPANEL_CERTIFICATE_RESOLVER`. A URL deve usar HTTPS ou o endereço interno `http://easypanel:3000/api`; o token nunca vai ao navegador. Adaptador usa `listDomains` e `createDomain`, destino fixo no serviço Askadia/porta 3000, após verificar propriedade e DNS. API/documentação: https://easypanel.io/docs/api/domains/createDomain. Se a versão instalada não oferecer esse contrato, o adaptador reporta pendência; não tenta endpoints alternativos ou desativa TLS.

Sem a credencial, a publicação pelo link Askadia funciona e a tela orienta o administrador a adicionar o domínio em Domínios do serviço, porta 3000, HTTPS. Desvincular/trocar domínio retira imediatamente o vínculo no banco; a limpeza de mapeamentos antigos do proxy da hospedagem é administrativa. Não altera DNS no registrador nem transfere domínio.

## Matriz adicional

| Operação | Capacidade exigida no servidor/banco |
|---|---|
| Ler CRM e conversas Meta | `crm.read` na empresa |
| Assumir e responder Meta | `crm.write`, tomada válida e reserva |
| Campanhas e destinatários | autorização de campanhas vigente, com delegação de verba/aprovação preservada |
| Ler propostas/contas de anúncios | `marketing.read` |
| Gerar propostas e editar site | `marketing.write` |
| Autorizar contas de anúncios e domínio | proprietário da empresa |
| Publicar/retirar site | `content.approve` na empresa |
| Conteúdo público | snapshot explicitamente publicado; nunca rascunho/perfil/cofre |

Os novos cofres de credenciais e verificações externas só são acessíveis por funções `service_role` que revalidam o ator e a empresa. RLS impede leitura direta entre empresas e o cliente não tem escrita direta nas novas tabelas.

## Configuração e homologação externas

- Google Ads: `GOOGLE_ADS_CLIENT_ID`, `GOOGLE_ADS_CLIENT_SECRET`, `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_API_VERSION=v23`; `GOOGLE_ADS_LOGIN_CUSTOMER_ID` quando houver conta gerenciadora. Callback exato `https://askadia.com.br/api/connections/google/callback`, escopo `https://www.googleapis.com/auth/adwords`, acesso offline. Requer projeto OAuth e token de desenvolvedor aprovados. Seleção de conta é explícita.
- Meta: token atual com permissões de mensagens e tarefa MESSAGING na Página; Instagram profissional associado. App em desenvolvimento limita usuários/ativos de teste; acesso de clientes externos depende da revisão Meta. Consultar erros reais; conectar não garante cada permissão.
- Hospedagem: DNS do domínio de cada academia + integração administrativa Easypanel + emissão HTTPS. Nenhum site/contato/campanha real foi publicado/enviado para testar.
- Pacote aditivo: `.local/askadia-experiencia-sites.sql`, migrações 009–013, em transação. Depende de 001–008 anteriores. Não aplicar duas vezes. Sem remoção de cadastros; nenhuma campanha ativada por migração.

## Validação

Testes de persistência/RLS com PostgreSQL embutido e migrações reais: rascunho versus publicação, isolamento de arquivos/domínios, revogação, revisão otimista, vínculos de OAuth e cofres, seleção de destinatários/consentimento e idempotência. Testes de conteúdo escapado, esquema visual, URLs, calendário cruzando meses, métricas de respostas e conversas assinadas. Resultado final de `pnpm check` e implantação registrado em `docs/progress.md`.

### Complementos desta entrega
Upload múltiplo no onboarding: fila sequencial com progresso, limite individual de 10 MiB, erros por arquivo e preservação dos envios concluídos. Mapa é a visualização padrão e a lista uma alternativa. O fim do onboarding não força o resumo ao abrir a conversa.
Sites incluem comparação em molduras reais de desktop (1280 px) e celular (390 px), exportação com fotos embutidas e reserva de subdomínio por proprietário. Para *.askadia.com.br, configurar registro wildcard no Registro.br para o servidor e provisionar cada hostname com certificado via API Easypanel; o wildcard DNS não é, por si só, um certificado wildcard. A aplicação informa endereço reservado até a hospedagem estar configurada.

### Sites e catálogo visual
Meu site abre na prévia desktop/mobile; edição explícita e aba independente de domínio. Landing page com capa fotográfica, faixas na cor da academia, modalidades, galeria e contato. GPT-5 (`OPENAI_MODEL_SITE=gpt-5`) produz o conteúdo estruturado e seleciona IDs reais do catálogo; HTML permanece escapado e controlado. Nenhum depoimento/oferta é inferido de foto.
Gemini 3.5 Flash-Lite (`GEMINI_DESCRIPTION_MODEL`) descreve imagens por fila persistida (`IMAGE_DESCRIPTIONS_ENABLED=true`). Migração 014 adiciona metadados aos anexos; descrição e uso recomendado ficam internos. Imagens existentes também entram na fila. Uma imagem por ciclo, lease de cinco minutos, três tentativas no máximo; falhas preservam upload e não são apresentadas como análise concluída. PDFs não entram na análise visual. Designer recebe descrições dos materiais selecionados; site recebe catálogo com identificação e categoria. Credenciais ficam no servidor.
