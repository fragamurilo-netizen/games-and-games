<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

final class GOAC_API {
	const API_BASE = 'https://adsense.googleapis.com';
	const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private static $deadline = 0.0;
    /** A shared request deadline includes token refresh, retries and pagination. */
    public static function begin_budget( $seconds = 12.0 ) {
        $deadline = microtime( true ) + max( 1.0, (float) $seconds );
        self::$deadline = self::$deadline ? min( self::$deadline, $deadline ) : $deadline;
    }
    public static function remaining() {
        if ( ! self::$deadline ) { self::begin_budget(); }
        return max( 0.0, self::$deadline - microtime( true ) );
    }
    private static function transport_guard() {
        if ( self::remaining() < 0.5 ) { return new WP_Error( 'goac_budget', 'Limite de tempo atingido; a coleta continua no próximo ciclo.' ); }
        if ( (int) get_transient( 'goac_api_cooldown' ) > time() ) { return new WP_Error( 'goac_cooldown', 'A API está em pausa após falha temporária; dados salvos continuam disponíveis.' ); }
        return true;
    }
    private static function remember_failure( $response ) {
        $code = is_wp_error( $response ) ? 0 : (int) wp_remote_retrieve_response_code( $response );
        if ( 0 === $code || 429 === $code || $code >= 500 ) {
            $raw = is_wp_error( $response ) ? '' : (string) wp_remote_retrieve_header( $response, 'retry-after' );
            $seconds = is_numeric( $raw ) ? (int) $raw : ( $raw ? max( 0, (int) strtotime( $raw ) - time() ) : 60 );
            $seconds = max( 60, min( HOUR_IN_SECONDS, $seconds ) );
            set_transient( 'goac_api_cooldown', time() + $seconds, $seconds );
        }
    }

	/** Métricas tally/ratio pedidas nos relatórios. Métricas derivadas (RPM, CTR, CPC, cobertura) são calculadas localmente. */
	const DAILY_METRICS = array( 'ESTIMATED_EARNINGS', 'PAGE_VIEWS', 'AD_REQUESTS', 'MATCHED_AD_REQUESTS', 'IMPRESSIONS', 'CLICKS' );
	const VIEW_METRICS = array( 'ACTIVE_VIEW_VIEWABILITY', 'ACTIVE_VIEW_MEASURABILITY', 'ACTIVE_VIEW_TIME' );

	public static function client_id() {
		if ( defined( 'GOAC_GOOGLE_CLIENT_ID' ) && GOAC_GOOGLE_CLIENT_ID ) { return trim( (string) GOAC_GOOGLE_CLIENT_ID ); }
		return trim( (string) get_option( 'goac_client_id', '' ) );
	}

	public static function client_secret() {
		if ( defined( 'GOAC_GOOGLE_CLIENT_SECRET' ) && GOAC_GOOGLE_CLIENT_SECRET ) { return trim( (string) GOAC_GOOGLE_CLIENT_SECRET ); }
		return trim( (string) get_option( 'goac_client_secret', '' ) );
	}

	public static function credentials_locked() {
		return defined( 'GOAC_GOOGLE_CLIENT_ID' ) || defined( 'GOAC_GOOGLE_CLIENT_SECRET' );
	}

	public static function scope() {
		$mode = get_option( 'goac_scope_mode', 'full' );
		return 'readonly' === $mode ? 'https://www.googleapis.com/auth/adsense.readonly' : 'https://www.googleapis.com/auth/adsense';
	}

	public static function redirect_uri() {
		return admin_url( 'admin-post.php?action=goac_oauth_callback' );
	}

	public static function connection() {
		$value = get_option( 'goac_connection', array() );
		return is_array( $value ) ? $value : array();
	}

	public static function is_connected() {
		$c = self::connection();
		return ! empty( $c['refresh_token'] ) && ! empty( $c['account_name'] );
	}

	public static function account_name() {
		$c = self::connection();
		return isset( $c['account_name'] ) ? (string) $c['account_name'] : '';
	}

	/** Limpa caches de consultas. O histórico diário local (GOAC_Store) não é afetado. */
	public static function flush_cache() {
		global $wpdb;
		foreach ( array( 'goac_access_token', 'goac_snapshot_v1', 'goac_account_v1', 'goac_childaccounts_v1', 'goac_adclients_v1', 'goac_sites_v1', 'goac_units_v1', 'goac_channels_v1', 'goac_urlchannels_v1', 'goac_policy_v1', 'goac_payments_v1', 'goac_alerts_v1', 'goac_savedreports_v1' ) as $transient ) {
			delete_transient( $transient );
		}
		// Relatórios e combinações de métricas em cache criados por este plugin.
		foreach ( array( 'goac_report_', 'goac_metricset_' ) as $prefix ) {
			$like1 = $wpdb->esc_like( '_transient_' . $prefix ) . '%';
			$like2 = $wpdb->esc_like( '_transient_timeout_' . $prefix ) . '%';
			$wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s OR option_name LIKE %s", $like1, $like2 ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery
		}
	}

