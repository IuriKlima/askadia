// Numeric WhatsApp identifiers are placeholders, never inferred phone numbers.
export function meaningfulContactName(value:unknown):string|null {
 if(typeof value!=='string')return null;
 const name=value.trim().slice(0,150);
 return name&&/[\p{L}]/u.test(name)&&!/@(lid|s\.whatsapp\.net|g\.us)$/.test(name)?name:null;
}
export function preferredContactName(current:string,candidate:unknown){return meaningfulContactName(current)??meaningfulContactName(candidate)??current;}
