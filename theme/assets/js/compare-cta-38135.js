(function () {
  'use strict';
  var ROOT_CLASS = 'go-compare-promo-38135';
  var LINK_SELECTOR = 'a[href*="/compara/"][href*="category="], a[href*="/compara?"][href*="category="]';

  function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }

  function fixCopy(node) {
    var walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    var current;
    while ((current = walker.nextNode())) {
      current.nodeValue = current.nodeValue.replace(/Celulars/g, 'Celulares').replace(/celulars/g, 'celulares')
        .replace(/\b(Compare|Comparar)\s+tvs\b/gi, '$1 TVs');
    }
  }

  function findPromoRoot(link) {
    var article = link.closest('.go-article__content, .entry-content');
    if (!article) return null;
    var node = link.parentElement;
    var depth = 0;
    while (node && node !== article && depth < 8) {
      var text = clean(node.textContent).toLowerCase();
      if (text.indexOf('overdrive compare') !== -1 && text.indexOf('escolha os modelos') !== -1 && text.length < 700) return node;
      node = node.parentElement;
      depth += 1;
    }
    return null;
  }

  function topChild(root, node) {
    if (!node || node === root) return null;
    while (node.parentElement && node.parentElement !== root) node = node.parentElement;
    return node.parentElement === root ? node : null;
  }

  function classify(root, link) {
    if (!root || root.classList.contains(ROOT_CLASS + '--ready') && link.classList.contains(ROOT_CLASS + '__action')) return;
    root.classList.remove(ROOT_CLASS + '--grouped', ROOT_CLASS + '--no-icon');
    fixCopy(root);
    root.classList.add(ROOT_CLASS);
    link.classList.add(ROOT_CLASS + '__action');
    var title = null;
    var description = null;
    var kicker = null;
    var nodes = root.querySelectorAll('span, strong, small, p, h2, h3, h4, div');
    Array.prototype.forEach.call(nodes, function (el) {
      if (el.children.length || link.contains(el)) return;
      var text = clean(el.textContent);
      if (/^overdrive compare$/i.test(text)) { el.classList.add(ROOT_CLASS + '__kicker'); kicker = el; }
      else if (/^compare\s+/i.test(text) && text.length < 80) { el.classList.add(ROOT_CLASS + '__title'); title = el; }
      else if (/^escolha os modelos/i.test(text)) { el.classList.add(ROOT_CLASS + '__description'); description = el; }
    });
    var copy = title && title.parentElement;
    while (copy && copy !== root && description && !copy.contains(description)) copy = copy.parentElement;
    if (copy && copy !== root && !copy.contains(link)) copy.classList.add(ROOT_CLASS + '__copy');

    var icon = null;
    Array.prototype.some.call(root.querySelectorAll('svg'), function (svg) {
      // The arrow inside the CTA is NOT the product icon.
      if (!link.contains(svg)) { icon = svg; return true; }
      return false;
    });
    if (icon && icon.parentElement !== root) icon.parentElement.classList.add(ROOT_CLASS + '__icon');
    var copyTop = topChild(root, title || description || kicker);
    var iconTop = topChild(root, icon);
    if (copyTop && iconTop && copyTop === iconTop && !copyTop.contains(link)) {
      root.classList.add(ROOT_CLASS + '--grouped');
      copyTop.classList.add(ROOT_CLASS + '__body');
    } else if (!icon) root.classList.add(ROOT_CLASS + '--no-icon');
    var actionTop = topChild(root, link);
    if (actionTop && actionTop !== link) actionTop.classList.add(ROOT_CLASS + '__action-wrap');
    root.classList.add(ROOT_CLASS + '--ready');
  }

  function enhance(scope) {
    if (!scope || scope.nodeType !== 1 && scope.nodeType !== 9) return;
    if (scope.matches && scope.matches(LINK_SELECTOR)) classify(findPromoRoot(scope), scope);
    Array.prototype.forEach.call(scope.querySelectorAll(LINK_SELECTOR), function (link) { classify(findPromoRoot(link), link); });
  }

  function boot() {
    var targets = document.querySelectorAll('.go-article__content, .entry-content');
    Array.prototype.forEach.call(targets, function (target) {
      // .entry-content and .go-article__content often refer to the same element.
      if (target.dataset.goCompareObserved || target.parentElement && target.parentElement.closest('.go-article__content, .entry-content')) return;
      target.dataset.goCompareObserved = '1';
      enhance(target);
      if (!('MutationObserver' in window)) return;
      var observer = new MutationObserver(function (mutations) {
        mutations.forEach(function (mutation) {
          Array.prototype.forEach.call(mutation.addedNodes, function (node) {
            if (node.nodeType !== 1) return;
            // Visit inserted subtrees only; never rescan all article links for ads.
            enhance(node);
          });
        });
      });
      observer.observe(target, { childList: true, subtree: true });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
  else boot();
}());
