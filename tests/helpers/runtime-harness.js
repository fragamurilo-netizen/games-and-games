/**
 * Shared DOM double for the browser-runtime suites.
 *
 * It loads assets/js/go-ads-runtime.js unmodified and drives real placements
 * through mount()/activate(), so budget accounting, density, timing, the
 * Revenue Governor and the provider lifecycle are exercised on the actual
 * production code path rather than on a reimplementation of it.
 *
 * Until 4.6 six of the runtime suites each carried their own near-identical
 * copy of this file inline, which is why they disagreed about what the default
 * configuration was. There is one copy now.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const SOURCE = fs.readFileSync(process.env.GO_RUNTIME_SOURCE || path.join(__dirname, '..', '..', 'assets', 'js', 'go-ads-runtime.js'), 'utf8');

let pass = 0;
const failures = [];
function ok(condition, label, detail) {
  if (condition) { pass++; return true; }
  failures.push(label + (detail ? ' — ' + detail : ''));
  return false;
}
function equals(expected, actual, label) {
  return ok(expected === actual, label, 'esperado ' + JSON.stringify(expected) + ', obtido ' + JSON.stringify(actual));
}
function section(title) {
  console.log('\n' + '-'.repeat(72) + '\n' + title + '\n' + '-'.repeat(72));
}

/* ------------------------------------------------------------------ DOM double */

const CSS = {
  paddingLeft: '0px', paddingRight: '0px', paddingTop: '0px', paddingBottom: '0px',
  minHeight: '0px', display: 'block', visibility: 'visible', contentVisibility: 'visible',
  opacity: '1', overflowY: 'visible', overflowX: 'visible'
};

class El {
  constructor(tag, attrs, rect) {
    this.tagName = String(tag).toUpperCase();
    this.nodeType = 1;
    this._attrs = Object.assign({}, attrs || {});
    this.children = [];
    this.style = { setProperty() {}, width: '', height: '', minWidth: '' };
    const names = new Set(String((attrs || {}).class || '').split(/\s+/).filter(Boolean));
    this.classList = {
      add: (c) => names.add(c),
      remove: (c) => names.delete(c),
      contains: (c) => names.has(c)
    };
    this.hidden = false;
    this.isConnected = true;
    this.parentElement = null;
    this.textContent = '';
    this.rect = Object.assign({ top: 0, bottom: 250, left: 0, right: 360, width: 360, height: 250, x: 0, y: 0 }, rect || {});
    this.clientWidth = 360;
    this.clientHeight = Math.max(1, this.rect.height);
    this.offsetHeight = this.rect.height;
    this.scrollHeight = this.rect.height;
  }
  getAttribute(name) { return Object.prototype.hasOwnProperty.call(this._attrs, name) ? this._attrs[name] : null; }
  setAttribute(name, value) {
    this._attrs[name] = String(value);
    (this._observers || []).forEach((cb) => cb());
  }
  removeAttribute(name) { delete this._attrs[name]; }
  hasAttribute(name) { return Object.prototype.hasOwnProperty.call(this._attrs, name); }
  getBoundingClientRect() { return this.rect; }
  getClientRects() { return [this.rect]; }
  contains(node) {
    for (let cursor = node; cursor; cursor = cursor.parentElement) if (cursor === this) return true;
    return false;
  }
  querySelector() { return null; }
  querySelectorAll() { return []; }
  addEventListener() {}
  removeEventListener() {}
  append(...nodes) { nodes.forEach((n) => { n.parentElement = this; this.children.push(n); }); }
  appendChild(node) { node.parentElement = this; this.children.push(node); return node; }
  replaceWith(node) {
    const parent = this.parentElement;
    if (!parent) return;
    const index = parent.children.indexOf(this);
    if (index === -1) return;
    parent.children[index] = node;
    node.parentElement = parent;
    node.rect = node.rect || this.rect;
    this.parentElement = null;
  }
}

