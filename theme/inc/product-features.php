<?php
/**
 * Product features: connected game hubs, follows/saves, launch calendar,
 * live updates, corrections, specials, topic pages and accessibility.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Auto-create public utility pages without overwriting existing pages. */
function go_verge_product_page_map() {
	return array(
		'lancamentos' => 'Lançamentos',
		'para-voce' => 'Para você',
		'salvos' => 'Salvos',
		'popular' => 'Popular agora',
		'status' => 'Status',
		'preferencias-newsletter' => 'Preferências da newsletter',
	);
}
function go_verge_ensure_product_pages() {
	$version = '1.0.0';
	if ( get_option( 'go_verge_product_pages_version' ) === $version ) { return; }
	foreach ( go_verge_product_page_map() as $slug => $title ) {
		if ( get_page_by_path( $slug, OBJECT, 'page' ) ) { continue; }
		wp_insert_post( array( 'post_type'=>'page','post_status'=>'publish','post_title'=>$title,'post_name'=>$slug,'post_content'=>'' ) );
	}
	update_option( 'go_verge_product_pages_version', $version, false );
	go_verge_flush_rewrite_rules_once_per_request();
}
add_action( 'admin_init', 'go_verge_ensure_product_pages', 30 );

/** Generic meta helpers. */
function go_verge_product_first_meta( $post_id, $keys ) {
	foreach ( (array) $keys as $key ) {
		$value = get_post_meta( $post_id, $key, true );
		if ( '' !== trim( (string) $value ) ) { return $value; }
	}
	return '';
}
function go_verge_product_linked_game_id( $post_id ) {
	$relationship_keys = array( 'go_linked_game_id','_go_linked_game_id','go_review_game_id','_go_review_game_id' );
	foreach ( array_merge( $relationship_keys, array( 'go_promotion_linked_game_id' ) ) as $key ) {
		$id = absint( get_post_meta( $post_id, $key, true ) );
		if ( ! $id || 'games' !== get_post_type( $id ) ) {
			continue;
		}

		/* Automatic editorial relationships are not trusted by recirculation or
		 * schema until the hardened matcher validates the same game. Promotion
		 * relations are explicit product metadata and remain independent. */
		if ( in_array( $key, $relationship_keys, true ) && function_exists( 'go_verge_game_intelligence_link_is_trusted' ) ) {
			$mode = (string) get_post_meta( $post_id, '_go_game_intelligence_mode', true );
			if ( 'auto' === $mode && ! go_verge_game_intelligence_link_is_trusted( $post_id, $id ) ) {
				continue;
			}
		}
		return $id;
	}
	return 0;
}
function go_verge_product_subject_reference( $post_id ) {
	foreach ( array( 'go_primary_subject_ref', 'go_technical_subject_ref', '_go_review_subject_reference','go_review_subject_reference','_go_review_sheet_subject_reference' ) as $key ) {
		$value = trim( (string) get_post_meta( $post_id, $key, true ) );
		if ( $value && ! in_array( $value, array( 'auto', 'none', 'custom' ), true ) ) { return $value; }
	}
	return '';
}

/** Invalidate title/SEO match caches when editorial signals change. */
function go_verge_product_bump_game_match_generation( $post_id = 0 ) {
	if ( $post_id && ( 'post' !== get_post_type( $post_id ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) ) { return; }
	$next = (int) get_option( '_go_game_text_match_generation', 1 ) + 1;
	update_option( '_go_game_text_match_generation', $next, false );
}
add_action( 'save_post_post', 'go_verge_product_bump_game_match_generation', 220 );

function go_verge_product_bump_game_match_generation_on_meta( $meta_id, $post_id, $meta_key, $meta_value ) {
	if ( 'post' !== get_post_type( $post_id ) || ! function_exists( 'go_verge_game_intelligence_seo_meta_keys' ) ) { return; }
	$signal_keys = array_merge(
		go_verge_game_intelligence_seo_meta_keys(),
		array( '_go_post_subtitle', 'go_verge_support_line' )
	);
	if ( in_array( $meta_key, $signal_keys, true ) ) {
		go_verge_product_bump_game_match_generation( $post_id );
	}
}
add_action( 'added_post_meta', 'go_verge_product_bump_game_match_generation_on_meta', 120, 4 );
add_action( 'updated_post_meta', 'go_verge_product_bump_game_match_generation_on_meta', 120, 4 );

/** Refresh historical matching when game names, aliases or article terms change. */
function go_verge_product_bump_game_match_generation_on_game_save( $post_id ) {
	if ( ! wp_is_post_revision( $post_id ) && ! wp_is_post_autosave( $post_id ) ) {
		go_verge_product_bump_game_match_generation();
	}
}
add_action( 'save_post_games', 'go_verge_product_bump_game_match_generation_on_game_save', 220 );

function go_verge_product_bump_game_match_generation_on_terms( $object_id, $terms, $tt_ids, $taxonomy ) {
	if ( 'post' === get_post_type( $object_id ) && in_array( $taxonomy, array( 'category', 'post_tag' ), true ) ) {
		go_verge_product_bump_game_match_generation( $object_id );
	}
}
add_action( 'set_object_terms', 'go_verge_product_bump_game_match_generation_on_terms', 120, 4 );

/** Check section constraints after explicit and automatic game matching. */
function go_verge_product_related_post_matches_args( $post_id, $args ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'publish' !== get_post_status( $post_id ) ) { return false; }
	if ( in_array( $post_id, array_map( 'absint', (array) ( $args['exclude'] ?? array() ) ), true ) ) { return false; }
	$include = array_filter( array_map( 'sanitize_title', (array) ( $args['category_slugs'] ?? array() ) ) );
	$exclude = array_filter( array_map( 'sanitize_title', (array) ( $args['exclude_category_slugs'] ?? array() ) ) );
	if ( $include && ! has_category( $include, $post_id ) ) { return false; }
	if ( $exclude && has_category( $exclude, $post_id ) ) { return false; }
	if ( ! empty( $args['require_video'] ) ) {
		$content = (string) get_post_field( 'post_content', $post_id );
		$has_video = false;
		foreach ( array( 'gamxo_youtube_link','_go_trailer_url','go_trailer_url' ) as $key ) {
			if ( get_post_meta( $post_id, $key, true ) ) { $has_video = true; break; }
		}
		if ( ! $has_video && ! preg_match( '#(?:youtube\.com|youtu\.be|vimeo\.com|wp:embed|<iframe)#i', $content ) ) { return false; }
	}
	return true;
}

/** Strict title/SEO score used by game hubs; body mentions alone never qualify. */
function go_verge_product_game_title_seo_score( $post_id, $game_id ) {
	if ( ! function_exists( 'go_verge_game_intelligence_normalize' ) ) { return 0; }
	$title = go_verge_game_intelligence_normalize( get_the_title( $post_id ) );
	$seo   = function_exists( 'go_verge_game_intelligence_seo_context' ) ? go_verge_game_intelligence_seo_context( $post_id ) : array( 'titles'=>array(), 'focus'=>array() );
	$seo_titles = go_verge_game_intelligence_normalize( implode( ' ', (array) ( $seo['titles'] ?? array() ) ) );
	$focus      = go_verge_game_intelligence_normalize( implode( ' ', (array) ( $seo['focus'] ?? array() ) ) );
	$names = array( get_the_title( $game_id ) );
	if ( function_exists( 'go_verge_game_intelligence_aliases' ) ) {
		$names = array_merge( $names, go_verge_game_intelligence_aliases( $game_id ) );
	}
	$best = 0;
	foreach ( array_unique( array_filter( $names ) ) as $name ) {
		$name = go_verge_game_intelligence_normalize( $name );
		if ( strlen( str_replace( ' ', '', $name ) ) < 3 ) { continue; }
		$tokens = function_exists( 'go_verge_game_intelligence_tokens' ) ? count( go_verge_game_intelligence_tokens( $name ) ) : 1;
		$specificity = min( 4, max( 0, $tokens - 1 ) );
		if ( $title === $name ) { $best = max( $best, 100 ); }
		elseif ( false !== strpos( ' '.$title.' ', ' '.$name.' ' ) ) { $best = max( $best, min( 99, 95 + $specificity ) ); }
		if ( $seo_titles === $name ) { $best = max( $best, 100 ); }
		elseif ( $seo_titles && false !== strpos( ' '.$seo_titles.' ', ' '.$name.' ' ) ) { $best = max( $best, min( 99, 94 + $specificity ) ); }
		if ( $focus && false !== strpos( ' '.$focus.' ', ' '.$name.' ' ) ) { $best = max( $best, min( 98, 93 + $specificity ) ); }
	}
	return (int) $best;
}

/** Score one specific game against all strong editorial signals on a post. */
function go_verge_product_game_context_score( $post_id, $game_id ) {
	if ( ! function_exists( 'go_verge_game_intelligence_context' ) || ! function_exists( 'go_verge_game_intelligence_score_game' ) ) { return 0; }
	$names = array( get_the_title( $game_id ) );
	if ( function_exists( 'go_verge_game_intelligence_aliases' ) ) {
		$names = array_merge( $names, go_verge_game_intelligence_aliases( $game_id ) );
	}
	$normalized_names = array();
	foreach ( array_unique( array_filter( $names ) ) as $name ) {
		$normal = go_verge_game_intelligence_normalize( $name );
		if ( '' !== $normal ) { $normalized_names[ $normal ] = $name; }
	}
	if ( ! $normalized_names ) { return 0; }
	$result = go_verge_game_intelligence_score_game(
		array( 'id' => absint( $game_id ), 'names' => $normalized_names ),
		go_verge_game_intelligence_context( $post_id )
	);
	return (int) ( $result['score'] ?? 0 );
}

/**
 * Find recent posts whose title, SEO data, slug, support line or taxonomy can
 * plausibly identify a game. SQL only narrows candidates; final acceptance
 * uses normalized scoring and the all-games ambiguity check.
 */
