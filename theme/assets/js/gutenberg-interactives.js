(function (wp) {
	'use strict';

	if (!wp || !wp.blocks || !wp.element || !wp.components || !wp.blockEditor) {
		return;
	}

	var el = wp.element.createElement;
	var Fragment = wp.element.Fragment;
	var registerBlockType = wp.blocks.registerBlockType;
	var blockEditor = wp.blockEditor;
	var InspectorControls = blockEditor.InspectorControls;
	var useBlockProps = blockEditor.useBlockProps;
	var components = wp.components;
	var PanelBody = components.PanelBody;
	var TextControl = components.TextControl;
	var TextareaControl = components.TextareaControl;
	var SelectControl = components.SelectControl;
	var Notice = components.Notice;
	var Button = components.Button;
	var cfg = window.GoVergeGutenbergInteractives || {};

	function lines(value) {
		return String(value || '').split(/\r?\n/).map(function (item) {
			return item.trim();
		}).filter(Boolean);
	}

	function cardProps(type) {
		return useBlockProps({ className: 'go-gb-interactive go-gb-interactive--' + type });
	}

	function kicker(label, symbol) {
		return el('div', { className: 'go-gb-interactive__kicker' },
			el('span', { 'aria-hidden': 'true' }, symbol),
			el('strong', null, label)
		);
	}

	function optionPreview(items, className) {
		return el('div', { className: 'go-gb-interactive__options ' + (className || '') },
			items.map(function (item, index) {
				return el('div', { className: 'go-gb-interactive__option', key: index },
					el('span', { className: 'go-gb-interactive__option-index', 'aria-hidden': 'true' }, String.fromCharCode(65 + index)),
					el('span', null, item)
				);
			})
		);
	}

	registerBlockType('game-overdrive/enquete', {
		apiVersion: 2,
		title: 'Enquete',
		description: 'Pergunta com votação e resultados em porcentagem.',
		category: 'game-overdrive-interativos',
		icon: 'chart-bar',
		keywords: ['enquete', 'votação', 'interativo'],
		attributes: {
			pergunta: { type: 'string', default: 'Qual é a sua opinião?' },
			opcoes: { type: 'string', default: 'Opção 1\nOpção 2\nOpção 3' }
		},
		supports: { html: false, reusable: true },
		edit: function (props) {
			var attrs = props.attributes;
			var options = lines(attrs.opcoes);
			return el(Fragment, null,
				el(InspectorControls, null,
					el(PanelBody, { title: 'Configuração da enquete', initialOpen: true },
						el(TextControl, { label: 'Pergunta', value: attrs.pergunta, onChange: function (value) { props.setAttributes({ pergunta: value }); } }),
						el(TextareaControl, { label: 'Opções, uma por linha', rows: 6, value: attrs.opcoes, onChange: function (value) { props.setAttributes({ opcoes: value }); }, help: 'Use de 2 a 6 opções para uma leitura melhor.' })
					)
				),
				el('section', cardProps('poll'),
					kicker('Enquete', '◈'),
					el('h3', { className: 'go-gb-interactive__title' }, attrs.pergunta || 'Digite a pergunta da enquete'),
					options.length >= 2 ? optionPreview(options.slice(0, 6)) : el(Notice, { status: 'warning', isDismissible: false }, 'Adicione pelo menos duas opções.'),
					null
				)
			);
		},
		save: function () { return null; }
	});

	registerBlockType('game-overdrive/quiz', {
		apiVersion: 2,
		title: 'Quiz',
		description: 'Pergunta com resposta correta e explicação.',
		category: 'game-overdrive-interativos',
		icon: 'editor-help',
		keywords: ['quiz', 'pergunta', 'resposta'],
		attributes: {
			pergunta: { type: 'string', default: 'Qual é a resposta correta?' },
			opcoes: { type: 'string', default: 'Alternativa A\nAlternativa B\nAlternativa C' },
			correta: { type: 'number', default: 1 },
			explicacao: { type: 'string', default: '' }
		},
		supports: { html: false, reusable: true },
		edit: function (props) {
			var attrs = props.attributes;
			var options = lines(attrs.opcoes);
			var correctChoices = options.map(function (item, index) { return { label: (index + 1) + '. ' + item, value: index + 1 }; });
			return el(Fragment, null,
				el(InspectorControls, null,
					el(PanelBody, { title: 'Configuração do quiz', initialOpen: true },
						el(TextControl, { label: 'Pergunta', value: attrs.pergunta, onChange: function (value) { props.setAttributes({ pergunta: value }); } }),
						el(TextareaControl, { label: 'Alternativas, uma por linha', rows: 6, value: attrs.opcoes, onChange: function (value) { props.setAttributes({ opcoes: value }); } }),
						el(SelectControl, { label: 'Resposta correta', value: String(attrs.correta || 1), options: correctChoices.length ? correctChoices : [{ label: 'Adicione alternativas', value: '1' }], onChange: function (value) { props.setAttributes({ correta: parseInt(value, 10) || 1 }); } }),
						el(TextareaControl, { label: 'Explicação', rows: 4, value: attrs.explicacao, onChange: function (value) { props.setAttributes({ explicacao: value }); }, help: 'Aparece depois que o leitor responde.' })
					)
				),
				el('section', cardProps('quiz'),
					kicker('Quiz', '?'),
					el('h3', { className: 'go-gb-interactive__title' }, attrs.pergunta || 'Digite a pergunta do quiz'),
					optionPreview(options.slice(0, 6), 'is-quiz'),
					attrs.explicacao ? el('p', { className: 'go-gb-interactive__explain' }, attrs.explicacao) : null
				)
			);
		},
		save: function () { return null; }
	});

	registerBlockType('game-overdrive/comparador', {
		apiVersion: 2,
		title: 'Comparador',
		description: 'Tabela editorial para comparar dois produtos, jogos ou versões.',
		category: 'game-overdrive-interativos',
		icon: 'leftright',
		keywords: ['comparação', 'comparador', 'versus', 'vs'],
		attributes: {
			titulo: { type: 'string', default: 'Produto A vs Produto B' },
			a: { type: 'string', default: 'Produto A' },
			b: { type: 'string', default: 'Produto B' },
			linhas: { type: 'string', default: 'Preço | *R$ 2.499 | R$ 2.899\nDesempenho | 60 fps | *120 fps\nBateria | *10h | 7h' },
			veredito: { type: 'string', default: '' }
		},
		supports: { html: false, reusable: true },
		edit: function (props) {
			var attrs = props.attributes;
			var rows = lines(attrs.linhas).map(function (line) { return line.split('|').map(function (part) { return part.trim(); }); }).filter(function (parts) { return parts.length >= 3; });
			return el(Fragment, null,
				el(InspectorControls, null,
					el(PanelBody, { title: 'Configuração do comparador', initialOpen: true },
						el(TextControl, { label: 'Título', value: attrs.titulo, onChange: function (value) { props.setAttributes({ titulo: value }); } }),
						el(TextControl, { label: 'Lado A', value: attrs.a, onChange: function (value) { props.setAttributes({ a: value }); } }),
						el(TextControl, { label: 'Lado B', value: attrs.b, onChange: function (value) { props.setAttributes({ b: value }); } }),
						el(TextareaControl, { label: 'Critérios', rows: 8, value: attrs.linhas, onChange: function (value) { props.setAttributes({ linhas: value }); }, help: 'Uma linha por critério: Nome | Valor A | Valor B. Use * antes do melhor valor.' }),
						el(TextareaControl, { label: 'Veredito', rows: 4, value: attrs.veredito, onChange: function (value) { props.setAttributes({ veredito: value }); } })
					)
				),
				el('section', cardProps('compare'),
					kicker('Comparativo', '⇄'),
					el('h3', { className: 'go-gb-interactive__title' }, attrs.titulo || 'Comparação'),
					el('div', { className: 'go-gb-compare__head' }, el('strong', null, attrs.a || 'A'), el('span', null, 'vs'), el('strong', null, attrs.b || 'B')),
					el('div', { className: 'go-gb-compare__rows' }, rows.slice(0, 8).map(function (parts, index) {
						return el('div', { className: 'go-gb-compare__row', key: index },
							el('span', { className: 'go-gb-compare__label' }, parts[0]),
							el('span', { className: /^\*/.test(parts[1]) ? 'is-win' : '' }, String(parts[1]).replace(/^\*\s*/, '')),
							el('span', { className: /^\*/.test(parts[2]) ? 'is-win' : '' }, String(parts[2]).replace(/^\*\s*/, ''))
						);
					})),
					attrs.veredito ? el('p', { className: 'go-gb-interactive__verdict' }, el('strong', null, 'Veredito GO: '), attrs.veredito) : null
				)
			);
		},
		save: function () { return null; }
	});

	registerBlockType('game-overdrive/previsao', {
		apiVersion: 2,
		title: 'Caixa de previsão',
		description: 'Palpite com prazo e resultado definido depois pela redação.',
		category: 'game-overdrive-interativos',
		icon: 'chart-line',
		keywords: ['previsão', 'palpite', 'votação'],
		attributes: { predictionId: { type: 'number', default: 0 } },
		supports: { html: false, reusable: true },
		edit: function (props) {
			var predictions = Array.isArray(cfg.predictions) ? cfg.predictions : [];
			var selectOptions = [{ label: 'Selecione uma previsão', value: '0' }].concat(predictions.map(function (item) {
				return { label: item.title, value: String(item.id) };
			}));
			var selected = predictions.filter(function (item) { return Number(item.id) === Number(props.attributes.predictionId); })[0];
			return el(Fragment, null,
				el(InspectorControls, null,
					el(PanelBody, { title: 'Configuração da previsão', initialOpen: true },
						el(SelectControl, { label: 'Previsão publicada', value: String(props.attributes.predictionId || 0), options: selectOptions, onChange: function (value) { props.setAttributes({ predictionId: parseInt(value, 10) || 0 }); } }),
						cfg.newPredictionUrl ? el(Button, { variant: 'secondary', href: cfg.newPredictionUrl, target: '_blank' }, 'Criar nova previsão') : null
					)
				),
				el('section', cardProps('prediction'),
					kicker('Caixa de previsão', '◔'),
					selected ? el(Fragment, null,
						el('h3', { className: 'go-gb-interactive__title' }, selected.title),
						selected.context ? el('p', { className: 'go-gb-interactive__context' }, selected.context) : null,
						optionPreview(selected.options || [])
					) : el(Notice, { status: 'info', isDismissible: false }, predictions.length ? 'Escolha uma previsão publicada no painel lateral.' : 'Ainda não há previsões publicadas. Crie uma e volte a este bloco.')
				)
			);
		},
		save: function () { return null; }
	});
})(window.wp);
