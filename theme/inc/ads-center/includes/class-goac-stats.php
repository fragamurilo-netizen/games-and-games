<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Estatísticas e previsões calculadas sobre o histórico diário local.
 * Tudo aqui é puro: recebe arrays, devolve arrays, nunca chama a API.
 * Datas são strings Y-m-d já no fuso da conta; a aritmética usa dias inteiros (UTC) para evitar horário de verão.
 */
final class GOAC_Stats {
	const ADDITIVE = array( 'earnings', 'page_views', 'ad_requests', 'matched_requests', 'impressions', 'clicks' );
	const Z80 = 1.2816; // faixa de 80% (P10–P90)
	const PHI = 0.95;   // amortecimento da tendência por dia

	/* ------------------------------------------------------------------ Datas */

	public static function day_num( $date ) {
		$p = explode( '-', (string) $date );
		if ( count( $p ) < 3 ) { return 0; }
		return (int) floor( gmmktime( 0, 0, 0, (int) $p[1], (int) $p[2], (int) $p[0] ) / 86400 );
	}

	public static function num_day( $num ) { return gmdate( 'Y-m-d', (int) $num * 86400 ); }
	public static function add_days( $date, $days ) { return self::num_day( self::day_num( $date ) + (int) $days ); }
	public static function days_between( $from, $to ) { return self::day_num( $to ) - self::day_num( $from ); }
	public static function weekday( $date ) { return self::weekday_num( self::day_num( $date ) ); }
	public static function weekday_num( $num ) { return ( ( (int) $num + 4 ) % 7 + 7 ) % 7; } // 01/01/1970 foi quinta-feira; 0 = domingo.

	public static function valid_date( $date ) {
		if ( ! is_string( $date ) || ! preg_match( '/^(\d{4})-(\d{2})-(\d{2})$/', $date, $m ) ) { return false; }
		return checkdate( (int) $m[2], (int) $m[3], (int) $m[1] ) && (int) $m[1] >= 2000 && (int) $m[1] <= 2100;
	}

	public static function month_start( $date ) { return substr( (string) $date, 0, 8 ) . '01'; }
	public static function month_end( $date ) { return gmdate( 'Y-m-t', self::day_num( self::month_start( $date ) ) * 86400 ); }
	public static function days_in_month( $date ) { return (int) substr( self::month_end( $date ), 8, 2 ); }
	public static function week_start( $date ) { return self::add_days( $date, -( ( self::weekday( $date ) + 6 ) % 7 ) ); } // semana começa na segunda.
	public static function quarter_of( $date ) { return (int) floor( ( (int) substr( (string) $date, 5, 2 ) - 1 ) / 3 ) + 1; }
	public static function quarter_start( $date ) { return substr( (string) $date, 0, 5 ) . sprintf( '%02d', 3 * ( self::quarter_of( $date ) - 1 ) + 1 ) . '-01'; }
	public static function quarter_end( $date ) { return self::add_days( self::shift_months( self::quarter_start( $date ), 3 ), -1 ); }

	public static function shift_months( $date, $months ) {
		$y = (int) substr( (string) $date, 0, 4 ); $m = (int) substr( (string) $date, 5, 2 ) + (int) $months; $d = (int) substr( (string) $date, 8, 2 );
		while ( $m < 1 ) { $m += 12; $y--; }
		while ( $m > 12 ) { $m -= 12; $y++; }
		$last = (int) gmdate( 't', gmmktime( 0, 0, 0, $m, 1, $y ) );
		return sprintf( '%04d-%02d-%02d', $y, $m, min( max( 1, $d ), $last ) );
	}

	public static function shift_years( $date, $years ) { return self::shift_months( $date, 12 * (int) $years ); }

	/* ------------------------------------------------------------------ Linhas e agregação */

	public static function empty_row() {
		return array( 'earnings' => 0.0, 'page_views' => 0.0, 'ad_requests' => 0.0, 'matched_requests' => 0.0, 'impressions' => 0.0, 'clicks' => 0.0, 'viewability' => null, 'measurability' => null, 'view_time' => null );
	}

	/** Acrescenta as métricas derivadas (RPM, CTR, CPC, cobertura) a partir das somas. */
	public static function derive( array $r ) {
		$r += self::empty_row();
		$e = (float) $r['earnings']; $pv = (float) $r['page_views']; $im = (float) $r['impressions'];
		$cl = (float) $r['clicks']; $rq = (float) $r['ad_requests']; $mr = (float) $r['matched_requests'];
		$r['page_rpm']             = $pv > 0 ? $e / $pv * 1000 : null;
		$r['impression_rpm']       = $im > 0 ? $e / $im * 1000 : null;
		$r['ctr']                  = $pv > 0 ? $cl / $pv : null;
		$r['impression_ctr']       = $im > 0 ? $cl / $im : null;
		$r['cpc']                  = $cl > 0 ? $e / $cl : null;
		$r['coverage']             = $rq > 0 ? $mr / $rq : null;
		$r['impressions_per_page'] = $pv > 0 ? $im / $pv : null;
		return $r;
	}

	/** Soma métricas aditivas e reconstrói os pesos mensuráveis do Active View.
	 * A reconstrução exige impressões, mensurabilidade e visibilidade do mesmo
	 * universo AFC/AFV. As razões locais são arredondadas; preferir o agregado
	 * nativo do Google para decisões. Uma razão ausente não equivale a 100%.
	 * Tempo visível mantém uma aproximação separada, ponderada por impressões.
	 */
	public static function sum( $rows ) {
		$t = self::empty_row();
		$acc = array( 'viewability' => array( 0.0, 0.0 ), 'measurability' => array( 0.0, 0.0 ), 'view_time' => array( 0.0, 0.0 ) );
		$viewability_basis = 0.0;
		foreach ( (array) $rows as $row ) {
			foreach ( self::ADDITIVE as $k ) { $t[ $k ] += (float) ( $row[ $k ] ?? 0 ); }
			$w = max( 0.0, (float) ( $row['impressions'] ?? 0 ) );
			foreach ( $acc as $k => $pair ) {
				if ( ! isset( $row[ $k ] ) || ! is_numeric( $row[ $k ] ) || ! is_finite( (float) $row[ $k ] ) || $w <= 0 ) { continue; }
				$value = (float) $row[ $k ];
				if ( 'view_time' !== $k && ( $value < 0 || $value > 1 ) ) { continue; }
				$weight = $w;
				if ( 'viewability' === $k ) {
					if ( ! isset( $row['measurability'] ) || ! is_numeric( $row['measurability'] ) ) { continue; }
					$measurability = (float) $row['measurability'];
					if ( ! is_finite( $measurability ) || $measurability < 0 || $measurability > 1 ) { continue; }
					$weight *= $measurability;
					$viewability_basis += $w;
				}
				$acc[ $k ][0] += $value * $weight;
				$acc[ $k ][1] += $weight;
			}
		}
		foreach ( $acc as $k => $pair ) { $t[ $k ] = $pair[1] > 0 ? $pair[0] / $pair[1] : null; }
		$t['viewability_aggregation'] = 'reconstructed_measurable_impression_weighted_available_rows';
		$t['viewability_data_coverage'] = $t['impressions'] > 0 ? $viewability_basis / $t['impressions'] : null;
		$t['view_time_aggregation'] = 'impression_weighted_approximation';
		return self::derive( $t );
	}

