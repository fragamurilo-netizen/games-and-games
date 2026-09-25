<?php
/**
 * Overdrive V21 — topic hubs, fluid navigation and canonical publisher entity.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Canonical public topic URL without inventing taxonomy terms. */
function go_verge_v21_topic_hub_url( $label ) {
	$label = trim( wp_strip_all_tags( (string) $label ) );
	if ( '' === $label ) { return home_url( '/' ); }
	$slug = sanitize_title( $label );
	/* V47: Assunto is the reader-facing concept, not a second public object.
	 * When the same concept already has a Production/Game/Entity/Service/etc.
	 * hub, every generated subject link goes straight to that canonical page. */
	if ( function_exists( 'go_verge_v36_topic_destination' ) ) {
		$destination = go_verge_v36_topic_destination( $slug );
		if ( is_array( $destination ) && ! empty( $destination['url'] ) ) {
			return esc_url_raw( $destination['url'] );
		}
	}
	return home_url( user_trailingslashit( 'assunto/' . $slug ) );
}

/** Canonical URL for one page in a generic topic sequence. */
function go_verge_v44_topic_page_url( $label, $page = 1 ) {
	$page = max( 1, absint( $page ) );
	$base = go_verge_v21_topic_hub_url( $label );
	if ( 1 === $page ) { return $base; }
	global $wp_rewrite;
	$pagination_base = ( $wp_rewrite instanceof WP_Rewrite && ! empty( $wp_rewrite->pagination_base ) ) ? $wp_rewrite->pagination_base : 'page';
	return trailingslashit( $base ) . user_trailingslashit( trim( (string) $pagination_base, '/' ) . '/' . $page );
}

/** Register clean /assunto/{slug}/ routes, including real pagination. */
function go_verge_v21_topic_rewrite() {
	global $wp_rewrite;
	$pagination_base = ( $wp_rewrite instanceof WP_Rewrite && ! empty( $wp_rewrite->pagination_base ) ) ? $wp_rewrite->pagination_base : 'page';
	$pagination_base = preg_quote( trim( (string) $pagination_base, '/' ), '#' );

	/* Put the paged rule first so /assunto/farah/page/2/ is not swallowed by
	 * the generic topic route or treated as a missing WordPress object. */
	add_rewrite_rule( '^assunto/([^/]+)/' . $pagination_base . '/([0-9]{1,})/?$', 'index.php?go_topic=$matches[1]&paged=$matches[2]', 'top' );
	add_rewrite_rule( '^assunto/([^/]+)/?$', 'index.php?go_topic=$matches[1]', 'top' );
}
add_action( 'init', 'go_verge_v21_topic_rewrite', 12 );
add_filter( 'query_vars', static function ( $vars ) { $vars[] = 'go_topic'; return $vars; } );

