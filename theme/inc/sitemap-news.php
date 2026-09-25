<?php
/**
 * Google News sitemap at /news-sitemap.xml.
 *
 * Plugin-independent implementation for Overdrive. It follows Google's
 * current News sitemap rules: only recently published articles, original
 * publication date, up to 1,000 entries, and the required News XML namespace.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_NEWS_SITEMAP_TRANSIENT' ) ) {
	define( 'GO_VERGE_NEWS_SITEMAP_TRANSIENT', 'go_verge_news_sitemap_v7' );
}

/**
 * True when Rank Math PRO is actively providing a News sitemap.
 * The theme fallback must never compete for the same endpoint.
 */
function go_verge_news_sitemap_rank_math_news_active() {
	if ( ! defined( 'RANK_MATH_VERSION' ) && ! class_exists( 'RankMath' ) ) {
		return false;
	}

	$active = false;
	$module_state_known = false;
	foreach ( array( 'rank_math_modules', 'rank-math-options-modules' ) as $option_name ) {
		$modules = get_option( $option_name, null );
		if ( ! is_array( $modules ) ) {
			continue;
		}
		$module_state_known = true;
		foreach ( $modules as $key => $value ) {
			$key_normalized   = str_replace( '_', '-', strtolower( (string) $key ) );
			$value_normalized = is_scalar( $value ) ? str_replace( '_', '-', strtolower( (string) $value ) ) : '';
			if ( ( 'news-sitemap' === $key_normalized && ! empty( $value ) ) || 'news-sitemap' === $value_normalized ) {
				$active = true;
				break 2;
			}
		}
	}

	/* Different Rank Math PRO releases have used different namespaces. Class
	 * existence is treated as a secondary signal only when no persisted module
	 * state can be read. */
	if ( ! $active && ! $module_state_known ) {
		foreach ( array(
			'RankMathPro\\News_Sitemap\\News_Sitemap',
			'RankMathPro\\News_Sitemap',
			'RankMath\\Pro\\News_Sitemap\\News_Sitemap',
		) as $class_name ) {
			if ( class_exists( $class_name ) ) {
				$active = true;
				break;
			}
		}
	}

	return (bool) apply_filters( 'go_verge/news_sitemap/rank_math_owns', $active );
}

/** Whether the theme fallback owns /news-sitemap.xml. */
function go_verge_news_sitemap_theme_owns_endpoint() {
	/* Stable newsroom endpoint. Rank Math module state must never make a News
	 * sitemap disappear between publishes/plugin updates. */
	return true;
}

/**
 * Mark the News sitemap as a machine-readable, non-page-cache response.
 *
 * `Cache-Control: no-store` is necessary but not sufficient for every LiteSpeed
 * stack: an old cached 301/HTML response can be served before PHP gets a chance
 * to emit fresh headers. The explicit LiteSpeed control action keeps the endpoint
 * outside page cache after the old entry is purged on the first request of this
 * theme version (inc/litespeed-compat.php). DONOTCACHEPAGE also protects other
 * compatible caching layers that honor WordPress' conventional flag.
 */
function go_verge_news_sitemap_mark_nocache() {
	if ( ! defined( 'DONOTCACHEPAGE' ) ) {
		define( 'DONOTCACHEPAGE', true );
	}

	do_action( 'litespeed_control_set_nocache', 'Overdrive News sitemap' );
}

/**
 * Register /news-sitemap.xml.
 */
function go_verge_news_sitemap_rewrite() {
	if ( ! go_verge_news_sitemap_theme_owns_endpoint() ) { return; }
	add_rewrite_tag( '%go_news_sitemap%', '1' );
	add_rewrite_rule( '^news-sitemap\.xml/?$', 'index.php?go_news_sitemap=1', 'top' );
}
add_action( 'init', 'go_verge_news_sitemap_rewrite', 1 );

/**
 * Determine whether the current request is for the News sitemap.
 *
 * @return bool
 */
function go_verge_news_sitemap_is_request() {
	if ( ! go_verge_news_sitemap_theme_owns_endpoint() ) { return false; }
	if ( '1' === (string) get_query_var( 'go_news_sitemap' ) ) {
		return true;
	}

	$uri           = isset( $_SERVER['REQUEST_URI'] ) ? (string) wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
	$path          = untrailingslashit( (string) wp_parse_url( $uri, PHP_URL_PATH ) );
	$expected_path = untrailingslashit( (string) wp_parse_url( home_url( '/news-sitemap.xml' ), PHP_URL_PATH ) );

	return '' !== $expected_path && $expected_path === $path;
}

