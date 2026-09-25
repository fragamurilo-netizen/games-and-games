<?php
/**
 * Checks for the engine settings layer and the refine decision.
 *
 *   php tools/test-engine-refine.php theme
 */
require __DIR__ . '/wp-stubs.php';
$theme = rtrim( $argv[1] ?? 'theme', '/' );
define( 'GO_VERGE_DIR', $theme );
require $theme . '/inc/ads/engine-settings.php';
require $theme . '/inc/ads/engine-refine.php';

$fail = 0;
function check( $label, $ok, $detail = '' ) { global $fail; if ( ! $ok ) { $fail++; } printf( "%s %s%s\n", $ok ? 'ok  ' : 'FAIL', $label, $detail ? " ($detail)" : '' ); }

/* A day state shaped like go_verge_ads_econ_day_state(). */
function state( $hour_rpm, $hour_irpm, $hour_ipv, $normal_rpm = 3.0, $normal_irpm = 0.50, $normal_ipv = 6.0, $extra = array() ) {
	return array_replace_recursive( array(
		'available' => true, 'freshness_min' => 12,
		'day' => array( 'page_views' => 9000, 'page_rpm' => 3.1, 'impression_rpm' => 0.5, 'impressions_pv' => 6.2, 'coverage' => 0.9 ),
		'window' => array( 'page_views' => 700, 'impressions' => 700 * $hour_ipv, 'page_rpm' => $hour_rpm, 'impression_rpm' => $hour_irpm, 'impressions_pv' => $hour_ipv, 'price_signal_usable' => true ),
		'peers' => array( 'count' => 4, 'page_rpm' => $normal_rpm, 'impression_rpm' => $normal_irpm, 'impressions_pv' => $normal_ipv ),
		'projection' => array( 'page_rpm' => 3.2 ),
	), $extra );
}
$ctx = array( 'now' => time(), 'last_refine_at' => null, 'refines_today' => 0, 'viewability_today' => 0.53, 'viewability_yesterday' => 0.52 );
$s = go_verge_ads_engine_settings();

/* Defaults are the 3.53 profile. */
check( 'default body format is In-article', 'inarticle' === $s['body_format'] );
check( 'default spacing 240/300 (3.53 core ranks were exempt from 520/600)', 240 === $s['min_gap_mobile'] && 300 === $s['min_gap_desktop'] );
check( 'default multiplex off', false === $s['surface_multiplex'] );

/* Sanitizer bounds. */
$x = go_verge_ads_engine_sanitize( array( 'min_gap_mobile' => 5000, 'article_ratio' => '0,9', 'body_format' => 'weird', 'lead_mobile' => array( 'reach' => 9 ) ) );
check( 'sanitizer clamps spacing', 900 === $x['min_gap_mobile'] );
check( 'sanitizer clamps ratio (comma decimal)', 0.45 === $x['article_ratio'] );
check( 'sanitizer rejects unknown format', 'inarticle' === $x['body_format'] );
check( 'sanitizer clamps lead', 2.0 === $x['lead_mobile']['reach'] );

/* Decisions. */
$d = go_verge_ads_engine_refine_decide( state( 3.0, 0.50, 6.0 ), $s, $ctx );
check( 'normal hour holds', 'hold' === $d['status'] && 'hold' === $d['action'], $d['headline'] );

$d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6 ), $s, $ctx );
check( '11/08 pattern (price down, volume up) -> less density', 'density_down' === $d['action'] && 'apply' === $d['status'], $d['headline'] );
check( '  spacing +60', 300 === $d['next']['min_gap_mobile'] );
check( '  ratio -0.03', 0.32 === $d['next']['article_ratio'] );
check( '  lead scale -0.10', 0.9 === $d['next']['lead_scale_mobile'] );

$d = go_verge_ads_engine_refine_decide( state( 2.5, 0.50, 5.0 ), $s, $ctx );
check( '26/08 pattern (volume short, price ok) -> more supply', 'supply_up' === $d['action'], $d['headline'] );
check( '  spacing stays at its floor', 240 === $d['next']['min_gap_mobile'] );
check( '  ratio +0.03', 0.38 === $d['next']['article_ratio'] );
check( '  lead scale +0.10', 1.1 === $d['next']['lead_scale_mobile'] );

