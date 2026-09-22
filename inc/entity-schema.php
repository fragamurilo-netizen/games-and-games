<?php
/**
 * Schema graph for public /universo/ entity hubs.
 *
 * Rank Math can leave these CPT singles with only BreadcrumbList. This module
 * guarantees a WebPage node and a concrete main entity without duplicating
 * nodes already present in the graph.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Infer a conservative schema.org type from the editorial entity taxonomy. */
function go_verge_entity_schema_type( $post_id ) {
	$terms = get_the_terms( $post_id, 'go_entity_type' );
	$keys  = array();
	if ( $terms && ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			$keys[] = remove_accents( strtolower( $term->slug . ' ' . $term->name ) );
		}
	}
	$text = implode( ' ', $keys );

	if ( preg_match( '/\b(pessoa|personagem|autor|diretor|ator|atriz|criador)\b/', $text ) ) {
		return 'Person';
	}
	if ( preg_match( '/\b(desenvolvedor|desenvolvedora|publisher|publicadora|empresa|estudio|studio|fabricante|organizacao)\b/', $text ) ) {
		return 'Organization';
	}
	if ( preg_match( '/\b(franquia|serie|saga|universo)\b/', $text ) ) {
		return 'CreativeWorkSeries';
	}
	/* These URLs are durable editorial subject hubs, not pages for one scheduled
	 * occurrence. Event would require a truthful startDate and physical/virtual
	 * location, fields this CPT does not collect. Keep event topics as Thing. */
	if ( preg_match( '/\b(evento|festival|showcase|premiacao|premiacao)\b/', $text ) ) {
		return 'Thing';
	}
	/* Brand is safe only when the editorial taxonomy says it is a brand. A
	 * platform, console, service or ecosystem can be a Product, Service or a
	 * broader subject depending on the page, so do not manufacture that claim. */
	if ( preg_match( '/\b(marca|brand)\b/', $text ) ) {
		return 'Brand';
	}

	return 'Thing';
}

/** Build the main entity represented by one public hub. */
function go_verge_entity_schema_node( $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : get_queried_object_id();
	$post    = get_post( $post_id );
	if ( ! $post || 'go_entity' !== $post->post_type || 'publish' !== $post->post_status ) {
		return null;
	}

	$url  = get_permalink( $post_id );
	$node = array(
		'@type'            => go_verge_entity_schema_type( $post_id ),
		'@id'              => $url . '#entity',
		'name'             => wp_strip_all_tags( get_the_title( $post_id ) ),
		'url'              => $url,
		'mainEntityOfPage' => array( '@id' => $url . '#webpage' ),
	);

	$description = trim( wp_strip_all_tags( get_the_excerpt( $post_id ) ) );
	if ( '' === $description ) {
		$description = trim( wp_strip_all_tags( strip_shortcodes( (string) $post->post_content ) ) );
	}
	if ( '' !== $description ) {
		$node['description'] = wp_trim_words( $description, 42, '…' );
	}

	if ( has_post_thumbnail( $post_id ) ) {
		$image = wp_get_attachment_image_src( get_post_thumbnail_id( $post_id ), 'go_hero' );
		if ( is_array( $image ) && ! empty( $image[0] ) ) {
			$node['image'] = array(
				'@type'  => 'ImageObject',
				'@id'    => $url . '#primaryimage',
				'url'    => $image[0],
				'width'  => (int) $image[1],
				'height' => (int) $image[2],
			);
		}
	}

	$terms = get_the_terms( $post_id, 'go_entity_type' );
	if ( $terms && ! is_wp_error( $terms ) ) {
		$node['category'] = array_values(
			array_filter(
				array_map(
					static function ( $term ) {
						return $term instanceof WP_Term ? $term->name : '';
					},
					$terms
				)
			)
		);
	}

	return $node;
}

/** Build the WebPage node for one entity hub. */
function go_verge_entity_webpage_schema_node( $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : get_queried_object_id();
	$url     = get_permalink( $post_id );
	$entity  = go_verge_entity_schema_node( $post_id );
	if ( ! $url || ! $entity ) {
		return null;
	}

	$node = array(
		'@type'         => 'WebPage',
		'@id'           => $url . '#webpage',
		'url'           => $url,
		'name'          => wp_strip_all_tags( get_the_title( $post_id ) ),
		'isPartOf'      => array( '@id' => home_url( '/#website' ) ),
		'mainEntity'    => array( '@id' => $entity['@id'] ),
		'about'         => array( '@id' => $entity['@id'] ),
		'inLanguage'    => get_bloginfo( 'language' ),
		'datePublished' => get_post_time( 'c', true, $post_id ),
		'dateModified'  => get_post_modified_time( 'c', true, $post_id ),
	);
	if ( ! empty( $entity['description'] ) ) {
		$node['description'] = $entity['description'];
	}
	if ( has_post_thumbnail( $post_id ) ) {
		$node['primaryImageOfPage'] = array( '@id' => $url . '#primaryimage' );
	}
	return $node;
}


