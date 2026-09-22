<?php
/**
 * Request hygiene & hardening.
 *
 * The practical cure for the "429 / too many requests" a WordPress news site
 * hits on shared hosting: cut off the endpoints bots hammer (XML-RPC, pingback
 * flooding, author-enumeration scans) and calm WordPress's own background
 * chatter (Heartbeat, self-pings). Less junk traffic = fewer host rate-limits,
 * plus a tighter attack surface.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/* -------------------------------------------------------------------------
 * XML-RPC — a top brute-force / amplification vector. Off entirely.
 * ---------------------------------------------------------------------- */

add_filter( 'xmlrpc_enabled', '__return_false' );
add_filter( 'xmlrpc_methods', '__return_empty_array', 99 );
// Drop the X-Pingback header and RSD link that advertise xmlrpc.php.
add_filter( 'wp_headers', function ( $headers ) {
	unset( $headers['X-Pingback'] );
	return $headers;
}, 11 );
remove_action( 'wp_head', 'rsd_link' );
remove_action( 'wp_head', 'wlwmanifest_link' );
remove_action( 'wp_head', 'wp_generator' );

/* -------------------------------------------------------------------------
 * Pingbacks / trackbacks — disable the self-ping storm and inbound spam.
 * ---------------------------------------------------------------------- */

// Strip the pingback URL WordPress advertises in the head.
add_filter( 'bloginfo_url', function ( $output, $property ) {
	return ( 'pingback_url' === $property ) ? '' : $output;
}, 10, 2 );

// Kill inbound pingback/trackback methods.
add_filter( 'xmlrpc_methods', function ( $methods ) {
	unset( $methods['pingback.ping'], $methods['pingback.extensions.getPingbacks'] );
	return $methods;
}, 100 );

// Stop a post from pinging its own internal links on publish.
function go_verge_no_self_ping( &$links ) {
	$home = home_url();
	foreach ( array_keys( $links ) as $i ) {
		if ( 0 === strpos( $links[ $i ], $home ) ) {
			unset( $links[ $i ] );
		}
	}
}
add_action( 'pre_ping', 'go_verge_no_self_ping' );

/* -------------------------------------------------------------------------
 * Author-enumeration scans (?author=N) — bots use these to harvest logins,
 * then brute-force them, generating the request floods that trip 429s.
 * ---------------------------------------------------------------------- */

