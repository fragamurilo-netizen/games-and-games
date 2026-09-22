<?php
/**
 * The account's own August 2026 series.
 *
 * Twenty-six closed days, straight from the AdSense report. This is the only
 * honest yardstick the lab has: not what a model predicts, but what this exact
 * inventory has already delivered.
 *
 * The publisher reports in-page Auto Ads on 13-19/08 only. The other windows
 * are the best available manual+overlay yardstick for this site. They are not
 * a controlled experiment: traffic/device/content mix and demand also changed.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	exit;
}

/**
 * date, earnings, pageviews, page_rpm, impressions, impression_rpm, active_view, auto_ads
 *
 * @return array<int,array<int,mixed>>
 */
function go_lab_august() {
	return array(
		array( '01/08 sab', 11.89, 11618, 1.02,  67516, 0.18, 49.09, false ),
		array( '02/08 dom', 35.16, 22401, 1.57, 136279, 0.26, 47.78, false ),
		array( '03/08 seg', 94.84, 36742, 2.58, 249355, 0.38, 50.72, false ),
		array( '04/08 ter', 74.22, 27727, 2.68, 187631, 0.40, 50.35, false ),
		array( '05/08 qua', 69.71, 21835, 3.19, 158493, 0.44, 51.58, false ),
		array( '06/08 qui', 75.01, 24464, 3.07, 176666, 0.42, 47.99, false ),
		array( '07/08 sex', 79.00, 25068, 3.15, 180488, 0.44, 46.65, false ),
		array( '08/08 sab', 96.13, 29533, 3.26, 231158, 0.42, 51.61, false ),
		array( '09/08 dom', 123.89, 35571, 3.48, 277762, 0.45, 51.53, false ),
		array( '10/08 seg', 113.83, 39891, 2.85, 295797, 0.38, 49.50, false ),
		array( '11/08 ter', 171.52, 60767, 2.82, 483293, 0.35, 50.22, false ),
		array( '12/08 qua', 212.81, 67784, 3.14, 444003, 0.48, 53.94, false ),
		array( '13/08 qui', 327.34, 70459, 4.65, 571480, 0.57, 50.91, true ),
		array( '14/08 sex', 264.22, 57257, 4.61, 461251, 0.57, 50.80, true ),
		array( '15/08 sab', 190.18, 46896, 4.06, 392579, 0.48, 53.22, true ),
		array( '16/08 dom', 225.71, 53010, 4.26, 430363, 0.52, 52.16, true ),
		array( '17/08 seg', 183.60, 40860, 4.49, 304197, 0.60, 50.67, true ),
		array( '18/08 ter', 134.43, 29039, 4.63, 197715, 0.68, 49.84, true ),
		array( '19/08 qua', 210.79, 35299, 5.97, 241976, 0.87, 49.99, true ),
		array( '24/08 seg', 73.89, 32026, 2.31, 133733, 0.55, 53.11, false ),
		array( '25/08 ter', 47.04, 20009, 2.35,  83023, 0.57, 54.31, false ),
		array( '26/08 qua', 39.29, 17503, 2.24,  83905, 0.47, 59.33, false ),
		array( '27/08 qui', 80.21, 24436, 3.28, 171120, 0.47, 58.88, false ),
		array( '28/08 sex', 77.69, 23272, 3.34, 158813, 0.49, 59.78, false ),
		array( '29/08 sab', 94.47, 24308, 3.89, 159242, 0.59, 55.62, false ),
		array( '30/08 dom', 199.16, 41574, 4.79, 272594, 0.73, 54.84, false ),
	);
}

/** @return array{min:float,median:float,max:float,count:int} */
function go_lab_ipv_stats( array $rows ) {
	$values = array();
	foreach ( $rows as $row ) {
		$values[] = (float) $row[4] / (float) $row[2];
	}
	sort( $values, SORT_NUMERIC );
	return array(
		'min'    => $values[0],
		'median' => $values[ (int) floor( count( $values ) / 2 ) ],
		'max'    => $values[ count( $values ) - 1 ],
		'count'  => count( $values ),
	);
}

