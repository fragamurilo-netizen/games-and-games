<?php
/** Shared destinations for the publisher drawer and footer. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** One navigation contract: desks, then formats and subjects within each desk. */
function go_verge_publisher_navigation_blueprint() {
	$subjects = array(
		'games' => array( 'lancamentos' => 'Lançamentos' ),
		'entretenimento' => array( 'series' => 'Séries', 'filmes' => 'Filmes', 'producoes-turcas' => 'Produções turcas', 'anime-e-manga' => 'Anime e Mangá', 'doramas' => 'Doramas', 'streaming' => 'Streaming', 'musica' => 'Música' ),
		'tecnologia' => array( 'celulares' => 'Celulares', 'mobilidade' => 'Auto e Mobilidade', 'internet' => 'Internet', 'hardware' => 'Hardware', 'notebooks' => 'Notebooks', 'tvs-e-monitores' => 'TVs e Monitores', 'eletrodomesticos' => 'Eletrodomésticos', 'casa-inteligente' => 'Casa Inteligente', 'wearables' => 'Wearables', 'apps-software' => 'Apps e Software', 'ia' => 'Inteligência Artificial', 'ciencia' => 'Ciência e Mundo', 'servico' => 'Serviço' ),
		'ofertas' => array( 'promocoes' => 'Promoções', 'guias-de-compra' => 'Todos os guias de compra', 'jogos-gratis' => 'Jogos grátis' ),
	);
	if ( function_exists( 'go_verge_editorial_subdesk_blueprint' ) ) { $subjects = go_verge_editorial_subdesk_blueprint(); }
	$groups = array();
	foreach ( go_verge_editorial_pillars() as $desk => $pillar ) {
		$items = array();
		foreach ( go_verge_desk_formats( $desk ) as $type => $label ) {
			$items[] = array( $label, go_verge_desk_format_url( $desk, $type ), 'format' );
		}
		foreach ( $subjects[ $desk ] ?? array() as $slug => $label ) {
			$term = get_term_by( 'slug', $slug, 'category' );
			if ( ! ( $term instanceof WP_Term ) ) { continue; }
			if ( go_verge_category_editorial_desk( $term ) !== $desk ) { continue; }
			/* Subject destinations come from the controlled editorial blueprint. Keep
			 * them visible even before their first story so the desk navigation is stable
			 * and every planned category has an internal crawl path from its parent hub. */
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) { $items[] = array( $label, $url, 'topic' ); }
		}
		if ( 'games' === $desk ) {
			foreach ( array( 'pc' => 'PC', 'playstation' => 'PlayStation', 'xbox' => 'Xbox', 'nintendo' => 'Nintendo' ) as $slug => $label ) {
				$term = get_term_by( 'slug', $slug, 'go_platform' );
				$url = $term instanceof WP_Term ? get_term_link( $term ) : '';
				if ( $url && ! is_wp_error( $url ) ) { $items[] = array( $label, $url, 'platform' ); }
			}
		}
		$groups[] = array( 'key' => $desk, 'label' => $pillar['label'], 'url' => go_verge_v7_category_url( $desk ), 'items' => $items );
	}
	return $groups;
}

/** The active masthead follows the subject desk, including reviews and guides. */
function go_verge_publisher_current_desk() {
	if ( is_singular( 'post' ) ) { return go_verge_post_editorial_desk( get_queried_object_id() ); }
	if ( is_category() ) { return go_verge_category_editorial_desk( get_queried_object() ); }
	if ( is_post_type_archive( 'games' ) || is_singular( 'games' ) || is_tax( 'go_platform' ) ) { return 'games'; }
	if ( is_singular( 'productions' ) || is_post_type_archive( 'productions' ) ) { return 'entretenimento'; }
	if ( is_tax( 'go_service' ) ) {
		$service = get_queried_object();
		return $service instanceof WP_Term && in_array( $service->slug, array( 'steam', 'playstation-plus', 'playstation-store', 'xbox-game-pass', 'epic-games-store', 'geforce-now' ), true ) ? 'games' : 'entretenimento';
	}
	if ( is_post_type_archive( 'go_promotion' ) || is_singular( 'go_promotion' ) ) { return 'ofertas'; }
	$context = go_verge_desk_format_context();
	return $context['desk'] ?? '';
}

add_filter( 'go_verge_header_context_identity', function ( $identity ) {
	$desk = go_verge_publisher_current_desk();
	$pillars = go_verge_editorial_pillars();
	return isset( $pillars[ $desk ] ) ? array( 'label' => $pillars[ $desk ]['label'], 'url' => go_verge_v7_category_url( $desk ) ) : $identity;
} );

function go_verge_publisher_navigation() {
	static $groups = null;
	if ( null !== $groups ) { return $groups; }
	$groups = array();
	foreach ( go_verge_v7_nav_blueprint() as $group ) {
		$seen = array();
		$items = array();
		foreach ( $group['items'] as $item ) {
			if ( empty( $item[1] ) || isset( $seen[ $item[1] ] ) ) { continue; }
			$seen[ $item[1] ] = true;
			$items[] = $item;
		}
		$group['items'] = $items;
		$groups[] = $group;
	}
	return $groups;
}

/** Exact page state; articles may open a group without marking its archive as the current page. */
function go_verge_publisher_current_url() {
	$format_url = go_verge_desk_format_canonical_url();
	if ( $format_url ) { return $format_url; }
	if ( is_front_page() ) { return home_url( '/' ); }
	if ( is_singular() ) { return get_permalink(); }
	if ( is_category() || is_tag() || is_tax() ) {
		$url = get_term_link( get_queried_object() );
		return is_wp_error( $url ) ? '' : $url;
	}
	if ( is_post_type_archive() ) {
		$type = get_query_var( 'post_type' );
		return get_post_type_archive_link( is_array( $type ) ? reset( $type ) : $type );
	}
	if ( is_home() ) {
		$id = (int) get_option( 'page_for_posts' );
		return $id ? get_permalink( $id ) : home_url( '/' );
	}
	return '';
}

/** Only link published institutional pages. Custom footer menus still take precedence. */
function go_verge_publisher_page_links( $map ) {
	$links = array();
	foreach ( $map as $slug => $label ) {
		$page = get_page_by_path( $slug );
		if ( $page instanceof WP_Post && 'publish' === get_post_status( $page ) ) {
			$links[] = array( 'label' => $label, 'url' => get_permalink( $page ) );
		}
	}
	return $links;
}

function go_verge_publisher_social_links() {
	$links = go_verge_get_social_links();
	// Preserve the existing publisher X destination when no social menu is configured.
	if ( ! $links && function_exists( 'go_verge_publisher_social_url' ) ) {
		$url = go_verge_publisher_social_url( 'x' );
		if ( $url ) { $links[] = array( 'label' => 'Siga no X', 'url' => $url, 'target' => '_blank' ); }
	}
	// A bare "X" in navigation is ambiguous. Normalize first-party X/Twitter
	// destinations to an action label while preserving every other network.
	foreach ( $links as &$link ) {
		$url   = strtolower( (string) ( $link['url'] ?? '' ) );
		$label = trim( (string) ( $link['label'] ?? '' ) );
		if ( false !== strpos( $url, 'x.com/' ) || false !== strpos( $url, 'twitter.com/' ) || in_array( strtolower( $label ), array( 'x', 'twitter', 'x / twitter', 'x (twitter)' ), true ) ) {
			$link['label'] = 'Siga no X';
		}
	}
	unset( $link );
	return $links;
}
