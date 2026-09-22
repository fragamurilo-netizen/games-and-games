<?php
/**
 * Reusable rendering helpers for the Verge design system.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Uppercase helper that survives missing mbstring.
 */
function go_verge_upper( $text ) {
	return function_exists( 'mb_strtoupper' ) ? mb_strtoupper( $text, 'UTF-8' ) : strtoupper( $text );
}

/**
 * The one Page that owns the "Últimas" stream.
 *
 * Overdrive ended up with two of them: the Page the theme treats as canonical
 * everywhere (footer, home "Ver todas", sitemap, site map, ad context) and a
 * legacy duplicate that WordPress had been serving as the posts page. Both
 * rendered the same template under the same H1, so both were indexable and
 * competing. Everything that needs the URL now asks this one function, and the
 * redirect in inc/seo-authority-ai.php sends the other surface here.
 *
 * @return WP_Post|null Published hub page, or null when it does not exist.
 */
function go_verge_latest_hub_page() {
	static $page = false;
	if ( false !== $page ) {
		return $page;
	}
	$page = null;
	foreach ( array( 'ultimas-publicacoes', 'ultimas' ) as $slug ) {
		$candidate = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $candidate instanceof WP_Post && 'publish' === $candidate->post_status ) {
			$page = $candidate;
			break;
		}
	}
	return $page;
}

/**
 * Public URL of the "Últimas" hub.
 *
 * @param int $page Page number, for paginated links.
 * @return string
 */
function go_verge_latest_url( $page = 1 ) {
	$page = max( 1, absint( $page ) );
	$hub  = go_verge_latest_hub_page();
	$url  = $hub instanceof WP_Post ? get_permalink( $hub ) : home_url( '/ultimas-publicacoes/' );
	if ( $page > 1 ) {
		$url = trailingslashit( $url ) . 'page/' . $page . '/';
	}
	return $url;
}

/**
 * Turn an out-of-range page from a template-owned WP_Query into a real 404.
 *
 * WordPress validates pagination only against the main query. Several editorial
 * landing pages intentionally use a secondary query, so `/page/9999/` otherwise
 * remains a 200 response with an empty-state component: a classic soft 404 and
 * an effectively unbounded crawl space. Call this before get_header(), while
 * status and robots output can still follow the corrected query state.
 *
 * @param WP_Query|null $query Secondary query that owns the visible listing.
 * @param int      $page  Requested page number.
 * @return bool True when the request was converted to a 404 and rendered.
 */
function go_verge_render_empty_pagination_404( $query, $page ) {
	$page = max( 1, absint( $page ) );
	if ( $page <= 1 || ( $query instanceof WP_Query && $query->have_posts() ) ) {
		return false;
	}

	global $wp_query;
	if ( $wp_query instanceof WP_Query ) {
		$wp_query->set_404();
	}
	status_header( 404 );
	nocache_headers();

	$template = get_404_template();
	if ( $template ) {
		include $template;
	}

	return true;
}

/**
 * Whether the current request is the "Últimas" hub.
 *
 * Covers both surfaces: the hub Page itself and the WordPress posts page,
 * which still answers until the redirect lands (and on installs that keep it).
 *
 * @return bool
 */
function go_verge_is_latest_hub() {
	if ( is_home() && ! is_front_page() ) {
		return true;
	}
	$hub = go_verge_latest_hub_page();
	return $hub instanceof WP_Post && is_page( $hub->ID );
}


/**
 * Editorial support text for cards, archives and pages.
 *
 * Priority is always the dedicated editorial support line saved in
 * `_go_post_subtitle`. The native excerpt is only a fallback.
 *
 * @param int|null $post_id Post ID.
 * @return string
 */
function go_verge_support_text( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return '';
	}

	$support = get_post_meta( $post_id, '_go_post_subtitle', true );
	$support = trim( wp_strip_all_tags( (string) $support ) );

	if ( '' !== $support ) {
		// Editorial support lines never display a terminal full stop. Preserve ellipses.
		if ( ! preg_match( '/\.\.\.\s*$/u', $support ) ) {
			$support = preg_replace( '/\.\s*$/u', '', $support );
		}
		return trim( (string) $support );
	}

	return trim( wp_strip_all_tags( (string) get_the_excerpt( $post_id ) ) );
}

/**
 * Depth of a term (number of ancestors).
 */
function go_verge_term_depth( $term ) {
	if ( ! $term || is_wp_error( $term ) ) {
		return 0;
	}
	$depth  = 0;
	$parent = (int) $term->parent;
	$guard  = 0;
	while ( $parent && $guard < 10 ) {
		$depth++;
		$parent = (int) get_term( $parent, $term->taxonomy )->parent;
		$guard++;
	}
	return $depth;
}

/**
 * Resolve the "primary" term for a post: Rank Math primary category first,
 * then the deepest non-uncategorized term.
 */
function go_verge_get_primary_term( $post_id = null, $taxonomy = 'category' ) {
	$post_id = $post_id ? $post_id : get_the_ID();

	if ( 'category' === $taxonomy ) {
		$primary_id = (int) get_post_meta( $post_id, '_go_primary_category_id', true );
		if ( $primary_id ) {
			$term = get_term( $primary_id, 'category' );
			if ( $term && ! is_wp_error( $term ) && has_category( $primary_id, $post_id ) ) {
				return $term;
			}
		}

		$primary_id = (int) get_post_meta( $post_id, 'rank_math_primary_category', true );
		if ( $primary_id ) {
			$term = get_term( $primary_id, 'category' );
			if ( $term && ! is_wp_error( $term ) && has_category( $primary_id, $post_id ) ) {
				return $term;
			}
		}
	}

	$terms = get_the_terms( $post_id, $taxonomy );
	if ( empty( $terms ) || is_wp_error( $terms ) ) {
		return null;
	}

	$terms = array_filter( $terms, function ( $t ) {
		return ! in_array( $t->slug, array( 'sem-categoria-pt', 'uncategorized', 'sem-categoria' ), true );
	} );
	if ( empty( $terms ) ) {
		return null;
	}

	usort( $terms, function ( $a, $b ) {
		return go_verge_term_depth( $b ) - go_verge_term_depth( $a );
	} );

	return reset( $terms );
}

/**
 * Publication state and relative timestamp.
 *
 * The publication date is shown by default. When WordPress records a genuine
 * edit after publication, the modified date replaces it so list metadata reads
 * "Atualizado há..." instead of displaying two competing dates.
 */
function go_verge_time_html( $post_id = null ) {
	$post_id  = $post_id ? absint( $post_id ) : get_the_ID();
	$published = function_exists( 'go_verge_search_published_timestamp' )
		? (int) go_verge_search_published_timestamp( $post_id )
		: (int) get_post_time( 'U', true, $post_id );
	$modified_iso_for_time = function_exists( 'go_verge_search_consistent_modified_iso' )
		? go_verge_search_consistent_modified_iso( $post_id )
		: get_post_modified_time( 'c', true, $post_id );
	$modified  = (int) strtotime( (string) $modified_iso_for_time );
	$now       = (int) current_time( 'timestamp', true );

	/*
	 * Ignore the tiny modified/published difference WordPress can create during
	 * the first save. Sites may tune this threshold without changing templates.
	 */
	$update_threshold = max( 0, (int) apply_filters( 'go_verge_update_time_threshold', 60, $post_id ) );
	$is_updated       = $modified > ( $published + $update_threshold );
	$timestamp        = $is_updated ? $modified : $published;

	// Future timestamps can leak through previews. Keep the label natural.
	if ( $timestamp > $now ) {
		$timestamp = $now;
	}

	/* translators: %s: human time difference (e.g. "3 dias"). */
	$label = sprintf( __( 'há %s', 'go-verge' ), human_time_diff( $timestamp, $now ) );

	$datetime = $is_updated
		? ( function_exists( 'go_verge_search_consistent_modified_iso' ) ? go_verge_search_consistent_modified_iso( $post_id ) : get_post_modified_time( 'c', true, $post_id ) )
		: ( function_exists( 'go_verge_search_published_iso' ) ? go_verge_search_published_iso( $post_id ) : get_post_time( 'c', true, $post_id ) );

	return sprintf(
		'<time class="go-mono go-time go-time--%1$s" datetime="%2$s">%3$s</time>',
		$is_updated ? 'updated' : 'published',
		esc_attr( $datetime ),
		esc_html( $label )
	);
}


/**
 * Absolute publication/update dateline for an article page.
 *
 * Google News recommends a clear, visible date and time near the headline/body.
 * Archive cards intentionally keep the relative `go_verge_time_html()` label,
 * while single stories expose one unambiguous human-readable timestamp. A
 * meaningful update replaces the publication label instead of competing with
 * it. The original publication clock remains available to schema and sitemaps.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_article_dateline_html( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return '';
	}

	$published = function_exists( 'go_verge_search_published_timestamp' )
		? (int) go_verge_search_published_timestamp( $post_id )
		: (int) get_post_time( 'U', true, $post_id );
	$modified_iso = function_exists( 'go_verge_search_consistent_modified_iso' )
		? go_verge_search_consistent_modified_iso( $post_id )
		: get_post_modified_time( 'c', true, $post_id );
	$modified  = (int) strtotime( (string) $modified_iso );
	$threshold = max( 0, (int) apply_filters( 'go_verge_update_time_threshold', 60, $post_id ) );
	$is_updated = $modified > ( $published + $threshold );

	$published_iso = function_exists( 'go_verge_search_published_iso' )
		? go_verge_search_published_iso( $post_id )
		: get_post_time( 'c', true, $post_id );

	/* Keep the visible timezone identical to the publication timezone configured
	 * in WordPress. `wp_date()` receives UTC timestamps and formats them locally. */
	$format = (string) apply_filters( 'go_verge_article_dateline_format', 'd/m/Y \à\s H:i', $post_id );
	$published_label = wp_date( $format, $published );
	$modified_label  = wp_date( $format, $modified );

	$html = '<span class="go-article-dateline go-mono">';
	if ( $is_updated ) {
		$html .= '<span class="go-article-dateline__updated">' . esc_html__( 'Atualizado em', 'go-verge' ) . ' <time class="go-time go-time--updated" datetime="' . esc_attr( $modified_iso ) . '">' . esc_html( $modified_label ) . '</time></span>';
	} else {
		$html .= '<span class="go-article-dateline__published">' . esc_html__( 'Publicado em', 'go-verge' ) . ' <time class="go-time go-time--published" datetime="' . esc_attr( $published_iso ) . '">' . esc_html( $published_label ) . '</time></span>';
	}
	$html .= '</span>';

	return $html;
}

/**
 * Byline (author) as mono-uppercase micro text.
 *
 * The legacy second argument is kept for backwards compatibility with existing
 * templates, but no icon or avatar is rendered. Only the author's name is bold.
 */
function go_verge_byline( $post_id = null, $with_avatar = false ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$author  = absint( get_post_field( 'post_author', $post_id ) );
	if ( ! $author ) {
		return '';
	}

	$name = esc_html( get_the_author_meta( 'display_name', $author ) );

	return sprintf(
		'<a class="go-mono go-byline" href="%1$s"><strong class="go-byline__name">%2$s</strong></a>',
		esc_url( get_author_posts_url( $author ) ),
		$name
	);
}


/** Resolve a real page/category destination for the Explore rail. */
function go_verge_explore_destination_url( $page_slugs, $category_slugs, $fallback = '' ) {
	foreach ( (array) $page_slugs as $slug ) {
		$page = get_page_by_path( sanitize_title( $slug ) );
		if ( $page instanceof WP_Post && 'publish' === $page->post_status ) { return get_permalink( $page ); }
	}
	foreach ( (array) $category_slugs as $slug ) {
		$term = get_category_by_slug( sanitize_title( $slug ) );
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) { return $url; }
		}
	}
	return $fallback ?: home_url( '/' );
}

/** Latest representative image for one Explore destination. */
function go_verge_explore_image_id( $category_slugs, $excluded_image_ids = array() ) {
	$excluded_image_ids = array_values( array_filter( array_map( 'absint', (array) $excluded_image_ids ) ) );
	$exact_term_ids      = array();

	foreach ( (array) $category_slugs as $slug ) {
		$slug = sanitize_title( remove_accents( (string) $slug ) );
		if ( '' === $slug ) {
			continue;
		}

		$term = get_term_by( 'slug', $slug, 'category' );
		if ( $term instanceof WP_Term ) {
			$exact_term_ids[] = absint( $term->term_id );
		}
	}

	$exact_term_ids = array_values( array_unique( array_filter( $exact_term_ids ) ) );
	if ( empty( $exact_term_ids ) ) {
		return 0;
	}

	$direct_descendants = array();
	$direct_ancestors   = array();
	$all_descendants    = array();
	$all_ancestors      = array();

	foreach ( $exact_term_ids as $term_id ) {
		$term = get_term( $term_id, 'category' );
		if ( $term instanceof WP_Term && $term->parent ) {
			$direct_ancestors[] = absint( $term->parent );
		}

		$children = get_terms(
			array(
				'taxonomy'   => 'category',
				'hide_empty' => false,
				'parent'     => $term_id,
				'fields'     => 'ids',
			)
		);
		if ( ! is_wp_error( $children ) ) {
			$direct_descendants = array_merge( $direct_descendants, array_map( 'absint', (array) $children ) );
		}

		$descendants = get_term_children( $term_id, 'category' );
		if ( ! is_wp_error( $descendants ) ) {
			$all_descendants = array_merge( $all_descendants, array_map( 'absint', (array) $descendants ) );
		}

		$ancestors = get_ancestors( $term_id, 'category', 'taxonomy' );
		if ( $ancestors ) {
			$all_ancestors = array_merge( $all_ancestors, array_map( 'absint', (array) $ancestors ) );
		}
	}

	$tiers = array(
		$exact_term_ids,
		array_values( array_unique( array_filter( $direct_descendants ) ) ),
		array_values( array_unique( array_filter( $direct_ancestors ) ) ),
		array_values( array_unique( array_diff( array_filter( $all_descendants ), $direct_descendants ) ) ),
		array_values( array_unique( array_diff( array_filter( $all_ancestors ), $direct_ancestors ) ) ),
	);

	$fallback_image_id = 0;

	foreach ( $tiers as $term_ids ) {
		if ( empty( $term_ids ) ) {
			continue;
		}

		$query = new WP_Query(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => 80,
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'fields'              => 'ids',
				'tax_query'           => array(
					array(
						'taxonomy'         => 'category',
						'field'            => 'term_id',
						'terms'            => $term_ids,
						'include_children' => false,
					),
				),
				'meta_query'          => array(
					array(
						'key'     => '_thumbnail_id',
						'compare' => 'EXISTS',
					),
				),
				'orderby'             => array(
					'date' => 'DESC',
					'ID'   => 'DESC',
				),
			)
		);

		foreach ( (array) $query->posts as $candidate_id ) {
			$image_id = absint( get_post_thumbnail_id( absint( $candidate_id ) ) );
			if ( ! $image_id ) {
				continue;
			}

			if ( ! $fallback_image_id ) {
				$fallback_image_id = $image_id;
			}

			if ( ! in_array( $image_id, $excluded_image_ids, true ) ) {
				return $image_id;
			}
		}
	}

	return $fallback_image_id;
}

/**
 * Google preferred-source destination for this publication.
 *
 * Google may vary feature availability by account or market. Keeping the URL
 * filterable lets the publisher replace it without editing templates.
 */
function go_verge_google_preferred_source_url() {
	$url = 'https://www.google.com/preferences/source?q=gameoverdrive.com.br';
	return (string) apply_filters( 'go_verge_google_preferred_source_url', $url, 'gameoverdrive.com.br' );
}

/**
 * Compact preferred-source CTA used at the start of the article body.
 *
 * The destination is Google's supported preferred-source deeplink. Keeping the
 * CTA as a normal link avoids loading another third-party script before the
 * reader starts the article, while still preserving Google's source-selection
 * flow.
 */
function go_verge_render_preferred_source_button( $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || ! is_singular( 'post' ) ) {
		return;
	}

	$url = go_verge_google_preferred_source_url();
	if ( ! $url ) {
		return;
	}
	?>
	<div class="go-preferred-source-row">
		<a
			class="go-preferred-source-pill"
			href="<?php echo esc_url( $url ); ?>"
			target="_blank"
			rel="noopener noreferrer"
			aria-label="<?php esc_attr_e( 'Adicionar o Overdrive às fontes preferidas do Google', 'go-verge' ); ?>"
		>
			<span class="go-preferred-source-pill__google" aria-hidden="true">
				<svg class="go-preferred-source-pill__google-mark" viewBox="0 0 18 18" width="18" height="18" focusable="false" aria-hidden="true">
					<path fill="#4285F4" d="M17.64 9.205c0-.638-.057-1.252-.164-1.841H9v3.482h4.844a4.14 4.14 0 0 1-1.797 2.716v2.258h2.909c1.702-1.567 2.684-3.874 2.684-6.615z"/>
					<path fill="#34A853" d="M9 18c2.43 0 4.468-.806 5.956-2.18l-2.91-2.258c-.805.54-1.835.858-3.046.858-2.344 0-4.328-1.584-5.037-3.71H.955v2.332A8.997 8.997 0 0 0 9 18z"/>
					<path fill="#FBBC05" d="M3.963 10.71A5.42 5.42 0 0 1 3.68 9c0-.593.102-1.17.284-1.71V4.958H.955A9.003 9.003 0 0 0 0 9c0 1.45.347 2.823.955 4.042l3.008-2.332z"/>
					<path fill="#EA4335" d="M9 3.58c1.321 0 2.507.454 3.441 1.346l2.582-2.582C13.464.892 11.426 0 9 0A8.997 8.997 0 0 0 .955 4.958L3.963 7.29C4.672 5.164 6.656 3.58 9 3.58z"/>
				</svg>
			</span>
			<span><?php esc_html_e( 'Priorizar meus resultados no Google', 'go-verge' ); ?></span>
		</a>
	</div>
	<?php
}

/** Backward-compatible alias for older template calls. */
function go_verge_render_preferred_source_card( $post_id = 0 ) {
	go_verge_render_preferred_source_button( $post_id );
}

/** Shared Explore destinations used on the homepage and article endings. */
/**
 * Featured image for the Promotions Explore card.
 *
 * This intentionally uses the same editorial query as the Promotions archive,
 * so any article visible in "Últimas publicações" is eligible for the card.
 */
function go_verge_explore_promotions_image_id( $excluded_image_ids = array() ) {
	$excluded_image_ids = array_values( array_filter( array_map( 'absint', (array) $excluded_image_ids ) ) );

	if ( ! function_exists( 'go_verge_query_promotion_articles' ) ) {
		return 0;
	}

	$query = go_verge_query_promotion_articles(
		40,
		array(
			'no_found_rows' => true,
			'fields'        => 'ids',
		)
	);

	$fallback_image_id = 0;

	foreach ( (array) $query->posts as $candidate_id ) {
		$image_id = absint( get_post_thumbnail_id( absint( $candidate_id ) ) );
		if ( ! $image_id ) {
			continue;
		}

		if ( ! $fallback_image_id ) {
			$fallback_image_id = $image_id;
		}

		if ( ! in_array( $image_id, $excluded_image_ids, true ) ) {
			return $image_id;
		}
	}

	return $fallback_image_id;
}

function go_verge_explore_overdrive_items() {
	static $items = null;
	if ( null !== $items ) { return $items; }
	$definitions = array(
		array( 'label' => 'Games', 'pages' => array( 'games' ), 'categories' => array( 'games', 'jogos' ), 'fallback' => '/games/' ),
		array( 'label' => 'Entretenimento', 'pages' => array( 'entretenimento' ), 'categories' => array( 'entretenimento' ), 'fallback' => '/entretenimento/' ),
		array( 'label' => 'Tecnologia', 'pages' => array( 'tecnologia' ), 'categories' => array( 'tecnologia' ), 'fallback' => '/tecnologia/' ),
		array( 'label' => 'Ofertas e Compras', 'pages' => array( 'ofertas', 'promocoes' ), 'categories' => array( 'ofertas', 'promocoes' ), 'fallback' => '/ofertas/' ),
	);
	$items       = array();
	$used_images = array();
	foreach ( $definitions as $definition ) {
		$image_id = go_verge_explore_image_id( $definition['categories'], $used_images );
		if ( ! $image_id ) { $image_id = go_verge_explore_fallback_image_id( $used_images ); }
		if ( $image_id ) { $used_images[] = $image_id; }
		$items[] = array(
			'label'    => $definition['label'],
			'url'      => go_verge_explore_destination_url( $definition['pages'], $definition['categories'], home_url( $definition['fallback'] ) ),
			'image_id' => $image_id,
		);
	}
	return apply_filters( 'go_verge_explore_overdrive_items', $items );
}

/** Newest site-wide thumbnail not already used by another Explore tile. */
function go_verge_explore_fallback_image_id( $excluded_image_ids = array() ) {
	$excluded_image_ids = array_values( array_filter( array_map( 'absint', (array) $excluded_image_ids ) ) );
	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 60,
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'orderby'             => 'date',
			'order'               => 'DESC',
			'meta_key'            => '_thumbnail_id',
		)
	);
	$fallback_image_id = 0;
	foreach ( $query->posts as $candidate ) {
		$image_id = absint( get_post_thumbnail_id( $candidate->ID ) );
		if ( ! $image_id ) {
			continue;
		}
		if ( ! $fallback_image_id ) {
			$fallback_image_id = $image_id;
		}
		if ( ! in_array( $image_id, $excluded_image_ids, true ) ) {
			return $image_id;
		}
	}
	return $fallback_image_id;
}

/**
 * Compact image-led navigation for the site's main editorial sections, without copying
 * another publisher's card treatment.
 */
function go_verge_render_explore_overdrive( $context = 'home' ) {
	$items = go_verge_explore_overdrive_items();
	if ( empty( $items ) ) { return; }
	$context = sanitize_html_class( $context ?: 'home' );
	?>
	<section class="go-container go-explore-overdrive go-explore-overdrive--<?php echo esc_attr( $context ); ?>" aria-labelledby="go-explore-overdrive-<?php echo esc_attr( $context ); ?>">
		<div class="go-explore-overdrive__head">
			<h2 id="go-explore-overdrive-<?php echo esc_attr( $context ); ?>" class="go-section__title"><?php esc_html_e( 'Explore o Overdrive', 'go-verge' ); ?></h2>
		</div>
		<nav class="go-explore-overdrive__rail" aria-label="<?php esc_attr_e( 'Principais editorias do Overdrive', 'go-verge' ); ?>">
			<?php foreach ( $items as $item ) : ?>
				<a class="go-explore-tile<?php echo empty( $item['image_id'] ) ? ' go-explore-tile--empty' : ''; ?>" href="<?php echo esc_url( $item['url'] ); ?>">
					<span class="go-explore-tile__media" aria-hidden="true">
						<?php if ( ! empty( $item['image_id'] ) ) : ?>
							<?php echo wp_get_attachment_image( (int) $item['image_id'], 'go_card', false, array( 'loading' => 'lazy', 'decoding' => 'async', 'sizes' => '(max-width: 560px) 42vw, (max-width: 960px) 28vw, 180px' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
						<?php endif; ?>
					</span>
					<strong class="go-explore-tile__label"><?php echo esc_html( $item['label'] ); ?></strong>
				</a>
			<?php endforeach; ?>
		</nav>
	</section>
	<?php
}

/**
 * Estimated reading time in minutes (based on content word count).
 */
function go_verge_reading_time( $post_id = null ) {
	$post_id = $post_id ? $post_id : get_the_ID();
	$content = get_post_field( 'post_content', $post_id );
	$text    = wp_strip_all_tags( (string) $content );
	// str_word_count() only recognises ASCII letters, so accented pt-BR words
	// (ação, coração, missão) split into several "words" and inflate the estimate.
	// Count Unicode letter/number runs instead, with an ASCII fallback.
	$words   = preg_match_all( '/[\p{L}\p{N}]+/u', $text );
	if ( ! $words ) {
		$words = str_word_count( $text );
	}
	return max( 1, (int) ceil( $words / 200 ) );
}

/**
 * Pull a numeric review score if the post carries one (several possible meta keys).
 * Returns float or null.
 */
function go_verge_review_score( $post_id = null ) {
	$post_id = $post_id ? $post_id : get_the_ID();
	$keys    = array( 'go_critique_score', 'go_review_score', '_go_review_score', 'review_score', '_go_score', 'nota', 'rating', 'score' );
	foreach ( $keys as $key ) {
		$value = get_post_meta( $post_id, $key, true );
		$numeric_value = is_string( $value ) ? str_replace( ',', '.', trim( $value ) ) : $value;
		if ( '' !== $numeric_value && is_numeric( $numeric_value ) ) {
			if ( function_exists( 'go_verge_normalize_review_score' ) ) {
				return go_verge_normalize_review_score( $numeric_value );
			}
			return (float) $numeric_value;
		}
	}
	return null;
}

/**
 * Whether a post belongs to the review editorial format, including legacy
 * reviews that only carry a score or the Reviews taxonomy.
 */
function go_verge_is_review_post( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return false;
	}
	if ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) ) {
		return false;
	}

	/* Editorial Desk is the canonical source for the current format. A Review
	 * must keep the review presentation even before score/verdict/pros/cons are
	 * filled in. Legacy signals below remain as backwards-compatible fallbacks. */
	if ( taxonomy_exists( 'go_content_type' ) ) {
		$content_types = wp_get_post_terms( $post_id, 'go_content_type', array( 'fields' => 'slugs' ) );
		if ( ! is_wp_error( $content_types ) && in_array( 'review', (array) $content_types, true ) ) {
			return true;
		}
	}

	if ( null !== go_verge_review_score( $post_id ) ) {
		return true;
	}
	if ( function_exists( 'go_verge_review_data' ) && ! empty( go_verge_review_data( $post_id )['has_review'] ) ) {
		return true;
	}
	$terms = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
	if ( is_wp_error( $terms ) ) {
		return false;
	}
	foreach ( (array) $terms as $slug ) {
		if ( in_array( $slug, array( 'reviews', 'review', 'analises', 'analises-de-jogos' ), true ) || preg_match( '/(?:^|-)(?:review|reviews|analise|analises)(?:-|$)/', $slug ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Whether a post is one of the two editorial formats allowed to expose a
 * rating: game reviews and entertainment critiques.
 */
function go_verge_is_scored_editorial_post( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return false;
	}

	if ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) ) {
		return true;
	}

	return go_verge_is_review_post( $post_id );
}

/**
 * Scores are exposed only for the post currently open on a review or critique
 * single. This deliberately excludes home, archives, landing pages, widgets
 * and related cards rendered inside the same single.
 */
function go_verge_should_show_review_scores( $post_id = null ) {
	if ( ! is_singular( 'post' ) ) {
		return false;
	}

	$queried_id = absint( get_queried_object_id() );
	$post_id    = $post_id ? absint( $post_id ) : $queried_id;

	if ( ! $queried_id || $post_id !== $queried_id ) {
		return false;
	}

	return go_verge_is_scored_editorial_post( $queried_id );
}

/**
 * Score badge markup (only when a score exists and the current surface is
 * allowed to expose review ratings).
 */
function go_verge_score_badge( $post_id = null ) {
	if ( ! go_verge_should_show_review_scores( $post_id ) ) {
		return '';
	}
	$score = go_verge_review_score( $post_id );
	if ( null === $score ) {
		return '';
	}
	if ( function_exists( 'go_verge_normalize_review_score' ) ) {
		$score = go_verge_normalize_review_score( $score );
	}
	$tier = $score >= 8 ? 'is-high' : ( $score >= 5 ? 'is-mid' : 'is-low' );
	$label = function_exists( 'go_verge_review_score_display' ) ? go_verge_review_score_display( $score ) : rtrim( rtrim( number_format( (float) $score, 1, '.', '' ), '0' ), '.' );
	return sprintf(
		'<span class="go-score %1$s" aria-label="%3$s">%2$s</span>',
		esc_attr( $tier ),
		esc_html( $label ),
		esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $label ) )
	);
}

/**
 * Whether a post or one of its category ancestors matches an editorial format.
 *
 * @param int|null $post_id Post ID.
 * @param string[] $aliases Accepted category slugs/names.
 * @param string $pattern Optional category token pattern.
 * @param string $excluded_pattern Optional pattern that invalidates a match.
 * @return bool
 */
function go_verge_post_has_editorial_format( $post_id, $aliases, $pattern = '', $excluded_pattern = '' ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return false;
	}

	$aliases = array_map( 'sanitize_title', (array) $aliases );
	$terms   = wp_get_post_terms( $post_id, 'category' );
	if ( is_wp_error( $terms ) ) {
		return false;
	}

	$seen = array();
	foreach ( (array) $terms as $term ) {
		$current = $term;
		while ( $current instanceof WP_Term && empty( $seen[ $current->term_id ] ) ) {
			$seen[ $current->term_id ] = true;
			$slug = sanitize_title( $current->slug );
			$name = sanitize_title( $current->name );
			$excluded = $excluded_pattern && ( preg_match( $excluded_pattern, $slug ) || preg_match( $excluded_pattern, $name ) );
			if ( ! $excluded && ( in_array( $slug, $aliases, true ) || in_array( $name, $aliases, true ) || ( $pattern && ( preg_match( $pattern, $slug ) || preg_match( $pattern, $name ) ) ) ) ) {
				return true;
			}
			if ( ! $current->parent ) {
				break;
			}
			$current = get_term( (int) $current->parent, 'category' );
			if ( is_wp_error( $current ) ) {
				break;
			}
		}
	}

	return false;
}

/** Whether a post belongs to a Dicas e Guias editorial surface. */
function go_verge_post_is_guide( $post_id = null ) {
	/* A Lista or Ranking nested below a broad help category keeps its own format. */
	if ( go_verge_post_is_ranking( $post_id ) || go_verge_post_is_list( $post_id ) ) {
		return false;
	}

	if ( function_exists( 'go_verge_is_guide_post' ) ) {
		return go_verge_is_guide_post( $post_id );
	}

	return go_verge_post_has_editorial_format(
		$post_id,
		array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'detonados', 'tutoriais', 'tutorial' ),
		'/(?:^|-)(?:guia|guias|dica|dicas|detonado|detonados|tutorial|tutoriais)(?:-|$)/'
	);
}

/** Whether a post belongs to a Ranking editorial surface. */
function go_verge_post_is_ranking( $post_id = null ) {
	return go_verge_post_has_editorial_format(
		$post_id,
		array( 'ranking', 'rankings' ),
		'/(?:^|-)(?:ranking|rankings)(?:-|$)/',
		'/(?:lista|listas).*?(?:ranking|rankings)|(?:ranking|rankings).*?(?:lista|listas)/'
	);
}

