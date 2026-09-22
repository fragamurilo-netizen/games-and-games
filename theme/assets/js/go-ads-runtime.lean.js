/* Overdrive ad runtime — generated from go-ads-runtime.js by tests/build-runtime-min.js. Do not edit. */
(function(w,d){
'use strict';
if(w.GOAdsRuntime)return;
var VERSION= '12.7.0-context-paint-gate',LABEL_BAND=32,DAY=86400000;
var YIELD=w.GOAdsYieldConfig||{};
var DELIVERY=YIELD.delivery_v2||{};
var diagnosticRate=Math.max(0,Math.min(1,Number(DELIVERY.diagnostic_sample_rate)||0));
var diagnosticSampled=diagnosticRate>0&&Math.random()<diagnosticRate;
var gateDiagnostics=diagnosticSampled||!!(YIELD.diagnostics&&YIELD.diagnostics.gate_timings===true);
var TIERS=['reach', 'premium', 'standard', 'deep', 'completion'];
var DEFAULT_PROFILE={
min_gap_px:300,density_window_vh:0.90,max_units_in_window:3,
max_local_ad_ratio:0.45,max_ad_to_content_ratio:0.45,min_stream_gap_px:380,
rest_lead_vh:{reach:1.00,premium:0.90,standard:0.75,deep:0.60,completion:0.52},
rest_lead_min_px:260,rest_lead_max_px:1100,
max_lookahead_vh:3.0,flick_vh_s:2.0,request_spacing_ms:90,
engage_scroll_vh:0.07,engage_dwell_ms:1500
};
var DEFAULT_GOVERNOR={
expansion_depth:0.40,expansion_dwell_ms:18000,expansion_deep_depth:0.58,
expansion_prior_depth:0.70,expansion_prior_floor:0.35,
warmup_lookahead_vh:1.15,conservative_lookahead_vh:1.25,
spacing_scale:{warmup:1,standard:1,conservative:1.20,expansion:0.94}
};
function num(value,fallback){var n =Number(value);return isFinite(n)?n:fallback;}
var reserveOnRequest=!(YIELD.cwv&&YIELD.cwv.reserve_on_request===false);
var trialSignal=(function(value){return(value&&typeof value=== 'object')?value:null;})(YIELD.trial);
function clamp(n,min,max){n=Number(n);return isFinite(n)?Math.max(min,Math.min(max,n)):min;}
var RULES=(function(){
var table=(YIELD.rules&&typeof YIELD.rules=== 'object')?YIELD.rules:{};
var desktopMin=num(table.desktop_min_width,1101);
var desktop=(w.innerWidth||d.documentElement.clientWidth||0)>=desktopMin;
var profile=table[desktop? 'desktop' : 'mobile'];
var out={device:desktop? 'desktop' : 'mobile',desktopMinWidth:desktopMin};
Object.keys(DEFAULT_PROFILE).forEach(function(key){
var value=(profile&&typeof profile=== 'object')?profile[key]:undefined;
if(key=== 'rest_lead_vh'){
var leads={};
TIERS.forEach(function(tier){
leads[tier]=clamp(num(value&&value[tier],DEFAULT_PROFILE.rest_lead_vh[tier]),0.25,2.0);
});
out[key]=leads;
return;
}
out[key]=num(value,DEFAULT_PROFILE[key]);
});
out.critical_hold_ms=clamp(num(table.critical_hold_ms,800),0,2500);
out.stuck_release_ms=clamp(num(table.stuck_release_ms,8000),4000,30000);
var gov=(table.governor&&typeof table.governor=== 'object')?table.governor:{};
out.governor={};
Object.keys(DEFAULT_GOVERNOR).forEach(function(key){
if(key=== 'spacing_scale'){
var scales={};
Object.keys(DEFAULT_GOVERNOR.spacing_scale).forEach(function(state){
scales[state]=clamp(num(gov.spacing_scale&&gov.spacing_scale[state],DEFAULT_GOVERNOR.spacing_scale[state]),0.85,1.60);
});
out.governor[key]=scales;
return;
}
out.governor[key]=num(gov[key],DEFAULT_GOVERNOR[key]);
});
out.governor.warmup_lookahead_vh=clamp(out.governor.warmup_lookahead_vh,0.5,2.5);
out.governor.conservative_lookahead_vh=clamp(out.governor.conservative_lookahead_vh,0.5,3.0);
out.min_gap_px=clamp(out.min_gap_px,120,900);
out.min_stream_gap_px=clamp(out.min_stream_gap_px,160,1200);
out.density_window_vh=clamp(out.density_window_vh,0.4,2.0);
out.max_units_in_window=Math.round(clamp(out.max_units_in_window,1,6));
out.max_local_ad_ratio=clamp(out.max_local_ad_ratio,0.20,0.60);
out.max_ad_to_content_ratio=clamp(out.max_ad_to_content_ratio,0.20,0.60);
out.max_lookahead_vh=clamp(out.max_lookahead_vh,1.0,5.0);
out.flick_vh_s=clamp(out.flick_vh_s,1.0,6.0);
out.request_spacing_ms=clamp(out.request_spacing_ms,0,400);
out.engage_scroll_vh=clamp(out.engage_scroll_vh,0.04,0.40);
out.engage_dwell_ms=clamp(out.engage_dwell_ms,600,8000);
out.rest_lead_min_px=clamp(out.rest_lead_min_px,120,600);
out.rest_lead_max_px=clamp(out.rest_lead_max_px,out.rest_lead_min_px,2000);
return out;
})();
var slotOwners=Object.create(null),pending=new Set(),adjustments=new Set(),records=[];
var mounted=new WeakSet(),measured=new WeakMap(),viewMeasured=new WeakMap(),proximityObservers=Object.create(null);
var frame=0,frameId=0,listening=false,resizeListening=false,ro=null,viewObserver=null,settleTimer=0,stuckTimer=0;
var responseEstimateMs=1050,responseTimes=[],presentResponseTimes=[];
var latencyMemory={loaded:false,profile: '',updatedAt:0,samples:[],imported:0};
var diagnosticBuffer=[],dynamicStats={scans:0,mounted:0,materialized:0,skippedDuplicate:0,rejectedMarkup:0};
var listingBinding={initialized:false,root:null,reserves:[]};
var anchorDiscovery=null,anchorResizeObserver=null,watchedAnchors=new Map();
var now=function(){return Math.round(w.performance&&w.performance.now?w.performance.now():Date.now());};
var motion={y:w.pageYOffset||d.documentElement.scrollTop||0,t:0,velocity:0,direction:0,paceVh:0};
var profileCache={minute:-1,name: '',hour:null,weekday: '' };
motion.t=now();
var engine={
engaged:false,engagedBy: '',engagedAtMs:null,dwellMs:0,dwellStart:null,dwellTimer:0,
criticalInFlight:new Set(),criticalHoldUntil:0,holdTimer:0,paceTimer:0,lastNonCriticalRequestAt:-100000,
dwellWake:0,maxScrollDepth:0,readerModel:null,readerCheckpoint:null,articleWords:0,
topScrollSession:null,topScrollSessionOpened:false,topScrollDwellBase:0,
pageHidden:false,hiddenSinceWall:null,refreshTopScrollOnResume:false,
plannedBodyCount:0,renderedBodyCount:0,reserveBodyCount:0,
eligibleCandidates:0,structuralBodyCapacity:0,plannerVersion: '',plannerTelemetry:false,
articleType: '',
profileName: '',profileHour:null,profileWeekday: '',
auctionSignal: 'neutral',
governor: 'warmup',governorSince:0,governorReason: 'page-load',governorLog:[],
releasedStuck:0,
reserveVh:0,reservePx:null,reserveFrame:-1,anchorFrame:-1,anchorViewport: '',anchorRects:[],clockReserve:-1
};
function viewportHeight(){return w.innerHeight||d.documentElement.clientHeight;}
function viewportWidth(){return w.innerWidth||d.documentElement.clientWidth||0;}
function viewportHasArea(){return viewportHeight()>0&&viewportWidth()>0;}
function scrollY(){return w.pageYOffset||d.documentElement.scrollTop||0;}
function pageVisible(){return d.visibilityState!== 'hidden' &&!engine.pageHidden;}
function accountAnchorRects(){
var viewport=viewportWidth()+ ':' + viewportHeight();
if(engine.anchorFrame===frameId&&engine.anchorViewport===viewport)return engine.anchorRects;
var rects=[];
try{
var nodes=d.querySelectorAll('ins.adsbygoogle[data-anchor-status="displayed"]');
for(var i =0;i<nodes.length;i++){
var r =nodes[i].getBoundingClientRect();
if(r.width>0&&r.height>0)rects.push({top:r.top,bottom:r.bottom,left:r.left,right:r.right,width:r.width,height:r.height});
}
}catch(e){}
engine.anchorFrame=frameId;engine.anchorViewport=viewport;engine.anchorRects=rects;
return rects;
}
function overlayReserve(){
var vh=viewportHeight();
if(engine.reserveFrame===frameId&&engine.reserveVh===vh&&engine.reservePx!=null)return engine.reservePx;
var px=0;
accountAnchorRects().forEach(function(r){
if(r.height>0&&r.bottom>=vh - 4&&r.height<=vh*0.25)px=Math.max(px,Math.round(r.height));
});
engine.reserveVh=vh;engine.reservePx=px;engine.reserveFrame=frameId;
return px;
}
function anchorGeometryChanged(){
engine.anchorFrame=-1;engine.reserveFrame=-1;
refreshViewClocks();
schedule();
}
function recognizedAnchor(node){
return node&&node.nodeType===1&&node.tagName=== 'INS' &&node.classList.contains('adsbygoogle')&&node.hasAttribute('data-anchor-status');
}
function observeAccountAnchor(node){
if(!recognizedAnchor(node)||watchedAnchors.has(node))return false;
var observer=new w.MutationObserver(anchorGeometryChanged);
observer.observe(node,{attributes:true,attributeFilter:['style', 'class', 'data-anchor-status']});
watchedAnchors.set(node,observer);
if(anchorResizeObserver)anchorResizeObserver.observe(node);
return true;
}
function ensureAnchorWatch(){
if(anchorDiscovery||typeof w.MutationObserver!== 'function' ||!d.body)return;
if(typeof w.ResizeObserver=== 'function')anchorResizeObserver=new w.ResizeObserver(anchorGeometryChanged);
anchorDiscovery=new w.MutationObserver(function(mutations){
var changed=false;
(mutations||[]).forEach(function(mutation){
if(mutation.type=== 'attributes'){
if(recognizedAnchor(mutation.target)){observeAccountAnchor(mutation.target);changed=true;}
return;
}
Array.prototype.forEach.call(mutation.addedNodes||[],function(node){
if(!node||node.nodeType!==1)return;
if(observeAccountAnchor(node))changed=true;
if(typeof node.querySelectorAll=== 'function'){
Array.prototype.forEach.call(node.querySelectorAll('ins.adsbygoogle[data-anchor-status]'),function(anchor){
if(observeAccountAnchor(anchor))changed=true;
});
}
});
});
watchedAnchors.forEach(function(observer,anchor){
if(anchor.isConnected)return;
observer.disconnect();if(anchorResizeObserver)anchorResizeObserver.unobserve(anchor);
watchedAnchors.delete(anchor);changed=true;
});
if(changed)anchorGeometryChanged();
});
anchorDiscovery.observe(d.body,{childList:true,subtree:true,attributes:true,attributeFilter:['data-anchor-status']});
Array.prototype.forEach.call(d.querySelectorAll('ins.adsbygoogle[data-anchor-status]'),observeAccountAnchor);
}
function stopAnchorWatch(){
if(anchorDiscovery){anchorDiscovery.disconnect();anchorDiscovery=null;}
if(anchorResizeObserver){anchorResizeObserver.disconnect();anchorResizeObserver=null;}
watchedAnchors.forEach(function(observer){observer.disconnect();});watchedAnchors.clear();
}
function usableViewportHeight(){return Math.max(1,viewportHeight()- overlayReserve());}
function inView(rect){return!!rect&&rect.top<usableViewportHeight()&&rect.bottom>0;}
function listHas(list,value){return Array.isArray(list)&&list.indexOf(value)!==-1;}
function rectOf(rec){
if(rec.rectFrame===frameId&&rec.rectCache)return rec.rectCache;
rec.rectCache=rec.box.getBoundingClientRect();
rec.rectFrame=frameId;
return rec.rectCache;
}
function permission(){
try{
if(w.GOAdsConsent)return w.GOAdsConsent.permitted()===true;
if(typeof w.wp_has_consent=== 'function')return w.wp_has_consent('marketing')===true;
}catch(e){}
return false;
}
var storageConsent=permission();
function history(rec){
if(!permission())return[];
try{
var raw=JSON.parse(w.localStorage.getItem(rec.key)|| '[]'),time=Date.now();
if(!Array.isArray(raw))return[];
return raw.filter(function(n,i,all){
return typeof n === 'number' &&isFinite(n)&&n>time - DAY&&n<=time + 300000&&all.indexOf(n)===i;
}).sort(function(a,b){return a - b;}).slice(-20);
}catch(e){return[];}
}
function persistFill(rec){
if(!rec.options.frequencyMax||!rec.filled||rec.persisted||!permission())return;
try{
var list=history(rec);
if(list.indexOf(rec.filledAt)===-1)list.push(rec.filledAt);
w.localStorage.setItem(rec.key,JSON.stringify(list.slice(-20)));
rec.persisted=true;
}catch(e){}
}
var heightMemory={loaded:false,slots:null};
function heightMemoryEnabled(){
var cfg=YIELD.height_memory||{};
return cfg.enabled!==false&&permission();
}
function loadHeightMemory(){
if(heightMemory.loaded||!heightMemoryEnabled())return heightMemory.slots;
heightMemory.loaded=true;
heightMemory.slots=Object.create(null);
try{
var cfg=YIELD.height_memory||{};
var ttl=clamp(num(cfg.ttl_ms,7*DAY),DAY,30*DAY);
var raw=JSON.parse(w.localStorage.getItem(cfg.storage_key|| 'go_ads_slot_height_v1')|| '{}');
var wall=Date.now();
if(raw&&typeof raw=== 'object'){
Object.keys(raw).slice(0,40).forEach(function(slot){
var entry=raw[slot];
if(!entry||typeof entry!== 'object')return;
var height=Number(entry.h),samples=Number(entry.n),at=Number(entry.t);
if(!isFinite(height)||height<=0||!isFinite(at)||at>wall + 300000||wall - at>ttl)return;
heightMemory.slots[slot]={h:height,n:isFinite(samples)?samples:1,t:at};
});
}
}catch(e){}
return heightMemory.slots;
}
function rememberedHeight(rec){
if(!heightMemoryEnabled()||!rec.slot)return null;
var cfg=YIELD.height_memory||{};
var slots=loadHeightMemory();
var entry=slots&&slots[rec.slot];
if(!entry||entry.n<Math.max(1,num(cfg.min_samples,2)))return null;
return clamp(Math.round(entry.h),0,clamp(num(cfg.max_px,400),100,1200));
}
function rememberHeight(rec,px){
if(!heightMemoryEnabled()||!rec.slot||!(px>0))return;
var cfg=YIELD.height_memory||{};
px=clamp(Math.round(px),0,clamp(num(cfg.max_px,400),100,1200));
try{
var slots=loadHeightMemory()||Object.create(null);
var prior=slots[rec.slot];
var alpha=clamp(num(cfg.ema_alpha,0.4),0.1,0.9);
var next=prior?(prior.h*(1 - alpha)+ px*alpha):px;
slots[rec.slot]={h:Math.round(next),n:Math.min(50,(prior?prior.n:0)+ 1),t:Date.now()};
heightMemory.slots=slots;
var out={};
Object.keys(slots).slice(0,40).forEach(function(key){out[key]=slots[key];});
w.localStorage.setItem(cfg.storage_key|| 'go_ads_slot_height_v1',JSON.stringify(out));
}catch(e){}
}
function applyRememberedReserve(rec){
var declared=parseFloat(w.getComputedStyle(rec.box).minHeight)||0;
if(declared<1)return;
var remembered=rememberedHeight(rec);
if(remembered==null)return;
var target=remembered + bandOf(rec);
if(target>declared){reserve(rec,target);rec.rememberedReserve=target;}
}
function topScrollSession(rec){
if(!rec||rec.placement!== 'topscroll' ||!rec.options.smartFrequency||!permission()){
return{available:false,pages:0,activeMs:0};
}
if(engine.topScrollSession){
return{
available:true,
pages:engine.topScrollSession.pages,
activeMs:Math.max(0,engine.topScrollSession.baseActiveMs + dwellMs()- engine.topScrollDwellBase)
};
}
try{
if(!w.sessionStorage)return{available:false,pages:0,activeMs:0};
var key= 'go_ads_topscroll_session_v1';
var wall=Date.now(),idle=Math.max(60000,Number(rec.options.smartSessionIdleMs)||1800000);
var raw=JSON.parse(w.sessionStorage.getItem(key)|| '{}');
var updated=Number(raw.updatedAt)||0;
var stale=!updated||wall - updated>idle||updated>wall + 300000;
var pages=stale?0:Math.max(0,parseInt(raw.pages||0,10)||0);
var activeMs=stale?0:Math.max(0,Number(raw.activeMs)||0);
pages=stale?1:Math.min(200,pages + (engine.topScrollSessionOpened?0:1));
engine.topScrollSession={key:key,pages:pages,baseActiveMs:activeMs,updatedAt:wall};
engine.topScrollSessionOpened=true;
w.sessionStorage.setItem(key,JSON.stringify({pages:pages,activeMs:Math.round(activeMs),updatedAt:wall}));
return{available:true,pages:pages,activeMs:Math.max(0,activeMs + dwellMs()- engine.topScrollDwellBase)};
}catch(e){
return{available:false,pages:0,activeMs:0};
}
}
function persistTopScrollSession(){
if(!engine.topScrollSession||!permission())return;
try{
var activeMs=Math.max(0,engine.topScrollSession.baseActiveMs + dwellMs()- engine.topScrollDwellBase);
w.sessionStorage.setItem(engine.topScrollSession.key,JSON.stringify({
pages:engine.topScrollSession.pages,activeMs:Math.round(activeMs),updatedAt:Date.now()
}));
}catch(e){}
}
function resumeTopScrollSession(force){
if(!permission())return;
records.forEach(function(rec){
if(rec.placement!== 'topscroll' ||!rec.options.smartFrequency||(rec.media&&!rec.media.matches))return;
var idle=Math.max(60000,Number(rec.options.smartSessionIdleMs)||1800000);
if(force||(engine.hiddenSinceWall!=null&&Date.now()- engine.hiddenSinceWall>idle)){
engine.topScrollSession=null;
engine.topScrollDwellBase=dwellMs();
}
var session=topScrollSession(rec);
rec.smartSessionPages=session.pages||0;
rec.smartSessionActiveMs=Math.round(session.activeMs||0);
});
}
function armTopScrollSmartWake(rec,remainingMs){
if(rec.smartWake||remainingMs<=0||!pageVisible())return;
rec.smartWake=w.setTimeout(function(){rec.smartWake=0;schedule();},Math.max(250,remainingMs + 20));
}
function topScrollSmartAllows(rec,fills){
if(!rec||rec.placement!== 'topscroll' ||!rec.options.smartFrequency)return true;
var session=topScrollSession(rec);
rec.smartSessionPages=session.pages||0;
rec.smartSessionActiveMs=Math.round(session.activeMs||0);
var free=Math.max(0,parseInt(rec.options.smartFreeFills||4,10)||4);
if(fills<free)return true;
var nextFill=fills + 1;
if(nextFill<5)return true;
rec.smartNextFill=nextFill;
if(!session.available)return false;
var pagesNeeded=nextFill>=6?Math.max(1,parseInt(rec.options.smartSixthPages||4,10)||4):Math.max(1,parseInt(rec.options.smartFifthPages||3,10)||3);
var msNeeded=nextFill>=6?Math.max(1000,Number(rec.options.smartSixthMs)||120000):Math.max(1000,Number(rec.options.smartFifthMs)||60000);
if(session.pages>=pagesNeeded||session.activeMs>=msNeeded)return true;
armTopScrollSmartWake(rec,msNeeded - session.activeMs);
return false;
}
function gateStat(rec,name){
return rec.gateStats[name]||(rec.gateStats[name]={entries:0,checks:0,foregroundMs:0,inViewportChecks:0});
}
function closeGateClock(rec){
if(!gateDiagnostics||rec.gateStartMs==null)return;
gateStat(rec,rec.state).foregroundMs +=Math.max(0,now()- rec.gateStartMs);
rec.gateStartMs=null;
}
function openGateClock(rec){
if(gateDiagnostics&&pageVisible()&& /^waiting-/.test(rec.state)&&rec.gateStartMs==null)rec.gateStartMs=now();
}
function inspectGateTimings(rec){
if(!gateDiagnostics)return null;
var result={};
Object.keys(rec.gateStats).forEach(function(name){
var item=rec.gateStats[name];
result[name]={entries:item.entries,checks:item.checks,
foregroundMs:Math.round(item.foregroundMs + (name===rec.state&&rec.gateStartMs!=null?Math.max(0,now()- rec.gateStartMs):0)),
inViewportChecks:item.inViewportChecks};
});
return result;
}
function state(rec,value){
if(gateDiagnostics&& /^waiting-/.test(value)){
var gate=gateStat(rec,value);gate.checks++;
if(rec.lastRange&&inView(rec.lastRange.rect)&&pageVisible())gate.inViewportChecks++;
if(value=== 'waiting-content-density' &&rec.densityReason)rec.densityChecks[rec.densityReason]=(rec.densityChecks[rec.densityReason]||0)+ 1;
}
if(rec.state===value)return;
closeGateClock(rec);
rec.state=value;
if(gateDiagnostics&& /^waiting-/.test(value))gateStat(rec,value).entries++;
openGateClock(rec);
rec.box.setAttribute('data-go-ad-state',value);
rec.timeline.push({state:value,ms:now()});
if(rec.timeline.length>24)rec.timeline.shift();
try{d.dispatchEvent(new CustomEvent('go:ad-state',{detail:{placement:rec.placement,slot:rec.slot,state:value,ms:now()}}));}catch(e){}
if(rec.options.debug&&w.console&&typeof w.console.debug=== 'function'){
w.console.debug('[GO Ads]',{placement:rec.placement,state:value,tier:tierOf(rec),
governor:engine.governor,distance:rec.distanceToViewport,arrivalMs:rec.estimatedArrivalMs,
expectedValue:Math.round(expectedValue(rec)*1000)/ 1000,availableWidth:rec.availableWidth==null?null:Math.round(rec.availableWidth)});
}
}
function changedConsent(){
var granted=permission();
if(granted!==storageConsent){
engine.readerModel=null;
engine.topScrollSession=null;
engine.topScrollDwellBase=dwellMs();
storageConsent=granted;
if(!granted)latencyMemory={loaded:false,profile: '',updatedAt:0,samples:[],imported:0};
}
if(granted)loadLatencyMemory();
records.forEach(persistFill);
if(granted&&pageVisible())resumeTopScrollSession(false);
schedule();
}
function allowed(rec){return!rec.options.gate||permission();}
function tierOf(rec){return(rec&&rec.tier&&RULES.rest_lead_vh[rec.tier]!=null)?rec.tier: 'standard';}
function yieldProfileParts(){
try{
var tz=YIELD.timezone|| 'America/Sao_Paulo';
var parts=new Intl.DateTimeFormat('en-US',{timeZone:tz,hour: '2-digit',hour12:false,weekday: 'short' }).formatToParts(new Date());
var hour=12,weekday= '';
parts.forEach(function(part){if(part.type=== 'hour')hour=parseInt(part.value,10);if(part.type=== 'weekday')weekday=part.value;});
if(hour===24)hour=0;
return{hour:isFinite(hour)?hour:12,weekday:weekday};
}catch(e){return{hour:(new Date()).getHours(),weekday: '' };}
}
function currentProfileName(){
var minute=Math.floor(Date.now()/ 60000);
if(profileCache.minute===minute&&profileCache.name){
engine.profileName=profileCache.name;engine.profileHour=profileCache.hour;engine.profileWeekday=profileCache.weekday;
return profileCache.name;
}
var parts=yieldProfileParts(),maps=YIELD.dayparts||{},name= 'peak';
if(listHas(maps.guard,parts.hour))name= 'guard';
else if(listHas(maps.shoulder,parts.hour))name= 'shoulder';
profileCache={minute:minute,name:name,hour:parts.hour,weekday:parts.weekday};
engine.profileName=name;engine.profileHour=parts.hour;engine.profileWeekday=parts.weekday;
return name;
}
function currentProfile(){
var name=currentProfileName(),profiles=YIELD.profiles||{};
return profiles[name]||profiles.shoulder||profiles.peak||{};
}
function engageScrollViewports(){return clamp(Math.max(RULES.engage_scroll_vh,num(currentProfile().engage_scroll_viewports,RULES.engage_scroll_vh)),0.04,0.40);}
function engageDwellMs(){return clamp(Math.max(RULES.engage_dwell_ms,num(currentProfile().engage_dwell_ms,RULES.engage_dwell_ms)),600,8000);}
function requestSpacingMs(){
return Math.max(0,Math.round(RULES.request_spacing_ms));
}
var unitModel=(function(){
var raw=YIELD.decision&&typeof YIELD.decision=== 'object' ?YIELD.decision:{};
var generated=num(raw.generated_at,0),samples=Math.max(0,num(raw.model_samples,0)),priors={},neutral={};
[priors,neutral].forEach(function(out){
out.regime= 'manual_fixed';out.delivery_mode= 'manual_fixed';
out.supply_bias=0;out.pacing_scale=1;
out.tier_lookahead={reach:1,premium:1,standard:1,deep:1,completion:1};
out.generated_at=generated;
out.model_samples=samples;
out.model_window=raw.model_window||null;
out.model_max_age_seconds=86400;out.model_future_tolerance_seconds=300;
out.freshness_source= 'unit-model-generation-not-report-capture';
['slot_value', 'slot_coverage', 'slot_viewability', 'tier_value'].forEach(function(key){
out[key]=out===priors&&raw[key]&&typeof raw[key]=== 'object' ?raw[key]:{};
});
});
priors.confidence= 'historical';priors.fresh=true;priors.reasons=[];
neutral.confidence= 'none';neutral.fresh=false;neutral.reasons=['unit-model-missing-or-stale'];
return{generated:generated,samples:samples,priors:priors,neutral:neutral};
})();
function decision(){
var age=Date.now()/ 1000 - unitModel.generated;
return unitModel.samples>0&&unitModel.generated>0&&age>=-300&&age<=86400?unitModel.priors:unitModel.neutral;
}
function slotKey(rec){return String((rec&&rec.slot)|| '');}
function fallbackTierValue(rec){return clamp(num((decision().tier_value||{})[tierOf(rec)],1),0.35,2.20);}
function slotValue(rec){
var raw=Number((decision().slot_value||{})[slotKey(rec)]);
return(isFinite(raw)&&raw>0)?clamp(raw,0.25,2.60):fallbackTierValue(rec);
}
function slotCoverage(rec){return clamp(num((decision().slot_coverage||{})[slotKey(rec)],1),0.70,1.20);}
function slotViewability(rec){
var value=Number((decision().slot_viewability||{})[slotKey(rec)]);
return(isFinite(value)&&value>0)?clamp(value,0.15,0.95):null;
}
function tierWeight(rec){return clamp(num((YIELD.tier_weights||{})[tierOf(rec)],0.80),0.45,1.15);}
function maxDocumentScroll(){return Math.max(1,Math.max(d.documentElement.scrollHeight||0,d.body?d.body.scrollHeight:0)- viewportHeight());}
function currentScrollDepth(){return clamp(scrollY()/ maxDocumentScroll(),0,1);}
function readerDepth(){return Math.max(engine.maxScrollDepth||0,currentScrollDepth());}
function dwellMs(){return engine.dwellMs + (engine.dwellStart==null?0:Math.max(0,now()- engine.dwellStart));}
function getReaderModel(refresh){
var base={pages:0,emaDepth:0.5};
if(!YIELD.reader_model||YIELD.reader_model.enabled===false||!permission())return base;
if(engine.readerModel&&!refresh)return engine.readerModel;
try{
var key=YIELD.reader_model.storage_key|| 'go_ads_reader_depth_v1';
var raw=JSON.parse(w.localStorage.getItem(key)|| '{}');
if(raw&&typeof raw=== 'object'){
base.pages=Math.max(0,parseInt(raw.pages||0,10)||0);
var depth=Number(raw.emaDepth);if(isFinite(depth))base.emaDepth=clamp(depth,0,1);
}
}catch(e){}
engine.readerModel=base;return base;
}
function persistReaderModel(){
if(!YIELD.reader_model||YIELD.reader_model.enabled===false||!permission())return;
try{
var model=getReaderModel(true),alpha=clamp(num(YIELD.reader_model.ema_alpha,0.25),0.05,0.8);
var depth=readerDepth(),checkpoint=engine.readerCheckpoint,next;
if(checkpoint){
var correction=(depth - checkpoint.depth)*checkpoint.weight
*Math.pow(1 - alpha,Math.max(0,model.pages - checkpoint.pages));
next={pages:model.pages,emaDepth:clamp(model.emaDepth + correction,0,1)};
}else{
next={pages:Math.min(200,(model.pages||0)+ 1),
emaDepth:(model.pages?model.emaDepth:depth)*(1 - alpha)+ depth*alpha};
}
next.emaDepth=Math.round(next.emaDepth*1000)/ 1000;
w.localStorage.setItem(YIELD.reader_model.storage_key|| 'go_ads_reader_depth_v1',JSON.stringify(next));
engine.readerCheckpoint={pages:checkpoint?checkpoint.pages:next.pages,
depth:depth,weight:checkpoint?checkpoint.weight:(model.pages?alpha:1)};
engine.readerModel=next;
}catch(e){}
}
var entryContext=(function(){
var cfg=(YIELD.entry_context&&typeof YIELD.entry_context=== 'object')?YIELD.entry_context:{};
var out={enabled:cfg.enabled!==false,source: 'unknown',depth:null,weight:0};
if(!out.enabled)return out;
function hostOf(url){
var match= /^[a-z][a-z0-9+.-]*:\/\/([^/?#]*)/i.exec(String(url|| ''));
if(!match)return '';
return String(match[1]).toLowerCase().replace(/^[^@]*@/, '').replace(/:\d+$/, '').replace(/^www\./, '');
}
try{
var ref=typeof d.referrer=== 'string' ?d.referrer: '';
var host=hostOf(ref);
var self=hostOf((w.location&&w.location.href)|| '');
if(!ref)out.source= 'direct';
else if(/^android-app:/i.test(ref))out.source= /googlequicksearchbox/i.test(ref)? 'google-app' : 'app';
else if(!host)out.source= 'other';
else if(self&&host===self)out.source= 'internal';
else if(/^news\.google\./.test(host)|| /^(flipboard|smartnews)\./.test(host)|| /(^|\.)msn\.com$/.test(host))out.source= 'aggregator';
else if(/(^|\.)(google|bing|duckduckgo|yahoo|ecosia|yandex|baidu)\./.test(host)|| /(^|\.)brave\.com$/.test(host))out.source= 'search';
else if(/(^|\.)(facebook|instagram|twitter|x|t|reddit|linkedin|pinterest|tiktok|youtube|whatsapp|telegram)\.[a-z.]+$/.test(host))out.source= 'social';
else out.source= 'other';
}catch(e){out.source= 'unknown';}
var priors=(cfg.depth_priors&&typeof cfg.depth_priors=== 'object')?cfg.depth_priors:{};
var raw=Number(priors[out.source]);
if(isFinite(raw)&&raw>0){
out.depth=clamp(raw,num(cfg.min_prior,0.35),num(cfg.max_prior,0.72));
out.weight=clamp(num(cfg.weight,1),0,1);
}
return out;
})();
function storedReaderPrior(){
var model=getReaderModel();
return model.pages>=num((YIELD.reader_model||{}).min_pages,3)?model.emaDepth:null;
}
function readerPrior(){
var stored=storedReaderPrior();
if(stored!=null)return stored;
if(entryContext.depth==null||entryContext.weight<=0)return 0.5;
return clamp(0.5 + (entryContext.depth - 0.5)*entryContext.weight,0,1);
}
function engagementScore(){
return clamp(currentScrollDepth()*0.50 + Math.min(1,dwellMs()/ 18000)*0.28 + readerPrior()*0.22,0,1);
}
function auctionSignal(){
var cfg=YIELD.auction_signal||{},responded=0,filled=0,totalMs=0,timed=0;
records.forEach(function(r){
if(!r.critical||!r.providerStatus)return;
responded++;
if(r.providerStatus=== 'filled')filled++;
if(r.responseMs!=null){totalMs +=r.responseMs;timed++;}
});
if(responded<num(cfg.min_critical_responses,2)){engine.auctionSignal= 'neutral';return 'neutral';}
var fill=filled / responded,avg=timed?totalMs / timed:9999;
if(fill>=num(cfg.strong_fill_rate,0.67)&&avg<=num(cfg.strong_response_ms,1500))engine.auctionSignal= 'strong';
else if(fill<=num(cfg.weak_fill_rate,0.34)||avg>=num(cfg.weak_response_ms,2600))engine.auctionSignal= 'weak';
else engine.auctionSignal= 'neutral';
return engine.auctionSignal;
}
function governorSpacingScale(){return num(RULES.governor.spacing_scale[engine.governor],1);}
function setGovernor(next,reason){
if(engine.governor===next)return;
engine.governorLog.push({from:engine.governor,to:next,reason:reason,ms:now(),depth:Math.round(readerDepth()*1000)/ 1000});
if(engine.governorLog.length>12)engine.governorLog.shift();
engine.governor=next;
engine.governorSince=now();
engine.governorReason=reason;
try{d.dispatchEvent(new CustomEvent('go:ads-governor',{detail:{state:next,reason:reason}}));}catch(e){}
}
function armDwellWake(remainingMs){
if(engine.dwellWake)return;
engine.dwellWake=w.setTimeout(function(){engine.dwellWake=0;schedule();},Math.max(250,remainingMs + 20));
}
function evaluateGovernor(){
if(engine.dwellWake){w.clearTimeout(engine.dwellWake);engine.dwellWake=0;}
if(!engine.engaged){setGovernor('warmup', 'awaiting-engagement');return;}
var gov=RULES.governor,depth=readerDepth(),dwell=dwellMs();
var depthBar=clamp(gov.expansion_depth,0.20,0.90);
var deepBar=clamp(gov.expansion_deep_depth,0.30,0.95);
if(engine.governor!== 'expansion'){
if(depth>=deepBar){setGovernor('expansion', 'scroll-depth');return;}
if(depth>=depthBar&&dwell>=gov.expansion_dwell_ms){setGovernor('expansion', 'depth-and-dwell');return;}
var stored=storedReaderPrior();
if(stored!=null&&stored>=gov.expansion_prior_depth&&depth>=gov.expansion_prior_floor){setGovernor('expansion', 'returning-deep-reader');return;}
if(depth>=depthBar&&pageVisible())armDwellWake(gov.expansion_dwell_ms - dwell);
}else{
return;
}
if(motion.paceVh>RULES.flick_vh_s){setGovernor('conservative', 'sustained-fast-scroll');return;}
setGovernor('standard', 'engaged-reading');
}
var contentNode=null,contentFrame=-1;
function articleContentNode(){
if(contentFrame!==frameId){
contentFrame=frameId;
contentNode=d.querySelector('[data-go-manual-ads-root="article"], .go-article__content, .entry-content, .go-single__content');
}
return contentNode;
}
function isArticle(){return!!(d.body&&d.body.classList.contains('single-post'));}
var planFrame=-1;
function syncArticlePlan(){
if(planFrame===frameId)return;
var node=articleContentNode();
if(!node||typeof node.getAttribute!== 'function')return;
planFrame=frameId;
var read=function(name){return parseInt(node.getAttribute('data-go-ad-plan-' + name)|| '',10)||0;};
var hasTelemetry=node.hasAttribute('data-go-ad-plan-planned-body')||node.hasAttribute('data-go-ad-plan-body-capacity');
if(!hasTelemetry)return;
engine.plannerTelemetry=true;
engine.articleWords=Math.max(engine.articleWords||0,read('body-words'));
engine.plannedBodyCount=Math.max(engine.plannedBodyCount||0,read('planned-body'));
engine.renderedBodyCount=Math.max(engine.renderedBodyCount||0,read('rendered-body'));
engine.reserveBodyCount=Math.max(engine.reserveBodyCount||0,read('reserve-body'));
engine.eligibleCandidates=Math.max(engine.eligibleCandidates||0,read('eligible-candidates'));
engine.structuralBodyCapacity=Math.max(engine.structuralBodyCapacity||0,read('body-capacity'));
engine.plannerVersion=node.getAttribute('data-go-ad-plan-planner-version')||engine.plannerVersion|| '';
engine.articleType=node.getAttribute('data-go-ad-plan-article-type')||engine.articleType|| '';
}
function articleWords(){
syncArticlePlan();
if(engine.articleWords>0)return engine.articleWords;
var node=articleContentNode();
if(!node)return 0;
var total=((node.textContent|| '').match(/\S+/g)||[]).length;
var ads=0;
Array.prototype.forEach.call(node.querySelectorAll('.go-ad-slot'),function(el){
ads +=((el.textContent|| '').match(/\S+/g)||[]).length;
});
engine.articleWords=Math.max(0,total - ads);
return engine.articleWords;
}
function isBodyRecord(rec){return /^(article|article-prime)$/.test(rec.surface|| '');}
function isCompletionRecord(rec){return(rec.surface|| '')=== 'article-completion' ||tierOf(rec)=== 'completion';}
function requestBudgetOccupied(r){
if(!r.requested||r.closed||r.error||r.providerStatus=== 'unfilled')return false;
if(/^(filled|unfill-optimized)$/.test(r.providerStatus|| ''))return true;
if(r.providerStatus)return true;
return(now()- r.requestedMs)<RULES.stuck_release_ms;
}
function countOccupied(filter){
var n =0;
records.forEach(function(r){if(requestBudgetOccupied(r)&&filter(r))n++;});
return n;
}
function bodyBudget(){
syncArticlePlan();
if(!engine.plannerTelemetry)return 0;
var planned=Math.max(0,engine.plannedBodyCount||0);
if(planned<1)return 0;
var rendered=Math.max(planned,engine.renderedBodyCount||0);
var structural=Math.max(planned,engine.structuralBodyCapacity||0);
var budget=planned;
if(engine.governor=== 'expansion')budget=Math.min(rendered,structural);
return Math.max(0,Math.round(budget));
}
function reachedReserveAllows(rec){
if(!engine.plannerTelemetry||!isBodyRecord(rec))return false;
var maximum=Math.min(Math.max(0,engine.renderedBodyCount||0),Math.max(0,engine.structuralBodyCapacity||0));
if(maximum<1||countOccupied(isBodyRecord)>=maximum)return false;
var range=rangeFor(rec);
if(!range||!range.rect)return false;
var visible=inView(range.rect);
var imminent=!visible&&range.arrival!=null&&range.arrival<=responseEstimateFor(rec)+ Math.max(250,num(rec.options.safetyMs,600))
&&range.distance<=Math.min(restingLead(rec),usableViewportHeight()*0.5)
&&motion.paceVh<=RULES.flick_vh_s&&reachProbability(rec)>=0.90;
if(!visible&&!imminent)return false;
rec.reachedReserveQualified=true;
rec.reachedReserveReason=visible? 'in-useful-viewport' : 'predicted-arrival';
return true;
}
function budgetAllows(rec){
if(rec.critical||!isArticle())return true;
if(isCompletionRecord(rec)){
return countOccupied(isCompletionRecord)<1;
}
if(!isBodyRecord(rec))return true;
if(countOccupied(isBodyRecord)<bodyBudget()){rec.budgetPath=engine.governor=== 'expansion' ? 'governor-expansion' : 'planned';return true;}
if(reachedReserveAllows(rec)){rec.budgetPath= 'reached-reserve';return true;}
rec.budgetPath= 'waiting';
return false;
}
function nominalHeight(rec){
if(rec.nominalFrame!==frameId){
rec.nominalFrame=frameId;
rec.nominalCache=Math.max(180,Math.min(320,widthOf(rec.box)*0.62));
}
return rec.nominalCache;
}
function effectiveAdRect(rec){
var rect=rectOf(rec);
var height=Math.max(0,num(rect.height,0));
if(rec&&rec.requested&&rec.providerStatus!== 'unfilled'){
var requestedHeight=rec.requestSize?Math.max(0,num(rec.requestSize.height,0)):0;
if(!/^(filled|unfill-optimized)$/.test(rec.providerStatus|| '')){
height=Math.max(height,requestedHeight,nominalHeight(rec));
}else if(height<1){
height=Math.max(requestedHeight,nominalHeight(rec));
}
}
if(height<1)return rect;
return{
top:rect.top,bottom:rect.top + height,left:rect.left,right:rect.right,
width:rect.width,height:height,x:rect.x,y:rect.y
};
}
function horizontalOverlap(a,b){
var left=Math.max(num(a.left,a.x||0),num(b.left,b.x||0));
var right=Math.min(num(a.right,left + num(a.width,0)),num(b.right,left + num(b.width,0)));
var overlap=Math.max(0,right - left);
var smaller=Math.max(1,Math.min(num(a.width,0),num(b.width,0)));
return overlap / smaller;
}
function gapBetween(rect,candidateHeight,other){
return rect.top>=other.bottom?rect.top - other.bottom
:((rect.top + candidateHeight)<=other.top?other.top - (rect.top + candidateHeight):0);
}
function occupiedNeighbours(rect){
var out=[];
records.forEach(function(r){
if(!r.requested||r.closed||r.providerStatus=== 'unfilled')return;
var other=effectiveAdRect(r);
if((other.height||0)<1)return;
if(horizontalOverlap(rect,other)<0.15)return;
out.push(other);
});
return out;
}
function usesStreamSpacing(rec){return!/^article/.test(rec.surface|| '');}
function minGapFor(rec){
return Math.round((usesStreamSpacing(rec)?RULES.min_stream_gap_px:RULES.min_gap_px)*governorSpacingScale());
}
function densityAllows(rec){
rec.densityReason= '';
if(rec.critical)return true;
var vh=viewportHeight();
var rect=rectOf(rec);
var candidate=nominalHeight(rec);
var minGap=minGapFor(rec);
var half=vh*RULES.density_window_vh;
var windowTop=rect.top - half;
var windowBottom=rect.top + candidate + half;
var windowHeight=Math.max(1,windowBottom - windowTop);
var neighbours=occupiedNeighbours(rect);
var localAds=0,nearestGap=Infinity;
neighbours.forEach(function(other){
var overlap=Math.min(other.bottom,windowBottom)- Math.max(other.top,windowTop);
if(overlap>0)localAds +=overlap;
nearestGap=Math.min(nearestGap,gapBetween(rect,candidate,other));
});
if(nearestGap<minGap){rec.densityReason= 'minimum-gap';return false;}
var candidateRect={top:rect.top,bottom:rect.top + candidate};
var boxes=neighbours.concat([candidateRect]);
for(var i =0;i<boxes.length;i++){
var from=boxes[i].top - half,to=boxes[i].bottom + half,count=0;
if(candidateRect.bottom<=from||candidateRect.top>=to)continue;
for(var j =0;j<boxes.length;j++){
if(boxes[j].bottom>from&&boxes[j].top<to)count++;
}
if(count>RULES.max_units_in_window){rec.densityReason= 'unit-window';return false;}
}
if((localAds + candidate)>windowHeight*RULES.max_local_ad_ratio){rec.densityReason= 'local-area-ratio';return false;}
if(!isBodyRecord(rec))return true;
var content=articleContentNode();
if(!content||!content.contains(rec.box))return true;
var articleAds=0;
records.forEach(function(r){
if(r===rec||!r.requested||r.closed||r.providerStatus=== 'unfilled' ||!content.contains(r.box))return;
articleAds +=Math.max(0,effectiveAdRect(r).height||0);
});
var total=Math.max(1,content.scrollHeight||content.getBoundingClientRect().height||1);
var fits=(articleAds + candidate)<=total*RULES.max_ad_to_content_ratio;
if(!fits)rec.densityReason= 'article-area-ratio';
return fits;
}
function armPace(ms){
if(engine.paceTimer)return;
engine.paceTimer=w.setTimeout(function(){engine.paceTimer=0;schedule();},Math.max(20,ms + 5));
}
function pacingAllows(rec){
if(rec.critical)return true;
var spacing=requestSpacingMs(),elapsed=now()- engine.lastNonCriticalRequestAt;
if(elapsed>=spacing)return true;
var remaining=Math.max(0,spacing - elapsed);
var info=rangeFor(rec),rect=info&&info.rect;
if(inView(rect))return true;
if(info&&info.arrival!=null&&info.arrival<=remaining + clamp(responseEstimateFor(rec)*0.25,100,350))return true;
armPace(remaining);return false;
}
function reachProbability(rec){
var range=rangeFor(rec),rect=range.rect,vh=viewportHeight();
if(!rect)return 0.5;
if(inView(rect))return 1;
var distance=Math.max(0,range.distance||0);
if(rect.bottom<=0)return motion.direction<0?0.95:0.35;
var targetDepth=clamp((scrollY()+ rect.top)/ Math.max(1,maxDocumentScroll()+ vh),0,1);
var reached=readerDepth();
if(targetDepth<=reached + 0.02)return 1;
var stamina=clamp(readerPrior()*0.55 + engagementScore()*0.45,0.10,1);
var p =clamp(Math.exp(-(targetDepth - reached)/ Math.max(0.08,stamina*0.85)),0.05,1);
if(distance<=vh*0.75)p=Math.max(p,0.92);
else if(distance<=vh*1.60)p=Math.max(p,0.74);
else if(distance<=vh*2.60)p=Math.max(p,0.52);
return p;
}
function expectedValue(rec){return slotValue(rec)*reachProbability(rec);}
function requestPriority(rec){
if(!rec||rec.requested||rec.closed||!rec.box||!rec.box.isConnected)return -100000;
var range=rangeFor(rec),rect=range.rect,vh=viewportHeight();
if(rec.critical)return 100000 - Math.max(0,range.distance||0);
if(inView(rect))return 50000 + slotValue(rec)*1000;
return expectedValue(rec)*tierWeight(rec)*10000 - Math.max(0,range.distance||0)/ 50;
}
function sampleMotion(){
var t =now(),y=scrollY(),dt=Math.max(1,t - motion.t),raw=((y - motion.y)/ dt)*1000;
if(Math.abs(raw)<8)raw=0;
motion.velocity=motion.velocity*0.72 + raw*0.28;
motion.direction=motion.velocity>20?1:(motion.velocity<-20?-1:0);
motion.paceVh=motion.paceVh*0.72 + (Math.abs(raw)/ Math.max(1,viewportHeight()))*0.28;
motion.y=y;motion.t=t;
}
function percentile(values,p){
if(!values||!values.length)return null;
var sorted=values.slice().sort(function(a,b){return a - b;});
return sorted[Math.max(0,Math.min(sorted.length - 1,Math.ceil(sorted.length*clamp(p,0.5,0.99))- 1))];
}
function latencyProfile(){
var c =navigator.connection||navigator.mozConnection||navigator.webkitConnection;
var device=(w.innerWidth||d.documentElement.clientWidth||0)>=RULES.desktopMinWidth? 'desktop' : 'mobile';
return device + ':' +(c?String(c.effectiveType|| 'unknown'): 'unknown')+ ':' +(c&&c.saveData? 'save' : 'normal');
}
function latencyMemoryEnabled(){return DELIVERY.latency_memory===true&&permission();}
function loadLatencyMemory(){
if(!latencyMemoryEnabled())return;
var profile=latencyProfile(),wall=Date.now();
var ttl=clamp(num(DELIVERY.memory_ttl_ms,1800000),60000,3600000);
if(latencyMemory.loaded&&latencyMemory.profile===profile){
if(wall - latencyMemory.updatedAt>ttl)latencyMemory.samples=[];
return;
}
if(latencyMemory.profile&&latencyMemory.profile!==profile){presentResponseTimes=[];responseEstimateMs=1050;}
latencyMemory={loaded:true,profile:profile,updatedAt:0,samples:[],imported:0};
try{
var raw=JSON.parse(w.sessionStorage.getItem('go_ads_fill_latency_v2')|| '{}');
var updated=num(raw.updatedAt,0);
if(raw.version!==2||raw.profile!==profile||!updated||updated>wall + 300000||wall - updated>ttl||!Array.isArray(raw.samples))return;
latencyMemory.samples=raw.samples.filter(function(ms){return typeof ms=== 'number' &&isFinite(ms)&&ms>=150&&ms<=4000;}).slice(-24);
latencyMemory.updatedAt=updated;
latencyMemory.imported=latencyMemory.samples.length;
}catch(e){}
}
function persistLatencyMemory(){
if(!latencyMemoryEnabled()||!presentResponseTimes.length)return;
loadLatencyMemory();
try{
w.sessionStorage.setItem('go_ads_fill_latency_v2',JSON.stringify({version:2,
profile:latencyProfile(),updatedAt:Date.now(),
samples:latencyMemory.samples.concat(presentResponseTimes).slice(-24).map(Math.round)}));
}catch(e){}
}
function predictionSamples(){
loadLatencyMemory();
if(!latencyMemoryEnabled()||presentResponseTimes.length>=3)return presentResponseTimes;
var old=latencyMemory.samples.slice(-Math.max(0,6 - presentResponseTimes.length*2));
return old.concat(presentResponseTimes);
}
function responseEstimateFor(rec){
var samples=predictionSamples();
if(samples.length<3)return responseEstimateMs;
var tier=tierOf(rec),p=0.85;
if(tier=== 'reach' ||tier=== 'premium')p=0.90;
else if(tier=== 'deep')p=0.78;
else if(tier=== 'completion')p=0.72;
var estimate=percentile(samples,p);
return estimate==null?responseEstimateMs:clamp(estimate,650,4000);
}
function learnFilledResponse(ms){
loadLatencyMemory();
ms=clamp(ms,150,4000);
presentResponseTimes.push(ms);
if(presentResponseTimes.length>32)presentResponseTimes.shift();
var presentP85=percentile(presentResponseTimes,0.85);
responseEstimateMs=presentResponseTimes.length>=3?presentP85:Math.max(1050,presentP85||0);
persistLatencyMemory();
}
function learnResponse(ms,providerStatus,foregroundOnly){
ms=Number(ms);
if(!isFinite(ms)||ms<1)return;
ms=clamp(ms,150,4000);
responseTimes.push(ms);
if(responseTimes.length>32)responseTimes.shift();
if(providerStatus=== 'filled' &&foregroundOnly)learnFilledResponse(ms);
}
function belowViewport(rec){return rec.box.getBoundingClientRect().top>=viewportHeight()+ 32;}
function aboveViewport(rec){return rec.box.getBoundingClientRect().bottom<=-32;}
function engage(reason){
if(engine.engaged)return;
engine.engaged=true;
engine.engagedBy=reason;
engine.engagedAtMs=now();
if(engine.dwellTimer){w.clearTimeout(engine.dwellTimer);engine.dwellTimer=0;}
pending.forEach(watchProximity);
try{d.dispatchEvent(new CustomEvent('go:ads-engaged',{detail:{reason:reason}}));}catch(e){}
schedule();
}
function checkScrollEngagement(){
if(!engine.engaged&&scrollY()>=viewportHeight()*engageScrollViewports())engage('scroll');
}
function stopDwell(){
if(engine.dwellTimer){w.clearTimeout(engine.dwellTimer);engine.dwellTimer=0;}
if(engine.dwellStart!=null){engine.dwellMs +=Math.max(0,now()- engine.dwellStart);engine.dwellStart=null;}
}
function startDwell(){
if(!pageVisible()||engine.dwellStart!=null)return;
engine.dwellStart=now();
if(engine.engaged||engine.dwellTimer)return;
engine.dwellTimer=w.setTimeout(function(){engine.dwellTimer=0;engage('dwell');},
Math.max(0,engageDwellMs()- dwellMs()));
}
function releaseCritical(rec){
if(engine.criticalInFlight.delete(rec)&&!engine.criticalInFlight.size)schedule();
}
function armHold(ms){
if(engine.holdTimer)return;
engine.holdTimer=w.setTimeout(function(){engine.holdTimer=0;schedule();},Math.max(16,ms + 8));
}
function criticalHold(rec){
if(rec.critical||engine.engaged||!engine.criticalInFlight.size)return false;
var remaining=engine.criticalHoldUntil - now();
if(remaining<=0)return false;
var info=rangeFor(rec),rect=info&&info.rect;
if(inView(rect))return false;
var tier=tierOf(rec),vh=viewportHeight();
var releaseVh=tier=== 'reach' ?0.38:(tier=== 'premium' ?0.30:0);
if(releaseVh>0&&info&&info.distance<=clamp(vh*releaseVh,180,360))return false;
if(info&&info.arrival!=null&&info.arrival<=responseEstimateFor(rec)+ Math.max(250,num(rec.options.safetyMs,600))+ remaining)return false;
if(rec.holdStartMs==null)rec.holdStartMs=now();
armHold(remaining);
return true;
}
var paintGate={armed:false,released:true,releasedBy: 'disabled',holdMs:0,maxHoldMs:0,nearVh:0.5,
startedMs:0,releasedMs:null,observer:null,graceTimer:0,ceilingTimer:0,deferred:0};
function releasePaintGate(reason){
if(paintGate.released)return;
paintGate.released=true;
paintGate.releasedBy=reason;
paintGate.releasedMs=now();
if(paintGate.graceTimer){w.clearTimeout(paintGate.graceTimer);paintGate.graceTimer=0;}
if(paintGate.ceilingTimer){w.clearTimeout(paintGate.ceilingTimer);paintGate.ceilingTimer=0;}
if(paintGate.observer){try{paintGate.observer.disconnect();}catch(e){}paintGate.observer=null;}
schedule();
}
function armPaintGate(){
var cfg=(YIELD.cwv&&typeof YIELD.cwv=== 'object')?YIELD.cwv:{};
var ceiling=clamp(num(cfg.paint_gate_max_hold_ms,0),0,4000);
if(paintGate.armed||cfg.paint_gate===false||ceiling<50)return;
paintGate.armed=true;
paintGate.released=false;
paintGate.releasedBy= '';
paintGate.startedMs=now();
paintGate.maxHoldMs=ceiling;
paintGate.holdMs=clamp(num(cfg.paint_gate_grace_ms,250),0,1500);
paintGate.nearVh=clamp(num(cfg.paint_gate_near_vh,0.5),0,2.0);
paintGate.ceilingTimer=w.setTimeout(function(){paintGate.ceilingTimer=0;releasePaintGate('ceiling');},ceiling);
try{
if(typeof w.PerformanceObserver=== 'function'){
paintGate.observer=new w.PerformanceObserver(function(){
if(paintGate.released||paintGate.graceTimer)return;
paintGate.graceTimer=w.setTimeout(function(){paintGate.graceTimer=0;releasePaintGate('largest-contentful-paint');},
Math.max(1,paintGate.holdMs));
});
paintGate.observer.observe({type: 'largest-contentful-paint',buffered:true});
}
}catch(e){}
}
function releasePaintGateOnInput(){releasePaintGate('interaction');}
function paintHold(rec){
if(paintGate.released||rec.critical)return false;
var info=rangeFor(rec),rect=info&&info.rect;
if(inView(rect))return false;
if(info&&info.distance<=Math.round(viewportHeight()*paintGate.nearVh))return false;
if(info&&info.arrival!=null&&info.arrival<=responseEstimateFor(rec)+ Math.max(250,num(rec.options.safetyMs,600)))return false;
if(rec.paintHeldMs==null){rec.paintHeldMs=now();paintGate.deferred++;}
return true;
}
function restingLead(rec){
var configured=Math.max(0,num(rec.options.near,0));
if(!configured)return 0;
var tier=tierOf(rec);
var lead=clamp(usableViewportHeight()*RULES.rest_lead_vh[tier],RULES.rest_lead_min_px,RULES.rest_lead_max_px);
var view=slotViewability(rec);
if(view!=null)lead*=(view<0.35?0.85:(view>=0.60?1.08:1));
return Math.min(configured,Math.round(lead));
}
function rangeInfo(rec){
var rect=rectOf(rec),vh=viewportHeight(),seen=usableViewportHeight();
var below=rect.top>=seen,above=rect.bottom<0;
var distance=below?Math.max(0,rect.top - seen):(above?-rect.bottom:0);
var rest=restingLead(rec);
var ceiling=Math.max(rest,Math.round(vh*RULES.max_lookahead_vh));
if(!engine.engaged&&!rec.critical)ceiling=Math.min(ceiling,Math.round(vh*RULES.governor.warmup_lookahead_vh));
if(engine.governor=== 'conservative')ceiling=Math.min(ceiling,Math.round(vh*RULES.governor.conservative_lookahead_vh));
var approaching=(below&&motion.direction>0)||(above&&motion.direction<0);
var speed=Math.abs(motion.velocity),arrival=null,near=Math.min(rest,ceiling);
if(rec.options.predictive&&distance>0&&approaching&&speed>80){
arrival=Math.round((distance / speed)*1000);
var safety=Math.max(250,num(rec.options.safetyMs,600));
var lead=responseEstimateFor(rec)+ safety;
lead*=clamp(num(currentProfile().lookahead_scale,1),1.00,1.15)
*(auctionSignal()=== 'strong' ?1.08:1)
*networkLeadScale();
near=clamp(Math.max(near,speed*(lead / 1000)),near,ceiling);
}
var leadingEdge=motion.direction<0?-near:-64;
var eligible=rect.bottom>=leadingEdge&&rect.top<=seen + near;
rec.dynamicNear=Math.round(near);
rec.estimatedArrivalMs=arrival;
rec.distanceToViewport=Math.round(distance);
return{eligible:eligible,near:near,ceiling:ceiling,distance:distance,arrival:arrival,rect:rect};
}
function rangeFor(rec){
if(rec.rangeFrame!==frameId||!rec.lastRange){
rec.lastRange=rangeInfo(rec);
rec.rangeFrame=frameId;
if(pageVisible()&&(!rec.media||rec.media.matches)){
if(rec.lastRange.eligible&&rec.firstNearbyMs==null)rec.firstNearbyMs=now();
if(inView(rec.lastRange.rect)&&rec.lastRange.rect.width>0&&rec.firstOpportunityVisibleMs==null)rec.firstOpportunityVisibleMs=now();
}
}
return rec.lastRange;
}
function networkLeadScale(){
var c =navigator.connection||navigator.mozConnection||navigator.webkitConnection;
if(!c)return 1;
if(c.saveData)return 0.88;
var type=String(c.effectiveType|| '');
if(type=== 'slow-2g' ||type=== '2g')return 1.28;
if(type=== '3g')return 1.14;
return 1;
}
function inRange(rec){return rangeFor(rec).eligible;}
function exposureAllows(rec){
if(rec.critical)return true;
var tier=tierOf(rec);
if(tier=== 'reach' ||tier=== 'premium')return true;
var info=rangeFor(rec),rect=info&&info.rect;
if(inView(rect))return true;
if(motion.paceVh<=RULES.flick_vh_s)return true;
armPace(180);
return false;
}
function unwatchProximity(rec){
if(!rec.proximityGroup)return;
rec.proximityGroup.observer.unobserve(rec.box);
rec.proximityGroup.count--;
if(!rec.proximityGroup.count){
rec.proximityGroup.observer.disconnect();
delete proximityObservers[String(rec.proximityMargin)];
}
rec.proximityGroup=null;
}
function watchProximity(rec){
if(rec.requested||rec.closed||typeof w.IntersectionObserver!== 'function')return;
if(rec.media&&!rec.media.matches){unwatchProximity(rec);return;}
var near=restingLead(rec);
if(!engine.engaged&&!rec.critical)near=Math.min(near,Math.round(viewportHeight()*RULES.governor.warmup_lookahead_vh));
var margin=Math.round(near),key=String(margin);
if(rec.proximityMargin===margin&&rec.proximityGroup)return;
unwatchProximity(rec);
if(!proximityObservers[key]){
proximityObservers[key]={observer:new w.IntersectionObserver(schedule,{rootMargin:margin + 'px 0px',threshold:0}),count:0};
}
rec.proximityMargin=margin;
rec.proximityGroup=proximityObservers[key];
rec.proximityGroup.count++;
rec.proximityGroup.observer.observe(rec.box);
}
function visibleHost(rec,host){
host=host||rec.box;
if(typeof host.checkVisibility=== 'function'){
try{
if(!host.checkVisibility({contentVisibilityAuto:true,opacityProperty:true,visibilityProperty:true}))return false;
}catch(e){}
}
for(var node=host;node&&node.nodeType===1;node=node.parentElement){
var css=w.getComputedStyle(node);
if(node.hidden||css.display=== 'none' ||css.visibility=== 'hidden' ||css.visibility=== 'collapse' ||
css.contentVisibility=== 'hidden' ||parseFloat(css.opacity)===0)return false;
if(node.tagName=== 'DETAILS' &&!node.open){
var summary=node.querySelector(':scope > summary');
if(!summary||!summary.contains(host))return false;
}
if((css.overflowY!== 'visible' &&node.clientHeight<1)||(css.overflowX!== 'visible' &&node.clientWidth<1))return false;
}
return true;
}
function watchReveal(rec){
if(rec.revealObserver||typeof w.MutationObserver!== 'function')return;
rec.revealObserver=new w.MutationObserver(schedule);
for(var node=rec.box;node&&node.nodeType===1;node=node.parentElement){
rec.revealObserver.observe(node,{attributes:true,attributeFilter:['style', 'class', 'hidden', 'open']});
}
rec.revealEnd=schedule;
d.addEventListener('transitionend',rec.revealEnd,true);
d.addEventListener('animationend',rec.revealEnd,true);
}
function unwatchReveal(rec){
if(rec.revealObserver){rec.revealObserver.disconnect();rec.revealObserver=null;}
if(rec.revealEnd){
d.removeEventListener('transitionend',rec.revealEnd,true);
d.removeEventListener('animationend',rec.revealEnd,true);
rec.revealEnd=null;
}
}
function widthOf(box){
var css=w.getComputedStyle(box);
return Math.max(0,box.clientWidth - (parseFloat(css.paddingLeft)||0)-(parseFloat(css.paddingRight)||0));
}
function fixedSizes(rec){
var raw=Array.isArray(rec.options.sizes)?rec.options.sizes:[];
return raw.filter(function(s){return Array.isArray(s)&&s.length===2&&Number(s[0])>0&&Number(s[1])>0;})
.map(function(s){return[Math.round(Number(s[0])),Math.round(Number(s[1]))];})
.sort(function(a,b){return b[0]- a[0];});
}
function fittingSize(rec,width){
var sizes=fixedSizes(rec);
for(var i =0;i<sizes.length;i++)if(sizes[i][0]<=width + 0.5)return sizes[i];
return null;
}
function syncStickyFit(rec){
if(!rec.stickyCandidate||rec.closed||!rec.box.isConnected)return;
var rect=rec.box.getBoundingClientRect(),creative=rec.ins&&rec.ins.getBoundingClientRect();
var css=w.getComputedStyle(rec.box),offset=parseFloat(css.top);
if(!isFinite(offset))offset=parseFloat(css.insetBlockStart);
var available=usableViewportHeight(),width=Math.max(rect.width||0,creative?creative.width||0:0);
var height=Math.max(rect.height||0,creative?(creative.height||0)+ bandOf(rec):0);
var viewportKey=viewportWidth()+ ':' + available + ':' +(isFinite(offset)?offset: 'unknown');
if(rec.stickyViewport!==viewportKey){rec.stickyViewport=viewportKey;rec.stickyRejectedViewport= '';}
var reason= '';
if(!viewportHasArea())reason= 'viewport-unavailable';
else if(viewportWidth()<RULES.desktopMinWidth)reason= 'not-desktop';
else if(rec.gameNavigation&&rec.gameNavigation.isConnected)reason= 'game-navigation-flow';
else if(!isFinite(offset)||offset<0)reason= 'unknown-offset';
else if(width<=0||height<=0)reason= 'waiting-layout';
else if(width>300)reason= 'width-exceeds-300';
else if(rect.left<0||rect.right>viewportWidth()||(creative&&(creative.left<0||creative.right>viewportWidth())))reason= 'outside-horizontal-viewport';
else if(accountAnchorRects().some(function(anchor){
return anchor.left<rect.right&&anchor.right>rect.left&&anchor.top<offset + height&&anchor.bottom>offset;
}))reason= 'account-anchor-overlap';
else if(height + offset>available)reason= 'height-exceeds-viewport';
else if(rec.stickyRejectedViewport===viewportKey)reason= 'same-viewport-latch';
if(reason=== 'width-exceeds-300' ||reason=== 'outside-horizontal-viewport' ||reason=== 'height-exceeds-viewport')rec.stickyRejectedViewport=viewportKey;
rec.stickyFit=!reason;rec.stickyReason=reason|| 'fits';
rec.stickyGeometry={width:Math.round(width),height:Math.round(height),offset:isFinite(offset)?offset:null,availableHeight:Math.round(available)};
if(rec.stickyFit){
if(rec.box.getAttribute('data-go-ad-sticky-fit')!== '1')rec.box.setAttribute('data-go-ad-sticky-fit', '1');
}else if(rec.box.hasAttribute('data-go-ad-sticky-fit'))rec.box.removeAttribute('data-go-ad-sticky-fit');
}
function onScroll(){
if(!paintGate.released)releasePaintGate('scroll');
sampleMotion();
engine.maxScrollDepth=Math.max(engine.maxScrollDepth||0,currentScrollDepth());
checkScrollEngagement();
schedule();
if(settleTimer)w.clearTimeout(settleTimer);
settleTimer=w.setTimeout(function(){
settleTimer=0;
motion.velocity=0;
motion.direction=0;
motion.paceVh=0;
schedule();
},170);
}
function onResize(){sampleMotion();pending.forEach(watchProximity);schedule();}
function watchMedia(rec){
if(!rec.media)return;
var change=function(){watchProximity(rec);updateListeners();schedule();};
if(typeof rec.media.addEventListener=== 'function')rec.media.addEventListener('change',change);
else if(typeof rec.media.addListener=== 'function')rec.media.addListener(change);
else return;
rec.mediaChange=change;
}
function unwatchMedia(rec){
if(!rec.mediaChange)return;
if(typeof rec.media.removeEventListener=== 'function')rec.media.removeEventListener('change',rec.mediaChange);
else if(typeof rec.media.removeListener=== 'function')rec.media.removeListener(rec.mediaChange);
rec.mediaChange=null;
}
function updateListeners(){
var need=adjustments.size>0;
pending.forEach(function(rec){if(!rec.media||rec.media.matches||!rec.mediaChange)need=true;});
if(need&&!listening){
w.addEventListener('scroll',onScroll,{passive:true});
listening=true;
}else if(!need&&listening){
w.removeEventListener('scroll',onScroll);
listening=false;
}
var hasSticky=records.some(function(rec){return rec.stickyCandidate&&!rec.closed&&rec.box.isConnected;});
if(hasSticky)ensureAnchorWatch();else stopAnchorWatch();
var needResize=need||hasSticky;
if(needResize&&!resizeListening){w.addEventListener('resize',onResize,{passive:true});resizeListening=true;}
else if(!needResize&&resizeListening){w.removeEventListener('resize',onResize);resizeListening=false;}
}
function watch(node,rec){
if(!node||typeof w.ResizeObserver!== 'function')return;
if(!ro)ro=new w.ResizeObserver(function(entries){
entries.forEach(function(entry){
var item=measured.get(entry.target);
if(!item||item.closed)return;
if(entry.target===item.ins&& /^(filled|unfill-optimized)$/.test(item.providerStatus))adjustments.add(item);
syncStickyFit(item);
});
schedule();
});
measured.set(node,rec);
ro.observe(node);
}
function armStuckSweep(){
if(stuckTimer)return;
stuckTimer=w.setTimeout(function(){
stuckTimer=0;
var live=false,released=0;
records.forEach(function(r){
if(!r.requested||r.closed||r.error||r.providerStatus)return;
if((now()- r.requestedMs)>=RULES.stuck_release_ms){
if(!r.stuckReleased){r.stuckReleased=true;released++;state(r, 'provider-no-response');releaseCritical(r);}
}else{live=true;}
});
if(released){engine.releasedStuck +=released;schedule();}
if(live)armStuckSweep();
},1000);
}
var creativeOriginWarmed=false;
function warmCreativeOrigin(){
if(creativeOriginWarmed)return;
creativeOriginWarmed=true;
try{
var head=d.head||d.documentElement;
if(!head||d.querySelector('link[rel="preconnect"][href="https://tpc.googlesyndication.com"]'))return;
var link=d.createElement('link');
link.rel= 'preconnect';
link.href= 'https://tpc.googlesyndication.com';
head.appendChild(link);
}catch(e){}
}
var VIEW_LARGE_AREA=242500;
function syncViewableRatio(rec){
var box=rec.ins?rec.ins.getBoundingClientRect():null;
var area=box?Math.max(0,box.width||0)*Math.max(0,box.height||0):0;
rec.viewableRatio=area>=VIEW_LARGE_AREA?0.3:0.5;
return rec.viewableRatio;
}
function viewableRatioFor(rec){return rec.viewableRatio>0?rec.viewableRatio:0.5;}
function usableVisibleRatio(rec,entry){
var r =(entry&&entry.boundingClientRect)||(rec.ins?rec.ins.getBoundingClientRect():null);
if(!r)return 0;
var width=Math.max(0,r.width||0),height=Math.max(0,r.height||0);
if(width<1||height<1)return 0;
var visibleY=Math.max(0,Math.min(usableViewportHeight(),r.bottom)- Math.max(0,r.top));
var visibleX=Math.max(0,Math.min(viewportWidth(),r.right)- Math.max(0,r.left));
return clamp((visibleY*visibleX)/(width*height),0,1);
}
function viewableTotal(rec){
var total=rec.viewable50Ms||0;
if(rec.viewStartMs!=null&&pageVisible())total +=Math.max(0,now()- rec.viewStartMs);
return Math.round(total);
}
function stopViewClock(rec){
if(rec.viewTimer){w.clearTimeout(rec.viewTimer);rec.viewTimer=0;}
if(rec.viewStartMs!=null){
rec.viewable50Ms=(rec.viewable50Ms||0)+ Math.max(0,now()- rec.viewStartMs);
rec.viewStartMs=null;
}
}
function startViewClock(rec){
if(rec.closed||!rec.box.isConnected||!rec.viewObserved||
!/^(filled|unfill-optimized)$/.test(rec.providerStatus)||!pageVisible()||
rec.currentRatio<viewableRatioFor(rec))return;
if(rec.viewStartMs==null)rec.viewStartMs=now();
if(!rec.localViewable&&!rec.viewTimer){
rec.viewTimer=w.setTimeout(function(){
rec.viewTimer=0;
if(!rec.closed&&rec.currentRatio>=viewableRatioFor(rec)&&pageVisible()&& /^(filled|unfill-optimized)$/.test(rec.providerStatus)){
rec.localViewable=true;
rec.localViewableAt=Date.now();
rec.box.setAttribute('data-go-ad-local-viewable', '1');
}
},1000);
}
}
function updateViewClock(rec,entry){
if(!rec||rec.closed||!rec.viewObserved)return;
rec.currentRatio=usableVisibleRatio(rec,entry);
rec.maxIntersectionRatio=Math.max(rec.maxIntersectionRatio||0,rec.currentRatio);
if(rec.currentRatio>=viewableRatioFor(rec)&&pageVisible())startViewClock(rec);else stopViewClock(rec);
}
function refreshViewClocks(){
records.forEach(function(rec){if(rec.viewObserved)updateViewClock(rec,null);});
}
function ensureViewObserver(){
if(viewObserver||typeof w.IntersectionObserver!== 'function')return;
viewObserver=new w.IntersectionObserver(function(entries){
entries.forEach(function(entry){
var rec=viewMeasured.get(entry.target);
if(!rec||rec.closed)return;
updateViewClock(rec,entry);
});
},{threshold:[0,0.3,0.5,0.75,1]});
}
function observeViewability(rec){
if(!rec.ins||rec.viewObserved)return;
ensureViewObserver();
if(!viewObserver)return;
rec.viewObserved=true;
syncViewableRatio(rec);
viewMeasured.set(rec.ins,rec);
viewObserver.observe(rec.ins);
}
function handleVisibility(){
records.forEach(function(rec){
if(!pageVisible()){stopViewClock(rec);closeGateClock(rec);}
else{if(rec.currentRatio>=viewableRatioFor(rec))startViewClock(rec);openGateClock(rec);}
});
if(!pageVisible()){
stopDwell();
if(engine.hiddenSinceWall==null){engine.hiddenSinceWall=Date.now();persistTopScrollSession();}
}else{
resumeTopScrollSession(engine.refreshTopScrollOnResume);
engine.refreshTopScrollOnResume=false;
engine.hiddenSinceWall=null;
startDwell();
}
if(pageVisible()){
motion.velocity=0;
motion.direction=0;
motion.paceVh=0;
motion.y=scrollY();
motion.t=now();
schedule();
}
}
function removePending(rec){
pending.delete(rec);
unwatchMedia(rec);
unwatchProximity(rec);
unwatchReveal(rec);
if(ro)ro.unobserve(rec.box);
updateListeners();
}
function dispose(rec){
unwatchMedia(rec);
unwatchReveal(rec);
unwatchProximity(rec);
releaseCritical(rec);
pending.delete(rec);adjustments.delete(rec);
stopViewClock(rec);
closeGateClock(rec);
if(rec.smartWake){w.clearTimeout(rec.smartWake);rec.smartWake=0;}
if(rec.observer){rec.observer.disconnect();rec.observer=null;}
if(ro){ro.unobserve(rec.box);if(rec.ins)ro.unobserve(rec.ins);}
if(viewObserver&&rec.ins&&rec.viewObserved){viewObserver.unobserve(rec.ins);rec.viewObserved=false;}
updateListeners();
}
function reserve(rec,px){
px=Math.max(0,Math.ceil(px));
if(rec.reserved===px)return;
rec.reserved=px;
rec.box.style.setProperty('--go-ad-resolved-reserve',px + 'px');
}
function bandOf(rec){
if(rec.placement!== 'topscroll')return LABEL_BAND;
var css=w.getComputedStyle(rec.box);
var band=(parseFloat(css.paddingTop)||0)+(parseFloat(css.paddingBottom)||0);
return band>0?Math.ceil(band):LABEL_BAND;
}
function fitFilled(rec){
if(!rec.ins||rec.closed||rec.box.hidden){adjustments.delete(rec);return;}
var height=Math.max(rec.ins.offsetHeight||0,rec.ins.getBoundingClientRect().height||0);
if(!height){adjustments.delete(rec);return;}
if(rec.providerStatus=== 'filled')rememberHeight(rec,height);
var target=Math.ceil(height)+ bandOf(rec);
var current=rec.reserved==null?(parseFloat(w.getComputedStyle(rec.box).minHeight)||0):rec.reserved;
if(rec.placement=== 'topscroll'){
reserve(rec,Math.max(rec.initialReserve,current,target));
adjustments.delete(rec);
}else if(target>=current||belowViewport(rec)){
reserve(rec,target);
adjustments.delete(rec);
}else{
adjustments.add(rec);
}
if(rec.viewObserved){syncViewableRatio(rec);updateViewClock(rec,null);}
syncStickyFit(rec);
updateListeners();
}
function collapseEmpty(rec){
if(rec.closed||!rec.box.isConnected){dispose(rec);return;}
var provider=rec.ins?(rec.ins.getAttribute('data-ad-status')|| ''): '';
if(provider!== 'unfilled'){adjustments.delete(rec);updateListeners();return;}
if(!rec.box.classList.contains('go-ad-slot--collapse-unfilled')){
state(rec, 'unfilled-reserved');
adjustments.delete(rec);updateListeners();return;
}
if(belowViewport(rec)||(rec.placement=== 'topscroll' &&aboveViewport(rec))){
rec.box.setAttribute('data-go-ad-empty', '1');
state(rec, 'unfilled-collapsed');
adjustments.delete(rec);
}else{
state(rec, 'unfilled-awaiting-safe-collapse');
adjustments.add(rec);
}
updateListeners();
}
function status(rec){
if(!rec.ins||rec.closed)return;
var value=rec.ins.getAttribute('data-ad-status')|| '';
rec.providerStatus=value;
rec.providerInitStatus=rec.ins.getAttribute('data-adsbygoogle-status')|| '';
if((value||rec.providerInitStatus=== 'done')&&rec.providerAcceptedMs==null){
rec.providerAcceptedMs=Math.max(0,now()- rec.requestedMs);
}
if(value&&rec.responseMs==null){
rec.responseMs=Math.max(0,now()- rec.requestedMs);
var foregroundResponse=pageVisible()&&rec.requestDwellMs!=null&&Math.abs(rec.responseMs - (dwellMs()- rec.requestDwellMs))<=250;
learnResponse(rec.responseMs,value,foregroundResponse);
if(value=== 'filled')rec.fillLatencyLearned=foregroundResponse;
}
if(value=== 'filled' &&!rec.fillLatencyLearned){
var filledMs=Math.max(0,now()- rec.requestedMs);
if(filledMs>0&&pageVisible()&&rec.requestDwellMs!=null&&Math.abs(filledMs - (dwellMs()- rec.requestDwellMs))<=250){
learnFilledResponse(filledMs);rec.fillLatencyLearned=true;
}
}
if(value){releaseCritical(rec);schedule();}
if(value!== 'unfilled')rec.box.removeAttribute('data-go-ad-empty');
if(value=== 'filled' ||value=== 'unfill-optimized'){
rec.box.setAttribute('data-go-ad-present', '1');
if(value=== 'filled'){
rec.box.setAttribute('data-go-ad-filled', '1');
state(rec, 'filled');
if(!rec.filled){rec.filled=true;rec.filledAt=Date.now();persistFill(rec);}
}else{
rec.box.removeAttribute('data-go-ad-filled');
state(rec, 'optimized');
}
fitFilled(rec);
watch(rec.ins,rec);
observeViewability(rec);
startViewClock(rec);
}else{
stopViewClock(rec);
rec.box.removeAttribute('data-go-ad-filled');
rec.box.removeAttribute('data-go-ad-present');
if(value=== 'unfilled')collapseEmpty(rec);
else if(value||!rec.error)state(rec,value? 'provider-other-status' : 'requested');
}
}
function activate(rec){
if(rec.requested||rec.closed||!rec.box.isConnected){removePending(rec);return;}
if(rec.media&&!rec.media.matches){state(rec, 'ineligible-viewport');return;}
if(!pageVisible()){state(rec, 'waiting-page-visible');return;}
if(!viewportHasArea()){state(rec, 'waiting-viewport-geometry');return;}
if(!allowed(rec)){state(rec, 'waiting-consent');return;}
if(!inRange(rec)){state(rec,engine.engaged? 'waiting-proximity' : 'waiting-engagement');return;}
if(criticalHold(rec)){state(rec, 'waiting-critical-first');return;}
if(paintHold(rec)){state(rec, 'waiting-first-paint');return;}
if(!budgetAllows(rec)){state(rec, 'waiting-opportunity-budget');return;}
if(!exposureAllows(rec)){state(rec, 'waiting-exposure');return;}
if(!densityAllows(rec)){state(rec, 'waiting-content-density');return;}
if(!pacingAllows(rec)){state(rec, 'waiting-pacing');return;}
if(!rec.box.getClientRects().length||!visibleHost(rec)){state(rec, 'waiting-visible-host');watchReveal(rec);return;}
unwatchReveal(rec);
var width=widthOf(rec.box);
rec.availableWidth=width;
if(width<1){state(rec, 'waiting-width');return;}
var size=null;
if(rec.options.fixed){
if(!fixedSizes(rec).length){state(rec, 'invalid-fixed-size-config');removePending(rec);return;}
size=fittingSize(rec,width);
if(!size){state(rec, 'no-fitting-size');return;}
}
var fillHistory=rec.options.frequencyMax?history(rec):[];
if(rec.options.frequencyMax&&fillHistory.length>=rec.options.frequencyMax){
rec.box.hidden=true;state(rec, 'frequency-capped');removePending(rec);return;
}
if(!topScrollSmartAllows(rec,fillHistory.length)){
state(rec, 'waiting-session-engagement');return;
}
if(slotOwners[rec.slot]&&slotOwners[rec.slot]!==rec){
rec.box.hidden=true;state(rec, 'alternative-already-requested');removePending(rec);return;
}
var node=rec.template.content.firstElementChild;
if(!node||node.tagName!== 'INS' ||!rec.slot||node.hasAttribute('data-ad-status')||node.hasAttribute('data-adsbygoogle-status')){
state(rec, 'invalid-markup');removePending(rec);return;
}
rec.initialReserve=parseFloat(w.getComputedStyle(rec.box).minHeight)||0;
if(size){
node.style.width=size[0]+ 'px';
node.style.height=size[1]+ 'px';
reserve(rec,size[1]+ bandOf(rec));
}else{
node.style.width= '100%';node.style.minWidth= '1px';
}
rec.template.replaceWith(node);
rec.ins=node;
var box=node.getBoundingClientRect();
if(box.width<1||(size&&box.height<1)||!visibleHost(rec,node)){
node.replaceWith(rec.template);rec.template.content.appendChild(node);
rec.ins=null;state(rec, 'waiting-geometry');watchReveal(rec);return;
}
slotOwners[rec.slot]=rec;
if(reserveOnRequest&&!size&&rec.initialReserve<1&&(rec.reserved==null||rec.reserved<1)&&
box.top>=usableViewportHeight()&&rec.box.classList.contains('go-ad-slot--collapse-unfilled')){
reserve(rec,Math.round(nominalHeight(rec))+ bandOf(rec));
rec.predictedReserve=rec.reserved;
}
rec.requested=true;rec.requestedMs=now();rec.requestDwellMs=dwellMs();
rec.heldMs=rec.holdStartMs==null?0:Math.max(0,rec.requestedMs - rec.holdStartMs);
rec.engagedAtRequest=engine.engaged;
rec.governorAtRequest=engine.governor;
rec.valueAtRequest=Math.round(expectedValue(rec)*1000)/ 1000;
rec.reachAtRequest=Math.round(reachProbability(rec)*1000)/ 1000;
rec.regimeAtRequest=decision().regime;
if(!rec.critical)engine.lastNonCriticalRequestAt=rec.requestedMs;
if(rec.critical){
engine.criticalInFlight.add(rec);
engine.criticalHoldUntil=Math.max(engine.criticalHoldUntil,rec.requestedMs + RULES.critical_hold_ms);
}
rec.box.setAttribute('data-go-ad-requested', '1');
var requestRange=rangeFor(rec);
rec.distanceAtRequest=Math.round(requestRange.distance||0);
rec.dynamicNearAtRequest=Math.round(requestRange.near||0);
rec.estimatedArrivalAtRequest=requestRange.arrival==null?null:Math.round(requestRange.arrival);
rec.scrollVelocityAtRequest=Math.round(motion.velocity);
rec.paceVhAtRequest=Math.round(motion.paceVh*100)/ 100;
rec.responseEstimateAtRequest=Math.round(responseEstimateFor(rec));
rec.requestScrollY=Math.round(scrollY());
rec.requestSize={width:Math.round(box.width),height:Math.round(box.height)};
state(rec, 'requested');
removePending(rec);
if(typeof w.MutationObserver=== 'function'){
rec.observer=new w.MutationObserver(function(){status(rec);});
rec.observer.observe(node,{attributes:true,attributeFilter:['data-ad-status', 'data-adsbygoogle-status']});
}
armStuckSweep();
warmCreativeOrigin();
try{
(w.adsbygoogle=w.adsbygoogle||[]).push({});
status(rec);
}catch(e){
rec.error=String(e&&e.message||e);state(rec, 'request-error');
releaseCritical(rec);
}
if(pending.size)schedule();
}
function sweep(){
frame=0;
frameId++;
checkScrollEngagement();
evaluateGovernor();
var sweepReserve=overlayReserve();
if(sweepReserve!==engine.clockReserve){engine.clockReserve=sweepReserve;refreshViewClocks();}
var queue=Array.from(pending).map(function(rec){return{rec:rec,score:requestPriority(rec)};});
queue.sort(function(a,b){return b.score - a.score;});
queue.forEach(function(item){activate(item.rec);});
adjustments.forEach(function(rec){
if(!rec.box.isConnected||rec.closed||rec.box.hidden){dispose(rec);return;}
if(rec.providerStatus=== 'unfilled')collapseEmpty(rec);
else if(/^(filled|unfill-optimized)$/.test(rec.providerStatus))fitFilled(rec);
else adjustments.delete(rec);
});
records.forEach(syncStickyFit);
updateListeners();
}
function schedule(){if(!frame)frame=w.requestAnimationFrame(sweep);}
function mount(box,options){
if(!box||mounted.has(box)||!box.hasAttribute('data-go-ad-placement'))return;
var template=null;
for(var i =0;i<box.children.length;i++){
if(box.children[i].tagName=== 'TEMPLATE' &&box.children[i].hasAttribute('data-go-ad-pending'))template=box.children[i];
}
if(!template)return;
mounted.add(box);
var unit=template.content.firstElementChild;
var attr=function(name){return parseInt(box.getAttribute(name)|| '',10)||null;};
var rec={
box:box,template:template,options:options||{},placement:box.getAttribute('data-go-ad-placement'),
slot:unit&&unit.getAttribute('data-ad-slot'),state: '',requested:false,initialReserve:0,reserved:null,
filled:false,persisted:false,observer:null,providerStatus: '',timeline:[],closed:false,smartWake:0,
gateStats:Object.create(null),gateStartMs:null,densityReason: '',densityChecks:Object.create(null),
mountedMs:now(),availableWidth:null,currentRatio:0,maxIntersectionRatio:0,viewable50Ms:0,viewableRatio:0,
viewStartMs:null,viewTimer:0,localViewable:false,viewObserved:false,stuckReleased:false,
critical:!!(options&&options.priority=== 'critical'),holdStartMs:null,heldMs:0,paintHeldMs:null,engagedAtRequest:null,
rectCache:null,rectFrame:-1,nominalCache:0,nominalFrame:-1,rangeFrame:-1,
firstNearbyMs:null,firstOpportunityVisibleMs:null,budgetPath: '',reachedReserveQualified:false,
stickyCandidate:box.classList.contains('go-article-sidebar__ad--sticky'),stickyFit:false,stickyReason: 'not-applicable',
stickyViewport: '',stickyRejectedViewport: '',stickyGeometry:null,gameNavigation:null,
tier:box.getAttribute('data-go-ad-tier')||(options&&options.tier)|| '',
surface:box.getAttribute('data-go-ad-surface')|| '',
plannerScore:parseFloat(box.getAttribute('data-go-ad-planner-score')|| '')||null,
plannerDepth:attr('data-go-ad-depth'),
articleWords:attr('data-go-ad-body-words')||attr('data-go-ad-article-words'),
articleProfile:box.getAttribute('data-go-ad-profile')|| '',
articleType:box.getAttribute('data-go-ad-article-type')|| '',
plannedBodyCount:attr('data-go-ad-planned-count'),
renderedBodyCount:attr('data-go-ad-rendered-count'),
fallbackReserve:box.getAttribute('data-go-ad-fallback-reserve')=== '1',
eligibleCandidates:attr('data-go-ad-eligible-candidates'),
structuralBodyCapacity:attr('data-go-ad-body-capacity'),
listingIndex:attr('data-go-ad-listing-index')
};
if(rec.stickyCandidate&&box.classList.contains('go-game-sidebar-revenue')){
for(var gameRoot=box.parentElement;gameRoot&&gameRoot.nodeType===1;gameRoot=gameRoot.parentElement){
if(gameRoot.classList.contains('od-games')){rec.gameNavigation=gameRoot.querySelector('.od-game-nav');break;}
}
}
if(rec.articleWords)engine.articleWords=Math.max(engine.articleWords||0,rec.articleWords);
if(box.hasAttribute('data-go-ad-planned-count')||box.hasAttribute('data-go-ad-body-capacity'))engine.plannerTelemetry=true;
if(engine.plannerTelemetry){
engine.plannedBodyCount=Math.max(engine.plannedBodyCount||0,Math.max(0,rec.plannedBodyCount||0));
engine.renderedBodyCount=Math.max(engine.renderedBodyCount||0,Math.max(0,rec.renderedBodyCount||0));
if(rec.fallbackReserve)engine.reserveBodyCount=Math.max(engine.reserveBodyCount||0,1);
engine.eligibleCandidates=Math.max(engine.eligibleCandidates||0,Math.max(0,rec.eligibleCandidates||0));
engine.structuralBodyCapacity=Math.max(engine.structuralBodyCapacity||0,Math.max(0,rec.structuralBodyCapacity||0));
if(rec.articleType)engine.articleType=engine.articleType||rec.articleType;
}
rec.key= 'go_adsense_topscroll_24h_' + rec.slot;
rec.media=rec.options.media&&w.matchMedia?w.matchMedia(rec.options.media):null;
records.push(rec);pending.add(rec);
applyRememberedReserve(rec);
state(rec, 'pending');syncStickyFit(rec);watchMedia(rec);watch(box,rec);watchProximity(rec);updateListeners();activate(rec);
}
function pendingUnit(box){
for(var i =0;box&&i<box.children.length;i++){
var child=box.children[i];
if(child.tagName=== 'TEMPLATE' &&child.hasAttribute('data-go-ad-pending'))return child.content&&child.content.firstElementChild;
}
return null;
}
function parseMountOptions(box){
try{
var raw=box.getAttribute('data-go-ad-options');
if(!raw||raw.length>12000)return null;
var value=JSON.parse(raw);
return value&&typeof value=== 'object' &&!Array.isArray(value)?value:null;
}catch(e){return null;}
}
function removeNode(node){
if(node&&typeof node.remove=== 'function')node.remove();
else if(node&&node.parentNode)node.parentNode.removeChild(node);
}
function removeMountScripts(box){
if(box&&typeof box.querySelectorAll=== 'function')Array.prototype.forEach.call(box.querySelectorAll('script'),removeNode);
}
function mountDeclarative(box){
if(!box||mounted.has(box))return false;
var options=parseMountOptions(box),unit=pendingUnit(box);
if(!options||!unit||unit.tagName!== 'INS' ||!unit.getAttribute('data-ad-slot')||
unit.hasAttribute('data-ad-status')||unit.hasAttribute('data-adsbygoogle-status')){dynamicStats.rejectedMarkup++;return false;}
removeMountScripts(box);
var before=records.length;
mount(box,options);
if(records.length>before){dynamicStats.mounted++;return true;}
return false;
}
function materializeListingReserves(){
if(!listingBinding.initialized){
var roots=d.querySelectorAll('[data-go-ad-listing-root="1"]');
if(d.readyState=== 'loading')return 0;
listingBinding.initialized=true;
if(roots.length!==1)return 0;
listingBinding.root=roots[0];
listingBinding.reserves=Array.prototype.slice.call(d.querySelectorAll('template[data-go-listing-reserve]'));
}
var root=listingBinding.root;
if(!root||!root.isConnected)return 0;
var selector=root.getAttribute('data-go-ad-listing-card-selector'),cards=[];
if(!selector||selector.length>160)return 0;
try{
cards=Array.prototype.filter.call(root.children||[],function(node){
return typeof node.matches=== 'function' &&node.matches(selector);
});
}catch(e){return 0;}
var made=0;
listingBinding.reserves.slice().forEach(function(template){
if(template.isConnected===false){listingBinding.reserves=listingBinding.reserves.filter(function(candidate){return candidate!==template;});return;}
var after=parseInt(template.getAttribute('data-go-listing-after')|| '',10);
if(!isFinite(after)||after<1||cards.length<after)return;
listingBinding.reserves=listingBinding.reserves.filter(function(candidate){return candidate!==template;});
var box=template.content&&template.content.firstElementChild,unit=pendingUnit(box);
if(!box||!box.hasAttribute('data-go-ad-placement')||!parseMountOptions(box)||!unit||unit.hasAttribute('data-ad-status')||unit.hasAttribute('data-adsbygoogle-status')){dynamicStats.rejectedMarkup++;removeNode(template);return;}
var slot=unit.getAttribute('data-ad-slot');
if(!slot||records.some(function(record){return record.slot===slot;})){
dynamicStats.skippedDuplicate++;removeNode(template);return;
}
removeMountScripts(box);
root.insertBefore(box,cards[after - 1].nextSibling||null);
removeNode(template);
if(mountDeclarative(box)){made++;dynamicStats.materialized++;}
});
return made;
}
function scan(root){
root=root&&typeof root.querySelectorAll=== 'function' ?root:d;
dynamicStats.scans++;
var made=materializeListingReserves();
if(root.hasAttribute&&root.hasAttribute('data-go-ad-options')&&mountDeclarative(root))made++;
Array.prototype.forEach.call(root.querySelectorAll('[data-go-ad-placement][data-go-ad-options]'),function(box){
if(mountDeclarative(box))made++;
});
if(made)schedule();
return made;
}
function contentUpdated(event){
var detail=event&&event.detail||{};
scan(detail.root||detail.scope||d);
}
function diagnosticSnapshot(){return null;}
function flushDiagnostics(){return null;}
function inspect(){
return{version:VERSION,lean:true,mounted:records.length,
requested:records.filter(function(r){return r.requested;}).length,
note: 'Cópia pública enxuta: o diagnóstico completo é servido ao administrador logado.' };
}
function explain(){return 'Cópia pública enxuta. Abra a página como administrador para o relatório completo.';}
d.addEventListener('visibilitychange',handleVisibility);
armPaintGate();
['pointerdown', 'keydown', 'touchstart'].forEach(function(event){
d.addEventListener(event,releasePaintGateOnInput,{passive:true,once:true});
});
startDwell();
checkScrollEngagement();
['wp_listen_for_consent_change', 'wp_consent_type_defined', 'go:consent-change', 'go:ads-consent-update'].forEach(function(event){
d.addEventListener(event,changedConsent);
});
d.addEventListener('DOMContentLoaded',function(){scan(d);schedule();},{once:true});
d.addEventListener('go:content-updated',contentUpdated);
d.addEventListener('load',function(){if(pending.size)schedule();},true);
w.addEventListener('pageshow',function(event){
engine.pageHidden=false;
engine.refreshTopScrollOnResume=!!(event&&event.persisted);
if(engine.refreshTopScrollOnResume)engine.readerModel=null;
handleVisibility();
schedule();
});
w.addEventListener('pagehide',function(){
engine.pageHidden=true;
handleVisibility();
persistReaderModel();
flushDiagnostics('pagehide');
});
w.GOAdsRuntime={
version:VERSION,mount:mount,scan:scan,inspect:inspect,explain:explain,
diagnosticSnapshot:diagnosticSnapshot,flushDiagnostics:flushDiagnostics,
diagnosticBuffer:function(){return diagnosticBuffer.slice();},
dismiss:function(box){
records.forEach(function(r){if(r.box===box){r.closed=true;state(r, 'dismissed');dispose(r);}});
}
};
loadLatencyMemory();
if(d.readyState=== 'interactive' ||d.readyState=== 'complete')scan(d);
d.dispatchEvent(new Event('go:ads-runtime-ready'));
})(window,document);
