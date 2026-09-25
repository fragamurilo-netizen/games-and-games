<?php
/**
 * Editorial category indexing parity.
 *
 * Gives every canonical Overdrive desk the same technical Search contract:
 * canonical taxonomy tree, index/follow robots, self-referencing canonicals,
 * clean Rank Math term metadata without changing existing story classification.
 * Editorial migrations remain owned by their existing background workflow.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

const GO_VERGE_CATEGORY_INDEXING_PARITY_VERSION = '2026-09-22-v6-complete-category-hubs';

/** True for an intentionally filtered/list variant that must stay noindex. */
function go_verge_category_parity_is_filtered_request() {
	return function_exists( 'go_verge_indexing_is_filtered_discovery_request' ) && go_verge_indexing_is_filtered_discovery_request();
}

/** Return the canonical category slugs without technical/retired terms. */
function go_verge_category_parity_slugs() {
	if ( function_exists( 'go_verge_v7_canonical_category_slugs' ) ) {
		return array_values( array_unique( array_map( 'sanitize_title', go_verge_v7_canonical_category_slugs() ) ) );
	}
	return array(
		'games', 'dicas-e-guias', 'especiais', 'lancamentos', 'reviews',
		'entretenimento', 'anime-e-manga', 'criticas', 'doramas', 'filmes', 'musica', 'producoes-turcas', 'series', 'streaming',
		'ofertas', 'guias-de-compra', 'jogos-gratis', 'promocoes',
		'tecnologia', 'celulares', 'mobilidade', 'internet', 'hardware', 'notebooks', 'tvs-e-monitores', 'eletrodomesticos', 'casa-inteligente', 'wearables', 'apps-software', 'ia', 'ciencia', 'servico',
	);
}

/** Root slugs that are intentionally public editorial pillars. */
function go_verge_category_parity_root_slugs() {
	return function_exists( 'go_verge_v7_category_blueprint' )
		? array_values( array_map( 'sanitize_title', array_keys( go_verge_v7_category_blueprint() ) ) )
		: array( 'games', 'entretenimento', 'ofertas', 'tecnologia' );
}

/**
 * True when a category is an intentional editorial desk.
 *
 * The original V7 contract used a hard-coded child list. That kept taxonomy
 * noise out of Search, but it also meant a genuinely new desk could render
 * publicly while remaining excluded from robots/sitemaps until the next theme
 * release. Explicit blueprint destinations are durable hubs and stay indexable;
 * ad-hoc descendants become public from their first published story; free-form
 * top-level taxonomy noise stays excluded.
 */
function go_verge_category_parity_is_editorial_term( $term ) {
	if ( ! ( $term instanceof WP_Term ) || 'category' !== $term->taxonomy ) {
		return false;
	}
	$slug = sanitize_title( $term->slug );
	if ( '' === $slug || in_array( $slug, array( 'interno', 'sem-categoria', 'uncategorized', 'tudo' ), true ) ) {
		return false;
	}
	if ( function_exists( 'go_verge_search_redirected_category_slugs' ) && in_array( $slug, go_verge_search_redirected_category_slugs(), true ) ) {
		return false;
	}
	if ( in_array( $slug, go_verge_category_parity_slugs(), true ) ) {
		/* Explicit blueprint destinations are durable landing pages. They remain
		 * crawlable/indexable before the first story so navigation, canonicals and
		 * XML sitemaps never disagree about whether the category exists. */
		return true;
	}
	if ( (int) $term->count < 1 ) {
		return false;
	}
	$root_slugs = go_verge_category_parity_root_slugs();
	$ancestor_ids = array_map( 'absint', get_ancestors( (int) $term->term_id, 'category', 'taxonomy' ) );
	foreach ( $ancestor_ids as $ancestor_id ) {
		$ancestor = get_term( $ancestor_id, 'category' );
		if ( $ancestor instanceof WP_Term && in_array( sanitize_title( $ancestor->slug ), $root_slugs, true ) ) {
			return true;
		}
	}
	return false;
}