	public static function query_string( $params ) {
		$parts = array();
		foreach ( (array) $params as $key => $value ) {
			$values = is_array( $value ) ? $value : array( $value );
			foreach ( $values as $item ) {
				if ( null === $item || '' === $item ) { continue; }
				$parts[] = rawurlencode( (string) $key ) . '=' . rawurlencode( (string) $item );
			}
		}
		return implode( '&', $parts );
	}

	private static function decode( $response, $context = 'AdSense API' ) {
		if ( is_wp_error( $response ) ) { return $response; }
		$code = (int) wp_remote_retrieve_response_code( $response );
		$body = (string) wp_remote_retrieve_body( $response );
		$data = json_decode( $body, true );
		if ( $code < 200 || $code >= 300 ) {
			$message = is_array( $data ) ? (string) ( $data['error']['message'] ?? $data['error_description'] ?? '' ) : '';
			$status  = is_array( $data ) ? (string) ( $data['error']['status'] ?? '' ) : '';
			if ( '' === $message ) { $message = trim( wp_strip_all_tags( $body ) ); }
			if ( '' === $message ) { $message = sprintf( '%s HTTP %d', $context, $code ); }
			if ( 429 === $code ) { $message = 'Limite de consultas da API do AdSense atingido. Aguarde alguns minutos. (' . $message . ')'; }
			$retry = (string) wp_remote_retrieve_header( $response, 'retry-after' );
			$retry_after = '' === $retry ? 0 : ( is_numeric( $retry ) ? (int) $retry : max( 0, (int) strtotime( $retry ) - time() ) );
			return new WP_Error( 'goac_http_' . $code, $message, array( 'status' => $code, 'google_status' => $status, 'retry_after' => $retry_after, 'body' => $data ) );
		}
		if ( ! is_array( $data ) ) { return new WP_Error( 'goac_invalid_json', 'A API retornou JSON inválido ou incompleto; o histórico foi preservado.' ); }
        return $data;
	}

	public static function error_status( $error ) {
		if ( ! is_wp_error( $error ) ) { return 0; }
		$data = $error->get_error_data();
		return (int) ( is_array( $data ) ? ( $data['status'] ?? 0 ) : 0 );
	}

	public static function token_request( $body ) {
        $guard = self::transport_guard();
        if ( is_wp_error( $guard ) ) { return $guard; }
		$response = wp_remote_post( self::TOKEN_URL, array(
			'timeout' => min( 8.0, self::remaining() ),
            'limit_response_size' => 1048576,
            'redirection' => 0,
			'headers' => array( 'Accept' => 'application/json' ),
			'body'    => $body,
		) );
		self::remember_failure( $response );
        return self::decode( $response, 'OAuth Google' );
	}

	public static function access_token( $force = false ) {
		if ( ! $force ) {
			$cached = get_transient( 'goac_access_token' );
			if ( is_array( $cached ) && ! empty( $cached['token'] ) && (int) ( $cached['expires_at'] ?? 0 ) > time() + 60 ) {
				return (string) $cached['token'];
			}
		}
		$c = self::connection();
		$refresh = trim( (string) ( $c['refresh_token'] ?? '' ) );
		if ( '' === $refresh ) { return new WP_Error( 'goac_not_connected', 'Conecte a conta do Google AdSense primeiro.' ); }
		if ( '' === self::client_id() || '' === self::client_secret() ) { return new WP_Error( 'goac_credentials', 'Client ID e Client Secret não configurados.' ); }
		$data = self::token_request( array(
			'client_id'     => self::client_id(),
			'client_secret' => self::client_secret(),
			'refresh_token' => $refresh,
			'grant_type'    => 'refresh_token',
		) );
		if ( is_wp_error( $data ) ) { return $data; }
		$token = trim( (string) ( $data['access_token'] ?? '' ) );
		if ( '' === $token ) { return new WP_Error( 'goac_token_missing', 'O Google não retornou um access token.' ); }
		$ttl = max( 120, (int) ( $data['expires_in'] ?? 3600 ) - 90 );
		set_transient( 'goac_access_token', array( 'token' => $token, 'expires_at' => time() + $ttl ), $ttl );
		return $token;
	}

