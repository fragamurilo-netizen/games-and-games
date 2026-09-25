(function (window, document, wp) {
	'use strict';

	if (!wp || !wp.media || !wp.media.view) {
		return;
	}

	document.documentElement.classList.add('go-media-workspace');

	/* Add an editorial-quality filter to the grid Media Library and post modal. */
	if (wp.media.view.AttachmentFilters && wp.media.view.AttachmentsBrowser) {
		var QualityFilter = wp.media.view.AttachmentFilters.extend({
			id: 'go-media-quality-filter',
			createFilters: function () {
				this.filters = {
					all: {
						text: 'Qualidade editorial: todas',
						props: { go_media_quality: null },
						priority: 10
					},
					missingAlt: {
						text: 'Sem texto alternativo',
						props: { go_media_quality: 'missing_alt' },
						priority: 20
					},
					missingCaption: {
						text: 'Sem legenda',
						props: { go_media_quality: 'missing_caption' },
						priority: 30
					},
					genericTitle: {
						text: 'Título genérico',
						props: { go_media_quality: 'generic_title' },
						priority: 40
					}
				};
			}
		});

		var OriginalBrowser = wp.media.view.AttachmentsBrowser;
		wp.media.view.AttachmentsBrowser = OriginalBrowser.extend({
			createToolbar: function () {
				OriginalBrowser.prototype.createToolbar.apply(this, arguments);
				if (!this.toolbar || !this.collection || !this.collection.props) {
					return;
				}
				this.toolbar.set('GoMediaQualityFilter', new QualityFilter({
					controller: this.controller,
					model: this.collection.props,
					priority: -72
				}).render());
			}
		});
	}

	/* Mark image-editor screens without rescanning on unrelated Gutenberg edits. */
	var imageEditorSelector = '.imgedit-wrap, .image-editor, .imgedit-panel-content';
	var syncImageEditorState = function () {
		var editor = document.querySelector('.imgedit-wrap, .image-editor, .media-frame-content .imgedit-panel-content');
		document.body.classList.toggle('go-native-image-editor-open', !!editor);
	};
	var observer = new MutationObserver(function (mutations) {
		var relevant = Array.prototype.some.call(mutations || [], function (mutation) {
			var nodes = Array.prototype.slice.call(mutation.addedNodes || []).concat(Array.prototype.slice.call(mutation.removedNodes || []));
			return nodes.some(function (node) {
				if (!node || node.nodeType !== 1) return false;
				return (node.matches && node.matches(imageEditorSelector)) || (node.querySelector && node.querySelector(imageEditorSelector));
			});
		});
		if (relevant) syncImageEditorState();
	});
	observer.observe(document.body, { childList: true, subtree: true });
	syncImageEditorState();
})(window, document, window.wp);
