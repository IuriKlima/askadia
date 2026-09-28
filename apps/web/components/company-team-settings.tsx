'use client';
import {useCallback,useEffect,useRef,useState,type FormEvent} from 'react';
import {Button,Modal} from '@askadia/ui';
import {companyRoles,roleLabels,type CompanyTeam,type MemberRecord} from '@askadia/contracts';
import {identityApi} from '../lib/identity-api';
import {CompanyDelegations} from './company-delegations';
import {LoadState} from './load-state';
import styles from './company-settings.module.css';
const auditLabels:Record<string,string>={'company.created':'Empresa criada','company.updated':'Perfil atualizado','member.invited':'Convite criado','member.joined':'Convite aceito','member.removed':'Membro removido','member.role_changed':'Permissão alterada','invitation.revoked':'Convite revogado','company.export_requested':'Exportação solicitada'};
export function CompanyTeamSettings({companyId,owner,userId,timezone}:{companyId:string;owner:boolean;userId:string;timezone:string}){
 const [data,setData]=useState<CompanyTeam|null>(null),[error,setError]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false);
 const [dialog,setDialog]=useState<'invite'|'member'|null>(null),[member,setMember]=useState<MemberRecord|null>(null),[formError,setFormError]=useState(''),[inviteLink,setInviteLink]=useState('');
 const lock=useRef(false);const base='companies/'+companyId;
 const load=useCallback(async(signal?:AbortSignal)=>{try{const result=await identityApi<CompanyTeam>(base+'/team','GET',undefined,signal);if(!signal?.aborted){setData(result);setError('');}}catch(e){if(!signal?.aborted){setData(null);setError(e instanceof Error?e.message:'Não foi possível carregar a equipe.');}}},[base]);
 useEffect(()=>{const c=new AbortController();void load(c.signal);return()=>c.abort();},[load]);
 function open(kind:'invite'|'member',person?:MemberRecord){setMember(person??null);setFormError('');setInviteLink('');setDialog(kind);}
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(lock.current)return;lock.current=true;setBusy(true);setFormError('');setNotice('');
  const values=new FormData(event.currentTarget),role=String(values.get('role'));
  try{
   if(dialog==='invite'){
    const result=await identityApi<{token:string}>(base+'/invitations','POST',{email:String(values.get('email')).trim(),role});
    setInviteLink(window.location.origin+'/login#invite='+result.token);
    setNotice('Convite criado. Compartilhe o link com a pessoa indicada.');
   }else if(dialog==='member'&&member){
    await identityApi(base+'/members/'+member.user_id,'PATCH',{role:role==='remove'?null:role});setDialog(null);setNotice('Acesso atualizado.');
   }
   await load();
  }catch(e){setFormError(e instanceof Error?e.message:'Não foi possível salvar.');}finally{lock.current=false;setBusy(false);}
 }
 async function revoke(id:string){if(lock.current)return;lock.current=true;setBusy(true);setError('');try{await identityApi(base+'/invitations/'+id+'/revoke','POST',{});setNotice('Convite revogado.');await load();}catch(e){setError(e instanceof Error?e.message:'Não foi possível revogar.');}finally{lock.current=false;setBusy(false);}}
 return <div className={styles.team}>
  {error&&<LoadState error={error} retry={()=>void load()}/>} {!data&&!error&&<LoadState label="Carregando equipe e acessos…"/>}
  {notice&&<p role="status" className={styles.notice}>{notice}</p>}
  {data&&<><div className={styles.heading}><div><h2>Equipe e acessos</h2><p>Convide pessoas e escolha as permissões nesta empresa.</p></div><Button disabled={busy} onClick={()=>open('invite')}>Convidar pessoa</Button></div>
   <div className={styles.members}>{data.members.map(person=><article key={person.user_id}><div><strong>{person.display_name}{person.user_id===userId?' · Você':''}</strong><p>{roleLabels[person.role]}</p></div><Button variant="outline" size="small" disabled={busy} onClick={()=>open('member',person)}>Gerenciar acesso</Button></article>)}</div>
   <CompanyDelegations companyId={companyId} members={data.members} owner={owner}/>
   <h3>Convites</h3><div className={styles.members}>{data.invitations.length?data.invitations.map(inv=><article key={inv.id}><div><strong>{inv.email}</strong><p>{roleLabels[inv.role]} · {inv.accepted_at?'Aceito':inv.revoked_at?'Revogado':Date.parse(inv.expires_at)<=Date.now()?'Expirado':'Válido até '+new Date(inv.expires_at).toLocaleDateString('pt-BR',{timeZone:timezone})}</p></div>{!inv.accepted_at&&!inv.revoked_at&&Date.parse(inv.expires_at)>Date.now()&&<Button variant="outline" size="small" disabled={busy} onClick={()=>void revoke(inv.id)}>Revogar</Button>}</article>):<p>Nenhum convite nesta empresa.</p>}</div>
   <details className={styles.history}><summary>Histórico de acessos e alterações</summary>{data.audit.length?data.audit.map(record=><article key={record.id}><strong>{auditLabels[record.action]??record.action}</strong><p>{new Date(record.created_at).toLocaleString('pt-BR',{timeZone:timezone})} · {record.actor_id===userId?'Você':data.members.find(person=>person.user_id===record.actor_id)?.display_name??'Membro anterior'}</p></article>):<p>Nenhum registro disponível.</p>}</details>
  </>}
  <Modal open={dialog!==null} onOpenChange={value=>{if(!value&&!busy)setDialog(null);}} title={dialog==='invite'?'Convidar pessoa':'Gerenciar acesso'} description="As permissões são verificadas no servidor e as alterações ficam no histórico.">
   {formError&&<p role="alert" className="form-error">{formError}</p>}
   {inviteLink?<div className="form"><p>Compartilhe este link com a pessoa indicada. Válido por 7 dias; nenhum e-mail foi enviado.</p><label>Link do convite<input readOnly value={inviteLink} onFocus={event=>event.currentTarget.select()}/></label><Button onClick={()=>setDialog(null)}>Concluir</Button></div>:<form className="form" onSubmit={submit}>
    {dialog==='invite'?<label>E-mail<input name="email" type="email" required maxLength={254}/></label>:<p>{member?.display_name}</p>}
    <label>Permissão<select name="role" defaultValue={member?.role??'marketing'}>{companyRoles.map(role=><option key={role} value={role}>{roleLabels[role]}</option>)}{dialog==='member'&&<option value="remove">Remover acesso desta empresa</option>}</select></label>
    <p>A empresa deve manter pelo menos um administrador. Aprovações adicionais são definidas nas delegações.</p>
    <Button type="submit" disabled={busy}>{busy?'Salvando…':dialog==='invite'?'Criar convite':'Salvar acesso'}</Button>
   </form>}
  </Modal>
 </div>;
}
