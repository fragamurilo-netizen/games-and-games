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
			'content' => '<p>O Overdrive existe porque a gente cansou de ler sobre jogos em texto que parece bula de remédio.</p>
<p>Somos um portal brasileiro de games, entretenimento e tecnologia, fundado em 2024. Cobrimos lançamentos, séries, filmes, streaming, produtos e tendências, além de reviews e guias, sempre com contexto para o público brasileiro.</p>
<p>O site é conduzido por Gregory Felipe e Murilo Rodrigues, fundadores e editores-chefes, com Deco Campos na equipe editorial. A proposta editorial é simples: tratar games, entretenimento e tecnologia com rigor de apuração, opinião assinada e texto que respeite o tempo de quem lê.</p>
<h2>Como a gente trabalha</h2>
<p>Todo review publicado aqui foi jogado de verdade. Quando recebemos código de análise de distribuidora ou estúdio, avisamos no texto. Quando compramos o jogo do nosso bolso, também foi jogado do mesmo jeito. A diferença é só quem pagou o boleto.</p>
<p>Nota não é matemática. É opinião de quem jogou, defendida com argumento. Você pode discordar da gente, e tudo bem: um review que não gera discussão provavelmente não disse nada.</p>
<p>Nos guias, o compromisso é outro: testamos os passos antes de publicar. Se um guia nosso estiver desatualizado depois de um patch, avise. Corrigimos e marcamos a data da atualização no texto.</p>
<h2>Quem assina</h2>
<p>Cada matéria do Overdrive tem autor com nome e página própria. O histórico de cada pessoa fica disponível na página de autor, e a equipe publicada no site pode ser consultada em <a href="/autores/">Autores</a>.</p>
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
<p>O Overdrive também está em ' . $x_link . '. Para correção, pauta, imprensa ou assunto comercial, o e-mail continua sendo o canal mais seguro.</p>',
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
<p>O Overdrive é um portal editorial independente e não pertence a distribuidora, estúdio ou fabricante de hardware. Relações comerciais, códigos de análise e acesso antecipado não dão a parceiros poder de aprovar pauta, nota ou conclusão editorial.</p>
<hr>
<p><em>Mudanças relevantes nesta política ficam refletidas na data de atualização exibida pela própria página.</em></p>',
		),
	);
}

/**
 * Editorial trust center and policy drafts introduced in 5.5.10.
 *
 * These documents are deliberately provisioned as drafts. Publishing a policy
 * is a newsroom claim, so an editor must read it before its URL can be exposed
 * by NewsMediaOrganization structured data.
 *
 * @return array<string,array{title:string,excerpt:string,content:string}>
 */