	/** Coluna de um conjunto de linhas: date => valor. */
	public static function column( array $rows, $key, $until = '' ) {
		$out = array();
		foreach ( $rows as $date => $row ) {
			if ( $until && $date > $until ) { continue; }
			$out[ $date ] = (float) ( $row[ $key ] ?? 0 );
		}
		return $out;
	}

	public static function slice( array $rows, $from, $to ) {
		$out = array();
		foreach ( $rows as $date => $row ) { if ( $date >= $from && $date <= $to ) { $out[ $date ] = $row; } }
		return $out;
	}

	/** Resumo de um período: totais, médias por dia (dias completos), mediana, melhor/pior dia. */
	public static function summary( array $rows, $today ) {
		$complete = array();
		foreach ( $rows as $date => $row ) { if ( $date < $today ) { $complete[ $date ] = $row; } }
		$basis = $complete ? $complete : $rows;
		$total = self::sum( $rows );
		$basis_total = self::sum( $basis );
		$n = max( 1, count( $basis ) );
		$avg = array();
		foreach ( self::ADDITIVE as $k ) { $avg[ $k ] = $basis_total[ $k ] / $n; }
		foreach ( array( 'viewability', 'measurability', 'view_time' ) as $k ) { $avg[ $k ] = $basis_total[ $k ]; }
		$avg = self::derive( $avg );
		$vals = array(); $active = 0; $best_pv = array( 'date' => '', 'value' => 0.0 );
		foreach ( $basis as $date => $row ) {
			$vals[ $date ] = (float) $row['earnings'];
			if ( (float) $row['page_views'] > $best_pv['value'] ) { $best_pv = array( 'date' => $date, 'value' => (float) $row['page_views'] ); }
		}
		foreach ( $rows as $row ) { if ( (float) $row['earnings'] > 0 ) { $active++; } }
		$best = array( 'date' => '', 'value' => 0.0 ); $worst = array( 'date' => '', 'value' => 0.0 );
		if ( $vals ) {
			arsort( $vals ); $k = array_key_first( $vals ); $best = array( 'date' => (string) $k, 'value' => (float) $vals[ $k ] );
			asort( $vals ); $k = array_key_first( $vals ); $worst = array( 'date' => (string) $k, 'value' => (float) $vals[ $k ] );
		}
		$list = array_values( $vals );
		return array(
			'total' => $total, 'avg' => $avg, 'days' => count( $rows ), 'complete_days' => count( $complete ), 'active_days' => $active,
			'median' => self::median( $list ), 'stdev' => self::stdev( $list ), 'p25' => self::percentile( $list, 0.25 ), 'p75' => self::percentile( $list, 0.75 ),
			'best' => $best, 'worst' => $worst, 'best_page_views' => $best_pv, 'partial' => isset( $rows[ $today ] ),
		);
	}

	public static function group_key( $date, $by ) {
		switch ( $by ) {
			case 'week': return self::week_start( $date );
			case 'month': return substr( (string) $date, 0, 7 );
			case 'quarter': return substr( (string) $date, 0, 4 ) . '-T' . self::quarter_of( $date );
			case 'year': return substr( (string) $date, 0, 4 );
			default: return (string) $date;
		}
	}

	/** Agrupa linhas diárias por semana, mês, trimestre ou ano. */
	public static function group( array $rows, $by, $today = '' ) {
		$buckets = array();
		foreach ( $rows as $date => $row ) {
			$key = self::group_key( $date, $by );
			if ( ! isset( $buckets[ $key ] ) ) { $buckets[ $key ] = array( 'start' => $date, 'end' => $date, 'rows' => array() ); }
			$buckets[ $key ]['end'] = $date;
			$buckets[ $key ]['rows'][ $date ] = $row;
		}
		$out = array();
		foreach ( $buckets as $key => $b ) {
			$sum = self::sum( $b['rows'] );
			$vals = array(); $complete_e = 0.0; $complete_n = 0;
			foreach ( $b['rows'] as $d => $r ) {
				$vals[ $d ] = (float) $r['earnings'];
				if ( ! $today || $d < $today ) { $complete_e += (float) $r['earnings']; $complete_n++; }
			}
			arsort( $vals );
			$best = (string) array_key_first( $vals );
			$days = count( $b['rows'] );
			$out[ $key ] = $sum + array(
				'key' => (string) $key, 'start' => $b['start'], 'end' => $b['end'], 'days' => $days,
				'avg_earnings' => $complete_n ? $complete_e / $complete_n : $sum['earnings'] / max( 1, $days ),
				'best_date' => $best, 'best_value' => $best ? $vals[ $best ] : 0.0,
				'partial' => $today && $b['end'] >= $today,
			);
		}
		return $out;
	}

	public static function moving_average( array $values, $window ) {
		$values = array_values( $values ); $out = array(); $sum = 0.0; $window = max( 1, (int) $window );
		foreach ( $values as $i => $v ) {
			$sum += (float) $v;
			if ( $i >= $window ) { $sum -= (float) $values[ $i - $window ]; }
			$out[] = $i >= $window - 1 ? $sum / $window : null;
		}
		return $out;
	}

	/** Média por dia da semana nas últimas N semanas completas (segunda a domingo). */
	public static function weekday_profile( array $rows, $today, $weeks = 12 ) {
		$from = self::add_days( $today, -7 * (int) $weeks );
		$groups = array_fill( 0, 7, array() );
		foreach ( $rows as $date => $row ) {
			if ( $date >= $from && $date < $today ) { $groups[ self::weekday( $date ) ][ $date ] = $row; }
		}
		$all = 0.0; $count = 0;
		foreach ( $groups as $list ) { foreach ( $list as $r ) { $all += (float) $r['earnings']; $count++; } }
		$overall = $count ? $all / $count : 0.0;
		$out = array();
		foreach ( array( 1, 2, 3, 4, 5, 6, 0 ) as $w ) {
			$n = count( $groups[ $w ] ); $sum = self::sum( $groups[ $w ] );
			$avg = $n ? $sum['earnings'] / $n : 0.0;
			$out[ $w ] = array(
				'weekday' => $w, 'days' => $n, 'avg_earnings' => $avg, 'avg_page_views' => $n ? $sum['page_views'] / $n : 0.0,
				'avg_clicks' => $n ? $sum['clicks'] / $n : 0.0, 'page_rpm' => $sum['page_rpm'], 'ctr' => $sum['ctr'], 'index' => $overall > 0 ? $avg / $overall : null,
			);
		}
		return $out;
	}

