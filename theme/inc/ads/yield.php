<?php
/**
 * Financial diagnostics and historical unit priors.
 *
 * Site-wide estimates include manual placements, official anchor/vignette and
 * residual formats. They describe reported earnings, not the value of the next
 * manual impression. Their classification remains available to administrators
 * through GOAC and explain(), but no longer changes delivery timing or volume.
 *
 * The public contract is one fixed manual policy. The structural planner owns
 * capacity; the runtime uses actual geometry, consent, reader motion and
 * measured provider latency. Seven-day per-unit values can order simultaneously
 * eligible placements; they cannot veto a placement or set an auction floor.
 * No request is refreshed or repeated. No monetary value reaches the browser.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT' ) ) {
	define( 'GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT', 'go_ads_yield_decision_v12' );
}

/* ------------------------------------------------------------------ frontier */

/**
 * The economic reference band for site-wide health classification.
 *
 * Nothing here decides how many ads a page carries. Capacity belongs to
 * `planner.php` (structure) and to the browser's Revenue Governor (session).
 * These numbers answer one question only: is the site as a whole delivering
 * and earning like it has already proven it can?
 *
 * Until 4.6 this function also carried a per-word "article_total" ladder. It
 * had stopped being the authority for anything the moment planner telemetry
 * shipped, but it was still transmitted to the browser and still printed in
 * the dashboard as though it governed inventory. It is gone; the dashboard now
 * shows the planner ladder that actually decides.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_yield_frontier() {
	return (array) apply_filters(
		'go_verge_ads_yield_frontier',
		array(
			/* Analytical reference retained for dashboard continuity. The primary
			 * baseline 13-19/08 included Auto Ads in-page. Later windows differ in
			 * architecture, traffic and content mix. They do not prove a universal
			 * per-page quota or a technical cause/date of the reported regression.
			 * These values never alter the manual delivery policy. */
			'delivery_reference_pv' => 6.60,
			'delivery_reference_min'=> 5.80,
			'delivery_reference_max'=> 7.00,
			/* Rounded historical comparison values, not promised prices, bids or
			 * auction floors. Matching them also depends on audience and demand. */
			'success_page_rpm'      => 4.62,
			'success_irpm'          => 0.59,
			'success_coverage'      => 0.915,
			/* Reference band for the price story only. It never vetoes safe supply. */
			'irpm_healthy'          => 0.59,
			/* Internal low-estimate classification threshold; no delivery veto. */
			'irpm_viable'           => 0.20,
		)
	);
}

/**
 * Site-wide delivery reference used for health classification.
 *
 * A peer median may raise the conservative baseline by at most 0.5 imp/PV.
 * It can never lower the baseline: otherwise a bad release would teach the
 * controller that its own regression is normal. This reference does NOT alter
 * a page's planner target.
 *
 * @param float|null $peer_imp_pv Comparable historical delivery.
 * @return float
 */
function go_verge_ads_yield_delivery_reference( $peer_imp_pv = null ) {
	$frontier = go_verge_ads_yield_frontier();
	$base = (float) $frontier['delivery_reference_pv'];
	$reference = $base;
	$peer = (float) $peer_imp_pv;
	if ( $peer > 0 ) {
		$reference = max( $base, min( $peer, $base + 0.50 ) );
	}
	return go_verge_ads_econ_clamp(
		$reference,
		(float) $frontier['delivery_reference_min'],
		(float) $frontier['delivery_reference_max']
	);
}

/* ------------------------------------------------------------------ regimes */

/**
 * Legacy diagnostic coefficients for one financial regime.
 *
 * Retained for existing dashboard/export consumers. These coefficients no longer
 * control delivery. Public signals always export neutral compatibility values;
 * the browser independently ignores legacy financial multipliers in cached HTML.
 *
 * `floor_scale` is an ANALYSIS reference, not a delivery control. It scales the
 * per-slot value floor shown in the revenue dashboard so an operator can see
 * which units are earning below the site's median opportunity. It has never
 * been able to withhold an impression, and the browser no longer receives it.
 *
 * @return array<string,array<string,mixed>>
 */
