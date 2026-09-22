# Identidade e isolamento — etapa 2

## Situação
Código de autenticação, gestão de empresas/membros e políticas implementado. Conexão ao Auth hospedado validada (HTTP 200); estrutura do banco e homologação com contas reais ainda pendentes.
A prévia local continua disponível em /preview. Ela não sincroniza dados automaticamente com contas autenticadas.

## Configuração de homologação
1. Criar/selecionar um projeto Supabase de homologação.
2. No SQL Editor do projeto, executar o arquivo local .local/supabase-setup.sql, que reúne as três migrações em uma transação. Ele bloqueia objetos conflitantes e uma segunda execução. Alternativamente, revisar e aplicar os três arquivos de supabase/migrations em ordem. Não executar as duas opções. Não executar em um banco existente sem verificar conflitos de tabelas e políticas.
3. Copiar .env.example para .env na raiz. Preencher SUPABASE_URL e SUPABASE_ANON_KEY com a URL e chave pública anon/publishable do projeto. **Não usar service_role/secret key como anon key.**
4. WEB_ORIGIN deve ser a origem exata usada no navegador: padrão http://127.0.0.1:3000. Não alternar com localhost durante um fluxo de login/recuperação.
5. API_INTERNAL_URL aponta para a API Nest local (padrão http://127.0.0.1:4000).
6. No Supabase Auth, configurar Site URL para WEB_ORIGIN e autorizar WEB_ORIGIN/auth/callback e o retorno de recuperação com next=/auth/update-password. Manter confirmação de e-mail habilitada.
7. Configurar SMTP autorizado antes de testar entrega real de e-mails. Nenhum e-mail foi enviado durante a implementação.
8. Reiniciar pnpm dev após mudar ambiente. Entrar em /login.

Web, API e worker leem o .env da raiz. Nenhuma chave é enviada por NEXT_PUBLIC. A aplicação de gestão não precisa de uma chave de serviço.

## Fluxo
- Login, cadastro, recuperação e alteração de senha usam o cliente oficial Supabase no servidor.
- Sessão em cookies HttpOnly, SameSite=Lax e Secure em produção; tokens não ficam no localStorage.
- Proxy atualiza cookies; getUser valida a identidade. Dados pessoais não entram em cache compartilhado.
- A web encaminha operações ao Nest somente após validar sessão. A API revalida o token e opera com JWT do usuário, mantendo RLS.
- Métodos mutáveis verificam a origem exata. Rotas encaminhadas têm lista de métodos/caminhos permitidos.
- Redirecionamento do callback aceita somente /workspace e /auth/update-password.
- A produção da API continua bloqueada até homologação e decisão de lançamento.

## Empresas
O proprietário cria o workspace e empresas. Empresa nasce em draft, sem contrato. A criação concede explicitamente admin ao criador daquela empresa.
Proprietário do workspace pode gerenciar metadados e equipe, mas não recebe acesso automático a dados operacionais de outras empresas.
Edição não permite mover empresa de workspace nem alterar status de cobrança. Arquivamento preserva dados e bloqueia leitura operacional; restaurar não ativa assinatura. Arquivar não significa cancelar uma assinatura.

## Membros e convites
Administradores da empresa e proprietário do workspace gerenciam acessos. A função de aprovador é uma concessão explícita.
Convites têm 7 dias de validade, e-mail específico, token aleatório composto por dois UUIDs v4, hash SHA-256 no banco e uso único. Um novo convite revoga o anterior não aceito para o mesmo e-mail/empresa.
O token completo só aparece ao criar o convite; o link usa fragmento #invite para não colocá-lo em logs de requisição. Não registrar nem compartilhar links indiscriminadamente.
O destinatário entra com o e-mail confirmado e aceita o convite. Se criar conta primeiro, pode precisar reabrir o convite após confirmar o e-mail.
Nenhum envio de convite por e-mail está implementado: há cópia manual do link.
Remoção de emissor invalida convites pendentes. A última pessoa administradora não pode ser removida ou rebaixada. Alterações registram ator, empresa e data.

## Banco e Storage
RLS é aplicado a todas as tabelas. Escritas de identidade usam funções transacionais com search_path vazio, validação explícita e privilégios limitados.
Contatos e oportunidades são somente leitura nesta etapa, para admin/attendant com vínculo ativo; mutations do CRM conectado vêm na etapa 4.
Bucket company-assets é privado. Prefixo obrigatório company_id/arquivo. Admin envia/edita/remove; admin, approver e support leem. O tamanho de 10 MiB e tipos permitidos são salvaguardas técnicas provisórias, não franquias comerciais.
Validação binária de uploads, URLs temporárias e UI de arquivos são da etapa 5. Nenhum upload foi executado.
Realtime não é consumido por esta interface. Assinaturas de canais e comportamento de desconexão por revogação ainda precisam de implementação/prova real antes da etapa ser considerada totalmente homologada.

## Verificação
pnpm check executa testes do domínio local, HTTP Nest com identidade controlada e SQL real via PostgreSQL/PGlite.
Os testes SQL usam fixtures mínimas de auth/storage. A extensão pgcrypto da migração base é omitida somente no teste, pois as funções utilizadas (gen_random_uuid, sha256) são nativas.
Isso valida SQL, grants, RLS, transações e relacionamentos; **não valida o serviço hospedado de Auth, PostgREST, Storage nem entrega SMTP**.
Antes de concluir a homologação: duas contas reais, duas empresas no mesmo workspace e uma em outro; testar acesso cruzado por API REST, banco e download; retirar membro com sessão ativa; confirmar expiração/revogação do convite e recuperação de acesso; verificar políticas existentes adicionais que possam ampliar acesso.

## Atualização do prompt mestre
As regras de proprietário foram atualizadas: ele acessa a operação das empresas do seu workspace. Gerente de marketing, delegações, carteira interna e planos são definidos na migração 202609210003. Importação assistida está na 202609210004. Ver docs/internal-access-setup.md e docs/askadia-progresso.md; essas decisões substituem descrições conflitantes anteriores deste documento.
