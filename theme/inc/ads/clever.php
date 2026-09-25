<?php
/**
 * Clever Advertising — a second network beside the AdSense contract.
 *
 * Additive by construction. It adds exactly three things:
 *
 *   1. The Clever Core loader (site 105113), async, immediately before </body>,
 *      on the same monetizable requests that carry AdSense.
 *   2. One 300x250 host per page: in the article, a little before 36% of the
 *      story, past the opening (P1, A1) and with comfortable room from every
 *      AdSense host the planner already placed; or at the top of the
 *      home/archive sidebar. It reserves nothing and stays invisible until
 *      Clever puts a creative in it.
 *   3. The mobile 320x50 anchor, docked in normal flow at the very top of the
 *      page instead of floating over the article and over Google's own anchor.
 *
 * Clever rotates one format per pageview — anchor, then 300x250, then the mobile
 * 300x250 — and pauses 24 hours after the last one. Its first-party cookies show
 * where the reader is in that rotation, so the browser knows before first paint,
 * without storing anything, which pageview opens a rotation: that is the one the
 * anchor arrives on. Only on that pageview is the 50px strip reserved and Top
 * Scroll requested as an exact 300x250 with compact framing. From the second
 * access onwards Top Scroll renders exactly as before.
 *
 * Never: moving, delaying or removing an AdSense unit; resizing one outside that
 * single Top Scroll variant; hiding a served Clever creative; writing storage.
 *
 * Switches for wp-config.php:
 *   GO_VERGE_CLEVER_ENABLED       false removes the loader and every host.
 *   GO_VERGE_CLEVER_MOBILE        false loads Clever only from 1101px up (the
 *                                 desktop layout), where its rotation has only
 *                                 the 300x250: no anchor, no strip, Top Scroll
 *                                 untouched. The anchor currently served
 *                                 (stickySponsorClick) redirects the reader's
 *                                 first link click to the sponsor.
 *   GO_VERGE_CLEVER_FIRST_ACCESS  false keeps Top Scroll untouched on every
 *                                 pageview (no reserved strip); the anchor is
 *                                 still docked at the top when Clever serves it.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! defined( 'GO_VERGE_CLEVER_ENABLED' ) ) {
	define( 'GO_VERGE_CLEVER_ENABLED', true );
}
if ( ! defined( 'GO_VERGE_CLEVER_SCRIPT_ID' ) ) {
	define( 'GO_VERGE_CLEVER_SCRIPT_ID', '105113' );
}
if ( ! defined( 'GO_VERGE_CLEVER_SCRIPT_URL' ) ) {
	define( 'GO_VERGE_CLEVER_SCRIPT_URL', 'https://scripts.cleverwebserver.com/498461ef42e36bdbfe38a5e2b7f253ec.js' );
}
/*
 * Clever stays on desktop; phones are AdSense-only by default since 5.7.0.
 *
 * The phone rotation opens with the anchor documented above, which sends the
 * reader's first link click to the sponsor. That click is the one AdSense's
 * vignette waits for — the most valuable and most viewable format the account
 * serves — so the first internal navigation of every rotation lost its vignette
 * and, usually, the rest of the session. It also held Top Scroll to a compact
 * exact 300x250 on the first access instead of the full-width creative, and
 * a redirecting ad on the same page as Google ads is a policy exposure the
 * account does not need. Desktop keeps Clever's 300x250 as before.
 *
 * To restore the previous behaviour: define( 'GO_VERGE_CLEVER_MOBILE', true );
 */
if ( ! defined( 'GO_VERGE_CLEVER_MOBILE' ) ) {
	define( 'GO_VERGE_CLEVER_MOBILE', false );
}
if ( ! defined( 'GO_VERGE_CLEVER_FIRST_ACCESS' ) ) {
	define( 'GO_VERGE_CLEVER_FIRST_ACCESS', true );
}

/**
 * Resolved Clever configuration.
 *
 * @return array{enabled:bool,script_id:string,script_url:string,mobile:bool,first_access:bool,article:bool,sidebar:bool}
 */
