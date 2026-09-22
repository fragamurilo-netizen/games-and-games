<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Aba Relatórios: quebras por dimensão direto da API, com totais, médias, comparação e filtros. */
final class GOAC_View_Reports {
	const DIMENSIONS = array(
		'Tempo' => array( 'date' => array( 'DATE', 'Data' ), 'week' => array( 'WEEK', 'Semana' ), 'month' => array( 'MONTH', 'Mês' ) ),
		'Público' => array( 'country' => array( 'COUNTRY_NAME', 'País' ), 'platform' => array( 'PLATFORM_TYPE_NAME', 'Plataforma' ), 'os' => array( 'OS_TYPE_NAME', 'Sistema operacional' ), 'browser' => array( 'BROWSER_TYPE_NAME', 'Navegador' ), 'webview' => array( 'WEBVIEW_TYPE_NAME', 'WebView' ), 'traffic' => array( 'TRAFFIC_SOURCE_NAME', 'Origem do tráfego' ) ),
		'Conteúdo' => array( 'site' => array( 'OWNED_SITE_DOMAIN_NAME', 'Site' ), 'domain' => array( 'DOMAIN_NAME', 'Domínio' ), 'page' => array( 'PAGE_URL', 'Página (URL)' ), 'url_channel' => array( 'URL_CHANNEL_NAME', 'Canal de URL' ), 'custom_channel' => array( 'CUSTOM_CHANNEL_NAME', 'Canal personalizado' ), 'content_platform' => array( 'CONTENT_PLATFORM_NAME', 'Plataforma de conteúdo' ) ),
		'Anúncios' => array( 'unit' => array( 'AD_UNIT_NAME', 'Unidade de anúncio' ), 'unit_size' => array( 'AD_UNIT_SIZE_NAME', 'Tamanho da unidade' ), 'format' => array( 'AD_FORMAT_NAME', 'Formato' ), 'placement' => array( 'AD_PLACEMENT_NAME', 'Posicionamento' ), 'served_type' => array( 'SERVED_AD_TYPE_NAME', 'Tipo veiculado' ), 'requested_type' => array( 'REQUESTED_AD_TYPE_NAME', 'Tipo solicitado' ), 'creative_size' => array( 'CREATIVE_SIZE_NAME', 'Tamanho do criativo' ) ),
		'Demanda' => array( 'buyer' => array( 'BUYER_NETWORK_NAME', 'Rede compradora' ), 'bid' => array( 'BID_TYPE_NAME', 'Tipo de lance' ), 'targeting' => array( 'TARGETING_TYPE_NAME', 'Segmentação' ), 'product' => array( 'PRODUCT_NAME', 'Produto' ) ),
	);
	const TIME = array( 'date', 'week', 'month' );
	const LIMITS = array( 25, 50, 100, 250, 500, 1000, 5000 );

	public static function dimension( $key ) {
		foreach ( self::DIMENSIONS as $group ) { if ( isset( $group[ $key ] ) ) { return $group[ $key ]; } }
		return null;
	}

	public static function params() {
		list( $range, $include_today ) = GOAC_UI::request_range( 'last_30', false );
		$get = static function( $key, $default ) { return isset( $_GET[ $key ] ) ? sanitize_text_field( wp_unslash( $_GET[ $key ] ) ) : $default; }; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$dim = sanitize_key( $get( 'dimension', 'date' ) ); if ( ! self::dimension( $dim ) ) { $dim = 'date'; }
		$dim2 = sanitize_key( $get( 'dimension2', '' ) ); if ( $dim2 === $dim || ! self::dimension( $dim2 ) ) { $dim2 = ''; }
		$limit = (int) $get( 'limit', in_array( $dim, self::TIME, true ) ? 500 : 100 ); if ( ! in_array( $limit, self::LIMITS, true ) ) { $limit = 100; }
		$filter_dim = sanitize_key( $get( 'filter_dim', '' ) ); if ( ! self::dimension( $filter_dim ) || in_array( $filter_dim, self::TIME, true ) ) { $filter_dim = ''; }
		$filter_op = 'contains' === $get( 'filter_op', 'eq' ) ? 'contains' : 'eq';
		$filter_value = trim( (string) $get( 'filter_value', '' ) );
		return array(
			'range' => $range, 'include_today' => $include_today, 'dimension' => $dim, 'dimension2' => $dim2, 'limit' => $limit,
			'compare' => ! empty( $_GET['compare'] ), 'advanced' => ! empty( $_GET['advanced'] ), // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			'filter_dim' => $filter_dim, 'filter_op' => $filter_op, 'filter_value' => mb_substr( $filter_value, 0, 300 ),
		);
	}

