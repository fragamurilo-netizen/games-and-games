(function ($) {
	'use strict';
	function chooseImage(title, done) {
		var frame = wp.media({ title: title, button: { text: 'Usar esta imagem' }, multiple: false, library: { type: 'image' } });
		frame.on('select', function () {
			var item = frame.state().get('selection').first().toJSON();
			done(Number(item.id || 0));
		});
		frame.open();
	}
	$(document).on('click', '[data-go-split-image-insert]', function (event) {
		event.preventDefault();
		chooseImage('Escolha a imagem da esquerda', function (leftId) {
			if (!leftId) { return; }
			chooseImage('Escolha a imagem da direita', function (rightId) {
				if (!rightId) { return; }
				var shortcode = '[go_split_image left="' + leftId + '" right="' + rightId + '"]';
				if (window.wp && wp.media && wp.media.editor) {
					wp.media.editor.insert(shortcode);
				}
			});
		});
	});
})(jQuery);
