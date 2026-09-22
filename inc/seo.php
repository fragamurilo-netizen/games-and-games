<?php
/**
 * SEO / AEO / GEO engine.
 *
 * A self-contained head layer for Overdrive: meta description, canonical,
 * robots (with Google Discover levers), Open Graph, Twitter cards and a rich
 * schema.org JSON-LD @graph (NewsMediaOrganization, WebSite, WebPage,
 * BreadcrumbList, NewsArticle, Review, VideoGame, Person,
 * SpeakableSpecification).
 *
 * Designed to run WITHOUT any SEO plugin. If Rank Math or Yoast is ever
 * activated it steps aside automatically so tags are never duplicated.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Whether this engine should output. Defers to a dedicated SEO plugin.
 */
function go_verge_seo_active() {
	if ( is_admin() || is_feed() || is_embed() ) {
		return false;
	}
	// Stand down when a full SEO plugin is present to avoid duplicate meta.
	if ( defined( 'RANK_MATH_VERSION' ) || defined( 'WPSEO_VERSION' ) || defined( 'SEOPRESS_VERSION' ) || defined( 'AIOSEO_VERSION' ) ) {
		return false;
	}
	/**
	 * Allow disabling the whole engine.
	 *
	 * @param bool $active Whether the engine runs.
	 */
	return (bool) apply_filters( 'go_verge_seo_active', true );
}

/* -------------------------------------------------------------------------
 * Shared resolvers
 * ---------------------------------------------------------------------- */

/**
 * The site's public identity used across schema + OG.
 */
function go_verge_seo_site_name() {
	return defined( 'GO_VERGE_BRAND_NAME' ) ? GO_VERGE_BRAND_NAME : 'Game Overdrive';
}

/**
 * Public fallback names for Google site-name selection.
 *
 * "Game Overdrive" is the preferred publisher/site name (`name`). Google
 * explicitly supports `alternateName` for a concise or familiar alias, so the
 * shorter "Overdrive" identity remains available without competing with the
 * canonical publisher name.
 *
 * Order matters: preferred `name` is Game Overdrive; `alternateName` is
 * Overdrive. Google may still choose another representation automatically.
 *
 * @return string[]
 */
function go_verge_seo_site_alternate_names() {
	$primary = go_verge_seo_site_name();
	$names   = (array) apply_filters(
		'go_verge_seo_site_alternate_names',
		array( 'Overdrive' )
	);

	return array_values(
		array_filter(
			array_unique( array_map( 'trim', array_map( 'strval', $names ) ) ),
			static function ( $name ) use ( $primary ) {
				return '' !== $name && 0 !== strcasecmp( $name, $primary );
			}
		)
	);
}

/**
 * Schema value for the alias list: one name is a string, several are an array.
 *
 * @return string|string[]|null
 */
function go_verge_seo_alternate_name_value() {
	$names = go_verge_seo_site_alternate_names();
	if ( ! $names ) {
		return null;
	}

	return 1 === count( $names ) ? $names[0] : $names;
}

/**
 * Best available logo URL (square, ideally >=112px for Google) + dimensions.
 *
 * @return array{url:string,width:int,height:int}
 */
function go_verge_seo_logo() {
	/* Keep publisher identity on the approved artwork even if another plugin
	 * overrides the WordPress Site Icon with a stale attachment later on. */
	if ( function_exists( 'go_verge_brand_icon_url' ) ) {
		return array( 'url' => go_verge_brand_icon_url(), 'width' => 512, 'height' => 512 );
	}
	$icon = function_exists( 'get_site_icon_url' ) ? get_site_icon_url( 512 ) : '';
	if ( $icon ) {
		return array( 'url' => $icon, 'width' => 512, 'height' => 512 );
	}

	$custom_logo_id = (int) get_theme_mod( 'custom_logo' );
	if ( $custom_logo_id ) {
		$src = wp_get_attachment_image_src( $custom_logo_id, 'full' );
		if ( is_array( $src ) && ! empty( $src[0] ) ) {
			return array( 'url' => $src[0], 'width' => (int) $src[1], 'height' => (int) $src[2] );
		}
	}

	return array(
		'url'    => trailingslashit( GO_VERGE_URI ) . 'assets/img/brand/multicolor-v2/serp-icon-512.png',
		'width'  => 512,
		'height' => 512,
	);
}

/**
 * Canonical URL for the current view, self-referencing and paginate-aware.
 */
function go_verge_seo_canonical_url() {
	if ( function_exists( 'go_verge_specials_gallery_is_current' ) && go_verge_specials_gallery_is_current() ) {
		return go_verge_specials_gallery_canonical();
	}
	if ( is_404() ) {
		return '';
	}
	/* A validated desk/type combination owns its filtered pagination URL.
	 * Keep native metadata and schema aligned with the SEO-plugin canonical. */
	if ( function_exists( 'go_verge_desk_format_canonical_url' ) ) {
		$desk_format_url = (string) go_verge_desk_format_canonical_url();
		if ( '' !== $desk_format_url ) {
			return esc_url_raw( $desk_format_url );
		}
	}

	$url   = '';
	$paged = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );

	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) {
		return esc_url_raw( function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url( $paged ) : home_url( '/noticias/' ) );
	}

	if ( is_front_page() ) {
		$url = home_url( '/' );
	} elseif ( is_home() ) {
		$posts_page = (int) get_option( 'page_for_posts' );
		$url        = $posts_page ? get_permalink( $posts_page ) : home_url( '/' );
	} elseif ( is_singular() ) {
		$url   = get_permalink();
		$cpage = (int) get_query_var( 'cpage' );
		if ( $cpage > 1 ) {
			$url = get_comments_pagenum_link( $cpage );
		} elseif ( $paged > 1 ) {
			/* A Page-backed listing uses `/page/N/`; a genuinely multipage
			 * singular document uses `/N/`. Detect the pagination segment from
			 * the request instead of canonicalizing both URL families as one. */
			global $wp_rewrite;
			$pagination_base = $wp_rewrite instanceof WP_Rewrite && ! empty( $wp_rewrite->pagination_base )
				? (string) $wp_rewrite->pagination_base
				: 'page';
			$request_path = (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH );
			$has_archive_pagination = (bool) preg_match( '#/' . preg_quote( trim( $pagination_base, '/' ), '#' ) . '/[0-9]+/?$#', $request_path );
			$url = $has_archive_pagination
				? get_pagenum_link( $paged )
				: trailingslashit( $url ) . user_trailingslashit( $paged, 'single_paged' );
		}
	} elseif ( is_category() || is_tag() || is_tax() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$link = get_term_link( $term );
			$url  = is_wp_error( $link ) ? home_url( '/' ) : $link;
		}
	} elseif ( is_author() ) {
		$url = get_author_posts_url( get_queried_object_id() );
	} elseif ( is_post_type_archive() ) {
		$post_type = get_query_var( 'post_type' );
		if ( is_array( $post_type ) ) {
			$post_type = reset( $post_type );
		}
		$link = is_string( $post_type ) && '' !== $post_type ? get_post_type_archive_link( $post_type ) : '';
		$url  = $link ? $link : home_url( '/' );
	} elseif ( is_search() ) {
		$url = get_search_link();
	} elseif ( is_year() ) {
		$url = get_year_link( (int) get_query_var( 'year' ) );
	} elseif ( is_month() ) {
		$url = get_month_link( (int) get_query_var( 'year' ), (int) get_query_var( 'monthnum' ) );
	} elseif ( is_day() ) {
		$url = get_day_link( (int) get_query_var( 'year' ), (int) get_query_var( 'monthnum' ), (int) get_query_var( 'day' ) );
	} else {
		/* Never let campaign/debug parameters leak into a canonical. Convert the
		 * request path back to a home-relative path so subdirectory installs do
		 * not accidentally duplicate their /wordpress/ prefix. */
		$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '/';
		$path        = (string) wp_parse_url( $request_uri, PHP_URL_PATH );
		$home_path   = '/' . trim( (string) wp_parse_url( home_url( '/' ), PHP_URL_PATH ), '/' );
		if ( '/' !== $home_path && ( $path === $home_path || 0 === strpos( $path, $home_path . '/' ) ) ) {
			$path = substr( $path, strlen( $home_path ) );
		}
		$url = home_url( '/' . ltrim( $path, '/' ) );
	}

	// Self-reference paginated archive pages so each page is its own canonical.
	if ( $paged > 1 && ! is_singular() && $url ) {
		$url = get_pagenum_link( $paged );
	}

	/* Strip campaign/click identifiers without removing functional query vars
	 * such as the search term. */
	$url = remove_query_arg(
		(array) apply_filters(
			'go_verge_seo_canonical_tracking_args',
			array( 'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content', 'utm_id', 'gclid', 'dclid', 'fbclid', 'msclkid', 'twclid', 'ttclid', '_gl', 'gad_source' )
		),
		$url
	);

	return esc_url_raw( $url );
}

/**
 * Keep Rank Math's canonical aligned with the theme's real paginated URL.
 *
 * Page-backed editorial hubs use a secondary query, so Rank Math sees a
 * singular Page and otherwise canonicalizes every `/page/N/` response to page
 * one. The theme resolver already understands this shape; reuse it instead of
 * maintaining a second URL builder.
 *
 * @param string $canonical Canonical selected by Rank Math.
 * @return string
 */
function go_verge_rank_math_paginated_page_canonical( $canonical ) {
	$paged = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	if ( $paged <= 1 || ! is_page() || is_404() ) {
		return $canonical;
	}

	$resolved = go_verge_seo_canonical_url();
	return $resolved ? $resolved : $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_rank_math_paginated_page_canonical', 1200 );

/** Give every indexable page of an editorial sequence a distinct title. */
function go_verge_paginated_page_document_title( $title ) {
	$paged = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	if ( $paged <= 1 || ! is_page() || is_404() ) {
		return $title;
	}

	$title = trim( wp_strip_all_tags( (string) $title ) );
	if ( '' === $title ) {
		$title = wp_strip_all_tags( get_the_title( get_queried_object_id() ) );
	}
	if ( preg_match( '/\bp[aá]gina\s+' . preg_quote( (string) $paged, '/' ) . '\b/iu', $title ) ) {
		return $title;
	}

	$page_label = sprintf( __( 'Página %d', 'go-verge' ), $paged );
	$site_name  = preg_quote( go_verge_seo_site_name(), '/' );
	if ( preg_match( '/^(.*?)(\s+[|–—-]\s+' . $site_name . ')$/iu', $title, $parts ) ) {
		return trim( $parts[1] ) . ' — ' . $page_label . $parts[2];
	}

	return $title . ' — ' . $page_label;
}
add_filter( 'rank_math/frontend/title', 'go_verge_paginated_page_document_title', 1200 );
add_filter( 'pre_get_document_title', 'go_verge_paginated_page_document_title', 1200 );

/**
 * Concise meta description for the current view.
 */
function go_verge_seo_description() {
	$text = '';

	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) {
		$text = function_exists( 'go_verge_newsroom_description' )
			? go_verge_newsroom_description()
			: sprintf( __( 'Notícias do %s sobre games, entretenimento e tecnologia.', 'go-verge' ), go_verge_seo_site_name() );
	} elseif ( is_front_page() || is_home() ) {
		$text = (string) get_bloginfo( 'description' );
	} elseif ( is_singular() ) {
		$post_id = get_queried_object_id();
		if ( is_singular( 'post' ) ) {
			/*
			 * Newsroom articles must prefer the explicit editorial fields before the
			 * WordPress excerpt. Priority: SEO meta, support line, then excerpt.
			 */
			if ( function_exists( 'go_verge_preferred_search_description' ) ) {
				$text = go_verge_preferred_search_description( $post_id );
			} else {
				$text = function_exists( 'go_verge_editor_support_line' ) ? go_verge_editor_support_line( $post_id ) : '';
				if ( '' === trim( (string) $text ) ) {
					$text = get_the_excerpt( $post_id );
				}
			}
		} else {
			/* Preserve structured descriptions for game/production/entity singles. */
			if ( function_exists( 'go_verge_support_text' ) ) {
				$text = go_verge_support_text( $post_id );
			}
			if ( '' === trim( (string) $text ) ) {
				$text = get_the_excerpt( $post_id );
			}
			if ( '' === trim( (string) $text ) ) {
				$content = get_post_field( 'post_content', $post_id );
				$text    = wp_strip_all_tags( strip_shortcodes( (string) $content ) );
			}
		}
	} elseif ( is_category() || is_tag() || is_tax() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$text = term_description( $term );
			if ( '' === trim( wp_strip_all_tags( (string) $text ) ) ) {
				/* translators: %s: category/tag name. */
				$text = sprintf( __( 'As últimas notícias, análises e guias sobre %s no Overdrive.', 'go-verge' ), $term->name );
			}
		}
	} elseif ( is_author() ) {
		$text = get_the_author_meta( 'description', get_queried_object_id() );
		if ( '' === trim( (string) $text ) ) {
			/* translators: %s: author name. */
			$text = sprintf( __( 'Matérias assinadas por %s no Overdrive.', 'go-verge' ), get_the_author_meta( 'display_name', get_queried_object_id() ) );
		}
	} elseif ( is_search() ) {
		/* translators: %s: search query. */
		$text = sprintf( __( 'Resultados de busca para “%s” no Overdrive.', 'go-verge' ), get_search_query() );
	} elseif ( is_post_type_archive() ) {
		$text = get_the_archive_description();
	}

	$text = wp_strip_all_tags( strip_shortcodes( (string) $text ) );
	$text = preg_replace( '/\s+/u', ' ', $text );
	$text = trim( (string) $text );

	if ( '' === $text ) {
		$text = go_verge_seo_site_name() . ' — ' . __( 'games, entretenimento e tecnologia.', 'go-verge' );
	}

	// Keep meta descriptions in the ~155–160 char sweet spot.
	if ( function_exists( 'mb_strimwidth' ) ) {
		$text = mb_strimwidth( $text, 0, 160, '…', 'UTF-8' );
	} elseif ( strlen( $text ) > 160 ) {
		$text = rtrim( substr( $text, 0, 159 ) ) . '…';
	}

	return $text;
}

