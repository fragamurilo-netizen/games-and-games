// Shared procedural identity. Game Design Bible §5.

/* ================= utilidades ================= */
function rngOf(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
function h2r(h){return[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)]}
function r2h(r){return'#'+r.map(v=>clamp(Math.round(v),0,255).toString(16).padStart(2,'0')).join('')}
function mix(a,b,t){const A=h2r(a),B=h2r(b);return r2h(A.map((v,i)=>v+(B[i]-v)*t))}
const darken=(c,t)=>mix(c,'#26120c',t), lighten=(c,t)=>mix(c,'#fff4ea',t);
const lum=c=>{const[r,g,b]=h2r(c);return(.299*r+.587*g+.114*b)/255};
function pickW(r,obj){let t=0;for(const k in obj)t+=obj[k];let x=r()*t;for(const k in obj){x-=obj[k];if(x<=0)return k}return Object.keys(obj)[0]}
const pick=(r,a)=>a[Math.floor(r()*a.length)];
const clone=o=>JSON.parse(JSON.stringify(o));
const PAL={paper:'#F1EEE6',ink:'#1B2025',red:'#C83B3B',steel:'#46535E',surface:'#1B2025',surface2:'#232A31'};

/* ================= biblioteca ================= */
const SKIN={
 t01:['#f7ded0','Muito clara rosada'],t02:['#f1d2b8','Clara'],t03:['#e9c4a1','Clara quente'],t04:['#dcbb92','Clara oliva'],
 t05:['#d6a57f','Média clara'],t06:['#c99570','Média'],t07:['#bd8c5e','Média oliva'],t08:['#b27a52','Bronzeada'],
 t09:['#a06a45','Morena'],t10:['#8f5d3b','Morena escura'],t11:['#7d4f33','Marrom'],t12:['#6c422a','Marrom escura'],
 t13:['#5b3622','Escura'],t14:['#4a2b1b','Muito escura'],t15:['#3b2216','Retinta'],
};
const HAIR_COLORS={
 preto:['#17110e','Preto'],castanho_escuro:['#35231a','Castanho escuro'],castanho:['#5a3a22','Castanho'],castanho_claro:['#7d5a3a','Castanho claro'],
 ruivo_escuro:['#7a3a20','Ruivo escuro'],ruivo:['#a24a22','Ruivo'],loiro_escuro:['#94733f','Loiro escuro'],loiro:['#c7a15f','Loiro'],
 platinado:['#e3d7bb','Platinado'],grisalho:['#8e8a84','Grisalho'],branco:['#d8d5cf','Branco'],tingido_vermelho:['#8e1f2b','Tingido vermelho'],tingido_azul:['#23466e','Tingido azul'],
 tingido_rosa:['#c2507e','Tingido rosa'],tingido_verde:['#2f7a4f','Tingido verde'],multicolor:['#a2508a','Mechas coloridas'],
 bicolor:['#9a3a7a','Duas cores'],pontas_claras:['#3a2a1c','Pontas descoloridas'],acaju:['#6e2a1c','Acaju'],prata:['#b9bcc0','Prata'],
};
const IRIS={escuro:['#24170f','Castanho escuro'],castanho:['#4a2e1a','Castanho'],mel:['#7a5420','Mel'],verde:['#5a6b3e','Verde'],azul:['#4d6d8c','Azul'],cinza:['#6d7b83','Cinza']};

const HEADS={
 oval:{n:'Oval',hw:.76,jw:.58,cw:.24,cl:.03,cb:1,cr:.8},
 quadrado:{n:'Quadrado',hw:.8,jw:.72,cw:.34,cl:.02,cb:1,cr:.78},
 redondo:{n:'Redondo',hw:.82,jw:.65,cw:.3,cl:-.02,cb:1.05,cr:.78},
 alongado:{n:'Alongado',hw:.72,jw:.58,cw:.26,cl:.1,cb:1,cr:.86},
 diamante:{n:'Diamante',hw:.72,jw:.54,cw:.21,cl:.05,cb:1.14,cr:.8},
 coracao:{n:'Coração',hw:.8,jw:.52,cw:.19,cl:.04,cb:1,cr:.8},
 retangular:{n:'Retangular',hw:.76,jw:.7,cw:.33,cl:.09,cb:1,cr:.84},
};
const EYES={
 amendoado:{n:'Amendoado',w:.12,h:.075,tilt:.01,crease:1},
 redondo:{n:'Redondo',w:.115,h:.095,tilt:0,crease:1},
 encapuzado:{n:'Encapuzado',w:.12,h:.066,tilt:0,hood:1},
 monolid:{n:'Pálpebra única',w:.122,h:.052,tilt:.018,mono:1},
 profundo:{n:'Profundo',w:.115,h:.07,tilt:0,deep:1,crease:1},
 caido:{n:'Caído',w:.12,h:.07,tilt:-.028,crease:1},
 puxado:{n:'Puxado para cima',w:.122,h:.066,tilt:.034,crease:1},
 pequeno:{n:'Pequeno',w:.1,h:.058,tilt:.005,crease:1},
 grande:{n:'Grande',w:.132,h:.09,tilt:.005,crease:1},
};
const BROWS={
 reta:{n:'Reta',arch:0,t:.05},
 arqueada:{n:'Arqueada',arch:.04,t:.045},
 alta:{n:'Arco alto',arch:.075,t:.04},
 grossa:{n:'Grossa',arch:.01,t:.075},
 fina:{n:'Fina',arch:.04,t:.025},
 angular:{n:'Angular',arch:.055,t:.05,angular:1},
 espessa:{n:'Espessa',arch:.02,t:.085,bushy:1},
 baixa:{n:'Baixa e reta',arch:-.01,t:.055,low:.04},
};
const NOSES={
 reto:{n:'Reto',nw:.15,len:.34,bw:.07},
 botao:{n:'Botão',nw:.12,len:.3,bw:.06,round:1},
 largo:{n:'Largo',nw:.21,len:.33,bw:.085,flare:.035},
 aquilino:{n:'Aquilino',nw:.14,len:.37,bw:.07,bump:.035,tip:.03},
 romano:{n:'Romano',nw:.16,len:.39,bw:.08,bump:.02,tip:.015},
 arrebitado:{n:'Arrebitado',nw:.13,len:.29,bw:.06,up:1},
 fino:{n:'Fino e longo',nw:.12,len:.39,bw:.05},
 achatado:{n:'Achatado (boxeador)',nw:.2,len:.31,bw:.1,flat:1},
 carnudo:{n:'Ponta carnuda',nw:.17,len:.35,bw:.07,round:1.4},
};
const MOUTHS={
 neutra:{n:'Neutra',w:.2,up:.035,lo:.045,curve:0,bow:.012},
 fina:{n:'Lábios finos',w:.2,up:.017,lo:.025,curve:0,bow:.006},
 carnuda:{n:'Carnuda',w:.21,up:.052,lo:.072,curve:0,bow:.018},
 larga:{n:'Larga',w:.25,up:.03,lo:.045,curve:0,bow:.01},
 pequena:{n:'Pequena',w:.155,up:.035,lo:.048,curve:0,bow:.012},
 canto:{n:'Sorriso de canto',w:.2,up:.032,lo:.042,curve:0,bow:.01,smirk:.028},
 seria:{n:'Séria',w:.2,up:.025,lo:.035,curve:-.022,bow:.008},
 inferior:{n:'Inferior cheio',w:.2,up:.022,lo:.078,curve:0,bow:.008},
 arco:{n:'Arco do cupido marcado',w:.2,up:.045,lo:.05,curve:0,bow:.026},
};
const EARS={
 normal:{n:'Normal',rx:.1,ry:.19},pequena:{n:'Pequena',rx:.082,ry:.16},abano:{n:'De abano',rx:.14,ry:.2,out:.05},grande:{n:'Grande',rx:.115,ry:.23},
};
const HAIR_STYLES={
 raspado:{n:'Raspado'},maquina:{n:'Máquina'},degrade_baixo:{n:'Degradê baixo'},degrade_alto:{n:'Degradê navalhado'},
 militar:{n:'Militar'},curto:{n:'Curto texturizado'},cacheado_curto:{n:'Cacheado curto'},risca:{n:'Risca lateral'},
 topete:{n:'Topete'},para_tras:{n:'Penteado para trás'},moicano:{n:'Moicano'},fauxhawk:{n:'Faux-hawk'},
 franja:{n:'Franja'},black_power:{n:'Black power'},afro_curto:{n:'Afro curto'},twists:{n:'Twists'},
 nago:{n:'Trança nagô'},box_braids:{n:'Box braids'},dreads_curtos:{n:'Dreads curtos'},dreads_longos:{n:'Dreads longos'},
 coque_masc:{n:'Coque alto'},coque:{n:'Coque'},rabo:{n:'Rabo de cavalo'},longo_liso:{n:'Longo liso'},
 longo_ondulado:{n:'Longo ondulado'},cacheado_longo:{n:'Cacheado longo'},mullet:{n:'Mullet'},coroa:{n:'Calvície de coroa'},
 undercut:{n:'Undercut para trás'},mullet_moderno:{n:'Mullet moderno'},crop_frances:{n:'Crop francês'},espetado:{n:'Espetado'},
 degrade_risca:{n:'Degradê com risca'},high_top:{n:'High top'},moicano_cacheado:{n:'Moicano cacheado'},dreads_presos:{n:'Dreads presos no alto'},
 meio_coque:{n:'Meio coque'},duas_trancas:{n:'Duas tranças'},tranca_unica:{n:'Trança única'},coque_baixo:{n:'Coque baixo'},
 pixie:{n:'Pixie'},undercut_lateral:{n:'Lateral raspada'},
 quiff:{n:'Topete curto',novo:1},franja_longa:{n:'Franja longa',novo:1},cogumelo:{n:'Cogumelo',novo:1},ombro:{n:'Na altura do ombro',novo:1},
 ondulado_medio:{n:'Ondulado médio',novo:1},cachos_volumosos:{n:'Cachos volumosos',novo:1},dreads_soltos:{n:'Dreads soltos',novo:1},twists_altos:{n:'Twists altos',novo:1},
 afro_puff:{n:'Afro puff',novo:1},rabo_alto:{n:'Rabo alto',novo:1},coque_baguncado:{n:'Coque bagunçado',novo:1},curto_lateral:{n:'Curto de lado',novo:1},
 volumoso:{n:'Volumoso espetado',novo:1},trancas_laterais:{n:'Tranças nas laterais',novo:1},
 waves_360:{n:'Ondas 360',novo:2},caesar:{n:'Caesar',novo:2},flat_top:{n:'Flat top',novo:2},maquina_desenho:{n:'Máquina com desenho',novo:2},
 afro_degrade:{n:'Afro com degradê',novo:2},cachos_degrade:{n:'Cachos com degradê',novo:2},slick_longo:{n:'Longo para trás',novo:2},samurai:{n:'Coque samurai',novo:2},
 undercut_coque:{n:'Undercut com coque',novo:2},nago_zigue:{n:'Nagô em zigue-zague',novo:2},freeform:{n:'Locs livres',novo:2},franja_cortina:{n:'Franja cortina',novo:2},
 wolf_cut:{n:'Wolf cut',novo:2},calvo_lateral:{n:'Calvo no topo',novo:2},viking_trancado:{n:'Lateral raspada com trança',novo:2},espinhos:{n:'Espinhos curtos',novo:2},
 trancas_boxeadora:{n:'Tranças de boxeadora',novo:2},bob:{n:'Chanel',novo:2},long_bob:{n:'Chanel alongado',novo:2},shag:{n:'Shag repicado',novo:2},
 coque_trancado:{n:'Coque trançado',novo:2},rabo_trancado:{n:'Rabo trançado',novo:2},bantu_knots:{n:'Bantu knots',novo:2},nago_longas:{n:'Nagô longas',novo:2},
 franja_reta_longo:{n:'Longo com franja reta',novo:2},coques_duplos:{n:'Dois coques',novo:2},
};
const BEARDS={
 nenhuma:{n:'Sem barba'},sombra:{n:'Sombra'},por_fazer:{n:'Por fazer'},cheia_curta:{n:'Cheia curta'},cheia_longa:{n:'Cheia longa'},
 sem_bigode:{n:'Sem bigode'},cavanhaque:{n:'Cavanhaque'},cavanhaque_bigode:{n:'Cavanhaque e bigode'},ancora:{n:'Âncora'},
 bigode:{n:'Bigode'},bigode_fino:{n:'Bigode fino'},ferradura:{n:'Ferradura'},costeletas:{n:'Costeletas largas'},
 contorno:{n:'Contorno'},mosca:{n:'Mosca'},
 desenhada:{n:'Barba desenhada',novo:1},longa_sem_bigode:{n:'Longa sem bigode',novo:1},bigode_grosso:{n:'Bigode grosso',novo:1},cavanhaque_longo:{n:'Cavanhaque longo',novo:1},
 cheia_media:{n:'Cheia média',novo:2},lenhador:{n:'Lenhador',novo:2},viking_trancada:{n:'Viking trançada',novo:2},van_dyke:{n:'Van Dyke',novo:2},
 balbo:{n:'Balbo',novo:2},garibaldi:{n:'Garibaldi',novo:2},bigode_guidao:{n:'Bigode guidão',novo:2},chevron:{n:'Bigode chevron',novo:2},
 fu_manchu:{n:'Fu manchu',novo:2},barba_degrade:{n:'Barba com degradê',novo:2},falhada:{n:'Barba falhada',novo:2},ducktail:{n:'Barba em ponta',novo:2},
 costeletas_bigode:{n:'Costeletas com bigode',novo:2},contorno_bigode:{n:'Contorno com bigode',novo:2},
};
const MARKS=[
 ['sardas_leves','Sardas leves','freckles',.4],['sardas','Sardas fortes','freckles',1],
 ['pinta_bochecha','Pinta na bochecha','mole'],['pinta_queixo','Pinta no queixo','mole'],['pinta_labio','Pinta no lábio','mole'],
 ['brow_l','Cicatriz supercílio E','scar'],['brow_r','Cicatriz supercílio D','scar'],['cheek_l','Cicatriz bochecha E','scar'],['cheek_r','Cicatriz bochecha D','scar'],
 ['lip','Cicatriz no lábio','scar'],['nose','Cicatriz no nariz','scar'],['chin','Cicatriz no queixo','scar'],
 ['neck','Tatuagem no pescoço','tattoo'],['chest','Tatuagem no peito','tattoo'],['shoulders','Tatuagem nos ombros','tattoo'],['temple','Tatuagem na têmpora','tattoo'],
 ['argola','Argola na orelha','piercing'],['brinco','Brinco','piercing'],
];

/* ================= caneta ================= */
function makePen(ctx,S,ox,oy,mode,rng){
  let cx=0,cy=0;
  const J=()=>mode==='sketch'?(rng()-.5)*.026:0;
  const X=x=>ox+x*S, Y=y=>oy+y*S;
  return{
    begin(){ctx.beginPath()},
    m(x,y){x+=J();y+=J();ctx.moveTo(X(x),Y(y));cx=x;cy=y},
    l(x,y){x+=J();y+=J();ctx.lineTo(X(x),Y(y));cx=x;cy=y},
    q(qx,qy,x,y){x+=J();y+=J();
      if(mode==='geo'){ctx.lineTo(X(.25*cx+.5*qx+.25*x),Y(.25*cy+.5*qy+.25*y));ctx.lineTo(X(x),Y(y))}
      else ctx.quadraticCurveTo(X(qx),Y(qy),X(x),Y(y));cx=x;cy=y},
    c(ax,ay,bx,by,x,y){x+=J();y+=J();
      if(mode==='geo'){ctx.lineTo(X((cx+3*ax+3*bx+x)/8),Y((cy+3*ay+3*by+y)/8));ctx.lineTo(X(x),Y(y))}
      else ctx.bezierCurveTo(X(ax),Y(ay),X(bx),Y(by),X(x),Y(y));cx=x;cy=y},
    e(ex,ey,rx,ry,a0=0,a1=Math.PI*2,newSub=true){
      if(mode==='geo'||mode==='sketch'){
        const span=Math.abs(a1-a0),n=mode==='geo'?Math.max(3,Math.round(8*span/(Math.PI*2))):Math.max(8,Math.round(26*span/(Math.PI*2)));
        for(let i=0;i<=n;i++){const a=a0+(a1-a0)*i/n,px=ex+Math.cos(a)*rx+J()*.5,py=ey+Math.sin(a)*ry+J()*.5;
          if(i===0&&newSub)ctx.moveTo(X(px),Y(py));else ctx.lineTo(X(px),Y(py));cx=px;cy=py}
      }else{
        if(newSub)ctx.moveTo(X(ex+Math.cos(a0)*rx),Y(ey+Math.sin(a0)*ry));
        ctx.ellipse(X(ex),Y(ey),Math.max(.1,rx*S),Math.max(.1,ry*S),0,a0,a1,false);cx=ex+Math.cos(a1)*rx;cy=ey+Math.sin(a1)*ry}
    },
    close(){ctx.closePath()}
  }
}

/* ================= desenho ================= */
function geometry(f){
  const H=HEADS[f.head.shape]||HEADS.oval, fem=f.sex==='f';
  const hw=H.hw+(f.head.width||0)*.05;
  let jw=H.jw+(f.head.jaw||0)*.07, cw=H.cw+(f.head.jaw||0)*.03;
  if(fem){jw*=.88;cw*=.84}
  const cl=H.cl+(f.head.chin||0)*.05;
  return{hw,jw,cw,cl,chinY:.86+cl,cb:H.cb,cr:H.cr};
}
function ageFx(f){const a=f.age;return{gray:clamp((a-32)/13,0,.8)*(f.grayGene??1),recede:(f.recede||0)*clamp((a-23)/15,0,1),wrinkle:clamp((a-27)/14,0,1)}}

