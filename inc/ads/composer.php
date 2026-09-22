<?php
/**
 * Revenue placement composer.
 *
 * The planner owns structure; this composer only turns approved opportunities
 * into provider markup, and hands listing surfaces their units from one ordered
 * pool. It never refreshes, retries an empty unit, selects a creative or
 * changes the AdSense auction.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * The editorial format of the post being rendered.
 *
 * The theme already classifies every story for layout purposes; the planner
 * simply reads the same answer. Format is a reading-behaviour signal: a guide
 * or ranking is consumed in sections and reaches its tail far more often than a
 * news story of identical length, so its deeper opportunities are real rather
 * than theoretical.
 *
 * @param int $post_id Optional post id; defaults to the current post.
 * @return string guide|review|critique|ranking|list|special|news
 */
function go_verge_ads_article_type( $post_id = 0 ) {
	$post_id = absint( $post_id );
	if ( ! $post_id && function_exists( 'get_the_ID' ) ) {
		$post_id = (int) get_the_ID();
	}
	if ( ! $post_id ) {
		return 'news';
	}
	static $cache = array();
	if ( isset( $cache[ $post_id ] ) ) {
		return $cache[ $post_id ];
	}

	$type = 'news';
	if ( function_exists( 'go_verge_is_guide_post' ) && go_verge_is_guide_post( $post_id ) ) {
		$type = 'guide';
	} elseif ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) ) {
		$type = 'critique';
	} elseif ( function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id ) ) {
		$type = 'review';
	} elseif ( function_exists( 'go_verge_post_is_ranking' ) && go_verge_post_is_ranking( $post_id ) ) {
		$type = 'ranking';
	} elseif ( function_exists( 'go_verge_post_is_list' ) && go_verge_post_is_list( $post_id ) ) {
		$type = 'list';
	} elseif ( function_exists( 'go_verge_post_is_special' ) && go_verge_post_is_special( $post_id ) ) {
		$type = 'special';
	}

	$cache[ $post_id ] = (string) apply_filters( 'go_verge_ads_article_type', $type, $post_id );
	return $cache[ $post_id ];
}

/**
 * Insert Prime P1 + A1..A6 into the final, fully transformed article HTML.
 *
 * Important: this function is called explicitly by single-clean.php after CTA,
 * related, spoiler, ranking and FAQ transforms. It is deliberately NOT a
 * the_content filter, so the planner sees the same DOM the reader will see.
 *
 * @param string $content Final article HTML.
 * @return string
 */
