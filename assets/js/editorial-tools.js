/**
 * Kit de ferramentas editoriais — lado do editor.
 *
 * 1. Painel "Foco da imagem destacada" na barra lateral do documento, com o
 *    marcador arrastável e mini-previews 16:9 / 1:1.
 * 2. Bloco go/before-after (comparador com slider) — render dinâmico no PHP.
 * 3. Bloco go/spoiler (details/summary estático, funciona sem JS no site).
 *
 * Sem build step: usa apenas os globals wp.* do editor.
 */
(function (wp) {
	'use strict';

	if (!wp || !wp.element || !wp.blocks || !wp.blockEditor) {
		return;
	}

	var el = wp.element.createElement;
	var Fragment = wp.element.Fragment;
	var useState = wp.element.useState;
	var useRef = wp.element.useRef;
	var __ = wp.i18n.__;
	var registerBlockType = wp.blocks.registerBlockType;
	var useBlockProps = wp.blockEditor.useBlockProps;
	var InnerBlocks = wp.blockEditor.InnerBlocks;
	var InspectorControls = wp.blockEditor.InspectorControls;
	var MediaUpload = wp.blockEditor.MediaUpload;
	var MediaUploadCheck = wp.blockEditor.MediaUploadCheck;
	var Button = wp.components.Button;
	var PanelBody = wp.components.PanelBody;
	var TextControl = wp.components.TextControl;
	var SelectControl = wp.components.SelectControl;
	var ToggleControl = wp.components.ToggleControl;
	var useSelect = wp.data.useSelect;
	var useEntityProp = wp.coreData ? wp.coreData.useEntityProp : null;
	var registerPlugin = wp.plugins ? wp.plugins.registerPlugin : null;
	var SettingPanel =
		(wp.editor && wp.editor.PluginDocumentSettingPanel) ||
		(wp.editPost && wp.editPost.PluginDocumentSettingPanel) ||
		null;

	function clamp(value, min, max) {
		return Math.min(max, Math.max(min, value));
	}

	/* ---------------------------------------------------------------------
	 * 1) Foco da imagem destacada
	 * ------------------------------------------------------------------ */
	function FocusPanel() {
		var postType = useSelect(function (select) {
			return select('core/editor').getCurrentPostType();
		}, []);
		var featuredId = useSelect(function (select) {
			return select('core/editor').getEditedPostAttribute('featured_media');
		}, []);
		var media = useSelect(
			function (select) {
				return featuredId ? select('core').getMedia(featuredId) : null;
			},
			[featuredId]
		);
		var metaPair = useEntityProp('postType', postType, 'meta');
		var meta = metaPair[0] || {};
		var setMeta = metaPair[1];
		var dragRef = useRef(false);

		var x = meta._go_thumb_focus_x !== '' && meta._go_thumb_focus_x !== undefined ? parseFloat(meta._go_thumb_focus_x) : null;
		var y = meta._go_thumb_focus_y !== '' && meta._go_thumb_focus_y !== undefined ? parseFloat(meta._go_thumb_focus_y) : null;
		var hasFocus = null !== x && !isNaN(x) && null !== y && !isNaN(y);
		var url = media && media.source_url ? media.source_url : '';

		function setFromEvent(event) {
			var bounds = event.currentTarget.getBoundingClientRect();
			var nx = clamp(((event.clientX - bounds.left) / bounds.width) * 100, 0, 100);
			var ny = clamp(((event.clientY - bounds.top) / bounds.height) * 100, 0, 100);
			setMeta({
				_go_thumb_focus_x: String(Math.round(nx * 100) / 100),
				_go_thumb_focus_y: String(Math.round(ny * 100) / 100)
			});
		}

		var body;
		if (!featuredId) {
			body = el('p', { style: { margin: 0, opacity: 0.75 } },
				__('Defina a imagem destacada para escolher o ponto focal dos cards.', 'go-verge'));
		} else if (!url) {
			body = el('p', { style: { margin: 0, opacity: 0.75 } }, __('Carregando imagem…', 'go-verge'));
		} else {
			var position = (hasFocus ? x : 50) + '% ' + (hasFocus ? y : 50) + '%';
			body = el(
				Fragment,
				null,
				el('p', { style: { marginTop: 0, fontSize: '12px', opacity: 0.8 } },
					__('Toque na foto para marcar o ponto que deve ficar sempre visível nos cards e listas.', 'go-verge')),
				el(
					'div',
					{
						role: 'presentation',
						onPointerDown: function (event) {
							dragRef.current = true;
							event.currentTarget.setPointerCapture(event.pointerId);
							setFromEvent(event);
						},
						onPointerMove: function (event) {
							if (dragRef.current) {
								setFromEvent(event);
							}
						},
						onPointerUp: function () {
							dragRef.current = false;
						},
						style: {
							position: 'relative',
							cursor: 'crosshair',
							lineHeight: 0,
							userSelect: 'none',
							touchAction: 'none',
							borderRadius: '6px',
							overflow: 'hidden'
						}
					},
					el('img', {
						src: url,
						alt: '',
						draggable: false,
						style: { width: '100%', height: 'auto', display: 'block' }
					}),
					hasFocus
						? el('span', {
							style: {
								position: 'absolute',
								left: x + '%',
								top: y + '%',
								width: '22px',
								height: '22px',
								transform: 'translate(-50%, -50%)',
								border: '3px solid #d8ff38',
								borderRadius: '50%',
								boxShadow: '0 0 0 2px rgba(0,0,0,.55), inset 0 0 0 2px rgba(0,0,0,.55)',
								pointerEvents: 'none'
							}
						})
						: null
				),
				el(
					'div',
					{ style: { display: 'grid', gridTemplateColumns: '1.45fr 1fr .8fr', gap: '8px', marginTop: '10px', alignItems: 'end' } },
					[
						{ label: __('Hero', 'go-verge'), ratio: '16 / 9' },
						{ label: __('Card', 'go-verge'), ratio: '16 / 9' },
						{ label: __('Sidebar', 'go-verge'), ratio: '16 / 9' }
					].map(function (preview) {
						return el('div', { key: preview.label, style: { minWidth: 0 } },
							el('span', { style: { display: 'block', marginBottom: '4px', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', opacity: .7 } }, preview.label),
							el('img', {
								src: url,
								alt: '',
								style: {
									width: '100%',
									aspectRatio: preview.ratio,
									objectFit: 'cover',
									objectPosition: position,
									borderRadius: '5px',
									border: '1px solid rgba(128,128,128,.35)'
								}
							})
						);
					})
				),
				el('p', { style: { margin: '6px 0 10px', fontSize: '11px', opacity: 0.65 } },
					__('Prévia 16:9 do mesmo ponto focal em hero, card e sidebar.', 'go-verge')),
				hasFocus
					? el(Button, {
						variant: 'tertiary',
						isDestructive: true,
						onClick: function () {
							setMeta({ _go_thumb_focus_x: '', _go_thumb_focus_y: '' });
						}
					}, __('Voltar ao enquadramento automático', 'go-verge'))
					: null
			);
		}

		return el(SettingPanel, {
			name: 'go-thumb-focus',
			title: __('Foco da imagem destacada', 'go-verge')
		}, body);
	}

	if (registerPlugin && SettingPanel && useEntityProp) {
		registerPlugin('go-editorial-tools-focus', { render: FocusPanel });
	}

	/* ---------------------------------------------------------------------
	 * 2) Bloco Antes/Depois
	 * ------------------------------------------------------------------ */
	function mediaButton(props, key, current, onSelect, label) {
		return el(MediaUploadCheck, { key: key },
			el(MediaUpload, {
				allowedTypes: ['image'],
				value: current,
				onSelect: onSelect,
				render: function (open) {
					return el(Button, {
						variant: current ? 'secondary' : 'primary',
						onClick: open.open,
						style: { width: '100%', justifyContent: 'center' }
					}, label);
				}
			})
		);
	}

	registerBlockType('go/before-after', {
		apiVersion: 2,
		title: __('Antes / Depois', 'go-verge'),
		description: __('Comparador com divisor arrastável entre duas imagens.', 'go-verge'),
		icon: 'image-flip-horizontal',
		category: 'media',
		keywords: [__('comparação', 'go-verge'), __('antes', 'go-verge'), __('depois', 'go-verge'), 'slider'],
		attributes: {
			beforeId: { type: 'number', default: 0 },
			afterId: { type: 'number', default: 0 },
			beforeLabel: { type: 'string', default: 'Antes' },
			afterLabel: { type: 'string', default: 'Depois' },
			caption: { type: 'string', default: '' }
		},
		supports: { html: false },
		edit: function (props) {
			var attrs = props.attributes;
			var beforeUrl = useSelect(function (select) {
				var m = attrs.beforeId ? select('core').getMedia(attrs.beforeId) : null;
				return m ? m.source_url : '';
			}, [attrs.beforeId]);
			var afterUrl = useSelect(function (select) {
				var m = attrs.afterId ? select('core').getMedia(attrs.afterId) : null;
				return m ? m.source_url : '';
			}, [attrs.afterId]);

			function slot(url, label) {
				return el('div', {
					style: {
						flex: '1 1 0',
						minWidth: 0,
						aspectRatio: '16 / 9',
						display: 'grid',
						placeItems: 'center',
						overflow: 'hidden',
						borderRadius: '8px',
						background: url ? 'transparent' : 'rgba(128,128,128,.15)',
						border: '1px dashed rgba(128,128,128,.4)',
						position: 'relative'
					}
				},
				url
					? el('img', { src: url, alt: '', style: { width: '100%', height: '100%', objectFit: 'cover' } })
					: el('span', { style: { fontSize: '12px', opacity: 0.7 } }, label));
			}

			return el(
				'div',
				useBlockProps({ style: { border: '1px solid rgba(128,128,128,.35)', borderRadius: '10px', padding: '14px' } }),
				el('div', { style: { fontWeight: 600, marginBottom: '10px' } }, __('Antes / Depois', 'go-verge')),
				el('div', { style: { display: 'flex', gap: '10px', marginBottom: '10px' } },
					slot(beforeUrl, attrs.beforeLabel || __('Antes', 'go-verge')),
					slot(afterUrl, attrs.afterLabel || __('Depois', 'go-verge'))
				),
				el('div', { style: { display: 'flex', gap: '10px' } },
					mediaButton(props, 'before', attrs.beforeId, function (media) {
						props.setAttributes({ beforeId: media.id });
					}, beforeUrl ? __('Trocar imagem “antes”', 'go-verge') : __('Escolher imagem “antes”', 'go-verge')),
					mediaButton(props, 'after', attrs.afterId, function (media) {
						props.setAttributes({ afterId: media.id });
					}, afterUrl ? __('Trocar imagem “depois”', 'go-verge') : __('Escolher imagem “depois”', 'go-verge'))
				),
				el(InspectorControls, null,
					el(PanelBody, { title: __('Rótulos', 'go-verge'), initialOpen: true },
						el(TextControl, {
							label: __('Rótulo da esquerda', 'go-verge'),
							value: attrs.beforeLabel,
							onChange: function (value) { props.setAttributes({ beforeLabel: value }); }
						}),
						el(TextControl, {
							label: __('Rótulo da direita', 'go-verge'),
							value: attrs.afterLabel,
							onChange: function (value) { props.setAttributes({ afterLabel: value }); }
						}),
						el(TextControl, {
							label: __('Legenda (opcional)', 'go-verge'),
							value: attrs.caption,
							onChange: function (value) { props.setAttributes({ caption: value }); }
						})
					)
				)
			);
		},
		save: function () {
			return null;
		}
	});

	/* ---------------------------------------------------------------------
	 * 3) Bloco CTA editorial
	 * ------------------------------------------------------------------ */
	var CTA_PRESETS = [
		{ key: 'gnews', label: 'Google News', icon: 'news', title: 'Acompanhe o Overdrive no Google News', button: 'Seguir no Google News' },
		{ key: 'whatsapp', label: 'WhatsApp', icon: 'whatsapp', title: 'Receba as notícias no canal do WhatsApp', button: 'Entrar no canal' },
		{ key: 'youtube', label: 'YouTube', icon: 'youtube', title: 'Vídeos, gameplays e análises no YouTube', button: 'Inscrever-se' },
		{ key: 'newsletter', label: 'Newsletter', icon: 'mail', title: 'O melhor da semana direto no seu e-mail', button: 'Assinar a newsletter' }
	];

	registerBlockType('go/cta', {
		apiVersion: 2,
		title: __('CTA editorial', 'go-verge'),
		description: __('Chamada com botão verde: seguir, assinar ou abrir um link.', 'go-verge'),
		icon: 'megaphone',
		category: 'design',
		keywords: ['cta', __('chamada', 'go-verge'), __('botão', 'go-verge'), 'google news', 'whatsapp'],
		attributes: {
			title: { type: 'string', default: '' },
			text: { type: 'string', default: '' },
			buttonLabel: { type: 'string', default: 'Saiba mais' },
			url: { type: 'string', default: '' },
			icon: { type: 'string', default: 'none' },
			variant: { type: 'string', default: 'panel' },
			newTab: { type: 'boolean', default: true },
			sponsored: { type: 'boolean', default: false }
		},
		supports: { html: false },
		edit: function (props) {
			var attrs = props.attributes;

			return el(
				'div',
				useBlockProps({
					style: {
						border: '1px solid rgba(128,128,128,.35)',
						borderLeft: '4px solid #d8ff38',
						borderRadius: '10px',
						padding: '14px 16px'
					}
				}),
				el('div', { style: { display: 'flex', gap: '6px', flexWrap: 'wrap', marginBottom: '12px' } },
					CTA_PRESETS.map(function (preset) {
						return el(Button, {
							key: preset.key,
							variant: 'secondary',
							size: 'small',
							onClick: function () {
								props.setAttributes({
									icon: preset.icon,
									title: preset.title,
									buttonLabel: preset.button
								});
							}
						}, preset.label);
					})
				),
				el(TextControl, {
					label: __('Título', 'go-verge'),
					value: attrs.title,
					onChange: function (value) { props.setAttributes({ title: value }); }
				}),
				el(TextControl, {
					label: __('Texto de apoio (opcional)', 'go-verge'),
					value: attrs.text,
					onChange: function (value) { props.setAttributes({ text: value }); }
				}),
				el('div', { style: { display: 'flex', gap: '10px' } },
					el('div', { style: { flex: '1 1 0' } }, el(TextControl, {
						label: __('Texto do botão', 'go-verge'),
						value: attrs.buttonLabel,
						onChange: function (value) { props.setAttributes({ buttonLabel: value }); }
					})),
					el('div', { style: { flex: '2 1 0' } }, el(TextControl, {
						label: __('Link (URL)', 'go-verge'),
						value: attrs.url,
						placeholder: 'https://…',
						onChange: function (value) { props.setAttributes({ url: value }); }
					}))
				),
				attrs.url ? null : el('p', { style: { margin: '2px 0 0', fontSize: '11px', color: '#b45309' } },
					__('Informe o link — sem URL o CTA não aparece no site.', 'go-verge')),
				el(InspectorControls, null,
					el(PanelBody, { title: __('Aparência', 'go-verge'), initialOpen: true },
						el(SelectControl, {
							label: __('Ícone', 'go-verge'),
							value: attrs.icon,
							options: [
								{ value: 'none', label: __('Sem ícone', 'go-verge') },
								{ value: 'news', label: 'Google News / notícias' },
								{ value: 'whatsapp', label: 'WhatsApp' },
								{ value: 'youtube', label: 'YouTube' },
								{ value: 'mail', label: 'Newsletter / e-mail' },
								{ value: 'cart', label: __('Compras', 'go-verge') },
								{ value: 'star', label: __('Destaque', 'go-verge') }
							],
							onChange: function (value) { props.setAttributes({ icon: value }); }
						}),
						el(SelectControl, {
							label: __('Formato', 'go-verge'),
							value: attrs.variant,
							options: [
								{ value: 'panel', label: __('Painel destacado', 'go-verge') },
								{ value: 'strip', label: __('Faixa compacta', 'go-verge') }
							],
							onChange: function (value) { props.setAttributes({ variant: value }); }
						}),
						el(ToggleControl, {
							label: __('Abrir em nova aba', 'go-verge'),
							checked: !!attrs.newTab,
							onChange: function (value) { props.setAttributes({ newTab: !!value }); }
						}),
						el(ToggleControl, {
							label: __('Link patrocinado (rel sponsored)', 'go-verge'),
							help: __('Ative para links de afiliado ou publicidade.', 'go-verge'),
							checked: !!attrs.sponsored,
							onChange: function (value) { props.setAttributes({ sponsored: !!value }); }
						})
					)
				)
			);
		},
		save: function () {
			return null;
		}
	});

	/* ---------------------------------------------------------------------
	 * 4) Bloco "Em resumo" (TL;DR)
	 * ------------------------------------------------------------------ */
	registerBlockType('go/tldr', {
		apiVersion: 2,
		title: __('Em resumo', 'go-verge'),
		description: __('Box com os pontos essenciais da matéria, logo no topo.', 'go-verge'),
		icon: 'editor-ul',
		category: 'text',
		keywords: ['tldr', __('resumo', 'go-verge'), __('destaques', 'go-verge')],
		attributes: {
			label: { type: 'string', default: 'Em resumo' }
		},
		supports: { html: false },
		edit: function (props) {
			return el(
				'div',
				useBlockProps({
					style: {
						border: '1px solid rgba(128,128,128,.35)',
						borderLeft: '4px solid #d8ff38',
						borderRadius: '10px',
						padding: '12px 16px'
					}
				}),
				el(TextControl, {
					label: __('Rótulo do box', 'go-verge'),
					value: props.attributes.label,
					onChange: function (value) { props.setAttributes({ label: value }); }
				}),
				el(InnerBlocks, {
					allowedBlocks: ['core/list', 'core/paragraph'],
					template: [['core/list', {}]]
				})
			);
		},
		save: function (props) {
			return el(
				'aside',
				useBlockProps.save({ className: 'go-tldr' }),
				el('span', { className: 'go-tldr__kicker' }, props.attributes.label),
				el('div', { className: 'go-tldr__content' }, el(InnerBlocks.Content, null))
			);
		}
	});

	/* ---------------------------------------------------------------------
	 * 5) Bloco "Ver na loja" — nome da loja + link = botão pronto.
	 * ------------------------------------------------------------------ */
	function storeButtonLabel(attrs) {
		return 'Ver ' + (attrs.prep || 'na') + ' ' + (attrs.store || '…');
	}

	function isAffiliateStoreUrl(url) {
		return /amazon\.|amzn\.|mercadoliv/i.test(url || '');
	}

	registerBlockType('go/store-button', {
		apiVersion: 2,
		title: __('Ver na loja', 'go-verge'),
		description: __('Botão de loja com o visual do Overdrive. Preserve o link de afiliado e identifique a loja.', 'go-verge'),
		icon: 'button',
		category: 'design',
		keywords: ['ver', 'loja', __('botão', 'go-verge'), 'comprar', 'link'],
		attributes: {
			store: { type: 'string', default: '' },
			prep: { type: 'string', default: 'na' },
			url: { type: 'string', default: '' }
		},
		supports: { html: false },
		edit: function (props) {
			var attrs = props.attributes;
			return el(
				'div',
				useBlockProps({ style: { border: '1px dashed rgba(128,128,128,.45)', borderRadius: '10px', padding: '12px 14px' } }),
				el('div', { style: { display: 'flex', gap: '10px', alignItems: 'flex-end', flexWrap: 'wrap' } },
					el('div', { style: { width: '90px' } }, el(SelectControl, {
						label: __('Ver…', 'go-verge'),
						value: attrs.prep,
						options: [
							{ value: 'na', label: 'na' },
							{ value: 'no', label: 'no' },
							{ value: 'em', label: 'em' }
						],
						onChange: function (value) { props.setAttributes({ prep: value }); }
					})),
					el('div', { style: { flex: '1 1 140px' } }, el(TextControl, {
						label: __('Nome da loja', 'go-verge'),
						placeholder: 'Amazon, Steam, Nuuvem…',
						value: attrs.store,
						onChange: function (value) { props.setAttributes({ store: value }); }
					})),
					el('div', { style: { flex: '2 1 220px' } }, el(TextControl, {
						label: __('Link', 'go-verge'),
						placeholder: 'https://…',
						value: attrs.url,
						onChange: function (value) { props.setAttributes({ url: value }); }
					}))
				),
				el('div', { style: { marginTop: '10px', display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' } },
					el('span', {
						style: {
							display: 'inline-flex',
							alignItems: 'center',
							gap: '9px',
							minHeight: '46px',
							padding: '11px 20px',
							borderRadius: '9px',
							background: '#111015',
							color: '#ffffff',
							fontSize: '13px',
							fontWeight: 700
						}
					}, storeButtonLabel(attrs) + ' →'),
					isAffiliateStoreUrl(attrs.url)
						? el('span', { style: { fontSize: '10px', letterSpacing: '.08em', textTransform: 'uppercase', opacity: 0.65 } },
							__('link patrocinado', 'go-verge'))
						: null
				),
				isAffiliateStoreUrl(attrs.url)
					? el('p', { style: { margin: '6px 0 0', fontSize: '11px', opacity: 0.7 } },
						__('Link de afiliado detectado: o selo "link patrocinado" será exibido e a tag de comissão entra automaticamente.', 'go-verge'))
					: null,
				attrs.url ? null : el('p', { style: { margin: '6px 0 0', fontSize: '11px', color: '#b45309' } },
					__('Sem link o botão não aparece no site.', 'go-verge'))
			);
		},
		save: function (props) {
			var attrs = props.attributes;
			if (!attrs.url) {
				return null;
			}
			var affiliate = isAffiliateStoreUrl(attrs.url);
			return el(
				'div',
				useBlockProps.save({ className: 'go-store-button-wrap' + (affiliate ? ' go-store-button-wrap--sponsored' : '') }),
				el('a', { className: 'go-store-button', href: attrs.url, target: '_blank', rel: affiliate ? 'sponsored nofollow noopener' : 'noopener' },
					storeButtonLabel(attrs),
					el('svg', { viewBox: '0 0 20 20', width: 16, height: 16, 'aria-hidden': 'true' },
						el('path', { d: 'M4 10h11m-4-4 4 4-4 4', fill: 'none', stroke: 'currentColor', strokeWidth: '1.8', strokeLinecap: 'round', strokeLinejoin: 'round' }))
				),
				affiliate
					? el('span', { className: 'go-store-button-note' }, 'link patrocinado')
					: null
			);
		}
	});

	/* ---------------------------------------------------------------------
	 * 6) Bloco Spoiler
	 * ------------------------------------------------------------------ */
	registerBlockType('go/spoiler', {
		apiVersion: 2,
		title: __('Spoiler', 'go-verge'),
		description: __('O trecho fica fechado até o leitor tocar em revelar.', 'go-verge'),
		icon: 'hidden',
		category: 'text',
		keywords: ['spoiler', __('revelar', 'go-verge'), __('crítica', 'go-verge')],
		attributes: {
			label: { type: 'string', default: 'Contém spoilers — toque para revelar' }
		},
		supports: { html: false },
		edit: function (props) {
			return el(
				'div',
				useBlockProps({ style: { border: '1px dashed rgba(128,128,128,.5)', borderRadius: '10px', padding: '12px 14px' } }),
				el(TextControl, {
					label: __('Aviso exibido ao leitor', 'go-verge'),
					value: props.attributes.label,
					onChange: function (value) { props.setAttributes({ label: value }); }
				}),
				el('div', { style: { fontSize: '11px', opacity: 0.65, margin: '2px 0 10px' } },
					__('O conteúdo abaixo só aparece no site depois que o leitor toca no aviso.', 'go-verge')),
				el(InnerBlocks, null)
			);
		},
		save: function (props) {
			return el(
				'details',
				useBlockProps.save({ className: 'go-spoiler' }),
				el('summary', { className: 'go-spoiler__summary' }, props.attributes.label),
				el('div', { className: 'go-spoiler__content' }, el(InnerBlocks.Content, null))
			);
		}
	});
})(window.wp);
