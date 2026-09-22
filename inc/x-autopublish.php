<?php
/**
 * Overdrive — publicação automática no X.
 *
 * Módulo isolado: fila assíncrona, prevenção de duplicação, retry,
 * texto por matéria e suporte opcional à imagem destacada.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Default settings.
 *
 * OAuth 2.0 secrets can be defined in wp-config.php:
 * GO_X_OAUTH2_CLIENT_ID, GO_X_OAUTH2_CLIENT_SECRET,
 * GO_X_OAUTH2_ACCESS_TOKEN, GO_X_OAUTH2_REFRESH_TOKEN.
 *
 * OAuth 1.0a remains available for legacy installations through:
 * GO_X_API_KEY, GO_X_API_SECRET, GO_X_ACCESS_TOKEN, GO_X_ACCESS_TOKEN_SECRET.
 */
function go_x_default_settings() {
	return array(
		'enabled'                 => 0,
		'default_auto'            => 1,
		'default_image'           => 1,
		'append_utm'              => 1,
		'utm_source'              => 'x',
		'utm_medium'              => 'social',
		'utm_campaign'            => 'auto_publish',
		'auth_mode'               => 'oauth2',
		'oauth2_client_id'        => '',
		'oauth2_client_secret'    => '',
		'oauth2_access_token'     => '',
		'oauth2_refresh_token'    => '',
		'oauth2_expires_at'       => 0,
		'oauth2_token_endpoint'   => 'https://api.x.com/2/oauth2/token',
		'oauth2_media_endpoint'   => '',
		'api_key'                 => '',
		'api_secret'              => '',
		'access_token'            => '',
		'access_token_secret'     => '',
		'tweet_endpoint'          => 'https://api.x.com/2/tweets',
		'media_endpoint'          => 'https://upload.twitter.com/1.1/media/upload.json',
	);
}

function go_x_get_settings() {
	$saved = get_option( 'go_x_autopublish_settings', array() );
	$saved = is_array( $saved ) ? $saved : array();

	// Preserve legacy installations that predate the auth_mode setting.
	if ( ! isset( $saved['auth_mode'] ) ) {
		$legacy_ready = ! empty( $saved['api_key'] ) && ! empty( $saved['api_secret'] ) && ! empty( $saved['access_token'] ) && ! empty( $saved['access_token_secret'] );
		$saved['auth_mode'] = $legacy_ready ? 'oauth1' : 'oauth2';
	}

	return wp_parse_args( $saved, go_x_default_settings() );
}

function go_x_oauth2_runtime_tokens() {
	$tokens = get_option( 'go_x_oauth2_runtime_tokens', array() );
	return is_array( $tokens ) ? $tokens : array();
}

function go_x_setting( $key, $default = '' ) {
	if ( in_array( $key, array( 'oauth2_access_token', 'oauth2_refresh_token' ), true ) ) {
		$runtime = go_x_oauth2_runtime_tokens();
		if ( ! empty( $runtime[ $key ] ) ) {
			return (string) $runtime[ $key ];
		}
	}

	$constant_map = array(
		'auth_mode'               => 'GO_X_AUTH_MODE',
		'oauth2_client_id'        => 'GO_X_OAUTH2_CLIENT_ID',
		'oauth2_client_secret'    => 'GO_X_OAUTH2_CLIENT_SECRET',
		'oauth2_access_token'     => 'GO_X_OAUTH2_ACCESS_TOKEN',
		'oauth2_refresh_token'    => 'GO_X_OAUTH2_REFRESH_TOKEN',
		'oauth2_token_endpoint'   => 'GO_X_OAUTH2_TOKEN_ENDPOINT',
		'oauth2_media_endpoint'   => 'GO_X_OAUTH2_MEDIA_ENDPOINT',
		'api_key'                 => 'GO_X_API_KEY',
		'api_secret'              => 'GO_X_API_SECRET',
		'access_token'            => 'GO_X_ACCESS_TOKEN',
		'access_token_secret'     => 'GO_X_ACCESS_TOKEN_SECRET',
	);
	if ( isset( $constant_map[ $key ] ) && defined( $constant_map[ $key ] ) ) {
		return (string) constant( $constant_map[ $key ] );
	}
	$settings = go_x_get_settings();
	return isset( $settings[ $key ] ) ? $settings[ $key ] : $default;
}

function go_x_auth_mode() {
	$mode = sanitize_key( (string) go_x_setting( 'auth_mode', 'oauth2' ) );
	return 'oauth1' === $mode ? 'oauth1' : 'oauth2';
}

function go_x_has_credentials() {
	if ( 'oauth1' === go_x_auth_mode() ) {
		return '' !== trim( (string) go_x_setting( 'api_key' ) )
			&& '' !== trim( (string) go_x_setting( 'api_secret' ) )
			&& '' !== trim( (string) go_x_setting( 'access_token' ) )
			&& '' !== trim( (string) go_x_setting( 'access_token_secret' ) );
	}

	return '' !== trim( (string) go_x_setting( 'oauth2_access_token' ) );
}

function go_x_has_oauth2_refresh_credentials() {
	return '' !== trim( (string) go_x_setting( 'oauth2_client_id' ) )
		&& '' !== trim( (string) go_x_setting( 'oauth2_refresh_token' ) );
}

function go_x_sanitize_secret_value( $value ) {
	$value = trim( (string) wp_unslash( $value ) );
	return preg_replace( '/[\\x00-\\x1F\\x7F]/', '', $value );
}

/** Admin settings. */
function go_x_register_settings() {
	register_setting( 'go_x_autopublish', 'go_x_autopublish_settings', array(
		'type'              => 'array',
		'sanitize_callback' => 'go_x_sanitize_settings',
		'default'           => go_x_default_settings(),
	) );
}
add_action( 'admin_init', 'go_x_register_settings' );

