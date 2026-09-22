<?php
/** Dedicated search landing page. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();

$go_search_recent = new WP_Query(
	array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => 6,
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
	)
);
?>
<main id="primary" class="go-main go-search-landing">
	<section class="go-container go-search-page__hero go-search-page__hero--landing">
		<div class="go-search-page__heading">
			<?php go_verge_breadcrumbs(); ?>
			<h1 class="go-pagehead__title"><?php esc_html_e( 'Busca', 'go-verge' ); ?></h1>
		</div>
		<form class="go-search-page__form" method="get" action="<?php echo esc_url( home_url( '/' ) ); ?>" role="search">
			<label class="screen-reader-text" for="go-search-landing-input"><?php esc_html_e( 'Buscar no site', 'go-verge' ); ?></label>
			<input id="go-search-landing-input" type="search" name="s" value="" placeholder="<?php esc_attr_e( 'Busque jogos, reviews, notícias, autores…', 'go-verge' ); ?>" autocomplete="off">
			<button type="submit" class="go-btn go-btn--mint"><?php esc_html_e( 'Buscar', 'go-verge' ); ?></button>
		</form>
	</section>

	<?php if ( $go_search_recent->have_posts() ) : ?>
		<section class="go-container go-section">
			<div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2></div>
			<div class="go-archive-list" data-go-latest-feed>
				<?php foreach ( $go_search_recent->posts as $post ) : go_verge_archive_list_item( $post->ID, array( 'show_excerpt' => true ) ); endforeach; ?>
			</div>
		</section>
	<?php endif; ?>
</main>
<?php get_footer(); ?>
