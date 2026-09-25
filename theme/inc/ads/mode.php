<?php
/** Manual inventory coexists with the account's official Auto ads. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Compatibility accessors: legacy options, constants and filters cannot select another engine. */
function go_verge_ads_delivery_modes() {
	return array( 'hybrid' => 'Manuais + Auto ads' );
}
function go_verge_ads_delivery_mode() { return 'hybrid'; }
function go_verge_ads_manual_delivery_enabled() {
	$config = go_verge_ads_config();
	return ! empty( $config['enabled'] );
}
function go_verge_ads_delivery_mode_locked() { return true; }

/** Legacy callers receive a safe refusal; there is no mutable admin endpoint. */
function go_verge_ads_save_delivery_mode( $requested ) {
	if ( ! current_user_can( 'manage_options' ) ) { return new WP_Error( 'forbidden', 'Sem permissão.' ); }
	if ( 'hybrid' === $requested ) { return false; }
	return new WP_Error( 'fixed_hybrid_architecture', 'O tema integra anúncios manuais e Auto ads; os formatos automáticos são configurados no AdSense.' );
}

/**
 * One administrative migration, independent of front-end delivery decisions.
 * Back up the original value/history before normalization. Do not alter account
 * records, consent, per-unit switches, or the global advertising switch.
 */
function go_verge_ads_migrate_manual_architecture() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) || ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) ) { return false; }
	$marker_key = 'go_verge_ads_hybrid_architecture_v1';
	$marker = get_option( $marker_key, false );
	if ( is_array( $marker ) && 1 === (int) ( $marker['version'] ?? 0 ) ) { return false; }
	$backup_key = 'go_verge_ads_hybrid_architecture_backup_v1';
	$backup = get_option( $backup_key, false );
	if ( ! is_array( $backup ) ) {
		$missing = new stdClass();
		$previous = get_option( 'go_verge_ads_delivery_mode', $missing );
		$backup = array(
			'version' => 1, 'at_utc' => gmdate( 'c' ),
			'option_existed' => $previous !== $missing,
			'option_value' => $previous !== $missing ? $previous : null,
			'history_value' => get_option( 'go_verge_ads_delivery_mode_history', array() ),
			'legacy_constant_defined' => defined( 'GO_VERGE_ADS_DELIVERY_MODE' ),
			'legacy_constant_value' => defined( 'GO_VERGE_ADS_DELIVERY_MODE' ) ? GO_VERGE_ADS_DELIVERY_MODE : null,
			'legacy_filter_present' => false !== has_filter( 'go_verge_ads_delivery_mode' ),
		);
		/* add_option is atomic: concurrent admin requests cannot overwrite the original. */
		add_option( $backup_key, $backup, '', false );
		$backup = get_option( $backup_key, false );
		if ( ! is_array( $backup ) || 1 !== (int) ( $backup['version'] ?? 0 ) ) { return false; }
	}
	if ( 1 !== (int) ( $backup['version'] ?? 0 ) || ! array_key_exists( 'option_value', $backup ) || ! array_key_exists( 'option_existed', $backup ) ) { return false; }
	if ( 'hybrid' !== get_option( 'go_verge_ads_delivery_mode', null ) ) {
		update_option( 'go_verge_ads_delivery_mode', 'hybrid', false );
		if ( 'hybrid' !== get_option( 'go_verge_ads_delivery_mode', null ) ) { return false; }
	}
	$history = get_option( 'go_verge_ads_delivery_mode_history', array() );
	$history = is_array( $history ) ? $history : array();
	$recorded = false;
	foreach ( $history as $entry ) { if ( is_array( $entry ) && 'hybrid-architecture-v1' === ( $entry['reason'] ?? '' ) ) { $recorded = true; break; } }
	if ( ! $recorded ) {
		$history[] = array(
			'at_utc' => gmdate( 'c' ), 'user_id' => get_current_user_id(),
			'from' => ! empty( $backup['option_existed'] ) && is_string( $backup['option_value'] ) ? $backup['option_value'] : 'legacy-default-or-invalid',
			'to' => 'hybrid', 'reason' => 'hybrid-architecture-v1', 'trigger' => 'administrative-upgrade',
		);
		update_option( 'go_verge_ads_delivery_mode_history', $history, false );
		if ( $history !== get_option( 'go_verge_ads_delivery_mode_history', array() ) ) { return false; }
	}
	/* Only the request that commits this marker issues the one cache purge. */
	if ( ! add_option( $marker_key, array( 'version' => 1, 'at_utc' => gmdate( 'c' ) ), '', false ) ) { return false; }
	go_verge_ads_schedule_policy_cache_purge();
	return true;
}
add_action( 'admin_init', 'go_verge_ads_migrate_manual_architecture', 10 );

