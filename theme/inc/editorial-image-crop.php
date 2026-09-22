<?php
/**
 * Recorte editorial de imagens (estilo Multicontent).
 *
 * O bloco de imagem do editor ganha um botão "Recorte": a redação desenha o
 * retângulo sobre a própria foto e o recorte escolhido é exatamente o que a
 * matéria exibe. Nenhum arquivo novo é gerado — o recorte é matemático
 * (moldura com aspect-ratio + imagem deslocada), então trocar ou refazer o
 * recorte nunca degrada a original.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Format a float for CSS without locale surprises or trailing zeros. */
function go_verge_image_crop_css_number( $value ) {
	$formatted = rtrim( rtrim( number_format( (float) $value, 4, '.', '' ), '0' ), '.' );
	return '' === $formatted ? '0' : $formatted;
}

/**
 * Does the Image block carry an explicit Gutenberg aspect-ratio choice?
 * Plain pasted width/height attributes are source geometry, not crop intent.
 *
 * @param array $block Parsed block.
 * @return bool
 */
function go_verge_image_has_explicit_core_geometry( $block ) {
	$attrs = is_array( $block ) && isset( $block['attrs'] ) && is_array( $block['attrs'] ) ? $block['attrs'] : array();
	$ratio = isset( $attrs['aspectRatio'] ) ? trim( (string) $attrs['aspectRatio'] ) : '';
	if ( '' !== $ratio && 'auto' !== strtolower( $ratio ) ) {
		return true;
	}

	$style_ratio = '';
	if ( isset( $attrs['style']['dimensions']['aspectRatio'] ) ) {
		$style_ratio = trim( (string) $attrs['style']['dimensions']['aspectRatio'] );
	}
	return '' !== $style_ratio && 'auto' !== strtolower( $style_ratio );
}

/**
 * Stamp an image whose geometry is intentional so the late pasted-image repair
 * does not reset its height/aspect-ratio.
 *
 * @param string $img_tag Image tag.
 * @param string $kind    core|crop|frame.
 * @return string
 */
function go_verge_image_mark_geometry( $img_tag, $kind = 'core' ) {
	$kind = in_array( $kind, array( 'core', 'crop', 'frame' ), true ) ? $kind : 'core';
	if ( preg_match( '/\bdata-go-image-geometry="[^"]*"/i', $img_tag ) ) {
		return preg_replace( '/\bdata-go-image-geometry="[^"]*"/i', 'data-go-image-geometry="' . esc_attr( $kind ) . '"', $img_tag, 1 );
	}
	return preg_replace( '/<img\b/i', '<img data-go-image-geometry="' . esc_attr( $kind ) . '"', $img_tag, 1 );
}

/**
 * Aplica o estilo do recorte/quadro à <img>, removendo antes as propriedades
 * de dimensionamento que o editor deixa inline (width/height/aspect-ratio em
 * blocos "is-resized"). Sem essa limpeza, o aspect-ratio antigo brigava com o
 * recorte e deixava a foto torta com um vão vazio embaixo.
 *
 * @param string $img_tag   Tag <img> original.
 * @param string $new_style Estilo do recorte a aplicar.
 * @return string
 */
function go_verge_image_merge_img_style( $img_tag, $new_style ) {
	if ( preg_match( '/\bstyle="([^"]*)"/i', $img_tag, $m ) ) {
		$existing = preg_replace( '/\b(?:width|height|aspect-ratio|max-width|min-width|min-height|object-fit|object-position)\s*:[^;]*;?/i', '', $m[1] );
		$existing = trim( $existing, "; \t" );
		$merged   = ( '' !== $existing ? $existing . ';' : '' ) . $new_style;
		return str_replace( $m[0], 'style="' . esc_attr( $merged ) . '"', $img_tag );
	}
	return preg_replace( '/<img\b/i', '<img style="' . esc_attr( $new_style ) . '"', $img_tag, 1 );
}

