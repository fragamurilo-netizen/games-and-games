<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Histórico diário local do AdSense.
 * Cada ano fica numa opção própria (goac_days_YYYY, sem autoload): gravações pequenas, leitura instantânea
 * e estatísticas sem gastar cota da API. A sincronização regrava sempre desde o 1º dia do mês anterior,
 * cobrindo os ajustes que o Google faz até fechar o mês.
 *
 * Moeda: as métricas ficam na moeda da conta. Para exibir em outra moeda (ex.: dólar ⇄ real) guardamos só a
 * receita convertida pelo próprio Google (goac_fx_USD_YYYY), dia a dia; RPM e CPC são recalculados a partir dela.
 */
final class GOAC_Store {
	const META = 'goac_store_meta';
	const BACKFILL = 'goac_backfill';
	const YEAR_PREFIX = 'goac_days_';
	const FX_PREFIX = 'goac_fx_';
	const INTRADAY_TODAY = 'goac_intraday_today';
	const INTRADAY_HIST = 'goac_intraday_hist';
	const KEYS = array( 'earnings' => 'e', 'page_views' => 'pv', 'ad_requests' => 'rq', 'matched_requests' => 'mr', 'impressions' => 'im', 'clicks' => 'cl', 'viewability' => 'vw', 'measurability' => 'ms', 'view_time' => 'vt' );
	const CURRENCIES = array( 'BRL', 'USD' );

	private static $years = array();
	private static $fx = array();

	/* ------------------------------------------------------------------ Metadados */

	public static function meta() {
		$m = get_option( self::META, array() );
		return array_merge( array( 'account' => '', 'currency' => '', 'years' => array(), 'first_day' => '', 'last_day' => '', 'synced_at' => 0, 'last_error' => '', 'last_error_at' => 0, 'fx_years' => array(), 'fx_complete' => array(), 'fx_rate' => array(), 'fx_error' => '' ), is_array( $m ) ? $m : array() );
	}

	/** Relê a opção direto do banco antes de alterar, para não sobrescrever gravações concorrentes (cron x painel). */
	private static function update_meta( array $changes ) {
		wp_cache_delete( self::META, 'options' );
		$meta = array_merge( self::meta(), $changes );
		update_option( self::META, $meta, false );
		return $meta;
	}

	public static function backfill_status() {
		$b = get_option( self::BACKFILL, array() );
		return array_merge( array( 'state' => 'idle', 'next_year' => 0, 'done_years' => array(), 'empty_streak' => 0, 'started_at' => 0, 'finished_at' => 0, 'error' => '', 'note' => '', 'max_years' => self::max_years(), 'fx' => array() ), is_array( $b ) ? $b : array() );
	}

	public static function max_years() { return max( 1, min( 20, (int) get_option( 'goac_history_years', 10 ) ) ); }

	public static function has_data() { $m = self::meta(); return '' !== $m['first_day']; }

	/** Moeda em que o AdSense registra a conta (vem dos cabeçalhos dos relatórios). */
	public static function currency() { return strtoupper( (string) self::meta()['currency'] ); }

	public static function currencies() {
		return array_values( array_unique( array_filter( array_merge( array( self::currency() ), self::CURRENCIES ) ) ) );
	}

	/** Moeda escolhida para exibição; sem escolha válida, a da conta. */
	public static function display_currency() {
		$account = self::currency();
		$chosen = strtoupper( (string) get_option( 'goac_display_currency', '' ) );
		return $chosen && in_array( $chosen, self::currencies(), true ) ? $chosen : $account;
	}

	public static function converting() {
		$account = self::currency();
		return '' !== $account && self::display_currency() !== $account;
	}

	/** Se a conta conectada mudou, o histórico local pertence a outra conta e é descartado. */
	public static function ensure_account() {
		$account = GOAC_API::account_name();
		$meta = self::meta();
		if ( $account && $meta['account'] && $meta['account'] !== $account ) { self::reset(); $meta = self::meta(); }
		if ( $account && ! $meta['account'] ) { $meta = self::update_meta( array( 'account' => $account ) ); }
		return $meta;
	}

