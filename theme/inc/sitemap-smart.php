<?php
/**
 * Overdrive Smart Sitemap 3.56.0.
 *
 * A small, resilient sitemap system for the newsroom. It deliberately avoids
 * dependency on Rank Math, WordPress rewrite rules and public page cache.
 * Requests are intercepted on wp_loaded, after CPT/taxonomy registration but
 * before WordPress runs its main query/canonical/404 machinery.
 *
 * Canonical endpoints:
 * - /sitemap.xml
 * - /sitemap-fresh.xml (new or substantially updated editorial URLs, 7 days)
 * - /sitemap-posts.xml (or numbered shards only after 20k URLs)
 * - /sitemap-pages.xml
 * - /sitemap-games.xml
 * - /sitemap-productions.xml
 * - /sitemap-entities.xml
 * - /sitemap-categories.xml
 * - /sitemap-platforms.xml
 * - /sitemap-services.xml
 * - /sitemap-authors.xml
 * - /news-sitemap.xml (owned by sitemap-news.php)
 *
 * Legacy /sitemap-posts-YYYY-MM.xml endpoints remain readable but are no longer
 * advertised in the main index.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

const GO_VERGE_SMART_SITEMAP_EPOCH_OPTION = 'go_smart_sitemap_epoch';
const GO_VERGE_SMART_SITEMAP_TOUCH_OPTION = 'go_smart_sitemap_touch';
const GO_VERGE_SMART_SITEMAP_POSTS_PER_FILE = 20000;
const GO_VERGE_PREFERRED_SOURCE_OPTION = 'go_preferred_source_cta_enabled';

/** Official Google Preferred Sources CTA introduced for publishers in Aug 2026. */
function go_verge_preferred_source_deeplink() {
	$host = (string) wp_parse_url( home_url(), PHP_URL_HOST );
	return 'https://www.google.com/preferences/source?q=' . rawurlencode( $host );
}
function go_verge_preferred_source_enqueue() {
	wp_enqueue_script( 'go-google-preferred-source', 'https://news.google.com/swg/js/v1/publisher.js', array(), null, array( 'strategy'=>'async', 'in_footer'=>false ) );
}
function go_verge_preferred_source_markup() {
	go_verge_preferred_source_enqueue();
	return '<aside class="go-preferred-source" aria-label="Google Fontes preferidas"><strong>Quer ver mais do Overdrive no Google?</strong><span>Adicione o site às suas Fontes preferidas.</span><div google-add-preferred-source-btn data-lang="pt-BR"></div></aside>';
}
function go_verge_preferred_source_shortcode() { return go_verge_preferred_source_markup(); }
add_shortcode( 'go_preferred_source', 'go_verge_preferred_source_shortcode' );
function go_verge_preferred_source_auto_content( $content ) {
	if ( is_admin() || ! is_singular( 'post' ) || ! in_the_loop() || ! is_main_query() || ! (bool) get_option( GO_VERGE_PREFERRED_SOURCE_OPTION, false ) ) { return $content; }
	return $content . go_verge_preferred_source_markup();
}
add_filter( 'the_content', 'go_verge_preferred_source_auto_content', 80 );
function go_verge_preferred_source_css() {
	if ( ! is_singular( 'post' ) || ! (bool) get_option( GO_VERGE_PREFERRED_SOURCE_OPTION, false ) ) { return; }
	echo '<style>.go-preferred-source{margin:28px 0;padding:16px 18px;border:1px solid rgba(127,127,127,.24);border-radius:10px;display:flex;gap:8px 14px;align-items:center;flex-wrap:wrap}.go-preferred-source strong{font-size:15px}.go-preferred-source span{font-size:13px;opacity:.76}</style>';
}
add_action( 'wp_head', 'go_verge_preferred_source_css', 90 );

function go_verge_smart_sitemap_url() { return home_url( '/sitemap.xml' ); }
function go_verge_smart_sitemap_fresh_url() { return home_url( '/sitemap-fresh.xml' ); }
function go_verge_smart_sitemap_epoch() { return max( 1, absint( get_option( GO_VERGE_SMART_SITEMAP_EPOCH_OPTION, 1 ) ) ); }
function go_verge_smart_sitemap_touch_map() {
	$map = get_option( GO_VERGE_SMART_SITEMAP_TOUCH_OPTION, array() );
	return is_array( $map ) ? $map : array();
}
function go_verge_smart_sitemap_record_touch( $key, $timestamp = 0 ) {
	$key = sanitize_key( str_replace( ':', '-', (string) $key ) );
	if ( '' === $key ) { return; }
	$map = go_verge_smart_sitemap_touch_map();
	$map[ $key ] = $timestamp ? absint( $timestamp ) : time();
	arsort( $map, SORT_NUMERIC );
	update_option( GO_VERGE_SMART_SITEMAP_TOUCH_OPTION, array_slice( $map, 0, 160, true ), false );
}
function go_verge_smart_sitemap_bump( $post_id = 0 ) {
	update_option( GO_VERGE_SMART_SITEMAP_EPOCH_OPTION, go_verge_smart_sitemap_epoch() + 1, false );
	update_option( 'go_smart_sitemap_last_change', time(), false );
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return; }
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) { return; }
	$map = array( 'post'=>'posts', 'page'=>'pages', 'games'=>'games', 'productions'=>'productions', 'go_entity'=>'entities' );
	if ( isset( $map[ $post->post_type ] ) ) { go_verge_smart_sitemap_record_touch( $map[ $post->post_type ] ); }
	if ( 'post' === $post->post_type ) {
		go_verge_smart_sitemap_record_touch( 'fresh' );
		go_verge_smart_sitemap_record_touch( 'categories' );
		go_verge_smart_sitemap_record_touch( 'platforms' );
		go_verge_smart_sitemap_record_touch( 'services' );
		$ym = get_post_time( 'Y-m', false, $post_id );
		if ( $ym ) { go_verge_smart_sitemap_record_touch( 'posts-' . $ym ); }
	}
}
function go_verge_smart_sitemap_on_transition( $new_status, $old_status, $post ) {
	if ( ! ( $post instanceof WP_Post ) || $new_status === $old_status ) { return; }
	if ( ! in_array( $post->post_type, array( 'post','page','games','productions','go_entity' ), true ) ) { return; }
	if ( 'publish' === $new_status || 'publish' === $old_status ) { go_verge_smart_sitemap_bump( $post->ID ); }
}
add_action( 'transition_post_status', 'go_verge_smart_sitemap_on_transition', 70, 3 );
function go_verge_smart_sitemap_on_post_updated( $post_id, $after, $before ) {
	if ( ! ( $after instanceof WP_Post ) || ! ( $before instanceof WP_Post ) || 'publish' !== $after->post_status ) { return; }
	if ( ! in_array( $after->post_type, array( 'post','page','games','productions','go_entity' ), true ) ) { return; }
	/* A password change changes sitemap eligibility even with identical copy.
	 * Date/author changes also affect ordering and the author/index surfaces. */
	foreach ( array( 'post_title', 'post_content', 'post_excerpt', 'post_name', 'post_password', 'post_date', 'post_date_gmt', 'post_author' ) as $field ) {
		if ( ( $after->$field ?? null ) !== ( $before->$field ?? null ) ) { go_verge_smart_sitemap_bump( $post_id ); break; }
	}
}
add_action( 'post_updated', 'go_verge_smart_sitemap_on_post_updated', 70, 3 );
function go_verge_smart_sitemap_meta_changed( $meta_id, $post_id, $meta_key, $meta_value = null ) {
	unset( $meta_id, $meta_value );
	if ( ! in_array( (string) $meta_key, array( 'rank_math_title','rank_math_description','rank_math_canonical_url','rank_math_robots','_yoast_wpseo_title','_yoast_wpseo_metadesc','_yoast_wpseo_canonical','_yoast_wpseo_meta-robots-noindex','_yoast_wpseo_redirect','_thumbnail_id','_go_search_content_modified_gmt', defined( 'GO_VERGE_FIRST_PUBLISHED_META' ) ? GO_VERGE_FIRST_PUBLISHED_META : '_go_first_published_gmt' ), true ) ) { return; }
	if ( 'publish' === get_post_status( $post_id ) ) { go_verge_smart_sitemap_bump( $post_id ); }
}
add_action( 'added_post_meta', 'go_verge_smart_sitemap_meta_changed', 70, 4 );
add_action( 'updated_post_meta', 'go_verge_smart_sitemap_meta_changed', 70, 4 );
add_action( 'deleted_post_meta', 'go_verge_smart_sitemap_meta_changed', 70, 4 );
/** A profile-only edit changes the author XML without touching a post. */
function go_verge_smart_sitemap_author_meta_changed( $meta_id, $user_id, $meta_key, $meta_value = null ) {
	unset( $meta_id, $meta_value );
	if ( '_go_author_profile_schema_modified_gmt' !== (string) $meta_key || ! count_user_posts( absint( $user_id ), 'post', true ) ) { return; }
	go_verge_smart_sitemap_record_touch( 'authors' );
	go_verge_smart_sitemap_bump();
}
add_action( 'added_user_meta', 'go_verge_smart_sitemap_author_meta_changed', 70, 4 );
add_action( 'updated_user_meta', 'go_verge_smart_sitemap_author_meta_changed', 70, 4 );
add_action( 'deleted_user_meta', 'go_verge_smart_sitemap_author_meta_changed', 70, 4 );
function go_verge_smart_sitemap_terms_changed( $object_id, $terms, $tt_ids, $taxonomy ) {
	unset( $terms, $tt_ids );
	if ( ! in_array( $taxonomy, array( 'category','post_tag','go_platform','go_service' ), true ) || 'publish' !== get_post_status( $object_id ) ) { return; }
	go_verge_smart_sitemap_bump( $object_id );
	$keys = array( 'category'=>'categories', 'post_tag'=>'tags', 'go_platform'=>'platforms', 'go_service'=>'services' );
	go_verge_smart_sitemap_record_touch( $keys[ $taxonomy ] );
}
add_action( 'set_object_terms', 'go_verge_smart_sitemap_terms_changed', 120, 4 );
function go_verge_smart_sitemap_term_changed() {
	$f = current_filter();
	if ( false !== strpos( $f, 'category' ) ) { go_verge_smart_sitemap_record_touch( 'categories' ); }
	if ( false !== strpos( $f, 'post_tag' ) ) { go_verge_smart_sitemap_record_touch( 'tags' ); }
	if ( false !== strpos( $f, 'go_platform' ) ) { go_verge_smart_sitemap_record_touch( 'platforms' ); }
	if ( false !== strpos( $f, 'go_service' ) ) { go_verge_smart_sitemap_record_touch( 'services' ); }
	update_option( GO_VERGE_SMART_SITEMAP_EPOCH_OPTION, go_verge_smart_sitemap_epoch() + 1, false );
	update_option( 'go_smart_sitemap_last_change', time(), false );
}
foreach ( array( 'created_category','edited_category','delete_category','created_post_tag','edited_post_tag','delete_post_tag','created_go_platform','edited_go_platform','delete_go_platform','created_go_service','edited_go_service','delete_go_service' ) as $hook ) { add_action( $hook, 'go_verge_smart_sitemap_term_changed', 90 ); }

