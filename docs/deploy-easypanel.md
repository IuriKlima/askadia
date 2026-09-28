# Deploy da Askadia

Serviço: askadia/askadia no Easypanel. Fonte GitHub IuriKlima/askadia, main, caminho /, Dockerfile.

O container executa Next na porta 3000 e a API na porta interna 4000. O runner encerra ambos se um falhar; o healthcheck verifica API e login. O worker de protótipos não é executado. As credenciais são variáveis privadas no painel, nunca argumentos de build nem arquivos do Git. O cofre deve manter SECRETS_ENCRYPTION_KEY estável para abrir conexões existentes.

Ambiente de produção: NODE_ENV=production, WEB_ORIGIN=https://askadia.com.br, PORT=3000, API_PORT=4000, API_INTERNAL_URL=http://127.0.0.1:4000. Supabase, OpenAI, Gemini, Evolution e Meta usam as variáveis documentadas em .env.example. A automação de atendimento exige INBOX_AUTOMATION_ENABLED=true e SUPABASE_SERVICE_ROLE_KEY; cada canal continua desligado até seleção e salvamento do usuário.

Domínio principal https://askadia.com.br aponta para a porta 3000. Supabase Site URL usa o domínio público; callbacks limitados à rota /auth/callback em produção e no desenvolvimento local. O callback Meta é /api/connections/meta/callback. O domínio técnico do Easypanel também usa porta 3000; login deve ser feito pelo domínio principal para corresponder à origem autorizada.

## Checkout de teste após o deploy — 28/09/2026

O `.env` local não é enviado na imagem. A API só permite escolher e confirmar planos com `CHECKOUT_MODE=test`. Sem esse valor, os cartões aparecem, mas os botões ficam desabilitados e a tela informa “Contratação disponível em breve”. Não é um problema de preço, rolagem ou cache do navegador.

Nesta fase de homologação autorizada, o Dockerfile declara `CHECKOUT_MODE=test` explicitamente para os novos deploys. Uma variável configurada no Easypanel tem precedência: no serviço **askadia/askadia → Environment**, mescle `CHECKOUT_MODE=test` às variáveis existentes, salve e implante novamente. Não substitua o restante do ambiente. Para desativar novas simulações, use `CHECKOUT_MODE=disabled` e reimplante.

O checkout permanece identificado como teste, sem cartão ou cobrança real. A simulação exige usuário autorizado, onboarding confirmado e aceitação do plano; a confirmação no servidor libera sete dias de acesso à IA somente para aquela empresa. Esta mudança não ativa gateway de pagamento, anúncios nem mensagens. A chave `SUPABASE_SERVICE_ROLE_KEY` continua necessária na API para confirmar o teste.

Validação após implantação: reabra a seleção de planos com a conta responsável, confira os botões habilitados e a indicação “Teste sem cobrança”, selecione mensal/semestral e confira o resumo do checkout. Não confirme o pagamento como simples teste de deploy: a confirmação libera tarefas de IA. A correção de ambiente não exige SQL novo; as migrações de comércio `202609270003` e preços `202609280001` precisam já estar aplicadas.

Em 22/09/2026, o commit 746dad1 foi construído e implantado com sucesso pelo Easypanel. HTTPS / e /login responderam 200, e a API de inbox sem sessão respondeu 401. As migrações 202609220001–005 estão instaladas no Supabase; executar somente migrações posteriores em novas atualizações. Não há envio real a contatos nem publicação social nos testes.

As conexões de mensagens Meta/TikTok, publicador automático e homologação de insights continuam pendentes. O calendário atual organiza datas, detalha peças, gera criativos e recebe vídeos; datas planejadas não são agendamentos de envio. Não ativar consumidores de protótipos para contornar essas dependências.

## Campanhas e permissões Meta — 22/09/2026
Commit 6189426 compilado e implantado; Easypanel registrou Success às 17:52 UTC. Migrações 202609220006–008 aplicadas com autorização explícita e RLS confirmada nas três tabelas públicas. Login HTTPS respondeu 200; campanhas e ingestão sem autenticação responderam 401. MESSAGE_CAMPAIGNS_ENABLED=true salvo após autorização específica do proprietário. Nenhuma campanha foi ativada para teste. Operação do consumidor pela interface ainda em conferência.

## Ajuda e chamados — 28/09/2026

Aplicar `202609280003_support_chat.sql` depois das migrações anteriores. Reimplantar API/web para disponibilizar a central interna e o chat de ajuda. A imagem declara `PUBLIC_SUPPORT_WHATSAPP=5519993070799`, número público informado pelo responsável. O ambiente do Easypanel tem precedência. Teste a consulta de ajuda, o link WhatsApp sem enviar mensagem e um chamado de homologação em empresa de teste. Respostas são feitas em `/admin` ou `/acompanhamento/carteira`, conforme a carteira da equipe interna. Ver `docs/ajuda-e-chamados-2026-09-28.md`.
