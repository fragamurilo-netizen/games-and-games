// Catalog recipes modify geometry, not character DNA. No duplicated bitmap assets.
;(function (root) {
  'use strict'
  const C = root.FaceCore
  const cuts = [
    ['pixie-longa', 'Pixie alongada', .35, .24, 'side'], ['bixie', 'Bixie', .5, .47, 'wisp'],
    ['bob-invertido', 'Bob invertido', .65, .66, 'none'], ['bob-assimetrico', 'Bob assimétrico', .8, .8, 'side'],
    ['bob-curtina', 'Bob cortina', .6, .62, 'curtain'], ['bob-microfranja', 'Bob com microfranja', .62, .68, 'straight'],
    ['lob-camadas', 'Lob em camadas', .85, .9, 'curtain'], ['wolf-cut', 'Wolf cut', .95, .96, 'wisp'],
    ['shag-curto', 'Shag curto', .55, .52, 'spiky'], ['shag-longo', 'Shag longo', 1.35, 1.4, 'curtain'],
    ['crop-frances', 'Crop francês', .22, .06, 'straight'], ['taper-baixo', 'Taper baixo', .3, .08, 'swept'],
    ['taper-alto', 'Taper alto', .34, .03, 'quiff'], ['quiff-lateral', 'Topete lateral', .48, .15, 'quiff'],
    ['undercut-longo', 'Undercut alongado', .62, .03, 'side'], ['cortina-curta', 'Cortina curta', .38, .27, 'curtain'],
    ['mullet-moderno', 'Mullet moderno', .82, .18, 'spiky'], ['comprido-repicado', 'Comprido repicado', 1.6, 1.65, 'wisp'],
    ['longo-lateral', 'Comprido lateral', 1.42, 1.48, 'side'], ['franja-arredondada', 'Franja arredondada', 1.08, 1.14, 'straight'],
    ['afro-esculpido', 'Afro esculpido', .68, .55, 'none'], ['afro-taper', 'Afro taper', .32, .08, 'none'],
    ['trancas-curtas', 'Tranças curtas', .65, .68, 'none'], ['locs-medios', 'Locs médios', .95, 1.0, 'none'],
  ]
  const textures = [['liso', 'liso', 0], ['ondas', 'ondulado', .9], ['cachos', 'cacheado', 2.0]]
  for (const [id, name, len, side, fringe] of cuts) for (const [tid, label, curl] of textures) {
    const special = id.startsWith('afro') ? 'afro' : id.startsWith('trancas') ? 'boxbraids' : id.startsWith('locs') ? 'locs' : undefined
    const textureLabel = special === 'afro' ? ['compacto','leve','volumoso'][textures.findIndex(t=>t[0]===tid)] : ['boxbraids','locs'].includes(special) ? ['finos','médios','espessos'][textures.findIndex(t=>t[0]===tid)] : label
    const s = { id: id + '-' + tid, name: name + ' · ' + textureLabel, len, side,
      volTop: .05 + curl * .035 + (id.includes('topete') || id.includes('quiff') ? .12 : 0), volSide: .03 + curl * .025,
      fringe, fringeLen: id.includes('micro') ? .16 : .35, curlBoost: curl,
      part: id.includes('lateral') || id.includes('assimet') ? .5 : .18, layered: id.includes('camadas') || id.includes('shag') ? 1 : 0,
      back: id.includes('mullet') ? 1.05 : side, asymmetric: id.includes('assimet') ? .24 : 0, special, catalogTexture: curl }
    C.HAIR_STYLES.push(s); C.HAIR_BY_ID[s.id] = s
  }
  const beardBases = [
    ['aparada', 'Barba aparada', ['mus', 'chin', 'cheek', 'neck'], { boxed: 1 }],
    ['arredondada', 'Barba arredondada', ['mus', 'chin', 'cheek', 'neck'], { round: 1 }],
    ['pontuda', 'Barba pontuda', ['mus', 'chin', 'cheek', 'neck'], { point: 1 }],
    ['desconectada', 'Barba desconectada', ['mus', 'goateeWide'], { musGap: 1 }],
    ['queixo', 'Barbicha desenhada', ['goatee'], { point: .4 }],
    ['circular-estudio', 'Cavanhaque circular', ['mus', 'goateeRound'], {}],
    ['ancora-estudio', 'Âncora desenhada', ['mus', 'anchor'], { musGap: 1 }],
    ['cortina', 'Cortina de barba', ['chin', 'cheekLow', 'neck'], { round: .6 }],
    ['suicas-estudio', 'Suíças desenhadas', ['chops'], { boxed: .6 }],
    ['bigode-estudio', 'Bigode esculpido', ['mus'], { mus: 'chevron' }],
  ]
  const lengths = [['micro', 'micro', .025], ['leve', 'leve', .065], ['curta', 'curta', .12],
    ['media', 'média', .23], ['cheia', 'cheia', .38], ['longa', 'longa', .6], ['extra', 'extra longa', .88]]
  for (const [id, name, parts, shape] of beardBases) for (const [lid, label, len] of lengths) {
    const s = { id: id + '-' + lid, name: name + ' · ' + label, parts, len, ...shape }
    C.BEARD_STYLES.push(s); C.BEARD_BY_ID[s.id] = s
  }
  root.CharacterCatalog = { hairCount: C.HAIR_STYLES.length, beardCount: C.BEARD_STYLES.length }
})(typeof window !== 'undefined' ? window : globalThis)
