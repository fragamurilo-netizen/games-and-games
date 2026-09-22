<?php
/**
 * Overdrive V45 — one coherent subject experience for generic topics,
 * productions and curated entities.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Shared page size for subject coverage. */
function go_verge_v45_subject_per_page() {
	return 14;
}

/**
 * Reader-facing labels for the controlled "Tipo de matéria" vocabulary.
 * Only types that actually exist inside a subject cluster are rendered.
 *
 * @return array<string,string>
 */
function go_verge_v45_subject_type_labels() {
	return array(
		'noticia'         => __( 'Notícias', 'go-verge' ),
		'guia'            => __( 'Guias', 'go-verge' ),
		'review'          => __( 'Reviews', 'go-verge' ),
		'critica'         => __( 'Críticas', 'go-verge' ),
		'onde-assistir'   => __( 'Onde assistir', 'go-verge' ),
		'final-explicado' => __( 'Finais explicados', 'go-verge' ),
		'especial'        => __( 'Especiais', 'go-verge' ),
		'lista'           => __( 'Listas', 'go-verge' ),
		'ranking'         => __( 'Rankings', 'go-verge' ),
		'impressoes'      => __( 'Impressões', 'go-verge' ),
		'oferta'          => __( 'Ofertas', 'go-verge' ),
		'guia-de-compra'  => __( 'Guias de compra', 'go-verge' ),
	);
}

