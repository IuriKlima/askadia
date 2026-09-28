import {describe,it,expect} from 'vitest';
import {stageReady,strategyTimedOut,type StrategyBrief,type JourneyStage} from '../packages/contracts/src/journey-progress';
import type {GeneratedStrategy} from '../packages/contracts/src/strategy';
import {result} from '../apps/api/src/identity/service';
const output={positioning:'Proposta local de teste',objectives:[],calendar:[],ads:[],keywords:[],unknowns:[]} as GeneratedStrategy;
const brief:StrategyBrief={id:'brief',generation:2,profile_version:6,status:'review',created_at:'2026-09-28T16:00:00Z',output};
const stage=(n:number,data:unknown):JourneyStage=>({stage:n,data,basis:'a'.repeat(32),approved:false,approvedAt:null});
describe('Guided flow readiness and recovery',()=>{
 it('does not confuse a reserved brief with a proposal ready for approval',()=>{
  const waiting=stage(2,{id:brief.id,generation:brief.generation,output:null,analysisCurrent:true});
  expect(Boolean(waiting.data)).toBe(true);
  expect(stageReady(waiting,{...brief,status:'generating',output:null})).toBe(false);
  expect(stageReady(stage(2,{...waiting.data as object,output}),brief)).toBe(true);
 });
 it('requires the displayed generation, finished status and current competitor analysis',()=>{
  const ready=stage(2,{id:brief.id,generation:brief.generation,output,analysisCurrent:true});
  for(const status of ['generating','failed','draft','superseded'])expect(stageReady(ready,{...brief,status})).toBe(false);
  expect(stageReady(ready,{...brief,generation:3})).toBe(false);
  expect(stageReady(ready,{...brief,id:'another-brief'})).toBe(false);
  expect(stageReady(ready,null)).toBe(false);
  expect(stageReady(stage(2,{...ready.data as object,analysisCurrent:false}),brief)).toBe(false);
 });
 it('waits for actual calendar dates and campaign proposals',()=>{
  expect(stageReady(stage(3,[]))).toBe(false);
  expect(stageReady(stage(3,[{date:null}]))).toBe(false);
  expect(stageReady(stage(3,[{date:'2026-10-05'}]))).toBe(true);
  expect(stageReady(stage(4,{whatsapp:null,messages:null}))).toBe(false);
  expect(stageReady(stage(4,{whatsapp:[],messages:[]}))).toBe(false);
  expect(stageReady(stage(4,{whatsapp:[{}],messages:[{}]}))).toBe(true);
  expect(stageReady(stage(5,[]))).toBe(false);
  expect(stageReady(stage(5,[{}]))).toBe(true);
 });
 it('offers recovery only after the server generation lock expires',()=>{
  const running={...brief,status:'generating',output:null};
  expect(strategyTimedOut(running,Date.parse(brief.created_at)+299_000)).toBe(false);
  expect(strategyTimedOut(running,Date.parse(brief.created_at)+301_000)).toBe(true);
  expect(strategyTimedOut(brief,Date.parse(brief.created_at)+301_000)).toBe(false);
  expect(strategyTimedOut({...running,created_at:'invalid'})).toBe(false);
 });
 it('turns expected waiting and version conflicts into actionable messages',()=>{
  for(const message of ['Strategy not ready','Suggestions not ready'])expect(()=>result({data:null,error:{code:'22023',message,details:'',hint:''}})).toThrow('A proposta ainda está sendo preparada');
  expect(()=>result({data:null,error:{code:'40001',message:'Generation already running',details:'',hint:''}})).toThrow('A estratégia já está sendo gerada');
  expect(()=>result({data:null,error:{code:'40001',message:'Proposal changed; review current version',details:'',hint:''}})).toThrow('A proposta foi atualizada');
 });
});