/** Do not append a trailing slash to the XML endpoint. */
function go_verge_news_sitemap_disable_canonical_redirect( $redirect_url ) {
	return go_verge_news_sitemap_is_request() ? false : $redirect_url;
}
add_filter( 'redirect_canonical', 'go_verge_news_sitemap_disable_canonical_redirect' );

/**
 * Flush rewrite rules once per theme version so the endpoint works immediately
 * after installing this build.
 */
function go_verge_news_sitemap_maybe_flush() {
	if ( ! go_verge_news_sitemap_theme_owns_endpoint() ) { return; }
	if ( get_option( 'go_verge_news_sitemap_flushed' ) === GO_VERGE_VERSION ) {
		return;
	}

	/* A theme update can change eligibility/classification without firing a
	 * post save. Never serve the previous build's 15-minute XML snapshot. */
	delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );

	/*
	 * flush_rewrite_rules() rewrites a large option. Older builds did this on
	 * public `init`, so concurrent first requests after a deploy could all try
	 * to rebuild rules. 3.15.1 runs this only from admin_init and uses the shared
	 * single-writer lock; all public routes are registered normally during init.
	 */
	if ( ! go_verge_news_sitemap_claim_flush_lock() ) {
		return;
	}

	go_verge_news_sitemap_rewrite();
	go_verge_flush_rewrite_rules_once_per_request();

	/*
	 * Stored autoloaded on purpose: this guard is read on every single request,
	 * which is exactly what autoload is for. As a non-autoloaded row it cost one
	 * extra query per page view to answer "no, nothing to do".
	 */
	delete_option( 'go_verge_news_sitemap_flushed' );
	add_option( 'go_verge_news_sitemap_flushed', GO_VERGE_VERSION, '', true );
	go_verge_release_job_lock( 'news_sitemap_flush' );
}

/**
 * Single-writer lock around the rewrite flush.
 *
 * @return bool True when this request owns the flush.
 */
function go_verge_news_sitemap_claim_flush_lock() {
	return function_exists( 'go_verge_claim_job_lock' ) ? go_verge_claim_job_lock( 'news_sitemap_flush', 120 ) : false;
}
add_action( 'admin_init', 'go_verge_news_sitemap_maybe_flush', 98 );

/** Reset rewrite/cache state when the theme is activated. */
function go_verge_news_sitemap_reset_rewrite_flag() {
	delete_option( 'go_verge_news_sitemap_flushed' );
	delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
}
add_action( 'after_switch_theme', 'go_verge_news_sitemap_reset_rewrite_flag' );

/** Bust the News sitemap cache whenever published content can change. */
function go_verge_news_sitemap_bust_cache( $object_id = 0 ) {
	if ( 'save_post_post' === current_filter() ) {
		$post_id = absint( $object_id );
		if ( ! $post_id || ! in_array( get_post_status( $post_id ), array( 'publish', 'future', 'trash' ), true ) ) {
			return;
		}
	}
	delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
}
add_action( 'save_post_post', 'go_verge_news_sitemap_bust_cache' );
add_action( 'deleted_post', 'go_verge_news_sitemap_bust_cache' );
add_action( 'transition_post_status', 'go_verge_news_sitemap_bust_cache' );

/**
 * Post meta whose value can change News sitemap membership or XML output.
 *
 * Meta boxes and SEO plugins commonly persist these values after `save_post`,
 * so the post-level hook above can run too early to invalidate the final state.
 * Keeping the dependency list beside the sitemap makes that cache contract
 * explicit and prevents a cached URL from retaining a stale canonical/noindex,
 * Article subtype, editorial clock, or representative image for 15 minutes.
 *
 * @return string[]
 */
