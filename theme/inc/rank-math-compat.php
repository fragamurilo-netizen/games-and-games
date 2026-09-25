<?php
/**
 * Rank Math compatibility for the theme-native table of contents.
 *
 * The Overdrive TOC is generated at render time from H2 headings and is
 * intentionally kept outside post_content. Rank Math normally analyses only
 * the editor content, so it cannot discover that front-end TOC by itself.
 * This bridge declares the theme integration and lets the editor-side filter
 * mirror a zero-text TOC marker into Rank Math's analysis input.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register the active Rank Math installation as the analysis bridge for the
 * theme-native TOC.
 *
 * Rank Math exposes this list so integrations can declare additional TOC
 * providers. The theme is not a WordPress plugin, therefore we add Rank Math's
 * own active basename while this theme supplies the actual TOC. This avoids a
 * false "no TOC plugin" result without installing or rendering a second TOC.
 *
 * @param array $plugins Known TOC provider plugin basenames.
 * @return array
 */
function go_verge_rank_math_toc_plugins( $plugins ) {
	if ( ! is_array( $plugins ) ) {
		return $plugins;
	}

	$rank_math_basename = 'seo-by-rank-math/rank-math.php';

	/* Support both list-style and associative provider registries. */
	if ( ! isset( $plugins[ $rank_math_basename ] ) ) {
		$plugins[ $rank_math_basename ] = 'Overdrive theme TOC';
	}
	if ( ! in_array( $rank_math_basename, $plugins, true ) ) {
		$plugins[] = $rank_math_basename;
	}

	return $plugins;
}
add_filter( 'rank_math/researches/toc_plugins', 'go_verge_rank_math_toc_plugins' );

/**
 * Expose whether the currently saved post qualifies for the theme TOC.
 *
 * This helper mirrors the front-end threshold used in single.php. It is useful
 * to integrations and deliberately inspects only H2 headings, matching the TOC
 * generator in go_verge_content_with_toc().
 *
 * @param int|WP_Post|null $post Post ID/object. Defaults to current post.
 * @return bool
 */
function go_verge_post_has_native_toc( $post = null ) {
	$post = get_post( $post );
	if ( ! $post || 'post' !== $post->post_type ) {
		return false;
	}

	$content = (string) $post->post_content;
	if ( '' === trim( $content ) ) {
		return false;
	}

	preg_match_all( '/<h2\b[^>]*>/i', $content, $matches );

	return isset( $matches[0] ) && count( $matches[0] ) >= 3;
}


/**
 * The /games/ archive otherwise ships the machine-generated "Arquivo Games"
 * title. Only the default-generated pattern is replaced; a title customized in
 * Rank Math does not match and passes through untouched.
 *
 * @param string $title Document title resolved by Rank Math.
 * @return string
 */
function go_verge_rank_math_games_archive_title( $title ) {
	if ( is_post_type_archive( 'games' ) && preg_match( '/^Arquivos?\s+Games\b/iu', (string) $title ) ) {
		return __( 'Biblioteca de Games: fichas, lançamentos e reviews', 'go-verge' ) . ' | ' . get_bloginfo( 'name' );
	}
	return $title;
}
add_filter( 'rank_math/frontend/title', 'go_verge_rank_math_games_archive_title', 20 );

/**
 * Portuguese titles for the service and platform hubs.
 *
 * /netflix/, /game-pass/, /plataformas/playstation/ and the other go_service /
 * go_platform hubs shipped Rank Math's untranslated default, "Netflix Archives |
 * Overdrive", in the title, og:title, twitter:title and the CollectionPage name
 * (Rank Math derives all four from this filter). Only that machine-generated
 * pattern is replaced; a title written for the term in Rank Math passes.
 *
 * @param string $title Title resolved by Rank Math.
 * @return string
 */
