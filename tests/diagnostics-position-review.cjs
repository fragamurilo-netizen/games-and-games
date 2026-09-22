'use strict';
// HTML5 parsing/selection is real jsdom. Geometry below is a labelled stub:
// jsdom has no layout engine. No network resources or page scripts are loaded.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const jsdomPath=process.env.GO_JSDOM_MODULE || 'jsdom';
const {JSDOM}=require(jsdomPath);
const source=fs.readFileSync(process.env.GO_DIAGNOSTICS_SOURCE || path.resolve(__dirname,'../assets/js/go-ads-recovery-diagnostics.js'),'utf8');
const results=[];
function test(name,fn){try{fn();results.push({name,passed:true});}catch(e){results.push({name,passed:false,error:e.message});}}
function scene(body){
 const dom=new JSDOM('<!doctype html><html><head><title>Offline diagnostics</title></head><body>'+body+'</body></html>',{url:'https://example.test/article/?private=not-exported#fragment',runScripts:'outside-only'});
 const w=dom.window, counts={fetch:0,push:0,storage:0,iframeReads:0,styleReads:0,rectReads:0,observers:0};
 w.fetch=()=>{counts.fetch++;throw Error('network forbidden');};
 w.adsbygoogle={push(){counts.push++;throw Error('ad requests forbidden');}};
 for(const key of ['localStorage','sessionStorage'])Object.defineProperty(w,key,{get(){counts.storage++;throw Error('storage forbidden');}});
 for(const key of ['contentDocument','contentWindow'])Object.defineProperty(w.HTMLIFrameElement.prototype,key,{get(){counts.iframeReads++;throw Error('creative access forbidden');}});
 w.MutationObserver=function(){counts.observers++;throw Error('observer not expected');};
 w.Element.prototype.getBoundingClientRect=function(){counts.rectReads++;return{top:100,left:20,width:600,height:100};};
 w.getComputedStyle=()=>{counts.styleReads++;return{getPropertyValue:k=>({display:'block',visibility:'visible',opacity:'1',position:'static',height:'100px',width:'600px'}[k]||'none')};};
 const before=w.document.documentElement.outerHTML;
 w.eval(source);
 return{w,dom,counts,before,collect:()=>w.GOAdsDiagnostics.collectArticle()};
}
test('Boot installs only the on-demand function; no scan, geometry, network, storage or DOM mutation',()=>{
 const s=scene('<main class="go-article__content"><p>Editorial</p></main>');
 assert.equal(typeof s.w.GOAdsDiagnostics.collectArticle,'function');assert.deepEqual(s.counts,{fetch:0,push:0,storage:0,iframeReads:0,styleReads:0,rectReads:0,observers:0});assert.equal(s.w.document.documentElement.outerHTML,s.before);s.dom.window.close();
});
test('Read-only collection separates prose, auxiliary, manual-host and outside markers and ignores lookalike class names',()=>{
 const s=scene('<main class="go-article__content"><p id="p1">Primeira prosa.</p><div><p id="p2">Segunda prosa.</p></div><div class="google-auto-placed"><ins class="adsbygoogle" data-ad-slot="auto1" data-ad-status="filled"></ins></div><aside class="go-channel-invite"><p>Texto CTA</p><div class="google-auto-placed"><ins class="adsbygoogle"></ins></div></aside><div class="go-inline-related"><p>Related</p></div><aside data-go-ad-placement="article-a1"><p>Label</p><div class="google-auto-placed"><ins class="adsbygoogle"></ins><iframe src="https://invalid.test/creative"></iframe></div></aside><p id="duplicate">Prosa final.</p><span id="duplicate"></span><div class="google-auto-placed-lookalike"></div></main><footer><div class="google-auto-placed"><ins class="adsbygoogle"></ins></div><ins class="adsbygoogle"></ins></footer>');
 const r=s.collect();assert.equal(r.articleRoots,1);assert.equal(r.article.editorialParagraphs,3);assert.equal(r.article.directParagraphs,2);assert.equal(r.article.manualHosts,1);assert.equal(r.article.auxiliaryBlocks,2);assert.equal(r.autoPlacementMarkers.length,4);assert.deepEqual(Array.from(r.autoPlacementMarkers,x=>x.region),['article-prose','auxiliary','manual-host','outside-article']);assert.equal(r.unclassifiedAdsenseElements,1);assert.equal(r.article.duplicateIds[0].count,2);assert.equal(r.page,'https://example.test/article/');assert.equal(s.w.document.documentElement.outerHTML,s.before);assert.equal(s.counts.fetch+s.counts.push+s.counts.storage+s.counts.iframeReads+s.counts.observers,0);assert.ok(s.counts.styleReads>0);assert.equal(s.w.performance.getEntriesByType?.('resource')?.length||0,0);s.dom.window.close();
});
test('Exact support class is counted separately and does not match a prefix/suffix',()=>{
 const s=scene('<div class="go-author-lead__body"></div><main itemprop="articleBody"><p>Editorial</p><div class="go-author-lead__body"></div><div class="go-author-lead__body-extra"></div></main>');const r=s.collect();assert.equal(r.supportRequestedClassCount,2);assert.equal(r.supportRequestedClassInArticle,true);s.dom.window.close();
});
test('No article root remains an explicit null result, including an author archive containing the support class',()=>{
 const s=scene('<article class="go-author-lead"><div class="go-author-lead__body"><h2>Story card</h2><p>Excerpt</p></div></article>');const r=s.collect();assert.equal(r.article,null);assert.equal(r.articleRoots,0);assert.equal(r.supportRequestedClassCount,1);assert.equal(r.supportRequestedClassInArticle,null);s.dom.window.close();
});
test('Nested root selectors do not duplicate paragraphs and samples are bounded',()=>{
 const s=scene('<article itemprop="articleBody"><div class="go-article__content" data-go-single-content>'+Array.from({length:120},(_,i)=>'<p>P '+i+'</p>').join('')+'</div></article>');const r=s.collect();assert.equal(r.articleRoots,2);assert.equal(r.article.editorialParagraphs,120);assert.equal(r.article.paragraphSample.length,100);assert.equal(r.article.directParagraphs,0);s.dom.window.close();
});
test('AdSense loader observation strips client/query values and distinguishes lazy script type',()=>{
 const s=scene('<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-private&token=x"></script><script type="text/plain" data-cfasync="false" src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script><main class="go-article__content"><p>Prosa</p></main>');const r=s.collect();assert.equal(r.scripts.length,2);assert.equal(r.scripts[0].url,'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js');assert.equal(r.scripts[0].clientQualified,true);assert.equal(r.scripts[1].type,'text/plain');assert.equal(JSON.stringify(r).includes('ca-pub-private'),false);assert.equal(s.counts.push+s.counts.fetch,0);s.dom.window.close();
});
test('Even and odd paragraph medians describe lengths without including auxiliary copy',()=>{
 const s=scene('<main class="go-article__content"><p>aa</p><p>bbbbbb</p><aside class="go-channel-invite"><p>'+('x'.repeat(100))+'</p></aside></main>');assert.equal(s.collect().article.medianParagraphCharacters,4);s.w.document.querySelector('main').insertAdjacentHTML('beforeend','<p>cccccccccc</p>');assert.equal(s.collect().article.medianParagraphCharacters,6);s.dom.window.close();
});
test('The requested panel preserves article collection if manual inspect throws or returns a nonobject',()=>{
 for(const inspect of [()=>{throw Error('legacy inspector failure');},()=>null,()=>false,()=>42,()=>'',()=>[]]){
  const s=scene('<div id="wp-admin-bar-go-ads-inspect"><a href="#inspect">Inspect</a></div><main class="go-article__content"><p>Editorial</p></main>');s.w.GOAdsRuntime={inspect};s.w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};
  const editorialBefore=s.w.document.querySelector('main').outerHTML;s.w.document.querySelector('a').dispatchEvent(new s.w.MouseEvent('click',{bubbles:true,cancelable:true}));
  const rendered=JSON.parse(s.w.document.querySelector('dialog pre').textContent);assert.equal(rendered.articleStructure?.article?.editorialParagraphs,1);assert.equal(s.w.document.querySelector('main').outerHTML,editorialBefore);assert.equal(s.counts.fetch+s.counts.push+s.counts.storage+s.counts.iframeReads,0);s.dom.window.close();
 }
});
test('Published comparator CTA and editorial poll components are auxiliary rather than prose',()=>{
 const s=scene('<main class="go-article__content"><p>Editorial.</p><aside class="goc-article-compare"><div class="goc-article-compare__copy"><p>Compare produtos</p><div class="google-auto-placed"><ins class="adsbygoogle"></ins></div></div></aside><section class="ged-reader-tool ged-reader-poll"><p>Vote!</p><div class="google-auto-placed"><ins class="adsbygoogle"></ins></div></section></main>');const r=s.collect();assert.equal(r.article.editorialParagraphs,1);assert.equal(r.article.auxiliaryBlocks,2);assert.deepEqual(Array.from(r.autoPlacementMarkers,x=>x.region),['auxiliary','auxiliary']);assert.equal(s.w.document.documentElement.outerHTML,s.before);assert.equal(s.counts.fetch+s.counts.push+s.counts.storage+s.counts.iframeReads,0);s.dom.window.close();
});

