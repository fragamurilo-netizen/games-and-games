(function(){
 'use strict';
 var cfg=window.GOFastSearch;if(!cfg)return;
 var busy=false,timer=null,lastBatch='',lastChecked=0;
 var fmt=new Intl.NumberFormat('pt-BR',{maximumFractionDigits:1});
 function schedule(ms){clearTimeout(timer);if(!document.hidden)timer=setTimeout(refresh,ms);}
 function selected(){
  var all=Array.from(document.querySelectorAll('.go-pi-index[data-post-id]')).filter(function(el){return el.closest('tr')?.dataset.goPublished!=='0'&&el.getClientRects().length;});
  var visible=all.filter(function(el){var r=el.getBoundingClientRect();return r.bottom>0&&r.top<innerHeight+600;});
  return (visible.length?visible:all).slice(0,20);
 }
 async function refresh(){
  if(busy||document.hidden)return;
  var cells=selected();if(!cells.length){schedule(60000);return;}
  var batch=cells.map(function(el){return el.dataset.postId;}).join(',');
  if(batch===lastBatch&&Date.now()-lastChecked<60000){schedule(60000-(Date.now()-lastChecked));return;}
  busy=true;var controller=new AbortController(),timeout=setTimeout(function(){controller.abort();},12000);
  try{
   var body=new URLSearchParams({action:'go_fast_search',nonce:cfg.nonce});cells.forEach(function(el){body.append('post_ids[]',el.dataset.postId);});
   var response=await fetch(cfg.url,{method:'POST',credentials:'same-origin',cache:'no-store',body:body,signal:controller.signal});var j=await response.json();
   if(!response.ok||!j.success)throw new Error(j.data?.message||'Google indisponível');
   var data=j.data||{};lastBatch=batch;lastChecked=Date.now();
   cells.forEach(function(el){
    var d=data.rows?.[el.dataset.postId];if(!d)return;
    el.dataset.fastSearch=String(data.checked_at);el.classList.remove('is-loading');
    var badge=el.querySelector('.go-pi-index-badge'),state=el.querySelector('.go-pi-serp-state'),detail=el.querySelector('.go-pi-serp-detail');
    var recent=d.impressions>0&&d.position>0,p=recent?d.position:d.fallback_position,imp=recent?d.impressions:d.fallback_impressions;
    var checked=new Date(data.checked_at*1000).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'});
    if(p>0&&imp>0){
     var tone=p<=3?'excellent':p<=10?'good':p<=20?'mid':p<=50?'weak':'poor';
     if(badge){badge.className='go-pi-index-badge is-pos-'+tone;badge.textContent='#'+fmt.format(p);}
     if(state)state.textContent=recent?'Posição recente · 24h':'Posição média · 7d';
     if(detail)detail.textContent=fmt.format(imp)+' impressões'+(recent&&d.latest_hour?' · até '+d.latest_hour.slice(5,16):'')+' · consultado '+checked+(recent?' · preliminar':'');
    }else{
     if(badge){badge.className='go-pi-index-badge is-muted';badge.textContent='Aguardando dados';}
     if(state)state.textContent='Google ainda não retornou uma amostra';
     if(detail)detail.textContent='Consultado '+checked+' · atualização automática';
    }
    el.title='Consulta direta à API horária do Search Console. Dados preliminares com atraso do Google; ausência de amostra não confirma zero impressões nem desindexação.';
    var tr=el.closest('tr');if(tr){tr.dataset.goSerp=p>0&&imp>0?'1':'0';tr.dataset.goSearchImpressions=String(imp||0);tr.dataset.goSerpPosition=String(p||0);}
   });
  }catch(e){
   cells.forEach(function(el){var detail=el.querySelector('.go-pi-serp-detail');if(detail&&!detail.textContent.includes('nova tentativa'))detail.textContent+=' · nova tentativa em 1 min';el.title=e.name==='AbortError'?'Google demorou a responder; dados anteriores preservados.':e.message;});
  }finally{clearTimeout(timeout);busy=false;schedule(60000);}
 }
 document.addEventListener('visibilitychange',function(){if(document.hidden)clearTimeout(timer);else schedule(100);});
 var scrollTimer;window.addEventListener('scroll',function(){clearTimeout(scrollTimer);scrollTimer=setTimeout(function(){if(!busy)schedule(300);},1500);},{passive:true});
 document.getElementById('go-pv-refresh')?.addEventListener('click',function(){lastChecked=0;schedule(0);});
 schedule(200);
})();
