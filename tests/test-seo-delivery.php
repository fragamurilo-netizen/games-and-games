<?php
/** CLI regression fixtures; actual SEO modules, no WordPress/database/network. */
if ( 'cli' !== PHP_SAPI ) { http_response_code( 403 ); exit; }
$theme = isset( $argv[1] ) ? rtrim( $argv[1], '/' ) : dirname( __DIR__ );
define( 'ABSPATH', $theme . '/' );
define( 'GO_VERGE_DIR', $theme );
define( 'GO_VERGE_URI', 'https://example.test/theme' );
define( 'DAY_IN_SECONDS', 86400 );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'RANK_MATH_VERSION', 'fixture' );
$GLOBALS['seo_hooks'] = array();
$GLOBALS['seo_context'] = array( 'singular' => 'post', 'id' => 42, 'admin' => false, 'feed' => false, 'preview' => false, 'password' => false, 'home' => 'https://example.test', 'status' => 'publish' );
$GLOBALS['seo_meta'] = array( 42 => array( '_go_first_published_gmt' => '2026-08-17 12:00:00', '_go_search_content_modified_gmt' => '2026-09-19 00:43:05' ) );
$GLOBALS['seo_writes'] = 0;
function add_filter( $hook, $callback, $priority = 10, $args = 1 ) { $GLOBALS['seo_hooks'][ $hook ][ $priority ][] = array( $callback, $args ); return true; }
function add_action( $hook, $callback, $priority = 10, $args = 1 ) { return add_filter( $hook, $callback, $priority, $args ); }
function add_shortcode() { return true; }
function remove_filter() { return true; }
function remove_action() { return true; }
function apply_filters( $hook, $value, ...$extra ) { $items = $GLOBALS['seo_hooks'][ $hook ] ?? array(); ksort( $items ); foreach ( $items as $callbacks ) { foreach ( $callbacks as $entry ) { $value = call_user_func_array( $entry[0], array_slice( array_merge( array( $value ), $extra ), 0, $entry[1] ) ); } } return $value; }
function absint( $v ) { return abs( (int) $v ); }
function __( $s, $domain = '' ) { return $s; }
function esc_html__( $s, $domain = '' ) { return $s; }
function esc_attr( $s ) { return htmlspecialchars( (string) $s, ENT_QUOTES, 'UTF-8' ); }
function esc_html( $s ) { return esc_attr( $s ); }
function esc_url_raw( $s ) { return (string) $s; }
function esc_url( $s ) { return (string) $s; }
function wp_strip_all_tags( $s ) { return strip_tags( (string) $s ); }
function wp_json_encode( $v, $flags = 0 ) { return json_encode( $v, $flags ); }
function wp_parse_url( $s, $part = -1 ) { return parse_url( $s, $part ); }
function wp_basename( $s ) { return basename( $s ); }
function untrailingslashit( $s ) { return rtrim( (string) $s, '/\\' ); }
function trailingslashit( $s ) { return untrailingslashit( $s ) . '/'; }
function home_url( $path = '' ) { return $GLOBALS['seo_context']['home'] . ( '' === $path ? '' : '/' . ltrim( $path, '/' ) ); }
function site_url( $path = '' ) { return home_url( $path ); }
function is_admin() { return $GLOBALS['seo_context']['admin']; }
function is_feed() { return $GLOBALS['seo_context']['feed']; }
function is_embed() { return false; }
function is_preview() { return $GLOBALS['seo_context']['preview']; }
function is_singular( $type = '' ) { return '' === $type ? (bool) $GLOBALS['seo_context']['singular'] : in_array( $GLOBALS['seo_context']['singular'], (array) $type, true ); }
function is_front_page() { return false; }
function is_home() { return false; }
function is_404() { return false; }
function is_page() { return false; }
function is_archive() { return false; }
function is_search() { return false; }
function is_author() { return false; }
function get_queried_object_id() { return $GLOBALS['seo_context']['id']; }
function get_post_status( $id = 0 ) { return $GLOBALS['seo_context']['status']; }
function post_password_required() { return $GLOBALS['seo_context']['password']; }
function get_post_meta( $id, $key, $single = false ) { return $GLOBALS['seo_meta'][ $id ][ $key ] ?? ''; }
function update_post_meta() { ++$GLOBALS['seo_writes']; return true; }
function get_option( $key, $default = false ) { return 'blog_public' === $key ? 1 : $default; }
function get_post_time( $format, $gmt = false, $id = 0 ) { return 'U' === $format ? strtotime( '2026-08-17 12:00:00 UTC' ) : '2026-08-17T12:00:00+00:00'; }
function get_post_modified_time( $format, $gmt = false, $id = 0 ) { return '2026-09-19T16:44:38+00:00'; }
function get_permalink( $id = 0 ) { return home_url( '/story/' ); }
function get_the_title( $id = 0 ) { return 'Título editorial'; }
function get_post_thumbnail_id( $id = 0 ) { return $GLOBALS['seo_thumb'] ?? 101; }
function has_post_thumbnail() { return get_post_thumbnail_id() > 0; }
function wp_get_attachment_metadata( $id ) { return $GLOBALS['seo_images'][ $id ]['meta'] ?? array(); }
function wp_get_attachment_url( $id ) { return $GLOBALS['seo_images'][ $id ]['src'][0] ?? ''; }
function wp_get_attachment_image_src( $id, $size = '' ) { return $GLOBALS['seo_images'][ $id ]['src'] ?? false; }
function image_get_intermediate_size( $id, $size ) { return $GLOBALS['seo_images'][ $id ]['intermediate'][ $size ] ?? false; }
function wp_get_attachment_caption( $id ) { return ''; }
function wp_check_filetype( $path ) { return array( 'type' => '' ); }
function get_post_mime_type( $id ) { return 'image/jpeg'; }
class WP_Post { public $ID=42; public $post_type='post'; public $post_status='publish'; public $post_author=1; }
function get_post( $id = 0 ) { $post = new WP_Post(); $post->ID = $id ?: 42; return $post; }
function get_post_type( $id = 0 ) { return 'post'; }
function get_posts( $args = array() ) { return array(42); }
function get_userdata( $id ) { return (object)array('ID'=>$id); }
function wp_get_post_terms( $id, $taxonomy, $args = array() ) { return array(1); }
function is_wp_error( $value ) { return false; }
function get_query_var( $key, $default = '' ) { return $default; }
require $theme . '/inc/seo.php';
require $theme . '/inc/rank-math-compat.php';
require $theme . '/inc/search-freshness.php';
require $theme . '/inc/search-visibility.php';
require $theme . '/inc/editorial-trust-seo.php';
require $theme . '/inc/discover-health.php';
require $theme . '/inc/discover-cwv.php';
require $theme . '/inc/sitemap-smart.php';
$checks = array();
function check( $ok, $name, $actual = null ) { global $checks; $checks[] = array( 'name' => $name, 'pass' => (bool) $ok, 'actual' => $ok ? null : $actual ); }

