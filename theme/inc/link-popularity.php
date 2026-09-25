<?php
/**
 * Popularidade interna de links: as sugestões do editor (Ctrl+K) passam a
 * mostrar primeiro os artigos e arquivos (tags/categorias) que a redação
 * mais linka nas matérias.
 *
 * Como funciona: ao salvar um post, os links internos do conteúdo viram uma
 * lista de caminhos normalizados no meta `_go_links_out_paths`. Um agregado
 * (transient de 12 horas) soma quantas vezes cada caminho é linkado no site
 * inteiro, e o endpoint /wp/v2/search — usado pelas sugestões de link do
 * Gutenberg — é reordenado por essa contagem, preservando a ordem de
 * relevância original como desempate. O acervo antigo é indexado em lotes
 * pelo cron, sem travar nada.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Post types cujos conteúdos alimentam o índice. */
function go_verge_linkpop_post_types() {
	return array( 'post', 'page', 'games' );
}

/**
 * Normaliza uma URL interna para um caminho comparável ('' quando externa).
 *
 * @param string $url URL absoluta ou relativa.
 * @return string Ex.: 'tag/xbox' ou 'melhor-monitor-ps5-xbox'.
 */
function go_verge_linkpop_normalize_path( $url ) {
	$url = html_entity_decode( (string) $url, ENT_QUOTES );
	if ( '' === trim( $url ) || 0 === strpos( $url, '#' ) || 0 === strpos( $url, 'mailto:' ) ) {
		return '';
	}

	$host = strtolower( (string) wp_parse_url( $url, PHP_URL_HOST ) );
	if ( '' !== $host ) {
		$site_host = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
		if ( preg_replace( '/^www\./', '', $host ) !== preg_replace( '/^www\./', '', $site_host ) ) {
			return '';
		}
	}

	$path = strtolower( trim( (string) wp_parse_url( $url, PHP_URL_PATH ), '/' ) );
	if ( '' === $path ) {
		return '';
	}
	$path = preg_replace( '~/amp$~', '', $path );
	if ( preg_match( '~^wp-(admin|content|login)~', $path ) ) {
		return '';
	}
	return $path;
}

/**
 * Extrai os caminhos internos linkados em um conteúdo.
 *
 * @param string $content Post content (raw).
 * @return array<string>
 */
function go_verge_linkpop_extract_paths( $content ) {
	if ( ! is_string( $content ) || false === stripos( $content, 'href' ) ) {
		return array();
	}
	if ( ! preg_match_all( '/\bhref="([^"]+)"/i', $content, $matches ) ) {
		return array();
	}
	$paths = array();
	foreach ( $matches[1] as $href ) {
		$path = go_verge_linkpop_normalize_path( $href );
		if ( '' !== $path ) {
			$paths[] = $path;
		}
	}
	return $paths;
}

/**
 * Indexa os links de saída de um post ao salvar.
 *
 * @param int     $post_id Post ID.
 * @param WP_Post $post    Post.
 */
function go_verge_linkpop_index_post( $post_id, $post ) {
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( ! ( $post instanceof WP_Post ) || ! in_array( $post->post_type, go_verge_linkpop_post_types(), true ) ) {
		return;
	}
	if ( 'publish' !== $post->post_status ) {
		delete_post_meta( $post_id, '_go_links_out_paths' );
		delete_transient( 'go_verge_linkpop_counts' );
		return;
	}

	update_post_meta( $post_id, '_go_links_out_paths', go_verge_linkpop_extract_paths( (string) $post->post_content ) );
	delete_transient( 'go_verge_linkpop_counts' );
}
add_action( 'save_post', 'go_verge_linkpop_index_post', 40, 2 );

/**
 * Contagem agregada: caminho normalizado => vezes linkado no site.
 *
 * @return array<string,int>
 */
function go_verge_linkpop_counts() {
	$cached = get_transient( 'go_verge_linkpop_counts' );
	if ( is_array( $cached ) ) {
		return $cached;
	}

	global $wpdb;
	$values = $wpdb->get_col(
		$wpdb->prepare(
			"SELECT pm.meta_value FROM {$wpdb->postmeta} pm
			 INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
			 WHERE pm.meta_key = %s AND p.post_status = 'publish'",
			'_go_links_out_paths'
		)
	);

	$counts = array();
	foreach ( (array) $values as $value ) {
		$paths = maybe_unserialize( $value );
		if ( ! is_array( $paths ) ) {
			continue;
		}
		foreach ( $paths as $path ) {
			$path = (string) $path;
			if ( '' === $path ) {
				continue;
			}
			$counts[ $path ] = (int) ( $counts[ $path ] ?? 0 ) + 1;
		}
	}

	set_transient( 'go_verge_linkpop_counts', $counts, 12 * HOUR_IN_SECONDS );
	return $counts;
}

/**
 * Reordena as sugestões de link do editor: mais relevantes primeiro, usando popularidade interna como
 * reforço limitado — não como substituto da relação semântica. Vale para posts e termos (tags).
 *
 * @param WP_REST_Response|WP_Error $response Result.
 * @param array                     $handler  Handler.
 * @param WP_REST_Request           $request  Request.
 * @return WP_REST_Response|WP_Error
 */
