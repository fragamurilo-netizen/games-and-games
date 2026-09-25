<?php
/**
 * A coluna "Oportunidade" na lista de posts.
 *
 * O GO Statistics já calcula, por consulta e URL, onde estão os cliques que o
 * site perde por título fraco, por posição a um passo do topo, por decaimento
 * ou por canibalização. Esse cálculo morria numa tela de relatório que ninguém
 * abre no meio do expediente.
 *
 * Aqui ele aparece na linha da matéria, ao lado do botão de editar — que é onde
 * a decisão realmente acontece. O editor não precisa procurar a oportunidade:
 * ela está do lado do trabalho.
 *
 * TRÊS COISAS QUE ESTA TELA NÃO FAZ
 * ---------------------------------
 * 1. Não consulta nada por linha. A lista de posts renderiza 20 linhas; vinte
 *    varreduras do Search Console tornariam a tela inutilizável. O motor devolve
 *    todas as oportunidades de uma vez, e o índice por post_id é montado uma vez
 *    por requisição.
 * 2. Não inventa quando o GO Statistics está desligado. Sem o plugin a coluna
 *    não é registrada — nem como célula vazia.
 * 3. Não promete posição. O número exibido é CLIQUE RECUPERÁVEL estimado pela
 *    curva de CTR do próprio site, e a coluna diz de onde ele veio.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** O motor de SERP está disponível? */
function go_verge_serp_engine_available() {
	return class_exists( 'GO_Stats_SERP' ) && method_exists( 'GO_Stats_SERP', 'opportunities' );
}

/**
 * Oportunidades indexadas por post, calculadas uma vez por requisição.
 *
 * @return array<int,array<int,array<string,mixed>>>
 */
function go_verge_serp_by_post() {
	static $index = null;
	if ( null !== $index ) {
		return $index;
	}
	$index = array();
	if ( ! go_verge_serp_engine_available() ) {
		return $index;
	}

	/* Cache curto: a lista de posts é recarregada muitas vezes por sessão e o
	 * cálculo varre até 4.000 linhas do Search Console. Meia hora é bem menor
	 * que a cadência com que os dados do GSC mudam (diária). */
	$cached = get_transient( 'go_verge_serp_by_post' );
	if ( is_array( $cached ) ) {
		$index = $cached;
		return $index;
	}

	$data = GO_Stats_SERP::opportunities();
	foreach ( (array) ( $data['items'] ?? array() ) as $item ) {
		$post_id = absint( $item['post_id'] ?? 0 );
		if ( ! $post_id ) {
			continue;
		}
		if ( ! isset( $index[ $post_id ] ) ) {
			$index[ $post_id ] = array();
		}
		/* No máximo três por matéria: a quarta não muda a decisão e a célula
		 * vira parede de texto. */
		if ( count( $index[ $post_id ] ) < 3 ) {
			$index[ $post_id ][] = $item;
		}
	}
	set_transient( 'go_verge_serp_by_post', $index, 30 * MINUTE_IN_SECONDS );
	return $index;
}

/** Rótulo curto e cor de cada tipo de oportunidade. */
function go_verge_serp_kind_meta( $kind ) {
	$map = array(
		'ctr_gap'           => array( 'Título', 'warn', 'A posição já existe e não converte: o CTR está abaixo do que este site costuma tirar dessa faixa. É promessa de título/description, não de ranking.' ),
		'striking_distance' => array( 'A um passo', 'ok', 'Está entre a 4ª e a 15ª posição com impressão de sobra. Subir ao top 3 vale o número ao lado, ao CTR que o site já pratica lá.' ),
		'decay'             => array( 'Caindo', 'bad', 'Perdeu posição e clique contra a janela anterior. Conteúdo envelhecido ou concorrente novo.' ),
		'cannibalization'   => array( 'Canibalização', 'bad', 'Duas ou mais URLs suas disputam a mesma consulta e nenhuma chega ao topo. Consolidar costuma valer mais que manter as duas.' ),
		'coverage_gap'      => array( 'Sem matéria', 'warn', 'Há impressão para a consulta e nenhuma matéria que case bem com ela.' ),
	);
	return $map[ $kind ] ?? array( ucfirst( (string) $kind ), 'warn', '' );
}

/**
 * Registrar a coluna. Só existe quando o motor existe.
 *
 * @param array<string,string> $columns Colunas.
 * @return array<string,string>
 */
function go_verge_serp_column( $columns ) {
	if ( ! go_verge_serp_engine_available() ) {
		return $columns;
	}
	$out = array();
	foreach ( $columns as $key => $label ) {
		$out[ $key ] = $label;
		if ( 'go_google' === $key ) {
			$out['go_serp'] = __( 'Oportunidade', 'go-verge' ) . ' ' . ( function_exists( 'go_verge_admin_metric_help' )
				? go_verge_admin_metric_help( 'Oportunidade de SERP', 'Cliques recuperáveis estimados pela curva de CTR DESTE site, a partir do Search Console próprio. Não é volume de mercado e não promete posição.' )
				: '' );
		}
	}
	/* Se a coluna do Google não existir (Desk desligado), entra no fim. */
	if ( ! isset( $out['go_serp'] ) ) {
		$out['go_serp'] = __( 'Oportunidade', 'go-verge' );
	}
	return $out;
}
add_filter( 'manage_post_posts_columns', 'go_verge_serp_column', 45 );

/**
 * Célula.
 *
 * @param string $column  Coluna.
 * @param int    $post_id Post.
 */