function go_verge_ads_compose_article_inventory( $content ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return $content; }
	if ( ! is_string( $content ) || '' === trim( $content ) ) {
		return $content;
	}
	if ( ! is_singular( 'post' ) ) {
		return $content;
	}
	if ( ! function_exists( 'go_verge_ads_is_monetizable_request' ) || ! go_verge_ads_is_monetizable_request() ) {
		return $content;
	}
	if ( preg_match( '/\bdata-go-ad-placement\s*=\s*(?:["\'](?:article-prime|article-a[1-6])["\']|(?:article-prime|article-a[1-6])(?=\s|>))/i', $content ) ) {
		return $content;
	}
	if ( ! function_exists( 'go_verge_ads_plan_article' ) ) {
		return $content;
	}

	$plan = go_verge_ads_plan_article( $content, go_verge_ads_article_type() );
	$selected = isset( $plan['selected'] ) && is_array( $plan['selected'] ) ? $plan['selected'] : array();
	if ( ! empty( $plan['prime'] ) && is_array( $plan['prime'] ) ) {
		$selected[] = $plan['prime'];
	}
	if ( ! empty( $plan['reserves'] ) && is_array( $plan['reserves'] ) ) {
		foreach ( $plan['reserves'] as $reserve ) {
			if ( is_array( $reserve ) ) {
				$selected[] = $reserve;
			}
		}
	}
	$metrics = isset( $plan['metrics'] ) && is_array( $plan['metrics'] ) ? $plan['metrics'] : array();
	$profile = isset( $plan['profile'] ) ? sanitize_key( (string) $plan['profile'] ) : 'standard_editorial';

	/*
	 * Production observability. 3.90 could explain the units that existed in the
	 * DOM, but not how many opportunities the planner discarded before the
	 * browser ever saw them. That made a 5.3-5.8 imp/PV production ceiling look
	 * like a runtime problem even when the loss was structural. Expose only
	 * harmless counts/labels on the publisher-owned article root; no revenue,
	 * account or auction data is emitted.
	 */
	$eligible_candidates = 0;
	foreach ( (array) ( $plan['candidates'] ?? array() ) as $candidate_log ) {
		if ( empty( $candidate_log['reasons'] ) ) {
			$eligible_candidates++;
		}
	}
	$GLOBALS['go_verge_ads_article_plan_public'] = array(
		'body-words'          => absint( $metrics['bodyWords'] ?? 0 ),
		'estimated-height'    => absint( $metrics['estimatedHeight'] ?? 0 ),
		'eligible-candidates' => absint( $eligible_candidates ),
		/* The STANDARD budget: what an ordinary engaged session may request. */
		'planned-body'        => absint( $plan['plannedCount'] ?? 0 ),
		/* Every host in the DOM, planned plus reserves. */
		'rendered-body'       => absint( $plan['renderedCount'] ?? ( $plan['plannedCount'] ?? 0 ) ),
		'reserve-body'        => absint( $plan['reserveCount'] ?? 0 ),
		'ladder-capacity'     => absint( $plan['ladderCapacity'] ?? 0 ),
		'headroom'            => absint( $plan['headroom'] ?? 0 ),
		/* The EXPANSION ceiling: what a reader who proves depth may reach. */
		'body-capacity'       => absint( $plan['totalCapacity'] ?? 0 ),
		'planner-version'     => sanitize_text_field( (string) ( $plan['version'] ?? '' ) ),
		'profile'             => $profile,
		'article-type'        => sanitize_key( (string) ( $plan['articleType'] ?? '' ) ),
	);

	/* Claim identities in reading order. The later string insertion still runs
	 * backwards, but a deeper candidate must not steal an earlier unit's ID. */
	usort(
		$selected,
		static function ( $a, $b ) {
			return absint( $a['position'] ?? 0 ) <=> absint( $b['position'] ?? 0 );
		}
	);

	$rendered = array();
	$render_rejections = array();
	$emitted_primary = 0;
	$emitted_reserves = 0;
	foreach ( $selected as $candidate ) {
		$placement = sanitize_key( (string) ( $candidate['placement'] ?? '' ) );
		$position  = absint( $candidate['position'] ?? 0 );
		if ( ! preg_match( '/^(?:article-prime|article-a[1-6])$/', $placement ) || $position < 1 || $position > strlen( $content ) ) {
			continue;
		}
		$is_prime = 'article-prime' === $placement;

		$markup = go_verge_adsense_unit_markup(
			$placement,
			array(
				'tag'   => 'aside',
				'class' => 'go-article-revenue-slot ' . ( $is_prime ? 'go-article-prime-slot ' : '' ) . 'go-article-revenue-slot--' . $placement,
				'data'  => array(
					'ad-surface'       => $is_prime ? 'article-prime' : 'article',
					'ad-depth'         => (int) round( (float) ( $candidate['depth'] ?? 0 ) * 100 ),
					'ad-planner-score' => (float) ( $candidate['score'] ?? 0 ),
					'ad-before-words'  => absint( $candidate['beforeWords'] ?? 0 ),
					'ad-article-words' => absint( $metrics['words'] ?? 0 ),
					/* The runtime's frontier ladder is calibrated on body words
					 * (prose + plain lists), which is also what the planner's own
					 * capacity function uses. Emitting only the total let the two
					 * sides size the same article differently. */
					'ad-body-words'    => absint( $metrics['bodyWords'] ?? 0 ),
					'ad-profile'       => $profile,
					'ad-article-type'  => sanitize_key( (string) ( $plan['articleType'] ?? '' ) ),
					'ad-planner-version' => (string) ( $plan['version'] ?? '' ),
					'ad-planned-count' => absint( $plan['plannedCount'] ?? count( $selected ) ),
					'ad-rendered-count' => absint( $plan['renderedCount'] ?? count( $selected ) ),
					'ad-fallback-reserve' => ! empty( $candidate['fallback'] ) ? 1 : 0,
					'ad-eligible-candidates' => absint( $eligible_candidates ),
					'ad-body-capacity' => absint( $plan['totalCapacity'] ?? 0 ),
				),
			)
		);
		if ( '' === $markup ) {
			$render_rejections[] = $placement;
			continue;
		}
		$rendered[] = array( 'position' => $position, 'markup' => $markup );
		if ( ! empty( $candidate['fallback'] ) ) { $emitted_reserves++; }
		else { $emitted_primary++; }
	}

	/* The renderer can reject disabled, ineligible or already claimed units.
	 * Only emitted hosts fund the browser budget; the original structural plan
	 * remains available below in the administrator-only decision log. */
	$emitted_count = count( $rendered );
	$emitted_capacity = min( absint( $plan['totalCapacity'] ?? 0 ), $emitted_count );
	$GLOBALS['go_verge_ads_article_plan_public']['planned-body'] = $emitted_primary;
	$GLOBALS['go_verge_ads_article_plan_public']['rendered-body'] = $emitted_count;
	$GLOBALS['go_verge_ads_article_plan_public']['reserve-body'] = $emitted_reserves;
	$GLOBALS['go_verge_ads_article_plan_public']['body-capacity'] = $emitted_capacity;
	$effective_attributes = array(
		'planned-count' => $emitted_primary,
		'rendered-count' => $emitted_count,
		'body-capacity' => $emitted_capacity,
	);
	foreach ( array_reverse( $rendered ) as $host ) {
		/* Update only our three numeric attributes in freshly generated markup,
		 * never the editorial source or a provider node in a browser. */
		$markup = preg_replace_callback(
			'/\bdata-go-ad-(planned-count|rendered-count|body-capacity)="[0-9]+"/',
			static function ( $match ) use ( $effective_attributes ) {
				return 'data-go-ad-' . $match[1] . '="' . $effective_attributes[ $match[1] ] . '"';
			},
			$host['markup']
		);
		$position = $host['position'];
		$content = substr( $content, 0, $position ) . "\n" . $markup . "\n" . substr( $content, $position );
	}

	/* Keep the full planner decision log server-side for administrator debugging;
	 * do not place it in public/cached HTML. */
	if ( function_exists( 'go_verge_ads_debug_enabled' ) && go_verge_ads_debug_enabled() ) {
		$GLOBALS['go_verge_ads_planner_debug'] = array(
			'profile'       => $profile,
			'metrics'       => $metrics,
			'totalCapacity' => absint( $plan['totalCapacity'] ?? 0 ),
			'capacity'      => absint( $plan['capacity'] ?? 0 ),
			'plannedCount'  => absint( $plan['plannedCount'] ?? 0 ),
			'renderedCount' => absint( $plan['renderedCount'] ?? 0 ),
			'reserveCount'  => absint( $plan['reserveCount'] ?? 0 ),
			'version'       => (string) ( $plan['version'] ?? '' ),
			'prime'         => isset( $plan['prime'] ) ? $plan['prime'] : null,
			'reserve'       => isset( $plan['reserve'] ) ? $plan['reserve'] : null,
			'reserves'      => isset( $plan['reserves'] ) ? (array) $plan['reserves'] : array(),
			'candidates'    => (array) ( $plan['candidates'] ?? array() ),
			'decisions'     => (array) ( $plan['decisions'] ?? array() ),
			'emitted'      => array( 'plannedCount' => $emitted_primary, 'renderedCount' => $emitted_count, 'reserveCount' => $emitted_reserves, 'totalCapacity' => $emitted_capacity ),
			'renderRejectedPlacements' => $render_rejections,
		);
	}

	return $content;
}