function go_verge_ads_yield_regime_policies() {
	return (array) apply_filters(
		'go_verge_ads_yield_regime_policies',
		array(
			/* Reported value above its comparison band; legacy coefficients only. */
			'harvest' => array(
				'supply_bias'     => 1,
				'floor_scale'     => 0.55,
				'tier_lookahead'  => array( 'reach' => 1.18, 'premium' => 1.16, 'standard' => 1.14, 'deep' => 1.10, 'completion' => 1.08 ),
				'pacing_scale'    => 0.70,
			),
			/* Reported delivery below the historical reference, not a page quota. */
			'supply_deficit' => array(
				'supply_bias'     => 1,
				'floor_scale'     => 0.45,
				'tier_lookahead'  => array( 'reach' => 1.18, 'premium' => 1.16, 'standard' => 1.15, 'deep' => 1.12, 'completion' => 1.10 ),
				'pacing_scale'    => 0.65,
			),
			'balanced' => array(
				'supply_bias'     => 0,
				'floor_scale'     => 1.00,
				'tier_lookahead'  => array( 'reach' => 1.06, 'premium' => 1.04, 'standard' => 1.02, 'deep' => 1.00, 'completion' => 1.00 ),
				'pacing_scale'    => 1.00,
			),
			/* Low reported value with delivery at the reference. No live braking. */
			'price_compression' => array(
				'supply_bias'     => 0,
				'floor_scale'     => 1.25,
				'tier_lookahead'  => array( 'reach' => 1.04, 'premium' => 1.02, 'standard' => 1.00, 'deep' => 1.00, 'completion' => 1.00 ),
				'pacing_scale'    => 1.10,
			),
			/* Low matching rate is a diagnostic; its cause needs investigation. */
			'coverage_stress' => array(
				'supply_bias'     => 0,
				'floor_scale'     => 1.40,
				'tier_lookahead'  => array( 'reach' => 1.04, 'premium' => 1.02, 'standard' => 1.02, 'deep' => 1.00, 'completion' => 1.00 ),
				'pacing_scale'    => 1.25,
			),
			/* Very low reported value does not identify the next manual auction. */
			'demand_collapse' => array(
				'supply_bias'     => 0,
				'floor_scale'     => 1.30,
				'tier_lookahead'  => array( 'reach' => 1.02, 'premium' => 1.02, 'standard' => 1.00, 'deep' => 1.00, 'completion' => 1.00 ),
				'pacing_scale'    => 1.15,
			),
			/* Bounded prior for a fresh but small sample. Unavailable, stale and
			 * revised observations receive fully neutral economic controls in
			 * go_verge_ads_yield_decision(), preserving structural base inventory. */
			'unknown' => array(
				'supply_bias'     => 1,
				'floor_scale'     => 0.70,
				'tier_lookahead'  => array( 'reach' => 1.12, 'premium' => 1.10, 'standard' => 1.08, 'deep' => 1.04, 'completion' => 1.02 ),
				'pacing_scale'    => 0.85,
			),
		)
	);
}

/**
 * Clock labels for diagnostics, with one delivery baseline at every hour.
 *
 * The available history does not establish a device/reader-matched benefit
 * from requiring more engagement at night. Keep the existing daytime baseline
 * throughout the day; device-specific minimums and actual latency, reach,
 * density, consent and economic-signal guards remain authoritative.
 * These labels do not describe observed advertiser demand or set a bid floor.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_yield_daypart_priors() {
	return (array) apply_filters(
		'go_verge_ads_yield_daypart_priors',
		array(
			'peak' => array(
				'hours'            => array( 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 ),
				'floor_scale'      => 1.00,
				'lookahead_scale'  => 1.04,
				'engage_scroll_viewports' => 0.07,
				'engage_dwell_ms'  => 1500,
			),
			'shoulder' => array(
				'hours'            => array( 6, 7, 19, 20, 21 ),
				'floor_scale'      => 1.00,
				'lookahead_scale'  => 1.04,
				'engage_scroll_viewports' => 0.07,
				'engage_dwell_ms'  => 1500,
			),
			'guard' => array(
				'hours'            => array( 22, 23, 0, 1, 2, 3, 4, 5 ),
				'floor_scale'      => 1.00,
				'lookahead_scale'  => 1.04,
				'engage_scroll_viewports' => 0.07,
				'engage_dwell_ms'  => 1500,
			),
		)
	);
}

/**
 * Depth priors by arrival context.
 *
 * The browser's reader model needs several pageviews before it says anything,
 * and most sessions on this site are one pageview long — so on the pageviews
 * that matter most, every estimate that consumes a depth prior fell back to a
 * flat 0.5. A reader who opened the article from Discover and one who landed on
 * it from a search result are not the same opportunity, and the engine was
 * treating them identically.
 *
 * These are PRIORS for how far a reader typically travels, expressed as a
 * fraction of the document. They are starting points that measured scroll depth
 * overrides as soon as the reader moves, they are clamped into a narrow band on
 * both sides, and they never open the governor's reserve hosts — that path
 * still requires this reader's own stored history.
 *
 * The browser reduces `document.referrer` to one of these bucket names in RAM
 * and keeps nothing else: no referrer string, no URL, no query, no identifier
 * and no storage, so this needs no consent and creates no reader profile.
 *
 * Tune them against the site's own analytics — a publisher whose social traffic
 * reads deeply should say so here rather than accept these defaults.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_entry_context_priors() {
	return (array) apply_filters(
		'go_verge_ads_entry_context_priors',
		array(
			'enabled' => true,
			/* How much of each bucket's deviation from neutral is applied. Below
			 * 1 the prior is deliberately timid, because it describes a
			 * population and is being applied to one reader. */
			'weight'  => 0.80,
			/* Hard band. Nothing in this table can make a placement look certain
			 * or hopeless before the reader has moved a pixel. */
			'min_prior' => 0.35,
			'max_prior' => 0.72,
			'depth_priors' => array(
				/* Already circulating inside the site: the only bucket whose
				 * engagement this pageview has actually observed. */
				'internal'   => 0.62,
				/* Opened deliberately from a feed, to read that article. */
				'google-app' => 0.60,
				'aggregator' => 0.60,
				/* Answer-seeking: a large share leave as soon as they have it. */
				'search'     => 0.46,
				/* The shortest sessions on most publishers. */
				'social'     => 0.42,
				'direct'     => 0.52,
				'app'        => 0.50,
				'other'      => 0.50,
			),
		)
	);
}