function go_verge_product_textual_game_candidates( $game_id, $limit = 80 ) {
	global $wpdb;
	$game_id = absint( $game_id );
	if ( ! $game_id || 'games' !== get_post_type( $game_id ) ) { return array(); }
	$generation = (int) get_option( '_go_game_text_match_generation', 1 );
	$cache_key = 'go_game_text_candidates_v6_' . $generation . '_' . $game_id . '_' . absint( $limit );
	$cached = wp_cache_get( $cache_key, 'go_verge' );
	if ( false !== $cached && is_array( $cached ) ) { return $cached; }

	$names = array( get_the_title( $game_id ) );
	if ( function_exists( 'go_verge_game_intelligence_aliases' ) ) { $names = array_merge( $names, go_verge_game_intelligence_aliases( $game_id ) ); }
	$tokens = array();
	$numeric_tokens = array();
	$stop_tokens = array_fill_keys( array( 'the','and','for','com','dos','das','de','do','da','game','games','jogo','jogos' ), true );
	foreach ( $names as $name ) {
		$normal = function_exists( 'go_verge_game_intelligence_normalize' ) ? go_verge_game_intelligence_normalize( $name ) : strtolower( remove_accents( $name ) );
		foreach ( preg_split( '/\s+/u', $normal ) as $token ) {
			if ( strlen( $token ) < 2 || isset( $stop_tokens[ $token ] ) ) { continue; }
			if ( preg_match( '/^\d+$/', $token ) ) { $numeric_tokens[ $token ] = strlen( $token ); continue; }
			$tokens[ $token ] = strlen( $token );
		}
	}
	if ( ! $tokens ) { $tokens = $numeric_tokens; }
	arsort( $tokens );
	$anchors = array_slice( array_keys( $tokens ), 0, 5 );
	if ( ! $anchors ) { wp_cache_set( $cache_key, array(), 'go_verge', 10 * MINUTE_IN_SECONDS ); return array(); }

	$seo_keys = function_exists( 'go_verge_game_intelligence_seo_meta_keys' ) ? go_verge_game_intelligence_seo_meta_keys() : array( 'rank_math_title','_yoast_wpseo_title' );
	$signal_meta_keys = array_values( array_unique( array_merge( $seo_keys, array( '_go_post_subtitle', 'go_verge_support_line' ) ) ) );
	$key_placeholders = implode( ',', array_fill( 0, count( $signal_meta_keys ), '%s' ) );
	$like_clauses = array();
	$params = $signal_meta_keys;
	foreach ( $anchors as $anchor ) {
		$like = '%' . $wpdb->esc_like( $anchor ) . '%';
		$like_clauses[] = '(p.post_title LIKE %s OR p.post_excerpt LIKE %s OR p.post_name LIKE %s OR pm.meta_value LIKE %s OR t.name LIKE %s)';
		for ( $i = 0; $i < 5; $i++ ) { $params[] = $like; }
	}
	$params[] = max( 120, min( 500, absint( $limit ) * 5 ) );
	$sql = "SELECT DISTINCT p.ID, p.post_date FROM {$wpdb->posts} p
		LEFT JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key IN ({$key_placeholders})
		LEFT JOIN {$wpdb->term_relationships} tr ON p.ID = tr.object_id
		LEFT JOIN {$wpdb->term_taxonomy} tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy IN ('category','post_tag')
		LEFT JOIN {$wpdb->terms} t ON tt.term_id = t.term_id
		WHERE p.post_type = 'post' AND p.post_status = 'publish'
		AND (" . implode( ' OR ', $like_clauses ) . ")
		ORDER BY p.post_date DESC LIMIT %d";
	$candidate_ids = $wpdb->get_col( $wpdb->prepare( $sql, $params ) ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared

	$ranked = array();
	foreach ( array_map( 'absint', (array) $candidate_ids ) as $post_id ) {
		$title_score   = go_verge_product_game_title_seo_score( $post_id, $game_id );
		$context_score = go_verge_product_game_context_score( $post_id, $game_id );
		$score         = max( $title_score, $context_score );
		// Dynamic legacy matching requires a title, SEO, tag, subtitle or slug
		// signal. A casual mention in the article body is not enough by itself.
		if ( $score < 91 ) { continue; }
		if ( function_exists( 'go_verge_game_intelligence_analyze' ) ) {
			$analysis = go_verge_game_intelligence_analyze( $post_id );
			if ( empty( $analysis['safe'] ) || empty( $analysis['candidate']['id'] ) || absint( $analysis['candidate']['id'] ) !== $game_id ) { continue; }
			$score = max( $score, (int) $analysis['score'] );
		} elseif ( $title_score < 95 ) {
			continue;
		}
		$ranked[] = array( 'id'=>$post_id, 'score'=>$score, 'date'=>(int) get_post_time( 'U', true, $post_id ) );
	}
	usort( $ranked, static function( $a, $b ) {
		if ( $a['score'] === $b['score'] ) { return $b['date'] <=> $a['date']; }
		return $b['score'] <=> $a['score'];
	} );
	$ids = array_slice( array_column( $ranked, 'id' ), 0, max( 1, absint( $limit ) ) );
	wp_cache_set( $cache_key, $ids, 'go_verge', 10 * MINUTE_IN_SECONDS );
	return $ids;
}

/** Find related post IDs using the canonical editorial relationship first. */
function go_verge_product_related_post_ids( $object_id, $object_type = 'games', $limit = 12, $args = array() ) {
	$object_id = absint( $object_id );
	$limit     = max( 1, (int) $limit );
	if ( ! $object_id || ! in_array( $object_type, array( 'games','productions','go_entity' ), true ) ) { return array(); }
	$defaults = array( 'category_slugs'=>array(), 'exclude_category_slugs'=>array(), 'require_video'=>false, 'exclude'=>array() );
	$args = wp_parse_args( $args, $defaults );
	$ids  = array();

	/*
	 * Entity hubs must use the same source of truth as the newsroom counter.
	 * Regular stories store their entity relationship in the serialized
	 * _go_entity_ids array. Older builds only queried review-subject metadata
	 * here, which made a public hub look empty even when the admin correctly
	 * reported dozens of linked published stories.
	 */
	if ( 'go_entity' === $object_type ) {
		if ( function_exists( 'go_verge_v27_entity_story_sets' ) ) {
			$sets = go_verge_v27_entity_story_sets();
			$ids  = array_map( 'absint', (array) ( $sets[ $object_id ] ?? array() ) );
		} else {
			/* Compatibility fallback for installs where the intelligence module is unavailable. */
			$ids = get_posts( array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => max( 60, $limit * 4 ),
				'fields'              => 'ids',
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'meta_query'          => array( // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_query
					array( 'key'=>'_go_entity_ids', 'value'=>'i:' . $object_id . ';', 'compare'=>'LIKE' ),
				),
				'orderby'             => 'date',
				'order'               => 'DESC',
			) );
		}

		/* Preserve legacy review links that predate _go_entity_ids. */
		$ref = 'go_entity:' . $object_id;
		$legacy_meta = array( 'relation'=>'OR' );
		foreach ( array( '_go_review_subject_reference','go_review_subject_reference','_go_review_sheet_subject_reference' ) as $key ) {
			$legacy_meta[] = array( 'key'=>$key,'value'=>$ref,'compare'=>'=' );
		}
		$legacy_ids = get_posts( array(
			'post_type'=>'post','post_status'=>'publish','posts_per_page'=>max(20,$limit),'fields'=>'ids','ignore_sticky_posts'=>true,'no_found_rows'=>true,
			'meta_query'=>$legacy_meta, 'orderby'=>'date', 'order'=>'DESC',
		) );
		$ids = array_values( array_unique( array_merge( array_map('absint',$ids), array_map('absint',$legacy_ids) ) ) );

		$ids = array_values( array_filter( $ids, static function( $id ) use ( $args ) {
			return go_verge_product_related_post_matches_args( $id, $args );
		} ) );
		usort( $ids, static function( $a, $b ) {
			return (int) get_post_time( 'U', true, $b ) <=> (int) get_post_time( 'U', true, $a );
		} );
		return array_slice( $ids, 0, $limit );
	}


	/*
	 * Production hubs aggregate every safe historical relationship, not only the
	 * newest _go_production_id field. Older stories may still carry a typed
	 * primary-subject reference or durable tags such as "Meu Nome é Farah 2ª
	 * temporada". A body-text mention by itself never qualifies.
	 */
	if ( 'productions' === $object_type ) {
		$production = get_post( $object_id );
		if ( ! ( $production instanceof WP_Post ) || 'productions' !== $production->post_type || 'publish' !== $production->post_status ) { return array(); }
		$pool_limit = max( 80, $limit * 5 );
		$ref        = 'productions:' . $object_id;
		$meta_query = array(
			'relation' => 'OR',
			array( 'key'=>'_go_production_id', 'value'=>$object_id, 'compare'=>'=' ),
		);
		foreach ( array( 'go_primary_subject_ref','go_technical_subject_ref','_go_review_subject_reference','go_review_subject_reference','_go_review_sheet_subject_reference' ) as $key ) {
			$meta_query[] = array( 'key'=>$key, 'value'=>$ref, 'compare'=>'=' );
		}
		$meta_ids = get_posts( array(
			'post_type'=>'post','post_status'=>'publish','posts_per_page'=>$pool_limit,'fields'=>'ids',
			'ignore_sticky_posts'=>true,'no_found_rows'=>true,'post__not_in'=>array_map('absint',(array)$args['exclude']),
			'meta_query'=>$meta_query, // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_query
			'orderby'=>'date','order'=>'DESC',
		) );
		$ids = array_map( 'absint', (array) $meta_ids );

		/* Existing tags are aliases of the Production, not competing hubs. Include
		 * exact and derivative tags only when they share the normalized title. */
		$production_slug  = sanitize_title( $production->post_name ?: $production->post_title );
		$production_label = trim( wp_strip_all_tags( $production->post_title ) );
		$tag_ids = array();
		if ( function_exists( 'go_verge_v21_topic_term_ids' ) ) {
			$tag_ids = go_verge_v21_topic_term_ids( $production_slug, $production_label );
		} else {
			$term = get_term_by( 'slug', $production_slug, 'post_tag' );
			if ( $term instanceof WP_Term && (int) $term->count > 0 ) { $tag_ids[] = (int) $term->term_id; }
		}
		if ( $tag_ids ) {
			$tag_story_ids = get_posts( array(
				'post_type'=>'post','post_status'=>'publish','posts_per_page'=>$pool_limit,'fields'=>'ids',
				'ignore_sticky_posts'=>true,'no_found_rows'=>true,'post__not_in'=>array_map('absint',(array)$args['exclude']),
				'tag__in'=>array_map('absint',$tag_ids),'orderby'=>'date','order'=>'DESC',
			) );
			$ids = array_merge( $ids, array_map( 'absint', (array) $tag_story_ids ) );
		}

		$ids = array_values( array_unique( array_filter( $ids ) ) );
		$ids = array_values( array_filter( $ids, static function( $id ) use ( $args ) {
			return go_verge_product_related_post_matches_args( $id, $args );
		} ) );
		usort( $ids, static function( $a, $b ) {
			return (int) get_post_time( 'U', true, $b ) <=> (int) get_post_time( 'U', true, $a );
		} );
		return array_slice( $ids, 0, $limit );
	}
	/* Games keep their explicit relationship keys plus the strict contextual fallback. */
	$meta_query = array( 'relation'=>'OR' );
	foreach ( array( 'go_linked_game_id','_go_linked_game_id','go_review_game_id','_go_review_game_id' ) as $key ) {
		$meta_query[] = array( 'key'=>$key,'value'=>$object_id,'compare'=>'=' );
	}
	$explicit_ids = get_posts( array(
		'post_type'=>'post','post_status'=>'publish','posts_per_page'=>max(40,$limit*4),'fields'=>'ids','ignore_sticky_posts'=>true,'no_found_rows'=>true,
		'post__not_in'=>array_map('absint',(array)$args['exclude']), 'meta_query'=>$meta_query, 'orderby'=>'date', 'order'=>'DESC',
	) );
	$ids = array_values( array_filter( array_map( 'absint', $explicit_ids ), static function( $id ) use ( $args ) { return go_verge_product_related_post_matches_args( $id, $args ); } ) );

	if ( count( $ids ) < $limit ) {
		$text_ids = go_verge_product_textual_game_candidates( $object_id, max( 60, $limit * 6 ) );
		foreach ( $text_ids as $post_id ) {
			$post_id = absint( $post_id );
			if ( in_array( $post_id, $ids, true ) || ! go_verge_product_related_post_matches_args( $post_id, $args ) ) { continue; }
			$ids[] = $post_id;
			if ( count( $ids ) >= $limit ) { break; }
		}
	}
	return array_slice( $ids, 0, $limit );
}

function go_verge_product_query_from_ids( $ids, $limit = 6 ) {
	$ids = array_values( array_filter( array_map( 'absint', (array) $ids ) ) );
	return new WP_Query( array(
		'post_type'=>'post','post_status'=>'publish','post__in'=>$ids ?: array(0),'orderby'=>'post__in','posts_per_page'=>max(1,(int)$limit),'ignore_sticky_posts'=>true,'no_found_rows'=>true,
	) );
}

/** Promotion records linked to a game. */
function go_verge_product_game_promotions( $game_id, $limit = 8 ) {
	if ( ! post_type_exists('go_promotion') ) { return new WP_Query(array('post__in'=>array(0))); }
	return new WP_Query( array(
		'post_type'=>'go_promotion','post_status'=>'publish','posts_per_page'=>max(1,(int)$limit),'ignore_sticky_posts'=>true,'no_found_rows'=>true,
		'meta_query'=>array( 'relation'=>'OR',
			array('key'=>'go_promotion_linked_game_id','value'=>$game_id), array('key'=>'go_linked_game_id','value'=>$game_id), array('key'=>'_go_linked_game_id','value'=>$game_id),
		),
		'meta_key'=>'go_promotion_sale_price','orderby'=>'meta_value_num','order'=>'ASC',
	) );
}