	public static function dataset( array $p ) {
		$dims = array( self::dimension( $p['dimension'] )[0] );
		if ( $p['dimension2'] ) { $dims[] = self::dimension( $p['dimension2'] )[0]; }
		$filters = array();
		if ( $p['filter_dim'] && '' !== $p['filter_value'] ) {
			$filters[] = self::dimension( $p['filter_dim'] )[0] . ( 'contains' === $p['filter_op'] ? '=@' : '==' ) . GOAC_API::filter_value( $p['filter_value'] );
		}
		$time = in_array( $p['dimension'], self::TIME, true );
		$order = $time ? array( '+' . $dims[0] ) : array( '-ESTIMATED_EARNINGS' );
		$r = GOAC_API::breakdown( $dims, $p['range']['start'], $p['range']['end'], array( 'limit' => $p['limit'], 'filters' => $filters, 'orderBy' => $order, 'currency' => GOAC_UI::api_currency() ) );
		if ( is_wp_error( $r ) ) { return $r; }
		$prev = null; $cmp = null;
		if ( $p['compare'] ) {
			$cmp = GOAC_Stats::compare_range( $p['range'] );
			$pr = GOAC_API::breakdown( $dims, $cmp['start'], $cmp['end'], array( 'limit' => min( 100000, max( 1000, 2 * $p['limit'] ) ), 'filters' => $filters, 'orderBy' => array( '-ESTIMATED_EARNINGS' ), 'currency' => GOAC_UI::api_currency() ) );
			if ( ! is_wp_error( $pr ) ) {
				$prev = array( 'totals' => $pr['totals'], 'map' => array() );
				foreach ( $pr['rows'] as $row ) { $prev['map'][ implode( '|', $row['dims'] ) ] = $row; }
				if ( $time ) { // Datas não coincidem: compara por posição.
					$prev['by_index'] = array_values( self::sort_time( $pr['rows'] ) );
				}
			}
		}
		return $r + array( 'prev' => $prev, 'cmp' => $cmp, 'time' => $time, 'filters' => $filters );
	}

	private static function sort_time( array $rows ) {
		usort( $rows, static function( $a, $b ) { return strcmp( $a['dims'][0], $b['dims'][0] ); } );
		return $rows;
	}

