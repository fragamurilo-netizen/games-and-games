<?php
/**
 * Production-delivery laboratory.
 *
 * Usage:
 *   php tests/lab.php
 *   php tests/lab.php <pageviews> <impressions> [impression_rpm]
 *
 * This lab deliberately does NOT forecast impressions/PV from a synthetic
 * reach curve. Version 3.90 did that and could report ~7 while production sat
 * in the mid-5s because several unmeasured terms (article mix, scroll depth,
 * fill, overlays and device mix) were converted into fixed assumptions.
 *
 * 4.1 tests only what can be validated offline:
 *   - how many safe boundaries the real planner sees;
 *   - how many body hosts it targets and how many reserves it exposes;
 *   - whether medium/short/list content is silently capacity-limited;
 *   - whether the decision authority diagnoses observed delivery without
 *     turning Impression RPM into a slot-count target.
 *
 * Actual impressions remain a production measurement. Use GOAdsRuntime.inspect()
 * on pages and the AdSense ad-unit/format reports to close that loop.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	http_response_code( 403 );
	exit;
}

require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/economics.php';
require_once GO_VERGE_DIR . '/inc/ads/yield.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
require_once __DIR__ . '/lab-history.php';

function go_lab_rule( $char = '-' ) {
	echo str_repeat( $char, 104 ) . PHP_EOL;
}
function go_lab_money( $value, $decimals = 2 ) {
	return number_format( (float) $value, $decimals, ',', '.' );
}
function go_lab_paragraph( $words, $seed = 'texto' ) {
	$words = max( 1, (int) $words );
	return '<p>' . implode( ' ', array_fill( 0, $words, $seed ) ) . '.</p>';
}
function go_lab_article_html( $shape ) {
	$html = '';
	foreach ( (array) $shape as $part ) {
		$type = (string) ( $part[0] ?? 'p' );
		if ( 'p' === $type ) {
			$html .= go_lab_paragraph( (int) ( $part[1] ?? 70 ) );
		} elseif ( 'h2' === $type ) {
			$html .= '<h2>' . htmlspecialchars( (string) ( $part[1] ?? 'Secao' ), ENT_QUOTES ) . '</h2>';
		} elseif ( 'img' === $type ) {
			$html .= '<figure><img src="example.jpg" alt=""><figcaption>Imagem editorial</figcaption></figure>';
		} elseif ( 'list' === $type ) {
			$items = max( 2, (int) ( $part[1] ?? 5 ) );
			$words = max( 8, (int) ( $part[2] ?? 20 ) );
			$html .= '<ul>';
			for ( $i = 0; $i < $items; $i++ ) {
				$html .= '<li>' . implode( ' ', array_fill( 0, $words, 'item' ) ) . '.</li>';
			}
			$html .= '</ul>';
		}
	}
	return $html;
}

/** Representative editorial shapes, not traffic weights. */
function go_lab_shapes() {
	return array(
		'noticia-curta-250' => array( array( 'p', 90 ), array( 'p', 80 ), array( 'p', 80 ) ),
		'noticia-280'       => array( array( 'p', 70 ), array( 'p', 70 ), array( 'p', 70 ), array( 'p', 70 ) ),
		'media-560'         => array_fill( 0, 8, array( 'p', 70 ) ),
		'media-com-imagem'  => array( array( 'p', 80 ), array( 'p', 75 ), array( 'img' ), array( 'p', 80 ), array( 'p', 75 ), array( 'p', 80 ) ),
		'guia-900'          => array_merge( array( array( 'p', 85 ), array( 'p', 80 ) ), array_fill( 0, 10, array( 'p', 74 ) ) ),
		'longform-1500'     => array_fill( 0, 20, array( 'p', 75 ) ),
		'listicle-900'      => array(
			array( 'p', 85 ), array( 'p', 75 ),
			array( 'h2', '1' ), array( 'list', 5, 24 ),
			array( 'h2', '2' ), array( 'list', 5, 24 ),
			array( 'h2', '3' ), array( 'list', 5, 24 ),
			array( 'h2', '4' ), array( 'list', 5, 24 ),
			array( 'h2', '5' ), array( 'list', 5, 24 ),
			array( 'h2', '6' ), array( 'list', 5, 24 ),
		),
	);
}

