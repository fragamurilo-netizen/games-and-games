<?php
/**
 * Criticism page fallback for installations that still keep /criticas/ as a Page.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

$go_critics_paged = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
$go_critics_query = go_verge_query_editorial_posts(
	array( 'criticas', 'critica' ),
	10,
	array(
		'paged'         => $go_critics_paged,
		'no_found_rows' => false,
		's'             => go_verge_editorial_search_term(),
	),
	array()
);

if ( function_exists( 'go_verge_render_empty_pagination_404' ) && go_verge_render_empty_pagination_404( $go_critics_query, $go_critics_paged ) ) {
	return;
}

get_header();
?>
<main id="primary" class="go-main go-review-index go-review-index--critique">
	<div class="go-container go-pagehead go-pagehead--search">
		<h1 class="go-pagehead__title"><?php esc_html_e( 'Críticas', 'go-verge' ); ?></h1>
		<?php go_verge_render_editorial_search(); ?>
	</div>
	<div class="go-container go-section go-archive-page" data-go-editorial-results>
		<?php if ( $go_critics_query->have_posts() ) : ?>
			<?php go_verge_render_query_feature_list( $go_critics_query, __( 'Últimas críticas', 'go-verge' ) ); ?>
			<?php go_verge_pagination( $go_critics_query ); ?>
		<?php else : ?>
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
