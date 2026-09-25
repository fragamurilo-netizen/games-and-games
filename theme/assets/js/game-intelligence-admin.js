(function () {
	'use strict';

	var cfg = window.GoVergeGameIntelligence || {};
	if (!cfg.ajaxUrl) return;

	function post(action, data) {
		var body = new URLSearchParams();
		body.set('action', action);
		body.set('nonce', cfg.nonce || '');
		Object.keys(data || {}).forEach(function (key) {
			body.set(key, data[key] == null ? '' : String(data[key]));
		});
		return fetch(cfg.ajaxUrl, {
			method: 'POST',
			credentials: 'same-origin',
			headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
			body: body.toString()
		}).then(function (response) {
			return response.json();
		}).then(function (payload) {
			if (!payload || payload.success !== true) {
				var message = payload && payload.data && payload.data.message ? payload.data.message : ((cfg.i18n && cfg.i18n.error) || 'Erro');
				throw new Error(message);
			}
			return payload.data || {};
		});
	}

	function editorContext() {
		var out = { title: '', seoTitle: '', content: '', excerpt: '' };
		try {
			if (window.wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor) {
					out.title = editor.getEditedPostAttribute('title') || '';
					out.content = editor.getEditedPostContent ? (editor.getEditedPostContent() || '') : (editor.getEditedPostAttribute('content') || '');
					out.excerpt = editor.getEditedPostAttribute('excerpt') || '';
					var meta = editor.getEditedPostAttribute('meta') || {};
					out.seoTitle = meta.rank_math_title || meta._rank_math_title || meta._yoast_wpseo_title || meta._seopress_titles_title || '';
				}
			}
		} catch (e) {}

		var title = document.querySelector('#title, input[name="post_title"]');
		var excerpt = document.querySelector('#excerpt, textarea[name="excerpt"]');
		if (!out.title) out.title = title ? title.value : '';
		if (!out.excerpt) out.excerpt = excerpt ? excerpt.value : '';
		if (!out.content) {
			if (window.tinyMCE && tinyMCE.get('content')) {
				out.content = tinyMCE.get('content').getContent() || '';
			} else {
				var content = document.querySelector('#content, textarea[name="content"]');
				out.content = content ? content.value : '';
			}
		}
		if (!out.seoTitle) {
			var seo = document.querySelector('input[name="rank_math_title"], input[name="_rank_math_title"], input[name="_yoast_wpseo_title"], input[name="_seopress_titles_title"], textarea[name="rank_math_title"], textarea[name="_yoast_wpseo_title"]');
			out.seoTitle = seo ? seo.value : '';
		}
		return out;
	}

	function init(root) {
		if (!root || root.dataset.goReady === '1') return;
		root.dataset.goReady = '1';

		var postId = parseInt(root.getAttribute('data-post-id') || '0', 10);
		var idInput = root.querySelector('[data-go-game-id]');
		var modeInput = root.querySelector('[data-go-game-mode]');
		var status = root.querySelector('[data-go-game-status]');
		var feedback = root.querySelector('[data-go-game-feedback]');
		var suggestion = root.querySelector('[data-go-game-suggestion]');
		var results = root.querySelector('[data-go-game-results]');
		var search = root.querySelector('[data-go-game-search]');
		var searchButton = root.querySelector('[data-go-game-search-button]');
		var analyzeButton = root.querySelector('[data-go-game-analyze]');

		function setFeedback(message, kind) {
			if (!feedback) return;
			feedback.textContent = message || '';
			feedback.className = 'go-game-intelligence__feedback' + (kind ? ' is-' + kind : '');
		}

		function setStatus(game, mode) {
			if (!status || !idInput || !modeInput) return;
			if (game && game.id) {
				idInput.value = String(game.id);
				modeInput.value = mode || 'manual';
				status.innerHTML = '';
				if (game.image) { var cover=document.createElement('img');cover.className='go-game-intelligence__linked-cover';cover.src=game.image;cover.alt='';status.appendChild(cover); }
				var copy=document.createElement('div');copy.className='go-game-intelligence__linked-copy';
				var strong = document.createElement('strong');
				strong.textContent = game.title || '';
				var span = document.createElement('span');
				span.textContent = mode === 'auto' ? 'Vinculado automaticamente.' : 'Vinculado manualmente.';
				copy.appendChild(strong);copy.appendChild(span);
				var facts=[];if(game.platforms&&game.platforms.length)facts.push(game.platforms.join(' · '));if(game.release)facts.push('Lançamento: '+game.release);if(game.stores&&game.stores.length)facts.push('Lojas: '+game.stores.join(', '));
				if(facts.length){var small=document.createElement('small');small.className='go-game-intelligence__linked-facts';small.textContent=facts.join('  |  ');copy.appendChild(small);}
				status.appendChild(copy);
			} else {
				idInput.value = '';
				modeInput.value = mode || 'none';
				status.innerHTML = '<span>Nenhum game vinculado.</span>';
			}
			updateUnlinkButton(!!(game && game.id));
		}

		function updateUnlinkButton(show) {
			var btn = root.querySelector('[data-go-game-unlink]');
			if (show && !btn) {
				btn = document.createElement('button');
				btn.type = 'button';
				btn.className = 'button-link-delete';
				btn.setAttribute('data-go-game-unlink', '');
				btn.textContent = 'Remover vínculo';
				var actions = root.querySelector('.go-game-intelligence__actions');
				if (actions) actions.appendChild(btn);
			}
			if (btn) btn.hidden = !show;
		}

		function renderSuggestion(game, score) {
			if (!suggestion) return;
			if (!game || !game.id) {
				suggestion.hidden = true;
				return;
			}
			suggestion.hidden = false;
			suggestion.innerHTML = '';
			suggestion.appendChild(document.createTextNode('Última sugestão: '));
			var strong = document.createElement('strong');
			strong.textContent = game.title || '';
			suggestion.appendChild(strong);
			if (score) suggestion.appendChild(document.createTextNode(' (' + score + '%)'));
		}

		function linkGame(game) {
			setFeedback('Salvando…');
			return post('go_verge_game_intelligence_link', { post_id: postId, game_id: game.id }).then(function (data) {
				setStatus(data.game || game, 'manual');
				setFeedback((cfg.i18n && cfg.i18n.linked) || 'Vínculo salvo.', 'success');
				if (results) results.hidden = true;
				return data;
			}).catch(function (error) {
				setFeedback(error.message, 'error');
			});
		}

		function renderResults(items) {
			if (!results) return;
			results.innerHTML = '';
			results.hidden = false;
			if (!items || !items.length) {
				results.innerHTML = '<p class="go-game-intelligence__empty"></p>';
				results.firstChild.textContent = (cfg.i18n && cfg.i18n.noResults) || 'Nenhum jogo encontrado.';
				return;
			}
			items.forEach(function (game) {
				var button = document.createElement('button');
				button.type = 'button';
				button.className = 'go-game-intelligence__result';
				button.dataset.gameId = String(game.id || '');
				if (game.image) {
					var img = document.createElement('img');
					img.src = game.image;
					img.alt = '';
					button.appendChild(img);
				}
				var text = document.createElement('span');
				text.textContent = game.title || '';
				button.appendChild(text);
				button.addEventListener('click', function () { linkGame(game); });
				results.appendChild(button);
			});
		}

		function runSearch() {
			var q = search ? search.value.trim() : '';
			if (q.length < 2) {
				renderResults([]);
				return;
			}
			setFeedback((cfg.i18n && cfg.i18n.searching) || 'Buscando…');
			post('go_verge_game_intelligence_search', { post_id: postId, q: q }).then(function (data) {
				renderResults(data.results || []);
				setFeedback('');
			}).catch(function (error) {
				setFeedback(error.message, 'error');
			});
		}

		if (searchButton) searchButton.addEventListener('click', runSearch);
		if (search) search.addEventListener('keydown', function (event) {
			if (event.key === 'Enter') {
				event.preventDefault();
				runSearch();
			}
		});
		var searchTimer = null;
		if (search) search.addEventListener('input', function () {
			window.clearTimeout(searchTimer);
			if (search.value.trim().length < 2) { if (results) results.hidden = true; return; }
			searchTimer = window.setTimeout(runSearch, 180);
		});

		if (analyzeButton) analyzeButton.addEventListener('click', function () {
			var context = editorContext();
			analyzeButton.disabled = true;
			setFeedback((cfg.i18n && cfg.i18n.loading) || 'Analisando…');
			post('go_verge_game_intelligence_analyze', {
				post_id: postId,
				title: context.title,
				seo_title: context.seoTitle,
				content: context.content,
				excerpt: context.excerpt
			}).then(function (data) {
				renderSuggestion(data.candidate, data.score || 0);
				if (data.candidate) {
					setFeedback((cfg.i18n && cfg.i18n.suggested) || 'Sugestão encontrada. Confirme manualmente para vincular agora.', 'success');
				} else {
					setFeedback((cfg.i18n && cfg.i18n.noConfident) || 'Nenhum jogo atingiu confiança suficiente. Nenhum vínculo foi alterado.', 'warning');
				}
			}).catch(function (error) {
				setFeedback(error.message, 'error');
			}).finally(function () {
				analyzeButton.disabled = false;
			});
		});

		root.addEventListener('click', function (event) {
			var unlink = event.target.closest('[data-go-game-unlink]');
			if (!unlink || !root.contains(unlink)) return;
			event.preventDefault();
			unlink.disabled = true;
			post('go_verge_game_intelligence_link', { post_id: postId, game_id: 0 }).then(function () {
				setStatus(null, 'none');
				setFeedback((cfg.i18n && cfg.i18n.unlinked) || 'Vínculo removido.', 'success');
			}).catch(function (error) {
				setFeedback(error.message, 'error');
			}).finally(function () {
				unlink.disabled = false;
			});
		});
	}

	function removeDuplicatePanels() {
		var roots = Array.prototype.slice.call(document.querySelectorAll('[data-go-game-intelligence]'));
		if (roots.length < 2) return;
		var keep = roots[0];
		roots.slice(1).forEach(function (root) {
			var box = root.closest('.postbox, .components-panel__body');
			if (box && box !== keep.closest('.postbox, .components-panel__body')) {
				box.remove();
			} else if (root !== keep) {
				root.remove();
			}
		});
	}

	function boot() {
		removeDuplicatePanels();
		document.querySelectorAll('[data-go-game-intelligence]').forEach(init);
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', boot);
	} else {
		boot();
	}

	// Gutenberg can remount document panels. Inspect only added nodes instead
	// of rescanning the entire editor after every block/React mutation.
	var observer = new MutationObserver(function (mutations) {
		var touchedGamePanel = false;
		mutations.forEach(function (mutation) {
			Array.prototype.forEach.call(mutation.addedNodes || [], function (node) {
				if (!node || node.nodeType !== 1) return;
				if (node.matches && node.matches('[data-go-game-intelligence]')) {
					touchedGamePanel = true;
					init(node);
				}
				if (node.querySelectorAll) {
					var nested = node.querySelectorAll('[data-go-game-intelligence]');
					if (nested.length) {
						touchedGamePanel = true;
						nested.forEach(init);
					}
				}
			});
		});
		if (touchedGamePanel) { removeDuplicatePanels(); }
	});
	observer.observe(document.documentElement, { childList: true, subtree: true });
}());
