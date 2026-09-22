<?php
/**
 * The body ladder follows the contract, not a compiled-in number.
 *
 * Seven was never a rule about reading or density — it was how many body units
 * the account happened to have (P1 + A1..A6), written as a literal in six
 * places. So creating A7 in AdSense and declaring it changed nothing.
 *
 * This suite runs with A7 and A8 configured and proves three things: the
 * ceiling follows the contract, the extra rungs are reached only by articles
 * long enough to have earned them, and a gap in the ladder never hands a
 * candidate a placement id that renders nothing.
 */
if ( 'cli' !== PHP_SAPI ) { exit; }

/*
 * Configured BEFORE the contract loads, the way wp-config.php would.
 *
 * The gap case needs a DIFFERENT set of constants in the same file, and
 * constants cannot be redefined, so that case runs as a child process.
 */
$go_ladder_gap = '1' === (string) getenv( 'GO_TEST_LADDER_GAP' );
if ( $go_ladder_gap ) {
	/* A8 declared, A7 blanked: a misconfiguration, not a longer ladder. An empty
	 * constant is how a publisher rolls one rung back without editing the theme,
	 * so this is the real shape of the mistake, not an artificial one. */
	define( 'GO_VERGE_ADS_ARTICLE_A7_SLOT', '' );
	define( 'GO_VERGE_ADS_ARTICLE_A8_SLOT', '2222222222' );
} else {
	define( 'GO_VERGE_ADS_ARTICLE_A7_SLOT', '1111111111' );
	define( 'GO_VERGE_ADS_ARTICLE_A8_SLOT', '2222222222' );
}

require_once __DIR__ . '/bootstrap.php';
function go_verge_ads_unit_matches_context( $unit ) { return true; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return false; }
function go_verge_adsense_topscroll_config() { return array(); }
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

if ( $go_ladder_gap ) {
	/* Child process: A8 exists, A7 does not. The planner names placements
	 * article-a1..aN in reading order, so counting "the highest rung declared"
	 * would hand a candidate the id article-a7 — which renders nothing, and the
	 * opportunity is lost in silence. Only the unbroken prefix may count. */
	go_test_section( 'A gap in the ladder is a misconfiguration, not a longer ladder' );
	$gap_inventory = go_verge_ads_inventory();
	go_test_equals( '', (string) $gap_inventory['article-a7']['slot'], 'A7 really is absent in this process' );
	go_test_ok( ! empty( $gap_inventory['article-a8']['enabled'] ), 'A8 really is declared in this process' );
	go_test_equals( 7, go_verge_ads_planner_contract_capacity(), 'The ceiling stops at the break, ignoring the orphaned A8' );
	go_test_equals( 7, go_verge_ads_planner_capacity_from_words( 12000 ), 'A very long article is clamped to the unbroken ladder' );
	return;
}

go_test_section( 'The ceiling is read from the contract' );
go_test_equals( 9, go_verge_ads_planner_contract_capacity(), 'A1..A8 configured means a ceiling of nine, Prime included' );

$inventory = go_verge_ads_inventory();
foreach ( array( 'article-a7', 'article-a8' ) as $key ) {
	go_test_ok( ! empty( $inventory[ $key ]['enabled'] ), $key . ' is enabled once its unit id exists' );
	go_test_equals( 'responsive', (string) $inventory[ $key ]['sizing'], $key . ' is the same Display product as A1..A6' );
	go_test_equals( 'auto', (string) $inventory[ $key ]['format'], $key . ' requests data-ad-format auto' );
	go_test_equals( 'deep', (string) $inventory[ $key ]['measurement_tier'], $key . ' is deep: it must never outrank a shallower position' );
}

go_test_section( 'Only articles long enough to have earned it reach the new rungs' );
$ladder = static function ( $words, $type = '' ) {
	return go_verge_ads_planner_capacity_from_words( $words, $type );
};

/* Everything below 1200 words is untouched by this change. */
go_test_equals( 0, $ladder( 200 ), 'A tiny brief stays ad-free in the body' );
go_test_equals( 1, $ladder( 260 ), '260 words: one opportunity' );
go_test_equals( 2, $ladder( 300 ), '300 words: two' );
go_test_equals( 3, $ladder( 500 ), '500 words: three' );
go_test_equals( 4, $ladder( 600 ), '600 words: four' );
go_test_equals( 5, $ladder( 800 ), '800 words: five' );
go_test_equals( 6, $ladder( 1000 ), '1000 words: six' );

/* The curve continues instead of ending. */
go_test_equals( 7, $ladder( 1200 ), '1200 words: seven, exactly as before' );
go_test_equals( 7, $ladder( 1799 ), '1799 words: still seven' );
go_test_equals( 8, $ladder( 1800 ), '1800 words: the eighth rung opens' );
go_test_equals( 8, $ladder( 2599 ), '2599 words: still eight' );
go_test_equals( 9, $ladder( 2600 ), '2600 words: the ninth rung opens' );
go_test_equals( 9, $ladder( 12000 ), 'A very long guide is still capped by the contract' );

go_test_section( 'The format bump still cannot exceed the contract' );
go_test_equals( 9, $ladder( 2600, 'guide' ), 'A long guide cannot be pushed past the ceiling' );
go_test_equals( 9, $ladder( 12000, 'ranking' ), 'Neither can a long ranking' );
go_test_ok( $ladder( 600, 'guide' ) > $ladder( 600, 'news' ), 'A guide still earns its bump in the middle of the curve' );
go_test_equals( $ladder( 200, 'guide' ), $ladder( 200, 'news' ), 'The bump never reaches a brief' );

go_test_section( 'A gap in the ladder, in a child process with A8 but no A7' );
$php  = defined( 'PHP_BINARY' ) && PHP_BINARY ? PHP_BINARY : 'php';
$cmd  = 'GO_TEST_LADDER_GAP=1 ' . escapeshellarg( $php ) . ' ' . escapeshellarg( __FILE__ ) . ' 2>&1';
$out  = (string) shell_exec( $cmd );
go_test_ok( false !== strpos( $out, '0 falharam' ), 'The gap case passes in its own process', trim( $out ) );
go_test_ok( false === strpos( $out, 'FALHA:' ), 'The gap case reports no failure', trim( $out ) );

go_test_section( 'Density is not what changed' );
$rules = go_verge_ads_delivery_rules();
go_test_equals( 3, (int) $rules['mobile']['max_units_in_window'], 'The per-window unit cap is untouched' );
go_test_equals( 0.45, (float) $rules['mobile']['max_local_ad_ratio'], 'The local ad ratio is untouched' );
go_test_equals( 0.45, (float) $rules['mobile']['max_ad_to_content_ratio'], 'The whole-article ratio is untouched' );
go_test_equals( 240, (int) $rules['mobile']['min_gap_px'], 'The anti-stacking floor is untouched' );
