<?php
/** CLI fixture: export the actual PHP-to-browser delivery contract. */
if ( 'cli' !== PHP_SAPI ) { http_response_code( 403 ); exit; }
define( 'GO_TEST_FIXTURE_EXPORT', true );
require_once __DIR__ . '/bootstrap.php';
function go_verge_ads_unit_matches_context( $unit ) { return true; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return false; }
function go_verge_adsense_topscroll_config() { return array(); }

require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/economics.php';
require_once GO_VERGE_DIR . '/inc/ads/yield.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
$units = array();
foreach ( go_verge_ads_config()['inventory'] as $key => $unit ) {
    if ( in_array( '--home', $argv, true ) ? 'home-masthead' !== $key : 'home-masthead' === $key ) { continue; }
    if ( empty( $unit['enabled'] ) ) { continue; }
    $markup = go_verge_adsense_unit_markup( $key );
    if ( preg_match( '/document\.currentScript,(\{[^;]+\})\);/', $markup, $match ) ) {
        $units[ $key ] = array( 'unit' => $unit, 'options' => json_decode( $match[1], true ), 'markup' => $markup );
    }
}
echo json_encode( array( 'config' => go_verge_ads_yield_config(), 'units' => $units ), JSON_UNESCAPED_SLASHES );
