<?php
/** Indexed, incremental read model of Burst's recorded post pageviews. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_pv_tables() {
 global $wpdb;
 return array( 'source'=>$wpdb->prefix.'burst_statistics', 'total'=>$wpdb->prefix.'go_post_views_total', 'daily'=>$wpdb->prefix.'go_post_views_daily', 'state'=>$wpdb->prefix.'go_post_views_state' );
}
function go_pv_available() {
 return function_exists( 'Burst\\burst_loader' ) && '1' === get_option( 'go_pv_schema' );
}
function go_pv_install() {
 if ( ! function_exists( 'Burst\\burst_loader' ) || '1' === get_option( 'go_pv_schema' ) ) { return; }
 global $wpdb; $t=go_pv_tables(); $charset=$wpdb->get_charset_collate();
 require_once ABSPATH.'wp-admin/includes/upgrade.php';
 dbDelta( "CREATE TABLE {$t['total']} (
 post_id bigint(20) unsigned NOT NULL,
 views bigint(20) unsigned NOT NULL DEFAULT 0,
 PRIMARY KEY  (post_id),
 KEY views (views)
 ) $charset;" );
 dbDelta( "CREATE TABLE {$t['daily']} (
 day_key date NOT NULL,
 post_id bigint(20) unsigned NOT NULL,
 views bigint(20) unsigned NOT NULL DEFAULT 0,
 PRIMARY KEY  (day_key,post_id),
 KEY ranking (day_key,views)
 ) $charset;" );
 dbDelta( "CREATE TABLE {$t['state']} (
 id tinyint unsigned NOT NULL,
 last_id bigint(20) unsigned NOT NULL DEFAULT 0,
 updated_at bigint(20) unsigned NOT NULL DEFAULT 0,
 PRIMARY KEY  (id)
 ) $charset;" );
 if ( false !== $wpdb->query( "INSERT IGNORE INTO {$t['state']} (id,last_id) VALUES (1,0)" ) ) {
  update_option('go_pv_schema','1',false); go_pv_schedule();
 }
}
add_action('admin_init','go_pv_install',-10);
add_action('after_switch_theme','go_pv_install',20);
function go_pv_schedule( $delay = 30 ) {
 $delay=max(10,min(120,(int)$delay));
 if ( ! wp_next_scheduled('go_pv_sync') ) { wp_schedule_single_event(time()+$delay,'go_pv_sync'); }
}

/** One cursor, transactional batch and a short lease prevent double counting. No visitor identifiers are copied. */
function go_pv_collect( $limit=2000 ) {
 if ( ! go_pv_available() ) { return; }
 global $wpdb; $t=go_pv_tables(); $lock='go_pv_sync_lock'; $lease=(string)(time()+60);
 // Compare-and-delete the exact expired lease: another worker's lease is never removed.
 $old=get_option($lock);
 if ($old && (int)$old<time()) {
  $wpdb->query($wpdb->prepare("DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s",$lock,(string)$old));
  wp_cache_delete($lock,'options');
 }
 if (!add_option($lock,$lease,'',false)) { return; }
 try {
  $limit=max(1,min(10000,(int)$limit));
  $wpdb->query('START TRANSACTION');
  $cursor=(int)$wpdb->get_var("SELECT last_id FROM {$t['state']} WHERE id=1");
  $rows=$wpdb->get_results($wpdb->prepare("SELECT ID,page_id,page_type,time FROM {$t['source']} WHERE ID>%d ORDER BY ID ASC LIMIT %d",$cursor,$limit),ARRAY_A);
  if ($wpdb->last_error) { throw new RuntimeException('source-unavailable'); }
  $totals=array();$days=array();$next=$cursor;
  foreach ((array)$rows as $r) {
   $next=max($next,(int)$r['ID']); $id=(int)$r['page_id'];
   // A positive page_id is globally unique in WordPress. Do not require page_type:
   // Burst 3.7 migrations/SHORTINIT hits can legitimately leave that label blank
   // while the post ID remains correct, which previously made Today freeze at 0.
   if ($id<1) { continue; }
   $day=wp_date('Y-m-d',(int)$r['time'],wp_timezone());
   $totals[$id]=($totals[$id]??0)+1;
   $days[$day][$id]=($days[$day][$id]??0)+1;
  }
  if ($totals) {
   $values=array(); foreach($totals as $id=>$n) { $values[]=$wpdb->prepare('(%d,%d)',$id,$n); }
   if(false===$wpdb->query("INSERT INTO {$t['total']} (post_id,views) VALUES ".implode(',',$values).' ON DUPLICATE KEY UPDATE views=views+VALUES(views)')) { throw new RuntimeException('total-write'); }
  }
  if ($days) {
   $values=array();foreach($days as $day=>$posts) { foreach($posts as $id=>$n) { $values[]=$wpdb->prepare('(%s,%d,%d)',$day,$id,$n); } }
   if(false===$wpdb->query("INSERT INTO {$t['daily']} (day_key,post_id,views) VALUES ".implode(',',$values).' ON DUPLICATE KEY UPDATE views=views+VALUES(views)')) { throw new RuntimeException('daily-write'); }
  }
  if(false===$wpdb->query($wpdb->prepare("UPDATE {$t['state']} SET last_id=%d,updated_at=%d WHERE id=1",$next,time()))) { throw new RuntimeException('cursor-write'); }
  if(false===$wpdb->query('COMMIT')) { throw new RuntimeException('commit'); }
  delete_option('go_pv_sync_error');
  update_option('go_pv_bootstrapped',count((array)$rows)<$limit?1:0,false);
  if(count((array)$rows)===$limit) { go_pv_schedule(20); }
 } catch (Throwable $e) {
  $wpdb->query('ROLLBACK'); update_option('go_pv_sync_error','Sincronização pendente; os últimos dados foram preservados.',false);go_pv_schedule(60);
 } finally {
  $wpdb->query($wpdb->prepare("DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s",$lock,$lease));wp_cache_delete($lock,'options');
 }
}
function go_pv_cron() { go_pv_collect(3000); if(go_pv_available()&&!wp_next_scheduled('go_pv_sync')){wp_schedule_single_event(time()+60,'go_pv_sync');} }
add_action('go_pv_sync','go_pv_cron');
// Burst's own consent/filtering and beacon decide whether a view exists. No second tracker.
add_action('burst_after_create_statistic',static function(){ go_pv_schedule(30); },20);

function go_pv_state_snapshot( $with_source = false ) {
 global $wpdb; $t=go_pv_tables();
 $state=$wpdb->get_row("SELECT last_id,updated_at FROM {$t['state']} WHERE id=1",ARRAY_A);
 $out=array('last_id'=>(int)($state['last_id']??0),'updated_at'=>(int)($state['updated_at']??0),'source_last_id'=>0,'ok'=>!$wpdb->last_error);
 if($with_source&&$out['ok']){$out['source_last_id']=(int)$wpdb->get_var("SELECT MAX(ID) FROM {$t['source']}");$out['ok']=!$wpdb->last_error;}
 return $out;
}

/**
 * Live Burst read for the posts currently visible in wp-admin.
 *
 * Burst 3.7+ normally records frontend hits through endpoint.php with SHORTINIT.
 * The active theme is intentionally not loaded on that hot path, so a theme
 * hook cannot be used as the source of truth for instant counters. Read the
 * rows Burst has already committed instead. The native (page_id,page_type)
 * index keeps the post-id lookup bounded; page_url is only used as a fallback
 * when a post has no positive page_id rows (old/migrated/identifier edge case).
 */
function go_pv_live_source_counts( array $ids ) {
 global $wpdb; $t=go_pv_tables();
 $ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$ids)))),0,100);
 $out=array();foreach($ids as $id){$out[$id]=array('today'=>0,'total'=>0);}
 if(!$ids){return array('counts'=>$out,'ok'=>true,'as_of'=>time());}

 // Burst stores Unix timestamps. Query only the local current day: this keeps
 // the admin request bounded even on a large lifetime table and bypasses any
 // stale/missing page_type label. `page_id` is enough because WP IDs are unique
 // across posts/pages/CPTs.
 $today=current_datetime()->setTime(0,0,0);
 $today_start=$today->getTimestamp();
 $now=time();
 $cache_key='go_pv_today_'.md5(implode(',',$ids).'|'.$today->format('Y-m-d'));
 $cached=get_transient($cache_key);
 if(is_array($cached)){
  foreach($ids as $id){if(isset($cached[$id])){$out[$id]['today']=max(0,(int)$cached[$id]);$out[$id]['total']=$out[$id]['today'];}}
  return array('counts'=>$out,'ok'=>true,'as_of'=>time(),'cached'=>true);
 }

 $in=implode(',',$ids);
 $rows=$wpdb->get_results($wpdb->prepare(
  "SELECT page_id,COUNT(*) views FROM {$t['source']} WHERE time >= %d AND time <= %d AND page_id IN ($in) GROUP BY page_id",
  $today_start,$now
 ),ARRAY_A);
 if($wpdb->last_error){return array('counts'=>$out,'ok'=>false,'as_of'=>time());}
 $cache=array();
 foreach($ids as $id){$cache[$id]=0;}
 foreach((array)$rows as $r){$id=absint($r['page_id']??0);if(isset($out[$id])){$n=max(0,(int)($r['views']??0));$out[$id]['today']=$n;$out[$id]['total']=$n;$cache[$id]=$n;}}
 set_transient($cache_key,$cache,20);
 return array('counts'=>$out,'ok'=>true,'as_of'=>time(),'cached'=>false);
}

