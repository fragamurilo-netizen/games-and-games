<?php
/** Criticism archive. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
?>
<main id="primary" class="go-main go-review-index go-review-index--critique">
	<div class="go-container go-pagehead go-pagehead--search">
		<?php go_verge_breadcrumbs(); ?>
		<h1 class="go-pagehead__title"><?php single_cat_title(); ?></h1>
		<?php go_verge_render_editorial_search(); ?>
	</div>
	<div class="go-container go-section go-archive-page" data-go-editorial-results>
		<?php if ( have_posts() ) : ?>
			<?php go_verge_render_archive_posts( $wp_query->posts, __( 'Últimas críticas', 'go-verge' ) ); ?>
			<?php go_verge_pagination(); ?>
		<?php else : get_template_part( 'template-parts/content', 'none' ); endif; ?>
	</div>
</main>
<?php get_footer(); ?>
