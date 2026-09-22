<?php
/**
 * Review scorecard: reads the meta fields already populated by the site's
 * editorial workflow (originally written by news-magazine-x / ACF) — nota,
 * verdict, pros/cons, platform/genre/developer/publisher, comparison scores.
 * Theme-agnostic data, just rendered here in the new design system.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * First non-empty value across a list of candidate meta keys.
 */
function go_verge_review_meta( $post_id, $keys ) {
	foreach ( (array) $keys as $key ) {
		$value = get_post_meta( $post_id, $key, true );
		if ( '' !== trim( wp_strip_all_tags( (string) $value ) ) ) {
			return $value;
		}
	}
	return '';
}

/**
 * Split a newline-separated meta value (how go_review_pros/cons are stored)
 * into a clean list of lines.
 */
function go_verge_review_lines( $text ) {
	if ( '' === trim( (string) $text ) ) {
		return array();
	}
	$lines = preg_split( '/\r\n|\r|\n/', (string) $text );
	return array_values( array_filter( array_map( 'trim', $lines ) ) );
}

/**
 * Normalise editorial copy before comparing summary and verdict fields.
 * This prevents the same text from being rendered twice because of casing,
 * punctuation or whitespace differences in legacy metadata.
 */
function go_verge_review_copy_key( $text ) {
	$text = remove_accents( wp_strip_all_tags( (string) $text ) );
	$text = function_exists( 'mb_strtolower' ) ? mb_strtolower( $text, 'UTF-8' ) : strtolower( $text );
	$text = preg_replace( '/[^a-z0-9]+/u', ' ', $text );
	$text = trim( preg_replace( '/\s+/u', ' ', (string) $text ) );
	$text = preg_replace( '/^(?:resumo|veredito(?: final)?|vale a pena assistir)\s+/u', '', (string) $text );
	return trim( (string) $text );
}

/**
 * Return whether two non-empty editorial fields carry effectively the same copy.
 */
function go_verge_review_copy_is_duplicate( $first, $second ) {
	$first_key  = go_verge_review_copy_key( $first );
	$second_key = go_verge_review_copy_key( $second );
	return '' !== $first_key && $first_key === $second_key;
}


/**
 * Normalise a review score to the editorial 0-10 scale.
 * Legacy 0-100 values are converted to 0-10.
 *
 * @param mixed $score Raw score.
 * @return float|null
 */
function go_verge_normalize_review_score( $score ) {
	if ( is_string( $score ) ) {
		$score = str_replace( ',', '.', trim( $score ) );
	}
	if ( '' === $score || null === $score || ! is_numeric( $score ) ) {
		return null;
	}

	$score = (float) $score;
	if ( $score > 10 ) {
		$score = $score / 10;
	}

	$score = max( 0, min( 10, $score ) );

	return round( $score, 1 );
}

/**
 * Editorial display format for scores.
 *
 * @param float|int|null $score Score already normalised or raw.
 * @return string
 */
function go_verge_review_score_display( $score ) {
	$score = go_verge_normalize_review_score( $score );
	if ( null === $score ) {
		return '';
	}

	return rtrim( rtrim( number_format( (float) $score, 1, '.', '' ), '0' ), '.' );
}


/**
 * Build title candidates for matching a review post to a Games CPT profile.
 * The function is deliberately conservative and never invents a URL.
 *
 * @param int $post_id Review post ID.
 * @return array
 */
function go_verge_review_game_title_candidates( $post_id ) {
	$title      = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( get_the_title( $post_id ) ) ) );
	$candidates = array();

	if ( '' === $title ) {
		return $candidates;
	}

	$patterns = array(
		'/^(?:review|an[áa]lise)\s+(?:de|do|da)?\s*(.+?)(?:\s*[:|–—-]\s*|\s+vale a pena\??|$)/iu',
		'/^(.+?)\s+(?:vale a pena\??|[ée] bom\??|review\b|an[áa]lise\b)/iu',
		'/^(.+?)\s+(?:[ée]|est[áa]|tem|ganha|recebe|chega|volta|acerta|erra|entrega|traz)\b/iu',
	);
	foreach ( $patterns as $pattern ) {
		if ( preg_match( $pattern, $title, $matches ) && ! empty( $matches[1] ) ) {
			$candidates[] = trim( $matches[1] );
		}
	}

	foreach ( array( ':', '–', '—', '|', '•' ) as $separator ) {
		$position = strpos( $title, $separator );
		if ( false !== $position ) {
			$part = trim( substr( $title, 0, $position ) );
			if ( '' !== $part ) {
				$candidates[] = $part;
			}
		}
	}

	$normalized = preg_replace(
		'/^(review|an[áa]lise|cr[íi]tica|vale a pena)\s+(de|do|da)?\s*/iu',
		'',
		$title
	);
	if ( is_string( $normalized ) && '' !== trim( $normalized ) ) {
		$candidates[] = trim( $normalized );
	}

	// Keep the full title last, useful only for exact CPT matches.
	$candidates[] = $title;

	$candidates = array_map(
		static function ( $candidate ) {
			$candidate = trim( preg_replace( '/\s+/u', ' ', (string) $candidate ) );
			$candidate = preg_replace( '/[?:!.,;]+$/u', '', $candidate );
			return trim( (string) $candidate );
		},
		$candidates
	);

	return array_values( array_unique( array_filter( $candidates ) ) );
}

/**
 * Resolve a real Games CPT profile. Never fabricates a profile URL.
 */