function go_verge_clever_config() {
	static $config = null;
	if ( null !== $config ) {
		return $config;
	}

	$config = (array) apply_filters(
		'go_verge_clever_config',
		array(
			'enabled'      => (bool) GO_VERGE_CLEVER_ENABLED,
			'script_id'    => (string) GO_VERGE_CLEVER_SCRIPT_ID,
			'script_url'   => (string) GO_VERGE_CLEVER_SCRIPT_URL,
			'mobile'       => (bool) GO_VERGE_CLEVER_MOBILE,
			'first_access' => (bool) GO_VERGE_CLEVER_FIRST_ACCESS,
			'article'      => true,
			'sidebar'      => true,
		)
	);

	$config['script_id'] = (string) preg_replace( '/\D+/', '', (string) ( $config['script_id'] ?? '' ) );
	$url  = esc_url_raw( (string) ( $config['script_url'] ?? '' ), array( 'https' ) );
	$host = (string) wp_parse_url( $url, PHP_URL_HOST );
	/* Only Clever's own script host may become the loader source. */
	$config['script_url'] = ( '' !== $url && preg_match( '/(?:^|\.)cleverwebserver\.com$/i', $host ) ) ? $url : '';
	$config['enabled']    = ! empty( $config['enabled'] ) && '' !== $config['script_id'] && '' !== $config['script_url'];
	foreach ( array( 'mobile', 'first_access', 'article', 'sidebar' ) as $key ) {
		$config[ $key ] = ! empty( $config[ $key ] );
	}
	/* The first-access layout exists for the phone anchor only. */
	$config['first_access'] = $config['first_access'] && $config['mobile'];

	return $config;
}

/**
 * Whether this response carries Clever at all.
 *
 * The theme's global advertising switch and page eligibility govern both
 * networks: a page without AdSense never gets Clever either.
 *
 * @return bool
 */
function go_verge_clever_enabled() {
	$config = go_verge_clever_config();
	if ( empty( $config['enabled'] ) ) {
		return false;
	}
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) {
		return false;
	}
	if ( ! function_exists( 'go_verge_ads_is_monetizable_request' ) || ! go_verge_ads_is_monetizable_request() ) {
		return false;
	}
	if ( function_exists( 'is_customize_preview' ) && is_customize_preview() ) {
		return false;
	}
	return (bool) apply_filters( 'go_verge_clever_enabled', true );
}

/** Whether the first-access layout (strip + exact 300x250 Top Scroll) is active. */
function go_verge_clever_first_access_enabled() {
	$config = go_verge_clever_config();
	return ! empty( $config['first_access'] ) && go_verge_clever_enabled();
}

/**
 * A local asset reduced for inline printing, or '' when it cannot be inlined.
 *
 * Block comments and indentation are dropped; line breaks stay, so automatic
 * semicolon insertion never changes meaning. The theme's HTML-filter guard
 * applies: a body with "<" followed by a letter, "/", "!" or "?" is refused.
 *
 * @param string $relative Path below the theme directory.
 * @return string
 */
function go_verge_clever_inline_asset( $relative ) {
	static $cache = array();
	if ( isset( $cache[ $relative ] ) ) {
		return $cache[ $relative ];
	}
	$path = GO_VERGE_DIR . $relative;
	$code = is_readable( $path ) ? (string) file_get_contents( $path ) : ''; // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents -- local static asset.
	$code = (string) preg_replace( '~/\*[\s\S]*?\*/~', '', $code );
	$code = trim( (string) preg_replace( '~\n\s*~', "\n", $code ) );
	if ( '' !== $code && function_exists( 'go_verge_ads_inline_script_is_safe' ) && ! go_verge_ads_inline_script_is_safe( $code ) ) {
		$code = '';
	}
	$cache[ $relative ] = $code;
	return $code;
}

/**
 * First-paint CSS for the strip, the docked anchor, the first-access Top Scroll
 * and the 300x250 host.
 *
 * @param string $script_id Clever script ID.
 * @return string
 */
