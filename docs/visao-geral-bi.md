# Visão geral e inteligência regional — 23/09/2026

## Implementado

A página inicial da empresa reúne contagem exata de contatos, novos cadastros por dia, oportunidades por etapa e campanhas de mensagens. Filtros de 7, 30 e 90 dias respeitam o fuso da empresa. Importações são identificadas como cadastros, sem confundir sua data com o primeiro contato. Etapa de matrícula não é pagamento confirmado.

O bloco financeiro reutiliza o motor autorizado de `/dashboard`: investimento, receita atribuída, novos pagantes, CAC, ROAS e ROI. Fórmula e fonte ficam acessíveis em cada indicador. Sem base financeira, não calcula resultados a partir dos leads.

Inteligência regional usa adaptadores no servidor:

- **IBGE**: identifica município por nome e UF confirmados (ou componentes do endereço Google), consulta tabela 4714, variáveis 93, 6318 e 614. Exibe população, área e densidade com o ano da referência. É média municipal, não estimativa do raio nem população em tempo real.
- **Google Places**: pesquisa academias/centros fitness por distância, em raios de 1, 3, 5 ou 10 km. Exclui a própria unidade, duplicatas, locais encerrados e coordenadas fora do raio. A API limita a 20 resultados; a contagem é parcial. Lista, distâncias e seleção do mapa usam a mesma resposta. Atribuições são preservadas.
- **Facebook**: pesquisa oficial `pages/search` com token da empresa e `appsecret_proof`, filtrando páginas com coordenadas no raio. Depende do acesso concedido ao app pela Meta; login da Página não garante pesquisa de concorrentes. Contagem separada, sem somar duplicatas entre fontes.
- **Google Trends**: embed oficial de pesquisas relacionadas e interesse temporal, para “academia”, últimos três meses, no estado identificado. O recorte estadual é explícito, separado do raio. O embed controla a quantidade/paginação e pode fornecer 25 termos. O ranking próprio de até 20 principais resultados depende do adaptador opcional SerpApi (`SERPAPI_API_KEY`); não exige criar conta nem inventa termos para completar a lista. Escala 0–100 não representa volume absoluto. A API alpha oficial não foi presumida pública.

## Isolamento e limites

Endpoints `/onboarding/companies/:id/overview` e `/market` passam por Auth, capacidades da empresa e RLS. CRM só é consultado com `crm.read`; atualização regional exige `marketing.write` e perfil confirmado. Credenciais Google/Meta/SerpApi ficam no servidor; só a chave própria do Maps para navegador é fornecida ao mapa. Nenhum token da Meta é devolvido.

Coletas usam a quota diária existente de Places e requisições limitadas, hosts fixos e sem redirecionamento. Cache efêmero de seis horas, limitado a 200 entradas, separado por empresa, versão/revisão do perfil e raio; atualização mínima de cinco minutos e deduplicação de consultas simultâneas. Permissão e perfil são revalidados após as chamadas externas, inclusive para usuários aguardando uma coleta compartilhada. Não é um monitor contínuo ou inventário completo do mercado.

CRM consulta datas em páginas de 1.000 registros e contagens exatas, sem limitar silenciosamente a primeira página. Acima de 100.000 cadastros no período exige outra estratégia de agregação. Sem mensagens pessoais na resposta do BI. Falhas ficam como indisponíveis, não zero.

## Validação e dependências reais

- `pnpm check`: lint, tipos, 198 testes em 20 arquivos, builds de API/worker/web. Os 12 testes novos cobrem município/ano, dados ausentes, fontes, raio, duplicatas, top versus rising, fuso/DST, autorização e revogação durante coleta compartilhada.
- Consulta real de Gaviões Varginha: CRM com 1.735 contatos; Google encontrou 19 outros estabelecimentos em 3 km (limite de 20 incluindo a própria unidade), e cinco em 1 km. IBGE retornou São Paulo, Censo 2022: 11.451.999 pessoas, 1.521,202 km² e 7.528,26 hab/km². Resultados retratam a coleta, não garantem cobertura completa.
- Corrigido componente de endereço sem `types` na resposta real do Google. Nenhum cadastro, campanha ou mensagem foi criado nos testes.
- Maps JavaScript API retornou `ApiNotActivatedMapError`. Google Cloud está sem sessão autenticada; ativação no projeto da chave pendente de login do responsável. A lista funciona sem o mapa.
- Meta Pages Search continua indisponível com o acesso atual. Homologação da permissão do app pendente.
- Embed oficial validado em página do Google; comportamento incorporado depende do navegador. Link externo disponível. Ranking próprio de 20 aguarda provedor; nenhuma chave SerpApi foi configurada.
- `dashboard_read` ausente no Supabase remoto (`PGRST202`). Migração aditiva existente `202609219001_dashboard.sql` preparada em `.local/askadia-dashboard.sql` e conferida integralmente no editor (conteúdo normalizado idêntico). Revisão automática bloqueou Run por falta de autorização específica; confirmação solicitada. Não foi executada nem contornada. Não existem ainda fatos financeiros importados neste trabalho.

## Referências

- [IBGE — API de agregados](https://servicodados.ibge.gov.br/api/docs/agregados?versao=3)
- [IBGE — tabela 4714](https://sidra.ibge.gov.br/tabela/4714)
- [Google Places Nearby Search](https://developers.google.com/maps/documentation/places/web-service/nearby-search)
- [Meta Pages Search](https://developers.facebook.com/documentation/pages-api/search-pages)
- [Incorporar gráficos do Google Trends](https://support.google.com/trends/answer/4365538?hl=pt-BR)
- [Google Trends API alpha](https://developers.google.com/search/apis/trends)
- [SerpApi — pesquisas relacionadas](https://serpapi.com/google-trends-related-queries)