/** Run the real decision authority against one observed site-wide state. */
function go_lab_observed_decision( $delivered, $price ) {
	go_test_flush_transients();
	$GLOBALS['go_test_goac'] = array(
		'connected' => true,
		'today'     => '2026-09-20',
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 6.5, 0.50 ),
			array( '2026-09-20' => go_test_day( 1200, $delivered, $price ) )
		),
		'unit_rows' => go_test_unit_rows(
			array(
				'7792311754' => array( 'request_rpm' => 0.62, 'requests' => 40000, 'coverage' => 0.88 ),
				'3572313419' => array( 'request_rpm' => 0.55, 'requests' => 38000, 'coverage' => 0.90 ),
				'5017324239' => array( 'request_rpm' => 0.49, 'requests' => 30000, 'coverage' => 0.86 ),
				'5223365459' => array( 'request_rpm' => 0.44, 'requests' => 26000, 'coverage' => 0.84 ),
				'6368539121' => array( 'request_rpm' => 0.40, 'requests' => 22000, 'coverage' => 0.83 ),
				'7554015324' => array( 'request_rpm' => 0.34, 'requests' => 18000, 'coverage' => 0.82 ),
				'6240933652' => array( 'request_rpm' => 0.27, 'requests' => 14000, 'coverage' => 0.80 ),
				'6568236715' => array( 'request_rpm' => 0.23, 'requests' => 11000, 'coverage' => 0.79 ),
				'8238832024' => array( 'request_rpm' => 0.17, 'requests' => 8000, 'coverage' => 0.76 ),
				'5255155049' => array( 'request_rpm' => 0.14, 'requests' => 6000, 'coverage' => 0.74 ),
				'5798080525' => array( 'request_rpm' => 0.31, 'requests' => 9000, 'coverage' => 0.81 ),
			)
		),
	);
	return go_verge_ads_yield_decision( true );
}


echo PHP_EOL;
go_lab_rule( '=' );
echo 'LABORATORIO DE PRODUCAO — Overdrive 4.5.0 Revenue Fusion' . PHP_EOL;
echo 'Sem previsao ficticia de imp/PV: o laboratorio mede estrutura; producao mede impressoes.' . PHP_EOL;
go_lab_rule( '=' );

echo PHP_EOL . '1. PLANNER REAL POR FORMATO EDITORIAL' . PHP_EOL;
go_lab_rule();
printf( "%-23s %7s %8s %9s %9s %8s %s%s", 'FORMA', 'PALAV.', 'CANDID.', 'CAPACID.', 'ALVO', 'RESERVA', 'POSICOES', PHP_EOL );
go_lab_rule();
foreach ( go_lab_shapes() as $name => $shape ) {
	$plan = go_verge_ads_plan_article( go_lab_article_html( $shape ) );
	$eligible = 0;
	foreach ( (array) ( $plan['candidates'] ?? array() ) as $candidate ) {
		if ( empty( $candidate['reasons'] ) ) {
			$eligible++;
		}
	}
	$placements = array();
	if ( ! empty( $plan['prime'] ) ) {
		$placements[] = 'P@' . (int) round( (float) $plan['prime']['depth'] * 100 ) . '%';
	}
	foreach ( (array) ( $plan['selected'] ?? array() ) as $slot ) {
		$placements[] = strtoupper( str_replace( 'article-', '', (string) $slot['placement'] ) ) . '@' . (int) round( (float) $slot['depth'] * 100 ) . '%';
	}
	foreach ( (array) ( $plan['reserves'] ?? ( ! empty( $plan['reserve'] ) ? array( $plan['reserve'] ) : array() ) ) as $reserve ) {
		$placements[] = 'R:' . strtoupper( str_replace( 'article-', '', (string) $reserve['placement'] ) ) . '@' . (int) round( (float) $reserve['depth'] * 100 ) . '%';
	}
	printf(
		"%-23s %7d %8d %9d %9d %8d %s%s",
		$name,
		(int) ( $plan['metrics']['bodyWords'] ?? 0 ),
		$eligible,
		(int) ( $plan['totalCapacity'] ?? 0 ),
		(int) ( $plan['plannedCount'] ?? 0 ),
		(int) ( $plan['reserveCount'] ?? 0 ),
		implode( ', ', $placements ),
		PHP_EOL
	);
}

