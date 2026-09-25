<?php
/**
 * Convites de canal e de seção no corpo da matéria.
 *
 * Duas peças, deliberadamente separadas porque servem a momentos diferentes da
 * leitura:
 *
 *  - o convite do CANAL entra antes do primeiro H2, onde o leitor acabou de
 *    decidir que a matéria interessa e ainda não gastou a atenção;
 *  - o convite da SEÇÃO fecha o texto, quando a pergunta natural passa a ser
 *    "o que mais tem sobre isso aqui".
 *
 * Um cluster é escolhido por post e só um. A ordem do array importa: `turcas`
 * vem antes de `pop` porque produção turca também é entretenimento, e quem cai
 * nos dois tem que receber o convite específico, não o genérico.
 *
 * Desligar por completo:
 *   add_filter( 'go_verge_channel_invite_enabled', '__return_false' );
 *
 * Ajustar links, textos ou taxonomias sem tocar no código:
 *   add_filter( 'go_verge_channel_invite_clusters', function ( $c ) { ... } );
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Chave interna: impede que o mesmo bloco seja inserido duas vezes. */
if ( ! defined( 'GO_VERGE_CHANNEL_INVITE_MARK' ) ) {
	define( 'GO_VERGE_CHANNEL_INVITE_MARK', 'data-go-channel-invite' );
}

/** Interruptor geral. */
function go_verge_channel_invite_enabled() {
	return (bool) apply_filters( 'go_verge_channel_invite_enabled', true );
}

/**
 * Os clusters, na ordem em que são testados.
 *
 * `categories` e `tags` são slugs. Basta um acerto em qualquer um dos dois para
 * o post pertencer ao cluster — uma matéria marcada só com a tag `series-turcas`
 * conta como turca mesmo sem estar na categoria.
 *
 * @return array<string,array<string,mixed>>
 */
function go_verge_channel_invite_clusters() {
	$clusters = array(
		/*
		 * Turcas primeiro, e isso não é ordem alfabética: a categoria vive dentro
		 * de Entretenimento, então um post turco casa com os dois clusters. Quem
		 * casa com dois recebe o mais específico.
		 */
		'turcas' => array(
			/*
			 * "Ama", não "gosta". A pergunta é um teste de identidade: quem chegou
			 * numa matéria de dizi por busca não "gosta" do gênero, é fã dele — e o
			 * bloco só funciona se o leitor se reconhecer na primeira linha.
			 */
			'question'      => __( 'Ama séries turcas?', 'go-verge' ),
			'channel_url'   => 'https://whatsapp.com/channel/0029VbDaFgx7YSdBSZLABX0b',
			/*
			 * O link diz o que o leitor ganha, não o que ele faz. "Entrar no canal"
			 * descreve o clique; "receba as estreias primeiro" descreve o motivo —
			 * e motivo é o que decide o clique. Personalizado por cluster porque a
			 * razão de acompanhar novela turca não é a mesma de acompanhar games.
			 *
			 * "spoilers" e "em primeira mão" trocam uma promessa genérica por uma
			 * com prazo. "Principais notícias" não perde nada se o leitor entrar
			 * semana que vem; spoiler perde tudo. É a diferença entre uma chamada
			 * que pode ser adiada e uma que não pode.
			 *
			 * A versão `_subject` cita o assunto da matéria aberta — a série que a
			 * pessoa está lendo agora, não um título fixo. Um nome cravado aqui
			 * prometeria spoiler da novela errada em toda matéria sobre outra dizi,
			 * e envelheceria sozinho quando o carro-chefe mudasse.
			 */
			'channel_cta'         => __( 'Receba spoilers e estreias turcas em primeira mão no canal do WhatsApp', 'go-verge' ),
			'channel_cta_subject' => __( 'Não perca nada de %s: spoilers e estreias em primeira mão no WhatsApp', 'go-verge' ),
			'section_slug'  => 'filmes-series-dizis-turcas',
			'section_name'  => __( 'produções turcas', 'go-verge' ),
			'categories'    => array( 'producoes-turcas', 'filmes-series-dizis-turcas', 'series-turcas', 'novelas-turcas' ),
			'tags'          => array( 'series-turcas', 'novelas-turcas', 'dizi', 'dizis' ),
		),
		'games' => array(
			'question'      => __( 'Quer jogos grátis e boas promoções?', 'go-verge' ),
			/*
			 * Jogos grátis e promoções são o benefício principal do canal.
			 * Guias, códigos e notícias complementam a chamada conforme a matéria.
			 * A promessa vale para o canal, não afirma que o jogo citado esteja grátis.
			 */
			'channel_cta'         => __( 'Receba alertas de jogos grátis e promoções no WhatsApp. Também enviamos guias e notícias', 'go-verge' ),
			'channel_cta_subject' => __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de novidades de %s', 'go-verge' ),
			'channel_url'   => 'https://whatsapp.com/channel/0029VbD3xgo5K3zd4n3vhk2r',
			'section_slug'  => 'games',
			'section_name'  => __( 'games', 'go-verge' ),
			'categories'    => array( 'games', 'noticias-games', 'playstation', 'xbox', 'nintendo', 'pc', 'steam', 'reviews', 'guias', 'lancamentos', 'especiais', 'promo-games', 'jogos-gratis', 'codigos', 'dicas-e-guias' ),
			'tags'          => array(),
		),
		'technology' => array(
			'question'      => __( 'Quer acompanhar as novidades de tecnologia?', 'go-verge' ),
			'channel_url'   => 'https://whatsapp.com/channel/0029Vb8lV4nFi8xiDKv2mT08',
			'channel_cta'   => __( 'Siga o canal de Tecnologia do Overdrive no WhatsApp', 'go-verge' ),
			'section_slug'  => 'tecnologia',
			'section_name'  => __( 'tecnologia', 'go-verge' ),
			/* Routing uses the editorial graph below, never a loose tag/body word. */
			'categories'    => array(),
			'tags'          => array(),
		),
		'pop' => array(
			'question'      => __( 'Gosta de séries e streaming?', 'go-verge' ),
			'channel_url'   => 'https://whatsapp.com/channel/0029Vb8GRzGEKyZEl4ulpP3s',
			/*
			 * O cluster pop é o mais largo dos três — cobre Netflix, HBO, anime,
			 * cinema e crítica —, então a versão sem assunto precisa valer para
			 * todos eles. O que dá urgência aqui é a ordem de chegada.
			 */
			'channel_cta'         => __( 'Receba notícias, listas e estreias em primeira mão no canal do WhatsApp', 'go-verge' ),
			'channel_cta_subject' => __( 'Não perca nada de %s: notícias e estreias em primeira mão no WhatsApp', 'go-verge' ),
			'section_slug'  => 'entretenimento',
			'section_name'  => __( 'séries, filmes e streaming', 'go-verge' ),
			'categories'    => array( 'entretenimento', 'series', 'netflix', 'streaming', 'filmes', 'cinema', 'hbo', 'anime', 'anime-e-manga', 'criticas', 'especiais-entretenimento' ),
			'tags'          => array(),
		),
	);

	return (array) apply_filters( 'go_verge_channel_invite_clusters', $clusters );
}

