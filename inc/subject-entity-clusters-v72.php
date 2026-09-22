<?php
/**
 * Subject ↔ Entity cluster promoter V72.
 *
 * A recurring editorial subject becomes a first-class /universo/ hub once it
 * has more than five published stories. Existing entity hubs are continuously
 * hydrated from their matching tag family and strong title mentions, so a hub
 * cannot silently show only the stories that happened to receive _go_entity_ids.
 *
 * The promoter never duplicates a structural Game, Production, Platform,
 * Service or section hub. People/characters are also never created from a tag
 * automatically: system-created recurring subjects are classified as the safe
 * generic type assunto-conceito until an editor deliberately changes the type.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

const GO_VERGE_SUBJECT_ENTITY_CLUSTER_VERSION = '2026-08-28-v74';
const GO_VERGE_SUBJECT_ENTITY_MIN_STORIES = 6;

/** Normalize an entity relationship meta array. */
function go_verge_v72_entity_ids_for_story( $post_id ) {
	$value = get_post_meta( absint( $post_id ), '_go_entity_ids', true );
	return array_values( array_unique( array_filter( array_map( 'absint', is_array( $value ) ? $value : array() ) ) ) );
}

/** Attach one entity without overwriting any deliberate existing relationships. */
function go_verge_v72_attach_entity_to_story( $post_id, $entity_id ) {
	$post_id   = absint( $post_id );
	$entity_id = absint( $entity_id );
	if ( ! $post_id || ! $entity_id || 'post' !== get_post_type( $post_id ) || 'publish' !== get_post_status( $post_id ) ) { return false; }
	$ids = go_verge_v72_entity_ids_for_story( $post_id );
	if ( in_array( $entity_id, $ids, true ) ) { return false; }
	$ids[] = $entity_id;
	update_post_meta( $post_id, '_go_entity_ids', array_values( array_unique( $ids ) ) );
	return true;
}

/** Build safe editorial aliases for a recurring entity label.
 *
 * Editors should not have to tag every historical post by hand. For multiword
 * franchises we can safely derive the familiar initialism (Metal Gear Solid ->
 * MGS) and also honor explicit aliases saved by editorial tooling. Aliases are
 * only used in strong headline/slug/tag contexts; a body-text mention alone is
 * never enough to join a cluster.
 */
function go_verge_v74_entity_aliases( $label, $entity_id = 0 ) {
	$label = trim( wp_strip_all_tags( (string) $label ) );
	$aliases = array();
	$tokens = preg_split( '/[^\p{L}\p{N}]+/u', remove_accents( $label ), -1, PREG_SPLIT_NO_EMPTY );
	$stop = array( 'a','as','o','os','de','da','das','do','dos','e','the','of','and' );
	$letters = '';
	foreach ( (array) $tokens as $token ) {
		$lower = strtolower( $token );
		if ( in_array( $lower, $stop, true ) ) { continue; }
		$letters .= strtoupper( substr( $token, 0, 1 ) );
	}
	if ( strlen( $letters ) >= 3 && strlen( $letters ) <= 8 ) { $aliases[] = $letters; }
	if ( $entity_id ) {
		$stored = get_post_meta( absint( $entity_id ), '_go_entity_aliases', true );
		if ( is_string( $stored ) ) { $stored = preg_split( '/[,;\n]+/u', $stored, -1, PREG_SPLIT_NO_EMPTY ); }
		foreach ( (array) $stored as $alias ) {
			$alias = trim( wp_strip_all_tags( (string) $alias ) );
			if ( strlen( $alias ) >= 2 && strlen( $alias ) <= 80 ) { $aliases[] = $alias; }
		}
	}
	$aliases = array_values( array_unique( array_filter( $aliases ) ) );
	return $aliases;
}

