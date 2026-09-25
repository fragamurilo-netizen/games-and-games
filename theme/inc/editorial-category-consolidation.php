<?php
/**
 * Canonical consolidation for the Guides editorial category.
 *
 * Moves posts and child categories from legacy Tutorial/Dicas roots to
 * the canonical V7 Guias category and keeps permanent redirects for old
 * archive/page URLs.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Exact legacy category slug => canonical category data.
 *
 * @return array<string,array{slug:string,name:string}>
 */
function go_verge_editorial_category_alias_map() {
	return (array) apply_filters(
		'go_verge_editorial_category_alias_map',
		array(
			'dicas-e-guias' => array( 'slug' => 'guias', 'name' => 'Guias' ),
			'guia'          => array( 'slug' => 'guias', 'name' => 'Guias' ),
			'dicas'         => array( 'slug' => 'guias', 'name' => 'Guias' ),
			'dica'          => array( 'slug' => 'guias', 'name' => 'Guias' ),
			'tutorial'      => array( 'slug' => 'guias', 'name' => 'Guias' ),
		)
	);
}

/** Return canonical category data for a legacy slug. */
function go_verge_editorial_category_alias_target( $slug ) {
	$slug = sanitize_title( (string) $slug );
	$map  = go_verge_editorial_category_alias_map();
	return isset( $map[ $slug ] ) && is_array( $map[ $slug ] ) ? $map[ $slug ] : null;
}

/** Resolve or create the canonical Dicas e Guias category. */
function go_verge_get_canonical_guides_category() {
	$canonical = get_term_by( 'slug', 'guias', 'category' );
	if ( $canonical instanceof WP_Term ) {
		return $canonical;
	}

	$parent = get_term_by( 'slug', 'games', 'category' );
	$created = wp_insert_term(
		'Guias',
		'category',
		array(
			'slug'   => 'guias',
			'parent' => $parent instanceof WP_Term ? (int) $parent->term_id : 0,
		)
	);
	if ( is_wp_error( $created ) || empty( $created['term_id'] ) ) {
		return null;
	}

	$canonical = get_term( (int) $created['term_id'], 'category' );
	return $canonical instanceof WP_Term ? $canonical : null;
}

/**
 * Move legacy category relationships into the canonical Dicas e Guias root.
 * Runs once per version and is safe to repeat.
 */
function go_verge_consolidate_guides_categories() {
	if ( ! taxonomy_exists( 'category' ) || ! current_user_can( 'manage_categories' ) ) {
		return;
	}

	$version = '2026-08-25-v38';
	if ( $version === get_option( 'go_verge_guides_category_consolidation_version' ) ) {
		return;
	}

	$canonical = go_verge_get_canonical_guides_category();
	if ( ! ( $canonical instanceof WP_Term ) ) {
		return;
	}

	foreach ( go_verge_editorial_category_alias_map() as $alias_slug => $target ) {
		$alias = get_term_by( 'slug', $alias_slug, 'category' );
		if ( ! ( $alias instanceof WP_Term ) || (int) $alias->term_id === (int) $canonical->term_id ) {
			continue;
		}

		$object_ids = get_objects_in_term( (int) $alias->term_id, 'category' );
		if ( ! is_wp_error( $object_ids ) ) {
			foreach ( array_map( 'absint', (array) $object_ids ) as $object_id ) {
				wp_set_object_terms( $object_id, array( (int) $canonical->term_id ), 'category', true );
				wp_remove_object_terms( $object_id, array( (int) $alias->term_id ), 'category' );
			}
		}

		if ( (int) $canonical->parent === (int) $alias->term_id ) {
			wp_update_term( (int) $canonical->term_id, 'category', array( 'parent' => 0 ) );
			$canonical = get_term( (int) $canonical->term_id, 'category' );
		}

		$children = get_terms(
			array(
				'taxonomy'   => 'category',
				'hide_empty' => false,
				'parent'     => (int) $alias->term_id,
			)
		);
		if ( ! is_wp_error( $children ) ) {
			foreach ( $children as $child ) {
				if ( (int) $child->term_id !== (int) $canonical->term_id ) {
					wp_update_term( (int) $child->term_id, 'category', array( 'parent' => (int) $canonical->term_id ) );
				}
			}
		}

		if ( '' === trim( (string) $canonical->description ) && '' !== trim( (string) $alias->description ) ) {
			wp_update_term( (int) $canonical->term_id, 'category', array( 'description' => $alias->description ) );
			$canonical = get_term( (int) $canonical->term_id, 'category' );
		}

		wp_delete_term( (int) $alias->term_id, 'category' );
	}

	clean_term_cache( (int) $canonical->term_id, 'category' );
	if ( function_exists( 'go_verge_internal_link_bust' ) ) {
		go_verge_internal_link_bust();
	}
	update_option( 'go_verge_guides_category_consolidation_version', $version, false );
}
add_action( 'admin_init', 'go_verge_consolidate_guides_categories', 31 );