	public static function reset() {
		$meta = self::meta();
		$now = (int) gmdate( 'Y' );
		$years = array_unique( array_merge( array_map( 'intval', (array) $meta['years'] ), range( $now - 1, $now + 1 ), array_map( 'intval', (array) self::backfill_status()['done_years'] ) ) );
		foreach ( $years as $y ) { delete_option( self::YEAR_PREFIX . $y ); }
		foreach ( array_merge( (array) $meta['fx_years'], (array) $meta['fx_complete'] ) as $cur => $list ) {
			foreach ( array_unique( array_merge( array_map( 'intval', (array) $list ), range( $now - 1, $now ) ) ) as $y ) { delete_option( self::FX_PREFIX . sanitize_key( $cur ) . '_' . $y ); }
		}
		foreach ( array( self::META, self::BACKFILL, self::INTRADAY_TODAY, self::INTRADAY_HIST ) as $option ) { delete_option( $option ); }
		self::$years = array(); self::$fx = array();
	}

	/* ------------------------------------------------------------------ Linhas */

	private static function compact( array $row ) {
		$out = array();
		foreach ( self::KEYS as $long => $short ) {
			if ( ! array_key_exists( $long, $row ) || null === $row[ $long ] || ! is_numeric( $row[ $long ] ) ) { continue; }
			$v = (float) $row[ $long ];
			$out[ $short ] = in_array( $long, array( 'earnings', 'viewability', 'measurability', 'view_time' ), true ) ? round( $v, 6 ) : (int) round( $v );
		}
		return $out;
	}

	private static function expand( array $c ) {
		$row = GOAC_Stats::empty_row();
		foreach ( self::KEYS as $long => $short ) { if ( isset( $c[ $short ] ) ) { $row[ $long ] = (float) $c[ $short ]; } }
		return $row;
	}

	private static function year( $year ) {
		$year = (int) $year;
		if ( ! isset( self::$years[ $year ] ) ) {
			$raw = get_option( self::YEAR_PREFIX . $year, array() );
			self::$years[ $year ] = is_array( $raw ) ? $raw : array();
		}
		return self::$years[ $year ];
	}

	/** Grava linhas date => métricas, agrupadas por ano. */
	public static function put_rows( array $rows ) {
		$by_year = array();
		foreach ( $rows as $date => $row ) {
			if ( ! GOAC_Stats::valid_date( (string) $date ) || ! is_array( $row ) ) { continue; }
			$by_year[ (int) substr( $date, 0, 4 ) ][ $date ] = self::compact( $row );
		}
		if ( ! $by_year ) { return; }
		foreach ( $by_year as $y => $list ) {
			wp_cache_delete( self::YEAR_PREFIX . $y, 'options' );
			unset( self::$years[ $y ] );
			$data = self::year( $y );
			foreach ( $list as $date => $c ) { $data[ $date ] = $c; }
			ksort( $data );
			self::$years[ $y ] = $data;
			update_option( self::YEAR_PREFIX . $y, $data, false );
		}
		wp_cache_delete( self::META, 'options' );
		$meta = self::meta();
		$years = array_values( array_unique( array_map( 'intval', array_merge( (array) $meta['years'], array_keys( $by_year ) ) ) ) );
		sort( $years );
		$first = ''; $last = '';
		foreach ( $years as $y ) {
			foreach ( self::year( $y ) as $date => $c ) {
				if ( ! empty( $c['e'] ) || ! empty( $c['pv'] ) || ! empty( $c['rq'] ) ) { $first = (string) $date; break 2; }
			}
		}
		foreach ( array_reverse( $years ) as $y ) {
			$data = self::year( $y );
			if ( $data ) { $keys = array_keys( $data ); $last = (string) end( $keys ); break; }
		}
		self::update_meta( array( 'years' => $years, 'first_day' => $first, 'last_day' => $last ) );
	}

