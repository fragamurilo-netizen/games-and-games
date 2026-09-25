<?php
/**
 * Internal linking tools for the editor.
 *
 * Two things, both aimed at the same problem: linking to our own archive is
 * work, so it does not get done.
 *
 *   1. `go/read-more` — a "Leia mais" block the editor drops anywhere in the
 *      text and fills with one to three stories. It renders the same
 *      .go-inline-related component the theme already injects automatically, so
 *      a manual block and an automatic one are visually identical, and the
 *      advertising density rules already treat that class as protected UI: no
 *      ad will ever land against it.
 *
 *   2. A document sidebar panel with internal link suggestions for the story
 *      being written, drawn from its own tags and categories, each one a click
 *      away from the clipboard. Pasting a URL over selected text is how
 *      WordPress creates a link, so this removes the "what do I link to?" step
 *      without fighting the rich-text API.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Build the inline related component from explicit post IDs.
 *
 * Mirrors the markup of the automatic block so one stylesheet serves both.
 *
 * @param int[]  $ids   Post IDs, in the order the editor arranged them.
 * @param string $label Heading.
 * @return string
 */
function go_verge_read_more_markup( $ids, $label = '' ) {
	$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	if ( empty( $ids ) ) {
		return '';
	}

	$ids   = array_slice( $ids, 0, 3 );
	$label = '' !== trim( (string) $label ) ? trim( (string) $label ) : __( 'Leia mais', 'go-verge' );

	$out  = '<aside class="go-inline-related go-inline-related--secondary go-inline-related--manual"';
	$out .= ' data-go-related-block="read-more" aria-label="' . esc_attr( $label ) . '">';
	$out .= '<p class="go-inline-related__title">' . esc_html( $label ) . '</p>';
	$out .= '<div class="go-inline-related__items">';

	$rendered = 0;
	$rendered_ids = array();
	$used = is_singular( 'post' ) && function_exists( 'go_verge_recirculation_shown_ids' ) ? go_verge_recirculation_shown_ids() : array();
	foreach ( $ids as $related_id ) {
		if ( 'publish' !== get_post_status( $related_id ) || in_array( $related_id, $used, true )
			|| ( is_singular('post') && function_exists( 'go_verge_single_recommendation_eligible' ) && ! go_verge_single_recommendation_eligible( $related_id, get_queried_object_id() ) ) ) {
			continue;
		}
		$rendered++;
		$rendered_ids[] = $related_id;
		$has_thumb = has_post_thumbnail( $related_id );

		$reco_attrs = function_exists( 'go_verge_reco_data_attributes' ) ? ' ' . go_verge_reco_data_attributes( $related_id, 'inline' ) : '';
		$out .= '<a class="go-inline-related__item' . ( $has_thumb ? '' : ' is-no-thumb' ) . '" href="' . esc_url( get_permalink( $related_id ) ) . '"' . $reco_attrs . '>';
		if ( $has_thumb ) {
			$out .= '<span class="go-inline-related__media">' . get_the_post_thumbnail(
				$related_id,
				'go_card',
				array(
					'loading' => 'lazy',
					'alt'     => '',
				)
			) . '</span>';
		}
		$out .= '<span class="go-inline-related__copy"><strong>' . esc_html( get_the_title( $related_id ) ) . '</strong>';
		$out .= '<span class="go-inline-related__meta">' . ( function_exists( 'go_verge_time_html' ) ? go_verge_time_html( $related_id ) : '' ) . '</span>';
		$out .= '</span></a>';
	}

	$out .= '</div></aside>';
	/* Manual choices keep their order and also inform every automatic surface
	 * rendered later. Register only links actually emitted, not deleted picks. */
	if ( $rendered_ids && function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( $rendered_ids );
	}

	// An unpublished or deleted pick must not leave an empty framed box behind.
	return $rendered ? $out : '';
}

/**
 * Render callback for go/read-more.
 *
 * @param array<string,mixed> $attributes Block attributes.
 * @return string
 */
function go_verge_render_read_more_block( $attributes ) {
	$ids   = isset( $attributes['ids'] ) ? (array) $attributes['ids'] : array();
	$label = isset( $attributes['label'] ) ? (string) $attributes['label'] : '';

	return go_verge_read_more_markup( $ids, $label );
}

/**
 * Register the block.
 *
 * @return void
 */
