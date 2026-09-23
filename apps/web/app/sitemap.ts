import type {MetadataRoute} from 'next';
export default function sitemap():MetadataRoute.Sitemap{return ['','/lp/marketing-fitness','/lp/atendimento-fitness','/sobre','/contato','/suporte'].map(path=>({url:'https://askadia.com.br'+path,changeFrequency:'monthly',priority:path===''?1:path.startsWith('/lp/')?.8:.5}));}
