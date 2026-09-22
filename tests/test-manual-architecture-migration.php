<?php
/** Independent administrative migration fixtures; no WordPress/network required. */
if ( 'cli' !== PHP_SAPI ) { exit( 1 ); }
define( 'ABSPATH', __DIR__ );
define( 'GO_VERGE_ADS_DELIVERY_MODE', 'auto_overlays' );
$checks = 0; $cases = 0;
function check( $condition, $message ) { global $checks; $checks++; if ( ! $condition ) { throw new RuntimeException( $message ); } }
function is_admin() { return $GLOBALS['admin']; }
function current_user_can( $cap ) { return $GLOBALS['manager'] && 'manage_options' === $cap; }
function wp_doing_ajax() { return $GLOBALS['ajax']; }
function get_current_user_id() { return 37; }
function get_option( $name, $default = false ) { return array_key_exists( $name, $GLOBALS['options'] ) ? $GLOBALS['options'][ $name ] : $default; }
function add_option( $name, $value, $deprecated = '', $autoload = false ) {
	if ( array_key_exists( $name, $GLOBALS['options'] ) || $name === $GLOBALS['fail_key'] ) { return false; }
	$GLOBALS['writes'][] = $name; $GLOBALS['options'][ $name ] = $value; return true;
}
function update_option( $name, $value, $autoload = false ) {
	if ( $name === $GLOBALS['fail_key'] || ( array_key_exists( $name, $GLOBALS['options'] ) && $GLOBALS['options'][ $name ] === $value ) ) { return false; }
	$GLOBALS['writes'][] = $name; $GLOBALS['options'][ $name ] = $value; return true;
}
function add_action( $name, $fn, $priority = 10 ) { $GLOBALS['actions'][ $name ][ $fn ] = $priority; }
function has_filter( $name ) { return 'go_verge_ads_delivery_mode' === $name ? 10 : false; }
function delete_transient( $key ) { $GLOBALS['deletes'][] = $key; }
function go_verge_purge_all_page_cache() { $GLOBALS['purges']++; }
function go_verge_ads_config() { return array( 'enabled' => $GLOBALS['enabled'], 'delivery_mode' => go_verge_ads_delivery_mode() ); }
function esc_html( $value ) { return htmlspecialchars( (string) $value, ENT_QUOTES, 'UTF-8' ); }
function reset_scene() {
	$GLOBALS['admin'] = true; $GLOBALS['manager'] = true; $GLOBALS['ajax'] = false; $GLOBALS['enabled'] = true;
	$GLOBALS['options'] = array( 'go_verge_ads_delivery_mode' => 'auto_overlays', 'go_verge_ads_delivery_mode_history' => array( array( 'from'=>'manual_overlays', 'to'=>'auto_overlays', 'at_utc'=>'old' ) ), 'goac_optimization_controls'=>array('auto_ads'=>'on','banner_ads'=>'on'), 'goac_connection'=>array('opaque'=>'preserve'), 'go_verge_adsense_topscroll'=>array('enabled'=>false,'frequency_max'=>2), 'cmp_choice'=>'denied' );
	$GLOBALS['writes'] = array(); $GLOBALS['deletes'] = array(); $GLOBALS['purges'] = 0; $GLOBALS['actions'] = array(); $GLOBALS['fail_key'] = '';
	$GLOBALS['go_verge_ads_policy_cache_purge_queued'] = false;
}
function scenario( $name, $callback ) { global $cases; $cases++; reset_scene(); $callback(); }
reset_scene();
require dirname( __DIR__ ) . '/inc/ads/mode.php';
check( 10 === $GLOBALS['actions']['admin_init']['go_verge_ads_migrate_manual_architecture'], 'mode migration registered on administrative hook with shared deferred purge' );
set_error_handler( static function ( $severity, $message, $file, $line ) { throw new ErrorException( $message, 0, $severity, $file, $line ); } );
scenario( 'public read is pure', function () {
	$GLOBALS['admin'] = false; $before=$GLOBALS['options'];
	for($i=0;$i<10;$i++){ check('manual_overlays'===go_verge_ads_delivery_mode(),'fixed mode ignores stored/constant/filter');check(go_verge_ads_manual_delivery_enabled(),'legacy preference cannot silence manual'); }
	check(false===go_verge_ads_migrate_manual_architecture(),'public request cannot migrate');check(array()===$GLOBALS['writes'],'no public writes');check($before===$GLOBALS['options'],'all preferences intact');check(0===$GLOBALS['purges'],'no public purge');
});
scenario( 'capability and AJAX gates', function () {
	$GLOBALS['manager']=false;check(false===go_verge_ads_migrate_manual_architecture(),'unauthorized admin rejected');$GLOBALS['manager']=true;$GLOBALS['ajax']=true;check(false===go_verge_ads_migrate_manual_architecture(),'AJAX does not migrate');check(array()===$GLOBALS['writes'],'rejected migrations write nothing');
});
scenario( 'backup normalization history and idempotence', function () {
	$before=$GLOBALS['options'];check(true===go_verge_ads_migrate_manual_architecture(),'first admin migration commits');
	$backup=get_option('go_verge_ads_manual_architecture_backup_v1');check(true===$backup['option_existed'],'existence backed up');check('auto_overlays'===$backup['option_value'],'original auto backed up');check($before['go_verge_ads_delivery_mode_history']===$backup['history_value'],'original history backed up');check('auto_overlays'===$backup['legacy_constant_value'],'legacy constant recorded');check(true===$backup['legacy_filter_present'],'legacy filter recorded without callback');check('manual_overlays'===get_option('go_verge_ads_delivery_mode'),'saved mode normalized');
	$history=get_option('go_verge_ads_delivery_mode_history');check(2===count($history),'one event appended');check($before['go_verge_ads_delivery_mode_history'][0]===$history[0],'original event retained');check('administrative-upgrade'===$history[1]['trigger'],'automatic migration not represented as user toggle');check('auto_overlays'===$history[1]['from'],'history preserves prior mode');
	foreach(array('goac_optimization_controls','goac_connection','go_verge_adsense_topscroll','cmp_choice')as$key){check($before[$key]===get_option($key),'unrelated state preserved '.$key);}
	check(0===$GLOBALS['purges'],'purge waits for shutdown');check(1===count($GLOBALS['actions']['shutdown']),'one purge callback queued');$writes=$GLOBALS['writes'];check(false===go_verge_ads_migrate_manual_architecture(),'second migration no-op');check($writes===$GLOBALS['writes'],'second call writes nothing');go_verge_ads_purge_policy_cache();go_verge_ads_purge_policy_cache();check(1===$GLOBALS['purges'],'purge executes once');check(array('goac_delivery_checks')===$GLOBALS['deletes'],'only delivery diagnostics invalidated');
});
scenario( 'absent preference still requests upgrade cache cleanup', function () {
	unset($GLOBALS['options']['go_verge_ads_delivery_mode']);check(true===go_verge_ads_migrate_manual_architecture(),'missing option migrated');$backup=get_option('go_verge_ads_manual_architecture_backup_v1');check(false===$backup['option_existed'],'absence backed up for rollback');check(null===$backup['option_value'],'no invented original value');go_verge_ads_purge_policy_cache();check(1===$GLOBALS['purges'],'constant/filter legacy paths still cause one upgrade purge');
});
scenario( 'shared baseline migration coalesces cache cleanup', function () {
	go_verge_ads_schedule_policy_cache_purge();check(true===go_verge_ads_migrate_manual_architecture(),'mode migration independent of queued baseline purge');go_verge_ads_schedule_policy_cache_purge();check(1===count($GLOBALS['actions']['shutdown']),'two migrations queue one callback');go_verge_ads_purge_policy_cache();check(1===$GLOBALS['purges'],'two migrations purge once');
});
scenario( 'backup write failure does not lose old preference', function () {
	$GLOBALS['fail_key']='go_verge_ads_manual_architecture_backup_v1';check(false===go_verge_ads_migrate_manual_architecture(),'backup failure stops normalization');check('auto_overlays'===get_option('go_verge_ads_delivery_mode'),'original retained');check(false===get_option('go_verge_ads_manual_architecture_v1'),'not falsely completed');check(go_verge_ads_manual_delivery_enabled(),'effective delivery still manual');
});
scenario( 'preference failure retry preserves first backup', function () {
	$GLOBALS['fail_key']='go_verge_ads_delivery_mode';check(false===go_verge_ads_migrate_manual_architecture(),'option failure remains pending');$backup=get_option('go_verge_ads_manual_architecture_backup_v1');check('auto_overlays'===get_option('go_verge_ads_delivery_mode'),'failed option preserved');check(false===get_option('go_verge_ads_manual_architecture_v1'),'no completion marker');$GLOBALS['fail_key']='';check(true===go_verge_ads_migrate_manual_architecture(),'retry succeeds');check($backup===get_option('go_verge_ads_manual_architecture_backup_v1'),'retry does not overwrite original backup');
});
scenario( 'history failure remains pending without losing account data', function () {
	$GLOBALS['fail_key']='go_verge_ads_delivery_mode_history';check(false===go_verge_ads_migrate_manual_architecture(),'history failure remains pending');check(false===get_option('go_verge_ads_manual_architecture_v1'),'no false completion');check(0===$GLOBALS['purges'],'no premature purge');$GLOBALS['fail_key']='';check(true===go_verge_ads_migrate_manual_architecture(),'history retry succeeds');check(2===count(get_option('go_verge_ads_delivery_mode_history')),'history not duplicated');
});
scenario( 'global disabled remains disabled', function () {
	$GLOBALS['enabled']=false;check(true===go_verge_ads_migrate_manual_architecture(),'migration independent of explicit global stop');check(false===go_verge_ads_manual_delivery_enabled(),'migration never sets enabled true');
});
scenario( 'invalid saved value backs up without warnings', function () {
	$GLOBALS['options']['go_verge_ads_delivery_mode']=array('unexpected'=>'value');check(true===go_verge_ads_migrate_manual_architecture(),'invalid preference normalized safely');check(array('unexpected'=>'value')===get_option('go_verge_ads_manual_architecture_backup_v1')['option_value'],'original typed value retained');
});
scenario( 'status UI has no architecture form', function () {
	ob_start();go_verge_ads_delivery_mode_form();$html=ob_get_clean();check(false===strpos($html,'<form')&&false===strpos($html,'<select')&&false===strpos($html,'<button'),'read-only status');check(false!==strpos($html,'âncora e vinheta'),'official overlays explained');check(array()===$GLOBALS['writes'],'render never migrates');
});
scenario( 'legacy preference changed after migration cannot reactivate retired architecture', function () {
	go_verge_ads_migrate_manual_architecture();$GLOBALS['options']['go_verge_ads_delivery_mode']='auto_overlays';$writes=$GLOBALS['writes'];check(false===go_verge_ads_migrate_manual_architecture(),'one-time migration does not repeatedly reset preferences');check('manual_overlays'===go_verge_ads_delivery_mode(),'effective architecture remains fixed');check(go_verge_ads_manual_delivery_enabled(),'legacy database edit cannot silence manual');check($writes===$GLOBALS['writes'],'no repeated migration writes');
});
restore_error_handler();
echo json_encode(array('suite'=>'manual-architecture-migration','cases'=>$cases,'assertions'=>$checks,'passed'=>true,'real_network_requests'=>0),JSON_PRETTY_PRINT)."\n";
