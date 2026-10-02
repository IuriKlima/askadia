# Configurar busca de empresas no Google

1. Abra https://console.cloud.google.com/ e selecione o projeto da Askadia.
2. Em **Faturamento**, vincule uma conta ativa ao projeto.
3. Em **APIs e serviços → Biblioteca**, habilite **Places API (New)** e **Maps JavaScript API**.
4. Em **Credenciais → Criar credenciais → Chave de API**, crie a chave de servidor, restrita à **Places API (New)**. Na raiz `.env`, preencha `GOOGLE_PLACES_SERVER_KEY`. Não use restrição por site nessa chave; em produção, restrinja também aos IPs de saída do backend.
5. Crie outra chave, restrita à **Maps JavaScript API** e a sites autorizados: `http://127.0.0.1:3000/*` e `http://localhost:3000/*` para desenvolvimento. Preencha `GOOGLE_MAPS_BROWSER_KEY`. Acrescente o domínio HTTPS real ao publicar.
6. Reinicie a API e teste localização e concorrentes. Confira quotas e alertas de faturamento do projeto. Limites internos da Askadia também se aplicam.

Não coloque a chave do servidor em variável pública. Não é necessário colar as chaves no chat. A chave Gemini não ativa Places automaticamente, e a localização da empresa não exige geolocalização do dispositivo.

Enquanto não houver configuração, **Abrir busca no Google Maps** permite pesquisa externa sem chave; a localização pode ser informada manualmente no questionário e a pesquisa de concorrentes fica identificada como pendente. O link não importa resultados.

Fontes oficiais: [configuração Places](https://developers.google.com/maps/documentation/places/web-service/get-api-key), [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started).

## Questionário com CEP — 02/10/2026

O cadastro inicial pede nome digitado e CEP de oito dígitos. O servidor pesquisa pelo nome e CEP via Places Text Search (New), solicita addressComponents e devolve a cidade/UF quando disponível. A escolha do estabelecimento continua explícita. Em falha ou ausência de cadastro, o cliente pode corrigir nome/CEP ou confirmar cidade/endereço manualmente. Não há geolocalização automática nem interpretação por IA nessa etapa.

O mapa e a lista de concorrentes aparecem juntos. A chave de navegador precisa permitir Maps JavaScript API e o domínio de implantação. A chave privada de Places nunca é enviada ao navegador. Sem mapa disponível, a lista e os links Google continuam utilizáveis; isso não deve ser apresentado como mapa homologado.

Aplicar supabase/migrations/202610020001_onboarding_questionnaire.sql depois das migrações anteriores, antes de implantar web/API. Não requer coluna ou tabela nova: amplia o contrato de fatos e a etapa persistida. Corrigir CEP invalida seleção local e pesquisa antiga; respostas de outras áreas são preservadas. Perfis antigos com cidade e perfis já confirmados mantêm continuidade.

Referências: [Text Search (New)](https://developers.google.com/maps/documentation/places/web-service/text-search) e [componentes de endereço](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#AddressComponent).