// Feed serialization: both quoting styles and legal whitespace, same origin.
$cases = array(
 array( '<a href="/a">A</a>', '<a href="https://example.test/a">A</a>', 'double quote' ),
 array( "<a href='/a'>A</a>", "<a href='https://example.test/a'>A</a>", 'single quote' ),
 array( '<img src = "/a.jpg">', '<img src = "https://example.test/a.jpg">', 'attribute whitespace' ),
 array( "<a HREF\t=\t'/a'>A</a>", "<a HREF\t=\t'https://example.test/a'>A</a>", 'case and tabs' ),
 array( '<img src="//cdn.test/a.jpg">', '<img src="//cdn.test/a.jpg">', 'protocol relative unchanged' ),
 array( '<a href="https://other.test/a">A</a>', '<a href="https://other.test/a">A</a>', 'absolute unchanged' ),
 array( '<a href="#a">A</a><a href="mailto:a@test">B</a>', '<a href="#a">A</a><a href="mailto:a@test">B</a>', 'anchors and mail unchanged' ),
 array( '<img data-src="/lazy.jpg" src="/real.jpg">', '<img data-src="/lazy.jpg" src="https://example.test/real.jpg">', 'custom data attribute untouched' ),
 array( '<a data-href="/client-only">A</a>', '<a data-href="/client-only">A</a>', 'data-href untouched' ),
 array( '<a href="/a?x=1&amp;y=2">A</a>', '<a href="https://example.test/a?x=1&amp;y=2">A</a>', 'query entity preserved' ),
);
foreach ( $cases as $c ) { $result = go_verge_feed_absolutize_urls( $c[0] ); check( $c[1] === $result, 'feed: ' . $c[2], $result ); }
$GLOBALS['seo_context']['home'] = 'https://example.test:8443/editorial';
check( '<img src="https://example.test:8443/wp-content/a.jpg">' === go_verge_feed_absolutize_urls( '<img src="/wp-content/a.jpg">' ), 'root relative uses origin with port, not home subdirectory' );
$GLOBALS['seo_context']['home'] = 'https://example.test';
check( null === go_verge_feed_absolutize_urls( null ), 'feed nonstring passthrough' );
$once = go_verge_feed_absolutize_urls( '<a href="/a">A</a>' );
check( $once === go_verge_feed_absolutize_urls( $once ), 'feed idempotence' );