/**
 * Human-readable alt text for an attachment used in social previews.
 *
 * @param int    $attachment_id Attachment ID.
 * @param string $fallback      Fallback when media metadata has no description.
 * @return string
 */
function go_verge_seo_image_alt( $attachment_id, $fallback = '' ) {
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id ) {
		return trim( wp_strip_all_tags( (string) $fallback ) );
	}

	$stored = get_post_meta( $attachment_id, '_wp_attachment_image_alt', true );
	if ( is_string( $stored ) && '' !== trim( $stored ) ) {
		return trim( wp_strip_all_tags( $stored ) );
	}

	$attachment = get_post( $attachment_id );
	$parent_id  = $attachment instanceof WP_Post ? absint( $attachment->post_parent ) : 0;
	if ( $parent_id && function_exists( 'go_verge_image_description' ) ) {
		$description = go_verge_image_description( $attachment_id, $parent_id );
		if ( '' !== trim( (string) $description ) ) {
			return trim( wp_strip_all_tags( (string) $description ) );
		}
	}

	$caption = wp_get_attachment_caption( $attachment_id );
	if ( is_string( $caption ) && '' !== trim( $caption ) ) {
		return trim( wp_strip_all_tags( $caption ) );
	}
	if ( $attachment instanceof WP_Post && '' !== trim( $attachment->post_title ) ) {
		$looks_like_file = function_exists( 'go_verge_title_looks_like_filename' )
			? go_verge_title_looks_like_filename( $attachment->post_title )
			: false;
		if ( ! $looks_like_file ) {
			return trim( wp_strip_all_tags( $attachment->post_title ) );
		}
	}

	return trim( wp_strip_all_tags( (string) $fallback ) );
}

/**
 * Resolve one attachment into a social image without discarding a useful
 * preview merely because it is smaller than the preferred Discover candidate.
 *
 * @param int    $attachment_id Attachment ID.
 * @param string $fallback_alt  Fallback alt text.
 * @return array{url:string,width:int,height:int,alt:string}|null
 */
function go_verge_seo_attachment_image( $attachment_id, $fallback_alt = '' ) {
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id ) {
		return null;
	}

	if ( function_exists( 'go_verge_rank_math_discover_image' ) ) {
		$selected = go_verge_rank_math_discover_image( $attachment_id );
		if ( ! empty( $selected['url'] ) ) {
			return array(
				'url'    => esc_url_raw( $selected['url'] ),
				'width'  => (int) ( $selected['width'] ?? 0 ),
				'height' => (int) ( $selected['height'] ?? 0 ),
				'alt'    => go_verge_seo_image_alt( $attachment_id, $fallback_alt ),
			);
		}
	}

	$full = wp_get_attachment_image_src( $attachment_id, 'full' );
	if ( ! is_array( $full ) || empty( $full[0] ) ) {
		return null;
	}
	if ( function_exists( 'go_verge_og_image_format_supported' ) && ! go_verge_og_image_format_supported( $full[0] ) ) {
		return null;
	}

	return array(
		'url'    => esc_url_raw( $full[0] ),
		'width'  => (int) ( $full[1] ?? 0 ),
		'height' => (int) ( $full[2] ?? 0 ),
		'alt'    => go_verge_seo_image_alt( $attachment_id, $fallback_alt ),
	);
}

/**
 * Whether an image URL uses a format Google Images can currently process.
 *
 * This is deliberately broader than the Open Graph allow-list. AVIF and SVG
 * are valid Google Images inputs even though social crawlers are less
 * consistent with them. Keeping the two policies separate avoids deleting a
 * valid Article image merely because it is not an ideal social-card asset.
 */
function go_verge_schema_image_format_supported( $url ) {
	$path = function_exists( 'wp_parse_url' ) ? wp_parse_url( (string) $url, PHP_URL_PATH ) : parse_url( (string) $url, PHP_URL_PATH );
	$ext  = strtolower( (string) pathinfo( (string) $path, PATHINFO_EXTENSION ) );
	return in_array( $ext, array( 'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'svg', 'avif' ), true );
}

/**
 * Resolve the representative image for Article/WebPage structured data.
 *
 * Discover still gets first choice: its preferred asset is at least 1200 px
 * wide and 300k pixels. When an older article has only a smaller upload, keep a
 * truthful, crawlable schema image as long as it clears Google's 50k-pixel
 * Article recommendation. This fallback never changes og:image and therefore
 * never pretends that the smaller file is Discover-ready.
 *
 * @return array<string,mixed>|null
 */
function go_verge_schema_editorial_image( $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : ( function_exists( 'get_queried_object_id' ) ? absint( get_queried_object_id() ) : 0 );
	if ( ! $post_id || ! has_post_thumbnail( $post_id ) ) {
		return null;
	}

	$attachment_id = absint( get_post_thumbnail_id( $post_id ) );
	$selected      = function_exists( 'go_verge_rank_math_discover_image' )
		? go_verge_rank_math_discover_image( $attachment_id )
		: array();

	if ( empty( $selected['url'] ) || empty( $selected['width'] ) || empty( $selected['height'] ) ) {
		$full = wp_get_attachment_image_src( $attachment_id, 'full' );
		if ( ! is_array( $full ) || empty( $full[0] ) || empty( $full[1] ) || empty( $full[2] ) ) {
			return null;
		}
		$selected = array(
			'url'    => (string) $full[0],
			'width'  => absint( $full[1] ),
			'height' => absint( $full[2] ),
		);
	}

	$url    = esc_url_raw( (string) $selected['url'], array( 'http', 'https' ) );
	$width  = absint( $selected['width'] );
	$height = absint( $selected['height'] );
	if ( '' === $url || ! $width || ! $height || ( $width * $height ) < 50000 || ! go_verge_schema_image_format_supported( $url ) ) {
		return null;
	}

	$node = array(
		'@type'      => 'ImageObject',
		'@id'        => get_permalink( $post_id ) . '#primaryimage',
		'url'        => $url,
		'contentUrl' => $url,
		'width'      => $width,
		'height'     => $height,
	);
	$caption = wp_get_attachment_caption( $attachment_id );
	if ( is_string( $caption ) && '' !== trim( $caption ) ) {
		$node['caption'] = trim( wp_strip_all_tags( $caption ) );
	}
	return $node;
}

/**
 * Best social/preview image for the current view.
 *
 * @return array{url:string,width:int,height:int,alt:string}|null
 */
function go_verge_seo_image() {
	if ( is_singular() ) {
		$post_id  = get_queried_object_id();
		$image_id = has_post_thumbnail( $post_id ) ? get_post_thumbnail_id( $post_id ) : 0;

		/* A legacy article may be missing a featured image but still contain a
		 * Media Library image. Prefer that relevant asset over an unrelated
		 * archive image or the publisher logo. */
		if ( ! $image_id ) {
			$content = (string) get_post_field( 'post_content', $post_id );
			if ( preg_match( '/\bwp-image-([0-9]+)\b/', $content, $match ) ) {
				$image_id = absint( $match[1] );
			}
		}

		if ( $image_id ) {
			$image = go_verge_seo_attachment_image( $image_id, wp_get_document_title() );
			if ( $image ) {
				return $image;
			}
		}
	}

	if ( ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) || is_category() || is_tag() || is_tax() || is_author() || is_home() || is_front_page() || is_post_type_archive() ) {
		/* Keep archive previews contextually relevant instead of always borrowing
		 * the newest image from an unrelated section of the site. */
		$args = array(
			'post_type'              => 'post',
			'posts_per_page'         => 1,
			'post_status'            => 'publish',
			'ignore_sticky_posts'    => true,
			'meta_key'               => '_thumbnail_id',
			'no_found_rows'          => true,
			'suppress_filters'       => false,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		);

		if ( is_category() ) {
			$args['category__in'] = array( get_queried_object_id() );
		} elseif ( is_tag() ) {
			$args['tag__in'] = array( get_queried_object_id() );
		} elseif ( is_tax() ) {
			$term = get_queried_object();
			if ( $term instanceof WP_Term ) {
				$taxonomy = get_taxonomy( $term->taxonomy );
				if ( $taxonomy && ! empty( $taxonomy->object_type ) ) {
					$args['post_type'] = array_values( array_filter( array_map( 'sanitize_key', (array) $taxonomy->object_type ) ) );
				}
				$args['tax_query'] = array( // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_tax_query
					array(
						'taxonomy' => $term->taxonomy,
						'field'    => 'term_id',
						'terms'    => array( $term->term_id ),
					),
				);
			}
		} elseif ( is_author() ) {
			$args['author'] = get_queried_object_id();
		} elseif ( is_post_type_archive() ) {
			$post_type = get_query_var( 'post_type' );
			$args['post_type'] = is_array( $post_type ) ? array_map( 'sanitize_key', $post_type ) : sanitize_key( (string) $post_type );
		}

		$recent = get_posts( $args );
		if ( ! empty( $recent[0] ) && has_post_thumbnail( $recent[0]->ID ) ) {
			$image = go_verge_seo_attachment_image( get_post_thumbnail_id( $recent[0]->ID ), get_the_title( $recent[0]->ID ) );
			if ( $image ) {
				return $image;
			}
		}
	}

	// A post without an editorial image must not advertise the publisher logo as its story preview.
	if ( is_singular( 'post' ) ) { return null; }
	$logo = go_verge_seo_logo();
	return $logo['url'] ? array(
		'url'    => esc_url_raw( $logo['url'] ),
		'width'  => (int) $logo['width'],
		'height' => (int) $logo['height'],
		'alt'    => go_verge_seo_site_name(),
	) : null;
}

/* -------------------------------------------------------------------------
 * <head> meta output
 * ---------------------------------------------------------------------- */

/**
 * Robots directives: unlock large image/snippet previews (Discover + rich
 * results) and keep thin/utility views out of the index.
 *
 * @param array $robots Existing directives from wp_robots().
 * @return array
 */
function go_verge_seo_robots( $robots ) {
	if ( ! go_verge_seo_active() ) {
		return $robots;
	}

	$restricted = is_search() || is_404() || is_preview() || ! get_option( 'blog_public' )
		|| ( is_singular() && post_password_required() );
	if ( $restricted || ! empty( $robots['noindex'] ) || ! empty( $robots['none'] ) ) {
		$robots['noindex'] = true;
		unset( $robots['index'], $robots['max-image-preview'], $robots['max-snippet'], $robots['max-video-preview'] );
		if ( empty( $robots['nofollow'] ) && empty( $robots['none'] ) ) { $robots['follow'] = true; }
		else { unset( $robots['follow'] ); }
		return $robots;
	}

	// wp_robots emits numeric limits correctly only when represented as strings.
	$robots['index'] = true;
	if ( empty( $robots['nofollow'] ) ) { $robots['follow'] = true; }
	else { unset( $robots['follow'] ); }
	$robots['max-image-preview'] = 'large';
	$robots['max-snippet'] = '-1';
	$robots['max-video-preview'] = '-1';

	return $robots;
}
add_filter( 'wp_robots', 'go_verge_seo_robots', 20 );

/**
 * Print the head meta block (description, canonical, OG, Twitter).
 */
function go_verge_seo_head() {
	if ( ! go_verge_seo_active() || is_preview() || ( is_singular() && post_password_required() ) ) {
		return;
	}

	$site_name   = go_verge_seo_site_name();
	$description = go_verge_seo_description();
	$canonical   = go_verge_seo_canonical_url();
	$title       = wp_get_document_title();
	$image       = go_verge_seo_image();
	$locale      = get_bloginfo( 'language' ); // e.g. pt-BR
	$og_locale   = str_replace( '-', '_', $locale );

	$out  = "\n<!-- Overdrive SEO -->\n";
	$out .= sprintf( '<meta name="description" content="%s">' . "\n", esc_attr( $description ) );
	if ( $canonical ) {
		$out .= sprintf( '<link rel="canonical" href="%s">' . "\n", esc_url( $canonical ) );
	}

	// Open Graph.
	$og_type = is_singular( 'post' ) ? 'article' : 'website';
	$out .= sprintf( '<meta property="og:type" content="%s">' . "\n", esc_attr( $og_type ) );
	$out .= sprintf( '<meta property="og:site_name" content="%s">' . "\n", esc_attr( $site_name ) );
	$out .= sprintf( '<meta property="og:title" content="%s">' . "\n", esc_attr( $title ) );
	$out .= sprintf( '<meta property="og:description" content="%s">' . "\n", esc_attr( $description ) );
	if ( $canonical ) {
		$out .= sprintf( '<meta property="og:url" content="%s">' . "\n", esc_url( $canonical ) );
	}
	$out .= sprintf( '<meta property="og:locale" content="%s">' . "\n", esc_attr( $og_locale ) );

	if ( $image && ! empty( $image['url'] ) ) {
		$out .= sprintf( '<meta property="og:image" content="%s">' . "\n", esc_url( $image['url'] ) );
		$out .= sprintf( '<meta property="og:image:secure_url" content="%s">' . "\n", esc_url( $image['url'] ) );
		if ( ! empty( $image['width'] ) && ! empty( $image['height'] ) ) {
			$out .= sprintf( '<meta property="og:image:width" content="%d">' . "\n", (int) $image['width'] );
			$out .= sprintf( '<meta property="og:image:height" content="%d">' . "\n", (int) $image['height'] );
		}
		$out .= sprintf( '<meta property="og:image:alt" content="%s">' . "\n", esc_attr( ! empty( $image['alt'] ) ? $image['alt'] : $title ) );
	}

	// Article-specific OG belongs only on editorial posts.
	if ( 'article' === $og_type ) {
		$post_id = get_queried_object_id();
		$out    .= sprintf( '<meta property="article:published_time" content="%s">' . "\n", esc_attr( function_exists( 'go_verge_search_published_iso' ) ? go_verge_search_published_iso( $post_id ) : get_post_time( 'c', true, $post_id ) ) );
		$out    .= sprintf( '<meta property="article:modified_time" content="%s">' . "\n", esc_attr( function_exists( 'go_verge_search_consistent_modified_iso' ) ? go_verge_search_consistent_modified_iso( $post_id ) : get_post_modified_time( 'c', true, $post_id ) ) );

		if ( function_exists( 'go_verge_get_primary_term' ) ) {
			$primary = go_verge_get_primary_term( $post_id );
			if ( $primary instanceof WP_Term ) {
				$out .= sprintf( '<meta property="article:section" content="%s">' . "\n", esc_attr( $primary->name ) );
			}
		}
		$tags = get_the_tags( $post_id );
		if ( $tags && ! is_wp_error( $tags ) ) {
			foreach ( array_slice( $tags, 0, 8 ) as $tag ) {
				$out .= sprintf( '<meta property="article:tag" content="%s">' . "\n", esc_attr( $tag->name ) );
			}
		}
	}

	// Twitter.
	$out .= sprintf( '<meta name="twitter:card" content="%s">' . "\n", $image ? 'summary_large_image' : 'summary' );
	$out .= sprintf( '<meta name="twitter:title" content="%s">' . "\n", esc_attr( $title ) );
	$out .= sprintf( '<meta name="twitter:description" content="%s">' . "\n", esc_attr( $description ) );
	if ( $image && ! empty( $image['url'] ) ) {
		$out .= sprintf( '<meta name="twitter:image" content="%s">' . "\n", esc_url( $image['url'] ) );
		$out .= sprintf( '<meta name="twitter:image:alt" content="%s">' . "\n", esc_attr( ! empty( $image['alt'] ) ? $image['alt'] : $title ) );
	}

	echo $out; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- assembled from esc_* above.
}
// Replace core canonical with our paginate-aware one, then print meta early.
remove_action( 'wp_head', 'rel_canonical' );
add_action( 'wp_head', 'go_verge_seo_head', 1 );

/* -------------------------------------------------------------------------
 * schema.org JSON-LD @graph
 * ---------------------------------------------------------------------- */

/**
 * Resolve public trust-policy URLs used by NewsMediaOrganization.
 * Only published pages may become machine-readable policy claims. Missing
 * policy URLs are omitted; a plausible-looking 404 is not an E-E-A-T signal.
 *
 * @return array<string,string>
 */
function go_verge_schema_policy_urls() {
	$resolve = static function ( $slug ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $page instanceof WP_Post && 'publish' === get_post_status( $page ) ) {
			return get_permalink( $page );
		}
		return '';
	};
	$editorial = $resolve( 'politica-editorial' );
	$about     = $resolve( 'sobre-o-overdrive' );

	return array(
		'publishingPrinciples'      => $editorial,
		'ethicsPolicy'              => $editorial,
		'correctionsPolicy'         => $resolve( 'correcoes-e-atualizacoes' ) ?: $editorial,
		'verificationFactCheckingPolicy' => $resolve( 'politica-de-fontes-e-rumores' ) ?: $editorial,
		'actionableFeedbackPolicy'  => $resolve( 'contato' ),
		'masthead'                  => $about,
	);
}