/** Does a post contain a strong editorial alias signal? */
function go_verge_v74_story_matches_alias( $post_id, $alias ) {
	$post_id = absint( $post_id );
	$alias   = trim( (string) $alias );
	if ( ! $post_id || '' === $alias ) { return false; }
	$title = (string) get_the_title( $post_id );
	$slug  = (string) get_post_field( 'post_name', $post_id );
	$haystacks = array( $title, str_replace( '-', ' ', $slug ) );
	$quoted = preg_quote( remove_accents( $alias ), '/' );
	foreach ( $haystacks as $haystack ) {
		$plain = remove_accents( (string) $haystack );
		if ( preg_match( '/(?<![A-Z0-9])' . $quoted . '(?=(?:[0-9]|\b|[:\-]))/iu', $plain ) ) { return true; }
	}
	$tags = wp_get_post_terms( $post_id, 'post_tag', array( 'fields'=>'names' ) );
	if ( ! is_wp_error( $tags ) ) {
		foreach ( (array) $tags as $tag ) {
			if ( preg_match( '/(?<![A-Z0-9])' . $quoted . '(?=(?:[0-9]|\b|[:\-]))/iu', remove_accents( (string) $tag ) ) ) { return true; }
		}
	}
	return false;
}

/**
 * Published coverage belonging to one durable label.
 *
 * Sources, in order of confidence:
 * - direct entity relationship;
 * - exact + derivative post tags;
 * - legacy typed subject references;
 * - exact franchise phrase in headline;
 * - safe editorial aliases (for example MGS/MGS4 for Metal Gear Solid);
 * - stories linked to child Game records whose titles belong to the entity.
 */
