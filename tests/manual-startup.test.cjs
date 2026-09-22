'use strict';
/**
 * Offline integration: actual PHP-rendered units, policy, head/footer scripts
 * and production runtimes; real jsdom HTML parsing, templates and selectors.
 * Geometry, clocks and provider replies are explicit deterministic doubles.
 * No network requests, creative access, paid impressions or browser layout.
 */
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {JSDOM} = require(process.env.GO_JSDOM_MODULE || 'jsdom');
const theme = process.env.GO_THEME_ROOT || path.resolve(__dirname, '..');
const php = process.env.GO_TEST_PHP || 'php';
const source = fs.readFileSync(path.join(theme,'assets/js/go-ads-runtime.js'),'utf8');
const mini = fs.readFileSync(path.join(theme,'assets/js/go-ads-runtime.min.js'),'utf8');
const lean = fs.readFileSync(path.join(theme,'assets/js/go-ads-runtime.lean.js'),'utf8');
const fixture = (args=[]) => JSON.parse(execFileSync(php,[path.join(__dirname,'manual-startup-fixture.php'),...args],{encoding:'utf8',env:{...process.env,GO_THEME_ROOT:theme}}));
const standard = fixture();
const gated = fixture(['--gate']);
const disabled = fixture(['--off']);
const scripts = html => [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
const results = [];
async function test(name, fn) {
  try { await fn(); results.push({name,passed:true}); console.log('PASS '+name); }
  catch(error) { results.push({name,passed:false,error:error.stack}); console.log('FAIL '+name+' '+error.stack); }
}
function scene(data=standard, placements=['article-prime'], width=1280) {
  const prose='<p>'+('Texto editorial da reportagem. '.repeat(8))+'</p>';
  const markup=placements.map(p=>data.units[p]||'').join('');
  const dom=new JSDOM('<!doctype html><html><head></head><body class="go-verge single-post"><main class="go-article__content" data-go-single-content>'+prose.repeat(4)+markup+prose.repeat(43)+'</main></body></html>',{url:'https://example.test/article/',runScripts:'outside-only'});
  const w=dom.window,d=w.document;
  let clock=0, nextTimer=0, allowed=false;
  const timers=new Map(), fetched=[], pushes=[], errors=[];
  w.addEventListener('error',event=>errors.push(String(event.error||event.message)));
  Object.defineProperty(d,'readyState',{configurable:true,get:()=> 'interactive'});
  Object.defineProperty(d,'visibilityState',{configurable:true,get:()=> 'visible'});
  Object.defineProperty(w,'innerWidth',{configurable:true,get:()=>width});
  Object.defineProperty(w,'innerHeight',{configurable:true,get:()=>800});
  Object.defineProperty(w.performance,'now',{configurable:true,value:()=>clock});
  w.Date.now=()=>1700000000000+clock;
  w.setTimeout=(fn,delay=0)=>{let id=++nextTimer;timers.set(id,{fn,at:clock+Math.max(1,Number(delay)||0)});return id;};
  w.clearTimeout=id=>timers.delete(id);
  w.requestAnimationFrame=fn=>w.setTimeout(()=>fn(clock),16);
  w.cancelAnimationFrame=w.clearTimeout;
  w.GOAdsConsent={permitted:()=>allowed};
  w.matchMedia=query=>({matches:[...query.matchAll(/(min|max)-width\s*:\s*(\d+)px/g)].every(([,kind,n])=>kind==='min'?width>=Number(n):width<=Number(n)),media:query,addEventListener(){},removeEventListener(){},addListener(){},removeListener(){}});
  w.fetch=()=>{throw Error('Network requests forbidden in offline integration');};
  w.getComputedStyle=el=>({display:el.hidden?'none':'block',visibility:'visible',opacity:'1',position:'static',overflowX:'visible',overflowY:'visible',contentVisibility:'visible',paddingTop:'0px',paddingBottom:'0px',paddingLeft:'0px',paddingRight:'0px',minHeight:'0px',top:'auto',getPropertyValue(name){return el.style.getPropertyValue(name);}});
  const tops={'article-prime':400,'article-a1':3200,'sidebar-desktop':500,'topscroll':20};
  const rect=el=>{
    const host=el.closest?.('[data-go-ad-placement]');
    const placement=host?.getAttribute('data-go-ad-placement');
    const top=(placement?tops[placement]:0)-(w.pageYOffset||0);
    const side=placement==='sidebar-desktop';
    const boxWidth=side?300:Math.min(width-32,740);
    const height=['HTML','BODY','MAIN'].includes(el.tagName)?12000:el.tagName==='P'?130:280;
    const left=side?900:16;
    return {top,bottom:top+height,left,right:left+boxWidth,width:boxWidth,height,x:left,y:top};
  };
  w.Element.prototype.getBoundingClientRect=function(){return rect(this);};
  w.Element.prototype.getClientRects=function(){return [rect(this)];};
  for(const [prop,dimension] of [['clientWidth','width'],['offsetWidth','width'],['clientHeight','height'],['offsetHeight','height'],['scrollHeight','height']]){
    Object.defineProperty(w.HTMLElement.prototype,prop,{configurable:true,get(){return rect(this)[dimension];}});
  }
  const originalAppend=d.head.appendChild.bind(d.head);
  d.head.appendChild=node=>{if(node.tagName==='SCRIPT'&&node.src)fetched.push(node);return originalAppend(node);};
  w.adsbygoogle=[];
  w.adsbygoogle.push=()=>{
    const ins=[...d.querySelectorAll('ins.adsbygoogle[data-ad-slot]')].find(x=>!x.hasAttribute('data-adsbygoogle-status'));
    assert.ok(ins,'Each provider push must have one materialized publisher INS');
    pushes.push(ins.getAttribute('data-ad-slot'));
    ins.setAttribute('data-adsbygoogle-status','done');ins.setAttribute('data-ad-status','filled');
  };
  function evalHtml(html){for(const js of scripts(html))w.eval(js);}
  function evalMounts(){for(const script of [...d.querySelectorAll('[data-go-ad-placement] > script')]){Object.defineProperty(d,'currentScript',{configurable:true,get:()=>script});w.eval(script.textContent);}Object.defineProperty(d,'currentScript',{configurable:true,get:()=>null});}
  async function tick(ms=2000){const until=clock+ms;for(let n=0;n<10000;n++){const next=[...timers.entries()].filter(([,t])=>t.at<=until).sort((a,b)=>a[1].at-b[1].at)[0];if(!next){clock=until;await Promise.resolve();return;}timers.delete(next[0]);clock=next[1].at;next[1].fn();await Promise.resolve();}throw Error('Timer fixture exceeded 10000 callbacks');}
  function load(code=source){assert.equal(fetched.length,1,'Recovery has one publisher fetch');w.eval(code);fetched[0].onload();}
  return {w,d,dom,fetched,pushes,errors,tick,evalHtml,evalMounts,load,recover:()=>evalHtml(data.recovery),grant(){allowed=true;d.dispatchEvent(new w.Event('go:consent-change'));},close(){w.close();}};
}
(async()=>{
  await test('PHP reuses policy, prints recovery once and keeps global disable absolute',()=>{
    assert.equal(standard.enabled,true);assert.equal(standard.secondRecovery,'');
    assert.equal(disabled.enabled,false);assert.equal(disabled.head,'');assert.equal(disabled.recovery,'');
    assert.ok(Object.values(disabled.units).every(x=>x===''));
    assert.ok(standard.recovery.includes('go-ads-runtime.js?ver=5.5.3-'));
  });
  await test('Baseline missing head: PHP inert hosts remain unrequested after readiness and time',async()=>{
    const s=scene();s.evalMounts();s.d.dispatchEvent(new s.w.Event('DOMContentLoaded'));await s.tick(10000);
    assert.equal(s.w.GOAdsRuntime,undefined);assert.equal(s.pushes.length,0);assert.equal(s.fetched.length,0);
    assert.equal(s.d.querySelectorAll('template[data-go-ad-pending]').length,1);s.close();
  });
  for(const [name,code] of [['source',source],['min',mini],['lean',lean]]){
    await test('Missing head recovers with '+name+' runtime and exact PHP policy; one eligible request',async()=>{
      const s=scene();s.evalMounts();s.recover();assert.equal(s.fetched.length,1);
      assert.deepEqual(JSON.parse(JSON.stringify(s.w.GOAdsYieldConfig)),standard.config);
      s.load(code);await s.tick();assert.equal(typeof s.w.GOAdsRuntime.mount,'function');
      assert.equal(s.w.GOAdsRuntimeBoot.state,'ready');assert.equal(s.pushes.length,1);
      assert.equal(s.d.querySelectorAll('template[data-go-ad-pending]').length,0);assert.deepEqual(s.errors,[]);s.close();
    });
  }
  await test('Normal PHP head makes footer a no-op with no additional runtime fetch',async()=>{
    const s=scene();s.evalHtml(standard.head);s.evalMounts();s.recover();await s.tick();
    assert.equal(s.fetched.length,0);assert.equal(s.pushes.length,1);assert.deepEqual(s.errors,[]);s.close();
  });
  await test('PHP footer reconstructs policy when the head emitter never ran',async()=>{
    const data=fixture(['--skip-head']);assert.equal(data.head,'');
    const s=scene(data);s.evalMounts();s.recover();assert.deepEqual(JSON.parse(JSON.stringify(s.w.GOAdsYieldConfig)),data.config);
    s.load();await s.tick();assert.equal(s.pushes.length,1);assert.deepEqual(s.errors,[]);s.close();
  });
  await test('Recovery mounts all hosts and requests the next body unit as the reader reaches it',async()=>{
    const s=scene(standard,['article-prime','article-a1']);s.evalMounts();s.recover();s.load();await s.tick();
    assert.equal(s.w.GOAdsRuntime.inspect().counts.manual.mounted,2);assert.equal(s.pushes.length,1);
    s.w.pageYOffset=2700;s.d.documentElement.scrollTop=2700;s.w.dispatchEvent(new s.w.Event('scroll'));await s.tick();
    assert.equal(s.pushes.length,2);assert.equal(new Set(s.pushes).size,2);
    s.recover();s.w.GOAdsRuntime.scan(s.d);s.d.dispatchEvent(new s.w.Event('DOMContentLoaded'));await s.tick();
    assert.equal(s.fetched.length,1);assert.equal(s.pushes.length,2);assert.deepEqual(s.errors,[]);s.close();
  });
  for(const order of ['normal-first','recovery-first']){
    await test('Delayed normal head race '+order+' retains one API and one request per host',async()=>{
      const s=scene();s.evalMounts();s.recover();
      if(order==='normal-first'){s.evalHtml(standard.head);const api=s.w.GOAdsRuntime;s.load();assert.equal(s.w.GOAdsRuntime,api);}
      else{s.load();const api=s.w.GOAdsRuntime;s.evalHtml(standard.head);assert.equal(s.w.GOAdsRuntime,api);}
      s.recover();s.d.dispatchEvent(new s.w.Event('DOMContentLoaded'));s.d.dispatchEvent(new s.w.Event('go:content-updated'));await s.tick();
      assert.equal(s.fetched.length,1);assert.equal(s.pushes.length,1);assert.equal(s.w.GOAdsRuntimeBoot.state,'ready');assert.deepEqual(s.errors,[]);s.close();
    });
  }
  await test('Consent-gated missing-head recovery stays inert until grant, then requests once',async()=>{
    const s=scene(gated);s.evalMounts();s.recover();s.load();await s.tick();
    assert.equal(s.pushes.length,0);assert.equal(s.d.querySelectorAll('template[data-go-ad-pending]').length,1);
    s.grant();await s.tick();assert.equal(s.pushes.length,1);s.grant();await s.tick();assert.equal(s.pushes.length,1);s.close();
  });
  await test('Desktop-only sidebar remains inert on mobile after recovery',async()=>{
    const s=scene(standard,['sidebar-desktop'],390);s.evalMounts();s.recover();s.load();await s.tick();
    assert.equal(s.pushes.length,0);assert.equal(s.d.querySelectorAll('template[data-go-ad-pending]').length,1);s.close();
  });
  await test('Mobile-only Top Scroll remains inert on desktop after recovery',async()=>{
    const s=scene(standard,['topscroll'],1280);s.evalMounts();s.recover();s.load();await s.tick();
    assert.equal(s.pushes.length,0);assert.equal(s.d.querySelectorAll('template[data-go-ad-pending]').length,1);s.close();
  });
  await test('Load failure records error, leaves units inert, and does not retry',async()=>{
    const s=scene();s.evalMounts();s.recover();s.fetched[0].onerror();s.recover();s.d.dispatchEvent(new s.w.Event('go:content-updated'));await s.tick();
    assert.equal(s.fetched.length,1);assert.equal(s.w.GOAdsRuntimeBoot.error,'runtime-load-failed');assert.equal(s.pushes.length,0);s.close();
  });
  await test('Recovery load error after delayed normal startup keeps successful ready state',async()=>{
    const s=scene();s.evalMounts();s.recover();s.evalHtml(standard.head);s.fetched[0].onerror();await s.tick();
    assert.equal(s.w.GOAdsRuntimeBoot.state,'ready');assert.equal(s.w.GOAdsRuntimeBoot.error,null);assert.equal(s.pushes.length,1);s.close();
  });
  await test('No publisher host means no fetch; a later declarative host can recover',async()=>{
    const s=scene(standard,[]);s.recover();assert.equal(s.fetched.length,0);
    s.d.querySelector('main').insertAdjacentHTML('beforeend',standard.units['article-prime']);s.d.dispatchEvent(new s.w.Event('go:content-updated'));s.load();await s.tick();assert.equal(s.pushes.length,1);s.close();
  });
  await test('Incomplete existing API is reported without replacing a foreign runtime',async()=>{
    const s=scene();const foreign={version:'foreign'};s.w.GOAdsRuntime=foreign;s.recover();await s.tick();
    assert.equal(s.fetched.length,0);assert.equal(s.w.GOAdsRuntime,foreign);assert.equal(s.w.GOAdsRuntimeBoot.error,'runtime-api-incomplete');assert.equal(s.pushes.length,0);s.close();
  });
  const report={suite:'manual-startup-recovery',passed:results.filter(x=>x.passed).length,failed:results.filter(x=>!x.passed).length,browserLayout:false,geometry:'deterministic fixture, not measured',realNetworkRequests:0,realAdRequests:0,results};
  if (process.env.GO_TEST_REPORT) fs.writeFileSync(process.env.GO_TEST_REPORT,JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));process.exitCode=report.failed?1:0;
})();
