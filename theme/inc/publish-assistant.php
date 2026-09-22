<?php
/**
 * Assistente de publicação: pre-publish checklist that inspects the saved
 * post and raises editorial warnings — missing internal links, featured image
 * without alt text, long article without H2, linkable game mentioned but not
 * linked, review without tested platform, near-duplicate titles and older
 * coverage that deserves an update.
 *
 * Nothing here writes content; it only reads and reports.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/* --------------------------------------------------------------------------
 * Checks
 * ------------------------------------------------------------------------ */

/** Significant title tokens (lowercase, accents stripped, stopwords removed). */
function go_verge_assistant_title_tokens( $title ) {
	$stopwords = array(
		'para', 'com', 'sem', 'por', 'das', 'dos', 'uma', 'que', 'the', 'and',
		'como', 'mais', 'novo', 'nova', 'novos', 'novas', 'sobre', 'entre',
		'depois', 'antes', 'tudo', 'todos', 'toda', 'todas', 'veja', 'saiba',
		'analise', 'análise', 'review', 'critica', 'crítica', 'guia',
	);
	$plain  = strtolower( remove_accents( wp_strip_all_tags( (string) $title ) ) );
	$plain  = preg_replace( '/[^a-z0-9\s]/', ' ', $plain );
	$tokens = array_filter(
		preg_split( '/\s+/', $plain ),
		static function ( $token ) use ( $stopwords ) {
			return strlen( $token ) >= 4 && ! in_array( $token, $stopwords, true );
		}
	);
	return array_values( array_unique( $tokens ) );
}

/** Recently published titles used by the duplicate/update checks. */
function go_verge_assistant_recent_posts( $exclude_id ) {
	global $wpdb;
	$rows = $wpdb->get_results(
		$wpdb->prepare(
			"SELECT ID, post_title, post_date FROM {$wpdb->posts}
			 WHERE post_type = 'post' AND post_status = 'publish' AND ID != %d
			 ORDER BY post_date DESC LIMIT 400",
			$exclude_id
		)
	);
	return is_array( $rows ) ? $rows : array();
}

/**
 * Run every check against the saved post. Returns a flat list of items:
 * level (warn|info|ok), text, optional action {label, href}.
 */
