<?php
/**
 * Overdrive — Verge
 * Standalone theme bootstrap.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'GO_VERGE_VERSION', '5.7.0' );

require_once get_template_directory() . '/inc/brand-icons.php';

define( 'GO_VERGE_DIR', get_template_directory() );
define( 'GO_VERGE_URI', get_template_directory_uri() );


/**
 * Keep the public <head> focused on resources and discovery signals that are
 * still useful to modern browsers/crawlers. Native emoji rendering is reliable
 * on the supported browser baseline, so the legacy detection payload only adds
 * parser/main-thread work. The REST/oEmbed/feed discovery links are preserved.
 */
function go_verge_frontend_head_hygiene() {
	if ( is_admin() ) {
		return;
	}

	remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
	remove_action( 'wp_print_styles', 'print_emoji_styles' );
	remove_action( 'wp_head', 'wp_generator' );
	remove_action( 'wp_head', 'rsd_link' );
	remove_action( 'wp_head', 'wlwmanifest_link' );
	remove_action( 'wp_head', 'wp_shortlink_wp_head', 10 );
	remove_action( 'wp_head', 'wp_site_icon', 99 );
}
add_action( 'after_setup_theme', 'go_verge_frontend_head_hygiene', 100 );

/**
 * True while Gutenberg is persisting a post through the REST API.
 *
 * Heavy editorial intelligence must not run inside this transport request: a
 * timeout/fatal here is surfaced by Gutenberg only as "Falha ao atualizar".
 */
function go_verge_editor_rest_save_in_progress() {
	return defined( 'REST_REQUEST' ) && REST_REQUEST;
}

/**
 * Queue expensive post-save intelligence outside the Gutenberg save request.
 *
 * The event is deduplicated per post, so taxonomy/meta callbacks triggered by
 * the same REST save do not schedule the same work several times.
 */
function go_verge_defer_post_save_maintenance( $post_id, $delay = 10 ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}

	$args = array( $post_id );
	if ( ! wp_next_scheduled( 'go_verge_deferred_post_save_maintenance', $args ) ) {
		wp_schedule_single_event( time() + max( 5, absint( $delay ) ), 'go_verge_deferred_post_save_maintenance', $args );
	}

	/* WP-Cron is still the preferred asynchronous worker, but editorial entity
	 * linking must not disappear merely because a host/CDN delays wp-cron.php.
	 * Keep a tiny persistent fallback queue. An ordinary subsequent wp-admin
	 * request drains at most one old item, so publishing remains fast and public
	 * page views never pay for semantic maintenance. */
	$queue = get_option( 'go_verge_deferred_post_save_fallback_queue', array() );
	$queue = is_array( $queue ) ? $queue : array();
	$queue[ (string) $post_id ] = isset( $queue[ (string) $post_id ] ) ? (int) $queue[ (string) $post_id ] : time();
	if ( count( $queue ) > 60 ) {
		asort( $queue, SORT_NUMERIC );
		$queue = array_slice( $queue, -60, null, true );
	}
	update_option( 'go_verge_deferred_post_save_fallback_queue', $queue, false );
}

/** Remove one post from the no-cron fallback queue after maintenance completes. */
function go_verge_deferred_post_save_fallback_done( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return; }
	$queue = get_option( 'go_verge_deferred_post_save_fallback_queue', array() );
	if ( ! is_array( $queue ) || ! isset( $queue[ (string) $post_id ] ) ) { return; }
	unset( $queue[ (string) $post_id ] );
	update_option( 'go_verge_deferred_post_save_fallback_queue', $queue, false );
}

/** Run the expensive, non-essential intelligence after the post is safely saved. */
function go_verge_run_deferred_post_save_maintenance( $post_id ) {
	static $running = array();
	$post_id = absint( $post_id );
	if ( ! $post_id || isset( $running[ $post_id ] ) || 'post' !== get_post_type( $post_id ) || 'trash' === get_post_status( $post_id ) ) {
		return;
	}

	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) {
		return;
	}

	$lock_key = 'post_save_maintenance_' . $post_id;
	$has_lock = function_exists( 'go_verge_claim_job_lock' ) ? go_verge_claim_job_lock( $lock_key, 5 * MINUTE_IN_SECONDS ) : true;
	if ( ! $has_lock ) { return; }

	$running[ $post_id ] = true;
	$tasks = array(
		array( 'go_verge_semantic_precompute_saved_post', array( $post_id, $post, true ) ),
		array( 'go_verge_game_intelligence_auto_link_on_save', array( $post_id, $post, true ) ),
		array( 'go_verge_v27_reanalyze_story_entities', array( $post_id ) ),
		array( 'go_verge_v72_queue_post_subjects', array( $post_id ) ),
		array( 'go_verge_v7_update_internal_legacy_links', array( $post_id ) ),
	);

	foreach ( $tasks as $task ) {
		$callback = $task[0];
		if ( ! function_exists( $callback ) ) {
			continue;
		}
		try {
			call_user_func_array( $callback, $task[1] );
		} catch ( Throwable $error ) {
			/* One optional intelligence task must never prevent the remaining
			 * maintenance jobs from completing. Keep the failure observable in the
			 * normal PHP error log without corrupting REST JSON. */
			error_log( sprintf( 'Overdrive deferred post-save task %s failed for post %d: %s', $callback, $post_id, $error->getMessage() ) ); // phpcs:ignore WordPress.PHP.DevelopmentFunctions.error_log_error_log
		}
	}

	unset( $running[ $post_id ] );
	go_verge_deferred_post_save_fallback_done( $post_id );
	if ( function_exists( 'go_verge_release_job_lock' ) ) { go_verge_release_job_lock( $lock_key ); }
}
add_action( 'go_verge_deferred_post_save_maintenance', 'go_verge_run_deferred_post_save_maintenance', 10, 1 );

/**
 * Bounded no-cron fallback for deferred editorial intelligence.
 *
 * Only wp-admin navigation can run it, only after an item has waited long enough
 * for WP-Cron to get first chance, and only one post is processed per request.
 */
function go_verge_deferred_post_save_admin_fallback() {
	if ( ! is_admin() || wp_doing_ajax() || wp_doing_cron() || ( defined( 'REST_REQUEST' ) && REST_REQUEST ) || ! current_user_can( 'edit_posts' ) ) {
		return;
	}
	$queue = get_option( 'go_verge_deferred_post_save_fallback_queue', array() );
	if ( ! is_array( $queue ) || ! $queue ) { return; }
	asort( $queue, SORT_NUMERIC );
	$now = time();
	foreach ( $queue as $post_id => $queued_at ) {
		$post_id = absint( $post_id );
		if ( ! $post_id ) { continue; }
		if ( ( $now - absint( $queued_at ) ) < 90 ) { break; }
		if ( 'post' !== get_post_type( $post_id ) || 'trash' === get_post_status( $post_id ) ) {
			go_verge_deferred_post_save_fallback_done( $post_id );
			continue;
		}
		go_verge_run_deferred_post_save_maintenance( $post_id );
		break;
	}
}
add_action( 'admin_init', 'go_verge_deferred_post_save_admin_fallback', 160 );


/**
 * Claim a short-lived database-backed lock for maintenance work.
 *
 * add_option() is atomic at the database layer, unlike a get/set transient
 * pair. Each claim also carries a unique owner token. Without that token, a
 * slow worker whose lock expired could finish after a replacement worker had
 * acquired the same key and delete the replacement's live lock on release.
 *
 * @param string $key Lock namespace.
 * @param int    $ttl Lock lifetime in seconds.
 * @return bool True only for the worker that owns the lock.
 */
function go_verge_claim_job_lock( $key, $ttl = 300 ) {
	$key     = sanitize_key( (string) $key );
	if ( '' === $key ) {
		return false;
	}
	$ttl     = max( 30, absint( $ttl ) );
	$option  = '_go_job_lock_' . $key;
	$now     = time();
	$current = get_option( $option, false );
	$expires = 0;

	/* Backward-compatible with the integer-only locks shipped before 3.53.1. */
	if ( is_numeric( $current ) ) {
		$expires = absint( $current );
	} elseif ( is_string( $current ) && preg_match( '/^([0-9]+)\|[a-f0-9]{16,64}$/', $current, $matches ) ) {
		$expires = absint( $matches[1] );
	}

	if ( $expires > $now ) {
		return false;
	}

	if ( false !== $current ) {
		/* Delete only the stale value we inspected. A plain delete_option() has a
		 * check/delete race and can erase a fresh claim created in between. */
		global $wpdb;
		if ( isset( $wpdb->options ) ) {
			$wpdb->query( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
				$wpdb->prepare(
					"DELETE FROM {$wpdb->options} WHERE option_name = %s AND option_value = %s",
					$option,
					maybe_serialize( $current )
				)
			);
			wp_cache_delete( $option, 'options' );
		} elseif ( get_option( $option, false ) === $current ) {
			/* Test/boot fallback; production WordPress always provides $wpdb. */
			delete_option( $option );
		}
	}

	$token = function_exists( 'wp_generate_uuid4' )
		? str_replace( '-', '', wp_generate_uuid4() )
		: md5( uniqid( (string) wp_rand(), true ) );
	$value = (string) ( $now + $ttl ) . '|' . strtolower( $token );

	if ( ! add_option( $option, $value, '', false ) ) {
		return false;
	}

	if ( ! isset( $GLOBALS['go_verge_job_lock_owners'] ) || ! is_array( $GLOBALS['go_verge_job_lock_owners'] ) ) {
		$GLOBALS['go_verge_job_lock_owners'] = array();
	}
	$GLOBALS['go_verge_job_lock_owners'][ $option ] = $value;

	return true;
}

/**
 * Release a lock previously claimed by this PHP worker.
 *
 * @param string $key Lock namespace.
 * @return bool Whether this worker's exact claim was removed.
 */
function go_verge_release_job_lock( $key ) {
	$option = '_go_job_lock_' . sanitize_key( (string) $key );
	$owners = isset( $GLOBALS['go_verge_job_lock_owners'] ) && is_array( $GLOBALS['go_verge_job_lock_owners'] )
		? $GLOBALS['go_verge_job_lock_owners']
		: array();
	$value  = isset( $owners[ $option ] ) ? (string) $owners[ $option ] : '';

	if ( '' === $value ) {
		return false;
	}

	global $wpdb;
	$deleted = false;
	if ( isset( $wpdb->options ) ) {
		$deleted = 1 === (int) $wpdb->query( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
			$wpdb->prepare(
				"DELETE FROM {$wpdb->options} WHERE option_name = %s AND option_value = %s",
				$option,
				maybe_serialize( $value )
			)
		);
		wp_cache_delete( $option, 'options' );
	} elseif ( get_option( $option, false ) === $value ) {
		$deleted = (bool) delete_option( $option );
	}

	unset( $GLOBALS['go_verge_job_lock_owners'][ $option ] );

	return $deleted;
}

/**
 * Flush rewrite rules at most once in a PHP request.
 *
 * Several theme modules have independent version guards. A deploy used to let
 * each one rebuild the same rewrite option in the same admin request. All
 * routes are already registered during init, so one soft flush is sufficient.
 *
 * @return bool Whether this call performed the flush.
 */
function go_verge_flush_rewrite_rules_once_per_request() {
	static $flushed = false;
	if ( $flushed ) {
		return false;
	}
	if ( ! go_verge_claim_job_lock( 'rewrite_flush', 120 ) ) {
		return false;
	}
	try {
		flush_rewrite_rules( false );
		$flushed = true;
		return true;
	} finally {
		go_verge_release_job_lock( 'rewrite_flush' );
	}
}

/*
 * Loaded before anything else the theme does, and deliberately not on a hook.
 * `plugins_loaded` has already fired by the time functions.php runs, so the
 * only way to disarm PHP's session cache limiter before a tracking component
 * starts its front-end session is to do it at theme load. See the file header
 * for the production measurement that motivated it.
 */
require_once GO_VERGE_DIR . '/inc/http-cache-integrity.php';
go_verge_cache_integrity_disarm_session_limiter();

require_once GO_VERGE_DIR . '/inc/privacy-page.php';


/**
 * WordPress 7.0 compatibility for Jetpack Subscriptions.
 *
 * Some Jetpack versions register the stylesheet extra `path` value as a URL.
 * Core's wp_maybe_inline_styles() expects that value to be a readable local
 * filesystem path and emits a doing_it_wrong notice otherwise. Keep the public
 * stylesheet URL untouched while normalising only the auxiliary path metadata.
 */
function go_verge_fix_jetpack_subscriptions_style_path() {
	global $wp_styles;

	if ( ! ( $wp_styles instanceof WP_Styles ) ) {
		return;
	}

	$handle = 'jetpack-subscriptions';
	if ( empty( $wp_styles->registered[ $handle ] ) ) {
		return;
	}

	$style = $wp_styles->registered[ $handle ];
	if ( empty( $style->extra ) || ! is_array( $style->extra ) || empty( $style->extra['path'] ) ) {
		return;
	}

	$path = (string) $style->extra['path'];

	// A real readable local path is already valid and needs no intervention.
	if ( ! wp_http_validate_url( $path ) && is_readable( $path ) ) {
		return;
	}

	$local_path  = '';
	$content_url = trailingslashit( content_url() );

	// First try the exact public wp-content URL prefix.
	if ( 0 === strpos( $path, $content_url ) ) {
		$relative   = ltrim( substr( $path, strlen( $content_url ) ), "/\\" );
		$local_path = trailingslashit( WP_CONTENT_DIR ) . str_replace( '/', DIRECTORY_SEPARATOR, $relative );
	} elseif ( wp_http_validate_url( $path ) ) {
		// Fallback for scheme/domain differences or reverse-proxy/CDN rewrites.
		$url_path     = (string) wp_parse_url( $path, PHP_URL_PATH );
		$content_path = (string) wp_parse_url( content_url( '/' ), PHP_URL_PATH );
		$content_path = trailingslashit( $content_path );

		if ( '' !== $url_path && '' !== $content_path && 0 === strpos( $url_path, $content_path ) ) {
			$relative   = ltrim( substr( $url_path, strlen( $content_path ) ), "/\\" );
			$local_path = trailingslashit( WP_CONTENT_DIR ) . str_replace( '/', DIRECTORY_SEPARATOR, $relative );
		}
	}

	if ( '' !== $local_path && is_readable( $local_path ) ) {
		$style->extra['path'] = $local_path;
		return;
	}

	// The `src` property still loads the stylesheet. Removing only invalid path
	// metadata prevents the core inline-style reader from producing a notice.
	unset( $style->extra['path'] );
}
add_action( 'wp_enqueue_scripts', 'go_verge_fix_jetpack_subscriptions_style_path', PHP_INT_MAX );
add_action( 'wp_head', 'go_verge_fix_jetpack_subscriptions_style_path', 1 );


/**
 * Return an asset version based on file modification time.
 *
 * This makes CSS/JS cache busting deterministic between localhost and
 * production without requiring a manual version bump for every asset edit.
 *
 * @param string $relative_path Relative path inside the theme directory.
 * @return string
 */
function go_verge_asset_version( $relative_path ) {
	$relative_path = '/' . ltrim( (string) $relative_path, '/' );
	$absolute_path = GO_VERGE_DIR . $relative_path;

	if ( is_readable( $absolute_path ) ) {
		$modified_time = filemtime( $absolute_path );

		if ( false !== $modified_time ) {
			return (string) $modified_time;
		}
	}

	return GO_VERGE_VERSION;
}

/**
 * Read the bundled font-face stylesheet and replace relative font URLs with
 * absolute theme URLs before output. This keeps self-hosted fonts working even
 * when optimization plugins combine or relocate CSS into a cache directory.
 *
 * @return string
 */
function go_verge_get_font_faces_css() {
	$font_css_path = GO_VERGE_DIR . '/assets/css/verge-fonts.css';

	if ( ! is_readable( $font_css_path ) ) {
		return '';
	}

	$css = file_get_contents( $font_css_path );

	if ( false === $css || '' === trim( $css ) ) {
		return '';
	}

	$font_base_url = trailingslashit( GO_VERGE_URI ) . 'assets/fonts/';

	$css = str_replace(
		array(
			"url('../fonts/",
			'url("../fonts/',
			'url(../fonts/',
		),
		array(
			"url('" . $font_base_url,
			'url("' . $font_base_url,
			'url(' . $font_base_url,
		),
		$css
	);

	return $css;
}

/**
 * The visual wordmark shown in the logo lockups (header, footer, offcanvas,
 * homepage masthead). Kept as its own constant rather than reading
 * get_bloginfo( 'name' ) directly: the site's public identity for Google News
 * and schema.org is derived from the WordPress site name in inc/seo.php, so
 * this stays the single place that controls what the logo itself spells out.
 */
define( 'GO_VERGE_BRAND_NAME', 'Overdrive' );
/* A disambiguating fallback for Google's site-name systems. If the concise
 * primary name cannot be selected, prefer a human brand alias over the bare
 * domain. */
define( 'GO_VERGE_BRAND_ALTERNATE_NAME', 'Game Overdrive' );
define( 'GO_VERGE_BRAND_WORDMARK', 'OVERDRIVE' );

/**
 * Prepare an editorial game name for display without changing its casing.
 *
 * WordPress titles, legacy meta and external catalogues may provide either a
 * Unicode string or one/more layers of HTML entities. This function returns
 * plain text; callers must still escape it for the destination context
 * (`esc_html()`, `esc_attr()` or JSON encoding). Keeping decoding here, before
 * HTML is generated, prevents both visible entities and unsafe late decoding.
 *
 * @param mixed $value Raw title/name.
 * @return string Plain display text preserving editorial typography and case.
 */
if ( ! function_exists( 'go_verge_prepare_game_name' ) ) {
	function go_verge_prepare_game_name( $value ) {
		$charset = get_bloginfo( 'charset' ) ?: 'UTF-8';
		$value   = wp_check_invalid_utf8( (string) $value );

		// A bounded loop also handles historical values such as &amp;#8217;.
		for ( $pass = 0; $pass < 3; $pass++ ) {
			$decoded = html_entity_decode( $value, ENT_QUOTES | ENT_HTML5, $charset );
			if ( $decoded === $value ) {
				break;
			}
			$value = $decoded;
		}

		$value = wp_strip_all_tags( $value, true );
		$value = preg_replace( '/\s+/u', ' ', $value );
		return trim( (string) $value );
	}
}

/** Return the original WordPress game title prepared as plain display text. */
if ( ! function_exists( 'go_verge_game_name' ) ) {
	function go_verge_game_name( $game ) {
		$game_id = $game instanceof WP_Post ? (int) $game->ID : absint( $game );
		if ( $game_id && 'games' === get_post_type( $game_id ) ) {
			return go_verge_prepare_game_name( get_post_field( 'post_title', $game_id, 'raw' ) );
		}
		return go_verge_prepare_game_name( $game instanceof WP_Post ? $game->post_title : $game );
	}
}

/**
 * Return a lightweight, request-scoped catalogue for editor selectors.
 *
 * Several editorial metaboxes use the same Games/Entity lists. Querying and
 * priming those 300-item lists independently on one editor request adds server
 * time and hundreds of redundant cache operations. Keep one canonical query
 * per post type/status/order and skip meta/term cache priming because these
 * selectors only read ID/title.
 *
 * @param string       $post_type Post type.
 * @param int          $limit Maximum rows.
 * @param string|array $post_status Post status(es).
 * @return WP_Post[]
 */
if ( ! function_exists( 'go_verge_editor_catalog_posts' ) ) {
	function go_verge_editor_catalog_posts( $post_type, $limit = 300, $post_status = 'publish' ) {
		static $catalogues = array();

		$post_type = sanitize_key( (string) $post_type );
		$limit     = max( 1, min( 500, absint( $limit ) ) );
		$statuses  = array_values( array_filter( array_map( 'sanitize_key', (array) $post_status ) ) );
		if ( ! $post_type || ! post_type_exists( $post_type ) || ! $statuses ) {
			return array();
		}

		$key = $post_type . '|' . implode( ',', $statuses ) . '|' . $limit;
		if ( isset( $catalogues[ $key ] ) ) {
			return $catalogues[ $key ];
		}

		$query = new WP_Query(
			array(
				'post_type'              => $post_type,
				'post_status'            => 1 === count( $statuses ) ? $statuses[0] : $statuses,
				'posts_per_page'         => $limit,
				'orderby'                => 'title',
				'order'                  => 'ASC',
				'no_found_rows'          => true,
				'ignore_sticky_posts'    => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
				'lazy_load_term_meta'    => false,
				'suppress_filters'       => false,
			)
		);

		$catalogues[ $key ] = is_array( $query->posts ) ? $query->posts : array();
		return $catalogues[ $key ];
	}
}

/**
 * Resolve one stored editor subject reference without loading the full catalog.
 *
 * @param string $reference Canonical value (games:ID, go_entity:ID, post_tag:ID).
 * @return array<string,string>|null
 */
function go_verge_editor_catalog_selected_item( $reference ) {
	$reference = trim( (string) $reference );
	if ( ! preg_match( '/^(games|productions|go_entity|post_tag):(\d+)$/', $reference, $match ) ) {
		return null;
	}

	$type = (string) $match[1];
	$id   = absint( $match[2] );
	if ( ! $id ) {
		return null;
	}

	if ( 'post_tag' === $type ) {
		$term = get_term( $id, 'post_tag' );
		if ( ! ( $term instanceof WP_Term ) || is_wp_error( $term ) ) {
			return null;
		}
		return array(
			'value' => 'post_tag:' . $id,
			'text'  => (string) $term->name,
			'group' => __( 'Tags existentes', 'go-verge' ),
		);
	}

	$post = get_post( $id );
	if ( ! ( $post instanceof WP_Post ) || $type !== $post->post_type || 'publish' !== $post->post_status ) {
		return null;
	}

	$text = 'games' === $type && function_exists( 'go_verge_game_name' )
		? go_verge_game_name( $post )
		: get_the_title( $post );
	$groups = array(
		'games'       => __( 'Jogos', 'go-verge' ),
		'productions' => __( 'Produções', 'go-verge' ),
		'go_entity'   => __( 'Entidades', 'go-verge' ),
	);

	return array(
		'value' => $type . ':' . $id,
		'text'  => (string) $text,
		'group' => $groups[ $type ] ?? __( 'Resultados', 'go-verge' ),
	);
}

/**
 * Fast on-demand catalog search for editor selectors.
 *
 * Previously every post editor request rendered up to 2,300 option nodes
 * across the editorial/technical/subject panels. Besides the database work,
 * Gutenberg then had to parse, retain and repeatedly filter those nodes while
 * typing. Search is now performed only when an editor actually uses a selector.
 */
function go_verge_editor_catalog_search_ajax() {
	check_ajax_referer( 'go_verge_editor_catalog_search', 'nonce' );
	if ( ! current_user_can( 'edit_posts' ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão.', 'go-verge' ) ), 403 );
	}

	$query = isset( $_GET['q'] ) ? sanitize_text_field( wp_unslash( $_GET['q'] ) ) : '';
	$query = trim( preg_replace( '/\s+/u', ' ', $query ) );
	if ( function_exists( 'mb_strlen' ) ? mb_strlen( $query, 'UTF-8' ) < 2 : strlen( $query ) < 2 ) {
		wp_send_json_success( array( 'items' => array() ) );
	}

	$requested = isset( $_GET['types'] ) ? explode( ',', sanitize_text_field( wp_unslash( $_GET['types'] ) ) ) : array();
	$allowed   = array( 'games', 'productions', 'go_entity', 'post_tag' );
	$types     = array_values( array_intersect( $allowed, array_filter( array_map( 'sanitize_key', $requested ) ) ) );
	if ( ! $types ) {
		$types = array( 'games', 'productions', 'go_entity' );
	}

	$items = array();
	foreach ( array( 'games', 'productions', 'go_entity' ) as $post_type ) {
		if ( ! in_array( $post_type, $types, true ) || ! post_type_exists( $post_type ) ) {
			continue;
		}
		$results = new WP_Query(
			array(
				'post_type'              => $post_type,
				'post_status'            => 'publish',
				's'                      => $query,
				'posts_per_page'         => 12,
				'orderby'                => 'relevance',
				'order'                  => 'DESC',
				'no_found_rows'          => true,
				'ignore_sticky_posts'    => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
				'lazy_load_term_meta'    => false,
			)
		);
		foreach ( (array) $results->posts as $result ) {
			if ( ! ( $result instanceof WP_Post ) ) {
				continue;
			}
			$groups = array(
				'games'       => __( 'Jogos', 'go-verge' ),
				'productions' => __( 'Produções', 'go-verge' ),
				'go_entity'   => __( 'Entidades', 'go-verge' ),
			);
			$items[] = array(
				'value' => $post_type . ':' . (int) $result->ID,
				'text'  => 'games' === $post_type && function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $result ) : (string) $result->post_title,
				'group' => $groups[ $post_type ] ?? __( 'Resultados', 'go-verge' ),
			);
		}
	}

	if ( in_array( 'post_tag', $types, true ) ) {
		$terms = get_terms(
			array(
				'taxonomy'   => 'post_tag',
				'hide_empty' => false,
				'search'     => $query,
				'number'     => 12,
				'orderby'    => 'count',
				'order'      => 'DESC',
			)
		);
		if ( ! is_wp_error( $terms ) ) {
			foreach ( (array) $terms as $term ) {
				if ( ! ( $term instanceof WP_Term ) ) {
					continue;
				}
				$items[] = array(
					'value' => 'post_tag:' . (int) $term->term_id,
					'text'  => (string) $term->name,
					'group' => __( 'Tags existentes', 'go-verge' ),
				);
			}
		}
	}

	wp_send_json_success( array( 'items' => array_slice( $items, 0, 30 ) ) );
}
add_action( 'wp_ajax_go_verge_editor_catalog_search', 'go_verge_editor_catalog_search_ajax' );

/** Normalize Games CPT titles at the shared display boundary, never in storage. */
if ( ! function_exists( 'go_verge_filter_game_title_for_display' ) ) {
	function go_verge_filter_game_title_for_display( $title, $post_id = 0 ) {
		return $post_id && 'games' === get_post_type( $post_id )
			? go_verge_prepare_game_name( $title )
			: $title;
	}
}
add_filter( 'the_title', 'go_verge_filter_game_title_for_display', 20, 2 );

/**
 * Theme supports & core setup.
 */
function go_verge_setup() {
	load_theme_textdomain( 'go-verge', GO_VERGE_DIR . '/languages' );

	add_theme_support( 'automatic-feed-links' );
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'custom-logo', array(
		'height'      => 48,
		'width'       => 220,
		'flex-width'  => true,
		'flex-height' => true,
	) );
	add_theme_support( 'html5', array(
		'search-form', 'comment-form', 'comment-list', 'gallery', 'caption', 'style', 'script', 'navigation-widgets',
	) );
	add_theme_support( 'post-formats', array( 'gallery', 'video', 'quote', 'link', 'image', 'audio' ) );
	add_theme_support( 'responsive-embeds' );
	add_theme_support( 'align-wide' );
	add_theme_support( 'editor-styles' );
	add_editor_style( array( 'assets/css/verge-fonts.css', 'assets/css/go-editor.css' ) );

	// The Verge grid + image ratios.
	set_post_thumbnail_size( 640, 360, true );          // 16:9 feed default.
	add_image_size( 'go_hero', 1280, 720, true );        // 16:9 masthead hero / fast LCP.
	add_image_size( 'go_feed', 720, 540, true );         // 4:3 mid-feed.
	add_image_size( 'go_card', 640, 360, true );         // 16:9 story tile.
	add_image_size( 'go_square', 360, 360, true );       // 1:1 thumb / avatar.

	// Search/Discover schema crops. Kept separate from the front-end hero so
	// rich previews can use high-resolution alternatives without making LCP
	// download a 1600px asset on every article view. Existing uploads can be
	// backfilled once with a thumbnail regeneration job.
	add_image_size( 'go_discover_16x9', 1600, 900, true );
	add_image_size( 'go_discover_4x3', 1200, 900, true );
	add_image_size( 'go_discover_1x1', 1200, 1200, true );

	register_nav_menus( array(
		'primary' => __( 'Menu principal', 'go-verge' ),
		'footer'  => __( 'Menu de rodapé', 'go-verge' ),
		'social'  => __( 'Redes sociais', 'go-verge' ),
	) );
}
add_action( 'after_setup_theme', 'go_verge_setup' );


/**
 * Newsroom image defaults.
 *
 * WordPress ships with a 1024px `large` image. On a 16:9 source that becomes
 * 1024x576, which is below the 1200px width Google recommends for large image
 * previews. Keep the familiar `large` semantic for editors, but raise its
 * runtime ceiling to 1280px so new uploads no longer manufacture 1024x576 as
 * the principal editorial derivative.
 */
function go_verge_editorial_large_width( $pre = false ) {
	unset( $pre );
	return 1280;
}
function go_verge_editorial_large_height( $pre = false ) {
	unset( $pre );
	return 1280;
}
add_filter( 'pre_option_large_size_w', 'go_verge_editorial_large_width', 20 );
add_filter( 'pre_option_large_size_h', 'go_verge_editorial_large_height', 20 );

/**
 * Image blocks in posts should store the original asset, not WordPress' legacy
 * `large` URL. Responsive delivery still happens through srcset on the front
 * end, while crawlers and future reprocessing retain a >=1200px source URL.
 */
function go_verge_post_editor_image_default( $settings, $context ) {
	if ( ! is_array( $settings ) ) {
		return $settings;
	}
	if ( is_object( $context ) && ! empty( $context->post ) && 'post' === $context->post->post_type ) {
		$settings['imageDefaultSize'] = 'full';
	}
	return $settings;
}
add_filter( 'block_editor_settings_all', 'go_verge_post_editor_image_default', 20, 2 );

/**
 * Create the high-resolution story crops for legacy featured images when a
 * post is saved. New uploads already receive these sizes during upload.
 *
 * wp_update_image_subsizes() is deliberately narrowed to the two story sizes
 * so an old attachment cannot trigger an expensive regeneration of every size
 * registered by unrelated plugins.
 */
