# Entrega da jornada — 21/09/2026

## Implementação

Criação atômica e idempotente de rascunho abre o onboarding sem cobrança. Conversa, fatos estruturados, anexos privados e versões confirmadas ficam no Supabase. Resumo editável, retomada, conflitos de revisão e empresas independentes são tratados no servidor. O perfil confirmado alimenta o briefing e o adaptador de estratégia OpenAI. Menu e entrada variam por contexto, papel e etapa. Administração e acompanhamento continuam separados; reuniões guardam participantes, decisões, responsáveis e próximas ações.

CRM persistente e tomada humana foram acrescentados em migração própria. Notas são internas; não há envio real de WhatsApp. A tomada humana cancela trabalhos pendentes e a futura execução deve revalidar revisão, modo, vínculo e versão do perfil.

## Validação

- `pnpm check`: código 0; lint, tipos, **114 testes**, builds web/API/worker. Após ajustes finais de texto e link Maps: tipos API/web e **22 testes** da jornada passaram.
- PostgreSQL/PGlite: idempotência, revisões concorrentes, isolamento, cinco papéis, revogação, anexos, limites, aprovação vinculada à geração, carteira interna e tomada humana. HTTP: autenticação, autorização, validação e persistência. Proxy sem sessão: 401; escrita de origem externa: 403.
- Navegador autenticado/Supabase: área isolada `Validação técnica Askadia`, adicionar empresa → chat; resposta com seis fatos; recarga mantém histórico/etapa; localização manual → concorrentes pendentes → ausência de referências; confirmar sem complementos → início da mesma empresa → briefing salvo da versão 1. PNG fictício privado persistiu após recarga.
- Perfil existente reaproveita nome/tipo. Revisão desktop e celular 390×844; edição por teclado. Cinco usuários reais em dispositivos distintos e canais externos ainda não homologados. Nenhum cadastro preexistente foi renomeado ou excluído. A empresa fictícia foi arquivada pela interface, com confirmação de preservação dos dados; a área de validação permanece identificada. A aba foi devolvida ao onboarding da Gaviões Varginha.

## Dependências

1. Migração 005 executada com sucesso pelo usuário. Migração 006: `.local/askadia-atendimento.sql` pronta, execução remota ainda sem confirmação; necessária ao CRM.
2. OpenAI: novo teste real da interpretação fictícia concluído com sucesso (nome, cidade e tipo; 359 tokens). Bloqueio anterior de crédito resolvido para esse teste. Geração completa de estratégia ainda não homologada.
3. Gemini Nano Banana Pro (`gemini-3-pro-image`): metadados acessíveis; duas tentativas fictícias retornaram **429, free tier com limite zero**. Nenhuma imagem gerada. Teste reproduzível em `.local/test-gemini-image.mjs`; não equivale a estúdio de produção conectado.
4. Google Places: chave do servidor ativada e pesquisa real validada com HTTP 200. Chave própria do Maps Embed ainda ausente: mapa incorporado pendente, link externo disponível. Resultados precisam de confirmação do cliente. Configuração em `google-places-configuracao.md`.
5. Evolution: URL, chave, instância e webhook ausentes; transporte e consumidor ainda por implementar/homologar. Sem mensagens a clientes.
6. Geração visual em produção, editor/calendário persistente completo, publicação, execução de mídia, cobrança e automações mensais permanecem etapas de implementação. O acervo/importação e dashboard existentes foram reutilizados. Nenhuma publicação, anúncio ou contratação feita nos testes.

Mapa de navegação, matriz de permissões e contrato: `jornada-contrato.md`. Auditoria de arquivos/rotas: `jornada-auditoria.md`. A reorganização não representa conclusão de toda a agência autônoma.
