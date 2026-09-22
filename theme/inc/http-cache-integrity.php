<?php
/**
 * HTTP cache integrity for anonymous public documents.
 *
 * MEASURED PROBLEM (production, 01/09/2026)
 * -----------------------------------------
 * Every anonymous request to gameoverdrive.com.br answered with:
 *
 *     Set-Cookie: PHPSESSID=...; path=/; secure
 *     Expires: Thu, 19 Nov 1981 08:52:00 GMT
 *     Cache-Control: no-store, no-cache, must-revalidate
 *     Pragma: no-cache
 *
 * That triple is not WordPress. `nocache_headers()` emits
 * `Expires: Wed, 11 Jan 1984 05:00:00 GMT` and
 * `Cache-Control: no-cache, must-revalidate, max-age=0, no-store, private`.
 * The 1981 date is PHP's own `session.cache_limiter=nocache` default, sent by
 * the session module the moment `session_start()` runs. Something on the
 * front end starts a native PHP session on ordinary page views, and PHP then
 * stamps the whole document as uncacheable. The exact component must be proved
 * from the active plugin/MU-plugin stack rather than guessed from the cookie.
 *
 * What that cost, measured on production:
 *
 *   - `X-Litespeed-Cache: miss` on the home page and on /noticias/, with
 *     `x-hcdn-upstream-rt` of 1.13 s and 3.01 s respectively. The page cache
 *     was being bypassed and the origin re-rendered every request.
 *   - `x-hcdn-cache-status: MISS` on every URL tested. The CDN cannot store a
 *     `no-store` response, so the edge never served HTML.
 *   - `no-store` makes the document ineligible for the browser back/forward
 *     cache. Every "back" is a full navigation: new TTFB, new LCP, new INP.
 *
 * All three are Core Web Vitals costs paid on every pageview, and none of them
 * are visible in the newsroom.
 *
 * WHAT THIS MODULE DOES
 * ---------------------
 * Two independent defences, both scoped to anonymous public GET documents:
 *
 *  1. PREVENTION. At theme load — before `init`, and therefore before almost
 *     any plugin reaches its tracking hooks — `session_cache_limiter( '' )`
 *     tells PHP to send no cache headers when a session is eventually started.
 *     The session still works; it simply stops rewriting the document's cache
 *     policy. This is a no-op when a session is already active.
 *
 *  2. REPAIR. If a session started before the theme loaded (auto_start, an
 *     mu-plugin, a drop-in), the headers already exist. On `send_headers` and
 *     again on `template_redirect` the module removes the three headers *only
 *     when they still carry PHP's session signature*, so a deliberate
 *     WordPress `nocache_headers()` call is never overridden.
 *
 * The default outcome is exactly what a normal WordPress install sends for an
 * anonymous page: no cache directive of its own, leaving the decision to
 * LiteSpeed Cache and the host. Publishers who want the edge to store HTML can
 * opt in to a shared-cache policy — that is deliberately not the default,
 * because a CDN that stores HTML must also be purged on publish.
 *
 * ESCAPE HATCHES
 * --------------
 *   define( 'GO_VERGE_CACHE_INTEGRITY', false );          // disable entirely
 *   define( 'GO_VERGE_PUBLIC_HTML_SMAXAGE', 300 );        // opt in to s-maxage
 *   add_filter( 'go_verge_cache_integrity_enabled', '__return_false' );
 *   add_filter( 'go_verge_public_cache_control', fn( $v ) => 'public, max-age=0' );
 *   add_filter( 'go_verge_cache_integrity_drop_session_cookie', '__return_false' );
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** PHP's session cache limiter stamps this exact Expires value. */
const GO_VERGE_PHP_SESSION_EXPIRES = 'Thu, 19 Nov 1981 08:52:00 GMT';

/**
 * Whether this request is an anonymous, cacheable public document.
 *
 * Deliberately usable before `pluggable.php` exists: authentication is read
 * from the cookie jar rather than from `is_user_logged_in()`, the same way
 * every page-cache drop-in does it.
 *
 * @return bool
 */
