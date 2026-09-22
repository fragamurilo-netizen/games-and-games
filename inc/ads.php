<?php
/**
 * Overdrive advertising delivery.
 *
 * Delivery model: MANUAL in-page with official provider overlays.
 *
 * The theme owns every in-page opportunity. The shared provider loader also
 * serves official anchor and vignette formats. Account controls are separate;
 * no local setting enables automatic in-page insertion.
 *
 * Where each decision lives:
 *   config.php     the ad units, and the single rule table the browser obeys;
 *   calendar-trials.php  which arm of a running trial today belongs to, decided
 *                  from the calendar alone -- never from the reader;
 *   planner.php    WHERE an in-article opportunity may exist (structure only);
 *   composer.php   turning approved opportunities into markup, plus the
 *                  listing pool that feeds home and archive streams;
 *   renderer.php   one inert `ins` + one mount call per placement;
 *   loader.php     the one AdSense bootstrap on the page;
 *   economics.php  seven-day per-unit value from data the Ads Center synced;
 *   yield.php      the site's economic state, and the money-free signal the
 *                  browser receives;
 *   go-ads-runtime.js  WHETHER and WHEN each opportunity becomes a request.
 *
 * Nothing in this layer refreshes, retries or re-requests a placement, hides a
 * paid creative, fabricates an impression or touches Google's auction.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

foreach ( array( 'mode', 'config', 'calendar-trials', 'economics', 'yield', 'context', 'consent', 'renderer', 'planner', 'composer', 'loader', 'topscroll', 'assets' ) as $go_verge_ads_module ) {
	require_once GO_VERGE_DIR . '/inc/ads/' . $go_verge_ads_module . '.php';
}
unset( $go_verge_ads_module );

/* Diagnostics are intentionally absent from anonymous requests. */
if ( is_admin() ) {
	require_once GO_VERGE_DIR . '/inc/ads/topscroll-admin.php';
	require_once GO_VERGE_DIR . '/inc/ads/health.php';
	require_once GO_VERGE_DIR . '/inc/ads/dashboard.php';
}
if ( is_user_logged_in() && current_user_can( 'manage_options' ) ) {
	require_once GO_VERGE_DIR . '/inc/ads/diagnostics.php';
}

// One shared GOAC engine: the optional plugin takes precedence over the bundled provider.
require_once GO_VERGE_DIR . "/inc/ads-center/bootstrap.php";
