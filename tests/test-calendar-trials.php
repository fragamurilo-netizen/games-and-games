<?php
/**
 * Calendar trials: assignment, balance and the safety envelope.
 *
 * Three things have to hold, and the third is the reason this design was
 * acceptable at all:
 *
 *   1. the arm is a pure function of the date — same date, same arm, forever,
 *      and never anything about the reader;
 *   2. the rotation balances weekdays, so a comparison is not secretly a
 *      comparison of weekends against weekdays;
 *   3. an arm can only move the delivery-timing keys, and a misconfigured one
 *      degrades to the shipped table rather than to an unsafe page.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	exit;
}

require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/config.php';
require_once GO_VERGE_DIR . '/inc/ads/calendar-trials.php';

/**
 * Declare the trials the engine should see, replacing any previous declaration.
 *
 * @param array<int,array<string,mixed>> $trials Trial definitions.
 * @return void
 */
function go_test_install_trials( array $trials ) {
	$GLOBALS['go_test_filters']['go_verge_ads_trials'] = array(
		static function () use ( $trials ) {
			return $trials;
		},
	);
}

/** One two-arm trial that moves only the mobile standard lead. */
function go_test_trial( $start = '2026-01-01', $days = 1, $enabled = true ) {
	return array(
		array(
			'id'      => 'lead-trial',
			'enabled' => $enabled,
			'label'   => 'Teste',
			'start'   => $start,
			'days'    => $days,
			'arms'    => array(
				'base' => array(),
				'lead' => array( 'mobile' => array( 'rest_lead_vh' => array( 'standard' => 0.88 ), 'request_spacing_ms' => 120 ) ),
			),
		),
	);
}

go_test_section( 'A suíte não depende do dia em que roda' );

/*
 * Um teste habilitado muda a tabela de entrega nos dias que ele possui. Se o
 * bootstrap dos testes não o neutralizasse, qualquer suíte que fixa um limiar
 * publicado passaria num dia de linha de base e quebraria num dia de braço — um
 * vermelho que ninguém causou, que a próxima pessoa aprende a ignorar.
 */
go_test_equals( null, go_verge_ads_active_trial(), 'O bootstrap dos testes neutraliza os testes por dia' );
$neutral = go_verge_ads_delivery_rules();
go_test_equals( 0.75, (float) $neutral['mobile']['rest_lead_vh']['standard'], 'Então a tabela publicada vale em qualquer dia' );
go_test_equals( 240, (int) $neutral['mobile']['min_gap_px'], 'E o resto dela também' );

go_test_section( 'Atribuição é uma função pura da data' );

go_test_install_trials( go_test_trial() );
$trial = array(
	'id' => 'lead-trial', 'start' => '2026-01-01', 'days' => 1,
	'arms' => array( 'base' => array(), 'lead' => array() ),
);

$first = go_verge_ads_trial_arm_for( $trial, '2026-01-01' );
go_test_equals( 'base', $first['arm'], 'O primeiro dia do rodízio é a linha de base' );
go_test_equals( true, $first['baseline'], 'O primeiro braço é marcado como linha de base' );
go_test_equals( 'lead', go_verge_ads_trial_arm_for( $trial, '2026-01-02' )['arm'], 'O segundo dia troca de braço' );
go_test_equals( 'base', go_verge_ads_trial_arm_for( $trial, '2026-01-03' )['arm'], 'O terceiro dia volta à linha de base' );
go_test_equals( null, go_verge_ads_trial_arm_for( $trial, '2025-12-31' ), 'Um dia anterior ao início não pertence a braço nenhum' );
go_test_equals( null, go_verge_ads_trial_arm_for( $trial, 'ontem' ), 'Uma data inválida não recebe braço' );

