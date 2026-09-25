<?php
/**
 * Search visibility and topical clarity layer.
 *
 * Adds conservative entity/topic signals to article schema, tracks meaningful
 * content modification dates, enriches search-engine metadata without
 * duplicating Rank Math output and keeps thin taxonomy noise out of the way.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Normalize text for conservative topic evidence checks. */
function go_verge_search_normalize_text( $text ) {
	$text = wp_strip_all_tags( strip_shortcodes( (string) $text ) );
	$text = html_entity_decode( $text, ENT_QUOTES, get_bloginfo( 'charset' ) );
	$text = remove_accents( $text );
	$text = function_exists( 'mb_strtolower' ) ? mb_strtolower( $text, 'UTF-8' ) : strtolower( $text );
	$text = preg_replace( '/[^\p{L}\p{N}]+/u', ' ', $text );
	return trim( preg_replace( '/\s+/u', ' ', (string) $text ) );
}

/** Broad editorial labels are sections, not useful topical entities. */
function go_verge_search_broad_topic_keys() {
	return array(
		'games', 'jogos', 'noticias', 'noticia', 'reviews', 'review', 'criticas', 'critica',
		'entretenimento', 'tecnologia', 'ciencia e tecnologia', 'dicas', 'guias', 'dicas e guias',
		'especial', 'especiais', 'listas', 'ranking', 'rankings', 'promocoes', 'promocao',
	);
}

/** Whether a label is too broad to be asserted as the subject of one article. */
function go_verge_search_is_broad_topic( $label ) {
	$key = go_verge_search_normalize_text( $label );
	return '' === $key || in_array( $key, go_verge_search_broad_topic_keys(), true );
}

/** Gather article text used only to verify whether a topic is actually present. */
function go_verge_search_article_evidence_text( $post_id ) {
	$title   = get_the_title( $post_id );
	$deck    = function_exists( 'go_verge_subtitle' ) ? go_verge_subtitle( $post_id ) : get_post_meta( $post_id, '_go_post_subtitle', true );
	$content = (string) get_post_field( 'post_content', $post_id );
	return go_verge_search_normalize_text( $title . ' ' . $deck . ' ' . $content );
}

/** Exact phrase evidence, with a modest token fallback for longer names. */
function go_verge_search_topic_has_evidence( $label, $evidence ) {
	$needle = go_verge_search_normalize_text( $label );
	if ( '' === $needle || '' === $evidence ) {
		return false;
	}
	if ( false !== strpos( ' ' . $evidence . ' ', ' ' . $needle . ' ' ) ) {
		return true;
	}

	$tokens = array_values( array_filter( preg_split( '/\s+/u', $needle ), static function ( $token ) {
		return function_exists( 'mb_strlen' ) ? mb_strlen( $token, 'UTF-8' ) >= 5 : strlen( $token ) >= 5;
	} ) );
	if ( count( $tokens ) < 2 ) {
		return false;
	}
	$matched = 0;
	foreach ( $tokens as $token ) {
		if ( false !== strpos( ' ' . $evidence . ' ', ' ' . $token . ' ' ) ) {
			++$matched;
		}
	}
	return $matched >= min( 2, count( $tokens ) );
}

/**
 * Validated topic/entity graph for one article.
 *
 * @return array<int,array{@type:string,name:string,url?:string}>
 */