function go_verge_news_sitemap_relevant_meta_keys() {
	$keys = array(
		defined( 'GO_VERGE_SCHEMA_TYPE_META' ) ? GO_VERGE_SCHEMA_TYPE_META : '_go_schema_article_type',
		defined( 'GO_VERGE_FIRST_PUBLISHED_META' ) ? GO_VERGE_FIRST_PUBLISHED_META : '_go_first_published_gmt',
		'_go_search_content_modified_gmt',
		'_thumbnail_id',
		'rank_math_canonical_url',
		'rank_math_robots',
		'rank_math_title',
		'_yoast_wpseo_canonical',
		'_yoast_wpseo_meta-robots-noindex',
		'_yoast_wpseo_title',
		'_yoast_wpseo_metadesc',
	'_yoast_wpseo_redirect',
	);

	/**
	 * Filter metadata dependencies that invalidate the News sitemap cache.
	 *
	 * @param string[] $keys Relevant post-meta keys.
	 */
	$keys = (array) apply_filters( 'go_verge/news_sitemap/relevant_meta_keys', $keys );

	return array_values( array_unique( array_filter( array_map( 'strval', $keys ) ) ) );
}

/** Bust the cache after an editorial or Rank Math dependency changes. */
function go_verge_news_sitemap_meta_changed( $meta_id, $object_id, $meta_key, $meta_value = null ) {
	unset( $meta_id, $meta_value );
	$object_id = absint( $object_id );
	if ( ! $object_id || 'post' !== get_post_type( $object_id ) || ! in_array( (string) $meta_key, go_verge_news_sitemap_relevant_meta_keys(), true ) ) {
		return;
	}

	delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
}
add_action( 'added_post_meta', 'go_verge_news_sitemap_meta_changed', 100, 4 );
add_action( 'updated_post_meta', 'go_verge_news_sitemap_meta_changed', 100, 4 );
add_action( 'deleted_post_meta', 'go_verge_news_sitemap_meta_changed', 100, 4 );

/** Bust when an assignment can add or remove a post from Google News. */
function go_verge_news_sitemap_terms_changed( $object_id, $terms, $tt_ids, $taxonomy ) {
	unset( $terms, $tt_ids );
	$object_id = absint( $object_id );
	if ( ! $object_id || 'post' !== get_post_type( $object_id ) || ! in_array( (string) $taxonomy, array( 'category', 'go_content_type' ), true ) ) {
		return;
	}

	delete_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
}
add_action( 'set_object_terms', 'go_verge_news_sitemap_terms_changed', 100, 4 );

/* Publication identity/language are part of every cached <news:publication>. */
add_action( 'update_option_go_verge_news_publication_name', 'go_verge_news_sitemap_bust_cache' );
add_action( 'update_option_blogname', 'go_verge_news_sitemap_bust_cache' );
add_action( 'update_option_WPLANG', 'go_verge_news_sitemap_bust_cache' );
add_action( 'update_option_rank-math-options-titles', 'go_verge_news_sitemap_bust_cache' );
add_action( 'update_option_wpseo_titles', 'go_verge_news_sitemap_bust_cache' );

/**
 * News uses the visible editorial headline, without document-title decoration.
 * Google's News sitemap specification excludes publication/author/date suffixes
 * from news:title; SEO templates commonly add exactly those fields.
 */
function go_verge_news_sitemap_document_title( $post_id ) {
	$post_id = absint( $post_id );
	$post    = $post_id ? get_post( $post_id ) : null;
	if ( ! ( $post instanceof WP_Post ) ) { return ''; }

	$title = (string) get_the_title( $post_id );
	$title = preg_replace( '/\s+/u', ' ', wp_strip_all_tags( wp_specialchars_decode( $title, ENT_QUOTES ) ) );
	return trim( (string) $title );
}

/**
 * Return the publication name used by Google News.
 *
 * @return string
 */
function go_verge_news_sitemap_publication_name() {
	$name = trim( wp_strip_all_tags( (string) get_option( 'go_verge_news_publication_name', '' ) ) );
	if ( '' === $name ) {
		$name = function_exists( 'go_verge_seo_site_name' )
			? go_verge_seo_site_name()
			: get_bloginfo( 'name' );
	}

	$name = trim( wp_strip_all_tags( (string) $name ) );
	return '' !== $name ? $name : 'Overdrive';
}

/** Expose the official Google News publication name in Settings > General. */
function go_verge_news_sitemap_register_publication_name_setting() {
	register_setting(
		'general',
		'go_verge_news_publication_name',
		array(
			'type'              => 'string',
			'sanitize_callback' => 'sanitize_text_field',
			'default'           => '',
		)
	);
	add_settings_field(
		'go_verge_news_publication_name',
		__( 'Nome oficial no Google News', 'go-verge' ),
		'go_verge_news_sitemap_publication_name_field',
		'general'
	);
}
add_action( 'admin_init', 'go_verge_news_sitemap_register_publication_name_setting' );