/**
 * Cluster do post, ou array vazio quando nenhum casa.
 *
 * Resolvido uma vez por post e guardado: o filtro roda duas vezes no mesmo
 * conteúdo (canal e seção) e cada resolução custa duas consultas de taxonomia.
 *
 * @param int $post_id Post.
 * @return array<string,mixed>
 */
function go_verge_channel_invite_for_post( $post_id = 0 ) {
	static $cache = array();

	$post_id = $post_id ? absint( $post_id ) : absint( get_queried_object_id() );
	if ( ! $post_id ) {
		return array();
	}
	if ( isset( $cache[ $post_id ] ) ) {
		return $cache[ $post_id ];
	}

	/*
	 * Resolve categorias com os ancestrais canônicos. O WordPress não inclui o
	 * pai automaticamente quando um post recebe só uma categoria filha; depois
	 * da arquitetura editorial V7 isso fazia, por exemplo, `guias` deixar de
	 * casar com o cluster `games`. Herdar os ancestrais torna o convite compatível
	 * com a árvore atual e também com novas subcategorias futuras.
	 */
	$cat_terms = wp_get_post_terms( $post_id, 'category' );
	$cats      = array();
	if ( ! is_wp_error( $cat_terms ) ) {
		foreach ( (array) $cat_terms as $term ) {
			if ( ! ( $term instanceof WP_Term ) ) {
				continue;
			}
			$cats[] = $term->slug;
			foreach ( (array) get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
				$ancestor = get_term( $ancestor_id, 'category' );
				if ( $ancestor instanceof WP_Term && ! is_wp_error( $ancestor ) ) {
					$cats[] = $ancestor->slug;
				}
			}
		}
	}
	$cats = array_values( array_unique( array_filter( array_map( 'sanitize_title', $cats ) ) ) );

	$tags = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'slugs' ) );
	$tags = is_wp_error( $tags ) ? array() : (array) $tags;

	$found = array();
	$clusters = go_verge_channel_invite_clusters();
	foreach ( $clusters as $key => $cluster ) {
		$hit_cat = array_intersect( $cats, (array) ( $cluster['categories'] ?? array() ) );
		$hit_tag = array_intersect( $tags, (array) ( $cluster['tags'] ?? array() ) );
		if ( $hit_cat || $hit_tag ) {
			$cluster['key'] = $key;
			$found          = $cluster;
			break;
		}
	}
	/* Assigned editorial intent wins over broad legacy slugs such as "guias".
	 * The existing Turkish resolver still runs afterwards and keeps precedence. */
	if ( 'turcas' !== ( $found['key'] ?? '' ) && ! empty( $clusters['technology'] ) ) {
		$technology = go_verge_channel_invite_technology_context( $post_id, is_wp_error( $cat_terms ) ? array() : (array) $cat_terms );
		if ( $technology ) {
			$found = array_merge( (array) $clusters['technology'], $technology, array( 'key' => 'technology' ) );
		}
	}

	$cache[ $post_id ] = (array) apply_filters( 'go_verge_channel_invite_for_post', $found, $post_id, $cats, $tags );

	return $cache[ $post_id ];
}

/** Topic vocabulary for canonical subjects/categories, not arbitrary body copy. */
function go_verge_channel_invite_technology_topic( $value ) {
	$key = go_verge_channel_invite_match_text( $value );
	$topics = array(
		'windows'   => '/\bwindows\b/',
		'ai'        => '/\b(?:inteligencia artificial|ia|chatgpt|gemini|copilot|claude)\b/',
		'wearables' => '/\b(?:wearables?|smartwatches?|relogios? inteligentes?|dispositivos vestiveis|apple watch|galaxy watch|smartband)\b/',
		'audio'     => '/\b(?:audio|fones?|headphones?|earbuds?|headsets?|caixas? de som|soundbars?|airpods)\b/',
		'tv'        => '/\b(?:tvs?|televisor(?:es)?|televisao|monitor(?:es)?|smart tv|telas)\b/',
		'phones'    => '/\b(?:celular(?:es)?|smartphones?|iphone|android|ios|ipados|tablets?|ipad|google pixel|galaxy [sazm][0-9]*)\b/',
		'computers' => '/\b(?:pcs?|computador(?:es)?|notebooks?|laptops?|macbooks?|processador(?:es)?|placas? de video|hardware)\b/',
		'software'  => '/\b(?:apps?|aplicativos?|software|softwares|sistema operacional|sistemas operacionais|linux|macos|navegador(?:es)?)\b/',
		'science'   => '/\b(?:ciencia|cientifico|cientifica|espaco|astronomia)\b/',
	);
	foreach ( $topics as $topic => $pattern ) {
		if ( preg_match( $pattern, $key ) ) { return $topic; }
	}
	return '';
}

/**
 * Technology routing follows the assigned desk and durable subject graph.
 * A Games/Entertainment/Offers desk is never changed because Android, Windows
 * or a device appears in the story. Without a desk, only a canonical technology
 * subject can establish eligibility; title/body keywords are not consulted.
 */
