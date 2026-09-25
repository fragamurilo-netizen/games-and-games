<?php
/**
 * Template Name: Últimas
 *
 * Latest-publications surface with contextual filters and the same clean
 * horizontal feed used on the homepage, adapted to a full archive page.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$go_verge_paged  = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
$go_verge_filter = isset( $_GET['editoria'] ) && is_scalar( $_GET['editoria'] ) ? sanitize_title( wp_unslash( (string) $_GET['editoria'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
$go_verge_posts_page_id = (int) get_option( 'page_for_posts' );
$go_verge_page_url = $go_verge_posts_page_id ? get_permalink( $go_verge_posts_page_id ) : '';
if ( ! $go_verge_page_url ) {
	$go_verge_page_object = get_queried_object();
	$go_verge_page_url = $go_verge_page_object instanceof WP_Post ? get_permalink( $go_verge_page_object ) : home_url( '/ultimas-publicacoes/' );
}

/* The full latest page keeps only the five high-intent editorial filters. */
$go_verge_filter_candidates = array(
	array( 'key' => 'games', 'accent' => 'games', 'label' => __( 'Games', 'go-verge' ), 'slugs' => array( 'games', 'jogos' ) ),
	array( 'key' => 'entertainment', 'accent' => 'entertainment', 'label' => __( 'Entretenimento', 'go-verge' ), 'slugs' => array( 'entretenimento', 'entertainment' ) ),
	array( 'key' => 'technology', 'accent' => 'technology', 'label' => __( 'Tecnologia', 'go-verge' ), 'slugs' => array( 'tecnologia', 'technology', 'tech' ) ),
	array( 'key' => 'reviews', 'accent' => 'reviews', 'label' => __( 'Reviews', 'go-verge' ), 'slugs' => array( 'reviews', 'review' ) ),
	array( 'key' => 'criticas', 'accent' => 'criticas', 'label' => __( 'Críticas', 'go-verge' ), 'slugs' => array( 'criticas', 'critica' ) ),
);
$go_verge_filters = array();
foreach ( $go_verge_filter_candidates as $go_verge_candidate ) {
	foreach ( $go_verge_candidate['slugs'] as $go_verge_slug ) {
		$go_verge_term = get_category_by_slug( $go_verge_slug );
		if ( $go_verge_term instanceof WP_Term && (int) $go_verge_term->count > 0 ) {
			$go_verge_filters[] = array(
				'key'    => $go_verge_candidate['key'],
				'accent' => $go_verge_candidate['accent'],
				'label'  => $go_verge_candidate['label'],
				'slug'   => $go_verge_term->slug,
				'id'     => (int) $go_verge_term->term_id,
			);
			break;
		}
	}
}

$go_verge_selected = null;
foreach ( $go_verge_filters as $go_verge_filter_item ) {
	if ( $go_verge_filter && $go_verge_filter === $go_verge_filter_item['slug'] ) {
		$go_verge_selected = $go_verge_filter_item;
		break;
	}
}
if ( ! $go_verge_selected ) {
	$go_verge_filter = '';
}

$go_verge_latest_args = array(
	'post_type'           => 'post',
	'post_status'         => 'publish',
	'posts_per_page'      => 15,
	'paged'               => $go_verge_paged,
	'ignore_sticky_posts' => true,
	'no_found_rows'       => false,
);
if ( $go_verge_selected ) {
	$go_verge_latest_args['cat'] = (int) $go_verge_selected['id'];
}
$go_verge_latest = new WP_Query( $go_verge_latest_args );
if ( function_exists( 'go_verge_render_empty_pagination_404' ) && go_verge_render_empty_pagination_404( $go_verge_latest, $go_verge_paged ) ) {
	return;
}
$go_verge_latest_ids = array_map( 'absint', wp_list_pluck( $go_verge_latest->posts, 'ID' ) );

get_header();

