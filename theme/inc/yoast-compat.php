<?php
/**
 * Yoast SEO compatibility for the Overdrive newsroom architecture.
 *
 * Yoast remains the owner of document title/meta/canonical/schema whenever it
 * is active. This bridge only carries theme-specific editorial semantics into
 * Yoast and keeps the theme-owned /sitemap.xml as the sole general sitemap
 * contract advertised to crawlers.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Yoast 2026 can advertise its Schema Aggregator as an additional Sitemap line
 * in robots.txt. Overdrive intentionally owns the sitemap discovery contract,
 * so keep the aggregator available to Yoast without advertising it as a sitemap.
 */
function go_verge_yoast_disable_robots_schemamap( $disabled ) {
	return true;
}
add_filter( 'wpseo_disable_robots_schemamap', 'go_verge_yoast_disable_robots_schemamap', 100 );

/**
 * Keep Yoast as the metadata/schema layer, but disable its XML sitemap engine.
 *
 * The publisher explicitly uses the theme-owned /sitemap.xml contract. This
 * one-time migration prevents Yoast from registering a second sitemap family
 * and wasting crawl/discovery signals on two competing indexes. The setting is
 * only touched when Yoast exposes its public options API and is currently on.
 */
function go_verge_yoast_disable_native_xml_sitemaps_once() {
	if ( ! is_admin() || ! class_exists( 'WPSEO_Options' ) ) {
		return;
	}

	$flag = 'go_verge_yoast_sitemap_contract_37744';
	if ( get_option( $flag, false ) ) {
		return;
	}

	try {
		$enabled = WPSEO_Options::get( 'enable_xml_sitemap', null, array( 'wpseo' ) );
		if ( true === $enabled ) {
			WPSEO_Options::set( 'enable_xml_sitemap', false, 'wpseo' );
		}
		update_option( $flag, 1, false );
	} catch ( Throwable $e ) {
		/* Leave the flag unset so a later admin request can retry after Yoast
		 * finishes loading. Search rendering must never fail because of this. */
	}
}
add_action( 'admin_init', 'go_verge_yoast_disable_native_xml_sitemaps_once', 2 );

/**
 * Mirror the theme's indexing policy when Yoast owns the robots presenter.
 *
 * @param array $robots Yoast robots directives.
 * @return array
 */
function go_verge_yoast_robots_array( $robots ) {
	if ( ! is_array( $robots ) ) {
		return $robots;
	}

	$force_noindex = false;
	if ( function_exists( 'go_verge_search_is_utility_surface' ) && go_verge_search_is_utility_surface() ) {
		$force_noindex = true;
	}
	if ( is_date() || is_attachment() || is_singular( 'go_promotion' ) ) {
		$force_noindex = true;
	}
	/* V7 retired the free-form tag archive surface in favor of controlled entity,
	 * platform and service hubs. Mirror that policy in Yoast as well so the head,
	 * redirects and the custom sitemap never disagree about legacy /tag/ URLs. */
	if ( is_tag() ) {
		$force_noindex = true;
	}
	if ( function_exists( 'go_verge_indexing_is_filtered_discovery_request' ) && go_verge_indexing_is_filtered_discovery_request() ) {
		$force_noindex = true;
	}
	if ( is_singular( array( 'productions', 'go_entity' ) ) && function_exists( 'go_verge_v45_subject_active_type' ) && go_verge_v45_subject_active_type() ) {
		$force_noindex = true;
	}

	if ( $force_noindex ) {
		$robots['index']  = 'noindex';
		$robots['follow'] = 'follow';
		/* Match Yoast's own non-public output: preview directives have no
		 * meaning on a noindex URL and should not survive a late override. */
		unset( $robots['max-snippet'], $robots['max-image-preview'], $robots['max-video-preview'] );
		return $robots;
	}

	/* Canonical editorial desks are intentionally public. Do not allow a stale
	 * plugin setting from a prior taxonomy architecture to suppress them. */
	if ( function_exists( 'go_verge_category_parity_should_force_index' ) && go_verge_category_parity_should_force_index() ) {
		$robots['index']  = 'index';
		$robots['follow'] = 'follow';
	}

	/* Yoast normally adds these already. Reassert the Discover/Search preview
	 * contract only on indexable surfaces and never weaken an explicit noindex. */
	if ( 'noindex' !== strtolower( (string) ( $robots['index'] ?? '' ) ) && ! is_404() ) {
		$robots['max-snippet']       = 'max-snippet:-1';
		$robots['max-image-preview'] = 'max-image-preview:large';
		$robots['max-video-preview'] = 'max-video-preview:-1';
	}
	return $robots;
}
add_filter( 'wpseo_robots_array', 'go_verge_yoast_robots_array', 4200 );

