/**
 * Overdrive 5.6.5 — Clever placements and anchor docking.
 *
 * Printed inline right before the Clever loader, at the end of the body.
 *
 * 300x250: Clever fills the FIRST element carrying `clever-core-ads`. The server
 * prints inert hosts; the first one that is actually rendered receives the class,
 * so a hidden column can never swallow the creative. A host reserves nothing and
 * is revealed only once Clever put a creative in it, and only while its insertion
 * point is below the viewport, where growing moves nothing the reader can see.
 *
 * 320x50 anchor: Clever inserts it as the first child of the body, fixed to the
 * bottom. The critical CSS keeps it in normal flow at the very top instead, above
 * Top Scroll, where it covers neither the article nor Google's own anchor. On the
 * pageview that opens Clever's rotation the strip was reserved before first paint,
 * so docking swaps one 50px box for another. When that pageview ends up without
 * an anchor the strip stays until the reader leaves: removing it would move the
 * whole page, and Chrome counts that as layout shift even above the viewport,
 * scroll anchoring or not. Collapses happen only inside a tap on the anchor.
 *
 * Nothing here requests, refreshes, moves or hides an AdSense unit, and nothing is
 * stored. Printed inline: no "<" may be immediately followed by a letter, "/",
 * "!" or "?".
 */