/* Determinismo: a mesma data tem de dar o mesmo braço em qualquer momento. */
$stable = true;
foreach ( array( '2026-03-17', '2026-07-04', '2027-11-30' ) as $date ) {
	$once = go_verge_ads_trial_arm_for( $trial, $date );
	for ( $repeat = 0; $repeat < 50; $repeat++ ) {
		if ( go_verge_ads_trial_arm_for( $trial, $date ) !== $once ) { $stable = false; }
	}
}
go_test_ok( $stable, 'A mesma data devolve sempre o mesmo braço' );

/* Atravessa mudança de mês, ano e 29 de fevereiro sem pular nem repetir. */
$sequence = array();
for ( $offset = 0; $offset < 800; $offset++ ) {
	$date = gmdate( 'Y-m-d', strtotime( '2026-01-01 00:00:00 UTC' ) + $offset * 86400 );
	$sequence[] = go_verge_ads_trial_arm_for( $trial, $date )['arm'];
}
$alternates = true;
for ( $index = 1; $index < count( $sequence ); $index++ ) {
	if ( $sequence[ $index ] === $sequence[ $index - 1 ] ) { $alternates = false; }
}
go_test_ok( $alternates, 'O rodízio alterna todo dia por 800 dias, incluindo 29/02 e viradas de ano' );

go_test_section( 'O rodízio equilibra os dias da semana' );

/*
 * A propriedade que justifica o rodízio diário: como 2 e 7 não têm divisor
 * comum, em catorze dias cada braço recebe cada dia da semana exatamente uma
 * vez. Sem isso, um braço ficaria com os dois dias de fim de semana e a
 * diferença mediria o calendário em vez da configuração.
 */
$by_weekday = array();
for ( $offset = 0; $offset < 14; $offset++ ) {
	$stamp   = strtotime( '2026-01-01 00:00:00 UTC' ) + $offset * 86400;
	$date    = gmdate( 'Y-m-d', $stamp );
	$weekday = (int) gmdate( 'w', $stamp );
	$by_weekday[ go_verge_ads_trial_arm_for( $trial, $date )['arm'] ][ $weekday ] = ( $by_weekday[ go_verge_ads_trial_arm_for( $trial, $date )['arm'] ][ $weekday ] ?? 0 ) + 1;
}
$balanced = true;
foreach ( array( 'base', 'lead' ) as $arm ) {
	if ( count( $by_weekday[ $arm ] ?? array() ) !== 7 ) { $balanced = false; }
	foreach ( (array) ( $by_weekday[ $arm ] ?? array() ) as $count ) {
		if ( 1 !== $count ) { $balanced = false; }
	}
}
go_test_ok( $balanced, 'Em catorze dias cada braço recebe cada dia da semana exatamente uma vez' );

/* Com blocos de sete dias o equilíbrio semanal desaparece: o teste registra
 * isso para que a escolha de `days` seja consciente e não acidental. */
$weekly = array( 'id' => 'w', 'start' => '2026-01-01', 'days' => 7, 'arms' => array( 'base' => array(), 'lead' => array() ) );
$weekly_weekdays = array();
for ( $offset = 0; $offset < 14; $offset++ ) {
	$stamp = strtotime( '2026-01-01 00:00:00 UTC' ) + $offset * 86400;
	$weekly_weekdays[ go_verge_ads_trial_arm_for( $weekly, gmdate( 'Y-m-d', $stamp ) )['arm'] ][] = (int) gmdate( 'w', $stamp );
}
go_test_equals( 7, count( array_unique( $weekly_weekdays['base'] ) ), 'Blocos de sete dias também cobrem a semana inteira, só que em duas semanas' );

go_test_section( 'Uma configuração inválida não roda pela metade' );

go_test_install_trials( go_test_trial( '2026-01-01', 1, false ) );
go_test_equals( null, go_verge_ads_trial_arm_for( array( 'id' => 'x', 'start' => '2026-01-01', 'days' => 1, 'arms' => array( 'a' => array(), 'b' => array() ) ), '' ), 'Data vazia não recebe braço' );

/*
 * Cada caso abaixo tem de degradar para "sem teste", nunca para meio teste: um
 * teste que roda com metade da definição atribui dias a um braço que o operador
 * não desenhou, e o relatório depois afirma algo que nunca aconteceu.
 */
