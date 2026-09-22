export function authConfigured(){return Boolean(process.env.SUPABASE_URL && (process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY));}
export function authConfig(){
  if(!authConfigured()) throw new Error('Autenticação não configurada.');
  return {url:process.env.SUPABASE_URL!,key:(process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY)!};
}
export function appOrigin(){return process.env.WEB_ORIGIN || 'http://127.0.0.1:3000';}
export function safeAuthDestination(value:string|null){return value==='/auth/update-password'||Boolean(value&&/^\/workspace#invite=[a-f0-9]{64}$/.test(value)) ? value! : '/entrada';}
