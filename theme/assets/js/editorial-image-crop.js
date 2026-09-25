/**
 * Recorte editorial de imagens (estilo Multicontent).
 *
 * Adiciona o botão "Recorte" ao bloco de imagem: um modal mostra a foto com um
 * retângulo arrastável (com presets de proporção) e o recorte escolhido é
 * exatamente o que a matéria renderiza. Sem build step: usa apenas os globals
 * wp.* do editor.
 */
(function (wp) {
	'use strict';

	if (!wp || !wp.hooks || !wp.element || !wp.blockEditor) {
		return;
	}

	var el = wp.element.createElement;
	var Fragment = wp.element.Fragment;
	var useState = wp.element.useState;
	var useRef = wp.element.useRef;
	var useEffect = wp.element.useEffect;
	var addFilter = wp.hooks.addFilter;
	var __ = wp.i18n.__;
	var BlockControls = wp.blockEditor.BlockControls;
	var InspectorControls = wp.blockEditor.InspectorControls;
	var ToolbarGroup = wp.components.ToolbarGroup;
	var ToolbarButton = wp.components.ToolbarButton;
	var Modal = wp.components.Modal;
	var Button = wp.components.Button;
	var PanelBody = wp.components.PanelBody;
	var SelectControl = wp.components.SelectControl;
	var createHigherOrderComponent = wp.compose.createHigherOrderComponent;

	var FRAME_RATIOS = {
		'16x9': '16 / 9',
		'4x3': '4 / 3',
		'1x1': '1 / 1',
		'3x2': '3 / 2'
	};

	var ASPECTS = [
		{ key: 'free', label: __('Livre', 'go-verge'), value: 0 },
		{ key: '16x9', label: '16:9', value: 16 / 9 },
		{ key: '4x3', label: '4:3', value: 4 / 3 },
		{ key: '1x1', label: '1:1', value: 1 },
		{ key: '4x5', label: '4:5', value: 4 / 5 },
		{ key: '9x16', label: '9:16', value: 9 / 16 }
	];

	function clamp(value, min, max) {
		return Math.min(max, Math.max(min, value));
	}

	function round2(value) {
		return Math.round(value * 100) / 100;
	}

	var RATIO_169 = 16 / 9;

	/* The stored `ratio` is the crop rectangle's TRUE pixel aspect ratio, which
	   is not w/h: w and h are percentages of two different denominators. It is
	   derived from the values that are actually persisted (already rounded), so
	   the frame the renderer builds and the rectangle object-view-box selects
	   describe the same shape and `object-fit: cover` has nothing left to trim. */
	function cropRatio(rect, natural) {
		var w = (rect.w / 100) * natural.w;
		var h = (rect.h / 100) * natural.h;
		return h > 0 ? Math.round((w / h) * 10000) / 10000 : RATIO_169;
	}

	/* naturalWidth/naturalHeight of an <img>, or null.
	   A decoded, cached image is `complete` before React can attach onLoad, so
	   this is read directly instead of waiting for an event that never fires. */
	function naturalOf(img) {
		return img && img.complete && img.naturalWidth && img.naturalHeight
			? { w: img.naturalWidth, h: img.naturalHeight }
			: null;
	}

	/* Corte 16:9 centralizado — usado quando a imagem não pode ser analisada. */
	function centerCrop169(imgRatio) {
		if (!imgRatio || !isFinite(imgRatio) || imgRatio <= 0) { return null; }
		var natural = { w: imgRatio, h: 1 };
		var rect;
		if (imgRatio > RATIO_169) {
			var w = (RATIO_169 / imgRatio) * 100;
			rect = { x: round2((100 - w) / 2), y: 0, w: round2(w), h: 100 };
		} else if (imgRatio < RATIO_169) {
			var h = (imgRatio / RATIO_169) * 100;
			rect = { x: 0, y: round2((100 - h) / 2), w: 100, h: round2(h) };
		} else {
			rect = { x: 0, y: 0, w: 100, h: 100 };
		}
		/* Derived from the ROUNDED rectangle, not from the ideal 1.7778: the
		   renderer builds the frame from these same rounded percentages, and a
		   ratio that disagrees with them by even 0,3% makes `cover` shave a
		   sliver the editor never showed. */
		rect.ratio = cropRatio(rect, natural);
		return rect;
	}

	/* Melhor corte 16:9: desenha a imagem num canvas pequeno, mede a energia de
	   bordas de cada faixa e escolhe a janela 16:9 com mais detalhe. Recai para
	   o corte central se o canvas não puder ser lido (imagem de outro domínio). */
	function smartCrop169(image) {
		var nw = image.naturalWidth, nh = image.naturalHeight;
		if (!nw || !nh) { return null; }
		var imgRatio = nw / nh;
		if (Math.abs(imgRatio - RATIO_169) < 0.02) { return centerCrop169(imgRatio); }

		var sw = 160;
		var sh = Math.max(1, Math.round(sw * nh / nw));
		var canvas = document.createElement('canvas');
		canvas.width = sw; canvas.height = sh;
		var ctx = canvas.getContext('2d');
		var data;
		try {
			ctx.drawImage(image, 0, 0, sw, sh);
			data = ctx.getImageData(0, 0, sw, sh).data;
		} catch (e) {
			return centerCrop169(imgRatio);
		}

		var lum = new Float32Array(sw * sh);
		for (var i = 0; i < sw * sh; i++) {
			var p = i * 4;
			lum[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2];
		}
		var sal = new Float32Array(sw * sh);
		for (var y = 0; y < sh; y++) {
			for (var x = 0; x < sw; x++) {
				var idx = y * sw + x;
				var gx = Math.abs(lum[idx] - lum[y * sw + Math.min(sw - 1, x + 1)]);
				var gy = Math.abs(lum[idx] - lum[Math.min(sh - 1, y + 1) * sw + x]);
				sal[idx] = gx + gy + 1;
			}
		}
		var integ = new Float64Array((sw + 1) * (sh + 1));
		for (var yy = 1; yy <= sh; yy++) {
			var rowSum = 0;
			for (var xx = 1; xx <= sw; xx++) {
				rowSum += sal[(yy - 1) * sw + (xx - 1)];
				integ[yy * (sw + 1) + xx] = integ[(yy - 1) * (sw + 1) + xx] + rowSum;
			}
		}
		function rectSum(x0, y0, x1, y1) {
			return integ[y1 * (sw + 1) + x1] - integ[y0 * (sw + 1) + x1] - integ[y1 * (sw + 1) + x0] + integ[y0 * (sw + 1) + x0];
		}

		if (imgRatio > RATIO_169) {
			var cw = Math.round(sh * RATIO_169);
			var bestX = 0, bestScore = -1;
			for (var wx = 0; wx + cw <= sw; wx++) {
				var s = rectSum(wx, 0, wx + cw, sh);
				if (s > bestScore) { bestScore = s; bestX = wx; }
			}
			var wide = { x: round2(bestX / sw * 100), y: 0, w: round2(cw / sw * 100), h: 100 };
			wide.ratio = cropRatio(wide, { w: nw, h: nh });
			return wide;
		}
		var ch = Math.round(sw / RATIO_169);
		var bestY = 0, best = -1;
		for (var wy = 0; wy + ch <= sh; wy++) {
			var sc = rectSum(0, wy, sw, wy + ch);
			if (sc > best) { best = sc; bestY = wy; }
		}
		var tall = { x: 0, y: round2(bestY / sh * 100), w: 100, h: round2(ch / sh * 100) };
		tall.ratio = cropRatio(tall, { w: nw, h: nh });
		return tall;
	}

	/* Aplica o melhor corte 16:9 ao bloco. */
	function applyAuto169(props) {
		function apply(image) {
			var crop = smartCrop169(image);
			if (crop) {
				props.setAttributes({ goCrop: crop, goFrame: undefined });
			}
		}
		var onPage = document.querySelector('[data-block="' + props.clientId + '"] img');
		if (onPage && onPage.naturalWidth) {
			apply(onPage);
			return;
		}
		var fresh = new Image();
		fresh.crossOrigin = 'anonymous';
		fresh.onload = function () { apply(fresh); };
		fresh.onerror = function () {
			if (!onPage || !onPage.naturalWidth || !onPage.naturalHeight) { return; }
			var fallbackCrop = centerCrop169(onPage.naturalWidth / onPage.naturalHeight);
			if (fallbackCrop) { props.setAttributes({ goCrop: fallbackCrop, goFrame: undefined }); }
		};
		fresh.src = props.attributes.url;
	}

	/*
	 * Smart crop em lote para o botão do painel "Go Editorial".
	 * Analisa todos os blocos core/image do post (inclusive dentro de groups e
	 * galleries modernos), calcula o melhor 16:9 e grava tudo em uma única ação
	 * do block editor. A imagem original nunca é sobrescrita.
	 */
	function collectArticleImageBlocks(blocks, out) {
		out = out || [];
		(blocks || []).forEach(function (block) {
			if (!block) {
				return;
			}
			if (block.name === 'core/image' && block.clientId && block.attributes && block.attributes.url) {
				out.push(block);
			}
			if (Array.isArray(block.innerBlocks) && block.innerBlocks.length) {
				collectArticleImageBlocks(block.innerBlocks, out);
			}
		});
		return out;
	}

	function smartCropBlock169(block) {
		return new Promise(function (resolve) {
			var attrs = block && block.attributes ? block.attributes : {};
			var url = attrs.url || '';
			if (!url) {
				resolve(null);
				return;
			}

			var onPage = document.querySelector('[data-block="' + block.clientId + '"] img');
			var fallback = function () {
				if (onPage && onPage.naturalWidth && onPage.naturalHeight) {
					resolve(centerCrop169(onPage.naturalWidth / onPage.naturalHeight));
					return;
				}
				var width = Number(attrs.width || 0);
				var height = Number(attrs.height || 0);
				if (width > 0 && height > 0) {
					resolve(centerCrop169(width / height));
					return;
				}

				/* Última tentativa sem CORS: não permite ler pixels, mas recupera a
				 * proporção natural para um corte central seguro. */
				var plain = new Image();
				plain.onload = function () {
					resolve(plain.naturalWidth && plain.naturalHeight
						? centerCrop169(plain.naturalWidth / plain.naturalHeight)
						: null);
				};
				plain.onerror = function () { resolve(null); };
				plain.src = url;
			};

			/* Tenta primeiro uma leitura real dos pixels. Em CDN com CORS habilitado,
			 * isso mantém o smart crop; se o servidor bloquear CORS, cai no centro. */
			var fresh = new Image();
			fresh.crossOrigin = 'anonymous';
			fresh.onload = function () {
				var crop = smartCrop169(fresh);
				resolve(crop || centerCrop169(fresh.naturalWidth / fresh.naturalHeight));
			};
			fresh.onerror = fallback;
			fresh.src = url;
		});
	}

	function bindBulkSmartCropControls() {
		var buttons = document.querySelectorAll('[data-go-smart-crop-all]');
		if (!buttons.length || !wp.data || !wp.data.select || !wp.data.dispatch) {
			return;
		}

		var selector = wp.data.select('core/block-editor');
		var dispatcher = wp.data.dispatch('core/block-editor');
		if (!selector || !selector.getBlocks || !dispatcher || !dispatcher.updateBlockAttributes) {
			return;
		}

		buttons.forEach(function (button) {
			if (button.dataset.goSmartCropBound === '1') {
				return;
			}
			button.dataset.goSmartCropBound = '1';
			button.hidden = false;

			var panel = button.closest('[data-go-smart-crop-panel]');
			var status = panel ? panel.querySelector('[data-go-smart-crop-status]') : null;
			var label = button.querySelector('[data-go-smart-crop-label]');
			var idleText = status ? status.textContent : '';
			var idleButtonText = label ? label.textContent : '';
			var restoreTimer = 0;

			function setButtonState(state, text) {
				button.classList.remove('is-running', 'is-success', 'is-error');
				if (state) { button.classList.add(state); }
				if (label && text) { label.textContent = text; }
			}

			function scheduleRestore(delay) {
				window.clearTimeout(restoreTimer);
				restoreTimer = window.setTimeout(function () {
					if (button.disabled) { return; }
					setButtonState('', idleButtonText);
					if (panel) { panel.classList.remove('is-success', 'is-error'); }
					if (status) { status.textContent = idleText; }
				}, delay || 5000);
			}

			button.addEventListener('click', function () {
				var blocks = collectArticleImageBlocks(selector.getBlocks(), []);
				if (!blocks.length) {
					if (status) { status.textContent = __('Nenhuma foto no conteúdo para ajustar.', 'go-verge'); }
					if (panel) {
						panel.classList.remove('is-running', 'is-success');
						panel.classList.add('is-error');
					}
					setButtonState('is-error', __('Sem fotos no conteúdo', 'go-verge'));
					scheduleRestore(2600);
					return;
				}

				button.disabled = true;
				button.setAttribute('aria-busy', 'true');
				setButtonState('is-running', __('Analisando', 'go-verge') + ' 0/' + blocks.length);
				if (panel) {
					panel.classList.remove('is-success', 'is-error');
					panel.classList.add('is-running');
				}

				var completed = 0;
				var updates = [];
				if (status) { status.textContent = sprintfBulkStatus(0, blocks.length); }

				Promise.all(blocks.map(function (block) {
					return smartCropBlock169(block).then(function (crop) {
						completed += 1;
						if (status) { status.textContent = sprintfBulkStatus(completed, blocks.length); }
						if (label) { label.textContent = __('Analisando', 'go-verge') + ' ' + completed + '/' + blocks.length; }
						if (crop) { updates.push({ clientId: block.clientId, crop: crop }); }
					});
				})).then(function () {
					if (updates.length) {
						var ids = [];
						var byId = {};
						updates.forEach(function (item) {
							ids.push(item.clientId);
							byId[item.clientId] = { goCrop: item.crop, goFrame: undefined };
						});
						dispatcher.updateBlockAttributes(ids, byId, { uniqueByBlock: true });
					}

					button.disabled = false;
					button.removeAttribute('aria-busy');
					if (panel) {
						panel.classList.remove('is-running', 'is-error');
						panel.classList.add(updates.length ? 'is-success' : 'is-error');
					}
					if (status) {
						status.textContent = updates.length
							? (updates.length + (updates.length === 1 ? ' foto ajustada para 16:9.' : ' fotos ajustadas para 16:9.'))
							: __('Não foi possível analisar as fotos.', 'go-verge');
					}
					setButtonState(
						updates.length ? 'is-success' : 'is-error',
						updates.length
							? (updates.length + (updates.length === 1 ? ' foto em 16:9' : ' fotos em 16:9'))
							: __('Falha no Smart Crop', 'go-verge')
					);
					scheduleRestore(5200);
				}).catch(function () {
					button.disabled = false;
					button.removeAttribute('aria-busy');
					if (panel) {
						panel.classList.remove('is-running', 'is-success');
						panel.classList.add('is-error');
					}
					if (status) { status.textContent = __('Falha ao aplicar o smart crop.', 'go-verge'); }
					setButtonState('is-error', __('Tente novamente', 'go-verge'));
					scheduleRestore(4200);
				});
			});
		});
	}

	function sprintfBulkStatus(done, total) {
		return __('Analisando fotos', 'go-verge') + '… ' + done + '/' + total;
	}

	/* 1) Atributo persistido no bloco de imagem. */
	addFilter('blocks.registerBlockType', 'go-verge/image-crop-attributes', function (settings, name) {
		if (name !== 'core/image') {
			return settings;
		}
		settings.attributes = Object.assign({}, settings.attributes, {
			goCrop: { type: 'object' },
			goFrame: { type: 'object' }
		});
		return settings;
	});

	/* Caixa de recorte com alças e presets. */
	function CropModal(props) {
		var initial = props.crop && props.crop.w
			? { x: props.crop.x, y: props.crop.y, w: props.crop.w, h: props.crop.h }
			: { x: 10, y: 10, w: 80, h: 80 };
		var rectState = useState(initial);
		var rect = rectState[0];
		var setRect = rectState[1];
		var aspectState = useState('free');
		var aspectKey = aspectState[0];
		var setAspectKey = aspectState[1];
		var naturalState = useState(null);
		var natural = naturalState[0];
		var setNatural = naturalState[1];
		var frameRef = useRef(null);
		var dragRef = useRef(null);
		var imgRef = useRef(null);

		/*
		 * THE BUG THIS EXISTS TO KILL.
		 *
		 * `natural` used to be set only from the <img onLoad> handler. The photo
		 * in this modal has, in the ordinary case, just been rendered in the
		 * editor canvas, so it is already decoded in the browser cache and the
		 * element reaches `complete` BEFORE React attaches the handler -- onLoad
		 * then never fires. With `natural` stuck at null:
		 *
		 *   applyAspect()  returned early  -> the 16:9/4:3 buttons did nothing
		 *   save()         returned early  -> "Aplicar recorte" closed the modal
		 *                                     and silently discarded the crop
		 *
		 * That is the intermittent "the crop sometimes does not work": it failed
		 * exactly when the image was cached, which is most of the time, and it
		 * failed without an error. The size is now read straight off the element
		 * whenever it is available, and onLoad is only the fallback path.
		 */
		function adoptNatural(img) {
			var size = naturalOf(img);
			if (size && (!natural || natural.w !== size.w || natural.h !== size.h)) {
				setNatural(size);
			}
			return size;
		}

		useEffect(function () {
			if (natural) { return undefined; }
			var img = imgRef.current;
			if (adoptNatural(img)) { return undefined; }
			/* Not decoded yet: poll briefly as a belt-and-braces guard against a
			   decode that completes between render and event binding. */
			var tries = 0;
			var timer = window.setInterval(function () {
				tries++;
				if (adoptNatural(imgRef.current) || tries > 40) { window.clearInterval(timer); }
			}, 50);
			return function () { window.clearInterval(timer); };
		}, [natural, props.url]);

		function aspectValue(key) {
			for (var i = 0; i < ASPECTS.length; i++) {
				if (ASPECTS[i].key === key) {
					return ASPECTS[i].value;
				}
			}
			return 0;
		}

		/* Converte proporção em pixels para proporção percentual da imagem. */
		function percentHeightFor(widthPercent, pixelAspect) {
			if (!natural || !pixelAspect) {
				return null;
			}
			return (widthPercent * natural.w) / (pixelAspect * natural.h);
		}

		function applyAspect(key) {
			setAspectKey(key);
			var aspect = aspectValue(key);
			if (!aspect || !natural) {
				return;
			}
			var w = 100;
			var h = percentHeightFor(w, aspect);
			if (h > 100) {
				w = w * (100 / h);
				h = 100;
			}
			w = clamp(w, 5, 100);
			h = clamp(h, 5, 100);
			setRect({ x: (100 - w) / 2, y: (100 - h) / 2, w: w, h: h });
		}

		function beginDrag(event, mode) {
			event.preventDefault();
			event.stopPropagation();
			var frame = frameRef.current;
			if (!frame) {
				return;
			}
			var bounds = frame.getBoundingClientRect();
			if (event.currentTarget && event.currentTarget.setPointerCapture && event.pointerId !== undefined) {
				try { event.currentTarget.setPointerCapture(event.pointerId); } catch (e) { /* non-fatal */ }
			}
			dragRef.current = {
				mode: mode,
				startX: event.clientX,
				startY: event.clientY,
				bounds: bounds,
				start: { x: rect.x, y: rect.y, w: rect.w, h: rect.h }
			};
		}

		useEffect(function () {
			function onMove(event) {
				var drag = dragRef.current;
				if (!drag) {
					return;
				}
				event.preventDefault();
				var dx = ((event.clientX - drag.startX) / drag.bounds.width) * 100;
				var dy = ((event.clientY - drag.startY) / drag.bounds.height) * 100;
				var start = drag.start;
				var next = { x: start.x, y: start.y, w: start.w, h: start.h };
				var aspect = aspectValue(aspectKey);

				if ('move' === drag.mode) {
					next.x = clamp(start.x + dx, 0, 100 - start.w);
					next.y = clamp(start.y + dy, 0, 100 - start.h);
					setRect(next);
					return;
				}

				var east = drag.mode.indexOf('e') !== -1;
				var west = drag.mode.indexOf('w') !== -1;
				var south = drag.mode.indexOf('s') !== -1;
				var north = drag.mode.indexOf('n') !== -1;

				if (east) {
					next.w = clamp(start.w + dx, 5, 100 - start.x);
				}
				if (west) {
					var newX = clamp(start.x + dx, 0, start.x + start.w - 5);
					next.w = start.w + (start.x - newX);
					next.x = newX;
				}
				if (south) {
					next.h = clamp(start.h + dy, 5, 100 - start.y);
				}
				if (north) {
					var newY = clamp(start.y + dy, 0, start.y + start.h - 5);
					next.h = start.h + (start.y - newY);
					next.y = newY;
				}

				if (aspect && natural) {
					var lockedH = percentHeightFor(next.w, aspect);
					if (null !== lockedH) {
						if (north) {
							next.y = clamp(start.y + start.h - lockedH, 0, 100);
							next.h = start.y + start.h - next.y;
							next.w = (next.h * aspect * natural.h) / natural.w;
							if (west) {
								next.x = start.x + start.w - next.w;
							}
						} else {
							next.h = lockedH;
						}
						if (next.y + next.h > 100) {
							next.h = 100 - next.y;
							next.w = (next.h * aspect * natural.h) / natural.w;
							if (west) {
								next.x = start.x + start.w - next.w;
							}
						}
					}
				}

				next.x = clamp(next.x, 0, 100);
				next.y = clamp(next.y, 0, 100);
				next.w = clamp(next.w, 5, 100 - next.x);
				next.h = clamp(next.h, 5, 100 - next.y);
				setRect(next);
			}
			function onUp() {
				dragRef.current = null;
			}
			window.addEventListener('pointermove', onMove);
			window.addEventListener('pointerup', onUp);
			return function () {
				window.removeEventListener('pointermove', onMove);
				window.removeEventListener('pointerup', onUp);
			};
		/* `rect` is deliberately NOT a dependency: onMove reads drag.start, which
		   is captured at pointerdown. Listing it re-registered both window
		   listeners on every single pointermove. */
		}, [aspectKey, natural]);

		function save() {
			/* Last-resort read: state, then the live element. Only a genuinely
			   undecodable image can get past both, and that case now says so
			   instead of closing as if the crop had been applied. */
			var size = natural || naturalOf(imgRef.current);
			if (!size) {
				window.alert(__('Não foi possível ler as dimensões da imagem; o recorte não foi salvo. Recarregue a imagem e tente de novo.', 'go-verge'));
				return;
			}
			if (rect.w >= 99.5 && rect.h >= 99.5) {
				props.onClear();
				props.onClose();
				return;
			}
			/* Round first, then derive the ratio from the rounded rectangle, so
			   the persisted numbers are internally consistent. */
			var out = { x: round2(rect.x), y: round2(rect.y), w: round2(rect.w), h: round2(rect.h) };
			out.ratio = cropRatio(out, size);
			props.onSave(out);
			props.onClose();
		}

		var handleStyleBase = {
			position: 'absolute',
			width: '16px',
			height: '16px',
			background: '#d8ff38',
			border: '2px solid #11130b',
			borderRadius: '3px',
			touchAction: 'none',
			zIndex: 2
		};
		var handles = [
			{ mode: 'nw', style: { top: '-8px', left: '-8px', cursor: 'nwse-resize' } },
			{ mode: 'ne', style: { top: '-8px', right: '-8px', cursor: 'nesw-resize' } },
			{ mode: 'sw', style: { bottom: '-8px', left: '-8px', cursor: 'nesw-resize' } },
			{ mode: 'se', style: { bottom: '-8px', right: '-8px', cursor: 'nwse-resize' } }
		];

		var cropPx = natural
			? Math.round((rect.w / 100) * natural.w) + ' × ' + Math.round((rect.h / 100) * natural.h) + ' px'
			: '';

		return el(
			Modal,
			{
				title: __('Recorte da imagem', 'go-verge'),
				onRequestClose: props.onClose,
				shouldCloseOnClickOutside: false,
				style: { maxWidth: '920px', width: '92vw' }
			},
			el(
				'div',
				{ style: { display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '14px' } },
				ASPECTS.map(function (aspect) {
					return el(Button, {
						key: aspect.key,
						variant: aspectKey === aspect.key ? 'primary' : 'secondary',
						size: 'small',
						onClick: function () {
							applyAspect(aspect.key);
						}
					}, aspect.label);
				})
			),
			el(
				'div',
				{ style: { textAlign: 'center', background: '#0f0f0f', padding: '14px', borderRadius: '8px' } },
				el(
					'div',
					{
						ref: frameRef,
						style: {
							position: 'relative',
							display: 'inline-block',
							lineHeight: 0,
							userSelect: 'none',
							touchAction: 'none',
							maxWidth: '100%'
						}
					},
					el('img', {
						src: props.url,
						alt: '',
						draggable: false,
						ref: imgRef,
						onLoad: function (event) {
							adoptNatural(event.target);
						},
						style: { display: 'block', maxWidth: '100%', maxHeight: '58vh', width: 'auto', height: 'auto' }
					}),
					el(
						'div',
						{
							role: 'presentation',
							onPointerDown: function (event) {
								beginDrag(event, 'move');
							},
							style: {
								position: 'absolute',
								left: rect.x + '%',
								top: rect.y + '%',
								width: rect.w + '%',
								height: rect.h + '%',
								border: '2px solid #d8ff38',
								boxShadow: '0 0 0 9999px rgba(10, 11, 11, 0.62)',
								cursor: 'move',
								touchAction: 'none',
								boxSizing: 'border-box'
							}
						},
						handles.map(function (handle) {
							return el('div', {
								key: handle.mode,
								role: 'presentation',
								onPointerDown: function (event) {
									beginDrag(event, handle.mode);
								},
								style: Object.assign({}, handleStyleBase, handle.style)
							});
						})
					)
				)
			),
			el(
				'div',
				{ style: { display: 'flex', alignItems: 'center', gap: '10px', marginTop: '16px' } },
				el('span', { style: { opacity: 0.75, fontSize: '12px' } }, cropPx),
				el('span', { style: { flex: '1 1 auto' } }),
				props.crop
					? el(Button, {
						variant: 'tertiary',
						isDestructive: true,
						onClick: function () {
							props.onClear();
							props.onClose();
						}
					}, __('Remover recorte', 'go-verge'))
					: null,
				el(Button, { variant: 'secondary', onClick: props.onClose }, __('Cancelar', 'go-verge')),
				el(Button, { variant: 'primary', onClick: save }, __('Aplicar recorte', 'go-verge'))
			)
		);
	}

	/* Native Gutenberg aspect-ratio is intentional geometry. Plain imported
	 * width/height, on the other hand, must not stretch the editor preview. */
	function hasExplicitCoreGeometry(attrs) {
		attrs = attrs || {};
		var ratio = String(attrs.aspectRatio || '').trim().toLowerCase();
		var styleRatio = attrs.style && attrs.style.dimensions
			? String(attrs.style.dimensions.aspectRatio || '').trim().toLowerCase()
			: '';
		return (!!ratio && ratio !== 'auto') || (!!styleRatio && styleRatio !== 'auto');
	}

	/* 2) Botão na barra do bloco + pré-visualização no canvas. */
	var withImageCrop = createHigherOrderComponent(function (BlockEdit) {
		return function (props) {
			if (props.name !== 'core/image') {
				return el(BlockEdit, props);
			}

			var openState = useState(false);
			var isOpen = openState[0];
			var setOpen = openState[1];
			var crop = props.attributes.goCrop;
			var frame = props.attributes.goFrame;
			var url = props.attributes.url;

			var children = [el(BlockEdit, Object.assign({ key: 'edit' }, props))];

			/* Mirror the public pasted-image repair inside Gutenberg. Do not touch a
			 * custom crop/frame or a ratio the editor explicitly chose. */
			if (!crop && !frame && !hasExplicitCoreGeometry(props.attributes)) {
				var plainSelector = '[data-block="' + props.clientId + '"] img';
				var plainCss = plainSelector + '{height:auto!important;block-size:auto!important;min-height:0!important;max-height:none!important;' +
					'aspect-ratio:auto!important;object-fit:contain!important;max-width:100%!important;}';
				children.push(el('style', { key: 'go-plain-image-geometry' }, plainCss));
			}

			if (url) {
				children.push(
					el(
						BlockControls,
						{ key: 'go-crop-controls', group: 'other' },
						el(
							ToolbarGroup,
							null,
							el(ToolbarButton, {
								icon: 'image-crop',
								label: crop ? __('Editar recorte editorial', 'go-verge') : __('Recorte editorial', 'go-verge'),
								isPressed: !!crop,
								onClick: function () {
									setOpen(true);
								}
							}),
							el(ToolbarButton, {
								icon: el('svg', { width: 24, height: 24, viewBox: '0 0 24 24', 'aria-hidden': 'true' },
									el('rect', { x: 3, y: 7, width: 18, height: 10, rx: 1.5, fill: 'none', stroke: 'currentColor', strokeWidth: 1.6 }),
									el('path', { d: 'M17.5 4.2l.5 1.3 1.3.5-1.3.5-.5 1.3-.5-1.3-1.3-.5 1.3-.5z', fill: 'currentColor' })),
								label: __('16:9 automático (melhor corte)', 'go-verge'),
								onClick: function () {
									applyAuto169(props);
								}
							}),
							el(ToolbarButton, {
								icon: 'embed-photo',
								label: frame
									? __('Remover quadro (imagem inteira)', 'go-verge')
									: __('Quadro 16:9 — imagem inteira, sem corte', 'go-verge'),
								isPressed: !!frame,
								onClick: function () {
									if (frame) {
										props.setAttributes({ goFrame: undefined });
									} else {
										props.setAttributes({
											goFrame: { ratio: '16x9', bg: 'white' },
											goCrop: undefined
										});
									}
								}
							})
						)
					)
				);
			}

			if (frame) {
				children.push(
					el(
						InspectorControls,
						{ key: 'go-frame-inspector' },
						el(
							PanelBody,
							{ title: __('Quadro editorial', 'go-verge'), initialOpen: true },
							el(SelectControl, {
								label: __('Proporção do quadro', 'go-verge'),
								value: frame.ratio || '16x9',
								options: [
									{ value: '16x9', label: '16:9' },
									{ value: '4x3', label: '4:3' },
									{ value: '1x1', label: '1:1' },
									{ value: '3x2', label: '3:2' }
								],
								onChange: function (value) {
									props.setAttributes({ goFrame: Object.assign({}, frame, { ratio: value }) });
								}
							}),
							el(SelectControl, {
								label: __('Fundo do quadro', 'go-verge'),
								value: frame.bg || 'white',
								options: [
									{ value: 'white', label: __('Branco (fotos de produto)', 'go-verge') },
									{ value: 'surface', label: __('Superfície do tema', 'go-verge') },
									{ value: 'blur', label: __('Desfoque da própria imagem', 'go-verge') }
								],
								onChange: function (value) {
									props.setAttributes({ goFrame: Object.assign({}, frame, { bg: value }) });
								}
							}),
							el('p', { style: { fontSize: '11px', opacity: 0.7, margin: 0 } },
								__('O quadro mostra a imagem inteira, sem corte — ideal para fotos de produto em pé ou quadradas. Para cortar uma região, use o Recorte editorial.', 'go-verge'))
						)
					)
				);
			}

			if (isOpen && url) {
				children.push(
					el(CropModal, {
						key: 'go-crop-modal',
						url: url,
						crop: crop,
						onClose: function () {
							setOpen(false);
						},
						onSave: function (nextCrop) {
							props.setAttributes({ goCrop: nextCrop, goFrame: undefined });
						},
						onClear: function () {
							props.setAttributes({ goCrop: undefined });
						}
					})
				);
			}

			/*
			 * Pré-visualização do recorte dentro do canvas do editor.
			 *
			 * Declaration-for-declaration identical to what
			 * go_verge_image_crop_render_block() writes on the public article,
			 * INCLUDING the sizing reset. The preview used to omit width/max-width
			 * and to leave the block's own inline sizing in place, so a resized
			 * image (`is-resized`, an explicit width on the block) previewed at
			 * its editor width and published at 100% of the column: same crop
			 * rectangle, different picture on screen. Any divergence between these
			 * two strings is a WYSIWYG bug, so they are kept as one contract.
			 */
			if (crop && crop.w && crop.ratio) {
				var selector = '[data-block="' + props.clientId + '"] img';
				var posX = crop.w < 100 ? (crop.x / (100 - crop.w)) * 100 : 50;
				var posY = crop.h < 100 ? (crop.y / (100 - crop.h)) * 100 : 50;
				var inset = 'inset(' + crop.y + '% ' + (100 - crop.x - crop.w) + '% ' + (100 - crop.y - crop.h) + '% ' + crop.x + '%)';
				var css = selector + '{display:block;width:100%;height:auto;max-width:100%;min-width:0;' +
					'aspect-ratio:' + crop.ratio + ';object-fit:cover;' +
					'object-position:' + round2(posX) + '% ' + round2(posY) + '%;' +
					'object-view-box:' + inset + ';border-radius:6px;margin:0;}';
				children.push(el('style', { key: 'go-crop-preview' }, css));
			}

			/* Pré-visualização do quadro (imagem inteira em proporção fixa). */
			if (!crop && frame && FRAME_RATIOS[frame.ratio]) {
				var frameSelector = '[data-block="' + props.clientId + '"] img';
				var frameBg = 'blur' === frame.bg
					? 'background:#101010;'
					: ('surface' === frame.bg
						? 'background:#181919;border:1px solid rgba(255,255,255,.09);'
						: 'background:#ffffff;border:1px solid rgba(18,18,18,.08);');
				var frameCss = frameSelector + '{aspect-ratio:' + FRAME_RATIOS[frame.ratio] + ';width:100%;height:auto;' +
					'object-fit:contain;padding:14px;box-sizing:border-box;border-radius:10px;' + frameBg + '}';
				children.push(el('style', { key: 'go-frame-preview' }, frameCss));
			}

			return el(Fragment, null, children);
		};
	}, 'withGoImageCrop');
	addFilter('editor.BlockEdit', 'go-verge/image-crop-edit', withImageCrop);

	/* Expose only the re-bind hook: the crop implementation stays private.
	 * The custom Overdrive command bar is injected independently from Gutenberg,
	 * so either script is allowed to finish first without losing the action. */
	window.GoVergeBindBulkSmartCropControls = bindBulkSmartCropControls;
	document.addEventListener('go:editorial-commandbar-ready', bindBulkSmartCropControls);

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', bindBulkSmartCropControls, { once: true });
	} else {
		bindBulkSmartCropControls();
	}
	window.setTimeout(bindBulkSmartCropControls, 800);
	window.setTimeout(bindBulkSmartCropControls, 1800);
})(window.wp);
