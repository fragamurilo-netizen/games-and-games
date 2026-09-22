/** Offline execution of the optional gate emitted by the actual PHP loader. */
'use strict';
const assert = require('node:assert/strict');
const vm = require('node:vm');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const html = execFileSync(process.env.GO_TEST_PHP || 'php', [path.join(__dirname, 'test-unified-loader.php'), '--emit-gate'], { encoding: 'utf8' });
const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)];
assert.equal(scripts.length, 1, 'PHP emits a single executable consent gate');
const source = scripts[0][1];
let passed = 0;
function check(name, fn) { fn(); passed++; process.stdout.write('PASS ' + name + '\n'); }
function fixture(options = {}) {
  const listeners = new Map();
  const appended = [];
  let allowed = !!options.allowed;
  const document = {
    readyState: options.readyState || 'loading',
    addEventListener(name, fn) { const group = listeners.get(name) || []; group.push(fn); listeners.set(name, group); },
    querySelector() { return options.providerExists ? {} : null; },
    createElement(name) { assert.equal(name, 'script'); return {}; },
    head: { appendChild(node) { appended.push(node); } }
  };
  const window = {};
  if (options.wpFallback) window.wp_has_consent = category => { assert.equal(category, 'marketing'); return allowed; };
  else if (!options.noApi) window.GOAdsConsent = { permitted: () => { if (options.throws) throw new Error('CMP unavailable'); return allowed; } };
  vm.runInNewContext(source, { window, document, encodeURIComponent }, { timeout: 1000 });
  return { appended, listeners, setAllowed(value) { allowed = value; }, event(name) { (listeners.get(name) || []).forEach(fn => fn()); } };
}
check('No consent API does not insert the provider', () => { assert.equal(fixture({ noApi: true }).appended.length, 0); });
check('Denied hard gate remains closed on readiness and repeated consent notifications', () => {
  const f = fixture();
  ['DOMContentLoaded', 'go:consent-change', 'wp_listen_for_consent_change'].forEach(name => f.event(name));
  assert.equal(f.appended.length, 0);
});
check('Late consent inserts exactly one canonical script across every event source', () => {
  const f = fixture(); f.setAllowed(true);
  for (let repeat = 0; repeat < 3; repeat++) ['go:consent-change', 'go:ads-consent-update', 'wp_listen_for_consent_change', 'wp_consent_type_defined', 'DOMContentLoaded'].forEach(name => f.event(name));
  assert.equal(f.appended.length, 1);
  assert.equal(f.appended[0].src, 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-3687004010207904');
  assert.equal(f.appended[0].async, true); assert.equal(f.appended[0].crossOrigin, 'anonymous');
  assert.equal(Object.prototype.hasOwnProperty.call(f.appended[0], 'data-ad-channel'), false);
});
check('An existing official provider suppresses insertion after consent', () => {
  const f = fixture({ allowed: true, providerExists: true }); f.event('go:consent-change'); assert.equal(f.appended.length, 0);
});
check('WP marketing consent fallback releases once without an experiment API', () => {
  const f = fixture({ wpFallback: true }); f.setAllowed(true); f.event('wp_listen_for_consent_change'); f.event('go:ads-consent-update'); assert.equal(f.appended.length, 1);
});
check('CMP exception is handled without fetching provider', () => { const f = fixture({ allowed: true, throws: true }); f.event('go:consent-change'); assert.equal(f.appended.length, 0); });
check('Ready document with consent inserts once immediately', () => { const f = fixture({ allowed: true, readyState: 'complete' }); f.event('go:ads-consent-update'); assert.equal(f.appended.length, 1); assert.equal(f.listeners.has('DOMContentLoaded'), false); });
check('Consent revocation and regrant do not create a second provider', () => {
  const f = fixture({ allowed: true }); f.setAllowed(false); f.event('go:consent-change'); f.setAllowed(true); f.event('go:consent-change'); assert.equal(f.appended.length, 1);
});
process.stdout.write('loader-gate: ' + passed + ' passed, 0 failed; DOM double only, zero network requests\n');