// Published HTML observation: Rank Math technical edit was 16:44Z; editorial clock 00:43Z.
$old = '2026-09-19T13:44:38-03:00';
$editorial = go_verge_search_consistent_modified_iso( 42 );
foreach ( array( 'article_modified_time', 'og_updated_time' ) as $tag ) {
 $result = apply_filters( 'rank_math/opengraph/facebook/' . $tag, $old );
 check( $editorial === $result, 'OG clock agrees with schema and visible dateline: ' . $tag, $result );
}
check( go_verge_search_published_iso( 42 ) === apply_filters( 'rank_math/opengraph/facebook/article_published_time', '2026-08-01T09:00:00-03:00' ), 'OG first-publication agrees with schema' );
check( false === apply_filters( 'rank_math/opengraph/facebook/article_modified_time', false ), 'suppressed OG date stays suppressed' );
check( '' === apply_filters( 'rank_math/opengraph/facebook/article_modified_time', '' ), 'absent OG date stays absent' );
$GLOBALS['seo_context']['singular'] = 'page';
check( $old === apply_filters( 'rank_math/opengraph/facebook/article_modified_time', $old ), 'page clock remains plugin-owned' );
$GLOBALS['seo_context']['singular'] = 'post';
foreach ( array( 'admin', 'feed', 'preview', 'password' ) as $flag ) { $GLOBALS['seo_context'][ $flag ] = true; check( $old === apply_filters( 'rank_math/opengraph/facebook/article_modified_time', $old ), 'OG guard: ' . $flag ); $GLOBALS['seo_context'][ $flag ] = false; }
$GLOBALS['seo_context']['status'] = 'draft';
check( $old === apply_filters( 'rank_math/opengraph/facebook/article_modified_time', $old ), 'draft clock is not manufactured' );
$GLOBALS['seo_context']['status'] = 'publish';
$GLOBALS['seo_meta'][42]['_go_search_content_modified_gmt'] = '2026-07-01 00:00:00';
check( go_verge_search_published_iso(42) === apply_filters( 'rank_math/opengraph/facebook/article_modified_time', $old ), 'modified date cannot predate first publication' );
$GLOBALS['seo_meta'][42]['_go_search_content_modified_gmt'] = '2026-09-19 00:43:05';
check( 0 === $GLOBALS['seo_writes'], 'head and feed fixes never mutate saved dates/content' );

// Keep actual graph defenses and Google-supported AVIF separate from social formats.
$GLOBALS['seo_images'][101] = array( 'src' => array( 'https://example.test/uploads/a.avif', 1600, 900 ), 'meta' => array( 'width' => 1600, 'height' => 900, 'sizes' => array() ) );
check( ! go_verge_og_image_format_supported( 'https://example.test/uploads/a.avif' ), 'social-only format guard stays separate' );
$google_image = go_verge_schema_editorial_image(42);
check( is_array($google_image) && 'https://example.test/uploads/a.avif' === $google_image['url'], 'AVIF remains a valid Google Article image', $google_image );
$base = home_url('/story/');
$graph = array(
 'plugin' => array('@type'=>'NewsArticle','@id'=>$base.'#article','url'=>$base,'headline'=>'Título editorial','description'=>'Descrição preservada'),
 'theme' => array('@type'=>'Article','@id'=>$base.'#go-article','url'=>$base,'headline'=>'Título editorial','image'=>$google_image),
 'webpage' => array('@type'=>'WebPage','@id'=>$base.'#webpage','mainEntity'=>array('@id'=>$base.'#article')),
 'related' => array('@type'=>'NewsArticle','@id'=>home_url('/other/#article'),'url'=>home_url('/other/')),
);
$clean = go_verge_rank_math_dedupe_current_article_nodes($graph);
check( !isset($clean['plugin']) && isset($clean['theme']), 'one current Article survives at late deduper' );
check( isset($clean['related']), 'deduper preserves related articles at other URLs' );
check( $base.'#go-article' === $clean['webpage']['mainEntity']['@id'], 'graph references follow deduped Article id' );
check( 'Descrição preservada' === $clean['theme']['description'], 'deduper preserves nonconflicting properties' );
check( false === go_verge_seo_active(), 'native head/schema yield ownership to active Rank Math' );
$dated_graph = array(
 'article'=>array('@type'=>'Article','@id'=>$base.'#go-article','url'=>$base,'datePublished'=>'2026-08-18T00:00:00Z','dateModified'=>$old),
 'page'=>array('@type'=>'WebPage','@id'=>$base.'#webpage','url'=>$base,'datePublished'=>'2026-08-18T00:00:00Z','dateModified'=>$old),
 'other'=>array('@type'=>'WebPage','@id'=>home_url('/other/#webpage'),'url'=>home_url('/other/'),'datePublished'=>'2020-01-01T00:00:00Z'),
);
$dated_graph = go_verge_search_freshness_rank_math_graph($dated_graph);
check( go_verge_search_published_iso(42) === $dated_graph['page']['datePublished'], 'current WebPage publication agrees with Article and visible date', $dated_graph['page']['datePublished'] );
check( $editorial === $dated_graph['page']['dateModified'], 'current WebPage modification agrees with Article and visible date' );
check( $dated_graph['page']['datePublished'] === $dated_graph['article']['datePublished'], 'Article and WebPage publication share one clock' );
check( '2020-01-01T00:00:00Z' === $dated_graph['other']['datePublished'], 'related WebPage date remains unchanged' );