/** Build a CollectionPage that matches the platforms index actually rendered. */
function go_verge_entity_archive_schema_nodes() {
	if ( ! is_post_type_archive( 'go_entity' ) ) {
		return array();
	}

	$url = get_post_type_archive_link( 'go_entity' );
	$page = array(
		'@type'      => 'CollectionPage',
		'@id'        => $url . '#webpage',
		'url'        => $url,
		'name'       => __( 'Plataformas', 'go-verge' ),
		'description'=> __( 'Xbox, Nintendo, PC, PlayStation e Mobile: notícias, jogos, serviços e guias por plataforma.', 'go-verge' ),
		'isPartOf'   => array( '@id' => home_url( '/#website' ) ),
		'inLanguage' => get_bloginfo( 'language' ),
	);

	return array( 'page' => $page );
}

/** The archive template is a single platforms landing page, never a paged list. */
function go_verge_entity_archive_redirect_false_pagination() {
	if ( ! is_post_type_archive( 'go_entity' ) ) { return; }
	$paged = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	if ( $paged > 1 ) {
		wp_safe_redirect( get_post_type_archive_link( 'go_entity' ), 301, 'Overdrive Entity Archive' );
		exit;
	}
}
add_action( 'template_redirect', 'go_verge_entity_archive_redirect_false_pagination', -70 );

/** Keep the document metadata aligned with the visible Platforms landing page. */
function go_verge_entity_archive_document_title( $parts ) {
	if ( is_post_type_archive( 'go_entity' ) && is_array( $parts ) ) { $parts['title'] = __( 'Plataformas', 'go-verge' ); }
	return $parts;
}
add_filter( 'document_title_parts', 'go_verge_entity_archive_document_title', 200 );
function go_verge_entity_archive_rank_math_title( $title ) {
	if ( ! is_post_type_archive( 'go_entity' ) ) { return $title; }
	$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Game Overdrive';
	return sprintf( __( 'Plataformas | %s', 'go-verge' ), $site_name );
}
add_filter( 'rank_math/frontend/title', 'go_verge_entity_archive_rank_math_title', 200 );
function go_verge_entity_archive_rank_math_description( $description ) {
	return is_post_type_archive( 'go_entity' ) ? __( 'Xbox, Nintendo, PC, PlayStation e Mobile: notícias, jogos, serviços e guias por plataforma.', 'go-verge' ) : $description;
}
add_filter( 'rank_math/frontend/description', 'go_verge_entity_archive_rank_math_description', 200 );

/**
 * Complete Rank Math's graph for /universo/* singles.
 */
function go_verge_rank_math_entity_hub_schema( $data, $jsonld = null ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}

	if ( is_post_type_archive( 'go_entity' ) ) {
		$nodes = go_verge_entity_archive_schema_nodes();
		if ( empty( $nodes['page'] ) ) {
			return $data;
		}
		$page_key = null;
		foreach ( $data as $key => $node ) {
			if ( ! is_array( $node ) ) {
				continue;
			}
			$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
			$same_page = ( isset( $node['@id'] ) && $nodes['page']['@id'] === (string) $node['@id'] )
				|| ( isset( $node['url'] ) && untrailingslashit( $nodes['page']['url'] ) === untrailingslashit( (string) $node['url'] ) );
			if ( $same_page && array_intersect( array( 'WebPage', 'CollectionPage' ), $types ) ) {
				$page_key = $key;
				break;
			}
		}
		if ( null === $page_key ) {
			go_verge_schema_graph_add_unique( $data, 'goEntityArchivePage', $nodes['page'] );
		} else {
			$data[ $page_key ] = array_replace( $data[ $page_key ], $nodes['page'] );
			unset( $data[ $page_key ]['mainEntity'] );
		}
		return $data;
	}

	if ( ! is_singular( 'go_entity' ) ) {
		return $data;
	}

	$post_id  = get_queried_object_id();
	$entity   = go_verge_entity_schema_node( $post_id );
	$webpage  = go_verge_entity_webpage_schema_node( $post_id );
	if ( ! $entity || ! $webpage ) {
		return $data;
	}

	$entity_key  = null;
	$webpage_key = null;
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) {
			continue;
		}
		if ( ! empty( $node['@id'] ) && $entity['@id'] === $node['@id'] ) {
			$entity_key = $key;
		}
		$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
		$same_page = ( isset( $node['@id'] ) && $webpage['@id'] === (string) $node['@id'] )
			|| ( isset( $node['url'] ) && untrailingslashit( $webpage['url'] ) === untrailingslashit( (string) $node['url'] ) );
		if ( $same_page && array_intersect( array( 'WebPage', 'ItemPage', 'ProfilePage', 'CollectionPage' ), $types ) ) {
			$webpage_key = $key;
		}
	}

	if ( null === $entity_key ) {
		go_verge_schema_graph_add_unique( $data, 'goEntity', $entity );
	} else {
		$data[ $entity_key ] = array_replace( $entity, $data[ $entity_key ] );
	}

	if ( null === $webpage_key ) {
		go_verge_schema_graph_add_unique( $data, 'goEntityWebPage', $webpage );
	} else {
		$data[ $webpage_key ] = array_replace( $webpage, $data[ $webpage_key ] );
		$data[ $webpage_key ]['mainEntity'] = array( '@id' => $entity['@id'] );
		$data[ $webpage_key ]['about']      = array( '@id' => $entity['@id'] );
	}

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_entity_hub_schema', 96, 2 );
