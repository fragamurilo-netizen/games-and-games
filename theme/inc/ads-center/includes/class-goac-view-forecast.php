<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Aba Previsões & metas. */
final class GOAC_View_Forecast {

	public static function render() {
		$c = GOAC_UI::context();
		if ( ! $c['first_day'] ) { GOAC_UI::empty_state( 'O histórico ainda não foi importado. Veja o andamento na Visão geral.' ); return; }
		if ( ! empty( $c['model']['n'] ) && $c['model']['n'] < 28 ) {
			GOAC_UI::notice( 'info', 'Há apenas ' . (int) $c['model']['n'] . ' dias de histórico. As previsões funcionam, mas ficam mais precisas (e com faixas mais estreitas) a partir de 8 semanas.' );
		}
		self::headline( $c );
		self::goals( $c );
		echo '<div class="goac-grid goac-grid-2">';
		self::month_daily_chart( $c );
		self::month_cumulative_chart( $c );
		echo '</div><div class="goac-grid goac-grid-2">';
		self::year_chart( $c );
		self::year_cumulative_chart( $c );
		echo '</div>';
		self::methods( $c );
		echo '<div class="goac-grid goac-grid-8-4">';
		self::daily_table( $c );
		self::diagnostics( $c );
		echo '</div>';
		self::methodology();
	}