function go_verge_register_linking_blocks() {
	register_block_type(
		'go/read-more',
		array(
			'api_version'     => 2,
			'attributes'      => array(
				'ids'   => array(
					'type'    => 'array',
					'default' => array(),
					'items'   => array( 'type' => 'number' ),
				),
				'label' => array(
					'type'    => 'string',
					'default' => '',
				),
			),
			'render_callback' => 'go_verge_render_read_more_block',
		)
	);
}
add_action( 'init', 'go_verge_register_linking_blocks', 20 );

/**
 * Internal link suggestions for one post.
 *
 * Ordered by how much taxonomy the candidate shares with the story being
 * written, which is a good proxy for "a link here would actually make sense".
 *
 * @param WP_REST_Request $request Request.
 * @return WP_REST_Response
 */
function go_verge_link_suggestions_route( $request ) {
	$post_id = absint( $request->get_param( 'post' ) );
	$search  = sanitize_text_field( (string) $request->get_param( 'search' ) );

	$args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => 12,
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'post__not_in'        => $post_id ? array( $post_id ) : array(),
	);

	if ( '' !== $search ) {
		$args['s'] = $search;
	} elseif ( $post_id && function_exists( 'go_verge_related_post_ids' ) ) {
		$ids = go_verge_related_post_ids( $post_id, 12 );
		if ( ! $ids ) { return rest_ensure_response( array() ); }
		$args['post__in'] = $ids;
		$args['orderby'] = 'post__in';
	} elseif ( $post_id ) {
		$tags       = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) );
		$categories = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'ids' ) );
		$tax_query  = array( 'relation' => 'OR' );

		if ( ! is_wp_error( $tags ) && $tags ) {
			$tax_query[] = array(
				'taxonomy' => 'post_tag',
				'terms'    => $tags,
			);
		}
		if ( ! is_wp_error( $categories ) && $categories ) {
			$tax_query[] = array(
				'taxonomy' => 'category',
				'terms'    => $categories,
			);
		}
		if ( count( $tax_query ) > 1 ) {
			$args['tax_query'] = $tax_query; // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_tax_query
		}
	}

	$results = array();
	foreach ( get_posts( $args ) as $candidate ) {
		$results[] = array(
			'id'    => (int) $candidate->ID,
			'title' => html_entity_decode( get_the_title( $candidate ), ENT_QUOTES, 'UTF-8' ),
			'url'   => get_permalink( $candidate ),
			'date'  => get_the_date( 'd/m/Y', $candidate ),
		);
	}

	return rest_ensure_response( $results );
}

/* --------------------------------------------------------------------------
 * Intelligent contextual linking
 * ------------------------------------------------------------------------ */

/** Multibyte helpers with a safe fallback for lean PHP installations. */
function go_verge_smart_link_lower( $text ) {
	return function_exists( 'mb_strtolower' ) ? mb_strtolower( (string) $text, 'UTF-8' ) : strtolower( (string) $text );
}

function go_verge_smart_link_strlen( $text ) {
	return function_exists( 'mb_strlen' ) ? mb_strlen( (string) $text, 'UTF-8' ) : strlen( (string) $text );
}

function go_verge_smart_link_substr( $text, $start, $length = null ) {
	if ( function_exists( 'mb_substr' ) ) {
		return null === $length
			? mb_substr( (string) $text, (int) $start, null, 'UTF-8' )
			: mb_substr( (string) $text, (int) $start, (int) $length, 'UTF-8' );
	}

	return null === $length ? substr( (string) $text, (int) $start ) : substr( (string) $text, (int) $start, (int) $length );
}

function go_verge_smart_link_stripos( $haystack, $needle ) {
	return function_exists( 'mb_stripos' )
		? mb_stripos( (string) $haystack, (string) $needle, 0, 'UTF-8' )
		: stripos( (string) $haystack, (string) $needle );
}

function go_verge_smart_link_strpos( $haystack, $needle ) {
	return function_exists( 'mb_strpos' )
		? mb_strpos( (string) $haystack, (string) $needle, 0, 'UTF-8' )
		: strpos( (string) $haystack, (string) $needle );
}

/** Normalize editorial text for matching without losing Portuguese words. */
function go_verge_smart_link_normalize( $text ) {
	$text = html_entity_decode( wp_strip_all_tags( (string) $text ), ENT_QUOTES, 'UTF-8' );
	$text = go_verge_smart_link_lower( remove_accents( $text ) );
	$text = preg_replace( '/[^\p{L}\p{N}]+/u', ' ', $text );

	return trim( preg_replace( '/\s+/u', ' ', (string) $text ) );
}

