<?php
/**
 * Automatic image alternative text.
 *
 * Every image should carry a real description: it is what a screen reader
 * announces, what Google Images indexes, and what appears when the file fails
 * to load. A large part of the archive was published with an empty `alt`.
 *
 * The order below is deliberate. Alt text is an accessibility feature first and
 * an SEO signal second, so anything the editor actually wrote about the image
 * wins over a generic phrase. The focus keyphrase is the last resort, never the
 * first choice — repeating one keyword across every image on a page is keyword
 * stuffing, and Google treats it as such.
 *
 *   1. the alt already stored on the attachment
 *   2. the attachment caption
 *   3. the attachment title, when it is not just a file name
 *   4. the post title as a last-resort contextual fallback
 *
 * Disable with: add_filter( 'go_verge_auto_image_alt_enabled', '__return_false' );
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Whether the automatic description may run.
 *
 * @return bool
 */
function go_verge_auto_image_alt_enabled() {
	return (bool) apply_filters( 'go_verge_auto_image_alt_enabled', ! is_admin() );
}

/**
 * Reject titles that are really file names: "IMG_2931", "capa-fc27-1024x576".
 *
 * @param string $title Attachment title.
 * @return bool
 */
function go_verge_title_looks_like_filename( $title ) {
	$title = trim( (string) $title );
	if ( '' === $title ) {
		return true;
	}
	if ( preg_match( '/^(?:img|dsc|dscn|pxl|screenshot|scaled|image|foto|photo)[\s_-]*\d+/i', $title ) ) {
		return true;
	}
	if ( preg_match( '/\.(?:jpe?g|png|gif|webp|avif)$/i', $title ) ) {
		return true;
	}
	// A single hyphenated token with digits and no spaces is almost always a slug.
	if ( ! preg_match( '/\s/', $title ) && preg_match( '/[-_]\d|\d[-_]/', $title ) ) {
		return true;
	}

	return false;
}

/**
 * Primary focus keyphrase of a post, when an SEO plugin stores one.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_post_focus_keyphrase( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$keyphrase = '';
	foreach ( array( 'rank_math_focus_keyword', '_yoast_wpseo_focuskw' ) as $meta_key ) {
		$stored = get_post_meta( $post_id, $meta_key, true );
		if ( is_string( $stored ) && '' !== trim( $stored ) ) {
			// Rank Math stores a comma-separated list; the first one is primary.
			$parts     = explode( ',', $stored );
			$keyphrase = trim( (string) $parts[0] );
			break;
		}
	}

	return (string) apply_filters( 'go_verge_post_focus_keyphrase', $keyphrase, $post_id );
}

/**
 * Build one description for an attachment used inside a given post.
 *
 * @param int $attachment_id Attachment ID.
 * @param int $post_id       Post the image illustrates.
 * @return string
 */
function go_verge_image_description( $attachment_id, $post_id = 0 ) {
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id ) {
		return '';
	}

	$caption = wp_get_attachment_caption( $attachment_id );
	if ( is_string( $caption ) && '' !== trim( $caption ) ) {
		return trim( wp_strip_all_tags( $caption ) );
	}

	$attachment = get_post( $attachment_id );
	if ( $attachment instanceof WP_Post && ! go_verge_title_looks_like_filename( $attachment->post_title ) ) {
		return trim( $attachment->post_title );
	}

	$post_id = $post_id ? absint( $post_id ) : absint( get_queried_object_id() );
	if ( ! $post_id ) {
		return '';
	}

	// Do not auto-fill alt text with the SEO focus phrase. Alt is primarily an
	// image description; repeating a keyword that does not describe the actual
	// visual is worse for accessibility and image understanding.
	$title = get_the_title( $post_id );

	return is_string( $title ) ? trim( wp_strip_all_tags( $title ) ) : '';
}

/**
 * Fill an empty alt on any image rendered through the media API.
 *
 * The `title` attribute is deliberately NOT set. A title duplicating the alt
 * makes screen readers announce the same sentence twice and adds a tooltip
 * nobody asked for; it is not a ranking factor.
 *
 * @param array<string,string> $attr       Image attributes.
 * @param WP_Post              $attachment Attachment post.
 * @return array<string,string>
 */
