/* Melhoria progressiva: todo o texto já está presente no HTML servido. */
(()=>{'use strict';
 document.querySelectorAll('.go-wolverine').forEach(root=>{
  if(root.dataset.wxReady)return;root.dataset.wxReady='true';
  const normalize=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  root.querySelectorAll('[data-wx-enhance]').forEach(el=>el.hidden=false);
  const form=root.querySelector('[data-wx-filter]');
  if(form){
   const rows=[...root.querySelectorAll('.wx-bookrow')],query=form.querySelector('input'),select=form.querySelector('select'),count=root.querySelector('[data-wx-count]'),empty=root.querySelector('[data-wx-empty]');
   rows.forEach(row=>row.dataset.wxSearch=normalize(row.textContent));
   const filter=()=>{let n=0;const q=normalize(query.value.trim());rows.forEach(row=>{const visible=(!q||row.dataset.wxSearch.includes(q))&&(!select.value||row.dataset.route===select.value);row.hidden=!visible;if(visible)n++});count.textContent=n+' de '+rows.length+' entradas';empty.hidden=n>0};
   form.addEventListener('submit',event=>event.preventDefault());query.addEventListener('input',filter);select.addEventListener('change',filter);
  }
  const theme=root.querySelector('[data-wx-theme-toggle]');
  if(theme){
   const initial=()=>{const h=document.documentElement.dataset.theme;return root.dataset.wxTheme||(h&&h.startsWith('dark')?'dark':h&&h.startsWith('light')?'light':matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light')};
   const set=value=>{root.dataset.wxTheme=value;theme.setAttribute('aria-pressed',String(value==='dark'));theme.textContent=value==='dark'?'Modo claro':'Modo escuro'};
   let saved;try{saved=localStorage.getItem('go-wolverine-theme')}catch(e){}set(saved==='dark'||saved==='light'?saved:initial());
   theme.addEventListener('click',()=>{const value=root.dataset.wxTheme==='dark'?'light':'dark';set(value);try{localStorage.setItem('go-wolverine-theme',value)}catch(e){}});
  }
  const copy=root.querySelector('[data-wx-copy]');
  if(copy){if(!/^https?:$/.test(location.protocol)||!navigator.clipboard){copy.hidden=true}else{copy.addEventListener('click',async()=>{const status=root.querySelector('[data-wx-status]');try{await navigator.clipboard.writeText(location.href.split('#')[0]);status.textContent='Link copiado.'}catch(e){status.textContent='Copie o endereço pela barra do navegador.'}})}}
 });
})();
