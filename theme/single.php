<?php
/**
 * Standard post single.
 *
 * Presentation is intentionally thin: data preparation lives in
 * inc/single-clean.php and markup lives in template-parts/single/article.php.
 * Desktop and mobile render the exact same article HTML.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

while ( have_posts() ) :
	the_post();
	if ( post_password_required() ) {
		?><main id="primary" class="go-main"><div class="go-container go-section"><h1><?php the_title(); ?></h1><?php echo get_the_password_form(); ?></div></main><?php
		continue;
	}
	$go_verge_single = go_verge_single_clean_context( get_the_ID() );
	get_template_part( 'template-parts/single/article', null, $go_verge_single );
endwhile;

get_footer();