/**
 * Remembered creative height per ad unit.
 *
 * A responsive unit declares one reserve here and Google serves whatever the
 * auction produced. Where those disagree the creative's arrival moves the page:
 * on this site's mobile masthead, 132px reserved against a common 250px
 * creative measured 0.036 CLS above the fold — nearly all of the page's layout
 * shift. Reserving the larger number unconditionally only swaps that for a hole
 * whenever a short creative serves.
 *
 * So the browser remembers, per slot, the height the provider has actually been
 * returning and reserves that next time. It applies ONLY to units that already
 * declare a reserve, only with storage permission, only from filled responses,
 * and only upwards from the declared value — it can make an existing reserved
 * box the right size, never turn an unreserved host into a hole.
 *
 * It changes reservation only: never whether, when or what a unit requests.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_height_memory() {
	return (array) apply_filters(
		'go_verge_ads_height_memory',
		array(
			'enabled'     => true,
			'storage_key' => 'go_ads_slot_height_v1',
			/* Two confirmed fills before the memory is trusted. */
			'min_samples' => 2,
			/* A changed account mix reaches the reservation in a few pageviews. */
			'ema_alpha'   => 0.40,
			/* Ceiling on any reservation this can produce. */
			'max_px'      => 400,
			'ttl_ms'      => 7 * DAY_IN_SECONDS * 1000,
		)
	);
}

/**
 * Core Web Vitals guards the browser runtime applies.
 *
 * `paint_gate_*` defers NON-critical, off-screen placements until the first
 * paint has settled, so an ad request a screen away does not compete with the
 * LCP element for sockets and main thread. Above-the-fold inventory, anything
 * visible and anything the reader is about to reach are never held. It is a
 * deferral with a hard ceiling, not a cancellation: supply is unchanged.
 *
 * `reserve_on_request` lets the runtime claim the creative's expected footprint
 * at request time, while the host is still below the useful viewport, so the
 * creative arrives into space that already exists instead of pushing the
 * article down. Unfilled hosts still collapse to nothing.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_cwv_guards() {
	return (array) apply_filters(
		'go_verge_ads_cwv_guards',
		array(
			/*
			 * DESLIGADO por padrão desde 5.5.2.
			 *
			 * É o único guarda desta versão capaz de ADIAR um pedido, e o único
			 * cujo benefício (LCP) não foi medido no campo deste site. Um
			 * relato de "anúncio não aparece" que eu não consegui reproduzir é
			 * razão suficiente para não deixá-lo ligado sem que o publisher
			 * escolha: o ganho é de milissegundos de LCP, e o risco, por menor
			 * que seja, é de receita.
			 *
			 * Para ligar, depois de confirmar que os anúncios aparecem:
			 *   add_filter( 'go_verge_ads_cwv_guards', function ( $g ) {
			 *       $g['paint_gate'] = true;
			 *       return $g;
			 *   } );
			 */
			'paint_gate'             => false,
			/* Ceiling, not a target: almost every real document releases far
			 * earlier, on the LCP entry or on the reader's first scroll. */
			'paint_gate_max_hold_ms' => 1200,
			/* Room for a later, larger LCP candidate before releasing. */
			'paint_gate_grace_ms'    => 250,
			/* Nothing this close to the fold is ever deferred, whatever its
			 * tier: the reader is about to reach it, and it is not what the
			 * first paint is competing with. */
			'paint_gate_near_vh'     => 0.50,
			'reserve_on_request'     => true,
		)
	);
}

/**
 * The Active View band the browser steers every manual unit toward.
 *
 * AdSense prices an impression on the viewability it predicts for the unit,
 * and that prediction is learned from the unit's own history. A unit that asks
 * for creatives a screen before readers who mostly never arrive earns a low
 * Active View, and then a low price on the impressions readers DO see. The
 * runtime therefore reads each unit's seven-day Active View (synced by the Ads
 * Center, shipped in `decision.slot_viewability`) and shortens the unit's
 * request distance in proportion to how far below `target` it sits:
 *
 *   lead x max( floor, viewability / target )   below the target;
 *   lead x 1                                    inside the band;
 *   lead x healthy_scale                        above target + healthy_margin.
 *
 * Units under `flick_guard_below` also stop asking during a fast flick, even at
 * reach/premium tier. And a reader who travels more than `skim_vh` screens in
 * `skim_window_ms` (pauses included) is skimming: no unit is asked for ahead of
 * them, and one on screen only after they have been still for `skim_settle_ms`. Nothing is removed, refreshed or requested twice; this
 * is timing only, and it converges because a unit that recovers gets its lead
 * back from the next model (refreshed every three hours, ignored after 24h).
 *
 * The target sits in the middle of the 50-70% band the publisher wants. Tune:
 *   add_filter( 'go_verge_ads_viewability_policy', function ( $p ) { $p['target'] = 0.65; return $p; } );
 *
 * @return array<string,mixed>
 */
