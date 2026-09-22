<?php
/**
 * Administrative financial-classification scenarios.
 *
 * Financial observations remain useful in GOAC after their control over public
 * delivery is removed. Public-policy independence has its own regression test.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	exit;
}

require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/economics.php';
require_once GO_VERGE_DIR . '/inc/ads/yield.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

/**
 * Run one scenario and return the administrative financial classification.
 *
 * @param array<string,mixed> $scenario connected/today/intraday/unit_rows.
 * @return array<string,mixed>
 */
function go_test_decide( array $scenario ) {
	go_test_flush_transients();
	$GLOBALS['go_test_goac'] = array_merge(
		array( 'connected' => true, 'today' => '2026-09-20', 'intraday' => array(), 'unit_rows' => array(), 'daily_rows' => array() ),
		$scenario
	);
	return go_verge_ads_yield_decision();
}

/**
 * The internal decision for the same scenario.
 *
 * `floor_scale` never leaves the server: it scales the per-slot value floor the
 * revenue dashboard prints, and no delivery path consults it. Assertions about
 * it therefore have to read the decision, not the browser payload.
 */
function go_test_decision( array $scenario ) {
	go_test_decide( $scenario );
	return go_verge_ads_yield_decision();
}

/** The standard healthy inventory used when a scenario does not care about slots. */
function go_test_normal_units() {
	return go_test_unit_rows(
		array(
			'7792311754' => array( 'request_rpm' => 0.62, 'requests' => 40000, 'coverage' => 0.88 ),
			'3572313419' => array( 'request_rpm' => 0.55, 'requests' => 38000, 'coverage' => 0.90 ),
			'5017324239' => array( 'request_rpm' => 0.49, 'requests' => 30000, 'coverage' => 0.86 ),
			'5223365459' => array( 'request_rpm' => 0.44, 'requests' => 26000, 'coverage' => 0.84 ),
			'7131714626' => array( 'request_rpm' => 0.40, 'requests' => 22000, 'coverage' => 0.83 ),
			'4505551284' => array( 'request_rpm' => 0.34, 'requests' => 18000, 'coverage' => 0.82 ),
			'5056215625' => array( 'request_rpm' => 0.27, 'requests' => 14000, 'coverage' => 0.80 ),
			'6568236715' => array( 'request_rpm' => 0.23, 'requests' => 11000, 'coverage' => 0.79 ),
			'8238832024' => array( 'request_rpm' => 0.17, 'requests' => 8000,  'coverage' => 0.76 ),
			'5255155049' => array( 'request_rpm' => 0.14, 'requests' => 6000,  'coverage' => 0.74 ),
			'5798080525' => array( 'request_rpm' => 0.31, 'requests' => 9000,  'coverage' => 0.81 ),
		)
	);
}

go_test_section( 'Regime classification' );

/* ---------------------------------------------------------------- 1. The 19/09 fault */
$supply_deficit = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.8, 0.52 ),
			array( '2026-09-20' => go_test_day( 1200, 5.0, 0.50 ) )
		),
		'unit_rows' => go_test_normal_units(),
	)
);
go_test_equals( 'supply_deficit', $supply_deficit['regime'], '1. Preço saudável + entrega abaixo da fronteira = SUPPLY_DEFICIT' );
go_test_ok( $supply_deficit['supply_bias'] >= 1, '1b. SUPPLY_DEFICIT aumenta a urgência de entrega', 'bias=' . $supply_deficit['supply_bias'] );
go_test_ok( in_array( 'delivery-below-reference', $supply_deficit['reasons'], true ), '1c. Motivo declarado' );

/* ------------------------------------------------- 2. Price never manufactures slot count */
/*
 * 3.90 inverted Page RPM/iRPM and treated the result as a delivery target.
 * That assumes incremental impressions retain the current average price and
 * ignores the page's structural capacity. 4.0 uses the site's own manual
 * delivery history as a health reference; price can change ranking/timing but
 * cannot create a body-slot requirement.
 */
