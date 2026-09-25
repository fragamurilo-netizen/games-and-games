<?php
/**
 * Image deliverability contract for Search, Discover and editorial uploads.
 *
 * AVIF has two independent requirements on this site:
 *
 * 1. the public HTTP response must actually be `Content-Type: image/avif`;
 * 2. new uploads should only be accepted when WordPress can also process AVIF
 *    and generate the normal responsive/social derivatives.
 *
 * The first requirement governs Article.image and Discover readiness. The
 * second governs the Media Library. Keeping them separate avoids the old bug
 * where fixing the web-server MIME still left AVIF permanently disabled, while
 * also avoiding the opposite bug of accepting new AVIF files that the image
 * editor cannot resize.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Cache lifetime after a successful AVIF HTTP probe. */
function go_verge_avif_probe_good_ttl() {
	return defined( 'HOUR_IN_SECONDS' ) ? 12 * HOUR_IN_SECONDS : 43200;
}

/** Cache lifetime after a failed AVIF HTTP probe. Keep it short after a fix. */
function go_verge_avif_probe_bad_ttl() {
	return defined( 'MINUTE_IN_SECONDS' ) ? 10 * MINUTE_IN_SECONDS : 600;
}

/**
 * Bundled static AVIF used when no Media Library AVIF exists yet.
 *
 * The file is intentionally tiny. It tests the same Apache/LiteSpeed MIME
 * mapping without depending on a post already having an AVIF featured image.
 *
 * @return string
 */
function go_verge_avif_delivery_probe_url() {
	$base = defined( 'GO_VERGE_URI' ) ? rtrim( (string) GO_VERGE_URI, '/' ) : '';
	$url  = $base ? $base . '/assets/img/avif-delivery-probe.avif' : '';
	if ( $url && defined( 'GO_VERGE_VERSION' ) ) {
		$url .= '?go_avif_probe=' . rawurlencode( (string) GO_VERGE_VERSION );
	}
	return (string) apply_filters( 'go_verge_avif_delivery_probe_url', $url );
}

/** Cache AVIF MIME state separately for uploads/theme/static paths. */
function go_verge_avif_http_probe_cache_key( $url ) {
	$path  = function_exists( 'wp_parse_url' ) ? wp_parse_url( (string) $url, PHP_URL_PATH ) : parse_url( (string) $url, PHP_URL_PATH ); // phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
	$host  = function_exists( 'wp_parse_url' ) ? wp_parse_url( (string) $url, PHP_URL_HOST ) : parse_url( (string) $url, PHP_URL_HOST ); // phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
	$scope = 'other';
	if ( false !== strpos( (string) $path, '/wp-content/uploads/' ) ) {
		$scope = 'uploads';
	} elseif ( false !== strpos( (string) $path, '/wp-content/themes/' ) ) {
		$scope = 'theme';
	}
	return 'go_verge_avif_http_' . md5( strtolower( (string) $host ) . '|' . $scope );
}

/** Normalize an HTTP Content-Type header to its media type. */
function go_verge_normalize_image_content_type( $value ) {
	$value = strtolower( trim( (string) $value ) );
	if ( '' === $value ) {
		return '';
	}
	$parts = explode( ';', $value, 2 );
	return trim( (string) $parts[0] );
}

/**
 * Probe one public AVIF URL and cache whether consumers receive image/avif.
 *
 * HEAD is cheap, with a bounded range GET fallback for CDNs that return generic
 * metadata or reject HEAD. Static AVIF requests never enter WordPress, so this
 * is not a recursive PHP request.
 *
 * @param string $url   Public AVIF URL. Empty means the bundled probe asset.
 * Public render paths only read cached state and schedule a single refresh per
 * MIME scope. Network verification belongs to cron, admin/Site Health or CLI.
 *
 * @param bool   $force Ignore a cached answer in a maintenance context.
 * @return array{ok:bool,status:int,content_type:string,url:string,error:string}
 */
