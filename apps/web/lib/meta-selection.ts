const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const key=(companyId:string)=>'askadia:meta-selection:'+companyId;
export function metaSelectionStorage(){try{return window.sessionStorage;}catch{return null;}}
type SelectionStorage=Pick<Storage,'getItem'|'setItem'|'removeItem'>;
// Only an opaque selection ID is cached. The server still checks actor, company and expiry.
export function recoverMetaSelection(storage:SelectionStorage|null,companyId:string,fromUrl:string|null,now=Date.now()):string|null{
 let cached:{id?:string;expiresAt?:number}|null=null;
 try{cached=JSON.parse(storage?.getItem(key(companyId))??'null');}catch{/* Storage can be unavailable in private browsing. */}
 if(cached?.id===fromUrl&&typeof cached.expiresAt==='number'&&cached.expiresAt<=now){clearMetaSelection(storage,companyId);return null;}
 if(cached&&(!uuid.test(cached.id??'')||!Number.isFinite(cached.expiresAt)||(cached.expiresAt??0)<=now)){clearMetaSelection(storage,companyId);cached=null;}
 if(fromUrl&&uuid.test(fromUrl)){
  if(cached?.id===fromUrl)return fromUrl;
  try{storage?.setItem(key(companyId),JSON.stringify({id:fromUrl,expiresAt:now+10*60_000}));}catch{/* The URL remains a fallback. */}
  return fromUrl;
 }
 return cached?.id??null;
}
export function clearMetaSelection(storage:SelectionStorage|null,companyId:string){try{storage?.removeItem(key(companyId));}catch{/* No local storage is required for OAuth. */}}
