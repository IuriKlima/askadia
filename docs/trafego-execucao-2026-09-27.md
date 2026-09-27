# Execução programada de anúncios — 27/09/2026

## Auditoria de partida

O sistema possui propostas de investimento, conexões por empresa e geração durável de criativos, mas não cria anúncios nas plataformas. A execução está sendo acrescentada com revisão versionada, orçamento total, programação, pausa e reconciliação de resultados incertos. Primeiros formatos: Meta com imagem e destino web; Google Pesquisa com anúncios responsivos. Outros objetivos dependem de adaptadores e homologação próprios.

O usuário autorizou implementação, migrações, deploy e validação real de geração. Não autorizou aprovar campanhas de clientes nem gastar verba em anúncios de teste. No navegador, Easypanel requer login; Google aberto não apresenta MCC da Askadia; configuração real depende dessas sessões e credenciais.

## Validação

pnpm check concluído com sucesso: lint, tipos, 236 testes em 27 arquivos e builds de API, worker e Next. Os 16 testes específicos de anúncios cobrem autorização, orçamento, programação, reconciliação e divergências externas. Aviso textual antigo da proposta ajustado e lint reexecutado no componente. Nenhuma campanha foi criada, ativada ou cobrada durante esta revisão.


## Implementação

Propostas são preparadas após a quinta aprovação estratégica. Um orçamento único, explícito em BRL no perfil, permite distribuir o investimento por 30 dias; intervalos, valores diários, anuais, moeda estrangeira e respostas ambíguas bloqueiam a preparação com uma tarefa. Aprovação estratégica não autoriza gasto. A revisão final inclui conta, criativo, texto, destino, raio, orçamento, CPC no Google, início, fim e fuso da conta.

O worker de preparação é separado do agendador, para chamadas de IA não atrasarem ativações. Há até três gerações de redação por execução. A API e o banco verificam empresa, permissão ads.approve e teto da delegação sobre o plano inteiro. Edição anterior à criação invalida a versão aprovada. Depois que objetos existem na plataforma, pause/cancele e use uma nova proposta. Uma conta pausada diretamente no provedor não é reativada automaticamente pelo monitor.

Meta: campanha OUTCOME_TRAFFIC, imagem privada aprovada, anúncio de link para site, conjunto com orçamento vitalício, público adulto geográfico e feeds Facebook/Instagram. Toda a hierarquia nasce pausada. Na programação, anúncio e conjunto são habilitados primeiro e campanha por último, com nova conferência da aprovação. Google: duração de 3 a 90 dias, orçamento CUSTOM_PERIOD/totalAmountMicros, Pesquisa, idioma português, presença na região, proximidade por coordenadas reais do Places, palavras-chave em frase, CPC máximo explícito e anúncio responsivo. Uma mutação atômica cria a campanha pausada e seus recursos; ativação depende da programação. Não há conversão silenciosa de orçamento total em diário.

Diário privado de passos, hash da requisição, lease e identificadores externos persistidos. Repetição de um passo concluído reutiliza o ID. Resposta perdida provoca consulta pelo identificador determinístico; quando a consulta não comprova o resultado, a execução permanece em reconciliação e não cria outro objeto. Um resultado incerto não significa que a plataforma descartou a operação. Erros definitivos permitem nova tentativa limitada pela aprovação e período originais. Status são consultados aproximadamente a cada cinco minutos; a interface mostra a última consulta, sem alegar tempo real instantâneo.

Erros explícitos de saldo insuficiente geram alerta destacado em Início/Campanhas e link de faturamento. Falha de pagamento, restrição, autorização e saldo insuficiente têm classificações distintas. Nenhum valor de AdAccount.balance é tratado como crédito disponível. A regularização permite retomada automática dentro da programação aprovada; passado o término, a campanha é encerrada. Pausa não confirmada gera alerta urgente para conferir a plataforma.

O manager ID do Google é associado à conexão da empresa e usado ao consultar contas filhas. O token de desenvolvedor e OAuth continuam no servidor; nenhum segredo é enviado à interface ou aos modelos.

## Evidências reais e limites

Geração OpenAI executada em 27/09/2026: GPT Image 2.5 Sunburst, high, 1536×1920, PNG de 2.871.589 bytes. Uso reportado: 92 tokens de entrada e 2.257 de saída. Resultado inspecionado visualmente em .local/real-generation/askadia-validation.png; somente peça conceitual identificada, não publicada. Esse teste homologa a chamada direta do adaptador local, não prova que o worker está implantado.

Prévia React isolada, sem acesso a provedores: revisão → versão nova → aprovação → estado de criação; pausa; alerta de saldo; leitura no celular em 390 px sem overflow horizontal. Dados fictícios visivelmente identificados. A imagem demonstrativa foi gerada na validação real, sem representar instalações ou resultados de clientes.

Consulta remota de leitura: / e /login HTTP 200. As tabelas anteriores de site, propostas e preparação editorial existem; company_launch_jobs, company_instagram_watches, company_marketing_approvals, company_visual_jobs e company_ad_executions retornaram PGRST205. Nenhuma migração deste pacote foi aplicada nesta consulta.

Bloqueios externos: Easypanel sem sessão; Supabase aberto em marketing@alfafitness.com.br sem o projeto da Askadia; conta Google aberta sem MCC Askadia e pesquisa de projetos sem resultado Askadia. OAuth e developer token Google Ads não estão no .env. Nenhuma credencial de outro produto foi reaproveitada. É necessário usar a conta/projeto correto, OAuth web com callback https://askadia.com.br/api/connections/google/callback, escopo adwords, token de desenvolvedor aprovado para produção e eventual aprovação do projeto Cloud exigida pela API. Esses acessos não podem ser declarados configurados sem evidência.

Nenhuma campanha real foi criada/ativada, nenhuma mensagem foi enviada e nenhum conteúdo foi publicado nos testes. Adaptadores de anúncio implementados, homologação real pendente. Esta entrega não acrescenta Performance Max, YouTube, Display, objetivos Meta de conversão/lead form/WhatsApp, publicador social nem vídeo automático.

## Implantação

Pacote local .local/askadia-update-2026-09-27.sql inclui as cinco migrações novas em uma única transação e recusa reaplicação. Aplicar no projeto correto, conferir RLS/RPCs e preservar a chave de cofre. Mesclar .local/deploy-env-update-2026-09-27.env ao ambiente atual, sem substituir segredos ou configurações já existentes. Habilitação do worker depende de ADS_EXECUTION_ENABLED=true. Atualizar o serviço askadia/askadia do Easypanel depois do banco; verificar build, saúde, autenticação, jornada, criativos e status de campanhas. Não aprovar campanhas de clientes como teste de deploy.

## Referência de compatibilidade

Google documenta orçamento total para Pesquisa com duração mínima de três dias e máxima de 90: https://support.google.com/google-ads/answer/10486938?hl=en. A criação usa Manual CPC com teto explícito. A elegibilidade retornada pela plataforma é separada da comprovação de impressões/entrega. Homologar na conta autorizada antes de declarar funcionamento externo.

## Conferência final

git diff --check sem erros. Verificador dos 81 arquivos alterados/novos não encontrou valores secretos do ambiente. Migrações executadas apenas nos testes PostgreSQL locais; pacote de implantação atualizado com o mínimo de três dias do Google. Aprovação final de campanha segue sendo uma ação explícita do cliente, vinculada à versão. Não houve push, migração remota ou deploy nesta entrega, pois os acessos ainda não foram disponibilizados.
