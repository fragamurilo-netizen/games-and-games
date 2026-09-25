<?php
/**
 * Consent bridge.
 *
 * The theme does not implement a consent banner. Google's certified CMP/TCF
 * remains authoritative. A local hard gate is optional and disabled by default.
 * The tiny reader is printed only when a theme feature actually needs a local
 * consent signal (hard gate or an explicit Top Scroll local frequency cap).
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function go_verge_ads_requires_theme_consent_gate() {
	$default = defined( 'GO_VERGE_ADS_THEME_CONSENT_GATE' ) ? (bool) GO_VERGE_ADS_THEME_CONSENT_GATE : false;
	return (bool) apply_filters( 'go_verge_ads_requires_theme_consent_gate', $default );
}

function go_verge_ads_needs_local_consent_reader() {
	if ( go_verge_ads_requires_theme_consent_gate() ) {
		return true;
	}
	if ( function_exists( 'go_verge_adsense_topscroll_config' ) ) {
		$config = go_verge_adsense_topscroll_config();
		return absint( $config['frequency_max'] ?? 0 ) > 0;
	}
	return defined( 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT' ) && absint( GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT ) > 0;
}

function go_verge_ads_consent_reader() {
	if ( is_admin() || is_feed() || ! go_verge_ads_needs_local_consent_reader() ) {
		return;
	}
	$reader = GO_VERGE_DIR . '/assets/js/go-ads-consent.js';
	if ( ! is_readable( $reader ) ) {
		return;
	}
	echo '<script id="go-ads-consent-reader" data-cfasync="false" data-no-optimize="1" data-no-defer="1">';
	echo file_get_contents( $reader ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- static local source.
	echo "</script>\n";
}
add_action( 'wp_head', 'go_verge_ads_consent_reader', 0 );