function go_x_sanitize_settings( $input ) {
	$current = go_x_get_settings();
	$output  = go_x_default_settings();
	$input   = is_array( $input ) ? $input : array();

	foreach ( array( 'enabled', 'default_auto', 'default_image', 'append_utm' ) as $key ) {
		$output[ $key ] = empty( $input[ $key ] ) ? 0 : 1;
	}

	$output['auth_mode'] = isset( $input['auth_mode'] ) && 'oauth1' === sanitize_key( $input['auth_mode'] ) ? 'oauth1' : 'oauth2';

	foreach ( array( 'utm_source', 'utm_medium', 'utm_campaign' ) as $key ) {
		$output[ $key ] = isset( $input[ $key ] ) ? sanitize_key( $input[ $key ] ) : $output[ $key ];
	}

	foreach ( array( 'tweet_endpoint', 'media_endpoint', 'oauth2_token_endpoint', 'oauth2_media_endpoint' ) as $key ) {
		$value = isset( $input[ $key ] ) ? esc_url_raw( trim( (string) $input[ $key ] ) ) : '';
		if ( 'oauth2_media_endpoint' === $key ) {
			$output[ $key ] = $value;
		} else {
			$output[ $key ] = $value ? $value : ( isset( $current[ $key ] ) ? $current[ $key ] : $output[ $key ] );
		}
	}

	$reset_oauth2_runtime = false;
	foreach ( array( 'oauth2_client_id', 'oauth2_client_secret', 'oauth2_access_token', 'oauth2_refresh_token', 'api_key', 'api_secret', 'access_token', 'access_token_secret' ) as $key ) {
		$value = isset( $input[ $key ] ) ? go_x_sanitize_secret_value( $input[ $key ] ) : '';
		if ( in_array( $key, array( 'oauth2_access_token', 'oauth2_refresh_token' ), true ) && '' !== $value ) {
			$reset_oauth2_runtime = true;
		}
		// Blank fields preserve an existing secret.
		$output[ $key ] = '' !== $value ? $value : ( isset( $current[ $key ] ) ? $current[ $key ] : '' );
	}

	$output['oauth2_expires_at'] = isset( $current['oauth2_expires_at'] ) ? absint( $current['oauth2_expires_at'] ) : 0;
	if ( $reset_oauth2_runtime ) {
		delete_option( 'go_x_oauth2_runtime_tokens' );
	}

	return $output;
}

function go_x_add_settings_page() {
	add_options_page(
		__( 'Publicação no X', 'go-verge' ),
		__( 'Publicação no X', 'go-verge' ),
		'manage_options',
		'go-x-autopublish',
		'go_x_render_settings_page'
	);
}
add_action( 'admin_menu', 'go_x_add_settings_page' );

