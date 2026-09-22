<?php
/**
 * Which image formats this server can actually deliver to Google.
 *
 * `go_verge_block_avif_uploads()` in functions.php stops NEW articles from
 * entering the broken state this host creates for AVIF. It does nothing for the
 * back catalogue: every post whose featured image was uploaded as AVIF before
 * 18/08/2026 still points at a file the server answers with
 * `Content-Type: text/plain` and `nosniff`, and still has no sub-sizes, because
 * neither failure is a property of the upload. Both are properties of the
 * server, and they apply to files already on disk.
 *
 * That matters in exactly one place, and it is the place that pays. Google
 * Discover only distributes a story it can render with a large image. The
 * og:image chain already refused AVIF (`go_verge_og_image_format_supported()`),
 * so those articles shipped with no share image at all; the schema chain did
 * not, so `Article.image` kept naming a file Google's image pipeline drops, and
 * the Site Health readiness signal kept measuring pixels and reporting green.
 * Three answers to one question, none of them wrong on its own terms.
 *
 * This file is the single answer. It is deliberately dependency-light so the
 * og:image chain, the schema chain and the health checks can all reach it, and
 * so it can be exercised without booting the theme.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Whether a file of this format arrives intact at a consumer that reads
 * `Content-Type` instead of sniffing bytes.
 *
 * Derived from the same signal that governs uploads, so a server that starts
 * serving `image/avif` correctly re-enables uploads, schema images and the
 * readiness signal together, with one filter:
 *
 *     add_filter( 'go_verge_allow_avif_uploads', '__return_true' );
 *
 * SVG is excluded for a different and permanent reason: it is not a photograph
 * and Google does not use it as a Discover or large-preview asset, so naming
 * one as an article's representative image is a silent way to have none.
 *
 * @param string $url Image URL or path.
 * @return bool
 */
function go_verge_image_format_deliverable( $url ) {
	$path = function_exists( 'wp_parse_url' )
		? wp_parse_url( (string) $url, PHP_URL_PATH )
		: parse_url( (string) $url, PHP_URL_PATH ); // phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
	$ext = strtolower( (string) pathinfo( (string) $path, PATHINFO_EXTENSION ) );
	if ( '' === $ext ) {
		return false;
	}

	$blocked = array( 'svg', 'svgz', 'jxl', 'heic', 'heif', 'tif', 'tiff' );
	if ( ! apply_filters( 'go_verge_allow_avif_uploads', false ) ) {
		$blocked[] = 'avif';
		$blocked[] = 'avifs';
	}

	/**
	 * Filter the formats treated as undeliverable to Google's image pipeline.
	 *
	 * @param string[] $blocked Lower-case extensions.
	 * @param string   $url     Image URL being tested.
	 */
	$blocked = (array) apply_filters( 'go_verge_undeliverable_image_formats', $blocked, (string) $url );

	return ! in_array( $ext, $blocked, true );
}
