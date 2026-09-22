/** Responsive geometry regressions. Local DOM/provider doubles; no ad network. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { El, adBox, makeEnvironment, boot, mountAd, config } = require('./helpers/runtime-harness');
let passed = 0;
const failures = [];
function test(name, fn) {
  try { fn(); passed++; console.log('PASS ' + name); }
  catch (error) { failures.push(name + ': ' + error.stack); console.error('FAIL ' + name + ': ' + error.message); }
}
function flush(env) { for (let i = 0; env.frames.length && i < 200; i++) env.frames.splice(0).forEach(fn => fn()); }
function scene(change) {
  const env = makeEnvironment(config(), { now: 1000, scrollY: 0, innerWidth: 360, innerHeight: 800,
    plannedBodyCount: 1, renderedBodyCount: 2, structuralBodyCapacity: 2, contentHeight: 6000, documentHeight: 10000 });
  const listeners = {}, add = env.win.addEventListener, remove = env.win.removeEventListener;
  env.win.addEventListener = (name, fn, options) => { listeners[name] = fn; add(name, fn, options); };
  env.win.removeEventListener = (name, fn) => { delete listeners[name]; remove(name, fn); };
  env.resize = () => { if (listeners.resize) listeners.resize(); flush(env); };
  if (change) change(env);
  return { env, runtime: boot(env) };
}
function critical(s) {
  return mountAd(s.runtime, s.env, { placement: 'topscroll', slot: 'geometry-top', surface: 'topscroll',
    tier: 'reach', critical: true, top: 20, inContent: false });
}

test('A visible document with no viewport height waits, then requests once after resize', () => {
  const s = scene(env => { env.win.innerHeight = 0; env.doc.documentElement.clientHeight = 0; });
  const box = critical(s); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 0);
  assert.equal(s.runtime.inspect().manual[0].state, 'waiting-viewport-geometry');
  assert.equal(box.children[0].tagName, 'TEMPLATE');
  s.env.win.innerHeight = 800; s.env.resize();
  assert.equal(s.env.win.adsbygoogle.length, 1);
  s.env.resize(); s.runtime.mount(box, {}); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('A positive document client height remains a valid fallback for zero window innerHeight', () => {
  const s = scene(env => { env.win.innerHeight = 0; env.doc.documentElement.clientHeight = 800; });
  critical(s); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('A viewport without width does not consume a request and recovers through clientWidth', () => {
  const s = scene(env => { env.win.innerWidth = 0; env.doc.documentElement.clientWidth = 0; });
  critical(s); flush(s.env);
  assert.equal(s.env.win.adsbygoogle.length, 0);
  assert.equal(s.runtime.inspect().manual[0].state, 'waiting-viewport-geometry');
  s.env.doc.documentElement.clientWidth = 360; s.env.resize();
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('Viewport resize preserves the requested provider node and iframe without refresh', () => {
  const s = scene(); const box = critical(s); flush(s.env);
  const ins = box.children.find(node => node.tagName === 'INS');
  const iframe = new El('iframe', { id: 'google_ads_iframe_geometry', width: '300', height: '250' });
  ins.appendChild(iframe);
  s.env.win.innerWidth = 1440; s.env.win.innerHeight = 0; s.env.doc.documentElement.clientHeight = 0; s.env.resize();
  s.env.win.innerWidth = 360; s.env.win.innerHeight = 800; s.env.resize();
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(box.children.find(node => node.tagName === 'INS'), ins);
  assert.equal(ins.children[0], iframe);
  assert.equal(iframe.getAttribute('width'), '300');
  assert.equal(iframe.getAttribute('height'), '250');
  assert.equal(box.hidden, false);
});

function stickyScene(options) {
  const opts = Object.assign({ width: 300, creativeHeight: 600, height: 632, viewportHeight: 900, offset: '88px', left: 900 }, options || {});
  const s = scene(env => {
    env.win.innerWidth = 1440; env.win.innerHeight = opts.viewportHeight;
    env.observationEntries = []; env.resizeObserverEntries = []; env.accountAnchors = [];
    const BaseMutationObserver = env.win.MutationObserver;
    env.win.MutationObserver = function (callback) {
      const observer = new BaseMutationObserver(callback), observe = observer.observe;
      observer.observe = (node, options) => { env.observationEntries.push({ node, options, callback }); observe(node, options); };
      return observer;
    };
    env.emitAnchorMutation = mutation => env.observationEntries.filter(entry => entry.node === env.body && entry.options.childList).forEach(entry => entry.callback([mutation]));
    const query = env.doc.querySelectorAll;
    env.doc.querySelectorAll = selector => String(selector).includes('data-anchor-status')
      ? env.accountAnchors.filter(anchor => anchor.hasAttribute('data-anchor-status') && (!String(selector).includes('="displayed"') || anchor.getAttribute('data-anchor-status') === 'displayed'))
      : query(selector);
    env.insertAccountAnchor = (rect, status) => {
      const attrs = { class: 'adsbygoogle' };
      if (status !== null) attrs['data-anchor-status'] = status || 'displayed';
      const anchor = new El('ins', attrs, rect); anchor.parentElement = env.body;
      env.accountAnchors.push(anchor);
      env.emitAnchorMutation({ type: 'childList', addedNodes: [anchor], removedNodes: [] });
      return anchor;
    };
    if (opts.anchorHeight) {
      env.accountAnchor = env.insertAccountAnchor({
        top: opts.viewportHeight - opts.anchorHeight, bottom: opts.viewportHeight,
        left: 0, right: 1440, width: 1440, height: opts.anchorHeight });
    }
    const style = env.win.getComputedStyle;
    env.win.getComputedStyle = node => Object.assign({}, style(node), { top: opts.offset, insetBlockStart: opts.offset });
    env.win.ResizeObserver = function (callback) {
      const targets = new Set(); env.resizeObserverEntries.push({ targets, callback });
      this.observe = node => targets.add(node); this.unobserve = node => targets.delete(node); this.disconnect = () => targets.clear();
    };
    env.resizeObserved = target => { env.resizeObserverEntries.filter(entry => entry.targets.has(target)).forEach(entry => entry.callback([{ target }])); flush(env); };
  });
  const box = adBox({ placement: 'sidebar-desktop', slot: 'geometry-side', surface: 'article-sidebar', tier: 'premium',
    top: 100, left: opts.left, width: opts.width, height: opts.height });
  box.classList.add('go-article-sidebar__ad--sticky');
  box.classList.add('go-game-sidebar-revenue');
  box.parentElement = s.env.body; s.env.offBoxes.push(box);
  if (opts.gameNavigation !== undefined) {
    const root = new El('main', { class: 'od-games' }); root.parentElement = s.env.body;
    const nav = opts.gameNavigation ? new El('nav', { class: 'od-game-nav' }, { top: 76, bottom: 133, height: 57, width: 1200 }) : null;
    if (nav) nav.parentElement = root;
    root.querySelector = selector => selector === '.od-game-nav' ? nav : null;
    box.parentElement = root; s.env.gameNavigation = nav;
  }
  const ins = box.children[0].content.firstElementChild;
  ins.rect = Object.assign({}, ins.rect, { height: opts.creativeHeight, bottom: ins.rect.top + opts.creativeHeight });
  ins.offsetHeight = opts.creativeHeight;
  s.env.pushTargets.push(ins);
  s.runtime.mount(box, { tier: 'premium', gate: false, near: 1800 }); flush(s.env);
  return Object.assign(s, { box, ins });
}

test('A tall desktop creative stays in normal flow on a low screen and recovers sticky on resize', () => {
  const s = stickyScene({ viewportHeight: 600 });
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'height-exceeds-viewport');
  assert.equal(s.runtime.inspect().engine.scrollListenersActive, false);
  assert.equal(s.runtime.inspect().engine.resizeListenersActive, true);
  s.env.win.innerHeight = 900; s.env.resize();
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  s.env.win.innerWidth = 1000; s.env.resize();
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'not-desktop');
  assert.equal(s.box.hidden, false);
  s.env.win.innerWidth = 1440; s.env.resize();
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.box.children.find(node => node.tagName === 'INS'), s.ins);
});

test('A game navigation keeps the sidebar in normal flow without hiding or refreshing; no nav permits safe sticky', () => {
  const s = stickyScene({ gameNavigation: true });
  const iframe = new El('iframe', { id: 'google_ads_iframe_game_nav', width: '300', height: '600' }); s.ins.appendChild(iframe);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'game-navigation-flow');
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  for (const width of [1000, 1440, 1200, 1440]) { s.env.win.innerWidth = width; s.env.resize(); }
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'game-navigation-flow');
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.box.hidden, false);
  assert.equal(s.ins.children[0], iframe);
  assert.equal(iframe.getAttribute('height'), '600');
  assert.equal(s.env.gameNavigation.getAttribute('class'), 'od-game-nav');
  const noNav = stickyScene({ gameNavigation: false });
  assert.equal(noNav.box.getAttribute('data-go-ad-sticky-fit'), '1');
  assert.equal(noNav.runtime.inspect().manual[0].sticky.reason, 'fits');
  assert.equal(noNav.env.win.adsbygoogle.length, 1);
});

test('A larger late creative disables sticky without oscillation until viewport geometry changes', () => {
  const s = stickyScene();
  const iframe = new El('iframe', { width: '300', height: '600' }); s.ins.appendChild(iframe);
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  s.ins.rect.height = 900; s.ins.rect.bottom = s.ins.rect.top + 900; s.ins.offsetHeight = 900;
  s.env.resizeObserved(s.ins);
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  s.ins.rect.height = 600; s.ins.rect.bottom = s.ins.rect.top + 600; s.ins.offsetHeight = 600;
  for (let i = 0; i < 10; i++) s.env.resizeObserved(s.ins);
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'same-viewport-latch');
  s.env.win.innerHeight = 1000; s.env.resize();
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  assert.equal(s.env.win.adsbygoogle.length, 1);
  assert.equal(s.ins.children[0], iframe);
  assert.equal(iframe.getAttribute('height'), '600');
});

test('Sticky falls back to normal flow for excess width, horizontal overflow or unknown offset', () => {
  [
    [{ width: 320 }, 'width-exceeds-300'],
    [{ left: 1250 }, 'outside-horizontal-viewport'],
    [{ offset: 'auto' }, 'unknown-offset']
  ].forEach(([options, reason]) => {
    const s = stickyScene(options);
    assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
    assert.equal(s.runtime.inspect().manual[0].sticky.reason, reason);
    assert.equal(s.env.win.adsbygoogle.length, 1);
    assert.equal(s.box.hidden, false);
  });
});

test('Sticky clearance includes the recognized account anchor without altering that format', () => {
  const s = stickyScene({ viewportHeight: 900, anchorHeight: 200 });
  assert.equal(s.runtime.inspect().manual[0].sticky.geometry.availableHeight, 700);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'account-anchor-overlap');
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(s.env.accountAnchor.getAttribute('data-anchor-status'), 'displayed');
  assert.equal(s.env.accountAnchor.rect.height, 200);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('A late bottom anchor wakes the drained queue and dismissal restores safe sticky without a request', () => {
  const s = stickyScene();
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  assert.equal(s.env.frames.length, 0);
  const anchor = s.env.insertAccountAnchor({ top: 700, bottom: 900, left: 0, right: 1440, width: 1440, height: 200 });
  assert.ok(s.env.frames.length > 0, 'recognized insertion wakes the runtime without viewport resize');
  flush(s.env);
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'account-anchor-overlap');
  anchor.setAttribute('data-anchor-status', 'dismissed'); flush(s.env);
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('A top anchor blocks the projected sticky wrapper although the body bottom reserve stays zero', () => {
  const s = stickyScene();
  const anchor = s.env.insertAccountAnchor({ top: 0, bottom: 200, left: 0, right: 1440, width: 1440, height: 200 }); flush(s.env);
  assert.equal(s.runtime.inspect().viewport.anchorReservePx, 0);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'account-anchor-overlap');
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(anchor.getAttribute('data-anchor-status'), 'displayed');
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('A nonintersecting side anchor does not disable sticky; observed movement and removal are reconciled', () => {
  const s = stickyScene();
  const anchor = s.env.insertAccountAnchor({ top: 0, bottom: 900, left: 0, right: 200, width: 200, height: 900 }); flush(s.env);
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  anchor.rect.left = 1000; anchor.rect.right = 1200;
  anchor.setAttribute('style', 'left:1000px'); flush(s.env);
  assert.equal(s.runtime.inspect().manual[0].sticky.reason, 'account-anchor-overlap');
  anchor.isConnected = false; s.env.accountAnchors = [];
  s.env.emitAnchorMutation({ type: 'childList', addedNodes: [], removedNodes: [anchor] }); flush(s.env);
  assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

test('An anchor marker added after insertion is discovered without polling or a viewport event', () => {
  const s = stickyScene();
  const anchor = s.env.insertAccountAnchor({ top: 0, bottom: 200, left: 0, right: 1440, width: 1440, height: 200 }, null);
  flush(s.env); assert.equal(s.box.getAttribute('data-go-ad-sticky-fit'), '1');
  anchor.setAttribute('data-anchor-status', 'displayed');
  s.env.emitAnchorMutation({ type: 'attributes', target: anchor, attributeName: 'data-anchor-status' }); flush(s.env);
  assert.equal(s.box.hasAttribute('data-go-ad-sticky-fit'), false);
  assert.equal(s.env.win.adsbygoogle.length, 1);
});

/* These are CSS contract guards, not a browser layout simulation. The complete
 * cascade and actual provider expansion remain part of visual QA. */
