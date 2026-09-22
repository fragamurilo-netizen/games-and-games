<?php
/** Read-only format browsing inside the four existing editorial desks. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_verge_desk_formats( $desk ) {
	$formats = array(
		'games' => array(
			'noticia' => 'Notícias',
			'guia' => 'Guias',
			'review' => 'Reviews',
			'impressoes' => 'Impressões',
			'lista' => 'Listas',
			'ranking' => 'Rankings',
			'especial' => 'Especiais',
		),
		'entretenimento' => array(
			'noticia' => 'Notícias',
			'onde-assistir' => 'Onde assistir',
			'final-explicado' => 'Finais explicados',
			'guia' => 'Guias',
			'critica' => 'Críticas',
			'lista' => 'Listas',
			'ranking' => 'Rankings',
			'especial' => 'Especiais',
		),
		'tecnologia' => array(
			'noticia' => 'Notícias',
			'guia' => 'Guias',
			'guia-de-compra' => 'Guias de compra',
			'review' => 'Reviews',
			'lista' => 'Listas',
			'ranking' => 'Rankings',
			'especial' => 'Especiais',
		),
		'ofertas' => array(
			'oferta' => 'Ofertas',
			'guia-de-compra' => 'Guias de compra',
			'lista' => 'Listas',
		),
	);
	return $formats[ $desk ] ?? array();
}

/** A category that represents an editorial format is not a subject/subeditoria. */
function go_verge_desk_term_format( $term, $desk = '' ) {
	if ( ! ( $term instanceof WP_Term ) || 'category' !== $term->taxonomy ) { return ''; }
	if ( isset( go_verge_editorial_pillars()[ $term->slug ] ) ) { return ''; }
	if ( '' === $desk ) { $desk = go_verge_category_editorial_desk( $term ); }
	$formats = go_verge_desk_formats( $desk );
	if ( ! $formats ) { return ''; }
	$type = function_exists( 'go_verge_v7_default_type_for_categories' ) ? go_verge_v7_default_type_for_categories( array( $term->slug ) ) : '';
	return isset( $formats[ $type ] ) ? $type : '';
}


/** Keep the current subject archive when filtering a parent desk or a child. */
function go_verge_desk_format_context() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || is_404() || is_search() ) { return array(); }
	$desk = '';
	$scope = 0;
	$scope_taxonomy = 'category';
	if ( is_post_type_archive( 'games' ) ) {
		$desk = 'games';
	} elseif ( is_tax( 'go_platform' ) ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$desk = 'games';
			$scope = (int) $term->term_id;
			$scope_taxonomy = 'go_platform';
		}
	} elseif ( is_category() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$desk = go_verge_category_editorial_desk( $term );
			if ( ! isset( go_verge_editorial_pillars()[ $term->slug ] ) ) { $scope = (int) $term->term_id; }
		}
	} elseif ( is_page( array( 'games', 'entretenimento', 'tecnologia', 'ofertas' ) ) ) {
		$desk = (string) get_post_field( 'post_name', get_queried_object_id() );
	}
	$formats = go_verge_desk_formats( $desk );
	if ( ! $formats ) { return array(); }
	$type = isset( $_GET['tipo'] ) && is_scalar( $_GET['tipo'] ) ? sanitize_key( wp_unslash( (string) $_GET['tipo'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$page = isset( $_GET['pagina'] ) && is_scalar( $_GET['pagina'] ) ? absint( $_GET['pagina'] ) : max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	return array(
		'desk' => $desk,
		'scope' => $scope,
		'scope_taxonomy' => $scope_taxonomy,
		'type' => isset( $formats[ $type ] ) ? $type : '',
		'page' => max( 1, $page ),
		'formats' => $formats,
	);
}

function go_verge_desk_format_url( $desk, $type = '', $page = 1, $scope = 0, $scope_taxonomy = 'category' ) {
	$scope_taxonomy = in_array( $scope_taxonomy, array( 'category', 'go_platform' ), true ) ? $scope_taxonomy : 'category';
	$term = $scope ? get_term( $scope, $scope_taxonomy ) : null;
	$valid_scope = false;
	if ( $term instanceof WP_Term ) {
		$valid_scope = 'go_platform' === $scope_taxonomy ? 'games' === $desk : go_verge_category_editorial_desk( $term ) === $desk;
	}
	$url = $valid_scope ? get_term_link( $term ) : go_verge_v7_category_url( $desk );
	if ( is_wp_error( $url ) ) { $url = go_verge_v7_category_url( $desk ); }
	$args = isset( go_verge_desk_formats( $desk )[ $type ] ) ? array( 'tipo' => $type ) : array();
	if ( $page > 1 ) { $args['pagina'] = absint( $page ); }
	return $args ? add_query_arg( $args, $url ) : $url;
}

/** Reuses assigned categories, including known legacy branches, without writing terms. */
function go_verge_desk_category_ids( $desk ) {
	static $by_desk = null;
	if ( null === $by_desk ) {
		$by_desk = array();
		$terms = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => false ) );
		foreach ( is_array( $terms ) ? $terms : array() as $term ) {
			$key = go_verge_category_editorial_desk( $term );
			if ( $key ) { $by_desk[ $key ][] = (int) $term->term_id; }
		}
	}
	return $by_desk[ $desk ] ?? array();
}