function go_verge_rank_math_hub_archive_title( $title ) {
	if ( ! is_tax( array( 'go_service', 'go_platform' ) ) ) {
		return $title;
	}
	$term = get_queried_object();
	if ( ! $term instanceof WP_Term ) {
		return $title;
	}
	$name  = trim( wp_strip_all_tags( html_entity_decode( (string) $term->name, ENT_QUOTES, 'UTF-8' ) ) );
	$plain = html_entity_decode( (string) $title, ENT_QUOTES, 'UTF-8' );
	$quoted = preg_quote( $name, '/' );
	if ( '' === $name || ! preg_match( '/^\s*(?:' . $quoted . '\s+Archives?|Arquivos?\s+(?:de\s+|d[oa]s?\s+)?' . $quoted . ')(?=\s|$)/iu', $plain ) ) {
		return $title;
	}

	$streaming = array( 'netflix', 'max', 'hbo-max', 'prime-video', 'amazon-prime-video', 'disney-plus', 'globoplay', 'apple-tv-plus', 'crunchyroll', 'paramount-plus', 'star-plus', 'mubi', 'pluto-tv' );
	if ( 'go_platform' === $term->taxonomy ) {
		/* translators: %s: platform name (PlayStation, Xbox, PC...). */
		$label = sprintf( __( '%s: notícias, jogos, lançamentos e guias', 'go-verge' ), $name );
	} elseif ( in_array( $term->slug, $streaming, true ) ) {
		/* translators: %s: streaming service name. */
		$label = sprintf( __( '%s: estreias, séries, filmes e onde assistir', 'go-verge' ), $name );
	} else {
		/* translators: %s: game store or subscription (Steam, Game Pass...). */
		$label = sprintf( __( '%s: jogos, ofertas e novidades', 'go-verge' ), $name );
	}
	$label = (string) apply_filters( 'go_verge_hub_archive_title', $label, $term );
	$page  = max( 1, (int) get_query_var( 'paged' ) );
	if ( $page > 1 ) {
		/* translators: %d: archive page number. */
		$label .= sprintf( __( ' — Página %d', 'go-verge' ), $page );
	}
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : get_bloginfo( 'name' );
	return $label . ' | ' . $site_name;
}
add_filter( 'rank_math/frontend/title', 'go_verge_rank_math_hub_archive_title', 25 );

/**
 * Page N of an archive must not repeat page 1's title.
 *
 * Category, games and author archives configured with a fixed Rank Math title
 * (for example "Séries: notícias, temporadas e finais | Overdrive") returned the
 * same string on /page/2/, /page/3/ ... — duplicate titles for distinct, indexable
 * pages with their own canonicals. The page number is added before the site
 * name, in the " — Página N" form the Desk format hubs already use. Titles that
 * already carry a page marker are left alone.
 *
 * @param string $title Title resolved by Rank Math.
 * @return string
 */
function go_verge_rank_math_paged_archive_title( $title ) {
	$page = max( 1, (int) get_query_var( 'paged' ) );
	if ( $page < 2 || is_singular() || is_search() || ! ( is_archive() || is_home() ) ) {
		return $title;
	}
	$plain = html_entity_decode( (string) $title, ENT_QUOTES, 'UTF-8' );
	if ( '' === trim( $plain ) || preg_match( '/\b(?:p[áa]gina|page)\s*\d/iu', $plain ) ) {
		return $title;
	}
	/* translators: %d: archive page number. */
	$marker    = sprintf( __( ' — Página %d', 'go-verge' ), $page );
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : get_bloginfo( 'name' );
	/* Before a trailing "<separator> Site name", whichever separator is set. */
	if ( '' !== $site_name && preg_match( '/^(.*\S)(\s+(?:\||-|–|—|·|•|»|&[a-z]+;|&#\d+;)\s+' . preg_quote( $site_name, '/' ) . ')$/u', (string) $title, $parts ) ) {
		return $parts[1] . $marker . $parts[2];
	}
	return $title . $marker;
}
/* Before go_verge_audit_document_title (1100), so its length rule sees the final title. */
add_filter( 'rank_math/frontend/title', 'go_verge_rank_math_paged_archive_title', 1050 );

