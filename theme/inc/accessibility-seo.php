<?php
/**
 * Accessibility discovery, structured data and public statement.
 *
 * Exposes only accessibility features that are actually implemented by the
 * theme. This is descriptive metadata, not a certification claim.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Canonical accessibility feature vocabulary used in schema.org metadata.
 *
 * @return string[]
 */
function go_verge_accessibility_features() {
	return array(
		'alternativeText',
		'structuralNavigation',
		'highContrastDisplay',
		'largePrint',
		'displayTransformability',
		'readingOrder',
	);
}

/**
 * Interaction methods supported by the site's own interface.
 *
 * @return string[]
 */
function go_verge_accessibility_controls() {
	return array(
		'fullKeyboardControl',
		'fullMouseControl',
		'fullTouchControl',
	);
}

/**
 * Honest public summary of the accessibility features implemented in theme.
 *
 * @return string
 */
function go_verge_accessibility_summary() {
	return __( 'O Overdrive oferece navegação estrutural, link para pular ao conteúdo, controles de contraste e tamanho do texto, modo leitura, redução de movimento, operação por teclado e leitura em voz alta de matérias quando o navegador oferece síntese de voz.', 'go-verge' );
}

/**
 * Accessibility statement URL when available.
 *
 * @return string
 */
function go_verge_accessibility_page_url() {
	$page = get_page_by_path( 'acessibilidade', OBJECT, 'page' );
	if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
		return get_permalink( $page );
	}
	return home_url( '/acessibilidade/' );
}

/**
 * Merge accessibility metadata into a CreativeWork-style schema node.
 *
 * @param array $node Schema node.
 * @param bool  $with_controls Whether to expose interaction controls.
 * @return array
 */
function go_verge_schema_add_accessibility( $node, $with_controls = false ) {
	if ( ! is_array( $node ) ) {
		return $node;
	}

	$node['accessibilityFeature'] = go_verge_accessibility_features();
	$node['accessibilitySummary'] = go_verge_accessibility_summary();
	$node['accessMode']           = array( 'textual', 'visual' );

	if ( $with_controls ) {
		$node['accessibilityControl'] = go_verge_accessibility_controls();
	}

	return $node;
}

/**
 * Extend Rank Math's graph without creating duplicate schema trees.
 *
 * WebSite/WebPage get interaction controls. Article/Review get the actual
 * content-level features. We deliberately do not claim audio description,
 * sign language, captions or a hazard-free experience sitewide.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_rank_math_accessibility_json_ld( $data ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}

	$current_url = is_singular() ? get_permalink( get_queried_object_id() ) : ( function_exists( 'go_verge_seo_canonical_url' ) ? go_verge_seo_canonical_url() : '' );
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || empty( $node['@type'] ) ) {
			continue;
		}

		$is_site = go_verge_schema_node_matches_url( $node, home_url( '/' ), array( 'WebSite' ) );
		$is_page = $current_url && go_verge_schema_node_matches_url( $node, $current_url, array( 'WebPage', 'CollectionPage', 'ProfilePage', 'AboutPage', 'ContactPage' ) );
		$is_content = $current_url && go_verge_schema_node_matches_url( $node, $current_url, array( 'Article', 'NewsArticle', 'BlogPosting', 'Review', 'CreativeWork' ) );
		$is_site_or_page = $is_site || $is_page;

		if ( $is_site_or_page || $is_content ) {
			$data[ $key ] = go_verge_schema_add_accessibility( $node, $is_site_or_page );
		}

		if ( $is_site ) {
			$data[ $key ]['hasPart'] = array(
				'@type' => 'WebPage',
				'@id'   => go_verge_accessibility_page_url() . '#webpage',
				'url'   => go_verge_accessibility_page_url(),
				'name'  => __( 'Acessibilidade', 'go-verge' ),
			);
		}
	}

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_accessibility_json_ld', 80, 1 );

/**
 * Create a public accessibility statement only when missing.
 *
 * The copy describes features already implemented by the theme and avoids
 * claiming certification or conformance level.
 */