function go_verge_clever_critical_css( $script_id ) {
	$path = GO_VERGE_DIR . '/assets/css/go-clever-critical.css';
	$css  = is_readable( $path ) ? (string) file_get_contents( $path ) : ''; // phpcs:ignore WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents -- local static asset.
	$css  = (string) preg_replace( '~/\*[\s\S]*?\*/~', '', $css );
	$css  = trim( (string) preg_replace( '~\s*\n\s*~', '', $css ) );
	$css  = str_replace( '__CLEVER_ID__', preg_replace( '/\D+/', '', (string) $script_id ), $css );
	return false === strpos( $css, '<' ) ? $css : '';
}

/**
 * Head: first-paint geometry and the first-access decision.
 *
 * Both must exist before <body> is parsed: the strip and Top Scroll are the
 * first boxes of the page, and Top Scroll's mount call runs as soon as its
 * markup is parsed.
 *
 * @return void
 */
function go_verge_clever_print_head() {
	if ( ! go_verge_clever_enabled() ) {
		return;
	}
	$config = go_verge_clever_config();

	$css = go_verge_clever_critical_css( $config['script_id'] );
	if ( '' !== $css ) {
		echo '<style id="go-clever-critical">' . $css . "</style>\n"; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- local static CSS, checked for markup above.
	}

	$script = go_verge_clever_inline_asset( '/assets/js/go-clever-head.js' );
	if ( '' === $script ) {
		return;
	}
	$settings = array(
		'id'          => $config['script_id'],
		'firstAccess' => ! empty( $config['first_access'] ),
	);
	echo '<script id="go-clever-first-access" data-cfasync="false" data-no-optimize="1" data-no-defer="1">window.GOCleverConfig='
		. wp_json_encode( $settings, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT ) . ";\n"
		. $script . "</script>\n"; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- JSON_HEX encoded config and local static JavaScript checked above.
}
add_action( 'wp_head', 'go_verge_clever_print_head', 1 );

/** DNS only: the loader is requested at the end of the body, never ahead of LCP. */
function go_verge_clever_resource_hints( $urls, $relation_type ) {
	if ( 'dns-prefetch' === $relation_type && go_verge_clever_enabled() ) {
		$urls[] = 'https://scripts.cleverwebserver.com';
	}
	return $urls;
}
add_filter( 'wp_resource_hints', 'go_verge_clever_resource_hints', 21, 2 );

/**
 * The 50px strip above Top Scroll. Printed on every eligible response and
 * displayed only on a phone whose pageview opens Clever's rotation.
 *
 * @return void
 */
function go_verge_clever_render_anchor_slot() {
	if ( ! go_verge_clever_first_access_enabled() ) {
		return;
	}
	echo '<div class="go-clever-anchor-slot" aria-hidden="true"></div>' . "\n";
}

/**
 * Hand the Top Scroll options to the first-access variant before mounting.
 *
 * Only the unit's own mount call changes: when the browser decided this is not
 * the first access — or the variant is off — the options pass through untouched
 * and the runtime mounts exactly the responsive unit it always did.
 *
 * @param string $script    Mount script printed after the unit.
 * @param string $placement Placement key.
 * @return string
 */
function go_verge_clever_topscroll_mount_script( $script, $placement ) {
	if ( 'topscroll' !== $placement || ! go_verge_clever_first_access_enabled() ) {
		return $script;
	}
	$open = '(function(s,o){';
	if ( 0 !== strpos( (string) $script, $open ) ) {
		return $script;
	}
	return $open
		. 'if(window.GOClever&&window.GOClever.topScroll){o=window.GOClever.topScroll(s&&s.parentElement,o)||o;}'
		. substr( (string) $script, strlen( $open ) );
}
add_filter( 'go_verge_ads_unit_mount_script', 'go_verge_clever_topscroll_mount_script', 10, 2 );

/**
 * An inert 300x250 host. The footer controller gives `clever-core-ads` to the
 * first host that is actually rendered; the label shows with the creative.
 *
 * @param string $context article|sidebar.
 * @return string
 */
function go_verge_clever_slot_markup( $context ) {
	$context = sanitize_key( (string) $context );
	return sprintf(
		'<aside class="go-clever-slot go-clever-slot--%1$s" data-go-clever-slot="%1$s" aria-label="%2$s"><span class="go-clever-slot__label" aria-hidden="true">%3$s</span><div class="go-clever-slot__mount" data-go-clever-mount></div></aside>',
		esc_attr( $context ),
		esc_attr__( 'Publicidade', 'go-verge' ),
		esc_html__( 'Publicidade', 'go-verge' )
	);
}

