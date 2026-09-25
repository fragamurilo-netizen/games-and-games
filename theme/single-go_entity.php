<?php
/**
 * Curated entity subject hub.
 * V45 keeps people, characters and other entities intentionally simple:
 * identity + follow + one complete paginated editorial stream.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
while ( have_posts() ) : the_post();
	$entity_id = get_the_ID();
	$page      = function_exists( 'go_verge_v45_subject_page' ) ? go_verge_v45_subject_page() : 1;
	$type_filter = function_exists( 'go_verge_v45_subject_active_type' ) ? go_verge_v45_subject_active_type() : '';
	$data      = function_exists( 'go_verge_v45_subject_page_data' )
		? go_verge_v45_subject_page_data( $entity_id, 'go_entity', $page, $type_filter )
		: array( 'ids' => ( function_exists( 'go_verge_product_related_post_ids' ) ? go_verge_product_related_post_ids( $entity_id, 'go_entity', 14 ) : array() ), 'total_pages' => 1 );
	$ids       = array_values( array_filter( array_map( 'absint', (array) ( $data['ids'] ?? array() ) ) ) );
	$unfiltered_ids = array_values( array_filter( array_map( 'absint', (array) ( $data['all_ids_unfiltered'] ?? ( $data['all_ids'] ?? $ids ) ) ) ) );
	$editorial_bg = '';
	foreach ( $unfiltered_ids as $story_id ) {
		if ( has_post_thumbnail( $story_id ) ) { $editorial_bg = wp_get_attachment_image_url( get_post_thumbnail_id( $story_id ), 'full' ); break; }
	}
	if ( ! $editorial_bg && has_post_thumbnail( $entity_id ) ) { $editorial_bg = wp_get_attachment_image_url( get_post_thumbnail_id( $entity_id ), 'full' ); }
	$page_style = $editorial_bg ? '--go-editorial-page-bg:url(' . esc_url_raw( $editorial_bg ) . ');' : '';
?>
<main id="primary" class="go-main go-entity-single-v40<?php echo $editorial_bg ? ' has-editorial-page-bg' : ''; ?>"<?php echo $page_style ? ' style="' . esc_attr( $page_style ) . '"' : ''; ?>>
	<header class="go-container go-entity-hero-v40">
		<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
		<div class="go-entity-hero-v40__inner<?php echo has_post_thumbnail() ? ' has-media' : ''; ?>">
			<?php if ( has_post_thumbnail() ) : ?>
				<figure class="go-entity-hero-v40__media"><?php the_post_thumbnail( 'thumbnail', array( 'loading'=>'eager', 'fetchpriority'=>'high', 'decoding'=>'async' ) ); ?></figure>
			<?php endif; ?>
			<div class="go-entity-hero-v40__copy">
				<h1 class="go-entity-hero-v40__title"><?php the_title(); ?></h1>
				<?php if ( function_exists( 'go_verge_product_follow_button' ) ) : ?>
					<div class="go-entity-hero-v40__actions"><?php go_verge_product_follow_button( $entity_id, 'go_entity' ); ?></div>
				<?php endif; ?>
			</div>
		</div>
	</header>

	<section class="go-container go-section go-entity-latest-v40" aria-labelledby="go-entity-latest-<?php echo esc_attr( $entity_id ); ?>">
		<div class="go-section__head"><h2 id="go-entity-latest-<?php echo esc_attr( $entity_id ); ?>" class="go-section__title"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2></div>
		<?php if ( function_exists( 'go_verge_v45_render_subject_type_filters' ) ) { go_verge_v45_render_subject_type_filters( $unfiltered_ids, get_permalink( $entity_id ), $type_filter ); } ?>
		<?php if ( $ids ) :
			$all_subject_ids = array_values( array_filter( array_map( 'absint', (array) ( $data['all_ids'] ?? $ids ) ) ) );
			$q = new WP_Query( array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'post__in'            => $all_subject_ids,
				'orderby'             => 'post__in',
				'posts_per_page'      => function_exists( 'go_verge_v45_subject_per_page' ) ? go_verge_v45_subject_per_page() : 14,
				'paged'               => $page,
				'ignore_sticky_posts' => true,
				'no_found_rows'       => false,
			) );
		?>
			<div id="go-entity-latest-feed" class="go-stream" data-go-latest-feed<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
				<?php while ( $q->have_posts() ) : $q->the_post(); go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt'=>true, 'show_type'=>false, 'show_score'=>false, 'media_context'=>'latest' ) ); endwhile; wp_reset_postdata(); ?>
			</div>
			<?php if ( function_exists( 'go_verge_pagination' ) ) {
				$next_url = $type_filter ? add_query_arg( 'tipo', $type_filter, go_verge_v45_subject_page_url( $entity_id, $page + 1 ) ) : '';
				go_verge_pagination( $q, array(), array( 'mode'=>'archive-list', 'target'=>'#go-entity-latest-feed', 'media_context'=>'latest', 'next_url'=>$next_url ) );
			} ?>
			<?php if ( 1 === $page && function_exists( 'go_verge_v46_render_related_subjects' ) ) { go_verge_v46_render_related_subjects( $unfiltered_ids, get_permalink( $entity_id ), 5 ); } ?>
		<?php else : ?>
			<p class="go-hub-empty"><?php esc_html_e( 'Ainda não há matérias publicadas sobre este assunto.', 'go-verge' ); ?></p>
		<?php endif; ?>
	</section>
</main>
<?php endwhile; get_footer(); ?>
