<?php
/**
 * ALT text e legenda editorial automáticos.
 *
 * Ao inserir uma imagem no editor, os dois campos são preenchidos sozinhos a
 * partir de FATOS que o CMS já tem — nunca de invenção.
 *
 * POR QUE ESTE MÓDULO É DETERMINÍSTICO E NÃO CHAMA O MODELO DE VISÃO
 * ------------------------------------------------------------------
 * O tema já tem uma IA de visão que roda no navegador
 * (`assets/js/local-ai-image-text.js`, Xenova/transformers). Ela é boa e
 * continua onde estava, atrás de um botão: baixa ~200 MB de pesos na primeira
 * execução e leva segundos por imagem. Disparar isso a cada inserção seria uma
 * troca ruim — a redação insere dezenas de fotos por dia.
 *
 * Então a divisão é:
 *
 *   automático (aqui)   fatos conhecidos, instantâneo, sem rede
 *   sob demanda (lá)    descrição visual real, quando o editor pedir
 *
 * O refinamento por IA sobrescreve o texto automático; o texto automático NUNCA
 * sobrescreve o que um humano escreveu.
 *
 * A REGRA DO CRÉDITO
 * ------------------
 * `go_verge_image_credit()` só devolve crédito que existe em algum lugar
 * verificável: um campo preenchido por pessoa, o IPTC/EXIF do arquivo, ou uma
 * legenda anterior que já o carregava. Quando não há, a legenda sai **sem
 * crédito** e o campo é marcado como pendente. Em nenhuma circunstância este
 * arquivo escreve "Divulgação", "Reprodução" ou um nome de agência que não
 * tenha lido de uma dessas fontes. Crédito errado é problema jurídico, não
 * problema de preenchimento.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Meta onde a redação grava o crédito da foto. */
const GO_VERGE_IMAGE_CREDIT_META = '_go_image_credit';

/** Alt maior que isto é truncado por leitores de tela; alt é frase, não parágrafo. */
const GO_VERGE_ALT_MAX_CHARS = 125;

/** Legenda editorial, sem contar o crédito. */
const GO_VERGE_CAPTION_MAX_CHARS = 220;

/**
 * Rótulos que introduzem crédito numa legenda em português.
 *
 * @return array<int,string>
 */
function go_verge_image_credit_labels() {
	return array( 'Foto', 'Fotos', 'Imagem', 'Imagens', 'Vídeo', 'Arte', 'Ilustração', 'Reprodução', 'Crédito' );
}

/**
 * Separar uma legenda em texto editorial e crédito já embutido.
 *
 * Reconhece as formas que a redação realmente usa:
 *
 *     ... (Foto: Divulgação/Netflix)
 *     ... (Imagem: Reprodução/Instagram)
 *     ... (Reprodução/X)
 *     ... — Foto: Agência Brasil
 *
 * O crédito encontrado é devolvido VERBATIM. Isto é preservação, não geração:
 * se a legenda anterior dizia "Divulgação/Star+", continua dizendo.
 *
 * @param string $caption Legenda bruta.
 * @return array{text:string,credit:string}
 */
function go_verge_image_split_caption_credit( $caption ) {
	$caption = trim( (string) wp_strip_all_tags( (string) $caption ) );
	if ( '' === $caption ) {
		return array( 'text' => '', 'credit' => '' );
	}

	$labels = implode( '|', array_map( 'preg_quote', go_verge_image_credit_labels() ) );

	/* "(Foto: X)" ou "(Reprodução/X)" no fim. */
	$patterns = array(
		'/\s*[\(\[]\s*(?:' . $labels . ')\s*[:\/]\s*([^\)\]]{1,120})\s*[\)\]]\s*$/ui',
		'/\s*[\(\[]\s*(Reprodu[çc][ãa]o|Divulga[çc][ãa]o)\s*[\/:]?\s*([^\)\]]{0,120})\s*[\)\]]\s*$/ui',
		'/\s*[—\-–]\s*(?:' . $labels . ')\s*[:\/]\s*(.{1,120})$/ui',
	);
	foreach ( $patterns as $index => $pattern ) {
		if ( preg_match( $pattern, $caption, $m ) ) {
			$credit = 1 === $index
				? trim( $m[1] . ( isset( $m[2] ) && '' !== trim( $m[2] ) ? '/' . trim( $m[2] ) : '' ) )
				: trim( (string) $m[1] );
			$text   = trim( (string) preg_replace( $pattern, '', $caption ) );
			return array( 'text' => trim( $text, " \t\n\r\0\x0B" ), 'credit' => $credit );
		}
	}

	return array( 'text' => $caption, 'credit' => '' );
}