/** Words that do not help decide whether two stories are actually related. */
function go_verge_smart_link_stopwords() {
	static $words = null;
	if ( null !== $words ) {
		return $words;
	}

	$words = array_fill_keys(
		array(
			'a', 'ao', 'aos', 'as', 'com', 'como', 'da', 'das', 'de', 'do', 'dos', 'e', 'em', 'entre',
			'essa', 'esse', 'esta', 'este', 'foi', 'ha', 'mais', 'na', 'nas', 'no', 'nos', 'o', 'os',
			'para', 'pela', 'pelas', 'pelo', 'pelos', 'por', 'que', 'se', 'sem', 'ser', 'sua', 'suas',
			'seu', 'seus', 'um', 'uma', 'veja', 'saiba', 'entenda', 'confira', 'agora', 'novo', 'nova',
		),
		true
	);

	return $words;
}

/** Return meaningful tokens, preserving a compact order-free signal. */
function go_verge_smart_link_tokens( $text ) {
	$tokens = preg_split( '/\s+/u', go_verge_smart_link_normalize( $text ), -1, PREG_SPLIT_NO_EMPTY );
	$stop   = go_verge_smart_link_stopwords();
	$out    = array();

	foreach ( (array) $tokens as $token ) {
		if ( isset( $stop[ $token ] ) || go_verge_smart_link_strlen( $token ) < 2 ) {
			continue;
		}
		$out[ $token ] = true;
	}

	return array_keys( $out );
}

/** Text eligible to become an anchor: body copy only, never an existing link or heading. */
function go_verge_smart_link_body_text( $content ) {
	$content = preg_replace(
		'#<(a|h[1-6]|figcaption|code|pre)\b[^>]*>.*?</\1>#isu',
		' ',
		(string) $content
	);

	return trim( html_entity_decode( wp_strip_all_tags( (string) $content ), ENT_QUOTES, 'UTF-8' ) );
}

/** Existing internal destinations, keyed by URL path, to avoid duplicate links. */
function go_verge_smart_link_existing_paths( $content ) {
	$paths = array();
	if ( preg_match_all( '/<a\b[^>]*href=["\']([^"\']+)["\']/iu', (string) $content, $matches ) ) {
		foreach ( $matches[1] as $url ) {
			$path = (string) wp_parse_url( html_entity_decode( $url, ENT_QUOTES, 'UTF-8' ), PHP_URL_PATH );
			if ( '' !== $path ) {
				$paths[ untrailingslashit( $path ) ] = true;
			}
		}
	}

	return $paths;
}

/** Candidate IDs cached briefly because this tool is used only inside the editor. */
function go_verge_smart_link_candidate_ids() {
	$cache_key = 'go_smart_link_candidates_v2';
	$ids       = get_transient( $cache_key );
	if ( is_array( $ids ) ) {
		return $ids;
	}

	$post_types = array( 'post' );
	foreach ( array( 'games', 'productions', 'go_entity' ) as $post_type ) {
		if ( post_type_exists( $post_type ) ) {
			$post_types[] = $post_type;
		}
	}

	$ids = get_posts(
		array(
			'post_type'              => $post_types,
			'post_status'            => 'publish',
			'posts_per_page'         => 1200,
			'orderby'                => 'modified',
			'order'                  => 'DESC',
			'fields'                 => 'ids',
			'no_found_rows'          => true,
			'ignore_sticky_posts'    => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		)
	);
	$ids = array_values( array_unique( array_map( 'absint', $ids ) ) );
	set_transient( $cache_key, $ids, 10 * MINUTE_IN_SECONDS );

	return $ids;
}

/** Refresh the editor index as soon as a possible destination changes. */
function go_verge_smart_link_bust_candidates() {
	delete_transient( 'go_smart_link_candidates_v2' );
}
add_action( 'save_post_post', 'go_verge_smart_link_bust_candidates' );
add_action( 'save_post_games', 'go_verge_smart_link_bust_candidates' );
add_action( 'save_post_go_entity', 'go_verge_smart_link_bust_candidates' );
add_action( 'deleted_post', 'go_verge_smart_link_bust_candidates' );

