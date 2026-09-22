<?php
/** Initial-page escrow for feed continuation; no network or provider execution. */
if ( 'cli' !== PHP_SAPI ) { exit; }
if ( ! isset( $argv[1] ) ) {
	$failed = 0;
	foreach ( array( 'home', 'category-hero', 'latest', 'exhausted', 'ajax', 'disabled', 'duplicate', 'rollback', 'no-root',
		'hub-default', 'hub-no-hero', 'hub-zero-ids', 'hub-page-two', 'hub-desk-page-two', 'hub-query-page-two', 'hub-ajax', 'hub-hooks-repeated', 'hub-disabled-first' ) as $scenario ) {
		passthru( escapeshellarg( PHP_BINARY ) . ' ' . escapeshellarg( __FILE__ ) . ' ' . escapeshellarg( $scenario ), $status );
		if ( 0 !== $status ) { $failed++; }
	}
	exit( $failed ? 1 : 0 );
}
require_once __DIR__ . '/bootstrap.php';
$scenario = $argv[1];
$context = in_array( $scenario, array( 'category-hero', 'exhausted' ), true ) ? 'category' : ( 'latest' === $scenario ? 'latest' : ( 0 === strpos( $scenario, 'hub-' ) ? 'editorial_page' : 'home' ) );
$GLOBALS['go_test_listing_context'] = $context;
$GLOBALS['go_test_listing_ajax'] = in_array( $scenario, array( 'ajax', 'hub-ajax' ), true );
$GLOBALS['go_test_listing_desk_page'] = 'hub-desk-page-two' === $scenario ? 2 : 1;
$GLOBALS['go_test_listing_query_page'] = 'hub-query-page-two' === $scenario ? 2 : 1;
function wp_doing_ajax() { return $GLOBALS['go_test_listing_ajax']; }
function get_query_var( $key, $fallback = '' ) { return 'paged' === $key ? $GLOBALS['go_test_listing_query_page'] : $fallback; }
function go_verge_desk_format_context() { return array( 'page' => $GLOBALS['go_test_listing_desk_page'] ); }
function go_verge_ads_document_context() { return $GLOBALS['go_test_listing_context']; }
function go_verge_ads_is_monetizable_request() { return true; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return true; }
function go_verge_ads_unit_matches_context( $unit ) {
	return in_array( go_verge_ads_document_context(), (array) ( $unit['templates'] ?? array() ), true );
}
if ( 'rollback' === $scenario ) { define( 'GO_VERGE_ADS_LISTING_CONTINUATION_ENABLED', false ); }
add_filter( 'go_verge_ads_config', static function ( $config ) use ( $scenario ) {
	if ( 'disabled' === $scenario ) { $config['inventory']['listing-f4']['enabled'] = false; }
	if ( 'duplicate' === $scenario ) { $config['inventory']['listing-f4']['slot'] = $config['inventory']['listing-f3']['slot']; }
	if ( 'hub-disabled-first' === $scenario ) { $config['inventory']['listing-f1']['enabled'] = false; }
	return $config;
} );
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
require_once GO_VERGE_DIR . '/inc/ads/composer.php';

go_test_section( 'Listing continuation: ' . $scenario );
$root = 'no-root' === $scenario ? '' : go_verge_ads_listing_root_attributes();
if ( 'no-root' !== $scenario ) {
	go_test_equals( '', go_verge_ads_listing_root_attributes(), 'A second initial root is never established' );
}
if ( ! $GLOBALS['go_test_listing_ajax'] && 'no-root' !== $scenario ) {
	go_test_ok( false !== strpos( $root, 'data-go-ad-listing-root="1"' ), 'The initial feed receives the explicit marker' );
}
ob_start();
if ( in_array( $scenario, array( 'category-hero', 'exhausted' ), true ) ) {
	go_verge_ads_render_archive_hero_unit();
	ob_start(); go_verge_ads_render_archive_hero_unit(); $repeat_hero = ob_get_clean();
	go_test_equals( '', $repeat_hero, 'Repeated after-hero hook cannot consume another pool unit' );
}
if ( 0 === strpos( $scenario, 'hub-' ) ) {
	$hero_ids = 'hub-no-hero' === $scenario ? array() : ( 'hub-zero-ids' === $scenario ? array( 0, 0 ) : array( 42 ) );
	go_verge_ads_render_editorial_hub_hero_unit( 'technology', $hero_ids, 'hub-page-two' === $scenario ? 2 : 1 );
	if ( 'hub-hooks-repeated' === $scenario ) {
		ob_start();
		go_verge_ads_render_editorial_hub_hero_unit( 'technology', $hero_ids, 1 );
		go_verge_ads_render_archive_hero_unit();
		$repeated_hub = (string) ob_get_clean();
		go_test_equals( '', $repeated_hub, 'Repeated hub and archive hooks never consume another pool identity' );
	}
}
$rows = 'exhausted' === $scenario ? 18 : ( 'latest' === $scenario ? 15 : 10 );
$GLOBALS['go_test_listing_rows'] = $rows;
for ( $i = 0; $i < $rows; $i++ ) { go_verge_ads_maybe_render_listing_unit(); }
$initial = (string) ob_get_clean();
ob_start(); go_verge_ads_render_listing_continuation(); $manifest = (string) ob_get_clean();
ob_start(); go_verge_ads_render_listing_continuation(); $repeat = (string) ob_get_clean();
go_test_equals( '', $repeat, 'Footer repeat never produces another reserve manifest' );

