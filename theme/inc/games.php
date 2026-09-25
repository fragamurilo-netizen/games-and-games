<?php
/**
 * Games CPT data: reads the rich meta schema already populated by the
 * editorial workflow (platforms, developer, publisher, genre, price, store
 * links, gallery, trailer) — same "read what's already there" approach as
 * inc/reviews.php.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * First non-empty value across a list of candidate meta keys.
 */
function go_verge_game_meta( $post_id, $keys ) {
	$keys    = (array) $keys;
	$cleared = get_post_meta( $post_id, '_go_editor_cleared_fields', true );
	$cleared = is_array( $cleared ) ? array_map( 'sanitize_key', $cleared ) : array();
	if ( ! empty( $keys[0] ) && in_array( sanitize_key( $keys[0] ), $cleared, true ) ) {
		return '';
	}
	foreach ( $keys as $key ) {
		$value = get_post_meta( $post_id, $key, true );
		if ( '' !== trim( wp_strip_all_tags( (string) $value ) ) ) {
			return $value;
		}
	}
	return '';
}

/**
 * Gather a game's structured data into one array.
 */
function go_verge_game_data( $post_id = null ) {
	$post_id = $post_id ? $post_id : get_the_ID();

	$gallery_raw = go_verge_game_meta( $post_id, array( '_go_gallery' ) );
	$gallery     = array();
	if ( '' !== $gallery_raw ) {
		$gallery = array_values( array_filter( array_map( 'trim', preg_split( '/\r\n|\r|\n/', $gallery_raw ) ) ) );
	}

	$store_links_raw = get_post_meta( $post_id, '_go_store_links', true );
	$store_links      = maybe_unserialize( $store_links_raw );
	if ( ! is_array( $store_links ) ) {
		$store_links = array();
	}

	return array(
		'title'         => function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $post_id ) : get_the_title( $post_id ),
		'release_date'  => go_verge_game_meta( $post_id, array( '_go_release_date', '_go_data_lancamento' ) ),
		'release_status' => go_verge_game_meta( $post_id, array( '_go_release_status' ) ),
		'early_access'  => go_verge_game_meta( $post_id, array( '_go_early_access_date' ) ),
		'developer'     => go_verge_game_meta( $post_id, array( '_go_developer', '_go_desenvolvedora' ) ),
		'publisher'     => go_verge_game_meta( $post_id, array( '_go_publisher' ) ),
		'distributor'   => go_verge_game_meta( $post_id, array( '_go_distributor' ) ),
		'director'      => go_verge_game_meta( $post_id, array( '_go_director' ) ),
		'engine'        => go_verge_game_meta( $post_id, array( '_go_engine' ) ),
		'country'       => go_verge_game_meta( $post_id, array( '_go_country' ) ),
		'platforms'     => function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( go_verge_game_meta( $post_id, array( '_go_platforms', '_go_plataforma' ) ) ) : go_verge_game_meta( $post_id, array( '_go_platforms', '_go_plataforma' ) ),
		'genres'        => function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( go_verge_game_meta( $post_id, array( '_go_genres' ) ) ) : go_verge_game_meta( $post_id, array( '_go_genres' ) ),
		'modes'         => function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( go_verge_game_meta( $post_id, array( '_go_modes' ) ) ) : go_verge_game_meta( $post_id, array( '_go_modes' ) ),
		'primary_genre' => go_verge_game_meta( $post_id, array( '_go_primary_genre' ) ),
		'perspective'   => go_verge_game_meta( $post_id, array( '_go_perspective' ) ),
		'online'        => function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( go_verge_game_meta( $post_id, array( '_go_online_features' ) ) ) : go_verge_game_meta( $post_id, array( '_go_online_features' ) ),
		'players'       => go_verge_game_meta( $post_id, array( '_go_players' ) ),
		'languages'     => function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( go_verge_game_meta( $post_id, array( '_go_languages' ) ) ) : go_verge_game_meta( $post_id, array( '_go_languages' ) ),
		'age_rating'    => go_verge_game_meta( $post_id, array( '_go_age_rating' ) ),
		'price'         => go_verge_game_meta( $post_id, array( '_go_price' ) ),
		'summary'       => go_verge_game_meta( $post_id, array( '_go_summary' ) ),
		'trailer_url'   => go_verge_game_meta( $post_id, array( '_go_trailer_url', 'go_trailer_url' ) ),
		'gallery'       => $gallery,
		'store_links'   => $store_links,
		'accent_color'  => go_verge_game_meta( $post_id, array( '_go_theme_accent_color' ) ),
		'franchise'     => go_verge_game_meta( $post_id, array( 'go_game_franchise_name' ) ),
		'edition'       => go_verge_game_meta( $post_id, array( '_go_edition' ) ),
		'content_type'  => go_verge_game_meta( $post_id, array( '_go_content_type' ) ),
		'parent_game'   => absint( go_verge_game_meta( $post_id, array( '_go_parent_game_id' ) ) ),
		'hero_image_id' => absint( go_verge_game_meta( $post_id, array( '_go_hero_image_id' ) ) ),
		'logo_id'       => absint( go_verge_game_meta( $post_id, array( '_go_logo_id' ) ) ),
		'official_site' => go_verge_game_meta( $post_id, array( '_go_official_site_url' ) ),
		'subscriptions' => function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( go_verge_game_meta( $post_id, array( '_go_subscription_services' ) ) ) : go_verge_game_meta( $post_id, array( '_go_subscription_services' ) ),
		'coop'          => '1' === (string) get_post_meta( $post_id, '_go_coop', true ),
		'cross_play'    => '1' === (string) get_post_meta( $post_id, '_go_cross_play', true ),
		'cross_save'    => '1' === (string) get_post_meta( $post_id, '_go_cross_save', true ),
		'shared_progression' => '1' === (string) get_post_meta( $post_id, '_go_shared_progression', true ),
		'ptbr_subtitles' => '1' === (string) get_post_meta( $post_id, '_go_ptbr_subtitles', true ),
		'ptbr_dubbing'  => '1' === (string) get_post_meta( $post_id, '_go_ptbr_dubbing', true ),
		'physical'      => '1' === (string) get_post_meta( $post_id, '_go_physical_edition', true ),
		'digital'       => '1' === (string) get_post_meta( $post_id, '_go_digital_edition', true ),
	);
}


