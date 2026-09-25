(function () {
	'use strict';

	function boot() {
		document.querySelectorAll('[data-go-verdict-media]').forEach(function (field) {
			if (field.dataset.ready === '1') return;
			field.dataset.ready = '1';

			var input = field.querySelector('[data-go-verdict-media-id]');
			var preview = field.querySelector('[data-go-verdict-media-preview]');
			var select = field.querySelector('[data-go-verdict-media-select]');
			var remove = field.querySelector('[data-go-verdict-media-remove]');
			if (!input || !preview || !select || !window.wp || !wp.media) return;

			select.addEventListener('click', function () {
				var frame = wp.media({
					title: 'Escolher imagem do veredito',
					button: { text: 'Usar esta imagem' },
					library: { type: 'image' },
					multiple: false
				});
				frame.on('select', function () {
					var attachment = frame.state().get('selection').first().toJSON();
					var source = attachment.sizes && attachment.sizes.medium_large ? attachment.sizes.medium_large.url : attachment.url;
					input.value = String(attachment.id || '');
					preview.replaceChildren();
					var image = document.createElement('img');
					image.src = source || '';
					image.alt = '';
					image.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';
					preview.appendChild(image);
					if (remove) remove.hidden = false;
				});
				frame.open();
			});

			if (remove) {
				remove.addEventListener('click', function () {
					input.value = '';
					preview.replaceChildren();
					remove.hidden = true;
				});
			}
		});
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot, { once: true });
	} else {
		boot();
	}
}());