	private static function periods( array $c ) {
		$t = $c['today']; $y = substr( $t, 0, 4 );
		$ws = GOAC_Stats::week_start( $t ); $nm = GOAC_Stats::shift_months( GOAC_Stats::month_start( $t ), 1 ); $nq = GOAC_Stats::shift_months( GOAC_Stats::quarter_start( $t ), 3 );
		return array(
			array( 'Hoje até 23:59', $t, $t, 'day' ),
			array( 'Amanhã (' . GOAC_UI::weekday( GOAC_Stats::add_days( $t, 1 ) ) . ')', GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 1 ), 'day' ),
			array( 'Esta semana', $ws, GOAC_Stats::add_days( $ws, 6 ), 'week' ),
			array( 'Próxima semana', GOAC_Stats::add_days( $ws, 7 ), GOAC_Stats::add_days( $ws, 13 ), 'week' ),
			array( GOAC_UI::MONTHS[ (int) substr( $t, 5, 2 ) ] . ' (este mês)', GOAC_Stats::month_start( $t ), GOAC_Stats::month_end( $t ), 'month' ),
			array( GOAC_UI::MONTHS[ (int) substr( $nm, 5, 2 ) ] . ' (próximo mês)', $nm, GOAC_Stats::month_end( $nm ), 'month' ),
			array( GOAC_Stats::quarter_of( $t ) . 'º trimestre', GOAC_Stats::quarter_start( $t ), GOAC_Stats::quarter_end( $t ), 'quarter' ),
			array( GOAC_Stats::quarter_of( $nq ) . 'º trimestre de ' . substr( $nq, 0, 4 ), $nq, GOAC_Stats::quarter_end( $nq ), 'quarter' ),
			array( 'Ano de ' . $y, $y . '-01-01', $y . '-12-31', 'year' ),
			array( 'Próximos 7 dias', GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 7 ), 'rolling' ),
			array( 'Próximos 30 dias', GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 30 ), 'rolling' ),
			array( 'Próximos 90 dias', GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 90 ), 'rolling' ),
			array( 'Próximos 12 meses', GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 365 ), 'rolling' ),
		);
	}

	private static function headline( array $c ) {
		echo '<div class="goac-forecast-grid">';
		foreach ( self::periods( $c ) as $p ) {
			list( $label, $start, $end, $kind ) = $p;
			$pr = GOAC_UI::projection( $start, $end );
			$ly_start = GOAC_Stats::shift_years( $start, -1 ); $ly_end = GOAC_Stats::shift_years( $end, -1 );
			$ly = $ly_start >= $c['first_day'] ? GOAC_Stats::sum( GOAC_UI::rows( $ly_start, $ly_end ) )['earnings'] : null;
			$share = $pr['projected'] > 0 ? $pr['realized'] / $pr['projected'] : 0;
			echo '<div class="goac-fcard' . ( 'year' === $kind || 'month' === $kind && $start <= $c['today'] ? ' is-key' : '' ) . '">';
			echo '<span class="goac-fcard-label">' . esc_html( $label ) . '</span>';
			echo '<strong>' . esc_html( GOAC_UI::money( $pr['projected'], $pr['projected'] >= 10000 ? 0 : 2 ) ) . '</strong>';
			echo '<span class="goac-fcard-range" title="Faixa de 80%: há 1 chance em 10 de ficar abaixo e 1 em 10 de ficar acima.">' . esc_html( GOAC_UI::money( $pr['low'], 0 ) . ' – ' . GOAC_UI::money( $pr['high'], 0 ) ) . '</span>';
			echo '<div class="goac-fl-bar" aria-hidden="true"><i style="width:' . esc_attr( (string) round( 100 * $share, 2 ) ) . '%"></i></div>';
			$sub = array();
			if ( $pr['realized'] > 0 ) { $sub[] = 'realizado ' . GOAC_UI::money( $pr['realized'], 0 ); }
			if ( $pr['days_left'] > 0 && $pr['days'] > 1 ) { $sub[] = $pr['days_left'] . ' de ' . $pr['days'] . ' dias pela frente'; }
			if ( 'rolling' === $kind ) { $sub[] = GOAC_UI::money( $pr['projected'] / max( 1, $pr['days'] ) ) . '/dia'; }
			echo '<small>' . esc_html( implode( ' · ', $sub ) ) . '</small>';
			if ( null !== $ly && $ly > 0 ) { echo '<small>' . GOAC_UI::delta( GOAC_Stats::delta( $pr['projected'], $ly ), 'vs. mesmo período do ano anterior' ) . '</small>'; } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '</div>';
		}
		echo '</div>';
	}

	private static function goals( array $c ) {
		$t = $c['today']; $y = substr( $t, 0, 4 );
		$goal_m = GOAC_UI::goal( 'month' ); $goal_y = GOAC_UI::goal( 'year' );
		$info_m = GOAC_UI::goal_info( 'month' ); $info_y = GOAC_UI::goal_info( 'year' );
		GOAC_UI::card_open( 'Metas', '', 'goac-goals-card' );
		echo '<div class="goac-grid goac-grid-2 goac-grid-flat"><div>';
		if ( $goal_m > 0 ) { GOAC_UI::goal_meter( 'Meta de ' . GOAC_UI::MONTHS[ (int) substr( $t, 5, 2 ) ], $goal_m, GOAC_UI::projection( GOAC_Stats::month_start( $t ), GOAC_Stats::month_end( $t ) ), $info_m['note'] ); }
		if ( $goal_y > 0 ) { GOAC_UI::goal_meter( 'Meta de ' . $y, $goal_y, GOAC_UI::projection( $y . '-01-01', $y . '-12-31' ), $info_y['note'] ); }
		if ( $goal_m <= 0 && $goal_y <= 0 ) { echo '<p class="goac-muted">Defina metas para acompanhar quanto falta, quanto é preciso faturar por dia e a chance estimada de chegar lá.</p>'; }
		$last_month = GOAC_Stats::resolve_range( 'last_month', '', '', $t );
		$lm_total = GOAC_Stats::sum( GOAC_UI::rows( $last_month['start'], $last_month['end'] ) )['earnings'];
		$ly_total = GOAC_Stats::sum( GOAC_UI::rows( ( (int) $y - 1 ) . '-01-01', ( (int) $y - 1 ) . '-12-31' ) )['earnings'];
		echo '</div><form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="goac-goal-form">';
		wp_nonce_field( 'goac_save_goals' );
		echo '<input type="hidden" name="action" value="goac_save_goals">';
		printf( '<label>Meta mensal (%s)<input type="number" min="0" step="0.01" name="goal_month" value="%s" placeholder="%s"></label>', esc_html( $c['currency'] ?: 'moeda da conta' ), esc_attr( $goal_m > 0 && ! $info_m['note'] ? (string) round( $goal_m, 2 ) : '' ), esc_attr( $info_m['note'] ? 'Atual: ' . GOAC_UI::money( $goal_m, 0 ) . ' (' . $info_m['note'] . ')' : ( $lm_total > 0 ? 'Mês passado: ' . number_format( $lm_total, 2, ',', '.' ) : '' ) ) );
		printf( '<label>Meta anual (%s)<input type="number" min="0" step="0.01" name="goal_year" value="%s" placeholder="%s"></label>', esc_html( $c['currency'] ?: 'moeda da conta' ), esc_attr( $goal_y > 0 && ! $info_y['note'] ? (string) round( $goal_y, 2 ) : '' ), esc_attr( $info_y['note'] ? 'Atual: ' . GOAC_UI::money( $goal_y, 0 ) . ' (' . $info_y['note'] . ')' : ( $ly_total > 0 ? 'Ano passado: ' . number_format( $ly_total, 2, ',', '.' ) : '' ) ) );
		echo '<button class="button button-primary">Salvar metas</button><p class="goac-footnote">As metas ficam guardadas por moeda (' . esc_html( $c['currency'] ) . '). Use 0 para desativar; em branco usa a meta da outra moeda convertida, se houver.</p></form></div>';
		GOAC_UI::card_close();
	}

	private static function month_daily_chart( array $c ) {
		$t = $c['today']; $start = GOAC_Stats::month_start( $t ); $end = GOAC_Stats::month_end( $t );
		$p = GOAC_UI::projection( $start, $end );
		$labels = array(); $values = array(); $forecast = array(); $low = array(); $high = array();
		$est = $c['today_est'];
		for ( $d = $start; $d <= $end; $d = GOAC_Stats::add_days( $d, 1 ) ) {
			$labels[] = $d;
			if ( $d < $t ) {
				$values[] = round( (float) ( $c['rows'][ $d ]['earnings'] ?? 0 ), 2 ); $forecast[] = null; $low[] = null; $high[] = null;
			} elseif ( $d === $t ) {
				$values[] = round( $est['partial'], 2 ); $forecast[] = round( $est['projected'], 2 ); $low[] = round( $est['low'], 2 ); $high[] = round( $est['high'], 2 );
			} else {
				$f = $p['daily'][ $d ] ?? array( 'value' => 0, 'low' => 0, 'high' => 0 );
				$values[] = null; $forecast[] = round( $f['value'], 2 ); $low[] = round( $f['low'], 2 ); $high[] = round( $f['high'], 2 );
			}
		}
		$cfg = array( 'labels' => $labels, 'labelType' => 'date', 'format' => 'money', 'today' => $t, 'series' => array( array( 'name' => 'Receita do dia', 'type' => 'bar', 'values' => $values, 'forecast' => $forecast, 'low' => $low, 'high' => $high ) ), 'forecastLabel' => 'Previsão (hoje: até 23:59)' );
		$goal = GOAC_UI::goal( 'month' );
		if ( $goal > 0 && $p['days_left'] > 0 && $goal > $p['realized'] ) {
			$cfg['goal'] = array( 'value' => round( ( $goal - $p['realized'] ) / $p['days_left'], 2 ), 'label' => 'Necessário por dia para a meta' );
		}
		GOAC_UI::card_open( 'Dia a dia de ' . GOAC_UI::month_label( substr( $t, 0, 7 ), true ) );
		GOAC_UI::chart( $cfg, 260 );
		GOAC_UI::card_close();
	}

	private static function month_cumulative_chart( array $c ) {
		$t = $c['today']; $start = GOAC_Stats::month_start( $t ); $end = GOAC_Stats::month_end( $t );
		$prev_start = GOAC_Stats::shift_months( $start, -1 );
		$labels = array(); $real = array(); $proj = array(); $low = array(); $high = array(); $prev = array();
		$acc = 0.0; $prev_acc = 0.0; $i = 0;
		for ( $d = $start; $d <= $end; $d = GOAC_Stats::add_days( $d, 1 ), $i++ ) {
			$labels[] = (string) ( $i + 1 );
			if ( $d <= $t ) { $acc += (float) ( $c['rows'][ $d ]['earnings'] ?? 0 ); $real[] = round( $acc, 2 ); } else { $real[] = null; }
			if ( $d >= $t ) {
				$pp = GOAC_UI::projection( $start, $d );
				$proj[] = round( $pp['projected'], 2 ); $low[] = round( $pp['low'], 2 ); $high[] = round( $pp['high'], 2 );
			} else {
				$proj[] = null; $low[] = null; $high[] = null;
			}
			$pd = GOAC_Stats::add_days( $prev_start, $i );
			if ( substr( $pd, 0, 7 ) === substr( $prev_start, 0, 7 ) && isset( $c['rows'][ $pd ] ) ) { $prev_acc += (float) $c['rows'][ $pd ]['earnings']; $prev[] = round( $prev_acc, 2 ); } else { $prev[] = null; }
		}
		$series = array(
			array( 'name' => 'Acumulado realizado', 'type' => 'line', 'values' => $real ),
			array( 'name' => 'Acumulado previsto', 'type' => 'line', 'values' => $proj, 'dashed' => true, 'low' => $low, 'high' => $high, 'color' => 'accent-light' ),
		);
		if ( array_filter( $prev, 'is_numeric' ) ) { $series[] = array( 'name' => GOAC_UI::MONTHS[ (int) substr( $prev_start, 5, 2 ) ] . ' (acumulado)', 'type' => 'line', 'values' => $prev, 'color' => 'muted' ); }
		$cfg = array( 'labels' => $labels, 'labelType' => 'text', 'labelPrefix' => 'Dia ', 'format' => 'money', 'series' => $series );
		$goal = GOAC_UI::goal( 'month' );
		if ( $goal > 0 ) { $cfg['goal'] = array( 'value' => $goal, 'label' => 'Meta do mês' ); }
		GOAC_UI::card_open( 'Acumulado do mês', '<span class="goac-muted">faixa sombreada: 80%</span>' );
		GOAC_UI::chart( $cfg, 260 );
		GOAC_UI::card_close();
	}

	private static function year_chart( array $c ) {
		$t = $c['today']; $y = substr( $t, 0, 4 ); $cur_m = substr( $t, 0, 7 );
		$labels = array(); $values = array(); $forecast = array(); $low = array(); $high = array(); $ly = array();
		for ( $m = 1; $m <= 12; $m++ ) {
			$ms = sprintf( '%s-%02d-01', $y, $m ); $key = substr( $ms, 0, 7 ); $me = GOAC_Stats::month_end( $ms );
			$labels[] = $key;
			if ( $key < $cur_m ) {
				$values[] = round( GOAC_Stats::sum( GOAC_UI::rows( $ms, $me ) )['earnings'], 2 ); $forecast[] = null; $low[] = null; $high[] = null;
			} else {
				$p = GOAC_UI::projection( $ms, $me );
				$values[] = $key === $cur_m ? round( $p['realized'], 2 ) : null; $forecast[] = round( $p['projected'], 2 ); $low[] = round( $p['low'], 2 ); $high[] = round( $p['high'], 2 );
			}
			$lys = GOAC_Stats::shift_years( $ms, -1 );
			$ly[] = $lys >= GOAC_Stats::month_start( $c['first_day'] ) ? round( GOAC_Stats::sum( GOAC_UI::rows( $lys, GOAC_Stats::month_end( $lys ) ) )['earnings'], 2 ) : null;
		}
		$series = array( array( 'name' => 'Receita do mês', 'type' => 'bar', 'values' => $values, 'forecast' => $forecast, 'low' => $low, 'high' => $high ) );
		if ( array_filter( $ly, 'is_numeric' ) ) { $series[] = array( 'name' => (string) ( (int) $y - 1 ), 'type' => 'line', 'values' => $ly, 'color' => 'muted' ); }
		GOAC_UI::card_open( 'Meses de ' . $y );
		GOAC_UI::chart( array( 'labels' => $labels, 'labelType' => 'month', 'format' => 'money', 'series' => $series, 'forecastLabel' => 'Previsão do mês completo' ), 260 );
		GOAC_UI::card_close();
	}

	private static function year_cumulative_chart( array $c ) {
		$t = $c['today']; $y = substr( $t, 0, 4 ); $cur_m = substr( $t, 0, 7 );
		$labels = array(); $real = array(); $proj = array(); $low = array(); $high = array(); $ly = array();
		$acc = 0.0; $ly_acc = 0.0;
		for ( $m = 1; $m <= 12; $m++ ) {
			$ms = sprintf( '%s-%02d-01', $y, $m ); $key = substr( $ms, 0, 7 ); $me = GOAC_Stats::month_end( $ms );
			$labels[] = $key;
			if ( $key < $cur_m ) { $acc += GOAC_Stats::sum( GOAC_UI::rows( $ms, $me ) )['earnings']; $real[] = round( $acc, 2 ); $proj[] = null; $low[] = null; $high[] = null; }
			else {
				$p = GOAC_UI::projection( $y . '-01-01', $me );
				$real[] = $key === $cur_m ? round( $p['realized'], 2 ) : null;
				$proj[] = round( $p['projected'], 2 ); $low[] = round( $p['low'], 2 ); $high[] = round( $p['high'], 2 );
			}
			$lys = GOAC_Stats::shift_years( $ms, -1 );
			if ( $lys >= GOAC_Stats::month_start( $c['first_day'] ) ) { $ly_acc += GOAC_Stats::sum( GOAC_UI::rows( $lys, GOAC_Stats::month_end( $lys ) ) )['earnings']; $ly[] = round( $ly_acc, 2 ); } else { $ly[] = null; }
		}
		$series = array(
			array( 'name' => 'Acumulado realizado', 'type' => 'line', 'values' => $real ),
			array( 'name' => 'Acumulado previsto', 'type' => 'line', 'values' => $proj, 'dashed' => true, 'low' => $low, 'high' => $high, 'color' => 'accent-light' ),
		);
		if ( array_filter( $ly, 'is_numeric' ) ) { $series[] = array( 'name' => ( (int) $y - 1 ) . ' (acumulado)', 'type' => 'line', 'values' => $ly, 'color' => 'muted' ); }
		$cfg = array( 'labels' => $labels, 'labelType' => 'month', 'format' => 'money', 'series' => $series );
		$goal = GOAC_UI::goal( 'year' );
		if ( $goal > 0 ) { $cfg['goal'] = array( 'value' => $goal, 'label' => 'Meta do ano' ); }
		GOAC_UI::card_open( 'Acumulado do ano' );
		GOAC_UI::chart( $cfg, 260 );
		GOAC_UI::card_close();
	}

	private static function methods( array $c ) {
		$t = $c['today']; $y = substr( $t, 0, 4 );
		$actual = GOAC_Stats::column( $c['rows'], 'earnings' );
		$nm = GOAC_Stats::shift_months( GOAC_Stats::month_start( $t ), 1 );
		$ranges = array(
			'Este mês' => array( GOAC_Stats::month_start( $t ), GOAC_Stats::month_end( $t ) ),
			'Próximo mês' => array( $nm, GOAC_Stats::month_end( $nm ) ),
			'Este trimestre' => array( GOAC_Stats::quarter_start( $t ), GOAC_Stats::quarter_end( $t ) ),
			'Ano de ' . $y => array( $y . '-01-01', $y . '-12-31' ),
		);
		GOAC_UI::card_open( 'Comparação de métodos', '<span class="goac-muted">o modelo é a previsão oficial; os demais servem de referência</span>' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Período</th><th class="num">Modelo (oficial)</th><th class="num">Faixa 80%</th><th class="num">Ritmo dos últimos 7 dias</th><th class="num">Ritmo dos últimos 30 dias</th><th class="num">Ano anterior × crescimento</th><th class="num">Média dos métodos</th></tr></thead><tbody>';
		foreach ( $ranges as $label => $r ) {
			$p = GOAC_UI::projection( $r[0], $r[1] );
			$alt = GOAC_Stats::alt_methods( $actual, $c['first_day'], $r[0], $r[1], $t, $c['today_est'] );
			$all = array_filter( array( $p['projected'], $alt['pace7'], $alt['pace30'], $alt['last_year'] ), 'is_numeric' );
			echo '<tr><th scope="row" class="goac-nowrap">' . esc_html( $label ) . '<br><small class="goac-muted">' . esc_html( GOAC_UI::date( $r[0], 'd/m' ) . ' a ' . GOAC_UI::date( $r[1] ) ) . '</small></th>';
			echo '<td class="num"><strong>' . esc_html( GOAC_UI::money( $p['projected'] ) ) . '</strong></td><td class="num">' . esc_html( GOAC_UI::money( $p['low'], 0 ) . ' – ' . GOAC_UI::money( $p['high'], 0 ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::money( $alt['pace7'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $alt['pace30'] ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::money( $alt['last_year'] ) ) . ( null !== $alt['growth'] ? '<br><small class="goac-muted">crescimento ' . esc_html( GOAC_UI::signed_pct( $alt['growth'] - 1 ) ) . '</small>' : '' ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::money( $all ? array_sum( $all ) / count( $all ) : null ) ) . '</td></tr>';
		}
		echo '</tbody></table></div><p class="goac-footnote">Ritmo: média diária recente repetida nos dias restantes. Ano anterior × crescimento: mesmos dias do ano passado multiplicados pela variação dos últimos 28 dias contra o mesmo trecho do ano anterior (exige 1 ano de histórico).</p>';
		GOAC_UI::card_close();
	}

	private static function daily_table( array $c ) {
		$t = $c['today'];
		$p = GOAC_UI::projection( GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 30 ) );
		$pv = GOAC_UI::projection( GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 30 ), 'page_views' );
		$model = $c['model'];
		GOAC_UI::card_open( 'Próximos 30 dias, dia a dia', '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_export', array( 'source' => 'forecast' ) ) ) . '">Exportar CSV</a>', 'goac-span-8' );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Dia</th><th class="num">Previsão</th><th class="num">Faixa 80%</th><th class="num">Page views prev.</th><th class="num">Semana anterior (real)</th><th class="num">Ano anterior (real)</th><th class="num">Fator do dia da semana</th><th class="num">Fator sazonal</th></tr></thead><tbody>';
		$est = $c['today_est'];
		echo '<tr class="is-partial"><td><strong>' . esc_html( GOAC_UI::weekday( $t ) . ' ' . GOAC_UI::date( $t, 'd/m' ) ) . '</strong> <span class="goac-pill">hoje</span></td><td class="num"><strong>' . esc_html( GOAC_UI::money( $est['projected'] ) ) . '</strong></td><td class="num">' . esc_html( GOAC_UI::money( $est['low'] ) . ' – ' . GOAC_UI::money( $est['high'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $c['today_pv_est']['projected'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $c['rows'][ GOAC_Stats::add_days( $t, -7 ) ]['earnings'] ?? null ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $c['rows'][ GOAC_Stats::shift_years( $t, -1 ) ]['earnings'] ?? null ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $model['S'][ GOAC_Stats::weekday( $t ) ], 2 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( GOAC_Stats::season_factor( $model['season'], GOAC_Stats::day_num( $t ) ), 2 ) ) . '</td></tr>';
		foreach ( $p['daily'] as $d => $f ) {
			$weekend = in_array( GOAC_Stats::weekday( $d ), array( 0, 6 ), true );
			echo '<tr class="' . ( $weekend ? 'is-weekend' : '' ) . '"><td>' . esc_html( GOAC_UI::weekday( $d ) . ' ' . GOAC_UI::date( $d, 'd/m' ) ) . '</td><td class="num"><strong>' . esc_html( GOAC_UI::money( $f['value'] ) ) . '</strong></td><td class="num">' . esc_html( GOAC_UI::money( $f['low'] ) . ' – ' . GOAC_UI::money( $f['high'] ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::number( $pv['daily'][ $d ]['value'] ?? null ) ) . '</td>';
			$wk = GOAC_Stats::add_days( $d, -7 );
			echo '<td class="num">' . esc_html( $wk < $t ? GOAC_UI::money( $c['rows'][ $wk ]['earnings'] ?? null ) : 'prev. ' . GOAC_UI::money( $p['daily'][ $wk ]['value'] ?? ( $wk === $t ? $est['projected'] : null ) ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::money( $c['rows'][ GOAC_Stats::shift_years( $d, -1 ) ]['earnings'] ?? null ) ) . '</td>';
			echo '<td class="num">' . esc_html( GOAC_UI::number( $model['S'][ GOAC_Stats::weekday( $d ) ], 2 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( GOAC_Stats::season_factor( $model['season'], GOAC_Stats::day_num( $d ) ), 2 ) ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function diagnostics( array $c ) {
		$m = $c['model']; $cal = $m['cal']; $profile = $c['profile'];
		$weekly = $m['level'] > 0 ? $m['trend'] * 7 / $m['level'] : 0;
		$pv_m = GOAC_UI::projection( GOAC_Stats::month_start( $c['today'] ), GOAC_Stats::month_end( $c['today'] ), 'page_views' );
		$e_m = GOAC_UI::projection( GOAC_Stats::month_start( $c['today'] ), GOAC_Stats::month_end( $c['today'] ) );
		GOAC_UI::card_open( 'Como o modelo está vendo seus dados', '', 'goac-span-4' );
		echo '<dl class="goac-dl">';
		$row = static function( $label, $value, $hint = '' ) {
			echo '<dt>' . esc_html( $label ) . '</dt><dd>' . esc_html( $value ) . ( $hint ? '<small>' . esc_html( $hint ) . '</small>' : '' ) . '</dd>';
		};
		$row( 'Histórico usado', GOAC_UI::number( $m['n'] ) . ' dias', 'desde ' . GOAC_UI::date( $c['first_day'] ) );
		$row( 'Nível atual', GOAC_UI::money( $m['level'] * (float) ( $m['adjust'] ?? 1 ) ) . '/dia', 'receita típica de um dia médio, sem efeito de dia da semana' );
		$row( 'Tendência recente', GOAC_UI::signed_pct( $weekly ) . ' por semana', 'amortecida: perde força nos dias seguintes' );
		$row( 'Correção de viés', GOAC_UI::signed_pct( (float) ( $m['adjust'] ?? 1 ) - 1 ), 'compensa picos que o nível ignora' );
		$row( 'Sazonalidade anual', ! empty( $m['season']['ok'] ) ? 'ativa (' . (int) $m['season']['years'] . ( 1 === (int) $m['season']['years'] ? ' ano' : ' anos' ) . ' de referência)' : 'inativa', ! empty( $m['season']['ok'] ) ? 'fim de ano e meses fracos entram na conta' : 'ativa com 13 meses de histórico' );
		$row( 'Erro típico', '1 dia ±' . GOAC_UI::pct( $cal['s1'], 0 ) . ' · 7 dias ±' . GOAC_UI::pct( $cal['s7'], 0 ) . ' · 28 dias ±' . GOAC_UI::pct( $cal['s28'], 0 ), (int) $cal['origins'] . ' janelas testadas no passado' . ( null !== $m['mape'] ? ' · erro médio diário ' . GOAC_UI::pct( $m['mape'], 0 ) : '' ) );
		$row( 'Page views previstos no mês', GOAC_UI::number( $pv_m['projected'] ), 'faixa ' . GOAC_UI::number( $pv_m['low'] ) . ' – ' . GOAC_UI::number( $pv_m['high'] ) );
		$row( 'Page RPM implícito no mês', GOAC_UI::money( $pv_m['projected'] > 0 ? $e_m['projected'] / $pv_m['projected'] * 1000 : null ), 'receita prevista ÷ page views previstos' );
		$row( 'Curva do dia', 'learned' === $profile['source'] ? 'aprendida com ' . (int) $profile['days'] . ' dias' : 'padrão (aprende em ~5 dias)', 'agora: ' . GOAC_UI::pct( $c['today_est']['fraction'], 0 ) . ' da receita típica do dia já contabilizada' );
		echo '</dl><div class="goac-weekday-factors" aria-label="Fatores por dia da semana">';
		foreach ( array( 1, 2, 3, 4, 5, 6, 0 ) as $w ) {
			$f = (float) $m['S'][ $w ];
			echo '<span title="' . esc_attr( GOAC_UI::WEEKDAYS[ $w ] . ': ' . GOAC_UI::signed_pct( $f - 1 ) ) . '"><b style="height:' . esc_attr( (string) round( min( 100, max( 8, 50 * $f ) ) ) ) . '%"></b><em>' . esc_html( GOAC_UI::WEEKDAYS_SHORT[ $w ] ) . '</em><small>' . esc_html( GOAC_UI::number( $f, 2 ) ) . '</small></span>';
		}
		echo '</div>';
		$curve = array(); $labels = array();
		foreach ( $profile['curve'] as $b => $v ) { $labels[] = sprintf( '%02d:%02d', intdiv( ( $b + 1 ) * 30, 60 ) % 24, ( ( $b + 1 ) * 30 ) % 60 ); $curve[] = round( $v, 4 ); }
		echo '<h3 class="goac-subhead">Receita acumulada ao longo do dia</h3>';
		GOAC_UI::chart( array( 'labels' => $labels, 'labelType' => 'text', 'format' => 'percent', 'yMax' => 1, 'series' => array( array( 'name' => 'Parcela do dia', 'type' => 'line', 'values' => $curve ) ) ), 140 );
		GOAC_UI::card_close();
	}

	private static function methodology() {
		echo '<details class="goac-card goac-details"><summary>Como as previsões são calculadas</summary><div class="goac-prose">';
		echo '<p><strong>Base diária.</strong> O plugin guarda todos os dias do AdSense localmente. O modelo estima o nível atual de receita com uma média exponencial das últimas 8 semanas (dias recentes pesam mais) e remove o efeito de cada dia da semana, medido pela razão entre cada dia e a média móvel centrada, com mediana para ignorar picos.</p>';
		echo '<p><strong>Tendência.</strong> A inclinação das últimas 4 semanas é calculada pelo método de Theil–Sen (resistente a picos virais) e amortecida: vale inteira amanhã e perde força a cada dia, com efeito máximo de ±30% do nível.</p>';
		echo '<p><strong>Sazonalidade anual.</strong> Com mais de 13 meses de histórico, cada data futura recebe a razão entre a receita daquela época no ano anterior (janela de 31 dias) e as mesmas 4 semanas recentes um ano antes, com encolhimento para evitar exageros. É isso que antecipa, por exemplo, o aumento de fim de ano e a queda de janeiro.</p>';
		echo '<p><strong>Hoje até 23:59.</strong> Combina o ritmo do dia (receita parcial dividida pela parcela típica já contabilizada naquele horário, uma curva que o plugin aprende gravando instantâneos durante o dia) com a previsão do modelo. O peso de cada um depende da incerteza: de madrugada vale mais o modelo; à noite, o ritmo.</p>';
		echo '<p><strong>Faixas.</strong> O modelo é testado no seu próprio passado: previsões de 1, 7 e 28 dias feitas em datas antigas são comparadas com o que realmente aconteceu. A dispersão desses erros define as faixas de 80% e cresce com o horizonte. Uma correção de viés compensa desvios sistemáticos observados nesses testes.</p>';
		echo '<p><strong>Limites.</strong> Receita do AdSense é estimada e pode ser ajustada no fechamento do mês. Mudanças bruscas (atualizações do Google, viralização, perda de tráfego) não são previsíveis; a faixa se alarga automaticamente quando o histórico recente é instável.</p>';
		echo '</div></details>';
	}

	public static function export() {
		$c = GOAC_UI::context(); $t = $c['today'];
		$p = GOAC_UI::projection( GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 90 ) );
		$pv = GOAC_UI::projection( GOAC_Stats::add_days( $t, 1 ), GOAC_Stats::add_days( $t, 90 ), 'page_views' );
		$rows = array( array( $t, GOAC_UI::weekday( $t, false ), 'hoje (até 23:59)', (float) $c['today_est']['projected'], (float) $c['today_est']['low'], (float) $c['today_est']['high'], (float) round( $c['today_pv_est']['projected'] ) ) );
		foreach ( $p['daily'] as $d => $f ) { $rows[] = array( $d, GOAC_UI::weekday( $d, false ), 'previsão', (float) $f['value'], (float) $f['low'], (float) $f['high'], (float) round( $pv['daily'][ $d ]['value'] ?? 0 ) ); }
		$cur = GOAC_UI::currency_code();
		GOAC_UI::send_csv( 'adsense-previsao-90-dias-' . strtolower( $cur ) . '.csv', array( 'Data', 'Dia da semana', 'Tipo', 'Receita prevista (' . $cur . ')', 'Faixa inferior P10 (' . $cur . ')', 'Faixa superior P90 (' . $cur . ')', 'Page views previstos' ), $rows );
	}
}