/**
 * Organization / publisher node (referenced by every article's publisher).
 */
function go_verge_schema_organization() {
	$logo        = go_verge_seo_logo();
	$org_id      = home_url( '/#organization' );
	$description = trim( wp_strip_all_tags( (string) get_bloginfo( 'description' ) ) );

	$node = array(
		'@type' => 'NewsMediaOrganization',
		'@id'   => $org_id,
		'name'  => go_verge_seo_site_name(),
		'url'   => home_url( '/' ),
	);

	$alternate = go_verge_seo_alternate_name_value();
	if ( null !== $alternate ) {
		$node['alternateName'] = $alternate;
	}
	if ( '' !== $description ) {
		$node['description'] = $description;
	}

	if ( function_exists( 'go_verge_apply_editorial_scope_to_org' ) ) {
		$node = go_verge_apply_editorial_scope_to_org( $node );
	}

	if ( ! empty( $logo['url'] ) ) {
		$node['logo'] = array(
			'@type'      => 'ImageObject',
			'@id'        => home_url( '/#logo' ),
			'url'        => $logo['url'],
			'contentUrl' => $logo['url'],
			'width'      => (int) $logo['width'],
			'height'     => (int) $logo['height'],
			'caption'    => go_verge_seo_site_name(),
		);
		$node['image'] = array( '@id' => home_url( '/#logo' ) );
	}

	$same_as = array();
	if ( function_exists( 'go_verge_publisher_same_as_urls' ) ) {
		$same_as = go_verge_publisher_same_as_urls();
	} elseif ( function_exists( 'go_verge_get_social_links' ) ) {
		foreach ( go_verge_get_social_links() as $link ) {
			if ( ! empty( $link['url'] ) ) {
				$same_as[] = $link['url'];
			}
		}
	}
	if ( $same_as ) {
		$node['sameAs'] = array_values( array_unique( array_filter( array_map( 'esc_url_raw', $same_as ) ) ) );
	}

	if ( function_exists( 'go_verge_publisher_contact_email' ) ) {
		$email = go_verge_publisher_contact_email();
		if ( $email ) {
			$node['email']        = $email;
			$node['contactPoint'] = array(
				'@type'             => 'ContactPoint',
				'contactType'       => 'editorial',
				'email'             => $email,
				'availableLanguage' => get_bloginfo( 'language' ),
			);
		}
	}
	if ( function_exists( 'go_verge_publisher_legal_name' ) ) {
		$legal_name = go_verge_publisher_legal_name();
		if ( $legal_name ) {
			$node['legalName'] = $legal_name;
		}
	}
	if ( function_exists( 'go_verge_publisher_founding_date' ) ) {
		$founding_date = go_verge_publisher_founding_date();
		if ( $founding_date ) {
			$node['foundingDate'] = $founding_date;
		}
	}

	foreach ( go_verge_schema_policy_urls() as $property => $url ) {
		if ( $url ) {
			$node[ $property ] = esc_url_raw( $url );
		}
	}

	return $node;
}

/**
 * Merge editorial trust policies into Rank Math's publisher node.
 * This avoids emitting a duplicate organization solely to expose policies.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_rank_math_news_policies( $data ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}
	$policies = go_verge_schema_policy_urls();
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) {
			continue;
		}
		$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
		/* Organization is also a valid type for studios, publishers and companies
		 * represented by /universo/ hubs. Only the canonical publication @id may
		 * inherit Overdrive's newsroom policies. */
		$is_publisher = isset( $node['@id'] ) && home_url( '/#organization' ) === (string) $node['@id'];
		if ( ! $is_publisher ) {
			continue;
		}
		$data[ $key ]['@type'] = array_values( array_unique( array_merge( $types, array( 'NewsMediaOrganization' ) ) ) );
		foreach ( $policies as $property => $url ) {
			if ( $url ) {
				$data[ $key ][ $property ] = esc_url_raw( $url );
			} else {
				unset( $data[ $key ][ $property ] );
			}
		}
	}
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_news_policies', 950, 1 );


/**
 * Preferred editorial image used consistently by Rank Math and Search.
 *
 * A >=1200 px Discover candidate is preferred. Older uploads that only meet
 * Article's 50k-pixel recommendation remain valid structured-data images, but
 * are never promoted to og:image by this function.
 *
 * @return array<string,mixed>|null
 */
function go_verge_rank_math_preferred_editorial_image() {
	if ( ! is_singular( 'post' ) || ! has_post_thumbnail() ) {
		return null;
	}

	return go_verge_schema_editorial_image( get_queried_object_id() );
}

/**
 * Make Rank Math's site/publisher identity match the rebrand exactly.
 *
 * Rank Math owns the JSON-LD graph when active, so the theme-native graph steps
 * aside. This final pass prevents stale plugin settings from keeping the former
 * publisher/site name or icon alive in Google's structured-data inputs.
 *
 * @param array $data Rank Math JSON-LD graph.
 * @return array
 */
