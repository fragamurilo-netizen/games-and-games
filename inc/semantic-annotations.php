<?php
/**
 * Optional semantic annotations + conservative automatic inference.
 *
 * Manual editor input supplements automatic analysis. New/updated posts are
 * precomputed on save and legacy posts are backfilled in small WP-Cron batches,
 * so public requests remain read-only and crawlers never trigger inference writes.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Meta keys used by the editor. */
function go_verge_semantic_meta_keys() {
	return array(
		'auto'               => '_go_semantic_auto_enabled',
		'about_entities'     => '_go_semantic_about_entities',
		'mention_entities'   => '_go_semantic_mentions_entities',
		'keywords'           => '_go_semantic_keywords',
		'about_categories'   => '_go_semantic_about_categories',
		'mention_categories' => '_go_semantic_mentions_categories',
	);
}

/** Convert newline/comma separated editor input to a unique string list. */
function go_verge_semantic_sanitize_list( $value ) {
	if ( is_array( $value ) ) {
		$parts = $value;
	} else {
		$parts = preg_split( '/[\r\n,]+/u', (string) $value );
	}
	$out  = array();
	$seen = array();
	foreach ( (array) $parts as $part ) {
		$part = trim( sanitize_text_field( wp_unslash( (string) $part ) ) );
		if ( '' === $part ) {
			continue;
		}
		$key = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $part ) : strtolower( remove_accents( $part ) );
		if ( '' === $key || isset( $seen[ $key ] ) ) {
			continue;
		}
		$seen[ $key ] = true;
		$out[]        = $part;
	}
	return array_slice( $out, 0, 30 );
}

/** Get a stored semantic list. */
function go_verge_semantic_get_list( $post_id, $key ) {
	$keys = go_verge_semantic_meta_keys();
	if ( empty( $keys[ $key ] ) ) {
		return array();
	}
	$value = get_post_meta( $post_id, $keys[ $key ], true );
	return go_verge_semantic_sanitize_list( is_array( $value ) ? $value : (string) $value );
}

/** Automatic analysis is enabled by default unless explicitly disabled. */
function go_verge_semantic_auto_enabled( $post_id ) {
	$key   = go_verge_semantic_meta_keys()['auto'];
	$value = get_post_meta( $post_id, $key, true );
	return '0' !== (string) $value;
}

/** Stable content hash for lazy analysis of old posts. */
function go_verge_semantic_content_hash( $post_id ) {
	$post = get_post( $post_id );
	if ( ! $post ) {
		return '';
	}
	$deck = function_exists( 'go_verge_subtitle' ) ? go_verge_subtitle( $post_id ) : get_post_meta( $post_id, '_go_post_subtitle', true );
	$linked_game = get_post_meta( $post_id, 'go_linked_game_id', true );
	$subject_ref = function_exists( 'go_verge_product_subject_reference' ) ? go_verge_product_subject_reference( $post_id ) : '';
	return md5(
		$post->post_title . "\n" .
		$deck . "\n" .
		$post->post_content . "\n" .
		(string) $linked_game . "\n" .
		(string) $subject_ref . "\n" .
		wp_json_encode( wp_get_post_terms( $post_id, array( 'category', 'post_tag' ), array( 'fields' => 'ids' ) ) )
	);
}

/**
 * Automatic semantic analysis must never create database work on a public
 * request. Generation is allowed only in deliberate editorial/background
 * contexts; front-end rendering is read-only and uses an existing cache.
 */
function go_verge_semantic_generation_allowed( $force = false ) {
	if ( $force ) {
		return true;
	}
	if ( is_admin() ) {
		return true;
	}
	if ( function_exists( 'wp_doing_cron' ) && wp_doing_cron() ) {
		return true;
	}
	if ( defined( 'WP_CLI' ) && WP_CLI ) {
		return true;
	}
	return false;
}

/**
 * Build the graph reference for an addressable internal editorial entity.
 *
 * Games and entity hubs already publish canonical nodes elsewhere in the
 * graph. Reusing those identifiers prevents about/mentions from creating a
 * second, disconnected representation of the same subject. Productions do
 * not currently publish a canonical fragment, so they intentionally keep only
 * their public URL.
 */
function go_verge_semantic_internal_entity_node( $post_id, $name = '' ) {
	$post = get_post( $post_id );
	if ( ! $post || empty( $post->ID ) || 'publish' !== (string) $post->post_status ) {
		return array();
	}

	$post_id   = absint( $post->ID );
	$post_type = (string) $post->post_type;
	if ( ! in_array( $post_type, array( 'games', 'productions', 'go_entity' ), true ) ) {
		return array();
	}

	$url = esc_url_raw( get_permalink( $post_id ) );
	if ( '' === $url ) {
		return array();
	}

	$name = trim( wp_strip_all_tags( (string) $name ) );
	$node = array(
		'@type' => 'CreativeWork',
		'name'  => '' !== $name ? $name : wp_strip_all_tags( get_the_title( $post_id ) ),
		'url'   => $url,
	);

	if ( 'games' === $post_type ) {
		$node['@type'] = 'VideoGame';
		$node['@id']   = $url . '#videogame';
	} elseif ( 'go_entity' === $post_type ) {
		$node['@type'] = function_exists( 'go_verge_entity_schema_type' ) ? go_verge_entity_schema_type( $post_id ) : 'Thing';
		$node['@id']   = $url . '#entity';
	}

	return $node;
}

