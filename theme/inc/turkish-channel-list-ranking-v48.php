<?php
/**
 * Overdrive V48 — context-aware Turkish channel routing and list/ranking topics.
 *
 * Two related fixes:
 * 1. the Turkish WhatsApp CTA follows the canonical editorial graph (category,
 *    linked Production and durable subject), instead of depending on one legacy
 *    category/tag slug;
 * 2. lists/rankings cite a restrained set of first-class works/entities that
 *    are actually named in their item headings, feeding both visible Assuntos
 *    and the contextual internal-link engine.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Normalized comparison key used only for routing/matching. */
function go_verge_v48_key( $value ) {
	$value = remove_accents( wp_strip_all_tags( (string) $value ) );
	$value = mb_strtolower( $value, 'UTF-8' );
	$value = preg_replace( '/[^a-z0-9]+/u', ' ', $value );
	return trim( preg_replace( '/\s+/u', ' ', (string) $value ) );
}

/** Country values that unambiguously identify a Turkish production. */
function go_verge_v48_country_is_turkish( $country ) {
	$key = go_verge_v48_key( $country );
	return in_array( $key, array( 'turquia', 'turkey', 'turkiye', 'turkiye republic', 'turkish' ), true )
		|| false !== strpos( $key, 'turquia' )
		|| false !== strpos( $key, 'turkish' );
}

/**
 * Known durable Turkish works are a fallback for older catalogue entries whose
 * country field was never filled. It is filterable and intentionally contains
 * works already covered by the site, not an open-ended dictionary of Turkish TV.
 */
function go_verge_v48_known_turkish_subjects() {
	return (array) apply_filters( 'go_verge_v48_known_turkish_subjects', array(
		'Meu Nome é Farah', 'Fatmagül', 'A Sonhadora', 'Será Isso Amor?', 'Yargı',
		'Amor Sem Fim', 'Amor Proibido', 'Longe Demais', 'Iludida', 'Jogos do Destino',
		'O Século Magnífico', 'O Indomável', 'Deha', 'Bahar', 'Kızılcık Şerbeti',
		'Dolunay', 'Esqueça-me Se Puder', 'Amor na Ilha',
	) );
}