/**
 * Read-only overlay for Burst rows that already exist but have not reached the
 * indexed read model yet. The admin counter can therefore refresh quickly
 * without forcing a write-heavy collector pass on every pulse.
 */
function go_pv_pending_counts( array $ids, $cursor, $limit = 5000 ) {
 global $wpdb; $t=go_pv_tables();
 $ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$ids)))),0,100);
 $out=array();foreach($ids as $id){$out[$id]=array('today'=>0,'total'=>0);}
 if(!$ids){return array('counts'=>$out,'ok'=>true,'complete'=>true);}
 $limit=max(100,min(5000,(int)$limit));
 $rows=$wpdb->get_results($wpdb->prepare("SELECT ID,page_id,page_type,time FROM {$t['source']} WHERE ID>%d ORDER BY ID DESC LIMIT %d",max(0,(int)$cursor),$limit),ARRAY_A);
 if($wpdb->last_error){return array('counts'=>$out,'ok'=>false,'complete'=>false);}
 $wanted=array_fill_keys($ids,true);$day=current_datetime()->format('Y-m-d');
 foreach((array)$rows as $r){
  $id=(int)($r['page_id']??0);if($id<1||!isset($wanted[$id])){continue;}
  $out[$id]['total']++;
  if($day===wp_date('Y-m-d',(int)($r['time']??0),wp_timezone())){$out[$id]['today']++;}
 }
 // Fewer rows than the limit means every pending row was read.
 return array('counts'=>$out,'ok'=>true,'complete'=>count((array)$rows)<$limit);
}

/**
 * Cheap live overlay: compact aggregate + a very small uncollected Burst tail.
 *
 * The wp-admin list must never run lifetime COUNT(*) scans on Burst's raw table.
 * When the cursor is current, these numbers are exact. If more than the bounded
 * pending tail is waiting, we return null and let the background collector catch
 * up; the UI keeps the last compact aggregate instead of doing expensive work.
 */
function go_pv_live_overlay_counts( array $ids, $pending_limit = 1000 ) {
 $ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$ids)))),0,100);
 $pending_limit=max(100,min(2000,(int)$pending_limit));
 if(!$ids||get_option('go_pv_sync_error')||!get_option('go_pv_bootstrapped')){return null;}
 global $wpdb;$t=go_pv_tables();$in=implode(',',$ids);$aggregate=array();$pending=array();$read_ok=false;
 $wpdb->query('START TRANSACTION WITH CONSISTENT SNAPSHOT');
 try{
  $cursor=$wpdb->get_var("SELECT last_id FROM {$t['state']} WHERE id=1");
  $rows=$wpdb->get_results($wpdb->prepare("SELECT v.post_id,v.views total,COALESCE(d.views,0) today FROM {$t['total']} v LEFT JOIN {$t['daily']} d ON d.post_id=v.post_id AND d.day_key=%s WHERE v.post_id IN ($in)",current_datetime()->format('Y-m-d')),ARRAY_A);
  $read_ok=null!==$cursor&&!$wpdb->last_error;
  if($read_ok){
   foreach((array)$rows as $r){$aggregate[(int)$r['post_id']]=array('today'=>(int)$r['today'],'total'=>(int)$r['total']);}
   $pending=go_pv_pending_counts($ids,(int)$cursor,$pending_limit);
  }
 }finally{$wpdb->query('COMMIT');}
 if(!$read_ok||empty($pending['ok'])||empty($pending['complete'])){return null;}
 $out=array();
 foreach($ids as $id){
  $c=(array)($pending['counts'][$id]??array());
  $out[$id]=array('today'=>(int)($aggregate[$id]['today']??0)+(int)($c['today']??0),'total'=>(int)($aggregate[$id]['total']??0)+(int)($c['total']??0));
 }
 // Do not fall back to lifetime COUNT(*) scans from wp-admin. If a historical
 // edge case needs repair, the sequential collector fixes it in background.
 return array('counts'=>$out,'ok'=>true,'as_of'=>time());
}

/** One bounded indexed batch, shared by all editor tabs through the collector lease. */
function go_pv_sync_if_needed( $max_age = 8, $limit = 2000 ) {
 if(!go_pv_available()){return false;}
 $state=go_pv_state_snapshot(false);
 if(!$state['ok']){go_pv_schedule();return false;}
 if($state['updated_at'] && time()-$state['updated_at']<max(8,(int)$max_age)){return false;}
 // The admin list is the newsroom's fallback when WP-Cron is delayed or blocked.
 // Keep the read model close enough to Burst that server-side Today/Total sorting
 // does not depend on a cron request having happened in the previous minute.
 go_pv_collect(max(1,min(10000,(int)$limit)));
 return true;
}

/**
 * Reconcile the last few local days directly from Burst after the 3.85.10 fix.
 *
 * Older collectors discarded otherwise valid hits when page_type was blank.
 * We repair only a short recent window (cheap, indexed by time) and add the
 * difference to lifetime totals; no raw visitor/session data is copied.
 */
function go_pv_reconcile_recent_days( $days = 3 ) {
 if(!go_pv_available()){return false;}
 global $wpdb;$t=go_pv_tables();$days=max(1,min(7,(int)$days));$tz=wp_timezone();$today=new DateTimeImmutable('today',$tz);
 for($offset=0;$offset<$days;$offset++){
  $start=$today->modify('-'.$offset.' days');$end=$start->modify('+1 day');$day=$start->format('Y-m-d');
  $rows=$wpdb->get_results($wpdb->prepare(
   "SELECT page_id,COUNT(*) views FROM {$t['source']} WHERE time >= %d AND time < %d AND page_id > 0 GROUP BY page_id",
   $start->getTimestamp(),$end->getTimestamp()
  ),ARRAY_A);
  if($wpdb->last_error){update_option('go_pv_recent_reconcile_error','Burst: falha ao reconciliar '.$day,false);return false;}
  if(!$rows){continue;}
  $ids=array_values(array_unique(array_map(static fn($r)=>absint($r['page_id']??0),(array)$rows)));$ids=array_values(array_filter($ids));
  if(!$ids){continue;}$in=implode(',',$ids);
  $existing_rows=$wpdb->get_results($wpdb->prepare("SELECT post_id,views FROM {$t['daily']} WHERE day_key=%s AND post_id IN ($in)",$day),ARRAY_A);
  $existing=array();foreach((array)$existing_rows as $r){$existing[(int)$r['post_id']]=(int)$r['views'];}
  $daily_values=array();$diffs=array();
  foreach((array)$rows as $r){$id=absint($r['page_id']??0);$raw=max(0,(int)($r['views']??0));if(!$id){continue;}$old=max(0,(int)($existing[$id]??0));$daily_values[]=$wpdb->prepare('(%s,%d,%d)',$day,$id,$raw);if($raw>$old){$diffs[$id]=$raw-$old;}}
  if($daily_values){$wpdb->query("INSERT INTO {$t['daily']} (day_key,post_id,views) VALUES ".implode(',',$daily_values).' ON DUPLICATE KEY UPDATE views=VALUES(views)');if($wpdb->last_error){return false;}}
  if($diffs){$values=array();foreach($diffs as $id=>$n){$values[]=$wpdb->prepare('(%d,%d)',$id,$n);} $wpdb->query("INSERT INTO {$t['total']} (post_id,views) VALUES ".implode(',',$values).' ON DUPLICATE KEY UPDATE views=views+VALUES(views)');if($wpdb->last_error){return false;}}
 }
 delete_option('go_pv_recent_reconcile_error');
 update_option('go_pv_reconciled_version',defined('GO_VERGE_VERSION')?GO_VERGE_VERSION:'3.85.10',false);
 return true;
}
add_action('go_pv_reconcile_recent',static function(){go_pv_reconcile_recent_days(3);});
add_action('admin_init',static function(){
 if(!go_pv_available()){return;}
 $version=defined('GO_VERGE_VERSION')?(string)GO_VERGE_VERSION:'3.85.10';
 if((string)get_option('go_pv_reconciled_version','')===$version){return;}
 if(!wp_next_scheduled('go_pv_reconcile_recent')){wp_schedule_single_event(time()+5,'go_pv_reconcile_recent');}
},5);