/** Add a scored candidate to an inference bucket. */
function go_verge_semantic_candidate_add( &$bucket, $name, $score, $type = 'Thing', $url = '', $reason = '', $schema_id = '' ) {
	$name = trim( wp_strip_all_tags( (string) $name ) );
	if ( '' === $name || ( function_exists( 'go_verge_search_is_broad_topic' ) && go_verge_search_is_broad_topic( $name ) ) ) {
		return;
	}
	$key = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $name ) : strtolower( remove_accents( $name ) );
	if ( '' === $key ) {
		return;
	}
	$item = array(
		'name'   => $name,
		'score'  => (int) $score,
		'type'   => $type ?: 'Thing',
		'url'    => $url ? esc_url_raw( $url ) : '',
		'reason' => sanitize_text_field( (string) $reason ),
	);
	if ( $schema_id ) {
		$item['schema_id'] = esc_url_raw( $schema_id );
	}
	if ( ! isset( $bucket[ $key ] ) || $item['score'] > (int) $bucket[ $key ]['score'] ) {
		$bucket[ $key ] = $item;
	}
}

/** Phrase occurrence count with word boundaries. */
function go_verge_semantic_phrase_count( $label, $text ) {
	$needle = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $label ) : strtolower( remove_accents( (string) $label ) );
	$text   = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $text ) : strtolower( remove_accents( (string) $text ) );
	if ( '' === $needle || '' === $text ) {
		return 0;
	}
	return substr_count( ' ' . $text . ' ', ' ' . $needle . ' ' );
}

/** Resolve an internal URL to a useful editorial entity candidate. */
function go_verge_semantic_internal_link_candidates( $post_id, &$about, &$mentions, $title_text, $deck_text, $body_text ) {
	$content = (string) get_post_field( 'post_content', $post_id );
	if ( ! preg_match_all( '/<a\b[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)<\/a>/isu', $content, $matches, PREG_SET_ORDER ) ) {
		return;
	}
	foreach ( $matches as $match ) {
		$url       = esc_url_raw( html_entity_decode( $match[1], ENT_QUOTES, get_bloginfo( 'charset' ) ) );
		$target_id = url_to_postid( $url );
		if ( ! $target_id || $target_id === (int) $post_id ) {
			continue;
		}
		$type = get_post_type( $target_id );
		if ( ! in_array( $type, array( 'games', 'productions', 'go_entity' ), true ) || 'publish' !== get_post_status( $target_id ) ) {
			continue;
		}
		$name      = get_the_title( $target_id );
		$strong    = go_verge_semantic_phrase_count( $name, $title_text . ' ' . $deck_text ) > 0;
		$reference = go_verge_semantic_internal_entity_node( $target_id, $name );
		if ( empty( $reference ) ) {
			continue;
		}
		if ( $strong ) {
			go_verge_semantic_candidate_add( $about, $name, 88, $reference['@type'], $reference['url'], 'link interno + título/linha de apoio', $reference['@id'] ?? '' );
		} else {
			go_verge_semantic_candidate_add( $mentions, $name, 72, $reference['@type'], $reference['url'], 'link interno contextual', $reference['@id'] ?? '' );
		}
	}
}

/** Extract repeated proper-name phrases as keyword candidates only. */
function go_verge_semantic_proper_phrase_keywords( $title, $deck, $content ) {
	$text = wp_strip_all_tags( strip_shortcodes( $title . ' ' . $deck . ' ' . $content ) );
	if ( ! preg_match_all( '/\b(?:[A-ZÁÉÍÓÚÀÂÊÔÃÕÇ][\p{L}\p{N}\'’.-]{2,})(?:\s+(?:[A-ZÁÉÍÓÚÀÂÊÔÃÕÇ][\p{L}\p{N}\'’.-]{2,}|of|the|de|da|do|dos|das|and|e)){1,4}\b/u', $text, $matches ) ) {
		return array();
	}
	/*
	 * The pattern allows connector words inside a proper phrase ("CEO da Sony
	 * Group", "Wall Street Journal"), which also lets a match END on one. A
	 * sentence opening with a capitalised common noun then produced fragments
	 * like "Escassez e" — shipped verbatim into schema `keywords`, where a
	 * truncated n-gram is worse than no keyword at all.
	 *
	 * Trimming trailing connectors turns those fragments into a single word,
	 * which the >= 2 token rule below then rejects, while genuine multi-word
	 * proper names survive untouched.
	 */
	$connectors = array( 'of', 'the', 'de', 'da', 'do', 'dos', 'das', 'and', 'e' );
	$cleaned    = array();
	foreach ( $matches[0] as $match ) {
		$tokens = preg_split( '/\s+/u', trim( (string) $match ), -1, PREG_SPLIT_NO_EMPTY );
		if ( ! is_array( $tokens ) ) {
			continue;
		}
		while ( $tokens ) {
			$last = (string) end( $tokens );
			$last = function_exists( 'mb_strtolower' ) ? mb_strtolower( $last, 'UTF-8' ) : strtolower( $last );
			if ( ! in_array( $last, $connectors, true ) ) {
				break;
			}
			array_pop( $tokens );
		}
		if ( count( $tokens ) < 2 ) {
			continue;
		}
		$cleaned[] = implode( ' ', $tokens );
	}
	if ( ! $cleaned ) {
		return array();
	}

	$counts = array_count_values( $cleaned );
	arsort( $counts );
	$out = array();
	$site_name_key = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( get_bloginfo( 'name' ) ) : strtolower( remove_accents( get_bloginfo( 'name' ) ) );
	foreach ( $counts as $phrase => $count ) {
		$phrase_key = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $phrase ) : strtolower( remove_accents( $phrase ) );
		if ( $site_name_key && $phrase_key === $site_name_key ) {
			continue;
		}
		if ( $count < 2 && 0 === go_verge_semantic_phrase_count( $phrase, $title . ' ' . $deck ) ) {
			continue;
		}
		if ( function_exists( 'go_verge_search_is_broad_topic' ) && go_verge_search_is_broad_topic( $phrase ) ) {
			continue;
		}
		$out[] = $phrase;
		if ( count( $out ) >= 8 ) {
			break;
		}
	}
	return $out;
}

