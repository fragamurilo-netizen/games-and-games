<?php
/** 1,000 deterministic planner cases for 4.5.0 evidence-backed revenue headroom. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

function rr_para( $words, $seed ) {
	$v = array( 'jogo','filme','série','guia','personagem','história','desempenho','console','temporada','atualização','teste','resultado' );
	$out = array();
	for ( $i = 0; $i < $words; $i++ ) { $out[] = $v[ ( $i + $seed ) % count( $v ) ]; }
	return '<p>' . ucfirst( implode( ' ', $out ) ) . '.</p>';
}
function rr_article( $target, $case ) {
	$html = '';
	$words = 0;
	$block = 0;
	while ( $words < $target ) {
		$chunk = min( $target - $words, 38 + ( ( $case * 17 + $block * 29 ) % 73 ) );
		$html .= rr_para( $chunk, $case + $block );
		$words += $chunk;
		$block++;
		if ( 0 === ( $case + $block ) % 5 && $words < $target - 30 ) {
			$html .= '<h2>Seção editorial ' . $block . '</h2>';
		}
		if ( 0 === ( $case + $block ) % 9 && $words < $target - 80 ) {
			$html .= '<blockquote>' . strip_tags( rr_para( min( 45, $target - $words ), $case ) ) . '</blockquote>';
			$words += min( 45, $target - $words );
		}
		if ( 0 === ( $case + $block ) % 11 && $words < $target - 60 ) {
			$html .= '<figure><img src="https://example.test/' . $case . '.jpg" alt="imagem"><figcaption>Contexto editorial.</figcaption></figure>';
		}
	}
	return $html;
}

go_test_section( '1.000 cenários: teto estrutural, reservas e coerência do plano' );
$with_headroom = 0;
$with_reserve  = 0;
for ( $i = 0; $i < 1000; $i++ ) {
	$target = 220 + ( ( $i * 47 ) % 1581 ); // 220..1800
	$plan = go_verge_ads_plan_article( rr_article( $target, $i ) );
	$metrics = (array) $plan['metrics'];
	$ladder   = (int) $plan['ladderCapacity'];
	$head     = (int) $plan['headroom'];
	$total    = (int) $plan['totalCapacity'];
	$planned  = (int) $plan['plannedCount'];
	$rendered = (int) $plan['renderedCount'];
	$reserves = (int) $plan['reserveCount'];
	$body = (int) ( $metrics['bodyWords'] ?? 0 );
	$safe = 0;
	foreach ( (array) $plan['candidates'] as $candidate ) { if ( empty( $candidate['reasons'] ) ) { $safe++; } }
	if ( $head ) { $with_headroom++; }
	if ( $reserves ) { $with_reserve++; }

	go_test_ok( $head >= 0 && $head <= 2, 'O passo estrutural nunca passa de dois no caso ' . $i );
	go_test_ok( $ladder === min( 7, $safe, go_verge_ads_planner_capacity_from_words( $body ) ), 'Escada = min(teto por palavras, boundaries seguros) no caso ' . $i );
	go_test_ok( $planned <= 7 && $rendered <= 7 && $total <= 7, 'Nenhum caso rompe o teto 7: ' . $i );
	go_test_ok( $planned <= $rendered && $total === min( 7, $rendered ), 'Budget STANDARD <= renderizado = teto de EXPANSÃO no caso ' . $i );
	go_test_ok( $reserves === $rendered - $planned && $reserves <= 2, 'Reservas são exatamente os hosts extras renderizados no caso ' . $i );
	go_test_ok( 0 === $planned || $rendered >= $planned, 'Todo host planejado é renderizado no caso ' . $i );
	if ( $body < 480 || $ladder < 3 || $ladder >= 7 ) {
		go_test_equals( 0, $head, 'Fora da janela estrutural não há passo extra: ' . $i );
	}
	$share = (int) ( $metrics['mediaHeight'] ?? 0 ) / max( 1, (int) ( $metrics['estimatedHeight'] ?? 0 ) );
	if ( $head >= 1 ) {
		go_test_ok( $body >= 480, 'O passo estrutural exige corpo editorial real: ' . $i );
		go_test_ok( $safe > $ladder, 'O passo estrutural exige boundary seguro extra: ' . $i );
		go_test_ok( (int) ( $metrics['substantial'] ?? 0 ) >= 4, 'O passo estrutural exige leitura substancial: ' . $i );
		go_test_ok( $share <= .42, 'Layout media-heavy não recebe passo estrutural: ' . $i );
	}
	if ( 2 === $head ) {
		go_test_ok( $body >= 550 && $body < 900, 'O segundo passo fica restrito ao miolo 550–899: ' . $i );
		go_test_ok( $ladder <= 5, 'O segundo passo só existe abaixo do sexto degrau: ' . $i );
		go_test_ok( $safe >= $ladder + 2, 'O segundo passo exige dois boundaries seguros extras: ' . $i );
		go_test_ok( (int) ( $metrics['substantial'] ?? 0 ) >= 6, 'O segundo passo exige seis blocos substanciais: ' . $i );
		go_test_ok( $share <= .38, 'O segundo passo exclui layout media-heavy: ' . $i );
	}
}
go_test_ok( $with_headroom > 50, 'O passo estrutural é exercitado em amostra relevante', 'casos=' . $with_headroom );
go_test_ok( $with_reserve > 300, 'Reservas do governador são expostas na maioria dos artigos', 'casos=' . $with_reserve );
echo "Recovery: headroom_cases={$with_headroom}; reserve_cases={$with_reserve}\n";
