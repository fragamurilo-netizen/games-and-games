<?php
/**
 * Permanent newsroom for Google News discovery and readers.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

$go_news_page     = max( 1, (int) get_query_var( 'paged' ) );
$go_news_per_page = function_exists( 'go_verge_news_authority_per_page' ) ? go_verge_news_authority_per_page() : 20;
$go_news_all_ids  = function_exists( 'go_verge_news_authority_story_ids' ) ? go_verge_news_authority_story_ids() : array();
$go_news_ids      = function_exists( 'go_verge_news_authority_page_ids' ) ? go_verge_news_authority_page_ids( $go_news_page, $go_news_per_page ) : array();
$go_news_total    = count( $go_news_all_ids );
$go_news_pages    = max( 1, (int) ceil( $go_news_total / $go_news_per_page ) );
$go_news_query    = $go_news_ids ? new WP_Query(
	array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'post__in'            => $go_news_ids,
		'orderby'             => 'post__in',
		'posts_per_page'      => count( $go_news_ids ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
	)
) : null;

if ( function_exists( 'go_verge_render_empty_pagination_404' ) && go_verge_render_empty_pagination_404( $go_news_query, $go_news_page ) ) {
	return;
}

get_header();
?>

<main id="primary" class="go-main go-latest-page go-home-latest-editorial go-newsroom">
	<div class="go-container go-pagehead go-latest-page__head">
		<h1 class="go-pagehead__title"><?php esc_html_e( 'Notícias', 'go-verge' ); ?></h1>
		<?php
		/* No standfirst here. The line that used to sit under the H1 described the
		 * section to the reader who had already chosen it, and pushed the first
		 * headline down. The same sentence still serves search as the meta
		 * description, where it is read by someone deciding whether to click. */
		?>
	</div>

	<div class="go-container go-section go-archive-page go-latest-page__content">
		<nav class="go-latest-filters" aria-label="<?php esc_attr_e( 'Navegar pelas principais editorias', 'go-verge' ); ?>">
			<a class="go-latest-filter is-active" aria-current="page" href="<?php echo esc_url( go_verge_newsroom_url() ); ?>"><?php esc_html_e( 'Notícias', 'go-verge' ); ?></a>
			<a class="go-latest-filter" href="<?php echo esc_url( home_url( '/games/' ) ); ?>"><?php esc_html_e( 'Games', 'go-verge' ); ?></a>
			<a class="go-latest-filter" href="<?php echo esc_url( home_url( '/entretenimento/' ) ); ?>"><?php esc_html_e( 'Entretenimento', 'go-verge' ); ?></a>
			<a class="go-latest-filter" href="<?php echo esc_url( home_url( '/tecnologia/' ) ); ?>"><?php esc_html_e( 'Tecnologia', 'go-verge' ); ?></a>
		</nav>

		<div class="go-archive-body">
			<div class="go-archive-main">
				<?php if ( $go_news_query instanceof WP_Query && $go_news_query->have_posts() ) : ?>
					<div id="go-newsroom-feed" class="go-archive-list">
						<?php
						while ( $go_news_query->have_posts() ) :
							$go_news_query->the_post();
							go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'media_context' => 'latest' ) );
						endwhile;
						wp_reset_postdata();
						?>
					</div>

					<?php if ( $go_news_pages > 1 ) : ?>
						<nav class="navigation pagination" aria-label="<?php esc_attr_e( 'Paginação de notícias', 'go-verge' ); ?>">
							<div class="nav-links">
								<?php
								echo wp_kses_post(
									paginate_links(
										array(
											'base'      => str_replace( '999999999', '%#%', go_verge_newsroom_url( 999999999 ) ),
											'format'    => '',
											'current'   => $go_news_page,
											'total'     => $go_news_pages,
											'prev_text' => __( 'Anterior', 'go-verge' ),
											'next_text' => __( 'Próxima', 'go-verge' ),
										)
									)
								);
								?>
							</div>
						</nav>
					<?php endif; ?>
				<?php else : ?>
					<div id="go-newsroom-feed" class="go-archive-list"><?php get_template_part( 'template-parts/content', 'none' ); ?></div>
				<?php endif; ?>
			</div>
		</div>
	</div>
</main>

<?php get_footer(); ?>
