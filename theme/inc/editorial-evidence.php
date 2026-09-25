<?php
/**
 * Editorial evidence layer: first-party reporting notes and primary sources.
 *
 * The fields are deliberately optional and human-authored. They exist to make
 * real reporting evidence visible to readers and machines; they never infer or
 * fabricate first-hand experience.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Parse one source per line: "Label | https://example.com/..." or URL only. */
function go_verge_editorial_evidence_parse_sources( $raw ) {
	$lines = preg_split( '/\r\n|\r|\n/', (string) $raw );
	$out   = array();
	$seen  = array();

	foreach ( (array) $lines as $line ) {
		$line = trim( (string) $line );
		if ( '' === $line ) {
			continue;
		}

		$label = '';
		$url   = $line;
		if ( false !== strpos( $line, '|' ) ) {
			list( $label, $url ) = array_map( 'trim', explode( '|', $line, 2 ) );
		}

		$url = esc_url_raw( $url, array( 'http', 'https' ) );
		if ( ! $url || isset( $seen[ $url ] ) ) {
			continue;
		}
		$seen[ $url ] = true;

		if ( '' === $label ) {
			$host  = (string) wp_parse_url( $url, PHP_URL_HOST );
			$label = preg_replace( '/^www\./i', '', $host );
		}
		$label = sanitize_text_field( $label );
		if ( '' === $label ) {
			$label = __( 'Fonte', 'go-verge' );
		}

		$out[] = array(
			'label' => $label,
			'url'   => $url,
		);
		if ( count( $out ) >= 8 ) {
			break;
		}
	}

	return $out;
}

/** Return saved reporting note. */
function go_verge_editorial_evidence_method( $post_id ) {
	return trim( (string) get_post_meta( absint( $post_id ), '_go_reporting_method', true ) );
}

/** Return normalized primary/editorial sources. */
function go_verge_editorial_evidence_sources( $post_id ) {
	return go_verge_editorial_evidence_parse_sources( get_post_meta( absint( $post_id ), '_go_primary_sources', true ) );
}

