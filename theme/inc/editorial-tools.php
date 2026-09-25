<?php
/**
 * Kit de ferramentas editoriais.
 *
 * Companheiras do recorte editorial (inc/editorial-image-crop.php):
 *
 * 1. Foco da imagem destacada — a redação marca o ponto focal da capa e todos
 *    os cards/thumbnails do site enquadram a partir dele (object-position).
 * 2. Comparador Antes/Depois — bloco go/before-after com divisor arrastável
 *    entre duas imagens (remaster vs original, performance vs qualidade).
 * 3. Spoiler — bloco go/spoiler: o trecho fica fechado até o leitor tocar em
 *    "revelar"; usa <details>, então funciona sem JavaScript e com teclado.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/* -------------------------------------------------------------------------
 * 1) Foco da imagem destacada
 * ---------------------------------------------------------------------- */

/** Sanitize one focal coordinate: '' (unset) or a 0–100 float as string. */
function go_verge_tools_sanitize_focus( $value ) {
	$value = trim( (string) $value );
	if ( '' === $value ) {
		return '';
	}
	$number = (float) str_replace( ',', '.', $value );
	return (string) max( 0, min( 100, round( $number, 2 ) ) );
}

/** Register the focal-point meta for the editorial post types. */
function go_verge_tools_register_meta() {
	$auth = static function () {
		return current_user_can( 'edit_posts' );
	};

	foreach ( array( 'post', 'games', 'go_promotion' ) as $type ) {
		foreach ( array( '_go_thumb_focus_x', '_go_thumb_focus_y' ) as $key ) {
			register_post_meta(
				$type,
				$key,
				array(
					'type'              => 'string',
					'single'            => true,
					'default'           => '',
					'show_in_rest'      => true,
					'sanitize_callback' => 'go_verge_tools_sanitize_focus',
					'auth_callback'     => $auth,
				)
			);
		}
	}
}
add_action( 'init', 'go_verge_tools_register_meta', 9 );

/**
 * O editor só grava meta via REST quando o tipo suporta custom-fields; os CPTs
 * do tema não declaram esse suporte, então o painel de foco o adiciona aqui.
 */
function go_verge_tools_post_type_supports() {
	add_post_type_support( 'games', 'custom-fields' );
	add_post_type_support( 'go_promotion', 'custom-fields' );
}
add_action( 'init', 'go_verge_tools_post_type_supports', 11 );

/**
 * Apply the focal point to every featured-image render of the post.
 *
 * @param string $html Thumbnail HTML.
 * @param int    $post_id Post ID.
 * @return string
 */
function go_verge_tools_thumb_focus_html( $html, $post_id ) {
	if ( ! is_string( $html ) || '' === $html ) {
		return $html;
	}

	$x = get_post_meta( $post_id, '_go_thumb_focus_x', true );
	$y = get_post_meta( $post_id, '_go_thumb_focus_y', true );
	if ( '' === $x || '' === $y ) {
		return $html;
	}

	$style = sprintf(
		'object-position:%s%% %s%%;',
		go_verge_tools_sanitize_focus( $x ),
		go_verge_tools_sanitize_focus( $y )
	);

	if ( ! preg_match( '/<img\b[^>]*\/?>/i', $html, $match, PREG_OFFSET_CAPTURE ) ) {
		return $html;
	}
	$img_tag = $match[0][0];
	$offset  = (int) $match[0][1];

	if ( preg_match( '/\bstyle="([^"]*)"/i', $img_tag, $style_match ) ) {
		$new_img = str_replace(
			$style_match[0],
			'style="' . esc_attr( rtrim( $style_match[1], '; ' ) . ';' . $style ) . '"',
			$img_tag
		);
	} else {
		$new_img = preg_replace( '/<img\b/i', '<img style="' . esc_attr( $style ) . '"', $img_tag, 1 );
	}

	return substr_replace( $html, $new_img, $offset, strlen( $img_tag ) );
}
add_filter( 'post_thumbnail_html', 'go_verge_tools_thumb_focus_html', 12, 2 );

/* -------------------------------------------------------------------------
 * 2) Comparador Antes/Depois (bloco dinâmico go/before-after)
 * ---------------------------------------------------------------------- */

