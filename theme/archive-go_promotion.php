<?php
/**
 * Promotions hub: Nuuvem coupon radar plus editorial promotion articles only.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

get_header();

$go_promo_paged = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
$go_promo_extra = array(
	'paged'         => $go_promo_paged,
	'no_found_rows' => false,
);

$go_promo_subcategory = isset( $_GET['subcategoria'] )
	? sanitize_title( wp_unslash( $_GET['subcategoria'] ) )
	: ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended

$go_promo_allowed_subcategories = array(
	'jogos-gratis',
	'guias-de-compra-2',
	'guias-de-compra',
	'guia-de-compra',
);
if ( $go_promo_subcategory && in_array( $go_promo_subcategory, $go_promo_allowed_subcategories, true ) ) {
	$go_promo_term = get_term_by( 'slug', $go_promo_subcategory, 'category' );
	if ( $go_promo_term instanceof WP_Term ) {
		$go_promo_extra['tax_query'] = array(
			array(
				'taxonomy'         => 'category',
				'field'            => 'term_id',
				'terms'            => array( (int) $go_promo_term->term_id ),
				'include_children' => true,
			),
		);
	}
}

$go_promo_articles = go_verge_query_promotion_articles( 10, $go_promo_extra );
?>
<main id="primary" class="go-main">
	<div class="go-container go-pagehead">
		<h1 class="go-pagehead__title"><?php esc_html_e( 'Promoções', 'go-verge' ); ?></h1>
	</div>

	<div class="go-container go-section go-promotions-page">
		<?php
		$go_promo_base_url = get_post_type_archive_link( 'go_promotion' );
		$go_free_url = add_query_arg( 'subcategoria', 'jogos-gratis', $go_promo_base_url );
		$go_buying_term = null;
		foreach ( array( 'guias-de-compra-2', 'guias-de-compra', 'guia-de-compra' ) as $go_buying_slug ) {
			$go_candidate_term = get_term_by( 'slug', $go_buying_slug, 'category' );
			if ( $go_candidate_term instanceof WP_Term ) { $go_buying_term = $go_candidate_term; break; }
		}
		$go_buying_url = $go_buying_term instanceof WP_Term ? add_query_arg( 'subcategoria', $go_buying_term->slug, $go_promo_base_url ) : home_url( '/guias-de-compra/' );
		?>
		<nav class="go-promotions-nav" aria-label="<?php esc_attr_e( 'Navegação de promoções', 'go-verge' ); ?>">
			<a href="<?php echo esc_url( $go_promo_base_url ); ?>" data-go-category-access-filter=""<?php echo '' === $go_promo_subcategory ? ' class="is-active" aria-current="page"' : ''; ?>><?php esc_html_e( 'Tudo', 'go-verge' ); ?></a>
			<a href="#cupons"><?php esc_html_e( 'Cupons', 'go-verge' ); ?></a>
			<a href="<?php echo esc_url( $go_free_url ); ?>"<?php echo 'jogos-gratis' === $go_promo_subcategory ? ' class="is-active" aria-current="page"' : ''; ?> data-go-category-access-filter="jogos-gratis"><?php esc_html_e( 'Jogos grátis', 'go-verge' ); ?></a>
			<a href="<?php echo esc_url( $go_buying_url ); ?>"<?php echo $go_buying_term instanceof WP_Term && $go_buying_term->slug === $go_promo_subcategory ? ' class="is-active" aria-current="page"' : ''; ?><?php echo $go_buying_term instanceof WP_Term ? ' data-go-category-access-filter="' . esc_attr( $go_buying_term->slug ) . '"' : ''; ?>><?php esc_html_e( 'Guias de compra', 'go-verge' ); ?></a>
		</nav>


		<div id="cupons" class="go-promotions-section-anchor"><?php if ( function_exists( 'go_verge_render_coupon_center' ) ) { go_verge_render_coupon_center(); } ?></div>

		<?php if ( 1 === $go_promo_paged && '' === $go_promo_subcategory && function_exists( 'go_verge_render_store_promotions_v19' ) ) : ?>
			<div id="ofertas-plataformas" class="go-promotions-section-anchor">
				<?php go_verge_render_store_promotions_v19( 12, false ); ?>
			</div>
		<?php endif; ?>

		<?php
		if ( 1 === $go_promo_paged && function_exists( 'go_verge_render_category_access_sections' ) ) {
			go_verge_render_category_access_sections(
				array(
					array(
						'label'  => __( 'Jogos grátis', 'go-verge' ),
						'slugs'  => array( 'jogos-gratis' ),
						'accent' => 'free-games',
					),
					array(
						'label'  => __( 'Guias de compra', 'go-verge' ),
						'slugs'  => array( 'guias-de-compra-2', 'guias-de-compra', 'guia-de-compra' ),
						'accent' => 'buying',
					),
				),
				'promotions',
				get_post_type_archive_link( 'go_promotion' )
			);
		}
		?>

		<div id="publicacoes-promocoes" data-go-promotion-results aria-live="polite">
			<section class="go-archive-section" aria-labelledby="go-promo-latest-title">
				<div class="go-section__head"><h2 id="go-promo-latest-title" class="go-section__title"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2></div>
				<?php if ( $go_promo_articles->have_posts() ) : ?>
					<?php go_verge_render_query_list( $go_promo_articles, true ); ?>
					<?php go_verge_pagination( $go_promo_articles ); ?>
				<?php else : ?>
					<?php get_template_part( 'template-parts/content', 'none' ); ?>
				<?php endif; ?>
			</section>
		</div>
	</div>
</main>
<?php get_footer(); ?>
