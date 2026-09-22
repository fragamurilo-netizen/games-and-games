(function () {
	'use strict';
	var cfg = window.GoVergeEditorialV6 || {};
	if (!window.wp || !wp.data) return;
	if (!cfg.postId) {
		try { var initialEditor = wp.data.select('core/editor'); cfg.postId = initialEditor && initialEditor.getCurrentPostId ? Number(initialEditor.getCurrentPostId()) || 0 : 0; } catch (e) {}
	}
	if (!cfg.postId) return;

	function el(tag, cls, text) {
		var node = document.createElement(tag);
		if (cls) node.className = cls;
		if (typeof text === 'string') node.textContent = text;
		return node;
	}
	function editor() { try { return wp.data.select('core/editor'); } catch (e) { return null; } }
	function editPost(attrs) { try { wp.data.dispatch('core/editor').editPost(attrs); } catch (e) {} }
	function titleValue() { var e = editor(); return e && e.getEditedPostAttribute ? String(e.getEditedPostAttribute('title') || '') : ''; }
	function contentValue() { var e = editor(); return e && e.getEditedPostContent ? String(e.getEditedPostContent() || '') : ''; }
	function metaValue() { var e = editor(); return e && e.getEditedPostAttribute ? (e.getEditedPostAttribute('meta') || {}) : {}; }
	function featureId() { var e = editor(); return e && e.getEditedPostAttribute ? Number(e.getEditedPostAttribute('featured_media') || 0) : 0; }
	function categories() { var e = editor(); return e && e.getEditedPostAttribute ? (e.getEditedPostAttribute('categories') || []) : []; }
	function contentTypes() { var e = editor(); return e && e.getEditedPostAttribute ? (e.getEditedPostAttribute('go_content_type') || []) : []; }

	function ajax(action, data, nonce) {
		var body = new URLSearchParams();
		body.set('action', action); body.set('nonce', nonce || cfg.nonce || '');
		Object.keys(data || {}).forEach(function (key) { body.set(key, data[key] == null ? '' : String(data[key])); });
		return fetch(cfg.ajaxUrl, { method: 'POST', credentials: 'same-origin', headers: {'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'}, body: body.toString() })
			.then(function (r) { return r.json(); }).then(function (payload) { if (!payload || payload.success !== true) throw new Error(payload && payload.data && payload.data.message ? payload.data.message : 'Erro'); return payload.data || {}; });
	}

	function currentCategoryName() {
		var ids = categories();
		if (!ids.length) return 'Sem categoria';
		try {
			var term = wp.data.select('core').getEntityRecord('taxonomy', 'category', ids[0]);
			return term && term.name ? term.name : 'Categoria';
		} catch (e) { return 'Categoria'; }
	}
	function currentGameName() {
		var gameRoot = document.querySelector('[data-go-game-intelligence]');
		var id = gameRoot && gameRoot.querySelector('[data-go-game-id]') ? Number(gameRoot.querySelector('[data-go-game-id]').value || 0) : 0;
		var strong = gameRoot ? gameRoot.querySelector('[data-go-game-status] strong') : null;
		if (id && strong) return strong.textContent.trim();
		return cfg.linkedGame && cfg.linkedGame.title ? cfg.linkedGame.title : (cfg.i18n.noGame || 'Sem game');
	}
	function featuredUrl() {
		var id = featureId(); if (!id) return '';
		try {
			var media = wp.data.select('core').getMedia(id);
			if (media && media.media_details && media.media_details.sizes) {
				var sizes = media.media_details.sizes;
				return (sizes.go_discover_16x9 && sizes.go_discover_16x9.source_url) || (sizes.large && sizes.large.source_url) || media.source_url || '';
			}
			return media && media.source_url ? media.source_url : '';
		} catch (e) { return ''; }
	}

	function buildMatterBar() {
		var dock = document.getElementById('go-editor-commandbar');
		if (!dock || dock.querySelector('[data-go-v6-matterbar]')) return;
		var lower = dock.querySelector('.go-editor-commandbar__lower');
		if (!lower) return;
		var bar = el('div', 'go-v6-matterbar'); bar.dataset.goV6Matterbar = '1';
		var story = el('div', 'go-v6-matterbar__story');
		story.innerHTML = '<span class="go-v6-matterbar__story-label">Matéria</span><strong data-go-v6-title-preview>Título ainda não definido</strong><small><span data-go-v6-author></span><i aria-hidden="true">·</i><span data-go-v6-title-count>0 caracteres</span></small>';

		var meta = el('div', 'go-v6-matterbar__meta');
		meta.innerHTML = '<label class="go-v6-assignment"><span>Editor</span><select data-go-v6-editor><option value="0">Não atribuído</option></select></label>' +
			'<button type="button" class="go-v6-context-chip" data-go-v6-category><span>Categoria</span><strong></strong><small>Editar contexto</small></button>' +
			'<button type="button" class="go-v6-context-chip" data-go-v6-game><span>Game</span><strong></strong><small>Vincular ficha</small></button>' +
			'<button type="button" class="go-v6-cover" data-go-v6-cover><span class="go-v6-cover__media"><img hidden alt=""><i>16:9</i></span><span><small>Capa</small><strong>Selecionar</strong></span></button>';
		bar.appendChild(story); bar.appendChild(meta);
		lower.insertBefore(bar, lower.firstChild);

		bar.querySelector('[data-go-v6-author]').textContent = cfg.author || 'Autor atual';
		var select = bar.querySelector('[data-go-v6-editor]');
		(cfg.editors || []).forEach(function (u) { var o = document.createElement('option'); o.value=String(u.id); o.textContent=u.name; select.appendChild(o); });
		select.value = String(Number(metaValue()._go_editor_id || cfg.editorId || 0));
		select.addEventListener('change', function () { var m=Object.assign({},metaValue()); m._go_editor_id=Number(select.value||0); editPost({meta:m}); });
		bar.querySelector('[data-go-v6-category]').addEventListener('click', function () { document.dispatchEvent(new CustomEvent('go:open-architecture')); });
		bar.querySelector('[data-go-v6-game]').addEventListener('click', function () { var root=document.querySelector('[data-go-game-intelligence]'); if (root) root.scrollIntoView({behavior:'smooth',block:'center'}); var field=root&&root.querySelector('[data-go-game-search]'); if(field) field.focus(); });
		bar.querySelector('[data-go-v6-cover]').addEventListener('click', function () {
			var smart = document.querySelector('.go-editor-commandbar__smart-crop');
			if (featureId() && smart) { smart.click(); return; }
			var btn = document.querySelector('.editor-post-featured-image__toggle, .editor-post-featured-image button, .components-button.editor-post-featured-image__toggle'); if (btn) btn.click();
		});
		syncMatterBar();
	}

	function syncMatterBar() {
		var bar=document.querySelector('[data-go-v6-matterbar]'); if(!bar) return;
		var tv=titleValue(); var preview=bar.querySelector('[data-go-v6-title-preview]');if(preview)preview.textContent=tv||'Título ainda não definido';
		var count=bar.querySelector('[data-go-v6-title-count]'); if(count){count.textContent=tv.length+' caracteres'; count.classList.toggle('is-over',tv.length>75);}
		var c=bar.querySelector('[data-go-v6-category] strong'); if(c)c.textContent=currentCategoryName();
		var g=bar.querySelector('[data-go-v6-game] strong'); if(g)g.textContent=currentGameName();
		var url=featuredUrl(), img=bar.querySelector('[data-go-v6-cover] img'), label=bar.querySelector('[data-go-v6-cover] strong');
		if(img){if(url){img.src=url;img.hidden=false;if(label)label.textContent='Capa pronta';}else{img.hidden=true;img.removeAttribute('src');if(label)label.textContent='Selecionar';}}
	}

	function exec(cmd, value) {
		var active=document.activeElement;
		if (!active || !active.closest || !active.closest('[contenteditable="true"]')) return;
		document.execCommand(cmd, false, value || null);
		active.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'format'+cmd}));
	}
	function wrapSelection(tag) {
		var sel=window.getSelection(); if(!sel||!sel.rangeCount||sel.isCollapsed)return;
		var text=sel.toString(); document.execCommand('insertHTML',false,'<'+tag+'>'+text.replace(/</g,'&lt;').replace(/>/g,'&gt;')+'</'+tag+'>');
	}
	function transformBlock(kind) {
		try {
			var store=wp.data.select('core/block-editor'), dispatch=wp.data.dispatch('core/block-editor'), id=store.getSelectedBlockClientId(), block=store.getBlock(id); if(!id||!block)return;
			var content=block.attributes.content || block.attributes.value || '';
			if(kind==='h2'||kind==='h3') dispatch.replaceBlock(id,wp.blocks.createBlock('core/heading',{content:content,level:kind==='h2'?2:3}));
			else if(kind==='p') dispatch.replaceBlock(id,wp.blocks.createBlock('core/paragraph',{content:content}));
			else if(kind==='ul'||kind==='ol'){
				var parts=String(content||'').split(/<br\s*\/?\s*>|\n/gi).map(function(item){return item.trim();}).filter(Boolean);
				if(!parts.length)parts=[''];
				var items=parts.map(function(item){return wp.blocks.createBlock('core/list-item',{content:item});});
				dispatch.replaceBlock(id,wp.blocks.createBlock('core/list',{ordered:kind==='ol'},items));
			}
		} catch(e) {}
	}
	function buildFormatBar() {
		var dock=document.getElementById('go-editor-commandbar'); if(!dock||dock.querySelector('[data-go-v6-formatbar]'))return;
		var lower=dock.querySelector('.go-editor-commandbar__lower'); if(!lower)return;
		var wrap=el('details','go-v6-formatbar-wrap');wrap.dataset.goV6Formatbar='1';
		var summary=el('summary','go-v6-formatbar__summary');summary.innerHTML='<span>Ferramentas de texto</span><small>Opcional</small><i aria-hidden="true">⌄</i>';wrap.appendChild(summary);
		var bar=el('div','go-v6-formatbar');wrap.appendChild(bar);
		var actions=[
			['N','Negrito',function(){exec('bold');}],['I','Itálico',function(){exec('italic');}],['S','Sublinhar',function(){exec('underline');}],['T','Tachado',function(){exec('strikeThrough');}],
			['A','Marca-texto lima',function(){exec('hiliteColor','#d8ff38');}],['Link','Inserir link',function(){var u=window.prompt('URL');if(u)exec('createLink',u);}],['Unlink','Remover link',function(){exec('unlink');}],
			['•','Lista',function(){transformBlock('ul');}],['1.','Lista numerada',function(){transformBlock('ol');}],['H2','H2',function(){transformBlock('h2');}],['H3','H3',function(){transformBlock('h3');}],['P','Parágrafo',function(){transformBlock('p');}],
			['kbd','Tecla',function(){wrapSelection('kbd');}],['x²','Sobrescrito',function(){exec('superscript');}],['x₂','Subscrito',function(){exec('subscript');}],['Limpar','Limpar formatação',function(){exec('removeFormat');}]
		];
		actions.forEach(function(a){var b=el('button','go-v6-formatbar__btn',a[0]);b.type='button';b.title=a[1];b.addEventListener('mousedown',function(ev){ev.preventDefault();});b.addEventListener('click',a[2]);bar.appendChild(b);});
		lower.appendChild(wrap);
	}

	function addShortcuts() {
		var dock=document.getElementById('go-editor-commandbar'); if(!dock||dock.querySelector('[data-go-v6-shortcuts]'))return;
		var top=dock.querySelector('.go-editor-commandbar__actions'); if(!top)return;
		var wrap=el('div','go-v6-shortcuts');wrap.dataset.goV6Shortcuts='1';
		function openStage(label,stage){var b=el('button','go-v6-shortcut',label);b.type='button';b.addEventListener('click',function(){var open=document.querySelector('.go-editor-commandbar__open');if(open)open.click();setTimeout(function(){var tab=document.querySelector('[data-go-stage-tab="'+stage+'"]');if(tab)tab.click();if(label==='Review'){var field=document.querySelector('#go-review-score,input[name="nota"]');if(field)field.focus();}},120);});wrap.appendChild(b);}
		function insertBlocks(blocks){try{var d=wp.data.dispatch('core/block-editor');if(d&&d.insertBlocks)d.insertBlocks(blocks);}catch(e){}}
		openStage('Review','evaluation');openStage('Prós/Contras','evaluation');openStage('Spoiler','interaction');openStage('Leia também','content');
		var quote=el('button','go-v6-shortcut','Citação');quote.type='button';quote.addEventListener('click',function(){try{var inner=wp.blocks.createBlock('core/paragraph',{content:'Citação'});insertBlocks([wp.blocks.createBlock('core/quote',{citation:'Crédito'},[inner])]);}catch(e){insertBlocks([wp.blocks.createBlock('core/paragraph',{content:'Citação'})]);}});wrap.appendChild(quote);
		var box=el('button','go-v6-shortcut','Box destaque');box.type='button';box.addEventListener('click',function(){try{var store=wp.data.select('core/block-editor'),d=wp.data.dispatch('core/block-editor'),id=store.getSelectedBlockClientId(),block=store.getBlock(id),content=block&&block.attributes?(block.attributes.content||''):'';if(id&&content){d.replaceBlock(id,wp.blocks.createBlock('core/paragraph',{content:content,className:'go-pullquote-box'}));}else{insertBlocks([wp.blocks.createBlock('core/paragraph',{placeholder:'Frase de destaque',className:'go-pullquote-box'})]);}}catch(e){}});wrap.appendChild(box);
		var table=el('button','go-v6-shortcut','Tabela');table.type='button';table.addEventListener('click',function(){insertBlocks([wp.blocks.createBlock('core/table')]);});wrap.appendChild(table);
		var faq=el('button','go-v6-shortcut','FAQ + schema');faq.type='button';faq.addEventListener('click',function(){insertBlocks([wp.blocks.createBlock('core/heading',{content:'Perguntas frequentes',level:2}),wp.blocks.createBlock('core/heading',{content:'Pergunta',level:3}),wp.blocks.createBlock('core/paragraph',{content:'Resposta'})]);});wrap.appendChild(faq);
		var embed=el('button','go-v6-shortcut','Embed');embed.type='button';embed.addEventListener('click',function(){var url=window.prompt('Cole a URL do YouTube, TikTok ou X:','');if(url)insertBlocks([wp.blocks.createBlock('core/embed',{url:url})]);});wrap.appendChild(embed);
		var crop=el('button','go-v6-shortcut','Print 16:9');crop.type='button';crop.addEventListener('click',function(){var all=document.querySelector('[data-go-smart-crop-all],.go-editor-commandbar__smart-crop');if(all)all.click();});wrap.appendChild(crop);
		var update=el('button','go-v6-shortcut go-v6-shortcut--update','Atualizar matéria');update.type='button';update.addEventListener('click',function(){var note=window.prompt('Nota de correção/atualização (opcional). Deixe vazio para apenas atualizar o horário.','');ajax('go_verge_editorial_v6_update_article',{post_id:cfg.postId,note:note||''}).then(function(d){update.textContent='Atualizada · '+(d.time||'agora');setTimeout(function(){update.textContent='Atualizar matéria';},3500);}).catch(function(e){window.alert(e.message);});});wrap.appendChild(update);
		var desk=el('a','go-v6-shortcut','Mesa do autor');desk.href=cfg.authorDesk||'#';wrap.appendChild(desk);
		top.insertBefore(wrap,top.firstChild);
	}

	function addTagSuggestions() {
		var root=document.querySelector('[data-go-native-tags-preview]'); if(!root||root.querySelector('[data-go-v6-tag-suggest]'))return;
		var button=el('button','button button-small','Sugerir tags do texto');button.type='button';button.dataset.goV6TagSuggest='1';
		var results=el('div','go-v6-tag-suggestions');
		button.addEventListener('click',function(){button.disabled=true;button.textContent='Analisando…';ajax('go_verge_editorial_v6_tags',{post_id:cfg.postId,title:titleValue(),content:contentValue()}).then(function(data){results.innerHTML='';(data.items||[]).forEach(function(item){var chip=el('button','go-v6-tag-suggestion','+ '+item.name);chip.type='button';chip.addEventListener('click',function(){try{var e=editor(),ids=(e.getEditedPostAttribute('tags')||[]).map(Number);if(ids.indexOf(Number(item.id))===-1){if(ids.length>=5){window.alert('Use de 3 a 5 tags por matéria. Remova uma antes de adicionar outra.');return;}ids.push(Number(item.id));editPost({tags:ids});}chip.classList.add('is-added');chip.textContent='✓ '+item.name;}catch(err){}});results.appendChild(chip);});if(!(data.items||[]).length)results.textContent='Nenhuma tag existente bateu com o texto.';}).catch(function(e){results.textContent=e.message;}).finally(function(){button.disabled=false;button.textContent='Sugerir tags do texto';});});
		root.appendChild(button);root.appendChild(results);
	}

	function addGameCreator() {
		var root=document.querySelector('[data-go-game-intelligence]'); if(!root||root.querySelector('[data-go-v6-create-game]'))return;
		var box=el('div','go-v6-create-game');box.dataset.goV6CreateGame='1';box.innerHTML='<button type="button" class="button" data-go-v6-create-game-toggle>+ Criar ficha mínima aqui</button><div data-go-v6-create-game-form hidden><label>Nome<input type="text" class="widefat" data-go-v6-game-name></label><label>Lançamento<input type="date" class="widefat" data-go-v6-game-release></label><div class="go-v6-create-game__cover"><button type="button" class="button" data-go-v6-game-cover>Escolher capa</button><span data-go-v6-game-cover-name>Sem capa</span><input type="hidden" data-go-v6-game-cover-id value="0"></div><button type="button" class="button button-primary" data-go-v6-create-game-save>Criar e vincular</button><small data-go-v6-create-game-msg></small></div>';
		var results=root.querySelector('[data-go-game-results]'); if(results)results.insertAdjacentElement('afterend',box);else root.appendChild(box);
		var form=box.querySelector('[data-go-v6-create-game-form]');box.querySelector('[data-go-v6-create-game-toggle]').addEventListener('click',function(){form.hidden=!form.hidden;if(!form.hidden){var q=root.querySelector('[data-go-game-search]');box.querySelector('[data-go-v6-game-name]').value=q?q.value:'';box.querySelector('[data-go-v6-game-name]').focus();}});
		box.querySelector('[data-go-v6-game-cover]').addEventListener('click',function(){if(!window.wp||!wp.media)return;var frame=wp.media({title:'Capa do game',button:{text:'Usar como capa'},library:{type:'image'},multiple:false});frame.on('select',function(){var a=frame.state().get('selection').first().toJSON();box.querySelector('[data-go-v6-game-cover-id]').value=String(a.id||0);box.querySelector('[data-go-v6-game-cover-name]').textContent=a.filename||a.title||'Capa selecionada';});frame.open();});
		box.querySelector('[data-go-v6-create-game-save]').addEventListener('click',function(){var name=box.querySelector('[data-go-v6-game-name]').value.trim(),release=box.querySelector('[data-go-v6-game-release]').value,cover=Number(box.querySelector('[data-go-v6-game-cover-id]').value||0),msg=box.querySelector('[data-go-v6-create-game-msg]');if(!name){msg.textContent='Informe o nome.';return;}this.disabled=true;ajax('go_verge_editorial_v6_create_game',{post_id:cfg.postId,name:name,release:release,cover_id:cover},cfg.gameNonce).then(function(data){msg.textContent='Ficha criada e vinculada.';var idInput=root.querySelector('[data-go-game-id]'),status=root.querySelector('[data-go-game-status]');if(idInput)idInput.value=String(data.game.id);if(status)status.innerHTML='<strong>'+data.game.title+'</strong><span>Vinculado manualmente.</span>';cfg.linkedGame=data.game;syncMatterBar();form.hidden=true;}).catch(function(e){msg.textContent=e.message;}).finally(function(){box.querySelector('[data-go-v6-create-game-save]').disabled=false;});});
	}

	function hasInternalLink(html) {
		var host=cfg.homeHost||'';var div=document.createElement('div');div.innerHTML=html;return Array.prototype.some.call(div.querySelectorAll('a[href]'),function(a){try{var u=new URL(a.getAttribute('href'),cfg.homeUrl||location.origin);return u.host===host;}catch(e){return false;}});
	}
	function syncReviewScore(){
		var field=document.querySelector('#go-review-score');if(!field)return;
		var apply=function(){var raw=String(field.value||'').replace(',','.').trim(),m=Object.assign({},metaValue());m.nota=raw;editPost({meta:m});liveGate();};
		if(!field.dataset.goV6ScoreSync){field.dataset.goV6ScoreSync='1';field.addEventListener('input',apply);field.addEventListener('change',apply);}
	}

	function essentialWarnings() {
		var meta=metaValue(),content=contentValue(),errors=[];
		if(!String(meta._go_post_subtitle||'').trim())errors.push('linha de apoio');
		var fid=featureId();
		if(!fid)errors.push('capa');
		else{try{var media=wp.data.select('core').getMedia(fid),alt=media?String(media.alt_text||'').trim():'';if(media&&!alt)errors.push('alt da capa');}catch(e){}}
		if(!/<h2\b/i.test(content) && content.indexOf('"level":2')===-1)errors.push('H2');
		if(!hasInternalLink(content))errors.push('link interno');
		var reviewIds=(cfg.reviewContentTypeIds||[]).map(Number),typeIds=contentTypes().map(Number),isReview=typeIds.some(function(id){return reviewIds.indexOf(Number(id))!==-1;});
		try{var core=wp.data.select('core');isReview=isReview||typeIds.some(function(id){var t=core.getEntityRecord('taxonomy','go_content_type',id);return t&&t.slug==='review';});}catch(e){}
		if(isReview&&!String(meta.nota||'').trim())errors.push('nota da review');
		return errors;
	}
	function allPublishWarnings(){
		var errors=essentialWarnings().slice();
		(window.GoVergeEditorialArchitectureWarnings||[]).forEach(function(item){if(errors.indexOf(item)===-1)errors.push(item);});
		return errors;
	}
	function liveGate() {
		var dock=document.getElementById('go-editor-commandbar');if(!dock)return;
		var gate=dock.querySelector('[data-go-v6-gate]');if(!gate){gate=el('div','go-v6-gate');gate.dataset.goV6Gate='1';dock.querySelector('.go-editor-commandbar__signals').appendChild(gate);}
		var errors=essentialWarnings();
		gate.classList.toggle('is-ok',errors.length===0);gate.classList.toggle('has-warnings',errors.length>0);gate.textContent=errors.length?'Revisar antes de publicar: '+errors.join(' · ')+' — publicação liberada.':'Checklist essencial OK';
		var publish=document.querySelector('.editor-post-publish-button');if(publish){publish.title='';publish.classList.remove('go-v6-publish-has-errors');publish.classList.toggle('go-v6-publish-has-warnings',errors.length>0);}
		if(!allPublishWarnings().length)clearPublishWarningNotices();
	}

	/*
	 * Two advisory signals, zero publication vetoes:
	 * 1) opening the native pre-publish sidebar raises a prominent warning;
	 * 2) clicking the final Publish button raises a second snackbar.
	 * Neither path calls preventDefault(), stopPropagation() or lockPostSaving().
	 */
	var publishSignalState={sidebarOpen:false,firstShown:false,lastSecondAt:0};
	function publishWarningMessage(stage,errors){
		var prefix=stage===1?(cfg.i18n&&cfg.i18n.publishWarning1||'Aviso 1 de 2: há pendências editoriais. Você ainda pode publicar.'):(cfg.i18n&&cfg.i18n.publishWarning2||'Aviso 2 de 2: ainda há pendências. A publicação não será bloqueada.');
		return prefix+' Falta revisar: '+errors.join(' · ')+'.';
	}
	function createPublishWarning(stage,errors){
		if(!errors.length||!wp.data)return;
		try{
			var notices=wp.data.dispatch('core/notices');if(!notices)return;
			var message=publishWarningMessage(stage,errors);
			if(stage===1&&notices.createWarningNotice){
				notices.createWarningNotice(message,{id:'go-editorial-publish-warning-1',isDismissible:true,type:'default'});
			}else if(notices.createWarningNotice){
				notices.createWarningNotice(message,{id:'go-editorial-publish-warning-2',isDismissible:true,type:'snackbar'});
			}else if(notices.createNotice){
				notices.createNotice('warning',message,{id:'go-editorial-publish-warning-'+stage,isDismissible:true,type:stage===1?'default':'snackbar'});
			}
		}catch(e){}
	}
	function clearPublishWarningNotices(){
		try{var notices=wp.data.dispatch('core/notices');if(notices&&notices.removeNotice){notices.removeNotice('go-editorial-publish-warning-1');notices.removeNotice('go-editorial-publish-warning-2');}}catch(e){}
	}
	function watchPublishSidebar(){
		try{
			var e=editor();if(!e||!e.isPublishSidebarOpened)return;
			var open=!!e.isPublishSidebarOpened();
			if(open&&!publishSignalState.sidebarOpen){
				publishSignalState.firstShown=false;
				var errors=allPublishWarnings();
				if(errors.length){createPublishWarning(1,errors);publishSignalState.firstShown=true;}
			}
			if(!open&&publishSignalState.sidebarOpen){publishSignalState.firstShown=false;}
			publishSignalState.sidebarOpen=open;
		}catch(e){}
	}
	document.addEventListener('click',function(event){
		var button=event.target&&event.target.closest?event.target.closest('.editor-post-publish-button, .editor-post-publish-button__button'):null;
		if(!button)return;
		var errors=allPublishWarnings();if(!errors.length)return;
		var now=Date.now();if(now-publishSignalState.lastSecondAt<700)return;publishSignalState.lastSecondAt=now;
		/* If the site skips the pre-publish sidebar, still show both signals without stopping the click. */
		if(!publishSignalState.firstShown){createPublishWarning(1,errors);publishSignalState.firstShown=true;}
		createPublishWarning(2,errors);
	},true);


	var nativeFormatsRegistered=false;
	function registerNativeFormats(){
		/*
		 * RichTextToolbarButton is not a stable public surface across Gutenberg
		 * releases. Registering a format whose edit component is undefined makes
		 * the selected core/paragraph hit Gutenberg's error boundary, which in
		 * turn prevents typing and makes the native block toolbar look broken.
		 * Keep these optional formats progressive: if the compatible toolbar
		 * component is unavailable, native blocks must keep working untouched.
		 */
		if(nativeFormatsRegistered||!window.wp||!wp.richText||!wp.blockEditor||!wp.element)return;
		var register=wp.richText.registerFormatType;
		var toggle=wp.richText.toggleFormat;
		var isActive=wp.richText.isFormatActive;
		var ToolbarButton=wp.blockEditor.RichTextToolbarButton||(wp.editor&&wp.editor.RichTextToolbarButton);
		var h=wp.element.createElement;
		if(typeof register!=='function'||typeof toggle!=='function'||typeof isActive!=='function'||typeof ToolbarButton!=='function')return;

		var formats=[
			['go-verge/underline','go-v6-underline','span','Sublinhar','S'],
			['go-verge/highlight','go-v6-highlight','span','Marca-texto lima','A'],
			['go-verge/kbd','go-v6-kbd','kbd','Tecla (kbd)','kbd'],
			['go-verge/sup','go-v6-sup','sup','Sobrescrito','x²'],
			['go-verge/sub','go-v6-sub','sub','Subscrito','x₂']
		];
		var registeredAny=false;
		formats.forEach(function(f){
			try{
				register(f[0],{
					title:f[3],
					tagName:f[2],
					className:f[1],
					edit:function(props){
						try{
							return h(ToolbarButton,{
								icon:h('span',{className:'go-v6-rich-icon'},f[4]),
								title:f[3],
								isActive:isActive(props.value,f[0]),
								onClick:function(){props.onChange(toggle(props.value,{type:f[0]}));}
							});
						}catch(e){return null;}
					}
				});
				registeredAny=true;
			}catch(e){}
		});
		nativeFormatsRegistered=registeredAny;
	}

	function init() { registerNativeFormats(); buildMatterBar();addShortcuts();addTagSuggestions();addGameCreator();syncReviewScore();syncMatterBar();liveGate();watchPublishSidebar(); }
	document.addEventListener('go:editorial-commandbar-ready',init);
	// Gutenberg mutates the editor tree continuously. Re-running the full
	// integration from a body-wide MutationObserver created an editor feedback
	// loop and could leave post-new.php apparently loading forever.
	setTimeout(init,350);setTimeout(init,1200);setTimeout(init,2600);
	var last='';setInterval(function(){var sig=titleValue()+'|'+featureId()+'|'+categories().join(',')+'|'+contentTypes().join(',')+'|'+String(metaValue()._go_post_subtitle||'')+'|'+contentValue().length;if(sig!==last){last=sig;syncMatterBar();liveGate();}watchPublishSidebar();},600);
})();