function go_verge_rank_math_brand_identity( $data ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}

	$logo = go_verge_seo_logo();
	/*
	 * Resolved once, outside the loop: the alias list is identical for every node
	 * and both the Organization and the WebSite have to carry it. Google reads the
	 * two independently, and a rebrand declared on only one of them is a rebrand
	 * declared half.
	 */
	$alternate   = go_verge_seo_alternate_name_value();
	$same_as     = function_exists( 'go_verge_publisher_same_as_urls' ) ? go_verge_publisher_same_as_urls() : array();
	$description = trim( wp_strip_all_tags( (string) get_bloginfo( 'description' ) ) );
	$email       = function_exists( 'go_verge_publisher_contact_email' ) ? go_verge_publisher_contact_email() : '';
	$legal_name  = function_exists( 'go_verge_publisher_legal_name' ) ? go_verge_publisher_legal_name() : '';
	$founded     = function_exists( 'go_verge_publisher_founding_date' ) ? go_verge_publisher_founding_date() : '';
	$preferred   = go_verge_rank_math_preferred_editorial_image();
	$current_url = go_verge_seo_canonical_url();
	if ( ! $current_url && is_singular() ) {
		$current_url = get_permalink();
	}
	$page_id     = $current_url ? $current_url . '#webpage' : '';

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) {
			continue;
		}

		$types      = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
		$is_org     = isset( $node['@id'] ) && home_url( '/#organization' ) === (string) $node['@id'];
		$is_web     = isset( $node['@id'] ) && home_url( '/#website' ) === (string) $node['@id'];
		$is_page    = (bool) array_intersect( $types, array( 'WebPage', 'ItemPage' ) ) && (
			( $page_id && isset( $node['@id'] ) && $page_id === (string) $node['@id'] )
			|| ( $current_url && isset( $node['url'] ) && untrailingslashit( $current_url ) === untrailingslashit( (string) $node['url'] ) )
		);
		$article_page = is_array( $node['mainEntityOfPage'] ?? null ) ? (string) ( $node['mainEntityOfPage']['@id'] ?? '' ) : (string) ( $node['mainEntityOfPage'] ?? '' );
		$is_article = is_singular( 'post' ) && (bool) array_intersect( $types, array( 'Article', 'NewsArticle', 'BlogPosting' ) ) && (
			( $page_id && $page_id === $article_page )
			|| ( $current_url && isset( $node['url'] ) && untrailingslashit( $current_url ) === untrailingslashit( (string) $node['url'] ) )
			|| ( $current_url && isset( $node['@id'] ) && 0 === strpos( (string) $node['@id'], $current_url . '#' ) )
		);

		if ( $is_org ) {
			$data[ $key ]['name'] = go_verge_seo_site_name();
			$data[ $key ]['url']  = home_url( '/' );
			if ( '' !== $description ) {
				$data[ $key ]['description'] = $description;
			}

			if ( function_exists( 'go_verge_apply_editorial_scope_to_org' ) ) {
				$data[ $key ] = go_verge_apply_editorial_scope_to_org( $data[ $key ] );
			}

			$existing_same_as = array_values( array_filter( (array) ( $data[ $key ]['sameAs'] ?? array() ) ) );
			$merged_same_as   = array_values( array_unique( array_filter( array_merge( $same_as, $existing_same_as ) ) ) );
			if ( $merged_same_as ) {
				$data[ $key ]['sameAs'] = $merged_same_as;
			}

			if ( $email ) {
				$data[ $key ]['email']        = $email;
				$data[ $key ]['contactPoint'] = array(
					'@type'             => 'ContactPoint',
					'contactType'       => 'editorial',
					'email'             => $email,
					'availableLanguage' => get_bloginfo( 'language' ),
				);
			}
			if ( $legal_name ) {
				$data[ $key ]['legalName'] = $legal_name;
			}
			if ( $founded ) {
				$data[ $key ]['foundingDate'] = $founded;
			}

			if ( null !== $alternate ) {
				$data[ $key ]['alternateName'] = $alternate;
			} else {
				/* Never leave Rank Math's copy of the primary name behind. */
				unset( $data[ $key ]['alternateName'] );
			}
			if ( ! empty( $logo['url'] ) ) {
				$data[ $key ]['logo'] = array(
					'@type'      => 'ImageObject',
					'@id'        => home_url( '/#logo' ),
					'url'        => $logo['url'],
					'contentUrl' => $logo['url'],
					'width'      => (int) $logo['width'],
					'height'     => (int) $logo['height'],
					'caption'    => go_verge_seo_site_name(),
				);
				$data[ $key ]['image'] = array( '@id' => home_url( '/#logo' ) );
			}
		}

		if ( $is_web ) {
			$data[ $key ]['name'] = go_verge_seo_site_name();
			$data[ $key ]['url']  = home_url( '/' );
			/* Google retired the sitelinks search box; keep WebSite, drop SearchAction. */
			unset( $data[ $key ]['potentialAction'] );
			if ( null !== $alternate ) {
				$data[ $key ]['alternateName'] = $alternate;
			} else {
				unset( $data[ $key ]['alternateName'] );
			}
		}

		if ( is_array( $preferred ) ) {
			if ( $is_article ) {
				$images = array( $preferred );
				if ( is_singular( 'post' ) && function_exists( 'go_verge_search_article_image_variants' ) ) {
					$known = array();
					foreach ( $images as $image ) {
						$url = is_array( $image ) ? (string) ( $image['url'] ?? $image['contentUrl'] ?? '' ) : (string) $image;
						if ( $url ) { $known[ $url ] = true; }
					}
					foreach ( go_verge_search_article_image_variants( get_queried_object_id() ) as $variant ) {
						$url = (string) ( $variant['url'] ?? '' );
						if ( $url && empty( $known[ $url ] ) ) {
							$images[]      = $variant;
							$known[ $url ] = true;
						}
					}
				}
				$data[ $key ]['image'] = 1 === count( $images ) ? $images[0] : $images;
			}
			if ( $is_page ) {
				$data[ $key ]['primaryImageOfPage'] = $preferred;
			}
		} elseif ( is_singular( 'post' ) && has_post_thumbnail() ) {
			/* An unreadable, unsupported or sub-50k featured upload must not leak
			 * back into the graph through Rank Math's original ImageObject/@id. */
			if ( $is_article ) {
				unset( $data[ $key ]['image'] );
			}
			if ( $is_page ) {
				unset( $data[ $key ]['primaryImageOfPage'] );
			}
		}

		/*
		 * One address for the home page across the whole graph.
		 *
		 * Organization, WebSite and every canonical use `home_url( '/' )` with the
		 * trailing slash, while Rank Math's breadcrumb opens on the bare host.
		 * Two spellings of the same node id is the sort of mismatch that keeps a
		 * consumer from collapsing them into one entity, and it costs nothing to
		 * make them identical.
		 */
		if ( in_array( 'BreadcrumbList', $types, true ) && ! empty( $node['itemListElement'] ) && is_array( $node['itemListElement'] ) ) {
			$home       = home_url( '/' );
			$home_bare  = untrailingslashit( $home );
			foreach ( $data[ $key ]['itemListElement'] as $index => $element ) {
				if ( ! is_array( $element ) || empty( $element['item'] ) || ! is_array( $element['item'] ) ) {
					continue;
				}
				if ( isset( $element['item']['@id'] ) && $home_bare === $element['item']['@id'] ) {
					$data[ $key ]['itemListElement'][ $index ]['item']['@id'] = $home;
				}
			}
		}
	}

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_brand_identity', 999, 1 );


/**
 * Prevent incomplete Event nodes from leaking out of Rank Math's graph.
 *
 * Google only supports Event rich results for a dedicated page about one real
 * event, and requires at least name, startDate and a physical Place with an
 * address. Rank Math schema can also be saved per-post in the database, so an
 * old/mistaken Event selection may survive theme changes and produce Search
 * Console errors even though this theme never creates Event markup itself.
 *
 * Do not invent dates, venues, tickets or organizers from article copy. If a
 * future post contains a genuinely complete Event node, this guard leaves it
 * untouched. It only removes Event/Event-subtype nodes that are already invalid
 * for Google's required fields.
 *
 * @param array $data Rank Math JSON-LD graph.
 * @return array
 */
function go_verge_rank_math_guard_invalid_events( $data ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}

	$removed_ids = array();
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || ! go_verge_schema_node_is_event( $node ) ) {
			continue;
		}

		if ( ! go_verge_schema_event_has_google_required_fields( $node ) ) {
			if ( ! empty( $node['@id'] ) ) {
				$removed_ids[] = (string) $node['@id'];
			}
			unset( $data[ $key ] );
		}
	}

	/* Do not leave WebPage/about/mainEntity edges pointing at a node removed by
	 * the validator. A dangling @id is harder to diagnose than an absent optional
	 * relationship and can make an otherwise valid page graph inconsistent. */
	if ( $removed_ids ) {
		foreach ( $data as $key => $node ) {
			if ( ! is_array( $node ) ) {
				continue;
			}
			foreach ( array( 'mainEntity', 'about', 'subjectOf', 'hasPart', 'mentions', 'subEvent', 'superEvent' ) as $property ) {
				$reference = $data[ $key ][ $property ] ?? null;
				if ( is_string( $reference ) && in_array( $reference, $removed_ids, true ) ) {
					unset( $data[ $key ][ $property ] );
					continue;
				}
				if ( is_array( $reference ) && isset( $reference['@id'] ) && in_array( (string) $reference['@id'], $removed_ids, true ) ) {
					unset( $data[ $key ][ $property ] );
					continue;
				}
				$is_list = is_array( $reference ) && ( array() === $reference || array_keys( $reference ) === range( 0, count( $reference ) - 1 ) );
				if ( $is_list ) {
					$filtered = array();
					foreach ( $reference as $reference_key => $item ) {
						if ( is_string( $item ) && in_array( $item, $removed_ids, true ) ) { continue; }
						if ( is_array( $item ) && isset( $item['@id'] ) && in_array( (string) $item['@id'], $removed_ids, true ) ) {
							continue;
						}
						$filtered[ $reference_key ] = $item;
					}
					if ( ! $filtered ) {
						unset( $data[ $key ][ $property ] );
					} else {
						$data[ $key ][ $property ] = array_values( $filtered );
					}
				}
			}
		}
	}

	return $data;
}

/**
 * Whether a schema node is Event or a schema.org Event subtype.
 *
 * @param array $node Schema node.
 * @return bool
 */