/** Explicit format wins. Legacy aliases apply only when no format is assigned. */
function go_verge_desk_format_query_args( $desk, $type, $page = 1, $scope = 0, $scope_taxonomy = 'category' ) {
	$args = array( 'post_type' => 'post', 'post_status' => 'publish', 'has_password' => false,
		'posts_per_page' => 18, 'paged' => max( 1, absint( $page ) ),
		'orderby' => array( 'date' => 'DESC', 'ID' => 'DESC' ), 'ignore_sticky_posts' => true,
		'no_found_rows' => false, 'go_desk_format_query' => true );
	$scope_taxonomy = in_array( $scope_taxonomy, array( 'category', 'go_platform' ), true ) ? $scope_taxonomy : 'category';
	$ids = go_verge_desk_category_ids( $desk );
	if ( $scope && 'category' === $scope_taxonomy ) { $ids = in_array( (int) $scope, $ids, true ) ? array( (int) $scope ) : array(); }
	if ( $scope && 'go_platform' === $scope_taxonomy && 'games' !== $desk ) { $ids = array(); }
	if ( ! $ids || ( '' !== $type && ( ! isset( go_verge_desk_formats( $desk )[ $type ] ) || ! taxonomy_exists( 'go_content_type' ) ) ) || $page > 10000 ) {
		$args['post__in'] = array( 0 );
		return $args;
	}
	$args['tax_query'] = array( 'relation' => 'AND',
		array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => $ids, 'include_children' => (bool) ( $scope && 'category' === $scope_taxonomy ) )
	);
	if ( $scope && 'go_platform' === $scope_taxonomy ) {
		$args['tax_query'][] = array( 'taxonomy' => 'go_platform', 'field' => 'term_id', 'terms' => array( (int) $scope ), 'include_children' => false );
	}
	if ( '' !== $type ) { $args['tax_query'][] = go_verge_content_type_tax_query( $type ); }
	return $args;
}

function go_verge_desk_format_query() {
	static $queries = array();
	$context = go_verge_desk_format_context();
	if ( ! $context ) { return null; }
	$key = implode( ':', array( $context['desk'], $context['type'], $context['page'], $context['scope_taxonomy'], $context['scope'] ) );
	if ( ! isset( $queries[ $key ] ) ) {
		$queries[ $key ] = new WP_Query( go_verge_desk_format_query_args( $context['desk'], $context['type'], $context['page'], $context['scope'], $context['scope_taxonomy'] ) );
	}
	return $queries[ $key ];
}

function go_verge_render_desk_format_links( $desk ) {
	$formats = go_verge_desk_formats( $desk );
	if ( ! $formats ) { return; }
	$context = go_verge_desk_format_context();
	$active = $context['type'] ?? '';
	$scope = $context['scope'] ?? 0;
	$scope_taxonomy = $context['scope_taxonomy'] ?? 'category';
	echo '<div class="od-desk-filter-block" data-od-desk-filter-block>';
	echo '<div class="od-desk-filter-heading"><span class="od-desk-filter-label">Tipo de matéria</span></div>';
	echo '<nav class="go-chips go-chips--filter od-desk-formats" aria-label="Filtrar as últimas publicações por tipo de matéria">';
	echo '<a data-od-desk-type="" aria-controls="od-desk-feed" href="' . esc_url( go_verge_desk_format_url( $desk, '', 1, $scope, $scope_taxonomy ) ) . '"' . ( '' === $active ? ' class="is-active" aria-current="page"' : '' ) . '>Todas</a>';
	foreach ( $formats as $type => $label ) {
		echo '<a data-od-desk-type="' . esc_attr( $type ) . '" aria-controls="od-desk-feed" href="' . esc_url( go_verge_desk_format_url( $desk, $type, 1, $scope, $scope_taxonomy ) ) . '"' . ( $active === $type ? ' class="is-active" aria-current="page"' : '' ) . '>' . esc_html( $label ) . '</a>';
	}
	echo '</nav><p class="od-desk-status" role="status" aria-live="polite" aria-atomic="true"></p>';
	echo '</div>';
}

