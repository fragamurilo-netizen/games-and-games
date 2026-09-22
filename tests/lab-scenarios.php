<?php
/**
 * Operational scenarios.
 *
 * Included by tests/lab.php. Every row runs the REAL decision authority
 * against injected AdSense Center state, so what prints is what the engine
 * would actually do — not a description of what it is supposed to do.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	exit;
}

/**
 * Run one scenario through the decision authority.
 *
 * @param array<string,mixed> $goac Injected AdSense Center state.
 * @return array<string,mixed>
 */
function go_lab_scenario( array $goac ) {
	go_test_flush_transients();
	$GLOBALS['go_test_goac'] = array_merge(
		array( 'connected' => true, 'today' => '2026-09-20', 'intraday' => array(), 'unit_rows' => array() ),
		$goac
	);
	return go_verge_ads_yield_decision( true );
}

/** Seven days of per-unit economics with healthy match rates. */
function go_lab_healthy_units() {
	return go_test_unit_rows(
		array(
			'7792311754' => array( 'request_rpm' => 0.58, 'requests' => 40000, 'coverage' => 0.93 ),
			'3572313419' => array( 'request_rpm' => 0.52, 'requests' => 38000, 'coverage' => 0.90 ),
			'5017324239' => array( 'request_rpm' => 0.47, 'requests' => 30000, 'coverage' => 0.88 ),
			'5223365459' => array( 'request_rpm' => 0.43, 'requests' => 26000, 'coverage' => 0.87 ),
			'6368539121' => array( 'request_rpm' => 0.39, 'requests' => 22000, 'coverage' => 0.86 ),
			'7554015324' => array( 'request_rpm' => 0.34, 'requests' => 18000, 'coverage' => 0.85 ),
			'6240933652' => array( 'request_rpm' => 0.28, 'requests' => 14000, 'coverage' => 0.84 ),
			'6568236715' => array( 'request_rpm' => 0.24, 'requests' => 11000, 'coverage' => 0.84 ),
			'8238832024' => array( 'request_rpm' => 0.19, 'requests' => 8000,  'coverage' => 0.83 ),
			'5255155049' => array( 'request_rpm' => 0.16, 'requests' => 6000,  'coverage' => 0.82 ),
			'5798080525' => array( 'request_rpm' => 0.31, 'requests' => 9000,  'coverage' => 0.84 ),
		)
	);
}

/** The same inventory, with Google declining most requests. */
function go_lab_broken_coverage_units() {
	return go_test_unit_rows(
		array(
			'7792311754' => array( 'request_rpm' => 0.30, 'requests' => 40000, 'coverage' => 0.49 ),
			'3572313419' => array( 'request_rpm' => 0.27, 'requests' => 38000, 'coverage' => 0.45 ),
			'5017324239' => array( 'request_rpm' => 0.24, 'requests' => 30000, 'coverage' => 0.42 ),
			'5223365459' => array( 'request_rpm' => 0.21, 'requests' => 26000, 'coverage' => 0.39 ),
			'6368539121' => array( 'request_rpm' => 0.18, 'requests' => 22000, 'coverage' => 0.36 ),
			'7554015324' => array( 'request_rpm' => 0.15, 'requests' => 18000, 'coverage' => 0.33 ),
		)
	);
}