/** Extract the original-cased occurrence of a phrase from body copy. */
function go_verge_smart_link_exact_occurrence( $body, $phrase ) {
	$position = go_verge_smart_link_stripos( $body, $phrase );
	if ( false === $position ) {
		return '';
	}

	return go_verge_smart_link_substr( $body, $position, go_verge_smart_link_strlen( $phrase ) );
}

/** Reject generic snippets that would create weak or misleading anchors. */
function go_verge_smart_link_phrase_is_useful( $phrase, $allow_single = false ) {
	$normalized = go_verge_smart_link_normalize( $phrase );
	$tokens     = preg_split( '/\s+/u', $normalized, -1, PREG_SPLIT_NO_EMPTY );
	$blocked    = array( 'veja como', 'saiba mais', 'entenda o', 'entenda a', 'confira a', 'confira o', 'o que e', 'como fazer' );

	if ( go_verge_smart_link_strlen( $normalized ) < 4 || in_array( $normalized, $blocked, true ) ) {
		return false;
	}
	if ( count( $tokens ) < 2 && ! $allow_single ) {
		return false;
	}

	return count( go_verge_smart_link_tokens( $phrase ) ) >= 1;
}

/** Find the strongest exact anchor from a destination title inside the body. */
function go_verge_smart_link_anchor_from_title( $body, $title, $allow_single = false ) {
	$full = go_verge_smart_link_exact_occurrence( $body, $title );
	if ( '' !== $full ) {
		return array( 'anchor' => $full, 'full_title' => true );
	}

	preg_match_all( '/[\p{L}\p{N}][\p{L}\p{N}+.\'’-]*/u', (string) $title, $matches );
	$words = isset( $matches[0] ) ? array_values( $matches[0] ) : array();
	$count = count( $words );

	$minimum_size = $allow_single ? 1 : 2;
	for ( $size = min( 6, $count ); $size >= $minimum_size; $size-- ) {
		for ( $start = 0; $start <= $count - $size; $start++ ) {
			$phrase = implode( ' ', array_slice( $words, $start, $size ) );
			if ( ! go_verge_smart_link_phrase_is_useful( $phrase, $allow_single && 1 === $size ) ) {
				continue;
			}
			$found = go_verge_smart_link_exact_occurrence( $body, $phrase );
			if ( '' !== $found ) {
				return array( 'anchor' => $found, 'full_title' => false );
			}
		}
	}

	return array( 'anchor' => '', 'full_title' => false );
}

/** Ratio of shared meaningful tokens, weighted towards the shorter phrase. */
function go_verge_smart_link_overlap( $left, $right ) {
	$left  = go_verge_smart_link_tokens( $left );
	$right = go_verge_smart_link_tokens( $right );
	if ( empty( $left ) || empty( $right ) ) {
		return 0;
	}

	$shared = array_intersect( $left, $right );

	return count( $shared ) / max( 1, min( count( $left ), count( $right ) ) );
}