/** REST cards for local personalization. */
function go_verge_product_rest_routes() {
	register_rest_route( 'go-verge/v1', '/content-cards', array( 'methods'=>'GET','callback'=>'go_verge_product_rest_cards','permission_callback'=>'__return_true' ) );
	register_rest_route( 'go-verge/v1', '/personalized-feed', array( 'methods'=>'POST','callback'=>'go_verge_product_rest_personalized','permission_callback'=>'__return_true' ) );
}
add_action( 'rest_api_init', 'go_verge_product_rest_routes' );
function go_verge_product_card_data( $post_id ) {
	$post = get_post( $post_id ); if ( ! $post || 'publish' !== $post->post_status ) { return null; }
	$image = get_the_post_thumbnail_url( $post_id, 'go_card' );
	return array(
		'id'=>(int)$post_id,'type'=>$post->post_type,'title'=>get_the_title($post_id),'url'=>get_permalink($post_id),'image'=>$image ?: '',
		'excerpt'=>wp_trim_words( get_the_excerpt($post_id), 24, '…' ),'date'=>get_the_date('', $post_id),
	);
}
function go_verge_product_rest_cards( WP_REST_Request $request ) {
	$raw = explode( ',', (string) $request->get_param('ids') ); $ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$raw)))),0,50);
	$data=array(); foreach($ids as $id){$card=go_verge_product_card_data($id); if($card){$data[]=$card;}}
	return rest_ensure_response($data);
}
function go_verge_product_rest_personalized( WP_REST_Request $request ) {
	$game_ids     = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'game_ids' ) ) ) ) ), 0, 30 );
	$production_ids = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'production_ids' ) ) ) ) ), 0, 30 );
	$entity_ids   = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'entity_ids' ) ) ) ) ), 0, 30 );
	$tag_ids      = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'tag_ids' ) ) ) ) ), 0, 30 );
	$category_ids = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'category_ids' ) ) ) ) ), 0, 30 );
	$service_ids  = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'service_ids' ) ) ) ) ), 0, 30 );
	$platform_ids = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $request->get_param( 'platform_ids' ) ) ) ) ), 0, 30 );
	$ids          = array();

	foreach ( $game_ids as $id ) {
		$ids = array_merge( $ids, go_verge_product_related_post_ids( $id, 'games', 8 ) );
	}
	foreach ( $production_ids as $id ) {
		$ids = array_merge( $ids, go_verge_product_related_post_ids( $id, 'productions', 8 ) );
	}
	foreach ( $entity_ids as $id ) {
		$ids = array_merge( $ids, go_verge_product_related_post_ids( $id, 'go_entity', 8 ) );
	}

	$tax_query = array( 'relation' => 'OR' );
	if ( $tag_ids ) {
		$tax_query[] = array(
			'taxonomy' => 'post_tag',
			'field'    => 'term_id',
			'terms'    => $tag_ids,
		);
	}
	if ( $category_ids ) {
		$tax_query[] = array(
			'taxonomy'         => 'category',
			'field'            => 'term_id',
			'terms'            => $category_ids,
			'include_children' => true,
		);
	}
	if ( $service_ids ) {
		$tax_query[] = array(
			'taxonomy' => 'go_service',
			'field'    => 'term_id',
			'terms'    => $service_ids,
		);
	}
	if ( $platform_ids ) {
		$tax_query[] = array(
			'taxonomy' => 'go_platform',
			'field'    => 'term_id',
			'terms'    => $platform_ids,
		);
	}
	if ( count( $tax_query ) > 1 ) {
		$taxonomy_ids = get_posts(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => 24,
				'fields'              => 'ids',
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'orderby'             => 'date',
				'order'               => 'DESC',
				'tax_query'           => $tax_query,
			)
		);
		$ids = array_merge( $ids, array_map( 'absint', (array) $taxonomy_ids ) );
	}

	$ids  = array_slice( array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) ), 0, 24 );
	$data = array();
	foreach ( $ids as $id ) {
		$card = go_verge_product_card_data( $id );
		if ( $card ) {
			$data[] = $card;
		}
	}
	return rest_ensure_response( $data );
}

/** Buttons used by local personalization. */
function go_verge_product_follow_button( $object_id, $object_type, $label = '' ) {
	$object_id   = absint( $object_id );
	$object_type = sanitize_key( (string) $object_type );
	if ( ! $object_id ) { return; }
	$original_id   = $object_id;
	$original_type = $object_type;
	$subject_name  = '';

	/* V47: every representation of the same subject follows one canonical
	 * identity. A legacy tag for Meu Nome é Farah therefore shares the same
	 * button state and global counter as the Production hub. */
	if ( function_exists( 'go_verge_v47_subject_identity' ) ) {
		$identity = go_verge_v47_subject_identity( $object_id, $object_type );
		if ( is_array( $identity ) ) {
			$object_id   = absint( $identity['id'] ?? $object_id );
			$object_type = sanitize_key( (string) ( $identity['type'] ?? $object_type ) );
			$subject_name = trim( wp_strip_all_tags( (string) ( $identity['name'] ?? '' ) ) );
			if ( ! $label && $subject_name ) {
				$label = sprintf( __( 'Seguir %s', 'go-verge' ), $subject_name );
			}
		}
	}
	if ( ! $label ) {
		$label = function_exists( 'go_verge_v45_follow_label' )
			? go_verge_v45_follow_label( $object_id, $object_type )
			: ( 'games' === $object_type ? __( 'Seguir jogo', 'go-verge' ) : ( 'productions' === $object_type ? __( 'Seguir produção', 'go-verge' ) : __( 'Seguir assunto', 'go-verge' ) ) );
	}
	if ( ! $subject_name ) {
		if ( in_array( $object_type, array( 'games', 'productions', 'go_entity' ), true ) ) {
			$subject_name = get_the_title( $object_id );
		} elseif ( in_array( $object_type, array( 'post_tag', 'category', 'go_service', 'go_platform' ), true ) ) {
			$term = get_term( $object_id, $object_type );
			if ( $term instanceof WP_Term && ! is_wp_error( $term ) ) { $subject_name = $term->name; }
		}
	}
	$alias = ( $original_id !== $object_id || $original_type !== $object_type ) ? $original_type . ':' . $original_id : '';
	printf(
		'<button type="button" class="go-product-action" data-go-follow data-object-id="%1$d" data-object-type="%2$s" data-follow-default-label="%3$s" data-follow-name="%6$s"%5$s aria-pressed="false"><span aria-hidden="true">＋</span><span data-go-follow-label>%4$s</span></button>',
		$object_id,
		esc_attr( $object_type ),
		esc_attr( $label ),
		esc_html( $label ),
		$alias ? ' data-follow-alias="' . esc_attr( $alias ) . '"' : '',
		esc_attr( $subject_name )
	);

}
function go_verge_product_save_button( $post_id ) {
	printf('<button type="button" class="go-product-action go-product-action--save" data-go-save data-post-id="%1$d" aria-pressed="false">%3$s<span data-go-save-label>%2$s</span></button>',absint($post_id),esc_html__('Salvar','go-verge'),go_verge_icon('salvar','go-interface-icon'));
}

/** Significant editorial update label. */
function go_verge_product_updated_time_html( $post_id ) {
	$published = (int) get_post_time( 'U', true, $post_id );
	$modified  = (int) get_post_modified_time( 'U', true, $post_id );
	if ( ! $published || ! $modified || $modified < $published + 6 * HOUR_IN_SECONDS ) { return ''; }
	$now = (int) current_time( 'timestamp', true );
	$label = sprintf( __( 'há %s', 'go-verge' ), human_time_diff( min( $modified, $now ), $now ) );
	return sprintf( '<time class="go-mono go-time go-time--updated" datetime="%1$s">%2$s</time>', esc_attr( get_post_modified_time( 'c', true, $post_id ) ), esc_html( $label ) );
}