/**
 * O crédito de uma imagem, e de onde ele veio.
 *
 * Ordem deliberada: o que uma pessoa escreveu vence o que a câmera gravou, e
 * ambos vencem o silêncio. Não existe ramo que produza um crédito plausível a
 * partir do nada — quando as fontes se esgotam, `text` volta vazio e
 * `missing` fica verdadeiro, para a interface pedir à redação.
 *
 * @param int $attachment_id Attachment ID.
 * @return array{text:string,source:string,missing:bool}
 */
function go_verge_image_credit( $attachment_id ) {
	$attachment_id = absint( $attachment_id );
	$none = array( 'text' => '', 'source' => '', 'missing' => true );
	if ( ! $attachment_id ) {
		return $none;
	}

	/* 1. Campo explícito da redação. */
	$manual = trim( (string) get_post_meta( $attachment_id, GO_VERGE_IMAGE_CREDIT_META, true ) );
	if ( '' !== $manual ) {
		return array( 'text' => $manual, 'source' => 'campo_editorial', 'missing' => false );
	}

	/* 2. Crédito já embutido na legenda gravada na mídia. */
	$stored_caption = wp_get_attachment_caption( $attachment_id );
	$split = go_verge_image_split_caption_credit( (string) $stored_caption );
	if ( '' !== $split['credit'] ) {
		return array( 'text' => $split['credit'], 'source' => 'legenda_da_midia', 'missing' => false );
	}

	/* 3. IPTC/EXIF do arquivo, lido pelo próprio WordPress no upload. */
	$meta = wp_get_attachment_metadata( $attachment_id );
	$image_meta = is_array( $meta ) && isset( $meta['image_meta'] ) && is_array( $meta['image_meta'] ) ? $meta['image_meta'] : array();
	foreach ( array( 'credit' => 'iptc_credit', 'copyright' => 'exif_copyright' ) as $key => $source ) {
		$value = isset( $image_meta[ $key ] ) ? trim( (string) $image_meta[ $key ] ) : '';
		/* Câmeras gravam lixo aqui com frequência: um nome de modelo, um zero,
		 * ou a string vazia com espaços. Só passa o que parece um crédito. */
		if ( '' === $value || strlen( $value ) < 2 || preg_match( '/^[\d\s\.\-_]+$/', $value ) ) {
			continue;
		}
		return array( 'text' => $value, 'source' => $source, 'missing' => false );
	}

	/* 4. Nada. E nada é uma resposta. */
	return $none;
}

/**
 * Entidades que a matéria declara, agrupadas por tipo controlado.
 *
 * É daqui que sai um alt como "Can Yaman como Ferit em cena de Dolunay": os
 * três nomes são registros do CMS ligados a esta matéria, não adivinhação sobre
 * os pixels.
 *
 * @param int $post_id Post ID.
 * @return array<string,array<int,string>>
 */
function go_verge_post_image_entities( $post_id ) {
	$post_id = absint( $post_id );
    $empty = array( 'pessoa' => array(), 'personagem' => array(), 'obra-franquia' => array(), 'empresa-estudio' => array(), 'marca-produto' => array(), 'evento' => array() );
	if ( ! $post_id || ! post_type_exists( 'go_entity' ) || ! taxonomy_exists( 'go_entity_type' ) ) {
		return $empty;
	}

	$ids = get_post_meta( $post_id, '_go_entity_ids', true );
	$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	if ( ! $ids ) {
		return $empty;
	}

	$out = $empty;
	foreach ( array_slice( $ids, 0, 24 ) as $entity_id ) {
		if ( 'go_entity' !== get_post_type( $entity_id ) || 'publish' !== get_post_status( $entity_id ) ) {
			continue;
		}
		$name = go_verge_normalize_editorial_text( get_the_title( $entity_id ) );
		if ( '' === $name ) {
			continue;
		}
		$terms = wp_get_post_terms( $entity_id, 'go_entity_type', array( 'fields' => 'slugs' ) );
		$terms = is_wp_error( $terms ) ? array() : (array) $terms;
		foreach ( $terms as $slug ) {
			$slug = sanitize_key( $slug );
			if ( isset( $out[ $slug ] ) && ! in_array( $name, $out[ $slug ], true ) ) {
				$out[ $slug ][] = $name;
			}
		}
	}
	return $out;
}

