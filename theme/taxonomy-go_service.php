<?php
/**
 * Service editorial hub.
 *
 * A compact, brand-aware masthead keeps the taxonomy useful without turning
 * it into a technical profile. The regular archive hero directly below owns
 * the editorial weight of the page.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

get_header();

$term = get_queried_object();
$slug = $term instanceof WP_Term ? sanitize_title( $term->slug ) : '';
$name = $term instanceof WP_Term ? $term->name : single_term_title( '', false );

$description = '';
if ( $term instanceof WP_Term && trim( (string) $term->description ) ) {
	$description = wp_trim_words( wp_strip_all_tags( term_description( $term ) ), 28, '…' );
}
if ( ! $description && function_exists( 'go_verge_v42_service_fallback_description' ) ) {
	$description = go_verge_v42_service_fallback_description( $slug, $name );
}
if ( ! $description ) {
	$description = sprintf( __( 'Notícias, estreias e novidades de %s.', 'go-verge' ), $name );
}

$topics = function_exists( 'go_verge_v42_service_top_topics' ) && $term instanceof WP_Term
	? go_verge_v42_service_top_topics( $wp_query->posts, $term, 5 )
	: array();
?>
<main id="primary" class="go-main go-v7-hub go-v7-tax-hub go-v7-service-hub" data-service="<?php echo esc_attr( $slug ); ?>">
	<section class="go-v7-service-head" aria-labelledby="go-service-title">
		<div class="go-container">
			<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
			<div class="go-v7-service-head__inner">
				<div class="go-v7-service-head__copy">
					<h1 id="go-service-title"><?php echo esc_html( $name ); ?></h1>
					<p class="go-v7-service-head__dek"><?php echo esc_html( $description ); ?></p>
					<?php if ( $term instanceof WP_Term && function_exists( 'go_verge_product_follow_button' ) ) : ?>
						<div class="go-entity-hero-v40__actions go-v47-service-follow"><?php go_verge_product_follow_button( (int) $term->term_id, 'go_service', sprintf( __( 'Seguir %s', 'go-verge' ), $name ) ); ?></div>
					<?php endif; ?>
				</div>
			</div>

			<?php if ( $topics ) : ?>
				<nav class="go-v7-service-topics" aria-label="<?php esc_attr_e( 'Assuntos relacionados', 'go-verge' ); ?>">
					<?php foreach ( $topics as $topic ) : ?>
						<a href="<?php echo esc_url( $topic['url'] ); ?>"><?php echo esc_html( $topic['label'] ); ?></a>
					<?php endforeach; ?>
				</nav>
			<?php endif; ?>
		</div>
	</section>

	<div class="go-container go-section go-archive-page">
		<?php if ( have_posts() ) : ?>
			<?php if ( function_exists( 'go_verge_render_archive_posts' ) ) { go_verge_render_archive_posts( $wp_query->posts, 'Últimas publicações' ); } ?>
			<?php if ( function_exists( 'go_verge_pagination' ) ) { go_verge_pagination(); } else { the_posts_pagination(); } ?>
		<?php else : ?>
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
