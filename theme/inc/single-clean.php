<?php
/**
 * Clean single-post presentation contract.
 *
 * This module owns only the standard post single. It deliberately keeps data,
 * editorial helpers and SEO systems where they already live, while exposing one
 * predictable context object to one template and one stylesheet.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Story-type modifiers of a standard single.
 *
 * These used to sit on the <article>. They now live on <body>, outside the
 * ancestor chain of the prose, so the article element is identical on every
 * story (see template-parts/single/article.php). The stylesheets address them
 * as `.od-article:where(body.<modifier> *)`, which targets the same element with
 * the same specificity as the former `.<modifier>` on the article.
 *
 * @param int $post_id Post ID.
 * @return string[]
 */
function go_verge_single_clean_type_classes( $post_id ) {
	$post_id     = absint( $post_id );
	$is_guide    = function_exists( 'go_verge_is_guide_post' ) && go_verge_is_guide_post( $post_id );
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$is_review   = ! $is_critique && ( function_exists( 'go_verge_is_review_post' )
		? go_verge_is_review_post( $post_id )
		: ! empty( ( function_exists( 'go_verge_review_data' ) ? go_verge_review_data( $post_id ) : array() )['has_review'] ) );
	$is_special  = function_exists( 'go_verge_post_is_special' ) && go_verge_post_is_special( $post_id );
	$is_ranking  = function_exists( 'go_verge_post_is_ranking' ) && go_verge_post_is_ranking( $post_id );
	$is_list     = ! $is_ranking && function_exists( 'go_verge_post_is_list' ) && go_verge_post_is_list( $post_id );
	$has_hero    = has_post_thumbnail( $post_id ) && (bool) get_the_post_thumbnail_url( $post_id, 'full' );

	$classes = array();
	if ( $is_guide ) {
		$classes[] = 'go-single--guide';
	} elseif ( $is_review ) {
		$classes[] = 'go-single--scored';
		$classes[] = 'go-single--review';
	} elseif ( $is_critique ) {
		$classes[] = 'go-single--scored';
		$classes[] = 'go-single--critique';
	} elseif ( $is_special ) {
		$classes[] = 'go-single--special';
	} elseif ( $is_ranking ) {
		$classes[] = 'go-single--ranking';
	} elseif ( $is_list ) {
		$classes[] = 'go-single--list';
	}
	if ( $is_review || $is_critique ) {
		$classes[] = 'go-article--scored';
		$classes[] = $is_critique ? 'go-article--critique' : 'go-article--review';
		$classes[] = 'od-review-page';
		if ( ! $has_hero ) {
			$classes[] = 'od-article--premium';
		}
	}
	return $classes;
}

/**
 * Add a stable marker for the rebuilt single runtime and the story type.
 *
 * @param string[] $classes Body classes.
 * @return string[]
 */
function go_verge_single_clean_body_class( $classes ) {
	if ( is_singular( 'post' ) ) {
		$classes[] = 'go-single-clean';
		$classes   = array_merge( $classes, go_verge_single_clean_type_classes( get_queried_object_id() ) );
	}
	return array_values( array_unique( $classes ) );
}
add_filter( 'body_class', 'go_verge_single_clean_body_class', 20 );


/**
 * Remove pasted escaped-newline artifacts from the very start of an article.
 *
 * Some legacy/editorial pastes contain the literal characters "\\n\\n\\n"
 * (or "/n/n/n") before the first real block. WordPress correctly treats those
 * characters as text, which makes them visible above the article. This filter
 * is deliberately anchored to byte zero and never touches code/pre blocks or
 * occurrences inside the actual story.
 *
 * @param string $content Raw post content entering the_content.
 * @return string
 */
function go_verge_single_clean_strip_leading_newline_artifacts( $content ) {
	if ( is_admin() || ! is_singular( 'post' ) || ! is_string( $content ) || '' === $content ) {
		return $content;
	}

	$original = $content;
	$token    = '(?:\\\\n|\/n|&#0*92;\s*n|&bsol;\s*n)';
	$patterns = array(
		'/^\x{FEFF}/u',
		/* Possessive spacing cannot be redivided between adjacent repetitions. */
		'/\A(?:\s*+' . $token . ')++\s*+/iu',
		/* Standalone artifact/blank paragraphs only; ordinary prose remains intact. */
		'/\A(?:\s*+<p\b[^>]*+>(?:' . $token . '|&nbsp;|<br\s*+\/?\s*+>|\s)++<\/p>\s*+)++/iu',
	);
	foreach ( $patterns as $pattern ) {
		$filtered = preg_replace( $pattern, '', $content );
		/* PCRE can fail on a large paste or invalid UTF-8. A cosmetic cleanup
		 * must never turn that failure into an empty editorial document. */
		if ( ! is_string( $filtered ) ) {
			return $original;
		}
		$content = $filtered;
	}
	return $content;
}
add_filter( 'the_content', 'go_verge_single_clean_strip_leading_newline_artifacts', 7 );