function go_verge_schema_node_is_event( $node ) {
	$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
	foreach ( $types as $type ) {
		$type = preg_replace( '~^https?://schema\\.org/~i', '', trim( $type ) );
		if ( 'Event' === $type || ( strlen( $type ) > 5 && 'Event' === substr( $type, -5 ) ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Validate only Google's required Event fields; recommended fields remain
 * optional and must never be fabricated merely to silence Search Console.
 *
 * @param array $node Event node.
 * @return bool
 */
function go_verge_schema_event_has_google_required_fields( $node ) {
	$name       = trim( wp_strip_all_tags( (string) ( $node['name'] ?? '' ) ) );
	$start_date = trim( (string) ( $node['startDate'] ?? '' ) );
	$location   = $node['location'] ?? null;

	if ( '' === $name || '' === $start_date || ! is_array( $location ) ) {
		return false;
	}

	$location_types = array_map( 'strval', (array) ( $location['@type'] ?? array() ) );
	$has_place      = false;
	foreach ( $location_types as $location_type ) {
		$location_type = preg_replace( '~^https?://schema\\.org/~i', '', trim( $location_type ) );
		if ( 'Place' === $location_type ) {
			$has_place = true;
			break;
		}
	}
	if ( ! $has_place ) {
		return false;
	}

	$address = $location['address'] ?? null;
	if ( is_string( $address ) ) {
		return '' !== trim( wp_strip_all_tags( $address ) );
	}
	if ( ! is_array( $address ) || empty( $address ) ) {
		return false;
	}

	/* A PostalAddress may be expressed in one line (`name`) or split fields. */
	foreach ( array( 'name', 'streetAddress', 'addressLocality', 'addressRegion', 'postalCode', 'addressCountry' ) as $field ) {
		if ( isset( $address[ $field ] ) && '' !== trim( wp_strip_all_tags( (string) $address[ $field ] ) ) ) {
			return true;
		}
	}

	return false;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_guard_invalid_events', 1001, 1 );

/**
 * WebSite node used for site-name/entity understanding.
 *
 * SearchAction is intentionally omitted: Google retired the sitelinks search
 * box globally in November 2024, while WebSite markup for site names remains
 * supported.
 */
function go_verge_schema_website() {
	$node = array(
		'@type'      => 'WebSite',
		'@id'        => home_url( '/#website' ),
		'url'        => home_url( '/' ),
		'name'       => go_verge_seo_site_name(),
		'inLanguage' => get_bloginfo( 'language' ),
		'publisher'  => array( '@id' => home_url( '/#organization' ) ),
	);

	/*
	 * Assigned after the literal, not inside it, so an empty alias list leaves the
	 * key out of the graph entirely instead of emitting `"alternateName": null` —
	 * which validators flag and which tells Google nothing.
	 */
	$alternate = go_verge_seo_alternate_name_value();
	if ( null !== $alternate ) {
		$node['alternateName'] = $alternate;
	}

	if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
		$node = go_verge_schema_add_accessibility( $node, true );
		$node['hasPart'] = array(
			'@type' => 'WebPage',
			'@id'   => go_verge_accessibility_page_url() . '#webpage',
			'url'   => go_verge_accessibility_page_url(),
			'name'  => __( 'Acessibilidade', 'go-verge' ),
		);
	}
	return $node;
}

/** Insert a graph node without overwriting a plugin or third-party key. */
function go_verge_schema_graph_add_unique( &$graph, $preferred_key, $node ) {
	if ( ! is_array( $graph ) || ! is_array( $node ) ) { return null; }
	$key = (string) $preferred_key;
	$suffix = 2;
	while ( array_key_exists( $key, $graph ) ) { $key = (string) $preferred_key . $suffix++; }
	$graph[ $key ] = $node;
	return $key;
}

/** Find one exact @id in a top-level Rank Math graph. */
function go_verge_schema_graph_find_id( $graph, $wanted ) {
	foreach ( (array) $graph as $key => $node ) {
		if ( is_array( $node ) && isset( $node['@id'] ) && (string) $node['@id'] === (string) $wanted ) { return $key; }
	}
	return null;
}

/** Whether a top-level schema node represents one exact public URL and type. */
function go_verge_schema_node_matches_url( $node, $wanted_url, $wanted_types = array() ) {
	if ( ! is_array( $node ) || '' === trim( (string) $wanted_url ) ) { return false; }
	$node_types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
	if ( $wanted_types && ! array_intersect( array_map( 'strval', (array) $wanted_types ), $node_types ) ) { return false; }

	$candidates = array( $node['url'] ?? '', $node['@id'] ?? '' );
	$main_page  = $node['mainEntityOfPage'] ?? '';
	if ( is_array( $main_page ) ) {
		$candidates[] = $main_page['@id'] ?? '';
		$candidates[] = $main_page['url'] ?? '';
	} else {
		$candidates[] = $main_page;
	}

	$wanted = untrailingslashit( (string) $wanted_url );
	foreach ( $candidates as $candidate ) {
		$candidate = trim( (string) $candidate );
		if ( '' === $candidate ) { continue; }
		$candidate = explode( '#', $candidate, 2 )[0];
		if ( $wanted === untrailingslashit( $candidate ) ) { return true; }
	}
	return false;
}

/** Merge duplicate top-level nodes with one exact @id and preserve one key. */
function go_verge_schema_graph_dedupe_id( &$graph, $wanted ) {
	if ( ! is_array( $graph ) ) { return null; }
	$keys     = array_keys( $graph );
	$was_list = array() === $keys || $keys === range( 0, count( $keys ) - 1 );
	$primary  = null;
	foreach ( array_keys( $graph ) as $key ) {
		$node = $graph[ $key ] ?? null;
		if ( ! is_array( $node ) || ! isset( $node['@id'] ) || (string) $wanted !== (string) $node['@id'] ) { continue; }
		if ( null === $primary ) {
			$primary = $key;
			continue;
		}
		$graph[ $primary ]        = array_replace( $graph[ $primary ], $node );
		$graph[ $primary ]['@id'] = (string) $wanted;
		unset( $graph[ $key ] );
	}
	if ( $was_list && null !== $primary ) {
		$graph   = array_values( $graph );
		$primary = go_verge_schema_graph_find_id( $graph, $wanted );
	}
	return $primary;
}

/** Whether any property in a graph references an exact schema @id. */
function go_verge_schema_graph_references_id( $value, $wanted ) {
	if ( is_string( $value ) ) { return (string) $wanted === $value; }
	if ( ! is_array( $value ) ) { return false; }
	if ( isset( $value['@id'] ) && (string) $value['@id'] === (string) $wanted ) { return true; }
	foreach ( $value as $item ) {
		if ( go_verge_schema_graph_references_id( $item, $wanted ) ) { return true; }
	}
	return false;
}

/** Close publisher/site references in every Rank Math surface, not only posts. */
function go_verge_rank_math_close_foundation_graph( $data ) {
	if ( ! is_array( $data ) ) { return $data; }
	$organization_id = home_url( '/#organization' );
	$website_id      = home_url( '/#website' );
	$needs_website   = go_verge_schema_graph_references_id( $data, $website_id );
	$needs_org       = $needs_website || go_verge_schema_graph_references_id( $data, $organization_id );
	if ( $needs_org && null === go_verge_schema_graph_find_id( $data, $organization_id ) ) {
		go_verge_schema_graph_add_unique( $data, 'goOrganization', go_verge_schema_organization() );
	}
	if ( $needs_website && null === go_verge_schema_graph_find_id( $data, $website_id ) ) {
		go_verge_schema_graph_add_unique( $data, 'goWebSite', go_verge_schema_website() );
	}
	go_verge_schema_graph_dedupe_id( $data, $organization_id );
	go_verge_schema_graph_dedupe_id( $data, $website_id );
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_close_foundation_graph', 900, 1 );

/**
 * Person node for an author.
 */
function go_verge_schema_person( $author_id ) {
	$author_id = (int) $author_id;
	$node      = array(
		'@type' => 'Person',
		'@id'   => get_author_posts_url( $author_id ) . '#person',
		'name'  => get_the_author_meta( 'display_name', $author_id ),
		'url'   => get_author_posts_url( $author_id ),
	);
	$bio = get_the_author_meta( 'description', $author_id );
	if ( '' !== trim( (string) $bio ) ) {
		$node['description'] = wp_strip_all_tags( $bio );
	}
	if ( function_exists( 'go_verge_author_role' ) ) {
		$role = go_verge_author_role( $author_id );
		if ( $role ) {
			$node['jobTitle'] = $role;
		}
	}
	if ( function_exists( 'go_verge_author_list_meta' ) ) {
		$topics = array_values(
			array_unique(
				array_merge(
					go_verge_author_list_meta( $author_id, 'go_author_coverage', 12 ),
					go_verge_author_list_meta( $author_id, 'go_author_expertise', 12 )
				)
			)
		);
		if ( $topics ) {
			$node['knowsAbout'] = $topics;
		}
	}
	if ( function_exists( 'go_verge_author_profile_value' ) ) {
		$location = go_verge_author_profile_value( $author_id, 'go_author_location' );
		if ( $location ) {
			$node['homeLocation'] = array( '@type' => 'Place', 'name' => $location );
		}
		$languages = go_verge_author_profile_value( $author_id, 'go_author_languages' );
		if ( $languages ) {
			$language_list = preg_split( '/[,;\n]+|\s+e\s+/u', $languages );
			$language_list = array_values( array_unique( array_filter( array_map( 'sanitize_text_field', array_map( 'trim', (array) $language_list ) ) ) ) );
			if ( $language_list ) {
				$node['knowsLanguage'] = array_slice( $language_list, 0, 8 );
			}
		}
		$public_email = sanitize_email( go_verge_author_profile_value( $author_id, 'go_author_public_email' ) );
		if ( $public_email ) {
			$node['email'] = 'mailto:' . $public_email;
		}
	}
	$node['worksFor'] = array( '@id' => home_url( '/#organization' ) );
	$avatar = get_avatar_url( $author_id, array( 'size' => 192 ) );
	if ( $avatar ) {
		$node['image'] = $avatar;
	}
	$home_host = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
	$home_host = 0 === strpos( $home_host, 'www.' ) ? substr( $home_host, 4 ) : $home_host;
	$same_as   = array();
	foreach ( array( 'url', 'twitter', 'facebook', 'instagram', 'youtube', 'linkedin', 'bluesky', 'mastodon', 'threads', 'tiktok', 'go_author_portfolio_url' ) as $key ) {
		$value = trim( (string) get_the_author_meta( $key, $author_id ) );
		if ( '' === $value || ! preg_match( '#^https?://#i', $value ) ) {
			continue;
		}
		$value = esc_url_raw( $value, array( 'http', 'https' ) );
		if ( ! $value ) {
			continue;
		}
		$host = strtolower( (string) wp_parse_url( $value, PHP_URL_HOST ) );
		$host = 0 === strpos( $host, 'www.' ) ? substr( $host, 4 ) : $host;
		if ( ! $host || ( $home_host && $host === $home_host ) ) {
			continue;
		}
		$same_as[] = set_url_scheme( $value, 'https' );
	}
	$same_as = (array) apply_filters( 'go_verge_author_same_as_urls', $same_as, $author_id );
	$same_as = array_values( array_unique( array_filter( $same_as ) ) );
	if ( $same_as ) {
		$node['sameAs'] = $same_as;
	}
	return $node;
}

/**
 * BreadcrumbList built from the same trail logic used on-screen.
 */
function go_verge_schema_breadcrumbs() {
	$trail = array( array( 'name' => __( 'Home', 'go-verge' ), 'url' => home_url( '/' ) ) );

	if ( is_category() || is_tag() || is_tax() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			foreach ( array_reverse( get_ancestors( $term->term_id, $term->taxonomy ) ) as $ancestor_id ) {
				$ancestor = get_term( $ancestor_id, $term->taxonomy );
				if ( $ancestor && ! is_wp_error( $ancestor ) ) {
					$trail[] = array( 'name' => $ancestor->name, 'url' => get_term_link( $ancestor ) );
				}
			}
			$trail[] = array( 'name' => $term->name, 'url' => get_term_link( $term ) );
		}
	} elseif ( is_singular() ) {
		if ( is_singular( 'games' ) ) {
			$games_url = get_post_type_archive_link( 'games' );
			$trail[]   = array(
				'name' => __( 'Games', 'go-verge' ),
				'url'  => $games_url ? $games_url : home_url( '/games/' ),
			);
		} elseif ( function_exists( 'go_verge_get_primary_term' ) ) {
			$primary = go_verge_get_primary_term( get_the_ID() );
			if ( $primary instanceof WP_Term ) {
				foreach ( array_reverse( get_ancestors( $primary->term_id, $primary->taxonomy ) ) as $ancestor_id ) {
					$ancestor = get_term( $ancestor_id, $primary->taxonomy );
					if ( $ancestor && ! is_wp_error( $ancestor ) ) {
						$trail[] = array( 'name' => $ancestor->name, 'url' => get_term_link( $ancestor ) );
					}
				}
				$trail[] = array( 'name' => $primary->name, 'url' => get_term_link( $primary ) );
			}
		}
		$trail[] = array( 'name' => get_the_title(), 'url' => go_verge_seo_canonical_url() );
	} else {
		return null;
	}

	$items = array();
	$pos   = 1;
	foreach ( $trail as $crumb ) {
		if ( empty( $crumb['name'] ) || is_wp_error( $crumb['url'] ) ) {
			continue;
		}
		$items[] = array(
			'@type'    => 'ListItem',
			'position' => $pos++,
			'name'     => wp_strip_all_tags( $crumb['name'] ),
			'item'     => esc_url_raw( $crumb['url'] ),
		);
	}

	if ( count( $items ) < 2 ) {
		return null;
	}

	return array(
		'@type'           => 'BreadcrumbList',
		'@id'             => go_verge_seo_canonical_url() . '#breadcrumb',
		'itemListElement' => $items,
	);
}

/**
 * Headings that open an FAQ block.
 *
 * Editors do not all write "Perguntas frequentes" - "Perguntas rapidas",
 * "Duvidas comuns" and "Perguntas e respostas" appear just as often. The visual
 * transform in theme.js and the FAQPage entity must agree on this list, or a
 * story gets the collapsible cards without the schema (or the reverse).
 *
 * Each entry is a regex fragment, accent-tolerant so a heading typed without
 * diacritics still matches. Keep it in sync with the alternation in theme.js.
 *
 * @return string[]
 */
function go_verge_faq_heading_variants() {
	return (array) apply_filters(
		'go_verge_faq_heading_variants',
		array(
			'perguntas?\s+(?:mais\s+)?frequentes?',
			'perguntas?\s+r[áa]pidas?',
			'perguntas?\s+(?:comuns|comum)',
			'perguntas?\s+e\s+respostas',
			'd[úu]vidas?\s+(?:mais\s+)?frequentes?',
			'd[úu]vidas?\s+r[áa]pidas?',
			'd[úu]vidas?\s+(?:comuns|comum)',
			'principais\s+d[úu]vidas',
			'tire\s+suas\s+d[úu]vidas',
			'faq',
		)
	);
}

/** The variants as one non-delimited alternation, safe inside / and # patterns. */
function go_verge_faq_heading_pattern() {
	return implode( '|', go_verge_faq_heading_variants() );
}

/**
 * Detect an in-content FAQ (mirrors the "Perguntas frequentes" transform in
 * theme.js) and return FAQPage entities for rich results / answer engines.
 */
function go_verge_schema_faq( $post_id ) {
	if ( function_exists( 'go_verge_is_guide_post' ) && ! go_verge_is_guide_post( $post_id ) ) {
		return null;
	}
	$content = get_post_field( 'post_content', $post_id );
	if ( '' === trim( (string) $content ) ) {
		return null;
	}
	$content = do_blocks( $content );
	$content = strip_shortcodes( $content );

	$faq_pattern = go_verge_faq_heading_pattern();
	if ( ! preg_match( '/(?:' . $faq_pattern . ')/iu', wp_strip_all_tags( $content ) ) ) {
		return null;
	}

	/* Accept the same editorial variants as theme.js, including headings such as
	 * "Perguntas rápidas", "Perguntas rápidas: GTA 6" and
	 * "Dúvidas comuns — atualização 1.2". */
	$faq_suffix = '(?:(?:\s+sobre\b|\s*[:—–-]\s*)[^<]*)?';

	// Split on headings; find the FAQ heading, then read following H3/H4 pairs.
	if ( ! preg_match( '#<h2[^>]*>\s*(?:<[^>]+>\s*)*(?:' . $faq_pattern . ')' . $faq_suffix . '#iu', $content ) ) {
		return null;
	}

	$faq_section = preg_split( '#<h2[^>]*>\s*(?:<[^>]+>\s*)*(?:' . $faq_pattern . ')' . $faq_suffix . '\s*</h2>#iu', $content, 2 );
	if ( count( $faq_section ) < 2 ) {
		return null;
	}
	$after = $faq_section[1];
	// Stop at the next H2 so we only capture the FAQ block.
	$after = preg_split( '#<h2[^>]*>#i', $after, 2 );
	$after = $after[0];

	$questions = array();

	$add_question = static function ( $q, $a ) use ( &$questions ) {
		$q = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $q ) ) );
		$a = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $a ) ) );
		if ( '' === $q || '' === $a || mb_strlen( $a ) < 3 ) {
			return;
		}
		$questions[] = array(
			'@type'          => 'Question',
			'name'           => $q,
			'acceptedAnswer' => array(
				'@type' => 'Answer',
				'text'  => $a,
			),
		);
	};

	// Primary structure: questions authored as H3/H4 headings.
	if ( preg_match_all( '#<h[34][^>]*>(.*?)</h[34]>(.*?)(?=<h[34][^>]*>|$)#is', $after, $matches, PREG_SET_ORDER ) ) {
		foreach ( $matches as $m ) {
			$add_question( $m[1], $m[2] );
		}
	}

	// Fallback (mirrors faq-fallback logic in theme.js): questions authored as
	// bold paragraphs -- <p><strong>Pergunta?</strong></p> followed by one or
	// more answer paragraphs -- instead of headings.
	if ( count( $questions ) < 2 && preg_match_all( '#<p\b[^>]*>(.*?)</p>#is', $after, $paras, PREG_SET_ORDER ) ) {
		$open_q = '';
		$open_a = '';
		foreach ( $paras as $p ) {
			$inner = $p[1];
			$text  = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $inner ) ) );
			if ( '' === $text ) {
				continue;
			}
			$bold = '';
			if ( preg_match_all( '#<(?:strong|b)\b[^>]*>(.*?)</(?:strong|b)>#is', $inner, $bm ) ) {
				$bold = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( implode( ' ', $bm[1] ) ) ) );
			}
			$is_question = ( mb_strlen( $text ) <= 260 && preg_match( '/\?\s*$/u', $text ) && '' !== $bold && $bold === $text );

			if ( $is_question ) {
				if ( '' !== $open_q ) {
					$add_question( $open_q, $open_a );
				}
				$open_q = $text;
				$open_a = '';
			} elseif ( '' !== $open_q ) {
				$open_a = trim( $open_a . ' ' . $text );
			}
		}
		if ( '' !== $open_q ) {
			$add_question( $open_q, $open_a );
		}
	}

	if ( count( $questions ) < 2 ) {
		return null;
	}

	return array(
		'@type'      => 'FAQPage',
		'@id'        => get_permalink( $post_id ) . '#faq',
		'mainEntity' => $questions,
	);
}

