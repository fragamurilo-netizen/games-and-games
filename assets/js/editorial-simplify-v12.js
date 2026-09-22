(function () {
	'use strict';

	if (!window.wp || !wp.data) return;

	var once = false;
	var movedAssignments = false;

	function el(tag, cls, text) {
		var node = document.createElement(tag);
		if (cls) node.className = cls;
		if (typeof text === 'string') node.textContent = text;
		return node;
	}

	function editor() {
		try { return wp.data.select('core/editor'); } catch (e) { return null; }
	}

	function editedCategories() {
		var store = editor();
		return store && store.getEditedPostAttribute ? (store.getEditedPostAttribute('categories') || []).map(Number) : [];
	}

	function categorySlug() {
		var ids = editedCategories();
		if (!ids.length) return '';
		try {
			var term = wp.data.select('core').getEntityRecord('taxonomy', 'category', ids[0]);
			return term && term.slug ? String(term.slug) : '';
		} catch (e) { return ''; }
	}

	function moveSupportLine(dock, matter) {
		var subtitle = dock.querySelector('.go-editor-commandbar__subtitle');
		var title = matter && matter.querySelector('.go-v6-matterbar__title');
		if (!subtitle || !title || title.contains(subtitle)) return;
		subtitle.classList.add('go-v12-support');
		var label = subtitle.querySelector(':scope > span');
		if (label) label.textContent = 'Linha de apoio';
		title.appendChild(subtitle);
	}

	function buildInsertMenu(dock) {
		if (dock.querySelector('[data-go-v12-insert]')) return;
		var shortcuts = dock.querySelector('[data-go-v6-shortcuts]');
		var actions = dock.querySelector('.go-editor-commandbar__actions');
		if (!shortcuts || !actions) return;

		var menu = el('details', 'go-v12-menu go-v12-menu--insert');
		menu.dataset.goV12Insert = '1';
		var summary = el('summary', '', 'Ferramentas');
		var pop = el('div', 'go-v12-menu__popover');
		menu.appendChild(summary);
		menu.appendChild(pop);
		pop.appendChild(shortcuts);
		actions.insertBefore(menu, actions.firstChild);

		shortcuts.addEventListener('click', function (event) {
			if (event.target.closest('button, a')) menu.open = false;
		});
	}

	function simplifyTop(dock) {
		var types = dock.querySelector('.go-editor-commandbar__types');
		if (types) types.setAttribute('aria-hidden', 'true');

		var open = dock.querySelector('.go-editor-commandbar__open');
		if (open) {
			open.innerHTML = '<span>Mais</span><span aria-hidden="true">•••</span>';
			open.setAttribute('title', 'Abrir ferramentas editoriais avançadas');
		}

		var smart = dock.querySelector('.go-editor-commandbar__smart-crop [data-go-smart-crop-label]');
		if (smart) smart.textContent = 'Capa 16:9';
		var preview = dock.querySelector('.go-editor-commandbar__preview span:last-child');
		if (preview) preview.textContent = 'Prévia';

		var x = dock.querySelector('.go-editor-commandbar__x');
		if (x) x.classList.add('go-v12-secondary-action');
	}

	function makeAdvanced(panel, matter) {
		if (!panel || panel.querySelector('[data-go-v12-advanced]')) return;

		var context = panel.querySelector('.go-arch__context');
		var foot = panel.querySelector('.go-arch__foot');
		if (!context || !foot) return;

		var fields = Array.prototype.slice.call(context.children);
		var platform = fields[0] || null;
		var service = fields[1] || null;
		var production = fields[2] || null;
		var entities = fields[3] || null;

		if (production) production.classList.add('go-v12-production-field');
		if (platform) platform.classList.add('go-v12-advanced-field');
		if (service) service.classList.add('go-v12-advanced-field');
		if (entities) entities.classList.add('go-v12-advanced-field');

		var details = el('details', 'go-v12-advanced');
		details.dataset.goV12Advanced = '1';
		var summary = el('summary', '', 'Mais opções');
		var body = el('div', 'go-v12-advanced__body');
		details.appendChild(summary);
		details.appendChild(body);

		if (platform) body.appendChild(platform);
		if (service) body.appendChild(service);
		if (entities) body.appendChild(entities);

		var creator = foot.querySelector('.go-arch-create');
		if (creator) body.appendChild(creator);

		var assignments = matter ? matter.querySelectorAll('.go-v6-assignment') : [];
		if (assignments.length && !movedAssignments) {
			var newsroom = el('div', 'go-v12-newsroom');
			newsroom.appendChild(el('span', 'go-v12-newsroom__label', 'Responsáveis'));
			Array.prototype.forEach.call(assignments, function (item) { newsroom.appendChild(item); });
			body.appendChild(newsroom);
			movedAssignments = true;
		}

		var gate = foot.querySelector('[data-go-arch-gate]');
		if (gate) body.appendChild(gate);

		foot.parentNode.insertBefore(details, foot);
		foot.hidden = true;
	}

	function simplifyClassification(panel) {
		if (!panel) return;
		var eyebrow = panel.querySelector('.go-arch__eyebrow');
		if (eyebrow) eyebrow.textContent = 'Classificação';
		var title = panel.querySelector('.go-arch__title strong');
		if (title) title.textContent = 'Onde esta matéria entra?';
		var help = panel.querySelector('.go-arch__title small');
		if (help) help.textContent = 'Categoria e tipo. O restante é opcional.';

		var primary = panel.querySelector('.go-arch__primary');
		if (primary) primary.classList.add('go-v12-primary');
		var context = panel.querySelector('.go-arch__context');
		if (context) context.classList.add('go-v12-context');
	}

	function syncContext(panel) {
		if (!panel) return;
		var slug = categorySlug();
		var production = panel.querySelector('.go-v12-production-field');
		var entertainment = [
			'entretenimento', 'series', 'filmes', 'producoes-turcas',
			'anime-e-manga', 'streaming', 'criticas'
		].indexOf(slug) !== -1;
		if (production) production.hidden = !entertainment;
		panel.classList.toggle('go-v12-is-entertainment', entertainment);
	}

	function simplifyMatter(matter) {
		if (!matter) return;
		matter.classList.add('go-v12-matterbar');
		var category = matter.querySelector('[data-go-v6-category] span');
		if (category) category.textContent = 'Categoria';
		var game = matter.querySelector('[data-go-v6-game] span');
		if (game) game.textContent = 'Game';
		var cover = matter.querySelector('[data-go-v6-cover] small');
		if (cover) cover.textContent = 'Capa';
	}

	function simplifySignals(dock) {
		var signals = dock.querySelector('.go-editor-commandbar__signals');
		if (!signals) return;
		Array.prototype.forEach.call(signals.querySelectorAll('.go-editor-signal'), function (item) {
			item.hidden = true;
		});
		var gate = signals.querySelector('[data-go-v6-gate]');
		if (gate) gate.classList.add('go-v12-gate');
	}

	function init() {
		var dock = document.getElementById('go-editor-commandbar');
		var matter = dock && dock.querySelector('[data-go-v6-matterbar]');
		var panel = dock && dock.querySelector('[data-go-v7-architecture]');
		if (!dock || !matter || !panel) return false;

		simplifyTop(dock);
		buildInsertMenu(dock);
		simplifyMatter(matter);
		moveSupportLine(dock, matter);
		simplifyClassification(panel);
		makeAdvanced(panel, matter);
		simplifySignals(dock);
		syncContext(panel);

		document.body.classList.add('go-editorial-simple-v12');
		once = true;
		return true;
	}

	function boot() {
		if (init()) return;
		[250, 650, 1200, 2200, 3600].forEach(function (ms) {
			window.setTimeout(init, ms);
		});
	}

	document.addEventListener('go:editorial-commandbar-ready', boot);
	if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
	else boot();

	var last = '';
	if (wp.data && wp.data.subscribe) {
		wp.data.subscribe(function () {
			if (!once) return;
			var next = editedCategories().join(',');
			if (next === last) return;
			last = next;
			window.requestAnimationFrame(function () {
				var panel = document.querySelector('[data-go-v7-architecture]');
				syncContext(panel);
			});
		});
	}
})();