/** Whether one Production object is Turkish, using metadata first. */
function go_verge_v48_production_is_turkish( $production_id ) {
	$production_id = absint( $production_id );
	if ( ! $production_id || 'productions' !== get_post_type( $production_id ) ) {
		return false;
	}
	$country = (string) get_post_meta( $production_id, '_go_country', true );
	if ( go_verge_v48_country_is_turkish( $country ) ) {
		return true;
	}
	$name = go_verge_v48_key( get_the_title( $production_id ) );
	foreach ( go_verge_v48_known_turkish_subjects() as $known ) {
		if ( $name && $name === go_verge_v48_key( $known ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Resolve Turkish editorial intent without reading a loose body mention.
 * Strong signals only: taxonomy, title/deck/focus phrase, linked Production or
 * the canonical primary Production subject. That keeps a generic Netflix story
 * from being sent to the Turkish channel just because Farah appears once below.
 */
function go_verge_v48_post_is_turkish( $post_id, $cats = array(), $tags = array() ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return false; }
	if ( isset( $cache[ $post_id ] ) ) { return $cache[ $post_id ]; }

	if ( ! $cats ) {
		$cats = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
		$cats = is_wp_error( $cats ) ? array() : (array) $cats;
	}
	if ( ! $tags ) {
		$tags = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'slugs' ) );
		$tags = is_wp_error( $tags ) ? array() : (array) $tags;
	}
	$tax = array_map( 'sanitize_title', array_merge( (array) $cats, (array) $tags ) );
	foreach ( $tax as $slug ) {
		if ( preg_match( '/(?:^|-)(?:producoes?-turcas?|series?-turcas?|novelas?-turcas?|dizi|dizis)(?:-|$)/', $slug ) ) {
			return $cache[ $post_id ] = true;
		}
	}

	$production_id = absint( get_post_meta( $post_id, '_go_production_id', true ) );
	if ( $production_id && go_verge_v48_production_is_turkish( $production_id ) ) {
		return $cache[ $post_id ] = true;
	}

	if ( function_exists( 'go_verge_article_subject' ) ) {
		$subject = go_verge_article_subject( $post_id );
		if ( is_array( $subject ) && 'productions' === (string) ( $subject['type'] ?? '' ) ) {
			$subject_id = absint( $subject['id'] ?? 0 );
			if ( $subject_id && go_verge_v48_production_is_turkish( $subject_id ) ) {
				return $cache[ $post_id ] = true;
			}
			$subject_name = go_verge_v48_key( $subject['name'] ?? '' );
			foreach ( go_verge_v48_known_turkish_subjects() as $known ) {
				if ( $subject_name && $subject_name === go_verge_v48_key( $known ) ) {
					return $cache[ $post_id ] = true;
				}
			}
		}
	}

	$text = get_the_title( $post_id ) . ' ';
	if ( function_exists( 'go_verge_subtitle' ) ) { $text .= (string) go_verge_subtitle( $post_id ) . ' '; }
	$text .= (string) get_post_meta( $post_id, 'rank_math_focus_keyword', true ) . ' ';
	$text .= (string) get_post_meta( $post_id, 'rank_math_description', true );
	$key = go_verge_v48_key( $text );
	if ( preg_match( '/\b(?:novela|novelas|serie|series|producao|producoes) turc(?:a|as|o|os)\b/', $key ) || preg_match( '/\bdizis?\b/', $key ) ) {
		return $cache[ $post_id ] = true;
	}

	/* Older Farah/Fatmagül stories can predate the Production relationship. A
	 * durable work name in headline/deck is still a strong editorial signal. */
	foreach ( go_verge_v48_known_turkish_subjects() as $known ) {
		$needle = go_verge_v48_key( $known );
		if ( mb_strlen( str_replace( ' ', '', $needle ) ) < 4 ) { continue; }
		if ( false !== strpos( ' ' . $key . ' ', ' ' . $needle . ' ' ) ) {
			return $cache[ $post_id ] = true;
		}
	}

	return $cache[ $post_id ] = false;
}

/** Turkish always beats the broad pop/streaming CTA when strong signals agree. */
function go_verge_v48_channel_cluster( $found, $post_id, $cats, $tags ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || ! go_verge_v48_post_is_turkish( $post_id, (array) $cats, (array) $tags ) ) {
		return $found;
	}
	$clusters = function_exists( 'go_verge_channel_invite_clusters' ) ? go_verge_channel_invite_clusters() : array();
	if ( empty( $clusters['turcas'] ) || ! is_array( $clusters['turcas'] ) ) {
		return $found;
	}
	$cluster = $clusters['turcas'];
	$cluster['key'] = 'turcas';
	return $cluster;
}
add_filter( 'go_verge_channel_invite_for_post', 'go_verge_v48_channel_cluster', 5, 4 );

/** Catalogue map used only on list/ranking singles; one compact DB query/request. */
function go_verge_v48_catalogue_map() {
	static $map = null;
	if ( null !== $map ) { return $map; }
	$map = array();
	global $wpdb;
	$rows = $wpdb->get_results(
		"SELECT ID, post_title, post_type, post_name FROM {$wpdb->posts}
		 WHERE post_status='publish' AND post_type IN ('productions','games','go_entity')"
	);
	foreach ( (array) $rows as $row ) {
		$key = go_verge_v48_key( $row->post_title ?? '' );
		if ( ! $key || mb_strlen( str_replace( ' ', '', $key ) ) < 3 ) { continue; }
		$type = sanitize_key( (string) $row->post_type );
		$base = array( 'productions'=>'producoes', 'games'=>'games', 'go_entity'=>'universo' );
		$slug = sanitize_title( (string) ( $row->post_name ?? '' ) );
		if ( ! $slug || empty( $base[ $type ] ) ) { continue; }
		$map[] = array(
			'key' => $key,
			'label' => (string) $row->post_title,
			'url' => home_url( user_trailingslashit( $base[ $type ] . '/' . $slug ) ),
			'type' => $type,
			'len' => mb_strlen( $key ),
		);
	}
	foreach ( array( 'go_service' => 'service', 'go_platform' => 'platform' ) as $taxonomy => $type ) {
		if ( ! taxonomy_exists( $taxonomy ) ) { continue; }
		$terms = get_terms( array( 'taxonomy'=>$taxonomy, 'hide_empty'=>true, 'number'=>200 ) );
		if ( is_wp_error( $terms ) ) { continue; }
		foreach ( $terms as $term ) {
			$key = go_verge_v48_key( $term->name );
			$link = get_term_link( $term );
			if ( ! $key || is_wp_error( $link ) ) { continue; }
			$map[] = array( 'key'=>$key, 'label'=>$term->name, 'url'=>$link, 'type'=>$type, 'len'=>mb_strlen($key) );
		}
	}
	usort( $map, static function ( $a, $b ) { return (int) $b['len'] <=> (int) $a['len']; } );
	return $map;
}

