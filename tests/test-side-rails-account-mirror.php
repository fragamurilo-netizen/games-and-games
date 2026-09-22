<?php
/** The real GOAC handler/view round trip stores observations, never account settings. */
if ( 'cli' !== PHP_SAPI ) { exit( 1 ); }
define( 'ABSPATH', __DIR__ );
define( 'GO_VERGE_DIR', dirname( __DIR__ ) );
$GLOBALS['mirror_checks'] = 0;
function go_test_ok( $condition, $label ) { $GLOBALS['mirror_checks']++; if ( ! $condition ) { throw new RuntimeException( $label ); } }
function go_test_equals( $expected, $actual, $label ) { go_test_ok( $expected === $actual, $label ); }
function current_user_can( $cap ) { return ! empty( $GLOBALS['go_test_is_admin_user'] ) && 'manage_options' === $cap; }
function add_action() {} function add_filter() {}
function has_filter() { return false; }
function apply_filters( $hook, $value ) { return $value; }
function wp_parse_args( $args, $defaults ) { return array_merge( $defaults, (array)$args ); }
function wp_unslash( $value ) { return $value; }
function sanitize_key( $value ) { return is_scalar( $value ) ? preg_replace('/[^a-z0-9_\-]/','',strtolower((string)$value)) : ''; }
function sanitize_text_field( $value ) { return trim(strip_tags((string)$value)); }
function esc_html( $value ) { return htmlspecialchars((string)$value,ENT_QUOTES,'UTF-8'); }
function esc_attr( $value ) { return esc_html($value); }
function esc_url( $value ) { return (string)$value; }
function __( $value, $domain='' ) { return $value; }
function absint( $value ) { return abs((int)$value); }
function is_admin() { return true; }
$GLOBALS['go_test_is_admin_user'] = true;
$GLOBALS['mirror_options'] = array( 'goac_connection' => array( 'opaque' => 'preserve' ) );
$GLOBALS['mirror_nonce'] = true;
$GLOBALS['mirror_events'] = array();
class MirrorRedirect extends RuntimeException {}
function get_option( $key, $default=false ) { return $GLOBALS['mirror_options'][$key] ?? $default; }
function update_option( $key, $value, $autoload=false ) { $GLOBALS['mirror_options'][$key]=$value;return true; }
function check_admin_referer( $action ) { if ( ! $GLOBALS['mirror_nonce'] ) { throw new RuntimeException( 'bad nonce' ); } }
function wp_die( $message ) { throw new RuntimeException( $message ); }
function admin_url( $path='' ) { return '/wp-admin/'.$path; }
function add_query_arg( $args, $url ) { return $url.'?'.http_build_query($args); }
function wp_safe_redirect( $url ) { throw new MirrorRedirect( $url ); }
function wp_nonce_field( $action ) { echo '<input name="_wpnonce" value="fixture">'; }
function selected( $a, $b, $echo=true ) { $out=$a===$b?' selected':'';if($echo){echo $out;}return $out; }
class GOAC_Learning { public static function record_event( $kind, $title, $data ) { $GLOBALS['mirror_events'][]=array($kind,$data); } }
class GOAC_Stats { public static function valid_date( $day ) { return (bool)preg_match('/^\d{4}-\d{2}-\d{2}$/',$day); } }
class GOAC_UI { public static function card_open( $title, $badge='' ) { echo '<section><h2>'.esc_html($title).'</h2>'.$badge; } public static function card_close() { echo '</section>'; } }
require_once GO_VERGE_DIR.'/inc/ads/mode.php';
require_once GO_VERGE_DIR.'/inc/ads/config.php';
require_once GO_VERGE_DIR.'/inc/ads/health.php';
require_once GO_VERGE_DIR.'/inc/ads-center/includes/class-goac-plugin.php';
require_once GO_VERGE_DIR.'/inc/ads-center/includes/class-goac-view-optimization.php';
$plugin=(new ReflectionClass('GOAC_Plugin'))->newInstanceWithoutConstructor();
$controls=new ReflectionMethod('GOAC_View_Optimization','controls');
$card=new ReflectionMethod('GOAC_View_Optimization','controls_card');
$aligned=array('configured'=>1,'auto_ads'=>'on','anchor_ads'=>'on','vignette_ads'=>'on','banner_ads'=>'off','find_more'=>'off','optimize_existing'=>'off');
$GLOBALS['mirror_options']['goac_optimization_controls']=$aligned;
$before=$GLOBALS['mirror_options'];
$legacy=$controls->invoke(null);
go_test_equals('unknown',$legacy['side_rails_ads'],'Legacy mirror gains unknown in memory, never an invented OFF observation');
go_test_equals('recommended',go_verge_ads_account_controls_health_test()['status'],'Legacy mirror produces pending evidence');
go_test_equals($before,$GLOBALS['mirror_options'],'Reading legacy mirror writes nothing');
ob_start();$card->invoke(null,'2026-09-21',$legacy);$html=ob_get_clean();
go_test_ok(false!==strpos($html,'name="side_rails_ads"'),'Real view renders side rails operator record');
go_test_ok(false===strpos($html,'name="delivery_mode"')&&false===strpos($html,'Alterar modo'),'Real view has no architecture toggle');
go_test_ok(false!==strpos($html,'relatórios históricos'),'View preserves explanation of historical data');
foreach(array('off'=>'good','on'=>'critical','missing'=>'recommended','invalid'=>'recommended')as$input=>$health){
	$_POST=$aligned+array('opt_day'=>'2026-09-21');
	if('missing'!==$input){$_POST['side_rails_ads']=$input;}
	try{$plugin->save_optimization_controls();go_test_ok(false,'Handler redirects after save');}catch(MirrorRedirect $e){go_test_ok(false!==strpos($e->getMessage(),'optimization_controls_saved'),'Real handler reached its normal redirect');}
	$expected=in_array($input,array('on','off'),true)?$input:'unknown';
	$stored=get_option('goac_optimization_controls');
	go_test_equals($expected,$stored['side_rails_ads'],'Round trip sanitizes side rails '.$input);
	go_test_equals('on',$stored['auto_ads'],'Recording side rails does not turn general Auto Ads off');
	go_test_equals('on',$stored['anchor_ads'],'Anchor record preserved');
	go_test_equals('on',$stored['vignette_ads'],'Vignette record preserved');
	go_test_equals($health,go_verge_ads_account_controls_health_test()['status'],'Health reflects operator record '.$input);
	go_test_equals(true,go_verge_ads_manual_delivery_enabled(),'Missing/conflicting record does not block manual delivery');
	go_test_equals(array('opaque'=>'preserve'),get_option('goac_connection'),'Credentials are untouched');
	$last=end($GLOBALS['mirror_events']);go_test_equals($expected,$last[1]['side_rails_ads'],'History event includes observation');
	ob_start();$card->invoke(null,'2026-09-21',$controls->invoke(null));$roundtrip=ob_get_clean();
	go_test_ok((bool)preg_match('/name="side_rails_ads"[^>]*>.*?<option value="'.preg_quote($expected,'/').'" selected>/s',$roundtrip),'Real view renders selected value '.$expected);
}
$before=$GLOBALS['mirror_options'];
$GLOBALS['go_test_is_admin_user']=false;
try{$plugin->save_optimization_controls();go_test_ok(false,'Unauthorized call blocked');}catch(RuntimeException $e){go_test_ok(!$e instanceof MirrorRedirect,'Capability guard rejects unauthorized save');}
go_test_equals($before,$GLOBALS['mirror_options'],'Unauthorized call writes nothing');
$GLOBALS['go_test_is_admin_user']=true;$GLOBALS['mirror_nonce']=false;
try{$plugin->save_optimization_controls();go_test_ok(false,'Nonce rejected');}catch(RuntimeException $e){go_test_equals('bad nonce',$e->getMessage(),'Nonce guard still runs');}
go_test_equals($before,$GLOBALS['mirror_options'],'Invalid nonce writes nothing');

echo json_encode(array('suite'=>'side-rails-account-mirror','assertions'=>$GLOBALS['mirror_checks'],'passed'=>true,'real_network_requests'=>0),JSON_PRETTY_PRINT)."\n";
