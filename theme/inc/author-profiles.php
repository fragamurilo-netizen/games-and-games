<?php
/**
 * Rich, newsroom-oriented author profiles.
 *
 * WordPress keeps only a name, website and biography by default. This module
 * adds the public information a reader expects from a journalist profile while
 * keeping every field optional and editable by the author or an administrator.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Author field groups used by the profile editor and save routine.
 *
 * @return array<string,array<string,mixed>>
 */
function go_verge_author_profile_fields() {
	$fields = array(
		'identity' => array(
			'title'       => __( 'Identidade editorial', 'go-verge' ),
			'description' => __( 'Informações públicas exibidas na página do autor, nos cards e nas matérias.', 'go-verge' ),
			'fields'      => array(
				'go_author_role' => array(
					'label'       => __( 'Cargo ou função', 'go-verge' ),
					'type'        => 'text',
					'placeholder' => __( 'Ex.: Editor de Games', 'go-verge' ),
					'description' => __( 'Função pública que aparece junto ao nome.', 'go-verge' ),
					'maxlength'   => 100,
				),
				'go_author_pronouns' => array(
					'label'       => __( 'Pronomes', 'go-verge' ),
					'type'        => 'text',
					'placeholder' => __( 'Ex.: ele/dele', 'go-verge' ),
					'description' => __( 'Opcional.', 'go-verge' ),
					'maxlength'   => 40,
				),
				'go_author_short_bio' => array(
					'label'       => __( 'Resumo curto', 'go-verge' ),
					'type'        => 'textarea',
					'placeholder' => __( 'Uma apresentação direta, em até duas frases.', 'go-verge' ),
					'description' => __( 'Usado nos cards. A biografia completa continua no campo “Informações biográficas” do WordPress.', 'go-verge' ),
					'maxlength'   => 280,
					'wide'        => true,
				),
				'go_author_location' => array(
					'label'       => __( 'Localização', 'go-verge' ),
					'type'        => 'text',
					'placeholder' => __( 'Ex.: Porto Alegre, RS', 'go-verge' ),
					'description' => __( 'Cidade, estado ou região; não informe endereço.', 'go-verge' ),
					'maxlength'   => 100,
				),
				'go_author_since' => array(
					'label'       => __( 'Atua no jornalismo desde', 'go-verge' ),
					'type'        => 'number',
					'placeholder' => '2018',
					'description' => __( 'Ano com quatro dígitos.', 'go-verge' ),
					'min'         => 1900,
					'max'         => (int) gmdate( 'Y' ) + 1,
				),
				'go_author_languages' => array(
					'label'       => __( 'Idiomas', 'go-verge' ),
					'type'        => 'text',
					'placeholder' => __( 'Ex.: Português, inglês e espanhol', 'go-verge' ),
					'description' => __( 'Idiomas usados na apuração ou produção.', 'go-verge' ),
					'maxlength'   => 160,
				),
			),
		),
		'expertise' => array(
			'title'       => __( 'Experiência e cobertura', 'go-verge' ),
			'description' => __( 'Ajuda o leitor a entender a especialidade e a autoridade editorial do autor.', 'go-verge' ),
			'fields'      => array(
				'go_author_coverage' => array(
					'label'       => __( 'Editorias e temas cobertos', 'go-verge' ),
					'type'        => 'text',
					'placeholder' => __( 'Ex.: Games, streaming, séries turcas', 'go-verge' ),
					'description' => __( 'Separe os temas por vírgulas.', 'go-verge' ),
					'maxlength'   => 300,
					'wide'        => true,
				),
				'go_author_expertise' => array(
					'label'       => __( 'Especialidades', 'go-verge' ),
					'type'        => 'text',
					'placeholder' => __( 'Ex.: SEO, Google Discover, PlayStation', 'go-verge' ),
					'description' => __( 'Separe as especialidades por vírgulas.', 'go-verge' ),
					'maxlength'   => 300,
					'wide'        => true,
				),
				'go_author_credentials' => array(
					'label'       => __( 'Formação, experiência e credenciais', 'go-verge' ),
					'type'        => 'textarea',
					'placeholder' => __( 'Formação, veículos, certificações, projetos e experiência relevante.', 'go-verge' ),
					'description' => __( 'Texto público. Seja específico e verificável.', 'go-verge' ),
					'maxlength'   => 1200,
					'wide'        => true,
				),
				'go_author_transparency' => array(
					'label'       => __( 'Transparência e vínculos', 'go-verge' ),
					'type'        => 'textarea',
					'placeholder' => __( 'Informe vínculos, projetos ou potenciais conflitos relevantes para a cobertura.', 'go-verge' ),
					'description' => __( 'Opcional. Só aparece publicamente quando preenchido.', 'go-verge' ),
					'maxlength'   => 800,
					'wide'        => true,
				),
			),
		),
		'contact' => array(
			'title'       => __( 'Contato e perfis públicos', 'go-verge' ),
			'description' => __( 'Use URLs completas. Campos vazios não aparecem no site nem nos dados estruturados.', 'go-verge' ),
			'fields'      => array(
				'go_author_public_email' => array(
					'label'       => __( 'E-mail público', 'go-verge' ),
					'type'        => 'email',
					'placeholder' => 'nome@exemplo.com',
					'description' => __( 'Pode ser diferente do e-mail privado da conta.', 'go-verge' ),
					'maxlength'   => 190,
				),
				'go_author_portfolio_url' => array(
					'label'       => __( 'Portfólio', 'go-verge' ),
					'type'        => 'url',
					'placeholder' => 'https://',
					'description' => __( 'Site profissional ou página de portfólio.', 'go-verge' ),
					'maxlength'   => 300,
				),
				'twitter' => array(
					'label' => __( 'Perfil no X', 'go-verge' ), 'type' => 'url', 'placeholder' => 'https://x.com/', 'maxlength' => 300,
				),
				'instagram' => array(
					'label' => 'Instagram', 'type' => 'url', 'placeholder' => 'https://instagram.com/', 'maxlength' => 300,
				),
				'linkedin' => array(
					'label' => 'LinkedIn', 'type' => 'url', 'placeholder' => 'https://linkedin.com/in/', 'maxlength' => 300,
				),
				'bluesky' => array(
					'label' => 'Bluesky', 'type' => 'url', 'placeholder' => 'https://bsky.app/profile/', 'maxlength' => 300,
				),
				'threads' => array(
					'label' => 'Threads', 'type' => 'url', 'placeholder' => 'https://threads.net/@', 'maxlength' => 300,
				),
				'mastodon' => array(
					'label' => 'Mastodon', 'type' => 'url', 'placeholder' => 'https://', 'maxlength' => 300,
				),
				'youtube' => array(
					'label' => 'YouTube', 'type' => 'url', 'placeholder' => 'https://youtube.com/@', 'maxlength' => 300,
				),
				'tiktok' => array(
					'label' => 'TikTok', 'type' => 'url', 'placeholder' => 'https://tiktok.com/@', 'maxlength' => 300,
				),
				'facebook' => array(
					'label' => 'Facebook', 'type' => 'url', 'placeholder' => 'https://facebook.com/', 'maxlength' => 300,
				),
			),
		),
	);

	return (array) apply_filters( 'go_verge_author_profile_fields', $fields );
}