$broken = array(
	'sem data de início'     => array( 'id' => 'a', 'enabled' => true, 'start' => '', 'days' => 1, 'arms' => array( 'base' => array(), 'b' => array() ) ),
	'data malformada'        => array( 'id' => 'a', 'enabled' => true, 'start' => '01/01/2026', 'days' => 1, 'arms' => array( 'base' => array(), 'b' => array() ) ),
	'um único braço'         => array( 'id' => 'a', 'enabled' => true, 'start' => '2026-01-01', 'days' => 1, 'arms' => array( 'base' => array() ) ),
	'linha de base alterada' => array( 'id' => 'a', 'enabled' => true, 'start' => '2026-01-01', 'days' => 1, 'arms' => array( 'base' => array( 'mobile' => array( 'min_gap_px' => 400 ) ), 'b' => array() ) ),
	'sem id'                 => array( 'id' => '', 'enabled' => true, 'start' => '2026-01-01', 'days' => 1, 'arms' => array( 'base' => array(), 'b' => array() ) ),
);
foreach ( $broken as $label => $definition ) {
	go_test_install_trials( array( $definition ) );
	go_test_equals( null, go_verge_ads_active_trial(), 'Definição inválida não roda: ' . $label );
	go_test_equals( array(), go_verge_ads_trial_calendar( '2026-01-01', '2026-01-05' ), 'E não produz calendário: ' . $label );
}

/* Dois testes habilitados ao mesmo tempo se confundiriam. Nenhum roda. */
go_test_install_trials(
	array(
		array( 'id' => 'a', 'enabled' => true, 'start' => '2026-01-01', 'days' => 1, 'arms' => array( 'base' => array(), 'b' => array() ) ),
		array( 'id' => 'b', 'enabled' => true, 'start' => '2026-01-01', 'days' => 1, 'arms' => array( 'base' => array(), 'b' => array() ) ),
	)
);
go_test_equals( null, go_verge_ads_active_trial(), 'Dois testes habilitados ao mesmo tempo cancelam os dois' );

/* Um só, válido, volta a rodar. */
go_test_install_trials( go_test_trial( '2026-01-01', 1, true ) );
go_test_ok( is_array( go_verge_ads_active_trial() ), 'Um único teste válido roda' );

/* Um bloco absurdo é limitado, não recusado: 400 dias por braço ainda é um
 * teste, só que inútil, e recusá-lo silenciosamente seria pior. */
go_test_install_trials( array( array( 'id' => 'long', 'enabled' => true, 'start' => '2026-01-01', 'days' => 400, 'arms' => array( 'base' => array(), 'b' => array() ) ) ) );
go_test_equals( 28, (int) go_verge_ads_active_trial()['days'], 'Um bloco acima de 28 dias é limitado a 28' );
go_test_install_trials( array( array( 'id' => 'zero', 'enabled' => true, 'start' => '2026-01-01', 'days' => 0, 'arms' => array( 'base' => array(), 'b' => array() ) ) ) );
go_test_equals( 1, (int) go_verge_ads_active_trial()['days'], 'Um bloco de zero dias vira um dia em vez de dividir por zero' );

go_test_section( 'Um braço só move o que tem permissão para mover' );

/* Sem teste ligado, para que a mesclagem seja medida contra a tabela publicada
 * e não contra uma tabela que um braço já moveu. */
