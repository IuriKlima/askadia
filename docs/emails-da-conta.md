# E-mails da conta Askadia

## Estado em 22/09/2026
13 modelos HTML prontos, em português, com identidade visual neutra da Askadia. Prévia inspecionada em desktop e 390 px, sem rolagem horizontal. Não foram enviados e-mails de teste.

O painel Supabase do projeto mostrou “Set up custom SMTP to edit templates”. Remetente padrão em uso; notificações de segurança desligadas. RESEND_API_KEY e EMAIL_FROM ausentes no ambiente local. Os modelos NÃO foram aplicados ao projeto remoto e o envio personalizado NÃO está ativo. É necessário configurar SMTP próprio e um remetente verificado antes de concluir. Nenhum plano pago foi contratado.

## Arquivos e manutenção
Fonte única: scripts/build-account-emails.mjs. Execute node scripts/build-account-emails.mjs após editar o conteúdo. Os HTMLs ficam em supabase/templates e auth-config.json contém assuntos, corpos e flags de ativação das sete notificações de segurança para a Management API. Esse JSON não contém segredos e só deve ser aplicado após SMTP disponível. Não confundir service_role com token da Management API.

| Modelo | Uso |
| --- | --- |
| confirmation | Confirmação do cadastro |
| recovery | Recuperação de senha |
| invite | Convite do Supabase Auth |
| magic_link | Acesso por link, se utilizado |
| email_change | Confirmação de alteração de e-mail |
| reauthentication | Código para operação sensível |
| password_changed_notification | Senha alterada |
| email_changed_notification | E-mail alterado |
| phone_changed_notification | Telefone alterado |
| identity_linked_notification | Método de acesso vinculado |
| identity_unlinked_notification | Método de acesso removido |
| mfa_factor_enrolled_notification | Verificação adicional cadastrada |
| mfa_factor_unenrolled_notification | Verificação adicional removida |

O layout usa tabelas de apresentação e estilos inline; não depende de JavaScript, fontes remotas, imagens externas nem rastreamento. Os links de ação usam a variável ConfirmationURL original. Reautenticação usa Token. Avisos de segurança apontam para o login oficial. Variáveis específicas são mantidas somente no modelo correspondente. Assuntos não incluem códigos ou tokens.

## Ativação
1. Escolher provedor SMTP e remetente. Sugestão apresentada ao proprietário: Askadia <conta@askadia.com.br>; ainda não confirmada.
2. Validar domínio no provedor, incluindo registros SPF/DKIM indicados por ele, preservando registros de e-mail existentes. Não inventar valores DNS.
3. Em Supabase → Authentication → Emails → SMTP Settings, configurar host, porta, usuário, senha SMTP e remetente verificado. Guardar credenciais somente no painel/cofre. Desabilitar rastreamento de links no provedor para preservar links de autenticação.
4. Aplicar assunto e HTML de cada modelo. Ativar os avisos de segurança correspondentes depois de salvar os modelos. A configuração do Supabase vale imediatamente e não exige rebuild da Askadia.
5. Homologar recebimento com destinatário autorizado: cadastro, recuperação e alteração de senha. Confirmar remetente, layout, destino correto e uso único dos links. Testes atuais não comprovam entrega em Gmail/Outlook nem reputação do domínio.

Convites de membros de empresas atualmente geram um link no módulo Equipe. Eles não são enviados pelo Supabase Auth; o template invite não transforma esses links em e-mails automaticamente. Avisos de cobrança e marketing não estão incluídos nesta alteração.

Referências: https://supabase.com/docs/guides/auth/auth-email-templates e https://supabase.com/docs/guides/auth/auth-smtp. Restrição de personalização em projetos gratuitos com SMTP padrão: https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier.

## Resend escolhido pelo proprietário
Em 22/09/2026 o proprietário escolheu configurar o Resend. Cadastro/login está aguardando conclusão na aba do navegador. A configuração planejada é remetente Askadia <conta@askadia.com.br>, domínio verificado no Resend e SMTP próprio no Supabase. A integração oficial Resend/Supabase pode preencher o SMTP, mediante autorização de acesso; a alternativa é SMTP manual. Ainda não há credencial de envio instalada nem domínio verificado nesta etapa.
Fontes: https://resend.com/docs/send-with-smtp e https://supabase.com/partners/resend.
