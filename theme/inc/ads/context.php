<?php
/**
 * Request and template context for advertising.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! function_exists( 'go_verge_is_amp_request' ) ) {
	/**
	 * Whether the current front-end document is an AMP response.
	 *
	 * The AMP plugin is not installed. The check is kept so that installing it
	 * later cannot make the advertising layer emit non-AMP markup into an AMP
	 * document; the previous amp-auto-ads integration was removed with the rest
	 * of the V1 architecture.
	 *
	 * @return bool
	 */
	function go_verge_is_amp_request() {
		if ( is_admin() || is_feed() ) {
			return false;
		}
		if ( function_exists( 'amp_is_request' ) ) {
			return (bool) amp_is_request();
		}
		if ( function_exists( 'is_amp_endpoint' ) ) {
			return (bool) is_amp_endpoint();
		}

		return false;
	}
}

/**
 * Debug output is restricted to administrators or an explicit server flag.
 *
 * @return bool
 */
function go_verge_ads_debug_enabled() {
	$constant_enabled = defined( 'GO_ADS_DEBUG' ) && GO_ADS_DEBUG;
	$query_enabled    = isset( $_GET['go_ads_debug'] ) && '1' === sanitize_text_field( wp_unslash( $_GET['go_ads_debug'] ) );
	$administrator    = is_user_logged_in() && current_user_can( 'manage_options' );

	return $administrator && (bool) apply_filters(
		'go_verge_ads_debug_enabled',
		$constant_enabled || ( $administrator && $query_enabled )
	);
}

/**
 * Resolve one stable template key shared by PHP, diagnostics and reporting.
 *
 * @return string
 */
function go_verge_ads_document_context() {
	if ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) {
		return 'ajax_feed';
	}
	/* Compare templates declare their content state before get_header(). Their
	 * virtual URLs intentionally have no native WordPress page/archive flags. */
	if ( array_key_exists( 'go_verge_ads_compare_document', $GLOBALS ) ) {
		return $GLOBALS['go_verge_ads_compare_document'] ? 'editorial_page' : 'other';
	}
	if ( is_front_page() || is_home() ) {
		return 'home';
	}
	if ( is_singular( 'post' ) ) {
		return 'single_post';
	}
	if ( is_singular( 'games' ) ) {
		return 'single_game';
	}
	if ( is_singular( 'productions' ) ) {
		return 'single_production';
	}
	if ( is_singular( 'go_entity' ) ) {
		return 'single_entity';
	}
	if ( is_page_template( 'page-template/template-latest.php' ) || is_page( 'ultimas-publicacoes' ) ) {
		return 'latest';
	}
	if ( is_search() ) {
		return 'search';
	}
	if ( is_author() ) {
		return 'author';
	}
	if ( is_tag() ) {
		return 'tag';
	}
	if ( is_category( array( 'reviews', 'criticas' ) ) || is_page( array( 'reviews', 'criticas' ) ) ) {
		return 'reviews_archive';
	}
	if ( is_post_type_archive( 'games' ) || is_page( array( 'games', 'biblioteca-de-games' ) ) ) {
		return 'games_archive';
	}
	if ( is_post_type_archive( 'productions' ) ) {
		return 'productions_archive';
	}
	if ( is_post_type_archive( 'go_entity' ) ) {
		return 'entities_archive';
	}
	if ( is_category() || is_archive() ) {
		return 'category';
	}
	/*
	 * The editorial hubs — /entretenimento/, /games/, /tecnologia/, /listas/ and
	 * the rest — are WordPress Pages with their own templates, not category
	 * archives. Treating every Page as unmonetizable left those hubs with no
	 * advertising at all. Institutional pages are still excluded, by slug, in
	 * go_verge_ads_is_monetizable_request().
	 */
	if ( is_page() ) {
		return 'editorial_page';
	}

	return 'other';
}

/**
 * Explicit bridge for a resolved Compare document, before any head/body output.
 * The plugin owns content validity; all normal exclusions and publisher settings
 * remain enforced by go_verge_ads_is_monetizable_request() and the renderer.
 * No URL matching, database lookup, browser classification or new inventory.
 */
function go_verge_ads_compare_document( $has_content ) {
	$GLOBALS['go_verge_ads_compare_document'] = true === $has_content;
}


/**
 * Whether this response may contain advertising at all.
 *
 * @return bool
 */
