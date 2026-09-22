<?php
/**
 * Overdrive 3.81.35 — Compare CTA copy guard.
 *
 * The Compare plugin owns the CTA data, but older/generated copies can still
 * output the malformed Portuguese plural "Celulars". Correct it at the final
 * content boundary so cached articles render the proper label immediately.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Fix malformed Compare labels without touching stored post content.
 *
 * @param string $content Rendered post content.
 * @return string
 */
function go_verge_fix_compare_copy_38135( $content ) {
	if ( ! is_string( $content ) || '' === $content ) {
		return $content;
	}

	if ( false === stripos( $content, 'Overdrive Compare' ) || false === stripos( $content, '/compara' ) ) {
		return $content;
	}

	return str_replace(
		array( 'Celulars', 'celulars' ),
		array( 'Celulares', 'celulares' ),
		$content
	);
}
add_filter( 'the_content', 'go_verge_fix_compare_copy_38135', 999 );