function go_verge_search_topic_entities( $post_id ) {
	$post_id  = absint( $post_id );
	$evidence = go_verge_search_article_evidence_text( $post_id );
	$items    = array();
	$seen     = array();

	$add = static function ( &$items, &$seen, $name, $url = '', $type = 'Thing', $trusted = false ) use ( $evidence ) {
		$name = trim( wp_strip_all_tags( (string) $name ) );
		if ( '' === $name || go_verge_search_is_broad_topic( $name ) ) {
			return;
		}
		$key = go_verge_search_normalize_text( $name );
		if ( '' === $key || isset( $seen[ $key ] ) ) {
			return;
		}
		if ( ! $trusted && ! go_verge_search_topic_has_evidence( $name, $evidence ) ) {
			return;
		}
		$node = array( '@type' => $type, 'name' => $name );
		if ( $url ) {
			$node['url'] = esc_url_raw( $url );
		}
		$seen[ $key ] = true;
		$items[]      = $node;
	};

	// Explicit editorial links are trusted signals.
	if ( function_exists( 'go_verge_product_linked_game_id' ) ) {
		$game_id = absint( go_verge_product_linked_game_id( $post_id ) );
		if ( $game_id && 'publish' === get_post_status( $game_id ) ) {
			$add( $items, $seen, get_the_title( $game_id ), get_permalink( $game_id ), 'VideoGame', true );
		}
	}

	if ( function_exists( 'go_verge_product_subject_reference' ) ) {
		$reference = (string) go_verge_product_subject_reference( $post_id );
		if ( preg_match( '/^go_entity:(\d+)$/', $reference, $match ) ) {
			$entity_id = absint( $match[1] );
			if ( $entity_id && 'publish' === get_post_status( $entity_id ) ) {
				$add( $items, $seen, get_the_title( $entity_id ), get_permalink( $entity_id ), 'Thing', true );
			}
		}
	}

	// Primary taxonomy only when the article itself proves the topic.
	if ( function_exists( 'go_verge_get_primary_term' ) ) {
		$primary = go_verge_get_primary_term( $post_id );
		if ( $primary instanceof WP_Term ) {
			$link = get_term_link( $primary );
			$add( $items, $seen, $primary->name, is_wp_error( $link ) ? '' : $link, 'Thing', false );
		}
	}

	$tags = get_the_tags( $post_id );
	if ( $tags && ! is_wp_error( $tags ) ) {
		foreach ( $tags as $tag ) {
			if ( count( $items ) >= 6 || (int) $tag->count < 2 ) {
				break;
			}
			$destination = function_exists( 'go_verge_tag_preferred_destination' ) ? go_verge_tag_preferred_destination( $tag ) : null;
			$link        = $destination && ! empty( $destination['url'] ) ? $destination['url'] : get_tag_link( $tag );
			$add( $items, $seen, $tag->name, is_wp_error( $link ) ? '' : $link, 'Thing', false );
		}
	}

	return array_slice( $items, 0, 6 );
}

/** Word count based on editorial body only. */
function go_verge_search_word_count( $post_id ) {
	$text = wp_strip_all_tags( strip_shortcodes( (string) get_post_field( 'post_content', $post_id ) ) );
	$text = trim( preg_replace( '/\s+/u', ' ', $text ) );
	if ( '' === $text ) {
		return 0;
	}
	$parts = preg_split( '/\s+/u', $text, -1, PREG_SPLIT_NO_EMPTY );
	return is_array( $parts ) ? count( $parts ) : 0;
}

