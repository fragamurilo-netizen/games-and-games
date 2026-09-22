<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Consulta interna de distribuição da receita e rentabilidade editorial.
 *
 * A divisão 40/40/20 é apenas matemática sobre a receita estimada exibida no
 * AdSense Center; não registra pagamentos nem altera dados da conta.
 *
 * O ranking editorial usa a dimensão PAGE_URL da API do AdSense. Para evitar
 * dupla contagem em posts com várias categorias, cada matéria é atribuída a
 * uma única categoria principal (Yoast/Rank Math quando disponível; caso
 * contrário, a categoria mais específica do post).
 */
final class GOAC_View_Distribution {
	const PARTNERS = array(
		'Murilo'  => 0.40,
		'Gregory' => 0.40,
		'Deco'    => 0.20,
	);

	const PERIODS = array(
		'day'   => 'Dia',
		'week'  => 'Semana',
		'month' => 'Mês',
	);

	public static function render() {
		$c = GOAC_UI::context();
		if ( ! GOAC_Store::has_data() ) {
			GOAC_UI::empty_state( 'Ainda não há histórico suficiente para montar a distribuição.' );
			return;
		}

		$params = self::params( $c );
		self::split_section( $params['split_month'], $c );
		self::content_section( $params['period'], $params['ref'], $c );
	}

	private static function params( array $c ) {
		$today = (string) $c['today'];
		$period = isset( $_GET['period'] ) ? sanitize_key( wp_unslash( $_GET['period'] ) ) : 'month'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! isset( self::PERIODS[ $period ] ) ) { $period = 'month'; }

