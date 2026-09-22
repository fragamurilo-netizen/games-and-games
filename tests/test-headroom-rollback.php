<?php
/** Regression: structural recovery can be independently rolled back. */
if ( 'cli' !== PHP_SAPI ) { exit; }
define( 'GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED', false );
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';
function rhd_para( $words ) { return '<p>' . implode( ' ', array_fill( 0, $words, 'conteudo' ) ) . '.</p>'; }
$html = str_repeat( rhd_para( 70 ), 8 );
$plan = go_verge_ads_plan_article( $html );
go_test_section( 'Rollback do passo estrutural' );
go_test_equals( 4, (int) $plan['ladderCapacity'], 'Baseline de 560 palavras continua quatro' );
go_test_equals( 0, (int) $plan['headroom'], 'A constante desliga apenas o passo estrutural' );
go_test_ok( (int) $plan['plannedCount'] <= 4, 'Planner não usa quinta posição com rollback ativo' );
go_test_ok( (int) $plan['totalCapacity'] <= 6, 'Com rollback o teto de EXPANSÃO cai junto', 'total=' . $plan['totalCapacity'] );
go_test_ok( (int) $plan['renderedCount'] >= (int) $plan['plannedCount'], 'O rollback não quebra a coerência planner/render' );