function go_verge_review_game_profile( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return null;
	}

	/*
	 * Listings resolve this for every card; without an explicit relationship each
	 * resolution runs one title query per candidate. The answer changes only when
	 * the post or the Games catalog changes: memoize per request and cache the
	 * title-matched result per post (keyed by modification date) for 12 hours.
	 */
	static $memo = array();
	if ( array_key_exists( $post_id, $memo ) ) {
		return $memo[ $post_id ];
	}

	$meta_id = go_verge_review_meta(
		$post_id,
		array(
			'go_linked_game_id',
			'go_review_game_id',
			'review_game_id',
			'_go_related_game',
			'_go_related_game_id',
			'related_game',
			'related_game_id',
			'go_related_game',
			'_go_game_post_id',
			'game_id',
		)
	);

	if ( is_numeric( $meta_id ) ) {
		$game_id = absint( $meta_id );
		if ( $game_id && 'games' === get_post_type( $game_id ) && 'publish' === get_post_status( $game_id ) ) {
			return $memo[ $post_id ] = array(
				'id'    => $game_id,
				'title' => get_the_title( $game_id ),
				'url'   => get_permalink( $game_id ),
			);
		}
	}

	$cache_key = 'go_rgp_' . $post_id;
	$modified  = (string) get_post_field( 'post_modified_gmt', $post_id );
	$cached    = get_transient( $cache_key );
	if ( is_array( $cached ) && isset( $cached['m'] ) && $cached['m'] === $modified && array_key_exists( 'g', $cached ) ) {
		$game_id = absint( $cached['g'] );
		if ( ! $game_id ) {
			return $memo[ $post_id ] = null;
		}
		if ( 'games' === get_post_type( $game_id ) && 'publish' === get_post_status( $game_id ) ) {
			return $memo[ $post_id ] = array(
				'id'    => $game_id,
				'title' => get_the_title( $game_id ),
				'url'   => get_permalink( $game_id ),
			);
		}
	}

	foreach ( go_verge_review_game_title_candidates( $post_id ) as $candidate ) {
		$query = new WP_Query(
			array(
				'post_type'              => 'games',
				'post_status'            => 'publish',
				'posts_per_page'         => 1,
				'no_found_rows'          => true,
				'ignore_sticky_posts'    => true,
				'title'                  => $candidate,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
			)
		);

		if ( ! empty( $query->posts ) ) {
			$game_id = (int) $query->posts[0]->ID;
			wp_reset_postdata();
			set_transient( $cache_key, array( 'm' => $modified, 'g' => $game_id ), 12 * HOUR_IN_SECONDS );
			return $memo[ $post_id ] = array(
				'id'    => $game_id,
				'title' => get_the_title( $game_id ),
				'url'   => get_permalink( $game_id ),
			);
		}
		wp_reset_postdata();
	}

	set_transient( $cache_key, array( 'm' => $modified, 'g' => 0 ), 12 * HOUR_IN_SECONDS );
	return $memo[ $post_id ] = null;
}

/**
 * Resolve the game name even when no Games CPT profile exists.
 */
function go_verge_review_game_name( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return '';
	}

	$explicit = go_verge_review_meta(
		$post_id,
		array( 'go_review_game_name', 'review_game_name', 'game_name', '_go_game_name' )
	);
	if ( '' !== trim( (string) $explicit ) ) {
		return function_exists( 'go_verge_prepare_game_name' ) ? go_verge_prepare_game_name( $explicit ) : trim( wp_strip_all_tags( (string) $explicit ) );
	}

	$profile = go_verge_review_game_profile( $post_id );
	if ( ! empty( $profile['title'] ) ) {
		return function_exists( 'go_verge_prepare_game_name' ) ? go_verge_prepare_game_name( $profile['title'] ) : trim( wp_strip_all_tags( (string) $profile['title'] ) );
	}

	$candidates = go_verge_review_game_title_candidates( $post_id );
	return ! empty( $candidates ) ? $candidates[0] : '';
}

/**
 * Resolve the technical-sheet configuration and selected subject.
 *
 * @param int|null $post_id Post ID.
 * @param bool     $is_critique Whether current post is a critique.
 * @return array{enabled:bool,configured:bool,label:string,value:string,type:string}
 */
