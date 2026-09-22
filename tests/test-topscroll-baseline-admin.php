<?php
/** Admin-only baseline persistence, crash recovery, and read-only public config. */
if ( 'cli' !== PHP_SAPI ) { exit; }
define('ABSPATH',__DIR__.'/');
define('DAY_IN_SECONDS',86400);
define('MINUTE_IN_SECONDS',60);
define('GO_VERGE_ADSENSE_CLIENT','ca-pub-3687004010207904');
define('GO_VERGE_ADSENSE_TOPSCROLL_SLOT','7792311754');
$custom_default=in_array('--custom-default',(array)$argv,true);
if($custom_default) { define('GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT',3); }
$GLOBALS['top_options']=array();
$GLOBALS['top_writes']=array();
$GLOBALS['top_filters']=array();
$GLOBALS['top_hooks']=array();
$GLOBALS['top_fail']=array();
$GLOBALS['top_filter_zero']=false;
$GLOBALS['top_race_marker']=false;
$GLOBALS['top_context']=array('admin'=>true,'cap'=>true,'ajax'=>false);
$GLOBALS['top_purge']=0;
$GLOBALS['top_assertions']=0;
$GLOBALS['top_failures']=array();
function absint($v) { return abs((int)$v); }
function sanitize_key($v) { return preg_replace('/[^a-z0-9_\-]/','',strtolower($v)); }
function get_option($name,$default=false) { return array_key_exists($name,$GLOBALS['top_options'])?$GLOBALS['top_options'][$name]:$default; }
function update_option($name,$value,$autoload=null) {
    $GLOBALS['top_writes'][]=array('update',$name,$value,$autoload);
    if(!empty($GLOBALS['top_fail'][$name])) { return false; }
    if(array_key_exists($name,$GLOBALS['top_options']) && $GLOBALS['top_options'][$name]===$value) { return false; }
    $GLOBALS['top_options'][$name]=$value;
    return true;
}
function add_option($name,$value,$deprecated='',$autoload=null) {
    $GLOBALS['top_writes'][]=array('add',$name,$value,$autoload);
    if(!empty($GLOBALS['top_race_marker']) && GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION===$name) {
        $GLOBALS['top_options'][$name]=1;
        return false;
    }
    if(!empty($GLOBALS['top_fail'][$name]) || array_key_exists($name,$GLOBALS['top_options'])) { return false; }
    $GLOBALS['top_options'][$name]=$value;
    return true;
}
function add_action($hook,$callback,$priority=10) { $GLOBALS['top_hooks'][$hook][$callback]=$priority; }
function has_filter($hook) { return !empty($GLOBALS['top_filters'][$hook])?($GLOBALS['top_filter_zero']?0:true):false; }
function apply_filters($hook,$value) { foreach(($GLOBALS['top_filters'][$hook]??array()) as $fn) {$value=$fn($value);} return $value; }
function is_admin() { return $GLOBALS['top_context']['admin']; }
function current_user_can($cap) { return 'manage_options'===$cap && $GLOBALS['top_context']['cap']; }
function wp_doing_ajax() { return $GLOBALS['top_context']['ajax']; }
function go_verge_ads_schedule_policy_cache_purge() { $GLOBALS['top_purge']=1; }
function top_eq($expected,$actual,$label) {
    ++$GLOBALS['top_assertions'];
    if($expected!==$actual) {$GLOBALS['top_failures'][]=$label.' expected='.json_encode($expected).' actual='.json_encode($actual);}
}
function top_reset($exists=false,$value=null) {
    $GLOBALS['top_options']=$exists?array(GO_VERGE_ADSENSE_TOPSCROLL_OPTION=>$value):array();
    $GLOBALS['top_writes']=array();$GLOBALS['top_filters']=array();$GLOBALS['top_fail']=array();
    $GLOBALS['top_filter_zero']=false;$GLOBALS['top_race_marker']=false;
    $GLOBALS['top_context']=array('admin'=>true,'cap'=>true,'ajax'=>false);$GLOBALS['top_purge']=0;
}
require dirname(__DIR__).'/inc/ads/topscroll.php';
$cap=$custom_default?3:6;
top_eq(5,$GLOBALS['top_hooks']['admin_init']['go_verge_adsense_topscroll_apply_baseline'],'Migration runs before Settings API sanitizer priority10');
$cases=array(
    array(false,null),array(true,false),array(true,'corrupt-option'),array(true,array()),
    array(true,array('enabled'=>false,'frequency_max'=>0,'client_note'=>'keep','nested'=>array('x'=>1))),
    array(true,array('enabled'=>false,'frequency_max'=>2)),array(true,array('enabled'=>true,'frequency_max'=>3)),
    array(true,array('enabled'=>true,'frequency_max'=>4)),array(true,array('enabled'=>true,'frequency_max'=>5)),
    array(true,array('enabled'=>true,'frequency_max'=>6))
);
foreach($cases as $i=>$case) {
    top_reset($case[0],$case[1]);
    $GLOBALS['top_options'][GO_VERGE_ADSENSE_TOPSCROLL_READY_MIGRATION_OPTION]=1;
    $before=$GLOBALS['top_options'];
    $config=go_verge_adsense_topscroll_config();
    top_eq($cap,$config['frequency_max'],'Immediate effective cap '.$i);
    top_eq(true,$config['enabled'],'Immediate enabled baseline '.$i);
    top_eq($before,$GLOBALS['top_options'],'Public resolver preserves exact database '.$i);
    top_eq(0,count($GLOBALS['top_writes']),'No public writes '.$i);
    top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Admin reset succeeds '.$i);
    $target=go_verge_adsense_topscroll_baseline_values($case[1]);
    top_eq($target,get_option(GO_VERGE_ADSENSE_TOPSCROLL_OPTION),'Stored complete target '.$i);
    $backup=get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION);
    top_eq($case[0],$backup['existed'],'Original existence captured '.$i);
    top_eq($case[0]?$case[1]:null,$backup['value'],'Original exact value captured '.$i);
    top_eq($target,$backup['target'],'Target captured for review '.$i);
    top_eq(1,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION),'Completion marker '.$i);
    top_eq(1,$GLOBALS['top_purge'],'Cache purge scheduled '.$i);
    top_eq(false,go_verge_adsense_topscroll_config()['baseline_pending'],'Config distinguishes persisted baseline '.$i);
    $writes=count($GLOBALS['top_writes']);
    top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Second admin invocation succeeds '.$i);
    top_eq($writes,count($GLOBALS['top_writes']),'Second invocation adds no writes '.$i);
    top_eq($backup,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION),'Original backup never replaced '.$i);
    $GLOBALS['top_options'][GO_VERGE_ADSENSE_TOPSCROLL_OPTION]=array('enabled'=>false,'frequency_max'=>2,'after'=>'choice');
    top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Later administrator choice preserved '.$i);
    top_eq(false,go_verge_adsense_topscroll_config()['enabled'],'Later disabled option is effective '.$i);
    top_eq(2,go_verge_adsense_topscroll_config()['frequency_max'],'Later cap option is effective '.$i);
}
foreach(array('admin','cap','ajax') as $field) {
    top_reset(true,array('enabled'=>false,'frequency_max'=>3));
    $GLOBALS['top_context'][$field]='ajax'===$field;
    top_eq(false,go_verge_adsense_topscroll_apply_baseline(),'Wrong request cannot migrate: '.$field);
    top_eq(0,count($GLOBALS['top_writes']),'No writes in wrong context: '.$field);
    top_eq(0,$GLOBALS['top_purge'],'No purge in wrong context: '.$field);
}

