<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Aba Visão geral. */
final class GOAC_View_Dashboard {

	public static function render() {
		$c = GOAC_UI::context();
		self::toolbar( $c );
		if ( ! $c['first_day'] ) { self::waiting( $c ); return; }
		echo '<div id="goac-live-block" data-goac-live-block>';
		self::live_block( $c );
		echo '</div>';
		echo '<div class="goac-grid goac-grid-8-4">';
		self::main_chart( $c );
		self::forecast_strip( $c );
		echo '</div>';
		self::periods_table( $c );
		echo '<div class="goac-grid goac-grid-2">';
		self::last_days( $c );
		self::insights( $c );
		echo '</div>';
		echo '<div class="goac-grid goac-grid-2">';
		self::tops();
		self::weekdays( $c );
		echo '</div>';
		echo '<div class="goac-grid goac-grid-2">';
		self::records( $c );
		GOAC_UI::card_open( 'Saúde da conta', '', 'goac-async', 'goac-health' );
		echo '<div data-goac-async="health"><p class="goac-loading">Carregando status dos sites e políticas…</p></div>';
		GOAC_UI::card_close();
		echo '</div>';
	}

	private static function toolbar( array $c ) {
		$synced = (int) $c['meta']['synced_at'];
		echo '<div class="goac-toolbar"><div class="goac-toolbar-main">';
		echo '<span class="goac-pulse ' . ( $c['sync_error'] ? 'is-error' : 'is-ok' ) . '" aria-hidden="true"></span>';
		echo '<strong>' . esc_html( GOAC_UI::weekday( $c['today'], false ) . ', ' . GOAC_UI::date( $c['today'] ) ) . '</strong>';
		echo '<span id="goac-fetched">' . esc_html( $synced ? 'Dados do AdSense de ' . wp_date( 'H:i:s', $synced, $c['tz'] ) : 'Ainda não sincronizado' ) . '</span>';
		echo '<span class="goac-muted">Atualiza sozinho a cada ' . (int) GOAC_UI::refresh_minutes() . ' min · fuso ' . esc_html( $c['tz']->getName() ) . '</span>';
		echo '</div><div class="goac-toolbar-actions"><a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_sync' ) ) . '">Atualizar agora</a></div></div>';
		if ( $c['sync_error'] ) {
			GOAC_UI::notice( 'warning', '<strong>Não foi possível atualizar agora:</strong> ' . esc_html( $c['sync_error'] ) . ( $synced ? ' Exibindo o histórico sincronizado em ' . esc_html( wp_date( 'd/m H:i', $synced, $c['tz'] ) ) . '.' : '' ) );
		} elseif ( $c['stale'] ) {
			GOAC_UI::notice( 'warning', 'Os dados estão desatualizados há mais de 6 horas. Verifique o WP-Cron ou clique em <strong>Atualizar agora</strong>.' );
		}
	}

	private static function waiting( array $c ) {
		$b = $c['backfill'];
		echo '<section class="goac-empty"><span class="dashicons dashicons-database-import"></span><h2>Montando o histórico do AdSense</h2>';
		echo '<p>O plugin guarda cada dia localmente para mostrar todos os dias, totais, meses, anos e previsões sem gastar a cota da API. A primeira importação leva de alguns segundos a poucos minutos.</p>';
		if ( 'running' === $b['state'] ) {
			echo '<div class="goac-backfill" data-goac-backfill="1"><div class="goac-meter"><i style="width:' . esc_attr( (string) round( 100 * GOAC_Store::backfill_progress( $b ) ) ) . '%"></i></div><p data-goac-backfill-text>Importando…</p></div>';
		} else {
			echo '<p><a class="button button-primary button-hero" href="' . esc_url( GOAC_UI::action_url( 'goac_backfill', array( 'mode' => 'start' ) ) ) . '">Importar histórico agora</a></p>';
		}
		echo '</section>';
	}

	/** Bloco atualizado por AJAX: cartões principais, metas e métricas de hoje. */
	public static function live_block( array $c ) {
		$today = $c['today']; $t = $c['rows'][ $today ]; $yrow = $c['rows'][ $c['yesterday'] ] ?? GOAC_Stats::empty_row();
		$est = $c['today_est']; $same = $c['same_time_yesterday'];
		$month_start = GOAC_Stats::month_start( $today ); $month_end = GOAC_Stats::month_end( $today );
		$year_start = substr( $today, 0, 4 ) . '-01-01'; $year_end = substr( $today, 0, 4 ) . '-12-31';
		$mtd = GOAC_Stats::sum( GOAC_UI::rows( $month_start, $today ) );
		$ytd = GOAC_Stats::sum( GOAC_UI::rows( $year_start, $today ) );
		$prev_month = GOAC_Stats::compare_range( array( 'preset' => 'this_month', 'start' => $month_start, 'end' => $today ) );
		$prev_year = GOAC_Stats::compare_range( array( 'preset' => 'this_year', 'start' => $year_start, 'end' => $today ) );
		$mtd_prev = GOAC_Stats::sum( GOAC_UI::comparable_rows( $prev_month['start'], $prev_month['end'], $today ) );
		$ytd_prev = GOAC_Stats::sum( GOAC_UI::comparable_rows( $prev_year['start'], $prev_year['end'], $today ) );
		$month_p = GOAC_UI::projection( $month_start, $month_end );
		$year_p = GOAC_UI::projection( $year_start, $year_end );
		$minute_label = sprintf( '%02d:%02d', intdiv( $c['minute'], 60 ), $c['minute'] % 60 );

		if ( $same && $c['has_today'] ) {
			$today_sub = GOAC_UI::delta( GOAC_Stats::delta( $t['earnings'], $same['earnings'] ), 'vs. ontem até ' . $minute_label );
		} elseif ( $c['has_today'] && $est['fraction'] > 0.03 && $est['model'] > 0 ) {
			$today_sub = GOAC_UI::delta( GOAC_Stats::delta( $t['earnings'], $est['model'] * $est['fraction'] ), 'vs. esperado até ' . $minute_label );
		} else {
			$today_sub = GOAC_UI::delta( GOAC_Stats::delta( $t['earnings'], $yrow['earnings'] ), 'vs. ontem inteiro' );
		}
		$meter = '<span class="goac-meter is-small" title="' . esc_attr( 'Parcela típica do dia já contabilizada: ' . GOAC_UI::pct( $est['fraction'], 0 ) ) . '"><i style="width:' . esc_attr( (string) round( 100 * $est['fraction'] ) ) . '%"></i></span>';

		echo '<div class="goac-kpis goac-kpis-hero">';
		GOAC_UI::kpi( 'Receita hoje (parcial)', GOAC_UI::money( $t['earnings'] ), $today_sub, array( 'class' => 'is-hero is-accent', 'after' => $meter, 'title' => 'Estimativa do AdSense até ' . $minute_label . '. Pode ter atraso de 15–60 min e sofrer ajustes.' ) );
		GOAC_UI::kpi( 'Previsão até 23:59', GOAC_UI::money( $est['projected'] ), esc_html( 'Faixa ' . GOAC_UI::money( $est['low'] ) . ' – ' . GOAC_UI::money( $est['high'] ) . ' · confiança ' . $est['confidence'] ), array( 'class' => 'is-hero', 'title' => 'Combina o ritmo do dia (curva ' . ( 'learned' === $c['profile']['source'] ? 'aprendida' : 'padrão' ) . ') com o modelo diário. Peso do ritmo: ' . GOAC_UI::pct( $est['pace_weight'], 0 ) . '.' ) );
		GOAC_UI::kpi( 'Este mês', GOAC_UI::money( $mtd['earnings'] ), GOAC_UI::delta( GOAC_Stats::delta( $mtd['earnings'], $mtd_prev['earnings'] ), 'vs. ' . GOAC_UI::date( $prev_month['start'], 'd/m' ) . '–' . GOAC_UI::date( $prev_month['end'], 'd/m' ) ), array( 'class' => 'is-hero' ) );
		$goal_m = GOAC_UI::goal( 'month' );
		GOAC_UI::kpi( 'Previsão do mês', GOAC_UI::money( $month_p['projected'] ), esc_html( 'Faixa ' . GOAC_UI::money( $month_p['low'], 0 ) . ' – ' . GOAC_UI::money( $month_p['high'], 0 ) ) . ( $goal_m > 0 ? ' · <strong>' . esc_html( GOAC_UI::pct( $month_p['projected'] / $goal_m, 0 ) ) . ' da meta</strong>' : '' ), array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'Este ano', GOAC_UI::money( $ytd['earnings'] ), GOAC_UI::delta( GOAC_Stats::delta( $ytd['earnings'], $ytd_prev['earnings'] ), 'vs. mesmo período de ' . substr( $prev_year['start'], 0, 4 ) ), array( 'class' => 'is-hero' ) );
		$goal_y = GOAC_UI::goal( 'year' );
		GOAC_UI::kpi( 'Previsão do ano', GOAC_UI::money( $year_p['projected'] ), esc_html( 'Faixa ' . GOAC_UI::money( $year_p['low'], 0 ) . ' – ' . GOAC_UI::money( $year_p['high'], 0 ) ) . ( $goal_y > 0 ? ' · <strong>' . esc_html( GOAC_UI::pct( $year_p['projected'] / $goal_y, 0 ) ) . ' da meta</strong>' : '' ), array( 'class' => 'is-hero' ) );
		echo '</div>';

		if ( $goal_m > 0 || $goal_y > 0 ) {
			echo '<div class="goac-goals">';
			if ( $goal_m > 0 ) { GOAC_UI::goal_meter( 'Meta de ' . GOAC_UI::MONTHS[ (int) substr( $today, 5, 2 ) ], $goal_m, $month_p, GOAC_UI::goal_info( 'month' )['note'] ); }
			if ( $goal_y > 0 ) { GOAC_UI::goal_meter( 'Meta de ' . substr( $today, 0, 4 ), $goal_y, $year_p, GOAC_UI::goal_info( 'year' )['note'] ); }
			echo '</div>';
		}

		// Referência para as métricas de hoje: ontem no mesmo horário; sem instantâneo, ontem proporcional à parcela do dia já contabilizada.
		$compare = $same && $c['has_today'];
		$fraction = $c['has_today'] ? max( 0.0, min( 1.0, (float) $est['fraction'] ) ) : 1.0;
		if ( $compare ) {
			$ref = array( 'earnings' => $same['earnings'], 'page_views' => $same['page_views'], 'impressions' => $same['impressions'], 'clicks' => $same['clicks'] );
			$ref_label = 'vs. ontem até ' . $minute_label;
		} elseif ( $fraction > 0.03 && $fraction < 0.999 ) {
			$ref = array( 'earnings' => $yrow['earnings'] * $fraction, 'page_views' => $yrow['page_views'] * $fraction, 'impressions' => $yrow['impressions'] * $fraction, 'clicks' => $yrow['clicks'] * $fraction );
			$ref_label = 'vs. ontem proporcional';
		} else {
			$ref = $yrow; $ref_label = 'vs. ontem inteiro';
		}
		$ref_derived = GOAC_Stats::derive( array_merge( $yrow, $ref ) );
		$td = GOAC_Stats::derive( $t );
		$pv_est = $c['today_pv_est'];
		echo '<div class="goac-kpis goac-kpis-compact">';
		GOAC_UI::kpi( 'Page views', GOAC_UI::number( $t['page_views'] ), GOAC_UI::delta( GOAC_Stats::delta( $t['page_views'], $ref['page_views'] ), $ref_label ), array( 'title' => 'Previsão até 23:59: ' . GOAC_UI::number( $pv_est['projected'] ) ) );
		GOAC_UI::kpi( 'Impressões', GOAC_UI::number( $t['impressions'] ), GOAC_UI::delta( GOAC_Stats::delta( $t['impressions'], $ref['impressions'] ), $ref_label ) );
		GOAC_UI::kpi( 'Cliques', GOAC_UI::number( $t['clicks'] ), GOAC_UI::delta( GOAC_Stats::delta( $t['clicks'], $ref['clicks'] ), $ref_label ) );
		$ratio_label = $compare ? $ref_label : 'vs. ontem';
		GOAC_UI::kpi( 'Page RPM', GOAC_UI::money( $td['page_rpm'] ), GOAC_UI::delta( GOAC_Stats::delta( $td['page_rpm'], $ref_derived['page_rpm'] ), $ratio_label ) );
		GOAC_UI::kpi( 'RPM de impressão', GOAC_UI::money( $td['impression_rpm'] ), GOAC_UI::delta( GOAC_Stats::delta( $td['impression_rpm'], $ref_derived['impression_rpm'] ), $ratio_label ) );
		GOAC_UI::kpi( 'CTR da página', GOAC_UI::pct( $td['ctr'], 2 ), GOAC_UI::delta( GOAC_Stats::delta( $td['ctr'], $ref_derived['ctr'] ), $ratio_label ) );
		GOAC_UI::kpi( 'CPC médio', GOAC_UI::money( $td['cpc'] ), GOAC_UI::delta( GOAC_Stats::delta( $td['cpc'], $ref_derived['cpc'] ), $ratio_label ) );
		GOAC_UI::kpi( 'Cobertura', GOAC_UI::pct( $td['coverage'] ), esc_html( 'Ontem: ' . GOAC_UI::pct( GOAC_Stats::derive( $yrow )['coverage'] ) ) );
		GOAC_UI::kpi( 'Active View', GOAC_UI::pct( $t['viewability'] ), esc_html( 'Mensurável: ' . GOAC_UI::pct( $t['measurability'] ) ) );
		GOAC_UI::kpi( 'Page views previstos', GOAC_UI::number( $pv_est['projected'] ), esc_html( 'Faixa ' . GOAC_UI::number( $pv_est['low'] ) . ' – ' . GOAC_UI::number( $pv_est['high'] ) ) );
		echo '</div>';
	}

	/** Conjunto de dados do gráfico principal: 180 dias + previsão até o fim do mês. */
	private static function main_chart( array $c ) {
		$today = $c['today'];
		$start = max( $c['first_day'], GOAC_Stats::add_days( $today, -179 ) );
		$rows = GOAC_UI::rows( $start, $today );
		$month_end = GOAC_Stats::month_end( $today );
		$p = GOAC_UI::projection( GOAC_Stats::add_days( $today, 1 ), $month_end );
		$pv = GOAC_UI::projection( GOAC_Stats::add_days( $today, 1 ), $month_end, 'page_views' );
		$labels = array(); $metrics = array( 'earnings' => array(), 'page_views' => array(), 'page_rpm' => array(), 'impressions' => array(), 'clicks' => array(), 'ctr' => array(), 'coverage' => array(), 'impression_rpm' => array() );
		foreach ( $rows as $date => $row ) {
			$labels[] = $date; $d = GOAC_Stats::derive( $row );
			foreach ( $metrics as $k => $list ) { $metrics[ $k ][] = null === $d[ $k ] ? null : round( (float) $d[ $k ], 6 ); }
		}
		$f_earn = array(); $f_low = array(); $f_high = array(); $f_pv = array();
		foreach ( $p['daily'] as $date => $f ) {
			$labels[] = $date; $f_earn[] = round( $f['value'], 4 ); $f_low[] = round( $f['low'], 4 ); $f_high[] = round( $f['high'], 4 );
			$f_pv[] = isset( $pv['daily'][ $date ] ) ? round( $pv['daily'][ $date ]['value'] ) : null;
		}
		$dataset = array(
			'labels' => $labels, 'actualCount' => count( $rows ), 'today' => $today, 'currency' => $c['currency'],
			'metrics' => array(
				'earnings' => array( 'name' => 'Receita', 'format' => 'money', 'values' => $metrics['earnings'], 'forecast' => $f_earn, 'low' => $f_low, 'high' => $f_high ),
				'page_views' => array( 'name' => 'Page views', 'format' => 'number', 'values' => $metrics['page_views'], 'forecast' => $f_pv ),
				'page_rpm' => array( 'name' => 'Page RPM', 'format' => 'money', 'values' => $metrics['page_rpm'] ),
				'impressions' => array( 'name' => 'Impressões', 'format' => 'number', 'values' => $metrics['impressions'] ),
				'clicks' => array( 'name' => 'Cliques', 'format' => 'number', 'values' => $metrics['clicks'] ),
				'ctr' => array( 'name' => 'CTR', 'format' => 'percent', 'values' => $metrics['ctr'] ),
				'coverage' => array( 'name' => 'Cobertura', 'format' => 'percent', 'values' => $metrics['coverage'] ),
				'impression_rpm' => array( 'name' => 'RPM de impressão', 'format' => 'money', 'values' => $metrics['impression_rpm'] ),
			),
		);
		$metric_buttons = '';
		foreach ( array( 'earnings' => 'Receita', 'page_views' => 'Page views', 'page_rpm' => 'Page RPM', 'impressions' => 'Impressões', 'clicks' => 'Cliques', 'ctr' => 'CTR', 'coverage' => 'Cobertura' ) as $k => $label ) {
			$metric_buttons .= '<button type="button" class="' . ( 'earnings' === $k ? 'is-active' : '' ) . '" data-value="' . esc_attr( $k ) . '" aria-pressed="' . ( 'earnings' === $k ? 'true' : 'false' ) . '">' . esc_html( $label ) . '</button>';
		}
		$range_buttons = '';
		foreach ( array( 30, 60, 90, 180 ) as $n ) {
			$range_buttons .= '<button type="button" class="' . ( 60 === $n ? 'is-active' : '' ) . '" data-value="' . (int) $n . '" aria-pressed="' . ( 60 === $n ? 'true' : 'false' ) . '">' . (int) $n . 'd</button>';
		}
		GOAC_UI::card_open( 'Evolução diária', '<div class="goac-seg" data-goac-switch="range" data-target="goac-main-chart" role="group" aria-label="Janela">' . $range_buttons . '</div>', 'goac-span-8' );
		echo '<div class="goac-seg goac-seg-wide" data-goac-switch="metric" data-target="goac-main-chart" role="group" aria-label="Métrica">' . $metric_buttons . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		printf( '<div class="goac-chart" id="goac-main-chart" data-goac-dataset="%s" data-metric="earnings" data-range="60" style="min-height:326px"><p class="goac-chart-fallback">Ative o JavaScript para ver o gráfico.</p></div>', esc_attr( wp_json_encode( $dataset ) ) );
		echo '<p class="goac-footnote">Barras: valor diário (hoje parcial) · linha: média móvel de 7 dias · barras claras com traço: previsão até o fim do mês, com faixa de 80%.</p>';
		GOAC_UI::card_close();
	}

	private static function forecast_strip( array $c ) {
		$today = $c['today'];
		$week_start = GOAC_Stats::week_start( $today );
		$next_month = GOAC_Stats::shift_months( GOAC_Stats::month_start( $today ), 1 );
		$items = array(
			'Hoje' => array( $today, $today ),
			'Amanhã' => array( GOAC_Stats::add_days( $today, 1 ), GOAC_Stats::add_days( $today, 1 ) ),
			'Esta semana' => array( $week_start, GOAC_Stats::add_days( $week_start, 6 ) ),
			'Este mês' => array( GOAC_Stats::month_start( $today ), GOAC_Stats::month_end( $today ) ),
			'Próximo mês (' . GOAC_UI::month_label( substr( $next_month, 0, 7 ) ) . ')' => array( $next_month, GOAC_Stats::month_end( $next_month ) ),
			GOAC_Stats::quarter_of( $today ) . 'º trimestre' => array( GOAC_Stats::quarter_start( $today ), GOAC_Stats::quarter_end( $today ) ),
			'Ano de ' . substr( $today, 0, 4 ) => array( substr( $today, 0, 4 ) . '-01-01', substr( $today, 0, 4 ) . '-12-31' ),
			'Próximos 30 dias' => array( GOAC_Stats::add_days( $today, 1 ), GOAC_Stats::add_days( $today, 30 ) ),
		);
		GOAC_UI::card_open( 'Previsões', '<a href="' . esc_url( GOAC_UI::url( 'forecast' ) ) . '">Detalhes →</a>', 'goac-span-4' );
		echo '<ul class="goac-forecast-list">';
		foreach ( $items as $label => $r ) {
			$p = GOAC_UI::projection( $r[0], $r[1] );
			$share = $p['projected'] > 0 ? $p['realized'] / $p['projected'] : 0;
			echo '<li><div class="goac-fl-head"><span>' . esc_html( $label ) . '</span><strong>' . esc_html( GOAC_UI::money( $p['projected'], $p['projected'] >= 1000 ? 0 : 2 ) ) . '</strong></div>';
			echo '<div class="goac-fl-bar" aria-hidden="true"><i style="width:' . esc_attr( (string) round( 100 * $share, 2 ) ) . '%"></i></div>';
			echo '<div class="goac-fl-sub">' . esc_html( ( $p['realized'] > 0 ? 'Realizado ' . GOAC_UI::money( $p['realized'], 0 ) . ' · ' : '' ) . GOAC_UI::money( $p['low'], 0 ) . ' – ' . GOAC_UI::money( $p['high'], 0 ) ) . '</div></li>';
		}
		echo '</ul>';
		GOAC_UI::card_close();
	}

	private static function periods_table( array $c ) {
		$presets = array( 'today', 'yesterday', 'last_7', 'last_30', 'this_month', 'last_month', 'this_quarter', 'this_year', 'last_year', 'last_12_months', 'all' );
		$projectable = array( 'today' => 'today', 'this_month' => 'month', 'this_quarter' => 'quarter', 'this_year' => 'year' );
		GOAC_UI::card_open( 'Totais por período', '<a href="' . esc_url( GOAC_UI::url( 'days' ) ) . '">Todos os dias →</a>' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-periods"><thead><tr><th>Período</th><th>Datas</th><th class="num">Receita</th><th class="num">Variação</th><th class="num">Média/dia</th><th class="num">Page views</th><th class="num">Impressões</th><th class="num">Cliques</th><th class="num">Page RPM</th><th class="num">CTR</th><th class="num">Cobertura</th><th class="num">Previsão do período</th></tr></thead><tbody>';
		foreach ( $presets as $preset ) {
			$r = GOAC_Stats::resolve_range( $preset, '', '', $c['today'], $c['first_day'], false );
			$rows = GOAC_UI::rows( $r['start'], $r['end'] );
			$s = GOAC_Stats::summary( $rows, $c['today'] );
			$delta = null; $cmp_label = '';
			if ( 'all' !== $preset ) {
				$cmp = GOAC_Stats::compare_range( $r );
				if ( $cmp['start'] >= $c['first_day'] ) {
					$delta = GOAC_Stats::delta( $s['total']['earnings'], GOAC_Stats::sum( GOAC_UI::comparable_rows( $cmp['start'], $cmp['end'], $r['end'] ) )['earnings'] );
					$cmp_label = $cmp['label'];
				}
			}
			$forecast = '—';
			if ( isset( $projectable[ $preset ] ) ) {
				$end = 'today' === $preset ? $c['today'] : ( 'month' === $projectable[ $preset ] ? GOAC_Stats::month_end( $c['today'] ) : ( 'quarter' === $projectable[ $preset ] ? GOAC_Stats::quarter_end( $c['today'] ) : substr( $c['today'], 0, 4 ) . '-12-31' ) );
				$forecast = GOAC_UI::money( GOAC_UI::projection( $r['start'], $end )['projected'] );
			}
			$t = $s['total'];
			echo '<tr><td><a href="' . esc_url( GOAC_UI::url( 'days', array( 'preset' => $preset ) ) ) . '"><strong>' . esc_html( $r['label'] ) . '</strong></a>' . ( 'today' === $preset ? ' <span class="goac-pill">parcial</span>' : '' ) . '</td>';
			echo '<td class="goac-nowrap">' . esc_html( GOAC_UI::range_label( $r['start'], $r['end'] ) ) . '</td>';
			echo '<td class="num"><strong>' . esc_html( GOAC_UI::money( $t['earnings'] ) ) . '</strong></td>';
			echo '<td class="num" title="' . esc_attr( $cmp_label ? 'Comparado com ' . $cmp_label : '' ) . '">' . GOAC_UI::delta( $delta ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num">' . esc_html( GOAC_UI::money( $s['avg']['earnings'] ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::number( $t['page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $t['impressions'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $t['clicks'] ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::money( $t['page_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $t['ctr'], 2 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $t['coverage'] ) ) . '</td>';
			echo '<td class="num">' . esc_html( $forecast ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function last_days( array $c ) {
		$today = $c['today'];
		$rows = GOAC_UI::rows( GOAC_Stats::add_days( $today, -13 ), $today );
		$max = 0.0; foreach ( $rows as $r ) { $max = max( $max, (float) $r['earnings'] ); }
		GOAC_UI::card_open( 'Últimos 14 dias', '<a href="' . esc_url( GOAC_UI::url( 'days', array( 'preset' => 'last_90', 'include_today' => 1 ) ) ) . '">Ver 90 dias →</a>' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Dia</th><th class="num">Receita</th><th class="num" title="Mesmo dia da semana anterior">vs. sem. ant.</th><th class="num">Page views</th><th class="num">Page RPM</th><th class="num">CTR</th></tr></thead><tbody>';
		foreach ( array_reverse( $rows, true ) as $date => $r ) {
			$d = GOAC_Stats::derive( $r );
			$prev = $c['rows'][ GOAC_Stats::add_days( $date, -7 ) ] ?? null;
			echo '<tr' . ( $date === $today ? ' class="is-partial"' : '' ) . '><td class="goac-nowrap"><strong>' . esc_html( GOAC_UI::weekday( $date ) . ' ' . GOAC_UI::date( $date, 'd/m' ) ) . '</strong>' . ( $date === $today ? ' <span class="goac-pill">parcial</span>' : '' ) . '</td>';
			echo '<td class="num goac-cell-bar">' . GOAC_UI::bar( $max > 0 ? $r['earnings'] / $max : 0 ) . '<span>' . esc_html( GOAC_UI::money( $r['earnings'] ) ) . '</span></td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num">' . ( $date === $today ? '<span class="goac-muted">—</span>' : GOAC_UI::delta( $prev ? GOAC_Stats::delta( $r['earnings'], $prev['earnings'] ) : null ) ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num">' . esc_html( GOAC_UI::number( $r['page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $d['page_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $d['ctr'], 2 ) ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	/** Leituras automáticas do histórico; cada item tem ícone + texto (nunca só cor). */
	private static function insights( array $c ) {
		$items = array();
		$today = $c['today']; $y = $c['yesterday']; $rows = $c['rows'];
		$add = static function( $type, $text ) use ( &$items ) { $items[] = array( $type, $text ); };
		$t = $rows[ $today ];

		if ( $c['same_time_yesterday'] && $c['same_time_yesterday']['earnings'] > 0 && $c['has_today'] ) {
			$d = GOAC_Stats::delta( $t['earnings'], $c['same_time_yesterday']['earnings'] );
			if ( null !== $d && abs( $d ) >= 0.1 ) {
				$add( $d > 0 ? 'good' : 'warn', sprintf( 'Hoje está %s em relação a ontem no mesmo horário (%s contra %s).', GOAC_UI::signed_pct( $d ), GOAC_UI::money( $t['earnings'] ), GOAC_UI::money( $c['same_time_yesterday']['earnings'] ) ) );
			}
		}
		$last7 = GOAC_Stats::sum( GOAC_UI::rows( GOAC_Stats::add_days( $y, -6 ), $y ) );
		$prev28 = GOAC_Stats::sum( GOAC_UI::rows( GOAC_Stats::add_days( $y, -34 ), GOAC_Stats::add_days( $y, -7 ) ) );
		$d_rpm = GOAC_Stats::delta( $last7['page_rpm'], $prev28['page_rpm'] );
		if ( null !== $d_rpm && abs( $d_rpm ) >= 0.08 ) {
			$add( $d_rpm > 0 ? 'good' : 'warn', sprintf( 'Page RPM dos últimos 7 dias (%s) está %s em relação às 4 semanas anteriores (%s).', GOAC_UI::money( $last7['page_rpm'] ), GOAC_UI::signed_pct( $d_rpm ), GOAC_UI::money( $prev28['page_rpm'] ) ) );
		}
		$d_pv = GOAC_Stats::delta( $last7['page_views'] / 7, $prev28['page_views'] / 28 );
		if ( null !== $d_pv && abs( $d_pv ) >= 0.1 ) {
			$add( $d_pv > 0 ? 'good' : 'warn', sprintf( 'Tráfego: média de %s page views/dia na última semana, %s frente às 4 semanas anteriores.', GOAC_UI::number( $last7['page_views'] / 7 ), GOAC_UI::signed_pct( $d_pv ) ) );
		}
		if ( null !== $last7['coverage'] && $last7['coverage'] < 0.85 ) {
			$add( 'warn', sprintf( 'Cobertura de %s na última semana: parte das solicitações ficou sem anúncio.', GOAC_UI::pct( $last7['coverage'] ) ) );
		}
		if ( null !== $last7['viewability'] ) {
			if ( $last7['viewability'] < 0.5 ) { $add( 'warn', sprintf( 'Visibilidade Active View de %s na última semana, abaixo de 50%%. Blocos fora da tela reduzem o valor dos lances.', GOAC_UI::pct( $last7['viewability'] ) ) ); }
			elseif ( $last7['viewability'] >= 0.7 ) { $add( 'good', sprintf( 'Boa visibilidade Active View: %s na última semana.', GOAC_UI::pct( $last7['viewability'] ) ) ); }
		}
		$ctr28 = GOAC_Stats::sum( GOAC_UI::rows( GOAC_Stats::add_days( $y, -27 ), $y ) )['ctr'];
		$td = GOAC_Stats::derive( $t );
		if ( $ctr28 && $td['ctr'] && $t['page_views'] >= 200 && $td['ctr'] > 2 * $ctr28 ) {
			$add( 'warn', sprintf( 'CTR de hoje (%s) está mais que o dobro da média de 28 dias (%s). Vale monitorar possíveis cliques inválidos.', GOAC_UI::pct( $td['ctr'], 2 ), GOAC_UI::pct( $ctr28, 2 ) ) );
		}
		$month_p = GOAC_UI::projection( GOAC_Stats::month_start( $today ), GOAC_Stats::month_end( $today ) );
		$last_month = GOAC_Stats::resolve_range( 'last_month', '', '', $today );
		if ( $last_month['start'] >= $c['first_day'] ) {
			$lm = GOAC_Stats::sum( GOAC_UI::rows( $last_month['start'], $last_month['end'] ) )['earnings'];
			$d = GOAC_Stats::delta( $month_p['projected'], $lm );
			if ( null !== $d ) {
				$add( $d >= 0 ? 'good' : 'info', sprintf( 'A previsão do mês (%s) fica %s em relação a %s (%s).', GOAC_UI::money( $month_p['projected'], 0 ), GOAC_UI::signed_pct( $d ), mb_strtolower( GOAC_UI::month_label( substr( $last_month['start'], 0, 7 ), true ) ), GOAC_UI::money( $lm, 0 ) ) );
			}
		}
		$year_p = GOAC_UI::projection( substr( $today, 0, 4 ) . '-01-01', substr( $today, 0, 4 ) . '-12-31' );
		$ly = ( (int) substr( $today, 0, 4 ) - 1 );
		if ( $ly . '-01-01' >= $c['first_day'] ) {
			$ly_total = GOAC_Stats::sum( GOAC_UI::rows( $ly . '-01-01', $ly . '-12-31' ) )['earnings'];
			$d = GOAC_Stats::delta( $year_p['projected'], $ly_total );
			if ( null !== $d ) { $add( $d >= 0 ? 'good' : 'info', sprintf( 'Projeção de %s: %s, %s frente ao total de %d (%s).', substr( $today, 0, 4 ), GOAC_UI::money( $year_p['projected'], 0 ), GOAC_UI::signed_pct( $d ), $ly, GOAC_UI::money( $ly_total, 0 ) ) ); }
		}
		$window = GOAC_UI::rows( GOAC_Stats::add_days( $y, -89 ), $y );
		if ( count( $window ) >= 30 && isset( $window[ $y ] ) ) {
			$best = max( array_column( $window, 'earnings' ) );
			if ( (float) $window[ $y ]['earnings'] >= $best && $best > 0 ) { $add( 'good', sprintf( 'Ontem (%s) foi o melhor dia dos últimos 90 dias.', GOAC_UI::money( $window[ $y ]['earnings'] ) ) ); }
		}
		$profile = GOAC_Stats::weekday_profile( $rows, $today, 12 );
		$best_w = null; foreach ( $profile as $w => $p ) { if ( $p['days'] && ( null === $best_w || $p['avg_earnings'] > $profile[ $best_w ]['avg_earnings'] ) ) { $best_w = $w; } }
		if ( null !== $best_w && $profile[ $best_w ]['index'] ) {
			$add( 'info', sprintf( '%s é o dia mais forte nas últimas 12 semanas: média de %s (%s acima da média semanal).', GOAC_UI::WEEKDAYS[ $best_w ], GOAC_UI::money( $profile[ $best_w ]['avg_earnings'] ), GOAC_UI::signed_pct( $profile[ $best_w ]['index'] - 1 ) ) );
		}
		if ( 'running' === $c['backfill']['state'] ) { $add( 'info', 'O histórico completo ainda está sendo importado; comparações anuais e sazonalidade ficam mais precisas ao final.' ); }
		elseif ( empty( $c['model']['season']['ok'] ) ) { $add( 'info', 'Com mais de 13 meses de histórico as previsões passam a considerar a sazonalidade anual (ex.: fim de ano).' ); }

		$icons = array( 'good' => '▲', 'warn' => '!', 'info' => 'i' );
		$labels = array( 'good' => 'Positivo', 'warn' => 'Atenção', 'info' => 'Informação' );
		GOAC_UI::card_open( 'Leituras automáticas' );
		if ( ! $items ) { GOAC_UI::empty_state( 'Nada fora do comum no momento.' ); }
		else {
			echo '<ul class="goac-insights">';
			foreach ( $items as $item ) {
				echo '<li class="is-' . esc_attr( $item[0] ) . '"><span class="goac-insight-icon" aria-label="' . esc_attr( $labels[ $item[0] ] ) . '">' . esc_html( $icons[ $item[0] ] ) . '</span><span>' . esc_html( $item[1] ) . '</span></li>';
			}
			echo '</ul>';
		}
		GOAC_UI::card_close();
	}

	private static function tops() {
		$tabs = array( 'country' => 'Países', 'page' => 'Páginas', 'platform' => 'Plataformas', 'unit' => 'Unidades', 'format' => 'Formatos', 'traffic' => 'Origem' );
		$periods = array( 'today' => 'Hoje', 'yesterday' => 'Ontem', 'last_7' => '7 dias', 'this_month' => 'Este mês', 'last_30' => '30 dias' );
		$aside = '<select data-goac-top-period aria-label="Período">';
		foreach ( $periods as $k => $label ) { $aside .= '<option value="' . esc_attr( $k ) . '"' . selected( 'this_month', $k, false ) . '>' . esc_html( $label ) . '</option>'; }
		$aside .= '</select>';
		GOAC_UI::card_open( 'Onde a receita acontece', $aside, 'goac-tops' );
		echo '<div class="goac-seg goac-seg-wide" data-goac-top-tabs role="tablist">';
		$first = true;
		foreach ( $tabs as $k => $label ) {
			echo '<button type="button" role="tab" data-value="' . esc_attr( $k ) . '" class="' . ( $first ? 'is-active' : '' ) . '" aria-selected="' . ( $first ? 'true' : 'false' ) . '">' . esc_html( $label ) . '</button>';
			$first = false;
		}
		echo '</div><div data-goac-async="top" data-dimension="country" data-period="this_month"><p class="goac-loading">Carregando…</p></div>';
		echo '<p class="goac-footnote"><a href="' . esc_url( GOAC_UI::url( 'reports' ) ) . '">Relatório completo por dimensão →</a></p>';
		GOAC_UI::card_close();
	}

	private static function weekdays( array $c ) {
		$profile = GOAC_Stats::weekday_profile( $c['rows'], $c['today'], 12 );
		$labels = array(); $values = array();
		foreach ( $profile as $w => $p ) { $labels[] = GOAC_UI::WEEKDAYS_SHORT[ $w ]; $values[] = round( $p['avg_earnings'], 4 ); }
		GOAC_UI::card_open( 'Dias da semana', '<span class="goac-muted">últimas 12 semanas</span>' );
		GOAC_UI::chart( array( 'labels' => $labels, 'labelType' => 'text', 'format' => 'money', 'series' => array( array( 'name' => 'Receita média', 'type' => 'bar', 'values' => $values ) ) ), 180 );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Dia</th><th class="num">Receita média</th><th class="num">Índice</th><th class="num">Page views</th><th class="num">Page RPM</th><th class="num">CTR</th></tr></thead><tbody>';
		foreach ( $profile as $w => $p ) {
			echo '<tr><td>' . esc_html( GOAC_UI::WEEKDAYS[ $w ] ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $p['avg_earnings'] ) ) . '</td><td class="num">' . GOAC_UI::delta( null === $p['index'] ? null : $p['index'] - 1 ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $p['avg_page_views'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $p['page_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $p['ctr'], 2 ) ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function records( array $c ) {
		$r = GOAC_Stats::records( $c['rows'], $c['today'] );
		GOAC_UI::card_open( 'Recordes e histórico', '<span class="goac-muted">desde ' . esc_html( GOAC_UI::date( $c['first_day'] ) ) . '</span>' );
		echo '<div class="goac-records">';
		$item = static function( $label, $value, $sub ) {
			echo '<div><span>' . esc_html( $label ) . '</span><strong>' . esc_html( $value ) . '</strong><small>' . esc_html( $sub ) . '</small></div>';
		};
		if ( $r['best_day'] ) { $item( 'Melhor dia', GOAC_UI::money( $r['best_day']['value'] ), GOAC_UI::weekday( $r['best_day']['date'] ) . ', ' . GOAC_UI::date( $r['best_day']['date'] ) ); }
		if ( $r['best_week'] ) { $item( 'Melhor semana', GOAC_UI::money( $r['best_week']['value'] ), GOAC_UI::date( $r['best_week']['start'], 'd/m' ) . ' a ' . GOAC_UI::date( $r['best_week']['end'] ) ); }
		if ( $r['best_month'] ) { $item( 'Melhor mês', GOAC_UI::money( $r['best_month']['value'] ), GOAC_UI::month_label( $r['best_month']['key'], true ) . ( $r['best_month']['partial'] ? ' (em andamento)' : '' ) ); }
		if ( $r['best_year'] ) { $item( 'Melhor ano', GOAC_UI::money( $r['best_year']['value'], 0 ), $r['best_year']['key'] . ( $r['best_year']['partial'] ? ' (em andamento)' : '' ) ); }
		if ( $r['best_page_views'] ) { $item( 'Maior tráfego', GOAC_UI::number( $r['best_page_views']['value'] ) . ' pv', GOAC_UI::date( $r['best_page_views']['date'] ) ); }
		if ( $r['best_rpm'] ) { $item( 'Maior Page RPM', GOAC_UI::money( $r['best_rpm']['value'] ), GOAC_UI::date( $r['best_rpm']['date'] ) . ' · ' . GOAC_UI::number( $r['best_rpm']['page_views'] ) . ' pv' ); }
		$item( 'Receita no histórico', GOAC_UI::money( $r['total'], 0 ), GOAC_UI::number( $r['active_days'] ) . ' dias com receita' );
		$item( 'Média diária no histórico', GOAC_UI::money( $r['days'] ? $r['total'] / $r['days'] : 0 ), GOAC_UI::number( $r['days'] ) . ' dias registrados' );
		echo '</div>';
		GOAC_UI::card_close();
	}

	/** HTML do cartão de saúde (carregado por AJAX, pois consulta sites e políticas). */
	public static function health_html() {
		$c = GOAC_API::connection(); $sites = GOAC_API::sites(); $issues = GOAC_API::policy_issues(); $alerts = GOAC_API::alerts();
		$ready = 0; $attention = 0; $auto = 0;
		if ( is_array( $sites ) ) {
			foreach ( $sites as $s ) {
				if ( 'READY' === ( $s['state'] ?? '' ) ) { $ready++; }
				if ( 'NEEDS_ATTENTION' === ( $s['state'] ?? '' ) ) { $attention++; }
				if ( ! empty( $s['autoAdsEnabled'] ) ) { $auto++; }
			}
		}
		$count = static function( $items ) { return is_array( $items ) ? count( $items ) : 'Indisponível'; };
		$cells = array(
			'Conta' => (string) ( $c['account_state'] ?? '—' ),
			'Sites prontos' => is_array( $sites ) ? $ready : 'Indisponível',
			'Auto Ads ativos' => is_array( $sites ) ? $auto : 'Indisponível',
			'Sites com atenção' => is_array( $sites ) ? $attention : 'Indisponível',
			'Ocorrências de política' => $count( $issues ),
			'Alertas da conta' => $count( $alerts ),
			'Publisher ID' => (string) ( $c['publisher_id'] ?? '—' ),
			'Fuso dos relatórios' => (string) ( $c['timezone'] ?? '—' ),
		);
		$html = '<div class="goac-health">';
		foreach ( $cells as $label => $value ) {
			$flag = in_array( $label, array( 'Sites com atenção', 'Ocorrências de política' ), true ) && is_int( $value ) && $value > 0;
			$html .= '<div' . ( $flag ? ' class="is-warn"' : '' ) . '><span>' . esc_html( $label ) . '</span><strong>' . ( $flag ? '<span aria-hidden="true">! </span>' : '' ) . esc_html( (string) $value ) . '</strong></div>';
		}
		return $html . '</div><p class="goac-footnote"><a href="' . esc_url( GOAC_UI::url( 'sites' ) ) . '">Sites, políticas e alertas →</a></p>';
	}
}
