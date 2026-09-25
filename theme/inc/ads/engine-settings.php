<?php
/**
 * Engine settings — the live, editable layer of the manual ad engine (5.8.0).
 *
 * Every lever the newsroom may want to move during the day lives here, in one
 * option, with one sanitizer and one history. config.php, the delivery rule
 * table, the planner, the composer and the renderer read these values; nothing
 * else in the theme carries a second copy of them.
 *
 * DEFAULTS = the 3.53 profile. Theme 3.53 is the engine that produced the
 * reference day (Sun 30/08/2026: US$ 4,79 page RPM, US$ 0,73 impression RPM,
 * 54,84% Active View, 6,56 impressions per page view). Its own notes, measured on
 * this account, are the reason for each default:
 *
 *   - article body: native In-article units in the first ranks. Display in the
 *     body measured US$ 0,13-0,14 per thousand impressions (20-26/08); the
 *     native ranks pulled the ladder average up to US$ 0,20;
 *   - density: at most 35% of the reading column in advertising (5.6.7 ran
 *     45%). 3.53 also required 520 px (phone) / 600 px (desktop) between
 *     ladder units, but ONLY from rank 10 on: ranks 1-9 were exempt
 *     (`core_exempt_through_rank`), and the current ladder is P1 + A1..A6. The
 *     crowding floor for those ranks therefore stays at 5.6.7's 240 / 300 px;
 *     applying 520 px to them blocked Prime P1 behind the hero unit;
 *   - request timing: a long runway (up to ~1,9 screens for the first ranks).
 *     Short runways produced 26/08 — 3,88 imp/page at 58% Active View and
 *     US$ 2,11 page RPM — while 13/08 and 19/08 (6,9-8,1 imp/page at ~50% Active
 *     View) produced US$ 4,65-5,97;
 *   - Multiplex off: 11.710 impressions in 7 days for US$ 0,66 at 13,96% Active
 *     View, the worst unit in the account; the deep post-content display units
 *     and the stacked mobile rail did not exist in 3.53 either;
 *   - desktop Top Display as a fixed 970x250 billboard (728x90 where it does
 *     not fit): a responsive request on that host resolves to a ~90 px
 *     leaderboard.
 *
 * Changes are made in wp-admin (inc/ads/engine-admin.php). Every save keeps the
 * previous values in a bounded history, so any change can be undone, and
 * purges the page cache so the next reader gets the new engine.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_ADS_ENGINE_OPTION' ) ) {
	define( 'GO_VERGE_ADS_ENGINE_OPTION', 'go_verge_ads_engine_settings' );
}
if ( ! defined( 'GO_VERGE_ADS_ENGINE_HISTORY_OPTION' ) ) {
	define( 'GO_VERGE_ADS_ENGINE_HISTORY_OPTION', 'go_verge_ads_engine_history' );
}

/** The five request tiers the runtime understands, in reach order. */
function go_verge_ads_engine_tiers() {
	return array( 'reach', 'premium', 'standard', 'deep', 'completion' );
}

/**
 * The 3.53 profile.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_engine_defaults() {
	return array(
		/* Article body. */
		'body_format'            => 'inarticle', // inarticle | display (5.6.7 units)
		'body_max_rung'          => 6,           // A-rungs after Prime; 7-8 use the A7/A8 Display units
		'min_gap_mobile'         => 240,
		'min_gap_desktop'        => 300,
		'article_ratio'          => 0.35,
		'units_in_window'        => 3,
		'stream_gap_mobile'      => 380,
		'stream_gap_desktop'     => 460,
		/* Request timing: resting lead per tier in screens, times a device scale. */
		'lead_mobile'            => array( 'reach' => 1.60, 'premium' => 1.40, 'standard' => 1.15, 'deep' => 0.90, 'completion' => 0.70 ),
		'lead_desktop'           => array( 'reach' => 1.40, 'premium' => 1.25, 'standard' => 1.05, 'deep' => 0.85, 'completion' => 0.65 ),
		'lead_scale_mobile'      => 1.00,
		'lead_scale_desktop'     => 1.00,
		'max_lookahead_mobile'   => 1.90,
		'max_lookahead_desktop'  => 1.80,
		'warmup_lookahead'       => 1.25,
		/* Surfaces. */
		'masthead_billboard'     => true,
		'hero_overlay'           => true,
		'surface_multiplex'      => false,
		'surface_post_content'   => false,
		'surface_rail_mobile'    => false,
		/* Refine button. */
		'refine_min_page_views'  => 800,
		'refine_cooldown_min'    => 90,
		'refine_max_per_day'     => 4,
	);
}