/**
 * Use the same >=1200px representative image selected by the newsroom for
 * Discover as Yoast's primary Open Graph image.
 */
function go_verge_yoast_discover_image( $image ) {
	if ( ! is_singular( 'post' ) || ! function_exists( 'go_verge_rank_math_current_discover_image' ) ) {
		return $image;
	}
	$selected = go_verge_rank_math_current_discover_image();
	return ! empty( $selected['url'] ) ? $selected['url'] : $image;
}
add_filter( 'wpseo_opengraph_image', 'go_verge_yoast_discover_image', 95 );

function go_verge_yoast_discover_image_width( $width ) {
	if ( is_singular( 'post' ) && function_exists( 'go_verge_rank_math_current_discover_image' ) ) {
		$image = go_verge_rank_math_current_discover_image();
		if ( ! empty( $image['width'] ) ) { return (int) $image['width']; }
	}
	return $width;
}
add_filter( 'wpseo_opengraph_image_width', 'go_verge_yoast_discover_image_width', 95 );

function go_verge_yoast_discover_image_height( $height ) {
	if ( is_singular( 'post' ) && function_exists( 'go_verge_rank_math_current_discover_image' ) ) {
		$image = go_verge_rank_math_current_discover_image();
		if ( ! empty( $image['height'] ) ) { return (int) $image['height']; }
	}
	return $height;
}
add_filter( 'wpseo_opengraph_image_height', 'go_verge_yoast_discover_image_height', 95 );

function go_verge_yoast_discover_image_type( $type ) {
	if ( is_singular( 'post' ) && function_exists( 'go_verge_rank_math_current_discover_image' ) && function_exists( 'go_verge_rank_math_image_mime_type' ) ) {
		$image = go_verge_rank_math_current_discover_image();
		if ( ! empty( $image['url'] ) ) {
			$mime = go_verge_rank_math_image_mime_type( $image['url'], get_post_thumbnail_id( get_queried_object_id() ) );
			if ( $mime ) { return $mime; }
		}
	}
	return $type;
}
add_filter( 'wpseo_opengraph_image_type', 'go_verge_yoast_discover_image_type', 95 );

/** Keep site-name schema aligned with the theme's public publisher identity. */
function go_verge_yoast_schema_website( $data ) {
	if ( ! is_array( $data ) ) { return $data; }
	if ( function_exists( 'go_verge_seo_site_name' ) ) {
		$data['name'] = go_verge_seo_site_name();
	}
	if ( function_exists( 'go_verge_seo_alternate_name_value' ) ) {
		$alternate = go_verge_seo_alternate_name_value();
		if ( $alternate ) { $data['alternateName'] = $alternate; } else { unset( $data['alternateName'] ); }
	}
	$data['url'] = home_url( '/' );
	if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
		$data = go_verge_schema_add_accessibility( $data, true );
	}
	return $data;
}
add_filter( 'wpseo_schema_website', 'go_verge_yoast_schema_website', 90 );

/** Enrich Yoast's publisher Organization without creating a second publisher. */
function go_verge_yoast_schema_organization( $data ) {
	if ( ! is_array( $data ) ) { return $data; }

	/* Keep one publisher node, but make its newsroom role explicit. */
	$data['@type'] = 'NewsMediaOrganization';
	if ( function_exists( 'go_verge_seo_site_name' ) ) {
		$data['name'] = go_verge_seo_site_name();
	}
	if ( function_exists( 'go_verge_seo_alternate_name_value' ) ) {
		$alternate = go_verge_seo_alternate_name_value();
		if ( $alternate ) { $data['alternateName'] = $alternate; } else { unset( $data['alternateName'] ); }
	}
	$data['url'] = home_url( '/' );
	if ( empty( $data['logo'] ) && function_exists( 'go_verge_seo_logo' ) ) {
		$logo = go_verge_seo_logo();
		if ( is_array( $logo ) && ! empty( $logo['url'] ) ) {
			$data['logo'] = array_filter( array(
				'@type'  => 'ImageObject',
				'url'    => esc_url_raw( $logo['url'] ),
				'width'  => ! empty( $logo['width'] ) ? (int) $logo['width'] : null,
				'height' => ! empty( $logo['height'] ) ? (int) $logo['height'] : null,
			) );
		}
	}

	if ( function_exists( 'go_verge_apply_editorial_scope_to_org' ) ) {
		$data = go_verge_apply_editorial_scope_to_org( $data );
	}
	if ( function_exists( 'go_verge_publisher_same_as_urls' ) ) {
		$same_as = go_verge_publisher_same_as_urls();
		if ( $same_as ) { $data['sameAs'] = array_values( array_unique( array_filter( $same_as ) ) ); }
	}
	if ( function_exists( 'go_verge_publisher_contact_email' ) ) {
		$email = go_verge_publisher_contact_email();
		if ( $email ) {
			$data['email'] = $email;
			$data['contactPoint'] = array(
				'@type'             => 'ContactPoint',
				'contactType'       => 'editorial',
				'email'             => $email,
				'availableLanguage' => get_bloginfo( 'language' ),
			);
		}
	}
	if ( function_exists( 'go_verge_publisher_legal_name' ) ) {
		$legal = go_verge_publisher_legal_name();
		if ( $legal ) { $data['legalName'] = $legal; }
	}
	if ( function_exists( 'go_verge_publisher_founding_date' ) ) {
		$founded = go_verge_publisher_founding_date();
		if ( $founded ) { $data['foundingDate'] = $founded; }
	}
	if ( function_exists( 'go_verge_schema_policy_urls' ) ) {
		foreach ( go_verge_schema_policy_urls() as $property => $url ) {
			if ( $url ) { $data[ $property ] = esc_url_raw( $url ); }
		}
	}
	if ( function_exists( 'go_verge_eeat_resolved_trust_urls' ) ) {
		foreach ( go_verge_eeat_resolved_trust_urls() as $property => $url ) {
			if ( $url && empty( $data[ $property ] ) ) { $data[ $property ] = esc_url_raw( $url ); }
		}
	}
	if ( function_exists( 'go_verge_eeat_publisher_facts' ) ) {
		foreach ( go_verge_eeat_publisher_facts() as $property => $value ) {
			if ( ! isset( $data[ $property ] ) ) { $data[ $property ] = $value; }
		}
	}
	return $data;
}
add_filter( 'wpseo_schema_organization', 'go_verge_yoast_schema_organization', 90 );