function go_verge_refresh_featured_discover_sizes( $post_id, $post = null, $update = false ) {
	unset( $update );
	if ( ! $post_id || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( ! $post instanceof WP_Post ) {
		$post = get_post( $post_id );
	}
	if ( ! $post instanceof WP_Post || 'post' !== $post->post_type ) {
		return;
	}

	$attachment_id = absint( get_post_thumbnail_id( $post_id ) );
	if ( ! $attachment_id || ! wp_attachment_is_image( $attachment_id ) ) {
		return;
	}

	$meta = wp_get_attachment_metadata( $attachment_id );
	if ( ! is_array( $meta ) || absint( $meta['width'] ?? 0 ) < 1200 ) {
		return;
	}

	if ( ! function_exists( 'wp_get_missing_image_subsizes' ) || ! function_exists( 'wp_update_image_subsizes' ) ) {
		require_once ABSPATH . 'wp-admin/includes/image.php';
	}
	if ( ! function_exists( 'wp_get_missing_image_subsizes' ) || ! function_exists( 'wp_update_image_subsizes' ) ) {
		return;
	}

	$missing = wp_get_missing_image_subsizes( $attachment_id );
	$wanted  = array_intersect_key( (array) $missing, array( 'go_hero' => true, 'go_discover_16x9' => true ) );
	if ( empty( $wanted ) ) {
		return;
	}

	$limit_missing = static function ( $sizes ) use ( $wanted ) {
		return array_intersect_key( (array) $sizes, $wanted );
	};
	add_filter( 'wp_get_missing_image_subsizes', $limit_missing, 999 );
	wp_update_image_subsizes( $attachment_id );
	remove_filter( 'wp_get_missing_image_subsizes', $limit_missing, 999 );
}
add_action( 'save_post_post', 'go_verge_refresh_featured_discover_sizes', 30, 3 );

/**
 * Ensure the volunteer contributor page exists.
 *
 * The page is created only when the slug does not exist, so later editorial
 * changes made in WordPress are never overwritten by a theme update.
 */
function go_verge_ensure_contributor_page() {
	/*
	 * This used to run on `init`, unguarded, which meant a get_page_by_path()
	 * lookup on every anonymous page view for the rest of the site's life — to
	 * answer a question ("does this page exist yet?") whose answer stops changing
	 * after the first time. The flag makes it a one-shot, and admin_init keeps
	 * post creation off public traffic entirely.
	 */
	if ( get_option( 'go_verge_contributor_page_created' ) ) {
		return;
	}

	$existing = get_page_by_path(
		'seja-colaborador',
		OBJECT,
		'page'
	);

	if ( $existing instanceof WP_Post ) {
		update_option( 'go_verge_contributor_page_created', 1, true );
		return;
	}

	$content = '<p>O Overdrive está aberto a pessoas que buscam a primeira oportunidade para publicar textos sobre games, entretenimento e tecnologia.</p>'
		. '<p>A colaboração é voluntária e não remunerada. O objetivo é oferecer espaço para quem quer ganhar experiência, montar portfólio e participar da rotina de um portal editorial.</p>'
		. '<p>Buscamos pessoas responsáveis, que escrevam bem, acompanhem os temas do site e tenham disponibilidade para produzir conteúdos com orientação da equipe.</p>'
		. '<p>Para participar, envie uma breve apresentação, os assuntos sobre os quais gostaria de escrever e, caso tenha, links de textos ou trabalhos anteriores.</p>'
		. '<p><a class="go-btn go-btn--mint" href="mailto:contato@gameoverdrive.com.br?subject=Quero%20colaborar%20com%20o%20Overdrive">Quero colaborar</a></p>';

	$created = wp_insert_post(
		array(
			'post_type'      => 'page',
			'post_status'    => 'publish',
			'post_title'     => 'Seja colaborador do Overdrive!',
			'post_name'      => 'seja-colaborador',
			'post_content'   => $content,
			'comment_status' => 'closed',
			'ping_status'    => 'closed',
		),
		true
	);

	if ( $created && ! is_wp_error( $created ) ) {
		update_option( 'go_verge_contributor_page_created', 1, true );
	}
}
add_action( 'admin_init', 'go_verge_ensure_contributor_page', 60 );
add_action( 'after_switch_theme', 'go_verge_ensure_contributor_page', 60 );

/**
 * Add the contributor page to a custom footer menu without duplicating it.
 *
 * The fallback footer already lists institutional pages from its own map.
 */
function go_verge_append_contributor_to_footer_menu( $items, $args ) {
	if (
		! isset( $args->theme_location )
		|| 'footer' !== $args->theme_location
		|| false !== strpos( $items, '/seja-colaborador/' )
	) {
		return $items;
	}

	$page = get_page_by_path(
		'seja-colaborador',
		OBJECT,
		'page'
	);

	if ( ! $page instanceof WP_Post || 'publish' !== $page->post_status ) {
		return $items;
	}

	$items .= sprintf(
		'<li class="menu-item menu-item-type-post_type menu-item-object-page"><a href="%1$s">%2$s</a></li>',
		esc_url( get_permalink( $page ) ),
		esc_html__( 'Seja colaborador', 'go-verge' )
	);

	return $items;
}
add_filter( 'wp_nav_menu_items', 'go_verge_append_contributor_to_footer_menu', 20, 2 );

/**
 * Editorial support line shown below the headline on single posts.
 *
 * The front end already reads the `_go_post_subtitle` key through
 * go_verge_subtitle(); this meta box exposes that field in the post editor.
 */
function go_verge_register_support_line_meta_box() {
	add_meta_box(
		'go-verge-support-line',
		__( 'Linha de Apoio editorial', 'go-verge' ),
		'go_verge_render_support_line_meta_box',
		'post',
		'normal',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_support_line_meta_box' );

/**
 * Render the editorial support-line field.
 *
 * @param WP_Post $post Current post.
 */
function go_verge_render_support_line_meta_box( $post ) {
	$value = get_post_meta( $post->ID, '_go_post_subtitle', true );
	wp_nonce_field( 'go_verge_save_support_line', 'go_verge_support_line_nonce' );
	?>
	<p>
		<label class="screen-reader-text" for="go-verge-support-line-field"><?php esc_html_e( 'Linha de Apoio editorial', 'go-verge' ); ?></label>
		<textarea
			id="go-verge-support-line-field"
			name="go_verge_support_line"
			rows="3"
			class="widefat"
			maxlength="320"
			placeholder="<?php echo esc_attr__( 'Texto que aparece logo abaixo do título da matéria.', 'go-verge' ); ?>"
		><?php echo esc_textarea( $value ); ?></textarea>
	</p>
	<?php
}

/**
 * Save the editorial support line securely.
 *
 * @param int $post_id Post ID.
 */
function go_verge_save_support_line_meta( $post_id ) {
	if ( ! isset( $_POST['go_verge_support_line_nonce'] ) ) {
		return;
	}

	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_support_line_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_support_line' ) ) {
		return;
	}

	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}

	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}

	if ( ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	/*
	 * Gutenberg does not guarantee that every legacy metabox field is included
	 * in every save request. An omitted field must never erase stored content.
	 */
	if ( ! isset( $_POST['go_verge_support_line'] ) ) {
		return;
	}

	$value = sanitize_textarea_field(
		wp_unslash(
			$_POST['go_verge_support_line']
		)
	);

	if ( '' === trim( $value ) ) {
		$dirty = isset( $_POST['go_editorial_dirty']['support'] )
			&& ! empty( $_POST['go_editorial_dirty']['support'] );

		if ( $dirty ) {
			delete_post_meta( $post_id, '_go_post_subtitle' );
			delete_post_meta( $post_id, '_go_editorial_backup_post_subtitle' );
		}
		return;
	}

	update_post_meta( $post_id, '_go_post_subtitle', $value );
	update_post_meta( $post_id, '_go_editorial_backup_post_subtitle', $value );
}
add_action( 'save_post_post', 'go_verge_save_support_line_meta' );


/**
 * General linked-game selector for every post type=post editorial workflow.
 * This is intentionally independent from Review/Crítica boxes so news, guides
 * and features can also be associated with a real Games CPT profile.
 */
function go_verge_register_linked_game_meta_box() {
	add_meta_box(
		'go-verge-linked-game',
		__( 'Game vinculado', 'go-verge' ),
		'go_verge_render_linked_game_meta_box',
		'post',
		'side',
		'high'
	);
}
// Legacy selector kept for backwards compatibility, but the canonical Game Intelligence box is registered in inc/game-intelligence.php.

/**
 * Render a searchable game selector using the actual Games CPT records.
 */
function go_verge_render_linked_game_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_linked_game', 'go_verge_linked_game_nonce' );

	$selected_id = absint( get_post_meta( $post->ID, 'go_linked_game_id', true ) );
	if ( ! $selected_id ) {
		$selected_id = absint( get_post_meta( $post->ID, 'go_review_game_id', true ) );
	}

	$games = get_posts(
		array(
			'post_type'      => 'games',
			'post_status'    => 'publish',
			'posts_per_page' => 300,
			'orderby'        => 'title',
			'order'          => 'ASC',
		)
	);

	?>
	<div class="go-linked-game-editor">
		<input type="search" id="go-linked-game-search" class="widefat" placeholder="<?php esc_attr_e( 'Buscar game…', 'go-verge' ); ?>" autocomplete="off" style="margin-bottom:8px;">
		<select id="go-linked-game-id" class="widefat" name="go_linked_game_id" size="8" style="min-height:180px;">
			<option value=""><?php esc_html_e( 'Nenhum game vinculado', 'go-verge' ); ?></option>
			<?php foreach ( $games as $game ) : ?>
				<option value="<?php echo esc_attr( $game->ID ); ?>" <?php selected( $selected_id, $game->ID ); ?>><?php echo esc_html( go_verge_game_name( $game ) ); ?></option>
			<?php endforeach; ?>
		</select>
	</div>
	<script>
	(function(){
		var search = document.getElementById('go-linked-game-search');
		var select = document.getElementById('go-linked-game-id');
		if (!search || !select || search.dataset.goBound === '1') return;
		search.dataset.goBound = '1';
		var source = Array.prototype.map.call(select.options, function(option){
			return { value: option.value, text: option.textContent, selected: option.selected };
		});
		function render(){
			var q = search.value.trim().toLocaleLowerCase('pt-BR');
			var current = select.value;
			select.innerHTML = '';
			source.forEach(function(item){
				if (item.value === '' || !q || item.text.toLocaleLowerCase('pt-BR').indexOf(q) !== -1 || item.value === current) {
					var option = document.createElement('option');
					option.value = item.value;
					option.textContent = item.text;
					option.selected = item.value === current || (!current && item.selected);
					select.appendChild(option);
				}
			});
		}
		search.addEventListener('input', render);
	})();
	</script>
	<?php
}

/**
 * Save the general linked-game relation. Keep the legacy review meta in sync
 * so older review rendering and existing integrations continue to work.
 */
function go_verge_save_linked_game_meta( $post_id ) {
	if ( ! isset( $_POST['go_verge_linked_game_nonce'] ) ) {
		return;
	}
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_linked_game_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_linked_game' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$game_id = isset( $_POST['go_linked_game_id'] ) ? absint( wp_unslash( $_POST['go_linked_game_id'] ) ) : 0;
	if ( $game_id && 'games' === get_post_type( $game_id ) ) {
		update_post_meta( $post_id, 'go_linked_game_id', $game_id );
		update_post_meta( $post_id, 'go_review_game_id', $game_id );
	} else {
		delete_post_meta( $post_id, 'go_linked_game_id' );
		delete_post_meta( $post_id, 'go_review_game_id' );
	}
}
// Legacy save callback is intentionally not hooked; Game Intelligence owns canonical persistence and keeps legacy meta in sync.


/**
 * Technical-sheet subject selector for Reviews and Críticas.
 * The subject is independent from the linked game so non-game reviews can
 * still render a useful technical sheet.
 */
function go_verge_register_technical_sheet_meta_box() {
	add_meta_box(
		'go-verge-technical-sheet-fields',
		__( 'Ficha técnica', 'go-verge' ),
		'go_verge_render_technical_sheet_meta_box',
		'post',
		'side',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_technical_sheet_meta_box' );

/**
 * Render the technical-sheet selector.
 *
 * @param WP_Post $post Current post.
 */
function go_verge_render_technical_sheet_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_technical_sheet', 'go_verge_technical_sheet_nonce' );

	$configured = metadata_exists( 'post', $post->ID, 'go_technical_sheet_configured' );
	$enabled    = '1' === (string) get_post_meta( $post->ID, 'go_technical_sheet_enabled', true );
	$reference  = (string) get_post_meta( $post->ID, 'go_technical_subject_ref', true );
	$custom     = (string) get_post_meta( $post->ID, 'go_technical_subject_custom', true );

	// New Review/Crítica posts start with the sheet enabled. Existing linked
	// games still become the preferred subject until the editor chooses another
	// reference explicitly.
	if ( ! $configured ) {
		$enabled = true;
		$linked_id = absint( get_post_meta( $post->ID, 'go_linked_game_id', true ) );
		if ( ! $linked_id ) {
			$linked_id = absint( get_post_meta( $post->ID, 'go_review_game_id', true ) );
		}
		$reference = $linked_id ? 'games:' . $linked_id : 'auto';
	}

	$selected_item = go_verge_editor_catalog_selected_item( $reference );
	?>
	<div class="go-technical-sheet-editor">
		<p style="margin:0 0 12px;">
			<label>
				<input type="checkbox" name="go_technical_sheet_enabled" value="1" <?php checked( $enabled ); ?>>
				<strong><?php esc_html_e( 'Exibir ficha técnica nesta review/crítica', 'go-verge' ); ?></strong>
			</label>
		</p>
		<p style="margin:0 0 8px;">
			<label for="go-technical-subject-search"><strong><?php esc_html_e( 'Assunto da ficha técnica', 'go-verge' ); ?></strong></label>
			<input type="search" id="go-technical-subject-search" class="widefat" placeholder="<?php esc_attr_e( 'Digite 2+ letras para buscar…', 'go-verge' ); ?>" autocomplete="off" style="margin-top:5px;" data-go-catalog-search data-go-catalog-target="go-technical-subject-ref" data-go-catalog-types="games,productions,go_entity">
		</p>
		<select id="go-technical-subject-ref" class="widefat" name="go_technical_subject_ref" size="6" style="min-height:148px;">
			<option data-go-catalog-static="1" value="auto" <?php selected( $reference, 'auto' ); ?>><?php esc_html_e( 'Automático (game/obra preenchida)', 'go-verge' ); ?></option>
			<option data-go-catalog-static="1" value="custom" <?php selected( $reference, 'custom' ); ?>><?php esc_html_e( 'Assunto personalizado', 'go-verge' ); ?></option>
			<?php if ( $selected_item ) : ?><option data-go-catalog-pinned="1" value="<?php echo esc_attr( $selected_item['value'] ); ?>" selected><?php echo esc_html( $selected_item['text'] ); ?></option><?php endif; ?>
		</select>
		<p id="go-technical-custom-wrap" style="margin:10px 0 0;<?php echo 'custom' === $reference ? '' : 'display:none;'; ?>">
			<label for="go-technical-subject-custom"><strong><?php esc_html_e( 'Nome do assunto', 'go-verge' ); ?></strong></label>
			<input type="text" id="go-technical-subject-custom" class="widefat" name="go_technical_subject_custom" value="<?php echo esc_attr( $custom ); ?>" placeholder="<?php esc_attr_e( 'Ex.: Final Fantasy, Duna, Arcane…', 'go-verge' ); ?>" style="margin-top:5px;">
		</p>
		<p class="description" style="margin-top:10px;"><?php esc_html_e( 'O assunto selecionado tem prioridade sobre o jogo vinculado. Ao preencher os dados da ficha técnica, ela também é exibida automaticamente.', 'go-verge' ); ?></p>
	</div>
	<script>
	(function(){
		var select=document.getElementById('go-technical-subject-ref'),custom=document.getElementById('go-technical-custom-wrap');
		if(!select||select.dataset.goToggleBound==='1')return;select.dataset.goToggleBound='1';
		function toggle(){if(custom)custom.style.display=select.value==='custom'?'':'none';}
		select.addEventListener('change',toggle);toggle();
	})();
	</script>
	<?php
}

/**
 * Save technical-sheet configuration.
 *
 * @param int $post_id Post ID.
 */
function go_verge_save_technical_sheet_meta( $post_id ) {
	if ( ! isset( $_POST['go_verge_technical_sheet_nonce'] ) ) {
		return;
	}
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_technical_sheet_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_technical_sheet' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$enabled   = isset( $_POST['go_technical_sheet_enabled'] ) ? '1' : '0';
	$reference = isset( $_POST['go_technical_subject_ref'] ) ? sanitize_text_field( wp_unslash( $_POST['go_technical_subject_ref'] ) ) : 'auto';
	$custom    = isset( $_POST['go_technical_subject_custom'] ) ? sanitize_text_field( wp_unslash( $_POST['go_technical_subject_custom'] ) ) : '';

	$valid_reference = in_array( $reference, array( 'auto', 'custom' ), true );
	if ( ! $valid_reference && preg_match( '/^(games|productions|go_entity):(\d+)$/', $reference, $matches ) ) {
		$object_id       = absint( $matches[2] );
		$valid_reference = $object_id && $matches[1] === get_post_type( $object_id ) && 'publish' === get_post_status( $object_id );
	}
	if ( ! $valid_reference ) {
		$reference = 'auto';
	}

	update_post_meta( $post_id, 'go_technical_sheet_configured', '1' );
	update_post_meta( $post_id, 'go_technical_sheet_enabled', $enabled );
	update_post_meta( $post_id, 'go_technical_subject_ref', $reference );
	if ( '' !== $custom ) {
		update_post_meta( $post_id, 'go_technical_subject_custom', $custom );
	} else {
		delete_post_meta( $post_id, 'go_technical_subject_custom' );
	}
}
add_action( 'save_post_post', 'go_verge_save_technical_sheet_meta' );


/**
 * Review editorial fields used by review singles.
 */
function go_verge_register_review_meta_box() {
	add_meta_box(
		'go-verge-review-fields',
		__( 'Review: avaliação editorial', 'go-verge' ),
		'go_verge_render_review_meta_box',
		'post',
		'normal',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_review_meta_box' );

/**
 * Render review fields in the post editor.
 */
function go_verge_render_review_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_review_fields', 'go_verge_review_fields_nonce' );
	$values = array(
		'game_name'       => get_post_meta( $post->ID, 'go_review_game_name', true ),
		'score'           => get_post_meta( $post->ID, 'nota', true ),
		'summary'         => get_post_meta( $post->ID, 'go_review_summary', true ),
		'verdict'         => get_post_meta( $post->ID, 'go_review_verdict', true ),
		'verdict_image_id' => absint( get_post_meta( $post->ID, 'go_review_verdict_image_id', true ) ),
		'pros'            => get_post_meta( $post->ID, 'go_review_pros', true ),
		'cons'            => get_post_meta( $post->ID, 'go_review_cons', true ),
		'platform'        => get_post_meta( $post->ID, 'review_platform', true ),
		'copy_provided'   => '1' === (string) get_post_meta( $post->ID, 'go_review_copy_provided', true ),
		'copy_provider'   => get_post_meta( $post->ID, 'go_review_copy_provider', true ),
	);
	$games = get_posts(
		array(
			'post_type'      => 'games',
			'post_status'    => 'publish',
			'posts_per_page' => 200,
			'orderby'        => 'title',
			'order'          => 'ASC',
		)
	);
	?>
	<div class="go-review-editor-fields" style="display:grid;gap:16px;">
		<div style="display:grid;grid-template-columns:minmax(0,1fr) 160px;gap:14px;">
			<p style="margin:0;">
				<label for="go-review-game-name"><strong><?php esc_html_e( 'Nome do jogo', 'go-verge' ); ?></strong></label>
				<input id="go-review-game-name" class="widefat" type="text" name="go_review_game_name" value="<?php echo esc_attr( $values['game_name'] ); ?>" placeholder="<?php esc_attr_e( 'Opcional. O tema tenta inferir pelo título.', 'go-verge' ); ?>">
			</p>
			<p style="margin:0;">
				<label for="go-review-score"><strong><?php esc_html_e( 'Nota', 'go-verge' ); ?></strong></label>
				<input id="go-review-score" class="widefat" type="number" min="0" max="10" step="0.1" name="go_review_score" value="<?php echo esc_attr( str_replace( ',', '.', (string) $values['score'] ) ); ?>" placeholder="0 a 10">
			</p>
		</div>
		<p style="margin:0;">
			<label for="go-review-platform"><strong><?php esc_html_e( 'Plataforma testada', 'go-verge' ); ?></strong></label>
			<input id="go-review-platform" class="widefat" type="text" name="go_review_platform" value="<?php echo esc_attr( $values['platform'] ); ?>" placeholder="<?php esc_attr_e( 'Ex.: PS5 Pro, PC (RTX 4070), Switch 2. Aparece na ficha da review.', 'go-verge' ); ?>">
		</p>
		<div style="display:grid;grid-template-columns:minmax(0,220px) minmax(0,1fr);gap:14px;align-items:end;padding:14px;border:1px solid #dcdcde;border-radius:6px;background:#f6f7f7;">
			<p style="margin:0 0 4px;">
				<label>
					<input type="checkbox" name="go_review_copy_provided" value="1" <?php checked( $values['copy_provided'] ); ?>>
					<strong><?php esc_html_e( 'Código cedido para análise', 'go-verge' ); ?></strong>
				</label>
			</p>
			<p style="margin:0;">
				<label for="go-review-copy-provider"><strong><?php esc_html_e( 'Fornecido por', 'go-verge' ); ?></strong></label>
				<input id="go-review-copy-provider" class="widefat" type="text" name="go_review_copy_provider" value="<?php echo esc_attr( $values['copy_provider'] ); ?>" placeholder="<?php esc_attr_e( 'Ex.: Nintendo, Electronic Arts ou assessoria responsável. Opcional.', 'go-verge' ); ?>">
			</p>
		</div>
		<p style="margin:0;">
			<label for="go-review-summary"><strong><?php esc_html_e( 'Resumo', 'go-verge' ); ?></strong></label>
			<textarea id="go-review-summary" class="widefat" rows="4" name="go_review_summary" placeholder="<?php esc_attr_e( 'Resumo curto da avaliação. Este campo alimenta o primeiro bloco da review.', 'go-verge' ); ?>"><?php echo esc_textarea( $values['summary'] ); ?></textarea>
		</p>
		<p style="margin:0;">
			<label for="go-review-verdict"><strong><?php esc_html_e( 'Veredito final', 'go-verge' ); ?></strong></label>
			<textarea id="go-review-verdict" class="widefat" rows="4" name="go_review_verdict" placeholder="<?php esc_attr_e( 'Texto exclusivo do veredito exibido ao fim da review.', 'go-verge' ); ?>"><?php echo esc_textarea( $values['verdict'] ); ?></textarea>
		</p>
		<div data-go-verdict-media style="display:grid;gap:8px;">
			<label><strong><?php esc_html_e( 'Imagem do veredito', 'go-verge' ); ?></strong></label>
			<input type="hidden" name="go_review_verdict_image_id" value="<?php echo esc_attr( $values['verdict_image_id'] ); ?>" data-go-verdict-media-id>
			<div data-go-verdict-media-preview style="max-width:360px;aspect-ratio:16/9;overflow:hidden;background:#f0f0f1;"><?php echo $values['verdict_image_id'] ? wp_get_attachment_image( $values['verdict_image_id'], 'medium_large', false, array( 'style' => 'width:100%;height:100%;object-fit:cover;display:block;', 'alt' => '' ) ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
			<p style="margin:0;"><button type="button" class="button" data-go-verdict-media-select><?php esc_html_e( 'Escolher imagem', 'go-verge' ); ?></button> <button type="button" class="button-link-delete" data-go-verdict-media-remove<?php echo $values['verdict_image_id'] ? '' : ' hidden'; ?>><?php esc_html_e( 'Usar imagem destacada', 'go-verge' ); ?></button></p>
			<p class="description" style="margin:0;"><?php esc_html_e( 'Se nenhuma imagem for escolhida, o tema usa a imagem destacada em alta resolução.', 'go-verge' ); ?></p>
		</div>
		<div style="display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:14px;">
			<p style="margin:0;">
				<label for="go-review-pros"><strong><?php esc_html_e( 'Prós', 'go-verge' ); ?></strong></label>
				<textarea id="go-review-pros" class="widefat" rows="7" name="go_review_pros" placeholder="<?php esc_attr_e( 'Um item por linha', 'go-verge' ); ?>"><?php echo esc_textarea( $values['pros'] ); ?></textarea>
			</p>
			<p style="margin:0;">
				<label for="go-review-cons"><strong><?php esc_html_e( 'Contras', 'go-verge' ); ?></strong></label>
				<textarea id="go-review-cons" class="widefat" rows="7" name="go_review_cons" placeholder="<?php esc_attr_e( 'Um item por linha', 'go-verge' ); ?>"><?php echo esc_textarea( $values['cons'] ); ?></textarea>
			</p>
		</div>
	</div>
	<?php
}

/**
 * Save review editor fields.
 */
function go_verge_save_review_fields( $post_id ) {
	if ( ! isset( $_POST['go_verge_review_fields_nonce'] ) ) {
		return;
	}
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_review_fields_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_review_fields' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$fields = array(
		'go_review_game_name' => array( 'source' => 'go_review_game_name', 'type' => 'text' ),
		'nota'                => array( 'source' => 'go_review_score', 'type' => 'score' ),
		'go_review_summary'   => array( 'source' => 'go_review_summary', 'type' => 'textarea' ),
		'go_review_verdict'   => array( 'source' => 'go_review_verdict', 'type' => 'textarea' ),
		'go_review_verdict_image_id' => array( 'source' => 'go_review_verdict_image_id', 'type' => 'id' ),
		'go_review_pros'      => array( 'source' => 'go_review_pros', 'type' => 'textarea' ),
		'go_review_cons'      => array( 'source' => 'go_review_cons', 'type' => 'textarea' ),
		'review_platform'     => array( 'source' => 'go_review_platform', 'type' => 'text' ),
		'go_review_copy_provider' => array( 'source' => 'go_review_copy_provider', 'type' => 'text' ),
	);

	foreach ( $fields as $meta_key => $config ) {
		$raw = isset( $_POST[ $config['source'] ] ) ? wp_unslash( $_POST[ $config['source'] ] ) : '';
		if ( 'id' === $config['type'] ) {
			$value = absint( $raw );
			if ( $value && ! wp_attachment_is_image( $value ) ) {
				$value = 0;
			}
		} elseif ( 'score' === $config['type'] ) {
			$score_raw = str_replace( ',', '.', trim( (string) $raw ) );
			$value     = is_numeric( $score_raw ) ? min( 10, max( 0, (float) $score_raw ) ) : '';
		} elseif ( 'textarea' === $config['type'] ) {
			$value = sanitize_textarea_field( $raw );
		} else {
			$value = sanitize_text_field( $raw );
		}

		if ( '' === $value || 0 === $value ) {
			delete_post_meta( $post_id, $meta_key );
		} else {
			update_post_meta( $post_id, $meta_key, $value );
		}
	}

	if ( isset( $_POST['go_review_copy_provided'] ) ) {
		update_post_meta( $post_id, 'go_review_copy_provided', '1' );
	} else {
		delete_post_meta( $post_id, 'go_review_copy_provided' );
	}
}
add_action( 'save_post_post', 'go_verge_save_review_fields' );


/**
 * Critique editorial fields. Kept separate from review data so cinema/TV
 * criticism never silently overwrites a game review.
 */
function go_verge_register_critique_meta_box() {
	add_meta_box(
		'go-verge-critique-fields',
		__( 'Crítica: avaliação editorial', 'go-verge' ),
		'go_verge_render_critique_meta_box',
		'post',
		'normal',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_critique_meta_box' );

/**
 * Render critique fields in the post editor.
 *
 * @param WP_Post $post Current post.
 */
function go_verge_render_critique_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_critique_fields', 'go_verge_critique_fields_nonce' );
	$values = array(
		'work_name'        => get_post_meta( $post->ID, 'go_critique_work_name', true ),
		'work_type'        => get_post_meta( $post->ID, 'go_critique_work_type', true ),
		'score'            => get_post_meta( $post->ID, 'go_critique_score', true ),
		'summary'          => get_post_meta( $post->ID, 'go_critique_summary', true ),
		'verdict'          => get_post_meta( $post->ID, 'go_critique_verdict', true ),
		'verdict_image_id' => absint( get_post_meta( $post->ID, 'go_critique_verdict_image_id', true ) ),
		'pros'             => get_post_meta( $post->ID, 'go_critique_pros', true ),
		'cons'             => get_post_meta( $post->ID, 'go_critique_cons', true ),
	);
	$types = array(
		''             => __( 'Selecione', 'go-verge' ),
		'filme'        => __( 'Filme', 'go-verge' ),
		'serie'        => __( 'Série', 'go-verge' ),
		'anime'        => __( 'Anime', 'go-verge' ),
		'documentario' => __( 'Documentário', 'go-verge' ),
		'outro'        => __( 'Outro', 'go-verge' ),
	);
	?>
	<div class="go-critique-editor-fields" style="display:grid;gap:16px;">
		<div style="display:grid;grid-template-columns:minmax(0,1fr) minmax(180px,.45fr) 160px;gap:14px;">
			<p style="margin:0;">
				<label for="go-critique-work-name"><strong><?php esc_html_e( 'Título da obra', 'go-verge' ); ?></strong></label>
				<input id="go-critique-work-name" class="widefat" type="text" name="go_critique_work_name" value="<?php echo esc_attr( $values['work_name'] ); ?>" placeholder="<?php esc_attr_e( 'Filme, série, anime ou outra obra analisada', 'go-verge' ); ?>">
			</p>
			<p style="margin:0;">
				<label for="go-critique-work-type"><strong><?php esc_html_e( 'Tipo', 'go-verge' ); ?></strong></label>
				<select id="go-critique-work-type" class="widefat" name="go_critique_work_type">
					<?php foreach ( $types as $value => $label ) : ?>
						<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $values['work_type'], $value ); ?>><?php echo esc_html( $label ); ?></option>
					<?php endforeach; ?>
				</select>
			</p>
			<p style="margin:0;">
				<label for="go-critique-score"><strong><?php esc_html_e( 'Nota', 'go-verge' ); ?></strong></label>
				<input id="go-critique-score" class="widefat" type="number" min="0" max="10" step="0.1" name="go_critique_score" value="<?php echo esc_attr( str_replace( ',', '.', (string) $values['score'] ) ); ?>" placeholder="0 a 10">
			</p>
		</div>
		<p style="margin:0;">
			<label for="go-critique-summary"><strong><?php esc_html_e( 'Vale a pena assistir?', 'go-verge' ); ?></strong></label>
			<textarea id="go-critique-summary" class="widefat" rows="4" name="go_critique_summary" placeholder="<?php esc_attr_e( 'Resumo curto da avaliação que aparece no primeiro bloco da crítica.', 'go-verge' ); ?>"><?php echo esc_textarea( $values['summary'] ); ?></textarea>
		</p>
		<p style="margin:0;">
			<label for="go-critique-verdict"><strong><?php esc_html_e( 'Veredito final', 'go-verge' ); ?></strong></label>
			<textarea id="go-critique-verdict" class="widefat" rows="4" name="go_critique_verdict" placeholder="<?php esc_attr_e( 'Texto exclusivo do veredito exibido ao fim da crítica.', 'go-verge' ); ?>"><?php echo esc_textarea( $values['verdict'] ); ?></textarea>
		</p>
		<div data-go-verdict-media style="display:grid;gap:8px;">
			<label><strong><?php esc_html_e( 'Imagem do veredito', 'go-verge' ); ?></strong></label>
			<input type="hidden" name="go_critique_verdict_image_id" value="<?php echo esc_attr( $values['verdict_image_id'] ); ?>" data-go-verdict-media-id>
			<div data-go-verdict-media-preview style="max-width:360px;aspect-ratio:16/9;overflow:hidden;background:#f0f0f1;"><?php echo $values['verdict_image_id'] ? wp_get_attachment_image( $values['verdict_image_id'], 'medium_large', false, array( 'style' => 'width:100%;height:100%;object-fit:cover;display:block;', 'alt' => '' ) ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
			<p style="margin:0;"><button type="button" class="button" data-go-verdict-media-select><?php esc_html_e( 'Escolher imagem', 'go-verge' ); ?></button> <button type="button" class="button-link-delete" data-go-verdict-media-remove<?php echo $values['verdict_image_id'] ? '' : ' hidden'; ?>><?php esc_html_e( 'Usar imagem destacada', 'go-verge' ); ?></button></p>
			<p class="description" style="margin:0;"><?php esc_html_e( 'Se nenhuma imagem for escolhida, o tema usa a imagem destacada em alta resolução.', 'go-verge' ); ?></p>
		</div>
		<div style="display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:14px;">
			<p style="margin:0;">
				<label for="go-critique-pros"><strong><?php esc_html_e( 'Pontos fortes', 'go-verge' ); ?></strong></label>
				<textarea id="go-critique-pros" class="widefat" rows="7" name="go_critique_pros" placeholder="<?php esc_attr_e( 'Um item por linha', 'go-verge' ); ?>"><?php echo esc_textarea( $values['pros'] ); ?></textarea>
			</p>
			<p style="margin:0;">
				<label for="go-critique-cons"><strong><?php esc_html_e( 'Pontos fracos', 'go-verge' ); ?></strong></label>
				<textarea id="go-critique-cons" class="widefat" rows="7" name="go_critique_cons" placeholder="<?php esc_attr_e( 'Um item por linha', 'go-verge' ); ?>"><?php echo esc_textarea( $values['cons'] ); ?></textarea>
			</p>
		</div>
	</div>
	<?php
}

/**
 * Save critique editor fields.
 *
 * @param int $post_id Post ID.
 */
function go_verge_save_critique_fields( $post_id ) {
	if ( ! isset( $_POST['go_verge_critique_fields_nonce'] ) ) {
		return;
	}
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_critique_fields_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_critique_fields' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$fields = array(
		'go_critique_work_name' => array( 'source' => 'go_critique_work_name', 'type' => 'text' ),
		'go_critique_work_type' => array( 'source' => 'go_critique_work_type', 'type' => 'text' ),
		'go_critique_score'     => array( 'source' => 'go_critique_score', 'type' => 'score' ),
		'go_critique_summary'   => array( 'source' => 'go_critique_summary', 'type' => 'textarea' ),
		'go_critique_verdict'   => array( 'source' => 'go_critique_verdict', 'type' => 'textarea' ),
		'go_critique_verdict_image_id' => array( 'source' => 'go_critique_verdict_image_id', 'type' => 'id' ),
		'go_critique_pros'      => array( 'source' => 'go_critique_pros', 'type' => 'textarea' ),
		'go_critique_cons'      => array( 'source' => 'go_critique_cons', 'type' => 'textarea' ),
	);

	foreach ( $fields as $meta_key => $config ) {
		$raw = isset( $_POST[ $config['source'] ] ) ? wp_unslash( $_POST[ $config['source'] ] ) : '';
		if ( 'id' === $config['type'] ) {
			$value = absint( $raw );
			if ( $value && ! wp_attachment_is_image( $value ) ) {
				$value = 0;
			}
		} elseif ( 'score' === $config['type'] ) {
			$score_raw = str_replace( ',', '.', trim( (string) $raw ) );
			$value     = is_numeric( $score_raw ) ? min( 10, max( 0, (float) $score_raw ) ) : '';
		} elseif ( 'textarea' === $config['type'] ) {
			$value = sanitize_textarea_field( $raw );
		} else {
			$value = sanitize_text_field( $raw );
		}

		if ( '' === $value || 0 === $value ) {
			delete_post_meta( $post_id, $meta_key );
		} else {
			update_post_meta( $post_id, $meta_key, $value );
		}
	}
}
add_action( 'save_post_post', 'go_verge_save_critique_fields' );

/** Load the media picker used by the review and criticism verdict fields. */
function go_verge_review_verdict_media_admin_assets( $hook_suffix ) {
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = get_current_screen();
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}
	wp_enqueue_media();
	wp_enqueue_script(
		'go-verge-review-verdict-media',
		GO_VERGE_URI . '/assets/js/review-verdict-media.js',
		array(),
		go_verge_asset_version( '/assets/js/review-verdict-media.js' ),
		true
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_review_verdict_media_admin_assets', 55 );

/**
 * Resolve category IDs used to toggle editorial fields in the editor.
 * Descendants are included so a subcategory of Reviews/Críticas behaves
 * naturally without duplicating configuration.
 *
 * @param array $aliases Category slug aliases.
 * @return array
 */
function go_verge_editor_category_ids( $aliases ) {
	static $cache = array();
	$normalized = array_values( array_unique( array_filter( array_map( 'sanitize_title', (array) $aliases ) ) ) );
	sort( $normalized, SORT_STRING );
	$cache_key = implode( '|', $normalized );
	if ( isset( $cache[ $cache_key ] ) ) {
		return $cache[ $cache_key ];
	}

	$ids = array();
	foreach ( $normalized as $alias ) {
		$term = get_term_by( 'slug', $alias, 'category' );
		if ( ! $term || is_wp_error( $term ) ) {
			continue;
		}
		$ids[] = (int) $term->term_id;
		$children = get_term_children( $term->term_id, 'category' );
		if ( ! is_wp_error( $children ) ) {
			$ids = array_merge( $ids, array_map( 'intval', $children ) );
		}
	}
	$cache[ $cache_key ] = array_values( array_unique( array_filter( array_map( 'intval', $ids ) ) ) );
	return $cache[ $cache_key ];
}

/** Resolve exact term IDs from a non-hierarchical editorial taxonomy. */
function go_verge_editor_taxonomy_term_ids( $taxonomy, $slugs ) {
	$taxonomy = sanitize_key( $taxonomy );
	if ( ! $taxonomy || ! taxonomy_exists( $taxonomy ) ) { return array(); }
	$ids = array();
	foreach ( array_values( array_unique( array_filter( array_map( 'sanitize_title', (array) $slugs ) ) ) ) as $slug ) {
		$term = get_term_by( 'slug', $slug, $taxonomy );
		if ( $term instanceof WP_Term ) { $ids[] = (int) $term->term_id; }
	}
	return array_values( array_unique( array_filter( $ids ) ) );
}

/**
 * Enqueue the free local image AI runtime used by post editor and media UI.
 * The model runs in the editor browser and does not require a paid API key.
 *
 * @param int $post_id Current post ID when available.
 */
function go_verge_enqueue_local_ai_image_text_script( $post_id = 0 ) {
	wp_enqueue_script(
		'go-verge-local-ai-image-text',
		GO_VERGE_URI . '/assets/js/local-ai-image-text.js',
		array( 'wp-api-fetch', 'wp-data' ),
		go_verge_asset_version( '/assets/js/local-ai-image-text.js' ),
		true
	);

	wp_localize_script(
		'go-verge-local-ai-image-text',
		'GoVergeLocalAIConfig',
		array(
			'postId'          => absint( $post_id ),
			'transformersUrl' => 'https://cdn.jsdelivr.net/npm/@xenova/transformers@2.17.2',
			'visionModel'     => 'Xenova/vit-gpt2-image-captioning',
			'visionModels'    => array( 'Xenova/vit-gpt2-image-captioning' ),
			'objectModel'     => 'Xenova/detr-resnet-50',
			'translationModel'=> 'Xenova/opus-mt-en-pt',
			'contextEndpoint' => '/go-verge/v1/local-image-ai-context',
			'saveEndpoint'    => '/go-verge/v1/save-local-image-text',
		)
	);
}

/**
 * Editor-only assets: conditional Review/Crítica boxes.
 *
 * @param string $hook_suffix Current admin page.
 */
function go_verge_editorial_fields_admin_assets( $hook_suffix ) {
	// Lume owns the article editor UI. Keep this legacy workspace
	// only as a fallback when the plugin is inactive; otherwise its V12 dependency
	// can recreate the retired command bar after a late enqueue.
	if ( defined( 'GED_VERSION' ) ) {
		return;
	}
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = get_current_screen();
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}

	wp_enqueue_script(
		'go-verge-editor-catalog-search',
		GO_VERGE_URI . '/assets/js/editor-catalog-search.js',
		array(),
		go_verge_asset_version( '/assets/js/editor-catalog-search.js' ),
		true
	);
	wp_localize_script(
		'go-verge-editor-catalog-search',
		'GoVergeEditorCatalogSearch',
		array(
			'ajaxUrl' => admin_url( 'admin-ajax.php' ),
			'nonce'   => wp_create_nonce( 'go_verge_editor_catalog_search' ),
		)
	);

	wp_enqueue_script(
		'go-verge-editor-fields',
		GO_VERGE_URI . '/assets/js/editor-fields.js',
		array(),
		go_verge_asset_version( '/assets/js/editor-fields.js' ),
		true
	);
	wp_localize_script(
		'go-verge-editor-fields',
		'GoVergeEditorFields',
		array(
			/* Review/Crítica boxes are driven by Formato, never by category. */
			'reviewContentTypeIds'   => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'review' ) ),
			'critiqueContentTypeIds' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'critica' ) ),
			'editorialTypes'         => array(
				'news'        => array( 'label' => __( 'Notícia', 'go-verge' ), 'slug' => 'noticia', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'noticia' ) ) ),
				'guide'       => array( 'label' => __( 'Guia', 'go-verge' ), 'slug' => 'guia', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'guia' ) ) ),
				'review'      => array( 'label' => __( 'Review', 'go-verge' ), 'slug' => 'review', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'review' ) ) ),
				'critique'    => array( 'label' => __( 'Crítica', 'go-verge' ), 'slug' => 'critica', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'critica' ) ) ),
				'list'        => array( 'label' => __( 'Lista', 'go-verge' ), 'slug' => 'lista', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'lista' ) ) ),
				'special'     => array( 'label' => __( 'Especial', 'go-verge' ), 'slug' => 'especial', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'especial' ) ) ),
				'final'       => array( 'label' => __( 'Final explicado', 'go-verge' ), 'slug' => 'final-explicado', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'final-explicado' ) ) ),
				'impressions' => array( 'label' => __( 'Impressões', 'go-verge' ), 'slug' => 'impressoes', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'impressoes' ) ) ),
				'offer'       => array( 'label' => __( 'Oferta', 'go-verge' ), 'slug' => 'oferta', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'oferta' ) ) ),
				'buyingGuide' => array( 'label' => __( 'Guia de compra', 'go-verge' ), 'slug' => 'guia-de-compra', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'guia-de-compra' ) ) ),
				'ranking'     => array( 'label' => __( 'Ranking', 'go-verge' ), 'slug' => 'ranking', 'ids' => go_verge_editor_taxonomy_term_ids( 'go_content_type', array( 'ranking' ) ) ),
			),
		)
	);

	wp_enqueue_style(
		'go-verge-editor-workflow',
		GO_VERGE_URI . '/assets/css/editor-workflow.css',
		array(),
		go_verge_asset_version( '/assets/css/editor-workflow.css' )
	);

	wp_enqueue_style(
		'go-verge-editor-workspace',
		GO_VERGE_URI . '/assets/css/editor-workspace.css',
		array( 'go-verge-editor-workflow' ),
		go_verge_asset_version( '/assets/css/editor-workspace.css' )
	);

	$current_post_id = isset( $_GET['post'] ) ? absint( wp_unslash( $_GET['post'] ) ) : 0;
	if ( ! $current_post_id && isset( $GLOBALS['post'] ) && $GLOBALS['post'] instanceof WP_Post ) {
		$current_post_id = (int) $GLOBALS['post']->ID;
	}
	go_verge_enqueue_local_ai_image_text_script( $current_post_id );

	wp_enqueue_script(
		'go-verge-editor-workflow',
		GO_VERGE_URI . '/assets/js/editor-workflow.js',
		array(
			'go-verge-local-ai-image-text',
			'wp-api-fetch',
			'wp-block-editor',
			'wp-components',
			'wp-compose',
			'wp-core-data',
			'wp-data',
			'wp-edit-post',
			'wp-element',
			'wp-hooks',
			'wp-i18n',
			'wp-plugins',
			'wp-rich-text',
		),
		go_verge_asset_version( '/assets/js/editor-workflow.js' ),
		true
	);

	wp_localize_script(
		'go-verge-editor-workflow',
		'GoVergeEditorWorkflow',
		array(
			'postId'                => $current_post_id,
			'saveImageTextEndpoint' => '/go-verge/v1/save-local-image-text',
		)
	);

	wp_enqueue_script(
		'go-verge-editor-workspace',
		GO_VERGE_URI . '/assets/js/editor-workspace.js',
		array( 'go-verge-editor-fields', 'go-verge-editor-workflow' ),
		go_verge_asset_version( '/assets/js/editor-workspace.js' ),
		true
	);

	// X publishing controls are localized separately so the editorial workspace
	// can expose a reliable action even when Gutenberg does not render legacy
	// metaboxes in the expected position. No secret credential is sent here.
	$go_x_post_id = $current_post_id;
	if ( ! $go_x_post_id && isset( $GLOBALS['post'] ) && $GLOBALS['post'] instanceof WP_Post ) {
		$go_x_post_id = (int) $GLOBALS['post']->ID;
	}
	if ( function_exists( 'go_x_get_settings' ) ) {
		$go_x_settings = go_x_get_settings();
		wp_localize_script(
			'go-verge-editor-workspace',
			'GoVergeXEditor',
			array(
				'postId'         => absint( $go_x_post_id ),
				'ajaxUrl'        => admin_url( 'admin-ajax.php' ),
				'nonce'          => wp_create_nonce( 'go_x_editor_action' ),
				'enabled'        => ! empty( $go_x_settings['enabled'] ),
				'hasCredentials' => function_exists( 'go_x_has_credentials' ) ? go_x_has_credentials() : false,
				'settingsUrl'    => admin_url( 'options-general.php?page=go-x-autopublish' ),
				'postStatus'     => $go_x_post_id ? get_post_status( $go_x_post_id ) : 'auto-draft',
				'status'         => $go_x_post_id ? (string) get_post_meta( $go_x_post_id, '_go_x_status', true ) : '',
				'error'          => $go_x_post_id ? (string) get_post_meta( $go_x_post_id, '_go_x_error', true ) : '',
				'remoteId'       => $go_x_post_id ? (string) get_post_meta( $go_x_post_id, '_go_x_post_id', true ) : '',
				'text'           => $go_x_post_id ? (string) get_post_meta( $go_x_post_id, '_go_x_text', true ) : '',
				'auto'           => $go_x_post_id && function_exists( 'go_x_post_default' ) ? ( '1' === (string) go_x_post_default( $go_x_post_id, '_go_x_auto' ) ) : ! empty( $go_x_settings['default_auto'] ),
				'image'          => $go_x_post_id && function_exists( 'go_x_post_default' ) ? ( '1' === (string) go_x_post_default( $go_x_post_id, '_go_x_image' ) ) : ! empty( $go_x_settings['default_image'] ),
			)
		);
	}
}
add_action( 'admin_enqueue_scripts', 'go_verge_editorial_fields_admin_assets' );