function go_x_render_settings_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$s    = go_x_get_settings();
	$mode = go_x_auth_mode();
	?>
	<div class="wrap">
		<h1><?php esc_html_e( 'Publicação automática no X', 'go-verge' ); ?></h1>
		<p><?php esc_html_e( 'As matérias entram em uma fila assíncrona. A publicação do WordPress não espera a API do X.', 'go-verge' ); ?></p>
		<form method="post" action="options.php">
			<?php settings_fields( 'go_x_autopublish' ); ?>
			<table class="form-table" role="presentation">
				<tr><th scope="row"><?php esc_html_e( 'Ativar integração', 'go-verge' ); ?></th><td><label><input type="checkbox" name="go_x_autopublish_settings[enabled]" value="1" <?php checked( ! empty( $s['enabled'] ) ); ?>> <?php esc_html_e( 'Permitir envios automáticos', 'go-verge' ); ?></label></td></tr>
				<tr><th scope="row"><label for="go-x-auth-mode"><?php esc_html_e( 'Autenticação', 'go-verge' ); ?></label></th><td>
					<select id="go-x-auth-mode" name="go_x_autopublish_settings[auth_mode]">
						<option value="oauth2" <?php selected( $mode, 'oauth2' ); ?>><?php esc_html_e( 'OAuth 2.0 com renovação automática', 'go-verge' ); ?></option>
						<option value="oauth1" <?php selected( $mode, 'oauth1' ); ?>><?php esc_html_e( 'OAuth 1.0a legado', 'go-verge' ); ?></option>
					</select>
					<p class="description"><?php esc_html_e( 'Use OAuth 2.0 quando o console fornecer Access Token e Refresh Token.', 'go-verge' ); ?></p>
				</td></tr>
				<tr><th scope="row"><?php esc_html_e( 'Padrão por matéria', 'go-verge' ); ?></th><td>
					<label><input type="checkbox" name="go_x_autopublish_settings[default_auto]" value="1" <?php checked( ! empty( $s['default_auto'] ) ); ?>> <?php esc_html_e( 'Publicar automaticamente novos posts', 'go-verge' ); ?></label><br>
					<label><input type="checkbox" name="go_x_autopublish_settings[default_image]" value="1" <?php checked( ! empty( $s['default_image'] ) ); ?>> <?php esc_html_e( 'Tentar anexar a imagem destacada quando houver endpoint de mídia compatível', 'go-verge' ); ?></label>
				</td></tr>
			</table>

			<h2><?php esc_html_e( 'OAuth 2.0', 'go-verge' ); ?></h2>
			<p><?php esc_html_e( 'O Access Token publica. O Refresh Token permite renovar automaticamente um token expirado. Se o provedor rotacionar o Refresh Token, o WordPress salva o novo valor.', 'go-verge' ); ?></p>
			<table class="form-table" role="presentation">
				<?php foreach ( array(
					'oauth2_client_id'     => 'Client ID',
					'oauth2_client_secret' => 'Client Secret',
					'oauth2_access_token'  => 'Access Token',
					'oauth2_refresh_token' => 'Refresh Token',
				) as $key => $label ) : ?>
				<tr><th scope="row"><label for="go-x-<?php echo esc_attr( $key ); ?>"><?php echo esc_html( $label ); ?></label></th><td><input id="go-x-<?php echo esc_attr( $key ); ?>" type="password" autocomplete="new-password" class="regular-text" name="go_x_autopublish_settings[<?php echo esc_attr( $key ); ?>]" value="" placeholder="<?php echo esc_attr( empty( $s[ $key ] ) ? __( 'Não configurado', 'go-verge' ) : __( 'Salvo, deixe em branco para manter', 'go-verge' ) ); ?>"></td></tr>
				<?php endforeach; ?>
				<tr><th scope="row"><label for="go-x-oauth2-token-endpoint"><?php esc_html_e( 'Endpoint de renovação', 'go-verge' ); ?></label></th><td><input id="go-x-oauth2-token-endpoint" type="url" class="large-text" name="go_x_autopublish_settings[oauth2_token_endpoint]" value="<?php echo esc_attr( $s['oauth2_token_endpoint'] ); ?>"><p class="description"><?php esc_html_e( 'Editável porque endpoints e políticas da plataforma podem mudar.', 'go-verge' ); ?></p></td></tr>
				<tr><th scope="row"><label for="go-x-oauth2-media-endpoint"><?php esc_html_e( 'Endpoint de mídia OAuth 2.0', 'go-verge' ); ?></label></th><td><input id="go-x-oauth2-media-endpoint" type="url" class="large-text" name="go_x_autopublish_settings[oauth2_media_endpoint]" value="<?php echo esc_attr( $s['oauth2_media_endpoint'] ); ?>" placeholder="https://..."><p class="description"><?php esc_html_e( 'Opcional. Deixe vazio se sua conta/plano não oferecer upload de mídia compatível; nesse caso o post segue com texto e link.', 'go-verge' ); ?></p></td></tr>
			</table>

			<details>
				<summary><strong><?php esc_html_e( 'OAuth 1.0a legado', 'go-verge' ); ?></strong></summary>
				<table class="form-table" role="presentation">
					<?php foreach ( array(
						'api_key' => 'API Key', 'api_secret' => 'API Key Secret', 'access_token' => 'Access Token', 'access_token_secret' => 'Access Token Secret'
					) as $key => $label ) : ?>
					<tr><th scope="row"><label for="go-x-<?php echo esc_attr( $key ); ?>"><?php echo esc_html( $label ); ?></label></th><td><input id="go-x-<?php echo esc_attr( $key ); ?>" type="password" autocomplete="new-password" class="regular-text" name="go_x_autopublish_settings[<?php echo esc_attr( $key ); ?>]" value="" placeholder="<?php echo esc_attr( empty( $s[ $key ] ) ? __( 'Não configurado', 'go-verge' ) : __( 'Salvo, deixe em branco para manter', 'go-verge' ) ); ?>"></td></tr>
					<?php endforeach; ?>
					<tr><th scope="row"><label for="go-x-media-endpoint"><?php esc_html_e( 'Endpoint de mídia OAuth 1.0a', 'go-verge' ); ?></label></th><td><input id="go-x-media-endpoint" type="url" class="large-text" name="go_x_autopublish_settings[media_endpoint]" value="<?php echo esc_attr( $s['media_endpoint'] ); ?>"></td></tr>
				</table>
			</details>

			<h2><?php esc_html_e( 'Publicação e rastreamento', 'go-verge' ); ?></h2>
			<table class="form-table" role="presentation">
				<tr><th scope="row"><label for="go-x-tweet-endpoint"><?php esc_html_e( 'Endpoint de publicação', 'go-verge' ); ?></label></th><td><input id="go-x-tweet-endpoint" type="url" class="large-text" name="go_x_autopublish_settings[tweet_endpoint]" value="<?php echo esc_attr( $s['tweet_endpoint'] ); ?>"></td></tr>
				<tr><th scope="row"><?php esc_html_e( 'UTM', 'go-verge' ); ?></th><td>
					<label><input type="checkbox" name="go_x_autopublish_settings[append_utm]" value="1" <?php checked( ! empty( $s['append_utm'] ) ); ?>> <?php esc_html_e( 'Adicionar parâmetros de campanha ao link', 'go-verge' ); ?></label>
					<p><input class="regular-text" name="go_x_autopublish_settings[utm_source]" value="<?php echo esc_attr( $s['utm_source'] ); ?>" placeholder="utm_source"> <input class="regular-text" name="go_x_autopublish_settings[utm_medium]" value="<?php echo esc_attr( $s['utm_medium'] ); ?>" placeholder="utm_medium"> <input class="regular-text" name="go_x_autopublish_settings[utm_campaign]" value="<?php echo esc_attr( $s['utm_campaign'] ); ?>" placeholder="utm_campaign"></p>
				</td></tr>
			</table>
			<?php submit_button(); ?>
		</form>
		<p><strong><?php esc_html_e( 'Modo ativo:', 'go-verge' ); ?></strong> <?php echo esc_html( 'oauth1' === $mode ? 'OAuth 1.0a' : 'OAuth 2.0' ); ?></p>
		<p><strong><?php esc_html_e( 'Credenciais para publicar:', 'go-verge' ); ?></strong> <?php echo go_x_has_credentials() ? esc_html__( 'configuradas', 'go-verge' ) : esc_html__( 'incompletas', 'go-verge' ); ?></p>
		<?php if ( 'oauth2' === $mode ) : ?>
			<p><strong><?php esc_html_e( 'Renovação automática:', 'go-verge' ); ?></strong> <?php echo go_x_has_oauth2_refresh_credentials() ? esc_html__( 'pronta', 'go-verge' ) : esc_html__( 'incompleta; preencha Client ID e Refresh Token', 'go-verge' ); ?></p>
		<?php endif; ?>
		<p><?php esc_html_e( 'As credenciais iniciais podem vir do wp-config.php. Após uma renovação, tokens rotacionados são guardados em uma opção não autoloadada para que o fluxo continue funcionando automaticamente.', 'go-verge' ); ?></p>
	</div>
	<?php
}

/** Per-post controls. */
function go_x_add_post_metabox() {
	add_meta_box( 'go-x-publishing', __( 'Publicação no X', 'go-verge' ), 'go_x_render_post_metabox', 'post', 'normal', 'high' );
}
add_action( 'add_meta_boxes_post', 'go_x_add_post_metabox' );

function go_x_post_default( $post_id, $key ) {
	$exists = metadata_exists( 'post', $post_id, $key );
	if ( $exists ) {
		return get_post_meta( $post_id, $key, true );
	}
	$s = go_x_get_settings();
	if ( '_go_x_auto' === $key ) {
		return ! empty( $s['default_auto'] ) ? '1' : '';
	}
	if ( '_go_x_image' === $key ) {
		return ! empty( $s['default_image'] ) ? '1' : '';
	}
	return '';
}

