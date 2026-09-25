(function (blocks, element, components, blockEditor, i18n) {
	'use strict';
	var el = element.createElement;
	var Fragment = element.Fragment;
	var MediaUpload = blockEditor.MediaUpload;
	var MediaUploadCheck = blockEditor.MediaUploadCheck;
	var InspectorControls = blockEditor.InspectorControls;
	var Button = components.Button;
	var PanelBody = components.PanelBody;
	var TextControl = components.TextControl;
	var Placeholder = components.Placeholder;
	var __ = i18n.__;

	function imagePicker(side, attributes, setAttributes) {
		var idKey = side + 'Id';
		var urlKey = side + 'Url';
		var label = side === 'left' ? __('Imagem da esquerda', 'go-verge') : __('Imagem da direita', 'go-verge');
		var url = attributes[urlKey];
		return el('div', { className: 'go-split-image-editor__picker' },
			url ? el('img', { src: url, alt: '' }) : el('span', null, label),
			el(MediaUploadCheck, null,
				el(MediaUpload, {
					onSelect: function (media) {
						var next = {};
						next[idKey] = Number(media.id || 0);
						next[urlKey] = media.sizes && media.sizes.large ? media.sizes.large.url : media.url;
						setAttributes(next);
					},
					allowedTypes: ['image'],
					value: attributes[idKey],
					render: function (obj) {
						return el(Button, { variant: url ? 'secondary' : 'primary', onClick: obj.open }, url ? __('Trocar', 'go-verge') : __('Selecionar', 'go-verge'));
					}
				})
			)
		);
	}

	blocks.registerBlockType('go-verge/split-image', {
		title: __('Imagem meio a meio', 'go-verge'),
		description: __('Compara duas imagens lado a lado no corpo da matéria.', 'go-verge'),
		icon: 'images-alt2',
		category: 'media',
		attributes: {
			leftId: { type: 'number', default: 0 },
			leftUrl: { type: 'string', default: '' },
			rightId: { type: 'number', default: 0 },
			rightUrl: { type: 'string', default: '' },
			leftLabel: { type: 'string', default: '' },
			rightLabel: { type: 'string', default: '' },
			caption: { type: 'string', default: '' }
		},
		supports: { html: false, align: ['wide', 'full'] },
		edit: function (props) {
			var a = props.attributes;
			return el(Fragment, null,
				el(InspectorControls, null,
					el(PanelBody, { title: __('Rótulos e legenda', 'go-verge'), initialOpen: true },
						el(TextControl, { label: __('Rótulo esquerdo', 'go-verge'), value: a.leftLabel, onChange: function (v) { props.setAttributes({ leftLabel: v }); } }),
						el(TextControl, { label: __('Rótulo direito', 'go-verge'), value: a.rightLabel, onChange: function (v) { props.setAttributes({ rightLabel: v }); } }),
						el(TextControl, { label: __('Legenda', 'go-verge'), value: a.caption, onChange: function (v) { props.setAttributes({ caption: v }); } })
					)
				),
				el('div', { className: 'go-split-image-editor' },
					el(Placeholder, { label: __('Imagem meio a meio', 'go-verge'), instructions: __('Escolha duas fotos para a comparação.', 'go-verge') },
						el('div', { className: 'go-split-image-editor__grid' },
							imagePicker('left', a, props.setAttributes),
							imagePicker('right', a, props.setAttributes)
						),
						el('div', { className: 'go-split-image-editor__labels' },
							el(TextControl, { label: __('Rótulo esquerdo', 'go-verge'), value: a.leftLabel, onChange: function (v) { props.setAttributes({ leftLabel: v }); } }),
							el(TextControl, { label: __('Rótulo direito', 'go-verge'), value: a.rightLabel, onChange: function (v) { props.setAttributes({ rightLabel: v }); } })
						),
						el(TextControl, { label: __('Legenda', 'go-verge'), value: a.caption, onChange: function (v) { props.setAttributes({ caption: v }); } })
					)
				)
			);
		},
		save: function () { return null; }
	});
})(window.wp.blocks, window.wp.element, window.wp.components, window.wp.blockEditor, window.wp.i18n);
