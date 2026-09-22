<?php
/**
 * Technology indexing hardening.
 *
 * Consolidates the retired combined "Software e IA" desk into the canonical
 * V7 technology taxonomy and prevents duplicate archive URLs from competing in
 * Search/Google News. Existing stories are moved conservatively: obvious AI
 * coverage goes to /tecnologia/ia/; the remaining combined-desk stories go to
 * /tecnologia/apps-software/. The story permalink/body never changes.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

const GO_VERGE_TECH_INDEXING_HARDENING_VERSION = '2026-09-10-v1';

/** Canonical Technology child slugs from the V7 blueprint. */
function go_verge_technology_canonical_children() {
	$blueprint = function_exists( 'go_verge_v7_category_blueprint' ) ? go_verge_v7_category_blueprint() : array();
	$children  = isset( $blueprint['tecnologia']['children'] ) && is_array( $blueprint['tecnologia']['children'] )
		? array_keys( $blueprint['tecnologia']['children'] )
		: array( 'apps-software', 'celulares', 'ciencia', 'hardware', 'ia', 'notebooks', 'tvs-e-monitores' );

	return array_values( array_unique( array_map( 'sanitize_title', $children ) ) );
}

/**
 * Return the canonical Technology desk for a legacy Software e IA story.
 *
 * Existing canonical Technology child assignments always win. Otherwise only
 * strong AI product/model/company signals select IA; generic software remains
 * in Apps e Software. This avoids turning Windows/app stories into AI content.
 */
function go_verge_technology_legacy_story_target( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return 'apps-software';
	}

	$slugs = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
	$slugs = is_wp_error( $slugs ) ? array() : array_map( 'sanitize_title', (array) $slugs );
	$canonical_children = go_verge_technology_canonical_children();

	/* Respect a real canonical child already attached to the story. */
	$priority = function_exists( 'go_verge_v7_category_priority' ) ? go_verge_v7_category_priority() : $canonical_children;
	foreach ( $priority as $slug ) {
		$slug = sanitize_title( $slug );
		if ( in_array( $slug, $canonical_children, true ) && in_array( $slug, $slugs, true ) ) {
			return $slug;
		}
	}

	$haystack = implode( ' ', array_filter( array(
		(string) get_the_title( $post_id ),
		(string) get_post_field( 'post_name', $post_id ),
		(string) get_post_field( 'post_excerpt', $post_id ),
		(string) get_post_meta( $post_id, 'rank_math_focus_keyword', true ),
	) ) );
	$haystack = strtolower( remove_accents( wp_strip_all_tags( $haystack ) ) );
	$haystack = preg_replace( '/\s+/u', ' ', $haystack );

	$ai_signal = '/(?:^|[^a-z0-9])(?:chatgpt|openai|gemini|claude|anthropic|copilot|deepseek|perplexity|midjourney|gpt[ -]?[0-9a-z.]+|llm|inteligencia artificial|ia generativa|modelo(?:s)? de ia|agente(?:s)? de ia)(?:$|[^a-z0-9])/u';
	return preg_match( $ai_signal, (string) $haystack ) ? 'ia' : 'apps-software';
}

/** Reclassify one post away from the retired combined desk. */
function go_verge_technology_repair_legacy_story( $post_id ) {
	static $repairing = array();

	$post_id = absint( $post_id );
	if ( ! $post_id || isset( $repairing[ $post_id ] ) || 'post' !== get_post_type( $post_id ) || ! has_term( 'software-e-ia', 'category', $post_id ) ) {
		return false;
	}

	$repairing[ $post_id ] = true;
	$target_slug = go_verge_technology_legacy_story_target( $post_id );
	$target      = get_term_by( 'slug', $target_slug, 'category' );

	if ( ! ( $target instanceof WP_Term ) && function_exists( 'go_verge_v7_ensure_term' ) ) {
		$blueprint = go_verge_v7_category_blueprint();
		$root      = get_term_by( 'slug', 'tecnologia', 'category' );
		$name      = isset( $blueprint['tecnologia']['children'][ $target_slug ] ) ? $blueprint['tecnologia']['children'][ $target_slug ] : $target_slug;
		$parent_id = $root instanceof WP_Term ? (int) $root->term_id : 0;
		go_verge_v7_ensure_term( 'category', $target_slug, $name, $parent_id );
		$target = get_term_by( 'slug', $target_slug, 'category' );
	}

	if ( $target instanceof WP_Term ) {
		/* V7's contract is exactly one editorial category. This also detaches the
		 * retired combined term and any stale root relationship. */
		wp_set_post_terms( $post_id, array( (int) $target->term_id ), 'category', false );
		if ( function_exists( 'go_verge_v7_normalize_post_architecture' ) ) {
			go_verge_v7_normalize_post_architecture( $post_id );
		}
		delete_transient( defined( 'GO_VERGE_NEWS_SITEMAP_TRANSIENT' ) ? GO_VERGE_NEWS_SITEMAP_TRANSIENT : 'go_verge_news_sitemap_v5' );
		unset( $repairing[ $post_id ] );
		return true;
	}

	unset( $repairing[ $post_id ] );
	return false;
}

