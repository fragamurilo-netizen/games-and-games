<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Contexto compartilhado pelas telas (histórico local + modelos de previsão) e componentes de interface.
 * Todo texto dinâmico sai escapado; métodos que devolvem HTML deixam isso claro no nome ou no comentário.
 */
final class GOAC_UI {
	const WEEKDAYS = array( 'Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado' );
	const WEEKDAYS_SHORT = array( 'Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb' );
	const MONTHS = array( 1 => 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro' );
	const MONTHS_SHORT = array( 1 => 'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez' );

	private static $ctx = null;
	private static $currency = null;
	private static $columns = array();

	/* ------------------------------------------------------------------ Contexto */

	public static function context( $sync = true ) {
		if ( null !== self::$ctx ) { return self::$ctx; }
		$sync_error = '';
		if ( $sync && GOAC_API::is_connected() ) {
			$result = GOAC_Store::sync_recent( 60 * self::refresh_minutes() );
			if ( is_wp_error( $result ) ) { $sync_error = $result->get_error_message(); }
		}
		$tz = GOAC_API::tz(); $now = new DateTimeImmutable( 'now', $tz );
		$today = $now->format( 'Y-m-d' ); $yesterday = GOAC_Stats::add_days( $today, -1 );
		$meta = GOAC_Store::meta();
		$first = (string) $meta['first_day'];
		$account_rows = $first ? GOAC_Store::range( $first, $today ) : array();
		$has_today = isset( $account_rows[ $today ] );
		if ( $first && ! $has_today ) { $account_rows[ $today ] = GOAC_Stats::empty_row(); }
		$last_day = (string) $meta['last_day'];
		$model_last = $last_day && $last_day < $yesterday ? $last_day : $yesterday;

		// Moeda de exibição: receita convertida pelo Google, dia a dia.
		$account_currency = GOAC_Store::currency();
		$currency = GOAC_Store::display_currency();
		$rows = $account_rows; $rates = array(); $fx_notice = '';
		if ( $account_rows && $currency !== $account_currency ) {
			$rates = GOAC_Store::rates( $currency, $first, $today );
			if ( array_filter( $rates, 'is_numeric' ) ) {
				$rows = GOAC_Store::convert_rows( $account_rows, $currency, $rates );
			} else {
				$fx_notice = sprintf( 'A conversão para %s ainda não está disponível; exibindo valores em %s.', $currency, $account_currency );
				$currency = $account_currency; $rates = array();
			}
		}
		self::$currency = $currency ?: $account_currency;
		self::$columns = array();

		$synced_at = (int) $meta['synced_at'];
		$minute = 0;
		if ( $has_today && $synced_at ) {
			$sync_dt = ( new DateTimeImmutable( '@' . $synced_at ) )->setTimezone( $tz );
			$minute = $sync_dt->format( 'Y-m-d' ) === $today ? (int) $sync_dt->format( 'G' ) * 60 + (int) $sync_dt->format( 'i' ) : 1439;
		}

		$earn_hist = $first ? GOAC_Stats::column( $rows, 'earnings', $model_last ) : array();
		$pv_hist = $first ? GOAC_Stats::column( $rows, 'page_views', $model_last ) : array();
		$model = GOAC_Stats::build_model( $earn_hist, $model_last );
		$pv_model = GOAC_Stats::build_model( $pv_hist, $model_last );
		$intraday = GOAC_Store::intraday();
		// A curva do dia é uma proporção: aprende com os instantâneos e os totais na mesma moeda (a da conta).
		$profile = GOAC_Stats::learn_profile( $intraday, $first ? GOAC_Stats::column( $account_rows, 'earnings', $model_last ) : array(), $today );
		$today_row = $rows[ $today ] ?? GOAC_Stats::empty_row();
		$today_est = GOAC_Stats::today_estimate( $model, $today_row['earnings'], $minute, $profile );
		$today_pv_est = GOAC_Stats::today_estimate( $pv_model, $today_row['page_views'], $minute, $profile );
		$same_time = $has_today && $minute ? GOAC_Store::intraday_at( $intraday, $yesterday, $minute ) : null;
		if ( $same_time && $rates && isset( $rates[ $yesterday ] ) ) { $same_time['earnings'] *= (float) $rates[ $yesterday ]; }

		self::$ctx = array(
			'now' => $now, 'tz' => $tz, 'today' => $today, 'yesterday' => $yesterday, 'meta' => $meta, 'first_day' => $first, 'rows' => $rows, 'account_rows' => $account_rows,
			'has_today' => $has_today, 'minute' => $minute, 'model' => $model, 'pv_model' => $pv_model, 'profile' => $profile,
			'today_est' => $today_est, 'today_pv_est' => $today_pv_est, 'same_time_yesterday' => $same_time, 'intraday' => $intraday,
			'currency' => self::$currency, 'account_currency' => $account_currency, 'rates' => $rates, 'fx_notice' => $fx_notice,
			'sync_error' => $sync_error, 'stale' => $synced_at && time() - $synced_at > 6 * HOUR_IN_SECONDS,
			'backfill' => GOAC_Store::backfill_status(),
		);
		return self::$ctx;
	}

	public static function reset_context() { self::$ctx = null; self::$currency = null; self::$columns = array(); }

	/** Moeda em que os valores estão sendo exibidos. */
	public static function currency_code() {
		return null !== self::$currency ? self::$currency : GOAC_Store::display_currency();
	}

	/** Moeda para consultas diretas à API (relatórios, sites, unidades): vazio quando é a da conta. */
	public static function api_currency() {
		$cur = self::currency_code();
		return $cur && $cur !== GOAC_Store::currency() ? $cur : '';
	}

	public static function refresh_minutes() { return max( 1, min( 30, (int) get_option( 'goac_refresh_minutes', 5 ) ) ); }

	public static function projection( $start, $end, $key = 'earnings' ) {
		$c = self::context();
		$pv = 'page_views' === $key;
		if ( ! isset( self::$columns[ $key ] ) ) { self::$columns[ $key ] = GOAC_Stats::column( $c['rows'], $key ); }
		return GOAC_Stats::project_range( $pv ? $c['pv_model'] : $c['model'], self::$columns[ $key ], $pv ? $c['today_pv_est'] : $c['today_est'], $start, $end, $c['today'] );
	}

	public static function rows( $start, $end ) {
		return GOAC_Stats::slice( self::context()['rows'], $start, $end );
	}

	/**
	 * Linhas do período de comparação. Se o período atual termina hoje (parcial), o dia equivalente do período
	 * anterior entra só com a parte já transcorrida: o instantâneo de ontem no mesmo horário, quando existe,
	 * ou o dia inteiro × parcela típica do dia já contabilizada.
	 */
	public static function comparable_rows( $prev_start, $prev_end, $current_end ) {
		$c = self::context();
		$rows = self::rows( $prev_start, $prev_end );
		if ( $current_end !== $c['today'] || ! isset( $rows[ $prev_end ] ) || ! $c['has_today'] ) { return $rows; }
		$row = $rows[ $prev_end ];
		$same = $c['same_time_yesterday'];
		if ( $prev_end === $c['yesterday'] && $same ) {
			$scale = (float) $row['page_views'] > 0 ? $same['page_views'] / (float) $row['page_views'] : (float) $c['today_est']['fraction'];
			foreach ( array( 'earnings', 'page_views', 'impressions', 'clicks' ) as $k ) { $row[ $k ] = (float) $same[ $k ]; }
			$row['ad_requests'] = (float) $row['ad_requests'] * $scale; $row['matched_requests'] = (float) $row['matched_requests'] * $scale;
		} else {
			$f = (float) $c['today_est']['fraction'];
			foreach ( GOAC_Stats::ADDITIVE as $k ) { $row[ $k ] = (float) $row[ $k ] * $f; }
		}
		$rows[ $prev_end ] = $row;
		return $rows;
	}

	/** Metas ficam guardadas por moeda; sem meta na moeda exibida, converte a da outra moeda pela taxa recente. */
	public static function goal( $period ) {
		$info = self::goal_info( $period );
		return $info['value'];
	}

	public static function goal_info( $period ) {
		$goals = get_option( 'goac_goals', array() );
		$goals = is_array( $goals ) ? $goals : array();
		$cur = self::currency_code();
		if ( isset( $goals[ $cur ][ $period ] ) ) { return array( 'value' => max( 0.0, (float) $goals[ $cur ][ $period ] ), 'note' => '' ); }
		foreach ( $goals as $other => $values ) {
			if ( $other === $cur || empty( $values[ $period ] ) ) { continue; }
			$rate = self::recent_rate( $other, $cur );
			if ( $rate ) { return array( 'value' => (float) $values[ $period ] * $rate, 'note' => 'convertida de ' . self::money( $values[ $period ], 0, $other ) ); }
		}
		return array( 'value' => 0.0, 'note' => '' );
	}

	/** Taxa recente de $from para $to (média dos últimos 30 dias pelos relatórios do Google). */
	public static function recent_rate( $from, $to ) {
		if ( $from === $to ) { return 1.0; }
		$account = GOAC_Store::currency();
		$rate_to = static function( $cur ) use ( $account ) {
			if ( $cur === $account ) { return 1.0; }
			$today = GOAC_API::today(); $acc = 0.0; $fx = 0.0;
			foreach ( GOAC_Store::range( GOAC_Stats::add_days( $today, -30 ), GOAC_Stats::add_days( $today, -1 ) ) as $d => $row ) {
				$v = GOAC_Store::fx_value( $cur, $d );
				if ( null !== $v ) { $acc += (float) $row['earnings']; $fx += $v; }
			}
			if ( $acc > 0 && $fx > 0 ) { return $fx / $acc; }
			$stored = GOAC_Store::meta()['fx_rate'][ $cur ] ?? null;
			return is_numeric( $stored ) ? (float) $stored : null;
		};
		$a = $rate_to( $from ); $b = $rate_to( $to );
		return $a && $b ? $b / $a : null;
	}

	/** $value false remove a meta desta moeda (volta a valer a conversão de outra moeda, se houver); 0 desativa. */
	public static function save_goal( $period, $value ) {
		$goals = get_option( 'goac_goals', array() );
		$goals = is_array( $goals ) ? $goals : array();
		$cur = self::currency_code();
		if ( false === $value ) { unset( $goals[ $cur ][ $period ] ); }
		else { $goals[ $cur ][ $period ] = max( 0.0, (float) $value ); }
		update_option( 'goac_goals', array_filter( $goals ), false );
	}

	/* ------------------------------------------------------------------ Formatação */

	public static function money( $v, $decimals = 2, $currency = null ) {
		if ( null === $v || ! is_numeric( $v ) ) { return '—'; }
		$currency = strtoupper( (string) ( null === $currency ? self::currency_code() : $currency ) );
		$symbols = array( 'BRL' => 'R$ ', 'USD' => 'US$ ', 'EUR' => '€ ', 'GBP' => '£ ' );
		$prefix = $symbols[ $currency ] ?? ( $currency ? $currency . ' ' : '' );
		return ( (float) $v < 0 ? '-' : '' ) . $prefix . number_format_i18n( abs( (float) $v ), $decimals );
	}

	public static function number( $v, $decimals = 0 ) {
		return null === $v || ! is_numeric( $v ) ? '—' : number_format_i18n( (float) $v, $decimals );
	}

	public static function pct( $v, $decimals = 1 ) {
		return null === $v || ! is_numeric( $v ) ? '—' : number_format_i18n( (float) $v * 100, $decimals ) . '%';
	}

	public static function signed_pct( $v, $decimals = 1 ) {
		if ( null === $v || ! is_numeric( $v ) ) { return '—'; }
		return ( $v > 0 ? '+' : ( $v < 0 ? '−' : '' ) ) . number_format_i18n( abs( (float) $v ) * 100, $decimals ) . '%';
	}

	public static function seconds( $v ) {
		return null === $v || ! is_numeric( $v ) ? '—' : number_format_i18n( (float) $v, 1 ) . ' s';
	}

	public static function date( $date, $format = 'd/m/Y' ) {
		if ( ! GOAC_Stats::valid_date( (string) $date ) ) { return '—'; }
		return gmdate( $format, GOAC_Stats::day_num( $date ) * 86400 );
	}

	public static function weekday( $date, $short = true ) {
		$w = GOAC_Stats::weekday( $date );
		return $short ? self::WEEKDAYS_SHORT[ $w ] : self::WEEKDAYS[ $w ];
	}

	public static function month_label( $ym, $long = false ) {
		$y = (int) substr( (string) $ym, 0, 4 ); $m = (int) substr( (string) $ym, 5, 2 );
		if ( $m < 1 || $m > 12 ) { return (string) $ym; }
		return $long ? self::MONTHS[ $m ] . ' de ' . $y : self::MONTHS_SHORT[ $m ] . '/' . $y;
	}

	public static function range_label( $start, $end ) {
		if ( $start === $end ) { return self::weekday( $start ) . ', ' . self::date( $start ); }
		return self::date( $start ) . ' a ' . self::date( $end );
	}

	public static function group_label( array $g, $by ) {
		switch ( $by ) {
			case 'week': return self::date( $g['start'], 'd/m' ) . ' – ' . self::date( GOAC_Stats::add_days( $g['key'], 6 ), 'd/m/Y' );
			case 'month': return self::month_label( $g['key'], true );
			case 'quarter': return str_replace( '-T', ' · ', $g['key'] ) . 'º trimestre';
			case 'year': return (string) $g['key'];
			default: return self::weekday( $g['key'] ) . ' ' . self::date( $g['key'] );
		}
	}

	/** HTML: variação com seta e rótulo (nunca só cor). */
	public static function delta( $ratio, $label = '', $invert = false ) {
		if ( null === $ratio || ! is_numeric( $ratio ) ) {
			return '<span class="goac-delta is-flat">' . esc_html( $label ? 'sem base ' . $label : 'sem comparação' ) . '</span>';
		}
		$up = $ratio > 0.0005; $down = $ratio < -0.0005;
		$class = ! $up && ! $down ? 'is-flat' : ( ( $up xor $invert ) ? 'is-up' : 'is-down' );
		$arrow = $up ? '▲' : ( $down ? '▼' : '■' );
		return '<span class="goac-delta ' . $class . '"><span aria-hidden="true">' . $arrow . '</span> ' . esc_html( self::signed_pct( $ratio ) ) . '</span>' . ( $label ? ' <span class="goac-delta-label">' . esc_html( $label ) . '</span>' : '' );
	}

	/** add_query_arg() não codifica valores; valores vindos da API (URLs de página, nomes com &) precisam de rawurlencode. */
	private static function encode_args( array $args ) {
		return array_map( static function( $v ) { return rawurlencode( (string) $v ); }, $args );
	}

	public static function url( $tab, $args = array() ) {
		return add_query_arg( self::encode_args( array_merge( array( 'page' => 'goac', 'tab' => $tab ), $args ) ), admin_url( 'admin.php' ) );
	}

	public static function action_url( $action, $args = array() ) {
		return wp_nonce_url( add_query_arg( self::encode_args( array_merge( array( 'action' => $action ), $args ) ), admin_url( 'admin-post.php' ) ), $action );
	}

	/* ------------------------------------------------------------------ Componentes */

	/** $sub já deve vir como HTML seguro. */
	public static function kpi( $label, $value, $sub = '', $opts = array() ) {
		$class = 'goac-kpi' . ( ! empty( $opts['class'] ) ? ' ' . $opts['class'] : '' );
		$live = ! empty( $opts['live'] ) ? ' data-goac-live="' . esc_attr( $opts['live'] ) . '"' : '';
		$title = ! empty( $opts['title'] ) ? ' title="' . esc_attr( $opts['title'] ) . '"' : '';
		echo '<div class="' . esc_attr( $class ) . '"' . $title . '><span class="goac-kpi-label">' . esc_html( $label ) . '</span><strong' . $live . '>' . esc_html( $value ) . '</strong>' . ( '' !== $sub ? '<small>' . $sub . '</small>' : '' ) . ( $opts['after'] ?? '' ) . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	}

	public static function card_open( $title, $aside = '', $class = '', $id = '' ) {
		echo '<section class="goac-card ' . esc_attr( $class ) . '"' . ( $id ? ' id="' . esc_attr( $id ) . '"' : '' ) . '><div class="goac-card-head"><h2>' . esc_html( $title ) . '</h2>' . ( $aside ? '<div class="goac-card-aside">' . $aside . '</div>' : '' ) . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	}

	public static function card_close() { echo '</section>'; }

	/** Gráfico SVG desenhado pelo admin.js a partir da configuração JSON; a tabela ao lado/abaixo é o equivalente acessível. */
	public static function chart( array $config, $height = 280, $id = '' ) {
		$config['height'] = (int) $height;
		if ( empty( $config['currency'] ) ) { $config['currency'] = self::currency_code(); }
		printf(
			'<div class="goac-chart"%s data-goac-chart="%s" style="min-height:%dpx"><p class="goac-chart-fallback">Ative o JavaScript para ver o gráfico. Os mesmos dados estão na tabela.</p></div>',
			$id ? ' id="' . esc_attr( $id ) . '"' : '', esc_attr( wp_json_encode( $config ) ), (int) $height + 36
		);
	}

	/** HTML: barra horizontal de participação. */
	public static function bar( $fraction, $class = '' ) {
		$w = max( 0, min( 100, (float) $fraction * 100 ) );
		return '<span class="goac-bar ' . esc_attr( $class ) . '"><i style="width:' . esc_attr( number_format( $w, 2, '.', '' ) ) . '%"></i></span>';
	}

	/** Devolve uma função que classifica valores em 0–5 por quantis dos valores positivos (um pico não apaga o resto). */
	public static function heat_scale( array $values ) {
		$pos = array_values( array_filter( array_map( 'floatval', $values ), static function( $v ) { return $v > 0; } ) );
		$cuts = array();
		if ( $pos ) { foreach ( array( 0.2, 0.4, 0.6, 0.8 ) as $q ) { $cuts[] = GOAC_Stats::percentile( $pos, $q ); } }
		return static function( $v ) use ( $cuts ) {
			$v = (float) $v;
			if ( $v <= 0 || ! $cuts ) { return 0; }
			$level = 1;
			foreach ( $cuts as $cut ) { if ( $v > $cut ) { $level++; } }
			return min( 5, $level );
		};
	}

	public static function heat_legend( array $values ) {
		$pos = array_values( array_filter( array_map( 'floatval', $values ), static function( $v ) { return $v > 0; } ) );
		if ( ! $pos ) { return ''; }
		$html = '<div class="goac-heat-legend"><span>Menos</span>';
		for ( $i = 0; $i <= 5; $i++ ) { $html .= '<i class="goac-h' . $i . '"></i>'; }
		return $html . '<span>Mais</span><span class="goac-muted"> · ' . esc_html( self::money( min( $pos ) ) . ' a ' . self::money( max( $pos ) ) ) . '</span></div>';
	}

	/** Calendário de calor com um bloco por mês (segunda a domingo). Dias futuros com previsão aparecem tracejados. */
	public static function calendar( array $rows, $start, $end, $today, array $forecast = array(), $display_end = '' ) {
		$values = array();
		foreach ( $rows as $d => $r ) { if ( $d < $today ) { $values[] = (float) $r['earnings']; } }
		$scale = self::heat_scale( $values );
		echo '<div class="goac-calendar">';
		$month = GOAC_Stats::month_start( $start );
		$last = $display_end && $display_end > $end ? $display_end : $end;
		$guard = 0;
		while ( $month <= $last && $guard++ < 240 ) {
			$m_end = GOAC_Stats::month_end( $month );
			$sum = 0.0; foreach ( self::rows( $month, min( $m_end, $today ) ) as $r ) { $sum += (float) $r['earnings']; }
			$f_sum = 0.0; foreach ( $forecast as $d => $f ) { if ( $d >= $month && $d <= $m_end ) { $f_sum += (float) $f['value']; } }
			echo '<div class="goac-cal-month"><div class="goac-cal-head"><strong>' . esc_html( self::month_label( substr( $month, 0, 7 ), true ) ) . '</strong><span>' . esc_html( self::money( $sum, 0 ) ) . ( $f_sum > 0 ? ' · prev. ' . esc_html( self::money( $sum + $f_sum, 0 ) ) : '' ) . '</span></div><div class="goac-cal-grid">';
			foreach ( array( 1, 2, 3, 4, 5, 6, 0 ) as $w ) { echo '<span class="goac-cal-wd">' . esc_html( mb_substr( self::WEEKDAYS_SHORT[ $w ], 0, 1 ) ) . '</span>'; }
			$offset = ( GOAC_Stats::weekday( $month ) + 6 ) % 7;
			for ( $i = 0; $i < $offset; $i++ ) { echo '<span class="goac-cal-pad"></span>'; }
			for ( $d = $month; $d <= $m_end; $d = GOAC_Stats::add_days( $d, 1 ) ) {
				$day = (int) substr( $d, 8, 2 );
				if ( $d < $start || $d > $end ) {
					if ( isset( $forecast[ $d ] ) ) {
						$f = $forecast[ $d ];
						echo '<span class="goac-cal-day is-forecast" title="' . esc_attr( self::weekday( $d ) . ', ' . self::date( $d ) . ' — previsão ' . self::money( $f['value'] ) ) . '">' . (int) $day . '</span>';
					} else {
						echo '<span class="goac-cal-day is-out">' . (int) $day . '</span>';
					}
					continue;
				}
				if ( ! isset( $rows[ $d ] ) ) { echo '<span class="goac-cal-day is-empty" title="' . esc_attr( self::date( $d ) . ' — sem dados' ) . '">' . (int) $day . '</span>'; continue; }
				$r = $rows[ $d ]; $partial = $d === $today;
				$title = self::weekday( $d ) . ', ' . self::date( $d ) . ( $partial ? ' (parcial)' : '' ) . ' — ' . self::money( $r['earnings'] ) . ' · ' . self::number( $r['page_views'] ) . ' page views · RPM ' . self::money( $r['page_views'] > 0 ? $r['earnings'] / $r['page_views'] * 1000 : null );
				echo '<span class="goac-cal-day goac-h' . (int) ( $partial ? 0 : $scale( $r['earnings'] ) ) . ( $partial ? ' is-today' : '' ) . '" title="' . esc_attr( $title ) . '">' . (int) $day . '</span>';
			}
			echo '</div></div>';
			$month = GOAC_Stats::shift_months( $month, 1 );
		}
		echo '</div>' . self::heat_legend( $values ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	}

	/** Barra de meta: realizado, previsão, quanto falta por dia e chance estimada. */
	public static function goal_meter( $label, $goal, array $p, $note = '' ) {
		$prob = GOAC_Stats::goal_probability( $goal, $p );
		$missing = max( 0.0, $goal - $p['realized'] );
		$per_day = $p['days_left'] > 0 ? $missing / $p['days_left'] : 0.0;
		$done = min( 100, 100 * $p['realized'] / $goal ); $proj = min( 100, 100 * $p['projected'] / $goal );
		echo '<div class="goac-goal"><div class="goac-goal-head"><strong>' . esc_html( $label ) . ': ' . esc_html( self::money( $goal, 0 ) ) . ( $note ? ' <small class="goac-muted">(' . esc_html( $note ) . ')</small>' : '' ) . '</strong><span>' . esc_html( self::pct( $p['realized'] / $goal, 0 ) . ' realizado · previsão ' . self::pct( $p['projected'] / $goal, 0 ) ) . '</span></div>';
		echo '<div class="goac-goal-track" role="img" aria-label="' . esc_attr( 'Realizado ' . self::pct( $p['realized'] / $goal, 0 ) . ', previsão ' . self::pct( $p['projected'] / $goal, 0 ) ) . '"><i class="is-projected" style="width:' . esc_attr( (string) round( $proj, 2 ) ) . '%"></i><i class="is-done" style="width:' . esc_attr( (string) round( $done, 2 ) ) . '%"></i></div>';
		if ( $missing <= 0 ) {
			echo '<p class="goac-goal-note is-good"><span aria-hidden="true">▲</span> Meta atingida. Excedente atual: ' . esc_html( self::money( $p['realized'] - $goal ) ) . '.</p></div>';
			return;
		}
		echo '<p class="goac-goal-note">Faltam <strong>' . esc_html( self::money( $missing ) ) . '</strong> · ' . esc_html( self::money( $per_day ) ) . '/dia nos ' . (int) $p['days_left'] . ' dias restantes · chance estimada <strong>' . esc_html( self::pct( $prob, 0 ) ) . '</strong></p></div>';
	}

	/** Campos de período (preset + datas + incluir hoje). */
	public static function period_fields( array $range, $include_today ) {
		$c = self::context( false );
		$map = array();
		foreach ( GOAC_Stats::presets() as $group ) {
			foreach ( $group as $key => $label ) {
				if ( 'custom' === $key ) { continue; }
				$r = GOAC_Stats::resolve_range( $key, '', '', $c['today'], $c['first_day'], false );
				$ri = GOAC_Stats::resolve_range( $key, '', '', $c['today'], $c['first_day'], true );
				$map[ $key ] = array( $r['start'], $r['end'], $ri['end'] );
			}
		}
		echo '<label>Período<select name="preset" data-goac-preset=\'' . esc_attr( wp_json_encode( $map ) ) . '\'>';
		foreach ( GOAC_Stats::presets() as $group_label => $group ) {
			echo '<optgroup label="' . esc_attr( $group_label ) . '">';
			foreach ( $group as $key => $label ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $key ), selected( $range['preset'], $key, false ), esc_html( $label ) ); }
			echo '</optgroup>';
		}
		echo '</select></label>';
		printf( '<label>De<input type="date" name="from" value="%s" max="%s" data-goac-date></label>', esc_attr( $range['start'] ), esc_attr( $c['today'] ) );
		printf( '<label>Até<input type="date" name="to" value="%s" max="%s" data-goac-date></label>', esc_attr( $range['end'] ), esc_attr( $c['today'] ) );
		printf( '<label class="goac-check"><input type="checkbox" name="include_today" value="1" %s data-goac-include-today> Incluir hoje</label>', checked( $include_today, true, false ) );
	}

