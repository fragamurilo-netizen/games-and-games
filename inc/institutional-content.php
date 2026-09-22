<?php
/**
 * Approved institutional copy imported from the editorial Markdown drafts.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Return the approved institutional pages as HTML.
 *
 * @return array<string,array{title:string,content:string}>
 */
function go_verge_institutional_pages_content() {
	$contact_email = function_exists( 'go_verge_publisher_contact_email' ) && go_verge_publisher_contact_email() ? go_verge_publisher_contact_email() : 'contato@gameoverdrive.com.br';
	$x_url         = function_exists( 'go_verge_publisher_social_url' ) && go_verge_publisher_social_url( 'x' ) ? go_verge_publisher_social_url( 'x' ) : 'https://x.com/gameoverdrivebr';
	$contact_link  = '<a href="mailto:' . esc_attr( $contact_email ) . '">' . esc_html( $contact_email ) . '</a>';
	$x_link        = '<a href="' . esc_url( $x_url ) . '" target="_blank" rel="noopener noreferrer">Overdrive no X</a>';

	return array(
		'sobre-o-overdrive' => array(
			'title'   => 'Sobre o Overdrive',
			'content' => '<p>O Game Overdrive existe porque a gente cansou de ler sobre jogos em texto que parece bula de remédio.</p>
<p>Somos um portal brasileiro de games, entretenimento e tecnologia, fundado em 2024. Cobrimos lançamentos, séries, filmes, streaming, produtos e tendências, além de reviews e guias, sempre com contexto para o público brasileiro.</p>
<p>O site é conduzido por Gregory Felipe e Murilo Rodrigues, fundadores e editores-chefes, com Deco Campos na equipe editorial. A proposta editorial é simples: tratar games, entretenimento e tecnologia com rigor de apuração, opinião assinada e texto que respeite o tempo de quem lê.</p>
<h2>Como a gente trabalha</h2>
<p>Todo review publicado aqui foi jogado de verdade. Quando recebemos código de análise de distribuidora ou estúdio, avisamos no texto. Quando compramos o jogo do nosso bolso, também foi jogado do mesmo jeito. A diferença é só quem pagou o boleto.</p>
<p>Nota não é matemática. É opinião de quem jogou, defendida com argumento. Você pode discordar da gente, e tudo bem: um review que não gera discussão provavelmente não disse nada.</p>
<p>Nos guias, o compromisso é outro: testamos os passos antes de publicar. Se um guia nosso estiver desatualizado depois de um patch, avise. Corrigimos e marcamos a data da atualização no texto.</p>
<h2>Quem assina</h2>
<p>Cada matéria do Game Overdrive tem autor com nome e página própria. O histórico de cada pessoa fica disponível na página de autor, e a equipe publicada no site pode ser consultada em <a href="/autores/">Autores</a>.</p>
<p>A assinatura importa porque notícia, guia, crítica e review têm responsabilidade editorial. Quem escreve responde pelo texto, e o leitor consegue consultar o que aquela pessoa já publicou.</p>
<h2>Fale com a gente</h2>
<p>Erramos algo? Achou um bug no site? Quer sugerir uma pauta? A página de <a href="/contato/">Contato</a> tem os caminhos. A gente lê tudo, mesmo que nem sempre responda rápido.</p>
<p>Nossa <a href="/politica-editorial/">Política Editorial</a> explica em detalhe como lidamos com reviews, publieditorial, correções, fontes e uso de ferramentas no dia a dia da redação.</p>',
		),
		'contato' => array(
			'title'   => 'Contato',
			'content' => '<p>Fale direto com a redação. Escolha o caminho certo e a mensagem chega com o contexto necessário.</p>
<h2>Sugestão de pauta</h2>
<p>Viu algo que a gente deveria cobrir? Escreva para ' . $contact_link . ' com um resumo do assunto e, se tiver, o link da fonte. Não precisa de formalidade: duas linhas bastam.</p>
<h2>Correções</h2>
<p>Erramos um dado, um nome ou uma data? Envie para ' . $contact_link . ' o link da matéria e o trecho que precisa de revisão. Correção confirmada entra no ar com nota de atualização no próprio texto quando a mudança for relevante.</p>
<h2>Assessorias e estúdios</h2>
<p>Envio de códigos de análise, convites para eventos e material de imprensa: ' . $contact_link . '. Receber código não garante cobertura nem influencia nota. Nossa <a href="/politica-editorial/">Política Editorial</a> explica como isso funciona.</p>
<h2>Publicidade e parcerias</h2>
<p>Propostas comerciais também podem ser enviadas para ' . $contact_link . '. Conteúdo pago precisa ser identificado de forma clara. Propostas que dependam de disfarçar publicidade de matéria não são aceitas.</p>
<h2>Problemas técnicos no site</h2>
<p>Página quebrada, erro de layout ou link morto: mande o endereço da página para ' . $contact_link . '. Se puder informar aparelho, sistema e navegador, melhor ainda.</p>
<h2>Redes sociais</h2>
<p>O Game Overdrive também está em ' . $x_link . '. Para correção, pauta, imprensa ou assunto comercial, o e-mail continua sendo o canal mais seguro.</p>',
		),
		'politica-editorial' => array(
			'title'   => 'Política Editorial',
			'content' => '<p>Este documento explica como o Overdrive produz conteúdo. Está aqui para você cobrar a gente quando não cumprirmos o que prometemos.</p>
<h2>Reviews</h2>
<p><strong>Jogamos antes de opinar.</strong> Todo review é baseado em tempo real de jogo, no hardware informado no texto. Quando não terminamos o jogo antes de publicar, algo que pode acontecer em RPGs muito longos ou em janelas de embargo curtas, dizemos isso abertamente e informamos quanto jogamos.</p>
<p><strong>Códigos de análise não compram nota.</strong> Estúdios e distribuidoras podem enviar cópias gratuitas para análise, prática comum na imprensa de games. Sempre que um review foi feito com código cedido, isso deve estar indicado no texto. A nota não muda por causa disso.</p>
<p><strong>Nota é opinião do autor, não consenso automático da redação.</strong> O nome que assina é quem jogou e quem responde pela avaliação.</p>
<p><strong>Embargos são respeitados, condições não editoriais não.</strong> Aceitamos datas de embargo. Não aceitamos acordo que condicione cobertura a nota mínima, tom positivo ou omissão de defeitos.</p>
<h2>Publicidade e conteúdo pago</h2>
<p>Conteúdo pago é identificado de forma clara como publicidade, parceria comercial ou publieditorial, conforme o formato. Links afiliados, quando existirem, são sinalizados na página. Se você comprar por eles, o site pode receber comissão, sem alterar o preço para você nem a nossa opinião editorial.</p>
<p>Anunciante não lê matéria antes de publicar, não aprova pauta e não veta crítica. Quem banca o site não manda no site.</p>
<h2>Correções e atualizações</h2>
<p>Erro factual confirmado é corrigido no próprio texto, com nota de atualização datada quando a mudança for relevante. Não apagamos matérias para esconder erro. Mudanças importantes de contexto, como jogo alterado por patch ou promoção encerrada, também podem receber nota de atualização.</p>
<p>Achou um erro? A página de <a href="/contato/">Contato</a> tem o canal certo.</p>
<h2>Uso de ferramentas e IA</h2>
<p>Todo texto publicado no Overdrive passa por redator humano, que responde pelo conteúdo com nome e página de autor. Ferramentas de IA podem ser usadas como apoio em tarefas como transcrição, organização de dados, revisão, pesquisa interna, acessibilidade de imagens e apoio operacional. Elas não substituem a responsabilidade editorial de quem assina.</p>
<p>Reviews, críticas e opiniões são responsabilidade de autores humanos. Nenhum texto deve ir ao ar sem edição e verificação humana.</p>
<h2>Fontes e apuração</h2>
<p>Notícia tem fonte. Quando a informação vem de terceiros, linkamos a origem sempre que possível. Rumor é tratado como rumor e nunca como fato confirmado. Se uma informação não puder ser verificada nem atribuída, ela não deve ser publicada como fato.</p>
<h2>Independência</h2>
<p>O Game Overdrive é um portal editorial independente e não pertence a distribuidora, estúdio ou fabricante de hardware. Relações comerciais, códigos de análise e acesso antecipado não dão a parceiros poder de aprovar pauta, nota ou conclusão editorial.</p>
<hr>
<p><em>Mudanças relevantes nesta política ficam refletidas na data de atualização exibida pela própria página.</em></p>',
		),
	);
}