/**
 * Restore a large Open Graph image for social previews and Discover.
 *
 * Rank Math considers only `full`, `large` and `medium_large`, and rejects any
 * variation wider than 2000 px. Editorial covers here are stored at 2048 px or
 * more, so `full` is always discarded and the tag falls back to `large`, which
 * this install resolves to a 1024 px file (declared as 820 px). That is below
 * the 1200 px that Google Discover and Facebook expect, while the article
 * schema already points at the full-size image — so the two disagreed.
 *
 * Google now explicitly documents a preferred-image signal for Search and
 * Discover. Put the newsroom's exact 1600x900 crop first, then keep `full` and
 * every other 1200-2000 px fallback. This aligns og:image with the same 16:9
 * asset used by NewsArticle/primaryImageOfPage instead of asking Google to pick
 * between a full-size original and a different schema crop.
 *
 * @param array $sizes Image sizes Rank Math will evaluate, in priority order.
 * @return array
 */
function go_verge_rank_math_og_image_sizes( $sizes ) {
	if ( ! is_array( $sizes ) || ! function_exists( 'wp_get_registered_image_subsizes' ) ) {
		return $sizes;
	}

	/* Rank Math's own ceiling. Anything wider is discarded downstream anyway. */
	$candidates = array();
	foreach ( wp_get_registered_image_subsizes() as $name => $subsize ) {
		$width = isset( $subsize['width'] ) ? (int) $subsize['width'] : 0;
		if ( $width >= 1200 && $width <= 2000 ) {
			$candidates[ $name ] = $width;
		}
	}

	if ( empty( $candidates ) ) {
		return $sizes;
	}

	arsort( $candidates );

	$ordered = array();
	if ( isset( $candidates['go_discover_16x9'] ) ) {
		$ordered[] = 'go_discover_16x9';
	}
	$ordered[] = 'full';
	foreach ( array_keys( $candidates ) as $name ) {
		if ( ! in_array( $name, $ordered, true ) ) {
			$ordered[] = $name;
		}
	}
	foreach ( $sizes as $name ) {
		if ( ! in_array( $name, $ordered, true ) ) {
			$ordered[] = $name;
		}
	}

	return $ordered;
}
add_filter( 'rank_math/opengraph/image_sizes', 'go_verge_rank_math_og_image_sizes', 20 );


/**
 * Pick a real, generated Discover-ready asset instead of trusting a named size.
 *
 * `wp_get_attachment_image_src()` can silently fall back to the original when a
 * legacy attachment predates a registered crop. Rank Math may then reject that
 * original when it is wider than its Open Graph ceiling and continue down to
 * WordPress' 1024 px `large` size. Inspecting attachment metadata lets us choose
 * an asset that actually exists and is at least 1200 px wide.
 *
 * @param int $attachment_id Featured attachment ID.
 * @return array{url:string,width:int,height:int,size:string}|array{}
 */
/**
 * Um arquivo serve como `og:image`?
 *
 * `og:image` é UMA tag lida por muitos consumidores, e o formato precisa ser o
 * menor denominador comum entre eles:
 *
 *   Google Search/Discover   AVIF, WebP, JPEG, PNG   (AVIF desde 2023)
 *   Facebook / Instagram     WebP, JPEG, PNG         — AVIF nao renderiza
 *   X / Twitter              WebP, JPEG, PNG         — AVIF nao renderiza
 *   WhatsApp / LinkedIn      JPEG, PNG, WebP         — AVIF nao renderiza
 *
 * Medido neste site em 03/09/2026: uploads WebP geram subsizes normalmente
 * (`-640x360.webp`, `-1280x720.webp`), mas uploads AVIF **nao geram nenhuma** —
 * `-1600x900.avif`, `-1280x720.avif` e `-768x432.avif` respondem 404. Sem
 * subsize, o `go_discover_16x9` nao existe, a cadeia de candidatos cai para
 * `full`, e o `og:image` acaba sendo o AVIF original. O resultado e um card
 * quebrado em toda plataforma social, sem erro em lugar nenhum.
 *
 * Isto NAO desabilita AVIF no site: o `<img>` da pagina continua servindo AVIF
 * para quem o suporta, que e onde ele economiza banda de verdade. A restricao
 * vale so para a tag de compartilhamento.
 *
 * @param string $url URL do arquivo.
 * @return bool
 */
