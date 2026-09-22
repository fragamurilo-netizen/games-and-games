<?php
/**
 * Decision dashboard.
 *
 * Server-side financial observations and fixed manual delivery policy. Actual
 * per-page geometry and gate reasons belong to the runtime inspector; this
 * dashboard does not observe every visitor or attribute revenue to a DOM event.
 *
 * Administrator-only. It is the single surface where real account numbers are
 * shown; the public runtime never receives them.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function go_verge_ads_dashboard_menu() {
	$parent = menu_page_url( 'goac', false ) ? 'goac' : 'tools.php';
	add_submenu_page(
		$parent,
		__( 'Motor de receita', 'go-verge' ),
		__( 'Motor de receita', 'go-verge' ),
		'manage_options',
		'go-revenue-engine',
		'go_verge_ads_dashboard_render'
	);
}
add_action( 'admin_menu', 'go_verge_ads_dashboard_menu', 60 );

/** @return string */
function go_verge_ads_dashboard_money( $value, $decimals = 2 ) {
	return null === $value ? '—' : number_format_i18n( (float) $value, $decimals );
}

/** One metric tile. */
function go_verge_ads_dashboard_tile( $label, $value, $note = '' ) {
	printf(
		'<div style="padding:12px 14px;border:1px solid #dcdcde;border-radius:10px;background:#fff"><small style="display:block;color:#646970;margin-bottom:4px">%s</small><strong style="font-size:20px;line-height:1.2">%s</strong>%s</div>',
		esc_html( $label ),
		esc_html( $value ),
		'' === $note ? '' : '<small style="display:block;color:#646970;margin-top:4px">' . esc_html( $note ) . '</small>'
	);
}