function go_verge_block_author_enumeration() {
	if ( is_admin() || is_user_logged_in() ) {
		return;
	}
	if ( isset( $_GET['author'] ) && preg_match( '/^\d+$/', (string) wp_unslash( $_GET['author'] ) ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		wp_safe_redirect( home_url( '/' ), 301 );
		exit;
	}
}
// Priority 0: run before core redirect_canonical (10), which would otherwise
// leak the username by redirecting ?author=N to /author/{slug}/.
add_action( 'template_redirect', 'go_verge_block_author_enumeration', 0 );

// Remove the REST users endpoints for anonymous requests (same enumeration).
function go_verge_restrict_rest_users( $endpoints ) {
	if ( is_user_logged_in() ) {
		return $endpoints;
	}
	foreach ( array( '/wp/v2/users', '/wp/v2/users/(?P<id>[\d]+)' ) as $route ) {
		if ( isset( $endpoints[ $route ] ) ) {
			unset( $endpoints[ $route ] );
		}
	}
	return $endpoints;
}
add_filter( 'rest_endpoints', 'go_verge_restrict_rest_users' );

// Don't leak the author slug through the REST oEmbed response either.
add_filter( 'oembed_response_data', function ( $data ) {
	unset( $data['author_url'], $data['author_name'] );
	return $data;
} );

/* -------------------------------------------------------------------------
 * Calm background chatter.
 * ---------------------------------------------------------------------- */

// Slow the admin Heartbeat (default 15s → 60s) to cut admin-ajax load.
add_filter( 'heartbeat_settings', function ( $settings ) {
	$settings['interval'] = 60;
	return $settings;
} );

// Disable Heartbeat entirely on the frontend, where it serves no purpose.
add_action( 'init', function () {
	if ( ! is_admin() ) {
		wp_deregister_script( 'heartbeat' );
	}
}, 1 );

/*
 * One query for the theme's guard options instead of one query each.
 *
 * Release migrations and background schedulers check their own non-autoloaded
 * flag on every request: about forty on each admin request (every admin-ajax
 * poll and Heartbeat included) and a handful on every public, REST and cron
 * request. Measured in the lab, those single-option reads were ~45 of the 103
 * queries of an admin-ajax poll. Priming the names in one IN() query leaves every
 * callback and its decision untouched; options that do not exist are cached as
 * absent, which is exactly what the guards read.
 */
function go_verge_prime_guard_options( array $names ) {
	if ( function_exists( 'wp_prime_option_caches' ) ) {
		wp_prime_option_caches( $names );
	}
}

add_action( 'init', function () {
	go_verge_prime_guard_options( array(
		'can_compress_scripts',
		'go_product_schema_version',
		'go_verge_linkpop_backfill_done',
		'go_verge_litespeed_last_purged_version',
		'go_verge_semantic_backfill_complete_v68',
		'go_verge_semantic_backfill_scheduler_v3151',
		'go_verge_subject_entity_cluster_done',
	) );
}, PHP_INT_MIN );

add_action( 'admin_init', function () {
	go_verge_prime_guard_options( array(
		'go_pv_schema',
		'go_pv_sync_error',
		'go_pv_bootstrapped',
		'goac_version',
		'go_smart_sitemap_output_version',
		'go_overdrive_about_slug_v2',
		'go_overdrive_complete_rebrand_v4',
		'go_overdrive_google_human_site_name_v1',
		'go_overdrive_google_site_name_fallback_v1',
		'go_overdrive_rebrand_residual_v5',
		'go_overdrive_rebrand_v1',
		'go_overdrive_search_brand_v1',
		'go_overdrive_single_brand_identity_v1',
		'go_overdrive_taxonomy_brand_v1',
		'go_verge_accessibility_page_prepared_v1',
		'go_verge_ai_tag_cleanup_v3',
		'go_verge_arch_v7_migration',
		'go_verge_authority_copy_v5',
		'go_verge_bundle_cache_policy_v3152',
		'go_verge_category_indexing_parity_version',
		'go_verge_commercial_pages_v1',
		'go_verge_content_type_repair_v3152',
		'go_verge_content_type_vocab_v3152',
		'go_verge_editorial_scope_about_v4',
		'go_verge_final_explicado_v1',
		'go_verge_follow_schema_v47',
		'go_verge_game_intelligence_revalidated_v6',
		'go_verge_human_sitemap_schema',
		'go_verge_institutional_copy_v2',
		'go_verge_institutional_publish_v3',
		'go_verge_news_authority_rewrite_version',
		'go_verge_platform_consolidation_v24',
		'go_verge_platform_truth_version',
		'go_verge_product_pages_version',
		'go_verge_rewrites_flushed',
		'go_verge_rewrites_v25',
		'go_verge_subject_rewrite_v45',
		'go_verge_tag_consolidation_version',
		'go_verge_technology_indexing_hardening_version',
		'go_verge_technology_taxonomy_repair_version',
		'go_verge_topic_rewrite_v21',
		'go_verge_trust_pages_prepared_v1',
		'go_verge_v7_redirect_targets_v355',
	) );
}, PHP_INT_MIN );

add_action( 'template_redirect', function () {
	go_verge_prime_guard_options( array(
		'go_verge_v7_redirects',
		'go_verge_v24_platform_redirects',
		'go_verge_tag_dynamic_alias_redirects',
		'go_verge_cache_integrity_state',
		'go_verge_adsense_topscroll',
		'go_verge_publisher_identity',
		'site_logo',
		'medium_crop',
		'medium_large_crop',
		'large_crop',
	) );
}, PHP_INT_MIN );

// Trim the emoji detection script/loader — bytes and a request saved sitewide.
remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
remove_action( 'wp_print_styles', 'print_emoji_styles' );
remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
remove_action( 'admin_print_styles', 'print_emoji_styles' );
