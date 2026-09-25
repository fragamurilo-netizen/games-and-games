<?php
/**
 * Calendar trials — the only way this engine can prove a change raised RPM.
 *
 * WHY THIS EXISTS
 * Every other module here decides delivery. None of them could answer the one
 * question that matters after a release: did it earn more? Comparing "before"
 * and "after" cannot answer it, because traffic mix, demand and season move
 * between the two periods and no amount of care separates those from the
 * change. Without a design that holds them constant, a release note can only
 * say what the code now does, never what it was worth.
 *
 * WHAT THIS IS NOT
 * It is NOT an audience split. There is no group draw, no per-reader bucket, no
 * cookie, no ad channel and no second bootstrap: that design was removed from
 * this theme on purpose and stays removed. Two readers who open the same page
 * in the same minute always receive exactly the same configuration.
 *
 * WHAT IT IS
 * The calendar is the unit of assignment. A whole day runs one arm; the next
 * day runs the next. Every reader that day sees the same engine, and AdSense's
 * own per-day report — which the Ads Center already synchronises — therefore
 * separates the arms with the publisher's real revenue, with no custom
 * dimension and nothing for the theme to count.
 *
 * Because the rotation advances one day at a time and a week is seven days,
 * consecutive days land on different weekdays: over fourteen days a two-arm
 * trial gives each arm each weekday exactly once, so the weekend cancels out of
 * the comparison instead of landing on one arm. That property is the whole
 * reason the rotation is daily rather than weekly.
 *
 * WHAT IT STILL CANNOT DO
 * Days are not randomised within a block and a calendar day is not a controlled
 * unit: a news cycle, an outage or a Discover surge belongs to whichever arm
 * owns that date. It removes the confounds that move slowly — weekday, and with
 * enough blocks, season and trend. It does not remove a one-day event, and it
 * is not evidence about any single pair of days. Read it over many blocks, and
 * read the spread alongside the difference.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * The clock the whole engine agrees on.
 *
 * Trial days must line up with the days AdSense reports, or the comparison
 * measures a boundary rather than a configuration. The runtime's dayparts read
 * the same value, so there is one definition of "what day is it" here.
 *
 * @return string
 */
function go_verge_ads_timezone() {
	$timezone = (string) apply_filters( 'go_verge_ads_timezone', 'America/Sao_Paulo' );
	return '' !== trim( $timezone ) ? $timezone : 'America/Sao_Paulo';
}

/**
 * Today, in the reporting timezone.
 *
 * @return string Y-m-d.
 */
function go_verge_ads_trial_today() {
	try {
		$now = new DateTimeImmutable( 'now', new DateTimeZone( go_verge_ads_timezone() ) );
		return $now->format( 'Y-m-d' );
	} catch ( Exception $e ) {
		return gmdate( 'Y-m-d' );
	}
}

/**
 * Rule keys a trial arm is allowed to move.
 *
 * An arm changes delivery timing and spacing, never the safety envelope. The
 * density ceilings, the article ratio and the request-per-placement rule are
 * absent on purpose: a trial must not be able to answer "does more crowding
 * earn more" by crowding the page, and the runtime re-clamps every value it
 * receives regardless of what a filter produced.
 *
 * @return array<int,string>
 */
function go_verge_ads_trial_tunable_keys() {
	return (array) apply_filters(
		'go_verge_ads_trial_tunable_keys',
		array(
			'min_gap_px',
			'min_stream_gap_px',
			'rest_lead_vh',
			'rest_lead_min_px',
			'rest_lead_max_px',
			'max_lookahead_vh',
			'fling_tau_s',
			'flick_vh_s',
			'request_spacing_ms',
			'engage_scroll_vh',
			'engage_dwell_ms',
		)
	);
}

/**
 * Declared trials.
 *
 * Ships with one worked example, DISABLED. Nothing about delivery changes until
 * an operator enables a trial deliberately, and only one may be enabled at a
 * time: two trials rotating over the same days would confound each other and
 * neither result would mean anything.
 *
 * A trial is:
 *   id          stable slug, used by the report and the diagnostics;
 *   enabled     false until an operator turns it on;
 *   start       first day of the rotation, Y-m-d in the reporting timezone;
 *   days        how many days a single arm holds before the rotation advances;
 *   arms        ordered map of arm key => delivery-rule overrides. The FIRST
 *               arm is the baseline and must override nothing, so the report
 *               always has something to compare against.
 *
 * Overrides are nested by device exactly like go_verge_ads_delivery_rules(),
 * so an arm can move mobile without touching desktop.
 *
 * @return array<int,array<string,mixed>>
 */
