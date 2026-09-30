// PARALELO: one vector scene for Canvas previews and editable SVG export.
// Geometry depends only on the genome + explicit presentation options.
;(function (root) {
  'use strict'
  const C = root.FaceCore, { clamp, lerp, smooth } = C
  const rgb = c => `rgb(${c.map(v => Math.round(clamp(v, 0, 255))).join(',')})`
  const mix = (a, b, t) => a.map((v, i) => lerp(v, b[i], t))
  const ink = '#383b36'
  const n = x => Math.round(x * 100) / 100
  const esc = s => String(s).replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;')
  function scene(width, height, ctx) {
    const out = [`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">`]
    function node(tag, attrs) {
      out.push(`<${tag} ${Object.entries(attrs).map(([k, v]) => `${k}="${esc(v)}"`).join(' ')}/>`)
      if (!ctx) return
      ctx.save(); ctx.globalAlpha = attrs.opacity ?? 1
      const p = new Path2D()
      if (tag === 'path') p.addPath(new Path2D(attrs.d))
      else if (tag === 'ellipse') p.ellipse(attrs.cx, attrs.cy, attrs.rx, attrs.ry, 0, 0, Math.PI * 2)
      else if (tag === 'rect') p.rect(attrs.x, attrs.y, attrs.width, attrs.height)
      if (attrs.fill !== 'none') { ctx.fillStyle = attrs.fill; ctx.fill(p) }
      if (attrs.stroke) { ctx.strokeStyle = attrs.stroke; ctx.lineWidth = attrs['stroke-width'] || 1; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke(p) }
      ctx.restore()
    }
    return {
      path(d, fill, stroke = ink, sw = 2, opacity = 1) { node('path', { d, fill, ...(stroke ? { stroke, 'stroke-width': sw, 'stroke-linejoin': 'round', 'stroke-linecap': 'round' } : {}), opacity }) },
      oval(x, y, rx, ry, fill, stroke = null, sw = 2, opacity = 1) { node('ellipse', { cx: n(x), cy: n(y), rx: n(Math.max(.01, rx)), ry: n(Math.max(.01, ry)), fill, ...(stroke ? { stroke, 'stroke-width': sw } : {}), opacity }) },
      rect(x, y, w, h, fill) { node('rect', { x, y, width: w, height: h, fill }) },
      group(x, y, scale = 1) { out.push(`<g transform="translate(${n(x)} ${n(y)}) scale(${n(scale)})">`); if (ctx) { ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale) } },
      end() { out.push('</g>'); if (ctx) ctx.restore() },
      svg() { return out.join('') + '</svg>' },
    }
  }
  function polygon(points) {
    return C.catmull(points, true, 5).map(([x, y], i) => `${i ? 'L' : 'M'}${n(x)} ${n(y)}`).join(' ') + ' Z'
  }
  function palette(g, age, opts) {
    const p = C.phenotype(g, age), skin = C.skinRGB(p.mel, g.skin.under)
    const grey = smooth(g.hair.greyOnset, g.hair.greyOnset + 30, age)
    const hair = mix(C.hairRGB(p.hairEu, p.hairPheo), [183, 182, 169], grey * .85)
    const clothes = [[103, 126, 109], [166, 115, 87], [110, 128, 148], [153, 112, 126], [191, 161, 92], [88, 106, 106]]
    let cloth = clothes[Math.floor(g.pref.shirtHue * clothes.length) % clothes.length]
    const fabrics={linen:[202,195,172],formal:[188,196,191],shirt:[157,176,183],blazer:[76,94,108],cardigan:[156,120,98],blouse:[149,160,125],blouse34:[178,137,145],dress:[145,100,113],dresslong:[112,148,138],tank:[193,175,146],knit:[164,151,113]}
    if(fabrics[opts.outfit])cloth=mix(cloth,fabrics[opts.outfit],.82)
    return { p, skin: rgb(skin), shadow: rgb(mix(skin, [91, 64, 47], .18)), blush: rgb(mix(skin, [182, 99, 91], .28)),
      hair: rgb(hair), hairHi: rgb(mix(hair, [210, 193, 155], .16)), eye: rgb(C.eyeRGB(p.eyeDark, p.eyeGreen)),
      lip: rgb(mix(skin, [135, 67, 63], .48)), shirt: rgb(cloth), clothShadow: rgb(mix(cloth, [31, 45, 43], .22)),
      pants: '#4b5a61', pantShadow: '#39454d', shoe: '#343b39', shoeHi: '#636d64' }
  }
  function geometry(g, age, fat) {
    const z = g.z, baby = 1 - smooth(0, 13, age), old = smooth(55, 105, age)
    const rx = 76 * (1 + clamp(z.faceW, -3, 3) * .045) + fat * 10 + baby * 8
    const top = 111 - z.skullH * 2 - baby * 7, chin = 328 + z.faceL * 4 + z.chinL * 1.5 - baby * 27 + old * 4
    const jaw = rx * lerp(g.sex === 'M' ? .84 : .70,.83,baby) * (1 + z.jawW * .045 * (1-baby*.55))
    const H=chin-top,eyeY=top+H*lerp(.46,.54,baby)+z.eyeY*1.6,eyeOff=36+z.eyeSpace*2+baby*2
    const eyeW = clamp(22 + z.eyeSize * 1.8 + baby * 1.4, 17, 28)
    const chinW=clamp((20+z.chinW*2)*(g.sex==='F'?lerp(.93,1,baby):1),14,29),cheek=rx+z.cheekB*1.5,jawY=chin-26-z.jawSq*2.5
    return { rx, top, chin, jaw, eyeY, eyeOff, eyeW, baby, old,
      noseY: eyeY+H*lerp(.20,.13,baby)+z.noseL*1.8, mouthY: top+H*lerp(.81,.84,baby)+z.mouthY*1.6,
      hairline: top+H*lerp(.245,.26,baby)+z.forehead*1.5, mouthW: (24+z.mouthW*2.2)*lerp(1,.74,baby),
      face: `M200 ${n(top)} C${n(200 + rx * .75)} ${n(top - 4)} ${n(200 + rx + 8)} 165 ${n(200 + rx)} 223 C${n(200 + cheek)} 251 ${n(200 + jaw)} ${n(jawY)} ${n(200+chinW)} ${n(chin)} Q200 ${n(chin + 7)} ${n(200-chinW)} ${n(chin)} C${n(200 - jaw)} ${n(jawY)} ${n(200 - cheek)} 251 ${n(200 - rx)} 223 C${n(200 - rx - 8)} 165 ${n(200 - rx * .75)} ${n(top - 4)} 200 ${n(top)} Z` }
  }
  function hairBack(s, g, q, c, style) {
    if (!style || ['shaved', 'buzz', 'fuzz', 'horseshoe', 'thin'].includes(style.special)) return
    const { rx, top, chin } = q, side = style.side ?? style.len, curl = style.catalogTexture ?? Math.max(c.p.tex, style.curlBoost || 0)
    const w = rx + 10 + (style.volSide || 0) * 100 + curl * 3, y = top - 9 - (style.volTop || 0) * 90
    const length = Math.max(side, style.back || 0), bottom = top + (chin - top) * (.58 + length * .70)
    const color = c.hair
    if (style.special === 'afro') {
      const radius = rx + 14 + style.volSide * 105, ry = (chin - top) * .56 + style.volTop * 65
      s.oval(200, 204, radius, ry, color, ink)
      const bumps = 24, phase = C.hash32(g.id + style.id) % 17 / 17
      for (let i = 0; i < bumps; i++) { const a = i / bumps * Math.PI * 2 + phase; s.oval(200 + Math.cos(a) * radius * .94, 204 + Math.sin(a) * ry * .94, 12 + curl, 13 + curl, color) }
    } else if (side > .28 || style.back > .3) {
      const asym = (style.asymmetric || 0) * 80
      s.path(`M${n(200-w)} 215 C${n(194-w)} ${n(y)} ${n(206+w)} ${n(y)} ${n(200+w)} 215 L${n(200+w+curl*4)} ${n(bottom+asym)} Q200 ${n(bottom+22)} ${n(200-w-curl*4)} ${n(bottom-asym)} Z`, color)
      for (const dir of [-1, 1]) for (let i = 0; i < 3; i++) {
        const x = 200 + dir * (rx + 3 + i * 6)
        s.path(`M${n(x)} 211 Q${n(x+dir*(10+curl*4))} ${n((211+bottom)/2)} ${n(x+dir*curl*3)} ${n(bottom-7-i*6)}`, 'none', c.hairHi, 2)
      }
      if (curl > 1.1) for (const dir of [-1, 1]) for (let i = 0; i < Math.ceil(length * 7); i++) {
        const yy = 215 + i * 17, xx = 200 + dir * (w - 2 + Math.sin(i * 2) * 4)
        s.oval(xx, yy, 10 + curl * 2, 13, color)
      }
    }
    const tie = style.tie
    if (['bun', 'topknot', 'messybun', 'afropuff'].includes(tie)) {
      s.oval(200 + (tie === 'messybun' ? 16 : 0), y - 8, tie === 'afropuff' ? 43 : 30, tie === 'afropuff' ? 39 : 26, color, ink)
      s.path(`M180 ${n(y-8)} Q205 ${n(y-26)} 219 ${n(y-4)}`, 'none', c.hairHi, 3)
    }
    if (['lowbun', 'lowtail', 'ponytail', 'halfup', 'sidebraid'].includes(tie)) {
      const tx = 200 + rx * .9, ty = tie === 'ponytail' ? 163 : tie === 'halfup' ? 176 : 245
      const end = ty + (tie === 'lowbun' ? 43 : style.len * 95)
      s.path(`M${n(tx)} ${ty} Q${n(tx+75)} ${n(ty-12)} ${n(tx+41)} ${n(end)} Q${n(tx+8)} ${n(end+9)} ${n(tx+8)} ${n(ty+20)} Z`, color)
      s.path(`M${n(tx+18)} ${n(ty+16)} Q${n(tx+41)} ${n(ty+26)} ${n(tx+24)} ${n(end-12)}`, 'none', c.hairHi, 3)
      if(tie==='sidebraid') for(let yy=ty+18;yy<end-7;yy+=13) s.path(`M${n(tx+13)} ${n(yy)} l24 6 -23 7`, 'none',c.hairHi,2)
    }
    if (['pigtails', 'puffs', 'braids'].includes(tie)) for (const dir of [-1, 1]) {
      const x = 200 + dir * (rx + 18), y = tie === 'puffs' ? 172 : 216
      if (tie === 'puffs') { s.oval(x, y, 42, 42, color, ink); for (let i=0;i<7;i++) s.oval(x+Math.cos(i)*34,y+Math.sin(i)*34,13,13,color) }
      else {
        const end = 235 + style.len * 103
        s.path(`M${n(x-17)} ${y} Q${n(x-dir*12)} ${n(end-10)} ${n(x+dir*18)} ${n(end)} Q${n(x+dir*36)} ${n(end+2)} ${n(x+20)} ${y} Z`, color)
        if (tie === 'braids') for (let j=y+10;j<end;j+=14) s.path(`M${n(x-8)} ${j} l22 8 -20 7`, 'none', c.hairHi, 2)
        s.path(`M${n(x-14)} ${y+6} L${n(x+19)} ${y+8}`, 'none', c.shirt, 6)
      }
    }
  }
  function hairFront(s, g, q, c, style) {
    if (!style) return
    const { rx, top, hairline } = q, special = style.special
    if (special === 'shaved') { s.path(`M${n(200-rx*.7)} 151 Q200 ${n(top+5)} ${n(200+rx*.7)} 151`, 'none', c.shadow, 3); return }
    if (special === 'horseshoe') {
      for (const dir of [-1, 1]) s.path(`M${n(200+dir*rx*.83)} 160 Q${n(200+dir*(rx+8))} 194 ${n(200+dir*rx*.91)} 250 L${n(200+dir*rx*.75)} 241 Z`, c.hair, null)
      return
    }
    const v = (style.volTop || 0) * 100 + (style.len || 0) * 8, y = top - 7 - v
    const part = (style.part || 0) * rx, fringe = style.fringe || 'none', fl = (style.fringeLen || .22) * 72
    const x1 = 200-rx-5, x2 = 200+rx+5, curl = style.catalogTexture ?? Math.max(c.p.tex, style.curlBoost || 0)
    const end = special === 'buzz' || special === 'fuzz' ? hairline - 16 : hairline
    let cap = `M${n(x1)} 205 C${n(x1-8)} ${n(y+25)} 153 ${n(y-14)} 200 ${n(y)} C252 ${n(y-6)} ${n(x2+13)} ${n(y+25)} ${n(x2)} 205 L${n(x2-11)} ${n(end+5)} Q${n(224+part)} ${n(end-18)} ${n(200+part)} ${n(end-15)} Q158 ${n(end-20)} ${n(x1+12)} ${n(end+7)} Z`
    if (special === 'flattop') cap = `M${n(x1)} 202 L${n(x1+9)} ${n(y)} L${n(x2-9)} ${n(y)} L${n(x2)} 202 Q200 ${n(end-38)} ${n(x1)} 202 Z`
    if (special === 'mohawk') cap = `M183 ${n(end)} L182 ${n(y-7)} L193 ${n(y-27)} L207 ${n(y-21)} L220 ${n(end)} Z`
    s.path(cap, c.hair, ink, 2, special === 'fuzz' ? .48 : special === 'thin' ? .65 : 1)
    if (style.fade) for (const dir of [-1, 1]) s.path(`M${n(200+dir*(rx-3))} 201 L${n(200+dir*(rx-8))} 226`, 'none', c.hair, 9, .28)
    if (fringe === 'straight') s.path(`M${n(x1+9)} ${n(end-12)} Q200 ${n(end-25)} ${n(x2-9)} ${n(end-12)} L${n(x2-14)} ${n(end+fl)} Q200 ${n(end+fl+5)} ${n(x1+16)} ${n(end+fl)} Z`, c.hair)
    else if (fringe === 'curtain') {
      s.path(`M${n(200+part)} ${n(end-32)} Q151 ${n(end-31)} ${n(x1+5)} ${n(end+fl+19)} Q164 ${n(end+fl-4)} ${n(200+part)} ${n(end-10)} Z`, c.hair)
      s.path(`M${n(200+part)} ${n(end-32)} Q248 ${n(end-31)} ${n(x2-5)} ${n(end+fl+14)} Q237 ${n(end+fl-4)} ${n(200+part)} ${n(end-10)} Z`, c.hair)
    } else if (['side', 'swept', 'back'].includes(fringe)) s.path(`M${n(x1+6)} ${n(end)} Q185 ${n(y-8)} ${n(x2-5)} ${n(end-9)} Q190 ${n(end+fl+14)} ${n(x1+14)} ${n(end+fl)} Q161 ${n(end+12)} ${n(x1+6)} ${n(end)} Z`, c.hair)
    else if (['quiff', 'pomp'].includes(fringe)) s.path(`M${n(x1+13)} ${n(end)} Q143 ${n(y-27-fl*.3)} 220 ${n(y-18)} Q278 ${n(y-5)} ${n(x2-12)} ${n(end-1)} Q216 ${n(end-29)} ${n(x1+13)} ${n(end)} Z`, c.hair)
    else if (['spiky', 'wisp'].includes(fringe)) {
      const points = [[x1+12,end-12]]
      for (let i=0;i<8;i++) points.push([x1+18+i*(rx*2-27)/7,end+(i%2?fl:fl*.35)+(fringe==='wisp'?Math.sin(i)*8:0)])
      points.push([x2-9,end-21]); s.path(polygon(points), c.hair, null)
    }
    if (special === 'cornrows') for (let i=-3;i<=3;i++) s.path(`M${n(200+i*18)} ${n(end+8)} Q${n(200+i*20)} ${n(top-7)} ${n(200+i*7)} ${n(top-3)}`, 'none', c.hairHi, 6)
    else if (['boxbraids', 'locs', 'twists'].includes(special)) {
      const len = style.side * 125, count = special === 'boxbraids' ? 12 : 9
      for(let i=0;i<count;i++) {
        const dir=i<count/2?-1:1, j=i%(count/2), xx=200+dir*(rx+2+j*4), yy=163+j*10
        s.path(`M${n(xx)} ${n(yy)} Q${n(xx+dir*14)} 241 ${n(xx+dir*8)} ${n(220+len-j*3)}`, 'none', c.hair, special==='locs'?11:7)
        s.path(`M${n(xx+dir*2)} ${n(yy)} Q${n(xx+dir*14)} 241 ${n(xx+dir*8)} ${n(218+len-j*3)}`, 'none', c.hairHi, 1.5)
      }
    } else if (curl > 1 && !['shaved','buzz','fuzz','mohawk'].includes(special)) {
      for(let i=0;i<13;i++) { const a=Math.PI+i/12*Math.PI; s.oval(200+Math.cos(a)*(rx-3),y+44+Math.sin(a)*(38+v*.2),11+curl*1.6,12+curl,c.hair) }
      for(let i=0;i<5;i++) s.path(`M${160+i*17} ${n(y+27+Math.sin(i)*6)} q-8 -12 3 -17 q14 -4 10 8`, 'none', c.hairHi, 2)
    } else {
      s.path(`M${n(x1+22)} ${n(y+34)} Q192 ${n(y+3)} ${n(x2-23)} ${n(y+30)}`, 'none', c.hairHi, 3)
      if (style.part != null) s.path(`M${n(200+part)} ${n(end-12)} Q${n(210+part)} ${n(y+13)} ${n(194+part)} ${n(y+5)}`, 'none', c.hairHi, 2)
    }
    if (style.layered) for(const dir of [-1,1]) s.path(`M${n(200+dir*(rx-1))} 202 q${dir*17} 39 ${dir*4} 76`, 'none', c.hairHi, 3)
    if(style.side>.6&&!style.tie&&!['afro','boxbraids','locs','twists'].includes(special))for(const dir of [-1,1]){
      const x=200+dir*(rx-1),end=top+(q.chin-top)*(.58+style.side*.70)+(dir>0?(style.asymmetric||0)*65:0),wave=(style.wavyBoost||0)+curl*.6
      s.path(`M${n(x+dir*4)} 184 C${n(x+dir*(16+wave*5))} 233 ${n(x+dir*(18+wave*5))} ${n(end-40)} ${n(x+dir*6)} ${n(end)} Q${n(x-dir*4)} ${n(end+4)} ${n(x-dir*11)} ${n(end-10)} C${n(x-dir*(7-wave*2))} ${n(end-49)} ${n(x-dir*22)} 250 ${n(x-dir*11)} 219 Z`,c.hair,null)
      s.path(`M${n(x+dir*3)} 218 C${n(x+dir*(11+wave*4))} 275 ${n(x+dir*9)} ${n(end-52)} ${n(x-dir*1)} ${n(end-13)}`, 'none',c.hairHi,1.8)
      s.path(`M${n(x+dir*9)} 235 Q${n(x+dir*(17+wave*3))} ${n(end-71)} ${n(x+dir*7)} ${n(end-26)}`, 'none',c.hairHi,1.1,.75)
    }
  }
  function beard(s, g, q, c, style, age) {
    if (g.sex !== 'M' || age < 16 || !style.parts) return
    const parts = style.parts, has = p => parts.includes(p), { rx, chin, mouthY, mouthW } = q
    const len = (style.len || .05) * 56 * smooth(15, 22, age), col = c.hair, opacity = (style.stubble ? .25 + style.stubble * .38 : 1)*lerp(.45,1,smooth(16,23,age))
    const wide = has('cheek') || has('cheekLow') || has('chin') || has('strap') || has('neck')
    if (wide) {
      const w = q.jaw + 1, cheekY = has('cheekLow') ? mouthY + 10 : mouthY - 18
      const bottom = chin + len, round = style.round || 0, point = style.point || 0
      s.path(`M${n(200-rx+4)} ${n(cheekY-10)} Q${n(200-w)} ${n(mouthY+8)} ${n(200-mouthW-13)} ${n(mouthY+12)} Q200 ${n(mouthY+27)} ${n(200+mouthW+13)} ${n(mouthY+12)} Q${n(200+w)} ${n(mouthY+8)} ${n(200+rx-4)} ${n(cheekY-10)} Q${n(200+w+4)} ${n(bottom-7)} ${n(222+round*9)} ${n(bottom)} Q200 ${n(bottom+6+point*len*.7)} ${n(178-round*9)} ${n(bottom)} Q${n(200-w-4)} ${n(bottom-7)} ${n(200-rx+4)} ${n(cheekY-10)} Z`, col, null, 1, opacity)
      if (style.boxed) s.path(`M${n(200-w*.64)} ${n(chin+len*.72)} L${n(200+w*.64)} ${n(chin+len*.72)}`, 'none', c.hairHi, 2, opacity)
      if(!style.stubble&&len>9)for(const dir of [-1,1])s.path(`M${n(200+dir*w*.83)} ${n(mouthY+18)} Q${n(200+dir*w*.69)} ${n(chin+len*.4)} ${n(200+dir*w*.32)} ${n(chin+len*.79)}`, 'none',c.hairHi,1.7,.65)
    }
    if (parts.some(p=>p.startsWith('goatee')) || has('anchor')) {
      const w = has('goateeWide') ? 35 : has('goateeRound') ? 31 : 24, y = mouthY+13
      s.path(`M${200-w} ${n(y)} Q200 ${n(y+12)} ${200+w} ${n(y)} L${n(200+w*.85)} ${n(chin+len)} Q200 ${n(chin+len+6+(style.point||0)*len)} ${n(200-w*.85)} ${n(chin+len)} Z`, col, null, 1, opacity)
      if (has('goateeRound')) for(const dir of [-1,1]) s.path(`M${n(200+dir*(mouthW+5))} ${n(mouthY-9)} Q${n(200+dir*39)} ${n(mouthY+5)} ${n(200+dir*29)} ${n(chin-10)}`, 'none', col, 7)
      if (has('anchor')) s.path(`M${n(200-rx*.68)} ${n(chin-14)} Q200 ${n(chin+20)} ${n(200+rx*.68)} ${n(chin-14)}`, 'none', col, 9)
    }
    if (has('burns') || has('chops')) for(const dir of [-1,1]) {
      const w = has('chops') ? 19 + len*.2 + (style.boxed||0)*3 : 9
      s.path(`M${n(200+dir*(rx-8))} 227 Q${n(200+dir*(rx-w))} 248 ${n(200+dir*(rx-w))} ${n(mouthY+15+len*.3)} L${n(200+dir*(rx+1))} ${n(mouthY+6+len*.3)} Z`, col, null)
    }
    if (has('soul')) s.path(`M191 ${n(mouthY+12)} h18 l-7 16 h-5 Z`, col, null)
    if (has('mus')) {
      const mus = style.mus || 'classic', thin = mus.includes('pencil') || mus === 'english', w=mouthW+7+(mus==='walrus'?7:0), y=mouthY-12
      const thick = thin ? 4 : 8 + (style.musLen || style.len || .1)*13
      s.path(`M200 ${n(y-3)} Q${n(200-w*.55)} ${n(y-8)} ${n(200-w)} ${n(y+thick)} Q${n(200-w*.4)} ${n(y+thick+3)} 200 ${n(y+3)} Q${n(200+w*.4)} ${n(y+thick+3)} ${n(200+w)} ${n(y+thick)} Q${n(200+w*.55)} ${n(y-8)} 200 ${n(y-3)} Z`, col, null, 1, opacity)
      if (mus === 'handlebar' || mus==='english') for(const dir of [-1,1]) s.path(`M${n(200+dir*w*.8)} ${n(y+7)} q${dir*21} 8 ${dir*26} -9`, 'none', col, thin?3:5)
    }
    if (has('horseshoe') || has('fumanchu')) for(const dir of [-1,1]) s.path(`M${n(200+dir*(mouthW+5))} ${n(mouthY-9)} L${n(200+dir*(mouthW+7))} ${n(chin-13+len)}`, 'none', col, has('fumanchu')?5:9)
    if (style.wild) for(let i=0;i<8;i++) s.path(`M${174+i*8} ${n(chin+len*.5)} l${Math.sin(i)*8} ${n(len*.5)}`, 'none', c.hairHi, 2)
    if (style.patchy) for(let i=0;i<6;i++) s.oval(165+i*13,chin-14+Math.sin(i)*7,4,7,c.skin,null)
  }
  function face(s, g, age, fat, c, opts) {
    const q = geometry(g, age, fat), z = g.z, h = C.hairForAge(g, age, opts.hair), expression=opts.expression||'warm'
    let bs = C.BEARD_BY_ID[opts.beard || g.pref.beard] || C.BEARD_BY_ID.nenhuma
    if (age < 16 || g.sex === 'F') bs = C.BEARD_BY_ID.nenhuma
    if(!opts.skipHairBack)hairBack(s,g,q,c,h)
    for(const dir of [-1,1]) {
      const ex=200+dir*(q.rx+1), ey=228+z.earSize*1.5
      s.oval(ex,ey,9+z.earOut*.9,20+z.earSize*1.1,c.skin,ink,1.5)
      s.path(`M${n(ex-dir*2)} ${n(ey-9)} q${dir*9} 1 ${dir*3} 15`, 'none', c.shadow,2)
    }
    s.path(q.face,c.skin)
    s.path(`M${n(200+q.rx-6)} 225 Q${n(200+q.rx-4)} 283 212 ${n(q.chin)} L222 ${n(q.chin-2)} Q${n(200+q.rx+5)} 277 ${n(200+q.rx-6)} 225 Z`,c.shadow,null)
    for(const dir of [-1,1]) {
      const x=200+dir*q.eyeOff, y=q.eyeY+(dir>0?g.asym*.65:0), w=q.eyeW, open=clamp(8.2+z.eyeOpen*.9-z.hood*.65,5.5,11.5), tilt=z.eyeTilt*1.2
      s.path(`M${n(x-w-2)} ${n(y-1)} Q${n(x)} ${n(y-open-10)} ${n(x+w+2)} ${n(y-1)} Q${n(x)} ${n(y-open-2)} ${n(x-w-2)} ${n(y-1)} Z`,c.shadow,null,1,.48)
      const d=`M${n(x-w)} ${n(y+dir*tilt)} Q${n(x)} ${n(y-open-3)} ${n(x+w)} ${n(y-dir*tilt)} Q${n(x)} ${n(y+open)} ${n(x-w)} ${n(y+dir*tilt)} Z`
      s.path(d,'#f4f0dd',ink,1.6)
      s.oval(x,y-.8,6.7,7.1,c.eye,ink,1)
      s.oval(x,y-.5,3.3,4.1,ink)
      s.oval(x-1.8,y-3.4,1.6,1.6,'#fff9e9')
      s.oval(x+2.5,y+2, .65,.65,'#fff9e9',null,1,.7)
      s.path(`M${n(x-w)} ${n(y+dir*tilt)} Q${n(x)} ${n(y-open-3)} ${n(x+w)} ${n(y-dir*tilt)}`, 'none',c.hair,g.sex==='F'?2.4:1.7)
      if(expression==='tired') {
        s.path(`M${n(x-w-1)} ${n(y+dir*tilt)} Q${n(x)} ${n(y-open-5)} ${n(x+w+1)} ${n(y-dir*tilt)} Q${n(x)} ${n(y-open*.15)} ${n(x-w-1)} ${n(y+dir*tilt)} Z`,c.skin,null)
        s.path(`M${n(x-w)} ${n(y+dir*tilt)} Q${n(x)} ${n(y-open*.15)} ${n(x+w)} ${n(y-dir*tilt)}`, 'none',c.hair,g.sex==='F'?2.4:1.9)
        s.path(`M${n(x-w+1)} ${n(y+open+2)} Q${n(x)} ${n(y+open+6)} ${n(x+w-1)} ${n(y+open+2)}`, 'none',c.shadow,1.6,.7)
      }
      const browY=y-23-z.browY*2+(expression==='curious'&&dir===1?-5:0)+(expression==='tense'?4:expression==='tired'?2:0), bw=w*(1+z.browLen*.04), thick=clamp(4+z.browThick*.9,2,7)
      s.path(`M${n(x-bw)} ${n(browY+2)} Q${n(x-3)} ${n(browY-6-z.browArch*1.5)} ${n(x+bw)} ${n(browY)} L${n(x+bw-1)} ${n(browY+thick)} Q${n(x-3)} ${n(browY+thick-4-z.browArch*1.5)} ${n(x-bw)} ${n(browY+thick+2)} Z`,c.hair,null)
      s.oval(200+dir*(q.eyeOff+13),q.noseY+8,15,6,c.blush,null,1,.4)
      if(q.old>.25) { s.path(`M${n(x-w-3)} ${n(y+7)} q${-dir*8} 4 ${-dir*12} 1`, 'none', c.shadow,1.4); s.path(`M${n(x-10)} ${n(y+14)} q10 3 21 -1`, 'none',c.shadow,1.2) }
    }
    if(expression==='tense') s.path(`M197 ${n(q.eyeY-17)} l2 8 M203 ${n(q.eyeY-17)} l-2 8`, 'none',c.shadow,1.3)
    const nw=clamp(9+z.noseW*1.3,5,15)*lerp(1,.74,q.baby), ny=q.noseY
    s.path(`M204 ${n(q.eyeY+11)} q-3 ${n(ny-q.eyeY-22)} -8 ${n(ny-q.eyeY-11)} q8 7 ${n(nw)} 2`, 'none',c.shadow,2.1)
    s.path(`M${n(200-nw)} ${n(ny+5)} q4 -3 7 0 M${n(204+nw*.3)} ${n(ny+5)} q4 -3 6 0`, 'none',c.shadow,1.7)
    const mw=q.mouthW, my=q.mouthY, lip=clamp(3.8+z.lipL*.9,1.8,7), upper=clamp(2+z.lipU*.65,1,5), smile=expression==='warm'?3:expression==='curious'?1:expression==='tense'?-1.6:expression==='tired'?-.6:0
    s.path(`M${n(200-mw)} ${n(my)} Q189 ${n(my-upper-2)} 200 ${n(my-1)} Q211 ${n(my-upper-2)} ${n(200+mw)} ${n(my)} Q200 ${n(my+lip*2)} ${n(200-mw)} ${n(my)} Z`,c.lip,null)
    s.path(`M${n(200-mw)} ${n(my-smile*.35)} Q200 ${n(my+1.5+smile)} ${n(200+mw)} ${n(my-smile*.35)}`, 'none',rgb(mix(C.skinRGB(c.p.mel,g.skin.under),[78,40,35],.65)),1.4)
    if(smile>1)for(const dir of [-1,1])s.path(`M${n(200+dir*(mw+1))} ${n(my-2)} q${dir*2} 2 ${dir*1} 4`, 'none',c.shadow,1.2)
    if(q.old>.2) {
      for(let i=0;i<2;i++) s.path(`M169 ${151+i*9} Q200 ${147+i*9} 231 ${151+i*9}`, 'none',c.shadow,1.1)
      s.path(`M${n(185-nw)} ${n(ny+13)} q-5 9 -4 18 M${n(215+nw)} ${n(ny+13)} q5 9 4 18`, 'none',c.shadow,1.3)
    }
    if(c.p.freckle>.2) { const r=C.makeRng(C.hash32(g.id+':freckles')); for(let i=0;i<Math.round(c.p.freckle*18);i++) s.oval(158+r()*84,ny-2+r()*17,.9,.9,c.shadow,null,1,.7) }
    beard(s,g,q,c,bs,age)
    hairFront(s,g,q,c,h)
    const glasses = opts.glasses === undefined ? g.pref.glasses : opts.glasses
    if(glasses) {
      const round=glasses==='redondo'||glasses==='grosso', sw=glasses==='grosso'?5:2.5
      for(const dir of [-1,1]) {
        const x=200+dir*q.eyeOff,y=q.eyeY
        if(round) s.oval(x,y,28,22,'none',ink,sw)
        else if(glasses==='aviador') s.path(`M${n(x-28)} ${n(y-15)} Q${n(x)} ${n(y-22)} ${n(x+28)} ${n(y-15)} Q${n(x+24)} ${n(y+30)} ${n(x)} ${n(y+26)} Q${n(x-24)} ${n(y+20)} ${n(x-28)} ${n(y-15)} Z`,'none',ink,sw)
        else if(glasses==='gatinho') s.path(`M${n(x-dir*27)} ${n(y-14)} Q${n(x)} ${n(y-22)} ${n(x+dir*34)} ${n(y-26)} L${n(x+dir*25)} ${n(y+16)} Q${n(x)} ${n(y+22)} ${n(x-dir*24)} ${n(y+13)} Z`,'none',ink,sw)
        else s.path(`M${n(x-29)} ${n(y-17)} Q${n(x)} ${n(y-22)} ${n(x+29)} ${n(y-17)} L${n(x+26)} ${n(y+17)} Q${n(x)} ${n(y+21)} ${n(x-26)} ${n(y+17)} Z`,'none',ink,sw)
      }
      s.path(`M${n(200-q.eyeOff+28)} ${n(q.eyeY-3)} Q200 ${n(q.eyeY-11)} ${n(200+q.eyeOff-28)} ${n(q.eyeY-3)}`, 'none',ink,sw)
    }
    return { hair:h.id, beard:bs.id, q }
  }
  function build(g,opts={},ctx) {
    const age=clamp(opts.age??30,0,110), fat=C.bodyFatAt(g,age,opts.fat), body=opts.view==='body'
    const w=body?520:400,h=body?900:500,s=scene(w,h,ctx),c=palette(g,age,opts)
    if(opts.bg!==false) {
      s.rect(0,0,w,h,'#e9e3d6');s.oval(w*.5,h*.46,w*.40,h*.36,'#dbdecf')
      if(body) { s.path('M43 854 H477','none','#c1c5b3',1); s.path('M470 100 V854 M465 100 h10 M465 854 h10','none','#c1c5b3',1) }
    }
    const helpers={geometry,hairBack,face,ink,n,polygon};
    const info=body?root.VectorWardrobe.body(s,g,age,fat,c,opts,helpers):root.VectorWardrobe.portrait(s,g,age,fat,c,opts,helpers)
    return {svg:s.svg(),width:w,height:h,info:{hair:info.hair,beard:info.beard,height:C.heightCm(g,age),fat,age}}
  }
  function render(canvas,g,opts={}) {
    const res=clamp(opts.res??1,.25,3),body=opts.view==='body'
    canvas.width=Math.round((body?520:400)*res);canvas.height=Math.round((body?900:500)*res)
    const ctx=canvas.getContext('2d');ctx.setTransform(res,0,0,res,0,0);ctx.clearRect(0,0,canvas.width/res,canvas.height/res)
    return build(g,opts,ctx).info
  }
  root.VectorCharacter={render,build,geometry,OUTFITS:root.VectorWardrobe.OUTFITS}
})(typeof window!=='undefined'?window:globalThis)
