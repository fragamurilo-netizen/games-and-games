<?php
/**
 * Escopo editorial canônico do Overdrive.
 *
 * Mantém uma única definição para Games, Entretenimento, Tecnologia e Ofertas e a
 * reutiliza em metadados e dados estruturados. Este módulo não altera queries,
 * layout da home, inventário ou carregamento de anúncios.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Pilares editoriais da publicação.
 *
 * @return array<string,array<string,mixed>>
 */
function go_verge_editorial_pillars() {
	$pillars = array(
		'games' => array(
			'label' => __( 'Games', 'go-verge' ),
			'slug'  => 'games',
			'terms' => array(
				'Jogos eletrônicos',
				'PlayStation',
				'Xbox',
				'Nintendo',
				'Jogos para PC',
			),
		),
		'entretenimento' => array(
			'label' => __( 'Entretenimento', 'go-verge' ),
			'slug'  => 'entretenimento',
			'terms' => array(
				'Séries de televisão',
				'Filmes',
				'Novelas',
				'Cultura pop',
				'Serviços de streaming',
				'Netflix',
				'Prime Video',
				'Disney+',
				'Globoplay',
				'Onde assistir',
			),
		),
		'tecnologia' => array(
			'label' => __( 'Tecnologia', 'go-verge' ),
			'slug'  => 'tecnologia',
			'terms' => array(
				'Tecnologia',
				'Celulares e smartphones',
				'Android',
				'iPhone e iOS',
				'Hardware',
				'Notebooks',
				'TVs e monitores',
				'Aplicativos e software',
				'Inteligência artificial',
			),
		),
		'ofertas' => array(
			'label' => __( 'Ofertas', 'go-verge' ),
			'slug'  => 'ofertas',
			'terms' => array( 'Ofertas de jogos e tecnologia', 'Guias de compra', 'Jogos grátis' ),
		),
	);

	return (array) apply_filters( 'go_verge_editorial_pillars', $pillars );
}

/**
 * Resolve a real category to one editorial desk, without rewriting any term.
 *
 * The assigned hierarchy wins over legacy slug conventions: a Review filed
 * under Tecnologia remains a Technology story. Known old slugs are fallback
 * compatibility only. Unknown terms never become Games by default.
 *
 * @param WP_Term|int $term Category object or term ID.
 * @return string games|entretenimento|tecnologia|ofertas, or an empty string.
 */
