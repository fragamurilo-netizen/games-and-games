<?php
/**
 * Indexing intelligence: crawl hygiene + fast, policy-safe discovery signals.
 *
 * This module deliberately does NOT call Google's Indexing API for ordinary
 * editorial articles. Google limits that API to JobPosting and livestream
 * BroadcastEvent pages. Overdrive instead relies on canonical URLs, clean
 * sitemaps, crawlable internal links, RSS and WebSub discovery.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Kill switch for outbound WebSub notifications. */
function go_verge_indexing_websub_enabled() {
	if ( defined( 'GO_VERGE_WEBSUB_ENABLED' ) ) {
		return (bool) GO_VERGE_WEBSUB_ENABLED;
	}
	return (bool) apply_filters( 'go_verge/indexing/websub_enabled', true );
}

/** Public UI parameters that create filtered/list variants, not canonical landing pages. */
function go_verge_indexing_filter_query_args() {
	return (array) apply_filters(
		'go_verge/indexing/filter_query_args',
		array( 'franquia', 'plataforma', 'genero', 'subcategoria', 'editoria', 'tipo', 'jogo', 'tema' )
	);
}

/** Return query parameters currently acting as editorial/list filters. */
function go_verge_indexing_active_filter_query_args() {
	$active = array();
	foreach ( go_verge_indexing_filter_query_args() as $arg ) {
		if ( isset( $_GET[ $arg ] ) && is_scalar( $_GET[ $arg ] ) && '' !== trim( (string) wp_unslash( $_GET[ $arg ] ) ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			$active[] = sanitize_key( $arg );
		}
	}
	return array_values( array_unique( $active ) );
}

/**
 * Filtered discovery surfaces should remain crawlable for their links but not
 * become alternate Search landing pages. Singular editorial entities are
 * excluded because arbitrary query strings must not change their index policy.
 */
function go_verge_indexing_is_filtered_discovery_request() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || empty( go_verge_indexing_active_filter_query_args() ) ) {
		return false;
	}
	if ( is_singular( array( 'post', 'games', 'go_entity', 'productions', 'go_promotion' ) ) ) {
		return false;
	}
	return true;
}

