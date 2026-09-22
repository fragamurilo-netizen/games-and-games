<?php
/**
 * Useful 404 with search-aware suggestions.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
$path        = trim( (string) wp_parse_url( $request_uri, PHP_URL_PATH ), '/' );
$tokens      = preg_replace( '/[-_]+/', ' ', $path );
$tokens      = preg_replace( '/\b(?:wp|page|category|tag|amp|html?)\b/i', ' ', (string) $tokens );
$tokens      = sanitize_text_field( trim( preg_replace( '/\s+/', ' ', (string) $tokens ) ) );
$tokens      = function_exists( 'mb_substr' ) ? mb_substr( $tokens, 0, 120, 'UTF-8' ) : substr( $tokens, 0, 120 );

$suggest_ids = array();
if ( strlen( $tokens ) >= 3 ) {
	$suggest_ids = get_posts(
		array(
			'post_type'      => array( 'post', 'games', 'go_entity' ),
			'post_status'    => 'publish',
			'has_password'   => false,
			's'              => $tokens,
			'posts_per_page' => 6,
			'fields'         => 'ids',
			'no_found_rows'  => true,
		)
	);
}

$popular = function_exists( 'go_product_get_popular_ids' )
	? go_product_get_popular_ids( 48, 6, array( 'post' ) )
	: array();

if ( ! $popular ) {
	$popular = get_posts(
		array(
			'post_type'      => 'post',
			'post_status'    => 'publish',
			'has_password'   => false,
			'posts_per_page' => 6,
			'fields'         => 'ids',
			'orderby'        => 'date',
			'order'          => 'DESC',
			'no_found_rows'  => true,
		)
	);
}
?>
<main id="primary" class="go-main od-recovery">
	<section class="go-container od-recovery__intro">
		<div class="od-recovery__message">
			<p class="od-recovery__eyebrow"><?php esc_html_e( 'Erro 404 · Página não encontrada', 'go-verge' ); ?></p>
			<h1><?php esc_html_e( 'Essa página saiu de cena.', 'go-verge' ); ?></h1>
			<p><?php esc_html_e( 'O endereço pode ter mudado ou o link pode estar incompleto. Busque pelo assunto para continuar.', 'go-verge' ); ?></p>
			<form class="od-recovery__search" role="search" action="<?php echo esc_url( home_url( '/' ) ); ?>" method="get">
				<label class="screen-reader-text" for="od-recovery-search"><?php esc_html_e( 'Buscar no Overdrive', 'go-verge' ); ?></label>
				<input id="od-recovery-search" type="search" name="s" placeholder="<?php esc_attr_e( 'Buscar por assunto', 'go-verge' ); ?>" required>
				<button type="submit"><?php esc_html_e( 'Buscar', 'go-verge' ); ?></button>
			</form>
			<a class="od-recovery__home" href="<?php echo esc_url( home_url( '/' ) ); ?>"><?php echo go_verge_icon( 'seta-esquerda' ); ?><?php esc_html_e( 'Voltar ao início', 'go-verge' ); ?></a>
		</div>
		<div class="od-recovery__code" aria-hidden="true">404</div>
	</section>
	<nav class="go-container od-recovery__desks" aria-label="<?php esc_attr_e( 'Explore as editorias', 'go-verge' ); ?>">
		<?php foreach ( array( 'games' => array( 'Games', 'Jogos, lançamentos e guias' ), 'entretenimento' => array( 'Entretenimento', 'Filmes, séries e cultura pop' ), 'tecnologia' => array( 'Tecnologia', 'Produtos, apps e inovação' ), 'ofertas' => array( 'Ofertas', 'Promoções e guias de compra' ) ) as $desk => $item ) : ?>
			<a href="<?php echo esc_url( go_verge_v7_category_url( $desk ) ); ?>"><strong><?php echo esc_html( $item[0] ); ?></strong><span><?php echo esc_html( $item[1] ); ?></span><?php echo go_verge_icon( 'seta-direita' ); ?></a>
		<?php endforeach; ?>
	</nav>

	<?php if ( $suggest_ids ) : ?>
		<section class="go-container go-section go-section--rule">
			<div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e( 'Talvez você procurasse por', 'go-verge' ); ?></h2></div>
			<div class="go-product-card-grid">
				<?php foreach ( $suggest_ids as $id ) : ?>
					<?php $card = go_verge_product_card_data( $id ); ?>
					<?php if ( ! $card ) { continue; } ?>
					<article class="go-product-card">
						<a class="go-product-card__media" href="<?php echo esc_url( $card['url'] ); ?>" tabindex="-1" aria-hidden="true">
							<?php if ( $card['image'] ) : ?>
								<img src="<?php echo esc_url( $card['image'] ); ?>" alt="" width="640" height="360" loading="lazy" decoding="async" fetchpriority="low" data-go-decorative="1">
							<?php endif; ?>
						</a>
						<div><h3><a href="<?php echo esc_url( $card['url'] ); ?>"><?php echo esc_html( $card['title'] ); ?></a></h3></div>
					</article>
				<?php endforeach; ?>
			</div>
		</section>
	<?php endif; ?>

	<?php $popular = array_values( array_diff( (array) $popular, (array) $suggest_ids ) ); ?>
	<?php if ( $popular ) : ?>
		<?php
		$popular_query = new WP_Query(
			array(
				'post_type'      => 'post',
				'post_status'    => 'publish',
				'has_password'   => false,
				'post__in'       => $popular,
				'orderby'        => 'post__in',
				'posts_per_page' => 6,
				'no_found_rows'  => true,
			)
		);
		?>
		<section class="go-container go-section go-section--rule">
			<div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e( 'Para continuar lendo', 'go-verge' ); ?></h2></div>
			<div class="go-grid">
				<?php while ( $popular_query->have_posts() ) : ?>
					<?php $popular_query->the_post(); ?>
					<?php go_verge_story_tile( array( 'id' => get_the_ID(), 'size' => 'standard' ) ); ?>
				<?php endwhile; ?>
			</div>
		</section>
		<?php wp_reset_postdata(); ?>
	<?php endif; ?>
</main>
<?php get_footer(); ?>