/** @return array<int,array{0:string,1:array<string,mixed>,2:string}> */
function go_lab_scenario_list() {
	$healthy = go_lab_healthy_units();
	$broken  = go_lab_broken_coverage_units();
	$weekend = go_test_history( 8, 1200, 7.4, 0.55 );

	return array(
		array(
			'Domingo 07h, sem historico (instalacao nova)',
			array( 'connected' => false ),
			'Sem evidencia: apoia-se no historico conhecido e abre +1. Nenhum piso segura inventario.',
		),
		array(
			'Domingo 09h, conectado, dia ainda pequeno',
			array( 'intraday' => array( '2026-09-20' => go_test_day( 900, 5.1, 0.50, 540 ) ), 'unit_rows' => $healthy ),
			'Amostra curta: decide pelo acumulado do dia, sem ficar seletivo.',
		),
		array(
			'Domingo 15h, preco normal, entrega curta',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 5.2, 0.52 ) ) ), 'unit_rows' => $healthy ),
			'O caso do 18/09: exige mais imp/PV do que esta entregando e empurra ao maximo.',
		),
		array(
			'Domingo 15h, impressao barata (0,38)',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 5.4, 0.38 ) ) ), 'unit_rows' => $healthy ),
			'Barato exige MAIS volume, nao menos. O piso cai para nao segurar nada.',
		),
		array(
			'Domingo 11h, leilao quente (0,92)',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 6.1, 0.92 ) ) ), 'unit_rows' => $healthy ),
			'Cada oportunidade vale mais: antecipa a cauda em vez de esperar o leitor.',
		),
		array(
			'Domingo 22h, preco caindo, entrega em dia',
			array( 'intraday' => array_merge( go_test_history( 8, 1200, 7.6, 0.78 ), array( '2026-09-20' => go_test_day( 1200, 7.8, 0.60 ) ) ), 'unit_rows' => $healthy ),
			'Unico estado em que ser seletivo ajuda: nao ha lacuna de entrega para fechar.',
		),
		array(
			'Domingo, pico do Discover (trafego 3x)',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 3600, 5.0, 0.44 ) ) ), 'unit_rows' => $healthy ),
			'Volume de trafego nao muda a regra: a lacuna de entrega continua mandando.',
		),
		array(
			'Domingo, cobertura quebrada (match abaixo de 50%)',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 4.8, 0.50 ) ) ), 'unit_rows' => $broken ),
			'Mais volume e a unica resposta que nao funciona aqui. Nao inunda.',
		),
		array(
			'Domingo, snapshot travado as 06h',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 5.0, 0.51, 360 ) ) ), 'unit_rows' => $healthy ),
			'Dado velho reduz seletividade, nao oferta.',
		),
		array(
			'Domingo, leilao morto (0,11)',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 6.0, 0.11 ) ) ), 'unit_rows' => $healthy ),
			'Abaixo da viabilidade: segura a fronteira em vez de gastar leitura a toa.',
		),
		array(
			'Domingo, tudo em dia (0,62 e 7,6 imp/PV)',
			array( 'intraday' => array_merge( $weekend, array( '2026-09-20' => go_test_day( 1200, 7.6, 0.62 ) ) ), 'unit_rows' => $healthy ),
			'Preco acima da banda dos pares: mesmo entregando bem, uma hora cara merece mais uma.',
		),
		array(
			'Segunda, preco medio e entrega curta',
			array( 'intraday' => array_merge( go_test_history( 8, 1400, 7.5, 0.58 ), array( '2026-09-20' => go_test_day( 1400, 5.5, 0.56 ) ) ), 'unit_rows' => $healthy ),
			'Mesma logica; o que muda e a banda de pares do dia da semana.',
		),
	);
}

/** Print the scenario table. */
function go_lab_print_scenarios() {
	echo PHP_EOL . PHP_EOL . '10. CENARIOS OPERACIONAIS' . PHP_EOL;
	go_lab_rule();
	echo 'Cada linha roda a autoridade de decisao real contra dados injetados: o que o motor faz,' . PHP_EOL;
	echo 'e por que, em cada situacao que um domingo pode apresentar.' . PHP_EOL . PHP_EOL;
	printf( "%-50s %-18s %-6s %-7s %-8s%s", 'CENARIO', 'REGIME', 'VIES', 'PISO', 'PRECISA', PHP_EOL );
	go_lab_rule();

	foreach ( go_lab_scenario_list() as $scenario ) {
		list( $label, $goac, $note ) = $scenario;
		$decision = go_lab_scenario( $goac );
		$econ     = go_verge_ads_econ_slot_economics();
		$floor    = go_verge_ads_econ_clamp( (float) ( $econ['floor'] ?? 0 ) * (float) $decision['floor_scale'], 0.0, 0.50 );
		printf(
			"%-50s %-18s %-6s %-7s %-8s%s",
			$label,
			(string) $decision['regime'],
			'+' . (int) $decision['supply_bias'],
			go_lab_money( $floor, 2 ),
			null === $decision['required_impressions_pv'] ? '  -' : go_lab_money( (float) $decision['required_impressions_pv'], 1 ),
			PHP_EOL
		);
		printf( "    %s%s", $note, PHP_EOL );
	}
	go_lab_rule();
	echo 'PISO = valor marginal minimo exigido de um bloco nao-premium. 0,00 = nada e segurado.' . PHP_EOL;
	echo 'Reach e premium (Top Scroll, Masthead, Hero, Prime, A1, A2) nunca tem piso, em regime nenhum.' . PHP_EOL;
}
