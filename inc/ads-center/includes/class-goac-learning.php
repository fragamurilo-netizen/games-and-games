<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Data Lab do GO AdSense Center.
 *
 * Mantém um dataset local de alta granularidade para explicar receita/RPM e para
 * separar mudanças de regime (ex.: troca do motor de anúncios). Os dados vêm
 * exclusivamente da API oficial do AdSense e do histórico local já coletado.
 *
	 * A coleta roda em lotes limitados: por ação do administrador e pelos hooks
	 * goac_quarter_hour_refresh/goac_learning_bootstrap registrados pelo provider.
 */
final class GOAC_Learning {
	const STATE_OPTION = 'goac_learning_state_v1';
	const MODEL_OPTION = 'goac_learning_model_v1';
	const RESOURCE_OPTION = 'goac_learning_resources_v1';
	const LOCK = 'goac_learning_lock'; // Transient legado (<= 2.5); mantido só para limpeza na desinstalação.
	const LEASE = 'goac_learning_lease';
	const COOLDOWN = 'goac_learning_cooldown_until';
	const COUNTS = 'goac_learning_counts';
	const MAX_ATTEMPTS = 5;
	const SCHEMA = '1.0';
	/** Linhas por consulta: acima disso cortes por período são divididos e URLs ficam marcadas como truncadas. */
	const REPORT_LIMIT = 20000;

	public static function table_rows() {
		global $wpdb;
		return $wpdb->prefix . 'goac_learning_rows';
	}

	public static function table_events() {
		global $wpdb;
		return $wpdb->prefix . 'goac_learning_events';
	}

	public static function account_key() {
		return md5( (string) GOAC_API::account_name() );
	}

	/** Dimensões estáveis (CODE/ID) e interações que ajudam a explicar a renda. */
	public static function definitions() {
		return array(
			'platform' => array( 'label' => 'Plataforma', 'dimensions' => array( 'PLATFORM_TYPE_CODE' ), 'priority' => 1 ),
			'format' => array( 'label' => 'Formato', 'dimensions' => array( 'AD_FORMAT_CODE' ), 'priority' => 1 ),
			'placement' => array( 'label' => 'Placement', 'dimensions' => array( 'AD_PLACEMENT_CODE' ), 'priority' => 1 ),
			'ad_unit' => array( 'label' => 'Bloco de anúncio', 'dimensions' => array( 'AD_UNIT_ID' ), 'priority' => 1 ),
			'ad_unit_size' => array( 'label' => 'Tamanho do bloco', 'dimensions' => array( 'AD_UNIT_SIZE_CODE' ), 'priority' => 1 ),
			'country' => array( 'label' => 'País', 'dimensions' => array( 'COUNTRY_CODE' ), 'priority' => 1 ),
			'traffic_source' => array( 'label' => 'Origem do tráfego', 'dimensions' => array( 'TRAFFIC_SOURCE_CODE' ), 'priority' => 1 ),
			'bid_type' => array( 'label' => 'Tipo de lance', 'dimensions' => array( 'BID_TYPE_CODE' ), 'priority' => 1 ),
			'targeting' => array( 'label' => 'Segmentação', 'dimensions' => array( 'TARGETING_TYPE_CODE' ), 'priority' => 1 ),
			'buyer_network' => array( 'label' => 'Rede compradora', 'dimensions' => array( 'BUYER_NETWORK_ID' ), 'priority' => 1 ),
			'platform_format' => array( 'label' => 'Plataforma × formato', 'dimensions' => array( 'PLATFORM_TYPE_CODE', 'AD_FORMAT_CODE' ), 'priority' => 1 ),
			'platform_placement' => array( 'label' => 'Plataforma × placement', 'dimensions' => array( 'PLATFORM_TYPE_CODE', 'AD_PLACEMENT_CODE' ), 'priority' => 1 ),
			'format_placement' => array( 'label' => 'Formato × placement', 'dimensions' => array( 'AD_FORMAT_CODE', 'AD_PLACEMENT_CODE' ), 'priority' => 1 ),
			'traffic_platform' => array( 'label' => 'Origem × plataforma', 'dimensions' => array( 'TRAFFIC_SOURCE_CODE', 'PLATFORM_TYPE_CODE' ), 'priority' => 1 ),
			'creative_size' => array( 'label' => 'Tamanho do criativo', 'dimensions' => array( 'CREATIVE_SIZE_CODE' ), 'priority' => 2 ),
			'browser' => array( 'label' => 'Navegador', 'dimensions' => array( 'BROWSER_TYPE_CODE' ), 'priority' => 2 ),
			'os' => array( 'label' => 'Sistema operacional', 'dimensions' => array( 'OS_TYPE_CODE' ), 'priority' => 2 ),
			'content_platform' => array( 'label' => 'Plataforma de conteúdo', 'dimensions' => array( 'CONTENT_PLATFORM_CODE' ), 'priority' => 2 ),
			'served_ad_type' => array( 'label' => 'Tipo de anúncio veiculado', 'dimensions' => array( 'SERVED_AD_TYPE_CODE' ), 'priority' => 2 ),
			'requested_ad_type' => array( 'label' => 'Tipo de anúncio solicitado', 'dimensions' => array( 'REQUESTED_AD_TYPE_CODE' ), 'priority' => 2 ),
			'domain' => array( 'label' => 'Domínio', 'dimensions' => array( 'DOMAIN_CODE' ), 'priority' => 2 ),
			'custom_channel' => array( 'label' => 'Canal personalizado', 'dimensions' => array( 'CUSTOM_CHANNEL_ID' ), 'priority' => 2 ),
			'url_channel' => array( 'label' => 'Canal de URL', 'dimensions' => array( 'URL_CHANNEL_ID' ), 'priority' => 2 ),
			'webview' => array( 'label' => 'WebView', 'dimensions' => array( 'WEBVIEW_TYPE_CODE' ), 'priority' => 2 ),
			'product' => array( 'label' => 'Produto AdSense', 'dimensions' => array( 'PRODUCT_CODE' ), 'priority' => 2 ),
		);
	}