/** Percentile rank inside an Overdrive-owned benchmark distribution. */
function go_pv_success_percentile( $value, array $values ) {
 $n=count($values);if(!$n){return 50.0;}$value=max(0.0,(float)$value);
 // Benchmark arrays are stored already sorted. Binary search keeps the live
 // wp-admin pulse cheap even with a newsroom-sized comparison cohort.
 $lo=0;$hi=$n;while($lo<$hi){$mid=(int)(($lo+$hi)>>1);if((float)$values[$mid]<$value){$lo=$mid+1;}else{$hi=$mid;}}$lower=$lo;
 $lo=$lower;$hi=$n;while($lo<$hi){$mid=(int)(($lo+$hi)>>1);if((float)$values[$mid]<=$value){$lo=$mid+1;}else{$hi=$mid;}}$upper=$lo;
 return max(0.0,min(100.0,(($lower+(0.5*($upper-$lower)))/$n)*100));
}

/** Quantile helper used only for dynamic newsroom expectations. */
function go_pv_success_quantile( array $values, $q = 0.5 ) {
 $n=count($values);if(!$n){return 0.0;}$q=max(0.0,min(1.0,(float)$q));$index=($n-1)*$q;$lo=(int)floor($index);$hi=(int)ceil($index);if($lo===$hi){return (float)$values[$lo];}$w=$index-$lo;return ((float)$values[$lo]*(1-$w))+((float)$values[$hi]*$w);
}

/** Current post cohort: editorial pillar + content type, with safe fallbacks. */
function go_pv_success_context( $post_id ) {
 $post_id=absint($post_id);$root_id=0;$root_name='Site inteiro';$type='';$type_name='';
 $primary=absint(get_post_meta($post_id,'_go_primary_category_id',true));if(!$primary){$primary=absint(get_post_meta($post_id,'rank_math_primary_category',true));}
 if(!$primary&&function_exists('go_verge_primary_category')){$term=go_verge_primary_category($post_id);if($term instanceof WP_Term){$primary=(int)$term->term_id;}}
 if($primary){$term=get_term($primary,'category');if($term instanceof WP_Term){$root=$term;while($root instanceof WP_Term&&$root->parent){$parent=get_term((int)$root->parent,'category');if(!($parent instanceof WP_Term)){break;}$root=$parent;}$root_id=(int)$root->term_id;$root_name=(string)$root->name;}}
 if(function_exists('go_verge_v7_post_content_type')){$type=sanitize_title((string)go_verge_v7_post_content_type($post_id));}
 if(!$type&&taxonomy_exists('go_content_type')){$slugs=wp_get_post_terms($post_id,'go_content_type',array('fields'=>'slugs'));if(!is_wp_error($slugs)&&$slugs){$type=sanitize_title((string)$slugs[0]);}}
 if($type&&taxonomy_exists('go_content_type')){$term=get_term_by('slug',$type,'go_content_type');if($term instanceof WP_Term){$type_name=(string)$term->name;}}
 return array('root_id'=>$root_id,'root_name'=>$root_name,'type'=>$type,'type_name'=>$type_name?:($type?ucfirst(str_replace('-',' ',$type)):'Todos os formatos'));
}

/** Add one metric triplet to a benchmark bucket. */
function go_pv_success_bucket_add( array &$bucket, $launch, $today, $life, $hot ) {
 foreach(array('launch'=>$launch,'today'=>$today,'lifetime'=>$life) as $key=>$value){if(!isset($bucket[$key])){$bucket[$key]=array();}$bucket[$key][]=(float)$value;if($hot){$hot_key=$key.'_hot';if(!isset($bucket[$hot_key])){$bucket[$hot_key]=array();}$bucket[$hot_key][]=(float)$value;}}
 $bucket['count']=isset($bucket['count'])?(int)$bucket['count']+1:1;if($hot){$bucket['hot_count']=isset($bucket['hot_count'])?(int)$bucket['hot_count']+1:1;}
}

/** Sort every distribution in one bucket once, before caching. */
function go_pv_success_bucket_sort( array &$bucket ) {
 foreach(array('launch','today','lifetime','launch_hot','today_hot','lifetime_hot') as $key){if(isset($bucket[$key])&&is_array($bucket[$key])){sort($bucket[$key],SORT_NUMERIC);}}
}

/**
 * Recent, contextual newsroom benchmark.
 *
 * The old 60-day site-wide percentile could make a 20-view article look
 * average simply because many old/quiet posts sat at zero. This model keeps
 * the benchmark close to today's newsroom reality: 21 days overall, with a
 * 7-day hot window weighted more heavily, and compares like with like when
 * there is enough sample (pillar + format, then pillar, then site).
 */
function go_pv_success_benchmark() {
 $cache=get_transient('go_pv_success_benchmark_v3');if(is_array($cache)&&!empty($cache['site']['count'])){return $cache;}
 global $wpdb;$t=go_pv_tables();$now=current_datetime();$tz=wp_timezone();$day=$now->format('Y-m-d');$midnight=$now->setTime(0,0,0);$elapsed_today=max(0.75,($now->getTimestamp()-$midnight->getTimestamp())/HOUR_IN_SECONDS);$start=$now->modify('-14 days')->format('Y-m-d H:i:s');$end=$now->format('Y-m-d H:i:s');$hot_cutoff=$now->modify('-3 days')->getTimestamp();
 $pm_primary=$wpdb->postmeta;$tr=$wpdb->term_relationships;$tt=$wpdb->term_taxonomy;$terms=$wpdb->terms;
 $sql=$wpdb->prepare("SELECT p.ID,p.post_date,COALESCE(tv.views,0) total_views,COALESCE(td.views,0) today_views,COALESCE(pd.views,0) publish_day_views,CASE WHEN ctt.term_id IS NULL THEN 0 WHEN ctt.parent>0 THEN ctt.parent ELSE ctt.term_id END root_cat_id,COALESCE(ctype.content_type,'') content_type FROM {$wpdb->posts} p LEFT JOIN {$t['total']} tv ON tv.post_id=p.ID LEFT JOIN {$t['daily']} td ON td.post_id=p.ID AND td.day_key=%s LEFT JOIN {$t['daily']} pd ON pd.post_id=p.ID AND pd.day_key=DATE(p.post_date) LEFT JOIN {$pm_primary} pm1 ON pm1.post_id=p.ID AND pm1.meta_key='_go_primary_category_id' LEFT JOIN {$pm_primary} pm2 ON pm2.post_id=p.ID AND pm2.meta_key='rank_math_primary_category' LEFT JOIN {$tt} ctt ON ctt.term_id=CAST(COALESCE(NULLIF(pm1.meta_value,''),NULLIF(pm2.meta_value,''),'0') AS UNSIGNED) AND ctt.taxonomy='category' LEFT JOIN (SELECT rel.object_id,MAX(term.slug) content_type FROM {$tr} rel INNER JOIN {$tt} tax ON tax.term_taxonomy_id=rel.term_taxonomy_id AND tax.taxonomy='go_content_type' INNER JOIN {$terms} term ON term.term_id=tax.term_id GROUP BY rel.object_id) ctype ON ctype.object_id=p.ID WHERE p.post_type='post' AND p.post_status='publish' AND p.post_date>=%s AND p.post_date<=%s ORDER BY p.post_date DESC LIMIT 1200",$day,$start,$end);
 $rows=$wpdb->get_results($sql,ARRAY_A);if($wpdb->last_error){return array('site'=>array('count'=>0),'roots'=>array(),'combos'=>array(),'window'=>14,'hot_window'=>3);}
 $out=array('site'=>array(),'roots'=>array(),'combos'=>array(),'window'=>14,'hot_window'=>3,'generated'=>time());
 foreach((array)$rows as $row){try{$published=new DateTimeImmutable((string)$row['post_date'],$tz);}catch(Throwable $e){continue;}$age_hours=max(0.01,($now->getTimestamp()-$published->getTimestamp())/HOUR_IN_SECONDS);if($age_hours<0.50){continue;}$same_day=$published->format('Y-m-d')===$day;if($same_day){$launch_hours=max(0.75,min($elapsed_today,$age_hours));$launch_views=(float)$row['today_views'];}else{$clock=((int)$published->format('G'))+(((int)$published->format('i'))/60);$launch_hours=max(1.0,24-$clock);$launch_views=(float)$row['publish_day_views'];}$today_hours=$same_day?max(0.75,min($elapsed_today,$age_hours)):$elapsed_today;$age_days=max(1.0,$age_hours/24);$launch=$launch_views/$launch_hours;$today=(float)$row['today_views']/max(0.75,$today_hours);$life=(float)$row['total_views']/$age_days;$hot=$published->getTimestamp()>=$hot_cutoff;$root=absint($row['root_cat_id']);$type=sanitize_title((string)$row['content_type']);
  go_pv_success_bucket_add($out['site'],$launch,$today,$life,$hot);if($root){if(!isset($out['roots'][$root])){$out['roots'][$root]=array();}go_pv_success_bucket_add($out['roots'][$root],$launch,$today,$life,$hot);if($type){$combo=$root.'|'.$type;if(!isset($out['combos'][$combo])){$out['combos'][$combo]=array();}go_pv_success_bucket_add($out['combos'][$combo],$launch,$today,$life,$hot);}}
 }
 go_pv_success_bucket_sort($out['site']);foreach($out['roots'] as &$bucket){go_pv_success_bucket_sort($bucket);}unset($bucket);foreach($out['combos'] as &$bucket){go_pv_success_bucket_sort($bucket);}unset($bucket);set_transient('go_pv_success_benchmark_v3',$out,2*MINUTE_IN_SECONDS);return $out;
}

