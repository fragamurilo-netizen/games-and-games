<?php
/** Generic editorial archive fallback. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
?>
<main id="primary" class="go-main">
	<div class="go-container go-pagehead">
		<?php go_verge_breadcrumbs(); ?>
		<h1 class="go-pagehead__title"><?php is_post_type_archive() ? post_type_archive_title() : the_archive_title(); ?></h1>
		<?php if ( get_the_archive_description() ) : ?><div class="go-pagehead__desc"><?php the_archive_description(); ?></div><?php endif; ?>
	</div>
	<div class="go-container go-section go-archive-page">
		<?php if ( have_posts() ) : ?>
			<?php go_verge_render_archive_posts( $wp_query->posts, __( 'Últimas publicações', 'go-verge' ) ); ?>
			<?php go_verge_pagination( null, array(), array( 'media_context' => in_array( go_verge_archive_format_context(), array( 'reviews', 'critiques' ), true ) ? 'card' : 'latest' ) ); ?>
		<?php else : get_template_part( 'template-parts/content', 'none' ); endif; ?>
	</div>
</main>
<?php get_footer(); ?>