/**
 * Regras de qualidade do ALT, num lugar só.
 *
 * Tanto o caminho automático quanto o refinamento por IA passam por aqui, para
 * que "curto, útil e sem stuffing" signifique a mesma coisa nos dois.
 *
 * @param string $alt   Texto candidato.
 * @param array  $guard Contexto: focus_keyword, post_title.
 * @return string
 */
function go_verge_image_sanitize_alt( $alt, $guard = array() ) {
	$alt = go_verge_normalize_editorial_text( $alt );
	if ( '' === $alt ) {
		return '';
	}

	/*
	 * "Imagem de" nunca abre um alt. Leitores de tela já anunciam que o
	 * elemento é uma imagem, então o prefixo gasta os primeiros segundos do
	 * usuário repetindo o que ele acabou de ouvir.
	 */
	$alt = preg_replace(
		'/^\s*(?:uma?\s+)?(?:imagem|foto(?:grafia)?|print|captura(?:\s+de\s+tela)?|ilustra[çc][ãa]o|arte)\s+(?:de|do|da|dos|das|com|que\s+mostra)\s+/ui',
		'',
		$alt
	);
	$alt = preg_replace( '/^\s*(?:na\s+)?(?:imagem|foto)\s*[,:;-]\s*/ui', '', (string) $alt );
	$alt = trim( (string) $alt );

	/* Alt é sintagma, não frase: sem ponto final. */
	$alt = rtrim( $alt, " .;," );

	/*
	 * Anti-stuffing. Duas formas, ambas observadas em campo:
	 * repetir o mesmo token significativo, e colar a focus keyphrase no fim de
	 * uma descrição que não fala dela ("..., na cobertura de <keyword>").
	 */
	$focus = go_verge_normalize_editorial_text( $guard['focus_keyword'] ?? '' );
	if ( '' !== $focus ) {
		$alt = preg_replace( '/\s*[,;]?\s*(?:na|em)\s+(?:cobertura|mat[ée]ria)\s+(?:de|do|da|sobre)\s+' . preg_quote( $focus, '/' ) . '\s*$/ui', '', $alt );
		$alt = trim( (string) $alt, " .;," );
	}
	$alt = go_verge_image_drop_repeated_tokens( $alt );

	/* Um alt idêntico ao título da matéria não descreve a imagem. */
	$post_title = go_verge_normalize_editorial_text( $guard['post_title'] ?? '' );
	if ( '' !== $post_title && 0 === strcasecmp( $alt, $post_title ) && ! empty( $guard['reject_title_echo'] ) ) {
		return '';
	}

	if ( go_verge_title_looks_like_filename( $alt ) ) {
		return '';
	}

	return go_verge_image_trim_words( $alt, GO_VERGE_ALT_MAX_CHARS );
}

/**
 * Remover a terceira ocorrência em diante de um mesmo token significativo.
 *
 * @param string $text Texto.
 * @return string
 */
function go_verge_image_drop_repeated_tokens( $text ) {
	$words = preg_split( '/\s+/u', (string) $text );
	if ( ! is_array( $words ) || count( $words ) < 4 ) {
		return (string) $text;
	}
	$seen = array();
	$out  = array();
	foreach ( $words as $word ) {
		$key = function_exists( 'mb_strtolower' ) ? mb_strtolower( remove_accents( $word ), 'UTF-8' ) : strtolower( remove_accents( $word ) );
		$key = preg_replace( '/[^a-z0-9]/', '', (string) $key );
		if ( strlen( (string) $key ) < 4 ) {
			$out[] = $word;
			continue;
		}
		$seen[ $key ] = ( $seen[ $key ] ?? 0 ) + 1;
		if ( $seen[ $key ] > 2 ) {
			continue;
		}
		$out[] = $word;
	}
	return trim( implode( ' ', $out ) );
}

/**
 * Cortar em limite de palavra, sem reticências no meio de um nome.
 *
 * @param string $text  Texto.
 * @param int    $limit Máximo de caracteres.
 * @return string
 */