function go_verge_news_sitemap_publication_name_field() {
	$value = (string) get_option( 'go_verge_news_publication_name', '' );
	?>
	<input type="text" class="regular-text" name="go_verge_news_publication_name" value="<?php echo esc_attr( $value ); ?>" placeholder="<?php echo esc_attr( get_bloginfo( 'name' ) ); ?>">
	<p class="description"><?php esc_html_e( 'Use exatamente o nome da publicação exibido no Google News. Em branco, o tema usa o nome do site.', 'go-verge' ); ?></p>
	<?php
}

/**
 * Return a Google News-compatible publication language code.
 *
 * @return string
 */
function go_verge_news_sitemap_language() {
	$language = strtolower( str_replace( '_', '-', (string) get_bloginfo( 'language' ) ) );

	if ( 0 === strpos( $language, 'zh-cn' ) ) {
		return 'zh-cn';
	}
	if ( 0 === strpos( $language, 'zh-tw' ) ) {
		return 'zh-tw';
	}

	$primary = strtok( $language, '-' );
	return $primary ? $primary : 'pt';
}

/**
 * Respect explicit Rank Math noindex settings and keep inaccessible posts out.
 *
 * @param int $post_id Post ID.
 * @return bool
 */
function go_verge_news_sitemap_post_is_eligible( $post_id ) {
	$post = get_post( $post_id );
	if ( ! $post || 'publish' !== $post->post_status || '' !== (string) $post->post_password ) {
		return false;
	}
	/* Use the canonical sitemap's single eligibility contract when available.
	 * In particular, a post canonicalized to another URL must not be submitted
	 * as a separate News result. */
	if ( function_exists( 'go_verge_smart_sitemap_post_eligible' ) && ! go_verge_smart_sitemap_post_eligible( $post_id ) ) {
		return false;
	}

	/* Keep Google News sitemap semantically aligned with the schema graph. */
	if ( function_exists( 'go_verge_post_is_news_article' ) && ! go_verge_post_is_news_article( $post_id ) ) {
		return false;
	}

	/* Google's News sitemap window is based on the original publication time,
	 * not on a later post_date/post_modified edit. Use the same immutable clock
	 * as Article schema so a republished/updated evergreen URL cannot sneak back
	 * into News merely because its WordPress date moved. */
	$published_ts = function_exists( 'go_verge_search_published_timestamp' )
		? (int) go_verge_search_published_timestamp( $post_id )
		: (int) get_post_time( 'U', true, $post_id );
	$now = time();
	if ( ! $published_ts || $published_ts < ( $now - ( 2 * DAY_IN_SECONDS ) ) || $published_ts > ( $now + ( 5 * MINUTE_IN_SECONDS ) ) ) {
		return false;
	}

	/* The shared contract already resolved the active SEO provider. An old
	 * Rank Math value must not veto an indexable Yoast article a second time.
	 * Keep the conservative fallback only for standalone use of this module. */
	if ( ! function_exists( 'go_verge_smart_sitemap_post_eligible' ) ) {
		$robots = get_post_meta( $post_id, 'rank_math_robots', true );
		if ( is_string( $robots ) ) {
			$robots = preg_split( '/[\s,]+/', strtolower( $robots ) );
		}
		if ( is_array( $robots ) ) {
			$robots = array_map( 'strtolower', array_map( 'strval', $robots ) );
			if ( in_array( 'noindex', $robots, true ) ) {
				return false;
			}
		}
	}

	/**
	 * Allow editorial code to exclude a specific post from Google News without
	 * removing it from the normal XML sitemap.
	 *
	 * @param bool $eligible Whether the post belongs in the News sitemap.
	 * @param int  $post_id  Post ID.
	 */
	return (bool) apply_filters( 'go_verge/news_sitemap/include_post', true, $post_id );
}

/**
 * Build the WP_Query arguments used by the News sitemap.
 *
 * Google requires entries to be articles published within the last two days.
 * WP_Query uses a slightly wider three-day prefilter for efficiency; the exact
 * immutable 48-hour window is enforced by go_verge_news_sitemap_post_is_eligible()
 * using the same first-publication clock as Article schema.
 *
 * @return array
 */
