<?php
/** Reviews page fallback. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$object = get_queried_object();
$title  = $object instanceof WP_Post ? $object->post_title : __( 'Reviews', 'go-verge' );
$url    = $object instanceof WP_Post ? get_permalink( $object ) : home_url( '/reviews/' );
go_verge_render_reviews_landing( $title, false, $url );