function go_verge_channel_invite_technology_context( $post_id, $terms = array() ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) { return array(); }
	$desk = function_exists( 'go_verge_post_editorial_desk' ) ? (string) go_verge_post_editorial_desk( $post_id ) : '';
	if ( '' !== $desk && ! in_array( $desk, array( 'tecnologia', 'technology', 'tech' ), true ) ) { return array(); }
	$technology_desk = '' !== $desk;
	$by_id = array();
	$category_topics = array();
	$category_desks = array();
	foreach ( (array) $terms as $term ) {
		if ( ! ( $term instanceof WP_Term ) ) { continue; }
		$by_id[ (int) $term->term_id ] = $term;
		$term_desk = function_exists( 'go_verge_category_editorial_desk' ) ? (string) go_verge_category_editorial_desk( $term ) : '';
		if ( $term_desk ) { $category_desks[ $term_desk ] = true; }
		if ( 'tecnologia' !== $term_desk ) { continue; }
		$lineage = array( $term );
		foreach ( (array) get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
			$ancestor = get_term( $ancestor_id, 'category' );
			if ( $ancestor instanceof WP_Term ) { $lineage[] = $ancestor; }
		}
		foreach ( $lineage as $candidate ) {
			$topic = go_verge_channel_invite_technology_topic( $candidate->slug . ' ' . $candidate->name );
			if ( $topic ) { $category_topics[ (int) $term->term_id ] = $topic; break; }
		}
	}
	/* Conservative fallback if the canonical desk helper cannot choose between
	 * conflicting categories. A secondary technology term cannot steal Games. */
	if ( ! $technology_desk && $category_desks ) {
		if ( 1 !== count( $category_desks ) || empty( $category_desks['tecnologia'] ) ) { return array(); }
		$technology_desk = true;
	}

	$primary_topic = '';
	foreach ( array( '_go_primary_category_id', 'rank_math_primary_category', '_yoast_wpseo_primary_category' ) as $meta_key ) {
		$id = absint( get_post_meta( $post_id, $meta_key, true ) );
		if ( isset( $by_id[ $id ] ) ) {
			$primary_topic = $category_topics[ $id ] ?? '';
			break;
		}
	}
	$subject = function_exists( 'go_verge_article_subject' ) ? go_verge_article_subject( $post_id ) : null;
	$subject_topic = '';
	if ( is_array( $subject ) && in_array( (string) ( $subject['type'] ?? '' ), array( 'go_entity', 'post_tag' ), true ) ) {
		$subject_topic = go_verge_channel_invite_technology_topic( $subject['name'] ?? '' );
		if ( ! $subject_topic ) { $subject_topic = go_verge_channel_invite_technology_topic( $subject['type_label'] ?? '' ); }
	}
	if ( ! $technology_desk && ! $subject_topic ) { return array(); }

	/* A narrow assigned subeditoria leads; canonical subjects refine broad
	 * Hardware/Apps categories (for example headphones or Windows). */
	$topic = $primary_topic;
	if ( ! $topic || in_array( $topic, array( 'computers', 'software' ), true ) ) { $topic = $subject_topic ?: $topic; }
	if ( ! $topic ) { $topic = $category_topics ? (string) reset( $category_topics ) : ''; }
	return array( 'technology_topic' => $topic ?: 'general' );
}

/** Copy identifies the shared Technology channel, not a dedicated topic feed. */
function go_verge_channel_invite_technology_copy( $cluster ) {
	$topics = array(
		'phones' => array( 'De olho em celulares?', 'Acompanhe celulares e outras novidades no canal de Tecnologia do Overdrive no WhatsApp' ),
		'ai' => array( 'Quer acompanhar o que muda na IA?', 'Veja novidades de IA e outros assuntos no canal de Tecnologia do Overdrive no WhatsApp' ),
		'windows' => array( 'Quer acompanhar as novidades do Windows?', 'Acompanhe novidades do Windows no canal de Tecnologia do Overdrive no WhatsApp' ),
		'computers' => array( 'De olho em PCs e notebooks?', 'Acompanhe PCs, hardware e outras novidades no canal de Tecnologia do Overdrive no WhatsApp' ),
		'tv' => array( 'Quer saber mais sobre TVs e monitores?', 'Veja TVs, monitores e outras novidades no canal de Tecnologia do Overdrive no WhatsApp' ),
		'audio' => array( 'Curte novidades de fones e áudio?', 'Acompanhe áudio e outros assuntos no canal de Tecnologia do Overdrive no WhatsApp' ),
		'wearables' => array( 'De olho em relógios e dispositivos vestíveis?', 'Veja wearables e outras novidades no canal de Tecnologia do Overdrive no WhatsApp' ),
		'software' => array( 'Quer acompanhar novidades de apps e software?', 'Veja apps, software e outros assuntos no canal de Tecnologia do Overdrive no WhatsApp' ),
		'science' => array( 'Curioso sobre ciência e tecnologia?', 'Acompanhe ciência e outras novidades no canal de Tecnologia do Overdrive no WhatsApp' ),
	);
	$topic = sanitize_key( (string) ( $cluster['technology_topic'] ?? '' ) );
	return $topics[ $topic ] ?? array( (string) ( $cluster['question'] ?? '' ), (string) ( $cluster['channel_cta'] ?? '' ) );
}

/** Só matéria comum, no loop principal, com um cluster resolvido. */
function go_verge_channel_invite_applies( $content ) {
	if ( ! go_verge_channel_invite_enabled() || ! is_string( $content ) || '' === trim( $content ) ) {
		return false;
	}
	if ( ! is_singular( 'post' ) || ! in_the_loop() || ! is_main_query() ) {
		return false;
	}

	return (bool) go_verge_channel_invite_for_post();
}

