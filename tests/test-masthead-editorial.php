<?php
/** Masthead restriction: real PHP markup with WordPress doubles, no network. */
if ( 'cli' !== PHP_SAPI ) { exit; }
$cases = array( 'review', 'critica', 'especial', 'pack', 'legacy-review', 'legacy-critica', 'legacy-special', 'news', 'guide', 'news-stale-review', 'home', 'archive', 'games', 'zero-id', 'review-breakpoint', 'review-mobile-disabled', 'auto-review' );
if ( ! isset( $argv[1] ) ) {
	$failed = 0;
	foreach ( $cases as $case ) {
		passthru( escapeshellarg( PHP_BINARY ) . ' ' . escapeshellarg( __FILE__ ) . ' ' . escapeshellarg( $case ), $status );
		$failed += (int) ( 0 !== $status );
	}
	exit( $failed ? 1 : 0 );
}
if ( in_array( '--json', $argv, true ) ) { define( 'GO_TEST_FIXTURE_EXPORT', true ); }
require_once __DIR__ . '/bootstrap.php';
$case = $argv[1];
$restricted = in_array( $case, array( 'review', 'critica', 'especial', 'pack', 'legacy-review', 'legacy-critica', 'legacy-special', 'review-breakpoint', 'review-mobile-disabled', 'auto-review' ), true );
$desktop_min = 'review-breakpoint' === $case ? 1281 : 1101;
function get_option( $key, $default = false ) { global $case; return 'go_verge_ads_delivery_mode' === $key && 'auto-review' === $case ? 'auto_overlays' : $default; }
function is_singular( $type = '' ) { global $case; return ! in_array( $case, array( 'home', 'archive' ), true ) && ( '' === $type || ( 'games' === $case ? 'games' : 'post' ) === $type ); }
function is_front_page() { global $case; return 'home' === $case; }
function is_home() { return is_front_page(); }
function is_feed() { return false; } function is_404() { return false; } function is_preview() { return false; }
function post_password_required() { return false; } function wp_doing_ajax() { return false; }
function is_page_template() { return false; } function is_search() { return false; } function is_author() { return false; } function is_tag() { return false; }
function is_post_type_archive() { return false; } function is_archive() { global $case; return 'archive' === $case; }
function get_queried_object_id() { global $case; return 'zero-id' === $case ? 0 : 42; }
/* Deliberately different: header runs before the main loop, and a prior loop may exist. */
function get_the_ID() { return 999; }
function go_verge_v7_post_content_type( $id ) {
	global $case;
	$GLOBALS['masthead_type_ids'][] = $id;
	if ( in_array( $case, array( 'review', 'review-breakpoint', 'review-mobile-disabled', 'auto-review' ), true ) ) { return 'review'; }
	if ( in_array( $case, array( 'critica', 'especial' ), true ) ) { return $case; }
	if ( 'guide' === $case ) { return 'guia'; }
	if ( in_array( $case, array( 'news', 'news-stale-review', 'home', 'archive', 'games' ), true ) ) { return 'noticia'; }
	return '';
}
function go_verge_specials_get_for_post( $id ) { global $case; return 'pack' === $case && 42 === $id ? array( 'id' => 'custom' ) : null; }
function go_verge_is_review_post( $id ) { global $case; return 42 === $id && in_array( $case, array( 'legacy-review', 'news-stale-review' ), true ); }
function go_verge_post_is_critique( $id ) { global $case; return 42 === $id && 'legacy-critica' === $case; }
function go_verge_post_is_special( $id ) { global $case; return 42 === $id && 'legacy-special' === $case; }
function go_verge_ads_requires_theme_consent_gate() { return false; }
function go_verge_adsense_topscroll_config() { return array(); }
if ( 'review-mobile-disabled' === $case ) { define( 'GO_VERGE_ADS_MASTHEAD_MOBILE', false ); }
add_filter( 'go_verge_ads_config', function ( $config ) use ( $desktop_min ) { $config['breakpoints']['desktop_min'] = $desktop_min; return $config; } );
foreach ( array( 'mode', 'config', 'context', 'renderer', 'loader' ) as $module ) { require_once GO_VERGE_DIR . '/inc/ads/' . $module . '.php'; }
$placement = 'home' === $case ? 'home-masthead' : 'site-masthead';
$unit = go_verge_adsense_unit_config( $placement );
$html = go_verge_adsense_unit_markup( $placement );
$options = array();
if ( preg_match( '/document\.currentScript,(\{[^;]+\})\);/', $html, $match ) ) { $options = json_decode( $match[1], true ); }
if ( in_array( '--json', $argv, true ) ) {
	echo wp_json_encode( array( 'case' => $case, 'restricted' => $restricted, 'desktopMin' => $desktop_min, 'placement' => $placement, 'unit' => $unit, 'options' => $options, 'html' => $html ) );
	exit;
}
go_test_section( 'Masthead: ' . $case );
$legacy_auto_preference = 'auto-review' === $case;
$media = $restricted ? '(max-width:' . ( $desktop_min - 1 ) . 'px)' : ( 'home' === $case ? '(min-width:1101px)' : '' );
if ( 'review-mobile-disabled' === $case ) { $media = '(min-width:768px) and ' . $media; }
if ( $legacy_auto_preference ) {
	go_test_equals( 'manual_overlays', go_verge_ads_delivery_mode(), 'Retired Auto preference cannot suppress manual Masthead delivery' );
}
go_test_equals( $media, $options['media'] ?? '', 'Runtime media eligibility follows format and effective breakpoint' );
go_test_equals( $restricted, false !== strpos( $html, '@media(min-width:' . $desktop_min . 'px)' ), 'Only restricted Masthead emits initial desktop reservation guard' );
if ( $restricted ) {
	go_test_ok( false !== strpos( $html, '.go-ad-slot--site-masthead:not([data-go-ad-requested="1"])' ), 'CSS guard excludes requested creatives after resize' );
	go_test_ok( false !== strpos( $html, 'display:none;min-block-size:0;margin-block:0;padding-block:0' ), 'Ineligible initial wrapper has no desktop space' );
}
go_test_equals( 1, substr_count( $html, '<template data-go-ad-pending>' ), 'Provider node starts inert in both mobile and desktop HTML' );
go_test_equals( '3572313419', $unit['slot'], 'Reporting slot is unchanged' );
go_test_equals( '', go_verge_adsense_unit_markup( $placement ), 'Duplicate renderer call stays deduplicated' );
foreach ( array( 'article-a1', 'sidebar-desktop', 'article-hero-overlay' ) as $other ) {
	go_test_ok( empty( go_verge_adsense_unit_config( $other )['max_viewport'] ), 'Other placement unchanged: ' . $other );
}
go_test_ok( ! in_array( 999, $GLOBALS['masthead_type_ids'] ?? array(), true ), 'Classification never reads a stale loop ID' );
if ( in_array( $case, array( 'home', 'archive', 'games', 'zero-id' ), true ) ) {
	go_test_equals( array(), $GLOBALS['masthead_type_ids'] ?? array(), 'Non-post/zero-ID context never runs editorial classification' );
}
ob_start(); go_verge_ads_print_loader(); go_verge_ads_print_loader(); $loader = ob_get_clean();
go_test_equals( 1, substr_count( $loader, '<script async src=' ), 'The single official loader remains available' );
go_test_equals( 'on', go_verge_ads_config()['account_formats']['anchor'], 'Anchor target preserved' );
go_test_equals( 'on', go_verge_ads_config()['account_formats']['vignette'], 'Vignette target preserved' );