/** Build ranked suggestions for a selected phrase or for the whole draft. */
function go_verge_smart_link_suggestions( $args ) {
	$args = wp_parse_args(
		(array) $args,
		array(
			'post_id'  => 0,
			'selected' => '',
			'context'  => '',
			'content'  => '',
			'title'    => '',
			'mode'     => 'document',
		)
	);

	$post_id       = absint( $args['post_id'] );
	$selected      = trim( sanitize_text_field( (string) $args['selected'] ) );
	$context       = trim( sanitize_textarea_field( (string) $args['context'] ) );
	$content       = (string) $args['content'];
	$document_title = trim( sanitize_text_field( (string) $args['title'] ) );
	$selection_mode = 'selection' === (string) $args['mode'] && '' !== $selected;
	$body           = go_verge_smart_link_body_text( $content );
	$existing_paths = go_verge_smart_link_existing_paths( $content );
	$current_tags   = $post_id ? wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) ) : array();
	$current_cats   = $post_id ? wp_get_post_terms( $post_id, 'category', array( 'fields' => 'ids' ) ) : array();
	$current_tags   = is_wp_error( $current_tags ) ? array() : array_map( 'absint', $current_tags );
	$current_cats   = is_wp_error( $current_cats ) ? array() : array_map( 'absint', $current_cats );
	$ranked         = array();

	foreach ( go_verge_smart_link_candidate_ids() as $candidate_id ) {
		if ( $candidate_id === $post_id ) {
			continue;
		}
		$candidate = get_post( $candidate_id );
		if ( ! ( $candidate instanceof WP_Post ) || 'publish' !== $candidate->post_status ) {
			continue;
		}

		$candidate_title = html_entity_decode( get_the_title( $candidate ), ENT_QUOTES, 'UTF-8' );
		$url             = get_permalink( $candidate );
		$path            = untrailingslashit( (string) wp_parse_url( $url, PHP_URL_PATH ) );
		if ( ! $url || ( $path && isset( $existing_paths[ $path ] ) ) ) {
			continue;
		}

		$score   = 0;
		$reasons = array();
		$anchor  = '';
		$full    = false;

		if ( $selection_mode ) {
			$selection_overlap = go_verge_smart_link_overlap( $selected, $candidate_title );
			$selected_norm     = go_verge_smart_link_normalize( $selected );
			$title_norm        = go_verge_smart_link_normalize( $candidate_title );
			if ( $selected_norm === $title_norm ) {
				$score += 120;
				$reasons[] = __( 'O destino corresponde exatamente ao trecho selecionado.', 'go-verge' );
			} elseif ( false !== go_verge_smart_link_strpos( $title_norm, $selected_norm ) || false !== go_verge_smart_link_strpos( $selected_norm, $title_norm ) ) {
				$score += 82;
				$reasons[] = __( 'O trecho selecionado aparece no título do destino.', 'go-verge' );
			}
			$score += (int) round( 58 * $selection_overlap );
			if ( $selection_overlap >= 0.5 && empty( $reasons ) ) {
				$reasons[] = __( 'O título compartilha os termos centrais da seleção.', 'go-verge' );
			}
			$anchor = $selected;
		} else {
			$allow_single = in_array( $candidate->post_type, array( 'games', 'productions', 'go_entity' ), true );
			$anchor_data = go_verge_smart_link_anchor_from_title( $body, $candidate_title, $allow_single );
			$anchor      = $anchor_data['anchor'];
			$full        = ! empty( $anchor_data['full_title'] );
			if ( '' === $anchor ) {
				continue;
			}
			$score += $full ? 95 : 62;
			$reasons[] = $full
				? __( 'O título completo do destino já aparece no texto.', 'go-verge' )
				: __( 'Uma expressão específica do destino já aparece no texto.', 'go-verge' );
		}

		$context_overlap = go_verge_smart_link_overlap( $context, $candidate_title );
		$title_overlap   = go_verge_smart_link_overlap( $document_title, $candidate_title );
		$score          += (int) round( 34 * $context_overlap );
		$score          += (int) round( 22 * $title_overlap );
		if ( $context_overlap >= 0.5 ) {
			$reasons[] = __( 'Também combina com o contexto do parágrafo.', 'go-verge' );
		}

		if ( in_array( $candidate->post_type, array( 'games', 'productions', 'go_entity' ), true ) && go_verge_smart_link_overlap( $anchor, $candidate_title ) >= 0.5 ) {
			$score += 8;
		}

		if ( $score < ( $selection_mode ? 38 : 55 ) ) {
			continue;
		}

		$ranked[] = array(
			'id'        => (int) $candidate->ID,
			'title'     => $candidate_title,
			'url'       => $url,
			'date'      => get_the_date( 'd/m/Y', $candidate ),
			'post_type' => $candidate->post_type,
			'anchor'    => $anchor,
			'score'     => $score,
			'reasons'   => $reasons,
			'full'      => $full,
		);
	}

	usort(
		$ranked,
		static function ( $left, $right ) {
			return $right['score'] <=> $left['score'];
		}
	);
	$ranked = array_slice( $ranked, 0, 60 );

	foreach ( $ranked as &$item ) {
		$candidate_tags = wp_get_post_terms( $item['id'], 'post_tag', array( 'fields' => 'ids' ) );
		$candidate_cats = wp_get_post_terms( $item['id'], 'category', array( 'fields' => 'ids' ) );
		$candidate_tags = is_wp_error( $candidate_tags ) ? array() : array_map( 'absint', $candidate_tags );
		$candidate_cats = is_wp_error( $candidate_cats ) ? array() : array_map( 'absint', $candidate_cats );
		$shared_tags    = count( array_intersect( $current_tags, $candidate_tags ) );
		$shared_cats    = count( array_intersect( $current_cats, $candidate_cats ) );

		$item['score'] += min( 24, ( $shared_tags * 8 ) + ( $shared_cats * 5 ) );
		if ( $shared_tags || $shared_cats ) {
			$item['reasons'][] = __( 'Compartilha assunto ou editoria com a matéria.', 'go-verge' );
		}
		$item['confidence'] = $item['score'] >= 105 ? 'alta' : ( $item['score'] >= 72 ? 'boa' : 'possível' );
		$item['typeLabel']  = 'games' === $item['post_type']
			? __( 'Ficha de jogo', 'go-verge' )
			: ( 'productions' === $item['post_type'] ? __( 'Produção', 'go-verge' ) : ( 'go_entity' === $item['post_type'] ? __( 'Entidade', 'go-verge' ) : __( 'Matéria', 'go-verge' ) ) );
		$item['reason']     = implode( ' ', array_slice( array_values( array_unique( $item['reasons'] ) ), 0, 2 ) );
		unset( $item['reasons'], $item['full'], $item['post_type'] );
	}
	unset( $item );

	usort(
		$ranked,
		static function ( $left, $right ) {
			return $right['score'] <=> $left['score'];
		}
	);

	return array_slice( $ranked, 0, 8 );
}