/**
 * Whether Speakable should be emitted for this publication locale.
 *
 * Google's Speakable integration remains a beta aimed at English news
 * publishers. Overdrive is pt-BR, so keep the markup off by default while
 * exposing a filter for a future supported locale/rollout.
 *
 * @return bool
 */
function go_verge_schema_speakable_supported() {
	$locale    = str_replace( '_', '-', (string) get_bloginfo( 'language' ) );
	$supported = 0 === stripos( $locale, 'en' );

	return (bool) apply_filters( 'go_verge_schema_speakable_supported', $supported, $locale );
}

/**
 * The @id of the WebPage node this request actually emits.
 *
 * go_verge_schema_webpage() identifies itself by the canonical URL, which on a
 * multipage or comment-paginated singular is NOT get_permalink(). Nodes that
 * built their own "#webpage" reference from the permalink therefore pointed at
 * a node no consumer could resolve. Resolve both sides from one place.
 *
 * @return string
 */
function go_verge_schema_current_webpage_id() {
	$url = go_verge_seo_canonical_url();
	if ( '' === $url ) {
		$url = get_permalink( get_queried_object_id() );
	}
	return $url ? $url . '#webpage' : '';
}

/**
 * Article node (NewsArticle/Article) for single posts.
 */
function go_verge_schema_article( $post_id, &$graph ) {
	$post = get_post( $post_id );
	if ( ! $post ) {
		return null;
	}

	$url         = get_permalink( $post_id );
	$webpage_id  = go_verge_schema_current_webpage_id();
	$is_review   = function_exists( 'go_verge_review_data' );
	$review_data = $is_review ? go_verge_review_data( $post_id ) : array( 'has_review' => false );
	$has_review  = ! empty( $review_data['has_review'] );

	$node = array(
		'@type'            => function_exists( 'go_verge_article_schema_type' ) ? go_verge_article_schema_type( $post_id ) : 'Article',
		'@id'              => $url . '#article',
		'isPartOf'         => array( '@id' => $webpage_id ),
		'mainEntityOfPage' => array( '@id' => $webpage_id ),
		'headline'         => wp_strip_all_tags( get_the_title( $post_id ) ),
		'datePublished'    => function_exists( 'go_verge_search_published_iso' ) ? go_verge_search_published_iso( $post_id ) : get_post_time( 'c', true, $post_id ),
		'dateModified'     => function_exists( 'go_verge_search_consistent_modified_iso' ) ? go_verge_search_consistent_modified_iso( $post_id ) : get_post_modified_time( 'c', true, $post_id ),
		'inLanguage'       => get_bloginfo( 'language' ),
		'publisher'        => array( '@id' => home_url( '/#organization' ) ),
	);

	$desc = go_verge_seo_description();
	if ( $desc ) {
		$node['description'] = $desc;
	}

	// Author (Person) — add to graph and reference here.
	$author_id           = (int) $post->post_author;
	$author_node         = go_verge_schema_person( $author_id );
	$graph[]             = $author_node;
	$node['author']      = array( '@id' => $author_node['@id'] );

	if ( has_post_thumbnail( $post_id ) ) {
		$img = go_verge_schema_editorial_image( $post_id );
		if ( is_array( $img ) ) {
			$node['image'] = $img;
		}
	}

	if ( function_exists( 'go_verge_get_primary_term' ) ) {
		$primary = go_verge_get_primary_term( $post_id );
		if ( $primary instanceof WP_Term ) {
			$node['articleSection'] = $primary->name;
		}
	}

	$tags = get_the_tags( $post_id );
	if ( $tags && ! is_wp_error( $tags ) ) {
		$node['keywords'] = wp_list_pluck( $tags, 'name' );
	}

	if ( go_verge_schema_speakable_supported() ) {
		$node['speakable'] = array(
			'@type'       => 'SpeakableSpecification',
			'cssSelector' => array( '.go-single__title', '.go-single__deck', '.go-scored-masthead__title', '.go-scored-masthead__deck' ),
		);
	} else {
		unset( $node['speakable'] );
	}

	// Scored reviews and film/TV critiques receive a dedicated Review node.
	// The reviewed item is resolved as VideoGame, Movie or TVSeries below.
	if ( $has_review && null !== $review_data['score'] ) {
		$review_node = go_verge_schema_review( $post_id, $review_data, $url );
		if ( is_array( $review_node ) ) {
			$graph[] = $review_node;
		}
	}

	if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
		$node = go_verge_schema_add_accessibility( $node, false );
	}
	if ( function_exists( 'go_verge_search_enrich_article_node' ) ) {
		$node = go_verge_search_enrich_article_node( $node, $post_id );
	}
	return $node;
}

/**
 * Review node for a scored game review or film/TV critique.
 */
function go_verge_schema_review( $post_id, $review_data, $url ) {
	$score = $review_data['score'] ?? null;
	if ( empty( $review_data['has_review'] ) || ! is_numeric( $score ) || ! is_finite( (float) $score ) || $score < 0 || $score > 10 ) { return null; }

	$is_critique = ! empty( $review_data['is_critique'] );
	$details     = ! empty( $review_data['technical_details'] ) && is_array( $review_data['technical_details'] ) ? $review_data['technical_details'] : array();

	$split_people = static function ( $value ) {
		$items = preg_split( '/\s*(?:,|;|\||\n)\s*/u', wp_strip_all_tags( (string) $value ) );
		return array_values( array_filter( array_map( 'trim', (array) $items ) ) );
	};
	$schema_date = static function ( $value ) {
		$value = trim( (string) $value );
		if ( preg_match( '/^(\d{4})-(\d{2})-(\d{2})$/', $value, $matches ) && checkdate( (int) $matches[2], (int) $matches[3], (int) $matches[1] ) ) { return $value; }
		if ( preg_match( '/^(\d{2})\/(\d{2})\/(\d{4})$/', $value, $matches ) && checkdate( (int) $matches[2], (int) $matches[1], (int) $matches[3] ) ) { return $matches[3] . '-' . $matches[2] . '-' . $matches[1]; }
		return '';
	};
	$schema_duration = static function ( $value ) {
		$value = trim( (string) $value );
		if ( preg_match( '/^PT(?=\d)(?:\d+H)?(?:\d+M)?(?:\d+(?:\.\d+)?S)?$/i', $value ) ) { return strtoupper( $value ); }
		$hours = 0;
		$minutes = 0;
		if ( preg_match( '/(\d+)\s*h(?:oras?)?/iu', $value, $matches ) ) { $hours = (int) $matches[1]; }
		if ( preg_match( '/(\d+)\s*(?:min|m)(?:utos?)?/iu', $value, $matches ) ) { $minutes = (int) $matches[1]; }
		if ( ! $hours && ! $minutes && preg_match( '/^(\d+)\s*(?:min|m)$/iu', $value, $matches ) ) { $minutes = (int) $matches[1]; }
		return ( $hours || $minutes ) ? 'PT' . ( $hours ? $hours . 'H' : '' ) . ( $minutes ? $minutes . 'M' : '' ) : '';
	};

	if ( $is_critique ) {
		$kind = ! empty( $details['kind'] ) ? (string) $details['kind'] : (string) ( $review_data['work_type'] ?? '' );
		/*
		 * Only types Google accepts for itemReviewed. `CreativeWork` and `Thing`
		 * are not on that list and Search Console rejects them outright, so a
		 * critique whose work type is unset or "outro" gets no Review node at all
		 * rather than an invalid one. Same rule as the Rank Math path in
		 * inc/editorial-trust-seo.php.
		 */
		$type_map = array(
			'filme'        => 'Movie',
			'documentario' => 'Movie',
			'serie'        => 'TVSeries',
			'anime'        => 'TVSeries',
		);
		if ( ! isset( $type_map[ $kind ] ) ) {
			return null;
		}
		$work_name = ! empty( $review_data['work_name'] ) ? $review_data['work_name'] : ( $details['title'] ?? '' );
		$item_reviewed = array(
			'@type' => $type_map[ $kind ],
			'name'  => wp_strip_all_tags( (string) $work_name ),
		);
		if ( ! empty( $details['genre'] ) ) { $item_reviewed['genre'] = wp_strip_all_tags( $details['genre'] ); }
		if ( ! empty( $details['director'] ) ) {
			$item_reviewed['director'] = array_map( static function ( $name ) { return array( '@type' => 'Person', 'name' => $name ); }, $split_people( $details['director'] ) );
		}
		if ( ! empty( $details['writer'] ) ) {
			$item_reviewed['creator'] = array_map( static function ( $name ) { return array( '@type' => 'Person', 'name' => $name ); }, $split_people( $details['writer'] ) );
		}
		if ( ! empty( $details['cast'] ) ) {
			$item_reviewed['actor'] = array_map( static function ( $name ) { return array( '@type' => 'Person', 'name' => $name ); }, $split_people( $details['cast'] ) );
		}
		if ( ! empty( $details['studio'] ) ) { $item_reviewed['productionCompany'] = array( '@type' => 'Organization', 'name' => wp_strip_all_tags( $details['studio'] ) ); }
		if ( ! empty( $details['rating'] ) ) { $item_reviewed['contentRating'] = wp_strip_all_tags( $details['rating'] ); }
		if ( ! empty( $details['country'] ) ) { $item_reviewed['countryOfOrigin'] = array( '@type' => 'Country', 'name' => wp_strip_all_tags( $details['country'] ) ); }
		$release_date = $schema_date( $details['release_date'] ?? '' );
		if ( $release_date ) { $item_reviewed['dateCreated'] = $release_date; }
		$duration = $schema_duration( $details['duration'] ?? '' );
		if ( $duration ) { $item_reviewed['duration'] = $duration; }
	} else {
		$game_name = ! empty( $review_data['game_name'] ) ? $review_data['game_name'] : ( $review_data['game_profile']['title'] ?? $details['title'] ?? '' );
		/*
		 * Google's Review rich-result allowlist accepts `Game`, but not the
		 * narrower schema.org `VideoGame` type for itemReviewed. Keep the
		 * reviewed item standards-valid and omit VideoGame-only properties
		 * such as gamePlatform from this Review node.
		 */
		$item_reviewed = array(
			'@type' => 'Game',
			'name'  => $game_name,
		);
		if ( ! empty( $review_data['game_profile']['url'] ) ) { $item_reviewed['url'] = $review_data['game_profile']['url']; }
		if ( ! empty( $review_data['publisher'] ) ) { $item_reviewed['publisher'] = array( '@type' => 'Organization', 'name' => $review_data['publisher'] ); }
		if ( ! empty( $review_data['genre'] ) ) { $item_reviewed['genre'] = $review_data['genre']; }
	}

	if ( '' === trim( wp_strip_all_tags( (string) $item_reviewed['name'] ) ) ) { return null; }

	$node = array(
		'@type'         => 'Review',
		'@id'           => $url . '#review',
		'isPartOf'      => array( '@id' => go_verge_schema_current_webpage_id() ),
		'mainEntityOfPage' => array( '@id' => go_verge_schema_current_webpage_id() ),
		'itemReviewed'  => $item_reviewed,
		'reviewRating'  => array(
			'@type'       => 'Rating',
			'ratingValue' => (string) $review_data['score'],
			'bestRating'  => '10',
			'worstRating' => '0',
		),
		'author'        => array( '@id' => get_author_posts_url( (int) get_post_field( 'post_author', $post_id ) ) . '#person' ),
		'publisher'     => array( '@id' => home_url( '/#organization' ) ),
		'datePublished' => function_exists( 'go_verge_search_published_iso' ) ? go_verge_search_published_iso( $post_id ) : get_post_time( 'c', true, $post_id ),
	);

	$summary = trim( wp_strip_all_tags( (string) ( $review_data['summary'] ?? '' ) ) );
	$verdict = trim( wp_strip_all_tags( (string) ( $review_data['verdict'] ?? '' ) ) );
	if ( $summary ) { $node['description'] = $summary; }
	if ( $verdict ) { $node['reviewBody'] = $verdict; }
	elseif ( $summary ) { $node['reviewBody'] = $summary; }

	if ( ! empty( $review_data['pros'] ) ) {
		$node['positiveNotes'] = array(
			'@type'           => 'ItemList',
			'itemListElement' => array_map( static function ( $item, $index ) { return array( '@type' => 'ListItem', 'position' => $index + 1, 'name' => $item ); }, array_values( $review_data['pros'] ), array_keys( array_values( $review_data['pros'] ) ) ),
		);
	}
	if ( ! empty( $review_data['cons'] ) ) {
		$node['negativeNotes'] = array(
			'@type'           => 'ItemList',
			'itemListElement' => array_map( static function ( $item, $index ) { return array( '@type' => 'ListItem', 'position' => $index + 1, 'name' => $item ); }, array_values( $review_data['cons'] ), array_keys( array_values( $review_data['cons'] ) ) ),
		);
	}
	if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
		$node = go_verge_schema_add_accessibility( $node, false );
	}

	return $node;
}

