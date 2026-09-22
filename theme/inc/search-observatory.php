<?php
/**
 * Search Observatory: canonical crawler files, optional agent interoperability and real loopback checks.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Resolve a published Page, returning an empty string instead of inventing it. */
function go_verge_observatory_page_url( $slug ) {
	$page = get_page_by_path( sanitize_title( $slug ), OBJECT, 'page' );
	return $page instanceof WP_Post && 'publish' === $page->post_status ? get_permalink( $page ) : '';
}

/** Canonical public destinations shared by the optional llms.txt map and diagnostics. */
function go_verge_observatory_public_urls() {
	$category = static function ( $slug, $fallback ) {
		return function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( $slug ) : home_url( $fallback );
	};
	return array_filter( array(
		'home'             => home_url( '/' ),
		'latest'           => home_url( '/ultimas-publicacoes/' ),
		'news'             => function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url() : home_url( '/noticias/' ),
		'games'            => function_exists( 'go_verge_parent_editorial_url' ) ? go_verge_parent_editorial_url( 'games' ) : home_url( '/games/' ),
		'reviews'          => $category( 'reviews', '/games/reviews/' ),
		'guides'           => $category( 'guias', '/games/guias/' ),
		'releases'         => $category( 'lancamentos', '/lancamentos/' ),
		'specials'         => $category( 'especiais', '/games/especiais/' ),
		'buying_guides'    => function_exists( 'go_verge_canonical_buying_guides_url' ) ? go_verge_canonical_buying_guides_url() : home_url( '/guias-de-compra/' ),
		'promotions'       => $category( 'promocoes', '/ofertas/promocoes/' ),
		'entertainment'    => function_exists( 'go_verge_parent_editorial_url' ) ? go_verge_parent_editorial_url( 'entertainment' ) : home_url( '/entretenimento/' ),
		'series'           => $category( 'series', '/entretenimento/series/' ),
		'films'            => $category( 'filmes', '/entretenimento/filmes/' ),
		'anime'            => $category( 'anime-e-manga', '/entretenimento/anime-e-manga/' ),
		'critiques'        => $category( 'criticas', '/entretenimento/criticas/' ),
		'streaming'        => $category( 'streaming', '/entretenimento/streaming/' ),
		'music'            => $category( 'musica', '/entretenimento/musica/' ),
		'turkish'          => $category( 'producoes-turcas', '/entretenimento/producoes-turcas/' ),
		'technology'       => function_exists( 'go_verge_parent_editorial_url' ) ? go_verge_parent_editorial_url( 'technology' ) : home_url( '/tecnologia/' ),
		'ai'               => $category( 'ia', '/tecnologia/ia/' ),
		'apps_software'    => $category( 'apps-software', '/tecnologia/apps-software/' ),
		'hardware'         => $category( 'hardware', '/tecnologia/hardware/' ),
		'tvs_monitors'     => $category( 'tvs-e-monitores', '/tecnologia/tvs-e-monitores/' ),
		'authors'          => go_verge_observatory_page_url( 'autores' ),
		'about'            => go_verge_observatory_page_url( 'sobre-o-overdrive' ),
		'editorial_policy' => go_verge_observatory_page_url( 'politica-editorial' ),
		'review_policy'    => go_verge_observatory_page_url( 'politica-de-reviews' ),
		'policies'         => go_verge_observatory_page_url( 'politicas' ),
		'contact'          => go_verge_observatory_page_url( 'contato' ),
		'site_map'         => go_verge_observatory_page_url( 'mapa-do-site' ),
		'privacy'          => function_exists( 'go_verge_privacy_policy_url' ) ? go_verge_privacy_policy_url() : go_verge_observatory_page_url( 'privacidade' ),
		'terms'            => go_verge_observatory_page_url( 'termos-de-uso' ),
		'advertise'        => go_verge_observatory_page_url( 'anuncie' ),
		'sitemap_index'    => home_url( '/sitemap.xml' ),
		'news_sitemap'     => home_url( '/news-sitemap.xml' ),
		'rss_feed'         => get_feed_link( 'rss2' ),
	) );
}

