<?php
/**
 * Keep Search-first editorial categories out of homepage recommendation surfaces.
 *
 * Scope is intentionally narrow: this does not change indexability, sitemaps,
 * category archives, Search, feeds or the post itself. It only affects queries
 * explicitly executed while rendering the front page (plus its AJAX continuation).
 *
 * Editorial contract:
 * - Serviço/Serviços: never promoted on the homepage.
 * - Novelas: never promoted on the homepage, except Turkish productions.
 * - Produções/novelas/séries turcas remain fully eligible for homepage discovery.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Resolve category/tag term IDs defensively across current and legacy slugs.
 * Category descendants are included because WordPress editorial trees may move
 * without changing this homepage distribution rule.
 *
 * @param string $group One of service, novels, turkish_category, turkish_tag.
 * @return int[]
 */
function go_verge_homepage_search_only_term_ids( $group ) {
	static $cache = array();

	$group = sanitize_key( (string) $group );
	if ( isset( $cache[ $group ] ) ) {
		return $cache[ $group ];
	}

	$sets = array(
		'service' => array(
			'taxonomy' => 'category',
			'slugs'    => array( 'servico', 'servicos', 'servico-2', 'servicos-2' ),
			'names'    => array( 'Serviço', 'Serviços' ),
		),
		'novels' => array(
			'taxonomy' => 'category',
			'slugs'    => array( 'novelas', 'novela' ),
			'names'    => array( 'Novelas', 'Novela' ),
		),
		'turkish_category' => array(
			'taxonomy' => 'category',
			'slugs'    => array(
				'producoes-turcas',
				'filmes-series-dizis-turcas',
				'series-turcas',
				'novelas-turcas',
				'novelas-e-series-turcas',
			),
			'names'    => array(
				'Produções turcas',
				'Novelas e séries turcas',
				'Séries turcas',
				'Novelas turcas',
			),
		),
		'turkish_tag' => array(
			'taxonomy' => 'post_tag',
			'slugs'    => array( 'series-turcas', 'novelas-turcas', 'novela-turca', 'dizi', 'dizis' ),
			'names'    => array( 'Séries turcas', 'Novelas turcas', 'Novela turca', 'Dizi', 'Dizis' ),
		),
	);

	if ( ! isset( $sets[ $group ] ) ) {
		$cache[ $group ] = array();
		return $cache[ $group ];
	}

	$definition = $sets[ $group ];
	$taxonomy   = $definition['taxonomy'];
	$ids        = array();

	foreach ( $definition['slugs'] as $slug ) {
		$term = get_term_by( 'slug', sanitize_title( $slug ), $taxonomy );
		if ( $term instanceof WP_Term ) {
			$ids[] = (int) $term->term_id;
		}
	}

	foreach ( $definition['names'] as $name ) {
		$term = get_term_by( 'name', $name, $taxonomy );
		if ( $term instanceof WP_Term ) {
			$ids[] = (int) $term->term_id;
		}
	}

	if ( 'category' === $taxonomy ) {
		$roots = array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
		foreach ( $roots as $root_id ) {
			$children = get_term_children( $root_id, 'category' );
			if ( ! is_wp_error( $children ) ) {
				$ids = array_merge( $ids, array_map( 'absint', $children ) );
			}
		}
	}

	$cache[ $group ] = array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
	return $cache[ $group ];
}

/**
 * Turkish stories are the explicit exception to the generic Novelas rule.
 */
function go_verge_homepage_post_is_turkish( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return false;
	}

	$category_ids = go_verge_homepage_search_only_term_ids( 'turkish_category' );
	if ( $category_ids && has_term( $category_ids, 'category', $post_id ) ) {
		return true;
	}

	$tag_ids = go_verge_homepage_search_only_term_ids( 'turkish_tag' );
	return $tag_ids && has_term( $tag_ids, 'post_tag', $post_id );
}

/**
 * True when a published story is Search-first and must not be promoted on home.
 */
function go_verge_homepage_post_is_search_only( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return false;
	}

	$service_ids = go_verge_homepage_search_only_term_ids( 'service' );
	if ( $service_ids && has_term( $service_ids, 'category', $post_id ) ) {
		return true;
	}

	$novel_ids = go_verge_homepage_search_only_term_ids( 'novels' );
	if ( $novel_ids && has_term( $novel_ids, 'category', $post_id ) ) {
		return ! go_verge_homepage_post_is_turkish( $post_id );
	}

	return false;
}

