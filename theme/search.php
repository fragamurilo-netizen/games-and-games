<?php
/** Search results page. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();

$go_search_query = get_search_query();
$go_search_type  = isset( $_GET['tipo'] ) ? sanitize_key( wp_unslash( $_GET['tipo'] ) ) : 'todos';
$go_search_tabs  = array(
	'todos'    => __( 'Tudo', 'go-verge' ),
	'materias' => __( 'Matérias', 'go-verge' ),
	'games'    => __( 'Games', 'go-verge' ),
	'paginas'  => __( 'Páginas', 'go-verge' ),
);
if ( ! post_type_exists( 'games' ) ) {
	unset( $go_search_tabs['games'] );
}
if ( ! isset( $go_search_tabs[ $go_search_type ] ) ) {
	$go_search_type = 'todos';
}
?>
<main id="primary" class="go-main go-search-results-page">
	<section class="go-container go-search-page__hero">
		<div class="go-search-page__heading">
			<h1 class="go-pagehead__title"><?php esc_html_e( 'Busca', 'go-verge' ); ?></h1>
			<?php if ( '' !== $go_search_query ) : ?>
				<p class="go-search-page__summary">
					<?php
					printf(
						/* translators: 1: search term, 2: number of results. */
						esc_html__( 'Resultados para “%1$s” · %2$d', 'go-verge' ),
						esc_html( $go_search_query ),
						(int) $wp_query->found_posts
					);
					?>
				</p>
			<?php endif; ?>
		</div>
		<form class="go-search-page__form" method="get" action="<?php echo esc_url( home_url( '/' ) ); ?>" role="search">
			<label class="screen-reader-text" for="go-search-page-input"><?php esc_html_e( 'Buscar no site', 'go-verge' ); ?></label>
			<input id="go-search-page-input" type="search" name="s" value="<?php echo esc_attr( $go_search_query ); ?>" placeholder="<?php esc_attr_e( 'Busque jogos, reviews, notícias, autores…', 'go-verge' ); ?>" autocomplete="off">
			<?php if ( 'todos' !== $go_search_type ) : ?><input type="hidden" name="tipo" value="<?php echo esc_attr( $go_search_type ); ?>"><?php endif; ?>
			<button type="submit" class="go-btn go-btn--mint"><?php esc_html_e( 'Buscar', 'go-verge' ); ?></button>
		</form>
	</section>

	<?php if ( '' !== $go_search_query ) : ?>
		<div class="go-container go-search-filters" aria-label="<?php esc_attr_e( 'Filtrar resultados da busca', 'go-verge' ); ?>">
			<?php foreach ( $go_search_tabs as $go_tab_key => $go_tab_label ) : ?>
				<?php
				$go_tab_url = add_query_arg(
					array_filter(
						array(
							's'    => $go_search_query,
							'tipo' => 'todos' === $go_tab_key ? null : $go_tab_key,
						),
						static function ( $value ) { return null !== $value; }
					),
					home_url( '/' )
				);
				?>
				<a class="go-search-filter<?php echo $go_search_type === $go_tab_key ? ' is-active' : ''; ?>" href="<?php echo esc_url( $go_tab_url ); ?>"<?php echo $go_search_type === $go_tab_key ? ' aria-current="page"' : ''; ?>><?php echo esc_html( $go_tab_label ); ?></a>
			<?php endforeach; ?>
		</div>
	<?php endif; ?>

	<div class="go-container go-section go-search-page__results">
		<?php if ( have_posts() ) : ?>
			<div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e( 'Resultados', 'go-verge' ); ?></h2></div>
			<div class="go-archive-list" data-go-latest-feed<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
				<?php
				while ( have_posts() ) : the_post();
					go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'show_type' => false ) );
				endwhile;
				?>
			</div>
			<?php go_verge_pagination(); ?>
		<?php else : ?>
			<div class="go-search-page__empty">
				<h2><?php esc_html_e( 'Nenhum resultado encontrado', 'go-verge' ); ?></h2>
				<p><?php esc_html_e( 'Tente outro termo, procure pelo nome do jogo, autor, plataforma ou use um filtro diferente.', 'go-verge' ); ?></p>
				<nav class="go-quicklinks" aria-label="<?php esc_attr_e( 'Editorias sugeridas', 'go-verge' ); ?>">
					<a href="<?php echo esc_url( home_url( '/games/' ) ); ?>"><?php esc_html_e( 'Games', 'go-verge' ); ?></a>
					<a href="<?php echo esc_url( function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'reviews' ) : home_url( '/reviews/' ) ); ?>"><?php esc_html_e( 'Reviews', 'go-verge' ); ?></a>
					<a href="<?php echo esc_url( function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'guias' ) : home_url( '/guias/' ) ); ?>"><?php esc_html_e( 'Guias', 'go-verge' ); ?></a>
					<a href="<?php echo esc_url( function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'promocoes' ) : home_url( '/ofertas/' ) ); ?>"><?php esc_html_e( 'Promoções', 'go-verge' ); ?></a>
				</nav>
			</div>
			<?php
			$go_search_fallback = new WP_Query(
				array(
					'post_type'           => 'post',
					'post_status'         => 'publish',
					'posts_per_page'      => 4,
					'ignore_sticky_posts' => true,
					'no_found_rows'       => true,
				)
			);
			?>
			<?php if ( $go_search_fallback->have_posts() ) : ?>
				<section class="go-search-page__fallback" aria-labelledby="go-search-fallback-title">
					<div class="go-section__head">
						<h2 id="go-search-fallback-title" class="go-section__title"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2>
					</div>
					<div class="go-archive-list" data-go-latest-feed<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
						<?php while ( $go_search_fallback->have_posts() ) : $go_search_fallback->the_post(); ?>
							<?php go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'show_type' => false ) ); ?>
						<?php endwhile; ?>
					</div>
				</section>
				<?php wp_reset_postdata(); ?>
			<?php endif; ?>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
