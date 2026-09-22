<?php
/** Lifecycle regression: actual theme modules, deterministic in-memory WP data, no network. */
if ( 'cli' !== PHP_SAPI ) { exit; }
define( 'ABSPATH', __DIR__ . '/../' );
define( 'MINUTE_IN_SECONDS', 60 ); define( 'HOUR_IN_SECONDS', 3600 ); define( 'DAY_IN_SECONDS', 86400 );
$code = getenv( 'GO_PUBLICATION_TEST_CODE' ) ?: dirname( __DIR__ );
$GLOBALS['np_posts'] = array(); $GLOBALS['np_meta'] = array(); $GLOBALS['np_options'] = array();
$GLOBALS['np_hooks'] = array(); $GLOBALS['np_checks'] = array(); $GLOBALS['np_query_log'] = array();
class WP_Post {
    public $ID; public $post_type = 'post'; public $post_status = 'publish'; public $post_password = '';
    public $post_title = 'Notícia'; public $post_content = 'Texto'; public $post_excerpt = ''; public $post_name;
    public $post_date; public $post_date_gmt; public $post_modified; public $post_modified_gmt; public $post_author = 1;
    public function __construct( $id, $age = 0, $status = 'publish' ) {
        $this->ID = $id; $this->post_name = 'story-' . $id; $this->post_status = $status;
        $this->post_date_gmt = $this->post_modified_gmt = gmdate( 'Y-m-d H:i:s', time() - $age );
        $this->post_date = $this->post_modified = gmdate( 'Y-m-d H:i:s', time() - $age - 3 * HOUR_IN_SECONDS );
    }
}
class WP_Term {}
class WP_Query { public $posts; public function __construct( $args ) { $this->posts = get_posts( $args ); } }
function add_action( $hook, $callback, $priority = 10, $accepted = 1 ) { $GLOBALS['np_hooks'][$hook][$priority][] = array($callback,$accepted); }
function add_filter( $hook, $callback, $priority = 10, $accepted = 1 ) { add_action($hook,$callback,$priority,$accepted); }
function add_shortcode( ...$args ) {}
function do_action( $hook, ...$args ) {
    $GLOBALS['np_current_hooks'][]=$hook;
    $callbacks = $GLOBALS['np_hooks'][$hook] ?? array(); ksort($callbacks);
    foreach ( $callbacks as $group ) { foreach ( $group as $row ) { call_user_func_array($row[0],array_slice($args,0,$row[1])); } }
    array_pop($GLOBALS['np_current_hooks']);
}
function current_filter() { return end($GLOBALS['np_current_hooks']); }
function apply_filters( $hook, $value, ...$args ) { return $value; }
function absint( $v ) { return abs((int)$v); }
function get_post( $id ) { return $id instanceof WP_Post ? $id : ($GLOBALS['np_posts'][(int)$id] ?? null); }
function get_post_type( $id ) { $p=get_post($id); return $p ? $p->post_type : false; }
function get_post_status( $id ) { $p=get_post($id); return $p ? $p->post_status : false; }
function get_post_meta( $id,$key,$single=true ) { return $GLOBALS['np_meta'][$id][$key] ?? ''; }
function update_post_meta( $id,$key,$value ) { $hook=isset($GLOBALS['np_meta'][$id][$key])?'updated_post_meta':'added_post_meta'; $GLOBALS['np_meta'][$id][$key]=$value; do_action($hook,1,$id,$key,$value); return true; }
function get_option( $key,$default=false ) { return $GLOBALS['np_options'][$key] ?? $default; }
function update_option( $key,$value,$autoload=false ) { $GLOBALS['np_options'][$key]=$value; return true; }
function delete_transient( $key ) { return true; }
function get_permalink( $id ) { $p=get_post($id); return $p ? 'https://example.test/'.$p->post_name.'/' : ''; }
function get_the_title( $id ) { return get_post($id)->post_title; }
function get_post_field( $field,$id,$context='display' ) { return get_post($id)->$field; }
function get_post_time( $format,$gmt=false,$id=null ) { $p=get_post($id); $ts=strtotime(($gmt?$p->post_date_gmt:$p->post_date).' UTC'); return 'U'===$format?$ts:gmdate($format,$ts); }
function get_post_modified_time( $format,$gmt=false,$id=null ) { $p=get_post($id); $ts=strtotime(($gmt?$p->post_modified_gmt:$p->post_modified).' UTC'); return 'U'===$format?$ts:gmdate($format,$ts); }
function wp_date( $format,$ts=null ) { return gmdate($format,($ts??time())-3*HOUR_IN_SECONDS); }
function wp_get_post_terms( ...$args ) { return array(); }
function get_post_thumbnail_id( $id ) { return 0; }
function wp_is_post_revision( $id ) { return false; } function wp_is_post_autosave( $id ) { return false; }
function home_url( $path='' ) { return 'https://example.test'.($path?:'/'); }
function wp_parse_url( $url,$component=-1 ) { return parse_url($url,$component); }
function get_bloginfo( $key ) { return 'language'===$key?'pt-BR':'Game Overdrive'; }
function untrailingslashit( $v ) { return rtrim($v,'/'); }
function sanitize_key( $v ) { return preg_replace('/[^a-z0-9_-]/','',strtolower($v)); }
function esc_url_raw( $v ) { return $v; }
function esc_url( $v ) { return htmlspecialchars($v,ENT_QUOTES|ENT_XML1,'UTF-8'); }
function esc_html( $v ) { return htmlspecialchars($v,ENT_QUOTES|ENT_XML1,'UTF-8'); }
function esc_xml( $v ) { return htmlspecialchars($v,ENT_QUOTES|ENT_XML1,'UTF-8'); }
function wp_strip_all_tags( $v ) { return strip_tags($v); }
function wp_specialchars_decode( $v,$flags=ENT_QUOTES ) { return htmlspecialchars_decode($v,$flags); }
function is_wp_error( $v ) { return false; }
function wp_reset_postdata() {}
function go_verge_post_is_news_article( $id ) { return 'Article' !== get_post_meta($id,'type',true); }
function np_query_matches( $p,$a ) {
    if ( isset($a['post_type']) && !in_array($p->post_type,(array)$a['post_type'],true) ) { return false; }
    if ( isset($a['post_status']) && !in_array($p->post_status,(array)$a['post_status'],true) ) { return false; }
    if ( isset($a['post__in']) && !in_array($p->ID,$a['post__in'],true) ) { return false; }
    if ( array_key_exists('has_password',$a) && !$a['has_password'] && ''!==$p->post_password ) { return false; }
    foreach ( $a['date_query']??array() as $q ) {
        if (!is_array($q)) { continue; } $column=$q['column']??'post_date'; $value=strtotime($p->$column.' UTC');
        if (isset($q['after']) && $value < strtotime($q['after'].' UTC')) { return false; }
        if (isset($q['before']) && $value > strtotime($q['before'].' UTC')) { return false; }
    }
    if (isset($a['meta_key'])) {
        $value=get_post_meta($p->ID,$a['meta_key'],true); if (''===$value) { return false; }
        if (isset($a['meta_value']) && '>='===($a['meta_compare']??'=') && strcmp($value,$a['meta_value'])<0) { return false; }
    }
    return true;
}
function get_posts( $a ) {
    $GLOBALS['np_query_log'][]=$a;
    $p=array_values(array_filter($GLOBALS['np_posts'],static function($p)use($a){return np_query_matches($p,$a);}));
    usort($p,static function($x,$y)use($a){$by=$a['orderby']??'date';$xv='meta_value'===$by?get_post_meta($x->ID,$a['meta_key'],true):('modified'===$by?$x->post_modified:$x->post_date);$yv='meta_value'===$by?get_post_meta($y->ID,$a['meta_key'],true):('modified'===$by?$y->post_modified:$y->post_date);return strcmp($yv,$xv);});
    $p=array_slice($p,0,max(0,(int)($a['posts_per_page']??5)));
    return 'ids'===($a['fields']??'')?array_map(static function($p){return $p->ID;},$p):$p;
}
function np_check($ok,$label){$GLOBALS['np_checks'][]=array((bool)$ok,$label);}
function np_has($xml,$id){return false!==strpos($xml,'<loc>https://example.test/story-'.$id.'/</loc>');}
require $code.'/inc/search-visibility.php';
require $code.'/inc/search-freshness.php';
require $code.'/inc/sitemap-news.php';
require $code.'/inc/sitemap-smart.php';

