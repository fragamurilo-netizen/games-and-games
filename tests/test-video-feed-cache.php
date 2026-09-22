<?php
/** Offline end-to-end video template + real cache/worker/lease, fake WordPress transport. */
if ('cli' !== PHP_SAPI) { exit; }
// Separate processes keep WP_CLI immutable and distinguish it from PHP's CLI SAPI.
if (in_array('--cli-worker', $argv, true)) { define('WP_CLI', true); }
if (in_array('--cli-disabled', $argv, true)) { define('WP_CLI', false); }
define('ABSPATH', __DIR__.'/../'); define('MINUTE_IN_SECONDS',60); define('DAY_IN_SECONDS',86400);
$code=getenv('GO_VIDEO_TEST_CODE') ?: dirname(__DIR__);
$GLOBALS['vc_options']=array(); $GLOBALS['vc_transients']=array(); $GLOBALS['vc_ttls']=array(); $GLOBALS['vc_events']=array(); $GLOBALS['vc_hooks']=array(); $GLOBALS['vc_calls']=array(); $GLOBALS['vc_cron']=false; $GLOBALS['vc_response']='error'; $GLOBALS['vc_checks']=array(); $GLOBALS['vc_override']=null;
class WP_Error {}
function add_action($hook,$callback,$priority=10,$accepted=1){$GLOBALS['vc_hooks'][$hook]=array($callback,$accepted);}
function apply_filters($hook,$value,...$args){return 'go_verge_official_video_sources'===$hook && is_array($GLOBALS['vc_override']) ? $GLOBALS['vc_override'] : $value;}
function get_option($key,$default=false){return $GLOBALS['vc_options'][$key]??$default;}
function update_option($key,$value,$autoload=false){$GLOBALS['vc_options'][$key]=$value;return true;}
function add_option($key,$value,...$args){if(array_key_exists($key,$GLOBALS['vc_options'])){return false;} $GLOBALS['vc_options'][$key]=$value;return true;}
function delete_option($key){unset($GLOBALS['vc_options'][$key]);return true;}
function wp_generate_uuid4(){return '12345678-1234-1234-1234-'.sprintf('%012x',++$GLOBALS['vc_uuid']);}
$GLOBALS['vc_uuid']=0;
function get_theme_mod($key,$default=''){return $default;}
function get_transient($key){if(strpos($key,'go_verge_local_video_articles_v4_')===0){return $GLOBALS['vc_local'];}return $GLOBALS['vc_transients'][$key]??false;}
function set_transient($key,$value,$ttl){$GLOBALS['vc_transients'][$key]=$value;$GLOBALS['vc_ttls'][$key]=$ttl;return true;}
function delete_transient($key){unset($GLOBALS['vc_transients'][$key]);return true;}
function wp_next_scheduled($hook,$args=array()){return $GLOBALS['vc_events'][$hook.'|'.json_encode($args)]['at']??false;}
function wp_schedule_single_event($at,$hook,$args=array()){$GLOBALS['vc_events'][$hook.'|'.json_encode($args)]=array('at'=>$at,'hook'=>$hook,'args'=>$args);return true;}
function wp_doing_cron(){return $GLOBALS['vc_cron'];}
function absint($v){return abs((int)$v);} function sanitize_key($v){return strtolower(preg_replace('/[^a-z0-9_\-]/i','',$v));}
function home_url($v='/'){return 'https://example.test'.$v;} function add_query_arg($k,$v,$url){return $url.'?'.rawurlencode($k).'='.rawurlencode($v);}
function wp_remote_get($url,$args){$GLOBALS['vc_calls'][]=array('url'=>$url,'args'=>$args,'cron'=>wp_doing_cron()); if('error'===$GLOBALS['vc_response']){return new WP_Error;} if('malformed'===$GLOBALS['vc_response']){return array('code'=>200,'body'=>'broken xml');}return array('code'=>200,'body'=>$GLOBALS['vc_atom']);}
function is_wp_error($v){return $v instanceof WP_Error;} function wp_remote_retrieve_response_code($v){return $v['code'];} function wp_remote_retrieve_body($v){return $v['body'];}
function wp_strip_all_tags($v){return strip_tags($v);} function wp_json_encode($v){return json_encode($v);}
function __($v,...$args){return $v;} function esc_html($v){return htmlspecialchars((string)$v,ENT_QUOTES);} function esc_attr($v){return esc_html($v);} function esc_url($v){return esc_attr($v);} function esc_html_e($v,...$args){echo esc_html($v);} function esc_attr_e($v,...$args){echo esc_attr($v);}
function human_time_diff($a,$b){return 'há '.abs($b-$a).'s';} function current_time($type,$gmt=false){return time();} function get_the_date(...$args){return '21/09/2026';}
function get_header(){echo '<header>Header fixture</header>'; } function get_footer(){echo '<footer>Footer fixture</footer>';}
function vc_check($name,$pass){$GLOBALS['vc_checks'][]=array('name'=>$name,'pass'=>(bool)$pass);}
function vc_render(){global $code;ob_start();include $code.'/page-videos.php';return ob_get_clean();}
function vc_key($channel){return 'go_video_channel_v1_'.md5($channel);}
function vc_drain(){foreach($GLOBALS['vc_events'] as $key=>$event){unset($GLOBALS['vc_events'][$key]);$GLOBALS['vc_cron']=true;try{[$fn,$accepted]=$GLOBALS['vc_hooks'][$event['hook']];call_user_func_array($fn,array_slice($event['args'],0,$accepted));}finally{$GLOBALS['vc_cron']=false;}}}
// Use the actual shared lease implementation, including token ownership and stale comparison.
$bootstrap=file_get_contents($code.'/functions.php');foreach(array('go_verge_claim_job_lock','go_verge_release_job_lock') as $name){preg_match('/function '.preg_quote($name,'/').'\(.*?\n\}\n/s',$bootstrap,$match);eval($match[0]);}
require $code.'/inc/editorial-layouts.php';
if (in_array('--cli-worker', $argv, true) || in_array('--cli-disabled', $argv, true)) {
 $enabled=defined('WP_CLI')&&WP_CLI;$sources=go_verge_official_video_sources();$source=$sources['xbox'];$channel=$source['channel_id'];$key=vc_key($channel);
 go_verge_fetch_official_video_source('xbox',$source,8);
 vc_check('saved-feed reader never fetches even in explicit CLI',count($GLOBALS['vc_calls'])===0&&count($GLOBALS['vc_events'])===1);
 go_verge_refresh_official_video_channel($channel);
 vc_check('worker accepts only explicitly enabled WP_CLI when cron flag is false',!wp_doing_cron()&&count($GLOBALS['vc_calls'])===($enabled?1:0));
 vc_check('CLI worker preserves negative cooldown', $enabled ? is_array(get_transient($key))&&$GLOBALS['vc_ttls'][$key]===600 : get_transient($key)===false);
 go_verge_refresh_official_video_channel($channel);
 vc_check('CLI duplicate worker respects saved cooldown',count($GLOBALS['vc_calls'])===($enabled?1:0));
 vc_check('CLI worker releases its lease',get_option('_go_job_lock_video_channel_'.md5($channel),false)===false);
 go_verge_request_official_video_source('xbox',$source,8);
 vc_check('raw transport uses the same explicit CLI gate',count($GLOBALS['vc_calls'])===($enabled?2:0));
 $failed=count(array_filter($GLOBALS['vc_checks'],fn($r)=>!$r['pass']));echo json_encode(array('total'=>count($GLOBALS['vc_checks']),'failed'=>$failed,'wp_cli'=>$enabled,'doing_cron'=>false,'network_requests_real'=>0,'checks'=>$GLOBALS['vc_checks']),JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE)."\n";exit($failed?1:0);
}
$GLOBALS['vc_local']=array(array('id'=>'LOCAL123456','title'=>'Vídeo da matéria local','channel'=>'Overdrive','source'=>'overdrive','published'=>time()-120,'url'=>'https://example.test/local/','article_url'=>'https://example.test/local/','post_id'=>1,'is_article'=>true,'thumbnail'=>'https://example.test/local.jpg'));
$html=vc_render();
vc_check('cold public full template makes zero HTTP',count($GLOBALS['vc_calls'])===0);
vc_check('cold queues three channels once despite two template passes',count($GLOBALS['vc_events'])===3);
vc_check('cold preserves header, main, footer and local video',strpos($html,'<header>')!==false&&strpos($html,'<main')!==false&&strpos($html,'<footer>')!==false&&strpos($html,'Vídeo da matéria local')!==false);
vc_render();vc_check('second cold render does not duplicate jobs',count($GLOBALS['vc_events'])===3&&count($GLOBALS['vc_calls'])===0);
if(!function_exists('go_verge_refresh_official_video_channel')){echo json_encode(array('checks'=>$GLOBALS['vc_checks'],'failed'=>count(array_filter($GLOBALS['vc_checks'],fn($r)=>!$r['pass']))),JSON_PRETTY_PRINT)."\n";exit(1);}
$sources=go_verge_official_video_sources();$channel=$sources['xbox']['channel_id'];$key=vc_key($channel);
vc_drain();vc_check('failure workers each do one HTTP only in cron',count($GLOBALS['vc_calls'])===3&&count(array_filter($GLOBALS['vc_calls'],fn($c)=>!$c['cron']))===0);
vc_check('failure caches negative result for ten minutes',is_array(get_transient($key))&&$GLOBALS['vc_ttls'][$key]===600);
vc_render();vc_check('negative cache prevents new jobs and public HTTP',count($GLOBALS['vc_events'])===0&&count($GLOBALS['vc_calls'])===3);
$GLOBALS['vc_options']['go_verge_video_channel_pc']='UC-optional-pc';$GLOBALS['vc_options']['go_verge_video_channel_mobile']='UC-optional-mobile';vc_render();
vc_check('new optional channels each queue once',count($GLOBALS['vc_events'])===2);
unset($GLOBALS['vc_options']['go_verge_video_channel_pc'],$GLOBALS['vc_options']['go_verge_video_channel_mobile']);vc_drain();
vc_check('removed configured channels do no HTTP when queued jobs run',count($GLOBALS['vc_calls'])===3);
$pool=array();for($i=0;$i<9;$i++){$pool[]=array('id'=>'OFFICIAL'.sprintf('%03d',$i),'title'=>'Vídeo oficial '.$i,'channel'=>'Old label','source'=>'old','published'=>time()-$i*60,'url'=>'https://www.youtube.com/watch?v=OFFICIAL'.sprintf('%03d',$i),'thumbnail'=>'https://example.test/official.jpg');}
$record=array('saved_at'=>time()-3600,'items'=>$pool);update_option($key.'_stale',$record,false);delete_transient($key);
$got=go_verge_fetch_official_video_source('xbox',array('channel_id'=>$channel,'label'=>'Xbox renomeado'),3);
vc_check('stale reader returns requested slice with current label/source',count($got)===3&&$got[0]['channel']==='Xbox renomeado'&&$got[0]['source']==='xbox');
vc_check('stale reader preserves original publication time',$got[0]['published']===$pool[0]['published']);
vc_check('nonpositive caller limit keeps existing minimum one',count(go_verge_fetch_official_video_source('xbox',$sources['xbox'],0))===1);
$events=count($GLOBALS['vc_events']);go_verge_fetch_official_video_source('alias',array('channel_id'=>$channel,'label'=>'Alias'),8);
vc_check('two source aliases sharing a channel do not create a second job',count($GLOBALS['vc_events'])===$events);
vc_check('empty channel is inert',go_verge_fetch_official_video_source('empty',array('channel_id'=>''),8)===array()&&count($GLOBALS['vc_events'])===$events);
$html=vc_render();vc_check('stale official and local data both render',strpos($html,'Vídeo oficial 0')!==false&&strpos($html,'Vídeo da matéria local')!==false&&strpos($html,'<footer>')!==false);
$before=count($GLOBALS['vc_calls']);vc_drain();vc_check('failure keeps previous successful record unchanged',get_option($key.'_stale')===$record&&count($GLOBALS['vc_calls'])===$before+1);
vc_check('failure serves saved items during cooldown',count(go_verge_fetch_official_video_source('xbox',$sources['xbox'],8))===8);
$too_old=array('saved_at'=>time()-8*DAY_IN_SECONDS,'items'=>$pool);update_option($key.'_stale',$too_old,false);set_transient($key,$too_old,600);
vc_check('stale beyond seven days is not exposed',go_verge_fetch_official_video_source('xbox',$sources['xbox'],8)===array());
delete_transient($key);$before=count($GLOBALS['vc_calls']);$GLOBALS['vc_cron']=true;go_verge_claim_job_lock('video_channel_'.md5($channel),90);go_verge_refresh_official_video_channel($channel);$GLOBALS['vc_cron']=false;
vc_check('existing live lease blocks duplicate worker HTTP',count($GLOBALS['vc_calls'])===$before);go_verge_release_job_lock('video_channel_'.md5($channel));
$before=count($GLOBALS['vc_calls']);go_verge_refresh_official_video_channel($channel);go_verge_request_official_video_source('xbox',$sources['xbox'],8);vc_check('worker and raw request reject public direct calls',count($GLOBALS['vc_calls'])===$before);
$GLOBALS['vc_override']=array('custom'=>array('label'=>'Custom label','channel_id'=>'UC-custom-filter'));go_verge_fetch_official_video_source('custom',$GLOBALS['vc_override']['custom'],8);
vc_check('source filter can schedule a new supported channel',wp_next_scheduled('go_verge_refresh_video_channel',array('UC-custom-filter'))!==false);
vc_drain();vc_check('worker honors current source filter',strpos(end($GLOBALS['vc_calls'])['url'],'UC-custom-filter')!==false);$GLOBALS['vc_override']=null;
$xml='<feed xmlns="http://www.w3.org/2005/Atom" xmlns:yt="http://www.youtube.com/xml/schemas/2015">';for($i=0;$i<9;$i++){$xml.='<entry><yt:videoId>SUCCESS'.sprintf('%04d',$i).'</yt:videoId><title>Fonte real '.$i.'</title><published>2026-09-21T12:00:00+00:00</published></entry>';}$GLOBALS['vc_atom']=$xml.'</feed>';
$parser_available=function_exists('simplexml_load_string');
if($parser_available){
 delete_transient($key);$GLOBALS['vc_response']='success';$GLOBALS['vc_cron']=true;go_verge_refresh_official_video_channel($channel);$GLOBALS['vc_cron']=false;
 vc_check('real Atom parser saves nine normalized items',count(get_option($key.'_stale')['items']??array())===9);
 vc_check('success caches thirty minutes',$GLOBALS['vc_ttls'][$key]===1800);
 vc_check('success replaces old record timestamp',get_option($key.'_stale')['saved_at']>=$record['saved_at']+3500);
 $saved=get_option($key.'_stale');vc_check('getter honors eight and three from same saved pool',count(go_verge_fetch_official_video_source('xbox',$sources['xbox'],8))===8&&count(go_verge_fetch_official_video_source('xbox',$sources['xbox'],3))===3);
 $before=count($GLOBALS['vc_calls']);$GLOBALS['vc_cron']=true;go_verge_refresh_official_video_channel($channel);$GLOBALS['vc_cron']=false;vc_check('duplicate scheduled worker respects fresh cache',count($GLOBALS['vc_calls'])===$before);
 delete_transient($key);$GLOBALS['vc_response']='malformed';$GLOBALS['vc_cron']=true;go_verge_refresh_official_video_channel($channel);$GLOBALS['vc_cron']=false;vc_check('malformed XML preserves last success and cooldown',get_option($key.'_stale')===$saved&&$GLOBALS['vc_ttls'][$key]===600);
 vc_check('lease released after worker completion',get_option('_go_job_lock_video_channel_'.md5($channel),false)===false);
}
$failed=count(array_filter($GLOBALS['vc_checks'],fn($r)=>!$r['pass']));echo json_encode(array('total'=>count($GLOBALS['vc_checks']),'failed'=>$failed,'network_requests_real'=>0,'simplexml_available'=>$parser_available,'checks'=>$GLOBALS['vc_checks']),JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE)."\n";exit($failed?1:0);
