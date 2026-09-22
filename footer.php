<?php
/** Publisher footer: brand, canonical sections, useful links and newsletter. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$od_footer_groups = go_verge_publisher_navigation();
$od_footer_socials = go_verge_publisher_social_links();
$od_footer_pages = go_verge_publisher_page_links( array(
	'sobre-o-overdrive' => 'Sobre', 'contato' => 'Contato', 'seja-colaborador' => 'Seja colaborador',
	'politica-editorial' => 'Política editorial', 'politica-de-reviews' => 'Política de reviews', 'status' => 'Status',
	'especiais' => 'Especiais',
) );
$od_footer_legal = go_verge_publisher_page_links( array(
	'privacidade' => 'Privacidade', 'termos-de-uso' => 'Termos de uso', 'acessibilidade' => 'Acessibilidade',
) );
$od_sitemap = get_page_by_path( 'mapa-do-site' );
$od_sitemap_url = $od_sitemap instanceof WP_Post && 'publish' === get_post_status( $od_sitemap ) ? get_permalink( $od_sitemap ) : home_url( '/mapa-do-site/' );
?>
</div><!-- .go-site -->
<footer class="od-footer" id="colophon">
	<div class="od-footer__wrap">
		<div class="od-footer__brandbar">
			<a class="od-publisher-brand" href="<?php echo esc_url( home_url( '/' ) ); ?>" rel="home" aria-label="<?php esc_attr_e( 'Overdrive — página inicial', 'go-verge' ); ?>">
				<img src="<?php echo esc_attr( go_verge_logo_inline_src( 'logo-dark.svg' ) ); ?>" width="768" height="182" alt="" decoding="async">
			</a>
			<?php if ( $od_footer_socials ) : ?>
				<nav class="od-publisher-socials" aria-label="<?php esc_attr_e( 'Redes sociais do Overdrive', 'go-verge' ); ?>">
					<?php foreach ( $od_footer_socials as $od_social ) : ?>
						<a href="<?php echo esc_url( $od_social['url'] ); ?>" target="<?php echo esc_attr( $od_social['target'] ); ?>"<?php if ( '_blank' === $od_social['target'] ) { echo ' rel="noopener noreferrer"'; } ?>><?php echo esc_html( $od_social['label'] ); ?></a>
					<?php endforeach; ?>
				</nav>
			<?php endif; ?>
		</div>
		<div class="od-footer__grid">
			<?php foreach ( $od_footer_groups as $od_idx => $od_group ) : ?>
				<nav class="od-footer__column" aria-labelledby="od-footer-heading-<?php echo esc_attr( $od_idx ); ?>">
					<h2 id="od-footer-heading-<?php echo esc_attr( $od_idx ); ?>"><a href="<?php echo esc_url( $od_group['url'] ); ?>"><?php echo esc_html( $od_group['label'] ); ?></a></h2>
					<ul>
						<?php foreach ( $od_group['items'] as $od_item ) : ?>
							<li><a href="<?php echo esc_url( $od_item[1] ); ?>"><?php echo esc_html( $od_item[0] ); ?></a></li>
						<?php endforeach; ?>
					</ul>
					<?php if ( $od_idx === count( $od_footer_groups ) - 1 ) : ?>
						<a class="od-footer__compara" href="<?php echo esc_url( go_verge_compara_url() ); ?>">Overdrive Compare<?php echo go_verge_icon( 'seta-direita' ); ?></a>
					<?php endif; ?>
				</nav>
			<?php endforeach; ?>
			<nav class="od-footer__column od-footer__about" aria-labelledby="od-footer-about">
				<h2 id="od-footer-about">Overdrive</h2>
				<?php if ( has_nav_menu( 'footer' ) ) : ?>
					<?php wp_nav_menu( array( 'theme_location' => 'footer', 'container' => false, 'items_wrap' => '<ul>%3$s</ul>', 'depth' => 1, 'fallback_cb' => false ) ); ?>
				<?php else : ?>
					<ul>
						<?php foreach ( $od_footer_pages as $od_link ) : ?>
							<li><a href="<?php echo esc_url( $od_link['url'] ); ?>"><?php echo esc_html( $od_link['label'] ); ?></a></li>
						<?php endforeach; ?>
					</ul>
				<?php endif; ?>
				<a href="<?php echo esc_url( $od_sitemap_url ); ?>"><?php esc_html_e( 'Mapa do site', 'go-verge' ); ?></a>
			</nav>
		</div>
		<div class="od-footer__subscription" id="go-newsletter" tabindex="-1">
			<div class="od-footer__newsletter-intro">
				<h2><?php esc_html_e( 'Newsletter', 'go-verge' ); ?></h2>
				<p><?php esc_html_e( 'Receba as novidades do Overdrive.', 'go-verge' ); ?></p>
				<?php if ( shortcode_exists( 'mc4wp_form' ) ) : ?>
					<a class="od-footer__preferences" href="<?php echo esc_url( home_url( '/preferencias-newsletter/' ) ); ?>"><?php esc_html_e( 'Gerenciar preferências', 'go-verge' ); ?></a>
				<?php endif; ?>
			</div>
			<div class="od-footer__form">
				<?php if ( shortcode_exists( 'mc4wp_form' ) ) : ?>
					<?php
					$od_form = do_shortcode( '[mc4wp_form]' );
					echo str_ireplace(
						array( 'Your email address', 'I have read and agree to the', 'Sign Up Now', 'Subscribe', 'terms &amp; conditions', 'terms & conditions' ),
						array( 'Seu endereço de e-mail', 'Li e concordo com os', 'Assinar', 'Assinar', 'termos e condições', 'termos e condições' ),
						$od_form
					); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- trusted plugin shortcode.
					?>
				<?php else : ?>
					<a class="od-footer__subscribe" href="<?php echo esc_url( home_url( '/preferencias-newsletter/' ) ); ?>"><?php esc_html_e( 'Assinar newsletter', 'go-verge' ); ?><?php echo go_verge_icon( 'seta-direita' ); ?></a>
				<?php endif; ?>
			</div>
		</div>
		<div class="od-footer__bottom">
			<p><?php printf( esc_html__( '© 2024–%s Overdrive. Todos os direitos reservados.', 'go-verge' ), '<span data-go-year>' . esc_html( date_i18n( 'Y' ) ) . '</span>' ); ?></p>
			<?php if ( $od_footer_legal ) : ?>
				<nav aria-label="<?php esc_attr_e( 'Políticas do site', 'go-verge' ); ?>">
					<?php foreach ( $od_footer_legal as $od_link ) : ?>
						<a href="<?php echo esc_url( $od_link['url'] ); ?>"><?php echo esc_html( $od_link['label'] ); ?></a>
					<?php endforeach; ?>
				</nav>
			<?php endif; ?>
		</div>
	</div>
</footer>
<button type="button" class="go-backtop" data-go-backtop aria-label="<?php esc_attr_e( 'Voltar ao início da página', 'go-verge' ); ?>">
	<?php echo go_verge_icon( 'seta-esquerda', 'go-interface-icon go-back-top-icon' ); ?>
</button>

<?php if ( is_front_page() || is_home() ) : ?>
	<?php
	$go_verge_preferred_source_url = add_query_arg(
		'q',
		'gameoverdrive.com.br',
		'https://www.google.com/preferences/source'
	);
	?>
	<aside class="go-preferred-toast" data-go-preferred-toast aria-hidden="true" aria-labelledby="go-preferred-toast-title" aria-describedby="go-preferred-toast-description">
		<button type="button" class="go-preferred-toast__close" data-go-preferred-toast-close aria-label="<?php esc_attr_e( 'Fechar aviso', 'go-verge' ); ?>">
			<?php echo go_verge_icon( 'fechar', '' ); ?>
		</button>

		<div class="go-preferred-toast__icon" aria-hidden="true">
			<svg viewBox="0 0 24 24"><path d="m12 3.4 2.57 5.2 5.74.84-4.15 4.04.98 5.72L12 16.5 6.86 19.2l.98-5.72-4.15-4.04 5.74-.84L12 3.4Z"></path></svg>
		</div>

		<div class="go-preferred-toast__copy">
			<span class="go-preferred-toast__eyebrow"><?php esc_html_e( 'Fontes preferidas', 'go-verge' ); ?></span>
			<strong class="go-preferred-toast__title" id="go-preferred-toast-title"><?php esc_html_e( 'Prefira o Overdrive no Google', 'go-verge' ); ?></strong>
			<p id="go-preferred-toast-description"><?php esc_html_e( 'Dê mais destaque às matérias do Overdrive nas suas experiências de notícias e busca do Google.', 'go-verge' ); ?></p>
		</div>

		<a class="go-preferred-toast__cta" href="<?php echo esc_url( $go_verge_preferred_source_url ); ?>" target="_blank" rel="noopener noreferrer" data-go-preferred-toast-accept>
			<?php esc_html_e( 'Adicionar às fontes preferidas', 'go-verge' ); ?>
		</a>
	</aside>
<?php endif; ?>

<?php wp_footer(); ?>

</body>
</html>
