import {confirmedLocationAnswers} from '../apps/web/lib/onboarding-location';
import type {PlaceOption,ProfileFacts} from '@askadia/contracts';
import {afterEach,describe,expect,it,vi} from 'vitest';
import {createRequire} from 'node:module';
import {QuestionForm} from '../apps/web/components/onboarding-questionnaire';
const require=createRequire(new URL('../apps/web/package.json',import.meta.url));const React=require('react');const {renderToStaticMarkup}=require('react-dom/server');
afterEach(()=>vi.unstubAllGlobals());
import {questionnaireAnswer,questionAllowsSkip} from '../apps/web/lib/onboarding-questions';
describe('Guided questionnaire answers',()=>{
 it('keeps typed business names intact and persists only the named field',()=>{
  const answer=questionnaireAnswer('identity',[],'Academia em Movimento');
  expect(answer.answers).toEqual({name:{value:'Academia em Movimento',status:'provided'}});
 });
 it('combines multiple choices and custom details without losing either',()=>{
  expect(questionnaireAnswer('services',['Musculação','Pilates','Musculação'],'Alongamento').answers)
   .toEqual({services:{value:'Musculação\nPilates\nAlongamento',status:'provided'}});
 });
 it('accepts a custom answer without forcing a suggested choice',()=>{
  expect(questionnaireAnswer('businessType',[],'Escola de dança').answers).toEqual({businessType:{value:'Escola de dança',status:'provided'}});
 });
 it('rejects empty answers, invalid CEP and conflicting single choices',()=>{
  expect(()=>questionnaireAnswer('identity',[],' ')).toThrow('Escolha');
  expect(()=>questionnaireAnswer('postalCode',[],'12345')).toThrow('8 dígitos');
  expect(()=>questionnaireAnswer('objective',['Atrair novos alunos','Melhorar a retenção dos alunos'],'')).toThrow('opções');
  expect(()=>questionnaireAnswer('services',['Opção adulterada'],'')).toThrow('opções');
  expect(questionAllowsSkip('identity')).toBe(false);expect(questionAllowsSkip('objective')).toBe(false);expect(questionAllowsSkip('postalCode')).toBe(true);
 });
});

describe('Questionnaire controls',()=>{
 it('renders multiple choice and a custom-answer option without conversation history',()=>{
  vi.stubGlobal('React',React);
  const html=renderToStaticMarkup(React.createElement(QuestionForm,{step:'services',onSave:vi.fn()}));
  expect((html.match(/type="checkbox"/g)??[])).toHaveLength(6);
  expect(html).toContain('Outra resposta ou complementar');expect(html).not.toContain('role="log"');
 });
 it('restores saved choices and free text, and prevents read-only edits',()=>{
  vi.stubGlobal('React',React);
  const html=renderToStaticMarkup(React.createElement(QuestionForm,{step:'services',initial:'Pilates\nAlongamento',disabled:true,onSave:vi.fn()}));
  expect(html).toMatch(/<input[^>]*type="checkbox"[^>]*checked/);
  expect(html).toContain('Alongamento');expect(html).toMatch(/<fieldset[^>]*disabled/);expect(html).toMatch(/<textarea[^>]*disabled/);
 });
});

describe('Google location confirmation',()=>{
 it('uses the selected business address and CEP while preserving other answers',()=>{
  const place={id:'place_test',name:'Academia teste',address:'Endereço confirmado',city:'São Paulo, SP',postalCode:'01310-100',latitude:0,longitude:0,url:'https://maps.google.com',attributions:[]} as PlaceOption;
  const answers=confirmedLocationAnswers(place,{postalCode:{value:'37002-000',status:'provided'},address:{value:'Endereço anterior',status:'provided'},hours:{value:'24h',status:'provided'}} as ProfileFacts);
  expect(answers).toMatchObject({postalCode:{value:'01310-100',status:'provided'},address:{value:'Endereço confirmado',status:'provided'},city:{value:'São Paulo, SP',status:'provided'}});
  expect(answers.hours).toBeUndefined();
 });
 it('requires a real city and avoids invalidating location for CEP formatting only',()=>{
  const place={id:'place_test',address:'Rua X',city:null,postalCode:'01310-100'} as PlaceOption;
  expect(()=>confirmedLocationAnswers(place,{})).toThrow('cidade');
  expect(confirmedLocationAnswers(place,{postalCode:{value:'01310100',status:'provided'}} as ProfileFacts,'São Paulo, SP').postalCode).toBeUndefined();
 });
});