/**
 * Best high-resolution featured image for a fresh article.
 *
 * The News sitemap also carries the Image sitemap extension so Google can
 * discover the exact representative image at the same time as the article.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_news_sitemap_image_url( $post_id ) {
	$image_id = get_post_thumbnail_id( $post_id );
	if ( ! $image_id || ! function_exists( 'go_verge_rank_math_discover_image' ) ) {
		return '';
	}

	$image = go_verge_rank_math_discover_image( $image_id );
	return ! empty( $image['url'] ) ? esc_url_raw( $image['url'] ) : '';
}

function go_verge_news_sitemap_query_args( $first_publication = false ) {
	$args = array(
		'post_type'              => 'post',
		'post_status'            => 'publish',
		'posts_per_page'         => 1000,
		'orderby'                => 'date',
		'order'                  => 'DESC',
		'ignore_sticky_posts'    => true,
		'no_found_rows'          => true,
		'update_post_meta_cache' => true,
		'update_post_term_cache' => false,
		'has_password'           => false,
		'date_query'             => array(
			array(
				'after'     => wp_date( 'Y-m-d H:i:s', time() - ( 3 * DAY_IN_SECONDS ) ),
				'inclusive' => true,
				'column'    => 'post_date',
			),
		),
	);
	/* The first-publication clock may be newer than an old draft/scheduled
	 * post_date. Query it separately, in UTC, then deduplicate both candidate
	 * sets. The existing query filter still runs last for each candidate query. */
	if ( $first_publication ) {
		unset( $args['date_query'] );
		$args['meta_key'] = defined( 'GO_VERGE_FIRST_PUBLISHED_META' ) ? GO_VERGE_FIRST_PUBLISHED_META : '_go_first_published_gmt';
		$args['meta_value'] = gmdate( 'Y-m-d H:i:s', time() - ( 2 * DAY_IN_SECONDS ) );
		$args['meta_compare'] = '>=';
		$args['meta_type'] = 'DATETIME';
		$args['orderby'] = 'meta_value';
	}

	/**
	 * Filter the News sitemap query for future editorial needs.
	 * Keep Google's 48-hour and 1,000-entry limits intact.
	 */
	return (array) apply_filters( 'go_verge/news_sitemap/query_args', $args, $first_publication );
}

/**
 * Return a valid sitemap last-modified clock that cannot predate publication.
 *
 * Imported and migrated posts can legitimately carry a WordPress modified time
 * older than the immutable first-publication meta. Sitemap clocks must describe
 * the public URL, so clamp that legacy value to publication instead of emitting
 * a contradictory pair of dates.
 *
 * @param string $publication_date ISO-8601 publication date.
 * @param string $modified_date    ISO-8601 modification date.
 * @return string ISO-8601 date, or an empty string when neither input is valid.
 */
function go_verge_news_sitemap_consistent_lastmod_iso( $publication_date, $modified_date ) {
	$publication_ts = strtotime( trim( (string) $publication_date ) );
	$modified_ts    = strtotime( trim( (string) $modified_date ) );

	if ( ! $publication_ts ) {
		return $modified_ts ? gmdate( DATE_W3C, $modified_ts ) : '';
	}
	if ( ! $modified_ts || $modified_ts < $publication_ts ) {
		$modified_ts = $publication_ts;
	}

	return gmdate( DATE_W3C, $modified_ts );
}

/**
 * Send the sitemap and end the request.
 *
 * Split out of go_verge_news_sitemap_render() so the early router and the
 * template_redirect fail-safe emit byte-identical responses.
 */
/**
 * Cache only while every News entry remains inside its publication window.
 * Re-check cached XML as well: cache lifetime alone cannot validate snapshots
 * written by an earlier release or near a moving 48-hour boundary.
 */
function go_verge_news_sitemap_cache_ttl( $xml, $now = null ) {
	$now = null === $now ? time() : (int) $now;
	$ttl = 15 * MINUTE_IN_SECONDS;
	preg_match_all( '#<news:publication_date>\s*([^<]+)\s*</news:publication_date>#', (string) $xml, $matches );
	foreach ( $matches[1] as $date ) {
		$published = strtotime( trim( $date ) );
		if ( ! $published ) { return 0; }
		/* Eligibility includes the exact boundary second. */
		$remaining = $published + ( 2 * DAY_IN_SECONDS ) + 1 - $now;
		if ( $remaining <= 0 ) { return 0; }
		$ttl = min( $ttl, $remaining );
	}
	return $ttl;
}

