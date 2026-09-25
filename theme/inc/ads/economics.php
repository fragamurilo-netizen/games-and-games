<?php
/**
 * Historical unit values and administrative financial diagnostics.
 *
 * Reads data already synced by the bundled GO AdSense Center, without new
 * Google API calls. Seven-day revenue per request includes historical coverage
 * and impression value, and supplies bounded relative weights for ordering
 * eligible manual opportunities. It does not prove the marginal value of the
 * next impression, and it never vetoes one because of a calculated floor.
 *
 * Site-wide daily and intraday estimates remain useful in the administrator
 * dashboard. They include format/audience changes and reporting revisions and
 * no longer control public delivery. An improvement in average impression RPM
 * alone does not establish a revenue gain. Nothing here clicks, refreshes,
 * re-requests, hides a paid creative, inflates counters or touches the auction.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_ADS_ECON_SLOT_TRANSIENT' ) ) {
	define( 'GO_VERGE_ADS_ECON_SLOT_TRANSIENT', 'go_ads_econ_slot_v2' );
}
if ( ! defined( 'GO_VERGE_ADS_ECON_DAY_TRANSIENT' ) ) {
	define( 'GO_VERGE_ADS_ECON_DAY_TRANSIENT', 'go_ads_econ_day_v2' );
}
if ( ! defined( 'GO_VERGE_ADS_ECON_CURVE_TRANSIENT' ) ) {
	define( 'GO_VERGE_ADS_ECON_CURVE_TRANSIENT', 'go_ads_econ_curve_v1' );
}

/* ------------------------------------------------------------------ statistics */

/**
 * Median of a numeric list. Non-finite values are dropped rather than
 * poisoning the result.
 *
 * @param array<int,mixed> $values Values.
 * @return float|null
 */
function go_verge_ads_econ_median( $values ) {
	$values = array_values( array_filter( array_map( 'floatval', (array) $values ), 'is_finite' ) );
	if ( ! $values ) {
		return null;
	}
	sort( $values, SORT_NUMERIC );
	$n = count( $values );
	$i = (int) floor( $n / 2 );
	return $n % 2 ? (float) $values[ $i ] : ( (float) $values[ $i - 1 ] + (float) $values[ $i ] ) / 2;
}

/**
 * Percentile with linear interpolation. Used for the marginal floor and for
 * the "is this hour unusually good/bad" bands.
 *
 * @param array<int,mixed> $values Values.
 * @param float            $p      Percentile in 0..1.
 * @return float|null
 */
function go_verge_ads_econ_percentile( $values, $p ) {
	$values = array_values( array_filter( array_map( 'floatval', (array) $values ), 'is_finite' ) );
	if ( ! $values ) {
		return null;
	}
	sort( $values, SORT_NUMERIC );
	$p = max( 0.0, min( 1.0, (float) $p ) );
	$pos = $p * ( count( $values ) - 1 );
	$low = (int) floor( $pos );
	$high = (int) ceil( $pos );
	if ( $low === $high ) {
		return (float) $values[ $low ];
	}
	return (float) $values[ $low ] + ( (float) $values[ $high ] - (float) $values[ $low ] ) * ( $pos - $low );
}

/**
 * Empirical-Bayes shrinkage toward a prior.
 *
 * A slot with 200 requests must not outrank a slot with 40,000 requests because
 * of one lucky day. `$k` is the sample size at which the observation carries
 * half the weight.
 *
 * @param float $observed Observed value.
 * @param float $prior    Prior (tier or global mean).
 * @param float $n        Sample size.
 * @param float $k        Half-weight sample size.
 * @return float
 */
function go_verge_ads_econ_shrink( $observed, $prior, $n, $k ) {
	$n = max( 0.0, (float) $n );
	$k = max( 1.0, (float) $k );
	$w = $n / ( $n + $k );
	return (float) $prior + ( (float) $observed - (float) $prior ) * $w;
}

/** Clamp helper shared by every bounded multiplier in this module. */
function go_verge_ads_econ_clamp( $value, $min, $max ) {
	$value = (float) $value;
	if ( ! is_finite( $value ) ) {
		return (float) $min;
	}
	return max( (float) $min, min( (float) $max, $value ) );
}

/**
 * The account's current instant, on the account's own clock.
 *
 * Everything below is clock-relative: snapshot freshness, the marginal window,
 * the peer band and the seven-day range all measure against this minute. Reading
 * `now` directly in three places made that layer untestable — a scenario built
 * around "the last sync was six hours ago" only behaves that way if the suite
 * happens to run after 07:00 in São Paulo. The filter exists so a test can pin
 * the minute; production never registers it.
 */
function go_verge_ads_econ_now() {
	$now      = new DateTimeImmutable( 'now', GOAC_API::tz() );
	$filtered = apply_filters( 'go_verge_ads_econ_now', $now );
	return $filtered instanceof DateTimeImmutable ? $filtered : $now;
}

