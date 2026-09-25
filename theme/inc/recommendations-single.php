<?php
/** Article-only recommendations: evidence first, discovery explicitly separate. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_verge_single_recommendation_eligible( $id, $source_id = 0 ) {
	$post = get_post( absint( $id ) );
	return $post instanceof WP_Post && (int) $post->ID !== (int) $source_id
		&& 'post' === $post->post_type && 'publish' === $post->post_status
		&& '' === $post->post_password && '' !== trim( wp_strip_all_tags( $post->post_title ) )
		&& ( function_exists( 'go_verge_promotion_is_current' ) ? go_verge_promotion_is_current( $post->ID ) : ( ! function_exists( 'go_verge_promotion_has_expired' ) || ! go_verge_promotion_has_expired( $post->ID ) ) );
}

/** Read saved editorial relationships, never infer a subject from the format. */
function go_verge_single_recommendation_context( $post_id ) {
	$desk = function_exists( 'go_verge_post_editorial_desk' ) ? go_verge_post_editorial_desk( $post_id ) : '';
	$subjects = array(); $category_slugs = array();
	foreach ( (array) get_the_terms( $post_id, 'category' ) as $term ) {
		if ( ! $term instanceof WP_Term || ! function_exists( 'go_verge_editorial_category_structure' ) ) { continue; }
		$category_slugs[] = $term->slug;
		foreach ( get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor ) {
			$ancestor_term = get_term( $ancestor, 'category' );
			if ( $ancestor_term instanceof WP_Term ) { $category_slugs[] = $ancestor_term->slug; }
		}
		$structure = go_verge_editorial_category_structure( $term );
		if ( 'subject' !== $structure['role'] || $desk !== $structure['desk'] ) { continue; }
		$subjects[] = (int) $term->term_id;
		foreach ( get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor ) {
			$parent = go_verge_editorial_category_structure( $ancestor );
			if ( 'subject' === $parent['role'] && $desk === $parent['desk'] ) { $subjects[] = (int) $ancestor; }
		}
	}
	$type = function_exists( 'go_verge_v7_post_content_type' ) ? go_verge_v7_post_content_type( $post_id ) : '';
	// A legacy format may label a candidate, but conflicting explicit types stay unknown.
	if ( ! $type && ! go_verge_cached_term_ids( $post_id, 'go_content_type' ) && function_exists( 'go_verge_v7_default_type_for_categories' ) ) {
		$type = go_verge_v7_default_type_for_categories( $category_slugs );
	}
	return array(
		'desk' => $desk, 'subjects' => array_values( array_unique( $subjects ) ), 'type' => $type,
		'tags' => go_verge_cached_term_ids( $post_id, 'post_tag' ),
		'game' => absint( get_post_meta( $post_id, 'go_linked_game_id', true ) ) ?: absint( get_post_meta( $post_id, 'go_review_game_id', true ) ),
		'production' => absint( get_post_meta( $post_id, '_go_production_id', true ) ),
		'entities' => array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) get_post_meta( $post_id, '_go_entity_ids', true ) ) ) ) ), 0, 8 ),
		'subject_ref' => trim( (string) get_post_meta( $post_id, 'go_technical_subject_ref', true ) ),
		'subject_custom' => trim( (string) get_post_meta( $post_id, 'go_technical_subject_custom', true ) ),
	);
}

/** Bounded pools are independent: newer desk news cannot crowd out an exact match. */
function go_verge_single_recommendation_candidates( $post_id, $source ) {
	$base = array( 'post_type'=>'post', 'post_status'=>'publish', 'has_password'=>false,
		'post__not_in'=>array( $post_id ), 'posts_per_page'=>48, 'fields'=>'ids',
		'ignore_sticky_posts'=>true, 'no_found_rows'=>true, 'orderby'=>'date', 'order'=>'DESC', 'go_single_recommendation_pool'=>true );
	$pool = $source['canonical_ids'] ?? array(); $meta = array( 'relation'=>'OR' );
	if ( $source['game'] ) {
		foreach ( array( 'go_linked_game_id', 'go_review_game_id' ) as $key ) { $meta[] = array( 'key'=>$key, 'value'=>$source['game'] ); }
	}
	if ( $source['production'] ) { $meta[] = array( 'key'=>'_go_production_id', 'value'=>$source['production'] ); }
	foreach ( $source['entities'] as $id ) {
		// WordPress legacy metadata contains both serialized integer and string IDs.
		$meta[] = array( 'key'=>'_go_entity_ids', 'value'=>'i:' . $id . ';', 'compare'=>'LIKE' );
		$meta[] = array( 'key'=>'_go_entity_ids', 'value'=>'"' . $id . '"', 'compare'=>'LIKE' );
	}
	if ( $source['subject_ref'] && ! in_array( $source['subject_ref'], array('auto','custom'), true ) ) {
		$meta[] = array( 'key'=>'go_technical_subject_ref', 'value'=>$source['subject_ref'] );
	} elseif ( 'custom' === $source['subject_ref'] && $source['subject_custom'] ) {
		$meta[] = array( 'relation'=>'AND', array('key'=>'go_technical_subject_ref','value'=>'custom'), array('key'=>'go_technical_subject_custom','value'=>$source['subject_custom']) );
	}
	if ( count( $meta ) > 1 ) { $pool = array_merge( $pool, get_posts( array_merge( $base, array('meta_query'=>$meta, 'posts_per_page'=>64) ) ) ); }
	foreach ( array('tags'=>'post_tag', 'subjects'=>'category') as $key=>$taxonomy ) {
		if ( $source[$key] ) {
			$pool = array_merge( $pool, get_posts( array_merge( $base, array( 'tax_query'=>array( array('taxonomy'=>$taxonomy,'terms'=>$source[$key],'include_children'=>true) ) ) ) ) );
		}
	}
	if ( $source['desk'] ) {
		$root = get_term_by( 'slug', $source['desk'], 'category' );
		if ( $root instanceof WP_Term ) {
			$pool = array_merge( $pool, get_posts( array_merge( $base, array( 'tax_query'=>array(array('taxonomy'=>'category','terms'=>array($root->term_id),'include_children'=>true)) ) ) ) );
		}
	}
	$pool = array_values( array_unique( array_map( 'absint', $pool ) ) );
	if ( $pool ) { _prime_post_caches( $pool, false, true ); update_object_term_cache( $pool, 'post' ); }
	return $pool;
}