/* wp_publish_post() changes only status: an old scheduled/draft row keeps its dates. */
$old=new WP_Post(1,10*DAY_IN_SECONDS,'future');$GLOBALS['np_posts'][1]=$old;$old->post_status='publish';
do_action('transition_post_status','publish','future',$old);
np_check(abs(time()-go_verge_search_published_timestamp(1))<=2,'First public transition records the actual UTC publication time');
np_check(go_verge_news_sitemap_post_is_eligible(1),'New public scheduled post is eligible despite its old database dates');
np_check(np_has(go_verge_news_sitemap_build(),1),'New public scheduled post appears in News candidates and XML');
np_check(np_has(go_verge_smart_sitemap_build_fresh(),1),'New public scheduled post appears in fresh candidates and XML');
np_check(10*DAY_IN_SECONDS-2 <= time()-(int)get_post_time('U',true,1),'Publication does not rewrite the editorial database date');

$normal=new WP_Post(2,600);$GLOBALS['np_posts'][2]=$normal;
np_check(np_has(go_verge_news_sitemap_build(),2),'Legacy current publication without first-publish meta remains in News');
np_check(np_has(go_verge_smart_sitemap_build_fresh(),2),'Legacy current publication remains in fresh sitemap');

/* New rows cannot reintroduce stale/hidden/canonicalized entries via the alternate clock. */
foreach (array(3,4,5,6,7)as$id){$GLOBALS['np_posts'][$id]=new WP_Post($id,10*DAY_IN_SECONDS);$GLOBALS['np_meta'][$id][GO_VERGE_FIRST_PUBLISHED_META]=gmdate('Y-m-d H:i:s',time()-60);}
$GLOBALS['np_posts'][3]->post_status='future';$GLOBALS['np_posts'][4]->post_password='secret';
$GLOBALS['np_meta'][5]['rank_math_robots']=array('noindex');$GLOBALS['np_meta'][6]['rank_math_canonical_url']='https://example.test/different/';
$GLOBALS['np_meta'][7][GO_VERGE_FIRST_PUBLISHED_META]=gmdate('Y-m-d H:i:s',time()-3*DAY_IN_SECONDS);
$news=go_verge_news_sitemap_build();$fresh=go_verge_smart_sitemap_build_fresh();
foreach(array(3,4,5,6)as$id){np_check(!np_has($news,$id),'News preserves status/password/noindex/canonical gate for '.$id);np_check(!np_has($fresh,$id),'Fresh preserves status/password/noindex/canonical gate for '.$id);}
np_check(!np_has($news,7),'News does not reopen its 48-hour window for older first publication');