function drawFace(ctx,W,H,f,st,opts={}){
  const zoom=opts.zoom||1, S=opts.S??W*.3*zoom, ox=opts.ox??W/2;
  const oy=opts.oy??(opts.cy!=null?H/2-opts.cy*S:H*(opts.avatar?.56:.44));
  const rng=rngOf((f.seed||1)*97+1);
  const P=makePen(ctx,S,ox,oy,st.pen,rng);
  const A=ageFx(f), g=geometry(f);
  if(st.realistic){g.hw*=.89;g.jw*=.82;g.cw*=.88;}
  const {hw,jw,cw,chinY,cb,cr}=g;
  const fem=f.sex==='f', sketch=st.mode==='sketch', INK=PAL.ink, contrast=st.contrast||1;
  const skin=SKIN[f.skin]?.[0]||SKIN.t06[0];
  const dk=lum(skin)<.42;
  const shade=darken(skin,dk?.3:.24), deep=darken(skin,dk?.5:.45), light=lighten(skin,dk?.14:.2);
  const lipC=mix(skin,dk?'#4a1d20':'#7a2c33',dk?.3:.34);
  const hairBase=HAIR_COLORS[f.hair.color]?.[0]||'#17110e';
  const hairC=mix(hairBase,'#c6c2ba',f.hair.color.startsWith('tingido')||['platinado','multicolor','bicolor','pontas_claras','prata'].includes(f.hair.color)?0:A.gray);
  const beardBase=HAIR_COLORS[f.beard.color||(['multicolor','bicolor','pontas_claras','platinado','prata'].includes(f.hair.color)||f.hair.color.startsWith('tingido')?'castanho_escuro':f.hair.color)]?.[0]||hairBase;
  const beardC=mix(beardBase,'#cfcbc3',Math.min(.9,A.gray*1.15));
  const build=f.build??.5, nw=.3+.2*build;
  const marks=new Set(f.marks||[]);

  function paint(fn,color,o={}){
    const alpha=o.alpha??1;ctx.save();P.begin();fn();
    if(sketch){ctx.globalAlpha=alpha*.34;ctx.fillStyle=color;ctx.fill();
      if(o.stroke!==false){ctx.globalAlpha=1;ctx.strokeStyle=INK;ctx.lineWidth=S*.02*(o.lw||1);ctx.lineJoin='round';ctx.stroke();P.begin();fn();ctx.globalAlpha=.45;ctx.stroke()}}
    else{ctx.globalAlpha=alpha;ctx.fillStyle=st.realistic&&color===skin?studioGradient(ctx,skin,ox,oy,hw*S):color;ctx.fill();
      if(st.outline&&o.stroke!==false){ctx.globalAlpha=1;ctx.strokeStyle=o.ink||darken(color,.62);ctx.lineWidth=S*.026*(o.lw||1);ctx.lineJoin='round';ctx.stroke()}}
    ctx.restore();
  }
  function hatch(alpha,angle=1){ctx.strokeStyle=INK;ctx.globalAlpha=clamp(alpha,0,1);ctx.lineWidth=Math.max(1,S*.011);const step=S*.06;ctx.beginPath();
    for(let x=-W;x<W*2;x+=step){ctx.moveTo(x,0);ctx.lineTo(x+H*.55*angle,H)}ctx.stroke()}
  function shadeIn(clip,fn,color,alpha){ctx.save();P.begin();clip();ctx.clip();
    if(sketch){P.begin();fn();ctx.clip();hatch(alpha*1.3)}else{P.begin();fn();ctx.globalAlpha=clamp(alpha*contrast*(st.realistic?.55:1),0,1);ctx.fillStyle=color;if(st.realistic)ctx.filter=`blur(${S*.04}px)`;ctx.fill()}ctx.restore()}
  function line(fn,color,lw,alpha=1){ctx.save();P.begin();fn();ctx.strokeStyle=sketch?INK:color;ctx.globalAlpha=alpha*(st.realistic?.8:1);ctx.lineWidth=S*lw*(st.realistic?.65:1);ctx.lineCap='round';ctx.lineJoin='round';ctx.stroke();ctx.restore()}
  const hairInk=darken(hairC,.5);
  let hairFill=hairC;
  if(f.hair.color==='multicolor'&&!sketch){hairFill=ctx.createLinearGradient(ox-hw*S*1.2,oy-1.2*S,ox+hw*S*1.2,oy+.2*S);
    [['#d9489a',0],['#f0b43c',.3],['#3fb3c9',.6],['#8a4fd0',1]].forEach(([c,t])=>hairFill.addColorStop(t,c))}
  if(f.hair.color==='bicolor'&&!sketch){hairFill=ctx.createLinearGradient(ox-hw*S,0,ox+hw*S,0);
    [['#d4357e',0],['#d4357e',.5],['#2f72c4',.5],['#2f72c4',1]].forEach(([c,t])=>hairFill.addColorStop(t,c))}
  if(f.hair.color==='pontas_claras'&&!sketch){hairFill=ctx.createLinearGradient(0,oy-1.35*S,0,oy-.35*S);
    [['#dcc38e',0],['#b58f55',.35],['#2a1d14',.75],['#1c140f',1]].forEach(([c,t])=>hairFill.addColorStop(t,c))}
  const hpaint=(fn,o={})=>{paint(fn,st.realistic&&typeof hairFill==='string'?studioGradient(ctx,hairC,ox,oy,hw*S):hairFill,{ink:hairInk,...o});if(st.realistic)studioHair(ctx,()=>{P.begin();fn()},hairC,f.seed||1,S,ox,oy,false,.7,f.hair.style)};

  const head=()=>{P.m(-hw,-.27);P.e(0,-.27,hw,cr,Math.PI,Math.PI*2,false);
    P.c(hw*cb,.12,jw+.06,.42,jw,.6);P.q(jw-.06,chinY-.06,cw,chinY);P.q(0,chinY+.06,-cw,chinY);
    P.q(-jw+.06,chinY-.06,-jw,.6);P.c(-jw-.06,.42,-hw*cb,.12,-hw,-.27);P.close()};
  const cranium=(v=0)=>P.e(0,-.27,hw+v,cr+v);
  const topY=-.27-cr;

  /* ---------- cabelo: parte de trás ---------- */
  const hs=f.hair.style;
  const rope=(x0,y0,len,s,wd=.06)=>()=>{P.m(x0-wd,y0);P.q(x0+s*.12,y0+len*.5,x0+s*.02,y0+len);P.l(x0+s*.02+s*wd*1.4,y0+len);P.q(x0+s*.2,y0+len*.5,x0+wd,y0);P.close()};
  if(hs==='black_power')hpaint(()=>P.e(0,-.5,hw*1.36,.8));
  if(hs==='afro_curto')hpaint(()=>P.e(0,-.4,hw*1.14,.66));
  if(hs==='longo_liso'||hs==='longo_ondulado'){
    hpaint(()=>{P.m(-hw*1.06,-.45);
      if(hs==='longo_ondulado'){P.q(-hw*1.35,.0,-hw*1.12,.3);P.q(-hw*.95,.6,-hw*1.2,.9);P.q(-hw*1.35,1.2,-hw*1.05,1.45)}else P.q(-hw*1.22,.7,-hw*1.04,1.45);
      P.l(hw*1.04,1.45);
      if(hs==='longo_ondulado'){P.q(hw*1.35,1.2,hw*1.2,.9);P.q(hw*.95,.6,hw*1.12,.3);P.q(hw*1.35,0,hw*1.06,-.45)}else P.q(hw*1.22,.7,hw*1.06,-.45);
      P.close()});
  }
  if(hs==='cacheado_longo'){
    hpaint(()=>{P.e(0,-.1,hw*1.35,1.1)});
    if(!sketch)for(let i=0;i<22;i++){const a=Math.PI*.9+i/21*Math.PI*1.2;hpaint(()=>P.e(Math.cos(a)*hw*1.33,-.1+Math.sin(a)*1.08,.1,.1),{stroke:false})}
  }
  if(hs==='dreads_longos'||hs==='box_braids'){
    const n=hs==='box_braids'?5:4;
    for(const s of[-1,1])for(let i=0;i<n;i++){const x0=s*(hw*.8+i*.065),len=(hs==='box_braids'?1.55:1.3)+i*.04;
      hpaint(rope(x0,-.15,len,s,hs==='box_braids'?.045:.06),{lw:.8});
      if(hs==='box_braids'&&!sketch)for(let k=0;k<8;k++){const yy=0+k*.19;line(()=>{P.m(x0,yy);P.q(x0+s*.05,yy+.05,x0+s*.09,yy+.02)},darken(hairC,.5),.013,.7)}}
  }
  if(hs==='dreads_curtos'){for(const s of[-1,1])for(let i=0;i<4;i++){const x0=s*(hw*.62+i*.1);hpaint(rope(x0,-.5,.55+i*.06,s,.055),{lw:.8})}}
  if(hs==='coque')hpaint(()=>P.e(hw*.1,topY-.05,.26,.2));
  if(hs==='coque_masc')hpaint(()=>P.e(0,topY-.02,.2,.15));
  if(hs==='rabo')hpaint(()=>{P.m(hw*.55,-.85);P.q(hw*1.35,-.3,hw*1.05,.6);P.q(hw*.95,1.1,hw*1.2,1.4);P.l(hw*1.0,1.42);P.q(hw*.7,.8,hw*.8,.2);P.q(hw*.9,-.4,hw*.3,-.8);P.close()});
  if(hs==='meio_coque')hpaint(()=>{P.m(-hw*1.04,-.4);P.q(-hw*1.2,.6,-hw*1.02,1.25);P.l(hw*1.02,1.25);P.q(hw*1.2,.6,hw*1.04,-.4);P.close()});
  if(hs==='mullet_moderno')hpaint(()=>{P.m(-hw*.85,.05);P.q(-hw*.95,.7,-nw*1.2,1.05);P.l(nw*1.2,1.05);P.q(hw*.95,.7,hw*.85,.05);P.close()});
  if(hs==='duas_trancas')for(const s of[-1,1]){const x0=s*hw*.82;hpaint(rope(x0,-.2,1.45,s,.075),{lw:.8});
    if(!sketch)for(let k=0;k<8;k++){const yy=-.05+k*.17;line(()=>{P.m(x0-s*.04,yy);P.q(x0+s*.04,yy+.06,x0+s*.12,yy+.01)},darken(hairC,.5),.016,.8)}}
  if(hs==='coque_baixo')hpaint(()=>P.e(hw*.86,.08,.16,.17));
  if(hs==='dreads_presos'){for(let i=-3;i<=3;i++)hpaint(rope(i*.09,topY-.18,.22,i<0?-1:1,.04),{lw:.6})}
  if(hs==='ombro')hpaint(()=>{P.m(-hw*1.05,-.45);P.q(-hw*1.22,.3,-hw*1.06,.95);P.l(hw*1.06,.95);P.q(hw*1.22,.3,hw*1.05,-.45);P.close()});
  if(hs==='ondulado_medio')hpaint(()=>{P.m(-hw*1.05,-.45);P.q(-hw*1.3,-.05,-hw*1.08,.2);P.q(-hw*.95,.45,-hw*1.12,.62);P.l(hw*1.12,.62);P.q(hw*.95,.45,hw*1.08,.2);P.q(hw*1.3,-.05,hw*1.05,-.45);P.close()});
  if(hs==='cachos_volumosos'){hpaint(()=>P.e(0,-.5,hw*1.22,.72));if(!sketch){const r=rngOf(f.seed||1);for(let i=0;i<26;i++){const a=Math.PI*.85+i/25*Math.PI*1.3;hpaint(()=>P.e(Math.cos(a)*hw*1.2,-.5+Math.sin(a)*.7,.11+r()*.04,.1+r()*.04),{lw:.6})}}}
  if(hs==='afro_puff'){hpaint(()=>P.e(0,topY-.32,.52,.42));if(!sketch){const r=rngOf(f.seed||1);for(let i=0;i<18;i++){const a=r()*Math.PI*2;hpaint(()=>P.e(Math.cos(a)*.45,topY-.32+Math.sin(a)*.36,.1,.09),{stroke:false})}}}
  if(hs==='rabo_alto')hpaint(()=>{P.m(hw*.2,-1.0);P.q(hw*1.1,-.9,hw*1.08,.1);P.q(hw*1.02,.7,hw*1.18,1.15);P.l(hw*.98,1.18);P.q(hw*.82,.6,hw*.85,0);P.q(hw*.8,-.75,hw*.05,-.95);P.close()});
  if(hs==='dreads_soltos')for(let i=0;i<9;i++){const a=Math.PI*.95+i/8*Math.PI*1.1,x0=Math.cos(a)*hw*.9,y0=-.27+Math.sin(a)*cr*.9,dx=Math.cos(a)*.75,dy=Math.sin(a)*.5+.45;
    hpaint(()=>{P.m(x0-.05,y0);P.q(x0+dx*.5,y0+dy*.3-.1,x0+dx,y0+dy);P.l(x0+dx+.09,y0+dy+.02);P.q(x0+dx*.5+.1,y0+dy*.3-.05,x0+.05,y0);P.close()},{lw:.6})}
  if(hs==='mullet')hpaint(()=>{P.m(-hw*.95,0);P.q(-hw*1.12,.8,-nw*1.45,1.18);P.l(nw*1.45,1.18);P.q(hw*1.12,.8,hw*.95,0);P.close()});
  // Rodada 5: cortes de atletas atuais (nomes genéricos, Game Design Bible §22).
  const braid=(x0,y0,len,s2,wd)=>{hpaint(rope(x0,y0,len,s2,wd),{lw:.8});if(!sketch)for(let k=0;k<Math.round(len/.17);k++){const yy=y0+.1+k*.17;line(()=>{P.m(x0-s2*wd*.6,yy);P.q(x0+s2*wd*.3,yy+.06,x0+s2*wd*1.6,yy+.01)},darken(hairC,.5),.015,.8)}};
  const bun=(x,y,rx,ry,braided)=>{hpaint(()=>P.e(x,y,rx,ry));if(braided&&!sketch)for(let k=-1;k<=1;k++)line(()=>{P.m(x-rx*.8,y+k*ry*.45);P.q(x,y+k*ry*.45-ry*.3,x+rx*.8,y+k*ry*.45)},darken(hairC,.45),.014,.7)};
  if(hs==='slick_longo')hpaint(()=>{P.m(-hw*1.02,-.45);P.q(-hw*1.14,.3,-hw*.96,.8);P.l(hw*.96,.8);P.q(hw*1.14,.3,hw*1.02,-.45);P.close()});
  if(hs==='freeform'){const r=rngOf((f.seed||1)+41);for(let i=0;i<13;i++){const a=Math.PI*.9+i/12*Math.PI*1.2,x0=Math.cos(a)*hw*.95,y0=-.27+Math.sin(a)*cr*.95,dx=Math.cos(a)*(.22+r()*.14),dy=1.0+r()*.45-Math.sin(a)*.1;
    hpaint(()=>{P.m(x0-.07,y0);P.q(x0+dx*.45,y0+dy*.3-.1,x0+dx,y0+dy);P.l(x0+dx+.12,y0+dy+.02);P.q(x0+dx*.5+.13,y0+dy*.3-.05,x0+.07,y0);P.close()},{lw:.6})}}
  if(hs==='wolf_cut'||hs==='shag'){const L=hs==='shag'?.95:.72;hpaint(()=>{P.m(-hw*1.08,-.45);P.q(-hw*1.3,.1,-hw*1.12,L*.6);P.l(-hw*1.22,L*.75);P.l(-hw*1.0,L*.8);P.l(-hw*1.08,L);P.l(hw*1.08,L);P.l(hw*1.0,L*.8);P.l(hw*1.22,L*.75);P.l(hw*1.12,L*.6);P.q(hw*1.3,.1,hw*1.08,-.45);P.close()})}
  if(hs==='bob'||hs==='long_bob'){const L=hs==='bob'?.55:.95;hpaint(()=>{P.m(-hw*1.08,-.45);P.q(-hw*1.22,.2,-hw*1.12,L);P.q(0,L+.06,hw*1.12,L);P.q(hw*1.22,.2,hw*1.08,-.45);P.close()})}
  if(hs==='franja_reta_longo')hpaint(()=>{P.m(-hw*1.06,-.45);P.q(-hw*1.2,.7,-hw*1.04,1.5);P.l(hw*1.04,1.5);P.q(hw*1.2,.7,hw*1.06,-.45);P.close()});
  if(hs==='rabo_trancado'){hpaint(()=>{P.m(hw*.55,-.85);P.q(hw*1.2,-.45,hw*1.02,.1);P.l(hw*.82,.1);P.q(hw*.9,-.4,hw*.3,-.8);P.close()});braid(hw*.94,0,1.35,1,.075)}
  if(hs==='nago_longas')for(const s2 of[-1,1])for(let i=0;i<3;i++)braid(s2*(hw*.72+i*.08),-.2,1.5+i*.08,s2,.045);
  if(hs==='trancas_boxeadora')for(const s2 of[-1,1])braid(s2*hw*.74,-.15,1.55,s2,.06);
  if(hs==='viking_trancado')braid(hw*.35,-.6,1.4,1,.065);
  if(hs==='samurai')bun(0,topY-.1,.16,.13,false);
  if(hs==='undercut_coque')bun(0,topY-.06,.2,.15,false);
  if(hs==='coque_trancado')bun(0,topY-.12,.28,.21,true);
  if(hs==='coques_duplos')for(const s2 of[-1,1])bun(s2*hw*.62,topY+.02,.2,.17,false);

  /* ---------- pescoço, ombros, tatuagens do corpo ---------- */
  const tr=1.35+build*.35;
  const body=()=>{P.m(-nw,.4);P.l(nw,.4);P.q(nw*.92,.98,nw*1.35,1.13);P.q(tr*.8,1.3,tr,1.5);P.q(tr+.35,1.6,tr+.45,1.95);
    P.l(tr+.6,3);P.l(-tr-.6,3);P.l(-tr-.45,1.95);P.q(-tr-.35,1.6,-tr,1.5);P.q(-tr*.8,1.3,-nw*1.35,1.13);P.q(-nw*.92,.98,-nw,.4);P.close()};
  const tc=sketch?INK:mix(skin,'#1d2b30',dk?.55:.75);
  if(!opts.noBody){
  paint(body,skin);
  if(st.realistic){ctx.save();P.begin();body();ctx.clip();studioTorso(ctx,S,ox,oy-.35*S,skin,tr,1,.15,f.body?.muscle??.6,fem,f.seed||1);ctx.restore()}
  shadeIn(body,()=>P.e(0,chinY+.06,jw*.85,.2),deep,.45);
  shadeIn(body,()=>{P.m(nw*.4,.4);P.l(3,.4);P.l(3,1.25);P.l(nw*.9,1.18);P.close()},shade,.35);
  for(const s of[-1,1])line(()=>{P.m(s*.22,1.36);P.q(s*.7,1.28,s*(tr-.1),1.44)},shade,.03,.7);
  if(!fem)line(()=>{P.m(-.02,1.75);P.q(-.5,1.95,-1.05,1.82);P.m(.02,1.75);P.q(.5,1.95,1.05,1.82)},shade,.025,.5);
  if(marks.has('shoulders'))for(const s of[-1,1]){
    line(()=>{P.m(s*(tr-.35),1.4);P.q(s*(tr-.05),1.35,s*(tr+.3),1.75)},tc,.05,.85);
    line(()=>{P.m(s*(tr-.25),1.52);P.q(s*(tr-.02),1.5,s*(tr+.22),1.86)},tc,.03,.85);
    for(let k=0;k<3;k++)line(()=>{P.m(s*(tr-.15+k*.12),1.47+k*.03);P.l(s*(tr-.08+k*.12),1.62+k*.04)},tc,.022,.85);
  }
  if(marks.has('chest')&&!fem){line(()=>{P.m(-.45,1.62);P.q(0,1.52,.45,1.62)},tc,.035,.85);line(()=>{P.m(-.3,1.7);P.q(-.05,1.66,.05,1.71);P.q(.2,1.76,.3,1.69)},tc,.022,.8)}
  if(fem){
    const top=()=>{P.m(-tr-.6,2.0);P.l(-1.05,1.72);P.q(0,1.9,1.05,1.72);P.l(tr+.6,2.0);P.l(tr+.6,3);P.l(-tr-.6,3);P.close()};
    paint(top,'#2E3942',{ink:'#141a1f'});
    for(const s of[-1,1])line(()=>{P.m(s*.98,1.74);P.l(s*.78,1.18)},'#2E3942',.08,1);
  }
  }else if(!opts.skipNeck){
    const neck=()=>{P.m(-nw,.4);P.l(nw,.4);P.l(nw*1.12,1.4);P.l(-nw*1.12,1.4);P.close()};
    paint(neck,skin,{stroke:false});for(const s2 of[-1,1])line(()=>{P.m(s2*nw,.45);P.l(s2*nw*1.1,1.25)},darken(skin,.62),.02,sketch?1:(st.outline?1:0));shadeIn(neck,()=>P.e(0,chinY+.06,jw*.85,.2),deep,.45);shadeIn(neck,()=>{P.m(nw*.4,.4);P.l(3,.4);P.l(3,1.5);P.l(nw*.9,1.5);P.close()},shade,.35);
  }
  if(hs==='tranca_unica'){const br=()=>{P.m(hw*.55,.1);P.q(hw*1.05,.8,hw*.95,1.7);P.l(hw*.78,1.72);P.q(hw*.85,.8,hw*.35,.2);P.close()};hpaint(br,{lw:.8});
    if(!sketch)for(let k=0;k<9;k++){const yy=.3+k*.15,xx=hw*(.62+k*.035);line(()=>{P.m(xx-.06,yy);P.q(xx,yy+.06,xx+.07,yy)},darken(hairC,.5),.016,.8)}}
  if(marks.has('neck')){
    line(()=>{P.m(-nw*.95,.7);P.q(-nw*.3,.8,-nw*.7,1.0);P.q(-nw*1.1,1.1,-nw*.55,1.22)},tc,.028,.85);
    line(()=>{P.m(-nw*.85,.86);P.q(-nw*.55,.9,-nw*.62,.98)},tc,.022,.85);
  }

  /* ---------- orelhas ---------- */
  const E0=EARS[f.ears.shape]||EARS.normal, cauli=f.ears.cauli||0;
  for(const s of[-1,1]){
    const ex0=s*(hw+.03+(E0.out||0));
    paint(()=>P.e(ex0,0,E0.rx+.02*cauli,E0.ry+.015*cauli),skin);
    if(cauli>0)paint(()=>{P.e(ex0+s*.05,-.07,.045*cauli,.05*cauli);P.e(ex0+s*.03,.07,.035*cauli,.04*cauli)},mix(skin,dk?'#6a3a3a':'#b56a6a',.18),{lw:.6});
    line(()=>{P.m(ex0-s*.01,-.12);P.q(ex0+s*.08,-.02,ex0+s*.01,.1)},deep,.022,.7);
    if(marks.has('argola'))line(()=>{P.e(ex0+s*.01,E0.ry-.01,.035,.04,0,Math.PI*2)},'#c9c4b8',.014,1);
    if(marks.has('brinco'))paint(()=>P.e(ex0+s*.01,E0.ry-.03,.018,.018),'#e8e3d6',{lw:.5});
  }

  /* ---------- cabeça ---------- */
  paint(head,skin,{lw:1.1});
  if(st.realistic){ctx.save();P.begin();head();ctx.clip();studioFacePlanes(ctx,S,ox,oy,skin,g,f.seed||1,A.wrinkle);ctx.restore()}
  shadeIn(head,()=>{P.m(.1,-1.2);P.q(.52,-.35,.2,.28);P.q(.06,.7,.08,1.2);P.l(1.3,1.2);P.l(1.3,-1.2);P.close()},shade,.42);
  for(const s of[-1,1])shadeIn(head,()=>P.e(s*.55,.3,.2,.1),shade,s>0?.35:.18);
  if(!sketch)shadeIn(head,()=>P.e(-.22,-.58,.24,.12),light,.4);
  if(st.facets){
    shadeIn(head,()=>{P.m(jw*.95,.45);P.l(cw,chinY);P.l(.02,chinY-.12);P.l(.3,.5);P.close()},deep,.25);
    shadeIn(head,()=>{P.m(-hw,-.3);P.l(-.35,-.05);P.l(-.45,.3);P.l(-jw,.55);P.close()},light,.22);
    shadeIn(head,()=>{P.m(-.2,-.95);P.l(.25,-.95);P.l(.1,-.35);P.l(-.3,-.4);P.close()},light,.25);
  }

  /* ---------- sardas, pintas, idade ---------- */
  const fr=marks.has('sardas')?1:marks.has('sardas_leves')?.4:0;
  if(fr>0){const r=rngOf((f.seed||1)*13);ctx.save();ctx.fillStyle=sketch?INK:darken(skin,.32);
    for(let i=0;i<Math.round(70*fr);i++){const s=r()<.5?-1:1,x=s*(.08+r()*.42),y=.08+r()*.3+Math.abs(x)*.1;ctx.globalAlpha=.35+r()*.35;
      ctx.beginPath();ctx.arc(ox+x*S,oy+y*S,Math.max(.6,S*(.008+r()*.008)),0,Math.PI*2);ctx.fill()}ctx.restore()}
  const moleC=sketch?INK:darken(skin,dk?.45:.55);
  if(marks.has('pinta_bochecha'))paint(()=>P.e(-.42,.36,.018,.018),moleC,{stroke:false});
  if(marks.has('pinta_queixo'))paint(()=>P.e(.12,chinY-.1,.016,.016),moleC,{stroke:false});
  if(marks.has('pinta_labio'))paint(()=>P.e(.2,.52,.014,.014),moleC,{stroke:false});
  const NZ=NOSES[f.nose.shape]||NOSES.reto, MO=MOUTHS[f.mouth.shape]||MOUTHS.neutra;
  if(A.wrinkle>0){const wa=A.wrinkle*.75;
    for(const s of[-1,1]){
      line(()=>{P.m(s*(NZ.nw+.06),.37);P.q(s*(NZ.nw+.16),.5,s*(MO.w+.06),.68)},deep,.018,wa);
      line(()=>{P.m(s*.44,.04);P.l(s*.52,0);P.m(s*.44,.08);P.l(s*.52,.1)},deep,.012,wa);
      line(()=>{P.m(s*.2,.15);P.q(s*.3,.2,s*.41,.14)},deep,.013,wa*.8);
    }
    line(()=>{P.m(-.3,-.45);P.q(0,-.49,.3,-.45)},deep,.013,wa*.8);
    if(A.wrinkle>.5)line(()=>{P.m(-.26,-.37);P.q(0,-.41,.26,-.37)},deep,.012,wa*.7);
  }

  /* ---------- barba ---------- */
  const bs=f.beard.style||'nenhuma';
  if(bs!=='nenhuma'&&!fem){
    const full=(len=.15,top=.02)=>()=>{P.m(-hw*.97,top);P.q(-hw*1.01,.42,-jw-.03,.6);P.q(-cw-.14-len*.3,chinY+len,0,chinY+len+.01);P.q(cw+.14+len*.3,chinY+len,jw+.03,.6);
      P.q(hw*1.01,.42,hw*.97,top);P.q(.6,.4,.3,.46);P.l(.2,.49);P.q(0,.44,-.2,.49);P.l(-.3,.46);P.q(-.6,.4,-hw*.97,top);P.close()};
    const must=()=>{P.m(-.26,.58);P.q(-.2,.47,0,.49);P.q(.2,.47,.26,.58);P.q(.13,.53,0,.545);P.q(-.13,.53,-.26,.58);P.close()};
    const pencil=()=>{P.m(-.2,.555);P.q(0,.5,.2,.555);P.q(0,.535,-.2,.555);P.close()};
    const chinPatch=(wd=.2)=>()=>{P.m(-wd,.66);P.q(0,.64,wd,.66);P.q(wd,chinY+.1,0,chinY+.11);P.q(-wd,chinY+.1,-wd,.66);P.close()};
    const noMust=()=>{P.m(-hw*.97,.02);P.q(-hw*1.01,.42,-jw-.03,.6);P.q(-cw-.16,chinY+.15,0,chinY+.16);P.q(cw+.16,chinY+.15,jw+.03,.6);P.q(hw*1.01,.42,hw*.97,.02);
      P.q(.55,.55,.26,.7);P.q(0,.74,-.26,.7);P.q(-.55,.55,-hw*.97,.02);P.close()};
    const chops=s=>()=>{P.m(s*hw*.97,.0);P.q(s*hw*1.0,.45,s*(jw-.02),.62);P.q(s*.4,.66,s*.3,.62);P.q(s*.45,.35,s*hw*.8,.0);P.close()};
    const strap=()=>{P.m(-hw*.97,.02);P.q(-hw*1.01,.42,-jw-.03,.6);P.q(-cw-.14,chinY+.1,0,chinY+.11);P.q(cw+.14,chinY+.1,jw+.03,.6);P.q(hw*1.01,.42,hw*.97,.02);
      P.l(hw*.88,.02);P.q(hw*.9,.4,jw-.06,.58);P.q(cw,chinY,0,chinY-.02);P.q(-cw,chinY,-jw+.06,.58);P.q(-hw*.9,.4,-hw*.88,.02);P.close()};
    const bp=(fn,o={})=>{paint(fn,st.realistic?studioGradient(ctx,beardC,ox,oy,hw*S):beardC,{ink:darken(beardC,.5),lw:.8,...o});if(st.realistic)studioHair(ctx,()=>{P.begin();fn()},beardC,f.seed||1,S,ox,oy,true,o.alpha??1,bs)};
    const stubble=(fn,a)=>{if(st.realistic){paint(fn,beardC,{alpha:a*.1,stroke:false});studioHair(ctx,()=>{P.begin();fn()},beardC,f.seed||1,S,ox,oy,true,a*2.8,'stubble')}else if(sketch){ctx.save();P.begin();fn();ctx.clip();ctx.fillStyle=INK;const r=rngOf(f.seed||1);for(let i=0;i<Math.round(300*a);i++){ctx.globalAlpha=.5;ctx.fillRect(ox+(r()-.5)*2*hw*S,oy+(r()*.9+.1)*S,1.2,1.2)}ctx.restore()}else bp(fn,{alpha:a,stroke:false})};
    switch(bs){
      case'sombra':stubble(full(),.17);break;
      case'por_fazer':stubble(full(),.32);break;
      case'cheia_curta':bp(full(.15));break;
      case'cheia_longa':bp(full(.42));break;
      case'sem_bigode':bp(noMust);break;
      case'cavanhaque':bp(chinPatch(.17));break;
      case'cavanhaque_bigode':bp(()=>{P.m(-.24,.52);P.q(0,.45,.24,.52);P.l(.22,.64);P.q(.2,chinY+.1,0,chinY+.11);P.q(-.2,chinY+.1,-.22,.64);P.close()});break;
      case'ancora':bp(must);bp(()=>{P.m(-.24,.7);P.q(0,.76,.24,.7);P.q(.12,chinY+.12,0,chinY+.14);P.q(-.12,chinY+.12,-.24,.7);P.close()});break;
      case'bigode':bp(must);break;
      case'bigode_fino':bp(pencil,{lw:.5});break;
      case'ferradura':bp(must);for(const s of[-1,1])bp(()=>{P.m(s*.2,.53);P.l(s*.27,.55);P.l(s*.27,chinY-.02);P.l(s*.19,chinY-.02);P.close()});break;
      case'costeletas':for(const s of[-1,1])bp(chops(s));break;
      case'contorno':bp(strap);break;
      case'desenhada':bp(()=>{P.m(-hw*.97,.0);P.q(-hw*1.01,.42,-jw-.03,.6);P.q(-cw-.14,chinY+.12,0,chinY+.13);P.q(cw+.14,chinY+.12,jw+.03,.6);P.q(hw*1.01,.42,hw*.97,0);
        P.l(hw*.9,0);P.l(.34,.43);P.l(.2,.49);P.q(0,.44,-.2,.49);P.l(-.34,.43);P.l(-hw*.9,0);P.close()});break;
      case'longa_sem_bigode':bp(()=>{P.m(-hw*.97,.02);P.q(-hw*1.01,.42,-jw-.03,.6);P.q(-cw-.25,chinY+.5,0,chinY+.55);P.q(cw+.25,chinY+.5,jw+.03,.6);P.q(hw*1.01,.42,hw*.97,.02);
        P.q(.55,.55,.26,.7);P.q(0,.74,-.26,.7);P.q(-.55,.55,-hw*.97,.02);P.close()});break;
      case'bigode_grosso':bp(()=>{P.m(-.31,.61);P.q(-.25,.43,0,.455);P.q(.25,.43,.31,.61);P.q(.15,.545,0,.56);P.q(-.15,.545,-.31,.61);P.close()});break;
      case'cavanhaque_longo':bp(()=>{P.m(-.24,.52);P.q(0,.45,.24,.52);P.l(.22,.64);P.q(.2,chinY+.1,.05,chinY+.35);P.l(-.05,chinY+.35);P.q(-.2,chinY+.1,-.22,.64);P.close()});break;
      case'cheia_media':bp(full(.28));break;
      case'lenhador':bp(full(.36,-.02));if(st.realistic)bp(full(.36,-.02),{alpha:.35});break;
      case'viking_trancada':bp(full(.3));for(const s2 of[-1,1]){const x0=s2*.13;bp(()=>{P.m(x0-.1,chinY+.2);P.q(x0-.08+s2*.03,chinY+.55,x0-.045,chinY+.82);P.l(x0+.045,chinY+.82);P.q(x0+.08+s2*.03,chinY+.55,x0+.1,chinY+.2);P.close()},{lw:.6});bp(()=>P.e(x0,chinY+.85,.05,.04),{lw:.5})}break;
      case'van_dyke':bp(must);bp(()=>{P.m(-.2,.68);P.q(0,.72,.2,.68);P.q(.14,chinY+.12,0,chinY+.3);P.q(-.14,chinY+.12,-.2,.68);P.close()});break;
      case'balbo':bp(()=>{P.m(-.28,.55);P.q(-.2,.46,0,.48);P.q(.2,.46,.28,.55);P.q(.14,.53,0,.54);P.q(-.14,.53,-.28,.55);P.close()});bp(()=>{P.m(-.34,.66);P.q(0,.7,.34,.66);P.q(.3,chinY+.12,0,chinY+.15);P.q(-.3,chinY+.12,-.34,.66);P.close()});break;
      case'garibaldi':bp(()=>{P.m(-hw*.97,.02);P.q(-hw*1.08,.42,-jw-.06,.62);P.q(-cw-.34,chinY+.36,0,chinY+.42);P.q(cw+.34,chinY+.36,jw+.06,.62);P.q(hw*1.08,.42,hw*.97,.02);P.q(.6,.4,.3,.46);P.l(.2,.49);P.q(0,.44,-.2,.49);P.l(-.3,.46);P.q(-.6,.4,-hw*.97,.02);P.close()});break;
      case'bigode_guidao':bp(()=>{P.m(-.2,.55);P.q(0,.46,.2,.55);P.q(.34,.6,.42,.5);P.q(.46,.44,.42,.4);P.q(.46,.5,.36,.57);P.q(.2,.6,0,.56);P.q(-.2,.6,-.36,.57);P.q(-.46,.5,-.42,.4);P.q(-.46,.44,-.42,.5);P.q(-.34,.6,-.2,.55);P.close()},{lw:.6});break;
      case'chevron':bp(()=>{P.m(-.3,.6);P.q(-.25,.44,0,.45);P.q(.25,.44,.3,.6);P.q(.12,.55,0,.56);P.q(-.12,.55,-.3,.6);P.close()});break;
      case'fu_manchu':bp(must);for(const s2 of[-1,1])bp(()=>{P.m(s2*.22,.55);P.l(s2*.28,.56);P.q(s2*.3,.9,s2*.26,chinY+.4);P.l(s2*.2,chinY+.4);P.q(s2*.24,.9,s2*.22,.55);P.close()},{lw:.5});break;
      case'barba_degrade':stubble(full(.05),.3);bp(()=>{P.m(-.5,.45);P.q(-.55,.62,-jw+.05,.64);P.q(-cw-.1,chinY+.13,0,chinY+.14);P.q(cw+.1,chinY+.13,jw-.05,.64);P.q(.55,.62,.5,.45);P.q(.3,.46,0,.44);P.q(-.3,.46,-.5,.45);P.close()});break;
      case'falhada':stubble(full(.1),.26);bp(chinPatch(.14),{alpha:.7});bp(must,{alpha:.55});break;
      case'ducktail':bp(()=>{P.m(-hw*.97,.02);P.q(-hw*1.01,.42,-jw-.03,.6);P.q(-cw-.1,chinY+.2,0,chinY+.48);P.q(cw+.1,chinY+.2,jw+.03,.6);P.q(hw*1.01,.42,hw*.97,.02);P.q(.6,.4,.3,.46);P.l(.2,.49);P.q(0,.44,-.2,.49);P.l(-.3,.46);P.q(-.6,.4,-hw*.97,.02);P.close()});break;
      case'costeletas_bigode':for(const s2 of[-1,1])bp(chops(s2));bp(must);break;
      case'contorno_bigode':bp(strap);bp(must);break;
      case'mosca':bp(()=>{P.m(-.05,.68);P.q(0,.66,.05,.68);P.l(.035,.78);P.q(0,.8,-.035,.78);P.close()},{lw:.5});break;
    }
  }

  /* ---------- cabelo: frente ---------- */
  if(hs!=='raspado'){
    const rec=A.recede, hl=-.56+rec*.28, cyc=hl-rec*.18+.02;
    const volBy={maquina:0,degrade_baixo:.02,degrade_alto:.02,militar:.03,curto:.06,risca:.06,topete:.05,para_tras:.03,franja:.07,nago:.01,box_braids:.02,coque:.02,coque_masc:.02,rabo:.02,longo_liso:.05,longo_ondulado:.06,cacheado_longo:.1,mullet:.05,afro_curto:.12,black_power:.2,twists:.06,dreads_curtos:.05,dreads_longos:.05,cacheado_curto:.05,moicano:0,fauxhawk:.02,coroa:.02,quiff:.02,franja_longa:.04,cogumelo:.05,ombro:.05,ondulado_medio:.06,cachos_volumosos:.14,dreads_soltos:.04,twists_altos:.02,afro_puff:.01,rabo_alto:.01,coque_baguncado:.02,curto_lateral:.05,volumoso:.12,trancas_laterais:.03,undercut:.02,mullet_moderno:.03,crop_frances:.02,espetado:.04,degrade_risca:.02,high_top:.02,moicano_cacheado:0,dreads_presos:.04,meio_coque:.03,duas_trancas:.02,tranca_unica:.02,coque_baixo:.02,pixie:.05,undercut_lateral:.04,waves_360:0,caesar:.02,flat_top:.02,maquina_desenho:0,afro_degrade:.02,cachos_degrade:.02,slick_longo:.03,samurai:.02,undercut_coque:.02,nago_zigue:.01,freeform:.08,franja_cortina:.05,wolf_cut:.08,calvo_lateral:.02,viking_trancado:.02,espinhos:.04,trancas_boxeadora:.01,bob:.06,long_bob:.06,shag:.08,coque_trancado:.02,rabo_trancado:.02,bantu_knots:.01,nago_longas:.01,franja_reta_longo:.05,coques_duplos:.03};
    const vol=volBy[hs]??.05;
    const sb=hs==='maquina'||hs.startsWith('degrade')||['undercut','mullet_moderno','crop_frances','high_top','moicano_cacheado','espetado','quiff','twists_altos','waves_360','caesar','flat_top','maquina_desenho','afro_degrade','cachos_degrade','samurai','undercut_coque','viking_trancado','espinhos'].includes(hs)?-.05:.08;
    const fringe=hs==='franja';
    const cap=(hly=hl)=>()=>{P.m(-hw*1.3,sb);P.l(-hw*.95,sb);P.q(-hw*.9,-.3,-hw*.72,-.38);
      if(fringe){P.q(-.5,-.3,-.3,-.28);P.l(-.18,-.34);P.l(-.08,-.27);P.l(.05,-.33);P.l(.18,-.27);P.l(.32,-.31);P.q(.5,-.3,hw*.72,-.38)}
      else{P.q(-.5,cyc,-.34,cyc);P.q(-.12,hly-.03,0,hly);P.q(.12,hly-.03,.34,cyc);P.q(.5,cyc,hw*.72,-.38)}
      P.q(hw*.9,-.3,hw*.95,sb);P.l(hw*1.3,sb);P.l(hw*1.3,-2.2);P.l(-hw*1.3,-2.2);P.close()};
    const topOnly=(y)=>()=>{P.m(-2,y);P.l(2,y);P.l(2,-2.5);P.l(-2,-2.5);P.close()};
    ctx.save();P.begin();cranium(vol);ctx.clip();
    const sides=a=>{if(sketch){ctx.save();P.begin();cap()();ctx.clip();hatch(a*.8,-.6);ctx.restore()}else{paint(cap(),hairFill,{alpha:a,stroke:false});if(st.realistic)studioHair(ctx,()=>{P.begin();cap()()},hairC,f.seed||1,S,ox,oy,false,a,f.hair.style)}};
    const solidTop=y=>{ctx.save();
      if(st.realistic){P.begin();cap()();ctx.clip();const fade=ctx.createLinearGradient(0,oy+(y-.13)*S,0,oy+(y+.27)*S);const rgb=h2r(hairC).join(',');fade.addColorStop(0,`rgba(${rgb},1)`);fade.addColorStop(.45,`rgba(${rgb},.8)`);fade.addColorStop(1,`rgba(${rgb},0)`);ctx.fillStyle=fade;ctx.fillRect(ox-hw*S*1.4,oy-2*S,hw*S*2.8,3*S);studioHair(ctx,()=>{P.begin();topOnly(y+.16)()},hairC,f.seed||1,S,ox,oy,false,.9,f.hair.style)}
      else{P.begin();topOnly(y)();ctx.clip();hpaint(cap(),{stroke:false});if(sketch){P.begin();cap()();ctx.clip();hatch(.55,-.6)}}ctx.restore()};
    switch(hs){
      case'maquina':sides(.72);break;
      case'degrade_baixo':sides(.5);solidTop(-.55);break;
      case'degrade_alto':sides(.14);solidTop(-.68);break;
      case'militar':sides(.5);solidTop(-.6);break;
      case'moicano':sides(.1);break;
      case'fauxhawk':sides(.35);break;
      case'undercut':sides(.12);break;
      case'quiff':sides(.35);solidTop(-.6);break;
      case'twists_altos':sides(.12);break;
      case'mullet_moderno':sides(.22);solidTop(-.6);break;
      case'crop_frances':sides(.3);solidTop(-.55);break;
      case'espetado':sides(.45);solidTop(-.55);break;
      case'degrade_risca':sides(.14);solidTop(-.68);break;
      case'high_top':sides(.1);break;
      case'moicano_cacheado':sides(.12);break;
      case'waves_360':sides(.82);break;
      case'caesar':sides(.5);solidTop(-.62);break;
      case'flat_top':sides(.18);break;
      case'maquina_desenho':sides(.66);break;
      case'afro_degrade':case'cachos_degrade':sides(.14);break;
      case'samurai':case'undercut_coque':sides(.12);break;
      case'viking_trancado':sides(.08);break;
      case'espinhos':sides(.45);solidTop(-.58);break;
      case'calvo_lateral':ctx.save();P.begin();P.m(-2,-.48);P.l(-hw*.66,-.48);P.l(-hw*.66,1);P.l(-2,1);P.close();P.m(2,-.48);P.l(hw*.66,-.48);P.l(hw*.66,1);P.l(2,1);P.close();ctx.clip();hpaint(cap(-.1),{stroke:false});ctx.restore();break;
      case'undercut_lateral':{ctx.save();P.begin();P.m(-hw*.42,-3);P.l(3,-3);P.l(3,3);P.l(-hw*.42,3);P.close();ctx.clip();hpaint(cap(),{stroke:false});ctx.restore();
        ctx.save();P.begin();P.m(-hw*.42,-3);P.l(-3,-3);P.l(-3,3);P.l(-hw*.42,3);P.close();ctx.clip();sides(.14);ctx.restore();break}
      case'coroa':ctx.save();P.begin();P.m(-2,-.55+rec*.1);P.l(-hw*.6,-.55+rec*.1);P.l(-hw*.6,1);P.l(-2,1);P.close();P.m(2,-.55+rec*.1);P.l(hw*.6,-.55+rec*.1);P.l(hw*.6,1);P.l(2,1);P.close();ctx.clip();hpaint(cap(-.2),{stroke:false});ctx.restore();break;
      default:
        hpaint(cap());
        if(sketch){P.begin();cap()();ctx.clip();hatch(.5,-.6)}
    }
    ctx.restore();
    // detalhes por estilo (fora do clip quando sobem acima do crânio)
    const hl2=lighten(hairC,.2);
    if(hs==='nago'||hs==='box_braids')for(let i=-3;i<=3;i++)line(()=>{P.m(i*.14,hl+.02);P.q(i*.2,-.85,i*.12,topY-.02)},hl2,.02,.8);
    if(hs==='curto')for(let i=-2;i<=2;i++)hpaint(()=>{P.m(i*.14-.07,hl-.02);P.l(i*.14,hl+.07);P.l(i*.14+.07,hl-.02);P.close()},{stroke:false});
    if(hs==='cacheado_curto'){const r=rngOf(f.seed||1);for(let i=0;i<26;i++){const a=Math.PI*1.08+r()*Math.PI*.84,rr=.85+r()*.2;hpaint(()=>P.e(Math.cos(a)*hw*rr,-.27+Math.sin(a)*cr*rr,.075,.075),{lw:.6})}}
    if(hs==='twists')for(let i=-4;i<=4;i++){const x=i*.13;hpaint(()=>{P.m(x-.045,topY+.25);P.l(x-.05,topY-.08+Math.abs(i)*.03);P.q(x,topY-.14+Math.abs(i)*.03,x+.05,topY-.08+Math.abs(i)*.03);P.l(x+.045,topY+.25);P.close()},{lw:.6})}
    if(hs==='risca'){line(()=>{P.m(-.32,hl+.04);P.q(-.36,-.8,-.3,topY+.05)},lighten(skin,.1),.02,.9);hpaint(()=>{P.m(-.3,topY+.05);P.q(.3,topY-.12,hw*.9,-.62);P.q(.3,-.8,-.3,-.72);P.close()},{stroke:false})}
    if(hs==='topete')hpaint(()=>{P.m(-hw*.8,-.6);P.q(-hw*.7,topY-.28,0,topY-.3);P.q(hw*.75,topY-.26,hw*.82,-.6);P.q(0,-.45,-hw*.8,-.6);P.close()});
    if(hs==='undercut'||hs==='mullet_moderno')hpaint(()=>{P.m(-hw*.7,-.5);P.q(-hw*.78,topY-.02,0,topY-.08);P.q(hw*.78,topY-.02,hw*.7,-.5);P.q(0,hl-.04,-hw*.7,-.5);P.close()});
    if(hs==='undercut')for(let i=-2;i<=2;i++)line(()=>{P.m(i*.14,hl+.02);P.q(i*.17,-.9,i*.1,topY-.04)},lighten(hairC,.22),.014,.5);
    if(hs==='mullet_moderno'||hs==='espetado')for(let i=-3;i<=3;i++){const x=i*.12,yb=hs==='espetado'?topY+.06+Math.abs(i)*.04:hl-.02;
      hpaint(()=>{if(hs==='espetado'){P.m(x-.06,yb+.12);P.l(x+i*.03,yb-.16);P.l(x+.06,yb+.12)}else{P.m(x-.06,yb);P.l(x+.01,yb+.09);P.l(x+.06,yb)}P.close()},{stroke:false})}
    if(hs==='crop_frances'){hpaint(()=>{P.m(-.42,-.6);P.l(.42,-.6);P.l(.4,-.37);P.l(-.4,-.37);P.close()},{stroke:false});for(let i=-3;i<=3;i++)line(()=>{P.m(i*.11,-.39);P.l(i*.11+.02,-.46)},darken(hairC,.35),.014,.8)}
    if(hs==='degrade_risca')line(()=>{P.m(-hw*.82,-.58);P.q(-hw*.6,-.72,-hw*.25,-.8)},lighten(skin,.1),.022,1);
    if(hs==='high_top')hpaint(()=>{P.m(-hw*.72,-.55);P.l(-hw*.78,topY-.34);P.l(hw*.78,topY-.34);P.l(hw*.72,-.55);P.q(0,hl-.02,-hw*.72,-.55);P.close()});
    if(hs==='moicano_cacheado'){const r=rngOf(f.seed||1);for(let i=0;i<16;i++){const t=i/15,y=hl-.02+(topY-.12-hl)*t;hpaint(()=>P.e((r()-.5)*.22,y+(r()-.5)*.05,.085,.075),{lw:.6})}}
    if(hs==='dreads_presos'){hpaint(()=>P.e(0,topY-.2,.3,.17));for(let i=-2;i<=2;i++)line(()=>{P.m(i*.16,hl+.02);P.q(i*.18,-.85,i*.08,topY-.05)},darken(hairC,.4),.02,.7)}
    if(hs==='meio_coque'){hpaint(()=>P.e(0,topY-.03,.17,.12));line(()=>{P.m(0,hl);P.l(0,topY+.02)},lighten(skin,.1),.018,.8)}
    if(hs==='duas_trancas')for(const s of[-1,1]){for(let k=0;k<6;k++){const t=k/5,x=s*(.14+t*.2),y=hl+.02+(topY+.08-hl)*t;hpaint(()=>P.e(x,y,.085,.06),{lw:.6})}}
    if(hs==='tranca_unica'||hs==='coque_baixo')for(let i=-2;i<=2;i++)line(()=>{P.m(i*.16,hl+.03);P.q(i*.2,-.9,i*.1+.1,topY+.05)},lighten(hairC,.2),.015,.45);
    if(hs==='pixie')hpaint(()=>{P.m(-hw*.85,-.28);P.q(-.3,-.5,.42,-.42);P.q(.1,-.66,-hw*.8,-.62);P.close()});
    if(hs==='undercut_lateral')hpaint(()=>{P.m(-hw*.42,-.62);P.q(.1,topY-.1,hw*.85,-.4);P.q(.3,-.55,-hw*.42,-.62);P.close()});
    if(hs==='quiff'){hpaint(()=>{P.m(-hw*.72,-.5);P.q(-hw*.62,topY-.16,.12,topY-.2);P.q(hw*.78,topY-.1,hw*.72,-.5);P.q(0,hl-.08,-hw*.72,-.5);P.close()});
      for(let i=-2;i<=2;i++)line(()=>{P.m(i*.15-.05,hl);P.q(i*.15,topY,i*.15+.12,topY-.12)},lighten(hairC,.22),.015,.5)}
    if(hs==='franja_longa')hpaint(()=>{P.m(-hw*1.0,.02);P.l(-hw*.97,-.55);P.q(-hw*.82,topY-.06,0,topY-.08);P.q(hw*.82,topY-.06,hw*.97,-.55);P.l(hw*1.0,.02);
      P.l(hw*.82,-.06);P.l(hw*.72,-.26);P.l(.46,-.17);P.l(.31,-.28);P.l(.16,-.18);P.l(0,-.3);P.l(-.16,-.18);P.l(-.31,-.27);P.l(-.46,-.17);P.l(-hw*.72,-.26);P.l(-hw*.82,-.06);P.close()});
    if(hs==='cogumelo')hpaint(()=>{P.m(-hw*1.06,-.04);P.q(-hw*1.14,topY-.12,0,topY-.12);P.q(hw*1.14,topY-.12,hw*1.06,-.04);P.q(hw*.92,-.2,.5,-.25);P.q(0,-.29,-.5,-.25);P.q(-hw*.92,-.2,-hw*1.06,-.04);P.close()});
    if(hs==='ombro'||hs==='ondulado_medio'){line(()=>{P.m(0,hl);P.l(0,topY+.02)},lighten(skin,.1),.018,.8);
      for(const s2 of[-1,1])hpaint(()=>{P.m(s2*.02,hl-.02);P.q(s2*hw*.85,hl-.02,s2*hw*1.03,.35);P.l(s2*hw*.9,.38);P.q(s2*hw*.78,-.1,s2*.02,hl+.06);P.close()},{stroke:false})}
    if(hs==='cachos_volumosos'||hs==='volumoso'){const r=rngOf((f.seed||1)+7);for(let i=0;i<9;i++){const x=-.5+i*.125,y=hl+.03+r()*.05;
      if(hs==='volumoso')hpaint(()=>{P.m(x-.08,y-.14);P.l(x+(r()-.5)*.1,y+.1);P.l(x+.08,y-.14);P.close()},{stroke:false});else hpaint(()=>P.e(x,y,.085,.075),{lw:.6})}
      if(hs==='volumoso')for(let i=0;i<9;i++){const a=Math.PI*1.08+i/8*Math.PI*.84;hpaint(()=>{P.m(Math.cos(a-.12)*hw*1.08,-.27+Math.sin(a-.12)*cr*1.08);P.l(Math.cos(a)*hw*1.32,-.27+Math.sin(a)*cr*1.3);P.l(Math.cos(a+.12)*hw*1.08,-.27+Math.sin(a+.12)*cr*1.08);P.close()},{stroke:false})}}
    if(hs==='twists_altos'){hpaint(()=>{P.m(-hw*.62,-.55);P.l(-hw*.68,topY-.3);P.q(0,topY-.37,hw*.68,topY-.3);P.l(hw*.62,-.55);P.q(0,hl-.04,-hw*.62,-.55);P.close()});
      for(let i=-4;i<=4;i++)line(()=>{P.m(i*.1,hl);P.l(i*.1+.01,topY-.3)},lighten(hairC,.25),.018,.55)}
    if(hs==='coque_baguncado'){hpaint(()=>P.e(0,topY-.16,.3,.24));const r=rngOf(f.seed||1);for(let i=0;i<7;i++){const a=Math.PI*(1.1+r()*.8);hpaint(()=>P.e(Math.cos(a)*.3,topY-.16+Math.sin(a)*.24,.08,.07),{lw:.5})}
      for(const s2 of[-1,1])line(()=>{P.m(s2*hw*.7,-.4);P.q(s2*hw*.95,.0,s2*hw*.85,.3)},hairC,.03,.9)}
    if(hs==='rabo_alto'){hpaint(()=>P.e(0,topY-.01,.2,.1));for(let i=-2;i<=2;i++)line(()=>{P.m(i*.16,hl+.03);P.q(i*.18,-.9,i*.05,topY+.03)},lighten(hairC,.22),.015,.45)}
    if(hs==='afro_puff')for(let i=-2;i<=2;i++)line(()=>{P.m(i*.16,hl+.03);P.q(i*.18,-.9,i*.05,topY+.03)},lighten(hairC,.22),.015,.45);
    if(hs==='curto_lateral')hpaint(()=>{P.m(hw*.85,-.3);P.q(.2,-.52,-.45,-.4);P.q(-.1,-.7,hw*.8,-.62);P.close()});
    if(hs==='trancas_laterais'){for(const s2 of[-1,1])for(let k=0;k<3;k++)line(()=>{P.m(s2*(hw*.55+k*.1),hl+.08+k*.1);P.q(s2*(hw*.62+k*.1),-.8,s2*(.3+k*.08),topY+.1)},lighten(hairC,.22),.02,.8);
      const r=rngOf(f.seed||1);for(let i=0;i<10;i++)hpaint(()=>P.e((r()-.5)*.5,topY+.05-r()*.12,.1,.09),{lw:.5})}
    if(hs==='dreads_soltos')for(let i=-3;i<=3;i++)hpaint(()=>{const x=i*.13;P.m(x-.05,hl+.02);P.q(x+i*.05,-.2,x+i*.08,.02);P.l(x+i*.08+.08,.02);P.q(x+i*.05+.06,-.25,x+.05,hl+.02);P.close()},{lw:.5});
    if(hs==='waves_360'&&!sketch)for(let k=0;k<5;k++)line(()=>{const y=hl+.02-k*.13;P.m(-hw*.72,y+.08);for(let i=0;i<6;i++){const x=-hw*.72+(i+.5)*hw*1.44/6;P.q(x,y-.05*(i%2?1:-1),x+hw*.12,y)}},darken(hairC,.5),.014,.55);
    if(hs==='caesar')hpaint(()=>{P.m(-.5,-.62);P.l(.5,-.62);P.l(.48,hl+.06);P.l(-.48,hl+.06);P.close()},{stroke:false});
    if(hs==='flat_top')hpaint(()=>{P.m(-hw*.84,-.55);P.l(-hw*.88,topY-.12);P.l(hw*.88,topY-.12);P.l(hw*.84,-.55);P.q(0,hl-.04,-hw*.84,-.55);P.close()});
    if(hs==='maquina_desenho')for(const s2 of[-1,1])line(()=>{P.m(s2*hw*.97,-.52);P.l(s2*hw*.76,-.66);P.l(s2*hw*.9,-.8);P.m(s2*hw*.99,-.36);P.q(s2*hw*.82,-.44,s2*hw*.7,-.6)},lighten(skin,.12),.02,.9);
    if(hs==='afro_degrade'){hpaint(()=>{P.m(-hw*.84,-.5);P.q(-hw*1.0,topY-.26,0,topY-.3);P.q(hw*1.0,topY-.26,hw*.84,-.5);P.q(0,hl-.05,-hw*.84,-.5);P.close()});
      if(!sketch)for(let i=0;i<11;i++){const a=Math.PI*1.12+i/10*Math.PI*.76;hpaint(()=>P.e(Math.cos(a)*hw*.9,-.62+Math.sin(a)*(cr*.78+.02),.08,.07),{stroke:false})}}
    if(hs==='cachos_degrade'){const r=rngOf((f.seed||1)+5);for(let i=0;i<26;i++){const a=Math.PI*1.12+(i%13)/12*Math.PI*.76+(r()-.5)*.08,rr=i<13?.9+r()*.06:.62+r()*.1;hpaint(()=>P.e(Math.cos(a)*hw*rr,-.27+Math.sin(a)*cr*rr*1.02,.085,.075),{lw:.6})}}
    if(hs==='samurai'||hs==='undercut_coque'||hs==='slick_longo'){hpaint(()=>{P.m(-hw*.72,-.48);P.q(-hw*.76,topY-.02,0,topY-.06);P.q(hw*.76,topY-.02,hw*.72,-.48);P.q(0,hl-.04,-hw*.72,-.48);P.close()});
      for(let i=-2;i<=2;i++)line(()=>{P.m(i*.15,hl+.02);P.q(i*.17,-.9,i*.05,topY-.02)},lighten(hairC,.22),.014,.5)}
    if(hs==='nago_zigue')for(let i=-3;i<=3;i++)line(()=>{P.m(i*.14,hl+.02);for(let k=1;k<=5;k++)P.l(i*.13+(k%2?.045:-.045),hl+.02+(topY+.1-hl)*k/5)},lighten(hairC,.2),.02,.8);
    if(hs==='franja_cortina'){line(()=>{P.m(0,hl-.02);P.l(0,topY+.04)},lighten(skin,.1),.018,.8);
      for(const s2 of[-1,1])hpaint(()=>{P.m(s2*.02,hl-.04);P.q(s2*.3,hl+.05,s2*.42,-.18);P.q(s2*hw*.8,-.1,s2*hw*.95,.05);P.l(s2*hw*.98,-.4);P.q(s2*hw*.5,hl-.1,s2*.02,hl-.04);P.close()},{stroke:false})}
    if(hs==='wolf_cut'||hs==='shag')hpaint(()=>{P.m(-hw*.95,-.05);P.l(-hw*.85,-.3);P.l(-.5,-.22);P.l(-.36,-.36);P.l(-.2,-.24);P.l(-.05,-.38);P.l(.1,-.25);P.l(.26,-.37);P.l(.42,-.22);P.l(.58,-.33);P.l(hw*.85,-.28);P.l(hw*.95,-.05);P.l(hw*.95,-.6);P.q(0,topY-.1,-hw*.95,-.6);P.close()},{stroke:false});
    if(hs==='bob'||hs==='long_bob'){line(()=>{P.m(-.25,hl-.01);P.q(-.28,-.85,-.22,topY+.05)},lighten(skin,.1),.018,.8);hpaint(()=>{P.m(-.24,hl-.02);P.q(.3,hl+.02,hw*.95,-.1);P.l(hw*1.0,-.62);P.q(.3,topY-.02,-.24,hl-.02);P.close()},{stroke:false})}
    if(hs==='franja_reta_longo')hpaint(()=>{P.m(-hw*.92,-.2);P.l(-hw*.92,-.62);P.q(0,topY-.1,hw*.92,-.62);P.l(hw*.92,-.2);P.l(-hw*.92,-.2);P.close()},{stroke:false});
    if(hs==='viking_trancado'){hpaint(()=>{P.m(-.24,hl);P.q(-.28,topY+.02,0,topY-.02);P.q(.28,topY+.02,.24,hl);P.close()});for(let k=0;k<6;k++){const y=hl-.02+(topY+.06-hl)*k/6;line(()=>{P.m(-.14,y);P.q(0,y-.07,.14,y)},darken(hairC,.45),.016,.8)}}
    if(hs==='espinhos')for(let i=-4;i<=4;i++){const x=i*.1,yb=topY+.08+Math.abs(i)*.03;hpaint(()=>{P.m(x-.05,yb+.1);P.l(x+i*.015,yb-.1);P.l(x+.05,yb+.1);P.close()},{stroke:false})}
    if(hs==='trancas_boxeadora')for(const s2 of[-1,1])for(let k=0;k<7;k++){const t=k/6,x=s2*(.12+t*.24),y=hl+.02+(topY+.1-hl)*t;hpaint(()=>P.e(x,y,.07,.05),{lw:.5})}
    if(hs==='coque_trancado'||hs==='rabo_trancado'||hs==='nago_longas')for(let i=-3;i<=3;i++)line(()=>{P.m(i*.13,hl+.03);P.q(i*.17,-.9,i*.07,topY+.05)},lighten(hairC,.22),.017,.6);
    if(hs==='bantu_knots'){const pts=[[-.36,-.62],[0,-.72],[.36,-.62],[-.2,topY+.05],[.2,topY+.05]];for(const[x,y]of pts){hpaint(()=>P.e(x,y-.08,.13,.11));line(()=>{P.m(x-.09,y-.08);P.q(x,y-.18,x+.09,y-.08)},darken(hairC,.45),.014,.7)}
      for(let i=-2;i<=2;i++)line(()=>{P.m(i*.18,hl+.02);P.l(i*.19,-.66)},lighten(skin,.1),.012,.7)}
    if(hs==='coques_duplos')line(()=>{P.m(0,hl);P.l(0,topY+.02)},lighten(skin,.1),.018,.8);
    if(hs==='moicano')hpaint(()=>{P.m(-.16,hl);P.l(-.2,topY-.3);P.q(0,topY-.4,.2,topY-.3);P.l(.16,hl);P.close()});
    if(hs==='fauxhawk')hpaint(()=>{P.m(-.36,hl);P.q(-.3,topY-.1,0,topY-.24);P.q(.3,topY-.1,.36,hl);P.close()});
    if(hs==='coque_masc'||hs==='para_tras'||hs==='rabo')for(let i=-2;i<=2;i++)line(()=>{P.m(i*.18,hl+.03);P.q(i*.2,-.9,i*.1,topY+.04)},hl2,.015,.45);
    if(hs==='longo_liso'||hs==='longo_ondulado')line(()=>{P.m(0,hl);P.l(0,topY+.02)},lighten(skin,.1),.018,.8);
    if(!sketch&&['curto','franja','afro_curto','black_power','longo_liso','longo_ondulado','cacheado_longo','mullet','topete','risca','coque','coque_masc','rabo','para_tras'].includes(hs))
      line(()=>{P.m(-.1,hl+.02);P.q(.2,-.82,.45,-.97)},lighten(hairC,.28),.024,.4);
  }else if(!sketch){shadeIn(head,()=>P.e(0,-.75,hw*.8,.35),light,.22)}

  /* ---------- sobrancelhas e olhos ---------- */
  const EY=EYES[f.eyes.shape]||EYES.amendoado, BR=BROWS[f.brows.shape]||BROWS.reta;
  const ey=.02, ex=.3, ew=EY.w, eh=EY.h, tilt=EY.tilt;
  const browC=mix(beardBase,hairC,.5);
  for(const s of[-1,1]){
    const by=-.13+(BR.low||0),t=BR.t*(fem?.8:1),ar=BR.arch;
    const scarGap=(s<0&&marks.has('brow_l'))||(s>0&&marks.has('brow_r'));
    const brow=()=>{P.m(s*(ex-.15),by+.03);
      if(BR.angular){P.l(s*(ex+.06),by-.05-ar);P.l(s*(ex+.17),by+.02);P.l(s*(ex+.16),by+.02+t*.6);P.l(s*(ex+.06),by-.05-ar+t);P.l(s*(ex-.15),by+.03+t)}
      else{P.q(s*ex,by-.05-ar,s*(ex+.17),by+.01);P.l(s*(ex+.16),by+.01+t*.7);P.q(s*ex,by-.02-ar+t,s*(ex-.15),by+.03+t)}
      P.close()};
    paint(brow,browC,{stroke:sketch,ink:darken(browC,.4),alpha:st.realistic?.65:1});
    if(st.realistic){ctx.save();P.begin();brow();ctx.clip();const brng=rngOf((f.seed||1)*379+(s+1));ctx.lineWidth=S*.0035;
      for(let i=0;i<180;i++){const x=s*(ex-.15+brng()*.32),y=by-.06-ar+brng()*(t+ar+.12);ctx.strokeStyle=brng()<.22?lighten(browC,.2):darken(browC,.28);ctx.globalAlpha=.3+brng()*.5;P.begin();P.m(x,y);P.q(x+s*.009,y-.015,x+s*.022,y-.026-brng()*.02);ctx.stroke()}ctx.restore()}
    if(BR.bushy&&!sketch)for(let k=0;k<6;k++){const x=s*(ex-.12+k*.05);line(()=>{P.m(x,by+.03+t*.8);P.l(x+s*.03,by-.03)},browC,.012,.8)}
    if(scarGap)line(()=>{P.m(s*(ex+.07),by-.06);P.l(s*(ex+.05),by+.09)},skin,.03,1);
    if(EY.deep)shadeIn(head,()=>P.e(s*ex,ey-eh*1.6,ew*1.3,eh*1.5),deep,.35);
    const oc=ey-tilt;
    const eye=()=>{P.m(s*(ex-ew),ey);P.q(s*ex,ey-eh*(EY.mono?.85:1.05),s*(ex+ew),oc);P.q(s*ex,ey+eh*.72,s*(ex-ew),ey);P.close()};
    paint(eye,mix('#efe8de',skin,.25),{stroke:false});
    ctx.save();P.begin();eye();ctx.clip();
    const ir=IRIS[f.eyes.iris]?.[0]||IRIS.escuro[0];
    paint(()=>P.e(s*ex+s*.005,ey-tilt*.3,.047,.047),ir,{stroke:false});
    if(st.realistic){const ix=ox+(s*ex+s*.005)*S,iy=oy+(ey-tilt*.3)*S;
      studioSoft(ctx,ix-S*.009,iy+S*.014,S*.04,S*.036,lighten(ir,.4),.65);
      ctx.save();ctx.strokeStyle=lighten(ir,.25);ctx.globalAlpha=.5;ctx.lineWidth=Math.max(.25,S*.002);
      for(let k=0;k<18;k++){const a=k*Math.PI/9;ctx.beginPath();ctx.moveTo(ix+Math.cos(a)*S*.025,iy+Math.sin(a)*S*.025);ctx.lineTo(ix+Math.cos(a)*S*.042,iy+Math.sin(a)*S*.042);ctx.stroke()}ctx.restore()}
    paint(()=>P.e(s*ex+s*.005,ey-tilt*.3,.022,.022),'#0e0908',{stroke:false});
    if(!sketch)paint(()=>P.e(s*ex+s*.016,ey-.017,.011,.011),'#ffffff',{stroke:false,alpha:.8});
    shadeIn(eye,()=>P.e(s*ex,ey-eh,ew*1.2,eh*.55),'#1a110c',.18);
    ctx.restore();
    line(()=>{P.m(s*(ex-ew),ey);P.q(s*ex,ey-eh*(EY.mono?.85:1.05),s*(ex+ew),oc)},'#1a110c',fem||EY.mono?.025:.02,1);
    if(fem)line(()=>{P.m(s*(ex+ew),oc);P.l(s*(ex+ew+.035),oc-.028)},'#1a110c',.02,1);
    if(EY.crease)line(()=>{P.m(s*(ex-ew*.7),ey-eh*1.25);P.q(s*ex,ey-eh*2.0,s*(ex+ew*.95),oc-eh*1.05)},shade,.014,.55);
    if(EY.mono)line(()=>{P.m(s*(ex-ew),ey+.004);P.q(s*(ex-ew*.8),ey-eh*.6,s*(ex-ew*.4),ey-eh*.85)},shade,.012,.5);
    if(EY.hood)paint(()=>{P.m(s*(ex-ew*.3),ey-eh*1.35);P.q(s*(ex+ew*.6),ey-eh*1.7,s*(ex+ew*1.18),oc-eh*.05);P.q(s*(ex+ew*.45),ey-eh*.95,s*(ex-ew*.3),ey-eh*1.35);P.close()},mix(skin,shade,.35),{stroke:false});
    line(()=>{P.m(s*(ex-ew*.8),ey+eh*.55);P.q(s*ex,ey+eh*.95,s*(ex+ew*.85),oc+eh*.4)},shade,.012,.35+A.wrinkle*.4);
  }

  /* ---------- nariz ---------- */
  const nwd=NZ.nw*(fem?.9:1), by=.05+NZ.len, bw=NZ.bw, br=(f.nose.broken||0)*.08+(NZ.flat?.03:0), fl=NZ.flare||0, bump=NZ.bump||0, tip=NZ.tip||0;
  shadeIn(head,()=>{P.m(bw,-.02);P.l(bw+br+bump,by*.45);P.l(nwd+fl+.02,by-.03);P.l(.02,by);P.close()},shade,.4);
  line(()=>{P.m(bw,-.02);P.q(bw+bump*2.2+br*1.2,by*.38,bw+br+bump*.6,by*.5);P.q(nwd*.85,by-.1,nwd+fl*.5,by-.05)},deep,.02,st.realistic?.22:.75);
  if(NZ.flat)line(()=>{P.m(-bw*1.1,.02);P.q(-bw*1.4,by*.4,-nwd*.8,by-.08)},deep,.016,.4);
  paint(()=>{P.m(-nwd-fl,by-.06);P.q(-nwd-fl-.05,by+.02,-nwd*.45,by+.025);P.q(0,by+.05+tip,nwd*.45,by+.025);P.q(nwd+fl+.05,by+.02,nwd+fl,by-.06);P.q(0,by-.04,-nwd-fl,by-.06);P.close()},mix(skin,shade,.3),{lw:.7});
  for(const s of[-1,1])line(()=>{P.m(s*(nwd*.55),by-.1);P.q(s*(nwd+fl+.04),by-.08,s*(nwd+fl),by)},deep,.016,st.realistic?.23:.55);
  for(const s of[-1,1])paint(()=>P.e(s*nwd*.46,by+.005,NZ.up?.04:.034,NZ.up?.028:.017),deep,{stroke:false,alpha:.85});
  if(!sketch)shadeIn(head,()=>P.e(0,by-.045,.055*(NZ.round||1),.04*(NZ.round||1)),light,.35);

  /* ---------- boca ---------- */
  const mw=MO.w*(fem?.95:1), up=MO.up*(fem?1.15:1), lo=MO.lo*(fem?1.12:1), my=.6+(f.head.chin||0)*.01, cv=MO.curve||0, sm=MO.smirk||0, bow=MO.bow||.01;
  const cyL=my-cv, cyR=my-cv-sm;
  paint(()=>{P.m(-mw,cyL);P.q(-mw*.6,my-up*.5,-mw*.3,my-up);P.q(-mw*.12,my-up,0,my-up+bow);P.q(mw*.12,my-up,mw*.3,my-up);P.q(mw*.6,my-up*.5,mw,cyR);P.q(0,my+.012,-mw,cyL);P.close()},mix(lipC,shade,.25),{stroke:false,alpha:.92});
  paint(()=>{P.m(-mw*.8,my+.012);P.q(0,my+lo*1.9,mw*.8,my+.012-sm*.5);P.q(0,my+.022,-mw*.8,my+.012);P.close()},lipC,{stroke:false,alpha:.78});
  if(!sketch)shadeIn(head,()=>P.e(0,my+lo*.9,mw*.35,lo*.35),light,.18);
  line(()=>{P.m(-mw,cyL);P.q(0,my+.022,mw,cyR)},darken(lipC,.55),.022,1);
  line(()=>{P.m(-.08,my+.15+lo*.4);P.q(0,my+.165+lo*.4,.08,my+.15+lo*.4)},shade,.02,st.realistic?.25:.5);

  /* ---------- cicatrizes e tatuagem de rosto ---------- */
  const scarC=sketch?INK:mix(skin,dk?'#b88a7e':'#f2c7bd',.55);
  const scar=(fn)=>line(fn,scarC,.022,.95);
  if(marks.has('brow_l'))scar(()=>{P.m(-.38,-.24);P.l(-.29,-.07)});
  if(marks.has('brow_r'))scar(()=>{P.m(.38,-.24);P.l(.29,-.07)});
  if(marks.has('cheek_l'))scar(()=>{P.m(-.44,.18);P.l(-.56,.36)});
  if(marks.has('cheek_r'))scar(()=>{P.m(.44,.18);P.l(.56,.36)});
  if(marks.has('lip'))scar(()=>{P.m(.08,my-.09);P.l(.11,my+.06)});
  if(marks.has('nose'))scar(()=>{P.m(-.06,.08);P.l(.07,.12)});
  if(marks.has('chin'))scar(()=>{P.m(-.08,chinY-.05);P.q(0,chinY-.02,.09,chinY-.06)});
  if(marks.has('temple')){for(let k=0;k<3;k++)line(()=>{P.m(-hw*.86+k*.035,-.4+k*.07);P.l(-hw*.72+k*.02,-.36+k*.07)},tc,.018,.85)}

  /* ---------- pós-luta ---------- */
  if(opts.post){
    const pr=rngOf((f.seed||1)*3),side=pr()>.5?1:-1;
    shadeIn(head,()=>P.e(side*.32,.13,.17,.09),'#6c2f4f',dk?.5:.38);
    shadeIn(head,()=>P.e(side*.36,.1,.1,.06),'#b04257',.3);
    shadeIn(head,()=>P.e(-side*.5,.34,.13,.09),'#6c3a55',dk?.36:.28);
    line(()=>{P.m(-side*.27,-.23);P.l(-side*.4,-.19)},'#9e1f26',.03,1);
    if(!sketch)for(const k of[-1,1])line(()=>{P.m(-side*(.335+k*.045),-.26);P.l(-side*(.335+k*.045),-.15)},'#f1ece2',.018,.9);
    if(f.nose.broken>.3)shadeIn(head,()=>P.e(.02,.2,.06,.12),'#8a3346',.25);
  }
}

