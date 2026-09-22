<?php
/**
 * 3.81.20 Discover recovery hardening.
 *
 * No code can guarantee Discover distribution. This module only removes
 * technical ambiguity: published stories explicitly allow large previews and
 * recent featured images get their high-resolution 16:9 derivative backfilled
 * in tiny admin-side batches when the source is large enough.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Reinforce large image preview permission at HTTP level for canonical posts. */
function go_verge_discover_recovery_headers_38120() {
	if ( headers_sent() || ! is_singular( 'post' ) || post_password_required() ) { return; }
	$post_id = absint( get_queried_object_id() );
	if ( ! $post_id || 'publish' !== get_post_status( $post_id ) ) { return; }
	header( 'X-Robots-Tag: max-image-preview:large, max-snippet:-1, max-video-preview:-1', false );
}
add_action( 'template_redirect', 'go_verge_discover_recovery_headers_38120', 30 );

/** Backfill at most two recent high-resolution featured images per admin request. */
function go_verge_discover_recovery_backfill_38120() {
	if ( ! current_user_can( 'manage_options' ) || wp_doing_ajax() ) { return; }
	$last = (int) get_transient( 'go_verge_discover_backfill_38120_lock' );
	if ( $last ) { return; }
	set_transient( 'go_verge_discover_backfill_38120_lock', 1, 10 * MINUTE_IN_SECONDS );

	$posts = get_posts( array(
		'post_type' => 'post', 'post_status' => 'publish', 'posts_per_page' => 60,
		'orderby' => 'date', 'order' => 'DESC', 'fields' => 'ids', 'no_found_rows' => true,
		'update_post_meta_cache' => true, 'update_post_term_cache' => false,
	) );
	$done = 0;
	foreach ( $posts as $post_id ) {
		$attachment_id = absint( get_post_thumbnail_id( $post_id ) );
		if ( ! $attachment_id ) { continue; }
		$meta = wp_get_attachment_metadata( $attachment_id );
		if ( ! is_array( $meta ) || absint( $meta['width'] ?? 0 ) < 1200 ) { continue; }
		$crop = image_get_intermediate_size( $attachment_id, 'go_discover_16x9' );
		if ( is_array( $crop ) && ! empty( $crop['file'] ) && absint( $crop['width'] ?? 0 ) >= 1200 ) { continue; }
		if ( ! function_exists( 'wp_update_image_subsizes' ) || ! function_exists( 'wp_get_missing_image_subsizes' ) ) {
			require_once ABSPATH . 'wp-admin/includes/image.php';
		}
		$missing = function_exists( 'wp_get_missing_image_subsizes' ) ? wp_get_missing_image_subsizes( $attachment_id ) : array();
		$wanted = array_intersect_key( (array) $missing, array( 'go_hero'=>true, 'go_discover_16x9'=>true ) );
		if ( ! $wanted || ! function_exists( 'wp_update_image_subsizes' ) ) { continue; }
		$limit = static function( $sizes ) use ( $wanted ) { return array_intersect_key( (array) $sizes, $wanted ); };
		add_filter( 'wp_get_missing_image_subsizes', $limit, 999 );
		wp_update_image_subsizes( $attachment_id );
		remove_filter( 'wp_get_missing_image_subsizes', $limit, 999 );
		if ( ++$done >= 2 ) { break; }
	}
}
add_action( 'admin_init', 'go_verge_discover_recovery_backfill_38120', 35 );
