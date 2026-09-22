/**
 * Preenchimento automático de ALT text e legenda ao inserir uma imagem.
 *
 * COMO ELE DECIDE QUE PODE ESCREVER
 * ---------------------------------
 * Só em campo vazio, e só uma vez por bloco. O texto de uma pessoa nunca é
 * sobrescrito, nem depois de um undo: cada bloco atendido fica registrado por
 * clientId, então apagar o alt de propósito continua sendo uma decisão que o
 * editor toma e a máquina respeita.
 *
 * POR QUE NÃO CHAMA O MODELO DE VISÃO
 * -----------------------------------
 * `local-ai-image-text.js` baixa ~200 MB de pesos na primeira execução. Isso é
 * aceitável quando o editor clica em "Sugerir"; é inaceitável a cada foto
 * inserida. Este arquivo usa o que o CMS já sabe (entidades da matéria, IPTC do
 * arquivo, legenda da mídia) e responde em uma requisição. O botão de IA
 * continua existindo e sobrescreve o que veio daqui.
 *
 * @package go-verge
 */
(function (window, wp) {
	'use strict';

	var config = window.GoVergeImageAutotext || {};
	if (!wp || !wp.data || !wp.apiFetch || !wp.data.select || !wp.data.dispatch) {
		return;
	}

	var ENDPOINT = config.endpoint || '/go-verge/v1/image-text-suggestion';
	var FILL_CAPTION = false !== config.fillCaption;

	/* Blocos já atendidos nesta sessão do editor. */
	var handled = Object.create(null);
	/* Requisições em voo, por attachment: várias inserções da mesma foto não
	   viram várias chamadas. */
	var inFlight = Object.create(null);

	function plainText(value) {
		if (!value) {
			return '';
		}
		var node = window.document.createElement('div');
		node.innerHTML = String(value);
		return String(node.textContent || node.innerText || '').replace(/\s+/g, ' ').trim();
	}

	function currentPostId() {
		try {
			var editor = wp.data.select('core/editor');
			return editor && editor.getCurrentPostId ? Number(editor.getCurrentPostId()) || 0 : 0;
		} catch (error) {
			return 0;
		}
	}

	/**
	 * Texto ao redor da imagem, para o servidor desempatar entre entidades.
	 * Deliberadamente curto: é dica de contexto, não o artigo inteiro.
	 */
	function nearbyText(clientId) {
		try {
			var select = wp.data.select('core/block-editor');
			var order = select.getBlockOrder();
			var index = order.indexOf(clientId);
			if (index < 0) {
				return '';
			}
			var parts = [];
			[index - 1, index + 1].forEach(function (position) {
				if (position < 0 || position >= order.length) {
					return;
				}
				var block = select.getBlock(order[position]);
				if (block && block.attributes && block.attributes.content) {
					parts.push(plainText(block.attributes.content));
				}
			});
			return parts.join(' ').slice(0, 400);
		} catch (error) {
			return '';
		}
	}

	function fetchSuggestion(attachmentId, postId, context) {
		var key = attachmentId + '|' + postId;
		if (inFlight[key]) {
			return inFlight[key];
		}
		var path = ENDPOINT +
			'?attachment_id=' + encodeURIComponent(attachmentId) +
			'&post_id=' + encodeURIComponent(postId) +
			'&context=' + encodeURIComponent(context || '');
		inFlight[key] = wp.apiFetch({ path: path }).then(function (data) {
			delete inFlight[key];
			return data || null;
		}).catch(function () {
			delete inFlight[key];
			return null;
		});
		return inFlight[key];
	}

	/**
	 * Um bloco de imagem só é candidato quando tem anexo, ainda não foi
	 * atendido, e tem pelo menos um dos dois campos vazio.
	 */
	function needsText(block) {
		if (!block || 'core/image' !== block.name || !block.clientId) {
			return false;
		}
		if (handled[block.clientId]) {
			return false;
		}
		var attrs = block.attributes || {};
		if (!Number(attrs.id)) {
			return false;
		}
		var altEmpty = !plainText(attrs.alt);
		var captionEmpty = !plainText(attrs.caption);
		return altEmpty || (FILL_CAPTION && captionEmpty);
	}

	function applySuggestion(clientId, suggestion) {
		var select = wp.data.select('core/block-editor');
		var block = select.getBlock(clientId);
		if (!block || !suggestion) {
			return;
		}
		var attrs = block.attributes || {};
		var next = {};

		/* Reler no momento da escrita: entre o pedido e a resposta o editor pode
		   ter digitado, e nesse caso quem manda é ele. */
		if (!plainText(attrs.alt) && suggestion.alt) {
			next.alt = suggestion.alt;
		}
		if (FILL_CAPTION && !plainText(attrs.caption) && suggestion.caption) {
			next.caption = suggestion.caption;
		}
		if (!Object.keys(next).length) {
			return;
		}

		wp.data.dispatch('core/block-editor').updateBlockAttributes(clientId, next);

		/*
		 * Aviso de crédito ausente. É a única coisa que este módulo NÃO resolve
		 * sozinho por princípio, então precisa aparecer para a redação em vez de
		 * ser preenchido com uma agência plausível.
		 */
		if (next.caption && suggestion.credit_missing && wp.data.dispatch('core/notices')) {
			notifyCreditOnce(suggestion.attachment_id);
		}
	}

	var creditNotified = Object.create(null);
	function notifyCreditOnce(attachmentId) {
		if (creditNotified[attachmentId]) {
			return;
		}
		creditNotified[attachmentId] = true;
		try {
			wp.data.dispatch('core/notices').createNotice(
				'warning',
				(config.i18n && config.i18n.creditMissing) || 'Legenda sem crédito.',
				{ id: 'go-verge-image-credit-' + attachmentId, isDismissible: true, type: 'snackbar' }
			);
		} catch (error) { /* notices store ausente: silencioso, não fatal */ }
	}

	function scan() {
		var select;
		try {
			select = wp.data.select('core/block-editor');
		} catch (error) {
			return;
		}
		if (!select || !select.getBlocks) {
			return;
		}
		var postId = currentPostId();
		var pending = [];
		(function walk(blocks) {
			(blocks || []).forEach(function (block) {
				if (needsText(block)) {
					pending.push(block);
				}
				if (block && block.innerBlocks && block.innerBlocks.length) {
					walk(block.innerBlocks);
				}
			});
		})(select.getBlocks());

		pending.forEach(function (block) {
			/* Marcar antes da requisição: o subscribe dispara muitas vezes por
			   segundo e sem isto a mesma imagem geraria uma fila de chamadas. */
			handled[block.clientId] = true;
			fetchSuggestion(Number(block.attributes.id), postId, nearbyText(block.clientId)).then(function (suggestion) {
				if (suggestion) {
					applySuggestion(block.clientId, suggestion);
				}
			});
		});
	}

	var scheduled = null;
	function scheduleScan() {
		if (scheduled) {
			return;
		}
		scheduled = window.setTimeout(function () {
			scheduled = null;
			scan();
		}, 400);
	}

	function start() {
		try {
			if (!wp.data.select('core/block-editor')) {
				return;
			}
		} catch (error) {
			return;
		}
		wp.data.subscribe(scheduleScan);
		scheduleScan();
	}

	if (wp.domReady) {
		wp.domReady(start);
	} else if ('loading' === window.document.readyState) {
		window.document.addEventListener('DOMContentLoaded', start, { once: true });
	} else {
		start();
	}

	/* Exposto para o painel editorial e para testes. */
	window.GoVergeImageAutotext = window.GoVergeImageAutotext || {};
	window.GoVergeImageAutotext.rescan = function (clientId) {
		if (clientId) {
			delete handled[clientId];
		} else {
			handled = Object.create(null);
		}
		scheduleScan();
	};
})(window, window.wp);
