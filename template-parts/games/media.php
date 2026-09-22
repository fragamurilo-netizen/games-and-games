<?php
/** Click-to-load trailer and accessible native-link gallery. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
?>
<section id="midia" class="od-game-section" aria-labelledby="od-game-media-title">
	<header class="od-game-section__head"><h2 id="od-game-media-title"><?php esc_html_e( 'Vídeos e imagens', 'go-verge' ); ?></h2></header>
	<?php if ( $embed ) : ?>
		<div class="od-game-trailer" id="od-game-trailer" data-od-trailer data-od-embed="<?php echo esc_url( $embed ); ?>" data-od-title="<?php echo esc_attr( $game_name . ' — trailer' ); ?>">
			<a href="<?php echo esc_url( $game['trailer_url'] ); ?>" target="_blank" rel="noopener noreferrer" class="od-game-trailer__play" data-od-play aria-label="<?php echo esc_attr( sprintf( __( 'Assistir ao trailer de %s', 'go-verge' ), $game_name ) ); ?>">
				<?php if ( $hero_url ) : ?><img src="<?php echo esc_url( $hero_url ); ?>" alt="" width="1280" height="720" loading="lazy" decoding="async"><?php endif; ?>
				<span class="od-game-trailer__control"><?php echo go_verge_games_icon( 'play' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><span class="od-game-trailer__label"><?php esc_html_e( 'Assistir ao trailer', 'go-verge' ); ?><small><?php esc_html_e( 'Reproduzir vídeo do YouTube', 'go-verge' ); ?></small></span>
			</a>
		</div>
	<?php endif; ?>
	<?php if ( $gallery_items ) : ?>
		<div class="od-game-gallery" data-od-gallery><?php foreach ( $gallery_items as $index => $shot ) : ?><a href="<?php echo esc_url( $shot ); ?>" target="_blank" rel="noopener noreferrer" data-od-gallery-item aria-label="<?php echo esc_attr( sprintf( __( 'Ampliar imagem %1$d de %2$s', 'go-verge' ), $index + 1, $game_name ) ); ?>"><img src="<?php echo esc_url( $shot ); ?>" alt="<?php echo esc_attr( sprintf( __( '%1$s — imagem %2$d', 'go-verge' ), $game_name, $index + 1 ) ); ?>" width="640" height="360" loading="lazy" decoding="async"><span><?php echo go_verge_games_icon( 'expand' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span></a><?php endforeach; ?></div>
		<dialog class="od-game-lightbox" data-od-lightbox aria-label="<?php echo esc_attr( sprintf( __( 'Galeria de %s', 'go-verge' ), $game_name ) ); ?>"><div class="od-game-lightbox__head"><span data-od-gallery-counter aria-live="polite"></span><button type="button" data-od-gallery-close aria-label="<?php esc_attr_e( 'Fechar galeria', 'go-verge' ); ?>"><?php echo go_verge_games_icon( 'close' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></button></div><div class="od-game-lightbox__stage"><img data-od-gallery-image alt=""><p data-od-gallery-error hidden><?php esc_html_e( 'Não foi possível carregar esta imagem.', 'go-verge' ); ?></p></div><div class="od-game-lightbox__controls"><button type="button" data-od-gallery-prev><?php esc_html_e( 'Anterior', 'go-verge' ); ?></button><a data-od-gallery-original target="_blank" rel="noopener noreferrer"><?php esc_html_e( 'Abrir original', 'go-verge' ); ?></a><button type="button" data-od-gallery-next><?php esc_html_e( 'Próxima', 'go-verge' ); ?></button></div></dialog>
	<?php endif; ?>
</section>
