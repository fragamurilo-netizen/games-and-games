<?php
/**
 * Editorial media workspace, primary category and optional article background.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Register editorial appearance metadata for the block editor. */
function go_verge_register_editorial_appearance_meta() {
	$auth = static function () {
		return current_user_can( 'edit_posts' );
	};

	register_post_meta( 'post', '_go_primary_category_id', array(
		'type'              => 'integer',
		'single'            => true,
		'show_in_rest'      => true,
		'default'           => 0,
		'sanitize_callback' => 'absint',
		'auth_callback'     => $auth,
	) );
	register_post_meta( 'post', '_go_editorial_background_id', array(
		'type'              => 'integer',
		'single'            => true,
		'show_in_rest'      => true,
		'default'           => 0,
		'sanitize_callback' => 'absint',
		'auth_callback'     => $auth,
	) );
	register_post_meta( 'post', '_go_editorial_background_strength', array(
		'type'              => 'string',
		'single'            => true,
		'show_in_rest'      => true,
		'default'           => 'subtle',
		'sanitize_callback' => static function ( $value ) {
			return in_array( $value, array( 'subtle', 'medium', 'strong' ), true ) ? $value : 'subtle';
		},
		'auth_callback'     => $auth,
	) );
	register_post_meta( 'post', '_go_editorial_background_position', array(
		'type'              => 'string',
		'single'            => true,
		'show_in_rest'      => true,
		'default'           => 'center-top',
		'sanitize_callback' => static function ( $value ) {
			return in_array( $value, array( 'center-top', 'center', 'left-top', 'right-top' ), true ) ? $value : 'center-top';
		},
		'auth_callback'     => $auth,
	) );
}
add_action( 'init', 'go_verge_register_editorial_appearance_meta', 8 );

/** Keep the chosen primary category valid and mirror it to SEO-plugin keys. */
function go_verge_sync_primary_category( $post_id, $post = null ) {
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || 'post' !== get_post_type( $post_id ) ) {
		return;
	}

	$primary = absint( get_post_meta( $post_id, '_go_primary_category_id', true ) );
	$assigned = array_map( 'intval', wp_get_post_categories( $post_id ) );

	if ( $primary && ! in_array( $primary, $assigned, true ) ) {
		$primary = 0;
		delete_post_meta( $post_id, '_go_primary_category_id' );
	}

	if ( ! $primary ) {
		if ( metadata_exists( 'post', $post_id, '_go_primary_category_id' ) ) {
			delete_post_meta( $post_id, 'rank_math_primary_category' );
			delete_post_meta( $post_id, '_yoast_wpseo_primary_category' );
		}
		return;
	}

	update_post_meta( $post_id, 'rank_math_primary_category', $primary );
	update_post_meta( $post_id, '_yoast_wpseo_primary_category', $primary );
}
add_action( 'save_post_post', 'go_verge_sync_primary_category', 80, 2 );

/** Prefer the explicit GO primary category before generic first-term fallback. */
function go_verge_primary_category_id( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return 0;
	}
	$primary = absint( get_post_meta( $post_id, '_go_primary_category_id', true ) );
	if ( $primary && has_category( $primary, $post_id ) ) {
		return $primary;
	}
	$rank_math = absint( get_post_meta( $post_id, 'rank_math_primary_category', true ) );
	if ( $rank_math && has_category( $rank_math, $post_id ) ) {
		return $rank_math;
	}
	$categories = wp_get_post_categories( $post_id );
	return $categories ? (int) reset( $categories ) : 0;
}

