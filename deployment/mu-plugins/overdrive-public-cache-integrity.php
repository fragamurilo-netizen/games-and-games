<?php
/**
 * Plugin Name: Overdrive Public Cache Guard
 * Description: Prevents native PHP sessions from poisoning cacheable anonymous front-end HTML.
 * Version: 1.0.0
 * Author: Game Overdrive
 *
 * This file is installed as an MU-plugin by the Overdrive theme. It has to run
 * before normal plugins: a theme loads too late to stop a plugin that starts a
 * native PHP session during plugin bootstrap.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( defined( 'OVERDRIVE_PUBLIC_CACHE_GUARD_VERSION' ) ) {
	return;
}
define( 'OVERDRIVE_PUBLIC_CACHE_GUARD_VERSION', '1.0.0' );

/**
 * Decide whether the current request is safe to treat as shared public HTML.
 *
 * Keep this deliberately independent of theme functions because MU-plugins run
 * before the active theme is loaded.
 *
 * @return bool
 */
function overdrive_public_cache_guard_is_public_document() {
	if ( defined( 'OVERDRIVE_ALLOW_NATIVE_PHP_SESSION' ) && OVERDRIVE_ALLOW_NATIVE_PHP_SESSION ) {
		return false;
	}

	$method = isset( $_SERVER['REQUEST_METHOD'] ) ? strtoupper( (string) $_SERVER['REQUEST_METHOD'] ) : 'GET';
	if ( 'GET' !== $method && 'HEAD' !== $method ) {
		return false;
	}

	$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? (string) $_SERVER['REQUEST_URI'] : '/';
	$path        = (string) parse_url( $request_uri, PHP_URL_PATH );
	if ( '' === $path ) {
		$path = '/';
	}

	/* Never interfere with control-plane, API, cron or authentication flows. */
	$blocked_prefixes = array(
		'/wp-admin/',
		'/wp-login.php',
		'/wp-cron.php',
		'/xmlrpc.php',
		'/wp-json/',
	);
	foreach ( $blocked_prefixes as $prefix ) {
		if ( 0 === strpos( $path, $prefix ) ) {
			return false;
		}
	}

	/* Preview/customizer/moderation requests are personalized even when GET. */
	foreach ( array( 'preview', 'preview_id', 'preview_nonce', 'customize_changeset_uuid', 'unapproved', 'replytocom', 'rest_route' ) as $key ) {
		if ( isset( $_GET[ $key ] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			return false;
		}
	}

	/* Logged-in/commenting/e-commerce visitors must keep any state they need. */
	foreach ( array_keys( (array) $_COOKIE ) as $cookie_name ) {
		$cookie_name = (string) $cookie_name;
		if ( 0 === strpos( $cookie_name, 'wordpress_logged_in_' )
			|| 0 === strpos( $cookie_name, 'wp-postpass_' )
			|| 0 === strpos( $cookie_name, 'comment_author_' )
			|| 0 === strpos( $cookie_name, 'wp_woocommerce_session_' ) ) {
			return false;
		}
	}

	return true;
}

/** Remove only the native PHP-session cookie from the outgoing header set. */
function overdrive_public_cache_guard_strip_session_cookie_header() {
	if ( headers_sent() || ! function_exists( 'headers_list' ) || ! function_exists( 'header_remove' ) ) {
		return;
	}

	$session_name = function_exists( 'session_name' ) ? (string) session_name() : 'PHPSESSID';
	if ( '' === $session_name ) {
		$session_name = 'PHPSESSID';
	}

	$keep    = array();
	$dropped = false;
	foreach ( headers_list() as $header ) {
		if ( 0 !== stripos( $header, 'set-cookie:' ) ) {
			continue;
		}
		$value = trim( substr( $header, strlen( 'set-cookie:' ) ) );
		$is_session_cookie = 0 === stripos( $value, $session_name . '=' ) || 0 === stripos( $value, 'PHPSESSID=' );
		$is_deletion       = $is_session_cookie
			&& ( false !== stripos( $value, 'Max-Age=0' ) || preg_match( '/Expires=[^;]*(?:1970|1969|Thu, 01 Jan)/i', $value ) );
		if ( $is_session_cookie && ! $is_deletion ) {
			$dropped = true;
			continue;
		}
		$keep[] = $value;
	}

	if ( ! $dropped ) {
		return;
	}

	header_remove( 'Set-Cookie' );
	foreach ( $keep as $value ) {
		header( 'Set-Cookie: ' . $value, false );
	}
}

/** Remove PHP's own session cache-limiter headers, never arbitrary app policy. */
function overdrive_public_cache_guard_strip_php_session_cache_headers() {
	if ( headers_sent() || ! function_exists( 'headers_list' ) || ! function_exists( 'header_remove' ) ) {
		return;
	}

	$has_php_session_signature = false;
	foreach ( headers_list() as $header ) {
		if ( 0 === stripos( $header, 'expires:' ) && false !== stripos( $header, 'Thu, 19 Nov 1981 08:52:00 GMT' ) ) {
			$has_php_session_signature = true;
			break;
		}
	}

	if ( ! $has_php_session_signature ) {
		return;
	}

	header_remove( 'Expires' );
	header_remove( 'Pragma' );
	header_remove( 'Cache-Control' );
}

/** Re-assert the guard after plugins have loaded, unless a protected flow began. */
function overdrive_public_cache_guard_reassert() {
	if ( ! overdrive_public_cache_guard_is_public_document() ) {
		return;
	}

	/* A plugin may have started a native session during bootstrap. Public HTML
	 * must not carry that state across readers, so close it and prevent PHP from
	 * emitting a new session cookie for the remainder of this request. */
	if ( function_exists( 'session_status' ) && PHP_SESSION_ACTIVE === session_status() ) {
		@session_write_close(); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	}

	/* Retire a stale PHPSESSID from readers who received one before this guard
	 * was installed. That single cleanup response may bypass cache, but the next
	 * navigation arrives without the cookie and becomes share-cache eligible. */
	$session_name = function_exists( 'session_name' ) ? (string) session_name() : 'PHPSESSID';
	if ( '' === $session_name ) {
		$session_name = 'PHPSESSID';
	}
	foreach ( array_unique( array( $session_name, 'PHPSESSID' ) ) as $stale_cookie ) {
		if ( isset( $_COOKIE[ $stale_cookie ] ) ) {
			unset( $_COOKIE[ $stale_cookie ] );
			if ( ! headers_sent() ) {
				$secure = ! empty( $_SERVER['HTTPS'] ) && 'off' !== strtolower( (string) $_SERVER['HTTPS'] );
				setcookie( $stale_cookie, '', array( 'expires' => time() - 3600, 'path' => '/', 'secure' => $secure, 'httponly' => true, 'samesite' => 'Lax' ) );
			}
		}
	}

	if ( function_exists( 'ini_set' ) ) {
		@ini_set( 'session.cache_limiter', '' ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		@ini_set( 'session.use_cookies', '0' ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		@ini_set( 'session.use_trans_sid', '0' ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	}
	if ( function_exists( 'session_cache_limiter' ) && ( ! function_exists( 'session_status' ) || PHP_SESSION_ACTIVE !== session_status() ) ) {
		@session_cache_limiter( '' ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	}

	overdrive_public_cache_guard_strip_php_session_cache_headers();
	overdrive_public_cache_guard_strip_session_cookie_header();
}

if ( overdrive_public_cache_guard_is_public_document() ) {
	/* Run immediately, before ordinary plugins. */
	overdrive_public_cache_guard_reassert();

	/* Ordinary plugins can still change PHP ini values later; re-assert at the
	 * first and last plugin lifecycle boundaries without touching private flows. */
	add_action( 'plugins_loaded', 'overdrive_public_cache_guard_reassert', PHP_INT_MAX );
	add_action( 'init', 'overdrive_public_cache_guard_reassert', 0 );
	add_action( 'send_headers', 'overdrive_public_cache_guard_strip_php_session_cache_headers', PHP_INT_MAX );
	add_action( 'send_headers', 'overdrive_public_cache_guard_strip_session_cookie_header', PHP_INT_MAX );
	add_action( 'template_redirect', 'overdrive_public_cache_guard_strip_php_session_cache_headers', PHP_INT_MAX );
	add_action( 'template_redirect', 'overdrive_public_cache_guard_strip_session_cookie_header', PHP_INT_MAX );
}
