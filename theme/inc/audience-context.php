<?php
/**
 * Contexto de audiência para a chamada da newsletter.
 *
 * O portal cresceu por entretenimento, mas a newsletter prometia "análises,
 * lançamentos e ofertas de games" para todo mundo. Quem chegou por uma série
 * não se reconhece nessa promessa e, se assinasse, receberia um boletim de
 * games que não pediu. Este módulo resolve as duas pontas: a promessa certa na
 * captação e a marcação do contato no segmento certo.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Segmentos válidos. São os mesmos da página de preferências, para que um
 * contato captado em matéria caia no mesmo balde de quem se inscreveu ali.
 *
 * @return array<string,string>
 */
function go_verge_audience_segments() {
	return apply_filters(
		'go_verge_audience_segments',
		array(
			'series'         => __( 'Séries', 'go-verge' ),
			'filmes'         => __( 'Filmes', 'go-verge' ),
			'entretenimento' => __( 'Entretenimento', 'go-verge' ),
			'games'          => __( 'Games', 'go-verge' ),
			'tecnologia'     => __( 'Tecnologia', 'go-verge' ),
			'promocoes'      => __( 'Promoções', 'go-verge' ),
			'geral'          => __( 'Geral', 'go-verge' ),
		)
	);
}

/**
 * Mapa de categoria para segmento. A ordem importa: a primeira correspondência
 * vence, então as categorias mais específicas vêm antes das guarda-chuva.
 *
 * @return array<string,string>
 */
function go_verge_audience_category_map() {
	return apply_filters(
		'go_verge_audience_category_map',
		array(
			'series'         => 'series',
			'serie'          => 'series',
			'seriados'       => 'series',
			'seriado'        => 'series',
			'tv'             => 'series',
			'televisao'      => 'series',
			'filmes'         => 'filmes',
			'filme'          => 'filmes',
			'cinema'         => 'filmes',
			'cinema-e-tv'    => 'filmes',
			'streaming'      => 'entretenimento',
			'entretenimento' => 'entretenimento',
			'promocoes'      => 'promocoes',
			'ofertas'        => 'promocoes',
			'guias-de-compra' => 'promocoes',
			'tecnologia'     => 'tecnologia',
			'hardware'       => 'tecnologia',
		)
	);
}

/**
 * Resolve o contexto do conteúdo em tela.
 *
 * @param int $post_id Post a inspecionar. Zero usa o objeto da consulta.
 * @return string Slug de segmento.
 */
function go_verge_audience_context( $post_id = 0 ) {
	static $cache = array();

	$post_id = $post_id ? absint( $post_id ) : absint( get_queried_object_id() );

	if ( isset( $cache[ $post_id ] ) ) {
		return $cache[ $post_id ];
	}

	$context = 'geral';
	$map     = go_verge_audience_category_map();

	// Em arquivo de categoria, a própria categoria decide.
	if ( ! $post_id || ! get_post( $post_id ) ) {
		$term = is_category() ? get_queried_object() : null;
		if ( $term instanceof WP_Term && isset( $map[ $term->slug ] ) ) {
			$context = $map[ $term->slug ];
		}
		$cache[ $post_id ] = $context;
		return $context;
	}

	if ( 'games' === get_post_type( $post_id ) ) {
		$cache[ $post_id ] = 'games';
		return 'games';
	}

	$slugs = array();
	foreach ( (array) get_the_category( $post_id ) as $cat ) {
		if ( $cat instanceof WP_Term ) {
			$slugs[] = $cat->slug;
			// A categoria pai também conta: "Séries" pendurada em "Entretenimento".
			if ( $cat->parent ) {
				$parent = get_term( $cat->parent, 'category' );
				if ( $parent instanceof WP_Term ) {
					$slugs[] = $parent->slug;
				}
			}
		}
	}

	foreach ( $map as $slug => $segment ) {
		if ( in_array( $slug, $slugs, true ) ) {
			$context = $segment;
			break;
		}
	}

	// Sem correspondência de entretenimento, um post de portal de games é games.
	if ( 'geral' === $context && $slugs ) {
		$context = 'games';
	}

	$cache[ $post_id ] = $context;

	return $context;
}

/**
 * Chamada da newsletter para um contexto.
 *
 * @param string $context Slug de segmento.
 * @return array{titulo:string,texto:string}
 */