function go_verge_ads_trials() {
	return (array) apply_filters(
		'go_verge_ads_trials',
		array(
			array(
				/* 5.8.0: stopped. Timing is now set by the engine settings and
				 * may be changed during the day from wp-admin, which would
				 * confound a day-by-day comparison of one rule. */
				'id'      => 'mobile-standard-lead',
				'enabled' => false,
				'label'   => 'Antecipação do tier standard no mobile',
				'note'    => 'Pergunta se preparar as posições standard um pouco mais cedo no telefone troca viewability por impressões de forma lucrativa. Nada além da antecipação muda.',
				/*
				 * A data de início é só um piso. O relatório começa a contar no
				 * dia em que o teste foi REALMENTE visto rodando (ver
				 * go_verge_ads_trial_first_seen), então instalar depois desta
				 * data não faz dias do tema antigo entrarem na comparação.
				 */
				'start'   => '2026-09-22',
				'days'    => 1,
				'arms'    => array(
					/* Baseline: the shipped table, unmodified. */
					'base' => array(),
					'lead' => array(
						'mobile' => array(
							'rest_lead_vh' => array( 'standard' => 0.88 ),
						),
					),
				),
			),
		)
	);
}

/**
 * The single enabled trial, or null.
 *
 * A trial with no start date, fewer than two arms, or a baseline arm that
 * overrides something is a misconfiguration and is ignored rather than run
 * half-applied. If more than one is enabled, none runs: silently picking one
 * would attribute its days to a design the operator did not choose.
 *
 * Deliberately NOT memoised: go_verge_ads_trial_assignment() caches the one
 * value a request actually needs, and it returns before reaching here when no
 * trial is running — so this loop over a handful of declarations runs at most
 * once per request, and stays observable to a test that installs a different
 * declaration halfway through.
 *
 * @return array<string,mixed>|null
 */
function go_verge_ads_active_trial() {
	$enabled = array();
	foreach ( go_verge_ads_trials() as $trial ) {
		if ( ! is_array( $trial ) || empty( $trial['enabled'] ) ) {
			continue;
		}
		$id    = sanitize_key( (string) ( $trial['id'] ?? '' ) );
		$start = (string) ( $trial['start'] ?? '' );
		$arms  = (array) ( $trial['arms'] ?? array() );
		if ( '' === $id || ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', $start ) || count( $arms ) < 2 ) {
			continue;
		}
		/* The baseline must be the shipped table or the difference is between
		 * two changes rather than between a change and doing nothing. */
		$first = reset( $arms );
		if ( ! empty( $first ) ) {
			continue;
		}
		$trial['id']    = $id;
		$trial['start'] = $start;
		$trial['days']  = max( 1, min( 28, absint( $trial['days'] ?? 1 ) ) );
		$trial['arms']  = $arms;
		$enabled[]      = $trial;
	}

	return ( 1 === count( $enabled ) ) ? $enabled[0] : null;
}

/**
 * The first day this trial was actually seen running.
 *
 * `start` is what the operator declared; it is not evidence that the theme was
 * installed and the trial enabled on that date. Without this, a trial started
 * on the 22nd and installed on the 25th would have the report attribute the
 * 22nd to 24th — days that ran the previous configuration entirely — to whichever
 * arm the rotation names, and an early read would be comparing the release
 * against itself. Two contaminated days out of fourteen is enough to invert a
 * small difference.
 *
 * So the first administrative pageview that sees the trial active records the
 * date, once, and the report never counts a day before it. Written from the
 * admin only, like every other migration marker here: a public request never
 * writes an option.
 *
 * @param string $trial_id Trial id.
 * @return string Y-m-d, or '' when it has not been recorded yet.
 */
function go_verge_ads_trial_first_seen( $trial_id ) {
	$trial_id = sanitize_key( (string) $trial_id );
	if ( '' === $trial_id ) {
		return '';
	}
	$seen = get_option( 'go_verge_ads_trial_first_seen', array() );
	$seen = is_array( $seen ) ? $seen : array();
	$date = (string) ( $seen[ $trial_id ] ?? '' );

	return preg_match( '/^\d{4}-\d{2}-\d{2}$/', $date ) ? $date : '';
}

