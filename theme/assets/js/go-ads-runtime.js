/**
 * Overdrive 13.3 — manual inventory with account-managed Auto Ads.
 *
 * DELIVERY MODEL
 * Publisher inventory retains its own planner. Auto Ads placement and formats
 * are configured in AdSense, never inferred from this script. Recognized
 * in-page units participate in spacing before a new manual request. Recognized
 * anchors adjust usable viewport geometry. Provider units are read-only: no
 * moving, hiding, resizing, requests or refresh, and no claimed impressions.
 *
 * WHAT IT DECIDES
 * The server planner decides WHERE an opportunity may exist. This runtime
 * decides WHETHER and WHEN each one becomes a request, from four inputs:
 *
 *   1. geometry   — real rendered pixels, never a server estimate;
 *   2. arrival    — predicted time until the reader reaches the slot;
 *   3. exposure   — predicted time the creative would be on screen;
 *   4. governor   — pacing and advance supply from observed reader behaviour;
 *   5. viewability — each unit's measured seven-day Active View, and whether
 *                    the reader is reading or skimming (13.3).
 *
 * WHAT IT WILL NEVER DO
 * - refresh, retry or re-request a placement (one request per placement, per
 *   pageview, full stop);
 * - reduce total supply to make an average price look better;
 * - create an impression the reader cannot see, or move content to attract a
 *   click;
 * - report a local DOM observation as an official impression or Active View.
 *
 * Published thresholds arrive from inc/ads/config.php via GOAdsYieldConfig.rules.
 * Bounded defaults below cover a missing or older payload.
 */