/** Canonical URL for the current filtered page with UI query parameters removed. */
function go_verge_indexing_clean_filtered_canonical( $canonical ) {
	if ( ! go_verge_indexing_is_filtered_discovery_request() ) {
		return $canonical;
	}
	$args = go_verge_indexing_active_filter_query_args();
	if ( empty( $args ) ) {
		return $canonical;
	}

	$clean = remove_query_arg( $args, (string) $canonical );
	if ( '' === trim( $clean ) ) {
		$scheme = is_ssl() ? 'https://' : 'http://';
		$host   = isset( $_SERVER['HTTP_HOST'] ) ? sanitize_text_field( wp_unslash( $_SERVER['HTTP_HOST'] ) ) : wp_parse_url( home_url( '/' ), PHP_URL_HOST );
		$uri    = isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '/';
		$path   = (string) wp_parse_url( $uri, PHP_URL_PATH );
		$clean  = $scheme . $host . $path;
	}
	return esc_url_raw( $clean );
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_indexing_clean_filtered_canonical', 1500 );

/** Noindex filtered/sort/search variants while preserving link discovery. */
function go_verge_indexing_filtered_wp_robots( $robots ) {
	if ( go_verge_indexing_is_filtered_discovery_request() && is_array( $robots ) ) {
		$robots['noindex'] = true;
		if ( empty( $robots['nofollow'] ) && empty( $robots['none'] ) ) {
			$robots['follow'] = true;
		}
		unset( $robots['index'] );
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_indexing_filtered_wp_robots', 300 );

function go_verge_indexing_filtered_rank_math_robots( $robots ) {
	if ( go_verge_indexing_is_filtered_discovery_request() && is_array( $robots ) ) {
		$robots['index']  = 'noindex';
		if ( empty( $robots['nofollow'] ) && empty( $robots['none'] ) && ( ! isset( $robots['follow'] ) || ! in_array( strtolower( (string) $robots['follow'] ), array( 'nofollow', 'none' ), true ) ) ) {
			$robots['follow'] = 'follow';
		}
	}
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_indexing_filtered_rank_math_robots', 300 );

/**
 * A legacy ?franquia= variant of /games/ is inert in the current server-side
 * archive. Consolidate it with a permanent redirect instead of asking Google
 * to repeatedly crawl the same archive under arbitrary franchise values.
 */
function go_verge_indexing_redirect_inert_games_franchise_filter() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || ! is_post_type_archive( 'games' ) || ! isset( $_GET['franquia'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return;
	}
	$target = get_post_type_archive_link( 'games' );
	if ( ! $target ) {
		return;
	}
	/* Preserve analytics parameters, but never preserve the inert content filter. */
	$keep = array();
	foreach ( $_GET as $key => $value ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$key = sanitize_key( $key );
		if ( 'franquia' === $key || ! is_scalar( $value ) ) {
			continue;
		}
		if ( 0 === strpos( $key, 'utm_' ) || in_array( $key, array( 'gclid', 'fbclid' ), true ) ) {
			$keep[ $key ] = sanitize_text_field( wp_unslash( $value ) );
		}
	}
	if ( $keep ) {
		$target = add_query_arg( $keep, $target );
	}
	wp_safe_redirect( $target, 301, 'Overdrive inert game archive filter consolidation' );
	exit;
}
add_action( 'template_redirect', 'go_verge_indexing_redirect_inert_games_franchise_filter', -20 );

/** Official public WebSub hub used by default; filterable for future migration. */
function go_verge_indexing_websub_hub_url() {
	return esc_url_raw( (string) apply_filters( 'go_verge/indexing/websub_hub', 'https://pubsubhubbub.appspot.com/' ) );
}

/** True only for the site's primary RSS2 feed, not author/category/tag feeds. */
function go_verge_indexing_is_main_rss2_feed() {
	return is_feed( 'rss2' ) && ! is_archive() && ! is_search() && ! is_singular();
}

/** Advertise the WebSub hub. WordPress already prints the RSS2 rel=self link. */
function go_verge_indexing_websub_rss2_links() {
	if ( ! go_verge_indexing_websub_enabled() || ! go_verge_indexing_is_main_rss2_feed() ) {
		return;
	}
	$hub = go_verge_indexing_websub_hub_url();
	if ( ! $hub ) {
		return;
	}
	echo '<atom:link rel="hub" href="' . esc_url( $hub ) . '" />' . "\n"; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
}
add_action( 'rss2_head', 'go_verge_indexing_websub_rss2_links', 1 );

/** Prevent an edge cache from giving the WebSub hub a stale primary feed. */
function go_verge_indexing_websub_feed_headers() {
	if ( ! go_verge_indexing_websub_enabled() || ! go_verge_indexing_is_main_rss2_feed() || headers_sent() ) {
		return;
	}
	$hub  = go_verge_indexing_websub_hub_url();
	$self = get_feed_link( 'rss2' );
	if ( $hub && $self ) {
		header( 'Link: <' . $hub . '>; rel="hub", <' . $self . '>; rel="self"', false );
	}
	header( 'Cache-Control: no-cache, max-age=0, must-revalidate', true );
	header( 'X-LiteSpeed-Cache-Control: no-cache', true );
}
add_action( 'send_headers', 'go_verge_indexing_websub_feed_headers', 120 );

/** Queue one debounced WebSub publish event without delaying the editor request. */
function go_verge_indexing_schedule_websub_publish() {
	if ( ! go_verge_indexing_websub_enabled() ) {
		return;
	}
	$feed = get_feed_link( 'rss2' );
	if ( ! $feed ) {
		return;
	}

	/*
	 * Keep the measured/retry worker in WP-Cron, but also queue one non-blocking
	 * publish notification for shutdown. Discovery must not wait for a delayed
	 * cron spawn after the editor presses Publish.
	 */
	if ( ! isset( $GLOBALS['go_verge_indexing_websub_shutdown_feeds'] ) || ! is_array( $GLOBALS['go_verge_indexing_websub_shutdown_feeds'] ) ) {
		$GLOBALS['go_verge_indexing_websub_shutdown_feeds'] = array();
	}
	$GLOBALS['go_verge_indexing_websub_shutdown_feeds'][ $feed ] = true;

	$key = 'go_websub_debounce_' . md5( $feed );
	if ( get_transient( $key ) ) {
		return;
	}
	set_transient( $key, 1, MINUTE_IN_SECONDS );
	if ( ! wp_next_scheduled( 'go_verge_indexing_websub_publish', array( $feed ) ) ) {
		wp_schedule_single_event( time() + 5, 'go_verge_indexing_websub_publish', array( $feed ) );
	}
}

/** New publication = immediate discovery signal. */
function go_verge_indexing_websub_on_transition( $new_status, $old_status, $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	if ( 'publish' === $new_status && 'publish' !== $old_status ) {
		go_verge_indexing_schedule_websub_publish();
	}
}
add_action( 'transition_post_status', 'go_verge_indexing_websub_on_transition', 30, 3 );

/** Significant editorial update = fresh feed signal, not every metadata save. */
function go_verge_indexing_websub_on_post_updated( $post_id, $post_after, $post_before ) {
	unset( $post_id );
	if ( ! ( $post_after instanceof WP_Post ) || ! ( $post_before instanceof WP_Post ) || 'post' !== $post_after->post_type || 'publish' !== $post_after->post_status ) {
		return;
	}
	$changed = $post_after->post_title !== $post_before->post_title ||
		$post_after->post_content !== $post_before->post_content ||
		$post_after->post_excerpt !== $post_before->post_excerpt;
	if ( $changed ) {
		go_verge_indexing_schedule_websub_publish();
	}
}
add_action( 'post_updated', 'go_verge_indexing_websub_on_post_updated', 30, 3 );


/**
 * Purge only the public discovery surfaces that can expose a newly published
 * or materially updated article. This keeps LiteSpeed from serving a cached
 * homepage/category/feed that does not yet link to the fresh URL.
 */
function go_verge_indexing_purge_publication_surfaces( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || 'publish' !== get_post_status( $post_id ) ) {
		return;
	}

	static $purged = array();
	if ( isset( $purged[ $post_id ] ) ) {
		return;
	}
	$purged[ $post_id ] = true;

	$urls = array(
		home_url( '/' ),
		get_permalink( $post_id ),
		get_feed_link( 'rss2' ),
		home_url( '/sitemap.xml' ),
		home_url( '/sitemap-fresh.xml' ),
		home_url( '/news-sitemap.xml' ),
	);

	if ( function_exists( 'go_verge_latest_url' ) ) {
		$urls[] = go_verge_latest_url();
	}
	if ( function_exists( 'go_verge_newsroom_url' ) ) {
		$urls[] = go_verge_newsroom_url();
	}

	foreach ( (array) wp_get_post_categories( $post_id ) as $term_id ) {
		$link = get_category_link( (int) $term_id );
		if ( ! is_wp_error( $link ) ) {
			$urls[] = $link;
		}
	}

	/* Official LiteSpeed Cache purge hooks are harmless when LSCWP is absent. */
	do_action( 'litespeed_purge_post', $post_id );
	foreach ( array_values( array_unique( array_filter( array_map( 'esc_url_raw', $urls ) ) ) ) as $url ) {
		do_action( 'litespeed_purge_url', $url );
	}

	update_option(
		'go_verge_indexing_last_surface_purge',
		array(
			'post_id' => $post_id,
			'time'    => time(),
			'urls'    => count( array_filter( $urls ) ),
		),
		false
	);
}

/** Purge discovery surfaces immediately after a first publication. */
function go_verge_indexing_purge_on_transition( $new_status, $old_status, $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	if ( 'publish' === $new_status && 'publish' !== $old_status ) {
		go_verge_indexing_purge_publication_surfaces( $post->ID );
	}
}
add_action( 'transition_post_status', 'go_verge_indexing_purge_on_transition', 85, 3 );

/** Purge discovery surfaces after a material editorial update. */
function go_verge_indexing_purge_on_post_updated( $post_id, $post_after, $post_before ) {
	if ( ! ( $post_after instanceof WP_Post ) || ! ( $post_before instanceof WP_Post ) || 'post' !== $post_after->post_type || 'publish' !== $post_after->post_status ) {
		return;
	}
	$changed = $post_after->post_title !== $post_before->post_title
		|| $post_after->post_content !== $post_before->post_content
		|| $post_after->post_excerpt !== $post_before->post_excerpt;
	if ( $changed ) {
		go_verge_indexing_purge_publication_surfaces( $post_id );
	}
}
add_action( 'post_updated', 'go_verge_indexing_purge_on_post_updated', 85, 3 );

/**
 * Queue the authenticated Google discovery push after the article is fully saved.
 *
 * Lume owns the OAuth token and official Search Console Sitemap API. The theme
 * only asks that connector to wake immediately. This deliberately avoids the
 * restricted Google Indexing API, which is not intended for ordinary articles.
 */
function go_verge_indexing_queue_google_fast_push( $post_id, $reason = 'publish' ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) || 'publish' !== get_post_status( $post_id ) ) {
		return;
	}

	$GLOBALS['go_verge_google_fast_push_pending'] = array(
		'post_id'   => $post_id,
		'reason'    => sanitize_key( $reason ),
		'queued_at' => time(),
	);

	/* Fail-safe for Lume <= 6.30.2: ensure its existing sitemap worker has an
	 * event even if shutdown is interrupted. 6.30.3+ has its own equivalent. */
	if ( class_exists( 'GED_Search_Console' ) && method_exists( 'GED_Search_Console', 'connected' ) && GED_Search_Console::connected() && ! method_exists( 'GED_Search_Console', 'request_sitemap_push' ) ) {
		if ( ! wp_next_scheduled( 'ged_gsc_submit_sitemaps' ) ) {
			wp_schedule_single_event( time() + 15, 'ged_gsc_submit_sitemaps' );
		}
	}
}

/** First publication: put the final URL in Google's discovery queue. */
function go_verge_indexing_google_fast_push_on_transition( $new_status, $old_status, $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	if ( 'publish' === $new_status && 'publish' !== $old_status ) {
		go_verge_indexing_queue_google_fast_push( $post->ID, 'publish' );
	}
}
add_action( 'transition_post_status', 'go_verge_indexing_google_fast_push_on_transition', 96, 3 );

/** Material editorial update: refresh the same supported discovery signals. */
function go_verge_indexing_google_fast_push_on_post_updated( $post_id, $post_after, $post_before ) {
	if ( ! ( $post_after instanceof WP_Post ) || ! ( $post_before instanceof WP_Post ) || 'post' !== $post_after->post_type || 'publish' !== $post_after->post_status ) {
		return;
	}
	$changed = $post_after->post_title !== $post_before->post_title
		|| $post_after->post_content !== $post_before->post_content
		|| $post_after->post_excerpt !== $post_before->post_excerpt
		|| $post_after->post_name !== $post_before->post_name;
	if ( $changed ) {
		go_verge_indexing_queue_google_fast_push( $post_id, 'update' );
	}
}
add_action( 'post_updated', 'go_verge_indexing_google_fast_push_on_post_updated', 96, 3 );

/**
 * Wake the official Search Console sitemap submission immediately at shutdown.
 *
 * With Lume 6.30.3+ this uses its public contract. With 6.30.2 the compatibility
 * path moves the existing 60-second WP-Cron event to now and explicitly spawns
 * cron, so a quiet newsroom does not have to wait for the next visitor.
 */
function go_verge_indexing_google_fast_push_shutdown() {
	$pending = isset( $GLOBALS['go_verge_google_fast_push_pending'] ) && is_array( $GLOBALS['go_verge_google_fast_push_pending'] )
		? $GLOBALS['go_verge_google_fast_push_pending']
		: array();
	if ( empty( $pending['post_id'] ) ) {
		return;
	}

	$status = array(
		'time'      => time(),
		'post_id'   => absint( $pending['post_id'] ),
		'reason'    => sanitize_key( $pending['reason'] ?? 'publish' ),
		'connected' => false,
		'mode'      => 'local-only',
		'awakened'  => false,
	);

	if ( ! class_exists( 'GED_Search_Console' ) || ! method_exists( 'GED_Search_Console', 'connected' ) || ! GED_Search_Console::connected() ) {
		update_option( 'go_verge_google_fast_push_last_request', $status, false );
		return;
	}
	$status['connected'] = true;

	if ( method_exists( 'GED_Search_Console', 'request_sitemap_push' ) ) {
		$status['mode']     = 'lume-contract';
		$status['awakened'] = (bool) GED_Search_Console::request_sitemap_push( $status['post_id'], $status['reason'] );
		update_option( 'go_verge_google_fast_push_last_request', $status, false );
		return;
	}

	/* Compatibility with Lume 6.30.2. Its worker already uses the authenticated
	 * Search Console Sitemap API; we only remove the avoidable scheduling delay. */
	$now  = time();
	$next = wp_next_scheduled( 'ged_gsc_submit_sitemaps' );
	if ( $next && $next > $now + 2 ) {
		wp_unschedule_event( $next, 'ged_gsc_submit_sitemaps' );
		$next = false;
	}
	if ( ! $next ) {
		wp_schedule_single_event( $now, 'ged_gsc_submit_sitemaps' );
	}
	if ( ! wp_doing_cron() && function_exists( 'spawn_cron' ) ) {
		spawn_cron( $now );
	}
	$status['mode']     = 'legacy-cron-wake';
	$status['awakened'] = true;
	update_option( 'go_verge_google_fast_push_last_request', $status, false );
}
add_action( 'shutdown', 'go_verge_indexing_google_fast_push_shutdown', 45 );

/**
 * Fire one best-effort WebSub request at shutdown. The normal cron worker still
 * records status and retries, so this fast path never hides delivery failures.
 */
function go_verge_indexing_websub_shutdown_publish() {
	if ( ! go_verge_indexing_websub_enabled() || empty( $GLOBALS['go_verge_indexing_websub_shutdown_feeds'] ) ) {
		return;
	}
	$hub = go_verge_indexing_websub_hub_url();
	if ( ! $hub ) {
		return;
	}
	foreach ( array_keys( (array) $GLOBALS['go_verge_indexing_websub_shutdown_feeds'] ) as $feed_url ) {
		if ( ! wp_http_validate_url( $feed_url ) ) {
			continue;
		}
		wp_remote_post(
			$hub,
			array(
				'timeout'     => 1,
				'redirection' => 0,
				'blocking'    => false,
				'headers'     => array( 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8' ),
				'body'        => array(
					'hub.mode' => 'publish',
					'hub.url'  => esc_url_raw( $feed_url ),
				),
				'user-agent'  => 'Overdrive-WebSub/' . GO_VERGE_VERSION . '; ' . home_url( '/' ),
			)
		);
	}
}
add_action( 'shutdown', 'go_verge_indexing_websub_shutdown_publish', 20 );

/** Perform the WebSub notification in WP-Cron. */
function go_verge_indexing_websub_publish_worker( $feed_url ) {
	if ( ! go_verge_indexing_websub_enabled() ) {
		return;
	}
	$hub = go_verge_indexing_websub_hub_url();
	if ( ! $hub || ! wp_http_validate_url( $feed_url ) ) {
		return;
	}
	$response = wp_remote_post(
		$hub,
		array(
			'timeout'     => 5,
			'redirection' => 2,
			'blocking'    => true,
			'headers'     => array( 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8' ),
			'body'        => array(
				'hub.mode' => 'publish',
				'hub.url'  => esc_url_raw( $feed_url ),
			),
			'user-agent'  => 'Overdrive-WebSub/' . GO_VERGE_VERSION . '; ' . home_url( '/' ),
		)
	);

	$status = is_wp_error( $response ) ? 0 : (int) wp_remote_retrieve_response_code( $response );
	$success  = $status >= 200 && $status < 300;
	$previous = get_option( 'go_verge_websub_last_result', array() );
	$attempt  = 0;
	$next     = 0;
	if ( ! $success ) {
		$previous_status = absint( $previous['status'] ?? 0 );
		$recent_failure  = ! empty( $previous['time'] )
			&& absint( $previous['time'] ) >= time() - HOUR_IN_SECONDS
			&& ! ( $previous_status >= 200 && $previous_status < 300 );
		$attempt = $recent_failure ? min( 3, absint( $previous['attempt'] ?? 0 ) + 1 ) : 1;
		if ( $attempt < 3 ) {
			$next = time() + ( 5 * MINUTE_IN_SECONDS * ( 2 ** ( $attempt - 1 ) ) );
			if ( ! wp_next_scheduled( 'go_verge_indexing_websub_publish', array( $feed_url ) ) ) {
				wp_schedule_single_event( $next, 'go_verge_indexing_websub_publish', array( $feed_url ) );
			}
		}
	}
	update_option(
		'go_verge_websub_last_result',
		array(
			'time'   => time(),
			'status' => $status,
			'error'  => is_wp_error( $response ) ? sanitize_text_field( $response->get_error_message() ) : '',
			'attempt'=> $attempt,
			'next_retry' => $next,
			'last_success' => $success ? time() : absint( $previous['last_success'] ?? 0 ),
		),
		false
	);
}
add_action( 'go_verge_indexing_websub_publish', 'go_verge_indexing_websub_publish_worker', 10, 1 );

/** Make indexing discovery health visible in Tools > Site Health. */
function go_verge_indexing_intelligence_health_tests( $tests ) {
	$tests['direct']['go_verge_indexing_discovery'] = array(
		'label' => __( 'Descoberta rápida e higiene de URLs', 'go-verge' ),
		'test'  => 'go_verge_indexing_intelligence_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_indexing_intelligence_health_tests' );

function go_verge_indexing_intelligence_health_test() {
	$last = get_option( 'go_verge_websub_last_result', array() );
	$websub = go_verge_indexing_websub_enabled();
	$ok = true;
	$tested = ! empty( $last['time'] );
	$detail = array( __( 'Filtros editoriais usam noindex/follow + canonical limpo.', 'go-verge' ) );
	if ( $websub ) {
		if ( $tested ) {
			$status = absint( $last['status'] ?? 0 );
			$ok = $status >= 200 && $status < 300;
			$detail[] = sprintf( __( 'Último WebSub: HTTP %1$d em %2$s.', 'go-verge' ), $status, wp_date( 'd/m/Y H:i', absint( $last['time'] ) ) );
			if ( ! $ok && ! empty( $last['error'] ) ) {
				$detail[] = sprintf( __( 'Erro: %s.', 'go-verge' ), sanitize_text_field( $last['error'] ) );
			}
			if ( ! $ok && ! empty( $last['next_retry'] ) ) {
				$detail[] = sprintf( __( 'Nova tentativa agendada para %s.', 'go-verge' ), wp_date( 'd/m/Y H:i', absint( $last['next_retry'] ) ) );
			}
		} else {
			$detail[] = __( 'WebSub está pronto e fará o primeiro envio na próxima publicação/atualização editorial.', 'go-verge' );
		}
	} else {
		$detail[] = __( 'WebSub está desativado pelo kill switch.', 'go-verge' );
	}

	$gsc_connected = class_exists( 'GED_Search_Console' )
		&& method_exists( 'GED_Search_Console', 'connected' )
		&& GED_Search_Console::connected();
	$gsc_ok = $gsc_connected;
	if ( $gsc_connected ) {
		$gsc_push = method_exists( 'GED_Search_Console', 'sitemap_push_status' )
			? GED_Search_Console::sitemap_push_status()
			: get_option( 'ged_gsc_sitemap_push_status', array() );
		if ( is_array( $gsc_push ) && ! empty( $gsc_push['time'] ) ) {
			$gsc_errors = isset( $gsc_push['errors'] ) && is_array( $gsc_push['errors'] ) ? $gsc_push['errors'] : array();
			$gsc_ok = empty( $gsc_errors );
			$detail[] = $gsc_ok
				? sprintf( __( 'Último envio autenticado ao Google: %1$d superfície(s) em %2$s.', 'go-verge' ), count( (array) ( $gsc_push['submitted'] ?? array() ) ), wp_date( 'd/m/Y H:i:s', absint( $gsc_push['time'] ) ) )
				: sprintf( __( 'O último envio autenticado ao Google teve %1$d erro(s) em %2$s.', 'go-verge' ), count( $gsc_errors ), wp_date( 'd/m/Y H:i:s', absint( $gsc_push['time'] ) ) );
			if ( ! $gsc_ok && ! empty( $gsc_push['next_retry'] ) ) {
				$detail[] = sprintf( __( 'Retry do Google agendado para %s.', 'go-verge' ), wp_date( 'd/m/Y H:i:s', absint( $gsc_push['next_retry'] ) ) );
			}
		} else {
			$last_request = get_option( 'go_verge_google_fast_push_last_request', array() );
			$detail[] = ! empty( $last_request['time'] )
				? sprintf( __( 'Search Console conectado; o worker rápido foi acordado em %s e aguarda o primeiro status persistido.', 'go-verge' ), wp_date( 'd/m/Y H:i:s', absint( $last_request['time'] ) ) )
				: __( 'Search Console conectado; o envio rápido será disparado na próxima publicação/atualização.', 'go-verge' );
		}
	} else {
		$detail[] = __( 'Search Console do Lume não está conectado; RSS/WebSub e sitemaps locais funcionam, mas o envio autenticado automático ao Google fica indisponível.', 'go-verge' );
	}
	$ok = $ok && $gsc_ok;

	$latest = get_posts(
		array(
			'post_type'      => 'post',
			'post_status'    => 'publish',
			'posts_per_page' => 1,
			'orderby'        => 'modified',
			'order'          => 'DESC',
			'fields'         => 'ids',
		)
	);
	if ( $latest && function_exists( 'go_verge_smart_sitemap_build_fresh' ) ) {
		$latest_url = get_permalink( (int) $latest[0] );
		$fresh_xml  = (string) go_verge_smart_sitemap_build_fresh();
		$fresh_ok   = $latest_url && false !== strpos( html_entity_decode( $fresh_xml, ENT_QUOTES | ENT_HTML5, 'UTF-8' ), $latest_url );
		$ok         = $ok && $fresh_ok;
		$detail[]   = $fresh_ok
			? __( 'A URL editorial mais recente já aparece no sitemap-fresh.xml local.', 'go-verge' )
			: __( 'A URL editorial mais recente não apareceu no sitemap-fresh.xml local.', 'go-verge' );
	}

	return array(
		'label'       => $ok && $tested ? __( 'Descoberta rápida está operacional', 'go-verge' ) : __( 'Revise os sinais de descoberta rápida', 'go-verge' ),
		'status'      => $ok && $tested ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Indexação', 'go-verge' ), 'color' => $ok ? 'blue' : 'orange' ),
		'description' => '<p>' . esc_html( implode( ' ', $detail ) ) . '</p>',
		'test'        => 'go_verge_indexing_discovery',
	);
}