	/**
	 * Linhas de um intervalo, em ordem e na moeda da conta. Dias sem linha entre o primeiro e o último dia
	 * sincronizados viram zero (a API omite dias sem atividade); fora disso não há dados.
	 */
	public static function range( $from, $to ) {
		$out = array();
		if ( ! GOAC_Stats::valid_date( $from ) || ! GOAC_Stats::valid_date( $to ) || $from > $to ) { return $out; }
		$meta = self::meta();
		$first = (string) $meta['first_day']; $last = (string) $meta['last_day'];
		$from_num = GOAC_Stats::day_num( $from ); $to_num = GOAC_Stats::day_num( $to );
		for ( $n = $from_num; $n <= $to_num; $n++ ) {
			$d = GOAC_Stats::num_day( $n );
			$data = self::year( (int) substr( $d, 0, 4 ) );
			if ( isset( $data[ $d ] ) ) { $out[ $d ] = self::expand( $data[ $d ] ); }
			elseif ( $first && $d >= $first && $d <= $last ) { $out[ $d ] = GOAC_Stats::empty_row(); }
		}
		return $out;
	}

	public static function row_count() {
		$count = 0;
		foreach ( (array) self::meta()['years'] as $y ) { $count += count( self::year( $y ) ); }
		return $count;
	}

	/* ------------------------------------------------------------------ Outra moeda */

	private static function fx_year( $currency, $year ) {
		$key = self::FX_PREFIX . sanitize_key( $currency ) . '_' . (int) $year;
		if ( ! isset( self::$fx[ $key ] ) ) {
			$raw = get_option( $key, array() );
			self::$fx[ $key ] = is_array( $raw ) ? $raw : array();
		}
		return self::$fx[ $key ];
	}

	public static function fx_value( $currency, $date ) {
		$data = self::fx_year( $currency, (int) substr( (string) $date, 0, 4 ) );
		return isset( $data[ $date ] ) ? (float) $data[ $date ] : null;
	}

	public static function put_fx( $currency, array $values ) {
		$currency = strtoupper( (string) $currency ); $by_year = array();
		foreach ( $values as $date => $value ) {
			if ( GOAC_Stats::valid_date( (string) $date ) && is_numeric( $value ) ) { $by_year[ (int) substr( $date, 0, 4 ) ][ $date ] = round( (float) $value, 6 ); }
		}
		if ( ! $by_year ) { return; }
		foreach ( $by_year as $y => $list ) {
			$key = self::FX_PREFIX . sanitize_key( $currency ) . '_' . $y;
			wp_cache_delete( $key, 'options' ); unset( self::$fx[ $key ] );
			$data = self::fx_year( $currency, $y );
			foreach ( $list as $d => $v ) { $data[ $d ] = $v; }
			ksort( $data );
			self::$fx[ $key ] = $data;
			update_option( $key, $data, false );
		}
		wp_cache_delete( self::META, 'options' );
		$fx_years = (array) self::meta()['fx_years'];
		$fx_years[ $currency ] = array_values( array_unique( array_map( 'intval', array_merge( (array) ( $fx_years[ $currency ] ?? array() ), array_keys( $by_year ) ) ) ) );
		self::update_meta( array( 'fx_years' => $fx_years ) );
	}

	private static function drop_fx( $currency, $date ) {
		$key = self::FX_PREFIX . sanitize_key( $currency ) . '_' . (int) substr( $date, 0, 4 );
		$data = self::fx_year( $currency, (int) substr( $date, 0, 4 ) );
		if ( ! isset( $data[ $date ] ) ) { return; }
		unset( $data[ $date ] );
		self::$fx[ $key ] = $data;
		update_option( $key, $data, false );
	}