/**
 * Bounds for every numeric setting: [min, max, step used by the refine button].
 *
 * @return array<string,array<int,float>>
 */
function go_verge_ads_engine_bounds() {
	return array(
		'body_max_rung'         => array( 1, 8, 1 ),
		'min_gap_mobile'        => array( 240, 900, 60 ),
		'min_gap_desktop'       => array( 300, 900, 60 ),
		'article_ratio'         => array( 0.20, 0.45, 0.03 ),
		'units_in_window'       => array( 1, 4, 1 ),
		'stream_gap_mobile'     => array( 200, 900, 40 ),
		'stream_gap_desktop'    => array( 240, 900, 40 ),
		'lead'                  => array( 0.30, 2.00, 0 ),
		'lead_scale_mobile'     => array( 0.60, 1.40, 0.10 ),
		'lead_scale_desktop'    => array( 0.60, 1.40, 0.10 ),
		'max_lookahead_mobile'  => array( 1.00, 2.50, 0 ),
		'max_lookahead_desktop' => array( 1.00, 2.50, 0 ),
		'warmup_lookahead'      => array( 0.50, 2.00, 0 ),
		'refine_min_page_views' => array( 200, 20000, 0 ),
		'refine_cooldown_min'   => array( 15, 360, 0 ),
		'refine_max_per_day'    => array( 1, 12, 0 ),
	);
}

/**
 * Clamp and normalise a settings array. Unknown keys are dropped.
 *
 * @param mixed $raw Candidate settings.
 * @return array<string,mixed>
 */
function go_verge_ads_engine_sanitize( $raw ) {
	$raw      = is_array( $raw ) ? $raw : array();
	$defaults = go_verge_ads_engine_defaults();
	$bounds   = go_verge_ads_engine_bounds();
	$out      = array();
	foreach ( $defaults as $key => $default ) {
		$value = array_key_exists( $key, $raw ) ? $raw[ $key ] : $default;
		if ( is_bool( $default ) ) {
			$out[ $key ] = ! empty( $value ) && 'off' !== $value && '0' !== (string) $value;
		} elseif ( is_array( $default ) ) {
			$value = is_array( $value ) ? $value : array();
			$out[ $key ] = array();
			foreach ( go_verge_ads_engine_tiers() as $tier ) {
				$number = isset( $value[ $tier ] ) && is_numeric( str_replace( ',', '.', (string) $value[ $tier ] ) ) ? (float) str_replace( ',', '.', (string) $value[ $tier ] ) : (float) $default[ $tier ];
				$out[ $key ][ $tier ] = round( max( $bounds['lead'][0], min( $bounds['lead'][1], $number ) ), 2 );
			}
		} elseif ( 'body_format' === $key ) {
			$out[ $key ] = in_array( $value, array( 'inarticle', 'display' ), true ) ? $value : $default;
		} else {
			$number = is_numeric( str_replace( ',', '.', (string) $value ) ) ? (float) str_replace( ',', '.', (string) $value ) : (float) $default;
			$range  = $bounds[ $key ] ?? array( $number, $number );
			$number = max( (float) $range[0], min( (float) $range[1], $number ) );
			$out[ $key ] = is_int( $default ) ? (int) round( $number ) : round( $number, 2 );
		}
	}
	return $out;
}

/**
 * The effective settings for this request.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_engine_settings() {
	static $cache = null;
	if ( null !== $cache && empty( $GLOBALS['go_verge_ads_engine_settings_dirty'] ) ) {
		return $cache;
	}
	$GLOBALS['go_verge_ads_engine_settings_dirty'] = false;
	$stored = function_exists( 'get_option' ) ? get_option( GO_VERGE_ADS_ENGINE_OPTION, array() ) : array();
	$cache  = go_verge_ads_engine_sanitize( (array) apply_filters( 'go_verge_ads_engine_settings', is_array( $stored ) ? $stored : array() ) );
	return $cache;
}

/** One setting. */
function go_verge_ads_engine_setting( $key ) {
	$settings = go_verge_ads_engine_settings();
	return $settings[ $key ] ?? ( go_verge_ads_engine_defaults()[ $key ] ?? null );
}

