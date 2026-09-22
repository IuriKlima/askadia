import {describe,it,expect} from 'vitest';
import {preferredContactName} from '../apps/api/src/inbox/contact-name';
import {normalizeChats} from '../apps/api/src/inbox/evolution';
describe('CRM contact identity',()=>{
 it('replaces numeric placeholders while preserving genuine CRM names',()=>{
  expect(preferredContactName('166743565668471','Luciana')).toBe('Luciana');
  expect(preferredContactName('+55 (11) 99999-8888','João')).toBe('João');
  expect(preferredContactName('Nome cadastrado','Outro nome')).toBe('Nome cadastrado');
  expect(preferredContactName('166743565668471',null)).toBe('166743565668471');
  expect(preferredContactName('166743565668471','5511999998888@s.whatsapp.net')).toBe('166743565668471');
 });
 it('uses contact names and only accepts incoming sender names',()=>{
  const jid='166743565668471@lid';
  expect(normalizeChats([{remoteJid:jid,name:'Luciana',pushName:'166743565668471'}])[0]?.name).toBe('Luciana');
  expect(normalizeChats([{remoteJid:jid,lastMessage:{key:{fromMe:true},pushName:'Minha empresa'}}])[0]?.name).toBe('166743565668471');
  expect(normalizeChats([{remoteJid:jid,lastMessage:{key:{fromMe:false},pushName:'Luciana'}}])[0]?.name).toBe('Luciana');
  expect(normalizeChats([{remoteJid:jid,lastMessage:{key:{},pushName:'Remetente desconhecido'}}])[0]?.name).toBe('166743565668471');
 });
});
