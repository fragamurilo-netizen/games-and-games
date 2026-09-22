<?php
/** Real planner/renderer integration: emitted inventory, claims and byte offsets. */
if ( 'cli' !== PHP_SAPI ) { exit; }
if ( ! isset( $argv[1] ) ) {
	$failed = 0;
	foreach ( array( 'normal', 'disabled', 'context', 'duplicate', 'preclaimed', 'all-disabled', 'reserve', 'reserve-disabled', 'primary-disabled-with-reserve' ) as $scenario ) {
		passthru( escapeshellarg( PHP_BINARY ) . ' ' . escapeshellarg( __FILE__ ) . ' ' . escapeshellarg( $scenario ), $status );
		if ( 0 !== $status ) { $failed++; }
	}
	exit( $failed ? 1 : 0 );
}
require_once __DIR__ . '/bootstrap.php';
$scenario = $argv[1];
function is_singular( $type = '' ) { return '' === $type || 'post' === $type; }
function go_verge_ads_is_monetizable_request() { return true; }
function go_verge_ads_document_context() { return 'single_post'; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return true; }
function go_verge_ads_unit_matches_context( $unit ) {
	return in_array( 'single_post', (array) ( $unit['templates'] ?? array() ), true );
}
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
$has_reserves = in_array( $scenario, array( 'reserve', 'reserve-disabled', 'primary-disabled-with-reserve' ), true );
$paragraph = '<p>' . implode( ' ', array_fill( 0, 70, 'conteudo' ) ) . '.</p>';
$content = str_repeat( $paragraph, $has_reserves ? 8 : 14 );
$plan = go_verge_ads_plan_article( $content, 'news' );
$all = array_merge( $plan['prime'] ? array( $plan['prime'] ) : array(), $plan['selected'], $plan['reserves'] );
usort( $all, static function ( $a, $b ) { return $a['position'] <=> $b['position']; } );
$positions = array();
$primary_names = array();
$reserve_names = array();
foreach ( $all as $candidate ) {
	$positions[ $candidate['placement'] ] = $candidate['position'];
	if ( ! empty( $candidate['fallback'] ) ) { $reserve_names[] = $candidate['placement']; }
	else { $primary_names[] = $candidate['placement']; }
}
$excluded = array();
if ( in_array( $scenario, array( 'disabled', 'context', 'preclaimed' ), true ) ) { $excluded[] = 'article-a2'; }
if ( 'duplicate' === $scenario ) { $excluded[] = 'article-a3'; }
if ( 'all-disabled' === $scenario ) { $excluded = array_keys( $positions ); }
if ( 'reserve-disabled' === $scenario ) { $excluded[] = $reserve_names[0]; }
if ( 'primary-disabled-with-reserve' === $scenario ) { $excluded = $primary_names; }
add_filter( 'go_verge_ads_config', static function ( $config ) use ( $scenario, $excluded ) {
	if ( 'context' === $scenario ) { $config['inventory']['article-a2']['templates'] = array( 'home' ); }
	elseif ( 'duplicate' === $scenario ) { $config['inventory']['article-a3']['slot'] = $config['inventory']['article-a2']['slot']; }
	elseif ( 'preclaimed' !== $scenario ) {
		foreach ( $excluded as $placement ) { $config['inventory'][ $placement ]['enabled'] = false; }
	}
	return $config;
} );
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
/* Optional CLI-only baseline source proves this regression before the patch. */
require_once getenv( 'GO_TEST_COMPOSER_SOURCE' ) ?: GO_VERGE_DIR . '/inc/ads/composer.php';
$claimed = '';
if ( 'preclaimed' === $scenario ) { $claimed = go_verge_adsense_unit_markup( 'article-a2' ); }
$out = go_verge_ads_compose_article_inventory( $content );
$public = $GLOBALS['go_verge_ads_article_plan_public'];
$host_pattern = '~\n<aside\b[^>]*data-go-ad-placement="(article-(?:prime|a[1-6]))"[^>]*>[\s\S]*?</aside>\n~';
preg_match_all( $host_pattern, $out, $hosts, PREG_OFFSET_CAPTURE );
$actual = array_map( static function ( $match ) { return $match[0]; }, $hosts[1] );
$expected = array_values( array_diff( array_keys( $positions ), $excluded ) );
$expected_primary = count( array_diff( $primary_names, $excluded ) );
$expected_reserves = count( array_diff( $reserve_names, $excluded ) );
$expected_capacity = min( (int) $plan['totalCapacity'], count( $expected ) );
go_test_section( 'Composer actual inventory: ' . $scenario );
go_test_equals( $expected, $actual, 'Only accepted units survive, in editorial order; earlier duplicate wins' );
go_test_equals( $expected_primary, (int) $public['planned-body'], 'Primary budget counts emitted primary hosts' );
go_test_equals( count( $actual ), (int) $public['rendered-body'], 'Rendered telemetry equals actual hosts' );
go_test_equals( $expected_reserves, (int) $public['reserve-body'], 'Reserve telemetry counts emitted reserves' );
go_test_equals( $expected_capacity, (int) $public['body-capacity'], 'Expansion never reports capacity above emitted hosts or original ceiling' );
go_test_equals( (int) $plan['ladderCapacity'], (int) $public['ladder-capacity'], 'Original word/type ladder remains unchanged' );
go_test_equals( (int) $plan['headroom'], (int) $public['headroom'], 'Structural headroom remains unchanged' );
go_test_equals( $content, preg_replace( $host_pattern, '', $out ), 'Removing generated hosts recovers the exact original editorial bytes' );
go_test_equals( $out, go_verge_ads_compose_article_inventory( $out ), 'A second composer call is idempotent' );
preg_match_all( '/data-ad-slot="([^"]+)"/', $claimed . $out, $slots );
go_test_equals( count( $slots[1] ), count( array_unique( $slots[1] ) ), 'Preclaimed and body markup never repeat a provider identity' );
go_test_ok( false === strpos( $out, '.push(' ), 'PHP generation does not request a real advertisement' );
if ( $has_reserves ) { go_test_ok( count( $reserve_names ) > 0, 'Fixture exercises a real planner reserve' ); }
foreach ( $hosts[0] as $index => $host ) {
	$placement = $actual[ $index ];
	$prefix = preg_replace( $host_pattern, '', substr( $out, 0, $host[1] ) );
	go_test_equals( $positions[ $placement ], strlen( $prefix ), $placement . ': original editorial byte position preserved' );
	foreach ( array( 'planned-count' => $expected_primary, 'rendered-count' => count( $actual ), 'body-capacity' => $expected_capacity ) as $key => $value ) {
		go_test_ok( false !== strpos( $host[0], 'data-go-ad-' . $key . '="' . $value . '"' ), $placement . ': ' . $key . ' agrees with article root' );
	}
	$reserve_flag = in_array( $placement, $reserve_names, true ) ? 1 : 0;
	go_test_ok( false !== strpos( $host[0], 'data-go-ad-fallback-reserve="' . $reserve_flag . '"' ), $placement . ': reserve role unchanged' );
	go_test_ok( false !== strpos( $host[0], '<template data-go-ad-pending><ins ' ), $placement . ': provider element remains inert' );
	preg_match( '/data-go-ad-options="([^"]+)"/', $host[0], $encoded );
	$options = json_decode( html_entity_decode( $encoded[1] ?? '', ENT_QUOTES, 'UTF-8' ), true );
	go_test_equals( true, $options['gate'] ?? null, $placement . ': consent gate preserved' );
	go_test_equals( go_verge_ads_unit_media_query( go_verge_adsense_unit_config( $placement ) ), $options['media'] ?? null, $placement . ': device eligibility unchanged' );
}