	public static function request( $method, $path, $params = array(), $body = null, $retry = true ) {
		$guard = self::transport_guard();
        if ( is_wp_error( $guard ) ) { return $guard; }
        $token = self::access_token();
		if ( is_wp_error( $token ) ) { return $token; }
		$guard = self::transport_guard();
        if ( is_wp_error( $guard ) ) { return $guard; }
        $url = self::API_BASE . $path;
		$query = self::query_string( $params );
		if ( $query ) { $url .= '?' . $query; }
		$args = array(
			'method'  => strtoupper( $method ),
			/* 45 s prendia um worker PHP por quase um minuto quando a API travava. */
			'timeout' => min( 8.0, self::remaining() ),
            'limit_response_size' => 8388608,
            'redirection' => 0,
			'headers' => array(
				'Authorization' => 'Bearer ' . $token,
				'Accept'        => 'application/json',
			),
		);
		if ( null !== $body ) {
			$args['headers']['Content-Type'] = 'application/json; charset=utf-8';
			$args['body'] = wp_json_encode( $body );
		}
		$response = wp_remote_request( $url, $args );
        self::remember_failure( $response );
		if ( ! is_wp_error( $response ) && 401 === (int) wp_remote_retrieve_response_code( $response ) && $retry ) {
			delete_transient( 'goac_access_token' );
			$fresh = self::access_token( true );
			if ( ! is_wp_error( $fresh ) ) { return self::request( $method, $path, $params, $body, false ); }
		}
		return self::decode( $response );
	}

	public static function get( $path, $params = array() ) { return self::request( 'GET', $path, $params ); }
	public static function patch( $path, $params, $body ) { return self::request( 'PATCH', $path, $params, $body ); }
	public static function post( $path, $params, $body ) { return self::request( 'POST', $path, $params, $body ); }

	public static function list_all( $path, $key, $params = array() ) {
		$out = array();
		$page_token = '';
		for ( $page = 0; $page < 10; $page++ ) {
			$args = $params;
			if ( $page_token ) { $args['pageToken'] = $page_token; }
			$data = self::get( $path, $args );
			if ( is_wp_error( $data ) ) { return $data; }
			foreach ( (array) ( $data[ $key ] ?? array() ) as $item ) { if ( is_array( $item ) ) { $out[] = $item; } }
			$page_token = trim( (string) ( $data['nextPageToken'] ?? '' ) );
			if ( '' === $page_token ) { break; }
		}
        if ( $page_token ) { return new WP_Error( 'goac_pagination_limit', 'Lista excedeu o limite desta coleta; resultado parcial não foi salvo.' ); }
		return $out;
	}

	public static function discover_accounts() {
		return self::list_all( '/v2/accounts', 'accounts', array( 'pageSize' => 1000 ) );
	}

	public static function select_account( $account_name, $preserve_refresh = true ) {
		$c = self::connection();
		if ( ! $preserve_refresh ) { $c = array(); }
		$c['account_name'] = sanitize_text_field( $account_name );
		update_option( 'goac_connection', $c, false );
		self::hydrate_connection();
		self::flush_cache();
		return self::connection();
	}

	public static function hydrate_connection() {
		$c = self::connection();
		$account_name = (string) ( $c['account_name'] ?? '' );
		if ( '' === $account_name ) { return new WP_Error( 'goac_account_missing', 'Nenhuma conta AdSense selecionada.' ); }
		$account = self::get( '/v2/' . $account_name );
		if ( is_wp_error( $account ) ) { return $account; }
		$clients = self::list_all( '/v2/' . $account_name . '/adclients', 'adClients', array( 'pageSize' => 1000 ) );
		if ( is_wp_error( $clients ) ) { return $clients; }
		$afc = null;
		foreach ( $clients as $client ) {
			if ( 'AFC' === (string) ( $client['productCode'] ?? '' ) && 'READY' === (string) ( $client['state'] ?? 'READY' ) ) { $afc = $client; break; }
		}
		if ( ! $afc ) {
			foreach ( $clients as $client ) { if ( 'AFC' === (string) ( $client['productCode'] ?? '' ) ) { $afc = $client; break; } }
		}
		$c['display_name']  = (string) ( $account['displayName'] ?? $account_name );
		$c['timezone']      = (string) ( $account['timeZone']['id'] ?? wp_timezone_string() );
		$c['account_state'] = (string) ( $account['state'] ?? '' );
		$c['premium']       = ! empty( $account['premium'] );
		$c['created_at']    = (string) ( $account['createTime'] ?? '' );
		$c['adclient_name'] = $afc ? (string) ( $afc['name'] ?? '' ) : '';
		$c['publisher_id']  = $afc ? (string) ( $afc['reportingDimensionId'] ?? '' ) : '';
		$c['connected_at']  = (int) ( $c['connected_at'] ?? time() );
		update_option( 'goac_connection', $c, false );
		return $c;
	}

	private static function date_params( DateTimeInterface $start, DateTimeInterface $end ) {
		return array(
			'startDate.year' => $start->format( 'Y' ), 'startDate.month' => $start->format( 'n' ), 'startDate.day' => $start->format( 'j' ),
			'endDate.year'   => $end->format( 'Y' ),   'endDate.month'   => $end->format( 'n' ),   'endDate.day'   => $end->format( 'j' ),
		);
	}

