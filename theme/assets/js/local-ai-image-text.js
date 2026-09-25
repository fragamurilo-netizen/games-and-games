(function (window, document, wp) {
	'use strict';

	var config = window.GoVergeLocalAIConfig || {};
	var apiFetch = wp && wp.apiFetch ? wp.apiFetch : null;
	var runtimePromise = null;
	var captionerPromise = null;
	var captionerModel = '';
	var translatorPromise = null;
	var detectorPromise = null;
	var browserLanguageModelPromise = null;

	function emitProgress(stage, message, progress) {
		var detail = {
			stage: stage || 'working',
			message: message || '',
			progress: typeof progress === 'number' ? Math.max(0, Math.min(100, progress)) : null
		};
		try {
			document.dispatchEvent(new CustomEvent('go-verge-local-ai-progress', { detail: detail }));
		} catch (error) {}
	}

	function plainText(value) {
		var node = document.createElement('div');
		node.innerHTML = String(value || '');
		return String(node.textContent || node.innerText || '')
			.replace(/\s+/g, ' ')
			.trim();
	}

	function truncate(value, limit) {
		value = String(value || '').trim();
		if (value.length <= limit) {
			return value;
		}
		return value.slice(0, limit - 1).replace(/\s+\S*$/, '').trim() + '…';
	}

	function sentenceCase(value) {
		value = String(value || '').trim();
		if (!value) {
			return '';
		}
		return value.charAt(0).toLocaleUpperCase('pt-BR') + value.slice(1);
	}


	function normalizeCompare(value) {
		value = String(value || '').toLocaleLowerCase('pt-BR');
		if (value.normalize) {
			value = value.normalize('NFD').replace(/[̀-ͯ]/g, '');
		}
		return value.replace(/\s+/g, ' ').trim();
	}

	function stripLeadingImageWords(value) {
		return String(value || '')
			.replace(/^\s*(?:uma?|the)\s+(?:imagem|foto|picture|image|photograph)\s+(?:de|of)\s+/i, '')
			.replace(/^\s*(?:imagem|foto|picture|image|photograph)\s+(?:de|of)\s+/i, '')
			.trim();
	}

	function normalizePortugueseVisual(value) {
		var text = plainText(value)
			.replace(/\s+([,.;!?])/g, '$1')
			.replace(/\s+/g, ' ')
			.trim();
		text = stripLeadingImageWords(text);
		text = text.replace(/[.!?]+$/, '').trim();
		return truncate(sentenceCase(text), 180);
	}

	function topicFromTitle(title) {
		var topic = plainText(title)
			.replace(/^(?:veja|saiba|entenda|descubra|confira)\s+/i, '')
			.replace(/\s*[:|]\s*.+$/, '')
			.trim();
		return truncate(topic, 110);
	}

	function englishFallbackToPortuguese(value) {
		var text = String(value || '').toLowerCase().trim();
		var replacements = [
			[/\bscene related to the article\b/g, 'cena relacionada ao conteúdo da matéria'], [/\ba man\b/g, 'um homem'], [/\ba woman\b/g, 'uma mulher'], [/\ba person\b/g, 'uma pessoa'],
			[/\btwo people\b/g, 'duas pessoas'], [/\bpeople\b/g, 'pessoas'], [/\ba child\b/g, 'uma criança'],
			[/\ba video game\b/g, 'um videogame'], [/\bvideo game\b/g, 'videogame'], [/\ba game controller\b/g, 'um controle de videogame'],
			[/\ba computer screen\b/g, 'uma tela de computador'], [/\ba screen\b/g, 'uma tela'], [/\ba phone\b/g, 'um celular'],
			[/\ba car\b/g, 'um carro'], [/\ba motorcycle\b/g, 'uma motocicleta'], [/\ba building\b/g, 'um prédio'],
			[/\ba city\b/g, 'uma cidade'], [/\ba street\b/g, 'uma rua'], [/\ba room\b/g, 'um ambiente interno'],
			[/\ba table\b/g, 'uma mesa'], [/\ba dog\b/g, 'um cachorro'], [/\ba cat\b/g, 'um gato'],
			[/\btraditional clothing\b/g, 'trajes tradicionais'], [/\bwearing armor\b/g, 'vestindo armadura'], [/\bin armor\b/g, 'com armadura'],
			[/\barmor\b/g, 'armadura'], [/\bcostume\b/g, 'traje'], [/\bwearing\b/g, 'vestindo'], [/\bdressed in\b/g, 'vestida de'],
			[/\blong hair\b/g, 'cabelo comprido'], [/\bhair tied up\b/g, 'cabelo preso'], [/\bblack\b/g, 'preto'], [/\bred\b/g, 'vermelho'],
			[/\bstanding\b/g, 'em pé'], [/\bsitting\b/g, 'sentado'], [/\bholding\b/g, 'segurando'], [/\bplaying\b/g, 'jogando'],
			[/\bwalking\b/g, 'caminhando'], [/\brunning\b/g, 'correndo'], [/\bin front of\b/g, 'diante de'], [/\bnext to\b/g, 'ao lado de'],
			[/\bon a\b/g, 'sobre uma'], [/\bin a\b/g, 'em um'], [/\bwith a\b/g, 'com um'], [/\bwith\b/g, 'com'],
			[/\band\b/g, 'e'], [/\bthe\b/g, 'o'], [/\ba\b/g, 'um']
		];
		replacements.forEach(function (item) { text = text.replace(item[0], item[1]); });
		return normalizePortugueseVisual(text);
	}

	function currentPostId(explicit) {
		if (explicit) {
			return Number(explicit) || 0;
		}
		try {
			if (wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getCurrentPostId) {
					return Number(editor.getCurrentPostId()) || Number(config.postId) || 0;
				}
			}
		} catch (error) {}
		return Number(config.postId) || 0;
	}

	function editedPostContext(nearby) {
		var result = {
			post_title: '',
			post_subtitle: '',
			post_excerpt: '',
			post_content: '',
			meta_description: '',
			context: plainText(nearby || ''),
			linked_game: '',
			focus_keyword: '',
			categories: ''
		};

		try {
			if (wp && wp.data && wp.data.select) {
				var editor = wp.data.select('core/editor');
				if (editor && editor.getEditedPostAttribute) {
					result.post_title = plainText(editor.getEditedPostAttribute('title') || '');
					result.post_excerpt = plainText(editor.getEditedPostAttribute('excerpt') || '');
					result.post_content = truncate(plainText(editor.getEditedPostAttribute('content') || ''), 2600);
				}
			}
		} catch (error) {}

		return result;
	}

	function mergeEditorial(serverEditorial, browserEditorial) {
		serverEditorial = serverEditorial || {};
		browserEditorial = browserEditorial || {};
		return {
			post_title: browserEditorial.post_title || serverEditorial.post_title || '',
			post_subtitle: browserEditorial.post_subtitle || serverEditorial.post_subtitle || '',
			post_excerpt: browserEditorial.post_excerpt || serverEditorial.post_excerpt || '',
			post_content: browserEditorial.post_content || serverEditorial.post_content || '',
			meta_description: browserEditorial.meta_description || serverEditorial.meta_description || '',
			context: browserEditorial.context || serverEditorial.context || '',
			linked_game: serverEditorial.linked_game || '',
			focus_keyword: serverEditorial.focus_keyword || browserEditorial.focus_keyword || '',
			categories: serverEditorial.categories || ''
		};
	}

	function getRuntime() {
		if (!runtimePromise) {
			emitProgress('runtime', 'Carregando o motor gratuito de IA local…', null);
			runtimePromise = import(config.transformersUrl || 'https://cdn.jsdelivr.net/npm/@xenova/transformers@2.17.2')
				.then(function (runtime) {
					if (runtime && runtime.env) {
						runtime.env.allowLocalModels = false;
						runtime.env.useBrowserCache = true;
					}
					return runtime;
				})
				.catch(function (error) {
					runtimePromise = null;
					throw new Error('Não foi possível carregar o motor gratuito de IA. Verifique a conexão ou bloqueios de CDN. ' + (error && error.message ? error.message : ''));
				});
		}
		return runtimePromise;
	}

	function modelProgress(label) {
		return function (info) {
			if (!info) {
				return;
			}
			var percent = typeof info.progress === 'number' ? info.progress : null;
			var status = String(info.status || '');
			var file = info.file ? ' ' + String(info.file).split('/').pop() : '';
			if (status === 'progress') {
				emitProgress('download', label + ': baixando modelo' + file + (percent !== null ? ' (' + Math.round(percent) + '%)' : '') + '…', percent);
			} else if (status === 'ready') {
				emitProgress('ready', label + ' pronto.', 100);
			} else if (status) {
				emitProgress('download', label + ': ' + status + file + '…', percent);
			}
		};
	}

	function friendlyModelError(error) {
		var message = error && error.message ? String(error.message) : '';
		if (/unauthorized access to file|401|403|forbidden|unauthorized/i.test(message)) {
			return 'O modelo visual principal não pôde ser baixado. A IA vai tentar um modo alternativo local.';
		}
		if (/failed to fetch|network|cdn|fetch/i.test(message)) {
			return 'Falha de conexão ao baixar o modelo visual. A IA vai tentar um modo alternativo local.';
		}
		return 'O modelo visual principal ficou indisponível. A IA vai tentar um modo alternativo local.';
	}

	function friendlyGenerationError(error) {
		var message = error && error.message ? String(error.message) : '';
		if (/unauthorized access to file|401|403|forbidden|unauthorized|failed to fetch|network|cdn|fetch/i.test(message)) {
			return friendlyModelError(error);
		}
		if (/^(?:Não|A |O |Falha|Imagem|Modelo|Texto|Cena|Arquivo)/i.test(message)) {
			return message;
		}
		return message || 'Não foi possível concluir a análise local desta imagem.';
	}

	function configuredVisionModels() {
		var models = [];
		if (Array.isArray(config.visionModels)) {
			models = config.visionModels.slice();
		}
		if (config.visionModel && models.indexOf(config.visionModel) < 0) {
			models.unshift(config.visionModel);
		}
		if (!models.length) {
			models = ['Xenova/vit-gpt2-image-captioning'];
		}
		return models.filter(Boolean);
	}

	function getCaptioner() {
		if (!captionerPromise) {
			captionerPromise = getRuntime().then(function (runtime) {
				var models = configuredVisionModels();
				var index = 0;

				function tryNext() {
					if (index >= models.length) {
						emitProgress('warning', 'Modelo de legenda visual indisponível. Usando análise alternativa por objetos.', null);
						return null;
					}
					var modelName = models[index++];
					emitProgress('model', 'Preparando modelo visual local…', null);
					return runtime.pipeline(
						'image-to-text',
						modelName,
						{ quantized: true, progress_callback: modelProgress('IA de visão') }
					).then(function (pipeline) {
						captionerModel = modelName;
						return pipeline;
					}).catch(function (error) {
						emitProgress('warning', friendlyModelError(error), null);
						return tryNext();
					});
				}

				return tryNext();
			}).catch(function () {
				return null;
			});
		}
		return captionerPromise;
	}

	function getDetector() {
		if (!detectorPromise) {
			detectorPromise = getRuntime().then(function (runtime) {
				emitProgress('model', 'Preparando verificação visual anti-alucinação…', null);
				return runtime.pipeline(
					'object-detection',
					config.objectModel || 'Xenova/detr-resnet-50',
					{ quantized: true, progress_callback: modelProgress('Verificação visual') }
				);
			}).catch(function () {
				/* Optional quality layer: generation still works if detector fails. */
				detectorPromise = Promise.resolve(null);
				return null;
			});
		}
		return detectorPromise;
	}

	function getTranslator() {
		if (!translatorPromise) {
			translatorPromise = getRuntime().then(function (runtime) {
				emitProgress('model', 'Preparando tradução local para português…', null);
				return runtime.pipeline(
					'translation',
					config.translationModel || 'Xenova/opus-mt-en-pt',
					{ quantized: true, progress_callback: modelProgress('Tradução local') }
				);
			}).catch(function () {
				translatorPromise = Promise.resolve(null);
				return null;
			});
		}
		return translatorPromise;
	}

	function getBrowserLanguageModel() {
		if (browserLanguageModelPromise) {
			return browserLanguageModelPromise;
		}

		browserLanguageModelPromise = Promise.resolve().then(function () {
			var api = null;
			if (window.LanguageModel && typeof window.LanguageModel.create === 'function') {
				api = window.LanguageModel;
			} else if (window.ai && window.ai.languageModel && typeof window.ai.languageModel.create === 'function') {
				api = window.ai.languageModel;
			}
			if (!api) {
				return null;
			}
			return api.create();
		}).catch(function () { return null; });

		return browserLanguageModelPromise;
	}

	function parseJsonObject(value) {
		var text = String(value || '').trim();
		var start = text.indexOf('{');
		var end = text.lastIndexOf('}');
		if (start >= 0 && end > start) {
			text = text.slice(start, end + 1);
		}
		try {
			var parsed = JSON.parse(text);
			return parsed && typeof parsed === 'object' ? parsed : null;
		} catch (error) {
			return null;
		}
	}

	function refineWithBrowserLanguageModel(visualPt, visualEn, editorial) {
		return getBrowserLanguageModel().then(function (session) {
			if (!session || typeof session.prompt !== 'function') {
				return null;
			}

			var prompt = [
				'Você é editor de fotografia de um portal jornalístico brasileiro.',
				'A descrição visual é a fonte principal e tem prioridade absoluta sobre o contexto da matéria.',
				'O contexto editorial serve apenas para explicar por que a foto está na matéria; ele nunca pode mudar o que está visível.',
				'Se houver conflito entre imagem e contexto, preserve a imagem e ignore a inferência contextual.',
				'Não identifique pessoa, personagem, marca, local, objeto ou ação que não esteja explicitamente sustentado pela descrição visual.',
				'Crie título de mídia, texto alternativo e legenda.',
				'O título da mídia deve ser curto e específico, sem mencionar IA, automação ou processo interno.',
				'O alt deve começar pelo que é visível, ser objetivo, natural, ter no máximo 180 caracteres e incluir a palavra-chave de foco se ela existir.',
				'A legenda pode ter até duas frases: a primeira descreve a foto; a segunda conecta com o assunto real da matéria sem inventar fatos visuais.',
				'Não use fórmulas como "imagem relacionada a", "imagem que ilustra" ou "em contexto abordado pela matéria".',
				'Não comece o alt com "imagem de" ou "foto de".',
				'Não escreva "IA", "AI", "gerado por IA" ou equivalente, salvo quando a própria matéria for sobre inteligência artificial.',
				'Retorne apenas JSON: {"title":"...","alt":"...","caption":"..."}.',
				'Descrição visual em português: ' + visualPt,
				'Descrição visual original: ' + visualEn,
				'Palavra-chave de foco: ' + (editorial.focus_keyword || ''),
				'Título: ' + (editorial.post_title || ''),
				'Subtítulo: ' + (editorial.post_subtitle || ''),
				'Game vinculado: ' + (editorial.linked_game || ''),
				'Contexto próximo: ' + (editorial.context || ''),
				'Resumo: ' + (editorial.post_excerpt || ''),
				'Meta descrição: ' + (editorial.meta_description || ''),
				'Trecho da matéria: ' + truncate(editorial.post_content || '', 1400)
			].join('\n');

			emitProgress('refine', 'Refinando o texto com base na foto…', null);
			return session.prompt(prompt).then(function (answer) {
				return parseJsonObject(answer);
			}).catch(function () { return null; });
		});
	}

	function looksLikeGameVisual(englishVisual, portugueseVisual) {
		var text = (String(englishVisual || '') + ' ' + String(portugueseVisual || '')).toLowerCase();
		return /video game|game screen|gameplay|character|controller|console|videogame|jogo|personagem|controle|console|tela/.test(text);
	}

	function bestContextualSentence(content, visualPt) {
		var stop = {
			'de':1,'da':1,'do':1,'das':1,'dos':1,'a':1,'o':1,'as':1,'os':1,'e':1,'em':1,'um':1,'uma':1,'para':1,'por':1,'com':1,'que':1,'se':1,'no':1,'na':1,'nos':1,'nas':1,'ao':1,'à':1,'sobre':1,'como':1
		};
		var visualWords = plainText(visualPt).toLowerCase().split(/[^a-zà-ÿ0-9]+/i).filter(function (word) {
			return word.length > 3 && !stop[word];
		});
		if (!visualWords.length) {
			return '';
		}
		var sentences = plainText(content).split(/(?<=[.!?])\s+/).slice(0, 50);
		var best = '';
		var bestScore = 0;
		sentences.forEach(function (sentence) {
			var low = sentence.toLowerCase();
			var score = visualWords.reduce(function (sum, word) { return sum + (low.indexOf(word) >= 0 ? 1 : 0); }, 0);
			if (score > bestScore) {
				bestScore = score;
				best = sentence;
			}
		});
		return bestScore > 0 ? truncate(best, 180) : '';
	}

	function normalizedDetectorLabels(detections) {
		return (detections || []).filter(function (item) {
			return item && Number(item.score || 0) >= 0.30;
		}).map(function (item) {
			return String(item.label || '').toLowerCase().trim();
		});
	}

	function detectorHas(labels, accepted) {
		return (accepted || []).some(function (candidate) {
			candidate = String(candidate || '').toLowerCase();
			return labels.some(function (label) {
				return label === candidate || label.indexOf(candidate) >= 0 || candidate.indexOf(label) >= 0;
			});
		});
	}

	function removeUnsupportedObjectClaims(value, detections) {
		var text = String(value || '');
		if (!text || detections === null || typeof detections === 'undefined') {
			return text;
		}
		var labels = normalizedDetectorLabels(detections);

		var rules = [
			{
				labels: ['cell phone', 'mobile phone'],
				patterns: [
					/\s+(?:holding|using|looking at|with)\s+(?:a\s+)?(?:cell\s*phone|mobile\s*phone|smartphone|phone)\b/ig,
					/\s+(?:segurando|usando|olhando para|com)\s+(?:um\s+)?(?:celular|smartphone|telefone)\b/ig
				]
			},
			{ labels: ['laptop'], patterns: [/\s+(?:holding|using|with)\s+(?:a\s+)?laptop\b/ig, /\s+(?:segurando|usando|com)\s+(?:um\s+)?notebook\b/ig] },
			{ labels: ['remote'], patterns: [/\s+(?:holding|using|with)\s+(?:a\s+)?remote\b/ig, /\s+(?:segurando|usando|com)\s+(?:um\s+)?controle remoto\b/ig] },
			{ labels: ['book'], patterns: [/\s+(?:holding|reading|with)\s+(?:a\s+)?book\b/ig, /\s+(?:segurando|lendo|com)\s+(?:um\s+)?livro\b/ig] },
			{ labels: ['bottle'], patterns: [/\s+(?:holding|drinking from|with)\s+(?:a\s+)?bottle\b/ig, /\s+(?:segurando|bebendo de|com)\s+(?:uma\s+)?garrafa\b/ig] },
			{ labels: ['cup'], patterns: [/\s+(?:holding|drinking from|with)\s+(?:a\s+)?cup\b/ig, /\s+(?:segurando|bebendo de|com)\s+(?:um\s+)?copo\b/ig] },
			{ labels: ['dog'], patterns: [/\s+(?:with|next to)\s+(?:a\s+)?dog\b/ig, /\s+(?:com|ao lado de)\s+(?:um\s+)?cachorro\b/ig] },
			{ labels: ['cat'], patterns: [/\s+(?:with|next to)\s+(?:a\s+)?cat\b/ig, /\s+(?:com|ao lado de)\s+(?:um\s+)?gato\b/ig] },
			{ labels: ['car'], patterns: [/\s+(?:with|next to|inside)\s+(?:a\s+)?car\b/ig, /\s+(?:com|ao lado de|dentro de)\s+(?:um\s+)?carro\b/ig] }
		];

		rules.forEach(function (rule) {
			if (!detectorHas(labels, rule.labels)) {
				rule.patterns.forEach(function (pattern) { text = text.replace(pattern, ''); });
			}
		});

		return text.replace(/\s{2,}/g, ' ').replace(/\s+([,.;!?])/g, '$1').trim();
	}

	function detectorLabelToPortuguese(label) {
		var map = {
			'person':'pessoa','car':'carro','motorcycle':'motocicleta','bicycle':'bicicleta',
			'dog':'cachorro','cat':'gato','cell phone':'celular','laptop':'notebook',
			'book':'livro','bottle':'garrafa','cup':'copo','tv':'televisão','chair':'cadeira',
			'backpack':'mochila','handbag':'bolsa','sports ball':'bola','keyboard':'teclado',
			'mouse':'mouse','remote':'controle remoto'
		};
		return map[label] || label;
	}

	function visualFromDetections(detections) {
		var labels = normalizedDetectorLabels(detections);
		if (!labels.length) {
			return '';
		}
		var counts = {};
		labels.forEach(function (label) { counts[label] = (counts[label] || 0) + 1; });
		var parts = [];
		Object.keys(counts).slice(0, 3).forEach(function (label) {
			var pt = detectorLabelToPortuguese(label);
			var count = counts[label];
			if (label === 'person') {
				parts.push(count > 1 ? 'pessoas' : 'uma pessoa');
			} else {
				parts.push((count > 1 ? count + ' ' : 'um ') + pt);
			}
		});
		if (!parts.length) {
			return '';
		}
		if (parts.length === 1) {
			return sentenceCase(parts[0]);
		}
		return sentenceCase(parts.slice(0, -1).join(', ') + ' e ' + parts[parts.length - 1]);
	}

	function articleTopic(editorial, contextData) {
		var source = plainText((editorial && editorial.post_title) || '');
		var attachmentTitle = plainText(contextData && contextData.attachment ? contextData.attachment.title : '');
		if (!source) {
			source = attachmentTitle.replace(/[-_]+/g, ' ');
		}
		return topicFromTitle(source);
	}

	function enrichGenericVisualWithTopic(alt, topic) {
		/* Context must never rewrite what the vision model actually saw. */
		return normalizePortugueseVisual(alt);
	}

	function lowerFirst(value) {
		value = plainText(value || '');
		if (!value) {
			return '';
		}
		return value.charAt(0).toLocaleLowerCase('pt-BR') + value.slice(1);
	}

	function cleanEditorialSnippet(value, limit) {
		var textValue = plainText(value || '')
			.replace(/^[-:–—\s]+/, '')
			.replace(/[.!?]+$/g, '')
			.replace(/\s+/g, ' ')
			.trim();
		if (!textValue) {
			return '';
		}
		return truncate(textValue, limit || 170);
	}

	function collectSignalWords(editorial, visualPt) {
		var stop = {
			'de':1,'da':1,'do':1,'das':1,'dos':1,'a':1,'o':1,'as':1,'os':1,'e':1,'em':1,'um':1,'uma':1,'para':1,'por':1,'com':1,'que':1,'se':1,'no':1,'na':1,'nos':1,'nas':1,'ao':1,'à':1,'sobre':1,'como':1,'mais':1,'menos':1,'ser':1,'ter':1,'esta':1,'esse':1,'essa':1,'isso':1,'este':1
		};
		var pool = [visualPt, editorial.post_title, editorial.post_subtitle, editorial.post_excerpt, editorial.meta_description, editorial.context, editorial.focus_keyword, editorial.linked_game].join(' ');
		var words = plainText(pool).toLocaleLowerCase('pt-BR').split(/[^a-zà-ÿ0-9]+/i).filter(function (word) {
			return word.length > 3 && !stop[word];
		});
		var seen = {};
		return words.filter(function (word) {
			if (seen[word]) {
				return false;
			}
			seen[word] = true;
			return true;
		}).slice(0, 28);
	}

	function scoreSnippet(snippet, signals, editorial) {
		var textValue = normalizeCompare(snippet);
		if (!textValue) {
			return 0;
		}
		var score = 0;
		(signals || []).forEach(function (signal) {
			if (signal && textValue.indexOf(normalizeCompare(signal)) >= 0) {
				score += signal.length > 7 ? 3 : 2;
			}
		});
		if (editorial.focus_keyword && textValue.indexOf(normalizeCompare(editorial.focus_keyword)) >= 0) {
			score += 5;
		}
		if (editorial.linked_game && textValue.indexOf(normalizeCompare(editorial.linked_game)) >= 0) {
			score += 4;
		}
		if (snippet.length > 140) {
			score -= 1;
		}
		return score;
	}

	function bestContentSnippets(content, editorial, visualPt) {
		var sentences = plainText(content).split(/(?<=[.!?])\s+/).map(function (sentence) {
			return cleanEditorialSnippet(sentence, 170);
		}).filter(Boolean);
		var signals = collectSignalWords(editorial, visualPt);
		return sentences.map(function (sentence) {
			return { text: sentence, score: scoreSnippet(sentence, signals, editorial) };
		}).filter(function (entry) {
			return entry.score > 0;
		}).sort(function (a, b) {
			return b.score - a.score;
		}).slice(0, 3).map(function (entry) {
			return entry.text;
		});
	}

	function buildCaptionAngle(editorial, visualPt, contextData) {
		var signals = collectSignalWords(editorial, visualPt);
		var candidates = [];
		var pushCandidate = function (value, bonus) {
			var cleaned = cleanEditorialSnippet(value, 165);
			if (!cleaned) {
				return;
			}
			candidates.push({
				text: cleaned,
				score: scoreSnippet(cleaned, signals, editorial) + (bonus || 0)
			});
		};

		pushCandidate(editorial.context, 10);
		pushCandidate(editorial.post_subtitle, 8);
		pushCandidate(editorial.post_excerpt, 6);
		pushCandidate(editorial.meta_description, 5);
		bestContentSnippets(editorial.post_content || '', editorial, visualPt).forEach(function (item, index) {
			pushCandidate(item, 4 - index);
		});
		pushCandidate(articleTopic(editorial, contextData), 2);
		if (editorial.focus_keyword) {
			pushCandidate(editorial.focus_keyword, 1);
		}
		if (editorial.linked_game) {
			pushCandidate(editorial.linked_game, 1);
		}

		var seen = {};
		var ordered = candidates.sort(function (a, b) { return b.score - a.score; }).filter(function (entry) {
			var key = normalizeCompare(entry.text);
			if (!key || seen[key]) {
				return false;
			}
			seen[key] = true;
			return true;
		});
		return ordered.length ? ordered[0].text : '';
	}

	function meaningfulVisualWords(value) {
		var stop = { 'uma':1,'um':1,'de':1,'da':1,'do':1,'das':1,'dos':1,'e':1,'com':1,'em':1,'no':1,'na':1,'nos':1,'nas':1,'para':1,'por':1,'sobre':1,'cena':1,'imagem':1,'foto':1 };
		var seen = {};
		return normalizeCompare(value).split(/[^a-z0-9à-ÿ]+/i).filter(function (word) {
			if (word.length < 4 || stop[word] || seen[word]) { return false; }
			seen[word] = true;
			return true;
		}).slice(0, 24);
	}

	function refinementKeepsVisualGrounding(candidate, visualPt, detections) {
		var textValue = normalizeCompare(candidate || '');
		if (!textValue) { return false; }
		var words = meaningfulVisualWords(visualPt || '');
		var labels = normalizedDetectorLabels(detections || []).map(detectorLabelToPortuguese);
		var evidence = words.concat(labels).filter(Boolean);
		if (!evidence.length) { return false; }
		return evidence.some(function (word) {
			word = normalizeCompare(word);
			return word && textValue.indexOf(word) >= 0;
		});
	}

	function visualLooksGeneric(value) {
		var textValue = normalizeCompare(value || '');
		return !textValue || /^(?:cena|conteudo|imagem|foto) relacionada/.test(textValue) || textValue === 'uma pessoa' || textValue === 'pessoa';
	}

	function chooseGroundedVisual(visualPt, visualEn, detections) {
		var grounded = normalizePortugueseVisual(removeUnsupportedObjectClaims(visualPt || '', detections));
		var detectorVisual = normalizePortugueseVisual(visualFromDetections(detections || []));
		if (visualLooksGeneric(grounded)) {
			return detectorVisual || '';
		}
		if (grounded) { return grounded; }
		if (detectorVisual) { return detectorVisual; }
		return normalizePortugueseVisual(englishFallbackToPortuguese(removeUnsupportedObjectClaims(visualEn || '', detections)));
	}

	function ensureFocusKeywordInAlt(alt, focusKeyword) {
		var focus = plainText(focusKeyword || '');
		var base = normalizePortugueseVisual(alt || '');
		if (!focus) {
			return truncate(base, 180);
		}
		if (!base) {
			return truncate(sentenceCase(focus), 180);
		}
		if (normalizeCompare(base).indexOf(normalizeCompare(focus)) >= 0) {
			return truncate(base, 180);
		}
		var appended = base.replace(/[.!?]+$/, '') + ', na cobertura de ' + focus;
		if (appended.length <= 180) {
			return truncate(normalizePortugueseVisual(appended), 180);
		}
		var prefixed = focus + ': ' + lowerFirst(base);
		return truncate(sentenceCase(prefixed), 180);
	}

	function buildMediaTitle(visual, editorial, contextData) {
		var cleanVisual = normalizePortugueseVisual(visual || '').replace(/[.!?]+$/, '');
		var focus = plainText((editorial && editorial.focus_keyword) || '');
		var topic = focus || plainText((editorial && editorial.linked_game) || '') || articleTopic(editorial, contextData);
		if (cleanVisual) {
			cleanVisual = lowerFirst(cleanVisual);
		}
		var title = '';
		if (topic && cleanVisual) {
			title = topic + ': ' + cleanVisual;
		} else if (topic) {
			title = topic;
		} else if (cleanVisual) {
			title = cleanVisual;
		} else if (editorial && editorial.post_title) {
			title = topicFromTitle(editorial.post_title);
		}
		return truncate(sentenceCase(plainText(title)), 110);
	}

	function editorialIsAboutAi(editorial) {
		var source = [
			editorial && editorial.post_title,
			editorial && editorial.post_subtitle,
			editorial && editorial.post_excerpt,
			editorial && editorial.meta_description,
			editorial && editorial.post_content,
			editorial && editorial.context,
			editorial && editorial.focus_keyword,
			editorial && editorial.categories,
			editorial && editorial.linked_game
		].join(' ');
		source = normalizeCompare(source);
		return /(\b(?:ia|ai)\b|inteligencia artificial|artificial intelligence|machine learning|aprendizado de maquina|generative ai|openai|chatgpt|gemini|copilot|midjourney)/i.test(source);
	}

	function stripUnwantedAiMentions(value, editorial) {
		var textValue = plainText(value || '');
		if (!textValue || editorialIsAboutAi(editorial)) {
			return textValue;
		}

		textValue = textValue
			.replace(/\s*[-–—|:]\s*(?:ia|ai)(?:\s+(?:local|gr[aá]tis|gratuita|autom[aá]tica|automatica|do site))?\b/gi, '')
			.replace(/\b(?:gerad[ao]s?|feito|feita|criad[ao]s?|produzid[ao]s?)\s+(?:por|com|via|usando)\s+(?:ia|ai)(?:\s+(?:local|gr[aá]tis|gratuita|autom[aá]tica|automatica|do site))?\b/gi, '')
			.replace(/\b(?:com|via|usando|feito com|feita com)\s+(?:intelig[eê]ncia artificial|(?:ia|ai)(?:\s+(?:local|gr[aá]tis|gratuita|autom[aá]tica|automatica|do site))?)\b/gi, '')
			.replace(/\bintelig[eê]ncia artificial\b/gi, '')
			.replace(/\b(?:ia|ai)(?:\s+(?:local|gr[aá]tis|gratuita|autom[aá]tica|automatica|do site))\b/gi, '')
			.replace(/\s{2,}/g, ' ')
			.replace(/\s+([,.;!?])/g, '$1')
			.replace(/[-–—|:]\s*$/g, '')
			.trim();

		return textValue;
	}

	function sanitizeEditorialOutputs(result, editorial) {
		result = result || {};
		return {
			title: truncate(sentenceCase(stripUnwantedAiMentions(result.title || '', editorial)), 110),
			alt: truncate(normalizePortugueseVisual(stripUnwantedAiMentions(result.alt || '', editorial)), 180),
			caption: truncate(sentenceCase(stripUnwantedAiMentions(result.caption || '', editorial)), 230),
			basis: result.basis || ''
		};
	}

	function composeLocally(visualPt, visualEn, editorial, contextData, detections) {
		var visual = chooseGroundedVisual(visualPt, visualEn, detections);
		if (!visual) {
			visual = 'Cena sem descrição visual confiável';
		}

		var alt = visual;
		var game = plainText(editorial.linked_game || '');
		var focusKeyword = plainText(editorial.focus_keyword || '');
		var angle = buildCaptionAngle(editorial, visual, contextData);
		var caption = visual.replace(/[.!?]+$/, '') + '.';

		if (game && looksLikeGameVisual(visualEn, visual)) {
			if (normalizeCompare(caption).indexOf(normalizeCompare(game)) < 0) {
				caption = visual.replace(/[.!?]+$/, '') + ' em cena de ' + game + '.';
			}
			if (angle && normalizeCompare(angle).indexOf(normalizeCompare(game)) < 0) {
				caption += ' A matéria aborda ' + lowerFirst(angle) + '.';
			}
		} else if (angle) {
			caption += ' A matéria aborda ' + lowerFirst(angle) + '.';
		}

		alt = ensureFocusKeywordInAlt(alt, focusKeyword);
		caption = caption.replace(/\s+/g, ' ').replace(/\s+([,.;!?])/g, '$1').trim();
		return sanitizeEditorialOutputs({
			title: buildMediaTitle(visual, editorial, contextData),
			alt: truncate(normalizePortugueseVisual(alt), 180),
			caption: truncate(sentenceCase(caption), 230)
		}, editorial);
	}

	function getContext(options) {
		if (!apiFetch) {
			return Promise.reject(new Error('A API interna do WordPress não está disponível.'));
		}
		var attachmentId = Number(options.attachmentId) || 0;
		var postId = currentPostId(options.postId);
		var nearby = plainText(options.context || '');
		var path = (config.contextEndpoint || '/go-verge/v1/local-image-ai-context') +
			'?attachment_id=' + encodeURIComponent(attachmentId) +
			'&post_id=' + encodeURIComponent(postId) +
			'&context=' + encodeURIComponent(nearby);

		return apiFetch({ path: path }).then(function (serverData) {
			serverData = serverData || {};
			serverData.editorial = mergeEditorial(serverData.editorial || {}, editedPostContext(nearby));
			serverData.editorial.attachment_title = serverData.attachment && serverData.attachment.title ? plainText(serverData.attachment.title) : '';
			if (options.imageUrl) {
				serverData.image_url = options.imageUrl;
			}
			return serverData;
		});
	}

	function translateCaption(englishCaption) {
		return getTranslator().then(function (translator) {
			if (!translator) {
				return englishFallbackToPortuguese(englishCaption);
			}
			emitProgress('translate', 'Traduzindo a análise visual para português…', null);
			return translator(englishCaption, { max_new_tokens: 96 }).then(function (output) {
				var first = output && output[0] ? output[0] : {};
				return normalizePortugueseVisual(first.translation_text || first.generated_text || englishFallbackToPortuguese(englishCaption));
			}).catch(function () {
				return englishFallbackToPortuguese(englishCaption);
			});
		});
	}

	function saveResult(attachmentId, mode, result) {
		if (!apiFetch) {
			return Promise.resolve(result);
		}
		return apiFetch({
			path: config.saveEndpoint || '/go-verge/v1/save-local-image-text',
			method: 'POST',
			data: {
				attachment_id: attachmentId,
				mode: mode || 'both',
				title: result.title || '',
				alt: result.alt || '',
				caption: result.caption || ''
			}
		}).then(function (saved) {
			return Object.assign({}, result, saved || {}, {
				ai_used: true,
				mode: 'local',
				basis: result.basis || 'IA local gratuita + contexto editorial'
			});
		});
	}

	function generate(options) {
		options = options || {};
		var attachmentId = Number(options.attachmentId) || 0;
		var mode = ['both', 'alt', 'caption'].indexOf(options.mode) >= 0 ? options.mode : 'both';
		if (!attachmentId) {
			return Promise.reject(new Error('A imagem precisa estar salva na Biblioteca de Mídia.'));
		}

		emitProgress('context', 'Lendo o contexto da matéria…', null);
		return getContext(options).then(function (contextData) {
			var imageUrl = contextData.image_url || options.imageUrl || '';
			if (!imageUrl) {
				throw new Error('Não foi possível localizar o arquivo da imagem.');
			}

			return Promise.all([getCaptioner(), getDetector()]).then(function (models) {
				var captioner = models[0];
				var detector = models[1];
				emitProgress('vision', 'A IA local está analisando a imagem…', null);

				var captionPromise = captioner ? captioner(imageUrl, {
					max_new_tokens: 72,
					num_beams: 5,
					early_stopping: true
				}).catch(function () { return null; }) : Promise.resolve(null);
				var detectionPromise = detector ? detector(imageUrl, { threshold: 0.20, percentage: true }).catch(function () { return null; }) : Promise.resolve(null);

				return Promise.all([captionPromise, detectionPromise]).then(function (visionResults) {
					var visionOutput = visionResults[0];
					var detections = visionResults[1] === null ? null : (visionResults[1] || []);
					var first = visionOutput && visionOutput[0] ? visionOutput[0] : {};
					var visualEnRaw = plainText(first.generated_text || first.caption || '');
					var visualEn = removeUnsupportedObjectClaims(visualEnRaw, detections);
					var detectorVisual = visualFromDetections(detections || []);
					if (!visualEn && !detectorVisual) {
						visualEn = 'scene related to the article';
					}

					var translationPromise = visualEn ? translateCaption(visualEn) : Promise.resolve(detectorVisual);
					return translationPromise.then(function (visualPtRaw) {
						if (!visualPtRaw && detectorVisual) {
							visualPtRaw = detectorVisual;
						}
						var visualPt = removeUnsupportedObjectClaims(visualPtRaw, detections);
						var editorial = contextData.editorial || {};
						return refineWithBrowserLanguageModel(visualPt, visualEn, editorial).then(function (refined) {
							var refinedTitle = refined && refined.title ? plainText(refined.title) : '';
							var refinedAlt = refined && refined.alt ? removeUnsupportedObjectClaims(refined.alt, detections) : '';
							var refinedCaption = refined && refined.caption ? removeUnsupportedObjectClaims(refined.caption, detections) : '';
							var groundedVisual = chooseGroundedVisual(visualPt, visualEn, detections);
							if (!groundedVisual) {
								throw new Error('A análise visual não reconheceu a foto com segurança. Tente outra imagem ou revise os campos manualmente.');
							}
							if (!refinementKeepsVisualGrounding(refinedAlt, groundedVisual, detections)) { refinedAlt = ''; }
							if (!refinementKeepsVisualGrounding(refinedCaption, groundedVisual, detections)) { refinedCaption = ''; }
							var localComposed = composeLocally(groundedVisual, visualEn, editorial, contextData, detections);
							var result = refinedAlt ? {
								title: truncate(sentenceCase(plainText(refinedTitle || localComposed.title)), 110),
								alt: ensureFocusKeywordInAlt(truncate(normalizePortugueseVisual(refinedAlt), 180), editorial.focus_keyword || ''),
								caption: truncate(sentenceCase(plainText(refinedCaption || localComposed.caption)), 230),
								basis: 'IA local de visão + verificação anti-alucinação + contexto editorial'
							} : localComposed;

							if (!result.caption) {
								result.caption = localComposed.caption;
							}
							if (!result.title) {
								result.title = localComposed.title;
							}
							result.alt = ensureFocusKeywordInAlt(result.alt, editorial.focus_keyword || '');
							result = sanitizeEditorialOutputs(result, editorial);
							result.alt = ensureFocusKeywordInAlt(result.alt, editorial.focus_keyword || '');
							result.ai_used = true;
							result.local_ai = true;
							result.visual_description = visualPt;
							result.detected_objects = normalizedDetectorLabels(detections);
							result.model = captionerModel || 'análise visual alternativa';
							result.basis = result.basis || 'IA local gratuita + verificação visual + contexto editorial';

							emitProgress('save', 'Salvando título, alt text e legenda na mídia…', null);
							return saveResult(attachmentId, mode, result);
						});
					});
				});
			});
		}).then(function (result) {
			emitProgress('done', 'Título, alt text e legenda gerados com IA local e salvos.', 100);
			return result;
		}).catch(function (error) {
			var friendly = friendlyGenerationError(error);
			emitProgress('error', friendly, null);
			throw new Error(friendly);
		});
	}

	window.GoVergeLocalAI = {
		generate: generate,
		warmup: function () { return getCaptioner(); },
		getContext: getContext
	};
	window.GoVergeLocalAIReady = Promise.resolve(window.GoVergeLocalAI);
})(window, document, window.wp);
