# Configurar busca de empresas no Google

1. Abra https://console.cloud.google.com/ e selecione o projeto da Askadia.
2. Em **Faturamento**, vincule uma conta ativa ao projeto.
3. Em **APIs e serviços → Biblioteca**, habilite **Places API (New)** e **Maps Embed API**.
4. Em **Credenciais → Criar credenciais → Chave de API**, crie a chave de servidor, restrita à **Places API (New)**. Na raiz `.env`, preencha `GOOGLE_PLACES_SERVER_KEY`. Não use restrição por site nessa chave; em produção, restrinja também aos IPs de saída do backend.
5. Crie outra chave, restrita à **Maps Embed API** e a sites autorizados: `http://127.0.0.1:3000/*` e `http://localhost:3000/*` para desenvolvimento. Preencha `GOOGLE_MAPS_BROWSER_KEY`. Acrescente o domínio HTTPS real ao publicar.
6. Reinicie a API e teste localização e concorrentes. Confira quotas e alertas de faturamento do projeto. Limites internos da Askadia também se aplicam.

Não coloque a chave do servidor em variável pública. Não é necessário colar as chaves no chat. A chave Gemini não ativa Places automaticamente, e a localização da empresa não exige geolocalização do dispositivo.

Enquanto não houver configuração, **Abrir busca no Google Maps** permite pesquisa externa sem chave; endereço e concorrentes são informados e confirmados manualmente na conversa. O link não importa resultados.

Fontes oficiais: [configuração Places](https://developers.google.com/maps/documentation/places/web-service/get-api-key), [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started).