/* ------------------------------------------------------------------ slot economics */

/**
 * Declared tier for a slot id, from the inventory contract.
 *
 * @return array<string,string> slot id => measurement tier
 */
function go_verge_ads_econ_slot_tiers() {
	$out = array();
	if ( ! function_exists( 'go_verge_ads_inventory' ) ) {
		return $out;
	}
	$rank = array( 'reach' => 5, 'premium' => 4, 'standard' => 3, 'deep' => 2, 'completion' => 1 );
	foreach ( go_verge_ads_inventory() as $unit ) {
		$tier = sanitize_key( (string) ( $unit['measurement_tier'] ?? 'standard' ) );
		/* Every id this unit can serve, including the vertical-specific variants
		 * the renderer swaps in. Leaving those out meant two of this account's
		 * twenty ad units never entered the economic model at all. */
		$slots = array( preg_replace( '/\D+/', '', (string) ( $unit['slot'] ?? '' ) ) );
		foreach ( (array) ( $unit['slot_variants'] ?? array() ) as $variant ) {
			$slots[] = preg_replace( '/\D+/', '', (string) ( $variant['slot'] ?? '' ) );
		}
		foreach ( $slots as $slot ) {
			if ( '' === $slot ) {
				continue;
			}
			/* Several placements may legitimately share one ad unit (the masthead
			 * is the same unit on home and on internals). The strongest declared
			 * tier wins so a shared unit is never judged by its weakest surface. */
			if ( ! isset( $out[ $slot ] ) || ( $rank[ $tier ] ?? 0 ) > ( $rank[ $out[ $slot ] ] ?? 0 ) ) {
				$out[ $slot ] = $tier;
			}
		}
	}
	return $out;
}

/**
 * Seven-day per-slot economics from the Data Lab's AD_UNIT_ID rows.
 *
 * Returned weights are relative, bounded and money-free: the browser learns
 * that A5 is worth ~0.6 of a median opportunity, never that it made US$0.19.
 *
 * @param bool $force Bypass the transient.
 * @return array<string,mixed>
 */