function go_verge_v72_cluster_story_ids( $slug, $label, $limit = 600, $entity_id = 0 ) {
	$slug  = sanitize_title( (string) $slug );
	$label = trim( wp_strip_all_tags( (string) $label ) );
	$limit = max( 20, min( 1000, absint( $limit ) ) );
	if ( ! $slug || ! $label ) { return array(); }

	$entity_id = absint( $entity_id );
	$cache_key = 'go_v72_cluster_' . md5( go_verge_v21_topic_cache_generation() . '|' . $slug . '|' . $label . '|' . $limit . '|' . $entity_id );
	$cached = get_transient( $cache_key );
	if ( is_array( $cached ) ) { return array_values( array_map( 'absint', $cached ) ); }

	$ids = array();
	/* Direct editorial relationship is the strongest signal and must always be
	 * part of the hub, even when an older article has no matching tag/title. */
	if ( $entity_id ) {
		global $wpdb;
		$direct_ids = $wpdb->get_col( $wpdb->prepare(
			"SELECT p.ID FROM {$wpdb->posts} p INNER JOIN {$wpdb->postmeta} pm ON pm.post_id=p.ID WHERE p.post_type='post' AND p.post_status='publish' AND pm.meta_key='_go_entity_ids' AND pm.meta_value LIKE %s ORDER BY p.post_date DESC LIMIT %d",
			'%' . $wpdb->esc_like( 'i:' . $entity_id . ';' ) . '%', $limit
		) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		$ids = array_merge( $ids, array_map( 'absint', (array) $direct_ids ) );
	}
	$tag_ids = function_exists( 'go_verge_v21_topic_term_ids' ) ? go_verge_v21_topic_term_ids( $slug, $label ) : array();
	if ( $tag_ids ) {
		$ids = array_merge( $ids, get_posts( array(
			'post_type' => 'post', 'post_status' => 'publish', 'posts_per_page' => $limit, 'fields' => 'ids',
			'ignore_sticky_posts' => true, 'no_found_rows' => true, 'tag__in' => array_map( 'absint', $tag_ids ),
			'update_post_meta_cache' => false, 'update_post_term_cache' => false, 'orderby' => 'date', 'order' => 'DESC',
		) ) );
	}

	$exact = get_term_by( 'slug', $slug, 'post_tag' );
	if ( $exact instanceof WP_Term ) {
		$ref = 'post_tag:' . (int) $exact->term_id;
		$meta_query = array( 'relation' => 'OR' );
		foreach ( array( 'go_primary_subject_ref', 'go_technical_subject_ref', '_go_review_subject_reference', 'go_review_subject_reference', '_go_review_sheet_subject_reference' ) as $key ) {
			$meta_query[] = array( 'key' => $key, 'value' => $ref, 'compare' => '=' );
		}
		$ids = array_merge( $ids, get_posts( array(
			'post_type' => 'post', 'post_status' => 'publish', 'posts_per_page' => $limit, 'fields' => 'ids',
			'ignore_sticky_posts' => true, 'no_found_rows' => true, 'meta_query' => $meta_query, // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_query
			'update_post_meta_cache' => false, 'update_post_term_cache' => false, 'orderby' => 'date', 'order' => 'DESC',
		) ) );
	}

	/* Once a topic is already established, a headline containing the full label
	 * is strong evidence and repairs older posts that predate the entity field.
	 * Broad distribution labels are intentionally excluded. */
	$is_broad = function_exists( 'go_verge_v17_cluster_is_broad' ) && go_verge_v17_cluster_is_broad( $label );
	$tokens = preg_split( '/\s+/u', $label, -1, PREG_SPLIT_NO_EMPTY );
	if ( ! $is_broad && strlen( remove_accents( $label ) ) >= 5 && ( count( (array) $tokens ) >= 2 || strlen( $label ) >= 9 ) ) {
		global $wpdb;
		$title_rows = $wpdb->get_col( $wpdb->prepare(
			"SELECT ID FROM {$wpdb->posts} WHERE post_type='post' AND post_status='publish' AND post_title LIKE %s ORDER BY post_date DESC LIMIT %d",
			'%' . $wpdb->esc_like( $label ) . '%', $limit
		) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		$ids = array_merge( $ids, array_map( 'absint', (array) $title_rows ) );
	}

	/* Historical franchise coverage often predates the entity system and uses a
	 * familiar initialism in headlines (MGS4, MGS Delta, etc.). Pull a bounded
	 * candidate pool for each safe alias and validate it in PHP against headline,
	 * slug or tags so a casual body mention never contaminates the hub. */
	foreach ( go_verge_v74_entity_aliases( $label, $entity_id ) as $alias ) {
		global $wpdb;
		$alias_like = '%' . $wpdb->esc_like( $alias ) . '%';
		$candidates = $wpdb->get_col( $wpdb->prepare(
			"SELECT ID FROM {$wpdb->posts} WHERE post_type='post' AND post_status='publish' AND (post_title LIKE %s OR post_name LIKE %s) ORDER BY post_date DESC LIMIT %d",
			$alias_like, $alias_like, min( 300, $limit )
		) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		foreach ( array_map( 'absint', (array) $candidates ) as $candidate_id ) {
			if ( go_verge_v74_story_matches_alias( $candidate_id, $alias ) ) { $ids[] = $candidate_id; }
		}
	}

	/* A franchise entity also owns articles attached to canonical Game records
	 * whose titles begin with that franchise name. This catches articles whose
	 * headline says only a subtitle/entry name but whose structured Game field is
	 * already correct. */
	if ( post_type_exists( 'games' ) && function_exists( 'go_verge_product_related_post_ids' ) ) {
		$game_candidates = get_posts( array(
			'post_type'=>'games','post_status'=>'publish','posts_per_page'=>80,'s'=>$label,'orderby'=>'title','order'=>'ASC','no_found_rows'=>true,
		) );
		$entity_key = function_exists( 'go_verge_v17_cluster_key' ) ? go_verge_v17_cluster_key( $label ) : strtolower( remove_accents( $label ) );
		foreach ( (array) $game_candidates as $game ) {
			$game_key = function_exists( 'go_verge_v17_cluster_key' ) ? go_verge_v17_cluster_key( $game->post_title ) : strtolower( remove_accents( $game->post_title ) );
			if ( ! $entity_key || ( $game_key !== $entity_key && 0 !== strpos( $game_key, $entity_key . ' ' ) ) ) { continue; }
			$ids = array_merge( $ids, array_map( 'absint', (array) go_verge_product_related_post_ids( $game->ID, 'games', min( 120, $limit ) ) ) );
		}
	}

	$ids = array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
	usort( $ids, static function( $a, $b ) { return (int) get_post_time( 'U', true, $b ) <=> (int) get_post_time( 'U', true, $a ); } );
	$ids = array_slice( $ids, 0, $limit );
	set_transient( $cache_key, $ids, 15 * MINUTE_IN_SECONDS );
	return $ids;
}

/** Find an entity by exact slug/title in any usable status. */
function go_verge_v72_find_entity( $slug, $label = '' ) {
	$slug = sanitize_title( (string) $slug );
	if ( ! $slug || ! post_type_exists( 'go_entity' ) ) { return null; }
	$direct = get_page_by_path( $slug, OBJECT, 'go_entity' );
	if ( $direct instanceof WP_Post && 'trash' !== $direct->post_status ) { return $direct; }

	$key = function_exists( 'go_verge_v27_entity_key' ) ? go_verge_v27_entity_key( $label ?: $slug ) : sanitize_title( $label ?: $slug );
	$candidates = get_posts( array(
		'post_type' => 'go_entity', 'post_status' => array( 'publish', 'draft', 'pending', 'private' ),
		'posts_per_page' => 30, 's' => $label ?: str_replace( '-', ' ', $slug ), 'no_found_rows' => true,
		'orderby' => 'modified', 'order' => 'DESC', 'suppress_filters' => false,
	) );
	foreach ( (array) $candidates as $candidate ) {
		$candidate_key = function_exists( 'go_verge_v27_entity_key' ) ? go_verge_v27_entity_key( $candidate->post_title ) : sanitize_title( $candidate->post_title );
		if ( $candidate_key === $key ) { return $candidate; }
	}
	return null;
}

/** Hydrate one entity with every confidently matching published story. */
function go_verge_v72_hydrate_entity( $entity_id ) {
	$entity = get_post( absint( $entity_id ) );
	if ( ! ( $entity instanceof WP_Post ) || 'go_entity' !== $entity->post_type || 'trash' === $entity->post_status ) { return array(); }
	$ids = go_verge_v72_cluster_story_ids( $entity->post_name ?: sanitize_title( $entity->post_title ), $entity->post_title, 600, $entity->ID );
	$changed = false;
	foreach ( $ids as $story_id ) {
		$changed = go_verge_v72_attach_entity_to_story( $story_id, $entity->ID ) || $changed;
	}
	if ( $changed && function_exists( 'go_verge_v27_flush_story_sets' ) ) { go_verge_v27_flush_story_sets(); }
	if ( $changed && function_exists( 'go_verge_v25_flush_entity_published_counts' ) ) { go_verge_v25_flush_entity_published_counts(); }
	return $ids;
}

/** Publish a qualified, non-conflicting recurring cluster even from WP-Cron. */
function go_verge_v72_maybe_publish_entity( $entity_id, $coverage = null ) {
	$entity = get_post( absint( $entity_id ) );
	if ( ! ( $entity instanceof WP_Post ) || 'go_entity' !== $entity->post_type || 'trash' === $entity->post_status ) { return false; }
	if ( 'publish' === $entity->post_status ) { return true; }
	$coverage = is_array( $coverage ) ? $coverage : go_verge_v72_hydrate_entity( $entity->ID );
	if ( count( $coverage ) < GO_VERGE_SUBJECT_ENTITY_MIN_STORIES ) { return false; }

	if ( function_exists( 'go_verge_v27_entity_canonical_target' ) && go_verge_v27_entity_canonical_target( $entity->ID ) ) { return false; }
	$generated = (bool) get_post_meta( $entity->ID, '_go_entity_cluster_generated', true );
	$editor_created = (bool) get_post_meta( $entity->ID, '_go_entity_cluster_editor_created', true );
	$classification = function_exists( 'go_verge_v27_classify_entity_title' ) ? go_verge_v27_classify_entity_title( $entity->post_title, $entity->ID ) : array();
	$type = sanitize_key( $classification['type'] ?? '' );
	$confidence = (float) ( $classification['confidence'] ?? 0 );
	$safe_types = array( 'obra-franquia', 'empresa-estudio', 'evento', 'marca-produto', 'assunto-conceito' );
	if ( ! $generated && ! $editor_created && ( $confidence < .95 || ! in_array( $type, $safe_types, true ) ) ) { return false; }

	if ( function_exists( 'go_verge_v27_analyze_entity' ) ) {
		$analysis = go_verge_v27_analyze_entity( $entity->ID, false );
		if ( in_array( (string) ( $analysis['status'] ?? '' ), array( 'canonical', 'duplicate', 'review' ), true ) ) { return false; }
	}

	$result = wp_update_post( array( 'ID' => $entity->ID, 'post_status' => 'publish' ), true );
	if ( is_wp_error( $result ) ) { return false; }
	update_post_meta( $entity->ID, '_go_entity_cluster_qualified', count( $coverage ) );
	update_post_meta( $entity->ID, '_go_entity_cluster_published_at', current_time( 'mysql', true ) );
	if ( function_exists( 'go_verge_v27_analyze_entity' ) ) { go_verge_v27_analyze_entity( $entity->ID, false ); }
	return true;
}


/**
 * Create or reuse an editor-declared subject candidate while editing a story.
 * The candidate remains draft/invisible until six published stories qualify.
 */
function go_verge_v72_create_editor_entity_candidate( $title ) {
	$title = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) $title ) ) );
	if ( function_exists('mb_substr') ) $title=mb_substr($title,0,120); else $title=substr($title,0,120);
	if ( strlen( $title ) < 2 || ! post_type_exists('go_entity') ) return new WP_Error('invalid_entity','Informe um assunto válido.');
	$slug = sanitize_title( $title );
	$existing = go_verge_v72_find_entity( $slug, $title );
	if ( $existing instanceof WP_Post ) {
		return array('id'=>(int)$existing->ID,'title'=>$existing->post_title,'status'=>$existing->post_status,'created'=>false,'threshold'=>GO_VERGE_SUBJECT_ENTITY_MIN_STORIES,'published_stories'=>count(go_verge_v72_hydrate_entity($existing->ID)));
	}
	$destination = function_exists('go_verge_v36_topic_destination') ? go_verge_v36_topic_destination($slug) : null;
	if ( is_array($destination) && !empty($destination['type']) && 'go_entity'!==$destination['type'] ) {
		return new WP_Error('structural_destination',sprintf('“%s” já possui uma página estrutural (%s); use essa referência em vez de duplicar um Universo.',$title,$destination['type']));
	}
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Game Overdrive';
	$id=wp_insert_post(wp_slash(array('post_type'=>'go_entity','post_status'=>'draft','post_title'=>$title,'post_name'=>$slug,'post_excerpt'=>sprintf('Acompanhe notícias, guias e especiais sobre %1$s no %2$s.',$title,$site_name))),true);
	if(is_wp_error($id)||!$id)return is_wp_error($id)?$id:new WP_Error('create_failed','Não foi possível criar a entidade.');
	update_post_meta($id,'_go_entity_cluster_editor_created',1);
	update_post_meta($id,'_go_entity_cluster_type','assunto-conceito');
	update_post_meta($id,'_go_entity_cluster_version',GO_VERGE_SUBJECT_ENTITY_CLUSTER_VERSION);
	if(taxonomy_exists('go_entity_type')){ $term=get_term_by('slug','assunto-conceito','go_entity_type'); if($term instanceof WP_Term) wp_set_object_terms($id,array((int)$term->term_id),'go_entity_type',false); }
	return array('id'=>(int)$id,'title'=>$title,'status'=>'draft','created'=>true,'threshold'=>GO_VERGE_SUBJECT_ENTITY_MIN_STORIES,'published_stories'=>0);
}

