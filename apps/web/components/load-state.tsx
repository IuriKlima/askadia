import {LoaderCircle,TriangleAlert} from 'lucide-react';
import {Button} from '@askadia/ui';
import s from './journey.module.css';
export function LoadState({error,retry,label='Carregando informações…'}:{error?:string;retry?:()=>void;label?:string}){
 return <div className={s.loadState} role={error?'alert':'status'}>{error?<TriangleAlert size={22}/>:<LoaderCircle size={22} className={s.spinner}/>}<div><strong>{error?'Não foi possível carregar':label}</strong>{error&&<p>{error}</p>}</div>{error&&retry&&<Button variant="outline" onClick={retry}>Tentar novamente</Button>}</div>;
}