/** Is the current request one of the canonical editorial landing surfaces? */
function go_verge_category_parity_is_public_surface() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || is_404() || is_search() || go_verge_category_parity_is_filtered_request() ) {
		return false;
	}

	if ( is_category() ) {
		$term = get_queried_object();
		return $term instanceof WP_Term && go_verge_category_parity_is_editorial_term( $term );
	}

	/* Entretenimento e Tecnologia are Page-backed public pillars. */
	if ( is_page( array( 'entretenimento', 'tecnologia' ) ) ) {
		return true;
	}

	/* Games is served by the games post-type archive in the current architecture. */
	return is_post_type_archive( 'games' );
}

/** Theme-resolved, pagination-aware canonical for a canonical editorial surface. */
function go_verge_category_parity_canonical_url() {
	if ( ! go_verge_category_parity_is_public_surface() ) {
		return '';
	}
	if ( function_exists( 'go_verge_seo_canonical_url' ) ) {
		return (string) go_verge_seo_canonical_url();
	}

	$paged = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	if ( $paged > 1 ) {
		return esc_url_raw( get_pagenum_link( $paged ) );
	}
	if ( is_category() ) {
		$link = get_term_link( get_queried_object() );
		return is_wp_error( $link ) ? '' : esc_url_raw( $link );
	}
	if ( is_page() ) { return esc_url_raw( get_permalink( get_queried_object_id() ) ); }
	if ( is_post_type_archive( 'games' ) ) { return esc_url_raw( get_post_type_archive_link( 'games' ) ); }
	return '';
}