/**
 * Persist new settings, keep the previous ones in history and purge the cache.
 *
 * @param array<string,mixed> $next   Candidate settings (sanitized here).
 * @param string              $source manual | refine | reset | undo.
 * @param string              $note   Human reason, shown in the history.
 * @param array<string,mixed> $context Metrics/decision that justified it.
 * @return array<string,mixed> What changed: key => [before, after].
 */
function go_verge_ads_engine_save( $next, $source, $note = '', $context = array() ) {
	$before = go_verge_ads_engine_settings();
	$after  = go_verge_ads_engine_sanitize( $next );
	$diff   = go_verge_ads_engine_diff( $before, $after );
	if ( ! $diff && 'reset' !== $source ) {
		return array();
	}
	update_option( GO_VERGE_ADS_ENGINE_OPTION, $after, true );
	$GLOBALS['go_verge_ads_engine_settings_dirty'] = true;

	$history = get_option( GO_VERGE_ADS_ENGINE_HISTORY_OPTION, array() );
	$history = is_array( $history ) ? $history : array();
	array_unshift(
		$history,
		array(
			'at'      => time(),
			'user'    => function_exists( 'get_current_user_id' ) ? get_current_user_id() : 0,
			'source'  => sanitize_key( $source ),
			'note'    => (string) $note,
			'before'  => $before,
			'diff'    => $diff,
			'context' => $context,
		)
	);
	update_option( GO_VERGE_ADS_ENGINE_HISTORY_OPTION, array_slice( $history, 0, 60 ), false );

	if ( function_exists( 'go_verge_ads_schedule_policy_cache_purge' ) ) {
		go_verge_ads_schedule_policy_cache_purge();
	}
	return $diff;
}

/**
 * Flat key => [before, after] map of what differs.
 *
 * @return array<string,array<int,mixed>>
 */
function go_verge_ads_engine_diff( $before, $after ) {
	$diff = array();
	foreach ( $after as $key => $value ) {
		$old = $before[ $key ] ?? null;
		if ( is_array( $value ) ) {
			foreach ( $value as $sub => $sub_value ) {
				$old_sub = is_array( $old ) ? ( $old[ $sub ] ?? null ) : null;
				if ( $old_sub !== $sub_value ) {
					$diff[ $key . '.' . $sub ] = array( $old_sub, $sub_value );
				}
			}
		} elseif ( $old !== $value ) {
			$diff[ $key ] = array( $old, $value );
		}
	}
	return $diff;
}

/** @return array<int,array<string,mixed>> */
function go_verge_ads_engine_history() {
	$history = get_option( GO_VERGE_ADS_ENGINE_HISTORY_OPTION, array() );
	return is_array( $history ) ? $history : array();
}

/* ------------------------------------------------------------ consumers */

/**
 * Body ladder units for the configured format.
 *
 * `inarticle` uses the account's native In-article units: the four the 3.53
 * ladder ran (R1 premium, R2-3 core, R4-6 yield early, R7-9 yield late) plus
 * the three In-article units 5.x ran as A1-A3 before switching them to Display.
 * One id per rung keeps the one-request-per-slot rule intact. `display` is the
 * 5.6.7 set, unchanged, so switching back is a single setting.
 *
 * @return array<string,array<string,string>> placement => slot/name
 */
