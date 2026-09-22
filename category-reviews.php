<?php
/** Reviews category archive. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$term = get_queried_object();
$url  = $term instanceof WP_Term ? get_term_link( $term ) : home_url( '/reviews/' );
go_verge_render_reviews_landing( single_cat_title( '', false ), true, $url );
