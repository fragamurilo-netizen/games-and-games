<?php
/** Regression: reporting revisions and stale snapshots are not zero-price auctions. */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
$code = getenv( 'GO_ADS_TEST_CODE' ) ?: GO_VERGE_DIR;
require_once $code . '/inc/ads/config.php';
require_once $code . '/inc/ads/economics.php';
require_once $code . '/inc/ads/yield.php';
require_once $code . '/inc/ads/planner.php';
go_test_pin_clock( 840 );
$start = array( 'earnings'=>10, 'page_views'=>1000, 'impressions'=>6000, 'clicks'=>10 );
$end = array( 'earnings'=>9.9, 'page_views'=>1300, 'impressions'=>8000, 'clicks'=>11 );
$revised = go_verge_ads_econ_interval( $start, $end, 60 );
go_test_ok( is_array( $revised ), 'Revisão permanece disponível para diagnóstico' );
go_test_ok( abs( $revised['earnings'] + .1 ) < .000001, 'Receita revisada preserva delta assinado, sem truncar a zero' );
go_test_equals( true, $revised['revised'], 'Revisão explicitamente identificada' );
go_test_equals( false, $revised['price_signal_usable'] ?? null, 'Revisão não é sinal de preço' );
go_test_equals( null, $revised['impression_rpm'], 'Sem RPM marginal artificial zero' );
go_test_equals( null, $revised['page_rpm'], 'Sem Page RPM marginal artificial zero' );
$end['earnings'] = 8;
$large = go_verge_ads_econ_interval( $start, $end, 60 );
go_test_ok( is_array( $large ) && $large['earnings'] === -2.0, 'Revisão grande também permanece observação, não some do diagnóstico' );
$end['earnings'] = 10;
$zero = go_verge_ads_econ_interval( $start, $end, 60 );
go_test_equals( 0.0, $zero['impression_rpm'], 'Delta de receita realmente zero não é descartado seletivamente' );
go_test_equals( true, $zero['price_signal_usable'] ?? null, 'Zero sem revisão é distinto de correção contábil' );
$down = array( array(780,10,1000,6000,10), array(840,9.9,1300,8000,11) );
$up = array( array(780,10,1000,6000,10), array(840,11.2,1300,8000,11) );
$hidden = array( array(780,10,1000,6000,10), array(810,9.9,1150,7000,10), array(840,10.2,1300,8000,11) );
$intraday = array( '2026-09-17'=>$hidden, '2026-09-18'=>$up, '2026-09-19'=>$down, '2026-09-20'=>$down );
$hidden_window = go_verge_ads_econ_window( $intraday, '2026-09-17', 840, 60 );
go_test_ok( $hidden_window['earnings'] > 0, 'Caso difícil: total da janela sobe após correção intermediária' );
go_test_equals( null, $hidden_window['impression_rpm'], 'Correção intermediária não desaparece no saldo positivo' );
$peers = go_verge_ads_econ_peers( $intraday, '2026-09-20', 840, new DateTimeImmutable( '2026-09-20 14:00', new DateTimeZone( 'America/Sao_Paulo' ) ) );
go_test_equals( 1, count( $peers ), 'Pares excluem as duas janelas revisadas, preservam a válida' );
function readiness_decision( $points ) {
    go_test_flush_transients();
    $GLOBALS['go_test_goac'] = array( 'connected'=>true, 'today'=>'2026-09-20', 'intraday'=>array('2026-09-20'=>$points), 'unit_rows'=>array(), 'daily_rows'=>array() );
    return go_verge_ads_yield_decision( true );
}
$decision = readiness_decision( $down );
go_test_equals( 'unknown', $decision['regime'], '10→9,9 com +300 PV/+2.000 imp não vira demand_collapse' );
go_test_equals( null, $decision['price'], 'Não substitui revisão pelo acumulado do dia' );
go_test_equals( 1.0, $decision['pacing_scale'], 'Revisão não freia nem acelera o ritmo de requests' );
go_test_equals( 0, $decision['supply_bias'], 'Revisão não inventa expansão econômica' );
go_test_ok( in_array('window-contains-reporting-revision', $decision['reasons'], true), 'Motivo de revisão é auditável' );
$article = str_repeat( '<p>' . str_repeat( 'palavra editorial ', 32 ) . '</p>', 10 );
$plan_revision = go_verge_ads_plan_article( $article );
$positive = readiness_decision( $up );
go_test_ok( $positive['price'] > .59 && $positive['price'] < .61, 'Janela positiva fresca mantém cálculo legítimo a partir dos totais' );
$plan_positive = go_verge_ads_plan_article( $article );
go_test_equals( $plan_positive['renderedCount'], $plan_revision['renderedCount'], 'Dados inválidos não retiram hosts estruturais de anúncios' );
go_test_equals( $plan_positive['plannedCount'], $plan_revision['plannedCount'], 'Inventário base preservado com revisão' );
$stale = readiness_decision( array( array(300,10,1000,6000,10), array(360,11.2,1300,8000,11) ) );
go_test_equals( 'unknown', $stale['regime'], 'Snapshot de oito horas atrás não classifica demanda atual' );
go_test_equals( null, $stale['price'], 'Acumulado atrasado não é preço atual' );
go_test_equals( 1.0, $stale['pacing_scale'], 'Stale tem ritmo neutro' );
go_test_equals( 0, $stale['supply_bias'], 'Stale não expande por acumulado antigo' );
go_test_equals( array_fill_keys(array('reach','premium','standard','deep','completion'),1.0), $stale['tier_lookahead'], 'Stale não altera antecipação por tier' );
$public = go_verge_ads_yield_public_signal();
go_test_ok( !isset($public['price']) && !isset($public['floor_scale']) && !isset($public['earnings']), 'Dinheiro e piso analítico não chegam ao runtime' );