function go_verge_og_image_format_supported( $url ) {
	$path = (string) wp_parse_url( (string) $url, PHP_URL_PATH );
	$ext  = strtolower( (string) pathinfo( $path, PATHINFO_EXTENSION ) );
	if ( '' === $ext ) {
		return false;
	}
	/* Reject incompatible social formats before any delivery verification. */
	$blocked = (array) apply_filters( 'go_verge_og_image_blocked_formats', array( 'avif', 'jxl', 'heic', 'heif' ) );
	if ( in_array( $ext, $blocked, true ) ) {
		return false;
	}
	/* Arrival first: a file this server answers with the wrong Content-Type is
	 * not a share image on any network, whatever the extension would allow.
	 * This also removes SVG and TIFF, which passed the list below because the
	 * list was written about AVIF and never revisited — an SVG og:image is a
	 * silent no-preview, and no crawler here renders TIFF. */
	if ( function_exists( 'go_verge_image_format_deliverable' ) && ! go_verge_image_format_deliverable( $url ) ) {
		return false;
	}
	return true;
}

/** Resolve the MIME type from the selected file, not from its original upload. */
function go_verge_rank_math_image_mime_type( $url, $attachment_id = 0 ) {
	$path = rawurldecode( (string) wp_parse_url( (string) $url, PHP_URL_PATH ) );
	$ext  = strtolower( (string) pathinfo( $path, PATHINFO_EXTENSION ) );
	$map  = array(
		'jpg'   => 'image/jpeg',
		'jpeg'  => 'image/jpeg',
		'jpe'   => 'image/jpeg',
		'jfif'  => 'image/jpeg',
		'png'   => 'image/png',
		'gif'   => 'image/gif',
		'webp'  => 'image/webp',
		'bmp'   => 'image/bmp',
	);
	if ( isset( $map[ $ext ] ) ) {
		return $map[ $ext ];
	}

	$type = '';
	if ( function_exists( 'wp_check_filetype' ) ) {
		$checked = wp_check_filetype( $path );
		$type    = is_array( $checked ) && ! empty( $checked['type'] ) ? strtolower( (string) $checked['type'] ) : '';
	}
	if ( '' === $type && $attachment_id && function_exists( 'get_post_mime_type' ) ) {
		$type = strtolower( (string) get_post_mime_type( absint( $attachment_id ) ) );
	}

	return preg_match( '#^image/[a-z0-9.+-]+$#', $type ) ? $type : '';
}

/** Return editorial alt text for the selected attachment. */
function go_verge_rank_math_image_alt( $attachment_id, $fallback = '' ) {
	$attachment_id = absint( $attachment_id );
	$fallback      = trim( wp_strip_all_tags( (string) $fallback ) );
	if ( function_exists( 'go_verge_seo_image_alt' ) ) {
		return trim( wp_strip_all_tags( (string) go_verge_seo_image_alt( $attachment_id, $fallback ) ) );
	}

	$alt = $attachment_id && function_exists( 'get_post_meta' )
		? trim( (string) get_post_meta( $attachment_id, '_wp_attachment_image_alt', true ) )
		: '';
	$alt = '' !== $alt ? trim( wp_strip_all_tags( $alt ) ) : $fallback;
	return function_exists( 'sanitize_text_field' ) ? sanitize_text_field( $alt ) : $alt;
}

/**
 * Build the complete image record consumed by Rank Math for both networks.
 *
 * Rank Math discards the original attachment array whenever its URL filter
 * changes the file. Repopulating the secondary `image_array` filter prevents
 * the selected 1600x900 URL from retaining the old image's dimensions, alt or
 * MIME. Deriving MIME from the actual subsize is important when an AVIF upload
 * has a generated WebP social crop: that crop is `image/webp`, not image/avif.
 */