/**
 * Load the AI image-text click handler anywhere WordPress exposes media
 * attachment details. This keeps the button functional in Media Library,
 * attachment screens and post editors.
 *
 * @param string $hook_suffix Current admin hook.
 */
function go_verge_ai_image_text_admin_assets( $hook_suffix ) {
	if ( ! current_user_can( 'upload_files' ) ) {
		return;
	}

	$allowed_hooks = array( 'upload.php', 'media-new.php', 'post.php', 'post-new.php' );
	if ( ! in_array( $hook_suffix, $allowed_hooks, true ) ) {
		return;
	}

	wp_enqueue_style(
		'go-verge-editor-workflow',
		GO_VERGE_URI . '/assets/css/editor-workflow.css',
		array(),
		go_verge_asset_version( '/assets/css/editor-workflow.css' )
	);

	$current_post_id = isset( $_GET['post'] ) ? absint( wp_unslash( $_GET['post'] ) ) : 0;
	if ( ! $current_post_id && isset( $GLOBALS['post'] ) && $GLOBALS['post'] instanceof WP_Post ) {
		$current_post_id = (int) $GLOBALS['post']->ID;
	}
	go_verge_enqueue_local_ai_image_text_script( $current_post_id );

	wp_enqueue_script(
		'go-verge-ai-image-text-media',
		GO_VERGE_URI . '/assets/js/ai-image-text-media.js',
		array( 'go-verge-local-ai-image-text', 'wp-api-fetch', 'wp-data' ),
		go_verge_asset_version( '/assets/js/ai-image-text-media.js' ),
		true
	);

	wp_localize_script(
		'go-verge-ai-image-text-media',
		'GoVergeAIImageText',
		array(
			'postId' => $current_post_id,
		)
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_ai_image_text_admin_assets', 30 );


/**
 * Register AI settings for editorial image text generation.
 */
function go_verge_register_ai_image_text_settings() {
	add_settings_section(
		'go_verge_ai_image_text_section',
		__( 'IA local gratuita para imagens', 'go-verge' ),
		'go_verge_render_local_ai_image_text_section',
		'media'
	);
}
add_action( 'admin_init', 'go_verge_register_ai_image_text_settings' );

/**
 * Render the free local AI explanation on Media settings.
 */
function go_verge_render_local_ai_image_text_section() {
	?>
	<div id="go-verge-ai-image-text" style="max-width:760px">
		<p><strong><?php esc_html_e( 'Sem API Key e sem cobrança por geração.', 'go-verge' ); ?></strong></p>
		<p><?php esc_html_e( 'O editor baixa um modelo de visão no primeiro uso e executa a análise no navegador. O modelo fica em cache para os próximos usos. A imagem é cruzada com o título, o texto da matéria, o game vinculado e o contexto próximo do bloco.', 'go-verge' ); ?></p>
		<p><?php esc_html_e( 'O primeiro uso pode ser mais lento porque os arquivos do modelo precisam ser baixados. A geração exige navegador moderno e conexão com a internet para o download inicial.', 'go-verge' ); ?></p>
	</div>
	<?php
}

/**
 * Normalise human-facing text used by editor workflow helpers.
 *
 * @param string $text Raw text.
 * @return string
 */
function go_verge_normalize_editorial_text( $text ) {
	$charset = get_bloginfo( 'charset' );
	$charset = $charset ? $charset : 'UTF-8';
	$text    = html_entity_decode( wp_strip_all_tags( (string) $text ), ENT_QUOTES, $charset );
	$text    = preg_replace( '/\s+/u', ' ', $text );

	return trim( (string) $text, " \t
\r\0\x0B-–—|_:;,." );
}


/**
 * Remove editorial AI-origin markers from human-facing image metadata.
 *
 * Older iterations of the media helper could leave prefixes or suffixes such
 * as "Gerado por IA" around suggestions. The current workflow must never
 * persist those implementation markers in title, alt text or captions.
 *
 * This helper intentionally changes only explicit origin markers. Mentions of
 * IA/AI that are part of the actual editorial text remain untouched.
 *
 * @param string $text Raw image metadata.
 * @return string
 */
if ( ! function_exists( 'go_verge_strip_ai_marker_text' ) ) {
	function go_verge_strip_ai_marker_text( $text ) {
		$text = (string) $text;
		if ( '' === trim( $text ) ) {
			return '';
		}

		$patterns = array(
			'/^\s*(?:\[(?:gerado|criado|sugerido)\s+por\s+(?:ia|ai)\]|\((?:gerado|criado|sugerido)\s+por\s+(?:ia|ai)\)|(?:gerado|criado|sugerido)\s+por\s+(?:ia|ai)|(?:ia|ai)\s*(?:gerada?|generated)?\s*[:\-–—])\s*/iu',
			'/\s*(?:\[(?:gerado|criado|sugerido)\s+por\s+(?:ia|ai)\]|\((?:gerado|criado|sugerido)\s+por\s+(?:ia|ai)\)|[|·•\-–—]\s*(?:gerado|criado|sugerido)\s+por\s+(?:ia|ai))\s*$/iu',
		);

		foreach ( $patterns as $pattern ) {
			$cleaned = preg_replace( $pattern, '', $text );
			if ( null !== $cleaned ) {
				$text = $cleaned;
			}
		}

		$text = preg_replace( '/\s+/u', ' ', $text );
		return trim( (string) $text, " \t
\r\0\x0B-–—|_:;,." );
	}
}

/**
 * Detect media labels that are effectively filenames or camera defaults.
 *
 * @param string $text Candidate text.
 * @return bool
 */
function go_verge_is_generic_media_text( $text ) {
	$text = go_verge_normalize_editorial_text( $text );
	if ( '' === $text || strlen( $text ) < 3 ) {
		return true;
	}

	$plain = remove_accents( strtolower( $text ) );
	$plain = preg_replace( '/\.(?:jpe?g|png|webp|gif|avif)$/i', '', $plain );
	$plain = preg_replace( '/[\s_-]+/', ' ', (string) $plain );
	$plain = trim( (string) $plain );

	if ( preg_match( '/^(?:img|image|imagem|foto|photo|picture|screenshot|captura|arquivo|upload|whatsapp|dsc|dscn|pxl)[\s_-]*\d*[a-z0-9-]*$/i', $plain ) ) {
		return true;
	}

	return (bool) preg_match( '/^(?:\d{6,}|[a-f0-9]{12,})$/i', $plain );
}

/**
 * Build a readable subject from the attachment filename without inventing
 * visual facts that are not present in WordPress metadata.
 *
 * @param int $attachment_id Attachment ID.
 * @return string
 */
function go_verge_attachment_filename_subject( $attachment_id ) {
	$file = get_attached_file( $attachment_id );
	if ( ! $file ) {
		return '';
	}

	$name = pathinfo( $file, PATHINFO_FILENAME );
	$name = preg_replace( '/-\d+x\d+$/i', '', (string) $name );
	$name = preg_replace( '/(?:-|_)(?:copy|copia|final|edit|edited|novo|new|v\d+)$/i', '', (string) $name );
	$name = preg_replace( '/[_-]+/', ' ', (string) $name );
	$name = preg_replace( '/\b(?:img|image|imagem|foto|photo|picture|screenshot|captura|arquivo|upload)\b/i', ' ', (string) $name );
	$name = preg_replace( '/\s+/u', ' ', (string) $name );
	$name = trim( (string) $name );

	if ( go_verge_is_generic_media_text( $name ) ) {
		return '';
	}

	return go_verge_normalize_editorial_text( $name );
}

/**
 * Resolve the linked game title for contextual editorial suggestions.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_editor_linked_game_title( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$game_id = absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	if ( ! $game_id ) {
		$game_id = absint( get_post_meta( $post_id, 'go_review_game_id', true ) );
	}

	return $game_id ? go_verge_normalize_editorial_text( get_the_title( $game_id ) ) : '';
}

/**
 * Resolve the editorial focus keyword, prioritising Rank Math and falling back
 * to other common SEO fields when needed.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_editor_focus_keyword( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$keys = array(
		'rank_math_focus_keyword',
		'_rank_math_focus_keyword',
		'rank_math_focus_keyword_slug',
		'_yoast_wpseo_focuskw',
	);

	foreach ( $keys as $meta_key ) {
		$value = go_verge_normalize_editorial_text( get_post_meta( $post_id, $meta_key, true ) );
		if ( '' !== $value ) {
			if ( false !== strpos( $value, ',' ) ) {
				$parts = array_filter( array_map( 'trim', explode( ',', $value ) ) );
				if ( ! empty( $parts ) ) {
					$value = (string) reset( $parts );
				}
			}
			return $value;
		}
	}

	return '';
}


/**
 * Resolve a meta description for the current post when available.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_editor_meta_description( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$keys = array(
		'rank_math_description',
		'_rank_math_description',
		'_yoast_wpseo_metadesc',
	);

	foreach ( $keys as $meta_key ) {
		$value = go_verge_normalize_editorial_text( get_post_meta( $post_id, $meta_key, true ) );
		if ( '' !== $value ) {
			return $value;
		}
	}

	return '';
}

/**
 * Resolve only a dedicated editorial support line, never the WordPress excerpt.
 *
 * Several generations of the newsroom stored the same field under different
 * keys. Keeping the aliases here lets old articles benefit from the same Search
 * description policy without a database migration.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_editor_support_line( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$keys = array(
		'_go_post_subtitle',
		'go_verge_support_line',
		'go_post_subtitle',
		'_subtitle',
	);

	foreach ( $keys as $meta_key ) {
		$value = go_verge_normalize_editorial_text( get_post_meta( $post_id, $meta_key, true ) );
		if ( '' !== $value ) {
			return $value;
		}
	}

	return '';
}

/**
 * Search-snippet description chosen by the newsroom.
 *
 * Priority is intentionally strict:
 * 1. explicit SEO meta description;
 * 2. editorial support line;
 * 3. WordPress excerpt (manual excerpt first; generated excerpt when needed).
 *
 * The excerpt is a fallback only. This keeps the newsroom's explicit Search
 * description and support line authoritative while preserving WordPress's
 * normal excerpt behavior for older posts that do not have either field.
 * Search engines can still rewrite a snippet for a specific query.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_preferred_search_description( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$text = go_verge_editor_meta_description( $post_id );
	if ( '' === $text ) {
		$text = go_verge_editor_support_line( $post_id );
	}

	if ( '' === $text ) {
		$text = get_the_excerpt( $post_id );
	}

	$text = go_verge_normalize_editorial_text( $text );
	if ( '' === $text ) {
		return '';
	}

	if ( function_exists( 'mb_strimwidth' ) ) {
		return mb_strimwidth( $text, 0, 158, '…', 'UTF-8' );
	}

	return strlen( $text ) > 158 ? rtrim( substr( $text, 0, 157 ) ) . '…' : $text;
}

/**
 * Generate contextual alt text and a caption suggestion using only grounded
 * WordPress metadata and current editorial context. No image contents or
 * credits are fabricated.
 *
 * @param int    $attachment_id Attachment ID.
 * @param int    $post_id       Current post ID.
 * @param string $context       Optional nearby block text/caption.
 * @return array
 */
function go_verge_generate_contextual_image_text( $attachment_id, $post_id = 0, $context = '' ) {
	$attachment_id = absint( $attachment_id );
	$post_id       = absint( $post_id );

	$existing_alt     = go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( get_post_meta( $attachment_id, '_wp_attachment_image_alt', true ) ) );
	$existing_caption = go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( wp_get_attachment_caption( $attachment_id ) ) );
	$attachment_title = go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( get_the_title( $attachment_id ) ) );
	$filename_subject = go_verge_attachment_filename_subject( $attachment_id );
	$context          = go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( $context ) );
	$post_title       = $post_id ? go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( get_the_title( $post_id ) ) ) : '';
	$game_title       = go_verge_editor_linked_game_title( $post_id );

	$candidates = array(
		'alt existente'     => $existing_alt,
		'legenda existente' => $existing_caption,
		'contexto do bloco'  => $context,
		'título da mídia'    => $attachment_title,
		'nome do arquivo'    => $filename_subject,
	);

	$subject = '';
	$basis   = '';
	foreach ( $candidates as $candidate_basis => $candidate ) {
		if ( '' !== $candidate && ! go_verge_is_generic_media_text( $candidate ) ) {
			$subject = $candidate;
			$basis   = $candidate_basis;
			break;
		}
	}

	if ( '' === $subject && '' !== $game_title ) {
		$subject = sprintf( 'Imagem relacionada a %s', $game_title );
		$basis   = 'game vinculado';
	} elseif ( '' === $subject && '' !== $post_title ) {
		$subject = sprintf( 'Imagem relacionada à matéria “%s”', $post_title );
		$basis   = 'título da matéria';
	} elseif ( '' === $subject ) {
		$subject = 'Imagem da matéria';
		$basis   = 'fallback neutro';
	}

	if ( function_exists( 'mb_substr' ) ) {
		$alt = mb_substr( $subject, 0, 180 );
	} else {
		$alt = substr( $subject, 0, 180 );
	}
	$alt = rtrim( $alt, " .,:;" );

	if ( '' !== $existing_caption && ! go_verge_is_generic_media_text( $existing_caption ) ) {
		$caption = $existing_caption;
	} else {
		$caption = $subject;
		if ( '' !== $game_title && false === stripos( remove_accents( $caption ), remove_accents( $game_title ) ) ) {
			$caption .= sprintf( '. Imagem relacionada a %s', $game_title );
		} elseif ( '' === $game_title && '' !== $post_title && false === stripos( remove_accents( $caption ), remove_accents( $post_title ) ) ) {
			$caption .= sprintf( '. Imagem relacionada à matéria “%s”', $post_title );
		}
	}

	$caption = preg_replace( '/\s+/u', ' ', (string) $caption );
	$caption = trim( (string) $caption );
	if ( '' !== $caption && ! preg_match( '/[.!?]$/u', $caption ) ) {
		$caption .= '.';
	}

	return array(
		'alt'     => sanitize_text_field( $alt ),
		'caption' => sanitize_text_field( $caption ),
		'basis'   => sanitize_text_field( $basis ),
	);
}

/**
 * REST permissions for editor workflow helpers.
 *
 * @return bool
 */
function go_verge_editor_workflow_permission() {
	return current_user_can( 'edit_posts' );
}

/**
 * Search public internal content for the enhanced hyperlink picker.
 *
 * @param WP_REST_Request $request REST request.
 * @return WP_REST_Response
 */
