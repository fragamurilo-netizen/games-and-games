<?php
/**
 * Shared institutional/trust page shell.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

$current_id = get_the_ID();
$current_slug = get_post_field( 'post_name', $current_id );

$institutional_map = array(
	'sobre-o-overdrive'      => __( 'Sobre', 'go-verge' ),
	'contato'                 => __( 'Contato', 'go-verge' ),
	/*
	 * O mídia kit é alcançável por aqui — a navegação institucional, que é onde
	 * um anunciante já está quando procura com quem falar — e deliberadamente
	 * não pelo rodapé, que é território do leitor.
	 */
	'parcerias'               => __( 'Parcerias', 'go-verge' ),
	'midia-kit'               => __( 'Mídia kit', 'go-verge' ),
	'seja-colaborador'       => __( 'Seja colaborador', 'go-verge' ),
	'politica-editorial'     => __( 'Política editorial', 'go-verge' ),
	'politica-de-reviews'     => __( 'Política de reviews', 'go-verge' ),
	'acessibilidade'          => __( 'Acessibilidade', 'go-verge' ),
	'privacidade'             => __( 'Política de Privacidade', 'go-verge' ),
	'termos-de-uso'           => __( 'Termos de uso', 'go-verge' ),
);

$links = array();
foreach ( $institutional_map as $slug => $label ) {
	$page = get_page_by_path( $slug, OBJECT, 'page' );
	if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
		$links[] = array(
			'id'    => $page->ID,
			'url'   => get_permalink( $page ),
			'label' => $label,
		);
	}
}

$deck = trim( (string) get_post_meta( $current_id, '_go_post_subtitle', true ) );
if ( ! $deck && has_excerpt( $current_id ) ) {
	$deck = trim( (string) get_the_excerpt( $current_id ) );
}
$document = go_verge_trust_document( apply_filters( 'the_content', get_the_content() ) );
$deck_prefix = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $deck ) ) );
$deck_prefix = preg_replace( '/(?:\.{3}|…|\[&hellip;\]|\[…\])\s*$/u', '', $deck_prefix );
$body_prefix = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( $document['html'] ) ) );
if ( strlen( $deck_prefix ) >= 50 && 0 === strpos( $body_prefix, $deck_prefix ) ) { $deck = ''; }

$published = (int) get_post_time( 'U', true, $current_id );
$modified  = (int) get_post_modified_time( 'U', true, $current_id );
$show_updated = $modified > $published + HOUR_IN_SECONDS;
?>
<main id="primary" class="go-main go-trust-page go-trust-page--<?php echo esc_attr( sanitize_html_class( $current_slug ) ); ?>">
	<div class="go-container go-trust-page__masthead"><a href="<?php echo esc_url( home_url( '/' ) ); ?>">Overdrive</a><span><?php esc_html_e( 'Institucional', 'go-verge' ); ?></span></div>
	<div class="go-container go-trust-page__layout">
		<article class="go-trust-page__article">
			<header class="go-trust-page__header">
				<h1 class="go-trust-page__title"><?php the_title(); ?></h1>
				<?php if ( $deck ) : ?>
					<p class="go-trust-page__deck"><?php echo esc_html( $deck ); ?></p>
				<?php endif; ?>
				<?php if ( $show_updated ) : ?>
					<p class="go-trust-page__updated">
						<time datetime="<?php echo esc_attr( get_post_modified_time( DATE_W3C, true, $current_id ) ); ?>">
							<?php echo esc_html( sprintf( __( 'Atualizado em %s', 'go-verge' ), get_the_modified_date( 'j \d\e F \d\e Y', $current_id ) ) ); ?>
						</time>
					</p>
				<?php endif; ?>
			</header>

			<?php if ( has_post_thumbnail( $current_id ) ) : ?>
				<figure class="go-trust-page__hero">
					<?php echo get_the_post_thumbnail( $current_id, 'go_hero', array( 'loading' => 'eager', 'fetchpriority' => 'high', 'decoding' => 'async', 'alt' => '' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				</figure>
			<?php endif; ?>

			<?php if ( count( $document['sections'] ) > 1 ) : ?>
				<details class="go-trust-page__index">
					<summary><?php esc_html_e( 'Nesta página', 'go-verge' ); ?><span><?php echo esc_html( count( $document['sections'] ) ); ?> <?php esc_html_e( 'seções', 'go-verge' ); ?></span></summary>
					<nav aria-label="<?php esc_attr_e( 'Seções desta página', 'go-verge' ); ?>"><ol><?php foreach ( $document['sections'] as $section ) : ?><li><a href="#<?php echo esc_attr( $section['id'] ); ?>"><?php echo esc_html( $section['label'] ); ?></a></li><?php endforeach; ?></ol></nav>
				</details>
			<?php endif; ?>
			<div class="go-trust-page__content">
				<?php echo $document['html']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- the_content pipeline, unchanged document with heading IDs. ?>
			</div>
		</article>

		<?php if ( count( $links ) > 1 ) : ?>
			<aside class="go-trust-page__aside">
				<h2 class="go-trust-page__nav-title" id="go-institutional-nav-title"><?php esc_html_e( 'Conheça o Overdrive', 'go-verge' ); ?></h2>
				<nav class="go-trust-page__nav" aria-labelledby="go-institutional-nav-title">
					<?php foreach ( $links as $item ) : ?>
						<a href="<?php echo esc_url( $item['url'] ); ?>"<?php echo (int) $item['id'] === (int) $current_id ? ' aria-current="page"' : ''; ?>>
							<span><?php echo esc_html( $item['label'] ); ?></span>
							<svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path fill="currentColor" d="m9 18 6-6-6-6 1.4-1.4L17.8 12l-7.4 7.4L9 18Z"/></svg>
						</a>
					<?php endforeach; ?>
				</nav>
			</aside>
		<?php endif; ?>
	</div>
</main>
