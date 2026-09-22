<?php
/** Listing fallback regression: real inventory + renderer; no provider requests. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';

$GLOBALS['go_test_listing_context'] = 'category';
$GLOBALS['go_test_listing_ajax'] = false;
function wp_doing_ajax() { return $GLOBALS['go_test_listing_ajax']; }
function go_verge_ads_document_context() { return $GLOBALS['go_test_listing_context']; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return true; }
function go_verge_ads_unit_matches_context( $unit ) {
	return in_array( go_verge_ads_document_context(), (array) ( $unit['templates'] ?? array() ), true );
}

add_filter( 'go_verge_ads_config', static function ( $config ) {
	$config['inventory']['listing-f1']['enabled'] = false;
	$config['inventory']['listing-f2']['templates'] = array( 'home' );
	/* Simulates a misconfigured override reusing an identity already emitted. */
	$config['inventory']['listing-f4']['slot'] = $config['inventory']['listing-f3']['slot'];
	return $config;
} );
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
require_once GO_VERGE_DIR . '/inc/ads/composer.php';

function go_test_listing_render( $index ) {
	ob_start();
	$result = go_verge_ads_render_listing_unit( 'audit', $index );
	return array( $result, (string) ob_get_clean() );
}

go_test_section( 'Disabled/context-ineligible listing units do not consume a host' );
list( $first_result, $first ) = go_test_listing_render( 3 );
go_test_ok( $first_result, 'First structural host renders a unit after F1/F2 rejection' );
go_test_ok( false !== strpos( $first, 'data-go-ad-placement="listing-f3"' ), 'F3 occupies the first eligible host' );
go_test_equals( 1, substr_count( $first, 'data-go-ad-placement=' ), 'One host emits exactly one placement' );
go_test_ok( false !== strpos( $first, 'data-go-ad-listing-index="3"' ), 'Diagnostic row remains the original structural row' );
go_test_ok( false !== strpos( $first, '"gate":true' ), 'Consent gate remains in mount options' );
go_test_ok( false !== strpos( $first, '<template data-go-ad-pending><ins ' ), 'Provider markup remains inert until runtime eligibility' );
go_test_ok( false === strpos( $first, '.push(' ), 'Server rendering never pushes an ad request' );

go_test_section( 'Duplicate identities advance safely and the pool remains finite' );
list( $second_result, $second ) = go_test_listing_render( 7 );
go_test_ok( $second_result, 'Next host skips duplicate F4 identity and renders F5' );
go_test_ok( false !== strpos( $second, 'data-go-ad-placement="listing-f5"' ), 'F5 retains its own reporting identity' );
preg_match_all( '/data-ad-slot="([0-9]+)"/', $first . $second, $slots );
go_test_equals( count( $slots[1] ), count( array_unique( $slots[1] ) ), 'No provider slot ID repeats across hosts' );
go_test_equals( 2, count( $slots[1] ), 'Fallback adds no extra unit at either host' );
list( $third_result, $third ) = go_test_listing_render( 11 );
go_test_equals( false, $third_result, 'Exhausted pool reports no unit' );
go_test_equals( '', $third, 'Exhausted pool emits no markup' );

go_test_section( 'AJAX does not consume a fresh document cursor' );
$GLOBALS['go_test_listing_context'] = 'home';
$GLOBALS['go_test_listing_ajax'] = true;
list( $ajax_result, $ajax ) = go_test_listing_render( 3 );
go_test_equals( false, $ajax_result, 'AJAX still emits no provider units' );
go_test_equals( '', $ajax, 'AJAX markup remains empty' );
$GLOBALS['go_test_listing_ajax'] = false;
list( $home_result, $home ) = go_test_listing_render( 3 );
go_test_ok( $home_result, 'First normal home call remains eligible' );
go_test_ok( false !== strpos( $home, 'data-go-ad-placement="listing-f2"' ), 'F2 has not been consumed by AJAX or a different context' );