function go_x_render_post_metabox( $post ) {
	wp_nonce_field( 'go_x_save_post_controls', 'go_x_post_nonce' );
	$status = (string) get_post_meta( $post->ID, '_go_x_status', true );
	$error  = (string) get_post_meta( $post->ID, '_go_x_error', true );
	$x_id   = (string) get_post_meta( $post->ID, '_go_x_post_id', true );
	$text   = (string) get_post_meta( $post->ID, '_go_x_text', true );
	$auto   = '1' === (string) go_x_post_default( $post->ID, '_go_x_auto' );
	$image  = '1' === (string) go_x_post_default( $post->ID, '_go_x_image' );
	?>
	<div class="go-x-editor">
		<div class="go-x-editor__status">
			<strong><?php esc_html_e( 'Status', 'go-verge' ); ?>:</strong>
			<span><?php echo esc_html( $status ? $status : __( 'Ainda não enviado', 'go-verge' ) ); ?></span>
			<?php if ( $x_id ) : ?><small><?php echo esc_html( sprintf( __( 'ID no X: %s', 'go-verge' ), $x_id ) ); ?></small><?php endif; ?>
		</div>
		<p><label><input type="checkbox" name="go_x_auto" value="1" <?php checked( $auto ); ?>> <?php esc_html_e( 'Publicar automaticamente quando esta matéria entrar no ar', 'go-verge' ); ?></label></p>
		<p><label><input type="checkbox" name="go_x_image" value="1" <?php checked( $image ); ?>> <?php esc_html_e( 'Tentar usar a imagem destacada', 'go-verge' ); ?></label></p>
		<p><label for="go-x-text"><strong><?php esc_html_e( 'Texto no X', 'go-verge' ); ?></strong></label><br>
		<textarea id="go-x-text" class="widefat" rows="4" name="go_x_text" placeholder="<?php esc_attr_e( 'Vazio: usa o título da matéria + link.', 'go-verge' ); ?>"><?php echo esc_textarea( $text ); ?></textarea>
		<small><?php esc_html_e( 'O link da matéria é acrescentado automaticamente. Atualizar o post não republica sozinho.', 'go-verge' ); ?></small></p>
		<?php if ( $error ) : ?><p class="notice notice-error inline"><strong><?php esc_html_e( 'Último erro:', 'go-verge' ); ?></strong> <?php echo esc_html( $error ); ?></p><?php endif; ?>
		<?php if ( 'publish' === $post->post_status ) : ?>
			<p><button type="submit" class="button button-secondary" name="go_x_manual_action" value="send"><?php echo $x_id ? esc_html__( 'Publicar novamente no X', 'go-verge' ) : esc_html__( 'Publicar agora no X', 'go-verge' ); ?></button></p>
		<?php else : ?>
			<p><button type="button" class="button button-secondary" disabled><?php esc_html_e( 'Publicar no X após publicar a matéria', 'go-verge' ); ?></button></p>
			<small><?php esc_html_e( 'O envio manual fica disponível assim que a matéria estiver publicada no WordPress.', 'go-verge' ); ?></small>
		<?php endif; ?>
	</div>
	<?php
}

function go_x_save_post_controls( $post_id ) {
	if ( ! isset( $_POST['go_x_post_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_x_post_nonce'] ) ), 'go_x_save_post_controls' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}
	update_post_meta( $post_id, '_go_x_auto', empty( $_POST['go_x_auto'] ) ? '' : '1' );
	update_post_meta( $post_id, '_go_x_image', empty( $_POST['go_x_image'] ) ? '' : '1' );
	$text = isset( $_POST['go_x_text'] ) ? sanitize_textarea_field( wp_unslash( $_POST['go_x_text'] ) ) : '';
	update_post_meta( $post_id, '_go_x_text', $text );

	if ( isset( $_POST['go_x_manual_action'] ) && 'send' === sanitize_key( wp_unslash( $_POST['go_x_manual_action'] ) ) && 'publish' === get_post_status( $post_id ) ) {
		go_x_queue_post( $post_id, true, 2 );
	}
}
add_action( 'save_post_post', 'go_x_save_post_controls', 20 );


/**
 * Save per-post X controls from the modern editorial workspace.
 * This endpoint exists because Gutenberg may omit or relocate legacy metaboxes.
 */
function go_x_ajax_save_editor_controls() {
	check_ajax_referer( 'go_x_editor_action', 'nonce' );
	$post_id = isset( $_POST['post_id'] ) ? absint( $_POST['post_id'] ) : 0;
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Você não pode editar esta matéria.', 'go-verge' ) ), 403 );
	}

	$auto  = ! empty( $_POST['auto'] ) ? '1' : '';
	$image = ! empty( $_POST['image'] ) ? '1' : '';
	$text  = isset( $_POST['text'] ) ? sanitize_textarea_field( wp_unslash( $_POST['text'] ) ) : '';

	update_post_meta( $post_id, '_go_x_auto', $auto );
	update_post_meta( $post_id, '_go_x_image', $image );
	update_post_meta( $post_id, '_go_x_text', $text );

	wp_send_json_success( array( 'message' => __( 'Preferências do X salvas.', 'go-verge' ) ) );
}
add_action( 'wp_ajax_go_x_save_editor_controls', 'go_x_ajax_save_editor_controls' );