/** Live updates and correction notices. */
function go_verge_product_meta_boxes() {
	add_meta_box( 'go-live-updates', __('Atualizações ao vivo','go-verge'), 'go_verge_render_live_updates_box', 'post', 'normal', 'high' );
	add_meta_box( 'go-correction-note', __('Correção editorial','go-verge'), 'go_verge_render_correction_box', 'post', 'normal', 'default' );
}
add_action( 'add_meta_boxes_post', 'go_verge_product_meta_boxes' );
function go_verge_render_live_updates_box( $post ) {
	$enabled=(bool)get_post_meta($post->ID,'_go_live_enabled',true); $updates=get_post_meta($post->ID,'_go_live_updates',true); if(!is_array($updates)){$updates=array();}
	wp_nonce_field('go_verge_product_meta','go_verge_product_nonce');
	?><p><label><input type="checkbox" name="go_live_enabled" value="1" <?php checked($enabled); ?>> <?php esc_html_e('Marcar matéria como em atualização','go-verge'); ?></label></p>
	<div id="go-live-updates-list"><?php foreach($updates as $row): ?><div class="go-live-update-row" style="display:grid;grid-template-columns:130px 1fr;gap:8px;margin:8px 0;"><input type="datetime-local" name="go_live_time[]" value="<?php echo esc_attr($row['time']??''); ?>"><div><input style="width:100%;margin-bottom:6px" type="text" name="go_live_title[]" value="<?php echo esc_attr($row['title']??''); ?>" placeholder="Título da atualização"><textarea style="width:100%" name="go_live_text[]" rows="3" placeholder="O que mudou"><?php echo esc_textarea($row['text']??''); ?></textarea><button type="button" class="button-link-delete" data-go-remove-live>Remover</button></div></div><?php endforeach; ?></div>
	<p><button type="button" class="button" id="go-add-live-update">Adicionar atualização</button></p>
	<script>document.addEventListener('DOMContentLoaded',function(){var list=document.getElementById('go-live-updates-list'),add=document.getElementById('go-add-live-update');if(!list||!add)return;add.addEventListener('click',function(){var row=document.createElement('div');row.className='go-live-update-row';row.style.cssText='display:grid;grid-template-columns:130px 1fr;gap:8px;margin:8px 0';row.innerHTML='<input type="datetime-local" name="go_live_time[]"><div><input style="width:100%;margin-bottom:6px" type="text" name="go_live_title[]" placeholder="Título da atualização"><textarea style="width:100%" name="go_live_text[]" rows="3" placeholder="O que mudou"></textarea><button type="button" class="button-link-delete" data-go-remove-live>Remover</button></div>';list.prepend(row);});list.addEventListener('click',function(e){if(e.target.matches('[data-go-remove-live]'))e.target.closest('.go-live-update-row').remove();});});</script><?php
}
function go_verge_render_correction_box( $post ) {
	$note=get_post_meta($post->ID,'_go_correction_note',true);$date=go_verge_normalize_correction_date(get_post_meta($post->ID,'_go_correction_date',true));
	?><p><label for="go-correction-note"><strong><?php esc_html_e('O que foi corrigido','go-verge'); ?></strong></label></p><textarea id="go-correction-note" name="go_correction_note" rows="4" style="width:100%"><?php echo esc_textarea($note); ?></textarea><p><label><?php esc_html_e('Data da correção','go-verge'); ?> <input type="date" name="go_correction_date" value="<?php echo esc_attr($date); ?>"></label></p><?php
}
/** Normalize old MySQL timestamps to the date-only value expected by HTML. */
function go_verge_normalize_correction_date( $value ) {
	$value = substr( trim( (string) $value ), 0, 10 );
	if ( ! preg_match( '/^(\d{4})-(\d{2})-(\d{2})$/', $value, $matches ) ) { return ''; }
	return checkdate( (int) $matches[2], (int) $matches[3], (int) $matches[1] ) ? $value : '';
}
function go_verge_save_product_meta( $post_id ) {
	if(!isset($_POST['go_verge_product_nonce'])||!wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['go_verge_product_nonce'])),'go_verge_product_meta')||defined('DOING_AUTOSAVE')&&DOING_AUTOSAVE||!current_user_can('edit_post',$post_id)){return;}
	update_post_meta($post_id,'_go_live_enabled',isset($_POST['go_live_enabled'])?'1':'');
	$times=(array)($_POST['go_live_time']??array());$titles=(array)($_POST['go_live_title']??array());$texts=(array)($_POST['go_live_text']??array());$rows=array();
	for($i=0;$i<max(count($times),count($titles),count($texts));$i++){ $time=sanitize_text_field(wp_unslash($times[$i]??''));$title=sanitize_text_field(wp_unslash($titles[$i]??''));$text=sanitize_textarea_field(wp_unslash($texts[$i]??'')); if($title||$text){$rows[]=compact('time','title','text');} }
	usort($rows,function($a,$b){return strcmp($b['time'],$a['time']);}); update_post_meta($post_id,'_go_live_updates',$rows);
	$old_note=(string)get_post_meta($post_id,'_go_correction_note',true);$old_date=go_verge_normalize_correction_date(get_post_meta($post_id,'_go_correction_date',true));
	$note=sanitize_textarea_field(wp_unslash($_POST['go_correction_note']??''));$raw_date=sanitize_text_field(wp_unslash($_POST['go_correction_date']??''));$date=go_verge_normalize_correction_date($raw_date);
	if($note&&''!==$raw_date&&''===$date){$date=$old_date;}if(!$note){$date='';}
	if($note){update_post_meta($post_id,'_go_correction_note',$note);}else{delete_post_meta($post_id,'_go_correction_note');}
	if($date){update_post_meta($post_id,'_go_correction_date',$date);}else{delete_post_meta($post_id,'_go_correction_date');}
	if($note!==$old_note||$date!==$old_date){update_post_meta($post_id,'_go_search_content_modified_gmt',current_time('mysql',true));if('publish'===get_post_status($post_id)&&function_exists('go_verge_indexing_schedule_websub_publish')){go_verge_indexing_schedule_websub_publish();}}
}
add_action('save_post_post','go_verge_save_product_meta',40);
function go_verge_render_live_updates( $post_id ) {
	if(!get_post_meta($post_id,'_go_live_enabled',true)){return;} $updates=get_post_meta($post_id,'_go_live_updates',true); if(!is_array($updates)||empty($updates)){return;}
	?><section class="go-live-updates" aria-labelledby="go-live-title"><div class="go-live-updates__head"><span class="go-live-updates__pulse" aria-hidden="true"></span><h2 id="go-live-title"><?php esc_html_e('Em atualização','go-verge'); ?></h2></div><ol><?php foreach($updates as $row): ?><li><time datetime="<?php echo esc_attr($row['time']??''); ?>"><?php echo esc_html($row['time']?wp_date('H:i',strtotime($row['time'])):''); ?></time><div><?php if(!empty($row['title'])):?><h3><?php echo esc_html($row['title']); ?></h3><?php endif; ?><p><?php echo nl2br(esc_html($row['text']??'')); ?></p></div></li><?php endforeach; ?></ol></section><?php
}
function go_verge_render_correction_note( $post_id ) {
	$note=trim((string)get_post_meta($post_id,'_go_correction_note',true));if(!$note){return;}$date=go_verge_normalize_correction_date(get_post_meta($post_id,'_go_correction_date',true));$date_object=$date?DateTimeImmutable::createFromFormat('!Y-m-d',$date,wp_timezone()):false;
	?><aside class="go-correction" aria-label="<?php esc_attr_e('Correção editorial','go-verge'); ?>"><strong><?php esc_html_e('Correção','go-verge'); ?></strong><?php if($date&&$date_object): ?><time datetime="<?php echo esc_attr($date); ?>"><?php echo esc_html(wp_date(get_option('date_format'),$date_object->getTimestamp(),wp_timezone())); ?></time><?php endif; ?><p><?php echo nl2br(esc_html($note)); ?></p></aside><?php
}



/** Render accessible toolbar. */
function go_verge_accessibility_toolbar() {
	$is_article = is_singular( 'post' );
	?>
	<aside class="go-a11y<?php echo $is_article ? ' go-a11y--article' : ' go-a11y--site'; ?>" data-go-a11y data-go-a11y-context="<?php echo $is_article ? 'article' : 'site'; ?>" aria-label="Ferramentas de acessibilidade">
		<button type="button" class="go-a11y__toggle" data-go-a11y-toggle aria-expanded="false" aria-controls="go-a11y-panel" aria-label="<?php esc_attr_e( 'Ferramentas de acessibilidade', 'go-verge' ); ?>" title="<?php esc_attr_e( 'Acessibilidade', 'go-verge' ); ?>">
			<span class="go-a11y__label"><?php esc_html_e( 'Acessibilidade', 'go-verge' ); ?></span>
			<svg class="go-a11y__icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
				<circle cx="12" cy="12" r="9.5"></circle>
				<circle cx="12" cy="7" r="1.4"></circle>
				<path d="M7.5 10h9M12 10v4.5M9.4 19l2.6-4.5 2.6 4.5M9 10.5l-1.5 4M15 10.5l1.5 4"></path>
			</svg>
		</button>
		<div class="go-a11y__panel" id="go-a11y-panel" role="dialog" aria-modal="false" aria-labelledby="go-a11y-title" hidden>
			<div class="go-a11y__head">
				<strong id="go-a11y-title"><?php esc_html_e( 'Acessibilidade', 'go-verge' ); ?></strong>
				<button type="button" class="go-a11y__close" data-go-a11y-close aria-label="<?php esc_attr_e( 'Fechar ferramentas de acessibilidade', 'go-verge' ); ?>" onclick="var r=this.closest('[data-go-a11y]'),p=r&&r.querySelector('.go-a11y__panel'),t=r&&r.querySelector('[data-go-a11y-toggle]');if(p){p.hidden=true;}if(t){t.setAttribute('aria-expanded','false');}"><span aria-hidden="true">×</span></button>
			</div>
			<div class="go-a11y__body">
				<?php if ( $is_article ) : ?>
				<div class="go-a11y__row">
					<div class="go-a11y__copy"><strong><?php esc_html_e( 'Tamanho do texto', 'go-verge' ); ?></strong><small><?php esc_html_e( 'Ajuste apenas o corpo da matéria', 'go-verge' ); ?></small></div>
					<div class="go-a11y__stepper" aria-label="<?php esc_attr_e( 'Tamanho do texto', 'go-verge' ); ?>"><button type="button" data-go-font-dec aria-label="<?php esc_attr_e( 'Diminuir texto', 'go-verge' ); ?>">A−</button><button type="button" data-go-font-inc aria-label="<?php esc_attr_e( 'Aumentar texto', 'go-verge' ); ?>">A+</button></div>
				</div>
				<?php endif; ?>
				<div class="go-a11y__row">
					<div class="go-a11y__copy"><strong><?php esc_html_e( 'Contraste', 'go-verge' ); ?></strong><small><?php esc_html_e( 'Reduza ou aumente o contraste', 'go-verge' ); ?></small></div>
					<div class="go-a11y__stepper" aria-label="<?php esc_attr_e( 'Contraste', 'go-verge' ); ?>"><button type="button" data-go-contrast-dec aria-label="<?php esc_attr_e( 'Diminuir contraste', 'go-verge' ); ?>">−</button><button type="button" data-go-contrast-inc aria-label="<?php esc_attr_e( 'Aumentar contraste', 'go-verge' ); ?>">+</button></div>
				</div>
				<?php if ( $is_article ) : ?>
				<button type="button" class="go-a11y__switch-row" data-go-reading-mode aria-pressed="false"><span><strong><?php esc_html_e( 'Modo leitura', 'go-verge' ); ?></strong><small><?php esc_html_e( 'Centraliza a matéria e reduz distrações', 'go-verge' ); ?></small></span><i aria-hidden="true"></i></button>
				<?php endif; ?>
				<button type="button" class="go-a11y__switch-row" data-go-reduce-motion aria-pressed="false"><span><strong><?php esc_html_e( 'Reduzir animações', 'go-verge' ); ?></strong><small><?php esc_html_e( 'Minimiza transições e movimentos', 'go-verge' ); ?></small></span><i aria-hidden="true"></i></button>
				<button type="button" class="go-a11y__reset" data-go-a11y-reset><?php esc_html_e( 'Restaurar padrão', 'go-verge' ); ?></button>
				<span class="screen-reader-text" data-go-a11y-status aria-live="polite"></span>
			</div>
		</div>
	</aside>
	<?php
}
add_action('wp_footer','go_verge_accessibility_toolbar',30);

/** Enqueue front-end product assets. */
function go_verge_product_assets() {
	$css_rel='/assets/css/product-features.min.css';
	$js_rel='/assets/js/product-features.min.js';
	wp_enqueue_style('go-verge-product',GO_VERGE_URI.$css_rel,array('go-verge'),go_verge_asset_version($css_rel));
	wp_enqueue_script('go-verge-product',GO_VERGE_URI.$js_rel,array(),go_verge_asset_version($js_rel),true);
	$current=array(); if(is_singular()){ $id=get_queried_object_id(); $current=array('id'=>$id,'type'=>get_post_type($id),'title'=>get_the_title($id),'url'=>get_permalink($id),'image'=>get_the_post_thumbnail_url($id,'go_card')?:'','excerpt'=>wp_trim_words(get_the_excerpt($id),24,'…')); }
	wp_localize_script('go-verge-product','goProduct',array(
		'rest'=>esc_url_raw(rest_url('go-verge/v1/')),'productRest'=>esc_url_raw(rest_url('go-product/v1/')),'nonce'=>wp_create_nonce('wp_rest'),'current'=>$current,
		'isSinglePost'=>is_singular('post'),'pages'=>array('saved'=>home_url('/salvos/'),'forYou'=>home_url('/para-voce/')),
	));
}
add_action('wp_enqueue_scripts','go_verge_product_assets',1650);


/**
 * Cache-safe REST nonce refresh used only when a cached page carries an expired nonce.
 * The product tracker lives in the companion go-product layer and historically expects
 * X-WP-Nonce even for anonymous pageviews, so removing the header breaks view counting.
 */
function go_verge_product_register_nonce_refresh_route() {
	register_rest_route(
		'go-verge/v1',
		'/rest-nonce',
		array(
			'methods'             => WP_REST_Server::CREATABLE,
			'callback'            => static function () {
				$response = new WP_REST_Response( array( 'nonce' => wp_create_nonce( 'wp_rest' ) ), 200 );
				$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
				$response->header( 'Pragma', 'no-cache' );
				return $response;
			},
			'permission_callback' => '__return_true',
		)
	);
}
add_action( 'rest_api_init', 'go_verge_product_register_nonce_refresh_route', 20 );

/** Track current content only after a meaningful visit; no IP is stored. */
function go_verge_product_tracking_marker() { if(!is_singular(array('post','games','productions','go_entity'))){return;} echo '<meta name="go-track-post" content="'.esc_attr(get_queried_object_id()).'">'; }
add_action('wp_head','go_verge_product_tracking_marker',30);

