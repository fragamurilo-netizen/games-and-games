/** Small progressive enhancements for game pages. No libraries or polling. */
(function () {
  'use strict';
  function ready() {
    var root = document.querySelector('.od-games');
    if (!root || root.dataset.odGamesReady === '1') { return; }
    root.dataset.odGamesReady = '1';

    var catalog = root.querySelector('[data-od-catalog-view]');
    var views = root.querySelector('[data-od-view-controls]');
    if (catalog && views) {
      views.hidden = false;
      views.addEventListener('click', function (event) {
        var button = event.target.closest('[data-od-view]');
        if (!button || !views.contains(button)) { return; }
        var view = button.getAttribute('data-od-view');
        if (view !== 'list' && view !== 'grid') { return; }
        catalog.setAttribute('data-od-catalog-view', view);
        views.querySelectorAll('[data-od-view]').forEach(function (item) {
          item.setAttribute('aria-pressed', item === button ? 'true' : 'false');
        });
      });
    }

    root.querySelectorAll('[data-od-trailer]').forEach(function (trailer) {
      var play = trailer.querySelector('[data-od-play]');
      if (!play) { return; }
      play.addEventListener('click', function (event) {
        if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button > 0) { return; }
        var url;
        try { url = new URL(trailer.getAttribute('data-od-embed')); } catch (error) { return; }
        if (url.protocol !== 'https:' || !/^(www\.)?youtube(-nocookie)?\.com$/.test(url.hostname) || url.pathname.indexOf('/embed/') !== 0) { return; }
        event.preventDefault();
        url.searchParams.set('autoplay', '1');
        url.searchParams.set('rel', '0');
        var frame = document.createElement('iframe');
        frame.src = url.toString();
        frame.title = trailer.getAttribute('data-od-title') || 'Trailer do jogo';
        frame.width = '1280'; frame.height = '720';
        frame.allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen';
        frame.allowFullscreen = true;
        frame.referrerPolicy = 'strict-origin-when-cross-origin';
        frame.tabIndex = 0;
        play.replaceWith(frame);
        frame.focus();
      });
    });

    var dialog = root.querySelector('[data-od-lightbox]');
    var items = Array.prototype.slice.call(root.querySelectorAll('[data-od-gallery-item]'));
    if (dialog && items.length && typeof dialog.showModal === 'function') {
      var image = dialog.querySelector('[data-od-gallery-image]');
      var counter = dialog.querySelector('[data-od-gallery-counter]');
      var original = dialog.querySelector('[data-od-gallery-original]');
      var imageError = dialog.querySelector('[data-od-gallery-error]');
      var close = dialog.querySelector('[data-od-gallery-close]');
      var prev = dialog.querySelector('[data-od-gallery-prev]');
      var next = dialog.querySelector('[data-od-gallery-next]');
      var current = 0;
      var opener = null;
      var previousOverflow = '';
      function show(index) {
        current = (index + items.length) % items.length;
        var item = items[current];
        var thumbnail = item.querySelector('img');
        imageError.hidden = true; image.hidden = false;
        image.alt = thumbnail ? thumbnail.alt : '';
        image.src = item.href;
        original.href = item.href;
        counter.textContent = (current + 1) + ' / ' + items.length;
      }
      image.addEventListener('error', function () { image.hidden = true; imageError.hidden = false; });
      prev.hidden = items.length < 2; next.hidden = items.length < 2;
      prev.addEventListener('click', function () { show(current - 1); });
      next.addEventListener('click', function () { show(current + 1); });
      close.addEventListener('click', function () { dialog.close(); });
      dialog.addEventListener('keydown', function (event) {
        if (event.key === 'ArrowRight') { event.preventDefault(); show(current + 1); }
        if (event.key === 'ArrowLeft') { event.preventDefault(); show(current - 1); }
      });
      dialog.addEventListener('click', function (event) {
        if (event.target !== dialog) { return; }
        var rect = dialog.getBoundingClientRect();
        if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) { dialog.close(); }
      });
      dialog.addEventListener('close', function () {
        document.documentElement.style.overflow = previousOverflow;
        if (opener && opener.isConnected) { opener.focus({ preventScroll: true }); }
      });
      items.forEach(function (item, index) {
        item.addEventListener('click', function (event) {
          if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button > 0) { return; }
          event.preventDefault();
          opener = item; show(index);
          previousOverflow = document.documentElement.style.overflow;
          dialog.showModal();
          document.documentElement.style.overflow = 'hidden';
          close.focus();
        });
      });
    }

    // Native fragment navigation remains usable without JavaScript.
    var nav = root.querySelector('[data-od-game-nav]');
    if (nav) {
      function markCurrent() {
        var hash = window.location.hash;
        nav.querySelectorAll('a[href^="#"]').forEach(function (link) {
          if (link.getAttribute('href') === hash) { link.setAttribute('aria-current', 'location'); }
          else { link.removeAttribute('aria-current'); }
        });
      }
      markCurrent();
      window.addEventListener('hashchange', markCurrent);
    }
  }
  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', ready, { once: true }); }
  else { ready(); }
}());