/** An <ins> that answers `filled` the moment it is pushed. */
function insNode(slot, rect) {
  const node = new El('ins', { 'data-ad-slot': slot, class: 'adsbygoogle' }, rect);
  node.answer = 'filled';
  return node;
}

function adBox(options) {
  const box = new El('aside', {
    'data-go-ad-placement': options.placement,
    'data-go-ad-tier': options.tier,
    'data-go-ad-surface': options.surface || '',
    'data-go-ad-article-words': String(options.articleWords || ''),
    class: 'go-ad-slot go-ad-slot--collapse-unfilled'
  }, {
    top: options.top, bottom: options.top + (options.height || 250), height: options.height || 250,
    width: options.width || 360, left: options.left || 0, right: (options.left || 0) + (options.width || 360),
    x: options.left || 0, y: options.top
  });
  const ins = insNode(options.slot, box.rect);
  if (options.answer) ins.answer = options.answer;
  const template = new El('template', { 'data-go-ad-pending': '' });
  template.content = {
    firstElementChild: ins,
    appendChild(node) { template.content.firstElementChild = node; }
  };
  box.append(template);
  box.slot = options.slot;
  return box;
}

function makeEnvironment(config, options) {
  options = options || {};
  const frames = [];
  const content = new El('div', {
    class: 'go-article__content',
    'data-go-manual-ads-root': 'article',
    'data-go-ad-plan-body-words': String(options.articleWords || 0),
    'data-go-ad-plan-planned-body': String(options.plannedBodyCount || 0),
    'data-go-ad-plan-eligible-candidates': String(options.eligibleCandidates || options.plannedBodyCount || 0),
    'data-go-ad-plan-body-capacity': String(options.structuralBodyCapacity || options.renderedBodyCount || options.plannedBodyCount || 0),
    'data-go-ad-plan-rendered-body': String(options.renderedBodyCount || options.plannedBodyCount || 0),
    'data-go-ad-plan-reserve-body': String(options.reserveBodyCount || 0),
    'data-go-ad-plan-article-type': String(options.articleType || 'news'),
    'data-go-ad-plan-planner-version': '19.0.0-manual-governor'
  }, { top: 0, bottom: 6000, height: 6000, width: 360, left: 0, right: 360, x: 0, y: 0 });
  content.scrollHeight = options.contentHeight || 6000;
  content.textContent = new Array(options.articleWords || 2600).fill('palavra').join(' ');
  const adBoxes = [];
  content.querySelectorAll = (selector) => (selector === '.go-ad-slot' ? adBoxes.slice() : []);

  const body = new El('body', { class: 'single-post' }, { top: 0, bottom: 6000, height: 6000, width: 360, left: 0, right: 360, x: 0, y: 0 });
  body.scrollHeight = options.documentHeight || 6000;
  content.parentElement = body;

  const documentElement = new El('html', {}, { top: 0, bottom: 6000, height: 6000, width: 360, left: 0, right: 360, x: 0, y: 0 });
  documentElement.scrollHeight = options.documentHeight || 6000;
  documentElement.clientHeight = options.innerHeight || 800;
  documentElement.scrollTop = options.scrollY == null ? 400 : options.scrollY;

  let clock = options.now == null ? Date.now() : options.now;
  let timerId = 0;
  const timers = new Map();
  function advance(ms) {
    const target = clock + ms;
    let iterations = 0;
    while (true) {
      const next = Array.from(timers).filter(([, t]) => t.at <= target).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      if (++iterations > 10000) throw new Error('Timer loop');
      timers.delete(next[0]); clock = next[1].at; next[1].cb();
    }
    clock = target;
  }
  const localStore = Object.assign({}, options.localStorageData || {});
  const sessionStore = Object.assign({}, options.sessionStorageData || {});
  const storage = (store) => ({
    getItem: (key) => Object.prototype.hasOwnProperty.call(store, key) ? String(store[key]) : null,
    setItem: (key, value) => { store[key] = String(value); },
    removeItem: (key) => { delete store[key]; },
    clear: () => { Object.keys(store).forEach((key) => delete store[key]); }
  });
  const win = {
    innerWidth: options.innerWidth || 360,
    innerHeight: options.innerHeight || 800,
    pageYOffset: options.scrollY == null ? 400 : options.scrollY,
    GOAdsYieldConfig: config,
    adsbygoogle: [],
    performance: { now: () => clock },
    setTimeout: (cb, delay) => { const id = ++timerId; timers.set(id, { cb, at: clock + Math.max(1, delay || 0) }); return id; },
    clearTimeout: (id) => timers.delete(id),
    requestAnimationFrame: (cb) => { frames.push(cb); return frames.length; },
    addEventListener: () => {},
    removeEventListener: () => {},
    getComputedStyle: () => CSS,
    matchMedia: null,
    MutationObserver: function MutationObserver(callback) {
      const watched = [];
      this.observe = (node) => {
        node._observers = node._observers || [];
        node._observers.push(callback);
        watched.push(node);
      };
      this.disconnect = () => {
        watched.forEach((node) => {
          const index = (node._observers || []).indexOf(callback);
          if (index !== -1) node._observers.splice(index, 1);
        });
        watched.length = 0;
      };
    },
    localStorage: storage(localStore),
    sessionStorage: storage(sessionStore),
    GOAdsConsent: options.storagePermission ? { permitted: () => true } : undefined
    /* IntersectionObserver / MutationObserver / ResizeObserver / fetch are
     * intentionally absent: the runtime must degrade to the scroll queue. */
  };
  win.adsbygoogle.push = function (value) {
    Array.prototype.push.call(this, value);
    /* Stand in for adsbygoogle.js writing data-ad-status on the newest unit.
     * `providerDelayMs` makes it answer the way the real library does — later,
     * through a DOM mutation — so the runtime's observer path and its latency
     * model are exercised rather than short-circuited. */
    const record = pushTargets.find((node) => node.parentElement && !node._providerRequested);
    if (!record) return;
    record._providerRequested = true;
    if (record.answer === '__NO_STATUS__') return;
    const write = () => record.setAttribute('data-ad-status', record.answer || 'filled');
    if (options.providerDelayMs) win.setTimeout(write, options.providerDelayMs);
    else write();
  };
  const pushTargets = [];

  const anchorHeight = Number(options.anchorHeight || 0);
  const anchorVh = options.innerHeight || 800;
  const anchorEl = anchorHeight > 0
    ? new El('ins', { class: 'adsbygoogle', 'data-anchor-status': 'displayed' },
        { top: anchorVh - anchorHeight, bottom: anchorVh, height: anchorHeight, width: options.innerWidth || 360, left: 0, right: options.innerWidth || 360, x: 0, y: anchorVh - anchorHeight })
    : null;

  const listeners = {};
  const docListeners = {};
  const doc = {
    visibilityState: 'visible',
    documentElement: documentElement,
    body: body,
    addEventListener: (type, cb) => { (docListeners[type] = docListeners[type] || []).push(cb); },
    removeEventListener: () => {},
    dispatchEvent: (event) => { (docListeners[event.type] || []).forEach(cb => cb(event)); return true; },
    querySelector: (selector) => (String(selector).indexOf('go-article__content') !== -1 ? content : null),
    /* The account's anchor, when a scenario asks for one. It is the only
     * overlay the engine ever queries, and only to measure how much of the
     * bottom of the screen it is covering. */
    querySelectorAll: (selector) => {
      if (!anchorEl || String(selector).indexOf('data-anchor-status') === -1) { return []; }
      return [anchorEl];
    }
  };

  const offBoxes = [];
  win.addEventListener = (type, handler) => { listeners[type] = handler; };
  win.removeEventListener = (type) => { delete listeners[type]; };
  return {
    win, doc, content, body, adBoxes, offBoxes, frames, pushTargets,
    onScroll: () => { if (listeners.scroll) listeners.scroll(); },
    advance,
    setScroll: (y) => {
      win.pageYOffset = y; documentElement.scrollTop = y;
      adBoxes.concat(offBoxes).forEach((box) => {
        const docTop = box._docTop == null ? box.rect.top + (options.scrollY == null ? 400 : options.scrollY) : box._docTop;
        box._docTop = docTop;
        box.rect.top = docTop - y; box.rect.bottom = box.rect.top + box.rect.height; box.rect.y = box.rect.top;
      });
      if (listeners.scroll) listeners.scroll();
    }
  };
}