go_test_install_trials( go_test_trial( '2026-01-01', 1, false ) );
$base  = go_verge_ads_delivery_rules();
$shipped_lead = (float) $base['mobile']['rest_lead_vh']['standard'];
go_test_equals( 0.75, $shipped_lead, 'A tabela publicada entra no teste intacta' );
$moved = go_verge_ads_trial_merge_rules(
	$base,
	array(
		'mobile' => array(
			'rest_lead_vh'            => array( 'standard' => 0.88, 'inexistente' => 3.0 ),
			'request_spacing_ms'      => 130,
			/* Fora da lista: o envelope de segurança não é objeto de teste. */
			'max_units_in_window'     => 6,
			'max_local_ad_ratio'      => 0.60,
			'max_ad_to_content_ratio' => 0.60,
		),
	)
);
go_test_equals( 0.88, (float) $moved['mobile']['rest_lead_vh']['standard'], 'O braço move a antecipação do tier que nomeou' );
go_test_equals( $shipped_lead, (float) $base['mobile']['rest_lead_vh']['standard'], 'A tabela recebida não é modificada no lugar' );
go_test_equals( 0.60, (float) $moved['mobile']['rest_lead_vh']['deep'], 'Os demais tiers ficam onde a tabela publicada os colocou' );
go_test_ok( ! isset( $moved['mobile']['rest_lead_vh']['inexistente'] ), 'Um tier inventado não entra na escada' );
go_test_equals( 130, (int) $moved['mobile']['request_spacing_ms'], 'O braço move o espaçamento entre requests' );
go_test_equals( 3, (int) $moved['mobile']['max_units_in_window'], 'A densidade máxima por janela não é ajustável por um braço' );
go_test_equals( 0.45, (float) $moved['mobile']['max_local_ad_ratio'], 'A parcela local máxima de publicidade não é ajustável por um braço' );
go_test_equals( 0.45, (float) $moved['mobile']['max_ad_to_content_ratio'], 'A relação anúncio/conteúdo não é ajustável por um braço' );
go_test_equals( 300, (int) $moved['desktop']['min_gap_px'], 'Um braço que só nomeia mobile deixa o desktop intacto' );

$ignored = go_verge_ads_trial_merge_rules( $base, array( 'tablet' => array( 'min_gap_px' => 10 ), 'mobile' => array( 'min_gap_px' => 'muito' ) ) );
go_test_equals( 240, (int) $ignored['mobile']['min_gap_px'], 'Um valor não numérico é ignorado em vez de virar zero' );
go_test_ok( ! isset( $ignored['tablet'] ), 'Um perfil de dispositivo inexistente não é criado por um braço' );

go_test_section( 'O calendário do relatório concorda com a entrega' );

/* O relatório só é honesto se atribuir cada dia ao mesmo braço que o entregou.
 * São duas travessias independentes do mesmo cálculo, e têm de coincidir. */
go_test_install_trials( go_test_trial( '2026-01-01', 1, true ) );
$calendar = go_verge_ads_trial_calendar( '2026-01-01', '2026-01-10' );
go_test_equals( 10, count( $calendar ), 'O calendário cobre todos os dias do intervalo' );
$disagreements = array();
foreach ( $calendar as $date => $entry ) {
	$delivered = go_verge_ads_trial_arm_for( $trial, $date );
	if ( $entry['arm'] !== $delivered['arm'] ) { $disagreements[] = $date; }
}
go_test_equals( array(), $disagreements, 'Todo dia do relatório recebe o braço que a entrega usou' );
go_test_equals( 'base', $calendar['2026-01-01']['arm'], 'O calendário começa na linha de base' );
go_test_equals( 'lead', $calendar['2026-01-02']['arm'], 'E alterna junto com a entrega' );
go_test_equals( array(), go_verge_ads_trial_calendar( '2026-01-10', '2026-01-01' ), 'Um intervalo invertido devolve vazio em vez de girar' );
go_test_equals( array(), go_verge_ads_trial_calendar( '2026-01-01', '2035-01-01' ), 'Um intervalo absurdamente longo é recusado em vez de varrer anos' );

go_test_section( 'Sem teste habilitado, nada muda' );