/** Pick the narrowest trustworthy cohort. */
function go_pv_success_pick_bucket( array $benchmark, array $context ) {
 $root=absint($context['root_id']??0);$type=sanitize_title((string)($context['type']??''));$combo=$root&&$type?$root.'|'.$type:'';
 if($combo&&!empty($benchmark['combos'][$combo]['count'])&&(int)$benchmark['combos'][$combo]['count']>=12){return array($benchmark['combos'][$combo],'mesma editoria + formato');}
 if($root&&!empty($benchmark['roots'][$root]['count'])&&(int)$benchmark['roots'][$root]['count']>=18){return array($benchmark['roots'][$root],'mesma editoria');}
 return array((array)($benchmark['site']??array()),'site inteiro');
}

/** Blend last-7-day and last-21-day percentile so the score changes with the newsroom. */
function go_pv_success_recent_percentile( $value, array $bucket, $metric ) {
 $base=(array)($bucket[$metric]??array());$hot=(array)($bucket[$metric.'_hot']??array());$p_base=go_pv_success_percentile($value,$base);if(count($hot)<6){return $p_base;}$p_hot=go_pv_success_percentile($value,$hot);return (0.78*$p_hot)+(0.22*$p_base);
}

/** Lightweight Search/Discover signals for the explanation panel; never a hard gate. */
function go_pv_success_gsc_signals( array $ids ) {
 $out=array();foreach($ids as $id){$out[absint($id)]=array('search_impressions'=>0,'search_clicks'=>0,'search_ctr'=>0.0,'search_position'=>0.0,'discover_clicks'=>0);}
 if(!class_exists('GED_DB')||!method_exists('GED_DB','table')){return $out;}global $wpdb;$ids=array_values(array_filter(array_map('absint',$ids)));if(!$ids){return $out;}$in=implode(',',array_fill(0,count($ids),'%d'));
 $hourly=GED_DB::table('perf_hourly');if($hourly&&function_exists('go_verge_admin_external_table_exists')&&go_verge_admin_external_table_exists($hourly)){$cutoff=current_datetime()->modify('-24 hours')->format('Y-m-d H:00:00');$sql="SELECT post_id,SUM(clicks) clicks,SUM(impressions) impressions,CASE WHEN SUM(impressions)>0 THEN SUM(position*impressions)/SUM(impressions) ELSE 0 END position FROM {$hourly} WHERE source='web' AND hour_bucket>=%s AND post_id IN ($in) GROUP BY post_id";$args=array_merge(array($cutoff),$ids);$rows=$wpdb->get_results($wpdb->prepare($sql,$args),ARRAY_A);foreach((array)$rows as $r){$id=absint($r['post_id']);if(!isset($out[$id]))continue;$imp=(float)$r['impressions'];$clk=(float)$r['clicks'];$out[$id]['search_impressions']=(int)round($imp);$out[$id]['search_clicks']=(int)round($clk);$out[$id]['search_ctr']=$imp>0?$clk/$imp:0.0;$out[$id]['search_position']=max(0.0,(float)$r['position']);}}
 $daily=GED_DB::table('perf_daily');if($daily&&function_exists('go_verge_admin_external_table_exists')&&go_verge_admin_external_table_exists($daily)){$start=wp_date('Y-m-d',time()-6*DAY_IN_SECONDS);$sql="SELECT post_id,SUM(clicks) clicks FROM {$daily} WHERE source='discover' AND metric_date>=%s AND post_id IN ($in) GROUP BY post_id";$args=array_merge(array($start),$ids);$rows=$wpdb->get_results($wpdb->prepare($sql,$args),ARRAY_A);foreach((array)$rows as $r){$id=absint($r['post_id']);if(isset($out[$id])){$out[$id]['discover_clicks']=(int)round((float)$r['clicks']);}}}
 return $out;
}

/** Editorial traffic floor for the current stage of a fresh article.
 *
 * This is deliberately stricter than a pure percentile. A weak week should not
 * make 10–20 views look healthy just because the comparison cohort was also
 * weak. The floor is still filterable for the newsroom as the site grows.
 */
function go_pv_success_editorial_floor_views( $age_hours ) {
 $h=max(0.0,(float)$age_hours);
 if($h<=3){$floor=18*$h;}
 elseif($h<=6){$floor=54+(9*($h-3));}
 elseif($h<=12){$floor=81+(7*($h-6));}
 elseif($h<=24){$floor=123+(4*($h-12));}
 else{$floor=171+(2*min(48,max(0,$h-24)));}
 return max(0.0,(float)apply_filters('go_pv_success_editorial_floor_views',$floor,$h));
}

/** Map actual/reference ratio to a human editorial score. 60 means ordinary. */
function go_pv_success_ratio_score( $ratio ) {
 $r=max(0.0,(float)$ratio);
 $points=array(array(0.00,0),array(0.15,8),array(0.35,20),array(0.60,38),array(0.85,52),array(1.00,62),array(1.20,70),array(1.50,78),array(2.00,87),array(3.00,95),array(5.00,99));
 for($i=1;$i<count($points);$i++){
  if($r<=$points[$i][0]){$a=$points[$i-1];$b=$points[$i];$span=max(.0001,$b[0]-$a[0]);$w=($r-$a[0])/$span;return $a[1]+(($b[1]-$a[1])*$w);}
 }
 return 100.0;
}

/** Friendly age label for editors, avoiding statistical jargon. */
function go_pv_success_age_label( $hours ) {
 $minutes=max(1,(int)round((float)$hours*60));
 if($minutes<60){return $minutes.' min';}
 $h=(int)floor($minutes/60);$m=$minutes%60;
 if($h<24){return $h.'h'.($m?str_pad((string)$m,2,'0',STR_PAD_LEFT):'');}
 $d=(int)floor($h/24);return $d.' dia'.($d===1?'':'s');
}