/**
 * Conservative automatic semantic analysis. Cached for old and new posts.
 *
 * @return array{about:array,mentions:array,keywords:array,categories_about:array,categories_mentions:array,hash:string}
 */
function go_verge_semantic_auto_analysis( $post_id, $force = false ) {
	$post_id = absint( $post_id );
	$empty   = array( 'about' => array(), 'mentions' => array(), 'keywords' => array(), 'categories_about' => array(), 'categories_mentions' => array(), 'hash' => '' );
	$post    = get_post( $post_id );
	if ( ! $post || 'post' !== $post->post_type ) {
		return $empty;
	}
	$cached       = get_post_meta( $post_id, '_go_semantic_auto_cache', true );
	$can_generate = go_verge_semantic_generation_allowed( $force );

	// Public rendering is strictly read-only. Cache invalidation happens on
	// content/taxonomy saves, so crawlers avoid hash + taxonomy work too.
	if ( ! $can_generate ) {
		return is_array( $cached ) && ! empty( $cached['hash'] ) ? array_merge( $empty, $cached ) : $empty;
	}

	$hash = go_verge_semantic_content_hash( $post_id );
	if ( ! $force && is_array( $cached ) && ! empty( $cached['hash'] ) && hash_equals( (string) $cached['hash'], $hash ) ) {
		return array_merge( $empty, $cached );
	}

	$title   = (string) $post->post_title;
	$deck    = function_exists( 'go_verge_subtitle' ) ? (string) go_verge_subtitle( $post_id ) : (string) get_post_meta( $post_id, '_go_post_subtitle', true );
	$content = (string) $post->post_content;
	$body    = wp_strip_all_tags( strip_shortcodes( $content ) );
	$all     = $title . ' ' . $deck . ' ' . $body;
	$about   = array();
	$mentions = array();
	$cat_about = array();
	$cat_mentions = array();

	// Explicit linked game is the strongest signal available in this product.
	if ( function_exists( 'go_verge_product_linked_game_id' ) ) {
		$game_id = absint( go_verge_product_linked_game_id( $post_id ) );
		$game    = $game_id ? go_verge_semantic_internal_entity_node( $game_id ) : array();
		if ( $game && 'VideoGame' === $game['@type'] ) {
			go_verge_semantic_candidate_add( $about, $game['name'], 100, $game['@type'], $game['url'], 'jogo vinculado pelo editor', $game['@id'] ?? '' );
		}
	}

	// Explicit subject entity is also trusted.
	if ( function_exists( 'go_verge_product_subject_reference' ) ) {
		$reference = (string) go_verge_product_subject_reference( $post_id );
		if ( preg_match( '/^go_entity:(\d+)$/', $reference, $m ) ) {
			$entity_id = absint( $m[1] );
			$entity    = $entity_id ? go_verge_semantic_internal_entity_node( $entity_id ) : array();
			if ( $entity && 'go_entity' === get_post_type( $entity_id ) ) {
				go_verge_semantic_candidate_add( $about, $entity['name'], 98, $entity['@type'], $entity['url'], 'entidade vinculada pelo editor', $entity['@id'] ?? '' );
			}
		}
	}

	go_verge_semantic_internal_link_candidates( $post_id, $about, $mentions, $title, $deck, $body );

	// Tags require evidence and receive stronger scores when present in title/deck.
	$tags = get_the_tags( $post_id );
	if ( $tags && ! is_wp_error( $tags ) ) {
		foreach ( $tags as $tag ) {
			$name = $tag->name;
			if ( function_exists( 'go_verge_search_is_broad_topic' ) && go_verge_search_is_broad_topic( $name ) ) {
				continue;
			}
			$in_title = go_verge_semantic_phrase_count( $name, $title );
			$in_deck  = go_verge_semantic_phrase_count( $name, $deck );
			$in_body  = go_verge_semantic_phrase_count( $name, $body );
			if ( ! $in_title && ! $in_deck && ! $in_body ) {
				continue;
			}
			$score = 45 + min( 20, $in_body * 4 ) + ( $in_deck ? 18 : 0 ) + ( $in_title ? 28 : 0 );

			/*
			 * Prefer a real entity page over the tag archive.
			 *
			 * A tag archive is a listing, and on this install tag archives are
			 * noindex, so declaring one as the canonical URL of an entity points
			 * every consumer — Google's entity pipeline and any LLM reading the
			 * graph — at a page the site itself asks not to index. When a games or
			 * go_entity hub carries the same name it is the addressable entity and
			 * gets typed accordingly; the tag link stays as the fallback.
			 */
			$resolved = go_verge_semantic_label_node( $name );
			$type     = ! empty( $resolved['@type'] ) ? (string) $resolved['@type'] : 'Thing';
			if ( ! empty( $resolved['url'] ) ) {
				$link = (string) $resolved['url'];
			} else {
				$tag_link = get_tag_link( $tag );
				$link     = is_wp_error( $tag_link ) ? '' : $tag_link;
			}

			if ( $score >= 78 ) {
				go_verge_semantic_candidate_add( $about, $name, $score, $type, $link, 'tag comprovada pelo texto', $resolved['@id'] ?? '' );
			} else {
				go_verge_semantic_candidate_add( $mentions, $name, $score, $type, $link, 'tag citada no texto', $resolved['@id'] ?? '' );
			}
		}
	}

	// Specific categories are treated separately and never promoted just for existing.
	$categories = get_the_category( $post_id );
	foreach ( (array) $categories as $category ) {
		if ( ! ( $category instanceof WP_Term ) || ( function_exists( 'go_verge_search_is_broad_topic' ) && go_verge_search_is_broad_topic( $category->name ) ) ) {
			continue;
		}
		$count_title = go_verge_semantic_phrase_count( $category->name, $title );
		$count_deck  = go_verge_semantic_phrase_count( $category->name, $deck );
		$count_body  = go_verge_semantic_phrase_count( $category->name, $body );
		if ( ! $count_title && ! $count_deck && ! $count_body ) {
			continue;
		}
		$item = array( 'name' => $category->name, 'url' => is_wp_error( get_category_link( $category ) ) ? '' : get_category_link( $category ), 'score' => 50 + ( $count_title ? 25 : 0 ) + ( $count_deck ? 15 : 0 ) + min( 10, $count_body * 2 ) );
		if ( $item['score'] >= 75 ) {
			$cat_about[] = $item;
		} else {
			$cat_mentions[] = $item;
		}
	}

	// Proper names are useful as keywords, but never automatically asserted as about/mentions.
	$keywords = go_verge_semantic_proper_phrase_keywords( $title, $deck, $content );
	foreach ( array_merge( array_values( $about ), array_values( $mentions ) ) as $candidate ) {
		$keywords[] = $candidate['name'];
	}
	$keywords = go_verge_semantic_sanitize_list( $keywords );

	$sort = static function ( &$items ) {
		usort( $items, static function ( $a, $b ) { return (int) $b['score'] <=> (int) $a['score']; } );
	};
	$about_values   = array_values( $about );
	$mention_values = array_values( $mentions );
	$sort( $about_values );
	$sort( $mention_values );
	$sort( $cat_about );
	$sort( $cat_mentions );

	$result = array(
		'about'               => array_slice( $about_values, 0, 5 ),
		'mentions'            => array_slice( $mention_values, 0, 8 ),
		'keywords'            => array_slice( $keywords, 0, 15 ),
		'categories_about'    => array_slice( $cat_about, 0, 4 ),
		'categories_mentions' => array_slice( $cat_mentions, 0, 5 ),
		'hash'                => $hash,
		'generated_at'        => gmdate( 'c' ),
	);

	// Cache only in deliberate editorial/background contexts. Public requests
	// are read-only so the first Googlebot visit never triggers a write.
	update_post_meta( $post_id, '_go_semantic_auto_cache', $result );
	return $result;
}

