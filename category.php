<?php
/**
 * Editorial category archive: one visual feature followed by a horizontal
 * latest-publications list.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$go_verge_term     = get_queried_object();
$go_verge_platform = $go_verge_term instanceof WP_Term ? go_verge_platform_entity_for_category( $go_verge_term->slug ) : null;

get_header();
?>
<main id="primary" class="go-main">
	<div class="go-container go-pagehead go-pagehead--search<?php echo $go_verge_platform ? ' go-pagehead--platform' : ''; ?>">
		<?php go_verge_breadcrumbs(); ?>
		<h1 class="go-pagehead__title"><?php single_cat_title(); ?></h1>
		<?php
		$go_verge_page_desc = '';
		if ( $go_verge_term instanceof WP_Term && function_exists( 'go_verge_38126_archive_description' ) ) {
			$go_verge_page_desc = go_verge_38126_archive_description( $go_verge_term );
		} elseif ( category_description() ) {
			$go_verge_page_desc = trim( wp_strip_all_tags( category_description() ) );
		}
		?>
		<?php if ( $go_verge_page_desc ) : ?><div class="go-pagehead__desc"><?php echo esc_html( $go_verge_page_desc ); ?></div><?php endif; ?>
		<?php go_verge_render_editorial_search(); ?>
		<?php go_verge_render_desk_subjects(); ?>
		<?php if ( $go_verge_term instanceof WP_Term && 'especiais' === $go_verge_term->slug && go_verge_specials_gallery_url() ) : ?><p><a href="<?php echo esc_url( go_verge_specials_gallery_url() ); ?>"><?php esc_html_e( 'Explore nossos especiais visuais', 'go-verge' ); ?> <?php echo go_verge_icon( 'seta-direita' ); ?></a></p><?php endif; ?>

	</div>


	<?php if ( $go_verge_term instanceof WP_Term && function_exists( 'go_verge_platform_key_for_term' ) && go_verge_platform_key_for_term( $go_verge_term ) ) : ?>
		<div class="go-container go-platform-ecosystem-wrap">
			<?php go_verge_render_platform_ecosystem( $go_verge_term ); ?>
		</div>
	<?php endif; ?>

	<?php
	$go_verge_is_offers_hub = $go_verge_term instanceof WP_Term && in_array( $go_verge_term->slug, array( 'ofertas', 'promocoes' ), true );
	$go_verge_archive_page  = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	?>
	<?php if ( $go_verge_is_offers_hub && 1 === $go_verge_archive_page ) : ?>
		<section class="go-container go-section go-offers-commerce-v73">
			<nav class="go-promotions-nav go-offers-commerce-v73__nav" aria-label="<?php esc_attr_e( 'Atalhos de promoções', 'go-verge' ); ?>">
				<a href="#cupons"><?php esc_html_e( 'Cupons', 'go-verge' ); ?></a>
				<a href="#ultimas-ofertas"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></a>
			</nav>
			<div id="cupons" class="go-promotions-section-anchor">
				<?php if ( function_exists( 'go_verge_render_coupon_center' ) ) { go_verge_render_coupon_center(); } ?>
			</div>
		</section>
	<?php endif; ?>

	<div id="<?php echo $go_verge_is_offers_hub ? 'ultimas-ofertas' : 'arquivo-editorial'; ?>" class="go-container go-section go-archive-page" data-go-editorial-results data-term-slug="<?php echo esc_attr( $go_verge_term instanceof WP_Term ? $go_verge_term->slug : '' ); ?>" data-per-page="<?php echo esc_attr( max( 1, (int) $wp_query->get( 'posts_per_page' ) ) ); ?>">
		<?php if ( go_verge_desk_format_context() ) : ?>
			<?php go_verge_render_desk_category( $go_verge_term ); ?>
		<?php elseif ( have_posts() ) : ?>
			<?php go_verge_render_archive_posts( $wp_query->posts, __( 'Últimas publicações', 'go-verge' ) ); ?>
			<?php go_verge_pagination( null, array(), array( 'media_context' => in_array( go_verge_archive_format_context(), array( 'reviews', 'critiques' ), true ) ? 'card' : 'latest' ) ); ?>
		<?php else : ?>
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
