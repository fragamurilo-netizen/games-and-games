<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

final class GOAC_Plugin {
	const TABS = array( 'dashboard' => 'Visão geral', 'days' => 'Dias', 'history' => 'Meses e anos', 'forecast' => 'Previsões', 'reports' => 'Relatórios', 'learning' => 'Data Lab', 'optimization' => 'Otimização de RPM', 'trials' => 'Testes por dia', 'distribution' => 'Orçamento & distribuição', 'payments' => 'Pagamentos', 'sites' => 'Sites', 'units' => 'Unidades', 'delivery' => 'Entrega & Saúde', 'manage' => 'Gestão', 'settings' => 'Configurações' );

	private static $instance;

	public static function instance() {
		if ( ! self::$instance ) { self::$instance = new self(); }
		return self::$instance;
	}

	private function __construct() {
		add_action( 'admin_menu', array( $this, 'menu' ) );
		add_action( 'admin_init', array( $this, 'maybe_upgrade' ) );
		add_action( 'admin_enqueue_scripts', array( $this, 'assets' ) );
		add_action( 'admin_post_goac_save_settings', array( $this, 'save_settings' ) );
		add_action( 'admin_post_goac_save_goals', array( $this, 'save_goals' ) );
		add_action( 'admin_post_goac_save_budget', array( $this, 'save_budget' ) );
		add_action( 'admin_post_goac_save_optimization_controls', array( $this, 'save_optimization_controls' ) );
		add_action( 'admin_post_goac_learning_collect', array( $this, 'learning_collect' ) );
		add_action( 'admin_post_goac_mark_engine', array( $this, 'mark_engine' ) );
		add_action( 'admin_post_goac_set_currency', array( $this, 'set_currency' ) );
		add_action( 'admin_post_goac_oauth_start', array( $this, 'oauth_start' ) );
		add_action( 'admin_post_goac_oauth_callback', array( $this, 'oauth_callback' ) );
		add_action( 'admin_post_goac_disconnect', array( $this, 'disconnect' ) );
		add_action( 'admin_post_goac_select_account', array( $this, 'select_account' ) );
		add_action( 'admin_post_goac_sync', array( $this, 'sync' ) );
		add_action( 'admin_post_goac_backfill', array( $this, 'backfill' ) );
		add_action( 'admin_post_goac_flush_cache', array( $this, 'flush_cache' ) );
		add_action( 'admin_post_goac_export', array( $this, 'export' ) );
		add_action( 'admin_post_goac_manage_unit', array( $this, 'manage_unit' ) );
		add_action( 'admin_post_goac_create_unit', array( $this, 'create_unit' ) );
		add_action( 'admin_post_goac_manage_channel', array( $this, 'manage_channel' ) );
		add_action( 'admin_post_goac_create_channel', array( $this, 'create_channel' ) );
		add_action( 'admin_post_goac_delivery_checks', array( $this, 'delivery_checks' ) );
		add_action( 'admin_post_goac_learning_retry', array( $this, 'learning_retry' ) );
		add_action( 'wp_ajax_goac_live_snapshot', array( $this, 'ajax_live_snapshot' ) );
		add_action( 'wp_ajax_goac_backfill_step', array( $this, 'ajax_backfill_step' ) );
		add_action( 'wp_ajax_goac_async', array( $this, 'ajax_async' ) );
		add_filter( 'cron_schedules', array( $this, 'cron_schedules' ) );
		add_action( 'goac_quarter_hour_refresh', array( $this, 'cron_refresh' ) );
		add_action( 'goac_backfill_event', array( $this, 'cron_backfill' ) );
		add_action( 'goac_learning_bootstrap', array( $this, 'cron_learning_bootstrap' ) );
	}

	public static function activate() {
		if ( false === get_option( 'goac_scope_mode', false ) ) { add_option( 'goac_scope_mode', 'full', '', false ); }
		if ( false === get_option( 'goac_refresh_minutes', false ) ) { add_option( 'goac_refresh_minutes', 5, '', false ); }
		if ( ! wp_next_scheduled( 'goac_quarter_hour_refresh' ) ) { wp_schedule_event( time() + 300, 'goac_15min', 'goac_quarter_hour_refresh' ); }
		GOAC_Learning::install();
		if ( GOAC_API::is_connected() ) { wp_schedule_single_event( time() + 45, 'goac_learning_bootstrap' ); }
	}

	public static function deactivate() {
		foreach ( array( 'goac_quarter_hour_refresh', 'goac_backfill_event', 'goac_learning_bootstrap' ) as $hook ) {
			$timestamp = wp_next_scheduled( $hook );
			while ( $timestamp ) { wp_unschedule_event( $timestamp, $hook ); $timestamp = wp_next_scheduled( $hook ); }
		}
	}

	/** Atualizações por ZIP não disparam a ativação: garante cron, limpa sobras da 1.0.x e inicia a importação do histórico. */
	public function maybe_upgrade() {
		// Deactivating the optional plugin hands ownership back to the theme.
		if ( ! wp_next_scheduled( 'goac_quarter_hour_refresh' ) ) { wp_schedule_event( time() + 300, 'goac_15min', 'goac_quarter_hour_refresh' ); }
		if ( GOAC_VERSION === get_option( 'goac_version' ) ) { return; }
		self::retire_theme_center();
		GOAC_Learning::install();
		if ( GOAC_API::is_connected() && ! wp_next_scheduled( 'goac_learning_bootstrap' ) ) { wp_schedule_single_event( time() + 45, 'goac_learning_bootstrap' ); }
		delete_option( 'goac_last_good_snapshot' );
		delete_transient( 'goac_snapshot_v1' );
		if ( GOAC_API::is_connected() && 'idle' === GOAC_Store::backfill_status()['state'] ) { GOAC_Store::start_backfill(); }
		update_option( 'goac_version', GOAC_VERSION, false );
	}

