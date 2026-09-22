<?php
/**
 * Mídia kit e página comercial de parcerias.
 *
 * Os números vivem aqui, num único array filtrável, para que a atualização
 * mensal seja uma edição de dados e não uma edição de template.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Dados de audiência apurados no Google Analytics 4.
 *
 * Janela vigente: 5 de julho a 3 de agosto de 2026 (últimos 30 dias),
 * comparada com 5 de junho a 4 de julho de 2026 (período anterior).
 *
 * @return array<string,mixed>
 */
function go_verge_media_kit_data() {
	$data = array(
		'periodo'          => '5 de julho a 3 de agosto de 2026',
		'periodo_curto'    => '5 jul – 3 ago 2026',
		'periodo_anterior' => '5 jun – 4 jul 2026',
		'fonte'            => 'Google Analytics 4',
		'fonte_busca'      => 'Google Search Console',
		'propriedade'      => 'gameoverdrive.com.br',
		'atualizado_em'    => 'agosto de 2026',

		/*
		 * Números absolutos NÃO são exibidos nas páginas públicas. Ficam aqui
		 * porque alimentam o PDF enviado sob demanda e servem de referência
		 * para atualizar o kit. A audiência é recente e concentrada numa
		 * editoria; o porte se explica melhor numa conversa por e-mail, com
		 * contexto, do que numa página que qualquer um lê sozinho. É também o
		 * que Lance! e Canaltech fazem: página aberta sem número, kit por
		 * formulário.
		 */
		'absolutos'        => array(
			'usuarios'       => '129.831',
			'paginas_vistas' => '187.338',
			'novos_usuarios' => '127.856',
		),

		/*
		 * O que a página pública mostra: só proporção. Percentual descreve o
		 * encaixe da audiência sem revelar o porte — e o encaixe é o argumento
		 * mais forte que temos, já que imprensa de games no Brasil é
		 * majoritariamente masculina e a nossa audiência não é.
		 */
		'destaques'        => array(
			array( 'valor' => '58,6%', 'rotulo' => 'Público feminino' ),
			array( 'valor' => '62%', 'rotulo' => 'Entre 18 e 34 anos' ),
			array( 'valor' => '84,1%', 'rotulo' => 'Acessos por mobile' ),
			array( 'valor' => '94,9%', 'rotulo' => 'Audiência no Brasil' ),
		),

		'engajamento'      => array(
			'tempo_medio' => '1min44s',
		),

		/*
		 * Seguidores por rede. Todo mídia kit comparável publica este bloco;
		 * ficou vazio de propósito porque o número precisa vir das contas
		 * oficiais. Preencha e ele aparece sozinho nas duas páginas e no PDF.
		 * Ex.: array( array( 'Instagram', '12,4 mil' ), array( 'X', '8 mil' ) ).
		 */
		'redes'            => array(),

		// Praças em participação, não em volume, pela mesma razão dos destaques.
		'geografia'        => array(
			'brasil_share' => '94,9%',
			'cidades'      => array(
				array( 'São Paulo', '11,6%' ),
				array( 'Rio de Janeiro', '5,0%' ),
				array( 'Belo Horizonte', '2,6%' ),
				array( 'Porto Alegre', '2,4%' ),
				array( 'Curitiba', '2,3%' ),
				array( 'Fortaleza', '2,0%' ),
			),
		),

		'dispositivos'     => array(
			array( 'Mobile', '84,1%' ),
			array( 'Desktop', '15,2%' ),
			array( 'Tablet', '0,7%' ),
		),

		'sistemas'         => array(
			array( 'Android', '60,8%' ),
			array( 'iOS', '24,6%' ),
			array( 'Windows', '13,9%' ),
		),

		'genero'           => array(
			array( 'Feminino', '58,6%' ),
			array( 'Masculino', '41,4%' ),
		),

		'idade'            => array(
			array( '18–24', '33,2%' ),
			array( '25–34', '29,0%' ),
			array( '35–44', '15,1%' ),
			array( '45–54', '9,1%' ),
			array( '55–64', '8,3%' ),
			array( '65+', '5,3%' ),
		),

		/*
		 * Origem de tráfego e métricas de Search Console (impressões, consultas
		 * distintas, posição média) saíram da página: nenhum portal comparável
		 * publica isso, e expor a dependência de busca é informação de
		 * diagnóstico interno, não de proposta comercial. Os dados continuam no
		 * GA4 e no Search Console para uso da redação.
		 */
		'editorias'        => array(
			array( 'nome' => 'Games', 'desc' => 'Notícias de lançamentos, indústria e plataformas.' ),
			array( 'nome' => 'Reviews e críticas', 'desc' => 'Análises assinadas de jogos, com nota e ficha técnica.' ),
			array( 'nome' => 'Guias e listas', 'desc' => 'Tutoriais, rankings e guias de compra.' ),
			array( 'nome' => 'Entretenimento', 'desc' => 'Séries e filmes: onde assistir, elenco e finais explicados.' ),
			array( 'nome' => 'Tecnologia', 'desc' => 'Hardware, periféricos e testes de configuração.' ),
		),
	);

	/**
	 * Permite atualizar os números do mídia kit sem tocar no template.
	 *
	 * @param array $data Dados de audiência.
	 */
	return apply_filters( 'go_verge_media_kit_data', $data );
}