/**
 * Normalize literal escaped-newline artifacts in short presentation strings.
 *
 * This is intentionally used only for the single-post title/deck context. It
 * converts pasted "\\n" or "/n" tokens to spaces without touching real line
 * breaks in post content.
 *
 * @param string $value Presentation text.
 * @return string
 */
function go_verge_single_clean_inline_text( $value ) {
	$value = (string) $value;
	if ( '' === $value ) {
		return '';
	}

	$value = preg_replace( '/(?:\\\\n|\/n|&#0*92;\s*n|&bsol;\s*n)+/iu', ' ', $value );
	$value = preg_replace( '/\s+/u', ' ', (string) $value );

	return trim( (string) $value );
}


/**
 * Annotate authored FAQ blocks before the document reaches the browser.
 *
 * The legacy presentation converted FAQ headings with JavaScript after parse.
 * The clean single keeps the original H2/H3/P nodes exactly where WordPress
 * rendered them and only adds CSS classes server-side. No node is moved,
 * wrapped, cloned or removed, so the article tree stays stable for Auto Ads.
 *
 * @param string $html Filtered article HTML.
 * @return string
 */
function go_verge_single_clean_format_faq( $html ) {
	$html = (string) $html;
	if ( '' === trim( $html ) ) {
		return $html;
	}

	$pattern = function_exists( 'go_verge_faq_heading_pattern' )
		? (string) go_verge_faq_heading_pattern()
		: 'perguntas?\\s+(?:mais\\s+)?frequentes?|perguntas?\\s+r[áa]pidas?|perguntas?\\s+e\\s+respostas|d[úu]vidas?\\s+(?:comuns|comum)|faq';
	if ( '' === $pattern || ! preg_match( '/(?:' . $pattern . ')/iu', wp_strip_all_tags( $html ) ) ) {
		return $html;
	}

	$add_class = static function ( $opening_tag, $class ) {
		if ( preg_match( '/\\bclass=("|\\\')(.*?)\\1/isu', $opening_tag, $match ) ) {
			$classes = preg_split( '/\\s+/', trim( $match[2] ) );
			$classes = array_values( array_filter( (array) $classes ) );
			if ( ! in_array( $class, $classes, true ) ) {
				$classes[] = $class;
			}
			$replacement = 'class=' . $match[1] . implode( ' ', $classes ) . $match[1];
			return preg_replace( '/\\bclass=("|\\\')(.*?)\\1/isu', $replacement, $opening_tag, 1 );
		}
		return preg_replace( '/>$/', ' class="' . $class . '">', $opening_tag, 1 );
	};

	$heading_regex = '#<h2\\b[^>]*>\\s*(?:<[^>]+>\\s*)*(?:' . $pattern . ')(?:(?:\\s+sobre\\b|\\s*[:—–-]\\s*)[^<]*)?\\s*</h2>#iu';
	if ( ! preg_match( $heading_regex, $html, $heading_match, PREG_OFFSET_CAPTURE ) ) {
		return $html;
	}

	$faq_heading = (string) $heading_match[0][0];
	$faq_offset  = (int) $heading_match[0][1];
	$faq_end     = $faq_offset + strlen( $faq_heading );
	$faq_heading = preg_replace_callback(
		'/^<h2\\b[^>]*>/iu',
		static function ( $m ) use ( $add_class ) {
			return $add_class( $m[0], 'go-faq-heading' );
		},
		$faq_heading,
		1
	);

	$after = substr( $html, $faq_end );
	$next_h2_offset = null;
	if ( preg_match( '/<h2\\b/iu', $after, $next_h2, PREG_OFFSET_CAPTURE ) ) {
		$next_h2_offset = (int) $next_h2[0][1];
	}
	$faq_body = null === $next_h2_offset ? $after : substr( $after, 0, $next_h2_offset );
	$suffix   = null === $next_h2_offset ? '' : substr( $after, $next_h2_offset );

	/* The editorial FAQ contract is H3/H4 question + authored paragraph answer.
	 * Add classes only; keep the original tags, IDs, text and sibling order. */
	$faq_body = preg_replace_callback(
		'#(<h([3-6])\\b[^>]*>.*?</h\\2>)(\\s*)(<p\\b[^>]*>.*?</p>)#isu',
		static function ( $m ) use ( $add_class ) {
			$question = preg_replace_callback(
				'/^<h[3-6]\\b[^>]*>/iu',
				static function ( $open ) use ( $add_class ) {
					return $add_class( $open[0], 'go-faq-question' );
				},
				$m[1],
				1
			);
			$answer = preg_replace_callback(
				'/^<p\\b[^>]*>/iu',
				static function ( $open ) use ( $add_class ) {
					return $add_class( $open[0], 'go-faq-answer' );
				},
				$m[4],
				1
			);
			return $question . $m[3] . $answer;
		},
		$faq_body
	);

	return substr( $html, 0, $faq_offset ) . $faq_heading . $faq_body . $suffix;
}