function go_verge_rank_math_social_image_record( $image, $attachment_id = 0, $fallback_alt = '' ) {
	if ( ! is_array( $image ) || empty( $image['url'] ) ) {
		return array();
	}

	$url    = esc_url_raw( (string) $image['url'], array( 'http', 'https' ) );
	$width  = absint( $image['width'] ?? 0 );
	$height = absint( $image['height'] ?? 0 );
	$type   = go_verge_rank_math_image_mime_type( $url, $attachment_id );
	if ( '' === $url || ! $width || ! $height || '' === $type || ! go_verge_og_image_format_supported( $url ) ) {
		return array();
	}

	return array(
		'id'     => absint( $attachment_id ),
		'url'    => $url,
		'width'  => $width,
		'height' => $height,
		'alt'    => go_verge_rank_math_image_alt( $attachment_id, $fallback_alt ),
		'type'   => $type,
	);
}

function go_verge_rank_math_discover_image( $attachment_id ) {
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id || ! function_exists( 'wp_get_attachment_metadata' ) || ! function_exists( 'wp_get_attachment_image_src' ) ) {
		return array();
	}

	$meta = wp_get_attachment_metadata( $attachment_id );
	$full = wp_get_attachment_image_src( $attachment_id, 'full' );
	if ( ! is_array( $meta ) || ! is_array( $full ) || empty( $full[0] ) ) {
		return array();
	}

	$eligible = static function ( $width, $height ) {
		$width  = absint( $width );
		$height = absint( $height );
		return $width >= 1200 && $height > 0 && ( $width * $height ) > 300000;
	};

	/* Prefer the newsroom's exact 16:9 crop when that file truly exists. */
	if ( function_exists( 'image_get_intermediate_size' ) ) {
		$discover = image_get_intermediate_size( $attachment_id, 'go_discover_16x9' );
		if (
			is_array( $discover ) && ! empty( $discover['url'] ) &&
			go_verge_og_image_format_supported( $discover['url'] ) &&
			$eligible( $discover['width'] ?? 0, $discover['height'] ?? 0 )
		) {
			return array(
				'url'    => (string) $discover['url'],
				'width'  => absint( $discover['width'] ),
				'height' => absint( $discover['height'] ),
				'size'   => 'go_discover_16x9',
			);
		}
	}

	$candidates = array();
	$full_url   = (string) $full[0];
	$full_dir   = trailingslashit( dirname( $full_url ) );

	foreach ( (array) ( $meta['sizes'] ?? array() ) as $name => $size ) {
		if ( ! is_array( $size ) || empty( $size['file'] ) || ! go_verge_og_image_format_supported( $size['file'] ) ) {
			continue;
		}
		$width  = absint( $size['width'] ?? 0 );
		$height = absint( $size['height'] ?? 0 );
		if ( ! $eligible( $width, $height ) ) {
			continue;
		}
		$candidates[] = array(
			'url'       => $full_dir . rawurlencode( wp_basename( (string) $size['file'] ) ),
			'width'     => $width,
			'height'    => $height,
			'size'      => (string) $name,
			'generated' => true,
		);
	}

	$full_width  = absint( $meta['width'] ?? ( $full[1] ?? 0 ) );
	$full_height = absint( $meta['height'] ?? ( $full[2] ?? 0 ) );
	if ( $eligible( $full_width, $full_height ) && go_verge_og_image_format_supported( $full_url ) ) {
		$candidates[] = array(
			'url'       => $full_url,
			'width'     => $full_width,
			'height'    => $full_height,
			'size'      => 'full',
			'generated' => false,
		);
	}

	if ( empty( $candidates ) ) {
		return array();
	}

	/*
	 * Ranking priorities:
	 * 1. landscape close to 16:9;
	 * 2. generated 1200-2000 px file (fast and accepted by Rank Math);
	 * 3. width close to 1600 px, our Discover editorial target.
	 * The full original still wins when it is the only genuinely good asset.
	 */
	usort(
		$candidates,
		static function ( $a, $b ) {
			$score = static function ( $item ) {
				$ratio = ! empty( $item['height'] ) ? ( $item['width'] / $item['height'] ) : 0;
				$gap   = abs( $ratio - ( 16 / 9 ) );
				$value = 0;
				if ( $gap <= 0.045 ) {
					$value += 100000;
				} elseif ( $gap <= 0.12 ) {
					$value += 50000;
				}
				if ( ! empty( $item['generated'] ) && $item['width'] <= 2000 ) {
					$value += 10000;
				}
				$value -= abs( 1600 - min( 2000, (int) $item['width'] ) );
				return $value;
			};
			return $score( $b ) <=> $score( $a );
		}
	);

	$best = $candidates[0];
	unset( $best['generated'] );
	return $best;
}