/* Contextual sidebar: selected editorias inherit their own plan. */
$go_verge_sidebar_modules = array();
if ( $go_verge_selected && function_exists( 'go_verge_archive_sidebar_modules' ) ) {
	$go_verge_sidebar_modules = go_verge_archive_sidebar_modules( $go_verge_selected['accent'], $go_verge_latest_ids );
} else {
	$go_verge_seen = $go_verge_latest_ids;
	$go_verge_popular = function_exists( 'go_verge_global_popular_posts' ) ? go_verge_global_popular_posts( $go_verge_seen, 5 ) : array();
	if ( $go_verge_popular ) {
		$go_verge_sidebar_modules[] = array( 'title' => __( 'Mais lidas', 'go-verge' ), 'ranked' => false, 'posts' => $go_verge_popular );
		$go_verge_seen = array_merge( $go_verge_seen, array_map( 'absint', wp_list_pluck( $go_verge_popular, 'ID' ) ) );
	}
	$go_verge_reviews = go_verge_query_editorial_posts(
		array( 'reviews', 'review', 'analises', 'analises-de-jogos' ),
		4,
		array( 'post__not_in' => $go_verge_seen ),
		array( 'review', 'analise' )
	)->posts;
	if ( $go_verge_reviews ) {
		$go_verge_sidebar_modules[] = array( 'title' => __( 'Reviews recentes', 'go-verge' ), 'ranked' => false, 'posts' => $go_verge_reviews );
		$go_verge_seen = array_merge( $go_verge_seen, array_map( 'absint', wp_list_pluck( $go_verge_reviews, 'ID' ) ) );
	}
	$go_verge_critiques = go_verge_query_editorial_posts(
		array( 'criticas', 'critica' ),
		4,
		array( 'post__not_in' => $go_verge_seen ),
		array( 'critica' )
	)->posts;
	if ( $go_verge_critiques ) {
		$go_verge_sidebar_modules[] = array( 'title' => __( 'Críticas recentes', 'go-verge' ), 'ranked' => false, 'posts' => $go_verge_critiques );
	}
}
?>

<main id="primary" class="go-main go-latest-page go-home-latest-editorial">
	<div class="go-container go-pagehead go-latest-page__head">
		<h1 class="go-pagehead__title"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h1>
	</div>

	<div class="go-container go-section go-archive-page go-latest-page__content">
		<?php if ( $go_verge_filters ) : ?>
			<nav class="go-latest-filters" data-go-latest-filters data-page-url="<?php echo esc_url( $go_verge_page_url ); ?>" aria-label="<?php esc_attr_e( 'Filtrar publicações por editoria', 'go-verge' ); ?>">
				<a class="go-latest-filter<?php echo '' === $go_verge_filter ? ' is-active' : ''; ?>" data-go-latest-filter data-editoria="" href="<?php echo esc_url( remove_query_arg( 'editoria', $go_verge_page_url ) ); ?>"<?php echo '' === $go_verge_filter ? ' aria-current="page"' : ''; ?>>
					<?php esc_html_e( 'Todas', 'go-verge' ); ?>
				</a>
				<?php foreach ( $go_verge_filters as $go_verge_filter_item ) : ?>
					<a class="go-latest-filter<?php echo $go_verge_filter === $go_verge_filter_item['slug'] ? ' is-active' : ''; ?>" data-go-latest-filter data-editoria="<?php echo esc_attr( $go_verge_filter_item['slug'] ); ?>" data-editorial-color="<?php echo esc_attr( $go_verge_filter_item['accent'] ); ?>" href="<?php echo esc_url( add_query_arg( 'editoria', $go_verge_filter_item['slug'], $go_verge_page_url ) ); ?>"<?php echo $go_verge_filter === $go_verge_filter_item['slug'] ? ' aria-current="page"' : ''; ?>>
						<?php echo esc_html( $go_verge_filter_item['label'] ); ?>
					</a>
				<?php endforeach; ?>
			</nav>
		<?php endif; ?>

		<div class="go-archive-body<?php echo $go_verge_sidebar_modules ? ' go-archive-body--aside' : ''; ?>" data-go-latest-results aria-live="polite">
			<div class="go-archive-main">
				<?php if ( $go_verge_latest->have_posts() ) : ?>
					<div id="go-latest-page-feed" class="go-archive-list"<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
						<?php
						while ( $go_verge_latest->have_posts() ) :
							$go_verge_latest->the_post();
							go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'media_context' => 'latest' ) );
						endwhile;
						wp_reset_postdata();
						?>
					</div>
					<div data-go-latest-pagination>
						<?php go_verge_pagination( $go_verge_latest, array(), array( 'target' => '#go-latest-page-feed', 'media_context' => 'latest' ) ); ?>
					</div>
				<?php else : ?>
					<div id="go-latest-page-feed" class="go-archive-list"<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>><?php get_template_part( 'template-parts/content', 'none' ); ?></div>
					<div data-go-latest-pagination></div>
				<?php endif; ?>
			</div>

			<?php if ( $go_verge_sidebar_modules ) { go_verge_render_archive_sidebar( $go_verge_sidebar_modules ); } ?>
		</div>
	</div>
</main>

<?php get_footer(); ?>