function go_verge_news_sitemap_send() {
	go_verge_news_sitemap_mark_nocache();

	$xml = get_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT );
	if ( false === $xml || ! is_string( $xml ) || '' === $xml || ! go_verge_news_sitemap_cache_ttl( $xml ) ) {
		$xml = go_verge_news_sitemap_build();
		$ttl = go_verge_news_sitemap_cache_ttl( $xml );
		if ( $ttl > 0 ) { set_transient( GO_VERGE_NEWS_SITEMAP_TRANSIENT, $xml, $ttl ); }
	}

	if ( ! headers_sent() ) {
		status_header( 200 );
		nocache_headers();
		header( 'Content-Type: application/xml; charset=UTF-8', true );
		header( 'X-Robots-Tag: noindex, follow', true );
		header( 'Cache-Control: no-store, no-cache, must-revalidate, max-age=0', true );
		header( 'CDN-Cache-Control: no-store', true );
		header( 'Surrogate-Control: no-store', true );
		header( 'X-LiteSpeed-Cache-Control: no-cache', true );
		header( 'X-Accel-Expires: 0', true );
	}

	echo $xml; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- XML is escaped while built.
	exit;
}

/**
 * Strong route: resolve /news-sitemap.xml before the main query runs.
 *
 * MEASURED PROBLEM (production, 04/09/2026)
 * -----------------------------------------
 * `https://gameoverdrive.com.br/news-sitemap.xml` — the URL declared in
 * robots.txt AND listed inside /sitemap.xml — answered
 *
 *     HTTP 200, Content-Type: text/html, after a 301 to /ultimas-publicacoes/
 *
 * so Google had no News sitemap at all, and the general sitemap index pointed
 * at an HTML page.
 *
 * The cause is hook ordering, not the rewrite rule. When the `news-sitemap.xml`
 * rule is missing from the live rules (any flush that lands after this file
 * registered it), WordPress resolves the path with EMPTY query vars — which is
 * the blog-home query, not a 404. `is_home()` is then true, and
 * go_verge_redirect_duplicate_latest_page() at `template_redirect` -2 sends the
 * request to the canonical "Últimas" hub and exits. The path-based fallback in
 * go_verge_news_sitemap_is_request() exists precisely for the missing-rule case,
 * but it only ran at `template_redirect` **0** — ten theme redirects are
 * registered ahead of it, so the fallback could never win.
 *
 * The general sitemap already solved this in go_verge_smart_sitemap_early_router():
 * route on `wp_loaded`, after every plugin and theme has registered its content
 * and before WP_Query exists, so no 404, canonical or consolidation redirect can
 * claim the URL and no rewrite flush is required. The News endpoint now uses the
 * same contract. Regression guard: tests/news-sitemap-endpoint.test.php asserts
 * this callback is registered earlier than every redirect in the theme.
 */
function go_verge_news_sitemap_early_router() {
	if ( is_admin() || wp_doing_ajax() ) {
		return;
	}
	if ( ! go_verge_news_sitemap_theme_owns_endpoint() || ! go_verge_news_sitemap_is_request() ) {
		return;
	}
	go_verge_news_sitemap_send();
}
add_action( 'wp_loaded', 'go_verge_news_sitemap_early_router', -1000 );

/** template_redirect is only a second fail-safe for unusual stacks. */
function go_verge_news_sitemap_render() {
	if ( is_admin() || wp_doing_ajax() ) {
		return;
	}
	if ( ! go_verge_news_sitemap_theme_owns_endpoint() || ! go_verge_news_sitemap_is_request() ) {
		return;
	}
	go_verge_news_sitemap_send();
}
add_action( 'template_redirect', 'go_verge_news_sitemap_render', -2000 );

/**
 * Site Health: the declared News sitemap must answer XML, not a page.
 *
 * A sitemap can only fail in production, and it fails silently: robots.txt keeps
 * advertising the URL, /sitemap.xml keeps listing it, and the newsroom sees
 * nothing. Only a request can tell, so this test is async and never runs during
 * a page view. It is the guardrail for the redirect-ordering defect fixed in
 * 3.68.0 — see go_verge_news_sitemap_early_router().
 *
 * @return array Site Health result.
 */
