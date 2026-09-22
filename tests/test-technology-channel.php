<?php
/** Offline routing/rendering checks for the existing inline channel component. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';

class WP_Term {
	public $term_id; public $slug; public $name; public $parent; public $taxonomy;
	public function __construct( $id, $slug, $name, $parent = 0, $taxonomy = 'category' ) {
		$this->term_id=$id; $this->slug=$slug; $this->name=$name; $this->parent=$parent; $this->taxonomy=$taxonomy;
	}
}
$GLOBALS['go_channel_terms'] = array();
$GLOBALS['go_channel_posts'] = array();
$GLOBALS['go_channel_current'] = 0;
function is_wp_error( $v ) { return false; }
function wp_strip_all_tags( $s ) { return strip_tags( preg_replace( '@<(script|style)[^>]*?>.*?</\1>@si', '', (string) $s ) ); }
function remove_accents( $s ) { return strtr( $s, array( 'á'=>'a','à'=>'a','ã'=>'a','â'=>'a','é'=>'e','ê'=>'e','í'=>'i','ó'=>'o','õ'=>'o','ô'=>'o','ú'=>'u','ç'=>'c','Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ç'=>'C','ü'=>'u','Ü'=>'U','ı'=>'i' ) ); }
function sanitize_title( $s ) { return trim( preg_replace( '/[^a-z0-9]+/', '-', strtolower( remove_accents( $s ) ) ), '-' ); }
function get_queried_object_id() { return $GLOBALS['go_channel_current']; }
function get_the_ID() { return get_queried_object_id(); }
function is_singular( $type = '' ) { return 'post' === get_post_type( get_queried_object_id() ); }
function in_the_loop() { return true; }
function is_main_query() { return true; }
function get_post_type( $id ) { return $GLOBALS['go_channel_posts'][$id]['type'] ?? ''; }
function get_post_meta( $id, $key, $single = true ) { return $GLOBALS['go_channel_posts'][$id]['meta'][$key] ?? ''; }
function get_post_field( $key, $id ) { return $GLOBALS['go_channel_posts'][$id][$key] ?? ''; }
function get_the_title( $id ) { return $GLOBALS['go_channel_posts'][$id]['title'] ?? ''; }
function get_the_terms( $id, $taxonomy ) { return wp_get_post_terms( $id, $taxonomy ); }
function wp_get_post_terms( $id, $taxonomy, $args = array() ) {
	$terms = array();
	foreach ( (array) ( $GLOBALS['go_channel_posts'][$id]['terms'][$taxonomy] ?? array() ) as $term_id ) {
		if ( isset( $GLOBALS['go_channel_terms'][$term_id] ) ) { $terms[] = $GLOBALS['go_channel_terms'][$term_id]; }
	}
	return 'slugs' === ( $args['fields'] ?? '' ) ? array_map( static function ( $t ) { return $t->slug; }, $terms ) : $terms;
}
function get_term( $id, $taxonomy = '' ) { return $GLOBALS['go_channel_terms'][$id] ?? null; }
function get_ancestors( $id, $type = '', $resource = '' ) {
	$out = array();
	while ( ( $term = get_term( $id ) ) && $term->parent && count( $out ) < 20 ) {
		$out[] = $term->parent; $id = $term->parent;
	}
	return $out;
}
function get_term_by( $field, $value, $taxonomy ) {
	foreach ( $GLOBALS['go_channel_terms'] as $term ) { if ( $term->taxonomy === $taxonomy && $term->$field === $value ) { return $term; } }
	return null;
}
function get_category_link( $term ) { return 'https://example.test/category/' . $term->slug . '/'; }
function go_verge_article_subject( $id ) { return $GLOBALS['go_channel_posts'][$id]['subject'] ?? null; }

foreach ( array(
	array(10,'tecnologia','Tecnologia'), array(11,'celulares','Celulares',10), array(12,'dobraveis','Dobráveis',11),
	array(13,'apps-software','Apps e Software',10), array(14,'hardware','Hardware',10), array(15,'ia','Inteligência Artificial',10),
	array(20,'games','Games'), array(21,'guias','Guias',20), array(30,'entretenimento','Entretenimento'),
	array(31,'filmes-series-dizis-turcas','Produções turcas',30), array(40,'ofertas','Ofertas'),
	array(50,'dizi','Dizi',0,'post_tag'), array(51,'android','Android',0,'post_tag'),
) as $args ) {
	$term = new WP_Term( ...$args ); $GLOBALS['go_channel_terms'][$term->term_id] = $term;
}
function technology_story( $id, $categories, $primary = 0, $subject = null, $extra = array() ) {
	$GLOBALS['go_channel_posts'][$id] = array_merge( array(
		'type'=>'post', 'title'=>'Matéria editorial', 'post_content'=>'Android aparece aqui apenas como menção.',
		'terms'=>array('category'=>$categories), 'meta'=>$primary ? array('_go_primary_category_id'=>$primary) : array(), 'subject'=>$subject,
	), $extra );
}
function technology_subject( $name, $type = 'go_entity', $type_label = 'Assunto' ) {
	return array('name'=>$name,'type'=>$type,'type_label'=>$type_label,'id'=>900,'source'=>'explicit');
}
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
require_once GO_VERGE_DIR . '/inc/template-helpers.php';
require_once GO_VERGE_DIR . '/inc/editorial-scope.php';
require_once GO_VERGE_DIR . '/inc/channel-invite.php';
require_once GO_VERGE_DIR . '/inc/turkish-channel-list-ranking-v48.php';

$cases = array(
	array(101, array(11,20),11,null,'technology','phones','Explicit Technology subeditoria wins over a secondary Games category'),
	array(102, array(20,11),20,technology_subject('Android'),'games',null,'Explicit Games is not reassigned because Android is the subject'),
	array(103, array(12),0,null,'technology','phones','An assigned descendant inherits the Technology and Celulares ancestry'),
	array(104, array(10),10,null,'technology','general','General Technology does not infer a topic from the body mention'),
	array(105, array(),0,null,null,null,'A title/body word alone does not establish Technology'),
	array(106, array(),0,technology_subject('Windows 11'),'technology','windows','A canonical technology entity supplies a missing desk'),
	array(107, array(),0,technology_subject('Android Runner','games'),null,null,'A Game object is never treated as a technology entity'),
	array(108, array(30),30,technology_subject('Windows'),'pop',null,'Entertainment remains in its own channel'),
	array(109, array(13),13,technology_subject('Windows 11'),'technology','windows','Canonical Windows refines the broad Apps category'),
	array(110, array(10),10,technology_subject('Galaxy Watch 8'),'technology','wearables','Wearable subject is not mistaken for phones'),
	array(111, array(10),10,technology_subject('ChatGPT'),'technology','ai','Canonical AI topic chooses natural IA copy'),
	array(112, array(14),14,technology_subject('AirPods'),'technology','audio','Audio subject refines the broad Hardware category'),
	array(113, array(10),10,technology_subject('MacBook Air'),'technology','computers','Canonical notebook chooses PC and notebook copy'),
	array(114, array(10),10,technology_subject('OLED 2026','go_entity','Televisor'),'technology','tv','Structured entity type supplies TV context'),
	array(115, array(20),10,technology_subject('Android'),'games',null,'Unassigned saved primary does not override the real category'),
	array(116, array(40),40,technology_subject('iPhone'),'technology-never',null,'Offers desk is preserved without stealing its editorial CTA'),
	array(117, array(11),11,technology_subject('Windows'),'technology','phones','A narrow explicit subeditoria remains authoritative for copy'),
	array(118, array(13),13,null,'technology','software','Apps subeditoria supplies fallback without a subject'),
	array(119, array(10),10,technology_subject('<img src=x onerror=alert(1)> Windows'),'technology','windows','Catalogue HTML is normalized and never rendered as raw markup'),
	array(120, array(20,10),0,technology_subject('Android'),'games',null,'Ambiguous desk does not let a secondary Technology term steal Games'),
);
go_test_section('Canonical Technology routing and context');
foreach ( $cases as $case ) {
	list($id,$categories,$primary,$subject,$key,$topic,$label)=$case;
	technology_story($id,$categories,$primary,$subject);
	$GLOBALS['go_channel_current']=$id;
	$cluster=go_verge_channel_invite_for_post($id);
	if ('technology-never'===$key) { go_test_ok('technology'!==($cluster['key']??''),$label); }
	else { go_test_equals($key??'',(string)($cluster['key']??''),$label); }
	if ($topic) { go_test_equals($topic,$cluster['technology_topic']??'', 'Expected topic for post '.$id); }
}

go_test_section('Turkish routing and existing channels keep precedence');
$GLOBALS['go_channel_posts'][501]=array('type'=>'productions','title'=>'Farah','meta'=>array('_go_country'=>'Turquia'));
technology_story(201,array(10),10,null,array('meta'=>array('_go_primary_category_id'=>10,'_go_production_id'=>501)));
$GLOBALS['go_channel_current']=201;
go_test_equals('turcas',go_verge_channel_invite_for_post(201)['key'],'Linked Turkish production still selects the Turkish channel');
technology_story(202,array(10),10,null,array('terms'=>array('category'=>array(10),'post_tag'=>array(50))));
$GLOBALS['go_channel_current']=202;
go_test_equals('turcas',go_verge_channel_invite_for_post(202)['key'],'Explicit Turkish tag still takes precedence');
$clusters=go_verge_channel_invite_clusters();
go_test_equals('https://whatsapp.com/channel/0029VbDaFgx7YSdBSZLABX0b',$clusters['turcas']['channel_url'],'Turkish destination preserved');
go_test_equals('https://whatsapp.com/channel/0029VbD3xgo5K3zd4n3vhk2r',$clusters['games']['channel_url'],'Games destination preserved');
go_test_equals('https://whatsapp.com/channel/0029Vb8GRzGEKyZEl4ulpP3s',$clusters['pop']['channel_url'],'General entertainment destination preserved');

go_test_section('Existing component: output, accessibility and idempotence');
$GLOBALS['go_channel_current']=101;
$cluster=go_verge_channel_invite_for_post(101);
$markup=go_verge_channel_invite_channel_markup($cluster);
go_test_ok(false!==strpos($markup,'href="https://whatsapp.com/channel/0029Vb8lV4nFi8xiDKv2mT08"'),'Exact supplied Technology URL is emitted');
go_test_ok(false!==strpos($markup,'data-go-channel-cluster="technology"'),'Existing channel metadata distinguishes Technology');
go_test_ok(false!==strpos($markup,'data-go-ad-integrity="atomic"'),'CTA remains a protected editorial component');
go_test_ok(false!==strpos($markup,'target="_blank" rel="noopener noreferrer nofollow"'),'External link uses the intended target and rel');
go_test_ok(false!==strpos($markup,'aria-label="Abrir o canal de Tecnologia do Overdrive no WhatsApp (nova aba)"'),'Accessible label names the channel and new tab');
go_test_ok(false!==strpos($markup,'De olho em celulares?'),'Visible copy follows the subeditoria');
go_test_ok(false!==strpos($markup,'canal de Tecnologia do Overdrive'),'Copy identifies the shared Technology channel');
go_test_ok(false===strpos($markup,'promoç') && false===strpos($markup,'ofertas'),'Technology invitation does not promise only deals');

$content=str_repeat('<p>Um parágrafo editorial completo com conteúdo independente.</p>',3).'<h2>Detalhes</h2><p>Outro parágrafo editorial.</p>';
$once=go_verge_channel_invite_insert_channel($content);
$twice=go_verge_channel_invite_insert_channel($once);
go_test_equals(1,substr_count($once,'data-go-channel-invite="channel"'),'Existing insertion point receives exactly one channel CTA');
go_test_equals($once,$twice,'Repeated content filtering does not duplicate the invite');
go_test_ok(strpos($once,'data-go-channel-invite="channel"')<strpos($once,'<h2>'),'Channel stays before the existing safe top-level heading');
$section=go_verge_channel_invite_append_section($once);
go_test_equals(1,substr_count($section,'data-go-channel-invite="channel"'),'Section continuation does not add another WhatsApp CTA');
go_test_equals($section,go_verge_channel_invite_append_section($section),'Section link remains idempotent');
go_test_equals($content.'<aside data-go-channel-invite=\'channel\'>Manual</aside>',go_verge_channel_invite_insert_channel($content.'<aside data-go-channel-invite=\'channel\'>Manual</aside>'),'A saved single-quoted channel marker is preserved');
$manual='<aside><a href="https://whatsapp.com/channel/editorial-choice">Canal escolhido pela redação</a></aside>'.$content;
go_test_equals($manual,go_verge_channel_invite_insert_channel($manual),'An explicit channel written into the article is not replaced or duplicated');
$manual_unquoted='<aside><a href=https://whatsapp.com/channel/editorial-choice>Canal editorial</a></aside>'.$content;
go_test_equals($manual_unquoted,go_verge_channel_invite_insert_channel($manual_unquoted),'A valid unquoted manual channel link is preserved without a duplicate');
$manual_relative='<aside><a href="//whatsapp.com/channel/editorial-choice">Canal editorial</a></aside>'.$content;
go_test_equals($manual_relative,go_verge_channel_invite_insert_channel($manual_relative),'A protocol-relative manual channel link is preserved without a duplicate');
$nested='<div><h2>Título interno</h2><p>Conteúdo de um componente.</p></div>';
go_test_equals($nested,go_verge_channel_invite_insert_channel($nested),'No channel is inserted into a nested component');
$short='<p>Nota sem subtítulo.</p>';
go_test_equals($short,go_verge_channel_invite_insert_channel($short),'A short note keeps the original absence of a channel break');
$escaped=array_merge($cluster,array('technology_topic'=>'general','question'=>'<img src=x onerror=alert(1)>','channel_cta'=>'Canal & notícias'));
$escaped_markup=go_verge_channel_invite_channel_markup($escaped);
go_test_ok(false===strpos($escaped_markup,'<img src=x') && false!==strpos($escaped_markup,'&lt;img'),'Filtered copy is escaped before rendering');
go_test_ok(false!==strpos($escaped_markup,'Canal &amp; notícias'),'Text entities are escaped once in the rendered link');
technology_story(203,array(10),10,null,array('type'=>'page'));
$GLOBALS['go_channel_current']=203;
go_test_equals($content,go_verge_channel_invite_insert_channel($content),'The component remains limited to editorial posts');


go_test_section('Real planner and shared protection integration');
$GLOBALS['go_channel_current']=101;
$ad='<aside class="go-ad-slot" data-go-ad-placement="article-a1"><template><ins class="adsbygoogle" data-ad-slot="fixture"></ins></template></aside>';
$paragraph='<p>'.str_repeat('conteúdo editorial relevante ',30).'</p>';
$adjacent='<p>Introdução editorial.</p>'.$ad.'<h2>Primeiro título</h2>'.$paragraph.'<h2>Segundo título</h2><p>Continuação.</p>';
$first=strpos($adjacent,'<h2>');
go_test_ok(go_verge_ads_break_near_protected_ui($adjacent,$first),'An immediately preceding ad is recognized by the active planner scanner');
$placed=go_verge_channel_invite_insert_channel($adjacent);
$placed_cta=strpos($placed,'data-go-channel-invite="channel"');
go_test_ok(false!==$placed_cta && $placed_cta>strpos($placed,'<h2>Primeiro título') && $placed_cta<strpos($placed,'<h2>Segundo título'),'An adjacent first heading is skipped and the next eligible heading receives the CTA');
go_test_equals(1,substr_count($placed,'data-go-channel-invite="channel"'),'Trying another heading still inserts only one CTA');
go_test_equals($placed,go_verge_channel_invite_insert_channel($placed),'The integrated protection path remains idempotent');
go_test_equals(1,substr_count($placed,$ad),'The existing ad host remains byte-for-byte intact and unique');
$far=$ad.$paragraph.'<h2>Primeiro título</h2>'.$paragraph;
go_test_ok(!go_verge_ads_break_near_protected_ui($far,strpos($far,'<h2>')),'Substantial editorial prose after an ad leaves the original heading eligible');
go_test_ok(strpos(go_verge_channel_invite_insert_channel($far),'data-go-channel-invite="channel"')<strpos(go_verge_channel_invite_insert_channel($far),'<h2>'),'A distant ad does not suppress the ordinary invitation');
$next='<p>Introdução.</p><h2>Título</h2>'.$ad.$paragraph.'<h2>Mais detalhes</h2>'.$paragraph;
go_test_ok(go_verge_ads_break_near_protected_ui($next,strpos($next,'<h2>')),'A short heading alone is insufficient clearance before the following ad');
$script_gap='<p>Introdução.</p>'.$ad.'<script>var ignored="'.str_repeat('not editorial ',60).'";</script><!-- marker --><h2>Título</h2>'.$paragraph;
go_test_ok(go_verge_ads_break_near_protected_ui($script_gap,strpos($script_gap,'<h2>')),'Ad mount scripts and comments cannot manufacture editorial clearance');
$script_only='<p>Introdução.</p><script>window.fixture=true;</script><h2>Título</h2>'.$paragraph;
go_test_ok(!go_verge_ads_break_near_protected_ui($script_only,strpos($script_only,'<h2>')),'An unrelated script does not become a visible UI barrier');
$no_alternative='<p>Introdução.</p>'.$ad.'<h2>Único título</h2>'.$paragraph;
go_test_equals($no_alternative,go_verge_channel_invite_insert_channel($no_alternative),'With no safe heading the optional CTA leaves the whole article and its ad intact');
$normal=str_repeat($paragraph,4);
go_test_ok(count(go_verge_content_safe_paragraph_breaks($normal,55))>0,'Shared prose-break consumers retain eligible normal paragraphs');
$atomic='<aside data-go-ad-integrity="atomic">'.str_repeat($paragraph,4).'</aside>'.$normal;
$inside=strpos($atomic,'</p>')+4;
go_test_ok(go_verge_content_offset_is_protected($atomic,$inside),'The shared interior guard recognizes paragraph endings inside an atomic card');
foreach (go_verge_content_safe_paragraph_breaks($atomic,55) as $safe_break) {
	go_test_ok($safe_break['position']>strpos($atomic,'</aside>'),'Shared sharing and recirculation candidates cannot enter an atomic card');
}
$marked_ad='<aside class="go-ad-slot" data-go-ad-placement="article-a1" data-padding="'.str_repeat('markup ',1000).'"><template><ins class="adsbygoogle"></ins></template></aside>';
$markup_far=$marked_ad.$paragraph.'<h2>Título</h2>'.$paragraph;
go_test_ok(!go_verge_ads_break_near_protected_ui($markup_far,strpos($markup_far,'<h2>')),'Thousands of attribute bytes do not suppress an otherwise eligible prose-separated CTA');
$malformed='<aside class="go-ad-slot"><p>broken</aside><h2>Título</h2>';
go_test_ok(go_verge_ads_break_near_protected_ui($malformed,strpos($malformed,'<h2>')),'Malformed structure never supplies a guessed UI insertion boundary');

$hidden_only='<p>Introdução.</p><div hidden>'.str_repeat('invisible words ',80).'</div><h2>Título</h2>'.$paragraph;
go_test_ok(!go_verge_ads_break_near_protected_ui($hidden_only,strpos($hidden_only,'<h2>')),'A hidden component alone is not a neighbouring visible UI barrier');
$hidden_after_ad=$ad.'<div hidden>'.str_repeat('invisible words ',80).'</div><h2>Título</h2>'.$paragraph;
go_test_ok(go_verge_ads_break_near_protected_ui($hidden_after_ad,strpos($hidden_after_ad,'<h2>')),'Hidden text between an ad and a heading cannot manufacture visible clearance');
$threshold=$ad.'<p>'.trim(str_repeat('editorial ',20)).'</p><h2>Título</h2>'.$paragraph;
go_test_ok(!go_verge_ads_break_near_protected_ui($threshold,strpos($threshold,'<h2>')),'The existing twenty-word clearance is sufficient without raising the limit');
