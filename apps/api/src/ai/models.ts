export const agentModelDefaults={strategy:'gpt-6-astra',orchestrator:'gpt-6-astra',site:'gpt-6-astra',ads:'gpt-6-astra',copy:'gpt-6-sol',chat:'gpt-6-luna',search:'gpt-6-luna',attendance:'gpt-6-luna'} as const;
const variables={strategy:'OPENAI_MODEL_STRATEGY',orchestrator:'OPENAI_MODEL_ORCHESTRATOR',site:'OPENAI_MODEL_SITE',ads:'OPENAI_MODEL_ADS',copy:'OPENAI_MODEL_COPY',chat:'OPENAI_MODEL_CHAT',search:'OPENAI_MODEL_SEARCH',attendance:'OPENAI_MODEL_ATTENDANCE'} as const;
/** Resolve at call time: dotenv is loaded after application imports. */
export function agentModel(role:keyof typeof agentModelDefaults){return process.env[variables[role]]?.trim()||agentModelDefaults[role];}