$cheap = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.4, 0.55 ),
			array( '2026-09-20' => go_test_day( 1200, 5.2, 0.40 ) )
		),
		'unit_rows' => go_test_normal_units(),
	)
);
go_test_equals( 'supply_deficit', $cheap['regime'], '2. Impressão barata + entrega curta = SUPPLY_DEFICIT' );
go_test_equals( 2, $cheap['supply_bias'], '2b. Gap de entrega pode pedir urgência máxima sem criar slots' );
go_test_ok( in_array( 'weak-price-does-not-cut-safe-inventory', $cheap['reasons'], true ), '2c. Preço fraco não corta inventário seguro' );
/* The decision array carries `floor_scale`, an ANALYSIS reference for the
 * dashboard — never a `floor`. Until 4.6 this line read $cheap['floor'], a key
 * that has never existed on this array, so it asserted `null <= 0.25` and
 * passed no matter what the controller did. */
go_test_ok( ! array_key_exists( 'floor', $cheap ), '2d. O sinal público não carrega mais um piso que nada consumia' );
go_test_ok( (float) go_verge_ads_yield_decision()['floor_scale'] <= 0.60,
	'2d2. Hora barata NÃO fica seletiva nem no relatório',
	'floor_scale=' . go_verge_ads_yield_decision()['floor_scale'] );

/* The reference is deliberately independent of price. */
/*
 * The delivery reference answers "is the SITE delivering like it has proven it
 * can?". It is not, and must never become, a per-page quota derived from price:
 * 3.90 inverted the Page-RPM identity into a required impression count and the
 * planner could not honour it. The shim that used to accept a price and ignore
 * it is gone; the reference now only takes a comparable historical delivery.
 */
/*
 * The assertions below read the frontier instead of repeating its numbers. The
 * reference moved once already — 7.80 was measured with Auto Ads in-page on, a
 * regime the account left on 20/08 — and every test that had hard-coded 7.8 had
 * to be edited by hand to follow it. What has to hold is the SHAPE: a canonical
 * base, peers that may raise it a little, peers that may never lower it, and a
 * hard ceiling. The number itself is evidence, and evidence is allowed to move.
 */
$frontier = go_verge_ads_yield_frontier();
$base     = go_verge_ads_yield_delivery_reference();
$ceiling  = (float) $frontier['delivery_reference_max'];
go_test_ok( abs( $base - (float) $frontier['delivery_reference_pv'] ) < 0.01,
	'2e. Sem histórico, a referência é a base canônica do frontier', (string) $base );
go_test_ok( $base > (float) $frontier['delivery_reference_min'],
	'2e2. E a base canônica fica acima do piso, senão o piso não protege nada' );
go_test_ok( go_verge_ads_yield_delivery_reference( 4.0 ) === $base,
	'2f. Uma janela ruim não ensina o controlador que a regressão virou normal' );
go_test_ok( go_verge_ads_yield_delivery_reference( $base + 1.0 ) > $base,
	'2g. Uma janela comprovadamente melhor pode elevar a referência' );
go_test_ok( go_verge_ads_yield_delivery_reference( 40.0 ) <= $ceiling,
	'2h. E o quanto ela pode subir é limitado', (string) go_verge_ads_yield_delivery_reference( 40.0 ) );
go_test_ok( ! function_exists( 'go_verge_ads_yield_required_delivery' ),
	'2i. O shim que aceitava um preço e o ignorava não existe mais' );
go_test_ok( go_verge_ads_yield_delivery_reference( $base + 0.20 ) <= $base + 0.51,
	'2g3. O quanto um histórico bom levanta a referência é limitado a meio imp/PV',
	(string) go_verge_ads_yield_delivery_reference( $base + 0.20 ) );
go_test_ok( abs( go_verge_ads_yield_delivery_reference( $base - 1.40 ) - $base ) < 0.01,
	'2g2. Release ruim não ensina o motor a aceitar regressão' );
/*
 * The reference must describe the regime the theme actually runs in. The
 * 13-19/08 window delivered 7.81 imp/PV with Auto Ads in-page ON; the contract
 * now says that format is off, so a reference at that level would put the
 * controller in permanent deficit against inventory it is not allowed to place.
 */
go_test_ok( $ceiling < 7.81,
	'2j. A referência não persegue a entrega da era Auto Ads in-page', (string) $ceiling );