/**
 * Provision missing pages once. Existing pages belong to their editors.
 * Missing pages are created as drafts so nothing institutional is published
 * without an editor seeing it first.
 */
function go_verge_apply_institutional_copy_v2() {
	if ( ! current_user_can( 'manage_options' ) || get_option( 'go_verge_institutional_copy_v2' ) ) {
		return;
	}

	foreach ( go_verge_institutional_pages_content() as $slug => $page_data ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $page instanceof WP_Post ) {
			continue;
		}
		$args = array(
			'post_type'    => 'page',
			'post_title'   => $page_data['title'],
			'post_name'    => $slug,
			'post_content' => wp_kses_post( $page_data['content'] ),
			'post_status'  => 'draft',
		);
		wp_insert_post( wp_slash( $args ) );
	}

	update_option( 'go_verge_institutional_copy_v2', 1, false );
}
add_action( 'admin_init', 'go_verge_apply_institutional_copy_v2', 60 );

/**
 * Retire the old automatic publication migration without changing pages.
 * Keep its option and callable name for installations upgrading from v3.
 */
function go_verge_publish_trust_pages_v3() {
	if ( get_option( 'go_verge_institutional_publish_v3' ) ) {
		return;
	}

	update_option( 'go_verge_institutional_publish_v3', 1, false );
}
add_action( 'admin_init', 'go_verge_publish_trust_pages_v3', 80 );

/** Retired copy migration: opening the admin must not rewrite editorial work. */
function go_verge_update_editorial_scope_about_v4() {
	if ( ! get_option( 'go_verge_editorial_scope_about_v4' ) ) {
		update_option( 'go_verge_editorial_scope_about_v4', 1, false );
	}
}
add_action( 'admin_init', 'go_verge_update_editorial_scope_about_v4', 82 );

/** Retain upgrade bookkeeping; publisher identity is rendered by the theme. */
function go_verge_update_brand_identity_trust_copy_v5() {
	if ( ! get_option( 'go_verge_brand_identity_trust_copy_v5' ) ) {
		update_option( 'go_verge_brand_identity_trust_copy_v5', GO_VERGE_VERSION, false );
	}
}
add_action( 'admin_init', 'go_verge_update_brand_identity_trust_copy_v5', 84 );

/** Retain upgrade bookkeeping without changing existing text or its dates. */
function go_verge_reconcile_public_authority_copy_v5() {
	if ( ! get_option( 'go_verge_authority_copy_v5' ) ) {
		update_option( 'go_verge_authority_copy_v5', 1, false );
	}
}
add_action( 'admin_init', 'go_verge_reconcile_public_authority_copy_v5', 84 );
