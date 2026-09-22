<?php
/** CLI regression fixtures: no WordPress installation, network, or ad requests. */
if ( 'cli' !== PHP_SAPI ) { exit; }
define( 'ABSPATH', __DIR__ . '/../' );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'DAY_IN_SECONDS', 86400 );
define( 'GO_VERGE_VERSION', 'discovery-test' );
$code = getenv( 'GO_DISCOVERY_TEST_CODE' ) ?: dirname( __DIR__ );
$provider = 'yoast';
$endpoint = '';
foreach ( $argv as $arg ) {
    if ( 0 === strpos( $arg, '--provider=' ) ) { $provider = substr( $arg, 11 ); }
    if ( 0 === strpos( $arg, '--endpoint=' ) ) { $endpoint = substr( $arg, 11 ); }
}
if ( 'yoast' === $provider ) { define( 'WPSEO_VERSION', 'test' ); }
if ( 'rank-math' === $provider ) { define( 'RANK_MATH_VERSION', 'test' ); }
$GLOBALS['sm_now'] = time();
$GLOBALS['sm_options'] = array();
$GLOBALS['sm_meta'] = array();
$GLOBALS['sm_transients'] = array();
$GLOBALS['sm_ttls'] = array();
$GLOBALS['sm_hooks'] = array();
$GLOBALS['sm_checks'] = array();
$GLOBALS['sm_status'] = 200;
$GLOBALS['sm_deleted_meta'] = array();
class WP_Post {
    public $ID = 42;
    public $post_type = 'post';
    public $post_status = 'publish';
    public $post_password = '';
    public $post_name = 'test-story';
    public $post_title = 'A & B: notícia de teste';
}
class WP_Term {}
class WP_Query { public $posts; public function __construct( $args ) { $this->posts = array( new WP_Post() ); } }
class SM_DB {
    public $posts = 'wp_posts';
    public function prepare( $sql, ...$args ) { return $sql; }
    public function get_var( $sql ) { return gmdate( 'Y-m-d H:i:s', $GLOBALS['sm_now'] - DAY_IN_SECONDS ); }
}
$wpdb = new SM_DB();
function add_action( $hook, $callback, $priority = 10, $args = 1 ) { $GLOBALS['sm_hooks'][$hook][$callback] = $priority; }
function add_filter( $hook, $callback, $priority = 10, $args = 1 ) { add_action( $hook, $callback, $priority, $args ); }
function add_shortcode( ...$args ) {}
function apply_filters( $hook, $value, ...$args ) { return $value; }
function do_action( ...$args ) {}
function absint( $v ) { return abs( (int) $v ); }
function get_post( $id ) { return new WP_Post(); }
function get_post_type( $id ) { return 'post'; }
function get_post_status( $id ) { return 'publish'; }
function get_post_meta( $id, $key, $single = true ) { return $GLOBALS['sm_meta'][$key] ?? ''; }
function delete_post_meta( $id, $key ) { $GLOBALS['sm_deleted_meta'][] = array($id,$key); return true; }
function get_post_field( $field, $id, $context = '' ) { return ( new WP_Post() )->$field; }
function get_post_time( $format, $gmt = false, $id = null ) { return 'U' === $format ? $GLOBALS['sm_now'] - 600 : gmdate( $format, $GLOBALS['sm_now'] - 600 ); }
function get_post_modified_time( $format, $gmt = false, $id = null ) { return get_post_time( $format, $gmt, $id ); }
function get_option( $name, $default = false ) { return $GLOBALS['sm_options'][$name] ?? $default; }
function get_transient( $key ) { return $GLOBALS['sm_transients'][$key] ?? false; }
function set_transient( $key, $value, $ttl ) { $GLOBALS['sm_transients'][$key] = $value; $GLOBALS['sm_ttls'][$key] = $ttl; }
function delete_transient( $key ) { unset( $GLOBALS['sm_transients'][$key] ); }
function get_permalink( $id ) { return 'https://example.test/test-story/'; }
function home_url( $path = '' ) { return 'https://example.test' . ( $path ?: '/' ); }
function get_bloginfo( $key ) { return 'language' === $key ? 'pt-BR' : 'Game Overdrive'; }
function get_post_thumbnail_id( $id ) { return 0; }
function wp_reset_postdata() {}
function wp_parse_url( $url, $component = -1 ) { return parse_url( $url, $component ); }
function wp_date( $format, $timestamp = null ) { return gmdate( $format, $timestamp ?? time() ); }
function wp_unslash( $value ) { return $value; }
function untrailingslashit( $value ) { return rtrim( $value, '/\\' ); }
function sanitize_key( $value ) { return preg_replace( '/[^a-z0-9_-]/', '', strtolower( $value ) ); }
function esc_url_raw( $value ) { return $value; }
function esc_url( $value ) { return htmlspecialchars( $value, ENT_QUOTES | ENT_XML1, 'UTF-8' ); }
function esc_html( $value ) { return htmlspecialchars( $value, ENT_QUOTES | ENT_XML1, 'UTF-8' ); }
function wp_strip_all_tags( $value ) { return strip_tags( $value ); }
function wp_specialchars_decode( $value, $flags ) { return htmlspecialchars_decode( $value, $flags ); }
function is_wp_error( $value ) { return false; }
function status_header( $status ) { $GLOBALS['sm_status'] = $status; }
function nocache_headers() {}
function wp_json_encode( $value ) { return json_encode( $value ); }
function sm_check( $ok, $label ) { $GLOBALS['sm_checks'][] = array( (bool)$ok, $label ); }
function sm_report() {
    $failed = array_filter( $GLOBALS['sm_checks'], static function( $row ) { return !$row[0]; } );
    foreach ( $failed as $row ) { fwrite( STDERR, 'FAIL ' . $row[1] . PHP_EOL ); }
    echo ( count($GLOBALS['sm_checks']) - count($failed) ) . '/' . count($GLOBALS['sm_checks']) . " checks passed\n";
    return count( $failed ) ? 1 : 0;
}
require $code . '/inc/sitemap-news.php';
require $code . '/inc/sitemap-smart.php';
require $code . '/inc/indexing-integrity.php';

