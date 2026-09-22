(function () {
	'use strict';

	function initCoverage(hub) {
		if (!hub || hub.dataset.goCoverageReady === '1') { return; }
		hub.dataset.goCoverageReady = '1';

		var buttons = Array.prototype.slice.call(hub.querySelectorAll('[data-go-coverage-filter]'));
		var empty = hub.querySelector('[data-go-coverage-empty]');
		if (!buttons.length) { return; }
		var controls = hub.querySelector('[data-go-coverage-controls]');
		if (controls) { controls.hidden = false; }

		function activeFilter() {
			var active = hub.querySelector('[data-go-coverage-filter].is-active,[data-go-coverage-filter][aria-pressed="true"]');
			return active ? (active.getAttribute('data-go-coverage-filter') || 'all') : 'all';
		}

		function apply(filter, sourceButton) {
			var visible = 0;
			buttons.forEach(function (candidate) {
				var active = sourceButton ? candidate === sourceButton : (candidate.getAttribute('data-go-coverage-filter') || 'all') === filter;
				candidate.classList.toggle('is-active', active);
				candidate.setAttribute('aria-pressed', active ? 'true' : 'false');
			});

			Array.prototype.forEach.call(hub.querySelectorAll('[data-go-coverage-item]'), function (item) {
				var types = (item.getAttribute('data-go-coverage-types') || '').split(/\s+/);
				var show = filter === 'all' || types.indexOf(filter) !== -1;
				item.hidden = !show;
				if (show) { visible += 1; }
			});

			if (empty) { empty.hidden = visible !== 0; }
			return visible;
		}

		function loaderHasMore() {
			var loader = hub.querySelector('[data-go-load-more][data-mode="game-coverage"]');
			if (!loader || loader.hidden) { return false; }
			var page = parseInt(loader.getAttribute('data-page') || '1', 10) || 1;
			var max = parseInt(loader.getAttribute('data-max') || '1', 10) || 1;
			return page < max ? loader : false;
		}

		function ensureFilteredResult(filter, visible) {
			if (filter === 'all' || visible > 0) { return; }
			var loader = loaderHasMore();
			if (!loader) { return; }
			/* V8 finishes its current promise immediately after dispatching the content
			 * event, so schedule the next request one tick later instead of racing its
			 * loading lock. This only runs when the chosen filter has no loaded row yet. */
			window.setTimeout(function () { loader.click(); }, 160);
		}

		buttons.forEach(function (button) {
			button.addEventListener('click', function () {
				var filter = button.getAttribute('data-go-coverage-filter') || 'all';
				ensureFilteredResult(filter, apply(filter, button));
			});
		});

		/* Infinite-scroll rows are appended after this module initialises. Reapply
		 * the current filter to the live NodeList instead of freezing page-1 items. */
		hub.addEventListener('go:content-updated', function () {
			var filter = activeFilter();
			ensureFilteredResult(filter, apply(filter, null));
		});
	}

	function ready() {
		Array.prototype.forEach.call(document.querySelectorAll('[data-go-game-coverage]'), initCoverage);
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', ready, { once: true });
	} else {
		ready();
	}
}());