/** Track only meaningful editorial updates, not every metadata/admin save. */
function go_verge_search_track_content_modified( $post_id, $post_after, $post_before ) {
	if ( ! ( $post_after instanceof WP_Post ) || ! ( $post_before instanceof WP_Post ) || 'post' !== $post_after->post_type ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	$changed = $post_after->post_title !== $post_before->post_title ||
		$post_after->post_content !== $post_before->post_content ||
		$post_after->post_excerpt !== $post_before->post_excerpt;
	if ( $changed ) {
		update_post_meta( $post_id, '_go_search_content_modified_gmt', gmdate( 'Y-m-d H:i:s' ) );
	}
}
add_action( 'post_updated', 'go_verge_search_track_content_modified', 10, 3 );

/**
 * Treat a changed visible support line as a meaningful editorial update too.
 *
 * Gutenberg saves registered post meta after the core post fields, so a deck
 * edit can happen without `post_updated` seeing a title/content/excerpt diff.
 * Only the public-facing support line is tracked here: SEO-only/admin metadata
 * must not manufacture a freshness signal. The first minute after publication
 * is ignored, matching the visible dateline threshold and preventing a normal
 * first-publish request from immediately becoming "Atualizado".
 *
 * @param int    $meta_id    Meta row ID.
 * @param int    $post_id    Post ID.
 * @param string $meta_key   Meta key.
 * @param mixed  $meta_value New value.
 */
function go_verge_search_track_editorial_meta_modified( $meta_id, $post_id, $meta_key, $meta_value ) {
	unset( $meta_id, $meta_value );
	$post_id = absint( $post_id );
	if ( '_go_post_subtitle' !== (string) $meta_key || ! $post_id || 'post' !== get_post_type( $post_id ) || 'publish' !== get_post_status( $post_id ) ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}

	$published = function_exists( 'go_verge_search_published_timestamp' )
		? (int) go_verge_search_published_timestamp( $post_id )
		: (int) get_post_time( 'U', true, $post_id );
	$threshold = max( 0, (int) apply_filters( 'go_verge_update_time_threshold', 60, $post_id ) );
	if ( $published && time() <= ( $published + $threshold ) ) {
		return;
	}

	update_post_meta( $post_id, '_go_search_content_modified_gmt', current_time( 'mysql', true ) );
}
add_action( 'added_post_meta', 'go_verge_search_track_editorial_meta_modified', 20, 4 );
add_action( 'updated_post_meta', 'go_verge_search_track_editorial_meta_modified', 20, 4 );
add_action( 'deleted_post_meta', 'go_verge_search_track_editorial_meta_modified', 20, 4 );

/** Accurate content modification date for schema. */
function go_verge_search_modified_iso( $post_id ) {
	$stored = get_post_meta( $post_id, '_go_search_content_modified_gmt', true );
	if ( $stored ) {
		$timestamp = strtotime( $stored . ' UTC' );
		if ( $timestamp ) {
			return gmdate( 'c', $timestamp );
		}
	}
	return get_post_modified_time( 'c', true, $post_id );
}

/** Infer an editorial genre without inventing facts. */
function go_verge_search_article_genre( $post_id ) {
	/* Tipo de matéria is the most precise editorial description available. */
	if ( function_exists( 'go_verge_v7_post_content_type' ) ) {
		$type = go_verge_v7_post_content_type( $post_id );
		$genres = array(
			'noticia'         => 'Notícia',
			'guia'            => 'Guia',
			'review'          => 'Review',
			'critica'         => 'Crítica',
			'lista'           => 'Lista',
			'especial'        => 'Especial',
			'onde-assistir'   => 'Onde assistir',
			'final-explicado' => 'Final explicado',
			'impressoes'      => 'Impressões',
			'oferta'          => 'Oferta',
			'guia-de-compra'  => 'Guia de compra',
			'ranking'         => 'Ranking',
		);
		if ( isset( $genres[ $type ] ) ) {
			return $genres[ $type ];
		}
	}

	/* Legacy fallbacks for posts not yet normalized into V7. */
	if ( function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id ) ) {
		return 'Crítica';
	}
	if ( function_exists( 'go_verge_review_data' ) ) {
		$data = go_verge_review_data( $post_id );
		if ( ! empty( $data['has_review'] ) && empty( $data['is_critique'] ) ) {
			return 'Review';
		}
	}
	if ( function_exists( 'go_verge_is_guide_post' ) && go_verge_is_guide_post( $post_id ) ) {
		return 'Guia';
	}
	if ( function_exists( 'go_verge_post_is_special' ) && go_verge_post_is_special( $post_id ) ) {
		return 'Especial';
	}
	if ( function_exists( 'go_verge_post_is_ranking' ) && go_verge_post_is_ranking( $post_id ) ) {
		return 'Ranking';
	}
	if ( function_exists( 'go_verge_post_is_list' ) && go_verge_post_is_list( $post_id ) ) {
		return 'Lista';
	}
	return function_exists( 'go_verge_post_is_news_article' ) && go_verge_post_is_news_article( $post_id ) ? 'Notícia' : 'Artigo';
}

/**
 * Return crawlable article image variants for Search/Discover schema.
 *
 * Google recommends multiple high-resolution Article images in 16:9, 4:3 and
 * 1:1. New uploads get dedicated crops; older media falls back to the existing
 * hero/feed/square sizes so current articles improve without breaking URLs.
 *
 * @return array<int,array{@type:string,url:string,width:int,height:int}>
 */
