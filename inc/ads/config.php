<?php
/**
 * AdSense inventory contract and the single delivery-rule table.
 *
 * Delivery model: MANUAL IN-PAGE + PROVIDER OVERLAYS ("manual_overlays").
 *
 * Every in-page opportunity on this site belongs to the theme. Account-level
 * Auto Ads should run with official anchor and vignette formats only. The
 * account settings must be checked separately. The runtime observes exposed
 * anchor geometry/status to avoid collisions with publisher wrappers; it never
 * moves, resizes, hides, replaces or refreshes those official formats. The
 * manual engine cannot rely on Auto Ads in-page to fill structural gaps.
 *
 * This file is the one place that answers:
 *   - which ad units exist, on which templates, at which quality tier;
 *   - which rules the browser runtime obeys, split by device.
 *
 * Anything numeric the runtime uses lives in go_verge_ads_delivery_rules().
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_ADSENSE_CLIENT' ) ) {
	define( 'GO_VERGE_ADSENSE_CLIENT', 'ca-pub-3687004010207904' );
}
if ( ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_SLOT' ) ) {
	define( 'GO_VERGE_ADSENSE_TOPSCROLL_SLOT', '7792311754' );
}

/*
 * Deeper listing inventory.
 *
 * F4 and F5 are native Display/responsive units created for the listing pool.
 * The publisher ids below are the canonical defaults for this theme build.
 * A wp-config.php constant may still override either id before the theme loads,
 * which keeps emergency rollbacks possible without editing theme files.
 */
if ( ! defined( 'GO_VERGE_ADS_LISTING_F4_SLOT' ) ) {
	define( 'GO_VERGE_ADS_LISTING_F4_SLOT', '4207836686' );
}
if ( ! defined( 'GO_VERGE_ADS_LISTING_F5_SLOT' ) ) {
	define( 'GO_VERGE_ADS_LISTING_F5_SLOT', '4704776118' );
}

/**
 * An optional ad unit id from wp-config.php, or nothing.
 *
 * A slot id is digits. Anything else — a quoted name, a pasted `<ins>` fragment,
 * a stray space — is a typo, and the position must fail closed. Without this it
 * survived every guard: `enabled` only asked whether the constant was non-empty,
 * so a broken id produced a unit that took its turn in the listing rotation,
 * displacing a working one, while `go_verge_ads_all_slots()` stripped it to ''
 * and left it invisible to the economics model and to every health check.
 */
function go_verge_ads_optional_slot( $value ) {
	return (string) preg_replace( '/\D+/', '', (string) $value );
}

/*
 * The body ladder is one format: Display responsive.
 *
 * A1, A2 and A3 now use new Display ids. Historical In-article and ON_PAGE
 * averages describe different placements and audiences, not a controlled
 * format comparison. The 21/09 export contains revenue and impressions for
 * the old three In-article ids; absence of history must not be assumed.
 * Compare formats at the same position, for randomized equivalent audiences,
 * before attributing incremental revenue to the format change.
 *
 * The old In-article units (6368539121, 7554015324, 6240933652) stay idle in
 * the account. A unit's type cannot be edited after it is created, which is why
 * these are new ids and not a reconfiguration -- and why no wp-config constant
 * may ever swap a live unit's type again. See tests/test-manual-formats.php.
 */

/**
 * The delivery rule table. One device profile per reading environment.
 *
 * These are the ONLY numbers the browser runtime obeys. Nothing in the runtime
 * carries a second, competing threshold for the same decision.
 *
 * Mobile and desktop are not the same environment with a multiplier applied.
 * A phone scrolls a narrow column where a 300x250 creative occupies a third of
 * the screen; a desktop reads a wide column beside a sticky rail, so the same
 * article is far shorter in pixels and two in-body units land much closer
 * together. Each profile is therefore stated in full.
 *
 * Distances that depend on how much the reader can see are expressed in
 * viewports (`_vh`) so they hold on a 640px phone and a 1200px desktop alike.
 * Distances that describe physical crowding are expressed in pixels.
 *
 * @return array<string,array<string,mixed>>
 */