/** Manual publish action used by the modern workspace. */
function go_x_ajax_manual_send() {
	check_ajax_referer( 'go_x_editor_action', 'nonce' );
	$post_id = isset( $_POST['post_id'] ) ? absint( $_POST['post_id'] ) : 0;
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Você não pode publicar esta matéria no X.', 'go-verge' ) ), 403 );
	}
	if ( 'publish' !== get_post_status( $post_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Publique a matéria no WordPress antes de enviá-la ao X.', 'go-verge' ) ), 409 );
	}

	// Persist the controls shown in the workspace before sending.
	$auto  = ! empty( $_POST['auto'] ) ? '1' : '';
	$image = ! empty( $_POST['image'] ) ? '1' : '';
	$text  = isset( $_POST['text'] ) ? sanitize_textarea_field( wp_unslash( $_POST['text'] ) ) : '';
	update_post_meta( $post_id, '_go_x_auto', $auto );
	update_post_meta( $post_id, '_go_x_image', $image );
	update_post_meta( $post_id, '_go_x_text', $text );

	if ( ! go_x_has_credentials() ) {
		wp_send_json_error( array( 'message' => __( 'As credenciais do X estão incompletas.', 'go-verge' ) ), 400 );
	}

	// Manual action is intentional and therefore may republish an already sent post.
	go_x_process_post( $post_id, true );

	$status    = (string) get_post_meta( $post_id, '_go_x_status', true );
	$error     = (string) get_post_meta( $post_id, '_go_x_error', true );
	$remote_id = (string) get_post_meta( $post_id, '_go_x_post_id', true );

	if ( in_array( $status, array( 'Publicado', 'Publicado sem imagem' ), true ) && $remote_id ) {
		wp_send_json_success( array(
			'message'  => 'Publicado sem imagem' === $status ? __( 'Publicado no X sem imagem.', 'go-verge' ) : __( 'Publicado no X com sucesso.', 'go-verge' ),
			'status'   => $status,
			'error'    => $error,
			'remoteId' => $remote_id,
		) );
	}

	wp_send_json_error( array(
		'message'  => $error ? $error : __( 'O X não confirmou a publicação.', 'go-verge' ),
		'status'   => $status ? $status : __( 'Erro', 'go-verge' ),
		'error'    => $error,
		'remoteId' => $remote_id,
	), 500 );
}
add_action( 'wp_ajax_go_x_manual_send', 'go_x_ajax_manual_send' );

/** Queue only on the first transition to publish. */
function go_x_transition_post_status( $new_status, $old_status, $post ) {
	if ( ! $post instanceof WP_Post || 'post' !== $post->post_type || 'publish' !== $new_status || 'publish' === $old_status ) {
		return;
	}
	$s = go_x_get_settings();
	if ( empty( $s['enabled'] ) ) {
		return;
	}
	$auto = go_x_post_default( $post->ID, '_go_x_auto' );
	if ( '1' !== (string) $auto ) {
		return;
	}
	go_x_queue_post( $post->ID, false, 5 );
}
add_action( 'transition_post_status', 'go_x_transition_post_status', 20, 3 );

function go_x_queue_post( $post_id, $force = false, $delay = 5 ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return false;
	}
	if ( ! $force && get_post_meta( $post_id, '_go_x_post_id', true ) ) {
		return false;
	}
	$args = array( $post_id, (bool) $force );
	if ( ! wp_next_scheduled( 'go_x_publish_post_event', $args ) ) {
		wp_schedule_single_event( time() + max( 1, absint( $delay ) ), 'go_x_publish_post_event', $args );
	}
	update_post_meta( $post_id, '_go_x_status', 'Na fila' );
	return true;
}

add_action( 'go_x_publish_post_event', 'go_x_process_post', 10, 2 );

function go_x_process_post( $post_id, $force = false ) {
	$post = get_post( $post_id );
	if ( ! $post || 'post' !== $post->post_type || 'publish' !== $post->post_status ) {
		return;
	}
	$s = go_x_get_settings();
	if ( empty( $s['enabled'] ) || ! go_x_has_credentials() ) {
		go_x_mark_error( $post_id, __( 'Integração desativada ou credenciais incompletas.', 'go-verge' ), false );
		return;
	}
	if ( ! $force && get_post_meta( $post_id, '_go_x_post_id', true ) ) {
		return;
	}

	update_post_meta( $post_id, '_go_x_status', 'Enviando' );
	update_post_meta( $post_id, '_go_x_error', '' );

	$media_id = '';
	$warning  = '';
	if ( '1' === (string) go_x_post_default( $post_id, '_go_x_image' ) && has_post_thumbnail( $post_id ) ) {
		$media = go_x_upload_featured_image( $post_id );
		if ( is_wp_error( $media ) ) {
			$warning = $media->get_error_message();
		} else {
			$media_id = (string) $media;
		}
	}

	$text    = go_x_build_post_text( $post );
	$payload = array( 'text' => $text );
	if ( $media_id ) {
		$payload['media'] = array( 'media_ids' => array( $media_id ) );
	}
	$response = go_x_api_post_json( (string) $s['tweet_endpoint'], $payload );
	if ( is_wp_error( $response ) ) {
		go_x_mark_error( $post_id, $response->get_error_message(), true );
		return;
	}

	$id = '';
	if ( isset( $response['data']['id'] ) ) {
		$id = sanitize_text_field( (string) $response['data']['id'] );
	}
	if ( ! $id ) {
		go_x_mark_error( $post_id, __( 'A API respondeu sem um ID de publicação.', 'go-verge' ), true );
		return;
	}

	update_post_meta( $post_id, '_go_x_post_id', $id );
	update_post_meta( $post_id, '_go_x_posted_at', current_time( 'mysql' ) );
	update_post_meta( $post_id, '_go_x_text_hash', hash( 'sha256', $text ) );
	update_post_meta( $post_id, '_go_x_status', $warning ? 'Publicado sem imagem' : 'Publicado' );
	update_post_meta( $post_id, '_go_x_error', $warning );
	delete_post_meta( $post_id, '_go_x_attempts' );
	go_x_add_log( $post_id, 'success', $warning ? 'Publicado sem imagem: ' . $warning : 'Publicado com sucesso', $id );
}

function go_x_mark_error( $post_id, $message, $retry ) {
	$message  = sanitize_text_field( (string) $message );
	$attempts = absint( get_post_meta( $post_id, '_go_x_attempts', true ) ) + 1;
	update_post_meta( $post_id, '_go_x_attempts', $attempts );
	update_post_meta( $post_id, '_go_x_status', 'Erro' );
	update_post_meta( $post_id, '_go_x_error', $message );
	go_x_add_log( $post_id, 'error', $message, '' );
	if ( $retry && $attempts < 4 ) {
		$delays = array( 120, 600, 1800 );
		$delay  = isset( $delays[ $attempts - 1 ] ) ? $delays[ $attempts - 1 ] : 1800;
		go_x_queue_post( $post_id, false, $delay );
		update_post_meta( $post_id, '_go_x_status', 'Nova tentativa agendada' );
	}
}

