// Laboratory snapshots have their own version; this is not the game's save schema.
;(function(root){
 'use strict'
 const C=root.FaceCore
 function validateGenome(g){
  if(!g||typeof g.id!=='string'||g.id.length>200||!['M','F'].includes(g.sex))throw Error('Identidade inválida.')
  const ref=C.makeGenome('validation',{sex:g.sex})
  function check(v,s,p){
   if(typeof s==='number'){if(typeof v!=='number'||!Number.isFinite(v)||Math.abs(v)>1e10)throw Error('Traço inválido: '+p)}
   else if(typeof s==='boolean'){if(typeof v!=='boolean')throw Error('Alelo inválido: '+p)}
   else if(Array.isArray(s)){if(!Array.isArray(v)||v.length!==s.length)throw Error('Alelos inválidos: '+p);s.forEach((x,i)=>check(v[i],x,p+'.'+i))}
   else if(s&&typeof s==='object'){if(!v||typeof v!=='object')throw Error('Grupo ausente: '+p);for(const [k,x]of Object.entries(s))check(v[k],x,p+'.'+k)}
  }
  for(const k of ['asym','asymSeed','z','skin','eye','hair'])check(g[k],ref[k],k)
  for(const k of ['fat','heightZ'])check(g.body?.[k],ref.body[k],'body.'+k)
  if(!g.pref||!Object.hasOwn(C.HAIR_BY_ID,g.pref.hair)||!Object.hasOwn(C.BEARD_BY_ID,g.pref.beard))throw Error('Estilo desconhecido.')
  for(const k of ['shirtHue','shirtTone','makeup'])if(!Number.isFinite(g.pref[k])||g.pref[k]<0||g.pref[k]>1)throw Error('Cor de roupa inválida.');
  if(g.asym<0||g.asym>2)throw Error('Assimetria inválida.');
  if(g.body.fat<0||g.body.fat>1||Math.abs(g.body.heightZ)>4)throw Error('Corpo fora dos limites.')
  for(const a of [g.skin.mel,g.eye.dark,g.eye.green,g.hair.eu])if(a.some(x=>x<0||x>1))throw Error('Alelo fora dos limites.')
  for(const v of Object.values(g.z))if(Math.abs(v)>4)throw Error('Proporção fora dos limites.')
  for(const k of Object.keys(C.bodyTraits(ref)))if(g.body[k]!=null&&(!Number.isFinite(g.body[k])||g.body[k]<0||g.body[k]>1))throw Error('Proporção corporal inválida.')
  if(g.ancestry)for(const [k,v]of Object.entries(g.ancestry))if(!C.ANCESTRY[k]||!Number.isFinite(v)||v<0||v>1)throw Error('Origem inválida.')
  return JSON.parse(JSON.stringify(g))
 }
 function decode(text){
  if(text.length>1000000)throw Error('Arquivo muito grande.')
  const d=JSON.parse(text);if(d.version!==1||d.kind!=='paralelo-character')throw Error('Formato não reconhecido.')
  const genome=validateGenome(d.genome),v=d.view||{},view={age:C.clamp(Number.isFinite(v.age)?v.age:30,0,110),fat:Number.isFinite(v.fat)?C.clamp(v.fat):undefined,muscle:Number.isFinite(v.muscle)?C.clamp(v.muscle):undefined,outfit:Object.hasOwn(root.VectorCharacter.OUTFITS,v.outfit)?v.outfit:'casual',expression:['warm','calm','curious'].includes(v.expression)?v.expression:'warm',pose:v.pose==='neutral'?'neutral':'relaxed',hair:Object.hasOwn(C.HAIR_BY_ID,v.hair)?v.hair:undefined,beard:Object.hasOwn(C.BEARD_BY_ID,v.beard)?v.beard:undefined,glasses:v.glasses===null?null:['redondo','retangular','gatinho','aviador','grosso'].includes(v.glasses)?v.glasses:undefined}
  return {genome,view}
 }
 function encode(genome,view){return JSON.stringify({kind:'paralelo-character',version:1,genome:validateGenome(genome),view},null,2)}
 root.CharacterSave={validateGenome,decode,encode}
})(typeof window!=='undefined'?window:globalThis)