function go_verge_newsletter_pitch( $context = '' ) {
	$context = $context ? $context : go_verge_audience_context();

	$pitches = array(
		'series'         => array(
			'titulo' => __( 'Séries no seu e-mail', 'go-verge' ),
			'texto'  => __( 'Grátis, toda semana: o que estreia, o que volta e onde assistir.', 'go-verge' ),
		),
		'filmes'         => array(
			'titulo' => __( 'Filmes no seu e-mail', 'go-verge' ),
			'texto'  => __( 'Grátis, toda semana: o que estreia no cinema e no streaming.', 'go-verge' ),
		),
		'entretenimento' => array(
			'titulo' => __( 'Entretenimento no seu e-mail', 'go-verge' ),
			'texto'  => __( 'Grátis, toda semana: séries e filmes que estreiam, voltam ou saem do catálogo.', 'go-verge' ),
		),
		'tecnologia'     => array(
			'titulo' => __( 'Tecnologia no seu e-mail', 'go-verge' ),
			'texto'  => __( 'Grátis, toda semana: hardware testado, lançamentos e o que vale comprar.', 'go-verge' ),
		),
		'promocoes'      => array(
			'titulo' => __( 'Promoções no seu e-mail', 'go-verge' ),
			'texto'  => __( 'Grátis: as quedas de preço que valem a pena, com histórico.', 'go-verge' ),
		),
		'games'          => array(
			'titulo' => __( 'Games no seu e-mail', 'go-verge' ),
			'texto'  => __( 'Grátis, toda semana: lançamentos, análises e as promoções que valem a pena.', 'go-verge' ),
		),
		'geral'          => array(
			'titulo' => __( 'Newsletter do Overdrive', 'go-verge' ),
			'texto'  => __( 'Grátis, toda semana: as principais histórias do Overdrive.', 'go-verge' ),
		),
	);

	$pitch = isset( $pitches[ $context ] ) ? $pitches[ $context ] : $pitches['geral'];

	/**
	 * Permite reescrever a chamada por contexto.
	 *
	 * @param array  $pitch   Título e texto.
	 * @param string $context Slug de segmento.
	 */
	return apply_filters( 'go_verge_newsletter_pitch', $pitch, $context );
}

/**
 * Reescreve o copy do formulário do Mailchimp for WP com a promessa do
 * contexto e injeta o segmento como campo oculto, para que o contato nasça
 * marcado. Substitui a antiga reescrita fixa de games.
 *
 * @param string $content HTML do formulário.
 * @return string
 */
function go_verge_contextual_newsletter_form( $content ) {
	if ( ! is_string( $content ) || '' === $content ) {
		return $content;
	}

	$context = go_verge_audience_context();
	$pitch   = go_verge_newsletter_pitch( $context );

	$map = array(
		// Localização dos rótulos padrão do plugin.
		'Your email address'                                           => __( 'Seu e-mail', 'go-verge' ),
		'Sign Up Now'                                                  => __( 'Assinar', 'go-verge' ),
		'Subscribe'                                                    => __( 'Assinar', 'go-verge' ),
		'I have read and agree to the'                                 => __( 'Li e concordo com os', 'go-verge' ),
		'terms &amp; conditions'                                       => __( 'termos de uso', 'go-verge' ),
		'terms & conditions'                                           => __( 'termos de uso', 'go-verge' ),
		// Chamada contextual no lugar do copy genérico e do antigo texto de games.
		'Descubra mais sobre Overdrive'                           => $pitch['titulo'],
		'A newsletter do Overdrive'                               => $pitch['titulo'],
		'Assine para receber nossas notícias mais recentes por e-mail.' => $pitch['texto'],
		'Assine para receber nossas notícias mais recentes por e-mail'  => $pitch['texto'],
		'Análises, lançamentos e as melhores ofertas de games no seu e-mail. Toda semana, sem spam.' => $pitch['texto'],
	);

	$content = str_ireplace( array_keys( $map ), array_values( $map ), $content );

	// Campo oculto com o segmento, lido de volta em go_verge_tag_subscriber().
	$hidden = sprintf(
		'<input type="hidden" name="go_segmento" value="%s">',
		esc_attr( $context )
	);

	if ( false !== stripos( $content, '</form>' ) ) {
		$content = preg_replace( '#</form>#i', $hidden . '</form>', $content, 1 );
	} else {
		$content .= $hidden;
	}

	return $content;
}
add_filter( 'mc4wp_form_content', 'go_verge_contextual_newsletter_form', 20 );

/**
 * Marca o contato com o segmento de origem. Sem isso, quem assinou numa
 * matéria de série entraria na mesma lista de quem quer games.
 *
 * @param object $subscriber Objeto de inscrição do mc4wp.
 * @return object
 */