/** Canonical destination used by redirects and term links. */
function go_verge_canonical_guides_url() {
	if ( function_exists( 'go_verge_v7_category_url' ) ) {
		return go_verge_v7_category_url( 'guias' );
	}

	$term = get_term_by( 'slug', 'guias', 'category' );
	if ( $term instanceof WP_Term ) {
		$url = get_term_link( $term );
		if ( ! is_wp_error( $url ) ) {
			return $url;
		}
	}
	return home_url( '/guias/' );
}

/** Return the dedicated Guides hub URL without falling back to a category. */
function go_verge_canonical_guides_page_url() {
	return '';
}

/** Redirect old category and Page URLs to the unified hub. */
function go_verge_redirect_legacy_guides_urls() {
	if ( is_admin() || wp_doing_ajax() || is_feed() ) {
		return;
	}

	$requested = '';
	$category_path = trim( (string) get_query_var( 'category_name' ), '/' );
	if ( '' !== $category_path ) {
		$requested = sanitize_title( basename( $category_path ) );
	} elseif ( is_page() ) {
		$page      = get_queried_object();
		$requested = $page instanceof WP_Post ? sanitize_title( $page->post_name ) : '';
	} else {
		$page_path = trim( (string) get_query_var( 'pagename' ), '/' );
		$requested = '' !== $page_path ? sanitize_title( basename( $page_path ) ) : '';
	}

	if ( ! go_verge_editorial_category_alias_target( $requested ) ) {
		return;
	}

	$url  = go_verge_canonical_guides_url();
	$term = function_exists( 'go_verge_editorial_search_term' ) ? go_verge_editorial_search_term() : '';
	if ( $term ) {
		$url = add_query_arg( 'tema', $term, $url );
	}

	wp_safe_redirect( $url, 301, 'Overdrive editorial category consolidation' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_legacy_guides_urls', 2 );

/** Point links for still-existing legacy category terms at the canonical hub. */
function go_verge_canonical_guides_term_link( $url, $term, $taxonomy ) {
	if ( 'category' !== $taxonomy || ! ( $term instanceof WP_Term ) ) {
		return $url;
	}
	if ( 'guias' === $term->slug ) {
		return $url;
	}
	return go_verge_editorial_category_alias_target( $term->slug ) ? go_verge_canonical_guides_url() : $url;
}
add_filter( 'term_link', 'go_verge_canonical_guides_term_link', 21, 3 );

/* -------------------------------------------------------------------------
 * Guias de Compra: a categoria real (guias-de-compra-2, sob Tecnologia)
 * continua sendo a fonte de dados, mas o destino público único é o hub
 * /guias-de-compra/. A categoria só redireciona quando a página existe,
 * então a ordem de publicação no ar não quebra nada.
 * ---------------------------------------------------------------------- */

/** Slugs de categoria que representam Guias de Compra. */
function go_verge_buying_guides_category_slugs() {
	return (array) apply_filters(
		'go_verge_buying_guides_category_slugs',
		function_exists( 'go_verge_v7_category_blueprint' )
			? array( 'guias-de-compra-2', 'guias-de-compra-3', 'guia-de-compra', 'guias-compra' )
			: array( 'guias-de-compra-2', 'guias-de-compra-3', 'guias-de-compra', 'guia-de-compra', 'guias-compra' )
	);
}

/** URL canônica do hub de Guias de Compra ('' quando a página não existe). */
function go_verge_canonical_buying_guides_url() {
	if ( function_exists( 'go_verge_v7_category_url' ) ) {
		return go_verge_v7_category_url( 'guias-de-compra' );
	}
	$page = get_page_by_path( 'guias-de-compra', OBJECT, 'page' );
	if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
		return get_permalink( $page );
	}
	return '';
}

/** 301 do arquivo da categoria para o hub unificado. */
function go_verge_redirect_buying_guides_category() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || ! is_category() ) {
		return;
	}

	$term = get_queried_object();
	if ( ! ( $term instanceof WP_Term ) || ! in_array( $term->slug, go_verge_buying_guides_category_slugs(), true ) ) {
		return;
	}

	$url = go_verge_canonical_buying_guides_url();
	if ( '' === $url ) {
		return;
	}

	// Subeditoria vira filtro do hub; a busca acompanha.
	$search = function_exists( 'go_verge_editorial_search_term' ) ? go_verge_editorial_search_term() : '';
	if ( $search ) {
		$url = add_query_arg( 'tema', $search, $url );
	}

	wp_safe_redirect( $url, 301, 'Overdrive buying guides consolidation' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_buying_guides_category', 3 );

/**
 * Cria (ou publica) a página do hub automaticamente na primeira visita ao
 * painel, no mesmo padrão das páginas institucionais do tema. O conteúdo fica
 * vazio de propósito: o template page-guias-de-compra.php renderiza tudo.
 */
function go_verge_provision_buying_guides_page() {
	if ( function_exists( 'go_verge_v7_category_blueprint' ) ) {
		return;
	}
	if ( get_option( 'go_verge_buying_guides_page_v1' ) || ! current_user_can( 'publish_pages' ) ) {
		return;
	}

	$existing = get_posts(
		array(
			'post_type'      => 'page',
			'name'           => 'guias-de-compra',
			'post_status'    => array( 'publish', 'draft', 'pending', 'private', 'future' ),
			'posts_per_page' => 1,
		)
	);

	if ( $existing ) {
		$page = $existing[0];
		if ( 'publish' !== $page->post_status ) {
			wp_update_post(
				array(
					'ID'          => (int) $page->ID,
					'post_status' => 'publish',
				)
			);
		}
		update_option( 'go_verge_buying_guides_page_v1', 1, false );
		return;
	}

	$page_id = wp_insert_post(
		array(
			'post_type'    => 'page',
			'post_status'  => 'publish',
			'post_title'   => 'Guias de Compra',
			'post_name'    => 'guias-de-compra',
			'post_content' => '',
		),
		true
	);

	if ( ! is_wp_error( $page_id ) && $page_id ) {
		update_option( 'go_verge_buying_guides_page_v1', 1, false );
	}
}
add_action( 'admin_init', 'go_verge_provision_buying_guides_page', 41 );

/* -------------------------------------------------------------------------
 * Promoções: a página manual duplicada (/promocoes-2/) é consolidada no
 * arquivo oficial de ofertas (/promocoes/).
 * ---------------------------------------------------------------------- */

/** 301 da página duplicada para o arquivo de ofertas. */
function go_verge_redirect_duplicate_promotions_page() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || ! is_page() ) {
		return;
	}
	$page = get_queried_object();
	if ( ! ( $page instanceof WP_Post ) || ! in_array( $page->post_name, array( 'promocoes-2', 'promocoes-3' ), true ) ) {
		return;
	}
	$url = get_post_type_archive_link( 'go_promotion' );
	if ( ! $url ) {
		return;
	}
	wp_safe_redirect( $url, 301, 'Overdrive promotions consolidation' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_duplicate_promotions_page', 3 );

/** Menus e listas que apontem para a página duplicada linkam direto o arquivo. */
function go_verge_duplicate_promotions_page_link( $link, $post_id ) {
	$post = get_post( $post_id );
	if ( $post instanceof WP_Post && 'page' === $post->post_type && in_array( $post->post_name, array( 'promocoes-2', 'promocoes-3' ), true ) ) {
		$archive = get_post_type_archive_link( 'go_promotion' );
		if ( $archive ) {
			return $archive;
		}
	}
	return $link;
}
add_filter( 'page_link', 'go_verge_duplicate_promotions_page_link', 20, 2 );

/**
 * Nota de transparência ao final das matérias de guia de compra. A exigência
 * (código de defesa do consumidor + boas práticas dos afiliados) é declarar a
 * relação comercial de forma clara. A data dos valores é dinâmica — vem da
 * última atualização da matéria —, então nunca envelhece no texto.
 *
 * @param string $content Conteúdo do post.
 * @return string
 */
function go_verge_buying_guide_transparency_note( $content ) {
	if ( is_admin() || is_feed() || ! is_singular( 'post' ) || ! in_the_loop() || ! is_main_query() ) {
		return $content;
	}
	if ( false !== strpos( $content, 'go-transparency-note' ) ) {
		return $content;
	}

	$post_id = get_the_ID();
	$slugs   = go_verge_buying_guides_category_slugs();
	$term_ids = function_exists( 'go_verge_category_ids' )
		? go_verge_category_ids( $slugs, array( 'guia-de-compra' ) )
		: array();
	if ( empty( $term_ids ) || ! has_term( $term_ids, 'category', $post_id ) ) {
		return $content;
	}

	$timestamp = get_post_timestamp( $post_id, 'modified' );
	if ( ! $timestamp ) {
		$timestamp = get_post_timestamp( $post_id );
	}
	$when = $timestamp ? wp_date( 'F \d\e Y', $timestamp ) : '';

	$note  = '<aside class="go-transparency-note" role="note">';
	$note .= '<p>' . esc_html__( 'A escolha dos produtos é da redação — marca nenhuma paga por posição nesta lista. Quando você compra por um dos nossos links, a Amazon ou o Mercado Livre repassam ao Overdrive uma pequena comissão, e o preço para você continua exatamente o mesmo. É assim que o site segue de graça.', 'go-verge' );
	if ( '' !== $when ) {
		$note .= ' ' . esc_html( sprintf( __( 'Preços e estoque mudam o tempo todo; os valores citados aqui foram apurados em %s.', 'go-verge' ), $when ) );
	} else {
		$note .= ' ' . esc_html__( 'Preços e estoque mudam o tempo todo e podem estar diferentes na hora da sua compra.', 'go-verge' );
	}
	$note .= '</p></aside>';

	return $content . $note;
}
add_filter( 'the_content', 'go_verge_buying_guide_transparency_note', 24 );

/** Links internos da categoria passam a apontar para o hub. */
function go_verge_buying_guides_term_link( $url, $term, $taxonomy ) {
	if ( 'category' !== $taxonomy || ! ( $term instanceof WP_Term ) ) {
		return $url;
	}
	if ( ! in_array( $term->slug, go_verge_buying_guides_category_slugs(), true ) ) {
		return $url;
	}
	$canonical = go_verge_canonical_buying_guides_url();
	return '' !== $canonical ? $canonical : $url;
}
add_filter( 'term_link', 'go_verge_buying_guides_term_link', 22, 3 );