/**
 * O ícone do cluster — a assinatura visual, e a única coisa que se repete.
 *
 * Trocou a etiqueta de texto por ícone em 14/08/2026, por dois motivos que
 * andam juntos:
 *
 * 1. O emoji de bandeira NÃO é confiável. O Windows não embarca os glifos de
 *    regional indicator, então 🇹🇷 caía para as duas letras "TR" em caixinhas no
 *    Chrome de desktop. Um símbolo de identidade que só aparece em metade dos
 *    aparelhos não é identidade. O SVG desenha igual em todo lugar.
 * 2. Repetir a mesma etiqueta de texto no bloco do canal e no da seção fazia a
 *    palavra virar ruído — o leitor lia "GAMES / GAMES" na mesma página. O
 *    ícone identifica sem soletrar, então pode aparecer duas vezes sem cansar.
 *
 * O crescente e a estrela vêm na vermelha da bandeira turca (#E30A17). É a única
 * cor fora da paleta em todo o tema, e ela cabe porque ocupa 16px: nesse tamanho
 * é insígnia, não esquema de cor.
 *
 * @param string $key Chave do cluster.
 * @return string SVG inline, ou string vazia.
 */
function go_verge_channel_invite_icon( $key ) {
	$open = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false">';

	switch ( $key ) {
		case 'turcas':
			/*
			 * Crescente e estrela em branco, porque o selo atrás é o vermelho da
			 * bandeira. Juntos os dois formam uma bandeirinha — que é o que o
			 * leitor reconhece de relance, sem precisar da palavra "turcas".
			 * Desenhado em SVG e não em emoji: o Windows não embarca os glifos de
			 * bandeira e a versão em emoji caía para as letras "TR" em caixinhas.
			 */
			/*
			 * O crescente são dois arcos: o de fora vai, o de dentro volta, e a
			 * área entre eles é a lua. As bandeiras de sinal (`1 0` no primeiro,
			 * `1 1` no segundo) são o que define de que lado fica a abertura —
			 * invertê-las vira a lua ao contrário, que é erro de bandeira, não de
			 * estilo. Conferido no navegador: esta combinação abre para a direita,
			 * como na bandeira turca, deixando o vão onde a estrela entra.
			 */
			return $open
				. '<path fill="currentColor" d="M11.6 5.5A7 7 0 1 0 11.6 18.5 5.6 5.6 0 1 1 11.6 5.5Z"/>'
				. '<path fill="currentColor" d="m16.9 8.35 1.07 1.5 1.76-.56-1.09 1.5 1.08 1.49-1.76-.57-1.08 1.49.02-1.85-1.77-.58 1.77-.55Z"/>'
				. '</svg>';

		case 'games':
			return $open
				. '<path fill="currentColor" d="M7.3 7.5h9.4a4.3 4.3 0 0 1 4.25 3.63l.7 4.4A2.6 2.6 0 0 1 19.08 18.5c-.83 0-1.6-.4-2.08-1.06l-.9-1.25a1.4 1.4 0 0 0-1.14-.59H9.04c-.45 0-.88.22-1.14.59l-.9 1.25c-.48.67-1.25 1.06-2.08 1.06a2.6 2.6 0 0 1-2.57-2.97l.7-4.4A4.3 4.3 0 0 1 7.3 7.5Zm-.05 2.9v1.15H6.1v1.2h1.15v1.15h1.2V12.75H9.6v-1.2H8.45V10.4Zm8.2.35a.9.9 0 1 0 0 1.8.9.9 0 0 0 0-1.8Zm1.85 2a.9.9 0 1 0 0 1.8.9.9 0 0 0 0-1.8Z"/>'
				. '</svg>';

		case 'pop':
			return $open
				. '<path fill="currentColor" d="M4.2 5h15.6a2 2 0 0 1 2 2v8.6a2 2 0 0 1-2 2h-5.4l.5 1.9h2.1a.75.75 0 0 1 0 1.5H7a.75.75 0 0 1 0-1.5h2.1l.5-1.9H4.2a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm6.05 3.35v5.9l5.1-2.95Z"/>'
				. '</svg>';
		case 'technology':
			return $open . '<path fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" d="M8 3v3m4-3v3m4-3v3M8 18v3m4-3v3m4-3v3M3 8h3m-3 4h3m-3 4h3m12-8h3m-3 4h3m-3 4h3M6 6h12v12H6zM9 9h6v6H9z"/></svg>';
	}

	return '';
}

/**
 * A etiqueta que recorta a borda — a assinatura do componente.
 *
 * No cluster turco ela é uma bandeirinha de verdade: retângulo vermelho com o
 * crescente e a estrela em branco. Nos outros é o ícone limpo, sem caixa.
 *
 * A versão com selo arredondado grande, degradê no fundo e pílula de ação foi
 * recusada por parecer gerada por IA — e a crítica estava certa: selo + degradê
 * + pílula é o vocabulário padrão de componente de landing page automática. A
 * etiqueta recortando a borda é um desenho de pasta de arquivo; é editorial, e
 * nenhum outro bloco do site usa essa forma.
 *
 * @param string $key   Cluster.
 * @param string $extra Classe adicional.
 * @return string
 */
function go_verge_channel_invite_badge( $key, $extra = '' ) {
	$icon = go_verge_channel_invite_icon( $key );
	if ( '' === $icon ) {
		return '';
	}

	$class = 'go-channel-invite__tag';
	if ( 'turcas' === $key ) {
		$class .= ' go-channel-invite__tag--flag';
	}
	if ( '' !== $extra ) {
		$class .= ' ' . $extra;
	}

	return '<span class="' . esc_attr( $class ) . '">' . $icon . '</span>';
}

