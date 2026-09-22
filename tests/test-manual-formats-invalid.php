<?php
/**
 * Optional ids from wp-config must fail closed.
 *
 * Até a 4.6 duas posições trocavam de TIPO de unidade por constante — A3 de
 * In-article para Display, Article End de Display para Multiplex — e um id com
 * erro de digitação reescrevia como uma unidade viva era servida e medida. Os
 * dois experimentos morreram, e a 5.0.3 fez a troca de formato do jeito certo:
 * unidades NOVAS declaradas no contrato, não uma constante reescrevendo as
 * antigas.
 *
 * O que ainda vem de `wp-config.php` são os dois slots de listagem opcionais.
 * Este arquivo garante as duas coisas: que as constantes mortas continuam
 * inertes, e que lixo nos slots vivos derruba a posição em vez de renderizar um
 * `ins` que nunca vai preencher.
 */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';

/* Constantes dos experimentos extintos, mais lixo nas opcionais que existem. */
define( 'GO_VERGE_ADS_ARTICLE_A3_DISPLAY_SLOT', 'not-a-slot' );
define( 'GO_VERGE_ADS_ARTICLE_END_MULTIPLEX_SLOT', '123' );
define( 'GO_VERGE_ADS_LISTING_F4_SLOT', 'nao-e-um-slot' );
define( 'GO_VERGE_ADS_LISTING_F5_SLOT', '   ' );

function go_verge_ads_unit_matches_context( $unit ) { return true; }
function go_verge_ads_debug_enabled() { return false; }
function go_verge_ads_requires_theme_consent_gate() { return false; }
function go_verge_adsense_topscroll_config() { return array(); }
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/renderer.php';
$c = go_verge_ads_config();
$inventory = $c['inventory'];

go_test_section( 'Constantes dos experimentos extintos são inertes' );
/* Definidas acima com valores plausíveis. Se alguma ainda fosse lida, estes
 * três blocos mudariam de id ou de formato — é exatamente o acidente que o
 * mecanismo antigo permitia. */
go_test_equals( '5056215625', (string) $inventory['article-a3']['slot'], 'A3 mantém a unidade Display declarada no contrato' );
go_test_equals( 'responsive', (string) $inventory['article-a3']['sizing'], 'A3 continua Display responsivo' );
go_test_equals( '5798080525', (string) $inventory['article-end']['slot'], 'Article End mantém o id declarado' );
go_test_equals( 'responsive', (string) $inventory['article-end']['sizing'], 'Article End continua Display responsivo' );

go_test_section( 'Slot opcional inválido derruba a posição' );
/*
 * A posição continua DECLARADA — é assim que ela fica inerte esperando um id —
 * mas não pode ser SERVIDA. Um `ins` com slot inválido reserva altura, toma o
 * lugar de uma unidade boa no rodízio de listagem e nunca preenche.
 */
$served = go_verge_adsense_units();
foreach ( array( 'listing-f4', 'listing-f5' ) as $key ) {
	go_test_ok( ! isset( $served[ $key ] ), $key . ' com id inválido não é servida' );
	go_test_equals( '', (string) ( $inventory[ $key ]['slot'] ?? 'ausente' ), $key . ' tem o slot inválido zerado, não repassado ao markup' );
}
foreach ( array( 'listing-f1', 'listing-f2', 'listing-f3' ) as $key ) {
	go_test_ok( isset( $served[ $key ] ), $key . ' continua servida ao lado do id quebrado' );
}
/* E o id quebrado não chega a lugar nenhum que o consuma. */
go_test_ok( ! in_array( 'nao-e-um-slot', array_map( 'strval', array_keys( go_verge_ads_all_slots() ) ), true ),
	'O id inválido não entra no mapa de slots da conta' );

go_test_section( 'Markup do corpo depois da troca de formato' );
$a1_html = go_verge_adsense_unit_markup( 'article-a1' );
$a2_html = go_verge_adsense_unit_markup( 'article-a2' );
$a3_html = go_verge_adsense_unit_markup( 'article-a3' );
$all     = $a1_html . $a2_html . $a3_html;
go_test_ok( false === strpos( $all, 'data-ad-layout=' ), 'Nenhum host do corpo emite layout de In-article' );
go_test_ok( false === strpos( $all, 'data-ad-format="fluid"' ), 'Nenhum host do corpo emite formato fluid' );
go_test_ok( 3 === substr_count( $all, 'data-full-width-responsive="true"' ), 'Os três pedem expansão full-width, como o resto do corpo' );
go_test_ok( false === strpos( $all, '6368539121' ) && false === strpos( $all, '7554015324' ) && false === strpos( $all, '6240933652' ),
	'Nenhuma unidade In-article aposentada aparece no markup' );