function go_verge_search_article_image_variants( $post_id ) {
	$image_id = get_post_thumbnail_id( $post_id );
	if ( ! $image_id ) {
		return array();
	}

	/*
	 * Each group has a real target ratio. WordPress may return the original file
	 * when a requested crop does not exist, so checking only the requested size
	 * name can accidentally label one landscape original as 16:9, 4:3 and 1:1.
	 * Validate both the intermediate flag and the resulting aspect ratio.
	 */
	$groups = array(
		array( 'ratio' => 16 / 9, 'sizes' => array( 'go_discover_16x9', 'go_hero', 'go_card', 'full' ) ),
		array( 'ratio' => 4 / 3,  'sizes' => array( 'go_discover_4x3', 'go_feed', 'full' ) ),
		array( 'ratio' => 1,      'sizes' => array( 'go_discover_1x1', 'go_square', 'gamxo-size5', 'full' ) ),
	);
	$out       = array();
	$seen      = array();
	$caption   = wp_get_attachment_caption( $image_id );
	$tolerance = 0.045;

	foreach ( $groups as $group ) {
		$selected = null;

		foreach ( $group['sizes'] as $size ) {
			$img = wp_get_attachment_image_src( $image_id, $size );
			if ( ! is_array( $img ) || empty( $img[0] ) || empty( $img[1] ) || empty( $img[2] ) ) {
				continue;
			}
			if ( function_exists( 'go_verge_og_image_format_supported' ) && ! go_verge_og_image_format_supported( $img[0] ) ) {
				continue;
			}

			/* For named crops, false means WordPress silently fell back to full. */
			if ( 'full' !== $size && isset( $img[3] ) && ! $img[3] ) {
				continue;
			}

			$width  = (int) $img[1];
			$height = (int) $img[2];
			$area   = $width * $height;
			if ( $area < 50000 || $height < 1 ) {
				continue;
			}

			$actual_ratio = $width / $height;
			$ratio_error  = abs( $actual_ratio - (float) $group['ratio'] ) / (float) $group['ratio'];
			if ( $ratio_error > $tolerance ) {
				continue;
			}

			if ( $width >= 1200 && $area >= 300000 ) {
				$selected = $img;
				break;
			}
		}

		if ( ! $selected || isset( $seen[ $selected[0] ] ) ) {
			continue;
		}

		$seen[ $selected[0] ] = true;
		$image_node = array(
			'@type'      => 'ImageObject',
			'url'        => esc_url_raw( $selected[0] ),
			'contentUrl' => esc_url_raw( $selected[0] ),
			'width'      => (int) $selected[1],
			'height'     => (int) $selected[2],
		);
		if ( is_string( $caption ) && '' !== trim( $caption ) ) {
			$image_node['caption'] = trim( wp_strip_all_tags( $caption ) );
		}
		$out[] = $image_node;
	}

	return $out;
}