	/** Recordes do histórico inteiro. */
	public static function records( array $rows, $today ) {
		$out = array( 'best_day' => null, 'best_page_views' => null, 'best_rpm' => null, 'best_week' => null, 'best_month' => null, 'best_year' => null, 'total' => 0.0, 'days' => 0, 'active_days' => 0 );
		$pvs = array();
		foreach ( $rows as $date => $row ) { if ( $date < $today && (float) $row['page_views'] > 0 ) { $pvs[] = (float) $row['page_views']; } }
		$pv_floor = max( 100.0, 0.3 * self::median( $pvs ) );
		foreach ( $rows as $date => $row ) {
			$e = (float) $row['earnings']; $pv = (float) $row['page_views'];
			$out['total'] += $e; $out['days']++;
			if ( $e > 0 ) { $out['active_days']++; }
			if ( $date >= $today ) { continue; }
			if ( ! $out['best_day'] || $e > $out['best_day']['value'] ) { $out['best_day'] = array( 'date' => $date, 'value' => $e ); }
			if ( ! $out['best_page_views'] || $pv > $out['best_page_views']['value'] ) { $out['best_page_views'] = array( 'date' => $date, 'value' => $pv ); }
			if ( $pv >= $pv_floor ) {
				$rpm = $e / $pv * 1000;
				if ( ! $out['best_rpm'] || $rpm > $out['best_rpm']['value'] ) { $out['best_rpm'] = array( 'date' => $date, 'value' => $rpm, 'page_views' => $pv ); }
			}
		}
		foreach ( self::group( $rows, 'week', $today ) as $w ) {
			if ( $w['days'] < 7 || $w['end'] >= $today ) { continue; }
			if ( ! $out['best_week'] || $w['earnings'] > $out['best_week']['value'] ) { $out['best_week'] = array( 'start' => $w['start'], 'end' => $w['end'], 'value' => $w['earnings'] ); }
		}
		foreach ( self::group( $rows, 'month', $today ) as $m ) {
			if ( ! $out['best_month'] || $m['earnings'] > $out['best_month']['value'] ) { $out['best_month'] = array( 'key' => $m['key'], 'value' => $m['earnings'], 'partial' => $m['partial'] ); }
		}
		foreach ( self::group( $rows, 'year', $today ) as $y ) {
			if ( ! $out['best_year'] || $y['earnings'] > $out['best_year']['value'] ) { $out['best_year'] = array( 'key' => $y['key'], 'value' => $y['earnings'], 'partial' => $y['partial'] ); }
		}
		return $out;
	}

	public static function delta( $current, $previous ) {
		if ( ! is_numeric( $current ) || ! is_numeric( $previous ) || abs( (float) $previous ) < 1e-9 ) { return null; }
		return ( (float) $current - (float) $previous ) / abs( (float) $previous );
	}

	/* ------------------------------------------------------------------ Estatística básica */

	public static function mean( array $v ) { return $v ? array_sum( $v ) / count( $v ) : 0.0; }

	public static function median( array $v ) {
		$v = array_values( $v ); $n = count( $v );
		if ( ! $n ) { return 0.0; }
		sort( $v );
		return $n % 2 ? (float) $v[ intdiv( $n, 2 ) ] : ( $v[ $n / 2 - 1 ] + $v[ $n / 2 ] ) / 2;
	}

	public static function percentile( array $v, $p ) {
		$v = array_values( $v ); $n = count( $v );
		if ( ! $n ) { return 0.0; }
		sort( $v );
		$pos = ( $n - 1 ) * (float) $p; $lo = (int) floor( $pos ); $hi = (int) ceil( $pos );
		return $v[ $lo ] + ( $v[ $hi ] - $v[ $lo ] ) * ( $pos - $lo );
	}

	public static function stdev( array $v ) {
		$n = count( $v );
		if ( $n < 2 ) { return 0.0; }
		$avg = array_sum( $v ) / $n; $s = 0.0;
		foreach ( $v as $x ) { $s += ( $x - $avg ) * ( $x - $avg ); }
		return sqrt( $s / ( $n - 1 ) );
	}

	public static function mad( array $v ) {
		if ( ! $v ) { return 0.0; }
		$med = self::median( $v ); $dev = array();
		foreach ( $v as $x ) { $dev[] = abs( $x - $med ); }
		return self::median( $dev );
	}

	public static function normal_cdf( $z ) {
		$z = (float) $z;
		$t = 1 / ( 1 + 0.2316419 * abs( $z ) );
		$d = 0.3989423 * exp( -$z * $z / 2 );
		$p = $d * $t * ( 0.3193815 + $t * ( -0.3565638 + $t * ( 1.781478 + $t * ( -1.821256 + $t * 1.330274 ) ) ) );
		return $z > 0 ? 1 - $p : $p;
	}

	/* ------------------------------------------------------------------ Períodos */

	public static function presets() {
		return array(
			'Rápidos' => array( 'today' => 'Hoje', 'yesterday' => 'Ontem', 'last_7' => 'Últimos 7 dias', 'last_14' => 'Últimos 14 dias', 'last_28' => 'Últimos 28 dias', 'last_30' => 'Últimos 30 dias', 'last_60' => 'Últimos 60 dias', 'last_90' => 'Últimos 90 dias', 'last_180' => 'Últimos 180 dias', 'last_365' => 'Últimos 365 dias' ),
			'Calendário' => array( 'this_week' => 'Esta semana', 'last_week' => 'Semana passada', 'this_month' => 'Este mês', 'last_month' => 'Mês passado', 'this_quarter' => 'Este trimestre', 'last_quarter' => 'Trimestre passado', 'this_year' => 'Este ano', 'last_year' => 'Ano passado', 'last_12_months' => 'Últimos 12 meses completos' ),
			'Outros' => array( 'all' => 'Todo o histórico', 'custom' => 'Personalizado' ),
		);
	}

	public static function preset_label( $preset ) {
		foreach ( self::presets() as $group ) { if ( isset( $group[ $preset ] ) ) { return $group[ $preset ]; } }
		return 'Personalizado';
	}

