<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Aba Pagamentos. */
final class GOAC_View_Payments {

	public static function data() {
		$payments = GOAC_API::payments();
		if ( is_wp_error( $payments ) ) { return $payments; }
		$unpaid = array(); $paid = array();
		foreach ( $payments as $p ) {
			$name = (string) ( $p['name'] ?? '' );
			$date = (array) ( $p['date'] ?? array() );
			$item = array( 'amount' => GOAC_API::parse_amount( $p['amount'] ?? '' ), 'text' => (string) ( $p['amount'] ?? '' ), 'youtube' => false !== strpos( $name, 'youtube' ) );
			if ( ! empty( $date['year'] ) && ! empty( $date['month'] ) && ! empty( $date['day'] ) ) {
				$paid[] = $item + array( 'date' => sprintf( '%04d-%02d-%02d', $date['year'], $date['month'], $date['day'] ) );
			} else {
				$unpaid[] = $item;
			}
		}
		usort( $paid, static function( $a, $b ) { return strcmp( $b['date'], $a['date'] ); } );
		return array( 'unpaid' => $unpaid, 'paid' => $paid );
	}

	public static function render() {
		$data = self::data();
		if ( is_wp_error( $data ) ) { GOAC_UI::notice( 'error', '<strong>Não foi possível consultar pagamentos:</strong> ' . esc_html( $data->get_error_message() ) ); return; }
		$c = GOAC_UI::context();
		$today = $c['today']; $year = substr( $today, 0, 4 );
		$paid = array_values( array_filter( $data['paid'], static function( $p ) { return ! $p['youtube']; } ) );
		$unpaid = array_values( array_filter( $data['unpaid'], static function( $p ) { return ! $p['youtube']; } ) );
		// Pagamentos vêm só na moeda da conta; em outra moeda, converte pela taxa do Google mais próxima da data (aproximado).
		$converting = $c['currency'] !== $c['account_currency'] && $c['account_currency'];
		$rate = static function( $date ) use ( $c, $converting ) {
			if ( ! $converting ) { return 1.0; }
			$d = min( $date, $c['today'] );
			$rates = GOAC_Store::rates( $c['currency'], $d, $d );
			return isset( $rates[ $d ] ) && is_numeric( $rates[ $d ] ) ? (float) $rates[ $d ] : null;
		};
		$conv = static function( $amount, $date ) use ( $rate ) { $r = $rate( $date ); return null === $amount || null === $r ? null : (float) $amount * $r; };
		$show = static function( $value ) use ( $converting ) { return ( $converting ? '≈ ' : '' ) . GOAC_UI::money( $value ); };
		$sum = static function( array $list ) use ( $conv ) { $s = 0.0; foreach ( $list as $p ) { $s += (float) $conv( $p['amount'], $p['date'] ?? GOAC_API::today() ); } return $s; };
		$this_year = array_filter( $paid, static function( $p ) use ( $year ) { return 0 === strpos( $p['date'], $year ); } );
		$last12 = array_filter( $paid, static function( $p ) use ( $today ) { return $p['date'] > GOAC_Stats::add_days( $today, -365 ); } );
		$recent = array_slice( $paid, 0, 12 );
		$unpaid_text = $unpaid ? implode( ' + ', array_column( $unpaid, 'text' ) ) : GOAC_UI::money( 0, 2, $c['account_currency'] );
		$unpaid_value = 0.0; foreach ( $unpaid as $p ) { $unpaid_value += (float) $conv( $p['amount'], $today ); }
		$note = $converting ? esc_html( 'Pagamentos são feitos em ' . $c['account_currency'] . '; valores em ' . $c['currency'] . ' convertidos pela taxa do Google na data (aproximados).' ) : '';

		if ( $converting ) { GOAC_UI::notice( 'info', $note ); }
		echo '<div class="goac-kpis goac-kpis-summary">';
		GOAC_UI::kpi( 'Saldo atual (não pago)', $unpaid_text, esc_html( ( $converting ? '≈ ' . GOAC_UI::money( $unpaid_value ) . ' · ' : '' ) . 'ganhos finalizados que ainda não foram pagos' ), array( 'class' => 'is-hero is-accent' ) );
		if ( $paid ) { GOAC_UI::kpi( 'Último pagamento', $paid[0]['text'], esc_html( GOAC_UI::date( $paid[0]['date'] ) . ( $converting ? ' · ≈ ' . GOAC_UI::money( $conv( $paid[0]['amount'], $paid[0]['date'] ) ) : '' ) ), array( 'class' => 'is-hero' ) ); }
		GOAC_UI::kpi( 'Recebido em ' . $year, $show( $sum( $this_year ) ), esc_html( count( $this_year ) . ' pagamentos' ), array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'Últimos 12 meses', $show( $sum( $last12 ) ), esc_html( count( $last12 ) . ' pagamentos' ) );
		GOAC_UI::kpi( 'Total recebido', $show( $sum( $paid ) ), esc_html( count( $paid ) . ' pagamentos no histórico da API' ) );
		GOAC_UI::kpi( 'Média por pagamento', $recent ? $show( $sum( $recent ) / count( $recent ) ) : '—', esc_html( 'últimos ' . count( $recent ) ) );
		$month_p = GOAC_UI::projection( GOAC_Stats::month_start( $today ), GOAC_Stats::month_end( $today ) );
		$day = (int) substr( $today, 8, 2 );
		$next_month = GOAC_Stats::shift_months( GOAC_Stats::month_start( $today ), 1 );
		if ( $day <= 26 && ( ! $paid || substr( $paid[0]['date'], 0, 7 ) !== substr( $today, 0, 7 ) ) ) {
			GOAC_UI::kpi( 'Próximo pagamento (estimativa)', $unpaid_text, esc_html( 'Janela usual: 21 a 26/' . substr( $today, 5, 2 ) . ', se o saldo atingir o limite de pagamento' ) );
		} else {
			GOAC_UI::kpi( 'Próximo pagamento (estimativa)', GOAC_UI::money( $month_p['projected'] ), esc_html( 'Receita prevista de ' . GOAC_UI::MONTHS[ (int) substr( $today, 5, 2 ) ] . ' · janela usual 21 a 26/' . substr( $next_month, 5, 2 ) ) );
		}
		GOAC_UI::kpi( 'Receita estimada deste mês', GOAC_UI::money( GOAC_Stats::sum( GOAC_UI::rows( GOAC_Stats::month_start( $today ), $today ) )['earnings'] ), esc_html( 'previsão ' . GOAC_UI::money( $month_p['projected'] ) . ' · entra no pagamento do mês seguinte' ) );
		echo '</div>';

		if ( ! $paid ) { GOAC_UI::card_open( 'Pagamentos' ); GOAC_UI::empty_state( 'A API não retornou pagamentos realizados.' ); GOAC_UI::card_close(); return; }

		$chart_items = array_reverse( array_slice( $paid, 0, 24 ) );
		echo '<div class="goac-grid goac-grid-8-4">';
		GOAC_UI::card_open( 'Pagamentos recebidos', '<span class="goac-muted">últimos ' . count( $chart_items ) . ( $converting ? ' · em ' . esc_html( $c['currency'] ) . ' (aprox.)' : '' ) . '</span>', 'goac-span-8' );
		GOAC_UI::chart( array( 'labels' => array_column( $chart_items, 'date' ), 'labelType' => 'date', 'format' => 'money', 'series' => array( array( 'name' => 'Pagamento', 'type' => 'bar', 'values' => array_map( static function( $p ) use ( $conv ) { $v = $conv( $p['amount'], $p['date'] ); return null === $v ? null : round( $v, 2 ); }, $chart_items ) ) ) ), 240 );
		GOAC_UI::card_close();
		$years = array();
		foreach ( $paid as $p ) { $years[ substr( $p['date'], 0, 4 ) ][] = $p; }
		GOAC_UI::card_open( 'Por ano', '', 'goac-span-4' );
		echo '<table class="widefat goac-table goac-table-compact"><thead><tr><th>Ano</th><th class="num">Pagamentos</th><th class="num">Total</th><th class="num">Média</th><th class="num">vs. ano ant.</th></tr></thead><tbody>';
		foreach ( $years as $y => $list ) {
			$total = $sum( $list ); $prev = isset( $years[ (string) ( (int) $y - 1 ) ] ) ? $sum( $years[ (string) ( (int) $y - 1 ) ] ) : null;
			echo '<tr><th scope="row">' . esc_html( (string) $y ) . '</th><td class="num">' . count( $list ) . '</td><td class="num"><strong>' . esc_html( $show( $total ) ) . '</strong></td><td class="num">' . esc_html( $show( $total / count( $list ) ) ) . '</td><td class="num">' . GOAC_UI::delta( (string) $y === $year ? null : GOAC_Stats::delta( $total, $prev ) ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tbody></table>';
		GOAC_UI::card_close();
		echo '</div>';

		GOAC_UI::card_open( 'Histórico de pagamentos', '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_export', array( 'source' => 'payments' ) ) ) . '">Exportar CSV</a>' );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable"><thead><tr><th data-sort-type="text" tabindex="0">Data do pagamento</th><th class="num" data-sort-type="num" tabindex="0">Valor</th>' . ( $converting ? '<th class="num" data-sort-type="num" tabindex="0">≈ ' . esc_html( $c['currency'] ) . '</th>' : '' ) . '<th class="num" data-sort-type="num" tabindex="0">vs. anterior</th><th data-sort-type="text" tabindex="0">Mês de referência</th><th class="num" data-sort-type="num" tabindex="0">Receita estimada do mês</th><th class="num" data-sort-type="num" tabindex="0">Pago vs. estimado</th></tr></thead><tbody>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		foreach ( $paid as $i => $p ) {
			$prev = $paid[ $i + 1 ] ?? null;
			$ref = GOAC_Stats::shift_months( GOAC_Stats::month_start( $p['date'] ), -1 );
			$est_account = null; $est_shown = null;
			if ( $c['first_day'] && $ref >= GOAC_Stats::month_start( $c['first_day'] ) && GOAC_Stats::month_end( $ref ) < $today ) {
				$est_account = GOAC_Stats::sum( GOAC_Stats::slice( $c['account_rows'], $ref, GOAC_Stats::month_end( $ref ) ) )['earnings'];
				$est_shown = GOAC_Stats::sum( GOAC_UI::rows( $ref, GOAC_Stats::month_end( $ref ) ) )['earnings'];
			}
			$d_prev = $prev ? GOAC_Stats::delta( $p['amount'], $prev['amount'] ) : null;
			$d_est = $est_account ? GOAC_Stats::delta( $p['amount'], $est_account ) : null;
			$converted = $conv( $p['amount'], $p['date'] );
			echo '<tr><td data-sort="' . esc_attr( $p['date'] ) . '">' . esc_html( GOAC_UI::weekday( $p['date'] ) . ', ' . GOAC_UI::date( $p['date'] ) ) . '</td><td class="num" data-sort="' . esc_attr( (string) $p['amount'] ) . '"><strong>' . esc_html( $p['text'] ) . '</strong></td>';
			if ( $converting ) { echo '<td class="num" data-sort="' . esc_attr( null === $converted ? '' : (string) $converted ) . '">' . esc_html( GOAC_UI::money( $converted ) ) . '</td>'; }
			echo '<td class="num" data-sort="' . esc_attr( null === $d_prev ? '' : (string) $d_prev ) . '">' . GOAC_UI::delta( $d_prev ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td data-sort="' . esc_attr( $ref ) . '">' . esc_html( GOAC_UI::month_label( substr( $ref, 0, 7 ), true ) ) . '</td><td class="num" data-sort="' . esc_attr( null === $est_shown ? '' : (string) $est_shown ) . '">' . esc_html( GOAC_UI::money( $est_shown ) ) . '</td>';
			echo '<td class="num" data-sort="' . esc_attr( null === $d_est ? '' : (string) $d_est ) . '" title="Comparado na moeda da conta. Diferenças costumam vir de ajustes de fechamento, tráfego inválido ou saldo acumulado de meses abaixo do limite.">' . ( null === $d_est ? '—' : GOAC_UI::delta( $d_est ) ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tbody></table></div><p class="goac-footnote">Datas de pagamento no fuso de cobrança do Google (America/Los_Angeles). A comparação assume que cada pagamento corresponde ao mês anterior; quando o saldo acumula meses abaixo do limite, a diferença é esperada.</p>';
		GOAC_UI::card_close();
	}

	public static function export() {
		$data = self::data();
		if ( is_wp_error( $data ) ) { wp_die( esc_html( $data->get_error_message() ) ); }
		$rows = array();
		foreach ( $data['paid'] as $p ) { $rows[] = array( $p['date'], $p['youtube'] ? 'YouTube' : 'AdSense', $p['text'], null === $p['amount'] ? null : (float) $p['amount'] ); }
		foreach ( $data['unpaid'] as $p ) { $rows[] = array( 'não pago', $p['youtube'] ? 'YouTube' : 'AdSense', $p['text'], null === $p['amount'] ? null : (float) $p['amount'] ); }
		GOAC_UI::send_csv( 'adsense-pagamentos.csv', array( 'Data', 'Origem', 'Valor (texto do Google)', 'Valor' ), $rows );
	}
}

/** Aba Sites & políticas. */
final class GOAC_View_Sites {

	public static function render() {
		$sites = GOAC_API::sites(); $issues = GOAC_API::policy_issues(); $alerts = GOAC_API::alerts();
		$today = GOAC_API::today();
		$perf = GOAC_API::breakdown( array( 'OWNED_SITE_DOMAIN_NAME' ), GOAC_Stats::add_days( $today, -30 ), GOAC_Stats::add_days( $today, -1 ), array( 'limit' => 1000, 'currency' => GOAC_UI::api_currency() ) );
		$by_domain = array(); $total = 0.0;
		if ( ! is_wp_error( $perf ) ) {
			foreach ( $perf['rows'] as $row ) { $by_domain[ strtolower( $row['dims'][0] ) ] = $row; }
			$total = max( 1e-9, (float) $perf['totals']['earnings'] );
		}
		GOAC_UI::card_open( 'Sites', '<span class="goac-muted">' . esc_html( self::count( $sites ) ) . ' · receita dos últimos 30 dias completos</span>' );
		if ( is_wp_error( $sites ) ) { echo '<p>' . esc_html( $sites->get_error_message() ) . '</p>'; }
		else {
			echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-sortable"><thead><tr><th data-sort-type="text" tabindex="0">Domínio</th><th data-sort-type="text" tabindex="0">Status</th><th data-sort-type="text" tabindex="0">Auto Ads</th><th class="num" data-sort-type="num" tabindex="0">Receita 30d</th><th class="num" data-sort-type="num" tabindex="0">%</th><th class="num" data-sort-type="num" tabindex="0">Page views 30d</th><th class="num" data-sort-type="num" tabindex="0">Page RPM</th><th class="num" data-sort-type="num" tabindex="0">Cobertura</th></tr></thead><tbody>';
			$states = array( 'READY' => array( 'ok', 'Pronto' ), 'NEEDS_ATTENTION' => array( 'warn', 'Precisa de atenção' ), 'REQUIRES_REVIEW' => array( 'warn', 'Requer revisão' ), 'GETTING_READY' => array( '', 'Em preparação' ) );
			foreach ( $sites as $s ) {
				$domain = (string) ( $s['domain'] ?? '—' ); $row = $by_domain[ strtolower( $domain ) ] ?? null;
				$state = (string) ( $s['state'] ?? '' ); $st = $states[ $state ] ?? array( '', $state ?: '—' );
				echo '<tr><td><strong>' . esc_html( $domain ) . '</strong></td><td><span class="goac-pill ' . esc_attr( $st[0] ) . '">' . ( 'warn' === $st[0] ? '<span aria-hidden="true">! </span>' : '' ) . esc_html( $st[1] ) . '</span></td><td>' . ( ! empty( $s['autoAdsEnabled'] ) ? '<span class="goac-pill ok">Ativo</span>' : '<span class="goac-pill">Desligado</span>' ) . '</td>';
				echo '<td class="num" data-sort="' . esc_attr( $row ? (string) $row['earnings'] : '0' ) . '">' . esc_html( $row ? GOAC_UI::money( $row['earnings'] ) : '—' ) . '</td><td class="num" data-sort="' . esc_attr( $row ? (string) ( $row['earnings'] / $total ) : '0' ) . '">' . esc_html( $row ? GOAC_UI::pct( $row['earnings'] / $total ) : '—' ) . '</td>';
				echo '<td class="num" data-sort="' . esc_attr( $row ? (string) $row['page_views'] : '0' ) . '">' . esc_html( $row ? GOAC_UI::number( $row['page_views'] ) : '—' ) . '</td><td class="num">' . esc_html( $row ? GOAC_UI::money( $row['page_rpm'] ) : '—' ) . '</td><td class="num">' . esc_html( $row ? GOAC_UI::pct( $row['coverage'] ) : '—' ) . '</td></tr>';
			}
			echo '</tbody></table></div>';
		}
		GOAC_UI::card_close();
		echo '<div class="goac-grid goac-grid-2">';
		GOAC_UI::card_open( 'Políticas', '<span class="goac-muted">' . esc_html( self::count( $issues ) ) . '</span>' );
		self::policy_items( $issues );
		GOAC_UI::card_close();
		GOAC_UI::card_open( 'Alertas da conta', '<span class="goac-muted">' . esc_html( self::count( $alerts ) ) . '</span>' );
		self::alerts( $alerts );
		GOAC_UI::card_close();
		echo '</div>';
	}

	private static function count( $items ) { return is_array( $items ) ? (string) count( $items ) : 'Indisponível'; }

	private static function alerts( $alerts ) {
		if ( is_wp_error( $alerts ) ) { echo '<p>' . esc_html( $alerts->get_error_message() ) . '</p>'; return; }
		if ( ! $alerts ) { GOAC_UI::empty_state( 'Nenhum alerta.' ); return; }
		$sev = array( 'SEVERE' => array( 'bad', '!!', 'Grave' ), 'WARNING' => array( 'warn', '!', 'Aviso' ), 'INFO' => array( '', 'i', 'Informação' ) );
		echo '<ul class="goac-alerts">';
		foreach ( $alerts as $a ) {
			$s = $sev[ (string) ( $a['severity'] ?? '' ) ] ?? array( '', 'i', 'Alerta' );
			echo '<li><span class="goac-pill ' . esc_attr( $s[0] ) . '"><span aria-hidden="true">' . esc_html( $s[1] ) . ' </span>' . esc_html( $s[2] ) . '</span> ' . esc_html( (string) ( $a['message'] ?? $a['type'] ?? 'Alerta sem mensagem' ) ) . '<details><summary>Dados da API</summary><pre>' . esc_html( wp_json_encode( $a, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) ) . '</pre></details></li>';
		}
		echo '</ul>';
	}

	private static function policy_items( $items ) {
		if ( is_wp_error( $items ) ) { echo '<p>' . esc_html( $items->get_error_message() ) . '</p>'; return; }
		if ( ! $items ) { GOAC_UI::empty_state( 'Nenhum problema de política retornado pela API.' ); return; }
		$actions = array(
			'WARNED' => 'Aviso: restrição prevista se o problema não for resolvido',
			'AD_SERVING_RESTRICTED' => 'Demanda de anúncios restrita',
			'AD_SERVING_DISABLED' => 'Veiculação de anúncios desativada',
			'AD_SERVED_WITH_CLICK_CONFIRMATION' => 'Confirmed Click aplicado aos anúncios',
			'AD_PERSONALIZATION_RESTRICTED' => 'Personalização de anúncios restrita',
		);
		$types = array( 'POLICY' => 'Política', 'ADVERTISER_PREFERENCE' => 'Preferência de anunciante', 'REGULATORY' => 'Requisito regulatório' );
		echo '<div class="goac-generic">';
		foreach ( $items as $item ) {
			$entity = $item['uri'] ?? $item['siteSection'] ?? $item['site'] ?? $item['name'] ?? 'Entidade não informada';
			$action = (string) ( $item['action'] ?? '' );
			echo '<section class="goac-policy"><h3>' . esc_html( $entity ) . '</h3><p><strong>' . esc_html( $actions[ $action ] ?? ( $action ?: 'Ação não informada' ) ) . '</strong></p>';
			foreach ( (array) ( $item['policyTopics'] ?? array() ) as $topic ) {
				$type = (string) ( $topic['type'] ?? '' );
				echo '<p>' . esc_html( $topic['topic'] ?? 'Tópico não informado' );
				if ( $type ) { echo ' · ' . esc_html( $types[ $type ] ?? $type ); }
				echo '</p>';
			}
			if ( isset( $item['adRequestCount'] ) ) { echo '<p>Solicitações afetadas nos últimos 7 dias: ' . esc_html( $item['adRequestCount'] ) . '.</p>'; }
			foreach ( array( 'firstDetectedDate' => 'Primeira detecção', 'lastDetectedDate' => 'Última detecção', 'warningEscalationDate' => 'Restrição prevista' ) as $key => $label ) {
				$date = (array) ( $item[ $key ] ?? array() );
				if ( ! empty( $date['year'] ) && ! empty( $date['month'] ) && ! empty( $date['day'] ) ) {
					echo '<p>' . esc_html( $label . ': ' . sprintf( '%02d/%02d/%04d', $date['day'], $date['month'], $date['year'] ) ) . ' (America/Los_Angeles).</p>';
				}
			}
			echo '<details><summary>Dados completos da API</summary><pre>' . esc_html( wp_json_encode( $item, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) ) . '</pre></details></section>';
		}
		echo '</div>';
	}
}

/** Aba Unidades: inventário com desempenho de cada unidade. */
final class GOAC_View_Units {

	public static function render() {
		$units = GOAC_API::units();
		if ( is_wp_error( $units ) ) { GOAC_UI::notice( 'error', esc_html( $units->get_error_message() ) ); return; }
		$days = isset( $_GET['days'] ) ? (int) $_GET['days'] : 30; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! in_array( $days, array( 7, 30, 90 ), true ) ) { $days = 30; }
		$today = GOAC_API::today();
		$perf = GOAC_API::breakdown( array( 'AD_UNIT_ID', 'AD_UNIT_NAME' ), GOAC_Stats::add_days( $today, -$days ), GOAC_Stats::add_days( $today, -1 ), array( 'limit' => 5000, 'currency' => GOAC_UI::api_currency() ) );
		$by_id = array(); $total = 1e-9;
		if ( ! is_wp_error( $perf ) ) {
			foreach ( $perf['rows'] as $row ) { $by_id[ $row['dims'][0] ] = $row; }
			$total = max( 1e-9, (float) $perf['totals']['earnings'] );
		}
		$chips = '';
		foreach ( array( 7, 30, 90 ) as $n ) { $chips .= '<a class="goac-chip ' . ( $n === $days ? 'is-active' : '' ) . '" href="' . esc_url( GOAC_UI::url( 'units', array( 'days' => $n ) ) ) . '">' . (int) $n . ' dias</a>'; }
		GOAC_UI::card_open( 'Unidades de anúncio', '<div class="goac-chips">' . $chips . '</div>' );
		echo '<p class="goac-muted">Inventário salvo no AdSense com o desempenho dos últimos ' . (int) $days . ' dias completos. A leitura funciona em contas comuns; criação/edição pela API é restrita pelo Google a projetos específicos.</p>';
		if ( is_wp_error( $perf ) ) { GOAC_UI::notice( 'warning', 'Desempenho indisponível: ' . esc_html( $perf->get_error_message() ) ); }
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-sortable goac-sticky"><thead><tr>';
		foreach ( array( array( 'Nome', 'text' ), array( 'Status', 'text' ), array( 'Tipo', 'text' ), array( 'Tamanho', 'text' ), array( 'Receita', 'num' ), array( '% da receita', 'num' ), array( 'Impressões', 'num' ), array( 'Cliques', 'num' ), array( 'CTR', 'num' ), array( 'RPM impr.', 'num' ), array( 'Cobertura', 'num' ), array( 'Active View', 'num' ), array( 'ID de relatório', 'text' ) ) as $h ) {
			echo '<th scope="col" data-sort-type="' . esc_attr( $h[1] ) . '" class="' . ( 'num' === $h[1] ? 'num' : '' ) . '" tabindex="0">' . esc_html( $h[0] ) . '</th>';
		}
		echo '</tr></thead><tbody>';
		$seen = array();
		$print = static function( $name, $state, $type, $size, $id, $row ) use ( $total ) {
			$v = static function( $k ) use ( $row ) { return $row ? $row[ $k ] : null; };
			echo '<tr><td><strong>' . esc_html( $name ) . '</strong></td><td>' . esc_html( $state ) . '</td><td>' . esc_html( $type ) . '</td><td>' . esc_html( $size ) . '</td>';
			echo '<td class="num" data-sort="' . esc_attr( (string) ( $v( 'earnings' ) ?? 0 ) ) . '">' . esc_html( GOAC_UI::money( $v( 'earnings' ) ) ) . '</td>';
			echo '<td class="num goac-cell-bar" data-sort="' . esc_attr( (string) ( $row ? $row['earnings'] / $total : 0 ) ) . '">' . ( $row ? GOAC_UI::bar( $row['earnings'] / $total ) : '' ) . '<span>' . esc_html( $row ? GOAC_UI::pct( $row['earnings'] / $total ) : '—' ) . '</span></td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num" data-sort="' . esc_attr( (string) ( $v( 'impressions' ) ?? 0 ) ) . '">' . esc_html( GOAC_UI::number( $v( 'impressions' ) ) ) . '</td><td class="num" data-sort="' . esc_attr( (string) ( $v( 'clicks' ) ?? 0 ) ) . '">' . esc_html( GOAC_UI::number( $v( 'clicks' ) ) ) . '</td>';
			echo '<td class="num" data-sort="' . esc_attr( (string) ( $v( 'impression_ctr' ) ?? '' ) ) . '">' . esc_html( GOAC_UI::pct( $v( 'impression_ctr' ), 2 ) ) . '</td><td class="num" data-sort="' . esc_attr( (string) ( $v( 'impression_rpm' ) ?? '' ) ) . '">' . esc_html( GOAC_UI::money( $v( 'impression_rpm' ) ) ) . '</td>';
			echo '<td class="num" data-sort="' . esc_attr( (string) ( $v( 'coverage' ) ?? '' ) ) . '">' . esc_html( GOAC_UI::pct( $v( 'coverage' ) ) ) . '</td><td class="num" data-sort="' . esc_attr( (string) ( $v( 'viewability' ) ?? '' ) ) . '">' . esc_html( GOAC_UI::pct( $v( 'viewability' ) ) ) . '</td><td><code>' . esc_html( $id ) . '</code></td></tr>';
		};
		foreach ( $units as $u ) {
			$id = (string) ( $u['reportingDimensionId'] ?? '' ); $seen[ $id ] = true;
			$print( (string) ( $u['displayName'] ?? '—' ), (string) ( $u['state'] ?? '—' ), (string) ( $u['contentAdsSettings']['type'] ?? '—' ), (string) ( $u['contentAdsSettings']['size'] ?? '—' ), $id ?: '—', $by_id[ $id ] ?? null );
		}
		foreach ( $by_id as $id => $row ) {
			if ( isset( $seen[ $id ] ) ) { continue; }
			$print( (string) ( $row['dims'][1] ?: $id ), 'fora do inventário', '—', '—', (string) $id, $row );
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}
}

/** Abas Gestão e Configurações. */
final class GOAC_View_Admin {

	public static function manage() {
		$units = GOAC_API::units(); $channels = GOAC_API::channels(); $full = 'readonly' !== get_option( 'goac_scope_mode', 'full' );
		?>
		<section class="goac-card goac-callout"><h2>O que dá para mudar pela API</h2><p>O escopo completo permite tentar criar/editar <strong>unidades Display</strong> e <strong>canais personalizados</strong>, mas o Google restringe essas operações a projetos habilitados para <strong>AdSense for Platforms</strong>. Auto Ads, densidade, vignette, anchor, exclusões de páginas e demais controles do painel AdSense não têm endpoint público de escrita.</p><div class="goac-actions"><a class="button button-primary" target="_blank" rel="noopener" href="https://adsense.google.com/adsense/">Abrir controles do AdSense</a><a class="button" target="_blank" rel="noopener" href="https://adsense.google.com/">Abrir AdSense</a></div></section>
		<?php
		if ( ! $full ) { GOAC_UI::notice( 'warning', 'Você está conectado em modo somente leitura. Troque o escopo nas Configurações e reconecte para tentar operações de escrita.' ); }
		$display_units = array();
		if ( ! is_wp_error( $units ) ) { foreach ( $units as $u ) { if ( 'DISPLAY' === (string) ( $u['contentAdsSettings']['type'] ?? '' ) ) { $display_units[] = $u; } } }
		if ( $display_units ) : ?>
			<section class="goac-card"><h2>Editar unidade Display</h2><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="goac-form-grid"><?php wp_nonce_field( 'goac_manage_unit' ); ?><input type="hidden" name="action" value="goac_manage_unit"><label>Unidade<select name="name" id="goac-unit-select" required><?php foreach ( $display_units as $u ) { printf( '<option value="%s" data-name="%s" data-state="%s" data-type="%s">%s — %s</option>', esc_attr( $u['name'] ?? '' ), esc_attr( $u['displayName'] ?? '' ), esc_attr( $u['state'] ?? '' ), esc_attr( $u['contentAdsSettings']['type'] ?? '' ), esc_html( $u['displayName'] ?? 'Sem nome' ), esc_html( $u['contentAdsSettings']['type'] ?? '—' ) ); } ?></select></label><label>Novo nome<input type="text" name="display_name" id="goac-unit-name"></label><label>Status<select name="state" id="goac-unit-state"><option value="">Manter</option><option value="ACTIVE">ACTIVE</option><option value="ARCHIVED">ARCHIVED</option></select></label><div class="goac-form-submit"><button class="button button-primary" <?php disabled( ! $full ); ?> data-goac-confirm="Essa ação altera a unidade no Google AdSense. Continuar?">Aplicar no AdSense</button></div></form><p class="goac-muted">A API oficial informa que PATCH atualmente só aceita unidades DISPLAY e somente em projetos autorizados pelo Google.</p></section>
		<?php endif; ?>
		<section class="goac-card"><h2>Criar unidade Display</h2><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="goac-form-grid"><?php wp_nonce_field( 'goac_create_unit' ); ?><input type="hidden" name="action" value="goac_create_unit"><label>Nome<input type="text" name="display_name" required placeholder="Ex.: GO_BODY_06"></label><label>Tamanho<select name="size"><option value="1x3">Responsivo (1x3)</option><option value="300x250">300x250</option><option value="336x280">336x280</option><option value="728x90">728x90</option><option value="970x250">970x250</option></select></label><div class="goac-form-submit"><button class="button button-primary" <?php disabled( ! $full ); ?> data-goac-confirm="Criar uma unidade no Google AdSense?">Criar no AdSense</button></div></form></section>
		<?php if ( ! is_wp_error( $channels ) && $channels ) : ?>
			<section class="goac-card"><h2>Editar canal personalizado</h2><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="goac-form-grid"><?php wp_nonce_field( 'goac_manage_channel' ); ?><input type="hidden" name="action" value="goac_manage_channel"><label>Canal<select name="name" id="goac-channel-select" required><?php foreach ( $channels as $ch ) { printf( '<option value="%s" data-name="%s" data-active="%s">%s</option>', esc_attr( $ch['name'] ?? '' ), esc_attr( $ch['displayName'] ?? '' ), ! empty( $ch['active'] ) ? '1' : '0', esc_html( $ch['displayName'] ?? 'Sem nome' ) ); } ?></select></label><label>Novo nome<input type="text" name="display_name" id="goac-channel-name"></label><label>Status<select name="active" id="goac-channel-active"><option value="keep">Manter</option><option value="1">Ativo</option><option value="0">Inativo</option></select></label><div class="goac-form-submit"><button class="button button-primary" <?php disabled( ! $full ); ?> data-goac-confirm="Essa ação altera o canal no Google AdSense. Continuar?">Aplicar no AdSense</button></div></form></section>
		<?php endif; ?>
		<section class="goac-card"><h2>Criar canal personalizado</h2><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="goac-form-grid"><?php wp_nonce_field( 'goac_create_channel' ); ?><input type="hidden" name="action" value="goac_create_channel"><label>Nome<input type="text" name="display_name" required placeholder="Ex.: Conteúdo editorial"></label><label>Status<select name="active"><option value="1">Ativo</option><option value="0">Inativo</option></select></label><div class="goac-form-submit"><button class="button button-primary" <?php disabled( ! $full ); ?> data-goac-confirm="Criar um canal personalizado no Google AdSense?">Criar no AdSense</button></div></form></section>
		<?php
	}

	public static function settings() {
		$connected = GOAC_API::is_connected();
		$accounts = $connected ? GOAC_API::discover_accounts() : array(); $c = GOAC_API::connection(); $locked = GOAC_API::credentials_locked();
		?>
		<div class="goac-grid goac-grid-2"><section class="goac-card"><h2>Google OAuth</h2><p class="goac-muted">No Google Cloud, ative a <strong>AdSense Management API</strong>, crie um OAuth Client ID do tipo Web e cadastre exatamente este URI de redirecionamento:</p><code class="goac-code"><?php echo esc_html( GOAC_API::redirect_uri() ); ?></code><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="goac-settings-form"><?php wp_nonce_field( 'goac_save_settings' ); ?><input type="hidden" name="action" value="goac_save_settings"><label>Client ID<input type="text" name="client_id" value="<?php echo esc_attr( GOAC_API::client_id() ); ?>" <?php disabled( $locked ); ?>></label><label>Client Secret<input type="password" name="client_secret" placeholder="<?php echo GOAC_API::client_secret() ? '••••••••••••••••' : ''; ?>" <?php disabled( $locked ); ?> autocomplete="new-password"></label><?php if ( $locked ) { echo '<p class="goac-muted">Credenciais bloqueadas por constantes no wp-config.php.</p>'; } ?><label>Permissão<select name="scope_mode"><option value="full" <?php selected( get_option( 'goac_scope_mode', 'full' ), 'full' ); ?>>Leitura + escrita disponível (adsense)</option><option value="readonly" <?php selected( get_option( 'goac_scope_mode', 'full' ), 'readonly' ); ?>>Somente leitura (adsense.readonly)</option></select></label><label>Atualização automática do painel<select name="refresh_minutes"><?php foreach ( array( 1, 5, 10, 15, 30 ) as $m ) { printf( '<option value="%d" %s>A cada %d min</option>', (int) $m, selected( (int) get_option( 'goac_refresh_minutes', 5 ), $m, false ), (int) $m ); } ?></select></label><label>Anos de histórico a importar<select name="history_years"><?php foreach ( array( 2, 3, 5, 10, 20 ) as $y ) { printf( '<option value="%d" %s>Até %d anos</option>', (int) $y, selected( GOAC_Store::max_years(), $y, false ), (int) $y ); } ?></select></label><label>Moeda de exibição<select name="display_currency"><?php foreach ( GOAC_Store::currencies() as $cur ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $cur ), selected( GOAC_Store::display_currency(), $cur, false ), esc_html( ( 'BRL' === $cur ? 'Real (R$)' : ( 'USD' === $cur ? 'Dólar (US$)' : $cur ) ) . ( $cur === GOAC_Store::currency() ? ' · moeda da conta' : ' · convertido pelo Google' ) ) ); } ?></select></label><?php $gm = GOAC_UI::goal_info( 'month' ); $gy = GOAC_UI::goal_info( 'year' ); ?><label>Meta mensal (<?php echo esc_html( GOAC_UI::currency_code() ); ?>)<input type="number" min="0" step="0.01" name="goal_month" value="<?php echo esc_attr( $gm['value'] > 0 && ! $gm['note'] ? (string) round( $gm['value'], 2 ) : '' ); ?>" placeholder="<?php echo esc_attr( $gm['note'] ? GOAC_UI::money( $gm['value'], 0 ) . ' (' . $gm['note'] . ')' : '' ); ?>"></label><label>Meta anual (<?php echo esc_html( GOAC_UI::currency_code() ); ?>)<input type="number" min="0" step="0.01" name="goal_year" value="<?php echo esc_attr( $gy['value'] > 0 && ! $gy['note'] ? (string) round( $gy['value'], 2 ) : '' ); ?>" placeholder="<?php echo esc_attr( $gy['note'] ? GOAC_UI::money( $gy['value'], 0 ) . ' (' . $gy['note'] . ')' : '' ); ?>"></label><button class="button button-primary">Salvar configurações</button></form></section>
		<section class="goac-card"><h2>Conexão</h2><?php if ( $connected ) : ?><div class="goac-account-box"><span>Conta</span><strong><?php echo esc_html( $c['display_name'] ?? $c['account_name'] ); ?></strong><small><?php echo esc_html( $c['publisher_id'] ?? '' ); ?> · <?php echo esc_html( $c['timezone'] ?? '' ); ?></small></div><?php if ( is_array( $accounts ) && count( $accounts ) > 1 ) : ?><form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="goac-inline-form"><?php wp_nonce_field( 'goac_select_account' ); ?><input type="hidden" name="action" value="goac_select_account"><select name="account_name"><?php foreach ( $accounts as $a ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $a['name'] ?? '' ), selected( $c['account_name'] ?? '', $a['name'] ?? '', false ), esc_html( $a['displayName'] ?? $a['name'] ) ); } ?></select><button class="button" data-goac-confirm="Trocar de conta apaga o histórico local da conta atual e importa o da nova. Continuar?">Trocar conta</button></form><?php endif; ?><div class="goac-actions"><a class="button button-secondary" href="<?php echo esc_url( wp_nonce_url( admin_url( 'admin-post.php?action=goac_oauth_start' ), 'goac_oauth_start' ) ); ?>">Reconectar</a><a class="button button-link-delete" href="<?php echo esc_url( wp_nonce_url( admin_url( 'admin-post.php?action=goac_disconnect' ), 'goac_disconnect' ) ); ?>" data-goac-confirm="Desconectar a conta do AdSense deste WordPress?">Desconectar</a></div><?php else : ?><p>Depois de salvar as credenciais, autorize a conta Google que possui acesso ao AdSense.</p><a class="button button-primary button-hero" href="<?php echo esc_url( wp_nonce_url( admin_url( 'admin-post.php?action=goac_oauth_start' ), 'goac_oauth_start' ) ); ?>">Conectar com Google</a><?php endif; ?>
		<?php self::history_box(); ?></section></div>
		<section class="goac-card"><h2>Segurança recomendada</h2><p>Em produção, prefira guardar as credenciais no <code>wp-config.php</code>, em vez do banco:</p><pre>define( 'GOAC_GOOGLE_CLIENT_ID', 'SEU_CLIENT_ID' );
