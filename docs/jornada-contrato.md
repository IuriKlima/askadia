# Contrato da jornada e perfil da empresa

## Regras
- Rascunho persistido e idempotente: requestId + ator, workspace autorizado; workspace inicial criado na mesma transação quando necessário.
- Estado no servidor, independente por companyId; revisão monotônica e optimistic locking impedem respostas atrasadas sobrescreverem outra versão.
- Fatos estruturados com valor, estado (informado/desconhecido/adiado), origem, responsável e data. Sugestão da IA não é confirmação.
- Ordem: identidade → localização confirmada → concorrentes locais revisados → referências → entrevista por lacunas → resumo → confirmação.
- Mínimo: nome/tipo, cidade ou região de atuação confirmada, serviços, público e objetivo informados; revisão de concorrentes/referências pode registrar indisponibilidade ou ausência; confirmação explícita do perfil. Material visual, integrações e campos complementares podem ficar pendentes.
- Uma versão confirmada é imutável. Editar reabre rascunho; confirmar novamente cria nova versão e sinaliza materiais existentes para revisão, sem alterar aprovações.
- Anexos privados, autorização revalidada ao receber/abrir; JPEG, PNG, WebP, PDF até 10 MiB como limite técnico inicial. Sem SVG executável ou URL arbitrária extraída no servidor.
- Perfil confirmado é a única entrada para preparar estratégia e briefings. Perfil em edição não substitui silenciosamente a versão usada por agentes.
- IA indisponível: perguntas guiadas e correção manual, com estado explícito. Google indisponível: localização manual, pesquisa pendente e concorrentes indicados pelo cliente.
- Resultados do Google são consultados ao vivo; persistir somente place IDs e dados fornecidos pelo usuário. Sem cache indevido de conteúdo Places.

## Navegação
Raiz pública /; autenticação /login; resolução de contexto /entrada; gestão de negócios /workspace; jornada por empresa /empresa/[id]. Dentro da empresa: Início; Planejamento (Agentes, Estratégia); Conteúdo (acervo existente); Aquisição (CRM autorizado); Resultados (dashboard existente); Empresa (perfil/marca, equipe e assinatura quando autorizado). Recursos ainda ausentes mostram dependência real no contexto, sem páginas vazias. Admin /admin e acompanhamento /acompanhamento/carteira continuam separados; /operacao/[sessão] conserva operador real.

## Matriz de permissões
| Perfil | Entrada | Perfil/onboarding | CRM | Assinatura | Aprovação |
|---|---|---|---|---|---|
| Administrador Askadia | /admin | Contexto interno auditado | Apenas capacidade autorizada | Administração global ainda em implantação | Não automática |
| Acompanhamento | carteira atribuída | Revisão em sessão interna | Apenas capacidade autorizada | Não | Só delegação |
| Proprietário | empresas | Editar/confirmar nas próprias empresas | Sim | Por empresa | Sim |
| Marketing | empresa atribuída | Editar/confirmar | Por delegação | Não | Por delegação |
| Atendente | atendimento/CRM | Não | Empresa atribuída | Não | Não |

Papéis legados permanecem compatíveis. Convites de cliente nunca criam equipe interna. Interfaces usam capabilities; API/RLS/arquivos revalidam o vínculo atual.

## Interfaces e limites

`POST /api/onboarding/companies` recebe `requestId` e `workspaceId` autorizado ou nulo; retorna o identificador do rascunho e abre o chat. `/companies/:id/answers` recebe revisão, nonce, mensagem, patch validado e ação controlada. Texto e fatos são persistidos na mesma transação. Campos permitidos estão em `profileKeys`, no contrato TypeScript. Mesmo sem IA, respostas rotuladas podem preencher múltiplos assuntos e desconhecidos permanecem explícitos.

`/companies/:id/places` devolve opções atuais com fontes, nunca conexão fictícia. `/website` extrai sugestões de páginas públicas HTTPS via ferramenta de pesquisa e exige confirmação do cliente. `/strategy` persiste briefing da versão confirmada; `/strategy/generate` chama OpenAI; `/strategy/approve` exige capacidade e geração atual. Estratégia contém propostas de anúncios, calendário e 20 palavras-chave; aprovação da estratégia não libera verba nem publicação.

`/attachments/:id` revalida acesso em upload e download; não entrega URL pública ou assinada reutilizável depois da revogação. Limite inicial de 50 arquivos/100 MiB por empresa, 10 MiB por arquivo. Limites de homologação por dia/empresa: 40 interpretações, 10 pesquisas Places, 2 estratégias. A migração 006 acrescenta teto diário por conta de 100/30/4, respectivamente, para evitar multiplicação por rascunhos. Esses tetos técnicos não são franquias comerciais definitivas.

CRM e caixa de entrada reutilizam contatos/conversas da empresa e exibem ausência de canal conectado. Notas internas não são mensagens enviadas. Eventos da futura Evolution devem localizar a empresa pela instância validada no servidor; nunca aceitar companyId arbitrário do remetente. Antes de envio, o futuro consumidor precisa verificar revisão da conversa, modo IA, vínculo vigente e versão do perfil. Tomada humana invalida jobs já enfileirados ou reservados.
