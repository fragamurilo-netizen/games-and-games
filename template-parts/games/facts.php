<?php
/** Structured game facts and destinations, included from single-games.php. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
?>
<?php if ( $has_facts ) : ?>
<section class="od-game-panel" id="ficha-tecnica" aria-labelledby="od-game-facts-title">
	<header class="od-game-panel__head"><?php echo go_verge_games_icon( 'game' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><h2 id="od-game-facts-title"><?php esc_html_e( 'Ficha técnica', 'go-verge' ); ?></h2></header>
	<?php if ( ! empty( $game['logo_id'] ) ) : ?><div class="od-game-panel__logo"><?php echo wp_get_attachment_image( $game['logo_id'], 'medium', false, array( 'alt' => $game_name, 'loading' => 'lazy' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
	<?php $facts = array_merge( $primary_specs, $detail_specs ); $main_facts = array_slice( $facts, 0, 8, true ); $extra_facts = array_slice( $facts, 8, null, true ); ?>
	<dl class="od-game-facts"><?php foreach ( $main_facts as $label => $value ) : ?><div><dt><?php echo esc_html( $label ); ?></dt><dd><?php echo esc_html( $value ); ?></dd></div><?php endforeach; ?></dl>
	<?php if ( $extra_facts ) : ?><details class="od-game-facts-more"><summary><?php esc_html_e( 'Ver ficha completa', 'go-verge' ); ?><?php echo go_verge_games_icon( 'chevron' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></summary><dl class="od-game-facts"><?php foreach ( $extra_facts as $label => $value ) : ?><div><dt><?php echo esc_html( $label ); ?></dt><dd><?php echo esc_html( $value ); ?></dd></div><?php endforeach; ?></dl></details><?php endif; ?>
</section>
<?php elseif ( ! empty( $game['logo_id'] ) ) : ?><div class="od-game-panel od-game-panel__logo"><?php echo wp_get_attachment_image( $game['logo_id'], 'medium', false, array( 'alt' => $game_name, 'loading' => 'lazy' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
<?php if ( $has_stores ) : ?>
<section class="od-game-panel" aria-labelledby="od-game-stores-title"><header class="od-game-panel__head"><h2 id="od-game-stores-title"><?php echo ! empty( $game['store_links'] ) ? esc_html__( 'Onde jogar', 'go-verge' ) : esc_html__( 'Mais informações', 'go-verge' ); ?></h2></header><div class="od-game-stores">
	<?php foreach ( $game['store_links'] as $store ) : ?>
		<?php if ( ! is_array( $store ) || empty( $store['url'] ) || empty( $store['platform'] ) || ! esc_url( $store['url'] ) ) { continue; } ?>
		<a href="<?php echo esc_url( $store['url'] ); ?>" target="_blank" rel="noopener noreferrer nofollow sponsored"><span><strong><?php echo esc_html( $store['platform'] ); ?></strong><?php if ( ! empty( $store['label'] ) ) : ?><small><?php echo esc_html( $store['label'] ); ?></small><?php endif; ?></span><?php echo go_verge_games_icon( 'external' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a>
	<?php endforeach; ?>
	<?php if ( ! empty( $game['official_site'] ) ) : ?><a href="<?php echo esc_url( $game['official_site'] ); ?>" target="_blank" rel="noopener noreferrer"><span><strong><?php esc_html_e( 'Site oficial', 'go-verge' ); ?></strong></span><?php echo go_verge_games_icon( 'external' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a><?php endif; ?>
</div><?php if ( ! empty( $game['store_links'] ) ) : ?><p class="od-game-panel__note"><?php esc_html_e( 'Preços e disponibilidade devem ser conferidos na loja. Links comerciais podem gerar comissão para o Overdrive.', 'go-verge' ); ?></p><?php endif; ?></section>
<?php endif; ?>
<a class="od-game-library-link" href="<?php echo esc_url( $library_url ); ?>"><span><?php esc_html_e( 'Procurando outro jogo?', 'go-verge' ); ?><strong><?php esc_html_e( 'Explore a biblioteca', 'go-verge' ); ?></strong></span><?php echo go_verge_games_icon( 'arrow' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a>
