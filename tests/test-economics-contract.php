<?php
/** Server economics: real AdSense data -> regime, and the planner contract it must NOT touch. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/economics.php';
require_once GO_VERGE_DIR . '/inc/ads/yield.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

function rg_units() {
	return go_test_unit_rows(
		array(
			'7792311754' => array( 'request_rpm' => 0.62, 'requests' => 40000, 'coverage' => 0.91 ),
			'3572313419' => array( 'request_rpm' => 0.55, 'requests' => 38000, 'coverage' => 0.92 ),
			'5017324239' => array( 'request_rpm' => 0.49, 'requests' => 30000, 'coverage' => 0.90 ),
			'5223365459' => array( 'request_rpm' => 0.44, 'requests' => 26000, 'coverage' => 0.89 ),
			'6368539121' => array( 'request_rpm' => 0.40, 'requests' => 22000, 'coverage' => 0.88 ),
			'7554015324' => array( 'request_rpm' => 0.34, 'requests' => 18000, 'coverage' => 0.87 ),
			'6240933652' => array( 'request_rpm' => 0.27, 'requests' => 14000, 'coverage' => 0.86 ),
			'6568236715' => array( 'request_rpm' => 0.23, 'requests' => 11000, 'coverage' => 0.86 ),
			'8238832024' => array( 'request_rpm' => 0.17, 'requests' => 8000,  'coverage' => 0.85 ),
			'5255155049' => array( 'request_rpm' => 0.14, 'requests' => 6000,  'coverage' => 0.84 ),
			'5798080525' => array( 'request_rpm' => 0.31, 'requests' => 9000,  'coverage' => 0.88 ),
		)
	);
}
function rg_article( $target_words ) {
	$html=''; $words=0; $i=0;
	while ( $words < $target_words ) {
		$n = 58 + ($i % 3) * 11;
		$parts=array(); for($j=0;$j<$n;$j++) $parts[]='palavra'.(($i+$j)%37);
		$html .= '<p>'.implode(' ', $parts).'.</p>';
		$words += $n; $i++;
		if ( $i % 3 === 0 && $words < $target_words ) $html .= '<h2>Seção editorial '.$i.'</h2>';
	}
	return $html;
}
function rg_set( $coverage ) {
	go_test_flush_transients();
	$requests = 140000;
	$GLOBALS['go_test_goac'] = array(
		'connected' => true,
		'today' => '2026-09-20',
		'intraday' => array_merge(
			go_test_history( 8, 1200, 7.8, 0.59 ),
			array( '2026-09-20' => go_test_day( 1200, 5.6, 0.43 ) )
		),
		'unit_rows' => rg_units(),
		'daily_rows' => array(
			'2026-09-20' => array(
				'ad_requests' => $requests,
				'matched_requests' => $requests * $coverage,
			),
		),
	);
}

go_test_section( 'Revenue Governor: dinheiro real controla urgência' );
rg_set( .92 );
$high = go_verge_ads_yield_decision( true );
go_test_equals( 'supply_deficit', $high['regime'], 'Déficit real + cobertura saudável = SUPPLY_DEFICIT' );
go_test_equals( 2, (int) $high['supply_bias'], 'Cobertura saudável + forte gap libera urgência máxima' );
go_test_ok( (float) $high['day_coverage'] >= .91, 'Cobertura atual vem do snapshot diário', (string) $high['day_coverage'] );
go_test_ok( (float) $high['revenue_pressure'] >= .20, 'Pressão de receita reconhece Page RPM abaixo da janela de sucesso', (string) $high['revenue_pressure'] );
go_test_ok( in_array( 'revenue-pressure-with-healthy-coverage', $high['reasons'], true ), 'Razão econômica fica auditável' );

rg_set( .55 );
$low = go_verge_ads_yield_decision( true );
go_test_equals( 'coverage_stress', $low['regime'], 'Cobertura atual quebrada vence o déficit' );
go_test_equals( 0, (int) $low['supply_bias'], 'Cobertura quebrada bloqueia expansão cega' );

go_test_section( 'Economia do servidor não decide capacidade da página' );
/*
 * The regime controller reads money. The planner reads structure. They must not
 * be able to reach each other: the same article, cached once, has to produce
 * the same inventory whether the auction is hot or the coverage is broken —
 * otherwise a full-page cache freezes a financial state into HTML for hours.
 */
$article = rg_article( 560 );
rg_set( .92 );
$plan_hot = go_verge_ads_plan_article( $article );
rg_set( .55 );
$plan_stress = go_verge_ads_plan_article( $article );

go_test_equals( (int) $plan_hot['plannedCount'], (int) $plan_stress['plannedCount'], 'Leilão quente e cobertura quebrada planejam o mesmo HTML' );
go_test_equals( (int) $plan_hot['renderedCount'], (int) $plan_stress['renderedCount'], 'O número de hosts renderizados é cache-safe' );
go_test_equals( (int) $plan_hot['totalCapacity'], (int) $plan_stress['totalCapacity'], 'O teto de EXPANSÃO é cache-safe' );
go_test_equals( (int) $plan_hot['headroom'], (int) $plan_stress['headroom'], 'O passo estrutural é cache-safe' );
go_test_ok( (int) $plan_hot['totalCapacity'] <= 7, 'Hard cap 7 permanece' );
go_test_ok( (int) $plan_hot['renderedCount'] > (int) $plan_hot['plannedCount'], 'A matéria média expõe reserva para o governador do navegador', 'planejado=' . $plan_hot['plannedCount'] . ' renderizado=' . $plan_hot['renderedCount'] );

go_test_section( 'O sinal público não carrega mais pisos mortos' );
rg_set( .92 );
go_verge_ads_yield_decision( true );
$signal = go_verge_ads_yield_public_signal();
go_test_ok( ! isset( $signal['floor'] ), 'Piso marginal deixou de ser transmitido ao navegador' );
go_test_ok( ! isset( $signal['tier_floor'] ), 'Tabela de pisos por tier deixou de ser transmitida' );
go_test_equals( array_fill_keys( array( 'reach','premium','standard','deep','completion' ), 1.0 ), $signal['tier_lookahead'], 'Lookahead financeiro tem compatibilidade neutra; latência local rege a entrega' );
go_test_ok( isset( $signal['slot_viewability'] ), 'Active View por bloco continua, porque decide a distância de aquecimento' );
go_test_ok( ! isset( $signal['slot_risk'] ), 'Lista de risco sem consumidor foi removida' );
