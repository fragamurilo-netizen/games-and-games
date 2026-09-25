<?php
/**
 * LiteSpeed Cache compatibility for Overdrive.
 *
 * The site is ad-heavy and image-led. These filters keep revenue-critical
 * JavaScript out of LSCache's minify/combine/defer/delay pipelines and mark
 * explicitly eager images so LiteSpeed lazy-load never rewrites the LCP.
 *
 * This file only registers public LiteSpeed hooks; when the plugin is absent
 * the filters are harmless no-ops.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * JavaScript fragments that must preserve their original execution timing.
 *
 * LiteSpeed documents these public filters for JS optimization, deferred /
 * delayed JS and Guest Mode exclusions. Partial matches are intentional.
 *
 * @param array<int,string>|mixed $excludes Existing exclusion list.
 * @return array<int,string>
 */
function go_verge_litespeed_revenue_js_excludes( $excludes ) {
	$excludes = is_array( $excludes ) ? $excludes : array();

	$critical = array(
		// Canonical AdSense bootstrap shared by Auto Ads and manual inventory.
		'pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
		'adsbygoogle.js',
		'GOAdsRuntime',
		'go-ads-manual-runtime',
		'GOAdsYieldConfig',
		'go-ads-yield-config',
		'go-ads-runtime',

		// Preserve native Burst tracking, including its inline configuration.
		'/burst-statistics/',
		'/burst-statistics-pro/',
		'/uploads/burst/',
		'burst.min.js',
		'burst-cookieless',
		'burst-goals',
		'timeme',
		'burst_options',
		'burstOptions',
		'burst-js-extra',
		'var burst =',

		/* The per-unit request printed next to each ins by inc/ads/renderer.php.
		 * Combining or deferring it requests a slot whose geometry has already
		 * changed, or drops the request entirely. The tags also carry
		 * data-no-optimize/data-no-defer; this is the second lock. */
		'adsbygoogle=window.adsbygoogle',
		'adsbygoogle||[]',

		/* Clever: the first-access decision must run before <body> is parsed, the
		 * controller before the loader, and the loader itself stays async and in
		 * place so the anchor's rotation matches what the head script predicted. */
		'cleverwebserver.com',
		'CleverCoreLoader',
		'clever-core',
		'GOCleverConfig',
		'go-clever-first-access',
		'go-clever-controller',

		// Consent ownership must be published before anything advertising runs.
		'GOAdsConsent',
		'go-ads-consent-reader',
		'go-ads-consent-loader-gate',

		/* Jetpack's subscription bundle calls window.wp.domReady as soon as its
		 * deferred script runs. LiteSpeed was interaction-delaying wp-dom-ready
		 * while leaving the consumer as ordinary defer, producing a deterministic
		 * TypeError and breaking the dependency contract. Keep this small pair in
		 * WordPress's original order. */
		'wp-dom-ready',
		'jetpack-block-subscriptions',

		/* Preserve GA4/GTM's native async timing. LiteSpeed interaction-delay can
		 * otherwise miss readers who land, read briefly and leave without the
		 * event that releases delayed JavaScript. No measurement ID is created or
		 * duplicated here; the existing analytics provider remains authoritative. */
		'googletagmanager.com/gtag/js',
		'googletagmanager.com/gtm.js',
		'google-analytics.com/g/collect',
		'gtag/js?id=',
		"gtag('config'",
		'gtag("config"',
		"gtag('js'",
		'gtag("js"',
	);

	return array_values( array_unique( array_merge( $excludes, $critical ) ) );
}
add_filter( 'litespeed_optimize_js_excludes', 'go_verge_litespeed_revenue_js_excludes', 20 );
add_filter( 'litespeed_optm_js_defer_exc', 'go_verge_litespeed_revenue_js_excludes', 20 );
add_filter( 'litespeed_optm_gm_js_exc', 'go_verge_litespeed_revenue_js_excludes', 20 );

/**
 * Keep the theme's machine-readable endpoints out of page optimization.
 *
 * All XML sitemap routes mark themselves non-cacheable through LiteSpeed's
 * cache-control API. This URI list additionally bypasses page optimization.
 *
 * @param array<int,string>|mixed $excludes Existing URI exclusions.
 * @return array<int,string>
 */
