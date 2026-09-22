<?php
/** Tag archive: a clear subject header and one chronological editorial feed. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
$od_tag = get_queried_object();
$od_tag_label = single_tag_title( '', false );
$od_tag_description = tag_description();
?>
<main id="primary" class="go-main od-topic-page">
	<header class="go-container go-pagehead od-topic__head">
		<?php go_verge_breadcrumbs(); ?>
		<div class="od-topic__heading">
			<h1 class="go-pagehead__title"><?php echo esc_html( $od_tag_label ); ?></h1>
			<?php if ( $od_tag_description ) : ?><div class="go-pagehead__desc"><?php echo wp_kses_post( $od_tag_description ); ?></div><?php endif; ?>
		</div>
		<?php if ( $od_tag instanceof WP_Term && function_exists( 'go_verge_product_follow_button' ) ) : ?>
			<div class="od-topic__actions"><?php go_verge_product_follow_button( (int) $od_tag->term_id, 'post_tag', sprintf( __( 'Seguir %s', 'go-verge' ), $od_tag_label ) ); ?></div>
		<?php endif; ?>
	</header>
	<section class="go-container go-section go-archive-page od-topic__content" aria-labelledby="od-tag-latest">
		<div class="go-section__head"><h2 class="go-section__title" id="od-tag-latest"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2></div>
		<?php if ( have_posts() ) : ?>
			<div class="go-archive-list od-topic__feed" data-go-latest-feed>
				<?php
				while ( have_posts() ) : the_post();
					go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'show_type' => false, 'media_context' => 'latest' ) );
				endwhile;
				?>
			</div>
			<?php go_verge_pagination( null, array(), array( 'mode' => 'archive-list', 'target' => '.od-topic__feed', 'media_context' => 'latest', 'label' => __( 'Carregar mais publicações', 'go-verge' ) ) ); ?>
		<?php else : get_template_part( 'template-parts/content', 'none' ); endif; ?>
	</section>
</main>
<?php get_footer(); ?>
