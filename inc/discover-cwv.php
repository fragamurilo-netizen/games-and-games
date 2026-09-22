<?php
/**
 * Discover + Core Web Vitals production guardrails.
 *
 * This module does not promise Discover inclusion (Google makes no such
 * guarantee) and never changes advertising inventory. It turns the local
 * prerequisites we can actually control into Site Health checks.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Single-post layout/CWV reservations are owned by assets/css/single-clean.css.
 * Site Health checks remain here; no second article stylesheet is enqueued.
 */

/** Add local Discover/news readiness to Tools > Site Health. */
function go_verge_register_discover_cwv_health( $tests ) {
	$tests['direct']['go_verge_discover_readiness'] = array(
		'label' => __( 'Discover e notícias do Overdrive', 'go-verge' ),
		'test'  => 'go_verge_discover_readiness_health_test',
	);
	$tests['direct']['go_verge_audience_measurement'] = array(
		'label' => __( 'Captura de audiência', 'go-verge' ),
		'test'  => 'go_verge_audience_measurement_health_test',
	);
	$tests['direct']['go_verge_discover_legacy_images'] = array(
		'label' => __( 'Imagens do acervo elegíveis ao Discover', 'go-verge' ),
		'test'  => 'go_verge_discover_legacy_image_health_test',
	);
	$tests['async']['go_verge_avif_delivery'] = array(
		'label'     => __( 'Entrega de imagens AVIF', 'go-verge' ),
		'test'      => 'go_verge_avif_delivery_health_test',
		'has_rest'  => false,
		'async_direct_test' => 'go_verge_avif_delivery_health_test',
	);
	return $tests;
}

/**
 * Most recent featured image stored as AVIF, if any.
 *
 * @return string Attachment URL, or an empty string.
 */
function go_verge_recent_avif_featured_image() {
	$posts = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => 25,
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'no_found_rows'          => true,
			'update_post_term_cache' => false,
		)
	);

	foreach ( $posts as $post ) {
		$image_id = get_post_thumbnail_id( $post->ID );
		if ( ! $image_id ) {
			continue;
		}
		if ( 'image/avif' !== get_post_mime_type( $image_id ) ) {
			continue;
		}
		$url = wp_get_attachment_url( $image_id );
		if ( $url ) {
			return $url;
		}
	}

	return '';
}

/**
 * Verify that AVIF media is served as an image.
 *
 * This host has been observed answering `.avif` with `Content-Type: text/plain`
 * alongside `X-Content-Type-Options: nosniff`. Browsers still paint the file,
 * so the breakage is invisible in the newsroom — but social crawlers and
 * Google's image pipeline validate the type before accepting an og:image, so a
 * whole article ships without a preview image and without a Discover-eligible
 * asset. Only a request can tell, which is why this test is async and never
 * runs during a page view.
 *
 * @return array Site Health result.
 */
