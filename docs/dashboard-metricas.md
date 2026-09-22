# Dashboard Askadia — métricas e regras (21/09/2026)

Método: `askadia-dashboard-v1`. Cálculos em TypeScript no servidor, com centavos inteiros e arredondamento apenas na apresentação. A IA não calcula resultados financeiros.

## Escopo comum
`companyId,start,end,timezone,comparison,channel,account,campaign,mode,observationEnd,socialMode,section` formam o recorte. URL preserva o recorte; API e banco verificam empresa e permissões. Datas usam o fuso cadastrado da empresa. A troca de empresa limpa conta/campanha/canal; respostas antigas são canceladas e descartadas por geração.

O período anterior tem a mesma duração inclusive. O mês atual termina hoje. Comparação anual preserva datas do calendário e ajusta 29/02 para 28/02. Zero anterior não produz variação infinita. Coortes não recebem comparação automática com maturidades diferentes.

Conta/campanha/canal não são filtros universais: Trends não recebe esses filtros; campanhas não são presumidas para Instagram/site/CRM. Conta de anúncio sem vínculo financeiro não gera um falso zero de clientes. Filtros incompatíveis deixam o resultado indisponível. O leitor pode selecionar entre seis e oito KPIs.

## Dicionário
| ID | Unidade | Fonte | Definição / agregação |
|---|---|---|---|
| media | BRL | Anúncios ou custo manual identificado | Soma dos gastos compatíveis. Anúncios e lançamento manual de mídia não são somados entre si. |
| leads | pessoas | CRM Askadia | Contatos distintos nas oportunidades criadas no intervalo; não soma contatos repetidos. |
| customers | pessoas | Gestão/importação financeira | Clientes distintos com primeira aquisição, primeiro pagamento positivo na mesma data declarada de aquisição, histórico conhecido e indicação de não preexistência. |
| revenue | BRL | Gestão/importação financeira | Recebimentos líquidos dos clientes adquiridos no intervalo, com evidência de origem, menos estornos elegíveis. |
| cac_media | BRL/cliente | Mídia + gestão | Mídia / novos clientes atribuídos à mídia. |
| cac | BRL/cliente | Custos + gestão | (Mídia + demais custos de aquisição) / novos clientes pagantes. |
| roas | múltiplo | Mídia + gestão | Receita líquida atribuída à mídia / mídia. |
| margin | BRL | Gestão + custos variáveis | Receita líquida atribuída − custos variáveis correspondentes. |
| roi | % | Gestão + custos | (Margem atribuída − custos de aquisição) / custos de aquisição × 100. |
| ctr | % | Relatórios de anúncios | Soma de cliques / soma de impressões × 100; tipos de clique incompatíveis ficam separados. |
| cpc | BRL/clique | Relatórios de anúncios | Gasto total / cliques totais. |
| cpm | BRL/mil impressões | Relatórios de anúncios | Gasto total / impressões totais × 1.000. |
| engagementRate | % | Instagram | (Curtidas + comentários + salvamentos + compartilhamentos) / alcance; campos ausentes impedem cálculo. |
| trend interest | índice | Google Trends | Média dos pontos suficientes no mesmo lote, região, escala e calendário. Não é volume absoluto. |
| sessions, users, key_events | contagem | GA4 | Séries por dia/propriedade; usuários únicos não são somados entre dias. |
| clicks, impressions | contagem | Search Console | Série por recurso; cobertura da API pode ser parcial. |
| forms_received | contagem | Formulário instrumentado/importação | Envios efetivos informados pela fonte; clique de WhatsApp não equivale a formulário, conversa ou venda. |

Todos os cards expõem fórmula, bases, origem, qualidade e atualização; as fontes têm carimbos próprios. Não existe selo global de integração atualizada.

## Regra financeira
O regime implementado é **caixa realizado**. Competência não está disponível sem fonte de reconhecimento de receita.

Na visão operacional, clientes são adquiridos no intervalo selecionado e a receita é recebida nesse intervalo. Custos do período podem ter ciclo comercial diferente das aquisições. Receita dos alunos adquiridos anteriormente não entra no retorno de novas aquisições.