/**
 * Byte offset for the article host in the composed HTML, or 0 for none.
 *
 * Reads the same top-level blocks as the AdSense planner, after the composer has
 * inserted its hosts, so the AdSense plan is final and the planner never sees
 * this host. Candidates are prose boundaries inside running text (a paragraph
 * followed by a paragraph or a heading), after the opening — the first two
 * AdSense hosts in reading order, P1 and A1 — and never in the first 20% of the
 * article. Each side must clear at least the planner's own minimum between two
 * AdSense units, counting the article start (hero unit) and end (completion
 * unit) as hosts.
 *
 * 5.6.7: the unit aims a little before 36% of the story. Among the boundaries
 * with comfortable room (1.5x that minimum on both sides) that sit before 36%,
 * the one closest to 33% wins: past the opening (Top Display, Hero Overlay, P1,
 * A1), and far enough down for Clever to fill it before the reader arrives,
 * while still reaching most readers. With no comfortable boundary before 36%,
 * the earliest comfortable one wins, as in 5.6.6; without any, the boundary with
 * the most room; a saturated article gets none. Comfort never drops below the
 * configured 1.5x to hit a depth, so the 300x250 is never packed closer to an
 * AdSense unit than before.
 * Filters: go_verge_clever_article_comfort (1.5), ..._protected_hosts (2),
 * ..._target_depth (0.33), ..._max_depth (0.36).
 *
 * @param string $content Composed article HTML.
 * @return int
 */
