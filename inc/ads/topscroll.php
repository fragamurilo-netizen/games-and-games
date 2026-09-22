<?php
/**
 * Top Scroll — historical responsive mobile unit in normal document flow.
 *
 * The editorial revenue preset uses a rolling 6-fill / 24-hour local cap.
 * Fills 1–4 are normal; fill 5 requires an engaged session (3+ pageviews or
 * 60s of active reading), and fill 6 requires 4+ pageviews or 120s active.
 * An explicit cap counts confirmed fills only with storage permission.
 * It never refreshes an ad and never changes automatically from RPM.
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_OPTION' ) ) {
	define( 'GO_VERGE_ADSENSE_TOPSCROLL_OPTION', 'go_verge_adsense_topscroll' );
}

if ( ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT' ) ) {
	define( 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT', 6 );
}
if ( ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_READY_MIGRATION_OPTION' ) ) {
	define( 'GO_VERGE_ADSENSE_TOPSCROLL_READY_MIGRATION_OPTION', 'go_verge_topscroll_ready_20260921_v1' );
}
if ( ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION' ) ) {
	define( 'GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION', 'go_verge_topscroll_manual_baseline_v1' );
}
if ( ! defined( 'GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION' ) ) {
	define( 'GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION', 'go_verge_topscroll_manual_baseline_backup_v1' );
}

/**
 * External code retains authority over the preset. Registered filters are
 * reported even if their result happens to equal the supplied configuration.
 * This report describes code overrides, not account settings or browser state.
 *
 * @return array<string,mixed>
 */
function go_verge_adsense_topscroll_external_overrides() {
	$overrides = array();
	foreach ( array( 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT', 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX', 'GO_VERGE_ADSENSE_TOPSCROLL_ENABLED' ) as $name ) {
		if ( defined( $name ) ) {
			$overrides[ $name ] = constant( $name );
		}
	}
	if ( 6 !== absint( GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT ) ) {
		$overrides['GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT'] = GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT;
	}
	foreach ( array( 'go_verge_adsense_topscroll_config', 'go_verge_adsense_topscroll_enabled' ) as $hook ) {
		if ( function_exists( 'has_filter' ) && false !== has_filter( $hook ) ) {
			$overrides[ $hook ] = 'registered';
		}
	}
	return $overrides;
}

/** Compatibility for integrations that used the old migration predicate. */
function go_verge_adsense_topscroll_has_ready_override() {
	return ! empty( go_verge_adsense_topscroll_external_overrides() );
}

/** Whether the authorized initial preset has already been persisted. */
function go_verge_adsense_topscroll_baseline_applied() {
	return 1 === (int) get_option( GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION, 0 );
}

/**
 * Baseline option values. IDs and additional integration fields are retained.
 * A customized DEFAULT constant is an explicit deployment override, as are the
 * higher-priority LIMIT/MAX/ENABLED constants resolved by config().
 *
 * @param mixed $saved Stored Top Scroll option.
 * @return array<string,mixed>
 */
function go_verge_adsense_topscroll_baseline_values( $saved ) {
	$saved = is_array( $saved ) ? $saved : array();
	$saved['enabled'] = true;
	$saved['frequency_max'] = max( 0, min( 6, absint( GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT ) ) );
	return $saved;
}

/**
 * Compatibility name, now a read-only resolver: the preset takes effect on the
 * first uncached response without database writes from a public page request.
 * Only the admin migration below persists it. Browser frequency/consent storage
 * is not read, removed or renamed by this server-side reset.
 *
 * @param mixed $saved Stored Top Scroll option.
 * @return array<string,mixed>
 */
function go_verge_adsense_topscroll_maybe_migrate_ready_cap( $saved ) {
	if ( ! go_verge_adsense_topscroll_baseline_applied() ) {
		return go_verge_adsense_topscroll_baseline_values( $saved );
	}
	return is_array( $saved ) ? $saved : array();
}

