/**
 * Lightweight remote search for large editorial catalogs.
 * Keeps thousands of <option> nodes out of Gutenberg until they are needed.
 */
(function (window, document) {
	'use strict';

	var cfg = window.GoVergeEditorCatalogSearch || {};
	if (!cfg.ajaxUrl || !cfg.nonce) { return; }

	function copyOption(option) {
		var clone = option.cloneNode(true);
		clone.selected = option.selected;
		return clone;
	}

	function selectedSnapshot(select) {
		var option = select.options[select.selectedIndex];
		if (!option || !option.value) { return null; }
		return { value: option.value, text: option.textContent || option.value };
	}

	function bind(input) {
		if (!input || input.dataset.goCatalogBound === '1') { return; }
		var targetId = input.getAttribute('data-go-catalog-target');
		var select = targetId ? document.getElementById(targetId) : null;
		if (!select) { return; }
		input.dataset.goCatalogBound = '1';

		var staticOptions = Array.prototype.slice.call(select.querySelectorAll('option[data-go-catalog-static="1"]')).map(copyOption);
		var initial = selectedSnapshot(select);
		var timer = 0;
		var controller = null;
		var lastQuery = '';

		function render(items) {
			var current = selectedSnapshot(select) || initial;
			select.innerHTML = '';
			staticOptions.forEach(function (option) { select.appendChild(copyOption(option)); });

			var groups = Object.create(null);
			(items || []).forEach(function (item) {
				if (!item || !item.value || !item.text) { return; }
				if (Array.prototype.some.call(select.options, function (option) { return option.value === item.value; })) { return; }
				var option = document.createElement('option');
				option.value = item.value;
				option.textContent = item.text;
				var groupName = String(item.group || 'Resultados');
				if (!groups[groupName]) {
					groups[groupName] = document.createElement('optgroup');
					groups[groupName].label = groupName;
					select.appendChild(groups[groupName]);
				}
				groups[groupName].appendChild(option);
			});

			if (current && current.value && !Array.prototype.some.call(select.options, function (option) { return option.value === current.value; })) {
				var pinned = document.createElement('option');
				pinned.value = current.value;
				pinned.textContent = current.text;
				pinned.setAttribute('data-go-catalog-pinned', '1');
				select.appendChild(pinned);
			}
			if (current && current.value) { select.value = current.value; }
			select.removeAttribute('aria-busy');
		}

		function search() {
			var query = String(input.value || '').trim().replace(/\s+/g, ' ');
			if (query.length < 2) {
				lastQuery = '';
				if (controller) { controller.abort(); controller = null; }
				render([]);
				return;
			}
			if (query === lastQuery) { return; }
			lastQuery = query;
			if (controller) { controller.abort(); }
			controller = 'AbortController' in window ? new AbortController() : null;
			select.setAttribute('aria-busy', 'true');

			var params = new URLSearchParams({
				action: 'go_verge_editor_catalog_search',
				nonce: cfg.nonce,
				q: query,
				types: input.getAttribute('data-go-catalog-types') || 'games,go_entity'
			});
			fetch(cfg.ajaxUrl + '?' + params.toString(), {
				credentials: 'same-origin',
				signal: controller ? controller.signal : undefined
			})
				.then(function (response) { if (!response.ok) { throw new Error('request'); } return response.json(); })
				.then(function (payload) {
					if (query !== lastQuery) { return; }
					render(payload && payload.success && payload.data ? payload.data.items : []);
				})
				.catch(function (error) {
					if (error && error.name === 'AbortError') { return; }
					select.removeAttribute('aria-busy');
				});
		}

		input.addEventListener('input', function () {
			window.clearTimeout(timer);
			timer = window.setTimeout(search, 260);
		});
	}

	function boot() {
		document.querySelectorAll('[data-go-catalog-search]').forEach(bind);
	}

	if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', boot, { once: true }); }
	else { boot(); }
})(window, document);