function go_verge_ads_viewability_policy() {
	$policy = (array) apply_filters(
		'go_verge_ads_viewability_policy',
		array(
			'enabled'           => true,
			'target'            => 0.62,
			'healthy_margin'    => 0.08,
			'healthy_scale'     => 1.08,
			'floor'             => 0.50,
			'flick_guard_below' => 0.45,
			'min_lead_px'       => 140,
			'skim_vh'           => 1.5,
			'skim_window_ms'    => 2500,
			'skim_settle_ms'    => 800,
		)
	);
	return array(
		'enabled'           => ! empty( $policy['enabled'] ),
		'target'            => round( go_verge_ads_econ_clamp( $policy['target'] ?? 0.62, 0.40, 0.85 ), 3 ),
		'healthy_margin'    => round( go_verge_ads_econ_clamp( $policy['healthy_margin'] ?? 0.08, 0, 0.30 ), 3 ),
		'healthy_scale'     => round( go_verge_ads_econ_clamp( $policy['healthy_scale'] ?? 1.08, 1, 1.30 ), 3 ),
		'floor'             => round( go_verge_ads_econ_clamp( $policy['floor'] ?? 0.50, 0.30, 1 ), 3 ),
		'flick_guard_below' => round( go_verge_ads_econ_clamp( $policy['flick_guard_below'] ?? 0.45, 0, 0.85 ), 3 ),
		'min_lead_px'       => (int) go_verge_ads_econ_clamp( $policy['min_lead_px'] ?? 140, 60, 400 ),
		/* 0 turns the skim gate off. */
		'skim_vh'           => round( go_verge_ads_econ_clamp( $policy['skim_vh'] ?? 1.5, 0, 6 ), 3 ),
		'skim_window_ms'    => (int) go_verge_ads_econ_clamp( $policy['skim_window_ms'] ?? 2500, 800, 8000 ),
		'skim_settle_ms'    => (int) go_verge_ads_econ_clamp( $policy['skim_settle_ms'] ?? 800, 0, 2000 ),
	);
}

/**
 * Whether seven-day coverage says requests are not turning into matched
 * requests. Absolute rates, not relative: a comparison against the median only
 * measures dispersion and stays silent when every unit fails together.
 *
 * @param array<string,mixed> $econ Slot economics.
 * @return bool
 */
function go_verge_ads_yield_coverage_stressed( array $econ, $current_coverage = null ) {
	/* Fresh day-to-date coverage is the strongest evidence because it describes
	 * the auction the site is facing NOW. A healthy current match rate must not
	 * be overruled by a weak seven-day unit mix from an older configuration. */
	if ( null !== $current_coverage && is_numeric( $current_coverage ) ) {
		$current_coverage = (float) $current_coverage;
		if ( $current_coverage >= 0.82 ) {
			return false;
		}
		if ( $current_coverage < 0.68 ) {
			return true;
		}
	}

	$cov = array_values( (array) ( $econ['coverage_abs'] ?? array() ) );
	if ( count( $cov ) < 4 ) {
		return false;
	}
	$site = $econ['coverage_site'] ?? null;
	if ( null !== $site && (float) $site < 0.62 ) {
		return true;
	}
	$poor = 0;
	foreach ( $cov as $value ) {
		if ( (float) $value < 0.55 ) {
			$poor++;
		}
	}
	return ( $poor / count( $cov ) ) >= 0.50;
}

/* ------------------------------------------------------------------ decision */

/**
 * Classify reported economic state for administration and compatible exports.
 *
 * Reason codes and legacy coefficients remain auditable. This function is not
 * called by the public page config and does not control the manual runtime.
 *
 * @param bool $force Bypass the transient.
 * @return array<string,mixed>
 */