// Inspector must use the active SEO provider instead of stale migration metadata.
$GLOBALS['seo_meta'][42]['_yoast_wpseo_meta-robots-noindex'] = '1';
$GLOBALS['seo_meta'][42]['rank_math_robots'] = array('index');
$sample = go_verge_discover_health_recent_sample(1);
check( 0 === $sample['custom_noindex'], 'inactive Yoast noindex does not taint Rank Math health', $sample );
$GLOBALS['seo_meta'][42]['rank_math_robots'] = array('noindex');
$sample = go_verge_discover_health_recent_sample(1);
check( 1 === $sample['custom_noindex'], 'active provider explicit noindex is reported' );

$sitemap_lines = "\nSitemap: https://example.test/sitemap.xml\nSitemap: https://example.test/sitemap-fresh.xml\nSitemap: https://example.test/news-sitemap.xml\n";
$robots_cases = array(
 array("User-agent: Otherbot\nDisallow: /\nUser-agent: Googlebot\nDisallow: /wp-admin/",false,'other crawler root block is not a Googlebot block'),
 array("User-agent: *\nDisallow: /\nUser-agent: Googlebot\nAllow: /",false,'specific Googlebot group replaces wildcard group'),
 array("User-agent: Googlebot\nDisallow: /\nUser-agent: Googlebot\nAllow: /",false,'repeated specific groups combine and Allow wins ties'),
 array("User-agent: *\nDisallow: / # maintenance",true,'inline comments do not hide a real block'),
 array("User-agent: Googlebot\nDisallow: /\nAllow: /$",false,'root Allow exception is honored'),
 array("User-agent: *\nDisallow: /",true,'unqualified root block remains critical for Googlebot'),
);
foreach($robots_cases as $c){$r=go_verge_discover_health_analyze_robots_body($c[0].$sitemap_lines);check($c[1]===$r['critical'],'robots: '.$c[2],$r);}
$r=go_verge_discover_health_analyze_robots_body("User-agent: Otherbot\nDisallow: /wp-content/uploads/\nUser-agent: Googlebot\nAllow: /".$sitemap_lines);
check(0===count($r['issues']),'unrelated crawler image block is not a Google asset warning',$r);
$r=go_verge_discover_health_analyze_robots_body("User-agent: *\nDisallow: /wp-content/uploads/\nAllow: /wp-content/uploads/".$sitemap_lines);
check(0===count($r['issues']),'asset Allow exception resolves same-length Disallow',$r);
$r=go_verge_discover_health_analyze_robots_body("User-agent: *\nDisallow: /wp-admin/".str_replace('Sitemap: ', "sitemap:\t", $sitemap_lines));
check(0===count($r['issues']),'sitemap directives accept case and whitespace',$r);

$failed = array_values(array_filter($checks, static function($c){return !$c['pass'];}));
echo json_encode(array('suite'=>'seo-delivery','theme'=>$theme,'checks'=>count($checks),'passed'=>count($checks)-count($failed),'failed'=>$failed), JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE)."\n";
exit($failed ? 1 : 0);
