<?php
/** Coverage retains the existing signed load-more and classification contract. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
?>
<section id="materias" class="od-game-section od-game-coverage" aria-labelledby="od-game-coverage-title" data-go-game-coverage>
	<header class="od-game-section__head"><div><h2 id="od-game-coverage-title"><?php esc_html_e( 'Últimas sobre o jogo', 'go-verge' ); ?></h2></div><span class="od-game-coverage__total"><?php printf( esc_html( _n( '%s publicação', '%s publicações', $coverage_counts['all'], 'go-verge' ) ), esc_html( number_format_i18n( $coverage_counts['all'] ) ) ); ?></span></header>
	<div class="od-game-coverage__filters" data-go-coverage-controls hidden role="group" aria-label="<?php esc_attr_e( 'Filtrar cobertura', 'go-verge' ); ?>">
		<?php foreach ( array( 'all' => 'Tudo', 'news' => 'Notícias', 'guides' => 'Guias', 'reviews' => 'Reviews', 'videos' => 'Vídeos' ) as $key => $label ) : ?>
			<?php if ( 'all' !== $key && empty( $coverage_counts[ $key ] ) ) { continue; } ?>
			<button type="button" class="<?php echo 'all' === $key ? 'is-active' : ''; ?>" data-go-coverage-filter="<?php echo esc_attr( $key ); ?>" aria-pressed="<?php echo 'all' === $key ? 'true' : 'false'; ?>"><?php echo esc_html( $label ); ?><span><?php echo esc_html( number_format_i18n( $coverage_counts[ $key ] ) ); ?></span></button>
		<?php endforeach; ?>
	</div>
	<div id="go-game-coverage-feed" class="od-game-coverage__feed" data-go-coverage-stream data-go-latest-feed>
		<?php $go_coverage_ad_index = 0; ?>
		<?php while ( $coverage_query->have_posts() ) : $coverage_query->the_post(); ?>
			<?php $go_coverage_ad_index++; ?>
			<?php go_verge_game_coverage_row( get_the_ID() ); ?>
			<?php if ( function_exists( 'go_verge_ads_render_indexed_listing_unit' ) ) { go_verge_ads_render_indexed_listing_unit( $go_coverage_ad_index, 'game-coverage', array( 3 => 'listing-f1', 7 => 'listing-f2', 10 => 'listing-f3' ) ); } ?>
		<?php endwhile; wp_reset_postdata(); ?>
	</div>
	<?php go_verge_pagination( $coverage_query, array(), array( 'mode' => 'game-coverage', 'target' => '#go-game-coverage-feed', 'label' => __( 'Carregar mais matérias', 'go-verge' ), 'media_context' => 'latest', 'sync_history' => false, 'next_url' => add_query_arg( 'cobertura', max( 1, (int) $coverage_query->get( 'paged' ) ) + 1, get_permalink( $game_id ) ) . '#materias' ) ); ?>
	<p class="od-games__muted" data-go-coverage-empty role="status" hidden><?php esc_html_e( 'Nenhuma matéria neste filtro.', 'go-verge' ); ?></p>
</section>
