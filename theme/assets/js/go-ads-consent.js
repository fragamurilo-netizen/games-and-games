/** Overdrive 3.85.0 — shared permission reader, never a consent manager. */
(function (w, d) {
  'use strict';
  if (w.GOAdsConsent) return;
  var tcfGranted = false, registered = false, tries = 0, timer = 0;
  function permitted() {
    try {
      // A site's explicit WP Consent API signal takes precedence, including denial.
      if (typeof w.wp_has_consent === 'function') return w.wp_has_consent('marketing') === true;
    } catch (e) { return false; }
    return tcfGranted === true;
  }
  function notify() {
    try { d.dispatchEvent(new Event('go:ads-consent-update')); } catch (e) {}
  }
  function discover() {
    if (registered) return;
    if (typeof w.__tcfapi === 'function') {
      try {
        registered = true;
        if (timer) w.clearTimeout(timer);
        w.__tcfapi('addEventListener', 2, function (tc, success) {
          // Neither unknown consent nor gdprApplies=false is an implicit storage grant.
          var settled = tc && (!tc.eventStatus || /^(tcloaded|useractioncomplete)$/.test(tc.eventStatus));
          tcfGranted = !!(success && settled && tc && (!tc.cmpStatus || tc.cmpStatus === 'loaded') &&
            tc.purpose && tc.purpose.consents && tc.purpose.consents[1] === true &&
            tc.vendor && tc.vendor.consents && tc.vendor.consents[755] === true);
          notify();
        });
      } catch (e) { registered = false; tcfGranted = false; }
    }
    // Bounded discovery only. No visitor identifiers, cookies, writes or network calls.
    if (!registered && tries++ < 20 && !timer) {
      timer = w.setTimeout(function () { timer = 0; discover(); }, 500);
    }
  }
  w.GOAdsConsent = { version: '3.85.0', permitted: permitted };
  ['wp_listen_for_consent_change', 'wp_consent_type_defined', 'go:consent-change'].forEach(function (name) {
    d.addEventListener(name, function () { discover(); notify(); });
  });
  d.addEventListener('DOMContentLoaded', function () { discover(); notify(); }, { once: true });
  w.addEventListener('pageshow', function () { discover(); notify(); });
  discover();
})(window, document);
