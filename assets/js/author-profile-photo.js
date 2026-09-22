(function (window, document) {
	'use strict';

	function initPicker(root) {
		var selectButton = root.querySelector('[data-go-author-photo-select]');
		var removeButton = root.querySelector('[data-go-author-photo-remove]');
		var input = root.querySelector('[data-go-author-photo-id]');
		var preview = root.querySelector('[data-go-author-photo-preview]');
		var frame = null;

		if (!selectButton || !input || !preview || !window.wp || !wp.media) {
			return;
		}

		selectButton.addEventListener('click', function (event) {
			event.preventDefault();
			if (frame) {
				frame.open();
				return;
			}

			frame = wp.media({
				title: 'Escolher foto do autor',
				button: { text: 'Usar esta foto' },
				library: { type: 'image' },
				multiple: false
			});

			frame.on('select', function () {
				var attachment = frame.state().get('selection').first().toJSON();
				var url = attachment.sizes && attachment.sizes.thumbnail ? attachment.sizes.thumbnail.url : attachment.url;
				input.value = attachment.id || '';
				preview.innerHTML = '';
				var image = document.createElement('img');
				image.src = url || '';
				image.alt = '';
				preview.appendChild(image);
				preview.classList.add('has-image');
				if (removeButton) {
					removeButton.hidden = false;
				}
			});

			frame.open();
		});

		if (removeButton) {
			removeButton.addEventListener('click', function (event) {
				event.preventDefault();
				input.value = '';
				preview.innerHTML = '';
				preview.classList.remove('has-image');
				removeButton.hidden = true;
			});
		}
	}

	document.addEventListener('DOMContentLoaded', function () {
		document.querySelectorAll('[data-go-author-photo-picker]').forEach(initPicker);
	});
})(window, document);
