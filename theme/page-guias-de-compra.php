<?php
/**
 * Guias de Compra hub.
 *
 * Curadoria de recomendações de hardware, periféricos e jogos: destaque,
 * feed paginado com filtros por subeditoria, selos de metodologia (E-E-A-T)
 * e ofertas da Amazon integradas. Aplica-se à página de slug
 * "guias-de-compra"; enquanto a categoria própria não existir, o feed cai
 * para Dicas e Guias, então a página nunca fica vazia.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$go_bg_aliases   = function_exists( 'go_verge_buying_guides_category_slugs' )
	? array_merge( go_verge_buying_guides_category_slugs(), array( 'melhores', 'recomendacoes' ) )
	: array( 'guias-de-compra-2', 'guias-de-compra', 'guia-de-compra', 'guias-compra', 'melhores', 'recomendacoes' );
$go_bg_fragments = array( 'guia-de-compra', 'guias-de-compra', 'melhores' );
$go_bg_root_ids  = function_exists( 'go_verge_category_ids' )
	? go_verge_category_ids( $go_bg_aliases, $go_bg_fragments )
	: array();

// Fallback editorial: sem a categoria própria, o hub mostra Dicas e Guias.
$go_bg_fallback = empty( $go_bg_root_ids );
if ( $go_bg_fallback ) {
	$go_bg_aliases   = array( 'dicas-e-guias', 'guias', 'dicas' );
	$go_bg_fragments = array( 'guia', 'dica' );
	$go_bg_root_ids  = function_exists( 'go_verge_category_ids' )
		? go_verge_category_ids( $go_bg_aliases, $go_bg_fragments )
		: array();
}

$go_bg_page_url = get_permalink();

$go_bg_feature    = go_verge_query_editorial_posts( $go_bg_aliases, 1, array(), $go_bg_fragments );
$go_bg_feature_id = $go_bg_feature->have_posts() ? (int) $go_bg_feature->posts[0]->ID : 0;

$go_bg_lead = go_verge_query_editorial_posts(
	$go_bg_aliases,
	4,
	array( 'post__not_in' => $go_bg_feature_id ? array( $go_bg_feature_id ) : array() ),
	$go_bg_fragments
);
$go_bg_lead_ids = array_map( 'absint', wp_list_pluck( $go_bg_lead->posts, 'ID' ) );

// Filtro por subeditoria (?editoria=), espelhando o hub de Games.
$go_bg_root_term = null;
foreach ( $go_bg_aliases as $go_bg_alias ) {
	$go_bg_candidate = get_category_by_slug( $go_bg_alias );
	if ( $go_bg_candidate instanceof WP_Term ) {
		$go_bg_root_term = $go_bg_candidate;
		break;
	}
}

$go_bg_filter_slug  = isset( $_GET['editoria'] ) ? sanitize_title( wp_unslash( $_GET['editoria'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
$go_bg_filter_term  = null;
$go_bg_filter_items = array();

if ( $go_bg_root_term instanceof WP_Term ) {
	$go_bg_children = get_terms(
		array(
			'taxonomy'   => 'category',
			'parent'     => $go_bg_root_term->term_id,
			'hide_empty' => true,
		)
	);
	if ( ! is_wp_error( $go_bg_children ) ) {
		foreach ( $go_bg_children as $go_bg_child ) {
			$go_bg_filter_items[] = array(
				'slug'  => $go_bg_child->slug,
				'label' => $go_bg_child->name,
				'url'   => add_query_arg( 'editoria', $go_bg_child->slug, $go_bg_page_url ),
			);
			if ( $go_bg_filter_slug && $go_bg_filter_slug === $go_bg_child->slug ) {
				$go_bg_filter_term = $go_bg_child;
			}
		}
	}
}

// Filtro por tipo de produto (?tipo=): casa apenas com o TÍTULO do guia —
// busca no conteúdo gerava falsos positivos (todo guia cita "monitor").
$go_bg_product_types = array(
	'headsets'  => array( 'label' => __( 'Headsets', 'go-verge' ), 'terms' => array( 'headset', 'fone' ) ),
	'consoles'  => array( 'label' => __( 'Consoles', 'go-verge' ), 'terms' => array( 'console', 'ps5', 'playstation', 'xbox', 'switch' ) ),
	'controles' => array( 'label' => __( 'Controles', 'go-verge' ), 'terms' => array( 'controle', 'gamepad', 'joystick' ) ),
	'monitores' => array( 'label' => __( 'Monitores e TVs', 'go-verge' ), 'terms' => array( 'monitor', ' tv', 'oled', 'qled' ) ),
	'teclados'  => array( 'label' => __( 'Teclados', 'go-verge' ), 'terms' => array( 'teclado' ) ),
	'mouses'    => array( 'label' => __( 'Mouses', 'go-verge' ), 'terms' => array( 'mouse' ) ),
	'ssd'       => array( 'label' => __( 'SSDs e armazenamento', 'go-verge' ), 'terms' => array( 'ssd', 'armazenamento', 'microsd', 'cartão de memória' ) ),
	'notebooks' => array( 'label' => __( 'Notebooks', 'go-verge' ), 'terms' => array( 'notebook', 'laptop' ) ),
	'cadeiras'  => array( 'label' => __( 'Cadeiras', 'go-verge' ), 'terms' => array( 'cadeira' ) ),
);
$go_bg_type_slug = isset( $_GET['tipo'] ) ? sanitize_title( wp_unslash( $_GET['tipo'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
if ( ! isset( $go_bg_product_types[ $go_bg_type_slug ] ) ) {
	$go_bg_type_slug = '';
}

$go_bg_paged       = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
$go_bg_latest_args = array(
	'post_type'           => 'post',
	'post_status'         => 'publish',
	'posts_per_page'      => 10,
	'paged'               => $go_bg_paged,
	'ignore_sticky_posts' => true,
	'no_found_rows'       => false,
);

$go_bg_tax_query = array();
if ( ! empty( $go_bg_root_ids ) ) {
	$go_bg_tax_query[] = array(
		'taxonomy'         => 'category',
		'field'            => 'term_id',
		'terms'            => $go_bg_root_ids,
		'include_children' => true,
	);
}
if ( $go_bg_filter_term instanceof WP_Term ) {
	$go_bg_tax_query[] = array(
		'taxonomy'         => 'category',
		'field'            => 'term_id',
		'terms'            => array( (int) $go_bg_filter_term->term_id ),
		'include_children' => true,
	);
}
if ( ! empty( $go_bg_tax_query ) ) {
	if ( count( $go_bg_tax_query ) > 1 ) {
		$go_bg_tax_query['relation'] = 'AND';
	}
	$go_bg_latest_args['tax_query'] = $go_bg_tax_query;
}
$go_bg_title_terms = '' !== $go_bg_type_slug ? (array) $go_bg_product_types[ $go_bg_type_slug ]['terms'] : array();
$go_bg_title_where = static function ( $where, $query ) use ( $go_bg_title_terms ) {
	global $wpdb;
	if ( $go_bg_title_terms && $query->get( 'go_bg_type_filter' ) ) {
		$likes = array();
		foreach ( $go_bg_title_terms as $go_bg_term ) {
			$likes[] = $wpdb->prepare( "{$wpdb->posts}.post_title LIKE %s", '%' . $wpdb->esc_like( $go_bg_term ) . '%' );
		}
		$where .= ' AND (' . implode( ' OR ', $likes ) . ')';
	}
	return $where;
};
if ( $go_bg_title_terms ) {
	$go_bg_latest_args['go_bg_type_filter'] = 1;
	$go_bg_latest_args['orderby']           = 'date';
	$go_bg_latest_args['order']             = 'DESC';
	add_filter( 'posts_where', $go_bg_title_where, 10, 2 );
}

$go_bg_latest = new WP_Query( $go_bg_latest_args );
if ( $go_bg_title_terms ) {
	remove_filter( 'posts_where', $go_bg_title_where, 10 );
}

$go_bg_latest_ids = array_map( 'absint', wp_list_pluck( $go_bg_latest->posts, 'ID' ) );
$go_bg_excluded   = array_values( array_unique( array_filter( array_merge( array( $go_bg_feature_id ), $go_bg_lead_ids, $go_bg_latest_ids ) ) ) );

$go_bg_sidebar_modules = function_exists( 'go_verge_archive_sidebar_modules' )
	? go_verge_archive_sidebar_modules( 'guides', $go_bg_excluded )
	: array();
?>
<main id="primary" class="go-main go-buying-guides">
	<div class="go-container go-pagehead go-pagehead--search">
		<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
		<h1 class="go-pagehead__title"><?php echo esc_html( get_the_title() ); ?></h1>
		<?php if ( function_exists( 'go_verge_render_editorial_search' ) ) { go_verge_render_editorial_search( $go_bg_page_url ); } ?>
	</div>

	<div class="go-container go-section go-buying-guides__body">
		<?php if ( $go_bg_feature_id || $go_bg_lead->have_posts() ) : ?>
			<section class="go-games-lead-grid<?php echo ( $go_bg_feature_id && $go_bg_lead->have_posts() ) ? '' : ' go-games-lead-grid--single'; ?>" aria-label="<?php esc_attr_e( 'Guias em destaque', 'go-verge' ); ?>">
				<?php if ( $go_bg_feature_id ) : ?>
					<div class="go-games-lead-grid__feature">
						<?php go_verge_archive_feature( $go_bg_feature_id ); ?>
					</div>
				<?php endif; ?>

				<?php if ( $go_bg_lead->have_posts() ) : ?>
					<div class="go-games-lead-grid__latest">
						<h2 class="go-games-lead-grid__title"><?php esc_html_e( 'Guias recentes', 'go-verge' ); ?></h2>
						<div class="go-games-headlines">
							<?php foreach ( $go_bg_lead->posts as $go_bg_lead_post ) : ?>
								<article class="go-games-headlines__item" data-go-ad-integrity="atomic">
									<?php if ( has_post_thumbnail( $go_bg_lead_post->ID ) ) : ?>
										<a class="go-games-headlines__media go-frame" href="<?php echo esc_url( get_permalink( $go_bg_lead_post->ID ) ); ?>" tabindex="-1" aria-hidden="true">
											<?php echo get_the_post_thumbnail( $go_bg_lead_post->ID, 'go_card', array( 'loading' => 'lazy', 'alt' => '' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
										</a>
									<?php endif; ?>
									<div>
										<h3><a href="<?php echo esc_url( get_permalink( $go_bg_lead_post->ID ) ); ?>"><?php echo esc_html( get_the_title( $go_bg_lead_post->ID ) ); ?></a></h3>
										<div class="go-games-headlines__meta"><?php echo go_verge_time_html( $go_bg_lead_post->ID ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
									</div>
								</article>
							<?php endforeach; ?>
						</div>
					</div>
				<?php endif; ?>
			</section>
		<?php endif; ?>

		<?php if ( class_exists( 'GO_Amazon_Frontend' ) ) : ?>
			<?php
			GO_Amazon_Frontend::instance()->render_deals(
				array(
					'limit'     => 8,
					'title'     => __( 'Ofertas da Amazon', 'go-verge' ),
					'placement' => 'guias-de-compra',
				)
			);
			?>
		<?php endif; ?>

		<section class="go-archive-section go-buying-guides__latest">
			<div data-go-editorial-filter-scope>
				<div class="go-archive-filters">
					<nav class="go-chips go-chips--filter" data-go-editorial-filters aria-label="<?php esc_attr_e( 'Filtrar por tipo de produto', 'go-verge' ); ?>">
						<a href="<?php echo esc_url( remove_query_arg( array( 'tipo', 'editoria' ), $go_bg_page_url ) ); ?>" data-go-editorial-filter="todos"<?php echo ( '' === $go_bg_type_slug && ! $go_bg_filter_term ) ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( go_verge_upper( __( 'Todos', 'go-verge' ) ) ); ?></a>
						<?php foreach ( $go_bg_product_types as $go_bg_type_key => $go_bg_type ) : ?>
							<a href="<?php echo esc_url( add_query_arg( 'tipo', $go_bg_type_key, remove_query_arg( 'editoria', $go_bg_page_url ) ) ); ?>" data-go-editorial-filter="tipo-<?php echo esc_attr( $go_bg_type_key ); ?>"<?php echo $go_bg_type_slug === $go_bg_type_key ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( go_verge_upper( $go_bg_type['label'] ) ); ?></a>
						<?php endforeach; ?>
					</nav>
				</div>

				<?php if ( ! empty( $go_bg_filter_items ) ) : ?>
					<div class="go-archive-filters">
						<nav class="go-chips go-chips--filter" data-go-editorial-filters aria-label="<?php esc_attr_e( 'Filtrar por editoria', 'go-verge' ); ?>">
							<a href="<?php echo esc_url( remove_query_arg( 'editoria', $go_bg_page_url ) ); ?>" data-go-editorial-filter="todas-editorias"<?php echo $go_bg_filter_term ? '' : ' class="is-active" aria-current="page"'; ?>><?php echo esc_html( go_verge_upper( __( 'Todas as editorias', 'go-verge' ) ) ); ?></a>
							<?php foreach ( $go_bg_filter_items as $go_bg_filter_item ) : ?>
								<a href="<?php echo esc_url( $go_bg_filter_item['url'] ); ?>" data-go-editorial-filter="<?php echo esc_attr( $go_bg_filter_item['slug'] ); ?>"<?php echo ( $go_bg_filter_term instanceof WP_Term && $go_bg_filter_term->slug === $go_bg_filter_item['slug'] ) ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( go_verge_upper( $go_bg_filter_item['label'] ) ); ?></a>
							<?php endforeach; ?>
						</nav>
					</div>
				<?php endif; ?>

				<div class="go-archive-body<?php echo $go_bg_sidebar_modules ? ' go-archive-body--aside' : ''; ?>">
					<div class="go-archive-main" data-go-editorial-results aria-live="polite">
						<div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2></div>
						<?php if ( $go_bg_latest->have_posts() ) : ?>
							<div id="go-buying-guides-feed" class="go-archive-list" data-go-latest-feed>
								<?php
								while ( $go_bg_latest->have_posts() ) :
									$go_bg_latest->the_post();
									go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true ) );
								endwhile;
								wp_reset_postdata();
								?>
							</div>
							<?php
							$go_bg_pagination_args = array();
							if ( '' !== $go_bg_type_slug ) {
								$go_bg_pagination_args['tipo'] = $go_bg_type_slug;
							}
							if ( $go_bg_filter_term instanceof WP_Term ) {
								$go_bg_pagination_args['editoria'] = $go_bg_filter_term->slug;
							}
							go_verge_pagination( $go_bg_latest, $go_bg_pagination_args, array( 'target' => '#go-buying-guides-feed' ) );
							?>
						<?php else : ?>
							<div id="go-buying-guides-feed" class="go-archive-list">
								<?php get_template_part( 'template-parts/content', 'none' ); ?>
							</div>
						<?php endif; ?>
					</div>

					<?php if ( $go_bg_sidebar_modules ) { go_verge_render_archive_sidebar( $go_bg_sidebar_modules ); } ?>
				</div>
			</div>
		</section>
	</div>
</main>
<?php
wp_reset_postdata();
get_footer();
