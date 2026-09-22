import console from 'node:console';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
export function buildInboxMigration(){
 const legacy=readFileSync('supabase/migrations/202609210006_crm_handoff.sql','utf8').replace(/^begin;\s*/i,'').replace(/commit;\s*$/i,'');
 const inbox=readFileSync('supabase/migrations/202609220001_inbox.sql','utf8').replace(/^begin;$/m,'').replace(/^commit;$/m,'');
 return `begin;\ndo $install$ begin\nif to_regclass('public.company_conversations') is null then\n execute $legacy$${legacy}$legacy$;\nend if;\nend $install$;\n${inbox}\ncommit;\n`;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){mkdirSync('.local',{recursive:true});writeFileSync('.local/askadia-caixa-entrada.sql',buildInboxMigration());console.log('Migração preparada em .local/askadia-caixa-entrada.sql');}