function go_verge_avif_delivery_health_test() {
	$badge  = array( 'label' => __( 'Search', 'go-verge' ), 'color' => 'blue' );
	$sample = go_verge_recent_avif_featured_image();

	if ( '' === $sample ) {
		return array(
			'label'       => __( 'Nenhuma matéria recente usa AVIF na imagem em destaque', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html__( 'Nada a verificar neste teste: nenhuma das últimas 25 publicações usa AVIF como arquivo original da imagem em destaque.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_avif_delivery',
		);
	}

	$args = array(
		'method'             => 'HEAD',
		'timeout'            => 5,
		'redirection'        => 3,
		'reject_unsafe_urls' => true,
		'user-agent'         => 'Overdrive Site Health/' . GO_VERGE_VERSION,
	);
	$response     = wp_safe_remote_request( $sample, $args );
	$status       = is_wp_error( $response ) ? 0 : (int) wp_remote_retrieve_response_code( $response );
	$content_type = is_wp_error( $response ) ? '' : strtolower( trim( (string) wp_remote_retrieve_header( $response, 'content-type' ) ) );
	$content_type = trim( strtok( $content_type, ';' ) ?: '' );

	/* Some CDNs reject HEAD or return generic metadata. Verify with a bounded
	 * byte-range GET before declaring the image broken. */
	if ( is_wp_error( $response ) || ! in_array( $status, array( 200, 206 ), true ) || 'image/avif' !== $content_type ) {
		$args['method'] = 'GET';
		$args['timeout'] = 8;
		$args['headers'] = array( 'Range' => 'bytes=0-1023' );
		$args['limit_response_size'] = 1024;
		$response     = wp_safe_remote_request( $sample, $args );
		$status       = is_wp_error( $response ) ? 0 : (int) wp_remote_retrieve_response_code( $response );
		$content_type = is_wp_error( $response ) ? '' : strtolower( trim( (string) wp_remote_retrieve_header( $response, 'content-type' ) ) );
		$content_type = trim( strtok( $content_type, ';' ) ?: '' );
	}

	if ( is_wp_error( $response ) ) {
		return array(
			'label'       => __( 'Não foi possível verificar a entrega das imagens AVIF', 'go-verge' ),
			'status'      => 'recommended',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: %s: transport error message. */
					__( 'A verificação falhou: %s. Repita mais tarde ou confira manualmente o cabeçalho Content-Type da imagem.', 'go-verge' ),
					$response->get_error_message()
				)
			) . '</p>',
			'test'        => 'go_verge_avif_delivery',
		);
	}

	$is_image = in_array( $status, array( 200, 206 ), true ) && 'image/avif' === $content_type;

	if ( $is_image ) {
		return array(
			'label'       => __( 'O servidor entrega AVIF com o tipo correto', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: 1: HTTP status, 2: Content-Type header value. */
					__( 'A imagem AVIF mais recente responde HTTP %1$d com Content-Type: %2$s.', 'go-verge' ),
					$status,
					$content_type
				)
			) . '</p>',
			'test'        => 'go_verge_avif_delivery',
		);
	}

	return array(
		'label'       => __( 'As imagens AVIF estão sendo entregues com o tipo errado', 'go-verge' ),
		'status'      => 'critical',
		'badge'       => $badge,
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: 1: HTTP status, 2: Content-Type header value, 3: sample image URL. */
				__( 'O servidor responde HTTP %1$d e Content-Type: %2$s para %3$s. Deveria responder 200/206 com image/avif. Crawlers sociais e pipelines de imagens podem recusar a prévia nessa condição.', 'go-verge' ),
				$status,
				'' !== $content_type ? $content_type : __( '(vazio)', 'go-verge' ),
				$sample
			)
		) . '</p><p>' . esc_html__( 'Correção: adicionar "AddType image/avif .avif" ao .htaccess da raiz, fora do bloco # BEGIN WordPress. O passo a passo está em docs/servidor-mime-avif.md, no tema.', 'go-verge' ) . '</p>',
		'test'        => 'go_verge_avif_delivery',
	);
}
add_filter( 'site_status_tests', 'go_verge_register_discover_cwv_health' );

/** Whether dimensions can support Google's large-image preview. */
function go_verge_discover_dimensions_ready( $width, $height ) {
	$width  = absint( $width );
	$height = absint( $height );

	/* 1200 px is the material eligibility threshold. A 16:9 crop is useful for
	 * consistent newsroom art direction, but it is not itself an eligibility
	 * requirement, so do not turn a valid 4:3/3:2 image into a false failure. */
	return $width >= 1200 && $height > 0 && ( $width * $height ) >= 300000;
}

/** Whether an image has the newsroom's preferred 16:9 share crop. */
function go_verge_discover_dimensions_16x9_ready( $width, $height ) {
	$width  = absint( $width );
	$height = absint( $height );
	return go_verge_discover_dimensions_ready( $width, $height )
		&& abs( ( $width / $height ) - ( 16 / 9 ) ) <= 0.045;
}

/**
 * Require a real >=1200 px source; exact 16:9 is a separate quality signal.
 *
 * Pixels are necessary and not sufficient. A 3000x1688 AVIF clears every
 * dimension test in this file and is still not a Discover asset on this server,
 * because the file is answered as `text/plain` and has no sub-sizes. Reporting
 * that attachment as "ready" is worse than reporting nothing: it is the signal
 * the newsroom checks before concluding the problem must be elsewhere.
 *
 * Deliverability is therefore part of readiness, using the same shared answer
 * as og:image and Article.image.
 */
function go_verge_discover_image_ready( $image_id ) {
	$image_id = absint( $image_id );
	$intermediate = image_get_intermediate_size( $image_id, 'go_discover_16x9' );
	if ( is_array( $intermediate ) && ! empty( $intermediate['file'] ) && go_verge_discover_dimensions_ready( $intermediate['width'] ?? 0, $intermediate['height'] ?? 0 ) ) {
		if ( ! function_exists( 'go_verge_image_format_deliverable' ) || go_verge_image_format_deliverable( (string) ( $intermediate['url'] ?? $intermediate['file'] ) ) ) {
			return true;
		}
	}
	$metadata = wp_get_attachment_metadata( $image_id );
	if ( ! is_array( $metadata ) || ! go_verge_discover_dimensions_ready( $metadata['width'] ?? 0, $metadata['height'] ?? 0 ) ) {
		return false;
	}
	if ( function_exists( 'go_verge_image_format_deliverable' ) ) {
		$source = (string) ( $metadata['file'] ?? '' );
		if ( '' === $source ) {
			$source = (string) wp_get_attachment_url( $image_id );
		}
		return go_verge_image_format_deliverable( $source );
	}
	return true;
}

