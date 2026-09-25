<?php
/**
 * Busca de hiperlink do editor.
 *
 * O painel que abre no Ctrl+K — no Gutenberg e no editor clássico — é servido
 * pelo `wp_link_query` do núcleo, que faz uma busca LIKE simples e devolve os
 * resultados em ordem de data. Num acervo com milhares de matérias sobre os
 * mesmos jogos, isso significa que digitar o nome exato de uma matéria
 * costumava trazer primeiro a cobertura mais recente que só cita o termo, e a
 * matéria certa ficava fora das 20 primeiras linhas.
 *
 * Três problemas concretos são resolvidos aqui:
 *
 *  1. Acento. "pokemon" não encontrava "Pokémon" quando a coleção da tabela é
 *     sensível a acento. A comparação passa a ser feita sobre a forma sem
 *     acento e em caixa baixa, dos dois lados.
 *  2. Ordem. O resultado passa a ser ordenado por qualidade de correspondência
 *     — título exato, depois começa-com, depois palavra inteira, depois
 *     contém — e só então por data.
 *  3. Identificação. O núcleo mostra o tipo do post ("Post") como legenda, o
 *     que não distingue nada quando tudo é "Post". No lugar entra a editoria e
 *     a data, que é o que permite escolher entre dois títulos parecidos.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Forma comparável de um texto: sem acento, sem pontuação dupla, caixa baixa.
 *
 * @param string $text Texto de entrada.
 * @return string
 */
function go_verge_link_search_normalize( $text ) {
	$text = remove_accents( (string) $text );
	$text = strtolower( $text );
	$text = preg_replace( '/[^a-z0-9]+/', ' ', $text );

	return trim( (string) $text );
}

/**
 * Amplia o universo da busca antes de o núcleo consultar o banco.
 *
 * O núcleo pesquisa os tipos com `show_in_nav_menus`. Os hubs de jogo e as
 * entidades editoriais são destinos internos legítimos e ficavam de fora, o
 * que obrigava o editor a copiar a URL na mão. O limite sobe porque a
 * reordenação abaixo precisa de material: pedir 20 e reordenar 20 não muda o
 * que já estava faltando na lista.
 *
 * @param array<string,mixed> $query Argumentos de WP_Query montados pelo núcleo.
 * @param array<string,mixed> $args  Argumentos da requisição.
 * @return array<string,mixed>
 */
function go_verge_link_search_args( $query, $args ) {
	unset( $args );

	$types = isset( $query['post_type'] ) ? (array) $query['post_type'] : array( 'post', 'page' );
	foreach ( array( 'games', 'productions', 'go_entity' ) as $post_type ) {
		if ( post_type_exists( $post_type ) && ! in_array( $post_type, $types, true ) ) {
			$types[] = $post_type;
		}
	}
	$query['post_type'] = array_values( array_unique( $types ) );

	/*
	 * Só vale ampliar quando há termo de busca. A listagem inicial sem termo é
	 * "conteúdo mais recente", e aí 20 linhas é a resposta certa.
	 */
	if ( ! empty( $query['s'] ) ) {
		$query['posts_per_page'] = 60;
	}

	return $query;
}
add_filter( 'wp_link_query_args', 'go_verge_link_search_args', 10, 2 );

/**
 * Pontua a correspondência entre o termo digitado e um título.
 *
 * Menor é melhor, para que um `usort` crescente já entregue a ordem final.
 *
 * @param string $title Título do resultado.
 * @param string $term  Termo normalizado.
 * @return int
 */