function go_verge_publish_assistant_checks( $post_id ) {
	$post = get_post( $post_id );
	if ( ! $post || 'post' !== $post->post_type ) {
		return array();
	}

	$items   = array();
	$content = (string) $post->post_content;
	$plain   = wp_strip_all_tags( strip_shortcodes( $content ) );
	$words   = str_word_count( remove_accents( $plain ) );
	$host    = wp_parse_url( home_url(), PHP_URL_HOST );

	/* 1. Internal links ---------------------------------------------------- */
	$has_internal_link = false;
	if ( preg_match_all( '/<a\s[^>]*href=["\']([^"\']+)["\']/i', $content, $link_matches ) ) {
		foreach ( $link_matches[1] as $href ) {
			if ( 0 === strpos( $href, '/' ) && 0 !== strpos( $href, '//' ) ) {
				$has_internal_link = true;
				break;
			}
			$link_host = wp_parse_url( $href, PHP_URL_HOST );
			if ( $link_host && 0 === strcasecmp( $link_host, (string) $host ) ) {
				$has_internal_link = true;
				break;
			}
		}
	}
	if ( $has_internal_link ) {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Há pelo menos um link interno no texto.', 'go-verge' ) );
	} else {
		$items[] = array(
			'level' => 'warn',
			'text'  => __( 'Nenhum link interno: conecte a matéria a outra cobertura do site.', 'go-verge' ),
		);
	}


	/* Publication contract: valid desk/category and author ------------------ */
	$category_ids = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'ids' ) );
	if ( is_wp_error( $category_ids ) || empty( $category_ids ) ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'Matéria sem categoria editorial: defina a editoria antes de publicar.', 'go-verge' ) );
	} else {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Categoria editorial definida.', 'go-verge' ) );
	}

	/* Authority / E-E-A-T: accurate authorship and visible sourcing -------- */
	$author_id   = absint( $post->post_author );
	$author_user = $author_id ? get_userdata( $author_id ) : false;
	if ( ! $author_user ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'Autor inválido ou ausente. A matéria precisa de uma assinatura pública válida.', 'go-verge' ) );
	}
	$author_bio = $author_user ? trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', $author_id ) ) ) : '';
	$author_role = function_exists( 'go_verge_author_role' ) ? trim( (string) go_verge_author_role( $author_id ) ) : trim( (string) get_the_author_meta( 'gamxo_author_designation', $author_id ) );
	if ( '' === $author_bio || '' === $author_role ) {
		$missing = array();
		if ( '' === $author_bio ) { $missing[] = __( 'bio', 'go-verge' ); }
		if ( '' === $author_role ) { $missing[] = __( 'função editorial', 'go-verge' ); }
		$items[] = array(
			'level'  => 'warn',
			'text'   => sprintf(
				/* translators: %s: missing author profile fields. */
				__( 'Perfil público do autor incompleto: falta %s. A assinatura precisa levar a informações reais sobre quem produziu a matéria.', 'go-verge' ),
				implode( ' + ', $missing )
			),
			'action' => array(
				'label' => __( 'Editar autor', 'go-verge' ),
				'href'  => get_edit_user_link( $author_id ),
			),
		);
	} else {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Autoria com bio pública e função editorial identificável.', 'go-verge' ) );
	}

	$external_links = array();
	if ( preg_match_all( '/<a\s[^>]*href=["\']([^"\']+)["\']/i', $content, $source_matches ) ) {
		foreach ( $source_matches[1] as $href ) {
			$link_host = wp_parse_url( $href, PHP_URL_HOST );
			if ( $link_host && $host && 0 !== strcasecmp( (string) $link_host, (string) $host ) ) {
				$external_links[] = esc_url_raw( $href );
			}
		}
	}
	$external_links = array_values( array_unique( array_filter( $external_links ) ) );
	$evidence_sources = function_exists( 'go_verge_editorial_evidence_sources' ) ? go_verge_editorial_evidence_sources( $post_id ) : array();
	$content_type = function_exists( 'go_verge_v7_post_content_type' ) ? go_verge_v7_post_content_type( $post_id ) : '';
	if ( $evidence_sources ) {
		$items[] = array(
			'level' => 'ok',
			'text'  => sprintf(
				/* translators: %d: source count. */
				_n( '%d fonte principal registrada e visível.', '%d fontes principais registradas e visíveis.', count( $evidence_sources ), 'go-verge' ),
				count( $evidence_sources )
			),
		);
	} elseif ( $external_links ) {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Há referência externa no corpo da matéria. Para apurações importantes, considere também registrar as fontes principais no bloco de transparência.', 'go-verge' ) );
	} else {
		$items[] = array(
			'level' => 'noticia' === $content_type ? 'warn' : 'info',
			'text'  => __( 'Nenhuma fonte externa/primária visível. Se a matéria relata fatos obtidos de terceiros, linke a origem oficial ou registre a fonte principal; não invente fonte para cumprir checklist.', 'go-verge' ),
		);
	}

	$method = function_exists( 'go_verge_editorial_evidence_method' ) ? go_verge_editorial_evidence_method( $post_id ) : '';
	if ( '' !== $method ) {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Método de apuração/experiência direta documentado para o leitor.', 'go-verge' ) );
	} elseif ( function_exists( 'go_verge_post_is_guide' ) && go_verge_post_is_guide( $post_id ) ) {
		$items[] = array( 'level' => 'info', 'text' => __( 'Guia sem nota de “Como apuramos”. Se os passos foram testados diretamente, vale registrar como foram verificados.', 'go-verge' ) );
	}

	/* AI/Search eligibility: nosnippet also blocks direct use in AI features. */
	$rank_math_robots = maybe_unserialize( get_post_meta( $post_id, 'rank_math_robots', true ) );
	if ( empty( $rank_math_robots ) ) {
		$rank_math_robots = maybe_unserialize( get_post_meta( $post_id, '_rank_math_robots', true ) );
	}
	$robots_text = strtolower( is_scalar( $rank_math_robots ) ? (string) $rank_math_robots : wp_json_encode( $rank_math_robots ) );
	$yoast_noindex = (string) get_post_meta( $post_id, '_yoast_wpseo_meta-robots-noindex', true );
	if ( false !== strpos( $robots_text, 'noindex' ) || '1' === $yoast_noindex ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'Esta matéria está marcada como noindex no plugin SEO: ela não poderá aparecer na Pesquisa nem no Discover.', 'go-verge' ) );
	} elseif ( false !== strpos( $robots_text, 'noimageindex' ) ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'O plugin SEO usa noimageindex nesta matéria. Revise a diretiva antes de publicar uma história que depende de preview visual.', 'go-verge' ) );
	} elseif ( false !== strpos( $robots_text, 'nosnippet' ) ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'Rank Math está usando nosnippet: isso remove snippets e impede o conteúdo de ser usado como entrada direta nas Visões gerais criadas por IA/Modo IA.', 'go-verge' ) );
	} else {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Nenhum bloqueio editorial noindex/nosnippet/noimageindex detectado.', 'go-verge' ) );
	}

	/* Canonical customizado é legítimo em casos especiais, mas deve ser explícito. */
	$custom_canonical = trim( (string) get_post_meta( $post_id, 'rank_math_canonical_url', true ) );
	if ( '' === $custom_canonical ) {
		$custom_canonical = trim( (string) get_post_meta( $post_id, '_yoast_wpseo_canonical', true ) );
	}
	if ( '' !== $custom_canonical ) {
		$permalink = get_permalink( $post_id );
		$custom_host = strtolower( (string) wp_parse_url( $custom_canonical, PHP_URL_HOST ) );
		$site_host   = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
		$custom_path = untrailingslashit( (string) wp_parse_url( $custom_canonical, PHP_URL_PATH ) );
		$post_path   = untrailingslashit( (string) wp_parse_url( $permalink, PHP_URL_PATH ) );
		if ( $custom_host && ( $custom_host !== $site_host || $custom_path !== $post_path ) ) {
			$items[] = array(
				'level' => 'warn',
				'text'  => sprintf( __( 'Canonical customizado aponta para outro documento: %s. Confirme que isso é intencional.', 'go-verge' ), $custom_canonical ),
			);
		} else {
			$items[] = array( 'level' => 'ok', 'text' => __( 'Canonical customizado, quando presente, permanece no mesmo documento.', 'go-verge' ) );
		}
	}

	/* Search visibility: title, deck and validated topic ------------------- */
	$title_length = function_exists( 'mb_strlen' ) ? mb_strlen( trim( (string) $post->post_title ), 'UTF-8' ) : strlen( trim( (string) $post->post_title ) );
	if ( $title_length < 28 ) {
		$items[] = array( 'level' => 'info', 'text' => __( 'Título muito curto: confirme se ele explica o assunto e a consequência para quem busca.', 'go-verge' ) );
	} elseif ( $title_length > 90 ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'Título muito longo: o foco da matéria pode ficar diluído nos resultados de busca.', 'go-verge' ) );
	}

	$deck = function_exists( 'go_verge_subtitle' ) ? trim( (string) go_verge_subtitle( $post_id ) ) : trim( (string) get_post_meta( $post_id, '_go_post_subtitle', true ) );
	if ( '' === $deck ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'Linha de apoio vazia: falta um resumo factual forte para descrição, descoberta e contexto.', 'go-verge' ) );
	}

	if ( function_exists( 'go_verge_search_topic_entities' ) ) {
		$topics = go_verge_search_topic_entities( $post_id );
		if ( empty( $topics ) ) {
			$items[] = array(
				'level' => 'info',
				'text'  => __( 'Nenhum assunto específico foi validado. Vincule o jogo/entidade correta ou revise tags genéricas antes de publicar.', 'go-verge' ),
			);
		} else {
			$items[] = array(
				'level' => 'ok',
				'text'  => sprintf(
					/* translators: %s: validated topic name. */
					__( 'Assunto específico reconhecido: %s.', 'go-verge' ),
					$topics[0]['name']
				),
			);
		}
	}

	/* 2. Featured image alt ------------------------------------------------ */
	$thumbnail_id = get_post_thumbnail_id( $post_id );
	if ( ! $thumbnail_id ) {
		$items[] = array( 'level' => 'warn', 'text' => __( 'A matéria ainda não tem imagem destacada.', 'go-verge' ) );
	} elseif ( '' === trim( (string) get_post_meta( $thumbnail_id, '_wp_attachment_image_alt', true ) ) ) {
		$items[] = array(
			'level'  => 'warn',
			'text'   => __( 'Imagem destacada sem texto alternativo (alt).', 'go-verge' ),
			'action' => array(
				'label' => __( 'Editar imagem', 'go-verge' ),
				'href'  => get_edit_post_link( $thumbnail_id, 'raw' ),
			),
		);
	} else {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Imagem destacada com alt text.', 'go-verge' ) );
	}

	/* Discover/large previews: source image should be at least 1200px wide. */
	if ( $thumbnail_id ) {
		$image_meta   = wp_get_attachment_metadata( $thumbnail_id );
		$image_width  = is_array( $image_meta ) && ! empty( $image_meta['width'] ) ? absint( $image_meta['width'] ) : 0;
		$image_height = is_array( $image_meta ) && ! empty( $image_meta['height'] ) ? absint( $image_meta['height'] ) : 0;
		$image_pixels = $image_width * $image_height;
		if ( $image_width && $image_width < 1200 ) {
			$items[] = array(
				'level'  => 'warn',
				'text'   => sprintf(
					/* translators: %d: featured image width in pixels. */
					__( 'Imagem destacada com apenas %d px de largura: use uma fonte de pelo menos 1200 px para previews grandes e Discover.', 'go-verge' ),
					$image_width
				),
				'action' => array(
					'label' => __( 'Trocar imagem', 'go-verge' ),
					'href'  => get_edit_post_link( $post_id, 'raw' ),
				),
			);
		} elseif ( $image_width >= 1200 ) {
			$items[] = array( 'level' => 'ok', 'text' => __( 'Imagem destacada com largura adequada para previews grandes.', 'go-verge' ) );
		}
		if ( $image_width && $image_height && $image_pixels <= 300000 ) {
			$items[] = array(
				'level' => 'warn',
				'text'  => sprintf(
					/* translators: 1: width, 2: height. */
					__( 'Imagem destacada com %1$d × %2$d px não ultrapassa 300 mil pixels; troque por uma fonte maior para previews grandes.', 'go-verge' ),
					$image_width,
					$image_height
				),
			);
		}
		if ( $image_width && $image_height && $image_height > $image_width ) {
			$items[] = array(
				'level' => 'warn',
				'text'  => __( 'Imagem destacada vertical. Para Discover, confirme se existe um recorte horizontal forte (preferencialmente 16:9) sem texto sobreposto.', 'go-verge' ),
			);
		}
	}

	/* 3. Long article without H2 ------------------------------------------- */
	if ( $words >= 1800 && false === stripos( $content, '<h2' ) && ! preg_match( '/^##\s/m', $content ) ) {
		$items[] = array(
			'level' => 'warn',
			'text'  => sprintf(
				/* translators: %s: word count. */
				__( 'Matéria longa (%s palavras) sem nenhum H2 — divida em seções.', 'go-verge' ),
				number_format_i18n( $words )
			),
		);
	} elseif ( $words >= 1800 ) {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Matéria longa já estruturada com H2.', 'go-verge' ) );
	}

	/* 4. Game mentioned but not linked -------------------------------------- */
	if ( post_type_exists( 'games' ) && '' !== $plain ) {
		$games = get_posts(
			array(
				'post_type'      => 'games',
				'post_status'    => 'publish',
				'posts_per_page' => 300,
				'orderby'        => 'date',
				'order'          => 'DESC',
			)
		);
		$unlinked = array();
		foreach ( $games as $game ) {
			$name = trim( get_the_title( $game ) );
			if ( strlen( $name ) < 4 ) {
				continue;
			}
			if ( false === stripos( $plain, $name ) ) {
				continue;
			}
			$permalink = get_permalink( $game );
			$slug_path = wp_parse_url( $permalink, PHP_URL_PATH );
			if ( $permalink && false === stripos( $content, (string) $slug_path ) ) {
				$unlinked[] = array( 'name' => $name, 'url' => $permalink );
			}
			if ( count( $unlinked ) >= 3 ) {
				break;
			}
		}
		if ( ! empty( $unlinked ) ) {
			$names = wp_list_pluck( $unlinked, 'name' );
			$items[] = array(
				'level'  => 'info',
				'text'   => sprintf(
					/* translators: %s: game names. */
					__( 'Jogo citado possui página vinculável: %s. Considere linkar a ficha.', 'go-verge' ),
					implode( ', ', $names )
				),
				'action' => array(
					'label' => __( 'Abrir ficha', 'go-verge' ),
					'href'  => $unlinked[0]['url'],
				),
			);
		}
	}

	/* 5. Review without tested platform ------------------------------------- */
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$has_score   = '' !== (string) get_post_meta( $post_id, 'nota', true );
	$in_reviews  = has_category( 'reviews', $post_id );
	if ( ! $is_critique && ( $has_score || $in_reviews ) ) {
		$platform = trim( (string) get_post_meta( $post_id, 'review_platform', true ) );
		if ( '' === $platform ) {
			$items[] = array(
				'level'  => 'warn',
				'text'   => __( 'Review sem plataforma testada — preencha o campo na caixa "Review: avaliação editorial".', 'go-verge' ),
				'action' => array(
					'label' => __( 'Preencher agora', 'go-verge' ),
					'href'  => '#go-review-platform',
				),
			);
		} else {
			$items[] = array(
				'level' => 'ok',
				'text'  => sprintf(
					/* translators: %s: platform name. */
					__( 'Plataforma testada informada: %s.', 'go-verge' ),
					$platform
				),
			);
		}
	}

	/* 6 & 7. Similar titles + older coverage to update ----------------------- */
	$recent = go_verge_assistant_recent_posts( $post_id );
	$title  = (string) $post->post_title;
	$tokens = go_verge_assistant_title_tokens( $title );

	$too_similar   = null;
	$needs_update  = null;
	$cutoff        = strtotime( '-120 days' );
	foreach ( $recent as $row ) {
		$other_title = (string) $row->post_title;

		similar_text( strtolower( remove_accents( $title ) ), strtolower( remove_accents( $other_title ) ), $percent );
		if ( $percent >= 82 && null === $too_similar ) {
			$too_similar = $row;
		}

		if ( null === $needs_update && ! empty( $tokens ) && strtotime( $row->post_date ) < $cutoff ) {
			$other_tokens = go_verge_assistant_title_tokens( $other_title );
			if ( ! empty( $other_tokens ) ) {
				$shared = array_intersect( $tokens, $other_tokens );
				if ( count( $shared ) >= 2 && ( count( $shared ) / count( $tokens ) ) >= 0.6 ) {
					$needs_update = $row;
				}
			}
		}

		if ( $too_similar && $needs_update ) {
			break;
		}
	}

	if ( $too_similar ) {
		$items[] = array(
			'level'  => 'warn',
			'text'   => sprintf(
				/* translators: %s: other post title. */
				__( 'Título muito parecido com outro já publicado: “%s”.', 'go-verge' ),
				$too_similar->post_title
			),
			'action' => array(
				'label' => __( 'Ver matéria', 'go-verge' ),
				'href'  => get_permalink( (int) $too_similar->ID ),
			),
		);
	} else {
		$items[] = array( 'level' => 'ok', 'text' => __( 'Título sem conflito com publicações recentes.', 'go-verge' ) );
	}

	if ( $needs_update ) {
		$items[] = array(
			'level'  => 'info',
			'text'   => sprintf(
				/* translators: 1: other post title, 2: date. */
				__( 'Há uma matéria anterior sobre o mesmo tema que pode merecer atualização ou link: “%1$s” (%2$s).', 'go-verge' ),
				$needs_update->post_title,
				wp_date( get_option( 'date_format' ), strtotime( $needs_update->post_date ) )
			),
			'action' => array(
				'label' => __( 'Abrir para revisar', 'go-verge' ),
				'href'  => get_edit_post_link( (int) $needs_update->ID, 'raw' ),
			),
		);
	}

	// Warnings first, then info, then passing checks.
	$order = array( 'warn' => 0, 'info' => 1, 'ok' => 2 );
	usort(
		$items,
		static function ( $a, $b ) use ( $order ) {
			return $order[ $a['level'] ] <=> $order[ $b['level'] ];
		}
	);

	return $items;
}

