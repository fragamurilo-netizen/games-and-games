<?php
/**
 * Automatic intelligent internal linking.
 *
 * On single articles, the first mention of a known game (Games CPT) or entity
 * (go_entity: platform / developer / publisher) is turned into a link to that
 * hub. This builds the topical entity graph search + answer engines reward,
 * with zero editor effort.
 *
 * Safe by construction: a real HTML parser (DOMDocument) walks only text
 * nodes, never touching existing links, headings, code, captions or markup.
 * Each keyword and each destination is used at most once, capped per article.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_IL_TRANSIENT' ) ) {
	define( 'GO_VERGE_IL_TRANSIENT', 'go_verge_internal_link_map_v1' );
}
if ( ! defined( 'GO_VERGE_IL_MAX_LINKS' ) ) {
	define( 'GO_VERGE_IL_MAX_LINKS', 6 );
}

/**
 * Build (and cache) the keyword → URL map from the Games and go_entity CPTs,
 * sorted longest-first so specific titles win over substrings.
 *
 * @return array<int, array{kw:string,url:string,id:int}>
 */
function go_verge_internal_link_map() {
	$cached = get_transient( GO_VERGE_IL_TRANSIENT );
	if ( is_array( $cached ) ) {
		return $cached;
	}

	$map        = array();
	$post_types = array_values( array_filter( array( 'productions', 'games', 'go_entity' ), 'post_type_exists' ) );

	if ( ! empty( $post_types ) ) {
		$items = get_posts(
			array(
				'post_type'              => $post_types,
				'post_status'            => 'publish',
				'posts_per_page'         => 500,
				'orderby'                => 'title',
				'order'                  => 'ASC',
				'no_found_rows'          => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
			)
		);

		$by_key = array();
		foreach ( $items as $item ) {
			$title = trim( wp_strip_all_tags( get_the_title( $item ) ) );
			$key   = function_exists( 'go_verge_v27_entity_key' ) ? go_verge_v27_entity_key( $title ) : mb_strtolower( remove_accents( $title ) );

			// Skip very short or numeric titles to avoid noisy automatic links.
			if ( mb_strlen( $title ) < 4 || is_numeric( $title ) || '' === $key ) {
				continue;
			}
			$url = get_permalink( $item );
			if ( ! $url ) {
				continue;
			}
			if ( ! isset( $by_key[ $key ] ) ) { $by_key[ $key ] = array(); }
			$by_key[ $key ][] = array( 'kw' => $title, 'url' => $url, 'id' => (int) $item->ID );
		}

		/* If the same exact label points to more than one first-class hub
		 * (for example a game and its TV adaptation), do not auto-link the
		 * phrase at all. Contextual/manual linking can disambiguate it safely. */
		foreach ( $by_key as $entries ) {
			if ( 1 === count( $entries ) ) { $map[] = reset( $entries ); }
		}
	}

	// Longest keyword first.
	usort(
		$map,
		static function ( $a, $b ) {
			return mb_strlen( $b['kw'] ) - mb_strlen( $a['kw'] );
		}
	);

	set_transient( GO_VERGE_IL_TRANSIENT, $map, 12 * HOUR_IN_SECONDS );
	return $map;
}

/**
 * Rebuild the map whenever a game/entity changes.
 */
function go_verge_internal_link_bust() {
	delete_transient( GO_VERGE_IL_TRANSIENT );
}
add_action( 'save_post_games', 'go_verge_internal_link_bust' );
add_action( 'save_post_go_entity', 'go_verge_internal_link_bust' );
add_action( 'deleted_post', 'go_verge_internal_link_bust' );

/**
 * Normalize typographic variants (curly quotes, apostrophes, dashes) to their
 * ASCII forms. Each replacement is one character → one character so character
 * indices stay aligned with the original string.
 *
 * @param string $s Input string.
 * @return string
 */
function go_verge_il_normalize( $s ) {
	return strtr(
		(string) $s,
		array(
			'’' => "'", '‘' => "'", '‚' => "'", '‛' => "'", '´' => "'", '`' => "'",
			'“' => '"', '”' => '"', '„' => '"',
			'–' => '-', '—' => '-', '‑' => '-',
		)
	);
}

/**
 * Case-insensitive, word-boundary-aware, typography-tolerant search.
 *
 * Matching happens on normalized copies (so "Dragon’s" matches "Dragon's"),
 * but the returned offset is a byte position in the ORIGINAL haystack so the
 * DOM split stays exact.
 *
 * @param string $haystack Original text to search.
 * @param string $needle   Keyword.
 * @return int|false Byte offset in $haystack, or false.
 */