function boot(env) {
  const sandbox = {
    window: env.win,
    document: env.doc,
    navigator: {},
    Event: function Event(type) { this.type = type; },
    CustomEvent: function CustomEvent(type, init) { this.type = type; this.detail = init && init.detail; },
    console: console,
    Math: Math,
    Date: Date,
    JSON: JSON,
    Set: Set,
    WeakSet: WeakSet,
    WeakMap: WeakMap,
    Array: Array,
    Number: Number,
    String: String,
    Object: Object,
    isFinite: isFinite,
    parseInt: parseInt,
    parseFloat: parseFloat,
    Intl: Intl
  };
  vm.createContext(sandbox);
  vm.runInContext(SOURCE, sandbox, { filename: 'go-ads-runtime.js' });
  return env.win.GOAdsRuntime;
}

/** Mount a placement and let the stub provider answer it. */
function mountAd(runtime, env, spec) {
  const box = adBox(spec);
  box._docTop = spec.top + (env.win.pageYOffset || 0);
  box.parentElement = spec.inContent === false ? env.body : env.content;
  if (spec.inContent !== false) env.adBoxes.push(box); else env.offBoxes.push(box);
  env.pushTargets.push(box.children[0].content.firstElementChild);
  runtime.mount(box, {
    near: spec.near == null ? 3000 : spec.near,
    nearMax: spec.nearMax == null ? 3000 : spec.nearMax,
    predictive: !!spec.predictive,
    safetyMs: spec.safetyMs || 600,
    tier: spec.tier,
    priority: spec.critical ? 'critical' : 'normal',
    frequencyMax: spec.frequencyMax || 0,
    smartFrequency: !!spec.smartFrequency,
    smartFreeFills: spec.smartFreeFills == null ? 4 : spec.smartFreeFills,
    smartFifthPages: spec.smartFifthPages == null ? 3 : spec.smartFifthPages,
    smartFifthMs: spec.smartFifthMs == null ? 60000 : spec.smartFifthMs,
    smartSixthPages: spec.smartSixthPages == null ? 4 : spec.smartSixthPages,
    smartSixthMs: spec.smartSixthMs == null ? 120000 : spec.smartSixthMs,
    smartSessionIdleMs: spec.smartSessionIdleMs == null ? 1800000 : spec.smartSessionIdleMs,
    sizes: [],
    gate: false,
    fixed: false,
    media: spec.media || ''
  });
  return box;
}