/* PRICE_COMPRESSION still exists: weak price, but delivery already meets it. */
$compression = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.6, 0.80 ),
			array( '2026-09-20' => go_test_day( 1200, 7.6, 0.62 ) )
		),
		'unit_rows' => go_test_normal_units(),
	)
);
go_test_equals( 'price_compression', $compression['regime'], '2h. Preço fraco COM entrega suficiente = PRICE_COMPRESSION' );
go_test_equals( 0, $compression['supply_bias'], '2i. Compressão de preço NÃO corta capacidade segura' );
$compression_policy = go_verge_ads_yield_regime_policies()['price_compression'];
$deficit_policy     = go_verge_ads_yield_regime_policies()['supply_deficit'];
go_test_ok( (float) $compression_policy['floor_scale'] > (float) $deficit_policy['floor_scale'],
	'2j. Compressão eleva o piso analítico, não o orçamento',
	'compressão=' . $compression_policy['floor_scale'] . ' déficit=' . $deficit_policy['floor_scale'] );
go_test_equals( 0, (int) $compression['supply_bias'], '2j2. E nunca reduz o inventário estrutural' );

/* ---------------------------------------------------------------- 3. The death spiral, explicitly */
$spiral = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.8, 0.60 ),
			array( '2026-09-20' => go_test_day( 1200, 5.0, 0.45 ) )
		),
		'unit_rows' => go_test_normal_units(),
	)
);
go_test_ok(
	$spiral['supply_bias'] >= 1,
	'3. Preço caindo COM entrega curta restaura oferta (nunca corta)',
	'regime=' . $spiral['regime'] . ' bias=' . $spiral['supply_bias']
);

/* ---------------------------------------------------------------- 4. Harvest */
$harvest = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.4, 0.55 ),
			array( '2026-09-20' => go_test_day( 1200, 7.0, 0.95 ) )
		),
		'unit_rows' => go_test_normal_units(),
	)
);
go_test_equals( 'harvest', $harvest['regime'], '4. Preço muito acima do P75 dos pares = HARVEST' );
go_test_ok( $harvest['supply_bias'] >= 1, '4b. HARVEST antecipa a coleta sem fabricar capacidade', 'bias=' . $harvest['supply_bias'] );

/* ---------------------------------------------------------------- 5. Balanced */
$balanced = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.8, 0.60 ),
			array( '2026-09-20' => go_test_day( 1200, 7.8, 0.55 ) )
		),
		'unit_rows' => go_test_normal_units(),
	)
);
go_test_equals( 'balanced', $balanced['regime'], '5. Dentro da banda dos pares = BALANCED' );
go_test_equals( 0, $balanced['supply_bias'], '5b. BALANCED mantém urgência neutra' );

/* ---------------------------------------------------------------- 6. Coverage stress */
$coverage = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.4, 0.55 ),
			array( '2026-09-20' => go_test_day( 1200, 9.2, 0.52 ) )
		),
		'unit_rows' => go_test_unit_rows(
			array(
				'7792311754' => array( 'request_rpm' => 0.40, 'requests' => 40000, 'coverage' => 0.51 ),
				'3572313419' => array( 'request_rpm' => 0.36, 'requests' => 38000, 'coverage' => 0.48 ),
				'5017324239' => array( 'request_rpm' => 0.30, 'requests' => 30000, 'coverage' => 0.44 ),
				'5223365459' => array( 'request_rpm' => 0.26, 'requests' => 26000, 'coverage' => 0.40 ),
				'7131714626' => array( 'request_rpm' => 0.22, 'requests' => 22000, 'coverage' => 0.38 ),
				'4505551284' => array( 'request_rpm' => 0.18, 'requests' => 18000, 'coverage' => 0.35 ),
			)
		),
	)
);
go_test_equals( 'coverage_stress', $coverage['regime'], '6. Requests não viram matched requests = COVERAGE_STRESS' );
go_test_equals( 0, $coverage['supply_bias'], '6b. COVERAGE_STRESS não cria capacidade cega' );

/* Coverage stress outranks the delivery controller: when Google is already
 * declining most requests, volume is the one answer that does not work. */