/** Handle out-of-range filter pages before any HTML. Empty first pages remain useful. */
add_action( 'template_redirect', function () {
	$context = go_verge_desk_format_context();
	if ( ! $context ) { return; }
	$query = go_verge_desk_format_query();
	if ( $context['page'] > 1 && ( $context['page'] > $query->max_num_pages || ! $query->have_posts() ) ) {
		$GLOBALS['wp_query']->set_404();
		status_header( 404 );
		nocache_headers();
	}
}, 0 );

function go_verge_desk_format_canonical_url() {
	$context = go_verge_desk_format_context();
	return ! empty( $context['type'] ) ? go_verge_desk_format_url( $context['desk'], $context['type'], $context['page'], $context['scope'], $context['scope_taxonomy'] ) : '';
}

function go_verge_desk_context_is_format_archive( $context = null ) {
	$context = is_array( $context ) ? $context : go_verge_desk_format_context();
	if ( ! $context || empty( $context['scope'] ) || 'category' !== ( $context['scope_taxonomy'] ?? 'category' ) ) { return false; }
	$term = get_term( (int) $context['scope'], 'category' );
	return $term instanceof WP_Term && '' !== go_verge_desk_term_format( $term, $context['desk'] );
}

/** Persistent section navigation; these links always open real archives. */
function go_verge_render_desk_subjects() {
	$context = go_verge_desk_format_context();
	if ( ! $context ) { return; }
	$scope_taxonomy = $context['scope_taxonomy'] ?? 'category';
	$current = $context['scope'] ? get_term( $context['scope'], $scope_taxonomy ) : null;
	$current_url = '';
	if ( $current instanceof WP_Term ) {
		$current_url = get_term_link( $current );
		if ( is_wp_error( $current_url ) ) { $current_url = ''; }
	}
	$current_is_format = $current instanceof WP_Term && 'category' === $current->taxonomy && '' !== go_verge_desk_term_format( $current, $context['desk'] );

	foreach ( go_verge_publisher_navigation() as $group ) {
		if ( $group['key'] !== $context['desk'] ) { continue; }
		$items = array_values( array_filter( $group['items'], static function ( $item ) { return in_array( $item[2] ?? '', array( 'topic', 'platform' ), true ); } ) );
		if ( ! $items && ! $current ) { return; }

		$by_kind = array( 'platform' => array(), 'topic' => array() );
		foreach ( $items as $item ) {
			$kind = $item[2] ?? 'topic';
			if ( isset( $by_kind[ $kind ] ) ) { $by_kind[ $kind ][] = $item; }
		}

		echo '<section class="od-desk-subject-block" aria-label="' . esc_attr( sprintf( 'Navegar em %s', $group['label'] ) ) . '">';
		echo '<div class="od-desk-subject-head"><div><strong class="od-desk-subject-title">' . esc_html( sprintf( 'Navegar em %s', $group['label'] ) ) . '</strong></div>';
		$home_active = ! $current;
		echo '<a class="od-desk-subject-home' . ( $home_active ? ' is-active' : '' ) . '" href="' . esc_url( $group['url'] ) . '"' . ( $home_active ? ' aria-current="page"' : '' ) . '>' . ( $home_active ? 'Página principal' : '← Voltar para ' . esc_html( $group['label'] ) ) . '</a></div>';

		echo '<div class="od-desk-subject-groups">';
		foreach ( array( 'platform' => 'Plataformas', 'topic' => 'Seções' ) as $kind => $label ) {
			if ( empty( $by_kind[ $kind ] ) ) { continue; }
			echo '<div class="od-desk-subject-row od-desk-subject-row--' . esc_attr( $kind ) . '"><span class="od-desk-subject-label">' . esc_html( $label ) . '</span><nav class="od-desk-subjects" aria-label="' . esc_attr( $label . ' de ' . $group['label'] ) . '">';
			$shown = false;
			foreach ( $by_kind[ $kind ] as $item ) {
				$active = $current_url && untrailingslashit( $item[1] ) === untrailingslashit( $current_url );
				$shown = $shown || $active;
				echo '<a href="' . esc_url( $item[1] ) . '"' . ( $active ? ' class="is-active" aria-current="page"' : '' ) . '>' . esc_html( $item[0] ) . '</a>';
			}
			if ( 'topic' === $kind && $current && ! $shown && ! $current_is_format && 'category' === $scope_taxonomy ) {
				echo '<a class="is-active" aria-current="page" href="' . esc_url( $current_url ) . '">' . esc_html( $current->name ) . '</a>';
			}
			echo '</nav></div>';
		}
		echo '</div></section>';
	}
}

