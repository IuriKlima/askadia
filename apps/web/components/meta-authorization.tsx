'use client';
import {useState} from 'react';
import {Button} from '@askadia/ui';
import {metaAccess,type MetaFeature} from '@askadia/contracts';
const options:{id:MetaFeature;label:string;description:string}[]=[
 {id:'insights',label:'Insights e resultados',description:'Ler métricas do Facebook e Instagram.'},
 {id:'publishing',label:'Publicações',description:'Autorizar a publicação dos conteúdos aprovados.'},
 {id:'ads',label:'Tráfego pago',description:'Ler e gerenciar campanhas na conta de anúncios escolhida.'},
 {id:'messaging',label:'Mensagens',description:'Ler e responder conversas do Messenger e Instagram Direct.'},
];
export function MetaAuthorization({metadata,connected,busy,canConnect,configured,onConnect}:{metadata?:Record<string,unknown>;connected:boolean;busy:boolean;canConnect:boolean;configured:boolean;onConnect:(features:MetaFeature[])=>void}){
 const [features,setFeatures]=useState<MetaFeature[]>(['insights','publishing','ads','messaging']);
 const scopes=Array.isArray(metadata?.scopes)?metadata.scopes.filter((p):p is string=>typeof p==='string'):[];
 const tasks=Array.isArray(metadata?.tasks)?metadata.tasks.filter((p):p is string=>typeof p==='string'):[];
 const access=metaAccess(scopes,typeof metadata?.instagramId==='string'?metadata.instagramId:null,tasks);
 return <div><p>Escolha os acessos que esta empresa deseja autorizar. A Meta permite selecionar as Páginas e contas durante a conexão.</p>
 {canConnect&&<fieldset disabled={busy||!configured} style={{border:0,padding:0,display:'grid',gap:12,margin:'20px 0'}}><legend>Acessos solicitados</legend>{options.map(o=><label key={o.id} style={{display:'flex',alignItems:'flex-start',gap:10,paddingTop:10}}><input style={{width:'auto',marginTop:4}} type="checkbox" checked={features.includes(o.id)} onChange={e=>setFeatures(f=>e.target.checked?[...f,o.id]:f.filter(v=>v!==o.id))}/><span><strong>{o.label}</strong><small style={{display:'block',marginTop:5}}>{o.description}</small></span></label>)}</fieldset>}
 {canConnect?<Button disabled={busy||!configured} onClick={()=>onConnect(features)}>{connected?'Atualizar autorizações Meta':'Conectar Facebook e Instagram'}</Button>:<p>Somente o proprietário pode autorizar contas.</p>}
 {connected&&<div style={{marginTop:20}}><h4>Permissões recebidas</h4><p>{[['Insights Facebook',access.facebookInsights],['Insights Instagram',access.instagramInsights],['Publicação Facebook',access.facebookPublishing],['Publicação Instagram',access.instagramPublishing],['Leitura de anúncios',access.adsRead],['Gestão de anúncios',access.adsManage],['Messenger',access.facebookMessaging],['Instagram Direct',access.instagramMessaging]].map(([label,enabled])=><span key={String(label)} style={{display:'block',marginBottom:5}}>{label}: {enabled?'autorizado':'permissão ou acesso à conta pendente'}</span>)}</p><p>Permissão concedida não significa publicação, envio ou gasto autorizado. Cada operação mantém suas aprovações.</p></div>}
 <details style={{marginTop:18}}><summary>O Facebook mostrou “Invalid Scopes”?</summary><p>O aplicativo Meta precisa habilitar as permissões citadas no erro. O administrador deve adicioná-las no caso de uso correspondente. Para vincular apenas a Página enquanto isso, desmarque os acessos acima. Essa conexão básica não libera publicação, métricas, anúncios ou mensagens.</p></details></div>;
}