/**
 * The ordered listing pool, in descending order of expected value.
 *
 * Listing inventory used to be addressed by name from two different cadence
 * maps that disagreed with each other, and a third map inline in the archive
 * templates. That made "which unit is the first one on a category page?"
 * unanswerable, and it meant the optional F4/F5 units could be scheduled at a
 * row the page never reached.
 *
 * There is now one pool and one cursor per document context. Whoever asks first
 * gets F1 — the post-hero position on an archive, or the first scheduled row on
 * a stream that has no hero. A placement whose ad unit is undefined renders
 * nothing and does not consume its turn, so defining F4/F5 in wp-config.php
 * extends the ladder with no other change.
 *
 * @param string $context Document context key.
 * @return string Placement key, or '' when the pool is exhausted.
 */
function go_verge_ads_listing_pool_next( $context ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ''; }
	$pool    = array( 'listing-f1', 'listing-f2', 'listing-f3', 'listing-f4', 'listing-f5' );
	$context = sanitize_key( (string) $context );
	$state   = go_verge_ads_listing_state( $context );
	$index   = (int) $state['cursor'];
	if ( $index >= count( $pool ) ) {
		return '';
	}
	go_verge_ads_listing_state( $context, array( 'cursor' => $index + 1 ) );
	return $pool[ $index ];
}