function go_verge_ads_yield_decision( $force = false ) {
	if ( ! $force ) {
		$cached = get_transient( GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT );
		if ( is_array( $cached ) ) {
			return $cached;
		}
	}

	$frontier = go_verge_ads_yield_frontier();
	$policies = go_verge_ads_yield_regime_policies();
	$econ     = go_verge_ads_econ_slot_economics();
	$day      = go_verge_ads_econ_day_state();

	$reasons    = array();
	$confidence = 'none';

	$window = is_array( $day['window'] ?? null ) ? $day['window'] : null;
	$peers  = is_array( $day['peers'] ?? null ) ? $day['peers'] : null;
	$today  = is_array( $day['day'] ?? null ) ? $day['day'] : array();
	$fresh  = null !== ( $day['freshness_min'] ?? null ) && (int) $day['freshness_min'] <= 55;

	$day_imp_pv   = (float) ( $today['impressions_pv'] ?? 0 );
	$day_irpm     = (float) ( $today['impression_rpm'] ?? 0 );
	$day_page_rpm = (float) ( $today['page_rpm'] ?? 0 );
	$day_pv       = (float) ( $today['page_views'] ?? 0 );
	$day_coverage = isset( $today['coverage'] ) && is_numeric( $today['coverage'] ) ? (float) $today['coverage'] : null;

	$window_revised = $window && ! empty( $window['revised'] );
	$window_usable = $window && ! $window_revised
		&& ( ! array_key_exists( 'price_signal_usable', $window ) || ! empty( $window['price_signal_usable'] ) )
		&& isset( $window['impression_rpm'] ) && is_numeric( $window['impression_rpm'] );
	$win_irpm  = $window_usable ? (float) $window['impression_rpm'] : null;
	$win_pv    = $window ? (float) $window['page_views'] : 0.0;
	$peer_p25  = ( $peers && null !== $peers['impression_rpm_p25'] ) ? (float) $peers['impression_rpm_p25'] : null;
	$peer_p75  = ( $peers && null !== $peers['impression_rpm_p75'] ) ? (float) $peers['impression_rpm_p75'] : null;

	/* ---- 1. What is an impression worth right now? --------------------- */
	$price = null;
	if ( $fresh && null !== $win_irpm && $win_pv >= 120 ) {
		$price = $win_irpm;
		$confidence = $win_pv >= 600 ? 'high' : 'medium';
		$reasons[] = 'marginal-window';
	} elseif ( $fresh && ! $window_revised && $day_irpm > 0 && $day_pv >= 400 ) {
		$price = $day_irpm;
		$confidence = 'day-to-date';
		$reasons[] = 'window-too-small';
	}
	if ( ! $fresh ) { $reasons[] = 'snapshot-stale'; }
	if ( $window_revised ) { $reasons[] = 'window-contains-reporting-revision'; }
	$data_unready = ! $fresh || $window_revised;

	/* ---- 2. Is production materially below its own delivery reference? -- */
	$peer_delivery = ( $peers && null !== ( $peers['impressions_pv'] ?? null ) ) ? (float) $peers['impressions_pv'] : null;
	$required = go_verge_ads_yield_delivery_reference( $peer_delivery );
	$gap = $day_imp_pv > 0 ? $required - $day_imp_pv : null;

	$delivery_bias = 0;
	if ( null !== $gap && ! $data_unready ) {
		if ( $gap >= 1.20 ) {
			$delivery_bias = 2;
			$reasons[] = 'delivery-gap-severe';
		} elseif ( $gap >= 0.40 ) {
			$delivery_bias = 1;
			$reasons[] = 'delivery-gap';
		}
	}

	/* Revenue pressure is deliberately secondary to structural safety. It only
	 * upgrades urgency when the site is materially below its proven Page-RPM
	 * baseline AND current-day coverage says Google is still matching requests.
	 * This closes the old blind spot where the controller knew revenue was weak
	 * but the planner remained static. */
	$success_page_rpm = (float) ( $frontier['success_page_rpm'] ?? 0 );
	$revenue_pressure = 0.0;
	if ( $success_page_rpm > 0 && $day_page_rpm > 0 ) {
		$revenue_pressure = go_verge_ads_econ_clamp( ( $success_page_rpm - $day_page_rpm ) / $success_page_rpm, 0.0, 1.0 );
	}
	if ( ! $data_unready && null !== $gap && $gap >= 0.75 && $revenue_pressure >= 0.20 && null !== $day_coverage && $day_coverage >= 0.86 && $day_pv >= 800 ) {
		$delivery_bias = 2;
		$reasons[] = 'revenue-pressure-with-healthy-coverage';
	}

	/* ---- 3. The price story, which sets floors and timing -------------- */
	$regime = 'unknown';
	if ( null === $price ) {
		$reasons[] = 'no-financial-evidence';
	} else {
		$viable = $price > (float) $frontier['irpm_viable'];
		$hot    = ( null !== $peer_p75 && $price >= $peer_p75 && $price >= (float) $frontier['irpm_healthy'] * 1.05 )
			|| $price >= (float) $frontier['irpm_healthy'] * 1.30;
		$weak   = ( null !== $peer_p25 && $price < $peer_p25 * 0.90 )
			|| $price < (float) $frontier['irpm_healthy'] * 0.80;

		if ( ! $viable ) {
			/* Flooding a dead auction adds impressions worth almost nothing and
			 * spends reading experience to do it. Hold the frontier. */
			$regime = 'demand_collapse';
			$reasons[] = 'impression-value-below-viability-floor';
		} elseif ( $hot ) {
			/* A genuinely hot auction is the clearest economic signal we have.
			 * Harvest it even if delivery is also short; planner live headroom
			 * accepts HARVEST and the delivery-gap reason remains visible. */
			$regime = 'harvest';
			$reasons[] = 'impression-value-above-peer-band';
			if ( $delivery_bias > 0 ) {
				$reasons[] = 'delivery-below-reference';
			}
		} elseif ( $delivery_bias > 0 && ! go_verge_ads_yield_coverage_stressed( $econ, $day_coverage ) ) {
			/* Delivery is short while the auction is still viable. Request every
			 * structurally-safe host sooner and let the live planner expose one
			 * additional safe opportunity when the article proves it exists. */
			$regime = 'supply_deficit';
			$reasons[] = 'delivery-below-reference';
			if ( $weak ) {
				$reasons[] = 'weak-price-does-not-cut-safe-inventory';
			}
		} elseif ( $weak ) {
			$regime = 'price_compression';
			$reasons[] = 'impression-value-below-peer-band';
			$reasons[] = 'delivery-already-meets-requirement';
		} else {
			$regime = 'balanced';
			$reasons[] = 'impression-value-within-peer-band';
		}

		/* Coverage stress is a structural fault and outranks everything except a
		 * dead auction. It is the one state where more requests is not the
		 * answer: Google is already declining most of the ones being made, so
		 * the fix is eligibility, sizing and timing. */
		if ( $viable && go_verge_ads_yield_coverage_stressed( $econ, $day_coverage ) ) {
			$regime = 'coverage_stress';
			$reasons[] = 'requests-not-reaching-matched-requests';
		}
	}

	$policy = isset( $policies[ $regime ] ) ? $policies[ $regime ] : $policies['unknown'];
	if ( 'coverage_stress' === $regime ) {
		/* The gap is real, but volume cannot close it while the match rate is
		 * this low. Do not let the delivery controller push through. */
		$delivery_bias = 0;
	}

	/* ---- 4. Assemble --------------------------------------------------- */
	$supply_bias = max( (int) $policy['supply_bias'], (int) $delivery_bias );
	$floor_scale = (float) $policy['floor_scale'];
	if ( $delivery_bias > 0 && ! in_array( $regime, array( 'coverage_stress', 'demand_collapse' ), true ) ) {
		/* Never be selective while short. Selectivity costs impressions, and a
		 * delivery gap means impressions are exactly what is missing. */
		$floor_scale = min( $floor_scale, 0.60 );
	}

	$decision = array(
		'version'        => '9.0.0-financial-diagnostics',
		'delivery_mode'  => 'manual_fixed',
		'delivery_controls_applied' => false,
		'regime'         => $regime,
		'supply_bias'    => max( 0, min( 2, $supply_bias ) ),
		'floor_scale'    => $floor_scale,
		'tier_lookahead' => (array) $policy['tier_lookahead'],
		'pacing_scale'   => (float) $policy['pacing_scale'],
		'confidence'     => $confidence,
		'fresh'          => (bool) $fresh,
		'price_signal_usable' => null !== $price,
		'window_price_signal_usable' => (bool) ( $fresh && $window_usable && $win_pv >= 120 ),
		'reasons'        => array_values( array_unique( $reasons ) ),
		/* Server-side only. This is a health reference, not a page quota. */
		'delivery_reference_pv'    => round( $required, 2 ),
		/* Kept for admin/backwards compatibility; semantics changed in 4.0. */
		'required_impressions_pv'  => round( $required, 2 ),
		'delivered_impressions_pv' => $day_imp_pv > 0 ? round( $day_imp_pv, 2 ) : null,
		'day_coverage'   => null === $day_coverage ? null : round( $day_coverage, 4 ),
		'revenue_pressure' => round( $revenue_pressure, 4 ),
		'price'          => null === $price ? null : round( $price, 4 ),
		'generated_at'   => time(),
	);

	/*
	 * Confidence damping, asymmetric on purpose.
	 *
	 * Weak evidence is a reason to be less SELECTIVE, never a reason to supply
	 * less. Selectivity on bad data withholds inventory that may well be
	 * earning; supply on bad data costs, at worst, one extra opportunity that
	 * every structural guard still has to approve. So the floor is always pulled
	 * toward neutral, while the supply bias is only capped when there is no
	 * evidence at all.
	 */
	if ( 'none' === $confidence ) {
		$decision['supply_bias'] = min( 1, $decision['supply_bias'] );
		$decision['floor_scale'] = 1.0 + ( $decision['floor_scale'] - 1.0 ) * 0.55;
	} elseif ( 'day-to-date' === $confidence ) {
		/* A fresh cumulative estimate is a weaker, explicitly labelled fallback;
		 * stale or revised windows never qualify for this branch. */
		$decision['floor_scale'] = 1.0 + ( $decision['floor_scale'] - 1.0 ) * 0.70;
	}
	if ( $data_unready ) {
		/* Reporting lag and downward revisions do not tell us that the current
		 * auction is cheap. Keep the structural planner and already eligible base
		 * inventory intact, without acceleration/expansion or braking from invalid
		 * money signals. Diagnostics retain the signed observation on the server. */
		$decision['supply_bias'] = 0;
		$decision['floor_scale'] = 1.0;
		$decision['tier_lookahead'] = array_fill_keys( array( 'reach', 'premium', 'standard', 'deep', 'completion' ), 1.0 );
		$decision['pacing_scale'] = 1.0;
		$decision['reasons'][] = 'reporting-evidence-unready-neutral-delivery';
	}

	set_transient( GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT, $decision, 5 * MINUTE_IN_SECONDS );
	return $decision;
}