/**
 * Formatos comerciais oferecidos.
 *
 * @return array<int,array<string,mixed>>
 */
function go_verge_commercial_email() {
	$email = sanitize_email( (string) apply_filters( 'go_verge_commercial_email', 'contato@gameoverdrive.com.br' ) );
	return is_email( $email ) ? $email : 'contato@gameoverdrive.com.br';
}

/** Build a draft briefing in the visitor's email application; nothing is sent. */
function go_verge_commercial_mailto( $format = '' ) {
	$format  = sanitize_text_field( $format );
	$subject = $format ? 'Proposta comercial — ' . $format . ' — Overdrive' : 'Proposta comercial — Overdrive';
	$body    = "Olá, equipe Overdrive!\r\n\r\nGostaria de receber uma proposta.\r\n\r\n"
		. "Marca/empresa: \r\nObjetivo da campanha: \r\nPeríodo: \r\n"
		. 'Formato de interesse: ' . $format . "\r\nPúblico desejado: \r\n"
		. "Investimento previsto (opcional): \r\nNome e contato: \r\n";
	return 'mailto:' . go_verge_commercial_email() . '?subject=' . rawurlencode( $subject ) . '&body=' . rawurlencode( $body );
}

/** @return array<int,array<string,mixed>> Commercial formats. */
function go_verge_partnership_formats() {
	$formats = array(
		array(
			'nome'   => 'Display',
			'resumo' => 'Banners para dar visibilidade à sua marca nas páginas do Overdrive. Posições e formatos definidos na proposta, conforme disponibilidade.',
			'itens'  => array(
				'Billboard 970×250 e leaderboard 728×90 (desktop)',
				'Retângulo 300×250 e half-page 300×600',
				'Mobile 320×50, 320×100 e 300×250',
				'Entrega por período ou por volume de impressões',
			),
		),
		array(
			'nome'   => 'Conteúdo patrocinado',
			'resumo' => 'Matéria produzida pela redação e publicada com selo de publieditorial.',
			'itens'  => array(
				'Identificação de conteúdo pago no título e no corpo do texto',
				'Publicação permanente, indexável, com link direto',
				'Divulgação na home e nas redes sociais do portal',
			),
		),
		array(
			'nome'   => 'Newsletter',
			'resumo' => 'Base segmentada por assunto, com patrocínio de edição ou bloco dedicado.',
			'itens'  => array(
				'Segmentos de games, entretenimento, promoções e tecnologia',
				'Bloco patrocinado ou edição temática',
				'Relatório de aberturas e cliques',
			),
		),
		array(
			'nome'   => 'Cobertura de lançamento',
			'resumo' => 'Recebimento de códigos de análise, acesso antecipado e material de imprensa.',
			'itens'  => array(
				'Envio de review codes e assets para a redação',
				'Datas de embargo respeitadas',
				'Origem do código informada no texto',
			),
		),
	);

	/**
	 * Permite ajustar os formatos comerciais.
	 *
	 * @param array $formats Formatos de parceria.
	 */
	return apply_filters( 'go_verge_partnership_formats', $formats );
}

