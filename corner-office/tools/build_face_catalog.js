// Exporta as tabelas do gerador facial (prototypes/face-lab/identity.js) para
// game/content/face_catalog.json, lidas pelo retrato nativo da Godot
// (game/identity/portrait_painter.gd). identity.js continua sendo a fonte:
// rode `node tools/build_face_catalog.js` sempre que ele mudar.
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "prototypes/face-lab/identity.js"), "utf8");
const ctx = { console, window: {}, document: { createElement: () => ({ getContext: () => ({}) }) } };
vm.createContext(ctx);
vm.runInContext(
  source +
    "\n;this.__genFace=genFace;this.__out={SKIN,HAIR_COLORS,IRIS,HEADS,EYES,BROWS,NOSES,MOUTHS,EARS,HAIR_STYLES,BEARDS,MARKS,POPS,CANON,SHORTS,GLOVES,PAL};",
  ctx,
);
const o = ctx.__out;
const names = (t) => Object.fromEntries(Object.entries(t).map(([k, v]) => [k, Array.isArray(v) ? v[1] : v.n]));
const colors = (t) => Object.fromEntries(Object.entries(t).map(([k, v]) => [k, v[0]]));
const shapes = (t) => Object.fromEntries(Object.entries(t).map(([k, v]) => [k, v]));
const out = {
  _note: "Gerado por tools/build_face_catalog.js a partir de prototypes/face-lab/identity.js. Não edite à mão.",
  palette: o.PAL,
  skin: colors(o.SKIN),
  skin_names: names(o.SKIN),
  hair_colors: colors(o.HAIR_COLORS),
  hair_color_names: names(o.HAIR_COLORS),
  iris: colors(o.IRIS),
  heads: shapes(o.HEADS),
  eyes: shapes(o.EYES),
  brows: shapes(o.BROWS),
  noses: shapes(o.NOSES),
  mouths: shapes(o.MOUTHS),
  ears: shapes(o.EARS),
  hair_styles: names(o.HAIR_STYLES),
  beards: names(o.BEARDS),
  marks: Object.fromEntries(o.MARKS.map((m) => [m[0], { name: m[1], kind: m[2] }])),
  populations: Object.fromEntries(Object.entries(o.POPS).filter(([k]) => k !== "misto")),
  canon: o.CANON,
  shorts: colors(o.SHORTS),
  gloves: colors(o.GLOVES),
};
const target = path.join(root, "game/content/face_catalog.json");
fs.writeFileSync(target, JSON.stringify(out, null, 1) + "\n");
console.log(`face catalog: ${Object.keys(out.hair_styles).length} cabelos, ${Object.keys(out.beards).length} barbas, ${Object.keys(out.populations).length} populações -> ${target}`);

// Referência para o teste de paridade do gerador facial GDScript × JS.
const samples = [[1, "misto", "m"], [42, "latino", "m"], [777, "caucaso", "m"], [2027, "afro_diaspora", "f"], [123456, "leste_asiatico", "f"], [99, "europa_norte", "m"]];
const reference = samples.map(([seed, pop, sex]) => ({ seed, pop, sex, face: ctx.__genFace(seed, pop, sex) }));
fs.mkdirSync(path.join(root, "game/tests/fixtures"), { recursive: true });
fs.writeFileSync(path.join(root, "game/tests/fixtures/genface_reference.json"), JSON.stringify(reference, null, 1) + "\n");