/**
 * Persist the authorized reset once, with the original option recoverable.
 * Priority 5 runs before this theme registers its Settings API sanitizer, which
 * otherwise would discard older additional option fields during the migration.
 * add_option makes creation of the original backup atomic across admin tabs.
 * Failed backup/option/marker writes leave the migration pending for retry.
 *
 * @return bool Whether the initial preset is durably marked as applied.
 */
function go_verge_adsense_topscroll_apply_baseline() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) || ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) ) {
		return false;
	}
	if ( go_verge_adsense_topscroll_baseline_applied() ) {
		return true;
	}
	$missing = new stdClass();
	$original = get_option( GO_VERGE_ADSENSE_TOPSCROLL_OPTION, $missing );
	$exists = $original !== $missing;
	$target = go_verge_adsense_topscroll_baseline_values( $exists ? $original : array() );
	$backup = get_option( GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION, $missing );
	if ( $backup === $missing ) {
		add_option(
			GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION,
			array(
				'option' => GO_VERGE_ADSENSE_TOPSCROLL_OPTION,
				'existed' => $exists,
				'value' => $exists ? $original : null,
				'target' => $target,
				'created_at' => time(),
				'overrides' => go_verge_adsense_topscroll_external_overrides(),
			),
			'',
			false
		);
		$backup = get_option( GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_BACKUP_OPTION, $missing );
	}
	if ( ! is_array( $backup ) || GO_VERGE_ADSENSE_TOPSCROLL_OPTION !== ( $backup['option'] ?? '' )
		|| ! array_key_exists( 'existed', $backup ) || ! array_key_exists( 'value', $backup ) ) {
		return false;
	}
	if ( ! $exists || $original !== $target ) {
		update_option( GO_VERGE_ADSENSE_TOPSCROLL_OPTION, $target, false );
	}
	if ( get_option( GO_VERGE_ADSENSE_TOPSCROLL_OPTION, $missing ) !== $target ) {
		return false;
	}
	$marked = add_option( GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION, 1, '', false );
	if ( ! $marked && ! go_verge_adsense_topscroll_baseline_applied()
		&& get_option( GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION, $missing ) !== $missing ) {
		$marked = update_option( GO_VERGE_ADSENSE_TOPSCROLL_BASELINE_OPTION, 1, false );
	}
	$applied = go_verge_adsense_topscroll_baseline_applied();
	if ( $applied && $marked && function_exists( 'go_verge_ads_schedule_policy_cache_purge' ) ) {
		go_verge_ads_schedule_policy_cache_purge();
	}
	return $applied;
}
add_action( 'admin_init', 'go_verge_adsense_topscroll_apply_baseline', 5 );

/**
 * Resolved Top Scroll configuration.
 *
 * @return array<string,mixed>
 */