function go_verge_image_trim_words( $text, $limit ) {
	$text  = trim( (string) $text );
	$limit = max( 20, (int) $limit );
	$length = function_exists( 'mb_strlen' ) ? mb_strlen( $text, 'UTF-8' ) : strlen( $text );
	if ( $length <= $limit ) {
		return $text;
	}
	$cut = function_exists( 'mb_substr' ) ? mb_substr( $text, 0, $limit, 'UTF-8' ) : substr( $text, 0, $limit );
	$cut = preg_replace( '/\s+\S*$/u', '', $cut );
	return rtrim( (string) $cut, " .,;-" );
}

/**
 * Montar o ALT a partir das entidades da matéria e dos campos da mídia.
 *
 * A ordem responde "o que descreve MESMO esta foto":
 *
 *   1. alt já gravado na mídia            — alguém já resolveu isso
 *   2. legenda da mídia, sem o crédito    — descreve a foto, não a matéria
 *   3. título da mídia, se não for arquivo
 *   4. composição por entidades           — pessoa como personagem em obra
 *   5. obra/jogo ligado à matéria
 *   6. título da matéria                  — último recurso, e sinalizado
 *
 * @param int    $attachment_id Attachment ID.
 * @param int    $post_id       Post que a imagem ilustra.
 * @param array  $entities      Entidades pré-carregadas.
 * @return array{text:string,source:string}
 */
function go_verge_image_alt_suggestion( $attachment_id, $post_id = 0, $entities = null ) {
	$attachment_id = absint( $attachment_id );
	$post_id       = absint( $post_id );
	$guard = array(
		'focus_keyword'      => $post_id ? go_verge_editor_focus_keyword( $post_id ) : '',
		'post_title'         => $post_id ? get_the_title( $post_id ) : '',
		'reject_title_echo'  => true,
	);

	$stored_alt = trim( (string) get_post_meta( $attachment_id, '_wp_attachment_image_alt', true ) );
	if ( '' !== $stored_alt ) {
		$clean = go_verge_image_sanitize_alt( $stored_alt, array_merge( $guard, array( 'reject_title_echo' => false ) ) );
		if ( '' !== $clean ) {
			return array( 'text' => $clean, 'source' => 'alt_da_midia' );
		}
	}

	$split = go_verge_image_split_caption_credit( (string) wp_get_attachment_caption( $attachment_id ) );
	if ( '' !== $split['text'] ) {
		$clean = go_verge_image_sanitize_alt( $split['text'], $guard );
		if ( '' !== $clean ) {
			return array( 'text' => $clean, 'source' => 'legenda_da_midia' );
		}
	}

	$media_title = go_verge_normalize_editorial_text( get_the_title( $attachment_id ) );
	if ( '' !== $media_title && ! go_verge_title_looks_like_filename( $media_title ) ) {
		$clean = go_verge_image_sanitize_alt( $media_title, $guard );
		if ( '' !== $clean ) {
			return array( 'text' => $clean, 'source' => 'titulo_da_midia' );
		}
	}

	$entities = is_array( $entities ) ? $entities : go_verge_post_image_entities( $post_id );
	$composed = go_verge_image_compose_from_entities( $entities );
	if ( '' !== $composed ) {
		$clean = go_verge_image_sanitize_alt( $composed, $guard );
		if ( '' !== $clean ) {
			return array( 'text' => $clean, 'source' => 'entidades_da_materia' );
		}
	}

	$game = $post_id ? go_verge_editor_linked_game_title( $post_id ) : '';
	if ( '' !== $game ) {
		$clean = go_verge_image_sanitize_alt( sprintf( 'Cena de %s', $game ), $guard );
		if ( '' !== $clean ) {
			return array( 'text' => $clean, 'source' => 'obra_ligada' );
		}
	}

	$title = go_verge_normalize_editorial_text( $guard['post_title'] );
	if ( '' !== $title ) {
		return array( 'text' => go_verge_image_trim_words( $title, GO_VERGE_ALT_MAX_CHARS ), 'source' => 'titulo_da_materia' );
	}

	return array( 'text' => '', 'source' => '' );
}

/**
 * "Can Yaman como Ferit em cena de Dolunay".
 *
 * Cada peça só entra se existir como entidade publicada ligada à matéria. Sem
 * pessoa não há "como"; sem obra não há "em cena de". Nada é preenchido por
 * analogia.
 *
 * @param array<string,array<int,string>> $entities Entidades por tipo.
 * @return string
 */