function go_verge_ads_econ_slot_economics( $force = false ) {
	if ( ! $force ) {
		$cached = get_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT );
		if ( is_array( $cached ) ) {
			return $cached;
		}
	}

	$empty = array(
		'slots'         => array(),
		'coverage'      => array(),
		'coverage_abs'  => array(),
		'viewability_abs' => array(),
		'viewability_aggregation' => 'reconstructed_measurable_impression_weighted_available_rows',
		'coverage_site' => null,
		'quality_risk'  => array(),
		'tier_value'    => array(),
		'floor'         => 0.0,
		'samples'       => 0,
		'window'        => '',
		'generated_at'  => time(),
	);

	if ( ! class_exists( 'GOAC_API' ) || ! class_exists( 'GOAC_Learning' ) || ! GOAC_API::is_connected() ) {
		set_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT, $empty, HOUR_IN_SECONDS );
		return $empty;
	}

	global $wpdb;
	$table   = GOAC_Learning::table_rows();
	$account = GOAC_Learning::account_key();
	$today   = go_verge_ads_econ_now();
	$to      = $today->modify( '-1 day' )->format( 'Y-m-d' );
	$from    = $today->modify( '-7 days' )->format( 'Y-m-d' );

	$sql = "SELECT dimensions_json,
		SUM(earnings) earnings,
		SUM(impressions) impressions,
		SUM(ad_requests) ad_requests,
		SUM(matched_requests) matched_requests,
		SUM(clicks) clicks,
		SUM(CASE WHEN viewability BETWEEN 0 AND 1 AND measurability BETWEEN 0 AND 1 AND impressions > 0 THEN viewability * measurability * impressions ELSE 0 END) viewability_weighted,
		SUM(CASE WHEN viewability BETWEEN 0 AND 1 AND measurability BETWEEN 0 AND 1 AND impressions > 0 THEN measurability * impressions ELSE 0 END) viewability_impressions
		FROM {$table}
		WHERE account_key=%s AND report_key='ad_unit' AND bucket=0 AND day BETWEEN %s AND %s
		GROUP BY value_hash";
	$rows = $wpdb->get_results( $wpdb->prepare( $sql, $account, $from, $to ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery

	$tiers = go_verge_ads_econ_slot_tiers();
	$raw   = array();
	foreach ( (array) $rows as $row ) {
		$dims = json_decode( (string) ( $row['dimensions_json'] ?? '' ), true );
		$id   = is_array( $dims ) ? (string) ( $dims['AD_UNIT_ID'] ?? '' ) : '';
		if ( ! preg_match( '/(\d{6,})$/', $id, $m ) ) {
			continue;
		}
		$slot = $m[1];
		if ( ! isset( $tiers[ $slot ] ) ) {
			/* Not part of the current publisher contract (retired unit, or an
			 * account-level overlay). Overlays are deliberately excluded: their
			 * economics are excellent and would distort the in-page floor. */
			continue;
		}
		$requests = (float) ( $row['ad_requests'] ?? 0 );
		$impressions = (float) ( $row['impressions'] ?? 0 );
		$matched  = (float) ( $row['matched_requests'] ?? 0 );
		$earnings = (float) ( $row['earnings'] ?? 0 );
		$clicks   = (float) ( $row['clicks'] ?? 0 );
		/* AFC unit rows: reconstruct the measurable denominator from the same
		 * row's measurability and impressions. The stored rates are rounded, so
		 * this remains a reconstruction, not Google's native period aggregate.
		 * Missing measurability is not an implicit 100% measurement rate. */
		$view_imps = (float) ( $row['viewability_impressions'] ?? 0 );
		/* A unit needs a real week to be judged. Below this it inherits its tier
		 * prior instead of being excluded — exclusion was silently treating new
		 * inventory as exactly median, which is not what the data says. */
		if ( $requests < 60 || $earnings < 0 ) {
			continue;
		}
		$raw[ $slot ] = array(
			'tier'        => $tiers[ $slot ],
			/* Revenue per thousand REQUESTS is the marginal value of an
			 * opportunity: it already contains fill, coverage and price. */
			'request_rpm' => $requests > 0 ? $earnings / $requests * 1000 : 0.0,
			'irpm'        => $impressions > 0 ? $earnings / $impressions * 1000 : 0.0,
			'coverage'    => $requests > 0 ? $matched / $requests : null,
			'ctr'         => $impressions > 0 ? $clicks / $impressions : null,
			'viewability' => $view_imps > 0 ? (float) ( $row['viewability_weighted'] ?? 0 ) / $view_imps : null,
			'requests'    => $requests,
			'impressions' => $impressions,
			'clicks'      => $clicks,
		);
	}

	if ( count( $raw ) < 3 ) {
		$empty['window'] = $from . '..' . $to;
		set_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT, $empty, HOUR_IN_SECONDS );
		return $empty;
	}

	/* Request-weighted global mean is the honest prior: it is what an average
	 * opportunity on this site actually earned last week. */
	$total_earn = 0.0;
	$total_req  = 0.0;
	foreach ( $raw as $row ) {
		$total_earn += $row['request_rpm'] * $row['requests'] / 1000;
		$total_req  += $row['requests'];
	}
	$global_rpm_request = $total_req > 0 ? $total_earn / $total_req * 1000 : 0.0;
	if ( $global_rpm_request <= 0 ) {
		$empty['window'] = $from . '..' . $to;
		set_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT, $empty, HOUR_IN_SECONDS );
		return $empty;
	}

	/* Tier priors, so a low-volume deep slot is compared with deep slots and not
	 * with the masthead. */
	$tier_earn = array();
	$tier_req  = array();
	foreach ( $raw as $row ) {
		$tier = $row['tier'];
		$tier_earn[ $tier ] = ( $tier_earn[ $tier ] ?? 0 ) + $row['request_rpm'] * $row['requests'] / 1000;
		$tier_req[ $tier ]  = ( $tier_req[ $tier ] ?? 0 ) + $row['requests'];
	}
	$tier_prior = array();
	foreach ( $tier_req as $tier => $req ) {
		$value = $req > 0 ? $tier_earn[ $tier ] / $req * 1000 : $global_rpm_request;
		/* A whole tier can also be thin. Shrink the tier toward the site. */
		$tier_prior[ $tier ] = go_verge_ads_econ_shrink( $value, $global_rpm_request, $req, 4000 );
	}

	$median_cov  = go_verge_ads_econ_median( array_filter( array_column( $raw, 'coverage' ), 'is_numeric' ) );
	$median_view = go_verge_ads_econ_median( array_filter( array_column( $raw, 'viewability' ), 'is_numeric' ) );
	$median_ctr  = go_verge_ads_econ_median( array_filter( array_column( $raw, 'ctr' ), 'is_numeric' ) );

	$slots        = array();
	$coverage     = array();
	$coverage_abs = array();
	$viewability_abs = array();
	$quality      = array();
	$relatives    = array();
	$matched_sum  = 0.0;
	$request_sum  = 0.0;
	foreach ( $raw as $slot => $row ) {
		$own_earnings = $row['request_rpm'] * $row['requests'] / 1000;

		/*
		 * Leave-one-out priors.
		 *
		 * A slot must never be shrunk toward a prior that contains itself. A tier
		 * holding a single low-volume unit would otherwise BE that unit's prior,
		 * so the shrinkage would pull the observation toward the observation and
		 * do nothing at all — the exact shape that let a 120-request unit with one
		 * expensive click outrank Top Scroll.
		 */
		$loo_requests = $total_req - $row['requests'];
		$loo_earnings = $total_earn - $own_earnings;
		$site_prior = $loo_requests > 500 ? $loo_earnings / $loo_requests * 1000 : $global_rpm_request;

		$tier_requests_loo = (float) ( $tier_req[ $row['tier'] ] ?? 0 ) - $row['requests'];
		$tier_earnings_loo = (float) ( $tier_earn[ $row['tier'] ] ?? 0 ) - $own_earnings;
		$prior = $tier_requests_loo >= 2000
			? go_verge_ads_econ_shrink( $tier_earnings_loo / $tier_requests_loo * 1000, $site_prior, $tier_requests_loo, 4000 )
			: $site_prior;

		/* Winsorize before shrinking. A unit with a few hundred requests that
		 * caught one expensive click is not a sixteen-times placement, and no
		 * sane shrinkage weight fully absorbs an outlier of that magnitude. */
		$observed = go_verge_ads_econ_clamp( $row['request_rpm'], $global_rpm_request * 0.15, $global_rpm_request * 3.0 );

		/* Half weight at 3,000 requests: roughly a week of a mid-body unit. */
		$shrunk = go_verge_ads_econ_shrink( $observed, $prior, $row['requests'], 3000 );
		$relative = $global_rpm_request > 0 ? $shrunk / $global_rpm_request : 1.0;
		$relative = go_verge_ads_econ_clamp( $relative, 0.25, 2.60 );
		$relatives[ $slot ] = $relative;

		$cov = ( null !== $median_cov && $median_cov > 0 && null !== $row['coverage'] )
			? go_verge_ads_econ_clamp( $row['coverage'] / $median_cov, 0.70, 1.20 ) : 1.0;
		$coverage[ $slot ] = round( $cov, 3 );
		if ( null !== $row['coverage'] ) {
			/* Relative coverage measures dispersion; only the ABSOLUTE rate says
			 * whether requests are actually turning into matched requests, which
			 * is what coverage stress means. */
			$coverage_abs[ $slot ] = round( (float) $row['coverage'], 4 );
			$matched_sum += (float) $row['coverage'] * $row['requests'];
			$request_sum += $row['requests'];
		}
		if ( null !== $row['viewability'] ) {
			/* Absolute Active View history is timing information, not a supply
			 * veto. The browser may prepare a historically weak slot a little
			 * earlier so the creative is rendered by the time the reader arrives. */
			$viewability_abs[ $slot ] = round( (float) $row['viewability'], 4 );
		}

		/* Click quality is a SAFETY signal, never an objective. A placement whose
		 * CTR is far above the site while its revenue/request is not is the
		 * classic accidental-click shape; it is flagged so the engine stops
		 * widening it, and the geometry is reviewed. */
		$risk = 0;
		if ( null !== $median_ctr && $median_ctr > 0 && null !== $row['ctr'] && $row['impressions'] >= 500 ) {
			$ctr_rel = $row['ctr'] / $median_ctr;
			if ( $ctr_rel >= 2.2 && $relative <= 1.05 ) {
				$risk = 1;
			}
		}
		if ( $risk ) {
			$quality[ $slot ] = 1;
		}

		$slots[ $slot ] = round( $relative, 3 );
	}

	/* Analytical comparison marker: the 10th percentile of relative request
	 * values, scaled below the weakest observed unit. It is shown only in server
	 * diagnostics; no delivery gate or Google auction reads this number. */
	$floor = go_verge_ads_econ_percentile( array_values( $relatives ), 0.10 );
	$floor = null === $floor ? 0.0 : go_verge_ads_econ_clamp( $floor * 0.55, 0.0, 0.35 );

	$out = array(
		'slots'        => $slots,
		'coverage'     => $coverage,
		'coverage_abs' => $coverage_abs,
		'viewability_abs' => $viewability_abs,
		'viewability_aggregation' => 'reconstructed_measurable_impression_weighted_available_rows',
		'coverage_site' => $request_sum > 0 ? round( $matched_sum / $request_sum, 4 ) : null,
		'quality_risk' => $quality,
		'tier_value' => array_map(
			static function ( $v ) use ( $global_rpm_request ) {
				return round( go_verge_ads_econ_clamp( $global_rpm_request > 0 ? $v / $global_rpm_request : 1, 0.35, 2.2 ), 3 );
			},
			$tier_prior
		),
		'floor'      => round( (float) $floor, 3 ),
		'samples'    => count( $slots ),
		'window'     => $from . '..' . $to,
		'generated_at' => time(),
	);
	set_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT, $out, 3 * HOUR_IN_SECONDS );
	return $out;
}