function go_verge_review_technical_sheet( $post_id = null, $is_critique = false ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$result  = array(
		'enabled'    => false,
		'configured' => false,
		'label'      => '',
		'value'      => '',
		'type'       => '',
	);
	if ( ! $post_id ) {
		return $result;
	}

	$configured = metadata_exists( 'post', $post_id, 'go_technical_sheet_configured' );
	$enabled    = '1' === (string) get_post_meta( $post_id, 'go_technical_sheet_enabled', true );
	$reference  = trim( (string) get_post_meta( $post_id, 'go_technical_subject_ref', true ) );
	$custom     = trim( (string) get_post_meta( $post_id, 'go_technical_subject_custom', true ) );

	// A filled technical sheet must never disappear because the separate
	// selector checkbox was not saved. This also repairs critiques created while
	// the two editor boxes were independent from each other.
	$has_manual_details = false;
	if ( function_exists( 'go_verge_technical_detail_fields' ) ) {
		foreach ( go_verge_technical_detail_fields() as $detail_key => $detail_label ) {
			if ( '' !== trim( (string) get_post_meta( $post_id, $detail_key, true ) ) ) {
				$has_manual_details = true;
				break;
			}
		}
	}

	// Reviews created before the selector existed keep their historical sheet;
	// manually filled details always opt the article into displaying it.
	if ( ! $configured || $has_manual_details ) {
		$enabled = true;
		if ( '' === $reference ) {
			$reference = 'auto';
		}
	}

	$result['configured'] = $configured;
	$result['enabled']    = $enabled;
	if ( ! $enabled ) {
		return $result;
	}

	if ( preg_match( '/^(games|productions|go_entity):(\d+)$/', $reference, $matches ) ) {
		$post_type = $matches[1];
		$object_id = absint( $matches[2] );
		if ( $object_id && $post_type === get_post_type( $object_id ) && 'publish' === get_post_status( $object_id ) ) {
			$result['label'] = 'games' === $post_type ? __( 'Game', 'go-verge' ) : ( 'productions' === $post_type ? __( 'Produção', 'go-verge' ) : __( 'Assunto', 'go-verge' ) );
			$result['value'] = sprintf(
				'<a href="%1$s">%2$s</a>',
				esc_url( get_permalink( $object_id ) ),
				esc_html( get_the_title( $object_id ) )
			);
			$result['type'] = $post_type;
			return $result;
		}
	}

	if ( 'custom' === $reference && '' !== $custom ) {
		$result['label'] = __( 'Assunto', 'go-verge' );
		$result['value'] = esc_html( $custom );
		$result['type']  = 'custom';
		return $result;
	}

	if ( $is_critique ) {
		$work_name = trim( (string) go_verge_review_meta( $post_id, array( 'go_critique_work_name' ) ) );
		if ( '' !== $work_name ) {
			$result['label'] = __( 'Obra', 'go-verge' );
			$result['value'] = esc_html( $work_name );
			$result['type']  = 'auto';
		}
		return $result;
	}

	$profile = go_verge_review_game_profile( $post_id );
	$name    = go_verge_review_game_name( $post_id );
	if ( ! empty( $profile['url'] ) && '' !== $name ) {
		$result['label'] = __( 'Game', 'go-verge' );
		$result['value'] = sprintf( '<a href="%1$s">%2$s</a>', esc_url( $profile['url'] ), esc_html( $name ) );
		$result['type']  = 'games';
	} elseif ( '' !== $name ) {
		$result['label'] = __( 'Game', 'go-verge' );
		$result['value'] = esc_html( $name );
		$result['type']  = 'auto';
	}

	return $result;
}

/**
 * Gather everything a review might have into one array. `has_review` is
 * true when there's enough to justify showing the scorecard at all.
 */
function go_verge_review_data( $post_id = null ) {
	$post_id    = $post_id ? $post_id : get_the_ID();
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );

	$score_keys = $is_critique
		? array( 'go_critique_score', 'nota', 'go_review_score', '_go_review_score', 'review_score', '_review_score' )
		: array( 'nota', 'go_review_score', '_go_review_score', 'review_score', '_review_score' );
	$score_raw = go_verge_review_meta( $post_id, $score_keys );
	$score     = go_verge_normalize_review_score( $score_raw );

	if ( $is_critique ) {
		// Critiques have their own canonical fields. Legacy review metadata is
		// only a migration fallback and is never allowed to duplicate the other
		// block on the public article.
		$verdict = go_verge_review_meta( $post_id, array( 'go_critique_verdict', 'go_review_verdict', 'review_verdict', 'veredito_final' ) );
		$summary = go_verge_review_meta( $post_id, array( 'go_critique_summary', 'go_review_should_play', 'vale_a_pena' ) );
		if ( go_verge_review_copy_is_duplicate( $summary, $verdict ) ) {
			$summary = '';
		}
		$pros    = go_verge_review_lines( go_verge_review_meta( $post_id, array( 'go_critique_pros', 'go_review_pros' ) ) );
		$cons    = go_verge_review_lines( go_verge_review_meta( $post_id, array( 'go_critique_cons', 'go_review_cons' ) ) );
	} else {
		$verdict = go_verge_review_meta( $post_id, array( 'go_review_verdict', 'review_verdict', 'veredito_final' ) );
		$summary = go_verge_review_meta( $post_id, array( 'go_review_summary', 'review_summary', 'resumo_avaliador' ) );
		$pros    = go_verge_review_lines( go_verge_review_meta( $post_id, array( 'go_review_pros' ) ) );
		$cons    = go_verge_review_lines( go_verge_review_meta( $post_id, array( 'go_review_cons' ) ) );
	}

	$technical_sheet   = go_verge_review_technical_sheet( $post_id, $is_critique );
	$technical_details = function_exists( 'go_verge_review_technical_details' ) ? go_verge_review_technical_details( $post_id, $is_critique ) : array();

	// A post counts as a review only when it carries an actual review JUDGEMENT:
	// a score, a verdict, a summary, or pros/cons. A technical sheet on its own is
	// game metadata (developer, platform, release date…) that legitimately appears
	// on news and previews about a game, so it must NOT, by itself, classify a
	// post as a review — doing so mislabels news stories as "Review" (e.g. a
	// "chega à fase Gold" announcement showing the REVIEW pill).
	$data = array(
		'has_review'   => ( null !== $score || '' !== $summary || '' !== $verdict || ! empty( $pros ) || ! empty( $cons ) ),
		'is_critique'  => $is_critique,
		'score'        => $score,
		'metacritic'   => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'nota_no_metacritic' ) ),
		'opencritic'   => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'nota_no_opencritic' ) ),
		'summary'      => $summary,
		'verdict'      => $verdict,
		'should_play'  => $is_critique ? $summary : go_verge_review_meta( $post_id, array( 'go_review_should_play', 'vale_a_pena' ) ),
		'pros'         => $pros,
		'cons'         => $cons,
		'platform'     => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'review_platform' ) ),
		'genre'        => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'review_genre' ) ),
		'developer'    => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'review_developer' ) ),
		'publisher'    => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'review_publisher' ) ),
		'release_date' => $is_critique ? '' : go_verge_review_meta( $post_id, array( 'review_release_date' ) ),
		'reviewer'     => go_verge_review_meta( $post_id, array( 'reviewer' ) ),
		'game_profile' => $is_critique ? null : go_verge_review_game_profile( $post_id ),
		'game_name'    => $is_critique ? '' : go_verge_review_game_name( $post_id ),
		'work_name'       => $is_critique ? go_verge_review_meta( $post_id, array( 'go_critique_work_name' ) ) : '',
		'work_type'       => $is_critique ? go_verge_review_meta( $post_id, array( 'go_critique_work_type' ) ) : '',
		'technical_sheet'   => $technical_sheet,
		'technical_details' => $technical_details,
	);

	return $data;
}