/**
 * Record today as the first day this trial ran, once.
 *
 * add_option is atomic, so concurrent admin requests cannot move the date
 * later; and nothing here ever rewrites a date that already exists.
 *
 * @return void
 */
function go_verge_ads_trial_mark_first_seen() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) || ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) ) {
		return;
	}
	$trial = go_verge_ads_active_trial();
	if ( ! $trial ) {
		return;
	}
	$seen = get_option( 'go_verge_ads_trial_first_seen', array() );
	$seen = is_array( $seen ) ? $seen : array();
	if ( ! empty( $seen[ $trial['id'] ] ) ) {
		return;
	}
	$today = go_verge_ads_trial_today();
	/* Never earlier than the declared start: a clock skewed backwards must not
	 * pull days that predate the rotation into the comparison. */
	$seen[ $trial['id'] ] = $today > $trial['start'] ? $today : $trial['start'];
	update_option( 'go_verge_ads_trial_first_seen', $seen, false );
}
add_action( 'admin_init', 'go_verge_ads_trial_mark_first_seen', 12 );

/**
 * The first day the report may count for this trial.
 *
 * @param array<string,mixed> $trial Trial definition.
 * @return string Y-m-d.
 */
function go_verge_ads_trial_reportable_start( array $trial ) {
	$seen = go_verge_ads_trial_first_seen( $trial['id'] );
	return ( '' !== $seen && $seen > $trial['start'] ) ? $seen : (string) $trial['start'];
}

/**
 * Which arm a given calendar day belongs to.
 *
 * Pure arithmetic on the date. It reads no request, no reader, no cookie and no
 * random source, which is what makes the same day reproducible months later
 * when the report is finally read — and what keeps this from being an audience
 * split.
 *
 * @param array<string,mixed> $trial Trial definition.
 * @param string              $date  Y-m-d.
 * @return array<string,mixed>|null
 */
function go_verge_ads_trial_arm_for( array $trial, $date ) {
	if ( ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', (string) $date ) ) {
		return null;
	}
	$day = (int) floor( strtotime( $date . ' 00:00:00 UTC' ) / DAY_IN_SECONDS );
	$from = (int) floor( strtotime( $trial['start'] . ' 00:00:00 UTC' ) / DAY_IN_SECONDS );
	$offset = $day - $from;
	if ( $offset < 0 ) {
		return null;
	}
	$keys  = array_keys( (array) $trial['arms'] );
	$block = (int) floor( $offset / max( 1, (int) $trial['days'] ) );
	$index = $block % count( $keys );

	return array(
		'trial'     => $trial['id'],
		'arm'       => $keys[ $index ],
		'arm_index' => $index,
		'baseline'  => 0 === $index,
		'day_index' => $offset,
		'block'     => $block,
		'date'      => (string) $date,
	);
}

/**
 * Today's assignment, or null when no trial is running.
 *
 * Nothing here is memoised. go_verge_ads_delivery_rules() is built once per
 * request, so a cache would save one filter pass and a date construction while
 * costing the property that makes the whole design auditable: that asking twice
 * always gives the same answer because the answer is computed, not remembered.
 *
 * @return array<string,mixed>|null
 */
function go_verge_ads_trial_assignment() {
	$trial = go_verge_ads_active_trial();
	return $trial ? go_verge_ads_trial_arm_for( $trial, go_verge_ads_trial_today() ) : null;
}

/**
 * Merge one arm's overrides into the delivery rule table.
 *
 * Only the allowlisted keys are copied, and only into a device profile that
 * already exists. Anything else in an arm is ignored rather than trusted: an
 * arm is a small, auditable delta on the shipped table, not a second copy of
 * it that could drift.
 *
 * @param array<string,mixed> $rules    Delivery rules.
 * @param array<string,mixed> $override Arm overrides.
 * @return array<string,mixed>
 */