/** Whether a post belongs to a Lista editorial surface. */
function go_verge_post_is_list( $post_id = null ) {
	if ( go_verge_post_is_ranking( $post_id ) ) {
		return false;
	}

	return go_verge_post_has_editorial_format(
		$post_id,
		array( 'lista', 'listas' ),
		'/(?:^|-)(?:lista|listas)(?:-|$)/',
		'/(?:lista|listas).*?(?:ranking|rankings)|(?:ranking|rankings).*?(?:lista|listas)/'
	);
}

/** Whether a post belongs exclusively to the Especiais editorial surface. */
function go_verge_post_is_special( $post_id = null ) {
	/*
	 * Some installations keep Guia, Lista and Ranking below a broad editorial
	 * category. A post with one of those explicit formats is not an Especial,
	 * even when an ancestor term happens to contain "especiais".
	 */
	if ( go_verge_post_is_guide( $post_id ) || go_verge_post_is_ranking( $post_id ) || go_verge_post_is_list( $post_id ) ) {
		return false;
	}

	return go_verge_post_has_editorial_format(
		$post_id,
		array( 'especiais', 'especial', 'reportagens', 'materias-especiais' ),
		'/(?:^|-)(?:especial|especiais|reportagem|reportagens)(?:-|$)/'
	);
}

/** Whether a non-critique post belongs to the Entretenimento vertical. */
function go_verge_post_is_entertainment( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return false;
	}
	if ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) ) {
		return false;
	}

	$terms = get_the_category( $post_id );
	foreach ( (array) $terms as $term ) {
		if ( function_exists( 'go_verge_offcanvas_category_bucket' ) && 'entertainment' === go_verge_offcanvas_category_bucket( $term ) ) {
			return true;
		}
	}

	return go_verge_post_has_editorial_format(
		$post_id,
		array( 'entretenimento', 'noticias-de-entretenimento', 'noticias-entretenimento', 'cinema-e-tv', 'cinema', 'filmes', 'series', 'streaming', 'animes', 'cultura-pop', 'mangas-e-quadrinhos', 'manga-e-quadrinhos', 'mangas', 'manga', 'quadrinhos', 'hqs', 'comics' ),
		'/(?:^|-)(?:entretenimento|noticias-entretenimento|cinema|filme|filmes|serie|series|streaming|anime|animes|cultura-pop|manga|mangas|quadrinho|quadrinhos|hqs|comics)(?:-|$)/'
	);
}

/**
 * Resolve the mutually exclusive editorial context used by related modules.
 * The most specific formats win over broad parent categories.
 */
function go_verge_post_editorial_context( $post_id = null ) {
	if ( go_verge_post_is_ranking( $post_id ) ) {
		return 'ranking';
	}
	if ( go_verge_post_is_list( $post_id ) ) {
		return 'list';
	}
	if ( go_verge_post_is_guide( $post_id ) ) {
		return 'guide';
	}
	if ( go_verge_post_is_special( $post_id ) ) {
		return 'special';
	}
	return '';
}

/** Whether a candidate belongs to the requested editorial context. */
function go_verge_post_matches_editorial_context( $post_id, $context ) {
	switch ( (string) $context ) {
		case 'ranking':
			return go_verge_post_is_ranking( $post_id );
		case 'list':
			return go_verge_post_is_list( $post_id );
		case 'guide':
			return go_verge_post_is_guide( $post_id );
		case 'special':
			return go_verge_post_is_special( $post_id );
		case 'entertainment':
			return go_verge_post_is_entertainment( $post_id );
		default:
			return true;
	}
}

/**
 * Give numbered H2s in ranking articles semantic hooks for a restrained
 * editorial layout. Only headings that already begin with a number are
 * changed; wording, order and heading IDs remain untouched.
 *
 * @param string $content Filtered post content.
 * @return string
 */
function go_verge_enhance_ranking_headings( $content ) {
	if ( ! is_string( $content ) || '' === trim( $content ) || false !== strpos( $content, 'go-ranking-heading__number' ) ) {
		return $content;
	}

	return preg_replace_callback(
		'#<h2\b([^>]*)>\s*(\d{1,3})\s*[\.\)\-–—:]\s*(.*?)</h2>#isu',
		static function ( $matches ) {
			$attributes = $matches[1];
			if ( preg_match( '/\bclass\s*=\s*(["\'])(.*?)\1/isu', $attributes, $class_match ) ) {
				$replacement = 'class=' . $class_match[1] . trim( $class_match[2] . ' go-ranking-heading' ) . $class_match[1];
				$attributes  = preg_replace( '/\bclass\s*=\s*(["\'])(.*?)\1/isu', $replacement, $attributes, 1 );
			} else {
				$attributes .= ' class="go-ranking-heading"';
			}

			return '<h2' . $attributes . '><span class="go-ranking-heading__number">' . esc_html( $matches[2] ) . '.</span><span class="go-ranking-heading__text">' . trim( $matches[3] ) . '</span></h2>';
		},
		$content
	);
}

/**
 * Small media pill used to signal reviews and critiques when they surface
 * outside their dedicated archive.
 */
function go_verge_review_media_label( $post_id = null, $context = 'card' ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return '';
	}

	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$is_review   = function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id );
	$context_key = sanitize_key( (string) $context );
	$is_hero     = 'homepage-hero' === $context_key;
	$is_latest   = 'latest' === $context_key;

	// In chronological "Últimas publicações" feeds, identify the format with a
	// deliberately quiet text cue. It replaces the score badge only in this
	// context, avoiding redundant labels in dedicated Reviews/Críticas surfaces.
	if ( $is_latest && ( $is_review || $is_critique ) ) {
		$format_label = $is_critique ? __( 'Crítica', 'go-verge' ) : __( 'Review', 'go-verge' );
		$format_class = $is_critique ? 'go-media-label--latest-critique' : 'go-media-label--latest-review';
		return sprintf(
			'<span class="go-media-label go-media-label--latest %1$s">%2$s</span>',
			esc_attr( $format_class ),
			esc_html( $format_label )
		);
	}

	// A scored review or critique surfaces its score as a flat, tier-colored badge
	// right on the card. The number is the format signal, so it replaces the
	// redundant text pill and gives the reader real editorial information — a solid
	// colour block, not a glassy pill.
	$score = function_exists( 'go_verge_review_score' ) ? go_verge_review_score( $post_id ) : null;
	if ( null !== $score ) {
		$is_scored_format = $is_critique || $is_review;
		if ( $is_scored_format ) {
			$tier  = function_exists( 'go_verge_review_score_tier' )
				? go_verge_review_score_tier( $score )
				: ( $score >= 8 ? 'is-high' : ( $score >= 5 ? 'is-mid' : 'is-low' ) );
			$label = function_exists( 'go_verge_review_score_display' )
				? go_verge_review_score_display( $score )
				: rtrim( rtrim( number_format( (float) $score, 1, '.', '' ), '0' ), '.' );
			if ( $is_hero && ( $is_review || $is_critique ) ) {
				$format_label = $is_critique ? __( 'Crítica', 'go-verge' ) : __( 'Review', 'go-verge' );
				$format_class = $is_critique ? 'go-media-label--hero-critique' : 'go-media-label--hero-game-review';
				return sprintf(
					'<span class="go-media-label go-media-label--hero-review %1$s %2$s" aria-label="%6$s"><span class="go-media-label__format">%3$s</span><span class="go-media-label__rating"><span class="go-media-label__num">%4$s</span><span class="go-media-label__scale">%5$s</span></span></span>',
					esc_attr( $tier ),
					esc_attr( $format_class ),
					esc_html( $format_label ),
					esc_html( $label ),
					esc_html__( '/10', 'go-verge' ),
					esc_attr( sprintf( __( '%1$s, nota %2$s de 10', 'go-verge' ), $format_label, $label ) )
				);
			}

			return sprintf(
				'<span class="go-media-label go-media-label--score %1$s" aria-label="%3$s"><span class="go-media-label__num">%2$s</span><span class="go-media-label__scale">/10</span></span>',
				esc_attr( $tier ),
				esc_html( $label ),
				esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $label ) )
			);
		}
	}

	// On its own archive the format is already explicit in the page title, so a
	// repeated "Crítica"/"Review" text pill on every card is pure redundancy.
	// The score badge above still shows — only the text label is suppressed.
	// Uses the shared format context, which the AJAX handler also feeds so the
	// suppression survives "carregar mais" (where is_category() is false).
	$archive_format = function_exists( 'go_verge_archive_format_context' ) ? go_verge_archive_format_context() : 'default';

	// Hero cards keep the format cue even before an editor assigns a score.
	if ( $is_hero && ( $is_review || $is_critique ) ) {
		$format_label = $is_critique ? __( 'Crítica', 'go-verge' ) : __( 'Review', 'go-verge' );
		$format_class = $is_critique ? 'go-media-label--hero-critique' : 'go-media-label--hero-game-review';
		return sprintf(
			'<span class="go-media-label go-media-label--hero-review is-unscored %1$s"><span class="go-media-label__format">%2$s</span></span>',
			esc_attr( $format_class ),
			esc_html( $format_label )
		);
	}

	// A critique keeps its format cue everywhere except the Críticas archive.
	if ( $is_critique ) {
		return ( 'critiques' === $archive_format ) ? '' : '<span class="go-media-label go-media-label--critique">' . esc_html__( 'Crítica', 'go-verge' ) . '</span>';
	}

	// A "Review" pill is redundant on the Reviews archive itself.
	if ( 'reviews' === $archive_format ) {
		return '';
	}

	if ( function_exists( 'go_verge_review_data' ) ) {
		$data = go_verge_review_data( $post_id );
		if ( ! empty( $data['has_review'] ) ) {
			return '<span class="go-media-label go-media-label--review">' . esc_html__( 'Review', 'go-verge' ) . '</span>';
		}
	}

	return '';
}

/**
 * Shared inner body of a story tile (kicker + headline + deck + meta).
 */
function go_verge_tile_body( $args ) {
	$post_id      = $args['id'];
	$show_excerpt  = ! empty( $args['show_excerpt'] );
	$show_subtitle = ! empty( $args['show_subtitle'] );
	$show_meta     = ! array_key_exists( 'show_meta', $args ) || ! empty( $args['show_meta'] );
	$pretitle      = isset( $args['pretitle'] ) ? trim( (string) $args['pretitle'] ) : '';
	$accent        = ! empty( $args['accent'] ) && 'none' !== $args['accent'];
	$title_tag     = ! empty( $args['title_tag'] ) ? $args['title_tag'] : 'h3';

	$out  = '<div class="go-tile__body">';
	if ( '' !== $pretitle ) {
		$out .= '<div class="go-tile__pretitle">' . esc_html( $pretitle ) . '</div>';
	}
	$out .= sprintf(
		'<%1$s class="go-tile__title"><a href="%2$s">%3$s</a></%1$s>',
		$title_tag,
		esc_url( get_permalink( $post_id ) ),
		esc_html( get_the_title( $post_id ) )
	);

	if ( $show_subtitle || $show_excerpt ) {
		$deck = go_verge_support_text( $post_id );
		if ( $deck ) {
			$out .= '<p class="go-tile__deck">' . esc_html( wp_trim_words( $deck, 26, '…' ) ) . '</p>';
		}
	}

	if ( $show_meta ) {
		$out .= '<div class="go-tile__meta">';
		$out .= go_verge_time_html( $post_id );
		$byline = go_verge_byline( $post_id );
		if ( $byline ) {
			$out .= '<span class="go-dot" aria-hidden="true">·</span>' . $byline;
		}
		$out .= '</div>';
	}
	$out .= '</div>';

	return $out;
}

/**
 * Story tile (grid card). Args:
 *   id, size (feature|standard|compact), accent (mint|uv|yellow|pink|orange|white|none),
 *   show_excerpt (bool), show_image (bool), image_size (string), title_tag (string),
 *   media_context (card|homepage-hero).
 */
function go_verge_story_tile( $args = array() ) {
	$args = wp_parse_args( $args, array(
		'id'           => get_the_ID(),
		'size'         => 'standard',
		'accent'       => 'none',
		'show_excerpt'  => false,
		'show_subtitle' => false,
		'show_image'   => true,
		'show_score'   => true,
		'show_label'   => true,
		'show_meta'    => true,
		'pretitle'     => '',
		'image_size'    => 'go_card',
		'title_tag'     => 'h3',
		'loading'       => 'lazy',
		'fetchpriority' => '',
		'decoding'      => 'async',
		'sizes'         => '',
		'media_context' => 'card',
	) );

	$post_id = $args['id'];
	$classes = array( 'go-tile', 'go-tile--' . $args['size'] );
	if ( 'none' !== $args['accent'] ) {
		$classes[] = 'go-tile--accent';
		$classes[] = 'go-accent-' . $args['accent'];
	}
	if ( ! $args['show_image'] || ! has_post_thumbnail( $post_id ) ) {
		$classes[] = 'go-tile--noimage';
	}

	$out = sprintf( '<article class="%s" data-go-ad-integrity="atomic">', esc_attr( implode( ' ', $classes ) ) );

	if ( $args['show_image'] && has_post_thumbnail( $post_id ) ) {
		$out .= '<a class="go-tile__media go-frame" href="' . esc_url( get_permalink( $post_id ) ) . '" tabindex="-1" aria-hidden="true">';
		$image_attrs = array(
			'loading'  => sanitize_key( (string) $args['loading'] ),
			'decoding' => sanitize_key( (string) $args['decoding'] ),
			'alt'      => esc_attr( get_the_title( $post_id ) ),
		);
		if ( ! empty( $args['fetchpriority'] ) ) {
			$image_attrs['fetchpriority'] = sanitize_key( (string) $args['fetchpriority'] );
		} elseif ( 'lazy' === $image_attrs['loading'] ) {
			/* Listing/card imagery is below the critical path. Explicitly keep it
			 * behind the hero/LCP and early monetization network work. */
			$image_attrs['fetchpriority'] = 'low';
		}
		if ( ! empty( $args['sizes'] ) ) {
			$image_attrs['sizes'] = sanitize_text_field( (string) $args['sizes'] );
		}
		$out .= get_the_post_thumbnail( $post_id, $args['image_size'], $image_attrs );
		if ( ! empty( $args['show_label'] ) ) {
			$out .= go_verge_review_media_label( $post_id, $args['media_context'] );
		}
		if ( ! empty( $args['show_score'] ) ) {
			$out .= go_verge_score_badge( $post_id );
		}
		$out .= '</a>';
	}

	$out .= go_verge_tile_body( $args );
	$out .= '</article>';

	echo $out; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts.
}

/**
 * StoryStream timeline row: mono timestamp on the rail + tile body.
 */
function go_verge_stream_item( $args = array() ) {
	$args = wp_parse_args( $args, array(
		'id'           => get_the_ID(),
		'accent'       => 'none',
		'show_excerpt'  => true,
		'show_subtitle' => false,
		'show_image'   => true,
		'image_size'   => 'go_card',
		'title_tag'    => 'h3',
	) );

	$post_id = $args['id'];
	$classes = array( 'go-stream__item' );
	if ( 'none' !== $args['accent'] ) {
		$classes[] = 'go-stream__item--accent';
		$classes[] = 'go-accent-' . $args['accent'];
	}

	$out  = sprintf( '<li class="%s">', esc_attr( implode( ' ', $classes ) ) );
	$out .= '<div class="go-stream__rail">' . go_verge_time_html( $post_id ) . '</div>';
	$out .= '<article class="go-stream__card" data-go-ad-integrity="atomic">';

	if ( $args['show_image'] && has_post_thumbnail( $post_id ) ) {
		$out .= '<a class="go-stream__media go-frame" href="' . esc_url( get_permalink( $post_id ) ) . '" tabindex="-1" aria-hidden="true">';
		$out .= get_the_post_thumbnail( $post_id, $args['image_size'], array( 'loading' => 'lazy', 'alt' => esc_attr( get_the_title( $post_id ) ) ) );
		$out .= go_verge_review_media_label( $post_id );
		$out .= go_verge_score_badge( $post_id );
		$out .= '</a>';
	}

	$out .= go_verge_tile_body( $args );
	$out .= '</article></li>';

	echo $out; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts.
}

/**
 * Section heading. The first argument is kept for call-site compatibility
 * but no longer rendered — no eyebrow labels sitewide.
 */
function go_verge_section_head( $eyebrow, $title, $link = '', $link_label = '' ) {
	echo '<div class="go-section__head">';
	echo '<h2 class="go-section__title">' . esc_html( $title ) . '</h2>';
	if ( $link ) {
		printf(
			'<a class="go-btn go-btn--outline-mint" href="%1$s">%2$s</a>',
			esc_url( $link ),
			esc_html( go_verge_upper( $link_label ? $link_label : __( 'Ver tudo', 'go-verge' ) ) )
		);
	}
	echo '</div>';
}

/**
 * Cycle accent colors for color-block tiles.
 */
function go_verge_accent( $index ) {
	$palette = array( 'mint', 'uv', 'yellow', 'pink', 'orange' );
	return $palette[ $index % count( $palette ) ];
}

/**
 * Run a WP_Query excluding IDs already surfaced elsewhere on the page, and
 * append its results to that same exclusion list (by reference) so the next
 * section in a homepage-style layout doesn't repeat a story.
 */
function go_verge_home_query( $args, array &$shown ) {
	$defaults = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'post__not_in'        => $shown,
	);
	$query = new WP_Query( wp_parse_args( $args, $defaults ) );
	foreach ( $query->posts as $queried_post ) {
		$shown[] = $queried_post->ID;
	}
	return $query;
}

/**
 * Mono-uppercase breadcrumb trail.
 *
 * By default it renders Home / Parent / Current. On singles, callers can hide
 * the current post title for a quieter, less invasive trail.
 */
function go_verge_breadcrumbs( $args = array() ) {
	$args = wp_parse_args(
		$args,
		array(
			'include_current' => true,
			'compact_single'  => false,
			'preserve_case'   => false,
		)
	);

	$trail = array( array( 'label' => __( 'Home', 'go-verge' ), 'url' => home_url( '/' ) ) );

	if ( is_category() || is_tag() || is_tax() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			/* V7 taxonomies are intentionally flat in storage; the breadcrumb
			 * expresses the editorial path a reader expects instead. */
			if ( 'go_platform' === $term->taxonomy && function_exists( 'go_verge_v7_category_url' ) ) {
				$trail[] = array( 'label'=>'Games', 'url'=>go_verge_v7_category_url('games') );
			} elseif ( 'go_service' === $term->taxonomy && function_exists( 'go_verge_v7_category_url' ) ) {
				$entertainment_services = array( 'netflix','prime-video','disney-plus','max','apple-tv-plus','crunchyroll','globoplay' );
				if ( in_array( $term->slug, $entertainment_services, true ) ) {
					$trail[] = array( 'label'=>'Entretenimento', 'url'=>go_verge_v7_category_url('entretenimento') );
					$trail[] = array( 'label'=>'Streaming', 'url'=>go_verge_v7_category_url('streaming') );
				} else {
					$trail[] = array( 'label'=>'Games', 'url'=>go_verge_v7_category_url('games') );
				}
			} else {
				$ancestors = array_reverse( get_ancestors( $term->term_id, $term->taxonomy ) );
				foreach ( $ancestors as $ancestor_id ) {
					$ancestor = get_term( $ancestor_id, $term->taxonomy );
					if ( $ancestor && ! is_wp_error( $ancestor ) ) { $trail[] = array( 'label'=>$ancestor->name, 'url'=>get_term_link($ancestor) ); }
				}
			}
			$trail[] = array( 'label' => $term->name, 'url' => '' );
		}
	} elseif ( is_singular( 'productions' ) ) {
		if ( function_exists( 'go_verge_v7_category_url' ) ) { $trail[] = array( 'label'=>'Entretenimento', 'url'=>go_verge_v7_category_url('entretenimento') ); }
		$archive = get_post_type_archive_link( 'productions' );
		$trail[] = array( 'label'=>'Produções', 'url'=>$archive ?: home_url('/producoes/') );
		if ( ! empty( $args['include_current'] ) ) { $trail[] = array( 'label'=>get_the_title(), 'url'=>'' ); }
	} elseif ( is_singular() ) {
		$primary = go_verge_get_primary_term( get_the_ID() );
		if ( $primary ) {
			$ancestor_ids = array_reverse( get_ancestors( $primary->term_id, $primary->taxonomy ) );
			$chain        = array();

			foreach ( $ancestor_ids as $ancestor_id ) {
				$ancestor = get_term( $ancestor_id, $primary->taxonomy );
				if ( $ancestor instanceof WP_Term && ! is_wp_error( $ancestor ) ) {
					$chain[] = $ancestor;
				}
			}
			$chain[] = $primary;

			if ( ! empty( $args['compact_single'] ) ) {
				$pillar_slugs = function_exists( 'go_verge_pillar_slugs' ) ? go_verge_pillar_slugs() : array( 'games', 'entretenimento', 'tecnologia', 'noticias' );
				$pillar       = null;

				foreach ( $chain as $candidate ) {
					if ( in_array( $candidate->slug, $pillar_slugs, true ) ) {
						$pillar = $candidate;
						break;
					}
				}

				if ( ! $pillar && ! empty( $chain ) ) {
					$pillar = reset( $chain );
				}

				if ( $pillar instanceof WP_Term ) {
					$pillar_link = get_term_link( $pillar );
					$trail[] = array(
						'label' => $pillar->name,
						'url'   => is_wp_error( $pillar_link ) ? '' : $pillar_link,
					);
				}

				if ( $primary instanceof WP_Term && ( ! $pillar || (int) $primary->term_id !== (int) $pillar->term_id ) ) {
					$primary_link = get_term_link( $primary );
					$trail[] = array(
						'label' => $primary->name,
						'url'   => is_wp_error( $primary_link ) ? '' : $primary_link,
					);
				}
			} else {
				foreach ( $chain as $term_item ) {
					$link = get_term_link( $term_item );
					$trail[] = array(
						'label' => $term_item->name,
						'url'   => is_wp_error( $link ) ? '' : $link,
					);
				}
			}
		}

		if ( ! empty( $args['include_current'] ) ) {
			$trail[] = array( 'label' => get_the_title(), 'url' => '' );
		}
	} elseif ( is_post_type_archive() ) {
		$trail[] = array( 'label' => post_type_archive_title( '', false ), 'url' => '' );
	}

	$trail = array_values( array_filter( $trail, function( $item ) {
		return ! empty( $item['label'] );
	} ) );

	if ( count( $trail ) < 2 ) {
		return;
	}

	echo '<nav class="go-breadcrumbs" aria-label="' . esc_attr__( 'Breadcrumb', 'go-verge' ) . '">';
	$last = count( $trail ) - 1;
	foreach ( $trail as $i => $crumb ) {
		if ( $i > 0 ) {
			echo '<span class="sep" aria-hidden="true">›</span>';
		}
		$label = ( is_singular( 'games' ) && $i === $last )
			? go_verge_prepare_game_name( $crumb['label'] )
			: ( ! empty( $args['preserve_case'] ) ? $crumb['label'] : go_verge_upper( $crumb['label'] ) );
		if ( '' !== $crumb['url'] && ( $i !== $last || empty( $args['include_current'] ) ) ) {
			printf( '<a href="%s">%s</a>', esc_url( $crumb['url'] ), esc_html( $label ) );
		} else {
			echo '<span>' . esc_html( $label ) . '</span>';
		}
	}
	echo '</nav>';
}

/**
 * Decide whether artificial intelligence is genuinely one of the post's
 * subjects. A stray mention inside the body must not be enough to classify a
 * story as being about AI.
 */
function go_verge_post_is_about_ai( $post_id ) {
	$post_id = absint( $post_id );
	$post    = get_post( $post_id );
	if ( ! $post instanceof WP_Post ) {
		return false;
	}

	$pattern = '/(?:\b(?:ia|ai)\b|intelig[eê]ncia\s+artificial|artificial\s+intelligence|machine\s+learning|aprendizado\s+de\s+m[aá]quina|chatgpt|openai|gemini|copilot|midjourney)/iu';
	$score   = 0;

	$title = wp_strip_all_tags( (string) $post->post_title );
	if ( preg_match( $pattern, $title ) ) {
		$score += 6;
	}

	$subtitle = '';
	foreach ( array( '_go_post_subtitle', 'go_post_subtitle', '_subtitle' ) as $meta_key ) {
		$value = trim( wp_strip_all_tags( (string) get_post_meta( $post_id, $meta_key, true ) ) );
		if ( '' !== $value ) {
			$subtitle = $value;
			break;
		}
	}
	if ( $subtitle && preg_match( $pattern, $subtitle ) ) {
		$score += 3;
	}

	$focus = '';
	foreach ( array( 'rank_math_focus_keyword', '_rank_math_focus_keyword', '_yoast_wpseo_focuskw' ) as $meta_key ) {
		$value = trim( wp_strip_all_tags( (string) get_post_meta( $post_id, $meta_key, true ) ) );
		if ( '' !== $value ) {
			$focus = $value;
			break;
		}
	}
	if ( $focus && preg_match( $pattern, $focus ) ) {
		$score += 7;
	}

	$categories = wp_get_post_terms( $post_id, 'category' );
	if ( ! is_wp_error( $categories ) ) {
		foreach ( $categories as $category ) {
			$category_text = $category->name . ' ' . $category->slug;
			if ( preg_match( $pattern, $category_text ) ) {
				$score += 6;
				break;
			}
		}
	}

	$excerpt = wp_strip_all_tags( (string) $post->post_excerpt );
	if ( $excerpt && preg_match( $pattern, $excerpt ) ) {
		$score += 2;
	}

	$body = wp_strip_all_tags( strip_shortcodes( (string) $post->post_content ) );
	if ( $body && preg_match_all( $pattern, $body, $matches ) ) {
		$count = count( $matches[0] );
		if ( $count >= 5 ) {
			$score += 4;
		} elseif ( $count >= 2 ) {
			$score += 2;
		} else {
			$score += 1;
		}
	}

	return $score >= 4;
}

/**
 * Identify AI-related tag names. These terms are hidden and detached from
 * unrelated stories so media-helper metadata never leaks into taxonomy.
 */
function go_verge_is_ai_tag( $tag ) {
	$name = $tag instanceof WP_Term ? $tag->name : (string) $tag;
	$slug = $tag instanceof WP_Term ? $tag->slug : sanitize_title( $name );
	$text = remove_accents( strtolower( trim( $name . ' ' . $slug ) ) );
	return (bool) preg_match( '/(?:^|[\s-])(?:ia|ai)(?:$|[\s-])|inteligencia artificial|artificial intelligence|chatgpt|openai|gemini|copilot|midjourney/i', $text );
}

/**
 * Remove AI taxonomy leakage from posts whose editorial subject is not AI.
 */
function go_verge_cleanup_unrelated_ai_tags( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( go_verge_post_is_about_ai( $post_id ) ) {
		return;
	}
	$tags = wp_get_post_terms( $post_id, 'post_tag' );
	if ( empty( $tags ) || is_wp_error( $tags ) ) {
		return;
	}
	foreach ( $tags as $tag ) {
		if ( go_verge_is_ai_tag( $tag ) ) {
			wp_remove_object_terms( $post_id, (int) $tag->term_id, 'post_tag' );
		}
	}
}
add_action( 'save_post_post', 'go_verge_cleanup_unrelated_ai_tags', 100 );

/**
 * One-time cleanup for posts that already received an unrelated AI tag.
 */
function go_verge_cleanup_existing_ai_tag_leakage() {
	if ( get_option( 'go_verge_ai_tag_cleanup_v3' ) ) {
		return;
	}
	$terms = get_terms( array( 'taxonomy' => 'post_tag', 'hide_empty' => false ) );
	if ( is_wp_error( $terms ) ) {
		return;
	}
	foreach ( $terms as $term ) {
		if ( ! go_verge_is_ai_tag( $term ) ) {
			continue;
		}
		$post_ids = get_objects_in_term( (int) $term->term_id, 'post_tag' );
		if ( is_wp_error( $post_ids ) ) {
			continue;
		}
		foreach ( array_map( 'absint', (array) $post_ids ) as $post_id ) {
			go_verge_cleanup_unrelated_ai_tags( $post_id );
		}
	}
	update_option( 'go_verge_ai_tag_cleanup_v3', current_time( 'mysql' ), false );
}
add_action( 'admin_init', 'go_verge_cleanup_existing_ai_tag_leakage', 30 );

/**
 * Tags shown below singles: prioritise the tags with the most associated posts
 * and keep the list concise.
 */
function go_verge_priority_tags( $post_id = null, $limit = 10, $min_count = 2 ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$tags    = get_the_terms( $post_id, 'post_tag' );

	if ( empty( $tags ) || is_wp_error( $tags ) ) {
		return array();
	}

	$limit     = max( 1, (int) $limit );
	$min_count = max( 1, (int) $min_count );
	$is_ai_subject = go_verge_post_is_about_ai( $post_id );
	$tags      = array_filter( $tags, function( $tag ) use ( $min_count, $is_ai_subject ) {
		if ( ! $tag instanceof WP_Term ) {
			return false;
		}
		/* A tag selected by the editor belongs to this article even when its
		 * sitewide usage count is still one. Popularity must not hide taxonomy. */
		if ( (int) $tag->count < $min_count ) {
			return false;
		}
		return $is_ai_subject || ! go_verge_is_ai_tag( $tag );
	} );

	if ( empty( $tags ) ) {
		return array();
	}

	usort( $tags, function( $a, $b ) {
		$count_compare = (int) $b->count <=> (int) $a->count;
		if ( 0 !== $count_compare ) {
			return $count_compare;
		}
		return strcasecmp( $a->name, $b->name );
	} );

	return array_slice( $tags, 0, $limit );
}

/**
 * Top-level editorial pillars (categories with no parent that actually hold
 * the site's sections, per the real content model).
 */
function go_verge_pillar_slugs() {
	return array( 'games', 'entretenimento', 'tecnologia', 'noticias' );
}

/**
 * Resolve the first real category that matches a list of aliases.
 */
function go_verge_category_by_aliases( $aliases ) {
	foreach ( (array) $aliases as $slug ) {
		$term = get_term_by( 'slug', sanitize_title( (string) $slug ), 'category' );
		if ( $term instanceof WP_Term ) {
			return $term;
		}
	}
	return null;
}

/**
 * Real editorial category destinations used by the drawer and article rail.
 * Pages are deliberately not used here: every link resolves through
 * get_term_link(), so the navigation cannot point at empty placeholder pages.
 */