/** Request-local state only. No browser offset or AJAX parameter grants a slot. */
function go_verge_ads_listing_state( $context, $updates = array() ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return array( 'cursor' => 0, 'rows' => 0, 'root' => false, 'manifest' => false, 'hero' => false ); }
	static $states = array();
	$context = sanitize_key( (string) $context );
	if ( ! isset( $states[ $context ] ) ) {
		$states[ $context ] = array( 'cursor' => 0, 'rows' => 0, 'root' => false, 'manifest' => false, 'hero' => false );
	}
	$states[ $context ] = array_merge( $states[ $context ], (array) $updates );
	return $states[ $context ];
}

/** The initial feed and its continuation share one unchanged row schedule. */
function go_verge_ads_listing_schedule( $context ) {
	return 'home' === $context ? array( 3, 6, 9, 12, 15 ) : array( 3, 7, 11, 15, 19 );
}

/** Mark one initial editorial feed; AJAX fragments never establish a new root. */
function go_verge_ads_listing_root_attributes() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ''; }
	if ( ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() )
		|| ! go_verge_ads_is_monetizable_request() ) {
		return '';
	}
	$context = go_verge_ads_document_context();
	$state = go_verge_ads_listing_state( $context );
	if ( $state['root'] || ! in_array( $context, go_verge_ads_listing_contexts(), true ) ) {
		return '';
	}
	go_verge_ads_listing_state( $context, array( 'root' => true ) );
	return ' data-go-ad-listing-root="1" data-go-ad-listing-card-selector=".go-archive-row"';
}

/**
 * Escrow every still-unclaimed pool identity in inert templates for real feed
 * continuation.
 *
 * Their scheduled rows remain unchanged. No provider markup is added to AJAX
 * responses and no script inside the outer template executes. The runtime may
 * materialize each host once, after counting actual direct-child story cards,
 * and then applies the same consent, geometry and one-request rules as usual.
 *
 * Until 5.5.0 this loop accepted only F4/F5 and `break`-ed on anything else —
 * but go_verge_ads_listing_pool_next() advances the cursor on every call, so the
 * rejected rank was consumed and then never rendered anywhere. A hub or archive
 * whose initial page spent fewer than three ranks (any feed with no after-hero
 * unit, and every hub from page 2 on) therefore destroyed F3 outright and pushed
 * F4/F5 from rows 11/15 down to 15/19 — four rows of reach given away for an
 * identity the document never used. Whatever the pool still holds at footer time
 * is by definition unclaimed: the renderer's per-response slot claim and the
 * cursor together already guarantee one host per identity per document.
 */