go_test_install_trials( go_test_trial( '2026-01-01', 1, false ) );
$untouched = go_verge_ads_trial_filter_rules( go_verge_ads_delivery_rules() );
go_test_equals( 240, (int) $untouched['mobile']['min_gap_px'], 'Sem teste, o intervalo mínimo é o da tabela publicada' );
go_test_equals( 0.75, (float) $untouched['mobile']['rest_lead_vh']['standard'], 'Sem teste, a antecipação é a da tabela publicada' );
go_test_equals( null, go_verge_ads_trial_public_signal(), 'Sem teste, o navegador não recebe sinal de braço' );
go_test_ok( is_array( go_verge_ads_trial_filter_rules( 'não é tabela' ) ) === false, 'Uma tabela inválida volta como veio' );

go_test_section( 'Com teste ligado, a tabela realmente muda' );

/*
 * A ponta a ponta: um braço não-linha-de-base tem de chegar à tabela que o
 * navegador recebe, e a linha de base tem de deixá-la exatamente como estava.
 * Os dois braços são verificados na data que cada um possui.
 */
$live = go_test_trial( '2026-01-01', 1, true );
go_test_install_trials( $live );
$definition = go_verge_ads_active_trial();
$base_day = null;
$lead_day = null;
for ( $offset = 0; $offset < 4 && ( null === $base_day || null === $lead_day ); $offset++ ) {
	$date = gmdate( 'Y-m-d', strtotime( '2026-01-01 00:00:00 UTC' ) + $offset * 86400 );
	$arm  = go_verge_ads_trial_arm_for( $definition, $date );
	if ( 'base' === $arm['arm'] && null === $base_day ) { $base_day = $arm; }
	if ( 'lead' === $arm['arm'] && null === $lead_day ) { $lead_day = $arm; }
}
go_test_equals( true, $base_day['baseline'], 'O dia da linha de base é marcado como tal' );
go_test_equals( false, $lead_day['baseline'], 'O dia do braço alternativo não é linha de base' );

/*
 * A tabela de referência é a publicada, capturada com o teste desligado:
 * go_verge_ads_delivery_rules() já traz o braço de HOJE aplicado, e medir a
 * mesclagem contra ela compararia um braço consigo mesmo.
 */
go_test_install_trials( go_test_trial( '2026-01-01', 1, false ) );
$shipped = go_verge_ads_delivery_rules();
go_test_equals( 0.75, (float) $shipped['mobile']['rest_lead_vh']['standard'], 'A referência é a tabela publicada' );
go_test_install_trials( $live );

$arms = (array) $definition['arms'];
$as_delivered = go_verge_ads_trial_merge_rules( $shipped, (array) $arms[ $lead_day['arm'] ] );
go_test_equals( 0.88, (float) $as_delivered['mobile']['rest_lead_vh']['standard'], 'No dia do braço alternativo a antecipação entregue é a do braço' );
go_test_equals( 120, (int) $as_delivered['mobile']['request_spacing_ms'], 'E o espaçamento entre requests também' );
$as_baseline = go_verge_ads_trial_merge_rules( $shipped, (array) $arms[ $base_day['arm'] ] );
go_test_equals( 0.75, (float) $as_baseline['mobile']['rest_lead_vh']['standard'], 'No dia da linha de base a tabela publicada vale sem alteração' );

/*
 * E a tabela que o navegador realmente recebe hoje tem de corresponder ao
 * braço que a atribuição diz ser o de hoje — é essa concordância, e não a
 * mesclagem isolada, que faz o relatório significar alguma coisa.
 */
$today_arm = go_verge_ads_trial_assignment();
$today_rules = go_verge_ads_delivery_rules();
$expected_lead = empty( $arms[ $today_arm['arm'] ] ) ? 0.75 : 0.88;
go_test_equals( $expected_lead, (float) $today_rules['mobile']['rest_lead_vh']['standard'], 'A tabela entregue hoje corresponde ao braço de hoje (' . $today_arm['arm'] . ')' );

$signal = go_verge_ads_trial_public_signal();
go_test_equals( 'lead-trial', $signal['trial'], 'O navegador recebe o id do teste' );
go_test_equals( 'calendar-day', $signal['unit'], 'O sinal declara que a unidade de atribuição é o dia' );
go_test_ok( ! isset( $signal['reader'] ) && ! isset( $signal['bucket'] ) && ! isset( $signal['group'] ), 'O sinal não carrega nada sobre o leitor' );