function go_verge_editorial_category_terms() {
	$groups = array(
		array( 'noticias', 'news' ),
		array( 'games', 'jogos' ),
		array( 'reviews', 'review', 'analises' ),
		array( 'dicas-e-guias', 'guias', 'tutoriais' ),
		array( 'entretenimento' ),
		array( 'tecnologia', 'tech' ),
		array( 'criticas', 'critica' ),
		array( 'promocoes', 'promocao' ),
		array( 'listas', 'rankings', 'lista', 'ranking' ),
		array( 'especiais', 'especial', 'reportagens' ),
	);

	$terms = array();
	$seen  = array();
	foreach ( $groups as $aliases ) {
		$term = go_verge_category_by_aliases( $aliases );
		if ( $term instanceof WP_Term && ! isset( $seen[ $term->term_id ] ) ) {
			$terms[] = $term;
			$seen[ $term->term_id ] = true;
		}
	}

	// A fresh install may use different slugs. Fall back to real top-level terms.
	if ( empty( $terms ) ) {
		$fallback = get_categories(
			array(
				'parent'     => 0,
				'hide_empty' => false,
				'number'     => 10,
				'orderby'    => 'count',
				'order'      => 'DESC',
			)
		);
		if ( ! is_wp_error( $fallback ) ) {
			$terms = $fallback;
		}
	}

	return $terms;
}

/**
 * Smart off-canvas navigation. Group labels are real links and the adjacent
 * chevron only controls expansion, so destinations are never duplicated.
 */
function go_verge_offcanvas_category_counts( $minimum = 10 ) {
	global $wpdb;

	$minimum  = max( 0, absint( $minimum ) );
	$cache_key = 'go_offcanvas_categories_gt_' . $minimum;
	$cached    = get_transient( $cache_key );
	if ( is_array( $cached ) ) {
		return $cached;
	}

	$sql = $wpdb->prepare(
		"SELECT tt.term_id, COUNT(DISTINCT p.ID) AS published_count
		FROM {$wpdb->term_taxonomy} tt
		INNER JOIN {$wpdb->term_relationships} tr ON tr.term_taxonomy_id = tt.term_taxonomy_id
		INNER JOIN {$wpdb->posts} p ON p.ID = tr.object_id
		WHERE tt.taxonomy = 'category'
		AND p.post_type = 'post'
		AND p.post_status = 'publish'
		GROUP BY tt.term_id
		HAVING COUNT(DISTINCT p.ID) > %d",
		$minimum
	);
	$rows = $wpdb->get_results( $sql ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	$counts = array();
	foreach ( (array) $rows as $row ) {
		$counts[ absint( $row->term_id ) ] = absint( $row->published_count );
	}
	set_transient( $cache_key, $counts, 6 * HOUR_IN_SECONDS );
	return $counts;
}

/** Clear the dynamic off-canvas category cache when editorial taxonomy changes. */
function go_verge_clear_offcanvas_category_cache() {
	global $wpdb;
	$patterns = array(
		$wpdb->esc_like( '_transient_go_offcanvas_categories_gt_' ) . '%',
		$wpdb->esc_like( '_transient_timeout_go_offcanvas_categories_gt_' ) . '%',
		$wpdb->esc_like( '_transient_go_offcanvas_recent_' ) . '%',
		$wpdb->esc_like( '_transient_timeout_go_offcanvas_recent_' ) . '%',
	);
	$wpdb->query(
		$wpdb->prepare(
			"DELETE FROM {$wpdb->options} WHERE option_name LIKE %s OR option_name LIKE %s OR option_name LIKE %s OR option_name LIKE %s",
			...$patterns
		)
	); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery
}
add_action( 'save_post_post', 'go_verge_clear_offcanvas_category_cache' );
add_action( 'created_category', 'go_verge_clear_offcanvas_category_cache' );
add_action( 'edited_category', 'go_verge_clear_offcanvas_category_cache' );
add_action( 'delete_category', 'go_verge_clear_offcanvas_category_cache' );

/** Resolve the editorial bucket for a category shown in the smart drawer. */
function go_verge_offcanvas_category_bucket( WP_Term $term ) {
	$roots = array(
		'games' => array( 'games', 'jogos' ),
		'entertainment' => array( 'entretenimento' ),
		'technology' => array( 'tecnologia', 'tech' ),
	);
	$ancestors = array_map( 'absint', get_ancestors( $term->term_id, 'category', 'taxonomy' ) );
	$lineage   = array_merge( array( absint( $term->term_id ) ), $ancestors );
	foreach ( $roots as $bucket => $aliases ) {
		foreach ( $aliases as $slug ) {
			$root = get_term_by( 'slug', $slug, 'category' );
			if ( $root instanceof WP_Term && in_array( absint( $root->term_id ), $lineage, true ) ) {
				return $bucket;
			}
		}
	}

	$needle = strtolower( remove_accents( $term->slug . ' ' . $term->name ) );
	$games_words = array( 'playstation', 'ps4', 'ps5', 'xbox', 'nintendo', 'switch', 'steam', 'epic-games', 'gog', 'game-pass', 'pc-gamer', 'jogos', 'games', 'review', 'reviews', 'listas', 'rankings', 'especiais', 'guias' );
	$ent_words = array( 'entretenimento', 'streaming', 'cinema', 'filme', 'filmes', 'terror', 'horror', 'tv', 'serie', 'series', 'anime', 'animes', 'manga', 'mangas', 'quadrinhos', 'cultura-pop', 'dorama', 'doramas', 'cosplay', 'critica', 'criticas', 'netflix', 'disney', 'hbo', 'prime-video' );
	$tech_words = array( 'tecnologia', 'hardware', 'celular', 'celulares', 'smartphone', 'gadgets', 'software', 'inteligencia-artificial', 'inteligencia artificial', 'ia', 'tech' );
	$matches_word = static function ( $text, $word ) {
		/* Two-letter labels such as IA and TV must be whole tokens. A raw
		 * substring match classified "notícias" as Technology because it
		 * contains the letters "ia". */
		if ( strlen( $word ) <= 2 ) {
			return (bool) preg_match( '/(?:^|[^a-z0-9])' . preg_quote( $word, '/' ) . '(?:$|[^a-z0-9])/i', $text );
		}
		return false !== strpos( $text, $word );
	};
	foreach ( $games_words as $word ) {
		if ( $matches_word( $needle, $word ) ) {
			return 'games';
		}
	}
	foreach ( $ent_words as $word ) {
		if ( $matches_word( $needle, $word ) ) {
			return 'entertainment';
		}
	}
	foreach ( $tech_words as $word ) {
		if ( $matches_word( $needle, $word ) ) {
			return 'technology';
		}
	}
	return 'direct';
}

/**
 * Recent publishing activity for categories already eligible for the drawer.
 * This is only used to order links inside a group. It never hides a category
 * that passed the >10 published posts rule.
 */
function go_verge_offcanvas_recent_category_counts( $term_ids, $days = 45 ) {
	global $wpdb;

	$term_ids = array_values( array_filter( array_map( 'absint', (array) $term_ids ) ) );
	$days     = max( 7, absint( $days ) );
	if ( empty( $term_ids ) ) {
		return array();
	}

	$cache_key = 'go_offcanvas_recent_' . md5( implode( ',', $term_ids ) . '|' . $days );
	$cached    = get_transient( $cache_key );
	if ( is_array( $cached ) ) {
		return $cached;
	}

	$placeholders = implode( ',', array_fill( 0, count( $term_ids ), '%d' ) );
	$since        = gmdate( 'Y-m-d H:i:s', current_time( 'timestamp', true ) - ( $days * DAY_IN_SECONDS ) );
	$params       = array_merge( $term_ids, array( $since ) );
	$sql          = $wpdb->prepare(
		"SELECT tt.term_id, COUNT(DISTINCT p.ID) AS recent_count
		FROM {$wpdb->term_taxonomy} tt
		INNER JOIN {$wpdb->term_relationships} tr ON tr.term_taxonomy_id = tt.term_taxonomy_id
		INNER JOIN {$wpdb->posts} p ON p.ID = tr.object_id
		WHERE tt.taxonomy = 'category'
		AND tt.term_id IN ({$placeholders})
		AND p.post_type = 'post'
		AND p.post_status = 'publish'
		AND p.post_date_gmt >= %s
		GROUP BY tt.term_id",
		...$params
	); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared

	$rows   = $wpdb->get_results( $sql ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	$counts = array();
	foreach ( (array) $rows as $row ) {
		$counts[ absint( $row->term_id ) ] = absint( $row->recent_count );
	}
	set_transient( $cache_key, $counts, 6 * HOUR_IN_SECONDS );
	return $counts;
}

/** Resolve which editorial group best matches the current request. */
function go_verge_offcanvas_current_bucket() {
	if ( is_singular( 'games' ) ) {
		return 'games';
	}

	if ( is_category() ) {
		$term = get_queried_object();
		return $term instanceof WP_Term ? go_verge_offcanvas_category_bucket( $term ) : '';
	}

	if ( is_singular( 'post' ) ) {
		$terms = get_the_terms( get_queried_object_id(), 'category' );
		$votes = array( 'games' => 0, 'entertainment' => 0, 'technology' => 0 );
		if ( ! is_wp_error( $terms ) ) {
			foreach ( (array) $terms as $term ) {
				$bucket = go_verge_offcanvas_category_bucket( $term );
				if ( isset( $votes[ $bucket ] ) ) {
					$votes[ $bucket ]++;
				}
			}
		}
		arsort( $votes );
		$bucket = key( $votes );
		return $bucket && current( $votes ) > 0 ? $bucket : '';
	}

	if ( is_page() ) {
		$page = get_queried_object();
		$slug = $page instanceof WP_Post ? strtolower( (string) $page->post_name ) : '';
		if ( preg_match( '/games|jogos|reviews|plataformas|listas|ranking|especiais|guias/', $slug ) ) {
			return 'games';
		}
		if ( preg_match( '/entretenimento|streaming|cinema|anime|critica/', $slug ) ) {
			return 'entertainment';
		}
		if ( preg_match( '/tecnologia|tech|hardware|celular|inteligencia-artificial/', $slug ) ) {
			return 'technology';
		}
	}

	return '';
}

/**
 * Resolve the primary top-navigation section for the current request.
 *
 * Child topics (for example Game of Thrones inside Séries) inherit their
 * editorial vertical, so the header keeps Entretenimento marked while the
 * reader is inside that story.
 *
 * @return string latest|games|entertainment|technology|guides|promotions|''
 */
function go_verge_header_current_section() {
	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) {
		return 'news';
	}
	/* "Últimas" links to the hub Page, not to the front page. Marking it current
	 * on the home page would put aria-current on a link the reader is not on. */
	if ( go_verge_is_latest_hub() ) {
		return 'latest';
	}
	if ( is_front_page() ) {
		return '';
	}

	if ( is_singular( 'post' ) ) {
		$post_id = get_queried_object_id();
		if ( function_exists( 'go_verge_post_is_guide' ) && go_verge_post_is_guide( $post_id ) ) {
			return 'guides';
		}
		$slugs = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
		if ( ! is_wp_error( $slugs ) ) {
			foreach ( (array) $slugs as $slug ) {
				if ( preg_match( '/(?:^|-)(?:promocao|promocoes|oferta|ofertas)(?:-|$)/', sanitize_title( $slug ) ) ) {
					return 'promotions';
				}
			}
		}

		$bucket = function_exists( 'go_verge_offcanvas_current_bucket' ) ? go_verge_offcanvas_current_bucket() : '';
		if ( in_array( $bucket, array( 'games', 'entertainment', 'technology' ), true ) ) {
			return $bucket;
		}
	}

	if ( is_singular( 'games' ) || is_post_type_archive( 'games' ) ) {
		return 'games';
	}
	if ( is_post_type_archive( 'go_promotion' ) ) {
		return 'promotions';
	}
	if ( is_category() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$slug = sanitize_title( $term->slug );
			if ( preg_match( '/(?:^|-)(?:guia|guias|dica|dicas|tutorial|tutoriais)(?:-|$)/', $slug ) ) {
				return 'guides';
			}
			if ( preg_match( '/(?:^|-)(?:promocao|promocoes|oferta|ofertas)(?:-|$)/', $slug ) ) {
				return 'promotions';
			}
			$bucket = go_verge_offcanvas_category_bucket( $term );
			if ( in_array( $bucket, array( 'games', 'entertainment', 'technology' ), true ) ) {
				return $bucket;
			}
		}
	}
	if ( is_page() ) {
		$slug = sanitize_title( (string) get_post_field( 'post_name', get_queried_object_id() ) );
		if ( preg_match( '/dicas|guias|tutorial/', $slug ) ) { return 'guides'; }
		if ( preg_match( '/promoc/', $slug ) ) { return 'promotions'; }
		$bucket = function_exists( 'go_verge_offcanvas_current_bucket' ) ? go_verge_offcanvas_current_bucket() : '';
		if ( in_array( $bucket, array( 'games', 'entertainment', 'technology' ), true ) ) { return $bucket; }
	}

	return '';
}


/**
 * Resolve the public entry point for Overdrive Compara.
 *
 * The product database may be delivered by a plugin, so the theme does not
 * hard-code plugin internals. It first looks for a real WordPress Page and
 * falls back to the canonical /compara/ route expected by the product.
 *
 * @return string
 */
function go_verge_compara_url() {
	foreach ( array( 'compara', 'overdrive-compara', 'comparador' ) as $slug ) {
		$page = get_page_by_path( $slug );
		if ( $page instanceof WP_Post && 'publish' === get_post_status( $page ) ) {
			$url = get_permalink( $page );
			if ( $url ) {
				return (string) apply_filters( 'go_verge_compara_url', $url );
			}
		}
	}

	return (string) apply_filters( 'go_verge_compara_url', home_url( '/compara/' ) );
}

/**
 * Resolve the compact masthead context displayed beside the Overdrive logo.
 *
 * The visual contract intentionally mirrors the common publisher pattern
 * "brand | current section" without changing taxonomy, canonical URLs or
 * archive behavior. On posts we prefer the editorial primary category so a
 * reader coming from Search immediately sees the exact section they landed in.
 *
 * @return array{label:string,url:string}
 */
function go_verge_header_context_identity() {
	$identity = array(
		'label' => '',
		'url'   => '',
	);

	if ( is_front_page() ) {
		return $identity;
	}

	if ( is_singular( 'post' ) ) {
		$term = function_exists( 'go_verge_get_primary_term' )
			? go_verge_get_primary_term( get_queried_object_id(), 'category' )
			: null;
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) {
				$identity['label'] = $term->name;
				$identity['url']   = $url;
				return apply_filters( 'go_verge_header_context_identity', $identity );
			}
		}
	}

	if ( is_category() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) {
				$identity['label'] = $term->name;
				$identity['url']   = $url;
				return apply_filters( 'go_verge_header_context_identity', $identity );
			}
		}
	}

	if ( is_singular( 'games' ) || is_post_type_archive( 'games' ) ) {
		$identity = array( 'label' => 'Games', 'url' => home_url( '/games/' ) );
		return apply_filters( 'go_verge_header_context_identity', $identity );
	}

	if ( is_post_type_archive( 'go_promotion' ) ) {
		$identity = array(
			'label' => 'Ofertas',
			'url'   => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'promocoes' ) : home_url( '/ofertas/' ),
		);
		return apply_filters( 'go_verge_header_context_identity', $identity );
	}

	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) {
		$identity = array(
			'label' => 'Notícias',
			'url'   => function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url() : home_url( '/noticias/' ),
		);
		return apply_filters( 'go_verge_header_context_identity', $identity );
	}

	if ( function_exists( 'go_verge_is_latest_hub' ) && go_verge_is_latest_hub() ) {
		$identity = array(
			'label' => 'Últimas',
			'url'   => function_exists( 'go_verge_latest_url' ) ? go_verge_latest_url() : home_url( '/ultimas-publicacoes/' ),
		);
		return apply_filters( 'go_verge_header_context_identity', $identity );
	}

	$section = function_exists( 'go_verge_header_current_section' ) ? go_verge_header_current_section() : '';
	$map = array(
		'games'         => array( 'Games', home_url( '/games/' ) ),
		'entertainment' => array( 'Entretenimento', home_url( '/entretenimento/' ) ),
		'technology'    => array( 'Tecnologia', home_url( '/tecnologia/' ) ),
		'guides'        => array( 'Guias', function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'guias' ) : home_url( '/guias/' ) ),
		'promotions'    => array( 'Ofertas', function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'promocoes' ) : home_url( '/ofertas/' ) ),
		'news'          => array( 'Notícias', function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url() : home_url( '/noticias/' ) ),
		'latest'        => array( 'Últimas', function_exists( 'go_verge_latest_url' ) ? go_verge_latest_url() : home_url( '/ultimas-publicacoes/' ) ),
	);

	if ( isset( $map[ $section ] ) ) {
		$identity['label'] = $map[ $section ][0];
		$identity['url']   = $map[ $section ][1];
		return apply_filters( 'go_verge_header_context_identity', $identity );
	}

	/* Generic inner-page fallback: the compact masthead should always explain
	 * where the reader is, while the homepage intentionally remains brand-only. */
	if ( is_page() ) {
		$post_id = get_queried_object_id();
		$title   = $post_id ? get_the_title( $post_id ) : '';
		$url     = $post_id ? get_permalink( $post_id ) : '';
		if ( $title && $url ) {
			$identity = array( 'label' => $title, 'url' => $url );
			return apply_filters( 'go_verge_header_context_identity', $identity );
		}
	}

	if ( is_tag() || is_tax() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) {
				$identity = array( 'label' => $term->name, 'url' => $url );
				return apply_filters( 'go_verge_header_context_identity', $identity );
			}
		}
	}

	if ( is_author() ) {
		$author = get_queried_object();
		if ( $author instanceof WP_User ) {
			$identity = array(
				'label' => $author->display_name,
				'url'   => get_author_posts_url( $author->ID ),
			);
			return apply_filters( 'go_verge_header_context_identity', $identity );
		}
	}

	if ( is_search() ) {
		$identity = array( 'label' => 'Busca', 'url' => home_url( '/?s=' . rawurlencode( get_search_query() ) ) );
		return apply_filters( 'go_verge_header_context_identity', $identity );
	}

	if ( is_post_type_archive() ) {
		$post_type = get_query_var( 'post_type' );
		$post_type = is_array( $post_type ) ? reset( $post_type ) : $post_type;
		$object    = $post_type ? get_post_type_object( $post_type ) : null;
		if ( $object && ! empty( $object->labels->name ) ) {
			$url = get_post_type_archive_link( $post_type );
			if ( $url ) {
				$identity = array( 'label' => $object->labels->name, 'url' => $url );
				return apply_filters( 'go_verge_header_context_identity', $identity );
			}
		}
	}

	if ( is_singular() ) {
		$post_type = get_post_type( get_queried_object_id() );
		$object    = $post_type ? get_post_type_object( $post_type ) : null;
		if ( $object && 'post' !== $post_type && ! empty( $object->labels->singular_name ) ) {
			$url = ! empty( $object->has_archive ) ? get_post_type_archive_link( $post_type ) : home_url( '/' );
			$identity = array( 'label' => $object->labels->singular_name, 'url' => $url ?: home_url( '/' ) );
		}
	}

	return apply_filters( 'go_verge_header_context_identity', $identity );
}


/**
 * Curated off-canvas navigation.
 *
 * Rules:
 * - stable editorial pillars keep a predictable order;
 * - each pillar exposes only a few high-intent destinations;
 * - the current editorial group opens automatically without reordering the menu;
 * - utility destinations stay direct and URLs are never duplicated.
 */
function go_verge_offcanvas_category_menu() {
	if ( function_exists( 'go_verge_v7_render_offcanvas_nav' ) ) {
		go_verge_v7_render_offcanvas_nav();
		return;
	}

	$games_url = get_post_type_archive_link( 'games' );
	if ( ! $games_url ) {
		$games_url = home_url( '/games/' );
	}

	$resolve = static function ( $category_slugs = array(), $page_slugs = array(), $fallback = '' ) {
		foreach ( (array) $category_slugs as $slug ) {
			$term = get_term_by( 'slug', $slug, 'category' );
			if ( $term instanceof WP_Term ) {
				$url = get_term_link( $term );
				if ( ! is_wp_error( $url ) ) {
					return $url;
				}
			}
		}
		foreach ( (array) $page_slugs as $slug ) {
			$page = get_page_by_path( $slug );
			if ( $page instanceof WP_Post ) {
				return get_permalink( $page );
			}
		}
		return $fallback ? $fallback : '';
	};

	$latest_url     = go_verge_latest_url();
	$promotions_url = get_post_type_archive_link( 'go_promotion' );
	if ( ! $promotions_url ) {
		$promotions_url = $resolve( array( 'promocoes', 'promocao' ), array( 'promocoes' ), ( function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'promocoes' ) : home_url( '/ofertas/' ) ) );
	}
	$guides_url    = $resolve( array( 'dicas-e-guias', 'guias' ), array( 'dicas-e-guias', 'guias' ), ( function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'guias' ) : home_url( '/guias/' ) ) );
	$videos_url    = $resolve( array( 'videos', 'video' ), array( 'videos' ), home_url( '/videos/' ) );
	$platforms_url = $resolve( array(), array( 'plataformas' ), get_post_type_archive_link( 'go_entity' ) ?: home_url( '/plataformas/' ) );
	$specials_url  = $resolve( array( 'especiais', 'especial', 'reportagens' ), array( 'especiais' ), home_url( '/especiais/' ) );
	$launches_url  = $resolve( array(), array( 'lancamentos' ), home_url( '/lancamentos/' ) );
	$games_hub_url = home_url( '/games/' );
	$ent_url       = $resolve( array( 'entretenimento' ), array( 'entretenimento' ), home_url( '/entretenimento/' ) );
	$tech_url      = $resolve( array( 'tecnologia', 'tech' ), array( 'tecnologia' ), home_url( '/tecnologia/' ) );

	/*
	 * Curated architecture inspired by large editorial portals: stable pillars,
	 * few high-intent destinations and a tiny data-driven trending layer.
	 * The drawer must help readers decide, not mirror the entire taxonomy.
	 */
	$groups = array(
		'games' => array(
			'label' => 'Games',
			'url'   => $games_hub_url,
			'items' => array(
				array( 'label' => 'Notícias', 'url' => $resolve( array( 'noticias' ), array( 'noticias' ) ) ),
				array( 'label' => 'Reviews', 'url' => $resolve( array( 'reviews', 'review' ), array( 'reviews' ), home_url( '/reviews/' ) ) ),
				array( 'label' => 'Plataformas', 'url' => $platforms_url ),
				array( 'label' => 'Lançamentos', 'url' => $launches_url ),
				array( 'label' => 'Especiais', 'url' => $specials_url ),
			),
		),
		'entertainment' => array(
			'label' => 'Entretenimento',
			'url'   => $ent_url,
			'items' => array(
				array( 'label' => 'Séries', 'url' => $resolve( array( 'series', 'serie' ), array( 'series' ), home_url( '/series/' ) ) ),
				array( 'label' => 'Filmes', 'url' => $resolve( array( 'filmes', 'filme' ), array( 'filmes' ), home_url( '/filmes/' ) ) ),
				array( 'label' => 'Animes', 'url' => $resolve( array( 'animes', 'anime' ), array( 'animes' ) ) ),
				array( 'label' => 'Críticas', 'url' => $resolve( array( 'criticas', 'critica' ), array( 'criticas' ), home_url( '/criticas/' ) ) ),
			),
		),
		'technology' => array(
			'label' => 'Tecnologia',
			'url'   => $tech_url,
			'items' => array(
				array( 'label' => 'Hardware', 'url' => $resolve( array( 'hardware' ), array( 'hardware' ) ) ),
				array( 'label' => 'Celulares', 'url' => $resolve( array( 'celulares', 'smartphones' ), array( 'celulares' ) ) ),
				array( 'label' => 'Inteligência artificial', 'url' => $resolve( array( 'inteligencia-artificial', 'ia' ), array( 'inteligencia-artificial' ) ) ),
			),
		),
	);

	$normalize_url = static function ( $url ) {
		$path = wp_parse_url( (string) $url, PHP_URL_PATH );
		return untrailingslashit( strtolower( (string) $path ) );
	};
	$current_url = function_exists( 'go_verge_current_url' ) ? go_verge_current_url() : home_url( add_query_arg( array(), $GLOBALS['wp']->request ?? '' ) );
	$current_key = $normalize_url( $current_url );

	/* Remove empty destinations and deduplicate curated links before trending. */
	$seen_urls = array();
	$remember_url = static function ( $url ) use ( &$seen_urls, $normalize_url ) {
		$key = $normalize_url( $url );
		if ( $key ) {
			$seen_urls[ $key ] = true;
		}
	};
	foreach ( array( $latest_url, $guides_url, $promotions_url, $videos_url ) as $url ) {
		$remember_url( $url );
	}
	foreach ( $groups as $bucket => $group ) {
		$remember_url( $group['url'] );
		$clean_items = array();
		foreach ( $group['items'] as $item ) {
			if ( empty( $item['url'] ) ) {
				continue;
			}
			$key = $normalize_url( $item['url'] );
			if ( ! $key || isset( $seen_urls[ $key ] ) ) {
				continue;
			}
			$clean_items[] = $item;
			$seen_urls[ $key ] = true;
		}
		$groups[ $bucket ]['items'] = $clean_items;
	}

	/* Trending links were intentionally removed from the drawer to keep navigation focused. */

	$current_bucket = go_verge_offcanvas_current_bucket();
	$group_order     = array( 'games', 'entertainment', 'technology' );

	$render_direct = static function ( $label, $url, $extra_class = '' ) use ( $normalize_url, $current_key ) {
		if ( ! $url ) {
			return;
		}
		$is_current = $normalize_url( $url ) === $current_key;
		$class      = trim( 'go-offcanvas__direct ' . $extra_class . ( $is_current ? ' is-current' : '' ) );
		printf(
			'<li class="%1$s"><a href="%2$s"%3$s>%4$s</a></li>',
			esc_attr( $class ),
			esc_url( $url ),
			$is_current ? ' aria-current="page"' : '',
			esc_html( go_verge_upper( $label ) )
		);
	};

	echo '<ul class="go-offcanvas__menu go-offcanvas__menu--smart go-offcanvas__menu--curated">';
	$render_direct( __( 'Últimas', 'go-verge' ), $latest_url, 'go-offcanvas__direct--latest' );

	foreach ( $group_order as $index => $bucket_key ) {
		$group = $groups[ $bucket_key ];
		if ( empty( $group['url'] ) ) {
			continue;
		}
		$items            = array_values( array_filter( $group['items'], static function ( $item ) { return ! empty( $item['url'] ); } ) );
		$submenu_id       = 'go-offcanvas-submenu-' . sanitize_html_class( $bucket_key ) . '-' . (int) $index;
		$group_is_current = $current_bucket === $bucket_key;
		foreach ( $items as $item ) {
			if ( $normalize_url( $item['url'] ) === $current_key ) {
				$group_is_current = true;
				break;
			}
		}

		echo '<li class="go-offcanvas__group go-offcanvas__group--' . esc_attr( $bucket_key ) . ( $group_is_current ? ' is-current' : '' ) . '">';
		echo '<div class="go-offcanvas__group-row">';
		printf(
			'<a class="go-offcanvas__group-link" href="%1$s"%2$s>%3$s</a>',
			esc_url( $group['url'] ),
			$normalize_url( $group['url'] ) === $current_key ? ' aria-current="page"' : '',
			esc_html( go_verge_upper( $group['label'] ) )
		);
		if ( ! empty( $items ) ) {
			printf(
				'<button type="button" class="go-offcanvas__group-toggle" aria-expanded="%1$s" aria-controls="%2$s" data-go-offcanvas-submenu-toggle><span class="screen-reader-text">%3$s</span><span class="go-offcanvas__chevron" aria-hidden="true"></span></button>',
				$group_is_current ? 'true' : 'false',
				esc_attr( $submenu_id ),
				esc_html( sprintf( __( 'Abrir opções de %s', 'go-verge' ), $group['label'] ) )
			);
		}
		echo '</div>';

		if ( ! empty( $items ) ) {
			echo '<ul class="go-offcanvas__submenu" id="' . esc_attr( $submenu_id ) . '"' . ( $group_is_current ? '' : ' hidden' ) . '>';
			foreach ( $items as $item ) {
				$is_current = $normalize_url( $item['url'] ) === $current_key;
				printf(
					'<li%1$s><a href="%2$s"%3$s>%4$s</a></li>',
					$is_current ? ' class="is-current"' : '',
					esc_url( $item['url'] ),
					$is_current ? ' aria-current="page"' : '',
					esc_html( $item['label'] )
				);
			}
			echo '</ul>';
		}
		echo '</li>';
	}


	$render_direct( __( 'Dicas e Guias', 'go-verge' ), $guides_url );

	$buying_guides_url = function_exists( 'go_verge_canonical_buying_guides_url' ) ? go_verge_canonical_buying_guides_url() : '';
	if ( '' === $buying_guides_url ) {
		$buying_term = get_term_by( 'slug', 'guias-de-compra-2', 'category' );
		if ( $buying_term instanceof WP_Term ) {
			$buying_link       = get_term_link( $buying_term );
			$buying_guides_url = is_wp_error( $buying_link ) ? '' : $buying_link;
		}
	}
	$render_direct( __( 'Guias de Compra', 'go-verge' ), $buying_guides_url );

	$render_direct( __( 'Promoções', 'go-verge' ), $promotions_url );
	$render_direct( __( 'Vídeos', 'go-verge' ), $videos_url );
	echo '</ul>';
}

/**
 * Categories that represent a gaming platform — used to show a platform
 * banner/cross-link on the category archive.
 */
function go_verge_platform_category_map() {
	return array(
		'playstation' => 'playstation',
		'xbox'        => 'xbox',
		'nintendo'    => 'nintendo',
		'pc'          => 'pc',
		'pc-gamer'    => 'pc',
		'mobile'      => 'mobile',
		'mobile-gaming' => 'mobile',
	);
}

/**
 * Broad platform hubs and their known consoles/services. Only destinations
 * that actually exist in WordPress are rendered, so a hub never invents a
 * console archive or sends readers to an empty placeholder.
 */