/** Resolve the author represented by Yoast's current Person piece. */
function go_verge_yoast_schema_author_id() {
	if ( is_singular( 'post' ) ) {
		$post = get_queried_object();
		return $post instanceof WP_Post ? (int) $post->post_author : 0;
	}
	if ( is_author() ) {
		$author = get_queried_object();
		return $author instanceof WP_User ? (int) $author->ID : 0;
	}
	return 0;
}

/** Add stable author identity, beat and verifiable credentials to Yoast's Person node. */
function go_verge_yoast_schema_person( $data ) {
	if ( ! is_array( $data ) ) { return $data; }
	$author_id = go_verge_yoast_schema_author_id();
	if ( ! $author_id ) { return $data; }

	$data['name'] = get_the_author_meta( 'display_name', $author_id );
	$data['url']  = get_author_posts_url( $author_id );

	/* Reuse the newsroom's mature Person resolver, but never replace Yoast's own
	 * @id because other Yoast graph pieces may already reference it. */
	if ( function_exists( 'go_verge_rank_math_person_node' ) ) {
		$resolved = go_verge_rank_math_person_node( $author_id );
		foreach ( $resolved as $property => $value ) {
			if ( in_array( $property, array( '@id', '@type', 'worksFor' ), true ) ) { continue; }
			if ( ! empty( $value ) ) { $data[ $property ] = $value; }
		}
	}

	if ( function_exists( 'go_verge_eeat_split_list' ) && function_exists( 'go_verge_author_profile_value' ) ) {
		$alma = go_verge_eeat_split_list( go_verge_author_profile_value( $author_id, 'go_author_alma_mater' ), 4 );
		if ( $alma ) {
			$data['alumniOf'] = array_map( static function ( $name ) { return array( '@type' => 'EducationalOrganization', 'name' => $name ); }, $alma );
		}
		$members = go_verge_eeat_split_list( go_verge_author_profile_value( $author_id, 'go_author_memberships' ), 6 );
		if ( $members ) {
			$data['memberOf'] = array_map( static function ( $name ) { return array( '@type' => 'Organization', 'name' => $name ); }, $members );
		}
		$awards = go_verge_eeat_split_list( go_verge_author_profile_value( $author_id, 'go_author_awards' ), 8 );
		if ( $awards ) { $data['award'] = $awards; }
	}
	if ( function_exists( 'go_verge_author_role' ) ) {
		$role = trim( (string) go_verge_author_role( $author_id ) );
		if ( $role ) {
			$occupation = array( '@type' => 'Occupation', 'name' => $role );
			if ( function_exists( 'go_verge_author_list_meta' ) ) {
				$beats = go_verge_author_list_meta( $author_id, 'go_author_coverage', 6 );
				if ( $beats ) { $occupation['occupationalCategory'] = $beats; }
			}
			if ( function_exists( 'go_verge_author_profile_value' ) ) {
				$since = absint( go_verge_author_profile_value( $author_id, 'go_author_since' ) );
				if ( $since >= 1900 && $since <= (int) gmdate( 'Y' ) ) { $occupation['startDate'] = (string) $since; }
			}
			$data['hasOccupation'] = $occupation;
		}
	}
	return $data;
}
add_filter( 'wpseo_schema_person', 'go_verge_yoast_schema_person', 90 );

