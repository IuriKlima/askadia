# Provisionamento interno e atualização incremental

1. Aplicar .local/supabase-setup.sql se a instalação inicial ainda não foi executada.
2. Aplicar .local/askadia-update.sql depois. Alternativamente aplicar as migrações 202609210003 e 202609210004 separadamente, em ordem. Não executar as duas alternativas.
3. Configurar URLs de Auth conforme identity-setup.md, confirmar e-mail e entrar em /workspace.
4. Criar um workspace garante a criação do perfil local. Contas internas também precisam de perfil. Provisionamento abaixo é exclusivamente do operador confiável via SQL Editor; nenhum usuário cliente pode executá-lo pela API.
5. Confirmar o UUID exato da conta no painel Auth antes de substituir o marcador abaixo. Não inferir proprietário da plataforma pelo primeiro cadastro, domínio de e-mail ou metadados enviados pelo usuário.

Exemplo de administração inicial (substituir UUID; não executado pelo agente):

```sql
begin;
insert into public.profiles(id,display_name)
select id,coalesce(raw_user_meta_data->>'name','Operador Askadia')
from auth.users where id='UUID_CONFIRMADO'::uuid and email_confirmed_at is not null
on conflict(id) do nothing;
insert into public.platform_staff(user_id,role)
select id,'platform_admin' from auth.users
where id='UUID_CONFIRMADO'::uuid and email_confirmed_at is not null;
commit;
```

Para acompanhamento, usar o mesmo procedimento com role='support'. Provisionamento global e alteração de papel interno por UI permanecem pendentes. Não é possível conceder platform_admin com um convite de cliente.

Acesse /admin com a conta provisionada. O botão Carteira permite atribuir ou remover profissionais de acompanhamento já provisionados. A pessoa acessa /acompanhamento/carteira e abre uma sessão explicitando o motivo.

O contexto interno atual é somente leitura de metadados/equipe/histórico/assinatura. Não concede acesso direto à tabela de contatos nem aprova conteúdo/gasto. Sessões duram 30 minutos (limite técnico, não duração comercial de encontros), revalidam carteira e papel no banco e são encerradas com “Encerrar e voltar à carteira”. Desativar platform_staff.active bloqueia sessões ainda abertas; remover atribuição também as encerra.

## Importação
No workspace, selecionar empresa → Rascunhos e importação. Ler do navegador ou escolher JSON exportado na prévia. Confirmar o destino. Limites técnicos do lote: 256 KiB, 100 contatos, 100 oportunidades e 30 peças. Para lotes maiores, dividir o arquivo mantendo contatos associados às oportunidades; os originais não são removidos.

Reimportar a mesma origem/ID não sobrescreve dados persistidos. Telefone normalizado deduplica contatos somente dentro da empresa. Mudança local posterior do mesmo ID não atualiza silenciosamente o registro do servidor. Etapas e aprovações locais não têm valor de autorização: oportunidades voltam a Novo e peças a rascunho v1.

Importação e leitura do acervo não ativam assinatura. Automações e geração exigirão plano, permissão e reserva de consumo, antes de efeitos externos.