	/**
	 * 3.0: um único AdSense Center. O tema Overdrive 3.83 embutia um segundo plano
	 * de controle (ODAC) com menu, OAuth, fila e cron próprios que disputavam o
	 * mesmo slug `goac`, o mesmo callback OAuth e as mesmas opções de conexão.
	 * O tema deixou de carregá-lo; aqui removemos só o que ficou órfão (cron,
	 * fila, locks e caches recalculáveis). Credenciais `goac_*`, histórico
	 * `goac_days_*` e o histórico diário salvo pelo ODAC são preservados.
	 */
	public static function retire_theme_center() {
		global $wpdb;
		wp_clear_scheduled_hook( 'odac_tick' );
		foreach ( array( 'odac_queue', 'odac_status', 'odac_accounts', 'odac_cache_epoch', 'odac_migration', 'odac_old_cron_retired' ) as $option ) { delete_option( $option ); }
		$likes = array( $wpdb->esc_like( 'odac_lock_' ) . '%', $wpdb->esc_like( '_transient_odac_' ) . '%', $wpdb->esc_like( '_transient_timeout_odac_' ) . '%' );
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s OR option_name LIKE %s OR option_name LIKE %s", $likes ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		delete_transient( GOAC_Learning::LOCK );
	}

	public function delivery_checks() {
		$this->guard( 'goac_delivery_checks' );
		GOAC_View_Delivery::run_checks();
		$this->redirect( 'delivery', 'delivery_checked' );
	}

	public function learning_retry() {
		$this->guard( 'goac_learning_retry' );
		$count = GOAC_Learning::retry_dead_letters();
		if ( false === $count ) { $this->redirect( 'delivery', 'learning_busy' ); }
		if ( ! wp_next_scheduled( 'goac_learning_bootstrap' ) ) { wp_schedule_single_event( time() + 30, 'goac_learning_bootstrap' ); }
		$this->redirect( 'delivery', 'learning_requeued' );
	}

	public function cron_schedules( $schedules ) {
		if ( ! isset( $schedules['goac_15min'] ) ) { $schedules['goac_15min'] = array( 'interval' => 15 * MINUTE_IN_SECONDS, 'display' => 'A cada 15 minutos (GO AdSense)' ); }
		return $schedules;
	}

	public function cron_refresh() {
		if ( ! GOAC_API::is_connected() ) { return; }
		GOAC_Store::sync_recent( 10 * MINUTE_IN_SECONDS );
		$learning = GOAC_Learning::tick( 9.0, 3 );
		$learning_state = is_wp_error( $learning ) ? GOAC_Learning::state() : $learning;
		if ( ( ! empty( $learning_state['queue'] ) || ! empty( $learning_state['maintenance_queue'] ) ) && ! wp_next_scheduled( 'goac_learning_bootstrap' ) ) { wp_schedule_single_event( time() + 60, 'goac_learning_bootstrap' ); }
		if ( GOAC_Store::backfill_running() && ! wp_next_scheduled( 'goac_backfill_event' ) ) { wp_schedule_single_event( time() + 30, 'goac_backfill_event' ); }
	}

	public function cron_backfill() {
		if ( ! GOAC_API::is_connected() ) { return; }
		$status = GOAC_Store::backfill_step( 20 );
		if ( GOAC_Store::backfill_running( $status ) && ! wp_next_scheduled( 'goac_backfill_event' ) ) { wp_schedule_single_event( time() + 60, 'goac_backfill_event' ); }
	}

	public function cron_learning_bootstrap() {
		if ( ! GOAC_API::is_connected() ) { return; }
		$result = GOAC_Learning::tick( 20.0, 6 );
		$state = is_wp_error( $result ) ? GOAC_Learning::state() : $result;
		// Fast lane de backfill: repete sozinho até completar o baseline; depois o cron de 15 min mantém o aprendizado contínuo.
		if ( ( ! empty( $state['queue'] ) || ! empty( $state['maintenance_queue'] ) ) && ! wp_next_scheduled( 'goac_learning_bootstrap' ) ) { wp_schedule_single_event( time() + 10 * MINUTE_IN_SECONDS, 'goac_learning_bootstrap' ); }
	}

	public function menu() {
		add_menu_page( 'AdSense Center', 'AdSense Center', 'manage_options', 'goac', array( $this, 'render' ), 'dashicons-chart-line', 59 );
	}

	public function assets( $hook ) {
		if ( false === strpos( (string) $hook, 'goac' ) ) { return; }
		wp_enqueue_style( 'goac-admin', GOAC_URL . 'assets/admin.css', array(), GOAC_VERSION );
		wp_enqueue_script( 'goac-admin', GOAC_URL . 'assets/admin.js', array(), GOAC_VERSION, true );
		wp_localize_script( 'goac-admin', 'GOAC_DATA', array(
			'ajax' => admin_url( 'admin-ajax.php' ), 'nonce' => wp_create_nonce( 'goac_live' ), 'connected' => GOAC_API::is_connected(),
			'refreshMinutes' => GOAC_UI::refresh_minutes(), 'currency' => GOAC_UI::currency_code() ?: 'BRL',
		) );
	}

	private function guard( $nonce_action = '' ) {
		if ( ! current_user_can( 'manage_options' ) ) { wp_die( 'Sem permissão.' ); }
		if ( $nonce_action ) { check_admin_referer( $nonce_action ); }
	}

