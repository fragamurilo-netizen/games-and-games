<?php
/** Mobile masthead, accessible brand controls and editorial image diagnostics. */
if (!defined('ABSPATH')) { exit; }
function go_375_assets() {
 $rel='/assets/css/overdrive-375.css';
 wp_enqueue_style('go-overdrive-375',GO_VERGE_URI.$rel,array(),go_verge_asset_version($rel));
}
add_action('wp_enqueue_scripts','go_375_assets',46000);


/** Discover uses existing SEO ownership; this adds actionable checks inside the editor. */
add_action('add_meta_boxes_post',static function(){
 add_meta_box('go-discover-image-check','Imagem para Google Discover',static function($post){
  $id=get_post_thumbnail_id($post);$image=$id&&function_exists('go_verge_rank_math_discover_image')?go_verge_rank_math_discover_image($id):array();
  if(!empty($image['url'])){
   printf('<p><strong>Imagem grande disponível: %d × %d px</strong></p><p>Prévia selecionada pelo tema. Confira o enquadramento, a autoria e se ela representa esta matéria.</p>',absint($image['width']),absint($image['height']));
  }else{
   echo '<p><strong>Revise a imagem destacada.</strong></p><p>Use uma foto relevante com pelo menos 1.200 px de largura e mais de 300 mil pixels. Para a prévia social, envie JPEG, PNG ou WebP; não use a marca do site como imagem da matéria.</p>';
  }
  echo '<p>Título descritivo, autoria identificada e conteúdo original ajudam o leitor. Elegibilidade técnica não garante aparição no Discover.</p><p><a href="https://developers.google.com/search/docs/appearance/google-discover?hl=pt-br" target="_blank" rel="noopener">Orientações do Google</a></p>';
 },'post','side','default');
});