/** Convert a manual/free label into a schema node, reusing known internal URLs when possible. */
function go_verge_semantic_label_node( $label, $preferred_type = 'Thing' ) {
	$label = trim( wp_strip_all_tags( (string) $label ) );
	$node  = array( '@type' => $preferred_type ?: 'Thing', 'name' => $label );
	if ( '' === $label ) {
		return array();
	}

	foreach ( array( 'productions', 'games', 'go_entity' ) as $type ) {
		$found = get_posts( array(
			'post_type'              => $type,
			'post_status'            => 'publish',
			'title'                  => $label,
			'posts_per_page'         => 1,
			'no_found_rows'          => true,
			'suppress_filters'       => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		) );
		if ( $found ) {
			$resolved = go_verge_semantic_internal_entity_node( $found[0], $label );
			return $resolved ?: $node;
		}
	}
	return $node;
}

/**
 * Convert an automatic candidate to a graph node.
 *
 * Old cache rows predate schema_id. Resolve their internal URL on read so a
 * deployment gains coherent @ids immediately without forcing a mass rewrite.
 */
function go_verge_semantic_candidate_node( $candidate ) {
	if ( ! is_array( $candidate ) || empty( $candidate['name'] ) ) {
		return array();
	}

	$name = trim( wp_strip_all_tags( (string) $candidate['name'] ) );
	$node = array(
		'@type' => ! empty( $candidate['type'] ) ? (string) $candidate['type'] : 'Thing',
		'name'  => $name,
	);
	$url = ! empty( $candidate['url'] ) ? esc_url_raw( $candidate['url'] ) : '';
	if ( $url ) {
		$node['url'] = $url;
	}
	if ( ! empty( $candidate['schema_id'] ) ) {
		$node['@id'] = esc_url_raw( $candidate['schema_id'] );
		return $node;
	}
	if ( $url ) {
		$post_id = absint( url_to_postid( $url ) );
		if ( $post_id ) {
			$internal = go_verge_semantic_internal_entity_node( $post_id, $name );
			if ( $internal ) {
				return $internal;
			}
		}
	}
	return $node;
}

/** Convert a manual category label to a Thing with archive URL when possible. */
function go_verge_semantic_category_node( $label ) {
	$label = trim( wp_strip_all_tags( (string) $label ) );
	$node  = array( '@type' => 'Thing', 'name' => $label );
	if ( '' === $label ) {
		return array();
	}
	$term = get_term_by( 'name', $label, 'category' );
	if ( ! $term ) {
		$term = get_term_by( 'slug', sanitize_title( $label ), 'category' );
	}
	if ( $term instanceof WP_Term ) {
		$link = get_term_link( $term );
		if ( ! is_wp_error( $link ) ) {
			$node['url'] = $link;
		}
	}
	return $node;
}

