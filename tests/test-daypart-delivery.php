<?php
/** Same reader and device receive the same clock-only delivery contract. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/economics.php';
require_once GO_VERGE_DIR . '/inc/ads/yield.php';

go_test_section( 'Delivery independent of an unsupported clock-only prior' );
$config = go_verge_ads_yield_config();
$profiles = $config['profiles'];
$peak = $profiles['peak'];
foreach ( array( 'mobile', 'desktop' ) as $device ) {
    $rules = $config['rules'][ $device ];
    $baseline = array(
        max( $rules['engage_scroll_vh'], $peak['engage_scroll_viewports'] ),
        max( $rules['engage_dwell_ms'], $peak['engage_dwell_ms'] ),
        $peak['lookahead_scale'],
    );
    foreach ( array( 'shoulder', 'guard' ) as $part ) {
        $profile = $profiles[ $part ];
        $effective = array(
            max( $rules['engage_scroll_vh'], $profile['engage_scroll_viewports'] ),
            max( $rules['engage_dwell_ms'], $profile['engage_dwell_ms'] ),
            $profile['lookahead_scale'],
        );
        go_test_equals( $baseline, $effective, $device . ': same effective reader gates and runway in ' . $part );
    }
    go_test_ok( $baseline[0] >= $rules['engage_scroll_vh'] && $baseline[1] >= $rules['engage_dwell_ms'], $device . ': device engagement protection remains authoritative' );
}
$hours = array();
foreach ( $config['dayparts'] as $part => $values ) {
    foreach ( $values as $hour ) { $hours[] = $hour; }
    go_test_ok( ! array_key_exists( 'request_spacing_ms', $profiles[ $part ] ), $part . ': do not emit an unused request-spacing override' );
}
sort( $hours );
go_test_equals( range( 0, 23 ), $hours, 'All 24 hours still have one diagnostic label' );
go_test_ok( $config['rules']['mobile']['request_spacing_ms'] > 0 && $config['rules']['desktop']['request_spacing_ms'] > 0, 'Actual device request pacing remains in the authoritative rule table' );
