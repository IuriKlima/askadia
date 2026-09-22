import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Askadia — Marketing com intenção', description: 'Seu espaço para planejar, criar e acompanhar o marketing da sua empresa fitness.' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="pt-BR"><body>{children}</body></html>;
}