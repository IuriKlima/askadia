'use client';
import { Button } from '@askadia/ui';
export default function ErrorPage({ reset }: { reset: () => void }) { return <main className="error-page"><h1>Não foi possível abrir seu espaço.</h1><p>Tente novamente. Seus rascunhos locais não serão apagados.</p><Button onClick={reset}>Tentar novamente</Button></main>; }