function go_verge_ads_delivery_rules() {
	return (array) apply_filters(
		'go_verge_ads_delivery_rules',
		array(
			/* ≥ this viewport width the reader gets the desktop profile. It is the
			 * same breakpoint the sticky sidebar rail appears at. */
			'desktop_min_width' => 1101,

			'mobile' => array(
				/* Real rendered publisher content between two creatives. This is a
				 * floor against stacking, not the density policy: on a correctly
				 * distributed ladder it never binds. It exists for the case the
				 * server's height estimate was wrong (a late image, a collapsed
				 * embed) and two units would otherwise render almost touching. It is
				 * calibrated against go_verge_ads_planner_clearance(): a pair the
				 * planner accepts renders just above this on a phone. */
				'min_gap_px'              => 240,
				/* The density policy. No window of ±0.9 viewports around a candidate
				 * may end up holding more than three publisher units, or give more
				 * than 45% of its height to advertising. Counting units is
				 * predictable before the auction returns a creative height; the
				 * ratio catches unusually tall creatives. Both must pass. */
				'density_window_vh'       => 0.90,
				'max_units_in_window'     => 3,
				'max_local_ad_ratio'      => 0.45,
				/* The whole article, measured against its own rendered height. */
				'max_ad_to_content_ratio' => 0.45,
				/* Listing/home units sit between story cards rather than inside
				 * prose, so the sliding window does not describe them. */
				'min_stream_gap_px'       => 380,
				/* Resting warm-up distance for a reader who is not moving, per
				 * quality tier, in viewports. A high-reach position may be prepared
				 * a full screen ahead; a completion unit stays cold until the reader
				 * is nearly there, because an early request there is the most likely
				 * to become a non-viewable impression. */
				'rest_lead_vh'            => array( 'reach' => 1.00, 'premium' => 0.90, 'standard' => 0.75, 'deep' => 0.60, 'completion' => 0.52 ),
				'rest_lead_min_px'        => 260,
				'rest_lead_max_px'        => 1100,
				/* Absolute ceiling for the predictive window. However fast the
				 * reader moves, nothing is requested more than this far ahead. */
				'max_lookahead_vh'        => 3.0,
				/* Above this scroll speed the reader is flicking, not reading: a
				 * creative delivered into that motion is unlikely to be seen for
				 * long enough to count. Reach/premium are exempt. */
				'flick_vh_s'              => 2.0,
				/* Network smoothing between non-critical requests. */
				'request_spacing_ms'      => 90,
				/* What counts as an engaged reader on this device. */
				'engage_scroll_vh'        => 0.07,
				'engage_dwell_ms'         => 1500,
			),

			'desktop' => array(
				/* A desktop column is roughly twice as wide, so the same paragraph is
				 * half as tall and the same plan lands much closer together. The floor
				 * is correspondingly higher, and positions it rejects simply pass their
				 * opportunity to the next safe host further down. */
				'min_gap_px'              => 300,
				'density_window_vh'       => 0.85,
				'max_units_in_window'     => 3,
				'max_local_ad_ratio'      => 0.42,
				'max_ad_to_content_ratio' => 0.45,
				'min_stream_gap_px'       => 460,
				/* Desktop viewports are taller, so the same fraction of a viewport is
				 * already more pixels. The fractions are deliberately smaller. */
				'rest_lead_vh'            => array( 'reach' => 0.85, 'premium' => 0.78, 'standard' => 0.65, 'deep' => 0.55, 'completion' => 0.50 ),
				'rest_lead_min_px'        => 280,
				'rest_lead_max_px'        => 1200,
				'max_lookahead_vh'        => 2.6,
				/* A mouse wheel moves in discrete jumps, so the honest flick
				 * threshold is higher than on a touch surface. */
				'flick_vh_s'              => 2.4,
				'request_spacing_ms'      => 70,
				'engage_scroll_vh'        => 0.09,
				'engage_dwell_ms'         => 1800,
			),

			/*
			 * Shared timings.
			 *
			 * `critical_hold_ms` is how long above-the-fold inventory may keep the
			 * rest of the page waiting so the first auctions are not competing with
			 * body requests for the same connections.
			 *
			 * `stuck_release_ms` closes a real production leak. Google writes
			 * `data-ad-status` on the `ins` when it resolves a request. A request
			 * that never receives one used to hold its share of the article's
			 * opportunity budget for the whole pageview, so one silent unit could
			 * cost a long article a position that was structurally safe. After this
			 * many milliseconds without any provider answer the OPPORTUNITY is
			 * released to the next safe host. The silent unit itself is never asked
			 * again: one request per placement, per pageview, stands.
			 */
			'critical_hold_ms' => 800,
			'stuck_release_ms' => 8000,

			/*
			 * The Revenue Governor.
			 *
			 * The engine opens the planner's reserve hosts only for a session that
			 * has demonstrably earned them. These are the thresholds for that
			 * demonstration; they are read from measured scroll depth, measured
			 * dwell on this page and — for a returning reader who allowed storage —
			 * the exponential average depth of their previous pageviews.
			 */
			'governor' => array(
				'expansion_depth'       => 0.40,
				'expansion_dwell_ms'    => 18000,
				/* Depth alone is proof enough once it is this deep. */
				'expansion_deep_depth'  => 0.58,
				/* A reader who habitually finishes articles earns the reserve sooner. */
				'expansion_prior_depth' => 0.70,
				'expansion_prior_floor' => 0.35,
				/* How far ahead the engine may prepare a placement while the reader
				 * has proven nothing yet, and while they are flick-scrolling. Both
				 * are in viewports, and both are ceilings on the predictive window
				 * rather than distances of their own. */
				'warmup_lookahead_vh'   => 1.15,
				'conservative_lookahead_vh' => 1.25,
				/* Spacing multipliers per state. Conservative widens the floor;
				 * expansion is allowed to close slightly, never below the hard
				 * minimum the density policy already guarantees. */
				'spacing_scale'         => array( 'warmup' => 1.00, 'standard' => 1.00, 'conservative' => 1.20, 'expansion' => 0.94 ),
			),
		)
	);
}