	/**
	 * Taxa diária moeda da conta → $currency, derivada da receita convertida pelo Google.
	 * Dias sem conversão (ou com receita zero) usam a taxa conhecida mais próxima; sem nenhuma, a última taxa sincronizada.
	 */
	public static function rates( $currency, $from, $to ) {
		$currency = strtoupper( (string) $currency );
		$lo = GOAC_Stats::add_days( $from, -60 ); $hi = GOAC_Stats::add_days( $to, 60 );
		$known = array();
		foreach ( self::range( $lo, $hi ) as $d => $row ) {
			$fx = self::fx_value( $currency, $d );
			if ( null !== $fx && (float) $row['earnings'] >= 0.01 && $fx > 0 ) { $known[ GOAC_Stats::day_num( $d ) ] = $fx / (float) $row['earnings']; }
		}
		$fallback = self::meta()['fx_rate'][ $currency ] ?? null;
		$nums = array_keys( $known ); sort( $nums ); $count = count( $nums ); $i = 0;
		$out = array();
		for ( $n = GOAC_Stats::day_num( $from ); $n <= GOAC_Stats::day_num( $to ); $n++ ) {
			$d = GOAC_Stats::num_day( $n );
			if ( isset( $known[ $n ] ) ) { $out[ $d ] = $known[ $n ]; continue; }
			if ( ! $count ) { $out[ $d ] = is_numeric( $fallback ) ? (float) $fallback : null; continue; }
			while ( $i < $count - 1 && $nums[ $i + 1 ] <= $n ) { $i++; }
			$best = $nums[ $i ];
			if ( $i + 1 < $count && abs( $nums[ $i + 1 ] - $n ) < abs( $best - $n ) ) { $best = $nums[ $i + 1 ]; }
			$out[ $d ] = $known[ $best ];
		}
		return $out;
	}

	/** Converte a receita das linhas: valor exato do Google quando existe; senão, receita × taxa do dia mais próximo. */
	public static function convert_rows( array $rows, $currency, array $rates ) {
		foreach ( $rows as $d => $row ) {
			$fx = self::fx_value( $currency, $d );
			if ( null !== $fx ) { $rows[ $d ]['earnings'] = $fx; }
			elseif ( isset( $rates[ $d ] ) && is_numeric( $rates[ $d ] ) ) { $rows[ $d ]['earnings'] = (float) $row['earnings'] * (float) $rates[ $d ]; }
		}
		return $rows;
	}

	/** Anos ainda não convertidos por inteiro (a sincronização recente cobre só ~45 dias e não conta). */
	public static function fx_missing_years( $currency ) {
		$meta = self::meta();
		if ( ! $meta['first_day'] ) { return array(); }
		$have = array_map( 'intval', (array) ( $meta['fx_complete'][ strtoupper( $currency ) ] ?? array() ) );
		$missing = array();
		for ( $y = (int) substr( $meta['first_day'], 0, 4 ); $y <= (int) substr( $meta['last_day'], 0, 4 ); $y++ ) { if ( ! in_array( $y, $have, true ) ) { $missing[] = $y; } }
		return $missing;
	}

	private static function sync_fx( $currency, $start, $end ) {
		$tz = GOAC_API::tz();
		$result = GOAC_API::daily_report( new DateTimeImmutable( $start, $tz ), new DateTimeImmutable( $end, $tz ), $currency );
		if ( is_wp_error( $result ) ) {
			self::drop_fx( $currency, $end ); // não deixa o parcial de hoje defasado em relação à moeda da conta
			self::update_meta( array( 'fx_error' => $result->get_error_message() ) );
			return $result;
		}
		self::put_fx( $currency, $result['rows'] );
		$acc = 0.0; $fx = 0.0;
		foreach ( self::range( GOAC_Stats::add_days( $end, -7 ), GOAC_Stats::add_days( $end, -1 ) ) as $d => $row ) {
			if ( isset( $result['rows'][ $d ] ) ) { $acc += (float) $row['earnings']; $fx += (float) $result['rows'][ $d ]; }
		}
		$rates = (array) self::meta()['fx_rate'];
		if ( $acc > 0 && $fx > 0 ) { $rates[ strtoupper( $currency ) ] = $fx / $acc; }
		self::update_meta( array( 'fx_rate' => $rates, 'fx_error' => '' ) );
		return true;
	}

	/* ------------------------------------------------------------------ Sincronização */