	/**
	 * Resolve um preset em datas. Janelas "Últimos N dias" terminam ontem (como no AdSense);
	 * com $include_today a janela avança até hoje. Presets de calendário incluem hoje.
	 */
	public static function resolve_range( $preset, $from, $to, $today, $first_day = '', $include_today = false ) {
		$y = self::add_days( $today, -1 );
		$start = $today; $end = $today;
		if ( preg_match( '/^last_(\d+)$/', (string) $preset, $m ) ) {
			$n = max( 1, min( 3650, (int) $m[1] ) );
			$start = self::add_days( $y, -( $n - 1 ) ); $end = $include_today ? $today : $y;
		} else {
			switch ( $preset ) {
				case 'today': break;
				case 'yesterday': $start = $y; $end = $y; break;
				case 'this_week': $start = self::week_start( $today ); break;
				case 'last_week': $start = self::add_days( self::week_start( $today ), -7 ); $end = self::add_days( $start, 6 ); break;
				case 'this_month': $start = self::month_start( $today ); break;
				case 'last_month': $start = self::shift_months( self::month_start( $today ), -1 ); $end = self::month_end( $start ); break;
				case 'this_quarter': $start = self::quarter_start( $today ); break;
				case 'last_quarter': $start = self::shift_months( self::quarter_start( $today ), -3 ); $end = self::quarter_end( $start ); break;
				case 'this_year': $start = substr( $today, 0, 4 ) . '-01-01'; break;
				case 'last_year': $start = ( (int) substr( $today, 0, 4 ) - 1 ) . '-01-01'; $end = ( (int) substr( $today, 0, 4 ) - 1 ) . '-12-31'; break;
				case 'last_12_months': $start = self::shift_months( self::month_start( $today ), -12 ); $end = self::add_days( self::month_start( $today ), -1 ); break;
				case 'all': $start = $first_day && $first_day <= $today ? $first_day : self::add_days( $today, -29 ); break;
				default:
					$preset = 'custom';
					$start = self::valid_date( $from ) ? $from : self::add_days( $y, -29 );
					$end = self::valid_date( $to ) ? $to : $today;
					if ( $start > $end ) { $tmp = $start; $start = $end; $end = $tmp; }
					if ( $end > $today ) { $end = $today; }
					if ( $start > $end ) { $start = $end; }
					if ( self::days_between( $start, $end ) > 7300 ) { $start = self::add_days( $end, -7300 ); }
			}
		}
		return array( 'preset' => (string) $preset, 'start' => $start, 'end' => $end, 'label' => self::preset_label( $preset ), 'days' => self::days_between( $start, $end ) + 1 );
	}

	/** Período de comparação: anterior equivalente (alinhado ao calendário quando faz sentido) ou mesmo período do ano anterior. */
	public static function compare_range( array $range, $mode = 'previous' ) {
		$start = $range['start']; $end = $range['end']; $preset = $range['preset'] ?? 'custom';
		if ( 'year' === $mode ) {
			$s = self::shift_years( $start, -1 ); $e = self::shift_years( $end, -1 );
			return array( 'start' => $s, 'end' => $e, 'label' => 'mesmo período do ano anterior', 'days' => self::days_between( $s, $e ) + 1 );
		}
		switch ( $preset ) {
			case 'this_week': case 'last_week':
				$s = self::add_days( $start, -7 ); $e = self::add_days( $end, -7 );
				$label = 'this_week' === $preset ? 'mesmos dias da semana anterior' : 'semana anterior'; break;
			case 'this_month': case 'last_month':
				$s = self::shift_months( $start, -1 ); $e = 'last_month' === $preset ? self::month_end( $s ) : self::shift_months( $end, -1 );
				$label = 'this_month' === $preset ? 'mesmos dias do mês anterior' : 'mês anterior'; break;
			case 'this_quarter': case 'last_quarter':
				$s = self::shift_months( $start, -3 ); $e = 'last_quarter' === $preset ? self::quarter_end( $s ) : self::shift_months( $end, -3 );
				$label = 'this_quarter' === $preset ? 'mesmo trecho do trimestre anterior' : 'trimestre anterior'; break;
			case 'this_year': case 'last_year':
				$s = self::shift_years( $start, -1 ); $e = self::shift_years( $end, -1 );
				$label = 'this_year' === $preset ? 'mesmo trecho do ano anterior' : 'ano anterior'; break;
			case 'last_12_months':
				$s = self::shift_months( $start, -12 ); $e = self::add_days( $start, -1 ); $label = '12 meses anteriores'; break;
			default:
				$len = self::days_between( $start, $end ) + 1;
				$s = self::add_days( $start, -$len ); $e = self::add_days( $start, -1 );
				$label = $len . ' ' . ( 1 === $len ? 'dia anterior' : 'dias anteriores' );
		}
		return array( 'start' => $s, 'end' => $e, 'label' => $label, 'days' => self::days_between( $s, $e ) + 1 );
	}

	/* ------------------------------------------------------------------ Previsão */

