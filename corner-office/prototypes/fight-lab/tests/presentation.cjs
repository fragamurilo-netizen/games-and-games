const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const R=require('../replay'), A=require('../appearance');
const dir=path.resolve(__dirname,'../../../game/content');
const read=p=>JSON.parse(fs.readFileSync(path.join(dir,p),'utf8'));
const catalog=read('fight_visuals.json'),arenas=read('arena_profiles.json');
// Fixtures come from the real engine; use one whose fight actually opened a cut.
const cut=e=>Object.values(e.after.cuts||{}).some(v=>v>0);
const log=read('replays/simulated_index.json').map(x=>read('replays/'+x.file)).find(l=>l.events.some(cut)),original=JSON.stringify(log);
assert.ok(log,'At least one engine fixture has a cut');
const player=new R.Player(log,catalog,arenas),all=player.sample(player.duration).stains;
assert.ok(all.length>0,'Cuts leave blood on the mat');
assert.equal(player.sample(0).stains.length,0,'No future blood at start');
for(const mark of all){const e=log.events.find(e=>e.id===mark.source_event);assert.ok(e.after.cuts[e.target_id]>0);assert.ok(['landed','knockdown','stoppage'].includes(e.outcome));assert.ok(Math.abs(mark.x)<arenas.arenas.find(a=>a.id===log.organization_id).radius_m);}
assert.deepEqual(player.sample(player.duration).stains,all,'Seek is deterministic');
assert.equal(JSON.stringify(log),original,'Cosmetics do not modify simulation');
const dry=structuredClone(log);for(const e of dry.events)for(const s of [e.before,e.after])s.cuts={};dry.initial_state=structuredClone(dry.events[0].before);
assert.equal(new R.Player(dry,catalog,arenas).sample(player.duration).stains.length,0,'No cuts, no invented blood');
const context=vm.createContext({console});vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../../face-lab/identity.js'),'utf8')+'\nthis.canon=CANON;',context);
for(const id of ['ftr_costa','ftr_markovic']) {
 const fighter=read('replays/sim_women.json').fighters[id];assert.equal(fighter.sex,1);assert.equal(A.resolve(fighter,context.canon).sex,'f');
 assert.equal(A.resolve({...fighter,appearance_index:0},context.canon).sex,'f','Stale male index cannot override female identity');
 assert.equal(A.resolve({...fighter,appearance_index:null},context.canon).sex,'f','Female fallback stays female');
}
console.log(JSON.stringify({passed:true,blood_marks:all.length,female_identity:true}));