$coverage_gap = go_test_decide(
	array(
		'intraday'  => array_merge(
			go_test_history( 8, 1200, 7.4, 0.55 ),
			array( '2026-09-20' => go_test_day( 1200, 4.6, 0.52 ) )
		),
		'unit_rows' => go_test_unit_rows(
			array(
				'7792311754' => array( 'request_rpm' => 0.40, 'requests' => 40000, 'coverage' => 0.51 ),
				'3572313419' => array( 'request_rpm' => 0.36, 'requests' => 38000, 'coverage' => 0.48 ),
				'5017324239' => array( 'request_rpm' => 0.30, 'requests' => 30000, 'coverage' => 0.44 ),
				'5223365459' => array( 'request_rpm' => 0.26, 'requests' => 26000, 'coverage' => 0.40 ),
				'7131714626' => array( 'request_rpm' => 0.22, 'requests' => 22000, 'coverage' => 0.38 ),
				'4505551284' => array( 'request_rpm' => 0.18, 'requests' => 18000, 'coverage' => 0.35 ),
			)
		),
	)
);
go_test_equals( 'coverage_stress', $coverage_gap['regime'], '6c. Cobertura quebrada vence o déficit de entrega' );
go_test_equals( 0, $coverage_gap['supply_bias'], '6d. Não se resolve cobertura fabricando volume' );

/* ---------------------------------------------------------------- 7. No data at all */
$blind = go_test_decide( array( 'connected' => false, 'intraday' => array(), 'unit_rows' => array() ) );
go_test_equals( 'unknown', $blind['regime'], '7. Sem dados financeiros = UNKNOWN' );
/* Missing money is not evidence for either expansion or braking. The base
 * planner inventory continues independently of the financial classifier. */
go_test_equals( 0, $blind['supply_bias'], '7b. Sem dados, não inventa urgência econômica' );
go_test_equals( 1.0, (float) go_verge_ads_yield_decision()['floor_scale'], '7c. Sem dados, piso analítico neutro' );
go_test_ok( ! array_key_exists( 'tier_floor', $blind ), '7d. Não existe mais tabela de pisos por tier para segurar reach' );
go_test_ok( $blind['supply_bias'] <= 1, '7e. UNKNOWN nunca vai ao máximo sem evidência' );

/* ---------------------------------------------------------------- 8. API connected, no rows yet */
$empty_lab = go_test_decide(
	array(
		'intraday'  => array( '2026-09-20' => go_test_day( 1200, 6.0, 0.50 ) ),
		'unit_rows' => array(),
	)
);
go_test_ok( in_array( $empty_lab['regime'], array( 'supply_deficit', 'balanced', 'unknown' ), true ), '8. Data Lab vazio degrada com segurança', 'regime=' . $empty_lab['regime'] );
go_test_equals( 0.0, (float) ( go_verge_ads_econ_slot_economics( true )['floor'] ?? 0 ),
	'8b. Sem modelo de slot, o piso analítico é zero e nada pode esconder inventário' );

/* ---------------------------------------------------------------- 9. Stale snapshot */
/*
 * Freshness is measured against the account's clock, so this pair only means
 * anything with the clock pinned: at 14:00 a snapshot ending at 13:50 is fresh
 * and one ending at 06:00 is eight hours old. Without the pin the same two
 * fixtures both read as fresh whenever the suite runs before 07:00 in São
 * Paulo, and the scenario tests nothing.
 */
go_test_pin_clock( 840 );

$stale_history = go_test_history( 8, 1200, 7.8, 0.55 );

/* The identical under-delivering day, told twice: once with the last sync ten
 * minutes ago, once with it eight hours ago. Same rates, so every ratio the
 * engine reads is the same and only the freshness differs. */
$fresh_pair = go_test_decide(
	array(
		'intraday'  => array_merge( $stale_history, array( '2026-09-20' => go_test_day( 1200, 5.2, 0.52, 830 ) ) ),
		'unit_rows' => go_test_normal_units(),
	)
);
$fresh_decision = go_verge_ads_yield_decision();

$stale = go_test_decide(
	array(
		'intraday'  => array_merge( $stale_history, array( '2026-09-20' => go_test_day( 1200, 5.2, 0.52, 360 ) ) ),
		'unit_rows' => go_test_normal_units(),
	)
);
$stale_decision = go_verge_ads_yield_decision();

/* No stale price may classify the current auction. Neutral economic controls
 * preserve structural inventory without expanding from obsolete evidence. */
go_test_equals( 0, $stale['supply_bias'], '9. Dados atrasados não inventam urgência de entrega' );
go_test_ok( '' !== $stale['regime'], '9b. Dados atrasados ainda produzem uma decisão' );
go_test_ok( ! $stale_decision['fresh'] && $fresh_decision['fresh'],
	'9c. O par difere exatamente em uma coisa: a idade do snapshot',
	'fresh=' . var_export( $fresh_decision['fresh'], true ) . ' stale=' . var_export( $stale_decision['fresh'], true ) );