/**
 * Renderiza um bloco de estatística.
 *
 * @param string $valor  Número já formatado.
 * @param string $rotulo Rótulo do indicador.
 * @param string $nota   Nota de rodapé opcional.
 */
function go_verge_media_kit_stat( $valor, $rotulo, $nota = '' ) {
	?>
	<div class="go-mk-stat">
		<span class="go-mk-stat__value"><?php echo esc_html( $valor ); ?></span>
		<span class="go-mk-stat__label"><?php echo esc_html( $rotulo ); ?></span>
		<?php if ( $nota ) : ?>
			<span class="go-mk-stat__note"><?php echo esc_html( $nota ); ?></span>
		<?php endif; ?>
	</div>
	<?php
}

/**
 * Linha de barra proporcional. O valor textual continua sendo a informação;
 * a barra é apoio visual.
 *
 * @param string $rotulo  Rótulo da linha.
 * @param string $valor   Valor exibido.
 * @param float  $percent Largura da barra, de 0 a 100.
 */
function go_verge_media_kit_bar( $rotulo, $valor, $percent ) {
	$percent = max( 0, min( 100, (float) $percent ) );
	?>
	<li class="go-mk-bar">
		<span class="go-mk-bar__label"><?php echo esc_html( $rotulo ); ?></span>
		<span class="go-mk-bar__track" aria-hidden="true">
			<span class="go-mk-bar__fill" style="width:<?php echo esc_attr( round( $percent, 2 ) ); ?>%"></span>
		</span>
		<span class="go-mk-bar__value"><?php echo esc_html( $valor ); ?></span>
	</li>
	<?php
}

/**
 * Nota de procedência exibida ao fim de cada seção de dados.
 *
 * @param string $fonte Fonte específica, quando diferente do padrão.
 */
function go_verge_media_kit_source( $fonte = '' ) {
	$data  = go_verge_media_kit_data();
	$fonte = $fonte ? $fonte : $data['fonte'];
	?>
	<p class="go-mk-source">
		<?php
		echo esc_html(
			sprintf(
				/* translators: 1: fonte, 2: propriedade, 3: janela de apuração. */
				__( 'Fonte: %1$s — %2$s. Período: %3$s.', 'go-verge' ),
				$fonte,
				$data['propriedade'],
				$data['periodo']
			)
		);
		?>
	</p>
	<?php
}

/**
 * Estilos das duas páginas comerciais. Carregam só onde são usados.
 */
function go_verge_media_kit_assets() {
	if ( is_admin() || ! is_page( array( 'midia-kit', 'parcerias' ) ) ) {
		return;
	}

	$rel = '/assets/css/media-kit.css';

	wp_enqueue_style(
		'go-verge-media-kit',
		GO_VERGE_URI . $rel,
		array( 'go-verge-site-upgrades' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_media_kit_assets', 10060 );

/**
 * Cria páginas ausentes uma vez, sem publicar rascunhos ou páginas privadas.
 * Falhas de inserção permanecem elegíveis a uma nova tentativa pelo administrador.
 */
function go_verge_create_commercial_pages() {
	if ( ! current_user_can( 'manage_options' ) || ! current_user_can( 'publish_pages' ) || get_option( 'go_verge_commercial_pages_v1' ) ) {
		return;
	}

	$pages = array(
		'midia-kit' => 'Mídia Kit',
		'parcerias' => 'Parcerias',
	);

	$complete = true;
	foreach ( $pages as $slug => $title ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );

		if ( $page instanceof WP_Post ) {
			continue;
		}

		$created = wp_insert_post(
			wp_slash(
				array(
					'post_type'    => 'page',
					'post_status'  => 'publish',
					'post_title'   => $title,
					'post_name'    => $slug,
					'post_content' => '',
				)
			),
			true
		);
		if ( is_wp_error( $created ) || ! $created ) {
			$complete = false;
		}
	}

	if ( $complete ) {
		update_option( 'go_verge_commercial_pages_v1', 1, false );
	}
}
add_action( 'admin_init', 'go_verge_create_commercial_pages', 85 );