/** Coalesce administrative architecture/preset migrations into one final purge. */
function go_verge_ads_schedule_policy_cache_purge() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) || ! empty( $GLOBALS['go_verge_ads_policy_cache_purge_queued'] ) ) { return; }
	$GLOBALS['go_verge_ads_policy_cache_purge_queued'] = true;
	add_action( 'shutdown', 'go_verge_ads_purge_policy_cache', 20 );
}
function go_verge_ads_purge_policy_cache() {
	if ( empty( $GLOBALS['go_verge_ads_policy_cache_purge_queued'] ) ) { return; }
	$GLOBALS['go_verge_ads_policy_cache_purge_queued'] = false;
	delete_transient( 'goac_delivery_checks' );
	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) { go_verge_purge_all_page_cache(); }
	else { do_action( 'litespeed_purge_all' ); }
}


/** Read-only status, reused by bundled or external GOAC integrations. */
function go_verge_ads_delivery_mode_form() {
	if ( ! current_user_can( 'manage_options' ) ) { return; }
	echo '<h3>Anúncios manuais + Auto ads</h3><p>O tema preserva seu inventário manual e o Top Scroll. Um único loader oficial também permite os Auto ads configurados no AdSense, respeitando o consentimento existente.</p>';
	$config = go_verge_ads_config();
	if ( empty( $config['enabled'] ) ) { echo '<p><strong>Chave global desligada:</strong> o tema não emite loader nem unidades. A migração não modifica essa escolha.</p>'; }
	echo '<p><strong>No AdSense:</strong> a ativação de Auto ads, os formatos, a carga e as exclusões de páginas ou áreas são configurados na conta. O tema não exige desligar banners in-page, side rails ou a otimização de anúncios existentes. Use a prévia e os experimentos do AdSense para avaliar a distribuição junto dos anúncios manuais. Este quadro não consulta nem altera esses controles.</p>';
	echo '<p>Preferências antigas de arquitetura não suspendem as unidades manuais. A migração administrativa preserva o histórico e solicita a limpeza do cache uma vez; confirme a propagação no CDN e o HTML publicado. O modo local não comprova que Auto ads esteja ativado na conta.</p>';
	if ( function_exists( 'go_verge_adsense_topscroll_baseline_applied' ) && function_exists( 'go_verge_adsense_topscroll_config' ) ) {
		$topscroll = go_verge_adsense_topscroll_config();
		echo '<p><strong>Configuração local de Top Scroll:</strong> ' . ( go_verge_adsense_topscroll_baseline_applied() ? 'inicialização registrada.' : 'valores ausentes recebem o padrão; persistência administrativa pendente.' ) . ' Preferências salvas são preservadas. Estado efetivo da unidade: <code>' . ( ! empty( $topscroll['enabled'] ) ? 'habilitada' : 'desabilitada' ) . '</code>; teto local <code>' . esc_html( (string) ( $topscroll['frequency_max'] ?? 0 ) ) . '</code> por 24h. A chave global e o consentimento continuam valendo.</p>';
		if ( ! empty( $topscroll['external_overrides'] ) ) { echo '<p><strong>Overrides externos preservados:</strong> <code>' . esc_html( implode( ', ', array_keys( $topscroll['external_overrides'] ) ) ) . '</code>. O valor efetivo pode diferir do preset; não foi removida configuração externa.</p>'; }
	}
	$marker = get_option( 'go_verge_ads_hybrid_architecture_v1', false );
	if ( is_array( $marker ) && ! empty( $marker['at_utc'] ) ) { echo '<p>Migração local registrada (UTC): <code>' . esc_html( $marker['at_utc'] ) . '</code>.</p>'; }
}
function go_verge_ads_delivery_mode_page() {
	if ( ! current_user_can( 'manage_options' ) ) { return; }
	echo '<div class="wrap"><h1>Contrato de entrega</h1>';
	go_verge_ads_delivery_mode_form();
	echo '</div>';
}
function go_verge_ads_delivery_mode_menu() {
	global $menu;
	$parent = 'tools.php';
	foreach ( (array) $menu as $entry ) { if ( 'goac' === ( $entry[2] ?? '' ) ) { $parent = 'goac'; break; } }
	add_submenu_page( $parent, 'Contrato de entrega', 'Contrato de entrega', 'manage_options', 'go-verge-ads-delivery-mode', 'go_verge_ads_delivery_mode_page' );
}
add_action( 'admin_menu', 'go_verge_ads_delivery_mode_menu', 99 );