	/**
	 * Modelo diário: nível (média exponencial) + tendência amortecida (Theil–Sen),
	 * fatores por dia da semana (razão à média móvel centrada, mediana) e, com 1+ ano de histórico,
	 * sazonalidade anual relativa à janela recente. Incerteza calibrada por backtest de 1 dia.
	 *
	 * @param array  $series    date => valor, apenas dias completos.
	 * @param string $yesterday último dia completo.
	 */
	public static function build_model( array $series, $yesterday, array $opts = array() ) {
		$last = self::day_num( $yesterday );
		$first = null;
		foreach ( $series as $date => $v ) {
			if ( ! self::valid_date( (string) $date ) ) { continue; }
			$num = self::day_num( $date );
			if ( $num <= $last && ( null === $first || $num < $first ) ) { $first = $num; }
		}
		$empty = array( 'ok' => false, 'n' => 0, 'first' => $last, 'last' => $last, 'S' => array_fill( 0, 7, 1.0 ), 'season' => array( 'ok' => false, 'years' => 0 ), 'phi' => self::PHI, 'level' => 0.0, 'raw_level' => 0.0, 'trend' => 0.0, 'sigma_rel' => 0.6, 'cal' => array( 's1' => 0.6, 's7' => 0.5, 's28' => 0.45, 'gamma' => 0.35, 'origins' => 0 ), 'rho' => 0.35, 'mape' => null, 'backtest_days' => 0, 'bias' => 0.0 );
		if ( null === $first ) { return $empty; }
		// A missing/failed collection is not a zero-revenue day. Model only the
		// observed contiguous tail; an explicit numeric zero remains valid data.
		for ( $i = $last; $i >= $first; $i-- ) {
			$d = self::num_day( $i );
			if ( ! array_key_exists( $d, $series ) || ! is_numeric( $series[ $d ] ) || ! is_finite( (float) $series[ $d ] ) ) { $first = $i + 1; break; }
		}
		if ( $first > $last ) { return $empty; }
		$vals = array();
		for ( $i = $first; $i <= $last; $i++ ) { $d = self::num_day( $i ); $vals[] = max( 0.0, (float) $series[ $d ] ); }
		$n = count( $vals );
		if ( $n < 3 || array_sum( $vals ) <= 0 ) { return array_merge( $empty, array( 'n' => $n, 'first' => $first, 'level' => self::mean( $vals ), 'raw_level' => self::mean( $vals ), 'ok' => $n > 0 && array_sum( $vals ) > 0 ) ); }

		$prefix = array( 0.0 );
		foreach ( $vals as $i => $v ) { $prefix[ $i + 1 ] = $prefix[ $i ] + $v; }

		// Fatores por dia da semana.
		$S = array_fill( 0, 7, 1.0 );
		$win = min( $n, 84 );
		if ( $win >= 14 ) {
			$ratios = array_fill( 0, 7, array() );
			for ( $k = $n - $win + 3; $k < $n - 3; $k++ ) {
				$center = ( $prefix[ $k + 4 ] - $prefix[ $k - 3 ] ) / 7;
				if ( $center > 0 ) { $ratios[ self::weekday_num( $first + $k ) ][] = $vals[ $k ] / $center; }
			}
			for ( $w = 0; $w < 7; $w++ ) {
				$c = count( $ratios[ $w ] );
				if ( $c >= 2 ) { $S[ $w ] = 1 + ( self::median( $ratios[ $w ] ) - 1 ) * $c / ( $c + 2 ); }
			}
			$mean = array_sum( $S ) / 7;
			foreach ( $S as $w => $f ) { $S[ $w ] = min( 1.8, max( 0.5, $mean > 0 ? $f / $mean : 1.0 ) ); }
		}

		// Sazonalidade anual: exige a janela recente de 28 dias também no ano anterior.
		$season = array( 'ok' => false, 'years' => 0 );
		if ( $n >= 364 + 28 && ( $opts['season'] ?? true ) ) {
			$bases = array();
			foreach ( array( 1, 2 ) as $yb ) {
				$a = $n - 28 - 364 * $yb; $b = $n - 1 - 364 * $yb;
				if ( $a < 0 ) { break; }
				$avg = ( $prefix[ $b + 1 ] - $prefix[ $a ] ) / 28;
				if ( $avg > 0 ) { $bases[ $yb ] = $avg; }
			}
			if ( $bases ) { $season = array( 'ok' => true, 'years' => count( $bases ), 'bases' => $bases, 'prefix' => $prefix, 'first' => $first, 'n' => $n ); }
		}
		// A razão sazonal já carrega a trajetória do ano anterior; a tendência recente então se dissipa mais rápido.
		$phi = (float) ( $season['ok'] ? ( $opts['season_phi'] ?? 0.85 ) : ( $opts['phi'] ?? self::PHI ) );

		$fit = self::fit_level( $vals, $first, $n - 1, $S, $season, $phi );

		// Backtest: previsão de 1 dia à frente nos últimos até 28 dias.
		$errors = array(); $abs = 0.0; $act = 0.0;
		$bt = min( 28, $n - 14 );
		if ( $bt >= 7 ) {
			for ( $k = $n - $bt; $k < $n; $k++ ) {
				$f_fit = self::fit_level( $vals, $first, $k - 1, $S, $season, $phi );
				$num = $first + $k;
				$f = max( 0.0, $f_fit['level'] + $f_fit['trend'] * $phi ) * $S[ self::weekday_num( $num ) ] * self::season_factor( $season, $num );
				$e = $vals[ $k ] - $f;
				$abs += abs( $e ); $act += $vals[ $k ];
				$errors[] = $f > 0 ? max( -3.0, min( 3.0, $e / $f ) ) : ( $vals[ $k ] > 0 ? 1.0 : 0.0 );
			}
		}
		$sigma = $n < 14 ? 0.5 : 0.35; $rho = 0.35; $bias = 0.0;
		if ( count( $errors ) >= 7 ) {
			$sigma = self::spread( $errors, 0.04 );
			$bias = self::median( $errors );
			if ( count( $errors ) >= 10 ) {
				$m = self::mean( $errors ); $num_c = 0.0; $den_c = 0.0;
				foreach ( $errors as $i => $e ) { $den_c += ( $e - $m ) * ( $e - $m ); if ( $i > 0 ) { $num_c += ( $e - $m ) * ( $errors[ $i - 1 ] - $m ); } }
				$rho = $den_c > 0 ? min( 0.75, max( 0.15, $num_c / $den_c ) ) : 0.35;
			}
		}

		// Calibração multi-horizonte: erro de somas de 7 e 28 dias previstas a partir de origens semanais passadas.
		$rel7 = array(); $rel28 = array();
		for ( $k = $n - 28; $k >= max( 21, $n - 28 - 7 * 30 ); $k -= 7 ) {
			$o_fit = self::fit_level( $vals, $first, $k - 1, $S, $season, $phi );
			$f7 = 0.0; $a7 = 0.0; $f28 = 0.0; $a28 = 0.0;
			for ( $h = 1; $h <= 28; $h++ ) {
				$num = $first + $k + $h - 1;
				$f = max( 0.0, $o_fit['level'] + $o_fit['trend'] * self::damp( $phi, $h ) ) * $S[ self::weekday_num( $num ) ] * self::season_factor( $season, $num );
				if ( $h <= 7 ) { $f7 += $f; $a7 += $vals[ $k + $h - 1 ]; }
				$f28 += $f; $a28 += $vals[ $k + $h - 1 ];
			}
			if ( $f7 > 0 ) { $rel7[] = max( -3.0, min( 3.0, ( $a7 - $f7 ) / $f7 ) ); }
			if ( $f28 > 0 ) { $rel28[] = max( -3.0, min( 3.0, ( $a28 - $f28 ) / $f28 ) ); }
		}
		$origins = count( $rel28 );
		if ( $origins >= 5 ) {
			$s7 = self::spread( $rel7, 0.03 ); $s28 = self::spread( $rel28, 0.03 );
		} else {
			$s7 = max( 0.15, 0.8 * $sigma ); $s28 = max( 0.15, 0.7 * $sigma );
		}
		$gamma = $origins >= 5 && $s7 > 0 ? min( 0.5, max( 0.15, log( max( $s28, 1e-6 ) / $s7 ) / log( 4 ) ) ) : 0.35;
		$cal = array( 's1' => $sigma, 's7' => $s7, 's28' => $s28, 'gamma' => $gamma, 'origins' => $origins );

		// Correção de viés: picos virais são aparados no nível, mas entram nas somas reais.
		// Se as somas de 28 dias vinham sistematicamente acima/abaixo, compensa 70% disso (limitado a ±12%).
		$adjust = 1.0;
		if ( $origins >= 8 && ( $opts['bias_correction'] ?? true ) ) {
			$sorted = $rel28; sort( $sorted );
			$trim = (int) floor( count( $sorted ) * 0.1 );
			$core = array_slice( $sorted, $trim, count( $sorted ) - 2 * $trim );
			$adjust = 1 + max( -0.12, min( 0.12, 0.7 * self::mean( $core ) ) );
		}

		return array(
			'ok' => true, 'n' => $n, 'first' => $first, 'last' => $last, 'S' => $S, 'season' => $season, 'phi' => $phi, 'adjust' => $adjust,
			'level' => $fit['level'], 'raw_level' => $fit['raw_level'], 'trend' => $fit['trend'],
			'sigma_rel' => $sigma, 'cal' => $cal, 'rho' => $rho, 'mape' => $act > 0 ? $abs / $act : null, 'backtest_days' => count( $errors ), 'bias' => $bias,
		);
	}