/** Enrich one Article/NewsArticle node with conservative search signals. */
function go_verge_search_enrich_article_node( $node, $post_id ) {
	if ( ! is_array( $node ) || ! $post_id ) {
		return $node;
	}

	$word_count = go_verge_search_word_count( $post_id );
	if ( $word_count ) {
		$node['wordCount'] = $word_count;
	}
	/*
	 * The publication is fully open. Do not emit isAccessibleForFree here:
	 * Rank Math serializes boolean true as the integer 1 in its JSON-LD graph on
	 * this install, which Google rejects for the Boolean property and classifies
	 * the NewsArticle as invalid paywalled content. Absence is valid for free
	 * articles and avoids a false paywall signal. Unset defensively in case an
	 * upstream schema node already provided the field.
	 */
	unset( $node['isAccessibleForFree'] );
	$node['dateModified'] = function_exists( 'go_verge_search_consistent_modified_iso' )
		? go_verge_search_consistent_modified_iso( $post_id )
		: go_verge_search_modified_iso( $post_id );
	$node['genre']               = go_verge_search_article_genre( $post_id );
	$node['copyrightYear']       = (int) get_post_time( 'Y', true, $post_id );
	$node['copyrightHolder']     = array( '@id' => home_url( '/#organization' ) );

	if ( has_post_thumbnail( $post_id ) ) {
		/*
		 * thumbnailUrl must be a thumbnail. wp_get_attachment_image_url() returns
		 * the full-size file when the requested crop was never generated, so this
		 * property used to advertise 2.5k-wide originals — measured at 2.1 MB on
		 * live reviews — as the article's thumbnail. Resolve a crop that exists.
		 */
		$thumb_id = get_post_thumbnail_id( $post_id );
		$thumb    = go_verge_intermediate_image_url( $thumb_id, 'go_discover_16x9' );
		if ( ! $thumb ) {
			$thumb = go_verge_intermediate_image_url( $thumb_id, 'go_hero' );
		}
		if ( $thumb && ( ! function_exists( 'go_verge_og_image_format_supported' ) || go_verge_og_image_format_supported( $thumb ) ) ) {
			$node['thumbnailUrl'] = $thumb;
		} else {
			unset( $node['thumbnailUrl'] );
		}

		$variants = go_verge_search_article_image_variants( $post_id );
		if ( $variants ) {
			$images = array();
			if ( ! empty( $node['image'] ) ) {
				// Preserve Rank Math/custom schema's canonical ImageObject reference.
				$images[] = $node['image'];
			}
			foreach ( $variants as $variant ) {
				$images[] = $variant;
			}
			$node['image'] = count( $images ) === 1 ? $images[0] : $images;
		}
	}

	if ( function_exists( 'go_verge_semantic_resolved' ) ) {
		$semantic = go_verge_semantic_resolved( $post_id );
		if ( ! empty( $semantic['about'] ) ) {
			$node['about'] = 1 === count( $semantic['about'] ) ? $semantic['about'][0] : array_slice( $semantic['about'], 0, 6 );
		}
		if ( ! empty( $semantic['mentions'] ) ) {
			$node['mentions'] = array_slice( $semantic['mentions'], 0, 10 );
		}
		$existing        = isset( $node['keywords'] ) ? (array) $node['keywords'] : array();
		$node['keywords'] = array_values( array_unique( array_filter( array_merge( (array) $semantic['keywords'], $existing ) ) ) );
		$node['keywords'] = array_slice( $node['keywords'], 0, 20 );
	} else {
		$entities = go_verge_search_topic_entities( $post_id );
		if ( ! empty( $entities ) ) {
			$node['about'] = count( $entities ) > 1 ? array_slice( $entities, 0, 2 ) : $entities[0];
			if ( count( $entities ) > 2 ) {
				$node['mentions'] = array_slice( $entities, 2 );
			}
			$validated_keywords = wp_list_pluck( $entities, 'name' );
			$existing           = isset( $node['keywords'] ) ? (array) $node['keywords'] : array();
			$node['keywords']    = array_values( array_unique( array_filter( array_merge( $validated_keywords, $existing ) ) ) );
			$node['keywords']    = array_slice( $node['keywords'], 0, 12 );
		}
	}

	$comment_count = (int) get_comments_number( $post_id );
	if ( $comment_count > 0 ) {
		$node['commentCount'] = $comment_count;
		$node['interactionStatistic'] = array(
			'@type'                => 'InteractionCounter',
			'interactionType'       => 'https://schema.org/CommentAction',
			'userInteractionCount' => $comment_count,
		);
	}

	return $node;
}

