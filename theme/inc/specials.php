<?php
/**
 * Overdrive Specials.
 *
 * Reusable presentation system for high-end editorial specials. A post keeps
 * its normal WordPress identity/SEO while the front end can render a dedicated
 * package or per-post custom HTML/CSS/JS instead of the standard article.
 *
 * Package contract (theme/specials/{id}/manifest.json):
 * - id:            sanitize_key-compatible package id.
 * - name:          human-readable admin label.
 * - version:       cache-busting version.
 * - description:   optional editor help text.
 * - content_mode:  "file", "post_content" or "custom_meta".
 * - content:       HTML filename when content_mode=file.
 * - style:         package CSS filename (optional).
 * - script:        package JS filename (optional).
 * - auto_slugs:    optional array of post slugs that activate automatically.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Register code meta so WordPress can carry it with post revisions. */
function go_verge_specials_register_meta() {
	$common = array(
		'single'            => true,
		'type'              => 'string',
		'show_in_rest'      => false,
		'revisions_enabled' => true,
		'auth_callback'     => static function( $allowed, $meta_key, $post_id ) {
			return current_user_can( 'edit_post', $post_id );
		},
	);

	register_post_meta( 'post', '_go_special_custom_html', $common );
	register_post_meta( 'post', '_go_special_custom_css', $common );
	register_post_meta( 'post', '_go_special_custom_js', $common );
}
add_action( 'init', 'go_verge_specials_register_meta' );

/** Get all valid bundled special packages. */
function go_verge_specials_registry() {
	static $registry = null;
	if ( null !== $registry ) {
		return $registry;
	}

	$registry = array();
	$root     = trailingslashit( GO_VERGE_DIR ) . 'specials';
	if ( ! is_dir( $root ) ) {
		return $registry;
	}

	$dirs = glob( $root . '/*', GLOB_ONLYDIR );
	if ( ! is_array( $dirs ) ) {
		return $registry;
	}

	foreach ( $dirs as $dir ) {
		$manifest_file = trailingslashit( $dir ) . 'manifest.json';
		if ( ! is_readable( $manifest_file ) ) {
			continue;
		}

		$manifest = json_decode( (string) file_get_contents( $manifest_file ), true ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
		if ( ! is_array( $manifest ) ) {
			continue;
		}

		$id = isset( $manifest['id'] ) ? sanitize_key( $manifest['id'] ) : '';
		if ( '' === $id || basename( $dir ) !== $id ) {
			continue;
		}

		$mode = isset( $manifest['content_mode'] ) ? sanitize_key( $manifest['content_mode'] ) : 'file';
		if ( ! in_array( $mode, array( 'file', 'post_content', 'custom_meta' ), true ) ) {
			continue;
		}

		$manifest['id']           = $id;
		$manifest['name']         = ! empty( $manifest['name'] ) ? sanitize_text_field( $manifest['name'] ) : $id;
		$manifest['description']  = ! empty( $manifest['description'] ) ? sanitize_text_field( $manifest['description'] ) : '';
		$manifest['version']      = ! empty( $manifest['version'] ) ? sanitize_text_field( $manifest['version'] ) : '1.0.0';
		$manifest['content_mode'] = $mode;
		$manifest['dir']          = trailingslashit( $dir );
		$manifest['uri']          = trailingslashit( GO_VERGE_URI ) . 'specials/' . rawurlencode( $id ) . '/';
		$manifest['auto_slugs']   = ! empty( $manifest['auto_slugs'] ) && is_array( $manifest['auto_slugs'] )
			? array_values( array_filter( array_map( 'sanitize_title', $manifest['auto_slugs'] ) ) )
			: array();

		foreach ( array( 'content', 'style', 'script' ) as $file_key ) {
			$value = isset( $manifest[ $file_key ] ) ? wp_basename( (string) $manifest[ $file_key ] ) : '';
			$manifest[ $file_key ] = $value;
		}

		if ( 'file' === $mode && ( '' === $manifest['content'] || ! is_readable( $manifest['dir'] . $manifest['content'] ) ) ) {
			continue;
		}

		$registry[ $id ] = $manifest;
	}

	ksort( $registry );
	$registry = apply_filters( 'go_verge_specials_registry', $registry );
	return $registry;
}

/** Resolve the special package for a post. Explicit editor choice wins over slug auto-detection. */
function go_verge_specials_get_for_post( $post_id ) {
	$post_id  = absint( $post_id );
	$registry = go_verge_specials_registry();
	if ( ! $post_id || empty( $registry ) ) {
		return null;
	}

	$enabled = get_post_meta( $post_id, '_go_special_enabled', true );
	$chosen  = sanitize_key( (string) get_post_meta( $post_id, '_go_special_id', true ) );

	/* An explicit off state always beats automatic slug matching. */
	if ( '0' === (string) $enabled ) {
		return null;
	}

	if ( '1' === (string) $enabled && $chosen && isset( $registry[ $chosen ] ) ) {
		return $registry[ $chosen ];
	}

	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return null;
	}

	$slug = sanitize_title( $post->post_name );
	foreach ( $registry as $package ) {
		if ( $slug && in_array( $slug, $package['auto_slugs'], true ) ) {
			return $package;
		}
	}

	return null;
}

