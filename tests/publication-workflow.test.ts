import {describe,it,expect} from 'vitest';
import type {CalendarItem} from '@askadia/contracts';
import {publicationStage} from '../apps/web/lib/publication-workflow';
describe('Publication workflow uses the current content revision',()=>{
 const item={id:'item',revision:2,format:'carrossel',status:'draft',details:{slides:[{},{}]}} as CalendarItem;
 it('keeps a carousel in creation until every current slide exists',()=>{
  expect(publicationStage(item,[{item_id:'item',revision:1,frame:0},{item_id:'item',revision:2,frame:1}],[])).toBe(1);
  expect(publicationStage(item,[{item_id:'item',revision:2,frame:0},{item_id:'item',revision:2,frame:1}],[])).toBe(2);
 });
 it('requires a current video and version-specific approval before programming',()=>{
  const video={...item,format:'video',status:'approved',approved_revision:1} as CalendarItem;
  expect(publicationStage(video,[],[{item_id:'item',revision:1}])).toBe(1);
  expect(publicationStage(video,[],[{item_id:'item',revision:2}])).toBe(2);
  expect(publicationStage({...video,approved_revision:2},[],[{item_id:'item',revision:2}])).toBe(4);
 });
});