$expected = array( 'home' => array( 12, 15 ), 'category-hero' => array( 11, 15 ), 'latest' => array( 19 ),
	'exhausted' => array(), 'ajax' => array(), 'disabled' => array( 12 ), 'duplicate' => array( 12 ),
	'rollback' => array(), 'no-root' => array(), 'hub-default' => array( 11, 15 ),
	/* No after-hero unit was spent, so F3 is still unclaimed at footer time and
	 * keeps its own scheduled row instead of being consumed and discarded. */
	'hub-no-hero' => array( 11, 15, 19 ), 'hub-zero-ids' => array( 11, 15, 19 ), 'hub-page-two' => array( 11, 15, 19 ),
	'hub-desk-page-two' => array( 11, 15, 19 ), 'hub-query-page-two' => array( 11, 15, 19 ), 'hub-ajax' => array(),
	'hub-hooks-repeated' => array( 11, 15 ), 'hub-disabled-first' => array( 11 ) );
preg_match_all( '/data-go-listing-after="([0-9]+)"/', $manifest, $after );
go_test_equals( $expected[ $scenario ], array_map( 'intval', $after[1] ), 'Only future scheduled rows receive the remaining pool ranks' );
preg_match_all( '/data-ad-slot="([0-9]+)"/', $initial . $manifest, $slots );
go_test_equals( count( $slots[1] ), count( array_unique( $slots[1] ) ), 'Initial units and escrow never duplicate a provider ID' );
go_test_ok( count( $slots[1] ) <= 5, 'The document never exceeds its five existing listing identities' );
go_test_ok( false === strpos( $manifest, '.push(' ), 'Escrow code never pushes a provider request' );

if ( $expected[ $scenario ] ) {
	go_test_equals( count( $expected[ $scenario ] ), substr_count( $manifest, '<template data-go-listing-reserve ' ), 'Every deferred host lives in an outer inert template' );
	preg_match_all( '/data-go-ad-placement="([^"]+)"/', $manifest, $placements );
	go_test_ok(
		! array_diff( $placements[1], array( 'listing-f1', 'listing-f2', 'listing-f3', 'listing-f4', 'listing-f5' ) ),
		'Continuation recovers pool identities only'
	);
	/* The escrowed rows must be the EARLIEST future scheduled rows. A gap would
	 * mean a rank was taken from the pool and then thrown away, which is exactly
	 * the loss the F4/F5-only filter used to cause. */
	$future_rows = array_values( array_filter(
		go_verge_ads_listing_schedule( $context ),
		static function ( $row ) use ( $context ) { return $row > $GLOBALS['go_test_listing_rows']; }
	) );
	go_test_equals(
		array_slice( $future_rows, 0, count( $expected[ $scenario ] ) ),
		$expected[ $scenario ],
		'Recovered hosts fill the earliest future rows, never skipping one'
	);
	preg_match_all( '/data-go-ad-options="([^"]+)"/', $manifest, $options );
	foreach ( $options[1] as $raw ) {
		$parsed = json_decode( html_entity_decode( $raw, ENT_QUOTES, 'UTF-8' ), true );
		go_test_ok( is_array( $parsed ) && true === $parsed['gate'], 'Serialized mount options preserve the consent gate' );
		go_test_equals( 'deep', $parsed['tier'], 'Continuation preserves the configured delivery tier' );
	}
}
if ( $GLOBALS['go_test_listing_ajax'] ) {
	go_test_equals( '', $initial . $manifest, 'AJAX remains free of advertising markup' );
	go_test_equals( 0, go_verge_ads_listing_state( $context )['cursor'], 'AJAX never advances the document pool' );
}
if ( in_array( $scenario, array( 'hub-no-hero', 'hub-zero-ids', 'hub-page-two', 'hub-desk-page-two', 'hub-query-page-two', 'hub-ajax' ), true ) ) {
	go_test_ok( false === strpos( $initial, 'editorial_page-after-hero' ), 'Hub boundary requires a real hero and the effective first document page' );
	go_test_ok( ! go_verge_ads_listing_state( $context )['hero'], 'An ineligible hub never claims the after-hero boundary' );
}
if ( in_array( $scenario, array( 'hub-default', 'hub-hooks-repeated', 'hub-disabled-first' ), true ) ) {
	go_test_equals( 1, substr_count( $initial, 'data-go-ad-surface="editorial_page-after-hero"' ), 'Normal hub integration emits one after-hero position without setup' );
	if ( 'hub-disabled-first' === $scenario ) {
		go_test_ok( false === strpos( $initial, 'data-go-ad-placement="listing-f1"' ), 'Disabled F1 is not reintroduced at the normal hub boundary' );
		go_test_ok( false !== strpos( $initial, 'data-go-ad-placement="listing-f2"' ), 'The first valid pool identity serves the hub boundary' );
	}
}