	private function redirect( $tab = 'dashboard', $msg = '' ) {
		$args = array( 'page' => 'goac', 'tab' => $tab ); if ( $msg ) { $args['goac_msg'] = $msg; }
		wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) ); exit;
	}

	private function error_redirect( $tab, $msg, $error ) {
		set_transient( 'goac_last_error', is_wp_error( $error ) ? $error->get_error_message() : (string) $error, 15 * MINUTE_IN_SECONDS );
		$this->redirect( $tab, $msg );
	}

	private static function money_input( $key ) {
		if ( ! isset( $_POST[ $key ] ) ) { return null; } // phpcs:ignore WordPress.Security.NonceVerification.Missing
		$raw = trim( (string) wp_unslash( $_POST[ $key ] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Missing
		if ( '' === $raw ) { return false; } // vazio: remove a meta desta moeda
		if ( false !== strpos( $raw, ',' ) ) { $raw = str_replace( array( '.', ',' ), array( '', '.' ), $raw ); }
		return max( 0.0, round( (float) preg_replace( '/[^\d.]/', '', $raw ), 2 ) );
	}

	public function save_settings() {
		$this->guard( 'goac_save_settings' );
		if ( ! GOAC_API::credentials_locked() ) {
			$id = isset( $_POST['client_id'] ) ? sanitize_text_field( wp_unslash( $_POST['client_id'] ) ) : '';
			$secret = isset( $_POST['client_secret'] ) ? trim( (string) wp_unslash( $_POST['client_secret'] ) ) : '';
			update_option( 'goac_client_id', $id, false );
			if ( '' !== $secret ) { update_option( 'goac_client_secret', preg_replace( '/[\r\n\x00-\x1F\x7F]/', '', $secret ), false ); }
		}
		$scope = isset( $_POST['scope_mode'] ) && 'readonly' === $_POST['scope_mode'] ? 'readonly' : 'full';
		$old_scope = get_option( 'goac_scope_mode', 'full' ); update_option( 'goac_scope_mode', $scope, false );
		$refresh = isset( $_POST['refresh_minutes'] ) ? max( 1, min( 30, (int) $_POST['refresh_minutes'] ) ) : 5;
		update_option( 'goac_refresh_minutes', $refresh, false );
		if ( isset( $_POST['history_years'] ) ) { update_option( 'goac_history_years', max( 1, min( 20, (int) $_POST['history_years'] ) ), false ); }
		$currency = isset( $_POST['display_currency'] ) ? strtoupper( sanitize_key( wp_unslash( $_POST['display_currency'] ) ) ) : '';
		foreach ( array( 'month', 'year' ) as $period ) {
			$value = self::money_input( 'goal_' . $period );
			if ( null !== $value ) { GOAC_UI::save_goal( $period, $value ); }
		}
		if ( $currency && in_array( $currency, GOAC_Store::currencies(), true ) && $currency !== GOAC_Store::display_currency() ) {
			update_option( 'goac_display_currency', $currency, false );
			GOAC_Store::prepare_currency( $currency );
		}
		if ( $scope !== $old_scope && GOAC_API::is_connected() ) { update_option( 'goac_reconnect_required', 1, false ); }
		GOAC_API::flush_cache();
		$this->redirect( 'settings', 'settings_saved' );
	}

	public function save_goals() {
		$this->guard( 'goac_save_goals' );
		foreach ( array( 'month', 'year' ) as $period ) {
			$value = self::money_input( 'goal_' . $period );
			if ( null !== $value ) { GOAC_UI::save_goal( $period, $value ); }
		}
		$this->redirect( 'forecast', 'goals_saved' );
	}

	/** Salva despesas pelo ciclo de pagamento e a cotação PayPal usada apenas como estimativa. */
	public function save_budget() {
		$this->guard( 'goac_save_budget' );
		$today = GOAC_API::today();
		$ym = isset( $_POST['budget_month'] ) ? sanitize_text_field( wp_unslash( $_POST['budget_month'] ) ) : substr( $today, 0, 7 );
		$latest = substr( GOAC_Stats::shift_months( $today, 1 ), 0, 7 );
		if ( ! preg_match( '/^\d{4}-\d{2}$/', $ym ) || $ym > $latest ) { $ym = substr( $today, 0, 7 ); }

		$paypal = self::money_input( 'paypal_rate' );
		$paypal = false === $paypal || null === $paypal ? 0.0 : min( 1000.0, (float) $paypal );
		$payout_date = isset( $_POST['payout_date'] ) ? sanitize_text_field( wp_unslash( $_POST['payout_date'] ) ) : GOAC_View_Distribution::default_payout_date( $ym );
		if ( ! GOAC_Stats::valid_date( $payout_date ) || substr( $payout_date, 0, 7 ) !== $ym ) { $payout_date = GOAC_View_Distribution::default_payout_date( $ym ); }

		// Guarda a janela que estava na tela; depois recalcula a nova janela com a data salva.
		$old_cycle = GOAC_View_Distribution::cycle_range( $ym );
		$budgets = get_option( 'goac_distribution_budgets', array() );
		$budgets = is_array( $budgets ) ? $budgets : array();
		$budgets[ $ym ] = array( 'paypal_rate' => $paypal, 'payout_date' => $payout_date, 'updated_at' => time() );
		update_option( 'goac_distribution_budgets', $budgets, false );
		$cycle = GOAC_View_Distribution::cycle_range( $ym );

		$allowed_currencies = GOAC_Store::currencies();
		$expenses = array();
		$raw_expenses = isset( $_POST['expenses'] ) && is_array( $_POST['expenses'] ) ? wp_unslash( $_POST['expenses'] ) : array(); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput.InputNotSanitized
		foreach ( array_slice( $raw_expenses, 0, 300 ) as $row ) {
			if ( ! is_array( $row ) ) { continue; }
			$date = sanitize_text_field( (string) ( $row['date'] ?? '' ) );
			if ( ! GOAC_Stats::valid_date( $date ) ) { $date = $today <= $cycle['end'] && $today >= $cycle['start'] ? $today : $cycle['end']; }
			$category = sanitize_text_field( (string) ( $row['category'] ?? '' ) );
			$description = sanitize_text_field( (string) ( $row['description'] ?? '' ) );
			$currency = strtoupper( sanitize_key( (string) ( $row['currency'] ?? GOAC_Store::display_currency() ) ) );
			if ( ! in_array( $currency, $allowed_currencies, true ) ) { $currency = GOAC_Store::display_currency(); }
			$amount_raw = trim( (string) ( $row['amount'] ?? '' ) );
			if ( false !== strpos( $amount_raw, ',' ) ) { $amount_raw = str_replace( array( '.', ',' ), array( '', '.' ), $amount_raw ); }
			$amount = max( 0.0, round( (float) preg_replace( '/[^\d.]/', '', $amount_raw ), 2 ) );
			if ( $amount <= 0 && '' === $description ) { continue; }
			if ( '' === $category ) { $category = 'Outros'; }
			$expenses[] = array( 'date' => $date, 'category' => $category, 'description' => $description, 'amount' => $amount, 'currency' => $currency );
		}

		// A tela edita somente a janela deste pagamento. Mantém todos os demais ciclos intactos.
		$ledger = get_option( 'goac_distribution_expenses', array() );
		$ledger = is_array( $ledger ) ? $ledger : array();
		$kept = array();
		foreach ( $ledger as $row ) {
			if ( ! is_array( $row ) ) { continue; }
			$date = (string) ( $row['date'] ?? '' );
			if ( GOAC_Stats::valid_date( $date ) && $date >= $old_cycle['start'] && $date <= $old_cycle['end'] ) { continue; }
			$kept[] = $row;
		}
		update_option( 'goac_distribution_expenses', array_values( array_merge( $kept, $expenses ) ), false );

		$revenue_ym = substr( GOAC_Stats::shift_months( $ym . '-01', -1 ), 0, 7 );
		$ref = min( $today, GOAC_Stats::month_end( $revenue_ym . '-01' ) );
		$url = add_query_arg( array( 'page' => 'goac', 'tab' => 'distribution', 'split_month' => $ym, 'period' => 'month', 'ref' => $ref, 'goac_msg' => 'budget_saved' ), admin_url( 'admin.php' ) );
		wp_safe_redirect( $url ); exit;
	}

	/** Salva o espelho manual da configuração atual do Auto Ads para permitir instruções exatas. */
	public function save_optimization_controls() {
		$this->guard( 'goac_save_optimization_controls' );
		$tri = static function( $key ) {
			$value = isset( $_POST[ $key ] ) ? sanitize_key( wp_unslash( $_POST[ $key ] ) ) : 'unknown'; // phpcs:ignore WordPress.Security.NonceVerification.Missing
			return in_array( $value, array( 'on', 'off' ), true ) ? $value : 'unknown';
		};
		$number = static function( $key, $max = 10000 ) {
			if ( ! isset( $_POST[ $key ] ) ) { return null; } // phpcs:ignore WordPress.Security.NonceVerification.Missing
			$raw = trim( (string) wp_unslash( $_POST[ $key ] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Missing
			if ( '' === $raw ) { return null; }
			return max( 0, min( $max, (int) preg_replace( '/[^0-9]/', '', $raw ) ) );
		};
		$cfg = array(
			'configured' => 1,
			'auto_ads' => $tri( 'auto_ads' ),
			'anchor_ads' => $tri( 'anchor_ads' ),
			'vignette_ads' => $tri( 'vignette_ads' ),
			'side_rails_ads' => $tri( 'side_rails_ads' ),
			'banner_ads' => $tri( 'banner_ads' ),
			'find_more' => $tri( 'find_more' ),
			'optimize_existing' => $tri( 'optimize_existing' ),
			'max_ads' => $number( 'max_ads', 100 ),
			'min_distance' => $number( 'min_distance', 10000 ),
			'updated_at' => time(),
		);
		update_option( 'goac_optimization_controls', $cfg, false );
		GOAC_Learning::record_event( 'adsense_config', 'Configuração manual do AdSense atualizada', $cfg );
		$day = isset( $_POST['opt_day'] ) ? sanitize_text_field( wp_unslash( $_POST['opt_day'] ) ) : '';
		$args = array( 'page' => 'goac', 'tab' => 'optimization', 'goac_msg' => 'optimization_controls_saved' );
		if ( GOAC_Stats::valid_date( $day ) ) { $args['opt_day'] = $day; }
		wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) ); exit;
	}

	public function learning_collect() {
		$this->guard( 'goac_learning_collect' );
		$result = GOAC_Learning::tick( 28.0, 10 );
		if ( is_wp_error( $result ) ) { $this->error_redirect( 'learning', 'learning_error', $result ); }
		$this->redirect( 'learning', 'learning_collected' );
	}

	public function mark_engine() {
		$this->guard( 'goac_mark_engine' );
		$label = isset( $_POST['label'] ) ? sanitize_text_field( wp_unslash( $_POST['label'] ) ) : 'Novo motor de anúncios';
		if ( '' === $label ) { $label = 'Novo motor de anúncios'; }
		$payload = array( 'pre_model' => GOAC_Learning::model(), 'optimization_controls' => get_option( 'goac_optimization_controls', array() ), 'goac_version' => GOAC_VERSION );
		GOAC_Learning::record_event( 'engine_launch', $label, $payload );
		GOAC_Learning::rebuild_model();
		$this->redirect( 'learning', 'engine_marked' );
	}

	/** Troca a moeda de exibição e volta para a mesma tela. A receita convertida vem do próprio Google, dia a dia. */
	public function set_currency() {
		$this->guard( 'goac_set_currency' );
		$currency = isset( $_GET['currency'] ) ? strtoupper( sanitize_key( wp_unslash( $_GET['currency'] ) ) ) : '';
		if ( in_array( $currency, GOAC_Store::currencies(), true ) ) {
			update_option( 'goac_display_currency', $currency, false );
			$result = GOAC_Store::prepare_currency( $currency );
			if ( is_wp_error( $result ) ) { set_transient( 'goac_last_error', 'Conversão de moeda: ' . $result->get_error_message(), 15 * MINUTE_IN_SECONDS ); }
		}
		$back = wp_get_referer();
		if ( $back && false !== strpos( $back, 'page=goac' ) ) { wp_safe_redirect( remove_query_arg( 'goac_msg', $back ) ); exit; }
		$this->redirect( 'dashboard' );
	}

	public function oauth_start() {
		$this->guard( 'goac_oauth_start' );
		if ( ! GOAC_API::client_id() || ! GOAC_API::client_secret() ) { $this->redirect( 'settings', 'missing_credentials' ); }
		$state = wp_generate_password( 48, false, false );
		set_transient( 'goac_oauth_state_' . get_current_user_id(), $state, 15 * MINUTE_IN_SECONDS );
		$url = 'https://accounts.google.com/o/oauth2/v2/auth?' . GOAC_API::query_string( array(
			'client_id' => GOAC_API::client_id(), 'redirect_uri' => GOAC_API::redirect_uri(), 'response_type' => 'code', 'scope' => GOAC_API::scope(),
			'access_type' => 'offline', 'prompt' => 'consent', 'include_granted_scopes' => 'true', 'state' => $state,
		) );
		wp_redirect( esc_url_raw( $url ) ); exit; // phpcs:ignore WordPress.Security.SafeRedirect.wp_redirect_wp_redirect
	}

	public function oauth_callback() {
		$this->guard();
		$expected = (string) get_transient( 'goac_oauth_state_' . get_current_user_id() );
		delete_transient( 'goac_oauth_state_' . get_current_user_id() );
		$state = isset( $_GET['state'] ) ? sanitize_text_field( wp_unslash( $_GET['state'] ) ) : '';
		if ( ! $expected || ! hash_equals( $expected, $state ) ) { $this->redirect( 'settings', 'oauth_state' ); }
		if ( ! empty( $_GET['error'] ) ) { $this->redirect( 'settings', 'oauth_denied' ); }
		$code = isset( $_GET['code'] ) ? trim( (string) wp_unslash( $_GET['code'] ) ) : '';
		if ( ! $code ) { $this->redirect( 'settings', 'oauth_code' ); }
		$data = GOAC_API::token_request( array( 'client_id' => GOAC_API::client_id(), 'client_secret' => GOAC_API::client_secret(), 'code' => $code, 'grant_type' => 'authorization_code', 'redirect_uri' => GOAC_API::redirect_uri() ) );
		if ( is_wp_error( $data ) ) { $this->error_redirect( 'settings', 'oauth_error', $data ); }
		$refresh = trim( (string) ( $data['refresh_token'] ?? '' ) );
		if ( ! $refresh ) { $this->redirect( 'settings', 'no_refresh' ); }
		$previous = GOAC_API::connection();
		update_option( 'goac_connection', array( 'refresh_token' => $refresh, 'connected_at' => time(), 'account_name' => (string) ( $previous['account_name'] ?? '' ) ), false );
		delete_option( 'goac_reconnect_required' );
		if ( ! empty( $data['access_token'] ) ) { $ttl = max( 120, (int) ( $data['expires_in'] ?? 3600 ) - 90 ); set_transient( 'goac_access_token', array( 'token' => (string) $data['access_token'], 'expires_at' => time() + $ttl ), $ttl ); }
		$accounts = GOAC_API::discover_accounts();
		if ( is_wp_error( $accounts ) || ! $accounts ) { $this->error_redirect( 'settings', 'discover_error', is_wp_error( $accounts ) ? $accounts : 'Nenhuma conta AdSense acessível.' ); }
		$chosen = $accounts[0];
		foreach ( $accounts as $account ) { if ( ( $account['name'] ?? '' ) === ( $previous['account_name'] ?? '' ) ) { $chosen = $account; break; } }
		$c = GOAC_API::connection(); $c['account_name'] = (string) ( $chosen['name'] ?? '' ); update_option( 'goac_connection', $c, false );
		$hydrated = GOAC_API::hydrate_connection();
		if ( is_wp_error( $hydrated ) ) { $this->error_redirect( 'settings', 'discover_error', $hydrated ); }
		GOAC_Store::sync_recent( 0, true );
		$status = GOAC_Store::backfill_status();
		if ( 'done' !== $status['state'] || ! GOAC_Store::has_data() ) { GOAC_Store::start_backfill(); }
		$this->redirect( 'dashboard', 'connected' );
	}

	public function disconnect() {
		$this->guard( 'goac_disconnect' ); delete_option( 'goac_connection' ); delete_option( 'goac_reconnect_required' ); GOAC_API::flush_cache(); $this->redirect( 'settings', 'disconnected' );
	}

	public function select_account() {
		$this->guard( 'goac_select_account' ); $name = isset( $_POST['account_name'] ) ? sanitize_text_field( wp_unslash( $_POST['account_name'] ) ) : '';
		if ( $name && $name !== GOAC_API::account_name() ) {
			GOAC_API::select_account( $name );
			GOAC_Store::ensure_account();
			GOAC_Store::start_backfill();
		}
		$this->redirect( 'settings', 'account_selected' );
	}

	public function sync() {
		$this->guard( 'goac_sync' );
		$s = GOAC_Store::sync_recent( 0, true );
		if ( is_wp_error( $s ) ) { $this->error_redirect( 'dashboard', 'sync_error', $s ); }
		$this->redirect( 'dashboard', 'synced' );
	}

	public function backfill() {
		$this->guard( 'goac_backfill' );
		$mode = isset( $_GET['mode'] ) ? sanitize_key( wp_unslash( $_GET['mode'] ) ) : 'start';
		GOAC_Store::start_backfill( 'rebuild' === $mode );
		if ( 'rebuild' === $mode ) { GOAC_Store::sync_recent( 0, true ); }
		$status = GOAC_Store::backfill_step( 8 );
		if ( 'error' === $status['state'] ) { $this->error_redirect( 'settings', 'backfill_error', $status['error'] ); }
		$this->redirect( 'settings', 'rebuild' === $mode ? 'backfill_rebuilt' : 'backfill_started' );
	}

	public function flush_cache() {
		$this->guard( 'goac_flush_cache' );
		GOAC_API::flush_cache();
		$this->redirect( 'settings', 'cache_flushed' );
	}

	public function export() {
		$this->guard( 'goac_export' );
		$source = isset( $_GET['source'] ) ? sanitize_key( wp_unslash( $_GET['source'] ) ) : '';
		switch ( $source ) {
			case 'days': GOAC_View_Days::export( GOAC_View_Days::params() ); break;
			case 'months': GOAC_View_History::export_months(); break;
			case 'forecast': GOAC_View_Forecast::export(); break;
			case 'reports': GOAC_View_Reports::export( GOAC_View_Reports::params() ); break;
			case 'mega': GOAC_Learning::export_mega(); break;
			case 'payments': GOAC_View_Payments::export(); break;
		}
		wp_die( 'Exportação desconhecida.' );
	}

	public function manage_unit() {
		$this->guard( 'goac_manage_unit' );
		$name = isset( $_POST['name'] ) ? sanitize_text_field( wp_unslash( $_POST['name'] ) ) : '';
		$display = isset( $_POST['display_name'] ) ? sanitize_text_field( wp_unslash( $_POST['display_name'] ) ) : '';
		$state = isset( $_POST['state'] ) ? strtoupper( sanitize_key( wp_unslash( $_POST['state'] ) ) ) : '';
		$result = GOAC_API::patch_unit( $name, $display, $state );
		if ( is_wp_error( $result ) ) { $this->error_redirect( 'manage', 'write_error', $result ); }
		GOAC_Learning::record_event( 'inventory_change', 'Bloco de anúncio atualizado', array( 'name' => $name, 'display_name' => $display, 'state' => $state ) );
		$this->redirect( 'manage', 'unit_updated' );
	}

	public function create_unit() {
		$this->guard( 'goac_create_unit' );
		$display = isset( $_POST['display_name'] ) ? sanitize_text_field( wp_unslash( $_POST['display_name'] ) ) : '';
		$size = isset( $_POST['size'] ) ? sanitize_text_field( wp_unslash( $_POST['size'] ) ) : '1x3';
		if ( ! $display ) { $this->redirect( 'manage', 'missing_unit_name' ); }
		$result = GOAC_API::create_display_unit( $display, $size );
		if ( is_wp_error( $result ) ) { $this->error_redirect( 'manage', 'write_error', $result ); }
		GOAC_Learning::record_event( 'inventory_change', 'Bloco de anúncio criado', array( 'display_name' => $display, 'size' => $size ) );
		$this->redirect( 'manage', 'unit_created' );
	}

	public function manage_channel() {
		$this->guard( 'goac_manage_channel' );
		$name = isset( $_POST['name'] ) ? sanitize_text_field( wp_unslash( $_POST['name'] ) ) : '';
		$display = isset( $_POST['display_name'] ) ? sanitize_text_field( wp_unslash( $_POST['display_name'] ) ) : '';
		$active_raw = isset( $_POST['active'] ) ? sanitize_key( wp_unslash( $_POST['active'] ) ) : 'keep';
		$active = 'keep' === $active_raw ? null : ( '1' === $active_raw );
		if ( ! $name ) { $this->redirect( 'manage', 'missing_channel_name' ); }
		$result = GOAC_API::patch_channel( $name, $display, $active );
		if ( is_wp_error( $result ) ) { $this->error_redirect( 'manage', 'write_error', $result ); }
		GOAC_Learning::record_event( 'inventory_change', 'Canal personalizado atualizado', array( 'name' => $name, 'display_name' => $display, 'active' => $active ) );
		$this->redirect( 'manage', 'channel_updated' );
	}

	public function create_channel() {
		$this->guard( 'goac_create_channel' );
		$display = isset( $_POST['display_name'] ) ? sanitize_text_field( wp_unslash( $_POST['display_name'] ) ) : '';
		$active = ! isset( $_POST['active'] ) || '0' !== (string) $_POST['active'];
		if ( ! $display ) { $this->redirect( 'manage', 'missing_channel_name' ); }
		$result = GOAC_API::create_channel( $display, $active );
		if ( is_wp_error( $result ) ) { $this->error_redirect( 'manage', 'write_error', $result ); }
		GOAC_Learning::record_event( 'inventory_change', 'Canal personalizado criado', array( 'display_name' => $display, 'active' => $active ) );
		$this->redirect( 'manage', 'channel_created' );
	}

	private function ajax_guard() {
		check_ajax_referer( 'goac_live', 'nonce' );
		if ( ! current_user_can( 'manage_options' ) ) { wp_send_json_error( array( 'message' => 'Sem permissão.' ), 403 ); }
	}

	public function ajax_live_snapshot() {
		$this->ajax_guard();
		$force = ! empty( $_POST['force'] );
		$result = GOAC_Store::sync_recent( $force ? 0 : max( 60, 60 * GOAC_UI::refresh_minutes() - 30 ), $force );
		GOAC_UI::reset_context();
		$c = GOAC_UI::context( false );
		if ( ! $c['first_day'] ) { wp_send_json_error( array( 'message' => is_wp_error( $result ) ? $result->get_error_message() : 'Histórico ainda vazio.' ), 500 ); }
		ob_start();
		GOAC_View_Dashboard::live_block( $c );
		$html = ob_get_clean();
		$synced = (int) $c['meta']['synced_at'];
		wp_send_json_success( array(
			'html' => $html,
			'fetchedAt' => $synced ? 'Dados do AdSense de ' . wp_date( 'H:i:s', $synced, $c['tz'] ) : '',
			'error' => is_wp_error( $result ) ? $result->get_error_message() : '',
		) );
	}

	public function ajax_backfill_step() {
		$this->ajax_guard();
		$status = GOAC_Store::backfill_step( 10 );
		$years = array_map( 'intval', (array) $status['done_years'] );
		$meta = GOAC_Store::meta();
		$running = GOAC_Store::backfill_running( $status );
		if ( 'running' === $status['state'] ) {
			$text = sprintf( 'Importando %d… (%s concluídos)', (int) $status['next_year'], $years ? implode( ', ', $years ) : 'nenhum ano ainda' );
		} elseif ( 'error' === $status['state'] ) {
			$text = 'Erro na importação: ' . $status['error'];
		} elseif ( $running ) {
			$text = 'Convertendo o histórico para ' . implode( ', ', array_keys( array_filter( (array) $status['fx'], static function( $fx ) { return 'running' === ( $fx['state'] ?? '' ); } ) ) ) . ' pelos relatórios do Google…';
		} else {
			$text = sprintf( 'Histórico completo: %s dias desde %s.', number_format_i18n( GOAC_Store::row_count() ), $meta['first_day'] ? GOAC_UI::date( $meta['first_day'] ) : '—' );
			foreach ( (array) $status['fx'] as $cur => $fx ) { if ( 'error' === ( $fx['state'] ?? '' ) ) { $text .= ' Conversão para ' . $cur . ' falhou: ' . $fx['error']; } }
		}
		wp_send_json_success( array( 'state' => $running ? 'running' : ( 'error' === $status['state'] ? 'error' : 'done' ), 'progress' => GOAC_Store::backfill_progress( $status ), 'text' => $text, 'locked' => ! empty( $status['locked'] ) ) );
	}

	public function ajax_async() {
		$this->ajax_guard();
		$block = isset( $_POST['block'] ) ? sanitize_key( wp_unslash( $_POST['block'] ) ) : '';
		if ( 'health' === $block ) { wp_send_json_success( array( 'html' => GOAC_View_Dashboard::health_html() ) ); }
		if ( 'top' === $block ) {
			$dimension = isset( $_POST['dimension'] ) ? sanitize_key( wp_unslash( $_POST['dimension'] ) ) : 'country';
			$period = isset( $_POST['period'] ) ? sanitize_key( wp_unslash( $_POST['period'] ) ) : 'this_month';
			wp_send_json_success( array( 'html' => GOAC_View_Reports::top_html( $dimension, $period ) ) );
		}
		wp_send_json_error( array( 'message' => 'Bloco desconhecido.' ), 400 );
	}

	public function render() {
		if ( ! current_user_can( 'manage_options' ) ) { return; }
		$tab = isset( $_GET['tab'] ) ? sanitize_key( wp_unslash( $_GET['tab'] ) ) : 'dashboard'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! isset( self::TABS[ $tab ] ) ) { $tab = 'dashboard'; }
		echo '<div class="wrap goac-wrap" data-goac-tab="' . esc_attr( $tab ) . '">';
		echo '<div class="goac-titlebar"><div><h1>AdSense Center</h1><p>Central única de monetização: receita, histórico, previsões, Data Lab, otimização de RPM, entrega e saúde dos anúncios, orçamento e distribuição 40/40/20.</p></div><div class="goac-titlebar-side">';
		$this->currency_switch();
		$this->connection_badge();
		echo '</div></div>';
		$this->notice();
		echo '<nav class="nav-tab-wrapper goac-tabs" aria-label="Seções do AdSense Center">';
		foreach ( self::TABS as $slug => $label ) {
			printf( '<a class="nav-tab %s" href="%s"%s>%s</a>', $tab === $slug ? 'nav-tab-active' : '', esc_url( GOAC_UI::url( $slug ) ), $tab === $slug ? ' aria-current="page"' : '', esc_html( $label ) );
		}
		echo '</nav>';
		if ( ! GOAC_API::is_connected() && ! in_array( $tab, array( 'settings', 'delivery' ), true ) ) {
			$this->connect_empty();
		} else {
			if ( in_array( $tab, array( 'days', 'history', 'forecast' ), true ) || ( 'dashboard' !== $tab && 'settings' !== $tab && GOAC_Store::has_data() ) ) {
				$status = GOAC_Store::backfill_status();
				if ( GOAC_Store::backfill_running( $status ) && GOAC_Store::has_data() ) {
					$title = 'running' === $status['state'] ? 'Importando o histórico completo.' : 'Convertendo o histórico para ' . GOAC_Store::display_currency() . '.';
					$hint = 'running' === $status['state'] ? 'Os números de meses e anos antigos aparecem conforme cada ano chega.' : 'Enquanto isso, dias antigos usam a taxa conhecida mais próxima.';
					echo '<div class="notice notice-info goac-backfill" data-goac-backfill="1"><p><strong>' . esc_html( $title ) . '</strong> <span data-goac-backfill-text>' . esc_html( $hint ) . '</span></p><div class="goac-meter"><i style="width:' . esc_attr( (string) round( 100 * GOAC_Store::backfill_progress( $status ) ) ) . '%"></i></div></div>';
				}
			}
			switch ( $tab ) {
				case 'days': GOAC_View_Days::render(); break;
				case 'history': GOAC_View_History::render(); break;
				case 'forecast': GOAC_View_Forecast::render(); break;
				case 'reports': GOAC_View_Reports::render(); break;
				case 'learning': GOAC_View_Learning::render(); break;
				case 'optimization': GOAC_View_Optimization::render(); break;
				case 'trials': GOAC_View_Trials::render(); break;
				case 'distribution': GOAC_View_Distribution::render(); break;
				case 'payments': GOAC_View_Payments::render(); break;
				case 'sites': GOAC_View_Sites::render(); break;
				case 'units': GOAC_View_Units::render(); break;
				case 'delivery': GOAC_View_Delivery::render(); break;
				case 'manage': GOAC_View_Admin::manage(); break;
				case 'settings': GOAC_View_Admin::settings(); break;
				default: GOAC_View_Dashboard::render();
			}
		}
		echo '<p class="goac-version">GO AdSense Center ' . esc_html( GOAC_VERSION ) . '</p></div>';
	}

	/** Seletor Real ⇄ Dólar (e a moeda da conta, se for outra). */
	private function currency_switch() {
		if ( ! GOAC_API::is_connected() || ! GOAC_Store::currency() ) { return; }
		$list = GOAC_Store::currencies();
		if ( count( $list ) < 2 ) { return; }
		$current = GOAC_Store::display_currency(); $account = GOAC_Store::currency();
		$rates = (array) GOAC_Store::meta()['fx_rate'];
		$labels = array( 'BRL' => array( 'R$', 'Real' ), 'USD' => array( 'US$', 'Dólar' ) );
		echo '<div class="goac-currency" role="group" aria-label="Moeda dos valores">';
		foreach ( $list as $cur ) {
			$label = $labels[ $cur ] ?? array( $cur, $cur );
			$title = $cur === $account ? 'Moeda da conta AdSense' : 'Convertido pelo Google, com a taxa de cada dia';
			if ( $cur !== $account && ! empty( $rates[ $cur ] ) && $rates[ $cur ] > 0 ) { $title .= ' · 1 ' . $cur . ' ≈ ' . GOAC_UI::money( 1 / $rates[ $cur ], 2, $account ) . ' (últimos 7 dias)'; }
			printf( '<a class="%s" href="%s" aria-pressed="%s" title="%s"><b>%s</b> %s</a>', $cur === $current ? 'is-active' : '', esc_url( GOAC_UI::action_url( 'goac_set_currency', array( 'currency' => $cur ) ) ), $cur === $current ? 'true' : 'false', esc_attr( $title ), esc_html( $label[0] ), esc_html( $label[1] ) );
		}
		echo '</div>';
	}

	private function connection_badge() {
		$c = GOAC_API::connection();
		if ( GOAC_API::is_connected() ) { echo '<span class="goac-status is-on"><i></i>' . esc_html( $c['display_name'] ?? 'Conectado' ) . '</span>'; }
		else { echo '<span class="goac-status"><i></i>Não conectado</span>'; }
	}

	private function notice() {
		$msg = isset( $_GET['goac_msg'] ) ? sanitize_key( wp_unslash( $_GET['goac_msg'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$map = array(
			'settings_saved' => array( 'success', 'Configurações salvas.' ), 'goals_saved' => array( 'success', 'Metas salvas.' ), 'budget_saved' => array( 'success', 'Ciclo de pagamento salvo e distribuição recalculada.' ), 'optimization_controls_saved' => array( 'success', 'Configuração atual do AdSense salva. As próximas instruções usam esses valores.' ), 'learning_collected' => array( 'success', 'Coleta enriquecida acelerada e modelo recalibrado.' ), 'learning_error' => array( 'error', 'A coleta enriquecida encontrou um erro.' ), 'engine_marked' => array( 'success', 'Novo regime marcado. O algoritmo preservou o baseline anterior e passou a separar o pós-motor.' ), 'connected' => array( 'success', 'AdSense conectado. O histórico completo está sendo importado.' ), 'disconnected' => array( 'success', 'Conta desconectada. O histórico local foi mantido.' ),
			'synced' => array( 'success', 'Dados atualizados.' ), 'delivery_checked' => array( 'success', 'Verificação de loader e ads.txt concluída.' ), 'learning_requeued' => array( 'success', 'Jobs em dead-letter voltaram para a fila do Data Lab.' ), 'learning_busy' => array( 'warning', 'O Data Lab está processando agora. Tente novamente em alguns minutos.' ), 'sync_error' => array( 'error', 'Falha ao atualizar os dados.' ), 'unit_updated' => array( 'success', 'Unidade atualizada.' ), 'unit_created' => array( 'success', 'Unidade criada.' ), 'channel_updated' => array( 'success', 'Canal personalizado atualizado.' ), 'channel_created' => array( 'success', 'Canal personalizado criado.' ),
			'write_error' => array( 'error', 'O Google recusou a operação de escrita. Veja o detalhe abaixo.' ), 'missing_credentials' => array( 'error', 'Informe o Client ID e o Client Secret.' ),
			'oauth_state' => array( 'error', 'Falha de segurança no retorno do OAuth. Tente conectar novamente.' ), 'oauth_denied' => array( 'error', 'A autorização do Google foi cancelada.' ),
			'oauth_code' => array( 'error', 'O Google não devolveu o código de autorização.' ), 'oauth_error' => array( 'error', 'Falha ao trocar o código OAuth.' ), 'no_refresh' => array( 'error', 'O Google não devolveu refresh token. Revogue o acesso do app no Google e tente novamente.' ),
			'discover_error' => array( 'error', 'Não foi possível descobrir a conta AdSense.' ), 'account_selected' => array( 'success', 'Conta selecionada.' ), 'missing_unit_name' => array( 'error', 'Informe o nome da unidade.' ), 'missing_channel_name' => array( 'error', 'Informe o nome do canal personalizado.' ),
			'backfill_started' => array( 'success', 'Importação do histórico iniciada. Ela continua sozinha enquanto esta tela estiver aberta e também pelo WP-Cron.' ), 'backfill_rebuilt' => array( 'success', 'Histórico apagado e reimportação iniciada.' ), 'backfill_error' => array( 'error', 'A importação do histórico falhou.' ), 'cache_flushed' => array( 'success', 'Cache de relatórios limpo.' ),
		);
		if ( $msg && isset( $map[ $msg ] ) ) { printf( '<div class="notice notice-%s is-dismissible"><p>%s</p></div>', esc_attr( $map[ $msg ][0] ), esc_html( $map[ $msg ][1] ) ); }
		$err = get_transient( 'goac_last_error' ); if ( $err ) { delete_transient( 'goac_last_error' ); echo '<div class="notice notice-error"><p><strong>Detalhe:</strong> ' . esc_html( $err ) . '</p></div>'; }
		if ( get_option( 'goac_reconnect_required' ) ) { echo '<div class="notice notice-warning"><p>O escopo OAuth mudou. Reconecte a conta para aplicar a nova permissão.</p></div>'; }
	}

	private function connect_empty() {
		?><section class="goac-empty"><span class="dashicons dashicons-chart-line"></span><h2>Conecte o AdSense ao WordPress</h2><p>Configure as credenciais OAuth e conecte a conta para liberar receita do dia, todos os dias com totais, meses e anos, previsões de mês e ano, metas, relatórios por página e país, pagamentos e status dos sites.</p><a class="button button-primary button-hero" href="<?php echo esc_url( GOAC_UI::url( 'settings' ) ); ?>">Configurar conexão</a></section><?php
	}
}