function go_verge_ads_is_monetizable_request() {
	$config = go_verge_ads_config();
	$ajax = function_exists( 'wp_doing_ajax' ) && wp_doing_ajax();
	if ( empty( $config['enabled'] ) || ( is_admin() && ! $ajax ) || is_feed() || is_404() || is_preview() ) {
		return false;
	}
	if ( function_exists( 'go_verge_is_amp_request' ) && go_verge_is_amp_request() ) {
		return false;
	}
	if ( is_singular() && post_password_required() ) {
		return false;
	}
	// The WordPress privacy page may have a custom slug outside the legacy list.
	if ( function_exists( 'is_privacy_policy' ) && is_privacy_policy() ) {
		return false;
	}
	if ( is_page() ) {
		$slug = (string) get_post_field( 'post_name', get_queried_object_id() );
		if ( $slug && in_array( $slug, (array) ( $config['excluded_page_slugs'] ?? array() ), true ) ) {
			return false;
		}
	}

	/*
	 * `single_game` was excluded here until 05/08/2026, which left every game
	 * page — masthead, anchor, rails, the revenue band single-games.php has
	 * always called — with no advertising at all. The template's own
	 * `game-display` call had no matching unit in the inventory, so it rendered
	 * nothing and the exclusion was never visible in the markup.
	 */
	$context = go_verge_ads_document_context();
	if ( 'other' === $context ) {
		return false;
	}

	return (bool) apply_filters( 'go_verge_ads_is_monetizable_request', true, $context );
}

/**
 * Check that an enabled placement belongs to the current template.
 *
 * @param array<string,mixed> $unit Unit configuration.
 * @return bool
 */
function go_verge_ads_unit_matches_context( $unit ) {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return false; }
	if ( ! go_verge_ads_is_monetizable_request() || empty( $unit['templates'] ) ) {
		return false;
	}

	$matches = in_array( go_verge_ads_document_context(), (array) $unit['templates'], true );

	return (bool) apply_filters( 'go_verge_ads_unit_matches_context', $matches, $unit );
}

/**
 * Reviews, critiques and specials keep Masthead only below the desktop layout.
 * Resolve the queried story: header.php runs before the main loop, and a cached
 * response must carry the same viewport contract for every user agent.
 */
function go_verge_ads_masthead_excludes_desktop() {
	if ( ! is_singular( 'post' ) ) { return false; }
	$post_id = absint( get_queried_object_id() );
	if ( ! $post_id ) { return false; }
	/* A selected/auto-matched package uses single-special.php regardless of its
	 * category or Desk format. An explicitly disabled package resolves to null. */
	if ( function_exists( 'go_verge_specials_get_for_post' ) && go_verge_specials_get_for_post( $post_id ) ) { return true; }
	$type = function_exists( 'go_verge_v7_post_content_type' ) ? go_verge_v7_post_content_type( $post_id ) : '';
	if ( '' !== $type ) { return in_array( $type, array( 'review', 'critica', 'especial' ), true ); }
	/* Preserve the theme's legacy classification only without an explicit Desk
	 * choice; an old score/category must not override a current News or Guide. */
	return ( function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id ) )
		|| ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) )
		|| ( function_exists( 'go_verge_post_is_special' ) && go_verge_post_is_special( $post_id ) );
}

/**
 * Where a post's Top Display serves phones (below 768px).
 *
 * On phones the responsive Top Display used to sit above the headline and was
 * commonly filled at 300x250/336x280 or full width: with Top Scroll and the
 * header, the first screen held no editorial content at all, and the creative
 * pushed the story down on arrival. Phones now get an exact 320x100 of the same
 * unit, in a host of its own:
 *
 *   'inline'  below headline, deck and byline, before the hero image (standard
 *             story layout). template-parts/single/article.php prints it;
 *   'header'  in the usual top position, for the review/critique opening that
 *             leads with the image and for Specials, where a unit under the
 *             byline would sit directly on top of the Hero Overlay;
 *   ''        no split: not a post, phone masthead disabled, or rolled back.
 *
 * Tablets and desktop keep the responsive unit in header.php, untouched. Both
 * hosts carry the same ad unit behind complementary media queries, and the
 * runtime locks a slot to the first host that requests it, so one pageview can
 * never request it twice, not even across a rotation.
 *
 * Rollback: define( 'GO_VERGE_ADS_MASTHEAD_PHONE_FIXED', false ) in wp-config.php.
 *
 * @return string
 */
