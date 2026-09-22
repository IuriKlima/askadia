import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { authConfig,authConfigured } from './lib/auth/config';
export async function proxy(request:NextRequest){
  let response=NextResponse.next({request});
  if(!authConfigured()) return response;
  const {url,key}=authConfig();
  const client=createServerClient(url,key,{
    cookieOptions:{httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax',path:'/'},
    cookies:{
      getAll:()=>request.cookies.getAll(),
      setAll(values){
        for(const {name,value} of values) request.cookies.set(name,value);
        response=NextResponse.next({request});
        for(const {name,value,options} of values) response.cookies.set(name,value,options);
      },
    },
  });
  // Validate with the Auth server, refreshing cookies when needed.
  await client.auth.getUser();
  response.headers.set('Cache-Control','private, no-store');
  return response;
}
export const config={matcher:['/dashboard/:path*','/resultados/:path*','/api/dashboard/:path*','/workspace/:path*','/api/identity/:path*','/auth/update-password','/admin/:path*','/acompanhamento/carteira/:path*','/operacao/:path*','/api/operations/:path*']};