function go_verge_ads_dashboard_render() {
	if ( ! current_user_can( 'manage_options' ) ) {
		wp_die( esc_html__( 'Sem permissão.', 'go-verge' ) );
	}

	if ( isset( $_GET['go_refresh'] ) && check_admin_referer( 'go_revenue_engine_refresh' ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		delete_transient( GO_VERGE_ADS_YIELD_SIGNAL_TRANSIENT );
		delete_transient( GO_VERGE_ADS_ECON_DAY_TRANSIENT );
		delete_transient( GO_VERGE_ADS_ECON_SLOT_TRANSIENT );
		delete_transient( GO_VERGE_ADS_ECON_CURVE_TRANSIENT );
	}

	$explain  = go_verge_ads_yield_explain();
	$decision = (array) ( $explain['decision'] ?? array() );
	$day      = (array) ( $explain['day'] ?? array() );
	$today    = (array) ( $day['day'] ?? array() );
	$window   = is_array( $day['window'] ?? null ) ? $day['window'] : null;
	$peers    = is_array( $day['peers'] ?? null ) ? $day['peers'] : null;
	$forecast = is_array( $day['projection'] ?? null ) ? $day['projection'] : null;
	$frontier = (array) ( $explain['frontier'] ?? array() );
	$econ     = (array) ( $explain['economics'] ?? array() );

	$regime_labels = array(
		'harvest'           => __( 'Valor estimado acima da referência', 'go-verge' ),
		'supply_deficit'    => __( 'Entrega abaixo da referência com preenchimento utilizável', 'go-verge' ),
		'balanced'          => __( 'Valor estimado dentro da referência', 'go-verge' ),
		'price_compression' => __( 'Valor estimado baixo; inventário base preservado', 'go-verge' ),
		'coverage_stress'   => __( 'Cobertura baixa; revisar elegibilidade e preenchimento', 'go-verge' ),
		'demand_collapse'   => __( 'Valor estimado muito baixo; inventário base preservado', 'go-verge' ),
		'unknown'           => __( 'Sem sinal financeiro utilizável', 'go-verge' ),
	);
	$regime = (string) ( $decision['regime'] ?? 'unknown' );

	echo '<div class="wrap"><h1>' . esc_html__( 'Motor de receita', 'go-verge' ) . '</h1>';
	echo '<p style="max-width:70ch;color:#50575e">' . esc_html( 'Arquitetura manual: o tema planeja as posições e cada unidade é solicitada uma vez conforme consentimento, dimensões, proximidade e leitura. O loader também atende âncora e vinheta oficiais. Os controles da conta precisam corresponder a essa configuração. O ritmo e a expansão seguem uma política fixa, sem subir ou descer com o RPM acumulado. O histórico por unidade ajuda a ordenar oportunidades simultâneas; não define lances nem preço mínimo.' ) . '</p>';

	echo '<p><a class="button" href="' . esc_url( wp_nonce_url( add_query_arg( 'go_refresh', '1' ), 'go_revenue_engine_refresh' ) ) . '">'
		. esc_html__( 'Recalcular agora', 'go-verge' ) . '</a></p>';

	/* ---------------------------------------------------------------- Agora */
	echo '<h2>' . esc_html__( 'Acumulado estimado do dia', 'go-verge' ) . '</h2>';
	echo '<p>' . esc_html__( 'Os números refletem a última consulta disponível. A receita pode ser revisada ou chegar em momento diferente das impressões. Recalcular atualiza a análise local; não acelera o processamento do AdSense.', 'go-verge' ) . '</p>';
	echo '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px;margin-bottom:22px">';
	go_verge_ads_dashboard_tile( __( 'Receita do dia', 'go-verge' ), go_verge_ads_dashboard_money( $today['earnings'] ?? null ) );
	go_verge_ads_dashboard_tile( __( 'Page RPM', 'go-verge' ), go_verge_ads_dashboard_money( $today['page_rpm'] ?? null ) );
	go_verge_ads_dashboard_tile( __( 'Impression RPM', 'go-verge' ), go_verge_ads_dashboard_money( $today['impression_rpm'] ?? null, 3 ) );
	go_verge_ads_dashboard_tile(
		__( 'Impressões / PV', 'go-verge' ),
		go_verge_ads_dashboard_money( $today['impressions_pv'] ?? null ),
		/* Health reference, not a per-page quota. `target_impressions_pv` never
		 * existed on the frontier array, so this tile silently printed "—" for
		 * the whole 4.x line. */
		sprintf( __( 'referência de saúde %s', 'go-verge' ), go_verge_ads_dashboard_money( $frontier['delivery_reference_pv'] ?? null ) )
	);
	go_verge_ads_dashboard_tile( __( 'Pageviews', 'go-verge' ), go_verge_ads_dashboard_money( $today['page_views'] ?? null, 0 ) );
	go_verge_ads_dashboard_tile( __( 'Impressões', 'go-verge' ), go_verge_ads_dashboard_money( $today['impressions'] ?? null, 0 ) );
	go_verge_ads_dashboard_tile(
		__( 'CTR', 'go-verge' ),
		( ( $today['impressions'] ?? 0 ) > 0 ) ? go_verge_ads_dashboard_money( (float) $today['clicks'] / (float) $today['impressions'] * 100, 2 ) . '%' : '—'
	);
	go_verge_ads_dashboard_tile(
		__( 'Cobertura (7 dias)', 'go-verge' ),
		null === ( $econ['coverage_site'] ?? null ) ? '—' : go_verge_ads_dashboard_money( (float) $econ['coverage_site'] * 100, 1 ) . '%'
	);
	echo '</div>';

	/* ---------------------------------------------------------------- Headroom */
	$headroom = $explain['page_rpm_headroom'] ?? null;
	if ( null !== $headroom ) {
		$positive = (float) $headroom > 0;
		printf(
			'<div style="padding:14px 16px;border-left:4px solid %s;background:#fff;border:1px solid #dcdcde;border-left-width:4px;border-radius:8px;margin-bottom:22px;max-width:80ch"><strong>%s</strong><br><span style="color:#50575e">%s</span></div>',
			$positive ? '#d63638' : '#00a32a',
			esc_html(
				$positive
					? sprintf( __( 'Sensibilidade à referência de entrega: diferença de US$ %s de Page RPM.', 'go-verge' ), go_verge_ads_dashboard_money( $headroom ) )
					: __( 'Impressões por página na referência histórica ou acima dela.', 'go-verge' )
			),
			esc_html__( 'Cálculo hipotético: diferença de impressões por página multiplicada pelo RPM de impressão atual. Não mede inventário elegível nem receita recuperável; novas impressões podem ter outro valor. A referência não é uma cota por página.', 'go-verge' )
		);
	}

	/* --------------------------------------------------------- Financial analysis */
	echo '<h2>' . esc_html__( 'Diagnóstico econômico', 'go-verge' ) . '</h2>';
	echo '<p style="max-width:80ch">' . esc_html__( 'As classificações abaixo descrevem estimativas do relatório e não alteram a entrega manual. A política ativa usa geometria, latência, proximidade e leitura; os antigos coeficientes ficam apenas na análise compatível com o histórico.', 'go-verge' ) . '</p>';
	echo '<table class="widefat striped" style="max-width:900px"><tbody>';
	printf(
		'<tr><th style="width:230px">%s</th><td><strong>%s</strong></td></tr>',
		esc_html__( 'Regime', 'go-verge' ),
		esc_html( $regime_labels[ $regime ] ?? $regime )
	);
	printf(
		'<tr><th>%s</th><td>%s</td></tr>',
		esc_html__( 'Confiança', 'go-verge' ),
		esc_html( (string) ( $decision['confidence'] ?? 'none' ) . ( empty( $decision['fresh'] ) ? ' · consulta atrasada' : ' · consulta recente; receita ainda estimada' ) )
	);
	printf(
		'<tr><th>%s</th><td>%d %s</td></tr>',
		esc_html__( 'Índice analítico legado', 'go-verge' ),
		absint( $decision['supply_bias'] ?? 0 ),
		esc_html__( 'na escala de 0 a 2; não controla ritmo, antecipação ou quantidade de anúncios', 'go-verge' )
	);
	printf(
		'<tr><th>%s</th><td>%s</td></tr>',
		esc_html__( 'Escala do piso analítico (somente relatório)', 'go-verge' ),
		esc_html( go_verge_ads_dashboard_money( $decision['floor_scale'] ?? 1, 2 ) )
	);
	$reasons = (array) ( $decision['reasons'] ?? array() );
	printf(
		'<tr><th>%s</th><td>%s</td></tr>',
		esc_html__( 'Motivos', 'go-verge' ),
		$reasons ? '<code>' . implode( '</code> <code>', array_map( 'esc_html', $reasons ) ) . '</code>' : '&mdash;'
	);
	echo '</tbody></table>';

	/* ---------------------------------------------------------------- Evidência */
	echo '<h2>' . esc_html__( 'Evidência', 'go-verge' ) . '</h2>';
	echo '<p style="max-width:80ch">' . esc_html__( 'A janela abaixo é a diferença entre estimativas reportadas em cerca de 60 minutos. Ela não identifica a hora de cada leilão. O RPM acumulado pode cair quando o novo intervalo tem RPM menor, mesmo que a receita total continue aumentando. Compare também receita e volume do intervalo.', 'go-verge' ) . '</p>';
	echo '<table class="widefat striped" style="max-width:900px"><thead><tr><th>' . esc_html__( 'Sinal', 'go-verge' ) . '</th><th>' . esc_html__( 'Valor', 'go-verge' ) . '</th></tr></thead><tbody>';
	$interval_status = ! $window ? __( 'sem intervalo disponível', 'go-verge' ) : ( ! empty( $window['revised'] ) ? __( 'revisão de métricas; sinal de preço suspenso', 'go-verge' ) : ( ! empty( $window['price_signal_usable'] ) ? __( 'diferença reportada com volume; sujeita a defasagem', 'go-verge' ) : __( 'volume insuficiente; sem RPM do intervalo', 'go-verge' ) ) );
	printf( '<tr><td>%s</td><td>%s</td></tr>', esc_html__( 'Estado do intervalo', 'go-verge' ), esc_html( $interval_status ) );
	foreach ( array(
		array( __( 'Receita acrescentada ou revisada no intervalo', 'go-verge' ), $window['earnings'] ?? null, 2 ),
		array( __( 'Variação de pageviews no intervalo', 'go-verge' ), $window['page_views_delta'] ?? $window['page_views'] ?? null, 0 ),
		array( __( 'Variação de impressões no intervalo', 'go-verge' ), $window['impressions_delta'] ?? $window['impressions'] ?? null, 0 ),
		array( __( 'Page RPM do intervalo', 'go-verge' ), $window['page_rpm'] ?? null, 3 ),
	) as $metric ) {
		printf( '<tr><td>%s</td><td>%s</td></tr>', esc_html( $metric[0] ), esc_html( go_verge_ads_dashboard_money( $metric[1], $metric[2] ) ) );
	}
	printf(
		'<tr><td>%s</td><td>%s</td></tr>',
		esc_html__( 'RPM de impressão do intervalo', 'go-verge' ),
		esc_html( $window ? go_verge_ads_dashboard_money( $window['impression_rpm'], 3 ) : __( 'sem amostra utilizável', 'go-verge' ) )
	);
	printf(
		'<tr><td>%s</td><td>%s</td></tr>',
		esc_html__( 'Janela marginal: impressões/PV', 'go-verge' ),
		esc_html( $window ? go_verge_ads_dashboard_money( $window['impressions_pv'] ) : '—' )
	);
	printf(
		'<tr><td>%s</td><td>%s</td></tr>',
		esc_html__( 'Pares no mesmo horário (mediana / P25 / P75)', 'go-verge' ),
		esc_html(
			$peers
				? sprintf(
					'%s / %s / %s (%d dias)',
					go_verge_ads_dashboard_money( $peers['impression_rpm'], 3 ),
					go_verge_ads_dashboard_money( $peers['impression_rpm_p25'], 3 ),
					go_verge_ads_dashboard_money( $peers['impression_rpm_p75'], 3 ),
					absint( $peers['count'] )
				)
				: __( 'histórico insuficiente', 'go-verge' )
		)
	);
	printf(
		'<tr><td>%s</td><td>%s</td></tr>',
		esc_html__( 'Atraso do último snapshot', 'go-verge' ),
		esc_html( null === ( $day['freshness_min'] ?? null ) ? '—' : absint( $day['freshness_min'] ) . ' min' )
	);
	printf(
		'<tr><td>%s</td><td>%s</td></tr>',
		esc_html__( 'Projeção de fechamento (curva do próprio dia da semana)', 'go-verge' ),
		esc_html(
			$forecast
				? sprintf(
					__( 'Page RPM %s · receita %s · %s%% do dia percorrido · confiança %s', 'go-verge' ),
					go_verge_ads_dashboard_money( $forecast['page_rpm'] ?? null ),
					go_verge_ads_dashboard_money( $forecast['earnings'] ?? null ),
					go_verge_ads_dashboard_money( (float) ( $forecast['share_pv'] ?? 0 ) * 100, 0 ),
					(string) ( $forecast['confidence'] ?? '—' )
				)
				: __( 'curva ainda em aprendizado', 'go-verge' )
		)
	);
	echo '</tbody></table>';

	/* ---------------------------------------------------------------- Slots */
	$slots = (array) ( $econ['slots'] ?? array() );
	echo '<h2>' . esc_html__( 'Valor relativo por bloco (7 dias)', 'go-verge' ) . '</h2>';
	if ( ! $slots ) {
		echo '<p>' . esc_html__( 'O Data Lab ainda não tem uma amostra utilizável por bloco. O inventário base continua dependendo de estrutura, consentimento e leitura. Nenhum piso analítico bloqueia anúncios.', 'go-verge' ) . '</p>';
	} else {
		$names = function_exists( 'go_verge_ads_all_slots' ) ? go_verge_ads_all_slots() : array();
		/* Tier per slot already exists, variants included; never rebuild it here. */
		$tiers = function_exists( 'go_verge_ads_econ_slot_tiers' ) ? go_verge_ads_econ_slot_tiers() : array();
		arsort( $slots );
		$floor = (float) ( $econ['floor'] ?? 0 ) * (float) ( $decision['floor_scale'] ?? 1 );
		echo '<p style="color:#50575e;max-width:80ch">'
			. esc_html__( 'Valor relativo a uma oportunidade mediana deste site, medido em receita por request e encolhido para o prior do tier quando a amostra é pequena. 1,00 = oportunidade mediana. No navegador este número decide a ORDEM em que posições simultaneamente elegíveis pedem ao Google — nunca se uma posição segura pode existir, nunca o lance e nunca o criativo. A coluna de piso abaixo é uma leitura de diagnóstico desta tela: nenhuma impressão é retida por ela.', 'go-verge' )
			. '</p>';
		echo '<table class="widefat striped" style="max-width:1000px"><thead><tr>'
			. '<th>' . esc_html__( 'Bloco', 'go-verge' ) . '</th>'
			. '<th>' . esc_html__( 'Slot', 'go-verge' ) . '</th>'
			. '<th>' . esc_html__( 'Tier', 'go-verge' ) . '</th>'
			. '<th>' . esc_html__( 'Valor relativo', 'go-verge' ) . '</th>'
			. '<th>' . esc_html__( 'Cobertura', 'go-verge' ) . '</th>'
			. '<th>' . esc_html__( 'Posição vs. piso analítico', 'go-verge' ) . '</th>'
			. '</tr></thead><tbody>';
		foreach ( $slots as $slot => $value ) {
			$absolute = (float) ( ( $econ['coverage_abs'] ?? array() )[ $slot ] ?? 0 );
			$needed = ( $value > 0 && $floor > 0 ) ? min( 1.0, $floor / $value ) : 0.0;
			printf(
				'<tr><td>%s</td><td><code>%s</code></td><td>%s</td><td><strong>%s</strong></td><td>%s</td><td>%s</td></tr>',
				esc_html( $names[ $slot ] ?? '—' ),
				esc_html( (string) $slot ),
				esc_html( $tiers[ $slot ] ?? '—' ),
				esc_html( go_verge_ads_dashboard_money( $value, 2 ) ),
				esc_html( $absolute > 0 ? go_verge_ads_dashboard_money( $absolute * 100, 1 ) . '%' : '—' ),
				esc_html(
					isset( ( $econ['quality_risk'] ?? array() )[ $slot ] )
						? __( 'CTR anômalo sem receita correspondente — revise a posição', 'go-verge' )
						: ( ( $floor > 0 && $value > 0 )
							? ( $value >= $floor ? __( 'acima do piso', 'go-verge' ) : __( 'abaixo do piso — candidato a revisão editorial', 'go-verge' ) )
							: __( 'sem piso calculado', 'go-verge' ) )
				)
			);
		}
		echo '</tbody></table>';
		echo '<p style="color:#50575e;max-width:80ch">'
			. esc_html__( 'O padrão das posições do corpo é Display responsivo. Confirme os IDs e tipos na conta quando houver configuração personalizada. Diferenças de valor também dependem de público, dispositivo, página, posição e exposição. Esta tabela usa médias históricas com ajuste para amostras pequenas; não mede o ganho causal de adicionar ou remover uma unidade. Comparar formatos em posições diferentes não demonstra que trocar o formato aumentará a receita.', 'go-verge' )
			. '</p>';
	}

	echo '<h2>' . esc_html__( 'Escada estrutural do artigo', 'go-verge' ) . '</h2>';
	echo '<p style="color:#50575e;max-width:80ch">'
		. esc_html__( 'A tabela é a capacidade inicial por comprimento e formato. A estrutura real pode reduzir esse número. Reservas válidas podem entrar quando alcançadas pelo leitor, após as condições de geometria, consentimento, ritmo e densidade. Quantidade planejada, pedido, preenchimento e receita são etapas distintas.', 'go-verge' )
		. '</p>';
	echo '<table class="widefat striped" style="max-width:720px"><thead><tr>'
		. '<th>' . esc_html__( 'Palavras do corpo', 'go-verge' ) . '</th>'
		. '<th>' . esc_html__( 'Notícia', 'go-verge' ) . '</th>'
		. '<th>' . esc_html__( 'Guia / ranking / lista', 'go-verge' ) . '</th>'
		. '</tr></thead><tbody>';
	$ladder_rows = array( 239, 279, 399, 549, 679, 899, 1199, 999999 );
	$previous = 0;
	foreach ( $ladder_rows as $max_words ) {
		printf(
			'<tr><td>%s</td><td>%d</td><td>%d</td></tr>',
			esc_html( $previous . '–' . ( $max_words >= 999999 ? '∞' : $max_words ) ),
			absint( go_verge_ads_planner_capacity_from_words( $max_words, 'news' ) ),
			absint( go_verge_ads_planner_capacity_from_words( $max_words, 'guide' ) )
		);
		$previous = $max_words + 1;
	}
	echo '</tbody></table>';
	echo '<p style="color:#50575e;max-width:80ch">'
		. esc_html__( 'Ver a decisão de uma pageview real: abra qualquer matéria logado como administrador e use "Anúncios: diagnóstico" na barra superior. O inspetor mostra o estado do governador, o budget do corpo, a distância de cada slot até a viewport e o motivo de cada recusa.', 'go-verge' )
		. '</p>';

	echo '</div>';
}