/* Ordinary scheduled publication prepared well in advance must retain one URL. */
$GLOBALS['np_posts'][8]=new WP_Post(8,300);$GLOBALS['np_meta'][8][GO_VERGE_FIRST_PUBLISHED_META]=gmdate('Y-m-d H:i:s',time()-300);
$news=go_verge_news_sitemap_build();$fresh=go_verge_smart_sitemap_build_fresh();
np_check(1===substr_count($news,'<loc>https://example.test/story-8/</loc>'),'News deduplicates overlap between candidate clocks');
np_check(1===substr_count($fresh,'<loc>https://example.test/story-8/</loc>'),'Fresh deduplicates overlap between candidate clocks');

/* Core's scheduled path can retain an old modified clock even when the scheduled date is current. */
$scheduled=new WP_Post(9,10*DAY_IN_SECONDS,'future');
$scheduled->post_date_gmt=gmdate('Y-m-d H:i:s',time()-30);$scheduled->post_date=wp_date('Y-m-d H:i:s',time()-30);
$GLOBALS['np_posts'][9]=$scheduled;$scheduled->post_status='publish';
do_action('transition_post_status','publish','future',$scheduled);
np_check(np_has(go_verge_news_sitemap_build(),9),'On-time scheduled publication remains in News');
np_check(np_has(go_verge_smart_sitemap_build_fresh(),9),'On-time scheduled publication with an old modified clock enters fresh XML');
$original_clock=get_post_meta(9,GO_VERGE_FIRST_PUBLISHED_META,true);
do_action('transition_post_status','publish','draft',$scheduled);
np_check($original_clock===get_post_meta(9,GO_VERGE_FIRST_PUBLISHED_META,true),'Republishing does not reset the immutable first-publication clock');
$draft=new WP_Post(10,10*DAY_IN_SECONDS,'draft');$GLOBALS['np_posts'][10]=$draft;$draft->post_status='publish';
do_action('transition_post_status','publish','draft',$draft);
np_check(np_has(go_verge_smart_sitemap_build_fresh(),10),'First publication from a draft enters fresh XML without rewriting saved dates');

