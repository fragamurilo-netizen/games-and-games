(function () {
	'use strict';

	var config = window.GoVergeEditorFields || {};
	var xConfig = window.GoVergeXEditor || {};
	var xSaveTimer = null;
	var typeConfig = config.editorialTypes || {};
	var observer = null;
	var scheduled = false;
	var dataUnsubscribe = null;
	var activeStage = 'content';
	var shellId = 'go-premium-editor';
	var dockId = 'go-editor-commandbar';
	var previewId = 'go-editor-preview-studio';
	var activePreviewMode = 'discover';
	var isSyncingSubtitle = false;
	var lastType = '';

	var stageConfig = {
		content: { label: 'Geral', description: 'Vínculos e dados essenciais da matéria.' },
		evaluation: { label: 'Avaliação', description: 'Nota, resumo, veredito e ficha técnica.' },
		interaction: { label: 'Interativos', description: 'Quiz, enquete, comparação, previsão e participação.' },
		publication: { label: 'Publicação', description: 'Checklist, correções e acabamento final.' }
	};

	var boxMap = {
		'go-verge-editorial-control': { stage: 'content', order: 5 },
		'go-verge-support-line': { stage: 'quickline', order: 6 },
		'go-verge-linked-game': { stage: 'content', order: 10 },
		'go-verge-semantic-annotation': { stage: 'content', order: 20 },
		'go-verge-review-fields': { stage: 'evaluation', order: 10 },
		'go-verge-critique-fields': { stage: 'evaluation', order: 10 },
		'go-verge-technical-sheet-fields': { stage: 'evaluation', order: 20 },
		'go-verge-technical-details-fields': { stage: 'evaluation', order: 30 },
		'go-verge-interactive-blocks': { stage: 'interaction', order: 10 },
		'go-verge-editorial-question': { stage: 'interaction', order: 20 },
		'go-live-updates': { stage: 'interaction', order: 30 },
		'go-verge-editorial-evidence': { stage: 'publication', order: 8 },
		'go-verge-publish-assistant': { stage: 'publication', order: 10 },
		'go-x-publishing': { stage: 'publication', order: 15 },
		'go-correction-note': { stage: 'publication', order: 20 }
	};

	var typeMeta = {
		news: { label: 'Notícia', code: 'N' },
		guide: { label: 'Guia', code: 'G' },
		review: { label: 'Review', code: 'R' },
		critique: { label: 'Crítica', code: 'C' },
		list: { label: 'Lista', code: 'L' },
		special: { label: 'Especial', code: 'E' },
		final: { label: 'Final explicado', code: 'F' },
		impressions: { label: 'Impressões', code: 'I' },
		offer: { label: 'Oferta', code: 'O' },
		buyingGuide: { label: 'Guia de compra', code: 'GC' },
		ranking: { label: 'Ranking', code: 'RK' }
	};

	function isGutenberg() {
		return !!document.querySelector('.interface-interface-skeleton, .edit-post-layout, .editor-editor-interface');
	}

	function normalizeIds(ids) {
		return (Array.isArray(ids) ? ids : []).map(Number).filter(function (id) { return id > 0; });
	}

	function availableTypes() {
		return Object.keys(typeMeta).filter(function (key) {
			return typeConfig[key] && normalizeIds(typeConfig[key].ids).length;
		});
	}

	function selectedContentTypeIds() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostAttribute) {
					var ids = editor.getEditedPostAttribute('go_content_type');
					if (Array.isArray(ids)) { return ids.map(Number).filter(Boolean); }
				}
			}
		} catch (error) {}
		return [];
	}

	function selectedCategoryIds() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostAttribute) {
					var ids = editor.getEditedPostAttribute('categories');
					if (Array.isArray(ids)) { return ids.map(Number).filter(Boolean); }
				}
			}
		} catch (error) {}
		return Array.prototype.slice.call(document.querySelectorAll('input[name="post_category[]"]:checked')).map(function (input) { return Number(input.value); }).filter(Boolean);
	}

	function currentType() {
		var selected = selectedContentTypeIds();
		var keys = availableTypes();
		for (var i = 0; i < keys.length; i += 1) {
			var key = keys[i];
			var ids = normalizeIds(typeConfig[key].ids);
			if (ids.some(function (id) { return selected.indexOf(id) !== -1; })) { return key; }
		}
		return keys.indexOf('news') !== -1 ? 'news' : (keys[0] || 'news');
	}

	function setContentTypes(next) {
		next = normalizeIds(next).filter(function (id, index, list) { return list.indexOf(id) === index; });
		try {
			if (window.wp && wp.data && wp.data.dispatch) {
				var dispatch = wp.data.dispatch('core/editor');
				if (dispatch && dispatch.editPost) { dispatch.editPost({ go_content_type: next }); }
			}
		} catch (error) {}
		window.dispatchEvent(new CustomEvent('go:v10-tax-change'));
	}

	function chooseType(key, source) {
		if (!typeConfig[key]) { return; }
		var targetIds = normalizeIds(typeConfig[key].ids);
		if (!targetIds.length) { return; }
		/* Formato is independent from category: never touch categories here. */
		setContentTypes([targetIds[0]]);
		document.body.dataset.goEditorialType = key;
		lastType = key;
		activeStage = (key === 'review' || key === 'critique') ? 'evaluation' : 'content';
		window.setTimeout(syncAll, 40);
		window.setTimeout(function () {
			syncAll();
			setStage(activeStage, false);
			if ((key === 'review' || key === 'critique') && source === 'dock') { openWorkspace(activeStage); }
		}, 180);
	}

	function createEl(tag, className, text) {
		var el = document.createElement(tag);
		if (className) { el.className = className; }
		if (typeof text === 'string') { el.textContent = text; }
		return el;
	}

	function workspaceTarget() {
		var direct = document.querySelector('.edit-post-layout__metaboxes .edit-post-meta-boxes-area, .edit-post-meta-boxes-area, .editor-post-meta-boxes-area');
		if (direct) { return direct; }
		var anchor = document.getElementById('go-verge-support-line') || document.getElementById('go-verge-review-fields') || document.getElementById('go-verge-linked-game');
		if (anchor) {
			return anchor.closest('.edit-post-meta-boxes-area, .edit-post-layout__metaboxes, #poststuff, form') || anchor.parentElement;
		}
		if (!isGutenberg()) { return document.getElementById('poststuff') || document.getElementById('post-body-content'); }
		return null;
	}

	function mainEditorTarget() {
		if (!isGutenberg()) {
			var title = document.getElementById('titlediv');
			return title && title.parentElement ? { parent: title.parentElement, before: title.nextSibling } : null;
		}
		var candidates = [
			'.edit-post-layout__content .edit-post-visual-editor',
			'.editor-editor-interface__content .editor-visual-editor',
			'.interface-interface-skeleton__content .edit-post-visual-editor',
			'.interface-interface-skeleton__content .editor-visual-editor',
			'.edit-post-visual-editor',
			'.editor-visual-editor'
		];
		for (var i = 0; i < candidates.length; i += 1) {
			var node = document.querySelector(candidates[i]);
			if (node && !node.closest('.interface-interface-skeleton__sidebar')) {
				return { parent: node.parentElement, before: node };
			}
		}
		return null;
	}

	function postStatusLabel() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				var status = editor && editor.getEditedPostAttribute ? editor.getEditedPostAttribute('status') : '';
				var map = { publish: 'Publicado', future: 'Agendado', pending: 'Pendente', private: 'Privado', draft: 'Rascunho', auto_draft: 'Novo rascunho' };
				return map[status] || 'Em edição';
			}
		} catch (error) {}
		var statusSelect = document.getElementById('post_status');
		return statusSelect && statusSelect.options[statusSelect.selectedIndex] ? statusSelect.options[statusSelect.selectedIndex].text : 'Em edição';
	}

	function postContent() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostContent) { return editor.getEditedPostContent() || ''; }
			}
		} catch (error) {}
		var classic = document.getElementById('content');
		return classic ? classic.value : '';
	}

	function wordCount() {
		var text = postContent().replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
		return text ? text.split(' ').filter(Boolean).length : 0;
	}

	function supportLineValue() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				var meta = editor && editor.getEditedPostAttribute ? (editor.getEditedPostAttribute('meta') || {}) : {};
				if (typeof meta._go_post_subtitle === 'string') { return meta._go_post_subtitle; }
			}
		} catch (error) {}
		var field = document.getElementById('go-verge-support-line-field');
		return field ? field.value : '';
	}

	function setSupportLineValue(value, source) {
		if (isSyncingSubtitle) { return; }
		isSyncingSubtitle = true;
		try {
			if (window.wp && wp.data && wp.data.select && wp.data.dispatch) {
				var editor = wp.data.select('core/editor');
				var dispatch = wp.data.dispatch('core/editor');
				var meta = editor && editor.getEditedPostAttribute ? (editor.getEditedPostAttribute('meta') || {}) : {};
				if (dispatch && dispatch.editPost) {
					dispatch.editPost({ meta: Object.assign({}, meta, { _go_post_subtitle: value }) });
				}
			}
		} catch (error) {}
		var field = document.getElementById('go-verge-support-line-field');
		if (field && field.value !== value) {
			field.value = value;
			field.dispatchEvent(new Event('input', { bubbles: true }));
			field.dispatchEvent(new Event('change', { bubbles: true }));
		}
		document.querySelectorAll('[data-go-subtitle-input]').forEach(function (input) {
			if (input !== source && input.value !== value) { input.value = value; }
		});
		document.dispatchEvent(new CustomEvent('go:editorial-support-sync', { detail: { value: value } }));
		isSyncingSubtitle = false;
		updateSignals();
	}

	function hasFeaturedImage() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				return !!(editor && editor.getEditedPostAttribute && Number(editor.getEditedPostAttribute('featured_media')));
			}
		} catch (error) {}
		return !!document.querySelector('#postimagediv img, #set-post-thumbnail img');
	}

	function hasLink() { return /<a\s+[^>]*href=/i.test(postContent()); }

	function plainText(value) {
		var holder = document.createElement('div');
		holder.innerHTML = String(value || '');
		return String(holder.textContent || holder.innerText || '').replace(/\s+/g, ' ').trim();
	}

	function editedPostAttribute(attribute, fallback) {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostAttribute) {
					var value = editor.getEditedPostAttribute(attribute);
					if (value !== undefined && value !== null && value !== '') { return value; }
				}
			}
		} catch (error) {}
		return fallback;
	}

	function previewTitle() {
		var value = editedPostAttribute('title', '');
		if (value && typeof value === 'object') { value = value.raw || value.rendered || ''; }
		return plainText(value) || 'Título da matéria';
	}

	function previewDescription() {
		var meta = editedPostAttribute('meta', {}) || {};
		var candidates = [
			supportLineValue(),
			editedPostAttribute('excerpt', ''),
			meta.rank_math_description,
			meta._yoast_wpseo_metadesc
		];
		for (var index = 0; index < candidates.length; index += 1) {
			var value = plainText(candidates[index]);
			if (value) { return value; }
		}
		var content = plainText(postContent());
		return content ? content.slice(0, 180) : 'A descrição será montada com a linha de apoio ou com o início da matéria.';
	}

	function previewSeoTitle() {
		var meta = editedPostAttribute('meta', {}) || {};
		var candidates = [meta.rank_math_title, meta._yoast_wpseo_title];
		for (var index = 0; index < candidates.length; index += 1) {
			var value = plainText(candidates[index]);
			if (value) { return value; }
		}
		return previewTitle();
	}

	function previewSearchDescription() {
		var meta = editedPostAttribute('meta', {}) || {};
		var candidates = [meta.rank_math_description, meta._yoast_wpseo_metadesc, supportLineValue(), editedPostAttribute('excerpt', '')];
		for (var index = 0; index < candidates.length; index += 1) {
			var value = plainText(candidates[index]);
			if (value) { return value; }
		}
		return previewDescription();
	}

	function previewCategory() {
		var selected = selectedCategoryIds();
		var m = editedPostAttribute('meta', {}) || {};
		var requested = Number(m._go_primary_category_id || 0);
		var primary = requested && selected.indexOf(requested) !== -1 ? requested : (selected[0] || 0);
		if (!primary) { return 'Sem categoria'; }
		try {
			var core = window.wp && wp.data && wp.data.select ? wp.data.select('core') : null;
			var record = core && core.getEntityRecord ? core.getEntityRecord('taxonomy', 'category', primary) : null;
			if (record && record.name) { return plainText(record.name); }
		} catch (error) {}
		return 'Categoria';
	}

	function previewIntro() {
		var content = plainText(postContent());
		if (!content) { return 'O início do texto da matéria aparecerá aqui conforme o conteúdo for escrito.'; }
		return content;
	}

	function previewData() {
		var title = previewTitle();
		var description = previewDescription();
		var searchTitle = previewSeoTitle();
		var searchDescription = previewSearchDescription();
		var body = previewIntro();
		var category = previewCategory();
		return {
			title: title,
			description: description,
			searchTitle: searchTitle,
			searchDescription: searchDescription,
			url: previewUrl(),
			displayUrl: previewUrl().replace(/^https?:\/\//, '').replace(/\/$/, ''),
			image: previewFeaturedImage(),
			author: previewAuthor(),
			category: category,
			reading: Math.max(1, Math.ceil(wordCount() / 220)) + ' min de leitura',
			body: body,
			titleLength: title.length,
			descriptionLength: description.length,
			searchTitleLength: searchTitle.length,
			searchDescriptionLength: searchDescription.length
		};
	}

	function buildTypeButton(key, compact, source) {
		var meta = typeMeta[key];
		var button = createEl('button', compact ? 'go-editor-type-chip' : 'go-workspace-type');
		button.type = 'button';
		button.dataset.goType = key;
		button.setAttribute('aria-pressed', 'false');
		button.innerHTML = compact
			? '<span class="go-editor-type-chip__code">' + meta.code + '</span><span>' + meta.label + '</span>'
			: '<span class="go-workspace-type__code">' + meta.code + '</span><span class="go-workspace-type__label">' + meta.label + '</span><span class="go-workspace-type__check" aria-hidden="true">✓</span>';
		button.addEventListener('click', function () { chooseType(key, source); });
		return button;
	}

	function buildSignal(label, key) {
		var item = createEl('span', 'go-editor-signal');
		item.dataset.goSignal = key;
		item.innerHTML = '<span class="go-editor-signal__dot" aria-hidden="true"></span><span>' + label + '</span>';
		return item;
	}


	var commandbarStorageKey = 'go-overdrive-editor-commandbar-layout-v2';

	function commandbarDefaultState() {
		return { mode: 'dock', collapsed: false, x: null, y: null, width: null, height: null };
	}

	function readCommandbarState() {
		var state = commandbarDefaultState();
		try {
			var saved = JSON.parse(window.localStorage.getItem(commandbarStorageKey) || '{}');
			if (saved && typeof saved === 'object') { state = Object.assign(state, saved); }
		} catch (error) {}
		if (['dock', 'float'].indexOf(state.mode) === -1) { state.mode = 'dock'; }
		state.collapsed = !!state.collapsed;
		/* V30: discard legacy persisted heights. Content changes used to be
		 * mistaken for user resizes, eventually making the panel escape the
		 * viewport. Width remains user-controlled; height is content-driven. */
		state.height = null;
		return state;
	}

	function writeCommandbarState(state) {
		try { window.localStorage.setItem(commandbarStorageKey, JSON.stringify(state)); } catch (error) {}
	}

	function clampCommandbarPosition(state, dock) {
		if (!dock || state.mode !== 'float') { return state; }
		var width = Number(state.width) || dock.offsetWidth || 720;
		var height = Math.min(dock.offsetHeight || 120, Math.max(120, window.innerHeight - 16));
		var maxX = Math.max(8, window.innerWidth - Math.min(width, window.innerWidth - 16) - 8);
		var maxY = Math.max(8, window.innerHeight - Math.min(height, window.innerHeight - 16) - 8);
		state.x = Math.min(Math.max(8, Number(state.x) || Math.max(16, window.innerWidth - width - 28)), maxX);
		state.y = Math.min(Math.max(8, Number(state.y) || 76), maxY);
		return state;
	}

	function applyCommandbarState(dock, state) {
		if (!dock) { return; }
		dock.classList.toggle('is-collapsed', !!state.collapsed);
		dock.classList.toggle('is-floating', state.mode === 'float');
		dock.dataset.goCommandbarMode = state.mode;

		if (state.mode === 'float') {
			state = clampCommandbarPosition(state, dock);
			dock.style.left = Math.round(state.x) + 'px';
			dock.style.top = Math.round(state.y) + 'px';
			dock.style.width = state.width ? Math.round(state.width) + 'px' : '';
			dock.style.height = ''; // V30: never lock a content-driven height.
		} else {
			dock.style.left = '';
			dock.style.top = '';
			dock.style.width = '';
			dock.style.height = '';
		}

		var collapse = dock.querySelector('[data-go-commandbar-collapse]');
		if (collapse) {
			collapse.setAttribute('aria-pressed', state.collapsed ? 'true' : 'false');
			collapse.setAttribute('title', state.collapsed ? 'Expandir painel editorial' : 'Minimizar painel editorial');
			collapse.querySelector('[data-go-layout-label]').textContent = state.collapsed ? 'Expandir' : 'Minimizar';
			collapse.querySelector('[data-go-layout-icon]').textContent = state.collapsed ? '▢' : '—';
		}
		var floatButton = dock.querySelector('[data-go-commandbar-float]');
		if (floatButton) {
			var floating = state.mode === 'float';
			floatButton.setAttribute('aria-pressed', floating ? 'true' : 'false');
			floatButton.setAttribute('title', floating ? 'Encaixar painel acima do editor' : 'Destacar painel para mover e redimensionar');
			floatButton.querySelector('[data-go-layout-label]').textContent = floating ? 'Encaixar' : 'Destacar';
			floatButton.querySelector('[data-go-layout-icon]').textContent = floating ? '↙' : '↗';
		}
		var drag = dock.querySelector('[data-go-commandbar-drag]');
		if (drag) {
			drag.disabled = state.mode !== 'float';
			drag.setAttribute('aria-label', state.mode === 'float' ? 'Arrastar painel editorial' : 'Destaque o painel para arrastar');
		}
	}

	function bindCommandbarLayout(dock) {
		if (!dock || dock.dataset.goCommandbarLayoutBound === '1') { return; }
		dock.dataset.goCommandbarLayoutBound = '1';
		var state = readCommandbarState();
		applyCommandbarState(dock, state);

		var collapse = dock.querySelector('[data-go-commandbar-collapse]');
		if (collapse) {
			collapse.addEventListener('click', function () {
				state.collapsed = !state.collapsed;
				if (state.collapsed) { state.height = null; }
				applyCommandbarState(dock, state);
				writeCommandbarState(state);
			});
		}

		var floatButton = dock.querySelector('[data-go-commandbar-float]');
		if (floatButton) {
			floatButton.addEventListener('click', function () {
				var rect = dock.getBoundingClientRect();
				if (state.mode === 'float') {
					state.mode = 'dock';
					state.height = null;
				} else {
					state.mode = 'float';
					state.width = Math.max(420, Math.min(rect.width, 880));
					state.x = Math.max(12, Math.min(rect.left, window.innerWidth - state.width - 12));
					state.y = Math.max(70, Math.min(rect.top, window.innerHeight - 90));
				}
				applyCommandbarState(dock, state);
				writeCommandbarState(state);
			});
		}

		var drag = dock.querySelector('[data-go-commandbar-drag]');
		if (drag) {
			drag.addEventListener('pointerdown', function (event) {
				if (state.mode !== 'float' || event.button !== 0) { return; }
				event.preventDefault();
				var rect = dock.getBoundingClientRect();
				var offsetX = event.clientX - rect.left;
				var offsetY = event.clientY - rect.top;
				dock.classList.add('is-dragging');
				try { drag.setPointerCapture(event.pointerId); } catch (error) {}
				function move(moveEvent) {
					var width = dock.offsetWidth;
					var height = dock.offsetHeight;
					state.x = Math.max(8, Math.min(moveEvent.clientX - offsetX, window.innerWidth - width - 8));
					state.y = Math.max(8, Math.min(moveEvent.clientY - offsetY, window.innerHeight - height - 8));
					dock.style.left = Math.round(state.x) + 'px';
					dock.style.top = Math.round(state.y) + 'px';
				}
				function up(upEvent) {
					dock.classList.remove('is-dragging');
					drag.removeEventListener('pointermove', move);
					drag.removeEventListener('pointerup', up);
					drag.removeEventListener('pointercancel', up);
					try { drag.releasePointerCapture(upEvent.pointerId); } catch (error) {}
					writeCommandbarState(state);
				}
				drag.addEventListener('pointermove', move);
				drag.addEventListener('pointerup', up);
				drag.addEventListener('pointercancel', up);
			});
			drag.addEventListener('dblclick', function () {
				if (state.mode !== 'float') { return; }
				state.x = Math.max(16, window.innerWidth - (Number(state.width) || dock.offsetWidth || 720) - 28);
				state.y = 76;
				applyCommandbarState(dock, state);
				writeCommandbarState(state);
			});
		}

		if (window.ResizeObserver) {
			var resizeTimer = 0;
			var resizeObserver = new ResizeObserver(function () {
				if (state.mode !== 'float' || dock.classList.contains('is-dragging')) { return; }
				window.clearTimeout(resizeTimer);
				resizeTimer = window.setTimeout(function () {
					/* Only width is a persistent user preference. Height can change as
					 * editorial sections open/close and must never be frozen. */
					state.width = dock.offsetWidth;
					state.height = null;
					state = clampCommandbarPosition(state, dock);
					writeCommandbarState(state);
				}, 180);
			});
			resizeObserver.observe(dock);
		}

		window.addEventListener('resize', function () {
			if (state.mode !== 'float') { return; }
			state = clampCommandbarPosition(state, dock);
			applyCommandbarState(dock, state);
			writeCommandbarState(state);
		});

		/* Always provide a keyboard escape hatch. This mirrors the Gutenberg
		 * convention that floating/dialog-like UI must remain dismissible even
		 * when its content or viewport changes. */
		document.addEventListener('keydown', function (event) {
			if (event.key !== 'Escape' || state.mode !== 'float') { return; }
			state.mode = 'dock';
			state.height = null;
			applyCommandbarState(dock, state);
			writeCommandbarState(state);
		});
	}

	function buildDock() {
		var existing = document.getElementById(dockId);
		if (existing) { return existing; }
		var target = mainEditorTarget();
		if (!target || !target.parent) { return null; }

		var dock = createEl('section', 'go-editor-commandbar');
		dock.id = dockId;
		dock.setAttribute('aria-label', 'Ferramentas editoriais Overdrive');

		var top = createEl('div', 'go-editor-commandbar__top');
		var brand = createEl('div', 'go-editor-commandbar__brand');
		brand.innerHTML = '<span class="go-editor-commandbar__mark" aria-hidden="true">OD</span><div><strong>Publicação</strong><small><span data-go-current-type-label>Notícia</span> · edição</small></div>';
		var dragHandle = createEl('button', 'go-editor-commandbar__drag');
		dragHandle.type = 'button';
		dragHandle.setAttribute('data-go-commandbar-drag', '');
		dragHandle.setAttribute('title', 'Destaque o painel para arrastar');
		dragHandle.innerHTML = '<span aria-hidden="true">⠿</span>';
		brand.insertBefore(dragHandle, brand.firstChild);
		var types = createEl('div', 'go-editor-commandbar__types');
		types.setAttribute('aria-label', 'Formato editorial');
		var typesLabel = createEl('span', 'go-editor-commandbar__types-label', 'Formato');
		types.appendChild(typesLabel);
		availableTypes().forEach(function (key) { types.appendChild(buildTypeButton(key, true, 'dock')); });
		var open = createEl('button', 'go-editor-commandbar__open');
		open.type = 'button';
		open.innerHTML = '<span>Mais campos</span><span aria-hidden="true">›</span>';
		open.setAttribute('title', 'Abrir todos os campos editoriais');
		open.addEventListener('click', function () { openWorkspace(activeStage); });
		var actions = createEl('div', 'go-editor-commandbar__actions');
		var layoutActions = createEl('div', 'go-editor-commandbar__layout-actions');
		var collapseButton = createEl('button', 'go-editor-commandbar__layout-button');
		collapseButton.type = 'button';
		collapseButton.setAttribute('data-go-commandbar-collapse', '');
		collapseButton.innerHTML = '<span data-go-layout-icon aria-hidden="true">—</span><span data-go-layout-label>Minimizar</span>';
		collapseButton.setAttribute('aria-label','Minimizar painel editorial');
		var floatButton = createEl('button', 'go-editor-commandbar__layout-button');
		floatButton.type = 'button';
		floatButton.setAttribute('data-go-commandbar-float', '');
		floatButton.innerHTML = '<span data-go-layout-icon aria-hidden="true">✥</span><span data-go-layout-label>Mover</span>';
		floatButton.setAttribute('aria-label','Destacar painel para mover ou redimensionar');
		layoutActions.appendChild(collapseButton);
		layoutActions.appendChild(floatButton);
		var smartCrop = createEl('button', 'go-editor-commandbar__smart-crop');
		smartCrop.type = 'button';
		smartCrop.setAttribute('data-go-smart-crop-all', '');
		smartCrop.setAttribute('title', 'Ajustar todas as fotos do conteúdo para 16:9 com enquadramento automático');
		smartCrop.innerHTML = '<span class="go-editor-commandbar__smart-crop-icon" aria-hidden="true">▣</span><span data-go-smart-crop-label>Fotos 16:9</span>';
		var preview = createEl('button', 'go-editor-commandbar__preview');
		preview.type = 'button';
		preview.innerHTML = '<span aria-hidden="true">◫</span><span>Prévia</span>';
		preview.setAttribute('title','Ver como a matéria pode aparecer no site, Discover e Busca');
		preview.addEventListener('click', function () { openPreviewStudio(activePreviewMode); });
		top.appendChild(brand);
		top.appendChild(types);
		actions.appendChild(preview);
		actions.appendChild(smartCrop);
		if (Number(xConfig.postId || 0) > 0) {
			var xQuick = createEl('button', 'go-editor-commandbar__x');
			xQuick.type = 'button';
			xQuick.innerHTML = '<span aria-hidden="true">X</span><span>Publicar no X</span>';
			xQuick.addEventListener('click', function () {
				openWorkspace('publication');
				window.setTimeout(function () {
					var panel = document.getElementById('go-x-workspace-action');
					if (panel) { panel.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
					var button = panel && panel.querySelector('[data-go-x-send]');
					if (button && !button.disabled) { button.focus(); }
				}, 80);
			});
			actions.appendChild(xQuick);
		}
		actions.appendChild(open);
		actions.appendChild(layoutActions);
		top.appendChild(actions);

		var lower = createEl('div', 'go-editor-commandbar__lower');
		var subtitle = createEl('label', 'go-editor-commandbar__subtitle');
		subtitle.innerHTML = '<span><strong>Linha de apoio</strong><small>Texto abaixo do título</small></span><textarea rows="1" maxlength="320" data-go-subtitle-input placeholder="Explique a notícia em uma frase clara e informativa"></textarea>';
		var subtitleInput = subtitle.querySelector('textarea');
		subtitleInput.value = supportLineValue();
		subtitleInput.addEventListener('input', function () { setSupportLineValue(subtitleInput.value, subtitleInput); });
		var signals = createEl('div', 'go-editor-commandbar__signals');
		signals.appendChild(buildSignal('Apoio', 'subtitle'));
		signals.appendChild(buildSignal('Capa', 'image'));
		signals.appendChild(buildSignal('Categoria', 'category'));
		signals.appendChild(buildSignal('Link interno', 'link'));
		lower.appendChild(subtitle);
		lower.appendChild(signals);

		dock.appendChild(top);
		dock.appendChild(lower);
		target.parent.insertBefore(dock, target.before || null);
		bindCommandbarLayout(dock);

		/* The crop runtime may load before or after this custom command bar.
		 * Re-bind explicitly when available so the action never depends on timing. */
		if (typeof window.GoVergeBindBulkSmartCropControls === 'function') {
			window.GoVergeBindBulkSmartCropControls();
		}
		document.dispatchEvent(new CustomEvent('go:editorial-commandbar-ready'));
		return dock;
	}

	function shorten(value, limit) {
		value = String(value || '').trim();
		if (value.length <= limit) { return value; }
		return value.slice(0, Math.max(0, limit - 1)).replace(/\s+\S*$/, '') + '…';
	}

	function previewTemplate(mode) {
		if (mode === 'discover') {
			return '<div class="go-preview-device go-preview-device--discover">' +
				'<div class="go-preview-device__status"><span>9:41</span><span>● ● ●</span></div>' +
				'<div class="go-preview-discover__brand">Google <span>Discover</span></div>' +
				'<article class="go-preview-discover__card"><div class="go-preview-media"><img data-go-preview-image hidden><span data-go-preview-placeholder>Imagem destacada 16:9</span></div>' +
				'<div class="go-preview-discover__copy"><div class="go-preview-discover__eyebrow"><span data-go-preview-category></span><span>·</span><span>Overdrive</span></div><h2 data-go-preview-title></h2>' +
				'<div class="go-preview-discover__meta"><span class="go-preview-source-dot">OD</span><span>Overdrive</span><span>·</span><span data-go-preview-reading></span></div></div></article>' +
				'<p class="go-preview-note" data-go-preview-editorial-warning></p></div>';
		}
		if (mode === 'mobile') {
			return '<div class="go-preview-device go-preview-device--mobile">' +
				'<div class="go-preview-device__status"><span>9:41</span><span>● ● ●</span></div>' +
				'<header class="go-preview-sitebar"><strong>OVERDRIVE</strong><span>☰</span></header>' +
				'<article class="go-preview-article go-preview-article--mobile"><div class="go-preview-breadcrumb"><span>Home</span><span>›</span><span data-go-preview-category></span></div><h1 data-go-preview-title></h1><p class="go-preview-deck" data-go-preview-description></p>' +
				'<div class="go-preview-byline">Por <strong data-go-preview-author></strong> · <span data-go-preview-reading></span></div>' +
				'<div class="go-preview-media"><img data-go-preview-image hidden><span data-go-preview-placeholder>Imagem destacada</span></div><p data-go-preview-body></p></article></div>';
		}
		if (mode === 'desktop') {
			return '<div class="go-preview-browser"><div class="go-preview-browser__chrome"><span></span><span></span><span></span><div data-go-preview-url></div></div>' +
				'<div class="go-preview-browser__shell"><header class="go-preview-desktop__sitebar"><strong>OVERDRIVE</strong><nav>Games&nbsp;&nbsp;Entretenimento&nbsp;&nbsp;Tecnologia&nbsp;&nbsp;Promoções</nav></header>' +
				'<article class="go-preview-article go-preview-article--desktop"><div class="go-preview-breadcrumb"><span>Home</span><span>›</span><span data-go-preview-category></span></div><h1 data-go-preview-title></h1><p class="go-preview-deck" data-go-preview-description></p>' +
				'<div class="go-preview-byline">Por <strong data-go-preview-author></strong> · <span data-go-preview-reading></span></div>' +
				'<div class="go-preview-media"><img data-go-preview-image hidden><span data-go-preview-placeholder>Imagem destacada 16:9</span></div><p data-go-preview-body></p></article></div></div>';
		}
		if (mode === 'x') {
			return '<div class="go-preview-social go-preview-social--x"><div class="go-preview-social__composer"><span class="go-preview-source-dot">OD</span><div><strong>Overdrive</strong><small>@overdrive · agora</small></div></div>' +
				'<p data-go-preview-description></p><article class="go-preview-social__card"><div class="go-preview-media"><img data-go-preview-image hidden><span data-go-preview-placeholder>Imagem 16:9</span></div>' +
				'<div class="go-preview-social__copy"><span>OVERDRIVE.COM.BR</span><h2 data-go-preview-title></h2><p data-go-preview-description></p></div></article>' +
				'<p class="go-preview-note" data-go-preview-editorial-warning></p></div>';
		}
		if (mode === 'whatsapp') {
			return '<div class="go-preview-social go-preview-social--whatsapp"><div class="go-preview-social__composer"><span class="go-preview-source-dot">WA</span><div><strong>WhatsApp</strong><small>Prévia do link</small></div></div>' +
				'<article class="go-preview-social__card"><div class="go-preview-media"><img data-go-preview-image hidden><span data-go-preview-placeholder>Imagem 16:9</span></div>' +
				'<div class="go-preview-social__copy"><span>OVERDRIVE.COM.BR</span><h2 data-go-preview-title></h2><p data-go-preview-description></p></div></article>' +
				'<p class="go-preview-note" data-go-preview-editorial-warning></p></div>';
		}
		return '<div class="go-preview-google"><div class="go-preview-google__search"><span>🔍</span><span data-go-preview-query></span><span>×</span></div>' +
			'<div class="go-preview-google__meta"><span class="go-preview-source-dot">OD</span><div><strong>Overdrive</strong><span data-go-preview-url></span></div><span>⋮</span></div>' +
			'<h2 data-go-preview-search-title></h2><p data-go-preview-search-description></p>' +
			'<div class="go-preview-google__checks"><span data-go-preview-search-title-state>Título: <strong data-go-preview-search-title-count></strong></span><span data-go-preview-search-description-state>Descrição: <strong data-go-preview-search-description-count></strong></span></div>' +
			'<p class="go-preview-note">Simulação do resultado de busca. O Google pode reescrever o snippet, mas o preview usa o SEO title/meta quando existirem.</p></div>';
	}

	function setPreviewText(root, selector, value) {
		root.querySelectorAll(selector).forEach(function (node) { node.textContent = value; });
	}

	function setPreviewImages(root, data) {
		root.querySelectorAll('[data-go-preview-image]').forEach(function (image) {
			var placeholder = image.parentElement ? image.parentElement.querySelector('[data-go-preview-placeholder]') : null;
			if (data.image) {
				image.src = data.image;
				image.alt = data.title;
				image.hidden = false;
				if (placeholder) { placeholder.hidden = true; }
			} else {
				image.removeAttribute('src');
				image.hidden = true;
				if (placeholder) { placeholder.hidden = false; }
			}
		});
	}

	function renderPreviewStudio() {
		var studio = document.getElementById(previewId);
		if (!studio || studio.hidden) { return; }
		var stage = studio.querySelector('[data-go-preview-stage]');
		if (!stage) { return; }
		var data = previewData();
		stage.dataset.mode = activePreviewMode;
		stage.innerHTML = previewTemplate(activePreviewMode);
		setPreviewText(stage, '[data-go-preview-title]', data.title);
		setPreviewText(stage, '[data-go-preview-search-title]', shorten(data.searchTitle, 65));
		setPreviewText(stage, '[data-go-preview-description]', data.description);
		setPreviewText(stage, '[data-go-preview-search-description]', shorten(data.searchDescription, 160));
		setPreviewText(stage, '[data-go-preview-url]', data.displayUrl);
		setPreviewText(stage, '[data-go-preview-query]', shorten(data.searchTitle || data.title, 52));
		setPreviewText(stage, '[data-go-preview-author]', data.author);
		setPreviewText(stage, '[data-go-preview-category]', data.category);
		setPreviewText(stage, '[data-go-preview-reading]', data.reading);
		setPreviewText(stage, '[data-go-preview-body]', shorten(data.body, activePreviewMode === 'desktop' ? 620 : 360));
		setPreviewText(stage, '[data-go-preview-title-count]', data.titleLength + ' caracteres');
		setPreviewText(stage, '[data-go-preview-description-count]', data.descriptionLength + ' caracteres');
		setPreviewText(stage, '[data-go-preview-search-title-count]', data.searchTitleLength + ' caracteres');
		setPreviewText(stage, '[data-go-preview-search-description-count]', data.searchDescriptionLength + ' caracteres');
		var warnings = [];
		if (data.titleLength > 75) { warnings.push('Título editorial longo demais para hero e Discover.'); }
		else if (data.titleLength && data.titleLength < 32) { warnings.push('Título curto; pode perder força no card.'); }
		if (data.descriptionLength && data.descriptionLength < 65) { warnings.push('Linha de apoio curta; dê mais contexto.'); }
		if (/^(saiba mais|veja|confira|entenda|descubra)(\s|:|$)/i.test(String(data.description || '').trim())) { warnings.push('Linha de apoio genérica; entregue informação concreta.'); }
		setPreviewText(stage, '[data-go-preview-editorial-warning]', warnings.length ? warnings.join(' ') : 'Preview em boa faixa para mobile, desktop e Discover.');
		setPreviewImages(stage, data);
		var titleState = stage.querySelector('[data-go-preview-search-title-state]');
		if (titleState) {
			titleState.classList.remove('is-good', 'is-warn');
			titleState.classList.add(data.searchTitleLength >= 30 && data.searchTitleLength <= 65 ? 'is-good' : 'is-warn');
		}
		var descriptionState = stage.querySelector('[data-go-preview-search-description-state]');
		if (descriptionState) {
			descriptionState.classList.remove('is-good', 'is-warn');
			descriptionState.classList.add(data.searchDescriptionLength >= 80 && data.searchDescriptionLength <= 165 ? 'is-good' : 'is-warn');
		}
		studio.querySelectorAll('[data-go-preview-mode]').forEach(function (button) {
			var active = button.dataset.goPreviewMode === activePreviewMode;
			button.classList.toggle('is-active', active);
			button.setAttribute('aria-selected', active ? 'true' : 'false');
		});
	}

	function buildPreviewStudio() {
		var existing = document.getElementById(previewId);
		if (existing) { return existing; }
		var studio = createEl('section', 'go-preview-studio');
		studio.id = previewId;
		studio.hidden = true;
		studio.setAttribute('role', 'dialog');
		studio.setAttribute('aria-modal', 'true');
		studio.setAttribute('aria-label', 'Prévia da matéria');
		studio.innerHTML = '<div class="go-preview-studio__dialog">' +
			'<header class="go-preview-studio__header"><div><strong>Prévia da matéria</strong><span>Mobile, desktop, Discover e Search em tempo real</span></div><button type="button" data-go-preview-close aria-label="Fechar prévia">×</button></header>' +
			'<nav class="go-preview-studio__tabs" role="tablist" aria-label="Formatos de prévia">' +
				'<button type="button" role="tab" data-go-preview-mode="discover">Discover</button>' +
				'<button type="button" role="tab" data-go-preview-mode="x">Prévia no X</button>' +
				'<button type="button" role="tab" data-go-preview-mode="whatsapp">WhatsApp</button>' +
				'<button type="button" role="tab" data-go-preview-mode="google">Search</button>' +
				'<button type="button" role="tab" data-go-preview-mode="mobile">Mobile</button>' +
				'<button type="button" role="tab" data-go-preview-mode="desktop">Desktop</button>' +
			'</nav><main class="go-preview-studio__stage" data-go-preview-stage></main></div>';
		studio.querySelector('[data-go-preview-close]').addEventListener('click', closePreviewStudio);
		studio.querySelectorAll('[data-go-preview-mode]').forEach(function (button) {
			button.addEventListener('click', function () {
				activePreviewMode = button.dataset.goPreviewMode || 'google';
				renderPreviewStudio();
			});
		});
		studio.addEventListener('click', function (event) {
			if (event.target === studio) { closePreviewStudio(); }
		});
		document.body.appendChild(studio);
		return studio;
	}

	function openPreviewStudio(mode) {
		var studio = buildPreviewStudio();
		if (!studio) { return; }
		if (mode) { activePreviewMode = mode; }
		if (document.body.classList.contains('go-editorial-workspace-open')) { closeWorkspace(); }
		studio.hidden = false;
		studio.classList.add('is-open');
		document.body.classList.add('go-preview-studio-open');
		renderPreviewStudio();
		window.setTimeout(function () {
			var close = studio.querySelector('[data-go-preview-close]');
			if (close) { close.focus(); }
		}, 30);
	}

	function closePreviewStudio() {
		var studio = document.getElementById(previewId);
		if (!studio) { return; }
		studio.classList.remove('is-open');
		studio.hidden = true;
		document.body.classList.remove('go-preview-studio-open');
		var opener = document.querySelector('.go-editor-commandbar__preview');
		if (opener) { opener.focus(); }
	}

	function buildShell() {
		var existing = document.getElementById(shellId);
		if (existing) { return existing; }
		var target = workspaceTarget();
		if (!target) { return null; }

		var shell = createEl('section', 'go-premium-editor');
		shell.id = shellId;
		shell.setAttribute('aria-label', 'Workspace editorial Overdrive');
		shell.setAttribute('aria-hidden', 'true');

		var header = createEl('header', 'go-premium-editor__header');
		header.innerHTML =
			'<div class="go-premium-editor__brand"><span class="go-premium-editor__brand-mark" aria-hidden="true">GO</span><div><strong>Central editorial</strong><small data-go-workspace-context>Campos da matéria</small></div></div>' +
			'<div class="go-premium-editor__header-meta"><span data-go-live-status>Em edição</span><span><strong data-go-word-count>0</strong> palavras</span></div>';
		var close = createEl('button', 'go-premium-editor__close');
		close.type = 'button';
		close.setAttribute('aria-label', 'Fechar central editorial');
		close.textContent = '×';
		close.addEventListener('click', closeWorkspace);
		header.appendChild(close);

		var formatBar = createEl('div', 'go-premium-editor__formatbar');
		var formatLabel = createEl('span', 'go-premium-editor__format-label', 'Formato');
		var formatTypes = createEl('div', 'go-premium-editor__format-types');
		availableTypes().forEach(function (key) { formatTypes.appendChild(buildTypeButton(key, false, 'workspace')); });
		formatBar.appendChild(formatLabel);
		formatBar.appendChild(formatTypes);

		var quick = createEl('div', 'go-premium-editor__quick');
		quick.innerHTML = '<div class="go-premium-editor__quick-copy"><span>Linha de apoio</span><small>Visível logo abaixo do título</small></div><div class="go-premium-editor__quickline-slot" data-go-quickline-slot></div><div class="go-premium-editor__quick-signals"></div>';
		var quickSignals = quick.querySelector('.go-premium-editor__quick-signals');
		quickSignals.appendChild(buildSignal('Apoio', 'subtitle'));
		quickSignals.appendChild(buildSignal('Imagem', 'image'));
		quickSignals.appendChild(buildSignal('Categoria', 'category'));
		quickSignals.appendChild(buildSignal('Link', 'link'));

		var work = createEl('div', 'go-premium-editor__work');
		var nav = createEl('nav', 'go-premium-editor__nav');
		nav.setAttribute('aria-label', 'Áreas do workspace editorial');
		Object.keys(stageConfig).forEach(function (key) {
			var button = createEl('button', 'go-premium-editor__tab');
			button.type = 'button';
			button.dataset.goStageTab = key;
			button.setAttribute('aria-pressed', key === activeStage ? 'true' : 'false');
			button.innerHTML = '<span class="go-premium-editor__tab-dot" aria-hidden="true"></span><span><strong>' + stageConfig[key].label + '</strong><small>' + stageConfig[key].description + '</small></span>';
			button.addEventListener('click', function () { setStage(key, false); });
			nav.appendChild(button);
		});

		var body = createEl('div', 'go-premium-editor__body');
		Object.keys(stageConfig).forEach(function (key) {
			var pane = createEl('section', 'go-premium-editor__pane');
			pane.dataset.goStagePane = key;
			pane.hidden = key !== activeStage;
			var paneHead = createEl('div', 'go-premium-editor__pane-head');
			paneHead.innerHTML = '<div><span>' + stageConfig[key].label + '</span><h2>' + stageConfig[key].description + '</h2></div>';
			var slot = createEl('div', 'go-premium-editor__slot');
			slot.dataset.goStageSlot = key;
			pane.appendChild(paneHead);
			pane.appendChild(slot);
			if (key === 'evaluation') {
				var empty = createEl('div', 'go-premium-editor__empty');
				empty.dataset.goEvaluationEmpty = '1';
				empty.innerHTML = '<span aria-hidden="true">10</span><div><strong>Nenhuma avaliação necessária</strong><p>Escolha Review ou Crítica no formato editorial. Os campos certos aparecem aqui automaticamente.</p></div>';
				slot.appendChild(empty);
			}
			body.appendChild(pane);
		});

		work.appendChild(nav);
		work.appendChild(body);
		shell.appendChild(header);
		shell.appendChild(formatBar);
		shell.appendChild(quick);
		shell.appendChild(work);

		target.insertBefore(shell, target.firstChild);
		return shell;
	}

	function decorateBox(box, id) {
		if (!box) { return; }
		box.classList.add('go-premium-editor__box');
		box.dataset.goPremiumBox = id;
		var header = box.querySelector('.postbox-header');
		if (header && !header.querySelector('.go-premium-editor__box-meta')) {
			var meta = createEl('span', 'go-premium-editor__box-meta');
			meta.textContent = boxMap[id].stage === 'evaluation' ? 'Contextual' : 'Editorial';
			header.appendChild(meta);
		}
	}

	function rehomeBoxes() {
		var shell = document.getElementById(shellId);
		if (!shell) { return; }
		Object.keys(boxMap).sort(function (a, b) { return boxMap[a].order - boxMap[b].order; }).forEach(function (id) {
			var box = document.getElementById(id);
			if (!box) { return; }
			decorateBox(box, id);
			var stage = boxMap[id].stage;
			var slot = stage === 'quickline' ? shell.querySelector('[data-go-quickline-slot]') : shell.querySelector('[data-go-stage-slot="' + stage + '"]');
			if (slot && box.parentNode !== slot) { slot.appendChild(box); }
		});
	}


	function editorPostStatus() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostAttribute) { return editor.getEditedPostAttribute('status') || xConfig.postStatus || ''; }
			}
		} catch (error) {}
		return xConfig.postStatus || '';
	}

	function syncXLegacyFields(panel) {
		if (!panel) { return; }
		var auto = panel.querySelector('[data-go-x-auto]');
		var image = panel.querySelector('[data-go-x-image]');
		var text = panel.querySelector('[data-go-x-text]');
		var legacyAuto = document.querySelector('#go-x-publishing input[name="go_x_auto"]');
		var legacyImage = document.querySelector('#go-x-publishing input[name="go_x_image"]');
		var legacyText = document.querySelector('#go-x-publishing textarea[name="go_x_text"]');
		if (legacyAuto && auto) { legacyAuto.checked = auto.checked; }
		if (legacyImage && image) { legacyImage.checked = image.checked; }
		if (legacyText && text && legacyText.value !== text.value) { legacyText.value = text.value; }
	}

	function xRequest(action, panel) {
		var body = new URLSearchParams();
		body.append('action', action);
		body.append('nonce', xConfig.nonce || '');
		body.append('post_id', String(Number(xConfig.postId || 0)));
		var auto = panel.querySelector('[data-go-x-auto]');
		var image = panel.querySelector('[data-go-x-image]');
		var text = panel.querySelector('[data-go-x-text]');
		body.append('auto', auto && auto.checked ? '1' : '');
		body.append('image', image && image.checked ? '1' : '');
		body.append('text', text ? text.value : '');
		return fetch(xConfig.ajaxUrl || window.ajaxurl || '', {
			method: 'POST',
			credentials: 'same-origin',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
			body: body.toString()
		}).then(function (response) { return response.json(); });
	}

	function saveXControls(panel) {
		if (!panel || !Number(xConfig.postId || 0) || !xConfig.nonce) { return; }
		syncXLegacyFields(panel);
		window.clearTimeout(xSaveTimer);
		xSaveTimer = window.setTimeout(function () {
			xRequest('go_x_save_editor_controls', panel).catch(function () {});
		}, 500);
	}

	function updateXPanelState(panel) {
		if (!panel) { return; }
		var status = editorPostStatus();
		var isPublished = status === 'publish';
		var send = panel.querySelector('[data-go-x-send]');
		var helper = panel.querySelector('[data-go-x-helper]');
		var statusNode = panel.querySelector('[data-go-x-status]');
		var remote = panel.querySelector('[data-go-x-remote]');
		if (statusNode) { statusNode.textContent = xConfig.status || (xConfig.remoteId ? 'Publicado' : 'Ainda não enviado'); }
		if (remote) {
			remote.hidden = !xConfig.remoteId;
			remote.textContent = xConfig.remoteId ? 'ID no X: ' + xConfig.remoteId : '';
		}
		if (!send || !helper) { return; }
		send.textContent = xConfig.remoteId ? 'Publicar novamente no X' : 'Publicar agora no X';
		if (!Number(xConfig.postId || 0)) {
			send.disabled = true;
			helper.textContent = 'Salve o rascunho para habilitar os controles do X.';
		} else if (!isPublished) {
			send.disabled = true;
			helper.textContent = 'Publique a matéria no WordPress para liberar o envio manual.';
		} else if (!xConfig.enabled || !xConfig.hasCredentials) {
			send.disabled = true;
			helper.innerHTML = 'A integração ainda não está pronta. <a href="' + (xConfig.settingsUrl || '#') + '">Abrir configurações do X</a>.';
		} else {
			send.disabled = false;
			helper.textContent = 'O envio manual usa o texto abaixo e acrescenta o link da matéria automaticamente.';
		}
	}

	function buildXWorkspacePanel() {
		var shell = document.getElementById(shellId);
		if (!shell || document.getElementById('go-x-workspace-action')) { return; }
		var slot = shell.querySelector('[data-go-stage-slot="publication"]');
		if (!slot) { return; }

		var panel = createEl('section', 'go-x-workspace-card');
		panel.id = 'go-x-workspace-action';
		panel.innerHTML =
			'<div class="go-x-workspace-card__head">' +
				'<div class="go-x-workspace-card__identity"><span class="go-x-workspace-card__mark" aria-hidden="true">X</span><div><strong>Publicação no X</strong><small data-go-x-status>Ainda não enviado</small></div></div>' +
				'<a class="go-x-workspace-card__settings" href="' + (xConfig.settingsUrl || '#') + '">Configurações</a>' +
			'</div>' +
			'<div class="go-x-workspace-card__options">' +
				'<label><input type="checkbox" data-go-x-auto> <span><strong>Publicação automática</strong><small>Enviar quando a matéria entrar no ar.</small></span></label>' +
				'<label><input type="checkbox" data-go-x-image> <span><strong>Imagem destacada</strong><small>Tentar anexar quando o fluxo permitir.</small></span></label>' +
			'</div>' +
			'<label class="go-x-workspace-card__text"><span>Texto no X</span><textarea rows="4" data-go-x-text placeholder="Vazio: usa o título da matéria + link."></textarea></label>' +
			'<div class="go-x-workspace-card__actions"><button type="button" class="button button-primary" data-go-x-send>Publicar agora no X</button><span data-go-x-helper></span></div>' +
			'<div class="go-x-workspace-card__feedback" data-go-x-feedback role="status" aria-live="polite"></div>' +
			'<small class="go-x-workspace-card__remote" data-go-x-remote hidden></small>';

		var auto = panel.querySelector('[data-go-x-auto]');
		var image = panel.querySelector('[data-go-x-image]');
		var text = panel.querySelector('[data-go-x-text]');
		auto.checked = !!xConfig.auto;
		image.checked = !!xConfig.image;
		text.value = xConfig.text || '';
		[auto, image].forEach(function (input) { input.addEventListener('change', function () { saveXControls(panel); }); });
		text.addEventListener('input', function () { saveXControls(panel); });

		var send = panel.querySelector('[data-go-x-send]');
		send.addEventListener('click', function () {
			if (send.disabled) { return; }
			var feedback = panel.querySelector('[data-go-x-feedback]');
			send.disabled = true;
			send.classList.add('is-loading');
			send.textContent = 'Enviando…';
			feedback.className = 'go-x-workspace-card__feedback';
			feedback.textContent = 'Publicando no X…';
			syncXLegacyFields(panel);
			xRequest('go_x_manual_send', panel).then(function (payload) {
				if (!payload || !payload.success) {
					var message = payload && payload.data && payload.data.message ? payload.data.message : 'Não foi possível publicar no X.';
					throw new Error(message);
				}
				xConfig.status = payload.data.status || 'Publicado';
				xConfig.remoteId = payload.data.remoteId || xConfig.remoteId || '';
				xConfig.error = payload.data.error || '';
				feedback.classList.add('is-success');
				feedback.textContent = payload.data.message || 'Publicado no X com sucesso.';
			}).catch(function (error) {
				feedback.classList.add('is-error');
				feedback.textContent = error && error.message ? error.message : 'Erro ao publicar no X.';
			}).finally(function () {
				send.classList.remove('is-loading');
				updateXPanelState(panel);
			});
		});

		// Keep the X action at the top of the publication stage.
		slot.insertBefore(panel, slot.firstChild);
		document.body.classList.add('go-x-modern-action-ready');
		updateXPanelState(panel);
	}

	function setStage(key, scroll) {
		if (!stageConfig[key]) { key = 'content'; }
		activeStage = key;
		document.querySelectorAll('[data-go-stage-tab]').forEach(function (button) {
			var active = button.dataset.goStageTab === key;
			button.classList.toggle('is-active', active);
			button.setAttribute('aria-pressed', active ? 'true' : 'false');
		});
		document.querySelectorAll('[data-go-stage-pane]').forEach(function (pane) { pane.hidden = pane.dataset.goStagePane !== key; });
		if (scroll) {
			var pane = document.querySelector('[data-go-stage-pane="' + key + '"]');
			if (pane) { pane.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
		}
	}

	function openWorkspace(stage) {
		buildShell();
		rehomeBoxes();
		if (stage) { setStage(stage, false); }
		var shell = document.getElementById(shellId);
		if (!shell) { return; }
		shell.classList.add('is-open');
		shell.setAttribute('aria-hidden', 'false');
		document.body.classList.add('go-editorial-workspace-open');
		window.setTimeout(function () {
			var close = shell.querySelector('.go-premium-editor__close');
			if (close) { close.focus(); }
		}, 30);
	}

	function closeWorkspace() {
		var shell = document.getElementById(shellId);
		if (!shell) { return; }
		shell.classList.remove('is-open');
		shell.setAttribute('aria-hidden', 'true');
		document.body.classList.remove('go-editorial-workspace-open');
		var opener = document.querySelector('.go-editor-commandbar__open');
		if (opener) { opener.focus(); }
	}

	function updateTypeState() {
		var type = currentType();
		lastType = type;
		document.body.dataset.goEditorialType = type;
		document.querySelectorAll('[data-go-type]').forEach(function (button) {
			var active = button.dataset.goType === type;
			button.classList.toggle('is-active', active);
			button.setAttribute('aria-pressed', active ? 'true' : 'false');
		});
		document.querySelectorAll('[data-go-current-type-label]').forEach(function (node) { node.textContent = typeMeta[type] ? typeMeta[type].label : 'Conteúdo'; });
		document.querySelectorAll('[data-go-workspace-context]').forEach(function (node) { node.textContent = typeMeta[type] ? typeMeta[type].label + ' em edição' : 'Campos da matéria'; });
		var evaluationEmpty = document.querySelector('[data-go-evaluation-empty]');
		if (evaluationEmpty) { evaluationEmpty.hidden = type === 'review' || type === 'critique'; }
		var evalTab = document.querySelector('[data-go-stage-tab="evaluation"]');
		if (evalTab) { evalTab.classList.toggle('is-contextual', type === 'review' || type === 'critique'); }
	}

	function updateSignals() {
		var states = { subtitle: !!supportLineValue().trim(), image: hasFeaturedImage(), category: selectedCategoryIds().length > 0, link: hasLink() };
		Object.keys(states).forEach(function (key) {
			document.querySelectorAll('[data-go-signal="' + key + '"]').forEach(function (item) { item.classList.toggle('is-ok', states[key]); });
		});
		document.querySelectorAll('[data-go-word-count]').forEach(function (node) { node.textContent = String(wordCount()); });
		document.querySelectorAll('[data-go-live-status]').forEach(function (node) { node.textContent = postStatusLabel(); });
		updateXPanelState(document.getElementById('go-x-workspace-action'));
		renderPreviewStudio();
		var value = supportLineValue();
		document.querySelectorAll('[data-go-subtitle-input]').forEach(function (input) {
			if (document.activeElement !== input && input.value !== value) { input.value = value; }
		});
	}

	function cleanupLegacyWorkspace() {
		document.querySelectorAll('.go-editor-stage-label').forEach(function (el) { el.remove(); });
		document.body.classList.remove('go-editor-has-modern-metadata');
		var old = document.getElementById('go-editor-workspace');
		if (old) { old.remove(); }
	}

	function syncAll() {
		scheduled = false;
		if (observer) { observer.disconnect(); }
		document.body.classList.add('go-editorial-editor-ui', 'go-premium-editor-ui');
		cleanupLegacyWorkspace();
		buildDock();
		buildPreviewStudio();
		buildShell();
		rehomeBoxes();
		buildXWorkspacePanel();
		updateTypeState();
		updateSignals();
		setStage(activeStage, false);
		observe();
	}

	function schedule() {
		if (scheduled) { return; }
		scheduled = true;
		window.requestAnimationFrame(syncAll);
	}

	function mutationTouchesWorkspace(mutations) {
		var selector = '[data-go-editorial-control], [data-go-semantic-field], [data-go-game-intelligence], .go-editorial-workspace, .go-editorial-dock, .postbox[id^="go-verge-"]';
		return Array.prototype.some.call(mutations || [], function (mutation) {
			return Array.prototype.some.call(mutation.addedNodes || [], function (node) {
				if (!node || node.nodeType !== 1) { return false; }
				return (node.matches && node.matches(selector)) || (node.querySelector && node.querySelector(selector));
			});
		});
	}

	function observe() {
		if (!observer) { return; }
		observer.observe(document.body, { childList: true, subtree: true });
	}

	function bindLiveUpdates() {
		document.addEventListener('input', function (event) {
			if (!event.target) { return; }
			if (event.target.id === 'go-verge-support-line-field' && !isSyncingSubtitle) { setSupportLineValue(event.target.value, event.target); }
			if (event.target.id === 'content') { updateSignals(); }
		});
		document.addEventListener('change', function (event) {
			if (event.target && event.target.matches('input[name="post_category[]"], #post_status')) {
				var previousType = lastType;
				window.setTimeout(function () {
					syncAll();
					var nextType = currentType();
					if (previousType && nextType !== previousType && (nextType === 'review' || nextType === 'critique')) { openWorkspace('evaluation'); }
				}, 30);
			}
		});
		document.addEventListener('keydown', function (event) {
			if (event.key !== 'Escape') { return; }
			if (document.body.classList.contains('go-preview-studio-open')) { closePreviewStudio(); }
			else if (document.body.classList.contains('go-editorial-workspace-open')) { closeWorkspace(); }
		});
		if (window.wp && wp.data && wp.data.subscribe) {
			var signalTimer = 0;
			var typeTimer = 0;
			dataUnsubscribe = wp.data.subscribe(function () {
				window.clearTimeout(signalTimer);
				signalTimer = window.setTimeout(updateSignals, 220);
				window.clearTimeout(typeTimer);
				typeTimer = window.setTimeout(function () {
					var type = currentType();
					if (type !== lastType) {
						var previous = lastType;
						schedule();
						if (previous && (type === 'review' || type === 'critique')) {
							window.setTimeout(function () { openWorkspace('evaluation'); }, 120);
						}
					}
				}, 360);
			});
		}
	}

	function boot() {
		observer = new MutationObserver(function (mutations) { if (mutationTouchesWorkspace(mutations)) { schedule(); } });
		syncAll();
		observe();
		bindLiveUpdates();
		window.setTimeout(schedule, 350);
		window.setTimeout(schedule, 1000);
		window.setTimeout(schedule, 2200);
	}

	if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', boot); }
	else { boot(); }
})();