/** Price chart renderer. */
function go_verge_render_price_history( $game_id ) {
	if(!function_exists('go_product_get_game_price_history')){return;}$history=go_product_get_game_price_history($game_id,730);if(empty($history)){return;}
	$values=array_map(function($row){return(float)$row['price'];},$history);$values=array_values(array_filter($values,function($v){return$v>0;}));if(empty($values)){return;}$min=min($values);$max=max($values);$range=max(0.01,$max-$min);$count=count($values);$points=array();foreach($values as $i=>$value){$x=$count>1?($i/($count-1))*100:50;$y=92-(($value-$min)/$range)*78;$points[]=round($x,2).','.round($y,2);} $rec=function_exists('go_product_price_recommendation')?go_product_price_recommendation($game_id):array();
	// Platform scope: the tracker follows PC digital storefronts (Steam, Epic,
	// GOG…). A game single may also list PS5/Xbox, so state which platform this
	// chart covers and name the store behind the current price instead of
	// leaving readers to guess.
	$current=function_exists('go_product_get_game_current_price')?go_product_get_game_current_price($game_id):array();
	$store=isset($current['store'])?trim((string)$current['store']):'';
	if(''!==$store&&function_exists('go_verge_editorial_display_label')){$store=go_verge_editorial_display_label($store);}
	?><section class="go-price-history"><div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e('Histórico de preço','go-verge'); ?></h2><span class="go-tag go-price-history__platform"><?php esc_html_e('PC','go-verge'); ?></span><?php if($rec): ?><span class="go-price-verdict is-<?php echo esc_attr($rec['tone']); ?>"><?php echo esc_html($rec['label']); ?></span><?php endif; ?></div><p class="go-price-history__scope"><?php esc_html_e('Menor preço em lojas digitais','go-verge'); ?><?php if(''!==$store){ echo ' · '.esc_html(sprintf(__('loja atual: %s','go-verge'),$store)); } ?></p><svg viewBox="0 0 100 100" role="img" aria-label="<?php esc_attr_e('Evolução do menor preço em lojas de PC','go-verge'); ?>"><polyline points="<?php echo esc_attr(implode(' ',$points)); ?>" fill="none" stroke="currentColor" stroke-width="2" vector-effect="non-scaling-stroke"/></svg><div class="go-price-history__stats"><span><?php printf(esc_html__('Menor preço: R$ %s','go-verge'),esc_html(number_format_i18n($min,2))); ?></span><?php if($rec): ?><span><?php printf(esc_html__('Preço atual: R$ %s','go-verge'),esc_html(number_format_i18n($rec['price'],2))); ?></span><?php endif; ?></div></section><?php
}

/** Render price alert form. */
function go_verge_render_price_alert( $game_id ) {
	if(!function_exists('go_product_get_game_current_price')){return;}$current=go_product_get_game_current_price($game_id);$current_price=(is_array($current)&&isset($current['price']))?(float)$current['price']:0;$suggest=$current_price>0?floor($current_price*0.85):100;
	?><section class="go-price-alert" data-go-ad-integrity="atomic" data-go-price-alert data-game-id="<?php echo esc_attr($game_id); ?>"><h2><?php esc_html_e('Alerta de preço','go-verge'); ?></h2><form><label><?php esc_html_e('Avisar quando cair abaixo de','go-verge'); ?><span class="go-money-input">R$ <input type="number" name="target_price" min="1" step="0.01" value="<?php echo esc_attr(number_format($suggest,2,'.','')); ?>"></span></label><label><span><?php esc_html_e('Seu e-mail','go-verge'); ?></span><input type="email" name="email" required autocomplete="email"></label><label class="go-check"><input type="checkbox" name="consent" value="1" required> <span><?php esc_html_e('Aceito receber este alerta e poder cancelá-lo pelo link enviado.','go-verge'); ?></span></label><button class="go-btn go-btn--mint" type="submit"><?php esc_html_e('Criar alerta','go-verge'); ?></button><p data-go-price-alert-status aria-live="polite"></p></form></section><?php
}

/**
 * V41: identify when a person/character is genuinely the headline's lead
 * subject rather than a secondary entity inside a story about a production.
 *
 * Examples:
 * - "Demet Özdemir, de Meu Nome é Farah, ..." => Demet Özdemir.
 * - "Quem é Engin Akyürek, astro de Meu Nome é Farah?" => Engin Akyürek.
 * - "Meu Nome é Farah: Demet e Engin ..." => the production remains primary.
 *
 * Only already-linked/assigned entities can win. This never invents an entity
 * from body copy and therefore keeps the public metadata deterministic.
 */
function go_verge_v41_headline_lead_entity_id( $post_id, $work_name = '' ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || ! post_type_exists( 'go_entity' ) ) { return 0; }

	$title = function_exists( 'go_verge_subject_match_text' )
		? go_verge_subject_match_text( get_the_title( $post_id ) )
		: strtolower( remove_accents( wp_strip_all_tags( get_the_title( $post_id ) ) ) );
	$work = function_exists( 'go_verge_subject_match_text' )
		? go_verge_subject_match_text( $work_name )
		: strtolower( remove_accents( wp_strip_all_tags( (string) $work_name ) ) );
	if ( '' === trim( (string) $title ) ) { return 0; }

	$ids = function_exists( 'go_verge_v7_post_entity_ids' ) ? go_verge_v7_post_entity_ids( $post_id ) : array();
	$tags = get_the_tags( $post_id );
	if ( $tags && ! is_wp_error( $tags ) ) {
		foreach ( $tags as $tag ) {
			$entity = get_page_by_path( $tag->slug, OBJECT, 'go_entity' );
			if ( $entity instanceof WP_Post && 'publish' === $entity->post_status ) { $ids[] = (int) $entity->ID; }
		}
	}
	$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	if ( ! $ids ) { return 0; }

	$work_pos = '' !== $work ? mb_strpos( $title, $work, 0, 'UTF-8' ) : false;
	$best_id = 0;
	$best_score = -999;
	foreach ( $ids as $entity_id ) {
		if ( 'go_entity' !== get_post_type( $entity_id ) || 'publish' !== get_post_status( $entity_id ) ) { continue; }
		$name = function_exists( 'go_verge_subject_match_text' )
			? go_verge_subject_match_text( get_the_title( $entity_id ) )
			: strtolower( remove_accents( wp_strip_all_tags( get_the_title( $entity_id ) ) ) );
		if ( '' === $name || mb_strlen( str_replace( ' ', '', $name ), 'UTF-8' ) < 3 ) { continue; }
		$entity_pos = mb_strpos( $title, $name, 0, 'UTF-8' );
		if ( false === $entity_pos ) { continue; }

		$score = 70;
		if ( 0 === $entity_pos ) { $score += 85; }
		if ( preg_match( '/^(?:quem e|quem foi|onde esta|o que aconteceu com|por que)\s+' . preg_quote( $name, '/' ) . '\b/u', $title ) ) { $score += 105; }
		if ( preg_match( '/^' . preg_quote( $name, '/' ) . '\s+(?:de|da|do|em|estrela|astro|atriz|ator)\b/u', $title ) ) { $score += 65; }

		if ( false === $work_pos ) {
			$score += 35;
		} elseif ( $entity_pos < $work_pos ) {
			$score += 45;
		} else {
			$score -= 35;
		}
		if ( '' !== $work && preg_match( '/^' . preg_quote( $work, '/' ) . '\b/u', $title ) ) { $score -= 65; }

		if ( function_exists( 'go_verge_subject_candidate_evidence' ) ) {
			$evidence = go_verge_subject_candidate_evidence( $post_id, array( get_the_title( $entity_id ), get_post_field( 'post_name', $entity_id ) ) );
			$score += min( 45, (int) ( $evidence['score'] ?? 0 ) * 3 );
		}
		if ( $score > $best_score ) { $best_score = $score; $best_id = $entity_id; }
	}

	/* Deliberately high threshold: an entity only demotes a work when the
	 * headline itself is clearly about that entity. */
	return $best_score >= 150 ? $best_id : 0;
}

/**
 * Resolve one canonical public subject for an article.
 *
 * The public subject is deliberately stricter than tags: it can only point to
 * a published Games or go_entity hub. Automatic mode never creates taxonomy,
 * never exposes broad sections and never guesses when more than one entity is
 * equally plausible.
 */