function go_x_add_log( $post_id, $level, $message, $remote_id ) {
	$logs = get_option( 'go_x_autopublish_logs', array() );
	$logs = is_array( $logs ) ? $logs : array();
	array_unshift( $logs, array(
		'time'      => current_time( 'mysql' ),
		'post_id'   => absint( $post_id ),
		'level'     => sanitize_key( $level ),
		'message'   => sanitize_text_field( $message ),
		'remote_id' => sanitize_text_field( $remote_id ),
	) );
	update_option( 'go_x_autopublish_logs', array_slice( $logs, 0, 30 ), false );
}

function go_x_build_post_url( $post ) {
	$url = get_permalink( $post );
	$s   = go_x_get_settings();
	if ( ! empty( $s['append_utm'] ) ) {
		$url = add_query_arg( array_filter( array(
			'utm_source'   => $s['utm_source'],
			'utm_medium'   => $s['utm_medium'],
			'utm_campaign' => $s['utm_campaign'],
		) ), $url );
	}
	return esc_url_raw( $url );
}

function go_x_build_post_text( $post ) {
	$custom = trim( (string) get_post_meta( $post->ID, '_go_x_text', true ) );
	$base   = $custom ? $custom : wp_strip_all_tags( get_the_title( $post ) );
	$url    = go_x_build_post_url( $post );
	$base   = preg_replace( '/\s+/u', ' ', $base );
	$base   = trim( (string) $base );
	// Keep a conservative headroom for the appended URL.
	$max = 235;
	if ( function_exists( 'mb_strlen' ) && mb_strlen( $base, 'UTF-8' ) > $max ) {
		$base = rtrim( mb_substr( $base, 0, $max - 1, 'UTF-8' ) ) . '…';
	} elseif ( strlen( $base ) > $max ) {
		$base = rtrim( substr( $base, 0, $max - 1 ) ) . '…';
	}
	return trim( $base . "\n\n" . $url );
}

/** OAuth 2.0 token lifecycle. */
function go_x_update_saved_setting( $key, $value ) {
	$constant_map = array(
		'oauth2_access_token'  => 'GO_X_OAUTH2_ACCESS_TOKEN',
		'oauth2_refresh_token' => 'GO_X_OAUTH2_REFRESH_TOKEN',
	);

	// Constants are intentionally immutable at runtime.
	if ( isset( $constant_map[ $key ] ) && defined( $constant_map[ $key ] ) ) {
		return false;
	}

	$settings         = go_x_get_settings();
	$settings[ $key ] = $value;
	update_option( 'go_x_autopublish_settings', $settings, false );
	return true;
}

function go_x_oauth2_token_is_expired() {
	$runtime = go_x_oauth2_runtime_tokens();
	if ( isset( $runtime['oauth2_expires_at'] ) ) {
		$expires_at = absint( $runtime['oauth2_expires_at'] );
		return $expires_at > 0 && time() >= $expires_at;
	}
	$settings   = go_x_get_settings();
	$expires_at = isset( $settings['oauth2_expires_at'] ) ? absint( $settings['oauth2_expires_at'] ) : 0;
	return $expires_at > 0 && time() >= $expires_at;
}

function go_x_refresh_oauth2_token() {
	$refresh_token = trim( (string) go_x_setting( 'oauth2_refresh_token' ) );
	$client_id     = trim( (string) go_x_setting( 'oauth2_client_id' ) );
	$client_secret = trim( (string) go_x_setting( 'oauth2_client_secret' ) );
	$endpoint      = esc_url_raw( (string) go_x_setting( 'oauth2_token_endpoint' ) );

	if ( ! $refresh_token || ! $client_id || ! $endpoint ) {
		return new WP_Error( 'go_x_oauth2_refresh_incomplete', __( 'Não foi possível renovar o token: Client ID, Refresh Token ou endpoint ausente.', 'go-verge' ) );
	}

	$body = array(
		'grant_type'    => 'refresh_token',
		'refresh_token' => $refresh_token,
	);

	$headers = array(
		'Accept'       => 'application/json',
		'Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8',
	);

	if ( '' !== $client_secret ) {
		$headers['Authorization'] = 'Basic ' . base64_encode( $client_id . ':' . $client_secret );
	} else {
		$body['client_id'] = $client_id;
	}

	$response = wp_remote_post( $endpoint, array(
		'timeout' => 20,
		'headers' => $headers,
		'body'    => $body,
	) );

	if ( is_wp_error( $response ) ) {
		return $response;
	}

	$code = wp_remote_retrieve_response_code( $response );
	$data = json_decode( wp_remote_retrieve_body( $response ), true );
	if ( $code < 200 || $code >= 300 || empty( $data['access_token'] ) ) {
		$message = '';
		if ( is_array( $data ) ) {
			$message = isset( $data['error_description'] ) ? $data['error_description'] : ( isset( $data['detail'] ) ? $data['detail'] : ( isset( $data['error'] ) ? $data['error'] : '' ) );
		}
		if ( ! $message ) {
			$message = sprintf( __( 'Erro HTTP %d ao renovar o token do X.', 'go-verge' ), $code );
		}
		return new WP_Error( 'go_x_oauth2_refresh_error', sanitize_text_field( (string) $message ), array( 'status' => $code, 'body' => $data ) );
	}

	$runtime = array(
		'oauth2_access_token' => go_x_sanitize_secret_value( $data['access_token'] ),
	);
	if ( ! empty( $data['refresh_token'] ) ) {
		$runtime['oauth2_refresh_token'] = go_x_sanitize_secret_value( $data['refresh_token'] );
	} else {
		$runtime['oauth2_refresh_token'] = $refresh_token;
	}
	$runtime['oauth2_expires_at'] = ! empty( $data['expires_in'] ) ? max( 0, time() + absint( $data['expires_in'] ) - 60 ) : 0;

	// Runtime storage allows Refresh Token rotation even when initial credentials
	// came from wp-config.php constants. This option is not autoloaded.
	update_option( 'go_x_oauth2_runtime_tokens', $runtime, false );

	return (string) $data['access_token'];
}

function go_x_get_oauth2_access_token( $force_refresh = false ) {
	$token = trim( (string) go_x_setting( 'oauth2_access_token' ) );
	if ( ! $force_refresh && $token && ! go_x_oauth2_token_is_expired() ) {
		return $token;
	}

	if ( go_x_has_oauth2_refresh_credentials() ) {
		$refreshed = go_x_refresh_oauth2_token();
		if ( ! is_wp_error( $refreshed ) ) {
			return $refreshed;
		}
		if ( ! $token || $force_refresh ) {
			return $refreshed;
		}
	}

	return $token ? $token : new WP_Error( 'go_x_oauth2_missing_token', __( 'Access Token OAuth 2.0 ausente.', 'go-verge' ) );
}

