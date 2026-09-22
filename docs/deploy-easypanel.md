# Deploy da Askadia

Serviço: askadia/askadia no Easypanel. Fonte GitHub IuriKlima/askadia, main, caminho /, Dockerfile.

O container executa Next na porta 3000 e a API na porta interna 4000. O runner encerra ambos se um falhar; o healthcheck verifica API e login. O worker de protótipos não é executado. As credenciais são variáveis privadas no painel, nunca argumentos de build nem arquivos do Git. O cofre deve manter SECRETS_ENCRYPTION_KEY estável para abrir conexões existentes.

Ambiente de produção: NODE_ENV=production, WEB_ORIGIN=https://askadia.com.br, PORT=3000, API_PORT=4000, API_INTERNAL_URL=http://127.0.0.1:4000. Supabase, OpenAI, Gemini, Evolution e Meta usam as variáveis documentadas em .env.example. A automação de atendimento exige INBOX_AUTOMATION_ENABLED=true e SUPABASE_SERVICE_ROLE_KEY; cada canal continua desligado até seleção e salvamento do usuário.

Domínio principal https://askadia.com.br aponta para a porta 3000. Supabase Site URL usa o domínio público; callbacks limitados à rota /auth/callback em produção e no desenvolvimento local. O callback Meta é /api/connections/meta/callback. O domínio técnico do Easypanel também usa porta 3000; login deve ser feito pelo domínio principal para corresponder à origem autorizada.

Em 22/09/2026, o commit 746dad1 foi construído e implantado com sucesso pelo Easypanel. HTTPS / e /login responderam 200, e a API de inbox sem sessão respondeu 401. As migrações 202609220001–005 estão instaladas no Supabase; executar somente migrações posteriores em novas atualizações. Não há envio real a contatos nem publicação social nos testes.

As conexões de mensagens Meta/TikTok, publicador automático e homologação de insights continuam pendentes. O calendário atual organiza datas, detalha peças, gera criativos e recebe vídeos; datas planejadas não são agendamentos de envio. Não ativar consumidores de protótipos para contornar essas dependências.

## Campanhas e permissões Meta — 22/09/2026
Commit 6189426 compilado e implantado; Easypanel registrou Success às 17:52 UTC. Migrações 202609220006–008 aplicadas com autorização explícita e RLS confirmada nas três tabelas públicas. Login HTTPS respondeu 200; campanhas e ingestão sem autenticação responderam 401. MESSAGE_CAMPAIGNS_ENABLED=true salvo após autorização específica do proprietário. Nenhuma campanha foi ativada para teste. Operação do consumidor pela interface ainda em conferência.
