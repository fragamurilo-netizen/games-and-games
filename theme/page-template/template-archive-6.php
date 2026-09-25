<?php
/**
 * Template Name: Archive style 6
 *
 * Shared editorial archive presentation: one feature followed by a list.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$go_verge_paged = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
$go_verge_archive_query = new WP_Query(
	array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => (int) get_option( 'posts_per_page', 10 ),
		'paged'               => $go_verge_paged,
		'ignore_sticky_posts' => true,
	)
);

if ( function_exists( 'go_verge_render_empty_pagination_404' ) && go_verge_render_empty_pagination_404( $go_verge_archive_query, $go_verge_paged ) ) {
	return;
}

get_header();
?>
<main id="primary" class="go-main">
	<div class="go-container go-pagehead">
		<h1 class="go-pagehead__title"><?php the_title(); ?></h1>
	</div>
	<div class="go-container go-section go-archive-page">
		<?php if ( $go_verge_archive_query->have_posts() ) : ?>
			<?php go_verge_render_query_feature_list( $go_verge_archive_query, __( 'Últimas publicações', 'go-verge' ) ); ?>
			<?php go_verge_pagination( $go_verge_archive_query ); ?>
		<?php else : ?>
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