/** OAuth 1.0a helpers retained for legacy mode. */
function go_x_oauth_encode( $value ) {
	return str_replace( '%7E', '~', rawurlencode( (string) $value ) );
}

function go_x_oauth_header( $method, $url, $body_params = array() ) {
	$oauth = array(
		'oauth_consumer_key'     => (string) go_x_setting( 'api_key' ),
		'oauth_nonce'            => wp_generate_password( 24, false, false ),
		'oauth_signature_method' => 'HMAC-SHA1',
		'oauth_timestamp'        => (string) time(),
		'oauth_token'            => (string) go_x_setting( 'access_token' ),
		'oauth_version'          => '1.0',
	);

	$query = array();
	$parts = wp_parse_url( $url );
	if ( ! empty( $parts['query'] ) ) {
		parse_str( $parts['query'], $query );
	}
	$params = array_merge( $query, is_array( $body_params ) ? $body_params : array(), $oauth );
	ksort( $params );
	$pairs = array();
	foreach ( $params as $key => $value ) {
		if ( is_array( $value ) ) {
			continue;
		}
		$pairs[] = go_x_oauth_encode( $key ) . '=' . go_x_oauth_encode( $value );
	}
	$base_url = ( isset( $parts['scheme'] ) ? $parts['scheme'] : 'https' ) . '://' . ( isset( $parts['host'] ) ? $parts['host'] : '' ) . ( isset( $parts['path'] ) ? $parts['path'] : '' );
	$base     = strtoupper( $method ) . '&' . go_x_oauth_encode( $base_url ) . '&' . go_x_oauth_encode( implode( '&', $pairs ) );
	$key      = go_x_oauth_encode( go_x_setting( 'api_secret' ) ) . '&' . go_x_oauth_encode( go_x_setting( 'access_token_secret' ) );
	$oauth['oauth_signature'] = base64_encode( hash_hmac( 'sha1', $base, $key, true ) );

	$header = array();
	ksort( $oauth );
	foreach ( $oauth as $k => $v ) {
		$header[] = go_x_oauth_encode( $k ) . '="' . go_x_oauth_encode( $v ) . '"';
	}
	return 'OAuth ' . implode( ', ', $header );
}

function go_x_parse_api_error( $code, $body, $fallback ) {
	$message = '';
	if ( is_array( $body ) ) {
		$message = isset( $body['detail'] ) ? $body['detail'] : ( isset( $body['title'] ) ? $body['title'] : ( isset( $body['error_description'] ) ? $body['error_description'] : ( isset( $body['error'] ) ? $body['error'] : '' ) ) );
	}
	return $message ? sanitize_text_field( (string) $message ) : sprintf( $fallback, $code );
}

function go_x_api_post_json_oauth2( $url, $payload, $allow_refresh = true ) {
	$token = go_x_get_oauth2_access_token();
	if ( is_wp_error( $token ) ) {
		return $token;
	}

	$response = wp_remote_post( $url, array(
		'timeout' => 20,
		'headers' => array(
			'Authorization' => 'Bearer ' . $token,
			'Content-Type'  => 'application/json; charset=utf-8',
			'Accept'        => 'application/json',
		),
		'body' => wp_json_encode( $payload ),
	) );
	if ( is_wp_error( $response ) ) {
		return $response;
	}

	$code = wp_remote_retrieve_response_code( $response );
	$body = json_decode( wp_remote_retrieve_body( $response ), true );

	if ( 401 === $code && $allow_refresh && go_x_has_oauth2_refresh_credentials() ) {
		$refreshed = go_x_get_oauth2_access_token( true );
		if ( is_wp_error( $refreshed ) ) {
			return $refreshed;
		}
		return go_x_api_post_json_oauth2( $url, $payload, false );
	}

	if ( $code < 200 || $code >= 300 ) {
		return new WP_Error( 'go_x_api_error', go_x_parse_api_error( $code, $body, __( 'Erro HTTP %d ao publicar no X.', 'go-verge' ) ), array( 'status' => $code, 'body' => $body ) );
	}
	return is_array( $body ) ? $body : array();
}

function go_x_api_post_json_oauth1( $url, $payload ) {
	$response = wp_remote_post( $url, array(
		'timeout' => 20,
		'headers' => array(
			'Authorization' => go_x_oauth_header( 'POST', $url ),
			'Content-Type'  => 'application/json; charset=utf-8',
			'Accept'        => 'application/json',
		),
		'body' => wp_json_encode( $payload ),
	) );
	if ( is_wp_error( $response ) ) {
		return $response;
	}
	$code = wp_remote_retrieve_response_code( $response );
	$body = json_decode( wp_remote_retrieve_body( $response ), true );
	if ( $code < 200 || $code >= 300 ) {
		return new WP_Error( 'go_x_api_error', go_x_parse_api_error( $code, $body, __( 'Erro HTTP %d ao publicar no X.', 'go-verge' ) ), array( 'status' => $code, 'body' => $body ) );
	}
	return is_array( $body ) ? $body : array();
}

function go_x_api_post_json( $url, $payload ) {
	$url = esc_url_raw( $url );
	if ( ! $url ) {
		return new WP_Error( 'go_x_bad_endpoint', __( 'Endpoint de publicação inválido.', 'go-verge' ) );
	}
	return 'oauth1' === go_x_auth_mode() ? go_x_api_post_json_oauth1( $url, $payload ) : go_x_api_post_json_oauth2( $url, $payload, true );
}