go_test_section( 'O teste entregue habilitado é válido' );

unset( $GLOBALS['go_test_filters']['go_verge_ads_trials'] );
$shipped_on = 0;
foreach ( go_verge_ads_trials() as $declared ) {
	if ( ! empty( $declared['enabled'] ) ) { $shipped_on++; }
}
go_test_ok( $shipped_on <= 1, 'No máximo um teste vem habilitado', 'habilitados=' . $shipped_on );

$shipped_trial = go_verge_ads_active_trial();
if ( $shipped_on ) {
	go_test_ok( is_array( $shipped_trial ), 'O teste entregue é válido e roda' );
	go_test_equals( 'mobile-standard-lead', $shipped_trial['id'], 'É o teste de antecipação do tier standard no mobile' );
	$arms = (array) $shipped_trial['arms'];
	go_test_ok( empty( reset( $arms ) ), 'Com a linha de base intacta' );
	/* O que o braço move, e só isso. */
	$base = go_verge_ads_delivery_rules();
	$moved = go_verge_ads_trial_merge_rules( $base, (array) $arms['lead'] );
	go_test_equals( 0.88, (float) $moved['mobile']['rest_lead_vh']['standard'], 'O braço antecipa o tier standard no mobile' );
	go_test_equals( 0.75, (float) $base['mobile']['rest_lead_vh']['standard'], 'A tabela publicada mantém 0,75' );
	go_test_equals( 0.90, (float) $moved['mobile']['rest_lead_vh']['premium'], 'Nenhum outro tier é tocado' );
	go_test_equals( 0.65, (float) $moved['desktop']['rest_lead_vh']['standard'], 'E o desktop fica intacto' );
	go_test_equals( 240, (int) $moved['mobile']['min_gap_px'], 'O envelope de densidade não é tocado' );
}

go_test_section( 'O relatório não conta dias anteriores ao teste' );

/*
 * `start` é o que o operador declarou; não é prova de que o tema estava
 * instalado naquele dia. Sem piso, um teste iniciado no dia 22 e instalado no
 * 25 faria o relatório atribuir 22 a 24 — dias que rodaram outra configuração
 * inteira — a algum braço, e uma leitura inicial compararia o release consigo
 * mesmo.
 */
if ( $shipped_on ) {
	$GLOBALS['go_test_options'] = array();
	go_test_equals( '', go_verge_ads_trial_first_seen( $shipped_trial['id'] ), 'Sem marcador, não há primeiro dia registrado' );
	go_test_equals( (string) $shipped_trial['start'], go_verge_ads_trial_reportable_start( $shipped_trial ),
		'E o piso do relatório é a própria data de início' );

	$GLOBALS['go_test_options']['go_verge_ads_trial_first_seen'] = array( $shipped_trial['id'] => '2026-10-05' );
	go_test_equals( '2026-10-05', go_verge_ads_trial_reportable_start( $shipped_trial ),
		'Com marcador posterior, a contagem começa no dia em que o teste foi visto rodando' );

	$GLOBALS['go_test_options']['go_verge_ads_trial_first_seen'] = array( $shipped_trial['id'] => '2020-01-01' );
	go_test_equals( (string) $shipped_trial['start'], go_verge_ads_trial_reportable_start( $shipped_trial ),
		'Um marcador anterior à data de início não puxa dias de antes para dentro' );

	$GLOBALS['go_test_options']['go_verge_ads_trial_first_seen'] = array( $shipped_trial['id'] => 'ontem' );
	go_test_equals( (string) $shipped_trial['start'], go_verge_ads_trial_reportable_start( $shipped_trial ),
		'Um marcador malformado é ignorado em vez de virar piso' );
	$GLOBALS['go_test_options'] = array();
}