/** Force Rank Math's preferred social image to a real >=1200 px asset. */
function go_verge_rank_math_preferred_og_image( $attachment_url ) {
	if ( ! function_exists( 'is_singular' ) || ! is_singular( 'post' ) || ! function_exists( 'get_post_thumbnail_id' ) ) {
		return $attachment_url;
	}
	$post_id = function_exists( 'get_queried_object_id' ) ? absint( get_queried_object_id() ) : 0;
	$image   = $post_id ? go_verge_rank_math_discover_image( get_post_thumbnail_id( $post_id ) ) : array();
	if ( ! empty( $image['url'] ) ) {
		return $image['url'];
	}

	/* Never put a rejected AVIF/JXL/HEIC back into og:image through Rank Math's
	 * original fallback. A manually configured JPEG/PNG/WebP social image is
	 * still preserved when it is safe. */
	return go_verge_og_image_format_supported( $attachment_url ) ? $attachment_url : '';
}
add_filter( 'rank_math/opengraph/facebook/image', 'go_verge_rank_math_preferred_og_image', 95 );
add_filter( 'rank_math/opengraph/twitter/image', 'go_verge_rank_math_preferred_og_image', 95 );

/** Synchronize every field after Rank Math replaces its attachment array. */
function go_verge_rank_math_preferred_og_image_array( $attachment ) {
	if ( ! function_exists( 'is_singular' ) || ! is_singular( 'post' ) || ! function_exists( 'get_post_thumbnail_id' ) ) {
		return $attachment;
	}

	$post_id       = function_exists( 'get_queried_object_id' ) ? absint( get_queried_object_id() ) : 0;
	$attachment_id = $post_id ? absint( get_post_thumbnail_id( $post_id ) ) : 0;
	$image         = $attachment_id ? go_verge_rank_math_discover_image( $attachment_id ) : array();
	if ( empty( $image['url'] ) ) {
		/* Returning an empty URL from Rank Math's first filter does not remove its
		 * original attachment. Remove a rejected fallback at the array stage. */
		$url = is_array( $attachment ) && ! empty( $attachment['url'] ) ? (string) $attachment['url'] : '';
		return $url && ! go_verge_og_image_format_supported( $url ) ? array() : $attachment;
	}

	$fallback = $post_id && function_exists( 'get_the_title' ) ? (string) get_the_title( $post_id ) : '';
	$record   = go_verge_rank_math_social_image_record( $image, $attachment_id, $fallback );
	return ! empty( $record ) ? $record : array();
}
add_filter( 'rank_math/opengraph/facebook/image_array', 'go_verge_rank_math_preferred_og_image_array', 95 );
add_filter( 'rank_math/opengraph/twitter/image_array', 'go_verge_rank_math_preferred_og_image_array', 95 );


/** Return the selected Discover image for the current article. */
function go_verge_rank_math_current_discover_image() {
	if ( ! function_exists( 'is_singular' ) || ! is_singular( 'post' ) || ! function_exists( 'get_post_thumbnail_id' ) ) {
		return array();
	}
	$post_id = function_exists( 'get_queried_object_id' ) ? absint( get_queried_object_id() ) : 0;
	return $post_id ? go_verge_rank_math_discover_image( get_post_thumbnail_id( $post_id ) ) : array();
}