	public static function install() {
		global $wpdb;
		require_once ABSPATH . 'wp-admin/includes/upgrade.php';
		$charset = $wpdb->get_charset_collate();
		$rows = self::table_rows();
		$events = self::table_events();
		$sql_rows = "CREATE TABLE {$rows} (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			account_key char(32) NOT NULL,
			report_key varchar(64) NOT NULL,
			dimension_key varchar(190) NOT NULL,
			day date NOT NULL,
			bucket smallint(5) unsigned NOT NULL DEFAULT 0,
			value_hash char(32) NOT NULL,
			value_text text NULL,
			dimensions_json longtext NULL,
			earnings double NOT NULL DEFAULT 0,
			page_views bigint(20) unsigned NOT NULL DEFAULT 0,
			ad_requests bigint(20) unsigned NOT NULL DEFAULT 0,
			matched_requests bigint(20) unsigned NOT NULL DEFAULT 0,
			impressions bigint(20) unsigned NOT NULL DEFAULT 0,
			clicks bigint(20) unsigned NOT NULL DEFAULT 0,
			viewability double NULL,
			measurability double NULL,
			view_time double NULL,
			metric_set varchar(32) NOT NULL DEFAULT '',
			captured_at datetime NOT NULL,
			PRIMARY KEY  (id),
			UNIQUE KEY uq_learning (account_key,report_key,day,bucket,value_hash),
			KEY report_day (account_key,report_key,day),
			KEY captured_at (captured_at)
		) {$charset};";
		$sql_events = "CREATE TABLE {$events} (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			account_key char(32) NOT NULL,
			event_time datetime NOT NULL,
			event_type varchar(64) NOT NULL,
			label varchar(190) NOT NULL,
			payload longtext NULL,
			created_by bigint(20) unsigned NOT NULL DEFAULT 0,
			PRIMARY KEY  (id),
			KEY account_time (account_key,event_time),
			KEY event_type (event_type)
		) {$charset};";
		dbDelta( $sql_rows );
		dbDelta( $sql_events );
		self::ensure_state();
	}

	private static function default_target() {
		$today = GOAC_API::today();
		// Marco editorial pedido para a preparação do novo motor em setembro/2026.
		if ( $today >= '2026-09-15' && $today <= '2026-09-19' ) { return '2026-09-19'; }
		return GOAC_Stats::add_days( $today, 4 );
	}

	/** Lê o estado e só grava quando algo precisou ser normalizado. A fila do baseline é montada no primeiro lote manual. */
	public static function ensure_state() {
		$raw = get_option( self::STATE_OPTION, array() );
		$state = is_array( $raw ) ? $raw : array();
		$account = self::account_key();
		if ( empty( $state['account_key'] ) || $state['account_key'] !== $account ) {
			$state = array(
				'schema' => self::SCHEMA,
				'account_key' => $account,
				'target_date' => self::default_target(),
				'history_days' => 365,
				'page_days' => 30,
				'queue' => array(),
				'done' => array(),
				'failed' => array(),
				'unsupported' => array(),
				'started_at' => time(),
				'updated_at' => 0,
				'last_resource_at' => 0,
				'last_model_at' => 0,
				'live_cursor' => 0,
				'maintenance_date' => '',
				'maintenance_queue' => array(),
				'maintenance_done' => array(),
			);
		}
		foreach ( array( 'dead_letter', 'failed', 'unsupported', 'done' ) as $bucket ) {
			if ( ! isset( $state[ $bucket ] ) || ! is_array( $state[ $bucket ] ) ) { $state[ $bucket ] = array(); }
		}
		if ( ! isset( $state['queue'] ) || ! is_array( $state['queue'] ) ) { $state['queue'] = array(); }
		if ( ! isset( $state['last_success'] ) ) { $state['last_success'] = 0; }
		if ( ! isset( $state['maintenance_date'] ) ) { $state['maintenance_date'] = ''; }
		if ( ! isset( $state['maintenance_queue'] ) || ! is_array( $state['maintenance_queue'] ) ) { $state['maintenance_queue'] = array(); }
		if ( ! isset( $state['maintenance_done'] ) || ! is_array( $state['maintenance_done'] ) ) { $state['maintenance_done'] = array(); }
		if ( $state !== $raw ) { update_option( self::STATE_OPTION, $state, false ); }
		return $state;
	}

	private static function baseline_empty( array $state ) {
		return empty( $state['queue'] ) && empty( $state['done'] ) && empty( $state['unsupported'] ) && empty( $state['dead_letter'] );
	}

	private static function build_queue( array $state ) {
		$today = GOAC_API::today();
		$history_days = max( 30, min( 730, (int) ( $state['history_days'] ?? 365 ) ) );
		$start = GOAC_Stats::add_days( $today, -( $history_days - 1 ) );
		$defs = self::definitions();
		uasort( $defs, static function( $a, $b ) { return (int) $a['priority'] <=> (int) $b['priority']; } );
		$jobs = array();
		foreach ( $defs as $key => $def ) {
			for ( $s = $start; $s <= $today; $s = GOAC_Stats::add_days( $e, 1 ) ) {
				$e = min( $today, GOAC_Stats::add_days( $s, 89 ) );
				$jobs[] = array( 'id' => 'profile:' . $key . ':' . $s . ':' . $e, 'type' => 'profile', 'key' => $key, 'start' => $s, 'end' => $e, 'priority' => (int) $def['priority'] );
			}
		}
		$page_days = max( 7, min( 90, (int) ( $state['page_days'] ?? 30 ) ) );
		$from = GOAC_Stats::add_days( $today, -$page_days );
		for ( $d = $from; $d < $today; $d = GOAC_Stats::add_days( $d, 1 ) ) {
			$jobs[] = array( 'id' => 'page:' . $d, 'type' => 'page_url', 'key' => 'page_url', 'start' => $d, 'end' => $d, 'priority' => 1 );
		}
		usort( $jobs, static function( $a, $b ) {
			if ( (int) $a['priority'] === (int) $b['priority'] ) { return strcmp( $b['end'], $a['end'] ); }
			return (int) $a['priority'] <=> (int) $b['priority'];
		} );
		return $jobs;
	}

	/** Cria a fila de fechamento do dia anterior; não altera o percentual do baseline inicial. */
	private static function ensure_maintenance_queue( array &$state ) {
		$yesterday = GOAC_Stats::add_days( GOAC_API::today(), -1 );
		if ( (string) $state['maintenance_date'] === $yesterday ) { return; }
		$jobs = array();
		$defs = self::definitions();
		uasort( $defs, static function( $a, $b ) { return (int) $a['priority'] <=> (int) $b['priority']; } );
		foreach ( $defs as $key => $def ) {
			$jobs[] = array( 'id' => 'maintenance:profile:' . $key . ':' . $yesterday, 'type' => 'profile', 'key' => $key, 'start' => $yesterday, 'end' => $yesterday, 'priority' => (int) $def['priority'] );
		}
		$jobs[] = array( 'id' => 'maintenance:page:' . $yesterday, 'type' => 'page_url', 'key' => 'page_url', 'start' => $yesterday, 'end' => $yesterday, 'priority' => 1 );
		usort( $jobs, static function( $a, $b ) { return (int) $a['priority'] <=> (int) $b['priority']; } );
		$state['maintenance_date'] = $yesterday;
		$state['maintenance_queue'] = array_merge( (array) $state['maintenance_queue'], $jobs );
		// Mantém um histórico operacional curto sem deixar wp_options crescer para sempre.
		if ( count( (array) $state['maintenance_done'] ) > 500 ) { $state['maintenance_done'] = array_slice( (array) $state['maintenance_done'], -300, null, true ); }
	}

	public static function state() {
		$state = self::ensure_state();
		$dead = 0;
		foreach ( (array) $state['dead_letter'] as $item ) { if ( 'maintenance_queue' !== ( $item['lane'] ?? 'queue' ) ) { $dead++; } }
		$initial = count( (array) $state['queue'] ) + count( (array) $state['done'] ) + count( (array) $state['unsupported'] ) + $dead;
		$resolved = count( (array) $state['done'] ) + count( (array) $state['unsupported'] ) + $dead;
		$state['total_jobs'] = max( 1, $initial );
		$state['resolved_jobs'] = $resolved;
		$state['progress'] = min( 1, $resolved / max( 1, $initial ) );
		return $state;
	}

	private static function save_state( array $state ) {
		$state['updated_at'] = time();
		update_option( self::STATE_OPTION, $state, false );
		return $state;
	}

	private static function compact_error( $error ) {
		$message = is_wp_error( $error ) ? $error->get_error_message() : (string) $error;
		return function_exists( 'mb_substr' ) ? mb_substr( $message, 0, 500 ) : substr( $message, 0, 500 );
	}

	/** Grava um lote de linhas com UPSERT em blocos, sem encher wp_options. */
	private static function upsert_rows( $report_key, array $dimensions, $day, $bucket, array $rows, $metric_set ) {
		global $wpdb;
		if ( ! $rows ) { return 0; }
		$table = self::table_rows();
		$account = self::account_key();
		$dimension_key = implode( '+', $dimensions );
		$captured = current_time( 'mysql', true );
		$count = 0;
		foreach ( array_chunk( $rows, 150 ) as $chunk ) {
			$values = array(); $args = array();
			foreach ( $chunk as $row ) {
				$dims = (array) ( $row['_dims'] ?? array() );
				$value_text = implode( ' | ', array_values( $dims ) );
				$hash = md5( wp_json_encode( $dims ) );
				$values[] = "(%s,%s,%s,%s,%d,%s,%s,%s,%f,%d,%d,%d,%d,%d,NULLIF(%s,''),NULLIF(%s,''),NULLIF(%s,''),%s,%s)";
				$args = array_merge( $args, array(
					$account, $report_key, $dimension_key, $day, (int) $bucket, $hash, $value_text, wp_json_encode( $dims ),
					(float) ( $row['earnings'] ?? 0 ), (int) round( $row['page_views'] ?? 0 ), (int) round( $row['ad_requests'] ?? 0 ), (int) round( $row['matched_requests'] ?? 0 ), (int) round( $row['impressions'] ?? 0 ), (int) round( $row['clicks'] ?? 0 ),
					null === ( $row['viewability'] ?? null ) ? null : (float) $row['viewability'],
					null === ( $row['measurability'] ?? null ) ? null : (float) $row['measurability'],
					null === ( $row['view_time'] ?? null ) ? null : (float) $row['view_time'],
					(string) $metric_set, $captured,
				) );
			}
			$sql = "INSERT INTO {$table} (account_key,report_key,dimension_key,day,bucket,value_hash,value_text,dimensions_json,earnings,page_views,ad_requests,matched_requests,impressions,clicks,viewability,measurability,view_time,metric_set,captured_at) VALUES " . implode( ',', $values ) . " ON DUPLICATE KEY UPDATE value_text=VALUES(value_text),dimensions_json=VALUES(dimensions_json),earnings=VALUES(earnings),page_views=VALUES(page_views),ad_requests=VALUES(ad_requests),matched_requests=VALUES(matched_requests),impressions=VALUES(impressions),clicks=VALUES(clicks),viewability=VALUES(viewability),measurability=VALUES(measurability),view_time=VALUES(view_time),metric_set=VALUES(metric_set),captured_at=VALUES(captured_at)";
			$wpdb->query( $wpdb->prepare( $sql, $args ) ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
			$count += count( $chunk );
		}
		return $count;
	}

	private static function collect_profile( array $job ) {
		$defs = self::definitions();
		$key = (string) $job['key'];
		if ( empty( $defs[ $key ] ) ) { return new WP_Error( 'goac_learning_definition', 'Definição desconhecida: ' . $key ); }
		$dimensions = (array) $defs[ $key ]['dimensions'];
		$query_dims = array_merge( array( 'DATE' ), $dimensions );
		$result = GOAC_API::breakdown( $query_dims, $job['start'], $job['end'], array( 'limit' => self::REPORT_LIMIT, 'ttl' => 0 ) );
		if ( is_wp_error( $result ) ) { return $result; }
		// Se a API truncou, divide o intervalo e repete depois para não perder cauda longa.
		if ( (int) $result['total_rows'] > count( $result['rows'] ) && $job['start'] < $job['end'] ) {
			$span = GOAC_Stats::days_between( $job['start'], $job['end'] );
			$mid = GOAC_Stats::add_days( $job['start'], (int) floor( $span / 2 ) );
			return array( 'split' => array(
				array_merge( $job, array( 'id' => 'profile:' . $key . ':' . $job['start'] . ':' . $mid, 'start' => $job['start'], 'end' => $mid ) ),
				array_merge( $job, array( 'id' => 'profile:' . $key . ':' . GOAC_Stats::add_days( $mid, 1 ) . ':' . $job['end'], 'start' => GOAC_Stats::add_days( $mid, 1 ), 'end' => $job['end'] ) ),
			) );
		}
		$by_day = array();
		foreach ( (array) $result['rows'] as $row ) {
			$dims = (array) ( $row['dims'] ?? array() );
			$date = (string) ( $dims[0] ?? '' );
			if ( ! GOAC_Stats::valid_date( $date ) ) { continue; }
			$map = array();
			foreach ( $dimensions as $i => $dim ) { $map[ $dim ] = (string) ( $dims[ $i + 1 ] ?? '' ); }
			$row['_dims'] = $map;
			$by_day[ $date ][] = $row;
		}
		$count = 0;
		foreach ( $by_day as $date => $rows ) { $count += self::upsert_rows( $key, $dimensions, $date, 0, $rows, (string) $result['metric_set'] ); }
		return array( 'rows' => $count, 'metric_set' => (string) $result['metric_set'], 'warnings' => $result['warnings'] );
	}

	private static function collect_page_url( array $job ) {
		$result = GOAC_API::page_url_breakdown( $job['start'], $job['end'], array( 'limit' => self::REPORT_LIMIT, 'ttl' => 0 ) );
		if ( is_wp_error( $result ) ) { return $result; }
		$rows = array();
		foreach ( (array) $result['rows'] as $row ) {
			$dims = (array) ( $row['dims'] ?? array() );
			$row['_dims'] = array( 'PAGE_URL' => (string) ( $dims[0] ?? '' ) );
			$rows[] = $row;
		}
		$count = self::upsert_rows( 'page_url', array( 'PAGE_URL' ), $job['start'], 0, $rows, (string) $result['metric_set'] );
		return array( 'rows' => $count, 'metric_set' => (string) $result['metric_set'], 'truncated' => (int) $result['total_rows'] > count( $result['rows'] ) );
	}

	private static function theme_fingerprint( $dir ) {
		if ( ! is_dir( $dir ) ) { return ''; }
		$parts = array(); $count = 0;
		try {
			$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $dir, FilesystemIterator::SKIP_DOTS ) );
			foreach ( $it as $file ) {
				if ( $count >= 2500 || ! $file->isFile() ) { if ( $count >= 2500 ) { break; } continue; }
				$ext = strtolower( (string) pathinfo( $file->getFilename(), PATHINFO_EXTENSION ) );
				if ( ! in_array( $ext, array( 'php','js','css' ), true ) ) { continue; }
				$path = str_replace( '\\', '/', $file->getPathname() );
				$rel = ltrim( str_replace( str_replace( '\\', '/', $dir ), '', $path ), '/' );
				$parts[] = $rel . ':' . $file->getSize() . ':' . $file->getMTime(); $count++;
			}
		} catch ( Exception $e ) { return ''; }
		sort( $parts );
		return hash( 'sha256', implode( "\n", $parts ) );
	}

	private static function environment_snapshot( $theme ) {
		if ( ! function_exists( 'get_plugins' ) ) { require_once ABSPATH . 'wp-admin/includes/plugin.php'; }
		$all = function_exists( 'get_plugins' ) ? get_plugins() : array();
		$active = array();
		foreach ( (array) get_option( 'active_plugins', array() ) as $file ) {
			$data = (array) ( $all[ $file ] ?? array() );
			$active[] = array( 'file' => $file, 'name' => (string) ( $data['Name'] ?? $file ), 'version' => (string) ( $data['Version'] ?? '' ) );
		}
		usort( $active, static function( $a, $b ) { return strcmp( $a['file'], $b['file'] ); } );
		$theme_fp = self::theme_fingerprint( $theme->get_stylesheet_directory() );
		$plugin_fp = hash( 'sha256', wp_json_encode( $active ) );
		return array(
			'site_url' => site_url(), 'home_url' => home_url(), 'wordpress' => get_bloginfo( 'version' ), 'php' => PHP_VERSION,
			'theme' => array( 'name' => $theme->get( 'Name' ), 'version' => $theme->get( 'Version' ), 'stylesheet' => $theme->get_stylesheet(), 'fingerprint' => $theme_fp ),
			'active_plugins' => $active, 'plugins_fingerprint' => $plugin_fp,
			'environment_fingerprint' => hash( 'sha256', $theme_fp . '|' . $plugin_fp ), 'goac_version' => defined( 'GOAC_VERSION' ) ? GOAC_VERSION : '',
		);
	}

	/**
	 * Foto dos recursos da conta para o Mega Relatório (só sob demanda). Usa o cache das listas (15–30 min)
	 * e respeita o limite de tempo; o que não couber mantém a última foto salva.
	 */
	private static function refresh_resources( $budget_seconds = 20.0 ) {
		$map = array( 'account'=>'account', 'child_accounts'=>'child_accounts', 'adclients'=>'adclients', 'sites'=>'sites', 'ad_units'=>'units', 'custom_channels'=>'channels', 'url_channels'=>'url_channels', 'payments'=>'payments', 'policy_issues'=>'policy_issues', 'alerts'=>'alerts', 'saved_reports'=>'saved_reports' );
		$started = microtime( true );
		GOAC_API::begin_budget( $budget_seconds );
		$resources = self::resources();
		foreach ( $map as $key => $method ) {
			if ( microtime( true ) - $started >= (float) $budget_seconds ) { break; }
			$value = call_user_func( array( 'GOAC_API', $method ) );
			if ( is_wp_error( $value ) ) { $resources['errors'][ $key ] = self::safe_value( $value ); continue; }
			if ( isset( $resources[ $key ] ) && $resources[ $key ] !== $value ) {
				self::record_event( 'adsense_resource_change', 'Recurso AdSense atualizado: ' . $key, array( 'resource' => $key ) );
			}
			$resources[ $key ] = $value;
			$resources['updated_at'][ $key ] = time();
			unset( $resources['errors'][ $key ] );
		}
		$resources['environment'] = self::environment_snapshot( wp_get_theme() );
		$resources['captured_at'] = gmdate( 'c' );
		update_option( self::RESOURCE_OPTION, $resources, false );
		return $resources;
	}

	private static function safe_value( $value ) {
		return is_wp_error( $value ) ? array( '_error' => $value->get_error_message(), '_status' => GOAC_API::error_status( $value ) ) : $value;
	}

	/**
	 * Lease atômico do worker. INSERT IGNORE na chave primária de wp_options é a
	 * única operação realmente exclusiva entre processos concorrentes; add_option()
	 * usa ON DUPLICATE KEY UPDATE e sobrescreveria o lease de outro worker. Um lease
	 * vencido (processo morto por timeout/fatal) é removido por compare-and-delete.
	 *
	 * @return string|false Token do lease.
	 */
	public static function acquire_lease( $seconds ) {
		global $wpdb;
		$old = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name=%s", self::LEASE ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		if ( is_string( $old ) && '' !== $old && (int) strtok( $old, ':' ) < time() ) {
			$wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", self::LEASE, $old ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		}
		$token = ( time() + max( 30, (int) $seconds ) ) . ':' . wp_generate_password( 24, false, false );
		$inserted = $wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$wpdb->options} (option_name, option_value, autoload) VALUES (%s, %s, 'no')", self::LEASE, $token ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		wp_cache_delete( self::LEASE, 'options' );
		return 1 === (int) $inserted ? $token : false;
	}

	public static function release_lease( $token ) {
		global $wpdb;
		if ( ! is_string( $token ) || '' === $token ) { return; }
		$wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", self::LEASE, $token ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		wp_cache_delete( self::LEASE, 'options' );
	}

	/** Segundos restantes da pausa por quota (429). 0 = sem pausa. */
	public static function cooldown_remaining() {
		return max( 0, (int) get_option( self::COOLDOWN, 0 ) - time() );
	}

	private static function start_cooldown( $error ) {
		$data = is_wp_error( $error ) ? (array) $error->get_error_data() : array();
		$delay = max( 5 * MINUTE_IN_SECONDS, min( 6 * HOUR_IN_SECONDS, (int) ( $data['retry_after'] ?? 0 ) ) );
		update_option( self::COOLDOWN, time() + $delay, false );
	}

	/**
	 * Processa uma raia da fila sem head-of-line blocking.
	 *
	 * Erros transitórios (429, 5xx, transporte) voltam para o FIM da raia com
	 * backoff exponencial (1, 2, 4, 8 min…) e no máximo MAX_ATTEMPTS tentativas;
	 * depois vão para dead_letter, visível na aba Entrega & Saúde. Erros
	 * permanentes (combinação de dimensão/métrica recusada) continuam como
	 * "unsupported". O job em execução é persistido antes do I/O, então um fatal
	 * no meio da chamada não perde nem duplica trabalho.
	 */
	private static function run_lane( array &$state, $lane, $started, $budget_seconds, $max_jobs, &$processed ) {
		$examined = 0;
		$initial = count( (array) $state[ $lane ] );
		while ( $state[ $lane ] && $examined++ < $initial && $processed < (int) $max_jobs && microtime( true ) - $started < (float) $budget_seconds ) {
			$job = array_shift( $state[ $lane ] );
			if ( ! is_array( $job ) || empty( $job['id'] ) || empty( $job['type'] ) ) { continue; }
			if ( (int) ( $job['next_at'] ?? 0 ) > time() ) { $state[ $lane ][] = $job; continue; }
			if ( (int) ( $job['attempts'] ?? 0 ) >= self::MAX_ATTEMPTS ) {
                $state['dead_letter'][ $job['id'] ] = array( 'at' => time(), 'error' => 'Limite de tentativas após execução interrompida.', 'attempts' => $job['attempts'], 'lane' => $lane, 'job' => array_diff_key( $job, array( 'next_at' => 1, 'attempts' => 1 ) ) );
                continue;
            }
            $job['attempts'] = (int) ( $job['attempts'] ?? 0 ) + 1;
			$inflight = $job; $inflight['next_at'] = time() + 5 * MINUTE_IN_SECONDS;
			$snapshot = $state; $snapshot[ $lane ][] = $inflight; self::save_state( $snapshot );
			try {
				$result = 'page_url' === $job['type'] ? self::collect_page_url( $job ) : self::collect_profile( $job );
			} catch ( Throwable $e ) {
				$result = new WP_Error( 'goac_learning_worker', 'Coleta interrompida: ' . $e->getMessage(), array( 'status' => 0 ) );
			}
			$processed++;
			if ( is_wp_error( $result ) ) {
				$status = GOAC_API::error_status( $result );
				$transient = 429 === $status || $status >= 500 || 0 === $status;
				$message = self::compact_error( $result );
				if ( $transient && $job['attempts'] < self::MAX_ATTEMPTS ) {
					$job['next_at'] = time() + min( HOUR_IN_SECONDS, MINUTE_IN_SECONDS * ( 2 ** ( $job['attempts'] - 1 ) ) );
					$state[ $lane ][] = $job;
					$state['failed'][ $job['id'] ] = array( 'at' => time(), 'error' => $message, 'retry' => true, 'attempts' => $job['attempts'] );
				} elseif ( $transient ) {
					$state['dead_letter'][ $job['id'] ] = array( 'at' => time(), 'error' => $message, 'attempts' => $job['attempts'], 'lane' => $lane, 'job' => array_diff_key( $job, array( 'next_at' => 1, 'attempts' => 1 ) ) );
					unset( $state['failed'][ $job['id'] ] );
				} elseif ( 'queue' === $lane ) {
					$state['unsupported'][ $job['id'] ] = array( 'at' => time(), 'error' => $message );
					unset( $state['failed'][ $job['id'] ] );
				} else {
					$state['maintenance_done'][ $job['id'] ] = array( 'at' => time(), 'unsupported' => true, 'error' => $message );
				}
				if ( 429 === $status ) { self::start_cooldown( $result ); return false; }
			} elseif ( ! empty( $result['split'] ) ) {
				$state[ $lane ] = array_merge( $result['split'], $state[ $lane ] );
				$initial += count( $result['split'] );
			} else {
				$record = array( 'at' => time(), 'rows' => (int) ( $result['rows'] ?? 0 ), 'metric_set' => (string) ( $result['metric_set'] ?? '' ), 'truncated' => ! empty( $result['truncated'] ) );
				if ( 'queue' === $lane ) { $state['done'][ $job['id'] ] = $record; } else { $state['maintenance_done'][ $job['id'] ] = $record; }
				unset( $state['failed'][ $job['id'] ] );
				$state['last_success'] = time();
			}
		}
		return true;
	}

	/** Reenfileira jobs em dead_letter (ação manual do administrador). */
	public static function retry_dead_letters() {
		$lease = self::acquire_lease( 120 );
		if ( ! $lease ) { return false; }
		try {
			$state = self::ensure_state();
			$count = 0;
			foreach ( (array) $state['dead_letter'] as $id => $item ) {
				if ( empty( $item['job'] ) || ! is_array( $item['job'] ) ) { continue; }
				$lane = 'maintenance_queue' === ( $item['lane'] ?? '' ) ? 'maintenance_queue' : 'queue';
				$state[ $lane ][] = $item['job'];
				$count++;
			}
			$state['dead_letter'] = array();
			delete_option( self::COOLDOWN );
			self::save_state( $state );
			return $count;
		} finally {
			self::release_lease( $lease );
		}
	}

	/**
		 * Lote do Data Lab: baseline enriquecido + fechamento D+1 + modelo.
		 * Usado pelo administrador e pelo cron; cada chamada respeita seu orçamento.
	 */
	public static function tick( $budget_seconds = 15.0, $max_jobs = 4 ) {
		if ( ! GOAC_API::is_connected() ) { return new WP_Error( 'goac_not_connected', 'AdSense não conectado.' ); }
		if ( self::cooldown_remaining() > 0 ) { return array( 'cooldown' => self::cooldown_remaining() ) + self::state(); }
		$lease = self::acquire_lease( (int) ceil( (float) $budget_seconds ) + 120 );
		if ( ! $lease ) { return array( 'locked' => true ) + self::state(); }
		try {
			$started = microtime( true );
			GOAC_API::begin_budget( $budget_seconds );
			$state = self::ensure_state();
			if ( self::baseline_empty( $state ) ) {
				$state['queue'] = self::build_queue( $state );
				$state['started_at'] = time();
			}
			self::ensure_maintenance_queue( $state );
			$processed = 0;
			$healthy = self::run_lane( $state, 'queue', $started, $budget_seconds, $max_jobs, $processed );

			// Depois do baseline, fecha o dia anterior em todos os cortes. Mantém a fila separada para não
			// distorcer o % de preparação inicial; jobs do baseline em backoff não bloqueiam a manutenção.
			$baseline_ready = true;
			foreach ( (array) $state['queue'] as $pending ) { if ( (int) ( $pending['next_at'] ?? 0 ) <= time() ) { $baseline_ready = false; break; } }
			if ( $healthy && $baseline_ready ) {
				self::run_lane( $state, 'maintenance_queue', $started, $budget_seconds, $max_jobs, $processed );
			}

			$state['failed'] = array_slice( (array) $state['failed'], -200, null, true );
			$state['dead_letter'] = array_slice( (array) $state['dead_letter'], -200, null, true );
			// O modelo faz 50 agregações no dataset: só recalcula quando o lote trouxe dados (ou ainda não existe).
			if ( ( $processed || empty( $state['last_model_at'] ) ) && microtime( true ) - $started < max( 1, $budget_seconds - 2 ) ) {
				self::rebuild_model();
				$state['last_model_at'] = time();
			}
			self::save_state( $state );
			if ( GOAC_API::today() >= (string) $state['target_date'] && ! self::latest_event( 'baseline_checkpoint' ) ) {
				$resources = self::resources();
				self::record_event( 'baseline_checkpoint', 'Checkpoint automático pré-motor', array( 'target_date' => $state['target_date'], 'readiness' => self::readiness( true ), 'model' => self::model(), 'adsense_controls' => get_option( 'goac_optimization_controls', array() ), 'resources' => $resources, 'environment' => $resources['environment'] ?? array() ) );
			}
		} finally {
			self::release_lease( $lease );
		}
		return self::state();
	}

	/**
	 * Apaga o dataset granular (tabela goac_learning_rows) e zera a fila. Mantém eventos de regime,
	 * histórico diário e configurações. TRUNCATE devolve o espaço em disco de uma vez.
	 */
	public static function purge_dataset() {
		global $wpdb;
		$lease = self::acquire_lease( 120 );
		if ( ! $lease ) { return false; }
		try {
			$table = self::table_rows();
			if ( false === $wpdb->query( "TRUNCATE TABLE {$table}" ) ) { // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery
				$wpdb->query( "DELETE FROM {$table}" ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery
			}
			$state = self::ensure_state();
			foreach ( array( 'queue', 'done', 'failed', 'unsupported', 'dead_letter', 'maintenance_queue', 'maintenance_done' ) as $bucket ) { $state[ $bucket ] = array(); }
			$state['maintenance_date'] = ''; $state['live_cursor'] = 0; $state['last_success'] = 0; $state['started_at'] = time();
			self::save_state( $state );
			set_transient( self::COUNTS, array( 'rows' => 0, 'daily_rows' => 0, 'intraday_rows' => 0, 'page_days' => 0, 'segment_intraday_days' => 0, 'at' => time() ), 12 * HOUR_IN_SECONDS );
			delete_option( self::COOLDOWN );
			self::rebuild_model();
			return true;
		} finally {
			self::release_lease( $lease );
		}
	}

	/** Migração para o modo leve: solta travas e caches da coleta contínua e encolhe o histórico operacional. */
	public static function release_background_work() {
		delete_transient( self::LOCK );
		delete_transient( self::COUNTS );
		$state = get_option( self::STATE_OPTION, array() );
		if ( is_array( $state ) && count( (array) ( $state['maintenance_done'] ?? array() ) ) > 60 ) {
			$state['maintenance_done'] = array_slice( (array) $state['maintenance_done'], -60, null, true );
			update_option( self::STATE_OPTION, $state, false );
		}
	}

	public static function row_count( $bucket_mode = 'all' ) {
		global $wpdb;
		$table = self::table_rows(); $account = self::account_key();
		$where = 'account_key=%s'; $args = array( $account );
		if ( 'daily' === $bucket_mode ) { $where .= ' AND bucket=0'; }
		elseif ( 'intraday' === $bucket_mode ) { $where .= ' AND bucket>0'; }
		return (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM {$table} WHERE {$where}", $args ) ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
	}

	public static function page_days_collected() {
		global $wpdb;
		$table = self::table_rows();
		return (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(DISTINCT day) FROM {$table} WHERE account_key=%s AND report_key='page_url' AND bucket=0", self::account_key() ) ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
	}

	public static function intraday_segment_days() {
		global $wpdb;
		$table = self::table_rows();
		return (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(DISTINCT day) FROM {$table} WHERE account_key=%s AND bucket>0", self::account_key() ) ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
	}

	public static function latest_event( $type = '' ) {
		global $wpdb;
		$table = self::table_events();
		if ( $type ) {
			return $wpdb->get_row( $wpdb->prepare( "SELECT * FROM {$table} WHERE account_key=%s AND event_type=%s ORDER BY event_time DESC,id DESC LIMIT 1", self::account_key(), $type ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
		}
		return $wpdb->get_row( $wpdb->prepare( "SELECT * FROM {$table} WHERE account_key=%s ORDER BY event_time DESC,id DESC LIMIT 1", self::account_key() ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
	}

	public static function events( $limit = 50 ) {
		global $wpdb;
		$table = self::table_events();
		return $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$table} WHERE account_key=%s ORDER BY event_time DESC,id DESC LIMIT %d", self::account_key(), max( 1, min( 500, (int) $limit ) ) ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
	}

	public static function record_event( $type, $label, array $payload = array(), $event_time = '' ) {
		global $wpdb;
		$type = sanitize_key( $type ); $label = sanitize_text_field( $label );
		if ( '' === $event_time ) { $event_time = current_time( 'mysql', true ); }
		$wpdb->insert( self::table_events(), array(
			'account_key' => self::account_key(), 'event_time' => $event_time, 'event_type' => $type, 'label' => $label,
			'payload' => wp_json_encode( $payload ), 'created_by' => get_current_user_id(),
		), array( '%s','%s','%s','%s','%s','%d' ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery
		return (int) $wpdb->insert_id;
	}

	private static function aggregate_period( $from, $to ) {
		$rows = GOAC_Store::range( $from, $to );
		if ( ! $rows ) { return array(); }
		$summary = GOAC_Stats::sum( $rows );
		$rpms = array(); $ir = array(); $cov = array(); $view = array();
		foreach ( $rows as $row ) {
			if ( $row['page_views'] > 0 ) { $rpms[] = $row['earnings'] / $row['page_views'] * 1000; }
			if ( $row['impressions'] > 0 ) { $ir[] = $row['earnings'] / $row['impressions'] * 1000; }
			if ( $row['ad_requests'] > 0 ) { $cov[] = $row['matched_requests'] / $row['ad_requests']; }
			if ( null !== $row['viewability'] ) { $view[] = $row['viewability']; }
		}
		return array(
			'from' => $from, 'to' => $to, 'days' => count( $rows ), 'earnings' => $summary['earnings'], 'page_views' => $summary['page_views'], 'impressions' => $summary['impressions'],
			'page_rpm' => $summary['page_rpm'], 'impression_rpm' => $summary['impression_rpm'], 'coverage' => $summary['coverage'], 'viewability' => $summary['viewability'],
			'aggregation' => 'ratios_of_sums', 'viewability_aggregation' => $summary['viewability_aggregation'] ?? 'unknown',
			'viewability_data_coverage' => $summary['viewability_data_coverage'] ?? null,
			'page_rpm_median' => GOAC_Stats::median( $rpms ), 'impression_rpm_median' => GOAC_Stats::median( $ir ),
			'coverage_median' => GOAC_Stats::median( $cov ), 'viewability_median' => GOAC_Stats::median( $view ),
			'impressions_per_page' => $summary['impressions_per_page'],
		);
	}

	/** Event timestamps are stored in UTC; exclude the mixed launch day locally. */
	public static function regime_dates( array $event, DateTimeZone $timezone ) {
		$value = $event['event_time'] ?? '';
		if ( ! is_string( $value ) || ! preg_match( '/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $value ) ) { return array(); }
		$date = DateTimeImmutable::createFromFormat( '!Y-m-d H:i:s', $value, new DateTimeZone( 'UTC' ) );
		if ( ! $date || $date->format( 'Y-m-d H:i:s' ) !== $value ) { return array(); }
		$local = $date->setTimezone( $timezone );
		$day = $local->format( 'Y-m-d' );
		return array( 'launch_day' => $day, 'first_complete_day' => '00:00:00' === $local->format( 'H:i:s' ) ? $day : GOAC_Stats::add_days( $day, 1 ), 'timezone' => $timezone->getName() );
	}

	/** NULL is unmeasured, never a zero-percent observation. */
	public static function driver_viewability_sql() {
		/* Same-universe AFC/AFV reconstruction from rounded rates; not a native
		 * Google aggregate. Rows without measurability have no usable weight. */
		return 'SUM(CASE WHEN viewability BETWEEN 0 AND 1 AND measurability BETWEEN 0 AND 1 AND impressions>0 THEN viewability*measurability*impressions ELSE 0 END)/NULLIF(SUM(CASE WHEN viewability BETWEEN 0 AND 1 AND measurability BETWEEN 0 AND 1 AND impressions>0 THEN measurability*impressions ELSE 0 END),0)';
	}

	/** Recalibra o modelo explicativo. Não inventa causalidade; guarda drivers e regimes. */
	public static function rebuild_model() {
		global $wpdb;
		$today = GOAC_API::today(); $to = GOAC_Stats::add_days( $today, -1 ); $from = GOAC_Stats::add_days( $to, -89 );
		$model = array(
			'version' => 3, 'trained_at' => gmdate( 'c' ), 'currency' => GOAC_Store::currency(), 'training_window' => array( $from, $to ),
			'baseline_90d' => self::aggregate_period( $from, $to ), 'windows' => array(), 'weekday' => array(), 'intraday_profile' => array(),
			'reference_success' => array(), 'drivers' => array(), 'regime' => array(),
		);
		foreach ( array( 7, 28, 90 ) as $days ) {
			$w_from = GOAC_Stats::add_days( $to, -( $days - 1 ) );
			$model['windows'][ $days . 'd' ] = self::aggregate_period( $w_from, $to );
		}
		// Referência histórica de maior eficiência já definida para o Overdrive; valores são sempre recalculados dos dados locais.
		if ( $to >= '2026-08-19' ) { $model['reference_success'] = self::aggregate_period( '2026-08-13', '2026-08-19' ); }
		$weekday = array_fill( 0, 7, array( 'days' => 0, 'earnings' => 0.0, 'page_views' => 0.0, 'impressions' => 0.0 ) );
		$finals = array();
		foreach ( GOAC_Store::range( $from, $to ) as $date => $row ) {
			$w = (int) ( new DateTimeImmutable( $date, GOAC_API::tz() ) )->format( 'w' );
			$weekday[ $w ]['days']++; $weekday[ $w ]['earnings'] += (float) $row['earnings']; $weekday[ $w ]['page_views'] += (float) $row['page_views']; $weekday[ $w ]['impressions'] += (float) $row['impressions'];
			$finals[ $date ] = (float) $row['earnings'];
		}
		foreach ( $weekday as $w => $x ) {
			$model['weekday'][ $w ] = array(
				'days' => $x['days'], 'avg_earnings' => $x['days'] ? $x['earnings'] / $x['days'] : 0,
				'page_rpm' => $x['page_views'] > 0 ? $x['earnings'] / $x['page_views'] * 1000 : null,
				'impression_rpm' => $x['impressions'] > 0 ? $x['earnings'] / $x['impressions'] * 1000 : null,
			);
		}
		$model['intraday_profile'] = GOAC_Stats::learn_profile( GOAC_Store::intraday(), $finals, $today );
		$table = self::table_rows(); $account = self::account_key();
		$viewability_sql = self::driver_viewability_sql();
		foreach ( self::definitions() as $key => $def ) {
			$sql = "SELECT value_hash,MAX(value_text) value_text,MAX(dimensions_json) dimensions_json,SUM(earnings) earnings,SUM(page_views) page_views,SUM(ad_requests) ad_requests,SUM(matched_requests) matched_requests,SUM(impressions) impressions,SUM(clicks) clicks,{$viewability_sql} viewability FROM {$table} WHERE account_key=%s AND report_key=%s AND bucket=0 AND day BETWEEN %s AND %s GROUP BY value_hash ORDER BY earnings DESC LIMIT 12";
			$rows = $wpdb->get_results( $wpdb->prepare( $sql, $account, $key, $from, $to ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
			$total = (float) $wpdb->get_var( $wpdb->prepare( "SELECT SUM(earnings) FROM {$table} WHERE account_key=%s AND report_key=%s AND bucket=0 AND day BETWEEN %s AND %s", $account, $key, $from, $to ) ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
			$out = array();
			foreach ( $rows as $row ) {
				$imp = (float) $row['impressions']; $req = (float) $row['ad_requests'];
				$out[] = array(
					'value' => (string) $row['value_text'], 'dimensions' => json_decode( (string) $row['dimensions_json'], true ), 'earnings' => (float) $row['earnings'],
					'share' => $total > 0 ? (float) $row['earnings'] / $total : 0, 'impression_rpm' => $imp > 0 ? (float) $row['earnings'] / $imp * 1000 : null,
					'coverage' => $req > 0 ? (float) $row['matched_requests'] / $req : null, 'ctr' => $imp > 0 ? (float) $row['clicks'] / $imp : null,
					'viewability' => null === $row['viewability'] ? null : (float) $row['viewability'],
				);
			}
				$model['drivers'][ $key ] = array( 'label' => $def['label'], 'values' => $out,
					'viewability_aggregation' => 'reconstructed_measurable_impression_weighted_available_rows' );
		}
		$event = self::latest_event( 'engine_launch' );
		$dates = $event ? self::regime_dates( $event, GOAC_API::tz() ) : array();
		if ( $dates ) {
			$start = $dates['first_complete_day'];
			$pre_to = GOAC_Stats::add_days( $dates['launch_day'], -1 ); $pre_from = GOAC_Stats::add_days( $pre_to, -13 );
			$post_to = min( $to, GOAC_Stats::add_days( $start, 13 ) );
			$model['regime'] = array( 'event' => $event, 'dates' => $dates, 'comparison' => 'descriptive_not_causal', 'pre_14d' => self::aggregate_period( $pre_from, $pre_to ), 'post' => $start <= $post_to ? self::aggregate_period( $start, $post_to ) : array() );
		}
		update_option( self::MODEL_OPTION, $model, false );
		return $model;
	}

	public static function model() {
		$model = get_option( self::MODEL_OPTION, array() );
		return is_array( $model ) ? $model : array();
	}

	public static function resources() {
		$r = get_option( self::RESOURCE_OPTION, array() );
		return is_array( $r ) ? $r : array();
	}

	/**
	 * Resumo do Data Lab. Também é lido pelo teste de Saúde do Site do tema, então por padrão não varre a tabela:
	 * as contagens vêm do cache de 12 h. Passe true para calcular quando o cache estiver vazio (aba Data Lab, export).
	 */
	public static function readiness( $with_counts = false ) {
		$state = self::state();
		$meta = GOAC_Store::meta();
		$history_days = $meta['first_day'] ? max( 0, GOAC_Stats::days_between( $meta['first_day'], GOAC_API::today() ) + 1 ) : 0;
		$intraday = GOAC_Store::intraday();
		$truncated = 0;
		foreach ( (array) $state['done'] as $job_id => $job_done ) { if ( 0 === strpos( (string) $job_id, 'page:' ) && ! empty( $job_done['truncated'] ) ) { $truncated++; } }
		foreach ( (array) $state['maintenance_done'] as $job_id => $job_done ) { if ( false !== strpos( (string) $job_id, ':page:' ) && ! empty( $job_done['truncated'] ) ) { $truncated++; } }
		$counts = self::counts( (bool) $with_counts );
		return array(
			'target_date' => (string) $state['target_date'], 'progress' => (float) $state['progress'], 'jobs_done' => (int) $state['resolved_jobs'], 'jobs_total' => (int) $state['total_jobs'],
			'queue' => count( (array) $state['queue'] ), 'unsupported' => count( (array) $state['unsupported'] ), 'history_days' => $history_days,
			'dead_letter' => count( (array) $state['dead_letter'] ), 'retrying' => count( (array) $state['failed'] ), 'last_success' => (int) $state['last_success'], 'cooldown' => self::cooldown_remaining(),
			'page_days' => (int) ( $counts['page_days'] ?? 0 ), 'page_days_truncated' => $truncated, 'intraday_days' => count( $intraday ), 'segment_intraday_days' => (int) ( $counts['segment_intraday_days'] ?? 0 ),
			'maintenance_date' => (string) ( $state['maintenance_date'] ?? '' ), 'maintenance_queue' => count( (array) ( $state['maintenance_queue'] ?? array() ) ), 'maintenance_done' => count( (array) ( $state['maintenance_done'] ?? array() ) ),
			'rows' => (int) ( $counts['rows'] ?? 0 ), 'daily_rows' => (int) ( $counts['daily_rows'] ?? 0 ), 'intraday_rows' => (int) ( $counts['intraday_rows'] ?? 0 ), 'counts_at' => (int) ( $counts['at'] ?? 0 ),
			'updated_at' => (int) $state['updated_at'], 'last_resource_at' => (int) ( $state['last_resource_at'] ?? 0 ), 'last_model_at' => (int) $state['last_model_at'],
		);
	}

	/** Contagens do dataset numa única varredura, guardadas por 12 h (a tabela pode ter milhões de linhas; a tela mostra a hora da contagem). */
	private static function counts( $compute ) {
		$cached = get_transient( self::COUNTS );
		if ( is_array( $cached ) ) { return $cached; }
		if ( ! $compute ) { return array(); }
		global $wpdb;
		$table = self::table_rows();
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT COUNT(*) total, SUM(bucket=0) daily, SUM(bucket>0) intraday, COUNT(DISTINCT CASE WHEN report_key='page_url' AND bucket=0 THEN day END) page_days, COUNT(DISTINCT CASE WHEN bucket>0 THEN day END) segment_days FROM {$table} WHERE account_key=%s", self::account_key() ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery
		$counts = array(
			'rows' => (int) ( $row['total'] ?? 0 ), 'daily_rows' => (int) ( $row['daily'] ?? 0 ), 'intraday_rows' => (int) ( $row['intraday'] ?? 0 ),
			'page_days' => (int) ( $row['page_days'] ?? 0 ), 'segment_intraday_days' => (int) ( $row['segment_days'] ?? 0 ), 'at' => time(),
		);
		set_transient( self::COUNTS, $counts, 12 * HOUR_IN_SECONDS );
		return $counts;
	}

	/* ------------------------------------------------------------ Mega export */

	private static function zip_json( $zip, $name, $data ) {
		$zip->addFromString( $name, wp_json_encode( $data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) );
	}

	private static function temp_csv( $headers, $writer ) {
		$file = wp_tempnam( 'goac-export-' );
		$fh = fopen( $file, 'w' );
		if ( ! $fh ) { return false; }
		fputcsv( $fh, $headers );
		call_user_func( $writer, $fh );
		fclose( $fh );
		return $file;
	}

	private static function zip_file( $zip, $name, $file, array &$temps ) {
		if ( $file && file_exists( $file ) ) { $zip->addFile( $file, $name ); $temps[] = $file; }
	}

	public static function export_mega() {
		if ( ! class_exists( 'ZipArchive' ) ) { wp_die( 'A extensão PHP ZipArchive é necessária para gerar o Mega Relatório.' ); }
		$resources = self::refresh_resources( 20.0 );
		$readiness = self::readiness( true ); $model = self::model();
		$zip_path = wp_tempnam( 'goac-mega-' );
		$zip = new ZipArchive();
		if ( ! $zip_path || true !== $zip->open( $zip_path, ZipArchive::CREATE | ZipArchive::OVERWRITE ) ) { wp_die( 'Não foi possível criar o ZIP temporário.' ); }
		$temps = array();
		$connection = GOAC_API::connection(); unset( $connection['refresh_token'] );
		self::zip_json( $zip, '00-manifest.json', array(
			'generated_at' => gmdate( 'c' ), 'plugin_version' => GOAC_VERSION, 'account' => GOAC_API::account_name(), 'currency' => GOAC_Store::currency(),
			'readiness' => $readiness, 'note' => 'Dataset local do AdSense + recursos atuais + eventos de configuração. Tokens OAuth e segredos nunca são exportados.',
		) );
		self::zip_json( $zip, 'account/connection-redacted.json', $connection );
		self::zip_json( $zip, 'account/resources-snapshot.json', $resources );
		self::zip_json( $zip, 'learning/model.json', $model );
		self::zip_json( $zip, 'learning/dimensions-collected.json', self::definitions() );
		self::zip_json( $zip, 'learning/state.json', self::state() );
		self::zip_json( $zip, 'configuration/adsense-controls.json', get_option( 'goac_optimization_controls', array() ) );
		self::zip_json( $zip, 'finance/distribution-budgets.json', get_option( 'goac_distribution_budgets', array() ) );
		self::zip_json( $zip, 'finance/expenses.json', get_option( 'goac_distribution_expenses', array() ) );
		self::zip_json( $zip, 'finance/goals.json', get_option( 'goac_goals', array() ) );
		self::zip_json( $zip, 'learning/events.json', self::events( 500 ) );

		$meta = GOAC_Store::meta(); $from = (string) $meta['first_day']; $to = GOAC_API::today();
		$daily = self::temp_csv( array( 'date','earnings','page_views','ad_requests','matched_requests','impressions','clicks','viewability','measurability','view_time','page_rpm','impression_rpm','coverage','ctr','impressions_per_page' ), static function( $fh ) use ( $from, $to ) {
			if ( ! $from ) { return; }
			foreach ( GOAC_Store::range( $from, $to ) as $date => $row ) {
				$d = GOAC_Stats::derive( $row );
				fputcsv( $fh, array( $date,$d['earnings'],$d['page_views'],$d['ad_requests'],$d['matched_requests'],$d['impressions'],$d['clicks'],$d['viewability'],$d['measurability'],$d['view_time'],$d['page_rpm'],$d['impression_rpm'],$d['coverage'],$d['ctr'],$d['impressions_per_page'] ) );
			}
		} );
		self::zip_file( $zip, 'reports/daily-history.csv', $daily, $temps );

		$intra = self::temp_csv( array( 'date','minute','time','earnings','page_views','impressions','clicks' ), static function( $fh ) {
			foreach ( GOAC_Store::intraday() as $date => $points ) {
				foreach ( (array) $points as $p ) { $minute = (int) ( $p[0] ?? 0 ); fputcsv( $fh, array( $date,$minute,sprintf( '%02d:%02d', intdiv( $minute, 60 ), $minute % 60 ),$p[1] ?? 0,$p[2] ?? 0,$p[3] ?? 0,$p[4] ?? 0 ) ); }
			}
		} );
		self::zip_file( $zip, 'reports/intraday-total.csv', $intra, $temps );

		global $wpdb;
		$table = self::table_rows(); $account = self::account_key();
		$segments = self::temp_csv( array( 'id','report_key','dimension_key','date','bucket','value','dimensions_json','earnings','page_views','ad_requests','matched_requests','impressions','clicks','viewability','measurability','view_time','metric_set','captured_at' ), static function( $fh ) use ( $wpdb, $table, $account ) {
			$last = 0;
			while ( true ) {
				$rows = $wpdb->get_results( $wpdb->prepare( "SELECT * FROM {$table} WHERE account_key=%s AND id>%d ORDER BY id ASC LIMIT 2000", $account, $last ), ARRAY_A ); // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared,WordPress.DB.DirectDatabaseQuery.DirectQuery
				if ( ! $rows ) { break; }
				foreach ( $rows as $row ) { $last = (int) $row['id']; fputcsv( $fh, array( $row['id'],$row['report_key'],$row['dimension_key'],$row['day'],$row['bucket'],$row['value_text'],$row['dimensions_json'],$row['earnings'],$row['page_views'],$row['ad_requests'],$row['matched_requests'],$row['impressions'],$row['clicks'],$row['viewability'],$row['measurability'],$row['view_time'],$row['metric_set'],$row['captured_at'] ) ); }
			}
		} );
		self::zip_file( $zip, 'reports/segmented-learning-dataset.csv', $segments, $temps );

		$content = self::temp_csv( array( 'post_id','date','type','status','title','url','categories' ), static function( $fh ) {
			$paged = 1;
			do {
				$q = new WP_Query( array( 'post_type' => 'any', 'post_status' => array( 'publish','future','draft','private' ), 'posts_per_page' => 500, 'paged' => $paged, 'fields' => 'ids', 'orderby' => 'ID', 'order' => 'ASC', 'no_found_rows' => true ) );
				foreach ( $q->posts as $id ) {
					$cats = wp_get_post_categories( $id, array( 'fields' => 'names' ) );
					fputcsv( $fh, array( $id, get_post_field( 'post_date', $id ), get_post_type( $id ), get_post_status( $id ), get_the_title( $id ), get_permalink( $id ), implode( ' | ', (array) $cats ) ) );
				}
				$more = count( $q->posts ) === 500; $paged++;
			} while ( $more );
		} );
		self::zip_file( $zip, 'wordpress/content-map.csv', $content, $temps );

		$zip->addFromString( 'README.txt', "GO AdSense Center — Mega Relatório\n\nEste pacote foi gerado em " . gmdate( 'c' ) . ".\nEle contém histórico diário, snapshots intradiários, dataset segmentado, recursos da conta, pagamentos/políticas, configuração manual, eventos de mudança de regime e mapa editorial do WordPress.\n\nA porcentagem de coleta do baseline está em 00-manifest.json. O aprendizado continua depois da data-alvo e novos eventos (como a troca do motor de anúncios) criam novos regimes sem apagar o histórico anterior.\n" );
		$zip->close();

		$filename = 'go-adsense-mega-relatorio-' . gmdate( 'Y-m-d-His' ) . '.zip';
		nocache_headers();
		header( 'Content-Type: application/zip' );
		header( 'Content-Disposition: attachment; filename="' . $filename . '"' );
		header( 'Content-Length: ' . filesize( $zip_path ) );
		readfile( $zip_path ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_read_readfile
		@unlink( $zip_path ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged,WordPress.WP.AlternativeFunctions.unlink_unlink
		foreach ( $temps as $file ) { @unlink( $file ); } // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged,WordPress.WP.AlternativeFunctions.unlink_unlink
		exit;
	}
}
