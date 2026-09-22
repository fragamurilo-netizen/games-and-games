/** Unified delivery contract. DOM/provider doubles only: no ad network is loaded. */
'use strict';
const assert = require('node:assert/strict');
const { El, adBox, makeEnvironment, boot, mountAd, config } = require('./helpers/runtime-harness');
const failures = [];
let passed = 0;
function test(name, fn) {
  try { fn(); passed++; console.log('PASS ' + name); }
  catch (e) { failures.push(name + ': ' + e.stack); console.log('FAIL ' + name + ': ' + e.message); }
}
function flush(env) { for (let i = 0; env.frames.length && i < 250; i++) env.frames.splice(0).forEach(cb => cb()); }
function scene(delivery, options, beforeBoot) {
  const cfg = config(); cfg.delivery_v2 = Object.assign({ latency_memory: true, diagnostic_sample_rate: 1 }, delivery || {});
  const env = makeEnvironment(cfg, Object.assign({ now: 1000, scrollY: 0, innerHeight: 800,
    plannedBodyCount: 1, renderedBodyCount: 2, structuralBodyCapacity: 2,
    documentHeight: 40000, contentHeight: 6000, articleWords: 1600 }, options || {}));
  if (beforeBoot) beforeBoot(env);
  return { env, runtime: boot(env) };
}
function place(s, spec) {
  return mountAd(s.runtime, s.env, Object.assign({ placement: 'article-a1', slot: 'a1', surface: 'article',
    tier: 'premium', near: 2000, predictive: true, top: 100 }, spec || {}));
}

test('The sole delivery policy admits a safe reached reserve on mobile and desktop', () => {
  [360, 1440].forEach(innerWidth => {
    const s = scene({}, { innerWidth }); place(s); place(s, { placement: 'article-a2', slot: 'a2', top: 750 }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 2);
    const reserve = s.runtime.inspect().manual[1];
    assert.equal(reserve.delivery.budgetPath, 'reached-reserve');
    assert.equal(reserve.delivery.reachedReserveReason, 'in-useful-viewport');
    assert.notEqual(s.runtime.inspect().engine.governor.state, 'expansion');
    assert.equal(s.runtime.inspect().evolution.reserveAdmission, 'reached');
  });
});

test('Reached mode does not release cold reserves or exceed structural capacity', () => {
  const s = scene(); place(s);
  place(s, { placement: 'article-a2', slot: 'a2', top: 1400 }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.runtime.inspect().manual[1].state, 'waiting-opportunity-budget');
  const t = scene({}, { plannedBodyCount: 1, renderedBodyCount: 1, structuralBodyCapacity: 1 });
  place(t); place(t, { placement: 'article-a2', slot: 'a2', top: 750 }); flush(t.env);
  assert.equal(t.env.win.adsbygoogle.length, 1);
});

test('Reached mode preserves real spacing, consent and background gates', () => {
  const s = scene(); place(s);
  place(s, { placement: 'article-a2', slot: 'a2', top: 300 }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.runtime.inspect().manual[1].state, 'waiting-content-density');
  const t = scene(); place(t);
  t.env.doc.visibilityState = 'hidden';
  place(t, { placement: 'article-a2', slot: 'a2', top: 750 }); flush(t.env);
  assert.equal(t.env.win.adsbygoogle.length, 1);
  assert.equal(t.runtime.inspect().manual[1].state, 'waiting-page-visible');
  const u = scene(); place(u);
  const box = adBox({ placement: 'article-a2', slot: 'consent-reserve', tier: 'premium', surface: 'article', top: 750 });
  box.parentElement = u.env.content; u.env.adBoxes.push(box); u.env.pushTargets.push(box.children[0].content.firstElementChild);
  u.runtime.mount(box, { near: 2000, tier: 'premium', gate: true }); flush(u.env);
  assert.equal(u.env.win.adsbygoogle.length, 1);
  assert.equal(u.runtime.inspect().manual[1].state, 'waiting-consent');
  u.env.win.GOAdsConsent = { permitted: () => true };
  u.env.doc.dispatchEvent({ type: 'go:consent-change' }); flush(u.env);
  assert.equal(u.env.win.adsbygoogle.length, 2);
  u.env.doc.dispatchEvent({ type: 'go:consent-change' }); flush(u.env);
  assert.equal(u.env.win.adsbygoogle.length, 2, 'consent events never request the same host twice');
});