/* ------------------------------------------------------------------ day shape */

/**
 * Cumulative intraday points for one date, normalised and ordered.
 *
 * @param array<string,mixed> $intraday GOAC intraday store.
 * @param string              $date     Y-m-d.
 * @return array<int,array<int,float>>
 */
function go_verge_ads_econ_points( array $intraday, $date ) {
	$points = isset( $intraday[ $date ] ) ? array_values( array_filter( (array) $intraday[ $date ], 'is_array' ) ) : array();
	usort(
		$points,
		static function ( $a, $b ) {
			return (int) ( $a[0] ?? 0 ) <=> (int) ( $b[0] ?? 0 );
		}
	);
	return $points;
}

/**
 * Economics of the interval between two cumulative snapshots.
 *
 * A downward revision of cumulative earnings or volume is an accounting observation, not
 * a zero-price auction. Preserve its signed delta for diagnosis, but do not
 * publish a marginal RPM from a window containing that revision. Even valid
 * windows describe changes in reported estimates, not a real-time bid price.
 *
 * @return array<string,mixed>|null
 */
function go_verge_ads_econ_interval( $start, $end, $minutes ) {
	if ( ! is_array( $start ) || ! is_array( $end ) ) {
		return null;
	}
	$earnings    = (float) ( $end['earnings'] ?? 0 ) - (float) ( $start['earnings'] ?? 0 );
	$page_views  = (float) ( $end['page_views'] ?? 0 ) - (float) ( $start['page_views'] ?? 0 );
	$impressions = (float) ( $end['impressions'] ?? 0 ) - (float) ( $start['impressions'] ?? 0 );
	$clicks      = (float) ( $end['clicks'] ?? 0 ) - (float) ( $start['clicks'] ?? 0 );
	$revised     = $earnings < 0 || $page_views < 0 || $impressions < 0;
	$has_volume  = $page_views >= 1 && $impressions >= 1;
	$usable      = ! $revised && $has_volume;
	/* Retain empty-denominator observations as diagnostics. Dropping them here
	 * hid accounting revisions from window() and allowed yield to fall back to
	 * the revised day total as if the recent window merely had too few readers.
	 * Keeping a non-actionable sample also lets window() detect an intermediate
	 * correction even when its final volume delta returns to zero. */
	return array(
		'minutes'        => max( 1, (float) $minutes ),
		'earnings'       => $earnings,
		'page_views'     => max( 0.0, $page_views ),
		'impressions'    => max( 0.0, $impressions ),
		'page_views_delta' => $page_views,
		'impressions_delta' => $impressions,
		'clicks'         => max( 0.0, $clicks ),
		'clicks_delta'   => $clicks,
		'revised'        => $revised,
		'price_signal_usable' => $usable,
		'price_signal_reason' => $revised ? ( $earnings < 0 ? 'cumulative-earnings-revision' : 'cumulative-volume-revision' ) : ( $has_volume ? 'reported-estimate-difference' : 'insufficient-interval-volume' ),
		'page_rpm'       => $usable ? $earnings / $page_views * 1000 : null,
		'impression_rpm' => $usable ? $earnings / $impressions * 1000 : null,
		'impressions_pv' => $page_views > 0 ? $impressions / $page_views : 0.0,
	);
}

