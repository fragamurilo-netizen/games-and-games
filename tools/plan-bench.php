<?php
/**
 * Planner bench: runs the theme's pure article planner over a deterministic
 * corpus of synthetic articles and prints the opportunities it exposes.
 *
 *   php tools/plan-bench.php <theme-dir> [--json|--positions]
 *
 * Compare two builds by running it against each theme directory. It measures
 * STRUCTURE only (hosts the browser may request); it says nothing about fill,
 * price or viewability, which only the live AdSense report can answer.
 */
require __DIR__ . '/wp-stubs.php';
$theme = rtrim( $argv[1] ?? '', '/' );
if ( '' === $theme || ! is_dir( $theme . '/inc/ads' ) ) { fwrite( STDERR, "usage: php plan-bench.php <theme-dir>\n" ); exit( 2 ); }
define( 'GO_VERGE_DIR', $theme );
if ( is_readable( $theme . '/inc/ads/engine-settings.php' ) ) { require $theme . '/inc/ads/engine-settings.php'; }
require $theme . '/inc/ads/config.php';
require $theme . '/inc/ads/planner.php';

$lorem = explode( ' ', 'o jogo chega ao console com uma proposta ousada de mundo aberto que mistura exploração combate tático e narrativa ramificada enquanto a equipe promete desempenho estável em sessenta quadros por segundo nas plataformas atuais além de suporte a mods e conteúdo adicional gratuito ao longo do primeiro ano de lançamento segundo o estúdio responsável pelo projeto' );
function od_words( $n ) { global $lorem; $o = array(); for ( $i = 0; $i < $n; $i++ ) { $o[] = $lorem[ mt_rand( 0, count( $lorem ) - 1 ) ]; } return ucfirst( implode( ' ', $o ) ) . '.'; }
function od_article( $type, $target ) {
	$html = ''; $words = 0; $i = 0;
	while ( $words < $target ) {
		$i++;
		if ( in_array( $type, array( 'guide', 'ranking', 'list' ), true ) && 1 === $i % 4 && $i > 1 ) {
			$html .= '<h2>' . od_words( 5 ) . '</h2>';
			if ( 'news' !== $type && 0 === mt_rand( 0, 1 ) ) { $html .= '<figure class="wp-block-image"><img src="x.webp" alt=""></figure>'; }
		} elseif ( 'news' === $type && 0 === $i % 6 ) {
			$html .= '<figure class="wp-block-image"><img src="x.webp" alt=""></figure>';
		}
		if ( 'list' === $type && 0 === $i % 5 ) {
			$items = ''; for ( $k = 0; $k < 4; $k++ ) { $items .= '<li>' . od_words( 9 ) . '</li>'; }
			$html .= '<ul>' . $items . '</ul>'; $words += 36; continue;
		}
		$n = mt_rand( 28, 85 );
		$html .= '<p>' . od_words( $n ) . '</p>';
		$words += $n;
	}
	return $html;
}

mt_srand( 20260925 );
$corpus = array();
foreach ( array( 'news' => array( 260, 340, 420, 520, 640, 760, 900 ), 'review' => array( 900, 1300, 1700, 2200 ), 'guide' => array( 1000, 1500, 2100, 2800, 3600 ), 'ranking' => array( 1200, 1900, 2600 ), 'list' => array( 800, 1400, 2400 ) ) as $type => $sizes ) {
	foreach ( $sizes as $size ) {
		for ( $v = 0; $v < 3; $v++ ) { $corpus[] = array( $type, $size, od_article( $type, $size ) ); }
	}
}

$rows = array(); $tot = array( 'articles' => 0, 'planned' => 0, 'rendered' => 0, 'reserves' => 0, 'long_planned' => 0, 'long_rendered' => 0, 'long' => 0 );
foreach ( $corpus as $item ) {
	list( $type, $size, $html ) = $item;
	$plan = go_verge_ads_plan_article( $html, 'review' === $type ? 'review' : $type );
	$words = $plan['metrics']['bodyWords'];
	$rows[] = sprintf( '%-8s %5d w  ladder %d  +head %d  planned %d  reserves %d  rendered %d  cap %d', $type, $words, $plan['ladderCapacity'], $plan['headroom'], $plan['plannedCount'], $plan['reserveCount'], $plan['renderedCount'], $plan['totalCapacity'] );
	$tot['articles']++; $tot['planned'] += $plan['plannedCount']; $tot['rendered'] += $plan['renderedCount']; $tot['reserves'] += $plan['reserveCount'];
	if ( $words >= 1200 ) { $tot['long']++; $tot['long_planned'] += $plan['plannedCount']; $tot['long_rendered'] += $plan['renderedCount']; }
}
if ( in_array( '--positions', $argv, true ) ) {
	/* One line per article: placement@words-before, in reading order. */
	foreach ( $corpus as $item ) {
		$plan = go_verge_ads_plan_article( $item[2], 'review' === $item[0] ? 'review' : $item[0] );
		$out  = array();
		foreach ( array_merge( $plan['prime'] ? array( $plan['prime'] ) : array(), $plan['selected'] ) as $c ) {
			$out[] = $c['placement'] . '@' . $c['beforeWords'];
		}
		echo $item[0], ' ', $plan['metrics']['bodyWords'], ': ', implode( ' ', $out ), "\n";
	}
	exit;
}
if ( in_array( '--json', $argv, true ) ) { echo json_encode( $tot ), "\n"; exit; }
echo implode( "\n", $rows ), "\n\n";
printf( "contract capacity (P1 + A-rungs): %d\n", go_verge_ads_planner_contract_capacity() );
printf( "articles %d | planned/article %.2f | rendered/article %.2f | reserves/article %.2f\n", $tot['articles'], $tot['planned'] / $tot['articles'], $tot['rendered'] / $tot['articles'], $tot['reserves'] / $tot['articles'] );
printf( "1200+ words: %d articles | planned/article %.2f | rendered/article %.2f\n", $tot['long'], $tot['long'] ? $tot['long_planned'] / $tot['long'] : 0, $tot['long'] ? $tot['long_rendered'] / $tot['long'] : 0 );