test('Reached mode anticipates one imminent safe reserve before the reader reaches a blank host', () => {
  const s = scene(); place(s);
  place(s, { placement: 'article-a2', slot: 'imminent', top: 1000 }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
  s.env.advance(200); s.env.setScroll(100); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 2);
  const reserve = s.runtime.inspect().manual[1];
  assert.equal(reserve.delivery.reachedReserveReason, 'predicted-arrival');
  assert.ok(reserve.delivery.distanceAtRequest > 0 && reserve.delivery.distanceAtRequest <= 400);
});

test('Reached admission does not depend on storage or a bootstrap and ignores stale mode flags', () => {
  [false, true].forEach(storagePermission => {
    let bootstrapReads = 0, createdScripts = 0, storageReads = 0, storageWrites = 0;
    const s = scene({ reserve_admission: 'governor' }, { storagePermission }, env => {
      Object.defineProperty(env.win, 'GOAdsExperiment', { get() { bootstrapReads++; throw new Error('obsolete bootstrap accessed'); } });
      env.doc.createElement = tag => { if (String(tag).toLowerCase() === 'script') createdScripts++; return new El(tag); };
      if (!storagePermission) {
        env.win.localStorage = env.win.sessionStorage = {
          getItem() { storageReads++; throw new Error('storage forbidden'); },
          setItem() { storageWrites++; throw new Error('storage forbidden'); }
        };
      }
    });
    const first = place(s); const second = place(s, { placement: 'article-a2', slot: 'a2', top: 750 }); flush(s.env);
    s.runtime.mount(second, { gate: false }); s.runtime.scan(s.env.doc); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 2);
    assert.equal(s.runtime.inspect().evolution.reserveAdmission, 'reached');
    [first, second].forEach(box => assert.equal(box.children.find(node => node.tagName === 'INS').hasAttribute('data-ad-channel'), false));
    assert.equal(bootstrapReads, 0); assert.equal(createdScripts, 0);
    assert.equal(storageReads, 0); assert.equal(storageWrites, 0);
  });
});

test('A retained reserve without primary hosts requires reached admission, never an advance budget', () => {
  [360, 1440].forEach(innerWidth => {
    const s = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 });
    place(s, { top: 1400 }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 0);
    assert.equal(s.runtime.inspect().manual[0].state, 'waiting-opportunity-budget');
    s.env.setScroll(800); flush(s.env);
    const view = s.runtime.inspect();
    assert.equal(s.env.win.adsbygoogle.length, 1);
    assert.equal(view.engine.article.bodyBudget, 0);
    assert.equal(view.manual[0].delivery.budgetPath, 'reached-reserve');
    assert.equal(view.manual[0].delivery.reachedReserveReason, 'in-useful-viewport');
    place(s, { placement: 'article-a2', slot: 'beyond-capacity', top: 750 }); flush(s.env);
    assert.equal(s.env.win.adsbygoogle.length, 1);
  });
});

test('Reached admission still requires planner telemetry, a rendered host and structural capacity', () => {
  [360, 1440].forEach(innerWidth => {
    ['missing-telemetry', 'zero-rendered', 'zero-capacity'].forEach(missing => {
      const s = scene({}, { innerWidth, plannedBodyCount: 0, renderedBodyCount: 1, structuralBodyCapacity: 1 }, env => {
        if (missing === 'missing-telemetry') {
          env.content.removeAttribute('data-go-ad-plan-planned-body');
          env.content.removeAttribute('data-go-ad-plan-body-capacity');
        } else {
          env.content.setAttribute(missing === 'zero-rendered' ? 'data-go-ad-plan-rendered-body' : 'data-go-ad-plan-body-capacity', '0');
        }
      });
      place(s); flush(s.env);
      assert.equal(s.env.win.adsbygoogle.length, 0, missing);
      assert.equal(s.runtime.inspect().manual[0].state, 'waiting-opportunity-budget');
    });
  });
});