/**
 * Fixed public delivery contract plus cached historical unit priors.
 *
 * No intraday store/financial classification is read here. The public page does
 * not need a second REST request to fetch seven-day unit priors already embedded
 * in its HTML. Their timestamp means model generation, not Google's report age.
 * Stale/missing priors become neutral in the runtime without changing inventory.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_yield_public_signal() {
	$econ = go_verge_ads_econ_slot_economics();
	$generated_at = max( 0, (int) ( $econ['generated_at'] ?? 0 ) );
	$model_age = time() - $generated_at;
	$usable = (int) ( $econ['samples'] ?? 0 ) > 0 && $generated_at > 0
		&& $model_age >= -300 && $model_age <= DAY_IN_SECONDS;
	/* The compatibility fields must be neutral even if an old financial decision
	 * remains in a transient. No cached economic regime can affect this export. */
	return array(
		'regime'         => 'manual_fixed',
		'delivery_mode'  => 'manual_fixed',
		'supply_bias'    => 0,
		'tier_lookahead' => array_fill_keys( array( 'reach', 'premium', 'standard', 'deep', 'completion' ), 1.0 ),
		'pacing_scale'   => 1.0,
		'slot_value'     => $usable ? (array) ( $econ['slots'] ?? array() ) : array(),
		'slot_coverage'  => $usable ? (array) ( $econ['coverage'] ?? array() ) : array(),
		'slot_viewability' => $usable ? (array) ( $econ['viewability_abs'] ?? array() ) : array(),
		'tier_value'     => $usable ? (array) ( $econ['tier_value'] ?? array() ) : array(),
		'confidence'     => $usable ? 'historical' : 'none',
		'fresh'          => $usable,
		'freshness_source' => 'unit-model-generation-not-report-capture',
		'model_window'   => (string) ( $econ['window'] ?? '' ),
		'model_samples'  => max( 0, (int) ( $econ['samples'] ?? 0 ) ),
		'model_max_age_seconds' => DAY_IN_SECONDS,
		'model_future_tolerance_seconds' => 300,
		'reasons'        => array( 'fixed-manual-delivery', $usable ? 'historical-unit-priors' : 'unit-priors-unavailable-or-stale' ),
		'generated_at'   => $generated_at,
	);
}

