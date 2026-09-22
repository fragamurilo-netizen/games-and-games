<?php
/**
 * Canonical tag consolidation.
 *
 * Prevents equivalent tag archives from splitting crawl signals and internal
 * authority. Existing relationships are merged into the canonical term and
 * legacy archive URLs keep a permanent redirect.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Alias slug => canonical tag data.
 *
 * Keep this list deliberately explicit. Broad fuzzy matching can merge terms
 * that editors intended to keep separate.
 *
 * @return array<string,array{slug:string,name:string}>
 */
function go_verge_tag_alias_map() {
	return (array) apply_filters(
		'go_verge_tag_alias_map',
		array(
			'playstation-5' => array( 'slug' => 'ps5', 'name' => 'PS5' ),
			'playstation5'  => array( 'slug' => 'ps5', 'name' => 'PS5' ),
			'ps-5'          => array( 'slug' => 'ps5', 'name' => 'PS5' ),
			'cdprojektred'   => array( 'slug' => 'cd-projekt-red', 'name' => 'CD Projekt Red' ),
			'cdprojekt-red'  => array( 'slug' => 'cd-projekt-red', 'name' => 'CD Projekt Red' ),
			'cd-project-red' => array( 'slug' => 'cd-projekt-red', 'name' => 'CD Projekt Red' ),
			'nintendo-switch2' => array( 'slug' => 'nintendo-switch-2', 'name' => 'Nintendo Switch 2' ),
			'switch2'          => array( 'slug' => 'nintendo-switch-2', 'name' => 'Nintendo Switch 2' ),
		)
	);
}

/** Return canonical data for a tag slug, or null when it is already canonical. */
function go_verge_tag_alias_target( $slug ) {
	$slug = sanitize_title( (string) $slug );
	$map  = go_verge_tag_alias_map();
	if ( isset( $map[ $slug ] ) && is_array( $map[ $slug ] ) ) { return $map[ $slug ]; }
	$dynamic = get_option( 'go_verge_tag_dynamic_alias_redirects', array() );
	if ( is_array( $dynamic ) && ! empty( $dynamic[ $slug ]['slug'] ) ) { return $dynamic[ $slug ]; }
	return null;
}

