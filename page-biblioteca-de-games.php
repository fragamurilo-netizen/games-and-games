<?php
/** Biblioteca de Games — searchable catalogue on the site's editorial canvas. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
$library_url = get_permalink( get_queried_object_id() );
$state = go_verge_games_library_state();
$paged = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
$games = new WP_Query( go_verge_games_library_query_args( $state, $paged ) );
$platforms = go_verge_games_platforms();
$statuses = go_verge_games_status_labels();
$filtered = '' !== $state['jogo'] || '' !== $state['plataforma'] || '' !== $state['status'];
?>
<main id="primary" class="od-games od-games--library" data-od-library>
	<div class="od-games__container">
		<div class="od-games__breadcrumbs"><?php go_verge_breadcrumbs(); ?></div>
		<header class="od-library-heading">
			<div>
				
				<h1><?php esc_html_e( 'Biblioteca de games', 'go-verge' ); ?></h1>
			</div>
			<a class="od-games__text-link" href="<?php echo esc_url( home_url( '/games/' ) ); ?>"><?php esc_html_e( 'Notícias de games', 'go-verge' ); ?><?php echo go_verge_games_icon( 'arrow' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a>
		</header>

		<form class="od-library-filters" method="get" action="<?php echo esc_url( $library_url ); ?>" role="search" aria-label="<?php esc_attr_e( 'Buscar jogos na biblioteca', 'go-verge' ); ?>">
			<?php if ( ! get_option( 'permalink_structure' ) ) : ?><input type="hidden" name="page_id" value="<?php echo esc_attr( get_queried_object_id() ); ?>"><?php endif; ?>
			<div class="od-library-filters__search">
				<label for="od-game-search"><?php esc_html_e( 'Qual jogo você procura?', 'go-verge' ); ?></label>
				<div class="od-library-searchbox"><?php echo go_verge_games_icon( 'search' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><input id="od-game-search" name="jogo" type="search" maxlength="200" value="<?php echo esc_attr( $state['jogo'] ); ?>" placeholder="<?php esc_attr_e( 'Buscar pelo nome do jogo', 'go-verge' ); ?>"></div>
			</div>
			<div class="od-library-filters__field">
				<label for="od-game-platform"><?php esc_html_e( 'Plataforma', 'go-verge' ); ?></label>
				<select id="od-game-platform" name="plataforma"><option value=""><?php esc_html_e( 'Todas', 'go-verge' ); ?></option><?php foreach ( $platforms as $key => $platform ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $state['plataforma'], $key ); ?>><?php echo esc_html( $platform['label'] ); ?></option><?php endforeach; ?></select>
			</div>
			<div class="od-library-filters__field">
				<label for="od-game-status"><?php esc_html_e( 'Status', 'go-verge' ); ?></label>
				<select id="od-game-status" name="status"><option value=""><?php esc_html_e( 'Todos', 'go-verge' ); ?></option><?php foreach ( $statuses as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $state['status'], $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select>
			</div>
			<div class="od-library-filters__field">
				<label for="od-game-sort"><?php esc_html_e( 'Ordenar por', 'go-verge' ); ?></label>
				<select id="od-game-sort" name="ordem"><?php foreach ( array( 'recentes' => 'Mais recentes', 'atualizados' => 'Atualizados', 'az' => 'Nome: A–Z' ) as $key => $label ) : ?><option value="<?php echo esc_attr( $key ); ?>" <?php selected( $state['ordem'], $key ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select>
			</div>
			<button class="od-games__button od-games__button--primary od-library-filters__submit" type="submit"><?php echo go_verge_games_icon( 'filter' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php esc_html_e( 'Filtrar', 'go-verge' ); ?></button>
		</form>

		<?php if ( $filtered ) : ?>
			<div class="od-library-active" aria-label="<?php esc_attr_e( 'Filtros aplicados', 'go-verge' ); ?>">
				<span><?php esc_html_e( 'Filtros:', 'go-verge' ); ?></span>
				<?php foreach ( array( 'jogo' => $state['jogo'], 'plataforma' => $state['plataforma'] ? $platforms[ $state['plataforma'] ]['label'] : '', 'status' => $state['status'] ? $statuses[ $state['status'] ] : '' ) as $key => $label ) : ?>
					<?php if ( '' === $label ) { continue; } $remaining = $state; unset( $remaining[ $key ] ); ?>
					<a href="<?php echo esc_url( add_query_arg( array_filter( $remaining ), $library_url ) ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Remover filtro: %s', 'go-verge' ), $label ) ); ?>"><?php echo esc_html( $label ); ?><?php echo go_verge_games_icon( 'close' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a>
				<?php endforeach; ?>
				<a class="od-library-active__clear" href="<?php echo esc_url( $library_url ); ?>"><?php esc_html_e( 'Limpar tudo', 'go-verge' ); ?></a>
			</div>
		<?php endif; ?>

		<section class="od-library-results" id="od-library-results" aria-labelledby="od-library-results-title">
			<header class="od-library-results__head">
				<div><h2 id="od-library-results-title"><?php echo $filtered ? esc_html__( 'Resultados da busca', 'go-verge' ) : esc_html__( 'Todos os jogos', 'go-verge' ); ?></h2><span><?php printf( esc_html( _n( '%s jogo encontrado', '%s jogos encontrados', (int) $games->found_posts, 'go-verge' ) ), esc_html( number_format_i18n( (int) $games->found_posts ) ) ); ?></span></div>
				<div class="od-library-views" data-od-view-controls hidden role="group" aria-label="<?php esc_attr_e( 'Visualização da biblioteca', 'go-verge' ); ?>"><button type="button" data-od-view="grid" aria-pressed="true" aria-label="<?php esc_attr_e( 'Visualizar em grade', 'go-verge' ); ?>"><?php echo go_verge_games_icon( 'grid' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></button><button type="button" data-od-view="list" aria-pressed="false" aria-label="<?php esc_attr_e( 'Visualizar em lista', 'go-verge' ); ?>"><?php echo go_verge_games_icon( 'list' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></button></div>
			</header>
			<?php if ( $games->have_posts() ) : ?>
				<div class="od-game-catalog" id="od-game-catalog" data-od-catalog-view="grid">
					<?php $go_game_catalog_index = 0; ?>
					<?php foreach ( $games->posts as $game_post ) : ?>
						<?php $go_game_catalog_index++; go_verge_game_library_card( $game_post->ID ); ?>
						<?php if ( function_exists( 'go_verge_ads_render_indexed_listing_unit' ) ) { go_verge_ads_render_indexed_listing_unit( $go_game_catalog_index, 'game-library', array( 12 => 'listing-f1', 24 => 'listing-f2' ) ); } ?>
					<?php endforeach; ?>
				</div>
				<?php go_verge_pagination( $games, array(), array( 'mode' => 'game-library', 'target' => '#od-game-catalog', 'label' => __( 'Carregar mais jogos', 'go-verge' ), 'next_url' => add_query_arg( array_filter( $state ), get_pagenum_link( $paged + 1 ) ) . '#od-library-results' ) ); ?>
				<?php if ( $paged > 1 ) : ?><a class="od-games__text-link od-library-back" href="<?php echo esc_url( add_query_arg( array_filter( $state ), $library_url ) ); ?>"><?php esc_html_e( 'Voltar à primeira página', 'go-verge' ); ?></a><?php endif; ?>
			<?php else : ?>
				<div class="od-games-empty"><?php echo go_verge_games_icon( 'search' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><h3><?php esc_html_e( 'Nenhum jogo por aqui', 'go-verge' ); ?></h3><p><?php echo $filtered ? esc_html__( 'Tente outro nome ou remova um dos filtros para ampliar a busca.', 'go-verge' ) : esc_html__( 'Os jogos cadastrados aparecerão aqui assim que forem publicados.', 'go-verge' ); ?></p><?php if ( $filtered ) : ?><a class="od-games__button" href="<?php echo esc_url( $library_url ); ?>"><?php esc_html_e( 'Ver todos os jogos', 'go-verge' ); ?></a><?php endif; ?></div>
			<?php endif; ?>
		</section>
	</div>
</main>
<?php get_footer(); ?>