if ( $endpoint ) {
    ob_start();
    register_shutdown_function( static function() use ( $endpoint ) {
        $xml = ob_get_clean();
        if ( 'news' === $endpoint ) {
            sm_check( false === strpos( $xml, 'expired-story' ), 'News response must rebuild a cached entry older than 48 hours' );
            sm_check( false !== strpos( $xml, '/test-story/' ), 'Rebuilt News response retains the current eligible article' );
            sm_check( 200 === $GLOBALS['sm_status'], 'News endpoint remains XML 200' );
        } else {
            $expected = in_array( $endpoint, array('fresh-etag','stable-ims'), true ) ? 304 : 200;
            sm_check( $expected === $GLOBALS['sm_status'], $endpoint . ' HTTP status ' . $expected );
            sm_check( 304 === $expected ? '' === $xml : false !== strpos($xml,'current-story'), $endpoint . ' body agrees with validator decision' );
        }
        exit( sm_report() );
    } );
    if ( 'news' === $endpoint ) {
        $GLOBALS['sm_transients'][GO_VERGE_NEWS_SITEMAP_TRANSIENT] = '<?xml version="1.0"?><urlset xmlns:news="http://www.google.com/schemas/sitemap-news/0.9"><url><loc>https://example.test/expired-story/</loc><news:news><news:publication_date>' . gmdate(DATE_W3C, $GLOBALS['sm_now'] - 2*DAY_IN_SECONDS - 60) . '</news:publication_date></news:news></url></urlset>';
        go_verge_news_sitemap_send();
    }
    $xml = '<?xml version="1.0"?><urlset><url><loc>https://example.test/current-story/</loc></url></urlset>';
    $_SERVER['HTTP_IF_MODIFIED_SINCE'] = gmdate( 'D, d M Y H:i:s', $GLOBALS['sm_now'] - DAY_IN_SECONDS ) . ' GMT';
    if ( 'fresh-etag' === $endpoint ) { $_SERVER['HTTP_IF_NONE_MATCH'] = 'W/"go-sm-' . md5($xml) . '"'; }
    if ( 'changed-etag' === $endpoint ) { $_SERVER['HTTP_IF_NONE_MATCH'] = '"previous-body"'; }
    go_verge_smart_sitemap_send_xml( $xml, array('kind'=>'stable-ims' === $endpoint ? 'posts-page' : 'fresh','key'=>'test') );
}

