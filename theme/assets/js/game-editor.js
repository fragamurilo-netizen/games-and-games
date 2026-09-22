(function () {
	'use strict';

	function initEditor(root) {
		if (!root || root.dataset.ready === '1') return;
		root.dataset.ready = '1';

		var tabs = Array.prototype.slice.call(root.querySelectorAll('[data-go-game-tab]'));
		var panels = Array.prototype.slice.call(root.querySelectorAll('[data-go-game-panel]'));
		tabs.forEach(function (tab) {
			tab.addEventListener('click', function () {
				var target = tab.getAttribute('data-go-game-tab');
				tabs.forEach(function (item) {
					var active = item === tab;
					item.classList.toggle('is-active', active);
					item.setAttribute('aria-selected', active ? 'true' : 'false');
				});
				panels.forEach(function (panel) {
					var active = panel.getAttribute('data-go-game-panel') === target;
					panel.hidden = !active;
					panel.classList.toggle('is-active', active);
				});
			});
		});

		root.querySelectorAll('[data-go-game-media]').forEach(function (field) {
			var input = field.querySelector('[data-go-game-media-id]');
			var preview = field.querySelector('[data-go-game-media-preview]');
			var select = field.querySelector('[data-go-game-media-select]');
			var remove = field.querySelector('[data-go-game-media-remove]');
			if (!input || !preview || !select || !window.wp || !wp.media) return;

			select.addEventListener('click', function () {
				var frame = wp.media({ title: 'Escolher imagem do game', button: { text: 'Usar esta imagem' }, library: { type: 'image' }, multiple: false });
				frame.on('select', function () {
					var attachment = frame.state().get('selection').first().toJSON();
					input.value = String(attachment.id || '');
					preview.replaceChildren();
					var image = document.createElement('img');
					image.src = (attachment.sizes && attachment.sizes.medium ? attachment.sizes.medium.url : attachment.url) || '';
					image.alt = '';
					preview.appendChild(image);
					if (remove) remove.hidden = false;
				});
				frame.open();
			});

			if (remove) remove.addEventListener('click', function () {
				input.value = '';
				preview.replaceChildren();
				remove.hidden = true;
			});
		});

		var stores = root.querySelector('[data-go-game-stores]');
		if (stores) {
			var rows = stores.querySelector('[data-go-game-store-rows]');
			var template = stores.querySelector('[data-go-game-store-template]');
			var add = stores.querySelector('[data-go-game-store-add]');
			if (rows && template && add) {
				add.addEventListener('click', function () {
					var index = Date.now().toString(36);
					var holder = document.createElement('div');
					holder.innerHTML = template.textContent.replaceAll('__INDEX__', index).trim();
					if (holder.firstElementChild) rows.appendChild(holder.firstElementChild);
				});
				stores.addEventListener('click', function (event) {
					var removeButton = event.target.closest('[data-go-game-store-remove]');
					if (!removeButton || !stores.contains(removeButton)) return;
					var row = removeButton.closest('.go-game-store-row');
					if (row) row.remove();
				});
			}
		}
	}

	function boot() {
		document.querySelectorAll('[data-go-game-editor]').forEach(initEditor);
	}

	if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
	else boot();
}());