function go_verge_ads_trial_merge_rules( array $rules, array $override ) {
	$tunable = go_verge_ads_trial_tunable_keys();

	foreach ( array( 'mobile', 'desktop' ) as $device ) {
		if ( ! isset( $override[ $device ] ) || ! is_array( $override[ $device ] ) || ! isset( $rules[ $device ] ) || ! is_array( $rules[ $device ] ) ) {
			continue;
		}
		foreach ( (array) $override[ $device ] as $key => $value ) {
			if ( ! in_array( (string) $key, $tunable, true ) ) {
				continue;
			}
			if ( 'rest_lead_vh' === $key ) {
				/* Per-tier, so an arm can move one tier and leave the rest of
				 * the ladder exactly where the shipped table put it. */
				foreach ( (array) $value as $tier => $lead ) {
					if ( isset( $rules[ $device ]['rest_lead_vh'][ $tier ] ) && is_numeric( $lead ) ) {
						$rules[ $device ]['rest_lead_vh'][ $tier ] = (float) $lead;
					}
				}
				continue;
			}
			if ( is_numeric( $value ) ) {
				$rules[ $device ][ $key ] = 0 === strpos( (string) $key, 'engage_scroll' ) || false !== strpos( (string) $key, '_vh' )
					? (float) $value
					: (int) round( (float) $value );
			}
		}
	}

	return $rules;
}

/**
 * Apply today's arm to the one rule table the browser obeys.
 *
 * Runs late so it sees the table every other filter produced, and it is the
 * only place a trial can change delivery. The runtime clamps every value it
 * reads, so a mistyped override cannot produce stacked creatives or a request
 * four screens ahead however it reaches this function.
 *
 * @param array<string,mixed> $rules Delivery rules.
 * @return array<string,mixed>
 */
function go_verge_ads_trial_filter_rules( $rules ) {
	if ( ! is_array( $rules ) ) {
		return $rules;
	}
	$assignment = go_verge_ads_trial_assignment();
	if ( ! $assignment || ! empty( $assignment['baseline'] ) ) {
		return $rules;
	}
	$trial = go_verge_ads_active_trial();
	$arms  = (array) $trial['arms'];
	$arm   = (array) ( $arms[ $assignment['arm'] ] ?? array() );

	return empty( $arm ) ? $rules : go_verge_ads_trial_merge_rules( $rules, $arm );
}
add_filter( 'go_verge_ads_delivery_rules', 'go_verge_ads_trial_filter_rules', 99 );

/**
 * What the browser is told about the trial.
 *
 * The arm name only, so `GOAdsRuntime.inspect()` can state which configuration
 * a page is running and an operator can confirm the rotation is live without
 * reading the database. It carries no reader information, is identical for
 * every visitor that day, and nothing in the delivery path reads it back.
 *
 * @return array<string,mixed>|null
 */
function go_verge_ads_trial_public_signal() {
	$assignment = go_verge_ads_trial_assignment();
	if ( ! $assignment ) {
		return null;
	}
	return array(
		'trial'     => $assignment['trial'],
		'arm'       => $assignment['arm'],
		'baseline'  => (bool) $assignment['baseline'],
		'block'     => (int) $assignment['block'],
		'unit'      => 'calendar-day',
		'scope'     => 'Assignment is per calendar day and identical for every reader; it is not an audience split.',
	);
}

/**
 * The arm that owned each day of a range.
 *
 * The report joins this to the revenue AdSense reported for the same days.
 *
 * @param string $from Y-m-d.
 * @param string $to   Y-m-d.
 * @return array<string,array<string,mixed>> Keyed by date.
 */
function go_verge_ads_trial_calendar( $from, $to ) {
	$trial = go_verge_ads_active_trial();
	$out   = array();
	if ( ! $trial || ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', (string) $from ) || ! preg_match( '/^\d{4}-\d{2}-\d{2}$/', (string) $to ) ) {
		return $out;
	}
	$start = (int) floor( strtotime( $from . ' 00:00:00 UTC' ) / DAY_IN_SECONDS );
	$end   = (int) floor( strtotime( $to . ' 00:00:00 UTC' ) / DAY_IN_SECONDS );
	if ( $end < $start || ( $end - $start ) > 1500 ) {
		return $out;
	}
	for ( $day = $start; $day <= $end; $day++ ) {
		$date = gmdate( 'Y-m-d', $day * DAY_IN_SECONDS );
		$arm  = go_verge_ads_trial_arm_for( $trial, $date );
		if ( $arm ) {
			$out[ $date ] = $arm;
		}
	}
	return $out;
}
