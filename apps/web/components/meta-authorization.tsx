'use client';
import {useState} from 'react';
import {Button} from '@askadia/ui';
import {metaAccess,type MetaFeature} from '@askadia/contracts';
import s from './meta-connection.module.css';
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
 return <div className={s.authorization}>
  <p>{connected?'Para usar outra Página, revise a autorização e escolha a Página ao voltar.':'Primeiro autorize no Facebook. Ao voltar, escolha aqui a Página que deseja integrar a esta empresa.'}</p>
  {canConnect?<div className={s.actions}><Button disabled={busy||!configured} onClick={()=>onConnect(features)}>{busy?'Aguarde…':connected?'Trocar Página ou revisar acessos':'Conectar e escolher Página'}</Button></div>:<p>Somente o proprietário pode autorizar contas.</p>}
  {canConnect&&<details className={s.permissions}><summary>Permissões solicitadas · {features.length} recursos selecionados</summary><fieldset disabled={busy||!configured}><legend>Acessos solicitados</legend>{options.map(o=><label key={o.id}><input type="checkbox" checked={features.includes(o.id)} onChange={e=>setFeatures(f=>e.target.checked?[...f,o.id]:f.filter(v=>v!==o.id))}/><span><strong>{o.label}</strong><small>{o.description}</small></span></label>)}</fieldset><p>Você pode ajustar os recursos antes de conectar. Vincular a Página não publica conteúdo nem ativa campanhas.</p></details>}
  {connected&&<details className={s.permissions}><summary>Ver permissões recebidas</summary><div className={s.received}>{[['Insights Facebook',access.facebookInsights],['Insights Instagram',access.instagramInsights],['Publicação Facebook',access.facebookPublishing],['Publicação Instagram',access.instagramPublishing],['Leitura de anúncios',access.adsRead],['Gestão de anúncios',access.adsManage],['Messenger',access.facebookMessaging],['Instagram Direct',access.instagramMessaging]].map(([label,enabled])=><span key={String(label)}>{label}: {enabled?'autorizado':'permissão ou acesso à conta pendente'}</span>)}</div><p>Permissão concedida não significa publicação, envio ou gasto autorizado. Cada operação mantém suas aprovações.</p></details>}
  <details className={s.permissions}><summary>Minha Página não apareceu ou houve erro no Facebook</summary><p>Confira se entrou no perfil do Facebook que tem acesso à Página. Revise as Páginas autorizadas na conexão e volte para escolher a empresa. Se a Página estiver em um portfólio empresarial, confira também seu acesso ao ativo no Meta Business Suite.</p><p>Se o Facebook informar “Invalid Scopes”, o aplicativo Meta precisa habilitar as permissões citadas. Você pode desmarcar os recursos acima para tentar a vinculação básica da Página; isso não libera publicação, métricas, anúncios ou mensagens.</p></details>
 </div>;
}