/** O glifo do WhatsApp. Informa o destino do clique — não é ornamento. */
function go_verge_channel_invite_whatsapp_glyph() {
	return '<svg class="go-channel-invite__glyph" viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" focusable="false">'
		. '<path fill="currentColor" d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.25-1.38a9.9 9.9 0 0 0 4.79 1.22c5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.82 9.82 0 0 0 12.04 2Zm0 18.15a8.2 8.2 0 0 1-4.2-1.15l-.3-.18-3.12.82.83-3.04-.2-.31a8.19 8.19 0 0 1-1.26-4.38c0-4.54 3.7-8.23 8.25-8.23a8.2 8.2 0 0 1 8.24 8.24c0 4.54-3.7 8.23-8.24 8.23Zm4.52-6.16c-.25-.12-1.47-.72-1.69-.81-.23-.08-.39-.12-.56.13-.16.24-.64.8-.78.97-.14.16-.29.18-.54.06-.25-.13-1.05-.39-1.99-1.23-.74-.66-1.23-1.47-1.38-1.72-.14-.25-.01-.38.11-.5.11-.11.25-.29.37-.43.13-.15.17-.25.25-.41.08-.17.04-.31-.02-.43-.06-.12-.56-1.34-.76-1.84-.2-.48-.4-.42-.56-.43h-.47c-.17 0-.43.06-.66.31-.22.25-.87.85-.87 2.07s.89 2.4 1.02 2.56c.12.17 1.75 2.67 4.23 3.74.59.26 1.05.41 1.41.52.59.19 1.13.16 1.56.1.48-.07 1.47-.6 1.67-1.18.21-.58.21-1.07.15-1.18-.06-.1-.22-.16-.47-.28Z"/>'
		. '</svg>';
}

/**
 * Assunto editorial seguro para o convite.
 *
 * O mesmo resolvedor alimenta pergunta e CTA. Isso evita um erro sutil: a
 * primeira linha falar de uma entidade e o link falar de outra. Em review de
 * game, a ficha da análise continua tendo prioridade absoluta sobre qualquer
 * menção do título ou do corpo — "Persona Engine" nunca pode vencer o jogo
 * efetivamente avaliado.
 *
 * @param array<string,mixed> $cluster Cluster resolvido.
 * @return string
 */
function go_verge_channel_invite_subject_name( $cluster ) {
	static $cache = array();

	$post_id = absint( get_queried_object_id() );
	$key     = (string) ( $cluster['key'] ?? '' );
	$cache_key = $post_id . ':' . $key;

	if ( isset( $cache[ $cache_key ] ) ) {
		return $cache[ $cache_key ];
	}
	if ( ! $post_id || ! function_exists( 'go_verge_article_subject' ) ) {
		$cache[ $cache_key ] = '';
		return '';
	}

	$name = '';

	/*
	 * Reviews são um caso especial: a ficha estruturada conhece o objeto da
	 * análise melhor que qualquer resolvedor semântico. Isso também cobre
	 * manchetes em que o nome do recurso aparece com mais destaque que o jogo.
	 */
	if ( 'games' === $key
		&& function_exists( 'go_verge_is_review_post' )
		&& go_verge_is_review_post( $post_id )
		&& function_exists( 'go_verge_review_game_name' ) ) {
		$name = trim( wp_strip_all_tags( (string) go_verge_review_game_name( $post_id ) ) );
	}

	if ( '' === $name ) {
		$subject = go_verge_article_subject( $post_id );
		$name    = is_array( $subject ) ? trim( wp_strip_all_tags( (string) ( $subject['name'] ?? '' ) ) ) : '';
	}

	$name = preg_replace( '/\s+/u', ' ', (string) $name );
	$name = trim( (string) $name );

	/*
	 * O bloco é um aparte curto. Se o nome não cabe com folga em duas linhas no
	 * mobile, melhor usar copy contextual genérico que truncar nome próprio.
	 */
	if ( '' === $name || mb_strlen( $name ) > 32 ) {
		$name = '';
	}

	$cache[ $cache_key ] = $name;
	return $name;
}

/** Normaliza texto apenas para detectar a intenção editorial. */
function go_verge_channel_invite_match_text( $text ) {
	$text = remove_accents( wp_strip_all_tags( (string) $text ) );
	$text = strtolower( $text );
	$text = preg_replace( '/[^a-z0-9]+/', ' ', $text );
	return trim( preg_replace( '/\s+/', ' ', (string) $text ) );
}

/**
 * Intenção da matéria de games. Não tenta descobrir o assunto — só o tipo de
 * necessidade de quem abriu a página: review, guia, código, beta, promoção etc.
 *
 * @param int $post_id Post.
 * @return string
 */
function go_verge_channel_invite_game_intent( $post_id ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( isset( $cache[ $post_id ] ) ) {
		return $cache[ $post_id ];
	}

	if ( function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id ) ) {
		$cache[ $post_id ] = 'review';
		return 'review';
	}

	$cats = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
	$cats = is_wp_error( $cats ) ? array() : array_map( 'sanitize_title', (array) $cats );
	$text = go_verge_channel_invite_match_text(
		get_the_title( $post_id ) . ' ' .
		(string) get_post_meta( $post_id, 'rank_math_title', true ) . ' ' .
		(string) get_post_meta( $post_id, 'rank_math_focus_keyword', true )
	);

	$has_cat = static function ( $needles ) use ( $cats ) {
		return (bool) array_intersect( $cats, (array) $needles );
	};
	$has = static function ( $needles ) use ( $text ) {
		foreach ( (array) $needles as $needle ) {
			$needle = go_verge_channel_invite_match_text( $needle );
			if ( '' !== $needle && preg_match( '/(?:^| )' . preg_quote( $needle, '/' ) . '(?: |$)/', $text ) ) {
				return true;
			}
		}
		return false;
	};

	/* Específicos primeiro: "como jogar o beta" é beta, não guia genérico. */
	if ( $has( array( 'beta', 'teste aberto', 'acesso antecipado', 'early access' ) ) ) {
		$intent = 'beta';
	} elseif ( $has_cat( array( 'codigos', 'codes', 'codigo' ) ) || $has( array( 'codigo', 'codigos', 'code', 'codes' ) ) ) {
		$intent = 'codes';
	} elseif ( $has_cat( array( 'jogos-gratis', 'gratis' ) ) || $has( array( 'jogo gratis', 'jogos gratis', 'gratis para jogar', 'free to play' ) ) ) {
		$intent = 'free';
	} elseif ( $has_cat( array( 'promo-games', 'promocoes', 'ofertas', 'guias-de-compra' ) ) || $has( array( 'promocao', 'promocoes', 'oferta', 'ofertas', 'desconto', 'menor preco' ) ) ) {
		$intent = 'deal';
	} elseif ( $has_cat( array( 'dicas-e-guias', 'guias', 'guia' ) ) || preg_match( '/^(como|guia|dicas?)\b/', $text ) ) {
		$intent = 'guide';
	} elseif ( $has( array( 'atualizacao', 'update', 'patch', 'temporada', 'season' ) ) ) {
		$intent = 'update';
	} elseif ( $has( array( 'lancamento', 'lanca', 'lancado', 'chega', 'estreia', 'data de lancamento', 'pre venda', 'pre-venda' ) ) ) {
		$intent = 'release';
	} else {
		$intent = 'news';
	}

	$cache[ $post_id ] = $intent;
	return $intent;
}

