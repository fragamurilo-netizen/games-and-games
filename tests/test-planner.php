<?php
/**
 * Structural planner simulation.
 *
 * Builds synthetic articles at the lengths and shapes the site actually
 * publishes and checks the inventory the planner produces: count, ordering,
 * editorial clearance and the protected-neighbour rules.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	exit;
}

require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/ads/planner.php';

/** A paragraph of roughly $words words. */
function go_test_paragraph( $words ) {
	$vocabulary = array( 'jogo', 'lançamento', 'console', 'estúdio', 'história', 'personagem', 'atualização', 'temporada', 'gráficos', 'desempenho', 'narrativa', 'multijogador', 'expansão', 'trilha', 'jogabilidade' );
	$out = array();
	for ( $i = 0; $i < $words; $i++ ) {
		$out[] = $vocabulary[ $i % count( $vocabulary ) ];
	}
	return '<p>' . ucfirst( implode( ' ', $out ) ) . '.</p>';
}
function go_test_heading( $text = 'O que muda agora' ) {
	return '<h2>' . $text . '</h2>';
}
function go_test_list( $items, $words_each = 12 ) {
	$out = '<ul>';
	for ( $i = 0; $i < $items; $i++ ) {
		$out .= '<li>' . strip_tags( go_test_paragraph( $words_each ) ) . '</li>';
	}
	return $out . '</ul>';
}
function go_test_figure() {
	return '<figure><img src="https://example.test/a.jpg" alt="cena"><figcaption>Uma cena do jogo.</figcaption></figure>';
}

/** Classic news/review: paragraphs, one heading every few paragraphs, some media. */
function go_test_prose_article( $target_words ) {
	$html = '';
	$words = 0;
	$index = 0;
	while ( $words < $target_words ) {
		$chunk = 55 + ( $index % 3 ) * 20;
		$html .= go_test_paragraph( $chunk );
		$words += $chunk;
		$index++;
		if ( 0 === $index % 4 && $words < $target_words ) {
			$html .= go_test_heading();
		}
		if ( 0 === $index % 7 && $words < $target_words ) {
			$html .= go_test_figure();
		}
	}
	return $html;
}

/** Listicle/ranking: heading + short intro + list, repeated. */
function go_test_list_article( $sections ) {
	$html = go_test_paragraph( 70 );
	for ( $i = 1; $i <= $sections; $i++ ) {
		$html .= go_test_heading( $i . '. Um item do ranking' );
		$html .= go_test_paragraph( 45 );
		$html .= go_test_list( 5, 14 );
	}
	return $html . go_test_paragraph( 60 );
}

go_test_section( 'Escada estrutural por tamanho (artigo em prosa)' );

$expectations = array(
	/* words, minimum in-body opportunities the planner must find */
	array( 250,  1 ),
	array( 350,  2 ),
	array( 500,  3 ),
	array( 700,  4 ),
	array( 1000, 5 ),
	array( 1500, 6 ),
	array( 2500, 6 ),
);

foreach ( $expectations as $case ) {
	list( $words, $minimum ) = $case;
	$plan = go_verge_ads_plan_article( go_test_prose_article( $words ) );
	$planned = (int) $plan['plannedCount'];
	go_test_ok(
		$planned >= $minimum,
		sprintf( 'Prosa ~%d palavras: pelo menos %d posições no corpo', $words, $minimum ),
		'obtido ' . $planned . ' (bodyWords=' . $plan['metrics']['bodyWords'] . ', capacidade=' . $plan['totalCapacity'] . ')'
	);
	go_test_ok( $planned <= 7, sprintf( 'Prosa ~%d palavras: nunca acima de 7 no corpo', $words ), 'obtido ' . $planned );
}

go_test_section( 'Escada Revenue Max e alcance inicial' );

go_test_equals( 4, go_verge_ads_planner_capacity_from_words( 679 ), '679 palavras: teto estrutural 4' );
go_test_equals( 5, go_verge_ads_planner_capacity_from_words( 700 ), '700 palavras: expõe quinta oportunidade para leitor profundo' );
go_test_equals( 6, go_verge_ads_planner_capacity_from_words( 900 ), '900 palavras: expõe sexta oportunidade sob densidade real' );
go_test_equals( 7, go_verge_ads_planner_capacity_from_words( 1200 ), '1200 palavras: permite escada completa Prime + A1..A6' );
$medium_reach = go_verge_ads_plan_article( str_repeat( go_test_paragraph( 70 ), 8 ) );
go_test_ok( ! empty( $medium_reach['prime'] ) && (int) $medium_reach['prime']['substantialBefore'] === 1, 'Matéria média de 560 palavras pode monetizar após uma abertura forte de 70 palavras' );

