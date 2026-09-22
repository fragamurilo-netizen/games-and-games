<?php
/** Server-rendered, paginated format view; all article links retain their URLs. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$od_format_context = go_verge_desk_format_context();
$od_format_query = go_verge_desk_format_query();
$od_desk_label = go_verge_editorial_pillars()[ $od_format_context['desk'] ]['label'];
$od_format_label = $od_format_context['formats'][ $od_format_context['type'] ];
$od_format_style = in_array( $od_format_context['type'], array( 'review', 'critica' ), true ) ? 'reviews' : 'default';
get_header();
?>
<main id="primary" class="go-main">
	<div class="go-container go-pagehead go-pagehead--search">
		<nav class="go-breadcrumbs" aria-label="Caminho de navegação"><a href="<?php echo esc_url( home_url( '/' ) ); ?>">Início</a> / <a href="<?php echo esc_url( go_verge_desk_format_url( $od_format_context['desk'] ) ); ?>"><?php echo esc_html( $od_desk_label ); ?></a></nav>
		<h1 class="go-pagehead__title"><?php echo esc_html( $od_desk_label . ': ' . $od_format_label ); ?></h1>
	</div>
	<div class="go-container go-section go-archive-page od-desk-results">
		<div class="go-archive-filters"><?php go_verge_render_desk_format_links( $od_format_context['desk'] ); ?></div>
		<?php if ( $od_format_query->have_posts() ) : ?>
			<?php foreach ( $od_format_query->posts as $od_format_post ) { go_verge_archive_list_item( $od_format_post->ID, array( 'format' => $od_format_style ) ); } ?>
			<?php if ( $od_format_query->max_num_pages > 1 ) : ?>
				<nav class="od-desk-pagination" aria-label="Paginação">
					<?php if ( $od_format_context['page'] > 1 ) : ?><a rel="prev" href="<?php echo esc_url( go_verge_desk_format_url( $od_format_context['desk'], $od_format_context['type'], $od_format_context['page'] - 1 ) ); ?>">← Anterior</a><?php endif; ?>
					<span><?php echo esc_html( sprintf( 'Página %d de %d', $od_format_context['page'], $od_format_query->max_num_pages ) ); ?></span>
					<?php if ( $od_format_context['page'] < $od_format_query->max_num_pages ) : ?><a rel="next" href="<?php echo esc_url( go_verge_desk_format_url( $od_format_context['desk'], $od_format_context['type'], $od_format_context['page'] + 1 ) ); ?>">Próxima →</a><?php endif; ?>
				</nav>
			<?php endif; ?>
		<?php else : ?>
			<p>Ainda não há matérias deste tipo nesta editoria.</p>
			<p><a href="<?php echo esc_url( go_verge_desk_format_url( $od_format_context['desk'] ) ); ?>"><?php echo esc_html( 'Ver todas as publicações de ' . $od_desk_label ); ?></a></p>
		<?php endif; ?>
	</div>
</main>
<?php get_footer(); ?>
