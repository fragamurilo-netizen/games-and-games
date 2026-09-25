/**
 * Overdrive 5.6.5 — Clever first-access decision, before first paint.
 *
 * Clever serves one format per pageview in a fixed rotation (320x50 anchor,
 * then 300x250, then the mobile 300x250) and pauses for 24 hours after the
 * last one. Its own first-party cookies say where the reader is:
 *
 *   clever-last-tracker-{id}  a rotation is running: the next format is a 300x250;
 *   clever-counter-{id}       the 24-hour pause is running: nothing will be served.
 *
 * With neither, this pageview opens a rotation and is the one that receives the
 * anchor. Only then is the 50px strip reserved above Top Scroll and Top Scroll
 * requested as an exact 300x250 with compact framing. Every other pageview,
 * the second access onwards, keeps Top Scroll exactly as configured.
 *
 * Nothing is written: the decision reads Clever's state and the viewport only.
 * Printed inline, so it must never contain a "<" immediately followed by a
 * letter, "/", "!" or "?" (see go_verge_ads_inline_script_is_safe()).
 */
(function (w, d) {
  'use strict';
  var cfg = w.GOCleverConfig || {};
  var root = d.documentElement;
  var api = w.GOClever = w.GOClever || {};

  api.id = String(cfg.id || '');
  api.firstAccess = false;

  try {
    var phone = !!(w.matchMedia && w.matchMedia('(max-width: 767px)').matches);
    /* Below 300px an exact 300x250 has nowhere to fit: keep the responsive unit. */
    var roomy = (root.clientWidth || w.innerWidth || 0) >= 300;
    var rotating = !!api.id && new RegExp('(?:^|;\\s*)clever-(?:counter|last-tracker)-' + api.id + '=').test(d.cookie || '');
    if (cfg.firstAccess && api.id && phone && roomy && !rotating) {
      api.firstAccess = true;
      root.setAttribute('data-go-first-access', '1');
    }
  } catch (e) {
    api.firstAccess = false;
  }

  /**
   * Top Scroll variant for the first access, applied by the unit's own mount
   * script before the runtime sees the unit, so the request, the reserve and
   * the diagnostics all describe the same thing. It follows Google's
   * documented exact-size pattern: explicit width and height on the ins, no
   * data-ad-format and no data-full-width-responsive. The slot, the frequency
   * cap and every delivery gate are untouched.
   *
   * @param {Element} host    The Top Scroll wrapper.
   * @param {Object}  options The runtime mount options printed by the server.
   * @return {Object} Options to mount with.
   */
  api.topScroll = function (host, options) {
    if (!api.firstAccess || !host || !options || options.fixed) {
      return options;
    }
    try {
      var template = null;
      for (var i = 0; i !== host.children.length; i++) {
        var child = host.children[i];
        if (child.tagName === 'TEMPLATE' && child.hasAttribute('data-go-ad-pending')) {
          template = child;
        }
      }
      var ins = template && template.content && template.content.firstElementChild;
      if (!ins || ins.tagName !== 'INS' || ins.hasAttribute('data-ad-status') || ins.hasAttribute('data-adsbygoogle-status')) {
        host.setAttribute('data-go-ad-variant', 'normal');
        return options;
      }
      var next = {};
      for (var key in options) {
        if (Object.prototype.hasOwnProperty.call(options, key)) {
          next[key] = options[key];
        }
      }
      next.fixed = true;
      next.sizes = [[300, 250]];
      ins.removeAttribute('data-ad-format');
      ins.removeAttribute('data-full-width-responsive');
      ins.classList.add('go-ad-unit--fixed');
      host.setAttribute('data-go-ad-sizing', 'fixed');
      host.setAttribute('data-go-ad-variant', 'first-access-300x250');
      /* The footer recovery mounts from this attribute when the inline runtime
       * is missing; it must describe the same unit the inline call mounts. */
      host.setAttribute('data-go-ad-options', JSON.stringify(next));
      return next;
    } catch (e) {
      host.setAttribute('data-go-ad-variant', 'normal');
      return options;
    }
  };
})(window, document);
