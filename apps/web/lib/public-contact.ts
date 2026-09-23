/** Only explicitly public business channels belong here. Never use an account owner's email as a fallback. */
export function publicContact(){
 const rawPhone=process.env.PUBLIC_SALES_WHATSAPP?.replace(/\D/g,'')??'';
 const email=(value:string|undefined)=>value&&/^[^\s@?&#]+@[^\s@?&#]+\.[^\s@?&#]+$/.test(value)?value:'';
 const salesEmail=email(process.env.PUBLIC_CONTACT_EMAIL);
 return {whatsapp:/^\d{10,15}$/.test(rawPhone)?rawPhone:'',salesEmail,supportEmail:email(process.env.PUBLIC_SUPPORT_EMAIL)||salesEmail};
}
