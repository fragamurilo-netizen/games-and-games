<?php
/** Bounded title index: typing never joins content, taxonomy or metadata tables. */
defined( 'ABSPATH' ) || exit;

function go_verge_suggestion_normalize( $text ) {
	$text = remove_accents( html_entity_decode( wp_strip_all_tags( $text ), ENT_QUOTES, 'UTF-8' ) );
	return function_exists( 'mb_strtolower' ) ? mb_strtolower( $text, 'UTF-8' ) : strtolower( $text );
}

function go_verge_suggestion_catalog() {
	global $wpdb;
	$cached = get_transient( 'go_search_titles_383' );
	if ( is_array( $cached ) ) { return $cached; }
	$key = 'go_search_titles_383_lock';
	$lease = (string) ( time() + 30 ) . ':' . wp_generate_uuid4();
	$old = get_option( $key );
	if ( $old && (int) $old < time() ) {
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", $key, $old ) );
		wp_cache_delete( $key, 'options' );
	}
	if ( ! add_option( $key, $lease, '', false ) ) { return array(); }
	try {
		$types = go_verge_search_post_types();
		$marks = implode( ',', array_fill( 0, count( $types ), '%s' ) );
		$rows = $wpdb->get_results( $wpdb->prepare(
			"SELECT ID, post_title FROM {$wpdb->posts} WHERE post_status='publish' AND post_password='' AND post_type IN ($marks) ORDER BY post_date DESC LIMIT 20000",
			$types
		), ARRAY_A );
		$catalog = array();
		foreach ( (array) $rows as $row ) {
			$catalog[] = array( (int) $row['ID'], go_verge_suggestion_normalize( $row['post_title'] ) );
		}
		if ( ! $wpdb->last_error ) { set_transient( 'go_search_titles_383', $catalog, 10 * MINUTE_IN_SECONDS ); }
		return $catalog;
	} finally {
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", $key, $lease ) );
		wp_cache_delete( $key, 'options' );
	}
}

function go_verge_rest_search_suggestions( WP_REST_Request $request ) {
	$raw = $request->get_param( 'q' );
	if ( ! is_scalar( $raw ) ) { return rest_ensure_response( array() ); }
	$needle = go_verge_suggestion_normalize( trim( sanitize_text_field( (string) $raw ) ) );
	$length = function_exists( 'mb_strlen' ) ? mb_strlen( $needle ) : strlen( $needle );
	if ( $length < 3 || $length > 80 ) { return rest_ensure_response( array() ); }
	$limit = min( 10, max( 4, absint( $request->get_param( 'limit' ) ) ?: 8 ) );
	$ranked = array( array(), array(), array() );
	foreach ( go_verge_suggestion_catalog() as $row ) {
		$offset = strpos( $row[1], $needle );
		if ( false === $offset ) { continue; }
		$rank = $row[1] === $needle ? 0 : ( 0 === $offset ? 1 : 2 );
		// Bound candidates while leaving room to exclude posts unpublished since indexing.
		if ( count( $ranked[ $rank ] ) < $limit * 3 ) { $ranked[ $rank ][] = $row[0]; }
	}
	$results = array();
	foreach ( array_merge( ...$ranked ) as $id ) {
		$post = get_post( $id );
		if ( ! $post || 'publish' !== $post->post_status || '' !== $post->post_password || ! in_array( $post->post_type, go_verge_search_post_types(), true ) ) { continue; }
		$results[] = array(
			'id' => $id,
			'title' => html_entity_decode( wp_strip_all_tags( get_the_title( $id ) ), ENT_QUOTES, 'UTF-8' ),
			'url' => get_permalink( $id ),
			'type' => go_verge_search_result_type_label( $post->post_type ),
			'kind' => 'content',
			'image_url' => get_the_post_thumbnail_url( $id, 'thumbnail' ) ?: '',
		);
		if ( count( $results ) >= $limit ) { break; }
	}
	return rest_ensure_response( $results );
}
