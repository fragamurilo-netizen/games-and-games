<?php
/** Template Name: Especiais */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$collection_page = go_verge_specials_gallery_page();
$special_ids = go_verge_specials_gallery_ids();
$collection = new WP_Query( array(
	'post_type' => 'post', 'post_status' => 'publish', 'has_password' => false,
	'post__in' => $special_ids ?: array( 0 ), 'posts_per_page' => 13, 'paged' => $collection_page,
	'orderby' => array( 'date' => 'DESC', 'ID' => 'DESC' ), 'ignore_sticky_posts' => true,
) );
if ( go_verge_render_empty_pagination_404( $collection, $collection_page ) ) { return; }
get_header();
?>
<main id="primary" class="go-main od-specials">
	<header class="go-container od-specials__intro">
		<h1><?php esc_html_e( 'Especiais', 'go-verge' ); ?></h1>
	</header>
	<div class="go-container od-specials__collection">
		<?php if ( $collection->posts ) : ?>
			<?php $collection_posts = $collection->posts; ?>
			<?php if ( 1 === $collection_page ) { $lead = array_shift( $collection_posts ); go_verge_specials_gallery_card( $lead->ID, true ); } ?>
			<?php if ( $collection_posts ) : ?>
				<div class="od-specials__section-head"><h2><?php esc_html_e( 'Mais especiais', 'go-verge' ); ?></h2><span><?php printf( esc_html__( '%s especiais', 'go-verge' ), number_format_i18n( $collection->found_posts ) ); ?></span></div>
				<div class="od-specials__grid"><?php foreach ( $collection_posts as $special_post ) { go_verge_specials_gallery_card( $special_post->ID ); } ?></div>
			<?php endif; ?>
			<?php if ( $collection->max_num_pages > 1 ) : ?>
				<nav class="od-specials__pagination" aria-label="<?php esc_attr_e( 'Páginas de especiais', 'go-verge' ); ?>">
					<?php if ( $collection_page > 1 ) : ?><a rel="prev" href="<?php echo esc_url( go_verge_specials_gallery_page_url( $collection_page - 1 ) ); ?>"><?php esc_html_e( 'Anteriores', 'go-verge' ); ?></a><?php endif; ?>
					<span><?php printf( esc_html__( 'Página %1$d de %2$d', 'go-verge' ), $collection_page, $collection->max_num_pages ); ?></span>
					<?php if ( $collection_page < $collection->max_num_pages ) : ?><a rel="next" href="<?php echo esc_url( go_verge_specials_gallery_page_url( $collection_page + 1 ) ); ?>"><?php esc_html_e( 'Próximos', 'go-verge' ); ?></a><?php endif; ?>
				</nav>
			<?php endif; ?>
		<?php else : ?>
			<div class="od-specials__empty"><h2><?php esc_html_e( 'Nenhum especial disponível', 'go-verge' ); ?></h2><a href="<?php echo esc_url( go_verge_latest_url() ); ?>"><?php esc_html_e( 'Ver últimas publicações', 'go-verge' ); ?></a></div>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