function go_verge_image_compose_from_entities( $entities ) {
	$entities  = is_array( $entities ) ? $entities : array();
	$person    = $entities['pessoa'][0] ?? '';
	$character = $entities['personagem'][0] ?? '';
	$work      = $entities['obra-franquia'][0] ?? '';
	$product   = $entities['marca-produto'][0] ?? '';
	$event     = $entities['evento'][0] ?? '';

	if ( $person && $character && $work ) {
		return sprintf( '%s como %s em cena de %s', $person, $character, $work );
	}
	if ( $person && $character ) {
		return sprintf( '%s como %s', $person, $character );
	}
	if ( $person && $work ) {
		return sprintf( '%s em cena de %s', $person, $work );
	}
	if ( $person && $event ) {
		return sprintf( '%s durante %s', $person, $event );
	}
	if ( $character && $work ) {
		return sprintf( '%s em cena de %s', $character, $work );
	}
	if ( $person ) {
		return $person;
	}
	if ( $work ) {
		return sprintf( 'Cena de %s', $work );
	}
	if ( $product ) {
		return $product;
	}
	if ( $event ) {
		return $event;
	}
	return '';
}

/**
 * Montar a LEGENDA — mais editorial que o alt, e com crédito quando ele existe.
 *
 * @param int   $attachment_id Attachment ID.
 * @param int   $post_id       Post ID.
 * @param array $entities      Entidades pré-carregadas.
 * @return array{text:string,body:string,credit:string,credit_source:string,credit_missing:bool,source:string}
 */
function go_verge_image_caption_suggestion( $attachment_id, $post_id = 0, $entities = null ) {
	$attachment_id = absint( $attachment_id );
	$post_id       = absint( $post_id );
	$credit        = go_verge_image_credit( $attachment_id );
	$entities      = is_array( $entities ) ? $entities : go_verge_post_image_entities( $post_id );

	$body   = '';
	$source = '';

	/* 1. A legenda que já existe na mídia, sem o crédito (ele é recolocado no fim). */
	$split = go_verge_image_split_caption_credit( (string) wp_get_attachment_caption( $attachment_id ) );
	if ( '' !== $split['text'] ) {
		$body   = $split['text'];
		$source = 'legenda_da_midia';
	}

	/* 2. Composição editorial pelas entidades: mais explicativa que o alt. */
	if ( '' === $body ) {
		$body   = go_verge_image_compose_caption_from_entities( $entities, $post_id );
		$source = '' !== $body ? 'entidades_da_materia' : '';
	}

	/* 3. Subtítulo da matéria — escrito por gente, e sobre este assunto. */
	if ( '' === $body && $post_id ) {
		$subtitle = go_verge_normalize_editorial_text( get_post_meta( $post_id, '_go_post_subtitle', true ) );
		if ( '' !== $subtitle ) {
			$body   = $subtitle;
			$source = 'subtitulo_da_materia';
		}
	}

	/* 4. Título da matéria. */
	if ( '' === $body && $post_id ) {
		$body   = go_verge_normalize_editorial_text( get_the_title( $post_id ) );
		$source = '' !== $body ? 'titulo_da_materia' : '';
	}

	$body = go_verge_image_trim_words( go_verge_normalize_editorial_text( $body ), GO_VERGE_CAPTION_MAX_CHARS );
	$text = go_verge_image_format_caption( $body, $credit['text'] );

	return array(
		'text'           => $text,
		'body'           => $body,
		'credit'         => $credit['text'],
		'credit_source'  => $credit['source'],
		'credit_missing' => ! empty( $credit['missing'] ),
		'source'         => $source,
	);
}

/**
 * Frase editorial a partir das entidades: nomeia papel e obra, como uma legenda
 * de veículo faz, em vez de repetir o alt.
 *
 * @param array $entities Entidades por tipo.
 * @param int   $post_id  Post ID.
 * @return string
 */
