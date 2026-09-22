<?php
/**
 * Advertising renderer — standard AdSense units.
 *
 * Units use an `ins.adsbygoogle` carrying the client and slot and `push({})`.
 * Device-restricted units remain in an inert template until their breakpoint
 * matches, so a later unit's push cannot select a hidden, unrequested element.
 * An explicitly enabled consent gate also keeps the unit inert until permission.
 *
 * The theme owns presentation only: the wrapper, the "Publicidade" disclosure and
 * the reserved height. Whether a slot fills, what it fills with and how tall the
 * creative is are Google's decisions, read back from the `data-ad-status` the
 * provider writes on the `ins`. Scoped observation reads this status for the
 * Top Scroll quota and safe publisher reservation release. Requested provider
 * nodes are not rewritten, resized or refreshed. Only a confirmed empty manual host may collapse under the selected policy.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Claim one provider slot ID for this response.
 *
 * Every configured provider slot is strictly single-use per response. This prevents a
 * duplicate template call or stale experiment from requesting the same reporting identity twice.
 *
 * @param string $slot      Provider slot ID.
 * @param string $placement Placement key.
 * @return bool True when the claim is accepted.
 */
function go_verge_ads_claim_slot( $slot, $placement ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return false; }
	static $claimed = array();

	$slot = preg_replace( '/\D+/', '', (string) $slot );
	if ( '' === $slot ) {
		return false;
	}

	if ( isset( $claimed[ $slot ] ) ) {
		if ( function_exists( 'go_verge_ads_debug_enabled' ) && go_verge_ads_debug_enabled() ) {
			error_log( sprintf( '[GO Ads] Slot %s rejected at %s; already claimed by %s.', $slot, $placement, implode( ',', $claimed[ $slot ] ) ) ); // phpcs:ignore WordPress.PHP.DevelopmentFunctions.error_log_error_log
		}

		return false;
	}

	$claimed[ $slot ] = array( sanitize_key( $placement ) );

	return true;
}

/**
 * The media query that decides whether a device-restricted unit may request.
 *
 * A unit hidden by CSS still has a box of zero width. Pushing it answers
 * "No slot size for availableWidth=0" and burns the one request that slot gets,
 * so the push itself is gated by the same breakpoint that governs its display.
 *
 * @param array<string,mixed> $unit Inventory entry.
 * @return string Media query, or an empty string when the unit is unrestricted.
 */
function go_verge_ads_unit_media_query( $unit ) {
	$config      = go_verge_ads_config();
	$breakpoints = (array) ( $config['breakpoints'] ?? array() );

	$conditions = array();
	if ( ! empty( $unit['mobile_only'] ) ) {
		$conditions[] = sprintf( '(max-width:%dpx)', absint( $breakpoints['mobile_max'] ?? 767 ) );
	}
	if ( ! empty( $unit['desktop_only'] ) ) {
		$conditions[] = sprintf( '(min-width:%dpx)', absint( $breakpoints['desktop_min'] ?? 1101 ) );
	} elseif ( ! empty( $unit['min_viewport'] ) ) {
		$conditions[] = sprintf( '(min-width:%dpx)', absint( $unit['min_viewport'] ) );
	}
	if ( ! empty( $unit['max_viewport'] ) ) {
		$conditions[] = sprintf( '(max-width:%dpx)', absint( $unit['max_viewport'] ) );
	}
	return implode( ' and ', $conditions );
}

/**
 * Delivery priority for the runtime's critical-first staging.
 *
 * `critical` marks above-the-fold inventory (Top Scroll, Masthead, Hero): it
 * requests when near the viewport and, while its request is in flight, other units
 * wait a short bounded window. Anything else is `normal`.
 *
 * @param array<string,mixed> $unit Inventory entry.
 * @return string
 */
function go_verge_ads_unit_priority( $unit ) {
	return 'critical' === ( is_array( $unit ) ? (string) ( $unit['priority'] ?? '' ) : '' ) ? 'critical' : 'normal';
}

/**
 * Build one complete, self-requesting AdSense unit.
 *
 * @param string              $placement Placement key.
 * @param array<string,mixed> $args      tag, class.
 * @return string Empty when the placement has no unit in this context.
 */