/** Normalize text for strict subject matching. */
function go_verge_subject_match_text( $value ) {
	$value = html_entity_decode( wp_strip_all_tags( (string) $value ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
	$value = strtolower( remove_accents( $value ) );
	$value = preg_replace( '/[^a-z0-9]+/u', ' ', $value );
	return trim( preg_replace( '/\s+/u', ' ', (string) $value ) );
}

/** Exact phrase match with token boundaries, never a loose body-text mention. */
function go_verge_subject_text_has_phrase( $text, $phrase ) {
	$text   = go_verge_subject_match_text( $text );
	$phrase = go_verge_subject_match_text( $phrase );
	if ( '' === $text || '' === $phrase ) { return false; }
	return false !== strpos( ' ' . $text . ' ', ' ' . $phrase . ' ' );
}

/**
 * Detect when a title only cites a subject as a comparison/reference.
 * "Rival de Stardew Valley" is about the rival, not Stardew Valley itself.
 */
function go_verge_subject_phrase_is_comparison( $text, $phrase ) {
	$text   = go_verge_subject_match_text( $text );
	$phrase = go_verge_subject_match_text( $phrase );
	if ( '' === $text || '' === $phrase ) { return false; }
	$quoted = preg_quote( $phrase, '/' );
	$patterns = array(
		'/\b(?:rival|sucessor|herdeiro|clone|alternativa)\s+(?:direto\s+)?(?:de|do|da|a|ao)?\s*' . $quoted . '\b/u',
		'/\b(?:inspirado|inspirada|baseado|baseada|parecido|parecida|comparado|comparada)\s+(?:em|com|a|ao)?\s*' . $quoted . '\b/u',
		'/\b(?:lembra|imita|mistura|combina)\s+(?:elementos\s+de\s+)?' . $quoted . '\b/u',
		'/\bpara\s+(?:os\s+)?fas\s+de\s+' . $quoted . '\b/u',
	);
	foreach ( $patterns as $pattern ) {
		if ( preg_match( $pattern, $text ) ) { return true; }
	}
	return false;
}

/** Collect featured/content image alt text once per request. */
function go_verge_subject_image_alt_texts( $post_id ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( isset( $cache[ $post_id ] ) ) { return $cache[ $post_id ]; }
	$alts = array();
	$featured_id = get_post_thumbnail_id( $post_id );
	if ( $featured_id ) {
		$alt = trim( (string) get_post_meta( $featured_id, '_wp_attachment_image_alt', true ) );
		if ( '' !== $alt ) { $alts[] = $alt; }
	}
	$content = (string) get_post_field( 'post_content', $post_id );
	if ( preg_match_all( '/<img\b[^>]*\balt\s*=\s*(["\'])(.*?)\1/isu', $content, $matches ) ) {
		foreach ( $matches[2] as $alt ) {
			$alt = trim( html_entity_decode( wp_strip_all_tags( $alt ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) );
			if ( '' !== $alt ) { $alts[] = $alt; }
		}
	}
	if ( preg_match_all( '/\bwp-image-(\d+)\b/i', $content, $ids ) ) {
		foreach ( array_unique( array_map( 'absint', $ids[1] ) ) as $attachment_id ) {
			$alt = trim( (string) get_post_meta( $attachment_id, '_wp_attachment_image_alt', true ) );
			if ( '' !== $alt ) { $alts[] = $alt; }
		}
	}
	$alts = array_values( array_unique( array_filter( array_map( 'trim', $alts ) ) ) );
	return $cache[ $post_id ] = array_slice( $alts, 0, 30 );
}

/** Build the four independent subject signals requested by the editorial team. */
function go_verge_subject_signal_context( $post_id ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( isset( $cache[ $post_id ] ) ) { return $cache[ $post_id ]; }
	$tags = get_the_tags( $post_id );
	$tags = $tags && ! is_wp_error( $tags ) ? array_values( $tags ) : array();
	$content = (string) get_post_field( 'post_content', $post_id );
	$body = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( strip_shortcodes( $content ) ) ) );
	return $cache[ $post_id ] = array(
		'title'   => (string) get_the_title( $post_id ),
		'seo'     => (string) get_post_meta( $post_id, 'rank_math_title', true ),
		'focus'   => (string) get_post_meta( $post_id, 'rank_math_focus_keyword', true ),
		'support' => (string) get_post_meta( $post_id, '_go_post_subtitle', true ),
		'slug'    => (string) get_post_field( 'post_name', $post_id ),
		'tags'    => $tags,
		'alts'    => go_verge_subject_image_alt_texts( $post_id ),
		'body'    => mb_substr( $body, 0, 12000 ),
	);
}

/**
 * Cross title, assigned tag, image alt and Rank Math focus keyword.
 * Body copy is only a weak tie-breaker and can never establish a subject.
 */
function go_verge_subject_candidate_evidence( $post_id, $aliases ) {
	$context = go_verge_subject_signal_context( $post_id );
	$aliases = array_values( array_unique( array_filter( array_map( 'go_verge_subject_match_text', (array) $aliases ) ) ) );
	$aliases = array_values( array_filter( $aliases, static function ( $alias ) { return mb_strlen( str_replace( ' ', '', $alias ) ) >= 3; } ) );
	$signals = array( 'title' => false, 'focus' => false, 'tag' => false, 'alt' => false, 'support' => false, 'slug' => false, 'body' => false );
	foreach ( $aliases as $alias ) {
		$title_match = go_verge_subject_text_has_phrase( $context['title'], $alias ) && ! go_verge_subject_phrase_is_comparison( $context['title'], $alias );
		$seo_match   = go_verge_subject_text_has_phrase( $context['seo'], $alias ) && ! go_verge_subject_phrase_is_comparison( $context['seo'], $alias );
		if ( $title_match || $seo_match ) { $signals['title'] = true; }
		if ( go_verge_subject_text_has_phrase( $context['focus'], $alias ) && ! go_verge_subject_phrase_is_comparison( $context['focus'], $alias ) ) { $signals['focus'] = true; }
		foreach ( $context['tags'] as $tag ) {
			$tag_name = go_verge_subject_match_text( $tag->name );
			$tag_slug = go_verge_subject_match_text( $tag->slug );
			if ( $tag_name === $alias || $tag_slug === $alias ) { $signals['tag'] = true; break; }
		}
		foreach ( $context['alts'] as $alt ) {
			if ( go_verge_subject_text_has_phrase( $alt, $alias ) && ! go_verge_subject_phrase_is_comparison( $alt, $alias ) ) { $signals['alt'] = true; break; }
		}
		if ( go_verge_subject_text_has_phrase( $context['support'], $alias ) && ! go_verge_subject_phrase_is_comparison( $context['support'], $alias ) ) { $signals['support'] = true; }
		if ( go_verge_subject_text_has_phrase( $context['slug'], $alias ) ) { $signals['slug'] = true; }
		if ( go_verge_subject_text_has_phrase( $context['body'], $alias ) && ! go_verge_subject_phrase_is_comparison( $context['body'], $alias ) ) { $signals['body'] = true; }
	}
	$weights = array( 'title' => 6, 'focus' => 6, 'tag' => 5, 'alt' => 4, 'support' => 2, 'slug' => 2, 'body' => 1 );
	$score = 0;
	foreach ( $weights as $signal => $weight ) { if ( ! empty( $signals[ $signal ] ) ) { $score += $weight; } }
	$core_count = 0;
	foreach ( array( 'title', 'focus', 'tag', 'alt' ) as $signal ) { if ( ! empty( $signals[ $signal ] ) ) { $core_count++; } }
	return array(
		'signals'    => $signals,
		'score'      => $score,
		'core_count' => $core_count,
		'accepted'   => $core_count >= 2 && $score >= 9,
	);
}


/**
 * Canonical universe families that should outrank characters, creatures,
 * missions, modes and individual Roblox experiences in public metadata.
 *
 * This list is intentionally small and filterable. It fixes known editorial
 * families while the generic scorer still handles every other topic.
 */
function go_verge_subject_canonical_families() {
	$families = array(
		'black-flag-resynced' => array(
			'label'           => 'Black Flag Resynced',
			'aliases'         => array( 'Assassin\'s Creed Black Flag Resynced', 'Assassins Creed Black Flag Resynced', 'Black Flag Resynced', 'Assassin\'s Creed Black Flag' ),
			'preferred_slugs' => array( 'black-flag-resynced', 'assassins-creed-black-flag-resynced', 'assassins-creed-black-flag' ),
		),
		'fortnite' => array(
			'label'           => 'Fortnite',
			'aliases'         => array( 'Fortnite' ),
			'preferred_slugs' => array( 'fortnite' ),
		),
		'palworld' => array(
			'label'           => 'Palworld',
			'aliases'         => array( 'Palworld' ),
			'preferred_slugs' => array( 'palworld' ),
		),
		'roblox' => array(
			'label'           => 'Roblox',
			/* Experiences are evidence for the parent platform; they must not
			 * become the public subject when Roblox is the useful canonical hub. */
			'aliases'         => array( 'Roblox', 'Adopt Me', 'Adopt Me Roblox', 'Animal Hospital', 'Animal Hospital Roblox', 'Anime RNG', 'Anime RNG Roblox', 'Blox Fruits', 'Brookhaven', 'Dress to Impress' ),
			'preferred_slugs' => array( 'roblox' ),
			'experience_aliases' => array( 'Adopt Me', 'Animal Hospital', 'Anime RNG', 'Blox Fruits', 'Brookhaven', 'Dress to Impress' ),
		),
		'gta' => array(
			'label'           => 'GTA',
			'aliases'         => array( 'GTA', 'GTA Online', 'Grand Theft Auto', 'Grand Theft Auto Online', 'GTA 5', 'GTA V', 'Grand Theft Auto V' ),
			'preferred_slugs' => array( 'gta', 'grand-theft-auto', 'gta-online', 'gta-5', 'grand-theft-auto-v' ),
		),
		'persona' => array(
			'label'           => 'Persona',
			'aliases'         => array( 'Persona', 'Persona 6', 'Persona 5', 'Persona 4', 'Persona 3' ),
			'preferred_slugs' => array( 'persona' ),
			/* "Persona" is also a generic product/engine word. When it only
			 * appears inside one of these compounds, drop the bare alias while
			 * keeping Persona 3/4/5/6 and an explicit Persona tag valid. */
			'ambiguous_aliases' => array( 'Persona' ),
			'blocked_compounds' => array( 'Persona Engine' ),
		),
	);
	return apply_filters( 'go_verge_subject_canonical_families', $families );
}

/** Whether a phrase is used as the world/platform that contains the article topic. */
function go_verge_subject_has_container_relation( $text, $aliases ) {
	$text = go_verge_subject_match_text( $text );
	if ( '' === $text ) { return false; }
	foreach ( (array) $aliases as $alias ) {
		$alias = go_verge_subject_match_text( $alias );
		if ( '' === $alias || go_verge_subject_phrase_is_comparison( $text, $alias ) ) { continue; }
		$quoted = preg_quote( $alias, '/' );
		$patterns = array(
			'/\b(?:em|no|na|nos|nas|dentro de|dentro do|dentro da|para|pelo|pela|do|da|de)\s+(?:o\s+|a\s+)?' . $quoted . '\b/u',
			'/\b(?:jogo|universo|mundo|experiencia|experiência|modo|mapa|servidor)\s+(?:de|do|da|em|no|na)\s+' . $quoted . '\b/u',
		);
		foreach ( $patterns as $pattern ) { if ( preg_match( $pattern, $text ) ) { return true; } }
	}
	return false;
}

/**
 * Pick a known canonical family only when the article itself proves it.
 * This deliberately lets "Shaolong em Palworld" resolve to Palworld and
 * "Anime RNG ... no Roblox" resolve to Roblox, while comparison wording still
 * blocks false assignments such as "rival de Stardew Valley".
 */
function go_verge_subject_canonical_family_candidate( $post_id ) {
	$context = go_verge_subject_signal_context( $post_id );
	$ranked  = array();
	foreach ( go_verge_subject_canonical_families() as $family_key => $family ) {
		$aliases = array_values( array_filter( (array) ( $family['aliases'] ?? array() ) ) );

		/* Some family labels are real franchises and ordinary vocabulary at the
		 * same time. If a known compound owns the occurrence ("Persona Engine"),
		 * ignore only the ambiguous bare alias unless the editor assigned that
		 * exact tag. Specific aliases such as Persona 5 remain untouched. */
		$ambiguous_aliases = array_values( array_filter( (array) ( $family['ambiguous_aliases'] ?? array() ) ) );
		$blocked_compounds = array_values( array_filter( (array) ( $family['blocked_compounds'] ?? array() ) ) );
		if ( $ambiguous_aliases && $blocked_compounds ) {
			$strong_text = implode( ' ', array_merge(
				array( $context['title'] ?? '', $context['seo'] ?? '', $context['focus'] ?? '', $context['support'] ?? '' ),
				(array) ( $context['alts'] ?? array() )
			) );
			$has_blocked_compound = false;
			foreach ( $blocked_compounds as $blocked_compound ) {
				if ( go_verge_subject_text_has_phrase( $strong_text, $blocked_compound ) ) {
					$has_blocked_compound = true;
					break;
				}
			}

			$has_exact_ambiguous_tag = false;
			foreach ( (array) ( $context['tags'] ?? array() ) as $tag ) {
				if ( ! ( $tag instanceof WP_Term ) ) { continue; }
				$tag_name = go_verge_subject_match_text( $tag->name );
				$tag_slug = go_verge_subject_match_text( $tag->slug );
				foreach ( $ambiguous_aliases as $ambiguous_alias ) {
					$ambiguous_key = go_verge_subject_match_text( $ambiguous_alias );
					if ( $tag_name === $ambiguous_key || $tag_slug === $ambiguous_key ) {
						$has_exact_ambiguous_tag = true;
						break 2;
					}
				}
			}

			if ( $has_blocked_compound && ! $has_exact_ambiguous_tag ) {
				$ambiguous_keys = array_map( 'go_verge_subject_match_text', $ambiguous_aliases );
				$aliases = array_values( array_filter( $aliases, static function ( $alias ) use ( $ambiguous_keys ) {
					return ! in_array( go_verge_subject_match_text( $alias ), $ambiguous_keys, true );
				} ) );
			}
		}

		if ( ! $aliases ) { continue; }
		$evidence = go_verge_subject_candidate_evidence( $post_id, $aliases );
		$relation = false;
		foreach ( array( 'title', 'seo', 'focus', 'support', 'body' ) as $field ) {
			if ( go_verge_subject_has_container_relation( $context[ $field ] ?? '', $aliases ) ) { $relation = true; break; }
		}
		$strong = ! empty( $evidence['signals']['title'] ) || ! empty( $evidence['signals']['focus'] ) || ! empty( $evidence['signals']['tag'] ) || ! empty( $evidence['signals']['alt'] );
		$experience_title = false;
		foreach ( (array) ( $family['experience_aliases'] ?? array() ) as $experience_alias ) {
			$experience_alias = go_verge_subject_match_text( $experience_alias );
			if ( '' !== $experience_alias && ( go_verge_subject_text_has_phrase( $context['title'], $experience_alias ) || go_verge_subject_text_has_phrase( $context['seo'], $experience_alias ) ) && ! go_verge_subject_phrase_is_comparison( $context['title'] . ' ' . $context['seo'], $experience_alias ) ) {
				$experience_title = true;
				break;
			}
		}
		$context_pair = $relation && ! empty( $evidence['signals']['support'] ) && ! empty( $evidence['signals']['body'] );
		$accepted = ! empty( $evidence['accepted'] ) || $experience_title || ( $relation && $strong && (int) $evidence['score'] >= 7 ) || $context_pair;
		if ( ! $accepted ) { continue; }
		$score = (int) $evidence['score'] + ( $relation ? 8 : 0 ) + ( $experience_title ? 12 : 0 );
		if ( ! empty( $evidence['signals']['tag'] ) ) { $score += 2; }
		$ranked[ $family_key ] = array( 'family' => $family, 'evidence' => $evidence, 'relation' => $relation, 'score' => $score );
	}
	if ( empty( $ranked ) ) { return null; }
	uasort( $ranked, static function ( $a, $b ) { return (int) $b['score'] <=> (int) $a['score']; } );
	$values = array_values( $ranked );
	if ( isset( $values[1] ) && (int) $values[0]['score'] === (int) $values[1]['score'] ) { return null; }
	return $values[0];
}

/** Broad labels are navigation, not useful article subjects. */
function go_verge_subject_tag_is_specific( WP_Term $tag ) {
	$name_key = go_verge_subject_match_text( $tag->name );
	$slug_key = go_verge_subject_match_text( $tag->slug );
	if ( mb_strlen( str_replace( ' ', '', $name_key ) ) < 3 ) { return false; }
	$broad = array(
		'game','games','jogo','jogos','noticia','noticias','entretenimento','tecnologia','review','reviews','critica','criticas',
		'guia','guias','dica','dicas','especial','especiais','lista','listas','ranking','rankings','pc','mobile','streaming'
	);
	return ! in_array( $name_key, $broad, true ) && ! in_array( $slug_key, $broad, true );
}

/**
 * Resolve one canonical public subject for an article.
 *
 * Automatic mode crosses independent editorial signals: headline/SEO title,
 * Rank Math focus keyword, exact assigned tags and image alt text. Body copy,
 * slug and support line can only break a tie; they never establish the subject
 * by themselves. Comparison wording such as "rival de X" is discounted.
 */
function go_verge_article_subject( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) { return null; }

	$build = null;
	$build = static function ( $object_id, $object_type, $source = 'explicit' ) use ( $post_id, &$build ) {
		$object_id = absint( $object_id );
		if ( ! $object_id || ! in_array( $object_type, array( 'games', 'productions', 'go_entity', 'post_tag' ), true ) ) { return null; }

		if ( 'post_tag' === $object_type ) {
			$term = get_term( $object_id, 'post_tag' );
			if ( ! ( $term instanceof WP_Term ) || (int) $term->count < 2 ) { return null; }
			$url = get_term_link( $term );
			if ( is_wp_error( $url ) ) { return null; }
			return array(
				'id' => (int) $term->term_id, 'type' => 'post_tag', 'name' => $term->name, 'url' => $url,
				'image' => '', 'type_label' => __( 'Assunto', 'go-verge' ), 'related_count' => (int) $term->count, 'source' => $source,
			);
		}

		/* Legacy entity references are resolved at render time to the real
		 * catalogue destination. This prevents old go_entity metadata from
		 * sending readers to a competing /universo/ or /assunto/ page after a
		 * Production/Game hub has become canonical. */
		if ( 'go_entity' === $object_type && function_exists( 'go_verge_v27_entity_canonical_target' ) ) {
			$target = go_verge_v27_entity_canonical_target( $object_id );
			if ( is_array( $target ) && ! empty( $target['target_id'] ) ) {
				$target_type = 'production' === ( $target['kind'] ?? '' ) ? 'productions' : ( 'game' === ( $target['kind'] ?? '' ) ? 'games' : '' );
				if ( $target_type ) {
					return $build( absint( $target['target_id'] ), $target_type, $source . '-canonical' );
				}
			}
		}

		if ( $object_type !== get_post_type( $object_id ) || 'publish' !== get_post_status( $object_id ) ) { return null; }
		$url  = get_permalink( $object_id );
		$name = trim( wp_strip_all_tags( get_the_title( $object_id ) ) );
		if ( ! $url || '' === $name ) { return null; }

		$type_label = __( 'Assunto', 'go-verge' );
		if ( 'games' === $object_type ) {
			$type_label = __( 'Jogo', 'go-verge' );
		} elseif ( 'productions' === $object_type ) {
			$type_label = __( 'Produção', 'go-verge' );
		} elseif ( 'go_entity' === $object_type ) {
			$types = get_the_terms( $object_id, 'go_entity_type' );
			if ( $types && ! is_wp_error( $types ) ) { $type_label = $types[0]->name; }
		}

		$related = function_exists( 'go_verge_product_related_post_ids' )
			? go_verge_product_related_post_ids( $object_id, $object_type, 4, array( 'exclude' => array( $post_id ) ) ) : array();

		return array(
			'id' => $object_id, 'type' => $object_type, 'name' => $name, 'url' => $url,
			'image' => get_the_post_thumbnail_url( $object_id, 'thumbnail' ) ?: '', 'type_label' => $type_label,
			'related_count' => count( $related ), 'source' => $source,
		);
	};

	$build_tag_or_page = static function ( $term_id, $source = 'explicit' ) use ( $build ) {
		$term = get_term( absint( $term_id ), 'post_tag' );
		if ( ! ( $term instanceof WP_Term ) ) { return null; }

		/* V36: ask the unified router first. This also handles title-normalized
		 * matches and structural aliases instead of relying on identical slugs. */
		if ( function_exists( 'go_verge_v36_topic_destination' ) ) {
			$destination = go_verge_v36_topic_destination( $term->slug );
			if ( is_array( $destination ) && ! empty( $destination['id'] ) && in_array( (string) ( $destination['type'] ?? '' ), array( 'games','productions','go_entity' ), true ) ) {
				$subject = $build( absint( $destination['id'] ), (string) $destination['type'], $source . '-canonical' );
				if ( $subject ) { return $subject; }
			}
		}

		/* First-class catalogue pages are always preferred over a generic tag
		 * with the same label. Productions intentionally precede games/entities
		 * because entertainment works such as "Meu Nome é Farah" and "Outer
		 * Banks" must resolve to their production hub, not an imported entity. */
		foreach ( array( 'productions', 'games', 'go_entity' ) as $post_type ) {
			if ( ! post_type_exists( $post_type ) ) { continue; }
			$page = get_page_by_path( $term->slug, OBJECT, $post_type );
			if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
				$subject = $build( (int) $page->ID, $post_type, $source );
				if ( $subject ) { return $subject; }
			}
		}

		if ( function_exists( 'go_verge_tag_preferred_destination' ) ) {
			$preferred = go_verge_tag_preferred_destination( $term );
			if ( $preferred && 'hub' === ( $preferred['type'] ?? '' ) ) {
				foreach ( array( 'productions', 'games', 'go_entity' ) as $post_type ) {
					if ( ! post_type_exists( $post_type ) ) { continue; }
					$page = get_page_by_path( $term->slug, OBJECT, $post_type );
					if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
						$subject = $build( (int) $page->ID, $post_type, $source );
						if ( $subject ) { return $subject; }
					}
				}
			}
		}
		return $build( (int) $term->term_id, 'post_tag', $source );
	};

	$reference = trim( (string) get_post_meta( $post_id, 'go_primary_subject_ref', true ) );
	if ( 'none' === $reference ) { return null; }
	if ( preg_match( '/^(games|productions|go_entity|post_tag):(\d+)$/', $reference, $match ) ) {
		return 'post_tag' === $match[1] ? $build_tag_or_page( (int) $match[2], 'explicit' ) : $build( (int) $match[2], $match[1], 'explicit' );
	}

	foreach ( array( 'go_technical_subject_ref', '_go_review_subject_reference', 'go_review_subject_reference', '_go_review_sheet_subject_reference' ) as $key ) {
		$value = trim( (string) get_post_meta( $post_id, $key, true ) );
		if ( preg_match( '/^(games|productions|go_entity|post_tag):(\d+)$/', $value, $match ) ) {
			$subject = 'post_tag' === $match[1] ? $build_tag_or_page( (int) $match[2], 'explicit' ) : $build( (int) $match[2], $match[1], 'explicit' );
			if ( $subject ) { return $subject; }
		}
	}

	$linked_game       = function_exists( 'go_verge_product_linked_game_id' ) ? go_verge_product_linked_game_id( $post_id ) : 0;
	$linked_production = absint( get_post_meta( $post_id, '_go_production_id', true ) );

	/* Explicit catalogue relationships are stronger than inferred tags/entities.
	 * This is the main guard against a Production such as Meu Nome é Farah
	 * being rendered as a generic /assunto/ link. */
	if ( $linked_game && 'games' === get_post_type( $linked_game ) && 'publish' === get_post_status( $linked_game ) ) {
		$subject = $build( $linked_game, 'games', 'linked' );
		if ( $subject ) { return $subject; }
	}
	if ( $linked_production && 'productions' === get_post_type( $linked_production ) && 'publish' === get_post_status( $linked_production ) ) {
		$subject = $build( $linked_production, 'productions', 'linked' );
		if ( $subject ) { return $subject; }
	}

	/* V41: a named work/game is the default canonical subject, but not a hard
	 * override. If an already-linked person/character clearly leads the headline
	 * ("Demet Özdemir, de Meu Nome é Farah..."), that entity is the better
	 * subject. When the work leads ("Meu Nome é Farah: Demet e Engin..."), the
	 * production remains primary. Explicit editor selections still win above. */
	if ( ( '' === $reference || 'auto' === $reference ) && function_exists( 'go_verge_v19_title_cluster_subject' ) ) {
		$headline_subject = go_verge_v19_title_cluster_subject( $post_id );
		if ( is_array( $headline_subject ) && in_array( (string) ( $headline_subject['type'] ?? '' ), array( 'productions', 'games' ), true ) ) {
			$lead_entity_id = function_exists( 'go_verge_v41_headline_lead_entity_id' )
				? go_verge_v41_headline_lead_entity_id( $post_id, (string) ( $headline_subject['name'] ?? '' ) ) : 0;
			if ( $lead_entity_id ) {
				$lead_entity = $build( $lead_entity_id, 'go_entity', 'headline-lead' );
				if ( $lead_entity ) { return $lead_entity; }
			}
			return $headline_subject;
		}
	}

	$tags        = get_the_tags( $post_id );
	$tags        = $tags && ! is_wp_error( $tags ) ? array_values( $tags ) : array();

	/* Canonical universes outrank narrower creatures, characters, quests and
	 * experience names when the article proves the parent world. This keeps
	 * Palworld, Fortnite, Roblox and Black Flag coverage grouped consistently. */
	$family_candidate = function_exists( 'go_verge_subject_canonical_family_candidate' ) ? go_verge_subject_canonical_family_candidate( $post_id ) : null;
	if ( $family_candidate && ! empty( $family_candidate['family'] ) ) {
		$family = $family_candidate['family'];
		$slugs  = array_values( array_unique( array_filter( array_map( 'sanitize_title', array_merge( (array) ( $family['preferred_slugs'] ?? array() ), (array) ( $family['aliases'] ?? array() ) ) ) ) ) );
		foreach ( $slugs as $slug ) {
			foreach ( array( 'productions', 'games', 'go_entity' ) as $post_type ) {
				if ( 'go_entity' === $post_type && ! post_type_exists( 'go_entity' ) ) { continue; }
				$page = get_page_by_path( $slug, OBJECT, $post_type );
				if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
					$subject = $build( (int) $page->ID, $post_type, 'canonical-family' );
					if ( $subject ) { return $subject; }
				}
			}
			$term = get_term_by( 'slug', $slug, 'post_tag' );
			if ( $term instanceof WP_Term ) {
				$subject = $build_tag_or_page( (int) $term->term_id, 'canonical-family' );
				if ( $subject ) { return $subject; }
			}
		}
		/* Last resort: look up the canonical display label by exact tag name. */
		if ( ! empty( $family['label'] ) ) {
			$term = get_term_by( 'name', (string) $family['label'], 'post_tag' );
			if ( $term instanceof WP_Term ) {
				$subject = $build_tag_or_page( (int) $term->term_id, 'canonical-family' );
				if ( $subject ) { return $subject; }
			}
		}
	}

	/* Game Intelligence may infer a candidate from the article, but the public
	 * subject is accepted only after crossing at least two independent signals:
	 * title/SEO title, assigned tag, image alt and Rank Math focus keyword. */
	if ( ( '' === $reference || 'auto' === $reference ) && function_exists( 'go_verge_game_intelligence_analyze' ) ) {
		$analysis = go_verge_game_intelligence_analyze( $post_id );
		if ( ! empty( $analysis['safe'] ) && ! empty( $analysis['candidate']['id'] ) ) {
			$game_id = absint( $analysis['candidate']['id'] );
			$names   = array( get_the_title( $game_id ), get_post_field( 'post_name', $game_id ) );
			if ( function_exists( 'go_verge_game_intelligence_aliases' ) ) { $names = array_merge( $names, go_verge_game_intelligence_aliases( $game_id ) ); }
			$evidence = go_verge_subject_candidate_evidence( $post_id, $names );
			if ( ! empty( $evidence['accepted'] ) ) {
				$subject = $build( $game_id, 'games', 'automatic' );
				if ( $subject ) { return $subject; }
			}
		}
	}

	/* Entity hubs are candidates only when an assigned tag maps to the hub and
	 * at least one other independent signal confirms it. */
	$entity_candidates = array();
	if ( post_type_exists( 'go_entity' ) ) {
		foreach ( $tags as $tag ) {
			$entity = get_page_by_path( $tag->slug, OBJECT, 'go_entity' );
			if ( ! ( $entity instanceof WP_Post ) || 'publish' !== $entity->post_status ) { continue; }
			$aliases = array( $tag->name, $tag->slug, get_the_title( $entity->ID ), get_post_field( 'post_name', $entity->ID ) );
			$evidence = go_verge_subject_candidate_evidence( $post_id, $aliases );
			if ( ! empty( $evidence['accepted'] ) ) {
				$entity_candidates[ (int) $entity->ID ] = $evidence;
			}
		}
	}
	if ( $entity_candidates ) {
		uasort( $entity_candidates, static function ( $a, $b ) {
			if ( $a['score'] === $b['score'] ) { return $b['core_count'] <=> $a['core_count']; }
			return $b['score'] <=> $a['score'];
		} );
		$ids = array_keys( $entity_candidates );
		$values = array_values( $entity_candidates );
		$top = $values[0];
		$second = $values[1] ?? array( 'score' => 0, 'core_count' => 0 );
		if ( $top['score'] - $second['score'] >= 2 || $top['core_count'] > $second['core_count'] ) {
			$subject = $build( (int) $ids[0], 'go_entity', 'automatic' );
			if ( $subject ) { return $subject; }
		}
	}

	/* Assigned tags are ranked with the same cross-signal model. The tag itself
	 * counts as one signal, so title, focus keyword or image alt must confirm it.
	 * A body mention alone never wins. */
	$tag_scores = array();
	foreach ( $tags as $tag ) {
		if ( ! go_verge_subject_tag_is_specific( $tag ) ) { continue; }
		$evidence = go_verge_subject_candidate_evidence( $post_id, array( $tag->name, $tag->slug ) );
		if ( empty( $evidence['accepted'] ) ) { continue; }
		$evidence['score'] += min( 4, (int) floor( mb_strlen( $tag->name ) / 8 ) );
		$tag_scores[ (int) $tag->term_id ] = $evidence;
	}
	if ( $tag_scores ) {
		uasort( $tag_scores, static function ( $a, $b ) {
			if ( $a['score'] === $b['score'] ) { return $b['core_count'] <=> $a['core_count']; }
			return $b['score'] <=> $a['score'];
		} );
		$ids = array_keys( $tag_scores );
		$values = array_values( $tag_scores );
		$top = $values[0];
		$second = $values[1] ?? array( 'score' => 0, 'core_count' => 0 );
		if ( 0 === $second['score'] || $top['score'] - $second['score'] >= 2 || $top['core_count'] > $second['core_count'] ) {
			return $build_tag_or_page( (int) $ids[0], 'automatic' );
		}
	}

	return null;
}