/** De-duplicate schema nodes by normalized name. */
function go_verge_semantic_unique_nodes( $nodes, $limit = 10 ) {
	$out  = array();
	$seen = array();
	foreach ( (array) $nodes as $node ) {
		if ( ! is_array( $node ) || empty( $node['name'] ) ) {
			continue;
		}
		$key = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $node['name'] ) : strtolower( remove_accents( $node['name'] ) );
		if ( '' === $key || isset( $seen[ $key ] ) ) {
			continue;
		}
		$seen[ $key ] = true;
		$out[]        = $node;
		if ( count( $out ) >= $limit ) {
			break;
		}
	}
	return $out;
}

/**
 * Resolved semantic graph. Manual values are authoritative additions; automatic
 * inference supplements them only when enabled.
 */
function go_verge_semantic_resolved( $post_id ) {
	$post_id = absint( $post_id );
	$about   = array();
	$mentions = array();

	foreach ( go_verge_semantic_get_list( $post_id, 'about_entities' ) as $label ) {
		$about[] = go_verge_semantic_label_node( $label );
	}
	foreach ( go_verge_semantic_get_list( $post_id, 'about_categories' ) as $label ) {
		$about[] = go_verge_semantic_category_node( $label );
	}
	foreach ( go_verge_semantic_get_list( $post_id, 'mention_entities' ) as $label ) {
		$mentions[] = go_verge_semantic_label_node( $label );
	}
	foreach ( go_verge_semantic_get_list( $post_id, 'mention_categories' ) as $label ) {
		$mentions[] = go_verge_semantic_category_node( $label );
	}

	$keywords = go_verge_semantic_get_list( $post_id, 'keywords' );
	$auto     = array();
	if ( go_verge_semantic_auto_enabled( $post_id ) ) {
		$auto = go_verge_semantic_auto_analysis( $post_id );
		foreach ( (array) $auto['about'] as $candidate ) {
			$node = go_verge_semantic_candidate_node( $candidate );
			if ( $node ) { $about[] = $node; }
		}
		foreach ( (array) $auto['categories_about'] as $candidate ) {
			$node = array( '@type' => 'Thing', 'name' => $candidate['name'] );
			if ( ! empty( $candidate['url'] ) ) { $node['url'] = $candidate['url']; }
			$about[] = $node;
		}
		foreach ( (array) $auto['mentions'] as $candidate ) {
			$node = go_verge_semantic_candidate_node( $candidate );
			if ( $node ) { $mentions[] = $node; }
		}
		foreach ( (array) $auto['categories_mentions'] as $candidate ) {
			$node = array( '@type' => 'Thing', 'name' => $candidate['name'] );
			if ( ! empty( $candidate['url'] ) ) { $node['url'] = $candidate['url']; }
			$mentions[] = $node;
		}
		$keywords = array_merge( $keywords, (array) $auto['keywords'] );
	}

	$about    = go_verge_semantic_unique_nodes( $about, 6 );
	$mentions = go_verge_semantic_unique_nodes( $mentions, 10 );
	$about_keys = array();
	foreach ( $about as $node ) {
		$about_keys[ function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $node['name'] ) : strtolower( $node['name'] ) ] = true;
	}
	$mentions = array_values( array_filter( $mentions, static function ( $node ) use ( $about_keys ) {
		$key = function_exists( 'go_verge_search_normalize_text' ) ? go_verge_search_normalize_text( $node['name'] ) : strtolower( $node['name'] );
		return ! isset( $about_keys[ $key ] );
	} ) );

	$keywords = go_verge_semantic_sanitize_list( array_merge( $keywords, wp_list_pluck( $about, 'name' ), wp_list_pluck( $mentions, 'name' ) ) );
	return array( 'about' => $about, 'mentions' => $mentions, 'keywords' => array_slice( $keywords, 0, 20 ), 'auto' => $auto );
}