/**
 * Best-effort parser for the release-date formats already stored by the old
 * editorial workflow. Returns 0 when the value cannot be safely normalized.
 */
function go_verge_game_release_timestamp( $value ) {
	$value = trim( wp_strip_all_tags( (string) $value ) );
	if ( '' === $value ) {
		return 0;
	}

	$formats = array( 'Y-m-d', 'd/m/Y', 'd-m-Y', 'Y/m/d', 'm/d/Y' );
	foreach ( $formats as $format ) {
		$date = DateTime::createFromFormat( '!' . $format, $value, wp_timezone() );
		if ( $date instanceof DateTime ) {
			return $date->getTimestamp();
		}
	}

	$timestamp = strtotime( $value );
	return false === $timestamp ? 0 : (int) $timestamp;
}

/**
 * Human release date for display. Parseable values render as dd/mm/yyyy in the
 * site language; free-form values ("2026", "TBA") pass through untouched.
 */
function go_verge_game_release_display( $value ) {
	$value = trim( wp_strip_all_tags( (string) $value ) );
	if ( '' === $value ) {
		return '';
	}
	$timestamp = go_verge_game_release_timestamp( $value );
	return $timestamp ? date_i18n( 'd/m/Y', $timestamp ) : $value;
}

/**
 * YouTube URL → embeddable URL, or '' if not recognized.
 */
function go_verge_youtube_embed_url( $url ) {
	if ( '' === trim( (string) $url ) ) {
		return '';
	}
	if ( preg_match( '#(?:youtu\.be/|youtube\.com/watch\?v=|youtube\.com/embed/)([A-Za-z0-9_-]{6,})#', $url, $m ) ) {
		return 'https://www.youtube.com/embed/' . $m[1];
	}
	return '';
}

/**
 * Normalize title/name fields in game-related REST payloads before JSON is
 * generated. This covers internal libraries and external providers while the
 * consuming JavaScript can continue using textContent or normal HTML escaping.
 */
if ( ! function_exists( 'go_verge_prepare_game_rest_payload' ) ) {
	function go_verge_prepare_game_rest_payload( $value, $key = '' ) {
		if ( is_array( $value ) ) {
			foreach ( $value as $child_key => $child_value ) {
				$is_name_context = in_array( $key, array( 'title', 'name', 'game_name', 'display_name' ), true );
				$context_key     = $is_name_context && ! ( 'title' === $key && 'raw' === (string) $child_key ) ? $key : (string) $child_key;
				$value[ $child_key ] = go_verge_prepare_game_rest_payload( $child_value, $context_key );
			}
			return $value;
		}
		if ( is_object( $value ) ) {
			foreach ( get_object_vars( $value ) as $child_key => $child_value ) {
				$is_name_context = in_array( $key, array( 'title', 'name', 'game_name', 'display_name' ), true );
				$context_key     = $is_name_context && ! ( 'title' === $key && 'raw' === (string) $child_key ) ? $key : (string) $child_key;
				$value->{$child_key} = go_verge_prepare_game_rest_payload( $child_value, $context_key );
			}
			return $value;
		}
		return is_string( $value ) && in_array( $key, array( 'title', 'name', 'game_name', 'display_name' ), true )
			? go_verge_prepare_game_name( $value )
			: $value;
	}
}

if ( ! function_exists( 'go_verge_normalize_game_rest_response' ) ) {
	function go_verge_normalize_game_rest_response( $response, $server, $request ) {
		$route = $request instanceof WP_REST_Request ? (string) $request->get_route() : '';
		if ( ! preg_match( '#(?:game|games|steam|go-gs)#i', $route ) || ! is_a( $response, 'WP_HTTP_Response' ) ) {
			return $response;
		}
		$response->set_data( go_verge_prepare_game_rest_payload( $response->get_data() ) );
		return $response;
	}
}
add_filter( 'rest_post_dispatch', 'go_verge_normalize_game_rest_response', 20, 3 );

if ( ! function_exists( 'go_verge_normalize_game_archive_title' ) ) {
	/** Keep franchise/platform archive headings readable when legacy terms contain entities. */
	function go_verge_normalize_game_archive_title( $title ) {
		return is_tax( array( 'game_platform', 'game_franchise', 'game_status' ) )
			? go_verge_prepare_game_name( $title )
			: $title;
	}
}
add_filter( 'get_the_archive_title', 'go_verge_normalize_game_archive_title', 20 );

if ( ! function_exists( 'go_verge_normalize_admin_game_query_titles' ) ) {
	/**
	 * Some admin matchers read WP_Post::post_title directly instead of calling
	 * get_the_title(). Normalize those in-memory query objects for display/AJAX;
	 * no database value is changed.
	 */
	function go_verge_normalize_admin_game_query_titles( $posts ) {
		if ( ! is_admin() || ! is_array( $posts ) ) {
			return $posts;
		}
		foreach ( $posts as $post ) {
			if ( $post instanceof WP_Post && 'games' === $post->post_type ) {
				$post->post_title = go_verge_prepare_game_name( $post->post_title );
			}
		}
		return $posts;
	}
}
add_filter( 'posts_results', 'go_verge_normalize_admin_game_query_titles', 20 );