/** Small theme-native endpoint so the block editor can create candidates inline. */
function go_verge_v72_register_entity_candidate_route() {
	register_rest_route('go-verge/v1','/entity-candidate',array(
		'methods'=>'POST','permission_callback'=>static function(){return current_user_can('edit_posts');},
		'callback'=>static function(WP_REST_Request $request){$result=go_verge_v72_create_editor_entity_candidate($request->get_param('title'));return is_wp_error($result)?$result:rest_ensure_response($result);},
		'args'=>array('title'=>array('type'=>'string','required'=>true)),
	));
}
add_action('rest_api_init','go_verge_v72_register_entity_candidate_route');

/** Promote one recurring post tag to its canonical first-class destination. */
function go_verge_v72_promote_subject_term( $term_id ) {
	$term = get_term( absint( $term_id ), 'post_tag' );
	if ( ! ( $term instanceof WP_Term ) || is_wp_error( $term ) || (int) $term->count < 2 ) { return 0; }
	if ( function_exists( 'go_verge_v17_cluster_is_broad' ) && go_verge_v17_cluster_is_broad( $term->name ) ) { return 0; }
	if ( function_exists( 'go_verge_v17_cluster_is_derivative' ) && go_verge_v17_cluster_is_derivative( $term->name ) ) { return 0; }
	$prequalified_coverage = go_verge_v72_cluster_story_ids( $term->slug, $term->name );
	if ( count( $prequalified_coverage ) < GO_VERGE_SUBJECT_ENTITY_MIN_STORIES ) { return 0; }

	$destination = function_exists( 'go_verge_v36_topic_destination' ) ? go_verge_v36_topic_destination( $term->slug ) : null;
	if ( is_array( $destination ) && ! empty( $destination['type'] ) && 'go_entity' !== $destination['type'] ) {
		/* Games, productions, services, platforms and sections are already
		 * first-class hubs. Creating a second /universo/ URL would split authority. */
		return absint( $destination['id'] ?? 0 );
	}

	$entity = ( is_array( $destination ) && 'go_entity' === ( $destination['type'] ?? '' ) && ! empty( $destination['id'] ) )
		? get_post( absint( $destination['id'] ) )
		: go_verge_v72_find_entity( $term->slug, $term->name );

	if ( ! ( $entity instanceof WP_Post ) ) {
		$id = wp_insert_post( wp_slash( array(
			'post_type' => 'go_entity', 'post_status' => 'draft', 'post_title' => $term->name, 'post_name' => $term->slug,
			'post_excerpt' => sprintf( 'Acompanhe as principais notícias, guias e especiais sobre %s no Overdrive.', $term->name ),
		) ), true );
		if ( is_wp_error( $id ) || ! $id ) { return 0; }
		update_post_meta( $id, '_go_entity_cluster_generated', 1 );
		update_post_meta( $id, '_go_entity_cluster_type', 'assunto-conceito' );
		update_post_meta( $id, '_go_entity_cluster_source_term_id', (int) $term->term_id );
		update_post_meta( $id, '_go_entity_cluster_version', GO_VERGE_SUBJECT_ENTITY_CLUSTER_VERSION );
		$entity = get_post( $id );
	}
	if ( ! ( $entity instanceof WP_Post ) ) { return 0; }

	$coverage = $prequalified_coverage;
	$changed = false;
	foreach ( $coverage as $story_id ) { $changed = go_verge_v72_attach_entity_to_story( $story_id, $entity->ID ) || $changed; }
	if ( $changed && function_exists( 'go_verge_v27_flush_story_sets' ) ) { go_verge_v27_flush_story_sets(); }
	if ( $changed && function_exists( 'go_verge_v25_flush_entity_published_counts' ) ) { go_verge_v25_flush_entity_published_counts(); }
	if ( count( $coverage ) >= GO_VERGE_SUBJECT_ENTITY_MIN_STORIES ) {
		go_verge_v72_maybe_publish_entity( $entity->ID, $coverage );
	}
	return (int) $entity->ID;
}

