<?php
/** Offline fixture: real PHP contract/renderer/assets, WordPress environment doubles only. */
if ('cli' !== PHP_SAPI) { exit(1); }
define('GO_TEST_FIXTURE_EXPORT', true);
$root = getenv('GO_THEME_ROOT') ?: dirname(__DIR__);
require $root . '/tests/bootstrap.php';
define('GO_VERGE_VERSION', '5.5.3');
if (in_array('--off', $argv, true)) { define('GO_ADS_V3_ENABLED', false); }
if (in_array('--gate', $argv, true)) { define('GO_VERGE_ADS_THEME_CONSENT_GATE', true); }
function wp_doing_ajax() { return false; }
function is_feed() { return false; }
function is_404() { return false; }
function is_preview() { return false; }
function is_singular($type = '') { return '' === $type || 'post' === $type; }
function post_password_required() { return false; }
function is_front_page() { return false; }
function is_home() { return false; }
function get_queried_object_id() { return 52503; }
function go_verge_asset_version($file) { return 'fixture'; }
function wp_enqueue_style() {}
foreach (array('mode','config','calendar-trials','economics','yield','context','consent','renderer','planner','composer','loader','topscroll','assets') as $module) {
    require $root . '/inc/ads/' . $module . '.php';
}
function capture($callback) { ob_start(); $callback(); return ob_get_clean(); }
$config = go_verge_ads_yield_config();
$head = in_array('--skip-head', $argv, true) ? '' : capture('go_verge_ads_print_manual_runtime');
$units = array();
foreach (array('article-prime','article-a1','sidebar-desktop','topscroll') as $placement) {
    $units[$placement] = go_verge_adsense_unit_markup($placement, array('data' => array(
        'ad-body-words' => 1800, 'ad-surface' => 'article', 'ad-planned-count' => 2,
        'ad-rendered-count' => 2, 'ad-body-capacity' => 2, 'ad-eligible-candidates' => 7,
    )));
}
$recovery = capture('go_verge_ads_print_manual_runtime_recovery');
$second_recovery = capture('go_verge_ads_print_manual_runtime_recovery');
echo json_encode(array('config'=>$config,'head'=>$head,'units'=>$units,'recovery'=>$recovery,
    'secondRecovery'=>$second_recovery,'enabled'=>go_verge_ads_manual_delivery_enabled()), JSON_UNESCAPED_SLASHES);