test('Compatible consented session latency is available on the next page before its first fill', () => {
  const stored = { version: 2, profile: 'mobile:unknown:normal', updatedAt: Date.now(), samples: [2200, 2300, 2400] };
  const s = scene({}, { storagePermission: true, sessionStorageData: { go_ads_fill_latency_v2: JSON.stringify(stored) } });
  place(s); flush(s.env);
  assert.equal(s.runtime.inspect().manual[0].delivery.responseEstimateMs, 2400);
  assert.equal(s.runtime.inspect().evolution.latencyMemory.importedSamples, 3);
});

test('Latency memory ignores expired, incompatible, malformed and nonconsented storage', () => {
  [
    { version: 2, profile: 'mobile:unknown:normal', updatedAt: Date.now() - 1800001, samples: [3000, 3000, 3000] },
    { version: 2, profile: 'desktop:unknown:normal', updatedAt: Date.now(), samples: [3000, 3000, 3000] },
    { version: 2, profile: 'mobile:unknown:normal', updatedAt: Date.now(), samples: ['3000', null, -2, 9000] }
  ].forEach(stored => {
    const s = scene({}, { storagePermission: true, sessionStorageData: { go_ads_fill_latency_v2: JSON.stringify(stored) } });
    place(s); flush(s.env); assert.equal(s.runtime.inspect().manual[0].delivery.responseEstimateMs, 1050);
  });
  let reads = 0, writes = 0;
  const s = scene({}, {}, env => { env.win.sessionStorage = { getItem: () => { reads++; return null; }, setItem: () => { writes++; } }; });
  place(s); s.env.advance(500); flush(s.env);
  assert.equal(reads, 0); assert.equal(writes, 0);
});

test('Latency memory changes profile on a viewport breakpoint without refreshing delivered units', () => {
  const stored = { version: 2, profile: 'mobile:unknown:normal', updatedAt: Date.now(), samples: [2200, 2300, 2400] };
  const s = scene({}, { storagePermission: true, plannedBodyCount: 2, sessionStorageData: { go_ads_fill_latency_v2: JSON.stringify(stored) } });
  place(s); flush(s.env); assert.equal(s.runtime.inspect().manual[0].delivery.responseEstimateMs, 2400);
  s.env.win.innerWidth = 1440;
  place(s, { placement: 'article-a2', slot: 'desktop-next', top: 750 }); flush(s.env);
  assert.equal(s.runtime.inspect().manual[1].delivery.responseEstimateMs, 1050);
  assert.equal(s.runtime.inspect().evolution.latencyMemory.profile, 'desktop:unknown:normal');
  assert.equal(s.env.win.adsbygoogle.length, 2);
});

test('Only foreground filled latency is learned and saved; empty and optimized are excluded', () => {
  ['unfilled', 'unfill-optimized'].forEach(answer => {
    const s = scene({}, { storagePermission: true, providerDelayMs: 900 }); place(s, { answer }); flush(s.env);
    s.env.advance(1000); flush(s.env);
    assert.equal(s.env.win.sessionStorage.getItem('go_ads_fill_latency_v2'), null);
    assert.equal(s.runtime.inspect().responsePresentSamples, 0);
  });
  const filled = scene({}, { storagePermission: true, providerDelayMs: 1900 }); place(filled); flush(filled.env);
  filled.env.advance(2000); flush(filled.env);
  const data = JSON.parse(filled.env.win.sessionStorage.getItem('go_ads_fill_latency_v2'));
  assert.deepEqual(data.samples, [1900]);
  assert.equal(Object.keys(data).sort().join(','), 'profile,samples,updatedAt,version');
  const hidden = scene({}, { storagePermission: true, providerDelayMs: 1900 }); place(hidden); flush(hidden.env);
  hidden.env.doc.visibilityState = 'hidden'; hidden.env.doc.dispatchEvent({ type: 'visibilitychange' });
  hidden.env.advance(2000); flush(hidden.env);
  assert.equal(hidden.env.win.sessionStorage.getItem('go_ads_fill_latency_v2'), null);
});