/** Classic editor / non-REST save safety net. */
function go_verge_technology_repair_legacy_story_on_save( $post_id, $post, $update ) {
	unset( $update );
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( defined( 'REST_REQUEST' ) && REST_REQUEST ) {
		return;
	}
	go_verge_technology_repair_legacy_story( $post_id );
}
add_action( 'save_post_post', 'go_verge_technology_repair_legacy_story_on_save', 155, 3 );

/** Gutenberg saves category relationships before this hook. */
function go_verge_technology_repair_legacy_story_after_rest( $post, $request, $creating ) {
	unset( $request, $creating );
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || ! current_user_can( 'edit_post', $post->ID ) ) {
		return;
	}
	go_verge_technology_repair_legacy_story( $post->ID );
}
add_action( 'rest_after_insert_post', 'go_verge_technology_repair_legacy_story_after_rest', 110, 3 );

/**
 * Bounded repair of existing stories. Runs only in wp-admin and keeps each
 * request small; subsequent admin requests continue until the old desk is empty.
 */
function go_verge_technology_repair_existing_legacy_stories() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) ) {
		return;
	}
	if ( GO_VERGE_TECH_INDEXING_HARDENING_VERSION === (string) get_option( 'go_verge_technology_taxonomy_repair_version', '' ) ) {
		return;
	}

	$legacy = get_term_by( 'slug', 'software-e-ia', 'category' );
	if ( ! ( $legacy instanceof WP_Term ) ) {
		update_option( 'go_verge_technology_taxonomy_repair_version', GO_VERGE_TECH_INDEXING_HARDENING_VERSION, false );
		return;
	}

	$ids = get_posts( array(
		'post_type'              => 'post',
		'post_status'            => array( 'publish', 'future', 'draft', 'pending', 'private' ),
		'posts_per_page'         => 100,
		'fields'                 => 'ids',
		'orderby'                => 'ID',
		'order'                  => 'ASC',
		'no_found_rows'          => true,
		'update_post_meta_cache' => false,
		'update_post_term_cache' => false,
		'tax_query'              => array(
			array(
				'taxonomy' => 'category',
				'field'    => 'term_id',
				'terms'    => array( (int) $legacy->term_id ),
			),
		),
	) );

	foreach ( array_map( 'absint', (array) $ids ) as $post_id ) {
		go_verge_technology_repair_legacy_story( $post_id );
	}

	/* Mark complete only after a fresh count says there is nothing left. */
	$legacy = get_term_by( 'slug', 'software-e-ia', 'category' );
	if ( ! ( $legacy instanceof WP_Term ) || 0 === (int) $legacy->count ) {
		update_option( 'go_verge_technology_taxonomy_repair_version', GO_VERGE_TECH_INDEXING_HARDENING_VERSION, false );
	}
}
add_action( 'admin_init', 'go_verge_technology_repair_existing_legacy_stories', 72 );

/** Never generate fresh internal links to the retired combined archive. */
function go_verge_technology_legacy_term_link( $url, $term, $taxonomy ) {
	if ( 'category' === $taxonomy && $term instanceof WP_Term && 'software-e-ia' === sanitize_title( $term->slug ) ) {
		return home_url( '/tecnologia/' );
	}
	return $url;
}
add_filter( 'term_link', 'go_verge_technology_legacy_term_link', 120, 3 );