/** Return all flat author field definitions. */
function go_verge_author_profile_flat_fields() {
	$flat = array();
	foreach ( go_verge_author_profile_fields() as $group ) {
		foreach ( (array) ( $group['fields'] ?? array() ) as $key => $field ) {
			$flat[ $key ] = $field;
		}
	}
	return $flat;
}

/** Hosts that can represent each centralized social network. */
function go_verge_author_profile_network_hosts() {
	return array(
		'twitter'   => array( 'x.com', 'twitter.com' ),
		'instagram' => array( 'instagram.com' ),
		'linkedin'  => array( 'linkedin.com' ),
		'bluesky'   => array( 'bsky.app' ),
		'threads'   => array( 'threads.net' ),
		'youtube'   => array( 'youtube.com' ),
		'tiktok'    => array( 'tiktok.com' ),
		'facebook'  => array( 'facebook.com', 'fb.com' ),
	);
}

/** Return a social-network key, or an empty string for a generic URL field. */
function go_verge_author_profile_url_network( $key ) {
	$key = sanitize_key( $key );
	if ( 'mastodon' === $key || isset( go_verge_author_profile_network_hosts()[ $key ] ) ) {
		return $key;
	}
	return '';
}

/**
 * Expand an imported username into that network's canonical profile URL.
 *
 * Old Gamxo fields accepted a bare username. Passing one to esc_url_raw()
 * produced values such as http://GregoryFelipeEF, which are URLs but are not
 * identities. Keep accepting those old values while making their meaning
 * explicit. Values that already contain a scheme are validated later.
 */
