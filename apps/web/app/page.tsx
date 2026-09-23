import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowRight, Building2, Check, Layers3, ShieldCheck, Sparkles, Users } from 'lucide-react';
import styles from './home.module.css';

export const metadata: Metadata = {
  title: 'Askadia — Mais clareza para o seu marketing',
  description: 'Conheça a Askadia: um espaço para organizar empresas, equipes e o marketing de academias e estúdios. Acesse o sistema pelo login.',
};

export default function HomePage() {
  return <div className={styles.site}>
    <a href="#conteudo" className={styles.skip}>Pular para o conteúdo</a>
    <header className={styles.header}>
      <div className={styles.headerInner}>
        <Link href="/" className={styles.brand} aria-label="Askadia, início"><span className="brand-mark" aria-hidden="true">a</span><span>askadia.</span></Link>
        <nav aria-label="Navegação principal" className={styles.nav}><a href="#sobre">Sobre a Askadia</a><a href="#possibilidades">O sistema</a><a href="#perguntas">Perguntas</a></nav>
        <Link href="/login" className="button button-primary">Entrar no sistema <ArrowRight size={15} aria-hidden="true"/></Link>
      </div>
    </header>
    <main id="conteudo">
      <section className={styles.hero} aria-labelledby="titulo">
        <div className={styles.heroCopy}>
          <span className={styles.eyebrow}>SUA AGÊNCIA DE MARKETING COM IA</span>
          <h1 id="titulo">Seu próximo passo.<br/><span>Com mais clareza.</span></h1>
          <p>Uma agência de marketing com IA para academias e estúdios. Apresente seu negócio, construa sua estratégia e acompanhe cada próximo passo em um só lugar.</p>
          <div className={styles.actions}><Link href="/login" className="button button-primary">Entrar no sistema <ArrowRight size={16} aria-hidden="true"/></Link><a href="#sobre" className={styles.textLink}>Conhecer a Askadia <ArrowRight size={15} aria-hidden="true"/></a></div>
          <div className={styles.heroNote}><ShieldCheck size={16} aria-hidden="true"/><span>Cada empresa no seu espaço. Sua equipe na mesma direção.</span></div>
        </div>
        <div className={styles.art} aria-hidden="true">
          <div className={styles.halo}/><div className={styles.orbit}/><div className={styles.pearl}/><div className={styles.pearlSmall}/>
          <div className={styles.artCard}><span className={styles.artIcon}><Layers3 size={21}/></span><div><strong>Espaço para suas ideias.</strong><span>Clareza para o próximo passo.</span></div></div>
          <span className={styles.artCaption}>SIMPLES NA FORMA. INTENCIONAL EM CADA DETALHE.</span>
        </div>
      </section>
      <section id="sobre" className={styles.about} aria-labelledby="sobre-titulo">
        <span className={styles.eyebrow}>MENOS DISPERSÃO. MAIS DIREÇÃO.</span>
        <div className={styles.aboutGrid}><h2 id="sobre-titulo">Seu negócio tem identidade.<br/><span>Seu marketing também precisa ter.</span></h2><div><p>A Askadia reúne o perfil da empresa, estratégia, criação de conteúdo e acompanhamento comercial em uma experiência organizada para academias e estúdios.</p><p>A jornada começa em uma conversa: a Askadia conhece seu negócio e usa as informações confirmadas para propor sua estratégia e campanhas. Conteúdos, publicação e investimentos passam pelas aprovações de quem você autorizar.</p></div></div>
      </section>
      <section id="possibilidades" className={styles.features} aria-labelledby="recursos-titulo">
        <div className={styles.sectionHeading}><div><span className={styles.eyebrow}>UM ESPAÇO QUE ACOMPANHA VOCÊ</span><h2 id="recursos-titulo">Organização que começa pela base.</h2></div><span className={styles.status}>Disponível no sistema</span></div>
        <div className={styles.cards}>
          <article className={styles.card}><Building2 size={25} strokeWidth={1.5} aria-hidden="true"/><h3>Cada empresa, seu espaço.</h3><p>Cadastre seus negócios e alterne entre eles, mantendo dados e acessos organizados por empresa.</p><span><Check size={14} aria-hidden="true"/>Gestão de empresas</span></article>
          <article className={styles.card}><Users size={25} strokeWidth={1.5} aria-hidden="true"/><h3>Uma equipe. Papéis claros.</h3><p>Convide pessoas, defina permissões e acompanhe o histórico das ações importantes.</p><span><Check size={14} aria-hidden="true"/>Equipe e acessos</span></article>
          <article className={styles.card}><Layers3 size={25} strokeWidth={1.5} aria-hidden="true"/><h3>Ideias que ficam com você.</h3><p>Apresente seu negócio em uma conversa com progresso salvo. Revise e confirme o perfil que orientará sua estratégia.</p><span><Check size={14} aria-hidden="true"/>Perfil e conversa persistidos</span></article>
        </div>
        <div className={styles.evolution}><Sparkles size={22} strokeWidth={1.5} aria-hidden="true"/><div><h3>Da conversa ao próximo passo.</h3><p>Confirme o perfil da academia, revise a estratégia e acompanhe a criação de textos e artes no calendário. Conecte seus canais para atendimento e revise sua página antes de publicar. Publicações nas redes e anúncios dependem das integrações e aprovações indicadas em cada etapa.</p></div><span className={styles.status}>Você acompanha e aprova</span></div>
      </section>
      <section id="perguntas" className={styles.faq} aria-labelledby="perguntas-titulo"><div><span className={styles.eyebrow}>ANTES DO PRÓXIMO PASSO</span><h2 id="perguntas-titulo">Bom saber.</h2></div><div className={styles.questions}>
        <details><summary>Para quem é a Askadia?</summary><p>O foco inicial são proprietários e equipes de academias e estúdios que querem organizar seus negócios e sua operação de marketing.</p></details>
        <details><summary>Posso cadastrar mais de uma empresa?</summary><p>Sim. Uma área de trabalho pode reunir várias empresas. Os dados e as permissões são separados para cada negócio.</p></details>
        <details><summary>Criar uma conta ou empresa gera cobrança?</summary><p>Não. O cadastro cria seu acesso e a empresa em rascunho. A contratação de assinaturas ainda não está habilitada nesta etapa.</p></details>
        <details><summary>Como entro no sistema?</summary><p>Use o botão “Entrar no sistema” para acessar a página de login. Se ainda não tiver uma conta, escolha “Criar conta” nessa página e confirme seu e-mail.</p></details>
      </div></section>
      <section className={styles.finalCta}><span className={styles.eyebrow}>PENSADO PARA CRESCER COM VOCÊ</span><h2>Seu espaço está aqui.</h2><p>Entre na Askadia e organize o próximo passo do seu negócio.</p><Link href="/login" className="button button-primary">Entrar no sistema <ArrowRight size={16} aria-hidden="true"/></Link></section>
    </main>
    <footer className={styles.footer}><Link href="/" className={styles.brand} aria-label="Askadia, início"><span className="brand-mark" aria-hidden="true">a</span><span>askadia.</span></Link><p>Marketing com intenção.</p><a href="#sobre">Sobre a Askadia</a><Link href="/login">Login <ArrowRight size={14} aria-hidden="true"/></Link></footer>
  </div>;
}