	/** Converte a resposta em linhas associativas, incluindo os totais e médias que a API devolve. */
	public static function normalize_report( $data ) {
		$headers = array(); $types = array(); $currency = '';
		foreach ( (array) ( $data['headers'] ?? array() ) as $header ) {
			$name = (string) ( $header['name'] ?? '' );
			$headers[] = $name;
			$types[ $name ] = (string) ( $header['type'] ?? '' );
			if ( ! $currency && ! empty( $header['currencyCode'] ) ) { $currency = (string) $header['currencyCode']; }
		}
		$assoc = static function( $row ) use ( $headers ) {
			$out = array(); $cells = (array) ( $row['cells'] ?? array() );
			foreach ( $headers as $i => $name ) { if ( $name ) { $out[ $name ] = (string) ( $cells[ $i ]['value'] ?? '' ); } }
			return $out;
		};
		$rows = array();
		foreach ( (array) ( $data['rows'] ?? array() ) as $row ) { $rows[] = $assoc( $row ); }
		return array(
			'rows' => $rows, 'headers' => (array) ( $data['headers'] ?? array() ), 'types' => $types, 'currency' => $currency,
			'totals' => isset( $data['totals'] ) ? $assoc( $data['totals'] ) : array(), 'averages' => isset( $data['averages'] ) ? $assoc( $data['averages'] ) : array(),
			'totalMatchedRows' => (int) ( $data['totalMatchedRows'] ?? count( $rows ) ), 'warnings' => (array) ( $data['warnings'] ?? array() ),
			'startDate' => (array) ( $data['startDate'] ?? array() ), 'endDate' => (array) ( $data['endDate'] ?? array() ),
		);
	}

	public static function report_dates( $dimensions, $metrics, DateTimeInterface $start, DateTimeInterface $end, $extra = array(), $cache_ttl = 0 ) {
		$account = self::account_name();
		if ( '' === $account ) { return new WP_Error( 'goac_account_missing', 'Nenhuma conta AdSense selecionada.' ); }
		$params = array_merge( array(
			'dimensions' => array_values( array_filter( array_map( 'strval', (array) $dimensions ) ) ),
			'metrics' => array_values( array_filter( array_map( 'strval', (array) $metrics ) ) ),
			'reportingTimeZone' => (string) ( $extra['reportingTimeZone'] ?? 'ACCOUNT_TIME_ZONE' ),
			'languageCode' => (string) ( $extra['languageCode'] ?? 'pt-BR' ),
		), self::date_params( $start, $end ) );
		foreach ( array( 'filters', 'orderBy' ) as $key ) { if ( ! empty( $extra[ $key ] ) ) { $params[ $key ] = (array) $extra[ $key ]; } }
		foreach ( array( 'limit', 'currencyCode' ) as $key ) { if ( isset( $extra[ $key ] ) && '' !== $extra[ $key ] ) { $params[ $key ] = $extra[ $key ]; } }
		$cache_key = 'goac_report_' . md5( wp_json_encode( array( $account, $params ) ) );
		if ( $cache_ttl > 0 ) {
			$cached = get_transient( $cache_key );
			if ( is_array( $cached ) ) { return $cached; }
		}
		$data = self::get( '/v2/' . $account . '/reports:generate', $params );
		if ( is_wp_error( $data ) ) { return $data; }
		$out = self::normalize_report( $data );
		if ( $cache_ttl > 0 ) { set_transient( $cache_key, $out, $cache_ttl ); }
		return $out;
	}

	public static function tz() {
		$c = self::connection();
		$id = (string) ( $c['timezone'] ?? '' );
		try { return new DateTimeZone( $id ?: wp_timezone_string() ?: 'UTC' ); }
		catch ( Exception $e ) { return wp_timezone(); }
	}

	public static function today() {
		return ( new DateTimeImmutable( 'now', self::tz() ) )->format( 'Y-m-d' );
	}

	public static function metric( $row, $key, $default = 0.0 ) {
		if ( ! is_array( $row ) || ! array_key_exists( $key, $row ) || ! is_numeric( $row[ $key ] ) ) { return $default; }
		return (float) $row[ $key ];
	}

	/** Cache conforme a idade dos dados: com hoje 5 min, com ontem/anteontem 15 min, só passado 3 h. */
	public static function report_ttl( $end_date ) {
		$today = self::today();
		if ( $end_date >= $today ) { return 5 * MINUTE_IN_SECONDS; }
		if ( $end_date >= GOAC_Stats::add_days( $today, -2 ) ) { return 15 * MINUTE_IN_SECONDS; }
		return 3 * HOUR_IN_SECONDS;
	}