/** Shared frontend assets for the editorial blocks. */
function go_verge_tools_register_assets() {
	$css = '/assets/css/editorial-tools.css';
	$js  = '/assets/js/editorial-tools-frontend.js';
	wp_register_style(
		'go-editorial-tools',
		GO_VERGE_URI . $css,
		array(),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $css ) : null
	);
	wp_register_script(
		'go-editorial-tools',
		GO_VERGE_URI . $js,
		array(),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $js ) : null,
		true
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_tools_register_assets', 20 );

/** Blocos estáticos (spoiler, TL;DR, Ver na loja): CSS quando a página os contém. */
function go_verge_tools_maybe_enqueue_spoiler_css() {
	if ( ! is_singular() ) { return; }
	$post = get_queried_object();
	$legacy_store = $post instanceof WP_Post && false !== strpos( (string) $post->post_content, 'go-store-button' );
	// Also cover saved HTML and synced patterns, without traversing/querying every block.
	if ( $legacy_store || has_block( 'go/spoiler' ) || has_block( 'go/tldr' ) || has_block( 'go/store-button' ) || has_block( 'core/block' ) ) {
		wp_enqueue_style( 'go-editorial-tools' );
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_tools_maybe_enqueue_spoiler_css', 30 );

/** Register the dynamic blocks. */
function go_verge_tools_register_blocks() {
	register_block_type(
		'go/before-after',
		array(
			'api_version'     => 2,
			'attributes'      => array(
				'beforeId'    => array( 'type' => 'number', 'default' => 0 ),
				'afterId'     => array( 'type' => 'number', 'default' => 0 ),
				'beforeLabel' => array( 'type' => 'string', 'default' => 'Antes' ),
				'afterLabel'  => array( 'type' => 'string', 'default' => 'Depois' ),
				'caption'     => array( 'type' => 'string', 'default' => '' ),
			),
			'render_callback' => 'go_verge_tools_render_before_after',
		)
	);

	register_block_type(
		'go/cta',
		array(
			'api_version'     => 2,
			'attributes'      => array(
				'title'       => array( 'type' => 'string', 'default' => '' ),
				'text'        => array( 'type' => 'string', 'default' => '' ),
				'buttonLabel' => array( 'type' => 'string', 'default' => 'Saiba mais' ),
				'url'         => array( 'type' => 'string', 'default' => '' ),
				'icon'        => array( 'type' => 'string', 'default' => 'none' ),
				'variant'     => array( 'type' => 'string', 'default' => 'panel' ),
				'newTab'      => array( 'type' => 'boolean', 'default' => true ),
				'sponsored'   => array( 'type' => 'boolean', 'default' => false ),
			),
			'render_callback' => 'go_verge_tools_render_cta',
		)
	);
}
add_action( 'init', 'go_verge_tools_register_blocks', 20 );

/**
 * Ícones do CTA — SVGs enxutos herdando currentColor.
 *
 * @param string $icon Icon key.
 * @return string Inline SVG or ''.
 */
function go_verge_tools_cta_icon( $icon ) {
	$common = 'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"';
	$icons  = array(
		'news'     => '<path d="M5 5h11v14H6.5A1.5 1.5 0 0 1 5 17.5V5Zm11 3h2.5V17a2 2 0 0 1-2 2H16M7.5 8.5H13m-5.5 3.5H13m-5.5 3.5H11" ' . $common . '/>',
		'whatsapp' => '<path d="M12 4.5a7.5 7.5 0 0 0-6.45 11.33L4.5 19.5l3.8-1A7.5 7.5 0 1 0 12 4.5Zm-2.4 5.1c.2 1.9 2.9 4.6 4.8 4.8l1.1-1.1 1.7 1-.4 1.4c-3.4.7-8.5-4.4-7.8-7.8l1.4-.4 1 1.7-1.1 1.1Z" ' . $common . '/>',
		'youtube'  => '<rect x="4" y="6.5" width="16" height="11" rx="3" ' . $common . '/><path d="m10.5 9.75 4 2.25-4 2.25v-4.5Z" fill="currentColor" stroke="none"/>',
		'mail'     => '<rect x="4" y="6" width="16" height="12" rx="2" ' . $common . '/><path d="m5 7.5 7 5.5 7-5.5" ' . $common . '/>',
		'cart'     => '<path d="M4.5 6h2l1.6 9.2a1.5 1.5 0 0 0 1.5 1.3h6.9a1.5 1.5 0 0 0 1.5-1.2L19.5 9H7.1M10 20a.9.9 0 1 0 0-1.8.9.9 0 0 0 0 1.8Zm7 0a.9.9 0 1 0 0-1.8.9.9 0 0 0 0 1.8Z" ' . $common . '/>',
		'star'     => '<path d="m12 4.8 2.1 4.5 4.9.6-3.6 3.4.9 4.9-4.3-2.4-4.3 2.4.9-4.9L5 9.9l4.9-.6L12 4.8Z" ' . $common . '/>',
	);
	if ( ! isset( $icons[ $icon ] ) ) {
		return '';
	}
	return '<svg class="go-cta__icon" viewBox="0 0 24 24" width="26" height="26" aria-hidden="true">' . $icons[ $icon ] . '</svg>';
}

/**
 * Render the editorial CTA.
 *
 * @param array $attrs Block attributes.
 * @return string
 */
function go_verge_tools_render_cta( $attrs ) {
	$url = esc_url_raw( (string) ( $attrs['url'] ?? '' ) );
	if ( ! $url ) {
		return '';
	}

	$title     = sanitize_text_field( $attrs['title'] ?? '' );
	$text      = sanitize_text_field( $attrs['text'] ?? '' );
	$button    = sanitize_text_field( $attrs['buttonLabel'] ?? '' );
	$button    = '' !== $button ? $button : __( 'Saiba mais', 'go-verge' );
	$variant   = in_array( $attrs['variant'] ?? 'panel', array( 'panel', 'strip' ), true ) ? $attrs['variant'] : 'panel';
	$icon      = go_verge_tools_cta_icon( sanitize_key( $attrs['icon'] ?? 'none' ) );
	$sponsored = ! empty( $attrs['sponsored'] );
	$new_tab   = ! empty( $attrs['newTab'] );

	$rel = $sponsored ? 'sponsored nofollow noopener' : 'noopener';

	wp_enqueue_style( 'go-editorial-tools' );

	ob_start();
	?>
	<aside class="go-cta go-cta--<?php echo esc_attr( $variant ); ?>">
		<div class="go-cta__body">
			<?php echo $icon; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- static SVG built above. ?>
			<div class="go-cta__copy">
				<?php if ( $title ) : ?><strong class="go-cta__title"><?php echo esc_html( $title ); ?></strong><?php endif; ?>
				<?php if ( $text ) : ?><span class="go-cta__text"><?php echo esc_html( $text ); ?></span><?php endif; ?>
				<?php if ( $sponsored ) : ?><span class="go-cta__disclosure"><?php esc_html_e( 'link patrocinado', 'go-verge' ); ?></span><?php endif; ?>
			</div>
		</div>
		<a class="go-cta__button" href="<?php echo esc_url( $url ); ?>"<?php echo $new_tab ? ' target="_blank"' : ''; ?> rel="<?php echo esc_attr( $rel ); ?>">
			<?php echo esc_html( $button ); ?>
			<svg viewBox="0 0 20 20" width="16" height="16" aria-hidden="true"><path d="M4 10h11m-4-4 4 4-4 4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
		</a>
	</aside>
	<?php
	return trim( ob_get_clean() );
}

/**
 * Render the before/after comparator.
 *
 * @param array $attrs Block attributes.
 * @return string
 */
function go_verge_tools_render_before_after( $attrs ) {
	$before_id = absint( $attrs['beforeId'] ?? 0 );
	$after_id  = absint( $attrs['afterId'] ?? 0 );
	if ( ! $before_id || ! $after_id ) {
		return '';
	}

	$before = wp_get_attachment_image_src( $before_id, 'large' );
	$after  = wp_get_attachment_image_src( $after_id, 'large' );
	if ( ! $before || ! $after ) {
		return '';
	}

	$before_label = sanitize_text_field( $attrs['beforeLabel'] ?? 'Antes' );
	$after_label  = sanitize_text_field( $attrs['afterLabel'] ?? 'Depois' );
	$caption      = sanitize_text_field( $attrs['caption'] ?? '' );
	$ratio        = $before[2] > 0 ? $before[1] / $before[2] : 16 / 9;

	$before_alt = get_post_meta( $before_id, '_wp_attachment_image_alt', true );
	$after_alt  = get_post_meta( $after_id, '_wp_attachment_image_alt', true );

	// AMP não executa o slider: as duas imagens aparecem empilhadas.
	if ( function_exists( 'amp_is_request' ) && amp_is_request() ) {
		$html  = '<figure class="go-before-after-amp">';
		$html .= '<figure><img src="' . esc_url( $before[0] ) . '" alt="' . esc_attr( $before_alt ? $before_alt : $before_label ) . '" width="' . (int) $before[1] . '" height="' . (int) $before[2] . '"><figcaption>' . esc_html( $before_label ) . '</figcaption></figure>';
		$html .= '<figure><img src="' . esc_url( $after[0] ) . '" alt="' . esc_attr( $after_alt ? $after_alt : $after_label ) . '" width="' . (int) $after[1] . '" height="' . (int) $after[2] . '"><figcaption>' . esc_html( $after_label ) . '</figcaption></figure>';
		if ( $caption ) {
			$html .= '<figcaption>' . esc_html( $caption ) . '</figcaption>';
		}
		return $html . '</figure>';
	}

	wp_enqueue_style( 'go-editorial-tools' );
	wp_enqueue_script( 'go-editorial-tools' );

	$ratio_css = rtrim( rtrim( number_format( (float) $ratio, 4, '.', '' ), '0' ), '.' );

	ob_start();
	?>
	<figure class="go-before-after-wrap">
		<div class="go-before-after" data-go-before-after style="aspect-ratio:<?php echo esc_attr( $ratio_css ); ?>;">
			<img class="go-before-after__img" src="<?php echo esc_url( $before[0] ); ?>" alt="<?php echo esc_attr( $before_alt ? $before_alt : $before_label ); ?>" width="<?php echo esc_attr( (int) $before[1] ); ?>" height="<?php echo esc_attr( (int) $before[2] ); ?>" loading="lazy" decoding="async">
			<div class="go-before-after__top" aria-hidden="true">
				<img class="go-before-after__img" src="<?php echo esc_url( $after[0] ); ?>" alt="" width="<?php echo esc_attr( (int) $after[1] ); ?>" height="<?php echo esc_attr( (int) $after[2] ); ?>" loading="lazy" decoding="async" aria-hidden="true" data-go-decorative="1">
			</div>
			<span class="go-before-after__divider" aria-hidden="true"></span>
			<span class="go-before-after__label go-before-after__label--before" aria-hidden="true"><?php echo esc_html( $before_label ); ?></span>
			<span class="go-before-after__label go-before-after__label--after" aria-hidden="true"><?php echo esc_html( $after_label ); ?></span>
			<input class="go-before-after__range" type="range" min="0" max="100" step="0.1" value="50" aria-label="<?php echo esc_attr( sprintf( __( 'Comparar %1$s e %2$s', 'go-verge' ), $before_label, $after_label ) ); ?>">
		</div>
		<?php if ( $caption ) : ?>
			<figcaption class="go-before-after__caption"><?php echo esc_html( $caption ); ?></figcaption>
		<?php endif; ?>
	</figure>
	<?php
	return trim( ob_get_clean() );
}

/* -------------------------------------------------------------------------
 * 3) Editor: painel de foco + blocos
 * ---------------------------------------------------------------------- */

/* -------------------------------------------------------------------------
 * Legendas técnicas: "Version 1.0.0" e afins vêm de press kits e não são
 * legendas editoriais — somem do site sem apagar nada do banco.
 * ---------------------------------------------------------------------- */

/**
 * Whether a caption is just a version string.
 *
 * @param string $text Caption.
 * @return bool
 */
function go_verge_tools_is_version_caption( $text ) {
	$text = trim( wp_strip_all_tags( (string) $text ) );
	if ( '' === $text ) {
		return false;
	}
	return (bool) preg_match( '/^(?:v(?:ersion|ers[aã]o)?\.?\s*\d+(?:\.\d+)*|\d+(?:\.\d+)+)$/iu', $text );
}

/**
 * Detect captions that are really upload/file names rather than editorial text.
 * Keep this conservative: timestamps, common camera/screenshot names and an
 * explicit image extension are removed; normal prose remains untouched.
 *
 * @param string $text Caption text.
 * @return bool
 */
function go_verge_tools_is_filename_caption( $text ) {
	$text = trim( html_entity_decode( wp_strip_all_tags( (string) $text ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ) );
	if ( '' === $text ) {
		return false;
	}
	return (bool) preg_match(
		'/(?:\.(?:jpe?g|png|webp|avif|gif|heic)|[_\-\s]\d{8,16}|^(?:img|dsc|dscn|pxl|mvimg|screenshot|screen[-_ ]?shot|captura(?: de tela)?)[-_ ]?\d{3,})\s*$/iu',
		$text
	);
}

/**
 * Remove technical caption bodies while preserving a verified embedded credit.
 *
 * @param string $caption Caption.
 * @return string
 */
function go_verge_tools_clean_media_caption( $caption ) {
	$caption = trim( (string) $caption );
	if ( '' === $caption || go_verge_tools_is_version_caption( $caption ) ) {
		return '';
	}
	if ( function_exists( 'go_verge_image_split_caption_credit' ) ) {
		$parts  = go_verge_image_split_caption_credit( $caption );
		$body   = isset( $parts['text'] ) ? trim( (string) $parts['text'] ) : $caption;
		$credit = isset( $parts['credit'] ) ? trim( (string) $parts['credit'] ) : '';
		if ( go_verge_tools_is_filename_caption( $body ) ) {
			if ( '' !== $credit && function_exists( 'go_verge_image_format_caption' ) ) {
				return go_verge_image_format_caption( '', $credit );
			}
			return '';
		}
	} elseif ( go_verge_tools_is_filename_caption( $caption ) ) {
		return '';
	}
	return $caption;
}

/**
 * Strip technical figcaptions from rendered content without deleting real copy.
 *
 * @param string $content Post content.
 * @return string
 */
function go_verge_tools_strip_version_captions( $content ) {
	if ( ! is_string( $content ) || false === stripos( $content, '<figcaption' ) ) {
		return $content;
	}
	return preg_replace_callback(
		'/<figcaption\b([^>]*)>(.*?)<\/figcaption>/is',
		static function ( $match ) {
			$clean = go_verge_tools_clean_media_caption( $match[2] );
			if ( '' === $clean ) {
				return '';
			}
			$original_text = trim( wp_strip_all_tags( (string) $match[2] ) );
			if ( $clean === $original_text ) {
				return $match[0];
			}
			return '<figcaption' . $match[1] . '>' . esc_html( $clean ) . '</figcaption>';
		},
		$content
	);
}
add_filter( 'the_content', 'go_verge_tools_strip_version_captions', 25 );

/**
 * Apply the same cleanup to captions read directly from media attachments.
 *
 * @param string $caption Attachment caption.
 * @return string
 */
function go_verge_tools_filter_attachment_caption( $caption ) {
	return go_verge_tools_clean_media_caption( $caption );
}
add_filter( 'wp_get_attachment_caption', 'go_verge_tools_filter_attachment_caption' );

/** Enqueue the block editor UI for the toolkit. */
function go_verge_tools_editor_assets() {
	$rel = '/assets/js/editorial-tools.js';
	wp_enqueue_script(
		'go-editorial-tools-editor',
		GO_VERGE_URI . $rel,
		array( 'wp-hooks', 'wp-blocks', 'wp-element', 'wp-components', 'wp-block-editor', 'wp-compose', 'wp-data', 'wp-core-data', 'wp-plugins', 'wp-i18n' ),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $rel ) : GO_VERGE_VERSION,
		true
	);
}
add_action( 'enqueue_block_editor_assets', 'go_verge_tools_editor_assets' );
