<?php
/**
 * Front-end stylesheet bundling.
 *
 * The Overdrive front-end grew by layering: every visual iteration shipped a new
 * stylesheet at a higher `wp_enqueue_scripts` priority so it could win by source
 * order. That is why a single article used to request 44 render-blocking
 * stylesheets — roughly 1 MB uncompressed — before the browser could paint, and
 * why the cascade is now the single largest cost in the critical path.
 *
 * This file does not change the cascade. It concatenates exactly the sheets
 * WordPress was about to print, in exactly the order WordPress resolved for
 * them, including every `wp_add_inline_style()` block at its original position,
 * and serves the result as one file. The computed styles of the document are
 * byte-for-byte identical; only the number of round trips changes.
 *
 * Rules of the bundle, and they are deliberate:
 *
 *   - Only theme-owned, local, unconditional, `media="all"` sheets are folded
 *     in. A plugin stylesheet, a conditional comment, a print sheet or an
 *     `alternate` sheet is left exactly where it is.
 *   - Each uninterrupted run is bundled at its original position. External or
 *     conditional sheets between theme layers remain between separate bundles.
 *   - Folded handles stay registered (with no `src`) so any dependency that
 *     points at them still resolves.
 *   - The build is cached in uploads under a hash of the exact input list plus
 *     each file's size and mtime, so editing any source stylesheet rebuilds it
 *     on the next request and nothing has to be purged by hand.
 *   - If uploads is not writable, or anything at all fails, the function returns
 *     without touching the queue and WordPress prints the sheets as before.
 *
 * Disable with: add_filter( 'go_verge_style_bundle_enabled', '__return_false' );
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
if ( ! defined( 'GO_VERGE_STYLE_BUNDLE_FORMAT_VERSION' ) ) {
	define( 'GO_VERGE_STYLE_BUNDLE_FORMAT_VERSION', '3' );
}

/** Handle of the generated bundle. */
if ( ! defined( 'GO_VERGE_STYLE_BUNDLE_HANDLE' ) ) {
	define( 'GO_VERGE_STYLE_BUNDLE_HANDLE', 'go-verge-bundle' );
}

/**
 * Absolute path + URL of the bundle cache directory.
 *
 * @return array{dir:string,url:string}|null Null when uploads is unavailable.
 */