	private static function row_from_report( array $row, array $types ) {
		$has = static function( $key ) use ( $row ) { return array_key_exists( $key, $row ) && is_numeric( $row[ $key ] ); };
		$view_time = $has( 'ACTIVE_VIEW_TIME' ) ? (float) $row['ACTIVE_VIEW_TIME'] : null;
		if ( null !== $view_time && 'METRIC_MILLISECONDS' === ( $types['ACTIVE_VIEW_TIME'] ?? '' ) ) { $view_time /= 1000; }
		return array(
			'earnings' => self::metric( $row, 'ESTIMATED_EARNINGS' ), 'page_views' => self::metric( $row, 'PAGE_VIEWS' ),
			'ad_requests' => self::metric( $row, 'AD_REQUESTS' ), 'matched_requests' => self::metric( $row, 'MATCHED_AD_REQUESTS' ),
			'impressions' => self::metric( $row, 'IMPRESSIONS' ), 'clicks' => self::metric( $row, 'CLICKS' ),
			'viewability' => $has( 'ACTIVE_VIEW_VIEWABILITY' ) ? (float) $row['ACTIVE_VIEW_VIEWABILITY'] : null,
			'measurability' => $has( 'ACTIVE_VIEW_MEASURABILITY' ) ? (float) $row['ACTIVE_VIEW_MEASURABILITY'] : null,
			'view_time' => $view_time,
		);
	}

	/**
	 * Relatório por DATE para alimentar o histórico local. Se a combinação completa for recusada (HTTP 400),
	 * repete só com as métricas principais e busca Active View à parte, sem falhar por causa dele.
	 */
	public static function daily_report( DateTimeInterface $start, DateTimeInterface $end, $currency = '' ) {
		$extra = array( 'orderBy' => array( '+DATE' ), 'limit' => 5000 );
		if ( '' !== (string) $currency ) {
			// Receita convertida pelo próprio Google (taxa de cada dia), para exibir em outra moeda.
			$extra['currencyCode'] = strtoupper( (string) $currency );
			$fx = self::report_dates( array( 'DATE' ), array( 'ESTIMATED_EARNINGS' ), $start, $end, $extra );
			if ( is_wp_error( $fx ) ) { return $fx; }
			$rows = array();
			foreach ( (array) $fx['rows'] as $row ) {
				$date = (string) ( $row['DATE'] ?? '' );
				if ( GOAC_Stats::valid_date( $date ) ) { $rows[ $date ] = self::metric( $row, 'ESTIMATED_EARNINGS' ); }
			}
			return array( 'rows' => $rows, 'currency' => (string) ( $fx['currency'] ?: $extra['currencyCode'] ) );
		}
		$r = self::report_dates( array( 'DATE' ), array_merge( self::DAILY_METRICS, self::VIEW_METRICS ), $start, $end, $extra );
		$view = null;
		if ( is_wp_error( $r ) ) {
			if ( 400 !== self::error_status( $r ) ) { return $r; }
			$r = self::report_dates( array( 'DATE' ), self::DAILY_METRICS, $start, $end, $extra );
			if ( is_wp_error( $r ) ) { return $r; }
			$v = self::report_dates( array( 'DATE' ), self::VIEW_METRICS, $start, $end, $extra );
			if ( ! is_wp_error( $v ) ) { $view = $v; }
		}
		$out = array();
		foreach ( (array) $r['rows'] as $row ) {
			$date = (string) ( $row['DATE'] ?? '' );
			if ( GOAC_Stats::valid_date( $date ) ) { $out[ $date ] = $row; }
		}
		if ( $view ) {
			foreach ( (array) $view['rows'] as $row ) {
				$date = (string) ( $row['DATE'] ?? '' );
				if ( isset( $out[ $date ] ) ) { $out[ $date ] = array_merge( $out[ $date ], $row ); }
			}
		}
		$types = array_merge( (array) ( $view['types'] ?? array() ), (array) $r['types'] );
		foreach ( $out as $date => $row ) { $out[ $date ] = self::row_from_report( $row, $types ); }
		return array( 'rows' => $out, 'currency' => (string) $r['currency'] );
	}