/** Plataforma/serviço pede verbo diferente de um jogo. */
function go_verge_channel_invite_game_subject_kind( $name ) {
	$key = go_verge_channel_invite_match_text( $name );
	$subscriptions = array(
		'ps plus', 'playstation plus', 'xbox game pass', 'game pass', 'nintendo switch online',
	);
	$platforms = array(
		'ps5', 'ps5 pro', 'ps4', 'playstation 5', 'playstation',
		'xbox', 'xbox series x', 'xbox series s', 'xbox series x s',
		'nintendo switch', 'nintendo switch 2', 'switch 2', 'steam', 'pc',
	);
	if ( in_array( $key, $subscriptions, true ) ) {
		return 'subscription';
	}
	if ( in_array( $key, $platforms, true ) ) {
		return 'platform';
	}
	return 'game';
}

/**
 * Pergunta do bloco. Agora ela responde ao conteúdo aberto, não apenas à
 * editoria. Quando não há assunto seguro, mantém uma pergunta genérica — nunca
 * inventa um nome a partir de uma menção solta.
 *
 * @param array<string,mixed> $cluster Cluster.
 * @return string
 */
function go_verge_channel_invite_question( $cluster ) {
	if ( 'technology' === ( $cluster['key'] ?? '' ) ) { return go_verge_channel_invite_technology_copy( $cluster )[0]; }
	$fallback = (string) ( $cluster['question'] ?? '' );
	$name     = go_verge_channel_invite_subject_name( $cluster );
	$key      = (string) ( $cluster['key'] ?? '' );

	if ( '' === $name ) {
		if ( 'games' === $key ) {
			$post_id = absint( get_queried_object_id() );
			switch ( go_verge_channel_invite_game_intent( $post_id ) ) {
				case 'free':
					return __( 'Quer mais jogos grátis?', 'go-verge' );
				case 'deal':
					return __( 'Quer jogos grátis e boas promoções?', 'go-verge' );
				case 'codes':
					return __( 'Quer jogos grátis e boas promoções?', 'go-verge' );
				case 'guide':
					return __( 'Quer jogos grátis e boas promoções?', 'go-verge' );
				case 'beta':
					return __( 'Quer jogos grátis e boas promoções?', 'go-verge' );
			}
		}
		return $fallback;
	}

	if ( 'turcas' === $key ) {
		return sprintf( __( 'Acompanha %s?', 'go-verge' ), $name );
	}
	if ( 'pop' === $key ) {
		return sprintf( __( 'Curte %s?', 'go-verge' ), $name );
	}
	if ( 'games' !== $key ) {
		return $fallback;
	}

	$post_id = absint( get_queried_object_id() );
	$intent  = go_verge_channel_invite_game_intent( $post_id );
	$kind    = go_verge_channel_invite_game_subject_kind( $name );

	if ( 'subscription' === $kind ) {
		return sprintf( __( 'Assina %s?', 'go-verge' ), $name );
	}
	if ( 'platform' === $kind ) {
		return sprintf( __( 'Joga no %s?', 'go-verge' ), $name );
	}

	switch ( $intent ) {
		case 'review':
			return sprintf( __( 'De olho em %s?', 'go-verge' ), $name );
		case 'guide':
		case 'codes':
		case 'update':
			return sprintf( __( 'Jogando %s?', 'go-verge' ), $name );
		case 'beta':
			return sprintf( __( 'Vai testar %s?', 'go-verge' ), $name );
		case 'release':
			return sprintf( __( 'Esperando %s?', 'go-verge' ), $name );
		case 'free':
			return __( 'Quer mais jogos grátis?', 'go-verge' );
		case 'deal':
			return sprintf( __( 'De olho em %s?', 'go-verge' ), $name );
		default:
			return sprintf( __( 'Curte %s?', 'go-verge' ), $name );
	}
}

/**
 * A chamada do canal, com copy adaptada ao assunto e à intenção da matéria.
 *
 * O nome nunca vem do corpo isoladamente. Reviews usam o jogo da ficha; os
 * demais posts usam o assunto canônico do portal. Quando isso não é seguro, o
 * texto volta para uma promessa genérica da editoria.
 *
 * @param array<string,mixed> $cluster Cluster resolvido.
 * @return string
 */