/**
 * One-shot cache invalidation after a release that changes generated XML.
 *
 * Route transients live up to an hour and are keyed by the epoch, so a fix to a
 * <lastmod> clock would otherwise keep serving the old value until the next
 * editorial save. Bump once per release version, never on every admin request.
 */
const GO_VERGE_SMART_SITEMAP_OUTPUT_VERSION = '3.88.0-publication-clock';

function go_verge_smart_sitemap_invalidate_on_release() {
	if ( GO_VERGE_SMART_SITEMAP_OUTPUT_VERSION === (string) get_option( 'go_smart_sitemap_output_version', '' ) ) {
		return;
	}
	update_option( 'go_smart_sitemap_output_version', GO_VERGE_SMART_SITEMAP_OUTPUT_VERSION, false );
	update_option( GO_VERGE_SMART_SITEMAP_EPOCH_OPTION, go_verge_smart_sitemap_epoch() + 1, false );
	update_option( 'go_smart_sitemap_last_change', time(), false );
	if ( defined( 'GO_VERGE_NEWS_SITEMAP_TRANSIENT' ) ) {
		delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
	}
}
add_action( 'admin_init', 'go_verge_smart_sitemap_invalidate_on_release', 97 );

function go_verge_smart_sitemap_xml( $value ) {
	$value = (string) $value;
	return function_exists( 'esc_xml' ) ? esc_xml( $value ) : htmlspecialchars( $value, ENT_XML1 | ENT_QUOTES, 'UTF-8' );
}
/**
 * Read Yoast's current indexability for an arbitrary public URL when its
 * Indexable exists. This is deliberately a fallback for low-cardinality
 * surfaces (terms/authors), not a per-post dependency for 20k-post shards.
 */
function go_verge_smart_sitemap_yoast_url_state( $url ) {
	$state = array( 'known' => false, 'noindex' => false, 'canonical' => '' );
	if ( ! $url || ! function_exists( 'YoastSEO' ) ) { return $state; }
	try {
		$surface = YoastSEO()->meta->for_url( $url );
	} catch ( Throwable $e ) {
		return $state;
	}
	if ( ! is_object( $surface ) ) { return $state; }
	$state['known'] = true;
	$state['canonical'] = ! empty( $surface->canonical ) ? esc_url_raw( (string) $surface->canonical ) : '';
	$robots = isset( $surface->robots ) && is_array( $surface->robots ) ? $surface->robots : array();
	foreach ( array_merge( array_keys( $robots ), array_values( $robots ) ) as $directive ) {
		if ( false !== strpos( strtolower( (string) $directive ), 'noindex' ) ) {
			$state['noindex'] = true;
			break;
		}
	}
	return $state;
}

/** Whether Yoast globally allows a public post type/taxonomy to be indexed. */
function go_verge_smart_sitemap_yoast_object_type_indexable( $object_type, $kind = 'post_type' ) {
	if ( ! function_exists( 'YoastSEO' ) ) { return true; }
	try {
		$helpers = YoastSEO()->helpers;
		if ( 'taxonomy' === $kind && isset( $helpers->taxonomy ) && method_exists( $helpers->taxonomy, 'is_indexable' ) ) {
			return (bool) $helpers->taxonomy->is_indexable( $object_type );
		}
		if ( 'post_type' === $kind && isset( $helpers->post_type ) && method_exists( $helpers->post_type, 'is_indexable' ) ) {
			return (bool) $helpers->post_type->is_indexable( $object_type );
		}
	} catch ( Throwable $e ) {
		return true;
	}
	return true;
}


/** Whether the current Yoast configuration exposes author archives to search. */
function go_verge_smart_sitemap_yoast_authors_indexable() {
	if ( ! function_exists( 'YoastSEO' ) ) { return true; }
	try {
		$helpers = YoastSEO()->helpers;
		if ( isset( $helpers->author_archive ) && method_exists( $helpers->author_archive, 'are_disabled' ) && $helpers->author_archive->are_disabled() ) {
			return false;
		}
	} catch ( Throwable $e ) {
		/* Fall through to the stable option API below. */
	}
	/* Yoast's author sitemap also treats this legacy/current search-visibility
	 * switch as authoritative. Reading it here avoids inferring a global setting
	 * from one author's individual indexability. */
	if ( class_exists( 'WPSEO_Options' ) ) {
		try {
			if ( WPSEO_Options::get( 'disable-author', false ) || WPSEO_Options::get( 'noindex-author-wpseo', false ) ) {
				return false;
			}
		} catch ( Throwable $e ) {
			return true;
		}
	}
	return true;
}

/**
 * Rank Math's robots decision for one author archive: the user's own robots meta
 * first, then the global author setting, as Paper\Author::robots() resolves it.
 */
function go_verge_smart_sitemap_rank_math_author_noindex( $user_id ) {
	if ( ! class_exists( 'RankMath\\Helper' ) ) { return false; }
	if ( true === \RankMath\Helper::get_settings( 'titles.disable_author_archives' ) ) { return true; }
	$robots = get_user_meta( absint( $user_id ), 'rank_math_robots', true );
	if ( is_array( $robots ) && $robots ) {
		return in_array( 'noindex', $robots, true );
	}
	return (bool) \RankMath\Helper::get_settings( 'titles.author_custom_robots' ) && in_array( 'noindex', (array) \RankMath\Helper::get_settings( 'titles.author_robots' ), true );
}

/**
 * Return the SEO provider that currently owns page-level index directives.
 *
 * Rank Math is preferred when both plugins happen to be loaded because it is
 * the active newsroom provider. Legacy Yoast post meta is common after provider
 * migrations and must not silently remove a valid Rank Math URL from sitemap.
 */
function go_verge_smart_sitemap_seo_provider() {
	$rank_math = defined( 'RANK_MATH_VERSION' ) || function_exists( 'rank_math' ) || class_exists( 'RankMath\\Helper' );
	$yoast     = defined( 'WPSEO_VERSION' ) || function_exists( 'YoastSEO' );
	if ( $rank_math ) { return 'rank-math'; }
	if ( $yoast ) { return 'yoast'; }
	return 'none';
}

/** Flatten Rank Math robots meta and detect an explicit noindex directive. */
function go_verge_smart_sitemap_rank_math_noindex_meta( $object_id, $kind = 'post' ) {
	$robots = 'term' === $kind ? get_term_meta( $object_id, 'rank_math_robots', true ) : get_post_meta( $object_id, 'rank_math_robots', true );
	if ( is_string( $robots ) ) { $robots = preg_split( '/[\\s,]+/', strtolower( $robots ) ); }
	if ( ! is_array( $robots ) ) { return false; }
	$flat = array();
	array_walk_recursive( $robots, static function( $v ) use ( &$flat ) { $flat[] = strtolower( (string) $v ); } );
	foreach ( $flat as $directive ) {
		if ( false !== strpos( $directive, 'noindex' ) ) { return true; }
	}
	return false;
}

function go_verge_smart_sitemap_noindex( $object_id, $kind = 'post' ) {
	$provider = go_verge_smart_sitemap_seo_provider();

	/* Only the provider that is actually active gets to make the page-level
	 * decision. When neither plugin is loaded, keep the historical conservative
	 * behavior and honour both metadata families. */
	if ( in_array( $provider, array( 'rank-math', 'none' ), true ) && go_verge_smart_sitemap_rank_math_noindex_meta( $object_id, $kind ) ) {
		return true;
	}

	if ( ! in_array( $provider, array( 'yoast', 'none' ), true ) ) {
		return false;
	}

	if ( 'term' !== $kind ) {
		$yoast_noindex = (string) get_post_meta( $object_id, '_yoast_wpseo_meta-robots-noindex', true );
		return '1' === trim( $yoast_noindex );
	}

	$term = get_term( $object_id );
	if ( $term instanceof WP_Term ) {
		$link = get_term_link( $term );
		if ( ! is_wp_error( $link ) && $link ) {
			$state = go_verge_smart_sitemap_yoast_url_state( $link );
			return ! empty( $state['noindex'] );
		}
	}
	return false;
}

/** Identify legacy promotion pages already consolidated into the category. */
function go_verge_smart_sitemap_is_retired_promotions_page( $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'page' !== $post->post_type || ! in_array( $post->post_name, array( 'promocoes', 'promocoes-2', 'promocoes-3' ), true ) || ! function_exists( 'go_verge_v7_category_url' ) ) {
		return false;
	}
	/* Legacy page_link resolves the duplicate pages to the old go_promotion
	 * archive. V7 redirects that archive to this published category surface. */
	$term = get_term_by( 'slug', 'promocoes', 'category' );
	if ( ! ( $term instanceof WP_Term ) ) {
		return false;
	}
	$target = get_term_link( $term );
	return ! is_wp_error( $target ) && '' !== (string) $target;
}

