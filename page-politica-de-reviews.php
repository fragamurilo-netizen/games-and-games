<?php
/** Shared institutional trust page wrapper. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
while ( have_posts() ) { the_post(); get_template_part( 'template-parts/trust-page' ); }
get_footer();
