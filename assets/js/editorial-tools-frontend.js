/**
 * Kit de ferramentas editoriais — frontend.
 * Liga o slider dos comparadores Antes/Depois (input range → variável CSS).
 */
(function () {
	'use strict';

	function init() {
		var comparators = document.querySelectorAll('[data-go-before-after]');
		for (var i = 0; i < comparators.length; i++) {
			bind(comparators[i]);
		}
	}

	function bind(container) {
		if (container.__goBeforeAfter) {
			return;
		}
		container.__goBeforeAfter = true;

		var range = container.querySelector('.go-before-after__range');
		if (!range) {
			return;
		}

		var update = function () {
			container.style.setProperty('--go-ba-pos', range.value + '%');
		};
		range.addEventListener('input', update);
		update();
	}

	if ('loading' !== document.readyState) {
		init();
	} else {
		document.addEventListener('DOMContentLoaded', init);
	}
})();
