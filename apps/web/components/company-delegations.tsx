'use client';
import { useCallback,useEffect,useState,type FormEvent } from 'react';
import { Button } from '@askadia/ui';
import { permissionActions,type DelegationRecord,type MemberRecord } from '@askadia/contracts';
import { connectedApi } from '../lib/api-client';
const labels:Record<string,string>={'crm.read':'Consultar CRM','crm.write':'Editar CRM','content.approve':'Aprovar conteúdo','strategy.approve':'Aprovar estratégia','site.approve':'Aprovar site','ads.approve':'Aprovar orçamento de anúncios'};
export function CompanyDelegations({companyId,members,owner}:{companyId:string;members:MemberRecord[];owner:boolean}){
  const [rows,setRows]=useState<DelegationRecord[]|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),[action,setAction]=useState<string>('crm.read');
  const refresh=useCallback(async(signal?:AbortSignal)=>{
    try{const data=await connectedApi<DelegationRecord[]>('companies/'+companyId+'/delegations',{signal});if(!signal?.aborted){setRows(data);setError('');}}
    catch(e){if(!signal?.aborted)setError(e instanceof Error?e.message:'Não foi possível consultar delegações.');}
  },[companyId]);
  useEffect(()=>{const c=new AbortController();void refresh(c.signal);return()=>c.abort();},[refresh]);
  async function save(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setBusy(true);setError('');
    const form=event.currentTarget,fields=new FormData(form);
    const budget=String(fields.get('budget')??'').trim().replace(',','.');
    try{
      await connectedApi('companies/'+companyId+'/delegations',{method:'POST',body:{userId:String(fields.get('userId')),action,enabled:true,budgetLimitCents:action==='ads.approve'?Math.round(Number(budget)*100):null,expiresAt:null}});
      form.reset();setAction('crm.read');await refresh();
    }catch(e){setError(e instanceof Error?e.message:'Não foi possível delegar.');}finally{setBusy(false);}
  }
  async function revoke(row:DelegationRecord){
    setBusy(true);setError('');
    try{await connectedApi('companies/'+companyId+'/delegations',{method:'POST',body:{userId:row.user_id,action:row.action,enabled:false}});await refresh();}
    catch(e){setError(e instanceof Error?e.message:'Não foi possível revogar.');}finally{setBusy(false);}
  }
  return <><div className="section-heading"><h2>Delegações explícitas</h2><span className="muted-caption">Concedidas pelo proprietário</span></div>
    {error&&<div className="error-banner" role="alert">{error}</div>}
    <section className="panel invitation-list">{rows===null?<div role="status">Carregando delegações…</div>:!rows.length?<div><p>Nenhuma permissão adicional concedida.</p></div>:rows.map(row=><div key={row.user_id+row.action}><span><strong>{members.find(m=>m.user_id===row.user_id)?.display_name??'Membro'} · {labels[row.action]}</strong><small>{row.budget_limit_cents!==null?'Limite '+new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(row.budget_limit_cents/100):'Sem acesso à cobrança'}{row.expires_at?' · Expira em '+new Date(row.expires_at).toLocaleDateString('pt-BR'):''}</small></span>{owner&&<Button variant="outline" size="small" disabled={busy} onClick={()=>void revoke(row)}>Revogar</Button>}</div>)}</section>
    {owner&&<form className="panel form delegation-form" onSubmit={save}><div className="form-row"><label>Pessoa<select name="userId" required defaultValue=""><option value="" disabled>Selecione um membro</option>{members.map(m=><option key={m.user_id} value={m.user_id}>{m.display_name}</option>)}</select></label><label>Permissão adicional<select value={action} onChange={e=>setAction(e.target.value)}>{permissionActions.map(a=><option value={a} key={a}>{labels[a]}</option>)}</select></label></div>{action==='ads.approve'&&<label>Limite por aprovação (R$)<input name="budget" type="number" required min="0" max="1000000000" step="0.01" placeholder="0,00"/></label>}<p className="form-note">Delegar define quem pode aprovar. Cada peça ou campanha ainda exige sua própria aprovação de versão. A delegação não ativa anúncios nem libera pagamento do SaaS.</p><Button type="submit" disabled={busy}>{busy?'Salvando…':'Conceder permissão'}</Button></form>}
  </>;
}
