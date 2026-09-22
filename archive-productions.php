<?php
/**
 * Biblioteca de produções do Overdrive.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
?>
<main id="primary" class="go-main go-v7-hub go-v7-productions-archive">
	<section class="go-v7-hubhero">
		<div class="go-container">
			<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
			<p class="go-v7-kicker">Biblioteca editorial</p>
			<h1>Produções</h1>
			<p>Filmes, séries, novelas e animes acompanhados pelo Overdrive, com ficha, disponibilidade, status e toda a cobertura relacionada.</p>
		</div>
	</section>
	<div class="go-container go-v7-library">
		<?php if ( have_posts() ) : ?>
			<div class="go-v7-library__grid" data-go-production-library-feed>
				<?php $go_production_catalog_index = 0; ?>
				<?php while ( have_posts() ) : the_post(); ?>
					<?php $go_production_catalog_index++; go_verge_production_library_card( get_the_ID() ); ?>
					<?php if ( function_exists( 'go_verge_ads_render_indexed_listing_unit' ) ) { go_verge_ads_render_indexed_listing_unit( $go_production_catalog_index, 'production-library', array( 8 => 'listing-f1', 16 => 'listing-f2' ) ); } ?>
				<?php endwhile; ?>
			</div>
			<?php if ( function_exists( 'go_verge_pagination' ) ) { go_verge_pagination( null, array(), array( 'mode' => 'production-library', 'target' => '[data-go-production-library-feed]', 'label' => __( 'Carregar mais produções', 'go-verge' ) ) ); } else { the_posts_pagination(); } ?>
		<?php else : get_template_part( 'template-parts/content', 'none' ); endif; ?>
	</div>
</main>
<?php get_footer(); ?>