function go_verge_adsense_topscroll_config() {
	$saved   = get_option( GO_VERGE_ADSENSE_TOPSCROLL_OPTION, array( 'enabled' => true ) );
	$saved   = is_array( $saved ) ? $saved : array();
	$baseline_pending = ! go_verge_adsense_topscroll_baseline_applied();
	$saved   = go_verge_adsense_topscroll_maybe_migrate_ready_cap( $saved );
	$enabled = ! array_key_exists( 'enabled', $saved ) || ! empty( $saved['enabled'] );
	$source  = $baseline_pending ? 'baseline' : 'option';
	$frequency_source = $baseline_pending ? 'baseline' : ( array_key_exists( 'frequency_max', $saved ) ? 'option' : 'default' );
	if ( $baseline_pending && 6 !== absint( GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT ) ) {
		$frequency_source = 'default-constant';
	}
	$frequency = $saved['frequency_max'] ?? GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT;
	if ( defined( 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT' ) ) {
		$frequency = GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT;
		$frequency_source = 'constant';
	} elseif ( defined( 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX' ) ) {
		/* Compatibility with the explicit cap supported by the August engine. */
		$frequency = GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX;
		$frequency_source = 'legacy-constant';
	}
	$frequency = max( 0, min( 6, absint( $frequency ) ) );

	if ( defined( 'GO_VERGE_ADSENSE_TOPSCROLL_ENABLED' ) ) {
		$enabled = (bool) GO_VERGE_ADSENSE_TOPSCROLL_ENABLED;
		$source  = 'constant';
	}

	$config = (array) apply_filters(
		'go_verge_adsense_topscroll_config',
		array(
			'enabled' => $enabled,
			'client'  => defined( 'GO_VERGE_ADSENSE_CLIENT' ) ? (string) GO_VERGE_ADSENSE_CLIENT : '',
			'slot'    => defined( 'GO_VERGE_ADSENSE_TOPSCROLL_SLOT' ) ? (string) GO_VERGE_ADSENSE_TOPSCROLL_SLOT : '',
			'source'  => $source,
			'frequency_max' => $frequency,
			'frequency_source' => $frequency_source,
			'baseline_pending' => $baseline_pending,
			'external_overrides' => go_verge_adsense_topscroll_external_overrides(),
			'frequency_window_ms' => DAY_IN_SECONDS * 1000,
			'smart_engagement' => true,
			'smart_free_fills' => 4,
			'smart_fifth_pages' => 3,
			'smart_fifth_active_ms' => 60 * 1000,
			'smart_sixth_pages' => 4,
			'smart_sixth_active_ms' => 120 * 1000,
			'smart_session_idle_ms' => 30 * MINUTE_IN_SECONDS * 1000,
		)
	);

	$config['frequency_max'] = max( 0, min( 6, absint( $config['frequency_max'] ?? GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT ) ) );
	if ( $config['frequency_max'] !== $frequency ) { $config['frequency_source'] = 'filter'; }
	$config['client']  = trim( (string) ( $config['client'] ?? '' ) );
	$config['slot']    = preg_replace( '/\D+/', '', (string) ( $config['slot'] ?? '' ) );
	$config['source']  = sanitize_key( (string) ( $config['source'] ?? 'filter' ) );
	$config['enabled'] = (bool) apply_filters(
		'go_verge_adsense_topscroll_enabled',
		! empty( $config['enabled'] ) && '' !== $config['client'] && '' !== $config['slot']
	);

	return $config;
}

/**
 * Whether this response may print the Top Scroll unit.
 *
 * Reserve and markup resolve from the same inventory predicate, so a template
 * the unit does not cover can never reserve space for a slot that never prints.
 *
 * @return bool
 */
function go_verge_adsense_topscroll_is_eligible() {
	$config = go_verge_adsense_topscroll_config();
	if ( empty( $config['enabled'] ) ) {
		return false;
	}
	if ( ! function_exists( 'go_verge_ads_is_monetizable_request' ) || ! go_verge_ads_is_monetizable_request() ) {
		return false;
	}
	if ( is_singular() && post_password_required() ) {
		return false;
	}
	if ( ! function_exists( 'go_verge_adsense_unit_config' ) || ! function_exists( 'go_verge_ads_unit_matches_context' ) ) {
		return false;
	}

	$unit = go_verge_adsense_unit_config( 'topscroll' );
	if ( empty( $unit ) || ! go_verge_ads_unit_matches_context( $unit ) ) {
		return false;
	}

	return (bool) apply_filters( 'go_verge_adsense_topscroll_is_eligible', true );
}

/**
 * Print the Top Scroll unit.
 *
 * @return void
 */
function go_verge_adsense_render_topscroll_slot() {
	if ( ! go_verge_adsense_topscroll_is_eligible() || ! function_exists( 'go_verge_adsense_unit_markup' ) ) {
		return;
	}

	echo go_verge_adsense_unit_markup( // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built and escaped by the renderer.
		'topscroll',
		array(
			'tag'         => 'aside',
			'class'       => 'go-adsense-topscroll',
			'dismissible' => true,
			'data'        => array( 'ad-surface' => 'topscroll' ),
		)
	);
}