function go_x_read_featured_image_data( $post_id ) {
	$attachment_id = get_post_thumbnail_id( $post_id );
	if ( ! $attachment_id ) {
		return new WP_Error( 'go_x_no_media', __( 'Imagem destacada ausente.', 'go-verge' ) );
	}
	$path = get_attached_file( $attachment_id );
	$data = '';
	if ( $path && is_readable( $path ) ) {
		$data = file_get_contents( $path );
	} else {
		$url = wp_get_attachment_url( $attachment_id );
		if ( $url ) {
			$response = wp_remote_get( $url, array( 'timeout' => 20 ) );
			if ( ! is_wp_error( $response ) && 200 === wp_remote_retrieve_response_code( $response ) ) {
				$data = wp_remote_retrieve_body( $response );
			}
		}
	}
	if ( ! $data ) {
		return new WP_Error( 'go_x_media_read', __( 'Não foi possível ler a imagem destacada.', 'go-verge' ) );
	}
	if ( strlen( $data ) > 5 * 1024 * 1024 ) {
		return new WP_Error( 'go_x_media_large', __( 'Imagem destacada grande demais para o envio simples; a publicação seguirá sem imagem.', 'go-verge' ) );
	}
	return array(
		'data'          => $data,
		'attachment_id' => $attachment_id,
		'filename'      => basename( $path ? $path : (string) wp_get_attachment_url( $attachment_id ) ),
		'mime'          => get_post_mime_type( $attachment_id ) ? get_post_mime_type( $attachment_id ) : 'application/octet-stream',
	);
}

function go_x_upload_featured_image_oauth1( $post_id ) {
	$image = go_x_read_featured_image_data( $post_id );
	if ( is_wp_error( $image ) ) {
		return $image;
	}
	$s      = go_x_get_settings();
	$url    = esc_url_raw( $s['media_endpoint'] );
	$params = array( 'media_data' => base64_encode( $image['data'] ) );
	$response = wp_remote_post( $url, array(
		'timeout' => 35,
		'headers' => array(
			'Authorization' => go_x_oauth_header( 'POST', $url, $params ),
			'Accept'        => 'application/json',
		),
		'body' => $params,
	) );
	if ( is_wp_error( $response ) ) {
		return $response;
	}
	$code = wp_remote_retrieve_response_code( $response );
	$body = json_decode( wp_remote_retrieve_body( $response ), true );
	if ( $code < 200 || $code >= 300 ) {
		return new WP_Error( 'go_x_media_api', go_x_parse_api_error( $code, $body, __( 'Erro HTTP %d no envio da imagem.', 'go-verge' ) ) );
	}
	if ( isset( $body['media_id_string'] ) ) {
		return sanitize_text_field( (string) $body['media_id_string'] );
	}
	if ( isset( $body['media_id'] ) ) {
		return sanitize_text_field( (string) $body['media_id'] );
	}
	return new WP_Error( 'go_x_media_no_id', __( 'A API de mídia respondeu sem ID.', 'go-verge' ) );
}

function go_x_build_multipart_body( $fields, $file_field, $filename, $mime, $binary, $boundary ) {
	$eol  = "\r\n";
	$body = '';
	foreach ( $fields as $name => $value ) {
		$body .= '--' . $boundary . $eol;
		$body .= 'Content-Disposition: form-data; name="' . $name . '"' . $eol . $eol;
		$body .= (string) $value . $eol;
	}
	$body .= '--' . $boundary . $eol;
	$body .= 'Content-Disposition: form-data; name="' . $file_field . '"; filename="' . str_replace( '"', '', $filename ) . '"' . $eol;
	$body .= 'Content-Type: ' . $mime . $eol . $eol;
	$body .= $binary . $eol;
	$body .= '--' . $boundary . '--' . $eol;
	return $body;
}

function go_x_upload_featured_image_oauth2( $post_id, $allow_refresh = true ) {
	$endpoint = esc_url_raw( (string) go_x_setting( 'oauth2_media_endpoint' ) );
	if ( ! $endpoint ) {
		return new WP_Error( 'go_x_oauth2_media_unconfigured', __( 'Endpoint de mídia OAuth 2.0 não configurado; a publicação seguirá sem imagem.', 'go-verge' ) );
	}

	$image = go_x_read_featured_image_data( $post_id );
	if ( is_wp_error( $image ) ) {
		return $image;
	}
	$token = go_x_get_oauth2_access_token();
	if ( is_wp_error( $token ) ) {
		return $token;
	}

	$boundary = '----GOX' . wp_generate_password( 24, false, false );
	$body     = go_x_build_multipart_body( array(), 'media', $image['filename'], $image['mime'], $image['data'], $boundary );
	$response = wp_remote_post( $endpoint, array(
		'timeout' => 35,
		'headers' => array(
			'Authorization' => 'Bearer ' . $token,
			'Content-Type'  => 'multipart/form-data; boundary=' . $boundary,
			'Accept'        => 'application/json',
		),
		'body' => $body,
	) );
	if ( is_wp_error( $response ) ) {
		return $response;
	}

	$code = wp_remote_retrieve_response_code( $response );
	$data = json_decode( wp_remote_retrieve_body( $response ), true );
	if ( 401 === $code && $allow_refresh && go_x_has_oauth2_refresh_credentials() ) {
		$refreshed = go_x_get_oauth2_access_token( true );
		if ( is_wp_error( $refreshed ) ) {
			return $refreshed;
		}
		return go_x_upload_featured_image_oauth2( $post_id, false );
	}
	if ( $code < 200 || $code >= 300 ) {
		return new WP_Error( 'go_x_media_api', go_x_parse_api_error( $code, $data, __( 'Erro HTTP %d no envio da imagem.', 'go-verge' ) ) );
	}

	$candidates = array(
		isset( $data['data']['id'] ) ? $data['data']['id'] : '',
		isset( $data['data']['media_id'] ) ? $data['data']['media_id'] : '',
		isset( $data['media_id_string'] ) ? $data['media_id_string'] : '',
		isset( $data['media_id'] ) ? $data['media_id'] : '',
		isset( $data['id'] ) ? $data['id'] : '',
	);
	foreach ( $candidates as $candidate ) {
		if ( '' !== (string) $candidate ) {
			return sanitize_text_field( (string) $candidate );
		}
	}
	return new WP_Error( 'go_x_media_no_id', __( 'A API de mídia respondeu sem ID.', 'go-verge' ) );
}

function go_x_upload_featured_image( $post_id ) {
	return 'oauth1' === go_x_auth_mode() ? go_x_upload_featured_image_oauth1( $post_id ) : go_x_upload_featured_image_oauth2( $post_id, true );
}