/** Confidence tiers are sorted before scores; freshness cannot invent affinity. */
function go_verge_single_recommendation_rows( $post_id ) {
	static $memo = array();
	$post_id = absint( $post_id );
	$key = $post_id . ':' . wp_cache_get_last_changed('posts') . ':' . wp_cache_get_last_changed('terms');
	if ( isset( $memo[$key] ) ) { return $memo[$key]; }
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) { return array(); }
	$source = go_verge_single_recommendation_context( $post_id );
	// Preserve the existing canonical subject bridge for older editorial records
	// that predate explicit game/production/entity metadata. No new title guessing.
	$source['canonical_ids'] = array();
	if ( ! $source['game'] && ! $source['production'] && ! $source['entities'] && function_exists('go_verge_v46_primary_subject') && function_exists('go_verge_v17_cluster_post_ids') ) {
		$subject = go_verge_v46_primary_subject($post_id);
		if ( is_array($subject) ) { $source['canonical_ids'] = go_verge_v17_cluster_post_ids($post_id,$subject,6); }
	}
	$rows = array(); $now = time();
	foreach ( go_verge_single_recommendation_candidates( $post_id, $source ) as $id ) {
		if ( ! go_verge_single_recommendation_eligible( $id, $post_id ) ) { continue; }
		$candidate = go_verge_single_recommendation_context( $id );
		if ( $source['desk'] && $source['desk'] !== $candidate['desk'] ) { continue; }
		$score = 0; $tier = $source['desk'] && $source['desk'] === $candidate['desk'] ? 1 : 0;
		if ( in_array($id,$source['canonical_ids'],true) ) { $tier=3; $score+=120; }
		foreach ( array('game','production') as $kind ) {
			if ( $source[$kind] && $source[$kind] === $candidate[$kind] ) { $tier=3; $score+=120; }
		}
		$shared_entities = array_intersect( $source['entities'], $candidate['entities'] );
		if ( $shared_entities ) { $tier=3; $score+=min(120,count($shared_entities)*60); }
		if ( $source['subject_ref'] && ! in_array($source['subject_ref'],array('auto','custom'),true) && $source['subject_ref'] === $candidate['subject_ref'] ) { $tier=3; $score+=120; }
		if ( 'custom' === $source['subject_ref'] && 'custom' === $candidate['subject_ref'] && $source['subject_custom'] && 0 === strcasecmp($source['subject_custom'],$candidate['subject_custom']) ) { $tier=3; $score+=120; }
		$subjects = array_intersect( $source['subjects'], $candidate['subjects'] );
		if ( $subjects ) { $tier=max(2,$tier); $score+=min(60,count($subjects)*30); }
		foreach ( array_intersect( $source['tags'], $candidate['tags'] ) as $tag_id ) {
			$tag = get_term( $tag_id, 'post_tag' );
			if ( ! $tag instanceof WP_Term || in_array( $tag->slug, array('games','entretenimento','tecnologia','ofertas','noticias','review','reviews','guia','guias'), true ) ) { continue; }
			$tier=max(2,$tier); $score+=max(8,min(45,(int)round(270/(6+max(1,$tag->count)))));
		}
		if ( ! $tier ) { continue; }
		$published = (int) get_post_time( 'U', true, $id );
		$score += max( 0, 8 - (int) floor( max(0,$now-$published) / (30*DAY_IN_SECONDS) ) );
		$rows[$id] = array('id'=>$id,'tier'=>$tier,'score'=>$score,'type'=>$candidate['type'],'date'=>$published);
	}
	return $memo[$key] = $rows;
}

/** Diversity only breaks close matches inside the same confidence tier. */
function go_verge_single_recommendation_ids( $post_id, $limit = 6, $exclude = array(), $discovery = false ) {
	$rows = go_verge_single_recommendation_rows( $post_id );
	$exclude = array_merge( array(absint($post_id)), array_map('absint',(array)$exclude) );
	$rows = array_filter($rows,static function($row)use($exclude,$discovery){return !in_array($row['id'],$exclude,true) && ($discovery || $row['tier']>=2) && go_verge_single_recommendation_eligible($row['id']);});
	$picks=array(); $formats=array(); $limit=max(1,min(96,(int)$limit));
	while ( $rows && count($picks)<$limit ) {
		uasort($rows,static function($a,$b)use($formats){
			if($a['tier']!==$b['tier']){return $b['tier']<=>$a['tier'];}
			$a_score=$a['score']-($a['type']?min(18,($formats[$a['type']]??0)*9):0);
			$b_score=$b['score']-($b['type']?min(18,($formats[$b['type']]??0)*9):0);
			return ($b_score<=>$a_score) ?: (($b['date']<=>$a['date']) ?: ($b['id']<=>$a['id']));
		});
		$row=reset($rows); $picks[]=$row['id']; if($row['type']){$formats[$row['type']]=($formats[$row['type']]??0)+1;} unset($rows[$row['id']]);
	}
	return $picks;
}