/**
 * Carry newsroom Article semantics into Yoast's graph.
 *
 * The same conservative enrichment used by the theme/Rank Math path is reused
 * here so Yoast does not lose image ratios, entities, comments or editorial
 * clocks. The graph stays owned by Yoast; no second JSON-LD block is printed.
 */
function go_verge_yoast_schema_article( $data ) {
	if ( ! is_array( $data ) || ! is_singular( 'post' ) ) {
		return $data;
	}
	$post_id = get_queried_object_id();
	if ( ! $post_id ) { return $data; }

	if ( function_exists( 'go_verge_article_schema_type' ) ) {
		$data['@type'] = go_verge_article_schema_type( $post_id );
	} else {
		$data['@type'] = function_exists( 'go_verge_post_is_news_article' ) && go_verge_post_is_news_article( $post_id ) ? 'NewsArticle' : 'Article';
	}

	if ( function_exists( 'go_verge_search_published_iso' ) ) {
		$published = go_verge_search_published_iso( $post_id );
		if ( $published ) { $data['datePublished'] = $published; }
	}
	if ( function_exists( 'go_verge_search_enrich_article_node' ) ) {
		$data = go_verge_search_enrich_article_node( $data, $post_id );
	} elseif ( function_exists( 'go_verge_search_consistent_modified_iso' ) ) {
		$modified = go_verge_search_consistent_modified_iso( $post_id );
		if ( $modified ) { $data['dateModified'] = $modified; }
	}
	if ( function_exists( 'go_verge_get_primary_term' ) ) {
		$primary = go_verge_get_primary_term( $post_id, 'category' );
		if ( $primary instanceof WP_Term ) { $data['articleSection'] = $primary->name; }
	}

	/* Provenance appears in schema only when the same sources are rendered in
	 * the visible "Apuração e fontes" block. */
	if ( function_exists( 'go_verge_editorial_evidence_sources' ) ) {
		$sources = go_verge_editorial_evidence_sources( $post_id );
		if ( $sources ) {
			$data['citation'] = array_map(
				static function ( $source ) {
					return array( '@type' => 'CreativeWork', 'name' => $source['label'], 'url' => $source['url'] );
				},
				array_values( $sources )
			);
		}
	}

	/* Ranking/list stories can cite first-class works in visible headings. Preserve
	 * those entities in Yoast too, without replacing the semantic resolver's base. */
	if ( function_exists( 'go_verge_v48_list_ranking_topics' ) ) {
		$existing = isset( $data['mentions'] ) ? (array) $data['mentions'] : array();
		$seen = array();
		$mentions = array();
		$push = static function ( $mention ) use ( &$seen, &$mentions ) {
			if ( ! is_array( $mention ) || empty( $mention['name'] ) ) { return; }
			$key = function_exists( 'go_verge_v48_key' ) ? go_verge_v48_key( $mention['name'] ) : strtolower( trim( (string) $mention['name'] ) );
			if ( ! $key || isset( $seen[ $key ] ) || count( $mentions ) >= 10 ) { return; }
			$seen[ $key ] = true;
			$mentions[] = $mention;
		};
		foreach ( $existing as $mention ) { $push( $mention ); }
		foreach ( go_verge_v48_list_ranking_topics( $post_id, 8 ) as $topic ) {
			$type = 'Thing';
			if ( 'games' === ( $topic['type'] ?? '' ) ) { $type = 'VideoGame'; }
			elseif ( 'productions' === ( $topic['type'] ?? '' ) ) { $type = 'CreativeWork'; }
			$push( array( '@type' => $type, 'name' => (string) $topic['label'], 'url' => (string) $topic['url'] ) );
		}
		if ( $mentions ) { $data['mentions'] = $mentions; }
	}
	if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
		$data = go_verge_schema_add_accessibility( $data, false );
	}
	unset( $data['isAccessibleForFree'] );
	return $data;
}
add_filter( 'wpseo_schema_article', 'go_verge_yoast_schema_article', 90 );


