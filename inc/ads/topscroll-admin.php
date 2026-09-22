<?php
/** Top Scroll settings UI; admin-only. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Sanitize the stored setting.
 *
 * @param mixed $value Submitted value.
 * @return array<string,mixed>
 */
function go_verge_adsense_sanitize_topscroll_settings( $value ) {
	$value = is_array( $value ) ? $value : array();

	return array(
		'enabled' => ! empty( $value['enabled'] ),
		'frequency_max' => max( 0, min( 6, absint( $value['frequency_max'] ?? GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT ) ) ),
	);
}

/** Register the setting. */
function go_verge_adsense_register_topscroll_setting() {
	register_setting(
		'go_verge_adsense_topscroll_group',
		GO_VERGE_ADSENSE_TOPSCROLL_OPTION,
		array(
			'type'              => 'array',
			'sanitize_callback' => 'go_verge_adsense_sanitize_topscroll_settings',
			'default'           => array( 'enabled' => true, 'frequency_max' => GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_DEFAULT ),
		)
	);
}
add_action( 'admin_init', 'go_verge_adsense_register_topscroll_setting' );

/** @return string */
function go_verge_adsense_topscroll_option_capability() {
	return 'manage_options';
}

/** Register the Appearance screen. */
function go_verge_adsense_register_topscroll_admin_page() {
	add_theme_page(
		__( 'Top Scroll', 'go-verge' ),
		__( 'Top Scroll', 'go-verge' ),
		go_verge_adsense_topscroll_option_capability(),
		'go-verge-adsense-topscroll',
		'go_verge_adsense_render_topscroll_admin_page'
	);
}
add_action( 'admin_menu', 'go_verge_adsense_register_topscroll_admin_page' );

/** Render the Appearance screen. */
function go_verge_adsense_render_topscroll_admin_page() {
	if ( ! current_user_can( go_verge_adsense_topscroll_option_capability() ) ) {
		return;
	}

	$config = go_verge_adsense_topscroll_config();
	$frequency_constant = 'constant' === $config['frequency_source']
		? 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT'
		: ( 'legacy-constant' === $config['frequency_source'] ? 'GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX' : '' );
	?>
	<div class="wrap">
		<h1><?php esc_html_e( 'Top Scroll', 'go-verge' ); ?></h1>
		<p>
			<?php esc_html_e( 'Unidade AdSense exibida no topo das páginas em telefones, acima do cabeçalho.', 'go-verge' ); ?>
			<?php printf( esc_html__( 'Bloco: %s.', 'go-verge' ), '<code>' . esc_html( (string) $config['slot'] ) . '</code>' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
		</p>
		<p><?php esc_html_e( 'Formato responsivo automático. O preset atual usa até 6 preenchimentos por 24 horas: os 4 primeiros são normais; o 5º exige 3+ páginas na sessão ou 60s ativos; o 6º exige 4+ páginas ou 120s ativos. Não há refresh artificial.', 'go-verge' ); ?></p>
		<?php if ( 'constant' === $config['source'] ) : ?>
			<div class="notice notice-info inline"><p><?php esc_html_e( 'Definido por constante no wp-config.php; a opção abaixo está sendo ignorada.', 'go-verge' ); ?></p></div>
		<?php endif; ?>
		<form method="post" action="options.php">
			<?php settings_fields( 'go_verge_adsense_topscroll_group' ); ?>
			<table class="form-table" role="presentation">
				<tr>
					<th scope="row"><?php esc_html_e( 'Exibição', 'go-verge' ); ?></th>
					<td>
						<label>
							<input type="checkbox" name="<?php echo esc_attr( GO_VERGE_ADSENSE_TOPSCROLL_OPTION ); ?>[enabled]" value="1" <?php checked( ! empty( $config['enabled'] ) ); ?> />
							<?php esc_html_e( 'Exibir o Top Scroll', 'go-verge' ); ?>
						</label>
					</td>
				</tr>
				<tr>
					<th scope="row"><label for="go-topscroll-frequency"><?php esc_html_e( 'Preenchimentos por 24 horas', 'go-verge' ); ?></label></th>
					<td><input id="go-topscroll-frequency" name="<?php echo esc_attr( GO_VERGE_ADSENSE_TOPSCROLL_OPTION ); ?>[frequency_max]" type="number" min="0" max="6" step="1" value="<?php echo esc_attr( (string) $config['frequency_max'] ); ?>" <?php if ( '' !== $frequency_constant ) { echo 'readonly aria-readonly="true"'; } ?> />
					<p class="description"><?php esc_html_e( '0 = sem limite local. De 1 a 6 = cota por navegador, aplicada somente com permissão de armazenamento. Com cota 5 ou 6, as exibições extras obedecem ao filtro de engajamento da sessão. O motor não faz refresh e não reduz a cota por queda de RPM.', 'go-verge' ); ?></p>
					<?php if ( '' !== $frequency_constant ) : ?><p class="description"><?php printf( esc_html__( 'A constante %s no wp-config.php determina o limite atual.', 'go-verge' ), esc_html( $frequency_constant ) ); ?></p><?php endif; ?></td>
				</tr>
			</table>
			<?php submit_button(); ?>
		</form>
	</div>
	<?php
}
