/** Shared vector interpretation of the brand direction supplied on 25 September. */
export function BrandMark({className = ''}:{className?:string}) {
  return <svg className={`askadia-symbol ${className}`} viewBox="0 0 64 64" fill="currentColor" aria-hidden="true" focusable="false">
    <path d="M24.5 10.1c3.3-5.8 11.7-5.8 15 0l22 38.1c3.3 5.8-.9 13-7.5 13h-7.1a8.7 8.7 0 0 1-7.5-4.3L25.8 33.3a9.2 9.2 0 0 0-8-4.6H13.7z"/>
    <path d="M12 32.5h10.3c5.6 0 9 6.1 6.2 10.9L20.7 57a8.4 8.4 0 0 1-7.2 4.2H8.2c-6.4 0-10.4-7-7.2-12.5z"/>
  </svg>;
}

export function BrandWordmark() {
  return <span className="askadia-wordmark"><BrandMark/><span>askadia</span></span>;
}

/** Decorative ribbon, based on the rounded angles in the Askadia symbol. */
export function BrandContours({className = ''}:{className?:string}) {
  return <svg className={`askadia-contours ${className}`} viewBox="0 0 800 600" fill="none" aria-hidden="true" focusable="false">
    <path d="M-90 420 198 94Q223 66 264 66H445Q486 66 509 101L704 399Q725 432 765 432H880"/>
    <path d="M-90 514 196 189Q222 160 263 160H396Q437 160 460 196L655 492Q677 525 718 525H880"/>
    <path d="M632-80V93Q632 131 654 164L719 261Q741 293 782 293H880"/>
  </svg>;
}