/** Extract stored H2/H3 item headings, preserving ranking numbers when present. */
function go_verge_v48_list_item_headings( $post_id ) {
	$content = (string) get_post_field( 'post_content', absint( $post_id ) );
	if ( '' === trim( $content ) ) { return array(); }
	preg_match_all( '#<h[23]\b[^>]*>(.*?)</h[23]>#isu', $content, $matches );
	$out = array();
	foreach ( (array) ( $matches[1] ?? array() ) as $index => $html ) {
		$text = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $html ) ) );
		if ( ! $text ) { continue; }
		$rank = 0;
		if ( preg_match( '/^\s*(\d{1,3})\s*[\.\)\-–—:]\s*/u', $text, $m ) ) { $rank = absint( $m[1] ); }
		$out[] = array( 'text'=>$text, 'key'=>go_verge_v48_key( $text ), 'position'=>(int)$index, 'rank'=>$rank );
	}
	return $out;
}

/**
 * First-class subjects actually cited by list/ranking item headings.
 * A match must be a complete normalized phrase, not a loose substring.
 */
function go_verge_v48_list_ranking_topics( $post_id, $limit = 6 ) {
	static $cache = array();
	$post_id = absint( $post_id );
	$limit = max( 1, min( 8, absint( $limit ) ) );
	$cache_key = $post_id . ':' . $limit;
	if ( isset( $cache[ $cache_key ] ) ) { return $cache[ $cache_key ]; }
	$is_ranking = function_exists( 'go_verge_post_is_ranking' ) && go_verge_post_is_ranking( $post_id );
	$is_list = function_exists( 'go_verge_post_is_list' ) && go_verge_post_is_list( $post_id );
	if ( ! $is_ranking && ! $is_list ) { return $cache[ $cache_key ] = array(); }

	$headings = go_verge_v48_list_item_headings( $post_id );
	if ( ! $headings ) { return $cache[ $cache_key ] = array(); }
	$catalogue = go_verge_v48_catalogue_map();
	if ( ! $catalogue ) { return $cache[ $cache_key ] = array(); }

	$type_weight = array( 'productions'=>90, 'games'=>90, 'go_entity'=>62, 'service'=>24, 'platform'=>24 );
	$matches = array();
	foreach ( $headings as $heading ) {
		$hay = ' ' . (string) $heading['key'] . ' ';
		foreach ( $catalogue as $item ) {
			$needle = (string) $item['key'];
			if ( ! $needle || false === strpos( $hay, ' ' . $needle . ' ' ) ) { continue; }
			$url_key = untrailingslashit( strtolower( (string) $item['url'] ) );
			if ( isset( $matches[ $url_key ] ) ) { continue; }
			$score = (int) ( $type_weight[ $item['type'] ] ?? 20 ) + min( 50, (int) $item['len'] );
			if ( $is_ranking && ! empty( $heading['rank'] ) ) {
				$score += max( 0, 220 - min( 200, (int) $heading['rank'] ) * 2 );
			} else {
				$score += max( 0, 120 - (int) $heading['position'] * 8 );
			}
			$matches[ $url_key ] = array(
				'label'=>(string)$item['label'], 'url'=>(string)$item['url'],
				'role'=>'mentioned', 'type'=>(string)$item['type'], 'score'=>$score,
			);
		}
	}
	if ( ! $matches ) { return $cache[ $cache_key ] = array(); }
	uasort( $matches, static function ( $a, $b ) {
		if ( (int) $a['score'] === (int) $b['score'] ) { return strcasecmp( $a['label'], $b['label'] ); }
		return (int) $b['score'] <=> (int) $a['score'];
	} );
	$out = array();
	foreach ( array_slice( array_values( $matches ), 0, $limit ) as $item ) {
		unset( $item['score'] );
		$out[] = $item;
	}
	return $cache[ $cache_key ] = $out;
}