function go_verge_avif_http_probe( $url = '', $force = false ) {
	$url = $url ? (string) $url : go_verge_avif_delivery_probe_url();
	$out = array(
		'ok'           => false,
		'status'       => 0,
		'content_type' => '',
		'url'          => $url,
		'error'        => '',
	);

	if ( '' === $url ) {
		$out['error'] = 'probe_url_missing';
		return $out;
	}

	$key = go_verge_avif_http_probe_cache_key( $url );
	if ( ! $force && function_exists( 'get_transient' ) ) {
		$cached = get_transient( $key );
		if ( is_array( $cached ) && array_key_exists( 'ok', $cached ) ) {
			return array_merge( $out, $cached, array( 'url' => $url ) );
		}
	}

	$can_upload = function_exists( 'current_user_can' ) && current_user_can( 'upload_files' );
	$maintenance = ( function_exists( 'is_admin' ) && is_admin()
			&& ( ! function_exists( 'wp_doing_ajax' ) || ! wp_doing_ajax() || $can_upload ) )
		|| ( function_exists( 'wp_doing_cron' ) && wp_doing_cron() )
		|| ( defined( 'WP_CLI' ) && WP_CLI )
		|| ( defined( 'REST_REQUEST' ) && REST_REQUEST && $can_upload );
	if ( ! $maintenance ) {
		/* A cold cache must never put two blocking HTTP requests on the path to
		 * first byte. Refresh once per host/path scope, not once per article. */
		$hook = 'go_verge_avif_refresh_delivery';
		$args = array( $key );
		if ( function_exists( 'wp_next_scheduled' ) && function_exists( 'wp_schedule_single_event' ) && ! wp_next_scheduled( $hook, $args ) ) {
			set_transient( $key . '_pending', $url, DAY_IN_SECONDS );
			wp_schedule_single_event( time(), $hook, $args );
		}
		/* Preserve the last verified answer during refresh, with a bounded
		 * lifetime. A never-verified host remains conservative until cron runs. */
		$previous = get_transient( $key . '_verified' );
		if ( is_array( $previous ) && array_key_exists( 'ok', $previous ) ) {
			return array_merge( $out, $previous, array( 'url' => $url ) );
		}
		$out['error'] = 'verification_pending';
		return $out;
	}

	/* CLI tests and unusually early boot paths have no HTTP API. Unknown stays
	 * false instead of silently claiming that AVIF is deliverable. */
	if (
		! function_exists( 'wp_safe_remote_request' ) ||
		! function_exists( 'wp_remote_retrieve_response_code' ) ||
		! function_exists( 'wp_remote_retrieve_header' ) ||
		! function_exists( 'is_wp_error' )
	) {
		$out['error'] = 'http_api_unavailable';
		return $out;
	}

	$args = array(
		'method'             => 'HEAD',
		'timeout'            => 4,
		'redirection'        => 3,
		'reject_unsafe_urls' => true,
		'headers'            => array( 'Cache-Control' => 'no-cache' ),
	);
	if ( defined( 'GO_VERGE_VERSION' ) ) {
		$args['user-agent'] = 'Overdrive AVIF Probe/' . GO_VERGE_VERSION;
	}

	$response     = wp_safe_remote_request( $url, $args );
	$status       = is_wp_error( $response ) ? 0 : (int) wp_remote_retrieve_response_code( $response );
	$content_type = is_wp_error( $response ) ? '' : go_verge_normalize_image_content_type( wp_remote_retrieve_header( $response, 'content-type' ) );

	if ( is_wp_error( $response ) || ! in_array( $status, array( 200, 206 ), true ) || 'image/avif' !== $content_type ) {
		$args['method']              = 'GET';
		$args['timeout']             = 6;
		$args['headers']['Range']    = 'bytes=0-1023';
		$args['limit_response_size'] = 1024;
		$response     = wp_safe_remote_request( $url, $args );
		$status       = is_wp_error( $response ) ? 0 : (int) wp_remote_retrieve_response_code( $response );
		$content_type = is_wp_error( $response ) ? '' : go_verge_normalize_image_content_type( wp_remote_retrieve_header( $response, 'content-type' ) );
	}

	$out['status']       = $status;
	$out['content_type'] = $content_type;
	$out['ok']           = in_array( $status, array( 200, 206 ), true ) && 'image/avif' === $content_type;
	if ( is_wp_error( $response ) ) {
		$out['error'] = (string) $response->get_error_message();
	}

	if ( function_exists( 'set_transient' ) ) {
		set_transient( $key, $out, $out['ok'] ? go_verge_avif_probe_good_ttl() : go_verge_avif_probe_bad_ttl() );
		set_transient( $key . '_verified', $out, DAY_IN_SECONDS );
	}

	return $out;
}

