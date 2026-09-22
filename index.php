<?php
/**
 * Universal fallback template (required by WordPress).
 * front-page.php, category.php, single.php etc. take over their contexts;
 * this only renders when nothing more specific matches.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( is_home() && ! is_front_page() ) {
	require get_template_directory() . '/page-template/template-latest.php';
	return;
}

get_header();
?>

<main id="primary" class="go-main">
	<div class="go-container">

		<?php if ( is_home() && ! is_front_page() ) : ?>
			<div class="go-pagehead">
				<h1 class="go-pagehead__title"><?php esc_html_e( 'Últimas', 'go-verge' ); ?></h1>
			</div>
		<?php endif; ?>

		<?php if ( have_posts() ) : ?>
			<ul class="go-stream go-section">
				<?php
				$go_verge_i = 0;
				while ( have_posts() ) :
					the_post();
					go_verge_stream_item( array(
						'id'           => get_the_ID(),
						'show_excerpt' => true,
					) );
					$go_verge_i++;
				endwhile;
				?>
			</ul>
			<?php go_verge_pagination( null, array(), array( 'mode' => 'stream', 'target' => '.go-stream' ) ); ?>
		<?php else : ?>
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		<?php endif; ?>

	</div>
</main>

<?php
get_footer();