/** Explain why a document is omitted; an empty string means sitemap-eligible. */
function go_verge_smart_sitemap_post_exclusion_reason( $post_id ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) { return 'post-not-found'; }
	if ( 'publish' !== $post->post_status ) { return 'not-published'; }
	if ( '' !== (string) $post->post_password ) { return 'password-protected'; }
	if ( ! in_array( $post->post_type, array( 'post','page','games','productions','go_entity' ), true ) ) { return 'unsupported-post-type'; }
	if ( go_verge_smart_sitemap_is_retired_promotions_page( $post ) ) { return 'retired-promotions-page'; }
	$provider = go_verge_smart_sitemap_seo_provider();
	if ( in_array( $provider, array( 'yoast', 'none' ), true ) && ! go_verge_smart_sitemap_yoast_object_type_indexable( $post->post_type, 'post_type' ) ) { return 'post-type-noindex'; }
	if ( go_verge_smart_sitemap_noindex( $post_id ) ) { return 'robots-noindex'; }

	/* Yoast redirect metadata is authoritative only while Yoast is the active
	 * SEO provider. Stale migration leftovers must not suppress Rank Math URLs. */
	if ( in_array( $provider, array( 'yoast', 'none' ), true ) && '' !== trim( (string) get_post_meta( $post_id, '_yoast_wpseo_redirect', true ) ) ) {
		return 'seo-redirect';
	}

	if ( 'page' === $post->post_type ) {
		$excluded = array();
		if ( function_exists( 'go_verge_search_utility_page_ids' ) ) { $excluded = array_merge( $excluded, go_verge_search_utility_page_ids() ); }
		if ( function_exists( 'go_verge_search_redirected_page_ids' ) ) { $excluded = array_merge( $excluded, go_verge_search_redirected_page_ids() ); }
		if ( in_array( $post_id, array_map( 'absint', $excluded ), true ) ) { return 'utility-or-redirected-page'; }
		if ( function_exists( 'go_verge_v7_retired_hub_pages' ) && isset( go_verge_v7_retired_hub_pages()[ $post->post_name ] ) ) { return 'retired-hub'; }
		if ( function_exists( 'go_verge_v7_path_is_redirected' ) && go_verge_v7_path_is_redirected( (string) wp_parse_url( (string) get_permalink( $post_id ), PHP_URL_PATH ) ) ) { return 'redirected-path'; }
	}

	if ( 'go_entity' === $post->post_type ) {
		if ( function_exists( 'go_verge_v27_rank_math_sitemap_entry' ) && false === go_verge_v27_rank_math_sitemap_entry( true, 'post', $post ) ) { return 'entity-shadow'; }
		if ( function_exists( 'go_verge_v27_entity_is_redirected' ) && go_verge_v27_entity_is_redirected( $post_id ) ) { return 'entity-redirect'; }
	}

	if ( 'games' === $post->post_type && class_exists( 'Overdrive\\GamesDB\\Frontend' ) && get_post_meta( $post_id, '_godb_created', true ) && '1' !== get_post_meta( $post_id, '_godb_reviewed', true ) ) {
		return 'game-awaiting-review';
	}

	$permalink = get_permalink( $post_id );
	if ( ! $permalink ) { return 'missing-permalink'; }

	/* A URL that Rank Math Redirections answers with a 301 is not a document
	 * Google can index; listing it only produces "Page with redirect". */
	if ( function_exists( 'go_verge_rank_math_redirect_target' ) && '' !== go_verge_rank_math_redirect_target( $permalink ) ) { return 'rank-math-redirect'; }

	$custom = '';
	if ( 'rank-math' === $provider ) {
		$custom = trim( (string) get_post_meta( $post_id, 'rank_math_canonical_url', true ) );
	} elseif ( 'yoast' === $provider ) {
		$custom = trim( (string) get_post_meta( $post_id, '_yoast_wpseo_canonical', true ) );
	} else {
		$custom = trim( (string) get_post_meta( $post_id, 'rank_math_canonical_url', true ) );
		if ( '' === $custom ) { $custom = trim( (string) get_post_meta( $post_id, '_yoast_wpseo_canonical', true ) ); }
	}
	/* A stored canonical that is this same post by another address (/?p=ID,
	 * http/www/trailing-slash variants) is self-canonical, not an exclusion. */
	if ( '' !== $custom && untrailingslashit( $custom ) !== untrailingslashit( $permalink ) && ! ( function_exists( 'go_verge_canonical_points_to_self' ) && go_verge_canonical_points_to_self( $custom, $post_id ) ) ) { return 'custom-canonical'; }
	return '';
}

function go_verge_smart_sitemap_post_eligible( $post_id ) {
	return '' === go_verge_smart_sitemap_post_exclusion_reason( $post_id );
}
function go_verge_smart_sitemap_post_lastmod( $post_id ) {
	$iso = function_exists( 'go_verge_search_modified_iso' ) ? go_verge_search_modified_iso( $post_id ) : get_post_modified_time( 'c', true, $post_id );
	$ts = $iso ? strtotime( $iso ) : 0;
	$pub = function_exists( 'go_verge_search_published_timestamp' ) ? (int) go_verge_search_published_timestamp( $post_id ) : (int) get_post_time( 'U', true, $post_id );
	$ts = max( $ts ?: 0, $pub );
	return $ts ? gmdate( 'c', $ts ) : '';
}
function go_verge_smart_sitemap_featured_image( $post_id ) {
	$image_id = get_post_thumbnail_id( $post_id );
	if ( ! $image_id || ! function_exists( 'go_verge_rank_math_discover_image' ) ) { return ''; }
	$image = go_verge_rank_math_discover_image( $image_id );
	return ! empty( $image['url'] ) ? esc_url_raw( $image['url'] ) : '';
}

