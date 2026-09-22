<?php
/**
 * Discover Health: production contract for Google Discover / News readiness.
 *
 * This module does not try to "optimize for an algorithm". It verifies the
 * technical promises the newsroom controls: crawlability, canonical delivery,
 * preview permissions, representative images, Article schema, News sitemap,
 * public cache integrity and WP-Cron continuity.
 *
 * Expensive checks run only in wp-admin/Site Health or from one hourly cron
 * event. Anonymous front-end requests pay only for the tiny cron-schedule guard.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_DISCOVER_HEALTH_TRANSIENT' ) ) {
	define( 'GO_VERGE_DISCOVER_HEALTH_TRANSIENT', 'go_verge_discover_health_report_v7' );
}
if ( ! defined( 'GO_VERGE_DISCOVER_HEALTH_OPTION' ) ) {
	define( 'GO_VERGE_DISCOVER_HEALTH_OPTION', 'go_verge_discover_health_last_report_v7' );
}

/** Normalize a URL for same-document canonical comparisons. */
function go_verge_discover_health_normalize_url( $url ) {
	$url = trim( (string) $url );
	if ( '' === $url ) {
		return '';
	}
	$parts = wp_parse_url( $url );
	if ( ! is_array( $parts ) || empty( $parts['host'] ) ) {
		return untrailingslashit( $url );
	}
	$scheme = strtolower( (string) ( $parts['scheme'] ?? 'https' ) );
	$host   = strtolower( (string) $parts['host'] );
	$port   = isset( $parts['port'] ) ? ':' . absint( $parts['port'] ) : '';
	$path   = '/' . ltrim( (string) ( $parts['path'] ?? '/' ), '/' );
	$path   = '/' === $path ? '/' : trailingslashit( $path );
	$query  = ! empty( $parts['query'] ) ? '?' . $parts['query'] : '';
	return $scheme . '://' . $host . $port . $path . $query;
}

/**
 * Perform one real public HTTP request and keep only diagnostic-safe fields.
 *
 * Redirection is deliberately disabled: a sitemap/article that unexpectedly
 * becomes a 301 must fail loudly instead of looking healthy after following it.
 *
 * @param string $url_or_path Absolute URL or site-root-relative path.
 * @param string $user_agent  Optional UA.
 * @return array<string,mixed>
 */