	/**
	 * Quebra por dimensões com totais/médias. Algumas métricas não combinam com certas dimensões
	 * (ex.: PAGE_VIEWS por unidade); em HTTP 400 tenta conjuntos menores e memoriza o que funcionou.
	 */
	public static function breakdown( $dimensions, $start, $end, $opts = array() ) {
		$dimensions = array_values( array_filter( (array) $dimensions ) );
		$sets = array(
			'full'     => array_merge( self::DAILY_METRICS, self::VIEW_METRICS ),
			'core'     => self::DAILY_METRICS,
			'no_pages' => array( 'ESTIMATED_EARNINGS', 'AD_REQUESTS', 'MATCHED_AD_REQUESTS', 'IMPRESSIONS', 'CLICKS', 'ACTIVE_VIEW_VIEWABILITY', 'ACTIVE_VIEW_MEASURABILITY' ),
			'minimal'  => array( 'ESTIMATED_EARNINGS', 'IMPRESSIONS', 'CLICKS' ),
			'earnings' => array( 'ESTIMATED_EARNINGS' ),
		);
		$memo_key = 'goac_metricset_' . md5( implode( ',', $dimensions ) );
		$known = get_transient( $memo_key );
		$order = array_keys( $sets );
		if ( is_string( $known ) && isset( $sets[ $known ] ) ) { $order = array_slice( $order, (int) array_search( $known, $order, true ) ); }
		$tz = self::tz();
		$s = new DateTimeImmutable( $start, $tz ); $e = new DateTimeImmutable( $end, $tz );
		$extra = array(
			'orderBy' => (array) ( $opts['orderBy'] ?? array( '-ESTIMATED_EARNINGS' ) ),
			'limit' => max( 1, min( 100000, (int) ( $opts['limit'] ?? 500 ) ) ),
			'filters' => (array) ( $opts['filters'] ?? array() ),
		);
		if ( ! empty( $opts['currency'] ) ) { $extra['currencyCode'] = strtoupper( (string) $opts['currency'] ); }
		$ttl = isset( $opts['ttl'] ) ? (int) $opts['ttl'] : self::report_ttl( $end );
		$last_error = null;
		foreach ( $order as $set ) {
			$r = self::report_dates( $dimensions, $sets[ $set ], $s, $e, $extra, $ttl );
			if ( ! is_wp_error( $r ) ) {
				if ( $set !== $known ) { set_transient( $memo_key, $set, 7 * DAY_IN_SECONDS ); }
				$rows = array();
				foreach ( $r['rows'] as $row ) { $rows[] = array( 'dims' => array_map( static function( $d ) use ( $row ) { return (string) ( $row[ $d ] ?? '' ); }, $dimensions ) ) + GOAC_Stats::derive( self::row_from_report( $row, $r['types'] ) ); }
				return array(
					'rows' => $rows, 'dimensions' => $dimensions, 'metric_set' => $set, 'metrics' => $sets[ $set ], 'currency' => $r['currency'],
					'totals' => $r['totals'] ? GOAC_Stats::derive( self::row_from_report( $r['totals'], $r['types'] ) ) : GOAC_Stats::sum( $rows ),
					'total_rows' => $r['totalMatchedRows'], 'warnings' => $r['warnings'],
				);
			}
			$last_error = $r;
			if ( 400 !== self::error_status( $r ) ) { break; }
		}
		return $last_error ? $last_error : new WP_Error( 'goac_report', 'Não foi possível gerar o relatório.' );
	}

	/**
	 * Relatório por URL de página com combinação conservadora de métricas.
	 * PAGE_URL é uma dimensão especial no AdSense e não deve ser combinada com
	 * filtros/dimensões adicionais desnecessários. Primeiro tenta receita + PV;
	 * se a conta rejeitar a combinação, preserva o ranking com receita apenas.
	 */
	public static function page_url_breakdown( $start, $end, $opts = array() ) {
		$tz = self::tz();
		$s = new DateTimeImmutable( $start, $tz ); $e = new DateTimeImmutable( $end, $tz );
		$limit = max( 1, min( 100000, (int) ( $opts['limit'] ?? 10000 ) ) );
		$ttl = isset( $opts['ttl'] ) ? (int) $opts['ttl'] : self::report_ttl( $end );
		$base = array( 'orderBy' => array( '-ESTIMATED_EARNINGS' ), 'limit' => $limit );
		if ( ! empty( $opts['currency'] ) ) { $base['currencyCode'] = strtoupper( (string) $opts['currency'] ); }
		$sets = array(
			'earnings_pages' => array( 'ESTIMATED_EARNINGS', 'PAGE_VIEWS' ),
			'earnings'       => array( 'ESTIMATED_EARNINGS' ),
		);
		$last_error = null;
		foreach ( $sets as $set => $metrics ) {
			$r = self::report_dates( array( 'PAGE_URL' ), $metrics, $s, $e, $base, $ttl );
			if ( ! is_wp_error( $r ) ) {
				$rows = array();
				foreach ( $r['rows'] as $row ) {
					$rows[] = array( 'dims' => array( (string) ( $row['PAGE_URL'] ?? '' ) ) ) + GOAC_Stats::derive( self::row_from_report( $row, $r['types'] ) );
				}
				return array(
					'rows' => $rows, 'dimensions' => array( 'PAGE_URL' ), 'metric_set' => $set, 'metrics' => $metrics, 'currency' => $r['currency'],
					'totals' => $r['totals'] ? GOAC_Stats::derive( self::row_from_report( $r['totals'], $r['types'] ) ) : GOAC_Stats::sum( $rows ),
					'total_rows' => $r['totalMatchedRows'], 'warnings' => $r['warnings'],
				);
			}
			$last_error = $r;
			if ( 400 !== self::error_status( $r ) ) { break; }
		}
		return $last_error ? $last_error : new WP_Error( 'goac_page_url_report', 'Não foi possível gerar o relatório por URL.' );
	}

	/** Escapa um valor para o parâmetro filters da API (barra invertida antes de vírgula). */
	public static function filter_value( $value ) {
		return str_replace( array( '\\', ',' ), array( '\\\\', '\\,' ), (string) $value );
	}

