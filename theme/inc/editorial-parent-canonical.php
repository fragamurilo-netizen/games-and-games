<?php
/**
 * Canonical URLs for the three parent editorial hubs.
 *
 * The site historically exposed both a WordPress Page and a root category for
 * Games, Entertainment and Technology. The Page/archive remains the public hub;
 * the duplicate root category permanently redirects to it. Child categories
 * keep their own URLs and templates.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Public destination for one parent editorial family. */
function go_verge_parent_editorial_url( $key ) {
	$key = sanitize_key( (string) $key );

	if ( 'games' === $key ) {
		$archive = get_post_type_archive_link( 'games' );
		if ( $archive ) {
			return $archive;
		}
		$page = get_page_by_path( 'games', OBJECT, 'page' );
		if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
			return get_permalink( $page );
		}
		return home_url( '/games/' );
	}

	$slug = 'entertainment' === $key ? 'entretenimento' : ( 'technology' === $key ? 'tecnologia' : '' );
	if ( ! $slug ) {
		return '';
	}
	$page = get_page_by_path( $slug, OBJECT, 'page' );
	if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
		return get_permalink( $page );
	}
	return home_url( '/' . $slug . '/' );
}

/** Map only root parent-category slugs; child editorias are intentionally excluded. */
function go_verge_parent_editorial_key_for_slug( $slug ) {
	$slug = sanitize_title( (string) $slug );
	if ( in_array( $slug, array( 'games', 'jogos' ), true ) ) {
		return 'games';
	}
	if ( in_array( $slug, array( 'entretenimento', 'entertainment' ), true ) ) {
		return 'entertainment';
	}
	if ( in_array( $slug, array( 'tecnologia', 'technology', 'tech' ), true ) ) {
		return 'technology';
	}
	return '';
}

/** Redirect duplicate parent category/Page URLs to the single public hub. */
function go_verge_redirect_duplicate_parent_editorials() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || is_preview() ) {
		return;
	}

	$key = '';
	if ( is_category() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$key = go_verge_parent_editorial_key_for_slug( $term->slug );
		}
	} elseif ( is_page() ) {
		$page = get_queried_object();
		if ( $page instanceof WP_Post ) {
			$key = go_verge_parent_editorial_key_for_slug( $page->post_name );
		}
	}
	if ( ! $key ) {
		return;
	}

	$target = go_verge_parent_editorial_url( $key );
	if ( ! $target ) {
		return;
	}
	/* A parent hub is a list, not a multipage WordPress document. Preserve the
	 * archive page on both canonical and legacy category routes. Previously
	 * every /page/N/ was permanently redirected to the first page. */
	$paged = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	if ( $paged > 1 ) {
		$target = trailingslashit( $target ) . user_trailingslashit( 'page/' . $paged, 'paged' );
	}

	/* Parent-hub filters and search survive a legacy URL redirect. */
	$keep = array();
	foreach ( array( 'editoria', 'tema' ) as $arg ) {
		if ( isset( $_GET[ $arg ] ) && is_scalar( $_GET[ $arg ] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			$keep[ $arg ] = sanitize_text_field( wp_unslash( $_GET[ $arg ] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		}
	}
	if ( $keep ) {
		$target = add_query_arg( $keep, $target );
	}

	$current_path = wp_parse_url( home_url( add_query_arg( array(), $GLOBALS['wp']->request ?? '' ) ), PHP_URL_PATH );
	$target_path  = wp_parse_url( $target, PHP_URL_PATH );
	$current_path = untrailingslashit( (string) $current_path );
	$target_path  = untrailingslashit( (string) $target_path );
	if ( $current_path === $target_path ) {
		return;
	}

	wp_safe_redirect( $target, 301, 'Overdrive editorial canonical' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_duplicate_parent_editorials', 4 );

/** Core's singular-page redirect must not collapse an editorial listing. */
function go_verge_parent_hub_pagination_redirect( $redirect ) {
	if ( is_page( array( 'tecnologia', 'entretenimento' ) ) && ! is_404()
		&& max( (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) ) > 1 ) {
		return false;
	}
	return $redirect;
}
add_filter( 'redirect_canonical', 'go_verge_parent_hub_pagination_redirect', 30 );

/** Generated root-category links also point directly to the public parent hub. */
function go_verge_parent_editorial_term_link( $url, $term, $taxonomy ) {
	if ( 'category' !== $taxonomy || ! $term instanceof WP_Term ) {
		return $url;
	}
	$key = go_verge_parent_editorial_key_for_slug( $term->slug );
	return $key ? go_verge_parent_editorial_url( $key ) : $url;
}
add_filter( 'term_link', 'go_verge_parent_editorial_term_link', 28, 3 );

/**
 * /games/ is registered as a games CPT archive but renders the article desk.
 * Core's CPT count cannot decide whether page 2 of that article feed exists.
 * Hand off to the editorial renderer, which validates the real feed and emits
 * its 404 before get_header() when the requested article page is empty.
 */
function go_verge_games_editorial_pre_handle_404( $preempt, $query ) {
	if ( false !== $preempt || ! ( $query instanceof WP_Query ) || ! $query->is_post_type_archive( 'games' ) || $query->is_feed() || max( absint( $query->get( 'paged' ) ), absint( $query->get( 'page' ) ) ) <= 1 ) {
		return $preempt;
	}
	status_header( 200 );
	return true;
}
add_filter( 'pre_handle_404', 'go_verge_games_editorial_pre_handle_404', 30, 2 );