function go_verge_ads_render_listing_continuation() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	if ( ( defined( 'GO_VERGE_ADS_LISTING_CONTINUATION_ENABLED' ) && ! GO_VERGE_ADS_LISTING_CONTINUATION_ENABLED )
		|| ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() )
		|| ! go_verge_ads_is_monetizable_request() ) {
		return;
	}
	$context = go_verge_ads_document_context();
	$state = go_verge_ads_listing_state( $context );
	if ( ! $state['root'] || $state['manifest'] || $state['rows'] < 1 ) {
		return;
	}
	go_verge_ads_listing_state( $context, array( 'manifest' => true ) );
	foreach ( go_verge_ads_listing_schedule( $context ) as $row ) {
		if ( $row <= $state['rows'] ) {
			continue;
		}
		while ( '' !== ( $placement = go_verge_ads_listing_pool_next( $context ) ) ) {
			/* The pool hands out each identity once, in rank order, and the cursor
			 * has already moved. Rendering whatever it returns keeps the schedule's
			 * own appointment for that rank; rejecting it would only discard the
			 * unit, because there is no way to put a rank back. */
			$markup = go_verge_adsense_unit_markup( $placement, array(
				'tag' => 'aside',
				'class' => 'go-listing-revenue-slot go-listing-revenue-slot--continuation',
				'data' => array( 'ad-surface' => $context . '-continuation', 'ad-listing-index' => $row ),
			) );
			if ( '' === $markup ) {
				continue;
			}
			echo '<template data-go-listing-reserve data-go-listing-after="' . esc_attr( $row ) . '">' . $markup . '</template>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- renderer and attributes escaped above.
			break;
		}
	}
}
add_action( 'wp_footer', 'go_verge_ads_render_listing_continuation', 4 );

/**
 * Render the next listing opportunity from the pool.
 *
 * @param string $surface Diagnostic surface name.
 * @param int    $index   One-based item index, for diagnostics only.
 * @return bool True when a unit was printed.
 */
function go_verge_ads_render_listing_unit( $surface = 'listing', $index = 0 ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return false; }
	if ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) {
		return false;
	}
	$context   = function_exists( 'go_verge_ads_document_context' ) ? go_verge_ads_document_context() : 'other';
	/* A disabled, context-ineligible or already claimed unit is not a rendered
	 * opportunity. Advance within this same host until the finite pool supplies
	 * a valid unit. The renderer still owns context and duplicate-slot guards;
	 * no additional host, request, retry or refresh is created here. */
	while ( '' !== ( $placement = go_verge_ads_listing_pool_next( $context ) ) ) {
		$markup = go_verge_adsense_unit_markup(
			$placement,
			array(
				'tag'   => 'aside',
				'class' => 'go-listing-revenue-slot go-listing-revenue-slot--' . sanitize_html_class( $surface ),
				'data'  => array(
					'ad-surface'       => sanitize_key( $surface ),
					'ad-listing-index' => absint( $index ),
				),
			)
		);
		if ( '' === $markup ) {
			continue;
		}
		echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built and escaped by the renderer.
		return true;
	}
	return false;
}

/**
 * Ordered anchors of the article's post-content zone, in reading order.
 *
 * @return string[]
 */
function go_verge_ads_post_content_anchors() {
	return (array) apply_filters(
		'go_verge_ads_post_content_anchors',
		array( 'after-author', 'after-recirculation', 'before-comments' )
	);
}

/**
 * Inventory for the part of an article that came after the last ad unit.
 *
 * A single_post document used to end its advertising at `article-end`, which
 * sits immediately after the prose. Everything below it — the author card, the
 * contextual next link, "Leia também", more reviews by the author, the game
 * cluster, the topic bar, the comments and the explore rail — carried none. On
 * a phone that is several screens of real, scrolled publisher content with no
 * inventory in it, and it is content a Discover reader reaches often, because
 * arriving at one story and continuing into another is what that audience does.
 *
 * This does not add an ad unit to the account. The listing pool (F1..F5) is
 * created, live and simply unspent on this template: the body ladder is a
 * different pool, so nothing here competes with P1/A1..A6 or article-end for a
 * slot id. The pool stays finite and ordered, so the zone can offer at most
 * what the pool still holds, and each anchor takes at most one.
 *
 * As everywhere else, this renders an OPPORTUNITY. Whether it becomes a request
 * is decided by the runtime against the same stream spacing, density window and
 * ad-to-content ratio every other position obeys, which is what keeps three
 * anchors from becoming three ads on a short story.
 *
 * @param string $anchor One of go_verge_ads_post_content_anchors().
 * @return bool True when an opportunity was printed.
 */