	/** Atualiza desde o 1º dia do mês anterior até hoje (1 consulta, +1 se exibindo outra moeda). */
	public static function sync_recent( $max_age = 240, $force = false ) {
		if ( ! GOAC_API::is_connected() ) { return new WP_Error( 'goac_not_connected', 'AdSense ainda não conectado.' ); }
		$meta = self::ensure_account();
		if ( ! $force && ( time() - (int) $meta['synced_at'] ) < (int) $max_age ) { return true; }
		if ( ! $force && get_transient( 'goac_sync_lock' ) ) { return true; }
		set_transient( 'goac_sync_lock', 1, MINUTE_IN_SECONDS );
		$tz = GOAC_API::tz(); $now = new DateTimeImmutable( 'now', $tz ); $today = $now->format( 'Y-m-d' );
		$start = GOAC_Stats::shift_months( GOAC_Stats::month_start( $today ), -1 );
		if ( GOAC_Stats::days_between( $start, $today ) < 35 ) { $start = GOAC_Stats::add_days( $today, -35 ); }
		$result = GOAC_API::daily_report( new DateTimeImmutable( $start, $tz ), new DateTimeImmutable( $today, $tz ) );
		if ( is_wp_error( $result ) ) {
			delete_transient( 'goac_sync_lock' );
			self::update_meta( array( 'last_error' => $result->get_error_message(), 'last_error_at' => time() ) );
			return $result;
		}
		self::put_rows( $result['rows'] );
		$changes = array( 'synced_at' => time(), 'last_error' => '' );
		if ( $result['currency'] ) { $changes['currency'] = strtoupper( $result['currency'] ); }
		self::update_meta( $changes );
		if ( self::converting() ) { self::sync_fx( self::display_currency(), $start, $today ); }
		delete_transient( 'goac_sync_lock' );
		if ( isset( $result['rows'][ $today ] ) ) {
			self::record_intraday( $today, (int) $now->format( 'G' ) * 60 + (int) $now->format( 'i' ), $result['rows'][ $today ] );
		}
		return true;
	}

	/** Ao escolher outra moeda: sincroniza o período recente e agenda a conversão do restante do histórico. */
	public static function prepare_currency( $currency ) {
		$currency = strtoupper( (string) $currency );
		if ( ! GOAC_API::is_connected() || $currency === self::currency() || ! self::has_data() ) { return true; }
		$today = GOAC_API::today();
		$result = self::sync_fx( $currency, GOAC_Stats::add_days( $today, -45 ), $today );
		if ( self::fx_missing_years( $currency ) ) {
			$status = self::backfill_status();
			$status['fx'][ $currency ] = array( 'state' => 'running', 'error' => '', 'started_at' => time() );
			update_option( self::BACKFILL, $status, false );
			if ( ! wp_next_scheduled( 'goac_backfill_event' ) ) { wp_schedule_single_event( time() + 10, 'goac_backfill_event' ); }
		}
		return $result;
	}

	public static function start_backfill( $rebuild = false ) {
		if ( $rebuild ) { self::reset(); }
		self::ensure_account();
		$year = (int) ( new DateTimeImmutable( 'now', GOAC_API::tz() ) )->format( 'Y' );
		$status = array( 'state' => 'running', 'next_year' => $year, 'done_years' => array(), 'empty_streak' => 0, 'started_at' => time(), 'finished_at' => 0, 'error' => '', 'note' => '', 'max_years' => self::max_years(), 'fx' => array() );
		if ( self::converting() ) { $status['fx'][ self::display_currency() ] = array( 'state' => 'running', 'error' => '', 'started_at' => time() ); }
		update_option( self::BACKFILL, $status, false );
		if ( ! wp_next_scheduled( 'goac_backfill_event' ) ) { wp_schedule_single_event( time() + 10, 'goac_backfill_event' ); }
		return $status;
	}

	public static function backfill_running( $status = null ) {
		$status = $status ?: self::backfill_status();
		if ( 'running' === $status['state'] ) { return true; }
		foreach ( (array) $status['fx'] as $fx ) { if ( 'running' === ( $fx['state'] ?? '' ) ) { return true; } }
		return false;
	}

