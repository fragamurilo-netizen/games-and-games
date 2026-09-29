;(function(){
 'use strict'
 const C=window.FaceCore,R=window.VectorCharacter,S=window.CharacterSave,$=id=>document.getElementById(id)
 const names={euro:'Europeia',afro:'Africana',east:'Leste asiático',south:'Sul asiático',latin:'Latino-americana',mena:'Oriente Médio / N. África'}
 const state={age:30,fat:-1,muscle:-1,hair:'',beard:'',glasses:'auto',outfit:'casual',pose:'relaxed',expression:'warm',ancestry:''}
 let genome=C.makeGenome('rua-das-flores-12',{sex:'F'}),family=[],familySeed=0,counter=1,page=0,tab='hair',playing=false,repaint=0
 const pageSize=24
 const observer=typeof IntersectionObserver!=='undefined'?new IntersectionObserver(entries=>{for(const e of entries)if(e.isIntersecting){const job=e.target._paint;if(job){R.render(e.target,job.g,{...job.o,res:.6});delete e.target._paint}observer.unobserve(e.target)}},{rootMargin:'300px'}):null
 function options(extra={}){return {age:state.age,fat:state.fat<0?undefined:state.fat/100,muscle:state.muscle<0?undefined:state.muscle/100,hair:state.hair||undefined,beard:state.beard||undefined,glasses:state.glasses==='auto'?undefined:state.glasses==='none'?null:state.glasses,outfit:state.outfit,pose:state.pose,expression:state.expression,...extra}}
 function origin(g){return Object.entries(g.ancestry||{}).filter(([,v])=>v>.005).sort((a,b)=>b[1]-a[1]).map(([k,v])=>`${names[k]} ${Math.round(v*100)}%`).join(' + ')||'Origem mista'}
 function texture(g){const t=C.phenotype(g,state.age).tex;return t<.4?'liso':t<1.2?'ondulado':t<2.2?'cacheado':'crespo'}
 function fillSelect(id,styles,label){$(id).append(new Option(label,''));for(const s of styles)$(id).append(new Option(s.name,s.id))}
 $('outfit').replaceChildren();for(const [id,o]of Object.entries(R.OUTFITS))$('outfit').append(new Option(o.name,id));
 fillSelect('hair',C.HAIR_STYLES,'Natural · do personagem');fillSelect('beard',C.BEARD_STYLES,'Natural · do personagem');$('counts').textContent=C.HAIR_STYLES.length+' / '+C.BEARD_STYLES.length
 function sync(){for(const id of ['age','fat','muscle','hair','beard','glasses','outfit','pose','expression'])$(id).value=state[id];$('sex').value=genome.sex;$('ancestry').value=state.ancestry;$('seed').value=genome.id}
 function render(){
  const start=performance.now(),o=options(),info=R.render($('portrait'),genome,{...o,res:1.6});R.render($('body'),genome,{...o,view:'body',res:1.2})
  $('beard').disabled=genome.sex==='F'||state.age<16;
  $('age-value').textContent=state.age+' anos';$('fat-value').textContent=state.fat<0?'do DNA':state.fat+'%';$('muscle-value').textContent=state.muscle<0?'do DNA':state.muscle+'%';$('height').textContent=(info.height/100).toFixed(2).replace('.',',')+' m'
  $('person-id').textContent=(genome.parents?'SEGUNDA GERAÇÃO / ':'PERSONAGEM / ')+genome.id.slice(-24)
  $('person-title').textContent=(genome.sex==='F'?'Mulher':'Homem')+', '+state.age+' '+(state.age===1?'ano':'anos')
  $('person-style').textContent=C.HAIR_BY_ID[info.hair].name+(info.beard==='nenhuma'?'':' · '+C.BEARD_BY_ID[info.beard].name)
  $('render-status').textContent='2D vetorial · '+Math.round(performance.now()-start)+' ms para as duas vistas'
  const json=S.encode(genome,o);$('genome-size').textContent=(new TextEncoder().encode(json).length/1024).toFixed(1)+' KB por personagem'
  $('dna-summary').textContent=origin(genome)+'. Cabelo '+texture(genome)+', altura adulta '+(C.heightCm(genome,30)/100).toFixed(2).replace('.',',')+' m. '+(genome.parents?'Filho de '+genome.parents.join(' e ')+'.':'Genoma gerado de forma determinística pela seed.')
  $('dna-code').textContent=JSON.stringify({id:genome.id,parents:genome.parents||[],ancestry:genome.ancestry,skinAlleles:genome.skin.mel,eyeAlleles:genome.eye.dark,hairAlleles:genome.hair.eu,redHairAlleles:genome.hair.red,textureAlleles:genome.hair.tex,body:genome.body,face:genome.z},null,2)
  for(const el of $('family').children)el.classList.toggle('selected',el.dataset.id===genome.id)
 }
 function schedule(){cancelAnimationFrame(repaint);repaint=requestAnimationFrame(render)}
 function clear(el){if(observer)for(const c of el.querySelectorAll('canvas'))observer.unobserve(c);el.replaceChildren()}
 function card(parent,g,age,title,note,onClick,o={}){
  const b=document.createElement('button');b.type='button';b.className='card';b.dataset.id=g.id;b.setAttribute('aria-label',title+(note?', '+note:''))
  const canvas=document.createElement('canvas');canvas.width=240;canvas.height=300;canvas.setAttribute('aria-hidden','true')
  const a=document.createElement('span');a.className='card-name';a.textContent=title;const n=document.createElement('span');n.className='card-note';n.textContent=note
  b.append(canvas,a);if(note)b.append(n);b.addEventListener('click',onClick);parent.append(b)
  const opts={age,glasses:null,...o};if(observer){canvas._paint={g,o:opts};observer.observe(canvas)}else R.render(canvas,g,{...opts,res:.6})
  return b
 }
 function stop(){playing=false;$('play').textContent='Ver uma vida inteira'}
 function choose(g,age){stop();genome=g;state.age=age;state.fat=-1;state.muscle=-1;state.hair='';state.beard='';state.ancestry='';sync();render();renderLife();renderCatalog();document.querySelector('.studio').scrollIntoView({behavior:'smooth'})}
 function makeFamily(){const pair=C.makeGenome(genome.id+'-par',{sex:genome.sex==='F'?'M':'F'});family=[{g:genome.sex==='F'?genome:pair,age:38,title:'Mãe'},{g:genome.sex==='M'?genome:pair,age:40,title:'Pai'}];familySeed=0;children()}
 function children(){family=family.slice(0,2);for(let i=0;i<4;i++){const g=C.childGenome(family[0].g,family[1].g,`familia-${C.hash32(family[0].g.id+':'+family[1].g.id).toString(36)}-${familySeed}-${i}`);family.push({g,age:[4,9,16,22][i],title:g.sex==='F'?'Filha '+(i+1):'Filho '+(i+1)})}renderFamily()}
 function renderFamily(){
  clear($('family'));for(const p of family)card($('family'),p.g,p.age,p.title,p.age+' anos',()=>choose(p.g,p.age))
  $('inheritance').replaceChildren();for(const [name,value]of [['Mãe',origin(family[0].g)],['Pai',origin(family[1].g)],['Herança','Alelos de cada pai + variação de traços']]){const item=document.createElement('span'),b=document.createElement('b');b.textContent=name+': ';item.append(b,document.createTextNode(value));$('inheritance').append(item)}for(const el of $('family').children)el.classList.toggle('selected',el.dataset.id===genome.id)
 }
 function renderLife(){clear($('life'));for(const age of [0,3,8,15,25,35,50,65,85,110])card($('life'),genome,age,age+' anos','',()=>{stop();state.age=age;sync();render();document.querySelector('.studio').scrollIntoView({behavior:'smooth'})})}
 function category(s){return s.tie?'tied':['afro','boxbraids','cornrows','locs','twists'].includes(s.special)?'textured':(s.side||s.len)<.3?'short':(s.side||s.len)<.95?'medium':'long'}
 function renderCatalog(){
  clear($('catalog'));const query=$('search').value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase(),cat=$('category').value
  const styles=(tab==='hair'?C.HAIR_STYLES:C.BEARD_STYLES).filter(s=>(tab!=='hair'||cat==='all'||category(s)===cat)&&s.name.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().includes(query)),pages=Math.max(1,Math.ceil(styles.length/pageSize));page=Math.min(page,pages-1)
  $('catalog-result').textContent=styles.length+' estilos';$('page-count').textContent=(page+1)+' / '+pages;$('previous').disabled=page===0;$('next').disabled=page===pages-1;$('category').disabled=tab!=='hair';$('catalog').setAttribute('aria-labelledby',tab==='hair'?'hair-tab':'beard-tab')
  if(!styles.length){const p=document.createElement('p');p.className='catalog-empty';p.textContent='Nenhum estilo encontrado. Tente outro nome.';$('catalog').append(p)}
  const g=tab==='beard'&&genome.sex==='F'?C.makeGenome(genome.id+'-catalogo',{sex:'M'}):genome
  for(const s of styles.slice(page*pageSize,(page+1)*pageSize)){const tile=card($('catalog'),g,Math.max(25,state.age),s.name,'',()=>{
   stop();if(tab==='beard'&&(genome.sex==='F'||state.age<16))return
   if(tab==='hair')state.hair=s.id;else state.beard=s.id
   sync();render();document.querySelector('.studio').scrollIntoView({behavior:'smooth'})
  },tab==='hair'?{hair:s.id,beard:'nenhuma'}:{beard:s.id,hair:'social-curto'});tile.disabled=tab==='beard'&&(genome.sex==='F'||state.age<16)}
 }
 function renderCrowd(){clear($('crowd'));for(let i=0;i<16;i++){const g=C.makeGenome('cidade-'+counter+'-'+i),r=C.makeRng(C.hash32(g.id+':age')),age=Math.floor(r()*90)+5;card($('crowd'),g,age,(g.sex==='F'?'Mulher':'Homem')+', '+age,texture(g),()=>{choose(g,age);makeFamily()})}}
 function refresh(){sync();render();renderLife();renderCatalog()}
 for(const id of ['age','fat','muscle'])$(id).addEventListener('input',e=>{stop();state[id]=+e.target.value;schedule()})
 for(const id of ['hair','beard','glasses','outfit','pose','expression'])$(id).addEventListener('change',e=>{state[id]=e.target.value;render()})
 $('sex').addEventListener('change',e=>{stop();genome=C.makeGenome(genome.id,{sex:e.target.value,ancestry:state.ancestry||undefined});state.hair='';state.beard='';refresh();makeFamily()})
 $('ancestry').addEventListener('change',e=>{stop();state.ancestry=e.target.value;genome=C.makeGenome(genome.id,{sex:genome.sex,ancestry:state.ancestry||undefined});refresh();makeFamily()})
 $('new-person').addEventListener('click',()=>{stop();genome=C.makeGenome('pessoa-'+Date.now().toString(36)+'-'+counter++,{ancestry:state.ancestry||undefined});state.age=30;state.hair='';state.beard='';state.fat=-1;state.muscle=-1;refresh();makeFamily()})
 $('use-parent').addEventListener('click',()=>{family[genome.sex==='F'?0:1]={g:genome,age:Math.max(25,state.age),title:genome.sex==='F'?'Mãe':'Pai'};familySeed++;children();$('family').scrollIntoView({behavior:'smooth'})})
 $('new-children').addEventListener('click',()=>{familySeed++;children()})
 for(const kind of ['hair','beard'])$(kind+'-tab').addEventListener('click',()=>{tab=kind;page=0;$('search').value='';for(const k of ['hair','beard'])$(k+'-tab').setAttribute('aria-selected',String(k===kind));renderCatalog()})
 for(const id of ['search','category'])$(id).addEventListener(id==='search'?'input':'change',()=>{page=0;renderCatalog()})
 $('previous').addEventListener('click',()=>{page--;renderCatalog()});$('next').addEventListener('click',()=>{page++;renderCatalog()});$('new-crowd').addEventListener('click',()=>{counter++;renderCrowd()})
 $('apply-seed').addEventListener('click',()=>{const seed=$('seed').value.trim();if(!seed){$('file-status').textContent='Digite uma seed para gerar a pessoa.';return}stop();genome=C.makeGenome(seed,{sex:genome.sex,ancestry:state.ancestry||undefined});state.hair='';state.beard='';refresh();makeFamily()})
 let playback=0
 $('play').addEventListener('click',async()=>{if(playing){stop();return}const token=++playback;playing=true;$('play').textContent='Parar passagem do tempo';for(let a=0;a<=110&&playing&&token===playback;a++){state.age=a;$('age').value=a;render();await new Promise(r=>setTimeout(r,110))}if(token===playback)stop()})
 function download(text,type,name){const url=URL.createObjectURL(new Blob([text],{type})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}
 $('save-character').addEventListener('click',()=>{download(S.encode(genome,options()),'application/json','paralelo-personagem.json');$('file-status').textContent='Personagem exportado com genoma, idade e escolhas de estilo.'})
 $('save-svg').addEventListener('click',()=>{download(R.build(genome,{...options(),view:'body'}).svg,'image/svg+xml','paralelo-personagem.svg');$('file-status').textContent='Corpo inteiro exportado como vetor editável.'})
 $('load-character').addEventListener('click',()=>$('character-file').click())
 $('character-file').addEventListener('change',async e=>{try{const file=e.target.files[0];if(!file)return;if(file.size>1000000)throw Error('Arquivo muito grande.');const saved=S.decode(await file.text());stop();genome=saved.genome;const v=saved.view;Object.assign(state,{age:v.age,fat:v.fat==null?-1:Math.round(v.fat*100),muscle:v.muscle==null?-1:Math.round(v.muscle*100),hair:v.hair||'',beard:v.beard||'',glasses:v.glasses===null?'none':v.glasses||'auto',outfit:v.outfit,pose:v.pose,expression:v.expression,ancestry:''});refresh();makeFamily();$('file-status').textContent='Personagem restaurado com o mesmo genoma.'}catch(err){$('file-status').textContent='Não foi possível abrir: '+err.message}e.target.value=''})
 refresh();makeFamily();renderCrowd()
})()