/**
 * Published posts whose featured image this server cannot deliver to Google.
 *
 * The upload block added on 18/08/2026 protects new stories only. Everything
 * published before it keeps its original attachment, so the newsroom can be
 * doing everything right and still have a back catalogue that is structurally
 * ineligible for a large preview. Nothing in the theme reported that, which is
 * why it stayed invisible while Discover impressions fell.
 *
 * @param int $limit How many recent posts to inspect.
 * @return array{checked:int,broken:int,samples:array<int,array{id:int,title:string,url:string,ext:string}>}
 */
function go_verge_discover_undeliverable_featured_images( $limit = 120 ) {
	$out = array( 'checked' => 0, 'broken' => 0, 'samples' => array() );
	if ( ! function_exists( 'go_verge_image_format_deliverable' ) ) {
		return $out;
	}

	$posts = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => max( 1, min( 500, absint( $limit ) ) ),
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'fields'                 => 'ids',
			'no_found_rows'          => true,
			'update_post_term_cache' => false,
		)
	);

	foreach ( $posts as $post_id ) {
		$attachment_id = absint( get_post_thumbnail_id( $post_id ) );
		if ( ! $attachment_id ) {
			continue;
		}
		$out['checked']++;
		$url = (string) wp_get_attachment_url( $attachment_id );
		if ( '' === $url || go_verge_image_format_deliverable( $url ) ) {
			continue;
		}
		$out['broken']++;
		if ( count( $out['samples'] ) < 8 ) {
			$path = (string) wp_parse_url( $url, PHP_URL_PATH );
			$out['samples'][] = array(
				'id'    => (int) $post_id,
				'title' => (string) get_the_title( $post_id ),
				'url'   => (string) get_permalink( $post_id ),
				'ext'   => strtolower( (string) pathinfo( $path, PATHINFO_EXTENSION ) ),
			);
		}
	}

	return $out;
}

/** Report the back catalogue that can never earn a large Discover preview. */
function go_verge_discover_legacy_image_health_test() {
	$badge = array( 'label' => __( 'Discover', 'go-verge' ), 'color' => 'blue' );
	$state = go_verge_discover_undeliverable_featured_images( 120 );

	if ( $state['broken'] < 1 ) {
		return array(
			'label'       => __( 'As matérias recentes usam formatos de imagem que o Google consegue buscar', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: %d: posts inspected. */
					__( '%d matérias publicadas com imagem em destaque foram inspecionadas e nenhuma usa um formato que este servidor entrega com o Content-Type errado.', 'go-verge' ),
					(int) $state['checked']
				)
			) . '</p>',
			'test'        => 'go_verge_discover_legacy_images',
		);
	}

	$list = array();
	foreach ( $state['samples'] as $sample ) {
		$list[] = '<li><a href="' . esc_url( $sample['url'] ) . '">' . esc_html( $sample['title'] ) . '</a> <code>.' . esc_html( $sample['ext'] ) . '</code></li>';
	}

	return array(
		'label'       => __( 'Há matérias publicadas sem imagem elegível para o Discover', 'go-verge' ),
		'status'      => 'critical',
		'badge'       => $badge,
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: 1: broken posts, 2: posts inspected. */
				__( '%1$d de %2$d matérias inspecionadas têm imagem em destaque num formato que este servidor não entrega corretamente a um consumidor que lê o Content-Type. Essas matérias saem sem og:image e sem imagem representativa utilizável, e o Discover não distribui uma história sem imagem grande.', 'go-verge' ),
				(int) $state['broken'],
				(int) $state['checked']
			)
		) . '</p><ul>' . implode( '', $list ) . '</ul><p>' . esc_html__( 'O bloqueio de upload adicionado em 18/08/2026 impede novos casos, mas não corrige os antigos. Correção definitiva: adicionar "AddType image/avif .avif" ao .htaccess da raiz, fora do bloco # BEGIN WordPress. Enquanto isso, reenvie a imagem em JPEG ou PNG nessas matérias — o site gera os recortes em WebP sozinho.', 'go-verge' ) . '</p>',
		'actions'     => '',
		'test'        => 'go_verge_discover_legacy_images',
	);
}