function go_verge_trust_policy_pages_content_v6() {
	return array(
		'politicas' => array(
			'title'   => 'Políticas e transparência',
			'excerpt' => 'Como o Overdrive escolhe pautas, identifica autores, trata fontes, separa publicidade de conteúdo editorial e presta contas ao leitor.',
			'content' => '<p>Transparência editorial precisa ser fácil de encontrar. Esta central reúne os documentos que explicam como o Overdrive trabalha, de onde vem sua receita, quais critérios orientam a cobertura e quem responde pelo conteúdo publicado.</p>
<p>As políticas abaixo complementam a <a href="/politica-editorial/">Política Editorial</a>. Quando uma prática mudar de forma relevante, o documento correspondente deve ser atualizado para refletir o processo realmente usado pela redação.</p>',
		),
		'propriedade-e-financiamento' => array(
			'title'   => 'Propriedade e financiamento',
			'excerpt' => 'Quem mantém o Overdrive, como o site gera receita e onde fica a separação entre interesses comerciais e decisões editoriais.',
			'content' => '<p>Esta página explica como o Overdrive é mantido e qual é a fronteira entre a operação comercial e as decisões da redação.</p>
<h2>Propriedade</h2>
<p>O Overdrive é uma publicação digital independente. A propriedade e a gestão do projeto permanecem com seus próprios sócios e responsáveis editoriais, sem participação de fabricantes de hardware, estúdios, distribuidoras, plataformas de streaming, varejistas ou anunciantes que sejam objeto da cobertura.</p>
<h2>Como o site se financia</h2>
<p>A operação pode gerar receita por publicidade programática ou direta, links de afiliados e parcerias comerciais identificadas. O leitor não paga mais por comprar por um link afiliado, e a existência de comissão não altera a conclusão de um guia, comparativo, review ou reportagem.</p>
<h2>Separação entre receita e pauta</h2>
<p>Anunciantes, lojas, fabricantes, estúdios e demais parceiros comerciais não recebem direito de aprovar previamente matérias editoriais, escolher notas, exigir conclusões positivas ou vetar críticas.</p>
<p>Quando uma publicação é patrocinada, publicitária ou produzida dentro de uma parceria comercial, essa relação deve ser informada de forma visível para que o leitor saiba a natureza do conteúdo antes de consumi-lo.</p>
<h2>Produtos, códigos e acesso antecipado</h2>
<p>Receber um jogo, produto, código de análise, convite ou acesso antecipado não garante cobertura favorável. Reviews e análises continuam sob responsabilidade de quem assina o texto, e eventuais condições relevantes de acesso devem ser informadas ao leitor.</p>
<h2>Dúvidas sobre financiamento</h2>
<p>Questões sobre relações comerciais, propriedade ou independência editorial podem ser encaminhadas pela página de <a href="/contato/">Contato</a>.</p>',
		),
		'missao-e-prioridades-de-cobertura' => array(
			'title'   => 'Missão e prioridades de cobertura',
			'excerpt' => 'O que o Overdrive cobre, quais critérios pesam na escolha de pautas e o que fica fora da cobertura editorial.',
			'content' => '<p>A missão do Overdrive é transformar informação sobre games, tecnologia, entretenimento, mobilidade e vida digital em conteúdo útil, verificável e claro para o público brasileiro.</p>
<h2>O que orienta uma pauta</h2>
<p>Uma pauta pode entrar na cobertura por relevância para o público, atualidade, impacto prático, utilidade, interesse jornalístico ou porque responde a uma dúvida recorrente dos leitores. Tendência e volume de busca podem ajudar a identificar interesse, mas não substituem apuração nem justificam publicar algo que não tenha informação útil.</p>
<h2>Prioridades editoriais</h2>
<ul>
<li>Notícias que mudam a experiência do jogador, consumidor ou assinante.</li>
<li>Guias e explicações que resolvem problemas concretos.</li>
<li>Reviews, críticas e comparativos baseados em uso, teste ou apuração identificável.</li>
<li>Mudanças de preço, disponibilidade, políticas, lançamentos e serviços com impacto para o público brasileiro.</li>
<li>Contexto para tendências que estejam gerando dúvida, interesse ou decisão de compra.</li>
</ul>
<h2>O que não determina cobertura</h2>
<p>Pagamento de anunciante, envio de produto, acesso antecipado, relacionamento com assessoria ou interesse comercial não garantem pauta e não definem a conclusão editorial.</p>
<h2>Rumores e informação incompleta</h2>
<p>Rumores podem ser noticiados quando houver origem relevante e interesse público, mas devem ser identificados como não confirmados. Informação sem atribuição verificável não deve ser apresentada como fato.</p>
<h2>O que podemos decidir não cobrir</h2>
<p>A redação pode deixar de publicar assuntos sem relevância para seu público, material promocional sem valor informativo, alegações impossíveis de verificar ou pautas cujo único objetivo seja reproduzir publicidade como se fosse notícia.</p>',
		),
		'politica-de-diversidade' => array(
			'title'   => 'Política de diversidade',
			'excerpt' => 'Compromissos do Overdrive para ampliar perspectivas, evitar estereótipos e escolher fontes de forma responsável.',
			'content' => '<p>O Overdrive busca produzir uma cobertura que considere diferentes experiências, perspectivas e públicos sem transformar diversidade em elemento decorativo ou estatística inventada.</p>
<h2>Diversidade nas fontes</h2>
<p>Quando a pauta permitir mais de uma perspectiva, a redação procura não depender sempre das mesmas fontes. Especialistas, profissionais, criadores, consumidores e demais pessoas consultadas devem ser escolhidos pela relação com o assunto, conhecimento e capacidade de contribuir para a apuração.</p>
<h2>Representação no texto</h2>
<p>A cobertura deve evitar estereótipos, generalizações e referências a características pessoais que não sejam relevantes para compreender a notícia. Identidade, origem, gênero, deficiência ou outras características não devem ser usadas apenas para gerar impacto.</p>
<h2>Equipe editorial</h2>
<p>Contratação, colaboração e distribuição de pautas devem considerar competência para o trabalho e respeito entre as pessoas. O site não publica percentuais demográficos sobre a equipe quando não possui base de dados ou metodologia suficiente para fazê-lo de maneira responsável.</p>
<h2>Correções e evolução</h2>
<p>Leitores podem apontar linguagem inadequada, ausência de contexto ou problemas de representação pela página de <a href="/contato/">Contato</a>. Esta política pode evoluir conforme a equipe e os processos editoriais mudarem.</p>',
		),
		'politica-de-assinatura' => array(
			'title'   => 'Política de autoria e matérias sem assinatura',
			'excerpt' => 'Quando o Overdrive usa assinatura individual, em quais exceções um conteúdo pode ser atribuído à redação e quem responde por ele.',
			'content' => '<p>Como regra, conteúdo editorial do Overdrive deve identificar quem o produziu. A assinatura ajuda o leitor a conhecer o histórico do autor e deixa clara a responsabilidade pelo texto.</p>
<h2>Quando usamos assinatura individual</h2>
<p>Notícias, reportagens, análises, reviews, críticas, guias e comparativos produzidos por uma pessoa devem sair com o nome de seu autor e, sempre que possível, com acesso à respectiva página de perfil.</p>
<h2>Quando um conteúdo pode sair sem assinatura individual</h2>
<p>Uma publicação pode ser atribuída à redação quando for produzida coletivamente, representar um comunicado institucional do próprio Overdrive, reunir atualizações operacionais de várias pessoas ou quando não houver uma contribuição individual que represente de forma justa a autoria do material.</p>
<p>A ausência de assinatura individual nunca deve ser usada para esconder a responsabilidade por uma opinião, acusação ou erro factual.</p>
<h2>Quem responde nesses casos</h2>
<p>Conteúdos atribuídos à redação continuam sob responsabilidade editorial do Overdrive. Pedidos de correção, dúvidas de autoria ou questionamentos podem ser enviados pela página de <a href="/contato/">Contato</a>.</p>
<h2>Alterações de autoria</h2>
<p>Uma assinatura não deve ser removida apenas para apagar o histórico de uma publicação. Correções de autoria podem ser feitas quando houver erro de atribuição ou quando a participação de outras pessoas justificar atualização dos créditos.</p>',
		),
		'politica-de-fontes-nao-identificadas' => array(
			'title'   => 'Política de fontes não identificadas',
			'excerpt' => 'Quando o Overdrive aceita uma fonte sem identificação pública, como verifica a informação e o que precisa explicar ao leitor.',
			'content' => '<p>O Overdrive prefere fontes identificadas. O anonimato é uma exceção editorial e não uma forma de tornar publicável qualquer alegação que alguém não queira assumir publicamente.</p>
<h2>Quando podemos preservar uma identidade</h2>
<p>Uma fonte pode não ser identificada publicamente quando a informação tiver relevância jornalística e houver risco concreto de retaliação, perda profissional, violação de confidencialidade legítima ou outra razão proporcional para preservar sua identidade.</p>
<h2>O que a redação precisa saber</h2>
<p>Mesmo quando o nome não aparece para o leitor, a redação deve conhecer a identidade da fonte sempre que isso for possível, avaliar sua relação com o assunto e entender de que forma ela teve acesso à informação.</p>
<h2>Verificação antes de publicar</h2>
<p>Informações de uma fonte não identificada devem ser confrontadas com documentos, dados, registros públicos, outras fontes ou evidências independentes sempre que houver meios para isso. Quanto mais séria for a alegação, maior deve ser a exigência de confirmação.</p>
<h2>Como explicamos ao leitor</h2>
<p>A matéria deve oferecer contexto suficiente para explicar por que aquela fonte está em posição de conhecer o assunto, sem revelar detalhes que tornem sua identificação possível. Quando a informação não puder ser confirmada de maneira independente, essa limitação deve ser considerada na decisão de publicar e na forma de apresentar o relato.</p>
<h2>O que não aceitamos</h2>
<p>Anonimato não deve ser usado apenas para ataques pessoais, promoção disfarçada, opinião sem evidência ou para contornar a necessidade de atribuição. A decisão final de conceder proteção à identidade é editorial.</p>
<h2>Responsabilidade</h2>
<p>O Overdrive responde pela decisão de publicar uma informação baseada em fonte não identificada. Dúvidas ou pedidos de correção podem ser enviados pela página de <a href="/contato/">Contato</a>.</p>',
		),
	);
}