function go_verge_is_anonymous_public_document() {
	if ( defined( 'GO_VERGE_CACHE_INTEGRITY' ) && ! GO_VERGE_CACHE_INTEGRITY ) {
		return false;
	}
	if ( ( defined( 'WP_CLI' ) && WP_CLI ) || ( defined( 'DOING_CRON' ) && DOING_CRON ) ) {
		return false;
	}
	if ( defined( 'REST_REQUEST' ) && REST_REQUEST ) {
		return false;
	}
	if ( defined( 'DOING_AJAX' ) && DOING_AJAX ) {
		return false;
	}
	if ( defined( 'XMLRPC_REQUEST' ) && XMLRPC_REQUEST ) {
		return false;
	}
	if ( defined( 'DONOTCACHEPAGE' ) && DONOTCACHEPAGE ) {
		return false;
	}
	if ( is_admin() ) {
		return false;
	}

	$method = isset( $_SERVER['REQUEST_METHOD'] ) ? strtoupper( sanitize_text_field( wp_unslash( $_SERVER['REQUEST_METHOD'] ) ) ) : 'GET';
	if ( 'GET' !== $method && 'HEAD' !== $method ) {
		return false;
	}

	/* Any authenticated or commenting reader gets a personalised document. */
	foreach ( array_keys( (array) $_COOKIE ) as $cookie ) {
		$cookie = (string) $cookie;
		if ( 0 === strpos( $cookie, 'wordpress_logged_in_' )
			|| 0 === strpos( $cookie, 'wp-postpass_' )
			|| 0 === strpos( $cookie, 'comment_author_' )
			|| 0 === strpos( $cookie, 'wp_woocommerce_session_' ) ) {
			return false;
		}
	}

	/* Preview, customizer and moderation flows are never shared documents. */
	$personal = array( 'preview', 'preview_id', 'preview_nonce', 'customize_changeset_uuid', 'unapproved', 'replytocom' );
	foreach ( $personal as $key ) {
		if ( isset( $_GET[ $key ] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
			return false;
		}
	}

	$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
	if ( false !== strpos( $request_uri, '/wp-admin/' ) || false !== strpos( $request_uri, '/wp-login.php' ) ) {
		return false;
	}

	return (bool) apply_filters( 'go_verge_cache_integrity_enabled', true );
}

/**
 * Stop PHP from rewriting the document's cache policy when a session starts.
 *
 * Called at theme load, which is before `init` and therefore before the
 * tracking hooks that start front-end sessions. Silent no-op when a session is
 * already active — `session_cache_limiter()` cannot be changed at that point
 * and would only raise a warning.
 *
 * @return bool True when the limiter was neutralised on this request.
 */
function go_verge_cache_integrity_disarm_session_limiter() {
	if ( ! function_exists( 'session_status' ) || ! function_exists( 'session_cache_limiter' ) ) {
		return false;
	}
	if ( PHP_SESSION_DISABLED === session_status() || PHP_SESSION_ACTIVE === session_status() ) {
		return false;
	}
	if ( ! go_verge_is_anonymous_public_document() ) {
		return false;
	}
	if ( '' === (string) session_cache_limiter() ) {
		return true;
	}
	session_cache_limiter( '' );
	return true;
}

/**
 * Cache policy for an anonymous public document.
 *
 * Empty string — the default — means "send nothing", which is what WordPress
 * itself does and leaves LiteSpeed Cache and the host in charge. A publisher
 * who wants the edge to store HTML sets GO_VERGE_PUBLIC_HTML_SMAXAGE and takes
 * on the obligation to purge the CDN when an article is published or corrected.
 *
 * @return string Cache-Control value, or '' to send no directive.
 */
function go_verge_public_cache_control() {
	$value = '';
	if ( defined( 'GO_VERGE_PUBLIC_HTML_SMAXAGE' ) ) {
		$s_maxage = absint( GO_VERGE_PUBLIC_HTML_SMAXAGE );
		if ( $s_maxage > 0 ) {
			$value = sprintf(
				'public, max-age=0, s-maxage=%d, stale-while-revalidate=%d, stale-if-error=%d',
				$s_maxage,
				min( $s_maxage, 60 ),
				DAY_IN_SECONDS
			);
		}
	}
	return (string) apply_filters( 'go_verge_public_cache_control', $value );
}

/**
 * Whether the currently sent headers are PHP's session cache limiter.
 *
 * The signature is the 1981 Expires date. WordPress `nocache_headers()` uses
 * 1984 and must never be undone here: a 404, a search page or a hub that
 * deliberately opted out of caching keeps its own policy.
 *
 * @return bool
 */
function go_verge_headers_carry_php_session_limiter() {
	if ( ! function_exists( 'headers_list' ) || headers_sent() ) {
		return false;
	}
	foreach ( headers_list() as $header ) {
		if ( 0 === stripos( $header, 'expires:' ) && false !== stripos( $header, GO_VERGE_PHP_SESSION_EXPIRES ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Remove the session cache limiter from an anonymous public document.
 *
 * @return bool True when headers were repaired.
 */
function go_verge_cache_integrity_repair_headers() {
	if ( headers_sent() || ! function_exists( 'header_remove' ) ) {
		return false;
	}
	if ( ! go_verge_is_anonymous_public_document() ) {
		return false;
	}
	/* A deliberate WordPress opt-out (404, thin tag, hub follower state, news
	 * sitemap) must survive untouched. Only PHP's own stamp is removed. */
	if ( ! go_verge_headers_carry_php_session_limiter() ) {
		return false;
	}
	if ( function_exists( 'is_404' ) && did_action( 'wp' ) && ( is_404() || is_search() || is_preview() ) ) {
		return false;
	}

	header_remove( 'Expires' );
	header_remove( 'Pragma' );
	header_remove( 'Cache-Control' );

	$policy = go_verge_public_cache_control();
	if ( '' !== $policy ) {
		header( 'Cache-Control: ' . $policy, true );
	}

	if ( ! defined( 'GO_VERGE_CACHE_HEADERS_REPAIRED' ) ) {
		define( 'GO_VERGE_CACHE_HEADERS_REPAIRED', true );
	}
	return true;
}
add_action( 'send_headers', 'go_verge_cache_integrity_repair_headers', 99 );
add_action( 'template_redirect', 'go_verge_cache_integrity_repair_headers', 99 );
/* A session started during rendering (a shortcode, a widget, a late tracker)
 * stamps the headers after template_redirect. Output is still buffered at
 * `get_header`, so this is the last point where the repair can land. */
add_action( 'get_header', 'go_verge_cache_integrity_repair_headers', 99 );

/**
 * Keep the anonymous document free of a session cookie.
 *
 * A `Set-Cookie` on an HTML response is enough for most CDNs to refuse to
 * store it, so this closes the last edge-cache hole.
 *
 * MEASURED, AND THE REASON THIS IS NOW ON BY DEFAULT (production, 03/09/2026)
 * --------------------------------------------------------------------------
 * Three sequential requests to one article, no cookie jar:
 *
 *   #1  set-cookie: PHPSESSID=…   X-Litespeed-Cache: miss  x-hcdn-cache-status: MISS  upstream-rt: 2.577
 *   #2  (no cookie)               X-LiteSpeed-Cache: hit   x-hcdn-cache-status: MISS  upstream-rt: 0.003
 *   #3  (no cookie)               X-LiteSpeed-Cache: hit   x-hcdn-cache-status: MISS  upstream-rt: 0.002
 *
 * LiteSpeed's own page cache works. The CDN edge never stored a single HTML
 * document — `MISS` on all three, and on every one of the 358 URLs sampled —
 * because the origin sometimes answers with `Set-Cookie`, and a conservative
 * edge refuses to store any response that does. Every reader request therefore
 * travelled to the origin, where an uncached article costs 2.7–7 s.
 *
 * This used to default to false, on the reasoning that the session belongs to
 * another component starts a native PHP session, so dropping its cookie was
 * previously left to the site owner. That reasoning held until the cost was
 * measured: an anonymous reader gets no benefit from a session cookie, and the
 * component that sets it re-establishes one on the request that actually needs
 * it. The cookie is stripped only from anonymous public GET documents — logged
 * in, commenting, preview and admin requests keep theirs, because
 * `go_verge_is_anonymous_public_document()` excludes them.
 *
 * Escape hatch, for a site whose tracking genuinely needs the cookie on HTML:
 *
 *     add_filter( 'go_verge_cache_integrity_drop_session_cookie', '__return_false' );
 */
function go_verge_cache_integrity_drop_session_cookie() {
	if ( headers_sent() || ! function_exists( 'headers_list' ) ) {
		return;
	}
	if ( ! apply_filters( 'go_verge_cache_integrity_drop_session_cookie', true ) ) {
		return;
	}
	if ( ! go_verge_is_anonymous_public_document() ) {
		return;
	}

	$name    = function_exists( 'session_name' ) ? (string) session_name() : 'PHPSESSID';
	$keep    = array();
	$dropped = false;
	foreach ( headers_list() as $header ) {
		if ( 0 !== stripos( $header, 'set-cookie:' ) ) {
			continue;
		}
		$value = trim( substr( $header, strlen( 'set-cookie:' ) ) );
		if ( 0 === stripos( $value, $name . '=' ) ) {
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
add_action( 'send_headers', 'go_verge_cache_integrity_drop_session_cookie', 100 );
/* A plugin can start a session after WP::send_headers() (for example on a late
 * template_redirect callback). Re-run the same surgical cookie cleanup before
 * the header template prints any bytes. The function is idempotent and keeps
 * every non-session Set-Cookie header intact. */
add_action( 'template_redirect', 'go_verge_cache_integrity_drop_session_cookie', 1000 );
add_action( 'get_header', 'go_verge_cache_integrity_drop_session_cookie', 100 );

/**
 * Record what the front end actually sent, so Site Health can report facts.
 *
 * Sampled from real anonymous pageviews rather than from a self-request: a
 * loopback request can be answered by a different worker, a different cache
 * layer or a different plugin state than a reader's request.
 */
function go_verge_cache_integrity_record_state() {
	if ( ! go_verge_is_anonymous_public_document() || ! function_exists( 'headers_list' ) ) {
		return;
	}
	$snapshot = get_option( 'go_verge_cache_integrity_state', array() );
	$snapshot = is_array( $snapshot ) ? $snapshot : array();

	/* One sample per hour is enough to notice a regression and cheap enough to
	 * never matter on a page view. */
	if ( ! empty( $snapshot['checked_at'] ) && ( time() - (int) $snapshot['checked_at'] ) < HOUR_IN_SECONDS ) {
		return;
	}

	$cache_control = '';
	$session_cookie = false;
	foreach ( headers_list() as $header ) {
		if ( 0 === stripos( $header, 'cache-control:' ) ) {
			$cache_control = trim( substr( $header, strlen( 'cache-control:' ) ) );
		}
		if ( 0 === stripos( $header, 'set-cookie:' ) && false !== stripos( $header, 'PHPSESSID=' ) ) {
			$session_cookie = true;
		}
	}

	update_option(
		'go_verge_cache_integrity_state',
		array(
			'checked_at'     => time(),
			'session_active' => function_exists( 'session_status' ) && PHP_SESSION_ACTIVE === session_status(),
			'session_cookie' => $session_cookie,
			'cache_control'  => $cache_control,
			'repaired'       => defined( 'GO_VERGE_CACHE_HEADERS_REPAIRED' ),
			'limiter'        => function_exists( 'session_cache_limiter' ) ? (string) @session_cache_limiter() : '', // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
		),
		false
	);
}
add_action( 'wp_footer', 'go_verge_cache_integrity_record_state', 999 );

/**
 * Install/update the early cache guard as an MU-plugin.
 *
 * The source lives inside the theme for version control, but execution must
 * happen from wp-content/mu-plugins so it precedes normal plugins.
 */
function go_verge_cache_integrity_mu_guard_source() {
	return GO_VERGE_DIR . '/deployment/mu-plugins/overdrive-public-cache-integrity.php';
}

function go_verge_cache_integrity_mu_guard_target() {
	$dir = defined( 'WPMU_PLUGIN_DIR' ) ? WPMU_PLUGIN_DIR : WP_CONTENT_DIR . '/mu-plugins';
	return trailingslashit( $dir ) . 'overdrive-public-cache-integrity.php';
}

/** Return installation state without mutating the filesystem. */
function go_verge_cache_integrity_mu_guard_status() {
	$source = go_verge_cache_integrity_mu_guard_source();
	$target = go_verge_cache_integrity_mu_guard_target();
	$out    = array(
		'installed' => false,
		'current'   => false,
		'source'    => $source,
		'target'    => $target,
		'error'     => '',
	);

	if ( ! is_readable( $source ) ) {
		$out['error'] = 'arquivo-fonte do MU guard não está disponível no tema';
		return $out;
	}
	if ( ! is_readable( $target ) ) {
		return $out;
	}

	$target_contents = (string) @file_get_contents( $target ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	if ( false === strpos( $target_contents, 'OVERDRIVE_PUBLIC_CACHE_GUARD_VERSION' ) ) {
		$out['error'] = 'já existe um arquivo com o mesmo nome que não pertence ao Overdrive';
		return $out;
	}

	$out['installed'] = true;
	$source_hash      = @hash_file( 'sha256', $source ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	$target_hash      = @hash_file( 'sha256', $target ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	$out['current']   = is_string( $source_hash ) && '' !== $source_hash && hash_equals( $source_hash, (string) $target_hash );
	return $out;
}

/**
 * Make the early guard self-healing on theme upgrades.
 *
 * We only write our own uniquely named MU-plugin and never overwrite a foreign
 * file. If the host forbids writes, Discover Health reports the exact manual
 * copy path instead of pretending the protection is active.
 */
function go_verge_cache_integrity_ensure_mu_guard() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) ) {
		return;
	}

	$status = go_verge_cache_integrity_mu_guard_status();
	if ( ! empty( $status['current'] ) ) {
		return;
	}
	if ( ! empty( $status['error'] ) && file_exists( $status['target'] ) ) {
		update_option( 'go_verge_cache_integrity_mu_guard_error', (string) $status['error'], false );
		return;
	}

	$dir = dirname( $status['target'] );
	if ( ! is_dir( $dir ) && ! wp_mkdir_p( $dir ) ) {
		update_option( 'go_verge_cache_integrity_mu_guard_error', 'não foi possível criar ' . $dir, false );
		return;
	}

	$source = @file_get_contents( $status['source'] ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged
	if ( ! is_string( $source ) || '' === $source ) {
		update_option( 'go_verge_cache_integrity_mu_guard_error', 'não foi possível ler o arquivo-fonte do MU guard', false );
		return;
	}

	$bytes = @file_put_contents( $status['target'], $source, LOCK_EX ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged,WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
	if ( false === $bytes ) {
		update_option( 'go_verge_cache_integrity_mu_guard_error', 'wp-content/mu-plugins não é gravável pelo PHP', false );
		return;
	}

	delete_option( 'go_verge_cache_integrity_mu_guard_error' );
	/* Discard the pre-guard sample so the admin does not keep showing a stale
	 * PHPSESSID critical for another hour after the protection was installed. */
	delete_option( 'go_verge_cache_integrity_state' );
	if ( defined( 'GO_VERGE_DISCOVER_HEALTH_TRANSIENT' ) ) {
		delete_transient( GO_VERGE_DISCOVER_HEALTH_TRANSIENT );
	}
}
add_action( 'admin_init', 'go_verge_cache_integrity_ensure_mu_guard', 1 );

/** Report the measured cache policy of the public front end. */
function go_verge_cache_integrity_health_test() {
	$badge = array( 'label' => __( 'Desempenho', 'go-verge' ), 'color' => 'blue' );
	$state = get_option( 'go_verge_cache_integrity_state', array() );
	$state = is_array( $state ) ? $state : array();

	if ( empty( $state['checked_at'] ) ) {
		return array(
			'label'       => __( 'Ainda não há amostra de cabeçalhos do front-end', 'go-verge' ),
			'status'      => 'recommended',
			'badge'       => $badge,
			'description' => '<p>' . esc_html__( 'Abra qualquer página pública deslogado (uma janela anônima serve) para que o tema registre os cabeçalhos realmente enviados a um leitor.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_cache_integrity',
		);
	}

	$cache_control = (string) ( $state['cache_control'] ?? '' );
	$poisoned      = false !== stripos( $cache_control, 'no-store' ) || false !== stripos( $cache_control, 'no-cache' );

	if ( $poisoned ) {
		return array(
			'label'       => __( 'O front-end público ainda envia no-store e não pode ser cacheado', 'go-verge' ),
			'status'      => 'critical',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: 1: Cache-Control value, 2: yes/no for the session cookie. */
					__( 'A última amostra de um leitor anônimo respondeu Cache-Control: %1$s (cookie de sessão presente: %2$s). Com no-store o LiteSpeed e o CDN não guardam o HTML e o navegador não pode usar o back/forward cache — cada "voltar" repete TTFB, LCP e INP.', 'go-verge' ),
					'' !== $cache_control ? $cache_control : __( '(vazio)', 'go-verge' ),
					! empty( $state['session_cookie'] ) ? __( 'sim', 'go-verge' ) : __( 'não', 'go-verge' )
				)
			) . '</p><p>' . esc_html__( 'Causa típica: um componente inicia sessão PHP no front-end e o limitador de cache padrão do PHP (session.cache_limiter=nocache) carimba o documento. O tema desarma o limitador no carregamento, o que só falha se a sessão começar antes disso — session.auto_start no PHP, um drop-in ou um mu-plugin. Desative a sessão no front-end nesse componente ou defina session.cache_limiter="" no PHP.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_cache_integrity',
		);
	}

	/* A healthy Cache-Control is not enough on its own: a Set-Cookie on the
	 * document makes a conservative CDN refuse to store it, which is exactly
	 * what produced `x-hcdn-cache-status: MISS` on every URL before 3.66.2. */
	if ( ! empty( $state['session_cookie'] ) ) {
		return array(
			'label'       => __( 'O HTML público ainda sai com cookie de sessão e o CDN não vai guardá-lo', 'go-verge' ),
			'status'      => 'recommended',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: %s: measured Cache-Control value. */
					__( 'A política de cache está correta (Cache-Control: %s), mas a última amostra anônima ainda trazia Set-Cookie: PHPSESSID. A maioria dos CDNs se recusa a armazenar uma resposta que define cookie, então o HTML continua sendo buscado na origem a cada visita.', 'go-verge' ),
					'' !== $cache_control ? $cache_control : __( '(nenhum)', 'go-verge' )
				)
			) . '</p><p>' . esc_html__( 'O tema remove esse cookie de documentos públicos anônimos desde a 3.66.2. Se ele reapareceu, algo está filtrando go_verge_cache_integrity_drop_session_cookie para false, ou a sessão começa depois de send_headers.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_cache_integrity',
		);
	}

	$label = ! empty( $state['repaired'] )
		? __( 'O tema removeu o limitador de sessão e o HTML voltou a ser cacheável', 'go-verge' )
		: __( 'O front-end público envia uma política de cache saudável', 'go-verge' );

	return array(
		'label'       => $label,
		'status'      => 'good',
		'badge'       => $badge,
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: 1: Cache-Control value, 2: session state, 3: age of the sample. */
				__( 'Última amostra anônima: Cache-Control: %1$s. Sessão PHP ativa na renderização: %2$s. Amostra coletada há %3$s.', 'go-verge' ),
				'' !== $cache_control ? $cache_control : __( '(nenhum — padrão do WordPress)', 'go-verge' ),
				! empty( $state['session_active'] ) ? __( 'sim', 'go-verge' ) : __( 'não', 'go-verge' ),
				human_time_diff( (int) $state['checked_at'] )
			)
		) . '</p>',
		'test'        => 'go_verge_cache_integrity',
	);
}

/** Register the cache-integrity test alongside the other Overdrive checks. */
function go_verge_register_cache_integrity_health( $tests ) {
	$tests['direct']['go_verge_cache_integrity'] = array(
		'label' => __( 'Cacheabilidade do front-end', 'go-verge' ),
		'test'  => 'go_verge_cache_integrity_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_cache_integrity_health' );


/**
 * Publish a short shared-cache policy for anonymous editorial HTML.
 *
 * The site's field TTFB is dominated by uncached origin work. LiteSpeed remains
 * the primary page cache; this header additionally gives a standards-compliant
 * CDN/edge permission to reuse the anonymous HTML for a few minutes. We never
 * override an explicit private/no-store/no-cache response and never cache a
 * response that still sets any cookie.
 */
function go_verge_cache_integrity_apply_shared_policy() {
	if ( headers_sent() || ! function_exists( 'headers_list' ) || ! go_verge_is_anonymous_public_document() ) {
		return;
	}
	if ( is_feed() || is_search() || is_404() || is_preview() ) {
		return;
	}
	$context_ok = is_front_page() || is_home() || is_singular() || is_category() || is_tag() || is_author() || is_archive();
	if ( ! $context_ok ) {
		return;
	}

	$cache_control = '';
	foreach ( headers_list() as $header ) {
		if ( 0 === stripos( $header, 'set-cookie:' ) ) {
			return; // Never turn a personalised/cookie-setting response into shared HTML.
		}
		if ( 0 === stripos( $header, 'cache-control:' ) ) {
			$cache_control = strtolower( trim( substr( $header, strlen( 'cache-control:' ) ) ) );
		}
	}
	if ( '' !== $cache_control ) {
		/* Respect every explicit cache decision. LiteSpeed may already have emitted
		 * a public policy, while plugins can deliberately mark a document private. */
		return;
	}

	$ttl = absint( apply_filters( 'go_verge_public_html_default_smaxage', 300 ) );
	if ( $ttl < 30 ) {
		return;
	}
	$stale = min( 60, max( 15, (int) floor( $ttl / 5 ) ) );
	header(
		sprintf(
			'Cache-Control: public, max-age=0, s-maxage=%d, stale-while-revalidate=%d, stale-if-error=%d',
			$ttl,
			$stale,
			DAY_IN_SECONDS
		),
		true
	);
}
add_action( 'template_redirect', 'go_verge_cache_integrity_apply_shared_policy', 1200 );
add_action( 'get_header', 'go_verge_cache_integrity_apply_shared_policy', 120 );