/**
 * Validate the model against the real record instead of two hand-picked days.
 *
 * @param float $modelled_3_89 Site-wide impressions/pageview the 3.89 model produces.
 * @param float $modelled_3_88 The same for the 3.88 model.
 * @return void
 */
function go_lab_print_history( $modelled_3_89, $modelled_3_88 ) {
	$all      = go_lab_august();
	$manual   = array_values( array_filter( $all, static function ( $r ) { return ! $r[7]; } ) );
	$auto     = array_values( array_filter( $all, static function ( $r ) { return $r[7]; } ) );
	$early    = array_slice( $manual, 0, 12 );
	$late     = array_slice( $manual, 12 );

	echo PHP_EOL . PHP_EOL . '1B. O QUE ESTE INVENTARIO JA ENTREGOU (agosto/2026, relatorio real)' . PHP_EOL;
	go_lab_rule();
	printf( "%-26s %8s %9s %8s %7s%s", 'JANELA', 'min', 'mediana', 'max', 'dias', PHP_EOL );
	go_lab_rule();
	foreach ( array(
		array( 'Sem Auto Ads, 01-12/08', $early ),
		array( 'Com Auto Ads, 13-19/08', $auto ),
		array( 'Sem Auto Ads, 24-30/08', $late ),
	) as $window ) {
		$stats = go_lab_ipv_stats( $window[1] );
		printf(
			"%-26s %8s %9s %8s %7d%s",
			$window[0],
			go_lab_money( $stats['min'], 2 ),
			go_lab_money( $stats['median'], 2 ),
			go_lab_money( $stats['max'], 2 ),
			$stats['count'],
			PHP_EOL
		);
	}
	go_lab_rule();
	printf( "Modelo 3.89 (este motor)   %8s impressoes/PV%s", go_lab_money( $modelled_3_89, 2 ), PHP_EOL );
	printf( "Modelo 3.88 (o que roda)   %8s impressoes/PV%s", go_lab_money( $modelled_3_88, 2 ), PHP_EOL );
	echo PHP_EOL;

	echo 'MESMO PRECO, ENTREGAS DIFERENTES - evidencia de que entrega pode mover muito o Page RPM:' . PHP_EOL . PHP_EOL;
	printf( "%-14s %7s %9s %10s  %s%s", 'DIA', 'iRPM', 'imp/PV', 'Page RPM', 'AUTO ADS', PHP_EOL );
	go_lab_rule();
	foreach ( array( '26/08 qua', '27/08 qui', '12/08 qua', '15/08 sab', '11/08 ter' ) as $wanted ) {
		foreach ( $all as $row ) {
			if ( $row[0] !== $wanted ) {
				continue;
			}
			printf(
				"%-14s %7s %9s %10s  %s%s",
				$row[0],
				go_lab_money( $row[5], 2 ),
				go_lab_money( (float) $row[4] / (float) $row[2], 2 ),
				go_lab_money( $row[3], 2 ),
				$row[7] ? 'sim' : '-',
				PHP_EOL
			);
		}
	}
	printf( "%-14s %7s %9s %10s  %s%s", '18/09 (3.88)', '0,48', '5,00', '2,38', '-', PHP_EOL );
	go_lab_rule();
	echo '26 e 27/08: mesmo preco (0,47), entrega 4,79 contra 7,00, Page RPM 2,24 contra 3,28.' . PHP_EOL;
	echo '11/08 a 0,35 fez 2,82 de Page RPM. O 18/09, a 0,48, fez 2,38. Preco maior, resultado pior.' . PHP_EOL;
	echo PHP_EOL;
	echo 'LEITURA: estes dias demonstram que o site ja sustentou entrega maior sem in-page Auto Ads.' . PHP_EOL;
	echo 'Eles NAO dizem sozinhos qual mecanismo causou a diferenca. Qualquer modelo novo precisa' . PHP_EOL;
	echo 'ser validado contra requests/fill por unidade e formatos de conta medidos em producao.' . PHP_EOL;
}