/** Keep Rank Math from reviving stale canonicals on any canonical desk. */
function go_verge_category_parity_rank_math_canonical( $canonical ) {
	$resolved = go_verge_category_parity_canonical_url();
	return $resolved ? $resolved : $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_category_parity_rank_math_canonical', 4200 );

/** Same contract if Yoast is used instead of Rank Math. */
function go_verge_category_parity_yoast_canonical( $canonical ) {
	$resolved = go_verge_category_parity_canonical_url();
	return $resolved ? $resolved : $canonical;
}
add_filter( 'wpseo_canonical', 'go_verge_category_parity_yoast_canonical', 4200 );

/** Canonical editorial surfaces must never inherit a stale noindex. */
function go_verge_category_parity_should_force_index() {
	if ( ! (int) get_option( 'blog_public' ) ) { return false; }
	if ( ! go_verge_category_parity_is_public_surface() ) {
		return false;
	}
	if ( is_category() ) {
		$term = get_queried_object();
		if ( ! ( $term instanceof WP_Term ) ) {
			return false;
		}
		$slug  = sanitize_title( $term->slug );
		$roots = function_exists( 'go_verge_v7_category_blueprint' ) ? array_keys( go_verge_v7_category_blueprint() ) : array( 'games', 'entretenimento', 'ofertas', 'tecnologia' );
		/* Canonical editorial categories are curated landing pages, not free-form
		 * taxonomy noise. Root and explicitly declared child hubs stay indexable so
		 * robots, canonicals and XML sitemaps share one stable contract. */
		return in_array( $slug, $roots, true ) || go_verge_category_parity_is_editorial_term( $term );
	}
	return true;
}

function go_verge_category_parity_wp_robots( $robots ) {
	if ( ! go_verge_category_parity_should_force_index() || ! is_array( $robots ) ) {
		return $robots;
	}
	unset( $robots['noindex'], $robots['nofollow'] );
	/* wp_robots() renders "key:value" for string values, so the numeric limits
	 * stay strings and the preview level is the bare value. */
	$robots['index']             = true;
	$robots['follow']            = true;
	$robots['max-image-preview'] = 'large';
	$robots['max-snippet']       = '-1';
	$robots['max-video-preview'] = '-1';
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_category_parity_wp_robots', 4200 );

/**
 * Rank Math prints its robots meta by imploding the array VALUES, so each value
 * must be the complete directive. Emitting the bare level here ("large") both
 * dropped max-image-preview:large from every canonical desk and added a
 * meaningless "large" token to the tag.
 */
function go_verge_category_parity_rank_math_robots( $robots ) {
	if ( ! go_verge_category_parity_should_force_index() || ! is_array( $robots ) ) {
		return $robots;
	}
	unset( $robots['noindex'], $robots['nofollow'] );
	$robots['index']             = 'index';
	$robots['follow']            = 'follow';
	$robots['max-image-preview'] = 'max-image-preview:large';
	$robots['max-snippet']       = 'max-snippet:-1';
	$robots['max-video-preview'] = 'max-video-preview:-1';
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_category_parity_rank_math_robots', 4200 );

/** Recursively detect a noindex directive in Rank Math metadata. */
function go_verge_category_parity_has_noindex( $value ) {
	if ( is_array( $value ) ) {
		foreach ( $value as $part ) {
			if ( go_verge_category_parity_has_noindex( $part ) ) {
				return true;
			}
		}
		return false;
	}
	return false !== strpos( strtolower( (string) $value ), 'noindex' );
}

/** Public URL for a category term after the parent-hub canonical filter. */
function go_verge_category_parity_term_url( $term ) {
	if ( ! ( $term instanceof WP_Term ) ) {
		return '';
	}
	$link = get_term_link( $term );
	return is_wp_error( $link ) ? '' : esc_url_raw( $link );
}

/** Remove only metadata capable of accidentally suppressing/canonicalizing a desk elsewhere. */
function go_verge_category_parity_clean_term_index_meta( $term ) {
	if ( ! ( $term instanceof WP_Term ) ) {
		return false;
	}
	$changed = false;
	$robots = get_term_meta( $term->term_id, 'rank_math_robots', true );
	if ( go_verge_category_parity_has_noindex( $robots ) ) {
		delete_term_meta( $term->term_id, 'rank_math_robots' );
		$changed = true;
	}

	$stored  = trim( (string) get_term_meta( $term->term_id, 'rank_math_canonical_url', true ) );
	$desired = go_verge_category_parity_term_url( $term );
	if ( $stored && $desired && untrailingslashit( $stored ) !== untrailingslashit( $desired ) ) {
		delete_term_meta( $term->term_id, 'rank_math_canonical_url' );
		$changed = true;
	}
	return $changed;
}

/** True when a term is one of the controlled editorial category destinations. */
function go_verge_category_parity_is_canonical_term( $term ) {
	if ( ! ( $term instanceof WP_Term ) || 'category' !== $term->taxonomy ) {
		return false;
	}
	return go_verge_category_parity_is_editorial_term( $term );
}

/**
 * Activate a canonical desk on its first published story.
 *
 * This is deliberately event-driven rather than a one-shot deployment repair.
 * New editorial categories can be created months after a theme release; they
 * must not wait for another release before stale Rank Math term metadata is
 * removed and the category becomes part of the crawl/indexing graph.
 */
function go_verge_category_parity_activate_term( $term_id ) {
	$term = get_term( absint( $term_id ), 'category' );
	if ( is_wp_error( $term ) || ! go_verge_category_parity_is_canonical_term( $term ) ) {
		return false;
	}

	if ( ! go_verge_category_parity_is_editorial_term( $term ) ) {
		return false;
	}

	$first_activation = '1' !== (string) get_term_meta( $term->term_id, '_go_category_indexing_active', true );
	$cleaned          = go_verge_category_parity_clean_term_index_meta( $term );
	if ( $first_activation ) {
		update_term_meta( $term->term_id, '_go_category_indexing_active', '1' );
	}

	if ( $first_activation || $cleaned ) {
		if ( function_exists( 'go_verge_smart_sitemap_bump' ) ) {
			go_verge_smart_sitemap_bump();
		}
		if ( function_exists( 'go_verge_smart_sitemap_record_touch' ) ) {
			go_verge_smart_sitemap_record_touch( 'categories' );
		}
		$url = go_verge_category_parity_term_url( $term );
		if ( $url ) {
			do_action( 'litespeed_purge_url', $url );
		}
	}
	return true;
}

/** Activate assigned desks when taxonomy changes on an already-published post. */
function go_verge_category_parity_on_set_object_terms( $object_id, $terms, $tt_ids, $taxonomy ) {
	unset( $terms, $tt_ids );
	if ( 'category' !== $taxonomy || 'post' !== get_post_type( $object_id ) || 'publish' !== get_post_status( $object_id ) ) {
		return;
	}
	foreach ( (array) wp_get_post_categories( $object_id ) as $term_id ) {
		go_verge_category_parity_activate_term( $term_id );
	}
}
add_action( 'set_object_terms', 'go_verge_category_parity_on_set_object_terms', 140, 4 );

/** Drafts commonly receive categories before publish; activate them at publish too. */
function go_verge_category_parity_on_transition( $new_status, $old_status, $post ) {
	if ( 'publish' !== $new_status || 'publish' === $old_status || ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	foreach ( (array) wp_get_post_categories( $post->ID ) as $term_id ) {
		go_verge_category_parity_activate_term( $term_id );
	}
}
add_action( 'transition_post_status', 'go_verge_category_parity_on_transition', 140, 3 );

/** Keep a newly-created/edited canonical desk synchronized when it already has content. */
function go_verge_category_parity_on_term_change( $term_id ) {
	go_verge_category_parity_activate_term( $term_id );
}
add_action( 'created_category', 'go_verge_category_parity_on_term_change', 140 );
add_action( 'edited_category', 'go_verge_category_parity_on_term_change', 140 );

/** Repair the complete V7 taxonomy tree, not only Technology. */
function go_verge_category_parity_provision_tree() {
	if ( ! function_exists( 'go_verge_v7_category_blueprint' ) || ! function_exists( 'go_verge_v7_ensure_term' ) ) {
		return;
	}
	foreach ( go_verge_v7_category_blueprint() as $root_slug => $root ) {
		$root_term = go_verge_v7_ensure_term( 'category', $root_slug, $root['name'], 0 );
		if ( ! ( $root_term instanceof WP_Term ) ) {
			continue;
		}
		foreach ( (array) $root['children'] as $child_slug => $child_name ) {
			go_verge_v7_ensure_term( 'category', $child_slug, $child_name, (int) $root_term->term_id );
		}
	}
}

/** Clear sitemap/page caches after a structural indexing repair. */
function go_verge_category_parity_purge_indexing_caches() {
	if ( defined( 'GO_VERGE_NEWS_SITEMAP_TRANSIENT' ) ) {
		delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
	}
	if ( defined( 'GO_VERGE_SMART_SITEMAP_EPOCH_OPTION' ) && function_exists( 'go_verge_smart_sitemap_epoch' ) ) {
		update_option( GO_VERGE_SMART_SITEMAP_EPOCH_OPTION, go_verge_smart_sitemap_epoch() + 1, false );
	}
	update_option( 'go_smart_sitemap_last_change', time(), false );
	do_action( 'litespeed_purge_all' );
}

/** One-time deployment repair across all canonical editorial categories. */
function go_verge_category_parity_deploy() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) ) {
		return;
	}
	if ( GO_VERGE_CATEGORY_INDEXING_PARITY_VERSION === (string) get_option( 'go_verge_category_indexing_parity_version', '' ) ) {
		return;
	}

	/* Synchronize the controlled tree first so a newly-added section can be
	 * linked and indexed immediately after the theme update. */
	go_verge_category_parity_provision_tree();

	$root_slugs = array_keys( go_verge_v7_category_blueprint() );
	foreach ( go_verge_category_parity_slugs() as $slug ) {
		$term = get_term_by( 'slug', $slug, 'category' );
		if ( ! ( $term instanceof WP_Term ) ) {
			continue;
		}
		/* Controlled category hubs are intentional public destinations, including
		 * those waiting for their first story. Clear stale noindex/canonical state. */
		go_verge_category_parity_clean_term_index_meta( $term );
	}

	/* Page-backed pillars can also carry stale Rank Math noindex/canonical meta. */
	foreach ( array( 'tecnologia', 'entretenimento' ) as $page_slug ) {
		$page = get_page_by_path( $page_slug, OBJECT, 'page' );
		if ( ! ( $page instanceof WP_Post ) ) {
			continue;
		}
		if ( go_verge_category_parity_has_noindex( get_post_meta( $page->ID, 'rank_math_robots', true ) ) ) {
			delete_post_meta( $page->ID, 'rank_math_robots' );
		}
		$stored  = trim( (string) get_post_meta( $page->ID, 'rank_math_canonical_url', true ) );
		$desired = get_permalink( $page->ID );
		if ( $stored && $desired && untrailingslashit( $stored ) !== untrailingslashit( $desired ) ) {
			delete_post_meta( $page->ID, 'rank_math_canonical_url' );
		}
	}

	go_verge_category_parity_purge_indexing_caches();
	update_option( 'go_verge_category_indexing_parity_version', GO_VERGE_CATEGORY_INDEXING_PARITY_VERSION, false );
}
add_action( 'admin_init', 'go_verge_category_parity_deploy', 74 );
