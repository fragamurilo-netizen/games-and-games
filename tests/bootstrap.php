<?php
/**
 * CLI-only test bootstrap.
 *
 * Provides the minimum WordPress and GO AdSense Center surface the advertising
 * modules touch, so the planner and the decision authority can be exercised
 * without a WordPress install. It is never loaded by the theme.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	http_response_code( 403 );
	exit;
}

define( 'ABSPATH', dirname( __DIR__ ) . '/' );
define( 'GO_VERGE_DIR', dirname( __DIR__ ) );
define( 'GO_VERGE_URI', 'https://example.test/wp-content/themes/overdrive' );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'DAY_IN_SECONDS', 86400 );
define( 'ARRAY_A', 'ARRAY_A' );

/* ------------------------------------------------------------ WordPress stubs */

$GLOBALS['go_test_transients'] = array();
$GLOBALS['go_test_filters']    = array();
$GLOBALS['go_test_actions']    = array();

function get_transient( $key ) {
	return array_key_exists( $key, $GLOBALS['go_test_transients'] ) ? $GLOBALS['go_test_transients'][ $key ] : false;
}
function set_transient( $key, $value, $ttl = 0 ) {
	$GLOBALS['go_test_transients'][ $key ] = $value;
	return true;
}
function delete_transient( $key ) {
	unset( $GLOBALS['go_test_transients'][ $key ] );
	return true;
}
function go_test_flush_transients() {
	$GLOBALS['go_test_transients'] = array();
}

/*
 * Options, in RAM.
 *
 * Guarded: several suites declare their own option doubles BEFORE requiring
 * this bootstrap, and redeclaring one is a fatal. A suite that wants the shared
 * store sets $GLOBALS['go_test_options'] directly.
 */
$GLOBALS['go_test_options'] = array();
if ( ! function_exists( 'get_option' ) ) {
	function get_option( $key, $default = false ) {
		return array_key_exists( $key, $GLOBALS['go_test_options'] ) ? $GLOBALS['go_test_options'][ $key ] : $default;
	}
}
if ( ! function_exists( 'update_option' ) ) {
	function update_option( $key, $value, $autoload = null ) {
		$GLOBALS['go_test_options'][ $key ] = $value;
		return true;
	}
}
if ( ! function_exists( 'add_option' ) ) {
	function add_option( $key, $value, $deprecated = '', $autoload = null ) {
		if ( array_key_exists( $key, $GLOBALS['go_test_options'] ) ) { return false; }
		$GLOBALS['go_test_options'][ $key ] = $value;
		return true;
	}
}
if ( ! function_exists( 'delete_option' ) ) {
	function delete_option( $key ) { unset( $GLOBALS['go_test_options'][ $key ] ); return true; }
}

function add_filter( $hook, $callback, $priority = 10, $args = 1 ) {
	$GLOBALS['go_test_filters'][ $hook ][] = $callback;
	return true;
}
function apply_filters( $hook, $value ) {
	$extra = array_slice( func_get_args(), 2 );
	foreach ( (array) ( $GLOBALS['go_test_filters'][ $hook ] ?? array() ) as $callback ) {
		$value = call_user_func_array( $callback, array_merge( array( $value ), $extra ) );
	}
	return $value;
}
function add_action( $hook, $callback, $priority = 10, $args = 1 ) {
	$GLOBALS['go_test_actions'][ $hook ][] = $callback;
	return true;
}
function do_action( $hook ) {
	foreach ( (array) ( $GLOBALS['go_test_actions'][ $hook ] ?? array() ) as $callback ) {
		call_user_func( $callback );
	}
}
function has_filter( $hook, $callback = false ) {
	return ! empty( $GLOBALS['go_test_filters'][ $hook ] );
}

