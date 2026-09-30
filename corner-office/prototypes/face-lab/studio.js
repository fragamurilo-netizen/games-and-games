/* Procedural studio materials. Game Design Bible §5, §16.
 * Geometry and identity stay seeded; lighting never changes appearance data.
 * No bitmaps, external renderer, or unseeded randomness in the drawing path.
 */
function studioGradient(ctx, color, x, y, radius, vertical = 0) {
  const g = ctx.createLinearGradient(x - radius, y - radius * vertical, x + radius, y + radius * vertical);
  const dark = lum(color) < .32;
  [[0, darken(color, .32)], [.18, lighten(color, dark ? .22 : .17)],
    [.4, lighten(color, dark ? .11 : .08)], [.66, color], [.9, darken(color, .4)],
    [1, mix(color, '#7a8996', .18)]].forEach(([p, c]) => g.addColorStop(p, c));
  return g;
}

// Elliptical falloff gives broad anatomical planes without outlined muscle tiles.
function studioSoft(ctx, x, y, rx, ry, color, alpha = .4, rotation = 0) {
  if (rx <= 0 || ry <= 0 || alpha <= 0) return;
  ctx.save();
  ctx.translate(x, y); ctx.rotate(rotation); ctx.scale(rx, ry);
  const c = h2r(color), g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1);
  g.addColorStop(0, `rgba(${c.join(',')},${clamp(alpha, 0, 1)})`);
  g.addColorStop(.45, `rgba(${c.join(',')},${clamp(alpha * .55, 0, 1)})`);
  g.addColorStop(1, `rgba(${c.join(',')},0)`);
  ctx.fillStyle = g; ctx.fillRect(-1, -1, 2, 2); ctx.restore();
}

function studioGrain(ctx, seed, x, y, w, h, unit, strength = 1) {
  if (unit < 60) return; // Detail budget follows projected size, including roster avatars.
  const r = rngOf(seed), count = Math.min(10000, Math.round(w * h / (unit * unit) * 820));
  ctx.save();
  for (let i = 0; i < count; i++) {
    const px = x + r() * w, py = y + r() * h, light = r() > .57;
    ctx.fillStyle = light ? '#fff0dd' : '#301c19';
    ctx.globalAlpha = (.018 + r() * .065) * strength;
    const radius = Math.max(.25, unit * (.001 + r() * .0017));
    ctx.beginPath(); ctx.ellipse(px, py, radius, radius * .7, 0, 0, Math.PI * 2); ctx.fill();
  }
  ctx.restore();
}

function studioHair(ctx, path, color, seed, S, ox, oy, beard = false, density = 1, kind = '') {
  if (S < 42) return;
  ctx.save(); path(); ctx.clip();
  const r=rngOf(seed+(beard?761:337));
  const stubble=kind==='stubble'||['maquina','raspado'].includes(kind);
  const curly=/cach|afro|black|twist/.test(kind),long=/long|ombro|rabo|tranc|braid|dread/.test(kind);
  const n=Math.round((S>90?7200:2800)*density),gray=kind==='grisalho';
  ctx.lineCap='round';
  for(let i=0;i<n;i++){
    const x=(r()-.5)*2.05,y=beard?.02+r()*1.4:-1.55+r()*(long?3.3:1.72);
    const l=stubble?.003+r()*.012:beard?.016+r()*.055:long?.08+r()*.25:.016+r()*.065;
    const lit=r()<.31,alpha=stubble?.2+r()*.45:.18+r()*.47;
    ctx.strokeStyle=lit?lighten(color,.12+r()*.14):darken(color,.3+r()*.4);
    ctx.globalAlpha=alpha;ctx.lineWidth=Math.max(.35,S*(stubble?.0023:.0028));
    const direction=beard?Math.sign(x)*l*.28:long?x*.045:l*.38*Math.sin(x*3.1);
    ctx.beginPath();ctx.moveTo(ox+x*S,oy+y*S);
    if(curly){const radius=(.006+r()*.013)*S;ctx.arc(ox+x*S+radius,oy+y*S,radius,r()*.6,Math.PI*1.6)}
    else ctx.bezierCurveTo(ox+(x+direction*.25)*S,oy+(y+l*.28)*S,ox+(x+direction*.7+.006)*S,oy+(y+l*.65)*S,ox+(x+direction)*S,oy+(y+l)*S);
    ctx.stroke();
  }
  ctx.restore();
}