/** Return the first graph key whose node represents the current WebPage. */
function go_verge_yoast_graph_page_key( $data ) {
	if ( ! is_array( $data ) ) { return null; }
	$current = '';
	if ( function_exists( 'YoastSEO' ) ) {
		try {
			$surface = YoastSEO()->meta->for_current_page();
			if ( is_object( $surface ) && ! empty( $surface->canonical ) ) { $current = (string) $surface->canonical; }
		} catch ( Throwable $e ) {
			$current = '';
		}
	}
	if ( '' === $current && is_singular() ) { $current = (string) get_permalink( get_queried_object_id() ); }
	$current_key = $current ? strtolower( untrailingslashit( $current ) ) : '';
	$fallback = null;
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) { continue; }
		$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
		if ( ! array_intersect( array( 'WebPage', 'CollectionPage', 'ProfilePage', 'ItemPage', 'FAQPage' ), $types ) ) { continue; }
		if ( null === $fallback ) { $fallback = $key; }
		$url = isset( $node['url'] ) ? strtolower( untrailingslashit( (string) $node['url'] ) ) : '';
		$id  = isset( $node['@id'] ) ? strtolower( (string) $node['@id'] ) : '';
		if ( $current_key && ( $url === $current_key || 0 === strpos( $id, $current_key . '#' ) || $id === $current_key ) ) {
			return $key;
		}
	}
	return $fallback;
}

/** Return the @id of the first graph node matching one of the requested types. */
function go_verge_yoast_graph_type_id( $data, $wanted ) {
	$wanted = (array) $wanted;
	foreach ( (array) $data as $node ) {
		if ( ! is_array( $node ) || empty( $node['@id'] ) ) { continue; }
		$types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
		if ( array_intersect( $wanted, $types ) ) { return (string) $node['@id']; }
	}
	return '';
}

/** Append one graph node without duplicating an existing @id. */
function go_verge_yoast_graph_add_unique_node( &$data, $node ) {
	if ( ! is_array( $data ) || ! is_array( $node ) || empty( $node['@type'] ) ) { return; }
	$id = isset( $node['@id'] ) ? (string) $node['@id'] : '';
	if ( $id ) {
		foreach ( $data as $existing ) {
			if ( is_array( $existing ) && isset( $existing['@id'] ) && (string) $existing['@id'] === $id ) { return; }
		}
	}
	$data[] = $node;
}

/**
 * Add theme-owned entity schemas to Yoast's single graph instead of printing a
 * competing JSON-LD block. This covers game database hubs, entity hubs and
 * scored editorial reviews while keeping Yoast as the graph owner.
 */
