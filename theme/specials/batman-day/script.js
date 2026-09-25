(function(){
  'use strict';
  const root=document.getElementById('go-batman');
  if(!root||root.dataset.initialized==='true')return;
  root.dataset.initialized='true';
  const norm=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  let ticking=false;
  root.querySelectorAll('[data-switcher]').forEach(switcher=>{
    const buttons=Array.from(switcher.querySelectorAll(':scope > .gb-switchbar > [data-switch]'));
    const panels=Array.from(switcher.querySelectorAll(':scope > [data-panel]'));
    const activate=key=>{
      buttons.forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.switch===key)));
      panels.forEach(p=>p.hidden=p.dataset.panel!==key);
      updateProgress();
    };
    buttons.forEach(b=>b.addEventListener('click',()=>activate(b.dataset.switch)));
    if(buttons.length)activate(buttons[0].dataset.switch);
  });
  root.querySelectorAll('[data-catalog]').forEach(catalog=>{
    const records=Array.from(catalog.querySelectorAll('[data-record]'));
    const container=catalog.querySelector('.gb-records');
    const search=catalog.querySelector('[data-search-input]');
    const group=catalog.querySelector('[data-group-input]');
    const sort=catalog.querySelector('[data-sort-input]');
    const status=catalog.querySelector('[data-catalog-status]');
    const more=catalog.querySelector('[data-more]');
    const all=catalog.querySelector('[data-all]');
    const reset=catalog.querySelector('[data-reset]');
    const empty=catalog.querySelector('[data-empty]');
    records.forEach(r=>r._search=norm(r.dataset.search));
    let limit=12;
    const draw=(reorder=false)=>{
      const query=norm(search.value.trim());
      let ordered=records.slice();
      if(sort.value==='desc')ordered.sort((a,b)=>parseInt(b.dataset.year,10)-parseInt(a.dataset.year,10));
      else if(sort.value==='title')ordered.sort((a,b)=>a.querySelector('.gb-record-title').textContent.localeCompare(b.querySelector('.gb-record-title').textContent,'pt-BR'));
      else ordered.sort((a,b)=>parseInt(a.dataset.year,10)-parseInt(b.dataset.year,10));
      if(reorder)ordered.forEach(r=>container.appendChild(r));
      const matches=ordered.filter(r=>(!group.value||r.dataset.group===group.value)&&(!query||query.split(/\s+/).every(word=>r._search.includes(word))));
      const shown=new Set(matches.slice(0,limit));
      records.forEach(r=>{r.hidden=!shown.has(r);if(r.hidden)r.open=false;});
      status.textContent=matches.length+' '+(matches.length===1?'registro encontrado':'registros encontrados')+' · '+Math.min(matches.length,limit)+' visíveis';
      empty.hidden=matches.length>0;
      more.hidden=limit>=matches.length;
      all.hidden=matches.length<=12;
      all.textContent=limit>=matches.length?'Recolher lista':'Ver todos ('+matches.length+')';
      updateProgress();
    };
    search.addEventListener('input',()=>{limit=12;draw();});
    group.addEventListener('change',()=>{limit=12;draw();});
    sort.addEventListener('change',()=>{limit=12;draw(true);});
    more.addEventListener('click',()=>{limit+=12;draw();});
    all.addEventListener('click',()=>{const collapse=all.textContent==='Recolher lista';limit=collapse?12:records.length;draw();if(collapse)catalog.scrollIntoView({block:'start',behavior:'auto'});});
    reset.addEventListener('click',()=>{search.value='';group.value='';sort.value='asc';limit=12;draw(true);search.focus({preventScroll:true});});
    draw();
  });
  const storageKey='go-batman-day-2026-checklist';
  let saved={};
  let storageWorks=true;
  try{const data=JSON.parse(localStorage.getItem(storageKey)||'{}');if(data&&typeof data==='object'&&!Array.isArray(data))saved=data;}catch(e){storageWorks=false;}
  const checks=Array.from(root.querySelectorAll('[data-check]'));
  const checkStatus=root.querySelector('[data-check-status]');
  function renderChecks(){const count=checks.filter(c=>c.checked).length;checkStatus.textContent=count+' de '+checks.length+' sugestões marcadas. '+(storageWorks?'Sua lista fica salva neste navegador.':'Sua lista fica marcada durante esta visita.');}
  checks.forEach(c=>{c.checked=saved[c.dataset.check]===true;c.addEventListener('change',()=>{saved[c.dataset.check]=c.checked;try{localStorage.setItem(storageKey,JSON.stringify(saved));}catch(e){storageWorks=false;}renderChecks();});});
  renderChecks();
  const dialog=root.querySelector('.gb-lightbox');
  if(dialog&&typeof dialog.showModal==='function'){
    const image=dialog.querySelector('img');
    const caption=dialog.querySelector('p');
    const close=()=>dialog.close();
    root.querySelectorAll('[data-lightbox]').forEach(link=>link.addEventListener('click',e=>{
      e.preventDefault();
      image.src=link.querySelector('img').src;
      image.alt=link.querySelector('img').alt;
      caption.textContent=link.closest('figure').querySelector('figcaption').textContent;
      dialog.showModal();
    }));
    dialog.querySelector('button').addEventListener('click',close);
    dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)close();}});
    dialog.addEventListener('close',()=>{image.removeAttribute('src');image.alt='';});
  }
  const navLinks=Array.from(root.querySelectorAll('.gb-nav a'));
  const sections=navLinks.map(a=>root.querySelector(a.getAttribute('href'))).filter(Boolean);
  function updateProgress(){
    if(ticking)return;
    ticking=true;
    requestAnimationFrame(()=>{
      const progress=root.querySelector('.gb-progress');
      const rect=root.getBoundingClientRect();
      const range=root.offsetHeight-window.innerHeight;
      if(progress)progress.value=range>0?Math.max(0,Math.min(100,(-rect.top/range)*100)):100;
      if(typeof sections!=='undefined'){
        let current='';
        sections.forEach(s=>{if(s.getBoundingClientRect().top<=180)current=s.id;});
        navLinks.forEach(a=>{if(a.hash==='#'+current)a.setAttribute('aria-current','location');else a.removeAttribute('aria-current');});
      }
      ticking=false;
    });
  }
  root.querySelectorAll('details').forEach(d=>d.addEventListener('toggle',updateProgress));
  window.addEventListener('scroll',updateProgress,{passive:true});
  window.addEventListener('resize',updateProgress,{passive:true});
  if('ResizeObserver' in window)new ResizeObserver(updateProgress).observe(root);
  root.classList.add('gb-ready');
  updateProgress();
})();
