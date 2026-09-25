<?php
/**
 * Reusable full-width single template for Overdrive Specials.
 *
 * The regular post remains the canonical WordPress object (permalink, author,
 * categories, Yoast, sitemaps, feeds, analytics). Only presentation is replaced.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

while ( have_posts() ) :
	the_post();
	?>
	<main id="primary" class="go-special-page" role="main">
		<?php go_verge_specials_render_current(); ?>
		<?php echo go_verge_specials_author_credit_html( get_the_ID() ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- escaped factual author credit. ?>
	</main>
	<?php
endwhile;

get_footer();