go_test_equals( 'none', $stale_decision['confidence'], '9d. Acumulado velho não substitui evidência atual' );
go_test_ok( in_array( 'snapshot-stale', (array) $stale_decision['reasons'], true ),
	'9e. E se nomeia como tal', implode( ',', (array) $stale_decision['reasons'] ) );
go_test_equals( null, $stale_decision['price'], '9f. Dado velho não tem preço atual presumido' );
/* Toward neutral, not to neutral: the floor gets less extreme, in whichever
 * direction the regime had pushed it. Asserting a fixed number here would just
 * pin today's policy table; what has to hold is the direction. */
go_test_ok(
	abs( (float) $stale_decision['floor_scale'] - 1.0 ) < abs( (float) $fresh_decision['floor_scale'] - 1.0 ),
	'9g. Dados atrasados puxam o piso analítico na direção do neutro',
	'fresco=' . $fresh_decision['floor_scale'] . ' atrasado=' . $stale_decision['floor_scale']
);

go_test_pin_clock( null );

go_test_section( 'Invariantes estruturais de política' );

$regimes = go_verge_ads_yield_regime_policies();
foreach ( $regimes as $name => $policy ) {
	go_test_ok( (int) $policy['supply_bias'] >= 0, 'Invariante: ' . $name . ' nunca usa urgência negativa', 'bias=' . $policy['supply_bias'] );
	go_test_ok( ! array_key_exists( 'tier_floor', $policy ), 'Invariante: ' . $name . ' não tem tabela de pisos por tier' );
	go_test_ok( (float) $policy['tier_lookahead']['reach'] >= 1.0, 'Invariante: ' . $name . ' nunca atrasa reach', (string) $policy['tier_lookahead']['reach'] );
	go_test_ok( (float) $policy['tier_lookahead']['premium'] >= 1.0, 'Invariante: ' . $name . ' nunca atrasa premium', (string) $policy['tier_lookahead']['premium'] );
	foreach ( array( 'standard', 'deep', 'completion' ) as $tier ) {
		go_test_ok( (float) $policy['tier_lookahead'][ $tier ] >= 1.0, 'Invariante: ' . $name . ' nunca atrasa ' . $tier, (string) $policy['tier_lookahead'][ $tier ] );
	}
}

$dayparts = go_verge_ads_yield_daypart_priors();
foreach ( $dayparts as $name => $prior ) {
	go_test_ok( ! array_key_exists( 'budget_delta', $prior ), 'Invariante: daypart ' . $name . ' não altera orçamento, só timing e piso' );
	go_test_ok( (float) $prior['lookahead_scale'] >= 1.0, 'Invariante: daypart ' . $name . ' nunca atrasa request abaixo da base', (string) $prior['lookahead_scale'] );
}

go_test_section( 'Modelo econômico por slot' );

go_test_flush_transients();
$GLOBALS['go_test_goac'] = array( 'connected' => true, 'today' => '2026-09-20', 'intraday' => array(), 'unit_rows' => go_test_normal_units() );
$econ = go_verge_ads_econ_slot_economics( true );

go_test_ok( $econ['slots']['7792311754'] > $econ['slots']['5255155049'], 'Top Scroll vale mais que A6 no modelo de 7 dias' );
go_test_ok( $econ['slots']['5255155049'] >= 0.25, 'Mesmo o slot mais fraco mantém um peso positivo (nunca zero absoluto)' );
go_test_ok( $econ['floor'] <= 0.42 && $econ['floor'] >= 0, 'Piso marginal permanece limitado', 'floor=' . $econ['floor'] );
go_test_ok( null !== $econ['coverage_site'], 'Cobertura absoluta do site é calculada' );
go_test_ok( isset( $econ['viewability_abs']['7792311754'] ), 'Active View histórico por slot é preservado para timing/diagnóstico' );

