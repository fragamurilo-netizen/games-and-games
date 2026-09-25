<?php
/**
 * Overdrive Editorial V6 — newsroom-first Gutenberg integration.
 *
 * Adds the missing glue around the existing Smart Crop, Game Intelligence,
 * review fields, publish assistant and live-update systems without replacing
 * those mature modules.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register assignment and review metadata used by the newsroom bar / Lume.
 *
 * The Lume editor saves article fields through Gutenberg's REST meta payload.
 * Legacy review fields used to rely only on save_post + $_POST, which works in
 * the classic metabox flow but not reliably when the Desk owns the editor UI.
 * Exposing the canonical review keys here makes the WordPress save operation
 * persist them natively, while the old save_post handler remains as fallback.
 */
function go_verge_editorial_v6_register_meta() {
	$can_edit = static function () {
		return current_user_can( 'edit_posts' );
	};

	register_post_meta(
		'post',
		'_go_editor_id',
		array(
			'type'              => 'integer',
			'single'            => true,
			'default'           => 0,
			'show_in_rest'      => true,
			'sanitize_callback' => 'absint',
			'auth_callback'     => $can_edit,
		)
	);

	$review_fields = array(
		/* Canonical fields read by the current review templates. */
		'go_review_game_name' => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'sanitize_text_field' ),
		'nota'                => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'go_verge_editorial_v6_sanitize_review_score' ),
		'review_platform'     => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'sanitize_text_field' ),
		'go_review_summary'   => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'sanitize_textarea_field' ),
		'go_review_verdict'   => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'sanitize_textarea_field' ),
		'go_review_pros'      => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'sanitize_textarea_field' ),
		'go_review_cons'      => array( 'type' => 'string',  'default' => '', 'sanitize_callback' => 'sanitize_textarea_field' ),
		'go_review_copy_provider' => array( 'type' => 'string', 'default' => '', 'sanitize_callback' => 'sanitize_text_field' ),
		'go_review_copy_provided' => array( 'type' => 'boolean', 'default' => false, 'sanitize_callback' => 'rest_sanitize_boolean' ),
		'go_review_verdict_image_id' => array( 'type' => 'integer', 'default' => 0, 'sanitize_callback' => 'absint' ),
		'go_review_game_id'   => array( 'type' => 'integer', 'default' => 0, 'sanitize_callback' => 'absint' ),

		/* Compatibility aliases used by older Desk/review builds. */
		'go_review_score'     => array( 'type' => 'string', 'default' => '', 'sanitize_callback' => 'go_verge_editorial_v6_sanitize_review_score' ),
		'go_review_platform'  => array( 'type' => 'string', 'default' => '', 'sanitize_callback' => 'sanitize_text_field' ),
		'review_game_name'    => array( 'type' => 'string', 'default' => '', 'sanitize_callback' => 'sanitize_text_field' ),
		'review_summary'      => array( 'type' => 'string', 'default' => '', 'sanitize_callback' => 'sanitize_textarea_field' ),
		'review_verdict'      => array( 'type' => 'string', 'default' => '', 'sanitize_callback' => 'sanitize_textarea_field' ),
	);

	foreach ( $review_fields as $meta_key => $args ) {
		register_post_meta(
			'post',
			$meta_key,
			array(
				'type'              => $args['type'],
				'single'            => true,
				'default'           => $args['default'],
				'show_in_rest'      => true,
				'revisions_enabled' => true,
				'sanitize_callback' => $args['sanitize_callback'],
				'auth_callback'     => $can_edit,
			)
		);
	}
}
add_action( 'init', 'go_verge_editorial_v6_register_meta', 45 );

/** Keep the review score in the 0-10 range while preserving an empty value. */
function go_verge_editorial_v6_sanitize_review_score( $value ) {
	$value = str_replace( ',', '.', trim( (string) $value ) );
	if ( '' === $value || ! is_numeric( $value ) ) {
		return '';
	}
	$score = min( 10, max( 0, (float) $value ) );
	return rtrim( rtrim( number_format( $score, 1, '.', '' ), '0' ), '.' );
}

/**
 * Keep compatibility aliases written by older Lume builds mirrored to the
 * canonical keys that the current front-end reads.
 */