function go_verge_auto_image_alt( $attr, $attachment ) {
	if ( ! go_verge_auto_image_alt_enabled() ) {
		return $attr;
	}
	if ( isset( $attr['alt'] ) && '' !== trim( (string) $attr['alt'] ) ) {
		return $attr;
	}
	if ( ! ( $attachment instanceof WP_Post ) ) {
		return $attr;
	}

	/*
	 * A decorative image must keep an empty alt so assistive technology skips
	 * it. Only images that carry meaning get a description.
	 */
	if ( ( ! empty( $attr['role'] ) && 'presentation' === strtolower( (string) $attr['role'] ) )
		|| ( isset( $attr['aria-hidden'] ) && 'true' === strtolower( (string) $attr['aria-hidden'] ) )
		|| ! empty( $attr['data-go-decorative'] ) ) {
		return $attr;
	}

	$parent      = absint( $attachment->post_parent );
	$description = go_verge_image_description( $attachment->ID, $parent ? $parent : 0 );
	if ( '' !== $description ) {
		$attr['alt'] = esc_attr( $description );
	}

	return $attr;
}
add_filter( 'wp_get_attachment_image_attributes', 'go_verge_auto_image_alt', 30, 2 );

/**
 * Fill empty alt attributes inside stored post content.
 *
 * Classic-editor and imported articles carry raw <img alt=""> that never passes
 * through the media API, so the filter above cannot reach them.
 *
 * @param string $content Rendered content.
 * @return string
 */
function go_verge_auto_content_image_alt( $content ) {
	if ( ! go_verge_auto_image_alt_enabled() || ! is_string( $content ) || false === strpos( $content, '<img' ) ) {
		return $content;
	}
	if ( ! is_singular() || ! in_the_loop() || ! is_main_query() ) {
		return $content;
	}

	$post_id  = absint( get_queried_object_id() );
	$fallback = '';

	return preg_replace_callback(
		'/<img\b[^>]*>/i',
		static function ( $matches ) use ( $post_id, &$fallback ) {
			$tag = $matches[0];

			/* Explicitly decorative images must stay silent to assistive
			 * technology, even when legacy content contains alt="". */
			if ( preg_match( '/\brole\s*=\s*(["\'])presentation\1/i', $tag )
				|| preg_match( '/\baria-hidden\s*=\s*(["\'])true\1/i', $tag )
				|| preg_match( '/\bdata-go-decorative(?:\s*=|\s|>)/i', $tag ) ) {
				return $tag;
			}

			// Leave a real description alone.
			if ( preg_match( '/\balt\s*=\s*(["\'])(.*?)\1/is', $tag, $alt ) && '' !== trim( $alt[2] ) ) {
				return $tag;
			}

			$description = '';
			if ( preg_match( '/wp-image-(\d+)/i', $tag, $id ) ) {
				$description = go_verge_image_description( (int) $id[1], $post_id );
			}
			if ( '' === $description ) {
				if ( '' === $fallback ) {
					$fallback = trim( wp_strip_all_tags( (string) get_the_title( $post_id ) ) );
				}
				$description = $fallback;
			}
			if ( '' === $description ) {
				return $tag;
			}

			$value = ' alt="' . esc_attr( $description ) . '"';

			return isset( $alt[0] )
				? str_replace( $alt[0], trim( $value ), $tag )
				: preg_replace( '/<img\b/i', '<img' . $value, $tag, 1 );
		},
		$content
	);
}
add_filter( 'the_content', 'go_verge_auto_content_image_alt', 12 );

/**
 * Persist the description on the attachment when a post is saved.
 *
 * The runtime filters above fix what readers and crawlers see immediately. This
 * writes the same value into the media library so the fix survives outside the
 * theme — in feeds, in the REST API and in any future theme.
 *
 * @param int $post_id Saved post ID.
 * @return void
 */
function go_verge_persist_featured_image_alt( $post_id ) {
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}

	$thumbnail_id = get_post_thumbnail_id( $post_id );
	if ( ! $thumbnail_id ) {
		return;
	}

	$existing = get_post_meta( $thumbnail_id, '_wp_attachment_image_alt', true );
	if ( is_string( $existing ) && '' !== trim( $existing ) ) {
		return;
	}

	$description = go_verge_image_description( $thumbnail_id, $post_id );
	if ( '' !== $description ) {
		update_post_meta( $thumbnail_id, '_wp_attachment_image_alt', wp_strip_all_tags( $description ) );
	}
}
add_action( 'save_post', 'go_verge_persist_featured_image_alt', 20 );