/** @return array<string,mixed> */
function go_verge_ads_config() {
	static $config = null;
	if ( null !== $config ) {
		return $config;
	}

	$topscroll_enabled = ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_ENABLED' ) || (bool) GO_VERGE_ADSENSE_TOPSCROLL_ENABLED;
	$masthead_mobile   = ! defined( 'GO_VERGE_ADS_MASTHEAD_MOBILE' ) || (bool) GO_VERGE_ADS_MASTHEAD_MOBILE;

	$config = array(
		'version'   => '19.0.0-manual-governor',
		'delivery_mode' => 'manual_overlays',
		/* Intended account state only, never an API confirmation. The fixed
		 * manual contract is restored after filters; official overlays stay on. */
		'account_formats' => array(
			'in_page'    => 'off',
			'anchor'     => 'on',
			'vignette'   => 'on',
			'side_rails' => 'off',
		),
		'enabled'   => ! defined( 'GO_ADS_V3_ENABLED' ) || (bool) GO_ADS_V3_ENABLED,
		'publisher' => GO_VERGE_ADSENSE_CLIENT,
		'breakpoints' => array(
			'mobile_max'  => 767,
			'desktop_min' => 1101,
		),
		'excluded_page_slugs' => array(
			'acessibilidade', 'contato', 'midia-kit', 'parcerias',
			'politica-de-reviews', 'politica-editorial', 'politica-de-privacidade',
			'privacidade', 'sobre-o-overdrive', 'sobre-o-game-overdrive',
			'termos-de-uso',
		),
		'inventory' => array(
			'topscroll' => array(
				'name'              => 'GO_V4_GLOBAL_ALL_TOPSCROLL_DISPLAY',
				'slot'              => GO_VERGE_ADSENSE_TOPSCROLL_SLOT,
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'requested_size'    => 'responsive-auto full-width',
				'templates'         => array( 'home', 'single_post', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'mobile_only'       => true,
				'collapse_unfilled' => true,
				'measurement_tier'  => 'reach',
				'priority'          => 'critical',
				/* 250px creative baseline + 44px control row + 14px tap-safety gap. */
				'reserve'           => array( 'mobile' => 308, 'desktop' => 0 ),
				'enabled'           => $topscroll_enabled,
			),
			'site-masthead' => array(
				'near_viewport'     => 600,
				'near_viewport_max' => 2200,
				'predictive'        => true,
				'safety_ms'         => 600,
				'name'           => 'GO_V3_SINGLE_ALL_TOP_DISPLAY',
				'slot'           => '3572313419',
				/*
				 * Vertical-specific ad units for the two commercial hubs, swapped
				 * in at render time so each vertical's masthead can be measured
				 * on its own. Declared HERE rather than inline in the renderer:
				 * they are real account units, and anything that only exists
				 * inside a render branch is invisible to the seven-day economic
				 * model, to the decision dashboard and to Site Health. Two of
				 * this account's twenty units used to be exactly that.
				 */
				'slot_variants'  => array(
					'tecnologia'     => array( 'slot' => '7835738857', 'name' => 'OD383_TECNOLOGIA_TOP_DISPLAY' ),
					'entretenimento' => array( 'slot' => '2789005317', 'name' => 'OD383_ENTRETENIMENTO_TOP_DISPLAY' ),
				),
				'sizing'         => 'responsive',
				'format'         => 'auto',
				'full_width'     => true,
				'requested_size' => 'responsive-auto full-width',
				'measurement_tier' => 'reach',
				'priority'       => 'critical',
				'templates'      => array( 'single_post', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'min_viewport'   => $masthead_mobile ? 0 : 768,
				'reserve'        => array( 'mobile' => $masthead_mobile ? 132 : 0, 'desktop' => 122 ),
				'enabled'        => true,
			),
			/*
			 * Home Top Display — DESKTOP ONLY, by publisher decision.
			 *
			 * On mobile the home already opens with Top Scroll, and a second
			 * large display unit between the hero and the first stories changes
			 * the look of the front page for a surface whose circulation is far
			 * below the article templates. The revenue the engine would gain here
			 * is not worth the front page's identity, so mobile home carries no
			 * masthead. Home supply is recovered deeper in the stream instead
			 * (listing F1/F2/F3 at rows 3/7/11), where it reads as an editorial
			 * break rather than as a second banner at the top.
			 */
			'home-masthead' => array(
				'near_viewport'     => 600,
				'near_viewport_max' => 2200,
				'predictive'        => true,
				'safety_ms'         => 600,
				'name'              => 'GO Home Desktop Masthead',
				'slot'              => '3572313419',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'requested_size'    => 'responsive-auto full-width',
				'measurement_tier'  => 'reach',
				'priority'          => 'critical',
				'templates'         => array( 'home' ),
				'desktop_only'      => true,
				'reserve'           => array( 'mobile' => 0, 'desktop' => 122 ),
				'enabled'           => true,
			),
			'article-hero-overlay' => array(
				'near_viewport'     => 600,
				'near_viewport_max' => 2200,
				'predictive'        => true,
				'safety_ms'         => 600,
				'name'              => 'GO_V3_SINGLE_ALL_HERO_OVERLAY_DISPLAY',
				'slot'              => '5017324239',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'requested_size'    => 'responsive-auto full-width inside hero surface',
				'measurement_tier'  => 'premium',
				'priority'          => 'critical',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 132, 'desktop' => 282 ),
				'enabled'           => ! defined( 'GO_ADS_HERO_OVERLAY_ENABLED' ) || (bool) GO_ADS_HERO_OVERLAY_ENABLED,
			),
			'game-hub-mid' => array(
				'name'              => 'GO Game Hub Mid',
				'slot'              => '1188364638',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1050,
				'near_viewport_max' => 1850,
				'predictive'        => true,
				'safety_ms'         => 650,
				'measurement_tier'  => 'premium',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_game' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'sidebar-desktop' => array(
				'name'              => 'GO_V2_Single_Desktop_Sidebar_Sticky',
				'slot'              => '6489083385',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1800,
				'near_viewport_max' => 3200,
				'predictive'        => true,
				'safety_ms'         => 700,
				'measurement_tier'  => 'premium',
				'requested_size'    => 'responsive-auto inside 300px sticky sidebar rail',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post', 'single_game' ),
				'desktop_only'      => true,
				'reserve'           => array( 'mobile' => 0, 'desktop' => 632 ),
				'enabled'           => true,
			),
			'article-prime' => array(
				'name'              => 'GO Article Prime P1',
				'slot'              => '5223365459',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1850,
				'near_viewport_max' => 3000,
				'predictive'        => true,
				'safety_ms'         => 775,
				'measurement_tier'  => 'reach',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'article-a1' => array(
				'name'              => 'GO Article A1',
				'slot'              => '7131714626',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'requested_size'    => 'responsive display',
				'near_viewport'     => 1650,
				'near_viewport_max' => 2800,
				'predictive'        => true,
				'safety_ms'         => 700,
				'measurement_tier'  => 'premium',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'article-a2' => array(
				'name'              => 'GO Article A2',
				'slot'              => '4505551284',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'requested_size'    => 'responsive display',
				'near_viewport'     => 1450,
				'near_viewport_max' => 2500,
				'predictive'        => true,
				'safety_ms'         => 650,
				'measurement_tier'  => 'premium',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'article-a3' => array(
				'name'              => 'GO Article A3',
				'slot'              => '5056215625',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'requested_size'    => 'responsive display',
				'near_viewport'     => 1450,
				'near_viewport_max' => 3000,
				'predictive'        => true,
				'safety_ms'         => 600,
				'measurement_tier'  => 'standard',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'article-a4' => array(
				'name'              => 'GO Article A4',
				'slot'              => '6568236715',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1100,
				'near_viewport_max' => 2700,
				'predictive'        => true,
				'safety_ms'         => 500,
				'measurement_tier'  => 'standard',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'article-a5' => array(
				'name'              => 'GO Article A5',
				'slot'              => '8238832024',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1100,
				'near_viewport_max' => 2350,
				'predictive'        => true,
				'safety_ms'         => 475,
				'measurement_tier'  => 'deep',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'article-a6' => array(
				'name'              => 'GO Article A6',
				'slot'              => '5255155049',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1050,
				'near_viewport_max' => 2050,
				'predictive'        => true,
				'safety_ms'         => 450,
				'measurement_tier'  => 'deep',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),

			'article-end' => array(
				'name'              => 'GO Article End D1',
				'slot'              => '5798080525',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1050,
				'near_viewport_max' => 1700,
				'predictive'        => true,
				'safety_ms'         => 450,
				'measurement_tier'  => 'completion',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'single_post' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'listing-f1' => array(
				'name'              => 'GO Listing F1',
				'slot'              => '4927851985',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1200,
				'near_viewport_max' => 2000,
				'predictive'        => true,
				'safety_ms'         => 650,
				'measurement_tier'  => 'premium',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'listing-f2' => array(
				'name'              => 'GO Listing F2',
				'slot'              => '3996334686',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1050,
				'near_viewport_max' => 1500,
				'predictive'        => true,
				'safety_ms'         => 500,
				'measurement_tier'  => 'deep',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			'listing-f3' => array(
				'name'              => 'GO Listing F3',
				'slot'              => '2880273141',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1000,
				'near_viewport_max' => 1350,
				'predictive'        => true,
				'safety_ms'         => 500,
				'measurement_tier'  => 'deep',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
			/* GO Listing F4 — Display responsivo. */
			'listing-f4' => array(
				'name'              => 'GO Listing F4',
				'slot'              => go_verge_ads_optional_slot( GO_VERGE_ADS_LISTING_F4_SLOT ),
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1000,
				'near_viewport_max' => 1350,
				'predictive'        => true,
				'safety_ms'         => 500,
				'measurement_tier'  => 'deep',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => '' !== go_verge_ads_optional_slot( GO_VERGE_ADS_LISTING_F4_SLOT ),
			),
			/* GO Listing F5 — Display responsivo. */
			'listing-f5' => array(
				'name'              => 'GO Listing F5',
				'slot'              => go_verge_ads_optional_slot( GO_VERGE_ADS_LISTING_F5_SLOT ),
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1000,
				'near_viewport_max' => 1350,
				'predictive'        => true,
				'safety_ms'         => 500,
				'measurement_tier'  => 'deep',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home', 'single_game', 'single_production', 'single_entity', 'latest', 'category', 'tag', 'search', 'author', 'games_archive', 'productions_archive', 'entities_archive', 'reviews_archive', 'editorial_page' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => '' !== go_verge_ads_optional_slot( GO_VERGE_ADS_LISTING_F5_SLOT ),
			),
			'home-mid' => array(
				'name'              => 'GO Home M1',
				'slot'              => '6795467428',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1000,
				'near_viewport_max' => 1700,
				'predictive'        => true,
				'safety_ms'         => 650,
				'measurement_tier'  => 'premium',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),

			'home-mid-2' => array(
				'name'              => 'GO Home M2',
				'slot'              => '6925750357',
				'sizing'            => 'responsive',
				'format'            => 'auto',
				'full_width'        => true,
				'near_viewport'     => 1000,
				'near_viewport_max' => 1350,
				'predictive'        => true,
				'safety_ms'         => 550,
				'measurement_tier'  => 'premium',
				'requested_size'    => 'responsive-auto full-width',
				'collapse_unfilled' => true,
				'templates'         => array( 'home' ),
				'reserve'           => array( 'mobile' => 0, 'desktop' => 0 ),
				'enabled'           => true,
			),
		),
	);

	/* Public extension point; only the supported production placement keys survive. */
	$config = (array) apply_filters( 'go_verge_ads_config', $config );
	/* One architecture after extension filters; the global kill remains absolute. */
	$config['delivery_mode'] = 'manual_overlays';
	$config['account_formats']['in_page'] = 'off';
	$config['account_formats']['anchor'] = 'on';
	$config['account_formats']['vignette'] = 'on';
	$config['account_formats']['side_rails'] = 'off';
	if ( defined( 'GO_ADS_V3_ENABLED' ) && ! GO_ADS_V3_ENABLED ) { $config['enabled'] = false; }
	$allowed = array_fill_keys( array( 'topscroll', 'site-masthead', 'home-masthead', 'article-hero-overlay', 'game-hub-mid', 'sidebar-desktop', 'article-prime', 'article-a1', 'article-a2', 'article-a3', 'article-a4', 'article-a5', 'article-a6', 'article-end', 'listing-f1', 'listing-f2', 'listing-f3', 'listing-f4', 'listing-f5', 'home-mid', 'home-mid-2' ), true );
	$config['inventory'] = array_intersect_key( (array) ( $config['inventory'] ?? array() ), $allowed );

	return $config;
}

/** @return array<string,array<string,mixed>> */
function go_verge_ads_inventory() {
	$config = go_verge_ads_config();
	return isset( $config['inventory'] ) && is_array( $config['inventory'] ) ? $config['inventory'] : array();
}

/** @return array<string,array<string,mixed>> */
function go_verge_adsense_units() {
	return array_filter(
		go_verge_ads_inventory(),
		static function ( $unit ) {
			return is_array( $unit ) && ! empty( $unit['slot'] ) && ! empty( $unit['enabled'] );
		}
	);
}

/**
 * Every ad unit id this contract can serve, including render-time variants.
 *
 * @return array<string,string> slot id => placement key
 */
function go_verge_ads_all_slots() {
	$out = array();
	foreach ( go_verge_ads_inventory() as $placement => $unit ) {
		$slot = preg_replace( '/\D+/', '', (string) ( $unit['slot'] ?? '' ) );
		if ( '' !== $slot && ! isset( $out[ $slot ] ) ) {
			$out[ $slot ] = $placement;
		}
		foreach ( (array) ( $unit['slot_variants'] ?? array() ) as $slug => $variant ) {
			$variant_slot = preg_replace( '/\D+/', '', (string) ( $variant['slot'] ?? '' ) );
			if ( '' !== $variant_slot && ! isset( $out[ $variant_slot ] ) ) {
				$out[ $variant_slot ] = $placement . ':' . sanitize_key( (string) $slug );
			}
		}
	}
	return $out;
}

/** @return array<string,mixed> */
function go_verge_adsense_unit_config( $placement ) {
	$units = go_verge_adsense_units();
	$unit  = isset( $units[ $placement ] ) && is_array( $units[ $placement ] ) ? $units[ $placement ] : array();
	if ( ! $unit || is_admin() ) {
		return $unit;
	}
	foreach ( (array) ( $unit['slot_variants'] ?? array() ) as $slug => $variant ) {
		if ( ( is_page( $slug ) || is_category( $slug ) ) && ! empty( $variant['slot'] ) ) {
			$unit['slot'] = (string) $variant['slot'];
			$unit['name'] = (string) ( $variant['name'] ?? $unit['name'] );
			break;
		}
	}
	if ( 'site-masthead' === $placement && function_exists( 'go_verge_ads_masthead_excludes_desktop' ) && go_verge_ads_masthead_excludes_desktop() ) {
		$config = go_verge_ads_config();
		$max_viewport = max( 1, absint( $config['breakpoints']['desktop_min'] ?? 1101 ) - 1 );
		$unit['max_viewport'] = empty( $unit['max_viewport'] ) ? $max_viewport : min( absint( $unit['max_viewport'] ), $max_viewport );
	}
	return $unit;
}
