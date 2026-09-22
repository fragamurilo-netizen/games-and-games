<?php
/**
 * Dedicated video hub.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$go_video_platforms = function_exists( 'go_verge_video_platform_definitions' ) ? go_verge_video_platform_definitions() : array();
$go_video_channels  = array();
foreach ( $go_video_platforms as $go_video_key => $go_video_platform ) {
	$go_video_channels[ $go_video_key ] = function_exists( 'go_verge_platform_video_items' ) ? go_verge_platform_video_items( $go_video_key, 8 ) : array();
}
$go_video_articles   = function_exists( 'go_verge_local_video_article_items' ) ? go_verge_local_video_article_items( 18 ) : array();
$go_video_lead_items = function_exists( 'go_verge_all_platform_video_items' ) ? array_slice( go_verge_all_platform_video_items( 3 ), 0, 8 ) : array();
if ( empty( $go_video_lead_items ) && ! empty( $go_video_articles ) ) {
	$go_video_lead_items = array_slice( $go_video_articles, 0, 8 );
}
?>

<main id="primary" class="go-main go-videos-page">
	<section class="go-container go-videos-page__hero">
		<h1><?php esc_html_e( 'Vídeos', 'go-verge' ); ?></h1>
	</section>

	<?php if ( ! empty( $go_video_lead_items ) ) : ?>
		<section class="go-container go-section go-videos-page__featured" id="go-video-player">
			<div class="go-videos-page__section-head"><h2><?php esc_html_e( 'Em destaque', 'go-verge' ); ?></h2></div>
			<?php go_verge_render_home_video_hub( $go_video_lead_items ); ?>
		</section>
	<?php endif; ?>

	<section class="go-container go-section go-videos-page__channels" data-go-video-platform-tabs>
		<div class="go-videos-page__section-head">
			<h2><?php esc_html_e( 'Canais', 'go-verge' ); ?></h2>
			<div class="go-videos-page__tabs" role="tablist" aria-label="<?php esc_attr_e( 'Plataformas', 'go-verge' ); ?>">
				<?php $go_video_tab_index = 0; ?>
				<?php foreach ( $go_video_platforms as $go_video_key => $go_video_platform ) : ?>
					<button type="button" role="tab" class="go-videos-page__tab<?php echo 0 === $go_video_tab_index ? ' is-active' : ''; ?>" data-go-video-platform-tab="<?php echo esc_attr( $go_video_key ); ?>" aria-selected="<?php echo 0 === $go_video_tab_index ? 'true' : 'false'; ?>">
						<?php echo esc_html( $go_video_platform['label'] ); ?>
					</button>
					<?php ++$go_video_tab_index; ?>
				<?php endforeach; ?>
			</div>
		</div>

		<?php $go_video_panel_index = 0; ?>
		<?php foreach ( $go_video_platforms as $go_video_key => $go_video_platform ) : ?>
			<?php $go_video_items = isset( $go_video_channels[ $go_video_key ] ) ? $go_video_channels[ $go_video_key ] : array(); ?>
			<div class="go-videos-page__panel<?php echo 0 === $go_video_panel_index ? ' is-active' : ''; ?>" data-go-video-platform-panel="<?php echo esc_attr( $go_video_key ); ?>" role="tabpanel"<?php echo 0 === $go_video_panel_index ? '' : ' hidden'; ?>>
				<?php if ( ! empty( $go_video_items ) ) : ?>
					<div class="go-videos-page__channel-grid">
						<?php foreach ( $go_video_items as $go_video_item ) : ?>
							<article class="go-videos-page__video-card">
								<button type="button" class="go-videos-page__video-thumb" data-go-video-load data-video-id="<?php echo esc_attr( $go_video_item['id'] ?? '' ); ?>" data-video-title="<?php echo esc_attr( $go_video_item['title'] ?? '' ); ?>" data-video-source="<?php echo esc_attr( $go_video_item['channel'] ?? $go_video_platform['label'] ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Reproduzir %s', 'go-verge' ), $go_video_item['title'] ?? __( 'vídeo', 'go-verge' ) ) ); ?>">
									<img src="<?php echo esc_url( $go_video_item['thumbnail'] ); ?>" alt="" width="480" height="270" loading="lazy" decoding="async">
									<span class="go-videos-page__video-play" aria-hidden="true">▶</span>
								</button>
								<span class="go-videos-page__video-copy">
									<?php if ( ! empty( $go_video_item['url'] ) ) : ?>
										<a href="<?php echo esc_url( $go_video_item['url'] ); ?>"<?php echo empty( $go_video_item['is_article'] ) ? ' target="_blank" rel="noopener noreferrer"' : ''; ?>><strong><?php echo esc_html( $go_video_item['title'] ); ?></strong></a>
									<?php else : ?>
										<strong><?php echo esc_html( $go_video_item['title'] ); ?></strong>
									<?php endif; ?>
									<?php if ( ! empty( $go_video_item['published'] ) ) : ?><time datetime="<?php echo esc_attr( gmdate( 'c', (int) $go_video_item['published'] ) ); ?>"><?php echo esc_html( human_time_diff( (int) $go_video_item['published'], current_time( 'timestamp', true ) ) ); ?></time><?php endif; ?>
								</span>
							</article>
						<?php endforeach; ?>
					</div>
				<?php endif; ?>
			</div>
			<?php ++$go_video_panel_index; ?>
		<?php endforeach; ?>
	</section>

	<?php if ( ! empty( $go_video_articles ) ) : ?>
		<section class="go-container go-section go-videos-page__articles">
			<div class="go-videos-page__section-head"><h2><?php esc_html_e( 'Vídeos', 'go-verge' ); ?></h2></div>
			<div class="go-videos-page__article-grid">
				<?php foreach ( $go_video_articles as $go_video_item ) : ?>
					<article class="go-videos-page__article-card">
						<button type="button" class="go-videos-page__article-thumb" data-go-video-load data-video-id="<?php echo esc_attr( $go_video_item['id'] ?? '' ); ?>" data-video-title="<?php echo esc_attr( $go_video_item['title'] ?? '' ); ?>" data-video-source="<?php esc_attr_e( 'Overdrive', 'go-verge' ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Reproduzir %s', 'go-verge' ), $go_video_item['title'] ?? __( 'vídeo', 'go-verge' ) ) ); ?>">
							<img src="<?php echo esc_url( $go_video_item['thumbnail'] ); ?>" alt="" width="480" height="270" loading="lazy" decoding="async">
							<span class="go-videos-page__video-play" aria-hidden="true">▶</span>
						</button>
						<span class="go-videos-page__article-copy">
							<a href="<?php echo esc_url( $go_video_item['article_url'] ?: $go_video_item['url'] ); ?>"><strong><?php echo esc_html( $go_video_item['title'] ); ?></strong></a>
							<?php if ( ! empty( $go_video_item['post_id'] ) ) : ?><small><?php echo esc_html( get_the_date( '', (int) $go_video_item['post_id'] ) ); ?></small><?php endif; ?>
						</span>
					</article>
				<?php endforeach; ?>
			</div>
		</section>
	<?php endif; ?>
</main>

<?php get_footer(); ?>