go_test_section( 'Listicles e rankings (regressão 14.5)' );

$list_plan = go_verge_ads_plan_article( go_test_list_article( 8 ) );
go_test_ok(
	$list_plan['metrics']['listWords'] > 400,
	'Listas contam como conteúdo editorial',
	'listWords=' . $list_plan['metrics']['listWords']
);
go_test_ok(
	$list_plan['plannedCount'] >= 4,
	'Um ranking longo recebe inventário de corpo real, não uma posição',
	'obtido ' . $list_plan['plannedCount'] . ' (bodyWords=' . $list_plan['metrics']['bodyWords'] . ')'
);

/* A list with commercial markup stays atomic, exactly as before. */
$affiliate = go_test_paragraph( 80 ) . '<ul><li><a href="https://amzn.to/x">Compre aqui</a></li><li>Outro item</li></ul>' . go_test_paragraph( 80 );
$affiliate_plan = go_verge_ads_plan_article( $affiliate );
$has_list_block = false;
foreach ( $affiliate_plan['metrics'] as $key => $value ) {
	if ( 'listWords' === $key && $value > 0 ) {
		$has_list_block = true;
	}
}
go_test_ok( ! $has_list_block, 'Lista com link de afiliado permanece componente atômico' );

go_test_section( 'Tabelas e listas de definição editoriais contam sem virar superfície de anúncio' );
$table_words = strip_tags( go_test_paragraph( 240 ) );
$atomic_table_html = str_repeat( go_test_paragraph( 80 ), 4 )
	. '<table><tr><th>Item</th><th>Dado</th></tr><tr><td>' . $table_words . '</td><td>valor editorial</td></tr></table>'
	. str_repeat( go_test_paragraph( 80 ), 4 );
$atomic_table_plan = go_verge_ads_plan_article( $atomic_table_html );
go_test_ok( $atomic_table_plan['metrics']['atomicTextWords'] >= 240, 'Tabela editorial estática conta palavras sem deixar de ser atômica' );
go_test_ok( $atomic_table_plan['metrics']['bodyWords'] >= 880, 'Palavras da tabela entram no comprimento editorial do artigo' );
$table_start = strpos( $atomic_table_html, '<table' );
$table_end = strpos( $atomic_table_html, '</table>' ) + strlen( '</table>' );
foreach ( array_merge( array_filter( array( $atomic_table_plan['prime'] ) ), (array) $atomic_table_plan['selected'], (array) $atomic_table_plan['reserves'] ) as $placement ) {
	go_test_ok( (int) $placement['position'] <= $table_start || (int) $placement['position'] >= $table_end, 'Nenhuma oportunidade é inserida dentro da tabela editorial' );
}
$commercial_table = str_repeat( go_test_paragraph( 80 ), 4 )
	. '<table class="go-review"><tr><td>' . $table_words . '</td></tr></table>'
	. str_repeat( go_test_paragraph( 80 ), 4 );
$commercial_table_plan = go_verge_ads_plan_article( $commercial_table );
go_test_equals( 0, $commercial_table_plan['metrics']['atomicTextWords'], 'Tabela comercial/protegida não compra capacidade editorial' );



go_test_section( 'Citações jornalísticas contam como conteúdo editorial' );
function go_test_quote( $words ) {
	return '<blockquote>' . implode( ' ', array_fill( 0, $words, 'declaração' ) ) . '.</blockquote>';
}
$plain_720 = str_repeat( go_test_paragraph( 120 ), 6 );
$quote_720 = go_test_paragraph( 120 ) . go_test_quote( 120 ) . go_test_paragraph( 120 ) . go_test_quote( 120 ) . go_test_paragraph( 120 ) . go_test_paragraph( 120 );
$plain_plan_720 = go_verge_ads_plan_article( $plain_720 );
$quote_plan_720 = go_verge_ads_plan_article( $quote_720 );
go_test_equals( 720, (int) $quote_plan_720['metrics']['bodyWords'], 'Palavras em blockquote permanecem no corpo editorial' );
go_test_equals( 240, (int) $quote_plan_720['metrics']['quoteWords'], 'Planner mede separadamente palavras de citação' );
go_test_equals( (int) $plain_plan_720['ladderCapacity'], (int) $quote_plan_720['ladderCapacity'], 'Mover 240 palavras para citações não rebaixa a escada por tamanho' );
go_test_ok( (int) $quote_plan_720['plannedCount'] >= 4, 'Notícia de 720 palavras com citações mantém inventário compatível com a leitura real', 'planejado=' . $quote_plan_720['plannedCount'] );
$quote_blocks = go_verge_ads_planner_blocks( $quote_720 );
$quote_inside = 0;
foreach ( array_merge( $quote_plan_720['prime'] ? array( $quote_plan_720['prime'] ) : array(), $quote_plan_720['selected'] ) as $selected ) {
	foreach ( $quote_blocks as $block ) {
		if ( 'quote' === $block['kind'] && (int) $selected['position'] > (int) $block['start'] && (int) $selected['position'] < (int) $block['end'] ) {
			$quote_inside++;
		}
	}
}
go_test_equals( 0, $quote_inside, 'Nenhum anúncio é inserido dentro de blockquote' );