function go_verge_litespeed_uri_excludes( $excludes ) {
	$excludes = is_array( $excludes ) ? $excludes : array();
	$excludes[] = '^/news-sitemap.xml$';
	$excludes[] = '^/sitemap.xml$';
	$excludes[] = '^/sitemap-[^/]+\.xml$';
	return array_values( array_unique( $excludes ) );
}
add_filter( 'litespeed_optm_uri_exc', 'go_verge_litespeed_uri_excludes', 20 );

/**
 * Site Health: detect accidental duplicate full-stack SEO / News sitemap tools.
 *
 * @param array<string,mixed> $tests Site Health tests.
 * @return array<string,mixed>
 */
function go_verge_register_stack_health_test( $tests ) {
	$tests['direct']['go_verge_free_seo_stack'] = array(
		'label' => __( 'Stack gratuito de SEO e performance', 'go-verge' ),
		'test'  => 'go_verge_free_seo_stack_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_stack_health_test' );

/** Return the SEO/performance stack status used by Site Health. */
function go_verge_free_seo_stack_health_test() {
	$rank_math = defined( 'RANK_MATH_VERSION' ) || class_exists( 'RankMath' );
	$litespeed = defined( 'LSCWP_V' ) || defined( 'LSCWP_DIR' ) || class_exists( 'LiteSpeed\\Core' );

	$conflicts = array();
	if ( defined( 'WPSEO_VERSION' ) ) {
		$conflicts[] = 'Yoast SEO';
	}
	if ( defined( 'SEOPRESS_VERSION' ) ) {
		$conflicts[] = 'SEOPress';
	}
	if ( defined( 'AIOSEO_VERSION' ) ) {
		$conflicts[] = 'AIOSEO';
	}

	$duplicate_news = defined( 'XMLSF_VERSION' ) || class_exists( 'XMLSF\\Core' );
	$issues         = array();
	if ( ! $rank_math ) {
		$issues[] = __( 'Rank Math Free não foi detectado.', 'go-verge' );
	}
	if ( ! $litespeed ) {
		$issues[] = __( 'LiteSpeed Cache não foi detectado.', 'go-verge' );
	}
	if ( $conflicts ) {
		$issues[] = sprintf(
			/* translators: %s: SEO plugin names. */
			__( 'Há outro plugin SEO completo ativo: %s.', 'go-verge' ),
			implode( ', ', $conflicts )
		);
	}
	if ( $duplicate_news ) {
		$issues[] = __( 'XML Sitemap & Google News foi detectado; o tema já fornece o News Sitemap e não precisa dele.', 'go-verge' );
	}

	$good = empty( $issues );
	return array(
		'label'       => $good
			? __( 'O stack gratuito recomendado está sem conflitos', 'go-verge' )
			: __( 'Revise o stack gratuito de SEO e performance', 'go-verge' ),
		'status'      => $good ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Overdrive', 'go-verge' ), 'color' => 'blue' ),
		'description' => $good
			? '<p>' . esc_html__( 'Rank Math e LiteSpeed Cache foram detectados; o tema mantém seu próprio News Sitemap e protege LCP e scripts de publicidade das otimizações agressivas.', 'go-verge' ) . '</p>'
			: '<p>' . esc_html( implode( ' ', $issues ) ) . '</p>',
		'actions'     => '<p>' . esc_html__( 'Use apenas um plugin SEO completo. Para links quebrados, prefira o motor em nuvem do Broken Link Checker para não consumir PHP/MySQL do servidor.', 'go-verge' ) . '</p>',
		'test'        => 'go_verge_free_seo_stack',
	);
}


/**
 * Purge anonymous LiteSpeed page/asset caches once per deployed theme version.
 *
 * Ad delivery logic lives in both PHP markup and versioned JS. Logged-in requests
 * commonly bypass full-page cache, so a stale anonymous document can otherwise
 * keep running the previous yield contract after an update. One option stores the
 * last purged version instead of accumulating a new option forever.
 */
function go_verge_litespeed_purge_theme_version_once() {
	$version = defined( 'GO_VERGE_VERSION' ) ? (string) GO_VERGE_VERSION : '';
	if ( '' === $version || (string) get_option( 'go_verge_litespeed_last_purged_version', '' ) === $version ) {
		return;
	}

	update_option( 'go_verge_litespeed_last_purged_version', $version, false );
	if ( defined( 'LSCWP_V' ) || defined( 'LSCWP_DIR' ) || class_exists( 'LiteSpeed\\Core' ) ) {
		do_action( 'litespeed_purge_all' );
	}
}
add_action( 'init', 'go_verge_litespeed_purge_theme_version_once', 2 );