	/** Importa anos inteiros, do atual para trás, até o limite de tempo; depois converte para a moeda de exibição. Retomável (cron ou AJAX). */
	public static function backfill_step( $budget = 12.0 ) {
		$status = self::backfill_status();
		if ( ! self::backfill_running( $status ) || ! GOAC_API::is_connected() ) { return $status; }
		if ( get_transient( 'goac_backfill_lock' ) ) { return $status + array( 'locked' => true ); }
		set_transient( 'goac_backfill_lock', 1, 2 * MINUTE_IN_SECONDS );
		self::ensure_account();
		$tz = GOAC_API::tz(); $today = ( new DateTimeImmutable( 'now', $tz ) )->format( 'Y-m-d' );
		$started = microtime( true );
		while ( 'running' === $status['state'] && microtime( true ) - $started < (float) $budget ) {
			$y = (int) $status['next_year'];
			$start = sprintf( '%04d-01-01', $y ); $end = min( sprintf( '%04d-12-31', $y ), $today );
			$result = GOAC_API::daily_report( new DateTimeImmutable( $start, $tz ), new DateTimeImmutable( $end, $tz ) );
			if ( is_wp_error( $result ) ) {
				if ( 400 === GOAC_API::error_status( $result ) && $status['done_years'] ) {
					$status['state'] = 'done'; $status['finished_at'] = time(); $status['note'] = sprintf( 'A API não aceitou datas de %d; importação encerrada.', $y );
				} else {
					$status['state'] = 'error'; $status['error'] = $result->get_error_message();
				}
				break;
			}
			$active = false;
			foreach ( $result['rows'] as $row ) {
				if ( (float) $row['earnings'] > 0 || (float) $row['page_views'] > 0 || (float) $row['ad_requests'] > 0 ) { $active = true; break; }
			}
			$status['done_years'][] = $y;
			if ( $result['rows'] ) { self::put_rows( $result['rows'] ); }
			if ( $result['currency'] && ! self::currency() ) { self::update_meta( array( 'currency' => strtoupper( $result['currency'] ) ) ); }
			$status['empty_streak'] = $active ? 0 : (int) $status['empty_streak'] + 1;
			$status['next_year'] = $y - 1;
			if ( $status['empty_streak'] >= 2 || count( $status['done_years'] ) >= (int) $status['max_years'] || $y - 1 < 2003 ) {
				$status['state'] = 'done'; $status['finished_at'] = time();
			}
			update_option( self::BACKFILL, $status, false );
		}
		if ( 'running' !== $status['state'] ) {
			foreach ( (array) $status['fx'] as $currency => $fx ) {
				if ( 'running' !== ( $fx['state'] ?? '' ) ) { continue; }
				foreach ( self::fx_missing_years( $currency ) as $y ) {
					if ( microtime( true ) - $started >= (float) $budget ) { break; }
					$result = GOAC_API::daily_report( new DateTimeImmutable( sprintf( '%04d-01-01', $y ), $tz ), new DateTimeImmutable( min( sprintf( '%04d-12-31', $y ), $today ), $tz ), $currency );
					if ( is_wp_error( $result ) ) { $status['fx'][ $currency ] = array( 'state' => 'error', 'error' => $result->get_error_message() ); break; }
					if ( $result['rows'] ) { self::put_fx( $currency, $result['rows'] ); }
					wp_cache_delete( self::META, 'options' );
					$complete = (array) self::meta()['fx_complete'];
					$complete[ $currency ] = array_values( array_unique( array_merge( array_map( 'intval', (array) ( $complete[ $currency ] ?? array() ) ), array( (int) $y ) ) ) );
					self::update_meta( array( 'fx_complete' => $complete ) );
				}
				if ( 'running' === $status['fx'][ $currency ]['state'] && ! self::fx_missing_years( $currency ) ) { $status['fx'][ $currency ] = array( 'state' => 'done', 'error' => '', 'finished_at' => time() ); }
			}
		}
		update_option( self::BACKFILL, $status, false );
		delete_transient( 'goac_backfill_lock' );
		return $status;
	}