define( 'GOAC_GOOGLE_CLIENT_SECRET', 'SEU_CLIENT_SECRET' );</pre><p class="goac-muted">O refresh token continua armazenado no banco do WordPress com autoload desativado. Restrinja acesso de administrador e mantenha backups protegidos.</p></section>
		<?php
	}

	private static function history_box() {
		$meta = GOAC_Store::meta(); $b = GOAC_Store::backfill_status(); $tz = GOAC_API::tz();
		$states = array( 'idle' => 'Não iniciada', 'running' => 'Importando', 'done' => 'Concluída', 'error' => 'Erro' );
		echo '<h3 class="goac-subhead">Histórico local</h3><div class="goac-health">';
		$cells = array(
			'Primeiro dia' => $meta['first_day'] ? GOAC_UI::date( $meta['first_day'] ) : '—',
			'Último dia' => $meta['last_day'] ? GOAC_UI::date( $meta['last_day'] ) : '—',
			'Dias guardados' => GOAC_UI::number( GOAC_Store::row_count() ),
			'Anos' => $meta['years'] ? implode( ', ', array_map( 'intval', (array) $meta['years'] ) ) : '—',
			'Última sincronização' => $meta['synced_at'] ? wp_date( 'd/m/Y H:i:s', (int) $meta['synced_at'], $tz ) : '—',
			'Importação completa' => ( $states[ $b['state'] ] ?? $b['state'] ) . ( $b['finished_at'] ? ' em ' . wp_date( 'd/m/Y H:i', (int) $b['finished_at'], $tz ) : '' ),
			'Moeda da conta' => $meta['currency'] ?: '—',
		);
		foreach ( GOAC_Store::currencies() as $cur ) {
			if ( $cur === $meta['currency'] || empty( $meta['fx_years'][ $cur ] ) ) { continue; }
			$missing = GOAC_Store::fx_missing_years( $cur );
			$rate = $meta['fx_rate'][ $cur ] ?? null;
			$cells[ 'Conversão para ' . $cur ] = ( $missing ? 'faltam ' . count( $missing ) . ' ano(s)' : 'histórico completo' ) . ( is_numeric( $rate ) && $rate > 0 ? ' · 1 ' . $cur . ' = ' . GOAC_UI::money( 1 / $rate, 2, $meta['currency'] ) : '' );
		}
		foreach ( $cells as $label => $value ) { echo '<div><span>' . esc_html( $label ) . '</span><strong>' . esc_html( $value ) . '</strong></div>'; }
		echo '</div>';
		if ( $meta['last_error'] ) { echo '<p class="goac-live-error">Último erro de sincronização: ' . esc_html( $meta['last_error'] ) . '</p>'; }
		if ( 'error' === $b['state'] && $b['error'] ) { echo '<p class="goac-live-error">Erro na importação: ' . esc_html( $b['error'] ) . '</p>'; }
		if ( $b['note'] ) { echo '<p class="goac-muted">' . esc_html( $b['note'] ) . '</p>'; }
		if ( 'running' === $b['state'] ) {
			echo '<div class="goac-backfill" data-goac-backfill="1"><div class="goac-meter"><i style="width:' . esc_attr( (string) round( 100 * GOAC_Store::backfill_progress( $b ) ) ) . '%"></i></div><p data-goac-backfill-text>Importando…</p></div>';
		}
		if ( GOAC_API::is_connected() ) {
			echo '<div class="goac-actions">';
			echo '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_backfill', array( 'mode' => 'start' ) ) ) . '">' . ( 'done' === $b['state'] ? 'Reimportar histórico' : 'Importar histórico' ) . '</a>';
			echo '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_backfill', array( 'mode' => 'rebuild' ) ) ) . '" data-goac-confirm="Apagar o histórico local e importar tudo de novo a partir da API?">Reconstruir do zero</a>';
			echo '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_flush_cache' ) ) . '">Limpar cache de relatórios</a>';
			echo '</div>';
		}
		echo '<p class="goac-footnote">Cada ano fica numa opção própria do WordPress (sem autoload). A sincronização regrava o mês anterior e o atual a cada atualização para acompanhar os ajustes do Google.</p>';
	}
}