	/** Dispersão relativa robusta usada nas faixas: o maior entre o P80 dos erros absolutos (em escala normal) e o MAD. */
	private static function spread( array $errors, $floor ) {
		$abs = array();
		foreach ( $errors as $e ) { $abs[] = abs( $e ); }
		return min( 1.5, max( (float) $floor, self::percentile( $abs, 0.8 ) / self::Z80, 1.4826 * self::mad( $errors ) ) );
	}

	private static function damp( $phi, $h ) {
		return $phi >= 1 ? (float) $h : $phi * ( 1 - pow( $phi, $h ) ) / ( 1 - $phi );
	}

	/** Erro relativo esperado de uma soma de k dias, interpolado (log) entre os horizontes calibrados. */
	public static function sigma_for( array $model, $k ) {
		$cal = (array) ( $model['cal'] ?? array() );
		$s1 = max( 0.02, (float) ( $cal['s1'] ?? 0.6 ) ); $s7 = max( 0.02, (float) ( $cal['s7'] ?? 0.5 ) ); $s28 = max( 0.02, (float) ( $cal['s28'] ?? 0.45 ) );
		$k = max( 1.0, (float) $k );
		if ( $k <= 7 ) { return exp( log( $s1 ) + ( log( $s7 ) - log( $s1 ) ) * log( $k ) / log( 7 ) ); }
		if ( $k <= 28 ) { return exp( log( $s7 ) + ( log( $s28 ) - log( $s7 ) ) * log( $k / 7 ) / log( 4 ) ); }
		return min( 1.5, $s28 * pow( $k / 28, (float) ( $cal['gamma'] ?? 0.35 ) ) );
	}

	private static function fit_level( array $vals, $first, $end, array $S, array $season, $phi = self::PHI ) {
		$start = max( 0, $end - 55 );
		$D = array(); $ages = array();
		for ( $k = $start; $k <= $end; $k++ ) {
			$num = $first + $k;
			$den = $S[ self::weekday_num( $num ) ] * self::season_factor( $season, $num );
			$D[] = $den > 0.05 ? $vals[ $k ] / $den : $vals[ $k ];
			$ages[] = $end - $k;
		}
		$m = count( $D );
		if ( ! $m ) { return array( 'level' => 0.0, 'raw_level' => 0.0, 'trend' => 0.0 ); }
		$med = self::median( $D ); $mad = 1.4826 * self::mad( $D );
		if ( $mad > 0 ) {
			foreach ( $D as $i => $x ) { $D[ $i ] = min( $med + 3.5 * $mad, max( $med - 3.5 * $mad, $x ) ); }
		}
		$ws = 0.0; $vs = 0.0; $as = 0.0;
		foreach ( $D as $i => $x ) { $w = exp( -$ages[ $i ] / 10 ); $ws += $w; $vs += $w * $x; $as += $w * $ages[ $i ]; }
		$level = $ws > 0 ? $vs / $ws : 0.0; $mean_age = $ws > 0 ? $as / $ws : 0.0;
		$trend = 0.0; $t = min( 28, $m );
		if ( $t >= 14 ) {
			$slopes = array(); $off = $m - $t;
			for ( $i = 0; $i < $t; $i++ ) {
				for ( $j = $i + 1; $j < $t; $j++ ) { $slopes[] = ( $D[ $off + $j ] - $D[ $off + $i ] ) / ( $j - $i ); }
			}
			$trend = self::median( $slopes );
		}
		$cap = 0.30 * max( 0.0, $level ) * ( 1 - $phi ) / max( 0.01, $phi ); // efeito máximo acumulado da tendência: ±30% do nível.
		$trend = max( -$cap, min( $cap, $trend ) );
		$now = max( 0.5 * $level, min( 1.5 * $level, $level + $trend * $mean_age ) );
		return array( 'level' => max( 0.0, $now ), 'raw_level' => max( 0.0, $level ), 'trend' => $trend );
	}

	public static function season_factor( array $season, $num ) {
		if ( empty( $season['ok'] ) ) { return 1.0; }
		$logs = array();
		foreach ( $season['bases'] as $yb => $base ) {
			$c = (int) $num - 364 * (int) $yb - (int) $season['first'];
			$a = max( 0, $c - 15 ); $b = min( (int) $season['n'] - 1, $c + 15 );
			if ( $b - $a + 1 < 21 ) { continue; }
			$avg = ( $season['prefix'][ $b + 1 ] - $season['prefix'][ $a ] ) / ( $b - $a + 1 );
			if ( $avg > 0 && $base > 0 ) { $logs[] = log( $avg / $base ); }
		}
		if ( ! $logs ) { return 1.0; }
		$shrink = count( $logs ) >= 2 ? 0.8 : 0.65;
		return min( 1.7, max( 0.6, exp( $shrink * array_sum( $logs ) / count( $logs ) ) ) );
	}

	/** Previsão pontual para um dia (número de dias UTC). */
	public static function predict( array $model, $num ) {
		if ( empty( $model['ok'] ) ) { return 0.0; }
		$h = max( 1, (int) $num - (int) $model['last'] );
		$base = max( 0.0, $model['level'] + $model['trend'] * self::damp( (float) ( $model['phi'] ?? self::PHI ), $h ) );
		return $base * (float) ( $model['adjust'] ?? 1.0 ) * $model['S'][ self::weekday_num( $num ) ] * self::season_factor( $model['season'], $num );
	}

