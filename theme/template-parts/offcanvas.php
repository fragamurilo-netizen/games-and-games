<?php
/** Editorial drawer, using the same destinations as the footer. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$od_groups  = go_verge_publisher_navigation();
$od_current = untrailingslashit( (string) go_verge_publisher_current_url() );
$od_context = go_verge_header_context_identity();
$od_context_url = untrailingslashit( (string) $od_context['url'] );
$od_socials = go_verge_publisher_social_links();
$od_latest = go_verge_latest_url();
?>
<div class="od-menu-backdrop" id="go-offcanvas-backdrop" aria-hidden="true"></div>
<aside class="od-menu" id="go-offcanvas" aria-hidden="true" inert role="dialog" aria-modal="true" aria-label="<?php esc_attr_e( 'Menu do Overdrive', 'go-verge' ); ?>">
	<div class="od-menu__head">
		<a class="od-publisher-brand" href="<?php echo esc_url( home_url( '/' ) ); ?>" rel="home" aria-label="<?php esc_attr_e( 'Overdrive — página inicial', 'go-verge' ); ?>">
			<img src="<?php echo esc_attr( go_verge_logo_inline_src( 'logo-dark.svg' ) ); ?>" width="768" height="182" alt="" decoding="async">
		</a>
		<button class="od-menu__close" type="button" data-go-close="offcanvas" aria-label="<?php esc_attr_e( 'Fechar menu', 'go-verge' ); ?>"><?php echo go_verge_icon( 'fechar' ); ?></button>
	</div>
	<div class="od-menu__body">
		<form class="od-menu__search" role="search" action="<?php echo esc_url( home_url( '/' ) ); ?>" method="get">
			<label class="screen-reader-text" for="od-menu-search"><?php esc_html_e( 'Buscar no Overdrive', 'go-verge' ); ?></label>
			<input id="od-menu-search" name="s" type="search" placeholder="<?php esc_attr_e( 'Buscar no Overdrive', 'go-verge' ); ?>" value="<?php echo esc_attr( get_search_query() ); ?>">
			<button type="submit" aria-label="<?php esc_attr_e( 'Pesquisar', 'go-verge' ); ?>"><?php echo go_verge_icon( 'busca' ); ?></button>
		</form>
		<nav class="od-menu__nav" aria-label="<?php esc_attr_e( 'Editorias', 'go-verge' ); ?>">
			<div class="od-menu__quick">
				<a href="<?php echo esc_url( home_url( '/' ) ); ?>"<?php if ( is_front_page() ) { echo ' aria-current="page"'; } ?>><?php esc_html_e( 'Início', 'go-verge' ); ?></a>
				<a href="<?php echo esc_url( $od_latest ); ?>"<?php if ( $od_current === untrailingslashit( $od_latest ) ) { echo ' aria-current="page"'; } ?>><?php esc_html_e( 'Últimas', 'go-verge' ); ?></a>
				<?php if ( function_exists( 'go_verge_specials_gallery_url' ) && go_verge_specials_gallery_url() ) : ?><a href="<?php echo esc_url( go_verge_specials_gallery_url() ); ?>"<?php if ( go_verge_specials_gallery_is_current() ) { echo ' aria-current="page"'; } ?>><?php esc_html_e( 'Especiais', 'go-verge' ); ?></a><?php endif; ?>
			</div>
			<ul class="od-menu__groups">
				<?php foreach ( $od_groups as $od_idx => $od_group ) :
					/* In the Games drawer, Guides and Reviews are real hubs, not AJAX filter destinations. */
					if ( 'games' === ( $od_group['key'] ?? '' ) && ! empty( $od_group['items'] ) ) {
						foreach ( $od_group['items'] as &$od_nav_item ) {
							if ( 'format' !== ( $od_nav_item[2] ?? '' ) ) { continue; }
							if ( 'Guias' === ( $od_nav_item[0] ?? '' ) ) {
								$od_nav_item[1] = home_url( '/games/dicas-e-guias/' );
							} elseif ( 'Reviews' === ( $od_nav_item[0] ?? '' ) ) {
								$od_nav_item[1] = home_url( '/games/reviews/' );
							}
						}
						unset( $od_nav_item );
					}
					$od_urls = array_map( 'untrailingslashit', array_merge( array( $od_group['url'] ), array_column( $od_group['items'], 1 ) ) );
					$od_open = in_array( $od_current, $od_urls, true ) || ( $od_context_url && in_array( $od_context_url, $od_urls, true ) );
					$od_id = 'od-menu-section-' . $od_idx;
					?>
					<li class="od-menu__group">
						<div class="od-menu__row">
							<a class="od-menu__section" href="<?php echo esc_url( $od_group['url'] ); ?>"<?php if ( $od_current === untrailingslashit( $od_group['url'] ) ) { echo ' aria-current="page"'; } ?>><?php echo esc_html( $od_group['label'] ); ?></a>
							<?php if ( $od_group['items'] ) : ?>
								<button class="od-menu__expand" type="button" data-go-offcanvas-submenu-toggle aria-expanded="<?php echo $od_open ? 'true' : 'false'; ?>" aria-controls="<?php echo esc_attr( $od_id ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Tipos de matéria, seções e plataformas de %s', 'go-verge' ), $od_group['label'] ) ); ?>"><span class="od-menu__expand-mark" aria-hidden="true"></span></button>
							<?php endif; ?>
						</div>
						<?php if ( $od_group['items'] ) : ?>
							<ul class="od-menu__sub" id="<?php echo esc_attr( $od_id ); ?>"<?php if ( ! $od_open ) { echo ' hidden'; } ?>>
								<?php $od_previous_kind = ''; foreach ( $od_group['items'] as $od_item ) :
									$od_kind = $od_item[2] ?? 'topic';
									if ( $od_kind !== $od_previous_kind ) : ?>
										<li class="od-menu__sub-label"><?php echo esc_html( array( 'format' => 'Tipos de matéria', 'topic' => 'Seções', 'platform' => 'Plataformas' )[ $od_kind ] ?? 'Assuntos' ); ?></li>
									<?php endif; $od_previous_kind = $od_kind; ?>
									<li><a href="<?php echo esc_url( $od_item[1] ); ?>"<?php if ( $od_current === untrailingslashit( $od_item[1] ) ) { echo ' aria-current="page"'; } ?>><?php echo esc_html( $od_item[0] ); ?></a></li>
								<?php endforeach; ?>
							</ul>
						<?php endif; ?>
					</li>
				<?php endforeach; ?>
			</ul>
		</nav>
		<a class="od-menu__compara" href="<?php echo esc_url( go_verge_compara_url() ); ?>"><span>Overdrive <strong>Compare</strong></span><?php echo go_verge_icon( 'seta-direita' ); ?></a>
		<nav class="od-menu__reader" aria-label="<?php esc_attr_e( 'Seus atalhos', 'go-verge' ); ?>">
			<a href="<?php echo esc_url( home_url( '/para-voce/' ) ); ?>"><?php esc_html_e( 'Para você', 'go-verge' ); ?></a>
			<a href="<?php echo esc_url( home_url( '/salvos/' ) ); ?>"><?php echo go_verge_icon( 'salvar' ); ?><?php esc_html_e( 'Salvos', 'go-verge' ); ?></a>
		</nav>
		<div class="od-menu__end">
			<?php if ( $od_socials ) : ?>
				<nav class="od-publisher-socials" aria-label="<?php esc_attr_e( 'Redes sociais do Overdrive', 'go-verge' ); ?>">
					<?php foreach ( $od_socials as $od_social ) : ?>
						<a href="<?php echo esc_url( $od_social['url'] ); ?>" target="<?php echo esc_attr( $od_social['target'] ); ?>"<?php if ( '_blank' === $od_social['target'] ) { echo ' rel="noopener noreferrer"'; } ?>><?php echo esc_html( $od_social['label'] ); ?></a>
					<?php endforeach; ?>
				</nav>
			<?php endif; ?>
			<nav class="od-menu__institutional" aria-label="<?php esc_attr_e( 'Sobre o Overdrive', 'go-verge' ); ?>">
				<?php foreach ( go_verge_publisher_page_links( array( 'sobre-o-overdrive' => 'Sobre', 'contato' => 'Contato' ) ) as $od_link ) : ?>
					<a href="<?php echo esc_url( $od_link['url'] ); ?>"><?php echo esc_html( $od_link['label'] ); ?></a>
				<?php endforeach; ?>
				<a href="#go-newsletter" data-go-menu-anchor><?php esc_html_e( 'Newsletter', 'go-verge' ); ?></a>
			</nav>
		</div>
	</div>
</aside>