function go_verge_link_search_rank( $title, $term ) {
	$title = go_verge_link_search_normalize( $title );

	if ( '' === $term || '' === $title ) {
		return 40;
	}
	if ( $title === $term ) {
		return 0;
	}
	if ( 0 === strpos( $title, $term . ' ' ) ) {
		return 10;
	}
	// Palavra inteira no meio do título vale mais que um pedaço de palavra.
	if ( preg_match( '/\b' . preg_quote( $term, '/' ) . '\b/', $title ) ) {
		return 20;
	}
	if ( false !== strpos( $title, $term ) ) {
		return 30;
	}

	/*
	 * Nenhuma correspondência no título: o núcleo trouxe pelo conteúdo. Ainda
	 * é um resultado válido, mas nunca deve passar na frente de um título que
	 * bate — então vai para o fim, ordenado pelo tanto que bate.
	 */
	$hits = 0;
	/*
	 * Partes de até dois caracteres ("e", "de", "os") aparecem em quase todo
	 * título e empatariam a cauda inteira em 35, desfazendo a ordenação por
	 * data logo abaixo. Só palavras com peso próprio contam aqui.
	 */
	$parts = array_filter(
		explode( ' ', $term ),
		static function ( $part ) {
			return strlen( $part ) > 2;
		}
	);
	foreach ( $parts as $part ) {
		if ( false !== strpos( $title, $part ) ) {
			$hits++;
		}
	}

	return $parts && $hits ? 35 : 40;
}

/**
 * Legenda útil para um resultado: editoria e data.
 *
 * @param int $post_id Post do resultado.
 * @return string
 */
function go_verge_link_search_info( $post_id ) {
	$post = get_post( $post_id );
	if ( ! $post instanceof WP_Post ) {
		return '';
	}

	$label = '';
	if ( 'post' === $post->post_type ) {
		$terms = get_the_category( $post_id );
		if ( ! empty( $terms ) && $terms[0] instanceof WP_Term ) {
			$label = $terms[0]->name;
		}
	} else {
		$object = get_post_type_object( $post->post_type );
		if ( $object ) {
			$label = $object->labels->singular_name;
		}
	}

	$date = get_the_date( 'j M Y', $post );

	if ( 'publish' !== $post->post_status ) {
		$status = get_post_status_object( $post->post_status );
		$label  = trim( $label . ' · ' . ( $status ? $status->label : $post->post_status ), ' ·' );
	}

	return trim( $label . ' · ' . $date, ' ·' );
}

/**
 * Reordena e reetiqueta o que o núcleo devolveu.
 *
 * @param array<int,array<string,mixed>> $results Resultados do núcleo.
 * @param array<string,mixed>            $query   Argumentos usados na consulta.
 * @return array<int,array<string,mixed>>
 */
function go_verge_link_search_results( $results, $query ) {
	if ( empty( $results ) || ! is_array( $results ) ) {
		return $results;
	}

	$term = isset( $query['s'] ) ? go_verge_link_search_normalize( $query['s'] ) : '';

	foreach ( $results as $index => $result ) {
		$post_id = isset( $result['ID'] ) ? absint( $result['ID'] ) : 0;

		$results[ $index ]['go_rank']  = go_verge_link_search_rank( $result['title'] ?? '', $term );
		$results[ $index ]['go_order'] = $index;
		$results[ $index ]['go_time']  = $post_id ? (int) get_post_time( 'U', true, $post_id ) : 0;

		if ( $post_id ) {
			$info = go_verge_link_search_info( $post_id );
			if ( '' !== $info ) {
				$results[ $index ]['info'] = $info;
			}
		}
	}

	usort(
		$results,
		static function ( $a, $b ) {
			if ( $a['go_rank'] !== $b['go_rank'] ) {
				return $a['go_rank'] <=> $b['go_rank'];
			}
			// Empate na qualidade da correspondência: a mais recente primeiro.
			if ( $a['go_time'] !== $b['go_time'] ) {
				return $b['go_time'] <=> $a['go_time'];
			}

			return $a['go_order'] <=> $b['go_order'];
		}
	);

	/*
	 * O painel do editor pagina de 20 em 20 e não sabe que a lista foi
	 * reordenada. Devolver mais do que ele pediu faria a segunda página repetir
	 * itens da primeira, então o corte é feito aqui.
	 */
	$per_page = isset( $query['posts_per_page'] ) ? absint( $query['posts_per_page'] ) : 20;
	if ( $per_page > 20 ) {
		$results = array_slice( $results, 0, 20 );
	}

	foreach ( $results as $index => $result ) {
		unset( $results[ $index ]['go_rank'], $results[ $index ]['go_order'], $results[ $index ]['go_time'] );
	}

	return array_values( $results );
}
add_filter( 'wp_link_query', 'go_verge_link_search_results', 10, 2 );