/**
 * Advance the reader down the page and let the queue run, the way a real
 * session does. Reach probability is a function of where the reader IS, so a
 * single measurement at load says nothing about what a page eventually serves.
 */
function readThrough(env, steps) {
  const boxes = env.adBoxes.concat(env.offBoxes || []);
  for (let step = 0; step < (steps || 8); step++) {
    const delta = 700;
    env.win.pageYOffset += delta;
    env.doc.documentElement.scrollTop = env.win.pageYOffset;
    boxes.forEach((box) => {
      box.rect.top -= delta;
      box.rect.bottom -= delta;
      box.rect.y = box.rect.top;
    });
    env.onScroll();
    env.frames.splice(0).forEach((cb) => cb());
  }
}

/**
 * The delivery rule table, mirroring inc/ads/config.php.
 *
 * Tests may override any single value; everything else keeps the production
 * number, so a suite cannot accidentally pass because it invented a lenient
 * threshold of its own.
 */
function rules(overrides) {
  const base = {
    desktop_min_width: 1101,
    mobile: {
      min_gap_px: 240, density_window_vh: 0.90, max_units_in_window: 3,
      max_local_ad_ratio: 0.45, max_ad_to_content_ratio: 0.45, min_stream_gap_px: 380,
      rest_lead_vh: { reach: 1.00, premium: 0.90, standard: 0.75, deep: 0.60, completion: 0.52 },
      rest_lead_min_px: 260, rest_lead_max_px: 1100,
      max_lookahead_vh: 3.0, flick_vh_s: 2.0, request_spacing_ms: 0,
      engage_scroll_vh: 0.07, engage_dwell_ms: 1500
    },
    desktop: {
      min_gap_px: 300, density_window_vh: 0.85, max_units_in_window: 3,
      max_local_ad_ratio: 0.42, max_ad_to_content_ratio: 0.45, min_stream_gap_px: 460,
      rest_lead_vh: { reach: 0.85, premium: 0.78, standard: 0.65, deep: 0.55, completion: 0.50 },
      rest_lead_min_px: 280, rest_lead_max_px: 1200,
      max_lookahead_vh: 2.6, flick_vh_s: 2.4, request_spacing_ms: 0,
      engage_scroll_vh: 0.09, engage_dwell_ms: 1800
    },
    critical_hold_ms: 800,
    stuck_release_ms: 8000,
    governor: {
      expansion_depth: 0.40, expansion_dwell_ms: 18000, expansion_deep_depth: 0.58,
      expansion_prior_depth: 0.70, expansion_prior_floor: 0.35,
      warmup_lookahead_vh: 1.15, conservative_lookahead_vh: 1.25,
      spacing_scale: { warmup: 1, standard: 1, conservative: 1.20, expansion: 0.94 }
    }
  };
  if (!overrides) return base;
  const out = JSON.parse(JSON.stringify(base));
  Object.keys(overrides).forEach((key) => {
    if (out[key] && typeof out[key] === 'object' && !Array.isArray(out[key]) && typeof overrides[key] === 'object') {
      Object.assign(out[key], overrides[key]);
    } else {
      out[key] = overrides[key];
    }
  });
  return out;
}