/** A recent, contextual five-level success signal calibrated to Overdrive itself. */
function go_pv_success_for_post( $post_id, $today_views, $total_views, array $benchmark, $post_date = '', $publish_day_views = 0, $post_status = 'publish', array $gsc = array() ) {
 $neutral=array('level'=>'evaluating','label'=>'Avaliando','score'=>null,'confidence'=>'baixa','title'=>'Ainda é cedo para julgar.','summary'=>'Ainda é cedo para avaliar esta matéria.','facts'=>array('Espere alguns minutos para formar uma amostra mínima de leitura.'),'reasons'=>array(),'actions'=>array('Reveja a nota quando a matéria completar cerca de 45 minutos.'),'basis'=>'amostra inicial','diagnostics'=>array());
 if('publish'!==$post_status||!$post_date||empty($benchmark['site']['count'])||(int)$benchmark['site']['count']<20){return $neutral;}
 $now=current_datetime();$tz=wp_timezone();try{$published=new DateTimeImmutable((string)$post_date,$tz);}catch(Throwable $e){return $neutral;}
 $age_hours=max(0.01,($now->getTimestamp()-$published->getTimestamp())/HOUR_IN_SECONDS);if($age_hours<0.75){return $neutral;}
 $context=go_pv_success_context($post_id);list($bucket,$scope_label)=go_pv_success_pick_bucket($benchmark,$context);if(empty($bucket['count'])){return $neutral;}
 $day=$now->format('Y-m-d');$midnight=$now->setTime(0,0,0);$elapsed_today=max(0.75,($now->getTimestamp()-$midnight->getTimestamp())/HOUR_IN_SECONDS);$same_day=$published->format('Y-m-d')===$day;
 if($same_day){$launch_hours=max(0.75,min($elapsed_today,$age_hours));$launch_views=(float)$today_views;}else{$launch_views=(float)$publish_day_views;$clock=((int)$published->format('G'))+(((int)$published->format('i'))/60);$launch_hours=max(1.0,24-$clock);}
 $today_hours=$same_day?max(0.75,min($elapsed_today,$age_hours)):$elapsed_today;$age_days=max(1.0,$age_hours/24);$launch_rate=$launch_views/$launch_hours;$today_rate=(float)$today_views/max(0.75,$today_hours);$life_rate=(float)$total_views/$age_days;
 $p_launch=go_pv_success_recent_percentile($launch_rate,$bucket,'launch');$p_today=go_pv_success_recent_percentile($today_rate,$bucket,'today');$p_life=go_pv_success_recent_percentile($life_rate,$bucket,'lifetime');
 $recent_launch=(array)($bucket['launch_hot']??array());if(count($recent_launch)<6){$recent_launch=(array)($bucket['launch']??array());}
 $cohort_median=max(0.0,go_pv_success_quantile($recent_launch,0.50)*$launch_hours);
 $cohort_low=max(0.0,go_pv_success_quantile($recent_launch,0.25)*$launch_hours);
 $cohort_high=max(0.0,go_pv_success_quantile($recent_launch,0.75)*$launch_hours);
 $editorial_floor=$same_day?go_pv_success_editorial_floor_views($age_hours):0.0;
 $reference=max(1.0,$cohort_median,$editorial_floor);
 $reference_low=max(1.0,$cohort_low,$editorial_floor*.72);
 $reference_high=max($reference*1.45,$cohort_high,$editorial_floor*1.45);
 $ratio=$launch_views/$reference;$absolute_score=go_pv_success_ratio_score($ratio);
 if($age_hours<=12){$score=(0.60*$absolute_score)+(0.25*$p_launch)+(0.15*$p_today);}elseif($age_hours<=36){$score=(0.42*$absolute_score)+(0.25*$p_launch)+(0.20*$p_today)+(0.13*$p_life);}elseif($age_hours<=96){$score=(0.25*$absolute_score)+(0.25*$p_launch)+(0.28*$p_today)+(0.22*$p_life);}else{$score=(0.15*$absolute_score)+(0.15*$p_launch)+(0.42*$p_today)+(0.28*$p_life);}

 $imp=(int)($gsc['search_impressions']??0);$pos=(float)($gsc['search_position']??0);$ctr=(float)($gsc['search_ctr']??0);$discover=(int)($gsc['discover_clicks']??0);
 if($imp>=30&&$pos>0){if($pos<=10&&$ctr>=.025){$score+=4;}elseif($pos<=10&&$ctr<.012){$score-=4;}elseif($pos>20){$score-=2;}}
 if($discover>=10){$score+=3;}

 /* Absolute reality wins over a weak cohort. */
 if($same_day&&$age_hours>=1.5&&(int)$today_views<=20){$score=min($score,34);}
 if($same_day&&$ratio<.25&&$age_hours>=1.25){$score=min($score,18);}
 elseif($same_day&&$ratio<.45&&$age_hours>=2){$score=min($score,28);}
 elseif($same_day&&$ratio<.65&&$age_hours>=3){$score=min($score,42);}
 $score=max(0,min(100,$score));$score_i=(int)round($score);

 if($score_i>=88){$level='excellent';$label='Excelente';$status_line='Muito acima do esperado';}
 elseif($score_i>=72){$level='good';$label='Bom';$status_line='Acima do esperado';}
 elseif($score_i>=48){$level='median';$label='Mediano';$status_line='Dentro da faixa, mas sem destaque';}
 elseif($score_i>=25){$level='weak';$label='Fraco';$status_line='Abaixo do esperado';}
 else{$level='poor';$label='Péssimo';$status_line='Muito abaixo do esperado';}

 $facts=array();$reasons=array();$actions=array();$age_label=go_pv_success_age_label($age_hours);$gap_pct=(int)round(abs(1-$ratio)*100);
 $facts[]=sprintf('Em %s, a matéria fez %d view%s.',$age_label,(int)$launch_views,1===(int)$launch_views?'':'s');
 if($same_day){$facts[]=sprintf('Para este estágio, a referência do Overdrive é cerca de %d views (faixa útil ~%d–%d).',(int)round($reference),(int)round($reference_low),(int)round($reference_high));}
 if($ratio<1){$facts[]=sprintf('Está aproximadamente %d%% abaixo dessa referência.',$gap_pct);}elseif($ratio>1.05){$facts[]=sprintf('Está aproximadamente %d%% acima dessa referência.',(int)round(($ratio-1)*100));}else{$facts[]='Está muito perto da referência esperada para este momento.';}
 if($p_launch<=20){$reasons[]='O arranque está entre os mais fracos das matérias parecidas publicadas recentemente.';}
 elseif($p_launch<45){$reasons[]='O arranque está abaixo da maior parte das matérias parecidas.';}
 elseif($p_launch>=85){$reasons[]='O arranque está entre os melhores das matérias parecidas.';}
 else{$reasons[]='O ritmo inicial está próximo do comportamento normal das matérias parecidas.';}
 if($same_day&&$age_hours>=1.5&&(int)$today_views<=20){$reasons[]='O volume absoluto ainda é baixo: mesmo uma comparação relativa favorável não transforma 20 views ou menos em bom resultado.';}
 if($imp>=20&&$pos>0){
  if($pos<=10&&$ctr<.018){$reasons[]=sprintf('O Google já mostra a URL na 1ª página (posição %.1f), mas poucos usuários clicam (CTR %.1f%%).',$pos,$ctr*100);$actions[]='Ajustar título SEO e descrição para deixar a promessa mais específica, sem mudar a intenção da URL.';}
  elseif($pos<=10){$reasons[]=sprintf('Search está ajudando: posição média %.1f nas últimas horas, com %d impressões.',$pos,$imp);}
  elseif($pos<=20){$reasons[]=sprintf('O Google encontra a matéria, mas ela ainda aparece fora do top 10 (posição %.1f).',$pos);$actions[]='Fortalecer a resposta principal e links internos de páginas fortes do mesmo assunto.';}
  else{$reasons[]=sprintf('Há impressões no Google, mas a posição média %.1f ainda limita bastante os cliques.',$pos);$actions[]='Revisar se a matéria responde exatamente à intenção das consultas que o Google está mostrando.';}
 }elseif($age_hours>=4&&$imp===0){$reasons[]='Ainda não há sinal recente de Search para esta URL. Isso não significa, sozinho, que ela esteja desindexada.';$actions[]='Se Search for importante para a pauta, conferir URL/canonical no Search Console e criar links internos para a matéria.';}
 if($discover>0){$reasons[]=sprintf('Discover já trouxe %d clique%s; há sinal de distribuição fora da busca.',$discover,1===$discover?'':'s');}

 $title=(string)get_the_title($post_id);$title_len=function_exists('mb_strlen')?mb_strlen(wp_strip_all_tags($title)):strlen(wp_strip_all_tags($title));
 if($score_i<48){
  $actions[]='Revisar título e capa: em matérias fracas, a primeira pergunta é se a promessa está clara e forte o suficiente para gerar clique.';
  $actions[]='Recircular agora em posições reais do site: Home, “Leia também” e links de matérias fortes do mesmo assunto.';
 }
 if($title_len>92){$actions[]='Encurtar o título e colocar entidade + fato + consequência antes do corte.';}elseif($title_len<35&&$score_i<72){$actions[]='Checar se o título está genérico demais; deixe claro quem/que, o que aconteceu e por que importa.';}
 if(!has_post_thumbnail($post_id)){$actions[]='Adicionar uma imagem destacada forte e claramente relacionada à pauta.';}
 if($score_i>=88){$actions[]='Preservar a matéria e aproveitar a demanda com um desdobramento realmente complementar.';}elseif($score_i>=72&&empty($actions)){$actions[]='Não mexer por ansiedade: manter distribuição e observar se o ritmo se sustenta.';}elseif($score_i>=48&&empty($actions)){$actions[]='Antes de reescrever, testar um ganho pequeno e mensurável em título, capa ou recirculação.';}

 $next_label='';$next_target=0;
 foreach(array(3,6,12,24) as $checkpoint){if($age_hours<$checkpoint){$next_label=$checkpoint.'h';$next_target=(int)round(max(go_pv_success_editorial_floor_views($checkpoint),$reference*($checkpoint/max(.75,$age_hours))*.75));break;}}
 if($next_label){$actions[]=sprintf('Próxima checagem: ao completar %s, use ~%d views como referência mínima de recuperação — não como meta garantida.',$next_label,$next_target);}

 $sample=(int)($bucket['hot_count']??0);if($sample<6){$sample=(int)($bucket['count']??0);}$confidence_score=min(1.0,($age_hours/6))*min(1.0,max(0.35,$sample/24));$confidence=$confidence_score>=0.72?'alta':($confidence_score>=0.42?'média':'baixa');
 $confidence_note='baixa'===$confidence?'Ainda é cedo; a nota pode mudar rápido.':('média'===$confidence?'Já existe uma amostra razoável, mas ainda pode oscilar.':'Já há tempo e amostra suficientes para uma leitura mais firme.');
 $basis_parts=array($scope_label,'últimos 3–14 dias','n='.$sample);if(!empty($context['root_name'])){$basis_parts[]=$context['root_name'];}if(!empty($context['type_name'])){$basis_parts[]=$context['type_name'];}$basis=implode(' · ',array_values(array_unique($basis_parts)));
 $reasons=array_values(array_unique(array_slice($reasons,0,5)));$actions=array_values(array_unique(array_slice($actions,0,4)));$facts=array_values(array_unique(array_slice($facts,0,4)));
 $summary=$status_line.'. '.($ratio<1?sprintf('%d views contra referência de ~%d neste estágio.',(int)$launch_views,(int)round($reference)):sprintf('%d views contra referência de ~%d neste estágio.',(int)$launch_views,(int)round($reference)));
 $title_text=sprintf('%s · %d/100. %s',$label,$score_i,$summary);
 return array('level'=>$level,'label'=>$label,'score'=>$score_i,'confidence'=>$confidence,'confidenceNote'=>$confidence_note,'title'=>$title_text,'summary'=>$summary,'facts'=>$facts,'reasons'=>$reasons,'actions'=>$actions,'basis'=>$basis,'statusLine'=>$status_line,'nextCheckpoint'=>$next_label,'nextTarget'=>$next_target,'diagnostics'=>$facts,'metrics'=>array('launch_percentile'=>(int)round($p_launch),'today_percentile'=>(int)round($p_today),'lifetime_percentile'=>(int)round($p_life),'reference'=>(int)round($reference),'reference_low'=>(int)round($reference_low),'reference_high'=>(int)round($reference_high),'editorial_floor'=>(int)round($editorial_floor),'ratio'=>round($ratio,3),'age_hours'=>round($age_hours,1),'sample'=>$sample));
}