function go_verge_platform_ecosystem_catalog() {
	return array(
		'playstation' => array(
			'title'   => 'PlayStation: consoles e serviços',
			'aliases' => array( 'playstation' ),
			'items'   => array(
				array( 'label' => 'PlayStation 5', 'slugs' => array( 'playstation-5', 'ps5' ) ),
				array( 'label' => 'PlayStation 4', 'slugs' => array( 'playstation-4', 'ps4' ) ),
				array( 'label' => 'PlayStation VR2', 'slugs' => array( 'playstation-vr2', 'ps-vr2', 'psvr2' ) ),
				array( 'label' => 'PlayStation Plus', 'slugs' => array( 'playstation-plus', 'ps-plus' ) ),
			),
		),
		'xbox' => array(
			'title'   => 'Xbox: consoles e serviços',
			'aliases' => array( 'xbox' ),
			'items'   => array(
				array( 'label' => 'Xbox Series X|S', 'slugs' => array( 'xbox-series-xs', 'xbox-series-x-s', 'xbox-series-x', 'xbox-series-s' ) ),
				array( 'label' => 'Xbox One', 'slugs' => array( 'xbox-one' ) ),
				array( 'label' => 'Game Pass', 'slugs' => array( 'game-pass', 'xbox-game-pass', 'pc-game-pass' ) ),
			),
		),
		'nintendo' => array(
			'title'   => 'Nintendo: consoles e serviços',
			'aliases' => array( 'nintendo' ),
			'items'   => array(
				array( 'label' => 'Nintendo Switch 2', 'slugs' => array( 'nintendo-switch-2', 'switch-2' ) ),
				array( 'label' => 'Nintendo Switch', 'slugs' => array( 'nintendo-switch', 'switch' ) ),
				array( 'label' => 'Nintendo eShop', 'slugs' => array( 'nintendo-eshop', 'eshop' ) ),
				array( 'label' => 'Nintendo Switch Online', 'slugs' => array( 'nintendo-switch-online', 'switch-online' ) ),
			),
		),
		'pc' => array(
			'title'   => 'PC: lojas e serviços',
			'aliases' => array( 'pc', 'pc-gamer' ),
			'items'   => array(
				array( 'label' => 'Steam', 'slugs' => array( 'steam' ) ),
				array( 'label' => 'Epic Games Store', 'slugs' => array( 'epic-games-store', 'epic-games' ) ),
				array( 'label' => 'GOG', 'slugs' => array( 'gog', 'gog-com' ) ),
				array( 'label' => 'PC Game Pass', 'slugs' => array( 'pc-game-pass', 'game-pass-pc' ) ),
			),
		),
		'mobile' => array(
			'title'   => 'Mobile: sistemas e serviços',
			'aliases' => array( 'mobile', 'mobile-gaming', 'celular' ),
			'items'   => array(
				array( 'label' => 'Android', 'slugs' => array( 'android' ) ),
				array( 'label' => 'iPhone e iPad', 'slugs' => array( 'ios', 'iphone', 'ipad' ) ),
				array( 'label' => 'Apple Arcade', 'slugs' => array( 'apple-arcade' ) ),
				array( 'label' => 'Google Play', 'slugs' => array( 'google-play', 'play-store' ) ),
			),
		),
	);
}

/** Resolve the broad platform key for a category term. */
function go_verge_platform_key_for_term( $term ) {
	if ( ! $term instanceof WP_Term ) {
		return '';
	}
	$catalog = go_verge_platform_ecosystem_catalog();
	$slugs   = array( $term->slug );
	foreach ( get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
		$ancestor = get_term( $ancestor_id, 'category' );
		if ( $ancestor instanceof WP_Term ) {
			$slugs[] = $ancestor->slug;
		}
	}
	foreach ( $catalog as $key => $config ) {
		if ( array_intersect( $slugs, (array) $config['aliases'] ) ) {
			return $key;
		}
	}
	return '';
}

/** Find a real category or entity for one platform sub-item. */
function go_verge_resolve_platform_destination( $candidate ) {
	foreach ( (array) ( $candidate['slugs'] ?? array() ) as $slug ) {
		$term = get_term_by( 'slug', $slug, 'category' );
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) {
				return array(
					'label'       => $term->name ?: (string) ( $candidate['label'] ?? '' ),
					'url'         => $url,
					'description' => trim( wp_strip_all_tags( term_description( $term ) ) ),
					'image_id'    => 0,
				);
			}
		}
	}
	if ( post_type_exists( 'go_entity' ) ) {
		foreach ( (array) ( $candidate['slugs'] ?? array() ) as $slug ) {
			$entity = get_page_by_path( $slug, OBJECT, 'go_entity' );
			if ( $entity instanceof WP_Post && 'publish' === $entity->post_status ) {
				return array(
					'label'       => get_the_title( $entity ) ?: (string) ( $candidate['label'] ?? '' ),
					'url'         => get_permalink( $entity ),
					'description' => trim( wp_strip_all_tags( get_the_excerpt( $entity ) ) ),
					'image_id'    => has_post_thumbnail( $entity ) ? (int) get_post_thumbnail_id( $entity ) : 0,
				);
			}
		}
	}
	return null;
}

/** Render consoles/services on broad platform category pages. */
function go_verge_render_platform_ecosystem( $term ) {
	$catalog = go_verge_platform_ecosystem_catalog();
	$key     = '';
	if ( $term instanceof WP_Term ) {
		$key = go_verge_platform_key_for_term( $term );
	} elseif ( $term instanceof WP_Post ) {
		$slug = $term->post_name;
		foreach ( $catalog as $candidate_key => $candidate_config ) {
			if ( in_array( $slug, (array) $candidate_config['aliases'], true ) || $slug === $candidate_key ) {
				$key = $candidate_key;
				break;
			}
		}
	} elseif ( is_string( $term ) && isset( $catalog[ $term ] ) ) {
		$key = $term;
	}
	if ( ! $key || empty( $catalog[ $key ] ) ) {
		return;
	}
	$config  = $catalog[ $key ];
	$items   = array();
	$seen    = array();

	foreach ( (array) $config['items'] as $candidate ) {
		$item = go_verge_resolve_platform_destination( $candidate );
		if ( ! $item || empty( $item['url'] ) || isset( $seen[ $item['url'] ] ) ) {
			continue;
		}
		$seen[ $item['url'] ] = true;
		$items[] = $item;
	}

	$children = $term instanceof WP_Term ? get_terms( array( 'taxonomy' => 'category', 'parent' => (int) $term->term_id, 'hide_empty' => true ) ) : array();
	if ( ! is_wp_error( $children ) ) {
		foreach ( $children as $child ) {
			$url = get_term_link( $child );
			if ( is_wp_error( $url ) || isset( $seen[ $url ] ) ) {
				continue;
			}
			$seen[ $url ] = true;
			$items[] = array(
				'label'       => $child->name,
				'url'         => $url,
				'description' => trim( wp_strip_all_tags( term_description( $child ) ) ),
				'image_id'    => 0,
			);
		}
	}

	if ( empty( $items ) ) {
		return;
	}
	?>
	<section class="go-platform-ecosystem" aria-labelledby="go-platform-ecosystem-title">
		<h2 id="go-platform-ecosystem-title"><?php echo esc_html( $config['title'] ); ?></h2>
		<div class="go-platform-ecosystem__grid">
			<?php foreach ( array_slice( $items, 0, 8 ) as $item ) : ?>
				<a class="<?php echo esc_attr( 'go-platform-ecosystem__card' . ( in_array( sanitize_title( remove_accents( $item['label'] ) ), array( 'jogo', 'jogos' ), true ) ? ' go-platform-ecosystem__card--games-subtle' : '' ) ); ?>" href="<?php echo esc_url( $item['url'] ); ?>">
					<?php if ( ! empty( $item['image_id'] ) ) : ?>
						<span class="go-platform-ecosystem__media"><?php echo wp_get_attachment_image( $item['image_id'], 'go_square', false, array( 'loading' => 'lazy', 'alt' => '' ) ); ?></span>
					<?php endif; ?>
					<span class="go-platform-ecosystem__copy"><strong><?php echo esc_html( $item['label'] ); ?></strong><?php if ( ! empty( $item['description'] ) ) : ?><span><?php echo esc_html( wp_trim_words( $item['description'], 18 ) ); ?></span><?php endif; ?></span>
					<span aria-hidden="true">→</span>
				</a>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
}

/**
 * If the given category slug maps to a go_entity platform, return that
 * entity post (for a cross-link banner). Null otherwise.
 */
function go_verge_platform_entity_for_category( $slug ) {
	$map = go_verge_platform_category_map();
	if ( empty( $map[ $slug ] ) || ! post_type_exists( 'go_entity' ) ) {
		return null;
	}
	$entity = get_page_by_path( $map[ $slug ], OBJECT, 'go_entity' );
	return ( $entity instanceof WP_Post ) ? $entity : null;
}

/**
 * Render the editoria filter row as a lateral tab bar.
 *
 * On a parent term it lists the children; on a child it lists its siblings so
 * the reader can move sideways, with "Todos" always leading back to the root.
 * The current term is marked active. No terms are invented: if the editoria has
 * no children, nothing renders — this never creates duplicate categories.
 */
function go_verge_child_category_chips( $term, $current_term_id = 0 ) {
	if ( ! ( $term instanceof WP_Term ) ) {
		return;
	}

	$root     = $term;
	$children = get_terms( array(
		'taxonomy'   => $term->taxonomy,
		'parent'     => $term->term_id,
		'hide_empty' => true,
	) );

	// A leaf term borrows its parent's children so siblings become the filters.
	if ( ( empty( $children ) || is_wp_error( $children ) ) && $term->parent ) {
		$parent = get_term( $term->parent, $term->taxonomy );
		if ( $parent instanceof WP_Term ) {
			$root     = $parent;
			$children = get_terms( array(
				'taxonomy'   => $term->taxonomy,
				'parent'     => $root->term_id,
				'hide_empty' => true,
			) );
		}
	}

	if ( ! ( $root instanceof WP_Term ) || empty( $children ) || is_wp_error( $children ) ) {
		return;
	}

	$root_link = get_term_link( $root );
	if ( is_wp_error( $root_link ) ) {
		return;
	}

	$current_id = $current_term_id ? absint( $current_term_id ) : (int) $term->term_id;
	$root_active = ( $current_id === (int) $root->term_id );
	?>
	<nav class="go-chips go-chips--filter" data-go-editorial-filters aria-label="<?php echo esc_attr( sprintf( __( 'Filtrar %s', 'go-verge' ), $root->name ) ); ?>">
		<a href="<?php echo esc_url( $root_link ); ?>" data-go-editorial-filter="<?php echo esc_attr( $root->slug ); ?>"<?php echo $root_active ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( go_verge_upper( __( 'Todos', 'go-verge' ) ) ); ?></a>
		<?php
		foreach ( $children as $child ) {
			$child_link = get_term_link( $child );
			if ( is_wp_error( $child_link ) ) {
				continue;
			}
			$child_label = $child->name;
			if ( 'consoles' === sanitize_title( $child->slug ) || 'consoles' === sanitize_title( $child->name ) ) {
				$child_label = __( 'Plataformas', 'go-verge' );
			}
			$is_active = ( $current_id === (int) $child->term_id );
			printf(
				'<a href="%1$s" data-go-editorial-filter="%2$s"%3$s>%4$s</a>',
				esc_url( $child_link ),
				esc_attr( $child->slug ),
				$is_active ? ' class="is-active" aria-current="page"' : '',
				esc_html( go_verge_upper( $child_label ) )
			);
		}
		?>
	</nav>
	<?php
}


/**
 * Upgrade explicit spoiler warnings already present in article copy into a
 * consistent editorial alert. The warning text itself is preserved.
 */
function go_verge_upgrade_spoiler_warnings( $content ) {
	if ( false === stripos( remove_accents( wp_strip_all_tags( (string) $content ) ), 'spoiler' ) ) {
		return $content;
	}

	// If the article already contains a rendered spoiler note, never add another.
	if ( false !== stripos( (string) $content, 'go-spoiler-alert' ) ) {
		return $content;
	}

	$warning_rendered = false;

	return preg_replace_callback(
		'/<p\b([^>]*)>(.*?)<\/p>/isu',
		static function ( $matches ) use ( &$warning_rendered ) {
			$plain = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( html_entity_decode( $matches[2], ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) ) ) );
			$test  = remove_accents( strtolower( $plain ) );

			// Only explicit editorial warnings qualify. A casual mention of
			// "spoiler" inside a paragraph must never become an alert.
			$is_explicit_warning = preg_match(
				'/^(?:(?:warning|aviso|atencao|alerta)\b.{0,180}\bspoilers?\b|a partir daqui\b.{0,180}\bspoilers?\b|(?:este|esta|o|a)?\s*(?:texto|materia|artigo|trecho|conteudo)\b.{0,120}\b(?:contem|tem|inclui)\s+spoilers?\b|(?:contem|ha)\s+spoilers?\b)/i',
				$test
			);

			if ( ! $is_explicit_warning || $warning_rendered ) {
				return $matches[0];
			}

			$warning_rendered = true;

			return '<aside class="go-spoiler-alert" role="note" aria-label="' . esc_attr__( 'Aviso de spoiler', 'go-verge' ) . '">'
				. '<span class="go-spoiler-alert__label">' . esc_html__( 'Spoilers à frente', 'go-verge' ) . '</span>'
				. '<div class="go-spoiler-alert__text">' . wp_kses_post( $matches[2] ) . '</div>'
				. '</aside>';
		},
		(string) $content
	);
}

/**
 * Inline one of the theme's bundled icons (assets/img/icons/{name}.svg),
 * tagged with an extra class, stripped of any hardcoded fill so it inherits
 * currentColor from its wrapping button/link.
 */
function go_verge_icon( $name, $extra_class = '' ) {
	static $cache = array();

	$aliases = array( 'search'=>'busca', 'theme-sun'=>'sol', 'theme-moon'=>'lua', 'share'=>'compartilhar', 'close'=>'fechar', 'clock'=>'relogio', 'bookmark'=>'salvar', 'comments'=>'comentarios', 'arrow-right'=>'seta-direita', 'arrow-left'=>'seta-esquerda' );
	$name = sanitize_file_name( $aliases[$name] ?? $name );
	if ( isset( $cache[ $name ] ) ) {
		$svg = $cache[ $name ];
	} else {
		$path = GO_VERGE_DIR . '/assets/img/icons/' . $name . '.svg';
		$svg  = file_exists( $path ) ? (string) file_get_contents( $path ) : '';
		$cache[ $name ] = $svg;
	}

	if ( '' === $svg ) {
		return '';
	}

	$svg = preg_replace( '/<title>.*?<\/title>/s', '', $svg );
	$svg = preg_replace( '/\s(?:role|aria-label|aria-hidden|focusable)="[^"]*"/i', '', $svg );
	$svg = preg_replace( '/<svg /', '<svg aria-hidden="true" focusable="false" ', $svg, 1 );

	if ( '' !== $extra_class ) {
		$svg = preg_replace( '/<svg /', '<svg class="' . esc_attr( $extra_class ) . '" ', $svg, 1 );
	}

	return $svg;
}

/**
 * Rank related stories using real editorial signals. A shared linked game or
 * technical-sheet subject is stronger than taxonomy; categories and tags are
 * then used to break ties before recency.
 */
function go_verge_related_post_ids( $post_id, $limit = 2 ) {
	// The homepage and archives keep their existing ranking and queries.
	if ( is_singular( 'post' ) && function_exists( 'go_verge_single_recommendation_ids' ) ) {
		return go_verge_single_recommendation_ids( $post_id, $limit );
	}
	/*
	 * The ranking does not depend on $limit, and a single article asks for it
	 * three times (inline related, internal links, recirculation). Rank once per
	 * request with the largest limit seen and slice for smaller callers.
	 */
	static $memo = array();
	$post_id = absint( $post_id );
	$limit   = max( 1, (int) $limit );
	if ( ! $post_id ) {
		return array();
	}
	if ( ! isset( $memo[ $post_id ] ) || $memo[ $post_id ]['limit'] < $limit ) {
		$depth             = max( 24, $limit );
		$memo[ $post_id ] = array( 'limit' => $depth, 'ids' => go_verge_related_post_ids_ranked( $post_id, $depth ) );
	}
	return array_slice( $memo[ $post_id ]['ids'], 0, $limit );
}

/**
 * Term IDs of a post read from the object-term cache.
 *
 * wp_get_post_categories()/wp_get_post_tags() always query the database, even
 * after update_object_term_cache() primed the same data; get_the_terms() reads
 * the primed cache. Same term set, no per-candidate query.
 *
 * @param int    $post_id  Post ID.
 * @param string $taxonomy Taxonomy.
 * @return int[]
 */
function go_verge_cached_term_ids( $post_id, $taxonomy ) {
	$terms = get_the_terms( (int) $post_id, $taxonomy );
	return ( $terms && ! is_wp_error( $terms ) ) ? array_map( 'intval', wp_list_pluck( $terms, 'term_id' ) ) : array();
}

/**
 * Uncached related-story ranking. Use go_verge_related_post_ids().
 *
 * @param int $post_id Source post.
 * @param int $limit   Maximum IDs.
 * @return int[]
 */
function go_verge_related_post_ids_ranked( $post_id, $limit ) {
	$post_id = absint( $post_id );
	$limit   = max( 1, (int) $limit );
	if ( ! $post_id ) {
		return array();
	}

	$category_ids = wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) );
	$tag_ids      = wp_get_post_tags( $post_id, array( 'fields' => 'ids' ) );
	$linked_game  = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	if ( ! $linked_game ) {
		$linked_game = absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	}
	$subject_ref    = trim( (string) get_post_meta( $post_id, 'go_technical_subject_ref', true ) );
	$subject_custom = trim( (string) get_post_meta( $post_id, 'go_technical_subject_custom', true ) );
	$source_desk = function_exists( 'go_verge_post_editorial_desk' ) ? go_verge_post_editorial_desk( $post_id ) : '';
	$source_production = absint( get_post_meta( $post_id, '_go_production_id', true ) );
	$source_entities   = array_values( array_filter( array_map( 'absint', (array) get_post_meta( $post_id, '_go_entity_ids', true ) ) ) );
	$authority_subject = function_exists( 'go_verge_v46_primary_subject' ) ? go_verge_v46_primary_subject( $post_id ) : null;
	$authority_related = array();

	$base_args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'post__not_in'        => array( $post_id ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'orderby'             => 'date',
		'order'               => 'DESC',
		'fields'              => 'ids',
	);
	$pool = array();

	/* V46: explicitly seed the pool with the canonical subject cluster. This is
	 * stronger and cheaper than hoping a production/person topic shares a broad
	 * category. The marked IDs receive a semantic score later. */
	if ( is_array( $authority_subject ) ) {
		$authority_type = (string) ( $authority_subject['type'] ?? '' );
		$authority_id   = absint( $authority_subject['id'] ?? 0 );
		$subject_ids    = array();
		if ( $authority_id && in_array( $authority_type, array( 'games', 'productions', 'go_entity' ), true ) && function_exists( 'go_verge_product_related_post_ids' ) ) {
			$subject_ids = go_verge_product_related_post_ids( $authority_id, $authority_type, 36, array( 'exclude' => array( $post_id ) ) );
		} elseif ( $authority_id && 'post_tag' === $authority_type ) {
			$subject_args = $base_args;
			$subject_args['posts_per_page'] = 36;
			$subject_args['tag_id'] = $authority_id;
			$subject_ids = get_posts( $subject_args );
		} elseif ( 'topic_hub' === $authority_type && function_exists( 'go_verge_v21_topic_query' ) ) {
			$subject_query = go_verge_v21_topic_query( sanitize_title( (string) ( $authority_subject['name'] ?? '' ) ), 1, 36 );
			$subject_ids = wp_list_pluck( $subject_query->posts, 'ID' );
		}
		foreach ( array_filter( array_map( 'absint', (array) $subject_ids ) ) as $subject_post_id ) {
			if ( $subject_post_id && $subject_post_id !== $post_id ) { $authority_related[ $subject_post_id ] = true; }
		}
		$pool = array_merge( $pool, array_keys( $authority_related ) );
	}

	if ( $linked_game ) {
		$game_args = $base_args;
		$game_args['posts_per_page'] = 24;
		$game_args['meta_query'] = array(
			'relation' => 'OR',
			array( 'key' => 'go_linked_game_id', 'value' => $linked_game, 'compare' => '=' ),
			array( 'key' => 'go_review_game_id', 'value' => $linked_game, 'compare' => '=' ),
		);
		$pool = array_merge( $pool, get_posts( $game_args ) );
	}
	if ( $source_production && ( ! is_array($authority_subject) || 'productions' !== ($authority_subject['type'] ?? '') || $source_production !== absint($authority_subject['id'] ?? 0) ) ) {
		$production_args = $base_args;
		$production_args['posts_per_page'] = 24;
		$production_args['meta_key'] = '_go_production_id';
		$production_args['meta_value'] = $source_production;
		$pool = array_merge( $pool, get_posts( $production_args ) );
	}

	if ( $subject_ref && 'auto' !== $subject_ref && 'custom' !== $subject_ref ) {
		$subject_args = $base_args;
		$subject_args['posts_per_page'] = 24;
		$subject_args['meta_key'] = 'go_technical_subject_ref';
		$subject_args['meta_value'] = $subject_ref;
		$pool = array_merge( $pool, get_posts( $subject_args ) );
	}

	if ( 'custom' === $subject_ref && '' !== $subject_custom ) {
		$custom_args = $base_args;
		$custom_args['posts_per_page'] = 24;
		$custom_args['meta_key'] = 'go_technical_subject_custom';
		$custom_args['meta_value'] = $subject_custom;
		$pool = array_merge( $pool, get_posts( $custom_args ) );
	}

	/* Retrieve specific tags independently: sixty fresh Games posts must not
	 * crowd an older exact-topic match out of a combined OR-category pool. */
	if ( $tag_ids ) {
		$tax_args = $base_args;
		$tax_args['posts_per_page'] = 48;
		$tax_args['tax_query'] = array( array('taxonomy'=>'post_tag','field'=>'term_id','terms'=>array_map('absint',$tag_ids)) );
		$pool = array_merge( $pool, get_posts( $tax_args ) );
	}
	if ( $category_ids ) {
		$category_args = $base_args;
		$category_args['posts_per_page'] = 36;
		$category_args['tax_query'] = array( array('taxonomy'=>'category','field'=>'term_id','terms'=>array_map('absint',$category_ids)) );
		$pool = array_merge( $pool, get_posts( $category_args ) );
	}

	/* Source taxonomy/subject pools already carry the useful candidates. A
	 * global 60-post query added work on every article without proving affinity. */
	$pool = array_values( array_unique( array_filter( array_map( 'absint', $pool ) ) ) );
	if ( empty( $pool ) ) {
		return array();
	}
	/* The scoring loop reads meta, terms and dates for every candidate; the ID-only
	 * queries above prime nothing, so each read used to be its own query. */
	if ( function_exists( '_prime_post_caches' ) ) {
		_prime_post_caches( $pool, false, true );
	}
	update_object_term_cache( $pool, 'post' );

	$scores  = array();
	$now     = current_time( 'timestamp', true );
	$primary = go_verge_get_primary_term( $post_id );

	/*
	 * Especificidade da tag (estilo IDF): uma tag rara ("DualSense") é um sinal
	 * de assunto muito mais forte do que uma tag ampla de pilar ("PlayStation").
	 * Pesar por raridade faz a sidebar de cada matéria puxar primeiro o conteúdo
	 * realmente sobre aquele tema, não a notícia recente da editoria inteira.
	 */
	$tag_weights = array();
	foreach ( (array) $tag_ids as $go_tag_id ) {
		$go_tag_id = absint( $go_tag_id );
		if ( ! $go_tag_id ) {
			continue;
		}
		$go_tag_term  = get_term( $go_tag_id, 'post_tag' );
		$go_tag_count = ( $go_tag_term instanceof WP_Term ) ? max( 1, (int) $go_tag_term->count ) : 20;
		// Tag com poucos posts ~55 pts; tag ampla desce até o piso de 12.
		$tag_weights[ $go_tag_id ] = max( 12, min( 55, (int) round( 55 * 6 / ( 6 + $go_tag_count ) ) ) );
	}

	foreach ( $pool as $candidate_id ) {
		$candidate_id   = absint( $candidate_id );
		if ( $source_desk && $source_desk !== go_verge_post_editorial_desk( $candidate_id ) ) { continue; }
		if ( function_exists( 'go_verge_promotion_has_expired' ) && go_verge_promotion_has_expired( $candidate_id ) ) { continue; }
		$score          = 0;
		$semantic_score = 0;
		$strong_signal  = false;

		if ( isset( $authority_related[ $candidate_id ] ) ) {
			$score += 180;
			$semantic_score += 180;
			$strong_signal = true;
		}

		$candidate_game = absint( get_post_meta( $candidate_id, 'go_linked_game_id', true ) );
		if ( ! $candidate_game ) {
			$candidate_game = absint( get_post_meta( $candidate_id, 'go_review_game_id', true ) );
		}
		if ( $linked_game && $candidate_game && $linked_game === $candidate_game ) {
			$score += 120;
			$semantic_score += 120;
			$strong_signal = true;
		}

		$candidate_production = absint( get_post_meta( $candidate_id, '_go_production_id', true ) );
		if ( $source_production && $candidate_production && $source_production === $candidate_production ) {
			$score += 145;
			$semantic_score += 145;
			$strong_signal = true;
		}
		if ( $source_entities ) {
			$candidate_entities = array_values( array_filter( array_map( 'absint', (array) get_post_meta( $candidate_id, '_go_entity_ids', true ) ) ) );
			$shared_entities = array_intersect( $source_entities, $candidate_entities );
			if ( $shared_entities ) {
				$entity_score = min( 90, count( $shared_entities ) * 45 );
				$score += $entity_score;
				$semantic_score += $entity_score;
				$strong_signal = true;
			}
		}

		$candidate_subject = trim( (string) get_post_meta( $candidate_id, 'go_technical_subject_ref', true ) );
		if ( $subject_ref && 'auto' !== $subject_ref && 'custom' !== $subject_ref && $subject_ref === $candidate_subject ) {
			$score += 100;
			$semantic_score += 100;
			$strong_signal = true;
		}
		if ( 'custom' === $subject_ref && '' !== $subject_custom && 'custom' === $candidate_subject ) {
			$candidate_custom = trim( (string) get_post_meta( $candidate_id, 'go_technical_subject_custom', true ) );
			if ( '' !== $candidate_custom && 0 === strcasecmp( $subject_custom, $candidate_custom ) ) {
				$score += 100;
				$semantic_score += 100;
				$strong_signal = true;
			}
		}

		$candidate_categories = go_verge_cached_term_ids( $candidate_id, 'category' );
		$candidate_tags       = go_verge_cached_term_ids( $candidate_id, 'post_tag' );
		$shared_categories    = array_intersect( (array) $category_ids, (array) $candidate_categories );
		$shared_tags          = array_intersect( (array) $tag_ids, (array) $candidate_tags );

		$category_score = count( $shared_categories ) * 24;
		$tag_score      = 0;
		foreach ( (array) $shared_tags as $go_shared_tag_id ) {
			$tag_score += isset( $tag_weights[ $go_shared_tag_id ] ) ? $tag_weights[ $go_shared_tag_id ] : 24;
		}
		$score         += $category_score + $tag_score;
		$semantic_score += $category_score + $tag_score;
		if ( ! empty( $shared_tags ) ) {
			$strong_signal = true;
		}
		if ( count( $shared_categories ) > 1 ) {
			$strong_signal = true;
		}

		if ( $primary instanceof WP_Term && in_array( (int) $primary->term_id, array_map( 'intval', (array) $candidate_categories ), true ) ) {
			$score += 28;
			$semantic_score += 28;
			$pillar_slugs = function_exists( 'go_verge_pillar_slugs' ) ? go_verge_pillar_slugs() : array( 'games', 'noticias', 'entretenimento', 'tecnologia' );
			$pillar_slugs = array_merge( $pillar_slugs, array('games','entretenimento','tecnologia','ofertas') );
			if ( ! in_array( sanitize_title( $primary->slug ), array_map( 'sanitize_title', $pillar_slugs ), true ) ) {
				$strong_signal = true;
			}
		}

		// Freshness may only break ties between posts that already share an
		// editorial signal. It can never make an unrelated recent post relevant.
		if ( $semantic_score <= 0 || ! $strong_signal ) {
			continue;
		}

		/* V49: once relevance is proven, help underlinked stories earn discovery.
		 * This is deliberately downstream of the strong-signal gate, so a weak or
		 * unrelated page never enters a cluster just because it lacks links. */
		if ( function_exists( 'go_verge_v46_inbound_link_count' ) ) {
			$go_v49_inbound = go_verge_v46_inbound_link_count( $candidate_id );
			if ( 0 === $go_v49_inbound ) {
				$score += 48;
			} elseif ( 1 === $go_v49_inbound ) {
				$score += 36;
			} elseif ( null !== $go_v49_inbound && $go_v49_inbound <= 3 ) {
				$score += 18;
			}
		}

		// Keep a light freshness component without letting a new unrelated post win.
		$published = (int) get_post_time( 'U', true, $candidate_id );
		$age_days  = $published ? max( 0, ( $now - $published ) / DAY_IN_SECONDS ) : 9999;
		$score    += max( 0, 12 - min( 12, (int) floor( $age_days / 14 ) ) );

		if ( $score > 0 ) {
			$scores[ $candidate_id ] = $score;
		}
	}

	if ( empty( $scores ) ) {
		return array();
	}

	uksort(
		$scores,
		static function ( $a, $b ) use ( $scores ) {
			if ( $scores[ $a ] === $scores[ $b ] ) {
				return (int) $b <=> (int) $a;
			}
			return $scores[ $b ] <=> $scores[ $a ];
		}
	);

	return array_slice( array_map( 'absint', array_keys( $scores ) ), 0, $limit );
}

/**
 * Small contextual recommendation block used inside long reads.
 */