const css = fs.readFileSync(process.env.GO_ADS_CSS_SOURCE || path.join(__dirname, '..', 'assets', 'css', 'go-ads.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
const rules = Array.from(css.matchAll(/([^{}]+)\{([^{}]*)\}/g), match => ({ selector: match[1].trim(), declarations: match[2] }));
function exact(selector) { return rules.filter(rule => rule.selector === selector); }
test('Body CSS preserves the full-width parameter contract without a stronger shared width cap', () => {
  const body = exact('body.single-post.go-verge .go-article__content .go-article-revenue-slot > ins.adsbygoogle');
  assert.equal(body.length, 1);
  assert.equal(/(?:max-width|max-inline-size)\s*:/.test(body[0].declarations), false);
  assert.match(exact('.go-ad-slot:not([data-go-ad-sizing="fixed"]) > ins.adsbygoogle[data-full-width-responsive="true"]')[0].declarations, /max-inline-size\s*:\s*none/);
  assert.match(exact('.go-ad-slot:not([data-go-ad-sizing="fixed"]) > ins.adsbygoogle[data-full-width-responsive="false"]')[0].declarations, /max-inline-size\s*:\s*100%/);
  assert.match(exact('.go-ad-slot[data-go-ad-sizing="fixed"] > ins.adsbygoogle')[0].declarations, /max-inline-size\s*:\s*none/);
});

test('Game sidebar narrow-screen hiding is restricted to unrequested hosts', () => {
  const hides = rules.filter(rule => rule.selector.includes('.go-game-sidebar-revenue') && /display\s*:\s*none/.test(rule.declarations));
  assert.equal(hides.length, 1);
  assert.equal(hides[0].selector, '.go-game-sidebar-revenue:not([data-go-ad-requested="1"])');
  assert.ok(css.includes('@media(max-width:1100px)'));
  assert.ok(css.includes('@media(min-width:1101px){.go-article-sidebar__ad--sticky'));
  const fallback = exact('body.go-verge .go-ad-slot.go-article-sidebar__ad--sticky:not([data-go-ad-sticky-fit="1"])');
  assert.equal(fallback.length, 1);
  assert.equal(fallback[0].declarations, 'position:static!important');
});

console.log(JSON.stringify({ suite: 'responsive-geometry', scenarios: passed + failures.length, passed, failed: failures.length,
  cssContractChecks: 2, browserLayoutExecuted: false, realAdRequests: 0 }));
if (failures.length) { failures.forEach(error => console.error(error)); process.exitCode = 1; }