/**
 * VideoGame node for a games CPT single.
 */
function go_verge_schema_videogame( $post_id ) {
	$data = function_exists( 'go_verge_game_data' ) ? go_verge_game_data( $post_id ) : array();
	$url  = get_permalink( $post_id );

	$node = array(
		'@type'            => 'VideoGame',
		'@id'              => $url . '#videogame',
		'name'             => function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $post_id ) : wp_strip_all_tags( get_the_title( $post_id ) ),
		'url'              => $url,
		'mainEntityOfPage' => array( '@id' => go_verge_schema_current_webpage_id() ),
	);

	$images = array();
	foreach ( array_filter( array( get_post_thumbnail_id( $post_id ), absint( $data['hero_image_id'] ?? 0 ) ) ) as $image_id ) {
		$image_url = wp_get_attachment_image_url( $image_id, 'full' );
		if ( $image_url ) {
			$images[] = $image_url;
		}
	}
	foreach ( array_slice( (array) ( $data['gallery'] ?? array() ), 0, 3 ) as $gallery_url ) {
		if ( $gallery_url ) {
			$images[] = esc_url_raw( $gallery_url );
		}
	}
	$images = array_values( array_unique( array_filter( $images ) ) );
	if ( $images ) {
		$node['image']        = $images;
		$node['thumbnailUrl'] = $images[0];
	}

	$summary = ! empty( $data['summary'] ) ? $data['summary'] : get_the_excerpt( $post_id );
	if ( '' !== trim( (string) $summary ) ) {
		$node['description'] = wp_strip_all_tags( $summary );
	}

	if ( function_exists( 'go_verge_game_intelligence_aliases' ) ) {
		$aliases = array_values(
			array_filter(
				array_unique(
					array_map(
						'trim',
						array_map( 'wp_strip_all_tags', go_verge_game_intelligence_aliases( $post_id ) )
					)
				),
				static function ( $alias ) use ( $node ) {
					return '' !== $alias && 0 !== strcasecmp( $alias, $node['name'] );
				}
			)
		);
		if ( $aliases ) {
			$node['alternateName'] = array_slice( $aliases, 0, 20 );
		}
	}

	$split_list = static function ( $value ) {
		return array_values( array_filter( array_map( 'trim', preg_split( '/[,;|]+/u', (string) $value ) ) ) );
	};
	if ( ! empty( $data['platforms'] ) ) {
		$node['gamePlatform'] = $split_list( $data['platforms'] );
	}
	if ( ! empty( $data['genres'] ) ) {
		$node['genre'] = $split_list( $data['genres'] );
	}
	if ( ! empty( $data['languages'] ) ) {
		$node['inLanguage'] = $split_list( $data['languages'] );
	}
	if ( ! empty( $data['developer'] ) ) {
		$node['author'] = array( '@type' => 'Organization', 'name' => $data['developer'] );
	}
	if ( ! empty( $data['publisher'] ) ) {
		$node['publisher'] = array( '@type' => 'Organization', 'name' => $data['publisher'] );
	}
	$ts = ! empty( $data['release_date'] ) && function_exists( 'go_verge_game_release_timestamp' ) ? go_verge_game_release_timestamp( $data['release_date'] ) : 0;
	if ( $ts ) {
		$node['datePublished'] = gmdate( 'Y-m-d', $ts );
	}
	if ( ! empty( $data['age_rating'] ) ) {
		$node['contentRating'] = wp_strip_all_tags( $data['age_rating'] );
	}
	if ( ! empty( $data['director'] ) ) {
		$node['director'] = array( '@type' => 'Person', 'name' => wp_strip_all_tags( $data['director'] ) );
	}
	if ( ! empty( $data['edition'] ) ) {
		$node['gameEdition'] = wp_strip_all_tags( $data['edition'] );
	}
	if ( ! empty( $data['country'] ) ) {
		$node['countryOfOrigin'] = array( '@type' => 'Country', 'name' => wp_strip_all_tags( $data['country'] ) );
	}
	if ( ! empty( $data['franchise'] ) ) {
		$node['isPartOf'] = array( '@type' => 'CreativeWorkSeries', 'name' => wp_strip_all_tags( $data['franchise'] ) );
	}
	if ( ! empty( $data['official_site'] ) ) {
		$official_site = esc_url_raw( $data['official_site'] );
		if ( $official_site ) {
			$node['sameAs'] = array( $official_site );
		}
	}

	$mode_text = strtolower( remove_accents( (string) ( $data['modes'] ?? '' ) ) );
	$play_mode = array();
	if ( ! empty( $data['coop'] ) || preg_match( '/\b(?:coop|co-op|cooperativo)\b/u', $mode_text ) ) {
		$play_mode[] = 'https://schema.org/CoOp';
	}
	if ( preg_match( '/\b(?:multiplayer|multijogador|multijogadores)\b/u', $mode_text ) ) {
		$play_mode[] = 'https://schema.org/MultiPlayer';
	}
	if ( preg_match( '/\b(?:single-player|singleplayer|um jogador|solo)\b/u', $mode_text ) ) {
		$play_mode[] = 'https://schema.org/SinglePlayer';
	}
	if ( $play_mode ) {
		$node['playMode'] = array_values( array_unique( $play_mode ) );
	}

	$players = trim( wp_strip_all_tags( (string) ( $data['players'] ?? '' ) ) );
	if ( preg_match( '/(\d+)\s*(?:-|–|—|a|até)\s*(\d+)/iu', $players, $range ) ) {
		$node['numberOfPlayers'] = array(
			'@type'    => 'QuantitativeValue',
			'minValue' => (int) $range[1],
			'maxValue' => (int) $range[2],
		);
	} elseif ( preg_match( '/^\d+$/', $players ) ) {
		$node['numberOfPlayers'] = (int) $players;
	}

	return $node;
}

/**
 * Record the last human edit to an author profile for ProfilePage.dateModified.
 *
 * @param int $user_id User ID.
 */
function go_verge_schema_mark_author_profile_modified( $user_id ) {
	$user_id = absint( $user_id );
	if ( $user_id ) {
		update_user_meta( $user_id, '_go_author_profile_schema_modified_gmt', current_time( 'mysql', true ) );
	}
}
add_action( 'profile_update', 'go_verge_schema_mark_author_profile_modified', 10, 1 );
add_action( 'personal_options_update', 'go_verge_schema_mark_author_profile_modified', 10, 1 );
add_action( 'edit_user_profile_update', 'go_verge_schema_mark_author_profile_modified', 10, 1 );

/**
 * Creation/modification dates that describe the profile itself, not its posts.
 *
 * @param int $author_id User ID.
 * @return array<string,string>
 */
function go_verge_schema_author_profile_dates( $author_id ) {
	$user = get_userdata( absint( $author_id ) );
	if ( ! $user instanceof WP_User ) {
		return array();
	}

	$dates = array();
	if ( ! empty( $user->user_registered ) && '0000-00-00 00:00:00' !== $user->user_registered ) {
		$dates['dateCreated'] = get_date_from_gmt( $user->user_registered, 'c' );
	}
	$modified = (string) get_user_meta( $user->ID, '_go_author_profile_schema_modified_gmt', true );
	if ( $modified && '0000-00-00 00:00:00' !== $modified ) {
		$dates['dateModified'] = get_date_from_gmt( $modified, 'c' );
	}

	return $dates;
}

/**
 * Minimal recent-activity Article nodes for an author ProfilePage.hasPart.
 *
 * @param int $author_id User ID.
 * @param int $limit Maximum recent posts.
 * @return array<int,array<string,mixed>>
 */
function go_verge_schema_author_recent_activity( $author_id, $limit = 5 ) {
	$query = new WP_Query(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'author'                 => absint( $author_id ),
			'posts_per_page'         => max( 1, min( 10, absint( $limit ) ) ),
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'fields'                 => 'ids',
			'no_found_rows'          => true,
			'ignore_sticky_posts'    => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		)
	);

	$person_id = get_author_posts_url( absint( $author_id ) ) . '#person';
	$activity  = array();
	foreach ( (array) $query->posts as $post_id ) {
		$post = get_post( $post_id );
		if ( ! $post instanceof WP_Post ) {
			continue;
		}
		$url  = get_permalink( $post );
		$type = function_exists( 'go_verge_article_schema_type_auto' ) ? go_verge_article_schema_type_auto( $post ) : 'Article';
		$activity[] = array(
			'@type'         => $type,
			'@id'           => $url . '#article',
			'headline'      => wp_strip_all_tags( get_the_title( $post ) ),
			'url'           => $url,
			'datePublished' => get_post_time( 'c', true, $post ),
			'author'        => array( '@id' => $person_id ),
		);
	}

	return $activity;
}

/**
 * WebPage node tying the current URL to the site + breadcrumb.
 */
function go_verge_schema_webpage( $has_breadcrumb ) {
	$url  = go_verge_seo_canonical_url();
	$author_page = is_author() && function_exists( 'go_verge_author_archive_page_number' )
		? go_verge_author_archive_page_number()
		: max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	$node = array(
		'@type'      => is_author() && 1 === $author_page ? 'ProfilePage' : ( is_singular() ? 'WebPage' : 'CollectionPage' ),
		'@id'        => go_verge_schema_current_webpage_id(),
		'url'        => $url,
		'name'       => wp_get_document_title(),
		'isPartOf'   => array( '@id' => home_url( '/#website' ) ),
		'inLanguage' => get_bloginfo( 'language' ),
	);
	$desc = go_verge_seo_description();
	if ( $desc ) {
		$node['description'] = $desc;
	}
	if ( is_author() ) {
		$author_id          = absint( get_queried_object_id() );
		$person_id          = get_author_posts_url( $author_id ) . '#person';
		if ( $author_page > 1 ) {
			$node['about'] = array( '@id' => $person_id );
		} else {
			$node['mainEntity'] = array( '@id' => $person_id );
			foreach ( go_verge_schema_author_profile_dates( $author_id ) as $property => $value ) {
				$node[ $property ] = $value;
			}
			$activity = go_verge_schema_author_recent_activity( $author_id, 5 );
			if ( $activity ) {
				$node['hasPart'] = $activity;
			}
		}
	}
	if ( is_singular() ) {
		$post_id = get_queried_object_id();
		$node['datePublished'] = function_exists( 'go_verge_search_published_iso' )
			? go_verge_search_published_iso( $post_id )
			: get_post_time( 'c', true, $post_id );
		$node['dateModified']  = function_exists( 'go_verge_search_consistent_modified_iso' )
			? go_verge_search_consistent_modified_iso( $post_id )
			: get_post_modified_time( 'c', true, $post_id );
		if ( has_post_thumbnail() ) {
			$img = go_verge_schema_editorial_image( $post_id );
			if ( is_array( $img ) ) {
				$node['primaryImageOfPage'] = $img;
			}
		}
	}
	if ( $has_breadcrumb ) {
		$node['breadcrumb'] = array( '@id' => $url . '#webpage/breadcrumb' );
	}
	if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
		$node = go_verge_schema_add_accessibility( $node, true );
	}
	return $node;
}

/**
 * Assemble and print the JSON-LD @graph.
 */