/** Self-heal one entity as it is saved/edited. */
function go_verge_v72_hydrate_saved_entity( $post_id, $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'go_entity' !== $post->post_type || wp_is_post_revision( $post_id ) || 'trash' === $post->post_status ) { return; }
	$coverage = go_verge_v72_hydrate_entity( $post_id );
	if ( count( $coverage ) >= GO_VERGE_SUBJECT_ENTITY_MIN_STORIES ) { go_verge_v72_maybe_publish_entity( $post_id, $coverage ); }
}
add_action( 'save_post_go_entity', 'go_verge_v72_hydrate_saved_entity', 140, 2 );

/** Queue only the tags touched by a published article; no full scan on save. */
function go_verge_v72_queue_post_subjects( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || 'publish' !== get_post_status( $post_id ) ) { return; }
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) {
		go_verge_defer_post_save_maintenance( $post_id );
		return;
	}
	/* A manually-created candidate can cross the threshold without any matching
	 * post tag, so directly-linked entities are evaluated on every publish. */
	foreach ( array_slice( go_verge_v72_entity_ids_for_story( $post_id ), 0, 12 ) as $entity_id ) {
		$coverage = go_verge_v72_hydrate_entity( $entity_id );
		if ( count( $coverage ) >= GO_VERGE_SUBJECT_ENTITY_MIN_STORIES ) { go_verge_v72_maybe_publish_entity( $entity_id, $coverage ); }
	}
	$terms = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) );
	if ( is_wp_error( $terms ) ) { return; }
	foreach ( array_slice( array_values( array_unique( array_map( 'absint', $terms ) ) ), 0, 20 ) as $term_id ) {
		if ( ! wp_next_scheduled( 'go_verge_v72_promote_subject_term', array( $term_id ) ) ) {
			wp_schedule_single_event( time() + 30, 'go_verge_v72_promote_subject_term', array( $term_id ) );
		}
	}
}
add_action( 'save_post_post', 'go_verge_v72_queue_post_subjects', 1300 );
add_action( 'go_verge_v72_promote_subject_term', 'go_verge_v72_promote_subject_term' );