function go_verge_inline_related_markup( $post_id = null, $variant = 'related', $exclude_ids = array() ) {
	$post_id     = $post_id ? absint( $post_id ) : get_the_ID();
	$variant     = 'read-also' === $variant ? 'read-also' : 'related';
	$exclude_ids = array_values( array_filter( array_map( 'absint', (array) $exclude_ids ) ) );

	/*
	 * V70: join the request-wide recirculation registry.
	 *
	 * This block renders first — go_verge_inject_inline_related() runs in
	 * single.php before the rail and before every module under the story — and
	 * it ranks from the same affinity pool they do. It read no registry and
	 * wrote to none, so its two picks were free to appear again in "Continue
	 * neste assunto", again in the rail and again in the discovery grid. That is
	 * how one subject ends up filling a page: not because the ranking is wrong,
	 * because four surfaces asked the same question independently.
	 */
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		$exclude_ids = array_values( array_unique( array_merge( $exclude_ids, array_map( 'absint', (array) go_verge_recirculation_shown_ids() ) ) ) );
	}

	$pool = is_singular('post') && function_exists('go_verge_single_recommendation_ids')
		? go_verge_single_recommendation_ids( $post_id, 2, $exclude_ids )
		: go_verge_related_post_ids( $post_id, 10 );

	if ( empty( $pool ) ) {
		return '';
	}

	$ids = array();
	foreach ( $pool as $candidate_id ) {
		$candidate_id = absint( $candidate_id );
		if ( ! $candidate_id || in_array( $candidate_id, $exclude_ids, true ) ) {
			continue;
		}
		$ids[] = $candidate_id;
		if ( count( $ids ) >= 2 ) {
			break;
		}
	}

	if ( empty( $ids ) ) {
		return '';
	}

	/* Hand the picks to every surface that renders after this one. */
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( $ids );
	}

	$is_secondary = 'read-also' === $variant;
	$label        = __( 'Leia também', 'go-verge' );
	$class        = $is_secondary ? 'go-inline-related--secondary' : 'go-inline-related--primary';

	$out  = '<aside class="go-inline-related ' . esc_attr( $class ) . '" data-go-related-block="' . esc_attr( $variant ) . '" aria-label="' . esc_attr( $label ) . '">';
	$out .= '<p class="go-inline-related__title">' . esc_html( $label ) . '</p>';
	$out .= '<div class="go-inline-related__items">';

	foreach ( $ids as $related_id ) {
		$has_thumb = has_post_thumbnail( $related_id );
		$reco_attrs = function_exists('go_verge_reco_data_attributes') ? ' ' . go_verge_reco_data_attributes($related_id,'inline') : '';
		$out      .= '<a class="go-inline-related__item' . ( $has_thumb ? '' : ' is-no-thumb' ) . '" href="' . esc_url( get_permalink( $related_id ) ) . '"' . $reco_attrs . '>';

		if ( $has_thumb ) {
			$out .= '<span class="go-inline-related__media">' . get_the_post_thumbnail(
				$related_id,
				'go_card',
				array(
					'loading' => 'lazy',
					'alt'     => '',
				)
			) . '</span>';
		}

		$out .= '<span class="go-inline-related__copy"><strong>' . esc_html( get_the_title( $related_id ) ) . '</strong><span class="go-inline-related__meta">' . go_verge_time_html( $related_id ) . '</span></span>';
		$out .= '</a>';
	}

	$out .= '</div></aside>';

	return $out;
}

/**
 * Upgrade legacy "Leia também" headings followed by a bullet list to the
 * same editorial card treatment used by the native related block.
 */
function go_verge_upgrade_legacy_read_also( $content, $post_id = null ) {
	if ( ! is_string( $content ) || '' === trim( $content ) || ( false === stripos( remove_accents( $content ), 'Leia tambem' ) && false === stripos( remove_accents( $content ), 'Leia mais' ) ) ) {
		return $content;
	}

	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$replacement_index = 0;
	$pattern = '~<(?P<tag>p|h2|h3|h4)(?P<attrs>[^>]*)>(?P<head>.*?)</(?P=tag)>(?:\s|<!--.*?-->|<p\b[^>]*>(?:\s|&nbsp;|<br\s*/?>)*</p>)*<(?P<list>ul|ol)(?P<lattrs>[^>]*)>(?P<items>.*?)</(?P=list)>~isu';
	return preg_replace_callback(
		$pattern,
		function ( $match ) use ( &$replacement_index, $post_id ) {
			$heading = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( html_entity_decode( (string) $match['head'], ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) ) ) );
			$heading_cmp = strtolower( remove_accents( rtrim( $heading, ": \t\n\r\0\x0B" ) ) );
			if ( ! in_array( $heading_cmp, array( 'leia tambem', 'leia mais' ), true ) ) {
				return $match[0];
			}

			++$replacement_index;

			if ( ! preg_match_all( '~<a\b[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>~isu', (string) $match['items'], $links, PREG_SET_ORDER ) ) {
				return $match[0];
			}

			$items = array();
			$seen  = array();
			foreach ( $links as $link_match ) {
				$url   = esc_url_raw( html_entity_decode( (string) $link_match[1], ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) );
				$label = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) $link_match[2] ) ) );
				if ( ! $url || isset( $seen[ $url ] ) ) {
					continue;
				}
				$seen[ $url ] = true;
				$post_id = url_to_postid( $url );
				if ( $post_id && 'publish' === get_post_status( $post_id ) ) {
					$label = get_the_title( $post_id ) ?: $label;
				}
				if ( '' === $label ) {
					continue;
				}
				$items[] = array( 'url' => $url, 'label' => $label, 'post_id' => absint( $post_id ) );
				if ( count( $items ) >= 6 ) {
					break;
				}
			}
			if ( empty( $items ) ) {
				return $match[0];
			}

			$out  = '<aside class="go-inline-related go-inline-related--legacy go-inline-related--primary" data-go-related-block="related" aria-label="' . esc_attr__( 'Leia também', 'go-verge' ) . '">';
			$out .= '<p class="go-inline-related__title">' . esc_html__( 'Leia também', 'go-verge' ) . '</p>';
			$out .= '<div class="go-inline-related__items">';
			foreach ( $items as $item ) {
				$has_thumb = $item['post_id'] && has_post_thumbnail( $item['post_id'] );
				$out .= '<a class="go-inline-related__item' . ( $has_thumb ? '' : ' is-no-thumb' ) . '" href="' . esc_url( $item['url'] ) . '">';
				if ( $has_thumb ) {
					$out .= '<span class="go-inline-related__media">' . get_the_post_thumbnail( $item['post_id'], 'go_card', array( 'loading' => 'lazy', 'alt' => '' ) ) . '</span>';
				}
				$out .= '<span class="go-inline-related__copy"><strong>' . esc_html( $item['label'] ) . '</strong>';
				if ( $item['post_id'] ) {
					$out .= '<span class="go-inline-related__meta">' . go_verge_time_html( $item['post_id'] ) . '</span>';
				}
				$out .= '</span></a>';
			}
			$out .= '</div></aside>';
			return $out;
		},
		$content
	);
}

/**
 * Detect an existing read-also heading regardless of accents, case or inline HTML.
 * This prevents a native block from being injected next to legacy headings such
 * as "Leia tambem".
 */
function go_verge_content_has_read_also( $content ) {
	if ( ! is_string( $content ) || '' === trim( $content ) ) {
		return false;
	}
	$text = html_entity_decode( wp_strip_all_tags( $content ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
	$text = strtolower( remove_accents( $text ) );
	$text = preg_replace( '/\s+/u', ' ', $text );
	return (bool) preg_match( '/\b(?:leia\s+tambem|leia\s+mais|relacionado)\b/u', (string) $text );
}

/**
 * Version the contextual link graph. Bumping this value makes old articles
 * immediately reconsider newly published/updated related stories without
 * rewriting historical post content in the database.
 */
function go_verge_internal_link_graph_version() {
	$version = absint( get_option( 'go_verge_internal_link_graph_version', 1 ) );
	return max( 1, $version );
}

/** Refresh the graph after a real post save/delete. */
function go_verge_internal_link_bump_graph_version( $post_id = 0 ) {
	$post_id = absint( $post_id );
	if ( $post_id && ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || 'post' !== get_post_type( $post_id ) ) ) {
		return;
	}
	$next = max( time(), go_verge_internal_link_graph_version() + 1 );
	update_option( 'go_verge_internal_link_graph_version', $next, false );
}
add_action( 'save_post_post', 'go_verge_internal_link_bump_graph_version', 240 );
add_action( 'before_delete_post', 'go_verge_internal_link_bump_graph_version', 20 );

/** Normalize one link label for de-duplication only. */
function go_verge_internal_link_key( $value ) {
	$value = html_entity_decode( wp_strip_all_tags( (string) $value ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
	$value = strtolower( remove_accents( $value ) );
	$value = preg_replace( '/[^a-z0-9]+/u', ' ', $value );
	return trim( preg_replace( '/\s+/u', ' ', (string) $value ) );
}

/** Generic words that must never become standalone automatic anchors. */
function go_verge_internal_link_stopwords() {
	return array(
		'a','o','as','os','um','uma','uns','umas','de','da','do','das','dos','e','em','no','na','nos','nas','por','para','com','sem','sob','sobre','ao','aos','que','como','quando','onde','qual','quais','mais','menos','novo','nova','novos','novas','jogo','jogos','game','games','guia','guias','dica','dicas','noticia','noticias','review','reviews','critica','criticas','veja','saiba','entenda','tudo','melhor','melhores','hoje','agora','oficial','oficiais','gratis','gratuito','gratuitos'
	);
}

/** Decide whether a phrase is specific enough to be linked automatically. */
function go_verge_internal_link_phrase_is_safe( $phrase, $allow_single_word = false ) {
	$phrase = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) $phrase ) ) );
	$length = mb_strlen( $phrase, 'UTF-8' );
	if ( $length < 5 || $length > 100 ) {
		return false;
	}

	$key = go_verge_internal_link_key( $phrase );
	if ( '' === $key ) {
		return false;
	}
	$broad = array(
		'games','jogos','tecnologia','entretenimento','noticias','noticia','review','reviews','critica','criticas','dicas','guias','dicas e guias','playstation','xbox','nintendo','pc','steam','filmes','series','anime','animes'
	);
	if ( in_array( $key, $broad, true ) ) {
		return false;
	}

	$words = preg_split( '/\s+/u', $key, -1, PREG_SPLIT_NO_EMPTY );
	if ( ! $words ) {
		return false;
	}
	if ( count( $words ) < 2 && ! $allow_single_word ) {
		return false;
	}
	if ( count( $words ) > 10 ) {
		return false;
	}

	$meaningful = array_diff( $words, go_verge_internal_link_stopwords() );
	return ! empty( $meaningful );
}

/** Build a typography-tolerant Unicode regex for one exact phrase. */
function go_verge_internal_link_phrase_pattern( $phrase ) {
	$chars = preg_split( '//u', (string) $phrase, -1, PREG_SPLIT_NO_EMPTY );
	if ( ! $chars ) {
		return '';
	}
	$out = '';
	foreach ( $chars as $char ) {
		if ( preg_match( '/\s/u', $char ) ) {
			$out .= '\\s+';
		} elseif ( in_array( $char, array( "'", '’', '‘', '´', '`' ), true ) ) {
			$out .= "['’‘´`]";
		} elseif ( in_array( $char, array( '-', '‐', '‑', '–', '—' ), true ) ) {
			$out .= '[-‐‑–—]';
		} else {
			$out .= preg_quote( $char, '/' );
		}
	}
	return '/(?<![\\p{L}\\p{N}])(' . $out . ')(?![\\p{L}\\p{N}])/iu';
}

/** Check whether an exact contextual phrase is actually present in source copy. */
function go_verge_internal_link_phrase_exists( $haystack, $phrase ) {
	if ( function_exists( 'go_verge_il_find' ) ) {
		return false !== go_verge_il_find( (string) $haystack, (string) $phrase );
	}
	$pattern = go_verge_internal_link_phrase_pattern( $phrase );
	return $pattern ? (bool) preg_match( $pattern, (string) $haystack ) : false;
}

/** Resolve an explicit or confidently inferred game for old and new stories. */
function go_verge_internal_link_game_id( $post_id, $allow_inference = true ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return 0;
	}
	$cache_key = $post_id . ':' . ( $allow_inference ? '1' : '0' );
	if ( isset( $cache[ $cache_key ] ) ) {
		return $cache[ $cache_key ];
	}
	$game_id = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	if ( ! $game_id ) {
		$game_id = absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	}
	if ( ! $game_id && function_exists( 'go_verge_product_linked_game_id' ) ) {
		$game_id = absint( go_verge_product_linked_game_id( $post_id ) );
	}

	// Historical posts can participate without being rewritten in the database.
	// Cache the conservative inference so old pages do not rescore the complete
	// game catalog on every request. Editing the article changes the cache key.
	if ( ! $game_id && $allow_inference && function_exists( 'go_verge_game_intelligence_analyze' ) ) {
		$modified      = (string) get_post_field( 'post_modified_gmt', $post_id );
		$inference_key = 'go_il_game_' . $post_id . '_' . substr( md5( $modified ), 0, 8 );
		$inferred      = get_transient( $inference_key );
		if ( is_array( $inferred ) && array_key_exists( 'id', $inferred ) ) {
			$game_id = absint( $inferred['id'] );
		} else {
			$analysis = go_verge_game_intelligence_analyze( $post_id );
			if ( ! empty( $analysis['safe'] ) && ! empty( $analysis['candidate']['id'] ) ) {
				$game_id = absint( $analysis['candidate']['id'] );
			}
			set_transient( $inference_key, array( 'id' => $game_id ), 12 * HOUR_IN_SECONDS );
		}
	}
	$cache[ $cache_key ] = $game_id;
	return $game_id;
}

/** URLs already linked by the editor must never be duplicated automatically. */
function go_verge_internal_link_existing_urls( $content ) {
	$urls = array();
	if ( preg_match_all( '/<a\b[^>]*\bhref=(?:"([^"]+)"|\'([^\']+)\')/iu', (string) $content, $matches, PREG_SET_ORDER ) ) {
		foreach ( $matches as $match ) {
			$url = html_entity_decode( (string) ( $match[1] ?: $match[2] ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
			if ( '' !== $url ) {
				$urls[ untrailingslashit( $url ) ] = true;
			}
		}
	}
	return $urls;
}

/** Cached related-story pool. New saves invalidate old pages through graph versioning. */
function go_verge_internal_link_related_article_ids( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || ! function_exists( 'go_verge_related_post_ids' ) ) {
		return array();
	}
	$modified = (string) get_post_field( 'post_modified_gmt', $post_id );
	$key      = 'go_il_rel_' . $post_id . '_' . go_verge_internal_link_graph_version() . '_' . substr( md5( $modified ), 0, 8 );
	$cached   = get_transient( $key );
	if ( is_array( $cached ) ) {
		return array_values( array_filter( array_map( 'absint', $cached ) ) );
	}
	$ids = array_values( array_filter( array_map( 'absint', go_verge_related_post_ids( $post_id, 18 ) ) ) );
	set_transient( $key, $ids, 6 * HOUR_IN_SECONDS );
	return $ids;
}

/** Score the actual relationship between source and destination article. */
function go_verge_internal_link_article_relation_score( $source_id, $candidate_id ) {
	$score = 0;
	$source_game    = go_verge_internal_link_game_id( $source_id, true );
	$candidate_game = go_verge_internal_link_game_id( $candidate_id, false );
	if ( $source_game && $candidate_game && $source_game === $candidate_game ) {
		$score += 150;
	}

	/* V46: the canonical subject is stronger than a generic taxonomy overlap.
	 * This makes Meu Nome é Farah → Meu Nome é Farah, GTA 6 → GTA 6, etc.
	 * the natural center of the graph while still allowing Demet/Engin/Tahir
	 * and other evidenced secondary topics to contribute. */
	if ( function_exists( 'go_verge_v46_primary_subject' ) ) {
		$source_subject    = go_verge_v46_primary_subject( $source_id );
		$candidate_subject = go_verge_v46_primary_subject( $candidate_id );
		if ( $source_subject && $candidate_subject && ! empty( $source_subject['url_key'] ) && $source_subject['url_key'] === ( $candidate_subject['url_key'] ?? '' ) ) {
			$score += 220;
		}
	}
	if ( function_exists( 'go_verge_v46_post_topic_urls' ) ) {
		$shared_topics = array_intersect( go_verge_v46_post_topic_urls( $source_id, 6 ), go_verge_v46_post_topic_urls( $candidate_id, 6 ) );
		$score += min( 105, count( $shared_topics ) * 35 );
	}

	$source_production    = absint( get_post_meta( $source_id, '_go_production_id', true ) );
	$candidate_production = absint( get_post_meta( $candidate_id, '_go_production_id', true ) );
	if ( $source_production && $candidate_production && $source_production === $candidate_production ) {
		$score += 150;
	}
	$source_entities    = array_values( array_filter( array_map( 'absint', (array) get_post_meta( $source_id, '_go_entity_ids', true ) ) ) );
	$candidate_entities = array_values( array_filter( array_map( 'absint', (array) get_post_meta( $candidate_id, '_go_entity_ids', true ) ) ) );
	$score += min( 80, count( array_intersect( $source_entities, $candidate_entities ) ) * 40 );

	$source_tags    = go_verge_cached_term_ids( $source_id, 'post_tag' );
	$candidate_tags = go_verge_cached_term_ids( $candidate_id, 'post_tag' );
	$score += min( 80, count( array_intersect( (array) $source_tags, (array) $candidate_tags ) ) * 28 );

	$source_cats    = go_verge_cached_term_ids( $source_id, 'category' );
	$candidate_cats = go_verge_cached_term_ids( $candidate_id, 'category' );
	$score += min( 36, count( array_intersect( (array) $source_cats, (array) $candidate_cats ) ) * 9 );
	return $score;
}

/** Trim generic words from the edges of a generated title phrase. */
function go_verge_internal_link_trim_phrase_edges( $tokens ) {
	$tokens = array_values( array_filter( array_map( 'trim', (array) $tokens ), 'strlen' ) );
	$stop   = go_verge_internal_link_stopwords();
	while ( count( $tokens ) > 1 && in_array( go_verge_internal_link_key( $tokens[0] ), $stop, true ) ) {
		array_shift( $tokens );
	}
	while ( count( $tokens ) > 1 && in_array( go_verge_internal_link_key( $tokens[ count( $tokens ) - 1 ] ), $stop, true ) ) {
		array_pop( $tokens );
	}
	return $tokens;
}

/**
 * Derive only phrases that occur in the source and genuinely describe the
 * destination article. Focus keywords lead; long title fragments are fallback.
 */
function go_verge_internal_link_article_phrases( $candidate_id, $source_plain ) {
	$candidate_id = absint( $candidate_id );
	$pool         = array();
	$push         = static function ( &$items, $phrase, $score ) use ( $source_plain ) {
		$phrase = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( html_entity_decode( (string) $phrase, ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) ) ) );
		if ( ! go_verge_internal_link_phrase_is_safe( $phrase, false ) || ! go_verge_internal_link_phrase_exists( $source_plain, $phrase ) ) {
			return;
		}
		$key = go_verge_internal_link_key( $phrase );
		if ( ! isset( $items[ $key ] ) || $score > $items[ $key ]['score'] ) {
			$items[ $key ] = array( 'label' => $phrase, 'score' => (int) $score );
		}
	};

	foreach ( array( 'rank_math_focus_keyword', '_rank_math_focus_keyword', '_yoast_wpseo_focuskw', '_seopress_analysis_target_kw' ) as $meta_key ) {
		$value = trim( (string) get_post_meta( $candidate_id, $meta_key, true ) );
		if ( '' === $value ) {
			continue;
		}
		foreach ( preg_split( '/[,;\n]+/u', $value, -1, PREG_SPLIT_NO_EMPTY ) as $keyword ) {
			$push( $pool, $keyword, 220 + min( 40, mb_strlen( trim( $keyword ), 'UTF-8' ) ) );
		}
	}

	$title_sources = array( get_the_title( $candidate_id ) );
	foreach ( array( 'rank_math_title', '_rank_math_title', '_yoast_wpseo_title', '_seopress_titles_title' ) as $meta_key ) {
		$value = trim( (string) get_post_meta( $candidate_id, $meta_key, true ) );
		if ( '' !== $value ) {
			$value = preg_replace( '/%[^%]+%/u', ' ', $value );
			$title_sources[] = $value;
		}
	}

	foreach ( $title_sources as $title ) {
		$title = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( html_entity_decode( (string) $title, ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) ) ) );
		if ( '' === $title ) {
			continue;
		}
		$push( $pool, $title, 180 + min( 50, mb_strlen( $title, 'UTF-8' ) ) );
		foreach ( preg_split( '/\s*(?:\||:|;|\?|!)\s*/u', $title, -1, PREG_SPLIT_NO_EMPTY ) as $chunk ) {
			$push( $pool, $chunk, 170 + min( 45, mb_strlen( trim( $chunk ), 'UTF-8' ) ) );
		}

		$tokens = preg_split( '/\s+/u', $title, -1, PREG_SPLIT_NO_EMPTY );
		$count  = count( $tokens );
		for ( $size = min( 7, $count ); $size >= 2; $size-- ) {
			for ( $start = 0; $start + $size <= $count; $start++ ) {
				$slice = go_verge_internal_link_trim_phrase_edges( array_slice( $tokens, $start, $size ) );
				if ( count( $slice ) < 2 ) {
					continue;
				}
				$phrase = trim( implode( ' ', $slice ), " \t\n\r\0\x0B,.;:!?()[]{}\"" );
				$push( $pool, $phrase, 95 + count( $slice ) * 18 + min( 30, mb_strlen( $phrase, 'UTF-8' ) ) );
			}
		}
	}

	uasort( $pool, static function ( $a, $b ) { return $b['score'] <=> $a['score']; } );
	return array_slice( array_values( $pool ), 0, 3 );
}

/** Add/replace one candidate without allowing a weaker destination to steal an anchor. */
function go_verge_internal_link_add_candidate( &$pool, $label, $url, $priority, $type = 'hub' ) {
	$label = trim( wp_strip_all_tags( (string) $label ) );
	$url   = esc_url_raw( (string) $url );
	if ( ! $url || ! go_verge_internal_link_phrase_is_safe( $label, 'hub' === $type ) ) {
		return;
	}
	$key = go_verge_internal_link_key( $label );
	if ( '' === $key ) {
		return;
	}
	if ( ! isset( $pool[ $key ] ) || (int) $priority > (int) $pool[ $key ]['priority'] ) {
		$pool[ $key ] = array(
			'label'    => $label,
			'url'      => $url,
			'priority' => (int) $priority,
			'type'     => sanitize_key( $type ),
		);
	}
}

/**
 * Add a restrained number of server-rendered contextual links to editorial copy.
 *
 * New and historical posts use the same graph at render time. Exact game/entity
 * hubs lead, followed by genuinely related stories whose focus/title phrases
 * are already present in the source copy. Manual links always win.
 */
/**
 * Build the ranked internal-link candidates for one article (uncached).
 *
 * @param int                 $post_id  Source post.
 * @param string              $plain    Plain text of the rendered article.
 * @param array<string,bool>  $existing URLs already linked in the article.
 * @return array<int,array<string,mixed>>
 */
function go_verge_internal_link_build_candidates( $post_id, $plain, $existing ) {
	$candidates = array();

	/* V46: lead with the canonical subject and the small, curated subject row.
	 * Exact phrases still have to exist naturally in the prose before a link is
	 * inserted, so this strengthens the knowledge graph without keyword stuffing. */
	if ( function_exists( 'go_verge_v46_primary_subject' ) ) {
		$primary_subject = go_verge_v46_primary_subject( $post_id );
		if ( $primary_subject && ! empty( $primary_subject['name'] ) && ! empty( $primary_subject['url'] ) ) {
			go_verge_internal_link_add_candidate( $candidates, $primary_subject['name'], $primary_subject['url'], 1400, 'hub' );
		}
	}
	if ( function_exists( 'go_verge_v7_story_topic_chips' ) ) {
		$role_priorities = array( 'primary'=>1380, 'work'=>1180, 'entity'=>1080, 'topic'=>760, 'context'=>540, 'related'=>620 );
		foreach ( go_verge_v7_story_topic_chips( $post_id, 6 ) as $chip ) {
			$role = sanitize_key( (string) ( $chip['role'] ?? 'related' ) );
			go_verge_internal_link_add_candidate(
				$candidates,
				$chip['label'] ?? '',
				$chip['url'] ?? '',
				$role_priorities[ $role ] ?? 620,
				'context' === $role ? 'context' : 'hub'
			);
		}
	}

	/* Lists and rankings often mention several durable works that are not the
	 * article's single primary subject. V48 promotes only first-class catalogue
	 * objects actually named in item headings, so the first natural occurrence
	 * can link to the canonical hub without turning the article into a tag cloud. */
	if ( function_exists( 'go_verge_v48_list_ranking_topics' ) ) {
		foreach ( go_verge_v48_list_ranking_topics( $post_id, 6 ) as $chip ) {
			go_verge_internal_link_add_candidate(
				$candidates,
				$chip['label'] ?? '',
				$chip['url'] ?? '',
				1120,
				'hub'
			);
		}
	}

	$game_id = go_verge_internal_link_game_id( $post_id );
	if ( $game_id && 'publish' === get_post_status( $game_id ) ) {
		go_verge_internal_link_add_candidate( $candidates, get_the_title( $game_id ), get_permalink( $game_id ), 1000, 'hub' );
		if ( function_exists( 'go_verge_game_intelligence_aliases' ) ) {
			foreach ( go_verge_game_intelligence_aliases( $game_id ) as $alias ) {
				go_verge_internal_link_add_candidate( $candidates, $alias, get_permalink( $game_id ), 980, 'hub' );
			}
		}
	}

	if ( function_exists( 'go_verge_product_subject_reference' ) ) {
		$reference = (string) go_verge_product_subject_reference( $post_id );
		if ( preg_match( '/^go_entity:(\d+)$/', $reference, $match ) ) {
			$entity_id = absint( $match[1] );
			if ( $entity_id && 'publish' === get_post_status( $entity_id ) ) {
				go_verge_internal_link_add_candidate( $candidates, get_the_title( $entity_id ), get_permalink( $entity_id ), 900, 'hub' );
			}
		}
	}

	foreach ( go_verge_internal_link_related_article_ids( $post_id ) as $candidate_id ) {
		if ( $candidate_id === $post_id || 'publish' !== get_post_status( $candidate_id ) ) {
			continue;
		}
		$url = get_permalink( $candidate_id );
		if ( ! $url || isset( $existing[ untrailingslashit( $url ) ] ) ) {
			continue;
		}
		$relation = go_verge_internal_link_article_relation_score( $post_id, $candidate_id );
		if ( $relation < 18 ) {
			continue;
		}
		foreach ( go_verge_internal_link_article_phrases( $candidate_id, $plain ) as $phrase ) {
			go_verge_internal_link_add_candidate( $candidates, $phrase['label'], $url, 180 + $relation + (int) $phrase['score'], 'article' );
		}
	}

	$tags = get_the_tags( $post_id );
	if ( $tags && ! is_wp_error( $tags ) ) {
		foreach ( $tags as $tag ) {
			$destination = function_exists( 'go_verge_tag_preferred_destination' ) ? go_verge_tag_preferred_destination( $tag ) : null;
			$type        = $destination && ! empty( $destination['type'] ) ? $destination['type'] : 'taxonomy';
			if ( 'hub' !== $type && (int) $tag->count < 3 ) {
				continue;
			}
			if ( function_exists( 'go_verge_search_is_broad_topic' ) && go_verge_search_is_broad_topic( $tag->name ) ) {
				continue;
			}
			if ( function_exists( 'go_verge_search_autolink_tag_is_supported' ) && ! go_verge_search_autolink_tag_is_supported( $post_id, $tag->name ) ) {
				continue;
			}
			$url = $destination && ! empty( $destination['url'] ) ? $destination['url'] : get_tag_link( $tag );
			if ( ! is_wp_error( $url ) ) {
				$priority = 'hub' === $type ? 860 : 120 + min( 60, (int) $tag->count );
				go_verge_internal_link_add_candidate( $candidates, $tag->name, $url, $priority, $type );
			}
		}
	}

	if ( empty( $candidates ) ) {
		return array();
	}

	// Ignore destinations already linked manually or by legacy content.
	$candidates = array_values( array_filter( $candidates, static function ( $candidate ) use ( $existing ) {
		return empty( $existing[ untrailingslashit( $candidate['url'] ) ] );
	} ) );
	usort( $candidates, static function ( $a, $b ) {
		if ( (int) $a['priority'] === (int) $b['priority'] ) {
			return mb_strlen( $b['label'], 'UTF-8' ) <=> mb_strlen( $a['label'], 'UTF-8' );
		}
		return (int) $b['priority'] <=> (int) $a['priority'];
	} );
	$candidates = array_slice( $candidates, 0, 28 );
	return $candidates;
}

function go_verge_intelligent_internal_links( $content, $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id || ! is_string( $content ) || '' === trim( $content ) ) {
		return $content;
	}

	$plain = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( strip_shortcodes( $content ) ) ) );
	$words = str_word_count( remove_accents( $plain ) );
	if ( $words < 220 ) {
		return $content;
	}

	$current_url = get_permalink( $post_id );
	$existing    = go_verge_internal_link_existing_urls( $content );
	if ( $current_url ) {
		$existing[ untrailingslashit( $current_url ) ] = true;
	}
	/*
	 * Candidate generation scores up to 18 related stories and scans the article
	 * text once per title n-gram: ~600 ms of CPU per uncached article view in the
	 * lab. The result depends only on the prose and the links already present,
	 * so it is cached per post (one transient per post, overwritten when the text
	 * changes) and refreshed at most every 12 hours for newly related stories.
	 */
	$cache_key   = 'go_il_c_' . $post_id;
	$fingerprint = md5( $plain . '|' . implode( '|', array_keys( $existing ) ) );
	$cached      = get_transient( $cache_key );
	if ( is_array( $cached ) && isset( $cached['f'], $cached['c'] ) && $cached['f'] === $fingerprint && is_array( $cached['c'] ) ) {
		$candidates = $cached['c'];
	} else {
		$candidates = go_verge_internal_link_build_candidates( $post_id, $plain, $existing );
		set_transient( $cache_key, array( 'f' => $fingerprint, 'c' => $candidates ), 12 * HOUR_IN_SECONDS );
	}
	if ( empty( $candidates ) ) {
		return $content;
	}

	$max_links = 1;
	if ( $words >= 550 ) {
		$max_links = 2;
	}
	if ( $words >= 950 ) {
		$max_links = 3;
	}
	if ( $words >= 1600 ) {
		$max_links = 4;
	}

	$linked_urls       = $existing;
	$linked_labels     = array();
	$paragraph         = 0;
	$last_link_paragraph = -99;

	return preg_replace_callback(
		'/<p\b([^>]*)>(.*?)<\/p>/isu',
		static function ( $match ) use ( &$paragraph, &$linked_urls, &$linked_labels, &$last_link_paragraph, $candidates, $max_links ) {
			++$paragraph;
			if ( $paragraph < 3 || count( $linked_labels ) >= $max_links || $paragraph - $last_link_paragraph < 2 ) {
				return $match[0];
			}
			$inner = (string) $match[2];
			if ( false !== stripos( $inner, '<a ' ) || preg_match( '/<(?:code|pre|button|iframe|script|style|form|figure|figcaption|ins|video|audio)\b/i', $inner ) ) {
				return $match[0];
			}
			if ( preg_match( '/go-(?:inline-related|context-block|newsletter|toc|review|poll|quiz|compare|prediction|gallery|video)/i', $inner ) ) {
				return $match[0];
			}

			foreach ( $candidates as $candidate ) {
				$key     = go_verge_internal_link_key( $candidate['label'] );
				$url_key = untrailingslashit( $candidate['url'] );
				if ( isset( $linked_labels[ $key ] ) || isset( $linked_urls[ $url_key ] ) ) {
					continue;
				}
				$pattern = go_verge_internal_link_phrase_pattern( $candidate['label'] );
				if ( ! $pattern ) {
					continue;
				}

				$parts   = preg_split( '/(<[^>]+>)/u', $inner, -1, PREG_SPLIT_DELIM_CAPTURE );
				$changed = false;
				foreach ( $parts as &$part ) {
					if ( $changed || '' === $part || '<' === substr( $part, 0, 1 ) ) {
						continue;
					}
					$replacement = '<a class="go-auto-internal-link" data-go-auto-link="' . esc_attr( $candidate['type'] ) . '" href="' . esc_url( $candidate['url'] ) . '">$1</a>';
					$part = preg_replace( $pattern, $replacement, $part, 1, $count );
					if ( $count ) {
						$changed = true;
					}
				}
				unset( $part );
				if ( $changed ) {
					$linked_labels[ $key ] = true;
					$linked_urls[ $url_key ] = true;
					$last_link_paragraph = $paragraph;
					return '<p' . $match[1] . '>' . implode( '', $parts ) . '</p>';
				}
			}
			return $match[0];
		},
		$content
	);
}