/** Register the newsroom evidence box. */
function go_verge_register_editorial_evidence_meta_box() {
	add_meta_box(
		'go-verge-editorial-evidence',
		__( 'Apuração e fontes', 'go-verge' ),
		'go_verge_render_editorial_evidence_meta_box',
		'post',
		'normal',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_editorial_evidence_meta_box' );

function go_verge_render_editorial_evidence_meta_box( $post ) {
	wp_nonce_field( 'go_verge_editorial_evidence_save', 'go_verge_editorial_evidence_nonce' );
	$method  = go_verge_editorial_evidence_method( $post->ID );
	$sources = (string) get_post_meta( $post->ID, '_go_primary_sources', true );
	?>
	<p><strong><?php esc_html_e( 'Como apuramos / evidência de experiência direta', 'go-verge' ); ?></strong></p>
	<p class="description"><?php esc_html_e( 'Opcional. Preencha somente com algo verdadeiro e útil ao leitor: teste realizado, entrevista, demonstração, documento consultado, conferência de catálogo, medição ou outro método real. Não use como texto promocional.', 'go-verge' ); ?></p>
	<textarea name="go_reporting_method" rows="4" style="width:100%" maxlength="1200" placeholder="Ex.: Testamos a versão de PS5 por 12 horas e conferimos o patch 1.02 antes da publicação."><?php echo esc_textarea( $method ); ?></textarea>

	<p style="margin-top:16px"><strong><?php esc_html_e( 'Fontes primárias / referências principais', 'go-verge' ); ?></strong></p>
	<p class="description"><?php esc_html_e( 'Até 8 fontes. Uma por linha no formato Nome | URL. Elas serão exibidas ao leitor no fim da matéria.', 'go-verge' ); ?></p>
	<textarea name="go_primary_sources" rows="6" style="width:100%;font-family:monospace" placeholder="Rockstar Games | https://www.rockstargames.com/...&#10;PlayStation Blog | https://blog.playstation.com/... "><?php echo esc_textarea( $sources ); ?></textarea>
	<?php
}

/** Save evidence fields without changing post content. */
function go_verge_save_editorial_evidence( $post_id ) {
	if ( ! isset( $_POST['go_verge_editorial_evidence_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_editorial_evidence_nonce'] ) ), 'go_verge_editorial_evidence_save' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$method = isset( $_POST['go_reporting_method'] ) ? sanitize_textarea_field( wp_unslash( $_POST['go_reporting_method'] ) ) : '';
	if ( function_exists( 'mb_substr' ) ) {
		$method = mb_substr( $method, 0, 1200, 'UTF-8' );
	} else {
		$method = substr( $method, 0, 1200 );
	}
	if ( '' === trim( $method ) ) {
		delete_post_meta( $post_id, '_go_reporting_method' );
	} else {
		update_post_meta( $post_id, '_go_reporting_method', $method );
	}

	$raw_sources = isset( $_POST['go_primary_sources'] ) ? sanitize_textarea_field( wp_unslash( $_POST['go_primary_sources'] ) ) : '';
	$sources     = go_verge_editorial_evidence_parse_sources( $raw_sources );
	if ( empty( $sources ) ) {
		delete_post_meta( $post_id, '_go_primary_sources' );
	} else {
		$normalized = array();
		foreach ( $sources as $source ) {
			$normalized[] = $source['label'] . ' | ' . $source['url'];
		}
		update_post_meta( $post_id, '_go_primary_sources', implode( "\n", $normalized ) );
	}
}
add_action( 'save_post_post', 'go_verge_save_editorial_evidence', 40 );

/** Visible evidence block; structured data below mirrors only what is shown. */
function go_verge_append_editorial_evidence( $content ) {
	if ( is_admin() || is_feed() || ! is_singular( 'post' ) || ! in_the_loop() || ! is_main_query() ) {
		return $content;
	}

	$post_id = get_the_ID();
	$method  = go_verge_editorial_evidence_method( $post_id );
	$sources = go_verge_editorial_evidence_sources( $post_id );
	if ( '' === $method && empty( $sources ) ) {
		return $content;
	}

	$html = '<aside class="go-editorial-evidence go-article-sources" aria-label="' . esc_attr__( 'Apuração e fontes', 'go-verge' ) . '">';
	$html .= '<h2>' . esc_html__( 'Apuração e fontes', 'go-verge' ) . '</h2>';
	if ( '' !== $method ) {
		$html .= '<p><strong>' . esc_html__( 'Como apuramos:', 'go-verge' ) . '</strong> ' . esc_html( $method ) . '</p>';
	}
	if ( $sources ) {
		$html .= '<div class="go-editorial-evidence__sources"><strong>' . esc_html__( 'Fontes principais:', 'go-verge' ) . '</strong><ul>';
		foreach ( $sources as $source ) {
			$html .= '<li><a href="' . esc_url( $source['url'] ) . '" target="_blank" rel="noopener noreferrer">' . esc_html( $source['label'] ) . '<span class="screen-reader-text"> ' . esc_html__( '(abre em nova aba)', 'go-verge' ) . '</span></a></li>';
		}
		$html .= '</ul></div>';
	}
	$html .= '</aside>';

	return $content . $html;
}
add_filter( 'the_content', 'go_verge_append_editorial_evidence', 90 );


/**
 * Give legacy/manual source lists the same visible provenance component used by
 * the structured editorial-evidence field.
 *
 * The wrapper is intentionally narrow: only a top-level H2 whose visible label
 * is exactly a source heading AND which is immediately followed by a list is
 * touched. Ordinary lists and headings remain byte-for-byte unchanged.
 *
 * @param string $content Rendered post content.
 * @return string
 */
function go_verge_wrap_manual_source_lists( $content ) {
	if ( is_admin() || is_feed() || ! is_singular( 'post' ) || ! in_the_loop() || ! is_main_query() || ! is_string( $content ) ) {
		return $content;
	}
	if ( false !== strpos( $content, 'class="go-article-sources"' ) ) {
		/* A structured evidence block can coexist with manual prose, but never
		 * wrap a block that was already normalized by an earlier pass. */
	}

	$wrapped = false;
	return (string) preg_replace_callback(
		'/((?:<h2\\b[^>]*>).*?<\\/h2>)\\s*(<ul\\b[^>]*>.*?<\\/ul>)/isu',
		static function ( $match ) use ( &$wrapped ) {
			if ( $wrapped ) {
				return $match[0];
			}

			$label = html_entity_decode( wp_strip_all_tags( (string) $match[1] ), ENT_QUOTES | ENT_HTML5, get_bloginfo( 'charset' ) ?: 'UTF-8' );
			$label = trim( preg_replace( '/\\s+/u', ' ', $label ) );
			$norm  = mb_strtolower( remove_accents( $label ) );
			if ( ! preg_match( '/^fontes(?:\\s+(?:consultadas|principais|e referencias))?$/u', $norm ) ) {
				return $match[0];
			}

			$wrapped = true;
			return '<aside class="go-article-sources go-article-sources--manual" aria-label="' . esc_attr( $label ) . '">' . $match[1] . $match[2] . '</aside>';
		},
		$content
	);
}
add_filter( 'the_content', 'go_verge_wrap_manual_source_lists', 10018 );

/**
 * Add source citations to the existing Article node only when they are also
 * rendered visibly. This is ordinary schema.org provenance, not an AI-only tag.
 */
function go_verge_editorial_evidence_rank_math_json_ld( $data, $jsonld = null ) {
	if ( ! is_singular( 'post' ) || ! is_array( $data ) ) {
		return $data;
	}
	$post_id = get_queried_object_id();
	$sources = go_verge_editorial_evidence_sources( $post_id );
	if ( empty( $sources ) ) {
		return $data;
	}

	$citations = array();
	foreach ( $sources as $source ) {
		$citations[] = array(
			'@type' => 'CreativeWork',
			'name'  => $source['label'],
			'url'   => $source['url'],
		);
	}

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) {
			continue;
		}
		if ( go_verge_schema_node_matches_url( $node, get_permalink( $post_id ), array( 'Article', 'NewsArticle', 'BlogPosting', 'Review' ) ) ) {
			$data[ $key ]['citation'] = $citations;
			break;
		}
	}
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_editorial_evidence_rank_math_json_ld', 96, 2 );