function go_verge_discover_health_fetch( $url_or_path, $user_agent = '' ) {
	$url = preg_match( '#^https?://#i', (string) $url_or_path )
		? (string) $url_or_path
		: home_url( '/' . ltrim( (string) $url_or_path, '/' ) );

	$headers = array( 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' );
	if ( '' !== $user_agent ) {
		$headers['User-Agent'] = $user_agent;
	}

	$started  = microtime( true );
	$response = wp_safe_remote_get(
		$url,
		array(
			'timeout'             => 8,
			'redirection'         => 0,
			'headers'             => $headers,
			'limit_response_size' => 1024 * 1024,
		)
	);
	$elapsed = (int) round( ( microtime( true ) - $started ) * 1000 );

	if ( is_wp_error( $response ) ) {
		return array(
			'url'               => $url,
			'code'              => 0,
			'type'              => '',
			'body'              => '',
			'ms'                => $elapsed,
			'error'             => $response->get_error_message(),
			'location'          => '',
			'xrobots'           => '',
			'cache_control'     => '',
			'set_cookie'        => '',
			'cookie_names'      => array(),
			'x_litespeed_cache' => '',
			'x_hcdn_cache'      => '',
		);
	}

	$header_value = static function ( $name ) use ( $response ) {
		$value = wp_remote_retrieve_header( $response, $name );
		if ( is_array( $value ) ) {
			return implode( ', ', array_map( 'strval', $value ) );
		}
		return (string) $value;
	};

	$cookie_names = array();
	foreach ( (array) wp_remote_retrieve_cookies( $response ) as $cookie ) {
		if ( is_object( $cookie ) && isset( $cookie->name ) ) {
			$cookie_names[] = (string) $cookie->name;
		}
	}

	return array(
		'url'               => $url,
		'code'              => (int) wp_remote_retrieve_response_code( $response ),
		'type'              => strtolower( $header_value( 'content-type' ) ),
		'body'              => (string) wp_remote_retrieve_body( $response ),
		'ms'                => $elapsed,
		'error'             => '',
		'location'          => $header_value( 'location' ),
		'xrobots'           => strtolower( $header_value( 'x-robots-tag' ) ),
		'cache_control'     => strtolower( $header_value( 'cache-control' ) ),
		'set_cookie'        => $header_value( 'set-cookie' ),
		'cookie_names'      => array_values( array_unique( $cookie_names ) ),
		'x_litespeed_cache' => strtolower( $header_value( 'x-litespeed-cache' ) ),
		'x_hcdn_cache'      => strtolower( $header_value( 'x-hcdn-cache-status' ) ),
	);
}

/**
 * Self-requests can be denied by WAF/CDN rules even when the public endpoint is
 * healthy for browsers and crawlers. Treat these codes as a blocked loopback,
 * not proof that the public resource itself is broken.
 */
function go_verge_discover_health_loopback_blocked( $probe ) {
	$code = is_array( $probe ) ? (int) ( $probe['code'] ?? 0 ) : 0;
	return in_array( $code, array( 401, 403, 429 ), true );
}

/**
 * A transport failure (HTTP 0) is also inconclusive: it describes the
 * WordPress server trying to call itself, not what an external crawler sees.
 */
function go_verge_discover_health_loopback_inconclusive( $probe ) {
	$code = is_array( $probe ) ? (int) ( $probe['code'] ?? 0 ) : 0;
	return 0 === $code || go_verge_discover_health_loopback_blocked( $probe );
}

/**
 * Evaluate the inspector's ASCII root/asset probes for one Google crawler.
 * This is a diagnostic, not a replacement for Google's URL Inspection: honor
 * agent groups, comments, repeated groups and Allow precedence instead of
 * treating a rule intended for an unrelated bot as a global site block.
 */
function go_verge_discover_health_robots_allows( $body, $path, $crawler = 'googlebot' ) {
	$groups = array();
	$group = array( 'agents' => array(), 'rules' => array() );
	foreach ( preg_split( '/\r\n|\r|\n/', ltrim( (string) $body, "\xEF\xBB\xBF" ) ) as $line ) {
		$line = trim( preg_replace( '/#.*/', '', $line ) );
		if ( ! preg_match( '/^([a-z-]+)\s*:\s*(.*)$/i', $line, $m ) ) { continue; }
		$field = strtolower( $m[1] );
		$value = trim( $m[2] );
		if ( 'user-agent' === $field ) {
			if ( $group['rules'] ) { $groups[] = $group; $group = array( 'agents' => array(), 'rules' => array() ); }
			if ( '' !== $value ) { $group['agents'][] = strtolower( $value ); }
		} elseif ( in_array( $field, array( 'allow', 'disallow' ), true ) && $group['agents'] ) {
			$group['rules'][] = array( $field, $value );
		}
	}
	if ( $group['agents'] ) { $groups[] = $group; }
	$best_group = -1;
	$rules = array();
	foreach ( $groups as $candidate ) {
		$score = -1;
		foreach ( $candidate['agents'] as $agent ) {
			if ( '*' === $agent ) { $score = max( $score, 0 ); continue; }
			$agent = preg_replace( '#[/*].*$#', '', $agent );
			if ( '' !== $agent && 0 === stripos( $crawler, $agent ) ) { $score = max( $score, strlen( $agent ) ); }
		}
		if ( $score < 0 || $score < $best_group ) { continue; }
		if ( $score > $best_group ) { $best_group = $score; $rules = array(); }
		$rules = array_merge( $rules, $candidate['rules'] );
	}
	$longest = -1;
	$allowed = true;
	foreach ( $rules as $rule ) {
		$pattern = $rule[1];
		if ( '' === $pattern || '/' !== $pattern[0] ) { continue; }
		$at_end = '$' === substr( $pattern, -1 );
		$raw = $at_end ? substr( $pattern, 0, -1 ) : $pattern;
		$regex = '~^' . str_replace( '\\*', '.*', preg_quote( $raw, '~' ) ) . ( $at_end ? '$' : '' ) . '~';
		if ( ! preg_match( $regex, (string) $path ) ) { continue; }
		$length = strlen( str_replace( '*', '', $pattern ) );
		if ( $length > $longest || ( $length === $longest && 'allow' === $rule[0] ) ) {
			$longest = $length;
			$allowed = 'allow' === $rule[0];
		}
	}
	return $allowed;
}

/** Analyze declared sitemap URLs and representative crawl paths, without HTTP. */
function go_verge_discover_health_analyze_robots_body( $body, $source = 'robots.txt' ) {
	$body     = (string) $body;
	$issues   = array();
	$critical = false;

	if ( ! go_verge_discover_health_robots_allows( $body, '/' ) ) {
		$critical = true;
		$issues[] = 'Googlebot bloqueado no caminho /';
	}
	$declared = array();
	if ( preg_match_all( '#^\s*sitemap\s*:\s*([^\s\#]+)#mi', $body, $matches ) ) { $declared = $matches[1]; }
	foreach ( array( '/sitemap.xml', '/sitemap-fresh.xml', '/news-sitemap.xml' ) as $sitemap ) {
		if ( ! in_array( home_url( $sitemap ), $declared, true ) ) { $issues[] = 'não anuncia ' . $sitemap; }
	}
	foreach ( array( '/wp-content/uploads/', '/wp-content/themes/', '/wp-content/plugins/' ) as $asset ) {
		if ( ! go_verge_discover_health_robots_allows( $body, $asset ) ) { $issues[] = 'Googlebot bloqueado em ' . $asset; }
	}

	return array(
		'ok'       => ! $critical,
		'critical' => $critical,
		'issues'   => $issues,
		'body'     => $body,
		'detail'   => $source . ( $issues ? ' · ' . implode( '; ', $issues ) : ' · sem bloqueio nos caminhos amostrados; sitemaps anunciados' ),
	);
}

/** Build/inspect the robots contract locally when the server cannot self-fetch it. */
function go_verge_discover_health_local_robots_contract() {
	$physical = trailingslashit( ABSPATH ) . 'robots.txt';
	$source   = 'virtual WordPress';
	$body     = '';

	if ( is_readable( $physical ) && is_file( $physical ) ) {
		$body   = (string) file_get_contents( $physical );
		$source = 'arquivo físico';
	} else {
		$public = (string) get_option( 'blog_public', '1' );
		$path   = (string) wp_parse_url( site_url( '/' ), PHP_URL_PATH );
		$path   = '/' . trim( $path, '/' );
		$path   = '/' === $path ? '' : $path;
		$body   = "User-agent: *\n";
		if ( '0' === $public ) {
			$body .= "Disallow: /\n";
		} else {
			$body .= 'Disallow: ' . $path . "/wp-admin/\n";
			$body .= 'Allow: ' . $path . "/wp-admin/admin-ajax.php\n";
		}
		$body = (string) apply_filters( 'robots_txt', $body, $public );
	}

	return go_verge_discover_health_analyze_robots_body( $body, $source );
}

/** Validate the theme's sitemap generator without crossing the WAF/CDN. */
function go_verge_discover_health_local_sitemap_contract( $kind ) {
	$xml = '';
	if ( 'index' === $kind && function_exists( 'go_verge_smart_sitemap_build_index' ) ) {
		$xml = (string) go_verge_smart_sitemap_build_index();
	} elseif ( 'news' === $kind && function_exists( 'go_verge_news_sitemap_build' ) ) {
		$xml = (string) go_verge_news_sitemap_build();
	}

	if ( '' === $xml ) {
		return array( 'ok' => false, 'xml' => '', 'detail' => 'gerador local indisponível' );
	}

	$ok = 'index' === $kind
		? (bool) preg_match( '#^\s*<\?xml[^>]*>\s*<sitemapindex\b#i', $xml )
		: (bool) ( preg_match( '#^\s*<\?xml[^>]*>\s*<urlset\b#i', $xml ) && false !== strpos( $xml, 'sitemap-news/0.9' ) && false === stripos( $xml, '<html' ) );

	return array(
		'ok'     => $ok,
		'xml'    => $xml,
		'detail' => $ok ? sprintf( 'gerador local íntegro · %s', size_format( strlen( $xml ) ) ) : 'gerador local produziu XML fora do contrato',
	);
}

/** Extract one meta content value regardless of attribute order. */
function go_verge_discover_health_meta_content( $html, $key ) {
	$key = preg_quote( (string) $key, '#' );
	if ( preg_match( '#<meta\b(?=[^>]*(?:name|property)=["\']' . $key . '["\'])(?=[^>]*content=["\']([^"\']*)["\'])[^>]*>#i', (string) $html, $m ) ) {
		return html_entity_decode( trim( (string) $m[1] ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
	}
	return '';
}

/** Extract canonical URL regardless of link attribute order. */
function go_verge_discover_health_canonical_from_html( $html ) {
	if ( preg_match( '#<link\b(?=[^>]*rel=["\'][^"\']*canonical[^"\']*["\'])(?=[^>]*href=["\']([^"\']+)["\'])[^>]*>#i', (string) $html, $m ) ) {
		return html_entity_decode( trim( (string) $m[1] ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
	}
	return '';
}

/** Count top-level Article nodes that claim the same public URL. */
function go_verge_discover_health_article_node_count( $html, $permalink ) {
	$canonical = go_verge_discover_health_normalize_url( $permalink );
	$count     = 0;
	if ( '' === $canonical || ! preg_match_all( '#<script\b[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>#is', (string) $html, $scripts ) ) {
		return 0;
	}
	foreach ( $scripts[1] as $raw ) {
		$data = json_decode( trim( html_entity_decode( $raw, ENT_QUOTES | ENT_HTML5, 'UTF-8' ) ), true );
		if ( ! is_array( $data ) ) { continue; }
		$nodes = isset( $data['@graph'] ) && is_array( $data['@graph'] ) ? $data['@graph'] : array( $data );
		foreach ( $nodes as $node ) {
			if ( ! is_array( $node ) ) { continue; }
			$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
			if ( ! array_intersect( array( 'Article', 'NewsArticle', 'BlogPosting' ), $types ) ) { continue; }
			$url = go_verge_discover_health_normalize_url( (string) ( $node['url'] ?? '' ) );
			$id  = go_verge_discover_health_normalize_url( preg_replace( '/#.*$/', '', (string) ( $node['@id'] ?? '' ) ) );
			if ( $canonical === $url || $canonical === $id ) { ++$count; }
		}
	}
	return $count;
}

/** Append a standardized health item. */
function go_verge_discover_health_item( &$items, $level, $label, $detail = '', $url = '' ) {
	$level = in_array( $level, array( 'good', 'warning', 'critical' ), true ) ? $level : 'warning';
	$items[] = array(
		'level'  => $level,
		'label'  => (string) $label,
		'detail' => (string) $detail,
		'url'    => esc_url_raw( (string) $url ),
	);
}

/** Latest published post ID. */
function go_verge_discover_health_latest_post_id() {
	$ids = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => 1,
			'fields'                 => 'ids',
			'orderby'                => 'date',
			'order'                  => 'DESC',
			'ignore_sticky_posts'    => true,
			'no_found_rows'          => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		)
	);
	return ! empty( $ids[0] ) ? absint( $ids[0] ) : 0;
}

/** Newest eligible NewsArticle still inside Google's two-day News window. */
function go_verge_discover_health_recent_news_post_id() {
	$ids = get_posts(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 80,
			'fields'              => 'ids',
			'orderby'             => 'date',
			'order'               => 'DESC',
			'ignore_sticky_posts' => true,
			'date_query'          => array(
				array(
					'after'     => wp_date( 'Y-m-d H:i:s', time() - ( 2 * DAY_IN_SECONDS ) ),
					'inclusive' => true,
					'column'    => 'post_date',
				),
			),
		)
	);
	foreach ( (array) $ids as $post_id ) {
		$post_id = absint( $post_id );
		if ( function_exists( 'go_verge_news_sitemap_post_is_eligible' ) ) {
			if ( go_verge_news_sitemap_post_is_eligible( $post_id ) ) {
				return $post_id;
			}
		} elseif ( function_exists( 'go_verge_post_is_news_article' ) && go_verge_post_is_news_article( $post_id ) ) {
			return $post_id;
		}
	}
	return 0;
}

/** Match the active SEO provider; inactive migration metadata is not a veto. */
function go_verge_discover_health_post_has_noindex( $post_id ) {
	if ( function_exists( 'go_verge_smart_sitemap_noindex' ) ) {
		return (bool) go_verge_smart_sitemap_noindex( $post_id );
	}
	/* Standalone-module fallback preserves the conservative historical behavior.
	 * In the complete theme the shared sitemap contract above is always present. */
	foreach ( array( 'rank_math_robots', '_rank_math_robots' ) as $key ) {
		if ( false !== stripos( wp_json_encode( get_post_meta( $post_id, $key, true ) ), 'noindex' ) ) { return true; }
	}
	return '1' === trim( (string) get_post_meta( $post_id, '_yoast_wpseo_meta-robots-noindex', true ) );
}

/** Measure recent editorial image hygiene without making network requests. */
function go_verge_discover_health_recent_sample( $limit = 20 ) {
	$ids = get_posts(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => max( 1, min( 50, absint( $limit ) ) ),
			'fields'              => 'ids',
			'orderby'             => 'date',
			'order'               => 'DESC',
			'ignore_sticky_posts' => true,
		)
	);

	$out = array(
		'total'            => count( $ids ),
		'no_image'         => 0,
		'under_1200'       => 0,
		'under_300k'       => 0,
		'portrait'         => 0,
		'no_category'      => 0,
		'invalid_author'   => 0,
		'custom_noindex'   => 0,
		'news_last_48h'    => 0,
		'news_with_image'  => 0,
	);

	foreach ( (array) $ids as $post_id ) {
		$post_id = absint( $post_id );
		$post    = get_post( $post_id );
		if ( ! ( $post instanceof WP_Post ) ) {
			continue;
		}

		if ( ! get_userdata( (int) $post->post_author ) ) {
			$out['invalid_author']++;
		}
		$category_ids = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'ids' ) );
		if ( is_wp_error( $category_ids ) || empty( $category_ids ) ) {
			$out['no_category']++;
		}

		$image_id = get_post_thumbnail_id( $post_id );
		if ( ! $image_id ) {
			$out['no_image']++;
		} else {
			$meta   = wp_get_attachment_metadata( $image_id );
			$width  = is_array( $meta ) ? absint( $meta['width'] ?? 0 ) : 0;
			$height = is_array( $meta ) ? absint( $meta['height'] ?? 0 ) : 0;
			if ( $width && $width < 1200 ) {
				$out['under_1200']++;
			}
			if ( $width && $height && ( $width * $height ) < 300000 ) {
				$out['under_300k']++;
			}
			if ( $width && $height && $height > $width ) {
				$out['portrait']++;
			}
		}

		if ( go_verge_discover_health_post_has_noindex( $post_id ) ) {
			$out['custom_noindex']++;
		}

		$published = get_post_time( 'U', true, $post_id );
		$is_news   = function_exists( 'go_verge_post_is_news_article' ) && go_verge_post_is_news_article( $post_id );
		if ( $is_news && $published && ( time() - $published ) <= ( 2 * DAY_IN_SECONDS ) ) {
			$out['news_last_48h']++;
			if ( $image_id ) {
				$out['news_with_image']++;
			}
		}
	}

	return $out;
}