function go_verge_ads_render_post_content_unit( $anchor ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return false; }
	if ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) { return false; }
	if ( ! function_exists( 'is_singular' ) || ! is_singular( 'post' ) ) { return false; }
	if ( ! function_exists( 'go_verge_ads_is_monetizable_request' ) || ! go_verge_ads_is_monetizable_request() ) { return false; }

	$anchor = sanitize_key( (string) $anchor );
	if ( '' === $anchor || ! in_array( $anchor, go_verge_ads_post_content_anchors(), true ) ) {
		return false;
	}

	/* One opportunity per anchor per document, even if a template part that
	 * renders it is included twice. */
	static $spent = array();
	if ( isset( $spent[ $anchor ] ) ) {
		return false;
	}
	$spent[ $anchor ] = true;

	/*
	 * The recirculation boundary prefers the Multiplex grid.
	 *
	 * Not because it is bigger, but because it is a different auction. Multiplex
	 * draws on native/recirculation demand that does not bid on the responsive
	 * Display unit the listing pool would have put here, so this is the page
	 * entering a second marketplace rather than running the same one twice. It
	 * is also the only boundary where a grid of related items is the native
	 * shape of the moment instead of an interruption of it.
	 *
	 * It REPLACES the pool unit at this anchor; it is not added on top. The
	 * grid is tall, and stacking a banner against it is exactly the density the
	 * rest of this engine exists to prevent. If the unit is ever disabled or
	 * rolled back, the anchor falls through to the pool with no other change.
	 */
	if ( 'after-recirculation' === $anchor && function_exists( 'go_verge_adsense_unit_markup' ) ) {
		$markup = go_verge_adsense_unit_markup(
			'post-content-multiplex',
			array(
				'tag'   => 'aside',
				'class' => 'go-listing-revenue-slot go-listing-revenue-slot--post-content-' . $anchor . ' go-post-content-multiplex',
				'data'  => array( 'ad-surface' => 'post-content-' . $anchor ),
			)
		);
		if ( '' !== $markup ) {
			echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built and escaped by the renderer.
			return true;
		}
	}

	return go_verge_ads_render_listing_unit( 'post-content-' . $anchor, 0 );
}

/**
 * Backwards-compatible entry point for templates that schedule their own rows.
 *
 * The cadence argument is now read only for the row numbers it names; which
 * ad unit is served comes from the shared pool.
 *
 * @param int                    $index   One-based item index in the stream.
 * @param string                 $surface Diagnostic surface name.
 * @param array<int,string>|null $cadence Rows at which this stream offers a unit.
 * @return void
 */
function go_verge_ads_render_indexed_listing_unit( $index, $surface = 'listing', $cadence = null ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	$index = absint( $index );
	if ( $index < 1 ) {
		return;
	}
	$rows = null === $cadence ? array( 3, 6, 9 ) : array_map( 'absint', array_keys( (array) $cadence ) );
	if ( ! in_array( $index, $rows, true ) ) {
		return;
	}
	go_verge_ads_render_listing_unit( $surface, $index );
}

/**
 * The first premium listing position: immediately after the archive hero.
 *
 * An archive's first page opens with a visual feature and up to four secondary
 * cards — five stories — before the chronological list begins. The in-stream
 * cadence only counts list rows, so the first unit used to land around the
 * seventh story, well past the point where most of the page's readers stop.
 * The boundary between the hero block and "Últimas publicações" is a genuine
 * editorial break at roughly one screen of scroll, which is the highest-reach
 * position this template has.
 *
 * On page 2 and beyond there is no hero, nothing calls this, and the pool
 * simply hands F1 to the first scheduled row instead.
 *
 * @return void
 */
