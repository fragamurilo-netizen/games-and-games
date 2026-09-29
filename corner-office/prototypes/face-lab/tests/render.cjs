const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
// Run the real drawing functions on a CPU Canvas; no DOM stubs for rendering primitives.
const {createCanvas,Path2D} = require(process.env.CANVAS_MODULE_PATH || '@napi-rs/canvas');
const lab = require('node:path').resolve(__dirname, '..');
const source = fs.readFileSync(lab+'/identity.js','utf8');
const context = vm.createContext({console,Path2D,window:{devicePixelRatio:1},document:{createElement:()=>createCanvas(1,1)}});
vm.runInContext(fs.readFileSync(lab+'/studio.js','utf8'),context);
vm.runInContext(source+'\nthis.api={CANON,STYLES,POSES,HAIR_STYLES,SKIN,genFace,drawFigure,drawFace,renderPortrait,background};',context);
const A=context.api;
const clone=x=>JSON.parse(JSON.stringify(x));
const hash=cv=>createHash('sha256').update(cv.toBuffer('image/png')).digest('hex');
function render(f,style='studio',pose='oficial',w=240,h=480,figure=true,bg=true){
 const cv=createCanvas(w,h),ctx=cv.getContext('2d');
 if(bg)A.background(ctx,w,h,style,{figure});
 if(figure)A.drawFigure(ctx,w,h,f,A.STYLES[style],{pose}); else A.drawFace(ctx,w,h,f,A.STYLES[style],{});
 return cv;
}
function bounds(cv){const {data}=cv.getContext('2d').getImageData(0,0,cv.width,cv.height);let left=cv.width,right=-1,top=cv.height,bottom=-1;
 for(let y=0;y<cv.height;y++)for(let x=0;x<cv.width;x++)if(data[(y*cv.width+x)*4+3]>30){left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y)}return {left,right,top,bottom};}
const start=Date.now();let count=0;
const original=clone(A.CANON[0]),serialized=JSON.stringify(original);
assert.equal(hash(render(original)),hash(render(original)),'render must be deterministic');
assert.equal(JSON.stringify(original),serialized,'render must not mutate appearance');
for(const property of ['muscle','fat','height','shoulders','reach','legs','hair','waist','hips','legMass','chest']){
 const low=clone(original),high=clone(original);low.body[property]=0;high.body[property]=1;
 assert.notEqual(hash(render(low)),hash(render(high)),property+' must change output');count+=2;
}
for(const sex of ['m','f'])for(const pose of Object.keys(A.POSES))for(const skin of ['t01','t08','t15'])for(const heavy of [false,true]){
 const f=clone(original);f.sex=sex;f.skin=skin;f.build=heavy?1:0;f.body={muscle:heavy?.8:.4,fat:heavy?.65:.08,height:heavy?1:0,shoulders:heavy?1:0,reach:heavy?1:0,legs:heavy?1:0,hair:0};
 if(sex==='f'){f.hair.style='coque';f.beard.style='nenhuma'}
 const cv=render(f,'studio',pose,150,300,true,false),b=bounds(cv);
 assert.ok(b.left>0&&b.right<cv.width-1&&b.top>0&&b.bottom<cv.height-1,JSON.stringify({sex,pose,skin,heavy,b}));count++;
}
for(const focus of ['hands','feet']){const cv=createCanvas(240,276);A.drawFigure(cv.getContext('2d'),240,276,original,A.STYLES.studio,{pose:'oficial',focus});assert.ok(bounds(cv).right>bounds(cv).left);count++;}
for(const style of Object.keys(A.STYLES))for(const f of A.CANON){render(f,style,'guarda',100,200);count++}
for(const hair of Object.keys(A.HAIR_STYLES)){const f=clone(original);f.hair.style=hair;render(f,'studio','oficial',150,172,false);count++}
console.log(JSON.stringify({passed:true,renders:count,seconds:(Date.now()-start)/1000}));
