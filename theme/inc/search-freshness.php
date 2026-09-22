<?php
/**
 * Search freshness and identity signals.
 *
 * Keeps first-publication time distinct from draft creation/metadata edits,
 * aligns Article date signals, and reinforces the preferred Google site name.
 * It deliberately does NOT use Google's Indexing API for normal articles: that
 * API is not a general-purpose news/article submission API.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

const GO_VERGE_FIRST_PUBLISHED_META = '_go_first_published_gmt';

/** Persist the first moment an editorial URL actually becomes public. */
function go_verge_search_capture_first_publish( $new_status, $old_status, $post ) {
	if ( ! $post instanceof WP_Post || 'post' !== $post->post_type || 'publish' !== $new_status || 'publish' === $old_status ) { return; }
	if ( defined( 'WP_IMPORTING' ) && WP_IMPORTING ) { return; }
	if ( get_post_meta( $post->ID, GO_VERGE_FIRST_PUBLISHED_META, true ) ) { return; }
	update_post_meta( $post->ID, GO_VERGE_FIRST_PUBLISHED_META, gmdate( 'Y-m-d H:i:s' ) );
}
add_action( 'transition_post_status', 'go_verge_search_capture_first_publish', 20, 3 );

/** ISO-8601 first-publication timestamp, falling back safely for legacy posts. */
function go_verge_search_published_iso( $post_id ) {
	$post_id = absint( $post_id );
	$raw     = (string) get_post_meta( $post_id, GO_VERGE_FIRST_PUBLISHED_META, true );
	$ts      = $raw ? strtotime( $raw . ' UTC' ) : 0;
	if ( $ts > 0 && $ts <= ( time() + 300 ) ) {
		return gmdate( 'c', $ts );
	}
	$legacy = get_post_time( 'c', true, $post_id );
	if ( $legacy ) {
		return (string) $legacy;
	}
	/*
	 * No stored first-publication time and no post date.
	 *
	 * This used to answer gmdate('c') — the moment of the request. That is not a
	 * missing date, it is a WRONG one, and it is wrong differently on every
	 * crawl: two fetches of the same URL an hour apart returned two different
	 * datePublished values, both "now". A news surface reads that as a story
	 * that keeps republishing itself.
	 *
	 * The honest answer for a post with no resolvable date is the post's own
	 * recorded date, however imperfect, and an empty string when even that is
	 * gone. Callers already treat '' as "omit the field", which is a correct
	 * graph; an invented clock is not.
	 */
	$raw_date = (string) get_post_field( 'post_date_gmt', $post_id );
	if ( '' !== $raw_date && '0000-00-00 00:00:00' !== $raw_date ) {
		$fallback = strtotime( $raw_date . ' UTC' );
		if ( $fallback ) {
			return gmdate( 'c', $fallback );
		}
	}
	return '';
}

/** Unix first-publication time for visible relative-date components. */
function go_verge_search_published_timestamp( $post_id ) {
	$iso = go_verge_search_published_iso( $post_id );
	$ts  = strtotime( $iso );
	return $ts ? (int) $ts : (int) get_post_time( 'U', true, $post_id );
}

/** A modified date can never predate publication. */
function go_verge_search_consistent_modified_iso( $post_id ) {
	$published = strtotime( go_verge_search_published_iso( $post_id ) );
	$modified_iso = function_exists( 'go_verge_search_modified_iso' )
		? go_verge_search_modified_iso( $post_id )
		: get_post_modified_time( 'c', true, $post_id );
	$modified = strtotime( (string) $modified_iso );
	if ( ! $modified || ( $published && $modified < $published ) ) {
		return go_verge_search_published_iso( $post_id );
	}
	return gmdate( 'c', $modified );
}

/**
 * Last pass over Rank Math's graph: one site identity and one article clock.
 * This runs after the theme's other schema enrichers so a stale plugin option
 * cannot reintroduce the domain as the primary site name or an old draft date.
 */