function go_verge_prepare_accessibility_page() {
	if ( get_option( 'go_verge_accessibility_page_prepared_v1' ) ) {
		return;
	}

	$existing = get_page_by_path( 'acessibilidade', OBJECT, 'page' );
	if ( ! $existing ) {
		$content = <<<'HTML'
<!-- wp:paragraph -->
<p>O Overdrive trabalha para que suas matérias e páginas possam ser usadas por mais pessoas, em diferentes dispositivos e formas de navegação. Os recursos abaixo fazem parte do próprio site e podem evoluir conforme a plataforma é atualizada.</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">Recursos disponíveis</h2>
<!-- /wp:heading -->

<!-- wp:list -->
<ul><li>link para pular diretamente ao conteúdo principal;</li><li>navegação por teclado nos principais controles e menus;</li><li>ajuste de contraste em níveis reduzido, padrão e aumentado;</li><li>aumento e redução do tamanho do texto;</li><li>modo leitura para reduzir distrações em matérias longas;</li><li>opção para reduzir movimentos e animações;</li><li>leitura em voz alta de matérias quando o navegador ou dispositivo oferece síntese de voz;</li><li>estrutura semântica de títulos, áreas de navegação e conteúdo principal;</li><li>textos alternativos em imagens editoriais quando disponíveis e revisados no fluxo de publicação.</li></ul>
<!-- /wp:list -->

<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">Como abrir os controles</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>O botão <strong>Acessibilidade</strong> fica no canto inferior esquerdo do site. Nele é possível alterar texto, contraste, modo leitura e movimento, além de restaurar as preferências ao padrão.</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">Conteúdo de terceiros</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Vídeos, players, anúncios e outros conteúdos incorporados podem ter controles próprios e limitações que não dependem diretamente do Overdrive. Sempre que possível, buscamos integrar esses elementos sem impedir a navegação principal do site.</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":2} -->
<h2 class="wp-block-heading">Encontrou uma barreira?</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Se algum conteúdo, controle ou fluxo do site estiver difícil de usar, fale com a redação pela página de <a href="/contato/">Contato</a>. Informar a página, o aparelho, o navegador e a tecnologia assistiva utilizada ajuda a reproduzir o problema.</p>
<!-- /wp:paragraph -->
HTML;

		wp_insert_post(
			array(
				'post_type'    => 'page',
				'post_status'  => 'publish',
				'post_title'   => 'Acessibilidade',
				'post_name'    => 'acessibilidade',
				'post_content' => $content,
			)
		);
	}

	update_option( 'go_verge_accessibility_page_prepared_v1', 1, false );
}
add_action( 'admin_init', 'go_verge_prepare_accessibility_page', 45 );

/** Add a discoverable relationship from every public page to the statement. */
function go_verge_accessibility_head_link() {
	if ( is_admin() || is_feed() ) {
		return;
	}
	printf( "\n<link rel=\"help\" href=\"%s\">\n", esc_url( go_verge_accessibility_page_url() ) );
}
add_action( 'wp_head', 'go_verge_accessibility_head_link', 3 );

/** Ensure the accessibility statement is discoverable even with a custom footer menu. */
function go_verge_append_accessibility_to_footer_menu( $items, $args ) {
	if ( empty( $args->theme_location ) || 'footer' !== $args->theme_location ) {
		return $items;
	}
	$url = go_verge_accessibility_page_url();
	if ( false !== strpos( (string) $items, $url ) ) {
		return $items;
	}
	$items .= sprintf(
		'<li class="menu-item go-menu-item-accessibility"><a href="%1$s">%2$s</a></li>',
		esc_url( $url ),
		esc_html__( 'Acessibilidade', 'go-verge' )
	);
	return $items;
}
add_filter( 'wp_nav_menu_items', 'go_verge_append_accessibility_to_footer_menu', 20, 2 );

/** Site Health visibility check for the public statement. */
function go_verge_register_accessibility_health_test( $tests ) {
	$tests['direct']['go_verge_accessibility_statement'] = array(
		'label' => __( 'Declaração pública de acessibilidade', 'go-verge' ),
		'test'  => 'go_verge_accessibility_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_accessibility_health_test' );

function go_verge_accessibility_health_test() {
	$page = get_page_by_path( 'acessibilidade', OBJECT, 'page' );
	$good = $page instanceof WP_Post && 'publish' === $page->post_status;
	return array(
		'label'       => $good ? __( 'A página de acessibilidade está pública', 'go-verge' ) : __( 'Publique a página de acessibilidade', 'go-verge' ),
		'status'      => $good ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'Acessibilidade', 'go-verge' ), 'color' => 'blue' ),
		'description' => '<p>' . esc_html( $good ? __( 'Mecanismos de busca e leitores encontram uma declaração pública dos recursos de acessibilidade do site.', 'go-verge' ) : __( 'Uma página pública ajuda a documentar recursos reais e oferece um canal para relatar barreiras.', 'go-verge' ) ) . '</p>',
		'actions'     => $good ? '' : sprintf( '<p><a href="%s">%s</a></p>', esc_url( admin_url( 'edit.php?post_type=page' ) ), esc_html__( 'Abrir páginas', 'go-verge' ) ),
		'test'        => 'go_verge_accessibility_statement',
	);
}
