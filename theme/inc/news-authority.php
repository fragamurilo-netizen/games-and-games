<?php
/**
 * Google News + publisher authority architecture.
 *
 * Creates a permanent newsroom surface, keeps the news feed semantically tied
 * to the Article subtype selected by the editor, and reinforces a single
 * publisher identity without fabricating eligibility or ranking claims.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Cache namespace for the curated newsroom membership. */
const GO_VERGE_NEWSROOM_CACHE_KEY = 'go_verge_newsroom_ids_v1';

/** One pagination contract shared by validation, template and schema. */
function go_verge_news_authority_per_page() {
	return 20;
}

/** Tiny presentation layer for the newsroom and the visible article dateline. */
function go_verge_news_authority_assets() {
	if ( ! go_verge_news_authority_is_newsroom() && ! is_singular( 'post' ) ) {
		return;
	}
	$rel = '/assets/css/news-authority.css';
	if ( is_readable( GO_VERGE_DIR . $rel ) ) {
		wp_enqueue_style( 'go-verge-news-authority', GO_VERGE_URI . $rel, array( 'go-verge' ), function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $rel ) : GO_VERGE_VERSION );
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_news_authority_assets', 40 );

/** Canonical newsroom URL. */
function go_verge_newsroom_url( $page = 1 ) {
	$page = max( 1, absint( $page ) );
	if ( $page > 1 ) {
		return home_url( '/noticias/page/' . $page . '/' );
	}
	return home_url( '/noticias/' );
}

/** Whether the current request is the virtual newsroom. */
function go_verge_news_authority_is_newsroom() {
	return (bool) get_query_var( 'go_newsroom' );
}

/** Permanent, crawlable newsroom endpoint and pagination. */
function go_verge_news_authority_rewrite() {
	add_rewrite_rule( '^noticias/?$', 'index.php?go_newsroom=1', 'top' );
	add_rewrite_rule( '^noticias/page/([0-9]{1,})/?$', 'index.php?go_newsroom=1&paged=$matches[1]', 'top' );
}
add_action( 'init', 'go_verge_news_authority_rewrite', 11 );

function go_verge_news_authority_query_vars( $vars ) {
	$vars[] = 'go_newsroom';
	return $vars;
}
add_filter( 'query_vars', 'go_verge_news_authority_query_vars' );

/**
 * Raw-request fallback. A theme uploaded over the active copy may receive a
 * front-end request before WordPress has persisted the new rewrite rules. This
 * keeps /noticias/ crawlable immediately; the normal rewrite flush still runs
 * in wp-admin and remains the permanent route.
 */
function go_verge_news_authority_request_fallback( $vars ) {
	$path = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_parse_url( wp_unslash( $_SERVER['REQUEST_URI'] ), PHP_URL_PATH ) : '';
	$home_path = (string) wp_parse_url( home_url( '/' ), PHP_URL_PATH );
	$home_path = '/' . trim( $home_path, '/' );
	if ( '/' === $home_path ) {
		$home_path = '';
	}
	if ( $home_path && 0 === strpos( $path, $home_path . '/' ) ) {
		$path = substr( $path, strlen( $home_path ) );
	}
	$path = trim( $path, '/' );
	if ( 'noticias' === $path ) {
		$vars['go_newsroom'] = 1;
		return $vars;
	}
	if ( preg_match( '#^noticias/page/([1-9][0-9]*)$#', $path, $matches ) ) {
		$vars['go_newsroom'] = 1;
		$vars['paged'] = absint( $matches[1] );
	}
	return $vars;
}
add_filter( 'request', 'go_verge_news_authority_request_fallback', 0 );

/**
 * Flush only once per theme version, even when an active theme is updated in
 * place instead of being switched through Appearance > Themes.
 */
function go_verge_news_authority_maybe_flush_rewrites() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$key = 'go_verge_news_authority_rewrite_version';
	if ( (string) get_option( $key ) === (string) GO_VERGE_VERSION ) {
		return;
	}
	go_verge_news_authority_rewrite();
	if ( function_exists( 'go_verge_flush_rewrite_rules_once_per_request' ) ) {
		go_verge_flush_rewrite_rules_once_per_request();
	} else {
		flush_rewrite_rules( false );
	}
	update_option( $key, GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_news_authority_maybe_flush_rewrites', 30 );

/** Flush immediately when the theme is activated through Appearance > Themes. */
function go_verge_news_authority_after_switch_theme() {
	go_verge_news_authority_rewrite();
	flush_rewrite_rules( false );
	update_option( 'go_verge_news_authority_rewrite_version', GO_VERGE_VERSION, false );
}
add_action( 'after_switch_theme', 'go_verge_news_authority_after_switch_theme' );

/** Make the custom endpoint a real archive request, not a disguised homepage. */
function go_verge_news_authority_main_query( $query ) {
	if ( ! ( $query instanceof WP_Query ) || ! $query->is_main_query() || ! $query->get( 'go_newsroom' ) ) {
		return;
	}
	$query->is_home    = false;
	$query->is_front_page = false;
	$query->is_page    = false;
	$query->is_singular = false;
	$query->is_archive = true;
	$query->is_404     = false;
	/* The template owns the curated list. Keep the otherwise-unused main query
	 * deliberately tiny so the newsroom cannot add a second expensive feed. */
	$query->set( 'post_type', 'post' );
	$query->set( 'posts_per_page', 1 );
	$query->set( 'ignore_sticky_posts', true );
	$query->set( 'no_found_rows', true );
}
add_action( 'pre_get_posts', 'go_verge_news_authority_main_query', 1 );

function go_verge_news_authority_validate_page() {
	if ( ! go_verge_news_authority_is_newsroom() ) {
		return;
	}
	$page = max( 1, absint( get_query_var( 'paged' ) ) );
	$path = trim( (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH ), '/' );

	/* /page/1/, /page/000/ and every zero-padded page are duplicate forms. */
	if ( preg_match( '#(?:^|/)noticias/page/(0+[0-9]+)$#', $path, $page_match ) ) {
		$normalized = max( 1, absint( $page_match[1] ) );
		wp_safe_redirect( go_verge_newsroom_url( $normalized ), 301, 'Overdrive newsroom pagination canonical' );
		exit;
	}
	if ( preg_match( '#(?:^|/)noticias/page/1$#', $path ) ) {
		wp_safe_redirect( go_verge_newsroom_url(), 301, 'Overdrive newsroom page-one canonical' );
		exit;
	}

	$total     = count( go_verge_news_authority_story_ids() );
	$max_pages = max( 1, (int) ceil( $total / go_verge_news_authority_per_page() ) );
	if ( $page > $max_pages ) {
		global $wp_query;
		$GLOBALS['go_verge_newsroom_invalid'] = true;
		if ( $wp_query instanceof WP_Query ) {
			$wp_query->set( 'go_newsroom', 0 );
			$wp_query->is_archive = false;
			$wp_query->set_404();
		}
		status_header( 404 );
		nocache_headers();
		return;
	}
	status_header( 200 );
}
add_action( 'template_redirect', 'go_verge_news_authority_validate_page', -20 );

function go_verge_news_authority_disable_canonical_redirect( $redirect_url ) {
	return ( go_verge_news_authority_is_newsroom() || ! empty( $GLOBALS['go_verge_newsroom_invalid'] ) ) ? false : $redirect_url;
}
add_filter( 'redirect_canonical', 'go_verge_news_authority_disable_canonical_redirect', 5 );

function go_verge_news_authority_template( $template ) {
	if ( ! go_verge_news_authority_is_newsroom() ) {
		return $template;
	}
	$candidate = GO_VERGE_DIR . '/page-template/template-newsroom.php';
	return is_readable( $candidate ) ? $candidate : $template;
}
add_filter( 'template_include', 'go_verge_news_authority_template', 99 );

/** Utility query for IDs only. */
function go_verge_news_authority_query_ids( $args ) {
	$args = wp_parse_args(
		$args,
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => 5000,
			'fields'                 => 'ids',
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'ignore_sticky_posts'    => true,
			'no_found_rows'          => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
			'has_password'           => false,
		)
	);
	return array_map( 'absint', get_posts( $args ) );
}

/**
 * IDs that belong to the permanent newsroom.
 *
 * Membership comes from three explicit editorial signals: V7 content type
 * `noticia`, the editor's NewsArticle override, or a legacy newsroom category.
 * It never marks a post as news merely because it is recent.
 *
 * @return int[]
 */
function go_verge_news_authority_story_ids() {
	$cached = get_transient( GO_VERGE_NEWSROOM_CACHE_KEY );
	if ( is_array( $cached ) ) {
		return array_values( array_filter( array_map( 'absint', $cached ) ) );
	}

	$ids = array();
	if ( taxonomy_exists( 'go_content_type' ) && term_exists( 'noticia', 'go_content_type' ) ) {
		$ids = array_merge(
			$ids,
			go_verge_news_authority_query_ids(
				array(
					'tax_query' => array(
						array(
							'taxonomy' => 'go_content_type',
							'field'    => 'slug',
							'terms'    => array( 'noticia' ),
						),
					),
				)
			)
		);
	}

	$ids = array_merge(
		$ids,
		go_verge_news_authority_query_ids(
			array(
				'meta_query' => array(
					array(
						'key'   => defined( 'GO_VERGE_SCHEMA_TYPE_META' ) ? GO_VERGE_SCHEMA_TYPE_META : '_go_schema_article_type',
						'value' => 'NewsArticle',
					),
				),
			)
		)
	);

	/* Backward compatibility for genuinely old /noticias/ category assignments. */
	$news_category_ids = array();
	$categories = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => false ) );
	if ( ! is_wp_error( $categories ) ) {
		foreach ( $categories as $term ) {
			if ( $term instanceof WP_Term && function_exists( 'go_verge_category_is_news_term' ) && go_verge_category_is_news_term( $term ) ) {
				$news_category_ids[] = (int) $term->term_id;
			}
		}
	}
	if ( $news_category_ids ) {
		$ids = array_merge(
			$ids,
			go_verge_news_authority_query_ids(
				array(
					'category__in' => array_values( array_unique( $news_category_ids ) ),
				)
			)
		);
	}

	$ids = array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
	if ( $ids ) {
		update_meta_cache( 'post', $ids );
		update_object_term_cache( $ids, 'post' );
	}

	/* Final semantic check guarantees that an explicit Article/BlogPosting
	 * override can remove an old category-based story from the newsroom. */
	if ( function_exists( 'go_verge_post_is_news_article' ) ) {
		$ids = array_values(
			array_filter(
				$ids,
				static function ( $post_id ) {
					return go_verge_post_is_news_article( $post_id );
				}
			)
		);
	}

	usort(
		$ids,
		static function ( $a, $b ) {
			$ta = function_exists( 'go_verge_search_published_timestamp' ) ? (int) go_verge_search_published_timestamp( $a ) : (int) get_post_time( 'U', true, $a );
			$tb = function_exists( 'go_verge_search_published_timestamp' ) ? (int) go_verge_search_published_timestamp( $b ) : (int) get_post_time( 'U', true, $b );
			return $tb <=> $ta;
		}
	);

	set_transient( GO_VERGE_NEWSROOM_CACHE_KEY, $ids, 10 * MINUTE_IN_SECONDS );
	return $ids;
}