/** Register the semantic annotation metabox. */
function go_verge_semantic_register_metabox() {
	add_meta_box(
		'go-verge-semantic-annotation',
		__( 'Anotação semântica', 'go-verge' ),
		'go_verge_semantic_render_metabox',
		'post',
		'normal',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_semantic_register_metabox', 22 );

/** Render one chip editor section. */
function go_verge_semantic_render_chip_field( $post_id, $field_key, $label, $description ) {
	$keys   = go_verge_semantic_meta_keys();
	$values = go_verge_semantic_get_list( $post_id, $field_key );
	$name   = 'go_semantic_' . $field_key;
	?>
	<section class="go-semantic-field" data-go-semantic-field="<?php echo esc_attr( $field_key ); ?>">
		<div class="go-semantic-field__head">
			<div><strong><?php echo esc_html( $label ); ?></strong><p><?php echo esc_html( $description ); ?></p></div>
			<span class="go-semantic-field__count" data-go-semantic-count><?php echo (int) count( $values ); ?></span>
		</div>
		<div class="go-semantic-chips" data-go-semantic-chips>
			<?php foreach ( $values as $value ) : ?>
				<span class="go-semantic-chip" data-value="<?php echo esc_attr( $value ); ?>"><span><?php echo esc_html( $value ); ?></span><button type="button" aria-label="<?php echo esc_attr( sprintf( __( 'Remover %s', 'go-verge' ), $value ) ); ?>">×</button></span>
			<?php endforeach; ?>
		</div>
		<div class="go-semantic-input-row">
			<input type="text" data-go-semantic-input placeholder="<?php esc_attr_e( 'Insira um termo e pressione Enter', 'go-verge' ); ?>" autocomplete="off">
			<button type="button" class="button" data-go-semantic-add><?php esc_html_e( 'Adicionar', 'go-verge' ); ?></button>
		</div>
		<input type="hidden" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( implode( "\n", $values ) ); ?>" data-go-semantic-hidden>
	</section>
	<?php
}

/** Metabox UI, intentionally compact but richer than legacy meta boxes. */
function go_verge_semantic_render_metabox( $post ) {
	wp_nonce_field( 'go_verge_semantic_save', 'go_verge_semantic_nonce' );
	$auto_enabled = go_verge_semantic_auto_enabled( $post->ID );
	$auto         = go_verge_semantic_auto_analysis( $post->ID );
	?>
	<div class="go-semantic-panel">
		<header class="go-semantic-panel__intro">
			<div>
				<span class="go-semantic-panel__eyebrow"><?php esc_html_e( 'Grafo editorial', 'go-verge' ); ?></span>
				<h3><?php esc_html_e( 'O que a matéria trata e o que apenas cita', 'go-verge' ); ?></h3>
				<p><?php esc_html_e( 'O preenchimento manual complementa a análise automática. Nada é obrigatório.', 'go-verge' ); ?></p>
			</div>
			<label class="go-semantic-toggle">
				<input type="checkbox" name="go_semantic_auto_enabled" value="1" <?php checked( $auto_enabled ); ?>>
				<span><?php esc_html_e( 'Completar automaticamente', 'go-verge' ); ?></span>
			</label>
		</header>

		<div class="go-semantic-auto-preview">
			<div class="go-semantic-auto-preview__head"><strong><?php esc_html_e( 'Leitura automática atual', 'go-verge' ); ?></strong><span><?php esc_html_e( 'Também vale para matérias antigas', 'go-verge' ); ?></span></div>
			<div class="go-semantic-auto-preview__groups">
				<div><small>ABOUT</small><p><?php echo esc_html( implode( ' · ', wp_list_pluck( array_slice( (array) $auto['about'], 0, 4 ), 'name' ) ) ?: 'Nenhum assunto forte ainda' ); ?></p></div>
				<div><small>MENTIONS</small><p><?php echo esc_html( implode( ' · ', wp_list_pluck( array_slice( (array) $auto['mentions'], 0, 5 ), 'name' ) ) ?: 'Nenhuma menção confiável ainda' ); ?></p></div>
			</div>
		</div>

		<div class="go-semantic-grid">
			<?php
			go_verge_semantic_render_chip_field( $post->ID, 'about_entities', __( 'Trata entidade', 'go-verge' ), __( 'Assuntos centrais: jogos, pessoas, empresas, franquias ou produtos.', 'go-verge' ) );
			go_verge_semantic_render_chip_field( $post->ID, 'mention_entities', __( 'Cita entidade', 'go-verge' ), __( 'Entidades relevantes mencionadas, mas que não são o foco principal.', 'go-verge' ) );
			go_verge_semantic_render_chip_field( $post->ID, 'keywords', __( 'Palavras-chave editoriais', 'go-verge' ), __( 'Termos importantes que ajudam a descrever o conteúdo sem forçar repetição.', 'go-verge' ) );
			go_verge_semantic_render_chip_field( $post->ID, 'about_categories', __( 'Trata categoria', 'go-verge' ), __( 'Categorias específicas realmente centrais para a matéria.', 'go-verge' ) );
			go_verge_semantic_render_chip_field( $post->ID, 'mention_categories', __( 'Cita categoria', 'go-verge' ), __( 'Categorias contextuais ou secundárias.', 'go-verge' ) );
			?>
		</div>
	</div>
	<?php
}

/** Save manual semantic annotations and invalidate auto cache when needed. */
function go_verge_semantic_save_post( $post_id ) {
	if ( ! isset( $_POST['go_verge_semantic_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_semantic_nonce'] ) ), 'go_verge_semantic_save' ) ) {
		return;
	}
	if ( ! current_user_can( 'edit_post', $post_id ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	$keys = go_verge_semantic_meta_keys();
	update_post_meta( $post_id, $keys['auto'], isset( $_POST['go_semantic_auto_enabled'] ) ? '1' : '0' );
	foreach ( array( 'about_entities', 'mention_entities', 'keywords', 'about_categories', 'mention_categories' ) as $field ) {
		$raw = isset( $_POST[ 'go_semantic_' . $field ] ) ? wp_unslash( $_POST[ 'go_semantic_' . $field ] ) : '';
		update_post_meta( $post_id, $keys[ $field ], go_verge_semantic_sanitize_list( $raw ) );
	}
	delete_post_meta( $post_id, '_go_semantic_auto_cache' );
}
add_action( 'save_post_post', 'go_verge_semantic_save_post', 35 );

/** Invalidate semantic inference when editorial body changes. */
function go_verge_semantic_invalidate_on_update( $post_id, $post_after, $post_before ) {
	if ( ! ( $post_after instanceof WP_Post ) || ! ( $post_before instanceof WP_Post ) ) {
		return;
	}
	if ( $post_after->post_title !== $post_before->post_title || $post_after->post_content !== $post_before->post_content || $post_after->post_excerpt !== $post_before->post_excerpt ) {
		delete_post_meta( $post_id, '_go_semantic_auto_cache' );
	}
}
add_action( 'post_updated', 'go_verge_semantic_invalidate_on_update', 30, 3 );

/** Precompute semantic data after a post save, after manual fields were stored. */
function go_verge_semantic_precompute_saved_post( $post_id, $post = null, $update = false ) {
	$post = $post instanceof WP_Post ? $post : get_post( $post_id );
	if ( ! $post || 'post' !== $post->post_type || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) {
		go_verge_defer_post_save_maintenance( $post_id );
		return;
	}
	if ( ! go_verge_semantic_auto_enabled( $post_id ) ) {
		delete_post_meta( $post_id, '_go_semantic_auto_cache' );
		return;
	}
	go_verge_semantic_auto_analysis( $post_id, true );
}
add_action( 'save_post_post', 'go_verge_semantic_precompute_saved_post', 100, 3 );

/** Recompute after taxonomy edits because tags/categories are semantic inputs. */
function go_verge_semantic_precompute_terms( $object_id, $terms, $tt_ids, $taxonomy ) {
	if ( ! in_array( $taxonomy, array( 'category', 'post_tag' ), true ) || 'post' !== get_post_type( $object_id ) ) {
		return;
	}
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) {
		go_verge_defer_post_save_maintenance( $object_id );
		return;
	}
	delete_post_meta( $object_id, '_go_semantic_auto_cache' );
	if ( go_verge_semantic_auto_enabled( $object_id ) ) {
		go_verge_semantic_auto_analysis( $object_id, true );
	}
}
add_action( 'set_object_terms', 'go_verge_semantic_precompute_terms', 30, 4 );

/** Schedule a bounded background backfill for legacy published posts. */
function go_verge_semantic_schedule_backfill() {
	if ( get_option( 'go_verge_semantic_backfill_complete_v68' ) ) {
		wp_clear_scheduled_hook( 'go_verge_semantic_backfill_batch' );
		return;
	}

	/* 3.15.1 replaces the old hourly recurring event (8 posts/hour) with a
	 * self-chaining single event. Clear the legacy schedule once. */
	if ( '3.15.1' !== get_option( 'go_verge_semantic_backfill_scheduler_v3151' ) ) {
		wp_clear_scheduled_hook( 'go_verge_semantic_backfill_batch' );
		update_option( 'go_verge_semantic_backfill_scheduler_v3151', '3.15.1', false );
	}

	if ( ! wp_next_scheduled( 'go_verge_semantic_backfill_batch' ) ) {
		wp_schedule_single_event( time() + 60, 'go_verge_semantic_backfill_batch' );
	}
}
add_action( 'init', 'go_verge_semantic_schedule_backfill', 40 );

/** Process a bounded batch without letting migration work pile up on visitors. */
function go_verge_semantic_run_backfill_batch() {
	if ( get_option( 'go_verge_semantic_backfill_complete_v68' ) ) {
		return;
	}
	if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( 'semantic_backfill_v68', 180 ) ) {
		if ( ! wp_next_scheduled( 'go_verge_semantic_backfill_batch' ) ) {
			wp_schedule_single_event( time() + 2 * MINUTE_IN_SECONDS, 'go_verge_semantic_backfill_batch' );
		}
		return;
	}

	$batch_size = 24;
	$started    = microtime( true );
	$complete   = false;

	try {
		$query = new WP_Query(
			array(
				'post_type'              => 'post',
				'post_status'            => 'publish',
				'posts_per_page'         => $batch_size,
				'orderby'                => 'date',
				'order'                  => 'DESC',
				'fields'                 => 'ids',
				'no_found_rows'          => true,
				'ignore_sticky_posts'    => true,
				'suppress_filters'       => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
				'meta_query'             => array(
					array(
						'key'     => '_go_semantic_auto_cache',
						'compare' => 'NOT EXISTS',
					),
				),
			)
		);

		if ( empty( $query->posts ) ) {
			$complete = true;
		} else {
			foreach ( (array) $query->posts as $post_id ) {
				if ( go_verge_semantic_auto_enabled( $post_id ) ) {
					go_verge_semantic_auto_analysis( $post_id, true );
				} else {
					/* Mark disabled legacy posts as intentionally inspected so the
					 * NOT EXISTS query does not select the same row forever. */
					update_post_meta( $post_id, '_go_semantic_auto_cache', array( 'disabled' => true, 'version' => 68 ) );
				}

				/* Protect shared hosting from a pathological article. A later event
				 * resumes from the remaining posts instead of holding a worker open. */
				if ( microtime( true ) - $started >= 12 ) {
					break;
				}
			}
		}
	} finally {
		go_verge_release_job_lock( 'semantic_backfill_v68' );
	}

	if ( $complete ) {
		update_option( 'go_verge_semantic_backfill_complete_v68', 1, false );
		wp_clear_scheduled_hook( 'go_verge_semantic_backfill_batch' );
		return;
	}

	if ( ! wp_next_scheduled( 'go_verge_semantic_backfill_batch' ) ) {
		wp_schedule_single_event( time() + 3 * MINUTE_IN_SECONDS, 'go_verge_semantic_backfill_batch' );
	}
}
add_action( 'go_verge_semantic_backfill_batch', 'go_verge_semantic_run_backfill_batch' );

