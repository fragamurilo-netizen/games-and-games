<?php
/**
 * 3.81.25 — platform truth, navigation parity, promotions admin clarity.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Canonical editorial guides destination — never the buying-guides hub. */
function go_verge_editorial_guides_url() {
	$term = get_term_by( 'slug', 'dicas-e-guias', 'category' );
	if ( $term instanceof WP_Term ) {
		$url = get_term_link( $term );
		if ( ! is_wp_error( $url ) && $url ) { return $url; }
	}
	$term = get_term_by( 'slug', 'guias', 'category' );
	if ( $term instanceof WP_Term ) {
		$url = get_term_link( $term );
		if ( ! is_wp_error( $url ) && $url ) { return $url; }
	}
	return home_url( '/guias/' );
}

/** Map any platform-ish label to the durable hub used by the public taxonomy. */
function go_verge_38125_platform_key_from_text( $text ) {
	$text = strtolower( remove_accents( wp_strip_all_tags( (string) $text ) ) );
	$text = preg_replace( '/\s+/u', ' ', $text );
	$out  = array();
	if ( preg_match( '/\b(?:playstation|ps5(?:\s*pro)?|ps4|ps3|ps\s*vr\s*2|psvr2|ps\s*vita)\b/u', $text ) ) { $out[] = 'playstation'; }
	if ( preg_match( '/\b(?:xbox(?:\s+series\s+[xs])?|xbox\s+one|xbox\s+360|series\s+x\|?s)\b/u', $text ) ) { $out[] = 'xbox'; }
	if ( preg_match( '/\b(?:nintendo|switch(?:\s*2)?|wii\s*u?|3ds|zelda|mario|pokemon|metroid|kirby|splatoon|animal\s+crossing|fire\s+emblem|xenoblade|donkey\s+kong)\b/u', $text ) ) { $out[] = 'nintendo'; }
	if ( preg_match( '/(?:^|[^a-z0-9])pc(?:$|[^a-z0-9])|\b(?:steam|windows|gog|epic\s+games\s+store)\b/u', $text ) ) { $out[] = 'pc'; }
	return array_values( array_unique( $out ) );
}

/** Strong evidence only: linked game / review platform / explicit title wording. */
function go_verge_38125_post_platform_truth( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) { return array(); }
	$parts = array();

	foreach ( array( 'review_platform', 'go_technical_platform', '_go_technical_platform' ) as $key ) {
		$value = trim( (string) get_post_meta( $post_id, $key, true ) );
		if ( '' !== $value ) { $parts[] = $value; }
	}

	$game_id = 0;
	if ( function_exists( 'go_verge_product_linked_game_id' ) ) {
		$game_id = absint( go_verge_product_linked_game_id( $post_id ) );
	}
	if ( ! $game_id ) {
		foreach ( array( 'go_linked_game_id', 'go_review_game_id', '_go_linked_game_id', '_go_review_game_id' ) as $key ) {
			$game_id = absint( get_post_meta( $post_id, $key, true ) );
			if ( $game_id ) { break; }
		}
	}
	if ( $game_id && 'games' === get_post_type( $game_id ) ) {
		foreach ( array( '_go_platforms', '_go_plataforma' ) as $key ) {
			$value = trim( (string) get_post_meta( $game_id, $key, true ) );
			if ( '' !== $value ) { $parts[] = $value; break; }
		}
	}

	/* The headline is strong enough only for explicit platform vocabulary and
	 * durable Nintendo franchises. Body copy is deliberately excluded so a mere
	 * comparison/reference cannot contaminate a platform hub. */
	$parts[] = get_the_title( $post_id );
	$truth = array();
	foreach ( $parts as $part ) {
		$truth = array_merge( $truth, go_verge_38125_platform_key_from_text( $part ) );
	}
	return array_values( array_unique( $truth ) );
}