/**
 * Score tier — drives the badge color (mirrors go_verge_score_badge's tiers).
 */
function go_verge_review_score_tier( $score ) {
	if ( null === $score ) {
		return '';
	}
	if ( $score >= 8 ) {
		return 'is-high';
	}
	return $score >= 5 ? 'is-mid' : 'is-low';
}

/**
 * One-word verdict for a score (IGN-style rating word). Turns a bare number into
 * an editorial judgement — "Ótimo", "Bom", "Mediano"…
 */
function go_verge_review_score_word( $score ) {
	if ( null === $score ) {
		return '';
	}
	$score = (float) $score;
	if ( $score >= 9 ) {
		return __( 'Excepcional', 'go-verge' );
	}
	if ( $score >= 8 ) {
		return __( 'Ótimo', 'go-verge' );
	}
	if ( $score >= 7 ) {
		return __( 'Bom', 'go-verge' );
	}
	if ( $score >= 6 ) {
		return __( 'Decente', 'go-verge' );
	}
	if ( $score >= 5 ) {
		return __( 'Mediano', 'go-verge' );
	}
	if ( $score >= 3 ) {
		return __( 'Fraco', 'go-verge' );
	}
	return __( 'Ruim', 'go-verge' );
}

/**
 * Render the full review scorecard: score, verdict, specs, pros/cons.
 * No-ops when the post has no review data at all.
 */
/** Available editorial facts; never manufacture a specification. */
function go_verge_review_spec_rows( $data ) {
	$sheet   = isset( $data['technical_sheet'] ) && is_array( $data['technical_sheet'] ) ? $data['technical_sheet'] : array();
	$details = isset( $data['technical_details'] ) && is_array( $data['technical_details'] ) ? $data['technical_details'] : array();
	$kind    = ! empty( $details['kind'] ) ? (string) $details['kind'] : ( ! empty( $data['is_critique'] ) ? (string) $data['work_type'] : 'game' );
	$is_critique = ! empty( $data['is_critique'] );
	$type_labels = array(
		'game'         => __( 'Jogo', 'go-verge' ),
		'filme'        => __( 'Filme', 'go-verge' ),
		'serie'        => __( 'Série', 'go-verge' ),
		'anime'        => __( 'Anime', 'go-verge' ),
		'documentario' => __( 'Documentário', 'go-verge' ),
		'outro'        => __( 'Outro', 'go-verge' ),
	);

	if ( ! empty( $sheet['enabled'] ) ) {
		$subject_label = ! empty( $sheet['label'] ) ? $sheet['label'] : ( 'game' === $kind ? __( 'Game', 'go-verge' ) : __( 'Obra', 'go-verge' ) );
		$subject_value = ! empty( $sheet['value'] ) ? $sheet['value'] : '';
		if ( '' === $subject_value && ! empty( $details['title'] ) ) {
			$subject_value = esc_html( $details['title'] );
		} elseif ( '' === $subject_value && ! empty( $data['work_name'] ) ) {
			$subject_value = esc_html( $data['work_name'] );
		}

		if ( 'game' === $kind ) {
			$specs = array(
				$subject_label                     => $subject_value,
				__( 'Plataforma', 'go-verge' )     => $details['platform'] ?? $data['platform'],
				__( 'Gênero', 'go-verge' )         => $details['genre'] ?? $data['genre'],
				__( 'Desenvolvedora', 'go-verge' ) => $details['developer'] ?? $data['developer'],
				__( 'Publisher', 'go-verge' )      => $details['publisher'] ?? $data['publisher'],
				__( 'Lançamento', 'go-verge' )     => $details['release_date'] ?? ( function_exists( 'go_verge_game_release_display' ) ? go_verge_game_release_display( $data['release_date'] ) : $data['release_date'] ),
			);
		} else {
			$specs = array(
				$subject_label                         => $subject_value,
				__( 'Tipo', 'go-verge' )               => $type_labels[ $kind ] ?? '',
				__( 'Gênero', 'go-verge' )             => $details['genre'] ?? '',
				__( 'Direção', 'go-verge' )            => $details['director'] ?? '',
				__( 'Roteiro', 'go-verge' )            => $details['writer'] ?? '',
				__( 'Elenco principal', 'go-verge' )   => $details['cast'] ?? '',
				__( 'Estúdio / distribuição', 'go-verge' ) => $details['studio'] ?? '',
				__( 'Duração', 'go-verge' )             => $details['duration'] ?? '',
				__( 'Classificação', 'go-verge' )       => $details['rating'] ?? '',
				__( 'País', 'go-verge' )                => $details['country'] ?? '',
				__( 'Lançamento', 'go-verge' )          => $details['release_date'] ?? '',
				__( 'Onde assistir', 'go-verge' )       => $details['streaming'] ?? '',
			);
		}
	} else {
		$specs = array();
	}
	$specs     = array_filter( $specs );
	return $specs;
}

