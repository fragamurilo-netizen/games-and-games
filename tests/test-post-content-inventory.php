<?php
/**
 * Post-content inventory on a single post.
 *
 * The zone below the prose — author card, recirculation, topic bar, comments —
 * carried no advertising. It now offers the shared listing pool at three
 * editorial anchors. This exercises the real inventory, renderer and composer;
 * no provider request is made and no new ad unit is introduced.
 */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';

$GLOBALS['go_test_pc_context']   = 'single_post';
$GLOBALS['go_test_pc_singular']  = true;
$GLOBALS['go_test_pc_ajax']      = false;
$GLOBALS['go_test_pc_monetize']  = true;

function wp_doing_ajax() { return $GLOBALS['go_test_pc_ajax']; }
function go_verge_ads_document_context() { return $GLOBALS['go_test_pc_context']; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return true; }
function go_verge_ads_is_monetizable_request() { return $GLOBALS['go_test_pc_monetize']; }
function is_singular( $type = '' ) {
	if ( ! $GLOBALS['go_test_pc_singular'] ) { return false; }
	if ( '' === $type ) { return true; }
	return in_array( 'post', (array) $type, true );
}
function go_verge_ads_unit_matches_context( $unit ) {
	return $GLOBALS['go_test_pc_monetize']
		&& in_array( go_verge_ads_document_context(), (array) ( $unit['templates'] ?? array() ), true );
}

require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
require_once GO_VERGE_DIR . '/inc/ads/composer.php';

function go_test_pc_render( $anchor ) {
	ob_start();
	$result = go_verge_ads_render_post_content_unit( $anchor );
	return array( $result, (string) ob_get_clean() );
}

go_test_section( 'The listing pool reaches the article post-content zone' );

$anchors = go_verge_ads_post_content_anchors();
go_test_equals( array( 'after-author', 'after-recirculation', 'before-comments' ), $anchors, 'Three anchors are declared in reading order' );

foreach ( go_verge_ads_inventory() as $placement => $unit ) {
	if ( 0 !== strpos( $placement, 'listing-f' ) ) { continue; }
	go_test_ok(
		in_array( 'single_post', (array) ( $unit['templates'] ?? array() ), true ),
		$placement . ' declares single_post so the pool can serve the article zone'
	);
}

list( $first_result, $first ) = go_test_pc_render( 'after-author' );
go_test_ok( $first_result, 'The first anchor renders an opportunity' );
go_test_ok( false !== strpos( $first, 'data-go-ad-placement="listing-f1"' ), 'The pool hands the first anchor F1' );
go_test_ok( false !== strpos( $first, 'data-go-ad-surface="post-content-after-author"' ), 'The host reports its own diagnostic surface' );
go_test_ok( false !== strpos( $first, '<template data-go-ad-pending><ins ' ), 'Provider markup stays inert until the runtime decides' );
go_test_ok( false === strpos( $first, '.push(' ), 'Server rendering never pushes an ad request' );
go_test_equals( 1, substr_count( $first, 'data-go-ad-placement=' ), 'One anchor emits exactly one placement' );

go_test_section( 'Each anchor spends at most one unit, once' );
list( $repeat_result, $repeat ) = go_test_pc_render( 'after-author' );
go_test_equals( false, $repeat_result, 'A repeated anchor reports no unit' );
go_test_equals( '', $repeat, 'A repeated anchor emits no markup' );

list( $second_result, $second ) = go_test_pc_render( 'after-recirculation' );
go_test_ok( $second_result, 'The second anchor renders an opportunity' );
go_test_ok( false !== strpos( $second, 'data-go-ad-placement="post-content-multiplex"' ), 'The recirculation boundary prefers the Multiplex grid' );
go_test_ok( false !== strpos( $second, 'data-ad-format="autorelaxed"' ), 'It requests the documented Multiplex format' );
go_test_ok( false !== strpos( $second, 'data-ad-slot="1889487031"' ), 'It requests the publisher\x27s real Multiplex unit' );
go_test_ok( false === strpos( $second, 'data-full-width-responsive=' ), 'Multiplex never asks for full-width-responsive' );
go_test_ok( false === strpos( $second, 'data-go-ad-placement="listing-f2"' ), 'Multiplex REPLACES the pool unit here, it is not stacked on top' );
go_test_equals( 1, substr_count( $second, 'data-ad-slot=' ), 'The boundary emits exactly one unit' );

list( $third_result, $third ) = go_test_pc_render( 'before-comments' );
go_test_ok( $third_result, 'The third anchor renders an opportunity' );
go_test_ok( false !== strpos( $third, 'data-go-ad-placement="listing-f2"' ), 'The pool cursor was not spent by the Multiplex boundary' );

preg_match_all( '/data-ad-slot="([0-9]+)"/', $first . $second . $third, $slots );
go_test_equals( 3, count( $slots[1] ), 'The zone emitted exactly three provider hosts' );
go_test_ok( in_array( '1889487031', $slots[1], true ), 'One of the three is the Multiplex unit' );
go_test_equals( count( $slots[1] ), count( array_unique( $slots[1] ) ), 'No provider slot ID repeats inside the zone' );