/* If a write fails, do not claim completion; keep the original backup for retry. */
foreach(array(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION,GO_VERGE_ADSENSE_TOPSCROLL_OPTION,GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION) as $failed) {
    $original=array('enabled'=>false,'frequency_max'=>4,'note'=>'original');
    top_reset(true,$original);$GLOBALS['top_fail'][$failed]=true;
    top_eq(false,go_verge_adsense_topscroll_apply_baseline(),'Write failure returns pending: '.$failed);
    top_eq(0,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION,0),'No completion on failed write: '.$failed);
    top_eq(0,$GLOBALS['top_purge'],'Failed writes do not create repeated cache purges: '.$failed);
    if(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION===$failed) {
        top_eq($original,get_option(GO_VERGE_ADSENSE_TOPSCROLL_OPTION),'Failed backup prevents option mutation');
        top_eq(1,count($GLOBALS['top_writes']),'Failed backup stops immediately');
    }
    $GLOBALS['top_fail']=array();
    top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Retry completes: '.$failed);
    top_eq($original,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION)['value'],'Retry keeps original recoverable: '.$failed);
    top_eq($cap,get_option(GO_VERGE_ADSENSE_TOPSCROLL_OPTION)['frequency_max'],'Retry stores target cap: '.$failed);
}