/**
 * Determine whether the current query is a homepage editorial surface.
 */
function go_verge_homepage_search_only_query_is_scoped( WP_Query $query ) {
	if ( ! empty( $GLOBALS['go_verge_homepage_query_context'] ) ) {
		return true;
	}
	return (bool) $query->get( 'go_homepage_surface' );
}

/**
 * Build a small EXISTS subquery against WordPress taxonomy tables.
 *
 * @param string $alias    SQL alias suffix.
 * @param string $taxonomy Taxonomy name.
 * @param int[]  $term_ids Term IDs.
 * @return string SQL expression without a leading AND/OR.
 */
function go_verge_homepage_search_only_exists_sql( $alias, $taxonomy, $term_ids ) {
	global $wpdb;

	$term_ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $term_ids ) ) ) );
	if ( empty( $term_ids ) ) {
		return '';
	}

	$alias    = preg_replace( '/[^a-z0-9_]/i', '', (string) $alias );
	$taxonomy = sanitize_key( (string) $taxonomy );
	$id_list  = implode( ',', $term_ids );

	return "EXISTS (\n"
		. "\tSELECT 1 FROM {$wpdb->term_relationships} go_home_{$alias}_tr\n"
		. "\tINNER JOIN {$wpdb->term_taxonomy} go_home_{$alias}_tt ON go_home_{$alias}_tt.term_taxonomy_id = go_home_{$alias}_tr.term_taxonomy_id\n"
		. "\tWHERE go_home_{$alias}_tr.object_id = {$wpdb->posts}.ID\n"
		. "\tAND go_home_{$alias}_tt.taxonomy = '" . esc_sql( $taxonomy ) . "'\n"
		. "\tAND go_home_{$alias}_tt.term_id IN ({$id_list})\n"
		. ')';
}

/**
 * Enforce the homepage-only editorial exclusion at SQL level.
 *
 * SQL-level filtering matters here: filtering after WP_Query would leave hero
 * slots/feed pages short and would allow pagination to leak Search-only stories.
 *
 * @param string   $where Existing WHERE clause.
 * @param WP_Query $query Query instance.
 * @return string
 */
function go_verge_homepage_filter_search_only_where( $where, $query ) {
	if ( ! ( $query instanceof WP_Query ) || ! go_verge_homepage_search_only_query_is_scoped( $query ) ) {
		return $where;
	}

	$post_type = $query->get( 'post_type' );
	if ( is_array( $post_type ) && ! in_array( 'post', $post_type, true ) && ! in_array( 'any', $post_type, true ) ) {
		return $where;
	}
	if ( is_string( $post_type ) && '' !== $post_type && 'post' !== $post_type && 'any' !== $post_type ) {
		return $where;
	}

	$service_ids   = go_verge_homepage_search_only_term_ids( 'service' );
	$novel_ids     = go_verge_homepage_search_only_term_ids( 'novels' );
	$turkish_cats  = go_verge_homepage_search_only_term_ids( 'turkish_category' );
	$turkish_tags  = go_verge_homepage_search_only_term_ids( 'turkish_tag' );

	$service_exists = go_verge_homepage_search_only_exists_sql( 'service', 'category', $service_ids );
	$novel_exists   = go_verge_homepage_search_only_exists_sql( 'novels', 'category', $novel_ids );
	$turkish_cat_exists = go_verge_homepage_search_only_exists_sql( 'turkish_cat', 'category', $turkish_cats );
	$turkish_tag_exists = go_verge_homepage_search_only_exists_sql( 'turkish_tag', 'post_tag', $turkish_tags );

	if ( $service_exists ) {
		$where .= "\n AND NOT ({$service_exists})";
	}

	if ( $novel_exists ) {
		$exceptions = array_filter( array( $turkish_cat_exists, $turkish_tag_exists ) );
		if ( $exceptions ) {
			$where .= "\n AND ( NOT ({$novel_exists}) OR " . implode( ' OR ', array_map( static function ( $sql ) { return '(' . $sql . ')'; }, $exceptions ) ) . ' )';
		} else {
			$where .= "\n AND NOT ({$novel_exists})";
		}
	}

	return $where;
}
add_filter( 'posts_where', 'go_verge_homepage_filter_search_only_where', 20, 2 );