/**
 * Protected blocks from the active manual planner, with original byte offsets.
 *
 * The former semantic-map helpers no longer ship with this theme. Reuse the
 * current scanner instead of silently allowing every break. This request-local
 * cache serves the channel, sharing and recommendation helpers without parsing
 * the same article again for each candidate.
 *
 * Lists, quotes and tables stay indivisible for UI insertion even when their
 * editorial words count toward the ad planner's article capacity. Script/style/
 * template siblings have no visible surface and do not create a new UI barrier.
 * A hidden block protects its interior but not a neighbouring visible break.
 *
 * @return array<int,array{0:int,1:int,2:bool}> Start, end and visible-UI flag.
 */
function go_verge_content_protected_intervals( $content ) {
	static $cached_content = null;
	static $cached_intervals = array();

	$content = (string) $content;
	if ( $cached_content === $content ) {
		return $cached_intervals;
	}
	$cached_content   = $content;
	$cached_intervals = array();
	$blocks = function_exists( 'go_verge_ads_planner_blocks' ) ? go_verge_ads_planner_blocks( $content ) : array();
	if ( ! $blocks ) {
		/* Malformed or unavailable structure cannot provide a trusted insertion
		 * boundary. This never removes an ad or edits the article. */
		if ( '' !== trim( $content ) ) {
			$cached_intervals[] = array( 0, strlen( $content ), true );
		}
		return $cached_intervals;
	}
	foreach ( $blocks as $block ) {
		if ( in_array( $block['kind'], array( 'prose', 'heading' ), true )
			|| in_array( $block['tag'], array( 'script', 'style', 'template' ), true ) ) {
			continue;
		}
		$cached_intervals[] = array( (int) $block['start'], (int) $block['end'], (int) $block['height'] > 0 );
	}
	return $cached_intervals;
}

/** Count visible editorial clearance; hidden component text buys no spacing. */
function go_verge_content_clearance_words( $content, $start, $end ) {
	if ( ! function_exists( 'go_verge_ads_word_count' ) ) {
		return 0;
	}
	$cursor = (int) $start;
	$words  = 0;
	foreach ( go_verge_content_protected_intervals( $content ) as $interval ) {
		if ( $interval[2] || $interval[1] <= $cursor || $interval[0] >= $end ) {
			continue;
		}
		$hidden_start = max( $cursor, $interval[0] );
		$words += go_verge_ads_word_count( substr( $content, $cursor, $hidden_start - $cursor ) );
		$cursor = min( $end, $interval[1] );
	}
	return $words + go_verge_ads_word_count( substr( $content, $cursor, $end - $cursor ) );
}

/** Whether an offset lies inside a protected block, rather than at its edge. */
function go_verge_content_offset_is_protected( $content, $offset ) {
	$content = (string) $content;
	$offset  = max( 0, min( strlen( $content ), (int) $offset ) );
	foreach ( go_verge_content_protected_intervals( $content ) as $interval ) {
		if ( $interval[0] >= $offset ) {
			break;
		}
		if ( $offset < $interval[1] ) {
			return true;
		}
	}
	return false;
}

/**
 * Measure protected UI proximity using editorial words, never HTML byte size.
 *
 * These are the theme's existing clearance choices, not Google policy limits.
 * The caller may try another valid break; this helper never moves/removes an ad.
 * Script/template contents and markup-heavy cards cannot manufacture clearance.
 *
 * @param string $content      Rendered article HTML.
 * @param int    $position     Byte offset of the proposed break.
 * @param int    $before_words Minimum editorial words after the previous protected block.
 * @param int    $after_words  Minimum editorial words before the next protected block.
 * @return bool True when the break is inside or too close to protected UI.
 */
function go_verge_ads_break_near_protected_ui( $content, $position, $before_words = 20, $after_words = 14 ) {
	$content  = (string) $content;
	$position = max( 0, min( strlen( $content ), (int) $position ) );
	$previous_end = null;
	$next_start   = null;

	foreach ( go_verge_content_protected_intervals( $content ) as $interval ) {
		if ( $interval[0] < $position && $position < $interval[1] ) {
			return true;
		}
		if ( ! $interval[2] ) {
			continue;
		}
		if ( $interval[1] <= $position ) {
			$previous_end = $interval[1];
		} elseif ( $interval[0] >= $position ) {
			$next_start = $interval[0];
			break;
		}
	}

	if ( null !== $previous_end ) {
		$words = go_verge_content_clearance_words( $content, $previous_end, $position );
		if ( 0 === $words || $words < max( 0, (int) $before_words ) ) {
			return true;
		}
	}
	if ( null !== $next_start ) {
		$words = go_verge_content_clearance_words( $content, $position, $next_start );
		if ( 0 === $words || $words < max( 0, (int) $after_words ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Return paragraph endings that are safe for recommendations and ads.
 * A break must be in prose and at least two paragraphs into its current
 * section, which prevents a unit from appearing immediately after H2/H3/H4.
 * The next heading is protected too, so ads and recommendations never sandwich
 * a section title. Media, tables, lists, quotes, FAQs and interactives remain
 * protected in both directions.
 */
function go_verge_content_safe_paragraph_breaks( $content, $minimum_text = 80 ) {
	$content = (string) $content;
	if ( '' === trim( $content ) || ! preg_match_all( '/<p\b[^>]*>.*?<\/p>/isu', $content, $paragraphs, PREG_OFFSET_CAPTURE ) ) { return array(); }
	$breaks = array();
	foreach ( $paragraphs[0] as $index => $match ) {
		$html  = (string) $match[0];
		$start = (int) $match[1];
		$end   = $start + strlen( $html );
		$text  = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $html ) ) );
		if ( mb_strlen( $text ) < $minimum_text ) { continue; }
		if ( preg_match( '/<(?:img|picture|figure|iframe|video|audio|table|ul|ol|blockquote|details|script|style|ins|form|button|pre|code)\b|go-(?:inline-related|context-block|interactive|poll|quiz|compare|prediction|gallery|video|newsletter|toc|review)|rank-math-faq|schema-faq/i', $html ) ) { continue; }
		if ( go_verge_content_offset_is_protected( $content, $end ) ) { continue; }

		$before = substr( $content, 0, $start );
		$last_heading = -1;
		if ( preg_match_all( '/<h[2-4]\b[^>]*>.*?<\/h[2-4]>/isu', $before, $heads, PREG_OFFSET_CAPTURE ) && ! empty( $heads[0] ) ) {
			$last = end( $heads[0] );
			$last_heading = (int) $last[1] + strlen( $last[0] );
		}
		$section_slice = substr( $content, max( 0, $last_heading ), $end - max( 0, $last_heading ) );
		if ( substr_count( strtolower( $section_slice ), '</p>' ) < 2 ) { continue; }

		$next = ltrim( substr( $content, $end, 700 ) );
		if ( preg_match( '/^<(?:h[2-4]|figure|table|ul|ol|blockquote|details|iframe|video|audio|aside)\b/i', $next ) ) { continue; }

		/* Semantic distance: never let thousands of markup bytes in an editorial
		 * card erase otherwise valid prose breaks. */
		if ( function_exists( 'go_verge_ads_break_near_protected_ui' ) && go_verge_ads_break_near_protected_ui( $content, $end, 20, 14 ) ) { continue; }
		$breaks[] = array( 'position' => $end, 'paragraph' => $index + 1, 'text_length' => mb_strlen( $text ) );
	}
	return $breaks;
}

/** Move the one Leia também block to the safest editorial pause. */
function go_verge_reposition_inline_related( $content ) {
	$content = (string) $content;

	if ( ! preg_match( '~<aside\b[^>]*class=["\'][^"\']*go-inline-related[^"\']*["\'][^>]*>.*?<\/aside>~isu', $content, $match ) ) {
		return $content;
	}

	$related = $match[0];
	$content = preg_replace(
		'~\s*<aside\b[^>]*class=["\'][^"\']*go-inline-related[^"\']*["\'][^>]*>.*?<\/aside>\s*~isu',
		"\n",
		$content
	);

	$related = preg_replace(
		'~\s*<span\b[^>]*class=["\'][^"\']*go-inline-related__arrow[^"\']*["\'][^>]*>.*?<\/span>\s*~isu',
		'',
		$related
	);
	$related = preg_replace(
		'~aria-label=(["\']).*?\1~isu',
		'aria-label="' . esc_attr__( 'Leia também', 'go-verge' ) . '"',
		$related,
		1
	);
	$related = preg_replace(
		'~(<p\b[^>]*class=["\'][^"\']*go-inline-related__title[^"\']*["\'][^>]*>).*?(</p>)~isu',
		'$1' . esc_html__( 'Leia também', 'go-verge' ) . '$2',
		$related,
		1
	);

	if ( false === strpos( $related, 'go-inline-related--primary' ) ) {
		$related = preg_replace(
			'~class=(["\'])([^"\']*go-inline-related[^"\']*)\1~i',
			'class="$2 go-inline-related--primary"',
			$related,
			1
		);
	}
	if ( false === strpos( $related, 'data-go-related-block=' ) ) {
		$related = preg_replace(
			'~<aside\b~i',
			'<aside data-go-related-block="related"',
			$related,
			1
		);
	}

	$breaks = go_verge_content_safe_paragraph_breaks( $content, 75 );
	if ( empty( $breaks ) ) {
		return $content;
	}

	$length        = strlen( $content );
	$goal          = $length * .37;
	$best          = null;
	$best_distance = PHP_INT_MAX;

	foreach ( $breaks as $break ) {
		$position = (int) $break['position'];
		if ( (int) $break['paragraph'] < 4 ) {
			continue;
		}

		$near = substr( $content, max( 0, $position - 420 ), 840 );
		$next = ltrim( substr( $content, $position, 520 ) );

		if (
			preg_match( '/<h[2-4]\b|data-go-ad-placement|data-go-ad-break|go-smart-ad|adsbygoogle|google-auto-placed|go-faq|rank-math-faq/i', $near )
			|| preg_match( '/^<(?:h[2-4]|figure|table|ul|ol|blockquote|details|iframe|video|audio|aside)\b/i', $next )
		) {
			continue;
		}

		$distance = abs( $position - $goal );
		if ( $distance < $best_distance ) {
			$best          = $break;
			$best_distance = $distance;
		}
	}

	if ( null === $best ) {
		$best = $breaks[ min( count( $breaks ) - 1, 2 ) ];
	}

	return substr( $content, 0, (int) $best['position'] ) . "\n" . $related . "\n" . substr( $content, (int) $best['position'] );
}

/** Insert one contextual recommendation, then normalize its final position. */
function go_verge_inject_inline_related( $content, $post_id = null, $after_paragraph = 7, $min_paragraphs = 9 ) {
	unset( $after_paragraph, $min_paragraphs );

	$content = (string) $content;
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();

	if ( '' === trim( $content ) || ! $post_id ) {
		return $content;
	}

	if (
		false !== strpos( $content, 'go-inline-related' )
		|| false !== strpos( $content, 'go-context-block--related' )
		|| go_verge_content_has_read_also( $content )
	) {
		$content = go_verge_reposition_inline_related( $content );
	} else {
		$primary = go_verge_inline_related_markup( $post_id, 'related' );
		if ( '' !== $primary ) {
			$content = $content . "\n" . $primary;
			$content = go_verge_reposition_inline_related( $content );
		}
	}

	if ( false === strpos( $content, 'data-go-related-block="related"' ) ) {
		return $content;
	}

	$words = str_word_count(
		remove_accents(
			trim(
				wp_strip_all_tags( $content )
			)
		)
	);

	if (
		$words < 1200
		|| false !== strpos( $content, 'data-go-related-block="read-also"' )
	) {
		return $content;
	}

	$exclude_ids = array();
	if ( preg_match_all( '~<aside\b[^>]*class=["\'][^"\']*go-inline-related[^"\']*["\'][^>]*>.*?<\/aside>~isu', $content, $blocks ) ) {
		foreach ( $blocks[0] as $block ) {
			if ( preg_match_all( '~<a\b[^>]*href=["\']([^"\']+)["\']~iu', $block, $links ) ) {
				foreach ( $links[1] as $url ) {
					$linked_id = absint(
						url_to_postid(
							html_entity_decode(
								$url,
								ENT_QUOTES,
								get_bloginfo( 'charset' ) ?: 'UTF-8'
							)
						)
					);
					if ( $linked_id ) {
						$exclude_ids[] = $linked_id;
					}
				}
			}
		}
	}
	$exclude_ids = array_values( array_unique( array_filter( $exclude_ids ) ) );

	$secondary = go_verge_inline_related_markup( $post_id, 'read-also', $exclude_ids );
	if ( '' === $secondary ) {
		return $content;
	}

	$primary_position = strpos( $content, 'data-go-related-block="related"' );
	$breaks           = go_verge_content_safe_paragraph_breaks( $content, 80 );

	if ( false === $primary_position || count( $breaks ) < 8 ) {
		return $content;
	}

	$length        = strlen( $content );
	$goal          = $length * .72;
	$minimum_gap   = max( 2200, (int) floor( $length * .24 ) );
	$best          = null;
	$best_distance = PHP_INT_MAX;

	foreach ( $breaks as $break ) {
		$position = (int) $break['position'];

		if (
			$position <= $primary_position
			|| abs( $position - $primary_position ) < $minimum_gap
			|| (int) $break['paragraph'] < 8
		) {
			continue;
		}

		$near = substr( $content, max( 0, $position - 560 ), 1120 );
		$next = ltrim( substr( $content, $position, 620 ) );

		if (
			preg_match( '/<h[2-4]\b|data-go-ad-placement|data-go-ad-break|go-smart-ad|adsbygoogle|google-auto-placed|go-inline-related|go-context-block|go-faq|rank-math-faq/i', $near )
			|| preg_match( '/^<(?:h[2-4]|figure|table|ul|ol|blockquote|details|iframe|video|audio|aside)\b/i', $next )
		) {
			continue;
		}

		$distance = abs( $position - $goal );
		if ( $distance < $best_distance ) {
			$best          = $break;
			$best_distance = $distance;
		}
	}

	if ( null === $best ) {
		return $content;
	}

	$position = (int) $best['position'];

	return substr( $content, 0, $position ) . "\n" . $secondary . "\n" . substr( $content, $position );
}

/**
 * Contextual, height-aware sidebar for article singles.
 *
 * The server builds a ranked pool of genuinely related modules. A tiny
 * front-end controller then reveals only as many modules as necessary to
 * accompany the real article height. This avoids both outcomes that hurt the
 * reading experience: a generic sidebar taller than a short story and a
 * nearly empty rail beside a long story.
 */

/**
 * Normalize editorial text for conservative sidebar topic checks.
 * This is intentionally strict: a specific module label is only used when
 * the current article and the stories inside that module actually support it.
 */
function go_verge_sidebar_normalize_text( $text ) {
	$text = html_entity_decode( wp_strip_all_tags( (string) $text ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' );
	$text = remove_accents( strtolower( $text ) );
	$text = preg_replace( '/[^a-z0-9]+/u', ' ', $text );
	return trim( preg_replace( '/\\s+/', ' ', (string) $text ) );
}

/**
 * Build a bounded text sample used only to validate a visible topic label.
 */
function go_verge_sidebar_post_text_sample( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}
	$title   = (string) get_the_title( $post_id );
	$excerpt = (string) get_post_field( 'post_excerpt', $post_id );
	$content = (string) get_post_field( 'post_content', $post_id );
	$content = wp_strip_all_tags( strip_shortcodes( $content ) );
	$content = function_exists( 'mb_substr' ) ? mb_substr( $content, 0, 4500 ) : substr( $content, 0, 4500 );
	return go_verge_sidebar_normalize_text( $title . ' ' . $excerpt . ' ' . $content );
}

/**
 * Significant words from a term. Generic connective words do not count as
 * evidence that a story is actually about that subject.
 */
function go_verge_sidebar_term_tokens( $term_name ) {
	$normalized = go_verge_sidebar_normalize_text( $term_name );
	if ( '' === $normalized ) {
		return array();
	}
	$stop = array(
		'a','o','as','os','de','da','do','das','dos','e','em','no','na','nos','nas','para','por','com','sem','um','uma','uns','umas',
		'the','a','an','of','and','or','in','on','for','to','with','from',
	);
	$tokens = array_values( array_filter( explode( ' ', $normalized ), static function ( $token ) use ( $stop ) {
		return strlen( $token ) >= 2 && ! in_array( $token, $stop, true );
	} ) );
	return array_values( array_unique( $tokens ) );
}

/**
 * Does the article text itself support a specific tag label?
 *
 * Merely having a tag is not enough. This prevents a mistagged or overly broad
 * term from becoming a factual-looking heading such as "Guias de jogos grátis".
 */
function go_verge_sidebar_term_supported_by_post( $term, $post_id ) {
	if ( ! $term instanceof WP_Term || ! $post_id ) {
		return false;
	}
	if ( ! has_term( (int) $term->term_id, $term->taxonomy, $post_id ) ) {
		return false;
	}

	$sample = go_verge_sidebar_post_text_sample( $post_id );
	$phrase = go_verge_sidebar_normalize_text( $term->name );
	if ( '' === $sample || '' === $phrase ) {
		return false;
	}

	if ( false !== strpos( ' ' . $sample . ' ', ' ' . $phrase . ' ' ) ) {
		return true;
	}

	$tokens = go_verge_sidebar_term_tokens( $term->name );
	if ( empty( $tokens ) ) {
		return false;
	}

	// Conservative fallback for inflected/compound phrasing: every meaningful
	// token must occur as a whole word in the article sample.
	foreach ( $tokens as $token ) {
		if ( ! preg_match( '/(?:^|\\s)' . preg_quote( $token, '/' ) . '(?:$|\\s)/', $sample ) ) {
			return false;
		}
	}
	return true;
}

/**
 * Pick a reliable tag to name sidebar modules. Popularity is deliberately not
 * the primary signal; textual support and specificity are.
 */
function go_verge_sidebar_reliable_tags( $post_id, $limit = 4 ) {
	$post_id = absint( $post_id );
	$tags    = wp_get_post_terms( $post_id, 'post_tag' );
	if ( ! $post_id || empty( $tags ) || is_wp_error( $tags ) ) {
		return array();
	}

	$sample = go_verge_sidebar_post_text_sample( $post_id );
	$title  = go_verge_sidebar_normalize_text( get_the_title( $post_id ) );
	$generic = array( 'games','game','jogos','jogo','noticias','noticia','entretenimento','tecnologia','guias','guia','reviews','review','criticas','critica' );
	$scored = array();

	foreach ( $tags as $tag ) {
		if ( ! $tag instanceof WP_Term || (int) $tag->count < 2 ) {
			continue;
		}
		if ( function_exists( 'go_verge_is_ai_tag' ) && go_verge_is_ai_tag( $tag ) && ! go_verge_post_is_about_ai( $post_id ) ) {
			continue;
		}
		if ( ! go_verge_sidebar_term_supported_by_post( $tag, $post_id ) ) {
			continue;
		}

		$phrase = go_verge_sidebar_normalize_text( $tag->name );
		$tokens = go_verge_sidebar_term_tokens( $tag->name );
		$score  = 0;
		if ( '' !== $phrase && false !== strpos( ' ' . $title . ' ', ' ' . $phrase . ' ' ) ) {
			$score += 120;
		} elseif ( '' !== $phrase && false !== strpos( ' ' . $sample . ' ', ' ' . $phrase . ' ' ) ) {
			$score += 80;
		} else {
			$score += 45;
		}
		$score += min( 30, count( $tokens ) * 8 );
		$score += min( 20, max( 0, 20 - (int) floor( log( max( 2, (int) $tag->count ), 2 ) * 3 ) ) );
		if ( in_array( $phrase, $generic, true ) ) {
			$score -= 80;
		}
		$scored[ (int) $tag->term_id ] = array( 'term' => $tag, 'score' => $score );
	}

	uasort( $scored, static function ( $a, $b ) {
		if ( $a['score'] === $b['score'] ) {
			return (int) $a['term']->count <=> (int) $b['term']->count;
		}
		return $b['score'] <=> $a['score'];
	} );

	return array_slice( array_values( array_map( static function ( $row ) { return $row['term']; }, $scored ) ), 0, max( 1, (int) $limit ) );
}

/**
 * Check a post against a named context. Used both for selection and for a
 * final fail-safe before a specific heading is printed.
 */
function go_verge_sidebar_post_matches_context( $candidate_id, $context ) {
	$candidate_id = absint( $candidate_id );
	if ( ! $candidate_id || empty( $context['type'] ) ) {
		return false;
	}

	switch ( $context['type'] ) {
		case 'game':
			$game_id = absint( $context['id'] ?? 0 );
			$candidate_game = absint( get_post_meta( $candidate_id, 'go_linked_game_id', true ) );
			if ( ! $candidate_game ) {
				$candidate_game = absint( get_post_meta( $candidate_id, 'go_review_game_id', true ) );
			}
			return $game_id && $candidate_game === $game_id;

		case 'subject':
			$key   = sanitize_key( (string) ( $context['key'] ?? '' ) );
			$value = (string) ( $context['value'] ?? '' );
			return $key && '' !== $value && 0 === strcasecmp( trim( (string) get_post_meta( $candidate_id, $key, true ) ), trim( $value ) );

		case 'tag':
			$term = $context['term'] ?? null;
			return $term instanceof WP_Term && go_verge_sidebar_term_supported_by_post( $term, $candidate_id );

		case 'category':
			$term = $context['term'] ?? null;
			return $term instanceof WP_Term && has_category( (int) $term->term_id, $candidate_id );
	}

	return false;
}

/**
 * A specific heading is only safe when every story in that module proves the
 * same context. Otherwise the caller must use neutral copy.
 */
function go_verge_sidebar_group_matches_context( $ids, $context ) {
	$ids = array_values( array_filter( array_map( 'absint', (array) $ids ) ) );
	if ( empty( $ids ) ) {
		return false;
	}
	foreach ( $ids as $candidate_id ) {
		if ( ! go_verge_sidebar_post_matches_context( $candidate_id, $context ) ) {
			return false;
		}
	}
	return true;
}

/**
 * Canonical visible labels for editorial taxonomy names, platforms, genres
 * and common tech brands.
 */
function go_verge_editorial_display_label( $label ) {
	$label = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) $label ) ) );
	if ( '' === $label ) {
		return '';
	}

	$normalized = strtolower( remove_accents( $label ) );
	$normalized = preg_replace( '/\s+/u', ' ', trim( (string) $normalized ) );

	$map = array(
		'ps5 pro'            => 'PS5 Pro',
		'ps5'                => 'PS5',
		'ps4'                => 'PS4',
		'ps vr2'             => 'PS VR2',
		'playstation'        => 'PlayStation',
		'xbox series x'      => 'Xbox Series X',
		'xbox series s'      => 'Xbox Series S',
		'xbox one'           => 'Xbox One',
		'xbox'               => 'Xbox',
		'nintendo switch 2'  => 'Nintendo Switch 2',
		'nintendo switch'    => 'Nintendo Switch',
		'nintendo'           => 'Nintendo',
		'switch 2'           => 'Switch 2',
		'steam'              => 'Steam',
		'epic games'         => 'Epic Games',
		'pc'                 => 'PC',
		'ios'                => 'iOS',
		'iphone'             => 'iPhone',
		'ipad'               => 'iPad',
		'macos'              => 'macOS',
		'android'            => 'Android',
		'acao'               => 'Ação',
		'aventura'           => 'Aventura',
		'acao e aventura'    => 'Ação e aventura',
		'rpg'                => 'RPG',
		'mmorpg'             => 'MMORPG',
		'mmo'                => 'MMO',
		'fps'                => 'FPS',
		'tps'                => 'TPS',
		'moba'               => 'MOBA',
		'roguelike'          => 'Roguelike',
		'roguelite'          => 'Roguelite',
		'soulslike'          => 'Soulslike',
		'survival horror'    => 'Survival horror',
		'terror'             => 'Terror',
		'sobrevivencia'      => 'Sobrevivência',
		'estrategia'         => 'Estratégia',
		'simulacao'          => 'Simulação',
		'esporte'            => 'Esporte',
		'esportes'           => 'Esportes',
		'corrida'            => 'Corrida',
		'luta'               => 'Luta',
		'plataforma'         => 'Plataforma',
		'puzzle'             => 'Puzzle',
		'ritmo'              => 'Ritmo',
		'musica'             => 'Música',
		'stealth'            => 'Stealth',
		'mundo aberto'       => 'Mundo aberto',
		'arcade'             => 'Arcade',
		'cooperativo'        => 'Cooperativo',
		'multiplayer'        => 'Multiplayer',
		'single player'      => 'Single player',
		'single-player'      => 'Single-player',
	);

	if ( isset( $map[ $normalized ] ) ) {
		return $map[ $normalized ];
	}

	$label = function_exists( 'mb_convert_case' ) ? mb_convert_case( $label, MB_CASE_TITLE, 'UTF-8' ) : ucwords( strtolower( $label ) );

	// Portuguese connectives stay lowercase mid-phrase: "Tiro em Primeira
	// Pessoa", never "Tiro Em Primeira Pessoa". The first word keeps its capital.
	$label = preg_replace_callback(
		'/(?<=\s)(Da|De|Do|Das|Dos|E|Em|No|Na|Nos|Nas|Ao|Aos|A|O|As|Os|Um|Uma|Para|Por|Com)(?=\s|$)/u',
		static function ( $m ) {
			return function_exists( 'mb_strtolower' ) ? mb_strtolower( $m[1], 'UTF-8' ) : strtolower( $m[1] );
		},
		$label
	);

	$replacements = array(
		'/\bPs5\s+Pro\b/u'          => 'PS5 Pro',
		'/\bPs5\b/u'                 => 'PS5',
		'/\bPs4\b/u'                 => 'PS4',
		'/\bPs\s*Vr\s*2\b/u'        => 'PS VR2',
		'/\bPlaystation\b/u'         => 'PlayStation',
		'/\bXbox\s+Series\s+X\s*(?:[,\/|&+]\s*)?S\b/u' => 'Xbox Series X|S',
		'/\bXbox\s+Series\s+X\b/u' => 'Xbox Series X',
		'/\bXbox\s+Series\s+S\b/u' => 'Xbox Series S',
		'/\bXbox\s+One\b/u'        => 'Xbox One',
		'/\bXbox\b/u'               => 'Xbox',
		'/\bNintendo\s+Switch\s+2\b/u' => 'Nintendo Switch 2',
		'/\bNintendo\s+Switch\b/u' => 'Nintendo Switch',
		'/\bNintendo\b/u'           => 'Nintendo',
		'/\bSwitch\s+2\b/u'        => 'Switch 2',
		'/\bSteam\b/u'              => 'Steam',
		'/\bEpic\s+Games\b/u'       => 'Epic Games',
		'/\bPc\b/u'                 => 'PC',
		'/\bIos\b/u'                => 'iOS',
		'/\bIphone\b/u'             => 'iPhone',
		'/\bIpad\b/u'               => 'iPad',
		'/\bMacos\b/u'              => 'macOS',
		'/\bRpg\b/u'                => 'RPG',
		'/\bMmorpg\b/u'             => 'MMORPG',
		'/\bMmo\b/u'                => 'MMO',
		'/\bFps\b/u'                => 'FPS',
		'/\bTps\b/u'                => 'TPS',
		'/\bMoba\b/u'               => 'MOBA',
		'/\bAcao\b/u'               => 'Ação',
		'/\bAventura\b/u'           => 'Aventura',
		'/\bEstrategia\b/u'         => 'Estratégia',
		'/\bSimulacao\b/u'          => 'Simulação',
		'/\bSobrevivencia\b/u'      => 'Sobrevivência',
		'/\bMusica\b/u'             => 'Música',
	);

	return (string) preg_replace( array_keys( $replacements ), array_values( $replacements ), $label );
}

/**
 * Normalize comma-separated editorial lists such as platforms, genres and
 * modes, preserving brand casing and accentuation.
 */