function go_verge_image_compose_caption_from_entities( $entities, $post_id = 0 ) {
	$entities  = is_array( $entities ) ? $entities : array();
	$person    = $entities['pessoa'][0] ?? '';
	$character = $entities['personagem'][0] ?? '';
	$work      = $entities['obra-franquia'][0] ?? '';
	$studio    = $entities['empresa-estudio'][0] ?? '';
	$product   = $entities['marca-produto'][0] ?? '';
	$event     = $entities['evento'][0] ?? '';

	if ( $person && $character && $work ) {
		return sprintf( '%s interpreta %s em %s', $person, $character, $work );
	}
	if ( $person && $character ) {
		return sprintf( '%s interpreta %s', $person, $character );
	}
	if ( $person && $work ) {
		return sprintf( '%s em %s', $person, $work );
	}
	if ( $person && $event ) {
		return sprintf( '%s durante %s', $person, $event );
	}
	if ( $character && $work ) {
		return sprintf( '%s em %s', $character, $work );
	}
	if ( $work && $studio ) {
		return sprintf( '%s, produzido por %s', $work, $studio );
	}
	if ( $product && $studio ) {
		return sprintf( '%s, da %s', $product, $studio );
	}
	if ( $work ) {
		return sprintf( 'Cena de %s', $work );
	}
	if ( $product ) {
		return $product;
	}
	if ( $event ) {
		return $event;
	}
	return '';
}

/**
 * Juntar corpo e crédito no formato da casa: `Texto editorial (Foto: Crédito)`.
 *
 * Sem crédito, devolve só o corpo. Não existe caminho que produza um parêntese
 * vazio nem um crédito genérico de preenchimento.
 *
 * @param string $body   Texto editorial.
 * @param string $credit Crédito verificado, possivelmente vazio.
 * @return string
 */
function go_verge_image_format_caption( $body, $credit ) {
	$body   = trim( (string) $body );
	$credit = trim( (string) $credit );
	if ( '' === $credit ) {
		return $body;
	}
	/* Um crédito que já vem rotulado ("Foto: X") não recebe um segundo rótulo. */
	$labels = implode( '|', array_map( 'preg_quote', go_verge_image_credit_labels() ) );
	$formatted = preg_match( '/^(?:' . $labels . ')\s*:/ui', $credit ) ? $credit : 'Foto: ' . $credit;
	if ( '' === $body ) {
		return sprintf( '(%s)', $formatted );
	}
	return sprintf( '%s (%s)', rtrim( $body, ' .' ), $formatted );
}

/**
 * A sugestão completa para uma imagem, com proveniência de cada campo.
 *
 * @param int    $attachment_id Attachment ID.
 * @param int    $post_id       Post ID.
 * @param string $context       Texto próximo da imagem no editor, opcional.
 * @return array<string,mixed>
 */
function go_verge_image_text_suggestion( $attachment_id, $post_id = 0, $context = '' ) {
	$attachment_id = absint( $attachment_id );
	$post_id       = absint( $post_id );
	$entities      = go_verge_post_image_entities( $post_id );
	$alt           = go_verge_image_alt_suggestion( $attachment_id, $post_id, $entities );
	$caption       = go_verge_image_caption_suggestion( $attachment_id, $post_id, $entities );

	/* Legenda e alt idênticos são ruído: o leitor de tela anuncia o alt e logo
	 * depois a legenda visível diz a mesma coisa. Quando coincidem e há um
	 * ângulo editorial melhor, a legenda cede. */
	if ( '' !== $caption['body'] && 0 === strcasecmp( $caption['body'], $alt['text'] ) ) {
		$subtitle = $post_id ? go_verge_normalize_editorial_text( get_post_meta( $post_id, '_go_post_subtitle', true ) ) : '';
		if ( '' !== $subtitle && 0 !== strcasecmp( $subtitle, $alt['text'] ) ) {
			$caption['body']   = go_verge_image_trim_words( $subtitle, GO_VERGE_CAPTION_MAX_CHARS );
			$caption['text']   = go_verge_image_format_caption( $caption['body'], $caption['credit'] );
			$caption['source'] = 'subtitulo_da_materia';
		}
	}

	$has_entities = (bool) array_filter( array_map( 'count', $entities ) );

	return array(
		'attachment_id'  => $attachment_id,
		'post_id'        => $post_id,
		'alt'            => $alt['text'],
		'alt_source'     => $alt['source'],
		'caption'        => $caption['text'],
		'caption_body'   => $caption['body'],
		'caption_source' => $caption['source'],
		'credit'         => $caption['credit'],
		'credit_source'  => $caption['credit_source'],
		'credit_missing' => $caption['credit_missing'],
		'entities'       => $entities,
		/*
		 * Confiança do preenchimento automático, para a interface saber quando
		 * pedir revisão. "titulo_da_materia" é o degrau em que o texto deixa de
		 * descrever a imagem e passa a repetir a matéria — nunca é alta.
		 */
		'confidence'     => go_verge_image_text_confidence( $alt['source'], $has_entities ),
		'context'        => go_verge_normalize_editorial_text( $context ),
	);
}