function go_verge_yoast_schema_graph_bridge( $data, $context = null ) {
	if ( ! is_array( $data ) ) { return $data; }
	$page_key = go_verge_yoast_graph_page_key( $data );
	$page_id  = null !== $page_key && ! empty( $data[ $page_key ]['@id'] ) ? (string) $data[ $page_key ]['@id'] : '';
	$org_id   = go_verge_yoast_graph_type_id( $data, array( 'NewsMediaOrganization', 'Organization' ) );

	if ( is_singular( 'games' ) && function_exists( 'go_verge_schema_videogame' ) ) {
		$post_id = get_queried_object_id();
		$game    = go_verge_schema_videogame( $post_id );
		if ( is_array( $game ) ) {
			if ( $page_id ) { $game['mainEntityOfPage'] = array( '@id' => $page_id ); }
			go_verge_yoast_graph_add_unique_node( $data, $game );
			if ( null !== $page_key ) {
				$page = $data[ $page_key ];
				$page['@type']      = 'CollectionPage';
				$page['mainEntity'] = array( '@id' => $game['@id'] );
				$page['about']      = array( '@id' => $game['@id'] );
				$page['datePublished'] = get_post_time( 'c', true, $post_id );
				if ( function_exists( 'go_verge_game_hub_related_ids' ) && function_exists( 'go_verge_game_hub_modified_iso' ) ) {
					$related = go_verge_game_hub_related_ids( $post_id );
					$page['dateModified'] = go_verge_game_hub_modified_iso( $post_id, $related );
				}
				$data[ $page_key ] = $page;
			}
			if ( function_exists( 'go_verge_game_hub_coverage_schema' ) ) {
				$coverage = go_verge_game_hub_coverage_schema( $post_id, $game['@id'] );
				if ( is_array( $coverage ) ) {
					if ( $org_id && ! empty( $coverage['itemListElement'] ) ) {
						foreach ( $coverage['itemListElement'] as &$list_item ) {
							if ( isset( $list_item['item'] ) && is_array( $list_item['item'] ) ) {
								$list_item['item']['publisher'] = array( '@id' => $org_id );
							}
						}
						unset( $list_item );
					}
					go_verge_yoast_graph_add_unique_node( $data, $coverage );
					if ( null !== $page_key ) { $data[ $page_key ]['hasPart'] = array( '@id' => $coverage['@id'] ); }
				}
			}
		}
	}

	if ( is_singular( 'go_entity' ) && function_exists( 'go_verge_entity_schema_node' ) ) {
		$post_id = get_queried_object_id();
		$entity  = go_verge_entity_schema_node( $post_id );
		if ( is_array( $entity ) ) {
			if ( $page_id ) { $entity['mainEntityOfPage'] = array( '@id' => $page_id ); }
			go_verge_yoast_graph_add_unique_node( $data, $entity );
			if ( null !== $page_key ) {
				$data[ $page_key ]['mainEntity'] = array( '@id' => $entity['@id'] );
				$data[ $page_key ]['about']      = array( '@id' => $entity['@id'] );
			}
		}
	}

	if ( is_post_type_archive( 'go_entity' ) && null !== $page_key && function_exists( 'go_verge_entity_archive_schema_nodes' ) ) {
		$nodes = go_verge_entity_archive_schema_nodes();
		if ( ! empty( $nodes['page'] ) ) {
			$data[ $page_key ]['@type'] = 'CollectionPage';
			foreach ( array( 'name', 'description', 'inLanguage' ) as $property ) {
				if ( isset( $nodes['page'][ $property ] ) ) { $data[ $page_key ][ $property ] = $nodes['page'][ $property ]; }
			}
		}
	}

	/* Virtual newsroom: describe the exact stories visible on /noticias/ as an
	 * ordered collection. This mirrors the existing Rank Math/standalone graph
	 * without printing a second JSON-LD document when Yoast owns schema. */
	if ( null !== $page_key && function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) {
		$page_num = max( 1, absint( get_query_var( 'paged' ) ) );
		$url      = function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url( $page_num ) : home_url( '/noticias/' );
		$data[ $page_key ]['@type'] = 'CollectionPage';
		$data[ $page_key ]['url']   = $url;
		$data[ $page_key ]['name']  = 1 < $page_num ? sprintf( 'Notícias — página %d', $page_num ) : 'Notícias';
		if ( function_exists( 'go_verge_newsroom_description' ) ) {
			$data[ $page_key ]['description'] = go_verge_newsroom_description();
		}
		if ( function_exists( 'go_verge_news_authority_page_ids' ) && function_exists( 'go_verge_news_authority_per_page' ) ) {
			$elements = array();
			foreach ( go_verge_news_authority_page_ids( $page_num, go_verge_news_authority_per_page() ) as $position => $post_id ) {
				$post_id = absint( $post_id );
				$link    = $post_id ? get_permalink( $post_id ) : '';
				if ( ! $link ) { continue; }
				$elements[] = array(
					'@type'    => 'ListItem',
					'position' => count( $elements ) + 1,
					'url'      => $link,
					'name'     => wp_strip_all_tags( get_the_title( $post_id ) ),
				);
			}
			if ( $elements ) {
				$list_id = trailingslashit( $url ) . '#itemlist';
				$list = array(
					'@type'           => 'ItemList',
					'@id'             => $list_id,
					'itemListOrder'   => 'https://schema.org/ItemListOrderDescending',
					'numberOfItems'   => count( $elements ),
					'itemListElement' => $elements,
				);
				go_verge_yoast_graph_add_unique_node( $data, $list );
				$data[ $page_key ]['mainEntity'] = array( '@id' => $list_id );
			}
		}
	}

	/* First-page public archives: make CollectionPage semantics explicit and
	 * attach the visible result set as ItemList. It is a crawler-comprehension
	 * aid only; no rich-result entitlement is implied. */
	if ( null !== $page_key && ! is_paged() && ( is_category() || is_tax() || is_post_type_archive() ) && ! is_post_type_archive( 'go_entity' ) ) {
		$current_url = function_exists( 'go_verge_search_current_archive_url' ) ? go_verge_search_current_archive_url() : '';
		global $wp_query;
		if ( $current_url && $wp_query instanceof WP_Query && ! empty( $wp_query->posts ) ) {
			$elements = array();
			foreach ( $wp_query->posts as $post ) {
				if ( ! ( $post instanceof WP_Post ) ) { continue; }
				$link = get_permalink( $post );
				if ( ! $link ) { continue; }
				$elements[] = array(
					'@type'    => 'ListItem',
					'position' => count( $elements ) + 1,
					'url'      => $link,
					'name'     => wp_strip_all_tags( get_the_title( $post ) ),
				);
				if ( count( $elements ) >= 20 ) { break; }
			}
			if ( $elements ) {
				$list_id = trailingslashit( $current_url ) . '#itemlist';
				$list = array(
					'@type'           => 'ItemList',
					'@id'             => $list_id,
					'itemListOrder'   => 'https://schema.org/ItemListOrderDescending',
					'numberOfItems'   => count( $elements ),
					'itemListElement' => $elements,
				);
				$data[ $page_key ]['@type']      = 'CollectionPage';
				$data[ $page_key ]['mainEntity'] = array( '@id' => $list_id );
				go_verge_yoast_graph_add_unique_node( $data, $list );
			}
		}
	}

	if ( is_singular( 'post' ) && function_exists( 'go_verge_review_data' ) && function_exists( 'go_verge_schema_review' ) ) {
		$post_id = get_queried_object_id();
		$review  = go_verge_review_data( $post_id );
		if ( ! empty( $review['has_review'] ) && null !== ( $review['score'] ?? null ) ) {
			$node = go_verge_schema_review( $post_id, $review, get_permalink( $post_id ) );
			if ( is_array( $node ) ) {
				if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
					$node = go_verge_schema_add_accessibility( $node, false );
				}
				if ( $page_id ) {
					$node['isPartOf']         = array( '@id' => $page_id );
					$node['mainEntityOfPage'] = array( '@id' => $page_id );
				}
				$author_id = absint( get_post_field( 'post_author', $post_id ) );
				if ( $author_id ) {
					$node['author'] = array(
						'@type' => 'Person',
						'name'  => get_the_author_meta( 'display_name', $author_id ),
						'url'   => get_author_posts_url( $author_id ),
					);
				}
				$node['publisher'] = $org_id ? array( '@id' => $org_id ) : array(
					'@type' => 'NewsMediaOrganization',
					'name'  => function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : get_bloginfo( 'name' ),
					'url'   => home_url( '/' ),
				);
				go_verge_yoast_graph_add_unique_node( $data, $node );
			}
		}
	}

	/* Keep the container clock aligned with the Article clock and carry the
	 * theme's real accessibility features into the one Yoast-owned graph. */
	if ( null !== $page_key ) {
		if ( is_singular( 'post' ) ) {
			$post_id = get_queried_object_id();
			if ( function_exists( 'go_verge_search_published_iso' ) ) {
				$data[ $page_key ]['datePublished'] = go_verge_search_published_iso( $post_id );
			}
			if ( function_exists( 'go_verge_search_consistent_modified_iso' ) ) {
				$data[ $page_key ]['dateModified'] = go_verge_search_consistent_modified_iso( $post_id );
			}
		}
		if ( function_exists( 'go_verge_schema_add_accessibility' ) ) {
			$data[ $page_key ] = go_verge_schema_add_accessibility( $data[ $page_key ], true );
		}
	}
	if ( function_exists( 'go_verge_eeat_normalize_numbers' ) ) {
		$data = go_verge_eeat_normalize_numbers( $data );
	}

	return $data;
}
add_filter( 'wpseo_schema_graph', 'go_verge_yoast_schema_graph_bridge', 1800, 2 );