sm_check( -1000 === $GLOBALS['sm_hooks']['wp_loaded']['go_verge_news_sitemap_early_router'], 'News router precedes the main query' );
sm_check( -1000 === $GLOBALS['sm_hooks']['wp_loaded']['go_verge_smart_sitemap_early_router'], 'General router precedes the main query' );
sm_check( go_verge_news_sitemap_theme_owns_endpoint(), 'Theme explicitly owns the News endpoint' );
$GLOBALS['sm_meta']['rank_math_robots'] = array('noindex');
$smart = go_verge_smart_sitemap_post_eligible(42);
$news = go_verge_news_sitemap_post_is_eligible(42);
sm_check( $smart === $news, 'News agrees with the active SEO provider instead of a stale Rank Math veto' );
sm_check( ('yoast' === $provider) === $news, 'Active noindex is preserved; inactive Rank Math meta is ignored under Yoast' );
$GLOBALS['sm_meta'] = array('_yoast_wpseo_meta-robots-noindex'=>'1');
sm_check( ('rank-math' === $provider) === go_verge_news_sitemap_post_is_eligible(42), 'Active Yoast noindex and inactive Yoast metadata follow the shared contract' );
$GLOBALS['sm_meta'] = array();
sm_check( go_verge_news_sitemap_post_is_eligible(42), 'Current eligible article remains in News' );
$GLOBALS['sm_meta']['rank_math_canonical_url'] = 'https://example.test/different-story/';
$GLOBALS['sm_meta']['_yoast_wpseo_canonical'] = 'https://example.test/different-story/';
sm_check( !go_verge_news_sitemap_post_is_eligible(42), 'Canonical pointing elsewhere remains excluded' );
$GLOBALS['sm_meta'] = array();