go_test_section( 'Segurança editorial' );

/* No ad may be planned between a heading and its own first paragraph. */
$plan = go_verge_ads_plan_article( go_test_prose_article( 1800 ) );
$blocks = go_verge_ads_planner_blocks( go_test_prose_article( 1800 ) );
$positions = array();
foreach ( array_merge( $plan['prime'] ? array( $plan['prime'] ) : array(), $plan['selected'] ) as $selected ) {
	$positions[] = (int) $selected['position'];
}
$violations = 0;
foreach ( $positions as $position ) {
	foreach ( $blocks as $index => $block ) {
		if ( (int) $block['end'] !== $position ) {
			continue;
		}
		$next = $blocks[ $index + 1 ] ?? null;
		/* Legal: prose|list followed by prose|list, or a section break where the
		 * NEXT block is an h2/h3 that opens its own section. */
		$a_ok = in_array( $block['kind'], array( 'prose', 'list' ), true );
		$b_ok = $next && ( in_array( $next['kind'], array( 'prose', 'list' ), true )
			|| ( 'heading' === $next['kind'] && in_array( $next['tag'], array( 'h2', 'h3' ), true ) ) );
		if ( ! $a_ok || ! $b_ok ) {
			$violations++;
		}
	}
}
go_test_equals( 0, $violations, 'Nenhuma inserção separa um título do próprio texto ou toca um componente' );

/* Protected components are never neighbours. */
$protected = go_test_paragraph( 90 )
	. '<div class="go-cta">Assine a newsletter</div>'
	. go_test_paragraph( 90 )
	. '<table><tr><td>Plataforma</td><td>Nota</td></tr></table>'
	. go_test_paragraph( 90 );
$protected_plan = go_verge_ads_plan_article( $protected );
$protected_blocks = go_verge_ads_planner_blocks( $protected );
$bad = 0;
foreach ( array_merge( $protected_plan['prime'] ? array( $protected_plan['prime'] ) : array(), $protected_plan['selected'] ) as $selected ) {
	foreach ( $protected_blocks as $index => $block ) {
		if ( (int) $block['end'] !== (int) $selected['position'] ) {
			continue;
		}
		$next = $protected_blocks[ $index + 1 ] ?? null;
		if ( 'component' === $block['kind'] || ( $next && 'component' === $next['kind'] ) ) {
			$bad++;
		}
	}
}
go_test_equals( 0, $bad, 'CTA e tabela nunca ficam encostados num anúncio' );

go_test_section( 'Clearance e ordenação' );

$long = go_test_prose_article( 2600 );
$long_plan = go_verge_ads_plan_article( $long );
$order = array();
foreach ( $long_plan['selected'] as $selected ) {
	$order[] = (int) $selected['beforeWords'];
}
$sorted = $order;
sort( $sorted, SORT_NUMERIC );
go_test_equals( $sorted, $order, 'A1..A6 saem em ordem crescente de profundidade' );

$gaps_ok = true;
for ( $i = 1; $i < count( $order ); $i++ ) {
	if ( $order[ $i ] - $order[ $i - 1 ] < 95 ) {
		$gaps_ok = false;
	}
}
go_test_ok( $gaps_ok, 'Espaçamento mínimo de palavras entre posições consecutivas é respeitado' );

if ( $long_plan['prime'] ) {
	go_test_ok( (float) $long_plan['prime']['depth'] <= 0.46, 'Prime P1 permanece na metade inicial do artigo', 'depth=' . $long_plan['prime']['depth'] );
	go_test_ok( (int) $long_plan['prime']['substantialBefore'] >= 2, 'Prime P1 só aparece após dois blocos substanciais' );
}

