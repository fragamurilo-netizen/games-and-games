(function (window, wp) {
	'use strict';

	if (!wp || !wp.data || !window.GoVergeAutoImageImport) {
		return;
	}

	var cfg = window.GoVergeAutoImageImport;
	var inFlight = Object.create(null);
	var completed = Object.create(null);
	var failed = Object.create(null);
	var scanTimer = null;
	var scanning = false;

	function postId() {
		try {
			var editor = wp.data.select('core/editor');
			return editor && editor.getCurrentPostId ? parseInt(editor.getCurrentPostId(), 10) || 0 : 0;
		} catch (error) {
			return 0;
		}
	}

	function externalHttpUrl(value) {
		if (!value || !/^https?:\/\//i.test(String(value))) {
			return false;
		}
		try {
			var source = new URL(String(value), window.location.href);
			var home = new URL(String(cfg.homeUrl || window.location.origin), window.location.href);
			return source.protocol.match(/^https?:$/) && source.host !== home.host;
		} catch (error) {
			return false;
		}
	}

	function allBlocks(blocks, output) {
		output = output || [];
		(blocks || []).forEach(function (block) {
			if (!block) { return; }
			output.push(block);
			if (block.innerBlocks && block.innerBlocks.length) {
				allBlocks(block.innerBlocks, output);
			}
		});
		return output;
	}

	function plainCaption(attrs) {
		var value = attrs && attrs.caption ? String(attrs.caption) : '';
		if (!value) { return ''; }
		var holder = document.createElement('div');
		holder.innerHTML = value;
		return (holder.textContent || '').trim();
	}

	function requestImport(block, url) {
		var id = postId();
		if (!id || !block || !block.clientId) {
			return Promise.reject(new Error('Post ainda não está pronto para receber mídia.'));
		}

		if (completed[url]) {
			return Promise.resolve(completed[url]);
		}
		if (inFlight[url]) {
			return inFlight[url];
		}

		var data = new FormData();
		data.append('action', 'go_verge_import_external_editor_image');
		data.append('nonce', cfg.nonce || '');
		data.append('post_id', String(id));
		data.append('url', url);
		data.append('alt', String((block.attributes && block.attributes.alt) || ''));
		data.append('caption', plainCaption(block.attributes || {}));

		inFlight[url] = window.fetch(cfg.ajaxUrl, {
			method: 'POST',
			credentials: 'same-origin',
			body: data
		}).then(function (response) {
			return response.json().catch(function () { return null; }).then(function (payload) {
				if (!response.ok || !payload || !payload.success || !payload.data) {
					var message = payload && payload.data && payload.data.message ? payload.data.message : 'Não foi possível importar a imagem externa.';
					throw new Error(message);
				}
				completed[url] = payload.data;
				return payload.data;
			});
		}).finally(function () {
			delete inFlight[url];
		});

		return inFlight[url];
	}

	function applyAttachment(block, originalUrl, attachment) {
		if (!attachment || !attachment.id || !attachment.url) { return; }
		var current;
		try {
			current = wp.data.select('core/block-editor').getBlock(block.clientId);
		} catch (error) {
			current = null;
		}
		if (!current || current.name !== 'core/image') { return; }
		var attrs = current.attributes || {};
		if (attrs.id || String(attrs.url || '') !== String(originalUrl)) { return; }

		var next = {
			id: parseInt(attachment.id, 10),
			url: String(attachment.url)
		};
		if (!attrs.alt && attachment.alt) { next.alt = String(attachment.alt); }
		if (!attrs.width && attachment.width) { next.width = parseInt(attachment.width, 10); }
		if (!attrs.height && attachment.height) { next.height = parseInt(attachment.height, 10); }

		wp.data.dispatch('core/block-editor').updateBlockAttributes(block.clientId, next);
	}

	function scan() {
		if (scanning) { return; }
		scanning = true;
		try {
			var editor = wp.data.select('core/editor');
			var blockEditor = wp.data.select('core/block-editor');
			if (!editor || !blockEditor || !postId()) { return; }
			if (editor.isSavingPost && editor.isSavingPost()) { return; }

			allBlocks(blockEditor.getBlocks ? blockEditor.getBlocks() : []).forEach(function (block) {
				if (!block || block.name !== 'core/image') { return; }
				var attrs = block.attributes || {};
				var url = String(attrs.url || '').trim();
				if (attrs.id || !externalHttpUrl(url) || failed[url]) { return; }

				requestImport(block, url).then(function (attachment) {
					applyAttachment(block, url, attachment);
				}).catch(function (error) {
					failed[url] = true;
					if (window.console && console.warn) {
						console.warn('[Overdrive] Importação automática de imagem:', error && error.message ? error.message : error);
					}
				});
			});
		} finally {
			scanning = false;
		}
	}

	function scheduleScan() {
		window.clearTimeout(scanTimer);
		scanTimer = window.setTimeout(scan, 180);
	}

	var boot = function () {
		scan();
		wp.data.subscribe(scheduleScan);
	};

	if (wp.domReady) {
		wp.domReady(boot);
	} else if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot, { once: true });
	} else {
		boot();
	}
})(window, window.wp);