function go_verge_channel_invite_cta( $cluster ) {
	if ( 'technology' === ( $cluster['key'] ?? '' ) ) { return go_verge_channel_invite_technology_copy( $cluster )[1]; }
	$fallback = (string) ( $cluster['channel_cta'] ?? '' );
	$format   = (string) ( $cluster['channel_cta_subject'] ?? '' );
	$name     = go_verge_channel_invite_subject_name( $cluster );
	$key      = (string) ( $cluster['key'] ?? '' );

	if ( 'games' === $key ) {
		$post_id = absint( get_queried_object_id() );
		$intent  = go_verge_channel_invite_game_intent( $post_id );

		/* Mesmo sem assunto, o tipo da matéria já permite ser mais útil. */
		if ( '' === $name ) {
			switch ( $intent ) {
				case 'free':
					return __( 'Receba alertas de jogos grátis e promoções no WhatsApp', 'go-verge' );
				case 'deal':
					return __( 'Receba alertas de jogos grátis e promoções no WhatsApp', 'go-verge' );
				case 'codes':
					return __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de códigos e recompensas', 'go-verge' );
				case 'guide':
					return __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de guias e dicas', 'go-verge' );
				case 'beta':
					return __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de novidades sobre betas', 'go-verge' );
			}
			return $fallback;
		}

		switch ( $intent ) {
			case 'review':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de guias e análises de %s', 'go-verge' ), $name );
			case 'codes':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de códigos de %s', 'go-verge' ), $name );
			case 'guide':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de guias de %s', 'go-verge' ), $name );
			case 'beta':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de novidades de %s', 'go-verge' ), $name );
			case 'update':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de atualizações de %s', 'go-verge' ), $name );
			case 'release':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de novidades de %s', 'go-verge' ), $name );
			case 'free':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de novidades de %s', 'go-verge' ), $name );
			case 'deal':
				return sprintf( __( 'Receba alertas de jogos grátis e promoções no WhatsApp, além de novidades de %s', 'go-verge' ), $name );
		}
	}

	if ( '' === $name || '' === $format || false === strpos( $format, '%s' ) ) {
		return $fallback;
	}

	return sprintf( $format, $name );
}

/**
 * Bloco do canal — o que entra antes do primeiro H2.
 *
 * @param array<string,mixed> $cluster Cluster resolvido.
 * @return string
 */
function go_verge_channel_invite_channel_markup( $cluster ) {
	$url = esc_url( (string) ( $cluster['channel_url'] ?? '' ) );
	if ( '' === $url ) {
		return '';
	}

	$key   = (string) ( $cluster['key'] ?? '' );
	$html  = '<aside class="go-channel-invite go-channel-invite--channel" data-go-ad-integrity="atomic" ' . GO_VERGE_CHANNEL_INVITE_MARK . '="channel" data-go-channel-cluster="' . esc_attr( $key ) . '">';
	$html .= go_verge_channel_invite_badge( $key );
	/*
	 * Só a pergunta e a ação. Havia uma terceira linha aqui — "Receba novidades,
	 * listas, estreias e recomendações no nosso canal do WhatsApp" — que dizia
	 * exatamente o que o link abaixo já promete, e sozinha respondia por metade
	 * da altura do bloco num celular. Aparte dentro de matéria compete com o
	 * texto por atenção: o que não acrescenta, custa.
	 */
	$html .= '<strong class="go-channel-invite__question">' . esc_html( go_verge_channel_invite_question( $cluster ) ) . '</strong>';
	$html .= '<div class="go-channel-invite__action">';
	$html .= go_verge_channel_invite_whatsapp_glyph();
	/*
	 * A seta é o mesmo `<span>` com o caractere que todo link de "ver mais" do
	 * site usa. Não é preguiça: `assets/js/theme.js` (v29, `decorateArrows`)
	 * encontra qualquer span cujo conteúdo seja só a seta, aplica `.go-ui-arrow`,
	 * e o design-polish desenha a seta com pseudo-elementos. Desenhar a seta aqui
	 * por conta própria — como este bloco fazia com `content` no CSS — produzia a
	 * ÚNICA seta do site fora desse mecanismo: a mesma página podia mostrar duas
	 * setas com desenhos diferentes.
	 */
	$label = 'technology' === $key ? ' aria-label="' . esc_attr__( 'Abrir o canal de Tecnologia do Overdrive no WhatsApp (nova aba)', 'go-verge' ) . '"' : '';
	$rel = 'technology' === $key ? 'noopener noreferrer nofollow' : 'noopener nofollow';
	$html .= '<a class="go-channel-invite__link" href="' . $url . '" target="_blank" rel="' . $rel . '"' . $label . '>' . esc_html( go_verge_channel_invite_cta( $cluster ) ) . '<span aria-hidden="true">→</span></a>';
	$html .= '</div></aside>';

	return $html;
}

/**
 * Bloco da seção — o que fecha a matéria.
 *
 * O endereço vem de `get_category_link()`, não de uma URL escrita à mão: a
 * categoria turca mora em /category/entretenimento/filmes-series-dizis-turcas/,
 * e uma mudança de estrutura de permalink quebraria um link fixo em 180 matérias
 * sem avisar ninguém.
 *
 * @param array<string,mixed> $cluster Cluster resolvido.
 * @return string
 */
function go_verge_channel_invite_section_markup( $cluster ) {
	$slug = sanitize_title( (string) ( $cluster['section_slug'] ?? '' ) );
	if ( '' === $slug ) {
		return '';
	}

	$term = get_term_by( 'slug', $slug, 'category' );
	if ( ! $term || is_wp_error( $term ) ) {
		return '';
	}
	$link = get_category_link( $term );
	if ( ! $link || is_wp_error( $link ) ) {
		return '';
	}

	$key   = (string) ( $cluster['key'] ?? '' );
	$html  = '<aside class="go-channel-invite go-channel-invite--section" data-go-ad-integrity="atomic" ' . GO_VERGE_CHANNEL_INVITE_MARK . '="section" data-go-channel-cluster="' . esc_attr( $key ) . '">';
	$html .= go_verge_channel_invite_badge( $key, 'go-channel-invite__tag--inline' );
	$html .= '<p class="go-channel-invite__lead">';
	$html .= sprintf(
		/* translators: %s: nome da seção, já dentro de um link. */
		esc_html__( 'O Overdrive tem uma seção inteira de %s.', 'go-verge' ),
		'<a class="go-channel-invite__link" href="' . esc_url( $link ) . '">' . esc_html( (string) ( $cluster['section_name'] ?? $term->name ) ) . '</a>'
	);
	$html .= '</p></aside>';

	return $html;
}

/**
 * Deslocamentos dos H2 que estão no NÍVEL DE TOPO do conteúdo.
 *
 * Procurar `<h2` com uma expressão simples encontra também os que estão dentro
 * de um wrapper — um grupo do editor, uma coluna, um figure. Inserir ali coloca
 * o convite DENTRO daquele container, onde ele herda largura, fundo e recortes
 * que não são dele. Foi assim que o bloco apareceu quebrado, com conteúdo
 * escapando da moldura.
 *
 * Então conta-se a profundidade: só serve o H2 com profundidade zero. Se todos
 * os subtítulos da matéria estiverem aninhados, o convite do canal simplesmente
 * não entra — e a matéria ainda recebe o bloco de seção no fim.
 *
 * @param string $content Conteúdo renderizado.
 * @return int[]
 */
