// Exports the appearance catalog drawn by the Fight Studio (prototypes/face-lab/identity.js)
// as one readable JSON for the Godot fighter generator/editor. Game Design Bible §§5,13,22.
// Run: node tools/build_appearance_catalog.cjs   (output: game/content/appearance_catalog.json)
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const root = path.resolve(__dirname, '..');
const context = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(root, 'prototypes/face-lab/identity.js'), 'utf8') +
  '\nthis.api={SKIN,HAIR_COLORS,HAIR_STYLES,BEARDS,IRIS,HEADS,EYES,BROWS,NOSES,MOUTHS,EARS,MARKS,POPS,BODY_TYPES,BODY_KEYS};', context);
const A = context.api;
const entries = (o, label = (v) => v.n) => Object.entries(o).map(([id, v]) => ({ id, label: label(v) }));
const sexOf = (id) => {
  let m = 0, f = 0;
  for (const [k, p] of Object.entries(A.POPS)) { if (k === 'misto') continue; m += p.m?.[id] || 0; f += p.f?.[id] || 0; }
  return m && f ? 'any' : f ? 'f' : m ? 'm' : 'any';
};
const round = (o) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, Math.round(v * 100) / 100]));
const catalog = {
  version: 1,
  source: 'prototypes/face-lab/identity.js (gerado por tools/build_appearance_catalog.cjs; não editar à mão)',
  note: 'Ids são o que Fighter.appearance guarda. hair.style/beard.style/body.type usam estes ids; body.* são 0–1.',
  skin_tones: Object.entries(A.SKIN).map(([id, [hex, label]]) => ({ id, label, hex })),
  hair_colors: Object.entries(A.HAIR_COLORS).map(([id, [hex, label]]) => ({ id, label, hex })),
  hair_styles: Object.entries(A.HAIR_STYLES).map(([id, v]) => ({ id, label: v.n, sex: sexOf(id), round: v.novo ? v.novo + 1 : 1 })),
  beards: Object.entries(A.BEARDS).map(([id, v]) => ({ id, label: v.n, round: v.novo ? v.novo + 1 : 1 })),
  iris: Object.entries(A.IRIS).map(([id, [hex, label]]) => ({ id, label, hex })),
  heads: entries(A.HEADS), eyes: entries(A.EYES), brows: entries(A.BROWS), noses: entries(A.NOSES),
  mouths: entries(A.MOUTHS), ears: entries(A.EARS), marks: A.MARKS.map((m) => ({ id: m[0], label: m[1] })),
  body_keys: A.BODY_KEYS,
  body_types: Object.entries(A.BODY_TYPES).map(([id, t]) => ({ id, label: t.n, sex: t.sex, generator_body_type: t.gen, build: t.build, weight_class_affinity: t.classes, body: t.body })),
  populations: Object.entries(A.POPS).filter(([k]) => k !== 'misto').map(([id, p]) => ({
    id, label: p.n, beard_chance: p.beardP, skin: round(p.skin), hair_colors: round(p.hairC),
    hair_styles_m: round(p.m), hair_styles_f: round(p.f), beards: round(p.beard),
  })),
};
const out = path.join(root, 'game/content/appearance_catalog.json');
fs.writeFileSync(out, JSON.stringify(catalog, null, 1) + '\n');
console.log(`appearance catalog: ${catalog.hair_styles.length} cabelos, ${catalog.beards.length} barbas, ${catalog.body_types.length} tipos de corpo, ${catalog.populations.length} populações`);