function go_verge_review_box( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( function_exists( 'go_verge_should_show_review_scores' ) && ! go_verge_should_show_review_scores( $post_id ) ) {
		return;
	}
	$data = go_verge_review_data( $post_id );

	if ( ! $data['has_review'] ) {
		return;
	}

	$specs = go_verge_review_spec_rows( $data );
	$is_critique = ! empty( $data['is_critique'] );
	$has_extra = ( $data['metacritic'] || $data['opencritic'] || ! empty( $data['pros'] ) || ! empty( $data['cons'] ) || ! empty( $specs ) || $data['reviewer'] );

	echo '<div class="go-review-box ' . ( $is_critique ? 'go-review-box--critique' : 'go-review-box--review' ) . '">';

	// Anchor the scorecard in the heading outline. Without an H2 here the first
	// headings inside the box are the "Prós"/"Contras" H3s, which sit directly
	// under the article H1 and create an invalid 1 -> 3 level skip.
	$review_box_heading = ! empty( $data['is_critique'] ) ? __( 'Ficha da crítica', 'go-verge' ) : __( 'Ficha de avaliação', 'go-verge' );
	echo '<h2 class="screen-reader-text">' . esc_html( $review_box_heading ) . '</h2>';

	$summary_text = $data['summary'];
	// When a review/critique has the cinematic featured-image masthead, the score
	// is already the strongest element in the hero. Do not repeat it immediately
	// below in the opening summary card. Posts without a featured image keep the
	// original score here as a graceful fallback.
	$show_opening_score = null !== $data['score'] && ! has_post_thumbnail( $post_id );
	// Never manufacture the opening summary from the final verdict. When the
	// editor leaves this field empty, the top card keeps only the available
	// technical information instead of repeating the closing copy.
	if ( $show_opening_score || $summary_text ) {
		echo '<div class="go-review-box__head">';
		if ( $show_opening_score ) {
			$score_label = go_verge_review_score_display( $data['score'] );
			printf(
				'<div class="go-review-box__score %1$s" aria-label="%3$s"><span class="go-review-box__score-num">%2$s</span><span class="go-review-box__score-max">/10</span></div>',
				esc_attr( go_verge_review_score_tier( $data['score'] ) ),
				esc_html( $score_label ),
				esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $score_label ) )
			);
		}
		if ( $summary_text ) {
			echo '<div class="go-review-box__head-text"><p class="go-review-box__verdict">' . esc_html( $summary_text ) . '</p></div>';
		}
		echo '</div>'; // .go-review-box__head
	}

	if ( $has_extra ) {
		$details_sections = array();
		if ( ! empty( $data['pros'] ) || ! empty( $data['cons'] ) ) {
			$details_sections[] = __( 'Prós e contras', 'go-verge' );
		}
		if ( ! empty( $specs ) ) {
			$details_sections[] = __( 'Ficha técnica', 'go-verge' );
		}
		if ( $data['metacritic'] || $data['opencritic'] ) {
			$details_sections[] = __( 'Notas externas', 'go-verge' );
		}
		$details_label = $details_sections ? implode( ' · ', $details_sections ) : __( 'Detalhes', 'go-verge' );
		echo '<details class="go-review-box__details" open>';
		echo '<summary class="go-review-box__details-summary">' . esc_html( $details_label ) . '</summary>';
		echo '<div class="go-review-box__details-body">';

		if ( $data['metacritic'] || $data['opencritic'] ) {
			echo '<div class="go-review-box__compare">';
			if ( $data['metacritic'] ) {
				printf( '<span class="go-tag">Metacritic %s</span>', esc_html( $data['metacritic'] ) );
			}
			if ( $data['opencritic'] ) {
				printf( '<span class="go-tag">OpenCritic %s</span>', esc_html( $data['opencritic'] ) );
			}
			echo '</div>';
		}

		if ( ! empty( $data['pros'] ) || ! empty( $data['cons'] ) ) {
			echo '<div class="go-review-box__proscons">';
			if ( ! empty( $data['pros'] ) ) {
				echo '<div class="go-review-box__pros"><h3>' . esc_html__( 'Prós', 'go-verge' ) . '</h3><ul>';
				foreach ( $data['pros'] as $line ) {
					echo '<li>' . esc_html( $line ) . '</li>';
				}
				echo '</ul></div>';
			}
			if ( ! empty( $data['cons'] ) ) {
				echo '<div class="go-review-box__cons"><h3>' . esc_html__( 'Contras', 'go-verge' ) . '</h3><ul>';
				foreach ( $data['cons'] as $line ) {
					echo '<li>' . esc_html( $line ) . '</li>';
				}
				echo '</ul></div>';
			}
			echo '</div>';
		}

		if ( ! empty( $specs ) ) {
			echo '<h3 class="go-review-box__specs-title">' . esc_html__( 'Ficha técnica', 'go-verge' ) . '</h3>';
			echo '<ul class="go-specs go-review-box__specs">';
			foreach ( $specs as $label => $value ) {
				printf(
					'<li><span class="k">%1$s</span><span class="v">%2$s</span></li>',
					esc_html( go_verge_upper( $label ) ),
					wp_kses_post( $value )
				);
			}
			echo '</ul>';
		}

		if ( $data['reviewer'] ) {
			printf(
				'<p class="go-review-box__by">%1$s <strong>%2$s</strong></p>',
				esc_html__( 'Análise por', 'go-verge' ),
				esc_html( $data['reviewer'] )
			);
		}

		echo '</div>';
		echo '</details>';
	}

	echo '</div>'; // .go-review-box
}