/** A neutral configuration: one daypart, no pacing, no financial evidence. */
function config(decision, ruleOverrides) {
  return {
    version: 'test',
    timezone: 'America/Sao_Paulo',
    dayparts: { guard: [], shoulder: [] },
    profiles: { peak: { lookahead_scale: 1, engage_scroll_viewports: 0.07, engage_dwell_ms: 1500, request_spacing_ms: 0 } },
    rules: rules(ruleOverrides),
    tier_weights: { reach: 1, premium: 0.94, standard: 0.8, deep: 0.68, completion: 0.66 },
    auction_signal: { min_critical_responses: 2, strong_fill_rate: 0.67, weak_fill_rate: 0.34, strong_response_ms: 1500, weak_response_ms: 2600 },
    reader_model: { enabled: true, storage_key: 'go_ads_reader_depth_v1', ema_alpha: 0.25, min_pages: 3 },
    decision: Object.assign({
      regime: 'balanced', supply_bias: 0, pacing_scale: 1,
      tier_lookahead: { reach: 1, premium: 1, standard: 1, deep: 1, completion: 1 },
      slot_value: {}, slot_coverage: {}, slot_viewability: {}, tier_value: {},
      confidence: 'high', fresh: true, reasons: []
    }, decision || {}),
    regime_endpoint: ''
  };
}

/** The article/governor section of inspect(), which most suites assert on. */
function report(runtime) {
  const snapshot = runtime.inspect();
  return {
    snapshot: snapshot,
    article: snapshot.engine.article,
    governor: snapshot.engine.governor,
    rules: snapshot.engine.rules,
    counts: snapshot.counts.manual,
    body: snapshot.counts.bodyFunnel,
    manual: snapshot.manual
  };
}

/** States of every mounted placement, keyed by placement name. */
function states(runtime) {
  const out = {};
  runtime.inspect().manual.forEach((slot) => { out[slot.placement] = slot.state; });
  return out;
}

module.exports = { El, adBox, insNode, makeEnvironment, boot, mountAd, config, rules, readThrough, report, states };