function go_verge_smart_sitemap_post_count() {
	global $wpdb;
	return max( 0, (int) $wpdb->get_var( "SELECT COUNT(ID) FROM {$wpdb->posts} WHERE post_type='post' AND post_status='publish' AND post_password=''" ) ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
}
function go_verge_smart_sitemap_post_shards() { return max( 1, (int) ceil( go_verge_smart_sitemap_post_count() / GO_VERGE_SMART_SITEMAP_POSTS_PER_FILE ) ); }
function go_verge_smart_sitemap_post_months() {
	global $wpdb;
	$rows = $wpdb->get_results( "SELECT DATE_FORMAT(post_date,'%Y-%m') AS ym, MAX(post_modified_gmt) AS modified_gmt, COUNT(*) AS qty FROM {$wpdb->posts} WHERE post_type='post' AND post_status='publish' AND post_password='' AND post_date > '2000-01-01 00:00:00' GROUP BY DATE_FORMAT(post_date,'%Y-%m') ORDER BY ym DESC", ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	return is_array( $rows ) ? $rows : array();
}
function go_verge_smart_sitemap_type_lastmod( $post_type ) {
	global $wpdb;
	$value = $wpdb->get_var( $wpdb->prepare( "SELECT MAX(post_modified_gmt) FROM {$wpdb->posts} WHERE post_type=%s AND post_status='publish' AND post_password=''", $post_type ) ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$ts = $value && '0000-00-00 00:00:00' !== $value ? strtotime( $value . ' UTC' ) : 0;
	$key = array( 'post'=>'posts','page'=>'pages','games'=>'games','productions'=>'productions','go_entity'=>'entities' )[ $post_type ] ?? sanitize_key( $post_type );
	return max( $ts ?: 0, absint( go_verge_smart_sitemap_touch_map()[ $key ] ?? 0 ) );
}
function go_verge_smart_sitemap_month_lastmod( $ym, $db_gmt = '' ) {
	$ts = $db_gmt && '0000-00-00 00:00:00' !== $db_gmt ? strtotime( $db_gmt . ' UTC' ) : 0;
	return max( $ts ?: 0, absint( go_verge_smart_sitemap_touch_map()[ sanitize_key( 'posts-' . $ym ) ] ?? 0 ) );
}
function go_verge_smart_sitemap_term_lastmod( $taxonomy ) {
	$key_map = array( 'category'=>'categories', 'post_tag'=>'tags', 'go_platform'=>'platforms', 'go_service'=>'services' );
	$touch = absint( go_verge_smart_sitemap_touch_map()[ $key_map[ $taxonomy ] ?? sanitize_key( $taxonomy ) ] ?? 0 );
	global $wpdb;
	/* MySQL reads UNIX_TIMESTAMP() in the session time zone, so it skewed this
	 * already-UTC column by the server offset and could date a <lastmod> in the
	 * future. Parse the raw value as UTC, like every sibling clock here. */
	$value = $wpdb->get_var( "SELECT MAX(post_modified_gmt) FROM {$wpdb->posts} WHERE post_type='post' AND post_status='publish' AND post_password=''" ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	$ts    = $value && '0000-00-00 00:00:00' !== $value ? (int) strtotime( $value . ' UTC' ) : 0;
	return max( $touch, $ts ?: 0 );
}

/** Latest meaningful author-profile change for sitemap-index lastmod. */
function go_verge_smart_sitemap_authors_lastmod() {
	$max = absint( go_verge_smart_sitemap_touch_map()['authors'] ?? 0 );
	foreach ( get_users( array( 'fields' => 'ID' ) ) as $user_id ) {
		$user_id = absint( $user_id );
		if ( ! count_user_posts( $user_id, 'post', true ) ) { continue; }
		$iso = go_verge_smart_sitemap_author_lastmod( $user_id );
		$ts  = $iso ? strtotime( $iso ) : 0;
		$max = max( $max, $ts ?: 0 );
	}
	return $max;
}

function go_verge_smart_sitemap_index_children() {
	$children = array();
	$post_last = go_verge_smart_sitemap_type_lastmod( 'post' );
	if ( go_verge_smart_sitemap_yoast_object_type_indexable( 'post', 'post_type' ) ) {
		$latest = get_posts( array( 'post_type'=>'post','post_status'=>'publish','posts_per_page'=>1,'orderby'=>'modified','order'=>'DESC','fields'=>'ids','no_found_rows'=>true,'ignore_sticky_posts'=>true ) );
		$news_last = ! empty( $latest[0] ) ? strtotime( go_verge_smart_sitemap_post_lastmod( (int) $latest[0] ) ) : 0;
		$news_last = max( $news_last ?: 0, absint( go_verge_smart_sitemap_touch_map()['fresh'] ?? 0 ) );
		$children[] = array( 'news', home_url( '/news-sitemap.xml' ), $news_last );
		$children[] = array( 'fresh', go_verge_smart_sitemap_fresh_url(), max( $news_last, absint( go_verge_smart_sitemap_touch_map()['fresh'] ?? 0 ) ) );

		$shards = go_verge_smart_sitemap_post_shards();
		if ( 1 === $shards ) {
			$children[] = array( 'posts', home_url( '/sitemap-posts.xml' ), $post_last );
		} else {
			for ( $i = 1; $i <= $shards; $i++ ) { $children[] = array( 'posts-' . $i, home_url( '/sitemap-posts-' . $i . '.xml' ), $post_last ); }
		}
	}
	foreach ( array( 'page'=>'pages','games'=>'games','productions'=>'productions','go_entity'=>'entities' ) as $type => $slug ) {
		if ( ! post_type_exists( $type ) || ! go_verge_smart_sitemap_yoast_object_type_indexable( $type, 'post_type' ) ) { continue; }
		$count = wp_count_posts( $type );
		if ( empty( $count->publish ) ) { continue; }
		$children[] = array( $slug, home_url( '/sitemap-' . $slug . '.xml' ), go_verge_smart_sitemap_type_lastmod( $type ) );
	}
	/* Author profile pages are first-class E-E-A-T/entity URLs. Keeping them in
	 * the canonical sitemap also accelerates recrawls when a legacy title or bio
	 * is still cached by Search. */
	if ( go_verge_smart_sitemap_yoast_authors_indexable() ) {
		$children[] = array( 'authors', home_url( '/sitemap-authors.xml' ), max( $post_last, go_verge_smart_sitemap_authors_lastmod() ) );
	}
	if ( go_verge_smart_sitemap_yoast_object_type_indexable( 'category', 'taxonomy' ) ) {
		$children[] = array( 'categories', home_url( '/sitemap-categories.xml' ), go_verge_smart_sitemap_term_lastmod( 'category' ) );
	}
	foreach ( array( 'go_platform'=>'platforms', 'go_service'=>'services' ) as $taxonomy => $slug ) {
		if ( ! taxonomy_exists( $taxonomy ) || ! go_verge_smart_sitemap_yoast_object_type_indexable( $taxonomy, 'taxonomy' ) ) { continue; }
		$count = wp_count_terms( $taxonomy, array( 'hide_empty'=>true ) );
		if ( ! is_wp_error( $count ) && (int) $count > 0 ) {
			$children[] = array( $slug, home_url( '/sitemap-' . $slug . '.xml' ), go_verge_smart_sitemap_term_lastmod( $taxonomy ) );
		}
	}
	return $children;
}
function go_verge_smart_sitemap_build_index() {
	$lines = array( '<?xml version="1.0" encoding="UTF-8"?>', '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' );
	foreach ( go_verge_smart_sitemap_index_children() as $child ) {
		$lines[] = '  <sitemap>';
		$lines[] = '    <loc>' . go_verge_smart_sitemap_xml( $child[1] ) . '</loc>';
		if ( ! empty( $child[2] ) ) { $lines[] = '    <lastmod>' . gmdate( 'c', (int) $child[2] ) . '</lastmod>'; }
		$lines[] = '  </sitemap>';
	}
	$lines[] = '</sitemapindex>';
	return implode( "\n", $lines ) . "\n";
}
function go_verge_smart_sitemap_urlset_open() { return array( '<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">' ); }
function go_verge_smart_sitemap_append_url( &$lines, $loc, $lastmod = '', $image = '' ) {
	if ( ! $loc ) { return; }
	$lines[] = '  <url>';
	$lines[] = '    <loc>' . go_verge_smart_sitemap_xml( $loc ) . '</loc>';
	if ( $lastmod ) { $lines[] = '    <lastmod>' . go_verge_smart_sitemap_xml( $lastmod ) . '</lastmod>'; }
	if ( $image ) { $lines[] = '    <image:image>'; $lines[] = '      <image:loc>' . go_verge_smart_sitemap_xml( $image ) . '</image:loc>'; $lines[] = '    </image:image>'; }
	$lines[] = '  </url>';
}
/**
 * Fast-discovery sitemap for new or materially updated posts from the last
 * seven days. It complements the full canonical sitemap with a small, high-
 * signal set that is easier to monitor and resubmit after newsroom updates.
 */
function go_verge_smart_sitemap_build_fresh() {
	$after = gmdate( 'Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS );
	$cutoff = strtotime( $after . ' UTC' );
	/* The public lastmod is an editorial clock stored in post meta. Query its
	 * clocks, then filter by the exact value emitted below: administrative saves
	 * cannot make stale content look fresh, while a correction to an old story is
	 * not lost merely because post_modified_gmt stayed unchanged. */
	$raw_ids = get_posts( array(
		'post_type'=>'post','post_status'=>'publish','posts_per_page'=>1500,'orderby'=>'modified','order'=>'DESC','fields'=>'ids',
		'ignore_sticky_posts'=>true,'no_found_rows'=>true,'has_password'=>false,
		'date_query'=>array(array('column'=>'post_modified_gmt','after'=>$after,'inclusive'=>true)),
		'update_post_meta_cache'=>false,'update_post_term_cache'=>false,
	) );
	$editorial_ids = get_posts( array(
		'post_type'=>'post','post_status'=>'publish','posts_per_page'=>1500,'orderby'=>'meta_value','order'=>'DESC','fields'=>'ids',
		'ignore_sticky_posts'=>true,'no_found_rows'=>true,'has_password'=>false,
		'meta_key'=>'_go_search_content_modified_gmt','meta_value'=>$after,'meta_compare'=>'>=','meta_type'=>'DATETIME',
		'update_post_meta_cache'=>false,'update_post_term_cache'=>false,
	) );
	/* wp_publish_post(), including scheduled publication, changes status without
	 * rewriting post_modified. A post prepared long ago can become public now. */
	$published_ids = get_posts( array(
		'post_type'=>'post','post_status'=>'publish','posts_per_page'=>1500,'orderby'=>'meta_value','order'=>'DESC','fields'=>'ids',
		'ignore_sticky_posts'=>true,'no_found_rows'=>true,'has_password'=>false,
		'meta_key'=>defined( 'GO_VERGE_FIRST_PUBLISHED_META' ) ? GO_VERGE_FIRST_PUBLISHED_META : '_go_first_published_gmt',
		'meta_value'=>$after,'meta_compare'=>'>=','meta_type'=>'DATETIME',
		'update_post_meta_cache'=>false,'update_post_term_cache'=>false,
	) );
	$ids = array_values( array_unique( array_map( 'absint', array_merge( $raw_ids, $editorial_ids, $published_ids ) ) ) );
	$posts = $ids ? get_posts( array(
		'post_type'=>'post','post_status'=>'publish','posts_per_page'=>count($ids),'post__in'=>$ids,'orderby'=>'post__in',
		'ignore_sticky_posts'=>true,'no_found_rows'=>true,'has_password'=>false,
		'update_post_meta_cache'=>true,'update_post_term_cache'=>true,
	) ) : array();
	usort( $posts, static function ( $left, $right ) {
		$left_ts  = strtotime( go_verge_smart_sitemap_post_lastmod( (int) $left->ID ) );
		$right_ts = strtotime( go_verge_smart_sitemap_post_lastmod( (int) $right->ID ) );
		return ( $right_ts ?: 0 ) <=> ( $left_ts ?: 0 );
	} );
	$lines = go_verge_smart_sitemap_urlset_open();
	$seen_urls = array();
	$hub_lastmods = array();
	foreach ( $posts as $post ) {
		$id=(int)$post->ID;
		$lastmod = go_verge_smart_sitemap_post_lastmod( $id );
		$lastmod_ts = $lastmod ? strtotime( $lastmod ) : 0;
		if ( $lastmod_ts < $cutoff || ! go_verge_smart_sitemap_post_eligible( $id ) ) { continue; }

		$permalink = get_permalink( $id );
		if ( $permalink ) {
			$key = strtolower( untrailingslashit( (string) $permalink ) );
			$seen_urls[ $key ] = true;
			go_verge_smart_sitemap_append_url( $lines, $permalink, $lastmod, go_verge_smart_sitemap_featured_image( $id ) );
		}

		/* A fresh story materially updates its category landing page too. Include
		 * the canonical child + canonical ancestors in the discovery sitemap so
		 * every desk receives the same recrawl signal as its newest stories. */
		$terms = wp_get_post_terms( $id, 'category' );
		if ( is_wp_error( $terms ) ) { continue; }
		foreach ( $terms as $term ) {
			$term_ids = array_merge( array( (int) $term->term_id ), array_map( 'absint', get_ancestors( $term->term_id, 'category', 'taxonomy' ) ) );
			foreach ( array_unique( $term_ids ) as $term_id ) {
				$hub_term = get_term( $term_id, 'category' );
				if ( ! ( $hub_term instanceof WP_Term ) || 'interno' === $hub_term->slug ) { continue; }
				if ( function_exists( 'go_verge_smart_sitemap_term_eligible' ) && ! go_verge_smart_sitemap_term_eligible( $hub_term ) ) { continue; }
				$url = get_term_link( $hub_term );
				if ( is_wp_error( $url ) || ! $url ) { continue; }
				$key = strtolower( untrailingslashit( (string) $url ) );
				if ( ! isset( $hub_lastmods[ $key ] ) || strtotime( $hub_lastmods[ $key ]['lastmod'] ) < $lastmod_ts ) {
					$hub_lastmods[ $key ] = array( 'url' => $url, 'lastmod' => $lastmod );
				}
			}
		}
	}
	/* Hubs are appended after articles, newest first, and never duplicated. */
	uasort( $hub_lastmods, static function ( $left, $right ) {
		return strtotime( (string) $right['lastmod'] ) <=> strtotime( (string) $left['lastmod'] );
	} );
	foreach ( $hub_lastmods as $key => $hub ) {
		if ( isset( $seen_urls[ $key ] ) ) { continue; }
		$seen_urls[ $key ] = true;
		go_verge_smart_sitemap_append_url( $lines, $hub['url'], $hub['lastmod'] );
	}
	$lines[]='</urlset>';return implode("\n",$lines)."\n";
}

function go_verge_smart_sitemap_build_posts_page( $page = 1 ) {
	$page = max( 1, absint( $page ) );
	$q = new WP_Query( array( 'post_type'=>'post','post_status'=>'publish','posts_per_page'=>GO_VERGE_SMART_SITEMAP_POSTS_PER_FILE,'paged'=>$page,'orderby'=>'date','order'=>'DESC','ignore_sticky_posts'=>true,'no_found_rows'=>true,'has_password'=>false,'update_post_meta_cache'=>true,'update_post_term_cache'=>false ) );
	$lines = go_verge_smart_sitemap_urlset_open();
	foreach ( $q->posts as $post ) { $id=(int)$post->ID; if ( go_verge_smart_sitemap_post_eligible( $id ) ) { go_verge_smart_sitemap_append_url( $lines, get_permalink( $id ), go_verge_smart_sitemap_post_lastmod( $id ), go_verge_smart_sitemap_featured_image( $id ) ); } }
	wp_reset_postdata(); $lines[]='</urlset>'; return implode( "\n", $lines ) . "\n";
}
function go_verge_smart_sitemap_build_post_month( $ym ) {
	list( $year, $month ) = array_map( 'intval', explode( '-', $ym ) );
	$q = new WP_Query( array( 'post_type'=>'post','post_status'=>'publish','posts_per_page'=>10000,'orderby'=>'date','order'=>'DESC','ignore_sticky_posts'=>true,'no_found_rows'=>true,'has_password'=>false,'date_query'=>array(array('year'=>$year,'monthnum'=>$month,'column'=>'post_date')),'update_post_meta_cache'=>true,'update_post_term_cache'=>false ) );
	$lines=go_verge_smart_sitemap_urlset_open();
	foreach($q->posts as $post){$id=(int)$post->ID;if(go_verge_smart_sitemap_post_eligible($id)){go_verge_smart_sitemap_append_url($lines,get_permalink($id),go_verge_smart_sitemap_post_lastmod($id),go_verge_smart_sitemap_featured_image($id));}}
	wp_reset_postdata();$lines[]='</urlset>';return implode("\n",$lines)."\n";
}
function go_verge_smart_sitemap_build_post_type( $post_type ) {
	$q = new WP_Query( array( 'post_type'=>$post_type,'post_status'=>'publish','posts_per_page'=>5000,'orderby'=>'modified','order'=>'DESC','no_found_rows'=>true,'has_password'=>false,'update_post_meta_cache'=>true,'update_post_term_cache'=>false ) );
	$lines = go_verge_smart_sitemap_urlset_open();
	/* The newsroom is appended below with its own clock; a Page stored at the same
	 * address must not add a second, staler <url> for /noticias/. */
	$newsroom = 'page' === $post_type && function_exists( 'go_verge_newsroom_url' ) ? untrailingslashit( go_verge_newsroom_url() ) : '';
	foreach ( $q->posts as $post ) {
		$id = (int) $post->ID;
		if ( $newsroom && untrailingslashit( (string) get_permalink( $id ) ) === $newsroom ) { continue; }
		if ( go_verge_smart_sitemap_post_eligible( $id ) ) {
			go_verge_smart_sitemap_append_url( $lines, get_permalink( $id ), go_verge_smart_sitemap_post_lastmod( $id ), go_verge_smart_sitemap_featured_image( $id ) );
		}
	}
	wp_reset_postdata();

	/* /noticias/ is virtual rather than a WordPress Page, but it is a permanent
	 * editorial hub and should be discoverable in the canonical sitemap too. */
	if ( 'page' === $post_type && function_exists( 'go_verge_newsroom_url' ) ) {
		$news_ids = function_exists( 'go_verge_news_authority_story_ids' ) ? go_verge_news_authority_story_ids() : array();
		$lastmod  = ! empty( $news_ids[0] ) ? go_verge_smart_sitemap_post_lastmod( (int) $news_ids[0] ) : '';
		go_verge_smart_sitemap_append_url( $lines, go_verge_newsroom_url(), $lastmod );
	}

	$lines[] = '</urlset>';
	return implode( "\n", $lines ) . "\n";
}
/** Author profile sitemap: only public users who have published posts. */
function go_verge_smart_sitemap_author_lastmod( $user_id ) {
	$user_id = absint( $user_id );
	$profile = (string) get_user_meta( $user_id, '_go_author_profile_schema_modified_gmt', true );
	$profile_ts = $profile ? strtotime( $profile . ' UTC' ) : 0;
	$latest = get_posts( array(
		'author'           => $user_id,
		'post_type'        => 'post',
		'post_status'      => 'publish',
		'posts_per_page'   => 1,
		'orderby'          => 'modified',
		'order'            => 'DESC',
		'fields'           => 'ids',
		'no_found_rows'    => true,
		'ignore_sticky_posts' => true,
	) );
	$post_ts = ! empty( $latest[0] ) ? strtotime( go_verge_smart_sitemap_post_lastmod( (int) $latest[0] ) ) : 0;
	$ts = max( $profile_ts ?: 0, $post_ts ?: 0 );
	return $ts ? gmdate( 'c', $ts ) : '';
}
function go_verge_smart_sitemap_build_authors() {
	$users = get_users( array(
		'has_published_posts' => array( 'post' ),
		'fields'              => 'ID',
		'number'              => 5000,
		'orderby'             => 'ID',
		'order'               => 'ASC',
	) );
	$lines = go_verge_smart_sitemap_urlset_open();
	foreach ( array_map( 'absint', (array) $users ) as $user_id ) {
		if ( ! $user_id ) { continue; }
		$url = get_author_posts_url( $user_id );
		if ( ! $url ) { continue; }
		$provider = go_verge_smart_sitemap_seo_provider();
		if ( in_array( $provider, array( 'yoast', 'none' ), true ) ) {
			$yoast = go_verge_smart_sitemap_yoast_url_state( $url );
			if ( ! empty( $yoast['noindex'] ) ) { continue; }
			if ( ! empty( $yoast['canonical'] ) && untrailingslashit( $yoast['canonical'] ) !== untrailingslashit( $url ) ) { continue; }
		}
		if ( in_array( $provider, array( 'rank-math', 'none' ), true ) && go_verge_smart_sitemap_rank_math_author_noindex( $user_id ) ) { continue; }
		go_verge_smart_sitemap_append_url( $lines, $url, go_verge_smart_sitemap_author_lastmod( $user_id ) );
	}
	$lines[] = '</urlset>';
	return implode( "\n", $lines ) . "\n";
}

function go_verge_smart_sitemap_term_eligible( $term ) {
	if ( ! ( $term instanceof WP_Term ) ) { return false; }
	$provider = go_verge_smart_sitemap_seo_provider();
	if ( in_array( $provider, array( 'yoast', 'none' ), true ) && ! go_verge_smart_sitemap_yoast_object_type_indexable( $term->taxonomy, 'taxonomy' ) ) { return false; }

	/* Canonical editorial categories are governed by the newsroom taxonomy
	 * contract, not by stale per-term plugin metadata. Explicit category hubs
	 * stay index/follow even before their first story, so the sitemap must make
	 * the identical decision and keep the crawl graph stable. */
	$is_canonical_desk = false;
	if ( 'category' === $term->taxonomy && 'interno' !== $term->slug ) {
		$is_canonical_desk = function_exists( 'go_verge_category_parity_is_canonical_term' )
			? go_verge_category_parity_is_canonical_term( $term )
			: ( function_exists( 'go_verge_v7_canonical_category_slugs' ) && in_array( $term->slug, go_verge_v7_canonical_category_slugs(), true ) );
	}
	if ( (int) $term->count < 1 && ! $is_canonical_desk ) { return false; }
	if ( ! $is_canonical_desk && go_verge_smart_sitemap_noindex( $term->term_id, 'term' ) ) { return false; }
	$link = get_term_link( $term );
	if ( in_array( $provider, array( 'yoast', 'none' ), true ) && ! is_wp_error( $link ) && $link ) {
		$yoast = go_verge_smart_sitemap_yoast_url_state( $link );
		if ( ! empty( $yoast['canonical'] ) && untrailingslashit( $yoast['canonical'] ) !== untrailingslashit( $link ) ) { return false; }
	}
	/* V7 retires the entire free-form tag surface. Canonical platforms and
	 * services have their own controlled taxonomies and dedicated sitemap files. */
	if ( 'post_tag' === $term->taxonomy ) { return false; }
	if ( 'category' === $term->taxonomy ) {
		/* Editorial desks are a controlled vocabulary. Explicit canonical hubs are
		 * permanent crawl destinations and may appear in the category sitemap before
		 * their first story. Technical, legacy, redirected and ad-hoc empty terms
		 * remain excluded below. */
		if ( 'interno' === $term->slug ) { return false; }
		if ( function_exists( 'go_verge_category_parity_is_editorial_term' ) ) {
			if ( ! go_verge_category_parity_is_editorial_term( $term ) ) { return false; }
		} elseif ( function_exists( 'go_verge_v7_canonical_category_slugs' ) && ! in_array( $term->slug, go_verge_v7_canonical_category_slugs(), true ) ) {
			return false;
		}
		if ( function_exists('go_verge_search_redirected_category_slugs') && in_array($term->slug,go_verge_search_redirected_category_slugs(),true) ) { return false; }
	}
	if ( ! in_array( $term->taxonomy, array( 'category','go_platform','go_service' ), true ) ) { return false; }
	if ( function_exists( 'go_verge_rank_math_redirect_target' ) && ! is_wp_error( $link ) && $link && '' !== go_verge_rank_math_redirect_target( (string) $link ) ) { return false; }
	return true;
}
function go_verge_smart_sitemap_term_lastmod_map( $taxonomy ) {
	global $wpdb;$sql=$wpdb->prepare("SELECT tt.term_id, MAX(p.post_modified_gmt) AS modified_gmt FROM {$wpdb->term_taxonomy} tt INNER JOIN {$wpdb->term_relationships} tr ON tr.term_taxonomy_id=tt.term_taxonomy_id INNER JOIN {$wpdb->posts} p ON p.ID=tr.object_id WHERE tt.taxonomy=%s AND p.post_type IN ('post','games','productions','go_entity') AND p.post_status='publish' AND p.post_password='' GROUP BY tt.term_id",$taxonomy); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$rows=$wpdb->get_results($sql,ARRAY_A);$map=array();foreach((array)$rows as $row){$id=absint($row['term_id']??0);$raw=(string)($row['modified_gmt']??'');if($id&&$raw&&'0000-00-00 00:00:00'!==$raw){$map[$id]=gmdate('c',strtotime($raw.' UTC'));}}return $map;
}
function go_verge_smart_sitemap_build_terms( $taxonomy ) {
	$terms=get_terms(array('taxonomy'=>$taxonomy,'hide_empty'=>'category'===$taxonomy?false:true,'number'=>5000,'orderby'=>'count','order'=>'DESC'));$lines=go_verge_smart_sitemap_urlset_open();$lastmods=go_verge_smart_sitemap_term_lastmod_map($taxonomy);$seen=array();if(!is_wp_error($terms)){foreach($terms as $term){if(!go_verge_smart_sitemap_term_eligible($term)){continue;}$url=get_term_link($term);if(is_wp_error($url)||!$url){continue;}$key=strtolower(untrailingslashit((string)$url));if(isset($seen[$key])){continue;}$seen[$key]=true;go_verge_smart_sitemap_append_url($lines,$url,(string)($lastmods[(int)$term->term_id]??''));}}
	/* 3.85.11: Dicas e Guias is a canonical Games child desk and must never
	 * disappear from the category sitemap because of stale term/plugin state. */
	if ( 'category' === $taxonomy ) {
		$guide = get_term_by( 'slug', 'dicas-e-guias', 'category' );
		$url   = home_url( '/games/dicas-e-guias/' );
		if ( $guide instanceof WP_Term ) {
			$resolved = get_term_link( $guide );
			if ( ! is_wp_error( $resolved ) && $resolved ) { $url = $resolved; }
		}
		$key = strtolower( untrailingslashit( (string) $url ) );
		if ( ! isset( $seen[ $key ] ) ) {
			$lastmod = $guide instanceof WP_Term ? (string) ( $lastmods[ (int) $guide->term_id ] ?? '' ) : '';
			go_verge_smart_sitemap_append_url( $lines, $url, $lastmod );
		}
	}
	$lines[]='</urlset>';return implode("\n",$lines)."\n";
}

/** Raw request route. No rewrite rule is required. */
function go_verge_smart_sitemap_route() {
	$path = (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH );
	$path = '/' . ltrim( $path, '/' );

	/* Canonical index plus compatibility aliases that may still be submitted in
	 * Search Console or referenced by a physical robots.txt from an older build.
	 * Returning real XML 200 here is intentionally more robust than a 301: URL
	 * Inspection can then associate article URLs with the already-submitted
	 * sitemap while robots.txt continues advertising only /sitemap.xml. */
	if ( in_array( $path, array( '/sitemap.xml', '/sitemap_index.xml', '/wp-sitemap.xml' ), true ) ) {
		return array( 'kind' => 'index', 'key' => 'index' );
	}
	if ( '/sitemap-fresh.xml' === $path ) { return array( 'kind' => 'fresh', 'key' => 'fresh' ); }
	if ( '/sitemap-posts.xml' === $path ) { return array( 'kind' => 'posts-page', 'key' => 'posts', 'page' => 1 ); }
	if ( '/sitemap-authors.xml' === $path ) { return array( 'kind' => 'authors', 'key' => 'authors' ); }
	if ( '/sitemap-tags.xml' === $path ) { return array( 'kind' => 'retired', 'key' => 'tags' ); }

	if ( preg_match( '#^/sitemap-posts-(\d+)\.xml$#', $path, $m ) ) {
		return array( 'kind' => 'posts-page', 'key' => 'posts-' . $m[1], 'page' => max( 1, (int) $m[1] ) );
	}
	if ( preg_match( '#^/sitemap-posts-(\d{4})-(\d{2})\.xml$#', $path, $m ) ) {
		$month = (int) $m[2];
		if ( $month >= 1 && $month <= 12 ) {
			return array( 'kind' => 'posts-month', 'key' => 'posts-' . $m[1] . '-' . $m[2], 'ym' => $m[1] . '-' . $m[2] );
		}
	}

	/* Yoast/Rank Math/Core compatibility aliases. They are not advertised by the
	 * canonical index, but answering them as the corresponding XML surface keeps
	 * historical GSC submissions valid after the publisher switched providers. */
	if ( preg_match( '#^/post-sitemap(\d+)?\.xml$#i', $path, $m ) ) {
		$page = ! empty( $m[1] ) ? max( 1, (int) $m[1] ) : 1;
		return array( 'kind' => 'posts-page', 'key' => 'legacy-posts-' . $page, 'page' => $page );
	}
	$legacy_map = array(
		'/page-sitemap.xml'        => array( 'type', 'legacy-pages', 'page' ),
		'/games-sitemap.xml'       => array( 'type', 'legacy-games', 'games' ),
		'/productions-sitemap.xml' => array( 'type', 'legacy-productions', 'productions' ),
		'/go_entity-sitemap.xml'   => array( 'type', 'legacy-entities', 'go_entity' ),
		'/category-sitemap.xml'    => array( 'terms', 'legacy-categories', 'category' ),
		'/go_platform-sitemap.xml' => array( 'terms', 'legacy-platforms', 'go_platform' ),
		'/go_service-sitemap.xml'  => array( 'terms', 'legacy-services', 'go_service' ),
	);
	if ( isset( $legacy_map[ $path ] ) ) {
		return array( 'kind' => $legacy_map[ $path ][0], 'key' => $legacy_map[ $path ][1], 'object' => $legacy_map[ $path ][2] );
	}
	if ( '/author-sitemap.xml' === $path ) { return array( 'kind' => 'authors', 'key' => 'legacy-authors' ); }
	if ( in_array( $path, array( '/post_tag-sitemap.xml', '/attachment-sitemap.xml' ), true ) ) {
		return array( 'kind' => 'retired', 'key' => 'legacy-retired' );
	}

	$map = array(
		'/sitemap-pages.xml'       => array( 'type', 'pages', 'page' ),
		'/sitemap-games.xml'       => array( 'type', 'games', 'games' ),
		'/sitemap-productions.xml' => array( 'type', 'productions', 'productions' ),
		'/sitemap-entities.xml'    => array( 'type', 'entities', 'go_entity' ),
		'/sitemap-categories.xml'  => array( 'terms', 'categories', 'category' ),
		'/sitemap-platforms.xml'   => array( 'terms', 'platforms', 'go_platform' ),
		'/sitemap-services.xml'    => array( 'terms', 'services', 'go_service' ),
	);
	return isset( $map[ $path ] ) ? array( 'kind' => $map[ $path ][0], 'key' => $map[ $path ][1], 'object' => $map[ $path ][2] ) : array();
}
function go_verge_smart_sitemap_build_route( $route ) {
	if('index'===$route['kind']){return go_verge_smart_sitemap_build_index();}
	if('retired'===$route['kind']){return '';}
	if('fresh'===$route['kind']){return go_verge_smart_sitemap_build_fresh();}
	if('posts-page'===$route['kind']){return go_verge_smart_sitemap_build_posts_page($route['page']);}
	if('posts-month'===$route['kind']){return go_verge_smart_sitemap_build_post_month($route['ym']);}
	if('authors'===$route['kind']){return go_verge_smart_sitemap_build_authors();}
	if('type'===$route['kind']){return go_verge_smart_sitemap_build_post_type($route['object']);}
	if('terms'===$route['kind']){return go_verge_smart_sitemap_build_terms($route['object']);}
	return '';
}
function go_verge_smart_sitemap_route_lastmod( $route ) {
	if('fresh'===$route['kind']){return max(go_verge_smart_sitemap_type_lastmod('post'),absint(go_verge_smart_sitemap_touch_map()['fresh']??0));}
	if('posts-page'===$route['kind']){return go_verge_smart_sitemap_type_lastmod('post');}
	if('posts-month'===$route['kind']){foreach(go_verge_smart_sitemap_post_months() as $row){if((string)($row['ym']??'')===$route['ym']){return go_verge_smart_sitemap_month_lastmod($route['ym'],(string)($row['modified_gmt']??''));}}}
	if('authors'===$route['kind']){return max(go_verge_smart_sitemap_type_lastmod('post'),go_verge_smart_sitemap_authors_lastmod());}
	if('type'===$route['kind']){return go_verge_smart_sitemap_type_lastmod($route['object']);}
	if('terms'===$route['kind']){return go_verge_smart_sitemap_term_lastmod($route['object']);}
	return absint(get_option('go_smart_sitemap_last_change',0));
}
function go_verge_smart_sitemap_mark_nocache() {
	if ( function_exists( 'do_action' ) ) { do_action( 'litespeed_control_set_nocache', 'Overdrive XML sitemap' ); }
}
/** Pure RFC 9110 conditional-request decision for regression coverage. */
function go_verge_smart_sitemap_is_not_modified( $etag, $last_modified, $if_none_match, $if_modified_since ) {
	$if_none_match = trim( (string) $if_none_match );
	if ( '' !== $if_none_match ) {
		$server_etag = preg_replace( '/^W\//i', '', trim( (string) $etag ) );
		foreach ( array_map( 'trim', explode( ',', $if_none_match ) ) as $candidate ) {
			$candidate = preg_replace( '/^W\//i', '', $candidate );
			if ( '*' === $candidate || $server_etag === $candidate ) { return true; }
		}
		return false;
	}
	$since = is_numeric( $if_modified_since ) ? (int) $if_modified_since : strtotime( (string) $if_modified_since );
	return (int) $last_modified > 0 && $since > 0 && $since >= (int) $last_modified;
}
function go_verge_smart_sitemap_send_xml( $xml, $route ) {
	go_verge_smart_sitemap_mark_nocache();
	$etag='"go-sm-'.md5($xml).'"';
	/* Fresh membership also changes when a story ages out, with no editorial
	 * save. That route has no reliable modification clock; its body ETag remains
	 * authoritative. Never send an IMS-only 304 based on the last post save. */
	$last = 'fresh' === $route['kind'] ? 0 : go_verge_smart_sitemap_route_lastmod( $route );
	$if_none=isset($_SERVER['HTTP_IF_NONE_MATCH'])?trim((string)wp_unslash($_SERVER['HTTP_IF_NONE_MATCH'])):'';$if_mod=isset($_SERVER['HTTP_IF_MODIFIED_SINCE'])?strtotime((string)wp_unslash($_SERVER['HTTP_IF_MODIFIED_SINCE'])):0;
	/* RFC conditional precedence: If-Modified-Since is ignored whenever the
	 * request also carries If-None-Match, even when that ETag does not match. */
	if(go_verge_smart_sitemap_is_not_modified($etag,$last,$if_none,$if_mod)){status_header(304);header('ETag: '.$etag,true);if($last>0){header('Last-Modified: '.gmdate('D, d M Y H:i:s',$last).' GMT',true);}header('Cache-Control: no-cache, must-revalidate, max-age=0',true);header('X-LiteSpeed-Cache-Control: no-cache',true);exit;}
	status_header(200);header('Content-Type: application/xml; charset=UTF-8',true);header('X-Robots-Tag: noindex, follow',true);header('Cache-Control: no-cache, must-revalidate, max-age=0',true);header('Pragma: no-cache',true);header('X-LiteSpeed-Cache-Control: no-cache',true);header('ETag: '.$etag,true);if($last>0){header('Last-Modified: '.gmdate('D, d M Y H:i:s',$last).' GMT',true);}echo $xml; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	exit;
}
function go_verge_smart_sitemap_render_route( $route ) {
	if('retired'===$route['kind']){go_verge_smart_sitemap_mark_nocache();status_header(410);header('Content-Type: text/plain; charset=UTF-8',true);header('X-Robots-Tag: noindex, nofollow',true);header('Cache-Control: public, max-age=86400',true);echo "Gone: legacy tag sitemap retired; use /sitemap.xml\n";exit;}
	if('posts-page'===$route['kind']&&(int)$route['page']>go_verge_smart_sitemap_post_shards()){status_header(404);header('X-Robots-Tag: noindex, nofollow',true);exit;}
	$epoch=go_verge_smart_sitemap_epoch();$key='go_sm_xml_'.md5($epoch.'|'.wp_json_encode($route));$xml=get_transient($key);
	if(!is_string($xml)||''===$xml){$xml=go_verge_smart_sitemap_build_route($route);if(''===$xml){status_header(404);exit;}set_transient($key,$xml,'index'===$route['kind']?5*MINUTE_IN_SECONDS:HOUR_IN_SECONDS);}
	go_verge_smart_sitemap_send_xml($xml,$route);
}

/**
 * Strong route: after every plugin/theme registered content, before the main
 * WordPress query. This bypasses 404/canonical/Rank Math and needs no rewrite.
 */
function go_verge_smart_sitemap_early_router() {
	if ( is_admin() || wp_doing_ajax() ) { return; }
	$route = go_verge_smart_sitemap_route();
	if ( empty( $route ) ) { return; }
	go_verge_smart_sitemap_render_route( $route );
}
add_action('wp_loaded','go_verge_smart_sitemap_early_router',-1000);

/** template_redirect is only a second fail-safe for unusual stacks. */
function go_verge_smart_sitemap_render(){if(is_admin()||wp_doing_ajax()){return;}$route=go_verge_smart_sitemap_route();if(!empty($route)){go_verge_smart_sitemap_render_route($route);}}
add_action('template_redirect','go_verge_smart_sitemap_render',-2000);
function go_verge_smart_sitemap_disable_canonical($redirect){return go_verge_smart_sitemap_route()?false:$redirect;}
add_filter('redirect_canonical','go_verge_smart_sitemap_disable_canonical',5);

/** Cache optimization exclude is supplemental; actual page-cache bypass is the API action above. */
function go_verge_smart_sitemap_litespeed_excludes($list){$list=is_array($list)?$list:array();foreach(array('^/sitemap.xml$','^/sitemap-','^/news-sitemap.xml$') as $v){$list[]=$v;}return array_values(array_unique($list));}
add_filter('litespeed_optm_uri_exc','go_verge_smart_sitemap_litespeed_excludes',100);

function go_verge_smart_sitemap_admin_menu(){add_management_page(__('Sitemap Intelligence','go-verge'),__('Sitemap Intelligence','go-verge'),'manage_options','go-sitemap-intelligence','go_verge_smart_sitemap_admin_page');}
add_action('admin_menu','go_verge_smart_sitemap_admin_menu',50);
function go_verge_smart_sitemap_admin_actions(){
	if(!is_admin()||!current_user_can('manage_options')||empty($_POST['go_sitemap_regenerate'])){return;}check_admin_referer('go_sitemap_regenerate');update_option(GO_VERGE_SMART_SITEMAP_EPOCH_OPTION,go_verge_smart_sitemap_epoch()+1,false);update_option('go_smart_sitemap_last_change',time(),false);do_action('litespeed_purge_all');wp_safe_redirect(add_query_arg(array('page'=>'go-sitemap-intelligence','regenerated'=>'1'),admin_url('tools.php')));exit;
}
add_action('admin_init','go_verge_smart_sitemap_admin_actions',5);
function go_verge_preferred_source_admin_actions(){
	if(!is_admin()||!current_user_can('manage_options')||empty($_POST['go_preferred_source_save'])){return;}
	check_admin_referer('go_preferred_source_save');
	update_option(GO_VERGE_PREFERRED_SOURCE_OPTION,!empty($_POST['go_preferred_source_enabled'])?1:0,false);
	wp_safe_redirect(add_query_arg(array('page'=>'go-sitemap-intelligence','preferred_saved'=>'1'),admin_url('tools.php')));exit;
}
add_action('admin_init','go_verge_preferred_source_admin_actions',6);
function go_verge_smart_sitemap_reason_label( $reason ) {
	$labels = array(
		'post-not-found'            => 'Post não encontrado',
		'not-published'             => 'Não publicado',
		'password-protected'        => 'Protegido por senha',
		'unsupported-post-type'     => 'Tipo não suportado',
		'post-type-noindex'         => 'Tipo definido como noindex',
		'robots-noindex'            => 'Robots noindex',
		'seo-redirect'              => 'Redirect do provedor SEO',
		'utility-or-redirected-page'=> 'Página utilitária/redirecionada',
		'retired-hub'               => 'Hub aposentado',
		'retired-promotions-page'   => 'Página de promoções consolidada na categoria',
		'redirected-path'           => 'Caminho redirecionado',
		'entity-shadow'             => 'Entidade duplicada/sombra',
		'entity-redirect'           => 'Entidade redirecionada',
		'game-awaiting-review'      => 'Game importado aguardando revisão',
		'missing-permalink'         => 'Sem permalink público',
		'custom-canonical'          => 'Canonical aponta para outra URL',
		'rank-math-redirect'        => 'Redirecionada pelo Rank Math (301)',
	);
	return isset( $labels[ $reason ] ) ? $labels[ $reason ] : (string) $reason;
}

/** Recent published stories that the local sitemap contract would exclude. */
function go_verge_smart_sitemap_recent_exclusions( $limit = 80 ) {
	$ids = get_posts( array(
		'post_type'              => 'post',
		'post_status'            => 'publish',
		'posts_per_page'         => max( 10, min( 200, absint( $limit ) ) ),
		'orderby'                => 'date',
		'order'                  => 'DESC',
		'fields'                 => 'ids',
		'no_found_rows'          => true,
		'update_post_meta_cache' => true,
		'update_post_term_cache' => false,
	) );
	$out = array();
	foreach ( (array) $ids as $post_id ) {
		$reason = go_verge_smart_sitemap_post_exclusion_reason( $post_id );
		if ( '' === $reason ) { continue; }
		$out[] = array( 'id' => absint( $post_id ), 'reason' => $reason );
	}
	return $out;
}

function go_verge_smart_sitemap_admin_page(){
	$children=go_verge_smart_sitemap_index_children();$last=absint(get_option('go_smart_sitemap_last_change',0));$preferred=(bool)get_option(GO_VERGE_PREFERRED_SOURCE_OPTION,false);$provider=go_verge_smart_sitemap_seo_provider();$recent_exclusions=go_verge_smart_sitemap_recent_exclusions(80);$gsc_connected=class_exists('GED_Search_Console')&&method_exists('GED_Search_Console','connected')&&GED_Search_Console::connected();$google_push=get_option('ged_gsc_sitemap_push_status',array());$google_request=get_option('go_verge_google_fast_push_last_request',array());
	?><div class="wrap"><h1><?php esc_html_e('Sitemap Intelligence','go-verge');?></h1>
	<p><?php esc_html_e('Índice editorial canônico + Fresh de 7 dias + News de 48h, servido diretamente pelo tema e independente de Rank Math, rewrite rules e page cache.','go-verge');?></p>
	<?php if(!empty($_GET['regenerated'])):?><div class="notice notice-success"><p><?php esc_html_e('Sitemap regenerado e cache do LiteSpeed invalidado.','go-verge');?></p></div><?php endif;?>
	<?php if(!empty($_GET['preferred_saved'])):?><div class="notice notice-success"><p><?php esc_html_e('Preferência de Fontes preferidas salva.','go-verge');?></p></div><?php endif;?>
	<table class="widefat striped" style="max-width:980px"><thead><tr><th>Arquivo</th><th>Função</th><th>Última mudança</th></tr></thead><tbody><tr><td><a href="<?php echo esc_url(go_verge_smart_sitemap_url());?>" target="_blank" rel="noopener">/sitemap.xml</a></td><td>Índice principal</td><td><?php echo $last?esc_html(wp_date('d/m/Y H:i:s',$last)):'—';?></td></tr><?php foreach($children as $child):?><tr><td><a href="<?php echo esc_url($child[1]);?>" target="_blank" rel="noopener"><?php echo esc_html((string)wp_parse_url($child[1],PHP_URL_PATH));?></a></td><td><?php echo esc_html(ucfirst(str_replace('-',' ',$child[0])));?></td><td><?php echo !empty($child[2])?esc_html(wp_date('d/m/Y H:i:s',(int)$child[2])):'—';?></td></tr><?php endforeach;?></tbody></table>
	<p><strong>Posts publicados:</strong> <?php echo esc_html(number_format_i18n(go_verge_smart_sitemap_post_count()));?> · <strong>Shards ativos:</strong> <?php echo esc_html(number_format_i18n(go_verge_smart_sitemap_post_shards()));?></p>
	<form method="post" style="margin:16px 0 24px"><?php wp_nonce_field('go_sitemap_regenerate');?><button class="button button-primary" name="go_sitemap_regenerate" value="1">Regenerar sitemap e limpar cache</button></form>
	<h2>Diagnóstico de cobertura local</h2>
	<p style="max-width:980px">Provedor SEO ativo: <strong><?php echo esc_html( $provider ); ?></strong>. A verificação abaixo usa a mesma função que gera <code>/sitemap-posts.xml</code> e <code>/news-sitemap.xml</code>; portanto, não confunde “sem impressões no Search” com “fora do sitemap”. Metadados antigos do Yoast são ignorados quando Rank Math está ativo.</p>
	<?php if ( empty( $recent_exclusions ) ) : ?>
		<div class="notice notice-success inline" style="max-width:940px"><p><strong>80 posts recentes publicados:</strong> todos estão elegíveis para o sitemap local.</p></div>
	<?php else : ?>
		<div class="notice notice-warning inline" style="max-width:940px"><p><strong><?php echo esc_html( number_format_i18n( count( $recent_exclusions ) ) ); ?> post(s) recente(s) fora do sitemap.</strong> Corrija apenas os itens abaixo; ausência de posição no Search, sozinha, não é falha de sitemap.</p></div>
		<table class="widefat striped" style="max-width:980px"><thead><tr><th>ID</th><th>Matéria</th><th>Motivo local</th></tr></thead><tbody>
		<?php foreach ( $recent_exclusions as $item ) : $edit = get_edit_post_link( $item['id'] ); ?>
		<tr><td><?php echo esc_html( (string) $item['id'] ); ?></td><td><?php if ( $edit ) : ?><a href="<?php echo esc_url( $edit ); ?>"><?php echo esc_html( get_the_title( $item['id'] ) ); ?></a><?php else : echo esc_html( get_the_title( $item['id'] ) ); endif; ?></td><td><?php echo esc_html( go_verge_smart_sitemap_reason_label( $item['reason'] ) ); ?></td></tr>
		<?php endforeach; ?>
		</tbody></table>
	<?php endif; ?>
	<?php if ( function_exists( 'go_verge_indexing_integrity_render' ) ) { go_verge_indexing_integrity_render(); } ?>
	<hr style="max-width:980px;margin:22px 0"><h2>Envio rápido ao Google</h2>
	<p style="max-width:980px">Ao publicar ou fazer uma alteração editorial relevante, o Overdrive atualiza <code>/sitemap-fresh.xml</code>, RSS, News sitemap e o índice principal, dispara WebSub e acorda imediatamente o conector autenticado do Search Console. Isso reduz o tempo de descoberta/rastreamento, sem usar a Indexing API restrita a tipos de página que não correspondem a matérias comuns.</p>
	<?php if ( $gsc_connected ) : ?>
		<?php $push_errors = is_array($google_push) && isset($google_push['errors']) && is_array($google_push['errors']) ? $google_push['errors'] : array(); ?>
		<?php if ( ! empty( $google_push['time'] ) && empty( $push_errors ) ) : ?>
			<div class="notice notice-success inline" style="max-width:940px"><p><strong>Google conectado e push automático operacional.</strong> Último envio: <?php echo esc_html(wp_date('d/m/Y H:i:s',absint($google_push['time']))); ?> · <?php echo esc_html(number_format_i18n(count((array)($google_push['submitted']??array())))); ?> superfície(s) aceita(s) pela API do Search Console<?php if(!empty($google_push['post_id'])): ?> · post #<?php echo esc_html((string)absint($google_push['post_id'])); ?><?php endif; ?>.</p></div>
		<?php elseif ( ! empty( $google_push['time'] ) ) : ?>
			<div class="notice notice-warning inline" style="max-width:940px"><p><strong>O último push ao Google teve erro.</strong> <?php echo esc_html(number_format_i18n(count($push_errors))); ?> falha(s).<?php if(!empty($google_push['next_retry'])): ?> Retry: <?php echo esc_html(wp_date('d/m/Y H:i:s',absint($google_push['next_retry']))); ?>.<?php endif; ?></p></div>
		<?php else : ?>
			<div class="notice notice-info inline" style="max-width:940px"><p><strong>Search Console conectado.</strong> O primeiro push rápido será registrado na próxima publicação ou atualização relevante.<?php if(!empty($google_request['time'])): ?> O worker foi acordado pela última vez em <?php echo esc_html(wp_date('d/m/Y H:i:s',absint($google_request['time']))); ?>.<?php endif; ?></p></div>
		<?php endif; ?>
	<?php else : ?>
		<div class="notice notice-warning inline" style="max-width:940px"><p><strong>Envio autenticado ainda não está ativo.</strong> Conecte o Search Console no Lume em <a href="<?php echo esc_url(admin_url('admin.php?page=go-editorial-desk-settings#ged-intelligence-settings')); ?>">Dados e IA</a>. WebSub e sitemaps locais continuam funcionando sem essa conexão.</p></div>
	<?php endif; ?>
	<p style="max-width:980px"><strong>Importante:</strong> o aceite do sitemap pela API acelera a sinalização ao Google, mas não é garantia de indexação. O conteúdo ainda precisa passar pelas decisões normais de rastreamento, canonicalização e qualidade do Google.</p>
	<hr style="max-width:980px;margin:22px 0"><h2>Google Notícias e Fontes preferidas</h2>
	<p style="max-width:900px">O Google Notícias considera publicações elegíveis automaticamente; não existe mais cadastro manual de feed no Publisher Center. O News sitemap acelera descoberta das últimas 48h. O botão oficial de <strong>Fontes preferidas</strong> permite que leitores escolham o Overdrive como fonte preferida no Google.</p>
	<form method="post" style="margin:12px 0"><?php wp_nonce_field('go_preferred_source_save');?><label><input type="checkbox" name="go_preferred_source_enabled" value="1" <?php checked($preferred);?>> Inserir automaticamente o botão oficial “Adicionar às Fontes preferidas” ao final das matérias</label> <button class="button" name="go_preferred_source_save" value="1">Salvar</button></form>
	<p><a class="button" href="<?php echo esc_url(go_verge_preferred_source_deeplink());?>" target="_blank" rel="noopener">Testar Overdrive em Fontes preferidas</a> <code>[go_preferred_source]</code> para inserção manual.</p>
	<p><strong>Search Console:</strong> para cadastro manual inicial, <code>/sitemap.xml</code> continua suficiente. Com o Lume conectado, o fluxo automático prioriza <code>/sitemap-fresh.xml</code> + RSS, depois <code>/news-sitemap.xml</code> e o índice principal. Discover não usa sitemap próprio: depende da URL indexada, conteúdo people-first e imagem grande.</p></div><?php
}
function go_verge_smart_sitemap_health($tests){
	$tests['async']['go_verge_smart_sitemap']=array(
		'label'=>__('Sitemap editorial independente','go-verge'),
		'test'=>'go_verge_observatory_sitemap_health_test',
		'has_rest'=>false,
		'async_direct_test'=>'go_verge_observatory_sitemap_health_test',
	);
	return $tests;
}
add_filter('site_status_tests','go_verge_smart_sitemap_health');