(function (w, d) {
  'use strict';
  var api = w.GOClever = w.GOClever || {};
  var root = d.documentElement;
  var id = String(api.id || (w.GOCleverConfig && w.GOCleverConfig.id) || '');
  if (!id || api.controller || !d.body) {
    return;
  }
  api.controller = true;

  var nativeAnchoring = !!(w.CSS && w.CSS.supports && w.CSS.supports('overflow-anchor', 'auto'));
  var anchorId = new RegExp('^clever-' + id + '-\\d+-stickySponsorClick(?:Top)?$');
  var strip = d.querySelector('.go-clever-anchor-slot');
  var expected = root.getAttribute('data-go-first-access') === '1';
  var anchor = null;
  var anchorHeight = 50;
  var decision = '';
  var pendingSlot = false;
  var watching = false;
  var frame = 0;

  function anchorState(value) {
    root.setAttribute('data-go-clever-anchor', value);
  }

  function viewportHeight() {
    return w.innerHeight || root.clientHeight || 0;
  }

  /* ------------------------------------------------------------------ 300x250 */

  var slot = null;
  var mount = null;
  var hosts = d.querySelectorAll('[data-go-clever-slot]');
  for (var i = 0; i !== hosts.length; i++) {
    var parent = hosts[i].parentElement;
    var candidate = hosts[i].querySelector('[data-go-clever-mount]');
    if (candidate && parent && parent.getClientRects().length) {
      slot = hosts[i];
      mount = candidate;
      break;
    }
  }
  if (mount) {
    mount.classList.add('clever-core-ads');
  }

  function insertionPoint(el) {
    var prev = el.previousElementSibling;
    var next = el.nextElementSibling;
    if (prev && prev.getClientRects().length) {
      return prev.getBoundingClientRect().bottom;
    }
    if (next && next.getClientRects().length) {
      return next.getBoundingClientRect().top;
    }
    return el.parentElement ? el.parentElement.getBoundingClientRect().top : 0;
  }

  function revealSlot() {
    pendingSlot = false;
    if (!slot || !mount || !mount.firstElementChild || slot.getAttribute('data-go-clever-state') === 'filled') {
      return;
    }
    if (insertionPoint(slot) < viewportHeight()) {
      /* On screen or already passed: growing now would move what the reader
       * sees (or, above the viewport, still count as layout shift). */
      pendingSlot = true;
      watch();
      return;
    }
    slot.setAttribute('data-go-clever-state', 'filled');
  }

  if (mount && w.MutationObserver) {
    new w.MutationObserver(function () {
      if (mount.firstElementChild) {
        decide('cube');
        revealSlot();
      }
    }).observe(mount, { childList: true });
  }

  /* ------------------------------------------------------------ 320x50 anchor */

  function stripReserved() {
    return expected && !!strip && !root.hasAttribute('data-go-clever-anchor');
  }

  /* What Clever did with this pageview; diagnostics only (inspect()). */
  function decide(kind) {
    if (!decision) {
      decision = kind;
    }
  }

  function isAnchor(node) {
    return !!(node && node.nodeType === 1 && anchorId.test(node.id || ''));
  }

  function dock(node) {
    if (anchor === node) {
      return;
    }
    var reserved = stripReserved();
    anchor = node;
    anchorHeight = node.offsetHeight || anchorHeight;
    decide('anchor');
    anchorState('docked');
    /* Unreserved (Clever served the anchor on a pageview its cookies did not
     * announce): it was inserted above everything. Where the browser has no
     * scroll anchoring, keep the reading position by hand. */
    if (!reserved && !nativeAnchoring && (w.pageYOffset || root.scrollTop || 0) > 0) {
      w.scrollBy(0, anchorHeight);
    }
  }

  function anchorGone() {
    if (!anchor) {
      return;
    }
    anchor = null;
    anchorState('closed');
  }

  if (w.MutationObserver) {
    new w.MutationObserver(function (records) {
      for (var r = 0; r !== records.length; r++) {
        var added = records[r].addedNodes;
        var removed = records[r].removedNodes;
        for (var a = 0; a !== added.length; a++) {
          if (isAnchor(added[a])) {
            dock(added[a]);
          }
        }
        for (var b = 0; b !== removed.length; b++) {
          if (removed[b] === anchor) {
            anchorGone();
          }
        }
      }
    }).observe(d.body, { childList: true });
  }
  for (var child = d.body.firstElementChild, n = 0; child && n !== 8; child = child.nextElementSibling, n++) {
    if (isAnchor(child)) {
      dock(child);
      break;
    }
  }

  /* Clever removes a closed anchor 500 ms after the tap. Collapse its box inside
   * the tap itself, so the page never moves outside a user interaction. Capture
   * phase, never cancelled: Clever's own handlers still run and decide. */
  d.addEventListener('click', function (event) {
    var target = event.target;
    if (!anchor || !target || target.nodeType !== 1 || !anchor.contains(target)) {
      return;
    }
    var control = target.closest ? target.closest('[id]') : target;
    if (control && /-(?:close|shadow)$/.test(control.id || '')) {
      anchorState('closed');
    }
  }, true);

  /* ----------------------------------------------------------- scroll watcher */

  function sweep() {
    frame = 0;
    if (pendingSlot) {
      revealSlot();
    }
    if (!pendingSlot && watching) {
      watching = false;
      w.removeEventListener('scroll', onScroll);
      w.removeEventListener('resize', onScroll);
    }
  }

  function onScroll() {
    if (!frame) {
      frame = w.requestAnimationFrame(sweep);
    }
  }

  function watch() {
    if (watching) {
      return;
    }
    watching = true;
    w.addEventListener('scroll', onScroll, { passive: true });
    w.addEventListener('resize', onScroll, { passive: true });
  }

  /* ------------------------------------------------------- Clever's decision */

  /* data-callback on the loader: Clever calls it with (user, tracker) when a
   * format is shown. The anchor is handled by the body observer above. */
  w.GOCleverFormat = function (user, tracker) {
    var type = tracker && tracker.Type ? String(tracker.Type) : '';
    api.format = type;
    if (type && !/^stickySponsorClick/i.test(type)) {
      decide(type);
    }
  };

  /* Clever posts these to its own window when this pageview gets no format. */
  w.addEventListener('message', function (event) {
    if (event.source === w && (event.data === 'clever|callback' || event.data === 'clever|alternative')) {
      w.setTimeout(function () {
        decide('none');
      }, 0);
    }
  });

  api.loader = function (script) {
    api.loaderState = 'loading';
    if (!script || !script.addEventListener) {
      return;
    }
    script.addEventListener('load', function () {
      api.loaderState = 'loaded';
      /* Clever resolves its format asynchronously after the script runs. */
      w.setTimeout(function () {
        decide('none');
      }, 4000);
    });
    script.addEventListener('error', function () {
      api.loaderState = 'error';
      decide('blocked');
    });
  };

  function lateFallback() {
    w.setTimeout(function () {
      decide('timeout');
    }, 8000);
  }
  if (d.readyState === 'complete') {
    lateFallback();
  } else {
    w.addEventListener('load', lateFallback, { once: true });
  }

  api.inspect = function () {
    return {
      id: id,
      firstAccess: !!api.firstAccess,
      anchor: root.getAttribute('data-go-clever-anchor') || (stripReserved() ? 'reserved' : 'none'),
      decision: decision || 'pending',
      format: api.format || '',
      slot: slot ? slot.getAttribute('data-go-clever-slot') : '',
      slotState: slot ? (slot.getAttribute('data-go-clever-state') || (mount && mount.firstElementChild ? 'waiting-offscreen' : 'empty')) : '',
      loader: api.loaderState || 'pending'
    };
  };
})(window, document);