/* An existing corrupt backup is not treated as successful protection. */
top_reset(true,array('enabled'=>false,'frequency_max'=>1));
$GLOBALS['top_options'][GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION]=false;
top_eq(false,go_verge_adsense_topscroll_apply_baseline(),'Corrupt existing backup blocks persistence');
top_eq(0,count($GLOBALS['top_writes']),'Corrupt backup is never overwritten');
top_eq(1,get_option(GO_VERGE_ADSENSE_TOPSCROLL_OPTION)['frequency_max'],'Original option survives corrupt backup');

/* Another administrative request won the atomic marker creation. */
top_reset(true,array('enabled'=>false,'frequency_max'=>3));
$GLOBALS['top_race_marker']=true;
top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Concurrent completed marker is recognized');
top_eq(0,$GLOBALS['top_purge'],'Losing marker request does not schedule a duplicate purge');
top_eq(3,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION)['value']['frequency_max'],'Concurrent completion retains original backup');

/* A deliberately pending existing marker can also complete without deleting it. */
top_reset(true,array('enabled'=>false,'frequency_max'=>3));
$GLOBALS['top_options'][GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION]=0;
top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Existing pending marker is completed');
top_eq(1,$GLOBALS['top_purge'],'Existing pending marker schedules one purge');

/* Deployment filters remain active while the option gets its authorized reset. */
top_reset(true,array('enabled'=>false,'frequency_max'=>0,'note'=>'external'));
$GLOBALS['top_filters']['go_verge_adsense_topscroll_config']=array(static function($c){$c['frequency_max']=2;return $c;});
$GLOBALS['top_filters']['go_verge_adsense_topscroll_enabled']=array(static function($v){return false;});
$GLOBALS['top_filter_zero']=true;
top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Baseline persistence does not erase filters');
top_eq($cap,get_option(GO_VERGE_ADSENSE_TOPSCROLL_OPTION)['frequency_max'],'Stored baseline still records reset cap');
top_eq(2,go_verge_adsense_topscroll_config()['frequency_max'],'External filter still controls effective cap');
top_eq(false,go_verge_adsense_topscroll_config()['enabled'],'External disable filter still works');
top_eq('registered',get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION)['overrides']['go_verge_adsense_topscroll_config'],'Backup identifies filter override');

define('GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT',4);
define('GO_VERGE_ADSENSE_TOPSCROLL_ENABLED',false);
top_reset(true,array('enabled'=>true,'frequency_max'=>0));
top_eq(true,go_verge_adsense_topscroll_apply_baseline(),'Emergency constant preserves explicit authority, allows option reset');
top_eq(false,go_verge_adsense_topscroll_config()['enabled'],'Emergency disabled remains effective');
top_eq(4,go_verge_adsense_topscroll_config()['frequency_max'],'Explicit constant cap remains effective');
top_eq(false,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION)['overrides']['GO_VERGE_ADSENSE_TOPSCROLL_ENABLED'],'Backup records emergency constant');
if($custom_default) {top_eq(3,get_option(GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION)['overrides']['GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT'],'Backup records custom DEFAULT');}

printf("Top Scroll baseline admin: %d assertions; %d failed.\n",$GLOBALS['top_assertions'],count($GLOBALS['top_failures']));
if($GLOBALS['top_failures']) {echo implode("\n",$GLOBALS['top_failures'])."\n";exit(1);}