(function () {
	'use strict';

	function normalize(value) {
		return String(value || '').trim().replace(/\s+/g, ' ');
	}

	function values(field) {
		return Array.prototype.slice.call(field.querySelectorAll('.go-semantic-chip[data-value]'))
			.map(function (chip) { return normalize(chip.getAttribute('data-value')); })
			.filter(Boolean);
	}

	function sync(field) {
		var hidden = field.querySelector('[data-go-semantic-hidden]');
		var count = field.querySelector('[data-go-semantic-count]');
		var list = values(field);
		if (hidden) { hidden.value = list.join('\n'); }
		if (count) { count.textContent = String(list.length); }
	}

	function makeChip(field, value) {
		value = normalize(value);
		if (!value) { return; }
		var existing = values(field).some(function (item) { return item.toLocaleLowerCase() === value.toLocaleLowerCase(); });
		if (existing) { return; }
		var chips = field.querySelector('[data-go-semantic-chips]');
		if (!chips) { return; }
		var chip = document.createElement('span');
		chip.className = 'go-semantic-chip';
		chip.setAttribute('data-value', value);
		var label = document.createElement('span');
		label.textContent = value;
		var remove = document.createElement('button');
		remove.type = 'button';
		remove.setAttribute('aria-label', 'Remover ' + value);
		remove.textContent = '×';
		remove.addEventListener('click', function () { chip.remove(); sync(field); });
		chip.appendChild(label);
		chip.appendChild(remove);
		chips.appendChild(chip);
		sync(field);
	}

	function addFromInput(field) {
		var input = field.querySelector('[data-go-semantic-input]');
		if (!input) { return; }
		String(input.value || '').split(',').forEach(function (part) { makeChip(field, part); });
		input.value = '';
		input.focus();
	}

	function bindField(field) {
		if (!field || field.dataset.goSemanticBound === '1') { return; }
		field.dataset.goSemanticBound = '1';
		field.querySelectorAll('.go-semantic-chip button').forEach(function (button) {
			button.addEventListener('click', function () { button.closest('.go-semantic-chip').remove(); sync(field); });
		});
		var input = field.querySelector('[data-go-semantic-input]');
		var add = field.querySelector('[data-go-semantic-add]');
		if (add) { add.addEventListener('click', function () { addFromInput(field); }); }
		if (input) {
			input.addEventListener('keydown', function (event) {
				if (event.key === 'Enter' || event.key === ',') {
					event.preventDefault();
					addFromInput(field);
				}
			});
		}
		sync(field);
	}

	function bindSemanticNode(node) {
		if (!node || node.nodeType !== 1) { return; }
		if (node.matches && node.matches('[data-go-semantic-field]')) { bindField(node); }
		if (node.querySelectorAll) { node.querySelectorAll('[data-go-semantic-field]').forEach(bindField); }
	}

	function boot() {
		document.querySelectorAll('[data-go-semantic-field]').forEach(bindField);
		var observer = new MutationObserver(function (mutations) {
			mutations.forEach(function (mutation) {
				Array.prototype.forEach.call(mutation.addedNodes || [], bindSemanticNode);
			});
		});
		observer.observe(document.body, { childList: true, subtree: true });
	}

	if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', boot); }
	else { boot(); }
})();
