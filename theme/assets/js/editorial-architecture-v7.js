(function () {
	'use strict';
	var cfg = window.GoVergeEditorialV7 || {};
	if (!window.wp || !wp.data) return;
	if (!cfg.postId) {
		try { var initialEditor = wp.data.select('core/editor'); cfg.postId = initialEditor && initialEditor.getCurrentPostId ? Number(initialEditor.getCurrentPostId()) || 0 : 0; } catch (e) {}
	}
	if (!cfg.postId) return;

	var TAX = cfg.taxonomies || {};
	/* Categories come from WordPress on every editor load. Never freeze desks in JS. */
	var categoryOptions = Array.isArray(cfg.categoryOptions) ? cfg.categoryOptions.slice() : [];
	var technicalCategorySlugs = Array.isArray(cfg.technicalCategorySlugs) && cfg.technicalCategorySlugs.length
		? cfg.technicalCategorySlugs.map(String)
		: ['interno','sem-categoria','uncategorized','tudo'];
	var canonicalContentTypes = Array.isArray(cfg.contentTypeSlugs) && cfg.contentTypeSlugs.length
		? cfg.contentTypeSlugs.map(String)
		: ['noticia','guia','review','critica','lista','especial','final-explicado','impressoes','oferta','guia-de-compra','ranking'];

	function el(tag, cls, text) { var n=document.createElement(tag); if(cls)n.className=cls; if(typeof text==='string')n.textContent=text; return n; }
	function editor(){try{return wp.data.select('core/editor');}catch(e){return null;}}
	function editPost(attrs){try{wp.data.dispatch('core/editor').editPost(attrs);}catch(e){}}
	function attr(name){var e=editor();return e&&e.getEditedPostAttribute?(e.getEditedPostAttribute(name)||[]):[];}
	function meta(){var e=editor();return e&&e.getEditedPostAttribute?(e.getEditedPostAttribute('meta')||{}):{};}
	function setMeta(key,value){var m=Object.assign({},meta());m[key]=value;editPost({meta:m});}
	function ajax(action,data){var body=new URLSearchParams();body.set('action',action);body.set('nonce',cfg.nonce||'');Object.keys(data||{}).forEach(function(k){body.set(k,data[k]==null?'':String(data[k]));});return fetch(cfg.ajaxUrl,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},body:body.toString()}).then(function(r){return r.json();}).then(function(p){if(!p||p.success!==true)throw new Error(p&&p.data&&p.data.message?p.data.message:'Erro');return p.data||{};});}
	function terms(tax){try{return wp.data.select('core').getEntityRecords('taxonomy',tax,{per_page:100,hide_empty:false,orderby:'name',order:'asc'})||[];}catch(e){return [];}}
	function selected(tax){return (attr(tax)||[]).map(Number).filter(Boolean);}
	function setTax(tax,ids){var o={};o[tax]=ids.map(Number).filter(Boolean);editPost(o);}
	function termById(tax,id){try{return wp.data.select('core').getEntityRecord('taxonomy',tax,Number(id));}catch(e){return null;}}
	function termSlug(tax,id){var t=termById(tax,id);return t&&t.slug?String(t.slug):'';}
	function escapeHtml(value){return String(value||'').replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}

	function fieldShell(label, help, required) {
		var field=el('div','go-arch-field');
		var head=el('div','go-arch-field__head');
		var labelNode=el('span','go-arch-field__label',label);
		if(required){var req=el('i','go-arch-field__required','•');req.setAttribute('aria-label','Obrigatório');labelNode.appendChild(req);}
		head.appendChild(labelNode);
		if(help){var hint=el('small','go-arch-field__hint',help);head.appendChild(hint);}
		field.appendChild(head);
		return field;
	}

	function makeSelect(tax,label,help,filterFn) {
		var field=fieldShell(label,help,label==='Tipo de matéria');
		var select=el('select','go-arch-select');
		var empty=el('option','','Selecione…');empty.value='0';select.appendChild(empty);field.appendChild(select);
		function sync(){
			var list=terms(tax);if(filterFn)list=list.filter(filterFn);var ids=selected(tax),sig=list.map(function(t){return t.id+':'+t.name;}).join('|');
			if(select.dataset.sig!==sig){while(select.options.length>1)select.remove(1);list.forEach(function(t){var o=el('option','',t.name);o.value=String(t.id);select.appendChild(o);});select.dataset.sig=sig;}
			select.value=ids.length?String(ids[0]):'0';
		}
		select.addEventListener('change',function(){var id=Number(select.value||0);setTax(tax,id?[id]:[]);window.dispatchEvent(new CustomEvent('go:v10-tax-change'));});
		return {field:field,select:select,sync:sync};
	}

	function hierarchyControl() {
		var data=cfg.editorialStructure, rows=data.categories||[], field=el('div','go-arch-hierarchy');
		var deskField=fieldShell('1. Editoria','Área principal da matéria',true), desk=el('select','go-arch-select');desk.setAttribute('aria-label','Editoria');deskField.appendChild(desk);field.appendChild(deskField);
		var subField=fieldShell('2. Subeditoria','Assunto dentro da editoria',false), sub=el('select','go-arch-select');sub.setAttribute('aria-label','Subeditoria');subField.appendChild(sub);field.appendChild(subField);
		var info=el('p','go-arch-field__hint');info.setAttribute('role','status');field.appendChild(info);
		var details=el('details'),summary=el('summary','','Categorias vinculadas'),list=el('ul');details.appendChild(summary);details.appendChild(list);field.appendChild(details);
		var empty=el('option','','Selecione a editoria…');empty.value='';desk.appendChild(empty);
		data.desks.forEach(function(item){var option=el('option','',item.name);option.value=item.slug;option.disabled=!item.id;desk.appendChild(option);});
		function choose(id,key){var row=rows.find(function(item){return Number(item.id)===Number(id);});if(!row||row.desk!==key||['desk','subject'].indexOf(row.role)===-1)return;
			var ids=(attr('categories')||[]).map(Number);if(ids.indexOf(Number(id))===-1)ids.push(Number(id));editPost({categories:ids,meta:Object.assign({},meta(),{_go_primary_category_id:Number(id)})});window.dispatchEvent(new CustomEvent('go:v10-tax-change'));}
		desk.addEventListener('change',function(){var item=data.desks.find(function(item){return item.slug===desk.value;});if(item)choose(item.id,item.slug);});
		sub.addEventListener('change',function(){var root=data.desks.find(function(item){return item.slug===desk.value;});choose(Number(sub.value)||(root&&root.id),desk.value);});
		function sync(){var ids=(attr('categories')||[]).map(Number),primary=Number(meta()._go_primary_category_id||0),current=rows.find(function(item){return Number(item.id)===primary&&ids.indexOf(primary)!==-1;});var key=current?current.desk:'';desk.value=key;sub.disabled=!key;sub.innerHTML='';var general=el('option','',key?'Geral da editoria':'Escolha a editoria primeiro');general.value='0';sub.appendChild(general);
			rows.filter(function(item){return item.desk===key&&item.role==='subject';}).forEach(function(item){var option=el('option','',item.path);option.value=String(item.id);sub.appendChild(option);});sub.value=current&&current.role==='subject'?String(current.id):'0';
			info.textContent=current&&['desk','subject'].indexOf(current.role)===-1?'Principal antiga: '+current.path+'. Revise quando necessário; os vínculos serão mantidos.':'Trocar a principal mantém as demais categorias. Tipo de matéria, plataformas e serviços são campos separados.';
			list.innerHTML='';ids.forEach(function(id){var item=rows.find(function(item){return Number(item.id)===id;});list.appendChild(el('li','',(item?item.path:'Categoria #'+id)+(id===primary?' · principal':'')+(item&&['desk','subject'].indexOf(item.role)===-1?' · legado':'')));});summary.textContent='Categorias vinculadas ('+ids.length+')';}
		return {field:field,select:desk,sync:sync};
	}

	function categoryControl() {
		if(cfg.editorialStructure&&cfg.editorialStructure.version===1)return hierarchyControl();
		var field=fieldShell('Categoria principal','Sobre o que é a matéria',true);var select=el('select','go-arch-select');field.appendChild(select);var empty=el('option','','Selecione…');empty.value='0';select.appendChild(empty);
		function availableOptions(){
			if(categoryOptions.length){
				return categoryOptions.filter(function(item){return item&&Number(item.id)&&technicalCategorySlugs.indexOf(String(item.slug||''))===-1;});
			}
			return terms('category').filter(function(t){return technicalCategorySlugs.indexOf(String(t.slug||''))===-1;}).map(function(t){return {id:Number(t.id),slug:String(t.slug||''),name:String(t.name||''),label:String(t.name||'')};});
		}
		function sync(){
			var list=availableOptions();var sig=list.map(function(t){return t.id+':'+t.slug+':'+(t.label||t.name||'');}).join('|');
			if(select.dataset.sig!==sig){while(select.options.length>1)select.remove(1);list.forEach(function(t){var o=el('option','',String(t.label||t.name||t.slug||('Categoria #'+t.id)));o.value=String(t.id);select.appendChild(o);});select.dataset.sig=sig;}
			var ids=realCategoryIds();select.value=ids.length===1?String(ids[0]):'0';
			var chip=document.querySelector('[data-go-v6-category] strong');if(chip){var selectedId=ids.length===1?ids[0]:0;var term=selectedId?termById('category',selectedId):null;var configured=selectedId?list.find(function(item){return Number(item.id)===Number(selectedId);}):null;chip.textContent=term&&term.name?term.name:(configured&&configured.name?configured.name:'Sem categoria');}
		}
		select.addEventListener('change',function(){var id=Number(select.value||0),m=Object.assign({},meta(),{_go_primary_category_id:id});editPost({categories:id?Array.from(new Set((attr('categories')||[]).map(Number).concat([id]))):(attr('categories')||[]),meta:m});window.dispatchEvent(new CustomEvent('go:v10-tax-change'));});
		return {field:field,select:select,sync:sync};
	}

	function multiPicker(tax,label,help){
		var field=fieldShell(label,help,false), wrap=el('div','go-arch-picker'), button=el('button','go-arch-picker__button');
		button.type='button';button.setAttribute('aria-expanded','false');
		var text=el('span','go-arch-picker__value','Nenhum');var chevron=el('span','go-arch-picker__chevron','⌄');button.appendChild(text);button.appendChild(chevron);
		var pop=el('div','go-arch-picker__popover');pop.hidden=true;wrap.appendChild(button);wrap.appendChild(pop);field.appendChild(wrap);
		function render(){
			var list=terms(tax), ids=selected(tax), sig=list.map(function(t){return t.id+':'+t.name;}).join('|');
			if(pop.dataset.sig!==sig){pop.innerHTML='';list.forEach(function(t){var row=el('label','go-arch-picker__option');var input=el('input');input.type='checkbox';input.value=String(t.id);var name=el('span','',t.name);row.appendChild(input);row.appendChild(name);pop.appendChild(row);input.addEventListener('change',function(){var next=Array.prototype.filter.call(pop.querySelectorAll('input:checked'),function(i){return i.checked;}).map(function(i){return Number(i.value);});setTax(tax,next);render();window.dispatchEvent(new CustomEvent('go:v10-tax-change'));});});pop.dataset.sig=sig;}
			Array.prototype.forEach.call(pop.querySelectorAll('input'),function(i){i.checked=ids.indexOf(Number(i.value))!==-1;});
			var names=ids.map(function(id){var t=termById(tax,id);return t?t.name:'';}).filter(Boolean);
			text.textContent=names.length===0?'Nenhum':(names.length<=2?names.join(', '):(names.slice(0,2).join(', ')+' +'+(names.length-2)));
			button.classList.toggle('has-value',names.length>0);
		}
		button.addEventListener('click',function(e){e.stopPropagation();var open=pop.hidden;document.querySelectorAll('.go-arch-picker__popover').forEach(function(p){p.hidden=true;var b=p.parentNode&&p.parentNode.querySelector('.go-arch-picker__button');if(b)b.setAttribute('aria-expanded','false');});pop.hidden=!open;button.setAttribute('aria-expanded',open?'true':'false');});
		document.addEventListener('click',function(e){if(!wrap.contains(e.target)){pop.hidden=true;button.setAttribute('aria-expanded','false');}});
		return {field:field,sync:render};
	}

	function entitySearch(kind,label,metaKey,multiple,help) {
		var field=fieldShell(label,help,false), selectedWrap=el('div','go-arch-chips'), box=el('div','go-arch-combobox'), input=el('input','go-arch-search');
		input.type='search';input.autocomplete='off';input.placeholder=kind==='production'?'Buscar produção…':'Buscar personagem, franquia, estúdio…';var results=el('div','go-arch-results');results.hidden=true;
		box.appendChild(input);box.appendChild(results);field.appendChild(selectedWrap);field.appendChild(box);
		var timer=0,names={};if(kind==='production'&&cfg.production&&cfg.production.id)names[Number(cfg.production.id)]=cfg.production.title;(cfg.entities||[]).forEach(function(x){names[Number(x.id)]=x.title;});
		function ids(){if(kind==='production')return Number(meta()[metaKey]||cfg.productionId||0)?[Number(meta()[metaKey]||cfg.productionId||0)]:[];return (meta()[metaKey]||cfg.entityIds||[]).map(Number).filter(Boolean);}
		function save(next){if(!multiple)next=next.slice(-1);if(multiple)next=next.slice(0,5);setMeta(metaKey,multiple?next:(next[0]||0));}
		function renderSelected(){selectedWrap.innerHTML='';ids().forEach(function(id){var chip=el('span','go-arch-chip');chip.appendChild(el('span','',names[id]||((kind==='production'?'Produção':'Entidade')+' #'+id)));var x=el('button','','×');x.type='button';x.title='Remover';x.addEventListener('click',function(){save(ids().filter(function(v){return v!==id;}));renderSelected();runGate();});chip.appendChild(x);selectedWrap.appendChild(chip);});}
		function choose(item){names[Number(item.id)]=item.title;var next=ids();if(next.indexOf(Number(item.id))===-1)next.push(Number(item.id));save(next);input.value='';results.hidden=true;renderSelected();runGate();}
		function search(q){ajax('go_verge_v7_search',{kind:kind,q:q}).then(function(d){results.innerHTML='';(d.items||[]).forEach(function(item){var b=el('button','go-arch-result');b.type='button';if(item.thumb){var im=new Image();im.src=item.thumb;im.alt='';b.appendChild(im);}var copy=el('span','go-arch-result__copy');copy.innerHTML='<strong>'+escapeHtml(item.title)+'</strong>'+(item.status==='draft'?'<small>Rascunho</small>':'');b.appendChild(copy);b.addEventListener('click',function(){choose(item);});results.appendChild(b);});results.hidden=!(d.items||[]).length;}).catch(function(){results.hidden=true;});}
		input.addEventListener('input',function(){clearTimeout(timer);var q=input.value.trim();if(q.length<2){results.hidden=true;return;}timer=setTimeout(function(){search(q);},220);});
		document.addEventListener('click',function(e){if(!field.contains(e.target))results.hidden=true;});
		return {field:field,renderSelected:renderSelected,choose:choose,input:input};
	}

	function productionCreator(productionSearch) {
		var details=el('details','go-arch-create');var summary=el('summary','','Criar nova produção');details.appendChild(summary);var grid=el('div','go-arch-create__grid');
		[['name','Título BR / nome'],['original','Título original'],['country','País'],['seasons','Temporadas'],['episodes','Episódios'],['cast','Elenco'],['watch','Onde assistir'],['status','Status'],['next','Próxima estreia']].forEach(function(a){var f=fieldShell(a[1]);var i=el('input','go-arch-input');i.dataset.key=a[0];f.appendChild(i);grid.appendChild(f);});
		var coverField=fieldShell('Capa 16:9');var coverRow=el('div','go-arch-cover');var coverId=el('input');coverId.type='hidden';coverId.dataset.key='cover_id';var coverButton=el('button','button','Escolher imagem');coverButton.type='button';var coverName=el('small','go-arch-cover__name','Sem capa');coverRow.appendChild(coverButton);coverRow.appendChild(coverName);coverRow.appendChild(coverId);coverField.appendChild(coverRow);grid.appendChild(coverField);
		coverButton.addEventListener('click',function(){if(!window.wp||!wp.media)return;var frame=wp.media({title:'Capa da produção',button:{text:'Usar esta imagem'},library:{type:'image'},multiple:false});frame.on('select',function(){var item=frame.state().get('selection').first().toJSON();coverId.value=String(item.id||'');coverName.textContent=item.filename||item.title||('Imagem #'+item.id);});frame.open();});
		var footer=el('div','go-arch-create__footer'),save=el('button','button button-primary','Criar e vincular'),msg=el('small','go-arch-create__msg');save.type='button';footer.appendChild(save);footer.appendChild(msg);grid.appendChild(footer);details.appendChild(grid);
		save.addEventListener('click',function(){var data={post_id:cfg.postId};Array.prototype.forEach.call(grid.querySelectorAll('[data-key]'),function(i){data[i.dataset.key]=String(i.value||'').trim();});if(!data.name){msg.textContent='Informe o nome.';return;}save.disabled=true;ajax('go_verge_v7_create_production',data).then(function(d){cfg.productionId=d.item.id;cfg.production=d.item;productionSearch.choose(d.item);msg.textContent='Criada e vinculada.';details.open=false;}).catch(function(e){msg.textContent=e.message;}).finally(function(){save.disabled=false;});});
		return details;
	}

	var controls={};
	var architectureStorageKey='go-overdrive-editor-context-v24';

	function architectureExpandedDefault(){
		try{
			var saved=window.localStorage.getItem(architectureStorageKey);
			if(saved==='1'||saved==='0')return saved==='1';
		}catch(e){}
		return realCategoryIds().length!==1||selected(TAX.contentType||'go_content_type').length!==1;
	}
	function setArchitectureExpanded(expanded,focusCategory){
		var panel=document.querySelector('[data-go-v7-architecture]');if(!panel)return;
		var body=panel.querySelector('[data-go-arch-body]'),toggle=panel.querySelector('[data-go-arch-toggle]');
		panel.classList.toggle('is-expanded',!!expanded);if(body)body.hidden=!expanded;
		if(toggle){toggle.setAttribute('aria-expanded',expanded?'true':'false');var label=toggle.querySelector('[data-go-arch-toggle-label]');if(label)label.textContent=expanded?'Recolher':'Editar contexto';}
		try{window.localStorage.setItem(architectureStorageKey,expanded?'1':'0');}catch(e){}
		if(expanded&&focusCategory&&controls.category&&controls.category.select){window.setTimeout(function(){controls.category.select.focus();},30);}
	}
	function selectedNames(tax){return selected(tax).map(function(id){var t=termById(tax,id);return t&&t.name?String(t.name):'';}).filter(Boolean);}
	function updateArchitectureSummary(){
		var panel=document.querySelector('[data-go-v7-architecture]');if(!panel)return;
		var summary=panel.querySelector('[data-go-arch-summary]');if(!summary)return;
		var cats=realCategoryIds(),primary=Number(meta()._go_primary_category_id||0),cat=cats.length?termById('category',cats.indexOf(primary)!==-1?primary:cats[0]):null;
		var types=selectedNames(TAX.contentType||'go_content_type');
		var platforms=selectedNames(TAX.platform||'go_platform');
		var services=selectedNames(TAX.service||'go_service');
		var entityCount=(meta()._go_entity_ids||cfg.entityIds||[]).map(Number).filter(Boolean).length;
		var bits=[];
		bits.push(cat&&cat.name?cat.name:'Sem categoria');
		bits.push(types[0]||'Sem formato');
		if(platforms.length)bits.push(platforms.join(', '));
		if(services.length)bits.push(services.slice(0,2).join(', ')+(services.length>2?' +'+(services.length-2):''));
		if(entityCount)bits.push(entityCount+' entidade'+(entityCount===1?'':'s'));
		summary.textContent=bits.join(' · ');
	}

	function buildPanel(){
		var dock=document.getElementById('go-editor-commandbar');if(!dock||dock.querySelector('[data-go-v7-architecture]'))return;
		var lower=dock.querySelector('.go-editor-commandbar__lower');var matter=dock.querySelector('[data-go-v6-matterbar]');if(!lower||!matter)return;
		var panel=el('section','go-arch');panel.dataset.goV7Architecture='1';
		var head=el('header','go-arch__head');
		var copy=el('div','go-arch__title');copy.innerHTML='<span class="go-arch__eyebrow">Contexto editorial</span><strong>Onde esta matéria se encaixa?</strong><small data-go-arch-summary>Categoria · formato · plataforma · entidades</small>';
		var headActions=el('div','go-arch__head-actions');
		var status=el('span','go-arch__status','Pendente');status.dataset.goV7Status='1';
		var toggle=el('button','go-arch__toggle');toggle.type='button';toggle.dataset.goArchToggle='1';toggle.innerHTML='<span data-go-arch-toggle-label>Editar contexto</span><span aria-hidden="true">⌄</span>';
		toggle.addEventListener('click',function(){setArchitectureExpanded(!panel.classList.contains('is-expanded'));});
		headActions.appendChild(status);headActions.appendChild(toggle);head.appendChild(copy);head.appendChild(headActions);panel.appendChild(head);

		var body=el('div','go-arch__body');body.dataset.goArchBody='1';
		var primary=el('div','go-arch__primary');
		controls.category=categoryControl();primary.appendChild(controls.category.field);
		controls.type=makeSelect(TAX.contentType||'go_content_type','3. Tipo de matéria','Notícia, guia, review…',function(t){return canonicalContentTypes.indexOf(String(t.slug||''))!==-1;});primary.appendChild(controls.type.field);
		controls.guide=makeSelect(TAX.guideType||'go_guide_type','Tipo de guia','Somente quando o formato for Guia');controls.guide.field.classList.add('go-arch-field--guide');primary.appendChild(controls.guide.field);
		body.appendChild(primary);

		var context=el('div','go-arch__context');
		controls.platform=multiPicker(TAX.platform||'go_platform','Plataformas','PC, PlayStation, Xbox, Nintendo…');context.appendChild(controls.platform.field);
		controls.service=multiPicker(TAX.service||'go_service','Serviços','Netflix, Game Pass, Steam, PS Plus…');context.appendChild(controls.service.field);
		controls.production=entitySearch('production','Produção','_go_production_id',false,'Série, filme, novela ou anime');context.appendChild(controls.production.field);
		controls.entity=entitySearch('entity','Entidades','_go_entity_ids',true,'Busque entidades existentes e centrais à pauta');
		var entityHint=el('small','go-arch-entity-hint','Use só entidades centrais. Serviços e plataformas ficam nos campos próprios; não crie personagem só porque foi citado no texto.');controls.entity.field.appendChild(entityHint);var entityTools=el('div','go-arch-entity-tools');
		if(cfg.entitiesAdminUrl){var manage=el('a','go-arch-entity-tools__link','Gerenciar entidades');manage.href=cfg.entitiesAdminUrl;manage.target='_blank';manage.rel='noopener';entityTools.appendChild(manage);}
		if(cfg.newEntityUrl){var add=el('a','go-arch-entity-tools__link go-arch-entity-tools__link--add','+ Criar entidade canônica');add.href=cfg.newEntityUrl;add.target='_blank';add.rel='noopener';entityTools.appendChild(add);}
		controls.entity.field.appendChild(entityTools);context.appendChild(controls.entity.field);
		body.appendChild(context);

		var foot=el('footer','go-arch__foot');var creator=productionCreator(controls.production);foot.appendChild(creator);var gate=el('div','go-arch__gate');gate.dataset.goArchGate='1';foot.appendChild(gate);body.appendChild(foot);panel.appendChild(body);
		matter.insertAdjacentElement('afterend',panel);
		var categoryChip=matter.querySelector('[data-go-v6-category] span');if(categoryChip)categoryChip.textContent='Categoria';
		var oldTags=document.querySelector('[data-go-native-tags-preview]');if(oldTags)oldTags.hidden=true;
		sync();setArchitectureExpanded(architectureExpandedDefault(),false);
	}

	function typeSlug(){var ids=selected(TAX.contentType||'go_content_type');return ids.length?termSlug(TAX.contentType||'go_content_type',ids[0]):'';}
	function sync(){
		if(!controls.category)return;
		controls.category.sync();controls.type.sync();controls.platform.sync();controls.service.sync();controls.guide.sync();controls.production.renderSelected();controls.entity.renderSelected();
		controls.guide.field.hidden=typeSlug()!=='guia';updateArchitectureSummary();runGate();
	}
	function realCategoryIds(){return (attr('categories')||[]).map(Number).filter(Boolean).filter(function(id){return technicalCategorySlugs.indexOf(termSlug('category',id))===-1;});}
	function runGate(){
		var errors=[];var cats=realCategoryIds();var types=selected(TAX.contentType||'go_content_type');if(!cats.length||cats.indexOf(Number(meta()._go_primary_category_id||0))===-1)errors.push('Editoria principal');if(types.length!==1)errors.push('Tipo de matéria');
		window.GoVergeEditorialArchitectureWarnings=errors.slice();
		var panel=document.querySelector('[data-go-v7-architecture]'),status=panel&&panel.querySelector('[data-go-v7-status]'),gate=panel&&panel.querySelector('[data-go-arch-gate]');
		if(status){status.classList.toggle('is-ok',!errors.length);status.textContent=errors.length?(errors.length+' pendência'+(errors.length>1?'s':'')):'Estrutura pronta';}
		if(gate){gate.classList.toggle('is-ok',!errors.length);gate.innerHTML=errors.length?'<strong>Falta revisar:</strong> '+escapeHtml(errors.join(' · '))+' <span>A publicação continua liberada.</span>':'<strong>Estrutura editorial OK.</strong> Categoria e formato definidos.';}
		/* Clear the lock left by older cached builds; these checks are warnings only. */
		try{var d=wp.data.dispatch('core/editor');if(d&&d.unlockPostSaving)d.unlockPostSaving('go-v7-editorial-architecture');}catch(e){}
	}

	document.addEventListener('go:open-architecture',function(){setArchitectureExpanded(true,true);});
	window.addEventListener('go:v10-tax-change',sync);window.addEventListener('go:v7-tax-change',sync);document.addEventListener('go:editorial-commandbar-ready',buildPanel);
	setTimeout(buildPanel,250);setTimeout(buildPanel,900);setTimeout(buildPanel,2200);
	var signature='';
	if(wp.data&&wp.data.subscribe){wp.data.subscribe(function(){if(!controls.category)return;var next=(attr('categories')||[]).join(',')+'|'+selected(TAX.contentType||'go_content_type').join(',')+'|'+selected(TAX.platform||'go_platform').join(',')+'|'+selected(TAX.service||'go_service').join(',')+'|'+selected(TAX.guideType||'go_guide_type').join(',')+'|'+JSON.stringify(meta()._go_production_id||0)+'|'+JSON.stringify(meta()._go_entity_ids||[]);if(next!==signature){signature=next;window.requestAnimationFrame(sync);}});}
})();