/** One independently replaceable list. Heroes, shelves and sidebars stay put. */
function go_verge_render_desk_feed( $query = null, $title = 'Últimas publicações' ) {
	$context = go_verge_desk_format_context();
	$query = $query ?: go_verge_desk_format_query();
	if ( ! $context || ! $query ) { return; }
	$is_format_archive = go_verge_desk_context_is_format_archive( $context );
	echo '<section id="od-desk-feed" class="go-archive-section od-desk-results" data-od-desk-feed data-od-scope="' . esc_attr( $context['desk'] . ':' . $context['scope_taxonomy'] . ':' . $context['scope'] ) . '" data-od-active-type="' . esc_attr( $context['type'] ) . '" data-od-page="' . esc_attr( $context['page'] ) . '" aria-labelledby="od-desk-feed-title" aria-busy="false" tabindex="-1">';
	echo '<div class="go-section__head od-desk-feed-head"><h2 id="od-desk-feed-title" class="go-section__title">' . esc_html( $title ) . '</h2></div>';
	if ( ! $is_format_archive ) { go_verge_render_desk_format_links( $context['desk'] ); }
	if ( $query->posts ) {
		echo '<div class="go-archive-list" data-go-latest-feed' . go_verge_ads_listing_root_attributes() . '>';
		foreach ( $query->posts as $post ) { go_verge_archive_list_item( $post->ID, array( 'show_excerpt' => true, 'media_context' => 'latest' ) ); }
		echo '</div>';
	} else {
		echo '<p class="od-desk-empty">' . esc_html( $context['type'] ? 'Ainda não há matérias deste tipo nesta seção.' : 'Ainda não há publicações nesta seção.' ) . '</p>';
	}
	if ( $query->max_num_pages > 1 ) {
		echo '<nav class="od-desk-pagination" aria-label="Paginação de últimas publicações">';
		foreach ( array( -1 => '← Anterior', 1 => 'Próxima →' ) as $step => $label ) {
			$page = $context['page'] + $step;
			if ( $page >= 1 && $page <= $query->max_num_pages ) { echo '<a data-od-desk-page rel="' . ( $step < 0 ? 'prev' : 'next' ) . '" href="' . esc_url( go_verge_desk_format_url( $context['desk'], $context['type'], $page, $context['scope'], $context['scope_taxonomy'] ) ) . '">' . esc_html( $label ) . '</a>'; }
			if ( -1 === $step ) { echo '<span>' . esc_html( sprintf( 'Página %d de %d', $context['page'], $query->max_num_pages ) ) . '</span>'; }
		}
		echo '</nav>';
	}
	echo '</section>';
}

