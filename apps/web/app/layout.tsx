import type { Metadata } from 'next';
import './globals.css';
import './brand.css';
export const metadata: Metadata = { title: 'Askadia — Conversa que vira ação', description: 'Estratégia, conteúdos, campanhas e atendimento com IA para colocar o marketing da sua academia em movimento.' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="pt-BR"><body>{children}</body></html>;
}
