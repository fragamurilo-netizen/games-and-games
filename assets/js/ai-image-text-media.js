(function (window, document, wp) {
	'use strict';

	if (!wp || !wp.apiFetch) {
		return;
	}

	var config = window.GoVergeAIImageText || {};

	function currentPostId() {
		try {
			if (wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getCurrentPostId) {
					return Number(editor.getCurrentPostId()) || Number(config.postId) || 0;
				}
			}
		} catch (error) {}
		return Number(config.postId) || 0;
	}

	function ensureStatus(button) {
		var holder = button.parentNode;
		if (!holder) {
			return null;
		}
		var status = holder.querySelector('.go-ai-image-text-status');
		if (!status) {
			status = document.createElement('div');
			status.className = 'go-ai-image-text-status';
			status.setAttribute('role', 'status');
			status.setAttribute('aria-live', 'polite');
			holder.appendChild(status);
		}
		return status;
	}

	function setStatus(button, message, type) {
		var status = ensureStatus(button);
		if (!status) {
			return;
		}
		status.textContent = message || '';
		status.className = 'go-ai-image-text-status' + (type ? ' is-' + type : '');
	}

	function dispatchValue(input, value) {
		if (!input) {
			return;
		}
		input.value = value || '';
		input.dispatchEvent(new Event('input', { bubbles: true }));
		input.dispatchEvent(new Event('change', { bubbles: true }));
	}

	function updateMediaUi(button, attachmentId, response) {
		var scope = button.closest('.attachment-details') || button.closest('.media-modal') || button.closest('.media-frame-content') || document;
		var titleInput = scope.querySelector('input[data-setting="title"], input[name*="post_title"]');
		var altInput = scope.querySelector('input[data-setting="alt"], textarea[data-setting="alt"], input[name*="image_alt"], input[name*="_wp_attachment_image_alt"]');
		var captionInput = scope.querySelector('textarea[data-setting="caption"], input[data-setting="caption"], textarea[name*="post_excerpt"]');

		dispatchValue(titleInput, response.title || '');
		dispatchValue(altInput, response.alt || '');
		dispatchValue(captionInput, response.caption || '');

		try {
			if (wp.media && wp.media.frame && wp.media.frame.state) {
				var selection = wp.media.frame.state().get('selection');
				var model = selection && (selection.get(attachmentId) || selection.first());
				if (model && Number(model.get('id')) === attachmentId) {
					model.set({ title: response.title || '', alt: response.alt || '', caption: response.caption || '' });
				}
			}
		} catch (error) {}
	}

	document.addEventListener('click', function (event) {
		var button = event.target && event.target.closest ? event.target.closest('.go-smart-image-media-button') : null;
		if (!button) {
			return;
		}

		event.preventDefault();
		event.stopPropagation();

		var attachmentId = Number(button.getAttribute('data-attachment-id')) || 0;
		if (!attachmentId || button.disabled) {
			return;
		}

		var original = button.textContent;
		button.disabled = true;
		button.textContent = 'Preparando IA grátis…';
		setStatus(button, 'O primeiro uso baixa o modelo local. Depois ele fica em cache no navegador.', 'loading');

		var onProgress = function (progressEvent) {
			var detail = progressEvent && progressEvent.detail ? progressEvent.detail : {};
			if (!detail.message) {
				return;
			}
			button.textContent = detail.stage === 'vision' ? 'Analisando imagem…' : 'IA local trabalhando…';
			setStatus(button, detail.message, detail.stage === 'error' ? 'error' : (detail.stage === 'warning' ? 'warning' : 'loading'));
		};
		document.addEventListener('go-verge-local-ai-progress', onProgress);

		Promise.resolve(window.GoVergeLocalAIReady)
			.then(function (localAI) {
				if (!localAI || typeof localAI.generate !== 'function') {
					throw new Error('O motor local de IA não foi carregado. Atualize a página e tente novamente.');
				}
				return localAI.generate({
					attachmentId: attachmentId,
					postId: currentPostId(),
					context: '',
					mode: 'both'
				});
			})
			.then(function (response) {
				updateMediaUi(button, attachmentId, response || {});
				button.textContent = 'Aplicado com IA grátis';
				setStatus(button, 'Título, alt text e legenda gerados localmente e salvos na mídia.', 'success');
			})
			.catch(function (error) {
				var message = error && error.message ? error.message : 'Não foi possível executar a IA local.';
				button.textContent = 'Tentar novamente';
				setStatus(button, message, 'error');
			})
			.then(function () {
				document.removeEventListener('go-verge-local-ai-progress', onProgress);
				button.disabled = false;
				window.setTimeout(function () {
					if (!button.disabled) {
						button.textContent = original;
					}
				}, 2200);
			});
	});
})(window, document, window.wp);
