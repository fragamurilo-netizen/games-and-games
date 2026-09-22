(function () {
 'use strict';
 var cfg=window.GOPostViews;if(!cfg)return;
 var timer=null,controller=null,busy=false,stable=0,lastInputAt=Date.now(),idle=false,lastFetchAt=Date.now();
 var format=new Intl.NumberFormat('pt-BR');
 // Deliberately conservative: the table is already painted server-side, so the
 // browser only checks again once a minute, backs off to five minutes when
 // nothing changes, and stops completely on hidden/idle tabs.
 var base=Math.max(60000,Number(cfg.poll)||60000);
 var maxDelay=Math.max(base,Number(cfg.maxPoll)||300000);
 var idleAfter=Math.max(120000,Number(cfg.idleAfter)||180000);

 function nextDelay(){return Math.min(maxDelay,base*Math.pow(2,Math.min(stable,3)));}
 function schedule(ms){clearTimeout(timer);if(document.hidden)return;if(Date.now()-lastInputAt>idleAfter){idle=true;return;}timer=setTimeout(function(){refresh(false);},Math.max(500,ms));}
 function wake(){lastInputAt=Date.now();if(idle&&!document.hidden){idle=false;stable=0;schedule(1500);}}
 function numberValue(el){return Number(el&&el.dataset?el.dataset.value:0)||0;}
 function setNumber(el,value){
  if(!el)return false;
  value=Number(value)||0;
  var changed=numberValue(el)!==value||el.textContent==='—';
  if(changed){el.dataset.value=String(value);el.textContent=format.format(value);}
  return changed;
 }
 function stamp(asOf){
  if(!asOf)return 'Atualização automática';
  var when=new Date(asOf*1000),diff=Math.max(0,Date.now()-when.getTime());
  if(diff<8000)return 'Atualizado agora';
  return 'Atualizado '+when.toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'});
 }
 function spin(on){var b=document.getElementById('go-pv-refresh');if(b)b.classList.toggle('is-spinning',!!on);}
 function insightNode(tag,className,text){var el=document.createElement(tag);if(className)el.className=className;if(text!==undefined&&text!==null)el.textContent=String(text);return el;}
 function renderInsight(cell,success){
  var pop=cell&&cell.querySelector?cell.querySelector('[data-go-pv-success-popover]'):null;if(!pop)return;success=success||{};pop.textContent='';
  var head=insightNode('div','go-pv__insight-head'),headCopy=insightNode('div',''),score=success.score===null||success.score===undefined?'':(' · '+String(Math.round(Number(success.score)||0))+'/100');headCopy.appendChild(insightNode('strong','',String(success.label||'Avaliando')+score));headCopy.appendChild(insightNode('small','',String(success.confidenceNote||('Confiança '+String(success.confidence||'baixa')))));head.appendChild(headCopy);var conf=insightNode('span','go-pv__confidence is-'+String(success.confidence||'baixa'),String(success.confidence||'baixa'));head.appendChild(conf);pop.appendChild(head);
  if(success.summary)pop.appendChild(insightNode('div','go-pv__insight-summary',success.summary));
  function section(title,items,ordered,extraClass){items=Array.isArray(items)?items.filter(Boolean):[];if(!items.length)return;var box=insightNode('div','go-pv__insight-section'+(extraClass?' '+extraClass:''));box.appendChild(insightNode('b','',title));var list=document.createElement(ordered?'ol':'ul');items.slice(0,ordered?4:5).forEach(function(item){list.appendChild(insightNode('li','',item));});box.appendChild(list);pop.appendChild(box);}
  section('O que aconteceu',success.facts||success.diagnostics,false,'go-pv__insight-section--snapshot');section('O que os sinais sugerem',success.reasons,false,'');section('Faça agora',success.actions,true,'go-pv__insight-section--actions');
  var details=document.createElement('details');details.className='go-pv__insight-method';var summary=document.createElement('summary');summary.textContent='Como esta nota foi calculada';details.appendChild(summary);details.appendChild(insightNode('p','','A análise é carregada apenas quando você pede, para não pesar a lista de Posts.'));details.appendChild(insightNode('p','','Base: '+String(success.basis||'amostra recente')+'. Search recente é apenas um sinal complementar.'));pop.appendChild(details);
 }
 function setSuccess(cell,success){
  var el=cell&&cell.querySelector?cell.querySelector('[data-go-pv-success]'):null;if(!el)return;
  success=success||{};var allowed=['excellent','good','median','weak','poor','evaluating'];var level=String(success.level||'evaluating');if(allowed.indexOf(level)===-1)level='evaluating';
  el.className='go-pv__success is-'+level;el.title=String(success.title||'Avaliando desempenho.');el.setAttribute('aria-label','Desempenho: '+String(success.label||'Avaliando'));renderInsight(cell,success);
 }
 function placeInsight(button,pop){if(!button||!pop)return;pop.hidden=false;pop.style.visibility='hidden';pop.style.left='12px';pop.style.top='12px';var r=button.getBoundingClientRect(),w=pop.offsetWidth||340,h=pop.offsetHeight||220,left=Math.min(Math.max(12,r.right-w),Math.max(12,window.innerWidth-w-12)),top=r.bottom+7;if(top+h>window.innerHeight-12)top=Math.max(12,r.top-h-7);pop.style.left=Math.round(left)+'px';pop.style.top=Math.round(top)+'px';pop.style.visibility='visible';button.setAttribute('aria-expanded','true');}
 function closeInsight(wrap){if(!wrap)return;var button=wrap.querySelector('[data-go-pv-success-help]'),pop=wrap.querySelector('[data-go-pv-success-popover]');if(pop){pop.hidden=true;pop.style.visibility='';}if(button)button.setAttribute('aria-expanded','false');}

 async function refresh(force){
  if(busy||document.hidden)return;
  force=!!force;
  var cells=Array.from(document.querySelectorAll('[data-go-pv]'));if(!cells.length)return;
  busy=true;spin(true);controller=new AbortController();var timeout=setTimeout(function(){controller.abort();},force?12000:8000);
  try{
   var body=new URLSearchParams({action:'go_post_views_fast',nonce:cfg.nonce,details:'0',force:force?'1':'0'});
   cells.forEach(function(c){body.append('ids[]',c.dataset.goPv);});
   var response=await fetch(cfg.url,{method:'POST',body:body,credentials:'same-origin',cache:'no-store',signal:controller.signal,headers:{'X-Requested-With':'XMLHttpRequest'}});
   var result=await response.json();if(!response.ok||!result.success)throw new Error('http-'+response.status);
   var data=result.data||{},changedAny=false;lastFetchAt=Date.now();
   cells.forEach(function(c){
    var n=data.counts&&data.counts[c.dataset.goPv];if(!n)return;
    var changed=false;
    if(data.ready){
     changed=setNumber(c.querySelector('[data-go-pv-today]'),n.today)||changed;
     changed=setNumber(c.querySelector('[data-go-pv-total]'),n.total)||changed;
     var tr=c.closest('tr');if(tr){tr.dataset.goToday=String(Number(n.today)||0);tr.dataset.goTotal=String(Number(n.total)||0);tr.dataset.goViewsSource='burst';}
    }
    c.classList.toggle('is-loading',!data.ready);
    var state=c.querySelector('[data-go-pv-state]');if(state)state.textContent=data.ready?'automático':'sincronizando';
    if(changed)changedAny=true;
   });
   var status=document.getElementById('go-pv-freshness');if(status)status.textContent=data.ready?stamp(data.as_of):'Sincronizando histórico…';
   try{document.dispatchEvent(new CustomEvent('go:postviews-updated',{detail:{asOf:Number(data.as_of)||0,forced:!!data.forced_sync}}));}catch(_e){}
   stable=changedAny?0:stable+1;
   schedule(nextDelay());
  }catch(e){
   var s=document.getElementById('go-pv-freshness');if(s)s.textContent='Dados preservados · nova tentativa depois';
   stable=Math.min(stable+1,3);schedule(nextDelay());
  }finally{clearTimeout(timeout);busy=false;spin(false);controller=null;}
 }

 async function loadDetails(cell){
  if(!cell||cell.dataset.goPvDetails==='loaded'||cell.dataset.goPvDetails==='loading')return;
  cell.dataset.goPvDetails='loading';
  var pop=cell.querySelector('[data-go-pv-success-popover]');if(pop){pop.textContent='Carregando análise sob demanda…';}
  var localController=new AbortController(),timeout=setTimeout(function(){localController.abort();},10000);
  try{
   var body=new URLSearchParams({action:'go_post_views_fast',nonce:cfg.nonce,details:'1',force:'0'});body.append('ids[]',cell.dataset.goPv);
   var response=await fetch(cfg.url,{method:'POST',body:body,credentials:'same-origin',cache:'no-store',signal:localController.signal,headers:{'X-Requested-With':'XMLHttpRequest'}});
   var result=await response.json();if(!response.ok||!result.success)throw new Error('detail');
   var data=result.data||{},n=data.counts&&data.counts[cell.dataset.goPv];
   if(n&&n.success){setSuccess(cell,n.success);cell.dataset.goPvDetails='loaded';}
   else{throw new Error('empty');}
  }catch(_e){
   cell.dataset.goPvDetails='error';if(pop)pop.textContent='Não foi possível carregar a análise agora. Os números de views continuam funcionando normalmente.';
  }finally{clearTimeout(timeout);}
 }

 document.addEventListener('focusin',function(e){var b=e.target.closest&&e.target.closest('[data-go-pv-success-help]');if(!b)return;var cell=b.closest('[data-go-pv]');loadDetails(cell);placeInsight(b,b.parentNode.querySelector('[data-go-pv-success-popover]'));});
 document.addEventListener('focusout',function(e){var wrap=e.target.closest&&e.target.closest('.go-pv__success-wrap');if(!wrap)return;setTimeout(function(){if(!wrap.contains(document.activeElement))closeInsight(wrap);},0);});
 document.addEventListener('click',function(e){var b=e.target.closest&&e.target.closest('[data-go-pv-success-help]');if(!b)return;e.preventDefault();e.stopPropagation();var p=b.parentNode.querySelector('[data-go-pv-success-popover]'),cell=b.closest('[data-go-pv]');if(b.getAttribute('aria-expanded')==='true'){closeInsight(b.parentNode);}else{loadDetails(cell);placeInsight(b,p);}});
 window.addEventListener('scroll',function(){document.querySelectorAll('.go-pv__success-wrap').forEach(closeInsight);},{passive:true});
 window.addEventListener('resize',function(){document.querySelectorAll('.go-pv__success-wrap').forEach(closeInsight);},{passive:true});

 ['pointerdown','keydown','wheel','touchstart'].forEach(function(type){document.addEventListener(type,wake,{passive:true,capture:true});});
 var manual=document.getElementById('go-pv-refresh');
 if(manual)manual.addEventListener('click',function(){lastInputAt=Date.now();idle=false;stable=0;refresh(true);});
 document.addEventListener('visibilitychange',function(){
  if(document.hidden){clearTimeout(timer);if(controller)controller.abort();return;}
  lastInputAt=Date.now();idle=false;
  var elapsed=Date.now()-lastFetchAt;schedule(elapsed>=base?1500:Math.max(1500,base-elapsed));
 });
 window.addEventListener('pagehide',function(){clearTimeout(timer);if(controller)controller.abort();});
 window.addEventListener('pageshow',function(){lastInputAt=Date.now();idle=false;schedule(base);});
 // No immediate AJAX on page load: PHP has already rendered the current indexed
 // values. This avoids a duplicate request every time an editor opens Posts.
 schedule(base);
})();