/**
 * Quanto se pode confiar no alt automático, pela fonte de onde ele veio.
 *
 * @param string $alt_source   Fonte do alt.
 * @param bool   $has_entities A matéria declara entidades.
 * @return string HIGH|MEDIUM|LOW
 */
function go_verge_image_text_confidence( $alt_source, $has_entities = false ) {
	if ( in_array( $alt_source, array( 'alt_da_midia', 'legenda_da_midia' ), true ) ) {
		return 'HIGH';
	}
	if ( 'entidades_da_materia' === $alt_source ) {
		return $has_entities ? 'HIGH' : 'MEDIUM';
	}
	if ( in_array( $alt_source, array( 'titulo_da_midia', 'obra_ligada' ), true ) ) {
		return 'MEDIUM';
	}
	return 'LOW';
}

/* -------------------------------------------------------------------------
 * REST
 * ---------------------------------------------------------------------- */

/**
 * Registrar o endpoint consumido pelo preenchimento automático do editor.
 */
function go_verge_register_image_text_routes() {
	register_rest_route(
		'go-verge/v1',
		'/image-text-suggestion',
		array(
			'methods'             => WP_REST_Server::READABLE,
			'callback'            => 'go_verge_rest_image_text_suggestion',
			'permission_callback' => function_exists( 'go_verge_editor_workflow_permission' ) ? 'go_verge_editor_workflow_permission' : function () { return current_user_can( 'upload_files' ); },
			'args'                => array(
				'attachment_id' => array( 'required' => true, 'sanitize_callback' => 'absint' ),
				'post_id'       => array( 'sanitize_callback' => 'absint' ),
				'context'       => array( 'sanitize_callback' => 'sanitize_textarea_field' ),
			),
		)
	);
}
add_action( 'rest_api_init', 'go_verge_register_image_text_routes' );

/**
 * @param WP_REST_Request $request Request.
 * @return WP_REST_Response|WP_Error
 */
function go_verge_rest_image_text_suggestion( WP_REST_Request $request ) {
	$attachment_id = absint( $request->get_param( 'attachment_id' ) );
	$post_id       = absint( $request->get_param( 'post_id' ) );

	if ( ! $attachment_id || 'attachment' !== get_post_type( $attachment_id ) || ! wp_attachment_is_image( $attachment_id ) ) {
		return new WP_Error( 'go_invalid_image', __( 'Selecione uma imagem válida da biblioteca.', 'go-verge' ), array( 'status' => 400 ) );
	}
	if ( ! current_user_can( 'edit_post', $attachment_id ) && ! current_user_can( 'upload_files' ) ) {
		return new WP_Error( 'go_image_permission', __( 'Você não tem permissão para usar esta imagem.', 'go-verge' ), array( 'status' => 403 ) );
	}
	if ( $post_id && ! current_user_can( 'edit_post', $post_id ) ) {
		$post_id = 0;
	}

	return rest_ensure_response( go_verge_image_text_suggestion( $attachment_id, $post_id, (string) $request->get_param( 'context' ) ) );
}

/* -------------------------------------------------------------------------
 * Campo de crédito na mídia
 * ---------------------------------------------------------------------- */

/**
 * Campo "Crédito da foto" nos detalhes do anexo.
 *
 * Existe porque a regra é não inventar: quando o IPTC vem vazio, alguém precisa
 * ter onde escrever, e esse valor passa a alimentar toda legenda futura.
 *
 * @param array   $form_fields Campos.
 * @param WP_Post $post        Anexo.
 * @return array
 */