/** Valid content-type slug selected by the reader through ?tipo=. */
function go_verge_v45_subject_active_type() {
	if ( ! isset( $_GET['tipo'] ) || is_array( $_GET['tipo'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return '';
	}
	$type = sanitize_title( wp_unslash( $_GET['tipo'] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	return isset( go_verge_v45_subject_type_labels()[ $type ] ) ? $type : '';
}

/**
 * Resolve the controlled editorial type for one story.
 * The structured go_content_type taxonomy is authoritative; category matching
 * only keeps older stories filterable while the background repair catches up.
 */
function go_verge_v45_story_content_type( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return ''; }
	if ( function_exists( 'go_verge_v7_post_content_type' ) ) {
		$type = sanitize_title( (string) go_verge_v7_post_content_type( $post_id ) );
		if ( isset( go_verge_v45_subject_type_labels()[ $type ] ) ) { return $type; }
	}

	if ( function_exists( 'go_verge_product_related_post_matches_args' ) ) {
		$groups = array(
			'review'          => array( 'reviews', 'review', 'analises', 'analises-de-jogos' ),
			'critica'         => array( 'criticas', 'critica' ),
			'guia-de-compra'  => array( 'guias-de-compra', 'guia-de-compra' ),
			'guia'            => array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'dica', 'tutoriais', 'tutorial' ),
			'onde-assistir'   => array( 'onde-assistir', 'onde-assistir-online', 'assistir-online' ),
			'especial'        => array( 'especiais', 'especial' ),
			'lista'           => array( 'listas', 'lista' ),
			'ranking'         => array( 'rankings', 'ranking' ),
			'oferta'          => array( 'promocoes', 'promocao', 'ofertas', 'oferta' ),
		);
		foreach ( $groups as $type => $slugs ) {
			if ( go_verge_product_related_post_matches_args( $post_id, array( 'category_slugs' => $slugs ) ) ) { return $type; }
		}
	}
	return function_exists( 'go_verge_post_is_news_article' ) && go_verge_post_is_news_article( $post_id ) ? 'noticia' : 'noticia';
}

/** Filter an already ordered subject story pool without changing its order. */
function go_verge_v45_filter_subject_ids_by_type( $ids, $type ) {
	$ids  = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	$type = sanitize_title( (string) $type );
	if ( ! $ids || ! isset( go_verge_v45_subject_type_labels()[ $type ] ) ) { return $ids; }
	if ( function_exists( 'update_object_term_cache' ) ) { update_object_term_cache( $ids, 'post' ); }
	return array_values( array_filter( $ids, static function( $post_id ) use ( $type ) {
		return $type === go_verge_v45_story_content_type( $post_id );
	} ) );
}

/** Counts by editorial type for the whole subject cluster, not just page one. */
function go_verge_v45_subject_type_counts( $ids ) {
	$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	$counts = array( 'all' => count( $ids ) );
	foreach ( go_verge_v45_subject_type_labels() as $type => $label ) { $counts[ $type ] = 0; }
	if ( function_exists( 'update_object_term_cache' ) && $ids ) { update_object_term_cache( $ids, 'post' ); }
	foreach ( $ids as $post_id ) {
		$type = go_verge_v45_story_content_type( $post_id );
		if ( isset( $counts[ $type ] ) ) { $counts[ $type ]++; }
	}
	return $counts;
}

/**
 * Shared filter UI for /universo/, /producoes/ and /assunto/ hubs.
 * Links are real URLs so filtering works without JavaScript and remains
 * accessible; filtered variants are canonicalised/noindexed below.
 */
function go_verge_v45_render_subject_type_filters( $ids, $base_url, $active_type = '' ) {
	$ids         = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	$base_url    = esc_url_raw( (string) $base_url );
	$active_type = sanitize_title( (string) $active_type );
	if ( ! $ids || ! $base_url ) { return; }
	$counts = go_verge_v45_subject_type_counts( $ids );
	$visible = array_filter( $counts, static function( $count, $key ) { return 'all' !== $key && (int) $count > 0; }, ARRAY_FILTER_USE_BOTH );
	if ( count( $visible ) < 2 ) { return; }
	$labels = go_verge_v45_subject_type_labels();
	?>
	<nav class="go-subject-type-filters" aria-label="<?php esc_attr_e( 'Filtrar matérias por tipo', 'go-verge' ); ?>">
		<a href="<?php echo esc_url( $base_url ); ?>" class="<?php echo $active_type ? '' : 'is-active'; ?>"<?php echo $active_type ? '' : ' aria-current="page"'; ?>>
			<?php esc_html_e( 'Tudo', 'go-verge' ); ?><span><?php echo esc_html( number_format_i18n( (int) $counts['all'] ) ); ?></span>
		</a>
		<?php foreach ( $labels as $type => $label ) : if ( empty( $counts[ $type ] ) ) { continue; } $active = $active_type === $type; ?>
			<a href="<?php echo esc_url( add_query_arg( 'tipo', $type, $base_url ) ); ?>" class="<?php echo $active ? 'is-active' : ''; ?>"<?php echo $active ? ' aria-current="page"' : ''; ?>>
				<?php echo esc_html( $label ); ?><span><?php echo esc_html( number_format_i18n( (int) $counts[ $type ] ) ); ?></span>
			</a>
		<?php endforeach; ?>
	</nav>
	<?php
}

/** Current coverage page for first-class subject hubs. */
function go_verge_v45_subject_page() {
	return max( 1, absint( get_query_var( 'go_subject_page' ) ) );
}

/** Public name for something the reader can follow. */
function go_verge_v45_follow_object_name( $object_id, $object_type ) {
	$object_id   = absint( $object_id );
	$object_type = sanitize_key( (string) $object_type );
	if ( ! $object_id ) { return ''; }

	if ( 'post_tag' === $object_type ) {
		$term = get_term( $object_id, 'post_tag' );
		return ( $term instanceof WP_Term && ! is_wp_error( $term ) ) ? trim( wp_strip_all_tags( $term->name ) ) : '';
	}
	if ( in_array( $object_type, array( 'games', 'productions', 'go_entity' ), true ) && $object_type === get_post_type( $object_id ) ) {
		return trim( wp_strip_all_tags( get_the_title( $object_id ) ) );
	}
	return '';
}

/** Named follow labels make the action clear: "Seguir Meu Nome é Farah". */
function go_verge_v45_follow_label( $object_id, $object_type ) {
	$name = go_verge_v45_follow_object_name( $object_id, $object_type );
	if ( $name ) {
		return sprintf( __( 'Seguir %s', 'go-verge' ), $name );
	}
	if ( 'games' === $object_type ) { return __( 'Seguir jogo', 'go-verge' ); }
	if ( 'productions' === $object_type ) { return __( 'Seguir produção', 'go-verge' ); }
	return __( 'Seguir assunto', 'go-verge' );
}

/** Register pretty coverage pagination for first-class subject pages. */
function go_verge_v45_subject_rewrite() {
	global $wp_rewrite;
	$pagination_base = ( $wp_rewrite instanceof WP_Rewrite && ! empty( $wp_rewrite->pagination_base ) ) ? $wp_rewrite->pagination_base : 'page';
	$pagination_base = preg_quote( trim( (string) $pagination_base, '/' ), '#' );

	add_rewrite_rule(
		'^producoes/([^/]+)/' . $pagination_base . '/([0-9]{1,})/?$',
		'index.php?post_type=productions&name=$matches[1]&go_subject_page=$matches[2]',
		'top'
	);
	add_rewrite_rule(
		'^universo/([^/]+)/' . $pagination_base . '/([0-9]{1,})/?$',
		'index.php?post_type=go_entity&name=$matches[1]&go_subject_page=$matches[2]',
		'top'
	);
}
add_action( 'init', 'go_verge_v45_subject_rewrite', 30 );
add_filter( 'query_vars', static function( $vars ) { $vars[] = 'go_subject_page'; return array_values( array_unique( $vars ) ); }, 40 );

/** Flush once after the new routes are installed. */
function go_verge_v45_maybe_flush_subject_rewrite() {
	if ( get_option( 'go_verge_subject_rewrite_v45' ) === GO_VERGE_VERSION ) { return; }
	go_verge_v45_subject_rewrite();
	go_verge_flush_rewrite_rules_once_per_request();
	update_option( 'go_verge_subject_rewrite_v45', GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_v45_maybe_flush_subject_rewrite', 100 );

/** All related stories for a first-class subject, already newest-first. */
function go_verge_v45_subject_related_ids( $object_id, $object_type, $limit = 500 ) {
	$object_id   = absint( $object_id );
	$object_type = sanitize_key( (string) $object_type );
	$limit       = max( 1, min( 500, absint( $limit ) ) );
	if ( ! $object_id || ! in_array( $object_type, array( 'productions', 'go_entity' ), true ) ) { return array(); }
	if ( ! function_exists( 'go_verge_product_related_post_ids' ) ) { return array(); }

	/* V74 — a public /universo/ page must self-heal on the request that renders it.
	 * Previous builds waited for WP-Cron to hydrate historical relationships, so
	 * an entity such as Metal Gear Solid could visibly show one article even when
	 * the cluster detector had already found several strong matches. Merge the
	 * live discovery pool with canonical relationships immediately; the hydrator
	 * persists those matches for future requests without making the page depend on
	 * cron or a stale entity-story transient. */
	$live_ids = array();
	if ( 'go_entity' === $object_type && function_exists( 'go_verge_v72_hydrate_entity' ) ) {
		$live_ids = array_map( 'absint', (array) go_verge_v72_hydrate_entity( $object_id ) );
	}
	$canonical_ids = array_map( 'absint', (array) go_verge_product_related_post_ids( $object_id, $object_type, $limit ) );
	$ids = array_values( array_unique( array_filter( array_merge( $live_ids, $canonical_ids ) ) ) );
	usort( $ids, static function( $a, $b ) {
		return (int) get_post_time( 'U', true, $b ) <=> (int) get_post_time( 'U', true, $a );
	} );
	return array_slice( $ids, 0, $limit );
}

/** Slice a subject's coverage for the requested page. */
function go_verge_v45_subject_page_data( $object_id, $object_type, $page = 1, $content_type = '' ) {
	$page           = max( 1, absint( $page ) );
	$per_page       = go_verge_v45_subject_per_page();
	$unfiltered_ids = go_verge_v45_subject_related_ids( $object_id, $object_type, 500 );
	$all_ids        = go_verge_v45_filter_subject_ids_by_type( $unfiltered_ids, $content_type );
	$total          = count( $all_ids );
	$pages          = max( 1, (int) ceil( $total / $per_page ) );
	$offset         = ( $page - 1 ) * $per_page;
	return array(
		'all_ids'            => $all_ids,
		'all_ids_unfiltered' => $unfiltered_ids,
		'ids'                => array_slice( $all_ids, $offset, $per_page ),
		'total'              => $total,
		'total_pages'        => $pages,
		'page'               => $page,
		'per_page'           => $per_page,
		'content_type'       => sanitize_title( (string) $content_type ),
	);
}

/** Self-canonical URL for one coverage page. */
function go_verge_v45_subject_page_url( $object_id, $page = 1 ) {
	$object_id = absint( $object_id );
	$page      = max( 1, absint( $page ) );
	$base      = $object_id ? get_permalink( $object_id ) : '';
	if ( ! $base || 1 === $page ) { return $base; }
	global $wp_rewrite;
	$pagination_base = ( $wp_rewrite instanceof WP_Rewrite && ! empty( $wp_rewrite->pagination_base ) ) ? $wp_rewrite->pagination_base : 'page';
	return trailingslashit( $base ) . user_trailingslashit( trim( (string) $pagination_base, '/' ) . '/' . $page );
}

/** Generic accessible pagination used by Production and Entity subject hubs. */
function go_verge_v45_render_subject_pagination( $object_id, $page, $total_pages ) {
	$page        = max( 1, absint( $page ) );
	$total_pages = max( 1, absint( $total_pages ) );
	if ( $total_pages < 2 ) { return; }
	$base = trailingslashit( get_permalink( $object_id ) ) . '%_%';
	global $wp_rewrite;
	$pagination_base = ( $wp_rewrite instanceof WP_Rewrite && ! empty( $wp_rewrite->pagination_base ) ) ? $wp_rewrite->pagination_base : 'page';
	$format = trim( (string) $pagination_base, '/' ) . '/%#%/';
	$html = paginate_links( array(
		'base'      => $base,
		'format'    => $format,
		'current'   => $page,
		'total'     => $total_pages,
		'mid_size'  => 2,
		'end_size'  => 1,
		'prev_text' => __( '← Anterior', 'go-verge' ),
		'next_text' => __( 'Próxima →', 'go-verge' ),
		'type'      => 'plain',
	) );
	if ( $html ) {
		echo '<nav class="go-topic-hub-v21__pagination" aria-label="' . esc_attr__( 'Paginação das publicações', 'go-verge' ) . '">' . wp_kses_post( $html ) . '</nav>';
	}
}

/** /page/1/ is a duplicate. Everything beyond the real last page is a real 404. */
function go_verge_v45_validate_first_class_subject_page() {
	if ( ! is_singular( array( 'productions', 'go_entity' ) ) ) { return; }
	$page = go_verge_v45_subject_page();
	if ( $page < 1 ) { return; }
	$id   = get_queried_object_id();
	$type = get_post_type( $id );
	if ( $page === 1 && preg_match( '#/(?:page|pagina)/1/?(?:\?.*)?$#i', (string) ( $_SERVER['REQUEST_URI'] ?? '' ) ) ) {
		wp_safe_redirect( get_permalink( $id ), 301, 'Overdrive subject page one' );
		exit;
	}
	if ( $page <= 1 ) { return; }
	$data = go_verge_v45_subject_page_data( $id, $type, $page, go_verge_v45_subject_active_type() );
	if ( $page <= $data['total_pages'] && ! empty( $data['ids'] ) ) { return; }
	global $wp_query;
	if ( $wp_query instanceof WP_Query ) { $wp_query->set_404(); }
	status_header( 404 );
	nocache_headers();
}
add_action( 'template_redirect', 'go_verge_v45_validate_first_class_subject_page', 5 );

/** Prevent core from collapsing valid /page/N/ subject coverage URLs. */
function go_verge_v45_subject_redirect_canonical( $redirect_url, $requested_url ) {
	if ( is_singular( array( 'productions', 'go_entity' ) ) && go_verge_v45_subject_page() > 1 ) { return false; }
	return $redirect_url;
}
add_filter( 'redirect_canonical', 'go_verge_v45_subject_redirect_canonical', 30, 2 );

/** Each paginated coverage page is self-canonical. */
function go_verge_v45_subject_rank_math_canonical( $canonical ) {
	if ( ! is_singular( array( 'productions', 'go_entity' ) ) ) { return $canonical; }
	$page = go_verge_v45_subject_page();
	if ( $page <= 1 ) { return $canonical; }
	$url = go_verge_v45_subject_page_url( get_queried_object_id(), $page );
	return $url ?: $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_v45_subject_rank_math_canonical', 1200 );

/** Helpful browser/SERP distinction for deeper coverage pages. */
function go_verge_v45_subject_document_title( $title ) {
	if ( ! is_singular( array( 'productions', 'go_entity' ) ) ) { return $title; }
	$page = go_verge_v45_subject_page();
	if ( $page <= 1 ) { return $title; }
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	return sprintf( __( '%1$s — página %2$d — %3$s', 'go-verge' ), single_post_title( '', false ), $page, $site_name );
}
add_filter( 'pre_get_document_title', 'go_verge_v45_subject_document_title', 1200 );



/** Filtered entity/production views are useful UI states, not Search landing pages. */
function go_verge_v45_filtered_subject_canonical( $canonical ) {
	if ( ! is_singular( array( 'productions', 'go_entity' ) ) || ! go_verge_v45_subject_active_type() ) { return $canonical; }
	$base = get_permalink( get_queried_object_id() );
	return $base ?: $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_v45_filtered_subject_canonical', 1700 );

function go_verge_v45_filtered_subject_wp_robots( $robots ) {
	if ( is_singular( array( 'productions', 'go_entity' ) ) && go_verge_v45_subject_active_type() && is_array( $robots ) ) {
		$robots['noindex'] = true;
		$robots['follow']  = true;
		unset( $robots['index'] );
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_v45_filtered_subject_wp_robots', 320 );

function go_verge_v45_filtered_subject_rank_math_robots( $robots ) {
	if ( is_singular( array( 'productions', 'go_entity' ) ) && go_verge_v45_subject_active_type() && is_array( $robots ) ) {
		$robots['index']  = 'noindex';
		$robots['follow'] = 'follow';
	}
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_v45_filtered_subject_rank_math_robots', 320 );

/** Generic topic /page/1/ should also collapse to its clean base URL. */
function go_verge_v45_topic_page_one_redirect() {
	if ( ! function_exists( 'go_verge_v21_is_topic_hub' ) || ! go_verge_v21_is_topic_hub() ) { return; }
	$page = max( 1, absint( get_query_var( 'paged' ) ) );
	if ( 1 !== $page || ! preg_match( '#/(?:page|pagina)/1/?(?:\?.*)?$#i', (string) ( $_SERVER['REQUEST_URI'] ?? '' ) ) ) { return; }
	$label = go_verge_v21_topic_label( get_query_var( 'go_topic' ) );
	wp_safe_redirect( go_verge_v21_topic_hub_url( $label ), 301, 'Overdrive topic page one' );
	exit;
}
add_action( 'template_redirect', 'go_verge_v45_topic_page_one_redirect', 4 );