/** Add body state for optional editorial backgrounds. */
function go_verge_editorial_background_body_class( $classes ) {
	if ( is_singular( 'post' ) ) {
		$post_id = get_queried_object_id();
		$image_id = absint( get_post_meta( $post_id, '_go_editorial_background_id', true ) );
		if ( $image_id && wp_attachment_is_image( $image_id ) ) {
			$strength = get_post_meta( $post_id, '_go_editorial_background_strength', true );
			$strength = in_array( $strength, array( 'subtle', 'medium', 'strong' ), true ) ? $strength : 'subtle';
			$classes[] = 'go-has-editorial-background';
			$classes[] = 'go-editorial-background--' . sanitize_html_class( $strength );
		}
	}
	return $classes;
}
add_filter( 'body_class', 'go_verge_editorial_background_body_class', 30 );

/** Print only the URL/position variables for the current post background. */
function go_verge_editorial_background_css() {
	if ( ! is_singular( 'post' ) ) {
		return;
	}
	$post_id  = get_queried_object_id();
	$image_id = absint( get_post_meta( $post_id, '_go_editorial_background_id', true ) );
	$url      = $image_id ? wp_get_attachment_image_url( $image_id, 'full' ) : '';
	if ( ! $url ) {
		return;
	}
	$position_key = get_post_meta( $post_id, '_go_editorial_background_position', true );
	$positions = array(
		'center-top' => 'center top',
		'center'     => 'center center',
		'left-top'   => 'left top',
		'right-top'  => 'right top',
	);
	$position = isset( $positions[ $position_key ] ) ? $positions[ $position_key ] : $positions['center-top'];
	printf(
		'<style id="go-editorial-background-vars">body.postid-%1$d{--go-editorial-bg-image:url("%2$s");--go-editorial-bg-position:%3$s}</style>' . "\n",
		(int) $post_id,
		esc_url( $url ),
		esc_html( $position )
	);
}
add_action( 'wp_head', 'go_verge_editorial_background_css', 25 );

/** Add quality filters to Media Library list view. */
function go_verge_media_quality_filter_dropdown( $post_type ) {
	if ( 'attachment' !== $post_type ) {
		return;
	}
	$current = isset( $_GET['go_media_quality'] ) ? sanitize_key( wp_unslash( $_GET['go_media_quality'] ) ) : '';
	?>
	<label class="screen-reader-text" for="go-media-quality-filter"><?php esc_html_e( 'Filtrar qualidade editorial das imagens', 'go-verge' ); ?></label>
	<select name="go_media_quality" id="go-media-quality-filter">
		<option value=""><?php esc_html_e( 'Qualidade editorial: todas', 'go-verge' ); ?></option>
		<option value="missing_alt" <?php selected( $current, 'missing_alt' ); ?>><?php esc_html_e( 'Sem texto alternativo', 'go-verge' ); ?></option>
		<option value="missing_caption" <?php selected( $current, 'missing_caption' ); ?>><?php esc_html_e( 'Sem legenda', 'go-verge' ); ?></option>
		<option value="generic_title" <?php selected( $current, 'generic_title' ); ?>><?php esc_html_e( 'Título genérico', 'go-verge' ); ?></option>
	</select>
	<?php
}
add_action( 'restrict_manage_posts', 'go_verge_media_quality_filter_dropdown', 20, 1 );