/** Whether the preferred generated 16:9 share crop physically exists. */
function go_verge_discover_image_has_16x9_crop( $image_id ) {
	$intermediate = image_get_intermediate_size( absint( $image_id ), 'go_discover_16x9' );
	return is_array( $intermediate )
		&& ! empty( $intermediate['file'] )
		&& go_verge_discover_dimensions_16x9_ready( $intermediate['width'] ?? 0, $intermediate['height'] ?? 0 );
}

/** Inspect recent editorial output for large-image and taxonomy readiness. */
function go_verge_discover_readiness_health_test() {
	$posts = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => 20,
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'no_found_rows'          => true,
			'update_post_meta_cache' => true,
			'update_post_term_cache' => true,
		)
	);

	$missing_large  = 0;
	$missing_crop   = 0;
	$missing_author = 0;
	$weak_headline  = 0;
	$news_count     = 0;
	foreach ( $posts as $post ) {
		if ( function_exists( 'go_verge_post_is_news_article' ) && go_verge_post_is_news_article( $post ) ) {
			++$news_count;
		}
		$image_id = get_post_thumbnail_id( $post->ID );
		if ( ! $image_id || ! go_verge_discover_image_ready( $image_id ) ) {
			++$missing_large;
		}
		if ( ! $image_id || ! go_verge_discover_image_has_16x9_crop( $image_id ) ) {
			++$missing_crop;
		}

		$author_id   = absint( $post->post_author );
		$author_url  = $author_id ? get_author_posts_url( $author_id ) : '';
		$author_name = $author_id ? trim( (string) get_the_author_meta( 'display_name', $author_id ) ) : '';
		if ( ! $author_id || '' === $author_name || '' === $author_url ) {
			++$missing_author;
		}

		$title       = trim( wp_strip_all_tags( get_the_title( $post->ID ) ) );
		$title_words = preg_split( '/\s+/u', $title, -1, PREG_SPLIT_NO_EMPTY );
		$title_len   = function_exists( 'mb_strlen' ) ? mb_strlen( $title, 'UTF-8' ) : strlen( $title );
		if ( '' === $title || count( (array) $title_words ) < 4 || $title_len > 120 ) {
			++$weak_headline;
		}
	}

	$good = ! empty( $posts ) && 0 === $missing_large;
	return array(
		'label'       => $good
			? __( 'As publicações recentes têm imagens grandes aptas a preview', 'go-verge' )
			: __( 'Há publicações recentes sem imagem grande pronta para Discover', 'go-verge' ),
		'status'      => $good ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Discover', 'go-verge' ), 'color' => 'blue' ),
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: 1: posts inspected, 2: news posts, 3: posts without >=1200px image, 4: posts without preferred 16:9 crop, 5: author identity gaps, 6: headline hygiene warnings. */
				__( 'Últimos %1$d posts: %2$d classificados como notícia; %3$d sem imagem elegível de pelo menos 1200 px; %4$d sem o crop editorial 16:9 recomendado; %5$d com lacuna de identidade de autor; %6$d com título muito curto ou excessivamente longo. O tema mantém max-image-preview:large, previews amplos e imagem preferida sincronizada entre og:image e schema.', 'go-verge' ),
				count( $posts ),
				$news_count,
				$missing_large,
				$missing_crop,
				$missing_author,
				$weak_headline
			)
		) . '</p>',
		'test'        => 'go_verge_discover_readiness',
	);
}

/**
 * Explain the analytics ownership instead of silently injecting a duplicate tag.
 */
function go_verge_audience_measurement_health_test() {
	$providers = array();
	if ( defined( 'RANK_MATH_VERSION' ) || class_exists( 'RankMath' ) ) {
		$providers[] = 'Rank Math';
	}
	if ( defined( 'GOOGLESITEKIT_VERSION' ) || class_exists( 'Google\Site_Kit\Plugin' ) ) {
		$providers[] = 'Site Kit';
	}
	$detected = ! empty( $providers );

	return array(
		'label'       => $detected
			? __( 'A integração de medição foi detectada sem duplicação pelo tema', 'go-verge' )
			: __( 'Nenhuma integração de medição foi detectada pelo tema', 'go-verge' ),
		'status'      => $detected ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Analytics', 'go-verge' ), 'color' => 'blue' ),
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: %s: detected analytics-capable integrations. */
				__( 'Integrações detectáveis: %s. O Overdrive preserva gtag/GTM das regras de atraso por interação do LiteSpeed, mas não cria outro Measurement ID. Se usuários ainda caírem, revise Consent Mode, filtros de dados/hostname e a origem que injeta o tag.', 'go-verge' ),
				$detected ? implode( ', ', $providers ) : __( 'nenhuma identificada pelo tema', 'go-verge' )
			)
		) . '</p>',
		'test'        => 'go_verge_audience_measurement',
	);
}