/** Write immutable cache policy next to content-hashed bundle files. */
function go_verge_style_bundle_cache_policy( $dir ) {
	$file = trailingslashit( $dir ) . '.htaccess';
	$marker = '# Overdrive immutable bundle cache v3152';
	if ( is_file( $file ) ) {
		$existing = (string) @file_get_contents( $file ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged,WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
		if ( false !== strpos( $existing, $marker ) ) { return; }
	}
	$rules = $marker . "\n<IfModule mod_expires.c>\nExpiresActive On\nExpiresByType text/css \"access plus 1 year\"\n</IfModule>\n<IfModule mod_headers.c>\n<FilesMatch \"\\.css$\">\nHeader set Cache-Control \"public, max-age=31536000, immutable\"\n</FilesMatch>\n</IfModule>\n";
	@file_put_contents( $file, $rules, LOCK_EX ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged,WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
}

function go_verge_style_bundle_dir() {
	$uploads = wp_upload_dir();
	if ( ! empty( $uploads['error'] ) || empty( $uploads['basedir'] ) ) {
		return null;
	}

	$dir = trailingslashit( $uploads['basedir'] ) . 'go-verge-bundles';
	$url = trailingslashit( $uploads['baseurl'] ) . 'go-verge-bundles';

	return array( 'dir' => $dir, 'url' => $url );
}

/** Apply the bundle cache policy once after upgrading, even when the current hash already exists. */
function go_verge_style_bundle_cache_policy_upgrade() {
	if ( get_option( 'go_verge_bundle_cache_policy_v3152' ) ) { return; }
	$paths = go_verge_style_bundle_dir();
	if ( $paths && is_dir( $paths['dir'] ) ) {
		go_verge_style_bundle_cache_policy( $paths['dir'] );
	}
	update_option( 'go_verge_bundle_cache_policy_v3152', 1, false );
}
add_action( 'admin_init', 'go_verge_style_bundle_cache_policy_upgrade', 22 );

/**
 * Whether a registered style may be folded into the bundle.
 *
 * @param string $handle Style handle.
 * @param object $item   Registered dependency object.
 * @return string|false Absolute file path, or false when the sheet must stay as-is.
 */
function go_verge_style_bundle_local_path( $handle, $item ) {
	if ( GO_VERGE_STYLE_BUNDLE_HANDLE === $handle ) {
		return false;
	}
	if ( empty( $item->src ) || ! is_string( $item->src ) ) {
		return false;
	}
	// Only unconditional, screen-agnostic sheets. A print or conditional sheet
	// has different semantics and must keep its own <link>.
	$media = isset( $item->args ) && is_string( $item->args ) ? strtolower( trim( $item->args ) ) : 'all';
	if ( '' !== $media && 'all' !== $media ) {
		return false;
	}
	if ( ! empty( $item->extra['conditional'] ) || ! empty( $item->extra['alt'] ) || ! empty( $item->extra['rtl'] ) ) {
		return false;
	}

	$theme_uri = trailingslashit( get_template_directory_uri() );
	$src       = $item->src;
	if ( 0 !== strpos( $src, $theme_uri ) ) {
		// Also accept protocol-relative / path-only sources inside the theme.
		$theme_host = (string) wp_parse_url( $theme_uri, PHP_URL_HOST );
		$src_host   = (string) wp_parse_url( $src, PHP_URL_HOST );
		if ( $src_host && strtolower( $src_host ) !== strtolower( $theme_host ) ) {
			return false;
		}
		$theme_path = (string) wp_parse_url( $theme_uri, PHP_URL_PATH );
		$src_path   = (string) wp_parse_url( $src, PHP_URL_PATH );
		if ( ! $theme_path || ! $src_path || 0 !== strpos( $src_path, $theme_path ) ) {
			return false;
		}
		$relative = substr( $src_path, strlen( $theme_path ) );
	} else {
		$relative = substr( $src, strlen( $theme_uri ) );
	}

	$relative = strtok( $relative, '?' );
	$path     = trailingslashit( get_template_directory() ) . ltrim( (string) $relative, '/' );
	$path     = realpath( $path );
	$root     = realpath( get_template_directory() );
	if ( ! $path || ! $root || 0 !== strpos( wp_normalize_path( $path ), trailingslashit( wp_normalize_path( $root ) ) ) ) {
		return false;
	}
	$path     = wp_normalize_path( $path );

	if ( ! is_file( $path ) || ! is_readable( $path ) ) {
		return false;
	}

	return $path;
}

/**
 * Rewrite relative url() references so the sheet keeps working from /uploads/.
 *
 * @param string $css      Stylesheet source.
 * @param string $file_dir Directory of the source file, relative to the theme root.
 * @return string
 */
function go_verge_style_bundle_absolutize( $css, $file_dir ) {
	$base = trailingslashit( get_template_directory_uri() ) . trailingslashit( ltrim( $file_dir, '/' ) );

	return (string) preg_replace_callback(
		'#url\(\s*([\'"]?)([^\'")]+)\1\s*\)#i',
		static function ( $m ) use ( $base ) {
			$target = trim( $m[2] );
			if ( '' === $target || preg_match( '#^(data:|https?:|//|/|\#)#i', $target ) ) {
				return $m[0];
			}
			// Resolve ../ segments against the source directory.
			$resolved = $base . $target;
			$parts    = array();
			foreach ( explode( '/', str_replace( '\\', '/', $resolved ) ) as $segment ) {
				if ( '..' === $segment ) {
					array_pop( $parts );
				} elseif ( '.' !== $segment ) {
					$parts[] = $segment;
				}
			}
			return 'url(' . $m[1] . implode( '/', $parts ) . $m[1] . ')';
		},
		$css
	);
}

/**
 * Conservative whitespace/comment minification.
 *
 * Deliberately does NOT touch the space around selectors, combinators or inside
 * values: those are where "safe" minifiers break `a :hover`, `calc(1px + 2px)`
 * and custom-property fallbacks. Comments and indentation are the bulk of the
 * win here anyway, and transport compression does the rest.
 *
 * @param string $css Stylesheet source.
 * @return string
 */
function go_verge_style_bundle_compact( $css ) {
	$out    = '';
	$len    = strlen( $css );
	$quote  = '';
	$i      = 0;

	while ( $i < $len ) {
		$c = $css[ $i ];

		if ( '' !== $quote ) {
			$out .= $c;
			if ( '\\' === $c && $i + 1 < $len ) {
				$out .= $css[ $i + 1 ];
				$i   += 2;
				continue;
			}
			if ( $c === $quote ) {
				$quote = '';
			}
			++$i;
			continue;
		}

		if ( '"' === $c || "'" === $c ) {
			$quote = $c;
			$out  .= $c;
			++$i;
			continue;
		}

		// Comment — but never a "/*!" licence block.
		if ( '/' === $c && $i + 1 < $len && '*' === $css[ $i + 1 ] ) {
			$keep = ( $i + 2 < $len && '!' === $css[ $i + 2 ] );
			$end  = strpos( $css, '*/', $i + 2 );
			if ( false === $end ) {
				break;
			}
			if ( $keep ) {
				$out .= substr( $css, $i, $end + 2 - $i );
			} else {
				// A comment can separate two tokens; leave one space behind.
				$out .= ' ';
			}
			$i = $end + 2;
			continue;
		}

		if ( ' ' === $c || "\t" === $c || "\n" === $c || "\r" === $c || "\f" === $c ) {
			$j = $i;
			while ( $j < $len && ( ' ' === $css[ $j ] || "\t" === $css[ $j ] || "\n" === $css[ $j ] || "\r" === $css[ $j ] || "\f" === $css[ $j ] ) ) {
				++$j;
			}
			$prev = '' !== $out ? substr( $out, -1 ) : '';
			$next = $j < $len ? $css[ $j ] : '';
			/*
			 * Whitespace only disappears next to a block or statement
			 * delimiter. Combinators and math operators keep theirs on
			 * purpose: `calc(100% + 12px)` is invalid the moment the space
			 * after `+` is dropped, and `a :hover` stops meaning what it says
			 * the moment the space before `:` is dropped. Those two cases are
			 * exactly how "safe" minifiers break production stylesheets, so
			 * this one trades a few hundred bytes for never doing it.
			 */
			if ( '' !== $prev && '' !== $next
				&& false === strpos( "{};,:(", $prev )
				&& false === strpos( "{};,)", $next ) ) {
				$out .= ' ';
			}
			$i = $j;
			continue;
		}

		$out .= $c;
		++$i;
	}

	return trim( $out );
}

/**
 * Fold the queued theme stylesheets into one file.
 *
 * Runs at the end of wp_enqueue_scripts, after the editorial and profile layers
 * and their `wp_add_inline_style()` calls have joined the queue.
 *
 * @return void
 */
function go_verge_build_style_bundle() {
	if ( is_admin() || is_customize_preview() || is_feed() ) {
		return;
	}
	if ( ! apply_filters( 'go_verge_style_bundle_enabled', true ) ) {
		return;
	}

	$styles = wp_styles();
	if ( ! $styles instanceof WP_Styles || empty( $styles->queue ) ) {
		return;
	}

	$paths = go_verge_style_bundle_dir();
	if ( null === $paths ) {
		return;
	}

	/* Resolve the exact print order once. */
	$styles->to_do = array();
	$styles->all_deps( $styles->queue );
	$ordered = (array) $styles->to_do;
	if ( count( $ordered ) < 3 ) {
		return;
	}

	/*
	 * Performance contract (3.14.1): fingerprint first, read CSS only when a new
	 * bundle must actually be built. The old implementation read every queued
	 * stylesheet into PHP memory on EVERY cache miss at WordPress level even when
	 * the hashed bundle already existed on disk. On a theme with dozens of layered
	 * sheets, concurrent PHP workers paid that file-I/O/string-allocation tax over
	 * and over. This two-pass build makes the steady-state request O(stat), not
	 * O(total CSS bytes).
	 */
	$entries     = array();
	$fingerprint = array(
		'format:' . GO_VERGE_STYLE_BUNDLE_FORMAT_VERSION,
		'theme-version:' . GO_VERGE_VERSION,
		'theme-uri:' . untrailingslashit( get_template_directory_uri() ),
	);
	$folded      = array();

	foreach ( $ordered as $handle ) {
		$item = isset( $styles->registered[ $handle ] ) ? $styles->registered[ $handle ] : null;
		if ( ! $item ) {
			continue;
		}

		/* Keep @font-face declarations in the document head. They are tiny compared
		 * with the visual bundle and must be known before first paint so preloaded
		 * Source Sans/Barlow files can be used immediately instead of causing a
		 * second, page-wide typography repaint after the bundle is parsed. */
		if ( 'go-verge-fonts' === $handle ) {
			continue;
		}

		$path   = go_verge_style_bundle_local_path( $handle, $item );
		$inline = ! empty( $item->extra['after'] ) ? (array) $item->extra['after'] : array();

		if ( false === $path && ! $inline ) {
			continue;
		}
		if ( false === $path && false !== $item->src ) {
			continue;
		}
		if ( false === $path && ( 0 !== strpos( $handle, 'go-verge' ) || ! empty( $item->extra['conditional'] ) || ! empty( $item->extra['alt'] ) || ! empty( $item->extra['rtl'] ) || ! in_array( $item->args, array( '', 'all', null ), true ) ) ) {
			continue;
		}

		$entry = array(
			'handle' => $handle,
			'item'   => $item,
			'path'   => $path,
			'inline' => $inline,
		);

		if ( false !== $path ) {
			$size  = @filesize( $path ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
			$mtime = @filemtime( $path ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
			if ( false === $size || false === $mtime ) {
				return;
			}
			$fingerprint[] = $handle . ':' . $path . ':' . $size . ':' . $mtime;
		}

		foreach ( $inline as $block ) {
			$block = trim( (string) $block );
			if ( '' !== $block ) {
				$fingerprint[] = $handle . ':inline:' . md5( $block );
			}
		}

		$entries[] = $entry;
		$folded[]  = $handle;
	}

	if ( count( $folded ) < 3 || ! $entries ) {
		return;
	}

	/* Never move a theme layer across another printable stylesheet. Preserve the
	 * resolved dependency order, with one bundle per uninterrupted theme run. */
	$by_handle = array_column( $entries, null, 'handle' );
	$groups = array();
	$group = array();
	foreach ( $ordered as $handle ) {
		if ( isset( $by_handle[ $handle ] ) ) {
			$group[] = $by_handle[ $handle ];
			continue;
		}
		$item = $styles->registered[ $handle ] ?? null;
		if ( $item && ( ! empty( $item->src ) || ! empty( $item->extra['after'] ) || ! empty( $item->extra['before'] ) ) && $group ) {
			$groups[] = $group;
			$group = array();
		}
	}
	if ( $group ) { $groups[] = $group; }

	$replacements = array();
	$bundles = array();
	$bundled = array();
	$needs_prune = false;
	foreach ( $groups as $group ) {
		if ( count( $group ) < 2 ) { continue; }
		$group_handles = array_column( $group, 'handle' );
		$created = false;
		$url = go_verge_write_style_bundle( $group, $paths, array_merge( $fingerprint, $group_handles ), $created );
		if ( ! $url ) { return; } // Leave all originals intact on a cache/build failure.
		$needs_prune = $needs_prune || $created;
		$bundle_handle = GO_VERGE_STYLE_BUNDLE_HANDLE . ( $bundles ? '-' . count( $bundles ) : '' );
		$bundles[ $bundle_handle ] = $url;
		$replacements[ end( $group_handles ) ] = $bundle_handle;
		$bundled = array_merge( $bundled, $group );
	}
	if ( ! $bundles ) { return; }
	if ( $needs_prune ) {
		go_verge_style_bundle_prune( $paths['dir'], array_map( 'basename', $bundles ) );
	}
	foreach ( $bundles as $handle => $url ) {
		wp_register_style( $handle, $url, array(), null );
	}
	$GLOBALS['go_verge_style_bundle_url'] = reset( $bundles );
	foreach ( $bundled as $entry ) {
		if ( false !== $entry['path'] ) { $entry['item']->src = false; }
		$entry['item']->extra['after'] = array();
	}
	$folded = array_column( $bundled, 'handle' );
	$queue = array();
	foreach ( $ordered as $handle ) {
		if ( isset( $replacements[ $handle ] ) ) {
			$queue[] = $replacements[ $handle ];
		} elseif ( ! in_array( $handle, $folded, true ) ) {
			$queue[] = $handle;
		}
	}
	$styles->queue = $queue;
	$styles->to_do = array();
}
// Collect the final editorial/profile layers as well as the shared theme sheets.
add_action( 'wp_enqueue_scripts', 'go_verge_build_style_bundle', PHP_INT_MAX - 10 );

/** Build or reuse one contiguous bundle without changing the WordPress queue. */
function go_verge_write_style_bundle( $entries, $paths, $fingerprint, &$created = false ) {
	$created = false;

	$key  = substr( md5( implode( '|', $fingerprint ) ), 0, 20 );
	$file = $paths['dir'] . '/go-verge-' . $key . '.css';

	if ( ! is_file( $file ) ) {
		$bundle_lock = 'style_bundle_' . $key;
		if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( $bundle_lock, 120 ) ) {
			/* Another worker is building this exact bundle. Keep the original
			 * styles for this request instead of duplicating CPU/file I/O. */
			return;
		}
		try {
		if ( ! wp_mkdir_p( $paths['dir'] ) ) {
			return;
		}
		go_verge_style_bundle_cache_policy( $paths['dir'] );

		$chunks = array();
		foreach ( $entries as $entry ) {
			$handle = $entry['handle'];
			$path   = $entry['path'];
			$inline = $entry['inline'];

			if ( false !== $path ) {
				$css = (string) file_get_contents( $path ); // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
				$rel = ltrim( str_replace( wp_normalize_path( trailingslashit( get_template_directory() ) ), '', $path ), '/' );
				$chunks[] = "\n/*! " . $handle . " */\n" . go_verge_style_bundle_absolutize( $css, dirname( $rel ) );
			}

			foreach ( $inline as $block ) {
				$block = trim( (string) $block );
				if ( '' !== $block ) {
					$chunks[] = "\n/*! " . $handle . " (inline) */\n" . $block;
				}
			}
		}

		$content = go_verge_style_bundle_compact( implode( "\n", $chunks ) );
		if ( '' === $content ) {
			return;
		}
		$tmp = $file . '.' . wp_generate_password( 6, false ) . '.tmp';
		if ( false === file_put_contents( $tmp, $content ) ) { // phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
			return;
		}
		if ( ! @rename( $tmp, $file ) ) { // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
			@unlink( $tmp ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
			return;
		}
		$created = true;
		} finally {
			go_verge_release_job_lock( $bundle_lock );
		}
	}
	/* Track recent use, at most once per day per variant. Retention must cover
	 * the longest HTML cache lifetime, even for a bundle first built months ago. */
	$last_used = filemtime( $file );
	if ( false !== $last_used && $last_used < time() - 86400 ) {
		@touch( $file ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	}

	return $paths['url'] . '/' . basename( $file );
}

/**
 * Keep enough generated bundle variants on disk to avoid rebuild churn.
 *
 * Different page types can legitimately produce different handle/inline-style
 * fingerprints. Keep at least 32 variants, all files used in this response,
 * and files newer than the retention window so cached HTML keeps working after
 * deploys. The count is a soft limit while those files are protected. Run only
 * after creating a new bundle; last-use timestamps update at most once per day.
 *
 * @param string $dir  Bundle directory.
 * @param string|string[] $keep Filenames used by the current response.
 * @return void
 */
function go_verge_style_bundle_prune( $dir, $keep ) {
	$keep = (array) $keep;
	$retention = max( 0, (int) apply_filters( 'go_verge_style_bundle_retention_seconds', 7 * 86400 ) );
	$cutoff = time() - $retention;
	$files = glob( trailingslashit( $dir ) . 'go-verge-*.css' );
	if ( ! is_array( $files ) || count( $files ) <= 32 ) {
		return;
	}

	usort(
		$files,
		static function ( $a, $b ) {
			return filemtime( $b ) <=> filemtime( $a );
		}
	);

	foreach ( array_slice( $files, 32 ) as $old ) {
		if ( in_array( basename( $old ), $keep, true ) || filemtime( $old ) >= $cutoff ) {
			continue;
		}
		@unlink( $old ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	}
}