/**
 * Marginal window for one date ending at a minute-of-day.
 *
 * @return array<string,mixed>|null
 */
function go_verge_ads_econ_window( array $intraday, $date, $end_minute, $window = 60 ) {
	if ( ! class_exists( 'GOAC_Store' ) ) {
		return null;
	}
	$end_minute = max( 0, min( 1439, (int) $end_minute ) );
	if ( $end_minute < 40 ) {
		return null;
	}
	$start_minute = max( 0, $end_minute - (int) $window );
	$start = GOAC_Store::intraday_at( $intraday, $date, $start_minute );
	$end   = GOAC_Store::intraday_at( $intraday, $date, $end_minute );
	$sample = go_verge_ads_econ_interval( $start, $end, $end_minute - $start_minute );
	$source_revised = false;
	/* A correction inside the window can be hidden by later positive growth.
	 * Inspect the source segments contributing to the interpolated endpoints as
	 * well as the net delta, so that peer bands cannot learn a revised sample. */
	$points = go_verge_ads_econ_points( $intraday, $date );
	for ( $i = 1, $n = count( $points ); $i < $n; $i++ ) {
		$prev = $points[ $i - 1 ];
		$next = $points[ $i ];
		if ( (int) $next[0] <= $start_minute || (int) $prev[0] >= $end_minute ) { continue; }
		if ( (float) $next[1] < (float) $prev[1] || (float) $next[2] < (float) $prev[2] || (float) $next[3] < (float) $prev[3] ) {
			$source_revised = true;
			break;
		}
	}
	if ( $source_revised ) {
		if ( ! $sample ) {
			/* A telemetry gap can make an endpoint unavailable while the newest
			 * source snapshots still prove a correction. Preserve that evidence;
			 * the interval's deltas are unknown, never invented from a zero base. */
			$sample = array(
				'minutes' => max( 1, $end_minute - $start_minute ),
				'earnings' => null, 'page_views' => null, 'impressions' => null,
				'page_views_delta' => null, 'impressions_delta' => null,
				'clicks' => null, 'clicks_delta' => null, 'impressions_pv' => null,
			);
		}
		$sample['revised'] = true;
		$sample['price_signal_usable'] = false;
		$sample['price_signal_reason'] = 'cumulative-metric-revision-in-window';
		$sample['page_rpm'] = null;
		$sample['impression_rpm'] = null;
	}
	return $sample;
}