/* ================= corpo inteiro e poses ================= */
const SHORTS={preto:['#1c1f23','Preto'],vermelho:['#9e2a2b','Vermelho'],azul:['#1f3f73','Azul'],branco:['#e9e6df','Branco'],verde:['#1f5a3a','Verde'],dourado:['#a9853f','Dourado'],roxo:['#4a2f6b','Roxo'],camuflado:['#4b5a3a','Camuflado']};
const GLOVES={preto:['#151719','Preta'],vermelho:['#8e1f22','Vermelha'],azul:['#1d3a6b','Azul'],branco:['#e9e6df','Branca']};
const POSES={
 oficial:{n:'Media day',belt:0},guarda:{n:'Guarda de luta',belt:0},bracos_cruzados:{n:'Braços cruzados',belt:0},vitoria:{n:'Vitória',belt:0},
 cinturao_peito:{n:'Cinturão no peito',belt:1},cinturao_ombro:{n:'Cinturão no ombro',belt:1},cinturao_erguido:{n:'Cinturão erguido',belt:1},cinturao_cintura:{n:'Cinturão na cintura',belt:1},
};
function drawFigure(ctx,W,H,f,st,opts){
  if(st.realistic)return drawStudioFigure(ctx,W,H,f,st,opts);
  const pose=opts.pose||'oficial', high=pose==='vitoria'||pose==='cinturao_erguido';
  const B=f.body||{muscle:.6,fat:.2,hair:0,height:.5};
  const m=B.muscle??.6, fat=B.fat??.2, legK=.95+(B.height??.5)*.1;
  const S=H/((high?12.3:11.0)+(legK-1)*8), ox=W/2, oy=H*(high?.2:.12);
  const rng=rngOf((f.seed||1)*5), P=makePen(ctx,S,ox,oy,st.pen,rng);
  const sketch=st.mode==='sketch', INK=PAL.ink, contrast=st.contrast||1, fem=f.sex==='f', build=f.build??.5;
  const skin=SKIN[f.skin]?.[0]||SKIN.t06[0], dk=lum(skin)<.42;
  const shade=darken(skin,dk?.32:.26), deep=darken(skin,dk?.52:.47), light=lighten(skin,dk?.16:.22), outlineC=darken(skin,.62);
  const kit=f.kit||{shorts:'preto',gloves:'preto'};
  const shortsC=SHORTS[kit.shorts]?.[0]||'#1c1f23', gloveC=GLOVES[kit.gloves]?.[0]||'#151719';
  const bodyHairC=HAIR_COLORS[f.beard?.color||(['multicolor','bicolor','pontas_claras','platinado','prata'].includes(f.hair?.color)||String(f.hair?.color).startsWith('tingido')?'castanho_escuro':f.hair?.color)]?.[0]||'#17110e';
  const marks=new Set(f.marks||[]), tc=sketch?INK:mix(skin,'#1d2b30',dk?.55:.75);
  const def=clamp(m*1.25-fat*1.7,0,1)*(fem?.7:1);
  const sh=(fem?1.16:1.3)+build*.5+m*.1, nw=.3+.2*build;
  const wa=(fem?.64:.76)+build*.26+fat*.45, hip=wa+(fem?.3:.1)+fat*.05, lat=sh-.24+m*.1-(fem?.08:0);
  const aK=(fem?.84:1)*(.86+build*.36+fat*.12), lK=(fem?1.08:1)*1.3*(.88+build*.3+fat*.1);
  const X=x=>ox+x*S, Y=y=>oy+y*S;
  const add=(a,b)=>[a[0]+b[0],a[1]+b[1]], sub=(a,b)=>[a[0]-b[0],a[1]-b[1]], mul=(a,k)=>[a[0]*k,a[1]*k], nrm=a=>{const l=Math.hypot(a[0],a[1])||1;return[a[0]/l,a[1]/l]};

  function paint(fn,color,o={}){ctx.save();P.begin();fn();
    if(sketch){ctx.globalAlpha=(o.alpha??1)*.3;ctx.fillStyle=color;ctx.fill();if(o.stroke!==false){ctx.globalAlpha=1;ctx.strokeStyle=INK;ctx.lineWidth=S*.028;ctx.lineJoin='round';ctx.stroke()}}
    else{ctx.globalAlpha=o.alpha??1;ctx.fillStyle=color;ctx.fill();if(st.outline&&o.stroke!==false){ctx.globalAlpha=1;ctx.strokeStyle=o.ink||darken(typeof color==='string'?color:'#b88b46',.62);ctx.lineWidth=S*(o.lw||.04);ctx.lineJoin='round';ctx.stroke()}}
    ctx.restore()}
  function shadeIn(clip,fn,color,alpha){if(alpha<=0.01)return;ctx.save();P.begin();clip();ctx.clip();P.begin();fn();
    if(sketch){ctx.clip();ctx.strokeStyle=INK;ctx.globalAlpha=clamp(alpha*1.1,0,1);ctx.lineWidth=Math.max(1,S*.018);ctx.beginPath();for(let x=-W;x<W*2;x+=S*.11){ctx.moveTo(x,0);ctx.lineTo(x+H*.5,H)}ctx.stroke()}
    else{ctx.globalAlpha=clamp(alpha*contrast,0,1);ctx.fillStyle=color;ctx.fill()}ctx.restore()}
  function line(fn,color,lw,alpha=1){if(alpha<=0.02)return;ctx.save();P.begin();fn();ctx.strokeStyle=sketch?INK:color;ctx.globalAlpha=clamp(alpha,0,1);ctx.lineWidth=S*lw;ctx.lineCap='round';ctx.lineJoin='round';ctx.stroke();ctx.restore()}
  function smooth(pts){const n=pts.length,mid=(a,b)=>[(a[0]+b[0])/2,(a[1]+b[1])/2];const m0=mid(pts[n-1],pts[0]);P.m(m0[0],m0[1]);
    for(let i=0;i<n;i++){const p=pts[i],q=pts[(i+1)%n],mm=mid(p,q);P.q(p[0],p[1],mm[0],mm[1])}P.close()}
  function poly(pts){P.m(pts[0][0],pts[0][1]);for(let i=1;i<pts.length;i++)P.l(pts[i][0],pts[i][1]);P.close()}
  function prof(pr,t){for(let i=0;i<pr.length-1;i++)if(t<=pr[i+1][0]){const a=pr[i],b=pr[i+1],k=(t-a[0])/(b[0]-a[0]||1);return[a[1]+(b[1]-a[1])*k,a[2]+(b[2]-a[2])*k]}const l=pr[pr.length-1];return[l[1],l[2]]}
  // membro anatômico: perfil lateral/medial ao longo do osso, sombra do lado direito (luz da esquerda)
  function limb(A,Bp,pr,s,k,capA,capB,extra){
    const d=nrm(sub(Bp,A));let n=[-d[1],d[0]];
    const nOut=Math.abs(n[0])>.25?(Math.sign(n[0])===s?n:mul(n,-1)):(n[1]>0?n:mul(n,-1)), nMed=mul(nOut,-1);
    const N=16,out=[],med=[],cen=[];
    for(let i=0;i<=N;i++){const t=i/N,c=add(A,mul(sub(Bp,A),t)),[wo,wm]=prof(pr,t);out.push(add(c,mul(nOut,wo*k)));med.push(add(c,mul(nMed,wm*k)));cen.push([c,wo*k,wm*k])}
    const pts=[add(A,mul(d,-capA)),...out,add(Bp,mul(d,capB)),...med.slice().reverse()];
    const shape=()=>smooth(pts);
    paint(shape,skin,{ink:outlineC,lw:.035});
    const shadowOut=nOut[0]>0, sideArr=shadowOut?out:med, nS=shadowOut?nOut:nMed, nL=mul(nS,-1);
    const band=[...sideArr,...cen.slice().reverse().map(([c,wo,wm])=>add(c,mul(nS,(shadowOut?wo:wm)*.15)))];
    shadeIn(shape,()=>poly(band),shade,.5);
    const litArr=shadowOut?med:out;
    if(!sketch)line(()=>{const p=litArr.map((q,i)=>add(q,mul(nS,(cen[i][1]+cen[i][2])*.22)));P.m(p[2][0],p[2][1]);for(let i=3;i<p.length-2;i++)P.l(p[i][0],p[i][1])},light,.05,.28);
    if(extra)extra({A,B:Bp,d,nOut,nMed,out,med,cen,shape});
    return shape;
  }
  const UPPER=[[0,.31+.1*m,.23],[.18,.33+.12*m,.21+.04*m],[.45,.23+.06*m+fat*.05,.2+.11*m+fat*.05],[.8,.17+.03*m,.15+.05*m],[1,.14,.13]];
  const FORE=[[0,.15+.03*m,.14],[.25,.19+.06*m,.16+.04*m],[.7,.12,.11],[1,.085,.08]];
  const THIGH=[[0,.37+.08*m+fat*.08,.31+fat*.06],[.3,.38+.1*m+fat*.08,.3+.04*m+fat*.06],[.75,.27+.04*m,.26+.08*m],[1,.23,.22]];
  const SHIN=[[0,.22,.21],[.25,.22+.06*m,.24+.08*m],[.7,.13,.13],[1,.09,.09]];

  function glove(h,e,big=1,s=1){const u=nrm(sub(h,e)),ang=Math.atan2(u[1],u[0])-Math.PI/2;
    ctx.save();ctx.translate(X(h[0]),Y(h[1]));ctx.rotate(ang);ctx.scale(S*big,S*big);
    const rr=(x,y,w,hh,r)=>{ctx.beginPath();ctx.moveTo(x+r,y);ctx.lineTo(x+w-r,y);ctx.quadraticCurveTo(x+w,y,x+w,y+r);ctx.lineTo(x+w,y+hh-r);ctx.quadraticCurveTo(x+w,y+hh,x+w-r,y+hh);ctx.lineTo(x+r,y+hh);ctx.quadraticCurveTo(x,y+hh,x,y+hh-r);ctx.lineTo(x,y+r);ctx.quadraticCurveTo(x,y,x+r,y);ctx.closePath()};
    const inkC=sketch?INK:'#060606', lwid=.035;
    rr(-.19,-.46,.38,.3,.06);ctx.fillStyle=sketch?PAL.paper:(kit.gloves==='branco'?'#1c1f23':'#e6e2d8');ctx.fill();ctx.lineWidth=lwid;ctx.strokeStyle=inkC;ctx.stroke();
    ctx.beginPath();ctx.moveTo(-.19,-.31);ctx.lineTo(.19,-.31);ctx.strokeStyle=sketch?INK:'rgba(0,0,0,.35)';ctx.lineWidth=.02;ctx.stroke();
    for(let i=0;i<4;i++){const x=-.14+i*.093;ctx.beginPath();ctx.ellipse(x,.26,.05,.06,0,0,Math.PI*2);ctx.fillStyle=sketch?PAL.paper:skin;ctx.fill();ctx.lineWidth=.02;ctx.strokeStyle=sketch?INK:outlineC;ctx.stroke()}
    ctx.beginPath();ctx.moveTo(-.23,-.18);ctx.quadraticCurveTo(-.3,.06,-.24,.2);ctx.quadraticCurveTo(0,.3,.24,.2);ctx.quadraticCurveTo(.3,.06,.23,-.18);ctx.closePath();
    const g=sketch?PAL.paper:(()=>{const gg=ctx.createLinearGradient(-.25,0,.25,0);gg.addColorStop(0,lighten(gloveC,.25));gg.addColorStop(1,darken(gloveC,.2));return gg})();
    ctx.fillStyle=g;ctx.fill();ctx.lineWidth=lwid;ctx.strokeStyle=inkC;ctx.stroke();
    ctx.beginPath();ctx.moveTo(-.18,.1);ctx.quadraticCurveTo(0,.18,.18,.1);ctx.strokeStyle=sketch?INK:lighten(gloveC,.4);ctx.lineWidth=.025;ctx.globalAlpha=.7;ctx.stroke();ctx.globalAlpha=1;
    ctx.beginPath();ctx.ellipse(-s*.25,-.02,.07,.12,s*.3,0,Math.PI*2);ctx.fillStyle=sketch?PAL.paper:darken(gloveC,.1);ctx.fill();ctx.lineWidth=.02;ctx.strokeStyle=inkC;ctx.stroke();
    ctx.restore()}
  function plate(cx,cy,w,h,rot=0){
    ctx.save();ctx.translate(X(cx),Y(cy));ctx.rotate(rot);ctx.scale(S,S);
    const rr=(x,y,ww,hh,r)=>{ctx.beginPath();ctx.moveTo(x+r,y);ctx.lineTo(x+ww-r,y);ctx.quadraticCurveTo(x+ww,y,x+ww,y+r);ctx.lineTo(x+ww,y+hh-r);ctx.quadraticCurveTo(x+ww,y+hh,x+ww-r,y+hh);ctx.lineTo(x+r,y+hh);ctx.quadraticCurveTo(x,y+hh,x,y+hh-r);ctx.lineTo(x,y+r);ctx.quadraticCurveTo(x,y,x+r,y);ctx.closePath()};
    const g=ctx.createLinearGradient(-w/2,-h/2,w/2,h/2);g.addColorStop(0,'#f0d48f');g.addColorStop(.35,'#c79a52');g.addColorStop(.6,'#8e6a2e');g.addColorStop(1,'#d6b36c');
    rr(-w/2,-h/2,w,h,.18);ctx.fillStyle=sketch?mix(PAL.paper,'#b88b46',.45):g;ctx.fill();ctx.lineWidth=.05;ctx.strokeStyle=sketch?INK:'#4a3514';ctx.stroke();
    rr(-w/2+.13,-h/2+.13,w-.26,h-.26,.1);ctx.fillStyle=sketch?PAL.paper:'#1b2025';ctx.fill();
    const bw=w*.2,bh=h*.42;ctx.fillStyle=sketch?INK:'#e2c47e';ctx.fillRect(-bw-.07,-bh/2,bw,bh);ctx.fillRect(.07,-bh/2,bw,bh);
    ctx.fillStyle=sketch?INK:'#C83B3B';ctx.fillRect(-.025,-bh/2-.06,.05,bh+.12);
    if(!sketch){ctx.globalAlpha=.45;ctx.fillStyle='#fff6d8';ctx.beginPath();ctx.ellipse(-w*.28,-h*.32,w*.18,h*.05,-.2,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1}
    ctx.fillStyle=sketch?INK:'#e2c07a';for(const[x,y]of[[-w/2+.08,-h/2+.08],[w/2-.08,-h/2+.08],[-w/2+.08,h/2-.08],[w/2-.08,h/2-.08]]){ctx.beginPath();ctx.arc(x,y,.045,0,Math.PI*2);ctx.fill()}
    ctx.restore()}
  function strap(pts,w=.5){
    ctx.save();ctx.lineCap='round';ctx.lineJoin='round';
    const pth=()=>{P.begin();P.m(pts[0][0],pts[0][1]);for(let i=1;i<pts.length;i++)P.l(pts[i][0],pts[i][1])};
    pth();ctx.strokeStyle=sketch?INK:'#060606';ctx.lineWidth=(w+.06)*S;ctx.stroke();
    pth();ctx.strokeStyle=sketch?PAL.paper:'#1c1d1f';ctx.lineWidth=w*S;ctx.stroke();
    if(!sketch){pth();ctx.strokeStyle='#3a3b3e';ctx.lineWidth=w*.25*S;ctx.globalAlpha=.6;ctx.stroke();ctx.globalAlpha=1}
    ctx.restore();
    for(let i=0;i<pts.length-1;i++){const mx=(pts[i][0]+pts[i+1][0])/2,my=(pts[i][1]+pts[i+1][1])/2;paint(()=>P.e(mx,my,w*.36,w*.3),'#c9a05a',{ink:'#4a3514'})}}

  const shA=[-sh+.1,1.64], shB=[sh-.1,1.64];
  const pz={
    oficial:{L:[shA,[-sh-.14,3.05],[-sh-.04,4.3]],R:[shB,[sh+.14,3.05],[sh+.04,4.3]],legs:0},
    guarda:{L:[shA,[-sh+.18,2.6],[-.44,1.22]],R:[shB,[sh-.26,2.48],[.38,.98]],legs:1,front:1},
    bracos_cruzados:{R:[shB,[sh+.06,2.95],[-.62,2.66]],L:[shA,[-sh-.06,2.95],[.62,2.48]],legs:0},
    vitoria:{L:[shA,[-sh-.55,.55],[-sh-.62,-1.15]],R:[shB,[sh+.55,.55],[sh+.62,-1.15]],legs:0},
    cinturao_peito:{L:[shA,[-sh-.06,3.05],[-.74,2.92]],R:[shB,[sh+.06,3.0],[.74,2.72]],legs:0,belt:'peito'},
    cinturao_ombro:{L:[shA,[-sh-.1,3.18],[-.62,3.18]],R:[shB,[sh+.14,3.05],[sh+.04,4.3]],legs:0,belt:'ombro'},
    cinturao_erguido:{L:[shA,[-sh-.42,.45],[-.94,-1.4]],R:[shB,[sh+.42,.45],[.94,-1.4]],legs:0,belt:'alto'},
    cinturao_cintura:{L:[shA,[-sh-.55,2.9],[-wa-.1,3.95]],R:[shB,[sh+.55,2.9],[wa+.1,3.95]],legs:0,belt:'cintura'},
  }[pose];

  /* pernas */
  const sp=pz.legs?1:0, kneeY=4.95+2.0*legK-sp*.15, ankY=4.95+3.6*legK;
  for(const s of[-1,1]){
    const hipJ=[s*(.5+fat*.06),4.95],knee=[s*(.56+sp*.3),kneeY],ank=[s*(.6+sp*.55),ankY];
    limb(knee,ank,SHIN,s,lK,.05,.02,L=>{
      line(()=>{P.m(knee[0]+s*.2,kneeY+.35);P.q(knee[0]+s*.3,kneeY+.8,ank[0]+s*.14,kneeY+1.3)},shade,.028,.35*def+.1);
      line(()=>{P.m(knee[0]-s*.02,kneeY+.25);P.l(ank[0]-s*.01,ankY-.25)},light,.03,.2);
    });
    limb(hipJ,knee,THIGH,s,lK,.1,.05,L=>{
      line(()=>{P.m(hipJ[0]-s*.02,5.35);P.q(hipJ[0]+s*.05,6.1,knee[0]-s*.04,kneeY-.3)},shade,.03,.35*def);
      line(()=>{P.m(knee[0]-s*.2,kneeY-.45);P.q(knee[0]-s*.26,kneeY-.2,knee[0]-s*.12,kneeY-.05)},shade,.03,.4*def);
    });
    paint(()=>P.e(knee[0]+s*.02,kneeY-.04,.12*lK,.1*lK),mix(skin,light,.25),{stroke:false,alpha:.8});
    line(()=>{P.m(knee[0]-.1,kneeY+.07);P.q(knee[0],kneeY+.13,knee[0]+.1,kneeY+.07)},shade,.025,.45);
    const fx=ank[0]+s*.05, fy=ankY;
    const foot=()=>{P.m(fx-.12,fy-.02);P.q(fx-.2-s*.02,fy+.15,fx-.2,fy+.28);P.q(fx+s*.02,fy+.37,fx+.21,fy+.28);P.q(fx+.2,fy+.13,fx+.12,fy-.02);P.close()};
    paint(foot,skin,{ink:outlineC,lw:.03});shadeIn(foot,()=>{P.m(fx,fy-.1);P.l(fx+.4,fy-.1);P.l(fx+.4,fy+.5);P.l(fx,fy+.5);P.close()},shade,.35);
    for(let i=0;i<4;i++)line(()=>{const x=fx-.12+i*.08;P.m(x,fy+.25);P.l(x+.005,fy+.31)},deep,.018,.5);
  }

  /* calção */
  const tO=(.38+.1*m+fat*.08)*lK-.02;
  const shorts=()=>{P.m(-hip-.06,4.2);P.q(0,4.25,hip+.06,4.2);P.q(hip+.2,4.9,.5+tO+.1+sp*.3,5.95);P.l(.14+sp*.1,6.02);P.q(.04,5.5,0,5.3);P.q(-.04,5.5,-.14-sp*.1,6.02);P.l(-.5-tO-.1-sp*.3,5.95);P.q(-hip-.2,4.9,-hip-.06,4.2);P.close()};
  paint(shorts,shortsC,{ink:darken(shortsC,.65)});
  shadeIn(shorts,()=>{P.m(.05,4.1);P.q(.3,5.2,.2,6.2);P.l(3,6.2);P.l(3,4.1);P.close()},darken(shortsC,.45),.35);
  shadeIn(shorts,()=>{P.m(-2,4.15);P.l(2,4.15);P.l(2,4.45);P.l(-2,4.45);P.close()},darken(shortsC,.5),.55);
  for(const s of[-1,1]){
    shadeIn(shorts,()=>{P.m(s*(hip+.02),4.45);P.l(s*(hip+.12),4.45);P.l(s*(.5+tO+.14+sp*.3),6);P.l(s*(.5+tO+sp*.3),6);P.close()},kit.shorts==='branco'?'#1c1f23':'#e9e6df',.55);
    line(()=>{P.m(s*(.5+tO+.02+sp*.3),5.95);P.l(s*(.44+tO+sp*.3),5.62)},darken(shortsC,.6),.03,.8);
    line(()=>{P.m(s*.14,5.9);P.q(s*.25,5.4,s*.18,4.95)},darken(shortsC,.5),.022,.45);
  }
  line(()=>{P.m(-.05,4.34);P.q(-.08,4.5,-.1,4.62);P.m(.05,4.34);P.q(.08,4.5,.1,4.62)},'#e9e6df',.02,.8);

  /* tronco */
  const torso=()=>{P.m(-nw*1.3,1.12);P.q(-sh*.62,1.18-.1*m,-sh+.02,1.52);P.q(-sh-.08,1.95,-sh+.22,2.35);P.q(-lat-.02,2.58,-lat,2.8);
    P.q(-wa-.08+fat*.12,3.3,-wa,3.78);P.q(-wa-.02-fat*.16,4.08,-hip,4.36);P.l(hip,4.36);
    P.q(wa+.02+fat*.16,4.08,wa,3.78);P.q(wa+.08-fat*.12,3.3,lat,2.8);P.q(lat+.02,2.58,sh-.22,2.35);P.q(sh+.08,1.95,sh-.02,1.52);P.q(sh*.62,1.18-.1*m,nw*1.3,1.12);P.close()};
  paint(torso,skin,{ink:outlineC,lw:.035});
  shadeIn(torso,()=>{P.m(.12,1);P.q(.5,2.4,.3,4.45);P.l(3,4.45);P.l(3,1);P.close()},shade,.4);
  shadeIn(torso,()=>P.e(-sh*.42,2.35,.55,.95),light,sketch?0:.22);
  // clavículas e esterno
  for(const s of[-1,1]){line(()=>{P.m(s*.12,1.34);P.q(s*sh*.5,1.24,s*(sh-.22),1.4)},light,.04,.35);line(()=>{P.m(s*.14,1.42);P.q(s*sh*.5,1.34,s*(sh-.25),1.48)},shade,.025,.35)}
  line(()=>{P.m(-.05,1.3);P.q(0,1.36,.05,1.3)},deep,.02,.5);
  if(!fem){
    for(const s of[-1,1]){
      const pec=()=>{P.m(s*.05,1.72);P.q(s*sh*.55,1.56,s*(sh-.26),1.8);P.q(s*(sh-.1),2.2,s*(sh-.34),2.46);P.q(s*sh*.42,2.7+fat*.12,s*.07,2.5);P.close()};
      shadeIn(torso,pec,light,sketch?0:.12+.1*m);
      line(()=>{P.m(s*(sh-.34),2.46);P.q(s*sh*.42,2.72+fat*.12,s*.07,2.52)},deep,.06,.18+.3*m*(1-fat));
      paint(()=>P.e(s*sh*.47,2.28+fat*.08,.05,.04),mix(skin,dk?'#2a1712':'#8a4a3a',.45),{stroke:false,alpha:.7});
      for(let i=0;i<3;i++)line(()=>{const y=2.42+i*.17;P.m(s*(lat-.02),y);P.l(s*(lat-.16),y+.1)},shade,.03,.35*def*m);
    }
    line(()=>{P.m(0,1.75);P.l(0,2.5)},shade,.03,.3*m);
  }
  // abdômen
  line(()=>{P.m(0,2.62);P.l(0,3.95)},shade,.03,.4*def);
  for(const y of[2.86,3.2,3.54])for(const s of[-1,1])line(()=>{P.m(s*.04,y);P.q(s*.18,y+.04,s*.3,y-.02)},shade,.03,.38*def);
  for(const s of[-1,1]){
    line(()=>{P.m(s*.33,2.62);P.q(s*.38,3.3,s*.28,3.98)},shade,.03,.32*def);
    shadeIn(torso,()=>{P.m(s*lat,2.8);P.q(s*(wa+.02),3.3,s*(wa-.02),3.95);P.l(s*(wa-.22),3.9);P.q(s*(lat-.25),3.3,s*(lat-.18),2.8);P.close()},shade,.28*def+.08);
    line(()=>{P.m(s*(wa-.16),3.72);P.q(s*(wa-.3),4.08,s*.2,4.4)},shade,.03,.4*def);
  }
  if(fat>.3)line(()=>{P.m(-wa+.12,3.55);P.q(0,4.25+fat*.25,wa-.12,3.55)},shade,.035,(fat-.3)*.9);
  paint(()=>P.e(0,3.86+fat*.12,.045,.035+fat*.02),deep,{stroke:false,alpha:.7});
  // pelos
  if(!fem&&(B.hair||0)>.15){const r=rngOf((f.seed||1)*29);ctx.save();ctx.strokeStyle=sketch?INK:bodyHairC;ctx.lineWidth=Math.max(.6,S*.013);
    const n=Math.round(260*B.hair);for(let i=0;i<n;i++){let x,y;if(i<n*.7){const a=r()*Math.PI*2,rad=Math.sqrt(r());x=Math.cos(a)*rad*sh*.55;y=2.15+Math.sin(a)*rad*.38}else{x=(r()-.5)*.14;y=3.5+r()*.85}
      ctx.globalAlpha=.25+r()*.35;ctx.beginPath();ctx.moveTo(X(x),Y(y));ctx.quadraticCurveTo(X(x+(r()-.5)*.06),Y(y+.04),X(x+(r()-.5)*.08),Y(y+.07+r()*.04));ctx.stroke()}ctx.restore()}
  if(marks.has('chest')&&!fem){line(()=>{P.m(-.72,2.08);P.q(0,1.88,.72,2.08)},tc,.06,.85);line(()=>{P.m(-.45,2.22);P.q(0,2.16,.45,2.24)},tc,.035,.8)}
  if(fem){
    const top=()=>{P.m(-sh+.2,1.98);P.q(-.55,1.78,-.05,2.1);P.l(.05,2.1);P.q(.55,1.78,sh-.2,1.98);P.q(sh-.08,2.5,lat-.04,2.88);P.q(0,2.98,-lat+.04,2.88);P.q(-sh+.08,2.5,-sh+.2,1.98);P.close()};
    paint(top,'#2E3942',{ink:'#141a1f'});
    shadeIn(top,()=>{P.m(.05,1.8);P.q(.4,2.5,.3,3.1);P.l(3,3.1);P.l(3,1.8);P.close()},'#11161a',.4);
    line(()=>{P.m(-lat+.06,2.7);P.q(0,2.8,lat-.06,2.7)},'#1a2127',.04,.9);
    for(const s of[-1,1]){line(()=>{P.m(s*.5,2.0);P.q(s*.46,1.6,s*.42,1.22)},'#2E3942',.13,1);line(()=>{P.m(s*.08,2.12);P.q(s*.35,2.4,s*(lat-.1),2.62)},'#11161a',.02,.5)}
  }
  if(pz.belt==='cintura'){paint(()=>{P.m(-wa-.12,3.84);P.q(0,4.0,wa+.12,3.84);P.l(wa+.12,4.26);P.q(0,4.42,-wa-.12,4.26);P.close()},'#1c1d1f',{ink:'#050505'});plate(0,4.07,1.35,.88)}

  /* braços */
  const order=pose==='bracos_cruzados'?['R','L']:['L','R'];
  for(const k of order){const a=pz[k],s=k==='L'?-1:1;
    limb(a[1],a[2],FORE,s,aK,.06,.02,L=>{
      line(()=>{const p1=add(L.A,add(mul(L.d,.1),mul(L.nOut,.08))),p2=add(L.A,add(mul(L.d,.7),mul(L.nOut,.02)));P.m(p1[0],p1[1]);P.l(p2[0],p2[1])},shade,.025,.3*def);
      if(marks.has('shoulders')){ctx.save();P.begin();L.shape();ctx.clip();const c=add(L.A,mul(sub(L.B,L.A),.35));line(()=>{const p1=add(c,mul(L.nOut,.3)),p2=add(c,mul(L.nMed,.3));P.m(p1[0],p1[1]);P.l(p2[0],p2[1])},tc,.07,.8);ctx.restore()}
    });
    limb(a[0],a[1],UPPER,s,aK,.22,.04,L=>{
      line(()=>{const p1=add(L.A,add(mul(L.d,.55),mul(L.nMed,.02))),p2=add(L.A,add(mul(L.d,1.1),mul(L.nMed,.08)));P.m(p1[0],p1[1]);P.l(p2[0],p2[1])},shade,.03,.35*def+.1);
      line(()=>{const p1=add(L.A,add(mul(L.d,.1),mul(L.nOut,.18))),p2=add(L.A,add(mul(L.d,.5),mul(L.nOut,.08)));P.m(p1[0],p1[1]);P.l(p2[0],p2[1])},shade,.028,.3*def);
      if(marks.has('shoulders')){ctx.save();P.begin();L.shape();ctx.clip();
        for(let j=0;j<4;j++){const t=.15+j*.2,c=add(L.A,mul(sub(L.B,L.A),t));line(()=>{const p1=add(c,mul(L.nOut,.45)),p2=add(c,mul(L.nMed,.45)),q=add(c,mul(L.d,.14));P.m(p1[0],p1[1]);P.q(q[0],q[1],p2[0],p2[1])},tc,.07-j*.01,.8)}
        ctx.restore()}
    });
  }
  if(pz.belt==='peito'){strap([[0,2.9],[0,4.55]],.52);plate(0,2.42,1.55,1.05)}
  if(pz.belt==='ombro'){strap([[-sh+.45,1.3],[-.6,2.35]],.5);strap([[-.35,3.15],[-.22,4.7]],.5);plate(-.45,2.75,1.4,.95,-.28)}
  if(pz.belt==='alto'){strap([[-.8,-1.7],[-1.1,-.6],[-1.2,.3]],.46);strap([[.8,-1.7],[1.1,-.6],[1.2,.3]],.46);plate(0,-1.72,1.6,1.05)}
  if(!pz.front)for(const k of['L','R'])glove(pz[k][2],pz[k][1],1,k==='L'?-1:1);
  const Sh=S*1.1;drawFace(ctx,W,H,f,st,{...opts,noBody:true,S:Sh,ox,oy:oy+1.3*S-1.4*Sh});
  if(pz.front)for(const k of['L','R'])glove(pz[k][2],pz[k][1],1.12,k==='L'?-1:1);
}

/* ================= estilos ================= */
const STYLES={
  studio:{pen:'smooth',mode:'studio',outline:false,realistic:true,contrast:1},
  flat:{pen:'smooth',mode:'flat',outline:true},
  editorial:{pen:'smooth',mode:'flat',outline:false,contrast:1.35},
  geo:{pen:'geo',mode:'flat',outline:false,facets:true,contrast:1.2},
  sketch:{pen:'sketch',mode:'sketch'},
};
function background(ctx,W,H,id,opts){
  if(id==='studio'){studioBackdrop(ctx,W,H,opts.figure);return}
  if(opts.figure){
    if(id==='flat'){ctx.fillStyle=PAL.surface2;ctx.fillRect(0,0,W,H);ctx.fillStyle='rgba(0,0,0,.28)';ctx.beginPath();ctx.ellipse(W/2,H*.945,W*.36,H*.02,0,0,Math.PI*2);ctx.fill()}
    if(id==='geo'){ctx.fillStyle=PAL.surface;ctx.fillRect(0,0,W,H);ctx.fillStyle=PAL.steel;ctx.globalAlpha=.55;ctx.beginPath();ctx.moveTo(W*.1,H*.95);ctx.lineTo(W*.25,H*.1);ctx.lineTo(W*.92,H*.18);ctx.lineTo(W*.85,H*.97);ctx.closePath();ctx.fill();ctx.globalAlpha=1}
    if(id==='sketch'){ctx.fillStyle=PAL.paper;ctx.fillRect(0,0,W,H);ctx.strokeStyle='rgba(70,83,94,.2)';ctx.lineWidth=1;const gg=W/10;ctx.beginPath();for(let y=gg;y<H;y+=gg){ctx.moveTo(0,y);ctx.lineTo(W,y)}ctx.stroke()}
    if(id==='editorial'){ctx.fillStyle=PAL.paper;ctx.fillRect(0,0,W,H);ctx.save();ctx.translate(W*.5,H*.42);ctx.rotate(-.06);ctx.fillStyle=PAL.red;ctx.fillRect(-W*.4,-H*.36,W*.8,H*.6);ctx.restore()}
    return}
  if(opts.avatar||opts.cy!=null){ctx.fillStyle=id==='sketch'||id==='editorial'?PAL.paper:PAL.surface2;ctx.fillRect(0,0,W,H);return}
  if(id==='flat'){ctx.fillStyle=PAL.surface2;ctx.fillRect(0,0,W,H);ctx.fillStyle='#2A323A';ctx.beginPath();ctx.arc(W*.5,H*.42,W*.44,0,Math.PI*2);ctx.fill()}
  if(id==='geo'){ctx.fillStyle=PAL.surface;ctx.fillRect(0,0,W,H);ctx.fillStyle=PAL.steel;ctx.beginPath();ctx.moveTo(W*.08,H*.9);ctx.lineTo(W*.3,H*.06);ctx.lineTo(W*.95,H*.2);ctx.lineTo(W*.82,H*.95);ctx.closePath();ctx.globalAlpha=.55;ctx.fill();ctx.globalAlpha=1}
  if(id==='sketch'){ctx.fillStyle=PAL.paper;ctx.fillRect(0,0,W,H);ctx.strokeStyle='rgba(70,83,94,.2)';ctx.lineWidth=1;const gg=W/12;ctx.beginPath();for(let y=gg;y<H;y+=gg){ctx.moveTo(0,y);ctx.lineTo(W,y)}ctx.stroke()}
  if(id==='editorial'){ctx.fillStyle=PAL.paper;ctx.fillRect(0,0,W,H);ctx.save();ctx.translate(W*.55,H*.4);ctx.rotate(-.09);ctx.fillStyle=PAL.red;ctx.fillRect(-W*.36,-H*.34,W*.72,H*.56);ctx.restore()}
}
function renderPortrait(cv,f,id,opts={}){
  const dpr=opts.pixelRatio??Math.min(2,window.devicePixelRatio||1);
  const w=opts.width||cv.clientWidth||110,h=opts.height||cv.clientHeight||126;
  cv.width=Math.round(w*dpr);cv.height=Math.round(h*dpr);
  const ctx=cv.getContext('2d'),W=cv.width,H=cv.height;
  ctx.setTransform(1,0,0,1,0,0);background(ctx,W,H,id,opts);
  const st=STYLES[id];
  const draw=(c)=>opts.figure?drawFigure(c,W,H,f,st,opts):drawFace(c,W,H,f,st,opts);
  if(id!=='editorial'){draw(ctx);return}
  const off=document.createElement('canvas');off.width=W;off.height=H;const o=off.getContext('2d');draw(o);
  const d=o.getImageData(0,0,W,H).data, step=Math.max(3,Math.round(W/(opts.avatar?26:opts.figure?48:66))), cells=[];
  for(let y=step/2;y<H;y+=step)for(let x=step/2;x<W;x+=step){const i=(Math.floor(y)*W+Math.floor(x))*4;if(d[i+3]<110)continue;cells.push([x,y,(.299*d[i]+.587*d[i+1]+.114*d[i+2])/255])}
  const ls=cells.map(c=>c[2]).sort((a,b)=>a-b), lo=ls[Math.floor(ls.length*.03)]??0, hi=ls[Math.floor(ls.length*.97)]??1, span=Math.max(.08,hi-lo);
  for(const c of cells)c[2]=clamp((c[2]-lo)/span*.85+.12,0,1);
  ctx.fillStyle=PAL.paper;for(const[x,y]of cells)ctx.fillRect(x-step/2-.5,y-step/2-.5,step+1,step+1);
  ctx.fillStyle='#111417';
  for(const[x,y,l]of cells){const k=clamp(Math.pow(1-l,1.15)*1.35,0,1);if(k>.86){ctx.fillRect(x-step/2,y-step/2,step,step);continue}
    const r=step*.7*Math.sqrt(k);if(r<.4)continue;ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill()}
}

/* ================= tipos de corpo ================= */
// Presets de biotipo (Game Design Bible §5). `classes` = afinidade por faixa de peso
// (leve: mosca–pena, medio: leve–médio, pesado: meio-pesado–pesado). Valores 0–1.
// `gen` = tipo grosso usado por fighter_generation.json (lean/athletic/compact/muscular/heavy).
const BODY_KEYS=['muscle','fat','height','shoulders','reach','legs','waist','hips','legMass','chest','arms','neck','traps','belly'];
const BODY_TYPES={
 esguio:{n:'Esguio',gen:'lean',sex:'m',classes:{leve:3,medio:1.5,pesado:.2},build:.2,body:{muscle:.42,fat:.05,height:.62,shoulders:.32,reach:.62,legs:.6,waist:.35,hips:.45,legMass:.35,chest:.4,arms:.3,neck:.32,traps:.3,belly:0}},
 longilineo:{n:'Longilíneo',gen:'lean',sex:'m',classes:{leve:1.5,medio:2,pesado:1},build:.35,body:{muscle:.55,fat:.07,height:.9,shoulders:.45,reach:.95,legs:.85,waist:.42,hips:.45,legMass:.42,chest:.45,arms:.42,neck:.4,traps:.4,belly:0}},
 cardio_seco:{n:'Seco de cardio',gen:'lean',sex:'m',classes:{leve:2.5,medio:1.5,pesado:.2},build:.3,body:{muscle:.58,fat:.03,height:.4,shoulders:.42,reach:.5,legs:.55,waist:.35,hips:.45,legMass:.45,chest:.45,arms:.42,neck:.42,traps:.4,belly:0}},
 atletico:{n:'Atlético',gen:'athletic',sex:'m',classes:{leve:2,medio:3,pesado:1.5},build:.5,body:{muscle:.66,fat:.1,height:.5,shoulders:.55,reach:.5,legs:.5,waist:.48,hips:.5,legMass:.52,chest:.55,arms:.55,neck:.52,traps:.52,belly:0}},
 definido:{n:'Definido',gen:'athletic',sex:'m',classes:{leve:1.5,medio:2.5,pesado:1},build:.55,body:{muscle:.82,fat:.04,height:.5,shoulders:.62,reach:.5,legs:.5,waist:.42,hips:.48,legMass:.55,chest:.62,arms:.62,neck:.55,traps:.58,belly:0}},
 compacto:{n:'Compacto',gen:'compact',sex:'m',classes:{leve:2,medio:2,pesado:.8},build:.65,body:{muscle:.74,fat:.12,height:.12,shoulders:.62,reach:.3,legs:.3,waist:.55,hips:.55,legMass:.7,chest:.6,arms:.64,neck:.66,traps:.62,belly:0}},
 musculoso:{n:'Musculoso',gen:'muscular',sex:'m',classes:{leve:.5,medio:2,pesado:2.5},build:.72,body:{muscle:.9,fat:.1,height:.55,shoulders:.78,reach:.5,legs:.5,waist:.5,hips:.52,legMass:.65,chest:.75,arms:.78,neck:.7,traps:.75,belly:0}},
 massivo:{n:'Massivo',gen:'muscular',sex:'m',classes:{leve:.1,medio:.8,pesado:3},build:.9,body:{muscle:.96,fat:.16,height:.65,shoulders:.92,reach:.6,legs:.5,waist:.6,hips:.58,legMass:.8,chest:.88,arms:.92,neck:.85,traps:.9,belly:.05}},
 grappler_robusto:{n:'Grappler robusto',gen:'compact',sex:'m',classes:{leve:1,medio:2.5,pesado:2.5},build:.75,body:{muscle:.78,fat:.18,height:.35,shoulders:.66,reach:.4,legs:.42,waist:.62,hips:.6,legMass:.75,chest:.64,arms:.7,neck:.95,traps:.92,belly:.08}},
 pesado_forte:{n:'Pesado forte',gen:'heavy',sex:'m',classes:{leve:0,medio:.4,pesado:3},build:.95,body:{muscle:.72,fat:.35,height:.75,shoulders:.85,reach:.7,legs:.5,waist:.72,hips:.66,legMass:.82,chest:.8,arms:.82,neck:.85,traps:.82,belly:.25}},
 pesado_barriga:{n:'Pesadão de barriga',gen:'heavy',sex:'m',classes:{leve:0,medio:.2,pesado:1.8},build:1,body:{muscle:.58,fat:.62,height:.7,shoulders:.78,reach:.66,legs:.45,waist:.9,hips:.75,legMass:.85,chest:.75,arms:.75,neck:.9,traps:.7,belly:.75}},
 veterano:{n:'Veterano',gen:'athletic',sex:'m',classes:{leve:.8,medio:1.5,pesado:1.5},build:.6,body:{muscle:.58,fat:.28,height:.5,shoulders:.55,reach:.55,legs:.5,waist:.6,hips:.55,legMass:.55,chest:.55,arms:.55,neck:.6,traps:.55,belly:.3}},
 esguia:{n:'Esguia',gen:'lean',sex:'f',classes:{leve:3,medio:1,pesado:.2},build:.15,body:{muscle:.45,fat:.08,height:.55,shoulders:.3,reach:.6,legs:.6,waist:.3,hips:.55,legMass:.5,chest:.35,arms:.3,neck:.3,traps:.25,belly:0}},
 longilinea:{n:'Longilínea',gen:'lean',sex:'f',classes:{leve:1.5,medio:2,pesado:1},build:.3,body:{muscle:.55,fat:.1,height:.9,shoulders:.4,reach:.9,legs:.88,waist:.36,hips:.6,legMass:.55,chest:.45,arms:.4,neck:.35,traps:.3,belly:0}},
 atletica:{n:'Atlética',gen:'athletic',sex:'f',classes:{leve:2.5,medio:3,pesado:1.5},build:.45,body:{muscle:.62,fat:.12,height:.45,shoulders:.42,reach:.5,legs:.5,waist:.4,hips:.64,legMass:.62,chest:.5,arms:.48,neck:.4,traps:.4,belly:0}},
 definida:{n:'Definida',gen:'athletic',sex:'f',classes:{leve:2,medio:2.5,pesado:1},build:.5,body:{muscle:.8,fat:.06,height:.45,shoulders:.5,reach:.5,legs:.5,waist:.35,hips:.6,legMass:.62,chest:.42,arms:.6,neck:.45,traps:.48,belly:0}},
 compacta:{n:'Compacta',gen:'compact',sex:'f',classes:{leve:2.5,medio:1.5,pesado:.5},build:.6,body:{muscle:.72,fat:.12,height:.1,shoulders:.52,reach:.3,legs:.3,waist:.45,hips:.62,legMass:.75,chest:.5,arms:.6,neck:.55,traps:.52,belly:0}},
 forte:{n:'Forte',gen:'muscular',sex:'f',classes:{leve:.8,medio:2,pesado:2.5},build:.72,body:{muscle:.85,fat:.14,height:.55,shoulders:.66,reach:.55,legs:.5,waist:.5,hips:.62,legMass:.75,chest:.55,arms:.72,neck:.62,traps:.66,belly:0}},
 curvilinea:{n:'Curvilínea',gen:'athletic',sex:'f',classes:{leve:1.5,medio:2,pesado:1.5},build:.5,body:{muscle:.55,fat:.24,height:.45,shoulders:.4,reach:.5,legs:.5,waist:.34,hips:.88,legMass:.8,chest:.72,arms:.45,neck:.38,traps:.35,belly:.05}},
 potente:{n:'Potente',gen:'heavy',sex:'f',classes:{leve:.3,medio:1,pesado:2.5},build:.85,body:{muscle:.78,fat:.3,height:.6,shoulders:.72,reach:.6,legs:.5,waist:.62,hips:.72,legMass:.85,chest:.65,arms:.75,neck:.68,traps:.66,belly:.18}},
};
// Aplica o preset com variação individual; nunca muta a entrada.
function applyBodyType(body,typeId,rng,spread=.07){
  const t=BODY_TYPES[typeId]; if(!t)return {...body};
  const out={...body,type:typeId};
  for(const k of BODY_KEYS){const v=t.body[k]??.5;out[k]=+clamp(v+(rng?(rng()-.5)*2*spread:0),0,1).toFixed(2)}
  if(rng==null)out.build=t.build;
  return out;
}
function pickBodyType(r,sex,cls){const w={};for(const[k,t]of Object.entries(BODY_TYPES))if(t.sex===sex)w[k]=cls?(t.classes[cls]??.1):Object.values(t.classes).reduce((a,b)=>a+b,0);return pickW(r,w)}

/* ================= populações ================= */
const POPS={
 africa_ocidental:{n:'África Ocidental',skin:{t12:2,t13:3,t14:3,t15:2},hairC:{preto:1},m:{raspado:3,maquina:3,degrade_alto:3,degrade_baixo:2,twists:2,nago:1,dreads_curtos:1,afro_curto:2,black_power:1},f:{box_braids:3,nago:2,afro_curto:2,coque:1,twists:1},eyes:{amendoado:3,redondo:3,profundo:1,encapuzado:1,grande:1},nose:{largo:4,reto:1,botao:2,achatado:1,carnudo:2},mouth:{carnuda:4,neutra:2,larga:2,inferior:2,arco:1},brows:{reta:2,arqueada:2,grossa:1,baixa:1},beard:{nenhuma:3,sombra:2,por_fazer:2,cavanhaque_bigode:2,cheia_curta:1,contorno:1,cavanhaque:1},iris:{escuro:1},heads:{oval:2,redondo:1,quadrado:2,alongado:1,retangular:1},beardP:.6},
 africa_oriental:{n:'África Oriental',skin:{t10:1,t11:2,t12:3,t13:3,t14:2},hairC:{preto:1},m:{raspado:3,maquina:3,degrade_alto:2,afro_curto:2,twists:1,dreads_curtos:1},f:{box_braids:2,nago:2,afro_curto:2,coque:2},eyes:{amendoado:4,grande:2,redondo:1,encapuzado:1},nose:{reto:3,fino:2,largo:2,botao:1,aquilino:1},mouth:{neutra:3,carnuda:2,larga:1,arco:1},brows:{reta:2,arqueada:2,fina:1},beard:{nenhuma:3,sombra:2,por_fazer:2,cavanhaque_bigode:1,cheia_curta:1},iris:{escuro:3,castanho:1},heads:{alongado:3,oval:3,diamante:1,retangular:1},beardP:.5},
 afro_diaspora:{n:'Afro-brasileiro / afro-americano',skin:{t08:1,t09:2,t10:2,t11:3,t12:3,t13:2,t14:1,t15:1},hairC:{preto:6,castanho_escuro:2,tingido_vermelho:.3,platinado:.3},m:{degrade_alto:3,degrade_baixo:3,maquina:2,raspado:2,twists:2,nago:2,dreads_curtos:1,dreads_longos:1,black_power:1,afro_curto:2,cacheado_curto:1,moicano:.5},f:{box_braids:3,nago:2,black_power:1,afro_curto:1,coque:1,twists:1,cacheado_longo:1,rabo:1},eyes:{amendoado:3,redondo:2,encapuzado:1,grande:1,profundo:1},nose:{largo:3,reto:2,botao:2,carnudo:2,achatado:1},mouth:{carnuda:3,neutra:3,larga:1,inferior:2,arco:1,canto:1},brows:{reta:2,arqueada:2,grossa:1,espessa:.5},beard:{nenhuma:2,sombra:2,por_fazer:2,cavanhaque_bigode:3,cheia_curta:2,contorno:1,bigode:1,ancora:1},iris:{escuro:4,castanho:2,mel:.5},heads:{oval:3,quadrado:2,redondo:1,retangular:1,diamante:1},beardP:.7},
 latino:{n:'Latino-americano',skin:{t04:1,t05:2,t06:3,t07:3,t08:3,t09:2,t10:1},hairC:{preto:4,castanho_escuro:4,castanho:1},m:{curto:3,degrade_baixo:3,militar:2,cacheado_curto:2,risca:1,franja:1,mullet:1,maquina:1,topete:1,para_tras:1},f:{rabo:3,longo_liso:2,longo_ondulado:2,coque:2,nago:1,cacheado_longo:1},eyes:{amendoado:4,redondo:2,encapuzado:1,caido:1},nose:{reto:3,aquilino:2,largo:2,romano:1,carnudo:1},mouth:{neutra:3,carnuda:1,larga:1,fina:1,canto:1,seria:1},brows:{reta:2,arqueada:2,grossa:2,espessa:1},beard:{nenhuma:2,por_fazer:2,bigode:2,cavanhaque_bigode:2,cheia_curta:2,sombra:1,ferradura:.5},iris:{escuro:4,castanho:3,mel:1,verde:.3},heads:{oval:3,redondo:2,quadrado:2,retangular:1},beardP:.75},
 andino:{n:'Andino / indígena das Américas',skin:{t06:2,t07:3,t08:3,t09:2,t10:1},hairC:{preto:1},m:{curto:3,militar:2,franja:2,maquina:2,degrade_baixo:2,rabo:.5},f:{longo_liso:3,rabo:3,coque:1,nago:1},eyes:{amendoado:3,monolid:2,encapuzado:2,puxado:1},nose:{aquilino:3,reto:2,largo:2,romano:1},mouth:{neutra:3,fina:1,larga:1,seria:1},brows:{reta:3,baixa:2,fina:1},beard:{nenhuma:5,sombra:2,bigode:1,bigode_fino:1},iris:{escuro:4,castanho:1},heads:{redondo:2,quadrado:2,oval:2,alongado:1},beardP:.35},
 europa_norte:{n:'Europa do Norte',skin:{t01:3,t02:3,t03:1},hairC:{loiro:3,loiro_escuro:3,castanho_claro:3,castanho:2,ruivo:1,ruivo_escuro:1,platinado:.3},m:{curto:3,degrade_baixo:2,militar:2,risca:2,para_tras:1,maquina:2,raspado:1,mullet:1,topete:1,coque_masc:1,coroa:.5},f:{rabo:3,coque:3,longo_liso:2,longo_ondulado:1,nago:1},eyes:{redondo:3,amendoado:3,profundo:2,encapuzado:1,grande:1},nose:{reto:3,botao:2,arrebitado:2,fino:2,romano:1},mouth:{fina:3,neutra:3,pequena:1,canto:1,seria:1},brows:{reta:2,arqueada:2,fina:1,angular:1},beard:{nenhuma:2,por_fazer:2,cheia_curta:3,cheia_longa:1,sombra:1,cavanhaque_bigode:1,ancora:.5},iris:{azul:4,cinza:2,verde:2,castanho:2},heads:{oval:2,quadrado:2,alongado:2,retangular:1},beardP:.7,freck:.35},
 mediterraneo:{n:'Europa do Sul / Mediterrâneo',skin:{t03:2,t04:3,t05:3,t06:2,t07:1},hairC:{preto:3,castanho_escuro:4,castanho:2},m:{curto:3,degrade_baixo:3,cacheado_curto:2,para_tras:2,risca:1,maquina:1,topete:1,coroa:.5},f:{longo_ondulado:3,rabo:2,coque:2,cacheado_longo:1,longo_liso:1},eyes:{amendoado:4,encapuzado:2,redondo:1,profundo:1,grande:1},nose:{romano:3,aquilino:2,reto:3,carnudo:1},mouth:{neutra:3,carnuda:2,larga:1,arco:1,canto:1},brows:{grossa:3,reta:2,arqueada:2,espessa:1},beard:{por_fazer:3,cheia_curta:3,sombra:2,nenhuma:1,cavanhaque_bigode:1},iris:{castanho:4,escuro:2,mel:1,verde:1},heads:{oval:3,quadrado:2,retangular:1,alongado:1},beardP:.8},
 leste_europeu:{n:'Leste Europeu',skin:{t01:2,t02:3,t03:2,t04:1},hairC:{castanho:3,castanho_claro:3,loiro_escuro:2,castanho_escuro:2,loiro:1},m:{maquina:3,raspado:2,militar:3,curto:2,degrade_baixo:2,coroa:1},f:{rabo:3,coque:2,longo_liso:2,nago:1},eyes:{profundo:3,amendoado:3,encapuzado:1,pequeno:1,redondo:1},nose:{reto:3,romano:2,largo:1,achatado:1,botao:1},mouth:{fina:2,neutra:3,seria:2,larga:1},brows:{reta:3,grossa:1,baixa:2,angular:1},beard:{nenhuma:2,por_fazer:3,sombra:2,cheia_curta:2,sem_bigode:.5},iris:{azul:3,cinza:3,verde:2,castanho:2},heads:{quadrado:3,retangular:2,redondo:1,oval:1},beardP:.65},
 oriente_medio:{n:'Oriente Médio / Norte da África',skin:{t03:1,t04:3,t05:3,t06:3,t07:2,t08:1,t09:1},hairC:{preto:5,castanho_escuro:3},m:{curto:2,degrade_baixo:3,cacheado_curto:2,maquina:2,para_tras:1,militar:1,risca:1},f:{longo_ondulado:2,coque:2,rabo:2,cacheado_longo:1},eyes:{amendoado:4,encapuzado:2,profundo:2,grande:1},nose:{aquilino:3,romano:3,reto:2,largo:1},mouth:{neutra:3,carnuda:1,larga:1,seria:1},brows:{grossa:3,espessa:2,reta:2,arqueada:1},beard:{cheia_curta:4,por_fazer:3,cheia_longa:1,sombra:1,cavanhaque_bigode:1,nenhuma:1},iris:{escuro:3,castanho:3,mel:1,verde:.4},heads:{oval:2,alongado:2,quadrado:1,retangular:1},beardP:.9},
 caucaso:{n:'Cáucaso',skin:{t02:2,t03:3,t04:3,t05:2},hairC:{preto:4,castanho_escuro:3,castanho:1},m:{raspado:3,maquina:3,militar:2,curto:1,degrade_baixo:1},f:{rabo:2,coque:2,longo_liso:2,longo_ondulado:1},eyes:{profundo:3,amendoado:3,encapuzado:2},nose:{aquilino:3,romano:3,reto:2,achatado:1},mouth:{fina:2,neutra:3,seria:2},brows:{grossa:3,reta:2,espessa:2,baixa:1},beard:{cheia_curta:3,sem_bigode:2,por_fazer:2,cheia_longa:1,nenhuma:1},iris:{escuro:3,castanho:3,verde:1,cinza:1},heads:{quadrado:3,oval:2,retangular:2},beardP:.9},
 asia_central:{n:'Ásia Central',skin:{t02:1,t03:2,t04:3,t05:3,t06:2,t07:1},hairC:{preto:5,castanho_escuro:2},m:{maquina:3,raspado:2,militar:3,curto:2,degrade_baixo:1},f:{longo_liso:3,rabo:2,coque:2},eyes:{monolid:3,encapuzado:3,amendoado:2,puxado:1},nose:{reto:3,largo:2,achatado:1,botao:1},mouth:{neutra:3,fina:2,seria:1},brows:{reta:3,baixa:2,fina:1},beard:{nenhuma:3,sombra:2,por_fazer:2,bigode:1,cheia_curta:1},iris:{escuro:4,castanho:2},heads:{redondo:3,quadrado:2,oval:1},beardP:.5},
 leste_asiatico:{n:'Leste Asiático',skin:{t02:3,t03:3,t04:2,t05:2,t06:1},hairC:{preto:6,castanho_escuro:2,platinado:.4,tingido_azul:.2},m:{franja:3,curto:3,risca:2,para_tras:2,degrade_baixo:2,militar:1,moicano:.3,fauxhawk:.5},f:{longo_liso:3,rabo:3,coque:2,franja:2},eyes:{monolid:4,encapuzado:3,amendoado:2,puxado:1,pequeno:1},nose:{botao:3,reto:2,largo:2,carnudo:1},mouth:{neutra:3,pequena:2,fina:1,carnuda:1},brows:{reta:4,baixa:2,fina:1},beard:{nenhuma:6,sombra:2,bigode_fino:1,cavanhaque:1},iris:{escuro:5,castanho:1},heads:{oval:2,redondo:2,quadrado:1,diamante:1},beardP:.25},
 sudeste_asiatico:{n:'Sudeste Asiático',skin:{t05:2,t06:3,t07:3,t08:2,t09:2,t10:1},hairC:{preto:6,castanho_escuro:2},m:{curto:3,degrade_baixo:3,franja:2,militar:2,cacheado_curto:1,fauxhawk:1},f:{longo_liso:3,rabo:3,coque:2},eyes:{amendoado:3,monolid:2,redondo:2,encapuzado:1},nose:{largo:3,botao:3,reto:2},mouth:{carnuda:2,neutra:3,larga:1,arco:1},brows:{reta:3,arqueada:1,fina:1},beard:{nenhuma:5,sombra:2,bigode_fino:1,cavanhaque:1},iris:{escuro:5},heads:{redondo:2,oval:2,quadrado:1},beardP:.3},
 sul_asiatico:{n:'Sul da Ásia',skin:{t06:2,t07:2,t08:3,t09:3,t10:2,t11:2,t12:1},hairC:{preto:5,castanho_escuro:3},m:{curto:3,para_tras:2,degrade_baixo:2,cacheado_curto:2,risca:1,topete:1},f:{longo_liso:3,rabo:2,coque:2,longo_ondulado:1},eyes:{amendoado:4,redondo:2,grande:2,profundo:1},nose:{reto:2,aquilino:3,romano:2,largo:1,carnudo:1},mouth:{neutra:3,carnuda:2,arco:1,canto:1},brows:{grossa:3,arqueada:2,espessa:1,reta:1},beard:{cheia_curta:3,por_fazer:3,sombra:1,nenhuma:2,cavanhaque_bigode:1,bigode:1},iris:{escuro:4,castanho:2,mel:.5,verde:.3},heads:{oval:3,alongado:1,redondo:1,diamante:1},beardP:.75},
 polinesia:{n:'Polinésia / Pacífico',skin:{t07:2,t08:3,t09:3,t10:2,t11:1},hairC:{preto:5,castanho_escuro:2},m:{cacheado_curto:3,coque_masc:3,degrade_baixo:2,maquina:2,dreads_curtos:1,longo_ondulado:1,mullet:1},f:{longo_ondulado:3,cacheado_longo:2,coque:2,rabo:2},eyes:{amendoado:3,redondo:2,encapuzado:1,profundo:1},nose:{largo:4,reto:1,carnudo:2,achatado:1},mouth:{carnuda:3,neutra:2,larga:2},brows:{grossa:2,reta:2,espessa:1},beard:{nenhuma:2,por_fazer:2,cheia_curta:2,cavanhaque_bigode:2,sombra:1},iris:{escuro:4,castanho:1},heads:{redondo:3,quadrado:3,oval:1},beardP:.6,build:.7,tattoo:.45},
};
// Tendências observadas no MMA atual (ranking UFC, set/2026), aplicadas por cima das distribuições regionais.
const AFRO=['africa_ocidental','africa_oriental','afro_diaspora'];
for(const[k,p]of Object.entries(POPS)){
  Object.assign(p.f,{duas_trancas:3,tranca_unica:2,coque_baixo:2,pixie:.4,undercut_lateral:.4});
  if(AFRO.includes(k))Object.assign(p.m,{degrade_risca:2,high_top:.7,dreads_presos:.8,moicano_cacheado:.5});
  else Object.assign(p.m,{undercut:1.2,crop_frances:1,mullet_moderno:.6,espetado:.4});
  if(['latino','mediterraneo','polinesia','europa_norte','leste_europeu'].includes(k))p.m.meio_coque=.7;
  p.hairC.multicolor=.08;p.hairC.tingido_rosa=.05;p.hairC.tingido_verde=.04;
  p.hairC.pontas_claras=.06;p.hairC.bicolor=.03;p.hairC.prata=.03;p.hairC.acaju=.05;
  Object.assign(p.f,{rabo_alto:3.5,ombro:1.5,coque_baguncado:1,curto_lateral:.5});
  if(AFRO.includes(k)){Object.assign(p.m,{twists_altos:1.2,dreads_soltos:.8,cachos_volumosos:.4});Object.assign(p.f,{afro_puff:1.5,trancas_laterais:1.2})}
  else{Object.assign(p.m,{quiff:2.5,franja_longa:1,ondulado_medio:.6,cachos_volumosos:.6,volumoso:.3,ombro:.25})}
  if(k==='leste_asiatico'){Object.assign(p.m,{franja_longa:2.5,cogumelo:1.2,volumoso:.8});p.f.cogumelo=1}
  if(['latino','mediterraneo','sul_asiatico'].includes(k))p.m.cachos_volumosos=1.2;
  Object.assign(p.beard,{desenhada:1.2,bigode_grosso:.4,cavanhaque_longo:.3});
  if(['caucaso','oriente_medio','asia_central'].includes(k))p.beard.longa_sem_bigode=1;
  // Rodada 5 (set/2026): mais cortes, barbas e tranças presos para luta.
  Object.assign(p.m,{caesar:1,espinhos:.6,slick_longo:.3,samurai:.3,undercut_coque:.6,calvo_lateral:.4,wolf_cut:.3,franja_cortina:.5,viking_trancado:.15,flat_top:.2,maquina_desenho:.5});
  Object.assign(p.f,{trancas_boxeadora:3,rabo_trancado:2,coque_trancado:1.5,bob:.4,long_bob:.4,shag:.3,franja_reta_longo:.4,coques_duplos:.6,nago_longas:.8});
  if(AFRO.includes(k)){Object.assign(p.m,{waves_360:2,afro_degrade:1.6,cachos_degrade:.8,nago_zigue:1,freeform:.6,flat_top:.8});Object.assign(p.f,{bantu_knots:1.2,nago_longas:2,freeform:.5})}
  else Object.assign(p.m,{cachos_degrade:.6});
  Object.assign(p.beard,{cheia_media:1.2,barba_degrade:1.5,falhada:.6,van_dyke:.4,balbo:.4,contorno_bigode:.6,chevron:.3,bigode_guidao:.1,fu_manchu:.08,ducktail:.3,costeletas_bigode:.2,garibaldi:.3,lenhador:.4,viking_trancada:.05});
  if(['europa_norte','leste_europeu'].includes(k))Object.assign(p.beard,{lenhador:1,viking_trancada:.3,garibaldi:.8});
  if(['caucaso','oriente_medio','sul_asiatico'].includes(k))Object.assign(p.beard,{cheia_media:2.5,garibaldi:.8});
}
POPS.misto={n:'Misto (qualquer origem)'};
function bodyFor(r,fem,Pp){const type=pickBodyType(r,fem?'f':'m',null);const b=applyBodyType({},type,r);b.hair=fem?0:+(r()<(Pp.beardP||.5)*.6?r():0).toFixed(2);return b}
function genFace(seed,popId,sex){
  const r=rngOf(seed);
  let pid=popId;
  if(!pid||pid==='misto'){const keys=Object.keys(POPS).filter(k=>k!=='misto');pid=pick(r,keys)}
  const Pp=POPS[pid];
  const fem=sex?sex==='f':r()<.25;
  const skin=pickW(r,Pp.skin);
  const hairColor=pickW(r,Pp.hairC);
  const style=pickW(r,fem?Pp.f:Pp.m);
  const beard=fem?'nenhuma':(r()<Pp.beardP?pickW(r,Pp.beard):'nenhuma');
  const marks=[];
  if(Pp.freck&&r()<Pp.freck)marks.push(r()<.5?'sardas_leves':'sardas');
  if(r()<.12)marks.push(pick(r,['pinta_bochecha','pinta_queixo','pinta_labio']));
  if(r()<.3)marks.push(pick(r,['brow_l','brow_r','cheek_l','cheek_r','lip','nose','chin']));
  if(r()<(Pp.tattoo||.12))marks.push(pick(r,['neck','shoulders','chest']));
  if(r()<.12)marks.push(r()<.5?'argola':'brinco');
  const out={v:1,seed:Math.floor(r()*1e6),pop:pid,sex:fem?'f':'m',age:19+Math.floor(r()*14),build:Pp.build!=null?clamp(Pp.build+(r()-.5)*.5,0,1):r(),
    skin,head:{shape:pickW(r,Pp.heads),width:+(r()*1.2-.6).toFixed(1),jaw:+(r()*1.2-.6).toFixed(1),chin:+(r()*1.2-.6).toFixed(1)},
    eyes:{shape:pickW(r,Pp.eyes),iris:pickW(r,Pp.iris)},brows:{shape:pickW(r,Pp.brows)},
    nose:{shape:pickW(r,Pp.nose),broken:r()<.3?+(r()*.8).toFixed(1):0},mouth:{shape:pickW(r,Pp.mouth)},
    ears:{shape:pickW(r,{normal:6,pequena:2,abano:1,grande:1}),cauli:r()<.35?1+Math.floor(r()*3):0},
    hair:{style,color:hairColor},beard:{style:beard,color:null},marks,recede:fem?0:+(r()*.7).toFixed(1),body:bodyFor(r,fem,Pp),kit:{shorts:pickW(r,{preto:4,vermelho:2,azul:2,branco:1,verde:1,dourado:.5,roxo:.5,camuflado:.5}),gloves:pickW(r,{preto:6,vermelho:1,azul:1,branco:.5})}};
  // Porte da cabeça/pescoço acompanha o biotipo sorteado.
  out.build=+clamp(out.build*.4+BODY_TYPES[out.body.type].build*.6,0,1).toFixed(2);
  return out;
}

/* ================= roster canônico ================= */
const C=(o)=>({v:1,pop:'misto',build:.5,body:{muscle:.65,fat:.15,hair:0,height:.5},kit:{shorts:'preto',gloves:'preto'},head:{shape:'oval',width:0,jaw:0,chin:0},eyes:{shape:'amendoado',iris:'escuro'},brows:{shape:'reta'},nose:{shape:'reto',broken:0},mouth:{shape:'neutra'},ears:{shape:'normal',cauli:0},hair:{style:'curto',color:'preto'},beard:{style:'nenhuma',color:null},marks:[],recede:0,...o});
const CANON=[
 C({name:'Malik Carter',body:{muscle:0.8,fat:0.08,hair:0,height:0.55},kit:{shorts:'vermelho',gloves:'preto'},cc:'EUA',rec:'24-1',seed:11,sex:'m',age:31,skin:'t12',pop:'afro_diaspora',head:{shape:'oval',width:0,jaw:.4,chin:0},nose:{shape:'largo',broken:0},mouth:{shape:'canto'},ears:{shape:'normal',cauli:1},hair:{style:'degrade_alto',color:'preto'},beard:{style:'cavanhaque_bigode',color:null},marks:['brow_r','argola'],recede:.1}),
 C({name:'Rafael Moreira',body:{muscle:0.7,fat:0.14,hair:0.35,height:0.5},kit:{shorts:'verde',gloves:'preto'},cc:'BRA',rec:'20-2',seed:22,sex:'m',age:31,skin:'t06',pop:'latino',head:{shape:'quadrado',width:.2,jaw:0,chin:0},eyes:{shape:'profundo',iris:'castanho'},brows:{shape:'grossa'},nose:{shape:'achatado',broken:.8},ears:{shape:'normal',cauli:3},hair:{style:'maquina',color:'castanho_escuro'},beard:{style:'por_fazer',color:null},marks:['cheek_l'],recede:.4}),
 C({name:'Magomed Arsanov',body:{muscle:0.75,fat:0.1,hair:0.5,height:0.55},kit:{shorts:'preto',gloves:'preto'},cc:'CAZ',rec:'18-0',seed:33,sex:'m',age:30,skin:'t03',pop:'caucaso',head:{shape:'quadrado',width:0,jaw:.2,chin:.3},eyes:{shape:'encapuzado',iris:'escuro'},brows:{shape:'espessa'},nose:{shape:'aquilino',broken:.3},mouth:{shape:'seria'},ears:{shape:'normal',cauli:3},hair:{style:'raspado',color:'preto'},beard:{style:'sem_bigode',color:null}}),
 C({name:'Mateo Reyes',body:{muscle:0.62,fat:0.07,hair:0,height:0.35},kit:{shorts:'vermelho',gloves:'vermelho'},cc:'MEX',rec:'17-1',seed:44,sex:'m',age:26,skin:'t08',pop:'latino',head:{shape:'diamante',width:0,jaw:0,chin:0},brows:{shape:'arqueada'},nose:{shape:'reto',broken:0},mouth:{shape:'canto'},hair:{style:'topete',color:'preto'},beard:{style:'bigode',color:null},marks:['neck','chest']}),
 C({name:'Ana Costa',body:{muscle:0.62,fat:0.1,hair:0,height:0.3},kit:{shorts:'dourado',gloves:'preto'},cc:'BRA',rec:'16-1',seed:55,sex:'f',age:29,skin:'t11',pop:'afro_diaspora',head:{shape:'oval',width:-.2,jaw:0,chin:0},eyes:{shape:'grande',iris:'escuro'},brows:{shape:'arqueada'},nose:{shape:'carnudo',broken:0},mouth:{shape:'carnuda'},hair:{style:'box_braids',color:'preto'},marks:['brinco']}),
 C({name:'Kenji Sato',body:{muscle:0.58,fat:0.08,hair:0.05,height:0.3},kit:{shorts:'branco',gloves:'preto'},cc:'JAP',rec:'29-5',seed:66,sex:'m',age:35,skin:'t03',pop:'leste_asiatico',head:{shape:'retangular',width:0,jaw:0,chin:0},eyes:{shape:'monolid',iris:'escuro'},nose:{shape:'botao',broken:.3},mouth:{shape:'seria'},ears:{shape:'normal',cauli:2},hair:{style:'para_tras',color:'preto'},marks:['cheek_r','brow_l'],recede:.3}),
 C({name:'Jessica Monroe',body:{muscle:0.55,fat:0.12,hair:0,height:0.35},kit:{shorts:'azul',gloves:'preto'},cc:'EUA',rec:'13-0',seed:77,sex:'f',age:25,skin:'t02',pop:'europa_norte',head:{shape:'coracao',width:0,jaw:0,chin:0},eyes:{shape:'redondo',iris:'azul'},brows:{shape:'alta'},nose:{shape:'arrebitado',broken:0},mouth:{shape:'arco'},hair:{style:'rabo',color:'loiro'},marks:['sardas_leves']}),
 C({name:'Aleksandr Volkovic',body:{muscle:0.62,fat:0.48,hair:0.7,height:0.85},kit:{shorts:'preto',gloves:'preto'},cc:'SRV',rec:'Lenda',seed:88,sex:'m',age:40,skin:'t02',pop:'leste_europeu',build:1,head:{shape:'quadrado',width:.6,jaw:.6,chin:.4},eyes:{shape:'profundo',iris:'cinza'},brows:{shape:'baixa'},nose:{shape:'achatado',broken:1},mouth:{shape:'fina'},ears:{shape:'grande',cauli:3},hair:{style:'raspado',color:'castanho'},beard:{style:'sombra',color:null},marks:['brow_l','brow_r','cheek_l','nose']}),
 C({name:'Sofia Markovic',body:{muscle:0.7,fat:0.12,hair:0,height:0.45},kit:{shorts:'roxo',gloves:'preto'},cc:'SRV',rec:'18-2',seed:99,sex:'f',age:30,skin:'t02',pop:'leste_europeu',head:{shape:'quadrado',width:0,jaw:-.2,chin:0},eyes:{shape:'amendoado',iris:'verde'},brows:{shape:'reta'},nose:{shape:'romano',broken:.2},mouth:{shape:'seria'},ears:{shape:'normal',cauli:1},hair:{style:'nago',color:'castanho_escuro'}}),
 C({name:'Darius Cole',body:{muscle:0.92,fat:0.06,hair:0.05,height:0.7},kit:{shorts:'camuflado',gloves:'preto'},cc:'EUA',rec:'12-0',seed:111,sex:'m',age:24,skin:'t10',pop:'afro_diaspora',build:.75,head:{shape:'retangular',width:0,jaw:.3,chin:.2},nose:{shape:'reto',broken:0},mouth:{shape:'neutra'},hair:{style:'twists',color:'preto'},beard:{style:'contorno',color:null},marks:['shoulders']}),
];

/* ================= catálogo ================= */
const VIEW_FULL={}, VIEW_EYES={zoom:2.5,cy:-.02}, VIEW_NOSE={zoom:2.4,cy:.22}, VIEW_MOUTH={zoom:2.6,cy:.62}, VIEW_LOWER={zoom:1.55,cy:.45}, VIEW_EARS={zoom:1.35,cy:0};
const CATS=[
 {id:'head',n:'Rosto',items:Object.entries(HEADS).map(([k,v])=>[k,v.n]),get:f=>f.head.shape,set:(f,k)=>f.head.shape=k,view:VIEW_FULL},
 {id:'skin',n:'Pele',items:Object.entries(SKIN).map(([k,v])=>[k,v[1]]),get:f=>f.skin,set:(f,k)=>f.skin=k,view:VIEW_LOWER},
 {id:'eyes',n:'Olhos',items:Object.entries(EYES).map(([k,v])=>[k,v.n]),get:f=>f.eyes.shape,set:(f,k)=>f.eyes.shape=k,view:VIEW_EYES},
 {id:'iris',n:'Íris',items:Object.entries(IRIS).map(([k,v])=>[k,v[1]]),get:f=>f.eyes.iris,set:(f,k)=>f.eyes.iris=k,view:VIEW_EYES},
 {id:'brows',n:'Sobrancelha',items:Object.entries(BROWS).map(([k,v])=>[k,v.n]),get:f=>f.brows.shape,set:(f,k)=>f.brows.shape=k,view:VIEW_EYES},
 {id:'nose',n:'Nariz',items:Object.entries(NOSES).map(([k,v])=>[k,v.n]),get:f=>f.nose.shape,set:(f,k)=>f.nose.shape=k,view:VIEW_NOSE},
 {id:'mouth',n:'Boca',items:Object.entries(MOUTHS).map(([k,v])=>[k,v.n]),get:f=>f.mouth.shape,set:(f,k)=>f.mouth.shape=k,view:VIEW_MOUTH},
 {id:'ears',n:'Orelha',items:Object.entries(EARS).map(([k,v])=>[k,v.n]),get:f=>f.ears.shape,set:(f,k)=>f.ears.shape=k,view:VIEW_EARS},
 {id:'hair',n:'Cabelo',items:Object.entries(HAIR_STYLES).map(([k,v])=>[k,v.n+(v.novo?' · novo':'')]),get:f=>f.hair.style,set:(f,k)=>f.hair.style=k,view:VIEW_FULL},
 {id:'hairColor',n:'Cor do cabelo',items:Object.entries(HAIR_COLORS).map(([k,v])=>[k,v[1]+(['bicolor','pontas_claras','acaju','prata'].includes(k)?' · novo':'')]),get:f=>f.hair.color,set:(f,k)=>f.hair.color=k,view:VIEW_FULL},
 {id:'beard',n:'Barba',items:Object.entries(BEARDS).map(([k,v])=>[k,v.n+(v.novo?' · novo':'')]),get:f=>f.beard.style,set:(f,k)=>f.beard.style=k,view:VIEW_LOWER,note:'Barba só aparece em rostos masculinos.'},
 {id:'beardColor',n:'Cor da barba',items:[['__hair','Igual ao cabelo'],...Object.entries(HAIR_COLORS).filter(([k])=>!k.startsWith('tingido')).map(([k,v])=>[k,v[1]])],get:f=>f.beard.color||'__hair',set:(f,k)=>f.beard.color=k==='__hair'?null:k,view:VIEW_LOWER},
 {id:'marks',n:'Marcas',multi:true,items:MARKS.map(m=>[m[0],m[1]]),get:f=>f.marks,set:(f,k)=>{const s=new Set(f.marks);if(s.has(k))s.delete(k);else{if(k==='sardas')s.delete('sardas_leves');if(k==='sardas_leves')s.delete('sardas');s.add(k)}f.marks=[...s]},view:VIEW_FULL,note:'Seleção múltipla: clique de novo para remover.'},
];
