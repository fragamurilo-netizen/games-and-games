<?php
/** Existing promotions, Amazon integration, history and price-alert form. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
?>
<section id="ofertas" class="od-game-section" aria-labelledby="od-game-offers-title">
	<header class="od-game-section__head"><h2 id="od-game-offers-title"><?php esc_html_e( 'Ofertas e preços', 'go-verge' ); ?></h2></header>
	<?php if ( $promos->have_posts() ) : ?>
		<div class="od-game-offers">
			<?php while ( $promos->have_posts() ) : $promos->the_post();
				$promotion_id = get_the_ID();
				$is_amazon = class_exists( 'GO_Amazon_Core' ) && get_post_meta( $promotion_id, '_go_amazon_asin', true );
				if ( $is_amazon && class_exists( 'GO_Amazon_Frontend' ) ) { echo GO_Amazon_Frontend::instance()->card( $promotion_id, 'pagina-do-game', 'archive' ); continue; } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
				$sale = go_verge_product_first_meta( $promotion_id, array( 'go_promotion_sale_price_text', 'go_promotion_sale_price' ) );
				$regular = go_verge_product_first_meta( $promotion_id, array( 'go_promotion_regular_price_text', 'go_promotion_regular_price' ) );
				$url = go_verge_product_first_meta( $promotion_id, array( 'go_promotion_offer_url', 'go_promotion_url' ) );
				$destination = $url ? $url : get_permalink();
			?>
				<article class="od-game-offer"><a href="<?php echo esc_url( $destination ); ?>"<?php echo $url ? ' target="_blank" rel="nofollow sponsored noopener noreferrer"' : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
					<?php if ( has_post_thumbnail() ) : ?><div class="od-game-offer__image"><?php the_post_thumbnail( 'go_card', array( 'loading' => 'lazy', 'alt' => '' ) ); ?></div><?php endif; ?>
					<div class="od-game-offer__body"><h3><?php the_title(); ?></h3><?php if ( $sale || $regular ) : ?><p class="od-game-offer__price"><?php if ( $regular ) : ?><del><?php echo esc_html( $regular ); ?></del><?php endif; ?><?php if ( $sale ) : ?><strong><?php echo esc_html( $sale ); ?></strong><?php endif; ?></p><?php endif; ?><span class="od-game-offer__cta"><?php esc_html_e( 'Conferir oferta', 'go-verge' ); ?><?php echo go_verge_games_icon( 'external' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span></div>
				</a></article>
			<?php endwhile; wp_reset_postdata(); ?>
		</div>
	<?php endif; ?>
	<?php if ( $price_tools ) : ?><div class="od-game-price-tools"><?php echo $price_tools; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- escaped by original theme renderers. ?></div><?php endif; ?>
</section>