/**
 * Choose a strong verdict image. A manually selected attachment wins, followed
 * by the post's featured image, the linked game's cover and finally the best
 * large landscape attachment inside the article.
 */
function go_verge_review_recap_image_url( $post_id, $is_critique = false ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$manual_keys = $is_critique
		? array( 'go_critique_verdict_image_id', 'go_review_verdict_image_id', '_go_verdict_image_id' )
		: array( 'go_review_verdict_image_id', '_go_verdict_image_id' );
	foreach ( $manual_keys as $key ) {
		$image_id = absint( get_post_meta( $post_id, $key, true ) );
		if ( $image_id && wp_attachment_is_image( $image_id ) ) {
			$url = wp_get_attachment_image_url( $image_id, 'go_hero' );
			if ( $url ) {
				return (string) $url;
			}
		}
	}

	$featured_id = get_post_thumbnail_id( $post_id );
	if ( $featured_id ) {
		$url = wp_get_attachment_image_url( $featured_id, 'go_hero' );
		if ( $url ) {
			return (string) $url;
		}
	}

	if ( ! $is_critique && function_exists( 'go_verge_review_game_profile' ) ) {
		$game = go_verge_review_game_profile( $post_id );
		if ( ! empty( $game['id'] ) ) {
			$game_image_id = get_post_thumbnail_id( absint( $game['id'] ) );
			$url = $game_image_id ? wp_get_attachment_image_url( $game_image_id, 'go_hero' ) : '';
			if ( $url ) {
				return (string) $url;
			}
		}
	}

	$image_ids   = array();
	$walk_blocks = static function ( $blocks ) use ( &$walk_blocks, &$image_ids ) {
		foreach ( (array) $blocks as $block ) {
			if ( ! empty( $block['blockName'] ) && 'core/image' === $block['blockName'] && ! empty( $block['attrs']['id'] ) ) {
				$image_ids[] = absint( $block['attrs']['id'] );
			}
			if ( ! empty( $block['blockName'] ) && 'core/gallery' === $block['blockName'] && ! empty( $block['attrs']['ids'] ) ) {
				foreach ( (array) $block['attrs']['ids'] as $image_id ) {
					$image_ids[] = absint( $image_id );
				}
			}
			if ( ! empty( $block['innerBlocks'] ) ) {
				$walk_blocks( $block['innerBlocks'] );
			}
		}
	};
	$walk_blocks( parse_blocks( (string) get_post_field( 'post_content', $post_id ) ) );

	$best_id    = 0;
	$best_score = 0;
	foreach ( array_unique( array_filter( $image_ids ) ) as $image_id ) {
		$metadata = wp_get_attachment_metadata( $image_id );
		$width    = isset( $metadata['width'] ) ? absint( $metadata['width'] ) : 0;
		$height   = isset( $metadata['height'] ) ? absint( $metadata['height'] ) : 0;
		if ( $width < 900 || $height < 450 ) {
			continue;
		}
		$ratio = $height ? $width / $height : 0;
		if ( $ratio < 1.2 || $ratio > 2.6 ) {
			continue;
		}
		$score = $width * $height;
		if ( $ratio >= 1.45 && $ratio <= 2 ) {
			$score *= 1.35;
		}
		if ( $score > $best_score ) {
			$best_score = $score;
			$best_id    = $image_id;
		}
	}

	return $best_id ? (string) wp_get_attachment_image_url( $best_id, 'go_hero' ) : '';
}

/**
 * Transparency note shown below the closing verdict when the review used a
 * complimentary analysis code. The editor explicitly enables it in the review
 * fields, so older reviews are never labelled by inference.
 */
function go_verge_review_copy_disclosure_text( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || '1' !== (string) get_post_meta( $post_id, 'go_review_copy_provided', true ) ) {
		return '';
	}

	if ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) ) {
		return '';
	}

	$platform = trim( wp_strip_all_tags( (string) get_post_meta( $post_id, 'review_platform', true ) ) );
	$provider = trim( wp_strip_all_tags( (string) get_post_meta( $post_id, 'go_review_copy_provider', true ) ) );

	if ( '' === $provider ) {
		$provider = trim(
			wp_strip_all_tags(
				(string) go_verge_review_meta( $post_id, array( 'review_developer', 'review_publisher' ) )
			)
		);
	}

	if ( '' === $provider && function_exists( 'go_verge_review_game_profile' ) && function_exists( 'go_verge_game_data' ) ) {
		$profile = go_verge_review_game_profile( $post_id );
		if ( ! empty( $profile['id'] ) ) {
			$game_data = go_verge_game_data( absint( $profile['id'] ) );
			$provider  = trim( wp_strip_all_tags( (string) ( $game_data['developer'] ?? '' ) ) );
			if ( '' === $provider ) {
				$provider = trim( wp_strip_all_tags( (string) ( $game_data['publisher'] ?? '' ) ) );
			}
		}
	}

	if ( $platform && $provider ) {
		$text = sprintf(
			__( 'Análise realizada na versão para %1$s com código fornecido por %2$s.', 'go-verge' ),
			$platform,
			$provider
		);
	} elseif ( $platform ) {
		$text = sprintf(
			__( 'Análise realizada na versão para %s com código fornecido pela desenvolvedora ou publicadora.', 'go-verge' ),
			$platform
		);
	} elseif ( $provider ) {
		$text = sprintf(
			__( 'Análise realizada com código fornecido por %s.', 'go-verge' ),
			$provider
		);
	} else {
		$text = __( 'Análise realizada com código fornecido pela desenvolvedora ou publicadora.', 'go-verge' );
	}

	return apply_filters( 'go_verge_review_copy_disclosure_text', $text, $post_id );
}