	public static function predict_date( array $model, $date ) { return self::predict( $model, self::day_num( $date ) ); }

	/** Curva padrão de acumulação da receita ao longo do dia (audiência brasileira, atraso de ~45 min). */
	public static function default_profile() {
		$weights = array( 3.0, 2.0, 1.4, 1.0, 0.8, 0.9, 1.5, 2.5, 3.5, 4.3, 4.8, 5.1, 5.3, 5.3, 5.3, 5.3, 5.3, 5.4, 5.6, 5.9, 6.2, 6.2, 5.4, 4.3 );
		$total = array_sum( $weights ); $curve = array();
		for ( $b = 0; $b < 48; $b++ ) {
			$t = ( $b + 1 ) * 30 - 45;
			$acc = 0.0;
			if ( $t > 0 ) {
				$h = (int) floor( $t / 60 );
				for ( $i = 0; $i < min( 24, $h ); $i++ ) { $acc += $weights[ $i ]; }
				if ( $h < 24 ) { $acc += $weights[ $h ] * ( ( $t - 60 * $h ) / 60 ); }
			}
			$curve[ $b ] = min( 1.0, $acc / $total );
		}
		return array( 'curve' => $curve, 'err' => array_fill( 0, 48, null ), 'days' => 0, 'source' => 'default' );
	}

	/**
	 * Aprende a curva intradiária com os instantâneos que o plugin grava durante o dia.
	 *
	 * @param array $intraday date => [ [minuto, receita, ...], ... ]
	 * @param array $finals   date => receita final do dia
	 */
	public static function learn_profile( array $intraday, array $finals, $today ) {
		$default = self::default_profile();
		$samples = array_fill( 0, 48, array() );
		$days = 0; $limit = self::add_days( $today, -2 );
		foreach ( $intraday as $date => $points ) {
			if ( $date > $limit || empty( $finals[ $date ] ) || (float) $finals[ $date ] <= 0 ) { continue; }
			$points = array_values( array_filter( (array) $points, 'is_array' ) );
			if ( count( $points ) < 12 ) { continue; }
			usort( $points, static function( $a, $b ) { return $a[0] <=> $b[0]; } );
			$final = (float) $finals[ $date ]; $used = false;
			for ( $b = 0; $b < 48; $b++ ) {
				$t = ( $b + 1 ) * 30; $prev = null; $next = null;
				foreach ( $points as $p ) {
					if ( $p[0] <= $t ) { $prev = $p; } else { $next = $p; break; }
				}
				if ( $prev && $next ) {
					if ( $t - $prev[0] > 45 && $next[0] - $t > 45 ) { continue; }
					$val = $prev[1] + ( $next[1] - $prev[1] ) * ( $t - $prev[0] ) / max( 1, $next[0] - $prev[0] );
				} elseif ( $prev ) {
					if ( $t - $prev[0] > 45 ) { continue; }
					$val = $prev[1];
				} elseif ( $next ) {
					if ( $next[0] - $t > 45 ) { continue; }
					$val = $next[1] * $t / max( 1, $next[0] );
				} else {
					continue;
				}
				$samples[ $b ][] = min( 1.2, max( 0.0, $val / $final ) );
				$used = true;
			}
			if ( $used ) { $days++; }
		}
		if ( $days < 3 ) { return $default; }
		$curve = array(); $err = array(); $running = 0.0;
		for ( $b = 0; $b < 48; $b++ ) {
			if ( count( $samples[ $b ] ) >= 3 ) {
				$med = self::median( $samples[ $b ] );
				$learned_err = max( 0.02, 1.4826 * self::mad( $samples[ $b ] ) / max( $med, 0.03 ) );
				$weight = min( 1.0, count( $samples[ $b ] ) / 10 );
				$curve[ $b ] = $weight * $med + ( 1 - $weight ) * $default['curve'][ $b ];
				$err[ $b ] = $learned_err;
			} else {
				$curve[ $b ] = $default['curve'][ $b ]; $err[ $b ] = null;
			}
			$running = max( $running, min( 1.0, $curve[ $b ] ) );
			$curve[ $b ] = $running;
		}
		return array( 'curve' => $curve, 'err' => $err, 'days' => $days, 'source' => 'learned' );
	}

	public static function profile_at( array $profile, $minute ) {
		$minute = max( 0.0, min( 1440.0, (float) $minute ) );
		$curve = $profile['curve'];
		if ( $minute < 30 ) { return $curve[0] * $minute / 30; }
		$pos = $minute / 30 - 1; $i = (int) floor( $pos ); $frac = $pos - $i;
		$a = $curve[ min( 47, $i ) ]; $b = $curve[ min( 47, $i + 1 ) ];
		return $a + ( $b - $a ) * $frac;
	}

	private static function profile_error( array $profile, $minute, $fraction ) {
		$default = 0.12 * sqrt( max( 0.0, 1 - $fraction ) / max( $fraction, 0.03 ) ) + 0.02;
		$b = max( 0, min( 47, (int) round( $minute / 30 ) - 1 ) );
		$learned = $profile['err'][ $b ] ?? null;
		if ( null === $learned ) { return min( 2.0, $default ); }
		$w = min( 1.0, (int) $profile['days'] / 14 );
		return min( 2.0, max( 0.02, $w * $learned + ( 1 - $w ) * $default ) );
	}

	/** Estimativa de hoje até 23:59: combina o ritmo intradiário e o modelo por variância inversa. */
	public static function today_estimate( array $model, $partial, $minute, array $profile ) {
		$partial = max( 0.0, (float) $partial );
		$C = self::profile_at( $profile, $minute );
		$F = ! empty( $model['ok'] ) ? self::predict( $model, $model['last'] + 1 ) : 0.0;
		$r_m = ! empty( $model['ok'] ) ? max( 0.05, (float) $model['sigma_rel'] ) : 0.6;
		$pace = $C >= 0.03 ? $partial / $C : null;
		$wp = 0.0;
		if ( null === $pace && $F <= 0 ) {
			$T = $partial; $rel = 1.0;
		} elseif ( null === $pace ) {
			$T = $F; $rel = $r_m;
		} else {
			$r_p = self::profile_error( $profile, $minute, $C );
			if ( $F <= 0 ) {
				$T = $pace; $rel = $r_p; $wp = 1.0;
			} else {
				$ip = 1 / ( $r_p * $r_p ); $im = 1 / ( $r_m * $r_m );
				$wp = $ip / ( $ip + $im ); $T = $wp * $pace + ( 1 - $wp ) * $F; $rel = sqrt( 1 / ( $ip + $im ) );
			}
		}
		$T = max( $T, $partial ); $sigma = $T * $rel;
		return array(
			'partial' => $partial, 'projected' => $T, 'low' => max( $partial, $T - self::Z80 * $sigma ), 'high' => $T + self::Z80 * $sigma,
			'sigma' => $sigma, 'rel' => $rel, 'pace' => $pace, 'model' => $F, 'pace_weight' => $wp, 'fraction' => $C,
			'confidence' => $rel <= 0.08 ? 'alta' : ( $rel <= 0.2 ? 'média' : 'baixa' ),
		);
	}

