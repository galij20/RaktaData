const Logo = () => (
  <div style={{display:"flex",alignItems:"center",gap:"8px"}}>
    <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
      <path d="M14 3 C14 3 5 13 5 18 A9 9 0 0 0 23 18 C23 13 14 3 14 3Z" fill="#DC2626" opacity="0.15" stroke="#DC2626" strokeWidth="1.5"/>
      <path d="M14 7 C14 7 8 14 8 18 A6 6 0 0 0 20 18 C20 14 14 7 14 7Z" fill="#DC2626"/>
      <path d="M10 18 Q14 15 18 18" stroke="white" strokeWidth="1.5" fill="none" strokeLinecap="round"/>
    </svg>
    <span style={{fontFamily:"var(--font-head)",fontWeight:700,fontSize:"1.1rem"}}>Rakta<span style={{color:"var(--red)"}}>Data</span></span>
  </div>
);

export default Logo;