function go_verge_il_find( $haystack, $needle ) {
	$n_hay    = go_verge_il_normalize( $haystack );
	$n_needle = go_verge_il_normalize( $needle );
	$needle_len = mb_strlen( $n_needle, 'UTF-8' );
	$offset   = 0;

	while ( true ) {
		$pos = mb_stripos( $n_hay, $n_needle, $offset, 'UTF-8' );
		if ( false === $pos ) {
			return false;
		}
		$before     = $pos > 0 ? mb_substr( $n_hay, $pos - 1, 1, 'UTF-8' ) : '';
		$after       = mb_substr( $n_hay, $pos + $needle_len, 1, 'UTF-8' );
		$bad_before = ( '' !== $before && preg_match( '/[\p{L}\p{N}]/u', $before ) );
		$bad_after  = ( '' !== $after && preg_match( '/[\p{L}\p{N}]/u', $after ) );

		if ( ! $bad_before && ! $bad_after ) {
			// Character index is identical in the original (1:1 normalization),
			// so convert it to a byte offset there.
			return strlen( mb_substr( $haystack, 0, $pos, 'UTF-8' ) );
		}
		$offset = $pos + 1;
	}
}

/**
 * Auto-link the article body. Hooked into the_content on single posts.
 *
 * @param string $content Post content HTML.
 * @return string
 */
function go_verge_auto_internal_links( $content ) {
	static $done = array();

	if ( is_admin() || ! is_singular( 'post' ) || is_feed() ) {
		return $content;
	}
	$post_id = get_the_ID();
	if ( ! $post_id || get_queried_object_id() !== $post_id ) {
		return $content;
	}
	if ( isset( $done[ $post_id ] ) ) {
		return $content;
	}
	$done[ $post_id ] = true;

	if ( '' === trim( $content ) || ! class_exists( 'DOMDocument' ) ) {
		return $content;
	}

	$map = go_verge_internal_link_map();
	if ( empty( $map ) ) {
		return $content;
	}

	$current_url = get_permalink( $post_id );

	$dom = new DOMDocument();
	libxml_use_internal_errors( true );
	$loaded = $dom->loadHTML(
		'<?xml encoding="utf-8" ?><div id="go-il-root">' . $content . '</div>',
		LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD
	);
	libxml_clear_errors();
	if ( ! $loaded ) {
		return $content;
	}

	$xpath = new DOMXPath( $dom );
	$root  = $dom->getElementById( 'go-il-root' );
	if ( ! $root ) {
		return $content;
	}

	// Text nodes that are safe to touch — nothing inside links, headings, code,
	// captions or blockquotes.
	$text_nodes = $xpath->query(
		'.//text()[not(ancestor::a) and not(ancestor::h1) and not(ancestor::h2) and not(ancestor::h3) and not(ancestor::h4) and not(ancestor::h5) and not(ancestor::h6) and not(ancestor::code) and not(ancestor::pre) and not(ancestor::figcaption) and not(ancestor::blockquote)]',
		$root
	);
	if ( ! $text_nodes || 0 === $text_nodes->length ) {
		return $content;
	}
	$nodes = array();
	foreach ( $text_nodes as $node ) {
		$nodes[] = $node;
	}

	$links_made = 0;
	$used_urls  = array( $current_url => true );

	foreach ( $map as $entry ) {
		if ( $links_made >= GO_VERGE_IL_MAX_LINKS ) {
			break;
		}
		if ( isset( $used_urls[ $entry['url'] ] ) ) {
			continue;
		}

		foreach ( $nodes as $node ) {
			if ( ! $node->parentNode ) {
				continue;
			}
			$text = $node->nodeValue;
			if ( '' === trim( $text ) || mb_strlen( $text ) < mb_strlen( $entry['kw'] ) ) {
				continue;
			}

			$byte_pos = go_verge_il_find( $text, $entry['kw'] );
			if ( false === $byte_pos ) {
				continue;
			}

			// Extract the exact original-cased substring at the match position.
			$mb_start   = mb_strlen( substr( $text, 0, $byte_pos ), 'UTF-8' );
			$matched    = mb_substr( $text, $mb_start, mb_strlen( $entry['kw'], 'UTF-8' ), 'UTF-8' );
			$before_txt = mb_substr( $text, 0, $mb_start, 'UTF-8' );
			$after_txt  = mb_substr( $text, $mb_start + mb_strlen( $entry['kw'], 'UTF-8' ), null, 'UTF-8' );

			$parent = $node->parentNode;

			$link = $dom->createElement( 'a' );
			$link->setAttribute( 'href', $entry['url'] );
			$link->setAttribute( 'class', 'go-autolink' );
			$link->appendChild( $dom->createTextNode( $matched ) );

			if ( '' !== $before_txt ) {
				$parent->insertBefore( $dom->createTextNode( $before_txt ), $node );
			}
			$parent->insertBefore( $link, $node );
			if ( '' !== $after_txt ) {
				$parent->insertBefore( $dom->createTextNode( $after_txt ), $node );
			}
			$parent->removeChild( $node );

			$links_made++;
			$used_urls[ $entry['url'] ] = true;
			break; // keyword linked once; move to next keyword.
		}
	}

	if ( 0 === $links_made ) {
		return $content;
	}

	// Serialize the wrapper's inner HTML back out.
	$html = '';
	foreach ( $root->childNodes as $child ) {
		$html .= $dom->saveHTML( $child );
	}

	return $html;
}
// Retired from automatic execution: single.php uses the newer contextual engine capped at three links.