		$ref = isset( $_GET['ref'] ) ? sanitize_text_field( wp_unslash( $_GET['ref'] ) ) : $today; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! GOAC_Stats::valid_date( $ref ) || $ref > $today ) { $ref = $today; }

		// split_month representa o mês do PAGAMENTO. Ex.: 2026-09 = receita de 2026-08 paga em 21/09.
		$split_month = isset( $_GET['split_month'] ) ? sanitize_text_field( wp_unslash( $_GET['split_month'] ) ) : substr( $today, 0, 7 ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$latest = substr( GOAC_Stats::shift_months( $today, 1 ), 0, 7 );
		if ( ! preg_match( '/^\d{4}-\d{2}$/', $split_month ) || $split_month > $latest ) { $split_month = substr( $today, 0, 7 ); }

		return compact( 'period', 'ref', 'split_month' );
	}

	/* ------------------------------------------------------------------ Divisão 40/40/20 */

	private static function split_section( $payout_ym, array $c ) {
		$revenue_ym = self::revenue_month_for_payout( $payout_ym );
		$start = $revenue_ym . '-01';
		$end = GOAC_Stats::month_end( $start );
		if ( $end > $c['today'] ) { $end = $c['today']; }
		$total = GOAC_Stats::sum( GOAC_UI::rows( $start, $end ) );
		$earnings = (float) $total['earnings'];
		$partial = $revenue_ym === substr( $c['today'], 0, 7 );
		$budget = self::budget_summary( $payout_ym, GOAC_UI::currency_code() );
		$expenses = (float) $budget['total'];
		$balance = $earnings - $expenses;
		$distributable = max( 0.0, $balance );
		$margin = $earnings > 0 ? $balance / $earnings : null;
		$payout_date = $budget['payout_date'];

		$months = self::available_payout_months( $c );
		$options = '';
		foreach ( $months as $month ) {
			$options .= sprintf(
				'<option value="%s" %s>%s</option>',
				esc_attr( $month ),
				selected( $payout_ym, $month, false ),
				esc_html( GOAC_UI::month_label( $month, true ) )
			);
		}
		$aside = '<form method="get" class="goac-inline-form goac-inline-compact">'
			. '<input type="hidden" name="page" value="goac"><input type="hidden" name="tab" value="distribution">'
			. '<input type="hidden" name="period" value="' . esc_attr( isset( $_GET['period'] ) ? sanitize_key( wp_unslash( $_GET['period'] ) ) : 'month' ) . '">' // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			. '<input type="hidden" name="ref" value="' . esc_attr( isset( $_GET['ref'] ) && GOAC_Stats::valid_date( sanitize_text_field( wp_unslash( $_GET['ref'] ) ) ) ? sanitize_text_field( wp_unslash( $_GET['ref'] ) ) : $c['today'] ) . '">' // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			. '<label class="screen-reader-text" for="goac-split-month">Mês do pagamento</label><select id="goac-split-month" name="split_month">' . $options . '</select>'
			. '<button class="button">Ver pagamento</button></form>';

		GOAC_UI::card_open( 'Pagamento, orçamento e distribuição · 40 / 40 / 20', $aside, 'goac-distribution-card' );
		echo '<div class="goac-payment-cycle"><strong>Pagamento de ' . esc_html( GOAC_UI::month_label( $payout_ym, true ) ) . '</strong><span>previsto para ' . esc_html( GOAC_UI::date( $payout_date ) ) . '</span><span>referente à receita de ' . esc_html( GOAC_UI::month_label( $revenue_ym, true ) ) . '</span><span>gastos do ciclo: ' . esc_html( GOAC_UI::range_label( $budget['cycle_start'], $budget['cycle_end'] ) ) . '</span></div>';
		echo '<p class="goac-muted goac-section-intro">O caixa é organizado pelo pagamento. Assim, a receita de <strong>' . esc_html( GOAC_UI::month_label( $revenue_ym, true ) ) . '</strong> financia o pagamento de <strong>' . esc_html( GOAC_UI::month_label( $payout_ym, true ) ) . '</strong>; gastos com data dentro da janela acima são abatidos antes do 40/40/20. ' . ( $partial ? 'A receita de referência ainda está em andamento, então o valor do próximo pagamento é provisório.' : 'A receita de referência está completa no histórico local.' ) . '</p>';

		echo '<div class="goac-kpis goac-kpis-budget">';
		GOAC_UI::kpi( 'Receita de ' . GOAC_UI::month_label( $revenue_ym ), GOAC_UI::money( $earnings ), $partial ? 'acumulado até ' . esc_html( GOAC_UI::date( $end ) ) : esc_html( GOAC_UI::range_label( $start, $end ) ), array( 'class' => 'is-hero is-accent' ) );
		GOAC_UI::kpi( 'Gastos do ciclo', GOAC_UI::money( $expenses ), count( $budget['rows'] ) . ' lançamento(s) · ' . esc_html( GOAC_UI::date( $budget['cycle_start'], 'd/m' ) ) . '–' . esc_html( GOAC_UI::date( $budget['cycle_end'], 'd/m' ) ), array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'Sobra do pagamento', GOAC_UI::money( $distributable ), $balance < 0 ? 'déficit de ' . esc_html( GOAC_UI::money( abs( $balance ) ) ) : 'receita − gastos do ciclo', array( 'class' => 'is-hero ' . ( $balance < 0 ? 'is-danger' : 'is-good' ) ) );
		GOAC_UI::kpi( 'Margem após gastos', null === $margin ? '—' : GOAC_UI::pct( $margin ), $balance < 0 ? 'gastos acima da receita' : 'saldo / receita', array( 'class' => 'is-hero' ) );
		echo '</div>';

		if ( ! empty( $budget['unconverted'] ) ) {
			GOAC_UI::notice( 'warning', 'Há ' . count( $budget['unconverted'] ) . ' gasto(s) em moeda sem conversão disponível. Eles não entram no total até existir uma taxa de câmbio.' );
		}

		echo '<div class="goac-subhead"><h3>Distribuição do saldo disponível</h3><span class="goac-muted">40% Murilo · 40% Gregory · 20% Deco</span></div>';
		echo '<div class="goac-kpis goac-kpis-partners">';
		foreach ( self::PARTNERS as $name => $share ) {
			$value = $distributable * $share;
			$paypal = self::paypal_estimate_brl( $value, GOAC_UI::currency_code(), $payout_ym, (float) $budget['paypal_rate'] );
			$display = GOAC_UI::money( $value );
			if ( null !== $paypal ) { $display .= ' (≈ ' . GOAC_UI::money( $paypal, 2, 'BRL' ) . ' via PayPal)'; }
			$sub = 'pagamento previsto em ' . esc_html( GOAC_UI::date( $payout_date ) );
			if ( (float) $budget['paypal_rate'] <= 0 ) { $sub .= ' · informe a cotação PayPal'; }
			GOAC_UI::kpi( $name . ' · ' . number_format_i18n( $share * 100, 0 ) . '%', $display, $sub, array( 'class' => 'is-hero' ) );
		}
		echo '</div>';
		echo '<p class="goac-footnote"><strong>Consulta operacional.</strong> O AdSense normalmente emite o pagamento do mês anterior entre os dias 21 e 26; aqui a data planejada é configurável e começa em dia 21. A conversão PayPal entre parênteses é estimativa e não altera o valor-base da participação.</p>';
		GOAC_UI::card_close();

		self::budget_section( $payout_ym, $budget );
		self::split_history( $c );
	}

	private static function revenue_month_for_payout( $payout_ym ) {
		return substr( GOAC_Stats::shift_months( $payout_ym . '-01', -1 ), 0, 7 );
	}

	private static function available_payout_months( array $c ) {
		$first = ! empty( $c['first_day'] ) ? substr( (string) $c['first_day'], 0, 7 ) : substr( (string) $c['today'], 0, 7 );
		$current_revenue = substr( (string) $c['today'], 0, 7 );
		$out = array();
		$cursor = $current_revenue . '-01';
		$guard = 0;
		while ( substr( $cursor, 0, 7 ) >= $first && $guard < 240 ) {
			$out[] = substr( GOAC_Stats::shift_months( $cursor, 1 ), 0, 7 );
			$cursor = GOAC_Stats::shift_months( $cursor, -1 );
			$guard++;
		}
		return array_values( array_unique( $out ) );
	}

	private static function split_history( array $c ) {
		$months = array_slice( self::available_payout_months( $c ), 0, 24 );
		GOAC_UI::card_open( 'Histórico dos pagamentos e da divisão', '<span class="goac-muted">últimos ' . count( $months ) . ' ciclos disponíveis</span>' );
		if ( ! $months ) {
			GOAC_UI::empty_state( 'Sem ciclos disponíveis.' );
			GOAC_UI::card_close();
			return;
		}
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-sortable"><thead><tr><th data-sort-type="text" tabindex="0">Pagamento</th><th>Receita de</th><th class="num" data-sort-type="num" tabindex="0">Receita</th><th class="num" data-sort-type="num" tabindex="0">Gastos</th><th class="num" data-sort-type="num" tabindex="0">Sobra</th>';
		foreach ( self::PARTNERS as $name => $share ) { echo '<th class="num" data-sort-type="num" tabindex="0">' . esc_html( $name . ' ' . number_format_i18n( $share * 100, 0 ) . '%' ) . '</th>'; }
		echo '<th>Status</th></tr></thead><tbody>';
		foreach ( $months as $payout_ym ) {
			$revenue_ym = self::revenue_month_for_payout( $payout_ym );
			$start = $revenue_ym . '-01'; $end = GOAC_Stats::month_end( $start );
			$partial = $end >= $c['today']; if ( $end > $c['today'] ) { $end = $c['today']; }
			$e = (float) GOAC_Stats::sum( GOAC_UI::rows( $start, $end ) )['earnings'];
			$budget = self::budget_summary( $payout_ym, GOAC_UI::currency_code() );
			$expenses = (float) $budget['total'];
			$balance = $e - $expenses;
			$distributable = max( 0.0, $balance );
			$href = GOAC_UI::url( 'distribution', array( 'split_month' => $payout_ym, 'period' => 'month', 'ref' => $end ) );
			echo '<tr><td data-sort="' . esc_attr( $payout_ym ) . '"><a href="' . esc_url( $href ) . '"><strong>' . esc_html( GOAC_UI::month_label( $payout_ym, true ) ) . '</strong></a><span class="goac-table-sub">' . esc_html( GOAC_UI::date( $budget['payout_date'] ) ) . '</span></td>';
			echo '<td>' . esc_html( GOAC_UI::month_label( $revenue_ym, true ) ) . '</td>';
			echo '<td class="num" data-sort="' . esc_attr( (string) $e ) . '"><strong>' . esc_html( GOAC_UI::money( $e ) ) . '</strong></td>';
			echo '<td class="num" data-sort="' . esc_attr( (string) $expenses ) . '">' . esc_html( GOAC_UI::money( $expenses ) ) . '</td>';
			echo '<td class="num" data-sort="' . esc_attr( (string) $balance ) . '"><strong>' . esc_html( GOAC_UI::money( $balance ) ) . '</strong></td>';
			foreach ( self::PARTNERS as $share ) {
				$value = $distributable * $share;
				echo '<td class="num" data-sort="' . esc_attr( (string) $value ) . '">' . esc_html( GOAC_UI::money( $value ) ) . '</td>';
			}
			$status = $partial ? '<span class="goac-pill warn">receita parcial</span>' : '<span class="goac-pill ok">receita fechada</span>';
			if ( ! empty( $budget['unconverted'] ) ) { $status .= ' <span class="goac-pill warn">câmbio pendente</span>'; }
			echo '<td>' . $status . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	/* ------------------------------------------------------------------ Orçamento mensal */

	private static function budget( $payout_ym ) {
		$all = get_option( 'goac_distribution_budgets', array() );
		$all = is_array( $all ) ? $all : array();
		$row = isset( $all[ $payout_ym ] ) && is_array( $all[ $payout_ym ] ) ? $all[ $payout_ym ] : array();
		return array_merge( array( 'paypal_rate' => 0.0, 'payout_date' => self::default_payout_date( $payout_ym ), 'expenses' => array(), 'updated_at' => 0 ), $row );
	}

	private static function budget_categories() {
		return array( 'Hospedagem', 'IA', 'Plugins e software', 'Domínio', 'Freelancers', 'Design', 'Contabilidade', 'Marketing', 'Equipamentos', 'Impostos e taxas', 'Outros' );
	}

	public static function default_payout_date( $payout_ym ) {
		return preg_match( '/^\d{4}-\d{2}$/', (string) $payout_ym ) ? $payout_ym . '-21' : GOAC_API::today();
	}

	public static function payout_date( $payout_ym ) {
		$budget = self::budget( $payout_ym );
		$date = (string) ( $budget['payout_date'] ?? '' );
		if ( ! GOAC_Stats::valid_date( $date ) || substr( $date, 0, 7 ) !== $payout_ym ) { $date = self::default_payout_date( $payout_ym ); }
		return $date;
	}

	/** Janela operacional: dia seguinte ao pagamento anterior até o pagamento selecionado. */
	public static function cycle_range( $payout_ym ) {
		$end = self::payout_date( $payout_ym );
		$prev_ym = substr( GOAC_Stats::shift_months( $payout_ym . '-01', -1 ), 0, 7 );
		$prev_end = self::payout_date( $prev_ym );
		return array( 'start' => GOAC_Stats::add_days( $prev_end, 1 ), 'end' => $end );
	}

	private static function expense_ledger() {
		$rows = get_option( 'goac_distribution_expenses', array() );
		return is_array( $rows ) ? $rows : array();
	}

	/** Média mensal da conversão derivada dos relatórios do Google; cai para a taxa recente quando necessário. */
	private static function month_rate( $from, $to, $ym ) {
		static $cache = array();
		$from = strtoupper( (string) $from ); $to = strtoupper( (string) $to );
		if ( $from === $to ) { return 1.0; }
		$key = $from . '>' . $to . '@' . $ym;
		if ( array_key_exists( $key, $cache ) ) { return $cache[ $key ]; }
		$account = GOAC_Store::currency();
		if ( '' === $account ) { $cache[ $key ] = GOAC_UI::recent_rate( $from, $to ); return $cache[ $key ]; }
		$start = $ym . '-01'; $end = GOAC_Stats::month_end( $start );
		$today = GOAC_API::today(); if ( $end > $today ) { $end = $today; }
		$ratio_to_account = static function( $cur ) use ( $account, $start, $end ) {
			if ( $cur === $account ) { return 1.0; }
			$acc = 0.0; $fx = 0.0;
			foreach ( GOAC_Store::range( $start, $end ) as $d => $row ) {
				$v = GOAC_Store::fx_value( $cur, $d );
				if ( null !== $v && (float) $row['earnings'] > 0 ) { $acc += (float) $row['earnings']; $fx += (float) $v; }
			}
			if ( $acc > 0 && $fx > 0 ) { return $fx / $acc; }
			return null;
		};
		$a = $ratio_to_account( $from ); $b = $ratio_to_account( $to );
		if ( $a && $b ) { $cache[ $key ] = $b / $a; return $cache[ $key ]; }
		$cache[ $key ] = GOAC_UI::recent_rate( $from, $to );
		return $cache[ $key ];
	}

	private static function budget_summary( $payout_ym, $target_currency ) {
		$budget = self::budget( $payout_ym );
		$cycle = self::cycle_range( $payout_ym );
		$source_rows = array();
		foreach ( self::expense_ledger() as $row ) {
			if ( ! is_array( $row ) ) { continue; }
			$date = (string) ( $row['date'] ?? '' );
			if ( GOAC_Stats::valid_date( $date ) && $date >= $cycle['start'] && $date <= $cycle['end'] ) { $source_rows[] = $row; }
		}
		// Compatibilidade com a v2.2: gastos antigos do mês são tratados como pertencentes ao ciclo salvo.
		foreach ( (array) ( $budget['expenses'] ?? array() ) as $legacy ) {
			if ( ! is_array( $legacy ) ) { continue; }
			$legacy['date'] = $cycle['end'];
			$source_rows[] = $legacy;
		}

		$rows = array(); $categories = array(); $unconverted = array(); $total = 0.0;
		foreach ( $source_rows as $row ) {
			$date = (string) ( $row['date'] ?? $cycle['end'] );
			$amount = max( 0.0, (float) ( $row['amount'] ?? 0 ) );
			$currency = strtoupper( (string) ( $row['currency'] ?? $target_currency ) );
			$rate_month = GOAC_Stats::valid_date( $date ) ? substr( $date, 0, 7 ) : $payout_ym;
			$rate = self::month_rate( $currency, $target_currency, $rate_month );
			$converted = null !== $rate ? $amount * $rate : null;
			$clean = array(
				'date' => $date,
				'category' => (string) ( $row['category'] ?? 'Outros' ),
				'description' => (string) ( $row['description'] ?? '' ),
				'amount' => $amount,
				'currency' => $currency,
				'converted' => $converted,
				'rate' => $rate,
			);
			$rows[] = $clean;
			if ( null === $converted ) { $unconverted[] = $clean; continue; }
			$total += $converted;
			$key = $clean['category'] ?: 'Outros';
			$categories[ $key ] = (float) ( $categories[ $key ] ?? 0 ) + $converted;
		}
		usort( $rows, static function( $a, $b ) { return strcmp( (string) $a['date'], (string) $b['date'] ); } );
		arsort( $categories );
		return array(
			'total' => $total, 'rows' => $rows, 'categories' => $categories, 'unconverted' => $unconverted,
			'paypal_rate' => max( 0.0, (float) $budget['paypal_rate'] ), 'updated_at' => (int) $budget['updated_at'],
			'payout_date' => self::payout_date( $payout_ym ), 'cycle_start' => $cycle['start'], 'cycle_end' => $cycle['end'],
		);
	}

	/** Valor estimado em reais após converter a parcela para USD e aplicar a cotação manual do PayPal. */
	private static function paypal_estimate_brl( $amount, $currency, $payout_ym, $paypal_rate ) {
		if ( $paypal_rate <= 0 ) { return null; }
		$to_usd = self::month_rate( strtoupper( (string) $currency ), 'USD', $payout_ym );
		if ( null === $to_usd ) { return null; }
		return max( 0.0, (float) $amount ) * $to_usd * $paypal_rate;
	}

	private static function budget_section( $payout_ym, array $summary ) {
		$budget = self::budget( $payout_ym );
		$target = GOAC_UI::currency_code();
		$revenue_ym = self::revenue_month_for_payout( $payout_ym );
		GOAC_UI::card_open( 'Planilha do pagamento · ' . GOAC_UI::month_label( $payout_ym, true ), '<span class="goac-muted">receita de ' . esc_html( GOAC_UI::month_label( $revenue_ym, true ) ) . '</span>', 'goac-budget-card' );
		echo '<p class="goac-muted goac-section-intro">Cadastre a <strong>data real ou prevista</strong> de cada gasto. Só entram neste pagamento os lançamentos entre <strong>' . esc_html( GOAC_UI::date( $summary['cycle_start'] ) ) . '</strong> e <strong>' . esc_html( GOAC_UI::date( $summary['cycle_end'] ) ) . '</strong>. Se você mudar a data de um gasto para depois do pagamento, ele passa automaticamente para o próximo ciclo.</p>';
		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" data-goac-budget-form>';
		wp_nonce_field( 'goac_save_budget' );
		echo '<input type="hidden" name="action" value="goac_save_budget"><input type="hidden" name="budget_month" value="' . esc_attr( $payout_ym ) . '">';
		echo '<div class="goac-budget-settings">';
		echo '<label><span>Data prevista do pagamento</span><input type="date" name="payout_date" value="' . esc_attr( $summary['payout_date'] ) . '" min="' . esc_attr( $payout_ym . '-01' ) . '" max="' . esc_attr( GOAC_Stats::month_end( $payout_ym . '-01' ) ) . '"><small>Por padrão, dia 21. Ajuste se o pagamento efetivo for emitido depois.</small></label>';
		echo '<label><span>Cotação PayPal estimada</span><div class="goac-input-suffix"><input type="text" inputmode="decimal" name="paypal_rate" value="' . esc_attr( (float) $budget['paypal_rate'] > 0 ? number_format( (float) $budget['paypal_rate'], 4, '.', '' ) : '' ) . '" placeholder="ex.: 5,10"><em>R$ por US$ 1</em></div><small>Taxa líquida que você espera receber; serve só para o valor entre parênteses.</small></label>';
		echo '<div class="goac-budget-total"><span>Total de gastos deste ciclo</span><strong>' . esc_html( GOAC_UI::money( $summary['total'] ) ) . '</strong><small>' . esc_html( count( $summary['rows'] ) . ' lançamento(s)' ) . '</small></div></div>';

		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-budget-table"><thead><tr><th>Data</th><th>Categoria</th><th>Descrição</th><th class="num">Valor</th><th>Moeda</th><th class="num">Em ' . esc_html( $target ) . '</th><th><span class="screen-reader-text">Ações</span></th></tr></thead><tbody data-goac-expense-rows>';
		$rows = (array) $summary['rows'];
		$today = GOAC_API::today();
		$default_date = $today < $summary['cycle_start'] ? $summary['cycle_start'] : ( $today > $summary['cycle_end'] ? $summary['cycle_end'] : $today );
		if ( ! $rows ) { $rows[] = array( 'date' => $default_date, 'category' => 'Hospedagem', 'description' => '', 'amount' => 0, 'currency' => $target, 'converted' => 0 ); }
		foreach ( $rows as $i => $row ) { self::expense_row( $row, $i, $target, $default_date ); }
		echo '</tbody></table></div>';
		echo '<div class="goac-budget-actions"><button type="button" class="button" data-goac-add-expense><span class="dashicons dashicons-plus-alt2" aria-hidden="true"></span> Adicionar gasto</button><button type="submit" class="button button-primary">Salvar ciclo e recalcular</button></div>';
		echo '<template data-goac-expense-template>';
		self::expense_row( array( 'date' => $default_date, 'category' => 'Outros', 'description' => '', 'amount' => 0, 'currency' => $target, 'converted' => null ), '__INDEX__', $target, $default_date );
		echo '</template></form>';

		if ( $summary['categories'] ) {
			echo '<div class="goac-budget-categories"><strong>Gastos por categoria</strong><div>';
			foreach ( $summary['categories'] as $label => $value ) { echo '<span><b>' . esc_html( $label ) . '</b> ' . esc_html( GOAC_UI::money( $value ) ) . '</span>'; }
			echo '</div></div>';
		}
		GOAC_UI::card_close();
	}

	private static function expense_row( array $row, $index, $target_currency, $default_date ) {
		$date = (string) ( $row['date'] ?? $default_date );
		if ( ! GOAC_Stats::valid_date( $date ) ) { $date = $default_date; }
		$category = (string) ( $row['category'] ?? 'Outros' );
		$description = (string) ( $row['description'] ?? '' );
		$amount = (float) ( $row['amount'] ?? 0 );
		$currency = strtoupper( (string) ( $row['currency'] ?? $target_currency ) );
		$converted = array_key_exists( 'converted', $row ) ? $row['converted'] : null;
		$name = 'expenses[' . $index . ']';
		echo '<tr data-goac-expense-row><td><input type="date" name="' . esc_attr( $name . '[date]' ) . '" value="' . esc_attr( $date ) . '"></td><td><select name="' . esc_attr( $name . '[category]' ) . '">';
		$cats = self::budget_categories(); if ( $category && ! in_array( $category, $cats, true ) ) { array_unshift( $cats, $category ); }
		foreach ( array_unique( $cats ) as $cat ) { echo '<option value="' . esc_attr( $cat ) . '" ' . selected( $category, $cat, false ) . '>' . esc_html( $cat ) . '</option>'; }
		echo '</select></td><td><input type="text" name="' . esc_attr( $name . '[description]' ) . '" value="' . esc_attr( $description ) . '" placeholder="ex.: Hostinger, ChatGPT, domínio..."></td>';
		echo '<td class="num"><input class="goac-money-field" type="text" inputmode="decimal" name="' . esc_attr( $name . '[amount]' ) . '" value="' . esc_attr( $amount > 0 ? number_format( $amount, 2, '.', '' ) : '' ) . '" placeholder="0,00"></td><td><select name="' . esc_attr( $name . '[currency]' ) . '">';
		foreach ( GOAC_Store::currencies() as $cur ) { echo '<option value="' . esc_attr( $cur ) . '" ' . selected( $currency, $cur, false ) . '>' . esc_html( $cur ) . '</option>'; }
		echo '</select></td><td class="num goac-budget-converted">' . ( null === $converted ? '<span class="goac-muted">—</span>' : esc_html( GOAC_UI::money( $converted, 2, $target_currency ) ) ) . '</td><td class="num"><button type="button" class="button-link-delete goac-remove-expense" data-goac-remove-expense aria-label="Remover gasto"><span class="dashicons dashicons-trash" aria-hidden="true"></span></button></td></tr>';
	}

	/* ------------------------------------------------------------------ Rentabilidade editorial */

	private static function content_section( $period, $ref, array $c ) {
		$range = self::period_range( $period, $ref, $c['today'] );
		$chips = array();
		foreach ( self::PERIODS as $key => $label ) {
			$chips[] = '<a class="goac-chip ' . ( $period === $key ? 'is-active' : '' ) . '" href="' . esc_url( GOAC_UI::url( 'distribution', array( 'period' => $key, 'ref' => $ref, 'split_month' => isset( $_GET['split_month'] ) ? sanitize_text_field( wp_unslash( $_GET['split_month'] ) ) : substr( $c['today'], 0, 7 ) ) ) ) . '">' . esc_html( $label ) . '</a>'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		}
		$aside = '<div class="goac-chips">' . implode( '', $chips ) . '</div>';

		GOAC_UI::card_open( 'Rentabilidade editorial · ' . self::PERIODS[ $period ], $aside );
		echo '<form method="get" class="goac-content-date-form"><input type="hidden" name="page" value="goac"><input type="hidden" name="tab" value="distribution"><input type="hidden" name="period" value="' . esc_attr( $period ) . '"><input type="hidden" name="split_month" value="' . esc_attr( isset( $_GET['split_month'] ) ? sanitize_text_field( wp_unslash( $_GET['split_month'] ) ) : substr( $c['today'], 0, 7 ) ) . '"><label>Data de referência <input type="date" name="ref" max="' . esc_attr( $c['today'] ) . '" value="' . esc_attr( $ref ) . '"></label><button class="button">Atualizar</button><span class="goac-muted">' . esc_html( GOAC_UI::range_label( $range['start'], $range['end'] ) ) . '</span></form>'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		echo '<p class="goac-muted goac-section-intro">Ranking pela receita estimada atribuída pelo AdSense a cada URL. A categoria é resolvida no WordPress pela categoria principal da matéria.</p>';

		$data = self::content_data( $range['start'], $range['end'] );
		if ( is_wp_error( $data ) ) {
			GOAC_UI::notice( 'error', 'Não foi possível montar o ranking editorial: ' . esc_html( $data->get_error_message() ) );
			GOAC_UI::card_close();
			return;
		}

		$site_total = max( 0.0, (float) $data['site_total'] );
		$mapped = max( 0.0, (float) $data['post_total'] );
		$returned = max( 0.0, (float) $data['returned_total'] );
		echo '<div class="goac-kpis goac-kpis-compact">';
		GOAC_UI::kpi( 'Receita do período', GOAC_UI::money( $site_total ), esc_html( GOAC_UI::range_label( $range['start'], $range['end'] ) ), array( 'class' => 'is-accent' ) );
		GOAC_UI::kpi( 'Mapeada a matérias', GOAC_UI::money( $mapped ), $site_total > 0 ? esc_html( GOAC_UI::pct( $mapped / $site_total ) . ' do total' ) : '—' );
		GOAC_UI::kpi( 'Matérias com receita', GOAC_UI::number( count( $data['posts'] ) ), 'URLs reconhecidas como posts' );
		GOAC_UI::kpi( 'URLs lidas do AdSense', GOAC_UI::number( $data['row_count'] ), $data['total_rows'] > $data['row_count'] ? esc_html( GOAC_UI::number( $data['total_rows'] ) . ' URLs no total' ) : 'relatório completo' );
		GOAC_UI::kpi( 'Cobertura das URLs', $site_total > 0 ? GOAC_UI::pct( $returned / $site_total ) : '—', 'receita contida nas linhas retornadas' );
		echo '</div>';
		if ( empty( $data['has_page_views'] ) ) { echo '<p class="goac-footnote">O AdSense aceitou receita por URL, mas não PAGE_VIEWS junto de PAGE_URL nesta conta. O ranking continua válido por receita; PV e Page RPM aparecem como —.</p>'; }

		GOAC_UI::card_close();

		echo '<div class="goac-grid goac-grid-2">';
		self::posts_table( $data );
		self::categories_table( $data );
		echo '</div>';

		if ( $data['total_rows'] > $data['row_count'] ) {
			echo '<p class="goac-footnote">O AdSense informou ' . esc_html( GOAC_UI::number( $data['total_rows'] ) ) . ' URLs no período; esta consulta lê as ' . esc_html( GOAC_UI::number( $data['row_count'] ) ) . ' URLs de maior receita. A cobertura em receita acima mostra quanto do total está representado.</p>';
		}
	}

	private static function period_range( $period, $ref, $today ) {
		switch ( $period ) {
			case 'day': $start = $ref; $end = $ref; break;
			case 'week': $start = GOAC_Stats::week_start( $ref ); $end = GOAC_Stats::add_days( $start, 6 ); break;
			default: $start = GOAC_Stats::month_start( $ref ); $end = GOAC_Stats::month_end( $start ); break;
		}
		if ( $end > $today ) { $end = $today; }
		return compact( 'start', 'end' );
	}

	/**
	 * Uma única consulta PAGE_URL serve tanto ao ranking de matérias quanto ao
	 * de categorias. O limite alto evita três consultas e mantém o painel leve.
	 */
	private static function content_data( $start, $end ) {
		// PAGE_URL já identifica a página; combinar OWNED_SITE_DOMAIN_NAME como filtro
		// pode ser rejeitado pelo AdSense como combinação de dimensões incompatível.
		// Filtramos o domínio localmente depois que a API devolve as URLs.
		$r = GOAC_API::page_url_breakdown( $start, $end, array(
			'limit' => 10000,
			'currency' => GOAC_UI::api_currency(),
			'ttl' => GOAC_API::report_ttl( $end ),
		) );
		if ( is_wp_error( $r ) ) { return $r; }

		$by_url = array();
		foreach ( (array) $r['rows'] as $row ) {
			$url = self::normalize_url( (string) ( $row['dims'][0] ?? '' ) );
			if ( '' === $url || ! self::is_local_url( $url ) ) { continue; }
			if ( ! isset( $by_url[ $url ] ) ) { $by_url[ $url ] = array(); }
			$by_url[ $url ][] = $row;
		}

		$pages = array(); $slugs = array();
		foreach ( $by_url as $url => $rows ) {
			$sum = GOAC_Stats::sum( $rows );
			$path = (string) wp_parse_url( $url, PHP_URL_PATH );
			$slug = sanitize_title( rawurldecode( basename( untrailingslashit( $path ) ) ) );
			$pages[ $url ] = array( 'url' => $url, 'slug' => $slug ) + $sum;
			if ( $slug ) { $slugs[ $slug ] = true; }
		}

		$post_lookup = self::posts_by_slug( array_keys( $slugs ) );
		$post_ids = array();
		foreach ( $post_lookup as $list ) { foreach ( $list as $post ) { $post_ids[ (int) $post['ID'] ] = (int) $post['ID']; } }
		if ( $post_ids && function_exists( '_prime_post_caches' ) ) { _prime_post_caches( array_values( $post_ids ), true, true ); }

		$posts = array(); $category_rows = array();
		foreach ( $pages as $page ) {
			$slug = $page['slug'];
			if ( ! $slug || empty( $post_lookup[ $slug ] ) ) { continue; }
			$post = self::match_post_to_url( $post_lookup[ $slug ], $page['url'] );
			if ( ! $post ) { continue; }
			$post_id = (int) $post['ID'];
			if ( ! isset( $posts[ $post_id ] ) ) {
				$posts[ $post_id ] = array( 'post_id' => $post_id, 'title' => (string) $post['post_title'], 'url' => get_permalink( $post_id ), 'rows' => array() );
			}
			$posts[ $post_id ]['rows'][] = $page;
		}

		foreach ( $posts as $post_id => &$post ) {
			$sum = GOAC_Stats::sum( $post['rows'] );
			unset( $post['rows'] );
			$post += $sum;
			$cat = self::primary_category( $post_id );
			$post['category_id'] = $cat['id'];
			$post['category'] = $cat['label'];
			$key = $cat['id'] ? 'term:' . $cat['id'] : 'uncategorized';
			if ( ! isset( $category_rows[ $key ] ) ) { $category_rows[ $key ] = array( 'id' => $cat['id'], 'label' => $cat['label'], 'posts' => 0, 'rows' => array() ); }
			$category_rows[ $key ]['posts']++;
			$category_rows[ $key ]['rows'][] = $post;
		}
		unset( $post );

		$categories = array();
		foreach ( $category_rows as $cat ) {
			$sum = GOAC_Stats::sum( $cat['rows'] );
			$categories[] = array( 'id' => $cat['id'], 'label' => $cat['label'], 'posts' => $cat['posts'] ) + $sum;
		}

		$posts = array_values( $posts );
		usort( $posts, static function( $a, $b ) { return $b['earnings'] <=> $a['earnings']; } );
		usort( $categories, static function( $a, $b ) { return $b['earnings'] <=> $a['earnings']; } );

		$returned_total = (float) GOAC_Stats::sum( array_values( $pages ) )['earnings'];
		$post_total = (float) GOAC_Stats::sum( $posts )['earnings'];
		$site_total = self::site_total_for_period( $start, $end, $returned_total );
		return array(
			'posts' => $posts,
			'categories' => $categories,
			'site_total' => $site_total,
			'returned_total' => $returned_total,
			'post_total' => $post_total,
			'row_count' => count( $r['rows'] ),
			'total_rows' => max( count( $r['rows'] ), (int) ( $r['total_rows'] ?? 0 ) ),
			'has_page_views' => in_array( 'PAGE_VIEWS', (array) ( $r['metrics'] ?? array() ), true ),
		);
	}

	/** Total exato do domínio em consulta separada, sem combinar PAGE_URL com outra dimensão. */
	private static function site_total_for_period( $start, $end, $fallback ) {
		$domain = self::reporting_site_domain();
		if ( '' === $domain ) { return (float) $fallback; }
		$r = GOAC_API::breakdown( array( 'OWNED_SITE_DOMAIN_NAME' ), $start, $end, array(
			'limit' => 1000,
			'currency' => GOAC_UI::api_currency(),
			'ttl' => GOAC_API::report_ttl( $end ),
		) );
		if ( is_wp_error( $r ) ) { return (float) $fallback; }
		$wanted = preg_replace( '/^www\./i', '', strtolower( $domain ) );
		foreach ( (array) $r['rows'] as $row ) {
			$got = preg_replace( '/^www\./i', '', strtolower( trim( (string) ( $row['dims'][0] ?? '' ) ) ) );
			if ( $got === $wanted ) { return max( 0.0, (float) ( $row['earnings'] ?? 0 ) ); }
		}
		return (float) $fallback;
	}

	private static function normalize_url( $url ) {
		$url = html_entity_decode( trim( (string) $url ), ENT_QUOTES, 'UTF-8' );
		if ( '' === $url ) { return ''; }
		$parts = wp_parse_url( $url );
		if ( ! is_array( $parts ) ) { return ''; }
		$host = strtolower( (string) ( $parts['host'] ?? wp_parse_url( home_url( '/' ), PHP_URL_HOST ) ) );
		$path = '/' . ltrim( (string) ( $parts['path'] ?? '/' ), '/' );
		$path = preg_replace( '#/amp/?$#i', '/', $path );
		$path = '/' === $path ? '/' : trailingslashit( untrailingslashit( $path ) );
		$scheme = strtolower( (string) ( $parts['scheme'] ?? wp_parse_url( home_url( '/' ), PHP_URL_SCHEME ) ?: 'https' ) );
		return $scheme . '://' . $host . $path;
	}

	private static function reporting_site_domain() {
		$home = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
		if ( '' === $home ) { return ''; }
		$home_key = preg_replace( '/^www\./i', '', $home );
		$sites = GOAC_API::sites();
		if ( ! is_wp_error( $sites ) ) {
			foreach ( (array) $sites as $site ) {
				$domain = strtolower( trim( (string) ( $site['domain'] ?? '' ) ) );
				if ( $domain && preg_replace( '/^www\./i', '', $domain ) === $home_key ) { return $domain; }
			}
		}
		return $home;
	}

	private static function is_local_url( $url ) {
		$host = strtolower( (string) wp_parse_url( (string) $url, PHP_URL_HOST ) );
		$home = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
		$host = preg_replace( '/^www\./i', '', $host );
		$home = preg_replace( '/^www\./i', '', $home );
		return '' !== $host && $host === $home;
	}

	/** Busca posts publicados em lotes, evitando um url_to_postid() por URL. */
	private static function posts_by_slug( array $slugs ) {
		global $wpdb;
		$out = array();
		$slugs = array_values( array_unique( array_filter( array_map( 'sanitize_title', $slugs ) ) ) );
		foreach ( array_chunk( $slugs, 200 ) as $chunk ) {
			$placeholders = implode( ',', array_fill( 0, count( $chunk ), '%s' ) );
			$sql = "SELECT ID, post_name, post_title FROM {$wpdb->posts} WHERE post_type = 'post' AND post_status = 'publish' AND post_name IN ($placeholders)"; // phpcs:ignore WordPress.DB.PreparedSQL.InterpolatedNotPrepared
			$rows = $wpdb->get_results( $wpdb->prepare( $sql, $chunk ), ARRAY_A ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
			foreach ( (array) $rows as $row ) { $out[ (string) $row['post_name'] ][] = $row; }
		}
		return $out;
	}

	private static function match_post_to_url( array $posts, $url ) {
		if ( 1 === count( $posts ) ) { return $posts[0]; }
		$wanted = self::normalized_path( $url );
		foreach ( $posts as $post ) {
			if ( self::normalized_path( get_permalink( (int) $post['ID'] ) ) === $wanted ) { return $post; }
		}
		return $posts ? $posts[0] : null;
	}

	private static function normalized_path( $url ) {
		$path = (string) wp_parse_url( (string) $url, PHP_URL_PATH );
		$path = preg_replace( '#/amp/?$#i', '/', $path );
		return '/' === $path ? '/' : trailingslashit( untrailingslashit( '/' . ltrim( $path, '/' ) ) );
	}

	private static function primary_category( $post_id ) {
		$assigned_ids = wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) );
		$assigned_ids = array_map( 'intval', (array) $assigned_ids );
		foreach ( array( '_yoast_wpseo_primary_category', 'rank_math_primary_category' ) as $meta_key ) {
			$primary = (int) get_post_meta( $post_id, $meta_key, true );
			if ( $primary && in_array( $primary, $assigned_ids, true ) ) {
				$term = get_term( $primary, 'category' );
				if ( $term && ! is_wp_error( $term ) ) { return array( 'id' => $primary, 'label' => self::category_label( $term ) ); }
			}
		}
		$cats = get_the_category( $post_id );
		if ( ! $cats ) { return array( 'id' => 0, 'label' => 'Sem categoria' ); }
		usort( $cats, static function( $a, $b ) {
			$da = count( get_ancestors( $a->term_id, 'category' ) );
			$db = count( get_ancestors( $b->term_id, 'category' ) );
			return $db === $da ? ( $a->term_id <=> $b->term_id ) : ( $db <=> $da );
		} );
		return array( 'id' => (int) $cats[0]->term_id, 'label' => self::category_label( $cats[0] ) );
	}

	private static function category_label( $term ) {
		$names = array( (string) $term->name );
		$parent = (int) $term->parent; $guard = 0;
		while ( $parent && $guard < 3 ) {
			$p = get_term( $parent, 'category' );
			if ( ! $p || is_wp_error( $p ) ) { break; }
			array_unshift( $names, (string) $p->name );
			$parent = (int) $p->parent; $guard++;
		}
		return implode( ' › ', $names );
	}

	private static function posts_table( array $data ) {
		$rows = array_slice( $data['posts'], 0, 20 );
		GOAC_UI::card_open( 'Matérias que mais deram $', '<span class="goac-muted">Top ' . count( $rows ) . '</span>' );
		if ( ! $rows ) { GOAC_UI::empty_state( 'Nenhuma URL de matéria pôde ser associada a um post neste período.' ); GOAC_UI::card_close(); return; }
		$total = max( 1e-9, (float) $data['post_total'] );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable goac-sticky"><thead><tr><th data-sort-type="text" tabindex="0">Matéria</th><th class="num" data-sort-type="num" tabindex="0">Receita</th><th class="num" data-sort-type="num" tabindex="0">%</th><th class="num" data-sort-type="num" tabindex="0">PV</th><th class="num" data-sort-type="num" tabindex="0">Page RPM</th></tr></thead><tbody>';
		foreach ( $rows as $row ) {
			$share = (float) $row['earnings'] / $total;
			$title = $row['title'] ?: self::normalized_path( $row['url'] );
			echo '<tr><td class="goac-dim-cell" data-sort="' . esc_attr( mb_strtolower( $title ) ) . '"><a href="' . esc_url( $row['url'] ) . '" target="_blank" rel="noopener noreferrer"><strong>' . esc_html( $title ) . '</strong></a><small class="goac-table-sub">' . esc_html( $row['category'] ) . '</small></td>';
			echo '<td class="num goac-cell-bar" data-sort="' . esc_attr( (string) $row['earnings'] ) . '">' . GOAC_UI::bar( $share ) . '<span><strong>' . esc_html( GOAC_UI::money( $row['earnings'] ) ) . '</strong></span></td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num" data-sort="' . esc_attr( (string) $share ) . '">' . esc_html( GOAC_UI::pct( $share ) ) . '</td>';
			if ( ! empty( $data['has_page_views'] ) ) {
				echo '<td class="num" data-sort="' . esc_attr( (string) $row['page_views'] ) . '">' . esc_html( GOAC_UI::number( $row['page_views'] ) ) . '</td><td class="num" data-sort="' . esc_attr( null === $row['page_rpm'] ? '' : (string) $row['page_rpm'] ) . '">' . esc_html( GOAC_UI::money( $row['page_rpm'] ) ) . '</td>';
			} else { echo '<td class="num" data-sort="">—</td><td class="num" data-sort="">—</td>'; }
			echo '</tr>';
		}
		echo '</tbody></table></div><p class="goac-footnote">Participação (%) calculada sobre a receita que pôde ser mapeada a matérias.</p>';
		GOAC_UI::card_close();
	}

	private static function categories_table( array $data ) {
		$rows = array_slice( $data['categories'], 0, 20 );
		GOAC_UI::card_open( 'Categorias que mais deram $', '<span class="goac-muted">sem dupla contagem</span>' );
		if ( ! $rows ) { GOAC_UI::empty_state( 'Nenhuma categoria pôde ser calculada neste período.' ); GOAC_UI::card_close(); return; }
		$total = max( 1e-9, (float) $data['post_total'] );
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable goac-sticky"><thead><tr><th data-sort-type="text" tabindex="0">Categoria principal</th><th class="num" data-sort-type="num" tabindex="0">Receita</th><th class="num" data-sort-type="num" tabindex="0">%</th><th class="num" data-sort-type="num" tabindex="0">Matérias</th><th class="num" data-sort-type="num" tabindex="0">Page RPM</th></tr></thead><tbody>';
		foreach ( $rows as $row ) {
			$share = (float) $row['earnings'] / $total;
			echo '<tr><td data-sort="' . esc_attr( mb_strtolower( $row['label'] ) ) . '"><strong>' . esc_html( $row['label'] ) . '</strong></td>';
			echo '<td class="num goac-cell-bar" data-sort="' . esc_attr( (string) $row['earnings'] ) . '">' . GOAC_UI::bar( $share ) . '<span><strong>' . esc_html( GOAC_UI::money( $row['earnings'] ) ) . '</strong></span></td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num" data-sort="' . esc_attr( (string) $share ) . '">' . esc_html( GOAC_UI::pct( $share ) ) . '</td><td class="num" data-sort="' . esc_attr( (string) $row['posts'] ) . '">' . esc_html( GOAC_UI::number( $row['posts'] ) ) . '</td>';
			if ( ! empty( $data['has_page_views'] ) ) { echo '<td class="num" data-sort="' . esc_attr( null === $row['page_rpm'] ? '' : (string) $row['page_rpm'] ) . '">' . esc_html( GOAC_UI::money( $row['page_rpm'] ) ) . '</td>'; } else { echo '<td class="num" data-sort="">—</td>'; }
			echo '</tr>';
		}
		echo '</tbody></table></div><p class="goac-footnote">Cada matéria entra em uma única categoria principal. Posts com várias categorias não multiplicam a receita.</p>';
		GOAC_UI::card_close();
	}
}