function go_verge_author_profile_handle_url( $value, $network ) {
	$value   = trim( (string) $value );
	$network = sanitize_key( $network );
	if ( '' === $value || preg_match( '#^https?://#i', $value ) ) {
		return $value;
	}
	if ( 0 === strpos( $value, '//' ) || false !== strpos( $value, '://' ) ) {
		return '';
	}

	/* A recognizable network URL without its scheme is unambiguous. */
	foreach ( (array) ( go_verge_author_profile_network_hosts()[ $network ] ?? array() ) as $base_host ) {
		if ( preg_match( '#^(?:[a-z0-9-]+\.)*' . preg_quote( $base_host, '#' ) . '(?:/|$)#i', $value ) ) {
			return 'https://' . $value;
		}
	}

	if ( 'twitter' === $network && preg_match( '/^@?([A-Za-z0-9_]{1,15})$/', $value, $match ) ) {
		return 'https://x.com/' . $match[1];
	}
	if ( 'instagram' === $network && preg_match( '/^@?([A-Za-z0-9._]{1,30})$/', $value, $match ) ) {
		return 'https://www.instagram.com/' . $match[1] . '/';
	}
	if ( 'linkedin' === $network && preg_match( '#^(?:in/)?([A-Za-z0-9-]{3,100})/?$#', $value, $match ) ) {
		return 'https://www.linkedin.com/in/' . $match[1] . '/';
	}
	if ( 'bluesky' === $network && preg_match( '/^@?([A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,63})$/', $value, $match ) ) {
		return 'https://bsky.app/profile/' . $match[1];
	}
	if ( 'threads' === $network && preg_match( '/^@?([A-Za-z0-9._]{1,30})$/', $value, $match ) ) {
		return 'https://www.threads.net/@' . $match[1];
	}
	if ( 'youtube' === $network && preg_match( '/^@?([A-Za-z0-9._-]{3,30})$/', $value, $match ) ) {
		return 'https://www.youtube.com/@' . $match[1];
	}
	if ( 'tiktok' === $network && preg_match( '/^@?([A-Za-z0-9._]{2,24})$/', $value, $match ) ) {
		return 'https://www.tiktok.com/@' . $match[1];
	}
	if ( 'facebook' === $network && preg_match( '/^@?([A-Za-z0-9.]{3,100})$/', $value, $match ) ) {
		return 'https://www.facebook.com/' . $match[1] . '/';
	}
	if ( 'mastodon' === $network && preg_match( '/^@?([A-Za-z0-9_.-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,63})$/', $value, $match ) ) {
		return 'https://' . $match[2] . '/@' . $match[1];
	}

	return '';
}

/**
 * Check that a URL host is a public, syntactically valid DNS name or IP.
 *
 * This deliberately does not perform a DNS request during page rendering:
 * transient resolver failures must not make author identities disappear.
 */