function go_verge_rest_link_search( WP_REST_Request $request ) {
	$search = sanitize_text_field( (string) $request->get_param( 'search' ) );
	$limit  = absint( $request->get_param( 'limit' ) );
	$limit  = min( 12, max( 1, $limit ? $limit : 8 ) );

	if ( strlen( $search ) < 2 ) {
		return rest_ensure_response( array() );
	}

	$post_types = get_post_types(
		array(
			'public'       => true,
			'show_in_rest' => true,
		),
		'names'
	);
	unset( $post_types['attachment'] );

	$query = new WP_Query(
		array(
			's'                   => $search,
			'post_type'           => array_values( $post_types ),
			'post_status'         => 'publish',
			'posts_per_page'      => $limit,
			'orderby'             => 'relevance',
			'order'               => 'DESC',
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
		)
	);

	$results = array();
	foreach ( $query->posts as $result_post ) {
		$type_object = get_post_type_object( $result_post->post_type );
		$charset     = get_bloginfo( 'charset' );
		$charset     = $charset ? $charset : 'UTF-8';
		$results[]   = array(
			'id'    => (int) $result_post->ID,
			'title' => html_entity_decode( wp_strip_all_tags( get_the_title( $result_post ) ), ENT_QUOTES, $charset ),
			'url'   => get_permalink( $result_post ),
			'type'  => $type_object && isset( $type_object->labels->singular_name ) ? $type_object->labels->singular_name : $result_post->post_type,
		);
	}

	return rest_ensure_response( $results );
}


/**
 * Build a compact editorial context for multimodal alt generation.
 *
 * @param int    $post_id Post ID.
 * @param string $context Optional nearby block context.
 * @return array<string,string>
 */
function go_verge_build_ai_image_editorial_context( $post_id = 0, $context = '' ) {
	$post_id   = absint( $post_id );
	$post      = $post_id ? get_post( $post_id ) : null;
	$title     = $post ? go_verge_normalize_editorial_text( get_the_title( $post ) ) : '';
	$subtitle  = $post_id ? go_verge_normalize_editorial_text( get_post_meta( $post_id, '_go_post_subtitle', true ) ) : '';
	$meta_desc = $post_id ? go_verge_editor_meta_description( $post_id ) : '';
	$context   = go_verge_normalize_editorial_text( $context );
	$game      = $post_id ? go_verge_editor_linked_game_title( $post_id ) : '';
	$focus     = $post_id ? go_verge_editor_focus_keyword( $post_id ) : '';
	$terms     = $post_id ? wp_get_post_terms( $post_id, 'category', array( 'fields' => 'names' ) ) : array();
	$terms    = is_wp_error( $terms ) ? array() : array_filter( array_map( 'go_verge_normalize_editorial_text', (array) $terms ) );
	$content  = '';
	$excerpt  = '';

	if ( $post ) {
		$excerpt = go_verge_normalize_editorial_text( has_excerpt( $post ) ? $post->post_excerpt : '' );
		$content = go_verge_normalize_editorial_text( wp_strip_all_tags( strip_shortcodes( (string) $post->post_content ) ) );
		if ( function_exists( 'mb_substr' ) ) {
			$content = mb_substr( $content, 0, 1800 );
		} else {
			$content = substr( $content, 0, 1800 );
		}
	}

	return array(
		'post_title'       => $title,
		'post_subtitle'    => $subtitle,
		'post_excerpt'     => $excerpt,
		'post_content'     => $content,
		'meta_description' => $meta_desc,
		'context'          => $context,
		'linked_game'      => $game,
		'focus_keyword'    => $focus,
		'categories'       => implode( ', ', $terms ),
	);
}

/**
 * Return image URL and editorial context for the free browser-side AI.
 *
 * @param WP_REST_Request $request REST request.
 * @return WP_REST_Response|WP_Error
 */
function go_verge_rest_local_image_ai_context( WP_REST_Request $request ) {
	$attachment_id = absint( $request->get_param( 'attachment_id' ) );
	$post_id       = absint( $request->get_param( 'post_id' ) );
	$context       = sanitize_textarea_field( (string) $request->get_param( 'context' ) );

	if ( ! $attachment_id || 'attachment' !== get_post_type( $attachment_id ) || ! wp_attachment_is_image( $attachment_id ) ) {
		return new WP_Error( 'go_invalid_image', __( 'Selecione uma imagem válida da biblioteca.', 'go-verge' ), array( 'status' => 400 ) );
	}

	if ( ! current_user_can( 'edit_post', $attachment_id ) && ! current_user_can( 'upload_files' ) ) {
		return new WP_Error( 'go_image_permission', __( 'Você não tem permissão para usar esta imagem.', 'go-verge' ), array( 'status' => 403 ) );
	}

	if ( $post_id && ! current_user_can( 'edit_post', $post_id ) ) {
		$post_id = 0;
	}

	$image_url = wp_get_attachment_image_url( $attachment_id, 'large' );
	if ( ! $image_url ) {
		$image_url = wp_get_attachment_url( $attachment_id );
	}

	return rest_ensure_response(
		array(
			'image_url'  => esc_url_raw( (string) $image_url ),
			'editorial'  => go_verge_build_ai_image_editorial_context( $post_id, $context ),
			'attachment' => array(
				'id'      => $attachment_id,
				'title'   => go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( get_the_title( $attachment_id ) ) ),
				'alt'     => go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( get_post_meta( $attachment_id, '_wp_attachment_image_alt', true ) ) ),
				'caption' => go_verge_strip_ai_marker_text( go_verge_normalize_editorial_text( wp_get_attachment_caption( $attachment_id ) ) ),
			),
		)
	);
}

/**
 * Persist text generated by the free browser-side AI.
 *
 * @param WP_REST_Request $request REST request.
 * @return WP_REST_Response|WP_Error
 */
function go_verge_rest_save_local_image_text( WP_REST_Request $request ) {
	$attachment_id = absint( $request->get_param( 'attachment_id' ) );
	$mode          = sanitize_key( (string) $request->get_param( 'mode' ) );
	$mode          = in_array( $mode, array( 'both', 'alt', 'caption' ), true ) ? $mode : 'both';
	$alt           = sanitize_text_field( go_verge_strip_ai_marker_text( (string) $request->get_param( 'alt' ) ) );
	$caption       = sanitize_text_field( go_verge_strip_ai_marker_text( (string) $request->get_param( 'caption' ) ) );
	$title         = sanitize_text_field( go_verge_strip_ai_marker_text( (string) $request->get_param( 'title' ) ) );

	if ( ! $attachment_id || 'attachment' !== get_post_type( $attachment_id ) || ! wp_attachment_is_image( $attachment_id ) ) {
		return new WP_Error( 'go_invalid_image', __( 'Selecione uma imagem válida da biblioteca.', 'go-verge' ), array( 'status' => 400 ) );
	}

	if ( ! current_user_can( 'edit_post', $attachment_id ) && ! current_user_can( 'upload_files' ) ) {
		return new WP_Error( 'go_image_permission', __( 'Você não tem permissão para editar esta imagem.', 'go-verge' ), array( 'status' => 403 ) );
	}

	if ( ( 'both' === $mode || 'alt' === $mode ) && $request->has_param( 'alt' ) ) {
		update_post_meta( $attachment_id, '_wp_attachment_image_alt', $alt );
	}

	if ( ( 'both' === $mode || 'caption' === $mode ) && $request->has_param( 'caption' ) ) {
		wp_update_post(
			array(
				'ID'           => $attachment_id,
				'post_excerpt' => $caption,
			)
		);
	}

	if ( 'alt' !== $mode && '' !== $title ) {
		wp_update_post(
			array(
				'ID'         => $attachment_id,
				'post_title' => $title,
			)
		);
	}

	return rest_ensure_response(
		array(
			'title'    => $title,
			'alt'      => $alt,
			'caption'  => $caption,
			'saved'    => true,
			'ai_used'  => true,
			'mode'     => 'local',
			'basis'    => 'IA local + contexto editorial',
		)
	);
}

/**
 * Register editor-only REST endpoints.
 */
function go_verge_register_editor_workflow_rest_routes() {
	register_rest_route(
		'go-verge/v1',
		'/link-search',
		array(
			'methods'             => WP_REST_Server::READABLE,
			'callback'            => 'go_verge_rest_link_search',
			'permission_callback' => 'go_verge_editor_workflow_permission',
			'args'                => array(
				'search' => array( 'sanitize_callback' => 'sanitize_text_field' ),
				'limit'  => array( 'sanitize_callback' => 'absint' ),
			),
		)
	);

	register_rest_route(
		'go-verge/v1',
		'/local-image-ai-context',
		array(
			'methods'             => WP_REST_Server::READABLE,
			'callback'            => 'go_verge_rest_local_image_ai_context',
			'permission_callback' => 'go_verge_editor_workflow_permission',
			'args'                => array(
				'attachment_id' => array( 'required' => true, 'sanitize_callback' => 'absint' ),
				'post_id'       => array( 'sanitize_callback' => 'absint' ),
				'context'       => array( 'sanitize_callback' => 'sanitize_textarea_field' ),
			),
		)
	);

	register_rest_route(
		'go-verge/v1',
		'/save-local-image-text',
		array(
			'methods'             => WP_REST_Server::CREATABLE,
			'callback'            => 'go_verge_rest_save_local_image_text',
			'permission_callback' => 'go_verge_editor_workflow_permission',
			'args'                => array(
				'attachment_id' => array( 'required' => true, 'sanitize_callback' => 'absint' ),
				'title'         => array( 'sanitize_callback' => 'sanitize_text_field' ),
				'alt'           => array( 'sanitize_callback' => 'sanitize_text_field' ),
				'caption'       => array( 'sanitize_callback' => 'sanitize_text_field' ),
				'mode'          => array( 'sanitize_callback' => 'sanitize_key' ),
			),
		)
	);
}
add_action( 'rest_api_init', 'go_verge_register_editor_workflow_rest_routes' );

/**
 * Add the contextual image helper to WordPress media attachment details.
 *
 * @param array   $form_fields Attachment fields.
 * @param WP_Post $post        Attachment post.
 * @return array
 */
function go_verge_media_smart_text_field( $form_fields, $post ) {
	if ( ! wp_attachment_is_image( $post->ID ) ) {
		return $form_fields;
	}

	$alt_value     = trim( (string) get_post_meta( $post->ID, '_wp_attachment_image_alt', true ) );
	$caption_value = trim( (string) $post->post_excerpt );
	$title_value   = trim( (string) $post->post_title );
	$quality_bits  = array();
	$quality_bits[] = $title_value && ! go_verge_is_generic_media_text( $title_value ) ? __( 'título ok', 'go-verge' ) : __( 'revisar título', 'go-verge' );
	$quality_bits[] = $alt_value ? __( 'alt ok', 'go-verge' ) : __( 'sem alt', 'go-verge' );
	$quality_bits[] = $caption_value ? __( 'legenda ok', 'go-verge' ) : __( 'sem legenda', 'go-verge' );

	$form_fields['go_verge_media_quality'] = array(
		'label' => __( 'Qualidade editorial', 'go-verge' ),
		'input' => 'html',
		'html'  => '<p class="go-media-quality-summary">' . esc_html( implode( ' · ', $quality_bits ) ) . '</p>',
	);

	$form_fields['go_verge_smart_image_text'] = array(
		'label' => __( 'Sugestão visual', 'go-verge' ),
		'input' => 'html',
		'html'  => sprintf(
			'<button type="button" class="button go-smart-image-media-button" data-attachment-id="%1$d">%2$s</button><p class="help">%3$s</p>',
			(int) $post->ID,
			esc_html__( 'Sugerir título + alt + legenda', 'go-verge' ),
			esc_html__( 'Analisa primeiro a imagem e usa o contexto da matéria apenas para refinar a sugestão.', 'go-verge' )
		),
	);

	$edit_url = get_edit_post_link( $post->ID, '' );
	if ( $edit_url ) {
		$form_fields['go_verge_full_media_edit'] = array(
			'label' => __( 'Edição completa', 'go-verge' ),
			'input' => 'html',
			'html'  => '<a class="button" href="' . esc_url( $edit_url ) . '">' . esc_html__( 'Abrir edição ampla', 'go-verge' ) . '</a>',
		);
	}

	return $form_fields;
}
add_filter( 'attachment_fields_to_edit', 'go_verge_media_smart_text_field', 20, 2 );


/**
 * Return social links for shared UI components.
 *
 * Priority is the dedicated WordPress social menu. When that menu has not
 * been assigned yet, reuse the social URLs already stored by the original
 * Gamxo customizer so existing installations do not need duplicate setup.
 *
 * @return array<int, array{label:string,url:string,target:string}>
 */
/**
 * Current front-end URL for share controls.
 */
function go_verge_current_url() {
	if ( is_singular() ) {
		$url = get_permalink();
		if ( $url ) {
			return $url;
		}
	}

	$request = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '/';
	$request = is_string( $request ) ? $request : '/';
	return home_url( $request );
}

/**
 * Create utility pages requested by the editorial shell once per
 * installation. Existing pages are never overwritten.
 */
function go_verge_ensure_utility_pages() {
	$flag = 'go_verge_utility_pages_137';
	if ( get_option( $flag ) ) {
		return;
	}

	$pages = array(
		'biblioteca-de-games' => __( 'Biblioteca de Games', 'go-verge' ),
		'busca'               => __( 'Busca', 'go-verge' ),
		'autores'             => __( 'Autores', 'go-verge' ),
	);

	foreach ( $pages as $slug => $title ) {
		if ( get_page_by_path( $slug ) ) {
			continue;
		}
		wp_insert_post(
			array(
				'post_type'   => 'page',
				'post_status' => 'publish',
				'post_title'  => $title,
				'post_name'   => $slug,
			)
		);
	}

	update_option( $flag, 1, true );
}
add_action( 'admin_init', 'go_verge_ensure_utility_pages', 40 );
add_action( 'after_switch_theme', 'go_verge_ensure_utility_pages', 40 );

/**
 * Ensure the dedicated video hub also exists on installations that already
 * completed the older utility-page migration flag.
 */
function go_verge_ensure_videos_page() {
	if ( get_page_by_path( 'videos' ) ) {
		return;
	}

	wp_insert_post(
		array(
			'post_type'   => 'page',
			'post_status' => 'publish',
			'post_title'  => __( 'Vídeos', 'go-verge' ),
			'post_name'   => 'videos',
		)
	);
}
// V7 retires /videos/ as a section; legacy page requests are 301 redirected.


/**
 * Optional YouTube channel IDs for platform channels that do not have a
 * universal first-party feed. They are exposed in Settings > Media.
 */
function go_verge_register_video_channel_settings() {
	register_setting( 'media', 'go_verge_video_channel_pc', array( 'sanitize_callback' => 'sanitize_text_field' ) );
	register_setting( 'media', 'go_verge_video_channel_mobile', array( 'sanitize_callback' => 'sanitize_text_field' ) );

	add_settings_section(
		'go_verge_video_channels',
		__( 'Canais da página de vídeos', 'go-verge' ),
		function () {
			echo '<p>' . esc_html__( 'Opcional. Informe o ID do canal do YouTube usado nas faixas de PC e Mobile. Sem ID, a página usa vídeos encontrados nas matérias dessas plataformas.', 'go-verge' ) . '</p>';
		},
		'media'
	);

	foreach ( array( 'pc' => 'PC', 'mobile' => 'Mobile' ) as $key => $label ) {
		add_settings_field(
			'go_verge_video_channel_' . $key,
			sprintf( __( 'Canal %s', 'go-verge' ), $label ),
			function () use ( $key ) {
				$value = (string) get_option( 'go_verge_video_channel_' . $key, '' );
				printf(
					'<input type="text" class="regular-text" name="go_verge_video_channel_%1$s" value="%2$s" placeholder="UC..."><p class="description">%3$s</p>',
					esc_attr( $key ),
					esc_attr( $value ),
					esc_html__( 'Use o ID do canal, não a URL completa.', 'go-verge' )
				);
			},
			'media',
			'go_verge_video_channels'
		);
	}
}
add_action( 'admin_init', 'go_verge_register_video_channel_settings' );

/**
 * Resolve the public game-library URL even before the utility page has been
 * created on a freshly activated installation.
 */
function go_verge_game_library_url() {
	$page = get_page_by_path( 'biblioteca-de-games' );
	return $page instanceof WP_Post ? get_permalink( $page ) : home_url( '/biblioteca-de-games/' );
}

function go_verge_get_social_links() {
	$links = array();

	$locations = get_nav_menu_locations();
	if ( ! empty( $locations['social'] ) ) {
		$items = wp_get_nav_menu_items( $locations['social'] );
		if ( is_array( $items ) ) {
			foreach ( $items as $item ) {
				$url = isset( $item->url ) ? esc_url_raw( $item->url ) : '';
				if ( ! $url ) {
					continue;
				}
				$links[] = array(
					'label'  => wp_strip_all_tags( $item->title ),
					'url'    => $url,
					'target' => ! empty( $item->target ) ? $item->target : '_blank',
				);
			}
		}
	}

	$unique = array();
	foreach ( $links as $link ) {
		$unique[ $link['url'] ] = $link;
	}

	return array_values( $unique );
}

/**
 * Content width for embeds.
 */
function go_verge_content_width() {
	$GLOBALS['content_width'] = 820;
}
add_action( 'after_setup_theme', 'go_verge_content_width', 0 );

/**
 * Front-end styles, fonts and scripts.
 */
function go_verge_assets() {
	/*
	 * Register a virtual stylesheet handle and inject @font-face rules inline
	 * after converting ../fonts/... paths to absolute theme URLs. This prevents
	 * CSS minifiers/cache plugins from breaking font resolution when they move
	 * or combine stylesheets into another directory.
	 */
	wp_register_style(
		'go-verge-fonts',
		false,
		array(),
		go_verge_asset_version( '/assets/css/verge-fonts.css' )
	);
	wp_enqueue_style( 'go-verge-fonts' );

	$font_faces_css = go_verge_get_font_faces_css();
	if ( '' !== $font_faces_css ) {
		wp_add_inline_style( 'go-verge-fonts', $font_faces_css );
	}

	$go_verge_css_rel = '/assets/css/verge.css';
	wp_enqueue_style(
		'go-verge',
		GO_VERGE_URI . $go_verge_css_rel,
		array( 'go-verge-fonts' ),
		go_verge_asset_version( $go_verge_css_rel )
	);
	wp_add_inline_style(
		'go-verge',
		'.go-container{min-width:0}.go-latest-bar{overflow:hidden}.go-latest-bar__inner{grid-template-columns:auto minmax(0,1fr)}.go-latest-bar__items{overflow:hidden}.go-latest-bar__item>span:first-child{min-width:0}.go-hero-visual__feature .go-tile__title,.go-single__title,.go-single__deck{overflow-wrap:anywhere}@media (max-width:900px){.go-latest-bar__inner{grid-template-columns:auto minmax(0,1fr)}}@media (max-width:550px){.go-latest-bar__inner{grid-template-columns:auto minmax(0,1fr)}}'
	);

	$go_verge_js_rel = '/assets/js/theme.min.js';
	wp_enqueue_script(
		'go-verge',
		GO_VERGE_URI . $go_verge_js_rel,
		array(),
		go_verge_asset_version( $go_verge_js_rel ),
		true
	);

	/* viewport-stability intentionally performs no work on standard posts so the
	 * article DOM stays immutable for Auto Ads. Do not download a script whose
	 * first runtime action would be to return on the site's hottest template. */
	if ( ! is_singular( 'post' ) ) {
		$go_verge_viewport_rel = '/assets/js/viewport-stability.min.js';
		wp_enqueue_script(
			'go-verge-viewport-stability',
			GO_VERGE_URI . $go_verge_viewport_rel,
			array( 'go-verge' ),
			go_verge_asset_version( $go_verge_viewport_rel ),
			true
		);
	}

	$go_verge_current_post = get_queried_object();
	$go_verge_post_content = $go_verge_current_post instanceof WP_Post
		? (string) $go_verge_current_post->post_content
		: '';
	$go_verge_has_editorial_table = is_singular( 'post' ) &&
		(bool) preg_match( '/<table\b|wp-block-table|\[table\b/i', $go_verge_post_content );
	if ( $go_verge_has_editorial_table ) {
		$go_verge_tables_rel = '/assets/js/editorial-tables.min.js';
		wp_enqueue_script(
			'go-verge-editorial-tables',
			GO_VERGE_URI . $go_verge_tables_rel,
			array( 'go-verge' ),
			go_verge_asset_version( $go_verge_tables_rel ),
			true
		);
	}

	/*
	 * `ajaxUrl` only. The `go_verge` nonce that used to ride along was verified
	 * by nothing — both public continuation endpoints authenticate with an HMAC
	 * over the query itself — and printing a per-user token into every document
	 * is what makes a full-page cache serve one reader's token to another.
	 */
	wp_localize_script( 'go-verge', 'GoVerge', array(
		'ajaxUrl' => admin_url( 'admin-ajax.php' ),
	) );

	/*
	 * Subject-aware crop is useful around a single story, but it is pure
	 * enhancement on listing surfaces. Loading it on Home, categories, tags,
	 * editorial hubs and search made the browser decode/sample many thumbnails
	 * with canvas while the reader was trying to scroll the feed. Those surfaces
	 * already have deterministic object-fit crops, so keep the analyser only on
	 * singular documents and never on the static front page.
	 */
	if ( is_singular( array( 'post', 'games', 'productions', 'go_entity' ) ) ) {
		$go_verge_framing_rel = '/assets/js/smart-framing.min.js';
		wp_enqueue_script(
			'go-verge-smart-framing',
			GO_VERGE_URI . $go_verge_framing_rel,
			array(),
			go_verge_asset_version( $go_verge_framing_rel ),
			true
		);
	}

	// Accessible read-aloud controls are loaded only on editorial articles.
	if ( is_singular( 'post' ) ) {
		$go_verge_audio_rel = '/assets/js/article-audio.min.js';
		wp_enqueue_script(
			'go-verge-article-audio',
			GO_VERGE_URI . $go_verge_audio_rel,
			array(),
			go_verge_asset_version( $go_verge_audio_rel ),
			true
		);
	}

	/* The article sidebar is now fully budgeted on the server. No height-matching
	 * script is loaded: recommendation shelves stay predictable and never expand
	 * into a duplicate mini archive after fonts or embeds finish loading. */

	if ( is_singular() && comments_open() && get_option( 'thread_comments' ) ) {
		wp_enqueue_script( 'comment-reply' );
	}
}
// Run after Gamxo's late dynamic typography callback (priority 1500).
add_action( 'wp_enqueue_scripts', 'go_verge_assets', 1600 );

/**
 * Whether this document is rendered by a third-party builder or commerce stack.
 *
 * Those stacks ship their own runtime and expect jQuery to execute in order, so
 * the theme's script-loading optimisations stand down on them. The historical
 * "legacy Gamxo bundle" dequeue that used to live here was removed with the
 * bundle itself: the parent stack no longer registers any handle, so the removal
 * loop could never match anything.
 *
 * @return bool
 */
function go_verge_page_needs_legacy_assets() {
	if ( is_admin() ) {
		return true;
	}

	if ( function_exists( 'is_woocommerce' ) && ( is_woocommerce() || is_cart() || is_checkout() || is_account_page() ) ) {
		return true;
	}

	$post_id = get_queried_object_id();
	if ( $post_id ) {
		$elementor_data = get_post_meta( $post_id, '_elementor_data', true );
		$elementor_mode = get_post_meta( $post_id, '_elementor_edit_mode', true );
		if ( ! empty( $elementor_data ) || 'builder' === $elementor_mode ) {
			return true;
		}
	}

	return false;
}


/** Mark small, non-critical custom scripts for deferred execution. */
function go_verge_set_script_loading_strategy() {
	foreach ( array( 'go-verge', 'go-verge-viewport-stability', 'go-verge-smart-framing', 'go-verge-enhanced-search', 'go-verge-article-audio', 'go-verge-editorial-tables', 'go-verge-game-hub', 'go-verge-product' ) as $handle ) {
		if ( wp_script_is( $handle, 'enqueued' ) ) {
			wp_script_add_data( $handle, 'strategy', 'defer' );
		}
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_set_script_loading_strategy', 1800 );

/**
 * Preload the fonts used by visible text in the first viewport.
 * Editorial listings and the home use Source Sans 3 for their headlines;
 * stories and Compare still use Barlow Condensed. Other weights load through
 * their existing @font-face rules when the rendered text needs them.
 *
 * Priority 3 is deliberate: `go_verge_preload_lcp_image()` runs at 2, so the
 * hero image keeps the first slot in the preload queue. Fonts do not need a new
 * connection, the image does not lose its head start, and neither waits on a
 * cross-origin handshake any more.
 *
 * @return void
 */
function go_verge_preload_primary_font() {
	/* Same-origin files on the document's own connection: no third-party DNS,
	 * TCP and TLS round trip before the headline and body text can paint. */
	$fonts = trailingslashit( GO_VERGE_URI ) . 'assets/fonts/';
	$files = array( 'source-sans-3/source-sans-3-variable-latin.woff2' );
	if ( ! is_front_page() && ! go_verge_is_editorial_index() ) {
		array_unshift( $files, 'barlow-condensed/barlow-condensed-700-latin.woff2' );
	}
	foreach ( $files as $file ) {
		printf( '<link rel="preload" href="%s" as="font" type="font/woff2" crossorigin>' . "\n", esc_url( $fonts . $file ) );
	}
}
add_action( 'wp_head', 'go_verge_preload_primary_font', 3 );

/**
 * URL of a registered crop that actually exists on disk.
 *
 * wp_get_attachment_image_url() never fails: when the requested size was never
 * generated — a size registered after the upload, or a format this host cannot
 * resize — it returns the full-size file. Callers that ask for a small crop and
 * silently receive a 2.5k-wide original end up preloading or advertising a
 * multi-megabyte asset. This resolves the real intermediate, then the closest
 * larger one, and only falls back to the original when the attachment genuinely
 * has no intermediate (which is the correct answer for images smaller than the
 * requested crop).
 *
 * @param int    $attachment_id Attachment ID.
 * @param string $size          Registered image size name.
 * @return string URL, or an empty string when the attachment is unusable.
 */
function go_verge_intermediate_image_url( $attachment_id, $size ) {
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id ) {
		return '';
	}

	$exact = image_get_intermediate_size( $attachment_id, $size );
	if ( is_array( $exact ) && ! empty( $exact['url'] ) ) {
		return $exact['url'];
	}

	$meta = wp_get_attachment_metadata( $attachment_id );
	if ( ! is_array( $meta ) || empty( $meta['sizes'] ) || ! is_array( $meta['sizes'] ) ) {
		return (string) wp_get_attachment_image_url( $attachment_id, 'full' );
	}

	$target = 0;
	$sizes  = wp_get_registered_image_subsizes();
	if ( isset( $sizes[ $size ]['width'] ) ) {
		$target = (int) $sizes[ $size ]['width'];
	}

	$best       = '';
	$best_width = 0;
	foreach ( $meta['sizes'] as $candidate ) {
		$width = isset( $candidate['width'] ) ? (int) $candidate['width'] : 0;
		if ( $width <= 0 || empty( $candidate['file'] ) ) {
			continue;
		}
		/* Prefer the smallest crop that still covers the target width; without a
		 * known target, the widest generated crop is the safest stand-in. */
		if ( $target > 0 && $width >= $target ) {
			if ( 0 === $best_width || $width < $best_width ) {
				$best       = (string) $candidate['file'];
				$best_width = $width;
			}
		} elseif ( 0 === $target && $width > $best_width ) {
			$best       = (string) $candidate['file'];
			$best_width = $width;
		}
	}

	if ( '' === $best && $target > 0 ) {
		foreach ( $meta['sizes'] as $candidate ) {
			$width = isset( $candidate['width'] ) ? (int) $candidate['width'] : 0;
			if ( $width > $best_width && ! empty( $candidate['file'] ) ) {
				$best       = (string) $candidate['file'];
				$best_width = $width;
			}
		}
	}

	if ( '' === $best ) {
		return (string) wp_get_attachment_image_url( $attachment_id, 'full' );
	}

	$full = (string) wp_get_attachment_image_url( $attachment_id, 'full' );
	if ( '' === $full ) {
		return '';
	}

	return dirname( $full ) . '/' . rawurlencode( wp_basename( $best ) );
}

/**
 * Return the normal responsive srcset for the article hero.
 *
 * Discover eligibility is supplied separately by a >=1200px representative
 * image in OG/schema/sitemaps plus max-image-preview:large. Filtering the HTML
 * srcset to >=1200px forced phones to download oversized LCP assets and could
 * hurt Core Web Vitals without improving Discover eligibility.
 *
 * The third parameter is retained for backwards compatibility with callers
 * from older child/custom code, but it intentionally no longer floors widths.
 *
 * @param int    $attachment_id Attachment ID.
 * @param string $size          Requested WordPress image size.
 * @param int    $min_width     Deprecated compatibility parameter.
 * @return string
 */
function go_verge_discover_ready_srcset( $attachment_id, $size = 'go_hero', $min_width = 0 ) {
	unset( $min_width );
	$attachment_id = absint( $attachment_id );
	if ( ! $attachment_id || ! function_exists( 'wp_get_attachment_image_srcset' ) ) {
		return '';
	}

	return (string) wp_get_attachment_image_srcset( $attachment_id, $size );
}

/**
 * The above-the-fold hero image of a standard article, as single.php renders it.
 *
 * The preload hint and the <img> must describe the SAME resource. They did not:
 * the preloader asked for the `go_hero` crop with an 1100px slot while single.php
 * rendered `go_discover_16x9` with an 856px slot, and reviews rendered the same
 * crop at `100vw`. Every article view therefore downloaded two different hero
 * files, and the one that actually painted queued behind the one marked
 * `fetchpriority=high`. Both callers now read the geometry from here, so a change
 * to the template can no longer desynchronise the hint.
 *
 * @param int $post_id Post ID.
 * @return array{id:int,size:string,sizes:string,scored:bool}|null
 */
function go_verge_single_hero_image( $post_id = 0 ) {
	$post_id = $post_id ? (int) $post_id : (int) get_queried_object_id();
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || post_password_required( $post_id ) || ! has_post_thumbnail( $post_id ) ) {
		return null;
	}

	$image_id = (int) get_post_thumbnail_id( $post_id );
	if ( ! $image_id ) {
		return null;
	}

	$critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$review   = ! $critique && function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id );
	$scored   = $critique || $review;

	return array(
		'id'     => $image_id,
		/* One responsive contract for the premium/standard image and its preload. */
		'size'   => $scored ? 'go_discover_16x9' : 'go_hero',
		'sizes'  => '(max-width: 767px) calc(100vw - 40px), (max-width: 1183px) calc(100vw - 64px), 1120px',
		'scored' => (bool) $scored,
	);
}

