// node prototypes/faces/check-characters.cjs — no installed dependencies.
const assert = require('node:assert/strict')
const { performance } = require('node:perf_hooks')
require('./faces-core.js'); require('./character-catalog.js'); require('./vector-body.js'); require('./vector-wardrobe.js'); require('./vector-character.js'); require('./character-save.js')
const C=globalThis.FaceCore,R=globalThis.VectorCharacter,S=globalThis.CharacterSave
assert.equal(C.HAIR_STYLES.length,133);assert.equal(C.BEARD_STYLES.length,106)
const g=C.makeGenome('style-check',{sex:'M'})
for(const [key,styles]of [['hair',C.HAIR_STYLES],['beard',C.BEARD_STYLES]]){
 const ids=new Set(),svg=new Set()
 for(const s of styles){assert(!ids.has(s.id));ids.add(s.id);const a=R.build(g,{age:30,hair:key==='hair'?s.id:'social-curto',beard:key==='beard'?s.id:'nenhuma'}).svg;assert(!/NaN|Infinity|undefined/.test(a),s.id);assert(!svg.has(a),'Duplicate artwork: '+s.id);svg.add(a)}
}
let cases=0
for(const sex of ['F','M'])for(const ancestry of Object.keys(C.ANCESTRY))for(const age of [0,1,4,10,16,30,65,90,110])for(const fat of [0,.5,1]){
 const p=C.makeGenome('anatomy-'+ancestry,{sex,ancestry}),before=JSON.stringify(p),opts={age,fat,muscle:1,outfit:cases%2?'jacket':'dress'}
 for(const view of ['portrait','body']){const a=R.build(p,{...opts,view});assert.equal(a.svg,R.build(p,{...opts,view}).svg);assert(!/NaN|Infinity|undefined/.test(a.svg));assert(a.info.height>30&&a.info.height<220)}
 const restored=S.decode(S.encode(p,opts));assert.deepEqual(restored.genome,p);assert.equal(R.build(p,opts).svg,R.build(restored.genome,restored.view).svg)
 assert.equal(JSON.stringify(p),before);cases++
}
let mom=C.makeGenome('mother',{sex:'F',ancestry:'afro'}),dad=C.makeGenome('father',{sex:'M',ancestry:'east'})
for(let i=0;i<100;i++){
 const child=C.childGenome(mom,dad,'generation-'+i,{sex:i%2?'F':'M'})
 assert.deepEqual(child,C.childGenome(mom,dad,child.id,{sex:child.sex}));assert.deepEqual(child.parents,[mom.id,dad.id])
 assert(Math.abs(Object.values(child.ancestry).reduce((s,x)=>s+x,0)-1)<1e-12)
 for(const k of ['afro','east'])assert.equal(child.ancestry[k],((mom.ancestry[k]||0)+(dad.ancestry[k]||0))/2)
 assert(child.eye.dark[0]===mom.eye.dark[0]||child.eye.dark[0]===mom.eye.dark[1]);assert(child.eye.dark[1]===dad.eye.dark[0]||child.eye.dark[1]===dad.eye.dark[1])
 S.decode(S.encode(child,{age:25}));if(child.sex==='F')mom=child;else dad=child
}
for(const mutate of [p=>p.z.eyeSize=NaN,p=>delete p.asym,p=>p.skin.mel=[2,0],p=>p.pref.hair='__proto__',p=>delete p.pref.shirtHue]){
 const bad=structuredClone(g);mutate(bad);assert.throws(()=>S.validateGenome(bad))
}
for(const [key,choices]of [['outfit',Object.keys(R.OUTFITS)],['glasses',['redondo','retangular','gatinho','aviador','grosso']],['expression',['warm','calm','curious']]]){
 for(const view of key==='outfit'?['body']:['portrait','body']){const artworks=choices.map(value=>R.build(g,{age:30,view,[key]:value}).svg);assert.equal(new Set(artworks).size,choices.length,key+'/'+view+' choices must change artwork')}
}
const start=performance.now();let bytes=0
for(let i=0;i<1000;i++)bytes+=Buffer.byteLength(JSON.stringify(C.makeGenome('population-'+i)))
const genomeMs=performance.now()-start,renderStart=performance.now()
for(let i=0;i<100;i++)R.build(C.makeGenome('population-'+i),{age:20+i%65,view:'body'})
console.log(`Characters passed: 133 unique hair recipes, 106 unique beard recipes, ${cases} body/age/origin combinations, 100 generations, JSON/SVG round trips and invalid save rejection.`)
console.log(`CPU sample: 1000 genomes ${(genomeMs).toFixed(1)} ms / ${(bytes/1024/1024).toFixed(2)} MB JSON; 100 body SVGs ${(performance.now()-renderStart).toFixed(1)} ms. Does not measure mobile frame rate.`)