function go_verge_ads_yield_register_rest_route() {
	register_rest_route(
		'go-verge/v1',
		'/yield-regime',
		array(
			'methods'             => 'GET',
			'permission_callback' => '__return_true',
			'callback'            => static function () {
				$response = rest_ensure_response( go_verge_ads_yield_public_signal() );
				if ( $response instanceof WP_REST_Response ) {
					$response->header( 'Cache-Control', 'public, max-age=120, stale-while-revalidate=300' );
				}
				return $response;
			},
		)
	);
}
add_action( 'rest_api_init', 'go_verge_ads_yield_register_rest_route' );

/**
 * Administrator-only explainability payload.
 *
 * This is the one place where the real numbers are visible, and it requires
 * `manage_options`. It exists so a decision can always be audited against the
 * evidence that produced it.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_yield_explain() {
	if ( ! is_user_logged_in() || ! current_user_can( 'manage_options' ) ) {
		return array();
	}
	$decision = go_verge_ads_yield_decision();
	$day      = go_verge_ads_econ_day_state();
	$econ     = go_verge_ads_econ_slot_economics();
	$frontier = go_verge_ads_yield_frontier();

	$delivered = (float) ( $day['day']['impressions_pv'] ?? 0 );
	$price     = (float) ( $day['day']['impression_rpm'] ?? 0 );
	$required  = $decision['required_impressions_pv'] ?? null;
	$headroom  = ( null !== $required && $delivered > 0 && $price > 0 )
		? round( ( (float) $required - $delivered ) * $price, 3 )
		: null;

	return array(
		'decision'  => $decision,
		'day'       => $day,
		'frontier'  => $frontier,
		'economics' => $econ,
		/* "If this day delivered what its own price requires instead of where it
		 * is, Page RPM would be this much higher" — the number that turns a
		 * regime label into an action. */
		'page_rpm_headroom' => $headroom,
	);
}

/* The bundled GO AdSense Center refreshes its cumulative snapshot every 15
 * minutes. Reclassify after that existing job; this adds zero Google API
 * calls. Runs after economics.php (priority 20) has refreshed the day state. */