Na visão de coorte, a aquisição permanece no intervalo selecionado e recebimentos/estornos são acompanhados até `observationEnd`. Renovações desses clientes podem compor a receita acumulada, sem aumentar aquisições. Como ainda não há cadastro de alocação de custos à coorte, CAC/ROAS/ROI de coorte permanecem sem base. Não se transporta custo operacional automaticamente.

A atribuição v1 é **origem informada pela fonte com evidência declarada**, não um modelo automático de último toque. Canal desconhecido ou evidência vazia não atribui receita à mídia. Conversões de Meta/Google não entram no denominador de clientes. Cobertura exibe clientes com origem / clientes elegíveis. Não se afirma causalidade.

`netCents` já deve conter os descontos e deduções definidos na exportação: não se subtrai desconto novamente. Comissões/tributos devem ser classificados uma única vez, como aquisição ou custo variável. A API não consegue verificar uma classificação incorreta feita no arquivo de origem; a nota da importação e o rateio devem descrever a regra.

Outros custos ausentes são desconhecidos, não zero. Para declarar custo zero, informe registro de custo com zero e seu critério. Custos estimados deixam os indicadores afetados identificados como estimados. Nenhum gasto é distribuído automaticamente por campanha.

Estornos são eventos separados vinculados ao pagamento; correções preservam versões. Na série diária, o estorno aparece na data do evento. Na janela de coorte, um estorno tardio reduz o retorno acumulado quando incluído na observação. Histórico anterior permanece reprodutível pelo snapshot exportado. Estorno sem pagamento, acima do recebido, anterior ao pagamento ou com reversão de custo variável acima do original bloqueia os cálculos financeiros.

Fontes financeiras sobrepostas exigem conciliação: múltiplos fornecedores de pagamentos suspendem o consolidado. Custos adicionais podem vir de fonte distinta. Relatórios de anúncio duplicados na mesma plataforma/conta/campanha/data também suspendem o consolidado de mídia.

### Exemplo exclusivamente de teste
Mídia R$ 3.000; outros custos R$ 1.000; 20 clientes atribuídos à mídia; receita líquida R$ 10.000; custos variáveis R$ 3.000. Resultados testados: CAC mídia R$ 150, CAC completo R$ 200, ROAS 3,333…, margem R$ 7.000, ROI 75%. Nenhum desses registros é inserido na aplicação.

## Temporalidade e limites
- Instagram: publicação no período com métricas acumuladas até a coleta é diferente de atividade ocorrida no intervalo. Atividade exige agregado oficial com datas exatas. Não se subtraem snapshots lifetime e não se soma alcance único.
- Funil: apresenta as etapas atuais das oportunidades criadas no período. Não apresenta taxa histórica de passagem, mediana de tempo ou fechamento confirmado sem eventos/vínculos compatíveis. Matrícula CRM não comprova pagamento. Atendente não recebe agregados gerais; a atribuição individual do CRM está pendente.
- Trends: candidatos editoriais são separados das pesquisas medidas. O perfil de serviços precisa de confirmação auditada; cidade vem do cadastro. Candidatos de modalidades/benefícios não confirmados não são gerados. CSV deve declarar exatamente a região presente no cabeçalho. Escalas independentes não são combinadas, pontos insuficientes não viram zero e termos com calendários diferentes não recebem ranking comparável.
- Importação é uma declaração da fonte, não homologação automática do fornecedor. O motor rejeita tipos inválidos e sinaliza registros incompatíveis.
- Limite operacional inicial: 1.000 registros/importação e 10.000 fatos ou oportunidades/empresa por consulta. Acima disso o banco exige agregação paginada; não corta resultados silenciosamente.
- Ausência de dado, zero confirmado, falta de base, proibição de acesso, cobertura parcial e estimativa têm semânticas distintas. Revogação/saúde de conectores em produção dependem da ativação dos consumidores descrita em dashboard-integracoes.md.

## Relatórios
CSV executivo inclui memória de cálculo, cobertura, séries e tabelas de anúncios, Instagram, Trends, candidatos, site e funil. PDF privado usa a mesma consulta e mantém empresa, período, filtros, regime, metodologia, evidência, geração e auditoria. O PDF é textual e paginado; caracteres fora de Latin-1 são substituídos por '?' (limitação do gerador). Nenhum arquivo é publicado; download exige sessão e permissão financeira, e o snapshot fica em tabela com RLS. CSV neutraliza fórmulas iniciadas por =, +, -, @.