/** Create the trust center and the five schema-backed policy pages as drafts. */
function go_verge_apply_trust_policy_pages_v6() {
	if ( ! current_user_can( 'manage_options' ) || get_option( 'go_verge_trust_policy_pages_v6' ) ) {
		return;
	}

	$created = 0;
	foreach ( go_verge_trust_policy_pages_content_v6() as $slug => $page_data ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $page instanceof WP_Post ) {
			/* Respect editorial work. Only hydrate a pre-existing unpublished shell
			 * when it is still empty, which also recovers half-finished migrations. */
			if ( 'publish' !== get_post_status( $page ) && '' === trim( wp_strip_all_tags( (string) $page->post_content ) ) ) {
				$result = wp_update_post(
					wp_slash(
						array(
							'ID'           => $page->ID,
							'post_title'   => $page_data['title'],
							'post_excerpt' => $page_data['excerpt'],
							'post_content' => wp_kses_post( $page_data['content'] ),
						),
					),
					true
				);
				if ( ! is_wp_error( $result ) ) {
					$created++;
				}
			}
			continue;
		}
		$post_id = wp_insert_post(
			wp_slash(
				array(
					'post_type'    => 'page',
					'post_title'   => $page_data['title'],
					'post_name'    => $slug,
					'post_excerpt' => $page_data['excerpt'],
					'post_content' => wp_kses_post( $page_data['content'] ),
					'post_status'  => 'draft',
				)
			),
			true
		);
		if ( ! is_wp_error( $post_id ) ) {
			$created++;
		}
	}

	update_option( 'go_verge_trust_policy_pages_v6', 1, false );
	if ( $created > 0 ) {
		set_transient( 'go_verge_trust_policy_pages_notice_v6', $created, 10 * MINUTE_IN_SECONDS );
	}
}
add_action( 'admin_init', 'go_verge_apply_trust_policy_pages_v6', 61 );

/** Tell administrators where the newly provisioned policy drafts are. */
function go_verge_trust_policy_pages_notice_v6() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$count = (int) get_transient( 'go_verge_trust_policy_pages_notice_v6' );
	if ( $count <= 0 ) {
		return;
	}
	delete_transient( 'go_verge_trust_policy_pages_notice_v6' );
	?>
	<div class="notice notice-info is-dismissible">
		<p><strong><?php esc_html_e( 'Políticas e transparência do Overdrive', 'go-verge' ); ?></strong></p>
		<p><?php echo esc_html( sprintf( __( '%d páginas institucionais foram preparadas como rascunho. Revise o texto e publique apenas o que representar a prática real da redação; as propriedades de confiança entram no schema automaticamente depois da publicação.', 'go-verge' ), $count ) ); ?></p>
		<p><a class="button button-primary" href="<?php echo esc_url( admin_url( 'edit.php?post_type=page' ) ); ?>"><?php esc_html_e( 'Revisar páginas', 'go-verge' ); ?></a></p>
	</div>
	<?php
}
add_action( 'admin_notices', 'go_verge_trust_policy_pages_notice_v6' );

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
