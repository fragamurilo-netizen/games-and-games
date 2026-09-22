<?php
/**
 * Template Name: Mapa do site Overdrive
 * Description: Human-readable sitemap with editorial, institutional and category navigation.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$go_sitemap_url = static function ( array $item ) {
	$kind   = isset( $item['kind'] ) ? (string) $item['kind'] : 'page';
	$target = isset( $item['target'] ) ? (string) $item['target'] : '';

	switch ( $kind ) {
		case 'home':
			return home_url( '/' );

		case 'category':
			if ( function_exists( 'go_verge_v7_category_url' ) && function_exists( 'go_verge_v7_canonical_category_slugs' ) && in_array( sanitize_title( $target ), go_verge_v7_canonical_category_slugs(), true ) ) {
				return go_verge_v7_category_url( $target );
			}
			$term = get_term_by( 'slug', $target, 'category' );
			if ( $term instanceof WP_Term ) {
				$link = get_term_link( $term );
				if ( ! is_wp_error( $link ) ) {
					return $link;
				}
			}
			return home_url( '/' . trim( $target, '/' ) . '/' );

		case 'archive':
			$link = get_post_type_archive_link( $target );
			return $link ? $link : home_url( '/' . trim( $target, '/' ) . '/' );

		case 'buying_guides':
			if ( function_exists( 'go_verge_canonical_buying_guides_url' ) ) {
				$link = go_verge_canonical_buying_guides_url();
				if ( $link ) {
					return $link;
				}
			}
			$term = get_term_by( 'slug', 'guias-de-compra-2', 'category' );
			if ( $term instanceof WP_Term ) {
				$link = get_term_link( $term );
				if ( ! is_wp_error( $link ) ) {
					return $link;
				}
			}
			return home_url( '/guias-de-compra/' );

		case 'custom':
			return isset( $item['url'] ) ? (string) $item['url'] : '';

		case 'page':
		default:
			$page = get_page_by_path( $target );
			return $page instanceof WP_Post ? get_permalink( $page ) : home_url( '/' . trim( $target, '/' ) . '/' );
	}
};

$go_sitemap_xml_url = static function () {
	/* Keep the human sitemap aligned with the single canonical XML sitemap
	 * contract used by robots.txt, Search Console and the newsroom sitemap. */
	if ( function_exists( 'go_verge_search_main_sitemap_url' ) ) {
		return go_verge_search_main_sitemap_url();
	}
	if ( function_exists( 'go_verge_smart_sitemap_url' ) ) {
		return go_verge_smart_sitemap_url();
	}
	return home_url( '/sitemap.xml' );
};

$go_sitemap_sections = array(
	array(
		'title' => __( 'Sobre o Overdrive', 'go-verge' ),
		'links' => array(
			array( 'label' => __( 'Início', 'go-verge' ), 'kind' => 'home' ),
			array( 'label' => __( 'Sobre o Overdrive', 'go-verge' ), 'target' => 'sobre-o-overdrive' ),
			array( 'label' => __( 'Autores', 'go-verge' ), 'target' => 'autores' ),
			array( 'label' => __( 'Contato', 'go-verge' ), 'target' => 'contato' ),
			array( 'label' => __( 'Parcerias', 'go-verge' ), 'target' => 'parcerias' ),
			array( 'label' => __( 'Mídia Kit', 'go-verge' ), 'target' => 'midia-kit' ),
		),
	),
	array(
		'title' => __( 'Games', 'go-verge' ),
		'links' => array(
			array( 'label' => __( 'Games', 'go-verge' ), 'kind' => 'archive', 'target' => 'games' ),
			array( 'label' => __( 'Notícias', 'go-verge' ), 'kind' => 'category', 'target' => 'noticias' ),
			array( 'label' => __( 'Reviews', 'go-verge' ), 'kind' => 'category', 'target' => 'reviews' ),
			array( 'label' => __( 'Críticas', 'go-verge' ), 'kind' => 'category', 'target' => 'criticas' ),
			array( 'label' => __( 'Guias', 'go-verge' ), 'kind' => 'category', 'target' => 'guias' ),
			array( 'label' => __( 'Guias de compra', 'go-verge' ), 'kind' => 'buying_guides' ),
			array( 'label' => __( 'Lançamentos', 'go-verge' ), 'kind' => 'category', 'target' => 'lancamentos' ),
			array( 'label' => __( 'Ofertas', 'go-verge' ), 'kind' => 'category', 'target' => 'promocoes' ),
			array( 'label' => __( 'Biblioteca de Games', 'go-verge' ), 'target' => 'biblioteca-de-games' ),
		),
	),
	array(
		'title' => __( 'Entretenimento e tecnologia', 'go-verge' ),
		'links' => array(
			array( 'label' => __( 'Entretenimento', 'go-verge' ), 'kind' => 'category', 'target' => 'entretenimento' ),
			array( 'label' => __( 'Tecnologia', 'go-verge' ), 'kind' => 'category', 'target' => 'tecnologia' ),
			array( 'label' => __( 'Listas', 'go-verge' ), 'target' => 'listas' ),
			array( 'label' => __( 'Listas e rankings', 'go-verge' ), 'target' => 'listas-e-rankings' ),
			array( 'label' => __( 'Plataformas', 'go-verge' ), 'target' => 'plataformas' ),
			array( 'label' => __( 'Últimas publicações', 'go-verge' ), 'target' => 'ultimas-publicacoes' ),
			array( 'label' => __( 'Popular agora', 'go-verge' ), 'target' => 'popular' ),
		),
	),
	array(
		'title' => __( 'Institucional e leitor', 'go-verge' ),
		'links' => array(
			array( 'label' => __( 'Política editorial', 'go-verge' ), 'target' => 'politica-editorial' ),
			array( 'label' => __( 'Política de reviews', 'go-verge' ), 'target' => 'politica-de-reviews' ),
			array( 'label' => __( 'Privacidade', 'go-verge' ), 'target' => 'privacidade' ),
			array( 'label' => __( 'Termos de uso', 'go-verge' ), 'target' => 'termos-de-uso' ),
			array( 'label' => __( 'Acessibilidade', 'go-verge' ), 'target' => 'acessibilidade' ),
			array( 'label' => __( 'Status', 'go-verge' ), 'target' => 'status' ),
			array( 'label' => __( 'Preferências da newsletter', 'go-verge' ), 'target' => 'preferencias-newsletter' ),
			array( 'label' => __( 'Mapa do site XML', 'go-verge' ), 'kind' => 'custom', 'url' => $go_sitemap_xml_url() ),
		),
	),
);

