<?php
/** Deterministic adversarial planner matrix for Revenue Max. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

function gs_words( $n ) {
	$w = array();
	for ( $i = 0; $i < $n; $i++ ) { $w[] = 'conteudo'; }
	return implode( ' ', $w );
}
function gs_article( $seed, $target ) {
	$html = '';
	$words = 0;
	$i = 0;
	while ( $words < $target ) {
		$chunk = 28 + ( ( $seed * 17 + $i * 23 ) % 58 );
		$chunk = min( $chunk, max( 18, $target - $words ) );
		$html .= '<p>' . gs_words( $chunk ) . '.</p>';
		$words += $chunk;
		$i++;
		if ( 0 === ( $seed + $i ) % 4 && $words < $target - 30 ) { $html .= '<h2>Seção ' . $i . '</h2>'; }
		if ( 0 === ( $seed + $i * 2 ) % 7 && $words < $target - 40 ) { $html .= '<figure><img src="x.jpg" alt="x"><figcaption>Imagem editorial.</figcaption></figure>'; }
		if ( 0 === ( $seed + $i ) % 9 && $words < $target - 60 ) { $html .= '<div class="go-cta">CTA protegido</div>'; }
	}
	return $html;
}

go_test_section( 'Matriz adversarial determinística do planner' );
$cases = 0;
foreach ( array( 230, 245, 275, 330, 390, 470, 560, 690, 820, 980, 1150, 1450, 1800, 2400 ) as $target ) {
	for ( $seed = 1; $seed <= 12; $seed++ ) {
		$html = gs_article( $seed, $target );
		$a = go_verge_ads_plan_article( $html );
		$b = go_verge_ads_plan_article( $html );
		$cases++;
		go_test_equals( $a['plannedCount'], $b['plannedCount'], "#$cases determinismo de contagem" );
		go_test_equals( $a['version'], $b['version'], "#$cases determinismo de versão" );
		go_test_ok( $a['plannedCount'] <= $a['totalCapacity'], "#$cases plano nunca excede capacidade" );
		go_test_ok( $a['renderedCount'] >= $a['plannedCount'], "#$cases renderizados cobrem plano" );
		go_test_ok( $a['renderedCount'] <= 7, "#$cases no máximo Prime + A1..A6" );
		go_test_ok( $a['reserveCount'] <= 2, "#$cases no máximo duas reservas" );
		go_test_equals( $a['renderedCount'], $a['plannedCount'] + $a['reserveCount'], "#$cases reservas contabilizadas exatamente" );
		$all = array_merge( $a['prime'] ? array( $a['prime'] ) : array(), (array) $a['selected'], (array) ( $a['reserves'] ?? array() ) );
		$placements = array(); $positions = array();
		foreach ( $all as $unit ) { $placements[] = $unit['placement']; $positions[] = $unit['position']; }
		go_test_equals( count( $placements ), count( array_unique( $placements ) ), "#$cases placements únicos" );
		go_test_equals( count( $positions ), count( array_unique( $positions ) ), "#$cases offsets únicos" );
		if ( $a['metrics']['bodyWords'] < 240 ) { go_test_equals( 0, (int) $a['plannedCount'], "#$cases <240 palavras sem corpo" ); }
	}
}
echo "Casos adversariais: {$cases}\n";
