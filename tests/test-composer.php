<?php
/** Integration test: planner -> composer with multiple inert reserves. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';

if ( ! function_exists( 'is_singular' ) ) {
	function is_singular( $type = '' ) { return 'post' === $type || '' === $type; }
}
function go_verge_ads_is_monetizable_request() { return true; }
function go_verge_ads_debug_enabled() { return true; }
function go_verge_adsense_unit_markup( $placement, $args = array() ) {
	$data = '';
	foreach ( (array) ( $args['data'] ?? array() ) as $key => $value ) {
		$data .= ' data-go-' . sanitize_key( $key ) . '="' . esc_attr( $value ) . '"';
	}
	return '<aside data-go-ad-placement="' . esc_attr( $placement ) . '"' . $data . '><template data-go-ad-pending><ins class="adsbygoogle" data-ad-slot="test-' . esc_attr( $placement ) . '"></ins></template></aside>';
}
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
require_once GO_VERGE_DIR . '/inc/ads/composer.php';

function gc_para( $words ) { return '<p>' . implode( ' ', array_fill( 0, $words, 'conteudo' ) ) . '.</p>'; }
$html = str_repeat( gc_para( 70 ), 8 );
$plan = go_verge_ads_plan_article( $html );
$out = go_verge_ads_compose_article_inventory( $html );

go_test_section( 'Integração planner -> composer' );
$planned  = (int) $plan['plannedCount'];
$reserves = (int) $plan['reserveCount'];
$rendered = (int) $plan['renderedCount'];
go_test_ok( $planned >= 4, '560 palavras mantêm ao menos quatro alvos primários', 'planejado=' . $planned );
go_test_ok( $reserves >= 1, 'Planner expõe reserva inerte para o governador do navegador', 'reservas=' . $reserves );
go_test_equals( $planned + $reserves, $rendered, 'Render count é exatamente alvos + reservas' );
preg_match_all( '/data-go-ad-placement="([^"]+)"/', $out, $matches );
$placements = $matches[1] ?? array();
go_test_equals( $rendered, count( $placements ), 'Composer injeta todos os hosts aprovados' );
go_test_equals( count( $placements ), count( array_unique( $placements ) ), 'Cada host usa placement único' );
go_test_ok( false !== strpos( $out, 'data-go-ad-fallback-reserve="1"' ), 'Reservas são explicitamente marcadas para o runtime' );

$public = $GLOBALS['go_verge_ads_article_plan_public'];
go_test_equals( $planned, (int) $public['planned-body'], 'Telemetria pública preserva o budget STANDARD' );
go_test_equals( $rendered, (int) $public['rendered-body'], 'Telemetria pública preserva hosts renderizados' );
go_test_equals( $reserves, (int) $public['reserve-body'], 'Telemetria pública preserva contagem de reservas' );
go_test_equals( min( 7, $rendered ), (int) $public['body-capacity'], 'Telemetria pública expõe o teto de EXPANSÃO' );
go_test_equals( 4, (int) $public['ladder-capacity'], 'Telemetria preserva o teto por palavras/formato' );
go_test_equals( 2, (int) $public['headroom'], 'Telemetria expõe os passos estruturais comprovados' );
go_test_equals( '19.0.0-manual-governor', $public['planner-version'], 'Composer propaga a versão do planner' );
go_test_ok( array_key_exists( 'article-type', $public ), 'O tipo editorial viaja na telemetria pública' );
go_test_ok( ! array_key_exists( 'word-capacity', $public ) && ! array_key_exists( 'revenue-headroom', $public ),
	'Chaves da telemetria 4.x que ninguém mais lia foram removidas' );

go_test_section( 'O pool de listagem entrega uma unidade por vez, em ordem' );
if ( ! function_exists( 'go_verge_ads_document_context' ) ) {
	function go_verge_ads_document_context() { return 'category'; }
}
$drawn = array();
for ( $i = 0; $i < 7; $i++ ) {
	$drawn[] = go_verge_ads_listing_pool_next( 'category' );
}
go_test_equals( array( 'listing-f1', 'listing-f2', 'listing-f3', 'listing-f4', 'listing-f5', '', '' ), $drawn,
	'O pool entrega F1..F5 em ordem e depois se esgota' );
go_test_equals( 'listing-f1', go_verge_ads_listing_pool_next( 'home' ), 'Cada contexto tem seu próprio cursor' );
go_test_ok( in_array( 'category', go_verge_ads_listing_contexts(), true ), 'Arquivos de categoria carregam inventário de listagem' );
go_test_ok( ! in_array( 'single_post', go_verge_ads_listing_contexts(), true ), 'O artigo usa o planner, nunca o pool de listagem' );
