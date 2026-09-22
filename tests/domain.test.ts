import { describe, expect, it } from 'vitest';
import { companySchema, contentSchema, normalizePhone, reviseContent } from '../packages/contracts/src';
import { addLead, approveContent, emptyWorkspace, moveOpportunity, readWorkspace, saveContent } from '../apps/web/lib/workspace';
const a = companySchema.parse({ id: '00000000-0000-4000-8000-000000000001', name: 'Empresa A', segment: 'Academia', status: 'draft' });
const b = companySchema.parse({ ...a, id: '00000000-0000-4000-8000-000000000002', name: 'Empresa B' });
const state = () => ({ ...emptyWorkspace(), companies: [a, b], activeCompanyId: a.id });
const fields = { name: 'Contato de teste', phone: '(11) 99999-1234', email: '', interest: 'Pilates' };
const content = () => contentSchema.parse({ id: '00000000-0000-4000-8000-000000000003', companyId: a.id, title: 'Aula experimental', caption: 'Teste', date: '', format: 'Imagem', version: 1, status: 'review', approvedVersion: null });
describe('Local domain guardrails — not server authorization', () => {
  it('creates drafts without a subscription', () => { expect(a.status).toBe('draft'); expect(a).not.toHaveProperty('subscription'); });
  it('normalizes equivalent Brazilian phones', () => { expect(normalizePhone(fields.phone)).toBe('+5511999991234'); expect(normalizePhone('+55 11 99999-1234')).toBe('+5511999991234'); });
  it('rejects incomplete phones', () => { expect(() => normalizePhone('123')).toThrow(); });
  it('reuses a contact in the same company, preserves two opportunities', () => {
    const one = addLead(state(), a.id, fields); const two = addLead(one, a.id, { ...fields, interest: 'Musculação' });
    expect(two.contacts).toHaveLength(1); expect(two.opportunities).toHaveLength(2);
    expect(two.opportunities[0]?.contactId).toBe(two.opportunities[1]?.contactId);
  });
  it('never merges the same phone across companies', () => {
    const next = addLead(addLead(state(), a.id, fields), b.id, fields);
    expect(next.contacts).toHaveLength(2); expect(next.contacts[0]?.id).not.toBe(next.contacts[1]?.id);
  });
  it('never merges contacts only by name', () => {
    const next = addLead(addLead(state(), a.id, { ...fields, phone: '' }), a.id, { ...fields, phone: '' });
    expect(next.contacts).toHaveLength(2);
  });
  it('rejects an unknown company', () => { expect(() => addLead(state(), 'invalid', fields)).toThrow(); });
  it('rejects cross-company stage changes', () => {
    const next = addLead(state(), a.id, fields);
    expect(() => moveOpportunity(next, b.id, next.opportunities[0]!.id, 'Qualificado')).toThrow();
  });
  it('records loss reason and preserves history on reopening', () => {
    const next = addLead(state(), a.id, fields); const id = next.opportunities[0]!.id;
    expect(() => moveOpportunity(next, a.id, id, 'Perdido')).toThrow();
    const lost = moveOpportunity(next, a.id, id, 'Perdido', 'Horário incompatível');
    const reopened = moveOpportunity(lost, a.id, id, 'Em atendimento');
    expect(reopened.opportunities[0]?.history.map(h => h.stage)).toEqual(['Novo', 'Perdido', 'Em atendimento']);
    expect(reopened.opportunities[0]?.history[1]?.reason).toBe('Horário incompatível');
  });
  it('blocks enrollment confirmation without authenticated workflow', () => {
    const next = addLead(state(), a.id, fields);
    expect(() => moveOpportunity(next, a.id, next.opportunities[0]!.id, 'Matriculado')).toThrow();
  });
  it('approves only the current review version and owning company', () => {
    const next = saveContent(state(), a.id, content());
    expect(() => approveContent(next, b.id, content().id, 1)).toThrow();
    expect(() => approveContent(next, a.id, content().id, 2)).toThrow();
    const approved = approveContent(next, a.id, content().id, 1);
    expect(approved.contents[0]?.approvedVersion).toBe(1);
  });
  it('editing invalidates approval', () => {
    const approved = { ...content(), status: 'approved' as const, approvedVersion: 1 };
    const revised = reviseContent(approved, { title: 'Nova oferta', caption: 'Mudou', date: '', format: 'Imagem' });
    expect(revised.version).toBe(2); expect(revised.status).toBe('draft'); expect(revised.approvedVersion).toBeNull();
  });
  it('rejects cross-company content overwrite', () => {
    const next = saveContent(state(), a.id, content());
    expect(() => saveContent(next, b.id, { ...content(), companyId: b.id })).toThrow();
  });
  it('rejects malformed saved state without silently returning an empty workspace', () => {
    expect(() => readWorkspace('{ broken')).toThrow(); expect(() => readWorkspace('{"version":999}')).toThrow();
    expect(readWorkspace(null)).toEqual(emptyWorkspace());
  });
});