/** Enqueue the block editor UI. */
function go_verge_image_crop_editor_assets() {
	$rel = '/assets/js/editorial-image-crop.js';
	wp_enqueue_script(
		'go-editorial-image-crop',
		GO_VERGE_URI . $rel,
		array( 'wp-hooks', 'wp-blocks', 'wp-element', 'wp-components', 'wp-block-editor', 'wp-compose', 'wp-i18n', 'wp-data' ),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $rel ) : GO_VERGE_VERSION,
		true
	);
}
add_action( 'enqueue_block_editor_assets', 'go_verge_image_crop_editor_assets' );

/**
 * Validate the stored crop attribute.
 *
 * @param mixed $crop Raw attribute.
 * @return array|null Normalized crop or null when absent/invalid.
 */
function go_verge_image_crop_normalize( $crop ) {
	if ( ! is_array( $crop ) ) {
		return null;
	}

	$x     = isset( $crop['x'] ) ? (float) $crop['x'] : -1;
	$y     = isset( $crop['y'] ) ? (float) $crop['y'] : -1;
	$w     = isset( $crop['w'] ) ? (float) $crop['w'] : 0;
	$h     = isset( $crop['h'] ) ? (float) $crop['h'] : 0;
	$ratio = isset( $crop['ratio'] ) ? (float) $crop['ratio'] : 0;

	if ( $x < 0 || $y < 0 || $w < 1 || $h < 1 || $ratio < 0.05 || $ratio > 20 ) {
		return null;
	}
	if ( $x + $w > 100.5 || $y + $h > 100.5 || $w > 100 || $h > 100 ) {
		return null;
	}
	// Full-frame selection means "no crop".
	if ( $w >= 99.5 && $h >= 99.5 ) {
		return null;
	}

	return array(
		'x'     => min( $x, 100 - $w ),
		'y'     => min( $y, 100 - $h ),
		'w'     => $w,
		'h'     => $h,
		'ratio' => $ratio,
	);
}

/**
 * Validate the stored frame attribute ("quadro": moldura com proporção fixa
 * que exibe a imagem INTEIRA — o oposto do recorte). Usada para fotos de
 * produto em pé/quadradas que precisam ocupar um cartão 16:9 sem corte.
 *
 * @param mixed $frame Raw attribute.
 * @return array|null Normalized frame or null when absent/invalid.
 */
function go_verge_image_frame_normalize( $frame ) {
	if ( ! is_array( $frame ) ) {
		return null;
	}

	$ratios = array(
		'16x9' => '16 / 9',
		'4x3'  => '4 / 3',
		'1x1'  => '1 / 1',
		'3x2'  => '3 / 2',
	);
	$ratio = (string) ( $frame['ratio'] ?? '' );
	$bg    = (string) ( $frame['bg'] ?? '' );

	if ( ! isset( $ratios[ $ratio ] ) || ! in_array( $bg, array( 'white', 'surface', 'blur' ), true ) ) {
		return null;
	}

	return array(
		'ratio_css' => $ratios[ $ratio ],
		'bg'        => $bg,
	);
}

/**
 * The crop rectangle's TRUE pixel aspect ratio, recovered from the image itself.
 *
 * `w` and `h` are percentages of two different denominators, so the rectangle's
 * shape is (w*W)/(h*H) and NOT w/h. The stored `ratio` is supposed to be that
 * number, but two sources of drift exist in already-published posts:
 *
 *   - crops written before this build hardcoded 1.7778 for every automatic 16:9,
 *     while the rectangle they actually stored was rounded to two decimals;
 *   - `ratio` was computed from the unrounded rectangle and then the rectangle
 *     was rounded, so the two disagreed slightly.
 *
 * That matters because `object-view-box` selects the rectangle and `object-fit:
 * cover` then fits it into a box of `aspect-ratio: ratio`. When the two ratios
 * differ, cover silently trims a sliver the editor never showed -- a small,
 * permanent divergence between preview and page. Re-deriving the ratio from the
 * image's own dimensions makes cover a no-op, which is the only state in which
 * the published framing is provably the drawn framing.
 *
 * Dimensions come from the width/height the image block already prints, so the
 * common path costs no query; attachment metadata is only consulted when the
 * markup carries no dimensions.
 *
 * @param array  $crop          Normalized crop.
 * @param string $img_tag       The matched <img> tag.
 * @param int    $attachment_id Block attachment id, 0 when unknown.
 * @return float Ratio to render with.
 */