function go_verge_adsense_unit_markup( $placement, $args = array() ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ''; }
	$placement = sanitize_key( $placement );
	$unit      = go_verge_adsense_unit_config( $placement );

	if ( empty( $unit['slot'] ) || ! go_verge_ads_unit_matches_context( $unit ) ) {
		return '';
	}
	if ( ! go_verge_ads_claim_slot( $unit['slot'], $placement ) ) {
		return '';
	}

	$args = wp_parse_args(
		$args,
		array(
			'tag'         => 'aside',
			'class'       => '',
			'dismissible' => false,
			'data'        => array(),
		)
	);

	$tag = preg_match( '/^[a-z]+$/', (string) $args['tag'] ) ? (string) $args['tag'] : 'aside';

	$classes = array( 'go-ad-slot', 'go-ad-slot--' . $placement );
	foreach ( preg_split( '/\s+/', (string) $args['class'] ) as $extra ) {
		$extra = sanitize_html_class( $extra );
		if ( '' !== $extra ) {
			$classes[] = $extra;
		}
	}
	if ( ! empty( $unit['mobile_only'] ) ) {
		$classes[] = 'go-ad-slot--mobile-only';
	}
	if ( ! empty( $unit['desktop_only'] ) ) {
		$classes[] = 'go-ad-slot--desktop-only';
	} elseif ( 768 === absint( $unit['min_viewport'] ?? 0 ) ) {
		$classes[] = 'go-ad-slot--tablet-up';
	}
	if ( ! empty( $unit['collapse_unfilled'] ) ) {
		$classes[] = 'go-ad-slot--collapse-unfilled';
	}
	/* Diagnostic hook and CSS contract for exact-size publisher units. */
	$sizing_attr = ( isset( $unit['sizing'] ) && 'fixed' === $unit['sizing'] ) ? ' data-go-ad-sizing="fixed"' : '';
	$dismissible = ! empty( $args['dismissible'] );
	if ( $dismissible ) {
		$classes[] = 'go-ad-slot--dismissible';
	}

	/* Publisher-owned measurement metadata. These attributes never influence
	 * Google's auction; they only make planner/runtime decisions inspectable. */
	$meta_attrs = '';
	$tier = sanitize_key( (string) ( $unit['measurement_tier'] ?? '' ) );
	if ( '' !== $tier ) {
		$meta_attrs .= ' data-go-ad-tier="' . esc_attr( $tier ) . '"';
	}
	$priority = go_verge_ads_unit_priority( $unit );
	if ( 'critical' === $priority ) {
		$meta_attrs .= ' data-go-ad-priority="critical"';
	}
	foreach ( (array) $args['data'] as $key => $value ) {
		$key = sanitize_key( (string) $key );
		if ( '' === $key || null === $value || '' === (string) $value ) {
			continue;
		}
		$meta_attrs .= ' data-go-' . esc_attr( $key ) . '="' . esc_attr( (string) $value ) . '"';
	}

	/* Baseline reservation. Responsive creatives may grow; this is not a CLS guarantee. */
	$reserve = (array) ( $unit['reserve'] ?? array() );
	$style   = sprintf(
		'--go-ad-reserve-mobile:%dpx;--go-ad-reserve-desktop:%dpx',
		absint( $reserve['mobile'] ?? 0 ),
		absint( $reserve['desktop'] ?? 0 )
	);

	/*
	 * Two shapes, chosen per unit.
	 *
	 * `fixed` follows Google's documented exact-size pattern for responsive
	 * units: `display:block` with an explicit width and height and no
	 * `data-ad-format`. Before requesting, the runtime writes the largest
	 * declared size that fits the measured host onto the `ins`. A deferred host
	 * may be reached after first paint; this is not a first-paint CLS guarantee.
	 *
	 * Everything else is responsive: `data-ad-format="auto"` with
	 * `data-full-width-responsive`, the standard responsive Display pattern.
	 * Available space and Google's demand determine the creative that is served.
	 */
	$fixed     = isset( $unit['sizing'] ) && 'fixed' === $unit['sizing'];
	$fluid     = isset( $unit['sizing'] ) && 'fluid' === $unit['sizing'];
	$multiplex = isset( $unit['sizing'] ) && 'multiplex' === $unit['sizing'];

	$ins_classes = array( 'adsbygoogle', 'go-ad-unit', 'go-ad-unit--' . $placement );
	if ( $fixed ) {
		$ins_classes[] = 'go-ad-unit--fixed';
	}
	$ins  = '<ins class="' . esc_attr( implode( ' ', $ins_classes ) ) . '"';
	$ins .= $fluid ? ' style="display:block;text-align:center"' : ' style="display:block"';
	$ins .= ' data-ad-client="' . esc_attr( GO_VERGE_ADSENSE_CLIENT ) . '"';
	$ins .= ' data-ad-slot="' . esc_attr( $unit['slot'] ) . '"';
	if ( ! $fixed ) {
		if ( $fluid && ! empty( $unit['ad_layout'] ) ) {
			$ins .= ' data-ad-layout="' . esc_attr( (string) $unit['ad_layout'] ) . '"';
		}
		$ins .= ' data-ad-format="' . esc_attr( (string) ( $unit['format'] ?? 'auto' ) ) . '"';
	}
	/*
	 * Full-width-responsive=true permits more frequent expansion to the mobile
	 * viewport when AdSense considers it appropriate. It does not guarantee
	 * expansion or an auction price; publisher CSS must leave the unit free to
	 * use the responsive geometry chosen by the provider.
	 */
	if ( ! $fixed && ! $fluid && ! $multiplex ) {
		$ins .= ' data-full-width-responsive="' . ( ! empty( $unit['full_width'] ) ? 'true' : 'false' ) . '"';
	}
	$ins .= '></ins>';

	/*
	 * The documented request. `push({})` queues into the array before
	 * adsbygoogle.js has loaded and the library drains it on arrival, so this
	 * runs correctly wherever it sits in the document.
	 *
	 * The optimizer attributes are not decoration: a combined or deferred copy of
	 * this line requests a slot whose geometry has already changed.
	 */
	$media = go_verge_ads_unit_media_query( $unit );
	$gate  = function_exists( 'go_verge_ads_requires_theme_consent_gate' ) && go_verge_ads_requires_theme_consent_gate();
	$near  = absint( $unit['near_viewport'] ?? 0 );
	$ins = '<template data-go-ad-pending>' . $ins . '</template>';
	$frequency = 'topscroll' === $placement ? go_verge_adsense_topscroll_config() : array();
	/* Reuse the compact request-options channel for runtime-only delivery hints. */
	$frequency['__near_max']   = absint( $unit['near_viewport_max'] ?? $near );
	$frequency['__predictive'] = ! empty( $unit['predictive'] );
	$frequency['__safety_ms']  = absint( $unit['safety_ms'] ?? 600 );
	$frequency['__tier']       = sanitize_key( (string) ( $unit['measurement_tier'] ?? '' ) );
	$frequency['__priority']   = $priority;
	$fixed_sizes = array();
	if ( $fixed ) {
		foreach ( (array) ( $unit['fixed_sizes'] ?? array() ) as $size ) {
			if ( is_array( $size ) && isset( $size[0], $size[1] ) && absint( $size[0] ) > 0 && absint( $size[1] ) > 0 ) {
				$fixed_sizes[] = array( absint( $size[0] ), absint( $size[1] ) );
			}
		}
	}
	$request_options = go_verge_ads_pending_request_options( $media, $gate, $fixed, $near, $frequency, $fixed_sizes, go_verge_ads_debug_enabled() );
	$meta_attrs .= ' data-go-ad-options="' . esc_attr( wp_json_encode( $request_options, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT ) ) . '"';
	$push = go_verge_ads_pending_request_script( $media, $gate, $fixed, $near, $frequency, $fixed_sizes, go_verge_ads_debug_enabled() );
	$script = '<script data-cfasync="false" data-no-optimize="1" data-no-defer="1">' . $push . '</script>';

	/*
	 * Publisher control, never part of the provider surface. It sits outside the
	 * <ins>, so it can never overlap the creative or be mistaken for part of it.
	 */
	$dismiss = '';
	if ( $dismissible ) {
		$dismiss  = '<button type="button" class="go-ad-slot__dismiss" data-go-ad-dismiss aria-label="' . esc_attr__( 'Fechar publicidade', 'go-verge' ) . '" title="' . esc_attr__( 'Fechar publicidade', 'go-verge' ) . '">';
		$dismiss .= '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" focusable="false"><path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>';
		$dismiss .= '</button>';
		$script  .= go_verge_ads_dismiss_runtime();
	}

	$label = '<span class="go-ad-slot__label">' . esc_html__( 'Publicidade', 'go-verge' ) . '</span>';

	/* Remove the initial reservation before JS runs at an excluded viewport.
	 * The matching media gate above prevents materialization/request. Once a
	 * mobile request exists, resize must preserve its provider node and space.
	 * Emit the rule with this host so filtered breakpoints cannot drift from CSS. */
	$viewport_style = '';
	if ( ! empty( $unit['max_viewport'] ) ) {
		$viewport_style = sprintf(
			'<style>@media(min-width:%dpx){body.go-verge .go-ad-slot--%s:not([data-go-ad-requested="1"]){display:none;min-block-size:0;margin-block:0;padding-block:0}}</style>',
			absint( $unit['max_viewport'] ) + 1,
			esc_attr( $placement )
		);
	}
	return $viewport_style . sprintf(
		'<%1$s class="%2$s" data-go-ad-placement="%3$s"%9$s%10$s style="%4$s">%5$s%6$s%7$s%8$s</%1$s>',
		esc_attr( $tag ),
		esc_attr( implode( ' ', array_unique( $classes ) ) ),
		esc_attr( $placement ),
		esc_attr( $style ),
		$dismiss, // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed accessible control, labels escaped above.
		$label,   // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher disclosure, escaped above.
		$ins,     // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- attributes escaped above.
		$script,  // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed provider call, media query JSON-encoded.
		$sizing_attr, // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed literal.
		$meta_attrs // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- keys sanitized, values escaped above.
	);
}

