import {describe,expect,it} from 'vitest';
import {billingObservation} from '../apps/api/src/campaigns/billing';
describe('Meta billing observations',()=>{
 it('never treats an active account as proof of credit',()=>{expect(billingObservation({account_status:1})).toMatchObject({status:'unverified',accountStatus:1});});
 it('distinguishes a restriction from an unavailable result',()=>{expect(billingObservation({account_status:3})).toMatchObject({status:'restricted'});expect(billingObservation({})).toMatchObject({status:'unavailable',accountStatus:null});expect(billingObservation({account_status:'1'}).status).toBe('unavailable');});
});