/* Cached general/fresh XML must change after the public eligibility changes. */
$before=clone $normal;$after=clone $normal;$after->post_password='new-password';$GLOBALS['np_posts'][2]=$after;
$epoch=go_verge_smart_sitemap_epoch();do_action('post_updated',2,$after,$before);
np_check(go_verge_smart_sitemap_epoch()>$epoch,'Password addition invalidates cached sitemap eligibility without a text edit');
$before=clone $after;$after=clone $after;$after->post_password='';$GLOBALS['np_posts'][2]=$after;
$epoch=go_verge_smart_sitemap_epoch();do_action('post_updated',2,$after,$before);
np_check(go_verge_smart_sitemap_epoch()>$epoch,'Password removal invalidates cached sitemap eligibility without a text edit');
$epoch=go_verge_smart_sitemap_epoch();update_post_meta(2,GO_VERGE_FIRST_PUBLISHED_META,gmdate('Y-m-d H:i:s',time()-3600));
np_check(go_verge_smart_sitemap_epoch()>$epoch,'First-publication metadata changes invalidate XML depending on that clock');

foreach(array('post_date','post_date_gmt','post_author')as$field){
    $before=clone $after;$after=clone $after;
    $after->$field='post_author'===$field?2:gmdate('Y-m-d H:i:s',time()-40*DAY_IN_SECONDS);
    $GLOBALS['np_posts'][2]=$after;$epoch=go_verge_smart_sitemap_epoch();do_action('post_updated',2,$after,$before);
    np_check(go_verge_smart_sitemap_epoch()>$epoch,'Changed '.$field.' invalidates affected sitemap membership/order');
}
$epoch=go_verge_smart_sitemap_epoch();do_action('post_updated',2,$after,clone $after);
np_check(go_verge_smart_sitemap_epoch()===$epoch,'No-op published save does not invalidate XML again');

/* Merging two bounded clocks must not exceed Google's News limit. */
$GLOBALS['np_posts']=array();$GLOBALS['np_meta']=array();
for($id=100;$id<1205;$id++){
    $GLOBALS['np_posts'][$id]=new WP_Post($id,$id<1100?300:10*DAY_IN_SECONDS);
    if($id>=1100){$GLOBALS['np_meta'][$id][GO_VERGE_FIRST_PUBLISHED_META]=gmdate('Y-m-d H:i:s',time()-60);}
}
$news=go_verge_news_sitemap_build();
np_check(1000===substr_count($news,'<news:news>'),'Merged News output stays at 1000 eligible entries');
np_check(np_has($news,1204),'Newer public-clock candidates survive final News ordering and cap');
np_check(substr_count($news,'<loc>')===count(array_unique((function($xml){preg_match_all('#<loc>([^<]+)</loc>#',$xml,$m);return $m[1];})($news))),'Merged News output contains no duplicate locations');

$failed=array_values(array_filter($GLOBALS['np_checks'],static function($x){return !$x[0];}));
echo json_encode(array('passed'=>!$failed,'checks'=>count($GLOBALS['np_checks']),'failed'=>$failed),JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL;
exit($failed?1:0);