function go_verge_image_crop_true_ratio( $crop, $img_tag, $attachment_id = 0 ) {
	$width  = 0;
	$height = 0;
	if ( preg_match( '/\bwidth="(\d+)"/i', $img_tag, $m ) ) { $width = (int) $m[1]; }
	if ( preg_match( '/\bheight="(\d+)"/i', $img_tag, $m ) ) { $height = (int) $m[1]; }

	if ( ( $width < 1 || $height < 1 ) && $attachment_id > 0 && function_exists( 'wp_get_attachment_metadata' ) ) {
		$meta = wp_get_attachment_metadata( $attachment_id );
		if ( is_array( $meta ) ) {
			$width  = (int) ( $meta['width'] ?? 0 );
			$height = (int) ( $meta['height'] ?? 0 );
		}
	}
	if ( $width < 1 || $height < 1 ) {
		return (float) $crop['ratio'];
	}

	$rect_w = ( $crop['w'] / 100 ) * $width;
	$rect_h = ( $crop['h'] / 100 ) * $height;
	if ( $rect_h <= 0 ) {
		return (float) $crop['ratio'];
	}
	$true = $rect_w / $rect_h;

	/* Out-of-range means the dimensions are not describing this image; keep what
	 * the editor stored rather than inventing a frame. */
	return ( $true >= 0.05 && $true <= 20 ) ? $true : (float) $crop['ratio'];
}

/**
 * Render the exact crop on the public article.
 *
 * A moldura define a proporção do recorte; a imagem é ampliada e deslocada de
 * modo que a janela visível seja exatamente o retângulo desenhado no editor.
 * Puro CSS — funciona em qualquer navegador e preserva srcset/lazy-loading.
 *
 * @param string $block_content Rendered block HTML.
 * @param array  $block         Parsed block.
 * @return string
 */
function go_verge_image_crop_render_block( $block_content, $block ) {
	$crop          = go_verge_image_crop_normalize( $block['attrs']['goCrop'] ?? null );
	$frame         = null === $crop ? go_verge_image_frame_normalize( $block['attrs']['goFrame'] ?? null ) : null;
	$core_geometry = null === $crop && null === $frame && go_verge_image_has_explicit_core_geometry( $block );
	if ( ! is_string( $block_content ) || '' === $block_content ) {
		return $block_content;
	}
	if ( null === $crop && null === $frame && ! $core_geometry ) {
		return $block_content;
	}

	// AMP converte <img> em <amp-img> com regras próprias de layout; lá a foto
	// aparece inteira em vez de arriscar um recorte quebrado.
	if ( function_exists( 'amp_is_request' ) && amp_is_request() ) {
		return $block_content;
	}

	if ( ! preg_match( '/<img\b[^>]*\/?>/i', $block_content, $match, PREG_OFFSET_CAPTURE ) ) {
		return $block_content;
	}
	$img_tag = $match[0][0];
	$offset  = (int) $match[0][1];

	if ( $core_geometry ) {
		$new_img = go_verge_image_mark_geometry( $img_tag, 'core' );
		return substr_replace( $block_content, $new_img, $offset, strlen( $img_tag ) );
	}

	if ( null !== $frame ) {
		return go_verge_image_frame_wrap( $block_content, $img_tag, $offset, $frame );
	}

	/*
	 * CSS IDÊNTICO ao preview do editor (assets/js/editorial-image-crop.js), o
	 * que faz o enquadramento publicado ser o enquadramento desenhado.
	 *
	 * `object-view-box` seleciona o retângulo exato e `aspect-ratio` recebe a
	 * proporção REAL desse retângulo, então `object-fit: cover` não tem nada
	 * para aparar — essa igualdade é o que torna o resultado determinístico.
	 *
	 * Suporte a `object-view-box`, com precisão: Chrome/Edge 104+ e Safari 16+.
	 * O Firefox ainda NÃO implementou (bug 1770054). Lá a regra é ignorada e
	 * sobram `object-fit: cover` + `object-position`, que reproduzem o mesmo
	 * retângulo **apenas quando o recorte ocupa 100% de um dos eixos** — que é
	 * o caso de todos os recortes automáticos (o 16:9 da barra, o 16:9 em lote e
	 * os presets de proporção sempre preservam um eixo inteiro). Só um arrasto
	 * manual em dois eixos difere, e difere igual no editor e no site, porque as
	 * duas declarações são a mesma. Não embrulhe a <img> para resolver isso:
	 * placements in-article do Auto Ads são ancorados por caminho DOM e existem
	 * âncoras FIGURE>IMG neste tema.
	 */
	$num   = 'go_verge_image_crop_css_number';
	$pos_x = $crop['w'] < 100 ? ( $crop['x'] / ( 100 - $crop['w'] ) ) * 100 : 50;
	$pos_y = $crop['h'] < 100 ? ( $crop['y'] / ( 100 - $crop['h'] ) ) * 100 : 50;
	$ratio = go_verge_image_crop_true_ratio( $crop, $img_tag, absint( $block['attrs']['id'] ?? 0 ) );

	/* Declaration-for-declaration identical to the editor preview in
	 * assets/js/editorial-image-crop.js. Any divergence is a WYSIWYG bug. */
	$img_style = sprintf(
		'display:block;width:100%%;height:auto;max-width:100%%;min-width:0;aspect-ratio:%s;object-fit:cover;object-position:%s%% %s%%;object-view-box:inset(%s%% %s%% %s%% %s%%);border-radius:6px;margin:0;',
		$num( $ratio ),
		$num( $pos_x ),
		$num( $pos_y ),
		$num( $crop['y'] ),
		$num( 100 - $crop['x'] - $crop['w'] ),
		$num( 100 - $crop['y'] - $crop['h'] ),
		$num( $crop['x'] )
	);

	$new_img = go_verge_image_mark_geometry( go_verge_image_merge_img_style( $img_tag, $img_style ), 'crop' );

	return substr_replace( $block_content, $new_img, $offset, strlen( $img_tag ) );
}
add_filter( 'render_block_core/image', 'go_verge_image_crop_render_block', 10, 2 );

