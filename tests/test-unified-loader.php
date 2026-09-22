<?php
/** The one canonical provider must remain available to manual ads and overlays. */
if ( 'cli' !== PHP_SAPI ) { exit( 1 ); }
require_once __DIR__ . '/bootstrap.php';
define( 'GO_VERGE_ADSENSE_CLIENT', 'ca-pub-3687004010207904' );
$GLOBALS['go_loader_request'] = true;
$GLOBALS['go_loader_gate'] = false;
function go_verge_ads_is_monetizable_request() { return $GLOBALS['go_loader_request']; }
function go_verge_ads_requires_theme_consent_gate() { return $GLOBALS['go_loader_gate']; }
require_once GO_VERGE_DIR . '/inc/ads/loader.php';

function go_loader_capture() {
	ob_start();
	go_verge_ads_print_loader();
	go_verge_ads_print_loader();
	return ob_get_clean();
}

/* The Node gate test executes this exact PHP-emitted script against a DOM
 * double. Creating a script in that double never performs a network request. */
if ( in_array( '--emit-gate', $argv, true ) ) {
	$GLOBALS['go_loader_gate'] = true;
	echo go_loader_capture();
	exit( 0 );
}

$tag = go_verge_ads_canonical_loader_tag();
go_test_equals( 1, substr_count( $tag, '<script ' ), 'Canonical tag contains one provider script' );
go_test_ok( false !== strpos( $tag, '?client=ca-pub-3687004010207904' ), 'Canonical tag uses the intended publisher' );
go_test_ok( false !== strpos( $tag, ' async ' ) && false !== strpos( $tag, 'crossorigin="anonymous"' ), 'Provider remains async with anonymous crossorigin' );
go_test_ok( false === strpos( $tag, 'data-ad-channel' ) && false === strpos( $tag, 'GOAdsExperiment' ), 'Canonical tag does not require audience allocation or channels' );
$html = go_loader_capture();
go_test_equals( $tag . "\n", $html, 'Repeated PHP integration prints the canonical provider only once' );
go_test_equals( false, go_verge_ads_should_print_loader(), 'Claim stops subsequent provider output' );
go_test_equals( true, go_verge_ads_block_site_kit_adsense_tag( false ), 'Site Kit duplicate tag is suppressed while the theme owns this request' );
go_test_equals( true, go_verge_ads_block_site_kit_adsense_tag( true ), 'An existing Site Kit block is preserved' );

unset( $GLOBALS['go_verge_ads_loader_claimed'] );
$GLOBALS['go_loader_request'] = false;
go_test_equals( '', go_loader_capture(), 'Nonmonetizable response has no provider bootstrap' );
go_test_equals( false, go_verge_ads_block_site_kit_adsense_tag( false ), 'Theme does not claim Site Kit ownership outside its eligible response' );
go_test_ok( empty( $GLOBALS['go_verge_ads_loader_claimed'] ), 'Ineligible response does not consume the bootstrap claim' );

$GLOBALS['go_loader_request'] = true;
add_filter( 'go_verge_ads_owns_adsense_loader', function () { return false; } );
go_test_equals( '', go_loader_capture(), 'Explicit ownership override remains respected' );
go_test_equals( false, go_verge_ads_block_site_kit_adsense_tag( false ), 'Ownership override also releases Site Kit suppression' );
unset( $GLOBALS['go_test_filters']['go_verge_ads_owns_adsense_loader'] );

$GLOBALS['go_loader_gate'] = true;
$html = go_loader_capture();
go_test_equals( 1, substr_count( $html, 'id="go-ads-consent-loader-gate"' ), 'Optional hard consent gate is emitted once across repeated integrations' );
go_test_equals( 0, preg_match_all( '/<script\b[^>]*\bsrc\s*=/i', $html ), 'Hard-gated response has no immediately fetched provider script' );
go_test_ok( false !== strpos( $html, '/pagead/js/adsbygoogle.js?client=' ), 'Hard gate retains the official provider path for manual ads and overlays' );
go_test_ok( false === strpos( $html, 'GOAdsExperiment' ) && false === strpos( $html, 'data-ad-channel' ), 'Hard gate has no experimental bootstrap or channel dependency' );