function go_verge_author_url_has_public_host( $url ) {
	$parts = wp_parse_url( (string) $url );
	if ( ! is_array( $parts ) || empty( $parts['host'] ) || empty( $parts['scheme'] ) ) {
		return false;
	}
	if ( ! in_array( strtolower( (string) $parts['scheme'] ), array( 'http', 'https' ), true ) ) {
		return false;
	}
	if ( ! empty( $parts['user'] ) || ! empty( $parts['pass'] ) ) {
		return false;
	}

	$host = strtolower( rtrim( trim( (string) $parts['host'], '[]' ), '.' ) );
	if ( '' === $host ) {
		return false;
	}

	if ( filter_var( $host, FILTER_VALIDATE_IP ) ) {
		return false !== filter_var( $host, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE );
	}

	/* Do not let abbreviated, numeric or malformed IP forms masquerade as DNS. */
	if ( false !== strpos( $host, ':' ) || preg_match( '/^[0-9.]+$/', $host ) ) {
		return false;
	}
	if ( strlen( $host ) > 253 || false === strpos( $host, '.' ) || ! filter_var( $host, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME ) ) {
		return false;
	}

	$labels = explode( '.', $host );
	$tld    = (string) end( $labels );
	if ( ! preg_match( '/^(?:[a-z]{2,63}|xn--[a-z0-9-]{2,59})$/', $tld ) ) {
		return false;
	}

	foreach ( array( 'localhost', 'local', 'internal', 'home', 'lan', 'test', 'invalid', 'example', 'onion' ) as $suffix ) {
		if ( $host === $suffix || substr( $host, -strlen( '.' . $suffix ) ) === '.' . $suffix ) {
			return false;
		}
	}

	return true;
}

/**
 * Normalize one public identity URL and reject non-public or mislabeled hosts.
 */
function go_verge_author_public_profile_url( $value, $network = '' ) {
	$network = sanitize_key( $network );
	$value   = go_verge_author_profile_handle_url( $value, $network );
	if ( ! preg_match( '#^https?://#i', $value ) ) {
		return '';
	}

	$url = esc_url_raw( $value, array( 'http', 'https' ) );
	if ( '' === $url ) {
		return '';
	}
	$url = preg_replace( '#^http://#i', 'https://', $url );
	if ( 'twitter' === $network ) {
		$url = preg_replace( '#^https://(?:www\.)?twitter\.com(?=/|$)#i', 'https://x.com', $url );
	}
	$url = esc_url_raw( $url, array( 'https' ) );
	if ( '' === $url || ! go_verge_author_url_has_public_host( $url ) ) {
		return '';
	}

	$network_hosts = go_verge_author_profile_network_hosts();
	$is_social     = 'mastodon' === $network || isset( $network_hosts[ $network ] );
	if ( isset( $network_hosts[ $network ] ) ) {
		$host    = preg_replace( '/^www\./', '', strtolower( (string) wp_parse_url( $url, PHP_URL_HOST ) ) );
		$matches = false;
		foreach ( $network_hosts[ $network ] as $base_host ) {
			if ( $host === $base_host || substr( $host, -strlen( '.' . $base_host ) ) === '.' . $base_host ) {
				$matches = true;
				break;
			}
		}
		if ( ! $matches ) {
			return '';
		}
	}
	if ( $is_social && '' === trim( (string) wp_parse_url( $url, PHP_URL_PATH ), '/' ) ) {
		return '';
	}

	return $url;
}

/** Read a profile value, including legacy Gamxo metadata when appropriate. */
function go_verge_author_profile_value( $author_id, $key ) {
	$author_id = absint( $author_id );
	$key       = sanitize_key( $key );
	$value     = trim( (string) get_user_meta( $author_id, $key, true ) );
	if ( '' !== $value ) {
		if ( 'go_author_portfolio_url' === $key || go_verge_author_profile_url_network( $key ) ) {
			return go_verge_author_public_profile_url( $value, go_verge_author_profile_url_network( $key ) );
		}
		return $value;
	}

	$legacy = array(
		'go_author_role' => 'gamxo_author_designation',
		'twitter'        => 'gamxo_twitter',
		'linkedin'       => 'gamxo_linkedin',
		'facebook'       => 'gamxo_facebook',
	);
	if ( isset( $legacy[ $key ] ) ) {
		$value = trim( (string) get_user_meta( $author_id, $legacy[ $key ], true ) );
		return go_verge_author_profile_url_network( $key )
			? go_verge_author_public_profile_url( $value, go_verge_author_profile_url_network( $key ) )
			: $value;
	}

	return '';
}