function marker(id, status){return '<div id="'+id+'" class="google-auto-placed"><ins class="adsbygoogle"'+(status?' data-ad-status="'+status+'"':'')+'></ins></div>';}
function row(report,id){return report.autoPlacementMarkers.find(r=>r.id===id);}
function unchanged(s){assert.equal(s.w.document.documentElement.outerHTML,s.before);assert.equal(s.counts.fetch+s.counts.push+s.counts.storage+s.counts.iframeReads+s.counts.observers,0);}
test('DOM order separates before, between and after without using equal fixture rectangles',()=>{
 const s=scene('<main class="go-article__content">'+marker('before')+'<p id="first">Primeiro.</p>'+marker('middle','filled')+'<p id="last">Último.</p>'+marker('after')+'</main>');const r=s.collect();
 assert.equal(row(r,'before').prosePosition,'before-first');assert.equal(row(r,'before').nextEditorialParagraph.id,'first');assert.equal(row(r,'before').previousEditorialParagraph,null);
 assert.equal(row(r,'middle').prosePosition,'between');assert.equal(row(r,'middle').previousEditorialParagraph.id,'first');assert.equal(row(r,'middle').nextEditorialParagraph.id,'last');assert.equal(row(r,'middle').previousElement.id,'first');assert.equal(row(r,'middle').nextElement.id,'last');
 assert.equal(row(r,'after').prosePosition,'after-last');assert.equal(row(r,'after').previousEditorialParagraph.id,'last');assert.equal(row(r,'after').nextEditorialParagraph,null);assert.ok(r.autoPlacementMarkers.every(x=>x.region==='article-prose'));unchanged(s);s.w.close();
});
test('Auxiliary paragraphs before and after prose cannot invent editorial boundaries',()=>{
 const s=scene('<main class="go-article__content"><aside class="go-channel-invite"><p>CTA inicial.</p></aside>'+marker('before')+'<p id="only">Matéria.</p>'+marker('after')+'<aside class="go-inline-related"><p>Relacionado final.</p></aside></main>');const r=s.collect();assert.equal(row(r,'before').prosePosition,'before-first');assert.equal(row(r,'after').prosePosition,'after-last');assert.equal(r.article.proseReferenceParagraphs,1);unchanged(s);s.w.close();
});
test('Auxiliary, manual and outside markers cannot become between even with surrounding prose',()=>{
 const s=scene('<main class="go-article__content"><p>Antes.</p><aside class="go-inline-related">'+marker('aux')+'</aside><aside data-go-ad-placement="article-a1">'+marker('manual')+'</aside><p>Depois.</p></main>'+marker('outside'));const r=s.collect();
 for(const [id,region]of [['aux','auxiliary'],['manual','manual-host'],['outside','outside-article']]){assert.equal(row(r,id).region,region);assert.equal(row(r,id).prosePosition,null);assert.equal(row(r,id).previousEditorialParagraph,null);assert.equal(row(r,id).nextEditorialParagraph,null);}assert.equal(r.autoPlacementMarkerSummary.byProsePosition.between.markers,0);unchanged(s);s.w.close();
});
test('Separate editorial wrappers still establish previous and next paragraph identities',()=>{
 const s=scene('<main class="go-article__content"><section><p id="wrapped-first">Antes.</p></section><div>'+marker('wrapped')+'</div><section><p id="wrapped-last">Depois.</p></section></main>');const r=s.collect();assert.equal(row(r,'wrapped').prosePosition,'between');assert.equal(row(r,'wrapped').previousEditorialParagraph.id,'wrapped-first');assert.equal(row(r,'wrapped').nextEditorialParagraph.id,'wrapped-last');assert.equal(row(r,'wrapped').previousElement,null);unchanged(s);s.w.close();
});
test('A marker inserted dynamically inside an editorial P is inside-p rather than between',()=>{
 const s=scene('<main class="go-article__content"><p>Antes.</p><p id="contains">Prosa textual.</p><p>Depois.</p></main>');const n=s.w.document.createElement('div');n.id='inside';n.className='google-auto-placed';n.innerHTML='<ins class="adsbygoogle" data-ad-status="filled"></ins>';s.w.document.getElementById('contains').append(n);s.before=s.w.document.documentElement.outerHTML;const r=s.collect();assert.equal(row(r,'inside').prosePosition,'inside-p');assert.equal(row(r,'inside').containingEditorialParagraph.id,'contains');unchanged(s);s.w.close();
});
test('Empty and advertising paragraphs are not prose boundaries; textless article remains explicit no-p',()=>{
 const s=scene('<main class="go-article__content"><h2>Título</h2><ul><li>Conteúdo em lista.</li></ul><p> </p><ins class="adsbygoogle"><p>Texto do provedor.</p></ins><div data-go-ad-placement="p1"><p>Outro texto do provedor.</p></div>'+marker('none')+'<div class="google-auto-placed"><p>Texto otimizado.</p></div></main>');const r=s.collect();assert.equal(r.article.editorialParagraphs,1);assert.equal(r.article.proseReferenceParagraphs,0);assert.equal(row(r,'none').prosePosition,'no-p');unchanged(s);s.w.close();
});
test('Filled, optimized, unfilled and done-only INS stay independent of the same between position',()=>{
 const s=scene('<main class="go-article__content"><p>Antes.</p>'+marker('filled','filled')+marker('optimized','unfill-optimized')+marker('unfilled','unfilled')+'<div id="done" class="google-auto-placed"><ins class="adsbygoogle" data-adsbygoogle-status="done"><iframe></iframe></ins></div>'+marker('unknown','future-provider-state')+'<p>Depois.</p></main>');const r=s.collect();assert.ok(r.autoPlacementMarkers.every(x=>x.prosePosition==='between'));assert.deepEqual(JSON.parse(JSON.stringify(r.autoPlacementMarkerSummary.insStatuses)),{total:5,filled:1,'unfill-optimized':1,unfilled:1,unknown:2});assert.equal(r.autoPlacementMarkerSummary.byProsePosition.between.insStatuses.filled,1);assert.equal(row(r,'done').ins[0].status,null);assert.equal(row(r,'done').ins[0].processed,'done');assert.equal(row(r,'optimized').ins[0].status,'unfill-optimized');unchanged(s);s.w.close();
});
test('Counts and state totals cover every marker while geometry details stop at the sample limit',()=>{
 const s=scene('<main class="go-article__content"><p>Antes.</p>'+Array.from({length:103},(_,i)=>marker('m'+i,i===102?'filled':'unfill-optimized')).join('')+'<p>Depois.</p></main>');const r=s.collect(),totals=r.autoPlacementMarkerSummary;assert.equal(totals.total,103);assert.equal(totals.sampled,100);assert.equal(totals.sampleLimit,100);assert.equal(totals.truncated,true);assert.equal(r.autoPlacementMarkers.length,100);assert.equal(totals.byProsePosition.between.markers,103);assert.equal(totals.insStatuses.total,103);assert.equal(totals.insStatuses.filled,1);assert.equal(totals.insStatuses['unfill-optimized'],102);assert.ok(s.counts.rectReads<110);unchanged(s);s.w.close();
});
test('Nested Google markers own unique INS statuses without double counting and INS markers can own themselves',()=>{
 const s=scene('<main class="go-article__content"><p>Antes.</p><div id="outer" class="google-auto-placed">'+marker('inner','filled')+'</div><ins id="self" class="google-auto-placed adsbygoogle" data-ad-status="unfill-optimized"></ins><p>Depois.</p></main>');const r=s.collect();assert.equal(r.autoPlacementMarkerSummary.total,3);assert.equal(r.autoPlacementMarkerSummary.insStatuses.total,2);assert.equal(row(r,'outer').ins.length,0);assert.equal(row(r,'inner').ins.length,1);assert.equal(row(r,'self').ins.length,1);assert.equal(r.autoPlacementMarkerSummary.insStatuses.filled,1);unchanged(s);s.w.close();
});
test('The panel reports total markers, structural positions and literal statuses rather than sampled paid ads',()=>{
 const s=scene('<div id="wp-admin-bar-go-ads-inspect"><a>Inspect</a></div><main class="go-article__content"><p>Texto.</p>'+Array.from({length:101},(_,i)=>marker('tail'+i,i===100?'filled':'unfill-optimized')).join('')+'</main>');s.w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};const editorialBefore=s.w.document.querySelector('main').outerHTML;s.w.document.querySelector('a').dispatchEvent(new s.w.MouseEvent('click',{bubbles:true,cancelable:true}));
 const cell=label=>[...s.w.document.querySelectorAll('dialog small')].find(n=>n.textContent===label)?.parentElement.querySelector('strong').textContent;
 assert.equal(cell('Marcadores Google no DOM'),'101');assert.equal(cell('Marcadores após o último P'),'101');assert.equal(cell('Marcadores entre P'),'0');assert.equal(cell('INS em marcadores: filled'),'1');assert.equal(cell('INS em marcadores: unfill-optimized'),'100');assert.equal(cell('INS filled entre P (DOM)'),'0');assert.ok(cell('Marcadores detalhados / limite').includes('amostra'));assert.equal(s.w.document.querySelector('main').outerHTML,editorialBefore);assert.equal(s.counts.fetch+s.counts.push+s.counts.storage+s.counts.iframeReads,0);s.w.close();
});
test('Repeated manual captures observe a changed status without refresh, mutation or cached counts',()=>{
 const s=scene('<main class="go-article__content"><p>Antes.</p>'+marker('change','unfill-optimized')+'<p>Depois.</p></main>');assert.equal(s.collect().autoPlacementMarkerSummary.insStatuses.filled,0);s.w.document.querySelector('ins').setAttribute('data-ad-status','filled');s.before=s.w.document.documentElement.outerHTML;const r=s.collect();assert.equal(r.autoPlacementMarkerSummary.insStatuses.filled,1);assert.equal(r.autoPlacementMarkerSummary.insStatuses['unfill-optimized'],0);assert.equal(row(r,'change').prosePosition,'between');unchanged(s);s.w.close();
});