/**
 * Peer windows for the same minute-of-day on comparable past days.
 *
 * Hierarchical fallback: same weekday -> same weekend/weekday class -> every
 * complete day in the store. Small samples never win authority.
 *
 * @return array<int,array<string,mixed>>
 */
function go_verge_ads_econ_peers( array $intraday, $today, $end_minute, DateTimeImmutable $now, $window = 60 ) {
	$weekday = (int) $now->format( 'w' );
	$weekend = in_array( $weekday, array( 0, 6 ), true );
	$cutoff  = $now->modify( '-30 days' )->format( 'Y-m-d' );
	$exact = array();
	$class = array();
	$all   = array();

	foreach ( array_keys( $intraday ) as $date ) {
		$date = (string) $date;
		if ( $date >= $today || $date < $cutoff ) {
			continue;
		}
		try {
			$day = (int) ( new DateTimeImmutable( $date, $now->getTimezone() ) )->format( 'w' );
		} catch ( Exception $e ) {
			continue;
		}
		$sample = go_verge_ads_econ_window( $intraday, $date, $end_minute, $window );
		if ( ! $sample || empty( $sample['price_signal_usable'] ) || $sample['page_views'] < 80 || $sample['impressions'] < 250 ) {
			continue;
		}
		$all[] = $sample;
		if ( in_array( $day, array( 0, 6 ), true ) === $weekend ) {
			$class[] = $sample;
		}
		if ( $day === $weekday ) {
			$exact[] = $sample;
		}
	}

	/*
	 * The thresholds here must clear the minimum the CALLER needs, which is
	 * three samples. Returning a two-sample same-weekday set satisfied this
	 * function and was then thrown away by the caller, so the whole peer band
	 * vanished — silently, and exactly when the store is young or has just been
	 * reset, which is when a sane band matters most. Prefer the same weekday
	 * only when it can stand on its own.
	 */
	if ( count( $exact ) >= 3 ) {
		return $exact;
	}
	if ( count( $class ) >= 3 ) {
		return $class;
	}
	return $all;
}

/**
 * Learned share-of-day curve for the current weekday class.
 *
 * Used for end-of-day nowcasting and for pacing: "by 21:00 a Sunday normally
 * has 78% of its pageviews and 74% of its revenue". This is what lets the
 * engine notice at 15:00 that the day is heading for US$2.50 instead of
 * discovering it at midnight.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_econ_day_curve( $force = false ) {
	if ( ! $force ) {
		$cached = get_transient( GO_VERGE_ADS_ECON_CURVE_TRANSIENT );
		if ( is_array( $cached ) ) {
			return $cached;
		}
	}
	$empty = array( 'pv' => array(), 'earnings' => array(), 'impressions' => array(), 'days' => 0, 'generated_at' => time() );
	if ( ! class_exists( 'GOAC_Store' ) || ! class_exists( 'GOAC_API' ) ) {
		set_transient( GO_VERGE_ADS_ECON_CURVE_TRANSIENT, $empty, HOUR_IN_SECONDS );
		return $empty;
	}

	$intraday = GOAC_Store::intraday();
	$today    = GOAC_API::today();
	$now      = go_verge_ads_econ_now();
	$weekend  = in_array( (int) $now->format( 'w' ), array( 0, 6 ), true );

	$pv_shares   = array();
	$earn_shares = array();
	$imp_shares  = array();
	$days        = 0;

	foreach ( array_keys( $intraday ) as $date ) {
		$date = (string) $date;
		if ( $date >= $today ) {
			continue;
		}
		try {
			$day_weekend = in_array( (int) ( new DateTimeImmutable( $date, $now->getTimezone() ) )->format( 'w' ), array( 0, 6 ), true );
		} catch ( Exception $e ) {
			continue;
		}
		if ( $day_weekend !== $weekend ) {
			continue;
		}
		$points = go_verge_ads_econ_points( $intraday, $date );
		if ( count( $points ) < 24 ) {
			continue;
		}
		$last = end( $points );
		$total_pv = (float) ( $last[2] ?? 0 );
		$total_earn = (float) ( $last[1] ?? 0 );
		$total_imp = (float) ( $last[3] ?? 0 );
		/* A day that never reached a realistic close is not a shape to learn. */
		if ( $total_pv < 3000 || $total_earn <= 0 || (int) ( $last[0] ?? 0 ) < 1320 ) {
			continue;
		}
		$days++;
		foreach ( $points as $point ) {
			$bucket = (int) floor( max( 0, min( 1439, (int) ( $point[0] ?? 0 ) ) ) / 30 );
			$pv_shares[ $bucket ][]   = (float) ( $point[2] ?? 0 ) / $total_pv;
			$earn_shares[ $bucket ][] = (float) ( $point[1] ?? 0 ) / $total_earn;
			if ( $total_imp > 0 ) {
				$imp_shares[ $bucket ][] = (float) ( $point[3] ?? 0 ) / $total_imp;
			}
		}
	}

	if ( $days < 2 ) {
		set_transient( GO_VERGE_ADS_ECON_CURVE_TRANSIENT, $empty, HOUR_IN_SECONDS );
		return $empty;
	}

	$reduce = static function ( $buckets ) {
		$out = array();
		foreach ( $buckets as $bucket => $values ) {
			$median = go_verge_ads_econ_median( $values );
			if ( null !== $median ) {
				$out[ (int) $bucket ] = round( go_verge_ads_econ_clamp( $median, 0.0, 1.0 ), 4 );
			}
		}
		ksort( $out );
		/* Cumulative shares must be monotonic; interpolation noise is smoothed. */
		$running = 0.0;
		foreach ( $out as $bucket => $value ) {
			$running = max( $running, $value );
			$out[ $bucket ] = $running;
		}
		return $out;
	};

	$out = array(
		'pv'          => $reduce( $pv_shares ),
		'earnings'    => $reduce( $earn_shares ),
		'impressions' => $reduce( $imp_shares ),
		'days'        => $days,
		'generated_at' => time(),
	);
	set_transient( GO_VERGE_ADS_ECON_CURVE_TRANSIENT, $out, 6 * HOUR_IN_SECONDS );
	return $out;
}