function go_verge_editorial_display_list( $text ) {
	$text = trim( wp_strip_all_tags( (string) $text ) );
	if ( '' === $text ) {
		return '';
	}

	$segments = array();
	$plain    = strtolower( preg_replace( '/\s+/u', ' ', trim( remove_accents( $text ) ) ) );

	/*
	 * Some imported game records lost their separators altogether, producing
	 * values such as "PCPlayStation 5Xbox Series X, S" and
	 * "RPG de AçãoMundo AbertoFantasia Sombria". Tokenize a value only when
	 * known editorial labels account for the complete string. This repairs the
	 * broken legacy data without splitting legitimate free-form descriptions.
	 */
	$known_label_pattern = '/xbox\s*series\s*x\s*(?:[,\/|&+]\s*)?s|xbox\s*series\s*x|xbox\s*series\s*s|xbox\s*one|xbox\s*360|playstation\s*5|playstation\s*4|playstation|ps5\s*pro|ps5|ps4|ps3|ps\s*vr\s*2|ps\s*vita|nintendo\s*switch\s*2|nintendo\s*switch|switch\s*2|steam\s*deck|epic\s*games|xbox|nintendo|steam|pc|ios|android|iphone|ipad|macos|mac|linux|mobile|rpg\s+de\s+acao|acao\s+e\s+aventura|mundo\s+aberto|fantasia\s+sombria|ficcao\s+cientifica|tiro\s+em\s+primeira\s+pessoa|tiro\s+em\s+terceira\s+pessoa|terror\s+de\s+sobrevivencia|sobrevivencia\s+e\s+terror|estrategia\s+em\s+tempo\s+real|hack\s+and\s+slash|battle\s+royale|metroidvania|soulslike|roguelike|roguelite|mmorpg|moba|rpg|fps|tps|mmo|acao|aventura|terror|sobrevivencia|estrategia|simulacao|corrida|luta|plataforma|puzzle|ritmo|musica|stealth|arcade|cooperativo|multiplayer/u';
	if ( preg_match_all( $known_label_pattern, $plain, $known_matches ) && ! empty( $known_matches[0] ) ) {
		$remainder = preg_replace( $known_label_pattern, '', $plain );
		$remainder = preg_replace( '/[\s,;\|\/·&+_-]+/u', '', (string) $remainder );
		if ( '' === $remainder ) {
			$segments = $known_matches[0];
		}
	}

	if ( empty( $segments ) ) {
		// The punctuation belongs to the official Xbox Series X|S family name,
		// not to the surrounding legacy list. Protect it during generic parsing.
		$text_for_split = preg_replace( '/\bXbox\s+Series\s+X\s*(?:[,\/|&+]\s*)S\b/iu', 'Xbox Series X__GO_PIPE__S', $text );
		$segments       = preg_split( '/\s*[,;\|\/·]+\s*/u', $text_for_split );
		$segments       = array_map( static function ( $segment ) { return str_replace( '__GO_PIPE__', '|', $segment ); }, (array) $segments );
	}

	if ( 1 === count( $segments ) ) {
		if ( preg_match( '/^(acao|aventura|rpg|mmorpg|mmo|fps|tps|moba|terror|sobrevivencia|estrategia|simulacao|corrida|luta|plataforma|puzzle|ritmo|musica|stealth|arcade|cooperativo|multiplayer)(\s+(acao|aventura|rpg|mmorpg|mmo|fps|tps|moba|terror|sobrevivencia|estrategia|simulacao|corrida|luta|plataforma|puzzle|ritmo|musica|stealth|arcade|cooperativo|multiplayer))+$/u', $plain ) ) {
			$segments = preg_split( '/\s+/u', $plain );
		} else {
			// Platforms saved space-separated ("PS5 Xbox PC") otherwise render as
			// one run-on token. Only split when the WHOLE string is consecutive
			// known platform names, so free-form values stay untouched.
			$platform_pattern = '/playstation\s*5|playstation\s*4|playstation|ps5\s+pro|ps5|ps4|ps3|ps\s*vr\s*2|ps\s*vita|xbox\s+series\s+x|xbox\s+series\s+s|xbox\s+one|xbox\s+360|xbox|nintendo\s+switch\s+2|nintendo\s+switch|switch\s+2|switch|steam\s+deck|steam|epic\s+games|pc|ios|android|iphone|ipad|macos|mac|linux|mobile/u';
			if ( preg_match_all( $platform_pattern, $plain, $pm ) && count( $pm[0] ) > 1 ) {
				$joined = preg_replace( '/\s+/u', '', implode( '', $pm[0] ) );
				$whole  = preg_replace( '/\s+/u', '', $plain );
				if ( $joined === $whole ) {
					$segments = $pm[0];
				}
			}
		}
	}

	$segments = array_values( array_filter( array_map( 'trim', (array) $segments ) ) );
	$segments = array_map( 'go_verge_editorial_display_label', $segments );
	$segments = array_values( array_unique( array_filter( $segments ) ) );

	return implode( ', ', $segments );
}

/**
 * Preserve the editorial casing of platforms and common tech brands when a
 * taxonomy term is reused as a visible sidebar heading. Terms such as "ps5"
 * may be stored in lowercase for consistency, but should never be printed
 * that way to readers.
 */
function go_verge_sidebar_display_context_name( $name, $preserve_editorial_case = false ) {
	if ( $preserve_editorial_case && function_exists( 'go_verge_prepare_game_name' ) ) {
		return go_verge_prepare_game_name( $name );
	}
	return go_verge_editorial_display_list( $name );
}

/**
 * Post IDs que o rail do artigo já ofereceu neste request.
 *
 * O rail e os módulos abaixo da matéria ranqueiam do mesmo pool de afinidade, e
 * o rail renderiza primeiro (single.php). Sem esse passe de bastão os melhores
 * candidatos são recomendados duas vezes na mesma página -- uma ao lado do
 * texto, outra embaixo dele.
 */
function go_verge_sidebar_shown_ids( $ids = null ) {
	static $shown = array();
	if ( is_array( $ids ) ) {
		/*
		 * This registry is request-wide: every recirculation surface contributes
		 * to it. Merge instead of replace, otherwise the sidebar (rendered late in
		 * single.php) can erase IDs claimed by the article tail and make the final
		 * rail repeat them again.
		 */
		$shown = array_values( array_unique( array_filter( array_merge(
			$shown,
			array_map( 'absint', $ids )
		) ) ) );
	}
	return $shown;
}

/**
 * Shared recommendation registry for the entire single request.
 *
 * Historically this state lived behind `go_verge_sidebar_shown_ids()` and only
 * the article rail reliably wrote to it. The result was visible duplication:
 * the same three stories could appear in "Continue neste assunto" and again a
 * few pixels later in "Mais de ...". Keep the legacy function as the storage
 * owner for compatibility, but expose the real semantic contract here.
 *
 * @param int[]|null $ids Complete set to remember, or null to read.
 * @return int[]
 */
function go_verge_recirculation_shown_ids( $ids = null ) {
	return go_verge_sidebar_shown_ids( $ids );
}

/**
 * Remember that the subject-specific continuation module rendered for a post.
 * The broader discovery rail can then change intent instead of repeating the
 * same subject immediately underneath it. State is request-local only.
 *
 * @param int       $post_id Post ID.
 * @param bool|null $set     Optional value to store.
 * @return bool
 */
function go_verge_contextual_next_rendered( $post_id, $set = null ) {
	static $rendered = array();
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return false;
	}
	if ( null !== $set ) {
		$rendered[ $post_id ] = (bool) $set;
	}
	return ! empty( $rendered[ $post_id ] );
}

/**
 * Resolve the real editorial vertical for a single article.
 *
 * A saved primary category from the editorial workflow/Rank Math wins when it
 * is still assigned to the post. Legacy articles without an explicit primary
 * are classified from their complete category hierarchy, never from the first
 * category ID returned by WordPress.
 */
function go_verge_article_vertical_bucket( $post_id, $primary = null ) {
	$post_id = absint( $post_id );
	if ( function_exists( 'go_verge_post_editorial_desk' ) ) {
		$map = array( 'games'=>'games', 'entretenimento'=>'entertainment', 'tecnologia'=>'technology', 'ofertas'=>'offers' );
		return $map[ go_verge_post_editorial_desk( $post_id ) ] ?? 'direct';
	}
	if ( ! $post_id || ! function_exists( 'go_verge_offcanvas_category_bucket' ) ) {
		return 'direct';
	}

	$valid_buckets = array( 'games', 'entertainment', 'technology' );

	/* Trust only an explicit primary term that still belongs to this article. */
	foreach ( array( '_go_primary_category_id', 'rank_math_primary_category' ) as $meta_key ) {
		$primary_id = absint( get_post_meta( $post_id, $meta_key, true ) );
		if ( ! $primary_id || ! has_category( $primary_id, $post_id ) ) {
			continue;
		}
		$explicit_primary = get_term( $primary_id, 'category' );
		if ( ! ( $explicit_primary instanceof WP_Term ) ) {
			continue;
		}
		$explicit_bucket = go_verge_offcanvas_category_bucket( $explicit_primary );
		if ( in_array( $explicit_bucket, $valid_buckets, true ) ) {
			return $explicit_bucket;
		}
	}

	$terms = wp_get_post_terms( $post_id, 'category' );
	if ( is_wp_error( $terms ) || empty( $terms ) ) {
		return 'direct';
	}

	$root_ids = array();
	foreach (
		array(
			'games'         => array( 'games', 'jogos' ),
			'entertainment' => array( 'entretenimento', 'entertainment' ),
			'technology'    => array( 'tecnologia', 'technology', 'tech' ),
		) as $bucket => $aliases
	) {
		foreach ( $aliases as $slug ) {
			$root = get_term_by( 'slug', $slug, 'category' );
			if ( $root instanceof WP_Term ) {
				$root_ids[ $bucket ][] = absint( $root->term_id );
			}
		}
	}

	$scores      = array_fill_keys( $valid_buckets, 0 );
	$inferred_id = $primary instanceof WP_Term ? absint( $primary->term_id ) : 0;

	foreach ( $terms as $term ) {
		if ( ! $term instanceof WP_Term ) {
			continue;
		}

		$bucket = go_verge_offcanvas_category_bucket( $term );
		if ( ! isset( $scores[ $bucket ] ) ) {
			continue;
		}

		$ancestors = array_map( 'absint', get_ancestors( $term->term_id, 'category', 'taxonomy' ) );
		$lineage   = array_merge( array( absint( $term->term_id ) ), $ancestors );
		$has_root  = ! empty( array_intersect( $lineage, (array) ( $root_ids[ $bucket ] ?? array() ) ) );

		/* Hierarchical membership outweighs a loose keyword match. */
		$scores[ $bucket ] += $has_root ? ( 20 + count( $ancestors ) ) : 2;
		if ( $inferred_id && absint( $term->term_id ) === $inferred_id ) {
			$scores[ $bucket ] += 1;
		}
	}

	arsort( $scores );
	$bucket = key( $scores );
	return $bucket && current( $scores ) > 0 ? $bucket : 'direct';
}

function go_verge_article_sidebar( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return;
	}

	$primary          = go_verge_get_primary_term( $post_id );
	$raw_content      = (string) get_post_field( 'post_content', $post_id );
	$word_count       = str_word_count( remove_accents( wp_strip_all_tags( $raw_content ) ) );
	$editorial_bucket = go_verge_article_vertical_bucket( $post_id, $primary );
	$tag_ids          = array_map( 'absint', (array) wp_get_post_tags( $post_id, array( 'fields' => 'ids' ) ) );
	$priority_tags    = function_exists( 'go_verge_sidebar_reliable_tags' ) ? go_verge_sidebar_reliable_tags( $post_id, 5 ) : array();
	$used             = array_values( array_unique( array_merge( array( $post_id ), go_verge_recirculation_shown_ids() ) ) );

	if ( $word_count < 450 ) {
		$length = 'compact';
	} elseif ( $word_count < 850 ) {
		$length = 'short';
	} elseif ( $word_count < 1500 ) {
		$length = 'medium';
	} else {
		$length = 'long';
	}

	$review_game = function_exists( 'go_verge_review_game_profile' ) ? go_verge_review_game_profile( $post_id ) : null;
	$linked_game = function_exists( 'go_verge_product_linked_game_id' ) ? absint( go_verge_product_linked_game_id( $post_id ) ) : 0;
	if ( ! $linked_game ) {
		$linked_game = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	}
	if ( ! $linked_game ) {
		$linked_game = absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	}
	if ( empty( $review_game['title'] ) && $linked_game && 'games' === get_post_type( $linked_game ) && 'publish' === get_post_status( $linked_game ) ) {
		$review_game = array(
			'id'    => $linked_game,
			'title' => go_verge_game_name( $linked_game ),
			'url'   => get_permalink( $linked_game ),
		);
	}

	$context_term = ! empty( $priority_tags ) && $priority_tags[0] instanceof WP_Term ? $priority_tags[0] : null;
	$context      = array();
	$context_name = '';

	if ( $linked_game && get_post_status( $linked_game ) ) {
		$context = array(
			'type' => 'game',
			'id'   => $linked_game,
			'name' => get_the_title( $linked_game ),
		);
	} elseif ( $context_term instanceof WP_Term ) {
		$context = array(
			'type' => 'tag',
			'id'   => (int) $context_term->term_id,
			'term' => $context_term,
			'name' => $context_term->name,
		);
	} elseif ( $primary instanceof WP_Term ) {
		$context = array(
			'type' => 'category',
			'id'   => (int) $primary->term_id,
			'term' => $primary,
			'name' => $primary->name,
		);
	}

	$context_name = ! empty( $context['name'] )
		? go_verge_sidebar_display_context_name( $context['name'], 'game' === ( $context['type'] ?? '' ) )
		: '';

	/*
	 * Start with the theme's own editorial relevance score. It already weighs
	 * linked game, technical subject, shared tags/categories and freshness.
	 */
	$ranked_ids = function_exists( 'go_verge_related_post_ids' ) ? go_verge_related_post_ids( $post_id, 24 ) : array();
	$ranked_ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $ranked_ids ) ) ) );

	/* Never cross Games, Entertainment and Technology inside an article rail. */
	if ( in_array( $editorial_bucket, array( 'games', 'entertainment', 'technology', 'offers' ), true ) ) {
		$ranked_ids = array_values( array_filter( $ranked_ids, static function ( $candidate_id ) use ( $editorial_bucket ) {
			return $editorial_bucket === go_verge_article_vertical_bucket( $candidate_id );
		} ) );
	}

	/*
	 * Do not append a raw OR-taxonomy pool here. A shared broad category is
	 * not enough evidence of topical relevance. Exact taxonomy fallbacks are
	 * built later and keep their own factual labels.
	 */

	$category_slugs_for = static function ( $candidate_id ) {
		$terms = wp_get_post_terms( $candidate_id, 'category', array( 'fields' => 'slugs' ) );
		return is_wp_error( $terms ) ? array() : array_map( 'sanitize_title', (array) $terms );
	};
	$is_guide = static function ( $candidate_id ) use ( $category_slugs_for ) {
		if ( function_exists( 'go_verge_single_recommendation_context' ) ) {
			return in_array( go_verge_single_recommendation_context($candidate_id)['type'], array('guia','tutorial'), true );
		}
		$slugs = $category_slugs_for( $candidate_id );
		foreach ( $slugs as $slug ) {
			if ( preg_match( '/(?:guia|guias|dicas|detonado|tutorial|como-fazer)/', $slug ) ) {
				return true;
			}
		}
		return false;
	};
	$is_evaluation = static function ( $candidate_id ) use ( $category_slugs_for ) {
		if ( function_exists( 'go_verge_single_recommendation_context' ) ) {
			return in_array( go_verge_single_recommendation_context($candidate_id)['type'], array('review','critica','comparativo'), true );
		}
		$slugs = $category_slugs_for( $candidate_id );
		foreach ( $slugs as $slug ) {
			if ( preg_match( '/(?:review|reviews|analise|analises|critica|criticas)/', $slug ) ) {
				return true;
			}
		}
		return false;
	};

	$take_ids = static function ( &$pool, &$used_ids, $limit, $predicate = null ) {
		$out = array();
		foreach ( $pool as $key => $candidate_id ) {
			$candidate_id = absint( $candidate_id );
			if ( ! $candidate_id || in_array( $candidate_id, $used_ids, true ) ) {
				continue;
			}
			if ( is_callable( $predicate ) && ! call_user_func( $predicate, $candidate_id ) ) {
				continue;
			}
			$out[]      = $candidate_id;
			$used_ids[] = $candidate_id;
			unset( $pool[ $key ] );
			if ( count( $out ) >= $limit ) {
				break;
			}
		}
		$pool = array_values( $pool );
		return $out;
	};

	$groups     = array();
	$main_limit = 'compact' === $length ? 2 : ( 'long' === $length ? 5 : ( 'medium' === $length ? 4 : 3 ) );

	$context_predicate = ! empty( $context ) ? static function ( $candidate_id ) use ( $context ) {
		return go_verge_sidebar_post_matches_context( $candidate_id, $context );
	} : null;

	/*
	 * Primary module: prefer stories that prove the named context. If there is
	 * not enough evidence, keep the recommendations but use neutral copy.
	 */
	$main_ids = is_callable( $context_predicate ) ? $take_ids( $ranked_ids, $used, $main_limit, $context_predicate ) : array();
	if ( empty( $main_ids ) ) {
		$main_ids = $take_ids( $ranked_ids, $used, $main_limit );
	}
	if ( $main_ids ) {
		$main_specific = $context_name && go_verge_sidebar_group_matches_context( $main_ids, $context );
		if ( $main_specific ) {
			$main_title = ( 'category' === ( $context['type'] ?? '' ) )
				? sprintf( __( 'Mais de %s', 'go-verge' ), $context_name )
				: sprintf( __( 'Mais sobre %s', 'go-verge' ), $context_name );
		} else {
			$main_title = __( 'Conteúdos relacionados', 'go-verge' );
		}
		$groups[] = array(
			'kind'     => 'context',
			'title'    => $main_title,
			'ids'      => $main_ids,
			'optional' => false,
			'context'  => $main_specific ? $context : array(),
			'fallback_title' => __( 'Conteúdos relacionados', 'go-verge' ),
		);
	}

	/* Guides only inherit a named subject when every guide proves it. */
	$guide_context_predicate = ! empty( $context ) ? static function ( $candidate_id ) use ( $is_guide, $context ) {
		return $is_guide( $candidate_id ) && go_verge_sidebar_post_matches_context( $candidate_id, $context );
	} : null;
	$guide_ids = is_callable( $guide_context_predicate ) ? $take_ids( $ranked_ids, $used, 3, $guide_context_predicate ) : array();
	if ( empty( $guide_ids ) ) {
		$guide_ids = $take_ids( $ranked_ids, $used, 3, $is_guide );
	}
	if ( $guide_ids ) {
		$guide_specific = $context_name && go_verge_sidebar_group_matches_context( $guide_ids, $context );
		$groups[] = array(
			'kind'     => 'guides',
			'title'    => $guide_specific ? sprintf( __( 'Guias de %s', 'go-verge' ), $context_name ) : __( 'Guias relacionados', 'go-verge' ),
			'ids'      => $guide_ids,
			'optional' => true,
			'context'  => $guide_specific ? $context : array(),
			'fallback_title' => __( 'Guias relacionados', 'go-verge' ),
		);
	}

	/* Same fail-safe for reviews and criticism. */
	$evaluation_context_predicate = ! empty( $context ) ? static function ( $candidate_id ) use ( $is_evaluation, $context ) {
		return $is_evaluation( $candidate_id ) && go_verge_sidebar_post_matches_context( $candidate_id, $context );
	} : null;
	$evaluation_ids = is_callable( $evaluation_context_predicate ) ? $take_ids( $ranked_ids, $used, 3, $evaluation_context_predicate ) : array();
	if ( empty( $evaluation_ids ) ) {
		$evaluation_ids = $take_ids( $ranked_ids, $used, 3, $is_evaluation );
	}
	if ( $evaluation_ids ) {
		$evaluation_specific = $context_name && go_verge_sidebar_group_matches_context( $evaluation_ids, $context );
		$groups[] = array(
			'kind'     => 'evaluation',
			'title'    => $evaluation_specific ? sprintf( __( 'Review de %s', 'go-verge' ), $context_name ) : __( 'Reviews e críticas relacionadas', 'go-verge' ),
			'ids'      => $evaluation_ids,
			'optional' => true,
			'context'  => $evaluation_specific ? $context : array(),
			'fallback_title' => __( 'Reviews e críticas relacionadas', 'go-verge' ),
		);
	}

	/*
	 * Secondary subject modules use only reliable tags from the current story,
	 * and every candidate must independently support that same tag in its text.
	 */
	/* Secondary-tag shelves were too costly and made the rail look like a tag
	 * archive. The final discovery shelf below already uses the relevance score. */
	foreach ( array() as $secondary_term ) {
		if ( ! $secondary_term instanceof WP_Term ) {
			continue;
		}
		$secondary_query = get_posts(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => 8,
				'post__not_in'        => array_values( array_unique( $used ) ),
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'orderby'             => 'date',
				'order'               => 'DESC',
				'fields'              => 'ids',
				'tag__in'             => array( (int) $secondary_term->term_id ),
			)
		);
		$secondary_query = array_values( array_filter( array_map( 'absint', (array) $secondary_query ), static function ( $candidate_id ) use ( $secondary_term ) {
			return go_verge_sidebar_term_supported_by_post( $secondary_term, $candidate_id );
		} ) );
		if ( $secondary_query ) {
			$secondary_query = array_slice( array_values( array_unique( $secondary_query ) ), 0, 3 );
			$used = array_merge( $used, $secondary_query );
			$secondary_context = array(
				'type' => 'tag',
				'id'   => (int) $secondary_term->term_id,
				'term' => $secondary_term,
				'name' => $secondary_term->name,
			);
			$groups[] = array(
				'kind'     => 'secondary-topic',
				'title'    => sprintf( __( 'Também sobre %s', 'go-verge' ), go_verge_sidebar_display_context_name( $secondary_term->name ) ),
				'ids'      => $secondary_query,
				'optional' => true,
				'context'  => $secondary_context,
				'fallback_title' => __( 'Conteúdos relacionados', 'go-verge' ),
			);
		}
	}

	/* Contextual popularity: exact context only. No site-wide mixed ranking. */
	/* Popularity alone is weaker than editorial affinity for a reading rail.
	 * Keep this legacy query disabled; the ranked pool remains the source. */
	if ( false && ! empty( $context ) ) {
		$trend_args = array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 8,
			'post__not_in'        => array_values( array_unique( $used ) ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'orderby'             => array( 'comment_count' => 'DESC', 'date' => 'DESC' ),
			'fields'              => 'ids',
		);
		switch ( $context['type'] ?? '' ) {
			case 'tag':
				$trend_args['tag__in'] = array( absint( $context['id'] ?? 0 ) );
				break;
			case 'category':
				$trend_args['cat'] = absint( $context['id'] ?? 0 );
				break;
			case 'game':
				$trend_args['meta_query'] = array(
					'relation' => 'OR',
					array( 'key' => 'go_linked_game_id', 'value' => absint( $context['id'] ?? 0 ), 'compare' => '=' ),
					array( 'key' => 'go_review_game_id', 'value' => absint( $context['id'] ?? 0 ), 'compare' => '=' ),
				);
				break;
		}
		$trend_ids = array_values( array_filter( array_map( 'absint', (array) get_posts( $trend_args ) ), static function ( $candidate_id ) use ( $context ) {
			return go_verge_sidebar_post_matches_context( $candidate_id, $context );
		} ) );
		$trend_ids = array_slice( array_values( array_unique( $trend_ids ) ), 0, 4 );
		if ( $trend_ids && go_verge_sidebar_group_matches_context( $trend_ids, $context ) ) {
			$used = array_merge( $used, $trend_ids );
			$groups[] = array(
				'kind'     => 'trending',
				'title'    => sprintf( __( 'Em alta em %s', 'go-verge' ), $context_name ),
				'ids'      => $trend_ids,
				'optional' => true,
				'context'  => $context,
				'fallback_title' => __( 'Em alta neste assunto', 'go-verge' ),
			);
		}
	}

	/*
	 * Exact primary-category fallback. The heading describes the query itself,
	 * so it cannot claim a narrower subject than the stories actually share.
	 */
	if ( $primary instanceof WP_Term ) {
		$latest_ids = get_posts(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => 4,
				'post__not_in'        => array_values( array_unique( $used ) ),
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'orderby'             => 'date',
				'order'               => 'DESC',
				'fields'              => 'ids',
				'cat'                 => (int) $primary->term_id,
			)
		);
		$latest_ids = array_slice( array_values( array_unique( array_filter( array_map( 'absint', (array) $latest_ids ) ) ) ), 0, 4 );
		if ( $latest_ids ) {
			$used = array_merge( $used, $latest_ids );
			$groups[] = array(
				'kind'     => 'latest-category',
				'title'    => __( 'Últimas da mesma editoria', 'go-verge' ),
				'ids'      => $latest_ids,
				'optional' => true,
			);
		}
	}

	/* Remaining ranked stories may fill space, but never receive a fake topic. */
	$more_ids = $take_ids( $ranked_ids, $used, 4 );
	if ( $more_ids ) {
		$groups[] = array(
			'kind'     => 'more-context',
			'title'    => __( 'Mais para ler', 'go-verge' ),
			'ids'      => $more_ids,
			'optional' => true,
		);
	}

	/*
	 * The old flat cap of four stories existed because the WHOLE rail used to be
	 * sticky: anything past the first viewport was unreachable, so more links
	 * would simply never be seen. The rail now scrolls normally and only the ad
	 * follows the reader, which removes that ceiling.
	 *
	 * The budget therefore scales with the article. A 3000-word feature has a
	 * column several thousand pixels tall; offering four links there wastes the
	 * best continue-reading surface on the site. It is still bounded by length,
	 * so a short post never grows a rail taller than its own text.
	 *
	 * The ceiling is deliberately below what would fill the column. The sticky
	 * unit closes the rail, and it can only follow the reader across the free
	 * space beneath the last module — measured viewability collapsed when the
	 * modules grew tall enough to leave no runway. Roughly two thirds content,
	 * one third runway keeps both the links and the impression working.
	 */
	$story_budget = array(
		'compact' => 4,
		'short'   => 5,
		'medium'  => 6,
		'long'    => 8,
	);
	$story_budget = $story_budget[ $length ];
	$main_group   = null;
	$utility_ids  = array();
	$discovery_ids = array();

	foreach ( $groups as $candidate_group ) {
		$kind = (string) ( $candidate_group['kind'] ?? '' );
		if ( 'context' === $kind && null === $main_group ) {
			$main_group = $candidate_group;
			continue;
		}
		if ( in_array( $kind, array( 'guides', 'evaluation' ), true ) ) {
			$utility_ids = array_merge( $utility_ids, (array) ( $candidate_group['ids'] ?? array() ) );
			continue;
		}
		if ( in_array( $kind, array( 'latest-category', 'more-context' ), true ) ) {
			$discovery_ids = array_merge( $discovery_ids, (array) ( $candidate_group['ids'] ?? array() ) );
		}
	}

	$professional_groups = array();
	$shown_story_ids      = array();
	if ( is_array( $main_group ) ) {
		$main_group['ids']      = array_slice( array_values( array_unique( array_map( 'absint', (array) $main_group['ids'] ) ) ), 0, $main_limit );
		$main_group['optional'] = false;
		if ( $main_group['ids'] ) {
			$shown_story_ids      = array_merge( $shown_story_ids, $main_group['ids'] );
			$professional_groups[] = $main_group;
		}
	}

	$remaining_budget = max( 0, $story_budget - count( $shown_story_ids ) );
	$utility_limit    = 'compact' === $length ? 0 : min( 'long' === $length ? 4 : 3, $remaining_budget );
	$utility_ids      = array_slice( array_values( array_diff( array_unique( array_map( 'absint', $utility_ids ) ), $shown_story_ids ) ), 0, $utility_limit );
	if ( $utility_ids ) {
		$professional_groups[] = array(
			'kind'     => 'utility',
			'title'    => __( 'Guias e análises', 'go-verge' ),
			'ids'      => $utility_ids,
			'optional' => false,
		);
		$shown_story_ids = array_merge( $shown_story_ids, $utility_ids );
	}

	$remaining_budget = max( 0, $story_budget - count( $shown_story_ids ) );
	$discovery_ids    = array_slice( array_values( array_diff( array_unique( array_map( 'absint', $discovery_ids ) ), $shown_story_ids ) ), 0, $remaining_budget );
	if ( $discovery_ids ) {
		$professional_groups[] = array(
			'kind'     => 'discovery',
			'title'    => __( 'Continue no Overdrive', 'go-verge' ),
			'ids'      => $discovery_ids,
			'optional' => false,
		);
		$shown_story_ids = array_merge( $shown_story_ids, $discovery_ids );
	}

	/*
	 * Never leave an article with a visually empty rail. On stories with a new
	 * subject, sparse taxonomy or no scored related posts, the previous logic
	 * could render only an unfilled ad slot. Readers then saw a full-width blank
	 * area where the sidebar should be. Fill the remaining editorial budget with
	 * recent stories from the same vertical. Never mix editorial pillars merely
	 * to fill the four-card budget; a shorter accurate rail is preferable.
	 */
	$remaining_budget = max( 0, $story_budget - count( $shown_story_ids ) );
	$fallback_ids     = array();

	/* $editorial_bucket was resolved from the real primary category above. */

	if ( $remaining_budget > 0 ) {
		$bucket_aliases = array(
			'games'         => array( 'games', 'jogos' ),
			'entertainment' => array( 'entretenimento' ),
			'technology'    => array( 'tecnologia', 'technology', 'tech' ),
			'offers'        => array( 'ofertas', 'promocoes' ),
		);
		$bucket_term_ids = array();
		foreach ( (array) ( $bucket_aliases[ $editorial_bucket ] ?? array() ) as $bucket_slug ) {
			$bucket_term = get_term_by( 'slug', $bucket_slug, 'category' );
			if ( $bucket_term instanceof WP_Term ) {
				$bucket_term_ids[] = (int) $bucket_term->term_id;
			}
		}

		if ( $bucket_term_ids ) {
			$fallback_ids = get_posts(
				array(
					'post_type'           => 'post',
					'post_status'         => 'publish',
					'posts_per_page'      => max( 8, $remaining_budget * 3 ),
					'post__not_in'        => array_values( array_unique( array_merge( array( $post_id ), $shown_story_ids, go_verge_recirculation_shown_ids() ) ) ),
					'ignore_sticky_posts' => true,
					'no_found_rows'       => true,
					'orderby'             => 'date',
					'order'               => 'DESC',
					'fields'              => 'ids',
					'tax_query'           => array(
						array(
							'taxonomy'         => 'category',
							'field'            => 'term_id',
							'terms'            => array_values( array_unique( $bucket_term_ids ) ),
							'include_children' => true,
						),
					),
				)
			);
			$fallback_ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $fallback_ids ) ) ) );
			if ( function_exists( '_prime_post_caches' ) ) { _prime_post_caches( $fallback_ids, true, true ); }
			$fallback_ids = array_slice( array_values( array_filter( $fallback_ids, static function($id) use ($editorial_bucket) {
				return $editorial_bucket === go_verge_article_vertical_bucket($id)
					&& ( ! function_exists('go_verge_promotion_has_expired') || ! go_verge_promotion_has_expired($id) );
			} ) ), 0, $remaining_budget );
		}

	}

	if ( $fallback_ids ) {
		$bucket_titles = array(
			'games'         => __( 'Últimas de Games', 'go-verge' ),
			'entertainment' => __( 'Últimas de Entretenimento', 'go-verge' ),
			'technology'    => __( 'Últimas de Tecnologia', 'go-verge' ),
			'offers'        => __( 'Últimas de Ofertas', 'go-verge' ),
		);
		$professional_groups[] = array(
			'kind'     => 'latest-fallback',
			'title'    => $bucket_titles[ $editorial_bucket ] ?? __( 'Últimas publicações', 'go-verge' ),
			'ids'      => array_slice( $fallback_ids, 0, $remaining_budget ),
			'optional' => false,
		);
		$shown_story_ids = array_merge( $shown_story_ids, $fallback_ids );
	}

	// Matéria de guia de compra: o trilho abre com outros guias, que é o que
	// esse leitor foi buscar — antes de qualquer descoberta genérica.
	if ( function_exists( 'go_verge_buying_guides_category_slugs' ) && function_exists( 'go_verge_category_ids' ) ) {
		$go_sidebar_buying_terms = go_verge_category_ids( go_verge_buying_guides_category_slugs(), array( 'guia-de-compra' ) );
		if ( $go_sidebar_buying_terms && has_term( $go_sidebar_buying_terms, 'category', $post_id ) ) {
			$go_sidebar_buying_ids = get_posts(
				array(
					'post_type'           => 'post',
					'post_status'         => 'publish',
					'posts_per_page'      => 3,
					'post__not_in'        => array_values( array_unique( array_merge( array( $post_id ), $shown_story_ids, go_verge_recirculation_shown_ids() ) ) ),
					'ignore_sticky_posts' => true,
					'no_found_rows'       => true,
					'fields'              => 'ids',
					'tax_query'           => array(
						array(
							'taxonomy'         => 'category',
							'field'            => 'term_id',
							'terms'            => $go_sidebar_buying_terms,
							'include_children' => true,
						),
					),
				)
			);
			$go_sidebar_buying_ids = array_values( array_filter( array_map( 'absint', (array) $go_sidebar_buying_ids ) ) );
			if ( $go_sidebar_buying_ids ) {
				array_unshift(
					$professional_groups,
					array(
						'kind'     => 'buying-guides',
						'title'    => __( 'Mais guias de compra', 'go-verge' ),
						'ids'      => $go_sidebar_buying_ids,
						'optional' => false,
					)
				);
				$shown_story_ids = array_merge( $shown_story_ids, $go_sidebar_buying_ids );
			}
		}
	}

	// Legacy side shelves must respect the same eligibility and page-wide ledger.
	$groups = array();
	$used = array_values( array_unique( array_merge( array($post_id), go_verge_recirculation_shown_ids() ) ) );
	foreach ( $professional_groups as $group ) {
		$accepted = array();
		foreach ( (array) $group['ids'] as $id ) {
			$id = absint($id);
			if ( in_array($id,$used,true) || ! go_verge_single_recommendation_eligible($id,$post_id) ) { continue; }
			if ( 'direct' !== $editorial_bucket && $editorial_bucket !== go_verge_article_vertical_bucket($id) ) { continue; }
			$accepted[]=$id; $used[]=$id;
		}
		if ( $accepted ) { $group['ids']=$accepted; $groups[]=$group; }
	}
	$has_sidebar_editorial_content = ! empty( $review_game['title'] ) || ! empty( $groups );

	$render_story_group = static function ( $group ) {
		$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $group['ids'] ) ) ) );
		if ( ! $ids ) {
			return;
		}
		$title = (string) ( $group['title'] ?? '' );
		if ( ! empty( $group['context'] ) && ! go_verge_sidebar_group_matches_context( $ids, $group['context'] ) ) {
			$title = (string) ( $group['fallback_title'] ?? __( 'Conteúdos relacionados', 'go-verge' ) );
		}
		$query = new WP_Query(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'post__in'            => $ids,
				'orderby'             => 'post__in',
				'posts_per_page'      => count( $ids ),
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
			)
		);
		if ( ! $query->have_posts() ) {
			return;
		}
		?>
		<section class="go-article-sidebar__block go-article-sidebar__block--<?php echo esc_attr( $group['kind'] ); ?>">
			<h2 class="go-article-sidebar__title"><?php echo esc_html( $title ); ?></h2>
			<div class="go-article-sidebar__stories">
				<?php while ( $query->have_posts() ) : $query->the_post(); ?>
					<a class="go-article-sidebar__story" href="<?php the_permalink(); ?>" <?php echo function_exists('go_verge_reco_data_attributes') ? go_verge_reco_data_attributes(get_the_ID(),'sidebar') : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
						<?php if ( has_post_thumbnail() ) : ?><span class="go-article-sidebar__thumb"><?php the_post_thumbnail( 'go_card', array( 'loading' => 'lazy', 'alt' => '' ) ); ?></span><?php endif; ?>
						<span class="go-article-sidebar__story-copy"><strong><?php the_title(); ?></strong><?php echo go_verge_time_html( get_the_ID() ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span>
					</a>
				<?php endwhile; wp_reset_postdata(); ?>
			</div>
		</section>
		<?php
	};
	?>
	<aside class="go-article-sidebar go-article-sidebar--<?php echo esc_attr( $length ); ?>" data-go-sidebar-length="<?php echo esc_attr( $length ); ?>" data-go-context-sidebar="1" data-go-sidebar-has-ad="1" aria-label="<?php esc_attr_e( 'Conteúdo complementar', 'go-verge' ); ?>">
		<div class="go-article-sidebar__track">
		<?php if ( ! empty( $review_game['title'] ) ) : ?>
			<section class="go-article-sidebar__block go-article-sidebar__block--game-profile">
				<h2 class="go-article-sidebar__title"><?php esc_html_e( 'Perfil do game', 'go-verge' ); ?></h2>
				<a class="go-article-sidebar__game-profile<?php echo empty( $review_game['url'] ) ? ' is-disabled' : ''; ?>" <?php if ( ! empty( $review_game['url'] ) ) : ?>href="<?php echo esc_url( $review_game['url'] ); ?>"<?php endif; ?>>
					<?php if ( ! empty( $review_game['id'] ) && has_post_thumbnail( $review_game['id'] ) ) : ?>
						<span class="go-article-sidebar__game-cover"><?php echo get_the_post_thumbnail( $review_game['id'], 'go_square', array( 'loading' => 'lazy', 'alt' => '' ) ); ?></span>
					<?php endif; ?>
					<span class="go-article-sidebar__game-copy"><strong><?php echo esc_html( go_verge_prepare_game_name( $review_game['title'] ) ); ?></strong><small><?php echo ! empty( $review_game['url'] ) ? esc_html__( 'Ver ficha do game', 'go-verge' ) : esc_html__( 'Perfil em breve', 'go-verge' ); ?></small></span>
				</a>
			</section>
		<?php endif; ?>

		<?php
		// Ofertas Amazon escolhidas para ESTA matéria acompanham a leitura no
		// trilho — o leitor não precisa rolar de volta ao card no meio do texto.
		if ( class_exists( 'GO_Amazon_Core' ) ) :
			$go_sidebar_offers = array();
			foreach ( array_slice( array_map( 'absint', (array) get_post_meta( $post_id, '_go_amazon_article_offer_ids', true ) ), 0, 2 ) as $go_sidebar_offer_id ) {
				$go_sidebar_offer = GO_Amazon_Core::offer_data( $go_sidebar_offer_id );
				if ( $go_sidebar_offer ) {
					$go_sidebar_offers[] = $go_sidebar_offer;
				}
			}
			if ( $go_sidebar_offers ) :
				?>
				<section class="go-article-sidebar__block go-article-sidebar__block--offers">
					<h2 class="go-article-sidebar__title"><?php esc_html_e( 'Ofertas desta matéria', 'go-verge' ); ?></h2>
					<div class="go-article-sidebar__offers">
						<?php foreach ( $go_sidebar_offers as $go_sidebar_offer ) : ?>
							<a class="go-article-sidebar__offer" href="<?php echo esc_url( $go_sidebar_offer['url'] ); ?>" target="_blank" rel="sponsored nofollow noopener" data-go-affiliate-link data-placement="sidebar" data-offer-title="<?php echo esc_attr( $go_sidebar_offer['title'] ); ?>">
								<?php if ( ! empty( $go_sidebar_offer['image_html'] ) ) : ?>
									<span class="go-article-sidebar__offer-thumb"><?php echo $go_sidebar_offer['image_html']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span>
								<?php elseif ( ! empty( $go_sidebar_offer['image_url'] ) ) : ?>
									<span class="go-article-sidebar__offer-thumb"><img src="<?php echo esc_url( $go_sidebar_offer['image_url'] ); ?>" alt="" width="62" height="62" loading="lazy" decoding="async" data-go-decorative="1"></span>
								<?php endif; ?>
								<span class="go-article-sidebar__offer-copy">
									<strong><?php echo esc_html( $go_sidebar_offer['title'] ); ?></strong>
									<?php if ( ! empty( $go_sidebar_offer['sale_price'] ) ) : ?><em><?php echo esc_html( $go_sidebar_offer['sale_price'] ); ?></em><?php endif; ?>
									<small><?php esc_html_e( 'Amazon · link patrocinado', 'go-verge' ); ?></small>
								</span>
							</a>
						<?php endforeach; ?>
					</div>
				</section>
				<?php
			endif;
		endif;
		?>

		<?php foreach ( $groups as $group ) { $render_story_group( $group ); } ?>

		<?php if ( ! $has_sidebar_editorial_content ) : ?>
			<section class="go-article-sidebar__block go-article-sidebar__block--latest-fallback">
				<h2 class="go-article-sidebar__title"><?php esc_html_e( 'Continue no Overdrive', 'go-verge' ); ?></h2>
				<a class="go-btn" href="<?php echo esc_url( home_url( '/' ) ); ?>"><?php esc_html_e( 'Ver últimas publicações', 'go-verge' ); ?></a>
			</section>
		<?php endif; ?>

		<?php
		/*
		 * The sticky unit must be the LAST child of the rail.
		 *
		 * A sticky element does not push what follows it: once pinned it keeps
		 * its screen position while its siblings keep scrolling, so it slides
		 * over everything below it. Placed mid-column it painted straight over
		 * "Continue no Overdrive". As the final child there is nothing left to
		 * cover, and it still gets a long travel because the rail is stretched
		 * to the height of the article (see .go-article-sidebar__track in
		 * go-ads.css): the free space under the last module IS its runway.
		 */
		if ( function_exists( 'go_verge_render_adsense_unit' ) ) {
			go_verge_render_adsense_unit(
				'sidebar-desktop',
				array(
					'tag'   => 'div',
					'class' => 'go-article-sidebar__ad go-article-sidebar__ad--sticky',
					'prime' => true,
					'data'  => array( 'ad-surface' => 'article-sidebar' ),
				)
			);
			/*
			 * The same rail below 1101px, where it is no longer a rail.
			 *
			 * single-clean.css collapses .go-single__layout to `display:block`
			 * there, so everything above renders full width under the article
			 * instead of disappearing — offers, story groups, "Continue no
			 * Overdrive" — and none of it carried inventory, on the device that
			 * carries most of the audience.
			 *
			 * Both hosts are emitted into one cached document on purpose. Their
			 * viewport gates are complementary (desktop_only against
			 * max_viewport 1100), the renderer puts that gate on the request as
			 * well as on the display rule, and the runtime requests neither
			 * until its own media query matches. One HTML response therefore
			 * stays correct for every user agent and every cache layer.
			 */
			go_verge_render_adsense_unit(
				'article-rail-mobile',
				array(
					'tag'   => 'div',
					'class' => 'go-article-sidebar__ad go-article-sidebar__ad--stacked',
					'data'  => array( 'ad-surface' => 'article-rail-mobile' ),
				)
			);
		}
		?>
		</div>
	</aside>
	<?php
	go_verge_sidebar_shown_ids( $used );
}