function go_verge_clever_article_position( $content ) {
	if ( ! function_exists( 'go_verge_ads_planner_blocks' ) ) {
		return 0;
	}
	$blocks = go_verge_ads_planner_blocks( $content );
	$count  = count( $blocks );
	if ( $count < 5 ) {
		return 0;
	}

	$clearance  = function_exists( 'go_verge_ads_planner_clearance' ) ? (array) go_verge_ads_planner_clearance() : array();
	$min_words  = max( 1, absint( $clearance['words'] ?? 70 ) );
	$min_height = max( 1, absint( $clearance['height'] ?? 215 ) );
	/* Comfortable room, as a multiple of the planner minimum (1.0 to 3.0). */
	$comfort        = max( 1.0, min( 3.0, (float) apply_filters( 'go_verge_clever_article_comfort', 1.5 ) ) );
	$comfort_words  = (int) ceil( $comfort * $min_words );
	$comfort_height = (int) ceil( $comfort * $min_height );
	/* How many leading AdSense hosts own the opening (P1, A1 by default). */
	$protected      = max( 0, min( 7, (int) apply_filters( 'go_verge_clever_article_protected_hosts', 2 ) ) );
	/* Preferred depth: a little before 36% of the story (word share). */
	$target_depth   = max( 0.20, min( 0.60, (float) apply_filters( 'go_verge_clever_article_target_depth', 0.33 ) ) );
	$max_depth      = max( $target_depth, min( 0.95, (float) apply_filters( 'go_verge_clever_article_max_depth', 0.36 ) ) );

	$is_host     = array();
	$words_to    = array();
	$height_to   = array();
	$hosts       = array( array( 'index' => -1, 'words' => 0, 'height' => 0 ) );
	$opening_end = -1;
	$words       = 0;
	$height      = 0;
	foreach ( $blocks as $index => $block ) {
		$opening = substr( $content, (int) $block['start'], min( 600, (int) $block['end'] - (int) $block['start'] ) );
		$is_host[ $index ] = (bool) preg_match( '~^<[a-z0-9:-]+\b[^>]*\sdata-go-ad-placement\s*=~i', $opening );
		if ( $is_host[ $index ] ) {
			$hosts[] = array( 'index' => $index, 'words' => $words, 'height' => $height );
			/* The opening belongs to the first AdSense hosts in reading order. */
			if ( count( $hosts ) - 1 <= $protected ) {
				$opening_end = $index;
			}
		} else {
			$words  += absint( $block['words'] ?? 0 );
			$height += absint( $block['height'] ?? 0 );
		}
		$words_to[ $index ]  = $words;
		$height_to[ $index ] = $height;
	}
	$hosts[] = array( 'index' => $count, 'words' => $words, 'height' => $height );
	if ( $words < 2 * $min_words ) {
		return 0;
	}

	$best      = null;
	$first     = null;
	$preferred = null;
	for ( $index = 0; $index < $count - 1; $index++ ) {
		$block = $blocks[ $index ];
		$next  = $blocks[ $index + 1 ];
		if ( $index <= $opening_end || $is_host[ $index ] || $is_host[ $index + 1 ] ) {
			continue;
		}
		if ( 'prose' !== ( $block['kind'] ?? '' ) || ! in_array( $next['kind'] ?? '', array( 'prose', 'heading' ), true ) ) {
			continue;
		}
		$depth = $words_to[ $index ] / $words;
		if ( $depth < 0.20 || $depth > 0.95 ) {
			continue;
		}
		/* A paragraph that introduces what follows ("Confira:") stays attached to it. */
		$text = trim( html_entity_decode( wp_strip_all_tags( substr( $content, (int) $block['start'], (int) $block['end'] - (int) $block['start'] ) ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) );
		if ( '' === $text || ':' === substr( $text, -1 ) ) {
			continue;
		}

		$before = $hosts[0];
		$after  = end( $hosts );
		foreach ( $hosts as $host ) {
			if ( $host['index'] <= $index ) {
				$before = $host;
			} elseif ( $host['index'] > $index ) {
				$after = $host;
				break;
			}
		}
		$gap_before_words  = $words_to[ $index ] - $before['words'];
		$gap_after_words   = $after['words'] - $words_to[ $index ];
		$gap_before_height = $height_to[ $index ] - $before['height'];
		$gap_after_height  = $after['height'] - $height_to[ $index ];
		if ( $gap_before_words < $min_words || $gap_after_words < $min_words
			|| $gap_before_height < $min_height || $gap_after_height < $min_height ) {
			continue;
		}

		$room = min( $gap_before_height, $gap_after_height );
		if ( min( $gap_before_words, $gap_after_words ) >= $comfort_words && $room >= $comfort_height ) {
			if ( $depth < $max_depth ) {
				/* Closest to the target wins; on a tie, the earlier one. */
				$distance = abs( $depth - $target_depth );
				if ( null === $preferred || $distance < $preferred['distance'] ) {
					$preferred = array(
						'position' => (int) $block['end'],
						'distance' => $distance,
					);
				}
			} elseif ( null === $first ) {
				/* Reading order: past the target band, the first comfortable one. */
				$first = (int) $block['end'];
			}
			continue;
		}
		if ( null === $best || $room > $best['room'] ) {
			$best = array(
				'position' => (int) $block['end'],
				'room'     => $room,
			);
		}
	}

	if ( $preferred ) {
		return $preferred['position'];
	}
	if ( null !== $first ) {
		return $first;
	}
	return $best ? $best['position'] : 0;
}

/**
 * Insert the Clever 300x250 host into the composed article, if a boundary
 * qualifies. Called by single-clean.php right after the AdSense composer.
 *
 * @param string $content Composed article HTML.
 * @return string
 */
function go_verge_clever_compose_article( $content ) {
	if ( ! is_string( $content ) || '' === trim( $content ) || ! is_singular( 'post' ) ) {
		return $content;
	}
	$config = go_verge_clever_config();
	if ( empty( $config['article'] ) || ! go_verge_clever_enabled() || false !== strpos( $content, 'data-go-clever-slot' ) ) {
		return $content;
	}
	$position = go_verge_clever_article_position( $content );
	if ( $position < 1 || $position > strlen( $content ) ) {
		return $content;
	}
	return substr( $content, 0, $position ) . "\n" . go_verge_clever_slot_markup( 'article' ) . "\n" . substr( $content, $position );
}

/** Home, archives and the latest-publications hub. */
function go_verge_clever_is_listing_context() {
	$listing = is_front_page() || is_home() || is_archive()
		|| ( function_exists( 'go_verge_is_latest_hub' ) && go_verge_is_latest_hub() );
	return (bool) apply_filters( 'go_verge_clever_sidebar_context', $listing );
}

/**
 * The sidebar host, at the top of the home/archive sidebar (on phones the
 * sidebar follows the feed, so it is still well below the fold). At most one
 * per document.
 *
 * @return void
 */
function go_verge_clever_render_sidebar_slot() {
	static $printed = false;
	if ( $printed ) {
		return;
	}
	$config = go_verge_clever_config();
	if ( empty( $config['sidebar'] ) || ! go_verge_clever_enabled() || ! go_verge_clever_is_listing_context() ) {
		return;
	}
	$printed = true;
	echo go_verge_clever_slot_markup( 'sidebar' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built and escaped above.
}

/**
 * The Clever Core tag as supplied for site 105113, configured: the real script
 * source, `data-callback` pointing at the theme's handler, and the unused
 * click/view macro placeholders left out. With GO_VERGE_CLEVER_MOBILE off it
 * returns early below the desktop layout. When the theme's optional consent gate
 * is on, the same code waits for that permission like AdSense does.
 *
 * @param array<string,mixed> $config Resolved configuration.
 * @return string
 */
function go_verge_clever_loader_tag( $config ) {
	$loader_id = wp_json_encode( 'CleverCoreLoader' . $config['script_id'] );
	$source    = wp_json_encode( (string) $config['script_url'], JSON_UNESCAPED_SLASHES );
	$body      = <<<JS
        var a, c = document.createElement("script"), f = window.frameElement;

        c.id = {$loader_id};
        c.src = {$source};

        c.async = !0;
        c.type = "text/javascript";
        c.setAttribute("data-target", window.name || (f && f.getAttribute("id")));
        c.setAttribute("data-callback", "GOCleverFormat");

        try {
            a = parent.document.getElementsByTagName("script")[0] || document.getElementsByTagName("script")[0];
        } catch (e) {
            a = !1;
        }

        a || (a = document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0]);
        a.parentNode.insertBefore(c, a);
        window.GOClever && window.GOClever.loader && window.GOClever.loader(c);
JS;

	if ( empty( $config['mobile'] ) ) {
		$body = "        if (!window.matchMedia || !window.matchMedia(\"(min-width: 1101px)\").matches) { return; }

" . $body;
	}

	$gate = function_exists( 'go_verge_ads_requires_theme_consent_gate' ) && go_verge_ads_requires_theme_consent_gate();
	if ( $gate ) {
		$body = "        function load() {\n" . $body . "\n        }\n"
			. "        function permitted() {\n"
			. "            try { return !!(window.GOAdsConsent && window.GOAdsConsent.permitted()); } catch (e) { return false; }\n"
			. "        }\n"
			. "        if (permitted()) { load(); return; }\n"
			. "        document.addEventListener(\"go:ads-consent-update\", function wait() {\n"
			. "            if (permitted()) { document.removeEventListener(\"go:ads-consent-update\", wait); load(); }\n"
			. "        });";
	}

	return "<script data-cfasync=\"false\" data-no-optimize=\"1\" data-no-defer=\"1\" type=\"text/javascript\" id=\"clever-core\">\n"
		. "/* <![CDATA[ */\n"
		. "    (function (document, window) {\n"
		. $body . "\n"
		. "    })(document, window);\n"
		. "/* ]]> */\n"
		. "</script>\n";
}

/**
 * Footer: the placement controller, then the loader, as the last scripts before
 * </body>. The controller must exist first: it names the data-callback handler
 * and follows the loader element it is handed.
 *
 * @return void
 */
function go_verge_clever_print_footer() {
	if ( ! go_verge_clever_enabled() ) {
		return;
	}
	$config     = go_verge_clever_config();
	$controller = go_verge_clever_inline_asset( '/assets/js/go-clever.js' );
	if ( '' !== $controller ) {
		echo '<script id="go-clever-controller" data-cfasync="false" data-no-optimize="1" data-no-defer="1">' . $controller . "</script>\n"; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- local static JavaScript checked by go_verge_clever_inline_asset().
	}
	echo go_verge_clever_loader_tag( $config ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed tag, values JSON-encoded.
}
add_action( 'wp_footer', 'go_verge_clever_print_footer', 100 );
