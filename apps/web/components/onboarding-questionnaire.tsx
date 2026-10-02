'use client';
import {useEffect,useRef,useState,type ReactNode} from 'react';
import Link from 'next/link';
import {ArrowLeft,ArrowRight,Check,ChevronDown,Paperclip,PencilLine,ShieldCheck} from 'lucide-react';
import {Button} from '@askadia/ui';
import {interviewKeys,type FactInput,type OnboardingSnapshot,type ProfileKey,type onboardingActions} from '@askadia/contracts';
import {onboardingQuestionOrder,onboardingQuestions,questionKey,questionAllowsSkip,questionnaireAnswer} from '../lib/onboarding-questions';
import {BrandWordmark} from './brand';
import {HelpChat} from './help-chat';
import {OnboardingPlaces} from './onboarding-places';
import s from './onboarding-questionnaire.module.css';

type Send=(message:string,action?:typeof onboardingActions[number],answers?:Partial<Record<ProfileKey,FactInput>>)=>Promise<boolean>;
type Props={companyId:string;data:OnboardingSnapshot;busy:boolean;readOnly:boolean;error:string;uploadProgress:string;showSummary:boolean;onSummary:(show:boolean)=>void;send:Send;onSaved:(data:OnboardingSnapshot)=>void;onExit?:()=>void;canConfirm:boolean;summary:ReactNode;materials:ReactNode;attachmentInput:ReactNode;tools:ReactNode};
export function OnboardingQuestionnaire(p:Props){
 const {companyId,data,busy,readOnly}=p;
 const [editStep,setEditStep]=useState<string|null>(null);
 const viewport=useRef<HTMLElement>(null);
 const step=editStep??data.step;
 const reviewing=p.showSummary||step==='review'||step==='complete';
 const index=onboardingQuestionOrder.indexOf(step),progress=step==='complete'?100:Math.max(0,Math.round(index/(onboardingQuestionOrder.length-1)*100));
 const previous=onboardingQuestionOrder.slice(0,index).reverse().find(k=>onboardingQuestions[k]&&data.state.facts[questionKey(k)]);
 const disabled=busy||readOnly;
 useEffect(()=>{const resize=()=>viewport.current?.style.setProperty('--questionnaire-height',(window.visualViewport?.height??window.innerHeight)+'px');resize();window.visualViewport?.addEventListener('resize',resize);return()=>window.visualViewport?.removeEventListener('resize',resize);},[]);
 async function save(message:string,action:typeof onboardingActions[number]='reply',answers:Partial<Record<ProfileKey,FactInput>>={}){
  const ok=await p.send(message,editStep?'edit':action,answers);if(ok){setEditStep(null);p.onSummary(false);}return ok;
 }
 const summary=<><h1 tabIndex={-1}>Confira seu perfil antes de continuar.</h1><p>Você pode corrigir as respostas. A estratégia será preparada após a confirmação do plano.</p>{p.summary}{p.materials}</>;
 return <section ref={viewport} className={s.root} aria-label="Cadastro guiado da empresa">
  <header className={s.header}><Link href="/" aria-label="Askadia, início"><BrandWordmark/></Link><div><span className={s.saved}><ShieldCheck size={15}/>Respostas salvas</span><button disabled={busy} onClick={()=>{setEditStep(null);p.onSummary(!p.showSummary);}}><PencilLine size={15}/>{p.showSummary?'Voltar às perguntas':'Revisar respostas'}</button><Link href="/entrada">Minha conta</Link></div></header>
  <div className={s.progress} role="progressbar" aria-label="Progresso do cadastro" aria-valuenow={progress} aria-valuemin={0} aria-valuemax={100}><span style={{width:progress+'%'}}/></div>
  <div className={s.meta}><span>{data.state.facts.name?.value??'Vamos conhecer sua empresa'}</span><span>{reviewing?'Revisão':step==='location'?'Sua empresa no Google':step==='competitors'?'Seu mercado local':'Seu negócio, do seu jeito'}</span></div>
  {p.error&&<div className={s.error} role="alert">{p.error}</div>}
  {p.uploadProgress&&<p className={s.status} role="status">{p.uploadProgress}</p>}
  {reviewing?<div className={s.reviewBody}>{summary}</div>:step==='location'||step==='competitors'?<div className={s.researchBody}><div className={s.researchTitle}><h1>{step==='location'?'Encontramos sua empresa?':'Quem concorre com você na região?'}</h1><p>{step==='location'?'Confira o endereço e confirme o estabelecimento correto.':'Confira os marcadores, selecione os concorrentes e ajuste o raio se precisar.'}</p></div><OnboardingPlaces key={companyId+step} companyId={p.companyId} data={data} disabled={disabled} mapFirst onSend={p.send} onSaved={p.onSaved}/></div>:<QuestionForm key={companyId+step} step={step} initial={editStep?data.state.facts[questionKey(step)]?.value??'':''} disabled={disabled} saving={busy} onSave={save} extras={<>
   {step==='brand'&&<><label className={s.upload}><Paperclip size={16}/>Anexar logo e materiais{p.attachmentInput}</label>{p.materials}</>}
   {step==='channels'&&<details className={s.connections}><summary>Conectar contas e aproveitar informações<ChevronDown size={16}/></summary>{p.tools}</details>}
  </>}/>}
  <footer className={s.footer}><div>{(previous||p.showSummary)&&step!=='complete'&&<button disabled={busy} onClick={()=>{if(p.showSummary){p.onSummary(false);return;}if(previous)setEditStep(previous);}}><ArrowLeft size={16}/>{p.showSummary?'Voltar às perguntas':'Anterior'}</button>}<small>{reviewing?'Confira e confirme os dados':interviewKeys.includes(step as typeof interviewKeys[number])?'Escolha o que faz sentido para sua empresa.':'Uma etapa de cada vez.'}</small></div>
   {reviewing&&data.step!=='complete'&&p.canConfirm&&<Button disabled={disabled} onClick={()=>void p.send('Confirmo os dados da empresa.','confirm')}>Confirmar e continuar<ArrowRight size={17}/></Button>}
   {reviewing&&data.step!=='complete'&&!p.canConfirm&&<Button disabled={busy} onClick={()=>{setEditStep(null);p.onSummary(false);}}>Continuar perguntas<ArrowRight size={17}/></Button>}
   {step==='complete'&&(p.onExit?<Button onClick={p.onExit}>Continuar<ArrowRight size={17}/></Button>:<Link className="button button-primary" href={'/comecar?empresa='+p.companyId}>Continuar</Link>)}
  </footer>
  <HelpChat companyId={p.companyId}/>
 </section>;
}