function absint( $value ) {
	return abs( (int) $value );
}
function sanitize_key( $value ) {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) );
}
function sanitize_html_class( $value ) {
	return preg_replace( '/[^A-Za-z0-9_\-]/', '', (string) $value );
}
function sanitize_text_field( $value ) {
	return trim( strip_tags( (string) $value ) );
}
function wp_unslash( $value ) {
	return $value;
}
function esc_attr( $value ) {
	return htmlspecialchars( (string) $value, ENT_QUOTES, 'UTF-8' );
}
function esc_html( $value ) {
	return htmlspecialchars( (string) $value, ENT_QUOTES, 'UTF-8' );
}
function esc_html__( $value, $domain = '' ) {
	return $value;
}
function esc_attr__( $value, $domain = '' ) {
	return $value;
}
function esc_url( $value ) {
	return (string) $value;
}
function __( $value, $domain = '' ) {
	return $value;
}
function wp_json_encode( $value, $flags = 0 ) {
	return json_encode( $value, $flags );
}
function wp_parse_args( $args, $defaults = array() ) {
	return array_merge( (array) $defaults, (array) $args );
}
function rest_url( $path = '' ) {
	return 'https://example.test/wp-json/' . ltrim( (string) $path, '/' );
}
function register_rest_route() {
	return true;
}
function rest_ensure_response( $value ) {
	return $value;
}
function is_admin() {
	return false;
}
function is_user_logged_in() {
	return ! empty( $GLOBALS['go_test_is_admin_user'] );
}
function current_user_can( $capability ) {
	return ! empty( $GLOBALS['go_test_is_admin_user'] );
}
function is_page( $value = '' ) {
	return false;
}
function is_category( $value = '' ) {
	return false;
}
function wp_timezone() {
	return new DateTimeZone( 'America/Sao_Paulo' );
}
function wp_timezone_string() {
	return 'America/Sao_Paulo';
}
function current_time( $format ) {
	return ( new DateTimeImmutable( 'now', wp_timezone() ) )->format( $format );
}

/* ------------------------------------------------------------ GOAC stubs */

/**
 * Injectable AdSense Center double.
 *
 * `$GLOBALS['go_test_goac']` carries the scenario: connection state, timezone,
 * "today", the cumulative intraday store and the per-ad-unit rows the Data Lab
 * would have collected.
 */
$GLOBALS['go_test_goac'] = array(
	'connected' => true,
	'today'     => '2026-09-20',
	'now'       => '2026-09-20 15:10:00',
	'intraday'  => array(),
	'unit_rows' => array(),
);

class GOAC_API {
	public static function is_connected() {
		return ! empty( $GLOBALS['go_test_goac']['connected'] );
	}
	public static function tz() {
		return new DateTimeZone( 'America/Sao_Paulo' );
	}
	public static function today() {
		return (string) $GLOBALS['go_test_goac']['today'];
	}
}

class GOAC_Learning {
	public static function table_rows() {
		return 'wp_goac_rows';
	}
	public static function account_key() {
		return 'testaccount';
	}
}

class GOAC_Store {
	public static function intraday() {
		return (array) $GLOBALS['go_test_goac']['intraday'];
	}
	public static function range( $from, $to ) {
		return (array) ( $GLOBALS['go_test_goac']['daily_rows'] ?? array() );
	}
	/** Mirrors the production interpolation contract exactly. */
	public static function intraday_at( array $intraday, $date, $minute ) {
		$points = isset( $intraday[ $date ] ) ? array_values( (array) $intraday[ $date ] ) : array();
		if ( ! $points ) {
			return null;
		}
		usort( $points, static function ( $a, $b ) { return $a[0] <=> $b[0]; } );
		$prev = null;
		$next = null;
		foreach ( $points as $p ) {
			if ( $p[0] <= $minute ) { $prev = $p; } else { $next = $p; break; }
		}
		$pick = null;
		if ( $prev && $next && $next[0] - $prev[0] <= 80 ) {
			$f = ( $minute - $prev[0] ) / max( 1, $next[0] - $prev[0] );
			$pick = array();
			for ( $i = 1; $i <= 4; $i++ ) { $pick[ $i ] = $prev[ $i ] + ( $next[ $i ] - $prev[ $i ] ) * $f; }
		} elseif ( $prev && $minute - $prev[0] <= 40 ) {
			$pick = $prev;
		} elseif ( $next && $next[0] - $minute <= 40 ) {
			$pick = $next;
		}
		if ( null === $pick ) {
			return null;
		}
		return array( 'earnings' => (float) $pick[1], 'page_views' => (float) $pick[2], 'impressions' => (float) $pick[3], 'clicks' => (float) $pick[4] );
	}
}