/** Flush only once for this build, never on normal front-end requests. */
function go_verge_v21_maybe_flush_rewrite() {
	if ( get_option( 'go_verge_topic_rewrite_v21' ) === GO_VERGE_VERSION ) { return; }
	go_verge_v21_topic_rewrite();
	go_verge_flush_rewrite_rules_once_per_request();
	update_option( 'go_verge_topic_rewrite_v21', GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_v21_maybe_flush_rewrite', 99 );

function go_verge_v21_is_topic_hub() {
	return '' !== sanitize_title( (string) get_query_var( 'go_topic' ) );
}

/** One comparison key shared with entity intelligence when available. */
function go_verge_v36_topic_key( $value ) {
	return function_exists( 'go_verge_v27_entity_key' )
		? go_verge_v27_entity_key( $value )
		: sanitize_title( remove_accents( (string) $value ) );
}

/** Find a published catalogue object by slug or normalized exact title. */
function go_verge_v36_topic_named_post( $slug, $post_type ) {
	$slug = sanitize_title( (string) $slug );
	if ( ! $slug || ! post_type_exists( $post_type ) ) { return null; }

	$direct = get_page_by_path( $slug, OBJECT, $post_type );
	if ( $direct instanceof WP_Post && 'publish' === $direct->post_status ) { return $direct; }

	$term  = get_term_by( 'slug', $slug, 'post_tag' );
	$label = $term instanceof WP_Term ? $term->name : ucwords( str_replace( '-', ' ', $slug ) );
	$key   = go_verge_v36_topic_key( $label );
	if ( ! $key ) { return null; }

	$candidates = get_posts( array(
		'post_type'              => $post_type,
		'post_status'            => 'publish',
		's'                      => $label,
		'posts_per_page'         => 20,
		'no_found_rows'          => true,
		'ignore_sticky_posts'    => true,
		'update_post_meta_cache' => false,
		'update_post_term_cache' => false,
		'suppress_filters'       => false,
	) );
	foreach ( (array) $candidates as $candidate ) {
		if ( $candidate instanceof WP_Post && $key === go_verge_v36_topic_key( $candidate->post_title ) ) {
			return $candidate;
		}
	}
	return null;
}

/**
 * Resolve /assunto/{slug}/ to a first-class destination when one exists.
 *
 * The generic route is only for genuinely generic topics. Production, game,
 * platform, service and curated entity hubs must have one canonical URL.
 */
function go_verge_v36_topic_destination( $slug ) {
	$slug = sanitize_title( (string) $slug );
	if ( ! $slug ) { return null; }
	static $cache = array();
	if ( array_key_exists( $slug, $cache ) ) { return $cache[ $slug ]; }
	$cache[ $slug ] = go_verge_v36_topic_destination_uncached( $slug );
	return $cache[ $slug ];
}

function go_verge_v36_topic_destination_uncached( $slug ) {
	$slug = sanitize_title( (string) $slug );
	if ( ! $slug ) { return null; }
	$key = go_verge_v36_topic_key( $slug );

	if ( function_exists( 'go_verge_v27_platform_aliases' ) ) {
		$aliases = go_verge_v27_platform_aliases();
		if ( isset( $aliases[ $key ] ) ) {
			$term = get_term_by( 'slug', $aliases[ $key ], 'go_platform' );
			if ( $term instanceof WP_Term ) {
				$url = get_term_link( $term );
				if ( ! is_wp_error( $url ) ) { return array( 'type'=>'platform', 'id'=>(int)$term->term_id, 'name'=>$term->name, 'url'=>$url ); }
			}
		}
	}
	if ( function_exists( 'go_verge_v27_service_aliases' ) ) {
		$aliases = go_verge_v27_service_aliases();
		if ( isset( $aliases[ $key ] ) ) {
			$term = get_term_by( 'slug', $aliases[ $key ], 'go_service' );
			if ( $term instanceof WP_Term ) {
				$url = get_term_link( $term );
				if ( ! is_wp_error( $url ) ) { return array( 'type'=>'service', 'id'=>(int)$term->term_id, 'name'=>$term->name, 'url'=>$url ); }
			}
		}
	}
	if ( function_exists( 'go_verge_v27_section_aliases' ) && function_exists( 'go_verge_v27_section_url' ) ) {
		$aliases = go_verge_v27_section_aliases();
		if ( isset( $aliases[ $key ] ) ) {
			$url = go_verge_v27_section_url( $aliases[ $key ] );
			if ( $url ) { return array( 'type'=>'section', 'id'=>0, 'name'=>ucwords(str_replace('-',' ',$aliases[$key])), 'url'=>$url ); }
		}
	}

	/* A generic topic may share a label with both an adaptation and a game.
	 * Never pick one by array order. One unique catalogue match is canonical;
	 * collisions are resolved only when entity evidence already chose a side. */
	$catalog = array();
	foreach ( array( 'productions', 'games' ) as $post_type ) {
		$post = go_verge_v36_topic_named_post( $slug, $post_type );
		if ( $post instanceof WP_Post ) { $catalog[ $post_type ] = $post; }
	}
	if ( 1 === count( $catalog ) ) {
		$post_type = (string) array_key_first( $catalog );
		$post = $catalog[ $post_type ];
		return array( 'type'=>$post_type, 'id'=>(int)$post->ID, 'name'=>get_the_title($post), 'url'=>get_permalink($post) );
	}

	$entity = post_type_exists( 'go_entity' ) ? go_verge_v36_topic_named_post( $slug, 'go_entity' ) : null;
	if ( $entity instanceof WP_Post && function_exists( 'go_verge_v27_entity_canonical_target' ) ) {
		$target = go_verge_v27_entity_canonical_target( $entity->ID );
		if ( is_array( $target ) && ! empty( $target['url'] ) ) {
			return array(
				'type' => (string) ( $target['kind'] ?? 'canonical' ),
				'id'   => absint( $target['target_id'] ?? 0 ),
				'name' => get_the_title( $entity ),
				'url'  => $target['url'],
			);
		}
	}
	if ( count( $catalog ) > 1 ) { return null; }

	if ( $entity instanceof WP_Post ) {
		return array( 'type'=>'go_entity', 'id'=>(int)$entity->ID, 'name'=>get_the_title($entity), 'url'=>get_permalink($entity) );
	}
	return null;
}

/** Human label for a topic slug, preferring a real catalogue title or tag. */
function go_verge_v21_topic_label( $slug ) {
	$slug = sanitize_title( (string) $slug );
	$destination = go_verge_v36_topic_destination( $slug );
	if ( $destination && ! empty( $destination['name'] ) ) { return (string) $destination['name']; }
	$term = get_term_by( 'slug', $slug, 'post_tag' );
	if ( $term instanceof WP_Term ) { return $term->name; }
	return ucwords( str_replace( '-', ' ', $slug ) );
}

/** Cache generation for the comparatively expensive generic-topic resolver. */
function go_verge_v21_topic_cache_generation() {
	return (string) get_option( 'go_verge_v21_topic_cache_generation', '1' );
}

/** Advance the generation instead of scanning/deleting individual transients. */
function go_verge_v21_touch_topic_cache_generation() {
	update_option( 'go_verge_v21_topic_cache_generation', (string) microtime( true ), false );
}

/** Invalidate when a post enters/leaves/updates the public editorial graph. */
function go_verge_v21_bust_topic_cache_on_transition( $new_status, $old_status, $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	if ( 'publish' === $new_status || 'publish' === $old_status ) {
		go_verge_v21_touch_topic_cache_generation();
	}
}
add_action( 'transition_post_status', 'go_verge_v21_bust_topic_cache_on_transition', 40, 3 );

/** Tag relationships can change without a post-status transition. */
function go_verge_v21_bust_topic_cache_on_terms( $object_id, $terms, $tt_ids, $taxonomy ) {
	if ( 'post_tag' !== $taxonomy || 'post' !== get_post_type( $object_id ) || 'publish' !== get_post_status( $object_id ) ) {
		return;
	}
	go_verge_v21_touch_topic_cache_generation();
}
add_action( 'set_object_terms', 'go_verge_v21_bust_topic_cache_on_terms', 40, 4 );

/** Term creation/rename/deletion can change which derivative tags match a hub. */
function go_verge_v21_bust_topic_cache_on_term() {
	go_verge_v21_touch_topic_cache_generation();
}
add_action( 'created_post_tag', 'go_verge_v21_bust_topic_cache_on_term', 40 );
add_action( 'edited_post_tag', 'go_verge_v21_bust_topic_cache_on_term', 40 );
add_action( 'delete_post_tag', 'go_verge_v21_bust_topic_cache_on_term', 40 );

/** Derivative tags that belong to a durable topic (seasons, episodes, finals...). */
function go_verge_v21_topic_term_ids( $slug, $label ) {
	$slug      = sanitize_title( (string) $slug );
	$label     = trim( (string) $label );
	$cache_key = 'go_v21_topic_terms_' . md5( go_verge_v21_topic_cache_generation() . '|' . $slug . '|' . $label );
	$cached    = get_transient( $cache_key );
	if ( is_array( $cached ) ) {
		return array_values( array_map( 'absint', $cached ) );
	}

	$ids   = array();
	$exact = get_term_by( 'slug', $slug, 'post_tag' );
	/* An empty legacy tag must not suppress the textual fallback. */
	if ( $exact instanceof WP_Term && (int) $exact->count > 0 ) { $ids[] = (int) $exact->term_id; }
	$needle = function_exists( 'go_verge_v17_cluster_key' ) ? go_verge_v17_cluster_key( $label ) : strtolower( remove_accents( $label ) );
	$terms = get_terms( array( 'taxonomy' => 'post_tag', 'hide_empty' => true, 'number' => 500, 'orderby' => 'count', 'order' => 'DESC' ) );
	if ( ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			$key = function_exists( 'go_verge_v17_cluster_key' ) ? go_verge_v17_cluster_key( $term->name ) : strtolower( remove_accents( $term->name ) );
			if ( $needle && ( $key === $needle || 0 === strpos( $key, $needle . ' ' ) ) ) { $ids[] = (int) $term->term_id; }
		}
	}
	$ids = array_values( array_unique( array_filter( $ids ) ) );
	set_transient( $cache_key, $ids, 30 * MINUTE_IN_SECONDS );
	return $ids;
}

/** Query one genuinely generic topic without exposing the generic search UI. */
function go_verge_v21_topic_query( $slug, $paged = 1, $per_page = 14, $content_type = '' ) {
	$slug      = sanitize_title( (string) $slug );
	$label     = go_verge_v21_topic_label( $slug );
	$tag_ids   = go_verge_v21_topic_term_ids( $slug, $label );
	$all_ids   = array();
	$pool_max  = 500;
	$pool_key  = 'go_v21_topic_pool_' . md5( go_verge_v21_topic_cache_generation() . '|' . $slug . '|' . implode( ',', $tag_ids ) );
	$pool      = get_transient( $pool_key );

	if ( is_array( $pool ) ) {
		$all_ids = array_values( array_map( 'absint', $pool ) );
	} else {
		/* Generic topics can have both taxonomy relationships and old typed subject
		 * references. Aggregate both before pagination so the public hub cannot show
		 * zero while the newsroom has already linked stories to that subject. */
		if ( $tag_ids ) {
		$tag_story_ids = get_posts( array(
			'post_type'=>'post','post_status'=>'publish','posts_per_page'=>$pool_max,'fields'=>'ids',
			'ignore_sticky_posts'=>true,'no_found_rows'=>true,'tag__in'=>array_map('absint',$tag_ids),
			'update_post_meta_cache'=>false,'update_post_term_cache'=>false,
			'orderby'=>'date','order'=>'DESC',
		) );
		$all_ids = array_merge( $all_ids, array_map( 'absint', (array) $tag_story_ids ) );
	}

	$exact = get_term_by( 'slug', sanitize_title( $slug ), 'post_tag' );
	if ( $exact instanceof WP_Term ) {
		$ref = 'post_tag:' . (int) $exact->term_id;
		$meta_query = array( 'relation'=>'OR' );
		foreach ( array( 'go_primary_subject_ref','go_technical_subject_ref','_go_review_subject_reference','go_review_subject_reference','_go_review_sheet_subject_reference' ) as $key ) {
			$meta_query[] = array( 'key'=>$key, 'value'=>$ref, 'compare'=>'=' );
		}
		$ref_ids = get_posts( array(
			'post_type'=>'post','post_status'=>'publish','posts_per_page'=>$pool_max,'fields'=>'ids',
			'ignore_sticky_posts'=>true,'no_found_rows'=>true,'meta_query'=>$meta_query, // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_query
			'update_post_meta_cache'=>false,'update_post_term_cache'=>false,
			'orderby'=>'date','order'=>'DESC',
		) );
		$all_ids = array_merge( $all_ids, array_map( 'absint', (array) $ref_ids ) );
	}

	$all_ids = array_values( array_unique( array_filter( $all_ids ) ) );
	set_transient( $pool_key, $all_ids, 15 * MINUTE_IN_SECONDS );
	}
	$args = array(
		'post_type'=>'post','post_status'=>'publish','posts_per_page'=>max(1,absint($per_page)),
		'paged'=>max(1,absint($paged)),'ignore_sticky_posts'=>true,'orderby'=>'date','order'=>'DESC',
	);
	$content_type = sanitize_title( (string) $content_type );
	$valid_type = $content_type && function_exists( 'go_verge_v45_subject_type_labels' ) && isset( go_verge_v45_subject_type_labels()[ $content_type ] );
	$had_subject_pool = ! empty( $all_ids );
	if ( $valid_type && $had_subject_pool && function_exists( 'go_verge_v45_filter_subject_ids_by_type' ) ) {
		/* Filter the canonical story pool itself. This keeps old stories whose
		 * structured type is inferred by the V45 fallback visible until their
		 * go_content_type repair has been persisted. */
		$all_ids = go_verge_v45_filter_subject_ids_by_type( $all_ids, $content_type );
	}
	if ( $had_subject_pool ) {
		$args['post__in'] = $all_ids ? $all_ids : array( 0 );
	} else {
		/* Never turn an arbitrary path into a search-results doorway. A public
		 * topic must be backed by a durable term/reference pool or a first-class
		 * entity handled by the redirect above. Unknown subjects therefore 404. */
		$args['post__in'] = array( 0 );
	}
	return new WP_Query( $args );
}

/**
 * Custom topic hubs use their own WP_Query, so the main WordPress query has no
 * posts to prove that /page/2/ exists. Validate the requested topic page here
 * and short-circuit core's generic 404 handler only when that page really has
 * content. Requests beyond max_num_pages still receive a proper 404.
 */
function go_verge_v44_topic_pre_handle_404( $preempt, $wp_query ) {
	if ( ! go_verge_v21_is_topic_hub() ) { return $preempt; }
	$slug  = sanitize_title( (string) get_query_var( 'go_topic' ) );
	$paged = max( 1, absint( get_query_var( 'paged' ) ) );
	if ( ! $slug ) { return $preempt; }

	$topic_query = go_verge_v21_topic_query( $slug, $paged, 14, function_exists( 'go_verge_v45_subject_active_type' ) ? go_verge_v45_subject_active_type() : '' );
	$valid       = $topic_query instanceof WP_Query && $topic_query->have_posts();
	if ( ! $valid ) { return $preempt; }

	if ( $wp_query instanceof WP_Query ) {
		$wp_query->is_404 = false;
	}
	status_header( 200 );
	return true;
}
add_filter( 'pre_handle_404', 'go_verge_v44_topic_pre_handle_404', 20, 2 );

/** Keep WordPress canonical guessing away from valid custom topic pages. */
function go_verge_v44_topic_redirect_canonical( $redirect_url, $requested_url ) {
	if ( go_verge_v21_is_topic_hub() ) { return false; }
	return $redirect_url;
}
add_filter( 'redirect_canonical', 'go_verge_v44_topic_redirect_canonical', 20, 2 );

/** Pick a real tag relationship that can be followed for a generic topic hub. */
function go_verge_v44_topic_follow_term( $slug, $label = '' ) {
	$slug  = sanitize_title( (string) $slug );
	$label = trim( wp_strip_all_tags( (string) $label ) );
	if ( ! $slug ) { return null; }

	$term = get_term_by( 'slug', $slug, 'post_tag' );
	if ( ! ( $term instanceof WP_Term ) && $label ) {
		$term = get_term_by( 'name', $label, 'post_tag' );
	}
	if ( $term instanceof WP_Term && (int) $term->count > 0 ) { return $term; }

	/* A legacy hub can be assembled from derivative tags even when the exact
	 * base tag is missing. Use the strongest real tag so following still works
	 * with the existing local personalization feed. */
	if ( function_exists( 'go_verge_v21_topic_term_ids' ) ) {
		$ids = go_verge_v21_topic_term_ids( $slug, $label ?: go_verge_v21_topic_label( $slug ) );
		foreach ( $ids as $id ) {
			$candidate = get_term( absint( $id ), 'post_tag' );
			if ( $candidate instanceof WP_Term && ! is_wp_error( $candidate ) && (int) $candidate->count > 0 ) { return $candidate; }
		}
	}
	return null;
}

/** Redirect duplicate /assunto/ routes to their one real hub. */
function go_verge_v36_redirect_topic_to_canonical_hub() {
	if ( ! go_verge_v21_is_topic_hub() || is_preview() ) { return; }
	$destination = go_verge_v36_topic_destination( get_query_var( 'go_topic' ) );
	if ( ! $destination || empty( $destination['url'] ) ) { return; }
	$target = esc_url_raw( $destination['url'] );
	$paged  = max( 1, absint( get_query_var( 'paged' ) ) );
	/* Preserve a reader's position when an old /assunto/.../page/N/ alias now
	 * resolves to a first-class Production/Entity subject hub. */
	if ( $paged > 1 && ! empty( $destination['id'] ) && in_array( (string) ( $destination['type'] ?? '' ), array( 'productions', 'go_entity' ), true ) && function_exists( 'go_verge_v45_subject_page_url' ) ) {
		$target = esc_url_raw( go_verge_v45_subject_page_url( absint( $destination['id'] ), $paged ) );
	}
	if ( ! $target ) { return; }
	wp_safe_redirect( $target, 301, 'Overdrive canonical topic hub' );
	exit;
}
add_action( 'template_redirect', 'go_verge_v36_redirect_topic_to_canonical_hub', -20 );


/**
 * Existing post-tag URLs are aliases too. If a tag has a unique first-class
 * Production/Game/Entity destination, links and direct visits use that one hub.
 * Ambiguous labels are deliberately left untouched.
 */
function go_verge_v36_canonical_tag_link( $url, $term, $taxonomy ) {
	if ( 'post_tag' !== $taxonomy || ! ( $term instanceof WP_Term ) ) { return $url; }
	$destination = go_verge_v36_topic_destination( $term->slug );
	return ( $destination && ! empty( $destination['url'] ) ) ? $destination['url'] : $url;
}
add_filter( 'term_link', 'go_verge_v36_canonical_tag_link', 35, 3 );

function go_verge_v36_redirect_tag_to_canonical_hub() {
	if ( ! is_tag() || is_preview() ) { return; }
	$term = get_queried_object();
	if ( ! ( $term instanceof WP_Term ) ) { return; }
	$destination = go_verge_v36_topic_destination( $term->slug );
	if ( ! $destination || empty( $destination['url'] ) ) { return; }
	wp_safe_redirect( esc_url_raw( $destination['url'] ), 301, 'Overdrive canonical tag hub' );
	exit;
}
add_action( 'template_redirect', 'go_verge_v36_redirect_tag_to_canonical_hub', -19 );

/** Serve the generic editorial topic-hub template. */
function go_verge_v21_topic_template( $template ) {
	if ( ! go_verge_v21_is_topic_hub() ) { return $template; }
	$file = GO_VERGE_DIR . '/topic-hub.php';
	return file_exists( $file ) ? $file : $template;
}
add_filter( 'template_include', 'go_verge_v21_topic_template', 9999 );

/** Proper title/canonical for generic topic hubs; first-class hubs redirect. */
add_filter( 'pre_get_document_title', static function ( $title ) {
	if ( ! go_verge_v21_is_topic_hub() ) { return $title; }
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	return go_verge_v21_topic_label( get_query_var( 'go_topic' ) ) . ' — ' . $site_name;
}, 999 );
add_filter( 'rank_math/frontend/canonical', static function ( $canonical ) {
	if ( ! go_verge_v21_is_topic_hub() ) { return $canonical; }
	$destination = go_verge_v36_topic_destination( get_query_var( 'go_topic' ) );
	$paged = max( 1, absint( get_query_var( 'paged' ) ) );
	if ( $destination && ! empty( $destination['url'] ) ) {
		if ( $paged > 1 && ! empty( $destination['id'] ) && in_array( (string) ( $destination['type'] ?? '' ), array( 'productions', 'go_entity' ), true ) && function_exists( 'go_verge_v45_subject_page_url' ) ) {
			return go_verge_v45_subject_page_url( absint( $destination['id'] ), $paged );
		}
		return $destination['url'];
	}
	$label = go_verge_v21_topic_label( get_query_var( 'go_topic' ) );
	return function_exists( 'go_verge_v44_topic_page_url' ) ? go_verge_v44_topic_page_url( $label, $paged ) : go_verge_v21_topic_hub_url( $label );
}, 999 );

/** Canonical for legacy tag aliases mirrors the server-side 301. */
add_filter( 'rank_math/frontend/canonical', static function ( $canonical ) {
	if ( ! is_tag() ) { return $canonical; }
	$term = get_queried_object();
	if ( ! ( $term instanceof WP_Term ) ) { return $canonical; }
	$destination = go_verge_v36_topic_destination( $term->slug );
	return ( $destination && ! empty( $destination['url'] ) ) ? $destination['url'] : $canonical;
}, 1000 );


/** Keep legacy tag aliases out of Rank Math XML sitemaps; canonical hubs remain. */
function go_verge_v36_rank_math_topic_alias_sitemap_entry( $url, $type, $object ) {
	if ( 'term' !== $type || ! ( $object instanceof WP_Term ) || 'post_tag' !== $object->taxonomy ) { return $url; }
	$destination = go_verge_v36_topic_destination( $object->slug );
	return ( $destination && ! empty( $destination['url' ] ) ) ? false : $url;
}
add_filter( 'rank_math/sitemap/entry', 'go_verge_v36_rank_math_topic_alias_sitemap_entry', 40, 3 );

/**
 * Canonicalize publisher identity in every Rank Math graph. There is only one
 * publication entity: Overdrive. Domain/handles remain stable technical URLs.
 */
function go_verge_v21_rank_math_publisher_entity( $data, $jsonld = null ) {
	if ( ! is_array( $data ) ) { return $data; }
	$org_id = trailingslashit( home_url( '/' ) ) . '#organization';
	$site_id = trailingslashit( home_url( '/' ) ) . '#website';
	$same_as = function_exists( 'go_verge_publisher_same_as_urls' ) ? go_verge_publisher_same_as_urls() : array();
	$logo = function_exists( 'go_verge_seo_logo' ) ? go_verge_seo_logo() : array();
	$current_url = is_singular() ? get_permalink( get_queried_object_id() ) : '';
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) { continue; }
		if ( isset( $node['@id'] ) && $org_id === (string) $node['@id'] ) {
			$data[$key]['name'] = $site_name;
			$data[$key]['@id'] = $org_id;
			$data[$key]['url'] = home_url( '/' );
			$alternate = function_exists( 'go_verge_seo_alternate_name_value' ) ? go_verge_seo_alternate_name_value() : null;
			if ( null !== $alternate && '' !== $alternate ) { $data[$key]['alternateName'] = $alternate; } else { unset( $data[$key]['alternateName'] ); }
			if ( $same_as ) { $data[$key]['sameAs'] = array_values( array_unique( $same_as ) ); }
			if ( ! empty( $logo['url'] ) ) {
				$data[$key]['logo'] = array( '@type' => 'ImageObject', '@id' => trailingslashit( home_url( '/' ) ) . '#logo', 'url' => $logo['url'] );
			}
		}
		if ( go_verge_schema_node_matches_url( $node, home_url( '/' ), array( 'WebSite' ) ) ) {
			$data[$key]['name'] = $site_name;
			$data[$key]['@id'] = $site_id;
			$data[$key]['url'] = home_url( '/' );
			$data[$key]['publisher'] = array( '@id' => $org_id );
			$alternate = function_exists( 'go_verge_seo_alternate_name_value' ) ? go_verge_seo_alternate_name_value() : null;
			if ( null !== $alternate && '' !== $alternate ) { $data[$key]['alternateName'] = $alternate; } else { unset( $data[$key]['alternateName'] ); }
		}
		if ( $current_url && go_verge_schema_node_matches_url( $node, $current_url, array( 'Article', 'NewsArticle', 'Review', 'BlogPosting' ) ) ) {
			$data[$key]['publisher'] = array( '@id' => $org_id );
		}
	}
	return $data;
}
/* Publisher references must exist before the generic foundation closer at 900. */
add_filter( 'rank_math/json_ld', 'go_verge_v21_rank_math_publisher_entity', 850, 2 );