/**
 * Wrap the image in a fixed-ratio frame that shows the WHOLE picture.
 *
 * @param string $block_content Block HTML.
 * @param string $img_tag       Matched <img> tag.
 * @param int    $offset        Tag offset inside the HTML.
 * @param array  $frame         Normalized frame (ratio_css, bg).
 * @return string
 */
function go_verge_image_frame_wrap( $block_content, $img_tag, $offset, $frame ) {
	$wrapper_style = 'display:block;position:relative;width:100%;overflow:hidden;border-radius:10px;aspect-ratio:' . $frame['ratio_css'] . ';';
	$bg_layer      = '';

	if ( 'white' === $frame['bg'] ) {
		$wrapper_style .= 'background:#ffffff;border:1px solid rgba(18,18,18,.08);';
	} elseif ( 'surface' === $frame['bg'] ) {
		$wrapper_style .= 'background:var(--slate,#181919);border:1px solid var(--border,rgba(255,255,255,.09));';
	} else { // blur: a própria foto, ampliada e desfocada, preenche as bordas.
		$wrapper_style .= 'background:#101010;';
		if ( preg_match( '/\bsrc="([^"]+)"/i', $img_tag, $src_match ) ) {
			$bg_layer = '<img aria-hidden="true" alt="" src="' . esc_url( $src_match[1] ) . '" loading="lazy" decoding="async" style="' . esc_attr( 'position:absolute;inset:0;width:100%;height:100%;object-fit:cover;margin:0;filter:blur(26px) saturate(1.15);opacity:.5;transform:scale(1.15);' ) . '">';
		}
	}

	$img_style = 'position:absolute;inset:0;width:100%;height:100%;max-width:none;aspect-ratio:auto;object-fit:contain;margin:0;padding:14px;box-sizing:border-box;';

	$new_img = go_verge_image_mark_geometry( go_verge_image_merge_img_style( $img_tag, $img_style ), 'frame' );

	$replacement = '<span class="go-image-frame go-image-frame--' . esc_attr( $frame['bg'] ) . '" style="' . esc_attr( $wrapper_style ) . '">' . $bg_layer . $new_img . '</span>';

	return substr_replace( $block_content, $replacement, $offset, strlen( $img_tag ) );
}