class GO_Test_WPDB {
	public function prepare( $sql ) {
		return $sql;
	}
	public function get_results( $sql, $mode = null ) {
		return (array) $GLOBALS['go_test_goac']['unit_rows'];
	}
	public function get_var( $sql ) {
		return 0;
	}
}
$GLOBALS['wpdb'] = new GO_Test_WPDB();

/* ------------------------------------------------------------ the account clock */

/*
 * The day state is clock-relative end to end: snapshot freshness, the marginal
 * window and the peer band are all measured against the account's current
 * minute. A scenario about a six-hour-old snapshot is only a stale snapshot if
 * the suite happens to run after 07:00 in São Paulo — before that, the same
 * fixture reads as perfectly fresh and the scenario silently tests nothing.
 * Pinning the minute makes those scenarios mean the same thing at every hour.
 *
 * Only the time of day is pinned. The date, and therefore the weekday the peer
 * band filters on, stays exactly what it was.
 */
$GLOBALS['go_test_clock_minute'] = null;

/**
 * Pin the account clock to a minute of day, or release it with null.
 *
 * @param int|null $minute Minute of day, 0-1439.
 */
function go_test_pin_clock( $minute ) {
	$GLOBALS['go_test_clock_minute'] = null === $minute ? null : max( 0, min( 1439, (int) $minute ) );
	go_test_flush_transients();
}

add_filter(
	'go_verge_ads_econ_now',
	static function ( $now ) {
		$minute = $GLOBALS['go_test_clock_minute'] ?? null;
		if ( null === $minute || ! $now instanceof DateTimeImmutable ) {
			return $now;
		}
		return $now->setTime( intdiv( (int) $minute, 60 ), (int) $minute % 60, 0 );
	}
);

/* ------------------------------------------------------------ scenario helpers */

/**
 * Build a cumulative intraday day from a constant per-hour rate.
 *
 * @param float $page_views_per_hour Pageviews per hour.
 * @param float $impressions_pv      Impressions per pageview.
 * @param float $impression_rpm      Revenue per 1,000 impressions.
 * @param int   $until_minute        Last snapshot minute of day.
 * @return array<int,array<int,float>>
 */
function go_test_day( $page_views_per_hour, $impressions_pv, $impression_rpm, $until_minute = 1430 ) {
	$points = array();
	for ( $minute = 0; $minute <= $until_minute; $minute += 10 ) {
		$pv  = $page_views_per_hour * ( $minute / 60 );
		$imp = $pv * $impressions_pv;
		$earn = $imp * $impression_rpm / 1000;
		$points[] = array( $minute, round( $earn, 4 ), (int) round( $pv ), (int) round( $imp ), (int) round( $imp * 0.012 ) );
	}
	return $points;
}

/**
 * A history of comparable days, so peer bands exist.
 *
 * @return array<string,array<int,array<int,float>>>
 */
function go_test_history( $days, $page_views_per_hour, $impressions_pv, $impression_rpm, $today = '2026-09-20' ) {
	$out = array();
	for ( $i = 1; $i <= $days; $i++ ) {
		$date = ( new DateTimeImmutable( $today ) )->modify( '-' . $i . ' days' )->format( 'Y-m-d' );
		$out[ $date ] = go_test_day( $page_views_per_hour, $impressions_pv, $impression_rpm, 1430 );
	}
	return $out;
}