/* Rank Math Knowledge Graph UI/output consistency. */
add_filter( 'rank_math/json_ld/organization', static function ( $entity ) {
	if ( ! is_array( $entity ) ) { $entity = array(); }
	$entity['name'] = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	$entity['url'] = home_url( '/' );
	$entity['@id'] = trailingslashit( home_url( '/' ) ) . '#organization';
	if ( function_exists( 'go_verge_publisher_same_as_urls' ) ) { $entity['sameAs'] = go_verge_publisher_same_as_urls(); }
	$alternate = function_exists( 'go_verge_seo_alternate_name_value' ) ? go_verge_seo_alternate_name_value() : null;
	if ( null !== $alternate && '' !== $alternate ) { $entity['alternateName'] = $alternate; } else { unset( $entity['alternateName'] ); }
	return $entity;
}, 999 );

/** Small contextual strip after the article: same subject first, discovery second. */
function go_verge_v21_render_contextual_next( $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || ! function_exists( 'go_verge_v17_cluster_subject' ) ) { return; }
	$subject = go_verge_v17_cluster_subject( $post_id );
	if ( ! $subject ) { return; }

	/*
	 * Pull a slightly larger subject pool, then remove everything already offered
	 * elsewhere in this pageview. Previously this module asked for exactly three
	 * IDs and knew nothing about the post-content grid, which is why the same
	 * cards could appear back-to-back in the screenshot that triggered V64.
	 */
	$used = function_exists( 'go_verge_recirculation_shown_ids' )
		? (array) go_verge_recirculation_shown_ids()
		: ( function_exists( 'go_verge_sidebar_shown_ids' ) ? (array) go_verge_sidebar_shown_ids() : array() );
	$pool = function_exists( 'go_verge_v17_cluster_post_ids' ) ? go_verge_v17_cluster_post_ids( $post_id, $subject, 6 ) : array();
	$ids  = array_values( array_diff( array_map( 'absint', (array) $pool ), array_map( 'absint', $used ), array( $post_id ) ) );
	$ids  = array_slice( array_filter( $ids ), 0, 3 );
	if ( count( $ids ) < 2 ) { return; }

	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( array_merge( $used, $ids ) );
	} elseif ( function_exists( 'go_verge_sidebar_shown_ids' ) ) {
		go_verge_sidebar_shown_ids( array_merge( $used, $ids ) );
	}
	if ( function_exists( 'go_verge_contextual_next_rendered' ) ) {
		go_verge_contextual_next_rendered( $post_id, true );
	}

	$name = trim( (string) ( $subject['name'] ?? '' ) );
	?>
	<section class="go-v21-next" aria-labelledby="go-v21-next-title-<?php echo esc_attr( $post_id ); ?>">
		<div class="go-v21-next__head"><div><span><?php esc_html_e( 'Continue neste assunto', 'go-verge' ); ?></span><h2 id="go-v21-next-title-<?php echo esc_attr( $post_id ); ?>"><?php echo esc_html( $name ); ?></h2></div><a href="<?php echo esc_url( $subject['url'] ); ?>"><?php esc_html_e( 'Ver tudo', 'go-verge' ); ?> →</a></div>
		<div class="go-v21-next__grid">
		<?php foreach ( $ids as $id ) : ?><article <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $id, 'contextual-next' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>><a href="<?php echo esc_url( get_permalink( $id ) ); ?>" class="go-v21-next__media"><?php echo get_the_post_thumbnail( $id, 'go_card', array( 'loading'=>'lazy', 'decoding'=>'async' ) ); // phpcs:ignore ?></a><h3><a href="<?php echo esc_url( get_permalink( $id ) ); ?>"><?php echo esc_html( get_the_title( $id ) ); ?></a></h3></article><?php endforeach; ?>
		</div>
	</section>
	<?php
}