/* -------------------------------------------------------------------------
 * Canonical/title parity for theme-owned dynamic editorial surfaces.
 * ---------------------------------------------------------------------- */

/** Keep Yoast canonical URLs aligned with the same dynamic routes as the theme. */
function go_verge_yoast_canonical_bridge( $canonical ) {
	if ( is_404() ) { return $canonical; }

	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() ) {
		$page = max( 1, absint( get_query_var( 'paged' ) ) );
		return function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url( $page ) : $canonical;
	}
	if ( function_exists( 'go_verge_indexing_is_filtered_discovery_request' ) && go_verge_indexing_is_filtered_discovery_request() && function_exists( 'go_verge_indexing_clean_filtered_canonical' ) ) {
		return go_verge_indexing_clean_filtered_canonical( $canonical );
	}
	if ( is_singular( array( 'productions', 'go_entity' ) ) && function_exists( 'go_verge_v45_subject_active_type' ) && go_verge_v45_subject_active_type() ) {
		$base = get_permalink( get_queried_object_id() );
		return $base ?: $canonical;
	}
	if ( is_singular( array( 'productions', 'go_entity' ) ) && function_exists( 'go_verge_v45_subject_page' ) && function_exists( 'go_verge_v45_subject_page_url' ) ) {
		$page = go_verge_v45_subject_page();
		if ( $page > 1 ) {
			$url = go_verge_v45_subject_page_url( get_queried_object_id(), $page );
			if ( $url ) { return $url; }
		}
	}
	if ( function_exists( 'go_verge_v21_is_topic_hub' ) && go_verge_v21_is_topic_hub() ) {
		$topic = get_query_var( 'go_topic' );
		$destination = function_exists( 'go_verge_v36_topic_destination' ) ? go_verge_v36_topic_destination( $topic ) : array();
		$page = max( 1, absint( get_query_var( 'paged' ) ) );
		if ( $destination && ! empty( $destination['url'] ) ) {
			if ( $page > 1 && ! empty( $destination['id'] ) && in_array( (string) ( $destination['type'] ?? '' ), array( 'productions', 'go_entity' ), true ) && function_exists( 'go_verge_v45_subject_page_url' ) ) {
				return go_verge_v45_subject_page_url( absint( $destination['id'] ), $page );
			}
			return $destination['url'];
		}
	}
	if ( is_author() && function_exists( 'go_verge_author_archive_page_number' ) && go_verge_author_archive_page_number() > 1 ) {
		$url = get_pagenum_link( go_verge_author_archive_page_number() );
		return $url ?: $canonical;
	}
	if ( is_page() && max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) ) > 1 && function_exists( 'go_verge_seo_canonical_url' ) ) {
		$url = go_verge_seo_canonical_url();
		return $url ?: $canonical;
	}
	if ( is_front_page() && isset( $_GET['stream_page'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		return home_url( '/' );
	}
	if ( is_singular( 'games' ) ) {
		$post_id = get_queried_object_id();
		$custom  = trim( (string) get_post_meta( $post_id, '_yoast_wpseo_canonical', true ) );
		if ( '' === $custom ) {
			$url = get_permalink( $post_id );
			return $url ?: $canonical;
		}
	}
	return $canonical;
}
add_filter( 'wpseo_canonical', 'go_verge_yoast_canonical_bridge', 4100 );

/** Distinguish paginated author/subject/editorial pages in Yoast title output. */
function go_verge_yoast_dynamic_title_bridge( $title ) {
	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() && function_exists( 'go_verge_news_authority_document_title' ) ) {
		return go_verge_news_authority_document_title( $title );
	}
	if ( function_exists( 'go_verge_v21_is_topic_hub' ) && go_verge_v21_is_topic_hub() && function_exists( 'go_verge_v21_topic_label' ) ) {
		$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
		return go_verge_v21_topic_label( get_query_var( 'go_topic' ) ) . ' — ' . $site_name;
	}
	if ( is_post_type_archive( 'go_entity' ) ) {
		$site_name = function_exists( 'go_verge_seo_site_name' ) ? go_verge_seo_site_name() : 'Overdrive';
		return sprintf( __( 'Plataformas | %s', 'go-verge' ), $site_name );
	}
	if ( is_author() && function_exists( 'go_verge_author_pagination_title' ) ) {
		return go_verge_author_pagination_title( $title );
	}
	if ( is_singular( array( 'productions', 'go_entity' ) ) && function_exists( 'go_verge_v45_subject_document_title' ) ) {
		return go_verge_v45_subject_document_title( $title );
	}
	if ( is_page() && function_exists( 'go_verge_paginated_page_document_title' ) ) {
		return go_verge_paginated_page_document_title( $title );
	}
	return $title;
}
add_filter( 'wpseo_title', 'go_verge_yoast_dynamic_title_bridge', 1250 );