/** Probe WP-Cron's public transport; cached because this deliberately loops back. */
function go_verge_discover_health_cron_transport_probe() {
	$cached = get_transient( 'go_verge_discover_cron_transport_v2' );
	if ( is_array( $cached ) ) {
		return $cached;
	}

	$url = site_url( '/wp-cron.php?doing_wp_cron=' . rawurlencode( sprintf( '%.22F', microtime( true ) ) ) );
	$started = microtime( true );
	$response = wp_safe_remote_post(
		$url,
		array(
			'timeout'     => 8,
			'redirection' => 0,
			'blocking'    => true,
			'body'        => array(),
			'headers'     => array( 'User-Agent' => 'Overdrive-Discover-Health/1.0' ),
		)
	);
	$result = array( 'code' => 0, 'ms' => (int) round( ( microtime( true ) - $started ) * 1000 ), 'error' => '' );
	if ( is_wp_error( $response ) ) {
		$result['error'] = $response->get_error_message();
	} else {
		$result['code'] = (int) wp_remote_retrieve_response_code( $response );
	}
	set_transient( 'go_verge_discover_cron_transport_v2', $result, 15 * MINUTE_IN_SECONDS );
	return $result;
}

/** Schedule a heartbeat that proves scheduled work is actually executing. */
function go_verge_discover_health_schedule() {
	if ( ! wp_next_scheduled( 'go_verge_discover_health_heartbeat' ) ) {
		wp_schedule_event( time() + MINUTE_IN_SECONDS, 'hourly', 'go_verge_discover_health_heartbeat' );
	}
}
add_action( 'admin_init', 'go_verge_discover_health_schedule', 20 );
add_action( 'after_switch_theme', 'go_verge_discover_health_schedule', 20, 0 );

/** Hourly heartbeat and background contract snapshot. */
function go_verge_discover_health_heartbeat() {
	update_option( 'go_verge_discover_health_last_cron', time(), false );
	delete_transient( GO_VERGE_DISCOVER_HEALTH_TRANSIENT );
	/* Never self-probe wp-cron from inside wp-cron. */
	$report = go_verge_discover_health_collect( true, true );
	update_option( GO_VERGE_DISCOVER_HEALTH_OPTION, $report, false );
}
add_action( 'go_verge_discover_health_heartbeat', 'go_verge_discover_health_heartbeat' );

/**
 * Build the complete Discover readiness report.
 *
 * @param bool $force               Ignore cached report.
 * @param bool $skip_cron_transport Avoid recursively calling wp-cron from cron.
 * @return array<string,mixed>
 */
