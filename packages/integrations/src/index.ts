export const providers = [
  { id: 'gemini', name: 'Nano Banana Pro · Gemini', category: 'Design com IA', description: 'Imagens e variações com referências e identidade da empresa.' },
  { id: 'openai', name: 'OpenAI', category: 'Inteligência artificial', description: 'Estratégias, propostas de tráfego pago, textos e triagem com contexto da sua empresa.' },
  { id: 'instagram', name: 'Instagram', category: 'Conteúdo e atendimento', description: 'Publicação, mensagens e indicadores da sua conta profissional.' },
  { id: 'whatsapp', name: 'WhatsApp', category: 'Atendimento', description: 'Conversas e encaminhamento de leads para sua equipe.' },
  { id: 'meta', name: 'Meta Ads', category: 'Mídia paga', description: 'Campanhas supervisionadas e captura de novos contatos.' },
  { id: 'google', name: 'Google Ads', category: 'Mídia paga', description: 'Campanhas de pesquisa e acompanhamento de resultados.' },
  { id: 'places', name: 'Google Places', category: 'Pesquisa', description: 'Descoberta de concorrentes locais, com fontes verificáveis.' },
  { id: 'analytics', name: 'Google Analytics', category: 'Resultados', description: 'Indicadores do site a partir de uma propriedade GA4 autorizada.' },
  { id: 'asaas', name: 'Asaas', category: 'Assinaturas', description: 'Assinatura individual e acompanhamento de pagamentos.' },
  { id: 'resend', name: 'Resend', category: 'Notificações', description: 'Convites e avisos transacionais por e-mail.' },
] as const;
export type ProviderId = typeof providers[number]['id'];
export interface AuthorizedOperation {
  companyId: string; actorId: string; connectionId: string; idempotencyKey: string;
  approvedVersionId: string;
}
export interface ProviderAdapter {
  readonly id: ProviderId;
  readonly status: 'unconfigured' | 'sandbox' | 'connected';
  health(): Promise<{ available: boolean; reason?: string }>;
}
/** Disabled deliberately: no simulated provider success or external side effects. */
export class UnconfiguredAdapter implements ProviderAdapter {
  readonly status = 'unconfigured' as const;
  constructor(readonly id: ProviderId) {}
  async health() { return { available: false, reason: 'Credencial e homologação pendentes.' }; }
  async execute(_operation: AuthorizedOperation): Promise<never> {
    throw new Error(`PROVIDER_NOT_CONFIGURED:${this.id}`);
  }
}

export const platformProviders:readonly ProviderId[]=['openai','gemini','places','asaas','resend'];

export * from './reporting';