/**
 * Today's economic state: what has happened, what the marginal hour looks
 * like, whether the day is ahead or behind its own learned shape, and what it
 * closes at if nothing changes.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_econ_day_state( $force = false ) {
	if ( ! $force ) {
		$cached = get_transient( GO_VERGE_ADS_ECON_DAY_TRANSIENT );
		if ( is_array( $cached ) ) {
			return $cached;
		}
	}

	$state = array(
		'available'      => false,
		'minute'         => 0,
		'freshness_min'  => null,
		'day'            => array( 'earnings' => 0.0, 'page_views' => 0.0, 'impressions' => 0.0, 'clicks' => 0.0, 'ad_requests' => 0.0, 'matched_requests' => 0.0, 'coverage' => null, 'requests_pv' => 0.0, 'matched_pv' => 0.0, 'page_rpm' => 0.0, 'impression_rpm' => 0.0, 'impressions_pv' => 0.0 ),
		'window'         => null,
		'peers'          => null,
		'pace'           => null,
		'projection'     => null,
		'readiness'      => array(
			'providers_available' => false, 'today_points' => 0, 'intraday_days_observed' => 0,
			'peer_windows_usable' => 0, 'curve_days' => 0,
			'freshness_source' => 'snapshot-capture-time-not-google-event-time',
			'marginal_source' => 'cumulative-estimate-differences-with-interpolation',
		),
		'generated_at'   => time(),
	);

	if ( ! class_exists( 'GOAC_API' ) || ! class_exists( 'GOAC_Store' ) ) {
		set_transient( GO_VERGE_ADS_ECON_DAY_TRANSIENT, $state, 5 * MINUTE_IN_SECONDS );
		return $state;
	}

	$intraday = GOAC_Store::intraday();
	$state['readiness']['providers_available'] = true;
	$state['readiness']['intraday_days_observed'] = count( array_filter( $intraday, static function ( $rows ) { return is_array( $rows ) && count( $rows ) >= 2; } ) );
	$today    = GOAC_API::today();
	$now      = go_verge_ads_econ_now();
	$now_minute = (int) $now->format( 'G' ) * 60 + (int) $now->format( 'i' );
	$points   = go_verge_ads_econ_points( $intraday, $today );
	$state['minute'] = $now_minute;
	$state['readiness']['today_points'] = count( $points );

	if ( count( $points ) < 2 ) {
		set_transient( GO_VERGE_ADS_ECON_DAY_TRANSIENT, $state, 5 * MINUTE_IN_SECONDS );
		return $state;
	}

	$last       = end( $points );
	$end_minute = max( 0, min( 1439, (int) ( $last[0] ?? 0 ) ) );
	$state['freshness_min'] = max( 0, $now_minute - $end_minute );

	$earnings    = (float) ( $last[1] ?? 0 );
	$page_views  = (float) ( $last[2] ?? 0 );
	$impressions = (float) ( $last[3] ?? 0 );
	$clicks      = (float) ( $last[4] ?? 0 );

	/* The daily store already contains ad requests and matched requests from the
	 * same AdSense sync that generated the intraday point. Read those two fields
	 * directly so the revenue controller can distinguish "not enough supply"
	 * from "Google is declining the requests" on the CURRENT day, instead of
	 * relying only on a seven-day unit average. This is read-only and adds zero
	 * Google API calls. */
	$ad_requests = 0.0;
	$matched_requests = 0.0;
	/* The bundled AdSense Center implements range(), but keep compatibility with
	 * an older external Center taking precedence during a rolling deploy. The
	 * controller simply loses the live-coverage signal until that dependency is
	 * upgraded; revenue delivery must never fatal because telemetry is older. */
	if ( method_exists( 'GOAC_Store', 'range' ) ) {
		$today_rows = GOAC_Store::range( $today, $today );
		if ( isset( $today_rows[ $today ] ) && is_array( $today_rows[ $today ] ) ) {
			$ad_requests      = max( 0.0, (float) ( $today_rows[ $today ]['ad_requests'] ?? 0 ) );
			$matched_requests = max( 0.0, (float) ( $today_rows[ $today ]['matched_requests'] ?? 0 ) );
		}
	}

	$state['day'] = array(
		'earnings'         => $earnings,
		'page_views'       => $page_views,
		'impressions'      => $impressions,
		'clicks'           => $clicks,
		'ad_requests'      => $ad_requests,
		'matched_requests' => $matched_requests,
		'coverage'         => $ad_requests > 0 ? $matched_requests / $ad_requests : null,
		'requests_pv'      => $page_views > 0 ? $ad_requests / $page_views : 0.0,
		'matched_pv'       => $page_views > 0 ? $matched_requests / $page_views : 0.0,
		'page_rpm'         => $page_views > 0 ? $earnings / $page_views * 1000 : 0.0,
		'impression_rpm'   => $impressions > 0 ? $earnings / $impressions * 1000 : 0.0,
		'impressions_pv'   => $page_views > 0 ? $impressions / $page_views : 0.0,
	);
	$state['available'] = $page_views > 0;

	/* Marginal window. Use the freshest snapshot as the anchor rather than the
	 * wall clock, so a late sync does not silently measure an empty hour. */
	$state['window'] = go_verge_ads_econ_window( $intraday, $today, $end_minute, 60 );

	$peers = go_verge_ads_econ_peers( $intraday, $today, $end_minute, $now, 60 );
	$state['readiness']['peer_windows_usable'] = count( $peers );
	if ( count( $peers ) >= 3 ) {
		$state['peers'] = array(
			'count'              => count( $peers ),
			'impression_rpm'     => go_verge_ads_econ_median( array_column( $peers, 'impression_rpm' ) ),
			'impression_rpm_p25' => go_verge_ads_econ_percentile( array_column( $peers, 'impression_rpm' ), 0.25 ),
			'impression_rpm_p75' => go_verge_ads_econ_percentile( array_column( $peers, 'impression_rpm' ), 0.75 ),
			'page_rpm'           => go_verge_ads_econ_median( array_column( $peers, 'page_rpm' ) ),
			'impressions_pv'     => go_verge_ads_econ_median( array_column( $peers, 'impressions_pv' ) ),
		);
	}

	/* Pacing and projection against the learned share-of-day curve. */
	$curve = go_verge_ads_econ_day_curve();
	$state['readiness']['curve_days'] = (int) ( $curve['days'] ?? 0 );
	$bucket = (int) floor( $end_minute / 30 );
	$pv_share = null;
	$earn_share = null;
	for ( $b = $bucket; $b >= 0 && null === $pv_share; $b-- ) {
		if ( isset( $curve['pv'][ $b ] ) ) {
			$pv_share = (float) $curve['pv'][ $b ];
			$earn_share = isset( $curve['earnings'][ $b ] ) ? (float) $curve['earnings'][ $b ] : null;
		}
	}
	if ( null !== $pv_share && $pv_share > 0.05 && $page_views > 0 ) {
		$projected_pv = $page_views / $pv_share;
		$projected_earn = ( null !== $earn_share && $earn_share > 0.05 ) ? $earnings / $earn_share : null;
		$state['projection'] = array(
			'page_views' => round( $projected_pv ),
			'earnings'   => null === $projected_earn ? null : round( $projected_earn, 2 ),
			'page_rpm'   => ( null === $projected_earn || $projected_pv <= 0 ) ? null : round( $projected_earn / $projected_pv * 1000, 3 ),
			'share_pv'   => round( $pv_share, 4 ),
			'confidence' => (int) ( $curve['days'] ?? 0 ) >= 4 ? 'high' : 'low',
		);
	}

	set_transient( GO_VERGE_ADS_ECON_DAY_TRANSIENT, $state, 5 * MINUTE_IN_SECONDS );
	return $state;
}

/** The Data Lab just advanced. Recompute the cheap parts; leave the slow ones. */
function go_verge_ads_econ_after_refresh() {
	delete_transient( GO_VERGE_ADS_ECON_DAY_TRANSIENT );
	go_verge_ads_econ_day_state( true );
}
add_action( 'goac_quarter_hour_refresh', 'go_verge_ads_econ_after_refresh', 20 );