function go_verge_category_editorial_desk( $term ) {
	if ( is_numeric( $term ) ) { $term = get_term( absint( $term ), 'category' ); }
	if ( ! ( $term instanceof WP_Term ) || 'category' !== $term->taxonomy ) { return ''; }
	$roots = array( 'games' => 'games', 'jogos' => 'games', 'entretenimento' => 'entretenimento', 'entertainment' => 'entretenimento', 'tecnologia' => 'tecnologia', 'technology' => 'tecnologia', 'tech' => 'tecnologia', 'ofertas' => 'ofertas' );
	$lineage = array( $term );
	foreach ( (array) get_ancestors( (int) $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
		$ancestor = get_term( (int) $ancestor_id, 'category' );
		if ( $ancestor instanceof WP_Term ) { $lineage[] = $ancestor; }
	}
	foreach ( $lineage as $ancestor ) {
		$slug = sanitize_title( $ancestor->slug );
		if ( isset( $roots[ $slug ] ) ) { return $roots[ $slug ]; }
	}

	/* Build once per request; no taxonomy query is needed for known old slugs. */
	static $legacy = null;
	if ( null === $legacy ) {
		$legacy = array( 'guias' => 'games', 'guia' => 'games', 'tutoriais' => 'games', 'dicas' => 'games', 'dica' => 'games', 'software-e-ia' => 'tecnologia' );
		if ( function_exists( 'go_verge_v7_category_blueprint' ) ) {
			foreach ( go_verge_v7_category_blueprint() as $root_slug => $root ) {
				foreach ( array_keys( (array) ( $root['children'] ?? array() ) ) as $slug ) { $legacy[ $slug ] = $root_slug; }
			}
		}
		if ( function_exists( 'go_verge_v7_legacy_maps' ) ) {
			$maps = go_verge_v7_legacy_maps();
			foreach ( (array) ( $maps['category'] ?? array() ) as $alias => $target ) {
				if ( isset( $roots[ $target ] ) ) { $legacy[ $alias ] = $roots[ $target ]; }
				elseif ( isset( $legacy[ $target ] ) ) { $legacy[ $alias ] = $legacy[ $target ]; }
			}
		}
	}
	foreach ( $lineage as $ancestor ) {
		$slug = sanitize_title( $ancestor->slug );
		if ( isset( $legacy[ $slug ] ) ) { return $legacy[ $slug ]; }
	}
	return '';
}

/** Read a story's desk from cached relationships and an assigned primary. */
function go_verge_post_editorial_desk( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) { return ''; }
	$terms = get_the_terms( $post_id, 'category' );
	if ( ! is_array( $terms ) || ! $terms ) { return ''; }
	$by_id = array();
	foreach ( $terms as $term ) {
		if ( $term instanceof WP_Term ) { $by_id[ (int) $term->term_id ] = $term; }
	}
	foreach ( array( '_go_primary_category_id', 'rank_math_primary_category', '_yoast_wpseo_primary_category' ) as $meta_key ) {
		$primary_id = absint( get_post_meta( $post_id, $meta_key, true ) );
		if ( isset( $by_id[ $primary_id ] ) ) {
			$desk = go_verge_category_editorial_desk( $by_id[ $primary_id ] );
			if ( '' !== $desk ) { return $desk; }
		}
	}
	if ( function_exists( 'go_verge_v7_pick_primary_category_term' ) ) {
		$primary = go_verge_v7_pick_primary_category_term( $terms, $post_id );
		if ( $primary instanceof WP_Term ) {
			$desk = go_verge_category_editorial_desk( $primary );
			if ( '' !== $desk ) { return $desk; }
		}
	}
	$desks = array();
	foreach ( $by_id as $term ) {
		$desk = go_verge_category_editorial_desk( $term );
		if ( '' !== $desk ) { $desks[ $desk ] = true; }
	}
	return 1 === count( $desks ) ? (string) key( $desks ) : '';
}

/**
 * Assuntos utilizados em knowsAbout no schema da publicação.
 *
 * @return string[]
 */
function go_verge_editorial_scope_terms() {
	$terms = array();

	foreach ( go_verge_editorial_pillars() as $pillar ) {
		foreach ( (array) ( $pillar['terms'] ?? array() ) as $term ) {
			$term = trim( wp_strip_all_tags( (string) $term ) );
			if ( '' !== $term ) {
				$terms[] = $term;
			}
		}
	}

	return (array) apply_filters(
		'go_verge_editorial_scope_terms',
		array_slice( array_values( array_unique( $terms ) ), 0, 32 )
	);
}

/**
 * Descrição curta e estável do escopo editorial.
 *
 * @return string
 */
function go_verge_editorial_scope_sentence() {
	return (string) apply_filters(
		'go_verge_editorial_scope_sentence',
		__( 'cobertura de games, entretenimento, tecnologia e ofertas com notícias, reviews e guias', 'go-verge' )
	);
}

/**
 * Adiciona o escopo editorial a um nó Organization/NewsMediaOrganization.
 *
 * @param array $node Nó do schema.
 * @return array
 */
function go_verge_apply_editorial_scope_to_org( $node ) {
	if ( ! is_array( $node ) ) {
		return $node;
	}

	$terms = go_verge_editorial_scope_terms();
	if ( ! $terms ) {
		return $node;
	}

	$existing = array();
	foreach ( (array) ( $node['knowsAbout'] ?? array() ) as $value ) {
		if ( is_string( $value ) && '' !== trim( $value ) ) {
			$existing[] = trim( $value );
		} elseif ( is_array( $value ) && ! empty( $value['name'] ) ) {
			$existing[] = trim( (string) $value['name'] );
		}
	}

	$node['knowsAbout'] = array_values( array_unique( array_merge( $existing, $terms ) ) );
	return $node;
}
