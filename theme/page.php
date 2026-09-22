<?php
/**
 * Generic institutional page shell.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

/*
 * Legacy editorial Pages are content hubs, not institutional documents.
 * Render their real category posts even when the Page body itself is empty.
 */
$go_verge_page_object = get_queried_object();
$go_verge_page_slug   = $go_verge_page_object instanceof WP_Post ? $go_verge_page_object->post_name : '';

$go_verge_institutional_slugs = array(
	'sobre-o-overdrive',
	'sobre-o-game-overdrive',
	'contato',
	'seja-colaborador',
	'politica-editorial',
	'politica-de-reviews',
	'politicas',
	'propriedade-e-financiamento',
	'missao-e-prioridades-de-cobertura',
	'politica-de-diversidade',
	'politica-de-assinatura',
	'politica-de-fontes-nao-identificadas',
	'acessibilidade',
	'privacidade',
	'termos-de-uso',
);

if ( in_array( $go_verge_page_slug, $go_verge_institutional_slugs, true ) ) {
	get_header();
	while ( have_posts() ) {
		the_post();
		get_template_part( 'template-parts/trust-page' );
	}
	get_footer();
	return;
}

/* Keep the Latest page functional even when a migration loses its assigned page template. */
if ( in_array( $go_verge_page_slug, array( 'ultimas-publicacoes', 'latest' ), true ) ) {
	require get_template_directory() . '/page-template/template-latest.php';
	return;
}
$go_verge_page_hubs   = array(
	'dicas-e-guias' => array(
		'aliases'   => array( 'dicas-e-guias', 'guias', 'dicas', 'tutoriais' ),
		'fragments' => array( 'dica', 'guia', 'tutorial' ),
	),
	'guias' => array(
		'aliases'   => array( 'dicas-e-guias', 'guias', 'dicas', 'tutoriais' ),
		'fragments' => array( 'dica', 'guia', 'tutorial' ),
	),
	'entretenimento' => array(
		'aliases'   => array( 'entretenimento', 'noticias-de-entretenimento', 'noticias-entretenimento', 'series', 'filmes', 'streaming', 'animes', 'anime', 'mangas-e-quadrinhos', 'manga-e-quadrinhos', 'mangas', 'manga', 'quadrinhos', 'hqs', 'comics' ),
		'fragments' => array( 'entreten', 'noticias-entretenimento', 'serie', 'filme', 'streaming', 'anime', 'manga', 'quadrinho', 'comic' ),
		'zone'      => 'entertainment',
	),
	'series' => array(
		'aliases'   => array( 'series', 'serie' ),
		'fragments' => array( 'serie', 'temporada', 'episodio' ),
		'zone'      => 'entertainment',
	),
	'filmes' => array(
		'aliases'   => array( 'filmes', 'filme', 'cinema' ),
		'fragments' => array( 'filme', 'cinema', 'longa' ),
		'zone'      => 'entertainment',
	),
	'tecnologia' => array(
		'aliases'   => array( 'tecnologia', 'tech' ),
		'fragments' => array( 'tecnolog', 'tech' ),
		'zone'      => 'technology',
	),
	'listas' => array(
		'aliases'   => array( 'listas', 'lista', 'rankings', 'ranking' ),
		'fragments' => array( 'lista', 'ranking' ),
	),
	'rankings' => array(
		'aliases'   => array( 'listas', 'lista', 'rankings', 'ranking' ),
		'fragments' => array( 'lista', 'ranking' ),
	),
	'listas-e-rankings' => array(
		'aliases'   => array( 'listas', 'lista', 'rankings', 'ranking' ),
		'fragments' => array( 'lista', 'ranking' ),
	),
	'especiais' => array(
		'aliases'   => array( 'especiais', 'especial', 'reportagens', 'materias-especiais' ),
		'fragments' => array( 'especial', 'reportagem' ),
	),
);

if ( isset( $go_verge_page_hubs[ $go_verge_page_slug ] ) ) {
	$go_verge_hub = $go_verge_page_hubs[ $go_verge_page_slug ];
	go_verge_render_editorial_hub_page(
		$go_verge_page_object->post_title,
		$go_verge_hub['aliases'],
		$go_verge_hub['fragments'],
		__( 'Últimas publicações', 'go-verge' ),
		isset( $go_verge_hub['zone'] ) ? $go_verge_hub['zone'] : ''
	);
	return;
}

get_header();

while ( have_posts() ) :
	the_post();
	?>
	<main id="primary" class="go-main go-institutional">
		<article <?php post_class( 'go-institutional__article' ); ?>>
			<header class="go-container go-institutional__header">
				<?php go_verge_breadcrumbs(); ?>
				<h1 class="go-institutional__title"><?php the_title(); ?></h1>
			</header>

			<?php if ( has_post_thumbnail() ) : ?>
				<figure class="go-container go-institutional__hero">
					<?php the_post_thumbnail( 'go_hero', array( 'loading' => 'eager', 'fetchpriority' => 'high', 'decoding' => 'async', 'sizes' => '(max-width: 767px) calc(100vw - 32px), (max-width: 1279px) calc(100vw - 40px), 1100px' ) ); ?>
				</figure>
			<?php endif; ?>

			<div class="go-container go-institutional__shell">
				<div class="go-institutional__content">
					<?php the_content(); ?>
				</div>
			</div>

			<?php if ( comments_open() || get_comments_number() ) : ?>
				<div class="go-container go-institutional__comments"><?php comments_template(); ?></div>
			<?php endif; ?>
		</article>
	</main>
	<?php
endwhile;

get_footer();