function go_verge_news_sitemap_delivery_health_test() {
	$badge = array( 'label' => __( 'Search', 'go-verge' ), 'color' => 'blue' );
	$url   = home_url( '/news-sitemap.xml' );

	if ( ! go_verge_news_sitemap_theme_owns_endpoint() ) {
		return array(
			'label'       => __( 'O sitemap de notícias é servido por outro componente', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html__( 'O tema não reivindica /news-sitemap.xml nesta instalação.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_news_sitemap_delivery',
		);
	}

	/* redirection => 0 so a 301 stays visible instead of being followed into a
	 * page that would answer 200 and hide the defect. */
	$response = wp_safe_remote_get(
		$url,
		array(
			'timeout'            => 8,
			'redirection'        => 0,
			'reject_unsafe_urls' => true,
			'user-agent'         => 'Overdrive Site Health/' . GO_VERGE_VERSION,
		)
	);

	if ( is_wp_error( $response ) ) {
		return array(
			'label'       => __( 'Não foi possível verificar o sitemap de notícias', 'go-verge' ),
			'status'      => 'recommended',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: %s: transport error message. */
					__( 'A verificação falhou: %s. Repita mais tarde ou abra a URL manualmente.', 'go-verge' ),
					$response->get_error_message()
				)
			) . '</p>',
			'test'        => 'go_verge_news_sitemap_delivery',
		);
	}

	$status   = (int) wp_remote_retrieve_response_code( $response );
	$type     = strtolower( trim( (string) strtok( (string) wp_remote_retrieve_header( $response, 'content-type' ), ';' ) ) );
	$location = (string) wp_remote_retrieve_header( $response, 'location' );
	$body     = ltrim( (string) wp_remote_retrieve_body( $response ) );
	$is_xml   = 200 === $status
		&& false !== strpos( $type, 'xml' )
		&& 0 === strpos( $body, '<?xml' )
		&& false !== strpos( $body, '<urlset' );

	if ( $is_xml ) {
		return array(
			'label'       => __( 'O sitemap de notícias responde XML', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: 1: sitemap URL, 2: Content-Type header value. */
					__( '%1$s responde HTTP 200 com Content-Type: %2$s e um <urlset> válido.', 'go-verge' ),
					$url,
					$type
				)
			) . '</p>',
			'test'        => 'go_verge_news_sitemap_delivery',
		);
	}

	/* WAF/CDN rules may deny a request from the origin back to its own public
	 * hostname. Validate the generator locally before calling that a broken News
	 * sitemap; a 403 self-loop is not evidence that Google receives a 403. */
	if ( in_array( $status, array( 401, 403, 429 ), true ) ) {
		$local = function_exists( 'go_verge_news_sitemap_build' ) ? (string) go_verge_news_sitemap_build() : '';
		$local_ok = '' !== $local
			&& 0 === strpos( ltrim( $local ), '<?xml' )
			&& false !== strpos( $local, '<urlset' )
			&& false !== strpos( $local, 'sitemap-news/0.9' )
			&& false === stripos( $local, '<html' );
		if ( $local_ok ) {
			return array(
				'label'       => __( 'Gerador News XML íntegro; self-loop bloqueado pela borda', 'go-verge' ),
				'status'      => 'recommended',
				'badge'       => $badge,
				'description' => '<p>' . esc_html( sprintf( __( 'O teste servidor→próprio domínio recebeu HTTP %1$d, mas o gerador local produziu um <urlset> Google News válido (%2$s). Confirme a borda externa/Search Console; o 403 de loopback não é tratado como status público.', 'go-verge' ), $status, size_format( strlen( $local ) ) ) ) . '</p>',
				'test'        => 'go_verge_news_sitemap_delivery',
			);
		}
	}

	$detail = '' !== $location
		? sprintf(
			/* translators: 1: HTTP status, 2: redirect target. */
			__( 'A URL responde HTTP %1$d e redireciona para %2$s.', 'go-verge' ),
			$status,
			$location
		)
		: sprintf(
			/* translators: 1: HTTP status, 2: Content-Type header value. */
			__( 'A URL responde HTTP %1$d com Content-Type: %2$s.', 'go-verge' ),
			$status,
			'' !== $type ? $type : __( '(vazio)', 'go-verge' )
		);

	return array(
		'label'       => __( 'O sitemap de notícias não está sendo entregue como XML', 'go-verge' ),
		'status'      => 'critical',
		'badge'       => $badge,
		'description' => '<p>' . esc_html( sprintf( '%s — %s', $url, $detail ) ) . '</p>'
			. '<p>' . esc_html__( 'O robots.txt e o /sitemap.xml anunciam essa URL ao Google News. Enquanto ela não devolver XML, o Google não consome sitemap de notícias nenhum. Causa mais comum: outro redirecionamento reivindica a URL antes do roteador do tema; confira também as regras de reescrita em Configurações > Links permanentes.', 'go-verge' ) . '</p>',
		'test'        => 'go_verge_news_sitemap_delivery',
	);
}