/** Preload the actual above-the-fold featured image with responsive candidates. */
function go_verge_preload_lcp_image() {
	$image_id        = 0;
	$size            = 'go_hero';
	$sizes           = '(max-width: 767px) calc(100vw - 32px), (max-width: 1279px) calc(100vw - 40px), 1100px';
	$discover_floor  = false;

	/*
	 * A template that resolved its own above-the-fold image wins.
	 *
	 * The front page is a static Page, so `is_singular()` is true there and its
	 * own featured image — the brand avatar — used to win this branch and get
	 * preloaded at fetchpriority=high. The real LCP element is the first hero
	 * card that front-page.php already resolved into the global below, so the
	 * browser was told to race a decorative asset against the element that
	 * actually decides LCP. Explicit wins over inferred.
	 */
	if ( ! empty( $GLOBALS['go_verge_lcp_preload_image_id'] ) ) {
		$image_id = absint( $GLOBALS['go_verge_lcp_preload_image_id'] );
		$sizes    = '(max-width: 767px) calc(100vw - 32px), (max-width: 1303px) 62vw, 806px';
	} elseif ( is_singular( 'post' ) ) {
		$hero = go_verge_single_hero_image( get_queried_object_id() );
		if ( $hero ) {
			$image_id       = $hero['id'];
			$size           = $hero['size'];
			$sizes          = $hero['sizes'];
			$discover_floor = true;
		}
	}

	if ( ! $image_id ) {
		return;
	}

	/* Use WordPress's exact resolver because the corresponding <img> is rendered
	 * by the_post_thumbnail(). If a legacy upload lacks the named crop both now
	 * resolve to the same full image instead of preloading a different subsize. */
	$resolved = wp_get_attachment_image_src( $image_id, $size );
	$href   = is_array( $resolved ) ? (string) ( $resolved[0] ?? '' ) : '';
	$srcset = $discover_floor
		? go_verge_discover_ready_srcset( $image_id, $size )
		: wp_get_attachment_image_srcset( $image_id, $size );
	if ( ! $href ) {
		return;
	}

	echo '<link rel="preload" as="image" fetchpriority="high" href="' . esc_url( $href ) . '"';
	if ( $srcset ) {
		echo ' imagesrcset="' . esc_attr( $srcset ) . '" imagesizes="' . esc_attr( $sizes ) . '"';
	}
	echo ">
";
}
add_action( 'wp_head', 'go_verge_preload_lcp_image', 2 );

/**
 * Fill missing intrinsic dimensions in legacy editor images whenever the
 * attachment ID is available in the standard wp-image-{ID} class.
 */
function go_verge_backfill_content_image_dimensions( $content ) {
	if ( ! is_string( $content ) || false === stripos( $content, '<img' ) || ! class_exists( 'WP_HTML_Tag_Processor' ) ) {
		return $content;
	}

	$processor = new WP_HTML_Tag_Processor( $content );
	$home_host = strtolower( (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST ) );
	$lookups = 0;
	while ( $processor->next_tag( 'IMG' ) ) {
		$is_high = 'high' === strtolower( (string) $processor->get_attribute( 'fetchpriority' ) );
		$is_eager = 'eager' === strtolower( (string) $processor->get_attribute( 'loading' ) );
		if ( null === $processor->get_attribute( 'decoding' ) ) {
			$processor->set_attribute( 'decoding', 'async' );
		}
		if ( $is_high || $is_eager ) {
			$processor->set_attribute( 'loading', 'eager' );
			$processor->set_attribute( 'data-no-lazy', '1' );
		} elseif ( null === $processor->get_attribute( 'loading' ) ) {
			$processor->set_attribute( 'loading', 'lazy' );
		}
		if ( ! $is_high && ! $is_eager && null === $processor->get_attribute( 'fetchpriority' ) ) {
			$processor->set_attribute( 'fetchpriority', 'low' );
		}

		$raw_width = $processor->get_attribute( 'width' );
		$raw_height = $processor->get_attribute( 'height' );
		$width = is_string( $raw_width ) && ctype_digit( $raw_width ) ? absint( $raw_width ) : 0;
		$height = is_string( $raw_height ) && ctype_digit( $raw_height ) ? absint( $raw_height ) : 0;
		if ( $width && $height ) { continue; }
		// Leave explicitly non-pixel sizing to the author's HTML/CSS contract.
		if ( ( null !== $raw_width && ! $width ) || ( null !== $raw_height && ! $height ) ) { continue; }

		$id = 0;
		if ( preg_match( '/(?:^|\s)wp-image-(\d+)(?:\s|$)/', (string) $processor->get_attribute( 'class' ), $match ) ) {
			$id = absint( $match[1] );
		}
		$src = (string) $processor->get_attribute( 'src' );
		if ( ! $id && $src && $lookups < 12 ) {
			$host = strtolower( (string) wp_parse_url( $src, PHP_URL_HOST ) );
			if ( '' === $host || $host === $home_host ) {
				++$lookups;
				$id = absint( attachment_url_to_postid( $src ) );
			}
		}
		if ( ! $id ) { continue; }
		$meta = wp_get_attachment_metadata( $id );
		if ( ! is_array( $meta ) ) { continue; }
		$natural_width = absint( $meta['width'] ?? 0 );
		$natural_height = absint( $meta['height'] ?? 0 );
		$filename = rawurldecode( basename( (string) wp_parse_url( $src, PHP_URL_PATH ) ) );
		foreach ( (array) ( $meta['sizes'] ?? array() ) as $size ) {
			if ( ! empty( $size['file'] ) && basename( (string) $size['file'] ) === $filename ) {
				$natural_width = absint( $size['width'] ?? 0 );
				$natural_height = absint( $size['height'] ?? 0 );
				break;
			}
		}
		if ( ! $natural_width || ! $natural_height ) { continue; }
		// Preserve an existing dimension and derive its partner at the same ratio.
		if ( ! $width ) {
			$processor->set_attribute( 'width', $height ? max( 1, (int) round( $height * $natural_width / $natural_height ) ) : $natural_width );
		}
		if ( ! $height ) {
			$processor->set_attribute( 'height', $width ? max( 1, (int) round( $width * $natural_height / $natural_width ) ) : $natural_height );
		}
	}
	return $processor->get_updated_html();
}
add_filter( 'the_content', 'go_verge_backfill_content_image_dimensions', 12 );

/** Keep attachment images explicit and cheap to decode. */
function go_verge_attachment_image_performance_attrs( $attr, $attachment, $size ) {
	$is_eager = isset( $attr['loading'] ) && 'eager' === strtolower( (string) $attr['loading'] );
	$is_high  = isset( $attr['fetchpriority'] ) && 'high' === strtolower( (string) $attr['fetchpriority'] );

	/* `fetchpriority=high` controls network priority; it does not require a
	 * synchronous decode. Keep the LCP candidate asynchronous as well so image
	 * decoding cannot monopolise the main thread immediately before first paint.
	 * Respect an explicit value supplied by a component or plugin. */
	if ( empty( $attr['decoding'] ) ) {
		$attr['decoding'] = 'async';
	}

	/* LiteSpeed Cache recognises data-no-lazy on images. Preserve every image
	 * the template explicitly chose to load eagerly (especially the article and
	 * homepage LCP) instead of allowing a second optimisation layer to rewrite
	 * it back to lazy-load. */
	if ( $is_eager || $is_high ) {
		$attr['loading']      = 'eager';
		$attr['data-no-lazy'] = '1';
		unset( $attr['fetchpriority'] );
		if ( $is_high ) {
			$attr['fetchpriority'] = 'high';
		}
	}

	return $attr;
}
add_filter( 'wp_get_attachment_image_attributes', 'go_verge_attachment_image_performance_attrs', 20, 3 );

/**
 * Give every Mailchimp for WP form control an accessible name. The form HTML
 * lives in the plugin settings, so the theme labels the consent checkbox and
 * the e-mail field on output instead of editing the stored markup.
 */
function go_verge_label_mc4wp_form_fields( $content ) {
	if ( false !== strpos( $content, 'name="AGREE_TO_TERMS"' ) && false === strpos( $content, 'AGREE_TO_TERMS" aria-label' ) ) {
		$content = str_replace(
			'name="AGREE_TO_TERMS"',
			'name="AGREE_TO_TERMS" aria-label="' . esc_attr__( 'Li e concordo com os termos e condições', 'go-verge' ) . '"',
			$content
		);
	}
	if ( preg_match( '/<input(?![^>]*aria-label)(?![^>]*\bid=)[^>]*name="EMAIL"[^>]*>/i', $content ) ) {
		$content = preg_replace(
			'/(<input(?![^>]*aria-label)[^>]*name="EMAIL")/i',
			'$1 aria-label="' . esc_attr__( 'Seu endereço de e-mail', 'go-verge' ) . '"',
			$content,
			1
		);
	}
	return $content;
}
add_filter( 'mc4wp_form_content', 'go_verge_label_mc4wp_form_fields', 20 );

/**
 * Trim WordPress runtime the editorial front-end never uses: the emoji
 * replacement script and jQuery Migrate. Both count against unused JS and
 * main-thread work on every page.
 */
function go_verge_trim_core_frontend_extras() {
	remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
	remove_action( 'wp_print_styles', 'print_emoji_styles' );
	remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
	remove_action( 'admin_print_styles', 'print_emoji_styles' );
	// WordPress 6.4+ enqueues emoji styles through these hooks instead.
	remove_action( 'wp_enqueue_scripts', 'wp_enqueue_emoji_styles' );
	remove_action( 'enqueue_block_assets', 'wp_enqueue_emoji_styles' );
	remove_filter( 'the_content_feed', 'wp_staticize_emoji' );
	remove_filter( 'comment_text_rss', 'wp_staticize_emoji' );
	remove_filter( 'wp_mail', 'wp_staticize_emoji_for_email' );
	add_filter( 'emoji_svg_url', '__return_false' );
}
add_action( 'init', 'go_verge_trim_core_frontend_extras' );

/** Drop jQuery Migrate on the public site; nothing here relies on removed APIs. */
function go_verge_remove_jquery_migrate( $scripts ) {
	if ( is_admin() || empty( $scripts->registered['jquery'] ) ) {
		return;
	}
	$jquery = $scripts->registered['jquery'];
	if ( ! empty( $jquery->deps ) ) {
		$jquery->deps = array_values( array_diff( $jquery->deps, array( 'jquery-migrate' ) ) );
	}
}
add_action( 'wp_default_scripts', 'go_verge_remove_jquery_migrate' );

/**
 * The newsletter form renders below the fold, so its plugin stylesheet must
 * not block first paint. Swap it to the async preload pattern with a
 * noscript fallback.
 */
function go_verge_async_noncritical_styles( $tag, $handle, $href, $media ) {
	if ( is_admin() || false === strpos( $handle, 'mc4wp' ) ) {
		return $tag;
	}
	$async = str_replace(
		"media='" . $media . "'",
		"media='print' data-go-async-media='" . esc_attr( $media ? $media : 'all' ) . "' onload=\"this.media=this.dataset.goAsyncMedia;this.removeAttribute('onload')\"",
		$tag
	);
	if ( $async === $tag ) {
		return $tag;
	}
	return $async . '<noscript>' . $tag . '</noscript>';
}
add_filter( 'style_loader_tag', 'go_verge_async_noncritical_styles', 20, 4 );

/**
 * Generate WebP sub-sizes for new uploads. Existing media is untouched;
 * regenerate thumbnails to convert the back catalog.
 *
 * PNG was the gap that mattered. The newsroom pipeline delivers most article
 * heroes as PNG, and PNG keeps photographic material lossless: measured on
 * live articles the 1280x720 hero shipped at ~980 KB and the full size at
 * ~1.75 MB, against ~60-120 KB for the same crop already stored as WebP.
 * Converting the generated sub-sizes — the ones the hero, srcset and cards
 * actually request — removes that penalty without touching the original file,
 * which stays PNG in the library.
 *
 * AVIF is mapped for a different reason: this host's image editor does not
 * produce AVIF sub-sizes, so AVIF uploads ship a single full-size file with no
 * srcset at all. Asking for WebP output gives those uploads a real responsive
 * set whenever the editor can read the source, and changes nothing when it
 * cannot.
 *
 * @param array $formats Source MIME => output MIME map.
 * @return array
 */
function go_verge_prefer_webp_subsizes( $formats ) {
	$formats['image/jpeg'] = 'image/webp';
	$formats['image/png']  = 'image/webp';
	$formats['image/avif'] = 'image/webp';
	return $formats;
}
add_filter( 'image_editor_output_format', 'go_verge_prefer_webp_subsizes' );

/**
 * Keep AVIF out of the media library only while the host is unhealthy.
 *
 * `inc/image-deliverability.php` now probes a real public AVIF response and
 * automatically reopens uploads when BOTH conditions are true: the server
 * sends `Content-Type: image/avif`, and the WordPress image editor can decode
 * AVIF to generate the normal WebP derivatives. No wp-config.php filter is
 * required after the server MIME has been corrected.
 *
 * The old `go_verge_allow_avif_uploads` filter remains available only as an
 * explicit emergency override for backwards compatibility.
 *
 * @param array $mimes Allowed upload MIME types.
 * @return array
 */
function go_verge_block_avif_uploads( $mimes ) {
	if ( function_exists( 'go_verge_avif_uploads_allowed' ) && go_verge_avif_uploads_allowed() ) {
		/* Core normally adds AVIF when the editor supports it. Keep the MIME
		 * explicit here so a previously cached upload_mimes result cannot leave
		 * the newsroom stuck after the HTTP MIME fix. */
		$mimes['avif'] = 'image/avif';
		return $mimes;
	}

	foreach ( array_keys( $mimes ) as $extension ) {
		if ( false !== strpos( (string) $extension, 'avif' ) ) {
			unset( $mimes[ $extension ] );
		}
	}

	return $mimes;
}
add_filter( 'upload_mimes', 'go_verge_block_avif_uploads', 20 );

/**
 * Say why, instead of letting the uploader fail with a generic message.
 *
 * @param array $file Upload being validated.
 * @return array
 */
function go_verge_explain_blocked_avif( $file ) {
	if ( empty( $file['name'] ) ) {
		return $file;
	}
	if ( function_exists( 'go_verge_avif_uploads_allowed' ) && go_verge_avif_uploads_allowed() ) {
		return $file;
	}

	$extension = strtolower( (string) pathinfo( $file['name'], PATHINFO_EXTENSION ) );
	if ( 'avif' !== $extension && 'avifs' !== $extension ) {
		return $file;
	}

	$http_ok   = function_exists( 'go_verge_avif_http_deliverable' ) && go_verge_avif_http_deliverable();
	$editor_ok = function_exists( 'wp_image_editor_supports' ) && wp_image_editor_supports( array( 'mime_type' => 'image/avif' ) );
	if ( ! $http_ok ) {
		$file['error'] = __( 'AVIF ainda está bloqueado porque a resposta pública não foi validada como Content-Type: image/avif. Confira Ferramentas → Saúde do site → Entrega de imagens AVIF.', 'go-verge' );
	} elseif ( ! $editor_ok ) {
		$file['error'] = __( 'O servidor já entrega AVIF corretamente, mas o editor de imagens do WordPress não consegue processar AVIF para gerar os recortes WebP/Discover. Use JPEG ou PNG até habilitar AVIF no GD/Imagick.', 'go-verge' );
	} else {
		$file['error'] = __( 'AVIF foi recusado por uma política personalizada do site. Confira o filtro go_verge_allow_avif_uploads.', 'go-verge' );
	}

	return $file;
}
add_filter( 'wp_handle_upload_prefilter', 'go_verge_explain_blocked_avif', 20 );

/*
 * The shared answer to "can this server deliver this image format to Google?"
 * lives in inc/image-deliverability.php, next to nothing else, because the
 * og:image chain, the schema chain and Site Health all need it and all three
 * used to answer it differently. Required here so it is defined before any
 * inc/ module that calls it.
 */
require_once GO_VERGE_DIR . '/inc/image-deliverability.php';

/**
 * Slightly richer WebP quality than core's default.
 *
 * Core encodes WebP at 82. Article heroes now come mostly from PNG sources —
 * UI screenshots, key art and captures with hard edges and flat colour, which
 * is exactly the material where lossy artefacts are visible. 86 keeps those
 * crops clean and still lands an order of magnitude below the PNG original.
 * Only WebP output is affected; JPEG and every other format keep core's value.
 *
 * @param int    $quality Default quality.
 * @param string $mime    Output MIME type.
 * @return int
 */
function go_verge_webp_quality( $quality, $mime ) {
	return 'image/webp' === $mime ? 86 : $quality;
}
add_filter( 'wp_editor_set_quality', 'go_verge_webp_quality', 10, 2 );


/** Start the main design-system stylesheet as early as possible. */
function go_verge_preload_primary_stylesheet() {
	/*
	 * The production front-end bundles theme CSS into a single generated file.
	 * Do not preload the obsolete source sheet. On the desktop homepage, however,
	 * preload the ACTUAL content-hashed bundle that the bundler already resolved
	 * during wp_enqueue_scripts. This closes the window where a cache/optimisation
	 * layer can let the critical shell paint before the full home cascade arrives.
	 * The media gate keeps this extra hint off mobile and the LCP image is printed
	 * earlier (priority 2), so it retains the first image preload slot.
	 */
	if ( apply_filters( 'go_verge_style_bundle_enabled', true ) ) {
		if ( ( is_front_page() || is_home() ) && ! empty( $GLOBALS['go_verge_style_bundle_url'] ) ) {
			printf(
				'<link rel="preload" href="%s" as="style" media="(min-width: 901px)" fetchpriority="high">' . "
",
				esc_url( $GLOBALS['go_verge_style_bundle_url'] )
			);
		}
		return;
	}

	$rel = '/assets/css/verge.css';
	$url = add_query_arg(
		'ver',
		go_verge_asset_version( $rel ),
		GO_VERGE_URI . $rel
	);
	printf(
		'<link rel="preload" href="%s" as="style">' . "
",
		esc_url( $url )
	);
}
add_action( 'wp_head', 'go_verge_preload_primary_stylesheet', 4 );

/**
 * Defer small non-critical product/companion scripts when registered.
 * WordPress keeps dependency ordering intact.
 */