function go_verge_ads_masthead_phone_mode() {
	if ( ! is_singular( 'post' ) ) { return ''; }
	if ( defined( 'GO_VERGE_ADS_MASTHEAD_MOBILE' ) && ! GO_VERGE_ADS_MASTHEAD_MOBILE ) { return ''; }
	if ( defined( 'GO_VERGE_ADS_MASTHEAD_PHONE_FIXED' ) && ! GO_VERGE_ADS_MASTHEAD_PHONE_FIXED ) { return ''; }
	$post_id = absint( get_queried_object_id() );
	if ( ! $post_id ) { return ''; }
	$mode = 'inline';
	/* Specials render single-special.php, which has no byline slot. */
	if ( function_exists( 'go_verge_specials_get_for_post' ) && go_verge_specials_get_for_post( $post_id ) ) {
		$mode = 'header';
	} elseif ( function_exists( 'go_verge_single_clean_type_classes' ) ) {
		/* The same test template-parts/single/article.php makes: a scored story
		 * with a hero opens with the cinematic masthead (image first), a scored
		 * story without one uses the standard opening (`od-article--premium`). */
		$types = go_verge_single_clean_type_classes( $post_id );
		if ( in_array( 'go-single--scored', $types, true ) && ! in_array( 'od-article--premium', $types, true ) ) {
			$mode = 'header';
		}
	}
	$mode = (string) apply_filters( 'go_verge_ads_masthead_phone_mode', $mode, $post_id );
	return in_array( $mode, array( 'inline', 'header' ), true ) ? $mode : '';
}

/**
 * True when at least one enabled manual unit can render in this response.
 *
 * @return bool
 */
function go_verge_ads_context_has_inventory() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return false; }
	if ( ! go_verge_ads_is_monetizable_request() ) {
		return false;
	}

	foreach ( go_verge_adsense_units() as $unit ) {
		if ( go_verge_ads_unit_matches_context( $unit ) ) {
			return true;
		}
	}

	return false;
}


/**
 * Stable article-root classes shared by editorial code on every viewport.
 *
 * @return string[] Ordered class list for the article prose container.
 */
function go_verge_ads_article_root_classes() {
	return array(
		'entry-content',
		'go-single__content',
		'go-single__content--dropcap',
		'go-article__content',
		'go-article__content--dropcap',
	);
}

/**
 * Stable serialized identity for the article prose container.
 *
 * Used by Site Health and runtime diagnostics to detect article-root drift.
 *
 * @return string e.g. "DIV.entry-content.go-single__content.go-single__content--dropcap.go-article__content.go-article__content--dropcap".
 */
function go_verge_ads_article_root_identity() {
	return 'DIV.' . implode( '.', go_verge_ads_article_root_classes() );
}

/**
 * Render the attribute string for the article prose container.
 *
 * The class list is fixed so theme code has one stable prose root. Extra hooks
 * may be supplied only as data-* attributes.
 *
 * @param array $data Extra data attributes, keyed without the `data-` prefix.
 * @return string Escaped attribute string, ready to print inside <div …>.
 */
function go_verge_ads_article_root_attributes( $data = array() ) {
	$attributes = array(
		'data-go-manual-ads-root' => 'article',
	);

	/* Planner diagnostics are request-local publisher metadata only. They let
	 * the browser distinguish "the planner never created the opportunity" from
	 * "the runtime/provider did not deliver it" without exposing financial data. */
	foreach ( (array) ( $GLOBALS['go_verge_ads_article_plan_public'] ?? array() ) as $key => $value ) {
		$key = sanitize_key( (string) $key );
		if ( '' !== $key && null !== $value && '' !== (string) $value ) {
			$attributes[ 'data-go-ad-plan-' . $key ] = (string) $value;
		}
	}

	foreach ( (array) $data as $key => $value ) {
		$key = strtolower( (string) $key );
		if ( 0 !== strpos( $key, 'data-' ) ) {
			$key = 'data-' . $key;
		}
		/* Keep id/class out of this extension point; the prose root stays canonical. */
		if ( ! preg_match( '/^data-[a-z0-9-]+$/', $key ) ) {
			continue;
		}
		$attributes[ $key ] = (string) $value;
	}

	/**
	 * Filter the extra data attributes on the article prose container.
	 *
	 * @param array $attributes Map of data-* attribute => value.
	 */
	$attributes = (array) apply_filters( 'go_verge_ads_article_root_data', $attributes );

	$out = 'class="' . esc_attr( implode( ' ', go_verge_ads_article_root_classes() ) ) . '" itemprop="articleBody"';
	foreach ( $attributes as $key => $value ) {
		if ( ! preg_match( '/^data-[a-z0-9-]+$/', (string) $key ) ) {
			continue;
		}
		$out .= sprintf( ' %s="%s"', $key, esc_attr( $value ) );
	}

	return $out;
}