/** Render the expanded profile editor. */
function go_verge_author_profile_editor( $user ) {
	if ( ! ( $user instanceof WP_User ) || ! current_user_can( 'edit_user', $user->ID ) ) {
		return;
	}
	?>
	<div class="go-author-profile-editor">
		<div class="go-author-profile-editor__intro">
			<h2><?php esc_html_e( 'Perfil público do autor', 'go-verge' ); ?></h2>
			<p><?php esc_html_e( 'Complete apenas as informações que devem aparecer publicamente. A foto do autor pode ser alterada no bloco acima.', 'go-verge' ); ?></p>
		</div>
		<?php foreach ( go_verge_author_profile_fields() as $group_key => $group ) : ?>
			<section class="go-author-profile-group" aria-labelledby="go-author-profile-<?php echo esc_attr( $group_key ); ?>">
				<header class="go-author-profile-group__head">
					<h3 id="go-author-profile-<?php echo esc_attr( $group_key ); ?>"><?php echo esc_html( $group['title'] ); ?></h3>
					<?php if ( ! empty( $group['description'] ) ) : ?><p><?php echo esc_html( $group['description'] ); ?></p><?php endif; ?>
				</header>
				<div class="go-author-profile-fields">
					<?php foreach ( (array) $group['fields'] as $key => $field ) : ?>
						<?php
						$value       = go_verge_author_profile_value( $user->ID, $key );
						$field_id    = 'go-author-' . sanitize_html_class( $key );
						$description = isset( $field['description'] ) ? (string) $field['description'] : '';
						$classes     = 'go-author-profile-field' . ( ! empty( $field['wide'] ) ? ' go-author-profile-field--wide' : '' );
						?>
						<div class="<?php echo esc_attr( $classes ); ?>">
							<label for="<?php echo esc_attr( $field_id ); ?>"><?php echo esc_html( $field['label'] ); ?></label>
							<?php if ( 'textarea' === $field['type'] ) : ?>
								<textarea id="<?php echo esc_attr( $field_id ); ?>" name="go_author_profile[<?php echo esc_attr( $key ); ?>]" rows="4" maxlength="<?php echo esc_attr( $field['maxlength'] ); ?>" placeholder="<?php echo esc_attr( $field['placeholder'] ?? '' ); ?>"<?php echo $description ? ' aria-describedby="' . esc_attr( $field_id . '-description' ) . '"' : ''; ?>><?php echo esc_textarea( $value ); ?></textarea>
							<?php else : ?>
								<input id="<?php echo esc_attr( $field_id ); ?>" name="go_author_profile[<?php echo esc_attr( $key ); ?>]" type="<?php echo esc_attr( $field['type'] ); ?>" value="<?php echo esc_attr( $value ); ?>" placeholder="<?php echo esc_attr( $field['placeholder'] ?? '' ); ?>" maxlength="<?php echo esc_attr( $field['maxlength'] ?? 300 ); ?>"<?php echo isset( $field['min'] ) ? ' min="' . esc_attr( $field['min'] ) . '"' : ''; ?><?php echo isset( $field['max'] ) ? ' max="' . esc_attr( $field['max'] ) . '"' : ''; ?><?php echo $description ? ' aria-describedby="' . esc_attr( $field_id . '-description' ) . '"' : ''; ?>>
							<?php endif; ?>
							<?php if ( $description ) : ?><p class="description" id="<?php echo esc_attr( $field_id . '-description' ); ?>"><?php echo esc_html( $description ); ?></p><?php endif; ?>
						</div>
					<?php endforeach; ?>
				</div>
			</section>
		<?php endforeach; ?>
		<?php wp_nonce_field( 'go_verge_save_author_profile_' . $user->ID, 'go_verge_author_profile_nonce' ); ?>
	</div>
	<?php
}
add_action( 'show_user_profile', 'go_verge_author_profile_editor', 15 );
add_action( 'edit_user_profile', 'go_verge_author_profile_editor', 15 );