/**
 * Detect a genuine attributed direct quote. A quoted word/term alone never
 * qualifies. Strong attribution is mandatory unless the author used blockquote.
 */
function go_verge_semantic_detect_attributed_quote( $plain, $previous = '', $next = '' ) {
	$plain = trim( html_entity_decode( wp_strip_all_tags( (string) $plain ), ENT_QUOTES, get_bloginfo( 'charset' ) ) );
	if ( '' === $plain ) {
		return false;
	}
	$quote_pattern = '/[“\"]([^”\"]{35,700})[”\"]/u';
	if ( ! preg_match( $quote_pattern, $plain, $qm ) ) {
		return false;
	}
	$quoted = trim( $qm[1] );
	$words  = preg_split( '/\s+/u', $quoted, -1, PREG_SPLIT_NO_EMPTY );
	if ( count( (array) $words ) < 7 ) {
		return false;
	}

	$verbs = '(?:disse|afirmou|explicou|declarou|comentou|contou|revelou|acrescentou|avaliou|escreveu|publicou|respondeu|destacou|ressaltou|observou|adiantou|informou|relatou|defendeu|criticou|completou|prosseguiu|lembrou|pontuou|garantiu|admitiu|frisou|anunciou)';
	$name  = '([A-ZÁÉÍÓÚÀÂÊÔÃÕÇ][\p{L}\'’.-]+(?:\s+(?:[A-ZÁÉÍÓÚÀÂÊÔÃÕÇ][\p{L}\'’.-]+|da|de|do|dos|das)){0,4})';
	$contexts = array( $plain, trim( $previous ), trim( $next ) );
	$speaker  = '';
	$strong   = false;
	foreach ( $contexts as $context ) {
		if ( '' === $context ) { continue; }
		if ( preg_match( '/\b' . $verbs . '\s+' . $name . '/u', $context, $m ) || preg_match( '/' . $name . '\s+' . $verbs . '\b/u', $context, $m ) ) {
			$speaker = trim( end( $m ) );
			$strong  = true;
			break;
		}
		if ( preg_match( '/\b(?:segundo|de acordo com)\s+' . $name . '/u', $context, $m ) ) {
			$speaker = trim( $m[1] );
			$strong  = true;
			break;
		}
	}
	if ( ! $strong ) {
		return false;
	}
	return array( 'quote' => $quoted, 'speaker' => $speaker );
}