/** Keep og:image:secure_url synchronized with the overridden image URL. */
function go_verge_rank_math_preferred_og_secure_url( $content ) {
	$image = go_verge_rank_math_current_discover_image();
	return ! empty( $image['url'] ) ? $image['url'] : $content;
}
add_filter( 'rank_math/opengraph/facebook/og_image_secure_url', 'go_verge_rank_math_preferred_og_secure_url', 95 );

/** Keep og:image:width synchronized; stale 1024 metadata can discourage large previews. */
function go_verge_rank_math_preferred_og_width( $content ) {
	$image = go_verge_rank_math_current_discover_image();
	return ! empty( $image['width'] ) ? (string) absint( $image['width'] ) : $content;
}
add_filter( 'rank_math/opengraph/facebook/og_image_width', 'go_verge_rank_math_preferred_og_width', 95 );

/** Keep og:image:height synchronized with the chosen high-resolution asset. */
function go_verge_rank_math_preferred_og_height( $content ) {
	$image = go_verge_rank_math_current_discover_image();
	return ! empty( $image['height'] ) ? (string) absint( $image['height'] ) : $content;
}
add_filter( 'rank_math/opengraph/facebook/og_image_height', 'go_verge_rank_math_preferred_og_height', 95 );

/**
 * Rank Math removes core `wp_robots` callbacks, so guarantee the Discover image
 * preview directive on its own robots filter instead of relying on theme SEO.
 *
 * @param array $robots Rank Math advanced robots directives.
 * @return array
 */
function go_verge_rank_math_discover_robots( $robots ) {
	if ( ! is_array( $robots ) || ! function_exists( 'is_singular' ) || ! is_singular( 'post' ) ) {
		return $robots;
	}
	$robots['max-image-preview'] = 'max-image-preview:large';
	$robots['max-snippet']       = 'max-snippet:-1';
	$robots['max-video-preview'] = 'max-video-preview:-1';
	return $robots;
}
add_filter( 'rank_math/frontend/advanced_robots', 'go_verge_rank_math_discover_robots', 95 );

/**
 * Use the same editorial clock as the visible dateline and Article schema.
 * Rank Math otherwise reads post_modified, which also advances after technical
 * metadata changes. These filters change emitted tags only, never stored dates.
 */
function go_verge_rank_math_editorial_og_time( $value, $modified = false ) {
	if ( ! is_string( $value ) || '' === $value || ! is_singular( 'post' ) || is_admin() || is_feed() || is_preview() || post_password_required() ) {
		return $value;
	}
	$post_id = absint( get_queried_object_id() );
	$resolver = $modified ? 'go_verge_search_consistent_modified_iso' : 'go_verge_search_published_iso';
	if ( ! $post_id || 'publish' !== get_post_status( $post_id ) || ! function_exists( $resolver ) ) {
		return $value;
	}
	$editorial = (string) $resolver( $post_id );
	return strtotime( $editorial ) > 0 ? $editorial : $value;
}
function go_verge_rank_math_editorial_og_published( $value ) {
	return go_verge_rank_math_editorial_og_time( $value, false );
}
function go_verge_rank_math_editorial_og_modified( $value ) {
	return go_verge_rank_math_editorial_og_time( $value, true );
}
add_filter( 'rank_math/opengraph/facebook/article_published_time', 'go_verge_rank_math_editorial_og_published', 2000 );
add_filter( 'rank_math/opengraph/facebook/article_modified_time', 'go_verge_rank_math_editorial_og_modified', 2000 );
add_filter( 'rank_math/opengraph/facebook/og_updated_time', 'go_verge_rank_math_editorial_og_modified', 2000 );

/**
 * Rank Math Analytics can keep its module enabled while its custom objects
 * table is absent after a failed migration, restore or prefix change. In that
 * state Rank Math issues cleanup queries while WordPress creates an auto-draft,
 * which surfaces a database error on the "Adicionar post" screen.
 *
 * The theme must not invent Rank Math's private schema. Instead, while the
 * table is genuinely absent, neutralize only SQL statements that target that
 * missing table. CREATE/ALTER/DROP and SHOW TABLES are always allowed so Rank
 * Math's own installer or database tools can repair the schema later.
 */
