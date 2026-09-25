<?php
/** Editorial topic hub: /assunto/{slug}/ */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
$slug  = sanitize_title( (string) get_query_var( 'go_topic' ) );
$label = go_verge_v21_topic_label( $slug );
$paged = max( 1, (int) get_query_var( 'paged' ) );
$type_filter = function_exists( 'go_verge_v45_subject_active_type' ) ? go_verge_v45_subject_active_type() : '';
$all_query = go_verge_v21_topic_query( $slug, 1, 500 );
$hub_post_ids = array_values( array_filter( array_map( 'absint', wp_list_pluck( $all_query->posts, 'ID' ) ) ) );
$query = go_verge_v21_topic_query( $slug, $paged, 14, $type_filter );
$follow_term = function_exists( 'go_verge_v44_topic_follow_term' ) ? go_verge_v44_topic_follow_term( $slug, $label ) : null;
?>
<main id="primary" class="go-main od-topic-page">
	<header class="go-container go-pagehead od-topic__head">
		<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
		<div class="od-topic__heading"><h1 class="go-pagehead__title"><?php echo esc_html( $label ); ?></h1></div>
		<?php if ( $follow_term instanceof WP_Term && function_exists( 'go_verge_product_follow_button' ) ) : ?>
			<div class="od-topic__actions">
				<?php go_verge_product_follow_button( (int) $follow_term->term_id, 'post_tag', sprintf( __( 'Seguir %s', 'go-verge' ), $label ) ); ?>
			</div>
		<?php endif; ?>
	</header>

	<section class="go-container go-section go-archive-page od-topic__content" aria-labelledby="go-topic-latest-v21">
		<div class="go-section__head"><h2 class="go-section__title" id="go-topic-latest-v21"><?php esc_html_e( 'Últimas publicações', 'go-verge' ); ?></h2></div>
		<?php if ( function_exists( 'go_verge_v45_render_subject_type_filters' ) ) { go_verge_v45_render_subject_type_filters( $hub_post_ids, go_verge_v21_topic_hub_url( $label ), $type_filter ); } ?>
		<div class="go-archive-list od-topic__feed go-topic-hub-v21__feed" data-go-latest-feed>
		<?php if ( $query->have_posts() ) : while ( $query->have_posts() ) : $query->the_post(); ?>
			<?php if ( function_exists( 'go_verge_archive_list_item' ) ) { go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt'=>true, 'show_type'=>false, 'show_score'=>false, 'media_context'=>'latest' ) ); } else { ?>
			<article class="go-topic-hub-v21__fallback"><a href="<?php the_permalink(); ?>"><?php the_post_thumbnail( 'go_card' ); ?><h3><?php the_title(); ?></h3></a></article>
			<?php } ?>
		<?php endwhile; else : ?><p><?php esc_html_e( 'Ainda não há publicações suficientes neste assunto.', 'go-verge' ); ?></p><?php endif; ?>
		</div>
		<?php
		if ( function_exists( 'go_verge_pagination' ) ) {
			go_verge_pagination(
				$query,
				array(),
				array(
					'mode'          => 'archive-list',
					'target'        => '.go-topic-hub-v21__feed',
					'label'         => __( 'Carregar mais publicações', 'go-verge' ),
					'media_context' => 'latest',
					'next_url'      => $type_filter ? add_query_arg( 'tipo', $type_filter, get_pagenum_link( $paged + 1 ) ) : '',
				)
			);
		}
		?>

		<?php if ( 1 === $paged && function_exists( 'go_verge_v46_render_related_subjects' ) ) {
			go_verge_v46_render_related_subjects( $hub_post_ids, go_verge_v21_topic_hub_url( $label ), 5 );
		} ?>
	</section>
</main>
<?php wp_reset_postdata(); get_footer(); ?>