function go_verge_discover_health_collect( $force = false, $skip_cron_transport = false ) {
	if ( ! $force ) {
		$cached = get_transient( GO_VERGE_DISCOVER_HEALTH_TRANSIENT );
		if ( is_array( $cached ) ) {
			return $cached;
		}
	}

	$items = array();

	/* 1) Discovery files ---------------------------------------------------- */
	$robots = go_verge_discover_health_fetch( '/robots.txt' );
	if ( 200 !== $robots['code'] || false === strpos( $robots['type'], 'text/plain' ) ) {
		$local_robots = go_verge_discover_health_local_robots_contract();
		if ( go_verge_discover_health_loopback_inconclusive( $robots ) && ! empty( $local_robots['ok'] ) ) {
			go_verge_discover_health_item(
				$items,
				'warning',
				'robots.txt: self-request inconclusivo, contrato local verificável',
				sprintf( 'Loopback HTTP %d · %s. Isso não prova falha pública. %s; confirme externamente/Search Console.', $robots['code'], $robots['error'] ?: ( $robots['type'] ?: 'sem content-type' ), $local_robots['detail'] ),
				$robots['url']
			);
		} else {
			$detail = $robots['error'] ?: sprintf( 'HTTP %d · %s', $robots['code'], $robots['type'] );
			$detail .= ' · ' . $local_robots['detail'];
			go_verge_discover_health_item( $items, 'critical', 'robots.txt não está sendo servido como texto 200', $detail, $robots['url'] );
		}
	} else {
		$public_robots = go_verge_discover_health_analyze_robots_body( $robots['body'], 'resposta pública' );
		$robot_issues  = $public_robots['issues'];
		$robot_level   = ! empty( $public_robots['critical'] ) ? 'critical' : ( $robot_issues ? 'warning' : 'good' );
		go_verge_discover_health_item(
			$items,
			$robot_level,
			'critical' === $robot_level ? 'robots.txt bloqueia rastreamento público' : ( $robot_issues ? 'robots.txt tem divergências de descoberta' : 'robots.txt está alinhado' ),
			$robot_issues ? implode( '; ', $robot_issues ) : sprintf( 'HTTP 200 text/plain · %d ms', $robots['ms'] ),
			$robots['url']
		);
	}

	$sitemap = go_verge_discover_health_fetch( '/sitemap.xml' );
	$sitemap_ok = 200 === $sitemap['code']
		&& false !== strpos( $sitemap['type'], 'xml' )
		&& preg_match( '#<sitemapindex\b#i', $sitemap['body'] );
	if ( ! $sitemap_ok ) {
		$local = go_verge_discover_health_local_sitemap_contract( 'index' );
		if ( go_verge_discover_health_loopback_inconclusive( $sitemap ) && ! empty( $local['ok'] ) ) {
			go_verge_discover_health_item(
				$items,
				'warning',
				'sitemap.xml: self-request inconclusivo, gerador local íntegro',
				sprintf( 'Loopback HTTP %d · %s. Isso não é tratado como falha pública. %s; confirme a borda externa/Search Console.', $sitemap['code'], $sitemap['type'] ?: 'content-type vazio', $local['detail'] ),
				$sitemap['url']
			);
		} else {
			$detail = $sitemap['error'] ?: sprintf( 'HTTP %d · %s · redirect %s', $sitemap['code'], $sitemap['type'], $sitemap['location'] ?: '—' );
			if ( ! empty( $local['detail'] ) ) {
				$detail .= ' · ' . $local['detail'];
			}
			go_verge_discover_health_item( $items, 'critical', 'sitemap.xml falhou no contrato XML', $detail, $sitemap['url'] );
		}
	} else {
		$issues = array();
		if ( false === strpos( $sitemap['body'], home_url( '/news-sitemap.xml' ) ) ) {
			$issues[] = 'não lista news-sitemap.xml';
		}
		if ( false !== strpos( $sitemap['body'], '/sitemap-tags.xml' ) ) {
			$issues[] = 'ainda lista sitemap de tags';
		}
		go_verge_discover_health_item( $items, $issues ? 'warning' : 'good', $issues ? 'sitemap.xml tem divergências' : 'sitemap.xml responde como índice XML', $issues ? implode( '; ', $issues ) : sprintf( '%d ms', $sitemap['ms'] ), $sitemap['url'] );
	}

	$news = go_verge_discover_health_fetch( '/news-sitemap.xml' );
	$news_ok = 200 === $news['code']
		&& false !== strpos( $news['type'], 'xml' )
		&& preg_match( '#<urlset\b#i', $news['body'] )
		&& false !== strpos( $news['body'], 'sitemap-news/0.9' )
		&& false === stripos( $news['body'], '<html' );
	if ( ! $news_ok ) {
		$local = go_verge_discover_health_local_sitemap_contract( 'news' );
		if ( go_verge_discover_health_loopback_inconclusive( $news ) && ! empty( $local['ok'] ) ) {
			$recent_news = go_verge_discover_health_recent_news_post_id();
			$recent_ok   = ! $recent_news || ( get_permalink( $recent_news ) && false !== strpos( html_entity_decode( $local['xml'], ENT_QUOTES | ENT_HTML5, 'UTF-8' ), get_permalink( $recent_news ) ) );
			go_verge_discover_health_item(
				$items,
				$recent_ok ? 'warning' : 'critical',
				$recent_ok ? 'news-sitemap.xml: self-request inconclusivo, News XML local íntegro' : 'News XML local não contém a matéria elegível mais recente',
				$recent_ok ? sprintf( 'Loopback HTTP %d · %s. Isso não é tratado como falha pública. %s; confirme a borda externa/Search Console.', $news['code'], $news['type'] ?: 'content-type vazio', $local['detail'] ) : 'O gerador local foi executado sem cruzar o WAF e ainda assim a URL elegível mais recente não apareceu.',
				$news['url']
			);
		} else {
			$detail = $news['error'] ?: sprintf( 'HTTP %d · %s · redirect %s', $news['code'], $news['type'], $news['location'] ?: '—' );
			if ( ! empty( $local['detail'] ) ) {
				$detail .= ' · ' . $local['detail'];
			}
			go_verge_discover_health_item( $items, 'critical', 'news-sitemap.xml falhou no contrato Google News', $detail, $news['url'] );
		}
	} else {
		$recent_news = go_verge_discover_health_recent_news_post_id();
		$detail      = sprintf( 'HTTP 200 XML · %d ms', $news['ms'] );
		$level       = 'good';
		if ( $recent_news ) {
			$news_url = get_permalink( $recent_news );
			if ( $news_url && false === strpos( html_entity_decode( $news['body'], ENT_QUOTES | ENT_HTML5, 'UTF-8' ), $news_url ) ) {
				$level  = 'critical';
				$detail = 'Há NewsArticle elegível nas últimas 48h, mas a URL mais recente não aparece no XML.';
			}
		} else {
			$detail .= ' · nenhuma NewsArticle elegível encontrada nas últimas 48h (XML vazio é válido).';
		}
		go_verge_discover_health_item( $items, $level, 'news-sitemap.xml responde como News XML', $detail, $news['url'] );
	}

	/* Warn about hidden dual ownership even though the theme wins the endpoint. */
	if ( function_exists( 'go_verge_news_sitemap_rank_math_news_active' ) && go_verge_news_sitemap_rank_math_news_active() ) {
		go_verge_discover_health_item( $items, 'warning', 'Há dois provedores configurados para News sitemap', 'O tema é o dono efetivo de /news-sitemap.xml, mas o módulo News Sitemap do Rank Math PRO parece ativo. Desative o módulo secundário para eliminar configuração concorrente.' );
	}

	/* 2) Representative live article -------------------------------------- */
	$live_cache_probe = array();
	$post_id          = go_verge_discover_health_latest_post_id();
	if ( ! $post_id ) {
		go_verge_discover_health_item( $items, 'warning', 'Nenhuma matéria publicada disponível para teste', 'O contrato de single não pôde ser validado.' );
	} else {
		$permalink = get_permalink( $post_id );
		$normal    = go_verge_discover_health_fetch( $permalink, 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/140 Mobile Safari/537.36' );
		$live_cache_probe = $normal;
		$googlebot = go_verge_discover_health_fetch( $permalink, 'Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' );

		if ( 200 !== $normal['code'] ) {
			$blocked = go_verge_discover_health_loopback_inconclusive( $normal );
			go_verge_discover_health_item(
				$items,
				$blocked ? 'warning' : 'critical',
				$blocked ? 'Self-request da matéria foi inconclusivo' : 'A matéria mais recente não responde HTTP 200',
				sprintf( 'HTTP %d · redirect %s · %s%s', $normal['code'], $normal['location'] ?: '—', $normal['error'] ?: 'sem erro de transporte', $blocked ? ' · o código do loopback não é tratado como status público da URL' : '' ),
				$permalink
			);
		} else {
			go_verge_discover_health_item( $items, 'good', 'Single pública responde HTTP 200', sprintf( '%d ms', $normal['ms'] ), $permalink );
		}

		if ( 200 !== $googlebot['code'] ) {
			$blocked = go_verge_discover_health_loopback_inconclusive( $googlebot );
			go_verge_discover_health_item(
				$items,
				$blocked ? 'warning' : 'critical',
				$blocked ? 'Self-request com UA Googlebot foi inconclusivo' : 'Googlebot Smartphone não recebe HTTP 200 na matéria mais recente',
				sprintf( 'HTTP %d · redirect %s · %s%s', $googlebot['code'], $googlebot['location'] ?: '—', $googlebot['error'] ?: 'sem erro de transporte', $blocked ? ' · confirme crawler externo/Search Console; este é um teste servidor→próprio domínio' : '' ),
				$permalink
			);
		} elseif ( 200 === $normal['code'] ) {
			$normal_len = strlen( $normal['body'] );
			$bot_len    = strlen( $googlebot['body'] );
			$ratio      = $normal_len > 0 ? $bot_len / $normal_len : 1;
			$level      = ( $ratio < 0.60 || $ratio > 1.60 ) ? 'warning' : 'good';
			go_verge_discover_health_item( $items, $level, 'Googlebot Smartphone acessa a mesma superfície pública', sprintf( 'HTTP 200 · tamanho normal %s / Googlebot %s · razão %.2f', size_format( $normal_len ), size_format( $bot_len ), $ratio ), $permalink );
		}

		if ( 200 === $normal['code'] ) {
			$html      = $normal['body'];
			$robots_m  = strtolower( go_verge_discover_health_meta_content( $html, 'robots' ) );
			$canonical = go_verge_discover_health_canonical_from_html( $html );
			$og_image  = go_verge_discover_health_meta_content( $html, 'og:image' );
			$xrobots   = strtolower( (string) $normal['xrobots'] );

			if ( false !== strpos( $robots_m, 'noindex' ) || false !== strpos( $xrobots, 'noindex' ) ) {
				go_verge_discover_health_item( $items, 'critical', 'A matéria pública está noindex', trim( 'meta robots: ' . $robots_m . ' · X-Robots-Tag: ' . $xrobots, ' ·' ), $permalink );
			} elseif ( false === strpos( $robots_m, 'max-image-preview:large' ) ) {
				go_verge_discover_health_item( $items, 'warning', 'max-image-preview:large não apareceu no HTML público', $robots_m ?: 'meta robots ausente', $permalink );
			} else {
				go_verge_discover_health_item( $items, 'good', 'Preview grande está autorizado', $robots_m, $permalink );
			}

			if ( '' === $canonical ) {
				go_verge_discover_health_item( $items, 'critical', 'Canonical ausente na matéria pública', 'Nenhum <link rel="canonical"> foi encontrado.', $permalink );
			} elseif ( go_verge_discover_health_normalize_url( $canonical ) !== go_verge_discover_health_normalize_url( $permalink ) ) {
				go_verge_discover_health_item( $items, 'critical', 'Canonical da matéria aponta para outro documento', $canonical, $permalink );
			} else {
				go_verge_discover_health_item( $items, 'good', 'Canonical da matéria é autorreferente', $canonical, $permalink );
			}

			if ( '' === $og_image ) {
				go_verge_discover_health_item( $items, 'warning', 'og:image ausente na matéria mais recente', 'O Google pode escolher outra imagem, mas o publisher perdeu controle da representação visual.', $permalink );
			} else {
				go_verge_discover_health_item( $items, 'good', 'og:image está presente', $og_image, $permalink );
			}

			$has_article_schema = preg_match( '#["\']@type["\']\s*:\s*(?:["\'](?:NewsArticle|Article|BlogPosting)["\']|\[[^\]]*(?:NewsArticle|Article|BlogPosting)[^\]]*\])#i', $html );
			go_verge_discover_health_item( $items, $has_article_schema ? 'good' : 'warning', $has_article_schema ? 'Article/NewsArticle schema detectado' : 'Article/NewsArticle schema não foi detectado', $has_article_schema ? 'JSON-LD contém um subtipo editorial reconhecido.' : 'Revise o provedor ativo de schema.', $permalink );

			$article_node_count = go_verge_discover_health_article_node_count( $html, $permalink );
			if ( $article_node_count > 1 ) {
				go_verge_discover_health_item( $items, 'warning', 'Há Article/NewsArticle duplicado para a mesma URL', sprintf( '%d nós de artigo foram encontrados no grafo público; mantenha um único nó canônico.', $article_node_count ), $permalink );
			} elseif ( 1 === $article_node_count ) {
				go_verge_discover_health_item( $items, 'good', 'Há um único Article/NewsArticle canônico', 'O grafo público não duplica a entidade editorial da matéria.', $permalink );
			}

			$has_body = false !== strpos( $html, 'go-article__content' ) || false !== strpos( $html, 'entry-content go-single__content' );
			go_verge_discover_health_item( $items, $has_body ? 'good' : 'critical', $has_body ? 'Corpo editorial está presente no HTML inicial' : 'Corpo editorial não foi reconhecido no HTML inicial', $has_body ? 'O artigo não depende de interação para existir no documento.' : 'O Googlebot pode estar recebendo um shell incompleto.', $permalink );
		}

		/* Source attachment dimensions are deterministic and do not depend on HTML. */
		$image_id = get_post_thumbnail_id( $post_id );
		if ( ! $image_id ) {
			go_verge_discover_health_item( $items, 'warning', 'Matéria mais recente sem imagem destacada', 'Use uma imagem editorial relevante antes de publicar.', $permalink );
		} else {
			$meta   = wp_get_attachment_metadata( $image_id );
			$width  = is_array( $meta ) ? absint( $meta['width'] ?? 0 ) : 0;
			$height = is_array( $meta ) ? absint( $meta['height'] ?? 0 ) : 0;
			$pixels = $width * $height;
			$level  = ( $width >= 1200 && $pixels > 300000 ) ? 'good' : 'warning';
			go_verge_discover_health_item( $items, $level, $level === 'good' ? 'Imagem destacada tem fonte grande' : 'Imagem destacada não cumpre o alvo de preview grande', sprintf( '%d × %d px · %s pixels', $width, $height, number_format_i18n( $pixels ) ), $permalink );
		}
	}

	/* 3) Recent newsroom sample ------------------------------------------- */
	$sample = go_verge_discover_health_recent_sample( 20 );
	$sample_issues = array();
	foreach ( array(
		'no_image'       => 'sem imagem destacada',
		'under_1200'     => 'com fonte menor que 1200 px',
		'under_300k'     => 'com menos de 300 mil pixels',
		'no_category'    => 'sem categoria',
		'invalid_author' => 'com autor inválido',
		'custom_noindex' => 'com noindex editorial',
	) as $key => $label ) {
		if ( ! empty( $sample[ $key ] ) ) {
			$sample_issues[] = sprintf( '%d %s', (int) $sample[ $key ], $label );
		}
	}
	go_verge_discover_health_item(
		$items,
		$sample_issues ? 'warning' : 'good',
		$sample_issues ? 'Amostra das últimas matérias tem pendências' : 'Últimas matérias passaram nos checks editoriais essenciais',
		$sample_issues ? implode( '; ', $sample_issues ) : sprintf( '%d matérias verificadas; %d NewsArticle(s) nas últimas 48h.', (int) $sample['total'], (int) $sample['news_last_48h'] )
	);

	/* 4) Cache/session state ---------------------------------------------- */
	$mu_status = function_exists( 'go_verge_cache_integrity_mu_guard_status' )
		? go_verge_cache_integrity_mu_guard_status()
		: array( 'installed' => false, 'current' => false, 'target' => WP_CONTENT_DIR . '/mu-plugins/overdrive-public-cache-integrity.php', 'error' => 'função de status indisponível' );
	if ( ! empty( $mu_status['current'] ) ) {
		go_verge_discover_health_item( $items, 'good', 'MU guard de cache está instalado antes dos plugins normais', 'Protege HTML público anônimo contra PHPSESSID e session.cache_limiter desde o bootstrap.' );
	} else {
		$detail = ! empty( $mu_status['error'] )
			? (string) $mu_status['error']
			: 'O tema tentará instalar automaticamente no próximo carregamento administrativo.';
		$detail .= ' · destino: ' . (string) ( $mu_status['target'] ?? '' );
		go_verge_discover_health_item( $items, 'warning', 'MU guard de cache ainda não está ativo', $detail );
	}

	/* A successful loopback is useful evidence of final headers, but a WAF/CDN
	 * denial is the response to the server's own IP/ASN, not the public article.
	 * Never diagnose cache poisoning from headers attached to a 401/403/429. */
	$live_cache_usable = ! empty( $live_cache_probe ) && 200 === (int) ( $live_cache_probe['code'] ?? 0 );
	$live_cache_blocked = ! empty( $live_cache_probe ) && go_verge_discover_health_loopback_blocked( $live_cache_probe );
	if ( $live_cache_usable ) {
		$live_cc       = strtolower( (string) ( $live_cache_probe['cache_control'] ?? '' ) );
		$live_set      = (string) ( $live_cache_probe['set_cookie'] ?? '' );
		$live_names    = array_map( 'strtolower', (array) ( $live_cache_probe['cookie_names'] ?? array() ) );
		$live_session  = false !== stripos( $live_set, 'PHPSESSID=' ) || in_array( 'phpsessid', $live_names, true );
		$live_poisoned = false !== strpos( $live_cc, 'no-store' ) || false !== strpos( $live_cc, 'private' );
		$cache_bits    = array(
			'PHPSESSID=' . ( $live_session ? 'sim' : 'não' ),
			'Cache-Control=' . ( $live_cc ?: 'não definido pelo PHP/host' ),
		);
		if ( ! empty( $live_cache_probe['x_litespeed_cache'] ) ) {
			$cache_bits[] = 'LiteSpeed=' . $live_cache_probe['x_litespeed_cache'];
		}
		if ( ! empty( $live_cache_probe['x_hcdn_cache'] ) ) {
			$cache_bits[] = 'hCDN=' . $live_cache_probe['x_hcdn_cache'];
		}

		if ( $live_session || $live_poisoned ) {
			go_verge_discover_health_item( $items, 'critical', 'Resposta HTTP pública final ainda está contaminada por sessão/cache privado', implode( ' · ', $cache_bits ), (string) ( $live_cache_probe['url'] ?? '' ) );
		} else {
			go_verge_discover_health_item( $items, 'good', 'Resposta HTTP pública final não envia sessão/cache privado', implode( ' · ', $cache_bits ), (string) ( $live_cache_probe['url'] ?? '' ) );
		}
	} elseif ( ! $live_cache_blocked ) {
		go_verge_discover_health_item( $items, 'warning', 'Não foi possível confirmar externamente a resposta final de cache', ! empty( $live_cache_probe['error'] ) ? (string) $live_cache_probe['error'] : 'A matéria representativa não produziu uma amostra HTTP utilizável.' );
	}

	$cache = get_option( 'go_verge_cache_integrity_state', array() );
	if ( is_array( $cache ) && ! empty( $cache['checked_at'] ) ) {
		$cache_control  = strtolower( (string) ( $cache['cache_control'] ?? '' ) );
		$session_cookie = ! empty( $cache['session_cookie'] );
		$bad_policy     = false !== strpos( $cache_control, 'no-store' ) || false !== strpos( $cache_control, 'private' );
		$internal_bad   = $session_cookie || $bad_policy;
		$external_bad   = $live_cache_usable
			&& ( false !== stripos( (string) ( $live_cache_probe['set_cookie'] ?? '' ), 'PHPSESSID=' )
				|| false !== strpos( strtolower( (string) ( $live_cache_probe['cache_control'] ?? '' ) ), 'no-store' )
				|| false !== strpos( strtolower( (string) ( $live_cache_probe['cache_control'] ?? '' ) ), 'private' ) );

		$level = $internal_bad && ! $external_bad ? 'warning' : ( $internal_bad ? 'critical' : 'good' );
		$label = 'Amostra interna de sessão/cache está limpa';
		if ( $internal_bad && ! $external_bad ) {
			$label = 'Amostra interna registrou sessão, mas a resposta HTTP final atual está limpa';
		} elseif ( $internal_bad ) {
			$label = 'Amostra interna confirma regressão de sessão/cache';
		}
		$detail = sprintf( 'PHPSESSID=%s · Cache-Control=%s · amostra %s', $session_cookie ? 'sim' : 'não', $cache_control ?: 'não definido pelo PHP', wp_date( 'd/m/Y H:i', (int) $cache['checked_at'] ) );
		if ( $live_cache_blocked ) {
			$detail .= sprintf( ' · self-loopback HTTP %d ignorado para cache (resposta de borda/WAF)', (int) ( $live_cache_probe['code'] ?? 0 ) );
		}
		go_verge_discover_health_item(
			$items,
			$level,
			$label,
			$detail
		);
	} else {
		go_verge_discover_health_item( $items, 'warning', 'Ainda não há amostra interna de cache público', 'Abra uma página pública anonimamente; a resposta HTTP externa acima é a verificação principal.' );
	}

	/* 5) WP-Cron ----------------------------------------------------------- */
	$last_cron = absint( get_option( 'go_verge_discover_health_last_cron', 0 ) );
	$next_cron = wp_next_scheduled( 'go_verge_discover_health_heartbeat' );
	$cron_fresh = $last_cron && ( time() - $last_cron ) <= ( 3 * HOUR_IN_SECONDS );
	if ( ! $next_cron ) {
		go_verge_discover_health_item( $items, 'warning', 'Heartbeat do Discover Health não está agendado', 'wp_schedule_event não encontrou o evento horário esperado.' );
	} elseif ( $last_cron && ( time() - $last_cron ) > ( 3 * HOUR_IN_SECONDS ) ) {
		go_verge_discover_health_item( $items, 'warning', 'WP-Cron não executa o heartbeat há mais de 3 horas', sprintf( 'Última execução: %s · próxima registrada: %s', wp_date( 'd/m/Y H:i:s', $last_cron ), wp_date( 'd/m/Y H:i:s', $next_cron ) ) );
	} elseif ( $last_cron ) {
		go_verge_discover_health_item( $items, 'good', 'WP-Cron está executando o heartbeat', sprintf( 'Última execução: %s', wp_date( 'd/m/Y H:i:s', $last_cron ) ) );
	} else {
		go_verge_discover_health_item( $items, 'warning', 'Heartbeat do WP-Cron ainda não executou', sprintf( 'Próxima execução registrada: %s', wp_date( 'd/m/Y H:i:s', $next_cron ) ) );
	}

	if ( defined( 'DISABLE_WP_CRON' ) && DISABLE_WP_CRON ) {
		go_verge_discover_health_item(
			$items,
			$cron_fresh ? 'good' : 'warning',
			$cron_fresh ? 'DISABLE_WP_CRON está ativo com cron real confirmado' : 'DISABLE_WP_CRON está ativo sem heartbeat recente',
			$cron_fresh ? 'O heartbeat recente comprova que o agendador externo está chamando o WordPress.' : 'Confirme que o servidor chama wp-cron.php externamente com frequência.'
		);
	}

	if ( ! $skip_cron_transport ) {
		$cron_probe = go_verge_discover_health_cron_transport_probe();
		if ( 403 === (int) $cron_probe['code'] ) {
			go_verge_discover_health_item(
				$items,
				$cron_fresh ? 'good' : 'warning',
				$cron_fresh ? 'Self-probe de wp-cron.php é bloqueado, mas o cron real está funcionando' : 'Self-probe de wp-cron.php responde 403',
				$cron_fresh ? sprintf( 'Loopback HTTP 403 · %d ms · heartbeat recente comprova execução por transporte externo.', (int) $cron_probe['ms'] ) : sprintf( 'Loopback HTTP 403 · %d ms. Isso pode ser WAF/host; sem heartbeat recente, confirme o cron externo.', (int) $cron_probe['ms'] ),
				site_url( '/wp-cron.php' )
			);
		} elseif ( 200 === (int) $cron_probe['code'] ) {
			go_verge_discover_health_item( $items, 'good', 'wp-cron.php aceita o transporte HTTP', sprintf( 'HTTP 200 · %d ms', (int) $cron_probe['ms'] ), site_url( '/wp-cron.php' ) );
		} else {
			go_verge_discover_health_item( $items, 'warning', 'Não foi possível confirmar o transporte HTTP do WP-Cron', $cron_probe['error'] ?: sprintf( 'HTTP %d · %d ms', (int) $cron_probe['code'], (int) $cron_probe['ms'] ), site_url( '/wp-cron.php' ) );
		}
	}

	$counts = array( 'good' => 0, 'warning' => 0, 'critical' => 0 );
	foreach ( $items as $item ) {
		$counts[ $item['level'] ]++;
	}
	$overall = $counts['critical'] ? 'critical' : ( $counts['warning'] ? 'warning' : 'good' );

	$report = array(
		'checked_at' => time(),
		'overall'    => $overall,
		'counts'     => $counts,
		'items'      => $items,
		'sample'     => $sample,
		'post_id'    => $post_id,
	);
	set_transient( GO_VERGE_DISCOVER_HEALTH_TRANSIENT, $report, 5 * MINUTE_IN_SECONDS );
	update_option( GO_VERGE_DISCOVER_HEALTH_OPTION, $report, false );
	return $report;
}

/** Read the saved report; page rendering must never wait for HTTP probes. */
function go_verge_discover_health_saved_report( $refresh = false ) {
    $report = get_option( GO_VERGE_DISCOVER_HEALTH_OPTION, array() );
    if ( $refresh || empty( $report['checked_at'] ) || time() - (int) $report['checked_at'] > HOUR_IN_SECONDS ) {
        if ( ! wp_next_scheduled( 'go_verge_discover_health_refresh' ) ) {
            wp_schedule_single_event( time() + 5, 'go_verge_discover_health_refresh' );
        }
    }
    if ( ! empty( $report['items'] ) && isset( $report['counts'], $report['sample'], $report['overall'] ) ) { return $report; }
    return array(
        'checked_at' => 0, 'overall' => 'warning', 'counts' => array( 'good' => 0, 'warning' => 1, 'critical' => 0 ),
        'sample' => array_fill_keys( array( 'total', 'no_image', 'under_1200', 'under_300k', 'custom_noindex', 'news_last_48h' ), 0 ),
        'items' => array( array( 'level' => 'warning', 'label' => 'Diagnóstico aguardando coleta', 'detail' => 'A coleta foi agendada em segundo plano. Ainda não há evidência para avaliar a entrega.', 'url' => '' ) ),
    );
}
add_action( 'go_verge_discover_health_refresh', 'go_verge_discover_health_heartbeat' );

/** Site Health integration. */
function go_verge_discover_health_site_health_result() {
	$report = go_verge_discover_health_saved_report();
	$status = 'good';
	if ( 'critical' === $report['overall'] ) {
		$status = 'critical';
	} elseif ( 'warning' === $report['overall'] ) {
		$status = 'recommended';
	}
	return array(
		'label'       => 'good' === $status ? __( 'Contrato técnico do Discover está saudável', 'go-verge' ) : __( 'Discover Health encontrou pendências', 'go-verge' ),
		'status'      => $status,
		'badge'       => array( 'label' => __( 'Discover', 'go-verge' ), 'color' => 'good' === $status ? 'blue' : ( 'critical' === $status ? 'red' : 'orange' ) ),
		'description' => '<p>' . esc_html( sprintf( 'Checks: %1$d OK, %2$d atenção, %3$d críticos. Verificação: %4$s.', (int) $report['counts']['good'], (int) $report['counts']['warning'], (int) $report['counts']['critical'], ( $report['checked_at'] ? wp_date( 'd/m/Y H:i:s', (int) $report['checked_at'] ) : 'aguardando coleta' ) ) ) . '</p>',
		'actions'     => '<p><a href="' . esc_url( admin_url( 'tools.php?page=go-discover-health' ) ) . '">' . esc_html__( 'Abrir Discover Health', 'go-verge' ) . '</a></p>',
		'test'        => 'go_verge_discover_health_contract',
	);
}

function go_verge_discover_health_register_site_health( $tests ) {
	$tests['async']['go_verge_discover_health_contract'] = array(
		'label'             => __( 'Contrato técnico do Google Discover', 'go-verge' ),
		'test'              => 'go_verge_discover_health_site_health_result',
		'has_rest'          => false,
		'async_direct_test' => 'go_verge_discover_health_site_health_result',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_discover_health_register_site_health', 250 );

/** Add the dedicated newsroom panel. */
function go_verge_discover_health_admin_menu() {
	add_management_page( __( 'Discover Health', 'go-verge' ), __( 'Discover Health', 'go-verge' ), 'manage_options', 'go-discover-health', 'go_verge_discover_health_admin_page' );
}
add_action( 'admin_menu', 'go_verge_discover_health_admin_menu', 53 );

/** Critical-state admin warning based on the latest background/admin snapshot. */
function go_verge_discover_health_admin_notice() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( $screen && 'tools_page_go-discover-health' === $screen->id ) {
		return;
	}
	$report = get_option( GO_VERGE_DISCOVER_HEALTH_OPTION, array() );
	if ( ! is_array( $report ) || 'critical' !== ( $report['overall'] ?? '' ) || empty( $report['checked_at'] ) ) {
		return;
	}
	/* Do not nag on a stale report from an old deployment. */
	if ( ( time() - (int) $report['checked_at'] ) > ( 6 * HOUR_IN_SECONDS ) ) {
		return;
	}
	$first_critical = '';
	foreach ( (array) ( $report['items'] ?? array() ) as $item ) {
		if ( 'critical' === ( $item['level'] ?? '' ) ) {
			$first_critical = sanitize_text_field( (string) ( $item['label'] ?? '' ) );
			break;
		}
	}
	printf(
		'<div class="notice notice-error"><p><strong>%1$s</strong> %2$s <a href="%3$s">%4$s</a></p></div>',
		esc_html__( 'Discover Health encontrou uma falha técnica confirmada que pode afetar rastreamento/indexação.', 'go-verge' ),
		esc_html( $first_critical ? 'Primeiro bloqueio: ' . $first_critical . '.' : 'Abra o diagnóstico para ver a evidência pública/local.' ),
		esc_url( admin_url( 'tools.php?page=go-discover-health' ) ),
		esc_html__( 'Ver diagnóstico', 'go-verge' )
	);
}
add_action( 'admin_notices', 'go_verge_discover_health_admin_notice' );

/** Render the Discover Health admin page. */
function go_verge_discover_health_admin_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}

	$force = false;
	if ( isset( $_POST['go_discover_health_refresh'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Missing
		check_admin_referer( 'go_discover_health_refresh' );
		delete_transient( GO_VERGE_DISCOVER_HEALTH_TRANSIENT );
		delete_transient( 'go_verge_discover_cron_transport_v2' );
		$force = true;
	}
	$report = $force ? go_verge_discover_health_collect( true, false ) : go_verge_discover_health_saved_report( false );
	if ( $force ) {
		echo '<div class="notice notice-success"><p>Reverificação concluída agora. O resultado abaixo já é da coleta nova.</p></div>';
	}
	$labels = array(
		'good'     => array( 'icon' => '🟢', 'text' => __( 'OK', 'go-verge' ), 'color' => '#08783f' ),
		'warning'  => array( 'icon' => '🟡', 'text' => __( 'Atenção', 'go-verge' ), 'color' => '#8a6500' ),
		'critical' => array( 'icon' => '🔴', 'text' => __( 'Crítico', 'go-verge' ), 'color' => '#b42318' ),
	);
	$overall = $labels[ $report['overall'] ];
	?>
	<div class="wrap">
		<h1><?php esc_html_e( 'Discover Health', 'go-verge' ); ?></h1>
		<p><?php esc_html_e( 'Contrato de produção para rastreamento, previews, imagem, schema, News sitemap, cache e WP-Cron. Ele detecta regressões técnicas; não promete distribuição no Discover.', 'go-verge' ); ?></p>

		<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;max-width:1000px;margin:18px 0;">
			<div class="card" style="margin:0;max-width:none"><h2 style="margin-top:0"><?php echo esc_html( $overall['icon'] . ' ' . $overall['text'] ); ?></h2><p><?php printf( esc_html__( 'Verificado em %s', 'go-verge' ), esc_html( ( $report['checked_at'] ? wp_date( 'd/m/Y H:i:s', (int) $report['checked_at'] ) : 'aguardando coleta' ) ) ); ?></p></div>
			<div class="card" style="margin:0;max-width:none"><strong><?php esc_html_e( 'OK', 'go-verge' ); ?></strong><div style="font-size:28px;font-weight:700"><?php echo (int) $report['counts']['good']; ?></div></div>
			<div class="card" style="margin:0;max-width:none"><strong><?php esc_html_e( 'Atenção', 'go-verge' ); ?></strong><div style="font-size:28px;font-weight:700"><?php echo (int) $report['counts']['warning']; ?></div></div>
			<div class="card" style="margin:0;max-width:none"><strong><?php esc_html_e( 'Críticos', 'go-verge' ); ?></strong><div style="font-size:28px;font-weight:700"><?php echo (int) $report['counts']['critical']; ?></div></div>
		</div>

		<form method="post" style="margin:0 0 16px">
			<?php wp_nonce_field( 'go_discover_health_refresh' ); ?>
			<button class="button button-primary" type="submit" name="go_discover_health_refresh" value="1"><?php esc_html_e( 'Reverificar agora', 'go-verge' ); ?></button>
			<a class="button" href="<?php echo esc_url( admin_url( 'site-health.php?tab=status' ) ); ?>"><?php esc_html_e( 'Saúde do site', 'go-verge' ); ?></a>
			<a class="button" href="<?php echo esc_url( admin_url( 'tools.php?page=go-search-observatory' ) ); ?>"><?php esc_html_e( 'Search Observatory', 'go-verge' ); ?></a>
		</form>

		<table class="widefat striped" style="max-width:1100px">
			<thead><tr><th style="width:110px"><?php esc_html_e( 'Estado', 'go-verge' ); ?></th><th><?php esc_html_e( 'Check', 'go-verge' ); ?></th><th><?php esc_html_e( 'Evidência', 'go-verge' ); ?></th></tr></thead>
			<tbody>
			<?php foreach ( $report['items'] as $item ) : $state = $labels[ $item['level'] ]; ?>
				<tr>
					<td><strong style="color:<?php echo esc_attr( $state['color'] ); ?>"><?php echo esc_html( $state['icon'] . ' ' . $state['text'] ); ?></strong></td>
					<td><strong><?php echo esc_html( $item['label'] ); ?></strong><?php if ( ! empty( $item['url'] ) ) : ?><br><a href="<?php echo esc_url( $item['url'] ); ?>" target="_blank" rel="noopener noreferrer"><?php echo esc_html( wp_parse_url( $item['url'], PHP_URL_PATH ) ?: $item['url'] ); ?></a><?php endif; ?></td>
					<td><?php echo esc_html( $item['detail'] ); ?></td>
				</tr>
			<?php endforeach; ?>
			</tbody>
		</table>

		<h2><?php esc_html_e( 'Amostra editorial recente', 'go-verge' ); ?></h2>
		<table class="widefat striped" style="max-width:800px"><tbody>
			<tr><th><?php esc_html_e( 'Matérias verificadas', 'go-verge' ); ?></th><td><?php echo (int) $report['sample']['total']; ?></td></tr>
			<tr><th><?php esc_html_e( 'Sem imagem destacada', 'go-verge' ); ?></th><td><?php echo (int) $report['sample']['no_image']; ?></td></tr>
			<tr><th><?php esc_html_e( 'Imagem abaixo de 1200 px', 'go-verge' ); ?></th><td><?php echo (int) $report['sample']['under_1200']; ?></td></tr>
			<tr><th><?php esc_html_e( 'Imagem abaixo de 300 mil pixels', 'go-verge' ); ?></th><td><?php echo (int) $report['sample']['under_300k']; ?></td></tr>
			<tr><th><?php esc_html_e( 'Noindex editorial', 'go-verge' ); ?></th><td><?php echo (int) $report['sample']['custom_noindex']; ?></td></tr>
			<tr><th><?php esc_html_e( 'NewsArticle nas últimas 48h', 'go-verge' ); ?></th><td><?php echo (int) $report['sample']['news_last_48h']; ?></td></tr>
		</tbody></table>

		<p style="max-width:1000px;color:#646970"><?php esc_html_e( 'Limite do diagnóstico: um self-loop HTTP do servidor para o próprio domínio pode ser bloqueado por WAF/CDN e não representa, sozinho, a resposta pública recebida pelo Google. O painel valida também os geradores locais; bloqueios de borda devem ser confirmados em logs e no Search Console.', 'go-verge' ); ?></p>
	</div>
	<?php
}