/**
 * Remove editor-only blank paragraphs from the rendered single-post flow.
 *
 * WordPress itself does not need empty <p> nodes for paragraph separation; the
 * theme owns that rhythm in CSS. Legacy posts and pasted HTML can still contain
 * paragraphs made only from whitespace, NBSP or <br>, which visually become an
 * extra line plus another paragraph gap. Keeping them is the main way a clean
 * spacing scale turns into random-looking holes between otherwise identical
 * blocks.
 *
 * @param string $content Rendered post content.
 * @return string
 */
function go_verge_normalize_article_flow_markup( $content ) {
	if ( ! is_string( $content ) || '' === trim( $content ) ) {
		return $content;
	}

	/* Work on byte ranges, never reserialize the article. An empty paragraph
	 * written inside JSON, a template or a code example is data, not spacing. */
	$attributes = '(?:"[^"]*"|\'[^\']*\'|[^\'">])*';
	$tokens = '~<!--[\s\S]*?(?:-->|$)|<(script|style|textarea)\b' . $attributes . '>[\s\S]*?</\1\s*>|</?[a-z][a-z0-9:-]*\b' . $attributes . '>~i';
	if ( false === preg_match_all( $tokens, $content, $matches, PREG_OFFSET_CAPTURE ) ) {
		return $content;
	}
	$protected = array( 'script', 'style', 'template', 'textarea', 'pre', 'code' );
	$ranges = array();
	$stack = array();
	$start = 0;
	foreach ( $matches[0] as $match ) {
		$token = $match[0];
		$offset = (int) $match[1];
		if ( 0 === strpos( $token, '<!--' ) ) {
			if ( '-->' !== substr( $token, -3 ) ) { return $content; }
			if ( ! $stack ) { $ranges[] = array( $offset, $offset + strlen( $token ) ); }
			continue;
		}
		if ( ! preg_match( '~^<(\/?)([a-z][a-z0-9:-]*)\b~i', $token, $tag ) ) { continue; }
		$name = strtolower( $tag[2] );
		if ( ! in_array( $name, $protected, true ) ) { continue; }
		/* Raw-text elements are one token: tag-like text inside is never parsed. */
		if ( '' === $tag[1] && in_array( $name, array( 'script', 'style', 'textarea' ), true )
			&& preg_match( '~</' . $name . '\s*>$~i', $token ) ) {
			if ( ! $stack ) { $ranges[] = array( $offset, $offset + strlen( $token ) ); }
			continue;
		}
		if ( '' === $tag[1] ) {
			if ( ! $stack ) { $start = $offset; }
			$stack[] = $name;
		} else {
			/* Cosmetic cleanup fails open on malformed protected markup. */
			if ( ! $stack || end( $stack ) !== $name ) { return $content; }
			array_pop( $stack );
			if ( ! $stack ) { $ranges[] = array( $start, $offset + strlen( $token ) ); }
		}
	}
	if ( $stack ) { return $content; }
	$empty_paragraph = '~<p\b' . $attributes . '>(?:\s++|&nbsp;|&#160;|&#x0*A0;|<br\s*/?>)*+</p>~iu';
	$result = '';
	$cursor = 0;
	$ranges[] = array( strlen( $content ), strlen( $content ) );
	foreach ( $ranges as $range ) {
		$clean = preg_replace( $empty_paragraph, '', substr( $content, $cursor, $range[0] - $cursor ) );
		if ( ! is_string( $clean ) ) { return $content; }
		$result .= $clean . substr( $content, $range[0], $range[1] - $range[0] );
		$cursor = $range[1];
	}
	return $result;
}

/** Build H2/H3 navigation without changing the article's element tree. */
function go_verge_article_outline( $html ) {
	$toc = array();
	$reserved = array();
	$used = array();
	$id_pattern = '~(?<=\s)id\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s>]+))~i';
	$tag_pattern = '~<!--[\s\S]*?-->|<(script|style|template)\b[^>]*>[\s\S]*?</\1\s*>|<([a-z][a-z0-9:-]*)\b((?:[^>"\']|"[^"]*"|\'[^\']*\')*)>~i';
	preg_match_all( $tag_pattern, $html, $tags, PREG_SET_ORDER );
	foreach ( $tags as $tag ) {
		if ( empty( $tag[2] ) || ! preg_match( $id_pattern, $tag[3], $match ) ) { continue; }
		$id = html_entity_decode( ( $match[1] ?? '' ) . ( $match[2] ?? '' ) . ( $match[3] ?? '' ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
		if ( '' === $id ) { continue; }
		$reserved[ $id ] = true;
		if ( ! in_array( strtolower( $tag[2] ), array( 'h2', 'h3' ), true ) ) { $used[ $id ] = true; }
	}
	$pattern = '~<!--[\s\S]*?-->|<(script|style|template)\b[^>]*>[\s\S]*?</\1\s*>|<h([23])\b((?:[^>"\']|"[^"]*"|\'[^\']*\')*)>([\s\S]*?)</h\2\s*>~i';
	$content = preg_replace_callback( $pattern, static function ( $match ) use ( &$toc, &$used, $reserved, $id_pattern ) {
		if ( empty( $match[2] ) ) { return $match[0]; }
		$text = trim( html_entity_decode( wp_strip_all_tags( $match[4] ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) );
		if ( '' === $text ) { return $match[0]; }
		$attrs = $match[3];
		$has_id = preg_match( $id_pattern, $attrs, $existing );
		$id = $has_id ? html_entity_decode( ( $existing[1] ?? '' ) . ( $existing[2] ?? '' ) . ( $existing[3] ?? '' ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) : '';
		if ( '' === $id || isset( $used[ $id ] ) ) {
			$base = sanitize_title( $text );
			if ( '' === $base ) { $base = 'secao'; }
			$id = $base;
			$number = 2;
			while ( isset( $used[ $id ] ) || isset( $reserved[ $id ] ) ) { $id = $base . '-' . $number++; }
			$attrs = $has_id ? preg_replace( $id_pattern, 'id="' . esc_attr( $id ) . '"', $attrs, 1 ) : $attrs . ' id="' . esc_attr( $id ) . '"';
		}
		$used[ $id ] = true;
		$toc[] = array( 'id' => $id, 'text' => $text, 'level' => (int) $match[2] );
		return '<h' . $match[2] . $attrs . '>' . $match[4] . '</h' . $match[2] . '>';
	}, (string) $html );
	return array( 'content' => is_string( $content ) ? $content : $html, 'toc' => $toc );
}

/** Filter content once, then add stable navigation anchors before Auto Ads runs. */
function go_verge_content_with_toc( $post_id = null ) {
	$post_id = $post_id ? $post_id : get_the_ID();
	$content = apply_filters( 'the_content', get_post_field( 'post_content', $post_id ) );
	return go_verge_article_outline( go_verge_normalize_article_flow_markup( $content ) );
}

/**
 * Render the "Sobre o autor" card at the end of an article. Only shows the
 * compact identity block without repeating the profile biography.
 */
function go_verge_author_card( $post_id = null ) {
	$post_id   = $post_id ? $post_id : get_the_ID();
	$author_id = (int) get_post_field( 'post_author', $post_id );
	if ( ! $author_id ) {
		return;
	}

	$author_url  = get_author_posts_url( $author_id );
	$author_name = get_the_author_meta( 'display_name', $author_id );
	$author_role = function_exists( 'go_verge_author_role' ) ? go_verge_author_role( $author_id ) : trim( (string) get_the_author_meta( 'go_author_role', $author_id ) );
	$topics      = array();
	if ( function_exists( 'go_verge_author_list_meta' ) ) {
		$topics = array_values( array_unique( array_merge(
			go_verge_author_list_meta( $author_id, 'go_author_coverage', 3 ),
			go_verge_author_list_meta( $author_id, 'go_author_expertise', 3 )
		) ) );
		$topics = array_slice( $topics, 0, 3 );
	}
	$since = function_exists( 'go_verge_author_profile_value' ) ? absint( go_verge_author_profile_value( $author_id, 'go_author_since' ) ) : 0;
	$policy = get_page_by_path( 'politica-editorial' );
	$policy_url = $policy instanceof WP_Post && 'publish' === $policy->post_status ? get_permalink( $policy ) : '';

	echo '<aside class="go-author-card" aria-label="' . esc_attr( sprintf( __( 'Sobre %s', 'go-verge' ), $author_name ) ) . '">';
	echo '<a class="go-author-card__avatar" href="' . esc_url( $author_url ) . '" tabindex="-1" aria-hidden="true">' . get_avatar( $author_id, 112 ) . '</a>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- get_avatar() escapes internally.
	echo '<div class="go-author-card__body">';
	echo '<p class="go-author-card__kicker">' . esc_html__( 'Escrito por', 'go-verge' ) . '</p>';
	printf(
		'<p class="go-author-card__name"><a rel="author" href="%1$s">%2$s</a></p>',
		esc_url( $author_url ),
		esc_html( $author_name )
	);
	if ( $author_role ) {
		echo '<p class="go-author-card__role">' . esc_html( $author_role ) . '</p>';
	}
	if ( $topics || $since ) {
		$parts = array();
		if ( $topics ) { $parts[] = '<strong>' . esc_html__( 'Cobre:', 'go-verge' ) . '</strong> ' . esc_html( implode( ' · ', $topics ) ); }
		if ( $since >= 1900 && $since <= (int) gmdate( 'Y' ) + 1 ) { $parts[] = esc_html( sprintf( __( 'Jornalismo desde %d', 'go-verge' ), $since ) ); }
		echo '<p class="go-author-card__expertise">' . implode( ' <span aria-hidden="true">•</span> ', $parts ) . '</p>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- parts escaped above.
	}
	echo '<div class="go-author-card__trust">';
	printf(
		'<a class="go-author-card__link" href="%1$s">%2$s</a>',
		esc_url( $author_url ),
		esc_html__( 'Perfil, experiência e matérias', 'go-verge' )
	);
	if ( $policy_url ) {
		echo '<a class="go-author-card__policy" href="' . esc_url( $policy_url ) . '">' . esc_html__( 'Política editorial', 'go-verge' ) . '</a>';
	}
	echo '</div></div></aside>';
}

/**
 * Editorial composition contract.
 *
 * Article prose is intentionally left untouched by publisher ad placement
 * helpers. Auto Ads owns the article body; the featured
 * image overlay and desktop sticky sidebar remain publisher-managed on singles.
 */

/**
 * Mid-article subject and sharing actions.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_inline_cta_markup( $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	if ( ! $post_id ) {
		return '';
	}

	$title = rawurlencode( get_the_title( $post_id ) );
	$url   = rawurlencode( get_permalink( $post_id ) );

	ob_start();
	?>
	<aside class="go-share-card-v11" data-go-share-v11="1" data-go-ad-integrity="atomic" aria-label="<?php esc_attr_e( 'Compartilhar matéria', 'go-verge' ); ?>">
		<div class="go-share-card-v11__head">
			<strong><?php esc_html_e( 'Compartilhe o conteúdo', 'go-verge' ); ?></strong>
		</div>
		<nav class="go-share-card-v11__actions" aria-label="<?php esc_attr_e( 'Compartilhar matéria', 'go-verge' ); ?>">
			<a href="<?php echo esc_url( 'https://api.whatsapp.com/send?text=' . $title . '%20' . $url ); ?>" target="_blank" rel="noopener noreferrer" aria-label="<?php esc_attr_e( 'Compartilhar no WhatsApp', 'go-verge' ); ?>" title="WhatsApp">
				<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg>
				<span><?php esc_html_e( 'WhatsApp', 'go-verge' ); ?></span>
			</a>
			<a href="<?php echo esc_url( 'https://www.facebook.com/sharer/sharer.php?u=' . $url ); ?>" target="_blank" rel="noopener noreferrer" aria-label="<?php esc_attr_e( 'Compartilhar no Facebook', 'go-verge' ); ?>" title="Facebook">
				<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M13.6 22v-8.7h2.9l.4-3.4h-3.3V7.7c0-1 .3-1.7 1.7-1.7H17V3a23 23 0 0 0-2.5-.1c-2.5 0-4.2 1.5-4.2 4.4v2.5H7.5v3.4h2.8V22h3.3Z"/></svg>
				<span><?php esc_html_e( 'Facebook', 'go-verge' ); ?></span>
			</a>
			<a href="<?php echo esc_url( 'https://twitter.com/intent/tweet?text=' . $title . '&url=' . $url ); ?>" target="_blank" rel="noopener noreferrer" aria-label="<?php esc_attr_e( 'Compartilhar no X', 'go-verge' ); ?>" title="<?php esc_attr_e( 'Compartilhar no X', 'go-verge' ); ?>">
				<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M18.2 2.3h3.3l-7.2 8.2 8.5 11.2h-6.6L11 14.9l-6 6.8H1.7l7.7-8.8L1.3 2.3h6.8l4.7 6.2 5.4-6.2Zm-1.1 17.5h1.8L7.1 4.2h-2l12 15.6Z"/></svg>
				<span><?php esc_html_e( 'Compartilhar no X', 'go-verge' ); ?></span>
			</a>
			<a href="<?php echo esc_url( 'https://www.reddit.com/submit?url=' . $url . '&title=' . $title ); ?>" target="_blank" rel="noopener noreferrer" aria-label="<?php esc_attr_e( 'Compartilhar no Reddit', 'go-verge' ); ?>" title="Reddit">
				<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 0C5.373 0 0 5.373 0 12c0 3.314 1.343 6.314 3.515 8.485l-2.286 2.286C.775 23.225 1.097 24 1.738 24H12c6.627 0 12-5.373 12-12S18.627 0 12 0Zm4.388 3.199c1.104 0 1.999.895 1.999 1.999 0 1.105-.895 2-1.999 2-.946 0-1.739-.657-1.947-1.539v.002c-1.147.162-2.032 1.15-2.032 2.341v.007c1.776.067 3.4.567 4.686 1.363.473-.363 1.064-.58 1.707-.58 1.547 0 2.802 1.254 2.802 2.802 0 1.117-.655 2.081-1.601 2.531-.088 3.256-3.637 5.876-7.997 5.876-4.361 0-7.905-2.617-7.998-5.87-.954-.447-1.614-1.415-1.614-2.538 0-1.548 1.255-2.802 2.803-2.802.645 0 1.239.218 1.712.585 1.275-.79 2.881-1.291 4.64-1.365v-.01c0-1.663 1.263-3.034 2.88-3.207.188-.911.993-1.595 1.959-1.595Zm-8.085 8.376c-.784 0-1.459.78-1.506 1.797-.047 1.016.64 1.429 1.426 1.429.786 0 1.371-.369 1.418-1.385.047-1.017-.553-1.841-1.338-1.841Zm7.406 0c-.786 0-1.385.824-1.338 1.841.047 1.017.634 1.385 1.418 1.385.785 0 1.473-.413 1.426-1.429-.046-1.017-.721-1.797-1.506-1.797Zm-3.703 4.013c-.974 0-1.907.048-2.77.135-.147.015-.241.168-.183.305.483 1.154 1.622 1.964 2.953 1.964 1.33 0 2.47-.81 2.953-1.964.057-.137-.037-.29-.184-.305-.863-.087-1.795-.135-2.769-.135Z"/></svg>
				<span><?php esc_html_e( 'Reddit', 'go-verge' ); ?></span>
			</a>
			<button type="button" data-go-native-share data-share-url="<?php echo esc_url( get_permalink( $post_id ) ); ?>" data-share-title="<?php echo esc_attr( get_the_title( $post_id ) ); ?>" aria-label="<?php esc_attr_e( 'Compartilhar no dispositivo', 'go-verge' ); ?>" title="<?php esc_attr_e( 'Compartilhar', 'go-verge' ); ?>">
				<?php echo go_verge_icon( 'compartilhar', 'go-interface-icon' ); ?>
				<span data-go-share-feedback aria-live="polite"><?php esc_html_e( 'Compartilhar', 'go-verge' ); ?></span>
			</button>
		</nav>
	</aside>
	<?php
	return trim( (string) ob_get_clean() );
}

/**
 * Insert the inline CTA after the Nth paragraph of already-rendered content.
 * Skips articles too short for a mid-read break to make sense.
 */
function go_verge_inject_mid_content_cta( $content, $post_id = 0, $after_paragraph = 3, $min_paragraphs = 5 ) {
	if ( ! is_string( $content ) || '' === trim( $content ) ) {
		return $content;
	}

	$paragraph_count = preg_match_all( '/<p\b[^>]*>.*?<\/p>/isu', $content, $paragraphs, PREG_OFFSET_CAPTURE );
	if ( ! $paragraph_count || $paragraph_count < max( 3, absint( $min_paragraphs ) ) ) {
		return $content;
	}

	$breaks = array();
	if ( function_exists( 'go_verge_content_safe_paragraph_breaks' ) ) {
		$breaks = go_verge_content_safe_paragraph_breaks( $content, 55 );
	}
	if ( empty( $breaks ) ) {
		foreach ( $paragraphs[0] as $paragraph ) {
			$breaks[] = array( 'position' => (int) $paragraph[1] + strlen( (string) $paragraph[0] ) );
		}
	}
	if ( empty( $breaks ) ) {
		return $content;
	}

	$second_h2_end = 0;
	if ( preg_match_all( '/<h2\b[^>]*>.*?<\/h2>/isu', $content, $headings, PREG_OFFSET_CAPTURE ) && count( $headings[0] ) >= 2 ) {
		$second        = $headings[0][1];
		$second_h2_end = (int) $second[1] + strlen( (string) $second[0] );
	}

	$target   = $second_h2_end ?: (int) floor( strlen( $content ) * .5 );
	$position = 0;
	$distance = PHP_INT_MAX;
	foreach ( $breaks as $break ) {
		$candidate = isset( $break['position'] ) ? (int) $break['position'] : 0;
		if ( ! $candidate ) {
			continue;
		}
		if ( $second_h2_end && $candidate <= $second_h2_end ) {
			continue;
		}
		$near = substr( $content, max( 0, $candidate - 420 ), 840 );
		if ( preg_match( '/data-go-ad-placement|data-go-ad-break|go-smart-ad|adsbygoogle|google-auto-placed|go-inline-related|go-inline-cta|go-share-card-v11/i', $near ) ) {
			continue;
		}
		if ( $second_h2_end ) {
			$position = $candidate;
			break;
		}
		$current_distance = abs( $candidate - $target );
		if ( $current_distance < $distance ) {
			$position = $candidate;
			$distance = $current_distance;
		}
	}

	if ( ! $position ) {
		return $content;
	}

	return substr( $content, 0, $position ) . "\n" . go_verge_inline_cta_markup( $post_id ) . "\n" . substr( $content, $position );
}
