(function () {
	'use strict';

	var controller = null;
	var serial = 0;

	function feed() {
		return document.querySelector('[data-od-desk-feed]');
	}

	function filterNav() {
		return document.querySelector('.od-desk-formats');
	}

	function statusNode() {
		return document.querySelector('.od-desk-status');
	}

	function cleanUrl(raw) {
		var url = new URL(raw, window.location.href);
		url.searchParams.delete('od_desk_fragment');
		return url;
	}

	function fragmentUrl(raw) {
		var url = cleanUrl(raw);
		url.searchParams.set('od_desk_fragment', 'feed');
		return url.toString();
	}

	function activeTypeFromUrl(raw) {
		try { return cleanUrl(raw).searchParams.get('tipo') || ''; }
		catch (error) { return ''; }
	}

	function setActiveFilter(raw) {
		var nav = filterNav();
		if (!nav) { return; }
		var activeType = activeTypeFromUrl(raw);
		nav.querySelectorAll('[data-od-desk-type]').forEach(function (item) {
			var active = (item.getAttribute('data-od-desk-type') || '') === activeType;
			item.classList.toggle('is-active', active);
			if (active) { item.setAttribute('aria-current', 'page'); }
			else { item.removeAttribute('aria-current'); }
		});
	}

	function setStatus(message) {
		var node = statusNode();
		if (node) { node.textContent = message || ''; }
	}

	function labelForUrl(raw) {
		var nav = filterNav();
		var type = activeTypeFromUrl(raw);
		if (!nav) { return type ? 'publicações filtradas' : 'últimas publicações'; }
		var match = Array.prototype.find.call(nav.querySelectorAll('[data-od-desk-type]'), function (item) {
			return (item.getAttribute('data-od-desk-type') || '') === type;
		});
		return match ? match.textContent.trim() : (type ? 'publicações filtradas' : 'últimas publicações');
	}

	function replaceFeed(raw, options) {
		options = options || {};
		var current = feed();
		if (!current) { return Promise.resolve(false); }

		var href = cleanUrl(raw).toString();
		var requestId = ++serial;
		if (controller && typeof controller.abort === 'function') { controller.abort(); }
		controller = 'AbortController' in window ? new AbortController() : null;

		current.setAttribute('aria-busy', 'true');
		current.classList.add('is-filtering');
		setStatus('Atualizando ' + labelForUrl(href) + '…');

		return fetch(fragmentUrl(href), {
			method: 'GET',
			credentials: 'same-origin',
			cache: 'no-store',
			headers: { 'X-Requested-With': 'XMLHttpRequest' },
			signal: controller ? controller.signal : undefined
		})
			.then(function (response) {
				if (!response.ok) { throw new Error('Falha ao atualizar a listagem'); }
				return response.text();
			})
			.then(function (html) {
				if (requestId !== serial) { return false; }
				var parsed = new DOMParser().parseFromString(html, 'text/html');
				var next = parsed.querySelector('[data-od-desk-feed]');
				var old = feed();
				if (!next || !old) { throw new Error('Listagem não encontrada'); }

				old.replaceWith(next);
				setActiveFilter(href);
				if (options.pushState !== false) {
					window.history.pushState({ odDeskFilter: true }, '', href);
				}
				setStatus(labelForUrl(href) + ' atualizadas.');
				document.dispatchEvent(new CustomEvent('go:content-updated', { detail: { scope: next } }));

				if (options.scrollToFeed) {
					var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
					next.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
				}
				return true;
			})
			.catch(function (error) {
				if (error && error.name === 'AbortError') { return false; }
				var old = feed();
				if (old) {
					old.removeAttribute('aria-busy');
					old.classList.remove('is-filtering');
				}
				setStatus('Não foi possível atualizar aqui. Abrindo a página…');
				window.location.assign(href);
				return false;
			});
	}

	document.addEventListener('click', function (event) {
		if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) { return; }

		var filter = event.target.closest('[data-od-desk-type]');
		if (filter && filterNav() && feed()) {
			event.preventDefault();
			replaceFeed(filter.href, { pushState: true, scrollToFeed: false });
			return;
		}

		var page = event.target.closest('[data-od-desk-page]');
		if (page && feed()) {
			event.preventDefault();
			replaceFeed(page.href, { pushState: true, scrollToFeed: true });
		}
	});

	window.addEventListener('popstate', function () {
		if (!feed()) { return; }
		replaceFeed(window.location.href, { pushState: false, scrollToFeed: false });
	});
})();
