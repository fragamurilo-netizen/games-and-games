<?php
/**
 * The manual format contract.
 *
 * Until 4.6 two placements could silently change their AdSense UNIT TYPE from a
 * wp-config constant: A3 from In-article fluid to Display responsive, and
 * Article End from Display to Multiplex. A unit's type is part of its reporting
 * identity, so a config typo rewrote how a live unit was served and measured.
 * Both experiments are gone and must stay gone.
 *
 * 5.0.3 made the whole body ladder Display responsive, and did it the only safe
 * way: three NEW units, declared with the format they actually are. That is the
 * distinction this file exists to keep. Changing a format by pointing a
 * placement at a different unit is a decision recorded in the contract;
 * changing it by constant rewrites a live unit's identity behind the reporting.
 */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
function go_verge_ads_unit_matches_context( $unit ) { return true; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return false; }
function go_verge_adsense_topscroll_config() { return array(); }
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';

$c = go_verge_ads_config();
$inventory = $c['inventory'];

go_test_section( 'Nenhum formato troca de tipo por constante' );
go_test_ok( ! defined( 'GO_VERGE_ADS_ARTICLE_A3_DISPLAY_SLOT' ), 'A constante do experimento Display de A3 não existe mais' );
go_test_ok( ! defined( 'GO_VERGE_ADS_ARTICLE_END_MULTIPLEX_SLOT' ), 'A constante do experimento Multiplex não existe mais' );
$source = file_get_contents( GO_VERGE_DIR . '/inc/ads/config.php' );
go_test_ok( false === strpos( $source, 'multiplex' ), 'O contrato não contém mais um caminho Multiplex' );
go_test_ok( false === strpos( $source, 'autorelaxed' ), 'O contrato não contém mais um formato autorelaxed' );

go_test_section( 'O corpo do artigo é um formato só' );
/*
 * Uma escada com dois produtos misturados não se compara: A3 In-article contra
 * A4 Display é posição E formato ao mesmo tempo. Agora as oito posições pedem a
 * mesma coisa, então a diferença entre elas é profundidade, que é o que o
 * planner controla.
 */
$body = array( 'article-prime', 'article-a1', 'article-a2', 'article-a3', 'article-a4', 'article-a5', 'article-a6', 'article-end' );
foreach ( $body as $key ) {
	$unit = $inventory[ $key ];
	go_test_equals( 'responsive', $unit['sizing'], $key . ' é Display responsivo' );
	go_test_equals( 'auto', $unit['format'], $key . ' pede data-ad-format auto' );
	go_test_ok( ! empty( $unit['full_width'] ), $key . ' usa full-width responsive em fluxo normal' );
	go_test_ok( ! isset( $unit['ad_layout'] ), $key . ' não declara layout de In-article' );
}
/* Os ids In-article aposentados não podem voltar por descuido: a unidade
 * continua existindo na conta e serviria com o markup errado. */
$slots = array_map( static function ( $key ) use ( $inventory ) { return (string) $inventory[ $key ]['slot']; }, $body );
foreach ( array( '6368539121', '7554015324', '6240933652' ) as $retired ) {
	go_test_ok( ! in_array( $retired, $slots, true ), 'A unidade In-article aposentada ' . $retired . ' não é mais servida' );
}
/* Qualquer unidade, em qualquer lugar do inventário: formato e forma nunca
 * discordam. É o descasamento que faz um criativo fluid ser pedido para uma
 * unidade Display e simplesmente não preencher. */
foreach ( $inventory as $key => $unit ) {
	if ( empty( $unit['enabled'] ) ) { continue; }
	$fluid = ( 'fluid' === ( $unit['sizing'] ?? '' ) );
	go_test_equals( $fluid, ( 'fluid' === ( $unit['format'] ?? '' ) ), $key . ': sizing e format concordam' );
	go_test_equals( $fluid, isset( $unit['ad_layout'] ), $key . ': só formato fluid declara ad_layout' );
	if ( $fluid ) { go_test_ok( empty( $unit['full_width'] ), $key . ': fluid nunca pede full-width' ); }
}

go_test_section( 'Markup emitido' );
$a1_html  = go_verge_adsense_unit_markup( 'article-a1' );
$a3_html  = go_verge_adsense_unit_markup( 'article-a3' );
$end_html = go_verge_adsense_unit_markup( 'article-end' );
go_test_ok( false === strpos( $a1_html . $a3_html . $end_html, 'data-ad-layout=' ), 'Nenhum host do corpo emite layout de In-article' );
go_test_ok( false === strpos( $a1_html . $a3_html . $end_html, 'data-ad-format="fluid"' ), 'Nenhum host do corpo emite formato fluid' );
go_test_ok( false !== strpos( $a3_html, 'data-ad-format="auto"' ), 'A3 emite Display auto' );
go_test_ok( false !== strpos( $a3_html, 'data-full-width-responsive="true"' ), 'A3 mantém full-width' );
go_test_ok( false !== strpos( $end_html, 'data-ad-format="auto"' ), 'Article End emite Display auto' );
go_test_ok( false !== strpos( $end_html, 'data-full-width-responsive="true"' ), 'Article End mantém full-width' );
go_test_ok( false !== strpos( $a1_html, '<template data-go-ad-pending>' ) && false !== strpos( $end_html, '<template data-go-ad-pending>' ), 'Todo formato continua inerte até o runtime' );
go_test_ok( false === strpos( $a1_html . $a3_html . $end_html, 'adsbygoogle = window.adsbygoogle' ), 'Renderer não cria segundo caminho de request' );
go_test_ok( 1 === substr_count( $a3_html, 'data-ad-slot=' ), 'Cada host carrega exatamente um slot' );
