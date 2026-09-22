(function (window, document, wp) {
	'use strict';

	if (!wp) {
		return;
	}

	var config = window.GoVergeEditorWorkflow || {};
	var el = wp.element && wp.element.createElement;
	var apiFetch = wp.apiFetch;
	var components = wp.components || {};
	var blockEditor = wp.blockEditor || wp.editor || {};
	var data = wp.data || {};
	var richText = wp.richText || {};
	var hooks = wp.hooks || {};
	var compose = wp.compose || {};
	var plugins = wp.plugins || {};
	var editPost = wp.editPost || {};

	function plainText(value) {
		var node = document.createElement('div');
		node.innerHTML = value || '';
		return (node.textContent || node.innerText || '').replace(/\s+/g, ' ').trim();
	}

	function currentPostId() {
		try {
			var editor = data.select && data.select('core/editor');
			if (editor && editor.getCurrentPostId) {
				return Number(editor.getCurrentPostId()) || Number(config.postId) || 0;
			}
		} catch (error) {}
		return Number(config.postId) || 0;
	}

	/* --------------------------------------------------------------------- */
	/* Categories: searchable hierarchical panel for Gutenberg.              */
	/* --------------------------------------------------------------------- */

	function categoryPath(category, byId) {
		var labels = [category.name];
		var parent = Number(category.parent) || 0;
		var guard = 0;
		while (parent && byId[parent] && guard < 20) {
			labels.unshift(byId[parent].name);
			parent = Number(byId[parent].parent) || 0;
			guard += 1;
		}
		return labels.join(' › ');
	}

	function compareCategoryNames(a, b) {
		return String(a.name || '').localeCompare(String(b.name || ''), 'pt-BR', {
			sensitivity: 'base',
			numeric: true
		});
	}

	function prepareCategoryTree(categories) {
		var list = Array.isArray(categories) ? categories.slice() : [];
		var byId = {};
		var children = {};
		var visited = {};
		var flat = [];

		list.forEach(function (category) {
			byId[Number(category.id)] = category;
		});

		list.forEach(function (category) {
			var parent = Number(category.parent) || 0;
			if (parent && !byId[parent]) {
				parent = 0;
			}
			if (!children[parent]) {
				children[parent] = [];
			}
			children[parent].push(category);
		});

		Object.keys(children).forEach(function (parentId) {
			children[parentId].sort(compareCategoryNames);
		});

		function walk(parentId, depth) {
			(children[parentId] || []).forEach(function (category) {
				var id = Number(category.id);
				if (visited[id]) {
					return;
				}
				visited[id] = true;
				flat.push({
					category: category,
					depth: depth,
					path: categoryPath(category, byId),
					childCount: (children[id] || []).length
				});
				walk(id, depth + 1);
			});
		}

		walk(0, 0);

		/* Safety for malformed/circular taxonomy data: never lose a term. */
		list.slice().sort(compareCategoryNames).forEach(function (category) {
			var id = Number(category.id);
			if (!visited[id]) {
				flat.push({
					category: category,
					depth: 0,
					path: categoryPath(category, byId),
					childCount: (children[id] || []).length
				});
			}
		});

		return { list: list, byId: byId, children: children, flat: flat };
	}

	function registerCategoryPanel() {
		if (!el || !plugins.registerPlugin || !editPost.PluginDocumentSettingPanel || !data.useSelect || !data.useDispatch) {
			return;
		}

		var useMemo = wp.element.useMemo;
		var useState = wp.element.useState;
		var TextControl = components.TextControl;
		var CheckboxControl = components.CheckboxControl;
		var Button = components.Button;
		var Spinner = components.Spinner;
		var SelectControl = components.SelectControl;
		var PluginDocumentSettingPanel = editPost.PluginDocumentSettingPanel;

		function CategoriesPanel() {
			var searchState = useState('');
			var search = searchState[0];
			var setSearch = searchState[1];

			var categories = data.useSelect(function (select) {
				var core = select('core');
				if (!core || !core.getEntityRecords) { return null; }
				return core.getEntityRecords('taxonomy', 'category', {
					per_page: 100,
					hide_empty: false,
					orderby: 'name',
					order: 'asc'
				});
			}, []);

			var selected = data.useSelect(function (select) {
				var editor = select('core/editor');
				var ids = editor && editor.getEditedPostAttribute ? editor.getEditedPostAttribute('categories') : [];
				return Array.isArray(ids) ? ids.map(Number) : [];
			}, []);

			var categoryMeta = data.useSelect(function (select) {
				var editor = select('core/editor');
				return editor && editor.getEditedPostAttribute ? (editor.getEditedPostAttribute('meta') || {}) : {};
			}, []);
			var primaryCategoryId = Number(categoryMeta._go_primary_category_id || 0);
			var editorDispatch = data.useDispatch('core/editor');

			var prepared = useMemo(function () {
				var technical = ['interno', 'tudo', 'sem-categoria', 'uncategorized'];
				var publicCategories = (Array.isArray(categories) ? categories : []).filter(function (category) {
					return technical.indexOf(String(category && category.slug || '')) === -1;
				});
				return prepareCategoryTree(publicCategories);
			}, [categories]);
			var visible = useMemo(function () {
				var needle = search.toLocaleLowerCase('pt-BR').trim();
				if (!needle) { return prepared.flat; }
				return prepared.flat.filter(function (item) {
					return item.path.toLocaleLowerCase('pt-BR').indexOf(needle) !== -1;
				}).slice().sort(function (a, b) {
					return a.path.localeCompare(b.path, 'pt-BR', { sensitivity: 'base', numeric: true });
				});
			}, [prepared, search]);

			function setPrimaryCategory(id) {
				id = Number(id) || 0;
				/* One editorial destination per story. Choosing a primary is also
				 * choosing the category, so stale Games can never remain attached. */
				editorDispatch.editPost({
					categories: id ? [id] : selected.slice(0, 1),
					meta: Object.assign({}, categoryMeta, { _go_primary_category_id: id })
				});
			}

			function toggleCategory(id, checked) {
				id = Number(id);
				if (checked) {
					editorDispatch.editPost({ categories: [id], meta: Object.assign({}, categoryMeta, { _go_primary_category_id: id }) });
					return;
				}
				var next = selected.filter(function (value) { return Number(value) !== id; });
				var fallback = next.length ? Number(next[0]) : 0;
				editorDispatch.editPost({ categories: next, meta: Object.assign({}, categoryMeta, { _go_primary_category_id: fallback }) });
			}

			var selectedCategories = selected.map(function (id) {
				return prepared.byId[id];
			}).filter(Boolean).sort(function (a, b) {
				return categoryPath(a, prepared.byId).localeCompare(categoryPath(b, prepared.byId), 'pt-BR', { sensitivity: 'base', numeric: true });
			});

			var primaryOptions = [{ label: 'Automática', value: 0 }].concat(selectedCategories.map(function (category) {
				return { label: categoryPath(category, prepared.byId), value: Number(category.id) };
			}));

			return el(
				PluginDocumentSettingPanel,
				{ name: 'go-verge-smart-categories', title: 'Categorias', className: 'go-smart-categories-panel', initialOpen: true },
				el('div', { className: 'go-smart-categories' },
					el('div', { className: 'go-smart-categories__selected-box' },
						el('div', { className: 'go-smart-categories__selected-head' },
							el('span', null, 'Selecionadas', selected.length ? ' (' + selected.length + ')' : ''),
							selected.length ? el(Button, {
								className: 'go-smart-categories__clear', variant: 'link', isDestructive: true,
								onClick: function () { editorDispatch.editPost({ categories: [], meta: Object.assign({}, categoryMeta, { _go_primary_category_id: 0 }) }); }
							}, 'Limpar') : null
						),
						selectedCategories.length ? el('div', { className: 'go-smart-categories__selected', 'aria-label': 'Categorias selecionadas' },
							selectedCategories.map(function (category) {
								var path = categoryPath(category, prepared.byId);
								return el(Button, {
									key: category.id, className: 'go-category-chip', isSmall: true,
									onClick: function () { toggleCategory(category.id, false); },
									label: 'Remover ' + path, title: path
								}, category.name, el('span', { 'aria-hidden': true }, '×'));
							})
						) : el('p', { className: 'go-smart-categories__empty' }, 'Nenhuma categoria selecionada.'),
						selectedCategories.length ? el('div', { className: 'go-primary-category-control' },
							el(SelectControl, {
								label: 'Categoria principal',
								help: 'Prioridade editorial usada em breadcrumbs e integrações de SEO.',
								value: primaryCategoryId,
								options: primaryOptions,
								onChange: setPrimaryCategory,
								__nextHasNoMarginBottom: true
							})
						) : null
					),
					el('div', { className: 'go-smart-categories__search' },
						el(TextControl, {
							label: 'Buscar categoria', hideLabelFromVision: true, placeholder: 'Buscar categoria…',
							value: search, onChange: setSearch, __nextHasNoMarginBottom: true
						}),
						search ? el('span', { className: 'go-smart-categories__result-count' }, visible.length + (visible.length === 1 ? ' resultado' : ' resultados')) : null
					),
					categories === null ? el('div', { className: 'go-smart-categories__loading' }, el(Spinner), ' Carregando categorias…') : null,
					categories !== null ? el('div', { className: 'go-smart-categories__list' + (search ? ' is-searching' : '') },
						visible.length ? visible.map(function (item) {
							var category = item.category;
							var depth = search ? 0 : item.depth;
							var rowClass = 'go-category-row ' + (item.depth === 0 ? 'is-root' : 'is-child');
							if (selected.indexOf(Number(category.id)) !== -1) { rowClass += ' is-selected'; }
							return el('div', { key: category.id, className: rowClass, style: { '--go-category-depth': depth } },
								el('div', { className: 'go-category-row__main' },
									el(CheckboxControl, {
										label: category.name, checked: selected.indexOf(Number(category.id)) !== -1,
										onChange: function (checked) { toggleCategory(category.id, checked); }, __nextHasNoMarginBottom: true
									}),
									!search && item.childCount ? el('span', { className: 'go-category-row__child-count', title: item.childCount + ' subcategorias diretas' }, item.childCount) : null
								),
								search && item.path !== category.name ? el('span', { className: 'go-category-row__path' }, item.path) : null
							);
						}) : el('p', { className: 'go-smart-categories__empty go-smart-categories__empty--list' }, 'Nenhuma categoria encontrada.')
					) : null
				)
			);
		}

		plugins.registerPlugin('go-verge-smart-categories', { render: CategoriesPanel, icon: 'category' });
		window.setTimeout(function () {
			try {
				var editPostDispatch = data.dispatch('core/edit-post');
				if (editPostDispatch && editPostDispatch.removeEditorPanel) { editPostDispatch.removeEditorPanel('taxonomy-panel-category'); }
			} catch (error) {}
		}, 700);
	}

	/* --------------------------------------------------------------------- */
	/* Editorial metadata panel: keep daily fields near the document sidebar. */
	/* --------------------------------------------------------------------- */

	function registerEditorialMetadataPanel() {
		if (!el || !plugins.registerPlugin || !editPost.PluginDocumentSettingPanel || !data.useSelect || !data.useDispatch) {
			return;
		}

		var PluginDocumentSettingPanel = editPost.PluginDocumentSettingPanel;
		var SelectControl = components.SelectControl;
		var Button = components.Button;
		var MediaUpload = blockEditor.MediaUpload;
		var MediaUploadCheck = blockEditor.MediaUploadCheck;

		function EditorialMetadataPanel() {
			var meta = data.useSelect(function (select) {
				var editor = select('core/editor');
				return editor && editor.getEditedPostAttribute ? (editor.getEditedPostAttribute('meta') || {}) : {};
			}, []);
			var editorDispatch = data.useDispatch('core/editor');
			var backgroundId = Number(meta._go_editorial_background_id || 0);

			var backgroundMedia = data.useSelect(function (select) {
				if (!backgroundId) { return null; }
				var core = select('core');
				return core && core.getMedia ? core.getMedia(backgroundId) : null;
			}, [backgroundId]);

			function updateMeta(key, value) {
				var next = Object.assign({}, meta);
				next[key] = value;
				editorDispatch.editPost({ meta: next });
			}

			var backgroundUrl = backgroundMedia && backgroundMedia.source_url ? backgroundMedia.source_url : '';

			return el(
				PluginDocumentSettingPanel,
				{ name: 'go-verge-editorial-metadata', title: 'Visual editorial', className: 'go-editorial-metadata-panel', initialOpen: false },
				el('div', { className: 'go-editorial-background-control' },
					el('p', { className: 'go-editorial-background-control__help' }, 'Fundo opcional para especiais, reviews, críticas e páginas com tratamento editorial.'),
					backgroundUrl ? el('div', { className: 'go-editorial-background-control__preview' }, el('img', { src: backgroundUrl, alt: '' })) : null,
					MediaUpload && MediaUploadCheck ? el(MediaUploadCheck, null,
						el(MediaUpload, {
							onSelect: function (media) { updateMeta('_go_editorial_background_id', Number(media && media.id) || 0); },
							allowedTypes: ['image'], value: backgroundId,
							render: function (obj) {
								return el('div', { className: 'go-editorial-background-control__actions' },
									el(Button, { variant: 'secondary', onClick: obj.open }, backgroundId ? 'Trocar imagem' : 'Escolher imagem'),
									backgroundId ? el(Button, { variant: 'tertiary', isDestructive: true, onClick: function () { updateMeta('_go_editorial_background_id', 0); } }, 'Remover') : null
								);
							}
						})
					) : null,
					backgroundId ? el(SelectControl, {
						label: 'Intensidade', value: meta._go_editorial_background_strength || 'subtle',
						options: [{ label: 'Sutil', value: 'subtle' }, { label: 'Média', value: 'medium' }, { label: 'Forte', value: 'strong' }],
						onChange: function (value) { updateMeta('_go_editorial_background_strength', value); }, __nextHasNoMarginBottom: true
					}) : null,
					backgroundId ? el(SelectControl, {
						label: 'Enquadramento', value: meta._go_editorial_background_position || 'center-top',
						options: [
							{ label: 'Centro no topo', value: 'center-top' }, { label: 'Centro', value: 'center' },
							{ label: 'Esquerda no topo', value: 'left-top' }, { label: 'Direita no topo', value: 'right-top' }
						],
						onChange: function (value) { updateMeta('_go_editorial_background_position', value); }, __nextHasNoMarginBottom: true
					}) : null
				)
			);
		}

		plugins.registerPlugin('go-verge-editorial-metadata', { render: EditorialMetadataPanel, icon: 'format-image' });
	}

	/* --------------------------------------------------------------------- */
	/* Classic editor category box enhancement.                              */
	/* --------------------------------------------------------------------- */

	function enhanceClassicCategories() {
		var box = document.getElementById('categorydiv');
		if (!box || box.dataset.goEnhanced === '1') {
			return;
		}
		box.dataset.goEnhanced = '1';
		var all = box.querySelector('#category-all') || box;
		var controls = document.createElement('div');
		controls.className = 'go-classic-category-tools';
		controls.innerHTML = '<input type="search" class="widefat go-classic-category-search" placeholder="Buscar categoria…" autocomplete="off"><div class="go-classic-category-selected" aria-live="polite"></div>';
		all.parentNode.insertBefore(controls, all);

		var search = controls.querySelector('.go-classic-category-search');
		var summary = controls.querySelector('.go-classic-category-selected');

		function items() {
			return Array.prototype.slice.call(box.querySelectorAll('li'));
		}

		function updateSummary() {
			var checked = Array.prototype.slice.call(box.querySelectorAll('input[name="post_category[]"]:checked'));
			if (!checked.length) {
				summary.textContent = 'Nenhuma categoria selecionada.';
				return;
			}
			summary.innerHTML = '';
			checked.forEach(function (input) {
				var label = input.closest('label');
				var chip = document.createElement('button');
				chip.type = 'button';
				chip.className = 'go-category-chip';
				chip.textContent = (label ? label.textContent : input.value).trim() + ' ×';
				chip.addEventListener('click', function () {
					input.checked = false;
					input.dispatchEvent(new Event('change', { bubbles: true }));
				});
				summary.appendChild(chip);
			});
		}

		function filter() {
			var needle = search.value.toLocaleLowerCase('pt-BR').trim();
			var allItems = items();
			if (!needle) {
				allItems.forEach(function (item) { item.style.display = ''; });
				return;
			}

			var visible = [];
			allItems.forEach(function (item) {
				var label = item.querySelector(':scope > label') || item.querySelector('label');
				var checkbox = item.querySelector(':scope > label input[name="post_category[]"]') || item.querySelector('input[name="post_category[]"]');
				var text = label ? label.textContent.toLocaleLowerCase('pt-BR') : '';
				if (text.indexOf(needle) !== -1 || (checkbox && checkbox.checked)) {
					visible.push(item);
					var parent = item.parentElement ? item.parentElement.closest('li') : null;
					while (parent) {
						if (visible.indexOf(parent) === -1) {
							visible.push(parent);
						}
						parent = parent.parentElement ? parent.parentElement.closest('li') : null;
					}
				}
			});

			allItems.forEach(function (item) {
				item.style.display = visible.indexOf(item) !== -1 ? '' : 'none';
			});
		}

		search.addEventListener('input', filter);
		box.addEventListener('change', function (event) {
			if (event.target && event.target.matches('input[name="post_category[]"]')) {
				updateSummary();
				filter();
			}
		});
		updateSummary();
	}

	/* --------------------------------------------------------------------- */
	/* Smart internal link picker for Gutenberg rich text.                   */
	/* --------------------------------------------------------------------- */

	function registerSmartLinkTool() {
		if (!el || !richText.registerFormatType || !richText.applyFormat || !blockEditor.RichTextToolbarButton) {
			return;
		}

		var useEffect = wp.element.useEffect;
		var useState = wp.element.useState;
		var RichTextToolbarButton = blockEditor.RichTextToolbarButton;
		var Popover = components.Popover;
		var TextControl = components.TextControl;
		var ToggleControl = components.ToggleControl;
		var Button = components.Button;
		var Spinner = components.Spinner;
		var Notice = components.Notice;

		function SmartLinkEdit(props) {
			var openState = useState(false);
			var isOpen = openState[0];
			var setOpen = openState[1];
			var urlState = useState('');
			var url = urlState[0];
			var setUrl = urlState[1];
			var queryState = useState('');
			var query = queryState[0];
			var setQuery = queryState[1];
			var resultsState = useState([]);
			var results = resultsState[0];
			var setResults = resultsState[1];
			var loadingState = useState(false);
			var loading = loadingState[0];
			var setLoading = loadingState[1];
			var errorState = useState('');
			var error = errorState[0];
			var setError = errorState[1];
			var newTabState = useState(false);
			var newTab = newTabState[0];
			var setNewTab = newTabState[1];
			var nofollowState = useState(false);
			var nofollow = nofollowState[0];
			var setNofollow = nofollowState[1];
			var sponsoredState = useState(false);
			var sponsored = sponsoredState[0];
			var setSponsored = sponsoredState[1];

			var active = richText.getActiveFormat ? richText.getActiveFormat(props.value, 'core/link') : null;

			useEffect(function () {
				if (!isOpen) {
					return;
				}
				var attrs = active && active.attributes ? active.attributes : {};
				var rel = String(attrs.rel || '').split(/\s+/);
				setUrl(attrs.url || '');
				setNewTab(attrs.target === '_blank');
				setNofollow(rel.indexOf('nofollow') !== -1);
				setSponsored(rel.indexOf('sponsored') !== -1);
				setError('');
			}, [isOpen]);

			useEffect(function () {
				var needle = query.trim();
				if (needle.length < 2 || !apiFetch) {
					setResults([]);
					setLoading(false);
					return;
				}
				var cancelled = false;
				setLoading(true);
				var timer = window.setTimeout(function () {
					apiFetch({ path: '/go-verge/v1/link-search?search=' + encodeURIComponent(needle) + '&limit=8' })
						.then(function (items) {
							if (!cancelled) {
								setResults(Array.isArray(items) ? items : []);
								setLoading(false);
							}
						})
						.catch(function () {
							if (!cancelled) {
								setResults([]);
								setLoading(false);
							}
						});
				}, 250);
				return function () {
					cancelled = true;
					window.clearTimeout(timer);
				};
			}, [query]);

			function buildRel() {
				var attrs = active && active.attributes ? active.attributes : {};
				var values = String(attrs.rel || '').split(/\s+/).filter(Boolean).filter(function (value) {
					return ['nofollow', 'sponsored', 'noopener'].indexOf(value) === -1;
				});
				if (nofollow) { values.push('nofollow'); }
				if (sponsored) { values.push('sponsored'); }
				if (newTab) { values.push('noopener'); }
				return values.filter(function (value, index, list) { return list.indexOf(value) === index; }).join(' ');
			}

			function applyLink() {
				var nextUrl = url.trim();
				if (!nextUrl) {
					setError('Informe uma URL ou escolha um conteúdo interno.');
					return;
				}
				var next = richText.applyFormat(props.value, {
					type: 'core/link',
					attributes: {
						url: nextUrl,
						target: newTab ? '_blank' : undefined,
						rel: buildRel() || undefined
					}
				});
				props.onChange(next);
				setOpen(false);
			}

			function removeLink() {
				if (richText.removeFormat) {
					props.onChange(richText.removeFormat(props.value, 'core/link'));
				}
				setOpen(false);
			}

			return el(wp.element.Fragment, null,
				el(RichTextToolbarButton, {
					icon: 'admin-links',
					title: 'Link inteligente',
					onClick: function () { setOpen(!isOpen); },
					isActive: !!active || isOpen
				}),
				isOpen ? el(Popover, {
					className: 'go-smart-link-popover',
					position: 'bottom center',
					onClose: function () { setOpen(false); },
					focusOnMount: 'firstElement'
				}, el('div', { className: 'go-smart-link' },
					el('div', { className: 'go-smart-link__header' },
						el('strong', null, active ? 'Editar hyperlink' : 'Inserir hyperlink'),
						el('span', null, 'Busca interna + atributos SEO')
					),
					error ? el(Notice, { status: 'warning', isDismissible: false }, error) : null,
					el(TextControl, {
						label: 'URL',
						placeholder: 'https://…',
						value: url,
						onChange: function (value) { setUrl(value); setError(''); },
						__nextHasNoMarginBottom: true
					}),
					el(TextControl, {
						label: 'Buscar conteúdo interno',
						placeholder: 'Digite ao menos 2 caracteres…',
						value: query,
						onChange: setQuery,
						__nextHasNoMarginBottom: true
					}),
					loading ? el('div', { className: 'go-smart-link__loading' }, el(Spinner), ' Buscando…') : null,
					results.length ? el('div', { className: 'go-smart-link__results' }, results.map(function (item) {
						return el('button', {
							key: item.id,
							type: 'button',
							className: 'go-smart-link-result',
							onClick: function () { setUrl(item.url || ''); setQuery(item.title || ''); setResults([]); }
						}, el('strong', null, item.title || '(Sem título)'), el('span', null, item.type || 'Conteúdo'));
					})) : null,
					el('div', { className: 'go-smart-link__toggles' },
						el(ToggleControl, { label: 'Abrir em nova aba', checked: newTab, onChange: setNewTab, __nextHasNoMarginBottom: true }),
						el(ToggleControl, { label: 'nofollow', checked: nofollow, onChange: setNofollow, __nextHasNoMarginBottom: true }),
						el(ToggleControl, { label: 'sponsored', checked: sponsored, onChange: setSponsored, __nextHasNoMarginBottom: true })
					),
					el('div', { className: 'go-smart-link__actions' },
						active ? el(Button, { variant: 'tertiary', isDestructive: true, onClick: removeLink }, 'Remover link') : el('span'),
						el(Button, { variant: 'primary', onClick: applyLink }, active ? 'Atualizar link' : 'Aplicar link')
					)
				)) : null
			);
		}

		try {
			richText.registerFormatType('go-verge/smart-link-tool', {
				title: 'Link inteligente',
				tagName: 'span',
				className: 'go-smart-link-tool-marker',
				edit: SmartLinkEdit
			});
		} catch (error) {}
	}

	/* --------------------------------------------------------------------- */
	/* Contextual alt/caption helper in Image block inspector.               */
	/* --------------------------------------------------------------------- */

	function registerImageTextHelper() {
		if (!el || !hooks.addFilter || !compose.createHigherOrderComponent || !blockEditor.InspectorControls || !apiFetch || !data || typeof data.useSelect !== 'function') {
			return;
		}

		var InspectorControls = blockEditor.InspectorControls;
		var PanelBody = components.PanelBody;
		var Button = components.Button;
		var Spinner = components.Spinner;
		var Notice = components.Notice;
		var TextControl = components.TextControl;
		var TextareaControl = components.TextareaControl;
		var useState = wp.element.useState;
		var useEffect = wp.element.useEffect;

		var withSmartImageText = compose.createHigherOrderComponent(function (BlockEdit) {
			return function (props) {
				/* Keep this optional enhancement completely outside non-image blocks.
				 * A media/API incompatibility must never be able to crash paragraph,
				 * heading, list or any other native Gutenberg block. */
				if (props.name !== 'core/image') {
					return el(BlockEdit, props);
				}
				var busyState = useState(false);
				var busy = busyState[0];
				var setBusy = busyState[1];
				var messageState = useState('');
				var message = messageState[0];
				var statusState = useState('success');
				var status = statusState[0];
				var setStatus = statusState[1];
				var titleState = useState('');
				var mediaTitle = titleState[0];
				var setMediaTitle = titleState[1];
				var titleTouchedState = useState(false);
				var titleTouched = titleTouchedState[0];
				var setTitleTouched = titleTouchedState[1];

				var attachmentId = Number(props.attributes && props.attributes.id) || 0;
				var mediaRecord = data.useSelect(function (select) {
					if (!attachmentId) { return null; }
					var core = select('core');
					return core && core.getMedia ? core.getMedia(attachmentId) : null;
				}, [attachmentId]);

				useEffect(function () {
					if (titleTouched || !mediaRecord) { return; }
					var rawTitle = mediaRecord.title && (mediaRecord.title.raw || mediaRecord.title.rendered) ? (mediaRecord.title.raw || plainText(mediaRecord.title.rendered)) : '';
					setMediaTitle(plainText(rawTitle));
				}, [attachmentId, mediaRecord, titleTouched]);

				if (!props.isSelected) {
					return el(BlockEdit, props);
				}

				var context = plainText(props.attributes && props.attributes.caption ? props.attributes.caption : '');
				var altValue = String(props.attributes && props.attributes.alt ? props.attributes.alt : '');
				var captionValue = plainText(props.attributes && props.attributes.caption ? props.attributes.caption : '');

				function saveMetadata() {
					if (!attachmentId) {
						setStatus('warning');
						messageState[1]('Salve a imagem na Biblioteca de Mídia para atualizar título, texto alternativo e legenda.');
						return;
					}
					setBusy(true);
					setStatus('info');
					messageState[1]('Salvando metadados da imagem…');
					apiFetch({
						path: (config.saveImageTextEndpoint || '/go-verge/v1/save-local-image-text'),
						method: 'POST',
						data: {
							attachment_id: attachmentId,
							title: mediaTitle,
							alt: altValue,
							caption: captionValue,
							mode: 'both'
						}
					}).then(function (response) {
						props.setAttributes({ alt: response && response.alt !== undefined ? response.alt : altValue, caption: response && response.caption !== undefined ? response.caption : captionValue });
						setStatus('success');
						messageState[1]('Metadados da imagem salvos.');
					}).catch(function (error) {
						setStatus('error');
						messageState[1](error && error.message ? error.message : 'Não foi possível salvar os metadados da imagem.');
					}).then(function () { setBusy(false); });
				}

				function generate(mode) {
					if (!attachmentId) {
						setStatus('warning');
						messageState[1]('A imagem precisa estar salva na Biblioteca de Mídia para gerar a sugestão.');
						return;
					}

					setBusy(true);
					setStatus('info');
					messageState[1]('Preparando a análise visual local…');

					var onProgress = function (event) {
						var detail = event && event.detail ? event.detail : {};
						if (detail.message) {
							setStatus(detail.stage === 'error' ? 'error' : (detail.stage === 'warning' ? 'warning' : 'info'));
							messageState[1](detail.message);
						}
					};
					document.addEventListener('go-verge-local-ai-progress', onProgress);

					Promise.resolve(window.GoVergeLocalAIReady)
						.then(function (localAI) {
							if (!localAI || typeof localAI.generate !== 'function') { throw new Error('O motor de análise visual não foi carregado. Atualize a página e tente novamente.'); }
							return localAI.generate({
								attachmentId: attachmentId,
								postId: currentPostId(),
								context: context,
								imageUrl: props.attributes && props.attributes.url ? props.attributes.url : '',
								mode: mode
							});
						})
						.then(function (response) {
							var next = {};
							if (response && response.title) { setMediaTitle(response.title); setTitleTouched(true); }
							if (mode === 'both' || mode === 'alt') { next.alt = response.alt || ''; }
							if (mode === 'both' || mode === 'caption') { next.caption = response.caption || ''; }
							props.setAttributes(next);
							setStatus('success');
							messageState[1]('Sugestão visual aplicada. Revise antes de publicar.');
						})
						.catch(function (error) {
							setStatus('error');
							messageState[1](error && error.message ? error.message : 'Não foi possível executar a análise visual local.');
						})
						.then(function () {
							document.removeEventListener('go-verge-local-ai-progress', onProgress);
							setBusy(false);
						});
				}

				return el(wp.element.Fragment, null,
					el(BlockEdit, props),
					el(InspectorControls, null,
						el(PanelBody, { title: 'Metadados da imagem', initialOpen: true },
							el('div', { className: 'go-image-metadata-fields' },
								el(TextControl, {
									label: 'Título',
									help: 'Organiza a imagem na Biblioteca de Mídia.',
									value: mediaTitle,
									onChange: function (value) { setMediaTitle(value); setTitleTouched(true); },
									__nextHasNoMarginBottom: true
								}),
								el(TextareaControl, {
									label: 'Texto alternativo',
									help: 'Fica escondido visualmente. Descreva o que é necessário para compreender a imagem.',
									value: altValue,
									onChange: function (value) { props.setAttributes({ alt: value }); },
									rows: 3,
									__nextHasNoMarginBottom: true
								}),
								el(TextareaControl, {
									label: 'Legenda visível',
									help: 'Aparece para o leitor abaixo da foto.',
									value: captionValue,
									onChange: function (value) { props.setAttributes({ caption: value }); },
									rows: 3,
									__nextHasNoMarginBottom: true
								}),
								el('div', { className: 'go-image-metadata-fields__actions' },
									el(Button, { variant: 'primary', disabled: busy, onClick: saveMetadata }, 'Salvar metadados')
								)
							)
						),
						el(PanelBody, { title: 'Sugestão visual', initialOpen: false },
							el('p', { className: 'go-smart-image-help' }, 'A imagem é analisada primeiro. O contexto da matéria só ajuda a refinar o texto sem substituir o que aparece na foto.'),
							message ? el(Notice, { status: status, isDismissible: true, onRemove: function () { messageState[1](''); } }, message) : null,
							busy ? el('div', { className: 'go-smart-image-loading' }, el(Spinner), ' Analisando…') : null,
							el(Button, { variant: 'primary', disabled: busy, onClick: function () { generate('both'); } }, 'Sugerir título + alt + legenda'),
							el('div', { className: 'go-smart-image-secondary-actions' },
								el(Button, { variant: 'secondary', disabled: busy, onClick: function () { generate('alt'); } }, 'Só alt'),
								el(Button, { variant: 'secondary', disabled: busy, onClick: function () { generate('caption'); } }, 'Só legenda')
							)
						)
					)
				);
			};
		}, 'withGoVergeSmartImageText');

		hooks.addFilter('editor.BlockEdit', 'go-verge/smart-image-text', withSmartImageText);
	}

	/* --------------------------------------------------------------------- */
	/* Rank Math: expose the theme-native TOC to content analysis.           */
	/* --------------------------------------------------------------------- */

	function registerRankMathTocBridge() {
		if (!hooks || !hooks.addFilter) {
			return;
		}

		hooks.addFilter('rank_math_content', 'go-verge/native-toc', function (content) {
			var source = String(content || '');
			var container;
			var headings;

			/* Do not add anything when a real TOC block/plugin is already present. */
			if (/wp-block-rank-math-toc-block|rank-math-toc-block|ez-toc-container|lwptoc|toc_container|data-go-theme-toc/i.test(source)) {
				return content;
			}

			container = document.createElement('div');
			container.innerHTML = source;
			headings = container.querySelectorAll('h2');

			/* single.php renders the built-in TOC only when there are at least 3 H2s. */
			if (!headings || headings.length < 3) {
				return content;
			}

			/*
			 * Mirror only a zero-text marker into Rank Math's analysis input.
			 * Nothing is saved to post_content and keyword/word counts stay intact.
			 */
			return source + '<nav class="wp-block-rank-math-toc-block go-rank-math-toc-bridge" data-go-theme-toc="1" aria-hidden="true"></nav>';
		});
	}

	function boot() {
		enhanceClassicCategories();
		registerCategoryPanel();
		registerEditorialMetadataPanel();
		registerRankMathTocBridge();
		registerImageTextHelper();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})(window, document, window.wp);