test('Manual startup distinguishes inert hosts and a present script from an initialized API without triggering recovery',()=>{
 const s=scene('<script id="go-ads-manual-runtime" type="text/plain">deferred</script><main class="go-article__content"><p>Texto.</p><aside data-go-ad-placement="article-a1"><template data-go-ad-pending><ins class="adsbygoogle" data-ad-slot="1"></ins></template></aside></main>');
 let ensureCalls=0;s.w.GOAdsRuntimeBoot={state:'loading',error:null,ensure(){ensureCalls++;}};
 let r=s.w.GOAdsDiagnostics.collectManualStartup();assert.equal(r.apiAvailable,false);assert.equal(r.inlineScriptPresent,true);assert.equal(r.manualHosts,1);assert.equal(r.hostsWithPendingTemplate,1);assert.equal(r.hostsMarkedRequested,0);assert.equal(r.activeInsStatuses.total,0);assert.equal(r.recoveryState,'loading');
 s.w.GOAdsRuntime={version:'test',mount(){throw Error('diagnostic must not mount');}};assert.equal(s.w.GOAdsDiagnostics.collectManualStartup().apiAvailable,false);s.w.GOAdsRuntime.scan=()=>{throw Error('diagnostic must not scan');};s.w.GOAdsRuntimeBoot.state='ready';r=s.collect().manualStartup;assert.equal(r.apiAvailable,true);assert.equal(r.runtimeVersion,'test');assert.equal(r.recoveryState,'ready');assert.equal(ensureCalls,0);unchanged(s);s.w.close();
});
test('Manual INS outcomes remain separate from templates and automatic marker counters',()=>{
 const s=scene('<main class="go-article__content"><p>Texto.</p><aside data-go-ad-placement="article-a1" data-go-ad-requested="1"><ins class="adsbygoogle" data-ad-status="filled"></ins></aside><aside data-go-ad-placement="article-a2" data-go-ad-requested="1"><ins class="adsbygoogle" data-ad-status="unfilled"></ins></aside><aside data-go-ad-placement="article-a3"><template data-go-ad-pending><ins class="adsbygoogle"></ins></template></aside></main>');
 const r=s.collect();assert.equal(r.manualStartup.manualHosts,3);assert.equal(r.manualStartup.hostsWithPendingTemplate,1);assert.equal(r.manualStartup.hostsMarkedRequested,2);assert.equal(r.manualStartup.activeInsStatuses.filled,1);assert.equal(r.manualStartup.activeInsStatuses.unfilled,1);assert.equal(r.autoPlacementMarkerSummary.total,0);unchanged(s);s.w.close();
});

console.log(JSON.stringify({suite:'diagnostics-position-review',jsdom:require(path.join(jsdomPath,'package.json')).version,scenarios:results.length,passed:results.filter(x=>x.passed).length,failed:results.filter(x=>!x.passed).length,browserLayout:false,geometry:'stub, not measured',realNetworkRequests:0,realAdRequests:0,results},null,2));
process.exitCode=results.some(x=>!x.passed)?1:0;