/** Enrich Rank Math's existing graph without creating a competing Article. */
function go_verge_search_rank_math_graph( $data ) {
	if ( ! is_singular( 'post' ) || ! is_array( $data ) ) {
		return $data;
	}
	$post_id = get_queried_object_id();
	$current_url = get_permalink( $post_id );
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || empty( $node['@type'] ) ) {
			continue;
		}
		if ( go_verge_schema_node_matches_url( $node, $current_url, array( 'Article', 'NewsArticle', 'BlogPosting' ) ) ) {
			$data[ $key ] = go_verge_search_enrich_article_node( $node, $post_id );
			continue;
		}

		/*
		 * One update time for the whole page.
		 *
		 * The article node reports the last real editorial change (see
		 * go_verge_search_modified_iso), while Rank Math's WebPage node reports
		 * post_modified — every metadata save, cache warm or bulk edit included.
		 * The two disagreed by seconds and in different offsets on the same URL,
		 * so a consumer reading the graph could take either as "when this was
		 * updated". Align the container with the article it contains.
		 */
		if ( isset( $node['dateModified'] ) && go_verge_schema_node_matches_url( $node, $current_url, array( 'WebPage' ) ) ) {
			$data[ $key ]['dateModified'] = function_exists( 'go_verge_search_consistent_modified_iso' )
				? go_verge_search_consistent_modified_iso( $post_id )
				: go_verge_search_modified_iso( $post_id );
		}
	}
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_search_rank_math_graph', 88, 1 );

/**
 * Declare what an indexable archive actually lists.
 *
 * The hubs already emit CollectionPage, which says "this page is a collection"
 * without ever saying of what. An ItemList naming the stories in document order
 * is a plain description of content that is visibly on the page — no invented
 * facts — and it is what lets a crawler or an answer engine read a hub as an
 * ordered set of articles instead of an undifferentiated blob of links.
 *
 * This is a comprehension aid, not a rich-result feature: Google publishes no
 * listing rich result for news hubs. Archives that are noindex are skipped,
 * because describing a page nobody should index has no consumer.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_search_archive_item_list( $data ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}
	if ( ! ( is_category() || is_tax() || is_post_type_archive() ) || is_paged() ) {
		return $data;
	}

	/*
	 * The entity archive already publishes a purpose-built ItemList through
	 * go_verge_rank_math_entity_hub_schema(), which runs after this filter and
	 * claims the page's mainEntity. Adding a second list here would leave one of
	 * them referenced by nothing.
	 */
	if ( is_post_type_archive( 'go_entity' ) ) {
		return $data;
	}

	global $wp_query;
	if ( ! ( $wp_query instanceof WP_Query ) || empty( $wp_query->posts ) ) {
		return $data;
	}

	$elements = array();
	$position = 0;
	foreach ( $wp_query->posts as $post ) {
		if ( ! ( $post instanceof WP_Post ) ) {
			continue;
		}
		$permalink = get_permalink( $post );
		if ( ! $permalink ) {
			continue;
		}
		++$position;
		$elements[] = array(
			'@type'    => 'ListItem',
			'position' => $position,
			'url'      => $permalink,
			'name'     => wp_strip_all_tags( get_the_title( $post ) ),
		);
		if ( $position >= 20 ) {
			break;
		}
	}

	if ( ! $elements ) {
		return $data;
	}

	$current_url = go_verge_search_current_archive_url();
	$list_id = trailingslashit( $current_url ) . '#itemlist';
	$list    = array(
		'@type'           => 'ItemList',
		'@id'             => $list_id,
		'itemListOrder'   => 'https://schema.org/ItemListOrderDescending',
		'numberOfItems'   => count( $elements ),
		'itemListElement' => $elements,
	);

	$attached = false;
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || empty( $node['@type'] ) ) {
			continue;
		}
		if ( go_verge_schema_node_matches_url( $node, $current_url, array( 'CollectionPage', 'WebPage' ) ) ) {
			$data[ $key ]['mainEntity'] = array( '@id' => $list_id );
			$attached                   = true;
			break;
		}
	}

	if ( ! $attached ) {
		return $data;
	}

	$list_key = go_verge_schema_graph_find_id( $data, $list_id );
	if ( null === $list_key ) {
		go_verge_schema_graph_add_unique( $data, 'goArchiveItemList', $list );
	} else {
		$data[ $list_key ] = array_replace( $data[ $list_key ], $list );
	}

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_search_archive_item_list', 92, 1 );