function go_verge_news_authority_bust_cache() {
	delete_transient( GO_VERGE_NEWSROOM_CACHE_KEY );
}
add_action( 'save_post_post', 'go_verge_news_authority_bust_cache', 100 );
add_action( 'deleted_post', 'go_verge_news_authority_bust_cache', 100 );

/** Bust only when a term change can alter newsroom membership. */
function go_verge_news_authority_terms_changed( $object_id, $terms, $tt_ids, $taxonomy ) {
	if ( 'post' !== get_post_type( absint( $object_id ) ) || ! in_array( (string) $taxonomy, array( 'category', 'go_content_type' ), true ) ) {
		return;
	}
	go_verge_news_authority_bust_cache();
}
add_action( 'set_object_terms', 'go_verge_news_authority_terms_changed', 100, 4 );

/** Bust only when an editor changes the Article subtype that drives membership. */
function go_verge_news_authority_meta_changed( $meta_id, $object_id, $meta_key ) {
	$key = defined( 'GO_VERGE_SCHEMA_TYPE_META' ) ? GO_VERGE_SCHEMA_TYPE_META : '_go_schema_article_type';
	if ( (string) $meta_key !== (string) $key || 'post' !== get_post_type( absint( $object_id ) ) ) {
		return;
	}
	go_verge_news_authority_bust_cache();
}
add_action( 'added_post_meta', 'go_verge_news_authority_meta_changed', 100, 3 );
add_action( 'updated_post_meta', 'go_verge_news_authority_meta_changed', 100, 3 );
add_action( 'deleted_post_meta', 'go_verge_news_authority_meta_changed', 100, 3 );