/**
 * Permanent one-hop redirects for every known public form of the old archive.
 * The combined archive has no honest 1:1 replacement after Software and IA were
 * split, so the Technology pillar is the correct consolidation destination.
 */
function go_verge_technology_legacy_archive_redirect() {
	if ( is_admin() || wp_doing_ajax() || is_feed() ) {
		return;
	}
	$method = isset( $_SERVER['REQUEST_METHOD'] ) ? strtoupper( (string) $_SERVER['REQUEST_METHOD'] ) : 'GET';
	if ( ! in_array( $method, array( 'GET', 'HEAD' ), true ) ) {
		return;
	}

	$uri  = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
	$path = trim( (string) wp_parse_url( $uri, PHP_URL_PATH ), '/' );
	if ( ! $path ) {
		return;
	}

	if ( preg_match( '#^(?:category/)?(?:tecnologia/)?software-e-ia(?:/page/[1-9][0-9]*)?/?$#i', $path ) ) {
		wp_safe_redirect( home_url( '/tecnologia/' ), 301, 'Overdrive Technology taxonomy consolidation' );
		exit;
	}
}
add_action( 'template_redirect', 'go_verge_technology_legacy_archive_redirect', -10 );

/** One-time deployment invalidation for sitemap caches affected by this repair. */
function go_verge_technology_indexing_deploy_invalidation() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) ) {
		return;
	}
	if ( GO_VERGE_TECH_INDEXING_HARDENING_VERSION === (string) get_option( 'go_verge_technology_indexing_hardening_version', '' ) ) {
		return;
	}

	/* Repair the visible Technology taxonomy even on a normal theme update
	 * (without requiring deactivate/reactivate). This renames stale labels such
	 * as `celulares` = "Mobile" and restores the canonical parent tree. */
	if ( function_exists( 'go_verge_v7_category_blueprint' ) && function_exists( 'go_verge_v7_ensure_term' ) ) {
		$blueprint = go_verge_v7_category_blueprint();
		if ( isset( $blueprint['tecnologia'] ) ) {
			$root = go_verge_v7_ensure_term( 'category', 'tecnologia', $blueprint['tecnologia']['name'], 0 );
			if ( $root instanceof WP_Term ) {
				foreach ( (array) $blueprint['tecnologia']['children'] as $slug => $name ) {
					go_verge_v7_ensure_term( 'category', $slug, $name, (int) $root->term_id );
				}
			}
		}
	}

	/* An old Rank Math term title can keep Google's snippet saying "Software e
	 * IA" even after the canonical IA term has been renamed. Clear only that
	 * known stale value; unrelated manual SEO metadata is preserved. */
	$ia_term = get_term_by( 'slug', 'ia', 'category' );
	if ( $ia_term instanceof WP_Term ) {
		foreach ( array( 'rank_math_title', 'rank_math_description' ) as $meta_key ) {
			$value = (string) get_term_meta( $ia_term->term_id, $meta_key, true );
			$normalized = strtolower( remove_accents( wp_strip_all_tags( $value ) ) );
			if ( false !== strpos( $normalized, 'software e ia' ) ) {
				delete_term_meta( $ia_term->term_id, $meta_key );
			}
		}
	}

	if ( defined( 'GO_VERGE_NEWS_SITEMAP_TRANSIENT' ) ) {
		delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
	}
	if ( defined( 'GO_VERGE_SMART_SITEMAP_EPOCH_OPTION' ) && function_exists( 'go_verge_smart_sitemap_epoch' ) ) {
		update_option( GO_VERGE_SMART_SITEMAP_EPOCH_OPTION, go_verge_smart_sitemap_epoch() + 1, false );
	}
	update_option( 'go_smart_sitemap_last_change', time(), false );
	/* Navigation and category chips are commonly page-cached on production. */
	do_action( 'litespeed_purge_all' );
	update_option( 'go_verge_technology_indexing_hardening_version', GO_VERGE_TECH_INDEXING_HARDENING_VERSION, false );
}
add_action( 'admin_init', 'go_verge_technology_indexing_deploy_invalidation', 70 );