function go_verge_rank_math_analytics_objects_table_name() {
	global $wpdb;
	return $wpdb->prefix . 'rank_math_analytics_objects';
}

/** Check the table without producing a SQL error when it is absent. */
function go_verge_rank_math_analytics_objects_table_exists( $force = false ) {
	global $wpdb;
	if ( $force || ! array_key_exists( 'go_verge_rank_math_objects_table_exists', $GLOBALS ) ) {
		$table = go_verge_rank_math_analytics_objects_table_name();
		$like  = $wpdb->esc_like( $table );
		$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $like ) );
		$GLOBALS['go_verge_rank_math_objects_table_exists'] = is_string( $found ) && $table === $found;
	}
	return ! empty( $GLOBALS['go_verge_rank_math_objects_table_exists'] );
}

/**
 * Prevent a missing Rank Math Analytics table from breaking post creation.
 *
 * @param string $query SQL about to be executed.
 * @return string
 */
function go_verge_rank_math_guard_missing_analytics_objects_table( $query ) {
	if ( ! is_string( $query ) || '' === $query ) {
		return $query;
	}

	$table = go_verge_rank_math_analytics_objects_table_name();
	if ( false === stripos( $query, $table ) ) {
		return $query;
	}

	/* Never block discovery or genuine repair/migration statements. A DDL
	 * statement invalidates the request-local cache so a table created later in
	 * the same request is immediately visible to Rank Math's subsequent writes. */
	if ( preg_match( '/^\s*SHOW\s+TABLES\b/i', $query ) ) {
		return $query;
	}
	if ( preg_match( '/^\s*(?:CREATE|ALTER|DROP|RENAME)\s+TABLE\b/i', $query ) ) {
		unset( $GLOBALS['go_verge_rank_math_objects_table_exists'] );
		return $query;
	}

	/* Re-check a cached miss. Rank Math may have repaired the table earlier in
	 * this request; keeping a permanent false cache would sabotage that repair. */
	if ( go_verge_rank_math_analytics_objects_table_exists( isset( $GLOBALS['go_verge_rank_math_objects_table_exists'] ) && ! $GLOBALS['go_verge_rank_math_objects_table_exists'] ) ) {
		return $query;
	}

	/* SELECT callers should receive an empty result; writes become a harmless
	 * successful query with zero affected rows. This is deliberately scoped to
	 * one missing Rank Math table and does not hide unrelated database errors. */
	if ( preg_match( '/^\s*SELECT\b/i', $query ) ) {
		return 'SELECT NULL AS go_verge_rank_math_missing_table WHERE 1 = 0';
	}

	return 'SELECT 1 AS go_verge_rank_math_missing_table_guard';
}
/* The "Game Overdrive Rank Math Analytics Guard" MU plugin loads earlier and does
 * the same job (plus DESCRIBE handling and early callback removal). Two query
 * filters inspecting every SQL statement for one table is duplicate work. */
if ( ! function_exists( 'go_rank_math_guard_missing_analytics_objects_query' ) ) {
	add_filter( 'query', 'go_verge_rank_math_guard_missing_analytics_objects_table', 0 );
}


/**
 * A listing is not an article.
 *
 * Measured on production 02/09/2026: /games/, /entretenimento/ and
 * /games/page/2/ all declared `og:type=article`. Open Graph reserves `article`
 * for a single authored piece, and the archives carry no article:* properties
 * to go with it, so the declaration is simply untrue. `website` is the correct
 * type for a listing.
 *
 * If this Rank Math filter is absent the hook never fires and nothing changes.
 *
 * @param string $type Open Graph type Rank Math resolved.
 * @return string
 */
function go_verge_rank_math_archive_og_type( $type ) {
	if ( function_exists( 'is_singular' ) && is_singular() ) {
		return $type;
	}
	if ( function_exists( 'is_archive' ) && ( is_archive() || is_home() || is_search() ) ) {
		return 'website';
	}
	return $type;
}
add_filter( 'rank_math/opengraph/type', 'go_verge_rank_math_archive_og_type', 20 );
