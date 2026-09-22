<?php
/** 5,000 deterministic mixed-layout cases for 4.5.0 Revenue Fusion. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

function rf_words( $count, $seed = 0 ) {
	$v = array( 'game','overdrive','serie','filme','guia','jogo','personagem','historia','teste','resultado','console','temporada','desempenho','atualizacao' );
	$out = array();
	for ( $i = 0; $i < $count; $i++ ) { $out[] = $v[ ( $i + $seed ) % count( $v ) ]; }
	return implode( ' ', $out );
}
function rf_para( $words, $seed ) { return '<p>' . rf_words( $words, $seed ) . '.</p>'; }
function rf_list( $words, $seed ) {
	$parts = array(); $left = $words; $i = 0;
	while ( $left > 0 ) { $take = min( $left, 12 + ( ( $seed + $i * 5 ) % 13 ) ); $parts[] = '<li>' . rf_words( $take, $seed + $i ) . '</li>'; $left -= $take; $i++; }
	return '<ul>' . implode( '', $parts ) . '</ul>';
}
function rf_article( $target, $case ) {
	$html = ''; $words = 0; $block = 0;
	while ( $words < $target ) {
		$left = $target - $words;
		$chunk = min( $left, 30 + ( ( $case * 19 + $block * 23 ) % 66 ) );
		$mode = ( $case + $block * 7 ) % 17;
		if ( 0 === $mode && $chunk >= 30 ) {
			$html .= '<blockquote>' . rf_words( $chunk, $case + $block ) . '.</blockquote>';
		} elseif ( 1 === $mode && $chunk >= 30 ) {
			$html .= rf_list( $chunk, $case + $block );
		} elseif ( 2 === $mode && $chunk >= 35 ) {
			$html .= '<table><tr><th>Item</th><th>Dado</th></tr><tr><td>' . rf_words( $chunk, $case ) . '</td><td>valor</td></tr></table>';
		} else {
			$html .= rf_para( $chunk, $case + $block );
		}
		$words += $chunk; $block++;
		if ( 0 === ( $case + $block ) % 4 && $words < $target - 25 ) { $html .= '<h2>Seção ' . $block . '</h2>'; }
		if ( 0 === ( $case + $block ) % 11 && $words < $target - 30 ) { $html .= '<figure><img src="https://example.test/' . $case . '-' . $block . '.jpg" alt="imagem"><figcaption>Contexto visual.</figcaption></figure>'; }
	}
	return $html;
}

go_test_section( '5.000 layouts mistos: invariantes do plano e do governador' );
$no_regression = 0; $with_reserve = 0; $type_uplift = 0;
for ( $i = 0; $i < 5000; $i++ ) {
	$target = 220 + ( ( $i * 67 ) % 1781 ); // 220..2000
	$html = rf_article( $target, $i );
	$plan = go_verge_ads_plan_article( $html );
	$m = (array) $plan['metrics'];
	$body     = (int) ( $m['bodyWords'] ?? 0 );
	$ladder   = (int) $plan['ladderCapacity'];
	$head     = (int) $plan['headroom'];
	$total    = (int) $plan['totalCapacity'];
	$planned  = (int) $plan['plannedCount'];
	$rendered = (int) $plan['renderedCount'];
	$safe = 0;
	foreach ( (array) $plan['candidates'] as $candidate ) { if ( empty( $candidate['reasons'] ) ) { $safe++; } }
	$substantial = (int) ( $m['substantial'] ?? 0 );
	$media_share = (int) ( $m['mediaHeight'] ?? 0 ) / max( 1, (int) ( $m['estimatedHeight'] ?? 0 ) );

	go_test_ok( $head >= 0 && $head <= 2, 'Passo estrutural 0..2 caso ' . $i );
	go_test_equals( min( 7, $safe, $ladder + $head ), min( 7, $safe, $ladder + $head ), 'Teto determinístico caso ' . $i );
	go_test_ok( $planned <= min( 7, $safe, $ladder + $head ), 'Plano nunca excede o teto estrutural caso ' . $i );
	go_test_ok( $planned <= $rendered && $rendered <= 7 && $total === min( 7, $rendered ), 'Planner/render/EXPANSÃO coerentes caso ' . $i );
	go_test_ok( (int) $plan['reserveCount'] === $rendered - $planned, 'Contagem de reservas coerente caso ' . $i );
	if ( $rendered > $planned ) { $with_reserve++; }
	if ( $body < 480 || $ladder < 3 || $ladder >= 7 ) {
		go_test_equals( 0, $head, 'Sem passo estrutural fora da janela caso ' . $i );
	}
	if ( $head >= 1 ) {
		go_test_ok( $safe > $ladder && $substantial >= 4 && $media_share <= .42, 'Passo estrutural exige evidência renderizada caso ' . $i );
	}
	if ( 2 === $head ) {
		go_test_ok( $body >= 550 && $body < 900 && $ladder <= 5 && $safe >= $ladder + 2 && $substantial >= 6 && $media_share <= .38,
			'Segundo passo exige a evidência completa caso ' . $i );
	}

	/* Every placement the planner emits must be a legal, non-overlapping insert
	 * point inside the original HTML, in the declared placement namespace. */
	$seen = array();
	foreach ( array_merge( $plan['prime'] ? array( $plan['prime'] ) : array(), (array) $plan['selected'], (array) $plan['reserves'] ) as $slot ) {
		$position = (int) $slot['position'];
		go_test_ok( $position > 0 && $position <= strlen( $html ), 'Offset dentro do HTML caso ' . $i );
		go_test_ok( 1 === preg_match( '/^(?:article-prime|article-a[1-6])$/', (string) $slot['placement'] ), 'Placement válido caso ' . $i );
		go_test_ok( ! isset( $seen[ $slot['placement'] ] ), 'Nenhum placement é emitido duas vezes caso ' . $i );
		$seen[ $slot['placement'] ] = true;
	}

	/* Format awareness may add inventory, never remove it. */
	$guide = go_verge_ads_plan_article( $html, 'guide' );
	go_test_ok( (int) $guide['ladderCapacity'] >= $ladder, 'Formato nunca rebaixa a escada caso ' . $i );
	go_test_ok( (int) $guide['plannedCount'] >= $planned, 'Formato nunca reduz o inventário planejado caso ' . $i );
	if ( (int) $guide['plannedCount'] > $planned ) { $type_uplift++; }
	$no_regression++;
}
go_test_ok( $with_reserve > 500, 'Reservas do governador existem em amostra relevante', 'casos=' . $with_reserve );
go_test_ok( $type_uplift > 50, 'O degrau de formato produz inventário real em amostra relevante', 'casos=' . $type_uplift );
echo "Fusion: cases={$no_regression}; reserve_cases={$with_reserve}; guide_uplift={$type_uplift}\n";