	/** Mantido por compatibilidade: agora "snapshot" é a sincronização do histórico recente. */
	public static function snapshot( $force = false ) {
		$result = GOAC_Store::sync_recent( $force ? 0 : 4 * MINUTE_IN_SECONDS, $force );
		return is_wp_error( $result ) ? $result : GOAC_Store::meta();
	}

	public static function account( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_account_v1' ); if ( is_array( $c ) ) { return $c; } }
		$data = self::get( '/v2/' . self::account_name() );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_account_v1', $data, 15 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function child_accounts( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_childaccounts_v1' ); if ( is_array( $c ) ) { return $c; } }
		$data = self::list_all( '/v2/' . self::account_name() . ':listChildAccounts', 'accounts', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_childaccounts_v1', $data, 30 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function adclients( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_adclients_v1' ); if ( is_array( $c ) ) { return $c; } }
		$data = self::list_all( '/v2/' . self::account_name() . '/adclients', 'adClients', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_adclients_v1', $data, 15 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function sites( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_sites_v1' ); if ( is_array( $c ) ) { return $c; } }
		$data = self::list_all( '/v2/' . self::account_name() . '/sites', 'sites', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_sites_v1', $data, 15 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function policy_issues( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_policy_v1' ); if ( is_array( $c ) ) { return $c; } }
		$data = self::list_all( '/v2/' . self::account_name() . '/policyIssues', 'policyIssues', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_policy_v1', $data, 15 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function alerts( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_alerts_v1' ); if ( is_array( $c ) ) { return $c; } }
		// alerts.list supports languageCode, but no pageSize or pageToken.
		$data = self::get( '/v2/' . self::account_name() . '/alerts', array( 'languageCode' => 'pt-BR' ) );
		if ( is_wp_error( $data ) ) { return $data; }
		$alerts = (array) ( $data['alerts'] ?? array() );
		set_transient( 'goac_alerts_v1', $alerts, 15 * MINUTE_IN_SECONDS );
		return $alerts;
	}

	public static function payments( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_payments_v1' ); if ( is_array( $c ) ) { return $c; } }
		// payments.list has no query parameters and returns the complete list.
		$data = self::get( '/v2/' . self::account_name() . '/payments' );
		if ( is_wp_error( $data ) ) { return $data; }
		$payments = (array) ( $data['payments'] ?? array() );
		set_transient( 'goac_payments_v1', $payments, 30 * MINUTE_IN_SECONDS );
		return $payments;
	}

	/**
	 * Converte o valor formatado de um pagamento ("R$ 1.234,56", "$1,234.57", "¥1,235 JPY") em número.
	 * O último separador seguido de 1–2 dígitos é o decimal; os demais são de milhar.
	 */
	public static function parse_amount( $text ) {
		$text = (string) $text;
		$negative = false !== strpos( $text, '-' ) || false !== strpos( $text, '−' );
		$clean = preg_replace( '/[^\d.,]/', '', $text );
		if ( '' === $clean || ! preg_match( '/\d/', $clean ) ) { return null; }
		$last = max( (int) strrpos( $clean, ',' ), (int) strrpos( $clean, '.' ) );
		$has_sep = false !== strpos( $clean, ',' ) || false !== strpos( $clean, '.' );
		if ( $has_sep && preg_match( '/^\d{1,2}$/', substr( $clean, $last + 1 ) ) ) {
			$number = preg_replace( '/[.,]/', '', substr( $clean, 0, $last ) ) . '.' . substr( $clean, $last + 1 );
		} else {
			$number = preg_replace( '/[.,]/', '', $clean );
		}
		$value = (float) $number;
		return $negative ? -$value : $value;
	}

	public static function units( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_units_v1' ); if ( is_array( $c ) ) { return $c; } }
		$conn = self::connection(); $adclient = (string) ( $conn['adclient_name'] ?? '' );
		if ( '' === $adclient ) { return new WP_Error( 'goac_no_afc', 'Nenhum AdSense for Content (AFC) disponível nesta conta.' ); }
		$data = self::list_all( '/v2/' . $adclient . '/adunits', 'adUnits', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) {
			set_transient( 'goac_units_v1', $data, 15 * MINUTE_IN_SECONDS );
			self::publish_unit_contract( $data, $adclient );
		}
		return $data;
	}

	/**
	 * Publica o contrato das unidades para a entrega do tema (slot => estado/tamanho).
	 * O tema deixa de solicitar slots não ACTIVE e respeita unidades de tamanho fixo.
	 * Pequeno e autoload: é lido uma vez por requisição pública, sem consulta extra.
	 */
	private static function publish_unit_contract( array $units, $adclient ) {
		$map = array();
		foreach ( $units as $unit ) {
			if ( ! is_array( $unit ) || ! preg_match( '/(\d{6,})$/', (string) ( $unit['name'] ?? '' ), $m ) ) { continue; }
			$map[ $m[1] ] = array(
				'state' => strtoupper( (string) ( $unit['state'] ?? '' ) ),
				'size'  => (string) ( $unit['contentAdsSettings']['size'] ?? '' ),
				'type'  => (string) ( $unit['contentAdsSettings']['type'] ?? '' ),
			);
		}
		if ( ! $map ) { return; }
		$publisher = preg_match( '#(ca-pub-\d+)$#', (string) $adclient, $p ) ? $p[1] : '';
		$previous = get_option( 'goac_unit_contract', array() );
		$next = array( 'publisher' => $publisher, 'units' => $map, 'updated_at' => time() );
		if ( is_array( $previous ) && ( $previous['units'] ?? null ) === $map && (int) ( $previous['updated_at'] ?? 0 ) > time() - DAY_IN_SECONDS ) { return; }
		update_option( 'goac_unit_contract', $next, true );
	}

	public static function channels( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_channels_v1' ); if ( is_array( $c ) ) { return $c; } }
		$conn = self::connection(); $adclient = (string) ( $conn['adclient_name'] ?? '' );
		if ( '' === $adclient ) { return new WP_Error( 'goac_no_afc', 'Nenhum AdSense for Content (AFC) disponível nesta conta.' ); }
		$data = self::list_all( '/v2/' . $adclient . '/customchannels', 'customChannels', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_channels_v1', $data, 15 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function url_channels( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_urlchannels_v1' ); if ( is_array( $c ) ) { return $c; } }
		$conn = self::connection(); $adclient = (string) ( $conn['adclient_name'] ?? '' );
		if ( '' === $adclient ) { return new WP_Error( 'goac_no_afc', 'Nenhum AdSense for Content (AFC) disponível nesta conta.' ); }
		$data = self::list_all( '/v2/' . $adclient . '/urlchannels', 'urlChannels', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_urlchannels_v1', $data, 15 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function saved_reports( $force = false ) {
		if ( ! $force ) { $c = get_transient( 'goac_savedreports_v1' ); if ( is_array( $c ) ) { return $c; } }
		$data = self::list_all( '/v2/' . self::account_name() . '/reports/saved', 'savedReports', array( 'pageSize' => 1000 ) );
		if ( ! is_wp_error( $data ) ) { set_transient( 'goac_savedreports_v1', $data, 30 * MINUTE_IN_SECONDS ); }
		return $data;
	}

	public static function patch_unit( $name, $display_name, $state ) {
		$allowed_state = array( 'ACTIVE', 'ARCHIVED' );
		$body = array( 'name' => $name ); $mask = array();
		if ( '' !== $display_name ) { $body['displayName'] = $display_name; $mask[] = 'displayName'; }
		if ( in_array( $state, $allowed_state, true ) ) { $body['state'] = $state; $mask[] = 'state'; }
		if ( ! $mask ) { return new WP_Error( 'goac_no_changes', 'Nenhuma alteração válida foi informada.' ); }
		$result = self::patch( '/v2/' . ltrim( $name, '/' ), array( 'updateMask' => implode( ',', $mask ) ), $body );
		if ( ! is_wp_error( $result ) ) { self::flush_cache(); }
		return $result;
	}

	public static function create_display_unit( $display_name, $size = '1x3' ) {
		$conn = self::connection(); $adclient = (string) ( $conn['adclient_name'] ?? '' );
		if ( '' === $adclient ) { return new WP_Error( 'goac_no_afc', 'Nenhum cliente AFC disponível.' ); }
		$body = array( 'displayName' => $display_name, 'state' => 'ACTIVE', 'contentAdsSettings' => array( 'size' => $size, 'type' => 'DISPLAY' ) );
		$result = self::post( '/v2/' . $adclient . '/adunits', array(), $body );
		if ( ! is_wp_error( $result ) ) { self::flush_cache(); }
		return $result;
	}

	public static function patch_channel( $name, $display_name, $active = null ) {
		$body = array( 'name' => $name ); $mask = array();
		if ( '' !== $display_name ) { $body['displayName'] = $display_name; $mask[] = 'displayName'; }
		if ( null !== $active ) { $body['active'] = (bool) $active; $mask[] = 'active'; }
		if ( ! $mask ) { return new WP_Error( 'goac_no_changes', 'Nenhuma alteração válida foi informada.' ); }
		$result = self::patch( '/v2/' . ltrim( $name, '/' ), array( 'updateMask' => implode( ',', $mask ) ), $body );
		if ( ! is_wp_error( $result ) ) { self::flush_cache(); }
		return $result;
	}

	public static function create_channel( $display_name, $active = true ) {
		$conn = self::connection(); $adclient = (string) ( $conn['adclient_name'] ?? '' );
		if ( '' === $adclient ) { return new WP_Error( 'goac_no_afc', 'Nenhum cliente AFC disponível.' ); }
		$result = self::post( '/v2/' . $adclient . '/customchannels', array(), array( 'displayName' => $display_name, 'active' => (bool) $active ) );
		if ( ! is_wp_error( $result ) ) { self::flush_cache(); }
		return $result;
	}
}
