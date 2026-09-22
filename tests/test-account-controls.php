<?php
/** Local operator records must not imply an unobserved live account state. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/health.php';
function get_option( $key, $default = false ) {
	return 'goac_optimization_controls' === $key ? $GLOBALS['go_test_controls'] : $default;
}
$GLOBALS['go_test_controls'] = array(
	'auto_ads' => 'on', 'banner_ads' => 'off', 'find_more' => 'off', 'optimize_existing' => 'off',
);
$result = go_verge_ads_account_controls_health_test();
go_test_equals( 'recommended', $result['status'], 'Global Auto ads ON without individual overlay records remains unknown' );
go_test_ok( false !== strpos( $result['description'], 'âncora' ) && false !== strpos( $result['description'], 'vinheta' ), 'Both missing formats are identified' );
$GLOBALS['go_test_controls']['anchor_ads'] = 'on';
$GLOBALS['go_test_controls']['vignette_ads'] = 'off';
go_test_equals( 'critical', go_verge_ads_account_controls_health_test()['status'], 'Recorded vignette OFF conflicts with intended architecture' );
$GLOBALS['go_test_controls']['vignette_ads'] = 'on';
go_test_equals( 'recommended', go_verge_ads_account_controls_health_test()['status'], 'Legacy mirror without side rails remains pending' );
$GLOBALS['go_test_controls']['side_rails_ads'] = 'on';
go_test_equals( 'critical', go_verge_ads_account_controls_health_test()['status'], 'Recorded automatic side rails ON conflicts without changing delivery' );
$GLOBALS['go_test_controls']['side_rails_ads'] = 'off';
$result = go_verge_ads_account_controls_health_test();
go_test_equals( 'good', $result['status'], 'Complete aligned operator records pass' );
go_test_ok( false !== strpos( $result['description'], 'não consulta' ), 'Passing result expressly remains a manual record, not a live API check' );
$GLOBALS['go_test_controls']['banner_ads'] = 'on';
go_test_equals( 'critical', go_verge_ads_account_controls_health_test()['status'], 'Automatic in-page banners are still reported as a conflict' );