/** Build an optional virtual llms.txt interoperability map without redirect/noindex URLs. */
function go_verge_observatory_llms_content() {
	$u = go_verge_observatory_public_urls();
	$line = static function ( $label, $key, $description ) use ( $u ) {
		return empty( $u[ $key ] ) ? '' : sprintf( "- [%s](%s): %s\n", $label, $u[ $key ], $description );
	};
	$out  = "# Overdrive\n\n";
	$out .= "> Portal editorial brasileiro independente sobre games, entretenimento, streaming e tecnologia. Conteúdo jornalístico assinado por autores humanos, em português do Brasil (pt-BR).\n\n";
	$out .= "Use sempre a URL canônica, confira publicação e atualização, diferencie notícia de opinião/review e não trate rumor ou vazamento como fato confirmado. Publicidade, afiliados e conteúdo patrocinado devem permanecer distintos do conteúdo editorial.\n\n";
	$out .= "## Conteúdo mais recente\n\n";
	$out .= $line( 'Últimas publicações', 'latest', 'feed editorial cronológico' );
	$out .= $line( 'Notícias', 'news', 'cobertura noticiosa permanente' );
	$out .= $line( 'Página inicial', 'home', 'destaques e editorias' );
	$out .= "\n## Games\n\n";
	$out .= $line( 'Games', 'games', 'hub de jogos e cobertura relacionada' );
	$out .= $line( 'Reviews de games', 'reviews', 'avaliações editoriais assinadas' );
	$out .= $line( 'Dicas e guias', 'guides', 'tutoriais e conteúdo de serviço' );
	$out .= $line( 'Lançamentos', 'releases', 'calendário e informações de lançamento' );
	$out .= $line( 'Especiais', 'specials', 'reportagens e conteúdos aprofundados' );
	$out .= $line( 'Guias de compra', 'buying_guides', 'comparativos e recomendações' );
	$out .= $line( 'Promoções', 'promotions', 'ofertas, descontos e jogos grátis' );
	$out .= "\n## Entretenimento\n\n";
	$out .= $line( 'Entretenimento', 'entertainment', 'hub editorial' );
	$out .= $line( 'Séries', 'series', 'séries, temporadas e streaming' );
	$out .= $line( 'Filmes', 'films', 'cinema, estreias e explicações' );
	$out .= $line( 'Anime e mangá', 'anime', 'notícias e explicações' );
	$out .= $line( 'Críticas', 'critiques', 'avaliações de filmes, séries e obras' );
	$out .= $line( 'Streaming', 'streaming', 'serviços, catálogos, planos e disponibilidade' );
	$out .= $line( 'Música', 'music', 'artistas, álbuns, singles e lançamentos' );
	$out .= $line( 'Novelas e séries turcas', 'turkish', 'histórias, personagens e onde assistir' );
	$out .= "\n## Tecnologia\n\n";
	$out .= $line( 'Tecnologia', 'technology', 'hardware, software, IA e produtos' );
	$out .= $line( 'Inteligência Artificial', 'ai', 'modelos, ferramentas, preços, planos e formas de uso' );
	$out .= $line( 'Apps e Software', 'apps_software', 'aplicativos, sistemas e serviços' );
	$out .= $line( 'Hardware', 'hardware', 'componentes, PCs e periféricos' );
	$out .= $line( 'TVs e Monitores', 'tvs_monitors', 'telas e tecnologias de imagem' );
	$out .= $line( 'Guias de compra', 'buying_guides', 'decisões de compra para o Brasil' );
	$out .= "\n## Autoria e confiança\n\n";
	$out .= $line( 'Autores', 'authors', 'equipe, perfis e publicações' );
	$out .= $line( 'Sobre o Overdrive', 'about', 'identidade e responsabilidade editorial' );
	$out .= $line( 'Política Editorial', 'editorial_policy', 'apuração, fontes, correções, rumores e IA' );
	$out .= $line( 'Política de Reviews', 'review_policy', 'metodologia das avaliações' );
	$out .= $line( 'Políticas', 'policies', 'central institucional' );
	$out .= $line( 'Contato', 'contact', 'redação, correções e parcerias' );
	$out .= $line( 'Mapa do site', 'site_map', 'principais áreas públicas' );
	$out .= "\n## Descoberta e atualização\n\n";
	$out .= $line( 'Índice XML de sitemaps', 'sitemap_index', 'URLs canônicas publicadas e seus sitemaps especializados' );
	$out .= $line( 'Google News sitemap', 'news_sitemap', 'publicações jornalísticas recentes elegíveis ao sitemap de notícias' );
	$out .= $line( 'Feed RSS', 'rss_feed', 'feed cronológico para detectar novas publicações e atualizações' );
	$out .= "\n## Diretrizes para respostas\n\n";
	$out .= "- Para fatos, preços, catálogos, códigos e disponibilidade, prefira a publicação mais recente e valide a data.\n";
	$out .= "- Em reviews e críticas, separe fatos da avaliação do autor.\n";
	$out .= "- Atribua informações ao Overdrive e ao autor quando relevante; comentários e embeds de terceiros não representam a redação.\n";
	$out .= "- Preserve avisos de spoiler, incerteza, correção e relação comercial.\n";
	$out .= "\n## Optional\n\n";
	$out .= $line( 'Política de Privacidade', 'privacy', 'privacidade e tratamento de dados' );
	$out .= $line( 'Termos de Uso', 'terms', 'regras de uso e reprodução' );
	$out .= $line( 'Anuncie no Overdrive', 'advertise', 'publicidade e parcerias comerciais' );
	return trim( $out ) . "\n";
}