/** Add editorial quote treatment only to genuinely attributed speech. */
function go_verge_semantic_style_attributed_quotes( $content ) {
	if ( is_admin() || is_feed() || ! is_singular( 'post' ) || ! is_string( $content ) || false !== strpos( $content, 'data-go-editorial-quote=' ) ) {
		return $content;
	}


	if ( ! preg_match_all( '/<p\b[^>]*>.*?<\/p>/isu', $content, $matches, PREG_OFFSET_CAPTURE ) ) {
		return $content;
	}
	$paragraphs = $matches[0];
	$replacements = array();
	foreach ( $paragraphs as $index => $match ) {
		$html = $match[0];
		if ( preg_match( '/<(?:img|code|pre|script|style|ins|iframe)\b/i', $html ) ) {
			continue;
		}
		$plain = trim( wp_strip_all_tags( $html ) );
		$prev  = $index > 0 ? trim( wp_strip_all_tags( $paragraphs[ $index - 1 ][0] ) ) : '';
		$next  = isset( $paragraphs[ $index + 1 ] ) ? trim( wp_strip_all_tags( $paragraphs[ $index + 1 ][0] ) ) : '';
		$detected = go_verge_semantic_detect_attributed_quote( $plain, $prev, $next );
		if ( ! $detected ) {
			continue;
		}
		$inner = preg_replace( '/^<p\b[^>]*>|<\/p>$/i', '', $html );
		$speaker = ! empty( $detected['speaker'] ) ? '<footer class="go-editorial-quote__speaker">' . esc_html( $detected['speaker'] ) . '</footer>' : '';
		$replacement = '<blockquote class="go-editorial-quote go-editorial-quote--detected" data-go-editorial-quote="detected"><div class="go-editorial-quote__text">' . $inner . '</div>' . $speaker . '</blockquote>';
		$replacements[] = array( 'offset' => $match[1], 'length' => strlen( $html ), 'html' => $replacement );
	}
	for ( $i = count( $replacements ) - 1; $i >= 0; $i-- ) {
		$r = $replacements[ $i ];
		$content = substr_replace( $content, $r['html'], $r['offset'], $r['length'] );
	}
	return $content;
}
add_filter( 'the_content', 'go_verge_semantic_style_attributed_quotes', 14 );

/** Front-end styles for detected/editor-authored speech. */
function go_verge_semantic_quote_styles() {
	if ( ! is_singular( 'post' ) ) {
		return;
	}
	$css = '.go-editorial-quote{position:relative;margin:2rem 0;padding:.15rem 0 .15rem 1.5rem;border-left:3px solid var(--lime,#c7ea00);background:transparent;color:inherit}.go-editorial-quote::before{content:"“";position:absolute;left:.34rem;top:-.18rem;color:var(--lime-text,#667500);font:800 1.5rem/1 var(--font-serif,Georgia,serif)}.go-editorial-quote__text{font-size:clamp(1.08rem,1.8vw,1.32rem);line-height:1.58;font-weight:600}.go-editorial-quote__text p{margin:0}.go-editorial-quote__speaker{display:block;margin-top:.75rem;font-size:.86rem;line-height:1.4;color:var(--muted,#697066);font-weight:600}.go-editorial-quote--manual{border-left-width:2px}[data-theme="dark-mode"] .go-editorial-quote::before{color:var(--lime,#c7ea00)}';
	wp_add_inline_style( 'go-verge', $css );
}
add_action( 'wp_enqueue_scripts', 'go_verge_semantic_quote_styles', 40 );
