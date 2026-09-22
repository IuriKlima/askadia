# Configuração e homologação de integrações

Ambiente atual: WEB_ORIGIN=http://127.0.0.1:3000; API interna 127.0.0.1:4000. Não usar localhost como origem alternativa durante autenticação.

| Provedor | Escopo | Implementação / evidência | Dependência e próximo teste |
|---|---|---|---|
| Supabase | Infraestrutura Askadia | SDK oficial Auth, SSR, RPC e Storage/RLS preparados; Auth/settings 200 em 21/09/2026 | Aplicar SQL; callback http://127.0.0.1:3000/auth/callback; recuperação com next=/auth/update-password; SMTP e duas contas reais |
| OpenAI | Infraestrutura Askadia | Catálogo; adapter indisponível | SDK Responses, schemas, modelo acessível, consumo, recusa e geração real |
| Gemini | Infraestrutura Askadia | Decisão vigente de imagens; ainda não integrado | SDK @google/genai, chave/modelo, imagem real e exportação validada |
| Google Maps/Places | Infraestrutura Askadia | Catálogo | APIs autorizadas, atribuição, restrição por origem, pesquisa real |
| Asaas | Infraestrutura Askadia | Catálogo, preço definido; sem cobrança | Sandbox, webhook autenticado, reconciliação; callback ainda não implementado |
| Resend | Infraestrutura Askadia | Catálogo, nenhum envio | Domínio/remetente autorizado e teste explícito |
| Hosting | Infraestrutura Askadia | Ausente | Provedor/limites/DNS, HTTPS e tenant por hostname |
| Meta Ads/Instagram/WhatsApp | Ativos do cliente | Catálogo; adapter indisponível | OAuth, revisão de app, contas elegíveis, callbacks ainda não implementados |
| Google Ads/GA4 | Ativos do cliente | Catálogo; adapter indisponível | OAuth, developer token, propriedades autorizadas, callbacks ainda não implementados |

Não existem URLs de webhook/OAuth operacionais para os provedores além do callback Supabase acima. Registrar rotas exatas somente quando implementadas. Não preencher chaves em campos públicos; .env é local e ignorado. Tokens individuais serão criptografados e associados à empresa.

Estados distintos: implementado, configurado, conexão validada, homologado, degradado, indisponível. Verificação de conexão não executa geração, envio ou campanha.

Para cada provedor futuro: verificar documentação oficial vigente antes de implementar, registrar permissões exatas, aprovação de conta/aplicativo, operação de smoke test e estratégia de reconciliação. Não extrapolar a homologação de uma operação para todo o provedor.