/** Canonical URL of the archive currently being rendered. */
function go_verge_search_current_archive_url() {
	$object = get_queried_object();

	if ( $object instanceof WP_Term ) {
		$link = get_term_link( $object );
		if ( ! is_wp_error( $link ) ) {
			return $link;
		}
	}

	if ( $object instanceof WP_Post_Type ) {
		$link = get_post_type_archive_link( $object->name );
		if ( $link ) {
			return $link;
		}
	}

	return home_url( '/' );
}

/** Never leave a singular page with an empty SEO title when Rank Math is active. */
function go_verge_search_rank_math_title_fallback( $title ) {
	if ( is_singular( 'post' ) && '' === trim( wp_strip_all_tags( (string) $title ) ) ) {
		return wp_strip_all_tags( get_the_title( get_queried_object_id() ) );
	}
	return $title;
}
add_filter( 'rank_math/frontend/title', 'go_verge_search_rank_math_title_fallback', 20 );

/** Thin one-post tag archives dilute crawl without adding a useful landing page. */
function go_verge_search_thin_tag_robots( $robots ) {
	if ( is_tag() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term && ( (int) $term->count < 2 || ( function_exists( 'go_verge_is_tag_alias' ) && go_verge_is_tag_alias( $term ) ) ) ) {
			$robots['noindex'] = true;
			$robots['follow']  = true;
			unset( $robots['index'] );
		}
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_search_thin_tag_robots', 85 );

/**
 * Preserve large previews with Rank Math too, without overriding an explicit
 * editorial noindex. Also keep one-post tag archives out of the index.
 */
function go_verge_search_rank_math_robots( $robots ) {
	if ( ! is_array( $robots ) ) {
		return $robots;
	}

	/* Rank Math removes core wp_robots callbacks while it owns the head. Mirror
	 * the theme's thin-content policy here so individual promotion records and
	 * attachment pages cannot become indexable while being omitted from every
	 * sitemap. Their useful destinations are the promotion archive and parent
	 * content/media URL, respectively. */
	if ( is_singular( 'go_promotion' ) || is_attachment() ) {
		$robots['index']  = 'noindex';
		$robots['follow'] = 'follow';
		return $robots;
	}

	$flat = array_map( 'strtolower', array_map( 'strval', array_merge( array_keys( $robots ), array_values( $robots ) ) ) );
	$has_noindex = false;
	foreach ( $flat as $value ) {
		if ( false !== strpos( $value, 'noindex' ) ) {
			$has_noindex = true;
			break;
		}
	}

	if ( is_tag() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term && ( (int) $term->count < 2 || ( function_exists( 'go_verge_is_tag_alias' ) && go_verge_is_tag_alias( $term ) ) ) ) {
			$robots['index']  = 'noindex';
			$robots['follow'] = 'follow';
			return $robots;
		}
	}

	if ( ! $has_noindex && ! is_search() && ! is_404() && ! go_verge_search_is_utility_surface() ) {
		$robots['max-image-preview'] = 'max-image-preview:large';
		$robots['max-snippet']       = 'max-snippet:-1';
		$robots['max-video-preview'] = 'max-video-preview:-1';
	}
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_search_rank_math_robots', 30 );

/**
 * Do not expose a standalone /tag/.../ page until the term has at least two
 * published posts. Editors may still assign one-post tags in wp-admin; they
 * simply remain private taxonomy signals until the archive becomes useful.
 */
function go_verge_search_hide_thin_tag_archives() {
	if ( is_admin() || wp_doing_ajax() || ! is_tag() ) {
		return;
	}
	$term = get_queried_object();
	if ( ! ( $term instanceof WP_Term ) || 'post_tag' !== $term->taxonomy || (int) $term->count >= 2 ) {
		return;
	}

	global $wp_query;
	if ( $wp_query instanceof WP_Query ) {
		$wp_query->set_404();
	}
	status_header( 404 );
	nocache_headers();
	$template = get_404_template();
	if ( $template ) {
		include $template;
	}
	exit;
}
// Thin tag archives stay reachable for users/crawlers and are controlled by
// noindex,follow above. Returning a 404 here would turn real internal links into
// dead ends and weaken discovery of the article linked from that archive.
// add_action( 'template_redirect', 'go_verge_search_hide_thin_tag_archives', 30 );
