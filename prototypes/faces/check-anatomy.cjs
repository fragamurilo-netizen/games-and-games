// Run: node prototypes/faces/check-anatomy.cjs (no installed packages required).
const assert = require('node:assert/strict')
require('./faces-core.js')
const C = globalThis.FaceCore
let cases = 0
for (const sex of ['F', 'M']) {
  for (const ancestry of Object.keys(C.ANCESTRY)) {
    const g = C.makeGenome('anatomy-' + ancestry, { sex, ancestry })
    assert.deepEqual(g, C.makeGenome(g.id, { sex, ancestry }), 'seed must reproduce genome')
    const before = JSON.stringify(g)
    for (const age of [0, 1, 6, 14, 19, 30, 65, 85, 110]) {
      for (const fat of [0, 0.5, 1]) {
        for (const muscle of [0, 1]) {
          const b = C.bodyLayout(g, { age, fat, muscle })
          assert.deepEqual(b, C.bodyLayout(g, { age, fat, muscle }))
          for (const [key, value] of Object.entries(b)) if (typeof value === 'number') {
            assert(Number.isFinite(value) && (key === 'stoop' || value >= 0), `${sex}/${age}: invalid ${key}`)
          }
          assert(b.height > 30 && b.height < 215)
          assert(b.head < b.shoulderY && b.shoulderY < b.chestY)
          assert(b.chestY < b.waistY && b.waistY < b.hipY && b.hipY < b.crotch)
          assert(b.crotch < b.kneeY && b.kneeY < b.ankleY && b.ankleY < 1)
          assert(b.wrist < b.upperArm && b.neck < b.shoulders)
          const face = C.layout(g, { age, fat })
          assert(face.outline.every(p => p.every(Number.isFinite)))
          cases++
        }
      }
    }
    assert.equal(JSON.stringify(g), before, 'body queries must not mutate genome')
    const thin = C.bodyLayout(g, { age: 30, fat: 0, muscle: 0 })
    const heavy = C.bodyLayout(g, { age: 30, fat: 1, muscle: 0 })
    const strong = C.bodyLayout(g, { age: 30, fat: 0, muscle: 1 })
    assert(heavy.waist > thin.waist && heavy.thigh > thin.thigh)
    assert(strong.shoulders > thin.shoulders && strong.upperArm > thin.upperArm)
    assert.equal(C.bodyLayout(g, { age: 0, muscle: 1 }).muscle, 0)
    const legacy = structuredClone(g)
    for (const key of Object.keys(C.bodyTraits(g))) delete legacy.body[key]
    assert.deepEqual(C.bodyTraits(legacy), C.bodyTraits(g), 'legacy seeds keep their derived body')
  }
}
const mom = C.makeGenome('mother', { sex: 'F' }), dad = C.makeGenome('father', { sex: 'M' })
for (let i = 0; i < 40; i++) {
  const seed = 'child-' + i
  const child = C.childGenome(mom, dad, seed)
  assert.deepEqual(child, C.childGenome(mom, dad, seed))
  for (const [key, value] of Object.entries(C.bodyTraits(child))) {
    assert(value >= 0 && value <= 1, `inherited ${key} must be normalized`)
  }
  assert.notDeepEqual(C.bodyTraits(child), C.bodyTraits(mom), 'children must vary from parents')
}
console.log(`Anatomy checks passed: ${cases} age / ancestry / body combinations and 40 inherited genomes.`)
