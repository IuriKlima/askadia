import {expect,it,vi} from 'vitest';
import {releaseMapResources} from '../apps/web/lib/map-resources';
it('keeps competitor selection usable after Google rejects authorization and a marker cannot detach',()=>{
 const marker={set map(_value:null){throw new TypeError("Cannot read properties of undefined (reading 'getRootNode')");}};
 const remainingMarker=vi.fn(),circle=vi.fn();
 expect(()=>releaseMapResources([()=>{marker.map=null;},remainingMarker,circle])).not.toThrow();
 expect(remainingMarker).toHaveBeenCalledOnce();expect(circle).toHaveBeenCalledOnce();
});