/* Shrinkage: a tiny sample must not outrank a proven unit. */
go_test_flush_transients();
$GLOBALS['go_test_goac']['unit_rows'] = go_test_unit_rows(
	array(
		'7792311754' => array( 'request_rpm' => 0.60, 'requests' => 50000, 'coverage' => 0.88 ),
		'3572313419' => array( 'request_rpm' => 0.50, 'requests' => 40000, 'coverage' => 0.88 ),
		'5017324239' => array( 'request_rpm' => 0.45, 'requests' => 30000, 'coverage' => 0.86 ),
		/* 120 requests, one lucky click. */
		'5255155049' => array( 'request_rpm' => 9.00, 'requests' => 120, 'coverage' => 0.80 ),
	)
);
$shrunk = go_verge_ads_econ_slot_economics( true );
go_test_ok(
	$shrunk['slots']['5255155049'] < $shrunk['slots']['7792311754'] * 1.15,
	'Amostra minúscula é encolhida para o prior do tier',
	'A6=' . $shrunk['slots']['5255155049'] . ' vs TopScroll=' . $shrunk['slots']['7792311754']
);

/* Click-quality risk: high CTR without matching revenue is flagged, never rewarded. */
go_test_flush_transients();
$GLOBALS['go_test_goac']['unit_rows'] = go_test_unit_rows(
	array(
		'7792311754' => array( 'request_rpm' => 0.50, 'requests' => 40000, 'coverage' => 0.88, 'ctr' => 0.011 ),
		'3572313419' => array( 'request_rpm' => 0.48, 'requests' => 38000, 'coverage' => 0.88, 'ctr' => 0.012 ),
		'5017324239' => array( 'request_rpm' => 0.45, 'requests' => 30000, 'coverage' => 0.86, 'ctr' => 0.012 ),
		'8238832024' => array( 'request_rpm' => 0.44, 'requests' => 20000, 'coverage' => 0.84, 'ctr' => 0.050 ),
	)
);
$risky = go_verge_ads_econ_slot_economics( true );
go_test_ok( isset( $risky['quality_risk']['8238832024'] ), 'CTR anômalo sem receita correspondente é sinalizado como risco' );
go_test_ok( ! isset( $risky['quality_risk']['7792311754'] ), 'Unidade saudável não é sinalizada' );

/* PHP turns numeric-string keys into integers. If the public signal leaked that
 * typing, the runtime's String(slot) comparison would never match and the
 * click-quality guard would be silently inert. */
$public = go_verge_ads_yield_public_signal();
go_test_ok( isset( $public['slot_viewability']['7792311754'] ), 'Viewability absoluto chega ao runtime como sinal bounded, sem valores de receita' );
go_test_ok( ! isset( $public['slot_risk'] ), 'A lista de risco de clique fica no servidor: nada no navegador a consumia' );
go_test_ok( isset( $risky['quality_risk']['8238832024'] ), 'O sinal de risco continua disponível para o painel administrativo' );
foreach ( array_keys( (array) $public['slot_value'] ) as $key ) {
	go_test_ok( 6 <= strlen( (string) $key ), 'Chave de slot preservada no payload público', var_export( $key, true ) );
}
go_test_ok(
	'{' === substr( (string) wp_json_encode( $public['slot_value'] ), 0, 1 ),
	'slot_value é serializado como objeto, não como lista'
);

go_test_section( 'Cobertura do inventário da conta' );

/*
 * The 20 ad units that exist in this AdSense account, verbatim. Any unit the
 * theme can serve but the economic model cannot see is a unit whose value the
 * engine never learns — which is how the two vertical mastheads sat outside the
 * seven-day model while being served on the two commercial hubs.
 */
$account_units = array(
	'7792311754' => 'GO_V4_GLOBAL_ALL_TOPSCROLL_DISPLAY',
	'3572313419' => 'GO_V3_SINGLE_ALL_TOP_DISPLAY',
	'7835738857' => 'OD383_TECNOLOGIA_TOP_DISPLAY',
	'2789005317' => 'OD383_ENTRETENIMENTO_TOP_DISPLAY',
	'5017324239' => 'GO_V3_SINGLE_ALL_HERO_OVERLAY_DISPLAY',
	'6489083385' => 'GO_V2_Single_Desktop_Sidebar_Sticky',
	'1188364638' => 'GO Game Hub Mid',
	'5223365459' => 'GO Article Prime P1',
	'7131714626' => 'GO Article A1',
	'4505551284' => 'GO Article A2',
	'5056215625' => 'GO Article A3',
	'6568236715' => 'GO Article A4',
	'8238832024' => 'GO Article A5',
	'5255155049' => 'GO Article A6',
	'5798080525' => 'GO Article End D1',
	'4927851985' => 'GO Listing F1',
	'3996334686' => 'GO Listing F2',
	'2880273141' => 'GO Listing F3',
	'4207836686' => 'GO Listing F4',
	'4704776118' => 'GO Listing F5',
	'6795467428' => 'GO Home M1',
	'6925750357' => 'GO Home M2',
);
$slot_map = go_verge_ads_all_slots();
$tier_map = go_verge_ads_econ_slot_tiers();
foreach ( $account_units as $slot => $name ) {
	go_test_ok( isset( $slot_map[ $slot ] ), 'Unidade mapeada no tema: ' . $name, $slot );
	go_test_ok( isset( $tier_map[ $slot ] ), 'Unidade visível ao modelo econômico: ' . $name, $slot );
}
go_test_equals( count( $account_units ), count( $slot_map ), 'Nenhum slot no tema sem unidade na conta' );

