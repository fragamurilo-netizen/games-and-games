(function(){
  'use strict';
  function norm(s){return String(s||'').replace(/\s+/g,' ').replace(/\s*\*\s*$/,'').trim().toLowerCase();}
  var labelMap={
    'nome da loja':'Loja',
    'url afiliada/oferta':'Link da oferta',
    'url afiliada / oferta':'Link da oferta',
    'url da oferta':'Link da oferta',
    'url da imagem':'Imagem do produto (URL)',
    'produto':'Produto / jogo',
    'preço normal':'Preço original',
    'preco normal':'Preço original',
    'preço promocional':'Preço com desconto',
    'preco promocional':'Preço com desconto',
    'moeda':'Moeda',
    'código do cupom':'Código do cupom',
    'codigo do cupom':'Código do cupom',
    'válido até':'Validade',
    'valido ate':'Validade',
    'cta do botão':'Texto do botão',
    'cta do botao':'Texto do botão',
    'vincular ao jogo':'Jogo relacionado'
  };
  var nameMap={
    'go_promotion_store_name':'Loja',
    'go_promotion_offer_url':'Link da oferta',
    'go_promotion_image_url':'Imagem do produto (URL)',
    'go_promotion_product_name':'Produto / jogo',
    'go_promotion_regular_price':'Preço original',
    'go_promotion_normal_price':'Preço original',
    'go_promotion_sale_price':'Preço com desconto',
    'go_promotion_currency':'Moeda',
    'go_promotion_coupon_code':'Código do cupom',
    'go_promotion_valid_until':'Validade',
    'go_promotion_button_label':'Texto do botão',
    'go_promotion_linked_game_id':'Jogo relacionado'
  };
  function setLabel(label,text){
    if(!label||!text)return;
    var nodes=Array.prototype.slice.call(label.childNodes);
    var textNode=nodes.find(function(n){return n.nodeType===3&&n.nodeValue.trim();});
    if(textNode){textNode.nodeValue=text+' ';return;}
    var nested=label.querySelector('span,strong');
    if(nested&&!nested.querySelector('input,select,textarea')){nested.textContent=text;return;}
    if(!label.querySelector('input,select,textarea'))label.textContent=text;
  }
  function fieldWrap(control,box){
    var el=control.parentElement;
    while(el&&el!==box){
      if(el.matches('p,.form-field,.field,.go-field,.cmb-row,.rwmb-field')||((el.children||[]).length<=4&&el.querySelector('label'))){return el;}
      el=el.parentElement;
    }
    return control.parentElement;
  }
  function init(){
    var boxes=Array.prototype.slice.call(document.querySelectorAll('.postbox'));
    var box=boxes.find(function(b){var h=b.querySelector('.postbox-header h2,.hndle');return h&&/detalhes da promo|dados da oferta|promoção/i.test(h.textContent);});
    if(!box)return;
    box.classList.add('go-promotion-details-box');
    var title=box.querySelector('.postbox-header h2,.hndle');if(title)title.textContent='Dados da oferta';
    var controls=Array.prototype.slice.call(box.querySelectorAll('input[name],select[name],textarea[name]')).filter(function(c){return /go_promotion_|promotion_/i.test(c.name);});
    var wrappers=[];
    controls.forEach(function(control){
      var label=control.id?box.querySelector('label[for="'+CSS.escape(control.id)+'"]'):null;
      if(!label){label=control.closest('label');}
      var wanted=nameMap[control.name];
      if(!wanted&&label)wanted=labelMap[norm(label.textContent)];
      if(wanted&&label)setLabel(label,wanted);
      var wrap=fieldWrap(control,box);if(!wrap)return;
      wrap.classList.add('go-promo-field');
      if(/offer_url|image_url/i.test(control.name))wrap.classList.add('go-promo-field--wide');
      if(/coupon/i.test(control.name))wrap.classList.add('go-promo-field--coupon');
      if(/price/i.test(control.name))wrap.classList.add('go-promo-field--price');
      if(wrappers.indexOf(wrap)===-1)wrappers.push(wrap);
    });
    box.querySelectorAll('label').forEach(function(label){var wanted=labelMap[norm(label.textContent)];if(wanted)setLabel(label,wanted);});
    if(wrappers.length>1){
      var parent=wrappers[0].parentElement;
      if(parent&&wrappers.every(function(w){return w.parentElement===parent;}))parent.classList.add('go-promo-fields-grid');
    }
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