go_test_section( 'The body ladder keeps its own pool' );
$body_slots = array();
foreach ( array( 'article-prime', 'article-a1', 'article-a2', 'article-a3', 'article-a4', 'article-a5', 'article-a6', 'article-end' ) as $placement ) {
	$unit = go_verge_adsense_unit_config( $placement );
	if ( ! empty( $unit['slot'] ) ) { $body_slots[] = (string) $unit['slot']; }
}
go_test_equals( array(), array_intersect( $body_slots, $slots[1] ), 'No post-content host reuses a body-ladder ad unit' );

go_test_section( 'Guards' );
$GLOBALS['go_test_pc_ajax'] = true;
list( $ajax_result, $ajax ) = go_test_pc_render( 'unused-anchor' );
go_test_equals( false, $ajax_result, 'AJAX emits no post-content unit' );
go_test_equals( '', $ajax, 'AJAX emits no markup' );
$GLOBALS['go_test_pc_ajax'] = false;

list( $unknown_result, $unknown ) = go_test_pc_render( 'somewhere-else' );
go_test_equals( false, $unknown_result, 'An undeclared anchor renders nothing' );
go_test_equals( '', $unknown, 'An undeclared anchor emits no markup' );

$GLOBALS['go_test_pc_singular'] = false;
$GLOBALS['go_test_pc_context']  = 'category';
list( $off_result, $off ) = go_test_pc_render( 'after-author' );
go_test_equals( false, $off_result, 'A non-single_post document renders no post-content unit' );
go_test_equals( '', $off, 'A non-single_post document emits no markup' );
$GLOBALS['go_test_pc_singular'] = true;
$GLOBALS['go_test_pc_context']  = 'single_post';

$GLOBALS['go_test_pc_monetize'] = false;
list( $blocked_result, $blocked ) = go_test_pc_render( 'after-recirculation' );
go_test_equals( false, $blocked_result, 'An unmonetizable request renders no post-content unit' );
go_test_equals( '', $blocked, 'An unmonetizable request emits no markup' );
$GLOBALS['go_test_pc_monetize'] = true;

go_test_section( 'The stacked article rail is live, and gated so it can never collide' );

$inventory = go_verge_ads_inventory();
go_test_ok( isset( $inventory['article-rail-mobile'] ), 'article-rail-mobile survives the allow-list' );

$rail = $inventory['article-rail-mobile'];
go_test_equals( '9492644884', (string) $rail['slot'], 'It serves the publisher\x27s real rail unit' );
go_test_equals( true, (bool) $rail['enabled'], 'It is enabled' );
go_test_equals( 1100, (int) $rail['max_viewport'], 'It is gated one pixel below the desktop breakpoint' );
go_test_equals( 'responsive', (string) $rail['sizing'], 'It is a Display responsive unit, like the rest of the contract' );
go_test_equals( 'auto', (string) $rail['format'], 'It requests data-ad-format auto' );

ob_start();
go_verge_render_adsense_unit( 'article-rail-mobile', array( 'tag' => 'div', 'class' => 'go-article-sidebar__ad go-article-sidebar__ad--stacked' ) );
$rail_markup = (string) ob_get_clean();
go_test_ok( false !== strpos( $rail_markup, 'data-ad-slot="9492644884"' ), 'It renders its own unit' );
go_test_ok( false !== strpos( $rail_markup, 'data-full-width-responsive="true"' ), 'It keeps full-width responsive' );
/* The gate must land on the REQUEST, not only on the display rule: a unit
 * hidden by CSS that still pushes is a request with availableWidth 0, which
 * burns the one request that slot gets on the page. */
go_test_ok( false !== strpos( $rail_markup, '&quot;media&quot;:&quot;(max-width:1100px)&quot;' ), 'The viewport gate travels with the request options' );
go_test_ok( false !== strpos( $rail_markup, '@media(min-width:1101px)' ), 'And with the display rule, so one cached document serves every user agent' );

$desktop = $inventory['sidebar-desktop'];
go_test_ok( ! empty( $desktop['desktop_only'] ), 'sidebar-desktop stays desktop-only' );
go_test_ok(
	(int) $rail['max_viewport'] < absint( go_verge_ads_config()['breakpoints']['desktop_min'] ),
	'The two rail placements can never both request in one document'
);
go_test_ok( $rail['slot'] !== $desktop['slot'], 'The stacked rail never reuses the sticky rail ad unit' );

/* The gate the renderer will put on BOTH the display rule and the request once
 * an ad unit exists. This is the part that must be right before the id is,
 * because it is what keeps one cached document correct for every user agent. */
go_test_equals( '(max-width:1100px)', go_verge_ads_unit_media_query( $rail ), 'The rail requests only below the desktop breakpoint' );
go_test_equals( '(min-width:1101px)', go_verge_ads_unit_media_query( $desktop ), 'The sticky rail requests only at and above it' );