/** Conservative key: only accents, spaces and punctuation are ignored. */
function go_verge_tag_duplicate_key( $value ) {
	$value = strtolower( remove_accents( html_entity_decode( wp_strip_all_tags( (string) $value ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) ) );
	return preg_replace( '/[^a-z0-9]+/', '', $value );
}

/** Whether a term/slug is one of the retired aliases. */
function go_verge_is_tag_alias( $term_or_slug ) {
	$slug = $term_or_slug instanceof WP_Term ? $term_or_slug->slug : (string) $term_or_slug;
	return null !== go_verge_tag_alias_target( $slug );
}

/**
 * Canonicalize newly inserted terms before WordPress stores them.
 *
 * This prevents editors and imports from recreating a retired alias after the
 * one-time relationship migration has run.
 */
function go_verge_canonicalize_inserted_tag( $data, $taxonomy, $args ) {
	if ( 'post_tag' !== $taxonomy || ! is_array( $data ) ) {
		return $data;
	}

	$candidate = ! empty( $data['slug'] ) ? $data['slug'] : ( $data['name'] ?? '' );
	$target    = go_verge_tag_alias_target( $candidate );
	if ( ! $target ) {
		return $data;
	}

	$data['slug'] = sanitize_title( $target['slug'] );
	$data['name'] = sanitize_text_field( $target['name'] );
	return $data;
}
add_filter( 'wp_insert_term_data', 'go_verge_canonicalize_inserted_tag', 20, 3 );

/**
 * Merge relationships and descriptions from aliases into canonical terms.
 * Runs once per version in wp-admin and is safe to repeat.
 */
function go_verge_consolidate_equivalent_tags() {
	if ( ! taxonomy_exists( 'post_tag' ) || ! current_user_can( 'manage_categories' ) ) {
		return;
	}

	$version = '2026-07-17-3';
	if ( $version === get_option( 'go_verge_tag_consolidation_version' ) ) {
		return;
	}

	foreach ( go_verge_tag_alias_map() as $alias_slug => $target ) {
		$alias = get_term_by( 'slug', $alias_slug, 'post_tag' );
		if ( ! ( $alias instanceof WP_Term ) ) {
			continue;
		}

		$canonical_slug = sanitize_title( $target['slug'] );
		$canonical      = get_term_by( 'slug', $canonical_slug, 'post_tag' );

		if ( $canonical instanceof WP_Term && (int) $canonical->term_id !== (int) $alias->term_id ) {
			$object_ids = get_objects_in_term( (int) $alias->term_id, 'post_tag' );
			if ( ! is_wp_error( $object_ids ) ) {
				foreach ( array_map( 'absint', (array) $object_ids ) as $object_id ) {
					wp_set_object_terms( $object_id, array( (int) $canonical->term_id ), 'post_tag', true );
					wp_remove_object_terms( $object_id, array( (int) $alias->term_id ), 'post_tag' );
				}
			}

			if ( '' === trim( (string) $canonical->description ) && '' !== trim( (string) $alias->description ) ) {
				wp_update_term( (int) $canonical->term_id, 'post_tag', array( 'description' => $alias->description ) );
			}

			wp_delete_term( (int) $alias->term_id, 'post_tag' );
		} else {
			wp_update_term(
				(int) $alias->term_id,
				'post_tag',
				array(
					'slug' => $canonical_slug,
					'name' => sanitize_text_field( $target['name'] ),
				)
			);
		}
	}


	/* Merge only truly equivalent spellings (case/accent/punctuation/spacing).
	 * No semantic/fuzzy guessing is used, so "Xbox" and "Xbox Series" remain
	 * separate. The most-used term wins and old slugs keep 301 redirects. */
	$all_tags = get_terms( array( 'taxonomy' => 'post_tag', 'hide_empty' => false ) );
	$groups   = array();
	if ( ! is_wp_error( $all_tags ) ) {
		foreach ( $all_tags as $term ) {
			$key = go_verge_tag_duplicate_key( $term->name );
			if ( strlen( $key ) < 3 || preg_match( '/^\d+$/', $key ) ) { continue; }
			$groups[ $key ][] = $term;
		}
	}
	$dynamic_redirects = get_option( 'go_verge_tag_dynamic_alias_redirects', array() );
	$dynamic_redirects = is_array( $dynamic_redirects ) ? $dynamic_redirects : array();
	foreach ( $groups as $terms ) {
		if ( count( $terms ) < 2 ) { continue; }
		usort( $terms, static function ( $a, $b ) {
			if ( (int) $a->count !== (int) $b->count ) { return (int) $b->count <=> (int) $a->count; }
			if ( strlen( $a->slug ) !== strlen( $b->slug ) ) { return strlen( $a->slug ) <=> strlen( $b->slug ); }
			return (int) $a->term_id <=> (int) $b->term_id;
		} );
		$canonical = array_shift( $terms );
		foreach ( $terms as $alias ) {
			if ( (int) $alias->term_id === (int) $canonical->term_id ) { continue; }
			$object_ids = get_objects_in_term( (int) $alias->term_id, 'post_tag' );
			if ( ! is_wp_error( $object_ids ) ) {
				foreach ( array_map( 'absint', (array) $object_ids ) as $object_id ) {
					wp_set_object_terms( $object_id, array( (int) $canonical->term_id ), 'post_tag', true );
					wp_remove_object_terms( $object_id, array( (int) $alias->term_id ), 'post_tag' );
				}
			}
			$dynamic_redirects[ $alias->slug ] = array( 'slug' => $canonical->slug, 'name' => $canonical->name );
			wp_delete_term( (int) $alias->term_id, 'post_tag' );
		}
	}
	update_option( 'go_verge_tag_dynamic_alias_redirects', $dynamic_redirects, false );

	delete_transient( 'go_verge_thin_tag_ids_v2' );
	if ( function_exists( 'go_verge_internal_link_bust' ) ) {
		go_verge_internal_link_bust();
	}
	update_option( 'go_verge_tag_consolidation_version', $version, false );
}
add_action( 'admin_init', 'go_verge_consolidate_equivalent_tags', 30 );

/**
 * Redirect legacy tag URLs even after their terms have been merged/deleted.
 */
function go_verge_redirect_tag_aliases() {
	if ( is_admin() || wp_doing_ajax() || is_feed() ) {
		return;
	}

	$requested_slug = sanitize_title( (string) get_query_var( 'tag' ) );
	$target         = go_verge_tag_alias_target( $requested_slug );
	if ( ! $target ) {
		return;
	}

	$canonical = get_term_by( 'slug', sanitize_title( $target['slug'] ), 'post_tag' );
	$url       = $canonical instanceof WP_Term ? get_term_link( $canonical ) : home_url( '/tag/' . sanitize_title( $target['slug'] ) . '/' );
	if ( is_wp_error( $url ) || ! $url ) {
		return;
	}

	wp_safe_redirect( $url, 301, 'Overdrive tag consolidation' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_tag_aliases', 1 );

/** Point any still-existing alias term link at the canonical archive. */
function go_verge_canonical_tag_term_link( $url, $term, $taxonomy ) {
	if ( 'post_tag' !== $taxonomy || ! ( $term instanceof WP_Term ) ) {
		return $url;
	}
	$target = go_verge_tag_alias_target( $term->slug );
	if ( ! $target ) {
		return $url;
	}
	$canonical = get_term_by( 'slug', sanitize_title( $target['slug'] ), 'post_tag' );
	if ( $canonical instanceof WP_Term && (int) $canonical->term_id !== (int) $term->term_id ) {
		$link = get_term_link( $canonical );
		return is_wp_error( $link ) ? $url : $link;
	}
	return home_url( '/tag/' . sanitize_title( $target['slug'] ) . '/' );
}
add_filter( 'term_link', 'go_verge_canonical_tag_term_link', 20, 3 );

/**
 * Prefer an entity hub over a tag archive when both represent the same topic.
 *
 * @return array{url:string,type:string}|null
 */
function go_verge_tag_preferred_destination( $term ) {
	if ( ! ( $term instanceof WP_Term ) || 'post_tag' !== $term->taxonomy ) {
		return null;
	}

	$slug   = $term->slug;
	$target = go_verge_tag_alias_target( $slug );
	if ( $target ) {
		$slug = sanitize_title( $target['slug'] );
	}

	$entity_aliases = (array) apply_filters(
		'go_verge_tag_entity_hub_map',
		array(
			'ps5'            => 'playstation',
			'cd-projekt-red' => 'cd-projekt-red',
		)
	);
	$entity_slug = isset( $entity_aliases[ $slug ] ) ? sanitize_title( $entity_aliases[ $slug ] ) : $slug;

	if ( post_type_exists( 'go_entity' ) ) {
		$entity = get_page_by_path( $entity_slug, OBJECT, 'go_entity' );
		if ( $entity instanceof WP_Post && 'publish' === $entity->post_status ) {
			return array( 'url' => get_permalink( $entity ), 'type' => 'hub' );
		}
	}

	$canonical = get_term_by( 'slug', $slug, 'post_tag' );
	if ( $canonical instanceof WP_Term ) {
		$url = get_term_link( $canonical );
		if ( ! is_wp_error( $url ) ) {
			return array( 'url' => $url, 'type' => 'taxonomy' );
		}
	}

	return array( 'url' => home_url( '/tag/' . $slug . '/' ), 'type' => 'taxonomy' );
}
