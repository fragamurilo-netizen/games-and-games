/**
 * Linkagem interna no editor.
 *
 * - Bloco dinâmico "Leia mais".
 * - Botão "Link inteligente" ao lado das ferramentas de RichText: selecione
 *   um termo, clique no botão e escolha o destino sugerido. O link é aplicado
 *   à seleção sem copiar e colar URL.
 * - Painel "Linkagem inteligente": analisa o rascunho ainda não salvo, mostra
 *   o que merece link e pode aplicar o vínculo na primeira ocorrência segura.
 *
 * Sem build step: usa somente os globals wp.* fornecidos pelo WordPress.
 */
(function (wp) {
	'use strict';

	if (!wp || !wp.element || !wp.blocks || !wp.blockEditor || !wp.apiFetch) {
		return;
	}

	var el = wp.element.createElement;
	var Fragment = wp.element.Fragment;
	var useState = wp.element.useState;
	var useEffect = wp.element.useEffect;
	var __ = wp.i18n.__;
	var registerBlockType = wp.blocks.registerBlockType;
	var useBlockProps = wp.blockEditor.useBlockProps;
	var InspectorControls = wp.blockEditor.InspectorControls;
	var BlockControls = wp.blockEditor.BlockControls;
	var RichTextToolbarButton = wp.blockEditor.RichTextToolbarButton;
	var Button = wp.components.Button;
	var PanelBody = wp.components.PanelBody;
	var TextControl = wp.components.TextControl;
	var Spinner = wp.components.Spinner;
	var Dropdown = wp.components.Dropdown;
	var ToolbarGroup = wp.components.ToolbarGroup;
	var ToolbarButton = wp.components.ToolbarButton;
	var apiFetch = wp.apiFetch;
	var registerPlugin = wp.plugins ? wp.plugins.registerPlugin : null;
	var registerFormatType = wp.richText ? wp.richText.registerFormatType : null;
	var applyFormat = wp.richText ? wp.richText.applyFormat : null;
	var addFilter = wp.hooks ? wp.hooks.addFilter : null;
	var createHigherOrderComponent = wp.compose ? wp.compose.createHigherOrderComponent : null;
	var activeSmartLinkSelection = null;
	var nativeLinkObserver = null;
	var nativeLinkScanScheduled = false;
	var SettingPanel =
		(wp.editor && wp.editor.PluginDocumentSettingPanel) ||
		(wp.editPost && wp.editPost.PluginDocumentSettingPanel) ||
		null;

	function currentPostId() {
		var editor = wp.data.select('core/editor');
		return editor && editor.getCurrentPostId ? editor.getCurrentPostId() : 0;
	}

	function currentTitle() {
		var editor = wp.data.select('core/editor');
		return editor && editor.getEditedPostAttribute
			? String(editor.getEditedPostAttribute('title') || '')
			: '';
	}

	function currentContent() {
		var editor = wp.data.select('core/editor');
		return editor && editor.getEditedPostContent ? String(editor.getEditedPostContent() || '') : '';
	}

	/** Busca simples no endpoint legado, usada pelo bloco Leia mais e pela busca manual. */
	function useSuggestions(search, postId, deps) {
		var state = useState({ items: [], loading: false });
		var value = state[0];
		var setValue = state[1];

		useEffect(function () {
			var query = String(search || '').trim();
			if (query.length < 2) {
				setValue({ items: [], loading: false });
				return function () {};
			}

			var cancelled = false;
			setValue({ items: value.items || [], loading: true });

			var timer = window.setTimeout(function () {
				var path = '/go-verge/v1/link-suggestions?post=' + (postId || 0) + '&search=' + encodeURIComponent(query);
				apiFetch({ path: path })
					.then(function (result) {
						if (!cancelled) setValue({ items: result || [], loading: false });
					})
					.catch(function () {
						if (!cancelled) setValue({ items: [], loading: false });
					});
			}, 300);

			return function () {
				cancelled = true;
				window.clearTimeout(timer);
			};
		}, deps);

		return value;
	}

	function fetchSmartLinks(payload) {
		return apiFetch({
			path: '/go-verge/v1/smart-links',
			method: 'POST',
			data: payload
		}).then(function (response) {
			return response && Array.isArray(response.items) ? response.items : [];
		});
	}

	function copyText(text, done) {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text).then(done, done);
			return;
		}
		var field = document.createElement('textarea');
		field.value = text;
		field.setAttribute('readonly', '');
		field.style.position = 'absolute';
		field.style.left = '-9999px';
		document.body.appendChild(field);
		field.select();
		try { document.execCommand('copy'); } catch (error) { /* sem ação */ }
		document.body.removeChild(field);
		done();
	}

	/* ------------------------------------------------------------------ */
	/* Bloco "Leia mais"                                                   */
	/* ------------------------------------------------------------------ */

	registerBlockType('go/read-more', {
		apiVersion: 2,
		title: __('Leia mais', 'go-verge'),
		description: __('Indicação de uma a três matérias do próprio site, no meio do texto.', 'go-verge'),
		icon: 'editor-ul',
		category: 'text',
		keywords: [__('leia', 'go-verge'), __('relacionado', 'go-verge'), __('link', 'go-verge')],
		supports: { html: false, align: false },
		attributes: {
			ids: { type: 'array', default: [], items: { type: 'number' } },
			label: { type: 'string', default: '' }
		},

		edit: function (props) {
			var attributes = props.attributes;
			var setAttributes = props.setAttributes;
			var blockProps = useBlockProps({ className: 'go-read-more-editor' });
			var searchState = useState('');
			var search = searchState[0];
			var setSearch = searchState[1];
			var postId = currentPostId();
			var suggestions = useSuggestions(search, postId, [search, postId]);
			var chosen = attributes.ids || [];
			var chosenState = useState([]);
			var chosenPosts = chosenState[0];
			var setChosenPosts = chosenState[1];

			useEffect(function () {
				if (!chosen.length) {
					setChosenPosts([]);
					return;
				}
				apiFetch({ path: '/wp/v2/posts?include=' + chosen.join(',') + '&_fields=id,title,link&per_page=3' })
					.then(function (result) {
						var byId = {};
						(result || []).forEach(function (item) { byId[item.id] = item; });
						setChosenPosts(chosen.map(function (id) { return byId[id]; }).filter(Boolean));
					})
					.catch(function () { setChosenPosts([]); });
			}, [chosen.join(',')]);

			function toggle(id) {
				var next = chosen.indexOf(id) !== -1
					? chosen.filter(function (existing) { return existing !== id; })
					: chosen.concat([id]).slice(0, 3);
				setAttributes({ ids: next });
			}

			return el(Fragment, null,
				el(InspectorControls, null,
					el(PanelBody, { title: __('Título do bloco', 'go-verge'), initialOpen: true },
						el(TextControl, {
							label: __('Rótulo', 'go-verge'),
							help: __('Vazio usa "Leia mais".', 'go-verge'),
							value: attributes.label,
							onChange: function (value) { setAttributes({ label: value }); }
						})
					)
				),
				el('div', blockProps,
					el('p', { className: 'go-read-more-editor__title' }, attributes.label || __('Leia mais', 'go-verge')),
					chosenPosts.length
						? el('ul', { className: 'go-read-more-editor__chosen' }, chosenPosts.map(function (item) {
							return el('li', { key: item.id },
								el('span', null, item.title ? item.title.rendered : '#' + item.id),
								el(Button, { isDestructive: true, variant: 'tertiary', onClick: function () { toggle(item.id); } }, __('Remover', 'go-verge'))
							);
						}))
						: el('p', { className: 'go-read-more-editor__empty' }, __('Escolha até três matérias abaixo.', 'go-verge')),
					el(TextControl, {
						label: __('Buscar matéria', 'go-verge'),
						placeholder: __('Sem busca, sugere pelas tags desta matéria', 'go-verge'),
						value: search,
						onChange: setSearch
					}),
					suggestions.loading
						? el(Spinner)
						: el('ul', { className: 'go-read-more-editor__results' }, (suggestions.items || []).map(function (item) {
							var picked = chosen.indexOf(item.id) !== -1;
							return el('li', { key: item.id },
								el(Button, { variant: picked ? 'primary' : 'secondary', onClick: function () { toggle(item.id); } }, (picked ? '✓ ' : '') + item.title)
							);
						}))
				)
			);
		},

		save: function () { return null; }
	});

	/* ------------------------------------------------------------------ */
	/* Botão contextual: aplica link à seleção atual                       */
	/* ------------------------------------------------------------------ */

	function selectedText(value) {
		if (!value || typeof value.text !== 'string') return '';
		var start = typeof value.start === 'number' ? value.start : 0;
		var end = typeof value.end === 'number' ? value.end : start;
		return value.text.slice(start, end).replace(/\u00a0/g, ' ').trim();
	}

	function SmartLinkSelectionBridge(props) {
		var selection = selectedText(props.value);

		useEffect(function () {
			if (selection.length >= 2) {
				var captured = {
					value: props.value,
					onChange: props.onChange,
					selected: selection,
					context: props.value && props.value.text ? props.value.text.slice(0, 1200) : '',
					capturedAt: Date.now()
				};
				activeSmartLinkSelection = captured;
				scheduleNativeLinkScan();
				window.setTimeout(function () {
					if (activeSmartLinkSelection === captured && Date.now() - captured.capturedAt >= 10000) {
						activeSmartLinkSelection = null;
					}
				}, 10050);
			}
		}, [props.value, props.onChange, selection]);

		return null;
	}

	function nativeLinkInput(popover) {
		return popover.querySelector(
			'.block-editor-link-control__search-input input,' +
			'.block-editor-link-control__search-input-wrapper input,' +
			'.block-editor-url-input__input,' +
			'input[placeholder*="digitar o URL" i],' +
			'input[placeholder*="type URL" i]'
		);
	}

	function closeNativeLinkPopover(popover) {
		window.setTimeout(function () {
			var closeButton = popover.querySelector('button[aria-label="Fechar" i], button[aria-label="Close" i]');
			if (closeButton) {
				closeButton.click();
				return;
			}
			document.dispatchEvent(new KeyboardEvent('keydown', {
				key: 'Escape',
				code: 'Escape',
				keyCode: 27,
				which: 27,
				bubbles: true
			}));
		}, 0);
	}

	function applyNativeSmartLink(item, popover) {
		if (!activeSmartLinkSelection || !applyFormat) return;
		var next = applyFormat(activeSmartLinkSelection.value, {
			type: 'core/link',
			attributes: { url: item.url }
		});
		activeSmartLinkSelection.onChange(next);
		activeSmartLinkSelection.value = next;
		activeSmartLinkSelection = null;
		closeNativeLinkPopover(popover);
	}

	function renderNativeSmartLinkResults(host, popover, items, selection) {
		host.textContent = '';
		var heading = document.createElement('div');
		heading.className = 'go-native-smart-links__head';
		var title = document.createElement('strong');
		title.textContent = __('Sugestões inteligentes', 'go-verge');
		var term = document.createElement('span');
		term.textContent = '“' + selection + '”';
		heading.appendChild(title);
		heading.appendChild(term);
		host.appendChild(heading);

		if (!items.length) {
			var empty = document.createElement('p');
			empty.className = 'go-native-smart-links__empty';
			empty.textContent = __('Nenhuma matéria relacionada forte foi encontrada. Use a busca normal abaixo.', 'go-verge');
			host.appendChild(empty);
			return;
		}

		var list = document.createElement('ul');
		list.className = 'go-native-smart-links__list';
		items.forEach(function (item) {
			var row = document.createElement('li');
			var button = document.createElement('button');
			button.type = 'button';
			button.className = 'go-native-smart-links__item';
			var itemTitle = document.createElement('strong');
			itemTitle.textContent = item.title || __('Matéria sem título', 'go-verge');
			var meta = document.createElement('span');
			meta.textContent = [item.typeLabel, item.date, item.confidence].filter(Boolean).join(' · ');
			var reason = document.createElement('small');
			reason.textContent = item.reason || __('Relacionado ao trecho selecionado.', 'go-verge');
			button.appendChild(itemTitle);
			button.appendChild(meta);
			button.appendChild(reason);
			button.addEventListener('click', function (event) {
				event.preventDefault();
				event.stopPropagation();
				applyNativeSmartLink(item, popover);
			});
			row.appendChild(button);
			list.appendChild(row);
		});
		host.appendChild(list);
	}

	function enhanceNativeLinkPopover(popover) {
		var input = nativeLinkInput(popover);
		var selectionState = activeSmartLinkSelection;
		if (!input || !selectionState || selectionState.selected.length < 2 || Date.now() - selectionState.capturedAt > 10000) return;
		if (popover.querySelector('.go-native-smart-links')) return;

		var host = document.createElement('section');
		host.className = 'go-native-smart-links is-loading';
		host.setAttribute('aria-live', 'polite');
		host.textContent = __('Buscando matérias relacionadas…', 'go-verge');

		var inputRow = input.closest('.block-editor-link-control__search-input, .block-editor-link-control__search-input-wrapper, .block-editor-url-input');
		var control = input.closest('.block-editor-link-control') || input.parentElement;
		if (inputRow && inputRow.parentElement) {
			inputRow.insertAdjacentElement('afterend', host);
		} else if (control) {
			control.insertBefore(host, control.firstChild);
		} else {
			return;
		}

		fetchSmartLinks({
			post: currentPostId(),
			selected: selectionState.selected,
			context: selectionState.context,
			content: currentContent(),
			title: currentTitle(),
			mode: 'selection'
		}).then(function (items) {
			if (!host.isConnected) return;
			host.classList.remove('is-loading');
			renderNativeSmartLinkResults(host, popover, items, selectionState.selected);
		}).catch(function () {
			if (!host.isConnected) return;
			host.classList.remove('is-loading');
			host.textContent = __('Não foi possível carregar as sugestões inteligentes. Use a busca normal abaixo.', 'go-verge');
		});
	}

	function scanNativeLinkPopovers() {
		nativeLinkScanScheduled = false;
		document.querySelectorAll('.components-popover').forEach(function (popover) {
			if (nativeLinkInput(popover)) enhanceNativeLinkPopover(popover);
		});
	}

	function scheduleNativeLinkScan() {
		if (nativeLinkScanScheduled) return;
		nativeLinkScanScheduled = true;
		window.requestAnimationFrame(scanNativeLinkPopovers);
	}

	function registerNativeLinkPopoverIntegration() {
		if (nativeLinkObserver || !window.MutationObserver || !document.body) return;
		nativeLinkObserver = new MutationObserver(function (mutations) {
			var hasPopover = Array.prototype.some.call(mutations || [], function (mutation) {
				return Array.prototype.some.call(mutation.addedNodes || [], function (node) {
					if (!node || node.nodeType !== 1) return false;
					return (node.matches && node.matches('.components-popover')) || (node.querySelector && node.querySelector('.components-popover'));
				});
			});
			if (hasPopover) scheduleNativeLinkScan();
		});
		nativeLinkObserver.observe(document.body, { childList: true, subtree: true });
		scheduleNativeLinkScan();
	}

	function SmartLinkToolbar(props) {
		var state = useState({ items: [], loading: false, error: '' });
		var result = state[0];
		var setResult = state[1];
		var selection = selectedText(props.value);

		function load() {
			if (selection.length < 2) return;
			setResult({ items: [], loading: true, error: '' });
			fetchSmartLinks({
				post: currentPostId(),
				selected: selection,
				context: props.value && props.value.text ? props.value.text.slice(0, 1200) : '',
				content: currentContent(),
				title: currentTitle(),
				mode: 'selection'
			}).then(function (items) {
				setResult({ items: items, loading: false, error: '' });
			}).catch(function () {
				setResult({ items: [], loading: false, error: __('Não foi possível analisar a seleção.', 'go-verge') });
			});
		}

		function apply(item, close) {
			if (!applyFormat) return;
			props.onChange(applyFormat(props.value, {
				type: 'core/link',
				attributes: { url: item.url }
			}));
			close();
		}

		return el(Dropdown, {
			className: 'go-smart-link-dropdown',
			popoverProps: { placement: 'bottom-start', className: 'go-smart-link-popover' },
			renderToggle: function (toggleProps) {
				return el(RichTextToolbarButton, {
					icon: 'admin-links',
					title: selection.length >= 2
						? __('Link inteligente: sugerir destino', 'go-verge')
						: __('Selecione um termo para receber sugestões de link', 'go-verge'),
					disabled: selection.length < 2,
					isActive: toggleProps.isOpen,
					onClick: function () {
						if (!toggleProps.isOpen) load();
						toggleProps.onToggle();
					}
				});
			},
			renderContent: function (contentProps) {
				return el('div', { className: 'go-smart-link-menu' },
					el('div', { className: 'go-smart-link-menu__head' },
						el('strong', null, __('Linkar “%s”', 'go-verge').replace('%s', selection)),
						el('span', null, __('Destinos ordenados por correspondência e contexto.', 'go-verge'))
					),
					result.loading ? el('div', { className: 'go-smart-link-menu__loading' }, el(Spinner)) : null,
					result.error ? el('p', { className: 'go-smart-link-menu__empty' }, result.error) : null,
					!result.loading && !result.error && !result.items.length
						? el('p', { className: 'go-smart-link-menu__empty' }, __('Nenhum destino interno forte para esta seleção.', 'go-verge'))
						: null,
					el('ul', { className: 'go-smart-link-menu__list' }, result.items.map(function (item) {
						return el('li', { key: item.id },
							el(Button, { variant: 'tertiary', onClick: function () { apply(item, contentProps.onClose); } },
								el('strong', null, item.title),
								el('span', null, item.reason || '')
							),
							el('span', { className: 'go-smart-link-menu__meta' }, (item.typeLabel || '') + ' · ' + (item.date || '') + ' · ' + (item.confidence || ''))
						);
					}))
				);
			}
		});
	}

	if (registerFormatType && RichTextToolbarButton && Dropdown && applyFormat) {
		registerFormatType('go-verge/smart-link-assistant', {
			title: __('Link inteligente', 'go-verge'),
			tagName: 'span',
			className: 'go-smart-link-assistant-format',
			edit: SmartLinkSelectionBridge
		});
		registerNativeLinkPopoverIntegration();
	}

	/* ------------------------------------------------------------------ */
	/* Atalho no menu principal do bloco selecionado                       */
	/* ------------------------------------------------------------------ */

	var smartLinkBlockAttributes = {
		'core/paragraph': ['content'],
		'core/list-item': ['content'],
		'core/freeform': ['content'],
		'core/pullquote': ['value', 'citation'],
		'core/verse': ['content']
	};

	function plainTextFromHtml(html) {
		var holder = document.createElement('div');
		holder.innerHTML = String(html || '');
		return String(holder.textContent || holder.innerText || '').replace(/\s+/g, ' ').trim();
	}

	function smartLinkBlockSource(props) {
		var attributes = smartLinkBlockAttributes[props.name] || [];
		var html = attributes.map(function (attribute) {
			return typeof props.attributes[attribute] === 'string' ? props.attributes[attribute] : '';
		}).filter(Boolean).join(' ');

		return {
			html: html,
			text: plainTextFromHtml(html)
		};
	}

	function applySuggestionToBlock(clientId, item) {
		var store = wp.data.select('core/block-editor');
		var dispatch = wp.data.dispatch('core/block-editor');
		var root = store && store.getBlock ? store.getBlock(clientId) : null;
		if (!root || !dispatch || !dispatch.updateBlockAttributes) return false;

		function walk(block) {
			var attributes = smartLinkBlockAttributes[block.name] || [];
			for (var index = 0; index < attributes.length; index += 1) {
				var attribute = attributes[index];
				if (typeof block.attributes[attribute] !== 'string') continue;
				var changed = linkFirstTextMatch(block.attributes[attribute], item.anchor, item.url);
				if (changed.changed) {
					var update = {};
					update[attribute] = changed.html;
					dispatch.updateBlockAttributes(block.clientId, update);
					return true;
				}
			}

			for (var childIndex = 0; childIndex < (block.innerBlocks || []).length; childIndex += 1) {
				if (walk(block.innerBlocks[childIndex])) return true;
			}

			return false;
		}

		return walk(root);
	}

	function SmartLinkBlockMenu(props) {
		var state = useState({ items: [], loading: false, error: '' });
		var result = state[0];
		var setResult = state[1];
		var source = smartLinkBlockSource(props);

		function load() {
			if (source.text.length < 2) return;
			setResult({ items: [], loading: true, error: '' });
			fetchSmartLinks({
				post: currentPostId(),
				selected: '',
				context: source.text.slice(0, 1200),
				content: source.html,
				title: currentTitle(),
				mode: 'document'
			}).then(function (items) {
				setResult({ items: items, loading: false, error: '' });
			}).catch(function () {
				setResult({ items: [], loading: false, error: __('Não foi possível analisar este bloco.', 'go-verge') });
			});
		}

		return el(BlockControls, { group: 'block' },
			el(ToolbarGroup, null,
				el(Dropdown, {
					className: 'go-smart-link-block-dropdown',
					popoverProps: { placement: 'bottom-start', className: 'go-smart-link-popover' },
					renderToggle: function (toggleProps) {
						return el(ToolbarButton, {
							icon: 'admin-links',
							label: __('Sugerir link inteligente', 'go-verge'),
							isPressed: toggleProps.isOpen,
							onClick: function () {
								if (!toggleProps.isOpen) load();
								toggleProps.onToggle();
							}
						});
					},
					renderContent: function (contentProps) {
						return el('div', { className: 'go-smart-link-menu' },
							el('div', { className: 'go-smart-link-menu__head' },
								el('strong', null, __('Sugerir link inteligente', 'go-verge')),
								el('span', null, __('Sugestões para o bloco selecionado.', 'go-verge'))
							),
							result.loading ? el('div', { className: 'go-smart-link-menu__loading' }, el(Spinner)) : null,
							result.error ? el('p', { className: 'go-smart-link-menu__empty' }, result.error) : null,
							!result.loading && !result.error && !result.items.length
								? el('p', { className: 'go-smart-link-menu__empty' }, __('Nenhum link interno forte foi encontrado neste bloco.', 'go-verge'))
								: null,
							el('ul', { className: 'go-smart-link-menu__list' }, result.items.map(function (item) {
								return el('li', { key: item.id },
									el(Button, {
										variant: 'tertiary',
										onClick: function () {
											if (applySuggestionToBlock(props.clientId, item)) contentProps.onClose();
										}
									},
										el('strong', null, item.anchor ? '“' + item.anchor + '” → ' + item.title : item.title),
										el('span', null, item.reason || '')
									),
									el('span', { className: 'go-smart-link-menu__meta' }, (item.typeLabel || '') + ' · ' + (item.date || '') + ' · ' + (item.confidence || ''))
								);
							}))
						);
					}
				})
			)
		);
	}

	if (false && addFilter && createHigherOrderComponent && BlockControls && ToolbarGroup && ToolbarButton && Dropdown) {
		var withSmartLinkBlockMenu = createHigherOrderComponent(function (BlockEdit) {
			return function (props) {
				var supportsSmartLinks = !!smartLinkBlockAttributes[props.name];
				return el(Fragment, null,
					el(BlockEdit, props),
					props.isSelected && supportsSmartLinks && smartLinkBlockSource(props).text.length >= 2
						? el(SmartLinkBlockMenu, props)
						: null
				);
			};
		}, 'withGoVergeSmartLinkBlockMenu');

		addFilter('editor.BlockEdit', 'go-verge/smart-link-block-menu', withSmartLinkBlockMenu);
	}

	/* ------------------------------------------------------------------ */
	/* Aplicação segura de uma sugestão automática em bloco RichText      */
	/* ------------------------------------------------------------------ */

	function linkFirstTextMatch(html, anchor, url) {
		var holder = document.createElement('div');
		holder.innerHTML = String(html || '');
		var walker = document.createTreeWalker(holder, window.NodeFilter.SHOW_TEXT, null);
		var node;
		var wanted = String(anchor || '').toLocaleLowerCase('pt-BR');

		while ((node = walker.nextNode())) {
			if (!node.parentElement || node.parentElement.closest('a,code,pre,h1,h2,h3,h4,h5,h6,figcaption')) continue;
			var source = String(node.nodeValue || '');
			var position = source.toLocaleLowerCase('pt-BR').indexOf(wanted);
			if (position === -1) continue;

			var before = source.slice(0, position);
			var matched = source.slice(position, position + anchor.length);
			var after = source.slice(position + anchor.length);
			var link = document.createElement('a');
			link.href = url;
			link.textContent = matched;
			var fragment = document.createDocumentFragment();
			if (before) fragment.appendChild(document.createTextNode(before));
			fragment.appendChild(link);
			if (after) fragment.appendChild(document.createTextNode(after));
			node.parentNode.replaceChild(fragment, node);
			return { changed: true, html: holder.innerHTML };
		}

		return { changed: false, html: html };
	}

	function applySuggestionToBlocks(item) {
		var store = wp.data.select('core/block-editor');
		var dispatch = wp.data.dispatch('core/block-editor');
		if (!store || !dispatch || !store.getBlocks) return false;
		var allowed = {
			'core/paragraph': ['content'],
			'core/list-item': ['content'],
			'core/freeform': ['content'],
			'core/pullquote': ['value', 'citation'],
			'core/verse': ['content']
		};

		function walk(blocks) {
			for (var index = 0; index < blocks.length; index += 1) {
				var block = blocks[index];
				var attrs = allowed[block.name] || [];
				for (var attrIndex = 0; attrIndex < attrs.length; attrIndex += 1) {
					var attr = attrs[attrIndex];
					if (typeof block.attributes[attr] !== 'string') continue;
					var changed = linkFirstTextMatch(block.attributes[attr], item.anchor, item.url);
					if (changed.changed) {
						var update = {};
						update[attr] = changed.html;
						dispatch.updateBlockAttributes(block.clientId, update);
						return true;
					}
				}
				if (block.innerBlocks && block.innerBlocks.length && walk(block.innerBlocks)) return true;
			}
			return false;
		}

		return walk(store.getBlocks());
	}

	/* ------------------------------------------------------------------ */
	/* Painel do documento: mostra o que linkar e aplica em um clique      */
	/* ------------------------------------------------------------------ */

	if (registerPlugin && SettingPanel) {
		registerPlugin('go-verge-link-suggestions', {
			render: function () {
				var searchState = useState('');
				var search = searchState[0];
				var setSearch = searchState[1];
				var copiedState = useState(0);
				var copied = copiedState[0];
				var setCopied = copiedState[1];
				var smartState = useState({ items: [], loading: false, message: '' });
				var smart = smartState[0];
				var setSmart = smartState[1];
				var postId = currentPostId();
				var suggestions = useSuggestions(search, postId, [search, postId]);

				function analyze() {
					setSmart({ items: smart.items || [], loading: true, message: '' });
					fetchSmartLinks({
						post: postId,
						selected: '',
						context: currentTitle(),
						content: currentContent(),
						title: currentTitle(),
						mode: 'document'
					}).then(function (items) {
						setSmart({ items: items, loading: false, message: '' });
					}).catch(function () {
						setSmart({ items: [], loading: false, message: __('Não foi possível analisar o rascunho.', 'go-verge') });
					});
				}

				/* Full smart-link analysis is intentionally manual to keep editor startup responsive. */

				function applyItem(item) {
					if (applySuggestionToBlocks(item)) {
						setSmart({
							items: smart.items.filter(function (candidate) { return candidate.id !== item.id; }),
							loading: false,
							message: __('Link aplicado em “%s”.', 'go-verge').replace('%s', item.anchor)
						});
						return;
					}
					copyText(item.url, function () {
						setSmart({ items: smart.items, loading: false, message: __('Trecho não localizado no bloco; URL copiada.', 'go-verge') });
					});
				}

				function copy(item) {
					copyText(item.url, function () {
						setCopied(item.id);
						window.setTimeout(function () { setCopied(0); }, 1600);
					});
				}

				return el(SettingPanel, {
					name: 'go-verge-link-suggestions',
					title: __('Linkagem inteligente', 'go-verge'),
					className: 'go-link-suggestions'
				},
					el('p', { className: 'go-link-suggestions__help' },
						__('Selecione um termo no texto e use o botão de corrente na barra. Abaixo, o tema também aponta links que já podem ser aplicados.', 'go-verge')
					),
					el('div', { className: 'go-link-suggestions__toolbar' },
						el(Button, { variant: 'secondary', onClick: analyze, disabled: smart.loading },
							smart.loading ? __('Analisando…', 'go-verge') : __('Analisar matéria', 'go-verge')
						)
					),
					smart.message ? el('p', { className: 'go-link-suggestions__message' }, smart.message) : null,
					smart.loading ? el(Spinner) : null,
					!smart.loading && !smart.items.length
						? el('p', { className: 'go-link-suggestions__empty' }, __('Nenhum link interno forte foi encontrado no texto atual.', 'go-verge'))
						: null,
					el('ul', { className: 'go-smart-link-panel__list' }, smart.items.map(function (item) {
						return el('li', { key: item.id },
							el('span', { className: 'go-smart-link-panel__anchor' }, '“' + item.anchor + '”'),
							el('strong', null, item.title),
							el('span', { className: 'go-smart-link-panel__reason' }, item.reason || ''),
							el('div', { className: 'go-smart-link-panel__actions' },
								el(Button, { variant: 'primary', size: 'small', onClick: function () { applyItem(item); } }, __('Aplicar link', 'go-verge')),
								el('a', { href: item.url, target: '_blank', rel: 'noreferrer' }, __('Abrir', 'go-verge'))
							)
						);
					})),
					el('hr', { className: 'go-link-suggestions__divider' }),
					el(TextControl, {
						label: __('Buscar outro destino', 'go-verge'),
						placeholder: __('Nome do jogo, série, empresa ou assunto', 'go-verge'),
						value: search,
						onChange: setSearch
					}),
					suggestions.loading
						? el(Spinner)
						: el('ul', { className: 'go-link-suggestions__list' }, (suggestions.items || []).map(function (item) {
							return el('li', { key: item.id },
								el(Button, { variant: 'tertiary', onClick: function () { copy(item); } }, copied === item.id ? __('Link copiado', 'go-verge') : item.title),
								el('span', { className: 'go-link-suggestions__date' }, item.date)
							);
						}))
				);
			}
		});
	}
})(window.wp);
