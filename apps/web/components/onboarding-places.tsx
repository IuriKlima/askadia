'use client';
import {useEffect,useRef,useState} from 'react';
import {Button} from '@askadia/ui';
import type {FactInput,OnboardingSnapshot,PlaceOption,PlaceSearchResult,ProfileKey} from '@askadia/contracts';
import {journeyApi} from '../lib/journey-api';
import {PlacesMap} from './places-map';
import {confirmedLocationAnswers} from '../lib/onboarding-location';
import s from './onboarding-questionnaire.module.css';

type Props={companyId:string;data:OnboardingSnapshot;disabled:boolean;mapFirst?:boolean;onSend:(message:string,action:'confirm_location'|'edit',answers?:Partial<Record<ProfileKey,FactInput>>)=>Promise<boolean>;onSaved:(data:OnboardingSnapshot)=>void};
export function OnboardingPlaces({companyId,data,disabled,mapFirst=true,onSend,onSaved}:Props){
 const [radius,setRadius]=useState(3000),[search,setSearch]=useState<PlaceSearchResult|null>(null),[selected,setSelected]=useState<string[]>([]),[loading,setLoading]=useState(false),[saving,setSaving]=useState(false),[error,setError]=useState(''),[refresh,setRefresh]=useState(0);
 const [manual,setManual]=useState(false),[correcting,setCorrecting]=useState(false),[manualCity,setManualCity]=useState(data.state.facts.city?.value??''),[manualAddress,setManualAddress]=useState(data.state.facts.address?.value??''),[name,setName]=useState(data.state.facts.name?.value??''),[postalCode,setPostalCode]=useState(data.state.facts.postalCode?.value??'');
 const pending=useRef<{key:string;id:string}|null>(null),mounted=useRef(true),lock=useRef(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const kind=data.step==='location'?'location':'competitors',facts=data.state.facts;
 const canSearch=data.capabilities.actions.includes('marketing.write');
 const queryKey=JSON.stringify([companyId,kind,facts.name?.value,facts.postalCode?.value,facts.city?.value,facts.address?.value,facts.businessType?.value,facts.placeId?.value,radius]);
 useEffect(()=>{
  if(!canSearch)return;const controller=new AbortController();setLoading(true);setError('');setSearch(null);setSelected([]);
  const timer=setTimeout(()=>{void journeyApi<PlaceSearchResult>('companies/'+companyId+'/places',{requestId:crypto.randomUUID(),kind,radius},controller.signal).then(value=>{if(!controller.signal.aborted){setSearch(value);const previous=(facts.competitorPlaceIds?.value??'').split('\n');setSelected(kind==='competitors'?value.places.filter(p=>previous.includes(p.id)).map(p=>p.id):[]);}}).catch(e=>{if(!controller.signal.aborted)setError(e instanceof Error?e.message:'Pesquisa indisponível. Você pode continuar manualmente.');}).finally(()=>{if(!controller.signal.aborted)setLoading(false);});},250);
  return()=>{clearTimeout(timer);controller.abort();};
 // The key covers the search inputs; unrelated saves must not repeat a paid Google query.
 },[queryKey,refresh,canSearch]);
 function toggle(id:string){if(kind==='location'){setSelected([id]);return;}setSelected(values=>values.includes(id)?values.filter(v=>v!==id):values.length<10?[...values,id]:values);}
 async function confirm(place:PlaceOption){
  try{const answers=confirmedLocationAnswers(place,facts,manualCity);await onSend('Conferi este estabelecimento e confirmo o endereço, CEP e dados comerciais exibidos.','confirm_location',answers);}catch(e){setSelected([place.id]);setError(e instanceof Error?e.message:'Confira a localização.');}
 }
 async function review(){
  if(disabled||lock.current)return;lock.current=true;setSaving(true);setError('');
  const places=search?.places.filter(p=>selected.includes(p.id)).map(p=>({placeId:p.id,label:p.name.slice(0,160)}))??[];
  const key=JSON.stringify([companyId,data.state.revision,places]);if(pending.current?.key!==key)pending.current={key,id:crypto.randomUUID()};
  try{const saved=await journeyApi<OnboardingSnapshot>('companies/'+companyId+'/places/review',{requestId:pending.current.id,revision:data.state.revision,places});if(mounted.current){pending.current=null;onSaved(saved);}}
  catch(e){if(mounted.current)setError(e instanceof Error?e.message:'Não foi possível salvar a seleção.');}finally{lock.current=false;if(mounted.current)setSaving(false);}
 }
 const blocked=disabled||saving,hasPlaces=Boolean(search?.places.length);
 async function saveManual(){
  if(blocked)return;
  if(correcting){
   if(!name.trim()||(!postalCode.trim()&&!manualCity.trim())){setError('Informe o nome e o CEP ou a cidade.');return;}
   if(postalCode.trim()&&!/^\d{5}-?\d{3}$/.test(postalCode.trim())){setError('Informe um CEP com 8 dígitos.');return;}
   const answers:Partial<Record<ProfileKey,FactInput>>={name:{value:name.trim(),status:'provided'},postalCode:{value:postalCode.trim()||null,status:postalCode.trim()?'provided':'unknown'}};
   if(!postalCode.trim())answers.city={value:manualCity.trim(),status:'provided'};
   if(await onSend('Corrigi os dados para pesquisar minha empresa.','edit',answers)){setCorrecting(false);setManual(false);}return;
  }
  if(!manualCity.trim()){setError('Informe a cidade e o estado.');return;}
  if(await onSend('Confirmei manualmente a localização da empresa.','confirm_location',{city:{value:manualCity.trim(),status:'provided'},address:{value:manualAddress.trim()||null,status:manualAddress.trim()?'provided':'unknown'}}))setManual(false);
 }
 const external='https://www.google.com/maps/search/?api=1&query='+encodeURIComponent([kind==='location'?facts.name?.value:facts.businessType?.value??'academia',facts.postalCode?.value,facts.city?.value].filter(Boolean).join(' '));
 return <section className={s.placesPanel} aria-label={kind==='location'?'Busca da empresa no Google':'Seleção de concorrentes locais'}>
  <div className={s.placeHeader}>{kind==='competitors'?<label>Raio da pesquisa<select value={radius} disabled={blocked||loading} onChange={e=>setRadius(Number(e.target.value))}>{[1000,3000,5000,10000,20000].map(r=><option key={r} value={r}>{r/1000} km</option>)}</select></label>:<Button variant="outline" disabled={blocked} onClick={()=>{setCorrecting(true);setManual(true);setError('');}}>Corrigir nome ou CEP</Button>}<Button variant="outline" disabled={blocked||loading} onClick={()=>setRefresh(v=>v+1)}>{loading?'Pesquisando no Google…':'Pesquisar novamente'}</Button></div>
  {error&&<p role="alert" className="error-banner">{error}</p>}
  {manual?<form className={s.manualForm} onSubmit={e=>{e.preventDefault();void saveManual();}}>
   <strong>{correcting?'Corrigir a pesquisa':'Confirmar localização manualmente'}</strong>
   {correcting&&<><label>Nome da empresa<input value={name} onChange={e=>setName(e.target.value)} maxLength={100} required disabled={blocked}/></label><label>CEP<input value={postalCode} inputMode="numeric" autoComplete="postal-code" onChange={e=>setPostalCode(e.target.value)} maxLength={9} disabled={blocked}/></label></>}
   {(!correcting||!postalCode.trim())&&<label>Cidade e estado<input value={manualCity} onChange={e=>setManualCity(e.target.value)} maxLength={100} required disabled={blocked} placeholder="Cidade, UF"/></label>}
   {!correcting&&<label>Endereço da empresa<input value={manualAddress} onChange={e=>setManualAddress(e.target.value)} maxLength={500} disabled={blocked} placeholder="Rua, número e bairro"/></label>}
   <div className={s.manualActions}><Button type="submit" disabled={blocked}>{correcting?'Salvar e buscar novamente':'Confirmar localização'}</Button><Button type="button" variant="outline" disabled={blocked} onClick={()=>setManual(false)}>Voltar aos resultados</Button></div>
  </form>:<>
   {loading&&<p role="status">Procurando {kind==='location'?facts.name?.value+' · '+(facts.postalCode?.value??facts.city?.value):'concorrentes próximos da empresa'}…</p>}
   {search&&<p role="status" className={s.placesStatus}>{search.message}</p>}
   {!loading&&(search?.status!=='available'||!hasPlaces)&&<div className={s.mapFallback}>{search?.status==='available'?'Nenhum estabelecimento encontrado com estes dados. Corrija a busca ou continue manualmente.':'A lista e o mapa dependem da disponibilidade do Google.'} <a href={external} target="_blank" rel="noreferrer">Abrir busca no Google Maps ↗</a></div>}
   {hasPlaces&&search&&<><small className={s.googleAttribution}>Google Maps · consulta atual · confirme os resultados antes de continuar</small><div className={s.placesSplit+' '+(!mapFirst?s.listOnly:'')}>
    {mapFirst&&<div className={s.placesMap}><PlacesMap search={search} selected={selected} disabled={blocked} onSelect={toggle}/></div>}
    <div className={s.placesList}>{search.places.map((p,i)=><article className={s.placeCard} key={p.id} data-selected={selected.includes(p.id)}>
     <h3>{i+1}. {p.name}</h3><p>{p.address}</p>{kind==='location'&&p.postalCode&&p.postalCode.replace('-','')!==facts.postalCode?.value?.replace('-','')&&<p><strong>CEP encontrado: {p.postalCode}.</strong> Ao confirmar, usaremos o CEP deste estabelecimento.</p>}
     <details open={kind==='location'?true:undefined}><summary>Ver informações do estabelecimento</summary><PlaceInformation place={p}/>{p.attributions.map((a,j)=><small key={j}>{a.uri?<a href={a.uri} target="_blank" rel="noreferrer">{a.displayName}</a>:a.displayName}</small>)}</details>
     <a href={p.url} target="_blank" rel="noreferrer">Ver no Google Maps ↗</a>
     {kind==='location'?<>{!p.city&&!facts.city?.value&&<label>Cidade e estado<input value={manualCity} onChange={e=>setManualCity(e.target.value)} maxLength={100} disabled={blocked}/></label>}<Button disabled={blocked} variant={selected.includes(p.id)?'default':'outline'} onClick={()=>void confirm(p)}>É minha empresa, confirmar dados</Button></>:<label><input type="checkbox" checked={selected.includes(p.id)} disabled={blocked||(!selected.includes(p.id)&&selected.length>=10)} onChange={()=>toggle(p.id)}/>Acompanhar este concorrente</label>}
    </article>)}</div>
   </div></>}
   <div className={s.placeFooter}>{kind==='location'?<Button variant="outline" disabled={blocked||loading} onClick={()=>{setManual(true);setCorrecting(false);setError('');}}>Não encontrei minha empresa</Button>:<><div><p>{selected.length} de 10 concorrentes selecionados.</p><p>Perfis do Instagram e análises aparecerão na Estratégia após confirmar o plano.</p></div><Button disabled={blocked||loading} onClick={()=>void review()}>{saving?'Salvando…':selected.length?'Salvar e continuar':'Continuar com pesquisa pendente'}</Button></>}</div>
  </>}
 </section>;
}
export function PlaceInformation({place}:{place:PlaceOption}){const d=place.details;if(!d)return null;return <><p>{d.businessType}{d.businessStatus==='CLOSED_TEMPORARILY'?' · Temporariamente fechado':''}</p>{d.phone&&<p>Telefone: {d.phone}</p>}{d.website&&<p><a href={d.website} target="_blank" rel="noreferrer">Site do estabelecimento ↗</a></p>}{d.rating!==null&&<p>Avaliação no Google: {d.rating.toLocaleString('pt-BR')} / 5{d.reviewCount!==null?' · '+d.reviewCount+' avaliações':''}</p>}{d.hours.length>0&&<details><summary>Horários de funcionamento</summary>{d.hours.map(h=><div key={h}>{h}</div>)}</details>}</>;}