/** Sanitize one profile field according to its declared type. */
function go_verge_author_profile_sanitize( $value, $field, $key = '' ) {
	$type  = isset( $field['type'] ) ? $field['type'] : 'text';
	$value = is_scalar( $value ) ? wp_unslash( (string) $value ) : '';

	if ( 'url' === $type ) {
		return go_verge_author_public_profile_url( $value, go_verge_author_profile_url_network( $key ) );
	}
	if ( 'email' === $type ) {
		return sanitize_email( $value );
	}
	if ( 'number' === $type ) {
		$number = absint( $value );
		$min    = isset( $field['min'] ) ? absint( $field['min'] ) : 0;
		$max    = isset( $field['max'] ) ? absint( $field['max'] ) : PHP_INT_MAX;
		return $number >= $min && $number <= $max ? (string) $number : '';
	}
	if ( 'textarea' === $type ) {
		$value = sanitize_textarea_field( $value );
	} else {
		$value = sanitize_text_field( $value );
	}

	$maxlength = isset( $field['maxlength'] ) ? absint( $field['maxlength'] ) : 0;
	if ( $maxlength && function_exists( 'mb_substr' ) ) {
		$value = mb_substr( $value, 0, $maxlength, 'UTF-8' );
	}
	return $value;
}

/** Save all optional author fields without touching the private account email. */
function go_verge_save_author_profile( $user_id ) {
	$user_id = absint( $user_id );
	if ( ! $user_id || ! current_user_can( 'edit_user', $user_id ) ) {
		return;
	}

	$nonce = isset( $_POST['go_verge_author_profile_nonce'] ) ? sanitize_text_field( wp_unslash( $_POST['go_verge_author_profile_nonce'] ) ) : '';
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_author_profile_' . $user_id ) ) {
		return;
	}

	$payload = isset( $_POST['go_author_profile'] ) && is_array( $_POST['go_author_profile'] )
		? $_POST['go_author_profile']
		: array();
	$values  = array();

	foreach ( go_verge_author_profile_flat_fields() as $key => $field ) {
		$value          = go_verge_author_profile_sanitize( $payload[ $key ] ?? '', $field, $key );
		$values[ $key ] = $value;
		if ( '' === $value ) {
			delete_user_meta( $user_id, $key );
		} else {
			update_user_meta( $user_id, $key, $value );
		}
	}

	/* Keep old templates and imported content compatible while the canonical
	 * profile fields use stable, theme-independent social keys. */
	$legacy_map = array(
		'go_author_role' => 'gamxo_author_designation',
		'twitter'        => 'gamxo_twitter',
		'linkedin'       => 'gamxo_linkedin',
		'facebook'       => 'gamxo_facebook',
	);
	foreach ( $legacy_map as $canonical => $legacy ) {
		if ( empty( $values[ $canonical ] ) ) {
			delete_user_meta( $user_id, $legacy );
		} else {
			update_user_meta( $user_id, $legacy, $values[ $canonical ] );
		}
	}

	/* Author archives and article bylines are full-page cached. A profile save is
	 * rare, so clearing those caches is preferable to showing stale credentials. */
	clean_user_cache( $user_id );
	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'personal_options_update', 'go_verge_save_author_profile', 20 );
add_action( 'edit_user_profile_update', 'go_verge_save_author_profile', 20 );

/** Remove the small English legacy panel now replaced by the newsroom editor. */
function go_verge_remove_legacy_author_profile_panel() {
	if ( function_exists( 'gamxo_user_social_profile_fields' ) ) {
		remove_action( 'show_user_profile', 'gamxo_user_social_profile_fields' );
		remove_action( 'edit_user_profile', 'gamxo_user_social_profile_fields' );
	}
	if ( function_exists( 'gamxo_extra_profile_fields' ) ) {
		remove_action( 'personal_options_update', 'gamxo_extra_profile_fields' );
		remove_action( 'edit_user_profile_update', 'gamxo_extra_profile_fields' );
	}
}
add_action( 'admin_init', 'go_verge_remove_legacy_author_profile_panel', 1 );

