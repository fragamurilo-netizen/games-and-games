<?php
/** Fixed manual contract, including retired mode settings: actual PHP delivery, no network/JavaScript execution. */
if ( 'cli' !== PHP_SAPI ) { exit; }
if ( ! isset( $argv[1] ) ) {
	$failed = 0;
	foreach ( array( 'default', 'auto', 'auto-consent', 'auto-ajax', 'global-off', 'global-off-auto', 'invalid', 'constant', 'filter', 'config-filter', 'custom-id', 'bad-id', 'admin' ) as $case ) {
		passthru( escapeshellarg( PHP_BINARY ) . ' ' . escapeshellarg( __FILE__ ) . ' ' . escapeshellarg( $case ), $status );
		$failed += (int) ( 0 !== $status );
	}
	exit( $failed ? 1 : 0 );
}
require_once __DIR__ . '/bootstrap.php';
$case = $argv[1];
$GLOBALS['mode_options'] = array();
$GLOBALS['mode_purges'] = 0;
$GLOBALS['mode_styles'] = array();
$GLOBALS['mode_ajax'] = 'auto-ajax' === $case;
$GLOBALS['mode_home'] = false;
$GLOBALS['mode_gate'] = 'auto-consent' === $case;
$GLOBALS['mode_nonce'] = true;
class WP_Error { public $code; private $message; public function __construct( $code, $message ) { $this->code=$code; $this->message=$message; } public function get_error_message() { return $this->message; } }
function is_wp_error( $value ) { return $value instanceof WP_Error; }
function get_option( $key, $default = false ) { return $GLOBALS['mode_options'][ $key ] ?? $default; }
function update_option( $key, $value, $autoload = null ) { $changed = ! array_key_exists( $key, $GLOBALS['mode_options'] ) || $GLOBALS['mode_options'][ $key ] !== $value; $GLOBALS['mode_options'][ $key ] = $value; return $changed; }
function get_current_user_id() { return 9; }
function wp_doing_ajax() { return $GLOBALS['mode_ajax']; }
function is_feed() { return false; } function is_404() { return false; } function is_preview() { return false; }
function is_singular( $type = '' ) { return ! $GLOBALS['mode_home'] && in_array( $type, array( '', 'post' ), true ); }
function post_password_required() { return false; }
function is_front_page() { return $GLOBALS['mode_home']; } function is_home() { return false; }
function wp_enqueue_style( $handle ) { $GLOBALS['mode_styles'][] = $handle; }
function go_verge_asset_version( $path ) { return 'test'; }
function go_verge_ads_requires_theme_consent_gate() { return $GLOBALS['mode_gate']; }
function wp_die( $message ) { throw new RuntimeException( $message ); }
function check_admin_referer( $action ) { if ( ! $GLOBALS['mode_nonce'] ) { wp_die( 'invalid nonce' ); } }
function home_url( $path = '' ) { return 'https://example.test/' . ltrim( $path, '/' ); }
function wp_remote_get() { return $GLOBALS['mode_remote']; }
function wp_remote_retrieve_response_code( $response ) { return $response['status']; }
function wp_remote_retrieve_body( $response ) { return $response['body']; }
function admin_url( $path = '' ) { return '/wp-admin/' . $path; }
function wp_nonce_field() { echo '<input name="_wpnonce" value="test">'; }
function selected( $a, $b, $echo = true ) { $out = $a === $b ? ' selected' : ''; if ( $echo ) { echo $out; } return $out; }
add_action( 'litespeed_purge_all', function () { $GLOBALS['mode_purges']++; } );
if ( in_array( $case, array( 'auto', 'auto-consent', 'auto-ajax', 'global-off-auto' ), true ) ) { $GLOBALS['mode_options']['go_verge_ads_delivery_mode'] = 'auto_overlays'; }
if ( 'invalid' === $case ) { $GLOBALS['mode_options']['go_verge_ads_delivery_mode'] = 'hybrid'; }
if ( 'constant' === $case ) { define( 'GO_VERGE_ADS_DELIVERY_MODE', 'auto_overlays' ); }
$GLOBALS['legacy_mode_filter_calls'] = 0;
if ( 'config-filter' === $case ) { add_filter( 'go_verge_ads_config', function ( $c ) { $c['delivery_mode'] = 'auto_overlays'; $c['account_formats']['in_page'] = 'on'; $c['account_formats']['anchor'] = 'off'; $c['account_formats']['vignette'] = 'off'; return $c; } ); }
if ( 'filter' === $case ) { define( 'GO_VERGE_ADS_DELIVERY_MODE', 'manual_overlays' ); add_filter( 'go_verge_ads_delivery_mode', function () { $GLOBALS['legacy_mode_filter_calls']++; return 'auto_overlays'; } ); }
if ( in_array( $case, array( 'global-off', 'global-off-auto' ), true ) ) { define( 'GO_ADS_V3_ENABLED', false ); add_filter( 'go_verge_ads_config', function ( $c ) { $c['enabled'] = true; return $c; } ); }
if ( in_array( $case, array( 'custom-id', 'bad-id' ), true ) ) { add_filter( 'go_verge_ads_config', function ( $c ) use ( $case ) { $c['inventory']['article-a1']['slot'] = 'custom-id' === $case ? '1234567890' : 'slot-123'; return $c; } ); }
require_once GO_VERGE_DIR . '/inc/ads/mode.php';
if ( 'admin' === $case ) {
	go_test_equals( 'forbidden', go_verge_ads_save_delivery_mode( 'auto_overlays' )->code, 'Anonymous legacy save rejected' );
	$GLOBALS['go_test_is_admin_user'] = true;
	foreach ( array( 'auto_overlays', 'hybrid', array( 'manual_overlays' ) ) as $input ) {
		go_test_equals( 'fixed_manual_architecture', go_verge_ads_save_delivery_mode( $input )->code, 'Retired architecture cannot be saved' );
	}
	go_test_equals( false, go_verge_ads_save_delivery_mode( 'manual_overlays' ), 'Manual compatibility call is a no-op' );
	go_test_equals( array(), $GLOBALS['mode_options'], 'Legacy setter makes no writes' );
	go_test_equals( 0, $GLOBALS['mode_purges'], 'Legacy setter makes no purge' );
	go_test_ok( empty( $GLOBALS['go_test_actions']['admin_post_go_verge_ads_save_delivery_mode'] ), 'No mutable architecture POST endpoint registered' );
	go_test_equals( 'manual_overlays', go_verge_ads_delivery_mode(), 'Only manual architecture exists' );
	exit;
}
foreach ( array( 'config', 'context', 'renderer', 'composer', 'loader', 'topscroll', 'assets', 'health' ) as $module ) { require_once GO_VERGE_DIR . '/inc/ads/' . $module . '.php'; }
go_test_section( 'Delivery mode: ' . $case );
$config = go_verge_ads_config();
$auto = in_array( $case, array( 'auto', 'auto-consent', 'auto-ajax', 'global-off-auto', 'constant', 'filter' ), true );
$global = ! in_array( $case, array( 'global-off', 'global-off-auto' ), true );
$manual = $global;
go_test_equals( 'manual_overlays', $config['delivery_mode'], 'Legacy option/constant/filter cannot suspend manual architecture' );
go_test_equals( 'off', $config['account_formats']['in_page'], 'Fixed contract keeps in-page automatic insertion off' );
go_test_equals( 'on', $config['account_formats']['anchor'], 'Anchor target stays ON' );
go_test_equals( 'on', $config['account_formats']['vignette'], 'Vignette target stays ON' );
go_test_equals( 'off', $config['account_formats']['side_rails'], 'Official automatic side rails remain outside the contract' );
$GLOBALS['go_test_is_admin_user'] = true;
ob_start(); go_verge_ads_delivery_mode_form(); $form = ob_get_clean();
$GLOBALS['go_test_is_admin_user'] = false;
go_test_ok( false === strpos( $form, '<form' ) && false === strpos( $form, '<select' ) && false === strpos( $form, '<button' ), 'Architecture UI is status-only' );
go_test_ok( false !== strpos( $form, 'não consulta nem altera esses controles da conta' ), 'UI distinguishes local choice from account changes' );
go_test_equals( true, go_verge_ads_delivery_mode_locked(), 'Architecture is always fixed' );
go_test_equals( $manual, go_verge_ads_manual_delivery_enabled(), 'Manual eligibility independent of provider eligibility' );
$_GET['delivery_mode'] = $auto ? 'manual_overlays' : 'auto_overlays';
go_test_equals( $config['delivery_mode'], go_verge_ads_delivery_mode(), 'Public GET cannot change mode' );
ob_start(); go_verge_ads_print_loader(); go_verge_ads_print_loader(); $loader = ob_get_clean();
go_test_equals( $global, '' !== $loader, 'Provider retained under legacy settings; global kill still absolute' );
if ( $global ) {
	go_test_equals( 1, substr_count( $loader, $GLOBALS['mode_gate'] ? 'id="go-ads-consent-loader-gate"' : '<script async src=' ), 'Repeated loader call emits only once' );
	if ( $GLOBALS['mode_gate'] ) { go_test_equals( 0, preg_match_all( '/<script\b[^>]*src=/', $loader ), 'Consent gate has no eagerly fetched provider' ); }
}
$placement = $GLOBALS['mode_ajax'] ? 'listing-f1' : 'article-a1';
$markup = go_verge_adsense_unit_markup( $placement );
go_test_equals( $manual && ! $GLOBALS['mode_ajax'], '' !== $markup, 'Renderer stays manual under retired settings; global off suspends it' );
go_verge_ads_enqueue_assets();
go_test_equals( $manual, in_array( 'go-verge-ads', $GLOBALS['mode_styles'], true ), 'Manual CSS only accompanies manual mode' );
ob_start(); go_verge_ads_print_manual_runtime(); $runtime = ob_get_clean();
go_test_equals( $manual && ! $GLOBALS['mode_ajax'], '' !== $runtime, 'Legacy settings cannot suppress runtime; global off still does' );
go_test_equals( $manual && ! $GLOBALS['mode_ajax'], go_verge_adsense_topscroll_is_eligible(), 'Top Scroll respects its template and global eligibility' );
if ( ! $manual ) {
	foreach ( go_verge_ads_inventory() as $placement => $unit ) { go_test_equals( '', go_verge_adsense_unit_markup( $placement ), 'No manual markup: ' . $placement ); }
	go_test_equals( false, go_verge_ads_claim_slot( '1234567890', 'probe' ), 'Direct claim cannot consume an ID while suspended' );
	$html = '<p>Article prose untouched.</p>';
	go_test_equals( $html, go_verge_ads_compose_article_inventory( $html ), 'Composer returns exact prose without planning/reserves' );
	$GLOBALS['mode_home'] = true;
	go_test_equals( '', go_verge_ads_listing_pool_next( 'home' ), 'Pool returns no unit' );
	go_verge_ads_listing_state( 'home', array( 'cursor'=>4, 'rows'=>19, 'root'=>true ) );
	go_test_equals( 0, go_verge_ads_listing_state( 'home' )['cursor'], 'No listing cursor can be consumed' );
	go_test_equals( '', go_verge_ads_listing_root_attributes(), 'No listing root reservation' );
	ob_start(); go_verge_ads_render_archive_hero_unit(); go_verge_ads_render_editorial_hub_hero_unit( 'technology', array( 42 ), 1 ); go_verge_ads_maybe_render_listing_unit(); go_verge_ads_render_listing_continuation(); $out = ob_get_clean();
	go_test_equals( '', $out, 'Listing hooks, hub and dynamic continuation emit no hosts' );
}
if ( $GLOBALS['mode_ajax'] ) {
	go_test_equals( false, go_verge_ads_render_listing_unit(), 'AJAX keeps its no-provider-fragment contract' );
	$GLOBALS['mode_ajax'] = false; $GLOBALS['mode_home'] = true;
	go_test_equals( 'listing-f1', go_verge_ads_listing_pool_next( 'home' ), 'Retired auto preference does not disable the initial listing pool' );
	go_test_ok( '' !== go_verge_adsense_unit_markup( 'listing-f1' ), 'Initial page emits manual listing host under retired auto preference' );
}
$health = go_verge_ads_stable_inventory_health_test();
go_test_equals( 'bad-id' === $case ? 'critical' : 'good', $health['status'], 'Local inventory accepts valid custom IDs and only the fixed mode' );
go_test_equals( 'recommended', go_verge_ads_account_controls_health_test()['status'], 'Unknown account controls are pending, never a confirmed error' );
$GLOBALS['mode_options']['goac_optimization_controls'] = array( 'auto_ads'=>'on', 'anchor_ads'=>'on', 'vignette_ads'=>'on', 'side_rails_ads'=>'off', 'banner_ads'=>'off', 'find_more'=>'off', 'optimize_existing'=>'off' );
go_test_equals( 'good', go_verge_ads_account_controls_health_test()['status'], 'Aligned manual account record matches selected local mode' );
go_test_ok( false !== strpos( go_verge_ads_loader_health_test()['description'], 'não observa' ), 'Local loader check does not assert the final live HTML' );

$GLOBALS['mode_remote'] = array( 'status'=>403, 'body'=>'<title>Bot challenge</title>' );
go_test_equals( 'recommended', go_verge_ads_single_loader_health_test()['status'], 'HTTP challenge is pending evidence, not proof of missing provider' );
$GLOBALS['mode_remote'] = array( 'status'=>200, 'body'=>'<script id="go-ads-consent-loader-gate">/* deferred */</script>' );
go_test_equals( 'recommended', go_verge_ads_single_loader_health_test()['status'], 'Deferred loader without src does not falsely fail live delivery' );
$GLOBALS['mode_remote']['body'] = go_verge_ads_canonical_loader_tag();
go_test_equals( 'good', go_verge_ads_single_loader_health_test()['status'], 'One HTTP tag reports only the observed HTML' );
$GLOBALS['mode_remote']['body'] .= go_verge_ads_canonical_loader_tag();
go_test_equals( 'critical', go_verge_ads_single_loader_health_test()['status'], 'Two immediate provider tags remain actionable local evidence' );

go_test_equals( 0, $GLOBALS['legacy_mode_filter_calls'], 'Retired mode callback is not executed on delivery path' );