function go_verge_ads_yield_after_goac_refresh() {
	delete_transient( GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT );
	go_verge_ads_yield_decision( true );

	/* Refresh the slow seven-day slot model a few times a day, on the account's
	 * own clock. 3.88.0 used gmdate() here, so the refresh drifted three hours
	 * away from the São Paulo daypart it was meant to track. */
	$hour = 12;
	if ( class_exists( 'GOAC_API' ) ) {
		try {
			$hour = (int) go_verge_ads_econ_now()->format( 'G' );
		} catch ( Exception $e ) {
			$hour = (int) current_time( 'G' );
		}
	}
	if ( 0 === $hour % 3 ) {
		delete_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT );
		delete_transient( GO_VERGE_ADS_ECON_CURVE_TRANSIENT );
	}
}
add_action( 'goac_quarter_hour_refresh', 'go_verge_ads_yield_after_goac_refresh', 30 );

/**
 * Serialised policy for the browser runtime.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_yield_config() {
	$priors   = go_verge_ads_yield_daypart_priors();

	$dayparts = array();
	$profiles = array();
	foreach ( $priors as $name => $prior ) {
		$dayparts[ $name ] = array_values( array_map( 'absint', (array) ( $prior['hours'] ?? array() ) ) );
		/* Only what the runtime reads. `floor_scale` stays server-side: it scales
		 * the analysis floor in the dashboard and has never reached the browser
		 * as anything but an unused number. */
		$profiles[ $name ] = array(
			'lookahead_scale'         => round( go_verge_ads_econ_clamp( $prior['lookahead_scale'] ?? 1, 1.00, 1.15 ), 3 ),
			'engage_scroll_viewports' => round( go_verge_ads_econ_clamp( $prior['engage_scroll_viewports'] ?? 0.12, 0.04, 0.40 ), 3 ),
			'engage_dwell_ms'         => (int) go_verge_ads_econ_clamp( $prior['engage_dwell_ms'] ?? 2400, 600, 8000 ),
		);
	}

	$config = array(
		'version'  => '9.2.0-viewability-first',
		/* One definition of the reporting clock: dayparts here and calendar
		 * trials in calendar-trials.php must agree on where a day ends. */
		'timezone' => function_exists( 'go_verge_ads_timezone' ) ? go_verge_ads_timezone() : 'America/Sao_Paulo',
		'dayparts' => $dayparts,
		'profiles' => $profiles,
		/*
		 * The one rule table the runtime obeys, split by device.
		 *
		 * It is defined in inc/ads/config.php and transmitted verbatim. There is
		 * deliberately no second copy of any threshold here or in the runtime:
		 * every density, timing and engagement number the browser uses has
		 * exactly one definition, in one file.
		 */
		'rules' => go_verge_ads_delivery_rules(),
		/* Structural quality of a tier, independent of this week's prices. Used
		 * to rank simultaneously eligible candidates, never to veto one. */
		'tier_weights' => array(
			'reach'      => 1.00,
			'premium'    => 0.94,
			'standard'   => 0.80,
			'deep'       => 0.68,
			'completion' => 0.66,
		),
		'auction_signal' => array(
			'min_critical_responses' => 2,
			'strong_fill_rate'       => 0.67,
			'weak_fill_rate'         => 0.34,
			'strong_response_ms'     => 1500,
			'weak_response_ms'       => 2600,
		),
		'reader_model' => array(
			'enabled'     => true,
			'storage_key' => 'go_ads_reader_depth_v1',
			'ema_alpha'   => 0.25,
			'min_pages'   => 3,
		),
		/* One delivery policy: a reached reserve may enter after the structural
		 * gates pass. This describes the runtime; no allocation or opt-in exists. */
		'delivery_v2' => array(
			'reserve_admission' => 'reached',
			'latency_memory' => true,
			'memory_ttl_ms' => 30 * MINUTE_IN_SECONDS * 1000,
			'memory_samples' => 24,
			'max_memory_ms' => 4000,
			'diagnostic_sample_rate' => 0.05,
		),
		/* Arrival-context depth priors; the browser keeps only the bucket name. */
		'entry_context'   => go_verge_ads_entry_context_priors(),
		/* First-paint deferral and request-time reservation. */
		'cwv'             => go_verge_ads_cwv_guards(),
		/* Reserve the height a slot is actually served (see the runtime). */
		'height_memory'   => go_verge_ads_height_memory(),
		/* Per-unit Active View controller (see go_verge_ads_viewability_policy). */
		'viewability'     => go_verge_ads_viewability_policy(),
		/* Which arm of a running calendar trial today belongs to. Identical for
		 * every reader that day; absent when no trial is enabled. */
		'trial'           => function_exists( 'go_verge_ads_trial_public_signal' ) ? go_verge_ads_trial_public_signal() : null,
		'decision'        => go_verge_ads_yield_public_signal(),
	);

	return (array) apply_filters( 'go_verge_ads_yield_config', $config );
}
