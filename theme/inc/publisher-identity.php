<?php
/**
 * Canonical publisher identity for Google News/Search and social profiles.
 *
 * Google News publication pages are generated automatically. The theme cannot
 * create one on demand, but it can make every first-party identity signal agree:
 * site name, publisher Organization, favicon/logo, public contact and sameAs
 * profiles. This module is deliberately independent from a header/footer menu,
 * because a navigation change must not erase the publisher entity from schema.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_PUBLISHER_IDENTITY_OPTION' ) ) {
	define( 'GO_VERGE_PUBLISHER_IDENTITY_OPTION', 'go_verge_publisher_identity' );
}

/**
 * Networks that may be declared as canonical publisher profiles.
 *
 * @return array<string,string>
 */
function go_verge_publisher_networks() {
	return array(
		'x'         => 'Perfil do Overdrive no X',
		'instagram' => 'Instagram',
		'facebook'  => 'Facebook',
		'youtube'   => 'YouTube',
		'tiktok'    => 'TikTok',
		'threads'   => 'Threads',
		'linkedin'  => 'LinkedIn',
	);
}

/**
 * Defaults are limited to identity data already public in this theme/site.
 * Unknown social handles are intentionally not guessed.
 *
 * @return array<string,string>
 */
function go_verge_publisher_identity_defaults() {
	return array(
		'x'             => 'https://x.com/gameoverdrivebr',
		'instagram'     => '',
		'facebook'      => '',
		'youtube'       => '',
		'tiktok'        => '',
		'threads'       => '',
		'linkedin'      => '',
		'contact_email' => 'contato@gameoverdrive.com.br',
		'legal_name'    => '',
		'founding_date' => '',
	);
}

/**
 * Read the publisher identity with stable defaults.
 *
 * @return array<string,string>
 */
function go_verge_publisher_identity() {
	$saved = get_option( GO_VERGE_PUBLISHER_IDENTITY_OPTION, array() );
	$saved = is_array( $saved ) ? $saved : array();
	$value = wp_parse_args( $saved, go_verge_publisher_identity_defaults() );

	return (array) apply_filters( 'go_verge_publisher_identity', $value );
}

/**
 * Sanitize a public identity URL. Only http(s) profile URLs belong here.
 *
 * @param mixed $value Raw value.
 * @return string
 */
function go_verge_publisher_identity_sanitize_url( $value ) {
	$url = esc_url_raw( trim( (string) $value ), array( 'http', 'https' ) );
	if ( ! $url ) {
		return '';
	}
	$parts = wp_parse_url( $url );
	if ( empty( $parts['host'] ) ) {
		return '';
	}
	return $url;
}

/**
 * YYYY-MM-DD only; schema.org accepts ISO dates and this avoids ambiguous dates.
 *
 * @param mixed $value Raw value.
 * @return string
 */
function go_verge_publisher_identity_sanitize_date( $value ) {
	$value = trim( (string) $value );
	if ( ! preg_match( '/^(\d{4})-(\d{2})-(\d{2})$/', $value, $match ) ) {
		return '';
	}
	return checkdate( (int) $match[2], (int) $match[3], (int) $match[1] ) ? $value : '';
}

/**
 * Sanitize the whole General Settings payload.
 *
 * @param mixed $value Raw option.
 * @return array<string,string>
 */
function go_verge_publisher_identity_sanitize( $value ) {
	$value = is_array( $value ) ? $value : array();
	$out   = array();

	foreach ( go_verge_publisher_networks() as $key => $label ) {
		$out[ $key ] = go_verge_publisher_identity_sanitize_url( $value[ $key ] ?? '' );
	}

	$out['contact_email'] = sanitize_email( (string) ( $value['contact_email'] ?? '' ) );
	$out['legal_name']    = sanitize_text_field( (string) ( $value['legal_name'] ?? '' ) );
	$out['founding_date'] = go_verge_publisher_identity_sanitize_date( $value['founding_date'] ?? '' );

	return $out;
}

/**
 * Canonical URL for one network.
 *
 * @param string $network Network key.
 * @return string
 */
function go_verge_publisher_social_url( $network ) {
	$network  = sanitize_key( $network );
	$identity = go_verge_publisher_identity();
	$url      = isset( $identity[ $network ] ) ? go_verge_publisher_identity_sanitize_url( $identity[ $network ] ) : '';

	/* Keep the already-public X destination working even before settings are saved. */
	if ( 'x' === $network && '' === $url ) {
		$url = 'https://x.com/gameoverdrivebr';
	}

	return $url;
}

/**
 * Reject feed/share/intent URLs when harvesting a social navigation menu.
 *
 * @param string $url URL.
 * @return bool
 */
