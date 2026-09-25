<?php
/**
 * Render bench: prints which ad units the composer/renderer emit, in order, for
 * the post-content zone and the page end of a given template context.
 *
 *   php tools/render-bench.php <theme-dir> <context>
 *
 * context: single_post | home | category | single_game
 * Checks that no slot id is emitted twice in one document.
 */
require __DIR__ . '/wp-stubs.php';
$theme   = rtrim( $argv[1] ?? '', '/' );
$context = $argv[2] ?? 'single_post';
define( 'GO_VERGE_DIR', $theme );
define( 'GO_VERGE_URI', 'https://example.test/wp-content/themes/overdrive' );
$GLOBALS['__stub_ctx'] = array(
	'context'   => $context,
	'singular'  => array( 'single_post' => 'post', 'single_game' => 'games' )[ $context ] ?? '',
	'page_slug' => '',
);
function is_user_logged_in_stub() { return false; }
foreach ( array( 'mode', 'config', 'calendar-trials', 'context', 'consent', 'renderer', 'planner', 'composer', 'topscroll' ) as $m ) {
	require $theme . '/inc/ads/' . $m . '.php';
}
function od_units( $html ) {
	preg_match_all( '/data-go-ad-placement="([^"]+)"[^>]*data-go-ad-surface="([^"]*)"|data-ad-slot="(\d+)"/', $html, $m, PREG_SET_ORDER );
	$out = array();
	foreach ( $m as $x ) { if ( ! empty( $x[1] ) ) { $out[] = array( 'placement' => $x[1], 'surface' => $x[2] ); } elseif ( ! empty( $x[3] ) ) { $out[ count( $out ) - 1 ]['slot'] = $x[3]; } }
	return $out;
}
ob_start();
if ( 'single_post' === $context ) {
	foreach ( go_verge_ads_post_content_anchors() as $anchor ) {
		go_verge_ads_render_post_content_unit( $anchor, 'after-article-sections' === $anchor ? 'go-container go-post-content-revenue' : '' );
	}
}
if ( 'single_game' === $context ) {
	go_verge_render_adsense_unit( 'sidebar-desktop', array( 'class' => 'go-article-sidebar__ad--sticky', 'data' => array( 'ad-surface' => 'game-sidebar' ) ) );
	go_verge_render_adsense_unit( 'article-rail-mobile', array( 'tag' => 'div', 'class' => 'go-article-sidebar__ad go-article-sidebar__ad--stacked', 'data' => array( 'ad-surface' => 'game-rail-stacked-mobile' ) ) );
}
if ( in_array( $context, array( 'home', 'category' ), true ) ) {
	for ( $row = 1; $row <= 20; $row++ ) { go_verge_ads_maybe_render_listing_unit(); }
}
do_action( 'get_footer', null, array() );
$html = ob_get_clean();
$units = od_units( $html );
$slots = array();
foreach ( $units as $u ) {
	printf( "%-24s surface=%-38s slot=%s\n", $u['placement'], $u['surface'], $u['slot'] ?? '?' );
	$slots[] = $u['slot'] ?? '';
}
$dupes = array_diff_assoc( $slots, array_unique( $slots ) );
printf( "units=%d duplicate-slots=%s\n", count( $units ), $dupes ? implode( ',', $dupes ) : 'none' );