/** Whether the current singular post uses a Special. */
function go_verge_specials_is_current() {
	if ( is_admin() || ! is_singular( 'post' ) ) {
		return false;
	}
	return (bool) go_verge_specials_get_for_post( get_queried_object_id() );
}

/** Swap only presentation; the queried post and all SEO metadata remain unchanged. */
function go_verge_specials_template_include( $template ) {
	if ( ! go_verge_specials_is_current() ) {
		return $template;
	}

	$special_template = locate_template( 'single-special.php', false, false );
	return $special_template ? $special_template : $template;
}
add_filter( 'template_include', 'go_verge_specials_template_include', 100000 );

/** Load package assets only on the selected special. */
function go_verge_specials_enqueue_assets() {
	if ( ! go_verge_specials_is_current() ) {
		return;
	}

	$post_id = get_queried_object_id();
	$package = go_verge_specials_get_for_post( $post_id );
	if ( ! $package ) {
		return;
	}

	$style_handle  = 'go-special-' . $package['id'];
	$script_handle = 'go-special-' . $package['id'];

	if ( ! empty( $package['style'] ) && is_readable( $package['dir'] . $package['style'] ) ) {
		$version = (string) filemtime( $package['dir'] . $package['style'] );
		wp_enqueue_style(
			$style_handle,
			$package['uri'] . rawurlencode( $package['style'] ),
			array(),
			$version ? $version : $package['version']
		);
	}

	if ( 'custom_meta' === $package['content_mode'] ) {
		$custom_css = (string) get_post_meta( $post_id, '_go_special_custom_css', true );
		if ( '' !== trim( $custom_css ) ) {
			if ( ! wp_style_is( $style_handle, 'enqueued' ) ) {
				wp_register_style( $style_handle, false, array(), $package['version'] );
				wp_enqueue_style( $style_handle );
			}
			wp_add_inline_style( $style_handle, $custom_css );
		}
	}

	if ( ! empty( $package['script'] ) && is_readable( $package['dir'] . $package['script'] ) ) {
		$version = (string) filemtime( $package['dir'] . $package['script'] );
		wp_enqueue_script(
			$script_handle,
			$package['uri'] . rawurlencode( $package['script'] ),
			array(),
			$version ? $version : $package['version'],
			true
		);
	}

	if ( 'custom_meta' === $package['content_mode'] ) {
		$custom_js = (string) get_post_meta( $post_id, '_go_special_custom_js', true );
		if ( '' !== trim( $custom_js ) ) {
			if ( ! wp_script_is( $script_handle, 'enqueued' ) ) {
				$runtime = trailingslashit( GO_VERGE_DIR ) . 'specials/custom/runtime.js';
				$src     = trailingslashit( GO_VERGE_URI ) . 'specials/custom/runtime.js';
				wp_enqueue_script( $script_handle, $src, array(), is_readable( $runtime ) ? (string) filemtime( $runtime ) : $package['version'], true );
			}
			wp_add_inline_script( $script_handle, $custom_js, 'after' );
		}
	}
}
/* Late priority: special CSS should win over generic article/theme styles. */
add_action( 'wp_enqueue_scripts', 'go_verge_specials_enqueue_assets', 999 );

/** Add useful body hooks without coupling the package to global theme selectors. */
function go_verge_specials_body_class( $classes ) {
	if ( go_verge_specials_is_current() ) {
		$package   = go_verge_specials_get_for_post( get_queried_object_id() );
		$classes[] = 'go-special-active';
		if ( $package ) {
			$classes[] = 'go-special-' . sanitize_html_class( $package['id'] );
		}
	}
	return $classes;
}
add_filter( 'body_class', 'go_verge_specials_body_class' );

