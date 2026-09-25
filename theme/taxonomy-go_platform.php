<?php
/**
 * Platform archive using the same editorial desk shell as /games/.
 *
 * Platforms are real destinations, while content-type controls only refresh
 * the latest-publications feed in place.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

$term = get_queried_object();
get_header();
?>
<main id="primary" class="go-main go-editorial-zone go-editorial-hub go-editorial-zone--games od-platform-page od-platform-page--unified">
	<div class="go-container go-pagehead go-pagehead--search od-desk-pagehead">
		<?php go_verge_breadcrumbs(); ?>
		<div class="od-desk-pagehead__titleline">
			<h1 class="go-pagehead__title"><?php single_term_title(); ?></h1>
			<?php if ( $term instanceof WP_Term && function_exists( 'go_verge_product_follow_button' ) ) : ?>
				<div class="od-desk-pagehead__actions"><?php go_verge_product_follow_button( (int) $term->term_id, 'go_platform', sprintf( __( 'Seguir %s', 'go-verge' ), $term->name ) ); ?></div>
			<?php endif; ?>
		</div>
		<?php if ( $term instanceof WP_Term && trim( (string) $term->description ) ) : ?>
			<div class="go-pagehead__desc"><?php echo wp_kses_post( term_description( $term ) ); ?></div>
		<?php endif; ?>
		<?php go_verge_render_editorial_search(); ?>
		<?php go_verge_render_desk_subjects(); ?>
	</div>

	<div class="go-container go-section go-archive-page">
		<?php if ( function_exists( 'go_verge_render_desk_category' ) && go_verge_desk_format_context() ) : ?>
			<?php go_verge_render_desk_category( $term ); ?>
		<?php elseif ( have_posts() ) : ?>
			<?php go_verge_render_archive_posts( $wp_query->posts, __( 'Últimas publicações', 'go-verge' ) ); ?>
			<?php go_verge_pagination(); ?>
		<?php else : ?>
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
