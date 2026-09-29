// Hand-shaped vector clothing and anatomy. Shared recipes for portrait and body.
;(function(root){
 'use strict'
 const C=root.FaceCore,{clamp,lerp,smooth}=C
 const OUTFITS={
  casual:{name:'Camiseta e jeans',sleeve:.30,neck:'round',lower:'jeans'},
  polo:{name:'Polo e chino',sleeve:.30,neck:'polo',lower:'chino'},
  formal:{name:'Camisa e gravata',sleeve:1,neck:'collar',lower:'chino'},
  shirt:{name:'Camisa social aberta',sleeve:1,neck:'collar',lower:'jeans'},
  linen:{name:'Camisa de linho',sleeve:.72,neck:'collar',lower:'chino',ease:1.12},
  sport:{name:'Conjunto esportivo',sleeve:.26,neck:'round',lower:'sport'},
  sweatshirt:{name:'Moletom',sleeve:1,neck:'round',lower:'jeans',ease:1.08},
  knit:{name:'Suéter de tricô',sleeve:1,neck:'round',lower:'chino'},
  jacket:{name:'Jaqueta e camiseta',sleeve:1,neck:'open',lower:'jeans',ease:1.08},
  cardigan:{name:'Cardigã',sleeve:1,neck:'open',lower:'chino',ease:1.06},
  blazer:{name:'Blazer e calça',sleeve:1,neck:'lapel',lower:'chino',ease:1.04},
  blouse:{name:'Blusa com gola V',sleeve:.26,neck:'v',lower:'jeans'},
  blouse34:{name:'Blusa de manga ¾',sleeve:.72,neck:'boat',lower:'chino'},
  tank:{name:'Regata e calça',sleeve:0,neck:'tank',lower:'jeans'},
  shorts:{name:'Camiseta e bermuda',sleeve:.30,neck:'round',lower:'shorts'},
  skirt:{name:'Blusa e saia',sleeve:.25,neck:'boat',lower:'skirt'},
  dress:{name:'Vestido acinturado',sleeve:.23,neck:'v',lower:'dress'},
  dresslong:{name:'Vestido midi',sleeve:0,neck:'tank',lower:'dresslong'},
  tunic:{name:'Túnica e calça',sleeve:.72,neck:'v',lower:'chino',ease:1.08,long:1},
 }
 function recipe(id){return OUTFITS[id]||OUTFITS.casual}
 function neckline(s,c,x,y,w,scale,o,ink,n){
  const line=(d,col=c.clothShadow,sw=2)=>s.path(d,'none',col,sw*scale)
  if(o.neck==='v'){s.path(`M${n(x-w)} ${n(y-1*scale)} Q${x} ${n(y+10*scale)} ${n(x+w)} ${n(y-1*scale)} L${x} ${n(y+29*scale)} Z`,c.skin,null);line(`M${n(x-w)} ${n(y)} Q${n(x-w*.8)} ${n(y+12*scale)} ${x} ${n(y+29*scale)} Q${n(x+w*.8)} ${n(y+12*scale)} ${n(x+w)} ${n(y)}`,c.clothShadow,3)}
  else if(o.neck==='boat')line(`M${n(x-w*1.35)} ${n(y+5*scale)} Q${x} ${n(y+20*scale)} ${n(x+w*1.35)} ${n(y+5*scale)}`,c.clothShadow,4)
  else if(o.neck==='tank'){s.path(`M${n(x-w)} ${n(y)} Q${x} ${n(y+10*scale)} ${n(x+w)} ${n(y)} Q${n(x+w)} ${n(y+36*scale)} ${x} ${n(y+36*scale)} Q${n(x-w)} ${n(y+36*scale)} ${n(x-w)} ${n(y)} Z`,c.skin,null);line(`M${n(x-w)} ${n(y)} Q${n(x-w)} ${n(y+36*scale)} ${x} ${n(y+36*scale)} Q${n(x+w)} ${n(y+36*scale)} ${n(x+w)} ${n(y)}`,c.clothShadow,3)}
  else if(['collar','polo'].includes(o.neck)){
   s.path(`M${n(x-w-5*scale)} ${n(y-3*scale)} L${x} ${n(y+22*scale)} L${n(x-16*scale)} ${n(y+34*scale)} L${n(x-w-13*scale)} ${n(y+9*scale)} Z`,o.neck==='collar'?'#e1ddce':c.shirt,ink,1.1*scale)
   s.path(`M${n(x+w+5*scale)} ${n(y-3*scale)} L${x} ${n(y+22*scale)} L${n(x+16*scale)} ${n(y+34*scale)} L${n(x+w+13*scale)} ${n(y+9*scale)} Z`,o.neck==='collar'?'#e1ddce':c.shirt,ink,1.1*scale)
   line(`M${x} ${n(y+23*scale)} v${n(40*scale)}`,c.clothShadow,1.4)
   s.oval(x,y+39*scale,1.5*scale,1.5*scale,'#ddd7c7')
  }else if(!['open','lapel'].includes(o.neck))line(`M${n(x-w)} ${n(y+1*scale)} Q${x} ${n(y+23*scale)} ${n(x+w)} ${n(y+1*scale)}`,c.clothShadow,5)
 }
 function portrait(s,g,age,fat,c,opts,H){
  const {geometry,hairBack,face,ink,n}=H,q=geometry(g,age,fat),o=recipe(opts.outfit)
  const b=C.bodyLayout(g,{...opts,age,fat}),width=(lerp(118,143,b.adult)+(g.sex==='M'?12*b.adult:0)+fat*22+b.muscle*12)*(o.ease||1)
  const neck=lerp(27,24,b.adult)+fat*10+b.muscle*3,neckBottom=q.chin+lerp(15,32,b.adult),shoulderY=neckBottom+8
  hairBack(s,g,q,c,C.hairForAge(g,age,opts.hair))
  s.path(`M${n(200-neck)} ${n(q.chin-12)} H${n(200+neck)} L${n(200+neck+2)} ${n(neckBottom+9)} Q200 ${n(neckBottom+28)} ${n(200-neck-2)} ${n(neckBottom+9)} Z`,c.skin,ink,1.6)
  s.path(`M${n(200-neck)} ${n(q.chin-6)} Q200 ${n(q.chin+14)} ${n(200+neck)} ${n(q.chin-6)} V${n(q.chin+9)} Q200 ${n(q.chin+23)} ${n(200-neck)} ${n(q.chin+9)} Z`,c.shadow,null)
  const outline=`M${n(200-neck-5)} ${n(neckBottom)} Q${n(200-width*.69)} ${n(shoulderY-5)} ${n(200-width)} ${n(shoulderY+22)} Q${n(200-width-13)} ${n(shoulderY+45)} ${n(200-width-15)} 510 H${n(200+width+15)} Q${n(200+width+13)} ${n(shoulderY+45)} ${n(200+width)} ${n(shoulderY+22)} Q${n(200+width*.69)} ${n(shoulderY-5)} ${n(200+neck+5)} ${n(neckBottom)} Q200 ${n(neckBottom+23)} ${n(200-neck-5)} ${n(neckBottom)} Z`
  s.path(outline,c.shirt,ink,1.8)
  s.path(`M${n(200+width*.77)} ${n(shoulderY+22)} Q${n(200+width*.7)} 460 ${n(200+width*.74)} 510 H${n(200+width+15)} Q${n(200+width)} ${n(shoulderY+54)} ${n(200+width*.77)} ${n(shoulderY+22)} Z`,c.clothShadow,null)
  if(o.neck==='tank')for(const dir of [-1,1])s.path(`M${n(200+dir*width*.58)} ${n(shoulderY+2)} Q${n(200+dir*width*.68)} ${n(shoulderY+43)} ${n(200+dir*width)} ${n(shoulderY+70)} L${n(200+dir*(width+15))} 510 H${n(200+dir*width*.65)} Z`,c.skin,ink,1.4)
  neckline(s,c,200,neckBottom,neck+5,1.05,o,ink,n)
  if(['open','lapel'].includes(o.neck)){
   s.path(`M${n(200-neck)} ${n(neckBottom)} L184 ${n(neckBottom+37)} L180 510 H220 L216 ${n(neckBottom+37)} L${n(200+neck)} ${n(neckBottom)} Q200 ${n(neckBottom+20)} ${n(200-neck)} ${n(neckBottom)} Z`,'#e5ddcd',null)
   for(const dir of [-1,1]){
    s.path(`M${n(200+dir*(neck+4))} ${n(neckBottom)} L${n(200+dir*40)} ${n(neckBottom+39)} L${n(200+dir*24)} ${n(neckBottom+55)}`, 'none',c.clothShadow,3)
    s.path(`M${n(200+dir*55)} 456 h${dir*36} v25 h${-dir*36}`, 'none',c.clothShadow,1.4)
   }
   for(let yy=neckBottom+70;yy<500;yy+=21)s.oval(225,yy,1.8,1.8,'#d6d0b8',ink,.8)
  }
  if(opts.outfit==='formal')s.path(`M200 ${n(neckBottom+22)} l-8 11 8 66 8 -66 Z`,'#435b54',null)
  if(opts.outfit==='sport')for(const dir of [-1,1])s.path(`M${n(200+dir*width*.76)} ${n(shoulderY+16)} L${n(200+dir*width*.82)} 510`,'none','#dce1c3',5)
  if(opts.outfit==='knit')for(let yy=425;yy<500;yy+=11)s.path(`M130 ${yy} h140`,'none',c.clothShadow,.7,.32)
  if(opts.outfit==='cardigan')for(const dir of [-1,1])for(let yy=431;yy<501;yy+=10)s.path(`M${n(200+dir*48)} ${yy} h${dir*48}`, 'none',c.clothShadow,.7,.25)
  if(opts.outfit==='sweatshirt')s.path(`M176 ${n(neckBottom+14)} l4 42 M224 ${n(neckBottom+14)} l-4 42`, 'none','#d9d5c1',2)
  for(const dir of [-1,1])s.path(`M${n(200+dir*width*.75)} ${n(shoulderY+35)} q${-dir*11} 8 ${-dir*15} 20`, 'none',c.clothShadow,1.3)
  return face(s,g,age,fat,c,{...opts,skipHairBack:true})
 }
 root.VectorWardrobe={OUTFITS,recipe,neckline,portrait,body:root.VectorBody.render}
})(typeof window!=='undefined'?window:globalThis)