test('Pending priority uses geometry from this sweep, not last sweep distance', () => {
  const s = scene({}, { plannedBodyCount: 1, renderedBodyCount: 1, structuralBodyCapacity: 1 });
  const first = place(s, { slot: 'far-later', top: 1800 });
  const second = place(s, { placement: 'article-a2', slot: 'visible-now', top: 6000 }); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 0);
  first.rect = Object.assign({}, first.rect, { top: 1000, bottom: 1250, y: 1000 });
  second.rect = Object.assign({}, second.rect, { top: 100, bottom: 350, y: 100 });
  s.env.onScroll(); flush(s.env);
  const requested = s.runtime.inspect().manual.filter(record => record.requested);
  assert.equal(requested.length, 1);
  assert.equal(requested[0].slot, 'visible-now');
});

function attachDom(env) {
  function descendants(node) { return (node.children || []).flatMap(child => [child].concat(descendants(child))); }
  function matches(node, selector) {
    if (selector === 'script') return node.tagName === 'SCRIPT';
    if (selector === '.go-archive-row') return node.classList.contains('go-archive-row');
    if (selector === '[data-go-ad-placement][data-go-ad-options]') return node.hasAttribute('data-go-ad-placement') && node.hasAttribute('data-go-ad-options');
    return false;
  }
  function decorate(node) {
    node.matches = selector => matches(node, selector);
    node.querySelectorAll = selector => descendants(node).filter(child => matches(child, selector));
    node.remove = () => {
      if (!node.parentElement) return;
      const i = node.parentElement.children.indexOf(node);
      if (i >= 0) node.parentElement.children.splice(i, 1);
      node.parentElement = null;
    };
    node.insertBefore = (child, before) => {
      let index = before ? node.children.indexOf(before) : -1;
      if (index < 0) index = node.children.length;
      node.children.splice(index, 0, child); child.parentElement = node;
      descendants(child).filter(item => item.tagName === 'SCRIPT').forEach(() => { env.executedAdScripts++; });
      if (child.hasAttribute('data-go-ad-placement')) { env.offBoxes.push(child); child._docTop = child.rect.top + env.win.pageYOffset; }
    };
    Object.defineProperty(node, 'nextSibling', { configurable: true, get() {
      if (!node.parentElement) return null;
      return node.parentElement.children[node.parentElement.children.indexOf(node) + 1] || null;
    } });
    return node;
  }
  env.executedAdScripts = 0;
  const feed = decorate(new El('div', { 'data-go-ad-listing-root': '1', 'data-go-ad-listing-card-selector': '.go-archive-row' }));
  const footer = decorate(new El('footer'));
  function addCards(n) { for (let i = 0; i < n; i++) feed.appendChild(decorate(new El('article', { class: 'go-archive-row' }))); }
  function reserve(slot, after, top) {
    const template = decorate(new El('template', { 'data-go-listing-reserve': '1', 'data-go-listing-after': String(after) }));
    const box = decorate(adBox({ placement: 'listing-f' + (slot === 'f4' ? '4' : '5'), slot, surface: 'listing', tier: 'deep', top: top || 5000 }));
    box.setAttribute('data-go-ad-options', JSON.stringify({ near: 1200, tier: 'deep', predictive: true, gate: false }));
    box.appendChild(decorate(new El('script')));
    env.pushTargets.push(box.children[0].content.firstElementChild);
    template.content = { firstElementChild: box }; footer.appendChild(template);
    return { template, box };
  }
  env.doc.querySelectorAll = selector => {
    if (selector === '[data-go-ad-listing-root="1"]') return [feed];
    if (selector === 'template[data-go-listing-reserve]') return footer.children.filter(node => node.hasAttribute('data-go-listing-reserve'));
    if (selector === '[data-go-ad-placement][data-go-ad-options]') return feed.querySelectorAll(selector);
    return [];
  };
  return { feed, footer, addCards, reserve };
}