function go_verge_image_credit_field( $form_fields, $post ) {
	if ( ! wp_attachment_is_image( $post->ID ) ) {
		return $form_fields;
	}
	$credit = go_verge_image_credit( $post->ID );
	$labels = array(
		'campo_editorial'  => __( 'preenchido pela redação', 'go-verge' ),
		'legenda_da_midia' => __( 'preservado da legenda', 'go-verge' ),
		'iptc_credit'      => __( 'lido do IPTC do arquivo', 'go-verge' ),
		'exif_copyright'   => __( 'lido do copyright do arquivo', 'go-verge' ),
	);
	$helper = $credit['missing']
		? __( 'Sem crédito conhecido. A legenda automática sai sem crédito — nada é inventado aqui.', 'go-verge' )
		: sprintf( /* translators: %s: credit provenance. */ __( 'Origem: %s.', 'go-verge' ), $labels[ $credit['source'] ] ?? $credit['source'] );

	$form_fields[ GO_VERGE_IMAGE_CREDIT_META ] = array(
		'label' => __( 'Crédito da foto', 'go-verge' ),
		'input' => 'text',
		'value' => (string) get_post_meta( $post->ID, GO_VERGE_IMAGE_CREDIT_META, true ),
		'helps' => $helper . ' ' . __( 'Ex.: Divulgação/Netflix, Reprodução/Instagram, Agência Brasil.', 'go-verge' ),
	);

	return $form_fields;
}
add_filter( 'attachment_fields_to_edit', 'go_verge_image_credit_field', 25, 2 );

/**
 * Persistir o crédito.
 *
 * @param array $post       Dados do anexo.
 * @param array $attachment Campos enviados.
 * @return array
 */
function go_verge_image_credit_save( $post, $attachment ) {
	if ( ! isset( $attachment[ GO_VERGE_IMAGE_CREDIT_META ] ) || empty( $post['ID'] ) ) {
		return $post;
	}
	$value = sanitize_text_field( (string) $attachment[ GO_VERGE_IMAGE_CREDIT_META ] );
	if ( '' === $value ) {
		delete_post_meta( (int) $post['ID'], GO_VERGE_IMAGE_CREDIT_META );
	} else {
		update_post_meta( (int) $post['ID'], GO_VERGE_IMAGE_CREDIT_META, $value );
	}
	return $post;
}
add_filter( 'attachment_fields_to_save', 'go_verge_image_credit_save', 10, 2 );

/* -------------------------------------------------------------------------
 * Editor
 * ---------------------------------------------------------------------- */

/**
 * Carregar o preenchimento automático no editor de blocos.
 *
 * Desligar com:
 *   add_filter( 'go_verge_image_autotext_enabled', '__return_false' );
 */
function go_verge_image_autotext_editor_assets() {
	if ( ! apply_filters( 'go_verge_image_autotext_enabled', true ) || ! current_user_can( 'upload_files' ) ) {
		return;
	}
	/*
	 * O Lume é dono da UI do editor.
	 *
	 * Quando ele está ativo, o preenchimento vive lá — o Desk consulta
	 * `go_verge_image_text_suggestion()` por dentro (GED_REST::theme_media_suggestion)
	 * e apresenta a sugestão com confiança, base e aviso de crédito. Dois
	 * preenchedores no mesmo campo brigariam pelo alt e o autor não saberia
	 * qual venceu. O gerador continua servindo os dois; só a interface cede.
	 */
	if ( defined( 'GED_VERSION' ) ) {
		return;
	}
	$rel = '/assets/js/editor-image-autotext.js';
	wp_enqueue_script(
		'go-verge-image-autotext',
		GO_VERGE_URI . $rel,
		array( 'wp-data', 'wp-api-fetch', 'wp-blocks', 'wp-dom-ready' ),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $rel ) : GO_VERGE_VERSION,
		true
	);
	wp_localize_script(
		'go-verge-image-autotext',
		'GoVergeImageAutotext',
		array(
			'endpoint'    => '/go-verge/v1/image-text-suggestion',
			/* Preencher a legenda visível é uma decisão editorial, não de
			 * acessibilidade: alt vazio é um defeito, legenda vazia é um estilo.
			 * Por isso o alt entra sempre e a legenda é opcional. */
			'fillCaption' => (bool) apply_filters( 'go_verge_image_autotext_fill_caption', true ),
			'i18n'        => array(
				'creditMissing' => __( 'Legenda sem crédito: nenhum foi encontrado no arquivo nem na mídia.', 'go-verge' ),
			),
		)
	);
}
add_action( 'enqueue_block_editor_assets', 'go_verge_image_autotext_editor_assets' );