	public static function render() {
		$p = self::params();
		$range = $p['range'];
		echo '<section class="goac-card goac-filters"><form method="get" class="goac-filter-row" data-goac-period-form>';
		echo '<input type="hidden" name="page" value="goac"><input type="hidden" name="tab" value="reports">';
		GOAC_UI::period_fields( $range, $p['include_today'] );
		self::dimension_select( 'dimension', 'Quebrar por', $p['dimension'], false );
		self::dimension_select( 'dimension2', 'Depois por', $p['dimension2'], true );
		echo '<label>Linhas<select name="limit">';
		foreach ( self::LIMITS as $n ) { printf( '<option value="%d" %s>%d</option>', (int) $n, selected( $p['limit'], $n, false ), (int) $n ); }
		echo '</select></label>';
		echo '<fieldset class="goac-filter-inline"><legend>Filtro</legend>';
		echo '<select name="filter_dim" aria-label="Dimensão do filtro"><option value="">Sem filtro</option>';
		foreach ( self::DIMENSIONS as $group_label => $group ) {
			if ( 'Tempo' === $group_label ) { continue; }
			echo '<optgroup label="' . esc_attr( $group_label ) . '">';
			foreach ( $group as $k => $d ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $k ), selected( $p['filter_dim'], $k, false ), esc_html( $d[1] ) ); }
			echo '</optgroup>';
		}
		echo '</select><select name="filter_op" aria-label="Operador"><option value="eq" ' . selected( $p['filter_op'], 'eq', false ) . '>é igual a</option><option value="contains" ' . selected( $p['filter_op'], 'contains', false ) . '>contém</option></select>';
		echo '<input type="text" name="filter_value" value="' . esc_attr( $p['filter_value'] ) . '" placeholder="ex.: Brasil, /review/" aria-label="Valor do filtro"></fieldset>';
		printf( '<label class="goac-check"><input type="checkbox" name="compare" value="1" %s> Comparar com período anterior</label>', checked( $p['compare'], true, false ) );
		printf( '<label class="goac-check"><input type="checkbox" name="advanced" value="1" %s> Métricas avançadas</label>', checked( $p['advanced'], true, false ) );
		echo '<div class="goac-filter-actions"><button class="button button-primary">Gerar relatório</button>';
		$export = array_merge( array( 'source' => 'reports', 'preset' => $range['preset'], 'from' => $range['start'], 'to' => $range['end'], 'include_today' => $p['include_today'] ? 1 : 0 ), array_intersect_key( $p, array_flip( array( 'dimension', 'dimension2', 'limit', 'filter_dim', 'filter_op', 'filter_value' ) ) ) );
		echo '<a class="button" href="' . esc_url( GOAC_UI::action_url( 'goac_export', $export ) ) . '">Exportar CSV</a></div></form>';
		echo '<p class="goac-muted goac-range-note"><strong>' . esc_html( GOAC_UI::range_label( $range['start'], $range['end'] ) ) . '</strong> · ' . (int) $range['days'] . ' dias · fuso ' . esc_html( GOAC_API::tz()->getName() ) . ( $range['end'] === GOAC_API::today() ? ' · inclui hoje em andamento' : ' · dias completos' ) . '</p></section>';

		$data = self::dataset( $p );
		if ( is_wp_error( $data ) ) { GOAC_UI::notice( 'error', '<strong>O AdSense recusou o relatório:</strong> ' . esc_html( $data->get_error_message() ) ); return; }
		if ( 'full' !== $data['metric_set'] ) {
			GOAC_UI::notice( 'info', 'Essa combinação de dimensões não aceita todas as métricas; o relatório usa ' . esc_html( implode( ', ', $data['metrics'] ) ) . '. Colunas sem dado aparecem como “—”.' );
		}
		foreach ( (array) $data['warnings'] as $warning ) { GOAC_UI::notice( 'warning', esc_html( (string) $warning ) ); }
		if ( $p['filter_dim'] && '' !== $p['filter_value'] ) {
			GOAC_UI::notice( 'info', 'Filtro ativo: <strong>' . esc_html( self::dimension( $p['filter_dim'] )[1] . ( 'contains' === $p['filter_op'] ? ' contém ' : ' = ' ) . $p['filter_value'] ) . '</strong> · <a href="' . esc_url( remove_query_arg( array( 'filter_dim', 'filter_op', 'filter_value' ) ) ) . '">remover</a>' );
		}

		self::summary( $data, $p );
		if ( $data['rows'] ) {
			if ( $data['time'] && ! $p['dimension2'] ) { self::time_chart( $data, $p ); }
			elseif ( ! $data['time'] ) { self::share_list( $data, $p ); }
		}
		self::table( $data, $p );
	}

	private static function dimension_select( $name, $label, $current, $optional ) {
		echo '<label>' . esc_html( $label ) . '<select name="' . esc_attr( $name ) . '">';
		if ( $optional ) { echo '<option value="">—</option>'; }
		foreach ( self::DIMENSIONS as $group_label => $group ) {
			echo '<optgroup label="' . esc_attr( $group_label ) . '">';
			foreach ( $group as $k => $d ) { printf( '<option value="%s" %s>%s</option>', esc_attr( $k ), selected( $current, $k, false ), esc_html( $d[1] ) ); }
			echo '</optgroup>';
		}
		echo '</select></label>';
	}

	private static function summary( array $data, array $p ) {
		$t = $data['totals']; $pt = $data['prev'] ? $data['prev']['totals'] : null;
		$label = $data['cmp'] ? 'vs. ' . $data['cmp']['label'] : '';
		$d = static function( $key ) use ( $t, $pt, $label ) { return $pt ? GOAC_UI::delta( GOAC_Stats::delta( $t[ $key ], $pt[ $key ] ), $label ) : ''; };
		$has = static function( $metric ) use ( $data ) { return in_array( $metric, $data['metrics'], true ); };
		echo '<div class="goac-kpis goac-kpis-summary">';
		GOAC_UI::kpi( 'Receita', GOAC_UI::money( $t['earnings'] ), $d( 'earnings' ), array( 'class' => 'is-hero is-accent' ) );
		GOAC_UI::kpi( 'Média por dia', GOAC_UI::money( $t['earnings'] / max( 1, $p['range']['days'] ) ), '', array( 'class' => 'is-hero' ) );
		if ( $has( 'PAGE_VIEWS' ) ) { GOAC_UI::kpi( 'Page views', GOAC_UI::number( $t['page_views'] ), $d( 'page_views' ) ); GOAC_UI::kpi( 'Page RPM', GOAC_UI::money( $t['page_rpm'] ), $d( 'page_rpm' ) ); GOAC_UI::kpi( 'CTR da página', GOAC_UI::pct( $t['ctr'], 2 ), $d( 'ctr' ) ); }
		if ( $has( 'IMPRESSIONS' ) ) { GOAC_UI::kpi( 'Impressões', GOAC_UI::number( $t['impressions'] ), $d( 'impressions' ) ); GOAC_UI::kpi( 'RPM de impressão', GOAC_UI::money( $t['impression_rpm'] ), $d( 'impression_rpm' ) ); }
		if ( $has( 'CLICKS' ) ) { GOAC_UI::kpi( 'Cliques', GOAC_UI::number( $t['clicks'] ), $d( 'clicks' ) ); GOAC_UI::kpi( 'CPC', GOAC_UI::money( $t['cpc'] ), $d( 'cpc' ) ); }
		if ( $has( 'AD_REQUESTS' ) ) { GOAC_UI::kpi( 'Cobertura', GOAC_UI::pct( $t['coverage'] ), $d( 'coverage' ) ); }
		if ( $has( 'ACTIVE_VIEW_VIEWABILITY' ) ) { GOAC_UI::kpi( 'Active View', GOAC_UI::pct( $t['viewability'] ), $d( 'viewability' ) ); }
		GOAC_UI::kpi( 'Linhas', GOAC_UI::number( count( $data['rows'] ) ), esc_html( $data['total_rows'] > count( $data['rows'] ) ? 'de ' . GOAC_UI::number( $data['total_rows'] ) . ' (aumente o limite)' : 'todas as linhas' ) );
		echo '</div>';
	}

	private static function time_chart( array $data, array $p ) {
		$rows = self::sort_time( $data['rows'] );
		$labels = array(); $values = array(); $compare = array();
		foreach ( $rows as $i => $row ) {
			$labels[] = $row['dims'][0]; $values[] = round( (float) $row['earnings'], 4 );
			$compare[] = isset( $data['prev']['by_index'][ $i ] ) ? round( (float) $data['prev']['by_index'][ $i ]['earnings'], 4 ) : null;
		}
		$series = array( array( 'name' => 'Receita', 'type' => 'bar', 'values' => $values ) );
		if ( $data['prev'] ) { $series[] = array( 'name' => ucfirst( $data['cmp']['label'] ), 'type' => 'line', 'values' => $compare, 'color' => 'muted' ); }
		GOAC_UI::card_open( 'Receita no período' );
		GOAC_UI::chart( array( 'labels' => $labels, 'labelType' => 'month' === $p['dimension'] ? 'month' : 'date', 'format' => 'money', 'today' => GOAC_API::today(), 'series' => $series ), 240 );
		GOAC_UI::card_close();
	}

	private static function share_list( array $data, array $p ) {
		$rows = $data['rows'];
		usort( $rows, static function( $a, $b ) { return $b['earnings'] <=> $a['earnings']; } );
		$total = max( 1e-9, (float) $data['totals']['earnings'] );
		$top = array_slice( $rows, 0, 12 );
		$rest = 0.0; foreach ( array_slice( $rows, 12 ) as $row ) { $rest += (float) $row['earnings']; }
		$rest += max( 0.0, $total - array_sum( array_column( $rows, 'earnings' ) ) );
		GOAC_UI::card_open( 'Participação na receita', '<span class="goac-muted">12 maiores</span>' );
		echo '<ul class="goac-share-list">';
		foreach ( $top as $row ) {
			$name = implode( ' · ', array_map( array( __CLASS__, 'dim_text' ), $row['dims'] ) );
			echo '<li><span class="goac-share-name" title="' . esc_attr( $name ) . '">' . esc_html( $name ) . '</span>' . GOAC_UI::bar( $row['earnings'] / $total ) . '<span class="goac-share-value">' . esc_html( GOAC_UI::money( $row['earnings'] ) . ' · ' . GOAC_UI::pct( $row['earnings'] / $total ) ) . '</span></li>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		if ( $rest > 0.005 ) { echo '<li class="is-rest"><span class="goac-share-name">Demais</span>' . GOAC_UI::bar( $rest / $total, 'is-muted' ) . '<span class="goac-share-value">' . esc_html( GOAC_UI::money( $rest ) . ' · ' . GOAC_UI::pct( $rest / $total ) ) . '</span></li>'; } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		echo '</ul>';
		GOAC_UI::card_close();
	}

	public static function dim_text( $value ) {
		$value = (string) $value;
		return '' === $value ? '(não informado)' : $value;
	}

	private static function dim_label( $key, $value ) {
		if ( 'date' === $key || 'week' === $key ) { return GOAC_Stats::valid_date( $value ) ? GOAC_UI::weekday( $value ) . ' ' . GOAC_UI::date( $value ) : $value; }
		if ( 'month' === $key ) { return GOAC_UI::month_label( $value, true ); }
		return self::dim_text( $value );
	}

	private static function table( array $data, array $p ) {
		$dims = array( $p['dimension'] ); if ( $p['dimension2'] ) { $dims[] = $p['dimension2']; }
		$total = max( 1e-9, (float) $data['totals']['earnings'] );
		$has = static function( $metric ) use ( $data ) { return in_array( $metric, $data['metrics'], true ); };
		$cols = array( array( 'earnings', 'Receita', 'money' ) );
		$cols[] = array( 'share', '% da receita', 'share' );
		if ( $data['prev'] ) { $cols[] = array( 'delta', 'vs. anterior', 'delta' ); }
		if ( $has( 'PAGE_VIEWS' ) ) { $cols[] = array( 'page_views', 'Page views', 'number' ); }
		if ( $has( 'IMPRESSIONS' ) ) { $cols[] = array( 'impressions', 'Impressões', 'number' ); }
		if ( $has( 'CLICKS' ) ) { $cols[] = array( 'clicks', 'Cliques', 'number' ); }
		if ( $has( 'PAGE_VIEWS' ) ) { $cols[] = array( 'ctr', 'CTR', 'pct2' ); }
		if ( $has( 'CLICKS' ) ) { $cols[] = array( 'cpc', 'CPC', 'money' ); }
		if ( $has( 'PAGE_VIEWS' ) ) { $cols[] = array( 'page_rpm', 'Page RPM', 'money' ); }
		if ( $has( 'IMPRESSIONS' ) ) { $cols[] = array( 'impression_rpm', 'RPM impr.', 'money' ); }
		if ( $has( 'AD_REQUESTS' ) ) { $cols[] = array( 'coverage', 'Cobertura', 'pct' ); }
		if ( $has( 'ACTIVE_VIEW_VIEWABILITY' ) ) { $cols[] = array( 'viewability', 'Active View', 'pct' ); }
		if ( $p['advanced'] ) {
			if ( $has( 'AD_REQUESTS' ) ) { $cols[] = array( 'ad_requests', 'Solicitações', 'number' ); $cols[] = array( 'matched_requests', 'Correspondidas', 'number' ); }
			if ( $has( 'PAGE_VIEWS' ) && $has( 'IMPRESSIONS' ) ) { $cols[] = array( 'impressions_per_page', 'Impr./página', 'decimal' ); }
			if ( $has( 'ACTIVE_VIEW_MEASURABILITY' ) ) { $cols[] = array( 'measurability', 'Mensurável', 'pct' ); }
			if ( $has( 'ACTIVE_VIEW_TIME' ) ) { $cols[] = array( 'view_time', 'Tempo visível', 'seconds' ); }
			if ( $data['prev'] && $has( 'PAGE_VIEWS' ) ) { $cols[] = array( 'delta_rpm', 'RPM vs. anterior', 'delta' ); $cols[] = array( 'delta_pv', 'Page views vs. anterior', 'delta' ); }
		}
		$fmt = static function( $type, $v ) {
			switch ( $type ) {
				case 'money': return esc_html( GOAC_UI::money( $v ) );
				case 'number': return esc_html( GOAC_UI::number( $v ) );
				case 'pct': return esc_html( GOAC_UI::pct( $v ) );
				case 'pct2': return esc_html( GOAC_UI::pct( $v, 2 ) );
				case 'decimal': return esc_html( GOAC_UI::number( $v, 2 ) );
				case 'seconds': return esc_html( GOAC_UI::seconds( $v ) );
				case 'delta': return GOAC_UI::delta( $v );
				default: return esc_html( (string) $v );
			}
		};
		$rows = $data['rows'];
		if ( $data['time'] && ! $p['dimension2'] ) { $rows = array_reverse( self::sort_time( $rows ) ); }
		$drill = ! $data['time'];
		GOAC_UI::card_open( 'Tabela', '<span class="goac-muted">' . count( $rows ) . ' linhas · ordene clicando no cabeçalho</span><input type="search" class="goac-search" placeholder="Filtrar linhas" data-goac-table-search="goac-report-table" aria-label="Filtrar linhas">' );
		if ( ! $rows ) { GOAC_UI::empty_state( 'Nenhuma linha para este período e filtro.' ); GOAC_UI::card_close(); return; }
		echo '<div class="goac-table-wrap goac-table-tall"><table class="widefat goac-table goac-sortable goac-sticky" id="goac-report-table"><thead><tr>';
		foreach ( $dims as $k ) { echo '<th scope="col" data-sort-type="text" tabindex="0">' . esc_html( self::dimension( $k )[1] ) . '</th>'; }
		foreach ( $cols as $col ) { echo '<th scope="col" class="num" data-sort-type="num" tabindex="0">' . esc_html( $col[1] ) . '</th>'; }
		echo '</tr><tr class="goac-summary-row"><th scope="row"' . ( count( $dims ) > 1 ? ' colspan="2"' : '' ) . '>Total</th>';
		$t = $data['totals'];
		foreach ( $cols as $col ) {
			if ( 'share' === $col[0] ) { echo '<td class="num">100%</td>'; continue; }
			if ( 'delta' === $col[0] ) { echo '<td class="num">' . ( $data['prev'] ? GOAC_UI::delta( GOAC_Stats::delta( $t['earnings'], $data['prev']['totals']['earnings'] ) ) : '' ) . '</td>'; continue; } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			if ( 'delta_rpm' === $col[0] || 'delta_pv' === $col[0] ) { $k = 'delta_rpm' === $col[0] ? 'page_rpm' : 'page_views'; echo '<td class="num">' . GOAC_UI::delta( GOAC_Stats::delta( $t[ $k ], $data['prev']['totals'][ $k ] ) ) . '</td>'; continue; } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			echo '<td class="num"><strong>' . $fmt( $col[2], $t[ $col[0] ] ?? null ) . '</strong></td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		echo '</tr><tr class="goac-summary-row is-avg"><th scope="row"' . ( count( $dims ) > 1 ? ' colspan="2"' : '' ) . '>Média por linha</th>';
		$n = max( 1, count( $rows ) );
		foreach ( $cols as $col ) {
			if ( in_array( $col[0], array( 'earnings', 'page_views', 'impressions', 'clicks', 'ad_requests', 'matched_requests' ), true ) ) { echo '<td class="num">' . $fmt( $col[2], (float) ( $t[ $col[0] ] ?? 0 ) / $n ) . '</td>'; } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			elseif ( 'share' === $col[0] ) { echo '<td class="num">' . esc_html( GOAC_UI::pct( 1 / $n ) ) . '</td>'; }
			else { echo '<td></td>'; }
		}
		echo '</tr></thead><tbody>';
		foreach ( $rows as $i => $row ) {
			echo '<tr>';
			foreach ( $row['dims'] as $j => $value ) {
				$key = $dims[ $j ];
				$label = self::dim_label( $key, $value );
				$cell = esc_html( $label );
				if ( 'page' === $key && preg_match( '#^https?://#i', $value ) ) {
					$cell = '<a href="' . esc_url( $value ) . '" target="_blank" rel="noopener noreferrer" class="goac-ext" title="Abrir página">↗</a> ' . esc_html( preg_replace( '#^https?://#i', '', $value ) );
				}
				if ( $drill && 0 === $j && '' !== $value ) {
					$href = GOAC_UI::url( 'reports', array( 'preset' => $p['range']['preset'], 'from' => $p['range']['start'], 'to' => $p['range']['end'], 'include_today' => $p['include_today'] ? 1 : 0, 'dimension' => 'date', 'filter_dim' => $key, 'filter_op' => 'eq', 'filter_value' => $value, 'compare' => $p['compare'] ? 1 : 0 ) );
					$cell .= ' <a class="goac-drill" href="' . esc_url( $href ) . '" title="' . esc_attr( 'Ver dia a dia de ' . $label ) . '">dia a dia</a>';
				}
				echo '<td data-sort="' . esc_attr( $data['time'] && 0 === $j ? $value : mb_strtolower( $label ) ) . '" class="goac-dim-cell">' . $cell . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			}
			$prev_row = null;
			if ( $data['prev'] ) {
				$prev_row = $data['time'] && ! $p['dimension2'] ? ( $data['prev']['by_index'][ count( $rows ) - 1 - $i ] ?? null ) : ( $data['prev']['map'][ implode( '|', $row['dims'] ) ] ?? null );
			}
			foreach ( $cols as $col ) {
				switch ( $col[0] ) {
					case 'share': $v = $row['earnings'] / $total; echo '<td class="num goac-cell-bar" data-sort="' . esc_attr( (string) $v ) . '">' . GOAC_UI::bar( $v ) . '<span>' . esc_html( GOAC_UI::pct( $v ) ) . '</span></td>'; break; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
					case 'delta': $v = $prev_row ? GOAC_Stats::delta( $row['earnings'], $prev_row['earnings'] ) : null; echo '<td class="num" data-sort="' . esc_attr( null === $v ? '' : (string) $v ) . '">' . ( $prev_row ? GOAC_UI::delta( $v ) : '<span class="goac-pill">novo</span>' ) . '</td>'; break; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
					case 'delta_rpm': case 'delta_pv':
						$k = 'delta_rpm' === $col[0] ? 'page_rpm' : 'page_views';
						$v = $prev_row ? GOAC_Stats::delta( $row[ $k ], $prev_row[ $k ] ) : null;
						echo '<td class="num" data-sort="' . esc_attr( null === $v ? '' : (string) $v ) . '">' . GOAC_UI::delta( $v ) . '</td>'; break; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
					default:
						$v = $row[ $col[0] ] ?? null;
						echo '<td class="num" data-sort="' . esc_attr( null === $v ? '' : (string) round( (float) $v, 6 ) ) . '">' . $fmt( $col[2], $v ) . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
				}
			}
			echo '</tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	public static function export( array $p ) {
		$data = self::dataset( $p );
		if ( is_wp_error( $data ) ) { wp_die( esc_html( $data->get_error_message() ) ); }
		$dims = array( $p['dimension'] ); if ( $p['dimension2'] ) { $dims[] = $p['dimension2']; }
		$header = array();
		foreach ( $dims as $k ) { $header[] = self::dimension( $k )[1]; }
		$cur = GOAC_UI::currency_code();
		$header = array_merge( $header, array( 'Receita (' . $cur . ')', '% da receita', 'Page views', 'Impressões', 'Cliques', 'Solicitações', 'Solicitações correspondidas', 'CTR (%)', 'CPC (' . $cur . ')', 'Page RPM (' . $cur . ')', 'RPM de impressão (' . $cur . ')', 'Cobertura (%)', 'Active View (%)', 'Mensurabilidade (%)', 'Tempo visível (s)' ) );
		$total = max( 1e-9, (float) $data['totals']['earnings'] );
		$line = static function( array $r, array $dims_values ) use ( $total ) {
			$pct = static function( $v ) { return null === $v ? null : (float) $v * 100; };
			return array_merge( $dims_values, array( (float) $r['earnings'], (float) $r['earnings'] / $total * 100, (int) $r['page_views'], (int) $r['impressions'], (int) $r['clicks'], (int) $r['ad_requests'], (int) $r['matched_requests'], $pct( $r['ctr'] ), $r['cpc'], $r['page_rpm'], $r['impression_rpm'], $pct( $r['coverage'] ), $pct( $r['viewability'] ), $pct( $r['measurability'] ), $r['view_time'] ) );
		};
		$rows = array();
		foreach ( $data['rows'] as $row ) { $rows[] = $line( $row, array_map( array( __CLASS__, 'dim_text' ), $row['dims'] ) ); }
		$rows[] = $line( $data['totals'], array_merge( array( 'TOTAL' ), array_fill( 0, count( $dims ) - 1, '' ) ) );
		GOAC_UI::send_csv( 'adsense-' . $p['dimension'] . ( $p['dimension2'] ? '-' . $p['dimension2'] : '' ) . '-' . $p['range']['start'] . '-a-' . $p['range']['end'] . '-' . strtolower( $cur ) . '.csv', $header, $rows );
	}

	/** HTML do cartão "Onde a receita acontece" da Visão geral (AJAX). */
	public static function top_html( $dimension, $period ) {
		$map = array( 'country' => 'COUNTRY_NAME', 'page' => 'PAGE_URL', 'platform' => 'PLATFORM_TYPE_NAME', 'unit' => 'AD_UNIT_NAME', 'format' => 'AD_FORMAT_NAME', 'traffic' => 'TRAFFIC_SOURCE_NAME' );
		if ( ! isset( $map[ $dimension ] ) ) { $dimension = 'country'; }
		if ( ! in_array( $period, array( 'today', 'yesterday', 'last_7', 'this_month', 'last_30' ), true ) ) { $period = 'this_month'; }
		$range = GOAC_Stats::resolve_range( $period, '', '', GOAC_API::today() );
		$r = GOAC_API::breakdown( array( $map[ $dimension ] ), $range['start'], $range['end'], array( 'limit' => 10, 'orderBy' => array( '-ESTIMATED_EARNINGS' ), 'ttl' => max( 10 * MINUTE_IN_SECONDS, GOAC_API::report_ttl( $range['end'] ) ), 'currency' => GOAC_UI::api_currency() ) );
		if ( is_wp_error( $r ) ) { return '<p class="goac-empty-inline">' . esc_html( 'Não foi possível consultar: ' . $r->get_error_message() ) . '</p>'; }
		if ( ! $r['rows'] ) { return '<p class="goac-empty-inline">Sem dados neste período.</p>'; }
		$total = max( 1e-9, (float) $r['totals']['earnings'] );
		$has_pv = in_array( 'PAGE_VIEWS', $r['metrics'], true );
		$html = '<table class="widefat goac-table goac-table-compact"><thead><tr><th>' . esc_html( self::dimension( $dimension )[1] ) . '</th><th class="num">Receita</th><th class="num">%</th><th class="num">' . ( $has_pv ? 'Page RPM' : 'RPM impr.' ) . '</th><th class="num">CTR</th></tr></thead><tbody>';
		foreach ( $r['rows'] as $row ) {
			$name = self::dim_text( $row['dims'][0] );
			$shown = 'page' === $dimension ? preg_replace( '#^https?://[^/]+#i', '', $name ) : $name;
			$html .= '<tr><td class="goac-dim-cell" title="' . esc_attr( $name ) . '">' . esc_html( '' === $shown ? '/' : $shown ) . '</td><td class="num goac-cell-bar">' . GOAC_UI::bar( $row['earnings'] / $total ) . '<span>' . esc_html( GOAC_UI::money( $row['earnings'] ) ) . '</span></td><td class="num">' . esc_html( GOAC_UI::pct( $row['earnings'] / $total ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $has_pv ? $row['page_rpm'] : $row['impression_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $has_pv ? $row['ctr'] : $row['impression_ctr'], 2 ) ) . '</td></tr>';
		}
		$href = GOAC_UI::url( 'reports', array( 'preset' => $period, 'include_today' => 1, 'dimension' => $dimension, 'limit' => 100 ) );
		return $html . '</tbody></table><p class="goac-footnote">' . esc_html( GOAC_UI::range_label( $range['start'], $range['end'] ) . ' · total ' . GOAC_UI::money( $total ) ) . ' · <a href="' . esc_url( $href ) . '">ver todos</a></p>';
	}
}
