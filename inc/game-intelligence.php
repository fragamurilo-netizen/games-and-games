<?php
/**
 * Reliable game linking for editorial posts.
 *
 * Provides one canonical workflow for manual selection and automatic context
 * analysis. The canonical relation is `go_linked_game_id`; the historical
 * `go_review_game_id` key is kept in sync for backwards compatibility.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/*
 * The legacy theme registered another selector with the same metabox ID.
 * Remove those callbacks before WordPress builds the editor screen so the
 * Intelligence panel cannot disappear or be overwritten by registration order.
 */
if ( function_exists( 'go_verge_register_linked_game_meta_box' ) ) {
	remove_action( 'add_meta_boxes_post', 'go_verge_register_linked_game_meta_box' );
}
if ( function_exists( 'go_verge_save_linked_game_meta' ) ) {
	remove_action( 'save_post_post', 'go_verge_save_linked_game_meta' );
}

/** Minimum confidence required for an automatic link. */
function go_verge_game_intelligence_threshold() {
	return (int) apply_filters( 'go_verge_game_intelligence_threshold', 90 );
}

/** Normalize text for accent-insensitive and punctuation-insensitive matching. */
function go_verge_game_intelligence_normalize( $value ) {
	$value = html_entity_decode( wp_strip_all_tags( (string) $value ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
	$value = remove_accents( $value );
	$value = strtolower( $value );
	$value = str_replace( array( '’', '‘', '´', '`' ), "'", $value );
	$value = preg_replace( '/[^a-z0-9]+/u', ' ', $value );
	$value = preg_replace( '/\s+/u', ' ', (string) $value );
	return trim( (string) $value );
}

/** SEO fields used by Rank Math, Yoast, SEOPress and common custom setups. */
function go_verge_game_intelligence_seo_meta_keys() {
	return array(
		'rank_math_title',
		'_rank_math_title',
		'_yoast_wpseo_title',
		'_seopress_titles_title',
		'_aioseo_title',
		'aioseo_title',
		'go_seo_title',
		'_go_seo_title',
		'rank_math_focus_keyword',
		'_rank_math_focus_keyword',
		'_yoast_wpseo_focuskw',
		'_seopress_analysis_target_kw',
	);
}

/** Expand the title placeholder used by SEO plugins and drop site-only tokens. */
function go_verge_game_intelligence_expand_seo_value( $value, $post_id ) {
	$value = (string) $value;
	if ( '' === trim( $value ) ) {
		return '';
	}
	$title = (string) get_post_field( 'post_title', $post_id );
	$value = str_ireplace( array( '%title%', '%%title%%' ), $title, $value );
	$value = preg_replace( '/%%(?:sep|sitename|sitedesc|page|currentdate|currentyear)%%/i', ' ', $value );
	$value = preg_replace( '/%(?:sep|sitename|sitedesc|page|currentdate|currentyear)%/i', ' ', $value );
	return trim( wp_strip_all_tags( (string) $value ) );
}

/** Collect saved SEO title and keyword signals without depending on one plugin. */
function go_verge_game_intelligence_seo_context( $post_id ) {
	$titles = array();
	$focus  = array();
	foreach ( go_verge_game_intelligence_seo_meta_keys() as $key ) {
		$value = go_verge_game_intelligence_expand_seo_value( get_post_meta( $post_id, $key, true ), $post_id );
		if ( '' === $value ) {
			continue;
		}
		if ( false !== strpos( $key, 'focus' ) || false !== strpos( $key, 'target_kw' ) ) {
			$focus[] = $value;
		} else {
			$titles[] = $value;
		}
	}
	return array(
		'titles' => array_values( array_unique( $titles ) ),
		'focus'  => array_values( array_unique( $focus ) ),
	);
}

/** Split alias fields that may have been entered as lines, commas or pipes. */
function go_verge_game_intelligence_aliases( $game_id ) {
	$aliases = array();
	foreach ( array( 'go_game_aliases', '_go_game_aliases', 'go_aliases', '_go_aliases' ) as $key ) {
		$raw = get_post_meta( $game_id, $key, true );
		if ( is_array( $raw ) ) {
			$parts = $raw;
		} else {
			$parts = preg_split( '/[\r\n,;|]+/u', (string) $raw );
		}
		foreach ( (array) $parts as $part ) {
			$part = trim( wp_strip_all_tags( (string) $part ) );
			if ( '' !== $part ) {
				$aliases[] = $part;
			}
		}
	}

	/* Derive a few conservative editorial forms that are commonly used in
	 * headlines even when the Games record keeps the complete licensed name. */
	$title = function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $game_id ) : get_the_title( $game_id );
	$title = trim( preg_replace( '/[™®©]/u', '', (string) $title ) );
	if ( '' !== $title ) {
		$derived = array();
		$without_brand = preg_replace( '/^(?:EA\s+SPORTS|Tom\s+Clancy[\'’]s|Sid\s+Meier[\'’]s|Marvel[\'’]s)\s+/iu', '', $title );
		if ( $without_brand && $without_brand !== $title ) { $derived[] = $without_brand; }

		$initialism = static function ( $phrase ) {
			$letters = '';
			foreach ( preg_split( '/\s+/u', trim( preg_replace( '/[^\p{L}\p{N}]+/u', ' ', remove_accents( $phrase ) ) ) ) as $word ) {
				if ( '' !== $word && ! preg_match( '/^(?:\d+|[ivx]+)$/i', $word ) ) { $letters .= substr( $word, 0, 1 ); }
			}
			$letters = strtoupper( $letters );
			return strlen( $letters ) >= 2 && strlen( $letters ) <= 6 ? $letters : '';
		};

		if ( false === strpos( $title, ':' ) && $without_brand === $title && preg_match( '/^(.+?)\s+((?:[ivx]{1,5})|\d{1,3})$/iu', $title, $version_match ) ) {
			$short = $initialism( $version_match[1] );
			if ( $short ) { $derived[] = $short . ' ' . strtoupper( $version_match[2] ); }
		}
		if ( false !== strpos( $title, ':' ) ) {
			list( $series, $subtitle ) = array_map( 'trim', explode( ':', $title, 2 ) );
			$series_short = $initialism( $series );
			if ( $series_short ) {
				$derived[] = $series_short . ' ' . $subtitle;
				if ( preg_match( '/^(.+?)\s+((?:[ivx]{1,5})|\d{1,3})$/iu', $subtitle, $subtitle_version ) ) {
					$subtitle_short = $initialism( $subtitle_version[1] );
					if ( $subtitle_short ) { $derived[] = $series_short . ' ' . $subtitle_short . strtoupper( $subtitle_version[2] ); }
				}
			}
		}

		$roman_to_number = array( 'I'=>1, 'II'=>2, 'III'=>3, 'IV'=>4, 'V'=>5, 'VI'=>6, 'VII'=>7, 'VIII'=>8, 'IX'=>9, 'X'=>10, 'XI'=>11, 'XII'=>12, 'XIII'=>13, 'XIV'=>14, 'XV'=>15, 'XVI'=>16, 'XVII'=>17, 'XVIII'=>18, 'XIX'=>19, 'XX'=>20 );
		$number_to_roman = array_flip( $roman_to_number );
		$variant_source = array_merge( array( $title ), $aliases, $derived );
		foreach ( $variant_source as $variant ) {
			if ( preg_match( '/^(.*?)\b([ivx]{1,5})$/iu', $variant, $match ) ) {
				$roman = strtoupper( $match[2] );
				if ( isset( $roman_to_number[ $roman ] ) ) { $derived[] = trim( $match[1] ) . ' ' . $roman_to_number[ $roman ]; }
			} elseif ( preg_match( '/^(.*?)\b(\d{1,2})$/u', $variant, $match ) ) {
				$number = (int) $match[2];
				if ( isset( $number_to_roman[ $number ] ) ) { $derived[] = trim( $match[1] ) . ' ' . $number_to_roman[ $number ]; }
			}
		}
		$aliases = array_merge( $aliases, $derived );
	}
	return array_values( array_unique( $aliases ) );
}

/**
 * Lightweight catalogue used by both manual search and automatic analysis.
 *
 * Most hosts in this stack do not provide a persistent object cache, so a
 * short-lived database transient carries the catalogue across editor requests.
 */
function go_verge_game_intelligence_catalog() {
	$cache_key = 'go_verge_game_intelligence_catalog_v6';
	$catalog   = wp_cache_get( $cache_key, 'go_verge' );
	if ( false !== $catalog && is_array( $catalog ) ) {
		return $catalog;
	}
	if ( ! wp_using_ext_object_cache() ) {
		$catalog = get_transient( $cache_key );
		if ( false !== $catalog && is_array( $catalog ) ) {
			wp_cache_set( $cache_key, $catalog, 'go_verge', 15 * MINUTE_IN_SECONDS );
			return $catalog;
		}
	}

	$ids = get_posts(
		array(
			'post_type'              => 'games',
			'post_status'            => 'publish',
			'posts_per_page'         => -1,
			'orderby'                => 'title',
			'order'                  => 'ASC',
			'fields'                 => 'ids',
			'no_found_rows'          => true,
			'suppress_filters'       => false,
			'update_post_meta_cache' => true,
			'update_post_term_cache' => false,
		)
	);

	$catalog = array();
	foreach ( (array) $ids as $game_id ) {
		$title = function_exists( 'go_verge_game_name' )
			? go_verge_game_name( $game_id )
			: html_entity_decode( trim( wp_strip_all_tags( get_the_title( $game_id ) ) ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
		if ( '' === $title ) {
			continue;
		}
		$names = array_merge( array( $title ), go_verge_game_intelligence_aliases( $game_id ) );
		$items = array();
		foreach ( $names as $name ) {
			$normal = go_verge_game_intelligence_normalize( $name );
			if ( '' !== $normal ) {
				$items[ $normal ] = $name;
			}
		}
		$catalog[] = array(
			'id'     => absint( $game_id ),
			'title'  => $title,
			'names'  => $items,
			'url'    => get_permalink( $game_id ),
			'image'  => get_the_post_thumbnail_url( $game_id, 'thumbnail' ) ?: '',
		);
	}

	wp_cache_set( $cache_key, $catalog, 'go_verge', 15 * MINUTE_IN_SECONDS );
	if ( ! wp_using_ext_object_cache() ) {
		set_transient( $cache_key, $catalog, 15 * MINUTE_IN_SECONDS );
	}
	return $catalog;
}

/** Bust the game catalogue when a Games record changes. */
function go_verge_game_intelligence_bust_catalog() {
	wp_cache_delete( 'go_verge_game_intelligence_catalog_v3', 'go_verge' );
	wp_cache_delete( 'go_verge_game_intelligence_catalog_v4', 'go_verge' );
	wp_cache_delete( 'go_verge_game_intelligence_catalog_v5', 'go_verge' );
	wp_cache_delete( 'go_verge_game_intelligence_catalog_v6', 'go_verge' );
	delete_transient( 'go_verge_game_intelligence_catalog_v6' );
}
add_action( 'save_post_games', 'go_verge_game_intelligence_bust_catalog' );
add_action( 'deleted_post', 'go_verge_game_intelligence_bust_catalog' );

/** Valid published Games CPT object. */
function go_verge_game_intelligence_valid_game( $game_id ) {
	$game_id = absint( $game_id );
	return $game_id && 'games' === get_post_type( $game_id ) && 'publish' === get_post_status( $game_id );
}

/** Keep canonical and legacy relations in lockstep. */
function go_verge_game_intelligence_write_link( $post_id, $game_id, $mode = 'auto' ) {
	$post_id = absint( $post_id );
	$game_id = absint( $game_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return false;
	}
	if ( $game_id && ! go_verge_game_intelligence_valid_game( $game_id ) ) {
		return false;
	}

	if ( $game_id ) {
		update_post_meta( $post_id, 'go_linked_game_id', $game_id );
		update_post_meta( $post_id, 'go_review_game_id', $game_id );
		update_post_meta( $post_id, '_go_game_intelligence_mode', in_array( $mode, array( 'manual', 'auto' ), true ) ? $mode : 'auto' );
		delete_post_meta( $post_id, '_go_game_intelligence_opt_out' );
	} else {
		delete_post_meta( $post_id, 'go_linked_game_id' );
		delete_post_meta( $post_id, 'go_review_game_id' );
		if ( 'auto' === $mode ) {
			update_post_meta( $post_id, '_go_game_intelligence_mode', 'auto' );
			delete_post_meta( $post_id, '_go_game_intelligence_opt_out' );
		} else {
			update_post_meta( $post_id, '_go_game_intelligence_mode', 'none' );
			if ( 'none' === $mode ) {
				update_post_meta( $post_id, '_go_game_intelligence_opt_out', '1' );
			}
		}
	}
	return true;
}

/** Token set excluding tiny words that create false fuzzy matches. */
function go_verge_game_intelligence_tokens( $text ) {
	$stop = array_fill_keys(
		array( 'a', 'o', 'as', 'os', 'de', 'da', 'do', 'das', 'dos', 'e', 'em', 'no', 'na', 'nos', 'nas', 'um', 'uma', 'para', 'por', 'com', 'the', 'of', 'and', 'in', 'on', 'to', 'for' ),
		true
	);
	$tokens = array();
	foreach ( preg_split( '/\s+/u', go_verge_game_intelligence_normalize( $text ) ) as $token ) {
		if ( strlen( $token ) < 2 || isset( $stop[ $token ] ) ) {
			continue;
		}
		$tokens[ $token ] = true;
	}
	return array_keys( $tokens );
}

/** Fuzzy token overlap, deliberately capped below the automatic threshold. */
function go_verge_game_intelligence_token_score( $needle, $haystack ) {
	$need = go_verge_game_intelligence_tokens( $needle );
	$hay  = go_verge_game_intelligence_tokens( $haystack );
	if ( empty( $need ) || empty( $hay ) ) {
		return 0;
	}
	$shared = array_intersect( $need, $hay );
	$ratio  = count( $shared ) / max( 1, count( $need ) );
	if ( 1 === count( $need ) && strlen( $need[0] ) < 5 ) {
		return 0;
	}
	return (int) round( min( 79, 42 + ( 37 * $ratio ) ) );
}

/** Build current editorial context, with optional unsaved editor overrides. */
function go_verge_game_intelligence_context( $post_id, $overrides = array() ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) {
		return array();
	}

	$override_value = static function ( $key, $fallback ) use ( $overrides ) {
		if ( array_key_exists( $key, $overrides ) && '' !== trim( wp_strip_all_tags( (string) $overrides[ $key ] ) ) ) {
			return $overrides[ $key ];
		}
		return $fallback;
	};

	$title   = sanitize_text_field( $override_value( 'title', $post->post_title ) );
	$content = wp_kses_post( $override_value( 'content', $post->post_content ) );
	$excerpt = sanitize_textarea_field( $override_value( 'excerpt', $post->post_excerpt ) );

	$subtitle = (string) get_post_meta( $post_id, '_go_post_subtitle', true );
	if ( '' === trim( $subtitle ) ) {
		$subtitle = (string) get_post_meta( $post_id, 'go_verge_support_line', true );
	}
	$terms = wp_get_post_terms( $post_id, array( 'category', 'post_tag' ), array( 'fields' => 'names' ) );
	$terms = is_wp_error( $terms ) ? array() : $terms;

	$seo_context = go_verge_game_intelligence_seo_context( $post_id );
	$seo_override = sanitize_text_field( $override_value( 'seo_title', '' ) );
	if ( '' !== $seo_override ) {
		array_unshift( $seo_context['titles'], $seo_override );
	}
	$seo_titles = implode( ' ', array_values( array_unique( array_filter( $seo_context['titles'] ) ) ) );
	$focus      = implode( ' ', array_values( array_unique( array_filter( $seo_context['focus'] ) ) ) );
	$slug       = (string) get_post_field( 'post_name', $post_id );

	return array(
		'title'    => go_verge_game_intelligence_normalize( $title ),
		'seo'      => go_verge_game_intelligence_normalize( $seo_titles ),
		'focus'    => go_verge_game_intelligence_normalize( $focus ),
		'subtitle' => go_verge_game_intelligence_normalize( $subtitle . ' ' . $excerpt ),
		'terms'    => go_verge_game_intelligence_normalize( implode( ' ', (array) $terms ) ),
		'slug'     => go_verge_game_intelligence_normalize( str_replace( '-', ' ', $slug ) ),
		'content'  => go_verge_game_intelligence_normalize( wp_trim_words( wp_strip_all_tags( $content ), 900, '' ) ),
		'raw'      => trim( wp_strip_all_tags( $title . ' ' . $seo_titles . ' ' . $focus . ' ' . $subtitle . ' ' . $excerpt . ' ' . implode( ' ', (array) $terms ) . ' ' . $slug . ' ' . $content ) ),
	);
}

/** Score one game against the context using exact mentions before fuzzy cues. */
function go_verge_game_intelligence_score_game( $game, $context ) {
	$best          = 0;
	$reason        = '';
	$auto_eligible = false;
	foreach ( (array) $game['names'] as $normal_name => $display_name ) {
		$name_len = strlen( str_replace( ' ', '', $normal_name ) );
		$tokens   = count( go_verge_game_intelligence_tokens( $normal_name ) );
		if ( $name_len < 3 ) {
			continue;
		}

		$specificity = min( 4, max( 0, $tokens - 1 ) );
		$consider = static function ( $score, $why, $eligible ) use ( &$best, &$reason, &$auto_eligible ) {
			if ( $score > $best ) {
				$best          = (int) $score;
				$reason        = (string) $why;
				$auto_eligible = (bool) $eligible;
			}
		};

		if ( $context['title'] === $normal_name ) {
			return array( 'score' => 100, 'reason' => 'título editorial exato', 'auto_eligible' => true );
		}
		if ( ! empty( $context['seo'] ) && $context['seo'] === $normal_name ) {
			$consider( 100, 'título SEO exato', true );
		}
		if ( false !== strpos( ' ' . $context['title'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( min( 99, 95 + $specificity ), 'nome do jogo no título editorial', true );
		}
		if ( ! empty( $context['seo'] ) && false !== strpos( ' ' . $context['seo'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( min( 99, 94 + $specificity ), 'nome do jogo no título SEO', true );
		}
		if ( ! empty( $context['focus'] ) && false !== strpos( ' ' . $context['focus'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( min( 98, 93 + $specificity ), 'nome do jogo na palavra-chave SEO', true );
		}
		if ( false !== strpos( ' ' . $context['terms'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( 94, 'nome do jogo em tag ou categoria', true );
		}
		if ( false !== strpos( ' ' . $context['subtitle'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( 92, 'nome do jogo na linha de apoio', true );
		}
		if ( ! empty( $context['slug'] ) && false !== strpos( ' ' . $context['slug'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( 91, 'nome do jogo no slug', true );
		}

		/* Body-only evidence is useful as an editor suggestion, never as permission
		 * to create an entity relationship automatically. This avoids collisions
		 * with generic subtitles such as Requiem, Origins, Legacy or Awakening. */
		if ( false !== strpos( ' ' . $context['content'] . ' ', ' ' . $normal_name . ' ' ) ) {
			$consider( $name_len >= 7 ? 79 : 74, 'nome do jogo apenas no texto', false );
		}

		$fuzzy = go_verge_game_intelligence_token_score( $normal_name, $context['title'] );
		$consider( $fuzzy, 'proximidade com o título editorial', false );
	}
	return array( 'score' => $best, 'reason' => $reason, 'auto_eligible' => $auto_eligible );
}

/**
 * Rank games and return a conservative best suggestion.
 * A close runner-up suppresses automatic linking to avoid franchise/edition
 * collisions, while still exposing the top suggestion to the editor.
 */
function go_verge_game_intelligence_analyze( $post_id, $overrides = array() ) {
	$context = go_verge_game_intelligence_context( $post_id, $overrides );
	if ( empty( $context['raw'] ) ) {
		return array( 'candidate' => null, 'score' => 0, 'reason' => '', 'safe' => false, 'runner_up' => 0 );
	}

	$ranked = array();
	foreach ( go_verge_game_intelligence_catalog() as $game ) {
		$result = go_verge_game_intelligence_score_game( $game, $context );
		if ( $result['score'] < 35 ) {
			continue;
		}
		$ranked[] = array(
			'game'   => $game,
			'score'  => (int) $result['score'],
			'reason'        => $result['reason'],
			'auto_eligible' => ! empty( $result['auto_eligible'] ),
		);
	}
	usort( $ranked, static function ( $a, $b ) { return $b['score'] <=> $a['score']; } );

	$top       = $ranked[0] ?? null;
	$runner_up = isset( $ranked[1] ) ? (int) $ranked[1]['score'] : 0;
	if ( ! $top ) {
		return array( 'candidate' => null, 'score' => 0, 'reason' => '', 'safe' => false, 'runner_up' => 0 );
	}

	$threshold = go_verge_game_intelligence_threshold();
	$gap       = (int) $top['score'] - $runner_up;
	$top_score = (int) $top['score'];
	/* Exact/near-exact title evidence can link with a small lead. Lower signals
	 * need a wider margin so editions from the same franchise are not mixed. */
	$safe      = ! empty( $top['auto_eligible'] ) && $top_score >= $threshold && (
		100 === $top_score ||
		( $top_score >= 99 && $gap >= 1 ) ||
		( $top_score >= 98 && $gap >= 2 ) ||
		( $top_score >= 94 && $gap >= 4 ) ||
		$gap >= 7
	);

	return array(
		'candidate' => $top['game'],
		'score'     => (int) $top['score'],
		'reason'    => $top['reason'],
		'safe'      => (bool) $safe,
		'runner_up' => $runner_up,
	);
}

/** Store suggestion diagnostics for the editor UI. */
function go_verge_game_intelligence_store_suggestion( $post_id, $analysis ) {
	$candidate = $analysis['candidate'] ?? null;
	if ( is_array( $candidate ) && ! empty( $candidate['id'] ) ) {
		update_post_meta( $post_id, '_go_game_intelligence_last_suggestion_id', absint( $candidate['id'] ) );
		update_post_meta( $post_id, '_go_game_intelligence_last_suggestion_score', (int) ( $analysis['score'] ?? 0 ) );
		update_post_meta( $post_id, '_go_game_intelligence_last_suggestion_reason', sanitize_text_field( $analysis['reason'] ?? '' ) );
	} else {
		delete_post_meta( $post_id, '_go_game_intelligence_last_suggestion_id' );
		delete_post_meta( $post_id, '_go_game_intelligence_last_suggestion_score' );
		delete_post_meta( $post_id, '_go_game_intelligence_last_suggestion_reason' );
	}
}

/** Convert a game record to a stable AJAX payload. */
function go_verge_game_intelligence_game_payload( $game_id ) {
	$game_id = absint( $game_id );
	if ( ! go_verge_game_intelligence_valid_game( $game_id ) ) {
		return null;
	}
	$platform_raw = (string) get_post_meta( $game_id, '_go_platforms', true );
	if ( '' === trim( $platform_raw ) ) {
		$platform_raw = (string) get_post_meta( $game_id, '_go_plataforma', true );
	}
	$platforms = array_values( array_filter( array_map( 'trim', preg_split( '/[,;|\/]+/', $platform_raw ) ) ) );
	$stores = maybe_unserialize( get_post_meta( $game_id, '_go_store_links', true ) );
	$stores = is_array( $stores ) ? $stores : array();
	$store_labels = array();
	foreach ( $stores as $store ) {
		if ( ! is_array( $store ) ) { continue; }
		$label = sanitize_text_field( $store['label'] ?? $store['platform'] ?? '' );
		if ( '' !== $label ) { $store_labels[] = $label; }
	}
	return array(
		'id'        => $game_id,
		'title'     => function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $game_id ) : html_entity_decode( wp_strip_all_tags( get_the_title( $game_id ) ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ),
		'url'       => get_permalink( $game_id ),
		'image'     => get_the_post_thumbnail_url( $game_id, 'thumbnail' ) ?: '',
		'platforms' => array_slice( $platforms, 0, 8 ),
		'release'   => sanitize_text_field( (string) get_post_meta( $game_id, '_go_release_date', true ) ),
		'stores'    => array_slice( array_values( array_unique( $store_labels ) ), 0, 6 ),
	);
}

/**
 * Remove every legacy/duplicate game-linking box before registering the one
 * canonical Game Intelligence panel. This is intentionally defensive: older
 * theme builds, object-cache leftovers and companion code may register a box
 * under a different ID while using the same visible title.
 */
function go_verge_game_intelligence_remove_duplicate_meta_boxes() {
	global $wp_meta_boxes;

	if ( empty( $wp_meta_boxes['post'] ) || ! is_array( $wp_meta_boxes['post'] ) ) {
		return;
	}

	$canonical_id = 'go-verge-game-intelligence';
	$legacy_ids   = array(
		'go-verge-linked-game',
		'go-verge-game-intelligence-v2',
		'go-verge-game-intelligence-v3',
		'go-game-intelligence',
		'game-intelligence',
	);

	foreach ( $wp_meta_boxes['post'] as $context => &$priorities ) {
		if ( ! is_array( $priorities ) ) {
			continue;
		}
		foreach ( $priorities as $priority => &$boxes ) {
			if ( ! is_array( $boxes ) ) {
				continue;
			}
			foreach ( $boxes as $box_id => $box ) {
				$title = isset( $box['title'] ) ? wp_strip_all_tags( (string) $box['title'] ) : '';
				$is_game_intelligence_title = false !== stripos( remove_accents( $title ), 'Game Intelligence' );
				$is_known_legacy_id         = in_array( (string) $box_id, $legacy_ids, true );
				$is_legacy_game_link_box    = 'go-verge-linked-game' === (string) $box_id;

				if ( $canonical_id !== (string) $box_id && ( $is_game_intelligence_title || $is_known_legacy_id || $is_legacy_game_link_box ) ) {
					unset( $boxes[ $box_id ] );
				}
			}
		}
	}
	unset( $priorities, $boxes );
}

/** Register exactly one reliable Game Intelligence box in Classic and Block Editor. */
function go_verge_game_intelligence_register_meta_box( $post_type = '', $post = null ) {
	if ( 'post' !== $post_type ) {
		return;
	}

	go_verge_game_intelligence_remove_duplicate_meta_boxes();

	add_meta_box(
		'go-verge-game-intelligence',
		__( 'Game Intelligence', 'go-verge' ),
		'go_verge_game_intelligence_render_meta_box',
		'post',
		'side',
		'high',
		array(
			'__block_editor_compatible_meta_box' => true,
		)
	);
}
add_action( 'add_meta_boxes', 'go_verge_game_intelligence_register_meta_box', 999, 2 );

/** Render the editor box. */
function go_verge_game_intelligence_render_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_linked_game', 'go_verge_linked_game_nonce' );
	$linked_id = absint( get_post_meta( $post->ID, 'go_linked_game_id', true ) );
	if ( ! go_verge_game_intelligence_valid_game( $linked_id ) ) {
		$linked_id = absint( get_post_meta( $post->ID, 'go_review_game_id', true ) );
	}
	if ( ! go_verge_game_intelligence_valid_game( $linked_id ) ) {
		$linked_id = 0;
	}
	$mode       = (string) get_post_meta( $post->ID, '_go_game_intelligence_mode', true );
	$opt_out    = '1' === (string) get_post_meta( $post->ID, '_go_game_intelligence_opt_out', true );
	$suggest_id = absint( get_post_meta( $post->ID, '_go_game_intelligence_last_suggestion_id', true ) );
	$score      = absint( get_post_meta( $post->ID, '_go_game_intelligence_last_suggestion_score', true ) );

	/* Opening Gutenberg is read-only and must not scan the complete Games CPT.
	 * The stored suggestion is enough for initial paint; explicit AJAX analysis
	 * and the save workflow remain the two intentional analysis entry points. */
	if ( ! $linked_id && ! $opt_out && ( '' === $mode || 'none' === $mode ) ) {
		$mode = 'auto';
	}
	?>
	<div class="go-game-intelligence" data-go-game-intelligence data-post-id="<?php echo esc_attr( $post->ID ); ?>">
		<input type="hidden" name="go_linked_game_id" value="<?php echo esc_attr( $linked_id ); ?>" data-go-game-id>
		<input type="hidden" name="go_game_intelligence_mode" value="<?php echo esc_attr( $mode ?: 'auto' ); ?>" data-go-game-mode>

		<div class="go-game-intelligence__status" data-go-game-status>
			<?php if ( $linked_id ) : ?>
				<strong><?php echo esc_html( go_verge_game_name( $linked_id ) ); ?></strong>
				<span><?php echo 'manual' === $mode ? esc_html__( 'Vinculado manualmente.', 'go-verge' ) : esc_html__( 'Vinculado automaticamente.', 'go-verge' ); ?></span>
			<?php else : ?>
				<span><?php esc_html_e( 'Nenhum game vinculado.', 'go-verge' ); ?></span>
			<?php endif; ?>
		</div>

		<div class="go-game-intelligence__actions">
			<button type="button" class="button button-primary" data-go-game-analyze><?php esc_html_e( 'Analisar contexto', 'go-verge' ); ?></button>
			<?php if ( $linked_id ) : ?>
				<button type="button" class="button-link-delete" data-go-game-unlink><?php esc_html_e( 'Remover vínculo', 'go-verge' ); ?></button>
			<?php endif; ?>
		</div>

		<div class="go-game-intelligence__search">
			<input type="search" class="widefat" placeholder="<?php esc_attr_e( 'Buscar jogo, alias…', 'go-verge' ); ?>" autocomplete="off" data-go-game-search>
			<button type="button" class="button" data-go-game-search-button><?php esc_html_e( 'Buscar', 'go-verge' ); ?></button>
		</div>
		<div class="go-game-intelligence__results" data-go-game-results hidden></div>
		<p class="go-game-intelligence__feedback" data-go-game-feedback aria-live="polite"></p>

		<p class="go-game-intelligence__suggestion" data-go-game-suggestion<?php echo $suggest_id ? '' : ' hidden'; ?>>
			<?php if ( $suggest_id ) : ?>
				<?php esc_html_e( 'Última sugestão:', 'go-verge' ); ?>
				<strong><?php echo esc_html( go_verge_game_name( $suggest_id ) ); ?></strong>
				<?php echo $score ? esc_html( '(' . $score . '%)' ) : ''; ?>
			<?php endif; ?>
		</p>
		<p class="description"><?php esc_html_e( 'A seleção manual é salva imediatamente. O texto do corpo pode gerar sugestão, mas vínculo automático só é persistido no salvamento quando título, SEO, tags, slug ou linha de apoio fornecem sinal forte.', 'go-verge' ); ?></p>
	</div>
	<?php
}

/** Editor-only assets. */
function go_verge_game_intelligence_admin_assets( $hook_suffix ) {
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = get_current_screen();
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}
	wp_enqueue_style(
		'go-verge-game-intelligence-admin',
		GO_VERGE_URI . '/assets/css/game-intelligence-admin.css',
		array(),
		go_verge_asset_version( '/assets/css/game-intelligence-admin.css' )
	);
	wp_enqueue_script(
		'go-verge-game-intelligence-admin',
		GO_VERGE_URI . '/assets/js/game-intelligence-admin.js',
		array(),
		go_verge_asset_version( '/assets/js/game-intelligence-admin.js' ),
		true
	);
	wp_localize_script(
		'go-verge-game-intelligence-admin',
		'GoVergeGameIntelligence',
		array(
			'ajaxUrl' => admin_url( 'admin-ajax.php' ),
			'nonce'   => wp_create_nonce( 'go_verge_game_intelligence_ajax' ),
			'i18n'    => array(
				'loading'      => __( 'Analisando…', 'go-verge' ),
				'searching'    => __( 'Buscando…', 'go-verge' ),
				'noResults'    => __( 'Nenhum jogo encontrado.', 'go-verge' ),
				'linked'       => __( 'Vínculo salvo.', 'go-verge' ),
				'unlinked'     => __( 'Vínculo removido.', 'go-verge' ),
				'error'        => __( 'Não foi possível concluir. Tente novamente.', 'go-verge' ),
				'autoLinked'   => __( 'Jogo identificado e vinculado automaticamente.', 'go-verge' ),
				'noConfident'  => __( 'Nenhum jogo atingiu confiança suficiente para vínculo automático.', 'go-verge' ),
			),
		)
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_game_intelligence_admin_assets', 40 );

/** Common AJAX permission and nonce guard. */
function go_verge_game_intelligence_ajax_post_id() {
	check_ajax_referer( 'go_verge_game_intelligence_ajax', 'nonce' );
	$post_id = isset( $_POST['post_id'] ) ? absint( $_POST['post_id'] ) : 0;
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão para editar esta matéria.', 'go-verge' ) ), 403 );
	}
	return $post_id;
}

/** AJAX manual search across game titles and aliases. */
function go_verge_game_intelligence_ajax_search() {
	go_verge_game_intelligence_ajax_post_id();
	$query = isset( $_POST['q'] ) ? sanitize_text_field( wp_unslash( $_POST['q'] ) ) : '';
	$norm  = go_verge_game_intelligence_normalize( $query );
	if ( strlen( $norm ) < 2 ) {
		wp_send_json_success( array( 'results' => array() ) );
	}

	$results = array();
	foreach ( go_verge_game_intelligence_catalog() as $game ) {
		$best = 0;
		foreach ( array_keys( $game['names'] ) as $name ) {
			if ( $name === $norm ) {
				$best = max( $best, 100 );
			} elseif ( 0 === strpos( $name, $norm ) ) {
				$best = max( $best, 95 );
			} elseif ( false !== strpos( $name, $norm ) ) {
				$best = max( $best, 90 );
			} else {
				$best = max( $best, go_verge_game_intelligence_token_score( $norm, $name ) );
			}
		}
		if ( $best < 55 ) {
			continue;
		}
		$results[] = array(
			'id'    => $game['id'],
			'title' => $game['title'],
			'image' => $game['image'],
			'score' => $best,
		);
	}
	usort( $results, static function ( $a, $b ) {
		if ( $a['score'] === $b['score'] ) {
			return strcasecmp( $a['title'], $b['title'] );
		}
		return $b['score'] <=> $a['score'];
	} );
	wp_send_json_success( array( 'results' => array_slice( $results, 0, 12 ) ) );
}
add_action( 'wp_ajax_go_verge_game_intelligence_search', 'go_verge_game_intelligence_ajax_search' );

/** AJAX persist a manual selection or an explicit unlink. */
function go_verge_game_intelligence_ajax_link() {
	$post_id = go_verge_game_intelligence_ajax_post_id();
	$game_id = isset( $_POST['game_id'] ) ? absint( $_POST['game_id'] ) : 0;
	if ( $game_id && ! go_verge_game_intelligence_valid_game( $game_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Jogo inválido ou não publicado.', 'go-verge' ) ), 400 );
	}
	go_verge_game_intelligence_write_link( $post_id, $game_id, $game_id ? 'manual' : 'none' );
	wp_send_json_success(
		array(
			'game' => $game_id ? go_verge_game_intelligence_game_payload( $game_id ) : null,
			'mode' => $game_id ? 'manual' : 'none',
		)
	);
}
add_action( 'wp_ajax_go_verge_game_intelligence_link', 'go_verge_game_intelligence_ajax_link' );

/** AJAX analyze current saved + unsaved editor context without changing the relationship. */
function go_verge_game_intelligence_ajax_analyze() {
	$post_id = go_verge_game_intelligence_ajax_post_id();
	$overrides = array(
		'title'     => isset( $_POST['title'] ) ? sanitize_text_field( wp_unslash( $_POST['title'] ) ) : '',
		'seo_title' => isset( $_POST['seo_title'] ) ? sanitize_text_field( wp_unslash( $_POST['seo_title'] ) ) : '',
		'content'   => isset( $_POST['content'] ) ? wp_kses_post( wp_unslash( $_POST['content'] ) ) : '',
		'excerpt'   => isset( $_POST['excerpt'] ) ? sanitize_textarea_field( wp_unslash( $_POST['excerpt'] ) ) : '',
	);
	$analysis = go_verge_game_intelligence_analyze( $post_id, $overrides );
	go_verge_game_intelligence_store_suggestion( $post_id, $analysis );

	$linked = false; // Analysis is suggestion-only; persistence happens on save/manual selection.

	$candidate = ! empty( $analysis['candidate']['id'] ) ? go_verge_game_intelligence_game_payload( $analysis['candidate']['id'] ) : null;
	wp_send_json_success(
		array(
			'candidate' => $candidate,
			'score'     => (int) $analysis['score'],
			'reason'    => sanitize_text_field( $analysis['reason'] ),
			'linked'    => (bool) $linked,
			'mode'      => $linked ? 'auto' : (string) get_post_meta( $post_id, '_go_game_intelligence_mode', true ),
		)
	);
}
add_action( 'wp_ajax_go_verge_game_intelligence_analyze', 'go_verge_game_intelligence_ajax_analyze' );

/** Save mode from classic editor and guarantee canonical/legacy consistency. */
function go_verge_game_intelligence_save_editor_state( $post_id ) {
	if ( ! isset( $_POST['go_verge_linked_game_nonce'] ) ) {
		return;
	}
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_linked_game_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_linked_game' ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}
	if ( ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	$game_id = isset( $_POST['go_linked_game_id'] ) ? absint( wp_unslash( $_POST['go_linked_game_id'] ) ) : 0;
	$mode    = isset( $_POST['go_game_intelligence_mode'] ) ? sanitize_key( wp_unslash( $_POST['go_game_intelligence_mode'] ) ) : '';
	if ( $game_id && go_verge_game_intelligence_valid_game( $game_id ) ) {
		go_verge_game_intelligence_write_link( $post_id, $game_id, 'auto' === $mode ? 'auto' : 'manual' );
	} elseif ( 'none' === $mode ) {
		go_verge_game_intelligence_write_link( $post_id, 0, 'none' );
	}
}
add_action( 'save_post_post', 'go_verge_game_intelligence_save_editor_state', 35 );

/**
 * Automatic detection after save. Manual selections and explicit "none" are
 * respected; otherwise the post is analyzed and linked only when unambiguous.
 */
function go_verge_game_intelligence_auto_link_on_save( $post_id, $post, $update ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	if ( ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( in_array( $post->post_status, array( 'auto-draft', 'trash' ), true ) || '' === trim( wp_strip_all_tags( $post->post_title ) ) ) {
		return;
	}
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) {
		go_verge_defer_post_save_maintenance( $post_id );
		return;
	}

	$current = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	if ( ! $current ) {
		$current = absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	}
	$mode    = (string) get_post_meta( $post_id, '_go_game_intelligence_mode', true );
	$opt_out = '1' === (string) get_post_meta( $post_id, '_go_game_intelligence_opt_out', true );
	if ( $current && go_verge_game_intelligence_valid_game( $current ) ) {
		// Repair both directions when an older editor/API wrote only one key.
		update_post_meta( $post_id, 'go_linked_game_id', $current );
		update_post_meta( $post_id, 'go_review_game_id', $current );
		// Legacy links without a mode are treated as deliberate manual choices.
		if ( '' === $mode ) {
			update_post_meta( $post_id, '_go_game_intelligence_mode', 'manual' );
			return;
		}
	}
	if ( $current && ! go_verge_game_intelligence_valid_game( $current ) ) {
		delete_post_meta( $post_id, 'go_linked_game_id' );
		delete_post_meta( $post_id, 'go_review_game_id' );
		$current = 0;
	}

	if ( 'manual' === $mode || $opt_out ) {
		return;
	}

	$context = go_verge_game_intelligence_context( $post_id );
	$hash    = md5( 'v6|' . wp_json_encode( $context ) );
	if ( $hash && $hash === (string) get_post_meta( $post_id, '_go_game_intelligence_context_hash', true ) ) {
		return;
	}
	update_post_meta( $post_id, '_go_game_intelligence_context_hash', $hash );

	$analysis = go_verge_game_intelligence_analyze( $post_id );
	go_verge_game_intelligence_store_suggestion( $post_id, $analysis );
	if ( ! empty( $analysis['safe'] ) && ! empty( $analysis['candidate']['id'] ) ) {
		go_verge_game_intelligence_write_link( $post_id, $analysis['candidate']['id'], 'auto' );
	} else {
		go_verge_game_intelligence_write_link( $post_id, 0, 'auto' );
	}
}
add_action( 'save_post_post', 'go_verge_game_intelligence_auto_link_on_save', 120, 3 );

/** REST saves can update post meta after save_post; run a final consistency pass. */
function go_verge_game_intelligence_after_rest_save( $post, $request, $creating ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	$current = absint( get_post_meta( $post->ID, 'go_linked_game_id', true ) );
	if ( $current && go_verge_game_intelligence_valid_game( $current ) ) {
		update_post_meta( $post->ID, 'go_review_game_id', $current );
	}
	/* The matcher can scan a large game catalog. Running it again here duplicates
	 * save_post work and can make Gutenberg time out. Queue one post-save pass. */
	go_verge_defer_post_save_maintenance( $post->ID );
}
add_action( 'rest_after_insert_post', 'go_verge_game_intelligence_after_rest_save', 80, 3 );

/**
 * Re-run matching when an SEO plugin writes its title/keyword after save_post.
 * This closes the timing gap common in Gutenberg and Rank Math REST saves.
 */
function go_verge_game_intelligence_after_seo_meta_change( $meta_id, $post_id, $meta_key, $meta_value ) {
	static $running = false;
	if ( $running || 'post' !== get_post_type( $post_id ) || ! in_array( $meta_key, go_verge_game_intelligence_seo_meta_keys(), true ) ) {
		return;
	}
	if ( '1' === (string) get_post_meta( $post_id, '_go_game_intelligence_opt_out', true ) ) {
		return;
	}
	$mode = (string) get_post_meta( $post_id, '_go_game_intelligence_mode', true );
	if ( 'manual' === $mode ) {
		return;
	}
	$running = true;
	$analysis = go_verge_game_intelligence_analyze( $post_id );
	go_verge_game_intelligence_store_suggestion( $post_id, $analysis );
	if ( ! empty( $analysis['safe'] ) && ! empty( $analysis['candidate']['id'] ) ) {
		go_verge_game_intelligence_write_link( $post_id, $analysis['candidate']['id'], 'auto' );
	} elseif ( 'auto' === $mode ) {
		go_verge_game_intelligence_write_link( $post_id, 0, 'auto' );
	}
	$running = false;
}
add_action( 'added_post_meta', 'go_verge_game_intelligence_after_seo_meta_change', 80, 4 );
add_action( 'updated_post_meta', 'go_verge_game_intelligence_after_seo_meta_change', 80, 4 );

/** Validate an automatic link before other product/schema layers trust it. */
function go_verge_game_intelligence_link_is_trusted( $post_id, $game_id ) {
	$post_id = absint( $post_id );
	$game_id = absint( $game_id );
	if ( ! $post_id || ! $game_id || ! go_verge_game_intelligence_valid_game( $game_id ) ) {
		return false;
	}
	$mode = (string) get_post_meta( $post_id, '_go_game_intelligence_mode', true );
	if ( 'manual' === $mode || '' === $mode ) {
		return true;
	}
	if ( 'auto' !== $mode ) {
		return false;
	}
	$analysis = go_verge_game_intelligence_analyze( $post_id );
	return ! empty( $analysis['safe'] ) && ! empty( $analysis['candidate']['id'] ) && $game_id === absint( $analysis['candidate']['id'] );
}

/**
 * Revalidate historical automatic links in small batches after this matcher
 * hardening. Manual links are never touched. A per-post marker prevents skips
 * when an invalid relation is removed during the migration.
 */
function go_verge_game_intelligence_revalidate_auto_links_batch() {
	if ( get_option( 'go_verge_game_intelligence_revalidated_v6' ) ) {
		return;
	}
	if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( 'game_intelligence_revalidate', 180 ) ) {
		return;
	}

	$ids = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => array( 'publish', 'future', 'draft', 'pending', 'private' ),
			'posts_per_page'         => 12,
			'fields'                 => 'ids',
			'orderby'                => 'ID',
			'order'                  => 'ASC',
			'no_found_rows'          => true,
			'suppress_filters'       => true,
			'update_post_meta_cache' => true,
			'update_post_term_cache' => true,
			'meta_query'             => array(
				'relation' => 'AND',
				array(
					'key'     => '_go_game_intelligence_mode',
					'value'   => 'auto',
					'compare' => '=',
				),
				array(
					'key'     => '_go_game_intelligence_revalidated_v6',
					'compare' => 'NOT EXISTS',
				),
			),
		)
	);

	foreach ( (array) $ids as $post_id ) {
		$current  = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
		$analysis = go_verge_game_intelligence_analyze( $post_id );
		if ( ! empty( $analysis['safe'] ) && ! empty( $analysis['candidate']['id'] ) ) {
			$candidate = absint( $analysis['candidate']['id'] );
			if ( $candidate !== $current ) {
				go_verge_game_intelligence_write_link( $post_id, $candidate, 'auto' );
			}
		} elseif ( $current ) {
			go_verge_game_intelligence_write_link( $post_id, 0, 'auto' );
		}
		go_verge_game_intelligence_store_suggestion( $post_id, $analysis );
		update_post_meta( $post_id, '_go_game_intelligence_revalidated_v6', '1' );
	}

	go_verge_release_job_lock( 'game_intelligence_revalidate' );
	if ( count( $ids ) < 12 ) {
		update_option( 'go_verge_game_intelligence_revalidated_v6', gmdate( 'c' ), false );
		return;
	}
	if ( ! wp_next_scheduled( 'go_verge_game_intelligence_revalidate_auto_links' ) ) {
		wp_schedule_single_event( time() + 5 * MINUTE_IN_SECONDS, 'go_verge_game_intelligence_revalidate_auto_links' );
	}
}
add_action( 'go_verge_game_intelligence_revalidate_auto_links', 'go_verge_game_intelligence_revalidate_auto_links_batch' );

/** Queue the one-time cleanup without processing a heavy batch in admin_init. */
function go_verge_game_intelligence_schedule_revalidation_v6() {
	if ( get_option( 'go_verge_game_intelligence_revalidated_v6' ) ) {
		return;
	}
	if ( ! wp_next_scheduled( 'go_verge_game_intelligence_revalidate_auto_links' ) ) {
		wp_schedule_single_event( time() + 30, 'go_verge_game_intelligence_revalidate_auto_links' );
	}
}
add_action( 'admin_init', 'go_verge_game_intelligence_schedule_revalidation_v6', 80 );