/**
 * Build all presentation data for the standard single in one place.
 *
 * The returned content is still the normal WordPress `the_content` result from
 * go_verge_content_with_toc(); no mobile/desktop copy is created.
 *
 * @param int $post_id Post ID.
 * @return array<string,mixed>
 */
function go_verge_single_clean_context( $post_id ) {
	$post_id = absint( $post_id );

	$deck             = go_verge_single_clean_inline_text( go_verge_subtitle( $post_id ) );
	$title            = go_verge_single_clean_inline_text( get_the_title( $post_id ) );
	$permalink        = get_permalink( $post_id );
	$share_title      = rawurlencode( $title );
	$share_url        = rawurlencode( $permalink );
	$body             = go_verge_content_with_toc( $post_id );
	$has_hero         = has_post_thumbnail( $post_id ) && (bool) get_the_post_thumbnail_url( $post_id, 'full' );
	$featured_id      = get_post_thumbnail_id( $post_id );
	$hero_alt         = $featured_id ? trim( (string) get_post_meta( $featured_id, '_wp_attachment_image_alt', true ) ) : '';
	$hero_caption     = '';
	if ( $featured_id ) {
		$stored_caption = trim( (string) wp_get_attachment_caption( $featured_id ) );
		if ( function_exists( 'go_verge_image_split_caption_credit' ) && function_exists( 'go_verge_image_credit' ) && function_exists( 'go_verge_image_format_caption' ) ) {
			$caption_parts = go_verge_image_split_caption_credit( $stored_caption );
			$credit_info   = go_verge_image_credit( $featured_id );
			$caption_body  = isset( $caption_parts['text'] ) ? trim( (string) $caption_parts['text'] ) : '';
			$credit_text   = isset( $credit_info['text'] ) ? trim( (string) $credit_info['text'] ) : '';
			if ( '' !== $caption_body || '' !== $credit_text ) {
				$hero_caption = go_verge_image_format_caption( $caption_body, $credit_text );
			}
		} else {
			$hero_caption = $stored_caption;
		}
	}
	$hero_image       = go_verge_single_hero_image( $post_id );
	$hero_size        = $hero_image ? $hero_image['size'] : 'go_discover_16x9';
	$hero_sizes       = $hero_image ? $hero_image['sizes'] : '(max-width: 767px) calc(100vw - 32px), (max-width: 1100px) calc(100vw - 40px), 856px';
	$hero_srcset      = ( $featured_id && function_exists( 'go_verge_discover_ready_srcset' ) )
		? go_verge_discover_ready_srcset( $featured_id, $hero_size )
		: '';
	$review_data      = function_exists( 'go_verge_review_data' ) ? go_verge_review_data( $post_id ) : array();
	$is_guide         = function_exists( 'go_verge_is_guide_post' ) && go_verge_is_guide_post( $post_id );
	$guide_game_id    = $is_guide && function_exists( 'go_verge_product_linked_game_id' ) ? go_verge_product_linked_game_id( $post_id ) : 0;
	$is_critique      = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$is_review        = ! $is_critique && ( function_exists( 'go_verge_is_review_post' )
		? go_verge_is_review_post( $post_id )
		: ! empty( $review_data['has_review'] ) );
	$is_special       = function_exists( 'go_verge_post_is_special' ) && go_verge_post_is_special( $post_id );
	$is_ranking       = function_exists( 'go_verge_post_is_ranking' ) && go_verge_post_is_ranking( $post_id );
	$is_list          = ! $is_ranking && function_exists( 'go_verge_post_is_list' ) && go_verge_post_is_list( $post_id );
	$is_scored        = $is_review || $is_critique;
	$score            = isset( $review_data['score'] ) && null !== $review_data['score'] ? (float) $review_data['score'] : null;
	$score_label      = null !== $score && function_exists( 'go_verge_review_score_display' )
		? go_verge_review_score_display( $score )
		: ( null !== $score ? rtrim( rtrim( number_format( $score, 1, '.', '' ), '0' ), '.' ) : '' );
	$use_scored       = false; // Legacy cinematic masthead retired; premium opening is server-rendered.
	$review_game_name = ! empty( $review_data['game_name'] ) ? (string) $review_data['game_name'] : '';
	$work_name        = ! empty( $review_data['work_name'] ) ? (string) $review_data['work_name'] : '';

	if ( '' === $hero_alt ) {
		$hero_alt = wp_strip_all_tags( $title );
	}

	/* Preserve the existing editorial pipeline, but run it exactly once. */
	$body['content'] = go_verge_upgrade_legacy_read_also( $body['content'], $post_id );
	if ( function_exists( 'go_verge_intelligent_internal_links' ) ) {
		$body['content'] = go_verge_intelligent_internal_links( $body['content'], $post_id );
	}
	$body['content'] = go_verge_inject_mid_content_cta( $body['content'], $post_id );
	$body['content'] = go_verge_inject_inline_related( $body['content'], $post_id );
	if ( function_exists( 'go_verge_upgrade_spoiler_warnings' ) ) {
		$body['content'] = go_verge_upgrade_spoiler_warnings( $body['content'] );
	}
	if ( $is_ranking && function_exists( 'go_verge_enhance_ranking_headings' ) ) {
		$body['content'] = go_verge_enhance_ranking_headings( $body['content'] );
	}
	$body['content'] = go_verge_single_clean_format_faq( $body['content'] );
	/* Revenue planning must see the final editorial DOM, including CTA, related,
	 * spoiler, ranking and FAQ transforms. */
	if ( function_exists( 'go_verge_ads_compose_article_inventory' ) ) {
		$body['content'] = go_verge_ads_compose_article_inventory( $body['content'] );
	}
	/* Clever's 300x250 goes into the finished plan, never into the planner's input:
	 * the AdSense ladder is decided before this host exists. */
	if ( function_exists( 'go_verge_clever_compose_article' ) ) {
		$body['content'] = go_verge_clever_compose_article( $body['content'] );
	}

	ob_start();
	go_verge_breadcrumbs(
		array(
			'include_current' => false,
			'compact_single'  => true,
			'preserve_case'   => true,
		)
	);
	$breadcrumbs = trim( (string) ob_get_clean() );

	$hero_ad = ( $has_hero && function_exists( 'go_verge_adsense_unit_markup' ) )
		? go_verge_adsense_unit_markup(
			'article-hero-overlay',
			array(
				'tag'         => 'aside',
				'class'       => 'go-single__hero-ad',
				'prime'       => true,
				'dismissible' => false,
				'data'        => array( 'ad-surface' => 'article-hero' ),
			)
		)
		: '';

	$classes = array( 'go-single' );
	if ( $is_guide ) {
		$classes[] = 'go-single--guide';
	} elseif ( $is_review ) {
		$classes[] = 'go-single--scored';
		$classes[] = 'go-single--review';
	} elseif ( $is_critique ) {
		$classes[] = 'go-single--scored';
		$classes[] = 'go-single--critique';
	} elseif ( $is_special ) {
		$classes[] = 'go-single--special';
	} elseif ( $is_ranking ) {
		$classes[] = 'go-single--ranking';
	} elseif ( $is_list ) {
		$classes[] = 'go-single--list';
	}

	$topics = function_exists( 'go_verge_v7_story_topic_chips' ) ? go_verge_v7_story_topic_chips( $post_id, 5 ) : array();
	if ( ( $is_list || $is_ranking ) && function_exists( 'go_verge_v48_merge_list_ranking_topics' ) ) {
		$topics = go_verge_v48_merge_list_ranking_topics( $post_id, $topics, 6 );
	}

	$follow = array();
	if ( function_exists( 'go_verge_product_follow_button' ) ) {
		$follow_game = function_exists( 'go_verge_product_linked_game_id' ) ? go_verge_product_linked_game_id( $post_id ) : 0;
		$follow_ref  = function_exists( 'go_verge_product_subject_reference' ) ? go_verge_product_subject_reference( $post_id ) : '';
		if ( $follow_game ) {
			$follow = array( 'id' => (int) $follow_game, 'type' => 'games' );
		} elseif ( preg_match( '/^go_entity:(\d+)$/', $follow_ref, $match ) ) {
			$follow = array( 'id' => (int) $match[1], 'type' => 'go_entity' );
		}
	}

	return array(
		'post_id'             => $post_id,
		'title'               => $title,
		'deck'                => $deck,
		'permalink'           => $permalink,
		'share_title_encoded' => $share_title,
		'share_url_encoded'   => $share_url,
		'body'                => $body,
		'has_hero'            => $has_hero,
		'hero_alt'            => $hero_alt,
		'hero_caption'        => $hero_caption,
		'hero_size'           => $hero_size,
		'hero_sizes'          => $hero_sizes,
		'hero_srcset'         => $hero_srcset,
		'hero_ad'             => $hero_ad,
		'classes'             => $classes,
		'breadcrumbs'         => $breadcrumbs,
		'reading_minutes'     => go_verge_reading_time( $post_id ),
		'review_data'         => $review_data,
		'is_guide'            => $is_guide,
		'guide_game_id'       => $guide_game_id,
		'is_review'           => $is_review,
		'is_critique'         => $is_critique,
		'is_special'          => $is_special,
		'is_ranking'          => $is_ranking,
		'is_list'             => $is_list,
		'is_scored'           => $is_scored,
		'use_scored_masthead' => $use_scored,
		'score_label'         => $score_label,
		'review_game_name'    => $review_game_name,
		'work_name'           => $work_name,
		'topics'              => $topics,
		'follow'              => $follow,
	);
}