function go_pv_counts( array $ids, $with_success = true ) {
 global $wpdb; $t=go_pv_tables();
 $ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$ids)))),0,100);
 $out=array();foreach($ids as $id){$out[$id]=array('today'=>0,'total'=>0,'success'=>array('level'=>'evaluating','label'=>'Avaliando','score'=>null,'title'=>'Avaliando desempenho.'));}
 if(!$ids||!go_pv_available()){return array('counts'=>$out,'ready'=>false,'available'=>false);}
 $in=implode(',',$ids);$day=current_datetime()->format('Y-m-d');$meta=array();
 // Keep the indexed read model for sorting/benchmarks and as a cheap fallback.
 $rows=$wpdb->get_results($wpdb->prepare("SELECT p.ID post_id,p.post_date,p.post_status,COALESCE(v.views,0) total,COALESCE(d.views,0) today,COALESCE(pd.views,0) publish_day_views FROM {$wpdb->posts} p LEFT JOIN {$t['total']} v ON v.post_id=p.ID LEFT JOIN {$t['daily']} d ON d.post_id=p.ID AND d.day_key=%s LEFT JOIN {$t['daily']} pd ON pd.post_id=p.ID AND pd.day_key=DATE(p.post_date) WHERE p.ID IN ($in)",$day),ARRAY_A);
 $base_ok=!$wpdb->last_error;
 foreach((array)$rows as $r){$id=(int)$r['post_id'];$out[$id]['today']=(int)$r['today'];$out[$id]['total']=(int)$r['total'];$meta[$id]=array('post_date'=>(string)$r['post_date'],'publish_day_views'=>(int)$r['publish_day_views'],'post_status'=>(string)$r['post_status']);}

 // Every visible post receives the live Burst overlay. Previously only fresh
 // posts/zero-count rows did, which meant an older article could keep showing a
 // stale Today/Total value whenever WP-Cron lagged. The overlay normally reads
 // only rows newer than our cursor and falls back to Burst's indexed page_id
 // lookup if the cursor is too far behind.
 $live_ids=$ids;
 // Normal wp-admin refreshes never scan a post's lifetime rows in Burst. They
 // read the compact aggregate plus at most a 1,000-row uncollected tail. If the
 // cursor falls farther behind, the background collector catches up instead of
 // making the editor wait on a large raw-table COUNT(*).
 $live=$base_ok?go_pv_live_overlay_counts($live_ids,1000):null;
 $live_ok=is_array($live)&&!empty($live['ok']);
 if($live_ok){foreach($live_ids as $id){$c=(array)($live['counts'][$id]??array());$out[$id]['today']=max((int)$out[$id]['today'],(int)($c['today']??0));$out[$id]['total']=max((int)$out[$id]['total'],(int)($c['total']??0));}}

 // Source-of-truth overlay for TODAY. Burst 3.7 can have correct positive
 // page_id values with an empty/legacy page_type, so relying on page_type made
 // the newsroom counter show zero even while Burst itself had the hit. The
 // query is bounded to the current day and visible post IDs only.
 $source_today=go_pv_live_source_counts($live_ids);
 $source_ok=is_array($source_today)&&!empty($source_today['ok']);
 if($source_ok){
  foreach($live_ids as $id){
   $raw=max(0,(int)($source_today['counts'][$id]['today']??0));
   $known_today=max(0,(int)$out[$id]['today']);
   if($raw>$known_today){
    // Totals from the compact model may have missed the same unlabeled rows.
    // Add only the missing part of today, avoiding double counting.
    $out[$id]['total']=max(0,(int)$out[$id]['total'])+($raw-$known_today);
    $out[$id]['today']=$raw;
   }
  }
 }

 if(($base_ok||$live_ok||$source_ok)&&$with_success){$benchmark=go_pv_success_benchmark();$gsc=go_pv_success_gsc_signals($ids);foreach($ids as $id){$m=(array)($meta[$id]??array());$out[$id]['success']=go_pv_success_for_post($id,(int)$out[$id]['today'],(int)$out[$id]['total'],$benchmark,(string)($m['post_date']??''),(int)($m['publish_day_views']??0),(string)($m['post_status']??''),(array)($gsc[$id]??array()));}}
 if(!$with_success){foreach($ids as $id){unset($out[$id]['success']);}}
 $state=go_pv_state_snapshot(false);$aggregate_ready=$base_ok&&!get_option('go_pv_sync_error')&&!empty($state['ok'])&&get_option('go_pv_bootstrapped');
 if(!$aggregate_ready||!$state['updated_at']||(time()-$state['updated_at'])>90){go_pv_schedule(30);}
 $ready=$source_ok||$live_ok||$aggregate_ready;$as_of=$source_ok?(int)($source_today['as_of']??time()):($live_ok?(int)($live['as_of']??time()):(int)$state['updated_at']);
 return array('counts'=>$out,'available'=>(bool)($base_ok||$live_ok||$source_ok),'ready'=>(bool)$ready,'stale'=>$ready?false:true,'as_of'=>$as_of,'checked_at'=>time(),'day'=>$day,'timezone'=>wp_timezone_string(),'source'=>$source_ok?'Burst direto hoje + índice Overdrive':'índice Overdrive + pendências recentes','success_basis'=>'Overdrive contextual 3d/14d');
}

/** Exclude just Posts from Burst's per-cell renderer; other post types keep their integration. */
add_filter('burst_column_post_types',static function($types){return go_pv_available()?array_values(array_diff($types,array('post'))):$types;});
add_action('admin_init',static function(){
 if(!go_pv_available()){return;}
 global $wp_filter;
 // Remove only the named Burst sorter, before it installs its unscoped aggregate joins.
 foreach(($wp_filter['pre_get_posts']->callbacks??array()) as $priority=>$callbacks){
  foreach($callbacks as $entry){$cb=$entry['function'];if(is_array($cb)&&is_object($cb[0])&&is_a($cb[0],'Burst\\Admin\\Posts\\Posts')&&'posts_orderby_total_pageviews'===$cb[1]){
   remove_action('pre_get_posts',$cb,$priority);
   add_action('pre_get_posts',static function($query)use($cb){if('post'!==($query->get('post_type')?:'post')){call_user_func($cb,$query);}},$priority);
  }}
 }
},0);
function go_pv_authorized(){return current_user_can('edit_posts')&&current_user_can('view_burst_statistics');}
add_filter('manage_post_posts_columns',static function($cols){
 if(!go_pv_available()||!go_pv_authorized()){return $cols;}
 // Keep views physically beside the post title regardless of columns injected
 // by Rank Math/Burst/other plugins. Reorder server-side only: no DOM movement.
 unset($cols['pageviews']);
 $ordered=array();$inserted=false;
 foreach($cols as $key=>$label){
  $ordered[$key]=$label;
  if('title'===$key){
   $ordered['pageviews']='<span class="go-pv-heading"><span class="go-pv-heading__eye" aria-hidden="true"></span>Visualizações</span>';
   $inserted=true;
  }
 }
 if(!$inserted){$ordered['pageviews']='Visualizações';}
 return $ordered;
},999);
add_filter('manage_edit-post_sortable_columns',static function($cols){if(go_pv_available()&&go_pv_authorized()){$cols['pageviews']=array('pageviews',true);}return $cols;},50);

/**
 * Catch the indexed read model up before WordPress builds a Today/Total sort.
 * This is intentionally limited to the explicit views sort: normal newsroom
 * navigation remains cheap, while the ranking the editor asked for is fresh
 * even when wp-cron.php is delayed by the host/CDN.
 */
add_action('pre_get_posts',static function($q){
 if(!is_admin()||!$q->is_main_query()||'post'!==($q->get('post_type')?:'post')||!go_pv_available()||!go_pv_authorized()){return;}
 $by=(string)$q->get('orderby');
 if(!in_array($by,array('pageviews','go_views_today'),true)){return;}
 go_pv_sync_if_needed(60,3000);
},80);

