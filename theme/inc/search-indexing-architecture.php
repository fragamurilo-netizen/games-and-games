<?php
/**
 * Search/indexing architecture hardening.
 *
 * Keeps crawl/index signals consistent across WordPress core + Rank Math,
 * removes duplicate auto-link processing, preserves useful hubs, and ensures
 * the Games CPT keeps a VideoGame node when Rank Math owns the main graph.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Pages that are useful to users but should not compete in organic search. */
function go_verge_search_utility_page_slugs() {
	return array( 'busca', 'para-voce', 'salvos', 'preferencias-newsletter', 'status' );
}

/** True when the current request is a utility/search surface. */
function go_verge_search_is_utility_surface() {
	if ( is_search() ) {
		return true;
	}
	foreach ( go_verge_search_utility_page_slugs() as $slug ) {
		if ( is_page( $slug ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Disable the older 500-entity/DOM autolinker. The article single already
 * runs go_verge_intelligent_internal_links(), capped at three contextual links.
 */
function go_verge_search_disable_duplicate_autolinker() {
	remove_filter( 'the_content', 'go_verge_auto_internal_links', 12 );
}
add_action( 'after_setup_theme', 'go_verge_search_disable_duplicate_autolinker', 1000 );
add_action( 'wp', 'go_verge_search_disable_duplicate_autolinker', 1 );

/** Keep utility/search pages crawlable for links but out of the index. */
function go_verge_search_utility_robots( $robots ) {
	if ( go_verge_search_is_utility_surface() ) {
		$robots['noindex'] = true;
		$robots['follow']  = true;
		unset( $robots['index'] );
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_search_utility_robots', 120 );

/** Match the same policy when Rank Math owns robots directives. */
function go_verge_search_rank_math_utility_robots( $robots ) {
	if ( ! is_array( $robots ) || ! go_verge_search_is_utility_surface() ) {
		return $robots;
	}
	$robots['index']  = 'noindex';
	$robots['follow'] = 'follow';
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_search_rank_math_utility_robots', 120 );


/**
 * Date archives duplicate the same stories already exposed through stronger
 * category, author and topic hubs. Keep their links crawlable, but do not spend
 * index space on /YYYY/, /YYYY/MM/ and /YYYY/MM/DD/ result pages.
 */
function go_verge_search_date_archive_robots( $robots ) {
	if ( is_date() ) {
		$robots['noindex'] = true;
		$robots['follow']  = true;
		unset( $robots['index'] );
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_search_date_archive_robots', 125 );

/** Match the date-archive policy when Rank Math owns the robots tag. */
function go_verge_search_rank_math_date_archive_robots( $robots ) {
	if ( ! is_array( $robots ) || ! is_date() ) {
		return $robots;
	}
	$robots['index']  = 'noindex';
	$robots['follow'] = 'follow';
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_search_rank_math_date_archive_robots', 125 );

/** Resolve IDs of utility pages once per request. */
function go_verge_search_utility_page_ids() {
	static $ids = null;
	if ( null !== $ids ) {
		return $ids;
	}
	$ids = array();
	foreach ( go_verge_search_utility_page_slugs() as $slug ) {
		$page = get_page_by_path( $slug );
		if ( $page instanceof WP_Post ) {
			$ids[] = (int) $page->ID;
		}
	}
	return array_values( array_unique( array_filter( $ids ) ) );
}

/** IDs of Pages whose public URL is owned by another canonical surface. */
function go_verge_search_redirected_page_ids() {
	$slugs = array( 'ultimas-noticias-2' );

	if ( get_post_type_archive_link( 'go_promotion' ) ) {
		$slugs = array_merge( $slugs, array( 'promocoes-2', 'promocoes-3' ) );
	}
	if ( post_type_exists( 'games' ) && get_post_type_archive_link( 'games' ) ) {
		$slugs[] = 'games';
	}
	if ( get_page_by_path( 'sobre-o-overdrive', OBJECT, 'page' ) ) {
		$slugs[] = 'sobre-o-game-overdrive';
	}
	if ( get_page_by_path( 'privacidade', OBJECT, 'page' ) ) {
		$slugs[] = 'politica-de-privacidade';
	}

	$ids = array();
	foreach ( array_unique( $slugs ) as $slug ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $page instanceof WP_Post ) {
			$ids[] = (int) $page->ID;
		}
	}

	return array_values( array_unique( array_filter( $ids ) ) );
}

/** Category slugs consolidated into Pages, CPT archives or canonical terms. */
function go_verge_search_redirected_category_slugs() {
	/* Games belongs to its CPT archive. When the durable editorial Pages for
	 * Entretenimento/Tecnologia exist, those Pages own the root URLs and the
	 * identically addressed category objects stay out of every sitemap. */
	$slugs = array( 'games', 'jogos', 'entertainment', 'technology', 'tech' );
	foreach ( array( 'entretenimento', 'tecnologia' ) as $page_slug ) {
		$page = get_page_by_path( $page_slug, OBJECT, 'page' );
		if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
			$slugs[] = $page_slug;
		}
	}

	if ( function_exists( 'go_verge_editorial_category_alias_map' ) ) {
		$slugs = array_merge( $slugs, array_keys( go_verge_editorial_category_alias_map() ) );
	}
	if ( function_exists( 'go_verge_entertainment_category_config' ) ) {
		$config = go_verge_entertainment_category_config();
		$slugs  = array_merge(
			$slugs,
			(array) ( $config['series']['aliases'] ?? array() ),
			(array) ( $config['films']['aliases'] ?? array() )
		);
	}
	if ( function_exists( 'go_verge_canonical_guides_page_url' ) && '' !== go_verge_canonical_guides_page_url() ) {
		$slugs[] = 'dicas-e-guias';
	}
	if ( function_exists( 'go_verge_canonical_buying_guides_url' ) && '' !== go_verge_canonical_buying_guides_url() && function_exists( 'go_verge_buying_guides_category_slugs' ) ) {
		$slugs = array_merge( $slugs, go_verge_buying_guides_category_slugs() );
	}

	return array_values( array_unique( array_filter( array_map( 'sanitize_title', $slugs ) ) ) );
}

/** IDs for the redirected category set, resolved only when a sitemap asks. */
function go_verge_search_redirected_category_ids() {
	$ids = array();
	foreach ( go_verge_search_redirected_category_slugs() as $slug ) {
		$term = get_term_by( 'slug', $slug, 'category' );
		if ( $term instanceof WP_Term ) {
			$ids[] = (int) $term->term_id;
		}
	}
	return array_values( array_unique( array_filter( $ids ) ) );
}

/** Core sitemap: remove utility pages while preserving useful hubs. */
function go_verge_search_core_sitemap_exclude_utilities( $args, $post_type ) {
	if ( 'page' !== $post_type ) {
		return $args;
	}
	$ids = array_values( array_unique( array_merge( go_verge_search_utility_page_ids(), go_verge_search_redirected_page_ids() ) ) );
	if ( $ids ) {
		$args['post__not_in'] = array_values( array_unique( array_merge( isset( $args['post__not_in'] ) ? (array) $args['post__not_in'] : array(), $ids ) ) );
	}
	return $args;
}
add_filter( 'wp_sitemaps_posts_query_args', 'go_verge_search_core_sitemap_exclude_utilities', 120, 2 );

/** Cache IDs of tag terms that are intentionally noindex because they are thin. */
function go_verge_search_thin_tag_ids() {
	$cached = get_transient( 'go_verge_thin_tag_ids_v2' );
	if ( is_array( $cached ) ) {
		return array_map( 'absint', $cached );
	}
	$terms = get_terms(
		array(
			'taxonomy'   => 'post_tag',
			'hide_empty' => false,
			'fields'     => 'all',
		)
	);
	$ids = array();
	if ( ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			if ( $term instanceof WP_Term && ( (int) $term->count < 2 || ( function_exists( 'go_verge_is_tag_alias' ) && go_verge_is_tag_alias( $term ) ) ) ) {
				$ids[] = (int) $term->term_id;
			}
		}
	}
	set_transient( 'go_verge_thin_tag_ids_v2', $ids, 6 * HOUR_IN_SECONDS );
	return $ids;
}

/** Bust the thin-tag cache when terms/relationships change. */
function go_verge_search_bust_thin_tag_cache( $object_id = null, $terms = null, $tt_ids = null, $taxonomy = '' ) {
	unset( $object_id, $terms, $tt_ids );
	if ( 'set_object_terms' === current_filter() && 'post_tag' !== $taxonomy ) {
		return;
	}
	delete_transient( 'go_verge_thin_tag_ids_v2' );
}
add_action( 'created_post_tag', 'go_verge_search_bust_thin_tag_cache' );
add_action( 'edited_post_tag', 'go_verge_search_bust_thin_tag_cache' );
add_action( 'delete_post_tag', 'go_verge_search_bust_thin_tag_cache' );
add_action( 'set_object_terms', 'go_verge_search_bust_thin_tag_cache', 100, 4 );

/** Core sitemap: if a tag is noindex, do not submit it in the sitemap. */
function go_verge_search_core_sitemap_exclude_thin_tags( $args, $taxonomy ) {
	$ids = array();
	if ( 'post_tag' === $taxonomy ) {
		$ids = go_verge_search_thin_tag_ids();
	} elseif ( 'category' === $taxonomy ) {
		$ids = go_verge_search_redirected_category_ids();
	}
	if ( $ids ) {
		$args['exclude'] = array_values( array_unique( array_merge( isset( $args['exclude'] ) ? (array) $args['exclude'] : array(), $ids ) ) );
	}
	return $args;
}
add_filter( 'wp_sitemaps_taxonomies_query_args', 'go_verge_search_core_sitemap_exclude_thin_tags', 120, 2 );

/**
 * Rank Math sitemap entry policy: mirror noindex decisions exactly.
 * Returning false is supported by Rank Math's entry filter and simply omits
 * that URL from the generated sitemap.
 */
function go_verge_search_rank_math_sitemap_entry( $url, $type, $object ) {
	if ( $object instanceof WP_Post && 'page' === $object->post_type ) {
		$excluded_pages = array_merge( go_verge_search_utility_page_ids(), go_verge_search_redirected_page_ids() );
		if ( in_array( (int) $object->ID, $excluded_pages, true ) ) {
			return false;
		}
	}
	if ( $object instanceof WP_Term && 'category' === $object->taxonomy && in_array( $object->slug, go_verge_search_redirected_category_slugs(), true ) ) {
		return false;
	}
	if ( $object instanceof WP_Term && 'post_tag' === $object->taxonomy && ( (int) $object->count < 2 || ( function_exists( 'go_verge_is_tag_alias' ) && go_verge_is_tag_alias( $object ) ) ) ) {
		return false;
	}
	return $url;
}
add_filter( 'rank_math/sitemap/entry', 'go_verge_search_rank_math_sitemap_entry', 120, 3 );

/**
 * Canonical main XML sitemap URL owned by the theme in every plugin state.
 */
function go_verge_search_main_sitemap_url() {
	/* Overdrive owns one stable sitemap contract. Rank Math/Core may keep their
	 * endpoints for compatibility, but robots.txt and Search Console should point
	 * to the newsroom sitemap so plugin/module state cannot make discovery vanish. */
	return home_url( '/sitemap.xml' );
}

/**
 * Last-resort compatibility for legacy plugin/Core sitemap entry points.
 *
 * sitemap-smart.php normally answers these aliases as XML 200 before the main
 * query starts. Keeping a late fallback makes unusual stacks resilient without
 * making the legacy URL the canonical discovery contract.
 */
function go_verge_search_legacy_sitemap_index_fallback() {
	if ( is_admin() || wp_doing_ajax() ) { return; }
	$path = trim( (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH ), '/' );
	if ( ! in_array( $path, array( 'sitemap_index.xml', 'wp-sitemap.xml' ), true ) ) { return; }

	if ( function_exists( 'go_verge_smart_sitemap_render_route' ) ) {
		go_verge_smart_sitemap_render_route( array( 'kind' => 'index', 'key' => 'index' ) );
	}

	wp_safe_redirect( home_url( '/sitemap.xml' ), 301, 'Overdrive canonical sitemap' );
	exit;
}
add_action( 'template_redirect', 'go_verge_search_legacy_sitemap_index_fallback', -1000 );

/** Advertise the canonical index and the high-signal fresh sitemap in robots.txt. */
function go_verge_search_main_sitemap_in_robots( $output ) {
	$main  = go_verge_search_main_sitemap_url();
	$fresh = home_url( '/sitemap-fresh.xml' );
	foreach ( array( $main, $fresh ) as $url ) {
		if ( false === strpos( $output, $url ) ) {
			$output .= "\nSitemap: " . esc_url_raw( $url ) . "\n";
		}
	}
	return $output;
}
add_filter( 'robots_txt', 'go_verge_search_main_sitemap_in_robots', 40 );

/**
 * Keep every sitemap directive unique and preserve the Overdrive sitemap contract.
 *
 * Some plugin/host combinations append the WordPress core sitemap once per
 * registered provider. Running last makes robots.txt deterministic even when
 * an upstream callback repeats the same line hundreds of times.
 */
function go_verge_search_normalize_robots_sitemaps( $output ) {
	$main  = go_verge_search_main_sitemap_url();
	$fresh = home_url( '/sitemap-fresh.xml' );
	$news  = home_url( '/news-sitemap.xml' );
	$seen  = array();
	$clean = array();

	foreach ( preg_split( '/\r\n|\r|\n/', (string) $output ) as $line ) {
		$rule = strtolower( trim( $line ) );
		/* These pages emit noindex,follow and must remain crawlable for search
		 * engines to see both that directive and their outgoing links. */
		if ( in_array( $rule, array( 'disallow: /?s=', 'disallow: /search/' ), true ) ) { continue; }
		if ( 'disallow: */trackback/' === $rule ) { $line = 'Disallow: /*/trackback/'; }
		if ( preg_match( '/^\s*Sitemap:\s*(\S+)\s*$/i', $line, $match ) ) {
			$url  = esc_url_raw( $match[1] );
			$key  = strtolower( untrailingslashit( $url ) );
			$allowed = array(
				strtolower( untrailingslashit( $main ) ),
				strtolower( untrailingslashit( $fresh ) ),
				strtolower( untrailingslashit( $news ) ),
			);

			/* The newsroom owns one sitemap contract. Drop Core, Yoast/Rank Math,
			 * the 2026 Yoast schema-aggregator schemamap and RSS-as-sitemap lines.
			 * RSS remains discoverable through <link rel=alternate>; robots.txt
			 * advertises only the canonical XML index, the fresh discovery set and the News endpoint. */
			if ( '' === $key || ! in_array( $key, $allowed, true ) || isset( $seen[ $key ] ) ) { continue; }
			$seen[ $key ] = true;
			$clean[] = 'Sitemap: ' . $url;
			continue;
		}
		$clean[] = rtrim( $line );
	}

	foreach ( array( $main, $fresh, $news ) as $url ) {
		$key = strtolower( untrailingslashit( $url ) );
		if ( ! isset( $seen[ $key ] ) ) {
			$clean[] = 'Sitemap: ' . esc_url_raw( $url );
			$seen[ $key ] = true;
		}
	}

	$output = trim( implode( "\n", $clean ) );
	$output = preg_replace( "/\n{3,}/", "\n\n", $output );
	return $output . "\n";
}
add_filter( 'robots_txt', 'go_verge_search_normalize_robots_sitemaps', PHP_INT_MAX );

/** Canonical fallback only when Rank Math unexpectedly emits an empty value. */
function go_verge_search_rank_math_canonical_fallback( $canonical ) {
	if ( '' !== trim( (string) $canonical ) ) {
		return $canonical;
	}
	if ( is_singular( array( 'post', 'page', 'games', 'go_entity', 'productions', 'go_promotion' ) ) ) {
		return get_permalink( get_queried_object_id() );
	}
	return $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_search_rank_math_canonical_fallback', 120 );


/**
 * Collapse internal home-feed query variants into the canonical home URL.
 *
 * Search engines have discovered URLs such as /?stream_page=1. They render the
 * same homepage and should not become a second indexable home. Canonicalization
 * is intentionally used instead of noindex so signals consolidate cleanly.
 *
 * @param string $canonical Rank Math canonical URL.
 * @return string
 */
function go_verge_search_home_parameter_canonical( $canonical ) {
	if ( is_front_page() && isset( $_GET['stream_page'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return home_url( '/' );
	}
	return $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_search_home_parameter_canonical', 999 );

/**
 * IDs shown by the game hub, shared by the HTML template and both schema
 * engines so structured data never describes hidden or differently ordered
 * stories.
 */
function go_verge_game_hub_related_ids( $game_id, $limit = 200 ) {
	static $cache = array();

	$game_id = absint( $game_id );
	$limit   = max( 1, min( 200, absint( $limit ) ) );
	$key     = $game_id . ':' . $limit;
	if ( isset( $cache[ $key ] ) ) {
		return $cache[ $key ];
	}
	if ( ! $game_id || 'games' !== get_post_type( $game_id ) || ! function_exists( 'go_verge_product_related_post_ids' ) ) {
		return array();
	}

	$ids = go_verge_product_related_post_ids( $game_id, 'games', $limit );
	usort(
		$ids,
		static function ( $first_id, $second_id ) {
			return (int) get_post_time( 'U', true, $second_id ) <=> (int) get_post_time( 'U', true, $first_id );
		}
	);
	$cache[ $key ] = array_values( array_unique( array_map( 'absint', $ids ) ) );
	return $cache[ $key ];
}

/** Latest meaningful hub update: the game record or its newest linked story. */
function go_verge_game_hub_modified_iso( $game_id, $story_ids = null ) {
	$game_id = absint( $game_id );
	$latest  = (int) get_post_modified_time( 'U', true, $game_id );
	$ids     = is_array( $story_ids ) ? $story_ids : go_verge_game_hub_related_ids( $game_id );
	foreach ( $ids as $story_id ) {
		$latest = max( $latest, (int) get_post_modified_time( 'U', true, $story_id ) );
	}
	return $latest ? gmdate( 'c', $latest ) : get_post_modified_time( 'c', true, $game_id );
}

/**
 * Schema.org ItemList for the exact chronological coverage rendered in HTML.
 */
function go_verge_game_hub_coverage_schema( $game_id, $game_schema_id = '' ) {
	$game_id = absint( $game_id );
	$ids     = go_verge_game_hub_related_ids( $game_id );
	if ( ! $ids ) {
		return null;
	}

	$game_url       = get_permalink( $game_id );
	$game_schema_id = $game_schema_id ? $game_schema_id : $game_url . '#videogame';
	$items          = array();
	foreach ( $ids as $index => $story_id ) {
		$url  = get_permalink( $story_id );
		$author_id   = absint( get_post_field( 'post_author', $story_id ) );
		$author_name = $author_id ? trim( (string) get_the_author_meta( 'display_name', $author_id ) ) : '';
		$item = array(
			'@type'         => 'Article',
			'@id'           => $url . '#article',
			'url'           => $url,
			'headline'      => wp_strip_all_tags( get_the_title( $story_id ) ),
			'datePublished' => get_post_time( 'c', true, $story_id ),
			'dateModified'  => get_post_modified_time( 'c', true, $story_id ),
			'publisher'     => array( '@id' => home_url( '/#organization' ) ),
			'about'         => array( '@id' => $game_schema_id ),
		);
		if ( $author_id && $author_name ) {
			$item['author'] = array(
				'@type' => 'Person',
				'name'  => $author_name,
				'url'   => get_author_posts_url( $author_id ),
			);
		}
		$description = function_exists( 'go_verge_support_text' ) ? go_verge_support_text( $story_id ) : get_the_excerpt( $story_id );
		if ( $description ) {
			$item['description'] = wp_trim_words( wp_strip_all_tags( $description ), 36, '…' );
		}
		if ( has_post_thumbnail( $story_id ) ) {
			$image = wp_get_attachment_image_url( get_post_thumbnail_id( $story_id ), 'go_hero' );
			if ( $image ) {
				$item['image'] = $image;
			}
		}
		$items[] = array(
			'@type'    => 'ListItem',
			'position' => $index + 1,
			'item'     => $item,
		);
	}

	return array(
		'@type'           => 'ItemList',
		'@id'             => $game_url . '#coverage',
		'name'            => sprintf( __( 'Matérias sobre %s', 'go-verge' ), function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $game_id ) : get_the_title( $game_id ) ),
		'itemListOrder'   => 'https://schema.org/ItemListOrderDescending',
		'numberOfItems'   => count( $items ),
		'itemListElement' => $items,
	);
}

/** Turn the game single's WebPage into the collection hub shown to readers. */
function go_verge_game_hub_webpage_schema( $game_id, $node = array(), $game_schema_id = '' ) {
	$game_id        = absint( $game_id );
	$url            = get_permalink( $game_id );
	$story_ids      = go_verge_game_hub_related_ids( $game_id );
	$game_schema_id = $game_schema_id ? $game_schema_id : $url . '#videogame';

	$node['@type']         = 'CollectionPage';
	$node['@id']           = $url . '#webpage';
	$node['url']           = $url;
	$node['mainEntity']    = array( '@id' => $game_schema_id );
	$node['about']         = array( '@id' => $game_schema_id );
	$node['breadcrumb']    = array( '@id' => $url . '#webpage/breadcrumb' );
	$node['datePublished'] = get_post_time( 'c', true, $game_id );
	$node['dateModified']  = go_verge_game_hub_modified_iso( $game_id, $story_ids );
	if ( empty( $node['description'] ) ) {
		$data = function_exists( 'go_verge_game_data' ) ? go_verge_game_data( $game_id ) : array();
		$description = trim( wp_strip_all_tags( (string) ( $data['summary'] ?? '' ) ) );
		if ( $description ) {
			$node['description'] = wp_trim_words( $description, 36, '…' );
		}
	}
	if ( empty( $node['primaryImageOfPage'] ) && has_post_thumbnail( $game_id ) ) {
		$image = wp_get_attachment_image_url( get_post_thumbnail_id( $game_id ), 'go_hero' );
		if ( $image ) {
			$node['primaryImageOfPage'] = array( '@type' => 'ImageObject', 'url' => $image );
		}
	}
	if ( $story_ids ) {
		$node['hasPart'] = array( '@id' => $url . '#coverage' );
	}
	return $node;
}

/** Canonical breadcrumb hierarchy for the games database. */
function go_verge_game_hub_breadcrumb_schema( $game_id ) {
	$game_id   = absint( $game_id );
	$game_url  = get_permalink( $game_id );
	$games_url = get_post_type_archive_link( 'games' );
	$games_url = $games_url ? $games_url : home_url( '/games/' );

	return array(
		'@type'           => 'BreadcrumbList',
		'@id'             => $game_url . '#webpage/breadcrumb',
		'itemListElement' => array(
			array( '@type' => 'ListItem', 'position' => 1, 'name' => __( 'Home', 'go-verge' ), 'item' => home_url( '/' ) ),
			array( '@type' => 'ListItem', 'position' => 2, 'name' => __( 'Games', 'go-verge' ), 'item' => $games_url ),
			array( '@type' => 'ListItem', 'position' => 3, 'name' => function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $game_id ) : get_the_title( $game_id ), 'item' => $game_url ),
		),
	);
}

/**
 * Expand Rank Math's graph instead of printing a competing JSON-LD block.
 * The game page is a CollectionPage whose main entity is a VideoGame and whose
 * visible chronological feed is represented by one ItemList.
 */
function go_verge_search_rank_math_games_schema( $data, $jsonld = null ) {
	if ( ! is_singular( 'games' ) || ! is_array( $data ) || ! function_exists( 'go_verge_schema_videogame' ) ) {
		return $data;
	}
	$post_id = get_queried_object_id();
	if ( ! $post_id ) {
		return $data;
	}
	$game         = go_verge_schema_videogame( $post_id );
	$current_url  = get_permalink( $post_id );
	if ( empty( $game ) || ! is_array( $game ) ) { return $data; }
	$game_key     = null;
	$page_key     = null;
	$breadcrumb_key = null;

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || empty( $node['@type'] ) ) {
			continue;
		}
		$types = array_map( 'strval', (array) $node['@type'] );
		if ( ! empty( $game['@id'] ) && isset( $node['@id'] ) && (string) $game['@id'] === (string) $node['@id'] ) {
			$game_key = $key;
		}
		if ( go_verge_schema_node_matches_url( $node, $current_url, array( 'WebPage', 'ItemPage', 'CollectionPage' ) ) ) {
			$page_key = $key;
		}
		if ( go_verge_schema_node_matches_url( $node, $current_url, array( 'BreadcrumbList' ) ) ) {
			$breadcrumb_key = $key;
		}
		// A database hub is not a news story. Remove Rank Math's generic
		// Article fallback while preserving Review and every unrelated node.
		if ( go_verge_schema_node_matches_url( $node, $current_url, array( 'Article', 'NewsArticle', 'BlogPosting' ) ) ) {
			unset( $data[ $key ] );
		}
	}

	if ( null === $game_key && ! empty( $game ) ) {
		$game_key = go_verge_schema_graph_add_unique( $data, 'goVideoGame', $game );
	} elseif ( null !== $game_key ) {
		$data[ $game_key ] = array_replace( $game, $data[ $game_key ] );
	}

	$game_schema_id = ! empty( $data[ $game_key ]['@id'] ) ? $data[ $game_key ]['@id'] : get_permalink( $post_id ) . '#videogame';
	if ( null === $page_key ) {
		go_verge_schema_graph_add_unique( $data, 'goGameHubPage', go_verge_game_hub_webpage_schema(
			$post_id,
			array(
				'name'       => wp_get_document_title(),
				'isPartOf'   => array( '@id' => home_url( '/#website' ) ),
				'inLanguage' => get_bloginfo( 'language' ),
			),
			$game_schema_id
		) );
	} else {
		$data[ $page_key ] = go_verge_game_hub_webpage_schema( $post_id, $data[ $page_key ], $game_schema_id );
	}

	$coverage = go_verge_game_hub_coverage_schema( $post_id, $game_schema_id );
	if ( $coverage ) {
		$coverage_key = go_verge_schema_graph_find_id( $data, $coverage['@id'] );
		if ( null === $coverage_key ) { go_verge_schema_graph_add_unique( $data, 'goGameCoverage', $coverage ); }
		else { $data[ $coverage_key ] = array_replace( $data[ $coverage_key ], $coverage ); }
	}

	$breadcrumb = go_verge_game_hub_breadcrumb_schema( $post_id );
	if ( null === $breadcrumb_key ) {
		go_verge_schema_graph_add_unique( $data, 'goGameBreadcrumb', $breadcrumb );
	} else {
		$data[ $breadcrumb_key ] = $breadcrumb;
	}

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_search_rank_math_games_schema', 97, 2 );

/** Use the structured game summary when no custom Rank Math description exists. */
function go_verge_game_hub_rank_math_description( $description ) {
	if ( ! is_singular( 'games' ) ) {
		return $description;
	}
	$post_id = get_queried_object_id();
	if ( '' !== trim( (string) get_post_meta( $post_id, 'rank_math_description', true ) ) ) {
		return $description;
	}
	$data = function_exists( 'go_verge_game_data' ) ? go_verge_game_data( $post_id ) : array();
	$text = trim( wp_strip_all_tags( (string) ( $data['summary'] ?? '' ) ) );
	if ( '' === $text ) {
		$name = function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $post_id ) : get_the_title( $post_id );
		$text = sprintf( __( 'Tudo sobre %s: notícias, guias, reviews, vídeos, plataformas, lançamento e ficha técnica.', 'go-verge' ), $name );
	}
	$text = preg_replace( '/\s+/u', ' ', $text );
	if ( function_exists( 'mb_strimwidth' ) ) {
		return mb_strimwidth( $text, 0, 155, '…', 'UTF-8' );
	}
	return strlen( $text ) > 155 ? rtrim( substr( $text, 0, 154 ) ) . '…' : $text;
}
add_filter( 'rank_math/frontend/description', 'go_verge_game_hub_rank_math_description', 30 );

/** Strip filter/query parameters from the game hub canonical unless customized. */
function go_verge_game_hub_rank_math_canonical( $canonical ) {
	if ( ! is_singular( 'games' ) ) {
		return $canonical;
	}
	$post_id = get_queried_object_id();
	if ( '' !== trim( (string) get_post_meta( $post_id, 'rank_math_canonical_url', true ) ) ) {
		return $canonical;
	}
	return get_permalink( $post_id );
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_game_hub_rank_math_canonical', 125 );

/**
 * Keep the retained three-link engine conservative: tags are eligible only
 * when the post text actually supports the phrase, not merely because a term
 * was attached in WordPress.
 */
function go_verge_search_autolink_tag_is_supported( $post_id, $label ) {
	$post = get_post( $post_id );
	if ( ! $post ) {
		return false;
	}
	$deck = function_exists( 'go_verge_subtitle' ) ? (string) go_verge_subtitle( $post_id ) : (string) get_post_meta( $post_id, '_go_post_subtitle', true );
	$text = $post->post_title . ' ' . $deck . ' ' . wp_strip_all_tags( strip_shortcodes( $post->post_content ) );
	if ( function_exists( 'go_verge_semantic_phrase_count' ) ) {
		return go_verge_semantic_phrase_count( $label, $text ) > 0;
	}
	return false !== stripos( remove_accents( $text ), remove_accents( $label ) );
}

/**
 * Site Health: expose the settings that most commonly delay discovery of new
 * articles. This is diagnostic only and never changes indexing preferences.
 */
function go_verge_register_indexing_health_test( $tests ) {
	$tests['direct']['go_verge_indexing_readiness'] = array(
		'label' => __( 'Prontidão de indexação das matérias', 'go-verge' ),
		'test'  => 'go_verge_indexing_readiness_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_indexing_health_test' );

function go_verge_indexing_readiness_health_test() {
	$issues  = array();
	$actions = array();

	if ( '1' !== (string) get_option( 'blog_public', '1' ) ) {
		$issues[]  = __( 'A opção “Evitar que mecanismos de pesquisa indexem este site” está ativa.', 'go-verge' );
		$actions[] = sprintf(
			'<a href="%1$s">%2$s</a>',
			esc_url( admin_url( 'options-reading.php' ) ),
			esc_html__( 'Abrir Configurações de leitura', 'go-verge' )
		);
	}

	if ( '' === trim( (string) get_option( 'permalink_structure' ) ) ) {
		$issues[]  = __( 'Os links permanentes legíveis não estão ativos.', 'go-verge' );
		$actions[] = sprintf(
			'<a href="%1$s">%2$s</a>',
			esc_url( admin_url( 'options-permalink.php' ) ),
			esc_html__( 'Abrir Links permanentes', 'go-verge' )
		);
	}

	$rewrite_rules = get_option( 'rewrite_rules', array() );
	$has_news_rule = false;
	if ( is_array( $rewrite_rules ) ) {
		foreach ( array_keys( $rewrite_rules ) as $rule ) {
			if ( false !== strpos( (string) $rule, 'news-sitemap' ) ) {
				$has_news_rule = true;
				break;
			}
		}
	}
	if ( ! $has_news_rule ) {
		$issues[]  = __( 'A regra persistida do news-sitemap ainda não aparece no WordPress.', 'go-verge' );
		$actions[] = sprintf(
			'<a href="%1$s">%2$s</a>',
			esc_url( admin_url( 'options-permalink.php' ) ),
			esc_html__( 'Salvar novamente os Links permanentes', 'go-verge' )
		);
	}

	$latest = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => 1,
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'fields'                 => 'ids',
			'no_found_rows'          => true,
			'ignore_sticky_posts'    => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		)
	);
	if ( ! empty( $latest[0] ) ) {
		$robots = get_post_meta( (int) $latest[0], 'rank_math_robots', true );
		$flat   = is_array( $robots ) ? array_map( 'strtolower', array_map( 'strval', array_merge( array_keys( $robots ), array_values( $robots ) ) ) ) : array();
		foreach ( $flat as $directive ) {
			if ( false !== strpos( $directive, 'noindex' ) ) {
				$issues[]  = __( 'A matéria mais recente está marcada como noindex no Rank Math.', 'go-verge' );
				$actions[] = sprintf(
					'<a href="%1$s">%2$s</a>',
					esc_url( get_edit_post_link( (int) $latest[0], '' ) ),
					esc_html__( 'Revisar a matéria mais recente', 'go-verge' )
				);
				break;
			}
		}
	}

	$good = empty( $issues );
	return array(
		'label'       => $good
			? __( 'As configurações locais permitem descoberta e indexação', 'go-verge' )
			: __( 'Há sinais locais que podem atrasar a indexação', 'go-verge' ),
		'status'      => $good ? 'good' : 'critical',
		'badge'       => array( 'label' => __( 'Indexação', 'go-verge' ), 'color' => 'blue' ),
		'description' => $good
			? '<p>' . esc_html__( 'O site está público, usa URLs legíveis e mantém a rota do sitemap de notícias registrada.', 'go-verge' ) . '</p>'
			: '<p>' . esc_html( implode( ' ', $issues ) ) . '</p>',
		'actions'     => $actions ? '<p>' . implode( ' · ', array_unique( $actions ) ) . '</p>' : '',
		'test'        => 'go_verge_indexing_readiness',
	);
}
