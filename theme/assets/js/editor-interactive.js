/**
 * "Blocos interativos" metabox: inserts shortcode templates at the caret in
 * the classic editor, or as a shortcode block in Gutenberg. Falls back to
 * copying the snippet when no editor is reachable.
 */
(function () {
	'use strict';

	function isBlockEditor() {
		return !!(window.wp && wp.data && wp.data.select && wp.data.select('core/block-editor') && document.body.classList.contains('block-editor-page'));
	}

	function insertIntoBlockEditor(text) {
		try {
			var block = wp.blocks.createBlock('core/shortcode', { text: text });
			wp.data.dispatch('core/block-editor').insertBlocks(block);
			return true;
		} catch (error) {
			return false;
		}
	}

	function insertIntoClassicEditor(text) {
		// TinyMCE visual mode.
		if (window.tinymce && tinymce.activeEditor && !tinymce.activeEditor.isHidden()) {
			tinymce.activeEditor.execCommand('mceInsertContent', false, '<p>' + text.replace(/\n/g, '<br>') + '</p>');
			return true;
		}
		// Quicktags / text mode.
		var textarea = document.getElementById('content');
		if (textarea && textarea.offsetParent !== null) {
			var start = textarea.selectionStart || 0;
			var end = textarea.selectionEnd || 0;
			textarea.value = textarea.value.slice(0, start) + '\n' + text + '\n' + textarea.value.slice(end);
			textarea.dispatchEvent(new Event('change', { bubbles: true }));
			return true;
		}
		return false;
	}

	function copyFallback(text, button) {
		var done = function () {
			var original = button.textContent;
			button.textContent = 'Copiado! Cole no texto.';
			window.setTimeout(function () { button.textContent = original; }, 2200);
		};
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text).then(done).catch(function () { window.prompt('Copie o shortcode:', text); });
		} else {
			window.prompt('Copie o shortcode:', text);
		}
	}

	function insert(text, button) {
		if (isBlockEditor() && insertIntoBlockEditor(text)) { return; }
		if (insertIntoClassicEditor(text)) { return; }
		copyFallback(text, button);
	}

	document.addEventListener('click', function (event) {
		var blockButton = event.target.closest('[data-go-insert-block]');
		if (blockButton) {
			event.preventDefault();
			insert(blockButton.getAttribute('data-go-insert-block'), blockButton);
			return;
		}

		var predictionButton = event.target.closest('[data-go-insert-prediction]');
		if (predictionButton) {
			event.preventDefault();
			var box = predictionButton.closest('[data-go-interactive-metabox]');
			var picker = box && box.querySelector('[data-go-prediction-picker]');
			if (!picker || !picker.value) { return; }
			insert('[go_previsao id="' + picker.value + '"]', predictionButton);
		}
	});
})();