/**
 * Per-ad-unit Data Lab rows for the seven-day economics model.
 *
 * @param array<string,array<string,float>> $spec slot => [request_rpm, impressions, requests, coverage, ctr]
 * @return array<int,array<string,mixed>>
 */
function go_test_unit_rows( array $spec ) {
	$rows = array();
	foreach ( $spec as $slot => $values ) {
		$requests    = (float) ( $values['requests'] ?? 5000 );
		$coverage    = (float) ( $values['coverage'] ?? 0.9 );
		$impressions = (float) ( $values['impressions'] ?? $requests * $coverage );
		$earnings    = (float) ( $values['request_rpm'] ?? 0.4 ) * $requests / 1000;
		$ctr         = (float) ( $values['ctr'] ?? 0.012 );
		$rows[] = array(
			'dimensions_json'         => json_encode( array( 'AD_UNIT_ID' => 'ca-pub-3687004010207904:' . $slot ) ),
			'earnings'                => $earnings,
			'impressions'             => $impressions,
			'ad_requests'             => $requests,
			'matched_requests'        => $requests * $coverage,
			'clicks'                  => $impressions * $ctr,
			'viewability_weighted'    => $impressions * (float) ( $values['viewability'] ?? 0.52 ),
			'viewability_impressions' => $impressions,
		);
	}
	return $rows;
}

/*
 * Neutralise calendar trials for every suite but the one that tests them.
 *
 * A running trial changes go_verge_ads_delivery_rules() on the days it owns, so
 * a suite that pins a published threshold would pass on a baseline day and fail
 * on an arm day. A test result that depends on the calendar is worse than no
 * test: it goes red for a reason nobody changed, and the next person learns to
 * ignore it.
 *
 * tests/test-calendar-trials.php replaces or removes this filter to exercise the
 * real declarations; tests/static-integrity.php loads the module directly with
 * its own apply_filters double and sees the shipped array untouched.
 */
add_filter(
	'go_verge_ads_trials',
	static function () {
		return array();
	}
);

/* ------------------------------------------------------------ assertions */

$GLOBALS['go_test_pass'] = 0;
$GLOBALS['go_test_fail'] = 0;
$GLOBALS['go_test_failures'] = array();

function go_test_ok( $condition, $label, $detail = '' ) {
	if ( $condition ) {
		$GLOBALS['go_test_pass']++;
		return true;
	}
	$GLOBALS['go_test_fail']++;
	$GLOBALS['go_test_failures'][] = $label . ( '' !== $detail ? ' — ' . $detail : '' );
	return false;
}
function go_test_equals( $expected, $actual, $label ) {
	return go_test_ok(
		$expected === $actual,
		$label,
		'esperado ' . var_export( $expected, true ) . ', obtido ' . var_export( $actual, true )
	);
}
function go_test_section( $title ) {
	echo "\n" . str_repeat( '-', 72 ) . "\n" . $title . "\n" . str_repeat( '-', 72 ) . "\n";
}

register_shutdown_function(
	static function () {
		if ( defined( 'GO_TEST_FIXTURE_EXPORT' ) && GO_TEST_FIXTURE_EXPORT && empty( $GLOBALS['go_test_fail'] ) ) { return; }
		$pass = (int) $GLOBALS['go_test_pass'];
		$fail = (int) $GLOBALS['go_test_fail'];
		echo "\n" . str_repeat( '=', 72 ) . "\n";
		printf( "%d asserções passaram, %d falharam\n", $pass, $fail );
		foreach ( (array) $GLOBALS['go_test_failures'] as $failure ) {
			echo '  FALHA: ' . $failure . "\n";
		}
		echo str_repeat( '=', 72 ) . "\n";
		if ( $fail > 0 ) {
			exit( 1 );
		}
	}
);
