<?php
/** Shared institutional reading tools and recovery-page presentation. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Add an on-page index without changing saved policy text or existing anchors. */
function go_verge_trust_document( $html ) {
	$html = (string) $html;
	if ( ! class_exists( 'WP_HTML_Tag_Processor' ) || ! method_exists( 'WP_HTML_Tag_Processor', 'next_token' ) ) { return array( 'html' => $html, 'sections' => array() ); }
	$used = array(); $headings = array(); $ordinal = 0; $pending = null; $inert = 0;
	$scan = new WP_HTML_Tag_Processor( $html );
	// Read real HTML tokens, including existing IDs later in the document. Raw
	// text and comments cannot masquerade as headings; template/foreign content
	// remains byte-for-byte unchanged. Two linear passes need no seek budget.
	while ( $scan->next_token() ) {
		$type = $scan->get_token_type();
		$tag = '#tag' === $type ? $scan->get_tag() : '';
		$closing = '#tag' === $type && $scan->is_tag_closer();
		if ( '#tag' === $type && ! $closing ) {
			$id = $scan->get_attribute( 'id' );
			if ( is_string( $id ) && '' !== $id ) { $used[ $id ] = true; }
		}
		if ( in_array( $tag, array( 'TEMPLATE', 'SVG', 'MATH' ), true ) ) {
			if ( ! $closing && 'TEMPLATE' !== $tag && $scan->has_self_closing_flag() ) { continue; }
			$inert = max( 0, $inert + ( $closing ? -1 : 1 ) ); continue;
		}
		if ( $inert ) { continue; }
		if ( 'H2' === $tag && ! $closing ) {
			$ordinal++;
			$pending = null === $scan->get_attribute( 'hidden' ) ? array( 'ordinal' => $ordinal, 'label' => '' ) : null;
		} elseif ( 'H2' === $tag && $closing && $pending ) {
			$label = trim( preg_replace( '/\s+/u', ' ', $pending['label'] ) );
			if ( '' !== $label ) { $headings[ $pending['ordinal'] ] = $label; }
			$pending = null;
		} elseif ( '#text' === $type && $pending ) {
			// get_modifiable_text decodes character references once. Never decode twice.
			$pending['label'] .= $scan->get_modifiable_text();
		} elseif ( 'BR' === $tag && $pending ) { $pending['label'] .= ' '; }
	}
	$sections = array(); $emitted = array(); $ordinal = 0; $inert = 0;
	$scan = new WP_HTML_Tag_Processor( $html );
	while ( $scan->next_token() ) {
		if ( '#tag' !== $scan->get_token_type() ) { continue; }
		$tag = $scan->get_tag(); $closing = $scan->is_tag_closer();
		if ( in_array( $tag, array( 'TEMPLATE', 'SVG', 'MATH' ), true ) ) {
			if ( ! $closing && 'TEMPLATE' !== $tag && $scan->has_self_closing_flag() ) { continue; }
			$inert = max( 0, $inert + ( $closing ? -1 : 1 ) ); continue;
		}
		if ( $inert || 'H2' !== $tag || $closing ) { continue; }
		$ordinal++;
		if ( ! isset( $headings[ $ordinal ] ) ) { continue; }
		$id = $scan->get_attribute( 'id' );
		if ( ! is_string( $id ) || '' === $id ) {
			$base = 'documento-' . ( sanitize_title( $headings[ $ordinal ] ) ?: 'secao' );
			$id = $base; $suffix = 2;
			while ( isset( $used[ $id ] ) ) { $id = $base . '-' . $suffix++; }
			$scan->set_attribute( 'id', $id );
			$used[ $id ] = true;
		}
		if ( isset( $emitted[ $id ] ) ) { continue; }
		$emitted[ $id ] = true;
		$sections[] = array( 'id' => $id, 'label' => $headings[ $ordinal ] );
	}
	return array( 'html' => $scan->get_updated_html(), 'sections' => $sections );
}

function go_verge_editorial_presentation_assets() {
	if ( is_admin() ) { return; }
	if ( is_404() ) {
		$rel = '/assets/css/recovery-page.css';
		wp_enqueue_style( 'go-verge-recovery-page', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
	}
	// The last publisher layer overrides old multicolor borders, never the ad creative.
	$rel = '/assets/css/ad-presentation.css';
	wp_enqueue_style( 'go-verge-ad-presentation', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_editorial_presentation_assets', 51000 );