/*
 * A unidade tem que ser pedida no formato que ela É: uma unidade fluid pedida
 * com data-ad-format="auto" é outra unidade para o leilão, e simplesmente não
 * preenche. Desde a 5.0.3 o corpo inteiro é Display responsivo — oito posições,
 * um produto só — então a comparação entre elas passa a ser profundidade.
 */
$inventory = go_verge_ads_inventory();
foreach ( array( 'article-prime', 'article-a1', 'article-a2', 'article-a3', 'article-a4', 'article-a5', 'article-a6', 'article-end' ) as $placement ) {
	go_test_equals( 'responsive', (string) $inventory[ $placement ]['sizing'], $placement . ' é display responsivo' );
	go_test_ok( ! isset( $inventory[ $placement ]['ad_layout'] ), $placement . ' não declara ad_layout de in-article' );
}

go_test_section( 'A escada de capacidade é do planner, não do controlador financeiro' );

/*
 * Until 4.6 this module also published a per-word "article_total" ladder. It
 * had already stopped deciding anything — planner telemetry overrode it on
 * every real article — but it was still sent to the browser and still printed
 * in the dashboard as if it governed inventory. The only ladder now is the
 * planner's, and it is reachable from one function.
 */
$frontier = go_verge_ads_yield_frontier();
go_test_ok( ! isset( $frontier['article_total'] ), 'A escada advisória deixou de existir' );
go_test_ok( ! isset( $frontier['body_max'] ) && ! isset( $frontier['total_max'] ), 'Tetos duplicados de inventário deixaram de existir' );
foreach ( array( 'delivery_reference_pv', 'success_page_rpm', 'irpm_healthy', 'irpm_viable' ) as $key ) {
	go_test_ok( isset( $frontier[ $key ] ), 'A referência econômica preserva ' . $key );
}

$previous = 0;
foreach ( array( 200, 260, 320, 480, 600, 800, 1000, 1400, 3000 ) as $words ) {
	$rung = go_verge_ads_planner_capacity_from_words( $words );
	go_test_ok( $rung >= $previous, 'Escada do planner é monotônica em ' . $words . ' palavras' );
	go_test_ok( $rung <= 7, 'Escada do planner respeita o teto de sete posições no corpo' );
	$previous = $rung;
}
go_test_equals( 7, go_verge_ads_planner_capacity_from_words( 3000 ), 'Longform satura o corpo em sete posições' );
go_test_equals( 0, go_verge_ads_planner_capacity_from_words( 200 ), 'Nota curta não recebe inventário no corpo' );

/* The browser rule table must arrive complete: every threshold has exactly one
 * definition, and it is this one. */
$rules = go_verge_ads_delivery_rules();
go_test_ok( isset( $rules['mobile'], $rules['desktop'] ), 'A tabela de regras é dividida por dispositivo' );
go_test_ok( (int) $rules['desktop']['min_gap_px'] > (int) $rules['mobile']['min_gap_px'], 'Desktop espaça mais que mobile, não o contrário' );
go_test_ok( (int) $rules['mobile']['min_gap_px'] >= (int) go_verge_ads_planner_clearance()['height'], 'O piso do navegador é calibrado contra a folga do planner' );
go_test_ok( (float) $rules['mobile']['max_lookahead_vh'] <= 5.0 && (float) $rules['mobile']['max_lookahead_vh'] >= 1.0, 'O teto de lookahead é limitado' );
go_test_ok( (int) $rules['stuck_release_ms'] >= 4000, 'A liberação de oportunidade silenciosa nunca é agressiva' );