/** Keep Discover image-preview eligibility explicit on specials without affecting other templates. */
function go_verge_specials_robots( $robots ) {
	if ( go_verge_specials_is_current() ) {
		$robots['max-image-preview'] = 'large';
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_specials_robots', 20 );

/** Tokens available to bundled and custom special HTML. */
function go_verge_specials_token_map( $post_id ) {
	$post     = get_post( $post_id );
	$thumb    = get_the_post_thumbnail_url( $post_id, 'full' );
	$author   = $post instanceof WP_Post ? get_the_author_meta( 'display_name', $post->post_author ) : '';
	$site_url = home_url( '/' );

	return array(
		'{{GO_POST_TITLE}}'       => esc_html( get_the_title( $post_id ) ),
		'{{GO_POST_URL}}'         => esc_url( get_permalink( $post_id ) ),
		'{{GO_POST_DATE}}'        => esc_html( get_the_date( 'j \\d\\e F \\d\\e Y', $post_id ) ),
		'{{GO_POST_MODIFIED}}'    => esc_html( get_the_modified_date( 'j \\d\\e F \\d\\e Y', $post_id ) ),
		'{{GO_FEATURED_IMAGE}}'   => $thumb ? esc_url( $thumb ) : '',
		'{{GO_AUTHOR_NAME}}'      => esc_html( $author ),
		'{{GO_AUTHOR_URL}}'       => $post instanceof WP_Post && $post->post_author ? esc_url( get_author_posts_url( $post->post_author ) ) : '',
		'{{GO_SITE_NAME}}'        => esc_html( get_bloginfo( 'name' ) ),
		'{{GO_SITE_URL}}'         => esc_url( $site_url ),
	);
}

/** Shared, factual authorship credit for packages that replace the usual byline. */
function go_verge_specials_author_credit_html( $post_id ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) || ! $post->post_author ) {
		return '';
	}
	$name = trim( (string) get_the_author_meta( 'display_name', $post->post_author ) );
	$url  = get_author_posts_url( $post->post_author );
	if ( '' === $name || ! $url ) {
		return '';
	}
	return '<aside class="go-container go-special-author" aria-label="' . esc_attr__( 'Autoria editorial', 'go-verge' ) . '"><p>'
		. esc_html__( 'Por', 'go-verge' ) . ' <a href="' . esc_url( $url ) . '" rel="author">' . esc_html( $name ) . '</a></p></aside>';
}

