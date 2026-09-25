<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Aba Dias: todos os dias (ou semanas, meses...) de qualquer período, com totais, médias e comparação. */
final class GOAC_View_Days {
	const GROUPS = array( 'day' => 'Dia', 'week' => 'Semana', 'month' => 'Mês', 'quarter' => 'Trimestre', 'year' => 'Ano' );
	const COMPARE = array( 'previous' => 'Período anterior', 'year' => 'Mesmo período do ano anterior', 'none' => 'Sem comparação' );

	public static function params() {
		list( $range, $include_today ) = GOAC_UI::request_range( 'last_30', true );
		$group = isset( $_GET['group'] ) ? sanitize_key( wp_unslash( $_GET['group'] ) ) : 'day'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$compare = isset( $_GET['compare'] ) ? sanitize_key( wp_unslash( $_GET['compare'] ) ) : 'previous'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! isset( self::GROUPS[ $group ] ) ) { $group = 'day'; }
		if ( ! isset( self::COMPARE[ $compare ] ) ) { $compare = 'previous'; }
		if ( 'day' !== $group && $range['days'] < 8 ) { $group = 'day'; }
		return array( 'range' => $range, 'include_today' => $include_today, 'group' => $group, 'compare' => $compare );
	}

	private static function shift( $date, $group, $years = false ) {
		if ( $years ) { return 'week' === $group ? GOAC_Stats::add_days( $date, -364 ) : GOAC_Stats::shift_years( $date, -1 ); }
		switch ( $group ) {
			case 'week': return GOAC_Stats::add_days( $date, -7 );
			case 'month': return GOAC_Stats::shift_months( $date, -1 );
			case 'quarter': return GOAC_Stats::shift_months( $date, -3 );
			case 'year': return GOAC_Stats::shift_years( $date, -1 );
			default: return GOAC_Stats::add_days( $date, -1 );
		}
	}

	public static function dataset( array $p ) {
		$c = GOAC_UI::context();
		$range = $p['range']; $today = $c['today'];
		$rows = GOAC_UI::rows( $range['start'], $range['end'] );
		$summary = GOAC_Stats::summary( $rows, $today );
		$cmp = 'none' === $p['compare'] ? null : GOAC_Stats::compare_range( $range, $p['compare'] );
		$cmp_rows = $cmp ? GOAC_UI::comparable_rows( $cmp['start'], $cmp['end'], $range['end'] ) : array();
		$cmp_summary = $cmp_rows ? GOAC_Stats::summary( $cmp_rows, $today ) : null;
		$total_e = max( 1e-9, (float) $summary['total']['earnings'] );
		$items = array();

		if ( 'day' === $p['group'] ) {
			$ma_src = GOAC_Stats::column( GOAC_UI::rows( GOAC_Stats::add_days( $range['start'], -6 ), $range['end'] ), 'earnings' );
			$ma = array_combine( array_keys( $ma_src ), GOAC_Stats::moving_average( $ma_src, 7 ) );
			$cum = 0.0;
			foreach ( $rows as $date => $row ) {
				$cum += (float) $row['earnings'];
				$prev = $c['rows'][ GOAC_Stats::add_days( $date, -1 ) ] ?? null;
				$week = $c['rows'][ GOAC_Stats::add_days( $date, -7 ) ] ?? null;
				if ( $date === $today ) {
					$p1 = GOAC_UI::comparable_rows( GOAC_Stats::add_days( $date, -1 ), GOAC_Stats::add_days( $date, -1 ), $today );
					$p7 = GOAC_UI::comparable_rows( GOAC_Stats::add_days( $date, -7 ), GOAC_Stats::add_days( $date, -7 ), $today );
					$prev = $p1 ? reset( $p1 ) : null; $week = $p7 ? reset( $p7 ) : null;
				}
				$items[ $date ] = array(
					'key' => $date, 'row' => GOAC_Stats::derive( $row ), 'partial' => $date === $today, 'days' => 1,
					'delta_prev' => $prev ? GOAC_Stats::delta( $row['earnings'], $prev['earnings'] ) : null,
					'delta_week' => $week ? GOAC_Stats::delta( $row['earnings'], $week['earnings'] ) : null,
					'share' => (float) $row['earnings'] / $total_e, 'cumulative' => $cum, 'ma7' => $ma[ $date ] ?? null,
				);
			}
		} else {
			foreach ( GOAC_Stats::group( $rows, $p['group'], $today ) as $key => $g ) {
				$prev_rows = GOAC_UI::comparable_rows( self::shift( $g['start'], $p['group'] ), self::shift( $g['end'], $p['group'] ), $g['end'] );
				$year_rows = GOAC_UI::comparable_rows( self::shift( $g['start'], $p['group'], true ), self::shift( $g['end'], $p['group'], true ), $g['end'] );
				$full_days = GOAC_Stats::days_between( self::period_start( $key, $p['group'] ), self::period_end( $key, $p['group'] ) ) + 1;
				$items[ $key ] = array(
					'key' => $key, 'row' => $g, 'partial' => $g['partial'] || $g['days'] < $full_days, 'days' => $g['days'], 'full_days' => $full_days,
					'delta_prev' => $prev_rows ? GOAC_Stats::delta( $g['earnings'], GOAC_Stats::sum( $prev_rows )['earnings'] ) : null,
					'delta_year' => $year_rows && $g['start'] >= GOAC_Stats::shift_years( $c['first_day'], 1 ) ? GOAC_Stats::delta( $g['earnings'], GOAC_Stats::sum( $year_rows )['earnings'] ) : null,
					'share' => (float) $g['earnings'] / $total_e,
				);
			}
		}

		$projection = null;
		$calendar_ends = array( 'this_week' => GOAC_Stats::add_days( GOAC_Stats::week_start( $today ), 6 ), 'this_month' => GOAC_Stats::month_end( $today ), 'this_quarter' => GOAC_Stats::quarter_end( $today ), 'this_year' => substr( $today, 0, 4 ) . '-12-31' );
		if ( isset( $calendar_ends[ $range['preset'] ] ) ) {
			$projection = GOAC_UI::projection( $range['start'], $calendar_ends[ $range['preset'] ] );
		}
		return compact( 'range', 'rows', 'summary', 'cmp', 'cmp_rows', 'cmp_summary', 'items', 'projection' ) + array( 'group' => $p['group'], 'compare' => $p['compare'], 'today' => $today );
	}

	private static function period_start( $key, $group ) {
		switch ( $group ) {
			case 'week': return $key;
			case 'month': return $key . '-01';
			case 'quarter': return substr( $key, 0, 4 ) . '-' . sprintf( '%02d', 3 * ( (int) substr( $key, -1 ) - 1 ) + 1 ) . '-01';
			case 'year': return $key . '-01-01';
			default: return $key;
		}
	}

	private static function period_end( $key, $group ) {
		switch ( $group ) {
			case 'week': return GOAC_Stats::add_days( $key, 6 );
			case 'month': return GOAC_Stats::month_end( $key . '-01' );
			case 'quarter': return GOAC_Stats::quarter_end( self::period_start( $key, $group ) );
			case 'year': return $key . '-12-31';
			default: return $key;
		}
	}

	public static function render() {
		$c = GOAC_UI::context();
		if ( ! $c['first_day'] ) { GOAC_UI::empty_state( 'O histórico ainda não foi importado. Veja o andamento na Visão geral.' ); return; }
		$p = self::params();
		$data = self::dataset( $p );
		$range = $data['range'];

		echo '<section class="goac-card goac-filters"><form method="get" class="goac-filter-row" data-goac-period-form>';
		echo '<input type="hidden" name="page" value="goac"><input type="hidden" name="tab" value="days">';
		GOAC_UI::period_fields( $range, $p['include_today'] );
		echo '<label>Agrupar por<select name="group">';
		foreach ( self::GROUPS as $k => $label ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $k ), selected( $p['group'], $k, false ), esc_html( $label ) ); }
		echo '</select></label><label>Comparar com<select name="compare">';
		foreach ( self::COMPARE as $k => $label ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $k ), selected( $p['compare'], $k, false ), esc_html( $label ) ); }
		echo '</select></label><div class="goac-filter-actions"><button class="button button-primary">Aplicar</button>';
		$export = array( 'source' => 'days', 'preset' => $range['preset'], 'from' => $range['start'], 'to' => $range['end'], 'group' => $p['group'], 'compare' => $p['compare'], 'include_today' => $p['include_today'] ? 1 : 0 );
		echo '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_export', $export ) ) . '">Exportar CSV</a></div></form>';
		GOAC_UI::quick_ranges( 'days', $range, array( 'group' => $p['group'], 'compare' => $p['compare'] ) );
		echo '<p class="goac-muted goac-range-note"><strong>' . esc_html( GOAC_UI::range_label( $range['start'], $range['end'] ) ) . '</strong> · ' . (int) $range['days'] . ' dias' . ( $data['cmp'] ? ' · comparado com ' . esc_html( $data['cmp']['label'] ) . ' (' . esc_html( GOAC_UI::range_label( $data['cmp']['start'], $data['cmp']['end'] ) ) . ')' : '' ) . ( $range['end'] === $c['today'] ? ' · hoje é parcial' : '' ) . '</p>';
		echo '</section>';

		if ( ! $data['rows'] ) { GOAC_UI::notice( 'info', 'Não há dados no histórico para este período (o histórico começa em ' . esc_html( GOAC_UI::date( $c['first_day'] ) ) . ').' ); return; }

		self::summary_cards( $data );
		self::chart( $data, $c );
		if ( 'day' === $p['group'] && $range['days'] <= 400 && $range['days'] >= 7 ) {
			$forecast = $data['projection'] ? $data['projection']['daily'] : array();
			GOAC_UI::card_open( 'Calendário de receita', '<span class="goac-muted">passe o mouse em um dia para ver os valores</span>' );
			GOAC_UI::calendar( $data['rows'], $range['start'], $range['end'], $c['today'], $forecast, $data['projection'] ? $data['projection']['end'] : '' );
			GOAC_UI::card_close();
		}
		'day' === $p['group'] ? self::day_table( $data ) : self::group_table( $data );
	}

	private static function summary_cards( array $data ) {
		$s = $data['summary']; $t = $s['total']; $cs = $data['cmp_summary']; $ct = $cs ? $cs['total'] : null;
		$label = $data['cmp'] ? 'vs. ' . $data['cmp']['label'] : '';
		$d = static function( $cur, $key, $avg = false ) use ( $cs, $label ) {
			if ( ! $cs ) { return ''; }
			$prev = $avg ? $cs['avg'][ $key ] : $cs['total'][ $key ];
			return GOAC_UI::delta( GOAC_Stats::delta( $cur, $prev ), $label );
		};
		echo '<div class="goac-kpis goac-kpis-summary">';
		GOAC_UI::kpi( 'Receita total', GOAC_UI::money( $t['earnings'] ), $d( $t['earnings'], 'earnings' ), array( 'class' => 'is-hero is-accent' ) );
		if ( $data['projection'] ) {
			$p = $data['projection'];
			GOAC_UI::kpi( 'Previsão do período completo', GOAC_UI::money( $p['projected'] ), esc_html( 'Até ' . GOAC_UI::date( $p['end'] ) . ' · faixa ' . GOAC_UI::money( $p['low'], 0 ) . ' – ' . GOAC_UI::money( $p['high'], 0 ) ), array( 'class' => 'is-hero' ) );
		}
		GOAC_UI::kpi( 'Média por dia', GOAC_UI::money( $s['avg']['earnings'] ), $d( $s['avg']['earnings'], 'earnings', true ), array( 'class' => 'is-hero', 'title' => 'Média dos dias completos do período (hoje parcial fica de fora).' ) );
		GOAC_UI::kpi( 'Mediana por dia', GOAC_UI::money( $s['median'] ), esc_html( 'P25 ' . GOAC_UI::money( $s['p25'] ) . ' · P75 ' . GOAC_UI::money( $s['p75'] ) ) );
		if ( $s['best']['date'] ) {
			GOAC_UI::kpi( 'Melhor dia', GOAC_UI::money( $s['best']['value'] ), esc_html( GOAC_UI::weekday( $s['best']['date'] ) . ', ' . GOAC_UI::date( $s['best']['date'] ) ) );
			GOAC_UI::kpi( 'Pior dia', GOAC_UI::money( $s['worst']['value'] ), esc_html( GOAC_UI::weekday( $s['worst']['date'] ) . ', ' . GOAC_UI::date( $s['worst']['date'] ) ) );
		}
		GOAC_UI::kpi( 'Dias com receita', GOAC_UI::number( $s['active_days'] ) . ' de ' . GOAC_UI::number( $s['days'] ), esc_html( 'Desvio padrão diário ' . GOAC_UI::money( $s['stdev'] ) ) );
		GOAC_UI::kpi( 'Page views', GOAC_UI::number( $t['page_views'] ), $d( $t['page_views'], 'page_views' ) );
		GOAC_UI::kpi( 'Impressões', GOAC_UI::number( $t['impressions'] ), $d( $t['impressions'], 'impressions' ) );
		GOAC_UI::kpi( 'Cliques', GOAC_UI::number( $t['clicks'] ), $d( $t['clicks'], 'clicks' ) );
		GOAC_UI::kpi( 'Page RPM', GOAC_UI::money( $t['page_rpm'] ), $d( $t['page_rpm'], 'page_rpm' ) );
		GOAC_UI::kpi( 'RPM de impressão', GOAC_UI::money( $t['impression_rpm'] ), $d( $t['impression_rpm'], 'impression_rpm' ) );
		GOAC_UI::kpi( 'CTR da página', GOAC_UI::pct( $t['ctr'], 2 ), $d( $t['ctr'], 'ctr' ) );
		GOAC_UI::kpi( 'CPC médio', GOAC_UI::money( $t['cpc'] ), $d( $t['cpc'], 'cpc' ) );
		GOAC_UI::kpi( 'Cobertura', GOAC_UI::pct( $t['coverage'] ), $d( $t['coverage'], 'coverage' ) );
		GOAC_UI::kpi( 'Active View', GOAC_UI::pct( $t['viewability'] ), $d( $t['viewability'], 'viewability' ) );
		GOAC_UI::kpi( 'Page views por dia', GOAC_UI::number( $s['avg']['page_views'] ), $d( $s['avg']['page_views'], 'page_views', true ) );
		echo '</div>';
	}

	private static function chart( array $data, array $c ) {
		$labels = array(); $metrics = array( 'earnings' => array(), 'page_views' => array(), 'page_rpm' => array(), 'impressions' => array(), 'clicks' => array(), 'ctr' => array(), 'coverage' => array() );
		$compare = array_fill_keys( array_keys( $metrics ), array() );
		$cmp_items = array();
		if ( $data['cmp_rows'] ) {
			$cmp_items = 'day' === $data['group'] ? array_values( $data['cmp_rows'] ) : array_values( GOAC_Stats::group( $data['cmp_rows'], $data['group'], $c['today'] ) );
		}
		$i = 0;
		foreach ( $data['items'] as $key => $item ) {
			$labels[] = (string) $key;
			$row = $item['row'];
			$cmp_row = isset( $cmp_items[ $i ] ) ? GOAC_Stats::derive( $cmp_items[ $i ] ) : null;
			foreach ( $metrics as $k => $list ) {
				$metrics[ $k ][] = null === $row[ $k ] ? null : round( (float) $row[ $k ], 6 );
				$compare[ $k ][] = $cmp_row && null !== $cmp_row[ $k ] ? round( (float) $cmp_row[ $k ], 6 ) : null;
			}
			$i++;
		}
		$f = array( 'values' => array(), 'low' => array(), 'high' => array() );
		if ( 'day' === $data['group'] && $data['projection'] ) {
			foreach ( $data['projection']['daily'] as $date => $v ) { $labels[] = $date; $f['values'][] = round( $v['value'], 4 ); $f['low'][] = round( $v['low'], 4 ); $f['high'][] = round( $v['high'], 4 ); }
		}
		$names = array( 'earnings' => array( 'Receita', 'money' ), 'page_views' => array( 'Page views', 'number' ), 'page_rpm' => array( 'Page RPM', 'money' ), 'impressions' => array( 'Impressões', 'number' ), 'clicks' => array( 'Cliques', 'number' ), 'ctr' => array( 'CTR', 'percent' ), 'coverage' => array( 'Cobertura', 'percent' ) );
		$out = array();
		foreach ( $names as $k => $meta ) {
			$out[ $k ] = array( 'name' => $meta[0], 'format' => $meta[1], 'values' => $metrics[ $k ] );
			if ( $cmp_items ) { $out[ $k ]['compare'] = $compare[ $k ]; $out[ $k ]['compareName'] = ucfirst( $data['cmp']['label'] ); }
		}
		if ( $f['values'] ) { $out['earnings'] += array( 'forecast' => $f['values'], 'low' => $f['low'], 'high' => $f['high'] ); }
		$dataset = array( 'labels' => $labels, 'actualCount' => count( $data['items'] ), 'today' => $c['today'], 'currency' => $c['currency'], 'labelType' => 'day' === $data['group'] ? 'date' : 'group', 'group' => $data['group'], 'ma' => 'day' === $data['group'] && count( $data['items'] ) >= 14 ? 7 : 0, 'metrics' => $out );
		$buttons = '';
		foreach ( $names as $k => $meta ) { $buttons .= '<button type="button" class="' . ( 'earnings' === $k ? 'is-active' : '' ) . '" data-value="' . esc_attr( $k ) . '" aria-pressed="' . ( 'earnings' === $k ? 'true' : 'false' ) . '">' . esc_html( $meta[0] ) . '</button>'; }
		GOAC_UI::card_open( 'Gráfico do período', '<div class="goac-seg" data-goac-switch="metric" data-target="goac-days-chart" role="group" aria-label="Métrica">' . $buttons . '</div>' );
		printf( '<div class="goac-chart" id="goac-days-chart" data-goac-dataset="%s" data-metric="earnings" data-range="all" style="min-height:336px"><p class="goac-chart-fallback">Ative o JavaScript para ver o gráfico. Os dados estão na tabela abaixo.</p></div>', esc_attr( wp_json_encode( $dataset ) ) );
		GOAC_UI::card_close();
	}

	private static function num( $value, $sort, $class = '' ) {
		return '<td class="num ' . esc_attr( $class ) . '" data-sort="' . esc_attr( null === $sort ? '' : (string) round( (float) $sort, 6 ) ) . '">' . $value . '</td>';
	}

	private static function day_table( array $data ) {
		$s = $data['summary']; $t = $s['total']; $avg = $s['avg'];
		$scale = GOAC_UI::heat_scale( array_map( static function( $i ) { return $i['partial'] ? 0 : $i['row']['earnings']; }, $data['items'] ) );
		GOAC_UI::card_open( 'Todos os dias', '<span class="goac-muted">' . count( $data['items'] ) . ' dias · clique no cabeçalho para ordenar</span><input type="search" class="goac-search" placeholder="Filtrar (ex.: sáb, 09/2026)" data-goac-table-search="goac-days-table" aria-label="Filtrar dias">' );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable goac-sticky" id="goac-days-table"><thead><tr>';
		$heads = array( array( 'Data', 'text' ), array( 'Dia', 'text' ), array( 'Receita', 'num' ), array( 'vs. dia anterior', 'num' ), array( 'vs. semana anterior', 'num' ), array( '% do período', 'num' ), array( 'Acumulado', 'num' ), array( 'Média móvel 7d', 'num' ), array( 'Page views', 'num' ), array( 'Impressões', 'num' ), array( 'Cliques', 'num' ), array( 'CTR', 'num' ), array( 'CPC', 'num' ), array( 'Page RPM', 'num' ), array( 'RPM impr.', 'num' ), array( 'Cobertura', 'num' ), array( 'Active View', 'num' ) );
		foreach ( $heads as $i => $h ) { echo '<th scope="col" data-sort-type="' . esc_attr( $h[1] ) . '" class="' . ( 'num' === $h[1] ? 'num' : '' ) . '" tabindex="0">' . esc_html( $h[0] ) . '</th>'; }
		echo '</tr>';
		self::summary_row( 'Total', $t, array( 'Receita' => GOAC_UI::money( $t['earnings'] ), 'share' => '100%', 'cum' => GOAC_UI::money( $t['earnings'] ) ) );
		self::summary_row( 'Média/dia', $avg, array( 'Receita' => GOAC_UI::money( $avg['earnings'] ) ), true );
		echo '</thead><tbody>';
		foreach ( array_reverse( $data['items'], true ) as $date => $item ) {
			$r = $item['row']; $weekend = in_array( GOAC_Stats::weekday( $date ), array( 0, 6 ), true );
			echo '<tr class="' . ( $item['partial'] ? 'is-partial' : '' ) . ( $weekend ? ' is-weekend' : '' ) . '">';
			echo '<td data-sort="' . esc_attr( $date ) . '" class="goac-nowrap"><strong>' . esc_html( GOAC_UI::date( $date ) ) . '</strong>' . ( $item['partial'] ? ' <span class="goac-pill">parcial</span>' : '' ) . '</td>';
			echo '<td data-sort="' . (int) ( ( GOAC_Stats::weekday( $date ) + 6 ) % 7 ) . '">' . esc_html( GOAC_UI::weekday( $date ) ) . '</td>';
			echo self::num( '<span class="goac-heat goac-h' . (int) ( $item['partial'] ? 0 : $scale( $r['earnings'] ) ) . '">' . esc_html( GOAC_UI::money( $r['earnings'] ) ) . '</span>', $r['earnings'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::num( GOAC_UI::delta( $item['delta_prev'] ), $item['delta_prev'] ) . self::num( GOAC_UI::delta( $item['delta_week'] ), $item['delta_week'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::num( esc_html( GOAC_UI::pct( $item['share'] ) ), $item['share'] ) . self::num( esc_html( GOAC_UI::money( $item['cumulative'] ) ), $item['cumulative'] ) . self::num( esc_html( GOAC_UI::money( $item['ma7'] ) ), $item['ma7'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::cells( $r ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '</tr>';
		}
		echo '</tbody><tfoot>';
		self::summary_row( 'Total', $t, array( 'Receita' => GOAC_UI::money( $t['earnings'] ), 'share' => '100%', 'cum' => GOAC_UI::money( $t['earnings'] ) ) );
		self::summary_row( 'Média/dia', $avg, array( 'Receita' => GOAC_UI::money( $avg['earnings'] ) ), true );
		echo '</tfoot></table></div>';
		GOAC_UI::card_close();
	}

	/** Células comuns de métricas (page views até Active View). */
	private static function cells( array $r, $with_rpm_impr = true ) {
		$html = self::num( esc_html( GOAC_UI::number( $r['page_views'] ) ), $r['page_views'] ) . self::num( esc_html( GOAC_UI::number( $r['impressions'] ) ), $r['impressions'] ) . self::num( esc_html( GOAC_UI::number( $r['clicks'] ) ), $r['clicks'] );
		$html .= self::num( esc_html( GOAC_UI::pct( $r['ctr'], 2 ) ), $r['ctr'] ) . self::num( esc_html( GOAC_UI::money( $r['cpc'] ) ), $r['cpc'] ) . self::num( esc_html( GOAC_UI::money( $r['page_rpm'] ) ), $r['page_rpm'] );
		if ( $with_rpm_impr ) { $html .= self::num( esc_html( GOAC_UI::money( $r['impression_rpm'] ) ), $r['impression_rpm'] ); }
		return $html . self::num( esc_html( GOAC_UI::pct( $r['coverage'] ) ), $r['coverage'] ) . self::num( esc_html( GOAC_UI::pct( $r['viewability'] ) ), $r['viewability'] );
	}

	private static function summary_row( $label, array $r, array $override, $is_avg = false ) {
		echo '<tr class="goac-summary-row' . ( $is_avg ? ' is-avg' : '' ) . '"><th scope="row">' . esc_html( $label ) . '</th><td></td>';
		echo '<td class="num"><strong>' . esc_html( $override['Receita'] ) . '</strong></td><td></td><td></td>';
		echo '<td class="num">' . esc_html( $override['share'] ?? '' ) . '</td><td class="num">' . esc_html( $override['cum'] ?? '' ) . '</td><td></td>';
		echo '<td class="num">' . esc_html( GOAC_UI::number( $r['page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $r['impressions'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $r['clicks'] ) ) . '</td>';
		echo '<td class="num">' . esc_html( GOAC_UI::pct( $r['ctr'], 2 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $r['cpc'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $r['page_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $r['impression_rpm'] ) ) . '</td>';
		echo '<td class="num">' . esc_html( GOAC_UI::pct( $r['coverage'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $r['viewability'] ) ) . '</td></tr>';
	}

	private static function group_table( array $data ) {
		$s = $data['summary']; $t = $s['total']; $group = $data['group'];
		$scale = GOAC_UI::heat_scale( array_map( static function( $i ) { return $i['partial'] ? 0 : $i['row']['earnings']; }, $data['items'] ) );
		GOAC_UI::card_open( 'Por ' . strtolower( self::GROUPS[ $group ] ), '<span class="goac-muted">' . count( $data['items'] ) . ' linhas</span>' );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable goac-sticky"><thead><tr>';
		$heads = array( array( 'Período', 'text' ), array( 'Dias', 'num' ), array( 'Receita', 'num' ), array( 'Média/dia', 'num' ), array( 'vs. anterior', 'num' ), array( 'vs. ano anterior', 'num' ), array( '% do total', 'num' ), array( 'Page views', 'num' ), array( 'Impressões', 'num' ), array( 'Cliques', 'num' ), array( 'CTR', 'num' ), array( 'CPC', 'num' ), array( 'Page RPM', 'num' ), array( 'Cobertura', 'num' ), array( 'Active View', 'num' ), array( 'Melhor dia', 'num' ) );
		foreach ( $heads as $h ) { echo '<th scope="col" data-sort-type="' . esc_attr( $h[1] ) . '" class="' . ( 'num' === $h[1] ? 'num' : '' ) . '" tabindex="0">' . esc_html( $h[0] ) . '</th>'; }
		echo '</tr><tr class="goac-summary-row"><th scope="row">Total</th><td class="num">' . (int) $s['days'] . '</td><td class="num"><strong>' . esc_html( GOAC_UI::money( $t['earnings'] ) ) . '</strong></td><td class="num">' . esc_html( GOAC_UI::money( $s['avg']['earnings'] ) ) . '</td><td></td><td></td><td class="num">100%</td>';
		echo '<td class="num">' . esc_html( GOAC_UI::number( $t['page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $t['impressions'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $t['clicks'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $t['ctr'], 2 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $t['cpc'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $t['page_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $t['coverage'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $t['viewability'] ) ) . '</td><td></td></tr></thead><tbody>';
		foreach ( array_reverse( $data['items'], true ) as $key => $item ) {
			$r = $item['row'];
			echo '<tr class="' . ( $item['partial'] ? 'is-partial' : '' ) . '"><td data-sort="' . esc_attr( $key ) . '" class="goac-nowrap"><strong>' . esc_html( GOAC_UI::group_label( $r, $group ) ) . '</strong>' . ( $item['partial'] ? ' <span class="goac-pill" title="' . esc_attr( $item['days'] . ' de ' . $item['full_days'] . ' dias no período' ) . '">parcial</span>' : '' ) . '</td>';
			echo self::num( esc_html( (string) $item['days'] ), $item['days'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::num( '<span class="goac-heat goac-h' . (int) ( $item['partial'] ? 0 : $scale( $r['earnings'] ) ) . '">' . esc_html( GOAC_UI::money( $r['earnings'] ) ) . '</span>', $r['earnings'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::num( esc_html( GOAC_UI::money( $r['avg_earnings'] ) ), $r['avg_earnings'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::num( GOAC_UI::delta( $item['delta_prev'] ), $item['delta_prev'] ) . self::num( GOAC_UI::delta( $item['delta_year'] ), $item['delta_year'] ) . self::num( esc_html( GOAC_UI::pct( $item['share'] ) ), $item['share'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::cells( $r, false ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo self::num( esc_html( $r['best_date'] ? GOAC_UI::money( $r['best_value'] ) . ' (' . GOAC_UI::date( $r['best_date'], 'd/m' ) . ')' : '—' ), $r['best_value'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '</tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	public static function export( array $p ) {
		$data = self::dataset( $p );
		$range = $data['range'];
		$cur = GOAC_UI::currency_code();
		$metric_head = array( 'Page views', 'Impressões', 'Cliques', 'Solicitações', 'Solicitações correspondidas', 'CTR (%)', 'CPC (' . $cur . ')', 'Page RPM (' . $cur . ')', 'RPM de impressão (' . $cur . ')', 'Cobertura (%)', 'Active View (%)' );
		$metric_cells = static function( array $r ) {
			return array( (int) $r['page_views'], (int) $r['impressions'], (int) $r['clicks'], (int) $r['ad_requests'], (int) $r['matched_requests'], null === $r['ctr'] ? null : $r['ctr'] * 100, $r['cpc'], $r['page_rpm'], $r['impression_rpm'], null === $r['coverage'] ? null : $r['coverage'] * 100, null === $r['viewability'] ? null : $r['viewability'] * 100 );
		};
		$rows = array();
		if ( 'day' === $data['group'] ) {
			$header = array_merge( array( 'Data', 'Dia da semana', 'Parcial', 'Receita (' . $cur . ')', 'Variação vs dia anterior (%)', 'Variação vs semana anterior (%)', '% do período', 'Acumulado (' . $cur . ')', 'Média móvel 7d (' . $cur . ')' ), $metric_head );
			foreach ( $data['items'] as $date => $item ) {
				$r = $item['row'];
				$rows[] = array_merge( array( $date, GOAC_UI::weekday( $date, false ), $item['partial'] ? 'sim' : 'não', (float) $r['earnings'], null === $item['delta_prev'] ? null : $item['delta_prev'] * 100, null === $item['delta_week'] ? null : $item['delta_week'] * 100, $item['share'] * 100, (float) $item['cumulative'], $item['ma7'] ), $metric_cells( $r ) );
			}
			$t = $data['summary']['total'];
			$rows[] = array_merge( array( 'TOTAL', '', '', (float) $t['earnings'], null, null, 100.0, (float) $t['earnings'], null ), $metric_cells( $t ) );
			$a = $data['summary']['avg'];
			$rows[] = array_merge( array( 'MÉDIA/DIA', '', '', (float) $a['earnings'], null, null, null, null, null ), $metric_cells( $a ) );
		} else {
			$header = array_merge( array( 'Período', 'Início', 'Fim', 'Dias', 'Parcial', 'Receita (' . $cur . ')', 'Média/dia (' . $cur . ')', 'Variação vs anterior (%)', 'Variação vs ano anterior (%)', '% do total' ), $metric_head );
			foreach ( $data['items'] as $key => $item ) {
				$r = $item['row'];
				$rows[] = array_merge( array( GOAC_UI::group_label( $r, $data['group'] ), $r['start'], $r['end'], (int) $item['days'], $item['partial'] ? 'sim' : 'não', (float) $r['earnings'], (float) $r['avg_earnings'], null === $item['delta_prev'] ? null : $item['delta_prev'] * 100, null === $item['delta_year'] ? null : $item['delta_year'] * 100, $item['share'] * 100 ), $metric_cells( $r ) );
			}
		}
		GOAC_UI::send_csv( 'adsense-' . $data['group'] . '-' . $range['start'] . '-a-' . $range['end'] . '-' . strtolower( $cur ) . '.csv', $header, $rows );
	}
}

/** Aba Meses & anos: matriz ano × mês, tabelas mensal, anual e semanal e calendário do ano. */
final class GOAC_View_History {
	const METRICS = array( 'earnings' => 'Receita', 'avg_day' => 'Média por dia', 'page_views' => 'Page views', 'page_rpm' => 'Page RPM', 'clicks' => 'Cliques' );

	public static function render() {
		$c = GOAC_UI::context();
		if ( ! $c['first_day'] ) { GOAC_UI::empty_state( 'O histórico ainda não foi importado. Veja o andamento na Visão geral.' ); return; }
		$metric = isset( $_GET['metric'] ) ? sanitize_key( wp_unslash( $_GET['metric'] ) ) : 'earnings'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! isset( self::METRICS[ $metric ] ) ) { $metric = 'earnings'; }
		$months = GOAC_Stats::group( $c['rows'], 'month', $c['today'] );
		$years = GOAC_Stats::group( $c['rows'], 'year', $c['today'] );
		self::matrix( $c, $months, $years, $metric );
		echo '<div class="goac-grid goac-grid-2">';
		self::monthly_chart( $c, $months );
		self::yearly_table( $c, $years, $months );
		echo '</div>';
		self::monthly_table( $c, $months );
		echo '<div class="goac-grid goac-grid-2">';
		self::weekly_table( $c );
		self::weekday_all( $c );
		echo '</div>';
		self::year_calendar( $c );
	}

	private static function month_value( array $m, $metric ) {
		switch ( $metric ) {
			case 'avg_day': return $m['avg_earnings'];
			case 'page_rpm': return $m['page_rpm'];
			default: return (float) $m[ $metric ];
		}
	}

	private static function format( $value, $metric ) {
		if ( in_array( $metric, array( 'page_views', 'clicks' ), true ) ) { return GOAC_UI::number( $value ); }
		return GOAC_UI::money( $value, in_array( $metric, array( 'page_rpm', 'avg_day' ), true ) ? 2 : 0 );
	}

	private static function matrix( array $c, array $months, array $years, $metric ) {
		$today = $c['today']; $cur_year = (int) substr( $today, 0, 4 ); $cur_month = substr( $today, 0, 7 );
		$projections = array();
		if ( in_array( $metric, array( 'earnings', 'avg_day', 'page_views' ), true ) ) {
			$key = 'page_views' === $metric ? 'page_views' : 'earnings';
			for ( $m = $cur_month . '-01'; substr( $m, 0, 4 ) === (string) $cur_year; $m = GOAC_Stats::shift_months( $m, 1 ) ) {
				$p = GOAC_UI::projection( $m, GOAC_Stats::month_end( $m ), $key );
				$projections[ substr( $m, 0, 7 ) ] = 'avg_day' === $metric ? $p['projected'] / GOAC_Stats::days_in_month( $m ) : $p['projected'];
			}
		}
		$values = array();
		foreach ( $months as $k => $m ) { if ( ! $m['partial'] ) { $values[] = (float) self::month_value( $m, $metric ); } }
		$scale = GOAC_UI::heat_scale( $values );
		$tabs = '';
		foreach ( self::METRICS as $k => $label ) { $tabs .= '<a class="goac-chip ' . ( $metric === $k ? 'is-active' : '' ) . '" href="' . esc_url( GOAC_UI::url( 'history', array( 'metric' => $k ) ) ) . '">' . esc_html( $label ) . '</a>'; }
		GOAC_UI::card_open( 'Todos os meses de todos os anos', '<div class="goac-chips">' . $tabs . '</div><a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_export', array( 'source' => 'months' ) ) ) . '">Exportar CSV</a>' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-matrix"><thead><tr><th scope="col">Ano</th>';
		for ( $i = 1; $i <= 12; $i++ ) { echo '<th scope="col" class="num">' . esc_html( ucfirst( GOAC_UI::MONTHS_SHORT[ $i ] ) ) . '</th>'; }
		echo '<th scope="col" class="num">Total</th><th scope="col" class="num">Média/mês</th><th scope="col" class="num">vs. ano anterior</th></tr></thead><tbody>';
		for ( $y = $cur_year; $y >= (int) substr( $c['first_day'], 0, 4 ); $y-- ) {
			echo '<tr><th scope="row">' . (int) $y . '</th>';
			$months_in_year = 0; $proj_total = 0.0; $has_proj = false;
			for ( $i = 1; $i <= 12; $i++ ) {
				$key = sprintf( '%04d-%02d', $y, $i );
				if ( isset( $months[ $key ] ) ) {
					$m = $months[ $key ]; $v = self::month_value( $m, $metric ); $months_in_year++;
					$title = GOAC_UI::month_label( $key, true ) . ': ' . GOAC_UI::money( $m['earnings'] ) . ' · ' . GOAC_UI::number( $m['page_views'] ) . ' pv · RPM ' . GOAC_UI::money( $m['page_rpm'] ) . ' · ' . $m['days'] . ' dias';
					if ( $key === $cur_month && isset( $projections[ $key ] ) ) {
						$proj_total += $projections[ $key ]; $has_proj = true;
						echo '<td class="num is-current" title="' . esc_attr( $title ) . '"><span class="goac-heat goac-h0">' . esc_html( self::format( $v, $metric ) ) . '</span><small class="goac-proj">prev. ' . esc_html( self::format( $projections[ $key ], $metric ) ) . '</small></td>';
					} else {
						$proj_total += (float) $v;
						echo '<td class="num" title="' . esc_attr( $title ) . '"><span class="goac-heat goac-h' . (int) ( $m['partial'] ? 0 : $scale( $v ) ) . '">' . esc_html( self::format( $v, $metric ) ) . '</span></td>';
					}
				} elseif ( $y === $cur_year && isset( $projections[ $key ] ) ) {
					$proj_total += $projections[ $key ]; $has_proj = true;
					echo '<td class="num is-future" title="' . esc_attr( 'Previsão para ' . GOAC_UI::month_label( $key, true ) ) . '"><small class="goac-proj">prev. ' . esc_html( self::format( $projections[ $key ], $metric ) ) . '</small></td>';
				} else {
					echo '<td class="num goac-muted">—</td>';
				}
			}
			$yk = (string) $y;
			if ( isset( $years[ $yk ] ) ) {
				$yr = $years[ $yk ];
				$total = 'page_rpm' === $metric ? $yr['page_rpm'] : ( 'avg_day' === $metric ? $yr['avg_earnings'] : (float) $yr[ $metric ] );
				$prev_key = (string) ( $y - 1 );
				$delta = null;
				if ( isset( $years[ $prev_key ] ) ) {
					if ( $y === $cur_year ) {
						$ly = GOAC_Stats::sum( GOAC_UI::comparable_rows( GOAC_Stats::shift_years( $yr['start'], -1 ), GOAC_Stats::shift_years( $today, -1 ), $today ) );
						$cur = 'page_rpm' === $metric ? $yr['page_rpm'] : (float) $yr[ 'avg_day' === $metric ? 'earnings' : $metric ];
						$delta = GOAC_Stats::delta( $cur, 'page_rpm' === $metric ? $ly['page_rpm'] : (float) $ly[ 'avg_day' === $metric ? 'earnings' : $metric ] );
					} else {
						$py = $years[ $prev_key ];
						$delta = GOAC_Stats::delta( $total, 'page_rpm' === $metric ? $py['page_rpm'] : ( 'avg_day' === $metric ? $py['avg_earnings'] : (float) $py[ $metric ] ) );
					}
				}
				$avg_month = in_array( $metric, array( 'page_rpm', 'avg_day' ), true ) ? null : $total / max( 1, $months_in_year );
				echo '<td class="num"><strong>' . esc_html( self::format( $total, $metric ) ) . '</strong>' . ( $y === $cur_year && $has_proj && in_array( $metric, array( 'earnings', 'page_views' ), true ) ? '<small class="goac-proj">prev. ' . esc_html( self::format( $proj_total, $metric ) ) . '</small>' : '' ) . '</td>';
				echo '<td class="num">' . esc_html( null === $avg_month ? '—' : self::format( $avg_month, $metric ) ) . '</td>';
				echo '<td class="num" title="' . esc_attr( $y === $cur_year ? 'Até hoje contra o mesmo período do ano anterior' : '' ) . '">' . GOAC_UI::delta( $delta ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			} else {
				echo '<td class="num">—</td><td class="num">—</td><td class="num">—</td>';
			}
			echo '</tr>';
		}
		echo '</tbody></table></div>' . GOAC_UI::heat_legend( $values ) . '<p class="goac-footnote">“prev.” é a previsão do mês/ano completo. Meses com poucos dias (início do histórico) aparecem sem cor.</p>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		GOAC_UI::card_close();
	}

	private static function monthly_chart( array $c, array $months ) {
		$today = $c['today'];
		$labels = array(); $values = array(); $last_year = array(); $forecast = array(); $low = array(); $high = array();
		$start = GOAC_Stats::shift_months( GOAC_Stats::month_start( $today ), -23 );
		for ( $m = $start; $m < GOAC_Stats::month_start( $today ); $m = GOAC_Stats::shift_months( $m, 1 ) ) {
			$key = substr( $m, 0, 7 ); if ( ! isset( $months[ $key ] ) ) { continue; }
			$labels[] = $key; $values[] = round( (float) $months[ $key ]['earnings'], 2 );
			$ly = substr( GOAC_Stats::shift_years( $m, -1 ), 0, 7 ); $last_year[] = isset( $months[ $ly ] ) ? round( (float) $months[ $ly ]['earnings'], 2 ) : null;
		}
		$actual = count( $labels );
		for ( $i = 0; $i < 3; $i++ ) {
			$m = GOAC_Stats::shift_months( GOAC_Stats::month_start( $today ), $i );
			$p = GOAC_UI::projection( $m, GOAC_Stats::month_end( $m ) );
			$labels[] = substr( $m, 0, 7 ); $forecast[] = round( $p['projected'], 2 ); $low[] = round( $p['low'], 2 ); $high[] = round( $p['high'], 2 );
			$ly = substr( GOAC_Stats::shift_years( $m, -1 ), 0, 7 ); $last_year[] = isset( $months[ $ly ] ) ? round( (float) $months[ $ly ]['earnings'], 2 ) : null;
		}
		$series = array( array( 'name' => 'Receita do mês', 'type' => 'bar', 'values' => array_merge( $values, array_fill( 0, 3, null ) ), 'forecast' => array_merge( array_fill( 0, $actual, null ), $forecast ), 'low' => array_merge( array_fill( 0, $actual, null ), $low ), 'high' => array_merge( array_fill( 0, $actual, null ), $high ) ) );
		if ( array_filter( $last_year, 'is_numeric' ) ) { $series[] = array( 'name' => 'Mesmo mês do ano anterior', 'type' => 'line', 'values' => $last_year, 'color' => 'muted' ); }
		GOAC_UI::card_open( 'Receita mensal', '<span class="goac-muted">24 meses + previsão de 3</span>' );
		GOAC_UI::chart( array( 'labels' => $labels, 'labelType' => 'month', 'format' => 'money', 'series' => $series, 'forecastLabel' => 'Previsão (mês atual e próximos)' ), 260 );
		GOAC_UI::card_close();
	}

	private static function yearly_table( array $c, array $years, array $months ) {
		$today = $c['today']; $cur = substr( $today, 0, 4 );
		GOAC_UI::card_open( 'Por ano' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Ano</th><th class="num">Receita</th><th class="num">vs. ano ant.</th><th class="num">Média/mês</th><th class="num">Média/dia</th><th class="num">Page views</th><th class="num">Page RPM</th><th class="num">Melhor mês</th></tr></thead><tbody>';
		foreach ( array_reverse( $years, true ) as $key => $y ) {
			$prev = $years[ (string) ( (int) $key - 1 ) ] ?? null;
			$delta = null;
			if ( $prev ) {
				$delta = (string) $key === $cur ? GOAC_Stats::delta( $y['earnings'], GOAC_Stats::sum( GOAC_UI::comparable_rows( GOAC_Stats::shift_years( $y['start'], -1 ), GOAC_Stats::shift_years( $today, -1 ), $today ) )['earnings'] ) : GOAC_Stats::delta( $y['earnings'], $prev['earnings'] );
			}
			$best = null;
			foreach ( $months as $mk => $m ) { if ( 0 === strpos( $mk, (string) $key ) && ( ! $best || $m['earnings'] > $best['earnings'] ) ) { $best = $m; } }
			$month_count = 0; foreach ( $months as $mk => $m ) { if ( 0 === strpos( $mk, (string) $key ) ) { $month_count++; } }
			$proj = (string) $key === $cur ? GOAC_UI::projection( $cur . '-01-01', $cur . '-12-31' ) : null;
			echo '<tr><th scope="row">' . esc_html( (string) $key ) . '</th><td class="num"><strong>' . esc_html( GOAC_UI::money( $y['earnings'], 0 ) ) . '</strong>' . ( $proj ? '<small class="goac-proj">prev. ' . esc_html( GOAC_UI::money( $proj['projected'], 0 ) ) . '</small>' : '' ) . '</td>';
			echo '<td class="num" title="' . esc_attr( (string) $key === $cur ? 'Até hoje contra o mesmo período do ano anterior' : '' ) . '">' . GOAC_UI::delta( $delta ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num">' . esc_html( GOAC_UI::money( $y['earnings'] / max( 1, $month_count ), 0 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $y['avg_earnings'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $y['page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $y['page_rpm'] ) ) . '</td>';
			echo '<td class="num">' . esc_html( $best ? GOAC_UI::month_label( $best['key'] ) . ' · ' . GOAC_UI::money( $best['earnings'], 0 ) : '—' ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function monthly_table( array $c, array $months ) {
		$today = $c['today']; $cur = substr( $today, 0, 7 );
		GOAC_UI::card_open( 'Todos os meses', '<span class="goac-muted">' . count( $months ) . ' meses · clique no cabeçalho para ordenar</span>' );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable goac-sticky"><thead><tr>';
		foreach ( array( array( 'Mês', 'text' ), array( 'Dias', 'num' ), array( 'Receita', 'num' ), array( 'Previsão', 'num' ), array( 'Média/dia', 'num' ), array( 'vs. mês anterior', 'num' ), array( 'vs. ano anterior', 'num' ), array( 'Page views', 'num' ), array( 'Impressões', 'num' ), array( 'Cliques', 'num' ), array( 'CTR', 'num' ), array( 'CPC', 'num' ), array( 'Page RPM', 'num' ), array( 'Cobertura', 'num' ), array( 'Active View', 'num' ), array( 'Melhor dia', 'num' ) ) as $h ) {
			echo '<th scope="col" data-sort-type="' . esc_attr( $h[1] ) . '" class="' . ( 'num' === $h[1] ? 'num' : '' ) . '" tabindex="0">' . esc_html( $h[0] ) . '</th>';
		}
		echo '</tr></thead><tbody>';
		foreach ( array_reverse( $months, true ) as $key => $m ) {
			$prev_key = substr( GOAC_Stats::shift_months( $key . '-01', -1 ), 0, 7 ); $ly_key = substr( GOAC_Stats::shift_years( $key . '-01', -1 ), 0, 7 );
			$is_cur = $key === $cur;
			if ( $is_cur ) {
				$pm = GOAC_UI::comparable_rows( GOAC_Stats::shift_months( $m['start'], -1 ), GOAC_Stats::shift_months( $m['end'], -1 ), $m['end'] );
				$ly = GOAC_UI::comparable_rows( GOAC_Stats::shift_years( $m['start'], -1 ), GOAC_Stats::shift_years( $m['end'], -1 ), $m['end'] );
				$d_prev = $pm ? GOAC_Stats::delta( $m['earnings'], GOAC_Stats::sum( $pm )['earnings'] ) : null;
				$d_year = $ly && isset( $months[ $ly_key ] ) ? GOAC_Stats::delta( $m['earnings'], GOAC_Stats::sum( $ly )['earnings'] ) : null;
				$proj = GOAC_UI::projection( $m['start'], GOAC_Stats::month_end( $m['start'] ) )['projected'];
			} else {
				$d_prev = isset( $months[ $prev_key ] ) ? GOAC_Stats::delta( $m['earnings'], $months[ $prev_key ]['earnings'] ) : null;
				$d_year = isset( $months[ $ly_key ] ) ? GOAC_Stats::delta( $m['earnings'], $months[ $ly_key ]['earnings'] ) : null;
				$proj = null;
			}
			$d = static function( $v, $s ) { return '<td class="num" data-sort="' . esc_attr( null === $s ? '' : (string) round( (float) $s, 6 ) ) . '">' . $v . '</td>'; };
			echo '<tr class="' . ( $is_cur ? 'is-partial' : '' ) . '"><td data-sort="' . esc_attr( $key ) . '" class="goac-nowrap"><strong>' . esc_html( GOAC_UI::month_label( $key, true ) ) . '</strong>' . ( $is_cur ? ' <span class="goac-pill">em andamento</span>' : '' ) . '</td>';
			echo $d( esc_html( (string) $m['days'] ), $m['days'] ) . $d( '<strong>' . esc_html( GOAC_UI::money( $m['earnings'] ) ) . '</strong>', $m['earnings'] ) . $d( esc_html( null === $proj ? '—' : GOAC_UI::money( $proj ) ), $proj ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo $d( esc_html( GOAC_UI::money( $m['avg_earnings'] ) ), $m['avg_earnings'] ) . $d( GOAC_UI::delta( $d_prev, $is_cur ? '' : '' ), $d_prev ) . $d( GOAC_UI::delta( $d_year ), $d_year ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo $d( esc_html( GOAC_UI::number( $m['page_views'] ) ), $m['page_views'] ) . $d( esc_html( GOAC_UI::number( $m['impressions'] ) ), $m['impressions'] ) . $d( esc_html( GOAC_UI::number( $m['clicks'] ) ), $m['clicks'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo $d( esc_html( GOAC_UI::pct( $m['ctr'], 2 ) ), $m['ctr'] ) . $d( esc_html( GOAC_UI::money( $m['cpc'] ) ), $m['cpc'] ) . $d( esc_html( GOAC_UI::money( $m['page_rpm'] ) ), $m['page_rpm'] ) . $d( esc_html( GOAC_UI::pct( $m['coverage'] ) ), $m['coverage'] ) . $d( esc_html( GOAC_UI::pct( $m['viewability'] ) ), $m['viewability'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo $d( esc_html( $m['best_date'] ? GOAC_UI::money( $m['best_value'] ) . ' (' . GOAC_UI::date( $m['best_date'], 'd/m' ) . ')' : '—' ), $m['best_value'] ) . '</tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function weekly_table( array $c ) {
		$today = $c['today'];
		$start = GOAC_Stats::add_days( GOAC_Stats::week_start( $today ), -7 * 25 );
		$weeks = GOAC_Stats::group( GOAC_UI::rows( max( $start, $c['first_day'] ), $today ), 'week', $today );
		GOAC_UI::card_open( 'Últimas 26 semanas', '<a href="' . esc_url( GOAC_UI::url( 'days', array( 'preset' => 'last_180', 'group' => 'week', 'include_today' => 1 ) ) ) . '">Mais semanas →</a>' );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Semana</th><th class="num">Receita</th><th class="num">vs. anterior</th><th class="num">Média/dia</th><th class="num">Page views</th><th class="num">Page RPM</th></tr></thead><tbody>';
		$keys = array_keys( $weeks );
		foreach ( array_reverse( $keys ) as $idx => $key ) {
			$w = $weeks[ $key ]; $pos = array_search( $key, $keys, true ); $prev = $pos > 0 ? $weeks[ $keys[ $pos - 1 ] ] : null;
			$partial = $w['days'] < 7;
			$delta = $prev ? GOAC_Stats::delta( $w['earnings'], $partial ? GOAC_Stats::sum( GOAC_UI::comparable_rows( GOAC_Stats::add_days( $w['start'], -7 ), GOAC_Stats::add_days( $w['end'], -7 ), $w['end'] ) )['earnings'] : $prev['earnings'] ) : null;
			echo '<tr class="' . ( $partial ? 'is-partial' : '' ) . '"><td class="goac-nowrap">' . esc_html( GOAC_UI::group_label( $w, 'week' ) ) . ( $partial ? ' <span class="goac-pill">parcial</span>' : '' ) . '</td><td class="num"><strong>' . esc_html( GOAC_UI::money( $w['earnings'] ) ) . '</strong></td><td class="num">' . GOAC_UI::delta( $delta ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $w['avg_earnings'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $w['page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $w['page_rpm'] ) ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function weekday_all( array $c ) {
		$recent = GOAC_Stats::weekday_profile( $c['rows'], $c['today'], 12 );
		$year = GOAC_Stats::weekday_profile( $c['rows'], $c['today'], 52 );
		$all = GOAC_Stats::weekday_profile( $c['rows'], $c['today'], 2000 );
		GOAC_UI::card_open( 'Dias da semana: recente x histórico' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Dia</th><th class="num">12 semanas</th><th class="num">Índice</th><th class="num">52 semanas</th><th class="num">Índice</th><th class="num">Todo o histórico</th><th class="num">Índice</th></tr></thead><tbody>';
		foreach ( $recent as $w => $p ) {
			echo '<tr><td>' . esc_html( GOAC_UI::WEEKDAYS[ $w ] ) . '</td>';
			foreach ( array( $p, $year[ $w ], $all[ $w ] ) as $prof ) {
				echo '<td class="num">' . esc_html( GOAC_UI::money( $prof['avg_earnings'] ) ) . '</td><td class="num">' . GOAC_UI::delta( null === $prof['index'] ? null : $prof['index'] - 1 ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			}
			echo '</tr>';
		}
		echo '</tbody></table></div><p class="goac-footnote">Índice: quanto o dia fica acima ou abaixo da média diária da mesma janela.</p>';
		GOAC_UI::card_close();
	}

	private static function year_calendar( array $c ) {
		$today = $c['today']; $cur = (int) substr( $today, 0, 4 ); $first = (int) substr( $c['first_day'], 0, 4 );
		$year = isset( $_GET['cal_year'] ) ? (int) $_GET['cal_year'] : $cur; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$year = max( $first, min( $cur, $year ) );
		$chips = '';
		for ( $y = $cur; $y >= $first; $y-- ) { $chips .= '<a class="goac-chip ' . ( $y === $year ? 'is-active' : '' ) . '" href="' . esc_url( GOAC_UI::url( 'history', array( 'cal_year' => $y ) ) . '#goac-year-calendar' ) . '">' . (int) $y . '</a>'; }
		GOAC_UI::card_open( 'Calendário de ' . $year, '<div class="goac-chips">' . $chips . '</div>', '', 'goac-year-calendar' );
		$start = $year . '-01-01'; $end = min( $today, $year . '-12-31' );
		$forecast = $year === $cur ? GOAC_UI::projection( GOAC_Stats::add_days( $today, 1 ), $year . '-12-31' )['daily'] : array();
		GOAC_UI::calendar( GOAC_UI::rows( $start, $end ), $start, $end, $today, $forecast, $year . '-12-31' );
		GOAC_UI::card_close();
	}

	public static function export_months() {
		$c = GOAC_UI::context();
		$rows = array();
		foreach ( GOAC_Stats::group( $c['rows'], 'month', $c['today'] ) as $key => $m ) {
			$rows[] = array( $key, (int) $m['days'], $m['partial'] ? 'sim' : 'não', (float) $m['earnings'], (float) $m['avg_earnings'], (int) $m['page_views'], (int) $m['impressions'], (int) $m['clicks'], null === $m['ctr'] ? null : $m['ctr'] * 100, $m['cpc'], $m['page_rpm'], null === $m['coverage'] ? null : $m['coverage'] * 100, null === $m['viewability'] ? null : $m['viewability'] * 100, $m['best_date'], (float) $m['best_value'] );
		}
		$cur = GOAC_UI::currency_code();
		GOAC_UI::send_csv( 'adsense-meses-' . strtolower( $cur ) . '.csv', array( 'Mês', 'Dias', 'Em andamento', 'Receita (' . $cur . ')', 'Média/dia (' . $cur . ')', 'Page views', 'Impressões', 'Cliques', 'CTR (%)', 'CPC (' . $cur . ')', 'Page RPM (' . $cur . ')', 'Cobertura (%)', 'Active View (%)', 'Melhor dia', 'Receita do melhor dia (' . $cur . ')' ), $rows );
	}
}