go_test_section( 'Regressões de produção 4.0' );

$medium = str_repeat( go_test_paragraph( 70 ), 8 );
$medium_plan = go_verge_ads_plan_article( $medium );
go_test_equals( 4, (int) $medium_plan['ladderCapacity'], '560 palavras mantêm teto-base de quatro posições' );
go_test_equals( 2, (int) $medium_plan['headroom'], '560 palavras com oito blocos substanciais e boundaries extras ganham os dois passos estruturais' );
go_test_ok( (int) $medium_plan['plannedCount'] >= 5, 'O passo estrutural vira posição real quando a geometria editorial comprova espaço', 'planejado=' . $medium_plan['plannedCount'] );
go_test_ok( (int) $medium_plan['renderedCount'] >= (int) $medium_plan['plannedCount'], 'Planner materializa hosts suficientes para o runtime decidir com pixels reais' );
go_test_ok( (int) $medium_plan['totalCapacity'] === (int) $medium_plan['renderedCount'], 'Capacidade de EXPANSÃO é exatamente o que foi renderizado' );
go_test_ok( (int) $medium_plan['totalCapacity'] <= 7, 'Capacidade nunca rompe o teto global de sete posições' );

$short_no_headroom = go_verge_ads_plan_article( str_repeat( go_test_paragraph( 70 ), 5 ) );
go_test_equals( 0, (int) $short_no_headroom['headroom'], 'Matéria abaixo de 480 palavras não recebe passo estrutural' );
$long_no_headroom = go_verge_ads_plan_article( go_test_prose_article( 1500 ) );
go_test_equals( 0, (int) $long_no_headroom['headroom'], 'Longform já no teto 7 não recebe oitava posição' );
go_test_ok( (int) $long_no_headroom['totalCapacity'] <= 7, 'Capacidade nunca rompe o teto global de sete posições' );

go_test_section( 'Formato editorial ajusta o teto estrutural' );
$guide_html = str_repeat( go_test_paragraph( 70 ), 9 );
$news_guide_plan = go_verge_ads_plan_article( $guide_html, 'news' );
$guide_plan      = go_verge_ads_plan_article( $guide_html, 'guide' );
go_test_equals( 4, (int) $news_guide_plan['ladderCapacity'], 'Notícia de 630 palavras usa a escada de palavras pura' );
go_test_equals( 5, (int) $guide_plan['ladderCapacity'], 'Guia do mesmo tamanho ganha exatamente um degrau' );
go_test_ok( (int) $guide_plan['plannedCount'] >= (int) $news_guide_plan['plannedCount'], 'O degrau de formato nunca reduz o inventário planejado' );
go_test_equals( 'guide', (string) $guide_plan['articleType'], 'O tipo do artigo viaja no plano para a telemetria' );
$short_guide = go_verge_ads_plan_article( str_repeat( go_test_paragraph( 75 ), 4 ), 'guide' );
go_test_equals( 2, (int) $short_guide['ladderCapacity'], 'Abaixo do terceiro degrau o formato não altera nada' );
foreach ( array( 'review', 'critique', 'special', '', 'news' ) as $neutral_type ) {
	$neutral = go_verge_ads_plan_article( $guide_html, $neutral_type );
	go_test_equals( 4, (int) $neutral['ladderCapacity'], 'Formato "' . ( $neutral_type ?: 'vazio' ) . '" não altera a escada' );
}

$short = go_test_paragraph( 90 ) . go_test_paragraph( 80 ) . go_test_paragraph( 80 );
$short_plan = go_verge_ads_plan_article( $short );
go_test_ok( (int) $short_plan['plannedCount'] >= 1, 'Notícia de ~250 palavras mantém uma oportunidade segura no corpo' );
go_test_ok( ! empty( $short_plan['prime'] ), 'A oportunidade curta é Prime de alto alcance, não slot profundo' );

go_test_section( 'Falha fechada' );

go_test_equals( array(), go_verge_ads_planner_blocks( '<p>aberto <div>errado</p></div>' ), 'HTML mal formado não recebe inventário' );
go_test_equals( 0, (int) go_verge_ads_plan_article( '<p>Curto demais.</p>' )['plannedCount'], 'Artigo minúsculo não recebe inventário' );
go_test_equals( 0, (int) go_verge_ads_plan_article( '' )['plannedCount'], 'Conteúdo vazio não recebe inventário' );
