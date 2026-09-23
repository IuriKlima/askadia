# Site comercial Askadia

Entrega de 23/09/2026. Página inicial refeita para a solução de marketing de academias, preservando marca, tipografia do sistema, fundos claros, cinzas e detalhes de vidro. As duas landing pages têm argumentos e perguntas próprias.

| Rota | Objetivo |
|---|---|
| `/` | Apresentar a solução completa e encaminhar para o cadastro |
| `/lp/marketing-fitness` | Campanhas de aquisição focadas em estratégia, calendário e produção de conteúdo |
| `/lp/atendimento-fitness` | Campanhas focadas em atendimento, CRM e relacionamento com alunos |
| `/sobre` | Apresentação factual da proposta e princípios da Askadia |
| `/contato` | Canais comerciais configurados e orientação para suporte |
| `/suporte` | Central de orientações por assunto e canal direto quando configurado |
| `/sitemap.xml` | URLs públicas para descoberta por buscadores |

CTAs de começar usam `/login?modo=cadastro`, abrindo a criação de conta diretamente. Entrada normal e recuperação continuam preservadas. Não há alteração em permissões, banco ou cobrança. Criar cadastro não é apresentado como teste gratuito de prazo indefinido nem como assinatura contratada.

Prévia do produto e peça visual são exemplos ilustrativos identificados, construídos em HTML/CSS. Não usam dados privados, marcas de clientes, depoimentos ou resultados inventados. A copy não promete matrículas garantidas, envio social automático concluído, compatibilidade universal com gestão ou ativação automática de anúncios.

## Contato e suporte

Canais oficiais ainda precisam ser informados pelo proprietário. Variáveis públicas do servidor: `PUBLIC_SALES_WHATSAPP` (DDI e número), `PUBLIC_CONTACT_EMAIL`, `PUBLIC_SUPPORT_EMAIL` (usa o e-mail comercial quando não separado). Nunca assumir e-mail pessoal do proprietário como contato público. As páginas são dinâmicas para refletir o ambiente sem recompilar.

Quando um canal comercial está configurado, o formulário valida nome, academia, interesse e mensagem no navegador e prepara uma conversa no WhatsApp ou um rascunho no aplicativo de e-mail. Ele informa que o visitante conclui o envio por lá. Não apresenta sucesso de recebimento, não persiste lead no CRM e não dispara mensagens sozinho. O formulário de aquisição com persistência na carteira interna e medição de conversões do escopo mestre permanece uma etapa separada, não declarada concluída aqui.

Sem canais configurados, Contato mantém o caminho de cadastro e suporte, com indisponibilidade de atendimento direto explícita. A central de suporte tem orientações úteis mesmo sem e-mail configurado. Não há endereço ou telefone inventado, envio real de teste ou promessa de prazo de atendimento.

## Validação

Conferir desktop e celular, navegação entre as seis páginas, CTAs de cadastro, FAQ e ausência de transbordamento horizontal. `pnpm check` executa lint, tipos, testes existentes e builds; registrar resultado e deploy em `docs/progress.md`. Não cadastrar conta, enviar e-mail/WhatsApp ou ativar campanhas na validação.