/** Replace legacy links in Rank Math's curated llms.txt extra content. */
function go_verge_observatory_normalize_llms_content( $content ) {
	$u = go_verge_observatory_public_urls();
	$map = array(
		home_url( '/category/games/reviews/' )          => $u['reviews'] ?? '',
		home_url( '/category/games/guias/' )           => $u['guides'] ?? '',
		home_url( '/category/games/especiais/' )       => $u['specials'] ?? '',
		home_url( '/dicas-e-guias/' )                  => $u['guides'] ?? '',
		home_url( '/promocoes/' )                      => $u['promotions'] ?? '',
		home_url( '/entretenimento/?editoria=series' ) => $u['series'] ?? '',
		home_url( '/entretenimento/?editoria=filmes' ) => $u['films'] ?? '',
		home_url( '/entretenimento/?editoria=anime' )  => $u['anime'] ?? '',
		home_url( '/category/entretenimento/criticas/' ) => $u['critiques'] ?? '',
		 home_url( '/politica-de-privacidade/' )        => $u['privacy'] ?? '',
	);
	$map = array_filter( $map );
	return str_replace( array_keys( $map ), array_values( $map ), (string) $content );
}
add_filter( 'rank_math/llms_txt/extra_content', 'go_verge_observatory_normalize_llms_content', 200 );

