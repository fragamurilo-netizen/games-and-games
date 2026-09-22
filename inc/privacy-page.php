<?php
/**
 * Managed institutional Privacy Policy page.
 *
 * Creates the page only when it is missing and never overwrites text that an
 * editor has changed manually. It also keeps the page discoverable in custom
 * footer menus and registers it as WordPress's privacy policy page when no
 * other valid page has already been selected.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Return the approved Privacy Policy HTML bundled with the theme. */
function go_verge_privacy_policy_content() {
	return <<<'HTML'
<p class="go-policy-meta"><strong>Última atualização:</strong> 19/07/2026</p>
<p>O Game Overdrive (<a href="https://gameoverdrive.com.br">https://gameoverdrive.com.br</a>) é um portal brasileiro de notícias, análises, guias e ofertas sobre games e cultura pop. Esta Política explica quais dados pessoais tratamos, por que tratamos, com quem eventualmente compartilhamos e como você pode exercer seus direitos, conforme a Lei nº 13.709/2018 (Lei Geral de Proteção de Dados — LGPD).</p>
<p>Ao navegar pelo site, você declara ter lido e compreendido este documento.</p>
<p>Dúvidas, solicitações ou pedidos relacionados aos seus dados: <strong><a href="mailto:contato@gameoverdrive.com.br">contato@gameoverdrive.com.br</a></strong>.</p>
<h2 id="1-glossário-rápido">1. Glossário rápido</h2>
<div class="go-policy-table-wrap" role="region" aria-label="Tabela da Política de Privacidade" tabindex="0">
<table>
<thead>
<tr>
<th>Termo</th>
<th>O que significa aqui</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>Dado pessoal</strong></td>
<td>Qualquer informação que identifique ou possa identificar você (nome, e-mail, IP, identificadores de dispositivo).</td>
</tr>
<tr>
<td><strong>Tratamento</strong></td>
<td>Qualquer operação com esses dados: coleta, armazenamento, uso, compartilhamento, exclusão etc.</td>
</tr>
<tr>
<td><strong>Titular</strong></td>
<td>Você, a pessoa a quem os dados se referem.</td>
</tr>
<tr>
<td><strong>Operador</strong></td>
<td>Terceiro que trata dados em nosso nome (por exemplo, um serviço de hospedagem ou de e-mail marketing).</td>
</tr>
<tr>
<td><strong>Base legal</strong></td>
<td>A hipótese prevista na LGPD que autoriza cada tratamento.</td>
</tr>
<tr>
<td><strong>Consentimento</strong></td>
<td>Sua autorização livre, informada e específica, que pode ser revogada a qualquer momento.</td>
</tr>
</tbody>
</table>
</div>
<h2 id="2-quais-dados-coletamos">2. Quais dados coletamos</h2>
<h3 id="21-dados-que-você-nos-fornece">2.1 Dados que você nos fornece</h3>
<p>Coletamos apenas o que é necessário para cada interação:</p>
<ul>
<li><strong>Newsletter:</strong> endereço de e-mail e, opcionalmente, nome.</li>
<li><strong>Comentários:</strong> nome ou apelido, e-mail, site (se informado), conteúdo do comentário e endereço IP no momento do envio.</li>
<li><strong>Formulários de contato, pauta, correções ou parcerias:</strong> nome, e-mail e o conteúdo da mensagem, incluindo qualquer dado que você decida incluir nela.</li>
<li><strong>Promoções, sorteios e ações com parceiros:</strong> os dados descritos no regulamento específico de cada ação, que prevalece sobre esta Política quanto ao escopo daquela coleta.</li>
</ul>
<p>Não solicitamos CPF, documentos ou dados financeiros para a simples navegação e leitura do site.</p>
<h3 id="22-dados-coletados-automaticamente">2.2 Dados coletados automaticamente</h3>
<p>Ao acessar o site, alguns dados são registrados de forma automática:</p>
<ul>
<li>endereço IP e dados aproximados de localização derivados dele (cidade/estado);</li>
<li>data, hora e duração do acesso; páginas visitadas e caminho de navegação;</li>
<li>origem do acesso (site de referência, mecanismo de busca, redes sociais, newsletter);</li>
<li>tipo e versão do navegador, sistema operacional, tipo de dispositivo e resolução de tela;</li>
<li>identificadores de cookies e tecnologias similares;</li>
<li>registros técnicos de segurança, incluindo sinais usados para distinguir tráfego humano de tráfego automatizado (bots).</li>
</ul>
<p>Esses dados são usados de forma majoritariamente agregada e estatística.</p>
<h2 id="3-para-que-usamos-os-dados-e-com-que-base-legal">3. Para que usamos os dados e com que base legal</h2>
<div class="go-policy-table-wrap" role="region" aria-label="Tabela da Política de Privacidade" tabindex="0">
<table>
<thead>
<tr>
<th>Finalidade</th>
<th>Base legal (LGPD)</th>
</tr>
</thead>
<tbody>
<tr>
<td>Exibir e entregar o conteúdo do site, manter o funcionamento técnico e a estabilidade das páginas</td>
<td>Legítimo interesse (art. 7º, IX)</td>
</tr>
<tr>
<td>Medir audiência, entender quais conteúdos são lidos e melhorar a experiência de navegação</td>
<td>Legítimo interesse / consentimento para cookies não essenciais</td>
</tr>
<tr>
<td>Enviar newsletter e comunicações editoriais</td>
<td>Consentimento (art. 7º, I)</td>
</tr>
<tr>
<td>Publicar e moderar comentários</td>
<td>Execução da relação com o usuário e legítimo interesse</td>
</tr>
<tr>
<td>Responder mensagens de contato, sugestões de pauta, correções e propostas comerciais</td>
<td>Legítimo interesse / procedimentos preliminares de contrato</td>
</tr>
<tr>
<td>Exibir publicidade e mensurar campanhas</td>
<td>Consentimento (para cookies de publicidade) e legítimo interesse</td>
</tr>
<tr>
<td>Operar links de ofertas e programas de afiliados</td>
<td>Legítimo interesse</td>
</tr>
<tr>
<td>Prevenir fraudes, abusos, spam e ataques; proteger a integridade do site</td>
<td>Legítimo interesse (art. 7º, IX) e segurança</td>
</tr>
<tr>
<td>Cumprir obrigações legais, inclusive a guarda de registros de acesso prevista no Marco Civil da Internet</td>
<td>Cumprimento de obrigação legal (art. 7º, II)</td>
</tr>
<tr>
<td>Exercer direitos em processo judicial, administrativo ou arbitral</td>
<td>Art. 7º, VI</td>
</tr>
</tbody>
</table>
</div>
<p>Não utilizamos seus dados para decisões automatizadas que produzam efeitos jurídicos sobre você, nem tratamos intencionalmente dados pessoais sensíveis.</p>
<h2 id="4-cookies-e-tecnologias-similares">4. Cookies e tecnologias similares</h2>
<p>Cookies são pequenos arquivos gravados no seu navegador. No Overdrive eles se dividem em quatro grupos:</p>
<ol type="1">
<li><strong>Essenciais</strong> — necessários para o site funcionar (sessão, preferências básicas, segurança, tema claro/escuro). Não podem ser desativados sem prejudicar a navegação.</li>
<li><strong>De preferências</strong> — guardam escolhas suas, como idioma, tema e ajustes de exibição.</li>
<li><strong>Analíticos</strong> — permitem entender, de forma agregada, quantas pessoas acessam o site e quais conteúdos têm mais audiência. Utilizamos ferramentas como <strong>Google Analytics</strong> e <strong>Google Search Console</strong>, além de métricas internas do próprio portal.</li>
<li><strong>Publicitários</strong> — usados por redes de anúncios para exibir publicidade, controlar a frequência e mensurar resultados. Veja a seção 5.</li>
</ol>
<p>Você pode gerenciar suas preferências pelo banner de cookies do site (quando disponível) e, a qualquer momento, apagar ou bloquear cookies nas configurações do seu navegador — Chrome, Firefox, Safari, Edge e outros oferecem essa opção nas seções de privacidade. Bloquear determinados cookies pode limitar funcionalidades do site.</p>
<h2 id="5-publicidade">5. Publicidade</h2>
<p>O Game Overdrive é um veículo gratuito, sustentado por publicidade. Para viabilizar isso, trabalhamos com serviços de anúncios fornecidos por terceiros, entre eles o <strong>Google AdSense</strong> e demais produtos de publicidade do Google, além de eventuais redes e anunciantes diretos.</p>
<p><strong>Como os anúncios são escolhidos.</strong> Parte da publicidade é <strong>contextual</strong>, ou seja, definida pelo conteúdo da página que você está lendo — uma análise de um jogo pode exibir anúncios relacionados a games. Outra parte pode ser <strong>personalizada</strong>, considerando informações como seu histórico de navegação em sites parceiros do Google, localização aproximada e interesses inferidos. Para isso, esses terceiros podem gravar e ler cookies próprios no seu navegador, aos quais o Overdrive não tem acesso direto.</p>
<p><strong>O que não fazemos.</strong> Não vendemos os seus dados. Não coletamos nem compartilhamos informações que identifiquem você pessoalmente a partir de cookies de veiculação de anúncios sem o seu consentimento explícito.</p>
<p><strong>Como você controla isso.</strong> Você tem meios de gerenciar a publicidade que recebe:</p>
<ul>
<li><strong>Banner de cookies do site:</strong> recuse ou revogue o consentimento para cookies publicitários a qualquer momento.</li>
<li><strong>Configurações de anúncios do Google:</strong> em <a href="https://myadcenter.google.com">https://myadcenter.google.com</a> você pode desativar a personalização de anúncios, ver quais interesses estão associados a você e bloquear anunciantes específicos.</li>
<li><strong>Navegador:</strong> bloqueio ou exclusão de cookies de terceiros nas configurações de privacidade.</li>
<li><strong>Iniciativas do setor:</strong> ferramentas de opt-out coletivo, como as da Network Advertising Initiative (<a href="https://optout.networkadvertising.org">https://optout.networkadvertising.org</a>) e da DAA (<a href="https://optout.aboutads.info">https://optout.aboutads.info</a>).</li>
</ul>
<p>Desativar a personalização não elimina os anúncios — eles apenas passam a ser menos relevantes para você.</p>
<p>Para entender como o Google trata dados em sua rede de publicidade, consulte:</p>
<ul>
<li>Publicidade — Privacidade &amp; Termos do Google: <a href="https://policies.google.com/technologies/ads">https://policies.google.com/technologies/ads</a></li>
<li>Como o Google usa informações de sites que utilizam seus serviços: <a href="https://policies.google.com/technologies/partner-sites">https://policies.google.com/technologies/partner-sites</a></li>
</ul>
<h2 id="6-ofertas-e-links-de-afiliados">6. Ofertas e links de afiliados</h2>
<ul>
<li>Nas seções de ofertas e nos blocos do tipo "Onde comprar", alguns links são <strong>de afiliado</strong>: se você comprar por meio deles, o Overdrive pode receber uma comissão, <strong>sem custo adicional para você</strong>. Isso não influencia notas, opiniões ou o julgamento editorial das nossas análises.</li>
<li>Esses links podem conter identificadores que permitem ao lojista atribuir a visita ao nosso site. O tratamento dos seus dados a partir do momento em que você entra na loja é responsabilidade dela.</li>
<li>Preços e disponibilidade exibidos são obtidos de lojas e serviços de terceiros e podem estar desatualizados no momento da sua visita.</li>
<li><strong>Conteúdo patrocinado e publieditorial</strong>, quando houver, é sinalizado de forma clara na própria publicação.</li>
</ul>
<h2 id="7-com-quem-compartilhamos-dados">7. Com quem compartilhamos dados</h2>
<p>Não vendemos dados pessoais. O compartilhamento ocorre apenas quando necessário, com:</p>
<ul>
<li><strong>Provedores de infraestrutura</strong>: hospedagem, CDN, segurança, backup e envio de e-mails;</li>
<li><strong>Ferramentas de medição de audiência</strong> e de desempenho em buscadores;</li>
<li><strong>Redes de publicidade e parceiros de afiliados</strong>, nos termos das seções 5 e 6;</li>
<li><strong>Plataformas de newsletter</strong>, quando você opta por recebê-la;</li>
<li><strong>Autoridades públicas</strong>, mediante requisição legal, ordem judicial ou para exercício regular de direitos.</li>
</ul>
<p>Alguns desses fornecedores estão sediados no exterior, o que implica <strong>transferência internacional de dados</strong>. Nesses casos, buscamos parceiros que adotem padrões adequados de proteção e cláusulas contratuais compatíveis com a LGPD.</p>
<h2 id="8-por-quanto-tempo-guardamos">8. Por quanto tempo guardamos</h2>
<ul>
<li><strong>Registros de acesso (logs):</strong> pelo prazo mínimo legal de 6 meses previsto no Marco Civil da Internet, podendo ser mantidos por período maior para segurança ou defesa de direitos.</li>
<li><strong>Comentários:</strong> enquanto publicados, salvo pedido de exclusão.</li>
<li><strong>Newsletter:</strong> até você cancelar a inscrição.</li>
<li><strong>Mensagens de contato:</strong> pelo tempo necessário ao atendimento e eventual histórico da tratativa.</li>
<li><strong>Dados analíticos:</strong> conforme a política de retenção da ferramenta utilizada, majoritariamente de forma agregada.</li>
</ul>
<p>Encerrada a finalidade, os dados são eliminados ou anonimizados, exceto quando houver obrigação legal de guarda ou necessidade de exercício de direitos.</p>
<h2 id="9-segurança">9. Segurança</h2>
<p>Adotamos medidas técnicas e administrativas razoáveis para proteger os dados: conexão criptografada (HTTPS), controle de acesso ao painel administrativo, atualizações periódicas de plataforma e plugins, backups e monitoramento de tráfego suspeito. Nenhum sistema é totalmente imune a incidentes; em caso de incidente relevante, comunicaremos os titulares afetados e a ANPD nos termos da lei.</p>
<h2 id="10-seus-direitos">10. Seus direitos</h2>
<p>Você pode, a qualquer momento, solicitar:</p>
<ul>
<li><strong>confirmação</strong> da existência de tratamento e <strong>acesso</strong> aos seus dados;</li>
<li><strong>correção</strong> de dados incompletos, inexatos ou desatualizados;</li>
<li><strong>anonimização, bloqueio ou eliminação</strong> de dados desnecessários, excessivos ou tratados em desconformidade com a lei;</li>
<li><strong>portabilidade</strong> a outro fornecedor;</li>
<li><strong>eliminação</strong> de dados tratados com base no consentimento;</li>
<li><strong>informação</strong> sobre com quem compartilhamos seus dados;</li>
<li><strong>informação</strong> sobre a possibilidade de não fornecer consentimento e suas consequências;</li>
<li><strong>revogação do consentimento</strong>;</li>
<li><strong>oposição</strong> a tratamentos baseados em legítimo interesse;</li>
<li><strong>revisão</strong> de decisões automatizadas, quando aplicável.</li>
</ul>
<p>Para exercer qualquer desses direitos, escreva para <strong><a href="mailto:contato@gameoverdrive.com.br">contato@gameoverdrive.com.br</a></strong>. Podemos solicitar informações adicionais para confirmar sua identidade antes de atender ao pedido — é uma medida de proteção contra fraudes. Responderemos em prazo razoável e, nos casos em que a lei permitir a recusa (segredo comercial, obrigação legal de retenção, direitos de terceiros), explicaremos o motivo.</p>
<p>Você também pode apresentar reclamação à <strong>Autoridade Nacional de Proteção de Dados (ANPD)</strong>.</p>
<h2 id="11-crianças-e-adolescentes">11. Crianças e adolescentes</h2>
<p>O conteúdo do Game Overdrive é dirigido ao público geral interessado em games, mas não coletamos intencionalmente dados de crianças e adolescentes sem o consentimento específico e em destaque de ao menos um dos pais ou responsável legal, conforme o art. 14 da LGPD. Se identificarmos coleta indevida — ou se um responsável nos comunicar pelo e-mail <strong><a href="mailto:contato@gameoverdrive.com.br">contato@gameoverdrive.com.br</a></strong> —, os dados serão eliminados.</p>
<h2 id="12-links-para-sites-de-terceiros">12. Links para sites de terceiros</h2>
<p>O site contém links para lojas, redes sociais, vídeos, distribuidoras e outros portais. Ao clicar, você passa a se relacionar diretamente com esses terceiros, sujeitando-se às políticas de privacidade deles. O Game Overdrive não controla nem se responsabiliza pelas práticas de privacidade desses sites.</p>
<h2 id="13-alterações-desta-política">13. Alterações desta Política</h2>
<p>Esta Política pode ser atualizada para refletir mudanças no site, em nossas ferramentas ou na legislação. A data da última revisão fica sempre indicada no topo do documento. Alterações relevantes serão sinalizadas no próprio site. Recomendamos revisitar esta página periodicamente.</p>
<h2 id="14-contato">14. Contato</h2>
<p>Dúvidas sobre esta Política ou sobre o tratamento dos seus dados: <strong><a href="mailto:contato@gameoverdrive.com.br">contato@gameoverdrive.com.br</a></strong>.</p>
<p><em>Este documento é regido pelas leis da República Federativa do Brasil.</em></p>
HTML;
}

/** Return the public Privacy Policy page when available. */
function go_verge_privacy_policy_page() {
	$page = get_page_by_path( 'privacidade', OBJECT, 'page' );
	return $page instanceof WP_Post ? $page : null;
}

/** Return the canonical public URL used by the footer and integrations. */
function go_verge_privacy_policy_url() {
	$page = go_verge_privacy_policy_page();
	if ( $page instanceof WP_Post && 'publish' === $page->post_status ) {
		return get_permalink( $page );
	}
	return home_url( '/privacidade/' );
}

/** Consolidate the former privacy slug into the managed canonical page. */
function go_verge_redirect_legacy_privacy_policy() {
	if ( is_admin() || wp_doing_ajax() ) {
		return;
	}
	$path = trim( (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH ), '/' );
	if ( 'politica-de-privacidade' !== $path ) {
		return;
	}
	$page = go_verge_privacy_policy_page();
	if ( ! ( $page instanceof WP_Post ) || 'publish' !== $page->post_status ) {
		return;
	}
	wp_safe_redirect( get_permalink( $page ), 301, 'Overdrive privacy canonical' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_legacy_privacy_policy', -30 );

/**
 * Create or safely seed the institutional Privacy Policy page.
 *
 * Existing editorial copy is preserved. A future bundled revision may replace
 * only content that still matches the hash previously generated by the theme.
 */
function go_verge_prepare_privacy_policy_page() {
	/* admin_init also fires for every admin-ajax poll and Heartbeat; rebuilding and
	 * hashing the policy there only repeats what the next admin screen does. */
	if ( wp_doing_ajax() ) {
		return;
	}
	$content      = go_verge_privacy_policy_content();
	$content_hash = md5( $content );
	$excerpt      = 'Como o Game Overdrive coleta, utiliza, compartilha e protege dados pessoais, cookies e informações de navegação conforme a LGPD.';
	$page         = go_verge_privacy_policy_page();
	$page_id      = 0;

	if ( ! $page instanceof WP_Post ) {
		$result = wp_insert_post(
			array(
				'post_type'      => 'page',
				'post_status'    => 'publish',
				'post_title'     => 'Política de Privacidade',
				'post_name'      => 'privacidade',
				'post_excerpt'   => $excerpt,
				'post_content'   => $content,
				'comment_status' => 'closed',
				'ping_status'    => 'closed',
			),
			true
		);

		if ( is_wp_error( $result ) ) {
			return;
		}

		$page_id = absint( $result );
		update_post_meta( $page_id, '_go_verge_privacy_content_hash', $content_hash );
	} else {
		$page_id          = absint( $page->ID );
		$current_content  = (string) $page->post_content;
		$current_hash     = md5( $current_content );
		$managed_hash     = (string) get_post_meta( $page_id, '_go_verge_privacy_content_hash', true );
		$has_placeholders = false !== strpos( $current_content, '[DD/MM/AAAA]' ) || false !== strpos( $current_content, '[e-mail]' );
		$is_empty         = '' === trim( wp_strip_all_tags( $current_content ) );
		$is_managed       = '' !== $managed_hash && hash_equals( $managed_hash, $current_hash );
		$changes          = array( 'ID' => $page_id );

		if ( $is_empty || $has_placeholders || ( $is_managed && ! hash_equals( $current_hash, $content_hash ) ) ) {
			$changes['post_content'] = $content;
			$changes['post_title']   = 'Política de Privacidade';
			update_post_meta( $page_id, '_go_verge_privacy_content_hash', $content_hash );
		}

		$current_excerpt = trim( (string) $page->post_excerpt );
		if ( '' === $current_excerpt || 'Como o Overdrive coleta, utiliza, compartilha e protege dados pessoais, cookies e informações de navegação conforme a LGPD.' === $current_excerpt ) {
			$changes['post_excerpt'] = $excerpt;
		}

		if ( 'closed' !== $page->comment_status ) {
			$changes['comment_status'] = 'closed';
		}
		if ( 'closed' !== $page->ping_status ) {
			$changes['ping_status'] = 'closed';
		}

		if ( count( $changes ) > 1 ) {
			wp_update_post( wp_slash( $changes ) );
		}
	}

	if ( ! $page_id ) {
		return;
	}

	// Preserve editorial customizations, but migrate the theme's own old short-brand defaults.
	$site_name     = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Game Overdrive';
	$current_title = (string) get_post_meta( $page_id, 'rank_math_title', true );
	$current_desc  = (string) get_post_meta( $page_id, 'rank_math_description', true );
	if ( '' === $current_title || 'Política de Privacidade | Overdrive' === $current_title ) {
		update_post_meta( $page_id, 'rank_math_title', sprintf( 'Política de Privacidade | %s', $site_name ) );
	}
	if ( '' === $current_desc || 'Saiba como o Overdrive coleta, utiliza, armazena e protege dados pessoais, cookies e informações de navegação conforme a LGPD.' === $current_desc ) {
		update_post_meta( $page_id, 'rank_math_description', sprintf( 'Saiba como o %s coleta, utiliza, armazena e protege dados pessoais, cookies e informações de navegação conforme a LGPD.', $site_name ) );
	}

	// Do not replace another valid privacy page already selected in WordPress.
	$configured_id = absint( get_option( 'wp_page_for_privacy_policy' ) );
	if ( ! $configured_id || 'publish' !== get_post_status( $configured_id ) ) {
		update_option( 'wp_page_for_privacy_policy', $page_id );
	}
}
add_action( 'after_switch_theme', 'go_verge_prepare_privacy_policy_page', 46 );
add_action( 'admin_init', 'go_verge_prepare_privacy_policy_page', 46 );

/** Ensure the page is visible even when a custom footer menu is assigned. */
function go_verge_append_privacy_policy_to_footer_menu( $items, $args ) {
	if ( empty( $args->theme_location ) || 'footer' !== $args->theme_location ) {
		return $items;
	}

	$page = go_verge_privacy_policy_page();
	if ( ! $page instanceof WP_Post || 'publish' !== $page->post_status ) {
		return $items;
	}

	$url = get_permalink( $page );
	if (
		false !== strpos( (string) $items, (string) $url )
		|| false !== strpos( (string) $items, '/privacidade/' )
	) {
		return $items;
	}

	$items .= sprintf(
		'<li class="menu-item go-menu-item-privacy-policy"><a href="%1$s">%2$s</a></li>',
		esc_url( $url ),
		esc_html__( 'Política de Privacidade', 'go-verge' )
	);

	return $items;
}
add_filter( 'wp_nav_menu_items', 'go_verge_append_privacy_policy_to_footer_menu', 24, 2 );
