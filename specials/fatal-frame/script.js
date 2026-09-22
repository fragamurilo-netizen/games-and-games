/* Fatal Frame / Game Overdrive. All editorial content is server-rendered. */
(()=>{'use strict';
const root=document.getElementById('go-fatal-frame');if(!root||root.dataset.ffReady)return;root.dataset.ffReady='true';root.classList.add('ff-interactive');
// Real tabs: buttons, arrow keys, Home/End and ARIA state stay in sync.
function tabs(list){if(!list)return;const items=[...list.querySelectorAll('[role="tab"]')];const panels=items.map(b=>root.querySelector('#'+b.getAttribute('aria-controls')));if(panels.some(p=>!p))return;
function select(i,focus=false){items.forEach((b,n)=>{b.setAttribute('aria-selected',String(n===i));b.tabIndex=n===i?0:-1;panels[n].hidden=n!==i});if(focus){items[i].focus();items[i].scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'})}}
items.forEach((b,i)=>{b.addEventListener('click',()=>select(i));b.addEventListener('keydown',e=>{let n=i;if(e.key==='ArrowRight')n=(i+1)%items.length;else if(e.key==='ArrowLeft')n=(i+items.length-1)%items.length;else if(e.key==='Home')n=0;else if(e.key==='End')n=items.length-1;else return;e.preventDefault();select(n,true)})});list.hidden=false;select(0)}
tabs(root.querySelector('[data-ff-tabs]'));tabs(root.querySelector('[data-ff-route-tabs]'));
// Accessible native dialog, with direct-image links as the non-JS fallback.
const dialog=root.querySelector('dialog');const links=[...root.querySelectorAll('[data-ff-gallery]')];let index=0,opener=null,savedOverflow='';
if(dialog&&typeof dialog.showModal==='function'){
const full=dialog.querySelector('[data-ff-full]'),caption=dialog.querySelector('[data-ff-caption]'),count=dialog.querySelector('[data-ff-count]');
function show(i){index=(i+links.length)%links.length;const a=links[index],im=a.querySelector('img'),fig=a.closest('figure');full.src=a.href;full.alt=im?im.alt:'';caption.textContent=fig?.querySelector('figcaption')?.textContent||full.alt;count.textContent=(index+1)+' / '+links.length}
links.forEach((a,i)=>a.addEventListener('click',e=>{if(e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;e.preventDefault();opener=a;show(i);savedOverflow=document.documentElement.style.overflow;document.documentElement.style.overflow='hidden';dialog.showModal()}));
dialog.querySelector('[data-ff-close]').addEventListener('click',()=>dialog.close());dialog.querySelector('[data-ff-prev]').addEventListener('click',()=>show(index-1));dialog.querySelector('[data-ff-next]').addEventListener('click',()=>show(index+1));
dialog.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'){e.preventDefault();show(index-1)}if(e.key==='ArrowRight'){e.preventDefault();show(index+1)}});
dialog.addEventListener('click',e=>{if(e.target!==dialog)return;const b=dialog.getBoundingClientRect();if(e.clientX<b.left||e.clientX>b.right||e.clientY<b.top||e.clientY>b.bottom)dialog.close()});
dialog.addEventListener('close',()=>{document.documentElement.style.overflow=savedOverflow;opener?.focus({preventScroll:true})});}
// Follow the theme's fixed header, including the WordPress admin bar.
const nav=root.querySelector('.ff-nav'),progress=root.querySelector('.ff-progress span');const anchors=[...root.querySelectorAll('.ff-nav a[href^="#"]')];const sections=anchors.map(a=>root.querySelector(a.hash));let pending=false;
function offset(){let bottom=0;for(const el of document.querySelectorAll('#wpadminbar,#masthead,.site-header,.go-header,.go-site-header')){if(root.contains(el))continue;const style=getComputedStyle(el),r=el.getBoundingClientRect();if((style.position==='fixed'||style.position==='sticky')&&r.top<=35&&r.bottom>0&&r.height<220)bottom=Math.max(bottom,r.bottom)}root.style.setProperty('--ff-sticky-top',Math.round(bottom)+'px');return bottom}
function update(){pending=false;const top=offset(),rect=root.getBoundingClientRect(),distance=Math.max(1,root.offsetHeight-innerHeight),value=Math.min(1,Math.max(0,-rect.top/distance));if(progress)progress.style.transform='scaleX('+value+')';let current=-1;sections.forEach((s,i)=>{if(s&&s.getBoundingClientRect().top<=top+(nav?.offsetHeight||0)+140)current=i});anchors.forEach((a,i)=>{if(i===current)a.setAttribute('aria-current','location');else a.removeAttribute('aria-current')})}
function schedule(){if(!pending){pending=true;requestAnimationFrame(update)}}addEventListener('scroll',schedule,{passive:true});addEventListener('resize',schedule,{passive:true});update();
})();