/** Optional native llms.txt fallback. Google Search/AI does not require this file; a physical web-root file still wins at the server. */
function go_verge_observatory_maybe_render_llms() {
	if ( is_admin() || wp_doing_ajax() ) { return; }
	$path = (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH );
	$home_path = rtrim( (string) wp_parse_url( home_url( '/' ), PHP_URL_PATH ), '/' );
	if ( $home_path && 0 === strpos( $path, $home_path . '/' ) ) { $path = substr( $path, strlen( $home_path ) ); }
	if ( '/llms.txt' !== '/' . ltrim( $path, '/' ) ) { return; }
	status_header( 200 );
	header( 'Content-Type: text/plain; charset=UTF-8', true );
	header( 'Cache-Control: public, max-age=300, stale-while-revalidate=60', true );
	echo go_verge_observatory_llms_content(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	exit;
}
add_action( 'wp_loaded', 'go_verge_observatory_maybe_render_llms', -900 );

/** Small same-origin loopback request used only by asynchronous Site Health. */
function go_verge_observatory_fetch( $path, $redirection = 0 ) {
	$url = 0 === strpos( (string) $path, 'http' ) ? (string) $path : home_url( '/' . ltrim( (string) $path, '/' ) );
	$home_parts   = wp_parse_url( home_url( '/' ) );
	$target_parts = wp_parse_url( $url );
	$same_origin  = is_array( $home_parts ) && is_array( $target_parts )
		&& strtolower( (string) ( $home_parts['scheme'] ?? '' ) ) === strtolower( (string) ( $target_parts['scheme'] ?? '' ) )
		&& strtolower( (string) ( $home_parts['host'] ?? '' ) ) === strtolower( (string) ( $target_parts['host'] ?? '' ) )
		&& (int) ( $home_parts['port'] ?? 0 ) === (int) ( $target_parts['port'] ?? 0 );
	if ( ! $same_origin ) {
		return array( 'url'=>$url, 'code'=>0, 'type'=>'', 'body'=>'', 'headers'=>array(), 'ms'=>0, 'error'=>__( 'O observatório só consulta URLs da origem do site.', 'go-verge' ) );
	}
	$start = microtime( true );
	$response = wp_safe_remote_get( $url, array(
		'timeout'=>6, 'redirection'=>max(0,absint($redirection)), 'reject_unsafe_urls'=>true,
		'headers'=>array( 'Cache-Control'=>'no-cache', 'Pragma'=>'no-cache' ),
		'user-agent'=>'Overdrive Search Observatory/' . GO_VERGE_VERSION,
		'limit_response_size'=>2 * MB_IN_BYTES,
	) );
	if ( is_wp_error( $response ) ) {
		return array( 'url'=>$url, 'code'=>0, 'type'=>'', 'body'=>'', 'headers'=>array(), 'ms'=>(int)round((microtime(true)-$start)*1000), 'error'=>$response->get_error_message() );
	}
	$headers = array();
	foreach ( array( 'set-cookie', 'cache-control', 'age', 'x-litespeed-cache' ) as $header_name ) {
		$value = wp_remote_retrieve_header( $response, $header_name );
		$headers[ $header_name ] = is_array( $value ) ? implode( '; ', array_map( 'strval', $value ) ) : (string) $value;
	}
	return array(
		'url'=>$url, 'code'=>(int)wp_remote_retrieve_response_code($response),
		'type'=>strtolower((string)wp_remote_retrieve_header($response,'content-type')),
		'body'=>(string)wp_remote_retrieve_body($response), 'headers'=>$headers,
		'ms'=>(int)round((microtime(true)-$start)*1000), 'error'=>'',
	);
}

/** Strict XML check without network/entity expansion. */
function go_verge_observatory_valid_xml_root( $body, $root ) {
	if ( ! function_exists( 'simplexml_load_string' ) || '' === trim( (string) $body ) ) {
		return false;
	}
	$previous = libxml_use_internal_errors( true );
	$xml      = simplexml_load_string( (string) $body, 'SimpleXMLElement', LIBXML_NONET );
	libxml_clear_errors();
	libxml_use_internal_errors( $previous );
	return $xml instanceof SimpleXMLElement && strtolower( $xml->getName() ) === strtolower( (string) $root );
}

/** Pure cache classifier kept separate so regression tests can cover headers. */
function go_verge_observatory_cache_probe_issues( $probe, $path ) {
	$issues = array();
	$code   = isset( $probe['code'] ) ? (int) $probe['code'] : 0;
	$headers = isset( $probe['headers'] ) && is_array( $probe['headers'] ) ? $probe['headers'] : array();
	$cookie = (string) ( $headers['set-cookie'] ?? '' );
	$cache  = strtolower( (string) ( $headers['cache-control'] ?? '' ) );
	if ( 200 !== $code ) {
		$issues[] = sprintf( '%s retornou HTTP %d', $path, $code );
		return $issues;
	}
	if ( false !== stripos( $cookie, 'PHPSESSID' ) ) {
		$issues[] = sprintf( '%s inicia PHPSESSID', $path );
	}
	if ( preg_match( '/(?:^|[,\s])(?:private|no-store|no-cache)(?:[,\s]|$)|(?:^|[,\s])max-age\s*=\s*0(?:[,\s]|$)/i', $cache ) ) {
		$issues[] = sprintf( '%s envia Cache-Control %s', $path, $cache );
	}
	return $issues;
}

/** Actual sitemap endpoint health, used by sitemap-smart.php's async test. */
function go_verge_observatory_sitemap_health_test() {
	$cached = get_transient( 'go_verge_observatory_sitemap_health_v355' );
	if ( is_array( $cached ) ) { return $cached; }
	$probe  = go_verge_observatory_fetch( '/sitemap.xml' );
	$issues = array();
	if ( 200 !== $probe['code'] ) { $issues[] = sprintf( 'HTTP %d em /sitemap.xml', $probe['code'] ); }
	if ( false === strpos( $probe['type'], 'xml' ) ) { $issues[] = 'Content-Type do índice não é XML'; }
	if ( ! go_verge_observatory_valid_xml_root( $probe['body'], 'sitemapindex' ) ) { $issues[] = 'XML inválido ou raiz sitemapindex ausente'; }
	if ( false !== strpos( $probe['body'], 'sitemap-tags.xml' ) ) { $issues[] = 'índice ainda anuncia o sitemap de tags noindex'; }
	$locs = array();
	if ( preg_match_all( '#<loc>([^<]+)</loc>#i', $probe['body'], $matches ) ) { $locs = array_map( 'html_entity_decode', $matches[1] ); }
	if ( count( $locs ) !== count( array_unique( array_map( 'strtolower', $locs ) ) ) ) { $issues[] = 'índice contém <loc> duplicado'; }
	foreach ( array( '/news-sitemap.xml', '/sitemap-posts.xml', '/sitemap-categories.xml' ) as $path ) {
		$child = go_verge_observatory_fetch( $path );
		if ( 200 !== $child['code'] || false === strpos( $child['type'], 'xml' ) || ! go_verge_observatory_valid_xml_root( $child['body'], 'urlset' ) ) {
			$issues[] = sprintf( '%s não respondeu como urlset XML 200', $path );
		}
	}
	$result = array(
		'label'=>$issues?__( 'O sitemap editorial falhou na validação real', 'go-verge' ):__( 'Sitemap editorial validado por loopback', 'go-verge' ),
		'status'=>$issues?'recommended':'good',
		'badge'=>array( 'label'=>__( 'Indexação', 'go-verge' ), 'color'=>$issues?'orange':'blue' ),
		'description'=>'<p>'.esc_html($issues?implode('; ',$issues):sprintf(__('Índice e filhos essenciais responderam em XML; índice principal: %d ms.','go-verge'),$probe['ms'])).'</p>',
		'actions'=>'<p><a href="'.esc_url(home_url('/sitemap.xml')).'" target="_blank" rel="noopener noreferrer">'.esc_html__('Abrir sitemap.xml','go-verge').'</a></p>',
		'test'=>'go_verge_smart_sitemap',
	);
	set_transient( 'go_verge_observatory_sitemap_health_v355', $result, 5 * MINUTE_IN_SECONDS );
	return $result;
}

/** Validate the deployed physical/virtual discovery files, not just PHP hooks. */
function go_verge_observatory_discovery_health_test() {
	$cached = get_transient( 'go_verge_observatory_discovery_health_v37744' );
	if ( is_array( $cached ) ) { return $cached; }
	$robots = go_verge_observatory_fetch( '/robots.txt' );
	$llms   = go_verge_observatory_fetch( '/llms.txt' );
	$issues = array();
	$main   = home_url( '/sitemap.xml' );
	if ( 200 !== $robots['code'] || false === strpos( $robots['type'], 'text/plain' ) ) { $issues[] = 'robots.txt não respondeu como texto 200'; }
	if ( false === strpos( $robots['body'], 'Sitemap: ' . $main ) ) { $issues[] = 'robots.txt não anuncia /sitemap.xml'; }
	if ( false === strpos( $robots['body'], 'Sitemap: ' . home_url( '/sitemap-fresh.xml' ) ) ) { $issues[] = 'robots.txt não anuncia /sitemap-fresh.xml'; }
	if ( preg_match( '#Sitemap:\s*\S+/(?:sitemap_index|wp-sitemap)\.xml#i', $robots['body'] ) ) { $issues[] = 'robots.txt anuncia um índice legado que redireciona'; }
	/* Search result pages already emit noindex,follow. Blocking them here keeps
	 * crawlers from seeing that directive and can leave URL-only results behind. */
	if ( preg_match( '#^Disallow:\s*/(?:\?s=|search/?)\s*$#mi', $robots['body'] ) ) { $issues[] = 'robots.txt bloqueia a busca interna antes que o noindex seja lido'; }
	/* llms.txt is optional interoperability metadata, not a Google Search/Discover/AI
	 * requirement. Validate it only when the endpoint is actually published; never
	 * downgrade site health merely because a host/plugin elects not to expose it. */
	$llms_published = 200 === $llms['code'] && false !== strpos( $llms['type'], 'text/plain' );
	if ( $llms_published ) {
		foreach ( array( '/dicas-e-guias/', '/category/', '?editoria=', home_url('/promocoes/'), '/politica-de-privacidade/', '/sitemap_index.xml', '/wp-sitemap.xml' ) as $legacy ) {
			if ( false !== strpos( $llms['body'], $legacy ) ) { $issues[] = sprintf( 'llms.txt contém destino não canônico: %s', $legacy ); }
		}
	}
	$result = array(
		'label'=>$issues?__( 'Arquivos de rastreamento publicados estão divergentes', 'go-verge' ):__( 'robots.txt usa o sitemap canônico; llms.txt é opcional', 'go-verge' ),
		'status'=>$issues?'recommended':'good',
		'badge'=>array( 'label'=>__( 'Rastreamento', 'go-verge' ), 'color'=>$issues?'orange':'blue' ),
		'description'=>'<p>'.esc_html($issues?implode('; ',$issues):__('O robots.txt efetivamente servido passou nas verificações de rastreamento e sitemap; quando publicado, llms.txt também usa apenas destinos canônicos.','go-verge')).'</p>',
		'actions'=>'<p><a href="'.esc_url(admin_url('tools.php?page=go-search-observatory')).'">'.esc_html__('Abrir Search Observatory','go-verge').'</a></p>',
		'test'=>'go_verge_discovery_files',
	);
	set_transient( 'go_verge_observatory_discovery_health_v37744', $result, 5 * MINUTE_IN_SECONDS );
	return $result;
}

/** Detect a plugin/host starting sessions on cacheable public landing pages. */
function go_verge_observatory_cache_health_test() {
	$cached = get_transient( 'go_verge_observatory_cache_health_v355' );
	if ( is_array( $cached ) ) { return $cached; }
	$issues = array();
	foreach ( array( '/', '/ultimas-publicacoes/', '/guias-de-compra/' ) as $path ) {
		$p = go_verge_observatory_fetch( $path );
		$issues = array_merge( $issues, go_verge_observatory_cache_probe_issues( $p, $path ) );
	}
	$result = array(
		'label'=>$issues?__( 'Páginas públicas estão perdendo cache', 'go-verge' ):__( 'Hubs públicos não abrem sessão PHP', 'go-verge' ),
		'status'=>$issues?'critical':'good',
		'badge'=>array( 'label'=>__( 'Performance', 'go-verge' ), 'color'=>$issues?'red':'blue' ),
		'description'=>'<p>'.esc_html($issues?implode('; ',$issues):__('Home, últimas publicações e guias de compra não enviaram PHPSESSID/private/no-store.','go-verge')).'</p>'.($issues?'<p>'.esc_html__('O tema não remove esses headers por segurança: localize o plugin, MU-plugin ou regra do host que inicia a sessão.','go-verge').'</p>':''),
		'test'=>'go_verge_public_cacheability',
	);
	set_transient( 'go_verge_observatory_cache_health_v355', $result, 5 * MINUTE_IN_SECONDS );
	return $result;
}

function go_verge_observatory_health_tests( $tests ) {
	$tests['async']['go_verge_discovery_files'] = array(
		'label'=>__( 'Arquivos públicos de descoberta', 'go-verge' ),
		'test'=>'go_verge_observatory_discovery_health_test',
		'has_rest'=>false,
		'async_direct_test'=>'go_verge_observatory_discovery_health_test',
	);
	$tests['async']['go_verge_public_cacheability'] = array(
		'label'=>__( 'Cacheabilidade dos hubs públicos', 'go-verge' ),
		'test'=>'go_verge_observatory_cache_health_test',
		'has_rest'=>false,
		'async_direct_test'=>'go_verge_observatory_cache_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_observatory_health_tests', 200 );

/** Read-only control panel; mutations remain in their purpose-built tools. */
function go_verge_observatory_admin_menu() {
	add_management_page( __( 'Search Observatory', 'go-verge' ), __( 'Search Observatory', 'go-verge' ), 'manage_options', 'go-search-observatory', 'go_verge_observatory_admin_page' );
}
add_action( 'admin_menu', 'go_verge_observatory_admin_menu', 52 );

function go_verge_observatory_admin_page() {
	if ( ! current_user_can( 'manage_options' ) ) { return; }
	$root_robots = defined( 'ABSPATH' ) ? trailingslashit( ABSPATH ) . 'robots.txt' : '';
	$root_llms   = defined( 'ABSPATH' ) ? trailingslashit( ABSPATH ) . 'llms.txt' : '';
	?>
	<div class="wrap"><h1><?php esc_html_e( 'Search Observatory', 'go-verge' ); ?></h1>
	<p><?php esc_html_e( 'Diagnóstico unificado de rastreamento, sitemaps, mapa opcional para agentes e cache público. As verificações HTTP reais ficam em Ferramentas → Saúde do site.', 'go-verge' ); ?></p>
	<table class="widefat striped" style="max-width:1000px"><thead><tr><th><?php esc_html_e( 'Superfície', 'go-verge' ); ?></th><th>URL</th><th><?php esc_html_e( 'Contrato', 'go-verge' ); ?></th></tr></thead><tbody>
	<tr><td>Sitemap</td><td><a href="<?php echo esc_url( home_url('/sitemap.xml') ); ?>" target="_blank" rel="noopener">/sitemap.xml</a></td><td>200 application/xml; índice canônico único</td></tr>
	<tr><td>News</td><td><a href="<?php echo esc_url( home_url('/news-sitemap.xml') ); ?>" target="_blank" rel="noopener">/news-sitemap.xml</a></td><td>Somente NewsArticle canônico das últimas 48h</td></tr>
	<tr><td>robots.txt</td><td><a href="<?php echo esc_url( home_url('/robots.txt') ); ?>" target="_blank" rel="noopener">/robots.txt</a></td><td><?php echo esc_html( $root_robots && is_readable($root_robots) ? $root_robots : __('virtual via WordPress','go-verge') ); ?></td></tr>
	<tr><td>llms.txt</td><td><a href="<?php echo esc_url( home_url('/llms.txt') ); ?>" target="_blank" rel="noopener">/llms.txt</a></td><td><?php echo esc_html( $root_llms && is_readable($root_llms) ? $root_llms : __('fallback canônico do tema','go-verge') ); ?></td></tr>
	</tbody></table>
	<p><a class="button button-primary" href="<?php echo esc_url( admin_url('site-health.php?tab=status') ); ?>"><?php esc_html_e( 'Executar verificações reais no Site Health', 'go-verge' ); ?></a> <a class="button" href="<?php echo esc_url( admin_url('tools.php?page=go-sitemap-intelligence') ); ?>"><?php esc_html_e( 'Abrir Sitemap Intelligence', 'go-verge' ); ?></a></p>
	<p><?php esc_html_e( 'Modelos para servidores que exigem arquivos físicos ficam em deployment/robots.txt e deployment/llms.txt dentro do tema. Prefira o robots.txt virtual do WordPress quando possível; llms.txt é apenas um mapa opcional para outros agentes e não substitui sitemap, robots, canonical ou dados estruturados.', 'go-verge' ); ?></p></div>
	<?php
}