/** IDs rendered on the current newsroom page. */
function go_verge_news_authority_page_ids( $page = 1, $per_page = 20 ) {
	$page     = max( 1, absint( $page ) );
	$per_page = max( 1, min( 50, absint( $per_page ) ) );
	return array_slice( go_verge_news_authority_story_ids(), ( $page - 1 ) * $per_page, $per_page );
}

/** SEO text shared by native engine and Rank Math. */
function go_verge_newsroom_description() {
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	return sprintf( __( 'Notícias do %s sobre games, entretenimento e tecnologia, com autoria identificada, fontes, correções e atualização editorial.', 'go-verge' ), $site_name );
}

function go_verge_news_authority_document_title( $title ) {
	if ( go_verge_news_authority_is_newsroom() ) {
		$page = max( 1, (int) get_query_var( 'paged' ) );
		$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
		return $page > 1
			? sprintf( __( 'Notícias — página %1$d | %2$s', 'go-verge' ), $page, $site_name )
			: sprintf( __( 'Notícias | %s', 'go-verge' ), $site_name );
	}
	return $title;
}
add_filter( 'pre_get_document_title', 'go_verge_news_authority_document_title', 100 );

function go_verge_news_authority_rank_math_title( $title ) {
	return go_verge_news_authority_is_newsroom() ? go_verge_news_authority_document_title( $title ) : $title;
}
add_filter( 'rank_math/frontend/title', 'go_verge_news_authority_rank_math_title', 2100 );