foreach ( array('https://example.test/?p=42','https://example.test/?page_id=42','https://example.test/index.php?p=42','/?p=42','http://www.example.test/test-story') as $url ) {
    sm_check( go_verge_canonical_points_to_self($url,42), 'True self canonical: ' . $url );
}
foreach ( array('https://example.test/?p=42&preview=true','https://example.test/?p=42&page=2','https://example.test/?p=42&page_id=99','https://example.test/?p=42foo','https://example.test/?p=-42','https://example.test/?p[]=42','https://example.test:8443/?p=42','https://example.test:8443/test-story/','https://another.test/?p=42','https://example.test/other/','https://example.test/?p=43') as $url ) {
    sm_check( !go_verge_canonical_points_to_self($url,42), 'Distinct or ambiguous canonical must be preserved: ' . $url );
    $GLOBALS['sm_deleted_meta'] = array();
    $result = go_verge_indexing_refuse_self_canonical_meta(null,42,'rank_math_canonical_url',$url);
    sm_check( null === $result && !$GLOBALS['sm_deleted_meta'], 'Save hook leaves distinct canonical untouched: ' . $url );
}
$GLOBALS['sm_deleted_meta'] = array();
sm_check( true === go_verge_indexing_refuse_self_canonical_meta(null,42,'rank_math_canonical_url','https://example.test/?p=42') && array(array(42,'rank_math_canonical_url')) === $GLOBALS['sm_deleted_meta'], 'Save hook still removes an unambiguous self override');
sm_check( go_verge_smart_sitemap_is_not_modified('"current"',100,'W/"old", W/"current"',999), 'Weak ETag and list matching supported' );
sm_check( !go_verge_smart_sitemap_is_not_modified('"current"',100,'"different"',999), 'If-None-Match has precedence over If-Modified-Since' );
sm_check( !go_verge_smart_sitemap_is_not_modified('"current"',0,'',999), 'An unknown representation clock never grants IMS 304' );
sm_check( '2026-09-20T12:00:00+00:00' === go_verge_news_sitemap_consistent_lastmod_iso('2026-09-20T12:00:00Z','2026-09-19T12:00:00Z'), 'Article lastmod cannot predate publication' );
if ( function_exists('go_verge_news_sitemap_cache_ttl') ) {
    $news_xml = static function($ts) { return '<news:publication_date>' . gmdate(DATE_W3C,$ts) . '</news:publication_date>'; };
    sm_check(900 === go_verge_news_sitemap_cache_ttl('<urlset/>',1000000), 'Empty News cache has a bounded normal TTL');
    sm_check(900 === go_verge_news_sitemap_cache_ttl($news_xml(1000000-100),1000000), 'Young News entry keeps normal TTL');
    sm_check(61 === go_verge_news_sitemap_cache_ttl($news_xml(1000000-2*DAY_IN_SECONDS+60),1000000), 'News cache expires at the oldest entry boundary');
    sm_check(0 === go_verge_news_sitemap_cache_ttl($news_xml(1000000-2*DAY_IN_SECONDS-1),1000000), 'Already expired News cache is rejected');
    sm_check(0 === go_verge_news_sitemap_cache_ttl('<news:publication_date>invalid</news:publication_date>',1000000), 'Malformed cached date cannot be treated as valid');
}
$GLOBALS['sm_meta'] = array('rank_math_title'=>'Título Rank Math','_yoast_wpseo_title'=>'Título Yoast');
$expected_title = 'rank-math' === $provider ? 'Título Rank Math' : ('yoast' === $provider ? 'Título Yoast' : (new WP_Post())->post_title);
sm_check($expected_title === go_verge_news_sitemap_document_title(42), 'News title uses the active provider only');
$GLOBALS['sm_meta'] = 'rank-math' === $provider ? array('_yoast_wpseo_title'=>'Título inativo') : array('rank_math_title'=>'Título inativo');
sm_check((new WP_Post())->post_title === go_verge_news_sitemap_document_title(42), 'Inactive provider title cannot replace the editorial title');
$active_key = 'rank-math' === $provider ? 'rank_math_title' : '_yoast_wpseo_title';
$GLOBALS['sm_meta'] = array($active_key=>'%%title%%');
sm_check((new WP_Post())->post_title === go_verge_news_sitemap_document_title(42), 'Full Yoast-style tokens never leave stray percent markers');
$GLOBALS['sm_meta'] = array($active_key=>'%title%');
sm_check((new WP_Post())->post_title === go_verge_news_sitemap_document_title(42), 'Single-percent title template remains supported');
$GLOBALS['sm_meta'] = array($active_key=>'%unavailable_custom_variable%');
sm_check((new WP_Post())->post_title === go_verge_news_sitemap_document_title(42), 'Unknown unresolved title template falls back to the visible headline');
sm_check(in_array('rank_math_title',go_verge_news_sitemap_relevant_meta_keys(),true), 'Rank Math title changes invalidate News cache');
sm_check(isset($GLOBALS['sm_hooks']['update_option_rank-math-options-titles']['go_verge_news_sitemap_bust_cache']), 'Rank Math title template change invalidates News cache');
sm_check(isset($GLOBALS['sm_hooks']['update_option_wpseo_titles']['go_verge_news_sitemap_bust_cache']), 'Yoast title template change invalidates News cache');
exit( sm_report() );