/**
 * Canonical options for inline mounts and scans of inert publisher fragments.
 * Building these values does not request an ad or activate pending markup.
 *
 * @return array Runtime mount options.
 */
function go_verge_ads_pending_request_options( $media, $gate, $fixed = false, $near = 0, $frequency = array(), $fixed_sizes = array(), $debug = false ) {
	return array(
		'media'        => (string) $media,
		'gate'         => (bool) $gate,
		'fixed'        => (bool) $fixed,
		'near'         => absint( $near ),
		'nearMax'      => absint( $frequency['__near_max'] ?? 0 ),
		'predictive'   => ! empty( $frequency['__predictive'] ),
		'safetyMs'     => absint( $frequency['__safety_ms'] ?? 0 ),
		'tier'         => sanitize_key( (string) ( $frequency['__tier'] ?? '' ) ),
		'priority'     => 'critical' === ( $frequency['__priority'] ?? '' ) ? 'critical' : 'normal',
		'frequencyMax' => absint( $frequency['frequency_max'] ?? 0 ),
		'smartFrequency' => ! empty( $frequency['smart_engagement'] ),
		'smartFreeFills' => absint( $frequency['smart_free_fills'] ?? 4 ),
		'smartFifthPages' => absint( $frequency['smart_fifth_pages'] ?? 3 ),
		'smartFifthMs' => absint( $frequency['smart_fifth_active_ms'] ?? 60000 ),
		'smartSixthPages' => absint( $frequency['smart_sixth_pages'] ?? 4 ),
		'smartSixthMs' => absint( $frequency['smart_sixth_active_ms'] ?? 120000 ),
		'smartSessionIdleMs' => absint( $frequency['smart_session_idle_ms'] ?? 1800000 ),
		'sizes'        => array_values( (array) $fixed_sizes ),
		'debug'        => (bool) $debug,
	);
}