function go_verge_serp_cell( $column, $post_id ) {
	if ( 'go_serp' !== $column ) {
		return;
	}
	$items = go_verge_serp_by_post()[ absint( $post_id ) ] ?? array();
	if ( ! $items ) {
		echo '<div class="go-serp is-empty"><small>—</small></div>';
		return;
	}

	$total = 0.0;
	foreach ( $items as $item ) {
		$total += (float) $item['gain'];
	}

	echo '<div class="go-serp">';
	printf(
		'<strong class="go-serp-total">+%s <span>cliques/28d</span></strong>',
		esc_html( number_format_i18n( round( $total ) ) )
	);
	foreach ( $items as $item ) {
		list( $label, $tone, $why ) = go_verge_serp_kind_meta( (string) $item['kind'] );
		printf(
			'<span class="go-serp-row"><em class="go-serp-chip is-%1$s" title="%2$s">%3$s</em><span class="go-serp-q" title="%4$s">%5$s</span><b>+%6$s</b></span>',
			esc_attr( $tone ),
			esc_attr( $why ),
			esc_html( $label ),
			esc_attr( (string) $item['why'] ),
			esc_html( wp_html_excerpt( (string) $item['query'], 34, '…' ) ),
			esc_html( number_format_i18n( round( (float) $item['gain'] ) ) )
		);
	}
	echo '</div>';
}
add_action( 'manage_post_posts_custom_column', 'go_verge_serp_cell', 12, 2 );

/** Estilo da coluna. */
function go_verge_serp_css() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'edit-post' !== $screen->id || ! go_verge_serp_engine_available() ) {
		return;
	}
	?>
	<style>
	.column-go_serp{width:210px}
	.go-serp{display:flex;flex-direction:column;gap:3px;line-height:1.3;min-height:54px}
	.go-serp.is-empty{opacity:.45;justify-content:center}
	.go-serp-total{font-size:14px;color:#067647;font-variant-numeric:tabular-nums}
	.go-serp-total span{font-weight:400;font-size:11px;color:#646970}
	.go-serp-row{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:5px;font-size:11px}
	.go-serp-q{color:#50575e;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
	.go-serp-row b{font-variant-numeric:tabular-nums;color:#1d2327}
	.go-serp-chip{font-style:normal;font-size:10px;line-height:1;padding:3px 5px;border-radius:10px;background:#f0f0f1;color:#50575e;cursor:help;white-space:nowrap}
	.go-serp-chip.is-ok{background:#dcfce7;color:#166534}
	.go-serp-chip.is-warn{background:#fff7d6;color:#7a4d00}
	.go-serp-chip.is-bad{background:#fcebea;color:#8a1f11}
	@media(max-width:1400px){.column-go_serp{display:none}}
	</style>
	<?php
}
add_action( 'admin_head-edit.php', 'go_verge_serp_css' );

/**
 * Ordenar a lista pelas maiores oportunidades.
 *
 * Sem isso a coluna informa mas não organiza: a matéria com 400 cliques
 * recuperáveis fica na página 7 porque foi publicada há três semanas.
 *
 * @param array $columns Colunas ordenáveis.
 * @return array
 */
function go_verge_serp_sortable( $columns ) {
	if ( go_verge_serp_engine_available() ) {
		$columns['go_serp'] = 'go_serp';
	}
	return $columns;
}
add_filter( 'manage_edit-post_sortable_columns', 'go_verge_serp_sortable' );

/**
 * A ordenação acontece em PHP, não em SQL.
 *
 * O ganho não está em nenhuma coluna do banco — ele é calculado da série do
 * Search Console. Um `orderby` de meta_value exigiria materializar isso em
 * postmeta e mantê-lo sincronizado, o que troca uma tela por um pipeline. Como
 * a lista já vem paginada e pequena, reordenar o resultado é honesto e barato;
 * a paginação continua sendo a do WordPress, então a ordem vale dentro da
 * página exibida. O cabeçalho diz isso.
 *
 * @param array    $posts Posts.
 * @param WP_Query $query Query.
 * @return array
 */
function go_verge_serp_sort_results( $posts, $query ) {
	if ( ! is_admin() || ! $query->is_main_query() || 'go_serp' !== $query->get( 'orderby' ) || ! go_verge_serp_engine_available() ) {
		return $posts;
	}
	$index = go_verge_serp_by_post();
	$gain  = static function ( $post ) use ( $index ) {
		$total = 0.0;
		foreach ( $index[ (int) $post->ID ] ?? array() as $item ) {
			$total += (float) $item['gain'];
		}
		return $total;
	};
	$desc = 'asc' !== strtolower( (string) $query->get( 'order' ) );
	usort( $posts, static function ( $a, $b ) use ( $gain, $desc ) {
		$cmp = $gain( $b ) <=> $gain( $a );
		return $desc ? $cmp : -$cmp;
	} );
	return $posts;
}
add_filter( 'the_posts', 'go_verge_serp_sort_results', 10, 2 );

/**
 * Invalidar o índice quando o GO Statistics sincroniza.
 *
 * Sem isto a coluna mostraria a mesma foto por meia hora depois de um sync
 * manual, e o editor concluiria que a tela não responde.
 */
function go_verge_serp_flush_cache() {
	delete_transient( 'go_verge_serp_by_post' );
}
add_action( 'go_stats_after_sync', 'go_verge_serp_flush_cache' );
add_action( 'go_stats_serp_recalculated', 'go_verge_serp_flush_cache' );