/** Compact subject link used in chronological-list metadata. */
function go_verge_article_subject_meta_link( $post_id ) {
	/*
	 * Subject resolution (relationship, cluster heuristics and catalog
	 * canonicalization) costs ~40 ms per card and every listing prints 10-20
	 * cards. The result depends on the post and a slowly changing catalog, so it
	 * is memoized per request and cached per post for 6 hours; editing the post
	 * changes the key immediately.
	 */
	static $memo = array();
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return ''; }
	if ( isset( $memo[ $post_id ] ) ) { return $memo[ $post_id ]; }
	$modified = (string) get_post_field( 'post_modified_gmt', $post_id );
	$key      = 'go_subj_link_' . $post_id;
	$cached   = get_transient( $key );
	if ( is_array( $cached ) && isset( $cached['m'], $cached['h'] ) && $cached['m'] === $modified ) {
		return $memo[ $post_id ] = (string) $cached['h'];
	}
	$html = go_verge_article_subject_meta_link_uncached( $post_id );
	set_transient( $key, array( 'm' => $modified, 'h' => $html ), 6 * HOUR_IN_SECONDS );
	return $memo[ $post_id ] = $html;
}

/** Uncached subject meta link. Use go_verge_article_subject_meta_link(). */
function go_verge_article_subject_meta_link_uncached( $post_id ) {
	/*
	 * V36: a real editorial relationship wins before headline/tag heuristics.
	 * The cluster resolver remains useful for old posts that have no structured
	 * relationship, but it may never demote a Production/Game to /assunto/.
	 */
	$base = function_exists( 'go_verge_article_subject' ) ? go_verge_article_subject( $post_id ) : null;
	$subject = $base;
	$base_type = is_array( $base ) ? (string) ( $base['type'] ?? '' ) : '';
	if ( ! in_array( $base_type, array( 'games','productions','go_entity' ), true ) && function_exists( 'go_verge_v17_cluster_subject' ) ) {
		$cluster = go_verge_v17_cluster_subject( $post_id );
		if ( $cluster ) { $subject = $cluster; }
	}

	/* Last-mile canonicalization protects legacy tag/topic results even when old
	 * metadata has not yet been migrated in the database. */
	if ( is_array( $subject ) && in_array( (string) ( $subject['type'] ?? '' ), array( 'post_tag','topic_hub' ), true ) && function_exists( 'go_verge_v36_cluster_catalog_subject' ) ) {
		$canonical = go_verge_v36_cluster_catalog_subject( (string) ( $subject['name'] ?? '' ), 'v36-meta-canonical' );
		if ( $canonical ) { $subject = $canonical; }
	}

	if ( ! $subject || empty( $subject['url'] ) || empty( $subject['name'] ) ) { return ''; }
	$type_label = trim( (string) ( $subject['type_label'] ?? '' ) );
	$aria = $type_label
		? sprintf( __( '%1$s: ver conteúdos sobre %2$s', 'go-verge' ), $type_label, $subject['name'] )
		: sprintf( __( 'Ver conteúdos sobre %s', 'go-verge' ), $subject['name'] );

	return sprintf(
		'<a class="go-archive-row__subject go-archive-row__cluster" href="%1$s" aria-label="%3$s" data-go-subject-type="%4$s">%2$s</a>',
		esc_url( $subject['url'] ),
		esc_html( go_verge_upper( $subject['name'] ) ),
		esc_attr( $aria ),
		esc_attr( sanitize_key( (string) ( $subject['type'] ?? 'topic' ) ) )
	);
}