function go_verge_ads_render_archive_hero_unit() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	if ( ! function_exists( 'go_verge_ads_document_context' ) ) {
		return;
	}
	$context = go_verge_ads_document_context();
	if ( ! in_array( $context, go_verge_ads_listing_contexts(), true ) || 'home' === $context ) {
		return;
	}
	$state = go_verge_ads_listing_state( $context );
	if ( $state['hero'] ) {
		return;
	}
	go_verge_ads_listing_state( $context, array( 'hero' => true ) );
	go_verge_ads_render_listing_unit( $context . '-after-hero', 0 );
}
add_action( 'go_verge_archive_after_hero', 'go_verge_ads_render_archive_hero_unit', 40 );

/**
 * Normal hub integration at the existing, closed hero boundary.
 *
 * Desk templates keep their hero visible while paginating the feed and pass 1
 * to this hook even on later pages. Resolve the actual document/desk page here
 * so only the first page can spend the shared pool's after-hero opportunity.
 */
function go_verge_ads_render_editorial_hub_hero_unit( $zone = '', $hero_ids = array(), $page = 1 ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	if ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) {
		return;
	}
	$hero_ids = array_filter( array_map( 'absint', (array) $hero_ids ) );
	if ( ! $hero_ids || 1 !== absint( $page ) ) {
		return;
	}
	$document_page = function_exists( 'get_query_var' )
		? max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) )
		: 1;
	$desk = function_exists( 'go_verge_desk_format_context' ) ? go_verge_desk_format_context() : array();
	if ( $document_page > 1 || absint( $desk['page'] ?? 1 ) > 1 ) {
		return;
	}
	go_verge_ads_render_archive_hero_unit();
}
add_action( 'go_verge_editorial_hub_after_hero', 'go_verge_ads_render_editorial_hub_hero_unit', 40, 3 );

/** Document contexts whose streams carry listing inventory. */
function go_verge_ads_listing_contexts() {
	return array(
		'home', 'latest', 'category', 'tag', 'search', 'author', 'games_archive',
		'reviews_archive', 'editorial_page', 'single_production', 'single_entity',
		'productions_archive', 'entities_archive',
	);
}

/**
 * Request-scoped row counter for the standard horizontal editorial row.
 *
 * Cadence is about DEPTH, not count. A position's worth is reach x coverage,
 * and reach falls steeply down a stream, so the rows are chosen to spread the
 * pool across the part of the page readers actually reach rather than to place
 * as many units as the pool contains.
 *
 * Home starts later because its opening rows are the editorial front page.
 * Archives start at row 3 because their first premium position is already
 * spent on the post-hero boundary above.
 *
 * AJAX fragments never emit provider units: "Carregar mais" would otherwise
 * append a second copy of a slot id that the page has already requested.
 *
 * @return void
 */
function go_verge_ads_maybe_render_listing_unit() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	if ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) {
		return;
	}
	$context = function_exists( 'go_verge_ads_document_context' ) ? go_verge_ads_document_context() : '';
	if ( ! in_array( $context, go_verge_ads_listing_contexts(), true ) ) {
		return;
	}

	$state = go_verge_ads_listing_state( $context );
	$index = (int) $state['rows'] + 1;
	go_verge_ads_listing_state( $context, array( 'rows' => $index ) );

	/*
	 * Home keeps its established 3/6/9 rhythm: its stream sits below three
	 * editorial modules that already carry their own inventory.
	 *
	 * Archives are wider apart because their first unit is already spent above,
	 * at the hero boundary. Rows 3/7/11 put roughly 550px then 700px of story
	 * cards between units on a phone, which clears the stream spacing floor with
	 * room to spare instead of sitting right on it — the 2/4/7 cadence used
	 * until 4.6 put barely 360px between the first two.
	 */
	$schedule = go_verge_ads_listing_schedule( $context );
	if ( ! in_array( $index, $schedule, true ) ) {
		return;
	}
	go_verge_ads_render_listing_unit( $context, $index );
}