function go_verge_publisher_identity_is_profile_url( $url ) {
	$url   = go_verge_publisher_identity_sanitize_url( $url );
	$parts = $url ? wp_parse_url( $url ) : false;
	if ( ! $url || ! is_array( $parts ) ) {
		return false;
	}

	$path  = strtolower( (string) ( $parts['path'] ?? '' ) );
	$query = strtolower( (string) ( $parts['query'] ?? '' ) );
	$bad   = array( '/intent/', '/sharer', '/sharearticle', '/sharing/', '/feeds/', '/feed/' );
	foreach ( $bad as $needle ) {
		if ( false !== strpos( $path, $needle ) ) {
			return false;
		}
	}
	if ( false !== strpos( $query, 'url=' ) && ( false !== strpos( $query, 'text=' ) || false !== strpos( $path, 'share' ) ) ) {
		return false;
	}

	return true;
}

/**
 * Complete sameAs list: explicit publisher settings first, then social menu/theme
 * settings as a compatibility fallback. A menu edit therefore cannot erase the
 * canonical profiles, while existing configured networks continue to work.
 *
 * @return string[]
 */
function go_verge_publisher_same_as_urls() {
	$urls     = array();
	$identity = go_verge_publisher_identity();

	foreach ( go_verge_publisher_networks() as $key => $label ) {
		$url = isset( $identity[ $key ] ) ? go_verge_publisher_identity_sanitize_url( $identity[ $key ] ) : '';
		if ( $url && go_verge_publisher_identity_is_profile_url( $url ) ) {
			$urls[] = $url;
		}
	}

	if ( function_exists( 'go_verge_get_social_links' ) ) {
		foreach ( go_verge_get_social_links() as $link ) {
			$label = strtolower( trim( (string) ( $link['label'] ?? '' ) ) );
			$url   = isset( $link['url'] ) ? (string) $link['url'] : '';
			if ( false !== strpos( $label, 'rss' ) || ! go_verge_publisher_identity_is_profile_url( $url ) ) {
				continue;
			}
			$urls[] = go_verge_publisher_identity_sanitize_url( $url );
		}
	}

	$urls = array_values( array_unique( array_filter( $urls ) ) );
	return array_values( (array) apply_filters( 'go_verge_publisher_same_as_urls', $urls ) );
}

/** Public editorial contact email, if explicitly available. */
function go_verge_publisher_contact_email() {
	$identity = go_verge_publisher_identity();
	return sanitize_email( (string) ( $identity['contact_email'] ?? '' ) );
}

/** Optional legal name. */
function go_verge_publisher_legal_name() {
	$identity = go_verge_publisher_identity();
	return sanitize_text_field( (string) ( $identity['legal_name'] ?? '' ) );
}

/** Optional ISO founding date. */
function go_verge_publisher_founding_date() {
	$identity = go_verge_publisher_identity();
	return go_verge_publisher_identity_sanitize_date( $identity['founding_date'] ?? '' );
}

/**
 * Register canonical publisher fields in Settings > General.
 */
function go_verge_publisher_identity_register_settings() {
	register_setting(
		'general',
		GO_VERGE_PUBLISHER_IDENTITY_OPTION,
		array(
			'type'              => 'array',
			'sanitize_callback' => 'go_verge_publisher_identity_sanitize',
			'default'           => go_verge_publisher_identity_defaults(),
		)
	);

	add_settings_section(
		'go_verge_publisher_identity_section',
		__( 'Identidade do publisher no Google', 'go-verge' ),
		'go_verge_publisher_identity_section_copy',
		'general'
	);

	foreach ( go_verge_publisher_networks() as $key => $label ) {
		add_settings_field(
			'go_verge_publisher_' . $key,
			esc_html( $label ),
			'go_verge_publisher_identity_url_field',
			'general',
			'go_verge_publisher_identity_section',
			array( 'key' => $key, 'label' => $label )
		);
	}

	add_settings_field(
		'go_verge_publisher_contact_email',
		__( 'E-mail editorial público', 'go-verge' ),
		'go_verge_publisher_identity_text_field',
		'general',
		'go_verge_publisher_identity_section',
		array( 'key' => 'contact_email', 'type' => 'email', 'description' => __( 'Usado como contato público do NewsMediaOrganization. Não usa automaticamente o e-mail privado do administrador.', 'go-verge' ) )
	);
	add_settings_field(
		'go_verge_publisher_legal_name',
		__( 'Razão social (opcional)', 'go-verge' ),
		'go_verge_publisher_identity_text_field',
		'general',
		'go_verge_publisher_identity_section',
		array( 'key' => 'legal_name', 'type' => 'text', 'description' => __( 'Preencha apenas se houver um nome jurídico público que represente o publisher.', 'go-verge' ) )
	);
	add_settings_field(
		'go_verge_publisher_founding_date',
		__( 'Data de fundação (opcional)', 'go-verge' ),
		'go_verge_publisher_identity_text_field',
		'general',
		'go_verge_publisher_identity_section',
		array( 'key' => 'founding_date', 'type' => 'date', 'description' => __( 'Formato ISO YYYY-MM-DD. Deixe vazio se a data pública não estiver definida.', 'go-verge' ) )
	);
}
add_action( 'admin_init', 'go_verge_publisher_identity_register_settings' );