/* A revision can arrive with no new impressions, or correct the denominators
 * themselves. These remain diagnostic observations, not cumulative fallbacks. */
$revision_cases = array(
    'earnings-down-volume-flat' => array( array(780,2,1000,6000,10), array(840,1.9,1000,6000,10) ),
    'pageviews-down' => array( array(780,2,1000,6000,10), array(840,2.1,990,6100,10) ),
    'impressions-down' => array( array(780,2,1000,6000,10), array(840,2.1,1100,5900,10) ),
    'all-cumulative-metrics-down' => array( array(780,2,1000,6000,10), array(840,1.9,990,5900,9) ),
    'intermediate-revision-net-zero' => array( array(780,2,1000,6000,10), array(810,1.9,990,5900,9), array(840,2,1000,6000,10) ),
    'missing-startpoint-revision' => array( array(720,2,1000,6000,10), array(830,2.2,1100,6600,11), array(840,2.1,1100,6600,11) ),
);
foreach ( $revision_cases as $case => $points ) {
    $decision = readiness_decision( $points );
    $state = go_verge_ads_econ_day_state();
    $window = $state['window'];
    go_test_ok( is_array( $window ) && ! empty( $window['revised'] ), "$case: revised window survives missing/negative interval volume" );
    go_test_equals( false, $window['price_signal_usable'] ?? null, "$case: no actionable marginal price" );
    go_test_equals( null, $window['page_rpm'] ?? null, "$case: no Page RPM from revised denominator" );
    go_test_equals( null, $window['impression_rpm'] ?? null, "$case: no impression RPM from revised denominator" );
    go_test_equals( null, $decision['price'], "$case: no escape to cumulative price" );
    go_test_equals( 0, $decision['supply_bias'], "$case: neutral supply" );
    go_test_equals( 1.0, $decision['pacing_scale'], "$case: neutral request timing" );
    go_test_ok( in_array( 'window-contains-reporting-revision', $decision['reasons'], true ), "$case: auditable revision reason" );
    if ( 'missing-startpoint-revision' === $case ) {
        go_test_equals( null, $window['earnings'], 'Missing endpoint does not fabricate a revenue delta' );
        go_test_equals( null, $window['page_views'], 'Missing endpoint does not fabricate interval pageviews' );
    }
}
$raw_revision = go_verge_ads_econ_interval(
    array( 'earnings'=>2, 'page_views'=>1000, 'impressions'=>6000, 'clicks'=>10 ),
    array( 'earnings'=>1.9, 'page_views'=>990, 'impressions'=>5900, 'clicks'=>9 ), 60
);
go_test_equals( -10.0, $raw_revision['page_views_delta'] ?? null, 'Signed pageview correction is preserved for diagnosis' );
go_test_equals( -100.0, $raw_revision['impressions_delta'] ?? null, 'Signed impression correction is preserved for diagnosis' );
go_test_equals( 0.0, $raw_revision['page_views'], 'Non-negative volume field remains compatible with callers' );
$flat_decision = readiness_decision( array( array(780,2,1000,6000,10), array(840,2,1000,6000,10) ) );
$flat_window = go_verge_ads_econ_day_state()['window'];
go_test_equals( false, $flat_window['revised'], 'Unchanged totals without an intermediate correction are not mislabeled revisions' );
go_test_equals( false, $flat_window['price_signal_usable'], 'Empty interval does not divide by zero or publish marginal RPM' );
go_test_equals( 'day-to-date', $flat_decision['confidence'], 'Existing fresh cumulative fallback remains available for an unrevised empty interval' );

$gap_decision = readiness_decision( array( array(720,2,1000,6000,10), array(830,2.2,1100,6600,11), array(840,2.3,1200,7200,11) ) );
go_test_equals( null, go_verge_ads_econ_day_state()['window'], 'Unrevised gap without initial endpoint remains an absent window' );
go_test_equals( 'day-to-date', $gap_decision['confidence'], 'An unrevised gap preserves the existing fresh cumulative fallback' );