/** Mount already-rendered markup with the same options used by dynamic scans. */
function go_verge_ads_pending_request_script( $media, $gate, $fixed = false, $near = 0, $frequency = array(), $fixed_sizes = array(), $debug = false ) {
	$options = go_verge_ads_pending_request_options( $media, $gate, $fixed, $near, $frequency, $fixed_sizes, $debug );
	$json = wp_json_encode( $options, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT );
	return '(function(s,o){function mount(){if(window.GOAdsRuntime){window.GOAdsRuntime.mount(s&&s.parentElement,o);}}if(window.GOAdsRuntime){mount();}else{document.addEventListener("go:ads-runtime-ready",mount,{once:true});}})(document.currentScript,' . $json . ');';
}

/**
 * The close control's behaviour, printed at most once per document.
 *
 * Delegated from the document so it costs one listener no matter how many
 * dismissible units exist, and it closes the unit for this page view only. It
 * never creates a persistent dismissal. The independent Top Scroll quota
 * records actual fills only when storage permission is available.
 *
 * @return string
 */
function go_verge_ads_dismiss_runtime() {
	static $printed = false;

	if ( $printed ) {
		return '';
	}
	$printed = true;

	return '<script data-cfasync="false" data-no-optimize="1" data-no-defer="1">'
		. 'document.addEventListener("click",function(e){'
		. 'var t=e.target;if(!t||!t.closest)return;'
		. 'var b=t.closest("[data-go-ad-dismiss]");if(!b)return;'
		. 'var s=b.closest(".go-ad-slot");if(s){s.hidden=true;if(window.GOAdsRuntime&&window.GOAdsRuntime.dismiss){window.GOAdsRuntime.dismiss(s);}}'
		. '});'
		. '</script>';
}

/**
 * Echo one unit.
 *
 * @param string              $placement Placement key.
 * @param array<string,mixed> $args      Markup arguments.
 * @return void
 */
function go_verge_render_adsense_unit( $placement, $args = array() ) {
	echo go_verge_adsense_unit_markup( $placement, $args ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built and escaped in go_verge_adsense_unit_markup().
}