/** Register the delivery check. */
function go_verge_news_sitemap_register_health( $tests ) {
	$tests['async']['go_verge_news_sitemap_delivery'] = array(
		'label'             => __( 'Entrega do sitemap de notícias', 'go-verge' ),
		'test'              => 'go_verge_news_sitemap_delivery_health_test',
		'has_rest'          => false,
		'async_direct_test' => 'go_verge_news_sitemap_delivery_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_news_sitemap_register_health' );

/**
 * Build the Google News XML sitemap.
 *
 * @return string
 */
function go_verge_news_sitemap_build() {
	$publication = go_verge_news_sitemap_publication_name();
	$language    = go_verge_news_sitemap_language();
	$query       = new WP_Query( go_verge_news_sitemap_query_args() );
	$first_query = new WP_Query( go_verge_news_sitemap_query_args( true ) );
	$posts       = array();
	foreach ( array_merge( $query->posts, $first_query->posts ) as $candidate ) {
		if ( $candidate instanceof WP_Post ) { $posts[ (int) $candidate->ID ] = $candidate; }
	}
	usort( $posts, static function ( $left, $right ) {
		$time_for = static function ( $post ) {
			return function_exists( 'go_verge_search_published_timestamp' )
				? (int) go_verge_search_published_timestamp( $post->ID )
				: (int) get_post_time( 'U', true, $post->ID );
		};
		return $time_for( $right ) <=> $time_for( $left );
	} );

	$lines   = array();
	$lines[] = '<?xml version="1.0" encoding="UTF-8"?>';
	$lines[] = '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:news="http://www.google.com/schemas/sitemap-news/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">';

	$included = 0;
	foreach ( $posts as $post ) {
		if ( $included >= 1000 ) { break; }
		$post_id = (int) $post->ID;
		if ( ! go_verge_news_sitemap_post_is_eligible( $post_id ) ) {
			continue;
		}

		$title     = go_verge_news_sitemap_document_title( $post_id );
		$loc       = get_permalink( $post_id );
		$date      = function_exists( 'go_verge_search_published_iso' )
			? go_verge_search_published_iso( $post_id )
			: get_post_time( DATE_W3C, true, $post_id );
		$modified  = function_exists( 'go_verge_search_consistent_modified_iso' )
			? go_verge_search_consistent_modified_iso( $post_id )
			: ( function_exists( 'go_verge_search_modified_iso' )
				? go_verge_search_modified_iso( $post_id )
				: get_post_modified_time( DATE_W3C, true, $post_id ) );
		$modified  = go_verge_news_sitemap_consistent_lastmod_iso( $date, $modified );
		$image     = go_verge_news_sitemap_image_url( $post_id );

		if ( '' === $title || ! $loc || ! $date ) {
			continue;
		}

		$lines[] = '  <url>';
		$lines[] = '    <loc>' . esc_url( $loc ) . '</loc>';
		if ( $modified ) {
			$lines[] = '    <lastmod>' . esc_html( $modified ) . '</lastmod>';
		}
		if ( $image ) {
			$lines[] = '    <image:image>';
			$lines[] = '      <image:loc>' . esc_url( $image ) . '</image:loc>';
			$lines[] = '    </image:image>';
		}
		$lines[] = '    <news:news>';
		$lines[] = '      <news:publication>';
		$lines[] = '        <news:name>' . esc_html( $publication ) . '</news:name>';
		$lines[] = '        <news:language>' . esc_html( $language ) . '</news:language>';
		$lines[] = '      </news:publication>';
		$lines[] = '      <news:publication_date>' . esc_html( $date ) . '</news:publication_date>';
		$lines[] = '      <news:title>' . esc_html( $title ) . '</news:title>';
		$lines[] = '    </news:news>';
		$lines[] = '  </url>';
		++$included;
	}

	wp_reset_postdata();
	$lines[] = '</urlset>';

	return implode( "\n", $lines ) . "\n";
}

/* /sitemap.xml is the only general sitemap index. The News endpoint is linked
 * there directly; it is intentionally not injected into Rank Math's retired
 * /sitemap_index.xml surface. */