function go_verge_linkpop_sort_search( $response, $handler, $request ) {
	if ( '/wp/v2/search' !== $request->get_route() || ! ( $response instanceof WP_REST_Response ) ) {
		return $response;
	}
	$data = $response->get_data();
	if ( ! is_array( $data ) || count( $data ) < 2 ) {
		return $response;
	}

	$counts = go_verge_linkpop_counts();
	if ( empty( $counts ) ) {
		return $response;
	}

	$decorated = array();
	foreach ( $data as $index => $item ) {
		$path       = is_array( $item ) && ! empty( $item['url'] ) ? go_verge_linkpop_normalize_path( (string) $item['url'] ) : '';
		$popularity = '' !== $path && isset( $counts[ $path ] ) ? (int) $counts[ $path ] : 0;
		/* V46: preserve Gutenberg's query relevance as the dominant signal and
		 * use link popularity only as a bounded quality hint. The old popularity-
		 * first sort could push a famous but weakly-related page above the exact
		 * destination the editor searched for. */
		$relevance  = max( 0, 100 - ( (int) $index * 8 ) );
		$pop_bonus  = min( 24, (int) round( log( $popularity + 1, 2 ) * 5 ) );
		$blend      = $relevance + $pop_bonus;
		$decorated[] = array( $blend, $index, $item );
	}
	usort(
		$decorated,
		static function ( $a, $b ) {
			if ( $a[0] !== $b[0] ) { return $b[0] <=> $a[0]; }
			return $a[1] <=> $b[1];
		}
	);

	$response->set_data( array_values( wp_list_pluck( $decorated, 2 ) ) );
	return $response;
}
add_filter( 'rest_request_after_callbacks', 'go_verge_linkpop_sort_search', 20, 3 );

/* -------------------------------------------------------------------------
 * Backfill do acervo: lotes de 40 posts a cada 2 minutos via cron, uma vez.
 * ---------------------------------------------------------------------- */

/** Agenda o primeiro lote quando o índice ainda não existe. */
function go_verge_linkpop_schedule_backfill() {
	if ( get_option( 'go_verge_linkpop_backfill_done' ) ) {
		wp_clear_scheduled_hook( 'go_verge_linkpop_backfill' );
		return;
	}
	if ( ! wp_next_scheduled( 'go_verge_linkpop_backfill' ) ) {
		wp_schedule_single_event( time() + 60, 'go_verge_linkpop_backfill' );
	}
}
add_action( 'init', 'go_verge_linkpop_schedule_backfill', 30 );

/** Processa um lote e agenda o próximo até terminar. */
function go_verge_linkpop_run_backfill() {
	if ( get_option( 'go_verge_linkpop_backfill_done' ) ) {
		return;
	}
	if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( 'linkpop_backfill', 120 ) ) {
		if ( ! wp_next_scheduled( 'go_verge_linkpop_backfill' ) ) {
			wp_schedule_single_event( time() + 2 * MINUTE_IN_SECONDS, 'go_verge_linkpop_backfill' );
		}
		return;
	}

	$batch_size = 40;
	$offset     = (int) get_option( 'go_verge_linkpop_backfill_offset', 0 );
	$posts      = array();

	try {
		$posts = get_posts(
			array(
				'post_type'              => go_verge_linkpop_post_types(),
				'post_status'            => 'publish',
				'posts_per_page'         => $batch_size,
				'offset'                 => $offset,
				'orderby'                => 'ID',
				'order'                  => 'ASC',
				'fields'                 => 'ids',
				'no_found_rows'          => true,
				'suppress_filters'       => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
			)
		);

		if ( ! empty( $posts ) ) {
			foreach ( $posts as $post_id ) {
				if ( metadata_exists( 'post', $post_id, '_go_links_out_paths' ) ) {
					continue;
				}
				$content = (string) get_post_field( 'post_content', $post_id, 'raw' );
				update_post_meta( $post_id, '_go_links_out_paths', go_verge_linkpop_extract_paths( $content ) );
			}
			update_option( 'go_verge_linkpop_backfill_offset', $offset + count( $posts ), false );
		}
	} finally {
		go_verge_release_job_lock( 'linkpop_backfill' );
	}

	if ( empty( $posts ) || count( $posts ) < $batch_size ) {
		update_option( 'go_verge_linkpop_backfill_done', 1, false );
		delete_option( 'go_verge_linkpop_backfill_offset' );
		delete_transient( 'go_verge_linkpop_counts' );
		wp_clear_scheduled_hook( 'go_verge_linkpop_backfill' );
		return;
	}

	if ( ! wp_next_scheduled( 'go_verge_linkpop_backfill' ) ) {
		wp_schedule_single_event( time() + 2 * MINUTE_IN_SECONDS, 'go_verge_linkpop_backfill' );
	}
}
add_action( 'go_verge_linkpop_backfill', 'go_verge_linkpop_run_backfill' );