/** Primary chips stay first; cited list/ranking works fill the remaining space. */
function go_verge_v48_merge_list_ranking_topics( $post_id, $base, $limit = 6 ) {
	$limit = max( 1, min( 8, absint( $limit ) ) );
	$out = array();
	$seen = array();
	$push = static function ( $item ) use ( &$out, &$seen, $limit ) {
		if ( count( $out ) >= $limit || ! is_array( $item ) || empty( $item['label'] ) || empty( $item['url'] ) ) { return; }
		$key = untrailingslashit( strtolower( (string) $item['url'] ) );
		if ( ! $key || isset( $seen[ $key ] ) ) { return; }
		$seen[ $key ] = true;
		$out[] = array( 'label'=>$item['label'], 'url'=>$item['url'], 'role'=>$item['role'] ?? 'related' );
	};
	foreach ( (array) $base as $item ) {
		if ( 'primary' === (string) ( $item['role'] ?? '' ) ) { $push( $item ); }
	}
	foreach ( go_verge_v48_list_ranking_topics( $post_id, $limit ) as $item ) { $push( $item ); }
	foreach ( (array) $base as $item ) { $push( $item ); }
	return $out;
}

/** Add cited list/ranking works to Article mentions without replacing existing about. */
function go_verge_v48_schema_list_mentions( $data ) {
	if ( ! is_singular( 'post' ) || ! is_array( $data ) ) { return $data; }
	$post_id = absint( get_queried_object_id() );
	$current_url = get_permalink( $post_id );
	$topics = go_verge_v48_list_ranking_topics( $post_id, 8 );
	if ( ! $topics ) { return $data; }
	$nodes = array();
	foreach ( $topics as $topic ) {
		$type = 'Thing';
		if ( 'games' === ( $topic['type'] ?? '' ) ) { $type = 'VideoGame'; }
		elseif ( 'go_entity' === ( $topic['type'] ?? '' ) ) { $type = 'Thing'; }
		elseif ( 'productions' === ( $topic['type'] ?? '' ) ) { $type = 'CreativeWork'; }
		$nodes[] = array( '@type'=>$type, 'name'=>(string)$topic['label'], 'url'=>(string)$topic['url'] );
	}
	foreach ( $data as $key => &$node ) {
		if ( ! is_array( $node ) ) { continue; }
		if ( ! go_verge_schema_node_matches_url( $node, $current_url, array( 'Article','NewsArticle','BlogPosting' ) ) ) { continue; }
		$existing = isset( $node['mentions'] ) ? (array) $node['mentions'] : array();
		$all = array_merge( $existing, $nodes );
		$deduped = array(); $seen = array();
		foreach ( $all as $mention ) {
			if ( ! is_array( $mention ) || empty( $mention['name'] ) ) { continue; }
			$mkey = go_verge_v48_key( $mention['name'] );
			if ( ! $mkey || isset( $seen[ $mkey ] ) ) { continue; }
			$seen[ $mkey ] = true; $deduped[] = $mention;
			if ( count( $deduped ) >= 10 ) { break; }
		}
		if ( $deduped ) { $node['mentions'] = $deduped; }
	}
	unset( $node );
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_v48_schema_list_mentions', 94, 1 );