function go_verge_schema_output() {
	if ( ! go_verge_seo_active() || is_preview() || ( is_singular() && post_password_required() ) ) {
		return;
	}

	$graph = array();

	$graph[] = go_verge_schema_organization();
	$graph[] = go_verge_schema_website();

	$breadcrumb = go_verge_schema_breadcrumbs();

	if ( is_singular( 'post' ) ) {
		$graph[] = go_verge_schema_webpage( (bool) $breadcrumb );
		$article = go_verge_schema_article( get_the_ID(), $graph );
		if ( $article ) {
			$graph[] = $article;
		}
	} elseif ( is_singular( 'games' ) ) {
		$page = go_verge_schema_webpage( (bool) $breadcrumb );
		if ( function_exists( 'go_verge_game_hub_webpage_schema' ) ) {
			$page = go_verge_game_hub_webpage_schema( get_the_ID(), $page );
		}
		$graph[] = $page;
		$game    = go_verge_schema_videogame( get_the_ID() );
		$graph[] = $game;
		if ( function_exists( 'go_verge_game_hub_coverage_schema' ) ) {
			$coverage = go_verge_game_hub_coverage_schema( get_the_ID(), $game['@id'] ?? '' );
			if ( $coverage ) {
				$graph[] = $coverage;
			}
		}
	} elseif ( is_singular( 'go_entity' ) ) {
		if ( function_exists( 'go_verge_entity_webpage_schema_node' ) ) {
			$entity_page = go_verge_entity_webpage_schema_node( get_the_ID() );
			if ( $entity_page ) {
				$graph[] = $entity_page;
			}
		} else {
			$graph[] = go_verge_schema_webpage( (bool) $breadcrumb );
		}
		if ( function_exists( 'go_verge_entity_schema_node' ) ) {
			$entity_node = go_verge_entity_schema_node( get_the_ID() );
			if ( $entity_node ) {
				$graph[] = $entity_node;
			}
		}
	} elseif ( is_singular() ) {
		$graph[] = go_verge_schema_webpage( (bool) $breadcrumb );
	} elseif ( is_author() ) {
		$graph[] = go_verge_schema_webpage( (bool) $breadcrumb );
		$graph[] = go_verge_schema_person( get_queried_object_id() );
	} elseif ( is_post_type_archive( 'go_entity' ) && function_exists( 'go_verge_entity_archive_schema_nodes' ) ) {
		$entity_archive_nodes = go_verge_entity_archive_schema_nodes();
		if ( ! empty( $entity_archive_nodes['page'] ) ) {
			$graph[] = $entity_archive_nodes['page'];
		}
		if ( ! empty( $entity_archive_nodes['list'] ) ) {
			$graph[] = $entity_archive_nodes['list'];
		}
	} elseif ( ! is_404() && ! is_search() ) {
		$graph[] = go_verge_schema_webpage( (bool) $breadcrumb );
	}

	if ( $breadcrumb ) {
		// Point the breadcrumb @id at the webpage's breadcrumb reference.
		$breadcrumb['@id'] = go_verge_seo_canonical_url() . '#webpage/breadcrumb';
		$graph[]           = $breadcrumb;
	}

	if ( empty( $graph ) ) {
		return;
	}

	$payload = array(
		'@context' => 'https://schema.org',
		'@graph'   => array_values( apply_filters( 'go_verge_native_schema_graph', $graph ) ),
	);

	echo "\n" . '<script type="application/ld+json">' . wp_json_encode( $payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) . '</script>' . "\n";
}
add_action( 'wp_head', 'go_verge_schema_output', 20 );

/* -------------------------------------------------------------------------
 * Sitemap hygiene
 * ---------------------------------------------------------------------- */

/**
 * Keep utility/system pages out of the core WordPress sitemap.
 *
 * @param array  $args      Query args.
 * @param string $post_type Post type.
 * @return array
 */
function go_verge_sitemap_exclude( $args, $post_type ) {
	if ( 'page' === $post_type ) {
		$exclude = array();
		foreach ( array( 'busca', 'para-voce', 'salvos', 'preferencias-newsletter', 'status' ) as $slug ) {
			$page = get_page_by_path( $slug );
			if ( $page ) {
				$exclude[] = $page->ID;
			}
		}
		if ( $exclude ) {
			$args['post__not_in'] = array_merge( isset( $args['post__not_in'] ) ? (array) $args['post__not_in'] : array(), $exclude );
		}
	}
	return $args;
}
add_filter( 'wp_sitemaps_posts_query_args', 'go_verge_sitemap_exclude', 10, 2 );

/**
 * Point search engines at the Google News sitemap from robots.txt.
 *
 * The canonical /sitemap.xml is added by search-indexing-architecture.php.
 * RSS remains discoverable through <link rel="alternate"> and is not
 * advertised as a sitemap, keeping robots.txt deterministic.
 *
 * @param string $output Robots.txt body.
 * @return string
 */
function go_verge_robots_txt( $output ) {
	$news = home_url( '/news-sitemap.xml' );
	if ( false === strpos( $output, 'news-sitemap.xml' ) ) {
		$output .= "\nSitemap: " . esc_url_raw( $news ) . "\n";
	}

	/* Do not create a special Googlebot-News group. A dedicated group can
	 * accidentally bypass crawl restrictions defined for User-agent: *. */
	return $output;
}
add_filter( 'robots_txt', 'go_verge_robots_txt', 20 );

/**
 * Site Health: surface the concrete Google News readiness signals that the
 * theme can verify locally. Search Console submission itself still happens in
 * Google's interface and cannot be automated by the theme.
 */
function go_verge_register_news_readiness_health_test( $tests ) {
	$tests['direct']['go_verge_news_readiness'] = array(
		'label' => __( 'Sinais técnicos para Google News', 'go-verge' ),
		'test'  => 'go_verge_news_readiness_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_news_readiness_health_test' );

function go_verge_news_readiness_health_test() {
	$missing = array();
	foreach ( array( 'sobre-o-overdrive', 'contato', 'politica-editorial' ) as $slug ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( ! ( $page instanceof WP_Post ) || 'publish' !== get_post_status( $page ) ) {
			$missing[] = $slug;
		}
	}

	$snapshot = function_exists( 'go_verge_news_authority_health_snapshot' )
		? go_verge_news_authority_health_snapshot()
		: array( 'eligible' => 0, 'missing_image' => 0, 'missing_author' => 0, 'missing_sources' => 0, 'room_count' => 0, 'publication' => '' );
	$publication_ok = go_verge_seo_site_name() === trim( (string) ( $snapshot['publication'] ?? '' ) );
	$room_ok        = (int) ( $snapshot['room_count'] ?? 0 ) > 0;
	$technical_ok   = empty( $missing ) && $publication_ok && $room_ok;

	$issues = array();
	if ( $missing ) {
		$issues[] = sprintf( esc_html__( 'Páginas institucionais ausentes: %s.', 'go-verge' ), esc_html( implode( ', ', $missing ) ) );
	}
	if ( ! $publication_ok ) {
		$issues[] = esc_html__( 'O nome da publicação no sitemap de notícias precisa ser “Game Overdrive”.', 'go-verge' );
	}
	if ( ! $room_ok ) {
		$issues[] = esc_html__( 'Nenhuma matéria classificada como notícia foi encontrada para a seção /noticias/.', 'go-verge' );
	}
	if ( (int) ( $snapshot['missing_image'] ?? 0 ) > 0 ) {
		$issues[] = sprintf( esc_html__( '%d notícia(s) recente(s) não têm imagem representativa de pelo menos 1200 px disponível para o News sitemap.', 'go-verge' ), (int) $snapshot['missing_image'] );
	}
	if ( (int) ( $snapshot['missing_author'] ?? 0 ) > 0 ) {
		$issues[] = sprintf( esc_html__( '%d notícia(s) recente(s) estão assinadas por autor sem biografia pública completa.', 'go-verge' ), (int) $snapshot['missing_author'] );
	}
	if ( (int) ( $snapshot['missing_sources'] ?? 0 ) > 0 ) {
		$issues[] = sprintf( esc_html__( '%d notícia(s) recente(s) não têm fonte primária registrada no bloco de Apuração e fontes. Isso é um alerta editorial, não um bloqueio técnico.', 'go-verge' ), (int) $snapshot['missing_sources'] );
	}

	$description  = '<p>' . esc_html__( 'O tema verifica os sinais que ele consegue controlar: identidade do publisher, seção permanente de notícias, News sitemap, páginas de confiança, autoria, imagem e evidência editorial. A inclusão e o ranking no Google News continuam sendo decisões automáticas do Google.', 'go-verge' ) . '</p>';
	$description .= '<p><strong>' . esc_html__( 'Últimas 48h:', 'go-verge' ) . '</strong> ' . sprintf(
		esc_html__( '%1$d matéria(s) elegível(is) ao News sitemap; %2$d matéria(s) na newsroom permanente.', 'go-verge' ),
		(int) ( $snapshot['eligible'] ?? 0 ),
		(int) ( $snapshot['room_count'] ?? 0 )
	) . '</p>';
	if ( $issues ) {
		$description .= '<ul><li>' . implode( '</li><li>', $issues ) . '</li></ul>';
	}

	return array(
		'label'       => $technical_ok
			? __( 'A arquitetura técnica de Google News está consistente', 'go-verge' )
			: __( 'Há sinais de Google News que precisam de atenção', 'go-verge' ),
		'status'      => $technical_ok ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Google News', 'go-verge' ), 'color' => 'blue' ),
		'description' => $description,
		'actions'     => sprintf(
			'<p><a href="%1$s" target="_blank" rel="noopener noreferrer">%2$s</a> · <a href="%3$s" target="_blank" rel="noopener noreferrer">%4$s</a></p>',
			esc_url( home_url( '/news-sitemap.xml' ) ),
			esc_html__( 'Abrir news-sitemap.xml', 'go-verge' ),
			esc_url( function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url() : home_url( '/noticias/' ) ),
			esc_html__( 'Abrir /noticias/', 'go-verge' )
		),
		'test'        => 'go_verge_news_readiness',
	);
}


/* -------------------------------------------------------------------------
 * Feed URL integrity
 *
 * Editorial internal links are frequently written as root-relative paths
 * ("/meu-nome-e-farah/"). That is correct inside the site and wrong inside a
 * feed: RSS has no document base, so a consumer resolves the path against its
 * own host or drops the link. Measured on production 02/09/2026, the main feed
 * carried 21 such links across 30 items — every one of them an internal link
 * that an aggregator, a newsreader or a syndication partner could not follow.
 *
 * Only the feed rendering is touched. The stored post content is never
 * modified, and only root-relative paths are rewritten: protocol-relative
 * ("//host/x"), absolute, anchor, mailto:, tel: and data: URLs are all left
 * exactly as they are.
 * ---------------------------------------------------------------------- */

/**
 * Absolutize root-relative src/href attributes for feed output.
 *
 * @param string $content Rendered feed content.
 * @return string
 */
function go_verge_feed_absolutize_urls( $content ) {
	if ( ! is_string( $content ) || '' === $content || false === strpos( $content, '/' ) ) {
		return $content;
	}

	/* A root-relative URL belongs to the origin, including when home_url() has
	 * a subdirectory. Never prepend that subdirectory a second time. */
	$parts = wp_parse_url( home_url() );
	if ( ! is_array( $parts ) || empty( $parts['scheme'] ) || empty( $parts['host'] ) ) {
		return $content;
	}
	$home = $parts['scheme'] . '://' . $parts['host'] . ( isset( $parts['port'] ) ? ':' . absint( $parts['port'] ) : '' );

	$out = preg_replace_callback(
		'#(?<![\w:-])(src|href)(\s*=\s*)(["\'])(/(?!/)[^"\']*)\3#i',
		static function ( $m ) use ( $home ) {
			return $m[1] . $m[2] . $m[3] . $home . $m[4] . $m[3];
		},
		$content
	);

	return is_string( $out ) ? $out : $content;
}
add_filter( 'the_content_feed', 'go_verge_feed_absolutize_urls', 20 );
add_filter( 'the_excerpt_rss', 'go_verge_feed_absolutize_urls', 20 );
add_filter( 'comment_text_rss', 'go_verge_feed_absolutize_urls', 20 );

/** Final safety boundary after legacy archive policies: private views stay private. */
function go_verge_robots_restricted_view() {
	return ! get_option( 'blog_public' ) || is_preview()
		|| ( is_singular() && ( post_password_required() || 'publish' !== get_post_status( get_queried_object_id() ) ) );
}
function go_verge_robots_final_restrictions( $robots ) {
	if ( ! is_array( $robots ) ) { return $robots; }
	if ( go_verge_robots_restricted_view() ) { $robots['noindex'] = true; }
	if ( ! empty( $robots['noindex'] ) || ! empty( $robots['none'] ) ) { unset( $robots['index'] ); }
	if ( ! empty( $robots['nofollow'] ) || ! empty( $robots['none'] ) ) { unset( $robots['follow'] ); }
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_robots_final_restrictions', PHP_INT_MAX );
function go_verge_rank_math_final_restrictions( $robots ) {
	if ( ! is_array( $robots ) ) { return $robots; }
	if ( go_verge_robots_restricted_view() ) { $robots['index'] = 'noindex'; }

	/*
	 * Preview and snippet limits describe how an indexed result is displayed, so
	 * they are meaningless once the page is noindex. They are injected early, at
	 * priority 30 (search-visibility.php), which cannot know that a later policy
	 * will set noindex: the date-archive, filtered-discovery, filtered-subject
	 * and filtered-hub decisions all run between 120 and 320. The result was a
	 * self-contradicting tag on every one of those surfaces:
	 *
	 *   noindex, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1
	 *
	 * Running last is the only place that can see the final decision. Rank Math's
	 * own advanced_robots() bails out on noindex for exactly this reason, but its
	 * bail only prevents ADDING the directives, and by then the theme has already
	 * put them in the main robots array.
	 */
	if ( isset( $robots['index'] ) && 'noindex' === (string) $robots['index'] ) {
		unset( $robots['max-image-preview'], $robots['max-snippet'], $robots['max-video-preview'] );
	}

	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_rank_math_final_restrictions', PHP_INT_MAX );