(function (w, d) {
  'use strict';
  if (w.GOAdsRuntime) return;

  var VERSION = '13.3.0-viewability-first', LABEL_BAND = 32, DAY = 86400000;
  var YIELD = w.GOAdsYieldConfig || {};
  var DELIVERY = YIELD.delivery_v2 || {};
  var diagnosticRate = Math.max(0, Math.min(1, Number(DELIVERY.diagnostic_sample_rate) || 0));
  /* Per-document RAM-only sampling. No analytics event or storage identifier is
   * created by the runtime. A collector must opt in to the local event. */
  var diagnosticSampled = diagnosticRate > 0 && Math.random() < diagnosticRate;
  var gateDiagnostics = diagnosticSampled || !!(YIELD.diagnostics && YIELD.diagnostics.gate_timings === true);
  var TIERS = ['reach', 'premium', 'standard', 'deep', 'completion'];

  /* ------------------------------------------------------------ rule table */

  var DEFAULT_PROFILE = {
    min_gap_px: 300, density_window_vh: 0.90, max_units_in_window: 3,
    max_local_ad_ratio: 0.45, max_ad_to_content_ratio: 0.45, min_stream_gap_px: 380,
    rest_lead_vh: { reach: 0.62, premium: 0.55, standard: 0.48, deep: 0.42, completion: 0.38 },
    rest_lead_min_px: 240, rest_lead_max_px: 700,
    max_lookahead_vh: 1.25, flick_vh_s: 2.0, request_spacing_ms: 90,
    engage_scroll_vh: 0.07, engage_dwell_ms: 1500, fling_tau_s: 0.35,
    critical_stage_ms: 0
  };
  var DEFAULT_GOVERNOR = {
    expansion_depth: 0.40, expansion_dwell_ms: 18000, expansion_deep_depth: 0.58,
    expansion_prior_depth: 0.70, expansion_prior_floor: 0.35,
    warmup_lookahead_vh: 0.62, conservative_lookahead_vh: 0.90,
    spacing_scale: { warmup: 1, standard: 1, conservative: 1.20, expansion: 0.94 }
  };

  function num(value, fallback) { var n = Number(value); return isFinite(n) ? n : fallback; }
  /* Claim the creative's footprint at request time (see activate()). */
  var reserveOnRequest = !(YIELD.cwv && YIELD.cwv.reserve_on_request === false);
  /*
   * Which arm of a calendar trial today belongs to, verbatim from the server.
   *
   * Read exactly once, here, and reported by inspect() so an operator can
   * confirm the rotation is live. Every reader sees the same value on the same
   * day — the arm is decided from the calendar in inc/ads/calendar-trials.php,
   * never in the browser — and nothing in the delivery path reads it back. An
   * arm changes delivery only by having already changed the rule table this
   * payload carries.
   */
  var trialSignal = (function (value) { return (value && typeof value === 'object') ? value : null; })(YIELD.trial);
  function clamp(n, min, max) { n = Number(n); return isFinite(n) ? Math.max(min, Math.min(max, n)) : min; }
  /* Active View band the per-unit controller steers toward (inc/ads/yield.php,
   * go_verge_ads_viewability_policy). Bounded here like every other rule. */
  var VIEW_POLICY = (function (raw) {
    raw = (raw && typeof raw === 'object') ? raw : {};
    return {
      enabled: raw.enabled !== false,
      target: clamp(num(raw.target, 0.62), 0.40, 0.85),
      healthy_margin: clamp(num(raw.healthy_margin, 0.08), 0, 0.30),
      healthy_scale: clamp(num(raw.healthy_scale, 1.08), 1, 1.30),
      floor: clamp(num(raw.floor, 0.50), 0.30, 1),
      flick_guard_below: clamp(num(raw.flick_guard_below, 0.45), 0, 0.85),
      min_lead_px: clamp(num(raw.min_lead_px, 140), 60, 400),
      skim_vh: clamp(num(raw.skim_vh, 1.5), 0, 6),
      skim_window_ms: clamp(num(raw.skim_window_ms, 2500), 800, 8000),
      skim_settle_ms: clamp(num(raw.skim_settle_ms, 800), 0, 2000)
    };
  })(YIELD.viewability);

  function resolveRules() {
    var table = (YIELD.rules && typeof YIELD.rules === 'object') ? YIELD.rules : {};
    var desktopMin = num(table.desktop_min_width, 1101);
    var desktop = (w.innerWidth || d.documentElement.clientWidth || 0) >= desktopMin;
    var profile = table[desktop ? 'desktop' : 'mobile'];
    var out = { device: desktop ? 'desktop' : 'mobile', desktopMinWidth: desktopMin };
    Object.keys(DEFAULT_PROFILE).forEach(function (key) {
      var value = (profile && typeof profile === 'object') ? profile[key] : undefined;
      if (key === 'rest_lead_vh') {
        var leads = {};
        TIERS.forEach(function (tier) {
          leads[tier] = clamp(num(value && value[tier], DEFAULT_PROFILE.rest_lead_vh[tier]), 0.25, 2.0);
        });
        out[key] = leads;
        return;
      }
      out[key] = num(value, DEFAULT_PROFILE[key]);
    });
    out.critical_hold_ms = clamp(num(table.critical_hold_ms, 800), 0, 2500);
    out.stuck_release_ms = clamp(num(table.stuck_release_ms, 8000), 4000, 30000);
    var gov = (table.governor && typeof table.governor === 'object') ? table.governor : {};
    out.governor = {};
    Object.keys(DEFAULT_GOVERNOR).forEach(function (key) {
      if (key === 'spacing_scale') {
        var scales = {};
        Object.keys(DEFAULT_GOVERNOR.spacing_scale).forEach(function (state) {
          scales[state] = clamp(num(gov.spacing_scale && gov.spacing_scale[state], DEFAULT_GOVERNOR.spacing_scale[state]), 0.85, 1.60);
        });
        out.governor[key] = scales;
        return;
      }
      out.governor[key] = num(gov[key], DEFAULT_GOVERNOR[key]);
    });
    out.governor.warmup_lookahead_vh = clamp(out.governor.warmup_lookahead_vh, 0.5, 2.5);
    out.governor.conservative_lookahead_vh = clamp(out.governor.conservative_lookahead_vh, 0.5, 3.0);
    /* Bounds are enforced here so a filter cannot publish a rule table that
     * produces stacked creatives or requests four screens ahead. */
    out.min_gap_px = clamp(out.min_gap_px, 120, 900);
    out.min_stream_gap_px = clamp(out.min_stream_gap_px, 160, 1200);
    out.density_window_vh = clamp(out.density_window_vh, 0.4, 2.0);
    out.max_units_in_window = Math.round(clamp(out.max_units_in_window, 1, 6));
    out.max_local_ad_ratio = clamp(out.max_local_ad_ratio, 0.20, 0.60);
    out.max_ad_to_content_ratio = clamp(out.max_ad_to_content_ratio, 0.20, 0.60);
    out.max_lookahead_vh = clamp(out.max_lookahead_vh, 1.0, 2.5);
    out.fling_tau_s = clamp(out.fling_tau_s, 0.15, 0.8);
    out.flick_vh_s = clamp(out.flick_vh_s, 1.0, 6.0);
    out.request_spacing_ms = clamp(out.request_spacing_ms, 0, 400);
    out.engage_scroll_vh = clamp(out.engage_scroll_vh, 0.04, 0.40);
    out.engage_dwell_ms = clamp(out.engage_dwell_ms, 600, 8000);
    out.rest_lead_min_px = clamp(out.rest_lead_min_px, 120, 600);
    out.rest_lead_max_px = clamp(out.rest_lead_max_px, out.rest_lead_min_px, 2000);
    out.critical_stage_ms = clamp(out.critical_stage_ms, 0, 2500);
    return out;
  }
  var RULES = resolveRules();

  /* CSS and slot media queries follow the current viewport. Delivery must use
   * that same profile after resize or bfcache, without touching served units. */
  function refreshDeviceRules() {
    var device = viewportWidth() >= RULES.desktopMinWidth ? 'desktop' : 'mobile';
    if (device === RULES.device) return false;
    RULES = resolveRules();
    frameId++;
    return true;
  }

  /* ------------------------------------------------------------ engine state */

  var slotOwners = Object.create(null), pending = new Set(), adjustments = new Set(), records = [];
  var mounted = new WeakSet(), measured = new WeakMap(), viewMeasured = new WeakMap(), proximityObservers = Object.create(null);
  var frame = 0, frameId = 0, listening = false, resizeListening = false, ro = null, viewObserver = null, settleTimer = 0, stuckTimer = 0;
  var responseEstimateMs = 1050, responseTimes = [], presentResponseTimes = [];
  var latencyMemory = { loaded: false, profile: '', updatedAt: 0, samples: [], imported: 0 };
  var diagnosticBuffer = [], dynamicStats = { scans: 0, mounted: 0, materialized: 0, detached: 0, skippedDuplicate: 0, rejectedMarkup: 0 };
  var listingBinding = { initialized: false, root: null, reserves: [] };
  var anchorDiscovery = null, anchorResizeObserver = null, providerStateObserver = null;
  var watchedAnchors = new Set(), watchedInPage = new Map(), inPageRects = [], inPageFrame = -1;
  var providerSelector = 'ins.adsbygoogle[data-anchor-status], .google-auto-placed ins.adsbygoogle';
  var now = function () { return Math.round(w.performance && w.performance.now ? w.performance.now() : Date.now()); };
  var motion = { y: w.pageYOffset || d.documentElement.scrollTop || 0, t: 0, velocity: 0, direction: 0, paceVh: 0, trail: [], lastScrollT: -100000 };
  var profileCache = { minute: -1, name: '', hour: null, weekday: '' };
  motion.t = now();

  var engine = {
    engaged: false, engagedBy: '', engagedAtMs: null, dwellMs: 0, dwellStart: null, dwellTimer: 0,
    criticalInFlight: new Set(), criticalHoldUntil: 0, holdTimer: 0, stageTimer: 0, paceTimer: 0, lastNonCriticalRequestAt: -100000,
    dwellWake: 0, maxScrollDepth: 0, readerModel: null, readerCheckpoint: null, articleWords: 0,
    topScrollSession: null, topScrollSessionOpened: false, topScrollDwellBase: 0,
    pageHidden: false, hiddenSinceWall: null, refreshTopScrollOnResume: false,
    plannedBodyCount: 0, renderedBodyCount: 0, reserveBodyCount: 0,
    eligibleCandidates: 0, structuralBodyCapacity: 0, plannerVersion: '', plannerTelemetry: false,
    articleType: '',
    profileName: '', profileHour: null, profileWeekday: '',
    auctionSignal: 'neutral',
    governor: 'warmup', governorSince: 0, governorReason: 'page-load', governorLog: [],
    releasedStuck: 0, skimTravelVh: 0,
    reserveVh: 0, reservePx: null, reserveFrame: -1, anchorFrame: -1, anchorViewport: '', anchorRects: [], clockReserve: -1
  };

  /* ------------------------------------------------------------ primitives */

  function viewportHeight() { return w.innerHeight || d.documentElement.clientHeight; }
  function viewportWidth() { return w.innerWidth || d.documentElement.clientWidth || 0; }
  function viewportHasArea() { return viewportHeight() > 0 && viewportWidth() > 0; }
  function scrollY() { return w.pageYOffset || d.documentElement.scrollTop || 0; }
  function pageVisible() { return d.visibilityState !== 'hidden' && !engine.pageHidden; }

  /**
   * How much of the bottom of the viewport the account's anchor is covering.
   *
   * The engine does not place, move or count overlays — but it cannot pretend
   * they are not there. A displayed bottom anchor can make the region a reader
   * can actually see shorter than `innerHeight`. Measuring the full height
   * made two decisions optimistic: a
   * unit resting behind the anchor counted as "in the viewport", and the
   * resting lead was computed against space that is not available.
   *
   * Measured, never assumed. AdSense marks its own anchor with
   * `data-anchor-status`; if the markup ever changes the query returns nothing,
   * the reserve is zero, and every decision behaves exactly as it did before.
   * Read once per sweep. The provider can show, resize or dismiss an anchor
   * without changing innerHeight, so a height-only cache becomes stale.
   */
  function accountAnchorRects() {
    var viewport = viewportWidth() + ':' + viewportHeight();
    if (engine.anchorFrame === frameId && engine.anchorViewport === viewport) return engine.anchorRects;
    var rects = [];
    try {
      var nodes = d.querySelectorAll('ins.adsbygoogle[data-anchor-status="displayed"]');
      for (var i = 0; i < nodes.length; i++) {
        var r = nodes[i].getBoundingClientRect();
        if (r.width > 0 && r.height > 0) rects.push({ top: r.top, bottom: r.bottom, left: r.left, right: r.right, width: r.width, height: r.height });
      }
    } catch (e) {}
    engine.anchorFrame = frameId; engine.anchorViewport = viewport; engine.anchorRects = rects;
    return rects;
  }
  function overlayReserve() {
    var vh = viewportHeight();
    if (engine.reserveFrame === frameId && engine.reserveVh === vh && engine.reservePx != null) return engine.reservePx;
    var px = 0;
    accountAnchorRects().forEach(function (r) {
        /* Preserve the body's existing small-bottom-anchor reserve. Other
         * recognized shapes stay available for sticky collision checks only. */
        if (r.height > 0 && r.bottom >= vh - 4 && r.height <= vh * 0.25) px = Math.max(px, Math.round(r.height));
    });
    engine.reserveVh = vh; engine.reservePx = px; engine.reserveFrame = frameId;
    return px;
  }
  function anchorGeometryChanged() {
    engine.anchorFrame = -1; engine.reserveFrame = -1;
    inPageFrame = -1;
    refreshViewClocks();
    schedule();
  }
  function recognizedAnchor(node) {
    return node && node.nodeType === 1 && node.tagName === 'INS' && node.classList.contains('adsbygoogle') && node.hasAttribute('data-anchor-status');
  }
  function observeAccountAnchor(node) {
    if (!recognizedAnchor(node) || watchedAnchors.has(node)) return false;
    watchedAnchors.add(node);
    observeProviderState(node);
    if (anchorResizeObserver) anchorResizeObserver.observe(node);
    return true;
  }
  function observeProviderState(node) {
    if (!providerStateObserver) providerStateObserver = new w.MutationObserver(anchorGeometryChanged);
    providerStateObserver.observe(node, { attributes: true, attributeFilter: ['style', 'class', 'hidden', 'data-ad-status', 'data-anchor-status'] });
  }
  function inPageHost(node) {
    if (!node || node.nodeType !== 1 || node.tagName !== 'INS' || !node.classList.contains('adsbygoogle') ||
        node.hasAttribute('data-anchor-status') || node.closest('[data-go-ad-placement]')) return null;
    /* This is a recognized provider marker, not a promise about future Google
     * markup. Unknown ad containers are never guessed from their dimensions. */
    return node.closest('.google-auto-placed');
  }
  function observeAccountInPage(node) {
    var host = inPageHost(node);
    if (!host || watchedInPage.has(node)) return false;
    watchedInPage.set(node, host);
    observeProviderState(node); observeProviderState(host);
    if (anchorResizeObserver) { anchorResizeObserver.observe(node); anchorResizeObserver.observe(host); }
    return true;
  }
  function discoverProviderNode(node) {
    if (!node || node.nodeType !== 1) return false;
    var changed = observeAccountAnchor(node) || observeAccountInPage(node);
    if (!node.firstElementChild) return changed;
    Array.prototype.forEach.call(node.querySelectorAll(providerSelector), function (unit) {
      if (observeAccountAnchor(unit) || observeAccountInPage(unit)) changed = true;
    });
    return changed;
  }
  function accountInPageRects() {
    if (inPageFrame === frameId) return inPageRects;
    inPageFrame = frameId; inPageRects = [];
    watchedInPage.forEach(function (host, node) {
      if (!node.isConnected || !host.isConnected || inPageHost(node) !== host || node.getAttribute('data-ad-status') === 'unfilled') return;
      var css = w.getComputedStyle(host), unitCss = w.getComputedStyle(node);
      if (/^(fixed|sticky)$/.test(css.position) || /^(fixed|sticky)$/.test(unitCss.position) ||
          host.hidden || node.hidden || css.display === 'none' || unitCss.display === 'none' ||
          /^(hidden|collapse)$/.test(css.visibility) || /^(hidden|collapse)$/.test(unitCss.visibility)) return;
      /* Use only the exposed in-flow footprint. In particular, no nominal
       * height is invented for an Auto unit Google has not sized yet. */
      var rect = host.getBoundingClientRect();
      if (rect.width < 1 || rect.height < 1) rect = node.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) inPageRects.push({
        top: rect.top, bottom: rect.bottom, left: rect.left, right: rect.right,
        width: rect.width, height: rect.height, node: node
      });
    });
    return inPageRects;
  }
  function ensureAnchorWatch() {
    if (anchorDiscovery || typeof w.MutationObserver !== 'function' || !d.body) return;
    if (typeof w.ResizeObserver === 'function') anchorResizeObserver = new w.ResizeObserver(anchorGeometryChanged);
    /* One discovery observer for official units. Only added subtrees and an
     * anchor's marker are searched. The shared state/resize observers then
     * watch those exact units, never provider iframes or all document styles. */
    anchorDiscovery = new w.MutationObserver(function (mutations) {
      var changed = false;
      (mutations || []).forEach(function (mutation) {
        if (mutation.type === 'attributes') {
          if (recognizedAnchor(mutation.target)) { observeAccountAnchor(mutation.target); changed = true; }
          return;
        }
        Array.prototype.forEach.call(mutation.addedNodes || [], function (node) {
          if (discoverProviderNode(node)) changed = true;
        });
      });
      var removed = false;
      watchedAnchors.forEach(function (anchor) {
        if (anchor.isConnected) return;
        if (anchorResizeObserver) anchorResizeObserver.unobserve(anchor);
        watchedAnchors.delete(anchor); changed = true; removed = true;
      });
      watchedInPage.forEach(function (host, node) {
        if (node.isConnected && host.isConnected && inPageHost(node) === host) return;
        if (anchorResizeObserver) { anchorResizeObserver.unobserve(node); anchorResizeObserver.unobserve(host); }
        watchedInPage.delete(node); changed = true; removed = true;
      });
      /* MutationObserver has no unobserve(). Rebind the one shared observer
       * after removal so it does not retain detached provider trees. */
      if (removed && providerStateObserver) {
        providerStateObserver.disconnect();
        watchedAnchors.forEach(observeProviderState);
        watchedInPage.forEach(function (host, node) { observeProviderState(host); observeProviderState(node); });
      }
      if (changed) anchorGeometryChanged();
    });
    anchorDiscovery.observe(d.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-anchor-status'] });
    discoverProviderNode(d.body);
  }
  function stopAnchorWatch() {
    if (anchorDiscovery) { anchorDiscovery.disconnect(); anchorDiscovery = null; }
    if (anchorResizeObserver) { anchorResizeObserver.disconnect(); anchorResizeObserver = null; }
    if (providerStateObserver) { providerStateObserver.disconnect(); providerStateObserver = null; }
    watchedAnchors.clear(); watchedInPage.clear(); inPageFrame = -1; inPageRects = [];
  }
  /* The part of the viewport a reader can actually see. */
  function usableViewportHeight() { return Math.max(1, viewportHeight() - overlayReserve()); }
  /* One definition of "the reader can see this right now", used by every
   * shortcut that skips pacing, holding or the exposure gate. */
  function inView(rect) { return !!rect && rect.top < usableViewportHeight() && rect.bottom > 0; }
  function listHas(list, value) { return Array.isArray(list) && list.indexOf(value) !== -1; }

  /* One layout read per record per animation frame. Reading a rect inside a
   * comparator would force a reflow on every scroll frame. */
  function rectOf(rec) {
    if (rec.rectFrame === frameId && rec.rectCache) return rec.rectCache;
    rec.rectCache = rec.box.getBoundingClientRect();
    rec.rectFrame = frameId;
    return rec.rectCache;
  }

  /* Storage permission comes from the shared consent reader (inc/ads/consent.php).
   * It never grants consent; it only reads it. */
  function permission() {
    try {
      if (w.GOAdsConsent) return w.GOAdsConsent.permitted() === true;
      if (typeof w.wp_has_consent === 'function') return w.wp_has_consent('marketing') === true;
    } catch (e) {}
    return false;
  }
  var storageConsent = permission();
  function history(rec) {
    if (!permission()) return [];
    try {
      var raw = JSON.parse(w.localStorage.getItem(rec.key) || '[]'), time = Date.now();
      if (!Array.isArray(raw)) return [];
      return raw.filter(function (n, i, all) {
        return typeof n === 'number' && isFinite(n) && n > time - DAY && n <= time + 300000 && all.indexOf(n) === i;
      }).sort(function (a, b) { return a - b; }).slice(-20);
    } catch (e) { return []; }
  }
  function persistFill(rec) {
    if (!rec.options.frequencyMax || !rec.filled || rec.persisted || !permission()) return;
    try {
      var list = history(rec);
      if (list.indexOf(rec.filledAt) === -1) list.push(rec.filledAt);
      w.localStorage.setItem(rec.key, JSON.stringify(list.slice(-20)));
      rec.persisted = true;
    } catch (e) { /* A storage failure must never become a retry. */ }
  }

  /* ------------------------------------------------ remembered creative height */

  /**
   * Reserve the height this unit actually gets served, not a guess.
   *
   * A responsive Display unit declares one reserve in config.php, and Google
   * serves whatever the auction produced. On this site's mobile masthead those
   * two disagree: 132px is reserved and a 250px creative is common, so the
   * creative's arrival pushes the whole article down — measured at 0.036 CLS,
   * above the fold, which was nearly all of the page's layout shift.
   *
   * Reserving 282px unconditionally would trade that for a 182px hole whenever
   * a short creative serves. So the engine remembers, per slot, the height the
   * provider has actually been returning, and reserves THAT on the next
   * pageview. A unit that consistently serves 100px keeps a 132px reserve; one
   * that consistently serves 250px stops shifting the page. It self-corrects
   * when the account's mix changes.
   *
   * Scope, deliberately narrow:
   *   - only units that ALREADY declare a server-side reserve, which is where
   *     the publisher has decided reserved space is acceptable. The in-body
   *     ladder keeps its zero reserve and its request-time reservation;
   *   - only with storage permission, like every other memory here;
   *   - only filled responses, since an empty unit has no height to learn;
   *   - bounded below by the declared reserve and above by `max_px`, so a
   *     strange sample can enlarge the hole but never invent one.
   *
   * This changes RESERVATION only. It never changes whether a unit requests,
   * when it requests, what it requests, or what Google serves.
   */
  var heightMemory = { loaded: false, slots: null };
  function heightMemoryEnabled() {
    var cfg = YIELD.height_memory || {};
    return cfg.enabled !== false && permission();
  }
  function loadHeightMemory() {
    if (heightMemory.loaded || !heightMemoryEnabled()) return heightMemory.slots;
    heightMemory.loaded = true;
    heightMemory.slots = Object.create(null);
    try {
      var cfg = YIELD.height_memory || {};
      var ttl = clamp(num(cfg.ttl_ms, 7 * DAY), DAY, 30 * DAY);
      var raw = JSON.parse(w.localStorage.getItem(cfg.storage_key || 'go_ads_slot_height_v1') || '{}');
      var wall = Date.now();
      if (raw && typeof raw === 'object') {
        Object.keys(raw).slice(0, 40).forEach(function (slot) {
          var entry = raw[slot];
          if (!entry || typeof entry !== 'object') return;
          var height = Number(entry.h), samples = Number(entry.n), at = Number(entry.t);
          if (!isFinite(height) || height <= 0 || !isFinite(at) || at > wall + 300000 || wall - at > ttl) return;
          heightMemory.slots[slot] = { h: height, n: isFinite(samples) ? samples : 1, t: at };
        });
      }
    } catch (e) { /* A blocked store simply leaves the declared reserve in place. */ }
    return heightMemory.slots;
  }
  /** The height to reserve for this slot, or null to keep the declared one. */
  function rememberedHeight(rec) {
    if (!heightMemoryEnabled() || !rec.slot) return null;
    var cfg = YIELD.height_memory || {};
    var slots = loadHeightMemory();
    var entry = slots && slots[rec.slot];
    if (!entry || entry.n < Math.max(1, num(cfg.min_samples, 2))) return null;
    return clamp(Math.round(entry.h), 0, clamp(num(cfg.max_px, 400), 100, 1200));
  }
  function rememberHeight(rec, px) {
    if (!heightMemoryEnabled() || !rec.slot || !(px > 0)) return;
    var cfg = YIELD.height_memory || {};
    px = clamp(Math.round(px), 0, clamp(num(cfg.max_px, 400), 100, 1200));
    try {
      var slots = loadHeightMemory() || Object.create(null);
      var prior = slots[rec.slot];
      /* An exponential average, so a one-off size moves the reservation a
       * little and a changed mix moves it all the way within a few pageviews. */
      var alpha = clamp(num(cfg.ema_alpha, 0.4), 0.1, 0.9);
      var next = prior ? (prior.h * (1 - alpha) + px * alpha) : px;
      slots[rec.slot] = { h: Math.round(next), n: Math.min(50, (prior ? prior.n : 0) + 1), t: Date.now() };
      heightMemory.slots = slots;
      var out = {};
      Object.keys(slots).slice(0, 40).forEach(function (key) { out[key] = slots[key]; });
      w.localStorage.setItem(cfg.storage_key || 'go_ads_slot_height_v1', JSON.stringify(out));
    } catch (e) { /* A storage failure must never become a delivery change. */ }
  }
  /**
   * Apply the remembered height at mount, before the provider answers.
   *
   * Only upwards, and only where a reserve already exists: this can make an
   * existing reserved box taller so the creative lands in space that is already
   * there, never turn an unreserved host into a hole.
   */
  function applyRememberedReserve(rec) {
    /* An exact-size unit declares its height; memory of responsive sizes
     * served to the same slot must not widen it. */
    if (rec.options.fixed) return;
    var declared = parseFloat(w.getComputedStyle(rec.box).minHeight) || 0;
    if (declared < 1) return;
    var remembered = rememberedHeight(rec);
    if (remembered == null) return;
    var target = remembered + bandOf(rec);
    if (target > declared) { reserve(rec, target); rec.rememberedReserve = target; }
  }

  /* ----------------------------------------------------- Top Scroll session gate */

  /**
   * Session engagement is deliberately first-party and coarse. sessionStorage
   * keeps it in the current tab only, and it is read/written only when the same
   * storage permission used by the 24h frequency cap is available. A 30-minute
   * inactivity gap starts a new session. No URL, identity or revenue value is
   * stored.
   */
  function topScrollSession(rec) {
    if (!rec || rec.placement !== 'topscroll' || !rec.options.smartFrequency || !permission()) {
      return { available: false, pages: 0, activeMs: 0 };
    }
    if (engine.topScrollSession) {
      return {
        available: true,
        pages: engine.topScrollSession.pages,
        activeMs: Math.max(0, engine.topScrollSession.baseActiveMs + dwellMs() - engine.topScrollDwellBase)
      };
    }
    try {
      if (!w.sessionStorage) return { available: false, pages: 0, activeMs: 0 };
      var key = 'go_ads_topscroll_session_v1';
      var wall = Date.now(), idle = Math.max(60000, Number(rec.options.smartSessionIdleMs) || 1800000);
      var raw = JSON.parse(w.sessionStorage.getItem(key) || '{}');
      var updated = Number(raw.updatedAt) || 0;
      var stale = !updated || wall - updated > idle || updated > wall + 300000;
      var pages = stale ? 0 : Math.max(0, parseInt(raw.pages || 0, 10) || 0);
      var activeMs = stale ? 0 : Math.max(0, Number(raw.activeMs) || 0);
      /* A BFcache return restores the same document. A new idle session starts
       * at page one; otherwise reopening this document must not add a page. */
      pages = stale ? 1 : Math.min(200, pages + (engine.topScrollSessionOpened ? 0 : 1));
      engine.topScrollSession = { key: key, pages: pages, baseActiveMs: activeMs, updatedAt: wall };
      engine.topScrollSessionOpened = true;
      w.sessionStorage.setItem(key, JSON.stringify({ pages: pages, activeMs: Math.round(activeMs), updatedAt: wall }));
      return { available: true, pages: pages, activeMs: Math.max(0, activeMs + dwellMs() - engine.topScrollDwellBase) };
    } catch (e) {
      return { available: false, pages: 0, activeMs: 0 };
    }
  }

  function persistTopScrollSession() {
    if (!engine.topScrollSession || !permission()) return;
    try {
      var activeMs = Math.max(0, engine.topScrollSession.baseActiveMs + dwellMs() - engine.topScrollDwellBase);
      w.sessionStorage.setItem(engine.topScrollSession.key, JSON.stringify({
        pages: engine.topScrollSession.pages, activeMs: Math.round(activeMs), updatedAt: Date.now()
      }));
    } catch (e) {}
  }

  function resumeTopScrollSession(force) {
    if (!permission()) return;
    records.forEach(function (rec) {
      if (rec.placement !== 'topscroll' || !rec.options.smartFrequency || (rec.media && !rec.media.matches)) return;
      var idle = Math.max(60000, Number(rec.options.smartSessionIdleMs) || 1800000);
      if (force || (engine.hiddenSinceWall != null && Date.now() - engine.hiddenSinceWall > idle)) {
        engine.topScrollSession = null;
        engine.topScrollDwellBase = dwellMs();
      }
      var session = topScrollSession(rec);
      rec.smartSessionPages = session.pages || 0;
      rec.smartSessionActiveMs = Math.round(session.activeMs || 0);
    });
  }

  function armTopScrollSmartWake(rec, remainingMs) {
    if (rec.smartWake || remainingMs <= 0 || !pageVisible()) return;
    rec.smartWake = w.setTimeout(function () { rec.smartWake = 0; schedule(); }, Math.max(250, remainingMs + 20));
  }

  /**
   * The first four confirmed fills are normal. The next two are incremental
   * inventory earned by a live session: fill 5 needs 3+ pageviews OR 60 seconds
   * active; fill 6 needs 4+ pageviews OR 120 seconds active. The exact values
   * come from the server config so diagnostics and production cannot drift.
   */
  function topScrollSmartAllows(rec, fills) {
    if (!rec || rec.placement !== 'topscroll' || !rec.options.smartFrequency) return true;
    /* Open/update the tab session on every eligible Top Scroll page, including
     * fills 1–4. Otherwise a new session that already has four 24h fills would
     * never be able to earn page 2/page 3 while fill 5 is waiting. */
    var session = topScrollSession(rec);
    rec.smartSessionPages = session.pages || 0;
    rec.smartSessionActiveMs = Math.round(session.activeMs || 0);
    var free = Math.max(0, parseInt(rec.options.smartFreeFills || 4, 10) || 4);
    if (fills < free) return true;
    var nextFill = fills + 1;
    if (nextFill < 5) return true;
    rec.smartNextFill = nextFill;
    if (!session.available) return false;
    var pagesNeeded = nextFill >= 6 ? Math.max(1, parseInt(rec.options.smartSixthPages || 4, 10) || 4) : Math.max(1, parseInt(rec.options.smartFifthPages || 3, 10) || 3);
    var msNeeded = nextFill >= 6 ? Math.max(1000, Number(rec.options.smartSixthMs) || 120000) : Math.max(1000, Number(rec.options.smartFifthMs) || 60000);
    if (session.pages >= pagesNeeded || session.activeMs >= msNeeded) return true;
    armTopScrollSmartWake(rec, msNeeded - session.activeMs);
    return false;
  }
  function gateStat(rec, name) {
    return rec.gateStats[name] || (rec.gateStats[name] = { entries: 0, checks: 0, foregroundMs: 0, inViewportChecks: 0 });
  }
  function closeGateClock(rec) {
    if (!gateDiagnostics || rec.gateStartMs == null) return;
    gateStat(rec, rec.state).foregroundMs += Math.max(0, now() - rec.gateStartMs);
    rec.gateStartMs = null;
  }
  function openGateClock(rec) {
    if (gateDiagnostics && pageVisible() && /^waiting-/.test(rec.state) && rec.gateStartMs == null) rec.gateStartMs = now();
  }
  function inspectGateTimings(rec) {
    if (!gateDiagnostics) return null;
    var result = {};
    Object.keys(rec.gateStats).forEach(function (name) {
      var item = rec.gateStats[name];
      result[name] = { entries: item.entries, checks: item.checks,
        foregroundMs: Math.round(item.foregroundMs + (name === rec.state && rec.gateStartMs != null ? Math.max(0, now() - rec.gateStartMs) : 0)),
        inViewportChecks: item.inViewportChecks };
    });
    return result;
  }
  function state(rec, value) {
    if (gateDiagnostics && /^waiting-/.test(value)) {
      var gate = gateStat(rec, value); gate.checks++;
      if (rec.lastRange && inView(rec.lastRange.rect) && pageVisible()) gate.inViewportChecks++;
      if (value === 'waiting-content-density' && rec.densityReason) rec.densityChecks[rec.densityReason] = (rec.densityChecks[rec.densityReason] || 0) + 1;
    }
    if (rec.state === value) return;
    closeGateClock(rec);
    rec.state = value;
    if (gateDiagnostics && /^waiting-/.test(value)) gateStat(rec, value).entries++;
    openGateClock(rec);
    rec.box.setAttribute('data-go-ad-state', value);
    rec.timeline.push({ state: value, ms: now() });
    if (rec.timeline.length > 24) rec.timeline.shift();
    try { d.dispatchEvent(new CustomEvent('go:ad-state', { detail: { placement: rec.placement, slot: rec.slot, state: value, ms: now() } })); } catch (e) {}
    if (rec.options.debug && w.console && typeof w.console.debug === 'function') {
      w.console.debug('[GO Ads]', { placement: rec.placement, state: value, tier: tierOf(rec),
        governor: engine.governor, distance: rec.distanceToViewport, arrivalMs: rec.estimatedArrivalMs,
        expectedValue: Math.round(expectedValue(rec) * 1000) / 1000, availableWidth: rec.availableWidth == null ? null : Math.round(rec.availableWidth) });
    }
  }
  function changedConsent() {
    var granted = permission();
    if (granted !== storageConsent) {
      engine.readerModel = null;
      engine.topScrollSession = null;
      /* Resuming storage permission starts this document's active contribution
       * now. Consent must not be used to backfill time measured before it. */
      engine.topScrollDwellBase = dwellMs();
      storageConsent = granted;
      if (!granted) latencyMemory = { loaded: false, profile: '', updatedAt: 0, samples: [], imported: 0 };
    }
    if (granted) loadLatencyMemory();
    records.forEach(persistFill);
    if (granted && pageVisible()) resumeTopScrollSession(false);
    schedule();
  }
  function allowed(rec) { return !rec.options.gate || permission(); }
  function tierOf(rec) { return (rec && rec.tier && RULES.rest_lead_vh[rec.tier] != null) ? rec.tier : 'standard'; }

  /* ------------------------------------------------------------ daypart prior */

  function yieldProfileParts() {
    try {
      var tz = YIELD.timezone || 'America/Sao_Paulo';
      var parts = new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: '2-digit', hour12: false, weekday: 'short' }).formatToParts(new Date());
      var hour = 12, weekday = '';
      parts.forEach(function (part) { if (part.type === 'hour') hour = parseInt(part.value, 10); if (part.type === 'weekday') weekday = part.value; });
      if (hour === 24) hour = 0;
      return { hour: isFinite(hour) ? hour : 12, weekday: weekday };
    } catch (e) { return { hour: (new Date()).getHours(), weekday: '' }; }
  }
  function currentProfileName() {
    var minute = Math.floor(Date.now() / 60000);
    if (profileCache.minute === minute && profileCache.name) {
      engine.profileName = profileCache.name; engine.profileHour = profileCache.hour; engine.profileWeekday = profileCache.weekday;
      return profileCache.name;
    }
    var parts = yieldProfileParts(), maps = YIELD.dayparts || {}, name = 'peak';
    if (listHas(maps.guard, parts.hour)) name = 'guard';
    else if (listHas(maps.shoulder, parts.hour)) name = 'shoulder';
    profileCache = { minute: minute, name: name, hour: parts.hour, weekday: parts.weekday };
    engine.profileName = name; engine.profileHour = parts.hour; engine.profileWeekday = parts.weekday;
    return name;
  }
  function currentProfile() {
    var name = currentProfileName(), profiles = YIELD.profiles || {};
    return profiles[name] || profiles.shoulder || profiles.peak || {};
  }
  function engageScrollViewports() { return clamp(Math.max(RULES.engage_scroll_vh, num(currentProfile().engage_scroll_viewports, RULES.engage_scroll_vh)), 0.04, 0.40); }
  function engageDwellMs() { return clamp(Math.max(RULES.engage_dwell_ms, num(currentProfile().engage_dwell_ms, RULES.engage_dwell_ms)), 600, 8000); }
  function requestSpacingMs() {
    return Math.max(0, Math.round(RULES.request_spacing_ms));
  }

  /* ------------------------------------------------------------ historical unit priors */

  /**
   * The manual baseline never moves with a site-wide revenue/RPM regime.
   *
   * `slot_value` is the seven-day revenue-per-request of each ad unit relative
   * to this site's own median opportunity; `slot_viewability` is that unit's
   * reported Active View. These priors remain useful for order/local lead time,
   * but the model-generation timestamp must be present and at most 24h old.
   * It is not the report capture time or evidence of current auction prices.
   * Missing/stale models are neutral, never an inventory veto. Snapshot the
   * embedded fields once; no per-page REST fetch or financial delivery command.
   */
  var unitModel = (function () {
    var raw = YIELD.decision && typeof YIELD.decision === 'object' ? YIELD.decision : {};
    var generated = num(raw.generated_at, 0), samples = Math.max(0, num(raw.model_samples, 0)), priors = {}, neutral = {};
    [priors, neutral].forEach(function (out) {
      out.regime = 'manual_fixed'; out.delivery_mode = 'manual_fixed';
      out.supply_bias = 0; out.pacing_scale = 1;
      out.tier_lookahead = { reach: 1, premium: 1, standard: 1, deep: 1, completion: 1 };
      out.generated_at = generated;
      out.model_samples = samples;
      out.model_window = raw.model_window || null;
      out.model_max_age_seconds = 86400; out.model_future_tolerance_seconds = 300;
      out.freshness_source = 'unit-model-generation-not-report-capture';
      ['slot_value', 'slot_coverage', 'slot_viewability', 'tier_value'].forEach(function (key) {
        out[key] = out === priors && raw[key] && typeof raw[key] === 'object' ? raw[key] : {};
      });
    });
    priors.confidence = 'historical'; priors.fresh = true; priors.reasons = [];
    neutral.confidence = 'none'; neutral.fresh = false; neutral.reasons = ['unit-model-missing-or-stale'];
    return { generated: generated, samples: samples, priors: priors, neutral: neutral };
  })();
  function decision() {
    var age = Date.now() / 1000 - unitModel.generated;
    return unitModel.samples > 0 && unitModel.generated > 0 && age >= -300 && age <= 86400 ? unitModel.priors : unitModel.neutral;
  }
  function slotKey(rec) { return String((rec && rec.slot) || ''); }
  function fallbackTierValue(rec) { return clamp(num((decision().tier_value || {})[tierOf(rec)], 1), 0.35, 2.20); }
  function slotValue(rec) {
    /* A missing slot inherits its tier value. clamp() returns its minimum for a
     * non-finite input, so an explicit presence check is required: an unknown
     * unit must not silently become the worst on the site. */
    var raw = Number((decision().slot_value || {})[slotKey(rec)]);
    return (isFinite(raw) && raw > 0) ? clamp(raw, 0.25, 2.60) : fallbackTierValue(rec);
  }
  function slotCoverage(rec) { return clamp(num((decision().slot_coverage || {})[slotKey(rec)], 1), 0.70, 1.20); }
  function slotViewability(rec) {
    var value = Number((decision().slot_viewability || {})[slotKey(rec)]);
    return (isFinite(value) && value > 0) ? clamp(value, 0.15, 0.95) : null;
  }
  function tierWeight(rec) { return clamp(num((YIELD.tier_weights || {})[tierOf(rec)], 0.80), 0.45, 1.15); }

  /* ------------------------------------------------------------ reader model */

  function maxDocumentScroll() { return Math.max(1, Math.max(d.documentElement.scrollHeight || 0, d.body ? d.body.scrollHeight : 0) - viewportHeight()); }
  function currentScrollDepth() { return clamp(scrollY() / maxDocumentScroll(), 0, 1); }
  function readerDepth() { return Math.max(engine.maxScrollDepth || 0, currentScrollDepth()); }
  function dwellMs() { return engine.dwellMs + (engine.dwellStart == null ? 0 : Math.max(0, now() - engine.dwellStart)); }
  function getReaderModel(refresh) {
    var base = { pages: 0, emaDepth: 0.5 };
    if (!YIELD.reader_model || YIELD.reader_model.enabled === false || !permission()) return base;
    if (engine.readerModel && !refresh) return engine.readerModel;
    try {
      var key = YIELD.reader_model.storage_key || 'go_ads_reader_depth_v1';
      var raw = JSON.parse(w.localStorage.getItem(key) || '{}');
      if (raw && typeof raw === 'object') {
        base.pages = Math.max(0, parseInt(raw.pages || 0, 10) || 0);
        var depth = Number(raw.emaDepth); if (isFinite(depth)) base.emaDepth = clamp(depth, 0, 1);
      }
    } catch (e) {}
    engine.readerModel = base; return base;
  }
  function persistReaderModel() {
    if (!YIELD.reader_model || YIELD.reader_model.enabled === false || !permission()) return;
    try {
      var model = getReaderModel(true), alpha = clamp(num(YIELD.reader_model.ema_alpha, 0.25), 0.05, 0.8);
      var depth = readerDepth(), checkpoint = engine.readerCheckpoint, next;
      if (checkpoint) {
        /* A later pagehide of this BFcache-restored document updates its depth
         * observation without counting another page. If other documents have
         * since contributed, decay this correction by their known count. This
         * is still an advisory local prior, never an analytics session count. */
        var correction = (depth - checkpoint.depth) * checkpoint.weight
          * Math.pow(1 - alpha, Math.max(0, model.pages - checkpoint.pages));
        next = { pages: model.pages, emaDepth: clamp(model.emaDepth + correction, 0, 1) };
      } else {
        next = { pages: Math.min(200, (model.pages || 0) + 1),
          emaDepth: (model.pages ? model.emaDepth : depth) * (1 - alpha) + depth * alpha };
      }
      next.emaDepth = Math.round(next.emaDepth * 1000) / 1000;
      w.localStorage.setItem(YIELD.reader_model.storage_key || 'go_ads_reader_depth_v1', JSON.stringify(next));
      engine.readerCheckpoint = { pages: checkpoint ? checkpoint.pages : next.pages,
        depth: depth, weight: checkpoint ? checkpoint.weight : (model.pages ? alpha : 1) };
      engine.readerModel = next;
    } catch (e) {}
  }
  /* --------------------------------------------------- entry context prior */

  /**
   * Where this reader arrived from, and the depth it implies before they move.
   *
   * Most sessions on this site are one pageview long, so the stored reader
   * model — which needs several pageviews before it says anything — is silent
   * on exactly the pageviews that matter most. Until the reader scrolls, every
   * estimate that consumes `readerPrior()` therefore fell back to a flat 0.5
   * for a Discover reader who will read to the end and for a search visitor who
   * will bounce in four seconds. They are not the same opportunity.
   *
   * `document.referrer` is read once, in RAM, and reduced immediately to one of
   * a handful of coarse buckets. No identifier is derived from it, nothing is
   * stored and nothing is transmitted; the full referrer never leaves this
   * function. It needs no storage permission because it creates no storage.
   *
   * The result is a PRIOR, not a verdict: `reachProbability()` already lets
   * measured depth dominate as soon as the reader moves, and the bucket values
   * are clamped so the prior can never reach either extreme. It deliberately
   * does NOT feed the governor's returning-deep-reader path, which must stay
   * evidence of this reader's own history rather than of their referrer.
   */
  var entryContext = (function () {
    var cfg = (YIELD.entry_context && typeof YIELD.entry_context === 'object') ? YIELD.entry_context : {};
    var out = { enabled: cfg.enabled !== false, source: 'unknown', depth: null, weight: 0 };
    if (!out.enabled) return out;
    /* Host only, lower-cased, no path and no query: a referrer can carry a
     * search term or a session token in either, and neither is ever read. */
    function hostOf(url) {
      var match = /^[a-z][a-z0-9+.-]*:\/\/([^/?#]*)/i.exec(String(url || ''));
      if (!match) return '';
      return String(match[1]).toLowerCase().replace(/^[^@]*@/, '').replace(/:\d+$/, '').replace(/^www\./, '');
    }
    try {
      var ref = typeof d.referrer === 'string' ? d.referrer : '';
      var host = hostOf(ref);
      var self = hostOf((w.location && w.location.href) || '');
      if (!ref) out.source = 'direct';
      else if (/^android-app:/i.test(ref)) out.source = /googlequicksearchbox/i.test(ref) ? 'google-app' : 'app';
      else if (!host) out.source = 'other';
      else if (self && host === self) out.source = 'internal';
      else if (/^news\.google\./.test(host) || /^(flipboard|smartnews)\./.test(host) || /(^|\.)msn\.com$/.test(host)) out.source = 'aggregator';
      else if (/(^|\.)(google|bing|duckduckgo|yahoo|ecosia|yandex|baidu)\./.test(host) || /(^|\.)brave\.com$/.test(host)) out.source = 'search';
      else if (/(^|\.)(facebook|instagram|twitter|x|t|reddit|linkedin|pinterest|tiktok|youtube|whatsapp|telegram)\.[a-z.]+$/.test(host)) out.source = 'social';
      else out.source = 'other';
    } catch (e) { out.source = 'unknown'; }
    var priors = (cfg.depth_priors && typeof cfg.depth_priors === 'object') ? cfg.depth_priors : {};
    var raw = Number(priors[out.source]);
    if (isFinite(raw) && raw > 0) {
      out.depth = clamp(raw, num(cfg.min_prior, 0.35), num(cfg.max_prior, 0.72));
      out.weight = clamp(num(cfg.weight, 1), 0, 1);
    }
    return out;
  })();

  /**
   * Depth prior from this reader's own stored history alone.
   *
   * The governor's returning-deep-reader path reads THIS, never the blended
   * value: arriving from a source that usually reads deeply is not evidence
   * that this reader does, and must not open the planner's reserve hosts.
   */
  function storedReaderPrior() {
    var model = getReaderModel();
    return model.pages >= num((YIELD.reader_model || {}).min_pages, 3) ? model.emaDepth : null;
  }
  /**
   * Depth prior for value estimation: this reader's measured history when it
   * exists, otherwise the entry-context bucket, otherwise a neutral 0.5.
   */
  function readerPrior() {
    var stored = storedReaderPrior();
    if (stored != null) return stored;
    if (entryContext.depth == null || entryContext.weight <= 0) return 0.5;
    return clamp(0.5 + (entryContext.depth - 0.5) * entryContext.weight, 0, 1);
  }
  function engagementScore() {
    return clamp(currentScrollDepth() * 0.50 + Math.min(1, dwellMs() / 18000) * 0.28 + readerPrior() * 0.22, 0, 1);
  }

  /**
   * Local fill/latency pulse from this pageview's own critical units.
   *
   * It measures whether Google is answering quickly and matching requests right
   * now. It does not observe bids, prices or the auction.
   */
  function auctionSignal() {
    var cfg = YIELD.auction_signal || {}, responded = 0, filled = 0, totalMs = 0, timed = 0;
    records.forEach(function (r) {
      if (!r.critical || !r.providerStatus) return;
      responded++;
      /* Optimized empty slots can contain provider suggestions, but they are
       * not ad fills and must not strengthen the predictive fill signal. */
      if (r.providerStatus === 'filled') filled++;
      if (r.responseMs != null) { totalMs += r.responseMs; timed++; }
    });
    if (responded < num(cfg.min_critical_responses, 2)) { engine.auctionSignal = 'neutral'; return 'neutral'; }
    var fill = filled / responded, avg = timed ? totalMs / timed : 9999;
    if (fill >= num(cfg.strong_fill_rate, 0.67) && avg <= num(cfg.strong_response_ms, 1500)) engine.auctionSignal = 'strong';
    else if (fill <= num(cfg.weak_fill_rate, 0.34) || avg >= num(cfg.weak_response_ms, 2600)) engine.auctionSignal = 'weak';
    else engine.auctionSignal = 'neutral';
    return engine.auctionSignal;
  }

  /* ------------------------------------------------------------ the governor */

  /**
   * Four states, decided from this session's own measured behaviour.
   *
   *   WARMUP        nothing proven yet. Critical and nearby publisher positions
   *                 remain eligible, with a shorter advance ceiling.
   *   STANDARD      an engaged reader. The planner's ladder is the budget.
   *   CONSERVATIVE  sustained flick-scrolling. Supply is NOT cut — a reader who
   *                 blows past a slot never requests it anyway. What changes is
   *                 that predictive lookahead stops racing ahead of them and
   *                 spacing widens, so the engine does not spend inventory on
   *                 motion that cannot produce a viewable impression.
   *   EXPANSION     depth and dwell prove a real read. The advance budget can
   *                 include the planner's safe rendered reserve hosts.
   *
   * EXPANSION is one-way. Independently, a reserve the reader has reached can
   * qualify through reachedReserveAllows(), subject to the downstream gates.
   */
  function governorSpacingScale() { return num(RULES.governor.spacing_scale[engine.governor], 1); }
  function setGovernor(next, reason) {
    if (engine.governor === next) return;
    engine.governorLog.push({ from: engine.governor, to: next, reason: reason, ms: now(), depth: Math.round(readerDepth() * 1000) / 1000 });
    if (engine.governorLog.length > 12) engine.governorLog.shift();
    engine.governor = next;
    engine.governorSince = now();
    engine.governorReason = reason;
    try { d.dispatchEvent(new CustomEvent('go:ads-governor', { detail: { state: next, reason: reason } })); } catch (e) {}
  }
  /**
   * A reader who is already deep enough and is simply reading will cross the
   * dwell threshold without producing any event.
   *
   * Nothing else on the page would wake the queue for them, so the governor
   * arms exactly one timer for the moment they qualify. It is not polling: it
   * is armed only when dwell is the single missing ingredient, and it is
   * cancelled as soon as EXPANSION opens or the reader scrolls (which
   * re-evaluates and re-arms with the new remaining time).
   */
  function armDwellWake(remainingMs) {
    if (engine.dwellWake) return;
    engine.dwellWake = w.setTimeout(function () { engine.dwellWake = 0; schedule(); }, Math.max(250, remainingMs + 20));
  }
  function evaluateGovernor() {
    if (engine.dwellWake) { w.clearTimeout(engine.dwellWake); engine.dwellWake = 0; }
    if (!engine.engaged) { setGovernor('warmup', 'awaiting-engagement'); return; }
    var gov = RULES.governor, depth = readerDepth(), dwell = dwellMs();
    /* Fixed physical baseline: aggregate price/revenue never opens or delays
     * an opportunity. Only the local reader can advance these thresholds. */
    var depthBar = clamp(gov.expansion_depth, 0.20, 0.90);
    var deepBar = clamp(gov.expansion_deep_depth, 0.30, 0.95);

    if (engine.governor !== 'expansion') {
      if (depth >= deepBar) { setGovernor('expansion', 'scroll-depth'); return; }
      if (depth >= depthBar && dwell >= gov.expansion_dwell_ms) { setGovernor('expansion', 'depth-and-dwell'); return; }
      var stored = storedReaderPrior();
      if (stored != null && stored >= gov.expansion_prior_depth && depth >= gov.expansion_prior_floor) { setGovernor('expansion', 'returning-deep-reader'); return; }
      if (depth >= depthBar && pageVisible()) armDwellWake(gov.expansion_dwell_ms - dwell);
    } else {
      return;
    }
    if (motion.paceVh > RULES.flick_vh_s) { setGovernor('conservative', 'sustained-fast-scroll'); return; }
    setGovernor('standard', 'engaged-reading');
  }

  /* ------------------------------------------------------------ article plan */

  /* Resolved once per sweep. Every density check and every budget check asks
   * for it, so a fresh querySelector per candidate per frame was a measurable
   * share of the engine's scroll cost for a node that cannot change. */
  var contentNode = null, contentFrame = -1;
  function articleContentNode() {
    if (contentFrame !== frameId) {
      contentFrame = frameId;
      contentNode = d.querySelector('[data-go-manual-ads-root="article"], .go-article__content, .entry-content, .go-single__content');
    }
    return contentNode;
  }
  function isArticle() { return !!(d.body && d.body.classList.contains('single-post')); }
  var planFrame = -1;
  function syncArticlePlan() {
    /* Read once per sweep: the attributes are server-rendered and static. */
    if (planFrame === frameId) return;
    var node = articleContentNode();
    if (!node || typeof node.getAttribute !== 'function') return;
    planFrame = frameId;
    var read = function (name) { return parseInt(node.getAttribute('data-go-ad-plan-' + name) || '', 10) || 0; };
    var hasTelemetry = node.hasAttribute('data-go-ad-plan-planned-body') || node.hasAttribute('data-go-ad-plan-body-capacity');
    if (!hasTelemetry) return;
    engine.plannerTelemetry = true;
    engine.articleWords = Math.max(engine.articleWords || 0, read('body-words'));
    engine.plannedBodyCount = Math.max(engine.plannedBodyCount || 0, read('planned-body'));
    engine.renderedBodyCount = Math.max(engine.renderedBodyCount || 0, read('rendered-body'));
    engine.reserveBodyCount = Math.max(engine.reserveBodyCount || 0, read('reserve-body'));
    engine.eligibleCandidates = Math.max(engine.eligibleCandidates || 0, read('eligible-candidates'));
    engine.structuralBodyCapacity = Math.max(engine.structuralBodyCapacity || 0, read('body-capacity'));
    engine.plannerVersion = node.getAttribute('data-go-ad-plan-planner-version') || engine.plannerVersion || '';
    engine.articleType = node.getAttribute('data-go-ad-plan-article-type') || engine.articleType || '';
  }
  function articleWords() {
    syncArticlePlan();
    if (engine.articleWords > 0) return engine.articleWords;
    var node = articleContentNode();
    if (!node) return 0;
    var total = ((node.textContent || '').match(/\S+/g) || []).length;
    /* Publisher disclosure labels and ad hosts are markup, not editorial length. */
    var ads = 0;
    Array.prototype.forEach.call(node.querySelectorAll('.go-ad-slot'), function (el) {
      ads += ((el.textContent || '').match(/\S+/g) || []).length;
    });
    engine.articleWords = Math.max(0, total - ads);
    return engine.articleWords;
  }

  function isBodyRecord(rec) { return /^(article|article-prime)$/.test(rec.surface || ''); }
  function isCompletionRecord(rec) { return (rec.surface || '') === 'article-completion' || tierOf(rec) === 'completion'; }

  /**
   * Whether a request is still holding its share of the article's opportunity
   * budget.
   *
   * Google writes `data-ad-status` when it resolves a request. Treating a
   * request with no answer as permanently occupied — the 11.x behaviour —
   * meant one silent unit cost a long article an entire structurally-safe
   * position for the whole pageview. After `stuck_release_ms` the OPPORTUNITY
   * is handed to the next safe host. The silent unit itself is never asked
   * again; one request per placement, per pageview, still stands.
   */
  function requestBudgetOccupied(r) {
    if (!r.requested || r.closed || !r.box.isConnected || r.error || r.providerStatus === 'unfilled') return false;
    if (/^(filled|unfill-optimized)$/.test(r.providerStatus || '')) return true;
    if (r.providerStatus) return true;
    return (now() - r.requestedMs) < RULES.stuck_release_ms;
  }
  function countOccupied(filter) {
    var n = 0;
    records.forEach(function (r) { if (requestBudgetOccupied(r) && filter(r)) n++; });
    return n;
  }

  /**
   * In-body opportunity budget.
   *
   * The planner has already proved which body hosts are structurally safe on
   * the rendered page; the runtime's job is real geometry, reach and exposure,
   * not a second, lower capacity invented in the browser. Without planner
   * telemetry (a template with no planner) the ladder simply does not exist.
   */
  function bodyBudget() {
    syncArticlePlan();
    if (!engine.plannerTelemetry) return 0;
    var planned = Math.max(0, engine.plannedBodyCount || 0);
    /* No primary host, no advance budget. A renderer may reject every primary
     * while retaining a valid reserve; only reachedReserveAllows may admit that
     * remaining host once the reader reaches it, within structural capacity. */
    if (planned < 1) return 0;
    var rendered = Math.max(planned, engine.renderedBodyCount || 0);
    var structural = Math.max(planned, engine.structuralBodyCapacity || 0);
    var budget = planned;
    /* EXPANSION increases the advance budget up to safe rendered capacity.
     * Outside expansion, an individual reserve can still qualify at the reader
     * through reachedReserveAllows(), subject to every downstream gate. */
    if (engine.governor === 'expansion') budget = Math.min(rendered, structural);
    return Math.max(0, Math.round(budget));
  }
  function reachedReserveAllows(rec) {
    /* One delivery policy for every page. Storage, allocation or a separate
     * bootstrap never determines whether a structurally safe reserve exists. */
    if (!engine.plannerTelemetry || !isBodyRecord(rec)) return false;
    var maximum = Math.min(Math.max(0, engine.renderedBodyCount || 0), Math.max(0, engine.structuralBodyCapacity || 0));
    if (maximum < 1 || countOccupied(isBodyRecord) >= maximum) return false;
    var range = rangeFor(rec);
    if (!range || !range.rect) return false;
    /* Reached means an editorial opportunity at the reader, not a lower global
     * depth threshold. A small predictive allowance prevents arriving blank,
     * with no release for cold, distant or fast-flicking inventory. */
    var visible = inView(range.rect);
    var imminent = !visible && range.arrival != null && range.arrival <= responseEstimateFor(rec) + Math.max(250, num(rec.options.safetyMs, 600))
      && range.distance <= Math.min(restingLead(rec), usableViewportHeight() * 0.5)
      && motion.paceVh <= RULES.flick_vh_s && reachProbability(rec) >= 0.90;
    if (!visible && !imminent) return false;
    rec.reachedReserveQualified = true;
    rec.reachedReserveReason = visible ? 'in-useful-viewport' : 'predicted-arrival';
    return true;
  }
  function budgetAllows(rec) {
    if (rec.critical || !isArticle()) return true;
    if (isCompletionRecord(rec)) {
      /* Completion has its own soft budget. It earns a request when the reader
       * approaches it; it never reserves a body opportunity at page load. */
      return countOccupied(isCompletionRecord) < 1;
    }
    /* Sidebar and other publisher surfaces are independently positioned and are
     * not crowded out because the article body filled first. */
    if (!isBodyRecord(rec)) return true;
    if (countOccupied(isBodyRecord) < bodyBudget()) { rec.budgetPath = engine.governor === 'expansion' ? 'governor-expansion' : 'planned'; return true; }
    if (reachedReserveAllows(rec)) { rec.budgetPath = 'reached-reserve'; return true; }
    rec.budgetPath = 'waiting';
    return false;
  }

  /* ------------------------------------------------------------ density */

  /**
   * The footprint a not-yet-rendered creative is assumed to take.
   *
   * Cached per record per sweep: it derives from the host's width, which cannot
   * change inside one frame, and it is read once for the candidate plus once
   * for every neighbour of every candidate — which made it the single most
   * frequent getComputedStyle call in the engine during a scroll.
   */
  function nominalHeight(rec) {
    if (rec.nominalFrame !== frameId) {
      rec.nominalFrame = frameId;
      rec.nominalCache = Math.max(180, Math.min(320, widthOf(rec.box) * 0.62));
    }
    return rec.nominalCache;
  }
  /**
   * The footprint a placement occupies for density purposes.
   *
   * A responsive host commonly measures only its border/padding while the
   * provider is still resolving. Treating 8px as the full ad height would make
   * the next request look safely spaced even though the first creative can
   * still expand to ~250px, so until provider content is final we reserve at
   * least the nominal footprint.
   */
  function effectiveAdRect(rec) {
    var rect = rectOf(rec);
    var height = Math.max(0, num(rect.height, 0));
    if (rec && rec.requested && rec.providerStatus !== 'unfilled') {
      var requestedHeight = rec.requestSize ? Math.max(0, num(rec.requestSize.height, 0)) : 0;
      if (!/^(filled|unfill-optimized)$/.test(rec.providerStatus || '')) {
        height = Math.max(height, requestedHeight, nominalHeight(rec));
      } else if (height < 1) {
        height = Math.max(requestedHeight, nominalHeight(rec));
      }
    }
    if (height < 1) return rect;
    return {
      top: rect.top, bottom: rect.top + height, left: rect.left, right: rect.right,
      width: rect.width, height: height, x: rect.x, y: rect.y
    };
  }
  function horizontalOverlap(a, b) {
    var left = Math.max(num(a.left, a.x || 0), num(b.left, b.x || 0));
    var right = Math.min(num(a.right, left + num(a.width, 0)), num(b.right, left + num(b.width, 0)));
    var overlap = Math.max(0, right - left);
    var smaller = Math.max(1, Math.min(num(a.width, 0), num(b.width, 0)));
    return overlap / smaller;
  }
  function gapBetween(rect, candidateHeight, other) {
    return rect.top >= other.bottom ? rect.top - other.bottom
      : ((rect.top + candidateHeight) <= other.top ? other.top - (rect.top + candidateHeight) : 0);
  }
  /** Publisher and recognized automatic inventory occupying this column. */
  function occupiedNeighbours(rect) {
    var out = [];
    records.forEach(function (r) {
      if (!r.requested || r.closed || !r.box.isConnected || r.providerStatus === 'unfilled') return;
      var other = effectiveAdRect(r);
      if ((other.height || 0) < 1) return;
      if (horizontalOverlap(rect, other) < 0.15) return;
      out.push(other);
    });
    accountInPageRects().forEach(function (other) {
      if (horizontalOverlap(rect, other) >= 0.15) out.push(other);
    });
    return out;
  }
  /**
   * Which spacing floor applies.
   *
   * The question is what the reader is looking at, not which DOM node holds the
   * markup. Everything in the article column — the body ladder, the hero unit
   * and the completion unit below the last paragraph — is prose spacing.
   * Listing and home units sit between story cards, which are much taller than
   * a paragraph, so a unit there needs more room to read as an editorial break
   * rather than as another card.
   */
  function usesStreamSpacing(rec) { return !/^article/.test(rec.surface || ''); }
  function minGapFor(rec) {
    return Math.round((usesStreamSpacing(rec) ? RULES.min_stream_gap_px : RULES.min_gap_px) * governorSpacingScale());
  }

  /**
   * Local advertising density.
   *
   * Three rules, each answering a different failure:
   *   - a hard pixel floor, so two creatives never render almost touching even
   *     when the server's height estimate was wrong;
   *   - a unit count inside a window of ±`density_window_vh`, which is
   *     predictable BEFORE the auction returns a creative height;
   *   - an area ratio over the same window and over the whole article, which
   *     catches an unusually tall creative the count would miss.
   *
   * Above-the-fold inventory (masthead, hero, top scroll) participates as a
   * neighbour even though it lives outside the prose container: a unit 200px
   * above the first in-body position is visual crowding wherever its markup
   * sits. Side rails never participate, because a sticky column beside the
   * article shares a vertical band without stacking on it. A rail that moves
   * into the same column on resize participates like any other neighbour.
   */
  function densityAllows(rec) {
    rec.densityReason = '';
    if (rec.critical) return true;
    var vh = viewportHeight();
    var rect = rectOf(rec);
    var candidate = nominalHeight(rec);
    var minGap = minGapFor(rec);
    var half = vh * RULES.density_window_vh;
    var windowTop = rect.top - half;
    var windowBottom = rect.top + candidate + half;
    var windowHeight = Math.max(1, windowBottom - windowTop);

    var neighbours = occupiedNeighbours(rect);
    var localAds = 0, nearestGap = Infinity;
    neighbours.forEach(function (other) {
      var overlap = Math.min(other.bottom, windowBottom) - Math.max(other.top, windowTop);
      if (overlap > 0) localAds += overlap;
      nearestGap = Math.min(nearestGap, gapBetween(rect, candidate, other));
    });

    /* Two creatives never touch, whatever the ratios say. */
    if (nearestGap < minGap) { rec.densityReason = 'minimum-gap'; return false; }

    /*
     * The unit-count rule is checked from EVERY unit's point of view, not just
     * the candidate's.
     *
     * A window centred on the candidate is symmetric, so a unit added below an
     * existing one widens that existing unit's window too. Checking only the
     * candidate therefore let a fourth unit slip into a window that already
     * held three, measured from the second unit — the reader saw the density
     * the rule was written to prevent. With at most eleven placements on a
     * page this pass is a handful of comparisons.
     */
    var candidateRect = { top: rect.top, bottom: rect.top + candidate };
    var boxes = neighbours.concat([candidateRect]);
    for (var i = 0; i < boxes.length; i++) {
      var from = boxes[i].top - half, to = boxes[i].bottom + half, count = 0;
      /* Only windows this candidate joins can gain another unit. A previous
       * cluster may already exceed the count after a viewport/layout change;
       * it must not veto a distant opportunity that leaves that window alone.
       * The candidate's own window and every affected neighbour still count. */
      if (candidateRect.bottom <= from || candidateRect.top >= to) continue;
      for (var j = 0; j < boxes.length; j++) {
        if (boxes[j].bottom > from && boxes[j].top < to) count++;
      }
      if (count > RULES.max_units_in_window) { rec.densityReason = 'unit-window'; return false; }
    }
    if ((localAds + candidate) > windowHeight * RULES.max_local_ad_ratio) { rec.densityReason = 'local-area-ratio'; return false; }

    /* Whole-article pressure applies to in-body inventory only: listing units
     * sit between story cards, where there is no prose column to measure. */
    if (!isBodyRecord(rec)) return true;
    var content = articleContentNode();
    if (!content || !content.contains(rec.box)) return true;
    var articleAds = 0;
    records.forEach(function (r) {
      if (r === rec || !r.requested || r.closed || r.providerStatus === 'unfilled' || !content.contains(r.box)) return;
      articleAds += Math.max(0, effectiveAdRect(r).height || 0);
    });
    accountInPageRects().forEach(function (other) {
      if (content.contains(other.node) && horizontalOverlap(rect, other) >= 0.15) articleAds += other.height;
    });
    var total = Math.max(1, content.scrollHeight || content.getBoundingClientRect().height || 1);
    var fits = (articleAds + candidate) <= total * RULES.max_ad_to_content_ratio;
    if (!fits) rec.densityReason = 'article-area-ratio';
    return fits;
  }

  /* ------------------------------------------------------------ pacing */

  function armPace(ms) {
    if (engine.paceTimer) return;
    engine.paceTimer = w.setTimeout(function () { engine.paceTimer = 0; schedule(); }, Math.max(20, ms + 5));
  }
  function pacingAllows(rec) {
    if (rec.critical) return true;
    var spacing = requestSpacingMs(), elapsed = now() - engine.lastNonCriticalRequestAt;
    if (elapsed >= spacing) return true;

    /* Pacing smooths the network; it is never a reason to let a safe slot
     * physically pass the reader. A fast flick can move more than a viewport
     * during 100ms on mobile. */
    var remaining = Math.max(0, spacing - elapsed);
    var info = rangeFor(rec), rect = info && info.rect;
    if (inView(rect)) return true;
    if (info && info.arrival != null && info.arrival <= remaining + clamp(responseEstimateFor(rec) * 0.25, 100, 350)) return true;

    armPace(remaining); return false;
  }

  /* ------------------------------------------------------------ value & order */

  /**
   * Probability that the reader actually reaches this placement.
   *
   * Proximity dominates a statistical prior: a unit three quarters of a screen
   * away is about to be seen regardless of reading habits.
   */
  function reachProbability(rec) {
    var range = rangeFor(rec), rect = range.rect, vh = viewportHeight();
    if (!rect) return 0.5;
    if (inView(rect)) return 1;
    var distance = Math.max(0, range.distance || 0);
    /* Behind the reader and moving back toward it: the depth is already proven. */
    if (rect.bottom <= 0) return motion.direction < 0 ? 0.95 : 0.35;

    var targetDepth = clamp((scrollY() + rect.top) / Math.max(1, maxDocumentScroll() + vh), 0, 1);
    var reached = readerDepth();
    if (targetDepth <= reached + 0.02) return 1;

    var stamina = clamp(readerPrior() * 0.55 + engagementScore() * 0.45, 0.10, 1);
    var p = clamp(Math.exp(-(targetDepth - reached) / Math.max(0.08, stamina * 0.85)), 0.05, 1);
    if (distance <= vh * 0.75) p = Math.max(p, 0.92);
    else if (distance <= vh * 1.60) p = Math.max(p, 0.74);
    else if (distance <= vh * 2.60) p = Math.max(p, 0.52);
    return p;
  }
  /* slotValue already measures revenue per REQUEST, including unfilled
   * attempts. Multiplying coverage again would count the same loss twice. */
  function expectedValue(rec) { return slotValue(rec) * reachProbability(rec); }

  /**
   * Ranking for simultaneously eligible candidates.
   *
   * Placement selection only: it changes the ORDER in which publisher positions
   * ask Google, never the auction, the bid or the creative. A unit the reader is
   * already looking at always beats a farther one.
   */
  function requestPriority(rec) {
    if (!rec || rec.requested || rec.closed || !rec.box || !rec.box.isConnected) return -100000;
    var range = rangeFor(rec), rect = range.rect, vh = viewportHeight();
    if (rec.critical) return 100000 - Math.max(0, range.distance || 0);
    if (inView(rect)) return 50000 + slotValue(rec) * 1000;
    return expectedValue(rec) * tierWeight(rec) * 10000 - Math.max(0, range.distance || 0) / 50;
  }

  /* ------------------------------------------------------------ motion */

  function sampleMotion() {
    var t = now(), y = scrollY(), dt = Math.max(1, t - motion.t), raw = ((y - motion.y) / dt) * 1000;
    if (Math.abs(raw) < 8) raw = 0;
    motion.velocity = motion.velocity * 0.72 + raw * 0.28;
    motion.direction = motion.velocity > 20 ? 1 : (motion.velocity < -20 ? -1 : 0);
    /* Smoothed reading pace in viewports per second. The governor reads this
     * rather than an instantaneous sample, so one wheel tick cannot flip a
     * state and a genuine flick cannot be averaged away. */
    motion.paceVh = motion.paceVh * 0.72 + (Math.abs(raw) / Math.max(1, viewportHeight())) * 0.28;
    /* Travel memory for the skim gate: absolute distance per scroll sample. */
    motion.trail.push({ t: t, dy: Math.abs(y - motion.y) });
    while (motion.trail.length && t - motion.trail[0].t > VIEW_POLICY.skim_window_ms) motion.trail.shift();
    motion.lastScrollT = t;
    motion.y = y; motion.t = t;
  }
  /**
   * Skimming: more than `skim_vh` screens travelled in the last
   * `skim_window_ms`, pauses included.
   *
   * The flick test above sees only instantaneous speed, and the settle timer
   * zeroes it 170ms after every stop, so a reader who flicks a screen, glances
   * for half a second and flicks again looked "still" at every pause. Each
   * pause released the units ahead; the creative arrived about a second later,
   * after the reader had gone. Served, counted, never viewable — and on Google
   * Ads display demand a non-viewable impression is also nearly unpaid, because
   * CPM campaigns there bid on viewable impressions. This window remembers the
   * rhythm across the pauses.
   */
  function skimming() {
    if (!VIEW_POLICY.enabled || !(VIEW_POLICY.skim_vh > 0)) return false;
    var t = now(), travel = 0;
    for (var i = motion.trail.length - 1; i >= 0 && t - motion.trail[i].t <= VIEW_POLICY.skim_window_ms; i--) travel += motion.trail[i].dy;
    engine.skimTravelVh = Math.round((travel / Math.max(1, viewportHeight())) * 100) / 100;
    return travel > viewportHeight() * VIEW_POLICY.skim_vh;
  }
  function percentile(values, p) {
    if (!values || !values.length) return null;
    var sorted = values.slice().sort(function (a, b) { return a - b; });
    return sorted[Math.max(0, Math.min(sorted.length - 1, Math.ceil(sorted.length * clamp(p, 0.5, 0.99)) - 1))];
  }
  function latencyProfile() {
    var c = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    var device = (w.innerWidth || d.documentElement.clientWidth || 0) >= RULES.desktopMinWidth ? 'desktop' : 'mobile';
    return device + ':' + (c ? String(c.effectiveType || 'unknown') : 'unknown') + ':' + (c && c.saveData ? 'save' : 'normal');
  }
  function latencyMemoryEnabled() { return DELIVERY.latency_memory === true && permission(); }
  function loadLatencyMemory() {
    if (!latencyMemoryEnabled()) return;
    var profile = latencyProfile(), wall = Date.now();
    var ttl = clamp(num(DELIVERY.memory_ttl_ms, 1800000), 60000, 3600000);
    if (latencyMemory.loaded && latencyMemory.profile === profile) {
      if (wall - latencyMemory.updatedAt > ttl) latencyMemory.samples = [];
      return;
    }
    if (latencyMemory.profile && latencyMemory.profile !== profile) { presentResponseTimes = []; responseEstimateMs = 1050; }
    latencyMemory = { loaded: true, profile: profile, updatedAt: 0, samples: [], imported: 0 };
    try {
      var raw = JSON.parse(w.sessionStorage.getItem('go_ads_fill_latency_v2') || '{}');
      var updated = num(raw.updatedAt, 0);
      if (raw.version !== 2 || raw.profile !== profile || !updated || updated > wall + 300000 || wall - updated > ttl || !Array.isArray(raw.samples)) return;
      latencyMemory.samples = raw.samples.filter(function (ms) { return typeof ms === 'number' && isFinite(ms) && ms >= 150 && ms <= 4000; }).slice(-24);
      latencyMemory.updatedAt = updated;
      latencyMemory.imported = latencyMemory.samples.length;
    } catch (e) { /* A missing or blocked store leaves the page-local model intact. */ }
  }
  function persistLatencyMemory() {
    if (!latencyMemoryEnabled() || !presentResponseTimes.length) return;
    loadLatencyMemory();
    try {
      w.sessionStorage.setItem('go_ads_fill_latency_v2', JSON.stringify({ version: 2,
        profile: latencyProfile(), updatedAt: Date.now(),
        samples: latencyMemory.samples.concat(presentResponseTimes).slice(-24).map(Math.round) }));
    } catch (e) {}
  }
  function predictionSamples() {
    /* Three fresh fills replace the prior. Before that, at most six compatible
     * samples from this tab reduce cold-start error without dominating a changed
     * provider on the new page. No-fill and optimized suggestions are excluded. */
    loadLatencyMemory();
    if (!latencyMemoryEnabled() || presentResponseTimes.length >= 3) return presentResponseTimes;
    var old = latencyMemory.samples.slice(-Math.max(0, 6 - presentResponseTimes.length * 2));
    return old.concat(presentResponseTimes);
  }
  /**
   * How long this tier should expect to wait for a creative.
   *
   * High-reach positions use a pessimistic percentile so they are ready when
   * the reader arrives; deep positions use a tighter one so they stay colder
   * and are more likely to be seen once served.
   */
  function responseEstimateFor(rec) {
    var samples = predictionSamples();
    if (samples.length < 3) return responseEstimateMs;
    var tier = tierOf(rec), p = 0.85;
    if (tier === 'reach' || tier === 'premium') p = 0.90;
    else if (tier === 'deep') p = 0.78;
    else if (tier === 'completion') p = 0.72;
    var estimate = percentile(samples, p);
    return estimate == null ? responseEstimateMs : clamp(estimate, 650, 4000);
  }
  function learnFilledResponse(ms) {
    loadLatencyMemory();
    ms = clamp(ms, 150, 4000);
    presentResponseTimes.push(ms);
    if (presentResponseTimes.length > 32) presentResponseTimes.shift();
    var presentP85 = percentile(presentResponseTimes, 0.85);
    responseEstimateMs = presentResponseTimes.length >= 3 ? presentP85 : Math.max(1050, presentP85 || 0);
    persistLatencyMemory();
  }
  function learnResponse(ms, providerStatus, foregroundOnly) {
    ms = Number(ms);
    if (!isFinite(ms) || ms < 1) return;
    ms = clamp(ms, 150, 4000);
    /* A no-fill can return much faster than a rendered creative. Mixing the two
     * populations teaches an unrealistically low render latency and makes the
     * next filled unit request too late, so lead time is learned only from
     * responses that actually produced provider content. */
    responseTimes.push(ms);
    if (responseTimes.length > 32) responseTimes.shift();
    if (providerStatus === 'filled' && foregroundOnly) learnFilledResponse(ms);
  }
  function belowViewport(rec) { return rec.box.getBoundingClientRect().top >= viewportHeight() + 32; }
  function aboveViewport(rec) { return rec.box.getBoundingClientRect().bottom <= -32; }

  /* ------------------------------------------------------------ engagement */

  function engage(reason) {
    if (engine.engaged) return;
    engine.engaged = true;
    engine.engagedBy = reason;
    engine.engagedAtMs = now();
    /* The engagement timer has done its job; the reading clock keeps running. */
    if (engine.dwellTimer) { w.clearTimeout(engine.dwellTimer); engine.dwellTimer = 0; }
    pending.forEach(watchProximity);
    try { d.dispatchEvent(new CustomEvent('go:ads-engaged', { detail: { reason: reason } })); } catch (e) {}
    schedule();
  }
  function checkScrollEngagement() {
    if (!engine.engaged && scrollY() >= viewportHeight() * engageScrollViewports()) engage('scroll');
  }
  /**
   * Time the reader has actually spent on this page, with the clock paused
   * while the tab is in the background.
   *
   * It serves two different jobs, and conflating them was a bug: the first
   * couple of seconds decide ENGAGEMENT, and the running total is one of the
   * two things that can earn a session EXPANSION. Stopping the clock once the
   * reader engaged — the 4.x behaviour, where dwell existed only to fire the
   * engagement timer — froze the total at about two seconds, so the
   * depth-and-dwell path to EXPANSION could never be reached.
   */
  function stopDwell() {
    /* Pausing also disarms the engagement timer: a tab in the background must
     * not become "engaged" while nobody is looking at it. startDwell() re-arms
     * it with the time that was actually left. */
    if (engine.dwellTimer) { w.clearTimeout(engine.dwellTimer); engine.dwellTimer = 0; }
    if (engine.dwellStart != null) { engine.dwellMs += Math.max(0, now() - engine.dwellStart); engine.dwellStart = null; }
  }
  function startDwell() {
    if (!pageVisible() || engine.dwellStart != null) return;
    engine.dwellStart = now();
    if (engine.engaged || engine.dwellTimer) return;
    engine.dwellTimer = w.setTimeout(function () { engine.dwellTimer = 0; engage('dwell'); },
      Math.max(0, engageDwellMs() - dwellMs()));
  }

  function releaseCritical(rec) {
    if (engine.criticalInFlight.delete(rec) && !engine.criticalInFlight.size) schedule();
  }
  function armHold(ms) {
    if (engine.holdTimer) return;
    engine.holdTimer = w.setTimeout(function () { engine.holdTimer = 0; schedule(); }, Math.max(16, ms + 8));
  }
  /**
   * Critical-first staging: while above-the-fold inventory is in flight, other
   * placements wait a short bounded window so the first auctions are not
   * competing with body requests for the same connections. It may never make a
   * body unit late — a position the reader is about to reach is released now.
   */
  function criticalHold(rec) {
    if (rec.critical || engine.engaged || !engine.criticalInFlight.size) return false;
    var remaining = engine.criticalHoldUntil - now();
    if (remaining <= 0) return false;
    var info = rangeFor(rec), rect = info && info.rect;
    if (inView(rect)) return false;
    var tier = tierOf(rec), vh = viewportHeight();
    var releaseVh = tier === 'reach' ? 0.38 : (tier === 'premium' ? 0.30 : 0);
    if (releaseVh > 0 && info && info.distance <= clamp(vh * releaseVh, 180, 360)) return false;
    if (info && info.arrival != null && info.arrival <= responseEstimateFor(rec) + Math.max(250, num(rec.options.safetyMs, 600)) + remaining) return false;
    if (rec.holdStartMs == null) rec.holdStartMs = now();
    armHold(remaining);
    return true;
  }

  /**
   * Premium formats in reading order.
   *
   * Top Scroll, Top Display and Hero Overlay are all critical, and each used to
   * ask the moment it was mounted: on a phone, three auctions and three
   * creatives competed for one connection while the headline was still
   * painting, whatever the reader could actually see. With `critical_stage_ms`
   * (mobile profile only; 0 disables it) a critical placement that is not yet in
   * the useful viewport waits while a critical placement ABOVE it still has no
   * answer from Google, for at most that long after that request. The unit on
   * screen asks and paints first; the next asks as soon as it has an answer. A
   * placement the reader reaches — visible, or arriving before a creative could
   * render — is released at once. Timing only: every placement still makes its
   * one request.
   */
  function criticalStage(rec) {
    var cap = RULES.critical_stage_ms;
    if (!rec.critical || !(cap > 0)) return false;
    var info = rangeFor(rec), rect = info && info.rect;
    if (!rect || inView(rect)) return false;
    if (info.arrival != null && info.arrival <= responseEstimateFor(rec) + Math.max(250, num(rec.options.safetyMs, 600))) return false;
    var wait = 0, t = now();
    engine.criticalInFlight.forEach(function (other) {
      if (other === rec || !other.requested || other.providerStatus || !other.box.isConnected) return;
      if (!(rectOf(other).top < rect.top)) return;
      wait = Math.max(wait, other.requestedMs + cap - t);
    });
    if (wait <= 0) return false;
    if (rec.stageStartMs == null) rec.stageStartMs = t;
    if (!engine.stageTimer) {
      engine.stageTimer = w.setTimeout(function () { engine.stageTimer = 0; schedule(); }, Math.max(16, wait + 8));
    }
    return true;
  }

  /* ------------------------------------------------------- largest paint gate */

  /**
   * Keep the first screen's own paint off the ad path.
   *
   * Above-the-fold inventory is this site's price anchor and is NEVER held
   * here: `critical` placements, anything already in the viewport and anything
   * the reader is about to reach all pass untouched. What this defers is the
   * one case that costs Core Web Vitals and buys nothing — a placement that is
   * still a screen away asking for a creative while the browser is still
   * painting the element that will become LCP. That request competes for the
   * same sockets, decoder and main thread as the hero image, and the creative
   * it returns cannot be seen for seconds yet.
   *
   * It is a bounded DEFERRAL, never a cancellation, and it is released by
   * whichever comes first:
   *   - the browser reporting a largest-contentful-paint entry, plus a short
   *     grace for a later, larger candidate;
   *   - any real interaction (a scroll, a pointer, a key), which is also what
   *     finalises LCP for the browser;
   *   - the hard ceiling below.
   *
   * Supply is unchanged: every placement this defers becomes eligible again on
   * the very next sweep after release, with its own gates re-evaluated.
   */
  var paintGate = { armed: false, released: true, releasedBy: 'disabled', holdMs: 0, maxHoldMs: 0, nearVh: 0.5,
    startedMs: 0, releasedMs: null, observer: null, graceTimer: 0, ceilingTimer: 0, deferred: 0 };
  function releasePaintGate(reason) {
    if (paintGate.released) return;
    paintGate.released = true;
    paintGate.releasedBy = reason;
    paintGate.releasedMs = now();
    if (paintGate.graceTimer) { w.clearTimeout(paintGate.graceTimer); paintGate.graceTimer = 0; }
    if (paintGate.ceilingTimer) { w.clearTimeout(paintGate.ceilingTimer); paintGate.ceilingTimer = 0; }
    if (paintGate.observer) { try { paintGate.observer.disconnect(); } catch (e) {} paintGate.observer = null; }
    schedule();
  }
  function armPaintGate() {
    var cfg = (YIELD.cwv && typeof YIELD.cwv === 'object') ? YIELD.cwv : {};
    var ceiling = clamp(num(cfg.paint_gate_max_hold_ms, 0), 0, 4000);
    if (paintGate.armed || cfg.paint_gate === false || ceiling < 50) return;
    paintGate.armed = true;
    paintGate.released = false;
    paintGate.releasedBy = '';
    paintGate.startedMs = now();
    paintGate.maxHoldMs = ceiling;
    paintGate.holdMs = clamp(num(cfg.paint_gate_grace_ms, 250), 0, 1500);
    paintGate.nearVh = clamp(num(cfg.paint_gate_near_vh, 0.5), 0, 2.0);
    /* The ceiling always exists, so a browser with no LCP reporting, a document
     * that never paints a candidate and a blocked observer all behave the same. */
    paintGate.ceilingTimer = w.setTimeout(function () { paintGate.ceilingTimer = 0; releasePaintGate('ceiling'); }, ceiling);
    try {
      if (typeof w.PerformanceObserver === 'function') {
        paintGate.observer = new w.PerformanceObserver(function () {
          if (paintGate.released || paintGate.graceTimer) return;
          paintGate.graceTimer = w.setTimeout(function () { paintGate.graceTimer = 0; releasePaintGate('largest-contentful-paint'); },
            Math.max(1, paintGate.holdMs));
        });
        paintGate.observer.observe({ type: 'largest-contentful-paint', buffered: true });
      }
    } catch (e) { /* An unsupported entry type leaves only the ceiling. */ }
  }
  /** Any genuine interaction finalises LCP for the browser; it ends the hold too. */
  function releasePaintGateOnInput() { releasePaintGate('interaction'); }

  /**
   * True while this placement should wait for the first paint to settle.
   *
   * The escapes matter more than the hold. This gate must never be stricter
   * than the critical-first hold sitting next to it in the ladder, because a
   * high-reach position a third of a screen below the fold is effectively
   * above-the-fold inventory: the reader is about to reach it, and it is not
   * what is competing with the LCP element for bandwidth. Holding it would
   * simply make it late.
   *
   * So four things always pass: critical priority, a host already in view, a
   * host arriving sooner than a creative could render, and anything within
   * `near_vh` of the fold. What remains — a placement most of a screen away,
   * eligible only because it sits inside its resting lead, before the reader
   * has moved at all — is the one case where an ad request genuinely competes
   * with the first paint and buys nothing by winning.
   */
  function paintHold(rec) {
    if (paintGate.released || rec.critical) return false;
    var info = rangeFor(rec), rect = info && info.rect;
    if (inView(rect)) return false;
    if (info && info.distance <= Math.round(viewportHeight() * paintGate.nearVh)) return false;
    if (info && info.arrival != null && info.arrival <= responseEstimateFor(rec) + Math.max(250, num(rec.options.safetyMs, 600))) return false;
    /* Once per placement. activate() re-runs this ladder every frame, so
     * incrementing on each check would report frames, not deferrals. */
    if (rec.paintHeldMs == null) { rec.paintHeldMs = now(); paintGate.deferred++; }
    return true;
  }

  /* ------------------------------------------------------------ viewport-first */

  /**
   * Stationary warm-up distance for one placement.
   *
   * The configured `near_viewport` is a ceiling. The real distance is a
   * fraction of the reader's own viewport, per tier, so a 640px phone and a
   * 1200px desktop prepare a slot at the same point in the reading experience.
   *
   * A unit whose measured Active View is poor is warmed LATER, not earlier:
   * requesting it closer to the viewport is the one legitimate way to raise the
   * share of its impressions that become viewable.
   */
  function restingLead(rec) {
    var configured = Math.max(0, num(rec.options.near, 0));
    if (!configured) return 0;
    var tier = tierOf(rec);
    var lead = clamp(usableViewportHeight() * RULES.rest_lead_vh[tier], RULES.rest_lead_min_px, RULES.rest_lead_max_px);
    lead = Math.max(VIEW_POLICY.min_lead_px, lead * viewabilityLeadScale(rec));
    return Math.min(configured, Math.round(lead));
  }

  /**
   * Active View controller, one ad unit at a time.
   *
   * The seven-day Active View of every unit arrives with the page (the Ads
   * Center syncs it; the model is refreshed every three hours and ignored once
   * it is a day old). Until 13.3 it moved the resting lead by at most -15% for
   * units under 35%, so a unit sitting at 30% kept asking for a creative most
   * of a screen before a reader who, more often than not, never arrived.
   * Those impressions are served, counted and not viewable: they pull the
   * site's Active View down, and Google prices every later impression of that
   * unit on the viewability it predicts from them.
   *
   * Now the lead is proportional to how far the unit is from the target band:
   * a unit at half the target asks from half the distance (never closer than
   * `floor`, never under `min_lead_px`). A unit inside the band keeps the table
   * value, and one comfortably above it may prepare slightly earlier. As the
   * unit's measured Active View rises the next model gives it its lead back,
   * so each unit settles inside the band instead of oscillating around one
   * global setting. Timing only: no unit is removed, refreshed or re-asked.
   * With no fresh model the scale is 1 and the table alone decides.
   */
  function viewabilityLeadScale(rec) {
    var view = slotViewability(rec);
    if (view == null || !VIEW_POLICY.enabled) return 1;
    var target = VIEW_POLICY.target;
    if (view >= target + VIEW_POLICY.healthy_margin) return VIEW_POLICY.healthy_scale;
    if (view >= target) return 1;
    return clamp(view / target, VIEW_POLICY.floor, 1);
  }
  /** A unit measured well below the band never asks during a flick, whatever its tier. */
  function viewabilityFlickGuard(rec) {
    var view = slotViewability(rec);
    return VIEW_POLICY.enabled && view != null && view < VIEW_POLICY.flick_guard_below;
  }
  /**
   * Geometry and timing for one placement, computed once per sweep.
   *
   * A slot becomes request-eligible when any of these is true:
   *   - it is inside the viewport;
   *   - it is within its stationary warm-up distance;
   *   - the reader is moving toward it and will arrive before a creative could
   *     realistically render (predicted arrival <= provider latency + safety).
   *
   * The predictive branch is capped by `max_lookahead_vh`, so however fast the
   * reader moves nothing is ever requested more than that far ahead.
   */
  function rangeInfo(rec) {
    /* Visibility is measured against the region the anchor leaves free; the
     * lookahead ceiling stays relative to the real screen, because how far a
     * reader travels does not change when an overlay covers part of it. */
    var rect = rectOf(rec), vh = viewportHeight(), seen = usableViewportHeight();
    var below = rect.top >= seen, above = rect.bottom < 0;
    var distance = below ? Math.max(0, rect.top - seen) : (above ? -rect.bottom : 0);
    var rest = restingLead(rec);
    var ceiling = Math.max(rest, Math.round(vh * RULES.max_lookahead_vh));

    /* A reader who has proven nothing yet only sees the first screen prepared. */
    if (!engine.engaged && !rec.critical) ceiling = Math.min(ceiling, Math.round(vh * RULES.governor.warmup_lookahead_vh));
    /* Flick-scrolling: stop racing ahead of motion that cannot be read. */
    if (engine.governor === 'conservative') ceiling = Math.min(ceiling, Math.round(vh * RULES.governor.conservative_lookahead_vh));

    var approaching = (below && motion.direction > 0) || (above && motion.direction < 0);
    var speed = Math.abs(motion.velocity), arrival = null, near = Math.min(rest, ceiling);

    if (rec.options.predictive && distance > 0 && approaching && speed > 80) {
      arrival = Math.round((distance / speed) * 1000);
      /*
       * Where the reader will STOP, not where the flick is heading.
       *
       * 12.7 multiplied the instantaneous velocity by the whole provider
       * latency (~1.6 s). A mobile flick peaks at 2,000-4,000 px/s and decays
       * in about a third of a second, so that projection asked for units two
       * to three screens past the point where the reader actually stopped.
       * Measured on live articles, those units were filled and never seen:
       * impressions that count against Active View and the price of every
       * other impression on the page, for no revenue of their own.
       *
       * A fling decelerates exponentially; the distance it still covers is
       * about velocity x time constant. The resting lead then applies from
       * that stopping point, exactly as it does for a reader who is not
       * moving, and a slower network widens the lead a little.
       */
      var travel = speed * RULES.fling_tau_s;
      var restFromStop = near * networkLeadScale();
      near = clamp(Math.max(near, travel + restFromStop), near, ceiling);
    }

    /* A missed slot stays inert behind a downward reader. On the way back up,
     * prepare it before it re-enters the viewport rather than after they pass. */
    var leadingEdge = motion.direction < 0 ? -near : -64;
    var eligible = rect.bottom >= leadingEdge && rect.top <= seen + near;

    rec.dynamicNear = Math.round(near);
    rec.estimatedArrivalMs = arrival;
    rec.distanceToViewport = Math.round(distance);
    return { eligible: eligible, near: near, ceiling: ceiling, distance: distance, arrival: arrival, rect: rect };
  }
  function rangeFor(rec) {
    if (rec.rangeFrame !== frameId || !rec.lastRange) {
      rec.lastRange = rangeInfo(rec);
      rec.rangeFrame = frameId;
      if (pageVisible() && (!rec.media || rec.media.matches)) {
        if (rec.lastRange.eligible && rec.firstNearbyMs == null) rec.firstNearbyMs = now();
        if (inView(rec.lastRange.rect) && rec.lastRange.rect.width > 0 && rec.firstOpportunityVisibleMs == null) rec.firstOpportunityVisibleMs = now();
      }
    }
    return rec.lastRange;
  }
  function networkLeadScale() {
    var c = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    if (!c) return 1;
    if (c.saveData) return 0.88;
    var type = String(c.effectiveType || '');
    if (type === 'slow-2g' || type === '2g') return 1.28;
    if (type === '3g') return 1.14;
    return 1;
  }
  function inRange(rec) { return rangeFor(rec).eligible; }

  /**
   * Exposure gate — the marginal-cost half of the decision.
   *
   * An opportunity is worth taking when its expected revenue exceeds its
   * marginal cost, and the dominant marginal cost here is a creative that is
   * served into motion nobody can read. Below `flick_vh_s` this never binds. At
   * flick speed the reader would cross the whole slot in a fraction of a
   * second, so a lower-tier position waits instead of spending itself; velocity
   * decays within ~170ms of the reader stopping, and the slot becomes eligible
   * again on the next sweep.
   *
   * Reach and premium positions are exempt: they are the site's price anchor
   * and are never withheld.
   */
  function exposureAllows(rec) {
    if (rec.critical) return true;
    var tier = tierOf(rec);
    var info = rangeFor(rec), rect = info && info.rect;
    /* A skimming reader gets no look-ahead at any tier: a unit is asked for only
     * once it is on screen AND the reader has actually stopped there. Once the
     * travel window drains, the ordinary lead-based delivery resumes. */
    if (skimming()) {
      rec.exposureReason = 'skimming';
      if (!inView(rect)) { armPace(Math.round(VIEW_POLICY.skim_window_ms / 2)); return false; }
      var still = now() - motion.lastScrollT;
      if (still < VIEW_POLICY.skim_settle_ms) { armPace(VIEW_POLICY.skim_settle_ms - still + 10); return false; }
      rec.exposureReason = 'skimming-settled';
      return true;
    }
    rec.exposureReason = '';
    if ((tier === 'reach' || tier === 'premium') && !viewabilityFlickGuard(rec)) return true;
    if (inView(rect)) return true;
    if (motion.paceVh <= RULES.flick_vh_s) return true;
    armPace(180);
    return false;
  }

  /* ------------------------------------------------------------ observers */

  function unwatchProximity(rec) {
    if (!rec.proximityGroup) return;
    rec.proximityGroup.observer.unobserve(rec.box);
    rec.proximityGroup.count--;
    if (!rec.proximityGroup.count) {
      rec.proximityGroup.observer.disconnect();
      delete proximityObservers[String(rec.proximityMargin)];
    }
    rec.proximityGroup = null;
  }
  /* Observers are shared by margin, so a page with eleven placements creates at
   * most a handful of IntersectionObservers rather than one each. */
  function watchProximity(rec) {
    if (rec.requested || rec.closed || typeof w.IntersectionObserver !== 'function') return;
    if (rec.media && !rec.media.matches) { unwatchProximity(rec); return; }
    var near = restingLead(rec);
    if (!engine.engaged && !rec.critical) near = Math.min(near, Math.round(viewportHeight() * RULES.governor.warmup_lookahead_vh));
    var margin = Math.round(near), key = String(margin);
    if (rec.proximityMargin === margin && rec.proximityGroup) return;
    unwatchProximity(rec);
    if (!proximityObservers[key]) {
      /* A host may move because an image or embed above it changes height, with
       * no scroll and no host resize. IO wakes the queue in that case. */
      proximityObservers[key] = { observer: new w.IntersectionObserver(schedule, { rootMargin: margin + 'px 0px', threshold: 0 }), count: 0 };
    }
    rec.proximityMargin = margin;
    rec.proximityGroup = proximityObservers[key];
    rec.proximityGroup.count++;
    rec.proximityGroup.observer.observe(rec.box);
  }

  /* Publisher ancestors only; third-party frames are never inspected. */
  function visibleHost(rec, host) {
    host = host || rec.box;
    if (typeof host.checkVisibility === 'function') {
      try {
        if (!host.checkVisibility({ contentVisibilityAuto: true, opacityProperty: true, visibilityProperty: true })) return false;
      } catch (e) { /* Older implementations fall back to publisher CSS below. */ }
    }
    for (var node = host; node && node.nodeType === 1; node = node.parentElement) {
      var css = w.getComputedStyle(node);
      if (node.hidden || css.display === 'none' || css.visibility === 'hidden' || css.visibility === 'collapse' ||
          css.contentVisibility === 'hidden' || parseFloat(css.opacity) === 0) return false;
      if (node.tagName === 'DETAILS' && !node.open) {
        var summary = node.querySelector(':scope > summary');
        if (!summary || !summary.contains(host)) return false;
      }
      if ((css.overflowY !== 'visible' && node.clientHeight < 1) || (css.overflowX !== 'visible' && node.clientWidth < 1)) return false;
    }
    return true;
  }
  function watchReveal(rec) {
    if (rec.revealObserver || typeof w.MutationObserver !== 'function') return;
    /* Ancestors of the waiting host only; never a document-wide observer. */
    rec.revealObserver = new w.MutationObserver(schedule);
    for (var node = rec.box; node && node.nodeType === 1; node = node.parentElement) {
      rec.revealObserver.observe(node, { attributes: true, attributeFilter: ['style', 'class', 'hidden', 'open'] });
    }
    rec.revealEnd = schedule;
    d.addEventListener('transitionend', rec.revealEnd, true);
    d.addEventListener('animationend', rec.revealEnd, true);
  }
  function unwatchReveal(rec) {
    if (rec.revealObserver) { rec.revealObserver.disconnect(); rec.revealObserver = null; }
    if (rec.revealEnd) {
      d.removeEventListener('transitionend', rec.revealEnd, true);
      d.removeEventListener('animationend', rec.revealEnd, true);
      rec.revealEnd = null;
    }
  }
  function widthOf(box) {
    var css = w.getComputedStyle(box);
    return Math.max(0, box.clientWidth - (parseFloat(css.paddingLeft) || 0) - (parseFloat(css.paddingRight) || 0));
  }
  function fixedSizes(rec) {
    var raw = Array.isArray(rec.options.sizes) ? rec.options.sizes : [];
    return raw.filter(function (s) { return Array.isArray(s) && s.length === 2 && Number(s[0]) > 0 && Number(s[1]) > 0; })
      .map(function (s) { return [Math.round(Number(s[0])), Math.round(Number(s[1]))]; })
      .sort(function (a, b) { return b[0] - a[0]; });
  }
  function fittingSize(rec, width) {
    var sizes = fixedSizes(rec);
    for (var i = 0; i < sizes.length; i++) if (sizes[i][0] <= width + 0.5) return sizes[i];
    return null;
  }
  /**
   * Sticky is a property of the publisher wrapper, never of the creative.
   * Permit it only when the whole wrapper and provider INS fit in the useful
   * viewport without intersecting a recognized account anchor. An oversized response falls back to normal
   * flow and stays there for this viewport geometry, even if later reflows
   * shrink it again. Resize can reconsider; no creative node is reparented,
   * resized or requested again by this function.
   */
  function syncStickyFit(rec) {
    if (!rec.stickyCandidate || rec.closed || !rec.box.isConnected) return;
    var rect = rec.box.getBoundingClientRect(), creative = rec.ins && rec.ins.getBoundingClientRect();
    var css = w.getComputedStyle(rec.box), offset = parseFloat(css.top);
    if (!isFinite(offset)) offset = parseFloat(css.insetBlockStart);
    var available = usableViewportHeight(), width = Math.max(rect.width || 0, creative ? creative.width || 0 : 0);
    var height = Math.max(rect.height || 0, creative ? (creative.height || 0) + bandOf(rec) : 0);
    var viewportKey = viewportWidth() + ':' + available + ':' + (isFinite(offset) ? offset : 'unknown');
    if (rec.stickyViewport !== viewportKey) { rec.stickyViewport = viewportKey; rec.stickyRejectedViewport = ''; }
    var reason = '';
    if (!viewportHasArea()) reason = 'viewport-unavailable';
    else if (viewportWidth() < RULES.desktopMinWidth) reason = 'not-desktop';
    else if (rec.gameNavigation && rec.gameNavigation.isConnected) reason = 'game-navigation-flow';
    else if (!isFinite(offset) || offset < 0) reason = 'unknown-offset';
    else if (width <= 0 || height <= 0) reason = 'waiting-layout';
    else if (width > 300) reason = 'width-exceeds-300';
    else if (rect.left < 0 || rect.right > viewportWidth() || (creative && (creative.left < 0 || creative.right > viewportWidth()))) reason = 'outside-horizontal-viewport';
    else if (accountAnchorRects().some(function (anchor) {
      /* Project the wrapper at its sticky offset. Top and side anchors do not
       * change the body's density model, but must not be overlapped here. */
      return anchor.left < rect.right && anchor.right > rect.left && anchor.top < offset + height && anchor.bottom > offset;
    })) reason = 'account-anchor-overlap';
    else if (height + offset > available) reason = 'height-exceeds-viewport';
    else if (rec.stickyRejectedViewport === viewportKey) reason = 'same-viewport-latch';
    if (reason === 'width-exceeds-300' || reason === 'outside-horizontal-viewport' || reason === 'height-exceeds-viewport') rec.stickyRejectedViewport = viewportKey;
    rec.stickyFit = !reason; rec.stickyReason = reason || 'fits';
    rec.stickyGeometry = { width: Math.round(width), height: Math.round(height), offset: isFinite(offset) ? offset : null, availableHeight: Math.round(available) };
    if (rec.stickyFit) {
      if (rec.box.getAttribute('data-go-ad-sticky-fit') !== '1') rec.box.setAttribute('data-go-ad-sticky-fit', '1');
    } else if (rec.box.hasAttribute('data-go-ad-sticky-fit')) rec.box.removeAttribute('data-go-ad-sticky-fit');
  }
  function onScroll() {
    if (!paintGate.released) releasePaintGate('scroll');
    sampleMotion();
    engine.maxScrollDepth = Math.max(engine.maxScrollDepth || 0, currentScrollDepth());
    checkScrollEngagement();
    schedule();
    if (settleTimer) w.clearTimeout(settleTimer);
    settleTimer = w.setTimeout(function () {
      settleTimer = 0;
      motion.velocity = 0;
      motion.direction = 0;
      motion.paceVh = 0;
      /* Keep the last real sample's timestamp and position. Advancing the clock
       * without a scroll sample makes the next wheel tick divide its movement by
       * only the time since this callback, inflating predictive lookahead. */
      schedule();
    }, 170);
  }
  function resetMotion() {
    motion.velocity = 0;
    motion.direction = 0;
    motion.paceVh = 0;
    motion.trail = [];
    motion.y = scrollY();
    motion.t = now();
  }
  /* Reflow/scroll anchoring during a resize is not a reader fling. Sampling it
   * as motion had no scroll-settle timer, leaving exposure gated indefinitely
   * and repeatedly waking pacing. The next real scroll starts a fresh sample. */
  function onResize() { resetMotion(); pending.forEach(watchProximity); schedule(); }
  function watchMedia(rec) {
    if (!rec.media) return;
    var change = function () { watchProximity(rec); updateListeners(); schedule(); };
    if (typeof rec.media.addEventListener === 'function') rec.media.addEventListener('change', change);
    else if (typeof rec.media.addListener === 'function') rec.media.addListener(change);
    else return;
    rec.mediaChange = change;
  }
  function unwatchMedia(rec) {
    if (!rec.mediaChange) return;
    if (typeof rec.media.removeEventListener === 'function') rec.media.removeEventListener('change', rec.mediaChange);
    else if (typeof rec.media.removeListener === 'function') rec.media.removeListener(rec.mediaChange);
    rec.mediaChange = null;
  }
  function updateListeners() {
    var need = adjustments.size > 0;
    pending.forEach(function (rec) { if (!rec.media || rec.media.matches || !rec.mediaChange) need = true; });
    if (need && !listening) {
      w.addEventListener('scroll', onScroll, { passive: true });
      listening = true;
    } else if (!need && listening) {
      w.removeEventListener('scroll', onScroll);
      listening = false;
    }
    /* Served sticky wrappers must still respond to a smaller window after the
     * pending queue drains. This keeps only resize, not an idle scroll loop. */
    var hasSticky = records.some(function (rec) { return rec.stickyCandidate && !rec.closed && rec.box.isConnected; });
    var hasExposure = records.some(function (rec) { return rec.viewObserved && !rec.closed && rec.box.isConnected; });
    if (need || hasSticky || hasExposure) ensureAnchorWatch(); else stopAnchorWatch();
    var needResize = need || hasSticky;
    if (needResize && !resizeListening) { w.addEventListener('resize', onResize, { passive: true }); resizeListening = true; }
    else if (!needResize && resizeListening) { w.removeEventListener('resize', onResize); resizeListening = false; }
  }
  function watch(node, rec) {
    if (!node || typeof w.ResizeObserver !== 'function') return;
    if (!ro) ro = new w.ResizeObserver(function (entries) {
      entries.forEach(function (entry) {
        var item = measured.get(entry.target);
        if (!item || item.closed) return;
        if (entry.target === item.ins && /^(filled|unfill-optimized)$/.test(item.providerStatus)) adjustments.add(item);
        syncStickyFit(item);
      });
      schedule();
    });
    measured.set(node, rec);
    ro.observe(node);
  }

  /**
   * One timer for every in-flight request, not one per record.
   *
   * It exists only so a silent provider response releases its opportunity at
   * `stuck_release_ms` even if the reader never scrolls again.
   */
  function armStuckSweep() {
    if (stuckTimer) return;
    stuckTimer = w.setTimeout(function () {
      stuckTimer = 0;
      var live = false, released = 0;
      records.forEach(function (r) {
        if (!r.requested || r.closed || r.error || r.providerStatus) return;
        if ((now() - r.requestedMs) >= RULES.stuck_release_ms) {
          if (!r.stuckReleased) { r.stuckReleased = true; released++; state(r, 'provider-no-response'); releaseCritical(r); }
        } else { live = true; }
      });
      if (released) { engine.releasedStuck += released; schedule(); }
      if (live) armStuckSweep();
    }, 1000);
  }

  /* ------------------------------------------------------ creative origin warm-up */

  /**
   * Open the creative host's connection when the first request goes out.
   *
   * The chain is: adsbygoogle.js from pagead2, the ad request itself to
   * googleads.g.doubleclick.net, then the creative from tpc.googlesyndication.com.
   * inc/ads/assets.php preconnects the first two and deliberately leaves the
   * third at dns-prefetch, because a third speculative handshake in <head>
   * competes with the LCP resource for sockets and CPU on a phone.
   *
   * That argument only holds while nothing needs the connection. By the time a
   * placement is close enough to request, the LCP resource has long since been
   * fetched, so the handshake is free here and it overlaps the ad request's own
   * round trip instead of queuing behind it. What it buys is earlier creative
   * paint, which is the one lever a publisher has over how much of the one-second
   * measurement window a served creative actually spends on screen.
   *
   * Credentialed, matching the iframe navigation that will use it: browsers keep
   * anonymous and credentialed sockets in separate pools, so warming this origin
   * with crossorigin would open a connection the creative cannot reuse. It is a
   * connection hint — it fetches nothing, requests no ad and creates no
   * impression — and a failure to insert it is never a delivery error.
   */
  var creativeOriginWarmed = false;
  function warmCreativeOrigin() {
    if (creativeOriginWarmed) return;
    creativeOriginWarmed = true;
    try {
      var head = d.head || d.documentElement;
      if (!head || d.querySelector('link[rel="preconnect"][href="https://tpc.googlesyndication.com"]')) return;
      var link = d.createElement('link');
      link.rel = 'preconnect';
      link.href = 'https://tpc.googlesyndication.com';
      head.appendChild(link);
    } catch (e) { /* A blocked or unsupported hint leaves delivery unchanged. */ }
  }

  /* ------------------------------------------------------------ viewability proxy */

  /**
   * The share of a creative that has to be on screen for the local clock to run.
   *
   * Google's display standard is 50% of the creative's own pixels for one
   * continuous second, and 30% for a LARGE creative — 242,500 px² or more, a
   * threshold a 970x250 masthead meets exactly. Measuring everything at 50%
   * therefore understated exposure on precisely the units whose resting lead an
   * operator is most likely to retune from these numbers.
   *
   * This remains a local DOM observation. It models the published measurement
   * shape so the number is not misleading; it is not Active View, an official
   * impression or revenue, and nothing in the delivery path reads it.
   */
  var VIEW_LARGE_AREA = 242500;
  function syncViewableRatio(rec) {
    var box = rec.ins ? rec.ins.getBoundingClientRect() : null;
    var area = box ? Math.max(0, box.width || 0) * Math.max(0, box.height || 0) : 0;
    rec.viewableRatio = area >= VIEW_LARGE_AREA ? 0.3 : 0.5;
    return rec.viewableRatio;
  }
  function viewableRatioFor(rec) { return rec.viewableRatio > 0 ? rec.viewableRatio : 0.5; }

  /**
   * Visible share measured against the viewport the reader can actually use.
   *
   * `entry.intersectionRatio` is computed against the whole viewport, including
   * the strip a displayed account anchor is covering. Delivery was corrected for
   * that in 12.x — `inView()` runs on usableViewportHeight() — but the exposure
   * clock was not, so a creative sitting behind the anchor still accumulated
   * local "viewable" time. The rect comes from the observer entry, so this costs
   * no extra layout.
   */
  function usableVisibleRatio(rec, entry) {
    var r = (entry && entry.boundingClientRect) || (rec.ins ? rec.ins.getBoundingClientRect() : null);
    if (!r) return 0;
    var width = Math.max(0, r.width || 0), height = Math.max(0, r.height || 0);
    if (width < 1 || height < 1) return 0;
    var visibleY = Math.max(0, Math.min(usableViewportHeight(), r.bottom) - Math.max(0, r.top));
    var visibleX = Math.max(0, Math.min(viewportWidth(), r.right) - Math.max(0, r.left));
    return clamp((visibleY * visibleX) / (width * height), 0, 1);
  }

  function viewableTotal(rec) {
    var total = rec.viewable50Ms || 0;
    if (rec.viewStartMs != null && pageVisible()) total += Math.max(0, now() - rec.viewStartMs);
    return Math.round(total);
  }
  function stopViewClock(rec) {
    if (rec.viewTimer) { w.clearTimeout(rec.viewTimer); rec.viewTimer = 0; }
    if (rec.viewStartMs != null) {
      rec.viewable50Ms = (rec.viewable50Ms || 0) + Math.max(0, now() - rec.viewStartMs);
      rec.viewStartMs = null;
    }
  }
  function startViewClock(rec) {
    if (rec.closed || !rec.box.isConnected || !rec.viewObserved ||
        !/^(filled|unfill-optimized)$/.test(rec.providerStatus) || !pageVisible() ||
        rec.currentRatio < viewableRatioFor(rec)) return;
    if (rec.viewStartMs == null) rec.viewStartMs = now();
    if (!rec.localViewable && !rec.viewTimer) {
      rec.viewTimer = w.setTimeout(function () {
        rec.viewTimer = 0;
        if (!rec.closed && rec.box.isConnected && rec.currentRatio >= viewableRatioFor(rec) && pageVisible() && /^(filled|unfill-optimized)$/.test(rec.providerStatus)) {
          rec.localViewable = true;
          rec.localViewableAt = Date.now();
          rec.box.setAttribute('data-go-ad-local-viewable', '1');
        }
      }, 1000);
    }
  }
  function updateViewClock(rec, entry) {
    if (!rec || rec.closed || !rec.viewObserved) return;
    rec.currentRatio = usableVisibleRatio(rec, entry);
    rec.maxIntersectionRatio = Math.max(rec.maxIntersectionRatio || 0, rec.currentRatio);
    if (rec.currentRatio >= viewableRatioFor(rec) && pageVisible()) startViewClock(rec); else stopViewClock(rec);
  }
  /* An anchor that appears, resizes or is dismissed changes the usable viewport
   * without moving the creative, so no observer entry is produced for it. */
  function refreshViewClocks() {
    records.forEach(function (rec) { if (rec.viewObserved) updateViewClock(rec, null); });
  }
  function ensureViewObserver() {
    if (viewObserver || typeof w.IntersectionObserver !== 'function') return;
    viewObserver = new w.IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var rec = viewMeasured.get(entry.target);
        if (!rec || rec.closed) return;
        updateViewClock(rec, entry);
      });
      /* The large-creative threshold is only a wake point for the observer; the
       * clock itself always compares against the usable viewport above. */
    }, { threshold: [0, 0.3, 0.5, 0.75, 1] });
  }
  function observeViewability(rec) {
    if (!rec.ins || rec.viewObserved) return;
    ensureViewObserver();
    if (!viewObserver) return;
    rec.viewObserved = true;
    syncViewableRatio(rec);
    viewMeasured.set(rec.ins, rec);
    viewObserver.observe(rec.ins);
  }
  function handleVisibility() {
    records.forEach(function (rec) {
      if (!pageVisible()) { stopViewClock(rec); closeGateClock(rec); }
      else { if (rec.currentRatio >= viewableRatioFor(rec)) startViewClock(rec); openGateClock(rec); }
    });
    if (!pageVisible()) {
      stopDwell();
      /* visibilitychange and pagehide can both fire. Record the actual first
       * pause, not a later pagehide that would make an idle session look fresh. */
      if (engine.hiddenSinceWall == null) { engine.hiddenSinceWall = Date.now(); persistTopScrollSession(); }
    } else {
      resumeTopScrollSession(engine.refreshTopScrollOnResume);
      engine.refreshTopScrollOnResume = false;
      engine.hiddenSinceWall = null;
      startDwell();
    }
    /* Never create a manual impression while the document is backgrounded. When
     * visibility returns, clear stale motion so a previous fast flick cannot
     * trigger a deep unit immediately. */
    if (pageVisible()) {
      resetMotion();
      schedule();
    }
  }

  /* ------------------------------------------------------------ lifecycle */

  function removePending(rec) {
    pending.delete(rec);
    unwatchMedia(rec);
    unwatchProximity(rec);
    unwatchReveal(rec);
    if (ro) ro.unobserve(rec.box);
    updateListeners();
  }
  function dispose(rec) {
    unwatchMedia(rec);
    unwatchReveal(rec);
    unwatchProximity(rec);
    releaseCritical(rec);
    pending.delete(rec); adjustments.delete(rec);
    stopViewClock(rec);
    closeGateClock(rec);
    if (rec.smartWake) { w.clearTimeout(rec.smartWake); rec.smartWake = 0; }
    if (rec.observer) { rec.observer.disconnect(); rec.observer = null; }
    if (ro) { ro.unobserve(rec.box); if (rec.ins) ro.unobserve(rec.ins); }
    if (viewObserver && rec.ins && rec.viewObserved) { viewObserver.unobserve(rec.ins); rec.viewObserved = false; }
    updateListeners();
  }
  function pruneDetachedRecords() {
    /* Content replacement already emits a scoped update. Reuse that lifecycle
     * and normal sweeps; no document-wide observer or permanent poll is needed.
     * Keep requested IDs claimed, but do not retain their removed DOM trees. */
    for (var i = records.length - 1; i >= 0; i--) {
      var rec = records[i];
      if (rec.box.isConnected) continue;
      rec.closed = true;
      records.splice(i, 1);
      dispose(rec);
      dynamicStats.detached++;
    }
  }
  function reserve(rec, px) {
    px = Math.max(0, Math.ceil(px));
    if (rec.reserved === px) return;
    rec.reserved = px;
    rec.box.style.setProperty('--go-ad-resolved-reserve', px + 'px');
  }
  function bandOf(rec) {
    if (rec.placement !== 'topscroll') return LABEL_BAND;
    var css = w.getComputedStyle(rec.box);
    var band = (parseFloat(css.paddingTop) || 0) + (parseFloat(css.paddingBottom) || 0);
    return band > 0 ? Math.ceil(band) : LABEL_BAND;
  }
  function fitFilled(rec) {
    if (!rec.ins || rec.closed || rec.box.hidden) { adjustments.delete(rec); return; }
    var height = Math.max(rec.ins.offsetHeight || 0, rec.ins.getBoundingClientRect().height || 0);
    if (!height) { adjustments.delete(rec); return; }
    /* Learn the height this slot is actually served, so the next pageview
     * reserves it instead of shifting when it arrives. Filled only: an
     * optimized-empty unit has no creative height to learn from. */
    if (rec.providerStatus === 'filled' && !rec.options.fixed) rememberHeight(rec, height);
    var target = Math.ceil(height) + bandOf(rec);
    var current = rec.reserved == null ? (parseFloat(w.getComputedStyle(rec.box).minHeight) || 0) : rec.reserved;
    if (rec.placement === 'topscroll') {
      /* High-water reservation: never pull the page upwards after the auction. */
      reserve(rec, Math.max(rec.initialReserve, current, target));
      adjustments.delete(rec);
    } else if (target >= current || belowViewport(rec)) {
      reserve(rec, target);
      adjustments.delete(rec);
    } else {
      /* A smaller creative is not an empty ad: keep the visible reservation. */
      adjustments.add(rec);
    }
    /* A responsive creative can cross the large-creative area on resize. */
    if (rec.viewObserved) { syncViewableRatio(rec); updateViewClock(rec, null); }
    syncStickyFit(rec);
    updateListeners();
  }
  function collapseEmpty(rec) {
    if (rec.closed || !rec.box.isConnected) { dispose(rec); return; }
    /* Only Google's literal `unfilled` may collapse. `unfill-optimized` means
     * no ad was returned and AdSense optimized the empty unit; it can contain
     * Google's own suggestions. Preserve provider control of that footprint. */
    var provider = rec.ins ? (rec.ins.getAttribute('data-ad-status') || '') : '';
    if (provider !== 'unfilled') { adjustments.delete(rec); updateListeners(); return; }
    if (!rec.box.classList.contains('go-ad-slot--collapse-unfilled')) {
      state(rec, 'unfilled-reserved');
      adjustments.delete(rec); updateListeners(); return;
    }
    if (belowViewport(rec) || (rec.placement === 'topscroll' && aboveViewport(rec))) {
      rec.box.setAttribute('data-go-ad-empty', '1');
      state(rec, 'unfilled-collapsed');
      adjustments.delete(rec);
    } else {
      state(rec, 'unfilled-awaiting-safe-collapse');
      adjustments.add(rec);
    }
    updateListeners();
  }
  function status(rec) {
    if (!rec.ins || rec.closed) return;
    var value = rec.ins.getAttribute('data-ad-status') || '';
    rec.providerStatus = value;
    rec.providerInitStatus = rec.ins.getAttribute('data-adsbygoogle-status') || '';
    if ((value || rec.providerInitStatus === 'done') && rec.providerAcceptedMs == null) {
      rec.providerAcceptedMs = Math.max(0, now() - rec.requestedMs);
    }
    if (value && rec.responseMs == null) {
      rec.responseMs = Math.max(0, now() - rec.requestedMs);
      var foregroundResponse = pageVisible() && rec.requestDwellMs != null && Math.abs(rec.responseMs - (dwellMs() - rec.requestDwellMs)) <= 250;
      learnResponse(rec.responseMs, value, foregroundResponse);
      if (value === 'filled') rec.fillLatencyLearned = foregroundResponse;
    }
    if (value === 'filled' && !rec.fillLatencyLearned) {
      var filledMs = Math.max(0, now() - rec.requestedMs);
      if (filledMs > 0 && pageVisible() && rec.requestDwellMs != null && Math.abs(filledMs - (dwellMs() - rec.requestDwellMs)) <= 250) {
        learnFilledResponse(filledMs); rec.fillLatencyLearned = true;
      }
    }
    /* An empty unit releases the opportunity it was holding, so a later safe
     * position can take it. The empty slot itself is never asked again. */
    if (value) { releaseCritical(rec); schedule(); }
    if (value !== 'unfilled') rec.box.removeAttribute('data-go-ad-empty');
    if (value === 'filled' || value === 'unfill-optimized') {
      rec.box.setAttribute('data-go-ad-present', '1');
      if (value === 'filled') {
        rec.box.setAttribute('data-go-ad-filled', '1');
        state(rec, 'filled');
        if (!rec.filled) { rec.filled = true; rec.filledAt = Date.now(); persistFill(rec); }
      } else {
        rec.box.removeAttribute('data-go-ad-filled');
        state(rec, 'optimized');
      }
      fitFilled(rec);
      watch(rec.ins, rec);
      observeViewability(rec);
      startViewClock(rec);
    } else {
      stopViewClock(rec);
      rec.box.removeAttribute('data-go-ad-filled');
      rec.box.removeAttribute('data-go-ad-present');
      if (value === 'unfilled') collapseEmpty(rec);
      else if (value || !rec.error) state(rec, value ? 'provider-other-status' : 'requested');
    }
  }

  /**
   * The gate ladder. Order matters: the cheapest and most decisive checks run
   * first, and every rejection names itself in `data-go-ad-state`.
   */
  function activate(rec) {
    if (rec.requested || rec.closed || !rec.box.isConnected) { removePending(rec); return; }
    if (rec.media && !rec.media.matches) { state(rec, 'ineligible-viewport'); return; }
    if (!pageVisible()) { state(rec, 'waiting-page-visible'); return; }
    if (!viewportHasArea()) { state(rec, 'waiting-viewport-geometry'); return; }
    if (!allowed(rec)) { state(rec, 'waiting-consent'); return; }
    if (!inRange(rec)) { state(rec, engine.engaged ? 'waiting-proximity' : 'waiting-engagement'); return; }
    if (criticalHold(rec)) { state(rec, 'waiting-critical-first'); return; }
    if (criticalStage(rec)) { state(rec, 'waiting-critical-stage'); return; }
    if (paintHold(rec)) { state(rec, 'waiting-first-paint'); return; }
    if (!budgetAllows(rec)) { state(rec, 'waiting-opportunity-budget'); return; }
    if (!exposureAllows(rec)) { state(rec, 'waiting-exposure'); return; }
    if (!densityAllows(rec)) { state(rec, 'waiting-content-density'); return; }
    if (!pacingAllows(rec)) { state(rec, 'waiting-pacing'); return; }
    if (!rec.box.getClientRects().length || !visibleHost(rec)) { state(rec, 'waiting-visible-host'); watchReveal(rec); return; }
    unwatchReveal(rec);
    var width = widthOf(rec.box);
    rec.availableWidth = width;
    if (width < 1) { state(rec, 'waiting-width'); return; }
    var size = null;
    if (rec.options.fixed) {
      if (!fixedSizes(rec).length) { state(rec, 'invalid-fixed-size-config'); removePending(rec); return; }
      size = fittingSize(rec, width);
      if (!size) { state(rec, 'no-fitting-size'); return; }
    }
    /* persistFill() records a fill for ANY placement that declares a cap, so
     * the cap has to be read back for any placement that declares one too.
     * Reading it for Top Scroll alone meant a cap configured on a second unit
     * silently accumulated history that nothing ever enforced. The smart
     * session ladder below stays Top Scroll's own and returns true elsewhere. */
    var fillHistory = rec.options.frequencyMax ? history(rec) : [];
    if (rec.options.frequencyMax && fillHistory.length >= rec.options.frequencyMax) {
      rec.box.hidden = true; state(rec, 'frequency-capped'); removePending(rec); return;
    }
    if (!topScrollSmartAllows(rec, fillHistory.length)) {
      state(rec, 'waiting-session-engagement'); return;
    }
    if (slotOwners[rec.slot]) {
      rec.box.hidden = true; state(rec, 'alternative-already-requested'); removePending(rec); return;
    }
    var node = rec.template.content.firstElementChild;
    if (!node || node.tagName !== 'INS' || !rec.slot || node.hasAttribute('data-ad-status') || node.hasAttribute('data-adsbygoogle-status')) {
      state(rec, 'invalid-markup'); removePending(rec); return;
    }
    rec.initialReserve = parseFloat(w.getComputedStyle(rec.box).minHeight) || 0;
    if (size) {
      node.style.width = size[0] + 'px';
      node.style.height = size[1] + 'px';
      reserve(rec, size[1] + bandOf(rec));
    } else {
      node.style.width = '100%'; node.style.minWidth = '1px';
    }
    rec.template.replaceWith(node);
    rec.ins = node;
    var box = node.getBoundingClientRect();
    if (box.width < 1 || (size && box.height < 1) || !visibleHost(rec, node)) {
      node.replaceWith(rec.template); rec.template.content.appendChild(node);
      /* The unit can have its own CSS gate while its host keeps the same size.
       * No provider call happened yet. Restore the original inert node and wake
       * on publisher class/style changes even without scroll or resize. */
      rec.ins = null; state(rec, 'waiting-geometry'); watchReveal(rec); return;
    }
    slotOwners[rec.slot] = true;
    /*
     * Reserve the footprint the creative is about to need, while the host is
     * still off screen.
     *
     * The in-body ladder declares no server-side reserve on purpose: an empty
     * unit must not leave a hole in the article. The cost was that the host
     * stayed at zero height for the whole round trip, so the creative's arrival
     * was itself the layout change. That is invisible while the slot is below
     * the fold and a visible jump the moment the reader catches up with it —
     * which is exactly what a fast scroll on a slow connection produces.
     *
     * So the space is claimed at REQUEST time and only while the host is fully
     * below the useful viewport, where growing it shifts nothing the reader can
     * see. fitFilled() then replaces the estimate with the creative's real
     * height, and collapseEmpty() removes it entirely on a literal `unfilled`.
     * Nothing here is reserved before a request, so an unrequested position
     * still occupies no space at all.
     *
     * Only a host that is allowed to collapse takes this reservation. A unit
     * configured with neither a server reserve nor `collapse_unfilled` has no
     * way to give the space back, so claiming it there would turn an empty
     * response into a permanent hole in the article — which is exactly what the
     * zero-reserve ladder exists to avoid. No shipped unit is in that position;
     * the guard is here so that adding one cannot create the trap.
     */
    if (reserveOnRequest && !size && rec.initialReserve < 1 && (rec.reserved == null || rec.reserved < 1) &&
        box.top >= usableViewportHeight() && rec.box.classList.contains('go-ad-slot--collapse-unfilled')) {
      reserve(rec, Math.round(nominalHeight(rec)) + bandOf(rec));
      rec.predictedReserve = rec.reserved;
    }
    rec.requested = true; rec.requestedMs = now(); rec.requestDwellMs = dwellMs();
    rec.heldMs = rec.holdStartMs == null ? 0 : Math.max(0, rec.requestedMs - rec.holdStartMs);
    rec.stagedMs = rec.stageStartMs == null ? 0 : Math.max(0, rec.requestedMs - rec.stageStartMs);
    rec.engagedAtRequest = engine.engaged;
    rec.governorAtRequest = engine.governor;
    rec.valueAtRequest = Math.round(expectedValue(rec) * 1000) / 1000;
    rec.reachAtRequest = Math.round(reachProbability(rec) * 1000) / 1000;
    rec.regimeAtRequest = decision().regime;
    if (!rec.critical) engine.lastNonCriticalRequestAt = rec.requestedMs;
    if (rec.critical) {
      engine.criticalInFlight.add(rec);
      engine.criticalHoldUntil = Math.max(engine.criticalHoldUntil, rec.requestedMs + RULES.critical_hold_ms);
    }
    rec.box.setAttribute('data-go-ad-requested', '1');
    var requestRange = rangeFor(rec);
    rec.distanceAtRequest = Math.round(requestRange.distance || 0);
    rec.dynamicNearAtRequest = Math.round(requestRange.near || 0);
    rec.estimatedArrivalAtRequest = requestRange.arrival == null ? null : Math.round(requestRange.arrival);
    rec.scrollVelocityAtRequest = Math.round(motion.velocity);
    rec.paceVhAtRequest = Math.round(motion.paceVh * 100) / 100;
    rec.responseEstimateAtRequest = Math.round(responseEstimateFor(rec));
    rec.requestScrollY = Math.round(scrollY());
    rec.requestSize = { width: Math.round(box.width), height: Math.round(box.height) };
    state(rec, 'requested');
    removePending(rec);
    if (typeof w.MutationObserver === 'function') {
      rec.observer = new w.MutationObserver(function () { status(rec); });
      rec.observer.observe(node, { attributes: true, attributeFilter: ['data-ad-status', 'data-adsbygoogle-status'] });
    }
    armStuckSweep();
    warmCreativeOrigin();
    try {
      (w.adsbygoogle = w.adsbygoogle || []).push({});
      status(rec);
    } catch (e) {
      /* No timeout-as-unfilled, no guessed retry, no refresh. */
      rec.error = String(e && e.message || e); state(rec, 'request-error');
      releaseCritical(rec);
    }
    /* The publisher host/reservation just changed normal flow. Other records
     * ranked in this sweep still hold pre-insertion DOMRect snapshots; a new
     * coalesced frame must reconcile them even if Google answers much later.
     * No new frame is scheduled by a rejected candidate, so this is not polling. */
    if (pending.size) schedule();
    return true;
  }

  function sweep() {
    frame = 0;
    frameId++;
    pruneDetachedRecords();
    if (refreshDeviceRules()) pending.forEach(watchProximity);
    /* Also covers scroll restoration, in-page anchors and back/forward cache. */
    checkScrollEngagement();
    /* The governor is re-evaluated exactly once per sweep. Every path that can
     * change a placement's eligibility — scroll, resize, visibility, a reveal,
     * a provider answer or a consent update — reaches the queue
     * through schedule(), so one call here covers all of them without spreading
     * the decision across six call sites. */
    evaluateGovernor();
    /* An account anchor that appears, resizes or is dismissed changes the usable
     * viewport without moving any creative, so the exposure observer produces no
     * entry for it. Desktop learns this through the anchor watch, but that watch
     * only runs where a sticky rail exists — never on a phone, which is where the
     * bottom anchor actually appears. Compare the reserve once per sweep and
     * re-measure the clocks only when it really moved; sweeps stop altogether
     * once nothing is pending, so this cannot become a polling loop. */
    var sweepReserve = overlayReserve();
    if (sweepReserve !== engine.clockReserve) { engine.clockReserve = sweepReserve; refreshViewClocks(); }
    /* Rank simultaneously eligible candidates by expected value rather than DOM
     * order. Priorities are computed once per sweep so the sort cannot trigger
     * repeated reflows. */
    var queue = Array.from(pending).map(function (rec) { return { rec: rec, score: requestPriority(rec) }; });
    queue.sort(function (a, b) { return b.score - a.score; });
    /* A successful request changes the publisher's flow (reservation/margins).
     * Remaining ranked candidates hold pre-change rect/range caches. Continue
     * in the frame already scheduled by activate(), after layout has settled,
     * instead of spending a request against stale geometry or forcing repeated
     * synchronous reflows in this frame. Rejected candidates add no frame. */
    for (var i = 0; i < queue.length; i++) {
      if (activate(queue[i].rec)) break;
    }
    adjustments.forEach(function (rec) {
      if (!rec.box.isConnected || rec.closed || rec.box.hidden) { dispose(rec); return; }
      if (rec.providerStatus === 'unfilled') collapseEmpty(rec);
      else if (/^(filled|unfill-optimized)$/.test(rec.providerStatus)) fitFilled(rec);
      else adjustments.delete(rec);
    });
    records.forEach(syncStickyFit);
    updateListeners();
  }
  function schedule() { if (!frame) frame = w.requestAnimationFrame(sweep); }

  function mount(box, options) {
    if (!box || mounted.has(box) || !box.hasAttribute('data-go-ad-placement')) return;
    if (refreshDeviceRules()) pending.forEach(watchProximity);
    var template = null;
    for (var i = 0; i < box.children.length; i++) {
      if (box.children[i].tagName === 'TEMPLATE' && box.children[i].hasAttribute('data-go-ad-pending')) template = box.children[i];
    }
    if (!template) return;
    mounted.add(box);
    var unit = template.content.firstElementChild;
    var attr = function (name) { return parseInt(box.getAttribute(name) || '', 10) || null; };
    var rec = {
      box: box, template: template, options: options || {}, placement: box.getAttribute('data-go-ad-placement'),
      slot: unit && unit.getAttribute('data-ad-slot'), state: '', requested: false, initialReserve: 0, reserved: null,
      filled: false, persisted: false, observer: null, providerStatus: '', timeline: [], closed: false, smartWake: 0,
      gateStats: Object.create(null), gateStartMs: null, densityReason: '', densityChecks: Object.create(null),
      mountedMs: now(), availableWidth: null, currentRatio: 0, maxIntersectionRatio: 0, viewable50Ms: 0, viewableRatio: 0,
      viewStartMs: null, viewTimer: 0, localViewable: false, viewObserved: false, stuckReleased: false,
      critical: !!(options && options.priority === 'critical'), holdStartMs: null, heldMs: 0, paintHeldMs: null, engagedAtRequest: null,
      rectCache: null, rectFrame: -1, nominalCache: 0, nominalFrame: -1, rangeFrame: -1,
      firstNearbyMs: null, firstOpportunityVisibleMs: null, budgetPath: '', reachedReserveQualified: false,
      stickyCandidate: box.classList.contains('go-article-sidebar__ad--sticky'), stickyFit: false, stickyReason: 'not-applicable',
      stickyViewport: '', stickyRejectedViewport: '', stickyGeometry: null, gameNavigation: null,
      tier: box.getAttribute('data-go-ad-tier') || (options && options.tier) || '',
      surface: box.getAttribute('data-go-ad-surface') || '',
      plannerScore: parseFloat(box.getAttribute('data-go-ad-planner-score') || '') || null,
      plannerDepth: attr('data-go-ad-depth'),
      articleWords: attr('data-go-ad-body-words') || attr('data-go-ad-article-words'),
      articleProfile: box.getAttribute('data-go-ad-profile') || '',
      articleType: box.getAttribute('data-go-ad-article-type') || '',
      plannedBodyCount: attr('data-go-ad-planned-count'),
      renderedBodyCount: attr('data-go-ad-rendered-count'),
      fallbackReserve: box.getAttribute('data-go-ad-fallback-reserve') === '1',
      eligibleCandidates: attr('data-go-ad-eligible-candidates'),
      structuralBodyCapacity: attr('data-go-ad-body-capacity'),
      listingIndex: attr('data-go-ad-listing-index')
    };
    /* Game navigation and the sidebar share the same desktop rail projection:
     * the nav starts at the header and is taller than the ad's 12px offset.
     * Preserve the ad in normal flow when that nav exists, without moving the
     * navigation or adding another dynamic offset system. Resolve once against
     * this game root, never by a document-wide query during scroll. */
    if (rec.stickyCandidate && box.classList.contains('go-game-sidebar-revenue')) {
      for (var gameRoot = box.parentElement; gameRoot && gameRoot.nodeType === 1; gameRoot = gameRoot.parentElement) {
        if (gameRoot.classList.contains('od-games')) { rec.gameNavigation = gameRoot.querySelector('.od-game-nav'); break; }
      }
    }
    if (rec.articleWords) engine.articleWords = Math.max(engine.articleWords || 0, rec.articleWords);
    if (box.hasAttribute('data-go-ad-planned-count') || box.hasAttribute('data-go-ad-body-capacity')) engine.plannerTelemetry = true;
    if (engine.plannerTelemetry) {
      engine.plannedBodyCount = Math.max(engine.plannedBodyCount || 0, Math.max(0, rec.plannedBodyCount || 0));
      engine.renderedBodyCount = Math.max(engine.renderedBodyCount || 0, Math.max(0, rec.renderedBodyCount || 0));
      if (rec.fallbackReserve) engine.reserveBodyCount = Math.max(engine.reserveBodyCount || 0, 1);
      engine.eligibleCandidates = Math.max(engine.eligibleCandidates || 0, Math.max(0, rec.eligibleCandidates || 0));
      engine.structuralBodyCapacity = Math.max(engine.structuralBodyCapacity || 0, Math.max(0, rec.structuralBodyCapacity || 0));
      if (rec.articleType) engine.articleType = engine.articleType || rec.articleType;
    }
    /* Slot-scoped, so it is already correct for any placement that declares a
     * frequency cap. The legacy `topscroll` in the name stays: renaming it
     * would orphan the counters real readers are carrying and hand every one of
     * them a fresh 24h allowance on the day of the update. */
    rec.key = 'go_adsense_topscroll_24h_' + rec.slot;
    rec.media = rec.options.media && w.matchMedia ? w.matchMedia(rec.options.media) : null;
    records.push(rec); pending.add(rec);
    applyRememberedReserve(rec);
    state(rec, 'pending'); syncStickyFit(rec); watchMedia(rec); watch(box, rec); watchProximity(rec); updateListeners(); activate(rec);
  }

  /* ------------------------------------------------------------ dynamic editorial content */

  function pendingUnit(box) {
    for (var i = 0; box && i < box.children.length; i++) {
      var child = box.children[i];
      if (child.tagName === 'TEMPLATE' && child.hasAttribute('data-go-ad-pending')) return child.content && child.content.firstElementChild;
    }
    return null;
  }
  function parseMountOptions(box) {
    try {
      var raw = box.getAttribute('data-go-ad-options');
      if (!raw || raw.length > 12000) return null;
      var value = JSON.parse(raw);
      return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
    } catch (e) { return null; }
  }
  function removeNode(node) {
    if (node && typeof node.remove === 'function') node.remove();
    else if (node && node.parentNode) node.parentNode.removeChild(node);
  }
  function removeMountScripts(box) {
    if (box && typeof box.querySelectorAll === 'function') Array.prototype.forEach.call(box.querySelectorAll('script'), removeNode);
  }
  function mountDeclarative(box) {
    if (!box || mounted.has(box)) return false;
    var options = parseMountOptions(box), unit = pendingUnit(box);
    if (!options || !unit || unit.tagName !== 'INS' || !unit.getAttribute('data-ad-slot') ||
        unit.hasAttribute('data-ad-status') || unit.hasAttribute('data-adsbygoogle-status')) { dynamicStats.rejectedMarkup++; return false; }
    /* Scripts in fetched HTML are not a mount API. Only publisher JSON is
     * consumed; even an unexpected script inside this ad host is never run. */
    removeMountScripts(box);
    var before = records.length;
    mount(box, options);
    if (records.length > before) { dynamicStats.mounted++; return true; }
    return false;
  }
  function materializeListingReserves() {
    if (!listingBinding.initialized) {
      if (d.readyState === 'loading') return 0;
      listingBinding.initialized = true;
      listingBinding.reserves = Array.prototype.slice.call(d.querySelectorAll('template[data-go-listing-reserve]'));
    }
    /* A user-selected editorial filter replaces the root. Rebind the original
     * document's remaining reserve templates to its sole current feed; never
     * import a second pool or recycle IDs that have already been requested. */
    if (!listingBinding.root || !listingBinding.root.isConnected) {
      var roots = d.querySelectorAll('[data-go-ad-listing-root="1"]');
      listingBinding.root = roots.length === 1 ? roots[0] : null;
    }
    var root = listingBinding.root;
    if (!root || !root.isConnected) return 0;
    var selector = root.getAttribute('data-go-ad-listing-card-selector'), cards = [];
    if (!selector || selector.length > 160) return 0;
    try {
      cards = Array.prototype.filter.call(root.children || [], function (node) {
        return typeof node.matches === 'function' && node.matches(selector);
      });
    } catch (e) { return 0; }
    var made = 0;
    listingBinding.reserves.slice().forEach(function (template) {
      if (template.isConnected === false) { listingBinding.reserves = listingBinding.reserves.filter(function (candidate) { return candidate !== template; }); return; }
      var after = parseInt(template.getAttribute('data-go-listing-after') || '', 10);
      if (!isFinite(after) || after < 1 || cards.length < after) return;
      listingBinding.reserves = listingBinding.reserves.filter(function (candidate) { return candidate !== template; });
      var box = template.content && template.content.firstElementChild, unit = pendingUnit(box);
      if (!box || !box.hasAttribute('data-go-ad-placement') || !parseMountOptions(box) || !unit || unit.hasAttribute('data-ad-status') || unit.hasAttribute('data-adsbygoogle-status')) { dynamicStats.rejectedMarkup++; removeNode(template); return; }
      var slot = unit.getAttribute('data-ad-slot');
      if (!slot || slotOwners[slot] || records.some(function (record) { return record.slot === slot; })) {
        dynamicStats.skippedDuplicate++; removeNode(template); return;
      }
      /* The initial document owns this remaining slot ID. Append only when the
       * real card count reaches its declared boundary, once, without recycling
       * F1-F3 or asking the AJAX response to invent a new cursor. */
      /* Strip while the template is still inert: moving a script-containing
       * template subtree into the live document can execute those scripts. */
      removeMountScripts(box);
      root.insertBefore(box, cards[after - 1].nextSibling || null);
      removeNode(template);
      if (mountDeclarative(box)) { made++; dynamicStats.materialized++; }
    });
    return made;
  }
  function scan(root) {
    root = root && typeof root.querySelectorAll === 'function' ? root : d;
    dynamicStats.scans++;
    pruneDetachedRecords();
    var made = materializeListingReserves();
    if (root.hasAttribute && root.hasAttribute('data-go-ad-options') && mountDeclarative(root)) made++;
    Array.prototype.forEach.call(root.querySelectorAll('[data-go-ad-placement][data-go-ad-options]'), function (box) {
      if (mountDeclarative(box)) made++;
    });
    if (made) schedule();
    return made;
  }
  function contentUpdated(event) {
    var detail = event && event.detail || {};
    scan(detail.root || detail.scope || d);
  }

  /*
   * @lean:strip-start
   *
   * Everything from here to @lean:strip-end is the OPERATOR surface: inspect(),
   * explain() and the local diagnostic snapshot. It is roughly a sixth of the
   * runtime, it is inlined into every HTML document, and an anonymous reader
   * can never call any of it.
   *
   * tests/build-runtime-min.js therefore emits two files. The full one keeps
   * this block and is served to a logged-in administrator; the lean one
   * replaces it with the stubs in @lean:stub below and is what the public gets.
   * Both come from this one source: there is no second copy of any decision.
   *
   * The stub keeps `version`, so the documented install check
   * (`GOAdsRuntime.inspect().version`) still answers on a public page, and
   * says plainly that the detail lives in the administrator's copy.
   */
  function diagnosticSnapshot(reason) {
    if (!gateDiagnostics) return null;
    return { schema: 'go-ads-local-v2', version: VERSION, reason: String(reason || 'inspect'),
      scope: 'Observações locais de oportunidades/hosts medidas na viewport útil; não são receita, impressões oficiais ou Active View. Sem envio automático.',
      device: RULES.device, foregroundMs: Math.round(dwellMs()), reserveAdmission: 'reached',
      latencyMemory: { enabled: DELIVERY.latency_memory === true, permitted: permission(), imported: latencyMemory.imported, currentFilledSamples: presentResponseTimes.length },
      dynamic: { scans: dynamicStats.scans, mounted: dynamicStats.mounted, materialized: dynamicStats.materialized, skippedDuplicate: dynamicStats.skippedDuplicate, rejectedMarkup: dynamicStats.rejectedMarkup },
      positions: records.slice(0, 64).map(function (record) {
        var density = {};
        Object.keys(record.densityChecks).forEach(function (key) { density[key] = record.densityChecks[key]; });
        return { placement: record.placement, slot: record.slot, surface: record.surface, requested: record.requested,
          status: record.providerStatus, state: record.state, firstNearbyMs: record.firstNearbyMs,
          opportunityReached: record.firstOpportunityVisibleMs != null, firstOpportunityVisibleMs: record.firstOpportunityVisibleMs,
          budgetPath: record.budgetPath, reachedReserveReason: record.reachedReserveReason || null,
          requestMs: record.requestedMs == null ? null : record.requestedMs, responseMs: record.responseMs == null ? null : record.responseMs,
          distanceAtRequest: record.distanceAtRequest == null ? null : record.distanceAtRequest,
          localExposureQualified: record.localViewable === true, localExposureMs: viewableTotal(record),
          localExposureRequiredRatio: viewableRatioFor(record),
          sticky: record.stickyCandidate ? { fit: record.stickyFit, reason: record.stickyReason, geometry: record.stickyGeometry } : null,
          densityChecks: density, waits: inspectGateTimings(record) };
      }) };
  }
  function flushDiagnostics(reason) {
    var snapshot = diagnosticSnapshot(reason);
    if (!snapshot) return null;
    diagnosticBuffer.push(snapshot);
    if (diagnosticBuffer.length > 4) diagnosticBuffer.shift();
    try { d.dispatchEvent(new CustomEvent('go:ads-local-diagnostic', { detail: snapshot })); } catch (e) {}
    return snapshot;
  }

  /* ------------------------------------------------------------ diagnostics */

  function inspect() {
    frameId++;
    function rect(node) {
      if (!node) return null;
      var r = node.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height) };
    }
    var counts = { mounted: records.length, eligibleViewport: 0, requested: 0, responded: 0, providerPresent: 0,
      filled: 0, optimized: 0, unfilled: 0, requestErrors: 0, waiting: 0, pendingEligible: 0,
      ineligibleViewport: 0, dismissed: 0, providerAccepted: 0, awaitingProvider: 0,
      releasedStuck: engine.releasedStuck, localViewable: 0, waitReasons: {} };
    records.forEach(function (r) {
      var eligible = !r.media || r.media.matches;
      if (eligible) counts.eligibleViewport++; else counts.ineligibleViewport++;
      if (r.requested) counts.requested++;
      if (r.providerAcceptedMs != null) counts.providerAccepted++;
      if (r.localViewable) counts.localViewable++;
      if (r.requested && !r.providerStatus && !r.error && !r.closed) counts.awaitingProvider++;
      if (r.providerStatus) counts.responded++;
      if (r.providerStatus === 'filled') counts.filled++;
      if (r.providerStatus === 'unfill-optimized') counts.optimized++;
      if (r.providerStatus === 'filled' || r.providerStatus === 'unfill-optimized') counts.providerPresent++;
      if (r.providerStatus === 'unfilled') counts.unfilled++;
      if (r.state === 'request-error') counts.requestErrors++;
      if (/^waiting-/.test(r.state)) {
        counts.waiting++;
        counts.waitReasons[r.state] = (counts.waitReasons[r.state] || 0) + 1;
      }
      if (r.closed || r.state === 'dismissed') counts.dismissed++;
      if (!r.requested && !r.closed && eligible && pending.has(r)) counts.pendingEligible++;
    });
    var bodyFunnel = { mounted: 0, requested: 0, responded: 0, providerPresent: 0, unfilled: 0, waiting: 0, states: {} };
    records.forEach(function (r) {
      if (!isBodyRecord(r)) return;
      bodyFunnel.mounted++;
      if (r.requested) bodyFunnel.requested++;
      if (r.providerStatus) bodyFunnel.responded++;
      if (r.providerStatus === 'filled' || r.providerStatus === 'unfill-optimized') bodyFunnel.providerPresent++;
      if (r.providerStatus === 'unfilled') bodyFunnel.unfilled++;
      if (!r.requested && !r.closed) bodyFunnel.waiting++;
      bodyFunnel.states[String(r.state || 'unknown')] = (bodyFunnel.states[String(r.state || 'unknown')] || 0) + 1;
    });
    var dec = decision();
    return {
      scope: 'Diagnóstico local do DOM. localViewability é exposição do criativo medida na viewport útil (descontando a âncora da conta) por >=1s contínuo, com o limiar publicado do formato: 50% em geral e 30% quando o criativo tem >=242.500 px². Inclui sugestões unfill-optimized sem anúncio; não é Active View oficial, receita, impressão paga ou métrica de campo.',
      version: VERSION, deliveryModel: 'inventário manual + Auto Ads geridos na conta',
      automatic: { recognizedInPage: accountInPageRects().length,
        scope: 'Geometria de unidades reconhecidas; não confirma ativação de formatos, impressões ou receita. Somente novos pedidos manuais não críticos podem aguardar espaço.' },
      trial: trialSignal,
      viewport: { width: w.innerWidth, height: viewportHeight(), usableHeight: usableViewportHeight(), anchorReservePx: overlayReserve(), device: RULES.device },
      diagnostics: { gateTimingsEnabled: gateDiagnostics, sampled: diagnosticSampled, sampleRate: diagnosticRate, bufferedSnapshots: diagnosticBuffer.length,
        scope: 'Contagens por posição nesta página; checks são reavaliações, não oportunidades únicas. Sem envio de dados.' },
      paintGate: { enabled: paintGate.armed, released: paintGate.released, releasedBy: paintGate.releasedBy || null,
        maxHoldMs: paintGate.maxHoldMs, graceMs: paintGate.holdMs, nearViewports: paintGate.nearVh, deferrals: paintGate.deferred,
        heldForMs: paintGate.releasedMs == null ? (paintGate.armed ? Math.max(0, now() - paintGate.startedMs) : 0) : Math.max(0, paintGate.releasedMs - paintGate.startedMs),
        scope: 'Adia apenas posições não críticas fora da viewport até a primeira pintura assentar; nunca cancela uma posição.' },
      evolution: { reserveAdmission: 'reached', creativeOriginWarmed: creativeOriginWarmed,
        latencyMemory: { enabled: DELIVERY.latency_memory === true, permitted: permission(), profile: latencyMemory.profile, importedSamples: latencyMemory.imported, retainedSamples: latencyMemory.samples.length },
        dynamic: dynamicStats },
      responseEstimateMs: Math.round(responseEstimateMs), responsePresentSamples: presentResponseTimes.length, responseAllSamples: responseTimes.length,
      engine: {
        readerEngaged: engine.engaged, engagedBy: engine.engagedBy || null, engagedAtMs: engine.engagedAtMs,
        scrollListenersActive: listening,
        resizeListenersActive: resizeListening,
        dwellMs: Math.round(dwellMs()),
        criticalInFlight: engine.criticalInFlight.size, criticalHoldRemainingMs: Math.max(0, engine.criticalHoldUntil - now()),
        governor: {
          state: engine.governor, reason: engine.governorReason, sinceMs: engine.governorSince,
          spacingScale: governorSpacingScale(), transitions: engine.governorLog.slice(),
          readingMs: Math.round(dwellMs()),
          depth: Math.round(readerDepth() * 1000) / 1000, paceViewportsPerSecond: Math.round(motion.paceVh * 100) / 100,
          engagementScore: Math.round(engagementScore() * 1000) / 1000, readerPrior: Math.round(readerPrior() * 1000) / 1000,
          /* Coarse arrival bucket only. No referrer string, URL, query or
           * identifier is retained, stored or reported by the engine. */
          entryContext: { source: entryContext.source, depthPrior: entryContext.depth,
            weight: entryContext.weight, applied: storedReaderPrior() == null && entryContext.depth != null }
        },
        decision: {
          regime: dec.regime, policyMode: 'manual_fixed', financialControlsApplied: false, supplyBias: 0, pacingScale: 1,
          confidence: dec.confidence, fresh: dec.fresh === true, reasons: (dec.reasons || []).slice(),
          generatedAt: dec.generated_at, modelSamples: dec.model_samples, modelWindow: dec.model_window,
          modelMaxAgeSeconds: dec.model_max_age_seconds, freshnessSource: dec.freshness_source,
          tierLookahead: dec.tier_lookahead, remoteDecisionApplied: false, perPageFetch: false
        },
        article: {
          timezone: YIELD.timezone || 'America/Sao_Paulo', daypart: currentProfileName(), hour: engine.profileHour, weekday: engine.profileWeekday,
          words: articleWords(), type: engine.articleType || null, bodyBudget: bodyBudget(),
          plannerVersion: engine.plannerVersion || '', plannedBodyCount: engine.plannedBodyCount || 0,
          renderedBodyCount: engine.renderedBodyCount || 0, reserveBodyCount: engine.reserveBodyCount || 0,
          eligibleCandidates: engine.eligibleCandidates || 0, structuralBodyCapacity: engine.structuralBodyCapacity || 0,
          plannerLoss: Math.max(0, (engine.structuralBodyCapacity || 0) - (engine.plannedBodyCount || 0)),
          occupiedTotal: countOccupied(function () { return true; }),
          occupiedBody: countOccupied(isBodyRecord),
          occupiedCritical: countOccupied(function (r) { return r.critical; }),
          auctionSignal: auctionSignal(), readerModel: getReaderModel(), maxScrollDepth: Math.round((engine.maxScrollDepth || 0) * 1000) / 1000
        },
        rules: RULES
      },
      counts: { manual: counts, bodyFunnel: bodyFunnel },
      manual: records.map(function (r) {
        return { placement: r.placement, slot: r.slot, tier: r.tier, priority: r.critical ? 'critical' : 'normal', surface: r.surface,
          state: r.state, status: r.providerStatus,
          economics: { slotValue: Math.round(slotValue(r) * 1000) / 1000, coverage: Math.round(slotCoverage(r) * 1000) / 1000,
            historicViewability: slotViewability(r), viewabilityLeadScale: Math.round(viewabilityLeadScale(r) * 1000) / 1000, exposureReason: r.exposureReason || null,
            reachProbability: Math.round(reachProbability(r) * 1000) / 1000,
            expectedValue: Math.round(expectedValue(r) * 1000) / 1000,
            valueAtRequest: r.valueAtRequest == null ? null : r.valueAtRequest,
            regimeAtRequest: r.regimeAtRequest || null },
          planner: { score: r.plannerScore, depthPercent: r.plannerDepth, articleWords: r.articleWords, profile: r.articleProfile, articleType: r.articleType, listingIndex: r.listingIndex },
          fallbackReserve: r.fallbackReserve === true, predictedReserve: r.predictedReserve || null,
          rememberedReserve: r.rememberedReserve || null, rememberedHeight: rememberedHeight(r),
          eligibleViewport: !r.media || r.media.matches, availableWidth: r.availableWidth == null ? null : Math.round(r.availableWidth),
          configuredSizes: fixedSizes(r), requested: r.requested, requestSize: r.requestSize || null,
          sticky: r.stickyCandidate ? { fit: r.stickyFit, reason: r.stickyReason, geometry: r.stickyGeometry } : null,
          timeToRequestMs: r.requestedMs == null ? null : Math.max(0, r.requestedMs - r.mountedMs),
          delivery: { distanceAtRequest: r.distanceAtRequest == null ? null : r.distanceAtRequest, dynamicNearAtRequest: r.dynamicNearAtRequest == null ? null : r.dynamicNearAtRequest,
            restingLeadPx: Math.round(restingLead(r)), configuredNearPx: num(r.options.near, 0),
            unusedNearMaxPx: num(r.options.nearMax, 0), distanceToViewport: r.distanceToViewport == null ? null : r.distanceToViewport,
            densityReason: r.densityReason || null, densityChecks: r.densityChecks, gateTimings: inspectGateTimings(r),
            budgetPath: r.budgetPath || null, reachedReserveQualified: r.reachedReserveQualified === true, reachedReserveReason: r.reachedReserveReason || null,
            firstNearbyMs: r.firstNearbyMs, firstOpportunityVisibleMs: r.firstOpportunityVisibleMs,
            scrollVelocityPxS: r.scrollVelocityAtRequest == null ? null : r.scrollVelocityAtRequest,
            paceViewportsPerSecondAtRequest: r.paceVhAtRequest == null ? null : r.paceVhAtRequest,
            estimatedArrivalMs: r.estimatedArrivalAtRequest == null ? null : r.estimatedArrivalAtRequest,
            responseEstimateMs: r.responseEstimateAtRequest == null ? null : r.responseEstimateAtRequest, responseMs: r.responseMs == null ? null : r.responseMs,
            providerInitStatus: r.providerInitStatus || '', providerAcceptedMs: r.providerAcceptedMs == null ? null : r.providerAcceptedMs,
            awaitingResponseMs: r.requested && !r.providerStatus && !r.error && !r.closed ? Math.max(0, now() - r.requestedMs) : null,
            opportunityReleased: r.stuckReleased === true,
            heldForCriticalMs: r.heldMs || 0, stagedBehindPremiumMs: r.stagedMs || 0, heldForFirstPaint: r.paintHeldMs != null, readerEngagedAtRequest: r.engagedAtRequest, governorAtRequest: r.governorAtRequest || null,
            frequencyCap: r.options.frequencyMax || 0, smartFrequency: r.options.smartFrequency === true,
            smartNextFill: r.smartNextFill || null, smartSessionPages: r.smartSessionPages || 0, smartSessionActiveMs: r.smartSessionActiveMs || 0 },
          localViewability: { qualified: r.localViewable === true,
            /* Share of the creative's own pixels inside the USABLE viewport, so
             * this is no longer a raw intersectionRatio. The old key is kept
             * because existing operator tooling reads it. */
            maxVisibleShare: Math.round((r.maxIntersectionRatio || 0) * 1000) / 1000,
            maxIntersectionRatio: Math.round((r.maxIntersectionRatio || 0) * 1000) / 1000,
            requiredRatio: viewableRatioFor(r), largeCreative: viewableRatioFor(r) === 0.3,
            timeAtLeastRequiredMs: viewableTotal(r), timeAtLeast50PctMs: viewableTotal(r) },
          container: rect(r.box), creative: rect(r.ins), reservation: r.reserved, hidden: r.box.hidden, error: r.error || null, timeline: r.timeline.slice() };
      }),
      loaders: d.querySelectorAll('script[src*="pagead/js/adsbygoogle.js"]').length,
      provider: { queueIsArray: Array.isArray(w.adsbygoogle), queuedCommands: Array.isArray(w.adsbygoogle) ? w.adsbygoogle.length : null,
        note: 'Push aceito na fila não comprova impressão. Somente data-ad-status explícito define filled/unfilled/unfill-optimized.' },
      queuedManual: counts.pendingEligible, pendingRegistrySize: pending.size, deferredAdjustments: adjustments.size
    };
  }

  /** One-line, human-readable account of the current decision. */
  function explain() {
    var dec = decision(), lines = [];
    lines.push('Entrega: inventário manual + Auto Ads geridos na conta. Unidades in-page reconhecidas entram no espaçamento de novos pedidos manuais; âncoras ajustam a viewport útil.');
    lines.push('Dispositivo: ' + RULES.device + ' · governador: ' + engine.governor + ' (' + engine.governorReason + ')' +
      ' · profundidade ' + Math.round(readerDepth() * 100) + '% · ritmo ' + (Math.round(motion.paceVh * 100) / 100) + ' viewports/s');
    lines.push('Política manual fixa: ritmo, expansão e teto independem do RPM global; sem consulta de regime por pageview.');
    lines.push('Histórico por unidade: ' + (dec.fresh ? 'modelo gerado há até 24h' : 'modelo ausente/expirado, valores neutros') + '; a idade do modelo não confirma captura recente do relatório nem preço atual do leilão.');
    lines.push('Motivos: ' + ((dec.reasons || []).join(', ') || 'sem sinal financeiro'));
    if (isArticle()) {
      lines.push('Artigo: ' + articleWords() + ' palavras' + (engine.articleType ? ' · ' + engine.articleType : '') +
        '; orçamento antecipado do corpo ' + bodyBudget() + ' (planejados ' + (engine.plannedBodyCount || 0) +
        ', renderizados ' + (engine.renderedBodyCount || 0) + ', capacidade ' + (engine.structuralBodyCapacity || 0) +
        ' em ' + (engine.eligibleCandidates || 0) + ' candidatos); reservas também podem ser admitidas quando alcançadas, dentro da capacidade e dos demais limites; ocupados ' + countOccupied(isBodyRecord));
    }
    lines.push('Espaçamento mínimo: ' + minGapFor({ surface: 'article' }) + 'px na coluna do artigo, ' +
      minGapFor({ surface: 'listing' }) + 'px em listagens · janela ' + RULES.density_window_vh +
      ' viewports, máx. ' + RULES.max_units_in_window + ' unidades · requests a cada ' + requestSpacingMs() + 'ms');
    lines.push('Sinal local de preenchimento/latência (não mede lances): ' + auctionSignal() +
      ' · latência estimada ' + Math.round(responseEstimateMs) + 'ms' +
      (engine.releasedStuck ? ' · ' + engine.releasedStuck + ' oportunidade(s) liberada(s) por silêncio do provedor' : ''));
    records.forEach(function (r) {
      if (r.critical) return;
      lines.push('  ' + r.placement + ' [' + (r.tier || 'standard') + '] valor=' + (Math.round(slotValue(r) * 100) / 100) +
        ' x alcance=' + (Math.round(reachProbability(r) * 100) / 100) + ' => ' + (Math.round(expectedValue(r) * 100) / 100) +
        ' · distância ' + (r.distanceToViewport == null ? '—' : r.distanceToViewport + 'px') + ' -> ' + r.state);
    });
    return lines.join('\n');
  }
  /* @lean:strip-end */

  /* @lean:stub
  function diagnosticSnapshot() { return null; }
  function flushDiagnostics() { return null; }
  function inspect() {
    return { version: VERSION, lean: true, mounted: records.length,
      requested: records.filter(function (r) { return r.requested; }).length,
      note: 'Cópia pública enxuta: o diagnóstico completo é servido ao administrador logado.' };
  }
  function explain() { return 'Cópia pública enxuta. Abra a página como administrador para o relatório completo.'; }
  @lean:stub-end */

  d.addEventListener('visibilitychange', handleVisibility);
  armPaintGate();
  /* Passive and once: these exist only to end the hold, never to drive delivery. */
  ['pointerdown', 'keydown', 'touchstart'].forEach(function (event) {
    d.addEventListener(event, releasePaintGateOnInput, { passive: true, once: true });
  });
  startDwell();
  checkScrollEngagement();
  ['wp_listen_for_consent_change', 'wp_consent_type_defined', 'go:consent-change', 'go:ads-consent-update'].forEach(function (event) {
    d.addEventListener(event, changedConsent);
  });
  d.addEventListener('DOMContentLoaded', function () { scan(d); schedule(); }, { once: true });
  d.addEventListener('go:content-updated', contentUpdated);
  /* Capturing resource completion also covers late images and embeds in browsers
   * without IntersectionObserver. Coalesced in the same animation-frame queue. */
  d.addEventListener('load', function () { if (pending.size) schedule(); }, true);
  w.addEventListener('pageshow', function (event) {
    engine.pageHidden = false;
    engine.refreshTopScrollOnResume = !!(event && event.persisted);
    if (engine.refreshTopScrollOnResume) engine.readerModel = null;
    handleVisibility();
    schedule();
  });
  w.addEventListener('pagehide', function () {
    engine.pageHidden = true;
    handleVisibility();
    persistReaderModel();
    flushDiagnostics('pagehide');
  });

  w.GOAdsRuntime = {
    version: VERSION, mount: mount, scan: scan, inspect: inspect, explain: explain,
    diagnosticSnapshot: diagnosticSnapshot, flushDiagnostics: flushDiagnostics,
    diagnosticBuffer: function () { return diagnosticBuffer.slice(); },
    dismiss: function (box) {
      records.forEach(function (r) { if (r.box === box) { r.closed = true; state(r, 'dismissed'); dispose(r); } });
    }
  };
  loadLatencyMemory();
  if (d.readyState === 'interactive' || d.readyState === 'complete') scan(d);
  d.dispatchEvent(new Event('go:ads-runtime-ready'));
})(window, document);