function go_verge_tag_subscriber( $subscriber ) {
	// phpcs:ignore WordPress.Security.NonceVerification.Missing -- o plugin valida o envio; aqui só lemos um rótulo.
	$raw = isset( $_POST['go_segmento'] ) ? sanitize_key( wp_unslash( $_POST['go_segmento'] ) ) : '';

	$segments = go_verge_audience_segments();
	if ( '' === $raw || ! isset( $segments[ $raw ] ) ) {
		return $subscriber;
	}

	if ( ! isset( $subscriber->tags ) || ! is_array( $subscriber->tags ) ) {
		$subscriber->tags = array();
	}
	$subscriber->tags[] = $segments[ $raw ];
	$subscriber->tags   = array_values( array_unique( $subscriber->tags ) );

	return $subscriber;
}
add_filter( 'mc4wp_form_subscriber_data', 'go_verge_tag_subscriber', 20 );

/**
 * Mesma reescrita para o bloco de assinatura do Jetpack, que usa gettext.
 *
 * @param string $translation Texto traduzido.
 * @param string $text        Texto-fonte em inglês.
 * @param string $domain      Textdomain.
 * @return string
 */
function go_verge_contextual_jetpack_copy( $translation, $text, $domain ) {
	if ( 'jetpack' !== $domain ) {
		return $translation;
	}

	$pitch = go_verge_newsletter_pitch();

	switch ( $text ) {
		case 'Discover more from %s':
			return $pitch['titulo'];
		case 'Subscribe to get the latest posts sent to your email.':
		case 'Subscribe to get the latest posts to your email.':
			return $pitch['texto'];
	}

	return $translation;
}
add_filter( 'gettext', 'go_verge_contextual_jetpack_copy', 21, 3 );

/* --------------------------------------------------------------------------
 * Barra de editoria no fim da matéria.
 * ------------------------------------------------------------------------ */

/**
 * Categoria mais específica da matéria. Entre "Entretenimento" e "Séries", a
 * filha diz mais ao leitor sobre onde ele está.
 *
 * @param int $post_id Post atual.
 * @return WP_Term|null
 */
function go_verge_primary_category( $post_id ) {
	$cats = get_the_category( $post_id );
	if ( empty( $cats ) ) {
		return null;
	}

	foreach ( $cats as $cat ) {
		if ( $cat instanceof WP_Term && $cat->parent ) {
			return $cat;
		}
	}

	return $cats[0] instanceof WP_Term ? $cats[0] : null;
}

/**
 * Barra de editoria entre o fim do texto e os comentários.
 *
 * É deliberadamente quase sem texto: nome da editoria, quantas matérias ela
 * tem e dois links. O número faz o trabalho que uma frase de marketing faria
 * pior — mostra que há acervo, em vez de prometer que há.
 *
 * @param int $post_id Post atual.
 * @return void
 */
function go_verge_render_topic_bar( $post_id = 0 ) {
	if ( ! is_singular( 'post' ) ) {
		return;
	}

	$post_id = $post_id ? absint( $post_id ) : absint( get_queried_object_id() );
	if ( ! $post_id ) {
		return;
	}

	$cat = go_verge_primary_category( $post_id );
	if ( ! $cat instanceof WP_Term ) {
		return;
	}

	$total = (int) $cat->count;
	$link  = get_category_link( $cat );
	if ( is_wp_error( $link ) ) {
		return;
	}
	?>
	<section class="go-topicbar">
		<div class="go-topicbar__id">
			<a class="go-topicbar__name" href="<?php echo esc_url( $link ); ?>"><?php echo esc_html( $cat->name ); ?></a>
			<span class="go-topicbar__count">
				<?php
				echo esc_html(
					sprintf(
						/* translators: %s: número de matérias na editoria. */
						_n( '%s matéria', '%s matérias', $total, 'go-verge' ),
						number_format_i18n( $total )
					)
				);
				?>
			</span>
		</div>

		<div class="go-topicbar__actions">
			<a href="<?php echo esc_url( $link ); ?>"><?php esc_html_e( 'Ver todas', 'go-verge' ); ?></a>
			<?php if ( comments_open( $post_id ) ) : ?>
				<a href="#respond"><?php echo go_verge_icon('comentarios','go-interface-icon'); ?> <?php esc_html_e( 'Comentar', 'go-verge' ); ?></a>
			<?php endif; ?>
		</div>
	</section>
	<?php
}

/** Estilo da barra de editoria. */
function go_verge_topicbar_assets() {
	if ( is_admin() || ! is_singular( 'post' ) ) {
		return;
	}

	$rel = '/assets/css/topic-bar.css';

	wp_enqueue_style(
		'go-verge-topicbar',
		GO_VERGE_URI . $rel,
		array( 'go-verge-site-upgrades' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_topicbar_assets', 10061 );
