<?php
/**
 * Search Console connection handoff for the Overdrive admin.
 *
 * The theme consumes the public GED_Search_Console contract exposed by
 * Lume. It deliberately does not duplicate OAuth credentials.
 * This screen makes the owner of the connection obvious and discovers the
 * closest Lume/Search Console settings screen when available.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function go_verge_search_console_is_connected() {
	return class_exists( 'GED_Search_Console' )
		&& method_exists( 'GED_Search_Console', 'connected' )
		&& (bool) GED_Search_Console::connected();
}

function go_verge_search_console_setup_url() {
	return admin_url( 'tools.php?page=go-search-console-setup' );
}

/** Build a usable admin URL from a registered menu/submenu item. */
function go_verge_search_console_admin_item_url( $parent, $slug ) {
	$slug   = (string) $slug;
	$parent = (string) $parent;
	if ( preg_match( '#^https?://#i', $slug ) ) {
		return $slug;
	}
	if ( false !== strpos( $slug, '.php' ) && false === strpos( $slug, ' ' ) ) {
		return admin_url( ltrim( $slug, '/' ) );
	}
	if ( $parent && false !== strpos( $parent, '.php' ) ) {
		$sep = false === strpos( $parent, '?' ) ? '?' : '&';
		return admin_url( ltrim( $parent, '/' ) . $sep . 'page=' . rawurlencode( $slug ) );
	}
	return admin_url( 'admin.php?page=' . rawurlencode( $slug ) );
}

/**
 * Find the most specific registered Lume/Search Console screen.
 * Search Console wins; then Conexões/Dados/Configurações inside a Desk menu.
 */
function go_verge_search_console_find_desk_url() {
	global $menu, $submenu;
	$best = '';
	$fallback = '';

	foreach ( (array) $submenu as $parent => $items ) {
		$parent_label = '';
		foreach ( (array) $menu as $top ) {
			if ( isset( $top[2] ) && (string) $top[2] === (string) $parent ) {
				$parent_label = wp_strip_all_tags( (string) ( $top[0] ?? '' ) );
				break;
			}
		}
		$is_desk_parent = false !== stripos( $parent_label, 'Editorial Desk' ) || false !== stripos( (string) $parent, 'editorial' );
		foreach ( (array) $items as $item ) {
			$label = wp_strip_all_tags( (string) ( $item[0] ?? '' ) );
			$slug  = (string) ( $item[2] ?? '' );
			if ( '' === $slug ) {
				continue;
			}
			$url = go_verge_search_console_admin_item_url( $parent, $slug );
			if ( false !== stripos( $label, 'Search Console' ) ) {
				return $url;
			}
			if ( $is_desk_parent && preg_match( '/Conex|Dados|Configura|Integra/i', $label ) ) {
				$best = $best ?: $url;
			}
			if ( $is_desk_parent ) {
				$fallback = $fallback ?: $url;
			}
		}
	}

	foreach ( (array) $menu as $item ) {
		$label = wp_strip_all_tags( (string) ( $item[0] ?? '' ) );
		$slug  = (string) ( $item[2] ?? '' );
		if ( '' === $slug ) {
			continue;
		}
		if ( false !== stripos( $label, 'Search Console' ) ) {
			return go_verge_search_console_admin_item_url( '', $slug );
		}
		if ( false !== stripos( $label, 'Editorial Desk' ) ) {
			$fallback = $fallback ?: go_verge_search_console_admin_item_url( '', $slug );
		}
	}

	return $best ?: $fallback;
}

function go_verge_search_console_setup_menu() {
	add_management_page(
		__( 'Search Console', 'go-verge' ),
		__( 'Search Console', 'go-verge' ),
		'manage_options',
		'go-search-console-setup',
		'go_verge_search_console_setup_page'
	);
}
add_action( 'admin_menu', 'go_verge_search_console_setup_menu', 99 );

function go_verge_search_console_setup_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$contract = class_exists( 'GED_Search_Console' );
	$connected = go_verge_search_console_is_connected();
	$desk_url = go_verge_search_console_find_desk_url();
	?>
	<div class="wrap go-gsc-setup">
		<h1><?php esc_html_e( 'Search Console', 'go-verge' ); ?></h1>
		<div class="notice <?php echo $connected ? 'notice-success' : 'notice-warning'; ?> inline">
			<p><strong><?php echo $connected ? esc_html__( 'Conectado', 'go-verge' ) : esc_html__( 'Ainda não conectado', 'go-verge' ); ?></strong></p>
			<?php if ( $connected ) : ?>
				<p><?php esc_html_e( 'O Overdrive já consegue ler os dados que o Lume importa do Search Console para a coluna Indexação / SERP.', 'go-verge' ); ?></p>
			<?php elseif ( $contract ) : ?>
				<p><?php esc_html_e( 'A autenticação pertence ao Lume. O tema não guarda uma segunda cópia das credenciais do Google.', 'go-verge' ); ?></p>
			<?php else : ?>
				<p><?php esc_html_e( 'O conector GED_Search_Console não foi detectado. Ative ou atualize o Lume antes de conectar a conta Google.', 'go-verge' ); ?></p>
			<?php endif; ?>
		</div>
		<?php if ( $desk_url ) : ?>
			<p><a class="button button-primary" href="<?php echo esc_url( $desk_url ); ?>"><?php esc_html_e( 'Abrir configuração no Lume', 'go-verge' ); ?></a></p>
		<?php else : ?>
			<p><strong><?php esc_html_e( 'Onde conectar:', 'go-verge' ); ?></strong> <?php esc_html_e( 'abra o Lume e entre em Configurações/Conexões (ou Dados) → Search Console. Esta tela passa a mostrar “Conectado” assim que o contrato do Desk estiver autenticado.', 'go-verge' ); ?></p>
		<?php endif; ?>
		<hr>
		<p><?php esc_html_e( 'A coluna “Indexação / SERP” usa impressões reais importadas do Google Search para confirmar que uma URL apareceu na SERP. Zero impressões não é tratado como prova de desindexação.', 'go-verge' ); ?></p>
	</div>
	<?php
}