function go_verge_editorial_v6_sync_review_alias( $meta_id, $object_id, $meta_key, $meta_value ) {
	if ( 'post' !== get_post_type( $object_id ) ) {
		return;
	}

	$aliases = array(
		'go_review_score'    => 'nota',
		'go_review_platform' => 'review_platform',
		'review_game_name'   => 'go_review_game_name',
		'review_summary'     => 'go_review_summary',
		'review_verdict'     => 'go_review_verdict',
	);
	if ( ! isset( $aliases[ $meta_key ] ) ) {
		return;
	}

	static $syncing = false;
	if ( $syncing ) {
		return;
	}
	$syncing = true;
	update_post_meta( $object_id, $aliases[ $meta_key ], $meta_value );
	$syncing = false;
}
add_action( 'added_post_meta', 'go_verge_editorial_v6_sync_review_alias', 10, 4 );
add_action( 'updated_post_meta', 'go_verge_editorial_v6_sync_review_alias', 10, 4 );

/** Clear the canonical value too when an old alias is emptied/deleted. */
function go_verge_editorial_v6_delete_review_alias( $meta_ids, $object_id, $meta_key, $meta_value ) {
	if ( 'post' !== get_post_type( $object_id ) ) {
		return;
	}
	$aliases = array(
		'go_review_score'    => 'nota',
		'go_review_platform' => 'review_platform',
		'review_game_name'   => 'go_review_game_name',
		'review_summary'     => 'go_review_summary',
		'review_verdict'     => 'go_review_verdict',
	);
	if ( isset( $aliases[ $meta_key ] ) ) {
		delete_post_meta( $object_id, $aliases[ $meta_key ] );
	}
}
add_action( 'deleted_post_meta', 'go_verge_editorial_v6_delete_review_alias', 10, 4 );

/** Current editor choices for assignment. */
function go_verge_editorial_v6_editor_choices() {
	$users = get_users(
		array(
			'capability' => 'edit_others_posts',
			'orderby'    => 'display_name',
			'order'      => 'ASC',
			'fields'     => array( 'ID', 'display_name' ),
		)
	);
	$out = array();
	foreach ( $users as $user ) {
		$out[] = array( 'id' => (int) $user->ID, 'name' => (string) $user->display_name );
	}
	return $out;
}

/** Admin assets: one final layer loaded after the existing workspace modules. */
function go_verge_editorial_v6_assets( $hook_suffix ) {
	if ( defined( 'GED_VERSION' ) ) {
		return;
	}
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}

	wp_enqueue_media();

	wp_enqueue_style(
		'go-verge-editorial-v6',
		GO_VERGE_URI . '/assets/css/editorial-integration-v6.css',
		array( 'go-verge-editor-workspace' ),
		go_verge_asset_version( '/assets/css/editorial-integration-v6.css' )
	);
	wp_enqueue_script(
		'go-verge-editorial-v6',
		GO_VERGE_URI . '/assets/js/editorial-integration-v6.js',
		array( 'go-verge-editor-workspace', 'go-verge-editor-workflow', 'wp-data', 'wp-blocks', 'wp-rich-text', 'wp-api-fetch', 'wp-element', 'wp-block-editor', 'wp-components', 'wp-notices' ),
		go_verge_asset_version( '/assets/js/editorial-integration-v6.js' ),
		true
	);

	$post_id = isset( $_GET['post'] ) ? absint( wp_unslash( $_GET['post'] ) ) : 0;
	if ( ! $post_id && isset( $GLOBALS['post'] ) && $GLOBALS['post'] instanceof WP_Post ) {
		$post_id = (int) $GLOBALS['post']->ID;
	}
	$post       = $post_id ? get_post( $post_id ) : null;
	$author     = $post ? get_userdata( (int) $post->post_author ) : wp_get_current_user();
	$editor_id  = $post_id ? absint( get_post_meta( $post_id, '_go_editor_id', true ) ) : 0;
	$linked_id  = $post_id ? absint( get_post_meta( $post_id, 'go_linked_game_id', true ) ) : 0;
	$linked_id  = $linked_id ?: ( $post_id ? absint( get_post_meta( $post_id, 'go_review_game_id', true ) ) : 0 );

	wp_localize_script(
		'go-verge-editorial-v6',
		'GoVergeEditorialV6',
		array(
			'postId'      => $post_id,
			'ajaxUrl'     => admin_url( 'admin-ajax.php' ),
			'nonce'       => wp_create_nonce( 'go_verge_editorial_v6' ),
			'gameNonce'   => wp_create_nonce( 'go_verge_game_intelligence_ajax' ),
			'author'      => $author ? (string) $author->display_name : '',
			'editorId'    => $editor_id,
			'editors'     => go_verge_editorial_v6_editor_choices(),
			'linkedGame'  => $linked_id ? array( 'id' => $linked_id, 'title' => get_the_title( $linked_id ) ) : null,
			'homeHost'    => wp_parse_url( home_url(), PHP_URL_HOST ),
			'homeUrl'     => home_url( '/' ),
			'authorDesk'  => admin_url( 'edit.php?page=go-author-desk' ),
			'reviewContentTypeIds' => function_exists( 'go_verge_editor_taxonomy_term_ids' ) ? array_values( array_map( 'absint', go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'review' ) ) ) ) : array(),
			'i18n'        => array(
				'noGame'          => __( 'Sem game', 'go-verge' ),
				'createGame'      => __( 'Criar ficha mínima', 'go-verge' ),
				'createdGame'     => __( 'Ficha criada e vinculada.', 'go-verge' ),
				'tagSuggest'      => __( 'Sugerir tags do texto', 'go-verge' ),
				'updated'         => __( 'Horário atualizado sem alterar a URL.', 'go-verge' ),
				'publishWarning1' => __( 'Aviso 1 de 2: há pendências editoriais. Você ainda pode publicar.', 'go-verge' ),
					'publishWarning2' => __( 'Aviso 2 de 2: ainda há pendências. A publicação não será bloqueada.', 'go-verge' ),
			),
		)
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_editorial_v6_assets', 90 );