/** Match the author pagination description already used by the native/Rank Math path. */
function go_verge_yoast_dynamic_description_bridge( $description ) {
	if ( function_exists( 'go_verge_news_authority_is_newsroom' ) && go_verge_news_authority_is_newsroom() && function_exists( 'go_verge_newsroom_description' ) ) {
		return go_verge_newsroom_description();
	}
	if ( is_post_type_archive( 'go_entity' ) ) {
		return __( 'Xbox, Nintendo, PC, PlayStation e Mobile: notícias, jogos, serviços e guias por plataforma.', 'go-verge' );
	}
	if ( is_singular( 'games' ) ) {
		$post_id = get_queried_object_id();
		$custom  = trim( (string) get_post_meta( $post_id, '_yoast_wpseo_metadesc', true ) );
		if ( '' === $custom ) {
			$game = function_exists( 'go_verge_game_data' ) ? go_verge_game_data( $post_id ) : array();
			$text = trim( wp_strip_all_tags( (string) ( $game['summary'] ?? '' ) ) );
			if ( '' === $text ) {
				$name = function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $post_id ) : get_the_title( $post_id );
				$text = sprintf( __( 'Tudo sobre %s: notícias, guias, reviews, vídeos, plataformas, lançamento e ficha técnica.', 'go-verge' ), $name );
			}
			$text = preg_replace( '/\s+/u', ' ', $text );
			return function_exists( 'mb_strimwidth' ) ? mb_strimwidth( $text, 0, 155, '…', 'UTF-8' ) : ( strlen( $text ) > 155 ? rtrim( substr( $text, 0, 154 ) ) . '…' : $text );
		}
	}
	if ( is_author() && function_exists( 'go_verge_author_pagination_description' ) ) {
		return go_verge_author_pagination_description( $description );
	}
	if ( function_exists( 'go_verge_rank_math_description_fallback' ) ) {
		return go_verge_rank_math_description_fallback( $description );
	}
	return $description;
}
add_filter( 'wpseo_metadesc', 'go_verge_yoast_dynamic_description_bridge', 2300 );