add_filter('posts_clauses',static function($clauses,$q){
 if(!is_admin()||!$q->is_main_query()||'post'!==($q->get('post_type')?:'post')||!go_pv_available()||!go_pv_authorized()){return $clauses;}
 $by=$q->get('orderby');if(!in_array($by,array('pageviews','go_views_today'),true)){return $clauses;}
 global $wpdb;$t=go_pv_tables();$direction='ASC'===$q->get('order')?'ASC':'DESC';
 $table='go_views_today'===$by?$t['daily']:$t['total'];
 $join=" LEFT JOIN $table go_pv ON go_pv.post_id={$wpdb->posts}.ID AND {$wpdb->posts}.post_status='publish'";
 if('go_views_today'===$by){$join.=$wpdb->prepare(' AND go_pv.day_key=%s',current_datetime()->format('Y-m-d'));}
 if(strpos($clauses['join'],' go_pv ')===false){$clauses['join'].=$join;}
 $clauses['orderby']="COALESCE(go_pv.views,0) $direction, {$wpdb->posts}.ID $direction";
 return $clauses;
},100,2);
/** Plain-language explanation rendered inside the success popover. */
function go_pv_success_panel_html( array $success ) {
 $label=(string)($success['label']??'Avaliando');$score=$success['score']??null;$confidence=(string)($success['confidence']??'baixa');$confidence_note=(string)($success['confidenceNote']??'');$summary=(string)($success['summary']??'');$basis=(string)($success['basis']??'amostra recente');$facts=array_values(array_filter(array_map('strval',(array)($success['facts']??$success['diagnostics']??array()))));$reasons=array_values(array_filter(array_map('strval',(array)($success['reasons']??array()))));$actions=array_values(array_filter(array_map('strval',(array)($success['actions']??array()))));
 $html='<div class="go-pv__insight-head"><div><strong>'.esc_html($label).(null!==$score?' · '.esc_html((string)absint($score)).'/100':'').'</strong><small>'.esc_html($confidence_note?:('Confiança '.$confidence)).'</small></div><span class="go-pv__confidence is-'.esc_attr(sanitize_html_class($confidence)).'">'.esc_html(ucfirst($confidence)).'</span></div>';
 if($summary){$html.='<div class="go-pv__insight-summary">'.esc_html($summary).'</div>';}
 if($facts){$html.='<div class="go-pv__insight-section go-pv__insight-section--snapshot"><b>O que aconteceu</b><ul>';foreach(array_slice($facts,0,4) as $item){$html.='<li>'.esc_html($item).'</li>';}$html.='</ul></div>';}
 if($reasons){$html.='<div class="go-pv__insight-section"><b>O que os sinais sugerem</b><ul>';foreach(array_slice($reasons,0,5) as $item){$html.='<li>'.esc_html($item).'</li>';}$html.='</ul></div>';}
 if($actions){$html.='<div class="go-pv__insight-section go-pv__insight-section--actions"><b>Faça agora</b><ol>';foreach(array_slice($actions,0,4) as $item){$html.='<li>'.esc_html($item).'</li>';}$html.='</ol></div>';}
 $html.='<details class="go-pv__insight-method"><summary>Como esta nota foi calculada</summary><p>Compara o momento da matéria com o próprio Overdrive, mas mantém um piso absoluto para uma semana fraca não transformar pouco tráfego em resultado bom.</p><p><strong>Base:</strong> '.esc_html($basis).'. Search recente entra como sinal complementar; ausência de impressão não é tratada como prova de desindexação.</p></details>';return $html;
}