/**
 * A closing verdict recap for the end of a review article — score + verdict
 * only (the full scorecard with pros/cons/specs already ran at the top).
 * No-ops when the post has no review data.
 */
function go_verge_review_recap( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( function_exists( 'go_verge_should_show_review_scores' ) && ! go_verge_should_show_review_scores( $post_id ) ) {
		return;
	}
	$data = go_verge_review_data( $post_id );
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$verdict_text = $data['verdict'];
	if ( $is_critique && go_verge_review_copy_is_duplicate( $verdict_text, $data['summary'] ) ) {
		$verdict_text = '';
	}

	// A critique without an explicit, distinct final verdict does not receive a
	// second recap card. This keeps old migrated posts from repeating the same
	// paragraph at the beginning and end of the article.
	if ( ! $data['has_review'] || ( $is_critique && ! $verdict_text ) || ( null === $data['score'] && ! $verdict_text ) ) {
		return;
	}

	$recap_image = go_verge_review_recap_image_url( $post_id, $is_critique );
	$recap_style = $recap_image ? '--go-review-recap-image:url(' . esc_url( $recap_image ) . ');' : '';
	echo '<aside class="go-review-recap ' . ( $is_critique ? 'go-review-recap--critique' : 'go-review-recap--review' ) . ( $recap_image ? ' go-review-recap--has-image' : '' ) . '" aria-labelledby="go-review-verdict-title"' . ( $recap_style ? ' style="' . esc_attr( $recap_style ) . '"' : '' ) . '>';
	echo '<header class="go-review-recap__head"><h2 id="go-review-verdict-title" class="go-review-recap__title">' . esc_html__( 'Veredito', 'go-verge' ) . '</h2></header>';
	echo '<div class="go-review-recap__row">';
	if ( null !== $data['score'] ) {
		$score_label = function_exists( 'go_verge_review_score_display' ) ? go_verge_review_score_display( $data['score'] ) : rtrim( rtrim( number_format( (float) $data['score'], 1, '.', '' ), '0' ), '.' );
		printf(
			'<div class="go-review-box__score go-review-recap__score %1$s" aria-label="%3$s"><span class="go-review-box__score-num">%2$s</span><span class="go-review-box__score-max">/10</span></div>',
			esc_attr( go_verge_review_score_tier( $data['score'] ) ),
			esc_html( $score_label ),
			esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $score_label ) )
		);
	}
	if ( $verdict_text ) {
		echo '<div class="go-review-recap__copy"><p class="go-review-box__verdict">' . esc_html( $verdict_text ) . '</p></div>';
	}
	echo '</div>';

	$copy_disclosure = go_verge_review_copy_disclosure_text( $post_id );
	if ( $copy_disclosure ) {
		echo '<p class="go-review-recap__disclosure">' . esc_html( $copy_disclosure ) . '</p>';
	}

	echo '</aside>';
}

/**
 * The post's subtitle / editorial support line — a distinct field from the
 * excerpt when the editorial workflow filled one in (_go_post_subtitle),
 * falling back to the excerpt otherwise.
 */
function go_verge_subtitle( $post_id = null ) {
	return go_verge_support_text( $post_id );
}


/**
 * Additional reviews by the same writer, inspired by editorial review hubs.
 */
function go_verge_author_review_posts( $post_id, $limit = 3, &$strict_author = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$author  = (int) get_post_field( 'post_author', $post_id );
	$strict_author = true;
	if ( ! $post_id || ! $author ) {
		return array();
	}

	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 200,
			'author'              => $author,
			'post__not_in'        => array( $post_id ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'orderby'             => 'date',
			'order'               => 'DESC',
		)
	);

	$items = array();
	foreach ( (array) $query->posts as $candidate ) {
		if ( function_exists( 'go_verge_is_review_post' ) && ! go_verge_is_review_post( $candidate->ID ) ) {
			continue;
		}
		$items[] = $candidate;
		if ( count( $items ) >= $limit ) {
			break;
		}
	}
	return $items;
}