	public static function backfill_progress( array $status ) {
		if ( 'running' === $status['state'] ) { return min( 0.97, count( (array) $status['done_years'] ) / max( 1, (int) $status['max_years'] ) ); }
		foreach ( (array) $status['fx'] as $currency => $fx ) {
			if ( 'running' !== ( $fx['state'] ?? '' ) ) { continue; }
			$meta = self::meta();
			$total = max( 1, (int) substr( $meta['last_day'], 0, 4 ) - (int) substr( $meta['first_day'], 0, 4 ) + 1 );
			return min( 0.97, ( $total - count( self::fx_missing_years( $currency ) ) ) / $total );
		}
		return 1.0;
	}

	/* ------------------------------------------------------------------ Intradiário */

	/** Guarda o parcial de hoje em blocos de 10 min; ao virar o dia o anterior vai para o histórico (30 dias). */
	public static function record_intraday( $date, $minute, array $row ) {
		$cur = get_option( self::INTRADAY_TODAY, array() );
		if ( ! is_array( $cur ) || ( $cur['date'] ?? '' ) !== $date ) {
			if ( is_array( $cur ) && ! empty( $cur['date'] ) && ! empty( $cur['points'] ) ) {
				$hist = get_option( self::INTRADAY_HIST, array() );
				if ( ! is_array( $hist ) ) { $hist = array(); }
				$hist[ $cur['date'] ] = array_values( $cur['points'] );
				$limit = GOAC_Stats::add_days( $date, -30 );
				foreach ( array_keys( $hist ) as $d ) { if ( (string) $d < $limit ) { unset( $hist[ $d ] ); } }
				ksort( $hist );
				update_option( self::INTRADAY_HIST, $hist, false );
			}
			$cur = array( 'date' => $date, 'points' => array() );
		}
		$minute = max( 0, min( 1439, (int) $minute ) );
		$cur['points'][ (int) floor( $minute / 10 ) ] = array( $minute, round( (float) ( $row['earnings'] ?? 0 ), 4 ), (int) ( $row['page_views'] ?? 0 ), (int) ( $row['impressions'] ?? 0 ), (int) ( $row['clicks'] ?? 0 ) );
		ksort( $cur['points'] );
		update_option( self::INTRADAY_TODAY, $cur, false );
	}

	public static function intraday() {
		$hist = get_option( self::INTRADAY_HIST, array() );
		if ( ! is_array( $hist ) ) { $hist = array(); }
		$cur = get_option( self::INTRADAY_TODAY, array() );
		if ( is_array( $cur ) && ! empty( $cur['date'] ) ) { $hist[ $cur['date'] ] = array_values( (array) $cur['points'] ); }
		return $hist;
	}

	/** Valores de um dia num minuto, interpolados entre instantâneos próximos (até 40 min de distância). Moeda da conta. */
	public static function intraday_at( array $intraday, $date, $minute ) {
		$points = isset( $intraday[ $date ] ) ? array_values( (array) $intraday[ $date ] ) : array();
		if ( ! $points ) { return null; }
		usort( $points, static function( $a, $b ) { return $a[0] <=> $b[0]; } );
		$prev = null; $next = null;
		foreach ( $points as $p ) { if ( $p[0] <= $minute ) { $prev = $p; } else { $next = $p; break; } }
		$pick = null;
		if ( $prev && $next && $next[0] - $prev[0] <= 80 ) {
			$f = ( $minute - $prev[0] ) / max( 1, $next[0] - $prev[0] );
			$pick = array();
			for ( $i = 1; $i <= 4; $i++ ) { $pick[ $i ] = $prev[ $i ] + ( $next[ $i ] - $prev[ $i ] ) * $f; }
		} elseif ( $prev && $minute - $prev[0] <= 40 ) {
			$pick = $prev;
		} elseif ( $next && $next[0] - $minute <= 40 ) {
			$pick = $next;
		}
		if ( null === $pick ) { return null; }
		return array( 'earnings' => (float) $pick[1], 'page_views' => (float) $pick[2], 'impressions' => (float) $pick[3], 'clicks' => (float) $pick[4] );
	}
}
