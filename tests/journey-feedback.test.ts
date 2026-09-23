import {describe,it,expect} from 'vitest';
import {readApiResponse} from '../apps/web/lib/response';
import {currentCalendarDate,calendarMonth,shiftCalendarMonth} from '../apps/web/lib/calendar-navigation';
describe('Customer feedback during proxy failures',()=>{
 it('keeps a usable message when a deployment returns an HTML gateway error',async()=>{
  await expect(readApiResponse(new Response('<html>upstream unavailable</html>',{status:502}))).rejects.toThrow('temporariamente indisponível');
 });
 it('preserves version conflicts and validation messages',async()=>{
  await expect(readApiResponse(new Response(JSON.stringify({message:'O site mudou. Atualize a página.'}),{status:409}))).rejects.toThrow('O site mudou');
  await expect(readApiResponse(new Response(JSON.stringify({message:['Informe o nome','Confira o telefone']}),{status:400}))).rejects.toThrow('Informe o nome · Confira o telefone');
 });
 it('handles expired sessions even when the gateway returns no JSON',async()=>{
  await expect(readApiResponse(new Response('',{status:401}))).rejects.toThrow('sessão expirou');
 });
 it('does not report success for an invalid payload',async()=>{
  await expect(readApiResponse(new Response('unexpected html'))).rejects.toThrow('resposta do serviço');
  await expect(readApiResponse(new Response(JSON.stringify({ok:true})))).resolves.toEqual({ok:true});
 });
});
describe('Calendar navigation uses the current company day',()=>{
 it('uses Sao Paulo day at the UTC month boundary',()=>{
  expect(currentCalendarDate(new Date('2026-10-01T01:00:00Z'))).toBe('2026-09-30');
  expect(currentCalendarDate(new Date('2026-10-01T03:01:00Z'))).toBe('2026-10-01');
 });
 it('moves between years and accepts only valid bounded month queries',()=>{
  expect(shiftCalendarMonth('2026-12',1)).toBe('2027-01');
  expect(shiftCalendarMonth('2026-01',-1)).toBe('2025-12');
  expect(calendarMonth('2026-09')).toBe('2026-09');
  for(const v of ['2026-13','2026-00','2026-1','0010-01','2026-09-02'])expect(calendarMonth(v)).toBeNull();
 });
});
