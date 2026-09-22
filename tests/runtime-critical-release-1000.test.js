'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { makeEnvironment, boot, mountAd } = require('./helpers/runtime-harness');
const php = process.env.GO_TEST_PHP || 'php';
const fixture = JSON.parse(execFileSync(php, [path.join(__dirname, 'export-delivery-fixture.php')], { encoding:'utf8' }));
function flush(env){ for(let i=0;env.frames.length&&i<100;i++) env.frames.splice(0).forEach(cb=>cb()); assert.equal(env.frames.length,0); }
function ctx(height){
  const env=makeEnvironment(JSON.parse(JSON.stringify(fixture.config)),{scrollY:0,now:1000,innerHeight:height,articleWords:1000,plannedBodyCount:7,renderedBodyCount:7,structuralBodyCapacity:7,contentHeight:10000,documentHeight:11000});
  return {env,runtime:boot(env)};
}
function mount(c,name,top,answer){ const item=fixture.units[name]; return mountAd(c.runtime,c.env,{placement:name,slot:item.unit.slot,tier:item.options.tier,top,near:item.options.near,nearMax:item.options.nearMax,predictive:item.options.predictive,safetyMs:item.options.safetyMs,critical:item.options.priority==='critical',inContent:name.startsWith('article-'),surface:name==='article-end'?'article-completion':(name.startsWith('article-')?'article':'global'),answer}); }
for(let i=0;i<1000;i++){
  const h=[568,667,736,800,844,900,1080][i%7];
  const high=(i%2)===0;
  const c=ctx(h);
  mount(c,'topscroll',20,'__NO_STATUS__'); flush(c.env);
  assert.equal(c.runtime.inspect().manual[0].requested,true,`critical starts case ${i}`);
  const name=high ? ((i%4)===0?'article-prime':'article-a1') : 'article-a4';
  const distance=Math.min(180,Math.floor(h*0.22));
  mount(c,name,h+distance,'filled'); flush(c.env);
  const target=c.runtime.inspect().manual.find(x=>x.placement===name);
  if(high){
    assert.equal(target.requested,true,`reach/premium near viewport bypasses blind hold case ${i}`);
  }else{
    assert.equal(target.requested,false,`standard tier preserves critical hold case ${i}`);
    c.env.advance(820); flush(c.env);
    assert.equal(c.runtime.inspect().manual.find(x=>x.placement===name).requested,true,`standard releases after hold case ${i}`);
  }
}
console.log(JSON.stringify({suite:'critical-release-1000',cases:1000,checks:2500,passed:true}));
