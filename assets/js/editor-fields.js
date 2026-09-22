(function () {
	'use strict';

	var config = window.GoVergeEditorFields || {};
	/* Review/Crítica are formats, not categories. */
	var reviewIds = (config.reviewContentTypeIds || (config.editorialTypes&&config.editorialTypes.review&&config.editorialTypes.review.ids) || []).map(Number);
	var critiqueIds = (config.critiqueContentTypeIds || (config.editorialTypes&&config.editorialTypes.critique&&config.editorialTypes.critique.ids) || []).map(Number);
	var lastSignature = '';

	function intersects(selected, allowed) {
		return selected.some(function (id) { return allowed.indexOf(Number(id)) !== -1; });
	}

	function selectedContentTypeIds() {
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostAttribute) {
					var ids = editor.getEditedPostAttribute('go_content_type');
					if (Array.isArray(ids)) { return ids.map(Number); }
				}
			}
		} catch (error) {}
		return [];
	}

	function setBoxVisible(id, visible) {
		var box = document.getElementById(id);
		if (!box) { return; }
		box.hidden = !visible;
		box.style.display = visible ? '' : 'none';
		box.setAttribute('aria-hidden', visible ? 'false' : 'true');
	}

	function sync() {
		var selected = selectedContentTypeIds();
		var signature = selected.slice().sort(function (a, b) { return a - b; }).join(',');
		if (signature === lastSignature && lastSignature !== '') { return; }
		lastSignature = signature;
		var isCritique = intersects(selected, critiqueIds);
		// Crítica has precedence when categories overlap (for example, when the
		// cinema section is nested below Reviews). This prevents both metadata
		// panels from appearing and being edited for the same film article.
		var isReview = intersects(selected, reviewIds) && !isCritique;
		setBoxVisible('go-verge-review-fields', isReview);
		setBoxVisible('go-verge-critique-fields', isCritique);
		setBoxVisible('go-verge-technical-sheet-fields', isReview || isCritique);
		setBoxVisible('go-verge-technical-details-fields', isReview || isCritique);
	}

	function boot() {
		sync();
		window.addEventListener('go:v10-tax-change', function () { lastSignature = ''; sync(); });
		window.addEventListener('go:v7-tax-change', function () { lastSignature = ''; sync(); });

		if (window.wp && wp.data && wp.data.subscribe) {
			var categorySyncTimer = 0;
			wp.data.subscribe(function () {
				window.clearTimeout(categorySyncTimer);
				categorySyncTimer = window.setTimeout(sync, 240);
			});
		}

		// Gutenberg taxonomy controls can mount after the meta boxes.
		window.setTimeout(function () { lastSignature = ''; sync(); }, 500);
		window.setTimeout(function () { lastSignature = ''; sync(); }, 1500);
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}
})();