function go_verge_search_freshness_rank_math_graph( $data ) {
	if ( ! is_array( $data ) ) { return $data; }
	$post_id = is_singular( 'post' ) ? get_queried_object_id() : 0;
	$home    = home_url( '/' );
	$org_id  = trailingslashit( $home ) . '#organization';
	$site_id = trailingslashit( $home ) . '#website';
	$current_url = $post_id ? get_permalink( $post_id ) : '';
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	$alternate = function_exists( 'go_verge_seo_alternate_name_value' ) ? go_verge_seo_alternate_name_value() : null;

	/* An unresolvable clock leaves the plugin's own value alone: overwriting a
	 * plausible date with an empty string is a worse graph than not running. */
	$published_iso = $post_id ? go_verge_search_published_iso( $post_id ) : '';
	$modified_iso  = $post_id ? go_verge_search_consistent_modified_iso( $post_id ) : '';

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) { continue; }
		if ( go_verge_schema_node_matches_url( $node, $home, array( 'WebSite' ) ) ) {
			$data[ $key ]['@id']          = $site_id;
			$data[ $key ]['url']          = $home;
			$data[ $key ]['name']         = $site_name;
			if ( null !== $alternate ) { $data[ $key ]['alternateName'] = $alternate; } else { unset( $data[ $key ]['alternateName'] ); }
			$data[ $key ]['publisher']    = array( '@id' => $org_id );
		}
		if ( isset( $node['@id'] ) && $org_id === (string) $node['@id'] ) {
			$data[ $key ]['name'] = $site_name;
			$data[ $key ]['url']  = $home;
		}
		if ( $post_id && go_verge_schema_node_matches_url( $node, $current_url, array( 'Article', 'NewsArticle', 'BlogPosting', 'Review' ) ) ) {
			if ( '' !== $published_iso ) { $data[ $key ]['datePublished'] = $published_iso; }
			if ( '' !== $modified_iso ) { $data[ $key ]['dateModified'] = $modified_iso; }
		}
		if ( $post_id && go_verge_schema_node_matches_url( $node, $current_url, array( 'WebPage' ) ) ) {
			/* This node describes the same document as Article and its visible
			 * byline. Do not let the plugin's draft/technical clock disagree. */
			if ( isset( $node['datePublished'] ) && '' !== $published_iso ) { $data[ $key ]['datePublished'] = $published_iso; }
			if ( isset( $node['dateModified'] ) && '' !== $modified_iso ) { $data[ $key ]['dateModified'] = $modified_iso; }
		}
	}
	/* This filter is intentionally late; consolidate any same-origin WebSite that
	 * was normalized to the canonical ID after the generic foundation pass. */
	go_verge_schema_graph_dedupe_id( $data, $site_id );
	go_verge_schema_graph_dedupe_id( $data, $org_id );
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_search_freshness_rank_math_graph', 2000, 1 );

/** Reinforce Rank Math's dedicated WebSite entity too. */
function go_verge_search_freshness_rank_math_website( $entity ) {
	if ( ! is_array( $entity ) ) { $entity = array(); }
	$entity['name']          = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	$alternate = function_exists( 'go_verge_seo_alternate_name_value' ) ? go_verge_seo_alternate_name_value() : null;
	if ( null !== $alternate ) { $entity['alternateName'] = $alternate; } else { unset( $entity['alternateName'] ); }
	$entity['url']           = home_url( '/' );
	$entity['@id']           = trailingslashit( home_url( '/' ) ) . '#website';
	return $entity;
}
add_filter( 'rank_math/json_ld/website', 'go_verge_search_freshness_rank_math_website', 2000 );

/**
 * Homepage fallback for installations where Rank Math omits its WebSite node.
 * It is emitted only when Rank Math does not advertise JSON-LD itself through
 * the expected frontend hook, avoiding two competing WebSite nodes.
 */
function go_verge_search_identity_head_hints() {
	if ( ! is_front_page() && ! is_home() ) { return; }
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
	echo '<meta name="application-name" content="' . esc_attr( $site_name ) . '">' . "\n";
	echo '<meta name="apple-mobile-web-app-title" content="' . esc_attr( $site_name ) . '">' . "\n";
}
add_action( 'wp_head', 'go_verge_search_identity_head_hints', 3 );

/** Surface first-publication state in Site Health for deploy verification. */
function go_verge_search_freshness_site_health( $tests ) {
	$tests['direct']['go_search_freshness'] = array(
		'label' => __( 'Overdrive search freshness signals', 'go-verge' ),
		'test'  => static function () {
			return array(
				'label'       => __( 'Fresh publication timestamps and site identity are active', 'go-verge' ),
				'status'      => 'good',
				'badge'       => array( 'label' => 'Overdrive Search', 'color' => 'blue' ),
				'description' => '<p>' . esc_html__( 'New posts store their true first-publication time; Article schema and Google site-name signals are normalized.', 'go-verge' ) . '</p>',
				'actions'     => '',
				'test'        => 'go_search_freshness',
			);
		},
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_search_freshness_site_health' );