/** Tag edits can cross the six-story threshold without another post save. */
function go_verge_v72_queue_changed_terms( $object_id, $terms, $tt_ids, $taxonomy ) {
	unset( $terms, $tt_ids );
	if ( 'post_tag' !== $taxonomy || 'post' !== get_post_type( $object_id ) || 'publish' !== get_post_status( $object_id ) ) { return; }
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) {
		go_verge_defer_post_save_maintenance( $object_id );
		return;
	}
	go_verge_v72_queue_post_subjects( $object_id );
}
add_action( 'set_object_terms', 'go_verge_v72_queue_changed_terms', 90, 4 );

/** Bounded maintenance: hydrate existing hubs + discover qualified tags. */
function go_verge_v72_cluster_maintenance() {
	if ( function_exists( 'go_verge_claim_job_lock' ) && ! go_verge_claim_job_lock( 'subject_entity_v72', 10 * MINUTE_IN_SECONDS ) ) { return; }
	$page = max( 1, absint( get_option( 'go_verge_v72_entity_page', 1 ) ) );
	$entities = get_posts( array(
		'post_type' => 'go_entity', 'post_status' => array( 'publish', 'draft', 'pending' ), 'posts_per_page' => 24,
		'paged' => $page, 'fields' => 'ids', 'orderby' => 'ID', 'order' => 'ASC', 'no_found_rows' => true,
		'suppress_filters' => false,
	) );
	foreach ( $entities as $entity_id ) {
		$coverage = go_verge_v72_hydrate_entity( absint( $entity_id ) );
		if ( count( $coverage ) >= GO_VERGE_SUBJECT_ENTITY_MIN_STORIES ) { go_verge_v72_maybe_publish_entity( $entity_id, $coverage ); }
	}
	update_option( 'go_verge_v72_entity_page', count( $entities ) < 24 ? 1 : $page + 1, false );

	$tag_offset = max( 0, absint( get_option( 'go_verge_v72_tag_offset', 0 ) ) );
	$terms = get_terms( array(
		'taxonomy' => 'post_tag', 'hide_empty' => true, 'number' => 100, 'offset' => $tag_offset, 'orderby' => 'count', 'order' => 'DESC',
	) );
	if ( ! is_wp_error( $terms ) ) {
		$continue_tags = count( $terms ) === 100;
		foreach ( $terms as $term ) {
			if ( (int) $term->count < 2 ) { $continue_tags = false; break; }
			go_verge_v72_promote_subject_term( $term->term_id );
		}
		update_option( 'go_verge_v72_tag_offset', $continue_tags ? $tag_offset + 100 : 0, false );
	}
	update_option( 'go_verge_subject_entity_cluster_done', GO_VERGE_SUBJECT_ENTITY_CLUSTER_VERSION, false );
	$more_entities = count( $entities ) === 24;
	$more_tags = ! is_wp_error( $terms ) && count( $terms ) === 100 && (int) get_option( 'go_verge_v72_tag_offset', 0 ) > 0;
	if ( ( $more_entities || $more_tags ) && ! wp_next_scheduled( 'go_verge_v72_cluster_maintenance_once' ) ) {
		wp_schedule_single_event( time() + 75, 'go_verge_v72_cluster_maintenance_once' );
	}
	if ( function_exists( 'go_verge_release_job_lock' ) ) { go_verge_release_job_lock( 'subject_entity_v72' ); }
}
add_action( 'go_verge_v72_cluster_maintenance', 'go_verge_v72_cluster_maintenance' );

/** Schedule maintenance and force one near-term pass after this build arrives. */
function go_verge_v72_schedule_cluster_maintenance() {
	if ( ! wp_next_scheduled( 'go_verge_v72_cluster_maintenance' ) ) {
		wp_schedule_event( time() + 10 * MINUTE_IN_SECONDS, 'hourly', 'go_verge_v72_cluster_maintenance' );
	}
	if ( get_option( 'go_verge_subject_entity_cluster_done' ) !== GO_VERGE_SUBJECT_ENTITY_CLUSTER_VERSION
		&& ! wp_next_scheduled( 'go_verge_v72_cluster_maintenance_once' ) ) {
		wp_schedule_single_event( time() + 45, 'go_verge_v72_cluster_maintenance_once' );
	}
}
add_action( 'init', 'go_verge_v72_schedule_cluster_maintenance', 40 );
add_action( 'go_verge_v72_cluster_maintenance_once', 'go_verge_v72_cluster_maintenance' );