function go_verge_ads_engine_body_units() {
	if ( 'display' === go_verge_ads_engine_setting( 'body_format' ) ) {
		return array(
			'article-prime' => array( 'slot' => '5223365459', 'name' => 'GO Article Prime P1' ),
			'article-a1'    => array( 'slot' => '7131714626', 'name' => 'GO Article A1' ),
			'article-a2'    => array( 'slot' => '4505551284', 'name' => 'GO Article A2' ),
			'article-a3'    => array( 'slot' => '5056215625', 'name' => 'GO Article A3' ),
			'article-a4'    => array( 'slot' => '6568236715', 'name' => 'GO Article A4' ),
			'article-a5'    => array( 'slot' => '8238832024', 'name' => 'GO Article A5' ),
			'article-a6'    => array( 'slot' => '5255155049', 'name' => 'GO Article A6' ),
		);
	}
	return array(
		'article-prime' => array( 'slot' => '6312711140', 'name' => 'GO_V5_SINGLE_FIRST_INARTICLE' ),
		'article-a1'    => array( 'slot' => '4674441820', 'name' => 'GO_V6_SINGLE_CORE_INARTICLE' ),
		'article-a2'    => array( 'slot' => '6368539121', 'name' => 'GO In-article (5.x A1)' ),
		'article-a3'    => array( 'slot' => '1241251828', 'name' => 'GO_V6_SINGLE_YIELD_INARTICLE' ),
		'article-a4'    => array( 'slot' => '7554015324', 'name' => 'GO In-article (5.x A2)' ),
		'article-a5'    => array( 'slot' => '3625953575', 'name' => 'GO_V5_SINGLE_BODY_INARTICLE' ),
		'article-a6'    => array( 'slot' => '6240933652', 'name' => 'GO In-article (5.x A3)' ),
	);
}

/**
 * Apply the body format to one inventory entry (article-prime, article-a1..a6).
 *
 * @param string              $placement Placement key.
 * @param array<string,mixed> $unit      Inventory entry.
 * @return array<string,mixed>
 */
function go_verge_ads_engine_body_unit( $placement, $unit ) {
	$units = go_verge_ads_engine_body_units();
	if ( ! isset( $units[ $placement ] ) ) {
		return $unit;
	}
	$unit['slot'] = $units[ $placement ]['slot'];
	$unit['name'] = $units[ $placement ]['name'];
	if ( 'inarticle' === go_verge_ads_engine_setting( 'body_format' ) ) {
		/* Google's In-article code: display:block;text-align:center,
		 * data-ad-layout="in-article", data-ad-format="fluid", no full-width flag. */
		$unit['sizing']         = 'fluid';
		$unit['format']         = 'fluid';
		$unit['ad_layout']      = 'in-article';
		$unit['full_width']     = false;
		$unit['requested_size'] = 'fluid in-article';
	}
	return $unit;
}

/**
 * Overlay the settings on the delivery rule table (config.php).
 *
 * @param array<string,mixed> $rules Rule table.
 * @return array<string,mixed>
 */
function go_verge_ads_engine_apply_rules( $rules ) {
	$s = go_verge_ads_engine_settings();
	foreach ( array( 'mobile', 'desktop' ) as $device ) {
		if ( ! isset( $rules[ $device ] ) || ! is_array( $rules[ $device ] ) ) {
			continue;
		}
		$scale = (float) $s[ 'lead_scale_' . $device ];
		$leads = array();
		foreach ( go_verge_ads_engine_tiers() as $tier ) {
			$leads[ $tier ] = round( max( 0.25, min( 2.0, (float) $s[ 'lead_' . $device ][ $tier ] * $scale ) ), 3 );
		}
		$rules[ $device ]['rest_lead_vh']            = $leads;
		$rules[ $device ]['rest_lead_max_px']        = 1800;
		$rules[ $device ]['min_gap_px']              = (int) $s[ 'min_gap_' . $device ];
		$rules[ $device ]['min_stream_gap_px']       = (int) $s[ 'stream_gap_' . $device ];
		$rules[ $device ]['max_ad_to_content_ratio'] = (float) $s['article_ratio'];
		$rules[ $device ]['max_units_in_window']     = (int) $s['units_in_window'];
		$rules[ $device ]['max_lookahead_vh']        = max( (float) $s[ 'max_lookahead_' . $device ], max( $leads ) );
	}
	if ( isset( $rules['governor'] ) && is_array( $rules['governor'] ) ) {
		$rules['governor']['warmup_lookahead_vh'] = (float) $s['warmup_lookahead'];
		$rules['governor']['conservative_lookahead_vh'] = max( 1.0, (float) $s['warmup_lookahead'] );
	}
	return $rules;
}
add_filter( 'go_verge_ads_delivery_rules', 'go_verge_ads_engine_apply_rules', 5 );