/** REST callback for live, unsaved Gutenberg content. */
function go_verge_smart_links_route( WP_REST_Request $request ) {
	$post_id = absint( $request->get_param( 'post' ) );
	$items   = go_verge_smart_link_suggestions(
		array(
			'post_id'  => $post_id,
			'selected' => go_verge_smart_link_substr( sanitize_text_field( (string) $request->get_param( 'selected' ) ), 0, 180 ),
			'context'  => go_verge_smart_link_substr( sanitize_textarea_field( (string) $request->get_param( 'context' ) ), 0, 1200 ),
			'content'  => wp_kses_post( (string) $request->get_param( 'content' ) ),
			'title'    => go_verge_smart_link_substr( sanitize_text_field( (string) $request->get_param( 'title' ) ), 0, 240 ),
			'mode'     => sanitize_key( (string) $request->get_param( 'mode' ) ),
		)
	);

	return rest_ensure_response( array( 'items' => $items ) );
}

/**
 * Expose the suggestions endpoint to logged-in editors only.
 *
 * @return void
 */
function go_verge_register_linking_routes() {
	register_rest_route(
		'go-verge/v1',
		'/link-suggestions',
		array(
			'methods'             => 'GET',
			'callback'            => 'go_verge_link_suggestions_route',
			'permission_callback' => static function () {
				return current_user_can( 'edit_posts' );
			},
			'args'                => array(
				'post'   => array( 'type' => 'integer' ),
				'search' => array( 'type' => 'string' ),
			),
		)
	);

	register_rest_route(
		'go-verge/v1',
		'/smart-links',
		array(
			'methods'             => 'POST',
			'callback'            => 'go_verge_smart_links_route',
			'permission_callback' => static function ( WP_REST_Request $request ) {
				$post_id = absint( $request->get_param( 'post' ) );

				return $post_id ? current_user_can( 'edit_post', $post_id ) : current_user_can( 'edit_posts' );
			},
		)
	);
}
add_action( 'rest_api_init', 'go_verge_register_linking_routes' );

/**
 * Editor assets.
 *
 * @return void
 */
function go_verge_linking_editor_assets() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( defined( 'GED_VERSION' ) && $screen && 'post' === $screen->post_type ) {
		return;
	}
	$rel = '/assets/js/editor-linking.js';
	$css = '/assets/css/editor-linking.css';
	wp_enqueue_style(
		'go-verge-editor-linking',
		GO_VERGE_URI . $css,
		array(),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $css ) : GO_VERGE_VERSION
	);
	wp_enqueue_script(
		'go-verge-editor-linking',
		GO_VERGE_URI . $rel,
		array( 'wp-blocks', 'wp-element', 'wp-components', 'wp-block-editor', 'wp-compose', 'wp-data', 'wp-hooks', 'wp-i18n', 'wp-api-fetch', 'wp-plugins', 'wp-rich-text', 'wp-editor', 'wp-edit-post' ),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $rel ) : GO_VERGE_VERSION,
		true
	);
}
add_action( 'enqueue_block_editor_assets', 'go_verge_linking_editor_assets' );