go_lab_rule();
echo 'ALVO = capacidade estrutural utilizavel pelo runtime; reservas nunca permitem ultrapassa-la e nao sao impressoes garantidas.' . PHP_EOL;
echo 'RESERVA = host inerte extra que pode substituir oportunidade nao preenchida/nao aproveitada sem refresh.' . PHP_EOL;

/* Historical yardstick. */
echo PHP_EOL . '2. YARDSTICK REAL DO PROPRIO SITE' . PHP_EOL;
go_lab_rule();
$all = go_lab_august();
$manual = array_values( array_filter( $all, static function ( $r ) { return ! $r[7]; } ) );
$auto = array_values( array_filter( $all, static function ( $r ) { return $r[7]; } ) );
$early = array_slice( $manual, 0, 12 );
$late = array_slice( $manual, 12 );
foreach ( array(
	array( 'Sem Auto Ads 01-12/08', $early ),
	array( 'Com Auto Ads 13-19/08', $auto ),
	array( 'Sem Auto Ads 24-30/08', $late ),
) as $window ) {
	$stats = go_lab_ipv_stats( $window[1] );
	printf( "%-26s min %s | mediana %s | max %s | %d dias%s",
		$window[0], go_lab_money( $stats['min'] ), go_lab_money( $stats['median'] ), go_lab_money( $stats['max'] ), $stats['count'], PHP_EOL );
}
echo PHP_EOL;
echo 'Esses numeros provam capacidade historica do site, nao causalidade de uma configuracao isolada.' . PHP_EOL;
echo 'Mix de trafego, device, alcance, formatos de conta e demanda mudam entre os dias.' . PHP_EOL;

/* Optional live snapshot supplied at the command line. */
$pv = isset( $argv[1] ) ? (float) $argv[1] : 0.0;
$impressions = isset( $argv[2] ) ? (float) $argv[2] : 0.0;
$price = isset( $argv[3] ) ? (float) $argv[3] : 0.45;
if ( $pv > 0 && $impressions > 0 ) {
	$delivered = $impressions / $pv;
	$decision = go_lab_observed_decision( $delivered, $price );
	echo PHP_EOL . '3. SNAPSHOT OBSERVADO INFORMADO NA LINHA DE COMANDO' . PHP_EOL;
	go_lab_rule();
	printf( "PV: %s | impressoes: %s | imp/PV: %s | iRPM informado: %s%s",
		number_format( $pv, 0, ',', '.' ), number_format( $impressions, 0, ',', '.' ), go_lab_money( $delivered ), go_lab_money( $price ), PHP_EOL );
	printf( "Referencia de saude: %s imp/PV | regime: %s | urgencia: +%d%s",
		go_lab_money( (float) ( $decision['delivery_reference_pv'] ?? 0 ) ),
		(string) $decision['regime'],
		(int) $decision['supply_bias'],
		PHP_EOL
	);
	printf( "Motivos: %s%s", implode( ', ', (array) $decision['reasons'] ), PHP_EOL );
	echo 'A referencia NAO aumenta o alvo estrutural de uma materia; ela apenas altera timing/prioridade.' . PHP_EOL;
}

echo PHP_EOL . '4. CRITERIO DE VALIDACAO EM PRODUCAO' . PHP_EOL;
go_lab_rule();
echo 'Para uma pageview real, rode GOAdsRuntime.inspect() no console e acompanhe:' . PHP_EOL;
echo '  planner: eligibleCandidates -> structuralBodyCapacity -> plannedBodyCount -> renderedBodyCount' . PHP_EOL;
echo '  runtime: mounted -> requested -> providerPresent/unfilled -> estados de espera' . PHP_EOL;
echo 'Depois cruze com o relatorio AdSense por AD_UNIT_ID e por formato (Anchor/Vignette separados).' . PHP_EOL;
echo 'Se o planner cria 5 e o runtime pede 5, mas AdSense conta 4, o gargalo e fill/provider.' . PHP_EOL;
echo 'Se o planner cria 5 e o runtime pede 3, o gargalo e alcance/densidade/timing.' . PHP_EOL;
echo 'Se o planner ja cria 3 numa materia que fisicamente suporta mais, o gargalo e estrutural.' . PHP_EOL;

go_lab_rule( '=' );
echo 'LAB FINALIZADO — nenhum numero de imp/PV projetado foi apresentado como resultado real.' . PHP_EOL;
go_lab_rule( '=' );
