<?php
/**
 * Audit hardening for crawlable links and document titles.
 *
 * The rules here are intentionally conservative: they repair malformed hrefs,
 * remove accidental nofollow from same-site editorial links, bypass known
 * legacy topic redirects in rendered content, and keep <title> descriptive
 * without changing the visible H1.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Compare hosts without treating www as a separate site. */
function go_verge_audit_host_key( $host ) {
	$host = strtolower( trim( (string) $host ) );
	return 0 === strpos( $host, 'www.' ) ? substr( $host, 4 ) : $host;
}

/** Whether one href belongs to this WordPress installation. */
function go_verge_audit_is_internal_href( $href ) {
	$href = trim( (string) $href );
	if ( '' === $href || '#' === $href[0] || '?' === $href[0] || 0 === strpos( $href, './' ) || 0 === strpos( $href, '../' ) || ( '/' === $href[0] && 0 !== strpos( $href, '//' ) ) ) {
		return true;
	}
	$host = wp_parse_url( $href, PHP_URL_HOST );
	if ( ! $host ) {
		/* A path without a URI scheme is relative to this site. */
		return ! preg_match( '~^[a-z][a-z0-9+.-]*:~i', $href );
	}
	return go_verge_audit_host_key( $host ) === go_verge_audit_host_key( wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
}

/** Repair common malformed href variants without guessing unknown destinations. */
function go_verge_audit_normalize_href( $href ) {
	$href = html_entity_decode( trim( (string) $href ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
	$href = preg_replace( '/[\\x00-\\x1F\\x7F]+/u', '', $href );
	if ( ! is_string( $href ) || '' === $href ) {
		return '';
	}

	/* Keep genuine local references and safe non-HTTP protocols. */
	if ( '#' === $href[0] || '?' === $href[0] || 0 === strpos( $href, './' ) || 0 === strpos( $href, '../' ) || ( '/' === $href[0] && 0 !== strpos( $href, '//' ) ) ) {
		return $href;
	}
	if ( preg_match( '~^(?:javascript|data|vbscript):~i', $href ) ) {
		return '';
	}
	if ( preg_match( '~^(?:mailto|tel):~i', $href ) ) {
		return esc_url_raw( $href, array( 'mailto', 'tel' ) );
	}

	/* Backslashes and one-slash protocols are common copy/paste crawl errors. */
	$href = str_replace( '\\', '/', $href );
	$href = preg_replace( '~^https?:/{1}(?!/)~i', '$0/', $href );
	$href = preg_replace( '~^(https?)//~i', '$1://', $href );
	if ( 0 === stripos( $href, '//' ) ) {
		$href = 'https:' . $href;
	} elseif ( 0 === stripos( $href, 'www.' ) ) {
		$href = 'https://' . $href;
	} elseif ( ! preg_match( '~^[a-z][a-z0-9+.-]*:~i', $href ) && preg_match( '~^[^/\\s]+\\.[a-z]{2,}(?:/|$)~i', $href ) ) {
		$href = 'https://' . $href;
	}

	if ( preg_match( '~^https?://~i', $href ) ) {
		$url = esc_url_raw( $href, array( 'http', 'https' ) );
		return wp_parse_url( $url, PHP_URL_HOST ) ? $url : '';
	}

	/* Plain relative paths such as "games/" are valid browser URLs. */
	return preg_match( '/\\s/u', $href ) ? '' : $href;
}

/** Turn stored legacy /tag/ and duplicate /assunto/ links into direct canonicals. */
function go_verge_audit_direct_internal_destination( $href ) {
	if ( ! $href || ! go_verge_audit_is_internal_href( $href ) ) {
		return $href;
	}

	$absolute = preg_match( '~^https?://~i', $href ) ? $href : home_url( '/' . ltrim( $href, '/' ) );
	$path     = trim( (string) wp_parse_url( $absolute, PHP_URL_PATH ), '/' );

	/* Bypass the two legacy navigation shells that generated site-wide 301s. */
	if ( function_exists( 'go_verge_v7_category_url' ) ) {
		$legacy_editorial = array(
			'dicas-e-guias'                => 'guias',
			'category/games/dicas-e-guias' => 'guias',
			'category/games/guias'          => 'guias',
			'category/games/reviews'        => 'reviews',
			'promocoes'                     => 'promocoes',
		);
		if ( isset( $legacy_editorial[ $path ] ) ) {
			return esc_url_raw( go_verge_v7_category_url( $legacy_editorial[ $path ] ), array( 'http', 'https' ) );
		}
	}

	if ( ! preg_match( '~^(?:tag|assunto)/([^/]+)$~i', $path, $match ) || ! function_exists( 'go_verge_v36_topic_destination' ) ) {
		return $href;
	}

	$destination = go_verge_v36_topic_destination( sanitize_title( rawurldecode( $match[1] ) ) );
	if ( ! is_array( $destination ) || empty( $destination['url'] ) ) {
		return $href;
	}
	return esc_url_raw( $destination['url'], array( 'http', 'https' ) );
}

/** Remove accidental nofollow only from ordinary same-site links. */
function go_verge_audit_internal_rel( $href, $rel ) {
	$rel = trim( (string) $rel );
	if ( ! go_verge_audit_is_internal_href( $href ) || '' === $rel ) {
		return $rel;
	}
	$tokens = preg_split( '/\\s+/', strtolower( $rel ) );
	$tokens = array_values( array_unique( array_filter( (array) $tokens ) ) );
	if ( in_array( 'sponsored', $tokens, true ) || in_array( 'ugc', $tokens, true ) ) {
		return implode( ' ', $tokens );
	}
	$tokens = array_values( array_diff( $tokens, array( 'nofollow' ) ) );
	return implode( ' ', $tokens );
}

/** Clean links in editorial HTML with WordPress' streaming HTML processor. */
function go_verge_audit_clean_html_links( $html ) {
	if ( ! is_string( $html ) || '' === $html || false === stripos( $html, '<a' ) || ! class_exists( 'WP_HTML_Tag_Processor' ) ) {
		return $html;
	}
	$processor = new WP_HTML_Tag_Processor( $html );
	while ( $processor->next_tag( array( 'tag_name' => 'A' ) ) ) {
		$href = (string) $processor->get_attribute( 'href' );
		if ( '' === $href ) {
			continue;
		}
		$href = go_verge_audit_normalize_href( $href );
		if ( '' === $href ) {
			$processor->remove_attribute( 'href' );
			continue;
		}
		$href = go_verge_audit_direct_internal_destination( $href );
		$processor->set_attribute( 'href', $href );

		$rel = go_verge_audit_internal_rel( $href, (string) $processor->get_attribute( 'rel' ) );
		if ( '' === $rel ) {
			$processor->remove_attribute( 'rel' );
		} else {
			$processor->set_attribute( 'rel', $rel );
		}
	}
	return $processor->get_updated_html();
}
add_filter( 'the_content', 'go_verge_audit_clean_html_links', 120 );
add_filter( 'widget_text_content', 'go_verge_audit_clean_html_links', 120 );

/**
 * Replace bare-URL anchor text on the privacy page with descriptive labels.
 *
 * Semrush treats a naked URL as a weak/empty anchor and Google recommends
 * anchor text that makes sense without surrounding context. Keep the href
 * untouched; only the human-facing label changes.
 */
function go_verge_audit_descriptive_privacy_anchors( $html ) {
	if ( ! is_string( $html ) || '' === $html || ! is_page( 'privacidade' ) || false === stripos( $html, '<a' ) ) {
		return $html;
	}

	$labels = array(
		'https://gameoverdrive.com.br'                         => __( 'site do Overdrive', 'go-verge' ),
		'https://gameoverdrive.com.br/'                        => __( 'site do Overdrive', 'go-verge' ),
		'https://myadcenter.google.com'                         => __( 'Minha Central de Anúncios do Google', 'go-verge' ),
		'https://myadcenter.google.com/'                        => __( 'Minha Central de Anúncios do Google', 'go-verge' ),
		'https://optout.networkadvertising.org'                 => __( 'ferramenta de opt-out da Network Advertising Initiative', 'go-verge' ),
		'https://optout.networkadvertising.org/'                => __( 'ferramenta de opt-out da Network Advertising Initiative', 'go-verge' ),
		'https://optout.aboutads.info'                          => __( 'ferramenta de opt-out da Digital Advertising Alliance', 'go-verge' ),
		'https://optout.aboutads.info/'                         => __( 'ferramenta de opt-out da Digital Advertising Alliance', 'go-verge' ),
		'https://policies.google.com/technologies/ads'          => __( 'política de publicidade e privacidade do Google', 'go-verge' ),
		'https://policies.google.com/technologies/ads/'         => __( 'política de publicidade e privacidade do Google', 'go-verge' ),
		'https://policies.google.com/technologies/partner-sites'=> __( 'como o Google usa dados de sites parceiros', 'go-verge' ),
		'https://policies.google.com/technologies/partner-sites/'=> __( 'como o Google usa dados de sites parceiros', 'go-verge' ),
	);

	foreach ( $labels as $url => $label ) {
		$quoted = preg_quote( $url, '~' );
		$html = preg_replace_callback(
			'~<a\\b([^>]*\\bhref=["\\\']' . $quoted . '["\\\'][^>]*)>\\s*(?:' . $quoted . ')\\s*</a>~iu',
			static function ( $match ) use ( $label ) {
				return '<a' . $match[1] . '>' . esc_html( $label ) . '</a>';
			},
			$html
		);
	}
	return $html;
}
add_filter( 'the_content', 'go_verge_audit_descriptive_privacy_anchors', 121 );


/** Apply the same URL contract to WordPress menus before markup is generated. */
function go_verge_audit_nav_menu_link_attributes( $atts ) {
	if ( ! is_array( $atts ) || empty( $atts['href'] ) ) {
		return $atts;
	}
	$href = go_verge_audit_normalize_href( $atts['href'] );
	if ( '' === $href ) {
		unset( $atts['href'] );
		return $atts;
	}
	$href         = go_verge_audit_direct_internal_destination( $href );
	$atts['href'] = $href;
	if ( isset( $atts['rel'] ) ) {
		$rel = go_verge_audit_internal_rel( $href, $atts['rel'] );
		if ( '' === $rel ) {
			unset( $atts['rel'] );
		} else {
			$atts['rel'] = $rel;
		}
	}
	return $atts;
}
add_filter( 'nav_menu_link_attributes', 'go_verge_audit_nav_menu_link_attributes', 120, 1 );

/** Prefer an existing .min.css/.min.js peer for local theme assets. */
function go_verge_audit_prefer_minified_theme_asset( $src ) {
	$src = (string) $src;
	if ( '' === $src || false !== strpos( $src, '.min.' ) || ! defined( 'GO_VERGE_URI' ) || ! defined( 'GO_VERGE_DIR' ) ) {
		return $src;
	}
	$base_uri = trailingslashit( GO_VERGE_URI );
	if ( 0 !== strpos( $src, $base_uri ) ) {
		return $src;
	}
	$parts = wp_parse_url( $src );
	$path  = (string) ( $parts['path'] ?? '' );
	$root  = (string) wp_parse_url( $base_uri, PHP_URL_PATH );
	if ( ! $path || 0 !== strpos( $path, $root ) || ! preg_match( '/\.(css|js)$/i', $path, $match ) ) {
		return $src;
	}
	$relative = ltrim( substr( $path, strlen( $root ) ), '/' );
	$min_rel  = preg_replace( '/\.(' . preg_quote( strtolower( $match[1] ), '/' ) . ')$/i', '.min.$1', $relative );
	if ( ! $min_rel || ! file_exists( trailingslashit( GO_VERGE_DIR ) . $min_rel ) ) {
		return $src;
	}
	$min_src = $base_uri . str_replace( DIRECTORY_SEPARATOR, '/', $min_rel );
	if ( ! empty( $parts['query'] ) ) {
		$min_src .= '?' . $parts['query'];
	}
	return $min_src;
}
add_filter( 'style_loader_src', 'go_verge_audit_prefer_minified_theme_asset', 80 );
add_filter( 'script_loader_src', 'go_verge_audit_prefer_minified_theme_asset', 80 );

/** Best approximation of the page's visible primary title for audit comparison. */
function go_verge_audit_visible_h1() {
	if ( function_exists( 'go_verge_v21_is_topic_hub' ) && go_verge_v21_is_topic_hub() && function_exists( 'go_verge_v21_topic_label' ) ) {
		return go_verge_v21_topic_label( get_query_var( 'go_topic' ) );
	}
	if ( is_singular() ) {
		return wp_strip_all_tags( get_the_title( get_queried_object_id() ) );
	}
	if ( is_category() || is_tag() || is_tax() ) {
		$term = get_queried_object();
		return $term instanceof WP_Term ? $term->name : '';
	}
	if ( is_author() ) {
		return (string) get_the_author_meta( 'display_name', get_queried_object_id() );
	}
	if ( is_post_type_archive() ) {
		$object = get_queried_object();
		return $object instanceof WP_Post_Type ? $object->labels->name : '';
	}
	return '';
}

/** Normalize text only for equality tests; never rewrite editorial wording. */
function go_verge_audit_title_key( $value ) {
	$value = html_entity_decode( wp_strip_all_tags( (string) $value ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
	$value = preg_replace( '/\\s+/u', ' ', trim( $value ) );
	return function_exists( 'mb_strtolower' ) ? mb_strtolower( $value, 'UTF-8' ) : strtolower( $value );
}

/**
 * Avoid vague/too-short <title>s and exact H1 duplicates with a concise brand
 * qualifier. The visible H1 is intentionally left untouched.
 */
function go_verge_audit_document_title( $title ) {
	if ( is_admin() || is_feed() || is_embed() || is_404() || is_search() ) {
		return $title;
	}

	$plain = trim( html_entity_decode( wp_strip_all_tags( (string) $title ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) );
	if ( '' === $plain ) {
		return $title;
	}

	$h1      = trim( (string) go_verge_audit_visible_h1() );
	$length  = function_exists( 'mb_strlen' ) ? mb_strlen( $plain, 'UTF-8' ) : strlen( $plain );
	$same_h1 = '' !== $h1 && go_verge_audit_title_key( $plain ) === go_verge_audit_title_key( $h1 );

	/*
	 * Known institutional pages were the exact H1/<title> duplicates in the
	 * 25/08 audit. Give each a useful, human descriptor rather than blindly
	 * repeating the brand.
	 */
	if ( $same_h1 && is_page() ) {
		$slug = (string) get_post_field( 'post_name', get_queried_object_id() );
		$qualifiers = array(
			'sobre-o-overdrive' => 'Quem somos e como trabalhamos',
			'seja-colaborador'  => 'Como publicar no site',
		);
		if ( isset( $qualifiers[ $slug ] ) ) {
			return rtrim( $plain, " \t\n\r\0\x0B|-—–:" ) . ' | ' . $qualifiers[ $slug ];
		}
	}

	/* For other exact duplicates/very short titles, add only a concise brand. */
	if ( $same_h1 || $length <= 10 ) {
		$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Game Overdrive';
		if ( false === stripos( $plain, 'Overdrive' ) ) {
			return rtrim( $plain, " \t\n\r\0\x0B|-—–:" ) . ' | ' . $site_name;
		}
		return $plain;
	}

	/*
	 * Semrush also flags verbose title elements, but Google has no hard
	 * character limit. Only remove redundant trailing branding automatically;
	 * never truncate the editorial headline itself.
	 */
	if ( $length > 70 ) {
		$without_brand = preg_replace( '/\s*(?:\||-|—|–|:)\s*(?:Game\s+)?Overdrive\s*$/iu', '', $plain );
		if ( is_string( $without_brand ) && $without_brand !== $plain ) {
			return trim( $without_brand );
		}
	}

	return $title;
}
add_filter( 'rank_math/frontend/title', 'go_verge_audit_document_title', 1100 );
add_filter( 'wpseo_title', 'go_verge_audit_document_title', 1100 );
add_filter( 'pre_get_document_title', 'go_verge_audit_document_title', 1100 );
