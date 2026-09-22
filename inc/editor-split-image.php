<?php
/**
 * Side-by-side comparison image block for article bodies.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Render the split-image block and shortcode. */
function go_verge_render_split_image( $attributes ) {
	$attributes = shortcode_atts(
		array(
			'leftId'     => 0,
			'rightId'    => 0,
			'leftLabel'  => '',
			'rightLabel' => '',
			'caption'    => '',
			'left'       => 0,
			'right'      => 0,
			'left_label' => '',
			'right_label'=> '',
		),
		(array) $attributes,
		'go_split_image'
	);

	$left_id     = absint( $attributes['leftId'] ?: $attributes['left'] );
	$right_id    = absint( $attributes['rightId'] ?: $attributes['right'] );
	$left_label  = sanitize_text_field( $attributes['leftLabel'] ?: $attributes['left_label'] );
	$right_label = sanitize_text_field( $attributes['rightLabel'] ?: $attributes['right_label'] );
	$caption     = sanitize_text_field( $attributes['caption'] );

	if ( ! $left_id || ! $right_id ) {
		return '';
	}

	$image_args = array(
		'loading'  => 'lazy',
		'decoding' => 'async',
		'sizes'    => '(max-width: 760px) 50vw, 380px',
	);
	$left_image  = wp_get_attachment_image( $left_id, 'large', false, $image_args );
	$right_image = wp_get_attachment_image( $right_id, 'large', false, $image_args );
	if ( ! $left_image || ! $right_image ) {
		return '';
	}

	ob_start();
	?>
	<figure class="go-split-image" data-go-split-image>
		<div class="go-split-image__canvas">
			<div class="go-split-image__side go-split-image__side--left">
				<?php echo $left_image; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php if ( $left_label ) : ?><span class="go-split-image__label"><?php echo esc_html( $left_label ); ?></span><?php endif; ?>
			</div>
			<div class="go-split-image__side go-split-image__side--right">
				<?php echo $right_image; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php if ( $right_label ) : ?><span class="go-split-image__label"><?php echo esc_html( $right_label ); ?></span><?php endif; ?>
			</div>
		</div>
		<?php if ( $caption ) : ?><figcaption><?php echo esc_html( $caption ); ?></figcaption><?php endif; ?>
	</figure>
	<?php
	return trim( (string) ob_get_clean() );
}

/** Shortcode fallback for the Classic Editor. */
function go_verge_split_image_shortcode( $atts ) {
	return go_verge_render_split_image( (array) $atts );
}
add_shortcode( 'go_split_image', 'go_verge_split_image_shortcode' );

/** Register Gutenberg block and assets. */
function go_verge_register_split_image_block() {
	$script_rel = '/assets/js/editor-split-image.js';
	$style_rel  = '/assets/css/split-image.css';

	wp_register_script(
		'go-verge-split-image-editor',
		GO_VERGE_URI . $script_rel,
		array( 'wp-blocks', 'wp-element', 'wp-components', 'wp-block-editor', 'wp-i18n' ),
		go_verge_asset_version( $script_rel ),
		true
	);
	wp_register_style(
		'go-verge-split-image',
		GO_VERGE_URI . $style_rel,
		array(),
		go_verge_asset_version( $style_rel )
	);

	register_block_type(
		'go-verge/split-image',
		array(
			'api_version'     => 2,
			'editor_script'   => 'go-verge-split-image-editor',
			'style'           => 'go-verge-split-image',
			'editor_style'    => 'go-verge-split-image',
			'render_callback' => 'go_verge_render_split_image',
			'attributes'      => array(
				'leftId'     => array( 'type' => 'number', 'default' => 0 ),
				'leftUrl'    => array( 'type' => 'string', 'default' => '' ),
				'rightId'    => array( 'type' => 'number', 'default' => 0 ),
				'rightUrl'   => array( 'type' => 'string', 'default' => '' ),
				'leftLabel'  => array( 'type' => 'string', 'default' => '' ),
				'rightLabel' => array( 'type' => 'string', 'default' => '' ),
				'caption'    => array( 'type' => 'string', 'default' => '' ),
			),
		)
	);
}
add_action( 'init', 'go_verge_register_split_image_block' );

/** Add a Classic Editor insertion button. */
function go_verge_split_image_media_button( $editor_id ) {
	if ( 'content' !== $editor_id || ! current_user_can( 'upload_files' ) ) {
		return;
	}
	printf(
		'<button type="button" class="button go-split-image-insert" data-go-split-image-insert><span class="dashicons dashicons-images-alt2" style="vertical-align:text-bottom"></span> %s</button>',
		esc_html__( 'Imagem meio a meio', 'go-verge' )
	);
}
add_action( 'media_buttons', 'go_verge_split_image_media_button', 20 );

/** Load the Classic Editor media workflow only on post editing screens. */
function go_verge_split_image_classic_assets( $hook ) {
	if ( ! in_array( $hook, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = get_current_screen();
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}
	wp_enqueue_media();
	$rel = '/assets/js/editor-split-image-classic.js';
	wp_enqueue_script( 'go-verge-split-image-classic', GO_VERGE_URI . $rel, array( 'jquery' ), go_verge_asset_version( $rel ), true );
}
add_action( 'admin_enqueue_scripts', 'go_verge_split_image_classic_assets' );

/** Ensure shortcode output receives the same front-end styling. */
function go_verge_enqueue_split_image_front_style() {
	if ( ! is_singular( 'post' ) ) {
		return;
	}

	$post = get_queried_object();
	if ( ! ( $post instanceof WP_Post ) ) {
		return;
	}

	$content = (string) $post->post_content;
	$uses_block = function_exists( 'has_block' ) && has_block( 'go-verge/split-image', $post );
	$uses_shortcode = function_exists( 'has_shortcode' ) && has_shortcode( $content, 'go_split_image' );
	if ( ! $uses_block && ! $uses_shortcode ) {
		return;
	}

	wp_enqueue_style( 'go-verge-split-image' );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_split_image_front_style', 1705 );
