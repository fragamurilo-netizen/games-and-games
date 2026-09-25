/**
 * Assistente de publicação — fetches the server-side checklist and renders it
 * in the sidebar metabox. Re-runs on demand ("Reverificar").
 */
(function () {
	'use strict';

	if (typeof GoVergeAssistant === 'undefined') { return; }

	var box = document.querySelector('[data-go-publish-assistant]');
	if (!box) { return; }

	var postId = box.getAttribute('data-post');
	var list = box.querySelector('[data-go-assistant-list]');
	var refresh = box.querySelector('[data-go-assistant-refresh]');
	var checkedAt = box.querySelector('[data-go-assistant-checked]');

	var ICONS = {
		warn: { glyph: '⚠', color: '#b45309' },
		info: { glyph: 'ℹ', color: '#2271b1' },
		ok: { glyph: '✓', color: '#00a32a' }
	};

	function render(items) {
		list.innerHTML = '';
		if (!items.length) {
			var empty = document.createElement('p');
			empty.style.cssText = 'color:#646970;margin:0;';
			empty.textContent = 'Nada para verificar ainda — salve o rascunho primeiro.';
			list.appendChild(empty);
			return;
		}

		var warnCount = items.filter(function (item) { return item.level === 'warn'; }).length;
		var summary = document.createElement('p');
		summary.style.cssText = 'margin:0 0 8px;font-weight:600;';
		summary.textContent = warnCount === 0
			? 'Tudo certo para publicar ✓'
			: (warnCount === 1 ? '1 alerta antes de publicar' : warnCount + ' alertas antes de publicar');
		summary.style.color = warnCount === 0 ? '#00a32a' : '#b45309';
		list.appendChild(summary);

		var ul = document.createElement('ul');
		ul.style.cssText = 'margin:0;display:grid;gap:6px;';

		items.forEach(function (item) {
			var icon = ICONS[item.level] || ICONS.info;
			var li = document.createElement('li');
			li.style.cssText = 'margin:0;display:flex;gap:6px;align-items:flex-start;line-height:1.45;';

			var mark = document.createElement('span');
			mark.textContent = icon.glyph;
			mark.style.cssText = 'color:' + icon.color + ';flex:none;font-weight:700;';
			mark.setAttribute('aria-hidden', 'true');
			li.appendChild(mark);

			var body = document.createElement('span');
			body.textContent = item.text;
			if (item.action && item.action.href) {
				body.appendChild(document.createTextNode(' '));
				var link = document.createElement('a');
				link.href = item.action.href;
				link.textContent = item.action.label || 'Abrir';
				if (item.action.href.charAt(0) !== '#') { link.target = '_blank'; link.rel = 'noopener'; }
				body.appendChild(link);
			}
			li.appendChild(body);
			ul.appendChild(li);
		});
		list.appendChild(ul);
	}

	function run() {
		if (!postId || postId === '0') {
			render([]);
			return;
		}
		list.setAttribute('aria-busy', 'true');
		fetch(GoVergeAssistant.restUrl + postId, {
			credentials: 'same-origin',
			headers: { 'X-WP-Nonce': GoVergeAssistant.nonce }
		})
			.then(function (response) {
				if (!response.ok) { throw new Error('request failed'); }
				return response.json();
			})
			.then(function (payload) {
				render(payload.items || []);
				if (checkedAt && payload.checked) { checkedAt.textContent = 'Verificado às ' + payload.checked; }
			})
			.catch(function () {
				list.innerHTML = '<p style="color:#b32d2e;margin:0;">Não foi possível verificar agora.</p>';
			})
			.finally(function () {
				list.removeAttribute('aria-busy');
			});
	}

	if (refresh) { refresh.addEventListener('click', run); }
	// Intentionally manual. This endpoint performs editorial similarity/topic
	// checks and should never compete with Gutenberg's first paint or typing.
	// Editors can run it on demand immediately before publishing.

	// Focus helper: "#go-review-platform" deep links scroll to the field.
	list.addEventListener('click', function (event) {
		var link = event.target.closest('a[href^="#"]');
		if (!link) { return; }
		var target = document.querySelector(link.getAttribute('href'));
		if (!target) { return; }
		event.preventDefault();
		target.scrollIntoView({ behavior: 'smooth', block: 'center' });
		window.setTimeout(function () { target.focus(); }, 350);
	});
})();
