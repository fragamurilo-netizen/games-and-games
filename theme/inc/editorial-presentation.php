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


/**
 * Group institutional destinations so the trust navigation stays readable as
 * the newsroom adds more public policies.
 *
 * @return array<int,array{label:string,items:array<string,string>}>
 */
function go_verge_trust_navigation_groups() {
	return array(
		array(
			'label' => __( 'Institucional', 'go-verge' ),
			'items' => array(
				'sobre-o-overdrive' => __( 'Sobre', 'go-verge' ),
				'contato'            => __( 'Contato', 'go-verge' ),
				'seja-colaborador'   => __( 'Seja colaborador', 'go-verge' ),
				'parcerias'           => __( 'Parcerias', 'go-verge' ),
				'midia-kit'           => __( 'Mídia kit', 'go-verge' ),
			),
		),
		array(
			'label' => __( 'Políticas editoriais', 'go-verge' ),
			'items' => array(
				'politicas'                            => __( 'Políticas e transparência', 'go-verge' ),
				'politica-editorial'                   => __( 'Política editorial', 'go-verge' ),
				'politica-de-reviews'                  => __( 'Política de reviews', 'go-verge' ),
				'propriedade-e-financiamento'          => __( 'Propriedade e financiamento', 'go-verge' ),
				'missao-e-prioridades-de-cobertura'    => __( 'Missão e cobertura', 'go-verge' ),
				'politica-de-diversidade'              => __( 'Diversidade', 'go-verge' ),
				'politica-de-assinatura'               => __( 'Autoria e assinatura', 'go-verge' ),
				'politica-de-fontes-nao-identificadas' => __( 'Fontes não identificadas', 'go-verge' ),
			),
		),
		array(
			'label' => __( 'Legal e acesso', 'go-verge' ),
			'items' => array(
				'acessibilidade' => __( 'Acessibilidade', 'go-verge' ),
				'privacidade'    => __( 'Privacidade', 'go-verge' ),
				'termos-de-uso'  => __( 'Termos de uso', 'go-verge' ),
			),
		),
	);
}

/** Published-page lookup used by the public policy hub. */
function go_verge_trust_published_page( $slug ) {
	$page = get_page_by_path( sanitize_title( (string) $slug ), OBJECT, 'page' );
	return ( $page instanceof WP_Post && 'publish' === get_post_status( $page ) ) ? $page : null;
}

/**
 * Render the policy landing page from published documents only. Draft policy
 * claims remain invisible until an editor approves them.
 */
function go_verge_policy_hub_markup() {
	$sections = array(
		array(
			'title' => __( 'Como publicamos', 'go-verge' ),
			'intro' => __( 'Regras para autoria, apuração, reviews e responsabilidade editorial.', 'go-verge' ),
			'items' => array(
				'politica-editorial' => array(
					'label' => __( 'Princípios', 'go-verge' ),
					'description' => __( 'Como lidamos com apuração, correções, publicidade, ferramentas e independência editorial.', 'go-verge' ),
				),
				'politica-de-reviews' => array(
					'label' => __( 'Reviews', 'go-verge' ),
					'description' => __( 'Como testamos produtos e jogos, tratamos códigos de análise e chegamos às conclusões publicadas.', 'go-verge' ),
				),
				'politica-de-assinatura' => array(
					'label' => __( 'Autoria', 'go-verge' ),
					'description' => __( 'Quando usamos assinatura individual, quando um conteúdo pode ser atribuído à redação e quem responde por ele.', 'go-verge' ),
				),
				'politica-de-fontes-nao-identificadas' => array(
					'label' => __( 'Fontes', 'go-verge' ),
					'description' => __( 'Quando a identidade de uma fonte pode ser preservada e que verificação é exigida antes da publicação.', 'go-verge' ),
				),
			),
		),
		array(
			'title' => __( 'Quem somos e como decidimos', 'go-verge' ),
			'intro' => __( 'Documentos sobre propriedade, financiamento, prioridades de cobertura e diversidade.', 'go-verge' ),
			'items' => array(
				'propriedade-e-financiamento' => array(
					'label' => __( 'Transparência', 'go-verge' ),
					'description' => __( 'Como o site se sustenta e como mantemos interesses comerciais separados das decisões de pauta.', 'go-verge' ),
				),
				'missao-e-prioridades-de-cobertura' => array(
					'label' => __( 'Cobertura', 'go-verge' ),
					'description' => __( 'O que priorizamos, quais critérios ajudam a escolher pautas e o que pode ficar fora da cobertura.', 'go-verge' ),
				),
				'politica-de-diversidade' => array(
					'label' => __( 'Diversidade', 'go-verge' ),
					'description' => __( 'Compromissos para ampliar perspectivas, escolher fontes com responsabilidade e evitar estereótipos.', 'go-verge' ),
				),
			),
		),
		array(
			'title' => __( 'Direitos do leitor', 'go-verge' ),
			'intro' => __( 'Privacidade, acessibilidade e regras de uso do site.', 'go-verge' ),
			'items' => array(
				'privacidade' => array(
					'label' => __( 'Dados', 'go-verge' ),
					'description' => __( 'Como informações e tecnologias de medição são tratadas no site.', 'go-verge' ),
				),
				'acessibilidade' => array(
					'label' => __( 'Acesso', 'go-verge' ),
					'description' => __( 'Compromissos e canais para tornar o Overdrive utilizável por mais pessoas.', 'go-verge' ),
				),
				'termos-de-uso' => array(
					'label' => __( 'Termos', 'go-verge' ),
					'description' => __( 'Condições de uso, responsabilidades e regras aplicáveis à navegação no site.', 'go-verge' ),
				),
			),
		),
	);

	$out = '<div class="go-policy-hub" aria-label="' . esc_attr__( 'Central de políticas do Overdrive', 'go-verge' ) . '">';
	foreach ( $sections as $section ) {
		$cards = '';
		foreach ( $section['items'] as $slug => $item ) {
			$page = go_verge_trust_published_page( $slug );
			if ( ! $page ) {
				continue;
			}
			$cards .= '<a class="go-policy-card" href="' . esc_url( get_permalink( $page ) ) . '">'
				. '<span class="go-policy-card__eyebrow">' . esc_html( $item['label'] ) . '</span>'
				. '<strong class="go-policy-card__title">' . esc_html( get_the_title( $page ) ) . '</strong>'
				. '<span class="go-policy-card__description">' . esc_html( $item['description'] ) . '</span>'
				. '<span class="go-policy-card__action">' . esc_html__( 'Ler política', 'go-verge' ) . '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="m9 18 6-6-6-6 1.4-1.4L17.8 12l-7.4 7.4L9 18Z"/></svg></span>'
				. '</a>';
		}
		if ( '' === $cards ) {
			continue;
		}
		$out .= '<section class="go-policy-hub__section">'
			. '<header class="go-policy-hub__head"><h2>' . esc_html( $section['title'] ) . '</h2><p>' . esc_html( $section['intro'] ) . '</p></header>'
			. '<div class="go-policy-grid">' . $cards . '</div>'
			. '</section>';
	}
	$out .= '</div>';
	return $out;
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
