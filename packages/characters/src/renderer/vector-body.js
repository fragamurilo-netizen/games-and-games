// Anatomical drawing in connected layers: hair -> legs -> arms -> torso -> head.
// Rounded quadratic contours remain inside their control polygon, avoiding joint bulges.
;(function(root){
 'use strict'
 const C=root.FaceCore,{lerp,clamp}=C
 function rounded(points,n){
  const mid=(a,b)=>[(a[0]+b[0])/2,(a[1]+b[1])/2],last=mid(points.at(-1),points[0])
  let d=`M${n(last[0])} ${n(last[1])}`
  for(let i=0;i<points.length;i++){const p=points[i],m=mid(p,points[(i+1)%points.length]);d+=` Q${n(p[0])} ${n(p[1])} ${n(m[0])} ${n(m[1])}`}
  return d+' Z'
 }
 function ribbon(points,radii,n){
  const sides=[-1,1].map(side=>points.map((p,i)=>{
   const a=points[Math.max(0,i-1)],b=points[Math.min(points.length-1,i+1)],len=Math.hypot(b[0]-a[0],b[1]-a[1])||1
   return [p[0]+side*(b[1]-a[1])/len*radii[i],p[1]-side*(b[0]-a[0])/len*radii[i]]
  }))
  return rounded([...sides[0],...sides[1].reverse()],n)
 }
 function render(s,g,age,fat,c,opts,H){
  const {geometry,face,hairBack,n,ink}=H,o=root.VectorWardrobe.recipe(opts.outfit),b=C.bodyLayout(g,{...opts,age,fat}),traits=C.bodyTraits(g),q=geometry(g,age,fat)
  const adult=b.adult,F=(g.sex==='F'?1:0)*adult,M=(g.sex==='M'?1:0)*adult
  const h=770*clamp(b.height/180,.24,1.07),ground=854,top=ground-h,cx=260,k=h/770
  const headH=h*lerp(.295,.151,adult),headTop=top+h*.023,headScale=headH/(q.chin-q.top),headBottom=headTop+headH
  const sh=h*(lerp(.095,.112+M*.012,adult)+(traits.shoulders-.5)*.012+fat*.011+b.muscle*.008)
  const chest=h*(lerp(.097,.102+M*.012,adult)+fat*.024+b.muscle*.008)
  const waist=h*(lerp(.096,.078+M*.014,adult)+fat*.040+(traits.waist-.5)*.010+b.muscle*.004)
  const hips=h*(lerp(.095,.108-M*.013,adult)+fat*.023+(traits.hips-.5)*.012)
  const neckW=h*(lerp(.029,.022+M*.003,adult)+fat*.007+b.muscle*.0015)
  const sy=headBottom+h*.049,ny=headBottom-h*.014,chestY=sy+h*.085,waistY=top+h*lerp(.45,.395,adult)
  const crotch=top+h*(lerp(.625,.527,adult)+(traits.legLength-.5)*-.035),hipY=crotch-h*.055,pantsY=hipY-h*.042
  const hem=hipY+h*(o.long?.067:.019),knee=crotch+(ground-crotch)*.49,calfY=knee+(ground-knee)*.42,ankleY=ground-h*.026
  const relaxed=opts.pose!=='neutral',tx=cx-200*headScale,ty=headTop-q.top*headScale
  const thigh=h*(.032+F*.002+fat*.021+b.muscle*.008),kneeR=h*(.024+fat*.010),calf=h*(.022+fat*.010+b.muscle*.004),ankleR=h*(.011+fat*.004)
  const armR=h*(.018+M*.002+fat*.012+b.muscle*.006),forearmR=h*(.0145+fat*.009+b.muscle*.003),wristR=h*(.009+fat*.0035)
  const wristY=crotch+h*(.049+(traits.armLength-.5)*.035),elbowY=lerp(sy+h*.024,wristY,.52),palm=h*(.011+fat*.0025)
  const bare=['skirt','dress','dresslong','shorts'].includes(o.lower),pants=o.lower==='chino'?'#807765':c.pants,pantsShadow=o.lower==='chino'?'#655d50':c.pantShadow
  const outline=1.65*k,stitch=1.2*k
  s.oval(cx,ground+5*k,hips+32*k,8*k,'#b3b8a6',null,1,.5)
  s.group(tx,ty,headScale);hairBack(s,g,q,c,C.hairForAge(g,age,opts.hair));s.end()
  const legs=[]
  for(const d of [-1,1]){
   const hipX=cx+d*hips*.53,kneeX=cx+d*(hips*.49+(relaxed?h*.006:0)),ankleX=cx+d*(hips*.50+(relaxed?h*.009:0))
   const points=[[hipX,hipY],[hipX+d*2*k,crotch+h*.13],[kneeX,knee],[ankleX+d*2*k,calfY],[ankleX,ankleY]]
   legs.push({d,points,radii:[thigh,thigh*.90,kneeR,calf,ankleR],hipX,kneeX,ankleX})
   if(bare)s.path(ribbon(points,[thigh,thigh*.90,kneeR,calf,ankleR],n),c.skin,ink,outline)
   if(bare)s.path(`M${n(hipX+d*thigh*.65)} ${n(crotch+28*k)} Q${n(kneeX+d*kneeR*.6)} ${n(knee)} ${n(ankleX+d*ankleR*.7)} ${n(ankleY-7*k)}`, 'none',c.shadow,Math.max(stitch,thigh*.10),.62)
   const footW=h*.028,toeX=ankleX+d*h*.018
   s.path(`M${n(ankleX-ankleR)} ${n(ankleY-3*k)} Q${n(ankleX)} ${n(ankleY-7*k)} ${n(ankleX+ankleR)} ${n(ankleY-3*k)} Q${n(toeX+footW)} ${n(ground-16*k)} ${n(toeX+footW)} ${n(ground+1*k)} Q${n(toeX)} ${n(ground+7*k)} ${n(toeX-footW)} ${n(ground+1*k)} Q${n(toeX-footW)} ${n(ground-9*k)} ${n(ankleX-ankleR)} ${n(ankleY-3*k)} Z`,c.shoe,ink,outline)
   s.path(`M${n(toeX-footW*.85)} ${n(ground+1*k)} Q${n(toeX)} ${n(ground+4*k)} ${n(toeX+footW*.85)} ${n(ground+1*k)}`, 'none',c.shoeHi,2*k)
   for(let j=0;j<2;j++)s.path(`M${n(ankleX-6*k)} ${n(ankleY+5*k+j*4*k)} h${n(12*k)}`, 'none',c.shoeHi,1.2*k)
  }
  if(!['dress','dresslong','skirt'].includes(o.lower)){
   if(o.lower==='shorts'){
    const end=crotch+h*.145
    s.path(`M${n(cx-hips)} ${n(pantsY)} Q${cx} ${n(pantsY-5*k)} ${n(cx+hips)} ${n(pantsY)} Q${n(cx+hips+2*k)} ${n(hipY+23*k)} ${n(cx+hips*.92)} ${n(end)} L${n(cx+hips*.25)} ${n(end)} Q${n(cx+hips*.16)} ${n(crotch+23*k)} ${cx} ${n(crotch+17*k)} Q${n(cx-hips*.16)} ${n(crotch+23*k)} ${n(cx-hips*.25)} ${n(end)} L${n(cx-hips*.92)} ${n(end)} Q${n(cx-hips-2*k)} ${n(hipY+23*k)} ${n(cx-hips)} ${n(pantsY)} Z`,pants,ink,outline)
   }else{
    // Both trouser legs and the pelvis share one exterior outline. No thigh seam.
    const left=legs[0],right=legs[1],outer=l=>l.points.map((p,i)=>[p[0]+l.d*l.radii[i],p[1]]),inner=l=>l.points.map((p,i)=>[p[0]-l.d*l.radii[i],p[1]])
    const contour=[[cx-hips,pantsY],...outer(left),...inner(left).slice(1).reverse(),[cx,crotch+17*k],...inner(right).slice(1),...outer(right).reverse(),[cx+hips,pantsY]]
    s.path(rounded(contour,n),pants,ink,outline)
    for(const l of legs)s.path(`M${n(l.hipX+l.d*thigh*.7)} ${n(crotch+46*k)} Q${n(l.kneeX+l.d*kneeR*.66)} ${n(knee)} ${n(l.ankleX+l.d*ankleR*.6)} ${n(ankleY-12*k)}`, 'none',pantsShadow,Math.max(stitch,thigh*.10),.58)
   }
   for(const d of [-1,1])s.path(`M${n(cx+d*hips*.75)} ${n(pantsY+9*k)} q${n(-d*11*k)} ${n(22*k)} ${n(-d*23*k)} ${n(28*k)}`, 'none',pantsShadow,stitch)
   s.path(`M${cx} ${n(pantsY+8*k)} v${n(43*k)}`, 'none',pantsShadow,stitch)
  }
  // One set of bones controls both skin and sleeves, so cuffs meet the wrist.
  for(const d of [-1,1]){
   const shoulder=[cx+d*(sh-armR*.90),sy+h*.035],elbow=[cx+d*(sh-armR*.08+h*(relaxed&&d<0?.005:0)),elbowY],wrist=[cx+d*(hips+h*(relaxed?(d<0?.023:.015):.019)),wristY]
   const points=[shoulder,elbow,wrist],radii=[armR,forearmR,wristR]
   const t=o.sleeve||0,split=t<.55?lerp(0,.62,t/.55):lerp(.62,1,(t-.55)/.45)
   let cuff,clothesPoints,clothesR,skinPoints,skinR
   if(split<.52){const u=split/.52;cuff=[lerp(shoulder[0],elbow[0],u),lerp(shoulder[1],elbow[1],u)];const r=lerp(armR,forearmR,u);clothesPoints=[shoulder,cuff];clothesR=[armR*1.13,r*1.08];skinPoints=[cuff,elbow,wrist];skinR=[r,forearmR,wristR]}
   else{const u=(split-.52)/.48;cuff=[lerp(elbow[0],wrist[0],u),lerp(elbow[1],wrist[1],u)];const r=lerp(forearmR,wristR,u);clothesPoints=[shoulder,elbow,cuff];clothesR=[armR*1.13,forearmR*1.11,r*1.15];skinPoints=[cuff,wrist];skinR=[r,wristR]}
   if(t<.98)s.path(ribbon(t?skinPoints:points,t?skinR:radii,n),c.skin,ink,outline)
   const wx=wrist[0],wy=wrist[1]
   s.path(`M${n(wx-wristR)} ${n(wy-5*k)} Q${n(wx-palm*.95)} ${n(wy+4*k)} ${n(wx-palm*.87)} ${n(wy+17*k)} Q${n(wx-palm*.72)} ${n(wy+30*k)} ${n(wx+palm*.26)} ${n(wy+27*k)} Q${n(wx+palm*.88)} ${n(wy+27*k)} ${n(wx+palm*.78)} ${n(wy+13*k)} Q${n(wx+palm*1.25)} ${n(wy+12*k)} ${n(wx+palm*.98)} ${n(wy+5*k)} L${n(wx+wristR)} ${n(wy-5*k)} Z`,c.skin,ink,1.4*k)
   s.path(`M${n(wx+palm*.77)} ${n(wy+8*k)} q${n(-palm*.2)} ${n(7*k)} ${n(-palm*.48)} ${n(9*k)}`, 'none',c.shadow,stitch)
   for(let j=0;j<2;j++)s.path(`M${n(wx+(j-.4)*palm*.35)} ${n(wy+22*k)} v${n(4*k)}`, 'none',c.shadow,.7*k)
   if(t){s.path(ribbon(clothesPoints,clothesR,n),c.shirt,ink,outline);const r=clothesR.at(-1);s.path(`M${n(cuff[0]-r*.78)} ${n(cuff[1]-2*k)} Q${n(cuff[0])} ${n(cuff[1]+2*k)} ${n(cuff[0]+r*.78)} ${n(cuff[1]-2*k)}`, 'none',c.clothShadow,stitch)}
  }
  s.path(`M${n(cx-neckW)} ${n(ny)} H${n(cx+neckW)} L${n(cx+neckW)} ${n(sy+8*k)} Q${cx} ${n(sy+17*k)} ${n(cx-neckW)} ${n(sy+8*k)} Z`,c.skin,ink,1.4*k)
  s.path(`M${n(cx-neckW)} ${n(ny+2*k)} Q${cx} ${n(ny+15*k)} ${n(cx+neckW)} ${n(ny+2*k)} v${n(7*k)} Q${cx} ${n(ny+22*k)} ${n(cx-neckW)} ${n(ny+9*k)} Z`,c.shadow,null)
  const ease=o.ease||1,cw=chest*ease,ww=waist*ease,hw=hips*ease
  s.path(`M${n(cx-neckW-3*k)} ${n(sy-5*k)} C${n(cx-neckW-22*k)} ${n(sy)} ${n(cx-sh+15*k)} ${n(sy-1*k)} ${n(cx-sh)} ${n(sy+17*k)} Q${n(cx-sh-5*k)} ${n(sy+34*k)} ${n(cx-cw)} ${n(chestY)} C${n(cx-cw-4*k*F)} ${n(chestY+29*k)} ${n(cx-ww)} ${n(waistY-18*k)} ${n(cx-ww)} ${n(waistY)} C${n(cx-ww)} ${n(waistY+25*k)} ${n(cx-hw)} ${n(hipY-13*k)} ${n(cx-hw)} ${n(hem)} Q${cx} ${n(hem+8*k)} ${n(cx+hw)} ${n(hem)} C${n(cx+hw)} ${n(hipY-13*k)} ${n(cx+ww)} ${n(waistY+25*k)} ${n(cx+ww)} ${n(waistY)} C${n(cx+ww)} ${n(waistY-18*k)} ${n(cx+cw+4*k*F)} ${n(chestY+29*k)} ${n(cx+cw)} ${n(chestY)} Q${n(cx+sh+5*k)} ${n(sy+34*k)} ${n(cx+sh)} ${n(sy+17*k)} C${n(cx+sh-15*k)} ${n(sy-1*k)} ${n(cx+neckW+22*k)} ${n(sy)} ${n(cx+neckW+3*k)} ${n(sy-5*k)} Q${cx} ${n(sy+17*k)} ${n(cx-neckW-3*k)} ${n(sy-5*k)} Z`,c.shirt,ink,outline)
  s.path(`M${n(cx+cw*.83)} ${n(chestY+8*k)} Q${n(cx+ww*.85)} ${n(waistY)} ${n(cx+hw*.87)} ${n(hem+2*k)} L${n(cx+hw)} ${n(hem)} Q${n(cx+hw)} ${n(hipY)} ${n(cx+ww)} ${n(waistY)} Z`,c.clothShadow,null,1,.78)
  root.VectorWardrobe.neckline(s,c,cx,sy-5*k,neckW+3*k,k,o,ink,n)
  if(['open','lapel'].includes(o.neck)){
   s.path(`M${n(cx-neckW)} ${n(sy-4*k)} L${n(cx-13*k)} ${n(sy+33*k)} L${n(cx-16*k)} ${n(hem+3*k)} H${n(cx+16*k)} L${n(cx+13*k)} ${n(sy+33*k)} L${n(cx+neckW)} ${n(sy-4*k)} Q${cx} ${n(sy+13*k)} ${n(cx-neckW)} ${n(sy-4*k)} Z`,'#e5ddcd',null)
   for(const d of [-1,1]){s.path(`M${n(cx+d*(neckW+3*k))} ${n(sy-4*k)} l${n(d*13*k)} ${n(33*k)} ${n(-d*17*k)} ${n(18*k)}`, 'none',c.clothShadow,2.2*k);s.path(`M${n(cx+d*hw*.42)} ${n(hem-34*k)} h${n(d*hw*.33)} v${n(20*k)} h${n(-d*hw*.33)}`, 'none',c.clothShadow,stitch)}
   for(let yy=sy+67*k;yy<hem-10*k;yy+=26*k)s.oval(cx+20*k,yy,1.6*k,1.6*k,'#d8d1bb',ink,.6*k)
  }
  if(opts.outfit==='formal')s.path(`M${cx} ${n(sy+16*k)} l${n(-6*k)} ${n(11*k)} ${n(6*k)} ${n(53*k)} ${n(6*k)} ${n(-53*k)} Z`,'#435b54',null)
  if(['shirt','linen'].includes(opts.outfit)){s.path(`M${cx} ${n(sy+45*k)} V${n(hem-3*k)}`, 'none',c.clothShadow,stitch);for(let yy=sy+60*k;yy<hem-10*k;yy+=25*k)s.oval(cx,yy,1.3*k,1.3*k,'#ddd7c7')}
  if(opts.outfit==='knit')for(let yy=chestY+12*k;yy<hem-9*k;yy+=11*k)s.path(`M${n(cx-ww*.8)} ${n(yy)} h${n(ww*1.6)}`, 'none',c.clothShadow,.6*k,.32)
  if(opts.outfit==='sport')for(const d of [-1,1])s.path(`M${n(cx+d*sh*.73)} ${n(sy+19*k)} L${n(cx+d*hw*.76)} ${n(hem-6*k)}`, 'none','#dce1c3',3*k)
  if(['dress','dresslong','skirt'].includes(o.lower)){
   const end=o.lower==='dresslong'?knee+h*.088:knee-h*.037,sw=hips*(o.lower==='dresslong'?1.40:1.27),y=o.lower==='skirt'?pantsY:waistY+5*k,color=o.lower==='skirt'?'#9a7769':c.shirt,shadow=o.lower==='skirt'?'#805f54':c.clothShadow
   s.path(`M${n(cx-ww)} ${n(y)} C${n(cx-ww-3*k)} ${n(hipY)} ${n(cx-sw+8*k)} ${n(end-25*k)} ${n(cx-sw)} ${n(end)} Q${cx} ${n(end+12*k)} ${n(cx+sw)} ${n(end)} C${n(cx+sw-8*k)} ${n(end-25*k)} ${n(cx+ww+3*k)} ${n(hipY)} ${n(cx+ww)} ${n(y)} Z`,color,ink,outline)
   for(const d of [-1,1])s.path(`M${n(cx+d*ww*.72)} ${n(y+15*k)} Q${n(cx+d*hips*.8)} ${n(hipY+31*k)} ${n(cx+d*sw*.73)} ${n(end-5*k)}`, 'none',shadow,stitch)
   s.path(`M${n(cx-ww)} ${n(y)} Q${cx} ${n(y+5*k)} ${n(cx+ww)} ${n(y)}`, 'none',shadow,3.2*k)
  }else{s.path(`M${n(cx-hw*.88)} ${n(hem-2*k)} Q${cx} ${n(hem+3*k)} ${n(cx+hw*.88)} ${n(hem-2*k)}`, 'none',c.clothShadow,stitch)}
  for(const d of [-1,1])s.path(`M${n(cx+d*cw*.75)} ${n(chestY-7*k)} l${n(-d*9*k)} ${n(9*k)}`, 'none',c.clothShadow,stitch,.65)
  s.group(tx,ty,headScale);const info=face(s,g,age,fat,c,{...opts,skipHairBack:true});s.end();return info
 }
 root.VectorBody={render,ribbon}
})(typeof window!=='undefined'?window:globalThis)