/** Category cover keeps its own subject while the list accepts a type filter. */
function go_verge_render_desk_category( $term ) {
	$context = go_verge_desk_format_context();
	$cover_args = go_verge_desk_format_query_args( $context['desk'], '', 1, $context['scope'], $context['scope_taxonomy'] );
	$cover_args['posts_per_page'] = 5;
	$cover_args['no_found_rows'] = true;
	$cover = new WP_Query( $cover_args );
	$ids = array_map( 'absint', wp_list_pluck( $cover->posts, 'ID' ) );
	if ( $ids ) { go_verge_archive_hero( $ids[0], array_slice( $ids, 1 ), 'default' ); }
	do_action( 'go_verge_archive_after_hero', $term, $ids, 'default' );
	$is_format_archive = $term instanceof WP_Term && 'category' === $term->taxonomy && '' !== go_verge_desk_term_format( $term, $context['desk'] );
	$feed_title = $is_format_archive ? sprintf( 'Últimas em %s', $term->name ) : 'Últimas publicações';
	$accents = array( 'games' => 'games', 'entretenimento' => 'entertainment', 'tecnologia' => 'technology', 'ofertas' => 'offers' );
	$modules = go_verge_archive_sidebar_modules( $accents[ $context['desk'] ], $ids );
	echo '<div class="go-archive-body' . ( $modules ? ' go-archive-body--aside' : '' ) . '"><div class="go-archive-main">';
	go_verge_render_desk_feed( null, $feed_title );
	echo '</div>';
	if ( $modules ) { go_verge_render_archive_sidebar( $modules ); }
	echo '</div>';
}

/**
 * Return only the replaceable latest-publications fragment for desk filter requests.
 * Links remain normal archive URLs for progressive enhancement; JavaScript adds this
 * private request flag so the rest of the page is never rendered again on a filter click.
 */
function go_verge_desk_feed_fragment_response() {
	if ( is_admin() || wp_doing_ajax() || empty( $_GET['od_desk_fragment'] ) || ! is_scalar( $_GET['od_desk_fragment'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return;
	}
	$requested = sanitize_key( wp_unslash( (string) $_GET['od_desk_fragment'] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( 'feed' !== $requested || ! go_verge_desk_format_context() ) { return; }

	$xhr = isset( $_SERVER['HTTP_X_REQUESTED_WITH'] ) ? strtolower( sanitize_text_field( wp_unslash( $_SERVER['HTTP_X_REQUESTED_WITH'] ) ) ) : '';
	if ( 'xmlhttprequest' !== $xhr ) { return; }

	status_header( 200 );
	nocache_headers();
	header( 'Content-Type: text/html; charset=' . get_option( 'blog_charset' ) );
	header( 'X-Robots-Tag: noindex, nofollow', true );
	go_verge_render_desk_feed();
	exit;
}
add_action( 'template_redirect', 'go_verge_desk_feed_fragment_response', 20 );

add_filter( 'rank_math/frontend/canonical', function ( $canonical ) { return go_verge_desk_format_canonical_url() ?: $canonical; }, 10000 );

function go_verge_desk_format_title( $title ) {
	$context = go_verge_desk_format_context();
	if ( empty( $context['type'] ) ) { return $title; }
	$label = go_verge_editorial_pillars()[ $context['desk'] ]['label'];
	if ( $context['scope'] ) { $term = get_term( $context['scope'], $context['scope_taxonomy'] ); if ( $term instanceof WP_Term ) { $label = $term->name; } }
	return $context['formats'][ $context['type'] ] . ' de ' . $label . ( $context['page'] > 1 ? ' — Página ' . $context['page'] : '' ) . ' | Overdrive';
}
add_filter( 'rank_math/frontend/title', 'go_verge_desk_format_title', 10000 );
add_filter( 'pre_get_document_title', 'go_verge_desk_format_title', 10000 );

/** Facets aid readers; existing categories and stories keep their index policy. */
add_filter( 'wp_robots', function ( $robots ) {
	if ( go_verge_desk_format_canonical_url() ) { $robots['noindex'] = true; unset( $robots['index'] ); }
	return $robots;
}, 10000 );
add_filter( 'rank_math/frontend/robots', function ( $robots ) {
	if ( go_verge_desk_format_canonical_url() ) { $robots['index'] = 'noindex'; }
	return $robots;
}, 10000 );

add_action( 'wp_enqueue_scripts', function () {
	if ( is_admin() || ! go_verge_desk_format_context() ) { return; }
	$rel = '/assets/css/editorial-desk-formats.css';
	wp_enqueue_style( 'go-verge-desk-formats', GO_VERGE_URI . $rel, array( 'go-verge-editorial-cards' ), go_verge_asset_version( $rel ) );
	$js = '/assets/js/editorial-desk-filters.js';
	wp_enqueue_script( 'go-verge-desk-filters', GO_VERGE_URI . $js, array(), go_verge_asset_version( $js ), true );
}, 49750 );
