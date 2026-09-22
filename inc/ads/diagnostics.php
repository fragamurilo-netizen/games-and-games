<?php
/**
 * Manager-only, on-demand advertising diagnostics.
 *
 * Adds "Anúncios: diagnóstico" to the admin bar on monetizable front-end views.
 * The inspector reads GOAdsRuntime.inspect() locally (state, geometry, request
 * size and timings per manual placement); it sends nothing to the server and
 * never reads creative iframes. The article report also works when only Auto
 * Ads is selected. It observes the live document; it does not prove account
 * settings, Google crawl state, Active View or revenue.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** @param WP_Admin_Bar $bar Admin bar. */
function go_verge_ads_diagnostics_toolbar( $bar ) {
	if ( is_admin() || ! current_user_can( 'manage_options' ) || ! function_exists( 'go_verge_ads_is_monetizable_request' ) || ! go_verge_ads_is_monetizable_request() ) {
		return;
	}
	$bar->add_node( array( 'id' => 'go-ads-inspect', 'title' => 'Anúncios: diagnóstico', 'href' => '#go-ads-inspect' ) );
}
add_action( 'admin_bar_menu', 'go_verge_ads_diagnostics_toolbar', 110 );

function go_verge_ads_diagnostics_assets() {
	if ( is_admin() || ! is_user_logged_in() || ! current_user_can( 'manage_options' ) || ! function_exists( 'go_verge_ads_is_monetizable_request' ) || ! go_verge_ads_is_monetizable_request() ) {
		return;
	}
	$rel = '/assets/js/go-ads-recovery-diagnostics.js';
	wp_enqueue_script( 'go-ads-diagnostics', GO_VERGE_URI . $rel, array(), go_verge_asset_version( $rel ), true );
	$config = function_exists( 'go_verge_ads_config' ) ? (array) go_verge_ads_config() : array();
	wp_add_inline_script( 'go-ads-diagnostics', 'window.GOAdsDiagnosticsConfig=' . wp_json_encode( array(
		'themeVersion' => defined( 'GO_VERGE_VERSION' ) ? GO_VERGE_VERSION : '',
		'deliveryMode' => (string) ( $config['delivery_mode'] ?? 'unknown' ),
	) ) . ';', 'before' );
}
add_action( 'wp_enqueue_scripts', 'go_verge_ads_diagnostics_assets', 47000 );