$d = go_verge_ads_engine_refine_decide( state( 2.3, 0.40, 5.8 ), $s, $ctx );
check( 'market dip (price and volume down) holds', 'hold' === $d['action'], $d['headline'] );

$d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6, 3.0, 0.5, 6.0, array( 'day' => array( 'coverage' => 0.62 ) ) ), $s, $ctx );
check( 'low coverage holds', 'hold' === $d['action'], $d['headline'] );

$d = go_verge_ads_engine_refine_decide( state( 2.7, 0.47, 5.8 ), $s, array_merge( $ctx, array( 'viewability_today' => 0.61 ) ) );
check( 'high Active View + short volume -> more supply', 'supply_up' === $d['action'], $d['headline'] );

/* Limits: repeated density_down steps stop at the refine bounds. */
$cur = $s;
for ( $i = 0; $i < 10; $i++ ) { $d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6 ), $cur, $ctx ); if ( 'apply' !== $d['status'] ) { break; } $cur = go_verge_ads_engine_sanitize( $d['next'] ); }
check( 'density_down stops at its limits', 600 === $cur['min_gap_mobile'] && 0.25 === $cur['article_ratio'] && 0.7 === $cur['lead_scale_mobile'], json_encode( array( $cur['min_gap_mobile'], $cur['article_ratio'], $cur['lead_scale_mobile'] ) ) );

/* Guards. */
$d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6, 3.0, 0.5, 6.0, array( 'freshness_min' => 95 ) ), $s, $ctx );
check( 'stale data blocks', 'blocked' === $d['status'], $d['headline'] );
$d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6, 3.0, 0.5, 6.0, array( 'day' => array( 'page_views' => 300 ) ) ), $s, $ctx );
check( 'too few page views blocks', 'blocked' === $d['status'], $d['headline'] );
$st = state( 2.6, 0.40, 6.6 ); $st['peers'] = null;
$d = go_verge_ads_engine_refine_decide( $st, $s, $ctx );
check( 'no same-hour history blocks', 'blocked' === $d['status'], $d['headline'] );
$d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6 ), $s, array_merge( $ctx, array( 'last_refine_at' => time() - 20 * 60 ) ) );
check( 'cooldown blocks', 'blocked' === $d['status'], $d['headline'] );
$d = go_verge_ads_engine_refine_decide( state( 2.6, 0.40, 6.6 ), $s, array_merge( $ctx, array( 'refines_today' => 4 ) ) );
check( 'daily cap blocks', 'blocked' === $d['status'], $d['headline'] );

/* Save, history and undo round trip. */
$before = go_verge_ads_engine_settings();
$diff = go_verge_ads_engine_save( array_merge( $before, array( 'min_gap_mobile' => 600 ) ), 'manual', 'teste' );
check( 'save records the diff', isset( $diff['min_gap_mobile'] ) && array( 240, 600 ) === $diff['min_gap_mobile'] );
check( 'save takes effect', 600 === go_verge_ads_engine_setting( 'min_gap_mobile' ) );
$h = go_verge_ads_engine_history();
check( 'history keeps the previous values', 240 === $h[0]['before']['min_gap_mobile'] );
go_verge_ads_engine_save( $h[0]['before'], 'undo', 'desfazer' );
check( 'undo restores', 240 === go_verge_ads_engine_setting( 'min_gap_mobile' ) );

/* Rule overlay. */
$rules = go_verge_ads_engine_apply_rules( array( 'mobile' => array(), 'desktop' => array(), 'governor' => array() ) );
check( 'rules carry spacing and leads', 240 === $rules['mobile']['min_gap_px'] && 1.6 === $rules['mobile']['rest_lead_vh']['reach'] && 0.35 === $rules['mobile']['max_ad_to_content_ratio'] );

echo $fail ? "\n$fail FAILED\n" : "\nall passed\n";
exit( $fail ? 1 : 0 );