/**
 * Single presentation asset contract.
 *
 * One readable source stylesheet is intentionally used. inc/asset-bundle.php
 * compacts queued CSS for delivery, so a second handwritten/minified sibling
 * would only create source drift.
 */
function go_verge_enqueue_single_clean_assets() {
	if ( is_admin() || ! is_singular( 'post' ) ) {
		return;
	}

	/* This script already exits on single-post; do not download dead runtime. */
	wp_dequeue_script( 'go-verge-viewport-stability' );
	wp_deregister_script( 'go-verge-viewport-stability' );

	$rel = '/assets/css/single-clean.css';
	wp_enqueue_style(
		'go-verge-single-clean',
		GO_VERGE_URI . $rel,
		array( 'go-verge-multicolor' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_single_clean_assets', 46980 );

/** Premium editorial presentation follows the shared publisher components. */
function go_verge_enqueue_article_premium() {
	if ( is_admin() || ! is_singular( 'post' ) ) { return; }
	if ( function_exists( 'go_verge_specials_is_current' ) && go_verge_specials_is_current() ) { return; }
	$rel = '/assets/css/article-premium.css';
	wp_enqueue_style( 'go-verge-article-premium', GO_VERGE_URI . $rel, array( 'go-verge-single-clean', 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_article_premium', 48200 );

/** Final article-reading layer: one visual system for standard text pages. */
function go_verge_enqueue_article_reading() {
	if ( is_admin() || ! is_singular( 'post' ) ) { return; }
	if ( function_exists( 'go_verge_specials_is_current' ) && go_verge_specials_is_current() ) { return; }
	$rel = '/assets/css/article-reading.css';
	wp_enqueue_style( 'go-verge-article-reading', GO_VERGE_URI . $rel, array( 'go-verge-article-premium' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_article_reading', 48250 );

/** Review/critique reading layer: isolated from normal articles. */
function go_verge_enqueue_review_reading() {
	if ( is_admin() || ! is_singular( 'post' ) ) { return; }
	$post_id = absint( get_queried_object_id() );
	if ( ! $post_id ) { return; }
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$is_review   = ! $is_critique && function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id );
	if ( ! $is_critique && ! $is_review ) { return; }
	$rel = '/assets/css/review-reading.css';
	wp_enqueue_style( 'go-verge-review-reading', GO_VERGE_URI . $rel, array( 'go-verge-article-reading' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_review_reading', 48300 );