/** Runtime guard: wrong strong-evidence stories never render in a platform hub. */
function go_verge_38125_filter_platform_archive_posts( $posts, $query ) {
	if ( ! $query instanceof WP_Query ) { return $posts; }
	$is_ajax = function_exists( 'wp_doing_ajax' ) && wp_doing_ajax();
	if ( is_admin() && ! $is_ajax ) { return $posts; }
	if ( ! $query->is_main_query() && ! $is_ajax ) { return $posts; }
	$is_platform = $query->is_tax( 'go_platform' ) || 'go_platform' === (string) $query->get( 'taxonomy' );
	if ( ! $is_platform ) { return $posts; }
	$term = $query->get_queried_object();
	$target = $term instanceof WP_Term ? sanitize_title( $term->slug ) : sanitize_title( (string) $query->get( 'term' ) );
	if ( '' === $target ) { return $posts; }
	$aliases = array(
		'ps5'=>'playstation','ps4'=>'playstation','playstation-5'=>'playstation','playstation-4'=>'playstation',
		'xbox-series'=>'xbox','xbox-series-x'=>'xbox','xbox-series-s'=>'xbox',
		'nintendo-switch'=>'nintendo','nintendo-switch-2'=>'nintendo','switch'=>'nintendo','switch-2'=>'nintendo','pc-gamer'=>'pc',
	);
	$target = $aliases[ $target ] ?? $target;
	if ( ! in_array( $target, array( 'playstation', 'xbox', 'nintendo', 'pc' ), true ) ) { return $posts; }
	return array_values( array_filter( (array) $posts, static function( $post ) use ( $target ) {
		if ( ! $post instanceof WP_Post ) { return true; }
		$truth = go_verge_38125_post_platform_truth( $post->ID );
		return empty( $truth ) || in_array( $target, $truth, true );
	} ) );
}
add_filter( 'the_posts', 'go_verge_38125_filter_platform_archive_posts', 45, 2 );

/** Repair canonical four-platform taxonomy from strong evidence, preserving mobile/etc. */
function go_verge_38125_sync_post_platforms( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || ! taxonomy_exists( 'go_platform' ) ) { return; }
	$truth = go_verge_38125_post_platform_truth( $post_id );
	if ( empty( $truth ) ) { return; }
	$current = wp_get_post_terms( $post_id, 'go_platform', array( 'fields' => 'slugs' ) );
	$current = is_wp_error( $current ) ? array() : array_map( 'sanitize_title', $current );
	$big_four = array( 'playstation', 'xbox', 'nintendo', 'pc', 'ps5', 'ps4', 'playstation-5', 'playstation-4', 'xbox-series', 'xbox-series-x', 'xbox-series-s', 'nintendo-switch', 'nintendo-switch-2', 'switch', 'switch-2', 'pc-gamer' );
	$keep = array_values( array_diff( $current, $big_four ) );
	$desired = array_values( array_unique( array_merge( $keep, $truth ) ) );
	$term_ids = array();
	foreach ( $desired as $slug ) {
		$term = get_term_by( 'slug', $slug, 'go_platform' );
		if ( $term instanceof WP_Term ) { $term_ids[] = (int) $term->term_id; }
	}
	if ( $term_ids ) { wp_set_object_terms( $post_id, $term_ids, 'go_platform', false ); }
}
function go_verge_38125_sync_post_platforms_on_save( $post_id, $post, $update ) {
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! $post instanceof WP_Post || 'post' !== $post->post_type || 'publish' !== $post->post_status ) { return; }
	go_verge_38125_sync_post_platforms( $post_id );
}
add_action( 'save_post_post', 'go_verge_38125_sync_post_platforms_on_save', 80, 3 );