/** Load the profile-editor presentation only where it is used. */
function go_verge_author_profile_admin_assets( $hook_suffix ) {
	if ( ! in_array( $hook_suffix, array( 'profile.php', 'user-edit.php' ), true ) ) {
		return;
	}
	wp_enqueue_style(
		'go-verge-author-profile-fields',
		GO_VERGE_URI . '/assets/css/author-profile-fields.css',
		array(),
		go_verge_asset_version( '/assets/css/author-profile-fields.css' )
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_author_profile_admin_assets', 30 );

/** Public role with a fallback for profiles created in the previous theme. */
function go_verge_author_role( $author_id ) {
	return go_verge_author_profile_value( absint( $author_id ), 'go_author_role' );
}

/** One-time compatibility copy of existing roles; never infer or rewrite identity. */
function go_verge_author_apply_cofounder_roles_v1() {
	/* A prior version marker already means this migration ran. A theme release
	 * must not overwrite a later profile edit or revisit biographies. */
	if ( '' !== trim( (string) get_option( 'go_author_cofounder_roles_v1', '' ) ) ) {
		return;
	}
	$users   = get_users();
	$changed = false;
	foreach ( (array) $users as $user ) {
		if ( ! ( $user instanceof WP_User ) ) { continue; }
		$slug = sanitize_title( (string) $user->user_nicename );
		$name = remove_accents( strtolower( trim( (string) $user->display_name ) ) );
		if ( ! in_array( $slug, array( 'fraga-murilo', 'gregory-felipe' ), true )
			&& ! in_array( $name, array( 'murilo rodrigues', 'gregory felipe' ), true ) ) {
			continue;
		}
		$role   = trim( (string) get_user_meta( $user->ID, 'go_author_role', true ) );
		$legacy = trim( (string) get_user_meta( $user->ID, 'gamxo_author_designation', true ) );
		if ( '' === $role && '' !== $legacy ) {
			update_user_meta( $user->ID, 'go_author_role', $legacy );
		} elseif ( '' === $legacy && '' !== $role ) {
			update_user_meta( $user->ID, 'gamxo_author_designation', $role );
		} else {
			continue;
		}
		$changed = true;
		clean_user_cache( $user->ID );
	}
	update_option( 'go_author_cofounder_roles_v1', 'complete', false );
	if ( $changed && function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'admin_init', 'go_verge_author_apply_cofounder_roles_v1', 121 );
add_action( 'after_switch_theme', 'go_verge_author_apply_cofounder_roles_v1', 121 );

/** Short public biography, falling back to the full WordPress biography. */
function go_verge_author_short_bio( $author_id ) {
	$short = go_verge_author_profile_value( $author_id, 'go_author_short_bio' );
	if ( '' === $short ) {
		$short = trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', absint( $author_id ) ) ) );
	}
	return function_exists( 'go_verge_rebrand_copy' ) ? go_verge_rebrand_copy( $short ) : $short;
}

/** Convert a comma/semicolon/newline list into safe, unique public labels. */
function go_verge_author_list_meta( $author_id, $key, $limit = 12 ) {
	$value = go_verge_author_profile_value( $author_id, $key );
	if ( '' === $value ) {
		return array();
	}
	$parts = preg_split( '/[,;\n]+/u', $value );
	$parts = array_map(
		static function ( $part ) {
			return trim( sanitize_text_field( $part ) );
		},
		(array) $parts
	);
	$parts = array_values( array_unique( array_filter( $parts ) ) );
	return array_slice( $parts, 0, max( 1, absint( $limit ) ) );
}

/** Resolved social links for the public author page. */
function go_verge_author_social_links( $author_id ) {
	$networks = array(
		'twitter'   => 'Siga no X',
		'instagram' => 'Instagram',
		'linkedin'  => 'LinkedIn',
		'bluesky'   => 'Bluesky',
		'threads'   => 'Threads',
		'mastodon'  => 'Mastodon',
		'youtube'   => 'YouTube',
		'tiktok'    => 'TikTok',
		'facebook'  => 'Facebook',
	);
	$links = array();
	foreach ( $networks as $key => $label ) {
		$url = go_verge_author_public_profile_url( go_verge_author_profile_value( $author_id, $key ), $key );
		if ( $url ) {
			$links[ $key ] = array( 'label' => $label, 'url' => $url );
		}
	}
	return $links;
}

/** Add every declared external identity to the canonical Person sameAs list. */
function go_verge_author_profile_same_as( $urls, $author_id ) {
	foreach ( go_verge_author_social_links( $author_id ) as $network ) {
		$urls[] = $network['url'];
	}
	$portfolio = go_verge_author_profile_value( $author_id, 'go_author_portfolio_url' );
	if ( $portfolio ) {
		$urls[] = $portfolio;
	}
	$home_host = preg_replace( '/^www\./', '', strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) ) );
	$clean     = array();
	foreach ( (array) $urls as $url ) {
		$url  = go_verge_author_public_profile_url( $url );
		$host = preg_replace( '/^www\./', '', strtolower( (string) wp_parse_url( $url, PHP_URL_HOST ) ) );
		if ( $url && $host && $host !== $home_host ) {
			$clean[] = $url;
		}
	}
	return array_values( array_unique( $clean ) );
}
add_filter( 'go_verge_author_same_as_urls', 'go_verge_author_profile_same_as', 20, 2 );

/** Public directory: only people with published articles; shared by view and schema. */
function go_verge_public_author_directory() {
	static $users = null;
	if ( null === $users ) {
		$users = get_users( array( 'has_published_posts' => array( 'post' ), 'orderby' => 'display_name', 'order' => 'ASC', 'fields' => 'all' ) );
	}
	return $users;
}

/** Describe the same linked authors visible on the directory, without private user data. */
function go_verge_author_directory_schema( $graph ) {
	if ( ! is_page( 'autores' ) || ! is_array( $graph ) || post_password_required() ) { return $graph; }
	$url = get_permalink( get_queried_object_id() );
	$list_id = $url . '#authors';
	$items = array();
	foreach ( go_verge_public_author_directory() as $user ) {
		$profile = get_author_posts_url( (int) $user->ID );
		$items[] = array( '@type' => 'ListItem', 'position' => count( $items ) + 1, 'item' => array( '@type' => 'Person', '@id' => $profile . '#person', 'name' => $user->display_name, 'url' => $profile ) );
	}
	if ( ! $items ) { return $graph; }
	foreach ( $graph as &$node ) {
		if ( ! is_array( $node ) ) { continue; }
		$is_page = array_intersect( (array) ( $node['@type'] ?? array() ), array( 'WebPage', 'CollectionPage' ) );
		if ( ( $node['@id'] ?? '' ) === $url . '#webpage' || ( $is_page && ( $node['url'] ?? '' ) === $url ) ) {
			$node['@type'] = 'CollectionPage';
			$node['mainEntity'] = array( '@id' => $list_id );
		}
	}
	unset( $node );
	$list = array( '@type' => 'ItemList', '@id' => $list_id, 'name' => __( 'Autores', 'go-verge' ), 'numberOfItems' => count( $items ), 'itemListElement' => $items );
	foreach ( $graph as $key => $node ) { if ( is_array( $node ) && ( $node['@id'] ?? '' ) === $list_id ) { $graph[ $key ] = $list; return $graph; } }
	$graph[] = $list;
	return $graph;
}
add_filter( 'rank_math/json_ld', 'go_verge_author_directory_schema', 85 );
add_filter( 'go_verge_native_schema_graph', 'go_verge_author_directory_schema', 20 );