function go_verge_news_authority_rank_math_description( $description ) {
	return go_verge_news_authority_is_newsroom() ? go_verge_newsroom_description() : $description;
}
add_filter( 'rank_math/frontend/description', 'go_verge_news_authority_rank_math_description', 2100 );

function go_verge_news_authority_rank_math_canonical( $canonical ) {
	return go_verge_news_authority_is_newsroom() ? go_verge_newsroom_url( max( 1, (int) get_query_var( 'paged' ) ) ) : $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_news_authority_rank_math_canonical', 2100 );

function go_verge_news_authority_robots( $robots ) {
	if ( ! go_verge_news_authority_is_newsroom() ) {
		return $robots;
	}
	if ( go_verge_news_authority_is_filtered_view() ) {
		return $robots;
	}
	$robots['index']             = true;
	$robots['follow']            = true;
	$robots['max-image-preview'] = 'large';
	$robots['max-snippet']       = '-1';
	$robots['max-video-preview'] = '-1';
	unset( $robots['noindex'] );
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_news_authority_robots', 200 );

/**
 * A filtered newsroom view is a UI state, not a Search landing page.
 *
 * indexing-intelligence.php marks any ?tema=/?editoria=/?tipo=... variant
 * noindex,follow at priority 300. This newsroom policy runs at 2100 and used to
 * force index back on unconditionally, silently reverting that decision for
 * every filtered /noticias/ URL. The canonical filter beside it already returns
 * the clean newsroom URL, so the two signals disagreed.
 *
 * @return bool True when the current newsroom request carries an editorial filter.
 */
function go_verge_news_authority_is_filtered_view() {
	return function_exists( 'go_verge_indexing_is_filtered_discovery_request' )
		&& go_verge_indexing_is_filtered_discovery_request();
}

/** Match the newsroom policy when Rank Math owns the robots meta tag. */
function go_verge_news_authority_rank_math_robots( $robots ) {
	if ( ! go_verge_news_authority_is_newsroom() || ! is_array( $robots ) ) {
		return $robots;
	}
	if ( go_verge_news_authority_is_filtered_view() ) {
		return $robots;
	}
	$robots['index']             = 'index';
	$robots['follow']            = 'follow';
	$robots['max-image-preview'] = 'max-image-preview:large';
	$robots['max-snippet']       = 'max-snippet:-1';
	$robots['max-video-preview'] = 'max-video-preview:-1';
	unset( $robots['noindex'] );
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_news_authority_rank_math_robots', 2100 );

/** CollectionPage + ItemList for the exact newsroom links visible in HTML. */
function go_verge_news_authority_rank_math_graph( $data ) {
	if ( ! go_verge_news_authority_is_newsroom() || ! is_array( $data ) ) {
		return $data;
	}
	$page = max( 1, (int) get_query_var( 'paged' ) );
	$url  = go_verge_newsroom_url( $page );
	$page_id = $url . '#webpage';
	$list_id = $url . '#itemlist';
	$site_id = trailingslashit( home_url( '/' ) ) . '#website';
	$org_id  = trailingslashit( home_url( '/' ) ) . '#organization';
	$per_page = go_verge_news_authority_per_page();

	$items = array();
	foreach ( go_verge_news_authority_page_ids( $page, $per_page ) as $position => $post_id ) {
		$items[] = array(
			'@type'    => 'ListItem',
			'position' => $position + 1 + ( ( $page - 1 ) * $per_page ),
			'url'      => get_permalink( $post_id ),
			'name'     => wp_strip_all_tags( get_the_title( $post_id ) ),
		);
	}

	$page_key = null;
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) {
			continue;
		}
		if ( go_verge_schema_node_matches_url( $node, $url, array( 'WebPage', 'CollectionPage' ) ) ) {
			$page_key = $key;
			break;
		}
	}
	$page_node = array(
		'@type'       => 'CollectionPage',
		'@id'         => $page_id,
		'url'         => $url,
		'name'        => go_verge_news_authority_document_title( '' ),
		'description' => go_verge_newsroom_description(),
		'isPartOf'    => array( '@id' => $site_id ),
		'publisher'   => array( '@id' => $org_id ),
		'inLanguage'  => get_bloginfo( 'language' ),
	);
	if ( $items ) {
		$page_node['mainEntity'] = array( '@id' => $list_id );
	}
	if ( null !== $page_key ) {
		$data[ $page_key ] = array_merge( $data[ $page_key ], $page_node );
	} else {
		go_verge_schema_graph_add_unique( $data, 'goNewsroomPage', $page_node );
	}
	if ( $items ) {
		$list_node = array(
			'@type'           => 'ItemList',
			'@id'             => $list_id,
			'itemListOrder'   => 'https://schema.org/ItemListOrderDescending',
			'numberOfItems'   => count( $items ),
			'itemListElement' => $items,
		);
		$list_key = go_verge_schema_graph_find_id( $data, $list_id );
		if ( null === $list_key ) {
			go_verge_schema_graph_add_unique( $data, 'goNewsroomItemList', $list_node );
		} else {
			$data[ $list_key ] = array_replace( $data[ $list_key ], $list_node );
		}
	}
	return $data;
}
/* Run before the foundation closer (priority 900), which materializes the
 * WebSite/Organization nodes referenced by this archive graph. */
add_filter( 'rank_math/json_ld', 'go_verge_news_authority_rank_math_graph', 850, 1 );

/** Data used by Site Health; never makes a claim Google itself must decide. */
function go_verge_news_authority_health_snapshot() {
	$recent = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => 200,
			'fields'                 => 'ids',
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'no_found_rows'          => true,
			'ignore_sticky_posts'    => true,
			'date_query'             => array( array( 'after' => gmdate( 'Y-m-d H:i:s', time() - ( 2 * DAY_IN_SECONDS ) ), 'inclusive' => true, 'column' => 'post_date_gmt' ) ),
			'update_post_meta_cache' => true,
			'update_post_term_cache' => true,
		)
	);
	$eligible = array();
	$missing_image = array();
	$missing_author = array();
	$missing_sources = array();
	foreach ( array_map( 'absint', $recent ) as $post_id ) {
		if ( function_exists( 'go_verge_news_sitemap_post_is_eligible' ) && ! go_verge_news_sitemap_post_is_eligible( $post_id ) ) {
			continue;
		}
		$eligible[] = $post_id;
		if ( function_exists( 'go_verge_news_sitemap_image_url' ) && ! go_verge_news_sitemap_image_url( $post_id ) ) {
			$missing_image[] = $post_id;
		}
		$author_id = (int) get_post_field( 'post_author', $post_id );
		if ( ! $author_id || '' === trim( (string) get_the_author_meta( 'description', $author_id ) ) ) {
			$missing_author[] = $post_id;
		}
		if ( function_exists( 'go_verge_editorial_evidence_sources' ) && ! go_verge_editorial_evidence_sources( $post_id ) ) {
			$missing_sources[] = $post_id;
		}
	}
	return array(
		'recent_posts'    => count( $recent ),
		'eligible'        => count( $eligible ),
		'missing_image'   => count( $missing_image ),
		'missing_author'  => count( $missing_author ),
		'missing_sources' => count( $missing_sources ),
		'room_count'      => count( go_verge_news_authority_story_ids() ),
		'publication'     => function_exists( 'go_verge_news_sitemap_publication_name' ) ? go_verge_news_sitemap_publication_name() : '',
	);
}