/** Render the selected package. */
function go_verge_specials_render_current() {
	$post_id = get_the_ID();
	$package = go_verge_specials_get_for_post( $post_id );
	if ( ! $package ) {
		return;
	}

	if ( 'post_content' === $package['content_mode'] ) {
		$content = apply_filters( 'the_content', get_post_field( 'post_content', $post_id ) );
		echo '<article class="go-special-free" data-go-special="' . esc_attr( $package['id'] ) . '">';
		echo $content; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- normal filtered WordPress post content.
		echo '</article>';
		return;
	}

	if ( 'custom_meta' === $package['content_mode'] ) {
		$html = (string) get_post_meta( $post_id, '_go_special_custom_html', true );
		$html = strtr( $html, go_verge_specials_token_map( $post_id ) );
		$html = apply_filters( 'go_verge_specials_custom_html', $html, $package, $post_id );

		if ( '' === trim( $html ) ) {
			if ( is_user_logged_in() && current_user_can( 'edit_post', $post_id ) ) {
				echo '<section class="go-special-empty" style="max-width:760px;margin:80px auto;padding:32px;background:#fff;color:#111;border:1px solid #ddd;font:16px/1.5 system-ui,sans-serif"><strong>Especial personalizado ativo, mas o HTML está vazio.</strong><br>Volte à edição da matéria e cole o conteúdo no bloco “Especial personalizado — HTML, CSS e JS”.</section>';
			}
			return;
		}

		echo '<div class="go-special-custom-root" data-go-special="custom" data-go-post="' . esc_attr( (string) $post_id ) . '">';
		echo $html; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- editor-authored special markup, capability-filtered on save.
		echo '</div>';
		return;
	}

	$file = $package['dir'] . $package['content'];
	if ( ! is_readable( $file ) ) {
		return;
	}

	$html = (string) file_get_contents( $file ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
	$html = strtr( $html, go_verge_specials_token_map( $post_id ) );
	$html = apply_filters( 'go_verge_specials_html', $html, $package, $post_id );
	echo $html; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- trusted bundled theme package.
}

/** Build a plain editorial summary for cards/feeds when Gutenberg is intentionally empty. */
function go_verge_specials_plain_summary( $post_id, $words = 55 ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) {
		return '';
	}
	if ( '' !== trim( (string) $post->post_excerpt ) ) {
		return wp_strip_all_tags( $post->post_excerpt );
	}

	$package = go_verge_specials_get_for_post( $post_id );
	if ( ! $package ) {
		return '';
	}

	$html = '';
	if ( 'custom_meta' === $package['content_mode'] ) {
		$html = (string) get_post_meta( $post_id, '_go_special_custom_html', true );
	} elseif ( 'post_content' === $package['content_mode'] ) {
		$html = (string) $post->post_content;
	} elseif ( 'file' === $package['content_mode'] && ! empty( $package['content'] ) ) {
		$file = $package['dir'] . $package['content'];
		if ( is_readable( $file ) ) {
			$html = (string) file_get_contents( $file ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
		}
	}

	if ( '' === trim( $html ) ) {
		return '';
	}
	$html = strtr( $html, go_verge_specials_token_map( $post_id ) );
	$text = trim( preg_replace( '/\s+/', ' ', wp_strip_all_tags( strip_shortcodes( $html ) ) ) );
	return wp_trim_words( $text, absint( $words ) ?: 55, '…' );
}

/** Keep archive cards useful even when a custom Special does not use post_content. */
function go_verge_specials_excerpt_fallback( $excerpt, $post ) {
	if ( '' !== trim( (string) $excerpt ) || ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return $excerpt;
	}
	$summary = go_verge_specials_plain_summary( $post->ID, 55 );
	return '' !== $summary ? $summary : $excerpt;
}
add_filter( 'get_the_excerpt', 'go_verge_specials_excerpt_fallback', 20, 2 );

/** Feeds get a compact teaser + canonical link instead of an empty Gutenberg body. */
function go_verge_specials_feed_content( $content, $feed_type ) {
	global $post;
	if ( ! ( $post instanceof WP_Post ) || ! go_verge_specials_get_for_post( $post->ID ) ) {
		return $content;
	}
	$summary = go_verge_specials_plain_summary( $post->ID, 80 );
	if ( '' === $summary ) {
		return $content;
	}
	return '<p>' . esc_html( $summary ) . '</p><p><a href="' . esc_url( get_permalink( $post ) ) . '">' . esc_html__( 'Leia o especial completo no Overdrive', 'go-verge' ) . '</a></p>';
}
add_filter( 'the_content_feed', 'go_verge_specials_feed_content', 20, 2 );

/** Sidebar editor control + large code box. */
function go_verge_specials_add_meta_box() {
	add_meta_box(
		'go-verge-specials',
		__( 'Layout Especial', 'go-verge' ),
		'go_verge_specials_meta_box',
		'post',
		'side',
		'high',
		array( '__block_editor_compatible_meta_box' => true )
	);

	add_meta_box(
		'go-verge-special-code',
		__( 'Especial personalizado — HTML, CSS e JS', 'go-verge' ),
		'go_verge_specials_code_meta_box',
		'post',
		'normal',
		'high',
		array( '__block_editor_compatible_meta_box' => true )
	);
}
add_action( 'add_meta_boxes', 'go_verge_specials_add_meta_box' );

function go_verge_specials_meta_box( $post ) {
	$registry = go_verge_specials_registry();
	$enabled  = get_post_meta( $post->ID, '_go_special_enabled', true );
	$chosen   = sanitize_key( (string) get_post_meta( $post->ID, '_go_special_id', true ) );
	$resolved = go_verge_specials_get_for_post( $post->ID );
	wp_nonce_field( 'go_verge_specials_save', 'go_verge_specials_nonce' );
	?>
	<p style="margin-top:0"><strong><?php esc_html_e( 'Troque apenas o visual desta matéria.', 'go-verge' ); ?></strong><br>
	<?php esc_html_e( 'Permalink, autor, categoria, Yoast, sitemap, feed e analytics continuam sendo os do post normal.', 'go-verge' ); ?></p>

	<label for="go_special_enabled" style="display:block;font-weight:600;margin:12px 0 4px"><?php esc_html_e( 'Estado', 'go-verge' ); ?></label>
	<select id="go_special_enabled" name="go_special_enabled" style="width:100%">
		<option value="" <?php selected( $enabled, '' ); ?>><?php esc_html_e( 'Automático por slug / padrão', 'go-verge' ); ?></option>
		<option value="1" <?php selected( $enabled, '1' ); ?>><?php esc_html_e( 'Usar Especial', 'go-verge' ); ?></option>
		<option value="0" <?php selected( $enabled, '0' ); ?>><?php esc_html_e( 'Forçar matéria normal', 'go-verge' ); ?></option>
	</select>

	<label for="go_special_id" style="display:block;font-weight:600;margin:12px 0 4px"><?php esc_html_e( 'Design', 'go-verge' ); ?></label>
	<select id="go_special_id" name="go_special_id" style="width:100%">
		<option value=""><?php esc_html_e( 'Selecione…', 'go-verge' ); ?></option>
		<?php foreach ( $registry as $id => $package ) : ?>
			<option value="<?php echo esc_attr( $id ); ?>" <?php selected( $chosen, $id ); ?>><?php echo esc_html( $package['name'] ); ?></option>
		<?php endforeach; ?>
	</select>

	<?php if ( $resolved ) : ?>
		<p style="padding:8px 10px;background:#e7f5ea;border-left:4px solid #1f883d"><strong><?php esc_html_e( 'Ativo:', 'go-verge' ); ?></strong> <?php echo esc_html( $resolved['name'] ); ?></p>
	<?php else : ?>
		<p style="padding:8px 10px;background:#f6f7f7;border-left:4px solid #8c8f94"><?php esc_html_e( 'Esta matéria usa o layout normal.', 'go-verge' ); ?></p>
	<?php endif; ?>

	<p class="description"><strong><?php esc_html_e( 'Novo especial?', 'go-verge' ); ?></strong> <?php esc_html_e( 'Escolha “Especial personalizado” e cole HTML + CSS no bloco grande abaixo do editor. JS é opcional.', 'go-verge' ); ?></p>
	<p class="description"><?php esc_html_e( 'O GTA VI também ativa automaticamente com os slugs gta-6-guia-completo ou gta-6-guia-definitivo.', 'go-verge' ); ?></p>
	<p><a href="<?php echo esc_url( admin_url( 'edit.php?page=go-verge-specials' ) ); ?>"><?php esc_html_e( 'Ver todos os Especiais →', 'go-verge' ); ?></a></p>
	<?php
}

/** Large per-post code editors for the reusable custom special. */
function go_verge_specials_code_meta_box( $post ) {
	$html = (string) get_post_meta( $post->ID, '_go_special_custom_html', true );
	$css  = (string) get_post_meta( $post->ID, '_go_special_custom_css', true );
	$js   = (string) get_post_meta( $post->ID, '_go_special_custom_js', true );
	wp_nonce_field( 'go_verge_specials_code_save', 'go_verge_specials_code_nonce' );
	?>
	<div class="go-special-code-intro">
		<p><strong><?php esc_html_e( 'Para futuros especiais, é só colar e publicar.', 'go-verge' ); ?></strong> <?php esc_html_e( 'Use “Especial personalizado” em Layout Especial. O Gutenberg pode ficar vazio.', 'go-verge' ); ?></p>
		<p class="description"><?php esc_html_e( 'HTML: cole apenas o conteúdo da página (ex.: <main>…</main>), sem <!doctype>, <html>, <head>, <body>, <style> ou <script>. CSS e JS têm campos próprios.', 'go-verge' ); ?></p>
		<p class="description"><strong><?php esc_html_e( 'Tokens opcionais:', 'go-verge' ); ?></strong> <code>{{GO_POST_TITLE}}</code> <code>{{GO_POST_URL}}</code> <code>{{GO_POST_DATE}}</code> <code>{{GO_POST_MODIFIED}}</code> <code>{{GO_FEATURED_IMAGE}}</code> <code>{{GO_AUTHOR_NAME}}</code> <code>{{GO_SITE_NAME}}</code></p>
	</div>

	<p><label for="go_special_custom_html"><strong><?php esc_html_e( '1. HTML do especial', 'go-verge' ); ?></strong></label><br>
	<textarea id="go_special_custom_html" name="go_special_custom_html" spellcheck="false" style="width:100%;min-height:520px;font-family:monospace"><?php echo esc_textarea( $html ); ?></textarea></p>
	<p class="description go-special-count" data-for="go_special_custom_html"></p>

	<p><label for="go_special_custom_css"><strong><?php esc_html_e( '2. CSS do especial', 'go-verge' ); ?></strong></label> <span class="description"><?php esc_html_e( '— sem tags <style>', 'go-verge' ); ?></span><br>
	<textarea id="go_special_custom_css" name="go_special_custom_css" spellcheck="false" style="width:100%;min-height:360px;font-family:monospace"><?php echo esc_textarea( $css ); ?></textarea></p>
	<p class="description go-special-count" data-for="go_special_custom_css"></p>

	<p><label for="go_special_custom_js"><strong><?php esc_html_e( '3. JavaScript opcional', 'go-verge' ); ?></strong></label> <span class="description"><?php esc_html_e( '— sem tags <script>; evite se não for necessário', 'go-verge' ); ?></span><br>
	<textarea id="go_special_custom_js" name="go_special_custom_js" spellcheck="false" style="width:100%;min-height:260px;font-family:monospace" <?php disabled( ! current_user_can( 'unfiltered_html' ) ); ?>><?php echo esc_textarea( $js ); ?></textarea></p>
	<?php if ( ! current_user_can( 'unfiltered_html' ) ) : ?>
		<p class="notice-inline" style="padding:10px;background:#fff8e5;border-left:4px solid #dba617"><?php esc_html_e( 'Seu usuário não tem permissão unfiltered_html; por segurança, JavaScript personalizado fica somente leitura. HTML e CSS continuam disponíveis.', 'go-verge' ); ?></p>
	<?php endif; ?>
	<p class="description go-special-count" data-for="go_special_custom_js"></p>

	<?php if ( 'auto-draft' !== $post->post_status ) : ?>
		<p><a class="button button-secondary" href="<?php echo esc_url( get_preview_post_link( $post ) ); ?>" target="_blank" rel="noopener"><?php esc_html_e( 'Abrir prévia do especial ↗', 'go-verge' ); ?></a> <span class="description"><?php esc_html_e( 'Salve/atualize primeiro para ver o código mais recente.', 'go-verge' ); ?></span></p>
	<?php else : ?>
		<p class="description"><?php esc_html_e( 'Salve o rascunho uma vez para liberar o link de prévia.', 'go-verge' ); ?></p>
	<?php endif; ?>
	<?php
}

/** Remove only wrapper tags accidentally pasted into CSS/JS fields. */
function go_verge_specials_sanitize_custom_css( $css ) {
	$css = str_replace( "\0", '', (string) $css );
	$css = preg_replace( '#</?style\b[^>]*>#i', '', $css );
	return trim( (string) $css );
}

function go_verge_specials_sanitize_custom_js( $js ) {
	$js = str_replace( "\0", '', (string) $js );
	$js = preg_replace( '#</?script\b[^>]*>#i', '', $js );
	return trim( (string) $js );
}

/** Save presentation choice and custom code. */
function go_verge_specials_save_meta( $post_id ) {
	if ( wp_is_post_autosave( $post_id ) || wp_is_post_revision( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$choice_ok = isset( $_POST['go_verge_specials_nonce'] ) && wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_specials_nonce'] ) ), 'go_verge_specials_save' );
	if ( $choice_ok ) {
		$enabled = isset( $_POST['go_special_enabled'] ) ? sanitize_text_field( wp_unslash( $_POST['go_special_enabled'] ) ) : '';
		$enabled = in_array( $enabled, array( '0', '1' ), true ) ? $enabled : '';
		if ( '' === $enabled ) {
			delete_post_meta( $post_id, '_go_special_enabled' );
		} else {
			update_post_meta( $post_id, '_go_special_enabled', $enabled );
		}

		$chosen   = isset( $_POST['go_special_id'] ) ? sanitize_key( wp_unslash( $_POST['go_special_id'] ) ) : '';
		$registry = go_verge_specials_registry();
		if ( $chosen && isset( $registry[ $chosen ] ) ) {
			update_post_meta( $post_id, '_go_special_id', $chosen );
		} else {
			delete_post_meta( $post_id, '_go_special_id' );
		}
	}

	$code_ok = isset( $_POST['go_verge_specials_code_nonce'] ) && wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_specials_code_nonce'] ) ), 'go_verge_specials_code_save' );
	if ( ! $code_ok ) {
		return;
	}

	$raw_html = isset( $_POST['go_special_custom_html'] ) ? wp_unslash( $_POST['go_special_custom_html'] ) : '';
	/* Administrators can author full semantic HTML. Other editors get normal post-content KSES. */
	$html = current_user_can( 'unfiltered_html' ) ? (string) $raw_html : wp_kses_post( $raw_html );
	$html = trim( $html );
	if ( '' === $html ) {
		delete_post_meta( $post_id, '_go_special_custom_html' );
	} else {
		update_post_meta( $post_id, '_go_special_custom_html', $html );
	}

	$raw_css = isset( $_POST['go_special_custom_css'] ) ? wp_unslash( $_POST['go_special_custom_css'] ) : '';
	$css     = go_verge_specials_sanitize_custom_css( $raw_css );
	if ( '' === $css ) {
		delete_post_meta( $post_id, '_go_special_custom_css' );
	} else {
		update_post_meta( $post_id, '_go_special_custom_css', $css );
	}

	/* Never let a lower-capability editor overwrite or erase trusted JS. */
	if ( current_user_can( 'unfiltered_html' ) ) {
		$raw_js = isset( $_POST['go_special_custom_js'] ) ? wp_unslash( $_POST['go_special_custom_js'] ) : '';
		$js     = go_verge_specials_sanitize_custom_js( $raw_js );
		if ( '' === $js ) {
			delete_post_meta( $post_id, '_go_special_custom_js' );
		} else {
			update_post_meta( $post_id, '_go_special_custom_js', $js );
		}
	}
}
add_action( 'save_post_post', 'go_verge_specials_save_meta', 20 );

/** Syntax highlighting + small editor UX. Uses WordPress core CodeMirror. */
function go_verge_specials_admin_assets( $hook ) {
	if ( ! in_array( $hook, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = get_current_screen();
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}

	$html_settings = wp_enqueue_code_editor( array( 'type' => 'text/html', 'codemirror' => array( 'lineNumbers' => true, 'lineWrapping' => true ) ) );
	$css_settings  = wp_enqueue_code_editor( array( 'type' => 'text/css', 'codemirror' => array( 'lineNumbers' => true, 'lineWrapping' => true ) ) );
	$js_settings   = wp_enqueue_code_editor( array( 'type' => 'text/javascript', 'codemirror' => array( 'lineNumbers' => true, 'lineWrapping' => true ) ) );

	if ( false === $html_settings || false === $css_settings ) {
		return;
	}

	$script = <<<'JS'
jQuery(function($){
	var editors = [];
	function initEditor(id, settings) {
		var el = document.getElementById(id);
		if (!el || !window.wp || !wp.codeEditor) return;
		try {
			var instance = wp.codeEditor.initialize(id, settings);
			if (!instance || !instance.codemirror) return;
			/*
			 * CodeMirror.fromTextArea() writes its buffer back to the textarea only
			 * on the form's NATIVE submit event. The block editor serialises meta
			 * boxes with JavaScript and never fires one, so the textarea kept its
			 * original value and every custom special saved as an empty string --
			 * which is what produced "Especial personalizado ativo, mas o HTML esta
			 * vazio" on the front end.
			 *
			 * Mirroring on every change keeps the textarea authoritative for any
			 * save path: native submit, Gutenberg's fetch, or an autosave.
			 */
			instance.codemirror.on('change', function (cm) {
				el.value = cm.getValue();
				updateCounts();
			});
			editors.push(instance);
		} catch(e) {}
	}

	/* Last line of defence for any save path that does fire a real submit. */
	function flushEditors() {
		editors.forEach(function (instance) {
			try {
				if (instance && instance.codemirror) {
					instance.codemirror.save();
				}
			} catch (e) {}
		});
	}
	$(document).on('submit', 'form#post', flushEditors);
	initEditor('go_special_custom_html', __HTML_SETTINGS__);
	initEditor('go_special_custom_css', __CSS_SETTINGS__);
	initEditor('go_special_custom_js', __JS_SETTINGS__);

	function toggleCustomBox(){
		var selected = $('#go_special_id').val() === 'custom';
		$('#go-verge-special-code').toggle(selected);
	}
	$('#go_special_id').on('change', function(){
		if ($(this).val()) $('#go_special_enabled').val('1');
		toggleCustomBox();
	});
	toggleCustomBox();

	function updateCounts(){
		$('.go-special-count').each(function(){
			var id = $(this).data('for');
			var el = document.getElementById(id);
			if (!el) return;
			var n = (el.value || '').length;
			$(this).text(n.toLocaleString('pt-BR') + ' caracteres');
		});
	}
	$(document).on('input', '#go_special_custom_html,#go_special_custom_css,#go_special_custom_js', updateCounts);
	setTimeout(updateCounts, 250);
});
JS;
	$script = str_replace(
		array( '__HTML_SETTINGS__', '__CSS_SETTINGS__', '__JS_SETTINGS__' ),
		array(
			wp_json_encode( $html_settings ),
			wp_json_encode( $css_settings ),
			wp_json_encode( false === $js_settings ? $html_settings : $js_settings ),
		),
		$script
	);
	wp_add_inline_script( 'code-editor', $script, 'after' );
	wp_add_inline_style( 'code-editor', '.go-special-code-intro{padding:12px 14px;background:#f6f7f7;border-left:4px solid #421aff;margin-bottom:16px}.go-special-code-intro p{margin:.45em 0}.go-special-code-intro code{display:inline-block;margin:2px}.go-special-count{text-align:right;margin-top:-8px!important}.CodeMirror{border:1px solid #c3c4c7;min-height:240px;height:auto}.CodeMirror-scroll{min-height:240px}.go-special-code-intro + p .CodeMirror{min-height:520px}.go-special-code-intro + p .CodeMirror-scroll{min-height:520px}' );
}
add_action( 'admin_enqueue_scripts', 'go_verge_specials_admin_assets' );

/** Add a compact Specials overview under Posts for editors. */
function go_verge_specials_admin_menu() {
	add_submenu_page(
		'edit.php',
		__( 'Especiais', 'go-verge' ),
		__( 'Especiais', 'go-verge' ),
		'edit_posts',
		'go-verge-specials',
		'go_verge_specials_admin_page'
	);
}
add_action( 'admin_menu', 'go_verge_specials_admin_menu' );

function go_verge_specials_admin_page() {
	if ( ! current_user_can( 'edit_posts' ) ) {
		return;
	}
	$registry = go_verge_specials_registry();
	?>
	<div class="wrap">
		<h1><?php esc_html_e( 'Overdrive — Especiais', 'go-verge' ); ?></h1>
		<p><?php esc_html_e( 'Especiais continuam sendo Posts normais. O sistema só substitui o template público e carrega o visual selecionado.', 'go-verge' ); ?></p>
		<table class="widefat striped" style="max-width:1100px">
			<thead><tr><th><?php esc_html_e( 'Design', 'go-verge' ); ?></th><th><?php esc_html_e( 'ID', 'go-verge' ); ?></th><th><?php esc_html_e( 'Uso', 'go-verge' ); ?></th></tr></thead>
			<tbody>
			<?php foreach ( $registry as $package ) : ?>
				<tr>
					<td><strong><?php echo esc_html( $package['name'] ); ?></strong><br><span class="description"><?php echo esc_html( $package['description'] ); ?></span></td>
					<td><code><?php echo esc_html( $package['id'] ); ?></code></td>
					<td>
						<?php
						if ( 'custom_meta' === $package['content_mode'] ) {
							esc_html_e( 'Cole HTML + CSS + JS opcional no próprio post. Gutenberg pode ficar vazio.', 'go-verge' );
						} elseif ( 'post_content' === $package['content_mode'] ) {
							esc_html_e( 'Usa o conteúdo do editor em tela cheia.', 'go-verge' );
						} else {
							esc_html_e( 'Conteúdo e CSS próprios do pacote.', 'go-verge' );
						}
						?>
					</td>
				</tr>
			<?php endforeach; ?>
			</tbody>
		</table>
		<h2><?php esc_html_e( 'Como criar um novo Especial sem mexer no tema', 'go-verge' ); ?></h2>
		<ol>
			<li><?php esc_html_e( 'Crie ou edite uma matéria normal e preencha título, categoria, autor, imagem destacada e Yoast.', 'go-verge' ); ?></li>
			<li><?php esc_html_e( 'Na caixa “Layout Especial”, escolha “Usar Especial” e “Especial personalizado”.', 'go-verge' ); ?></li>
			<li><?php esc_html_e( 'No bloco grande “Especial personalizado — HTML, CSS e JS”, cole o HTML e o CSS. JavaScript é opcional.', 'go-verge' ); ?></li>
			<li><?php esc_html_e( 'Salve o rascunho, abra a prévia e publique. O campo Gutenberg pode continuar vazio.', 'go-verge' ); ?></li>
		</ol>
		<p><strong><?php esc_html_e( 'GTA VI já está pronto:', 'go-verge' ); ?></strong> <?php esc_html_e( 'ele continua como pacote fechado e pode ser escolhido manualmente ou ativado pelos slugs gta-6-guia-completo e gta-6-guia-definitivo.', 'go-verge' ); ?></p>
	</div>
	<?php
}

/** Make active specials visible in the posts list. */
function go_verge_specials_posts_column( $columns ) {
	$columns['go_special'] = __( 'Especial', 'go-verge' );
	return $columns;
}
add_filter( 'manage_post_posts_columns', 'go_verge_specials_posts_column' );

function go_verge_specials_posts_column_content( $column, $post_id ) {
	if ( 'go_special' !== $column ) {
		return;
	}
	$package = go_verge_specials_get_for_post( $post_id );
	echo $package ? esc_html( $package['name'] ) : '—';
}
add_action( 'manage_post_posts_custom_column', 'go_verge_specials_posts_column_content', 10, 2 );