/** Render the IGN-inspired canonical subject strip on article singles. */
function go_verge_render_article_subject( $post_id ) {
	$subject = go_verge_article_subject( $post_id );
	if ( ! $subject ) {
		return;
	}
	?>
	<aside class="go-article-subject" aria-label="<?php esc_attr_e( 'Assunto principal da matéria', 'go-verge' ); ?>">
		<a class="go-article-subject__link" href="<?php echo esc_url( $subject['url'] ); ?>">
			<?php if ( $subject['image'] ) : ?>
				<span class="go-article-subject__media" aria-hidden="true"><img src="<?php echo esc_url( $subject['image'] ); ?>" alt="" width="50" height="50" loading="lazy" decoding="async" data-go-decorative="1"></span>
			<?php endif; ?>
			<span class="go-article-subject__body">
				<span class="go-article-subject__eyebrow"><?php echo esc_html( $subject['type_label'] ?: __( 'Assunto', 'go-verge' ) ); ?></span>
				<strong class="go-article-subject__title"><?php echo esc_html( $subject['name'] ); ?></strong>
			</span>
			<span class="go-article-subject__cta"><?php esc_html_e( 'Ver tudo', 'go-verge' ); ?><span aria-hidden="true">→</span></span>
		</a>
		<?php if ( function_exists( 'go_verge_product_follow_button' ) ) : ?>
			<div class="go-article-subject__follow"><?php go_verge_product_follow_button( $subject['id'], $subject['type'] ); ?></div>
		<?php endif; ?>
	</aside>
	<?php
}

/** One explicit subject selector for all articles; it never creates terms. */
function go_verge_register_article_subject_meta_box() {
	add_meta_box(
		'go-verge-article-subject',
		__( 'Assunto principal', 'go-verge' ),
		'go_verge_render_article_subject_meta_box',
		'post',
		'side',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_article_subject_meta_box', 40 );

function go_verge_render_article_subject_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_article_subject', 'go_verge_article_subject_nonce' );
	$current = trim( (string) get_post_meta( $post->ID, 'go_primary_subject_ref', true ) );
	$current = $current ?: 'auto';
	$selected_item = function_exists( 'go_verge_editor_catalog_selected_item' ) ? go_verge_editor_catalog_selected_item( $current ) : null;
	?>
	<p style="margin:0 0 8px;"><label for="go-primary-subject-search"><strong><?php esc_html_e( 'Vincular assunto', 'go-verge' ); ?></strong></label></p>
	<input type="search" id="go-primary-subject-search" class="widefat" placeholder="<?php esc_attr_e( 'Digite 2+ letras para buscar…', 'go-verge' ); ?>" autocomplete="off" style="margin-bottom:8px;" data-go-catalog-search data-go-catalog-target="go-primary-subject-ref" data-go-catalog-types="games,productions,go_entity">
	<select id="go-primary-subject-ref" name="go_primary_subject_ref" class="widefat" size="6" style="min-height:148px;">
		<option data-go-catalog-static="1" value="auto" <?php selected( $current, 'auto' ); ?>><?php esc_html_e( 'Automático seguro', 'go-verge' ); ?></option>
		<option data-go-catalog-static="1" value="none" <?php selected( $current, 'none' ); ?>><?php esc_html_e( 'Não exibir assunto', 'go-verge' ); ?></option>
		<?php if ( $selected_item ) : ?><option data-go-catalog-pinned="1" value="<?php echo esc_attr( $selected_item['value'] ); ?>" selected><?php echo esc_html( $selected_item['text'] ); ?></option><?php endif; ?>
	</select>
	<p class="description"><?php esc_html_e( 'Digite para buscar. O automático só usa vínculos inequívocos; nenhuma página é criada sozinha.', 'go-verge' ); ?></p>
	<?php
}

function go_verge_save_article_subject_meta( $post_id ) {
	if ( ! isset( $_POST['go_verge_article_subject_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_article_subject_nonce'] ) ), 'go_verge_save_article_subject' ) ) {
		return;
	}
	if ( ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}
	$value = isset( $_POST['go_primary_subject_ref'] ) ? sanitize_text_field( wp_unslash( $_POST['go_primary_subject_ref'] ) ) : 'auto';
	$valid = in_array( $value, array( 'auto', 'none' ), true );
	if ( ! $valid && preg_match( '/^(games|productions|go_entity|post_tag):(\d+)$/', $value, $match ) ) {
		$id    = absint( $match[2] );
		$valid = $id && $match[1] === get_post_type( $id ) && 'publish' === get_post_status( $id );
	}
	update_post_meta( $post_id, 'go_primary_subject_ref', $valid ? $value : 'auto' );
}
add_action( 'save_post_post', 'go_verge_save_article_subject_meta', 45 );