function go_verge_channel_invite_top_level_h2_offsets( $content ) {
	if ( ! preg_match_all( '/<(\/?)([a-z][a-z0-9]*)\b[^>]*?(\/?)>/i', $content, $tags, PREG_SET_ORDER | PREG_OFFSET_CAPTURE ) ) {
		return array();
	}

	/* Elementos vazios não abrem nível — contá-los desalinharia a profundidade. */
	$void    = array( 'br', 'hr', 'img', 'input', 'meta', 'link', 'source', 'track', 'wbr', 'area', 'base', 'col', 'embed', 'param' );
	$depth   = 0;
	$offsets = array();

	foreach ( $tags as $tag ) {
		$closing = '' !== $tag[1][0];
		$name    = strtolower( $tag[2][0] );
		$self    = '' !== $tag[3][0];

		if ( 'h2' === $name && ! $closing && 0 === $depth ) {
			$offsets[] = (int) $tag[0][1];
		}
		if ( $self || in_array( $name, $void, true ) ) {
			continue;
		}

		$depth += $closing ? -1 : 1;
		if ( $depth < 0 ) {
			$depth = 0;
		}
	}

	return $offsets;
}

/**
 * Compatibilidade: primeiro H2 de topo, quando algum consumidor externo usa
 * o helper antigo.
 *
 * @param string $content Conteúdo renderizado.
 * @return int|null
 */
function go_verge_channel_invite_first_top_level_h2( $content ) {
	$offsets = go_verge_channel_invite_top_level_h2_offsets( $content );
	return $offsets ? (int) $offsets[0] : null;
}

/**
 * Insere o convite do canal imediatamente antes do primeiro H2.
 *
 * Sem H2 no texto, o bloco não entra. É literal ao pedido, e é a decisão certa:
 * uma nota curta sem subtítulo não tem "primeira pausa" — encaixar o convite
 * depois de um parágrafo arbitrário seria inventar um lugar que o texto não tem.
 * A matéria curta ainda recebe o bloco de seção no fim.
 *
 * Roda depois do compositor de anúncios (9999) e da recirculação (10000) para
 * enxergar o que já está no texto e não encostar em nada.
 *
 * @param string $content Conteúdo renderizado.
 * @return string
 */
function go_verge_channel_invite_insert_channel( $content ) {
	if ( ! go_verge_channel_invite_applies( $content ) ) {
		return $content;
	}
	if ( preg_match( '~\b' . preg_quote( GO_VERGE_CHANNEL_INVITE_MARK, '~' ) . '\s*=\s*(?:["\']channel["\']|channel(?=\s|>))~i', $content ) ) {
		return $content;
	}
	$cluster = go_verge_channel_invite_for_post();
	/* A channel link deliberately written into the article remains the editor's
	 * choice. Technology routing neither replaces it nor adds a second invite. */
	if ( 'technology' === ( $cluster['key'] ?? '' )
		&& preg_match( '~<a\b(?:"[^"]*"|\'[^\']*\'|[^\'">])*?\shref\s*=\s*(?:"(?:https?:)?//(?:www\.)?whatsapp\.com/channel/[^"<>]+"|\'(?:https?:)?//(?:www\.)?whatsapp\.com/channel/[^\'<>]+\'|(?:https?:)?//(?:www\.)?whatsapp\.com/channel/[^\s"\'<>`=]+(?=\s|>))~i', $content ) ) {
		return $content;
	}

	$offsets = go_verge_channel_invite_top_level_h2_offsets( $content );
	if ( ! $offsets ) {
		return $content;
	}

	/*
	 * Nunca encostar em anúncio/recirculação, mas também não desistir no
	 * primeiro conflito. Procura o primeiro H2 de topo com distância segura.
	 */
	$offset = null;
	foreach ( $offsets as $candidate ) {
		if ( function_exists( 'go_verge_ads_break_near_protected_ui' ) && go_verge_ads_break_near_protected_ui( $content, $candidate ) ) {
			continue;
		}
		$offset = (int) $candidate;
		break;
	}
	if ( null === $offset ) {
		return $content;
	}

	$markup = go_verge_channel_invite_channel_markup( $cluster );
	if ( '' === $markup ) {
		return $content;
	}

	return substr( $content, 0, $offset ) . "\n" . $markup . "\n" . substr( $content, $offset );
}
add_filter( 'the_content', 'go_verge_channel_invite_insert_channel', 10020 );

/**
 * Fecha a matéria com o convite da seção.
 *
 * @param string $content Conteúdo renderizado.
 * @return string
 */
function go_verge_channel_invite_append_section( $content ) {
	if ( ! go_verge_channel_invite_applies( $content ) ) {
		return $content;
	}
	if ( false !== strpos( $content, GO_VERGE_CHANNEL_INVITE_MARK . '="section"' ) ) {
		return $content;
	}

	$markup = go_verge_channel_invite_section_markup( go_verge_channel_invite_for_post() );

	return '' === $markup ? $content : $content . "\n" . $markup;
}
add_filter( 'the_content', 'go_verge_channel_invite_append_section', 10021 );

/**
 * A folha só é pedida quando a matéria realmente vai mostrar um dos blocos.
 *
 * @return void
 */
function go_verge_channel_invite_enqueue() {
	if ( is_admin() || ! is_singular( 'post' ) || ! go_verge_channel_invite_enabled() ) {
		return;
	}
	if ( ! go_verge_channel_invite_for_post() ) {
		return;
	}

	$rel = '/assets/css/channel-invite.css';
	wp_enqueue_style(
		'go-verge-channel-invite',
		GO_VERGE_URI . $rel,
		array(),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_channel_invite_enqueue', 10110 );
