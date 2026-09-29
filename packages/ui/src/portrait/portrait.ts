// Retrato em busto que gira 360°.
// buildPortrait() faz o trabalho caro uma vez (geometria, cabelo, barba);
// renderPortrait() projeta o modelo num ângulo e devolve uma lista de desenho.

import {
  bodyFatAt,
  hairStyleForAge,
  heightCm,
  phenotype,
  type Appearance,
  type BeardStyleId,
  type GlassesId,
  type HairStyleId,
  type Phenotype,
  type ShirtKind,
} from "@paralelo/simulation"
import { buildBeard, drawBeard, type BeardModel } from "./beard"
import { buildBody, drawBody, drawNeck, type Body } from "./body"
import { hairColor, irisColor, skinColor } from "./color"
import { Painter, smoothD, toSvg, type DisplayList } from "./display"
import { drawBrows, drawEar, drawEyes, drawGlasses, drawHeadSkin, drawMouth, drawNose, earIsNear, type FaceCtx } from "./face"
import { FRAME_H, FRAME_W, layoutFace, type FaceLayout } from "./geometry"
import { buildHair, drawHairBack, drawHairFront, hairFrontPolygons, hairShadowOnFace, type HairModel } from "./hair"
import { buildHead, HeadView, type Head } from "./head"
import { GREY_HAIR } from "./color"
import { lerp, mix, mul, smooth, type RGB } from "./math"
import { BEARD_PARAMS, HAIR_PARAMS } from "./styles"

export type PortraitOptions = {
  age: number
  /** 0 muito magro ... 1 obeso; sem valor usa o genoma e a idade */
  fat?: number
  hair?: HairStyleId
  beard?: BeardStyleId
  glasses?: GlassesId | null
  shirt?: ShirtKind
}

export type PortraitModel = {
  appearance: Appearance
  age: number
  L: FaceLayout
  head: Head
  body: Body
  hair: HairModel
  beard: BeardModel | null
  ph: Phenotype
  skin: RGB
  iris: RGB
  browColor: RGB
  glasses: GlassesId | null
  makeup: number
  hairStyle: HairStyleId
  beardStyle: BeardStyleId
  heightCm: number
  fat: number
}

export function buildPortrait(appearance: Appearance, opts: PortraitOptions): PortraitModel {
  const { genome: g, style } = appearance
  const age = Math.max(0, Math.min(110, opts.age))
  const fat = opts.fat ?? bodyFatAt(g, age)
  const L = layoutFace(g, age, fat)
  const ph = phenotype(g, age)
  const noseTip = L.rx * lerp(0.16, 0.3 + 0.05 * g.face.noseL + 0.04 * g.face.noseBridge + 0.03 * g.face.noseTip, L.growth) * (1 + L.old * 0.1)
  const head = buildHead(L, noseTip, 0)
  const hairStyle = age < 1.2 ? "bebe" : opts.hair ?? hairStyleForAge(g, style, age)
  const beardStyle: BeardStyleId = opts.beard ?? (g.sex === "M" ? style.beard : "nenhuma")
  const hair = buildHair(L, head, HAIR_PARAMS[hairStyle], ph, age, g.seed)
  const beardCol = mix(hairColor(ph.hairEumelanin, ph.hairPheomelanin), [150, 70, 30], g.hair.beardRed * 0.5)
  const beard = buildBeard(L, BEARD_PARAMS[beardStyle], beardCol, ph.beardGrey, g.hair.beardDensity, ph.texture, age, g.seed)
  const body = buildBody(L, g.sex === "F", age, opts.shirt ?? style.shirt, style.shirtHue, style.shirtTone)
  let skin = skinColor(ph.melanin, g.skin.undertone)
  skin = mix(skin, [skin[0] * 0.97, skin[1] * 0.95, skin[2] * 0.95], L.old * 0.5)
  return {
    appearance,
    age,
    L,
    head,
    body,
    hair,
    beard,
    ph,
    skin,
    iris: irisColor(ph.eyeDarkness, ph.eyeGreen),
    browColor: mix(hairColor(ph.hairEumelanin, ph.hairPheomelanin), GREY_HAIR, ph.grey * 0.7),
    glasses: opts.glasses !== undefined ? opts.glasses : age > 7 ? style.glasses : null,
    makeup: age >= 15 ? style.makeup : 0,
    hairStyle,
    beardStyle,
    heightCm: heightCm(g, age),
    fat,
  }
}

/** yaw em radianos: 0 de frente, π/2 perfil, π de costas. */
export function renderPortrait(m: PortraitModel, yaw: number, idPrefix = "p"): DisplayList {
  const p = new Painter(FRAME_W, FRAME_H, idPrefix)
  const hv = new HeadView(m.head, yaw)
  const view = hv.view
  const { L, skin } = m
  const sil = hv.silhouette(3)
  const headD = smoothD(sil)
  const headClip = p.clip(headD)
  const ctx: FaceCtx = { p, hv, L, g: m.appearance.genome, ph: m.ph, skin, age: m.age, makeup: m.makeup, headClip }
  const facingFront = Math.cos(yaw)

  // 1. cabelo de trás
  drawHairBack(p, m.hair, view)
  // 2. corpo e pescoço
  drawBody(p, m.body, L, view, skin, L.female)
  drawNeck(p, m.body, L, view, skin)
  // 3. orelha do lado de lá
  const near = [-1, 1].map((s) => earIsNear(ctx, s))
  for (const [i, s] of [-1, 1].entries()) if (!near[i]) drawEar(ctx, s)
  // 4. cabeça
  drawHeadSkin(ctx, sil)
  if (facingFront > -0.35) {
    drawEyes(ctx, m.iris)
    drawBrows(ctx, m.browColor)
  }
  if (facingFront > -0.3) {
    if (m.beard) drawBeard(p, m.beard, hv, headClip)
    drawNose(ctx)
    drawMouth(ctx)
  } else if (m.beard && facingFront > -0.6) drawBeard(p, m.beard, hv, headClip)
  for (const [i, s] of [-1, 1].entries()) if (near[i]) drawEar(ctx, s)
  // 5. cabelo da frente
  const front = hairFrontPolygons(m.hair, view)
  hairShadowOnFace(p, front, headClip)
  drawHairFront(p, m.hair, view, front, L)
  // 6. óculos
  if (m.glasses && facingFront > 0.05) drawGlasses(ctx, m.glasses)
  void mul
  void smooth
  return p.list
}

export function portraitSvg(appearance: Appearance, opts: PortraitOptions & { yaw?: number; background?: string }): string {
  const m = buildPortrait(appearance, opts)
  return toSvg(renderPortrait(m, opts.yaw ?? 0), opts.background ? { background: opts.background } : {})
}