/* --------------------------------------------------------------------------
 * REST endpoint (editor-only)
 * ------------------------------------------------------------------------ */

function go_verge_register_publish_assistant_route() {
	register_rest_route(
		'go-verge/v1',
		'/publish-check/(?P<id>\d+)',
		array(
			'methods'             => 'GET',
			'callback'            => static function ( WP_REST_Request $request ) {
				$post_id = absint( $request['id'] );
				return rest_ensure_response(
					array(
						'items'   => go_verge_publish_assistant_checks( $post_id ),
						'checked' => wp_date( get_option( 'time_format' ) ),
					)
				);
			},
			'permission_callback' => static function ( WP_REST_Request $request ) {
				return current_user_can( 'edit_post', absint( $request['id'] ) );
			},
			'args'                => array(
				'id' => array( 'validate_callback' => 'is_numeric' ),
			),
		)
	);
}
add_action( 'rest_api_init', 'go_verge_register_publish_assistant_route' );

/* --------------------------------------------------------------------------
 * Metabox
 * ------------------------------------------------------------------------ */

function go_verge_register_publish_assistant_meta_box() {
	if ( defined( 'GED_VERSION' ) ) { return; }
	add_meta_box(
		'go-verge-publish-assistant',
		__( 'Assistente de publicação', 'go-verge' ),
		'go_verge_render_publish_assistant_meta_box',
		'post',
		'side',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_publish_assistant_meta_box' );

function go_verge_render_publish_assistant_meta_box( $post ) {
	?>
	<div data-go-publish-assistant data-post="<?php echo esc_attr( $post->ID ); ?>">
		<div data-go-assistant-list>
			<p style="color:#646970;margin:0;"><?php esc_html_e( 'Clique em Reverificar quando quiser rodar a análise completa.', 'go-verge' ); ?></p>
		</div>
		<p style="margin:10px 0 0;display:flex;align-items:center;gap:8px;">
			<button type="button" class="button" data-go-assistant-refresh><?php esc_html_e( 'Reverificar', 'go-verge' ); ?></button>
			<span style="color:#646970;" data-go-assistant-checked></span>
		</p>
		<p style="margin:8px 0 0;color:#646970;font-size:11px;">
			<?php esc_html_e( 'A análise usa a versão salva. Salve o rascunho para atualizar os alertas.', 'go-verge' ); ?>
		</p>
	</div>
	<?php
}

/** Assistant assets on the post editor. */
function go_verge_publish_assistant_assets( $hook_suffix ) {
	if ( defined( 'GED_VERSION' ) ) { return; }
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}
	wp_enqueue_script(
		'go-verge-publish-assistant',
		GO_VERGE_URI . '/assets/js/publish-assistant.js',
		array(),
		go_verge_asset_version( '/assets/js/publish-assistant.js' ),
		true
	);
	wp_localize_script(
		'go-verge-publish-assistant',
		'GoVergeAssistant',
		array(
			'restUrl' => esc_url_raw( rest_url( 'go-verge/v1/publish-check/' ) ),
			'nonce'   => wp_create_nonce( 'wp_rest' ),
		)
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_publish_assistant_assets', 45 );