/** Verify the queued sample outside the public HTML response. */
function go_verge_avif_refresh_delivery( $key ) {
	$url = get_transient( (string) $key . '_pending' );
	delete_transient( (string) $key . '_pending' );
	if ( is_string( $url ) && '' !== $url && go_verge_avif_http_probe_cache_key( $url ) === $key ) {
		go_verge_avif_http_probe( $url, true );
	}
}
add_action( 'go_verge_avif_refresh_delivery', 'go_verge_avif_refresh_delivery' );

/**
 * Whether AVIF reaches crawlers with a valid HTTP image MIME.
 *
 * Existing `go_verge_allow_avif_uploads` callbacks remain a backwards-
 * compatible manual override, but no wp-config.php callback is required now:
 * when there is no explicit override the theme probes the public response.
 *
 * @param string $url Optional AVIF URL to test; defaults to the bundled probe.
 * @return bool
 */
function go_verge_avif_http_deliverable( $url = '' ) {
	$override = apply_filters( 'go_verge_allow_avif_uploads', null );
	if ( is_bool( $override ) ) {
		return $override;
	}

	/* Attachment metadata often stores only `2026/09/file.avif`. That is useful
	 * for extension checks but is not a public URL. In that case probe the
	 * bundled static AVIF instead of sending an invalid relative HTTP request. */
	if ( $url ) {
		$scheme = function_exists( 'wp_parse_url' ) ? wp_parse_url( (string) $url, PHP_URL_SCHEME ) : parse_url( (string) $url, PHP_URL_SCHEME ); // phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
		if ( ! in_array( strtolower( (string) $scheme ), array( 'http', 'https' ), true ) ) {
			$url = '';
		}
	}

	$probe = go_verge_avif_http_probe( $url, false );
	return ! empty( $probe['ok'] );
}

/**
 * Whether WordPress can safely accept NEW AVIF uploads.
 *
 * MIME delivery alone is enough for a legacy full-size AVIF to be a truthful
 * Article.image. New uploads have a higher bar: the image editor must also be
 * able to decode AVIF so `go_discover_16x9`, `go_hero` and responsive WebP
 * derivatives can be generated.
 *
 * @return bool
 */
function go_verge_avif_uploads_allowed() {
	$override = apply_filters( 'go_verge_allow_avif_uploads', null );
	if ( is_bool( $override ) ) {
		return $override;
	}

	if ( ! go_verge_avif_http_deliverable() ) {
		return false;
	}

	$editor_ok = function_exists( 'wp_image_editor_supports' )
		? (bool) wp_image_editor_supports( array( 'mime_type' => 'image/avif' ) )
		: false;

	return (bool) apply_filters( 'go_verge_avif_editor_supported', $editor_ok );
}

/**
 * Whether a representative image format arrives intact at a crawler.
 *
 * SVG/JXL/HEIC/TIFF remain excluded as representative editorial preview
 * formats. AVIF is dynamic: it is accepted as soon as the public HTTP response
 * is verified as image/avif, including legacy files already on disk.
 *
 * @param string $url Image URL or path.
 * @return bool
 */
function go_verge_image_format_deliverable( $url ) {
	$path = function_exists( 'wp_parse_url' )
		? wp_parse_url( (string) $url, PHP_URL_PATH )
		: parse_url( (string) $url, PHP_URL_PATH ); // phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
	$ext = strtolower( (string) pathinfo( (string) $path, PATHINFO_EXTENSION ) );
	if ( '' === $ext ) {
		return false;
	}

	$blocked = array( 'svg', 'svgz', 'jxl', 'heic', 'heif', 'tif', 'tiff' );
	if ( in_array( $ext, array( 'avif', 'avifs' ), true ) && ! go_verge_avif_http_deliverable( (string) $url ) ) {
		return false;
	}

	/**
	 * Filter formats treated as undeliverable to Google's image pipeline.
	 *
	 * @param string[] $blocked Lower-case extensions.
	 * @param string   $url     Image URL being tested.
	 */
	$blocked = (array) apply_filters( 'go_verge_undeliverable_image_formats', $blocked, (string) $url );

	return ! in_array( $ext, $blocked, true );
}