test('F4/F5 materialize only after real card boundaries, strip scripts before insertion, and mount once', () => {
  const s = scene(); const dom = attachDom(s.env);
  dom.addCards(10); const f4 = dom.reserve('f4', 12, 5000); const f5 = dom.reserve('f5', 15, 7500);
  s.runtime.scan(s.env.doc); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 0);
  dom.addCards(3); s.env.doc.dispatchEvent({ type: 'go:content-updated', detail: { scope: dom.feed } }); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 1);
  assert.equal(dom.feed.children.indexOf(f4.box), 12);
  assert.equal(s.env.executedAdScripts, 0);
  assert.equal(s.env.win.adsbygoogle.length, 0, 'deeply appended host does not request before reader approaches');
  dom.addCards(2); s.env.doc.dispatchEvent({ type: 'go:content-updated', detail: { root: dom.feed } }); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 2);
  assert.equal(dom.feed.children.indexOf(f5.box), 16);
  s.runtime.scan(s.env.doc); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 2);
  assert.equal(s.runtime.inspect().evolution.dynamic.materialized, 2);
  s.env.setScroll(5000); flush(s.env);
  s.env.setScroll(7500); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 2);
  s.runtime.scan(dom.feed); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 2);
});

test('Continuation rejects a slot already registered instead of recycling it', () => {
  const s = scene(); place(s, { placement: 'listing-f4', slot: 'f4', top: 100, surface: 'listing' }); flush(s.env);
  const dom = attachDom(s.env); dom.addCards(12); dom.reserve('f4', 12);
  s.runtime.scan(s.env.doc); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 1);
  assert.equal(s.runtime.inspect().evolution.dynamic.skippedDuplicate, 1);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('Continuation binds only the initial feed and initial manifest', () => {
  const s = scene(); const dom = attachDom(s.env);
  dom.addCards(10); dom.reserve('f4', 12); s.runtime.scan(s.env.doc);
  dom.reserve('f5', 15); // injected after initial binding: must remain outside the inventory manifest
  dom.addCards(5); s.runtime.scan(dom.feed); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 1);
  assert.equal(s.runtime.inspect().manual[0].slot, 'f4');
  dom.feed.isConnected = false;
  const replacement = attachDom(s.env); replacement.addCards(20); replacement.reserve('f5', 15);
  s.runtime.scan(replacement.feed); flush(s.env);
  assert.equal(s.runtime.inspect().manual.length, 1);
});

test('Sampled diagnostics are bounded local objects/events and distinguish opportunities from fills', () => {
  const s = scene(); place(s); place(s, { placement: 'article-a2', slot: 'a2', top: 300 }); flush(s.env);
  let events = 0;
  s.env.doc.addEventListener('go:ads-local-diagnostic', () => { events++; });
  for (let i = 0; i < 8; i++) s.runtime.flushDiagnostics('test');
  assert.equal(events, 8); assert.equal(s.runtime.diagnosticBuffer().length, 4);
  const snapshot = s.runtime.diagnosticSnapshot('test');
  assert.equal(snapshot.positions[1].opportunityReached, true);
  assert.equal(snapshot.positions[1].requested, false);
  assert.equal(snapshot.reserveAdmission, 'reached');
  assert.equal(Object.prototype.hasOwnProperty.call(snapshot, 'experiment'), false);
  assert.equal(Object.prototype.hasOwnProperty.call(s.runtime.inspect().evolution, 'experiment'), false);
  const encoded = JSON.stringify(snapshot);
  assert.equal(/earnings|page_rpm|https?:|cookie|user_id/.test(encoded), false);
  const off = scene({ diagnostic_sample_rate: 0 }); place(off); flush(off.env);
  assert.equal(off.runtime.flushDiagnostics('test'), null);
});

console.log(JSON.stringify({ suite: 'runtime-unified', scenarios: passed + failures.length, passed, failed: failures.length, realAdRequests: 0 }));
if (failures.length) { failures.forEach(message => console.error(message)); process.exitCode = 1; }
