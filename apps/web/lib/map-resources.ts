/** A rejected Google authorization can leave partially initialized map objects.
 * Their setters may throw on teardown; that must not crash the surrounding CRM. */
export function releaseMapResources(resources:Array<()=>void>){
 for(const release of resources){try{release();}catch{/* Best-effort teardown of a third-party object. */}}
}