	/** Lê os parâmetros de período da URL. */
	public static function request_range( $default_preset = 'last_30', $default_include_today = true ) {
		$c = self::context( false );
		$preset = isset( $_GET['preset'] ) ? sanitize_key( wp_unslash( $_GET['preset'] ) ) : $default_preset; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$from = isset( $_GET['from'] ) ? sanitize_text_field( wp_unslash( $_GET['from'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$to = isset( $_GET['to'] ) ? sanitize_text_field( wp_unslash( $_GET['to'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$include_today = isset( $_GET['preset'] ) ? ! empty( $_GET['include_today'] ) : $default_include_today; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return array( GOAC_Stats::resolve_range( $preset, $from, $to, $c['today'], $c['first_day'], $include_today ), $include_today );
	}

	public static function quick_ranges( $tab, array $current, $extra = array() ) {
		$quick = array( 'today' => 'Hoje', 'yesterday' => 'Ontem', 'last_7' => '7 dias', 'last_30' => '30 dias', 'last_90' => '90 dias', 'this_month' => 'Este mês', 'last_month' => 'Mês passado', 'this_year' => 'Este ano', 'last_year' => 'Ano passado', 'all' => 'Tudo' );
		echo '<div class="goac-chips" role="list">';
		foreach ( $quick as $key => $label ) {
			printf( '<a role="listitem" class="goac-chip %s" href="%s">%s</a>', $current['preset'] === $key ? 'is-active' : '', esc_url( self::url( $tab, array_merge( $extra, array( 'preset' => $key, 'include_today' => 1 ) ) ) ), esc_html( $label ) );
		}
		echo '</div>';
	}

	public static function empty_state( $text ) {
		echo '<p class="goac-empty-inline">' . esc_html( $text ) . '</p>';
	}

	/** HTML: aviso do WordPress. */
	public static function notice( $type, $html ) {
		echo '<div class="notice notice-' . esc_attr( $type ) . '"><p>' . $html . '</p></div>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	}

	/** Garante valores seguros para planilhas: textos que começam com = + - @ ganham apóstrofo. */
	public static function csv_cell( $v ) {
		if ( null === $v ) { return ''; }
		if ( is_int( $v ) ) { return (string) $v; }
		if ( is_float( $v ) ) {
			$s = rtrim( rtrim( number_format( $v, 6, ',', '' ), '0' ), ',' );
			return '-0' === $s ? '0' : $s;
		}
		$v = (string) $v;
		return preg_match( '/^[=+\-@\t\r]/', $v ) ? "'" . $v : $v;
	}

	/** CSV para Excel pt-BR: UTF-8 com BOM, ponto e vírgula e vírgula decimal. */
	public static function send_csv( $filename, array $header, array $rows ) {
		nocache_headers();
		header( 'Content-Type: text/csv; charset=utf-8' );
		header( 'Content-Disposition: attachment; filename="' . sanitize_file_name( $filename ) . '"' );
		$out = fopen( 'php://output', 'w' );
		fwrite( $out, "\xEF\xBB\xBF" );
		fputcsv( $out, $header, ';', '"', '' );
		foreach ( $rows as $row ) { fputcsv( $out, array_map( array( __CLASS__, 'csv_cell' ), $row ), ';', '"', '' ); }
		fclose( $out );
		exit;
	}
}