function go_verge_defer_noncritical_product_scripts() {
	if ( wp_script_is( 'go-verge-product', 'enqueued' ) ) {
		wp_script_add_data( 'go-verge-product', 'strategy', 'defer' );
	}

	$scripts = wp_scripts();
	if ( ! ( $scripts instanceof WP_Scripts ) ) {
		return;
	}
	foreach ( (array) $scripts->queue as $handle ) {
		if ( empty( $scripts->registered[ $handle ] ) ) {
			continue;
		}
		$src = (string) $scripts->registered[ $handle ]->src;
		if ( false !== strpos( $src, 'newsx-core-pro-public.js' ) || false !== strpos( $src, '/blocks/subscription-view.js' ) ) {
			wp_script_add_data( $handle, 'strategy', 'defer' );
		}
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_defer_noncritical_product_scripts', 1900 );

/**
 * Keep the tiny accessibility control above-the-fold styling available even
 * when the larger product feature sheet is deferred on listing surfaces.
 */
function go_verge_inline_product_shell_css() {
	if ( is_admin() || ! wp_style_is( 'go-verge', 'enqueued' ) ) {
		return;
	}
	$css = 'html[data-go-font-scale="90"] .entry-content.go-single__content{font-size:1.044rem!important}html[data-go-font-scale="100"] .entry-content.go-single__content{font-size:1.16rem!important}html[data-go-font-scale="110"] .entry-content.go-single__content{font-size:1.276rem!important}html[data-go-font-scale="120"] .entry-content.go-single__content{font-size:1.392rem!important}html[data-go-font-scale="130"] .entry-content.go-single__content{font-size:1.508rem!important}.go-a11y{position:fixed;left:18px;bottom:18px;z-index:999}.go-a11y__toggle{border:1px solid var(--border-strong);border-radius:999px;background:var(--slate);color:var(--text);padding:9px 13px;font-weight:700;box-shadow:0 8px 28px rgba(0,0,0,.18)}.go-a11y__panel{position:absolute;left:0;bottom:48px;width:220px;padding:10px;background:var(--slate);border:var(--hair-strong);border-radius:var(--r-card);box-shadow:0 12px 38px rgba(0,0,0,.28);display:grid;grid-template-columns:1fr 1fr;gap:7px}.go-a11y__panel[hidden]{display:none}.go-a11y__panel button{border:var(--hair);background:var(--surface-2);color:var(--text);border-radius:var(--r-sm);padding:9px}.go-a11y__panel button[aria-pressed="true"]{border-color:var(--lime);color:var(--lime-dim)}.go-a11y__reset{grid-column:1/-1;font-weight:750}@media(max-width:767px){html[data-go-font-scale="90"] .entry-content.go-single__content{font-size:.945rem!important}html[data-go-font-scale="100"] .entry-content.go-single__content{font-size:1.05rem!important}html[data-go-font-scale="110"] .entry-content.go-single__content{font-size:1.155rem!important}html[data-go-font-scale="120"] .entry-content.go-single__content{font-size:1.26rem!important}html[data-go-font-scale="130"] .entry-content.go-single__content{font-size:1.365rem!important}}@media(max-width:520px){.go-a11y{left:10px;bottom:10px}.go-a11y__toggle{font-size:.75rem}}';
	wp_add_inline_style( 'go-verge', $css );
}
add_action( 'wp_enqueue_scripts', 'go_verge_inline_product_shell_css', 1910 );

/**
 * On listing surfaces these sheets style below-the-fold product/newsletter
 * features. Load them without blocking first paint, while keeping singles
 * synchronous so article components never flash unstyled.
 */
function go_verge_async_listing_styles( $tag, $handle, $href, $media ) {
	if ( is_admin() || ! ( is_front_page() || is_home() || is_archive() || is_search() ) ) {
		return $tag;
	}

	$allowed = array( 'go-verge-product', 'jetpack-subscriptions' );
	if ( ! in_array( $handle, $allowed, true ) ) {
		return $tag;
	}

	$target_media = $media ? $media : 'all';
	$async = sprintf(
		'<link rel="stylesheet" id="%1$s-css" href="%2$s" media="print" data-go-async-media="%3$s" onload="this.media=this.dataset.goAsyncMedia;this.removeAttribute(\'onload\')">',
		esc_attr( $handle ),
		esc_url( $href ),
		esc_attr( $target_media )
	);
	return $async . '<noscript>' . $tag . '</noscript>';
}
add_filter( 'style_loader_tag', 'go_verge_async_listing_styles', 30, 4 );

/* The delayed listing AdSense loader was removed: its hook was never
 * registered and the front-end controller already owns a single async loader. */

/** Return whether one queued script recursively depends on jQuery. */
function go_verge_script_depends_on_jquery( $scripts, $handle, &$seen = array() ) {
	if ( in_array( $handle, array( 'jquery', 'jquery-core' ), true ) ) {
		return true;
	}
	if ( isset( $seen[ $handle ] ) || empty( $scripts->registered[ $handle ] ) ) {
		return false;
	}
	$seen[ $handle ] = true;
	foreach ( (array) $scripts->registered[ $handle ]->deps as $dep ) {
		if ( go_verge_script_depends_on_jquery( $scripts, $dep, $seen ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Defer jQuery only when every queued consumer belongs to the known lightweight
 * companion/subscription layer. Unknown plugin dependencies keep the original
 * blocking behavior instead of risking a production regression.
 */
function go_verge_maybe_defer_safe_jquery() {
	if ( is_admin() || go_verge_page_needs_legacy_assets() ) {
		return;
	}
	$scripts = wp_scripts();
	if ( ! ( $scripts instanceof WP_Scripts ) || empty( $scripts->registered['jquery-core'] ) ) {
		return;
	}

	$allowed_fragments = array( 'newsx-core-pro-public.js', '/blocks/subscription-view.js' );
	$consumers = array();
	foreach ( (array) $scripts->queue as $handle ) {
		if ( in_array( $handle, array( 'jquery', 'jquery-core', 'jquery-migrate' ), true ) || empty( $scripts->registered[ $handle ] ) ) {
			continue;
		}
		$seen = array();
		if ( ! go_verge_script_depends_on_jquery( $scripts, $handle, $seen ) ) {
			continue;
		}
		$src = (string) $scripts->registered[ $handle ]->src;
		$known = false;
		foreach ( $allowed_fragments as $fragment ) {
			if ( false !== strpos( $src, $fragment ) ) {
				$known = true;
				break;
			}
		}
		if ( ! $known ) {
			return;
		}
		$consumers[] = $handle;
	}

	$core_extra = isset( $scripts->registered['jquery-core']->extra ) ? (array) $scripts->registered['jquery-core']->extra : array();
	if ( ! empty( $core_extra['before'] ) || ! empty( $core_extra['after'] ) ) {
		return;
	}

	wp_script_add_data( 'jquery-core', 'strategy', 'defer' );
	foreach ( $consumers as $handle ) {
		wp_script_add_data( $handle, 'strategy', 'defer' );
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_maybe_defer_safe_jquery', 1990 );

/**
 * Lower fetch priority for enhancement scripts that are not required to paint
 * the first screen or start the AdSense auction. They still execute with their
 * existing defer strategy; this only stops them competing with LCP resources.
 */
function go_verge_low_priority_enhancement_scripts( $tag, $handle, $src ) {
	if ( is_admin() ) {
		return $tag;
	}
	$low = array(
		'go-verge-smart-framing',
		'go-verge-article-audio',
		'go-verge-product',
		'go-verge-overdrive-v65-revenue-intelligence',
		'go-verge-viewport-stability',
	);
	if ( ! in_array( $handle, $low, true ) || false !== stripos( $tag, 'fetchpriority=' ) ) {
		return $tag;
	}
	return preg_replace( '/<script\b/i', '<script fetchpriority="low"', $tag, 1 );
}
add_filter( 'script_loader_tag', 'go_verge_low_priority_enhancement_scripts', 20, 3 );


/**
 * Give card images a truthful responsive slot instead of WordPress' generic
 * `auto` hint, which can make narrow screens download a 768 px candidate for
 * a card that never needs it.
 */
function go_verge_card_image_sizes_hint( $attr, $attachment, $size ) {
	$is_card = 'go_card' === $size || ( is_array( $size ) && 640 === (int) ( $size[0] ?? 0 ) );
	if ( ! $is_card ) {
		return $attr;
	}

	/*
	 * Respect component-specific hints first. The homepage already knows that
	 * topic cards, compact panels and hero side cards occupy much smaller slots
	 * than a generic 640 px card. Overwriting those hints made browsers fetch a
	 * 768 px candidate for elements rendered around 224 px wide.
	 */
	$current = isset( $attr['sizes'] ) ? trim( (string) $attr['sizes'] ) : '';
	// WordPress prepends "auto," to lazy images, including explicit component
	// hints. Preserve that real slot instead of replacing it with a full row.
	$fallback = trim( (string) preg_replace( '/^auto\s*,\s*/i', '', $current ) );
	if ( '' !== $fallback && 'auto' !== strtolower( $fallback ) ) {
		return $attr;
	}

	$attr['sizes'] = '(max-width: 767px) calc(100vw - 32px), (max-width: 1199px) 50vw, 420px';

	/* Card imagery is never the article LCP. Give the browser an explicit low
	 * fetch priority unless a component has already promoted the image. This keeps
	 * long feeds and recommendation rails from competing with the featured image,
	 * critical CSS and the first revenue-critical ad request on mobile. */
	if ( empty( $attr['fetchpriority'] ) && ( empty( $attr['loading'] ) || 'eager' !== strtolower( (string) $attr['loading'] ) ) ) {
		$attr['fetchpriority'] = 'low';
	}
	return $attr;
}
add_filter( 'wp_get_attachment_image_attributes', 'go_verge_card_image_sizes_hint', 25, 3 );

/* The entire advertising system — inventory, editorial density, the manual
 * top-scroll, Auto Ads contract and presentation layer — lives under inc/ads/.
 * inc/ads.php only loads it. */
require_once GO_VERGE_DIR . '/inc/ads.php';


/**
 * Modules.
 */
require_once GO_VERGE_DIR . '/inc/seo-media.php';
require_once GO_VERGE_DIR . '/inc/litespeed-compat.php';
require_once GO_VERGE_DIR . '/inc/burst-compat.php';
/* editorial-linking first: it owns go_verge_read_more_markup(), which the
 * recirculation module reuses for the mid-article block. */
require_once GO_VERGE_DIR . '/inc/editorial-linking.php';
require_once GO_VERGE_DIR . '/inc/single-recirculation.php';
require_once GO_VERGE_DIR . '/inc/homepage-urgent.php';
require_once GO_VERGE_DIR . '/inc/homepage-hero-admin.php';
require_once GO_VERGE_DIR . '/inc/homepage-search-only.php';
require_once GO_VERGE_DIR . '/inc/editor-split-image.php';
require_once GO_VERGE_DIR . '/inc/game-intelligence.php';
require_once GO_VERGE_DIR . '/inc/cpt.php';
require_once GO_VERGE_DIR . '/inc/rebrand.php';
require_once GO_VERGE_DIR . '/inc/editorial-scope.php';
require_once GO_VERGE_DIR . '/inc/template-helpers.php';
require_once GO_VERGE_DIR . '/inc/single-clean.php';
require_once GO_VERGE_DIR . '/inc/specials.php';
require_once GO_VERGE_DIR . '/inc/specials-gallery.php';
require_once GO_VERGE_DIR . '/inc/editorial-presentation.php';
require_once GO_VERGE_DIR . '/inc/editorial-layouts.php';
require_once GO_VERGE_DIR . '/inc/logo.php';
require_once GO_VERGE_DIR . '/inc/reviews.php';
require_once GO_VERGE_DIR . '/inc/review-genres.php';
require_once GO_VERGE_DIR . '/inc/games.php';
require_once GO_VERGE_DIR . '/inc/game-editor.php';
require_once GO_VERGE_DIR . '/inc/product-features.php';
require_once GO_VERGE_DIR . '/inc/go-editorial-panel.php';
require_once GO_VERGE_DIR . '/inc/publisher-identity.php';
require_once GO_VERGE_DIR . '/inc/author-profiles.php';
require_once GO_VERGE_DIR . '/inc/content-classification.php';
require_once GO_VERGE_DIR . '/inc/seo.php';
require_once GO_VERGE_DIR . '/inc/rank-math-compat.php';
require_once GO_VERGE_DIR . '/inc/yoast-compat.php';
require_once GO_VERGE_DIR . '/inc/review-technical-details.php';
require_once GO_VERGE_DIR . '/inc/editorial-trust-seo.php';
require_once GO_VERGE_DIR . '/inc/authority-eeat.php';
require_once GO_VERGE_DIR . '/inc/editorial-evidence.php';
require_once GO_VERGE_DIR . '/inc/seo-authority-ai.php';
require_once GO_VERGE_DIR . '/inc/indexing-intelligence.php';
require_once GO_VERGE_DIR . '/inc/semantic-annotations.php';
require_once GO_VERGE_DIR . '/inc/search-visibility.php';
require_once GO_VERGE_DIR . '/inc/discover-cwv.php';
require_once GO_VERGE_DIR . '/inc/editorial-media-workflow.php';
require_once GO_VERGE_DIR . '/inc/editorial-image-crop.php';
require_once GO_VERGE_DIR . '/inc/editorial-image-text.php';
require_once GO_VERGE_DIR . '/inc/editorial-tools.php';
if ( is_admin() ) {
	require_once GO_VERGE_DIR . '/inc/institutional-content.php';
}
require_once GO_VERGE_DIR . '/inc/accessibility-seo.php';
require_once GO_VERGE_DIR . '/inc/sitemap-news.php';
require_once GO_VERGE_DIR . '/inc/sitemap-smart.php';
require_once GO_VERGE_DIR . '/inc/indexing-integrity.php';
/* Large back-office dashboards do not belong on anonymous front-end
 * requests. admin-ajax.php reports is_admin()=true; cron keeps the SERP cache
 * invalidation hook available when statistics sync outside wp-admin. */
if ( is_admin() ) {
	require_once GO_VERGE_DIR . '/inc/search-console-setup.php';
require_once GO_VERGE_DIR . '/inc/admin-live-post-views.php';
}
if ( is_admin() || wp_doing_cron() ) {
	require_once GO_VERGE_DIR . '/inc/admin-serp-column.php';
}
if ( is_admin() ) {
	require_once GO_VERGE_DIR . '/inc/admin-branding.php';
	require_once GO_VERGE_DIR . '/inc/admin-posts-workspace.php';
}
require_once GO_VERGE_DIR . '/inc/search-freshness.php';
require_once GO_VERGE_DIR . '/inc/internal-links.php';
require_once GO_VERGE_DIR . '/inc/link-popularity.php';
require_once GO_VERGE_DIR . '/inc/tag-consolidation.php';
require_once GO_VERGE_DIR . '/inc/editorial-category-consolidation.php';
require_once GO_VERGE_DIR . '/inc/entertainment-category-architecture.php';
require_once GO_VERGE_DIR . '/inc/editorial-parent-canonical.php';
require_once GO_VERGE_DIR . '/inc/search-indexing-architecture.php';
require_once GO_VERGE_DIR . '/inc/semrush-audit-hardening.php';
require_once GO_VERGE_DIR . '/inc/entity-schema.php';
require_once GO_VERGE_DIR . '/inc/entity-admin-v24.php';
require_once GO_VERGE_DIR . '/inc/entity-intelligence-v27.php';
require_once GO_VERGE_DIR . '/inc/hardening.php';
require_once GO_VERGE_DIR . '/inc/anti-spam.php';
require_once GO_VERGE_DIR . '/inc/engagement.php';
require_once GO_VERGE_DIR . '/inc/publish-assistant.php';
require_once GO_VERGE_DIR . '/inc/editorial-integration-v6.php';
require_once GO_VERGE_DIR . '/inc/editorial-architecture-v7.php';
require_once GO_VERGE_DIR . '/inc/technology-indexing-hardening.php';
require_once GO_VERGE_DIR . '/inc/category-indexing-parity.php';
require_once GO_VERGE_DIR . '/inc/news-authority.php';
require_once GO_VERGE_DIR . '/inc/x-autopublish.php';
require_once GO_VERGE_DIR . '/inc/media-kit.php';
require_once GO_VERGE_DIR . '/inc/audience-context.php';
require_once GO_VERGE_DIR . '/inc/editor-link-search.php';
require_once GO_VERGE_DIR . '/inc/channel-invite.php';
require_once GO_VERGE_DIR . '/inc/asset-bundle.php';
require_once GO_VERGE_DIR . '/inc/search-observatory.php';
require_once GO_VERGE_DIR . '/inc/discover-health.php';

/**
 * Render the primary navigation with a robust fallback chain:
 * 1) menu assigned to the `primary` location,
 * 2) otherwise the "Menu principal" menu by slug (so it works right after activation),
 * 3) otherwise a page list.
 */
function go_verge_primary_menu( $args = array() ) {
	if ( function_exists( 'go_verge_v7_render_primary_nav' ) ) {
		go_verge_v7_render_primary_nav();
		return;
	}

	$defaults = array(
		'theme_location' => 'primary',
		'container'      => false,
		'menu_class'     => 'go-nav__list',
		'depth'          => 2,
		'fallback_cb'    => false,
	);
	$args = wp_parse_args( $args, $defaults );

	if ( has_nav_menu( 'primary' ) ) {
		wp_nav_menu( $args );
		return;
	}

	$by_slug = wp_get_nav_menu_object( 'menu-principal' );
	if ( $by_slug ) {
		$args['menu'] = $by_slug;
		unset( $args['theme_location'] );
		wp_nav_menu( $args );
		return;
	}

	wp_page_menu( array(
		'menu_class' => 'go-nav__list',
		'show_home'  => true,
	) );
}

/**
 * Excerpt tuning — Verge decks are short.
 */
function go_verge_excerpt_length() {
	return 24;
}
add_filter( 'excerpt_length', 'go_verge_excerpt_length', 999 );

function go_verge_excerpt_more() {
	return '…';
}
add_filter( 'excerpt_more', 'go_verge_excerpt_more' );

/**
 * Body classes.
 */
/**
 * Strip WordPress core's default "Archives:"/"Category:"/"Tag:" prefix —
 * the design system reads the title cleanly (kickers already carry context).
 */
function go_verge_unprefixed_archive_title( $title, $original_title ) {
	return $original_title;
}
add_filter( 'get_the_archive_title', 'go_verge_unprefixed_archive_title', 10, 2 );

function go_verge_body_classes( $classes ) {
	$classes[] = 'go-verge';
	if ( ! is_singular() ) {
		$classes[] = 'go-stream';
	}

	/*
	 * Give the three main editorial hubs a restrained visual identity without
	 * fragmenting the product into separate themes. The same class also follows
	 * category archives that clearly belong to one of those pillars.
	 */
	$editorial_zone = '';
	$queried_slug   = '';
	$template_slug  = '';
	$request_path   = '';
	$queried_object = get_queried_object();
	if ( $queried_object instanceof WP_Post ) {
		$queried_slug  = sanitize_title( $queried_object->post_name );
		$template_slug = sanitize_title( basename( (string) get_page_template_slug( $queried_object->ID ), '.php' ) );
	} elseif ( $queried_object instanceof WP_Term ) {
		$queried_slug = sanitize_title( $queried_object->slug );
	}
	if ( isset( $_SERVER['REQUEST_URI'] ) ) {
		$request_path = trim( (string) wp_parse_url( wp_unslash( $_SERVER['REQUEST_URI'] ), PHP_URL_PATH ), '/' );
	}
	$zone_haystack = implode( ' ', array_filter( array( $queried_slug, $template_slug, $request_path, (string) get_query_var( 'pagename' ) ) ) );

	$is_editorial_destination = is_page() || is_category() || is_post_type_archive( 'games' );
	if ( is_post_type_archive( 'games' ) || is_page( array( 'games' ) ) || ( $is_editorial_destination && preg_match( '/(^|\/)games(\/|$)/', $zone_haystack ) ) ) {
		$editorial_zone = 'games';
	} elseif ( is_page( array( 'entretenimento' ) ) || ( $is_editorial_destination && preg_match( '/entretenimento|page-entretenimento/', $zone_haystack ) ) ) {
		$editorial_zone = 'entertainment';
	} elseif ( is_page( array( 'tecnologia', 'tech' ) ) || ( $is_editorial_destination && preg_match( '/tecnologia|page-tecnologia|(^|\/)tech(\/|$)/', $zone_haystack ) ) ) {
		$editorial_zone = 'technology';
	}

	if ( $editorial_zone ) {
		$classes[] = 'go-editorial-zone';
		$classes[] = 'go-editorial-hub';
		$classes[] = 'go-editorial-zone--' . sanitize_html_class( $editorial_zone );
	}

	// Every editorial surface also carries its accent key so Séries, Filmes,
	// Reviews, Críticas and Dicas e Guias share the same restrained colour on
	// the H1 signature, the active filter and hovers — without a full reskin.
	if ( function_exists( 'go_verge_editorial_accent_key' ) && ( is_page() || is_category() || is_tax() || is_post_type_archive( 'games' ) ) ) {
		$accent_key = go_verge_editorial_accent_key( $queried_object );
		if ( '' === $accent_key && '' !== $editorial_zone ) {
			$accent_key = $editorial_zone;
		}
		if ( '' !== $accent_key ) {
			$classes[] = 'go-accent';
			$classes[] = 'go-accent--' . sanitize_html_class( $accent_key );

			// Subeditorias share their parent visual family: Reviews/Guias = Games;
			// Críticas/Séries/Filmes = Entretenimento; Tecnologia remains blue.
			if ( function_exists( 'go_verge_editorial_color_group' ) ) {
				$color_group = go_verge_editorial_color_group( $accent_key );
				if ( $color_group && ! in_array( 'go-editorial-zone--' . $color_group, $classes, true ) ) {
					$classes[] = 'go-editorial-zone';
					$classes[] = 'go-editorial-hub';
					$classes[] = 'go-editorial-zone--' . sanitize_html_class( $color_group );
				}
			}
		}
	}

	// Platform destinations keep the global design but receive a restrained
	// brand accent on titles, chips and ecosystem details.
	$platform_brand = '';
	if ( is_category() && function_exists( 'go_verge_platform_key_for_term' ) ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$platform_brand = go_verge_platform_key_for_term( $term );
		}
	} elseif ( is_singular( 'go_entity' ) || is_page( array( 'playstation', 'xbox', 'nintendo' ) ) ) {
		$slug = (string) get_post_field( 'post_name', get_queried_object_id() );
		if ( preg_match( '/playstation|ps5|ps4/', $slug ) ) {
			$platform_brand = 'playstation';
		} elseif ( false !== strpos( $slug, 'xbox' ) ) {
			$platform_brand = 'xbox';
		} elseif ( preg_match( '/nintendo|switch/', $slug ) ) {
			$platform_brand = 'nintendo';
		}
	}
	if ( in_array( $platform_brand, array( 'playstation', 'xbox', 'nintendo' ), true ) ) {
		$classes[] = 'go-platform-brand';
		$classes[] = 'go-platform-brand--' . sanitize_html_class( $platform_brand );
	}


	/*
	 * Single articles inherit the colour of their editorial pillar so inline
	 * hyperlinks can use the site's own neon palette instead of one global blue.
	 * Reviews/guides remain Games; critiques and cultural verticals inherit
	 * Entertainment; technology keeps its blue accent.
	 */
	if ( is_singular( 'post' ) ) {
		$single_zone  = 'games';
		$single_terms = wp_get_post_terms( get_queried_object_id(), 'category' );
		$single_slugs = array();

		if ( ! is_wp_error( $single_terms ) ) {
			foreach ( $single_terms as $single_term ) {
				$single_slugs[] = sanitize_title( $single_term->slug );
				foreach ( get_ancestors( $single_term->term_id, 'category', 'taxonomy' ) as $single_ancestor_id ) {
					$single_ancestor = get_term( $single_ancestor_id, 'category' );
					if ( $single_ancestor instanceof WP_Term ) {
						$single_slugs[] = sanitize_title( $single_ancestor->slug );
					}
				}
			}
		}

		$single_slugs = array_values( array_unique( array_filter( $single_slugs ) ) );
		$zone_scores  = array(
			'games'         => 1,
			'entertainment' => 0,
			'technology'    => 0,
		);

		$root_signals = array(
			'games'         => array( 'games', 'jogos' ),
			'entertainment' => array( 'entretenimento' ),
			'technology'    => array( 'tecnologia', 'technology' ),
		);
		$specific_signals = array(
			'games' => array(
				'reviews', 'review', 'analises-de-jogos', 'dicas-e-guias', 'guias', 'guia',
				'tutoriais', 'tutorial', 'playstation', 'ps5', 'ps4', 'xbox', 'nintendo',
				'nintendo-switch', 'switch', 'pc', 'steam', 'mobile', 'lancamentos', 'listas',
				'rankings', 'especiais', 'promocoes', 'como-roda', 'impressoes', 'noticias-de-games',
			),
			'entertainment' => array(
				'series', 'serie', 'filmes', 'filme', 'cinema', 'animes', 'anime', 'manga',
				'mangas', 'quadrinhos', 'criticas', 'critica', 'onde-assistir', 'final-explicado',
				'tv', 'televisao', 'cultura-pop', 'noticias-de-entretenimento', 'mangas-e-quadrinhos',
			),
			'technology' => array(
				'tech', 'celulares', 'celular', 'smartphones', 'smartphone', 'hardware', 'software',
				'inteligencia-artificial', 'ia', 'internet', 'mobilidade', 'casa-inteligente', 'eletrodomesticos', 'wearables', 'servico', 'seguranca-digital', 'aplicativos', 'noticias-de-tecnologia',
			),
		);

		foreach ( $single_slugs as $single_slug ) {
			foreach ( $root_signals as $zone_key => $signals ) {
				if ( in_array( $single_slug, $signals, true ) ) {
					$zone_scores[ $zone_key ] += 20;
				}
			}
			foreach ( $specific_signals as $zone_key => $signals ) {
				if ( in_array( $single_slug, $signals, true ) ) {
					$zone_scores[ $zone_key ] += 3;
				}
			}
		}

		$highest_score = max( $zone_scores );
		foreach ( array( 'games', 'entertainment', 'technology' ) as $zone_key ) {
			if ( $zone_scores[ $zone_key ] === $highest_score ) {
				$single_zone = $zone_key;
				break;
			}
		}

		$classes[] = 'go-single-zone--' . sanitize_html_class( $single_zone );
	}

	if ( is_singular( 'post' ) && function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( get_queried_object_id() ) ) {
		$classes[] = 'go-critique-single';
	} elseif ( is_singular( 'post' ) && function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( get_queried_object_id() ) ) {
		$classes[] = 'go-review-single';
	}

	if ( is_category( array( 'criticas', 'critica' ) ) || is_page( array( 'criticas', 'critica' ) ) ) {
		$classes[] = 'go-review-index';
		$classes[] = 'go-critique-index';
	} elseif ( is_category( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ) ) || is_page( array( 'reviews', 'review' ) ) ) {
		$classes[] = 'go-review-index';
	}

	return $classes;
}
add_filter( 'body_class', 'go_verge_body_classes' );

/**
 * Recursively keep only JSON-safe values from WP_Query vars.
 */
function go_verge_load_more_safe_value( $value ) {
	if ( is_null( $value ) || is_scalar( $value ) ) {
		return $value;
	}
	if ( is_array( $value ) ) {
		$out = array();
		foreach ( $value as $key => $item ) {
			$clean = go_verge_load_more_safe_value( $item );
			if ( null !== $clean || null === $item ) {
				$out[ $key ] = $clean;
			}
		}
		return $out;
	}
	return null;
}

/**
 * Sign the public query state used by the generic load-more endpoint.
 */
function go_verge_load_more_payload( WP_Query $query ) {
	$vars = go_verge_load_more_safe_value( $query->query_vars );
	foreach ( array( 'paged', 'page', 'offset', 'fields', 'cache_results', 'update_post_meta_cache', 'update_post_term_cache' ) as $key ) {
		unset( $vars[ $key ] );
	}
	$vars['post_status']    = 'publish';
	$vars['no_found_rows']  = false;
	$vars['cache_results']  = true;

	$json = wp_json_encode( $vars );
	if ( ! is_string( $json ) || '' === $json ) {
		return array( '', '' );
	}
	$payload   = rtrim( strtr( base64_encode( $json ), '+/', '-_' ), '=' );
	$signature = hash_hmac( 'sha256', $payload, wp_salt( 'nonce' ) );
	return array( $payload, $signature );
}

/**
 * Replace numbered pagination on editorial pages with one progressive button.
 *
 * @param WP_Query|null $query Current/custom query.
 * @param array         $add_args Kept for backwards compatibility.
 * @param array         $options mode + optional target selector.
 */
function go_verge_pagination( $query = null, $add_args = array(), $options = array() ) {
	global $wp_query;
	$query = $query instanceof WP_Query ? $query : $wp_query;
	if ( ! $query instanceof WP_Query || (int) $query->max_num_pages < 2 ) {
		return;
	}

	$options = wp_parse_args(
		is_array( $options ) ? $options : array(),
		array(
			'mode'          => 'archive-list',
			'target'        => '',
			'label'         => __( 'Carregar mais publicações', 'go-verge' ),
			'media_context' => 'card',
			'sync_history'   => true,
			'next_url'       => '',
		)
	);

	$current = max( 1, (int) $query->get( 'paged' ), (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );

	/* Direct visits to /page/N/ must remain useful even on the final page. Large
	 * editorial sites keep paginated URLs crawlable in both directions; the
	 * infinite loader is only progressive enhancement. A small contextual nav
	 * gives readers and crawlers a real <a href> back toward fresher stories
	 * without putting page-number clutter in the masthead. */
	if ( $current > 1 && ! empty( $options['sync_history'] ) && in_array( sanitize_key( (string) $options['mode'] ), array( 'archive-list', 'stream', 'tile-grid' ), true ) ) {
		$previous_url = get_pagenum_link( max( 1, $current - 1 ) );
		$first_url    = get_pagenum_link( 1 );
		echo '<nav class="go-pagination-context" data-go-pagination-context data-current-page="' . esc_attr( $current ) . '" aria-label="' . esc_attr__( 'Navegação das publicações', 'go-verge' ) . '">';
		echo '<a class="go-pagination-context__prev" data-go-pagination-prev rel="prev" href="' . esc_url( $previous_url ) . '">← ' . esc_html__( 'Publicações mais recentes', 'go-verge' ) . '</a>';
		if ( $current > 2 && untrailingslashit( $first_url ) !== untrailingslashit( $previous_url ) ) {
			echo '<a class="go-pagination-context__first" data-go-pagination-first href="' . esc_url( $first_url ) . '">' . esc_html__( 'Início da editoria', 'go-verge' ) . '</a>';
		}
		echo '</nav>';
	}

	if ( $current >= (int) $query->max_num_pages ) {
		return;
	}

	list( $payload, $signature ) = go_verge_load_more_payload( $query );
	if ( '' === $payload || '' === $signature ) {
		return;
	}

	$media_context = in_array( sanitize_key( (string) $options['media_context'] ), array( 'card', 'latest' ), true )
		? sanitize_key( (string) $options['media_context'] )
		: 'card';

	$next_url = ! empty( $options['next_url'] ) ? (string) $options['next_url'] : get_pagenum_link( $current + 1 );
	$history_attr = ! empty( $options['sync_history'] ) ? '' : ' data-go-no-history="1"';
	$rel_attr     = ! empty( $options['sync_history'] ) ? ' rel="next"' : '';

	/*
	 * Progressive enhancement: this control is a real crawlable link first and
	 * becomes an AJAX/infinite-loader only when JavaScript is available. This
	 * keeps older archive pages discoverable through ordinary <a href> links
	 * while preserving the instant reader experience.
	 */
	printf(
		'<div class="go-load-more-wrap"><a class="go-load-more" href="%9$s"%11$s data-go-load-more data-query="%1$s" data-signature="%2$s" data-page="%3$d" data-max="%4$d" data-mode="%5$s" data-target="%6$s" data-media-context="%7$s"%10$s><span class="go-load-more__label">%8$s</span><span class="go-load-more__icon" aria-hidden="true">↓</span></a></div>',
		esc_attr( $payload ),
		esc_attr( $signature ),
		$current,
		(int) $query->max_num_pages,
		esc_attr( sanitize_key( $options['mode'] ) ),
		esc_attr( (string) $options['target'] ),
		esc_attr( $media_context ),
		esc_html( $options['label'] ),
		esc_url( $next_url ),
		$history_attr, // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed attribute.
		$rel_attr // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed attribute.
	);
}

/**
 * Shared game-library card used by initial render and AJAX continuation.
 */
function go_verge_game_library_card( $post_id ) {
	go_verge_games_catalog_card( $post_id );
}

/**
 * Production-library card shared by the first archive page and AJAX batches.
 */
function go_verge_production_library_card( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'productions' !== get_post_type( $post_id ) ) {
		return;
	}
	$status  = get_post_meta( $post_id, '_go_production_status', true );
	$watch   = get_post_meta( $post_id, '_go_watch', true );
	$country = get_post_meta( $post_id, '_go_country', true );
	?>
	<article <?php post_class( 'go-v7-production-card', $post_id ); ?>>
		<a class="go-v7-production-card__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" aria-label="<?php echo esc_attr( get_the_title( $post_id ) ); ?>">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'medium_large', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-v7-production-card__placeholder" aria-hidden="true"></span>
			<?php endif; ?>
		</a>
		<div class="go-v7-production-card__body">
			<h2><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h2>
			<?php $meta = array_filter( array( $country, $status, $watch ) ); ?>
			<?php if ( $meta ) : ?><p><?php echo esc_html( implode( ' · ', $meta ) ); ?></p><?php endif; ?>
		</div>
	</article>
	<?php
}

/**
 * Classify one story inside a game hub coverage stream.
 *
 * Kept global because the same renderer is used by the initial template and
 * AJAX continuation; this keeps client-side filters truthful after page 1.
 *
 * @param int $post_id Story ID.
 * @return array<int,string>
 */
function go_verge_game_coverage_types( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return array();
	}

	$types = array();
	$is_review = function_exists( 'go_verge_product_related_post_matches_args' )
		? go_verge_product_related_post_matches_args( $post_id, array( 'category_slugs' => array( 'reviews', 'review', 'criticas', 'critica', 'analises', 'analise' ) ) )
		: false;
	$is_guide = function_exists( 'go_verge_product_related_post_matches_args' )
		? go_verge_product_related_post_matches_args( $post_id, array( 'category_slugs' => array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'tutoriais' ) ) )
		: false;
	$is_video = function_exists( 'go_verge_product_related_post_matches_args' )
		? go_verge_product_related_post_matches_args( $post_id, array( 'require_video' => true ) )
		: false;

	if ( $is_review ) { $types[] = 'reviews'; }
	if ( $is_guide ) { $types[] = 'guides'; }
	if ( $is_video ) { $types[] = 'videos'; }
	if ( ! $is_review && ! $is_guide ) { $types[] = 'news'; }

	return array_values( array_unique( $types ) );
}

/**
 * Standard horizontal row for a game hub. There is deliberately no oversized
 * first card: game/subject coverage now follows the same visual contract as
 * every other "Últimas publicações" feed.
 */
function go_verge_game_coverage_row( $post_id ) {
	go_verge_games_story_card( $post_id );
}

/**
 * Generic AJAX continuation for editorial lists, grids and the game library.
 */
function go_verge_ajax_load_more() {
	// Public read-only continuation. The signed HMAC query is the integrity gate;
	// do not strand cached pages behind an expiring WordPress nonce.

	$payload   = isset( $_POST['query'] ) ? sanitize_text_field( wp_unslash( $_POST['query'] ) ) : '';
	$signature = isset( $_POST['signature'] ) ? sanitize_text_field( wp_unslash( $_POST['signature'] ) ) : '';
	$page      = isset( $_POST['page'] ) ? max( 2, absint( wp_unslash( $_POST['page'] ) ) ) : 2;
	$mode      = isset( $_POST['mode'] ) ? sanitize_key( wp_unslash( $_POST['mode'] ) ) : 'archive-list';
	$media_context = isset( $_POST['media_context'] ) ? sanitize_key( wp_unslash( $_POST['media_context'] ) ) : 'card';
	if ( ! in_array( $media_context, array( 'card', 'latest' ), true ) ) {
		$media_context = 'card';
	}

	$expected = hash_hmac( 'sha256', $payload, wp_salt( 'nonce' ) );
	if ( '' === $payload || '' === $signature || ! hash_equals( $expected, $signature ) ) {
		wp_send_json_error( array( 'message' => __( 'Consulta inválida.', 'go-verge' ) ), 400 );
	}

	$padding = strlen( $payload ) % 4;
	if ( $padding ) {
		$payload .= str_repeat( '=', 4 - $padding );
	}
	$json = base64_decode( strtr( $payload, '-_', '+/' ), true );
	$vars = is_string( $json ) ? json_decode( $json, true ) : null;
	if ( ! is_array( $vars ) ) {
		wp_send_json_error( array( 'message' => __( 'Consulta inválida.', 'go-verge' ) ), 400 );
	}

	$vars['paged']          = $page;
	$vars['post_status']    = 'publish';
	$vars['no_found_rows']  = false;
	unset( $vars['page'], $vars['offset'], $vars['fields'] );

	$query = new WP_Query( $vars );

	// Recover the archive's editorial format so redundant format labels (Review/
	// Crítica) stay suppressed on appended pages, exactly as on the first render.
	// is_category() is false during admin-ajax, so resolve it from the query.
	$go_ajax_format = 'default';
	if ( function_exists( 'go_verge_format_for_term' ) ) {
		$go_ajax_term = $query->get_queried_object();
		if ( ! ( $go_ajax_term instanceof WP_Term ) && ! empty( $vars['category_name'] ) ) {
			$go_ajax_term = get_term_by( 'slug', basename( (string) $vars['category_name'] ), 'category' );
		}
		$go_ajax_format = go_verge_format_for_term( $go_ajax_term instanceof WP_Term ? $go_ajax_term : null );
	}
	if ( 'default' !== $go_ajax_format ) {
		$GLOBALS['go_verge_forced_archive_format'] = $go_ajax_format;
	}

	ob_start();

	while ( $query->have_posts() ) {
		$query->the_post();
		switch ( $mode ) {
			case 'stream':
				go_verge_stream_item(
					array(
						'id'            => get_the_ID(),
						'show_excerpt'  => true,
						'show_subtitle' => true,
					)
				);
				break;
			case 'tile-grid':
				go_verge_story_tile(
					array(
						'id'            => get_the_ID(),
						'size'          => 'standard',
						'show_excerpt'  => true,
						'show_subtitle' => true,
					)
				);
				break;
			case 'game-library':
				go_verge_game_library_card( get_the_ID() );
				break;
			case 'production-library':
				go_verge_production_library_card( get_the_ID() );
				break;
			case 'game-coverage':
				go_verge_game_coverage_row( get_the_ID() );
				break;
			case 'archive-list':
			default:
				go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'format' => $go_ajax_format, 'media_context' => $media_context ) );
				break;
		}
	}
	wp_reset_postdata();
	unset( $GLOBALS['go_verge_forced_archive_format'] );
	$html = ob_get_clean();

	wp_send_json_success(
		array(
			'html'    => $html,
			'page'    => $page,
			'maxPages'=> (int) $query->max_num_pages,
			'hasMore' => $page < (int) $query->max_num_pages,
		)
	);
}
add_action( 'wp_ajax_go_verge_load_more', 'go_verge_ajax_load_more' );
add_action( 'wp_ajax_nopriv_go_verge_load_more', 'go_verge_ajax_load_more' );


/**
 * AJAX pagination for the homepage "Últimas Publicações" stream.
 * The homepage intentionally uses only the load-more control.
 */
function go_verge_ajax_load_latest() {
	// Public read-only continuation: no expiring nonce so cached HTML cannot strand the feed.

	$page = isset( $_POST['page'] ) ? max( 1, absint( wp_unslash( $_POST['page'] ) ) ) : 1;
	$exclude_raw = isset( $_POST['exclude'] ) ? sanitize_text_field( wp_unslash( $_POST['exclude'] ) ) : '';
	$exclude_ids = array_values( array_unique( array_filter( array_map( 'absint', preg_split( '/[^0-9]+/', $exclude_raw ) ) ) ) );
	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 8,
			'paged'               => $page,
			'go_homepage_surface' => true,
			'ignore_sticky_posts' => true,
			'no_found_rows'       => false,
			'post__not_in'        => $exclude_ids,
		)
	);

	ob_start();
	while ( $query->have_posts() ) {
		$query->the_post();
		go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'media_context' => 'latest' ) );
	}
	wp_reset_postdata();
	$html = ob_get_clean();

	wp_send_json_success(
		array(
			'html'      => $html,
			'page'      => $page,
			'maxPages'  => (int) $query->max_num_pages,
			'hasMore'   => $page < (int) $query->max_num_pages,
		)
	);
}
add_action( 'wp_ajax_go_verge_load_latest', 'go_verge_ajax_load_latest' );
add_action( 'wp_ajax_nopriv_go_verge_load_latest', 'go_verge_ajax_load_latest' );


/**
 * Localize newsletter strings that may be emitted by subscription plugins.
 * Exact-match only, so unrelated admin/plugin copy is left untouched.
 */
function go_verge_localize_newsletter_plugin_strings( $translated, $text, $domain ) {
	$map = array(
		'Your email address'                            => 'Seu endereço de e-mail',
		'Sign Up Now'                                  => 'Assinar',
		'Subscribe'                                    => 'Assinar',
		'Sign up'                                      => 'Assinar',
		'I have read and agree to the terms & conditions' => 'Li e concordo com os termos e condições',
		'terms & conditions'                           => 'termos e condições',
	);

	return isset( $map[ $text ] ) ? $map[ $text ] : $translated;
}
add_filter( 'gettext', 'go_verge_localize_newsletter_plugin_strings', 20, 3 );

/**
 * -------------------------------------------------------------------------
 * Authors directory, editable author photos, and weighted site search.
 * -------------------------------------------------------------------------
 */

/**
 * Resolve a WordPress user ID from the values accepted by get_avatar().
 *
 * @param mixed $id_or_email Avatar subject.
 * @return int
 */
function go_verge_avatar_user_id( $id_or_email ) {
	if ( is_numeric( $id_or_email ) ) {
		return absint( $id_or_email );
	}
	if ( $id_or_email instanceof WP_User ) {
		return absint( $id_or_email->ID );
	}
	if ( $id_or_email instanceof WP_Post ) {
		return absint( $id_or_email->post_author );
	}
	if ( $id_or_email instanceof WP_Comment ) {
		if ( $id_or_email->user_id ) {
			return absint( $id_or_email->user_id );
		}
		$id_or_email = $id_or_email->comment_author_email;
	}
	if ( is_object( $id_or_email ) && ! empty( $id_or_email->user_id ) ) {
		return absint( $id_or_email->user_id );
	}
	if ( is_string( $id_or_email ) && is_email( $id_or_email ) ) {
		$user = get_user_by( 'email', $id_or_email );
		return $user instanceof WP_User ? absint( $user->ID ) : 0;
	}
	return 0;
}

/**
 * Return the custom author photo URL when one has been selected.
 *
 * @param int $user_id User ID.
 * @param int $size    Requested square size.
 * @return string
 */