/** Settings section explanatory text. */
function go_verge_publisher_identity_section_copy() {
	echo '<span id="go_verge_publisher_identity_section"></span>';
	echo '<p>' . esc_html__( 'Esses dados alimentam a entidade NewsMediaOrganization e permanecem estáveis mesmo se o menu social mudar. O Google News gera as páginas de publicação automaticamente; completar estes sinais melhora a consistência da entidade, mas não garante a criação do perfil.', 'go-verge' ) . '</p>';
}

/** Render a URL field. */
function go_verge_publisher_identity_url_field( $args ) {
	$key      = sanitize_key( (string) ( $args['key'] ?? '' ) );
	$identity = go_verge_publisher_identity();
	$value    = (string) ( $identity[ $key ] ?? '' );
	printf(
		'<input class="regular-text code" type="url" name="%1$s[%2$s]" value="%3$s" placeholder="https://…" autocomplete="url">',
		esc_attr( GO_VERGE_PUBLISHER_IDENTITY_OPTION ),
		esc_attr( $key ),
		esc_attr( $value )
	);
}

/** Render a generic text/email/date field. */
function go_verge_publisher_identity_text_field( $args ) {
	$key         = sanitize_key( (string) ( $args['key'] ?? '' ) );
	$type        = in_array( (string) ( $args['type'] ?? '' ), array( 'text', 'email', 'date' ), true ) ? (string) $args['type'] : 'text';
	$description = (string) ( $args['description'] ?? '' );
	$identity    = go_verge_publisher_identity();
	$value       = (string) ( $identity[ $key ] ?? '' );
	printf(
		'<input class="regular-text" type="%1$s" name="%2$s[%3$s]" value="%4$s">',
		esc_attr( $type ),
		esc_attr( GO_VERGE_PUBLISHER_IDENTITY_OPTION ),
		esc_attr( $key ),
		esc_attr( $value )
	);
	if ( $description ) {
		echo '<p class="description">' . esc_html( $description ) . '</p>';
	}
}

/**
 * Site Health readiness test for the identity inputs Google can read locally.
 */
function go_verge_publisher_identity_register_health_test( $tests ) {
	$tests['direct']['go_verge_publisher_identity'] = array(
		'label' => __( 'Entidade editorial do Overdrive', 'go-verge' ),
		'test'  => 'go_verge_publisher_identity_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_publisher_identity_register_health_test' );

/** Run the publisher-entity Site Health test. */
function go_verge_publisher_identity_health_test() {
	$same_as = go_verge_publisher_same_as_urls();
	$logo    = function_exists( 'go_verge_seo_logo' ) ? go_verge_seo_logo() : array();
	$logo_ok = ! empty( $logo['url'] ) && (int) ( $logo['width'] ?? 0 ) >= 112 && (int) ( $logo['height'] ?? 0 ) >= 112;
	$missing = array();

	foreach ( array( 'sobre-o-overdrive', 'contato', 'politica-editorial' ) as $slug ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( ! ( $page instanceof WP_Post ) || 'publish' !== get_post_status( $page ) ) {
			$missing[] = $slug;
		}
	}

	$description_ok = '' !== trim( wp_strip_all_tags( (string) get_bloginfo( 'description' ) ) );
	$good           = $logo_ok && ! empty( $same_as ) && empty( $missing ) && $description_ok;
	$details        = array();
	$details[]      = sprintf( __( 'Logo indexável: %s', 'go-verge' ), $logo_ok ? __( 'ok', 'go-verge' ) : __( 'revisar', 'go-verge' ) );
	$details[]      = sprintf( __( 'Perfis sameAs: %d', 'go-verge' ), count( $same_as ) );
	$details[]      = sprintf( __( 'Páginas editoriais pendentes: %d', 'go-verge' ), count( $missing ) );

	return array(
		'label'       => $good
			? __( 'A entidade editorial tem os sinais essenciais consistentes', 'go-verge' )
			: __( 'A entidade editorial ainda pode ganhar sinais mais fortes', 'go-verge' ),
		'status'      => $good ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Publisher', 'go-verge' ), 'color' => 'blue' ),
		'description' => '<p>' . esc_html( implode( ' · ', $details ) ) . '</p>',
		'actions'     => sprintf(
			'<p><a href="%1$s">%2$s</a></p>',
			esc_url( admin_url( 'options-general.php#go_verge_publisher_identity_section' ) ),
			esc_html__( 'Completar identidade do publisher', 'go-verge' )
		),
		'test'        => 'go_verge_publisher_identity',
	);
}