export function QuestionForm({step,initial='',disabled=false,saving=false,onSave,extras}:{step:string;initial?:string;disabled?:boolean;saving?:boolean;onSave:Send;extras?:ReactNode}){
 const config=onboardingQuestions[step];
 const [selected,setSelected]=useState<string[]>(()=>initial.split('\n').filter(v=>config?.choices?.includes(v)));
 const [custom,setCustom]=useState(()=>initial.split('\n').filter(v=>!config?.choices?.includes(v)).join('\n'));
 const [showCustom,setShowCustom]=useState(!config?.choices||Boolean(custom)),[error,setError]=useState('');
 const title=useRef<HTMLHeadingElement>(null),input=useRef<HTMLTextAreaElement>(null);
 useEffect(()=>{title.current?.focus();},[]);
 if(!config)return <p role="alert">Não foi possível abrir esta pergunta. Recarregue a página para retomar.</p>;
 async function submit(){if(disabled)return;try{const answer=questionnaireAnswer(step,selected,custom);setError('');await onSave(answer.message,step==='references'?'review_references':'reply',answer.answers);}catch(e){setError(e instanceof Error?e.message:'Confira sua resposta.');}}
 function toggle(value:string){setError('');setSelected(values=>values.includes(value)?values.filter(v=>v!==value):config?.multiple?[...values,value]:[value]);}
 return <form className={s.questionForm} onSubmit={e=>{e.preventDefault();void submit();}} aria-labelledby="onboarding-question-title">
  <div className={s.questionContent}>
   <div className={s.questionHeading}><span className={s.eyebrow}>VAMOS CONHECER SEU NEGÓCIO</span><h1 ref={title} id="onboarding-question-title" tabIndex={-1}>{config.title}</h1><p>{config.hint}</p></div>
   {config.choices&&<><fieldset disabled={disabled} className={s.choices}><legend className="sr-only">{config.multiple?'Selecione uma ou mais opções':'Selecione uma opção'}</legend>{config.choices.map((option,i)=><label key={option} data-selected={selected.includes(option)}><input type={config.multiple?'checkbox':'radio'} name="guided-choice" checked={selected.includes(option)} onChange={()=>toggle(option)}/><span className={s.letter} aria-hidden="true">{selected.includes(option)?<Check size={14}/>:String.fromCharCode(65+i)}</span><span>{option}</span></label>)}</fieldset><p className={s.choiceHint}>{config.multiple?'Você pode escolher mais de uma opção.':'Escolha uma opção ou escreva sua resposta.'}</p></>}
   {config.choices&&!showCustom&&<button type="button" className={s.other} disabled={disabled} onClick={()=>{setShowCustom(true);requestAnimationFrame(()=>input.current?.focus());}}><PencilLine size={16}/>Outra resposta ou complementar</button>}
   {showCustom&&<label className={s.answer}><span>{config.choices?'Sua resposta ou complemento':config.title}</span><textarea ref={input} value={custom} onChange={e=>{setCustom(e.target.value);setError('');}} inputMode={step==='postalCode'?'numeric':'text'} autoComplete={step==='postalCode'?'postal-code':step==='identity'?'organization':'off'} placeholder={config.placeholder??'Escreva com suas palavras…'} maxLength={step==='postalCode'?9:['identity','city'].includes(step)?100:6000} rows={['identity','postalCode','city'].includes(step)?1:2} disabled={disabled} onKeyDown={e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();void submit();}}}/></label>}
   {extras}
   {error&&<p className={s.fieldError} role="alert">{error}</p>}
  </div>
  <div className={s.formActions}><Button type="submit" disabled={disabled||(!selected.length&&!custom.trim())}>{saving?'Salvando…':'Continuar'}<ArrowRight size={18}/></Button><span>ou pressione Enter ↵</span>
   {questionAllowsSkip(step)&&<button type="button" className={s.skip} disabled={disabled} onClick={()=>void onSave(step==='references'?'Não tenho referências.':'Prefiro responder depois.',step==='references'?'review_references':'reply',{[questionKey(step)]:{value:null,status:step==='references'||step==='postalCode'?'unknown':'deferred'}})}>{step==='postalCode'?'Não sei meu CEP':step==='references'?'Não tenho referências':'Responder depois'}</button>}
  </div>
 </form>;
}