add_action('manage_post_posts_custom_column' ,static function($column,$id){
 if('pageviews'!==$column||!go_pv_available()||!go_pv_authorized()){return;}
 if(!go_verge_admin_post_has_public_history($id)){echo '<div class="go-pv go-pv--empty"><span>—</span><small>Não publicado</small></div>';return;}
 static $data=null;
 // Paint the table from the compact read model. Rich success diagnostics are
 // fetched only when the editor opens the ? helper for a specific post.
 if(null===$data){global $wp_query;$ids=wp_list_pluck((array)$wp_query->posts,'ID');$data=go_pv_counts($ids,false);}
 $c=$data['counts'][$id]??array('today'=>0,'total'=>0,'success'=>array());$ready=!empty($data['ready']);$success=(array)($c['success']??array());$level=sanitize_html_class((string)($success['level']??'evaluating'));$label=(string)($success['label']??'Avaliando');$success_title=(string)($success['title']??'Avaliando desempenho.');
 $panel=go_pv_success_panel_html($success);printf('<div class="go-pv%s" data-go-pv="%d"><div class="go-pv__metric go-pv__today"><span class="go-pv__label">Hoje</span><strong data-go-pv-today data-value="%d">%s</strong></div><span class="go-pv__divider" aria-hidden="true"></span><div class="go-pv__metric go-pv__total"><span>Total</span><b data-go-pv-total data-value="%d">%s</b></div><div class="go-pv__fresh"><span class="go-pv__success-wrap"><span class="go-pv__success is-%s" data-go-pv-success title="%s" aria-label="Desempenho: %s"></span><button type="button" class="go-pv__success-help" data-go-pv-success-help aria-label="Entender desempenho desta matéria" aria-expanded="false">i</button><span class="go-pv__success-popover" data-go-pv-success-popover role="tooltip" hidden>%s</span></span><span class="go-pv__auto" title="Atualização automática"><i aria-hidden="true"></i><small data-go-pv-state>%s</small></span></div></div>',$ready?'':' is-loading',absint($id),(int)$c['today'],$ready?esc_html(number_format_i18n($c['today'])):'—',(int)$c['total'],$ready?esc_html(number_format_i18n($c['total'])):'—',esc_attr($level),esc_attr($success_title),esc_attr($label),$panel,$ready?'automático':'sincronizando');
},20,2);
add_action('wp_ajax_go_post_views_fast',static function(){
 if(!go_pv_authorized()){wp_send_json_error(array('message'=>'forbidden'),403);}check_ajax_referer('go_post_views_fast','nonce');
 $ids=isset($_POST['ids'])&&is_array($_POST['ids'])?array_map('absint',$_POST['ids']):array();
 $ids=array_values(array_filter(array_slice($ids,0,100),static function($id){return current_user_can('edit_post',$id);}));
 $force=isset($_POST['force'])&&'1'===sanitize_text_field(wp_unslash($_POST['force']));
 if($force){go_pv_collect(3000);delete_transient('go_pv_success_benchmark_v3');}
 $with_success=!isset($_POST['details'])||'0'!==sanitize_text_field(wp_unslash($_POST['details']));
 $payload=go_pv_counts($ids,$with_success);$payload['forced_sync']=$force;
 wp_send_json_success($payload);
});
add_action('admin_enqueue_scripts',static function($hook){
 if('edit.php'!==$hook||'post'!==get_current_screen()->post_type||!go_pv_available()||!go_pv_authorized()){return;}
 $rel='/assets/js/go-post-views-fast.js';wp_enqueue_script('go-post-views-fast',GO_VERGE_URI.$rel,array(),go_verge_asset_version($rel),true);
 wp_add_inline_script('go-post-views-fast','window.GOPostViews='.wp_json_encode(array('url'=>admin_url('admin-ajax.php'),'nonce'=>wp_create_nonce('go_post_views_fast'),'poll'=>60000,'maxPoll'=>300000,'idleAfter'=>180000)).';','before');
 wp_add_inline_style('common','
 .column-pageviews{width:158px;min-width:158px}.go-pv-heading{display:inline-flex;align-items:center;gap:6px;color:var(--go-admin-ink,#17151c);font-weight:760}.go-pv-heading__eye{position:relative;display:inline-block;width:14px;height:9px;border:1.5px solid var(--go-admin-accent,#421aff);border-radius:50%/60%;box-sizing:border-box}.go-pv-heading__eye:after{content:"";position:absolute;left:50%;top:50%;width:4px;height:4px;border-radius:50%;background:var(--go-admin-accent,#421aff);transform:translate(-50%,-50%)}.go-pv{display:inline-flex;align-items:center;gap:8px;min-width:136px;padding:6px 8px;border:1px solid color-mix(in srgb,var(--go-admin-accent,#421aff) 18%,#e2e0e7);border-radius:9px;background:color-mix(in srgb,var(--go-admin-accent-soft,#eeeafd) 52%,#fff);font-variant-numeric:tabular-nums;line-height:1.05;user-select:text;box-sizing:border-box}.go-pv__metric{display:grid;grid-template-rows:auto auto;gap:2px;align-items:end}.go-pv__label,.go-pv__total span{color:var(--go-admin-muted,#64606c);font-size:8px;font-weight:760;letter-spacing:.055em;text-transform:uppercase}.go-pv__today strong{color:var(--go-admin-accent,#421aff);font-size:18px;line-height:1;font-weight:850;letter-spacing:-.035em}.go-pv__total b{color:var(--go-admin-ink,#17151c);font-size:13px;line-height:1;font-weight:780}.go-pv__divider{width:1px;height:25px;background:var(--go-admin-line,#e2e0e7)}.go-pv__fresh{display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:4px;align-self:stretch;margin:0 0 1px auto;color:var(--go-admin-muted,#64606c)}.go-pv__success{display:block;width:9px;height:9px;border-radius:999px;background:#a7aaad;box-shadow:0 0 0 2px rgba(80,80,80,.06);cursor:help}.go-pv__success.is-excellent{background:#008a20;box-shadow:0 0 0 2px rgba(0,138,32,.12)}.go-pv__success.is-good{background:#4ba45b}.go-pv__success.is-median{background:#dba617}.go-pv__success.is-weak{background:#dc6a5f}.go-pv__success.is-poor{background:#b32d2e;box-shadow:0 0 0 2px rgba(179,45,46,.10)}.go-pv__success.is-evaluating{background:#a7aaad}.go-pv__success-wrap{position:relative;display:inline-flex;align-items:center;gap:3px}.go-pv__success-help{display:inline-grid;place-items:center;width:14px;height:14px;min-width:14px;padding:0;border:1px solid color-mix(in srgb,var(--go-admin-muted,#64606c) 42%,transparent);border-radius:999px;background:transparent;color:var(--go-admin-muted,#64606c);font:800 8px/1 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;cursor:help}.go-pv__success-help:hover,.go-pv__success-help:focus-visible{outline:none;border-color:var(--go-admin-accent,#421aff);color:var(--go-admin-accent,#421aff);background:#fff}.go-pv__success-help:focus-visible{box-shadow:0 0 0 2px color-mix(in srgb,var(--go-admin-accent,#421aff) 18%,transparent)}.go-pv__success-popover{position:fixed;z-index:1000002;width:min(390px,calc(100vw - 24px));max-height:min(520px,calc(100vh - 24px));overflow:auto;padding:12px 13px;border:1px solid #dcdcde;border-radius:10px;background:#fff;color:#1d2327;box-shadow:0 14px 38px rgba(0,0,0,.18);font-size:11px;line-height:1.45;text-align:left;white-space:normal}.go-pv__success-popover[hidden]{display:none!important}.go-pv__insight-head{display:flex;align-items:baseline;justify-content:space-between;gap:12px;padding-bottom:8px;border-bottom:1px solid #f0f0f1}.go-pv__insight-head strong{font-size:13px}.go-pv__insight-head span{color:#646970;font-size:10px;white-space:nowrap}.go-pv__insight-section{margin-top:9px}.go-pv__insight-section--snapshot{padding:8px 9px;border-radius:8px;background:#f7f7f8}.go-pv__insight-section--snapshot ul{margin-left:14px}.go-pv__insight-section b{display:block;margin-bottom:4px;font-size:10px;text-transform:uppercase;letter-spacing:.045em;color:#50575e}.go-pv__insight-section ul{margin:0 0 0 16px}.go-pv__insight-section li{margin:0 0 4px}.go-pv__insight-basis{display:block;margin-top:8px;padding-top:8px;border-top:1px solid #f0f0f1;color:#646970;font-size:9px;line-height:1.35}.go-pv__auto{display:inline-flex;align-items:center;gap:3px;white-space:nowrap}.go-pv__auto i{flex:0 0 5px;width:5px;height:5px;border-radius:999px;background:var(--go-admin-accent,#421aff);opacity:.65}.go-pv__fresh small{font-size:8px;line-height:1}.go-pv.is-loading{opacity:.78}.go-pv.is-loading .go-pv__fresh i{opacity:.72}.go-pv.is-updated .go-pv__today strong{animation:none}.go-pv--empty{display:inline-flex;gap:5px;padding:6px 8px;color:var(--go-admin-muted,#64606c);font-size:11px}.go-pv--empty small{font-size:8px}.go-pv-tools{margin:0 2px!important;display:inline-flex!important;align-items:center;gap:5px;flex-wrap:nowrap;font-size:11px}.go-pv-tools__label{color:var(--go-admin-muted,#64606c);font-weight:650}.go-pv-tools a{display:inline-flex;align-items:center;min-height:28px;padding:0 8px;border:1px solid var(--go-admin-line,#e2e0e7);border-radius:7px;background:var(--go-admin-surface,#fff);text-decoration:none;font-weight:650}.go-pv-tools a.is-current{border-color:var(--go-admin-accent,#421aff);background:var(--go-admin-accent-soft,#eeeafd);color:var(--go-admin-accent,#421aff)}.go-pv-refresh{display:inline-grid;place-items:center;width:28px;height:28px;min-height:28px!important;padding:0!important;border-radius:7px!important;font-size:14px!important}.go-pv-refresh.is-spinning{animation:goPvSpin .7s linear infinite}.go-pv-freshness{max-width:160px;overflow:hidden;color:var(--go-admin-muted,#64606c);font-size:9px;line-height:1.1;white-space:nowrap;text-overflow:ellipsis}@keyframes goPvSpin{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){.go-pv.is-loading .go-pv__fresh i,.go-pv.is-updated .go-pv__today strong,.go-pv-refresh.is-spinning{animation:none!important}}
 ');
 wp_add_inline_style('common','
 .go-pv__success-popover{width:min(430px,calc(100vw - 24px));font-size:12px;line-height:1.48;padding:14px 15px}.go-pv__insight-head>div{display:grid;gap:2px;min-width:0}.go-pv__insight-head strong{font-size:14px;line-height:1.2}.go-pv__insight-head small{color:#646970;font-size:10px;line-height:1.3}.go-pv__confidence{display:inline-flex;align-items:center;min-height:22px;padding:0 8px;border-radius:999px;background:#f0f0f1;color:#50575e;font-size:9px;font-weight:750;text-transform:uppercase;letter-spacing:.04em}.go-pv__insight-summary{margin:10px 0 0;padding:10px 11px;border-left:3px solid var(--go-admin-accent,#421aff);border-radius:0 7px 7px 0;background:#f7f5ff;color:#1d2327;font-size:12px;font-weight:650;line-height:1.45}.go-pv__insight-section{margin-top:11px}.go-pv__insight-section--snapshot{background:#f7f7f8;padding:9px 10px}.go-pv__insight-section--actions{padding:9px 10px;border:1px solid #e7e3f2;border-radius:8px;background:#fbfaff}.go-pv__insight-section b{font-size:10px}.go-pv__insight-section ul,.go-pv__insight-section ol{margin:5px 0 0 18px}.go-pv__insight-section li{margin-bottom:5px}.go-pv__insight-method{margin-top:10px;padding-top:9px;border-top:1px solid #f0f0f1;color:#646970}.go-pv__insight-method summary{cursor:pointer;font-size:10px;font-weight:700;color:#50575e}.go-pv__insight-method p{margin:6px 0 0;font-size:10px;line-height:1.45}.go-pv__success-help{font-size:0}.go-pv__success-help:before{content:"?";font-size:8px;line-height:1}.go-pv__success-help[aria-expanded="true"]{border-color:var(--go-admin-accent,#421aff);color:var(--go-admin-accent,#421aff);background:#fff}
 ');
});
/** Keep the current WordPress/Rank Math filters when switching the views order. */
function go_pv_admin_order_url( $orderby ) {
 $args=array();
 foreach((array)$_GET as $key=>$value){ // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- read-only list-table state.
  $key=sanitize_key((string)$key);if(!$key||in_array($key,array('_wpnonce','_wp_http_referer','action','action2','paged','orderby','order'),true)||is_array($value)){continue;}
  $args[$key]=sanitize_text_field(wp_unslash((string)$value));
 }
 $args['post_type']='post';$args['orderby']=sanitize_key($orderby);$args['order']='desc';
 return add_query_arg($args,admin_url('edit.php'));
}
add_action('restrict_manage_posts',static function($type,$which){
 if('post'!==$type||'top'!==$which||!go_pv_available()||!go_pv_authorized()){return;}
 $orderby=isset($_GET['orderby'])?sanitize_key(wp_unslash($_GET['orderby'])):''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
 $today=go_pv_admin_order_url('go_views_today');
 $total=go_pv_admin_order_url('pageviews');
 echo '<span class="go-pv-tools"><span class="go-pv-tools__label">Views</span><a class="'.('go_views_today'===$orderby?'is-current':'').'" href="'.esc_url($today).'" title="Ordenar todos os resultados pelas visualizações de hoje">Hoje</a><a class="'.('pageviews'===$orderby?'is-current':'').'" href="'.esc_url($total).'" title="Ordenar todos os resultados pelas visualizações acumuladas">Total</a><button type="button" class="button go-pv-refresh" id="go-pv-refresh" title="Atualizar agora" aria-label="Atualizar visualizações agora">↻</button><span class="go-pv-freshness" id="go-pv-freshness" role="status">Atualização automática</span></span>';
},20,2);
