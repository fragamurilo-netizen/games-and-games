<?php
/** Fixed public policy never consults intraday money; no live WordPress/network. */
if ( 'cli' !== PHP_SAPI ) { exit; }
$code = getenv( 'GO_ADS_TEST_CODE' ) ?: dirname( __DIR__ );
define( 'ABSPATH', $code . '/' );
define( 'GO_VERGE_DIR', $code );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'DAY_IN_SECONDS', 86400 );
define( 'ARRAY_A', 'ARRAY_A' );
$GLOBALS['manual_test_cache'] = array();
$GLOBALS['manual_test_calls'] = array( 'intraday'=>0, 'range'=>0, 'today'=>0 );
function get_transient( $key ) { return $GLOBALS['manual_test_cache'][ $key ] ?? false; }
function set_transient( $key, $value, $ttl = 0 ) { $GLOBALS['manual_test_cache'][ $key ] = $value; return true; }
function delete_transient( $key ) { unset( $GLOBALS['manual_test_cache'][ $key ] ); }
function apply_filters( $hook, $value ) { return $value; }
function add_action() {}
function absint( $v ) { return abs( (int) $v ); }
function sanitize_key( $v ) { return preg_replace( '/[^a-z0-9_-]/', '', strtolower( (string) $v ) ); }
function rest_url( $v = '' ) { return 'https://example.test/wp-json/' . $v; }
function is_user_logged_in() { return true; }
function current_user_can( $v ) { return true; }
class GOAC_API {
    public static function is_connected() { return false; }
    public static function tz() { return new DateTimeZone( 'America/Sao_Paulo' ); }
    public static function today() { $GLOBALS['manual_test_calls']['today']++; return '2026-09-21'; }
}
class GOAC_Store {
    public static function intraday() { $GLOBALS['manual_test_calls']['intraday']++; return array(); }
    public static function range( $from, $to ) { $GLOBALS['manual_test_calls']['range']++; return array(); }
}
require_once $code . '/inc/ads/config.php';
require_once $code . '/inc/ads/economics.php';
require_once $code . '/inc/ads/yield.php';
$failures = array(); $checks = 0;
function fixed_assert( $condition, $message ) {
    global $failures, $checks;
    $checks++;
    if ( ! $condition ) { $failures[] = $message; }
}
function fixed_model( $timestamp ) {
    return array( 'generated_at'=>$timestamp, 'samples'=>3, 'window'=>'2026-09-14..2026-09-20',
        'slots'=>array('7792311754'=>1.3,'3572313419'=>1.0,'5017324239'=>.8),
        'coverage'=>array('7792311754'=>1.02), 'viewability_abs'=>array('7792311754'=>.49),
        'tier_value'=>array('reach'=>1.1) );
}
function fixed_controls( $signal, $label ) {
    fixed_assert( ($signal['regime'] ?? '') === 'manual_fixed', "$label: public regime is policy, not a simulated financial result" );
    fixed_assert( ($signal['delivery_mode'] ?? '') === 'manual_fixed', "$label: explicit fixed delivery mode" );
    fixed_assert( ($signal['supply_bias'] ?? -1) === 0, "$label: no financial supply bias" );
    fixed_assert( ($signal['pacing_scale'] ?? 0) === 1.0, "$label: no financial pacing" );
    fixed_assert( ($signal['tier_lookahead'] ?? array()) === array_fill_keys(array('reach','premium','standard','deep','completion'),1.0), "$label: no financial lookahead" );
}

/* Cold public configuration must not compute either intraday state or money. */
$public = go_verge_ads_yield_config();
fixed_controls( $public['decision'], 'cold cache' );
fixed_assert( ! array_key_exists('regime_endpoint', $public), 'No per-page regime REST endpoint' );
fixed_assert( $GLOBALS['manual_test_calls'] === array('intraday'=>0,'range'=>0,'today'=>0), 'Public config made zero intraday/day-store calls' );
fixed_assert( false === get_transient(GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT), 'Public config did not populate the financial decision cache' );
fixed_assert( false === get_transient(GO_VERGE_ADS_ECON_DAY_TRANSIENT), 'Public config did not compute daily financial state' );

/* Hostile cached decisions must not escape into a new public payload. */
$legacy = array('regime'=>'demand_collapse','supply_bias'=>2,'pacing_scale'=>1.6,
    'tier_lookahead'=>array_fill_keys(array('reach','premium','standard','deep','completion'),1.25),
    'confidence'=>'high','fresh'=>true,'reasons'=>array('legacy-money-signal'),'generated_at'=>time());
set_transient(GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT, $legacy);
set_transient(GO_VERGE_ADS_ECON_SLOT_TRANSIENT, fixed_model(time()));
$signal = go_verge_ads_yield_public_signal();
fixed_controls( $signal, 'legacy cached financial decision' );
fixed_assert( ($signal['slot_value']['7792311754'] ?? 0) === 1.3, 'Valid per-unit historical values survive decoupling' );
fixed_assert( ($signal['slot_coverage']['7792311754'] ?? 0) === 1.02, 'Coverage history remains available for diagnostics' );
fixed_assert( ($signal['slot_viewability']['7792311754'] ?? 0) === .49, 'Historical AV remains available for timing' );
fixed_assert( ($signal['freshness_source'] ?? '') === 'unit-model-generation-not-report-capture', 'Model freshness never claims report/auction freshness' );
fixed_assert( get_transient(GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT) === $legacy, 'Public export does not mutate cached financial analytics' );

foreach ( array('missing'=>0, 'old'=>time()-90000, 'future'=>time()+90000) as $label=>$timestamp ) {
    set_transient(GO_VERGE_ADS_ECON_SLOT_TRANSIENT, fixed_model($timestamp));
    $signal = go_verge_ads_yield_public_signal();
    fixed_controls( $signal, $label );
    fixed_assert( empty($signal['slot_value']) && empty($signal['tier_value']), "$label: unusable priors become neutral" );
    fixed_assert( ($signal['fresh'] ?? true) === false, "$label: freshness is not fabricated" );
}
set_transient(GO_VERGE_ADS_ECON_SLOT_TRANSIENT, fixed_model(time()+240));
$clock = go_verge_ads_yield_public_signal();
fixed_assert( !empty($clock['slot_value']), 'Small clock skew within 300 seconds preserves valid priors' );
fixed_assert( $GLOBALS['manual_test_calls'] === array('intraday'=>0,'range'=>0,'today'=>0), 'All public cases made zero intraday/day-store calls' );
$public_store_calls = $GLOBALS['manual_test_calls'];

/* Administrative analytics still execute when explicitly requested. */
delete_transient(GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT);
$admin = go_verge_ads_yield_decision(true);
fixed_assert( ($admin['regime'] ?? '') === 'unknown', 'Administrative no-data classification remains truthful' );
fixed_assert( $GLOBALS['manual_test_calls']['intraday'] === 1, 'Admin analysis still reads the preserved GOAC integration' );
fixed_assert( !empty($admin['delivery_mode']) && $admin['delivery_controls_applied'] === false, 'Admin clearly labels coefficients as non-controlling' );
echo json_encode(array('checks'=>$checks,'failures'=>$failures,'failureCount'=>count($failures),'public_store_calls'=>$public_store_calls,'store_calls_after_admin'=>$GLOBALS['manual_test_calls']),JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";
exit($failures?1:0);