function studioFacePlanes(ctx, S, ox, oy, skin, g, seed, age) {
  const p = (x, y, rx, ry, c, a, rot = 0) => studioSoft(ctx, ox + x * S, oy + y * S, rx * S, ry * S, c, a, rot);
  const light = lighten(skin, .4), dark = darken(skin, .68), warm = mix(skin, '#ad5342', .32);
  p(-.27, -.55, .48, .46, light, .4);
  p(g.hw * .94, -.14, .3, .87, dark, .65);
  p(-g.hw * .97, -.18, .17, .76, dark, .45);
  p(.25, .75, .5, .28, dark, .27);
  for (const s of [-1, 1]) {
    p(s * .31, -.015, .24, .16, dark, s > 0 ? .65 : .42);
    p(s * .44, .28, .23, .19, warm, .3);
    p(s * .54, .42, .18, .29, dark, .45, s * -.45);
    p(s * .46, .16, .23, .12, light, s < 0 ? .44 : .2, s * .25);
    p(s * .19, .47, .07, .18, dark, .19, s * -.3);
    p(s * .28, .12, .19, .085, dark, .14 + age * .1);
  }
  p(-.025, .12, .074, .35, light, .5);
  p(.115, .2, .065, .27, dark, .4);
  p(-.015, .355, .095, .06, light, .42);
  p(0, .475, .075, .07, dark, .32);
  p(-.05, .79, .19, .10, light, .25);
  studioGrain(ctx, seed * 919, ox - g.hw * S, oy - 1.1 * S, g.hw * 2 * S, 2.2 * S, S);
}

function studioTorso(ctx, S, ox, oy, skin, sh, waist, fat, muscle, fem, seed) {
  const p = (x, y, rx, ry, c, a, rot = 0) => studioSoft(ctx, ox + x * S, oy + y * S, rx * S, ry * S, c, a, rot);
  const light = lighten(skin, .4), dark = darken(skin, .7), def = clamp(muscle * 1.15 - fat * 1.55, 0, 1);
  p(0, 1.27, .45, .22, dark, .45);
  p(-sh * .67, 1.63, .44, .32, light, .46, -.2);
  p(sh * .84, 2.9, .38, 1.3, dark, .48);
  for (const s of [-1, 1]) {
    p(s * .36, 1.52, .33, .085, dark, .28, s * .08);
    p(s * sh * .49, 2.01, sh * .48, .40 + fat * .12, light, (s < 0 ? .49 : .23) * (fem ? .65 : 1), s * .06);
    p(s * sh * .5, 2.52, sh * .41, .105 + fat * .08, dark, .22 + .25 * def, s * -.08);
    p(s * (sh - .28), 2.3, .17, .48, dark, .25 + .2 * def, s * -.2);
    p(s * (waist - .08), 3.43, .22, .76, dark, .2 + .18 * def, s * -.12);
    p(s * .55, 3.35, .2, .55, light, .12 * def, s * -.25);
    for (let i = 0; i < 3; i++) {
      const y = 2.84 + i * .33;
      p(s * .19, y, .21, .2, light, .28 * def);
      p(s * .18, y + .15, .21, .055, dark, .22 * def);
      p(s * (sh - .44 - i * .085), 2.63 + i * .18, .14, .05, dark, .17 * def, s * -.55);
    }
  }
  p(.015, 2.15, .055, .44, dark, .34 * def);
  p(.015, 3.25, .043, .65, dark, .27 * def);
  p(-.16, 3.55, .52 + fat * .25, .64, light, .14 + .2 * fat);
  p(0, 4.14, waist * .87, .23, dark, .3);
  studioGrain(ctx, seed * 103, ox - sh * S, oy + S, sh * 2 * S, 3.5 * S, S, .8);
}

function studioBackdrop(ctx, W, H, figure) {
  const g = ctx.createRadialGradient(W * .38, H * .3, 0, W * .5, H * .4, H * .8);
  g.addColorStop(0, '#384048'); g.addColorStop(.48, '#22282d'); g.addColorStop(1, '#101417');
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  if (figure) {
    studioSoft(ctx, W / 2, H * .95, W * .33, H * .025, '#000000', .62);
    ctx.fillStyle = '#b9c1c8'; ctx.globalAlpha = .18; ctx.fillRect(W * .08, H * .967, W * .84, 1); ctx.globalAlpha = 1;
  }
}