/** Apply media quality filters in list view and media modal queries. */
function go_verge_apply_media_quality_query( $query ) {
	if ( ! is_admin() || ! $query instanceof WP_Query ) {
		return;
	}
	$quality = sanitize_key( (string) $query->get( 'go_media_quality' ) );
	if ( '' === $quality && isset( $_GET['go_media_quality'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$quality = sanitize_key( wp_unslash( $_GET['go_media_quality'] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$query->set( 'go_media_quality', $quality );
	}
	if ( 'missing_alt' === $quality ) {
		$meta_query   = (array) $query->get( 'meta_query' );
		$meta_query[] = array(
			'relation' => 'OR',
			array( 'key' => '_wp_attachment_image_alt', 'compare' => 'NOT EXISTS' ),
			array( 'key' => '_wp_attachment_image_alt', 'value' => '', 'compare' => '=' ),
		);
		$query->set( 'meta_query', $meta_query );
	}
}
add_action( 'pre_get_posts', 'go_verge_apply_media_quality_query', 20 );

/** Carry the quality flag from the media modal AJAX request into WP_Query. */
function go_verge_media_modal_query_args( $args ) {
	$quality = '';
	if ( isset( $_REQUEST['query']['go_media_quality'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$quality = sanitize_key( wp_unslash( $_REQUEST['query']['go_media_quality'] ) ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	}
	if ( in_array( $quality, array( 'missing_alt', 'missing_caption', 'generic_title' ), true ) ) {
		$args['go_media_quality'] = $quality;
		if ( 'missing_alt' === $quality ) {
			$args['meta_query'] = array( // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_query
				'relation' => 'OR',
				array( 'key' => '_wp_attachment_image_alt', 'compare' => 'NOT EXISTS' ),
				array( 'key' => '_wp_attachment_image_alt', 'value' => '', 'compare' => '=' ),
			);
		}
	}
	return $args;
}
add_filter( 'ajax_query_attachments_args', 'go_verge_media_modal_query_args', 20 );

/** SQL clauses for caption/title quality filters. */
function go_verge_media_quality_where( $where, $query ) {
	global $wpdb;
	$quality = sanitize_key( (string) $query->get( 'go_media_quality' ) );
	if ( 'missing_caption' === $quality ) {
		$where .= " AND ({$wpdb->posts}.post_excerpt = '' OR {$wpdb->posts}.post_excerpt IS NULL)";
	} elseif ( 'generic_title' === $quality ) {
		$where .= " AND ({$wpdb->posts}.post_title REGEXP '^(IMG|IMAGE|IMAGEM|FOTO|PHOTO|DSC|DSCN|PXL|SCREENSHOT|CAPTURA|WHATSAPP)[ _-]*[0-9A-Z_-]*$' OR {$wpdb->posts}.post_title REGEXP '^[0-9]{6,}$')";
	}
	return $where;
}
add_filter( 'posts_where', 'go_verge_media_quality_where', 20, 2 );

/** Add practical editorial columns to the Media Library list. */
function go_verge_media_editorial_columns( $columns ) {
	$columns['go_alt']     = __( 'Texto alternativo', 'go-verge' );
	$columns['go_caption'] = __( 'Legenda', 'go-verge' );
	return $columns;
}
add_filter( 'manage_media_columns', 'go_verge_media_editorial_columns', 20 );

/** Render compact quality status in Media Library list columns. */
function go_verge_media_editorial_column_content( $column, $post_id ) {
	if ( ! wp_attachment_is_image( $post_id ) ) {
		return;
	}
	if ( 'go_alt' === $column ) {
		$value = trim( (string) get_post_meta( $post_id, '_wp_attachment_image_alt', true ) );
		echo $value ? esc_html( wp_html_excerpt( $value, 70, '…' ) ) : '<span class="go-media-missing">' . esc_html__( 'Ausente', 'go-verge' ) . '</span>';
	}
	if ( 'go_caption' === $column ) {
		$value = trim( (string) wp_get_attachment_caption( $post_id ) );
		echo $value ? esc_html( wp_html_excerpt( $value, 70, '…' ) ) : '<span class="go-media-missing">' . esc_html__( 'Ausente', 'go-verge' ) . '</span>';
	}
}
add_action( 'manage_media_custom_column', 'go_verge_media_editorial_column_content', 20, 2 );

/** Enqueue the expanded media workspace in image-related admin screens. */
function go_verge_editorial_media_workspace_assets( $hook_suffix ) {
	if ( defined( 'GED_VERSION' ) && in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	if ( ! current_user_can( 'upload_files' ) ) {
		return;
	}
	if ( ! in_array( $hook_suffix, array( 'upload.php', 'media-new.php', 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	wp_enqueue_script(
		'go-verge-media-workspace',
		GO_VERGE_URI . '/assets/js/media-workspace.js',
		array( 'media-views', 'wp-api-fetch' ),
		go_verge_asset_version( '/assets/js/media-workspace.js' ),
		true
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_editorial_media_workspace_assets', 40 );

/** Resolve an imported attachment into the data a core/image block needs. */
function go_verge_external_image_attachment_payload( $attachment_id ) {
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id || ! wp_attachment_is_image( $attachment_id ) ) {
		return array();
	}
	$src = wp_get_attachment_image_src( $attachment_id, 'full' );
	if ( ! $src ) {
		return array();
	}
	return array(
		'id'     => $attachment_id,
		'url'    => (string) $src[0],
		'width'  => absint( $src[1] ),
		'height' => absint( $src[2] ),
		'alt'    => (string) get_post_meta( $attachment_id, '_wp_attachment_image_alt', true ),
	);
}

/**
 * Import an external image into Media Library as soon as Gutenberg receives it.
 *
 * This mirrors WordPress' manual "Upload external image" action, but happens
 * automatically for core/image blocks with a remote URL and no attachment ID.
 * The endpoint deliberately uses WordPress' safe HTTP stack, validates the
 * downloaded bytes as an actual raster image and deduplicates by source URL.
 */
function go_verge_ajax_import_external_editor_image() {
	check_ajax_referer( 'go_verge_auto_import_external_image', 'nonce' );

	$post_id = isset( $_POST['post_id'] ) ? absint( wp_unslash( $_POST['post_id'] ) ) : 0;
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || ! current_user_can( 'edit_post', $post_id ) || ! current_user_can( 'upload_files' ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão para importar esta imagem.', 'go-verge' ) ), 403 );
	}

	$url = isset( $_POST['url'] ) ? esc_url_raw( wp_unslash( $_POST['url'] ), array( 'http', 'https' ) ) : '';
	if ( ! $url || ! wp_http_validate_url( $url ) ) {
		wp_send_json_error( array( 'message' => __( 'URL de imagem inválida.', 'go-verge' ) ), 400 );
	}

	$alt = isset( $_POST['alt'] ) ? sanitize_text_field( wp_unslash( $_POST['alt'] ) ) : '';
	$caption = isset( $_POST['caption'] ) ? wp_kses_post( wp_unslash( $_POST['caption'] ) ) : '';

	// A local attachment URL without an ID only needs to be reconnected, not copied.
	$local_id = attachment_url_to_postid( $url );
	if ( $local_id && wp_attachment_is_image( $local_id ) ) {
		wp_send_json_success( go_verge_external_image_attachment_payload( $local_id ) );
	}

	$source_hash = hash( 'sha256', $url );
	$existing = get_posts( array(
		'post_type'              => 'attachment',
		'post_status'            => 'inherit',
		'post_mime_type'         => 'image',
		'posts_per_page'         => 1,
		'fields'                 => 'ids',
		'no_found_rows'          => true,
		'update_post_meta_cache' => false,
		'update_post_term_cache' => false,
		'meta_key'               => '_go_external_source_hash', // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_key
		'meta_value'             => $source_hash, // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_value
	) );
	if ( ! empty( $existing[0] ) && wp_attachment_is_image( $existing[0] ) ) {
		wp_send_json_success( go_verge_external_image_attachment_payload( (int) $existing[0] ) );
	}

	require_once ABSPATH . 'wp-admin/includes/file.php';
	require_once ABSPATH . 'wp-admin/includes/media.php';
	require_once ABSPATH . 'wp-admin/includes/image.php';

	$tmp = download_url( $url, 20 );
	if ( is_wp_error( $tmp ) ) {
		wp_send_json_error( array( 'message' => $tmp->get_error_message() ), 400 );
	}

	$cleanup = static function () use ( $tmp ) {
		if ( is_string( $tmp ) && file_exists( $tmp ) ) {
			@unlink( $tmp ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		}
	};

	$size = @filesize( $tmp ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	$max  = (int) wp_max_upload_size();
	if ( false === $size || $size < 1 || ( $max > 0 && $size > $max ) ) {
		$cleanup();
		wp_send_json_error( array( 'message' => __( 'A imagem excede o limite de upload do site.', 'go-verge' ) ), 413 );
	}

	$mime = function_exists( 'wp_get_image_mime' ) ? wp_get_image_mime( $tmp ) : false;
	$extensions = array(
		'image/jpeg' => 'jpg',
		'image/png'  => 'png',
		'image/gif'  => 'gif',
		'image/webp' => 'webp',
		'image/avif' => 'avif',
	);
	if ( ! $mime || ! isset( $extensions[ $mime ] ) ) {
		$cleanup();
		wp_send_json_error( array( 'message' => __( 'O endereço não retornou uma imagem compatível.', 'go-verge' ) ), 415 );
	}

	$path = (string) wp_parse_url( $url, PHP_URL_PATH );
	$name = sanitize_file_name( wp_basename( $path ) );
	$checked = wp_check_filetype( $name );
	if ( empty( $checked['ext'] ) || $mime !== (string) $checked['type'] ) {
		$base = sanitize_file_name( pathinfo( $name, PATHINFO_FILENAME ) );
		if ( '' === $base ) {
			$base = 'imagem-importada-' . substr( $source_hash, 0, 10 );
		}
		$name = $base . '.' . $extensions[ $mime ];
	}

	$file_array = array(
		'name'     => $name,
		'tmp_name' => $tmp,
	);
	$desc = $alt ? $alt : sanitize_text_field( pathinfo( $name, PATHINFO_FILENAME ) );
	$attachment_id = media_handle_sideload( $file_array, $post_id, $desc );
	if ( is_wp_error( $attachment_id ) ) {
		$cleanup();
		wp_send_json_error( array( 'message' => $attachment_id->get_error_message() ), 400 );
	}

	// media_handle_sideload() moved the temp file on success.
	update_post_meta( $attachment_id, '_go_external_source_url', $url );
	update_post_meta( $attachment_id, '_go_external_source_hash', $source_hash );
	if ( '' !== $alt ) {
		update_post_meta( $attachment_id, '_wp_attachment_image_alt', $alt );
	}
	if ( '' !== trim( wp_strip_all_tags( $caption ) ) ) {
		wp_update_post( array( 'ID' => $attachment_id, 'post_excerpt' => $caption ) );
	}

	$payload = go_verge_external_image_attachment_payload( $attachment_id );
	if ( ! $payload ) {
		wp_send_json_error( array( 'message' => __( 'A imagem foi importada, mas não pôde ser vinculada ao bloco.', 'go-verge' ) ), 500 );
	}
	wp_send_json_success( $payload );
}
add_action( 'wp_ajax_go_verge_import_external_editor_image', 'go_verge_ajax_import_external_editor_image' );

/** Load zero-click external-image import only inside the post block editor. */
function go_verge_external_image_auto_import_editor_assets() {
	if ( ! current_user_can( 'upload_files' ) ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}

	wp_enqueue_script(
		'go-verge-editor-auto-image-import',
		GO_VERGE_URI . '/assets/js/editor-auto-image-import.js',
		array( 'wp-data', 'wp-dom-ready' ),
		go_verge_asset_version( '/assets/js/editor-auto-image-import.js' ),
		true
	);
	wp_localize_script(
		'go-verge-editor-auto-image-import',
		'GoVergeAutoImageImport',
		array(
			'ajaxUrl' => admin_url( 'admin-ajax.php' ),
			'nonce'   => wp_create_nonce( 'go_verge_auto_import_external_image' ),
			'homeUrl' => home_url( '/' ),
		)
	);
}
add_action( 'enqueue_block_editor_assets', 'go_verge_external_image_auto_import_editor_assets', 35 );