function go_verge_author_photo_url( $user_id, $size = 96 ) {
	$photo_id = absint( get_user_meta( $user_id, 'go_verge_author_photo_id', true ) );
	if ( ! $photo_id || ! wp_attachment_is_image( $photo_id ) ) {
		return '';
	}

	$src = wp_get_attachment_image_src( $photo_id, array( max( 32, absint( $size ) ), max( 32, absint( $size ) ) ) );
	if ( is_array( $src ) && ! empty( $src[0] ) ) {
		return (string) $src[0];
	}

	$url = wp_get_attachment_url( $photo_id );
	return $url ? (string) $url : '';
}

/**
 * Use the editable author photo everywhere WordPress asks for an avatar URL.
 */
function go_verge_filter_author_avatar_url( $url, $id_or_email, $args ) {
	$user_id = go_verge_avatar_user_id( $id_or_email );
	if ( ! $user_id ) {
		return $url;
	}
	$size   = isset( $args['size'] ) ? absint( $args['size'] ) : 96;
	$custom = go_verge_author_photo_url( $user_id, $size );
	return $custom ? $custom : $url;
}
add_filter( 'get_avatar_url', 'go_verge_filter_author_avatar_url', 20, 3 );

/**
 * Replace avatar HTML too, so templates that call get_avatar() use the photo.
 */
function go_verge_filter_author_avatar_html( $avatar, $id_or_email, $size, $default, $alt, $args ) {
	$user_id = go_verge_avatar_user_id( $id_or_email );
	if ( ! $user_id ) {
		return $avatar;
	}
	$custom = go_verge_author_photo_url( $user_id, $size );
	if ( ! $custom ) {
		return $avatar;
	}

	$user       = get_userdata( $user_id );
	$alt_text   = $alt ? $alt : ( $user instanceof WP_User ? $user->display_name : '' );
	$extra      = isset( $args['class'] ) ? $args['class'] : array();
	$extra      = is_array( $extra ) ? $extra : preg_split( '/\s+/', (string) $extra );
	$classes    = array_merge( array( 'avatar', 'avatar-' . absint( $size ), 'photo' ), array_filter( $extra ) );
	$loading    = isset( $args['loading'] ) ? sanitize_key( $args['loading'] ) : 'lazy';
	$decoding   = isset( $args['decoding'] ) ? sanitize_key( $args['decoding'] ) : 'async';

	return sprintf(
		'<img alt="%1$s" src="%2$s" class="%3$s" height="%4$d" width="%4$d" loading="%5$s" decoding="%6$s">',
		esc_attr( $alt_text ),
		esc_url( $custom ),
		esc_attr( implode( ' ', array_unique( $classes ) ) ),
		absint( $size ),
		esc_attr( $loading ),
		esc_attr( $decoding )
	);
}
add_filter( 'get_avatar', 'go_verge_filter_author_avatar_html', 20, 6 );

/**
 * Add a media-library author photo picker to user profiles.
 *
 * @param WP_User $user User being edited.
 */
function go_verge_author_photo_profile_field( $user ) {
	if ( ! current_user_can( 'edit_user', $user->ID ) ) {
		return;
	}
	$photo_id  = absint( get_user_meta( $user->ID, 'go_verge_author_photo_id', true ) );
	$photo_url = $photo_id ? wp_get_attachment_image_url( $photo_id, 'thumbnail' ) : '';
	?>
	<h2><?php esc_html_e( 'Foto do autor', 'go-verge' ); ?></h2>
	<table class="form-table" role="presentation">
		<tr>
			<th><label for="go-verge-author-photo-id"><?php esc_html_e( 'Foto pública', 'go-verge' ); ?></label></th>
			<td>
				<div class="go-author-photo-picker" data-go-author-photo-picker>
					<div class="go-author-photo-picker__preview<?php echo $photo_url ? ' has-image' : ''; ?>" data-go-author-photo-preview>
						<?php if ( $photo_url ) : ?><img src="<?php echo esc_url( $photo_url ); ?>" alt=""><?php endif; ?>
					</div>
					<input type="hidden" id="go-verge-author-photo-id" name="go_verge_author_photo_id" value="<?php echo esc_attr( $photo_id ); ?>" data-go-author-photo-id>
					<div class="go-author-photo-picker__actions">
						<button type="button" class="button button-secondary" data-go-author-photo-select><?php esc_html_e( 'Escolher foto', 'go-verge' ); ?></button>
						<button type="button" class="button button-link-delete" data-go-author-photo-remove<?php echo $photo_id ? '' : ' hidden'; ?>><?php esc_html_e( 'Remover foto', 'go-verge' ); ?></button>
					</div>
					<p class="description"><?php esc_html_e( 'Esta imagem substitui o Gravatar nas matérias, na página do autor e na página de autores.', 'go-verge' ); ?></p>
				</div>
				<?php wp_nonce_field( 'go_verge_save_author_photo_' . $user->ID, 'go_verge_author_photo_nonce' ); ?>
			</td>
		</tr>
	</table>
	<?php
}
add_action( 'show_user_profile', 'go_verge_author_photo_profile_field', 5 );
add_action( 'edit_user_profile', 'go_verge_author_photo_profile_field', 5 );

/** Save the editable author photo. */
function go_verge_save_author_photo_profile_field( $user_id ) {
	if ( ! current_user_can( 'edit_user', $user_id ) ) {
		return;
	}
	$nonce = isset( $_POST['go_verge_author_photo_nonce'] ) ? sanitize_text_field( wp_unslash( $_POST['go_verge_author_photo_nonce'] ) ) : '';
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_author_photo_' . $user_id ) ) {
		return;
	}
	$photo_id = isset( $_POST['go_verge_author_photo_id'] ) ? absint( $_POST['go_verge_author_photo_id'] ) : 0;
	if ( $photo_id && wp_attachment_is_image( $photo_id ) ) {
		update_user_meta( $user_id, 'go_verge_author_photo_id', $photo_id );
	} else {
		delete_user_meta( $user_id, 'go_verge_author_photo_id' );
	}
}
add_action( 'personal_options_update', 'go_verge_save_author_photo_profile_field' );
add_action( 'edit_user_profile_update', 'go_verge_save_author_photo_profile_field' );