// Continuous athlete silhouette (Game Design Bible §5). Adult landmarks and
// connected limb envelopes are shared across poses; no separate joint discs.
function drawStudioFigure(ctx, W, H, f, st, opts = {}) {
  const B = {muscle:.65,fat:.15,height:.5,shoulders:.5,reach:.5,legs:.5,hair:0,waist:f.sex==='f'?.4:.5,hips:f.sex==='f'?.65:.5,legMass:f.sex==='f'?.62:.5,chest:.5,arms:.5,neck:.5,traps:.5,belly:0,...f.body};
  const m=clamp(B.muscle,0,1),fat=clamp(B.fat,0,1),build=clamp(f.build??.5,0,1),female=f.sex==='f';
  const pose=opts.pose||'oficial',high=['vitoria','cinturao_erguido'].includes(pose);
  const skin=SKIN[f.skin]?.[0]||SKIN.t06[0],dark=darken(skin,.65),light=lighten(skin,.4);
  const sh=(female?1.0:1.2)+build*(female?.12:.16)+m*.08+(B.shoulders-.5)*.22;
  const waist=(female?.60:.77)+build*(female?.09:.13)+fat*.36+(B.waist-.5)*.2,hip=waist+(female?.37:.12)+(B.hips-.5)*.4;
  const gut=clamp(B.belly,0,1),armMass=(B.arms-.5),trap=(B.traps-.5);
  const legLength=1+(B.legs-.5)*.13+(B.height-.5)*.09;
  const kneeY=4.55+2.08*legLength,ankY=4.55+4.22*legLength,sole=ankY+.49;
  let scale=Math.min(H/(high?12.6:10.9),W/(high?7.1:6.0));
  let ox=W/2,oy=H*.948-sole*scale;
  const kit={shorts:'preto',gloves:'preto',hands:'bare',...f.kit};
  const shorts=SHORTS[kit.shorts]?.[0]||'#1c1f23',glove=GLOVES[kit.gloves]?.[0]||'#151719';
  const marks=new Set(f.marks||[]),definition=clamp(m*1.2-fat*1.5,0,1);
  const add=(a,b)=>[a[0]+b[0],a[1]+b[1]],sub=(a,b)=>[a[0]-b[0],a[1]-b[1]],mul=(a,k)=>[a[0]*k,a[1]*k];
  const unit=a=>mul(a,1/(Math.hypot(...a)||1));
  function smooth(points){
    // Matching winding is essential when overlapping torso and limb paths.
    let area=0;for(let i=0;i<points.length;i++){const a=points[i],b=points[(i+1)%points.length];area+=a[0]*b[1]-b[0]*a[1]}
    if(area<0)points=points.slice().reverse();
    const p=new Path2D(),n=points.length,a=points[n-1],b=points[0];p.moveTo((a[0]+b[0])/2,(a[1]+b[1])/2);
    for(let i=0;i<n;i++){const a=points[i],b=points[(i+1)%n];p.quadraticCurveTo(a[0],a[1],(a[0]+b[0])/2,(a[1]+b[1])/2)}p.closePath();return p;
  }
  function oval(x,y,rx,ry){const p=new Path2D();p.ellipse(x,y,rx,ry,0,0,Math.PI*2);return p}
  function stroke(p,col,width,alpha=1){ctx.save();ctx.strokeStyle=col;ctx.lineWidth=width;ctx.lineCap='round';ctx.lineJoin='round';ctx.globalAlpha=alpha;ctx.stroke(p);ctx.restore()}
  function curve(points,col,width,alpha=1){const p=new Path2D();p.moveTo(...points[0]);if(points.length===3)p.quadraticCurveTo(...points[1],...points[2]);else p.bezierCurveTo(...points[1],...points[2],...points[3]);stroke(p,col,width,alpha)}
  function material(p,color,x=0,y=3,r=sh+.5){ctx.fillStyle=studioGradient(ctx,color,x,y,r);ctx.fill(p)}
  const soft=(x,y,rx,ry,col,a,rot=0)=>studioSoft(ctx,x,y,rx,ry,col,a,rot);
  function envelope(nodes){
    const samples=[];
    for(let i=0;i<nodes.length-1;i++){
      const prev=nodes[Math.max(0,i-1)],a=nodes[i],b=nodes[i+1],next=nodes[Math.min(nodes.length-1,i+2)];
      for(let j=0;j<8;j++){const t=j/8,t2=t*t,t3=t2*t;
        const h0=2*t3-3*t2+1,h1=t3-2*t2+t,h2=-2*t3+3*t2,h3=t3-t2;
        samples.push([h0*a[0]+h1*(b[0]-prev[0])*.4+h2*b[0]+h3*(next[0]-a[0])*.4,
          h0*a[1]+h1*(b[1]-prev[1])*.4+h2*b[1]+h3*(next[1]-a[1])*.4,a[2]+(b[2]-a[2])*(t2*(3-2*t))]);}
    }
    samples.push(nodes[nodes.length-1]);const left=[],right=[];
    samples.forEach((p,i)=>{const d=unit(sub(samples[Math.min(samples.length-1,i+1)],samples[Math.max(0,i-1)])),n=[-d[1],d[0]];left.push(add(p,mul(n,p[2])));right.push(add(p,mul(n,-p[2])))});
    const a=nodes[0],b=nodes[nodes.length-1],da=unit(sub(nodes[1],a)),db=unit(sub(b,nodes[nodes.length-2]));
    return {path:smooth([add(a,mul(da,-a[2]*.75)),...left,add(b,mul(db,b[2]*.35)),...right.reverse()]),nodes};
  }
  function volume(limb){
    ctx.save();ctx.clip(limb.path);
    for(let i=0;i<limb.nodes.length-1;i++){
      const a=limb.nodes[i],b=limb.nodes[i+1],d=unit(sub(b,a)),len=Math.hypot(b[0]-a[0],b[1]-a[1]);
      const c=mul(add(a,b),.5),w=(a[2]+b[2])*.5,rot=Math.atan2(d[1],d[0])-Math.PI/2;
      let n=[-d[1],d[0]];if(n[0]<0)n=mul(n,-1);
      soft(c[0]+n[0]*w*.82,c[1]+n[1]*w*.82,w*.68,len*.88,dark,.49,rot);
      soft(c[0]-n[0]*w*.28,c[1]-n[1]*w*.28,w*.72,len*.76,light,.3,rot);
    }
    ctx.restore();
  }
  const shoulderL=[-sh,1.50],shoulderR=[sh,1.55],restX=Math.max(sh+.07,hip+.14);
  const positions={
    oficial:[[-sh-.10,3.25],[-restX,4.83],[sh+.13,3.29],[restX,4.9]],
    guarda:[[-sh+.10,3.08],[-.76,1.72],[sh-.06,2.98],[.76,1.54]],
    bracos_cruzados:[[-sh+.06,3.28],[.72,2.86],[sh-.06,3.30],[-.75,3.03]],
    vitoria:[[-sh-.74,.25],[-sh-.76,-1.40],[sh+.74,.25],[sh+.76,-1.40]],
    cinturao_peito:[[-sh-.1,3.3],[-.68,2.96],[sh+.1,3.3],[.7,2.85]],
    cinturao_ombro:[[-sh-.1,3.3],[-.65,3.08],[sh+.13,3.27],[sh+.11,4.85]],
    cinturao_erguido:[[-sh-.48,.0],[-.94,-1.55],[sh+.48,.0],[.94,-1.55]],
    cinturao_cintura:[[-sh-.45,3.15],[-waist-.13,4.05],[sh+.45,3.15],[waist+.13,4.05]]
  }[pose]||[];
  const reach=1+(B.reach-.5)*.22,armScale=(female?.83:1)*(.85+build*.16);
  const arms=[];
  for(const [s,A,E0,H0] of [[-1,shoulderL,positions[0],positions[1]],[1,shoulderR,positions[2],positions[3]]]){
    const E=add(A,mul(sub(E0,A),reach)),hand=add(E,mul(sub(H0,E0),reach));
    const midUpper=add(A,mul(sub(E,A),.42)),midFore=add(E,mul(sub(hand,E),.3));
    const limb=envelope([[...A,(.28+m*.07+armMass*.09)*armScale],[...midUpper,(.25+m*.065+fat*.06+armMass*.1)*armScale],[...E,(.165+armMass*.02)*armScale],[...midFore,(.205+m*.03+fat*.03+armMass*.055)*armScale],[...hand,.105*armScale]]);
    arms.push({...limb,A,E,hand,s});
  }
  if(opts.focus==='hands'){scale=Math.min(W/1.32,H/1.75);ox=W/2-arms[0].hand[0]*scale;oy=H*.42-arms[0].hand[1]*scale;}
  if(opts.focus==='feet'){scale=Math.min(W/2.7,H/1.65);ox=W/2;oy=H*.36-ankY*scale;}
  const legs=[];
  for(const s of [-1,1]){const spread=pose==='guarda'?.27:0,hipX=s*((female?.56:.46)+fat*.09+(B.hips-.5)*.19),kx=s*(.61+spread),ax=s*(.77+spread*1.45);
    const limb=envelope([[hipX,4.28,(.35+m*.085+fat*.14+(B.legMass-.5)*.18)*(female?1.14:1)],[hipX+s*.06,5.18,(.36+m*.07+fat*.1+(B.legMass-.5)*.18)*(female?1.12:1)],[kx,kneeY,.215+fat*.035],[kx+s*.025,kneeY+.68,.25+m*.035+fat*.04+(B.legMass-.5)*.075],[ax,ankY,.125+fat*.017]]);
    legs.push({...limb,s,kx,ax});
  }
  const neck=(female?.25:.275)+build*.045+(B.neck-.5)*.14;
  const torso=smooth([[-neck,.58],[-neck,1.0],[-.54-trap*.12,1.13-trap*.16],[-sh-.02,1.28],[-sh-.30,1.45],[-sh-.25,1.92],[-sh+.1,2.19],[-sh+.25,2.54],[-waist-gut*.16,3.3],[-waist-gut*.34,3.85],[-hip,4.26],[-hip*.7,4.7],[0,4.82],[hip*.7,4.7],[hip,4.26],[waist+gut*.34,3.85],[waist+gut*.16,3.3],[sh-.25,2.54],[sh-.1,2.19],[sh+.25,1.92],[sh+.30,1.45],[sh+.02,1.28],[.54+trap*.12,1.13-trap*.16],[neck,1.0],[neck,.58]]);
  const skinMesh=new Path2D();skinMesh.addPath(torso);for(const part of [...legs,...arms])skinMesh.addPath(part.path);
  ctx.save();ctx.translate(ox,oy);ctx.scale(scale,scale);
  const skinMaterial=studioGradient(ctx,skin,0,3,sh+.55);ctx.fillStyle=skinMaterial;ctx.fill(skinMesh);
  ctx.save();ctx.clip(skinMesh);
  studioTorso(ctx,1,0,-.14,skin,sh,waist,fat,m,female,f.seed||1);
  for(const limb of [...legs,...arms])volume(limb);
  // Deltoids blend across the torso/arm union. Armpits and clavicles describe attachments.
  for(const s of [-1,1]){
    soft(s*sh,1.57,.39,.42,light,s<0?.32:.16);
    soft(s*(sh-.16),2.12,.105,.39,dark,.32,-s*.2);
    curve([[s*.12,1.23],[s*.56,1.16],[s*(sh-.23),1.39]],dark,.028,.32);
    curve([[s*.12,1.18],[s*.61,1.13],[s*(sh-.24),1.33]],light,.016,.36);
    curve([[s*neck*.72,.7],[s*.15,1.08],[s*.21,1.23]],dark,.025,.35);
    curve([[s*.75,3.44],[s*.54,3.86],[s*.16,4.05]],dark,.021,.26*definition);
    if(!female){soft(s*sh*.46,2.17,.067,.044,mix(skin,'#623b34',.5),.57);soft(s*sh*.46,2.18,.025,.018,dark,.55)}
  }
  soft(0,.84,.33,.17,dark,.48);
  if(gut>.05){soft(-.2,3.5,waist*.75,.5,light,gut*.3);soft(waist*.55,3.95,waist*.5,.25,dark,gut*.35)}
  soft(0,3.65,.052,.065,dark,.6);soft(-.012,3.64,.018,.025,light,.45);
  for(const leg of legs){soft(leg.kx,kneeY,.16,.24,light,.23);soft(leg.kx+.12,kneeY+.05,.105,.24,dark,.26);
    curve([[leg.kx-.04,kneeY+.22],[leg.kx-.05,kneeY+1],[leg.ax-.035,ankY-.16]],light,.018,.26);}
  // Tattoos follow skin rather than floating over garment layers.
  const tattoo=mix(skin,'#1d2b30',.68);
  if(marks.has('shoulders'))for(const arm of arms){ctx.save();ctx.clip(arm.path);for(let j=0;j<6;j++){const y=1.57+j*.13;curve([[arm.s*(sh-.3),y],[arm.s*(sh+.22),y+.27],[arm.s*(sh+.45),y+.14]],tattoo,.045,.7)}ctx.restore()}
  if(marks.has('chest')&&!female){curve([[-.62,1.96],[0,1.72],[.62,1.96]],tattoo,.032,.65);curve([[-.5,2.07],[0,1.92],[.5,2.07]],tattoo,.019,.6)}
  if(B.hair>.08){const r=rngOf((f.seed||1)*621);ctx.strokeStyle=HAIR_COLORS[f.hair.color]?.[0]||'#241811';ctx.lineWidth=.006;ctx.globalAlpha=.31;
    for(let i=0;i<Math.round(B.hair*720);i++){let x=(r()-.5)*sh*1.5,y=1.63+r()*2.2;if(i>300){const leg=legs[i%2];x=leg.ax+(r()-.5)*.37;y=5.45+r()*(ankY-5.45)}const p=new Path2D();p.moveTo(x,y);p.quadraticCurveTo(x+.02,y+.025,x+(r()-.5)*.025,y+.06);ctx.stroke(p)}ctx.globalAlpha=1;}
  ctx.restore();
  // Bare feet: five individual phalanges per foot, with a medial big toe and nail beds.
  for(const leg of legs){
    ctx.save();ctx.translate(leg.ax,ankY);ctx.rotate(-leg.s*.075);
    const foot=smooth([[-.12,-.12],[-.14,.08],[-.225,.24],[-.21,.305],[.20,.305],[.23,.24],[.13,.07],[.12,-.12]]);
    const toes=[],footMesh=new Path2D();footMesh.addPath(foot);
    for(let i=0;i<5;i++){const x=leg.s*[-.155,-.041,.05,.128,.196][i],y=[.382,.403,.388,.36,.331][i],rx=i===0?.062:.043-i*.002;const toe=oval(x,y,rx,i===0?.102:.076-i*.004);toes.push({x,y,rx,path:toe});footMesh.addPath(toe)}
    ctx.fillStyle=skinMaterial;ctx.fill(foot);for(const toe of toes)ctx.fill(toe.path);ctx.save();ctx.clip(footMesh);soft(-.06,.19,.12,.29,light,.4);soft(.18,.19,.1,.28,dark,.35);ctx.restore();
    for(const toe of toes){curve([[toe.x-toe.rx*.55,toe.y+.012],[toe.x,toe.y+.026],[toe.x+toe.rx*.55,toe.y+.012]],dark,.009,.36);ctx.fillStyle=mix(skin,'#e2cabc',.17);ctx.fill(oval(toe.x,toe.y+.034,toe.rx*.55,.024));}
    curve([[-.08,.04],[-.025,.15],[-.1,.27]],dark,.012,.25);ctx.restore();
  }
  // Technical fight shorts: flexible cloth panels, elastic waist, seams and stitch detail.
  const hem=female?5.2:5.48,legHem=.99+fat*.17+(B.legMass-.5)*.23+(female?(B.hips-.5)*.3:0),shortShape=smooth([[-hip,3.97],[-hip-.04,4.55],[-legHem,hem],[-.15,hem+.045],[0,4.86],[.15,hem+.045],[legHem,hem],[hip+.04,4.55],[hip,3.97]]);
  material(shortShape,shorts,0,4.8,hip+.15);
  ctx.save();ctx.clip(shortShape);
  if(kit.shorts==='camuflado'){const r=rngOf((f.seed||1)*343);for(let i=0;i<64;i++){const x=(r()-.5)*2.7,y=4+r()*1.7;ctx.fillStyle=['#748163','#1f3528','#a99b70','#354733'][i%4];ctx.globalAlpha=.65;ctx.fill(oval(x,y,.06+r()*.21,.03+r()*.11))}ctx.globalAlpha=1;}
  for(const s of [-1,1]){for(let i=0;i<4;i++){const x=s*(.21+i*.2);soft(x,4.79+i*.08,.075,.64,darken(shorts,.65),.6,-s*.19);soft(x-.035,4.79+i*.08,.028,.59,lighten(shorts,.6),.3,-s*.19)}
    curve([[s*(hip-.04),4.22],[s*(hip-.05),4.78],[s*.94,hem-.1]],'#e7e3d8',.048,.72);
    curve([[s*.18,hem-.04],[s*.54,hem-.015],[s*.94,hem-.065]],lighten(shorts,.5),.012,.55);
  }
  ctx.fillStyle=darken(shorts,.35);ctx.fillRect(-hip-.15,3.97,hip*2+.3,.22);
  for(let i=0;i<42;i++){const x=-hip+i*(hip*2/42);curve([[x,4.02],[x+.008,4.08],[x,4.14]],lighten(shorts,.3),.008,.35)}
  ctx.restore();
  curve([[-.04,4.08],[-.075,4.3],[-.11,4.35]],'#e9e4dc',.019,.85);curve([[.04,4.08],[.10,4.28],[.14,4.3]],'#e9e4dc',.019,.85);
  if(female){const fullness=B.chest,outer=sh-.1+fullness*.09,under=2.55+fullness*.14;
    const top=smooth([[-outer,1.8],[-.63,1.75],[0,1.98],[.63,1.75],[outer,1.8],[outer+.035,2.16],[.89,under],[0,under+.065],[-.89,under],[-outer-.035,2.16]]);
    const fabric=mix(shorts,'#1d2730',.68);material(top,fabric,0,2,1.3);ctx.save();ctx.clip(top);
    for(const side of[-1,1]){soft(side*.45,2.14,.43+fullness*.07,.28+fullness*.09,lighten(fabric,.5),side<0?.36:.18,side*.10);soft(side*.46,under-.05,.45,.085,darken(fabric,.65),.48)}
    soft(.0,2.15,.065,.32,darken(fabric,.6),.35);ctx.restore();
    for(const side of[-1,1]){curve([[side*.58,1.99],[side*.50,1.45],[side*.44,1.18]],fabric,.14);curve([[side*.52,1.87],[side*.48,1.50],[side*.44,1.20]],lighten(fabric,.4),.012,.5);
      curve([[side*.09,2.07],[side*.3,2.33],[side*.84,under-.12]],lighten(fabric,.33),.009,.5);}
    curve([[-.88,under-.06],[0,under+.04],[.88,under-.06]],darken(fabric,.4),.075,.9);
    curve([[-.87,under-.045],[0,under+.046],[.87,under-.045]],lighten(fabric,.3),.009,.6);
  }else{
    ctx.save();ctx.clip(torso);for(const side of[-1,1])soft(side*sh*.46,1.95,sh*.46,.36+(B.chest-.5)*.15,light,.13+B.chest*.18);ctx.restore();
  }
  // Forearms crossing the chest must occlude skin/cloth with one continuous envelope.
  if(['bracos_cruzados','guarda','cinturao_peito','cinturao_ombro'].includes(pose))for(const arm of arms){
    if(pose==='cinturao_ombro'&&arm.s>0)continue;
    const d=unit(sub(arm.hand,arm.E)),start=add(arm.E,mul(d,-.06));
    const front=envelope([[...start,.17*armScale],[...add(arm.E,mul(sub(arm.hand,arm.E),.3)),(.205+m*.03)*armScale],[...arm.hand,.105*armScale]]);
    material(front.path,skin,0,3,sh+.55);volume(front);
  }
  function belt(cx,cy,w,h,rotation=0){ctx.save();ctx.translate(cx,cy);ctx.rotate(rotation);
    const strap=smooth([[-w*.94,-h*.28],[w*.94,-h*.28],[w*.94,h*.28],[-w*.94,h*.28]]);material(strap,'#16191b',0,0,w);
    const gold=ctx.createLinearGradient(-w*.5,-h*.5,w*.5,h*.5);[[0,'#e7d09b'],[.24,'#b78b4a'],[.48,'#f1d799'],[.68,'#765628'],[1,'#c5a261']].forEach(([t,c])=>gold.addColorStop(t,c));
    const plate=smooth([[-w*.5,-h*.33],[-w*.29,-h*.53],[w*.29,-h*.53],[w*.5,-h*.33],[w*.5,h*.33],[w*.29,h*.53],[-w*.29,h*.53],[-w*.5,h*.33]]);ctx.fillStyle=gold;ctx.fill(plate);stroke(plate,'#6a4a20',.025,.85);
    ctx.save();ctx.scale(.85,.77);stroke(plate,'#f4e4b6',.014,.75);ctx.restore();
    ctx.fillStyle='#22272a';ctx.fillRect(-w*.22,-h*.26,w*.44,h*.52);ctx.fillStyle='#d4b373';ctx.fillRect(-w*.17,-h*.17,w*.12,h*.34);ctx.fillRect(w*.05,-h*.17,w*.12,h*.34);ctx.fillStyle='#ae4944';ctx.fillRect(-.018,-h*.22,.036,h*.44);
    for(const s of[-1,1]){ctx.fillStyle=gold;ctx.fill(oval(s*w*.73,0,w*.13,h*.2));}ctx.restore();}
  if(pose==='cinturao_peito')belt(0,2.72,1.44,.94);
  if(pose==='cinturao_ombro')belt(-.53,2.55,1.36,.88,-.35);
  if(pose==='cinturao_erguido')belt(0,-1.62,1.56,.95);
  if(pose==='cinturao_cintura')belt(0,3.89,1.49,.89);
  ctx.restore();
  // Existing library retains facial identity and aging; the body's neck is already in the mesh.
  drawFace(ctx,W,H,f,st,{...opts,noBody:true,skipNeck:true,S:scale*.76,ox,oy:oy+.025*scale});
  ctx.save();ctx.translate(ox,oy);ctx.scale(scale,scale);
  function hand(arm){
    const d=unit(sub(arm.hand,arm.E)),angle=Math.atan2(d[1],d[0])-Math.PI/2;
    const closed=pose!=='oficial'&&pose!=='bracos_cruzados'&&!(pose==='cinturao_ombro'&&arm.s>0);
    ctx.save();ctx.translate(...arm.hand);ctx.rotate(angle);ctx.scale(female?.91:1,female?.91:1);
    const palm=smooth([[-.1,-.075],[-.15,.12],[-.18,.28],[-.14,.37],[.14,.37],[.18,.23],[.13,.07],[.10,-.075]]);
    const handMesh=new Path2D();handMesh.addPath(palm);const fingers=[];
    for(let i=0;i<4;i++){
      const x=-.123+i*.083,len=[.29,.35,.33,.245][arm.s<0?i:3-i],drift=(i-1.5)*.009;
      const finger=closed?oval(x,.345+(i===0||i===3?-.012:.012),.046,.088):smooth([[x-.034,.245],[x-.044,.35],[x-.028+drift,.34+len],[x+.032+drift,.35+len],[x+.037,.38],[x+.034,.25]]);
      handMesh.addPath(finger);fingers.push({x,len,drift,path:finger});
    }
    const side=-arm.s,thumb=closed?smooth([[side*.17,.12],[side*.23,.24],[side*.08,.33],[-side*.07,.30],[-side*.055,.245],[side*.11,.22]]):smooth([[side*.12,.08],[side*.25,.19],[side*.29,.34],[side*.23,.405],[side*.185,.31],[side*.08,.22]]);
    handMesh.addPath(thumb);ctx.fillStyle=skinMaterial;ctx.fill(palm);for(const finger of fingers)ctx.fill(finger.path);ctx.fill(thumb);
    ctx.save();ctx.clip(handMesh);soft(-.06,.19,.17,.35,light,.32);soft(.19,.26,.085,.4,dark,.33);ctx.restore();
    for(const finger of fingers){const y=closed?.365:.35+finger.len;
      curve([[finger.x-.025,closed?.31:.42],[finger.x,closed?.3:.43],[finger.x+.025,closed?.31:.42]],dark,.005,.32);
      ctx.fillStyle=mix(skin,'#ead9c7',.14);ctx.fill(oval(finger.x+finger.drift,y-.025,.023,closed?.019:.031));
      if(!closed)curve([[finger.x-.026,y-.105],[finger.x,y-.098],[finger.x+.023,y-.105]],dark,.004,.26);
    }
    if(kit.hands==='mma'){
      const pad=smooth([[-.165,.01],[-.205,.10],[-.195,.275],[0,.32],[.195,.275],[.205,.1],[.165,.01]]);material(pad,glove,0,.15,.24);
      stroke(pad,darken(glove,.6),.016,.85);curve([[-.15,.21],[0,.26],[.15,.21]],lighten(glove,.6),.01,.6);
      ctx.fillStyle='#c9c8c0';ctx.fillRect(-.13,-.12,.26,.10);ctx.fillStyle=darken(glove,.2);ctx.fillRect(-.145,-.04,.29,.12);
      for(let j=0;j<4;j++)curve([[-.12+j*.08,.05],[-.13+j*.08,.15],[-.12+j*.08,.23]],lighten(glove,.3),.007,.5);
    }else{curve([[-.1,.15],[.01,.2],[.12,.16]],dark,.01,.22);for(const x of[-.07,0,.075])curve([[x,-.01],[x*.9,.1],[x*1.4,.23]],light,.01,.21);}
    ctx.restore();
  }
  for(const arm of arms)hand(arm);
  ctx.restore();
}
