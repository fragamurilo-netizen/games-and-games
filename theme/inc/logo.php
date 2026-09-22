<?php
/**
 * Overdrive Multicolor v2.0. Gradient artwork is rendered as an image document:
 * internal clip/gradient IDs stay isolated, including in the footer.
 * The header and offcanvas use dark surfaces in both page themes.
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Inline the small, trusted theme-owned SVG; cache once per request. */
function go_verge_logo_inline_src( $file ) {
	static $cache = array();

	$file = basename( (string) $file );
	if ( isset( $cache[ $file ] ) ) {
		return $cache[ $file ];
	}

	$url  = GO_VERGE_URI . '/assets/img/brand/multicolor-v2/' . $file;
	$path = GO_VERGE_DIR . '/assets/img/brand/multicolor-v2/' . $file;

	if ( ! is_readable( $path ) || 'svg' !== strtolower( (string) pathinfo( $file, PATHINFO_EXTENSION ) ) ) {
		$cache[ $file ] = $url;
		return $url;
	}

	$svg = (string) file_get_contents( $path ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
	if ( '' === trim( $svg ) || false === stripos( $svg, '<svg' ) ) {
		$cache[ $file ] = $url;
		return $url;
	}

	/* An <img> renders the SVG in its own document: no prolog, no comments. */
	$svg = preg_replace( '/<\?xml[^>]*\?>/i', '', $svg );
	$svg = preg_replace( '/<!--.*?-->/s', '', $svg );
	$svg = trim( preg_replace( '/\s+/', ' ', $svg ) );

	/* A 3 KB ceiling before encoding would defeat the purpose; a 40 KB one
	 * guards against someone dropping a traced bitmap in this directory. */
	if ( strlen( $svg ) > 40000 ) {
		$cache[ $file ] = $url;
		return $url;
	}

	$encoded = strtr(
		rawurlencode( $svg ),
		array(
			/* Restore the characters a data: URI accepts verbatim. Every one of
			 * them is common in path data, so this is most of the size win. */
			'%20' => ' ',
			'%3D' => '=',
			'%3A' => ':',
			'%2F' => '/',
			'%2C' => ',',
			'%28' => '(',
			'%29' => ')',
			'%2E' => '.',
			'%2D' => '-',
			'%5F' => '_',
		)
	);

	$cache[ $file ] = 'data:image/svg+xml;charset=utf-8,' . $encoded;

	return $cache[ $file ];
}

/**
 * Build the logo lockup markup for a given context.
 * $variant: 'full' (header/footer/masthead — icon + wordmark) or
 *           'icon' (offcanvas/tight spaces — icon only).
 */
function go_verge_render_logo( $variant = 'full' ) {
    $icon = 'icon' === $variant;
    if ( $icon ) {
        return sprintf(
            '<span class="go-logo go-logo--icon go-brand"><img class="go-brand-image go-brand-image--symbol" src="%1$s" alt="%2$s" width="102" height="112" decoding="async"></span>',
            esc_attr( go_verge_logo_inline_src( 'symbol.svg' ) ),
            esc_attr( GO_VERGE_BRAND_WORDMARK )
        );
    }
    return sprintf(
        '<span class="go-logo go-logo--full go-brand">'
        . '<img class="go-brand-image go-brand-image--dark" src="%1$s" alt="%3$s" width="768" height="182" loading="eager" decoding="async">'
        . '<img class="go-brand-image go-brand-image--light" src="%2$s" alt="%3$s" width="768" height="182" loading="eager" decoding="async">'
        . '</span>',
        esc_attr( go_verge_logo_inline_src( 'logo-dark.svg' ) ),
        esc_attr( go_verge_logo_inline_src( 'logo-light.svg' ) ),
        esc_attr( GO_VERGE_BRAND_WORDMARK )
    );
}

/**
 * Full lockup (symbol + Overdrive wordmark) - header, footer and masthead.
 */
function go_verge_logo_compact( $echo = true ) {
	$markup = go_verge_render_logo( 'full' );
	if ( ! $echo ) {
		return $markup;
	}
	echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts above.
}

/**
 * Same full lockup, used at hero scale on the homepage masthead.
 */
function go_verge_logo_large( $echo = true ) {
	$markup = go_verge_render_logo( 'full' );
	if ( ! $echo ) {
		return $markup;
	}
	echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts above.
}

/**
 * Icon-only mark — offcanvas and other tight spaces.
 */
function go_verge_logo_icon( $echo = true ) {
	$markup = go_verge_render_logo( 'icon' );
	if ( ! $echo ) {
		return $markup;
	}
	echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts above.
}

/**
 * Text-only "OVERDRIVE" fallback for legacy templates. Current public
 * lockups use the official SVG artwork above.
 */
function go_verge_wordmark_text( $echo = true ) {
	$upper = strtoupper( GO_VERGE_BRAND_WORDMARK );
	$pos   = stripos( $upper, 'OVER' );

	if ( false === $pos ) {
		$markup = '<span class="go-wordmark-text">' . esc_html( $upper ) . '</span>';
	} else {
		$before = substr( $upper, 0, $pos );
		$match  = substr( $upper, $pos, 4 );
		$after  = substr( $upper, $pos + 4 );

		$markup = '<span class="go-wordmark-text">'
			. esc_html( $before )
			. '<span class="go-wordmark-text__over">' . esc_html( $match ) . '</span>'
			. esc_html( $after )
			. '</span>';
	}

	if ( ! $echo ) {
		return $markup;
	}
	echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts above.
}

/** One inline footer mark: independent of image lazy loading and header mode switches. */
function go_verge_footer_logo() {
    return sprintf(
        '<img class="go-footer-logo go-brand-image" src="%s" width="768" height="182" alt="" decoding="async">',
        esc_attr( go_verge_logo_inline_src( 'logo-dark.svg' ) )
    );
}
