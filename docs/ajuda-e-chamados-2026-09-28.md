# Ajuda e chamados no sistema

O botão Ajuda nos cabeçalhos abre uma conversa compacta no desktop e em tela cheia no celular, com rolagem apenas dentro da conversa. Disponível no onboarding, planos, estratégia, módulos da empresa, workspace e resultados. Não cobre o campo de resposta ou o botão de compra.

A busca usa registros públicos revisados da central de suporte, compartilhados com /suporte. Mostra a fonte de cada orientação, oferece temas quando a consulta é ambígua e encaminha dúvidas sem base suficiente. Pedir um humano ou marcar que a orientação não resolveu oferece chamado e WhatsApp. Esta etapa usa busca textual, sem LLM, acesso a logs privados ou custo de tokens; funciona antes de contratar o plano e não libera os agentes de marketing.

## Chamados

O usuário revisa assunto, descrição e, opcionalmente, as últimas oito mensagens antes de enviar. O protocolo e o histórico são persistidos no banco e aparecem em Meus chamados. Uma repetição da mesma solicitação não duplica o chamado ou a resposta. A tela consulta atualizações a cada 30 segundos enquanto está aberta e visível. Os cem comentários mais recentes aparecem no histórico; comentários anteriores permanecem no banco.

Equipe interna: Central de chamados em /admin e /acompanhamento/carteira. Administradores internos acessam todos; acompanhamento só acessa empresas atribuídas. Chamados sem empresa ficam com a administração. É possível responder e definir aberto, em atendimento, aguardando cliente ou resolvido. Nova mensagem do cliente reabre um chamado resolvido. Ações são auditadas; nenhuma notificação por e-mail ou WhatsApp é enviada automaticamente.

Permissões são revalidadas no servidor e no banco. Cliente só lê seus próprios chamados e, quando houver empresa vinculada, precisa manter acesso à empresa. Papel de suporte dentro de uma empresa não concede acesso à equipe interna. Tabelas não permitem escrita direta pelo cliente. Criação limitada a dez chamados por hora por autor; respostas limitadas a trinta por hora por autor/chamado. O histórico de ajuda só é armazenado com seleção explícita do cliente e nunca alimenta a busca de outros clientes.

## Implantação

Aplicar a migração incremental 202609280003_support_chat.sql após as anteriores e reimplantar API/web. O Dockerfile configura PUBLIC_SUPPORT_WHATSAPP com o número público fornecido pelo usuário, +55 (19) 99307-0799. O ambiente do Easypanel pode sobrescrever o número. A configuração local também foi atualizada; .env.example usa apenas um número fictício.

O link abre wa.me com uma saudação e, quando existir, o protocolo. Não transmite a conversa nem envia mensagem automaticamente. O cliente escolhe o envio no WhatsApp. Credencial da Evolution não é necessária para esse encaminhamento.

A central exige equipe interna provisionada para responder. A migração e a homologação remota continuam pendentes de acesso administrativo. A prévia local usa dados fictícios e não representa chamados reais.

## Validação

pnpm check aprovado: lint, tipos, 264 testes e todos os builds. Os oito cenários novos cobrem busca sem informação suficiente, destinos WhatsApp, autorização no proxy e banco, isolamento, carteira interna, revogação, idempotência, status versionado e limites de uso. Prévia fictícia compilada; inspeção visual não concluída porque os navegadores de teste não responderam. Aplicação do SQL e homologação no site publicado ainda pendentes.
