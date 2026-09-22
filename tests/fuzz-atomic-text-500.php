<?php
/** 500 deterministic static table/dl layouts: count editorial text, never monetize inside/adjacent. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
function go_atomic_words( $n, $word = 'conteudo' ) { return trim( str_repeat( $word . ' ', max( 1, (int) $n ) ) ); }
function go_atomic_p( $n ) { return '<p>' . go_atomic_words( $n ) . '.</p>'; }
$failures = array(); $checks = 0;
for ( $case = 1; $case <= 500; $case++ ) {
	$pre = 3 + ( $case % 4 );
	$post = 3 + ( (int) floor( $case / 4 ) % 4 );
	$atomic_words = 120 + ( $case % 5 ) * 40;
	$is_dl = 0 === $case % 2;
	$atomic = $is_dl
		? '<dl><dt>' . go_atomic_words( 30, 'termo' ) . '</dt><dd>' . go_atomic_words( $atomic_words - 30, 'definicao' ) . '</dd></dl>'
		: '<table><tr><th>Campo</th><th>Valor</th></tr><tr><td>' . go_atomic_words( $atomic_words, 'dado' ) . '</td><td>editorial</td></tr></table>';
	$html = str_repeat( go_atomic_p( 80 ), $pre ) . $atomic . str_repeat( go_atomic_p( 80 ), $post );
	$plan = go_verge_ads_plan_article( $html );
	$expected_min = ( $pre + $post ) * 80 + $atomic_words;
	$checks++;
	if ( (int) $plan['metrics']['atomicTextWords'] < $atomic_words ) $failures[] = "case $case atomic words undercount";
	$checks++;
	if ( (int) $plan['metrics']['bodyWords'] < $expected_min ) $failures[] = "case $case body words undercount";
	$checks++;
	if ( (int) $plan['totalCapacity'] < 0 || (int) $plan['totalCapacity'] > 7 ) $failures[] = "case $case capacity out of range";
	$checks++;
	if ( (int) $plan['plannedCount'] > (int) $plan['totalCapacity'] ) $failures[] = "case $case plan exceeds capacity";
	$start = strpos( $html, $is_dl ? '<dl>' : '<table>' );
	$closing = $is_dl ? '</dl>' : '</table>';
	$end = strpos( $html, $closing ) + strlen( $closing );
	$placements = array_merge( array_filter( array( $plan['prime'] ) ), (array) $plan['selected'], (array) $plan['reserves'] );
	foreach ( $placements as $placement ) {
		$pos = (int) $placement['position'];
		$checks++;
		if ( $pos > $start && $pos < $end ) $failures[] = "case $case placement inside atomic text";
		/* Direct boundaries at the opening/closing are protected too. */
		$checks++;
		if ( $pos === $start || $pos === $end ) $failures[] = "case $case placement adjacent to atomic text";
	}
	$commercial = str_repeat( go_atomic_p( 80 ), $pre )
		. '<table class="go-review"><tr><td>' . go_atomic_words( $atomic_words, 'oferta' ) . '</td></tr></table>'
		. str_repeat( go_atomic_p( 80 ), $post );
	$commercial_plan = go_verge_ads_plan_article( $commercial );
	$checks++;
	if ( 0 !== (int) $commercial_plan['metrics']['atomicTextWords'] ) $failures[] = "case $case protected table counted";
}
$result = array( 'cases' => 500, 'checks' => $checks, 'failureCount' => count( $failures ), 'failures' => array_slice( $failures, 0, 30 ) );
echo json_encode( $result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES ), PHP_EOL;
if ( $failures ) exit( 1 );