/** Load the media picker on profile screens. */
function go_verge_author_photo_admin_assets( $hook_suffix ) {
	if ( ! in_array( $hook_suffix, array( 'profile.php', 'user-edit.php' ), true ) ) {
		return;
	}
	wp_enqueue_media();
	wp_enqueue_style(
		'go-verge-author-profile-photo',
		GO_VERGE_URI . '/assets/css/author-profile-photo.css',
		array(),
		go_verge_asset_version( '/assets/css/author-profile-photo.css' )
	);
	wp_enqueue_script(
		'go-verge-author-profile-photo',
		GO_VERGE_URI . '/assets/js/author-profile-photo.js',
		array(),
		go_verge_asset_version( '/assets/js/author-profile-photo.js' ),
		true
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_author_photo_admin_assets' );

/** Searchable public content types. */
function go_verge_search_post_types() {
	$types = array( 'post', 'page' );
	foreach ( array( 'games', 'productions', 'go_entity' ) as $type ) {
		if ( post_type_exists( $type ) && is_post_type_viewable( $type ) ) {
			$types[] = $type;
		}
	}
	return array_values( array_unique( $types ) );
}

/** Apply search type filters and enable relevance weighting. */
function go_verge_prepare_main_search_query( $query ) {
	if ( is_admin() || ! $query->is_main_query() || ! $query->is_search() ) {
		return;
	}

	$type = isset( $_GET['tipo'] ) ? sanitize_key( wp_unslash( $_GET['tipo'] ) ) : 'todos';
	$map  = array(
		'materias' => array( 'post' ),
		'games'    => post_type_exists( 'games' ) ? array( 'games' ) : array(),
		'paginas'  => array( 'page' ),
	);
	$post_types = isset( $map[ $type ] ) && ! empty( $map[ $type ] ) ? $map[ $type ] : go_verge_search_post_types();

	$query->set( 'post_type', $post_types );
	$query->set( 'post_status', 'publish' );
	$query->set( 'has_password', false );
	$query->set( 'posts_per_page', 18 );
	$query->set( 'ignore_sticky_posts', true );
	$query->set( 'go_verge_weighted_search', 1 );
}
add_action( 'pre_get_posts', 'go_verge_prepare_main_search_query', 30 );

/** Add joins needed for taxonomy and author-name search. */
function go_verge_search_join( $join, $query ) {
	global $wpdb;
	if ( ! $query->get( 'go_verge_weighted_search' ) ) {
		return $join;
	}
	if ( false === strpos( $join, 'go_search_users' ) ) {
		$join .= " LEFT JOIN {$wpdb->users} AS go_search_users ON ({$wpdb->posts}.post_author = go_search_users.ID)";
	}
	if ( false === strpos( $join, 'go_search_tr' ) ) {
		$join .= " LEFT JOIN {$wpdb->term_relationships} AS go_search_tr ON ({$wpdb->posts}.ID = go_search_tr.object_id)";
		$join .= " LEFT JOIN {$wpdb->term_taxonomy} AS go_search_tt ON (go_search_tr.term_taxonomy_id = go_search_tt.term_taxonomy_id)";
		$join .= " LEFT JOIN {$wpdb->terms} AS go_search_terms ON (go_search_tt.term_id = go_search_terms.term_id)";
	}
	if ( false === strpos( $join, 'go_search_meta' ) ) {
		$meta_keys = array(
			'_go_post_subtitle', 'go_review_game_name', 'go_critique_work_name',
			'go_game_aliases', '_go_game_aliases', 'rank_math_focus_keyword'
		);
		$quoted = implode( ',', array_map( static function ( $key ) use ( $wpdb ) { return $wpdb->prepare( '%s', $key ); }, $meta_keys ) );
		$join .= " LEFT JOIN {$wpdb->postmeta} AS go_search_meta ON ({$wpdb->posts}.ID = go_search_meta.post_id AND go_search_meta.meta_key IN ({$quoted}))";
		$join .= " LEFT JOIN {$wpdb->postmeta} AS go_search_linked ON ({$wpdb->posts}.ID = go_search_linked.post_id AND go_search_linked.meta_key IN ('go_linked_game_id','go_review_game_id'))";
		$join .= " LEFT JOIN {$wpdb->posts} AS go_search_game ON (go_search_game.ID = CAST(go_search_linked.meta_value AS UNSIGNED) AND go_search_game.post_type = 'games')";
	}
	return $join;
}
add_filter( 'posts_join', 'go_verge_search_join', 20, 2 );

/** Replace WordPress' basic search clause with phrase + token matching. */
function go_verge_search_where( $search, $query ) {
	global $wpdb;
	if ( ! $query->get( 'go_verge_weighted_search' ) ) {
		return $search;
	}

	$needle = trim( (string) $query->get( 's' ) );
	if ( '' === $needle ) {
		return $search;
	}

	$field_group = static function ( $like ) use ( $wpdb ) {
		return $wpdb->prepare(
			"({$wpdb->posts}.post_title LIKE %s OR {$wpdb->posts}.post_excerpt LIKE %s OR {$wpdb->posts}.post_content LIKE %s OR go_search_users.display_name LIKE %s OR go_search_terms.name LIKE %s OR go_search_meta.meta_value LIKE %s OR go_search_game.post_title LIKE %s)",
			$like,
			$like,
			$like,
			$like,
			$like,
			$like,
			$like
		);
	};

	$phrase_like = '%' . $wpdb->esc_like( $needle ) . '%';
	$groups      = array( $field_group( $phrase_like ) );
	$tokens      = array_values( array_unique( array_filter( preg_split( '/\s+/u', $needle ) ) ) );
	$tokens      = array_slice( $tokens, 0, 6 );
	if ( count( $tokens ) > 1 ) {
		$token_groups = array();
		foreach ( $tokens as $token ) {
			$token_groups[] = $field_group( '%' . $wpdb->esc_like( $token ) . '%' );
		}
		$groups[] = '(' . implode( ' AND ', $token_groups ) . ')';
	}

	return ' AND (' . implode( ' OR ', $groups ) . ') ';
}
add_filter( 'posts_search', 'go_verge_search_where', 20, 2 );

/** Order main search results by editorial relevance, then freshness. */
function go_verge_search_orderby( $orderby, $query ) {
	global $wpdb;
	if ( ! $query->get( 'go_verge_weighted_search' ) ) {
		return $orderby;
	}
	$needle = trim( (string) $query->get( 's' ) );
	if ( '' === $needle ) {
		return $orderby;
	}
	$contains = '%' . $wpdb->esc_like( $needle ) . '%';
	$prefix   = $wpdb->esc_like( $needle ) . '%';

	$score = $wpdb->prepare(
		"(CASE
			WHEN {$wpdb->posts}.post_title = %s THEN 220
			WHEN {$wpdb->posts}.post_title LIKE %s THEN 175
			WHEN {$wpdb->posts}.post_title LIKE %s THEN 145
			WHEN go_search_game.post_title = %s THEN 135
			WHEN go_search_game.post_title LIKE %s THEN 120
			WHEN go_search_meta.meta_value LIKE %s THEN 105
			WHEN go_search_terms.name LIKE %s THEN 90
			WHEN go_search_users.display_name LIKE %s THEN 75
			WHEN {$wpdb->posts}.post_excerpt LIKE %s THEN 55
			WHEN {$wpdb->posts}.post_content LIKE %s THEN 25
			ELSE 5 END)",
		$needle,
		$prefix,
		$contains,
		$needle,
		$contains,
		$contains,
		$contains,
		$contains,
		$contains,
		$contains
	);
	return $score . " DESC, {$wpdb->posts}.post_date DESC";
}
add_filter( 'posts_orderby', 'go_verge_search_orderby', 20, 2 );

/** Avoid duplicate posts introduced by taxonomy joins. */
function go_verge_search_distinct( $distinct, $query ) {
	return $query->get( 'go_verge_weighted_search' ) ? 'DISTINCT' : $distinct;
}
add_filter( 'posts_distinct', 'go_verge_search_distinct', 20, 2 );

/** Human label for a suggestion result. */
function go_verge_search_result_type_label( $post_type ) {
	if ( 'post' === $post_type ) {
		return __( 'Matéria', 'go-verge' );
	}
	$object = get_post_type_object( $post_type );
	return $object && ! empty( $object->labels->singular_name ) ? $object->labels->singular_name : $post_type;
}

/** Bounded public title suggestions. */
require_once GO_VERGE_DIR . '/inc/search-suggestions.php';

function go_verge_register_search_suggestions_route() {
	register_rest_route(
		'go-verge/v1',
		'/search-suggestions',
		array(
			'methods'             => WP_REST_Server::READABLE,
			'callback'            => 'go_verge_rest_search_suggestions',
			'permission_callback' => '__return_true',
			'args'                => array(
				'q'     => array( 'required' => true, 'sanitize_callback' => 'sanitize_text_field' ),
				'limit' => array( 'sanitize_callback' => 'absint' ),
			),
		)
	);
}
add_action( 'rest_api_init', 'go_verge_register_search_suggestions_route' );

/** Load suggestions UI on the public site. */
function go_verge_search_frontend_assets() {
	if ( is_admin() ) {
		return;
	}
	$go_verge_search_rel = '/assets/js/enhanced-search.min.js';
	wp_enqueue_script(
		'go-verge-enhanced-search',
		GO_VERGE_URI . $go_verge_search_rel,
		array(),
		go_verge_asset_version( $go_verge_search_rel ),
		true
	);
	wp_localize_script(
		'go-verge-enhanced-search',
		'GoVergeSearch',
		array(
			'endpoint' => esc_url_raw( rest_url( 'go-verge/v1/search-suggestions' ) ),
			'minChars' => 3,
		)
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_search_frontend_assets', 35 );

/**
 * Final visual consistency layer.
 *
 * Kept separate from the large historical stylesheet so score components,
 * newsletter preferences and cross-site refinements have one authoritative
 * place at the end of the cascade.
 */
function go_verge_design_polish_assets() {
	$rel = '/assets/css/design-polish.min.css';
	wp_enqueue_style(
		'go-verge-design-polish',
		GO_VERGE_URI . $rel,
		array( 'go-verge', 'go-verge-product' ),
		go_verge_asset_version( $rel )
	);
}

/*
 * A reescrita do copy da newsletter é contextual e vive em
 * inc/audience-context.php: a promessa muda conforme a editoria da página e o
 * contato nasce marcado no segmento certo. Uma cópia fixa de games aqui
 * voltaria a prometer "ofertas de games" para quem chegou por uma série — e,
 * por registrar o mesmo filtro na mesma prioridade, venceria a contextual
 * dependendo da ordem de carga. Por isso ela não existe mais neste arquivo.
 */
add_action( 'wp_enqueue_scripts', 'go_verge_design_polish_assets', 1700 );

/**
 * Dedicated assets for the game single hub.
 */
function go_verge_game_hub_assets() {
	if ( ! is_singular( 'games' ) ) {
		return;
	}

	wp_enqueue_script(
		'go-verge-game-hub',
		GO_VERGE_URI . '/assets/js/game-hub.js',
		array(),
		go_verge_asset_version( '/assets/js/game-hub.js' ),
		true
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_game_hub_assets', 1710 );


/**
 * Runtime guards for the two-state masthead and fixed overlays.
 * This intentionally loads last so cache/optimizer bundles cannot revive older
 * header behavior or place the preferred-source prompt over an ad surface.
 */
function go_verge_runtime_fixes_assets() {
	$rel = '/assets/css/verge-runtime-fixes.min.css';
	wp_enqueue_style(
		'go-verge-runtime-fixes',
		GO_VERGE_URI . $rel,
		array( 'go-verge-design-polish' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_runtime_fixes_assets', 9999 );

/** X35 reader layout: stable CSS sidebar, neutral canvas and post-hero controls. */
function go_verge_x35_reader_portal_assets() {
	$style_rel = '/assets/css/x35-reader-portal.min.css';

	wp_enqueue_style(
		'go-verge-x35-reader-portal',
		GO_VERGE_URI . $style_rel,
		array( 'go-verge-runtime-fixes' ),
		go_verge_asset_version( $style_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_x35_reader_portal_assets', 10020 );

/* Ad origin resource hints now live in inc/ads.php (go_verge_ads_resource_hints). */

/* All provider integration lives under inc/ads/. Nothing ad-related is printed
 * directly from this legacy bootstrap. */

/** Final focused UI upgrades kept separate from the legacy theme bundle. */
function go_verge_enqueue_site_upgrades() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/site-upgrades.min.css';
	wp_enqueue_style(
		'go-verge-site-upgrades',
		GO_VERGE_URI . $rel,
		array( 'go-verge-x35-reader-portal' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_site_upgrades', 10050 );

/** Keep the reference masthead motion and a conflict-free mobile EM ALTA rail. */
function go_verge_enqueue_header_reference_parity() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/header-reference-parity.min.css';
	wp_enqueue_style(
		'go-verge-header-reference-parity',
		GO_VERGE_URI . $rel,
		array( 'go-verge-site-upgrades' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_header_reference_parity', 10060 );

/** Official Overdrive logo, palette and responsive brand hierarchy. */
function go_verge_enqueue_overdrive_rebrand() {
	if ( is_admin() ) {
		return;
	}

	$rel = '/assets/css/overdrive-rebrand.min.css';
	wp_enqueue_style(
		'go-verge-overdrive-rebrand',
		GO_VERGE_URI . $rel,
		array( 'go-verge-header-reference-parity' ),
		go_verge_asset_version( $rel )
	);

	/*
	 * No inline palette here on purpose.
	 *
	 * This used to carry the requested 2026 canvas as raw hexes — --canvas and
	 * the body background for both themes, plus a repaint of the header, its
	 * bar, the ticker and the offcanvas. Being inline and last, it silently won
	 * over every value in assets/css/overdrive-rebrand.css, so the stylesheet
	 * described a site that no longer existed. Worse, its selector list omitted
	 * .go-footer, which the stylesheet did paint: the footer kept the old deep
	 * navy while the rest of the chrome moved to #0B0712, and every page shipped
	 * two different darks.
	 *
	 * The canvas now lives once, as --overdrive-canvas-dark / -light in
	 * overdrive-rebrand.css, where it can be read, reviewed and changed.
	 */
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_rebrand', 10070 );

/** Final phone-specific UX and revenue tuning; inventory geometry is untouched. */
function go_verge_enqueue_mobile_rpm() {
	if ( is_admin() ) {
		return;
	}

	$rel = '/assets/css/mobile-rpm.min.css';
	wp_enqueue_style(
		'go-verge-mobile-rpm',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-rebrand' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_mobile_rpm', 10090 );

/**
 * The authoritative header, provider-coexistence and ad-geometry layer.
 *
 * Last on purpose. Six earlier layers carry rules for `.go-header` — 277 of them
 * between design-polish, verge-runtime-fixes, site-upgrades,
 * header-reference-parity, overdrive-rebrand and mobile-rpm — each written to
 * correct the previous one. Five of those six ship minified files with no build
 * step in the repository, so editing their sources would change nothing that
 * reaches a browser.
 *
 * This file states the whole contract once, at the end of the cascade, where it
 * can be read and reviewed as a single document. It is not minified: it is small
 * enough that the bytes do not matter and important enough that it should stay
 * legible.
 *
 * @return void
 */
function go_verge_enqueue_header_ads_architecture() {
	if ( is_admin() ) {
		return;
	}

	$rel = '/assets/css/header-ads-architecture.css';
	wp_enqueue_style(
		'go-verge-header-ads-architecture',
		GO_VERGE_URI . $rel,
		array( 'go-verge-mobile-rpm' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_header_ads_architecture', 10100 );


/**
 * Contratos de componente — ícones e rótulos editoriais.
 *
 * Mesmo remédio que a folha acima, aplicado a outros dois componentes que
 * tinham o mesmo problema: muitas folhas descrevendo a mesma coisa, nenhuma
 * com autoridade. Medido no site publicado, antes desta camada: 15 ícones na
 * grade 24×24 desenhados em três espessuras diferentes — `.go-iconbtn`
 * aparecia a 2px e a 1,8px no mesmo header — e o rótulo de formato e o de nota
 * dividindo o mesmo canto do card sem compartilhar fonte, forma nem altura.
 *
 * Carrega depois de header-ads-architecture porque precisa da última palavra,
 * e sem `.min` irmão pelo mesmo motivo declarado lá: neste repositório não há
 * build, então um `.min` presente faria o tema servir uma cópia velha e o
 * contrato passaria a mentir.
 *
 * @return void
 */
function go_verge_enqueue_component_contracts() {
	if ( is_admin() ) {
		return;
	}

	$rel = '/assets/css/component-contracts.min.css';
	wp_enqueue_style(
		'go-verge-component-contracts',
		GO_VERGE_URI . $rel,
		array( 'go-verge-header-ads-architecture' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_component_contracts', 10200 );


/** Selected visual refinements only; advertising layers remain the 3.10.0 baseline. */
function go_verge_enqueue_selected_refresh() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/selected-refresh.css';
	wp_enqueue_style(
		'go-verge-selected-refresh',
		GO_VERGE_URI . $rel,
		array( 'go-verge-component-contracts' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_selected_refresh', 10250 );


/**
 * Critical header geometry kept inline so CSS aggregation/cache layers cannot
 * resurrect the historical two-column mobile masthead. Header only: no ad
 * selectors or advertising geometry are touched here.
 */



/**
 * Remove Hostinger Reach block assets when the current document does not use
 * that block. Mailchimp/Jetpack remain untouched; this only avoids Reach CSS
 * and JavaScript requests that were loading on documents without its markup.
 */
function go_verge_remove_unused_reach_assets() {
	if ( is_admin() ) {
		return;
	}

	$post = get_queried_object();
	$content = $post instanceof WP_Post ? (string) $post->post_content : '';
	$uses_reach = false !== stripos( $content, 'hostinger-reach' ) ||
		false !== stripos( $content, 'wp-block-hostinger' );

	if ( $uses_reach ) {
		return;
	}

	wp_dequeue_style( 'hostinger-reach-subscription-block' );
	wp_dequeue_script( 'hostinger-reach-subscription-block-view' );
	/* Reach 3.x added a second global embed handle. It has no work when this
	 * document contains no Reach block, so keep it under the same content gate. */
	wp_dequeue_script( 'hostinger-reach-embed' );
	wp_dequeue_style( 'hostinger-reach-embed' );
}
add_action( 'wp_enqueue_scripts', 'go_verge_remove_unused_reach_assets', 10080 );

/**
 * A few independent scripts still arrived without a loading strategy. Defer
 * them without touching AdSense, Funding Choices or consent-mode ordering.
 */
function go_verge_defer_remaining_noncritical_scripts() {
	foreach ( array( 'go-verge', 'go-verge-editorial-tables', 'goam-tracker' ) as $handle ) {
		if ( wp_script_is( $handle, 'enqueued' ) ) {
			wp_script_add_data( $handle, 'strategy', 'defer' );
		}
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_defer_remaining_noncritical_scripts', 10090 );

/**
 * Ensure the public, human-readable sitemap page exists.
 *
 * The page is created once on activation/update without overwriting an
 * existing page with the same slug. This keeps the footer link dependable
 * while leaving editorial control with WordPress after creation.
 *
 * @return int Sitemap page ID, or 0 if creation failed.
 */
function go_verge_ensure_human_sitemap_page() {
	$page = get_page_by_path( 'mapa-do-site', OBJECT, 'page' );

	if ( $page instanceof WP_Post ) {
		$template = get_page_template_slug( $page->ID );
		if ( ( ! $template || 'default' === $template ) && '' === trim( (string) $page->post_content ) ) {
			update_post_meta( $page->ID, '_wp_page_template', 'page-mapa-do-site.php' );
		}
		return (int) $page->ID;
	}

	$page_id = wp_insert_post(
		array(
			'post_type'      => 'page',
			'post_status'    => 'publish',
			'post_title'     => __( 'Mapa do site', 'go-verge' ),
			'post_name'      => 'mapa-do-site',
			'post_content'   => '',
			'comment_status' => 'closed',
			'ping_status'    => 'closed',
		),
		true
	);

	if ( is_wp_error( $page_id ) ) {
		return 0;
	}

	update_post_meta( $page_id, '_wp_page_template', 'page-mapa-do-site.php' );
	return (int) $page_id;
}
add_action( 'after_switch_theme', 'go_verge_ensure_human_sitemap_page' );

/**
 * Also run the sitemap-page migration once when an already-active theme is
 * replaced through WordPress' ZIP updater, where after_switch_theme may not
 * fire because the stylesheet directory remains active.
 *
 * @return void
 */
function go_verge_maybe_upgrade_human_sitemap_page() {
	$version = '1';
	if ( $version === (string) get_option( 'go_verge_human_sitemap_schema', '' ) ) {
		return;
	}

	if ( go_verge_ensure_human_sitemap_page() ) {
		update_option( 'go_verge_human_sitemap_schema', $version, false );
	}
}
add_action( 'admin_init', 'go_verge_maybe_upgrade_human_sitemap_page', 30 );

/**
 * Load the sitemap layout only on the public sitemap page.
 *
 * @return void
 */
function go_verge_enqueue_human_sitemap_assets() {
	if ( is_admin() || ( ! is_page( 'mapa-do-site' ) && ! is_page_template( 'page-mapa-do-site.php' ) ) ) {
		return;
	}

	$rel = '/assets/css/sitemap-page.css';
	wp_enqueue_style(
		'go-verge-sitemap-page',
		GO_VERGE_URI . $rel,
		array( 'go-verge' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_human_sitemap_assets', 10400 );

/**
 * Overdrive 4.7.1 visual parity on top of the current News Magazine X theme.
 *
 * This intentionally loads after every historical front-end layer. It changes
 * presentation only; advertising provider code and slot geometry remain owned
 * by the existing advertising architecture.
 *
 * @return void
 */
function go_verge_enqueue_overdrive_471_parity() {
	if ( is_admin() ) {
		return;
	}

	/*
	 * 3.15.0 — the Google Fonts request is gone, and this is the "bigger win"
	 * the previous comment kept promising.
	 *
	 * Barlow Condensed and Source Sans 3 carry every headline and every word of
	 * body copy, so they sit on the critical path of every page view. They were
	 * also the only two families the site did not self-host: Space Grotesk,
	 * Newsreader, Space Mono and Anton already live in assets/fonts/ and are
	 * injected as inline @font-face, which is exactly why go_verge_assets() goes
	 * out of its way to keep a Google Fonts request off the page — and then this
	 * function put one back. Worse, it was loaded asynchronously, so the font
	 * FILES could not even be discovered until a preconnect, a cross-origin
	 * stylesheet and a second DNS hop had all completed. On a 4G phone that is
	 * comfortably half a second after first paint: a guaranteed visible swap and
	 * a guaranteed layout shift, on every document.
	 *
	 * Both families were already shipped in assets/fonts/, referenced by
	 * nothing. They are now declared in assets/css/verge-fonts.css with
	 * metric-matched fallbacks, and the two critical faces are preloaded from
	 * this origin in go_verge_preload_primary_font(). Removed along with the
	 * request: two preconnects, one stylesheet round trip, and four static
	 * Source Sans 3 weights that one variable file replaces.
	 */
	$style_rel = '/assets/css/overdrive-471-parity.css';
	wp_enqueue_style(
		'go-verge-overdrive-471-parity',
		GO_VERGE_URI . $style_rel,
		array( 'go-verge-selected-refresh' ),
		go_verge_asset_version( $style_rel )
	);

	$script_rel = '/assets/js/overdrive-471-parity.min.js';
	wp_enqueue_script(
		'go-verge-overdrive-471-parity',
		GO_VERGE_URI . $script_rel,
		array( 'go-verge' ),
		go_verge_asset_version( $script_rel ),
		true
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_471_parity', 20000 );

/**
 * Final single/article polish requested for the 4.7.1 parity build.
 * Kept in one last stylesheet so old News Magazine X layers cannot win by
 * source order on article components.
 *
 * @return void
 */
function go_verge_enqueue_overdrive_article_final() {
	if ( is_admin() || is_singular( 'post' ) ) {
		return;
	}
	$rel = '/assets/css/overdrive-471-article-final.css';
	wp_enqueue_style(
		'go-verge-overdrive-471-article-final',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-471-parity' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_article_final', 20100 );

/**
 * V8 authoritative UI/infinite-loading layer. It is intentionally last so old
 * News Magazine X compatibility files cannot repaint page shells or rebind the
 * pagination controller.
 */
function go_verge_enqueue_overdrive_v8_hotfix() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v8-hotfix.css';
	$js_rel  = '/assets/js/overdrive-v8-hotfix.min.js';
	$css_deps = is_singular( 'post' ) ? array( 'go-verge-overdrive-471-parity' ) : array( 'go-verge-overdrive-471-article-final' );
	wp_enqueue_style( 'go-verge-overdrive-v8-hotfix', GO_VERGE_URI . $css_rel, $css_deps, go_verge_asset_version( $css_rel ) );
	wp_enqueue_script( 'go-verge-overdrive-v8-hotfix', GO_VERGE_URI . $js_rel, array( 'go-verge' ), go_verge_asset_version( $js_rel ), true );
	wp_localize_script( 'go-verge-overdrive-v8-hotfix', 'GoVergeV8', array( 'ajaxUrl' => admin_url( 'admin-ajax.php' ) ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v8_hotfix', 22000 );


/**
 * V9 stability layer: global canvas, Games parity, compact logo, off-canvas,
 * filters, share card, decorative separators and ad placeholder geometry.
 */
function go_verge_enqueue_overdrive_v9_stability() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v9-stability.css';
	wp_enqueue_style(
		'go-verge-overdrive-v9-stability',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v8-hotfix' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v9_stability', 23000 );

/**
 * V11: authoritative in-article spacing and isolated share component.
 * Loaded last so historical visual layers cannot stretch either component.
 */
function go_verge_enqueue_overdrive_v11_rpm_share() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v11-rpm-share.css';
	wp_enqueue_style(
		'go-verge-overdrive-v11-rpm-share',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v9-stability' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v11_rpm_share', 24000 );


/**
 * V12 structural recovery retired in 3.76.5. Single geometry is now owned by
 * verge.css instead of a viewport-specific override layer.
 */

/**
 * V13 visual parity layer. Keeps the 3.10.54 Auto Ads DOM intact while
 * restoring article geometry and archive/page visual consistency.
 */
function go_verge_enqueue_overdrive_v13_visual_autoads() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v13-visual-autoads.css';
	$deps    = array( 'go-verge-overdrive-v11-rpm-share' );
	wp_enqueue_style(
		'go-verge-overdrive-v13-visual-autoads',
		GO_VERGE_URI . $css_rel,
		$deps,
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v13_visual_autoads', 27000 );




/**
 * V14 final cascade fix: metadata rule, shared canvas, Games hub parity and
 * light-mode filter contrast. CSS only; Auto Ads DOM remains untouched.
 */
function go_verge_enqueue_overdrive_v14_cascade_fix() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v14-cascade-fix.css';
	wp_enqueue_style(
		'go-verge-overdrive-v14-cascade-fix',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v13-visual-autoads' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v14_cascade_fix', 28000 );

/**
 * V17 topic clusters: specific subject recirculation (Outer Banks, Meu Nome é
 * Farah, Metal Gear Solid, Netflix etc.) without creating terms automatically.
 */
require_once GO_VERGE_DIR . '/inc/topic-clusters-v17.php';
require_once GO_VERGE_DIR . '/inc/navigation-entity-v21.php';
require_once GO_VERGE_DIR . '/inc/promotions-v19.php';

/**
 * V15 shell background parity: historical shells were repainting the body
 * canvas and making hubs look flat while singles remained atmospheric.
 */
function go_verge_enqueue_overdrive_v15_shell_background() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v15-shell-background.css';
	wp_enqueue_style(
		'go-verge-overdrive-v15-shell-background',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v14-cascade-fix' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v15_shell_background', 29000 );

/**
 * V17 final UX layer: card hover contract, article heading scale, Auto Ads
 * presentation, buying-guide hierarchy, commerce and internal topic clusters.
 * CSS only for ad presentation; it never mutates Google's inserted DOM.
 */
function go_verge_enqueue_overdrive_v17_content_commerce_clusters() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v17-content-commerce-clusters.css';
	wp_enqueue_style(
		'go-verge-overdrive-v17-content-commerce-clusters',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v15-shell-background' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v17_content_commerce_clusters', 30000 );

/* V55+: the Auto Ads disclosure reconciler was removed. It observed
 * `.google-auto-placed` with a MutationObserver to label provider shells; the
 * theme no longer inspects or annotates provider markup at all. */


/**
 * V18 metadata clusters + canonical hover palette. Light cards use #421AFF,
 * dark cards use Electric Lime. Topic clusters live in card metadata.
 */
function go_verge_enqueue_overdrive_v18_meta_clusters_hover() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v18-meta-clusters-hover.css';
	wp_enqueue_style(
		'go-verge-overdrive-v18-meta-clusters-hover',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v17-content-commerce-clusters' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v18_meta_clusters_hover', 31000 );

/**
 * V19 final surface polish: one light/dark card-hover contract, four-card
 * buying-guide module and store-first Promotions layout. No Auto Ads changes.
 */
function go_verge_enqueue_overdrive_v19_surface_polish() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v19-surface-polish.css';
	wp_enqueue_style(
		'go-verge-overdrive-v19-surface-polish',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v18-meta-clusters-hover' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v19_surface_polish', 32000 );

/**
 * V20 games surfaces + Promotions navigation. This is presentation/navigation
 * only and deliberately does not touch Auto Ads or article DOM.
 */
function go_verge_enqueue_overdrive_v20_games_promotions() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v20-games-promotions.css';
	wp_enqueue_style(
		'go-verge-overdrive-v20-games-promotions',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v19-surface-polish' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v20_games_promotions', 33000 );



/**
 * 3.15.0 — no font-origin preconnects, because there is no font origin.
 *
 * Barlow Condensed and Source Sans 3 are served from this host now, so
 * fonts.googleapis.com and fonts.gstatic.com are two connections the document
 * no longer opens. That matters beyond the two handshakes: a preconnect is a
 * claim on the connection budget, and on a phone those two were competing with
 * the three AdSense origins and with the LCP image for the same early slots.
 *
 * This filter now only REMOVES what the theme used to add, including any hint
 * a plugin contributes for the same two hosts. AdSense origins are owned
 * centrally by inc/ads/assets.php.
 *
 * @param array<int|string,mixed> $urls          URLs/hint definitions.
 * @param string                  $relation_type Resource-hint relation.
 * @return array<int|string,mixed>
 */
function go_verge_overdrive_471_resource_hints( $urls, $relation_type ) {
	if ( 'preconnect' !== $relation_type && 'dns-prefetch' !== $relation_type ) {
		return $urls;
	}

	return array_values(
		array_filter(
			(array) $urls,
			static function ( $hint ) {
				$href = is_array( $hint ) ? (string) ( $hint['href'] ?? '' ) : (string) $hint;
				return false === strpos( $href, 'fonts.googleapis.com' )
					&& false === strpos( $href, 'fonts.gstatic.com' );
			}
		)
	);
}
add_filter( 'wp_resource_hints', 'go_verge_overdrive_471_resource_hints', 20, 2 );

/* The old one-row inline geometry conflicts with the new two-tier masthead. */


/** V21: topic hubs, fluid content navigation and canonical entity polish. */
function go_verge_enqueue_overdrive_v21_navigation_entity() {
    $rel = '/assets/css/overdrive-v21-navigation-entity.css';
    wp_enqueue_style( 'go-verge-overdrive-v21-navigation-entity', GO_VERGE_URI . $rel, array( 'go-verge-overdrive-v20-games-promotions' ), GO_VERGE_VERSION );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v21_navigation_entity', 34000 );

/**
 * V26 canonical interaction states + Assuntos UI.
 * Presentation only: never touches ad markup, slots, density or provider code.
 */
function go_verge_enqueue_overdrive_v26_interaction_subjects() {
	if ( is_admin() ) { return; }
	$css_rel = '/assets/css/overdrive-v26-interaction-subjects.css';
	wp_enqueue_style(
		'go-verge-overdrive-v26-interaction-subjects',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v21-navigation-entity' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v26_interaction_subjects', 35000 );

/**
 * V28 SEO/CWV/RPM performance guard.
 *
 * This layer is intentionally conservative: no ad unit, slot ID, placement,
 * density, Auto Ads setting or provider markup is changed. It only reduces
 * theme-side competition/repaint work around the ad stack.
 */
function go_verge_enqueue_overdrive_v28_performance() {
	if ( is_admin() ) {
		return;
	}
	$css_rel = '/assets/css/overdrive-v28-performance.css';
	wp_enqueue_style(
		'go-verge-overdrive-v28-performance',
		GO_VERGE_URI . $css_rel,
		array( 'go-verge-overdrive-v26-interaction-subjects' ),
		go_verge_asset_version( $css_rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v28_performance', 36000 );

/* The v34 single-game cascade was retired in 3.81.36. Both game surfaces
 * now use the scoped games-surfaces.css and native editorial markup. */

/**
 * Scripts introduced by late visual layers are registered after the older
 * strategy passes (1800/10090). Mark them only after they actually exist.
 * WordPress preserves dependency order when applying the defer strategy.
 */
function go_verge_v28_defer_late_theme_scripts() {
	if ( is_admin() ) {
		return;
	}
	foreach ( array( 'go-verge-overdrive-471-parity', 'go-verge-overdrive-v8-hotfix' ) as $handle ) {
		if ( wp_script_is( $handle, 'enqueued' ) ) {
			wp_script_add_data( $handle, 'strategy', 'defer' );
		}
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_v28_defer_late_theme_scripts', 36010 );


/** V40: compact entity/topic hero and clearer canonical article subjects. */
function go_verge_enqueue_overdrive_v40_topic_hero() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v40-topic-hero.min.css';
	wp_enqueue_style(
		'go-verge-overdrive-v40-topic-hero',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v26-interaction-subjects' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v40_topic_hero', 39000 );

/** V41: smarter article subject priority + useful related topic chips. */
function go_verge_enqueue_overdrive_v41_smart_subjects() {
	if ( is_admin() || ! is_singular( 'post' ) ) { return; }
	$rel = '/assets/css/overdrive-v41-smart-subjects.min.css';
	wp_enqueue_style(
		'go-verge-overdrive-v41-smart-subjects',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v40-topic-hero' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v41_smart_subjects', 39100 );

/** V45: unified subject hubs, named follows and first-class pagination. */
require_once GO_VERGE_DIR . '/inc/subject-hubs-v45.php';
require_once GO_VERGE_DIR . '/inc/subject-entity-clusters-v72.php';
/** V46: authority graph, contextual internal links, knowledge clusters and visible author trust. */
require_once GO_VERGE_DIR . '/inc/authority-knowledge-v46.php';
/** V47: canonical subject identity, global follower analytics and clean service heroes. */
require_once GO_VERGE_DIR . '/inc/unified-subjects-followers-v47.php';
/** V48: Turkish-channel routing + cited first-class subjects in lists/rankings. */
require_once GO_VERGE_DIR . '/inc/turkish-channel-list-ranking-v48.php';

function go_verge_enqueue_overdrive_v47_clean_subjects() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v47-clean-subjects.min.css';
	wp_enqueue_style(
		'go-verge-overdrive-v47-clean-subjects',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v40-topic-hero' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v47_clean_subjects', 39200 );

/**
 * V50: photo-overlay headlines stay Electric Lime in every theme and the
 * revenue-recovery ad inventory/density changes remain PHP-owned in inc/ads.
 */
function go_verge_enqueue_overdrive_v50_rpm_lime() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v50-rpm-lime.css';
	wp_enqueue_style(
		'go-verge-overdrive-v50-rpm-lime',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v47-clean-subjects' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v50_rpm_lime', 39300 );


/**
 * V58: canonical hover palette + desktop auction readiness.
 * Presentation only, except the sidebar unit sizing declared in inc/ads/config.php.
 */
function go_verge_enqueue_overdrive_v58_hover_desktop_ads() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v58-hover-desktop-ads.css';
	wp_enqueue_style(
		'go-verge-overdrive-v58-hover-desktop-ads',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v50-rpm-lime' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v58_hover_desktop_ads', 39400 );

/**
 * V60 canonical theme accent: light uses Overdrive Blue, dark uses Electric
 * Lime, and text physically over photography stays Lime in both themes.
 */
function go_verge_enqueue_overdrive_v60_accent_hover() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v60-accent-hover.css';
	wp_enqueue_style(
		'go-verge-overdrive-v60-accent-hover',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v58-hover-desktop-ads' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v60_accent_hover', 39450 );


/**
 * V65: cache-safe session revenue intelligence. Recommendations are ranked in
 * the browser so LiteSpeed/CDN cache variants are never split by session. It
 * learns per-browser A→B affinity, adapts discovery across successive pageviews
 * and exposes impression/click events to the existing dataLayer.
 */
function go_verge_enqueue_overdrive_v65_revenue_intelligence() {
	if ( is_admin() || ! is_singular( 'post' ) ) { return; }
	$css = '/assets/css/overdrive-v65-revenue-intelligence.css';
	$js  = '/assets/js/go-revenue-intelligence-v65.min.js';
	wp_enqueue_style(
		'go-verge-overdrive-v65-revenue-intelligence',
		GO_VERGE_URI . $css,
		array( 'go-verge-overdrive-v60-accent-hover' ),
		go_verge_asset_version( $css )
	);
	wp_enqueue_script(
		'go-verge-overdrive-v65-revenue-intelligence',
		GO_VERGE_URI . $js,
		array(),
		go_verge_asset_version( $js ),
		true
	);
	wp_script_add_data( 'go-verge-overdrive-v65-revenue-intelligence', 'strategy', 'defer' );
	$post_id = absint( get_queried_object_id() );
	wp_localize_script(
		'go-verge-overdrive-v65-revenue-intelligence',
		'GORevenueIntelligence',
		array(
			'postId'   => $post_id,
			'vertical' => function_exists( 'go_verge_post_editorial_context' ) ? sanitize_key( (string) go_verge_post_editorial_context( $post_id ) ) : '',
			/* Current Slickstream guidance (2026) recommends disabling its floating
			 * Filmstrip Toolbar after performance analysis. Keep our reversal surface
			 * implemented as an experiment, but OFF by default; the behavioral signal
			 * and recommendation ranking stay active. */
			'scrollReversalEnabled' => (bool) apply_filters( 'go_verge_scroll_reversal_reco_enabled', false ),
		)
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v65_revenue_intelligence', 39495 );

/**
 * V66: evidence-driven RPM recovery + visual contract fixes. Loaded after the
 * recommendation/session layer so it can correct legacy feature-card accent
 * selectors and the homepage Promoções composition without reopening older CSS.
 */
function go_verge_enqueue_overdrive_v66_rpm_recovery() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v66-rpm-recovery.css';
	wp_enqueue_style(
		'go-verge-overdrive-v66-rpm-recovery',
		GO_VERGE_URI . $rel,
		array( is_singular( 'post' ) ? 'go-verge-overdrive-v65-revenue-intelligence' : 'go-verge-overdrive-v60-accent-hover' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v66_rpm_recovery', 39498 );

/**
 * V67: atomic recirculation repair + revenue-core In-article presentation.
 * Loaded after V66 so stale compatibility layers cannot squeeze Related cards.
 */
function go_verge_enqueue_overdrive_v67_core_auction_recirculation() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v67-core-auction-recirculation.css';
	wp_enqueue_style(
		'go-verge-overdrive-v67-core-auction-recirculation',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v66-rpm-recovery' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v67_core_auction_recirculation', 39499 );

/**
 * Accessibility baseline, last in the cascade.
 *
 * See assets/css/a11y-focus.css — it exists specifically to be the final layer,
 * so it is enqueued after every visual layer and folded into the same bundle.
 *
 * @return void
 */
function go_verge_enqueue_a11y_focus() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/a11y-focus.css';
	wp_enqueue_style(
		'go-verge-a11y-focus',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v66-rpm-recovery' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_a11y_focus', 39500 );

/**
 * 3.14.1: final responsive/CWV rendering layer.
 * Kept separate so it can be removed independently from the revenue stack.
 */
function go_verge_enqueue_overdrive_v68_performance_cwv() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/overdrive-v68-performance-cwv.css';
	wp_enqueue_style(
		'go-verge-overdrive-v68-performance-cwv',
		GO_VERGE_URI . $rel,
		array( 'go-verge-a11y-focus' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v68_performance_cwv', 39510 );

/**
 * 3.14.2: deterministic brand paint + canonical homepage hero headline.
 * Loaded after the performance layer so historical accent/logo rules cannot
 * reintroduce a flash, wrong logo variant or lime lead headline.
 */
function go_verge_enqueue_overdrive_v69_brand_hero_polish() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/overdrive-v69-brand-hero-polish.css';
	wp_enqueue_style(
		'go-verge-overdrive-v69-brand-hero-polish',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v68-performance-cwv' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v69_brand_hero_polish', 39520 );

/**
 * 3.15.0 — layout containment and paint stability, last in the cascade.
 *
 * Kept as its own final layer for the same reason every other late layer
 * exists: it must be able to contain an overflow introduced by any sheet above
 * it. Unlike those layers it carries no design decisions, so it is safe to load
 * everywhere and cheap to remove if it ever needs to be bisected.
 *
 * @return void
 */
function go_verge_enqueue_overdrive_v70_stability() {
	if ( is_admin() ) {
		return;
	}
	$rel = '/assets/css/overdrive-v70-stability.css';
	if ( ! file_exists( GO_VERGE_DIR . $rel ) ) {
		return;
	}
	wp_enqueue_style(
		'go-verge-overdrive-v70-stability',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v69-brand-hero-polish' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v70_stability', 39530 );




/**
 * 3.15.9 — homepage guide-rail alignment. Presentation only; auction timing is
 * configured centrally in inc/ads/config.php so visual CSS never owns revenue.
 */
function go_verge_enqueue_overdrive_v71_home_guides_auction_polish() {
	/* Every selector in this sheet is scoped to body.home. Do not make article,
	 * category or search bundles carry homepage-only bytes. */
	if ( is_admin() || ! is_front_page() ) {
		return;
	}
	$rel = '/assets/css/overdrive-v71-home-guides-auction-polish.css';
	wp_enqueue_style(
		'go-verge-overdrive-v71-home-guides-auction-polish',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v70-stability' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v71_home_guides_auction_polish', 39540 );



/** 3.44.3: final editorial/commerce interaction refinements. */
function go_verge_enqueue_overdrive_v73_editorial_refinements() {
	if ( is_admin() ) { return; }
	$rel  = '/assets/css/overdrive-v73-editorial-refinements.css';
	$deps = is_front_page()
		? array( 'go-verge-overdrive-v71-home-guides-auction-polish' )
		: array( 'go-verge-overdrive-v70-stability' );
	wp_enqueue_style(
		'go-verge-overdrive-v73-editorial-refinements',
		GO_VERGE_URI . $rel,
		$deps,
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v73_editorial_refinements', 39570 );

/** 3.44.4: final light-mode contrast guard for interactive controls. */
function go_verge_enqueue_overdrive_v74_contrast_guard() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v74-contrast-empty-ads.css';
	wp_enqueue_style(
		'go-verge-overdrive-v74-contrast-guard',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v73-editorial-refinements' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v74_contrast_guard', 39580 );

/** 3.50.1: final homepage Promoções color contract. */
function go_verge_enqueue_overdrive_v75_home_promo_final() {
	if ( is_admin() || ! is_front_page() ) { return; }
	$rel = '/assets/css/overdrive-v75-home-promo-final.css';
	wp_enqueue_style(
		'go-verge-overdrive-v75-home-promo-final',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v74-contrast-guard' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v75_home_promo_final', 39590 );

/** 3.50.2: hero review contrast + light-mode content hover contract. */
function go_verge_enqueue_overdrive_v76_ui_clarity() {
	if ( is_admin() ) { return; }
	$rel  = '/assets/css/overdrive-v76-ui-clarity.css';
	$deps = is_front_page()
		? array( 'go-verge-overdrive-v75-home-promo-final' )
		: array( 'go-verge-overdrive-v74-contrast-guard' );
	wp_enqueue_style(
		'go-verge-overdrive-v76-ui-clarity',
		GO_VERGE_URI . $rel,
		$deps,
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v76_ui_clarity', 39600 );

/** 3.55.2: aligned article metadata + canonical theme interaction accents + dateline spacing. */
function go_verge_enqueue_overdrive_v77_theme_interactions() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v77-theme-interactions.css';
	wp_enqueue_style(
		'go-verge-overdrive-v77-theme-interactions',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v76-ui-clarity' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v77_theme_interactions', 39610 );

/* 3.76.5: V79 mobile Auto Ads recovery sheet retired. It was an override stack;
 * provider-safe geometry now comes from the canonical article/base styles. */

require_once GO_VERGE_DIR . '/inc/post-views-fast.php';
require_once GO_VERGE_DIR . '/inc/release-375.php';

require_once GO_VERGE_DIR . '/inc/brand-multicolor.php';

/** Publisher shell; isolated classes avoid historical header cascade conflicts. */
function go_verge_enqueue_publisher_design() {
    if ( is_admin() ) { return; }
    $shell = '/assets/css/publisher-shell.css';
    wp_enqueue_style( 'go-verge-publisher-shell', GO_VERGE_URI . $shell, array( 'go-verge-overdrive-v77-theme-interactions' ), go_verge_asset_version( $shell ) );
    if ( is_front_page() ) {
        $home = '/assets/css/editorial-home.css';
        wp_enqueue_style( 'go-verge-editorial-home', GO_VERGE_URI . $home, array( 'go-verge-publisher-shell' ), go_verge_asset_version( $home ) );
    }
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_publisher_design', 39730 );

/** Shared presentation for editorial indexes, never individual stories. */
function go_verge_is_editorial_index() {
    if ( is_front_page() || is_singular( array( 'post', 'game', 'jogo', 'production' ) ) ) { return false; }
    return is_archive() || is_search() || is_home()
        || ( function_exists( 'go_verge_v21_is_topic_hub' ) && go_verge_v21_is_topic_hub() )
        || is_page( array( 'ultimas', 'ultimas-publicacoes', 'games', 'tecnologia', 'entretenimento', 'reviews', 'criticas', 'guias', 'dicas-e-guias', 'listas', 'rankings', 'listas-e-rankings', 'ofertas', 'guias-de-compra', 'busca' ) )
        || is_page_template( array( 'page-template/template-latest.php', 'page-template/template-archive-1.php', 'page-template/template-archive-2.php', 'page-template/template-archive-3.php', 'page-template/template-archive-4.php', 'page-template/template-archive-5.php', 'page-template/template-archive-6.php' ) );
}
add_filter( 'body_class', function ( $classes ) {
    if ( go_verge_is_editorial_index() ) { $classes[] = 'od-listing-page'; }
    return $classes;
} );
add_action( 'wp_enqueue_scripts', function () {
    if ( is_admin() || ! go_verge_is_editorial_index() ) { return; }
    $rel = '/assets/css/editorial-index.css';
    wp_enqueue_style( 'go-verge-editorial-index', GO_VERGE_URI . $rel, array( 'go-verge-publisher-shell', 'go-verge-multicolor' ), go_verge_asset_version( $rel ) );
}, 47000 );

/** Final shared card presentation, after both brand and index styles. */
add_action( 'wp_enqueue_scripts', function () {
    if ( is_admin() ) { return; }
    $deps = array( 'go-verge-publisher-shell', 'go-verge-multicolor' );
    if ( go_verge_is_editorial_index() ) { $deps[] = 'go-verge-editorial-index'; }
    if ( is_front_page() ) { $deps[] = 'go-verge-editorial-home'; }
    $rel = '/assets/css/editorial-cards.css';
    wp_enqueue_style( 'go-verge-editorial-cards', GO_VERGE_URI . $rel, $deps, go_verge_asset_version( $rel ) );
}, 48000 );

/** Shared editorial navigation and restrained site dividers. */
require_once GO_VERGE_DIR . '/inc/publisher-navigation.php';
require_once GO_VERGE_DIR . '/inc/editorial-desk-formats.php';
function go_verge_enqueue_publisher_navigation() {
    if ( is_admin() ) { return; }
    $rel = '/assets/css/publisher-navigation.css';
    wp_enqueue_style( 'go-verge-publisher-navigation', GO_VERGE_URI . $rel, array( 'go-verge-editorial-cards' ), go_verge_asset_version( $rel ) );
    if ( is_page() ) {
        $rel = '/assets/css/institutional-pages.css';
        wp_enqueue_style( 'go-verge-institutional-pages', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
    }
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_publisher_navigation', 48100 );

/** Author and platform pages share the editorial type and spacing scale. */
function go_verge_enqueue_editorial_profiles() {
    if ( is_admin() || ! ( is_author() || is_page( 'autores' ) || is_tax( 'go_platform' ) ) ) { return; }
    $rel = '/assets/css/editorial-profiles.css';
    wp_enqueue_style( 'go-verge-editorial-profiles', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_editorial_profiles', 48200 );

/** 3.81.6 final editorial polish: reading UI, review hover and theme parity. */
function go_verge_enqueue_editorial_final_3816() {
    if ( is_admin() ) { return; }
    $rel = '/assets/css/editorial-final-3816.css';
    wp_enqueue_style(
        'go-verge-editorial-final-3816',
        GO_VERGE_URI . $rel,
        array( 'go-verge-publisher-navigation' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_editorial_final_3816', 49000 );

/** 3.81.10 — final single opening and stable primary action group. */
function go_verge_enqueue_article_opening_actions_38110() {
    if ( is_admin() || ! is_singular( 'post' ) ) { return; }
    $rel = '/assets/css/article-opening-actions.css';
    wp_enqueue_style(
        'go-verge-article-opening-actions-38110',
        GO_VERGE_URI . $rel,
        array( 'go-verge-editorial-final-3816' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_article_opening_actions_38110', 49100 );



/** 3.81.17 — safer hero crops + CWV-oriented below-the-fold containment. */
function go_verge_enqueue_cwv_hero_38117() {
    if ( is_admin() || ! is_singular( 'post' ) ) { return; }
    /* Depends on the review reading layer; without it WordPress dropped this
     * sheet anyway while logging a notice on every standard article. */
    if ( ! wp_style_is( 'go-verge-review-reading', 'registered' ) ) { return; }
    $rel = '/assets/css/cwv-hero-3817.css';
    wp_enqueue_style(
        'go-verge-cwv-hero-38117',
        GO_VERGE_URI . $rel,
        array( 'go-verge-article-opening-actions-38110', 'go-verge-review-reading' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_cwv_hero_38117', 49200 );


/** 3.81.18 — review masthead hover neutralization + cleaner pros/cons cards. */
function go_verge_enqueue_review_ui_38118() {
    if ( is_admin() || ! is_singular( 'post' ) || ! wp_style_is( 'go-verge-cwv-hero-38117', 'registered' ) ) { return; }
    $rel = '/assets/css/review-ui-3818.css';
    wp_enqueue_style(
        'go-verge-review-ui-38118',
        GO_VERGE_URI . $rel,
        array( 'go-verge-cwv-hero-38117' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_review_ui_38118', 49300 );


/** 3.81.20 — ad/Discover recovery hardening. */
require_once GO_VERGE_DIR . '/inc/discover-recovery-38120.php';


/** 3.81.22 — accessibility popup positioning/design and offcanvas polish. */
function go_verge_enqueue_a11y_popup_38122() {
    if ( is_admin() ) { return; }
    $rel = '/assets/css/accessibility-popup-38122.css';
    wp_enqueue_style( 'go-verge-a11y-popup-38122', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_a11y_popup_38122', 49500 );


/** 3.81.23 — preferred-source popup refinement + review section rhythm. */
function go_verge_enqueue_preferred_review_38123() {
    if ( is_admin() ) { return; }
    $rel = '/assets/css/preferred-review-38123.css';
    wp_enqueue_style(
        'go-verge-preferred-review-38123',
        GO_VERGE_URI . $rel,
        array( 'go-verge-a11y-popup-38122' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_preferred_review_38123', 49500 );


/** 3.81.24 — stronger spacing between pros/cons and ficha técnica. */
function go_verge_enqueue_review_spacing_38124() {
    if ( is_admin() || ! is_singular( 'post' ) ) { return; }
    $rel = '/assets/css/review-spacing-38124.css';
    wp_enqueue_style(
        'go-verge-review-spacing-38124',
        GO_VERGE_URI . $rel,
        array( 'go-verge-preferred-review-38123' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_review_spacing_38124', 49600 );


/** 3.81.25 — platform/nav/admin/load-more cleanup. */
require_once GO_VERGE_DIR . '/inc/release-38125.php';
function go_verge_enqueue_release_38125() {
    if ( is_admin() ) { return; }
    $rel = '/assets/css/release-38125.css';
    wp_enqueue_style( 'go-verge-release-38125', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_release_38125', 49700 );

require_once GO_VERGE_DIR . '/inc/release-38126.php';
function go_verge_enqueue_release_38126() {
    $rel = '/assets/css/release-38126.css';
    wp_enqueue_style( 'go-verge-release-38126', GO_VERGE_URI . $rel, array( 'go-verge-release-38125' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_release_38126', 49710 );

require_once GO_VERGE_DIR . '/inc/release-38127.php';

/** 3.81.28 — compact commerce cards in article content. */
function go_verge_enqueue_article_commerce_38128() {
    if ( is_admin() || ! is_singular( 'post' ) ) { return; }
    $rel = '/assets/css/article-commerce-38128.css';
    wp_enqueue_style(
        'go-verge-article-commerce-38128',
        GO_VERGE_URI . $rel,
        array( 'go-verge-release-38126' ),
        go_verge_asset_version( $rel )
    );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_article_commerce_38128', 49720 );


/** 3.81.35 — Compare CTA copy/design hotfix. */
require_once GO_VERGE_DIR . '/inc/release-38135.php';
function go_verge_enqueue_compare_cta_38135() {
    if ( is_admin() || ! is_singular( 'post' ) ) { return; }
    $css = '/assets/css/compare-cta-38135.css';
    $js  = '/assets/js/compare-cta-38135.js';
    wp_enqueue_style(
        'go-verge-compare-cta-38135',
        GO_VERGE_URI . $css,
        array( 'go-verge-article-commerce-38128' ),
        go_verge_asset_version( $css )
    );
    wp_enqueue_script(
        'go-verge-compare-cta-38135',
        GO_VERGE_URI . $js,
        array(),
        go_verge_asset_version( $js ),
        true
    );
    wp_script_add_data( 'go-verge-compare-cta-38135', 'strategy', 'defer' );
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_compare_cta_38135', 49730 );


/** 3.81.36 — rebuilt game single and catalogue. */
require_once GO_VERGE_DIR . '/inc/games-presentation.php';

/** 3.81.40 — contextual buying guides, without changing the guide format. */
require_once GO_VERGE_DIR . '/inc/buying-guides-integration.php';


/**
 * Auto Ads keep Google's native disclosure.
 *
 * A previous implementation created a publisher-owned fixed overlay and
 * recalculated its coordinates on every scroll to show an extra
 * "Publicidade" pill above Auto Ads. Besides being redundant with Google's
 * own disclosure, that made the label visibly move while the reader scrolled.
 * Manual publisher slots still render their static disclosure through
 * inc/ads/renderer.php.
 */

// Existing categories, editorial relationships and redirects survive theme updates.
require_once GO_VERGE_DIR . '/inc/editorial-preservation.php';