/** Small bounded migration so existing platform hubs clean themselves safely. */
function go_verge_38125_platform_cleanup_batch() {
	if ( ! is_admin() || ! current_user_can( 'edit_posts' ) || ! taxonomy_exists( 'go_platform' ) ) { return; }
	$version = '3.81.25';
	if ( $version === (string) get_option( 'go_verge_platform_truth_version', '' ) ) { return; }
	$queue = get_option( 'go_verge_platform_truth_queue', null );
	if ( ! is_array( $queue ) ) {
		$queue = get_posts( array(
			'post_type'=>'post','post_status'=>'publish','posts_per_page'=>2500,'fields'=>'ids','orderby'=>'ID','order'=>'DESC','no_found_rows'=>true,
			'tax_query'=>array( array( 'taxonomy'=>'go_platform','operator'=>'EXISTS' ) ),
		) );
		$queue = array_values( array_map( 'absint', $queue ) );
	}
	$batch = array_splice( $queue, 0, 60 );
	foreach ( $batch as $post_id ) { go_verge_38125_sync_post_platforms( $post_id ); }
	if ( $queue ) { update_option( 'go_verge_platform_truth_queue', $queue, false ); }
	else { delete_option( 'go_verge_platform_truth_queue' ); update_option( 'go_verge_platform_truth_version', $version, false ); }
}
add_action( 'admin_init', 'go_verge_38125_platform_cleanup_batch', 88 );

/** Clearer promotion vocabulary in wp-admin. */
function go_verge_38125_promotion_labels( $labels ) {
	$labels->name               = __( 'Ofertas de jogos', 'go-verge' );
	$labels->singular_name      = __( 'Oferta de jogo', 'go-verge' );
	$labels->menu_name          = __( 'Ofertas de jogos', 'go-verge' );
	$labels->all_items          = __( 'Todas as ofertas', 'go-verge' );
	$labels->add_new            = __( 'Adicionar oferta', 'go-verge' );
	$labels->add_new_item       = __( 'Adicionar oferta de jogo', 'go-verge' );
	$labels->edit_item          = __( 'Editar oferta', 'go-verge' );
	$labels->new_item           = __( 'Nova oferta de jogo', 'go-verge' );
	$labels->view_item          = __( 'Ver oferta', 'go-verge' );
	$labels->search_items       = __( 'Buscar ofertas de jogos', 'go-verge' );
	$labels->not_found          = __( 'Nenhuma oferta encontrada', 'go-verge' );
	$labels->not_found_in_trash = __( 'Nenhuma oferta na lixeira', 'go-verge' );
	return $labels;
}
add_filter( 'post_type_labels_go_promotion', 'go_verge_38125_promotion_labels', 100 );

/** Also mutate the registered object in case another component registered the CPT first. */
function go_verge_38125_promotion_registered_labels( $post_type, $object ) {
	if ( 'go_promotion' !== $post_type || ! is_object( $object ) || empty( $object->labels ) ) { return; }
	$object->labels = go_verge_38125_promotion_labels( $object->labels );
	$object->label  = $object->labels->name;
}
add_action( 'registered_post_type_go_promotion', 'go_verge_38125_promotion_registered_labels', 100, 2 );

/** Admin-only polish for the existing promotion details box, regardless of provider. */
function go_verge_38125_promotion_admin_assets( $hook ) {
	if ( ! in_array( $hook, array( 'post.php', 'post-new.php' ), true ) ) { return; }
	$screen = get_current_screen();
	if ( ! $screen || 'go_promotion' !== $screen->post_type ) { return; }
	$css = '/assets/css/promotion-admin-38125.css';
	$js  = '/assets/js/promotion-admin-38125.js';
	wp_enqueue_style( 'go-verge-promotion-admin-38125', GO_VERGE_URI . $css, array(), go_verge_asset_version( $css ) );
	wp_enqueue_script( 'go-verge-promotion-admin-38125', GO_VERGE_URI . $js, array(), go_verge_asset_version( $js ), true );
}
add_action( 'admin_enqueue_scripts', 'go_verge_38125_promotion_admin_assets', 100 );
