# Projeção de IA por cliente — 27/09/2026

Atualizada após a decisão do cliente: usar OpenAI também para criar e editar imagens. O cenário anterior com Gemini foi substituído. Estimativa de engenharia, não consumo medido de produção. Preços Standard por API, sem descontos de cache, Batch/Flex ou créditos grátis. Cotação PTAX venda de 25/09/2026: USD 1 = BRL 5,1991. A taxa de cobrança, spread e tributos podem diferir.

## Tarifas e premissas

| Modelo | Entrada por milhão de tokens | Saída por milhão de tokens |
| --- | ---: | ---: |
| GPT-6 Astra | USD 10 | USD 50 |
| GPT-6 Sol | USD 2 | USD 10 |
| GPT-6 Luna | USD 0,10 | USD 0,50 |

Tokens de saída incluem raciocínio faturado. Contexto curto e sem cache; os turnos contam o contexto reenviado. GPT Image 2.5 Sunburst cobra USD 5/milhão de tokens de texto de entrada, USD 8/milhão de imagem de entrada e USD 30/milhão de imagem de saída. São classes de token diferentes. O gerador usa a Images API diretamente, sem uma chamada adicional ao Astra para executar a imagem.

Na calculadora oficial, consultada pela interface em 27/09, com GPT Image 2.5 e qualidade high:

| Dimensão usada | Tokens de saída estimados | Custo somente da saída |
| --- | ---: | ---: |
| 1536 × 1920, feed 4:5 | 2.257 | USD 0,06771 |
| 2048 × 1152, horizontal | 1.413 | USD 0,04239 |
| 1792 × 1792, quadrado | 3.002 | USD 0,09006 |

Esses valores não incluem entrada de texto/fotos nem refações, e não são uma medição do Sunburst em produção. A própria documentação informa que o consumo varia por modelo, qualidade e imagens. Adotamos USD 0,20 por geração como premissa conservadora de planejamento, não tarifa fixa. Carrossel de cinco páginas exige cinco gerações; editar ou variar é outra chamada. O número de gerações abaixo já inclui refações. Custos reais devem ser calibrados pelo usage retornado; novos jobs de site/campanha guardam esse objeto quando disponível, sem fabricar contagens ausentes.

Pesquisa web OpenAI: USD 0,01 por chamada, mais tokens de conteúdo, incluídos nos volumes de entrada estimados. Coletas periódicas de dados não precisam chamar o modelo caro a cada consulta: analisar mudanças relevantes ou conjuntos consolidados. Tarifas de APIs de dados estão fora do cálculo de IA.

## Cliente padrão mensal

Oito posts: quatro imagens e quatro carrosséis de cinco páginas = 24 artes; seis criativos de campanhas; quatro edições de fotos. São 34 resultados desejados, orçados como 50 gerações ao incluir variações/refações. Mil respostas de atendimento, com média hipotética de 5.000 tokens de entrada e 300 de saída por resposta; não significa mil conversas completas. Trinta buscas. Estratégia/análises/propostas: 100 mil entrada + 60 mil saída/raciocínio Astra. Copy/revisões/datas: 200 mil entrada + 60 mil saída Sol.

| Componente | Consumo estimado | USD/mês | BRL/mês |
| --- | --- | ---: | ---: |
| Astra | 100 mil entrada + 60 mil saída | 4,00 | 20,80 |
| Sol | 200 mil entrada + 60 mil saída | 1,00 | 5,20 |
| Luna | 5 milhões entrada + 300 mil saída | 0,65 | 3,38 |
| GPT Image 2.5 Sunburst | 50 gerações × USD 0,20 | 10,00 | 51,99 |
| Busca web | 30 chamadas | 0,30 | 1,56 |
| Total | | 15,95 | 82,93 |
| Total com reserva operacional de 30% | | 20,74 | 107,80 |

A reserva cobre variabilidade, além das refações já contadas; não é uma taxa do provedor nem uma alíquota tributária. Reservar aproximadamente BRL 110 por cliente/mês no cenário padrão. Se o custo observado por geração variar de USD 0,15 a USD 0,35, o mesmo pacote fica entre BRL 90,91 e BRL 158,49 com a reserva. Essa faixa é uma simulação de sensibilidade, não intervalo garantido.

## Escala e primeiro mês

| Cenário | Respostas/mês | Gerações de imagem | USD estimado | BRL estimado | BRL com reserva 30% |
| --- | ---: | ---: | ---: | ---: | ---: |
| Enxuto | 200 | 25 | 7,48 | 38,89 | 50,56 |
| Padrão | 1.000 | 50 | 15,95 | 82,93 | 107,80 |
| Intenso | 6.000 | 150 | 48,40 | 251,64 | 327,13 |

Implantação adicional: Astra 80 mil entrada/50 mil saída; Sol 80 mil/30 mil; Luna 200 mil/50 mil; 12 gerações; 30 buscas. USD 6,505 / BRL 33,82 antes da reserva; BRL 43,97 com reserva. Primeiro mês padrão total: BRL 151,77 com reserva. São consumos adicionais ao mês regular, sem contar duas vezes a produção mensal; não são horas de implantação humana.

Volumes e resultados sem arredondamento estão em projecao-custos-ia-2026-09-27.json. Fórmula: (entrada × tarifa_entrada + saída × tarifa_saída) / 1.000.000 + gerações × premissa_por_imagem + buscas × tarifa_busca. Converter pela cotação; aplicar a reserva separadamente.

## Escolha e limites

GPT Image 2.5 Sunburst foi selecionado para geração/edição, com qualidade high e dimensões explícitas. Acesso confirmado por leitura do catálogo; comparação visual e consumo efetivo das chamadas ainda não homologados. Não afirmamos superioridade universal sobre Gemini. O cliente aprovou a escolha da OpenAI. A revisão das peças continua obrigatória, inclusive português, fidelidade do logo e fotos reais. Composição de texto/logo em camadas editáveis é uma melhoria futura; o fluxo atual produz bitmaps.

Fora do cálculo: verba Meta/Google, tarifas WhatsApp/mensageria, Maps/Places e outros provedores de dados, vídeo/voz/transcrição, servidor/banco/storage/tráfego/domínio, cobrança/suporte/trabalho humano e tributos/spread efetivos. Rateio de infraestrutura = custos fixos / clientes ativos. Não há base para afirmar o custo total do SaaS por cliente. Acompanhamento de usage por todos os modelos e falhas/retries deve ser consolidado antes de precificar planos ilimitados.

## Fontes oficiais

- https://developers.openai.com/api/docs/pricing
- https://developers.openai.com/api/docs/guides/image-generation#cost-and-latency
- https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst
- https://ptax.bcb.gov.br/ptax_internet/consultarUltimaCotacaoDolar.do