/** Front-end final layer for the new single/home geometry and editor-created formats. */
function go_verge_editorial_v6_front_assets() {
	/* Its dependency (471 article-final) exists only outside standard articles;
	 * on articles WordPress dropped this sheet while logging a notice. */
	if ( is_admin() || is_singular( 'post' ) ) {
		return;
	}
	wp_enqueue_style(
		'go-verge-editorial-v6-front',
		GO_VERGE_URI . '/assets/css/editorial-integration-v6-front.css',
		array( 'go-verge-overdrive-471-article-final' ),
		go_verge_asset_version( '/assets/css/editorial-integration-v6-front.css' )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_editorial_v6_front_assets', 20250 );

/** Basic content-token normalizer for tag suggestions. */
function go_verge_editorial_v6_normalize( $value ) {
	$value = strtolower( remove_accents( wp_strip_all_tags( (string) $value ) ) );
	$value = preg_replace( '/[^a-z0-9+.#\-\s]/', ' ', $value );
	return ' ' . preg_replace( '/\s+/', ' ', trim( (string) $value ) ) . ' ';
}

/** Suggest existing tags from title/body plus linked game metadata. */
function go_verge_editorial_v6_tag_suggestions() {
	check_ajax_referer( 'go_verge_editorial_v6', 'nonce' );
	$post_id = isset( $_POST['post_id'] ) ? absint( wp_unslash( $_POST['post_id'] ) ) : 0;
	if ( ! $post_id || ! current_user_can( 'edit_post', $post_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão.', 'go-verge' ) ), 403 );
	}
	$title   = isset( $_POST['title'] ) ? sanitize_text_field( wp_unslash( $_POST['title'] ) ) : '';
	$content = isset( $_POST['content'] ) ? wp_kses_post( wp_unslash( $_POST['content'] ) ) : '';
	$haystack = go_verge_editorial_v6_normalize( $title . ' ' . $content );
	$scored   = array();

	$terms = get_terms(
		array(
			'taxonomy'   => 'post_tag',
			'hide_empty' => false,
			'number'     => 600,
			'orderby'    => 'count',
			'order'      => 'DESC',
		)
	);
	if ( ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			$name = trim( (string) $term->name );
			if ( mb_strlen( $name ) < 3 ) {
				continue;
			}
			$needle = trim( go_verge_editorial_v6_normalize( $name ) );
			if ( '' === $needle || false === strpos( $haystack, ' ' . $needle . ' ' ) ) {
				continue;
			}
			$score = 20 + min( 12, substr_count( $haystack, $needle ) * 3 ) + min( 8, (int) log( max( 1, (int) $term->count ) + 1, 2 ) );
			if ( false !== stripos( remove_accents( $title ), remove_accents( $name ) ) ) {
				$score += 16;
			}
			$scored[ $term->term_id ] = array( 'id' => (int) $term->term_id, 'name' => $name, 'score' => $score );
		}
	}

	$game_id = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	$game_id = $game_id ?: absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	if ( $game_id ) {
		$entities = array( get_the_title( $game_id ) );
		foreach ( array( '_go_developer', '_go_publisher', '_go_platforms' ) as $key ) {
			$value = get_post_meta( $game_id, $key, true );
			$entities = array_merge( $entities, preg_split( '/[,;|\/]+/', is_array( $value ) ? implode( ',', $value ) : (string) $value ) );
		}
		foreach ( array_filter( array_map( 'trim', $entities ) ) as $entity ) {
			$term = get_term_by( 'name', $entity, 'post_tag' );
			if ( ! $term ) {
				$term = get_term_by( 'slug', sanitize_title( $entity ), 'post_tag' );
			}
			if ( $term instanceof WP_Term ) {
				$scored[ $term->term_id ] = array( 'id' => (int) $term->term_id, 'name' => (string) $term->name, 'score' => 60 );
			}
		}
	}

	usort( $scored, static function ( $a, $b ) { return $b['score'] <=> $a['score']; } );
	wp_send_json_success( array( 'items' => array_slice( $scored, 0, 8 ) ) );
}
add_action( 'wp_ajax_go_verge_editorial_v6_tags', 'go_verge_editorial_v6_tag_suggestions' );

/** Create a minimal game from the article editor, then bind it immediately. */
function go_verge_editorial_v6_create_game() {
	check_ajax_referer( 'go_verge_game_intelligence_ajax', 'nonce' );
	$post_id = isset( $_POST['post_id'] ) ? absint( wp_unslash( $_POST['post_id'] ) ) : 0;
	if ( ! $post_id || ! current_user_can( 'edit_post', $post_id ) || ! current_user_can( 'edit_posts' ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão para criar a ficha.', 'go-verge' ) ), 403 );
	}
	$name = isset( $_POST['name'] ) ? sanitize_text_field( wp_unslash( $_POST['name'] ) ) : '';
	$date = isset( $_POST['release'] ) ? sanitize_text_field( wp_unslash( $_POST['release'] ) ) : '';
	$cover_id = isset( $_POST['cover_id'] ) ? absint( wp_unslash( $_POST['cover_id'] ) ) : 0;
	if ( mb_strlen( $name ) < 2 ) {
		wp_send_json_error( array( 'message' => __( 'Informe o nome do game.', 'go-verge' ) ), 400 );
	}
	$existing = get_page_by_title( $name, OBJECT, 'games' );
	if ( $existing instanceof WP_Post ) {
		$game_id = (int) $existing->ID;
	} else {
		$game_id = wp_insert_post(
			array(
				'post_type'   => 'games',
				'post_status' => current_user_can( 'publish_posts' ) ? 'publish' : 'draft',
				'post_title'  => $name,
				'post_author' => get_current_user_id(),
			),
			true
		);
		if ( is_wp_error( $game_id ) ) {
			wp_send_json_error( array( 'message' => $game_id->get_error_message() ), 500 );
		}
	}
	if ( preg_match( '/^\d{4}-\d{2}-\d{2}$/', $date ) ) {
		update_post_meta( $game_id, '_go_release_date', $date );
	}
	if ( $cover_id && wp_attachment_is_image( $cover_id ) ) {
		set_post_thumbnail( $game_id, $cover_id );
	}
	update_post_meta( $post_id, 'go_linked_game_id', $game_id );
	update_post_meta( $post_id, 'go_review_game_id', $game_id );
	$payload = function_exists( 'go_verge_game_intelligence_game_payload' ) ? go_verge_game_intelligence_game_payload( $game_id ) : array( 'id' => (int) $game_id, 'title' => get_the_title( $game_id ), 'image' => get_the_post_thumbnail_url( $game_id, 'thumbnail' ) ?: '' );
	wp_send_json_success( array( 'game' => $payload ) );
}
add_action( 'wp_ajax_go_verge_editorial_v6_create_game', 'go_verge_editorial_v6_create_game' );

/** Touch modified time / optionally attach a correction note, keeping permalink intact. */
function go_verge_editorial_v6_update_article() {
	check_ajax_referer( 'go_verge_editorial_v6', 'nonce' );
	$post_id = isset( $_POST['post_id'] ) ? absint( wp_unslash( $_POST['post_id'] ) ) : 0;
	if ( ! $post_id || ! current_user_can( 'edit_post', $post_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão.', 'go-verge' ) ), 403 );
	}
	$note = isset( $_POST['note'] ) ? sanitize_textarea_field( wp_unslash( $_POST['note'] ) ) : '';
	$now  = current_time( 'mysql' );
	$gmt  = get_gmt_from_date( $now );
	global $wpdb;
	$wpdb->update( $wpdb->posts, array( 'post_modified' => $now, 'post_modified_gmt' => $gmt ), array( 'ID' => $post_id ), array( '%s', '%s' ), array( '%d' ) );
	clean_post_cache( $post_id );
	update_post_meta( $post_id, '_go_search_content_modified_gmt', $gmt );
	if ( '' !== $note ) {
		update_post_meta( $post_id, '_go_correction_note', $note );
		update_post_meta( $post_id, '_go_correction_date', current_time( 'Y-m-d' ) );
	}
	if ( 'publish' === get_post_status( $post_id ) && function_exists( 'go_verge_indexing_schedule_websub_publish' ) ) {
		go_verge_indexing_schedule_websub_publish();
	}
	wp_send_json_success( array( 'time' => wp_date( get_option( 'date_format' ) . ' ' . get_option( 'time_format' ) ) ) );
}
add_action( 'wp_ajax_go_verge_editorial_v6_update_article', 'go_verge_editorial_v6_update_article' );

/** Detect a linked game name cited without a canonical relationship. */
function go_verge_editorial_v6_cited_game_without_relation( $content, $post_id ) {
	$linked = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	$linked = $linked ?: absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	if ( $linked || ! post_type_exists( 'games' ) ) {
		return '';
	}
	$plain = wp_strip_all_tags( (string) $content );
	if ( mb_strlen( $plain ) < 4 ) {
		return '';
	}
	$games = get_posts( array( 'post_type' => 'games', 'post_status' => 'publish', 'posts_per_page' => 180, 'orderby' => 'date', 'order' => 'DESC', 'fields' => 'ids' ) );
	foreach ( $games as $game_id ) {
		$name = trim( get_the_title( $game_id ) );
		if ( mb_strlen( $name ) >= 4 && false !== mb_stripos( $plain, $name ) ) {
			return $name;
		}
	}
	return '';
}

/** Advisory publish checks. Returns human-readable warnings. */
function go_verge_editorial_v6_hard_errors( $post_id, $content = null, $title = null, $meta = array(), $featured_id = null, $categories = null ) {
	$post = get_post( $post_id );
	if ( ! $post ) {
		return array();
	}
	$content = null === $content ? (string) $post->post_content : (string) $content;
	$title   = null === $title ? (string) $post->post_title : (string) $title;
	$meta    = is_array( $meta ) ? $meta : array();
	$errors  = array();
	$deck    = isset( $meta['_go_post_subtitle'] ) ? trim( (string) $meta['_go_post_subtitle'] ) : trim( (string) get_post_meta( $post_id, '_go_post_subtitle', true ) );
	if ( '' === $deck ) {
		$errors[] = __( 'Linha de apoio obrigatória.', 'go-verge' );
	}
	$featured_id = null === $featured_id ? get_post_thumbnail_id( $post_id ) : absint( $featured_id );
	if ( ! $featured_id ) {
		$errors[] = __( 'Imagem destacada obrigatória.', 'go-verge' );
	} elseif ( '' === trim( (string) get_post_meta( $featured_id, '_wp_attachment_image_alt', true ) ) ) {
		$errors[] = __( 'A capa precisa de texto alternativo (alt).', 'go-verge' );
	}
	if ( false === stripos( $content, '<h2' ) && ! preg_match( '/<!--\s*wp:heading\s+[^>]*"level"\s*:\s*2/i', $content ) ) {
		$errors[] = __( 'A matéria precisa de pelo menos um H2.', 'go-verge' );
	}
	$host = wp_parse_url( home_url(), PHP_URL_HOST );
	$has_internal = false;
	if ( preg_match_all( '/<a\s[^>]*href=["\']([^"\']+)["\']/i', $content, $links ) ) {
		foreach ( $links[1] as $href ) {
			$link_host = wp_parse_url( $href, PHP_URL_HOST );
			if ( ( 0 === strpos( $href, '/' ) && 0 !== strpos( $href, '//' ) ) || ( $link_host && 0 === strcasecmp( (string) $host, (string) $link_host ) ) ) {
				$has_internal = true;
				break;
			}
		}
	}
	if ( ! $has_internal ) {
		$errors[] = __( 'Inclua pelo menos um link interno.', 'go-verge' );
	}
	$cited_game = go_verge_editorial_v6_cited_game_without_relation( $content, $post_id );
	if ( $cited_game ) {
		$errors[] = sprintf( __( 'O game “%s” é citado, mas a matéria não está vinculada à ficha.', 'go-verge' ), $cited_game );
	}

	$categories = is_array( $categories ) ? array_map( 'absint', $categories ) : wp_get_post_categories( $post_id );
	$review_ids = function_exists( 'go_verge_editor_category_ids' ) ? go_verge_editor_category_ids( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ) ) : array();
	$is_review  = (bool) array_intersect( $categories, $review_ids );
	$score      = isset( $meta['nota'] ) ? $meta['nota'] : get_post_meta( $post_id, 'nota', true );
	if ( $is_review && '' === trim( (string) $score ) ) {
		$errors[] = __( 'Review sem nota.', 'go-verge' );
	}
	return array_values( array_unique( $errors ) );
}

/**
 * Editorial quality checks are advisory, never a transport-level publish veto.
 *
 * V31 fixes a newsroom regression where the theme returned WP_Error(400) from
 * rest_pre_insert_post when a story lacked an H2, internal link, cover alt,
 * support line, linked game, etc. Gutenberg then surfaced only "Falha ao
 * publicar", even though the structural panel said the story was ready.
 *
 * Those items remain visible in the editor as warnings, but the native
 * WordPress save/publish request is no longer intercepted here. Structural
 * invariants (one editorial category + one content type, and review score)
 * remain owned by editorial-architecture-v7.php, where the editor can explain
 * them explicitly.
 */
function go_verge_editorial_v6_rest_publish_gate( $prepared_post, $request ) {
	return $prepared_post;
}
// Intentionally NOT attached to rest_pre_insert_post. See note above.

/** "Mesa do autor" consolidated newsroom list. */
function go_verge_editorial_v6_author_desk_menu() {
	add_posts_page( __( 'Mesa do autor', 'go-verge' ), __( 'Mesa do autor', 'go-verge' ), 'edit_posts', 'go-author-desk', 'go_verge_editorial_v6_author_desk_page' );
}
add_action( 'admin_menu', 'go_verge_editorial_v6_author_desk_menu', 40 );

function go_verge_editorial_v6_author_desk_page() {
	if ( ! current_user_can( 'edit_posts' ) ) {
		wp_die( esc_html__( 'Sem permissão.', 'go-verge' ) );
	}
	$filter = isset( $_GET['go_view'] ) ? sanitize_key( wp_unslash( $_GET['go_view'] ) ) : 'drafts';
	$author = current_user_can( 'edit_others_posts' ) && isset( $_GET['author_id'] ) ? absint( wp_unslash( $_GET['author_id'] ) ) : get_current_user_id();
	$args   = array( 'post_type' => 'post', 'posts_per_page' => 50, 'orderby' => 'modified', 'order' => 'DESC', 'author' => $author );
	switch ( $filter ) {
		case 'scheduled': $args['post_status'] = 'future'; break;
		case 'no-cover':  $args['post_status'] = array( 'draft', 'pending', 'future', 'publish' ); $args['meta_query'] = array( array( 'key' => '_thumbnail_id', 'compare' => 'NOT EXISTS' ) ); break;
		case 'no-game':   $args['post_status'] = array( 'draft', 'pending', 'future', 'publish' ); $args['meta_query'] = array( 'relation' => 'AND', array( 'key' => 'go_linked_game_id', 'compare' => 'NOT EXISTS' ), array( 'key' => 'go_review_game_id', 'compare' => 'NOT EXISTS' ) ); break;
		case 'seo':       $args['post_status'] = array( 'draft', 'pending' ); break;
		default:          $args['post_status'] = array( 'draft', 'pending' ); break;
	}
	$query = new WP_Query( $args );
	$base  = admin_url( 'edit.php?page=go-author-desk&author_id=' . $author );
	?>
	<div class="wrap go-author-desk"><h1><?php esc_html_e( 'Mesa do autor', 'go-verge' ); ?></h1>
		<nav class="nav-tab-wrapper">
			<?php foreach ( array( 'drafts' => 'Meus rascunhos', 'scheduled' => 'Agendados', 'no-cover' => 'Sem capa', 'seo' => 'SEO fino', 'no-game' => 'Sem game' ) as $key => $label ) : ?>
				<a class="nav-tab<?php echo $filter === $key ? ' nav-tab-active' : ''; ?>" href="<?php echo esc_url( add_query_arg( 'go_view', $key, $base ) ); ?>"><?php echo esc_html( $label ); ?></a>
			<?php endforeach; ?>
		</nav>
		<?php if ( current_user_can( 'edit_others_posts' ) ) : ?>
			<form method="get" style="margin:16px 0"><input type="hidden" name="page" value="go-author-desk"><input type="hidden" name="go_view" value="<?php echo esc_attr( $filter ); ?>"><label><strong><?php esc_html_e( 'Pessoa', 'go-verge' ); ?></strong> <?php wp_dropdown_users( array( 'name' => 'author_id', 'selected' => $author, 'who' => 'authors', 'show_option_all' => false ) ); ?></label> <button class="button"><?php esc_html_e( 'Filtrar', 'go-verge' ); ?></button></form>
		<?php endif; ?>
		<table class="widefat striped"><thead><tr><th><?php esc_html_e( 'Matéria', 'go-verge' ); ?></th><th><?php esc_html_e( 'Status', 'go-verge' ); ?></th><th><?php esc_html_e( 'Pendências', 'go-verge' ); ?></th><th><?php esc_html_e( 'Modificada', 'go-verge' ); ?></th></tr></thead><tbody>
		<?php if ( $query->have_posts() ) : while ( $query->have_posts() ) : $query->the_post(); $id = get_the_ID(); $pending = array(); if ( ! has_post_thumbnail( $id ) ) { $pending[] = 'sem capa'; } if ( '' === trim( (string) get_post_meta( $id, '_go_post_subtitle', true ) ) ) { $pending[] = 'sem apoio'; } if ( ! get_post_meta( $id, 'go_linked_game_id', true ) && ! get_post_meta( $id, 'go_review_game_id', true ) ) { $pending[] = 'sem game'; } ?>
			<tr><td><strong><a href="<?php echo esc_url( get_edit_post_link( $id, 'raw' ) ); ?>"><?php the_title(); ?></a></strong></td><td><?php echo esc_html( get_post_status_object( get_post_status( $id ) )->label ?? get_post_status( $id ) ); ?></td><td><?php echo esc_html( $pending ? implode( ' · ', $pending ) : 'ok' ); ?></td><td><?php echo esc_html( get_the_modified_date( 'd/m/Y H:i', $id ) ); ?></td></tr>
		<?php endwhile; wp_reset_postdata(); else : ?><tr><td colspan="4"><?php esc_html_e( 'Nenhuma matéria neste filtro.', 'go-verge' ); ?></td></tr><?php endif; ?>
		</tbody></table>
	</div>
	<?php
}

/** Convert generated JPEG derivatives to WebP when the server image editor supports it. */
function go_verge_editorial_v6_webp_derivatives( $formats ) {
	if ( wp_image_editor_supports( array( 'mime_type' => 'image/webp' ) ) ) {
		$formats['image/jpeg'] = 'image/webp';
	}
	return $formats;
}
add_filter( 'image_editor_output_format', 'go_verge_editorial_v6_webp_derivatives', 20 );

/**
 * V12 simple newsroom UI: a final admin-only layer loaded after the architecture
 * module so secondary metadata can use progressive disclosure without changing
 * persistence, taxonomies or the publication gate.
 */
function go_verge_editorial_v12_simple_assets( $hook_suffix ) {
	if ( defined( 'GED_VERSION' ) ) {
		return;
	}
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}
	wp_enqueue_style(
		'go-verge-editorial-v12-simple',
		GO_VERGE_URI . '/assets/css/editorial-simplify-v12.css',
		array( 'go-verge-editorial-v7' ),
		go_verge_asset_version( '/assets/css/editorial-simplify-v12.css' )
	);
	wp_enqueue_script(
		'go-verge-editorial-v12-simple',
		GO_VERGE_URI . '/assets/js/editorial-simplify-v12.js',
		array( 'go-verge-editorial-v7', 'go-verge-editorial-v6', 'go-verge-editor-workspace', 'wp-data' ),
		go_verge_asset_version( '/assets/js/editorial-simplify-v12.js' ),
		true
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_editorial_v12_simple_assets', 130 );