$go_sitemap_category_args = array(
	'hide_empty' => true,
	'orderby'    => 'name',
	'order'      => 'ASC',
);
if ( function_exists( 'go_verge_v7_canonical_category_slugs' ) ) {
	$canonical_ids = array();
	foreach ( go_verge_v7_canonical_category_slugs() as $slug ) {
		$term = get_term_by( 'slug', $slug, 'category' );
		if ( $term instanceof WP_Term ) { $canonical_ids[] = (int) $term->term_id; }
	}
	if ( $canonical_ids ) {
		$go_sitemap_category_args['include'] = array_values( array_unique( $canonical_ids ) );
	}
}
$go_sitemap_categories = get_categories( $go_sitemap_category_args );

$go_sitemap_excluded_pages = array();
if ( function_exists( 'go_verge_search_utility_page_ids' ) ) {
	$go_sitemap_excluded_pages = array_merge( $go_sitemap_excluded_pages, go_verge_search_utility_page_ids() );
}
if ( function_exists( 'go_verge_search_redirected_page_ids' ) ) {
	$go_sitemap_excluded_pages = array_merge( $go_sitemap_excluded_pages, go_verge_search_redirected_page_ids() );
}
$go_sitemap_pages = get_pages(
	array(
		'post_status' => 'publish',
		'sort_column' => 'post_title',
		'sort_order'  => 'ASC',
		'exclude'     => array_values( array_unique( array_filter( array_map( 'absint', $go_sitemap_excluded_pages ) ) ) ),
	)
);
?>

<main id="primary" class="go-main go-sitemap-page">
	<div class="go-container">
		<header class="go-sitemap-page__header">
			<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
			<h1><?php esc_html_e( 'Mapa do site', 'go-verge' ); ?></h1>
			<p><?php esc_html_e( 'Encontre editorias, páginas especiais, informações institucionais e outras áreas do Overdrive.', 'go-verge' ); ?></p>
		</header>

		<section class="go-sitemap-page__section" aria-labelledby="go-sitemap-main-title">
			<h2 class="go-sitemap-page__section-title" id="go-sitemap-main-title"><?php esc_html_e( 'Principais áreas', 'go-verge' ); ?></h2>
			<div class="go-sitemap-page__grid go-sitemap-page__grid--primary">
				<?php foreach ( $go_sitemap_sections as $section ) : ?>
					<section class="go-sitemap-page__group">
						<h3><?php echo esc_html( $section['title'] ); ?></h3>
						<ul>
							<?php foreach ( $section['links'] as $item ) : ?>
								<?php $url = $go_sitemap_url( $item ); ?>
								<?php if ( ! $url ) { continue; } ?>
								<li><a href="<?php echo esc_url( $url ); ?>"><?php echo esc_html( $item['label'] ); ?></a></li>
							<?php endforeach; ?>
						</ul>
					</section>
				<?php endforeach; ?>
			</div>
		</section>

		<?php if ( $go_sitemap_categories ) : ?>
			<section class="go-sitemap-page__section" aria-labelledby="go-sitemap-categories-title">
				<h2 class="go-sitemap-page__section-title" id="go-sitemap-categories-title"><?php esc_html_e( 'Editorias e categorias', 'go-verge' ); ?></h2>
				<ul class="go-sitemap-page__link-grid">
					<?php foreach ( $go_sitemap_categories as $category ) : ?>
						<?php $category_url = get_term_link( $category ); ?>
						<?php if ( is_wp_error( $category_url ) ) { continue; } ?>
						<li><a href="<?php echo esc_url( $category_url ); ?>"><?php echo esc_html( $category->name ); ?></a></li>
					<?php endforeach; ?>
				</ul>
			</section>
		<?php endif; ?>

		<?php if ( $go_sitemap_pages ) : ?>
			<section class="go-sitemap-page__section" aria-labelledby="go-sitemap-pages-title">
				<h2 class="go-sitemap-page__section-title" id="go-sitemap-pages-title"><?php esc_html_e( 'Todas as páginas', 'go-verge' ); ?></h2>
				<ul class="go-sitemap-page__link-grid">
					<?php foreach ( $go_sitemap_pages as $page ) : ?>
						<?php if ( 'mapa-do-site' === $page->post_name ) { continue; } ?>
						<li><a href="<?php echo esc_url( get_permalink( $page ) ); ?>"><?php echo esc_html( get_the_title( $page ) ); ?></a></li>
					<?php endforeach; ?>
				</ul>
			</section>
		<?php endif; ?>
	</div>
</main>

<?php get_footer(); ?>
