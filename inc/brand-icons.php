<?php
/** Canonical Overdrive favicon and publisher logo identity. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Stable URLs shared by the browser, WordPress and publisher schema. */
function go_verge_brand_icon_url( $size = 512 ) {
	$base = trailingslashit( get_template_directory_uri() ) . 'assets/img/brand/multicolor-v2/';
	$size = absint( $size );
	if ( 180 === $size ) {
		return $base . 'apple-touch-icon.png';
	}
	if ( $size <= 48 ) {
		return $base . 'serp-icon-48.png';
	}
	if ( $size <= 192 ) {
		return $base . 'serp-icon-192.png';
	}
	return $base . 'serp-icon-512.png';
}

/**
 * Emit one deterministic Overdrive favicon family on every public page.
 *
 * Google Search supports one favicon per host and recommends a stable, square
 * resource larger than 48x48.  We therefore do not let an old WordPress Site
 * Icon or the legacy SVG compete with the approved SERP artwork: every rel=icon
 * points to the same square, opaque Overdrive mark supplied by the newsroom.
 */
function go_verge_brand_favicon_head() {
	if ( is_admin() ) {
		return;
	}

	printf( '<link rel="icon" href="%1$s" sizes="512x512" type="image/png">' . "\n", esc_url( go_verge_brand_icon_url() ) );
	printf( '<link rel="apple-touch-icon" href="%1$s" sizes="180x180">' . "\n", esc_url( go_verge_brand_icon_url( 180 ) ) );
	printf( '<meta name="msapplication-TileImage" content="%1$s">' . "\n", esc_url( go_verge_brand_icon_url() ) );
}
add_action( 'wp_head', 'go_verge_brand_favicon_head', 2 );

/**
 * Keep WordPress core, schema and browser icon requests on the official kit.
 *
 * @param string $url     Core-resolved Site Icon URL.
 * @param int    $size    Requested square size.
 * @param int    $blog_id Site ID in multisite.
 * @return string
 */
function go_verge_brand_site_icon_url( $url, $size, $blog_id ) {
	unset( $url, $blog_id );
	return go_verge_brand_icon_url( $size );
}
add_filter( 'get_site_icon_url', 'go_verge_brand_site_icon_url', 20, 3 );