	/**
	 * Projeção de um intervalo: realizado (dias completos + hoje parcial) + restante de hoje + dias futuros.
	 *
	 * @param array $actual    date => valor realizado (até hoje).
	 * @param array $today_est resultado de today_estimate() (pode ser vazio se hoje não estiver no intervalo).
	 */
	public static function project_range( array $model, array $actual, array $today_est, $start, $end, $today ) {
		$t = self::day_num( $today ); $s = self::day_num( $start ); $e = self::day_num( $end );
		$realized = 0.0;
		for ( $i = $s; $i <= min( $e, $t - 1 ); $i++ ) { $realized += (float) ( $actual[ self::num_day( $i ) ] ?? 0 ); }
		$partial = 0.0; $today_rem = 0.0; $var = 0.0; $has_today = $t >= $s && $t <= $e;
		if ( $has_today && $today_est ) {
			$partial = (float) $today_est['partial']; $today_rem = max( 0.0, (float) $today_est['projected'] - $partial );
			$var += pow( (float) $today_est['sigma'], 2 );
		}
		$sum = 0.0; $hsum = 0; $k = 0; $daily = array();
		$last = (int) ( $model['last'] ?? ( $t - 1 ) );
		for ( $i = max( $s, $t + 1 ); $i <= $e; $i++ ) {
			$f = self::predict( $model, $i );
			$sd = self::sigma_for( $model, 1 + max( 0, $i - $last - 1 ) / 7 ); // erro diário cresce devagar com o horizonte.
			$sum += $f; $hsum += $i - $last; $k++;
			$daily[ self::num_day( $i ) ] = array( 'value' => $f, 'low' => max( 0.0, $f * ( 1 - self::Z80 * $sd ) ), 'high' => $f * ( 1 + self::Z80 * $sd ) );
		}
		$sigma_future = 0.0;
		if ( $k ) {
			// Janela que começa longe (ex.: próximo mês) herda o erro do horizonte médio, não só do tamanho.
			$k_eff = max( $k, 2 * ( $hsum / $k ) - 1 );
			$sigma_future = self::sigma_for( $model, $k_eff ) * $sum;
		}
		$sigma_today = sqrt( $var );
		$sigma = sqrt( $sigma_today * $sigma_today + $sigma_future * $sigma_future + $sigma_today * $sigma_future ); // correlação ~0,5 entre hoje e os próximos dias.
		$projected = $realized + $partial + $today_rem + $sum;
		$floor = $realized + $partial;
		return array(
			'start' => $start, 'end' => $end, 'realized' => $floor, 'remaining' => $today_rem + $sum, 'projected' => $projected,
			'low' => max( $floor, $projected - self::Z80 * $sigma ), 'high' => $projected + self::Z80 * $sigma, 'sigma' => $sigma,
			'days' => $e - $s + 1, 'days_left' => $k + ( $has_today ? 1 : 0 ), 'future_days' => $k, 'daily' => $daily, 'has_today' => $has_today,
		);
	}

	public static function goal_probability( $goal, array $projection ) {
		$goal = (float) $goal;
		if ( $goal <= 0 ) { return null; }
		if ( $projection['realized'] >= $goal ) { return 1.0; }
		if ( $projection['sigma'] <= 0 ) { return $projection['projected'] >= $goal ? 1.0 : 0.0; }
		return 1 - self::normal_cdf( ( $goal - $projection['projected'] ) / $projection['sigma'] );
	}

	/** Métodos alternativos para comparação: ritmo de 7 e 30 dias e ano anterior ajustado pelo crescimento. */
	public static function alt_methods( array $actual, $first_day, $start, $end, $today, array $today_est ) {
		$y = self::add_days( $today, -1 );
		$realized = 0.0; $future = 0; $has_today = $today >= $start && $today <= $end;
		for ( $d = $start; $d <= $end; $d = self::add_days( $d, 1 ) ) {
			if ( $d < $today ) { $realized += (float) ( $actual[ $d ] ?? 0 ); } elseif ( $d > $today ) { $future++; }
		}
		$partial = $has_today ? (float) ( $today_est['partial'] ?? 0 ) : 0.0;
		$frac = $has_today ? (float) ( $today_est['fraction'] ?? 0 ) : 0.0;
		$avg = function( $days ) use ( $actual, $y, $first_day ) {
			$sum = 0.0; $n = 0;
			for ( $i = 0; $i < $days; $i++ ) {
				$d = self::add_days( $y, -$i );
				if ( $first_day && $d < $first_day ) { break; }
				$sum += (float) ( $actual[ $d ] ?? 0 ); $n++;
			}
			return $n ? $sum / $n : null;
		};
		$out = array( 'pace7' => null, 'pace30' => null, 'last_year' => null, 'growth' => null );
		foreach ( array( 'pace7' => 7, 'pace30' => 30 ) as $key => $days ) {
			$a = $avg( $days );
			if ( null !== $a ) { $out[ $key ] = $realized + $partial + ( $has_today ? max( 0.0, $a * ( 1 - $frac ) ) : 0.0 ) + $a * $future; }
		}
		$window_start = self::add_days( $y, -27 );
		if ( $first_day && self::shift_years( $window_start, -1 ) >= $first_day ) {
			$now = 0.0; $then = 0.0;
			for ( $d = $window_start; $d <= $y; $d = self::add_days( $d, 1 ) ) { $now += (float) ( $actual[ $d ] ?? 0 ); $then += (float) ( $actual[ self::shift_years( $d, -1 ) ] ?? 0 ); }
			if ( $then > 0 ) {
				$growth = max( 0.2, min( 5.0, $now / $then ) ); $rem = 0.0;
				for ( $d = max( $start, $today ); $d <= $end; $d = self::add_days( $d, 1 ) ) {
					$ly = (float) ( $actual[ self::shift_years( $d, -1 ) ] ?? 0 );
					$rem += $d === $today ? $ly * ( 1 - $frac ) : $ly;
				}
				$out['last_year'] = $realized + $partial + $growth * $rem;
				$out['growth'] = $growth;
			}
		}
		return $out;
	}
}