function go_verge_render_more_reviews_by_author( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$is_review = function_exists( 'go_verge_is_review_post' ) ? go_verge_is_review_post( $post_id ) : ! empty( go_verge_review_data( $post_id )['has_review'] );
	if ( ! $is_review ) {
		return;
	}

	$strict_author = true;
	$items = go_verge_author_review_posts( $post_id, 8, $strict_author );
	$used = function_exists( 'go_verge_recirculation_shown_ids' )
		? (array) go_verge_recirculation_shown_ids()
		: ( function_exists( 'go_verge_sidebar_shown_ids' ) ? (array) go_verge_sidebar_shown_ids() : array() );
	$items = array_values( array_filter( (array) $items, static function ( $item ) use ( $used ) {
		return $item instanceof WP_Post && ! in_array( (int) $item->ID, array_map( 'absint', $used ), true );
	} ) );
	$items = array_slice( $items, 0, 3 );
	if ( empty( $items ) ) {
		return;
	}
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( array_merge( $used, wp_list_pluck( $items, 'ID' ) ) );
	}

	$author_id   = (int) get_post_field( 'post_author', $post_id );
	$author_name = get_the_author_meta( 'display_name', $author_id );
	$author_url  = get_author_posts_url( $author_id );
	?>
	<section class="go-more-reviews" aria-labelledby="go-more-reviews-title">
		<div class="go-more-reviews__head">
			<div class="go-more-reviews__author">
				<div class="go-more-reviews__author-copy">
					<h2 id="go-more-reviews-title"><?php echo esc_html( sprintf( __( 'Mais reviews de %s', 'go-verge' ), $author_name ) ); ?></h2>
				</div>
			</div>
			<?php if ( $author_url ) : ?><a class="go-more-reviews__all" href="<?php echo esc_url( $author_url ); ?>"><?php esc_html_e( 'Ver publicações', 'go-verge' ); ?></a><?php endif; ?>
		</div>
		<div class="go-more-reviews__grid">
			<?php foreach ( $items as $item ) : ?>
				<a class="go-more-reviews__item" href="<?php echo esc_url( get_permalink( $item->ID ) ); ?>">
					<span class="go-more-reviews__media"><?php echo get_the_post_thumbnail( $item->ID, 'go_card', array( 'loading' => 'lazy', 'alt' => '' ) ); ?></span>
					<span class="go-more-reviews__copy">
						<strong class="go-more-reviews__item-title"><?php echo esc_html( get_the_title( $item->ID ) ); ?></strong>
						<span class="go-more-reviews__meta"><?php echo go_verge_time_html( $item->ID ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span>
					</span>
				</a>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
}

/**
 * Game coverage block for stories linked to a game profile with a meaningful
 * amount of coverage. This stays hidden on light-coverage topics.
 */
function go_verge_render_game_content_cluster( $post_id = null ) {
	$post_id  = $post_id ? absint( $post_id ) : get_the_ID();
	$game_id  = function_exists( 'go_verge_product_linked_game_id' ) ? go_verge_product_linked_game_id( $post_id ) : 0;
	$game_ref = $game_id ? null : go_verge_review_game_profile( $post_id );
	if ( ! $game_id && ! empty( $game_ref['id'] ) ) {
		$game_id = absint( $game_ref['id'] );
	}
	if ( ! $game_id ) {
		return;
	}

	/*
	 * V64 deduplication: when the subject-specific "Continue neste assunto"
	 * module already represents this exact game, a second "Mais de [game]" rail
	 * immediately underneath is the same navigation intent twice. Suppress the
	 * duplicate module and let the broader recirculation rail provide discovery.
	 */
	if ( function_exists( 'go_verge_contextual_next_rendered' ) && go_verge_contextual_next_rendered( $post_id ) && function_exists( 'go_verge_v17_cluster_subject' ) ) {
		$subject = go_verge_v17_cluster_subject( $post_id );
		if ( is_array( $subject ) && 'games' === (string) ( $subject['type'] ?? '' ) && absint( $subject['id'] ?? 0 ) === $game_id ) {
			return;
		}
	}

	$used = function_exists( 'go_verge_recirculation_shown_ids' )
		? (array) go_verge_recirculation_shown_ids()
		: ( function_exists( 'go_verge_sidebar_shown_ids' ) ? (array) go_verge_sidebar_shown_ids() : array() );

	$all_ids = function_exists( 'go_verge_product_related_post_ids' )
		? go_verge_product_related_post_ids( $game_id, 'games', 18, array( 'exclude' => array_values( array_unique( array_merge( array( $post_id ), array_map( 'absint', $used ) ) ) ) ) )
		: array();
	if ( count( $all_ids ) < 6 ) {
		return;
	}

	$display_ids = array_slice( $all_ids, 0, 5 );
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( array_merge( $used, $display_ids ) );
	}
	$game_title  = get_the_title( $game_id );
	$game_url    = get_permalink( $game_id );
	?>
	<section class="go-game-collection" aria-labelledby="go-game-collection-title">
		<div class="go-game-collection__head">
			<div class="go-game-collection__intro">
				<h2 id="go-game-collection-title"><?php echo esc_html( sprintf( __( 'Mais de %s', 'go-verge' ), $game_title ) ); ?></h2>
			</div>
			<?php if ( $game_url ) : ?><a class="go-game-collection__all" href="<?php echo esc_url( $game_url ); ?>"><?php esc_html_e( 'Ver tudo', 'go-verge' ); ?></a><?php endif; ?>
		</div>
		<div class="go-game-collection__track" role="list">
			<?php foreach ( $display_ids as $related_id ) : ?>
				<article class="go-game-collection__card" role="listitem">
					<a class="go-game-collection__media" href="<?php echo esc_url( get_permalink( $related_id ) ); ?>">
						<?php echo get_the_post_thumbnail( $related_id, 'go_square', array( 'loading' => 'lazy', 'alt' => '' ) ); ?>
					</a>
					<div class="go-game-collection__body">
						<h3><a href="<?php echo esc_url( get_permalink( $related_id ) ); ?>"><?php echo esc_html( get_the_title( $related_id ) ); ?></a></h3>
					</div>
				</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
}
