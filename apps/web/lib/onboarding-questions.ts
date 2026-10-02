import {essentialKeys,labels,type FactInput,type ProfileKey} from '@askadia/contracts';

type Question={title:string;hint:string;choices?:string[];multiple?:boolean;placeholder?:string};
export const onboardingQuestionOrder=['identity','postalCode','city','location','businessType','competitors','references','services','audience','objective','structure','hours','offers','sales','history','budget','brand','channels','video','management','review'];
export const onboardingQuestions:Record<string,Question>={
 identity:{title:'Qual é o nome da sua empresa?',hint:'Escreva como seus clientes conhecem o negócio.',placeholder:'Nome da academia ou empresa'},
 postalCode:{title:'Qual é o CEP da sua empresa?',hint:'Vamos usar o nome e o CEP para encontrar seu estabelecimento no Google.',placeholder:'00000-000'},
 city:{title:'Em qual cidade fica sua empresa?',hint:'Sem o CEP, também podemos pesquisar pela cidade. Inclua o estado.',placeholder:'Cidade, UF'},
 businessType:{title:'Qual opção descreve seu negócio?',hint:'Escolha a atividade principal ou escreva outra.',choices:['Academia','Estúdio de pilates','Estúdio de treinamento funcional','Box de cross training','Escola de lutas','Centro esportivo']},
 references:{title:'Quem inspira a sua empresa?',hint:'Escreva nomes, sites ou perfis e conte o que admira: comunicação, ofertas, visual ou atendimento.',placeholder:'Ex.: Academia Movimento — gosto dos vídeos e da forma de apresentar as aulas.'},
 services:{title:'O que seus clientes encontram aí?',hint:'Selecione as modalidades que sua empresa realmente oferece.',choices:['Musculação','Treinamento funcional','Pilates','Aulas coletivas','Lutas','Natação'],multiple:true,placeholder:'Outras modalidades ou detalhes…'},
 audience:{title:'Quem você mais quer atrair?',hint:'Escolha os públicos que sua equipe está preparada para atender.',choices:['Pessoas começando a treinar','Quem busca saúde e bem-estar','Quem quer emagrecer','Quem busca força e desempenho','Pessoas acima de 60 anos','Quem quer voltar a treinar'],multiple:true},
 objective:{title:'Qual é a sua prioridade agora?',hint:'Escolha o objetivo principal. Se souber, acrescente uma meta e um prazo.',choices:['Atrair novos alunos','Aumentar visitas e aulas experimentais','Melhorar a retenção dos alunos','Preencher horários ociosos','Fortalecer a marca na região','Vender planos de maior valor'],placeholder:'Ex.: chegar a 30 visitas por mês nos próximos 3 meses.'},
 structure:{title:'O que faz sua empresa se destacar?',hint:'Marque apenas diferenciais que você consegue entregar.',choices:['Acompanhamento próximo','Equipamentos e estrutura','Equipe especializada','Variedade de modalidades','Localização e acesso','Ambiente acolhedor'],multiple:true},
 hours:{title:'Quando você quer mais movimento?',hint:'Escolha os períodos ociosos e complemente com os horários de funcionamento.',choices:['Manhã','Horário do almoço','Tarde','Noite','Finais de semana'],multiple:true,placeholder:'Ex.: abrimos de segunda a sexta, das 6h às 22h.'},
 offers:{title:'Quais planos podemos apresentar?',hint:'Inclua os valores e condições no campo livre. Só usaremos preços confirmados por você.',choices:['Plano mensal','Plano trimestral','Plano semestral','Plano anual','Aula experimental'],multiple:true,placeholder:'Plano, valor, condições e validade de cada oferta…'},
 sales:{title:'Como vocês recebem interessados?',hint:'Selecione os canais do atendimento e conte como funciona o agendamento.',choices:['WhatsApp','Recepção presencial','Instagram Direct','Ligação','Formulário no site'],multiple:true,placeholder:'Quem responde, horários e como agendar uma visita…'},
 history:{title:'O que você já experimentou no marketing?',hint:'Selecione o que já fez e conte o que funcionou ou precisa melhorar.',choices:['Publicações nas redes sociais','Anúncios no Instagram ou Facebook','Anúncios no Google','Parcerias e indicações','Campanhas pelo WhatsApp'],multiple:true},
 budget:{title:'Quanto pretende investir em anúncios?',hint:'Uma estimativa mensal ajuda a planejar. Esta resposta não autoriza gastos.',choices:['Até R$ 500 por mês','De R$ 500 a R$ 1.000 por mês','De R$ 1.000 a R$ 2.000 por mês','De R$ 2.000 a R$ 5.000 por mês','Acima de R$ 5.000 por mês'],placeholder:'Ou informe um valor e suas condições.'},
 brand:{title:'Como sua marca deve se comunicar?',hint:'Escolha o estilo que combina com a empresa. Acrescente cores e referências; você pode anexar seu logo.',choices:['Acolhedora e próxima','Motivadora e energética','Técnica e educativa','Moderna e direta','Premium e sofisticada'],multiple:true},
 channels:{title:'Onde sua empresa já está presente?',hint:'Selecione os canais, informe os endereços e conecte as contas abaixo quando quiser.',choices:['Instagram','Facebook','WhatsApp','Site próprio','Perfil da Empresa no Google'],multiple:true,placeholder:'@ do Instagram, endereço do site e WhatsApp comercial…'},
 video:{title:'Como podemos trabalhar os vídeos?',hint:'Escolha uma rotina que sua equipe consegue manter.',choices:['Consigo gravar toda semana','Consigo gravar a cada 15 dias','Tenho vídeos prontos para usar','Preciso de orientação para gravar','Prefiro começar com imagens'],placeholder:'Quem pode gravar e quais materiais já existem?'},
 management:{title:'Qual sistema de gestão vocês usam?',hint:'A resposta ajuda a planejar integrações. Nenhum acesso é conectado automaticamente.',choices:['Tecnofit','Next Fit','Pacto','EVO','Planilhas'],placeholder:'Outro sistema ou detalhes sobre o uso…'}
};
export const questionKey=(step:string)=>step==='identity'?'name':step as ProfileKey;
export function questionAllowsSkip(step:string){return !essentialKeys.includes(questionKey(step) as typeof essentialKeys[number]);}
export function questionnaireAnswer(step:string,selected:string[],custom:string):{message:string;answers:Partial<Record<ProfileKey,FactInput>>}{
 const config=onboardingQuestions[step];if(!config)throw new Error('Pergunta indisponível.');
 const unique=[...new Set(selected)];if(unique.some(v=>!config.choices?.includes(v))||(!config.multiple&&unique.length>1))throw new Error('Confira as opções selecionadas.');
 const value=[...unique,custom.trim()].filter(Boolean).join('\n');
 if(!value)throw new Error('Escolha uma opção ou escreva sua resposta.');
 if(step==='postalCode'&&!/^\d{5}-?\d{3}$/.test(value))throw new Error('Informe um CEP com 8 dígitos.');
 if(value.length>(['identity','city','businessType'].includes(step)?100:6000))throw new Error('Resuma sua resposta para continuar.');
 const key=questionKey(step);return {message:labels[key]+': '+value,answers:{[key]:{value,status:'provided'}}};
}
