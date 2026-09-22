<?php
/** Keep existing editorial relationships and URLs intact across theme updates. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
require_once __DIR__ . '/editorial-structure.php';

/**
 * The old maintenance jobs mutate existing terms/relationships. Their functions
 * remain available to deliberate maintenance tooling; ordinary boot and queued
 * cron events must not run them as a side effect of this release.
 */
function go_verge_editorial_preserved_legacy_hooks() {
	return array(
		array( 'after_switch_theme', 'go_verge_v9_provision_vocabulary_once', 24 ),
		array( 'admin_init', 'go_verge_v9_architecture_screen_provision', 24 ),
		array( 'admin_init', 'go_verge_v24_consolidate_platform_terms', 28 ),
		array( 'admin_init', 'go_verge_consolidate_guides_categories', 31 ),
		array( 'admin_init', 'go_verge_consolidate_entertainment_categories', 32 ),
		array( 'admin_init', 'go_verge_v25_migrate_final_explicado', 34 ),
		array( 'admin_init', 'go_verge_v3152_prune_invalid_content_types', 36 ),
		array( 'admin_init', 'go_verge_v3152_repair_content_type_posts', 37 ),
		array( 'admin_init', 'go_verge_v3153_seed_architecture_jobs', 42 ),
		array( 'admin_init', 'go_verge_technology_indexing_deploy_invalidation', 70 ),
		array( 'admin_init', 'go_verge_technology_repair_existing_legacy_stories', 72 ),
		array( 'go_verge_v3153_arch_terms_batch', 'go_verge_v3153_arch_terms_batch', 10 ),
		array( 'go_verge_v3153_arch_cleanup_batch', 'go_verge_v7_cleanup_existing_posts_batch', 10 ),
		/* These were legacy repairs on save, separate from normal publishing. */
		array( 'save_post_post', 'go_verge_route_saved_entertainment_post', 50 ),
		array( 'save_post_post', 'go_verge_technology_repair_legacy_story_on_save', 155 ),
		array( 'rest_after_insert_post', 'go_verge_technology_repair_legacy_story_after_rest', 110 ),
		array( 'transition_post_status', 'go_verge_v7_promote_legacy_tag_to_entity', 30 ),
		array( 'save_post_productions', 'go_verge_v7_promote_legacy_tag_to_production', 160 ),
	);
}

function go_verge_editorial_preservation_enabled() { return true; }

/** Detach only the listed jobs; retain registration, publishing and redirects. */
function go_verge_editorial_preserve_existing_classification() {
	foreach ( go_verge_editorial_preserved_legacy_hooks() as $hook ) {
		remove_action( $hook[0], $hook[1], $hook[2] );
	}
}
go_verge_editorial_preserve_existing_classification();
add_action( 'after_setup_theme', 'go_verge_editorial_preserve_existing_classification', PHP_INT_MAX );

/**
 * Create only absent vocabulary terms, never rename/reparent a stored term or
 * attach categories/types to any post. This replaces the old switch provisioner
 * and also makes a missing controlled vocabulary available to a fresh editor.
 */
function go_verge_editorial_provision_missing_terms() {
	if ( ! current_user_can( 'manage_categories' ) || ! function_exists( 'go_verge_v7_vocabularies' ) ) { return; }
	$configs = go_verge_v7_vocabularies();
	$taxonomies = array_values( array_filter( array_merge( array( 'category' ), array_keys( $configs ) ), 'taxonomy_exists' ) );
	if ( ! $taxonomies ) { return; }
	$terms = get_terms( array( 'taxonomy' => $taxonomies, 'hide_empty' => false, 'update_term_meta_cache' => false ) );
	if ( is_wp_error( $terms ) ) { return; }
	$existing = array();
	foreach ( (array) $terms as $term ) {
		if ( $term instanceof WP_Term ) { $existing[ $term->taxonomy ][ $term->slug ] = (int) $term->term_id; }
	}
	$ensure = static function ( $taxonomy, $slug, $name, $parent = 0 ) use ( &$existing ) {
		if ( isset( $existing[ $taxonomy ][ $slug ] ) ) { return $existing[ $taxonomy ][ $slug ]; }
		$created = wp_insert_term( $name, $taxonomy, array( 'slug' => $slug, 'parent' => absint( $parent ) ) );
		if ( is_wp_error( $created ) || empty( $created['term_id'] ) ) { return 0; }
		$existing[ $taxonomy ][ $slug ] = (int) $created['term_id'];
		return (int) $created['term_id'];
	};
	if ( in_array( 'category', $taxonomies, true ) ) {
		foreach ( go_verge_editorial_category_blueprint() as $slug => $root ) {
			$parent = $ensure( 'category', $slug, $root['name'] );
			if ( ! $parent ) { continue; }
			foreach ( (array) $root['children'] as $child_slug => $name ) { $ensure( 'category', $child_slug, $name, $parent ); }
		}
	}
	foreach ( $configs as $taxonomy => $config ) {
		if ( ! in_array( $taxonomy, $taxonomies, true ) ) { continue; }
		foreach ( (array) $config['terms'] as $slug => $name ) { $ensure( $taxonomy, $slug, $name ); }
	}
}
add_action( 'after_switch_theme', 'go_verge_editorial_provision_missing_terms', 24 );
add_action( 'load-post-new.php', 'go_verge_editorial_provision_missing_terms', 24 );
add_action( 'load-post.php', 'go_verge_editorial_provision_missing_terms', 24 );
