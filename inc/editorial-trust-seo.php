<?php
/**
 * Technical SEO, trust pages and editorial workflow refinements.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Whether a post belongs to a guides/help section.
 *
 * @param int|WP_Post|null $post Post ID/object.
 * @return bool
 */
function go_verge_is_guide_post( $post = null ) {
	$post = get_post( $post );
	if ( ! $post || 'post' !== $post->post_type ) {
		return false;
	}

	// V7: Tipo de conteúdo is the source of truth. Tutorials remains an
	// editorial category and is also considered guide/help content for FAQ
	// eligibility and related technical helpers.
	if ( function_exists( 'go_verge_v7_post_content_type' ) ) {
		$type = go_verge_v7_post_content_type( $post->ID );
		if ( 'guia' === $type || 'guia-de-compra' === $type ) {
			return true;
		}
	}

	$guide_slugs = array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'detonados', 'tutoriais', 'tutorial' );
	$terms       = get_the_category( $post->ID );
	foreach ( (array) $terms as $term ) {
		$current = $term;
		while ( $current instanceof WP_Term ) {
			$slug = sanitize_title( $current->slug );
			$name = sanitize_title( $current->name );
			if ( in_array( $slug, $guide_slugs, true ) || in_array( $name, $guide_slugs, true ) || preg_match( '/(?:^|-)(?:guia|guias|dica|dicas|tutorial|tutoriais)(?:-|$)/', $slug ) ) {
				return true;
			}
			if ( ! $current->parent ) {
				break;
			}
			$current = get_term( (int) $current->parent, 'category' );
			if ( is_wp_error( $current ) ) {
				break;
			}
		}
	}

	return false;
}

/**
 * Editorially meaningful meta description. Never invents facts.
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_real_meta_description( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	/*
	 * The canonical resolver lives in functions.php so the theme-native SEO
	 * layer, Rank Math bridge and schema all emit the exact same description.
	 * Priority: explicit meta description, support line, then excerpt fallback.
	 */
	if ( function_exists( 'go_verge_preferred_search_description' ) ) {
		return go_verge_preferred_search_description( $post_id );
	}

	return '';
}

/**
 * Normalize a short meta description candidate.
 *
 * @param string $text Candidate text.
 * @return string
 */
function go_verge_trim_meta_description( $text ) {
	$text = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( strip_shortcodes( (string) $text ) ) ) );
	if ( '' === $text ) {
		return '';
	}
	if ( function_exists( 'mb_strimwidth' ) ) {
		return mb_strimwidth( $text, 0, 158, '…', 'UTF-8' );
	}
	return strlen( $text ) > 158 ? rtrim( substr( $text, 0, 157 ) ) . '…' : $text;
}

/**
 * Meaningful archive descriptions for Rank Math defaults.
 *
 * @return string
 */
function go_verge_archive_meta_description() {
	if ( is_post_type_archive( 'games' ) ) {
		return __( 'Encontre fichas de jogos, plataformas, datas, reviews, guias e notícias relacionadas no Overdrive.', 'go-verge' );
	}

	if ( is_post_type_archive( 'go_promotion' ) ) {
		return __( 'Veja promoções, ofertas e jogos grátis selecionados pelo Overdrive para PC, PlayStation, Xbox e Nintendo.', 'go-verge' );
	}

	if ( is_post_type_archive( 'go_entity' ) ) {
		return __( 'Acompanhe hubs de jogos, estúdios, franquias e temas cobertos pelo Overdrive.', 'go-verge' );
	}

	if ( is_category() || is_tag() || is_tax() ) {
		$term = get_queried_object();
		if ( $term instanceof WP_Term ) {
			$term_description = go_verge_trim_meta_description( term_description( $term->term_id, $term->taxonomy ) );
			if ( '' !== $term_description ) {
				return $term_description;
			}
			return sprintf(
				/* translators: %s: taxonomy term name. */
				__( 'Últimas notícias, reviews, guias e atualizações sobre %s no Overdrive.', 'go-verge' ),
				$term->name
			);
		}
	}

	if ( is_author() ) {
		$author = get_queried_object();
		if ( $author instanceof WP_User ) {
			$bio = go_verge_trim_meta_description( get_the_author_meta( 'description', $author->ID ) );
			if ( '' !== $bio ) {
				return $bio;
			}
			return sprintf(
				/* translators: %s: author display name. */
				__( 'Matérias assinadas por %s no Overdrive, com notícias, reviews, guias e análises sobre games, entretenimento e tecnologia.', 'go-verge' ),
				$author->display_name
			);
		}
	}

	if ( is_home() ) {
		return go_verge_trim_meta_description( get_bloginfo( 'description' ) );
	}

	return '';
}

/**
 * Detect Rank Math placeholder descriptions that should not reach search snippets.
 *
 * @param string $description Current meta description.
 * @return bool
 */
function go_verge_rank_math_description_is_generic( $description ) {
	$clean            = trim( wp_strip_all_tags( (string) $description ) );
	$site_description = trim( wp_strip_all_tags( (string) get_bloginfo( 'description' ) ) );
	if ( '' === $clean || ( '' !== $site_description && 0 === strcasecmp( $clean, $site_description ) ) ) {
		return true;
	}

	if ( ! is_archive() && ! is_home() ) {
		return false;
	}

	$normalized = function_exists( 'remove_accents' ) ? remove_accents( $clean ) : $clean;
	$normalized = strtolower( $normalized );
	$normalized = preg_replace( '/\s+/u', ' ', $normalized );
	$site_name  = function_exists( 'remove_accents' ) ? remove_accents( get_bloginfo( 'name' ) ) : get_bloginfo( 'name' );
	$site_name  = strtolower( trim( (string) $site_name ) );

	if ( '' !== $site_name ) {
		$normalized = preg_replace( '/\s*\|\s*' . preg_quote( $site_name, '/' ) . '$/u', '', $normalized );
	}

	return (bool) preg_match( '/^(?:.+\s+)?(?:archive|archives|arquivo|arquivos)$/u', trim( $normalized ) );
}

/** Enforce the newsroom description on posts and meaningful summaries on archives. */
function go_verge_rank_math_description_fallback( $description ) {
	/*
	 * On newsroom posts, always enforce the newsroom resolver. Rank Math can
	 * produce a perfectly non-empty automatic excerpt, so checking only whether
	 * its description is blank/generic is insufficient and was the reason body
	 * excerpts reached Google instead of the support line/meta description.
	 */
	if ( is_singular( 'post' ) ) {
		$preferred = go_verge_real_meta_description( get_queried_object_id() );
		return '' !== $preferred ? $preferred : $description;
	}

	if ( ! go_verge_rank_math_description_is_generic( $description ) ) {
		return $description;
	}

	$fallback = go_verge_archive_meta_description();
	return '' !== $fallback ? $fallback : $description;
}
add_filter( 'rank_math/frontend/description', 'go_verge_rank_math_description_fallback', 2200 );

/**
 * Keep Yoast on the same singular-description policy if it is enabled later.
 *
 * @param string $description Yoast's resolved meta description.
 * @return string
 */
function go_verge_yoast_editorial_metadesc( $description ) {
	if ( ! is_singular( 'post' ) ) {
		return $description;
	}

	$preferred = go_verge_real_meta_description( get_queried_object_id() );
	return '' !== $preferred ? $preferred : $description;
}
add_filter( 'wpseo_metadesc', 'go_verge_yoast_editorial_metadesc', 2200 );

/**
 * Build a clean Person node for schema.
 *
 * @param int $author_id User ID.
 * @return array
 */
function go_verge_rank_math_person_node( $author_id ) {
	$author_id = absint( $author_id );
	$name      = get_the_author_meta( 'display_name', $author_id );
	$url       = get_author_posts_url( $author_id );
	$node      = array(
		'@type' => 'Person',
		'@id'   => $url . '#person',
		'name'  => $name,
		'url'   => $url,
	);
	$bio = trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', $author_id ) ) );
	if ( '' !== $bio ) {
		$node['description'] = $bio;
	}
	if ( function_exists( 'go_verge_author_role' ) ) {
		$role = go_verge_author_role( $author_id );
		if ( $role ) {
			$node['jobTitle'] = $role;
		}
	}
	if ( function_exists( 'go_verge_author_list_meta' ) ) {
		$topics = array_values(
			array_unique(
				array_merge(
					go_verge_author_list_meta( $author_id, 'go_author_coverage', 12 ),
					go_verge_author_list_meta( $author_id, 'go_author_expertise', 12 )
				)
			)
		);
		if ( $topics ) {
			$node['knowsAbout'] = $topics;
		}
	}
	if ( function_exists( 'go_verge_author_profile_value' ) ) {
		$location = go_verge_author_profile_value( $author_id, 'go_author_location' );
		if ( $location ) {
			$node['homeLocation'] = array( '@type' => 'Place', 'name' => $location );
		}
	}
	$node['worksFor'] = array( '@id' => home_url( '/#organization' ) );
	$avatar = go_verge_schema_avatar_url( $author_id, 256 );
	if ( $avatar ) {
		$node['image'] = array( '@type' => 'ImageObject', 'url' => $avatar );
	}

	/*
	 * sameAs anchors a Person to identities OUTSIDE this site.
	 *
	 * The WordPress profile "Website" field defaults to the site's own address,
	 * so every byline used to claim sameAs: http://gameoverdrive.com.br — an
	 * http URL, pointing at the publisher, asserted as an alternate identity of
	 * a journalist. That conflates the Person and the Organization in exactly
	 * the graph Google and the answer engines read to tell them apart, and it is
	 * the one property whose whole purpose is disambiguation.
	 *
	 * Own-host URLs are therefore dropped, and http is upgraded so a profile is
	 * not published under a scheme that redirects.
	 */
	$home_host = go_verge_schema_normalize_host( home_url( '/' ) );

	$same_as = array();
	foreach ( array( 'url', 'twitter', 'facebook', 'instagram', 'youtube', 'linkedin', 'bluesky', 'mastodon', 'threads', 'tiktok', 'go_author_portfolio_url' ) as $key ) {
		$value = trim( (string) get_the_author_meta( $key, $author_id ) );
		if ( '' === $value || ! preg_match( '#^https?://#i', $value ) ) {
			continue;
		}
		$profile_url = esc_url_raw( $value, array( 'http', 'https' ) );
		if ( ! $profile_url ) {
			continue;
		}
		$host = go_verge_schema_normalize_host( $profile_url );
		if ( '' === $host || ( '' !== $home_host && $host === $home_host ) ) {
			continue;
		}
		$same_as[] = set_url_scheme( $profile_url, 'https' );
	}

	/**
	 * External identities for one author.
	 *
	 * @param string[] $same_as   Resolved profile URLs.
	 * @param int      $author_id User ID.
	 */
	$same_as = (array) apply_filters( 'go_verge_author_same_as_urls', $same_as, $author_id );
	$same_as = array_values( array_unique( array_filter( $same_as ) ) );
	if ( $same_as ) {
		$node['sameAs'] = $same_as;
	}

	return $node;
}

/**
 * Avatar URL safe to publish inside JSON-LD.
 *
 * Script content is raw text, so an HTML-escaped ampersand stays literal in the
 * parsed JSON: `?s=96&amp;d=mm&amp;r=g` is consumed as three malformed query
 * parameters rather than three real ones. Reducing the Gravatar URL to its one
 * meaningful argument removes the ampersand entirely, so the value survives any
 * escaping layer between here and the page. `d` and `r` only restate Gravatar's
 * own defaults.
 *
 * @param int $author_id User ID.
 * @param int $size      Requested square size in pixels.
 * @return string
 */
function go_verge_schema_avatar_url( $author_id, $size = 256 ) {
	$avatar = get_avatar_url( absint( $author_id ), array( 'size' => absint( $size ) ) );
	if ( ! $avatar ) {
		return '';
	}

	$host = wp_parse_url( $avatar, PHP_URL_HOST );
	$host = is_string( $host ) ? strtolower( $host ) : '';
	if ( 'gravatar.com' === $host || '.gravatar.com' === substr( $host, -13 ) ) {
		$parts = explode( '?', $avatar, 2 );
		if ( '' !== $parts[0] ) {
			return $parts[0] . '?s=' . absint( $size );
		}
	}

	return $avatar;
}

/**
 * Host of a URL, lowercased and without a leading `www.`.
 *
 * Written as an explicit prefix test rather than ltrim(): ltrim's second
 * argument is a character SET, so ltrim( $host, 'www.' ) also eats the leading
 * "w" and "." of hosts like w3.org.
 *
 * @param string $url Absolute URL.
 * @return string Host, or an empty string when the URL has none.
 */
function go_verge_schema_normalize_host( $url ) {
	$host = wp_parse_url( (string) $url, PHP_URL_HOST );
	if ( ! is_string( $host ) || '' === $host ) {
		return '';
	}
	$host = strtolower( $host );

	return 0 === strpos( $host, 'www.' ) ? substr( $host, 4 ) : $host;
}

/**
 * Article schema independent of Rank Math's selected schema template.
 *
 * @param int $post_id Post ID.
 * @return array|null
 */
function go_verge_rank_math_article_node( $post_id ) {
	$post = get_post( $post_id );
	if ( ! $post || 'post' !== $post->post_type ) {
		return null;
	}

	$url  = get_permalink( $post_id );
	$type = function_exists( 'go_verge_article_schema_type' ) ? go_verge_article_schema_type( $post_id ) : 'Article';
	$node = array(
		'@type'            => $type,
		'@id'              => $url . '#go-article',
		'headline'         => wp_strip_all_tags( get_the_title( $post_id ) ),
		'url'              => $url,
		'isPartOf'         => array( '@id' => go_verge_schema_current_webpage_id() ),
		'mainEntityOfPage' => array( '@type' => 'WebPage', '@id' => go_verge_schema_current_webpage_id() ),
		'datePublished'    => function_exists( 'go_verge_search_published_iso' ) ? go_verge_search_published_iso( $post_id ) : get_post_time( 'c', true, $post_id ),
		'dateModified'     => function_exists( 'go_verge_search_consistent_modified_iso' ) ? go_verge_search_consistent_modified_iso( $post_id ) : ( function_exists( 'go_verge_search_modified_iso' ) ? go_verge_search_modified_iso( $post_id ) : get_post_modified_time( 'c', true, $post_id ) ),
		'inLanguage'       => get_bloginfo( 'language' ),
		'author'           => array( '@id' => get_author_posts_url( (int) $post->post_author ) . '#person' ),
		'publisher'        => array( '@id' => home_url( '/#organization' ) ),
	);

	$description = go_verge_real_meta_description( $post_id );
	if ( '' !== $description ) {
		$node['description'] = $description;
	}

	if ( has_post_thumbnail( $post_id ) ) {
		/* Keep Article.image, WebPage.primaryImageOfPage and og:image aligned on
		 * the same representative high-resolution asset. Google explicitly uses
		 * schema.org and og:image as preferred-image sources for Discover. */
		$image = function_exists( 'go_verge_schema_editorial_image' ) ? go_verge_schema_editorial_image( $post_id ) : null;
		if ( is_array( $image ) && ! empty( $image['url'] ) ) {
			$node['image'] = $image;
		}
	}

	$primary = function_exists( 'go_verge_get_primary_term' ) ? go_verge_get_primary_term( $post_id ) : null;
	$terms = get_the_category( $post_id );
	if ( $primary instanceof WP_Term ) { $node['articleSection'] = $primary->name; }
	elseif ( ! empty( $terms[0] ) ) { $node['articleSection'] = $terms[0]->name; }
	$tags = get_the_tags( $post_id );
	if ( $tags && ! is_wp_error( $tags ) ) {
		$node['keywords'] = array_values( wp_list_pluck( $tags, 'name' ) );
	}
	if ( function_exists( 'go_verge_schema_speakable_supported' ) && go_verge_schema_speakable_supported() ) {
		$node['speakable'] = array(
			'@type'       => 'SpeakableSpecification',
			'cssSelector' => array( '.go-single__title', '.go-single__deck', '.go-scored-masthead__title', '.go-scored-masthead__deck' ),
		);
	} else {
		unset( $node['speakable'] );
	}

	/* Back-compat only: Review now lives in a separate Review node. */
	if ( function_exists( 'go_verge_article_type_carries_review' ) && go_verge_article_type_carries_review( $type ) ) {
		$review = go_verge_rank_math_review_node( $post_id );
		if ( is_array( $review ) ) {
			foreach ( array( 'itemReviewed', 'reviewRating', 'reviewBody' ) as $property ) {
				if ( isset( $review[ $property ] ) ) {
					$node[ $property ] = $review[ $property ];
				}
			}
		}
	}

	return $node;
}

/**
 * Review node with a real rating when the editorial review has a score.
 *
 * @param int $post_id Post ID.
 * @return array|null
 */
function go_verge_rank_math_review_node( $post_id ) {
	if ( ! function_exists( 'go_verge_review_data' ) ) {
		return null;
	}

	$data = go_verge_review_data( $post_id );
	if ( empty( $data['has_review'] ) || null === $data['score'] || ! is_numeric( $data['score'] ) ) {
		return null;
	}

	/*
	 * Keep one canonical Review builder for native schema and Rank Math. This
	 * preserves the richer reviewed-item metadata plus visible pros/cons instead
	 * of publishing a reduced second implementation whenever Rank Math is active.
	 */
	if ( function_exists( 'go_verge_schema_review' ) ) {
		return go_verge_schema_review( $post_id, $data, get_permalink( $post_id ) );
	}

	return null;
}

/**
 * Add Overdrive's validated nodes to Rank Math JSON-LD without duplicating
 * equivalent nodes already produced by another source.
 *
 * @param array $data Rank Math graph.
 * @param mixed $jsonld Rank Math JSON-LD object.
 * @return array
 */
function go_verge_rank_math_json_ld( $data, $jsonld = null ) {
	if ( ! is_singular( 'post' ) ) {
		return $data;
	}
	if ( ! is_array( $data ) ) {
		return $data;
	}
	$post_id = get_queried_object_id();
	if ( ! $post_id ) {
		return $data;
	}

	$types = static function ( $node ) {
		$type = isset( $node['@type'] ) ? $node['@type'] : array();
		return array_map( 'strval', (array) $type );
	};
	$find_type = static function ( $graph, $wanted ) use ( $types ) {
		foreach ( (array) $graph as $key => $node ) {
			if ( ! is_array( $node ) ) { continue; }
			if ( array_intersect( (array) $wanted, $types( $node ) ) ) { return $key; }
		}
		return null;
	};
	$find_current_type = static function ( $graph, $wanted, $url ) use ( $types ) {
		$page_id = (string) $url . '#webpage';
		foreach ( (array) $graph as $key => $node ) {
			if ( ! is_array( $node ) || ! array_intersect( (array) $wanted, $types( $node ) ) ) { continue; }
			$node_url = (string) ( $node['url'] ?? '' );
			$node_id  = (string) ( $node['@id'] ?? '' );
			$page_ref = is_array( $node['mainEntityOfPage'] ?? null ) ? (string) ( $node['mainEntityOfPage']['@id'] ?? '' ) : (string) ( $node['mainEntityOfPage'] ?? '' );
			if ( ( $node_url && untrailingslashit( $node_url ) === untrailingslashit( $url ) ) || $page_id === $page_ref || ( $node_id && 0 === strpos( $node_id, (string) $url . '#' ) ) ) { return $key; }
		}
		return null;
	};
	$find_id = static function ( $graph, $wanted ) {
		foreach ( (array) $graph as $key => $node ) {
			if ( is_array( $node ) && isset( $node['@id'] ) && $wanted === (string) $node['@id'] ) {
				return $key;
			}
		}
		return null;
	};
	$add_unique = static function ( &$graph, $preferred_key, $node ) {
		$key    = (string) $preferred_key;
		$suffix = 2;
		while ( array_key_exists( $key, $graph ) ) {
			$key = (string) $preferred_key . $suffix;
			$suffix++;
		}
		$graph[ $key ] = $node;
		return $key;
	};

	/*
	 * Rank Math can legitimately return only its selected Article schema.  The
	 * article still references the publisher, WebSite and WebPage, however, and
	 * leaving those IDs unresolved turns a syntactically valid graph into a set
	 * of disconnected claims.  Close the graph by canonical @id, not merely by
	 * type, so a complete Rank Math graph remains untouched and a partial graph
	 * receives exactly one node for each referenced entity.
	 */
	$organization_id = home_url( '/#organization' );
	$website_id      = home_url( '/#website' );
	$webpage_id      = go_verge_schema_current_webpage_id();

	if ( null === $find_id( $data, $organization_id ) && function_exists( 'go_verge_schema_organization' ) ) {
		$add_unique( $data, 'goOrganization', go_verge_schema_organization() );
	}
	if ( null === $find_id( $data, $website_id ) && function_exists( 'go_verge_schema_website' ) ) {
		$add_unique( $data, 'goWebSite', go_verge_schema_website() );
	}

	$breadcrumb     = function_exists( 'go_verge_schema_breadcrumbs' ) ? go_verge_schema_breadcrumbs() : null;
	$breadcrumb_id  = $webpage_id . '/breadcrumb';
	$breadcrumb_key = null;
	foreach ( $data as $candidate_key => $candidate ) {
		if ( ! is_array( $candidate ) || ! in_array( 'BreadcrumbList', $types( $candidate ), true ) ) { continue; }
		$candidate_id = (string) ( $candidate['@id'] ?? '' );
		$matches_page = $candidate_id && ( 0 === strpos( $candidate_id, get_permalink( $post_id ) . '#' ) || 0 === strpos( $candidate_id, $webpage_id ) );
		foreach ( (array) ( $candidate['itemListElement'] ?? array() ) as $element ) {
			$item = is_array( $element ) && is_array( $element['item'] ?? null ) ? $element['item'] : array();
			$item_url = (string) ( $item['@id'] ?? $item['url'] ?? ( is_string( $element['item'] ?? null ) ? $element['item'] : '' ) );
			if ( $item_url && untrailingslashit( $item_url ) === untrailingslashit( get_permalink( $post_id ) ) ) { $matches_page = true; break; }
		}
		if ( $matches_page ) { $breadcrumb_key = $candidate_key; break; }
	}
	if ( null !== $breadcrumb_key ) {
		if ( empty( $data[ $breadcrumb_key ]['@id'] ) ) { $data[ $breadcrumb_key ]['@id'] = $breadcrumb_id; }
		$breadcrumb_id = (string) $data[ $breadcrumb_key ]['@id'];
	}
	$has_breadcrumb = null !== $breadcrumb_key || is_array( $breadcrumb );
	if ( null === $find_id( $data, $webpage_id ) && function_exists( 'go_verge_schema_webpage' ) ) {
		$add_unique( $data, 'goWebPage', go_verge_schema_webpage( $has_breadcrumb ) );
	}
	if ( null === $breadcrumb_key && is_array( $breadcrumb ) ) {
		$breadcrumb['@id']   = $breadcrumb_id;
		$breadcrumb_key = $add_unique( $data, 'goBreadcrumb', $breadcrumb );
	}
	$page_key = $find_id( $data, $webpage_id );
	if ( $has_breadcrumb && null !== $page_key ) {
		$data[ $page_key ]['breadcrumb'] = array( '@id' => $breadcrumb_id );
	}

	$person = go_verge_rank_math_person_node( (int) get_post_field( 'post_author', $post_id ) );
	$person_key = $find_id( $data, $person['@id'] );
	if ( null === $person_key ) {
		$add_unique( $data, 'goPerson', $person );
	} else {
		$data[ $person_key ] = array_replace( $person, $data[ $person_key ] );
		$data[ $person_key ]['@id'] = $person['@id'];
		if ( ! empty( $person['worksFor'] ) ) { $data[ $person_key ]['worksFor'] = $person['worksFor']; }
	}

	$article = go_verge_rank_math_article_node( $post_id );
	$article_key = null;
	if ( $article ) {
		$key = $find_current_type( $data, array( 'Article', 'NewsArticle', 'BlogPosting' ), get_permalink( $post_id ) );
		if ( null === $key ) {
			$article_key = $add_unique( $data, 'goArticle', $article );
		} else {
			$article_key = $key;
			// Keep plugin-specific values, fill the technical/editorial gaps only.
			$data[ $key ] = array_replace( $article, $data[ $key ] );
			/* Rank Math's selected template used to win this merge and could leave a
			 * Notícias post as generic Article. Taxonomy is authoritative here. */
			$data[ $key ]['@type'] = $article['@type'];
			$data[ $key ]['author'] = $article['author'];
			$data[ $key ]['datePublished'] = $article['datePublished'];
			$data[ $key ]['dateModified']  = $article['dateModified'];
			$data[ $key ]['isPartOf']         = $article['isPartOf'];
			$data[ $key ]['mainEntityOfPage'] = $article['mainEntityOfPage'];
			unset( $data[ $key ]['isAccessibleForFree'] );
			if ( ! empty( $article['description'] ) ) { $data[ $key ]['description'] = $article['description']; }
		}
	}
	if ( null !== $article_key && isset( $data[ $article_key ]['@id'] ) ) {
		$page_key = $find_id( $data, $webpage_id );
		if ( null !== $page_key ) {
			$data[ $page_key ]['mainEntity'] = array( '@id' => $data[ $article_key ]['@id'] );
		}
	}

	/* Review is a separate entity with its own required rating/item semantics. */
	$article_carries_review = $article
		&& function_exists( 'go_verge_article_type_carries_review' )
		&& go_verge_article_type_carries_review( $article['@type'] );

	$review = $article_carries_review ? null : go_verge_rank_math_review_node( $post_id );
	if ( $review ) {
		/*
		 * A Review that names no page it belongs to is a node floating in the
		 * graph: it describes this URL, but nothing in the graph says so, and a
		 * consumer walking from the WebPage never reaches it. Tie it to the page
		 * in both directions.
		 */
		$webpage_id                 = go_verge_schema_current_webpage_id();
		$review['isPartOf']         = array( '@id' => $webpage_id );
		$review['mainEntityOfPage'] = array( '@id' => $webpage_id );

		$key = $find_current_type( $data, array( 'Review' ), get_permalink( $post_id ) );
		if ( null === $key ) {
			$add_unique( $data, 'goReview', $review );
			$review_id = $review['@id'];
		} else {
			$data[ $key ] = array_replace( $review, $data[ $key ] );
			$data[ $key ]['reviewRating'] = $review['reviewRating'];
			$data[ $key ]['itemReviewed'] = $review['itemReviewed'];
			$data[ $key ]['author'] = $review['author'];
			$data[ $key ]['isPartOf'] = $review['isPartOf'];
			$data[ $key ]['mainEntityOfPage'] = $review['mainEntityOfPage'];
			$review_id = isset( $data[ $key ]['@id'] ) ? $data[ $key ]['@id'] : $review['@id'];
		}

		$webpage_key = $find_id( $data, $webpage_id );
		if ( null !== $webpage_key && empty( $data[ $webpage_key ]['mainEntity'] ) ) {
			$data[ $webpage_key ]['mainEntity'] = array( '@id' => $review_id );
		}
	}


	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_json_ld', 50, 2 );

/**
 * Collapse duplicate top-level Article nodes for the current single.
 *
 * Rank Math can append its selected `#richSnippet` node after an earlier
 * filter has already added the theme's canonical `#go-article` node. Both
 * describe the same URL, but two competing headlines/IDs make the graph
 * harder for crawlers to interpret. Keep the richest node and merge missing
 * properties from the others; this never touches nested Article objects on
 * author or collection pages.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_rank_math_dedupe_current_article_nodes( $data ) {
	if ( ! is_singular( 'post' ) || ! is_array( $data ) ) {
		return $data;
	}

	$post_id  = get_queried_object_id();
	$canonical = $post_id ? untrailingslashit( (string) get_permalink( $post_id ) ) : '';
	if ( '' === $canonical ) {
		return $data;
	}

	$types = static function ( $node ) {
		return array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
	};
	$matches = array();
	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || ! array_intersect( array( 'Article', 'NewsArticle', 'BlogPosting' ), $types( $node ) ) ) {
			continue;
		}
		$node_url = untrailingslashit( (string) ( $node['url'] ?? '' ) );
		$node_id  = (string) ( $node['@id'] ?? '' );
		$page_ref = is_array( $node['mainEntityOfPage'] ?? null )
			? (string) ( $node['mainEntityOfPage']['@id'] ?? '' )
			: (string) ( $node['mainEntityOfPage'] ?? '' );
		/* IDs retain / before # on WordPress permalinks. Compare document URLs,
		 * not a prefix built from the untrailed canonical. */
		$id_document = untrailingslashit( preg_replace( '/#.*$/', '', $node_id ) );
		$ref_document = untrailingslashit( preg_replace( '/#.*$/', '', $page_ref ) );
		if ( $canonical === $node_url || $canonical === $id_document || $canonical === $ref_document ) {
			$matches[ $key ] = $node;
		}
	}
	if ( count( $matches ) < 2 ) {
		return $data;
	}

	$title = wp_strip_all_tags( get_the_title( $post_id ) );
	$score = static function ( $key, $node ) use ( $title ) {
		$id    = (string) ( $node['@id'] ?? '' );
		$score = 0;
		if ( false !== strpos( $id, '#go-article' ) ) { $score += 6; }
		if ( (string) ( $node['headline'] ?? '' ) === $title ) { $score += 4; }
		if ( ! empty( $node['url'] ) ) { $score += 2; }
		if ( ! empty( $node['image'] ) ) { $score += 1; }
		if ( ! empty( $node['datePublished'] ) ) { $score += 1; }
		return $score;
	};
	$keys = array_keys( $matches );
	usort( $keys, static function ( $a, $b ) use ( $matches, $score ) {
		$delta = $score( $b, $matches[ $b ] ) - $score( $a, $matches[ $a ] );
		return 0 !== $delta ? $delta : strcmp( (string) $a, (string) $b );
	} );
	$keep = array_shift( $keys );
	$merged = $matches[ $keep ];
	foreach ( $keys as $duplicate ) {
		foreach ( $matches[ $duplicate ] as $property => $value ) {
			if ( ! array_key_exists( $property, $merged ) || '' === $merged[ $property ] || array() === $merged[ $property ] ) {
				$merged[ $property ] = $value;
			}
		}
		unset( $data[ $duplicate ] );
	}
	$data[ $keep ] = $merged;
	/* Preserve graph integrity when another node references the removed ID. */
	$aliases = array();
	foreach ( $keys as $duplicate ) {
		if ( ! empty( $matches[ $duplicate ]['@id'] ) && ! empty( $merged['@id'] ) ) {
			$aliases[ $matches[ $duplicate ]['@id'] ] = $merged['@id'];
		}
	}
	$rewrite = static function ( $value ) use ( &$rewrite, $aliases ) {
		if ( ! is_array( $value ) ) { return $value; }
		foreach ( $value as $key => $item ) {
			$value[ $key ] = '@id' === $key && is_string( $item ) && isset( $aliases[ $item ] ) ? $aliases[ $item ] : ( is_array( $item ) ? $rewrite( $item ) : $item );
		}
		return $value;
	};
	$data = $rewrite( $data );

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_dedupe_current_article_nodes', 9999, 1 );


/**
 * Turn Rank Math's author archive into a ProfilePage tied to the same Person
 * node used by article bylines. Google explicitly recommends ProfilePage when an
 * Article author URL points at an internal author profile.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_rank_math_author_profile_json_ld( $data ) {
	if ( ! is_author() || ! is_array( $data ) ) {
		return $data;
	}

	$author_id = absint( get_queried_object_id() );
	if ( ! $author_id ) {
		return $data;
	}

	$profile_url = get_author_posts_url( $author_id );
	$paged       = function_exists( 'go_verge_author_archive_page_number' ) ? go_verge_author_archive_page_number() : max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	$current_url = $paged > 1 ? get_pagenum_link( $paged ) : $profile_url;
	$person      = go_verge_rank_math_person_node( $author_id );
	$person_id   = $person['@id'];
	$page_key    = null;
	$has_person  = false;

	/*
	 * One human, one node. The canonical Person always lives at the first
	 * author/profile URL, even while page 2+ is a separate paginated collection.
	 */
	$person_aliases = array( $person_id, $profile_url, untrailingslashit( $profile_url ) );

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) ) {
			continue;
		}
		$node_types = array_map( 'strval', (array) ( $node['@type'] ?? array() ) );
		$node_id    = isset( $node['@id'] ) ? (string) $node['@id'] : '';
		$is_person  = in_array( 'Person', $node_types, true ) && in_array( $node_id, $person_aliases, true );

		if ( $person_id === $node_id || $is_person ) {
			if ( $has_person ) {
				unset( $data[ $key ] );
				continue;
			}
			$data[ $key ]        = array_replace( $node, $person );
			$data[ $key ]['@id'] = $person_id;
			$has_person          = true;
		}

		if ( null === $page_key && go_verge_schema_node_matches_url( $node, $current_url, array( 'WebPage', 'CollectionPage', 'ProfilePage' ) ) ) {
			$page_key = $key;
		}
	}

	if ( ! $has_person ) {
		go_verge_schema_graph_add_unique( $data, 'goAuthorPerson', $person );
	}

	/*
	 * Google treats every paginated URL as a separate page. Only page 1 is the
	 * author's ProfilePage; page 2+ is a CollectionPage about that same Person.
	 * This prevents every archive page from competing as the identity document.
	 */
	if ( $paged > 1 ) {
		$collection = array(
			'@type'      => 'CollectionPage',
			'@id'        => trailingslashit( $current_url ) . '#webpage',
			'url'        => $current_url,
			'name'       => sprintf(
				__( 'Publicações de %1$s — página %2$d | %3$s', 'go-verge' ),
				get_the_author_meta( 'display_name', $author_id ),
				$paged,
				get_bloginfo( 'name' )
			),
			'isPartOf'   => array( '@id' => home_url( '/#website' ) ),
			'inLanguage' => get_bloginfo( 'language' ),
			'about'      => array( '@id' => $person_id ),
		);

		if ( null === $page_key ) {
			go_verge_schema_graph_add_unique( $data, 'goAuthorArchivePage', $collection );
		} else {
			$preserve = $data[ $page_key ];
			$data[ $page_key ] = array_replace( $preserve, $collection );
			$data[ $page_key ]['@type'] = 'CollectionPage';
			if ( isset( $data[ $page_key ]['mainEntity'] ) && is_array( $data[ $page_key ]['mainEntity'] ) && $person_id === ( $data[ $page_key ]['mainEntity']['@id'] ?? '' ) ) {
				unset( $data[ $page_key ]['mainEntity'] );
			}
		}
		return $data;
	}

	$profile = array(
		'@type'      => 'ProfilePage',
		'@id'        => $profile_url . '#webpage',
		'url'        => $profile_url,
		'name'       => get_the_author_meta( 'display_name', $author_id ) . ' | ' . get_bloginfo( 'name' ),
		'isPartOf'   => array( '@id' => home_url( '/#website' ) ),
		'inLanguage' => get_bloginfo( 'language' ),
		'mainEntity' => array( '@id' => $person_id ),
	);
	$bio = trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', $author_id ) ) );
	if ( $bio ) {
		$profile['description'] = $bio;
	}
	if ( function_exists( 'go_verge_schema_author_profile_dates' ) ) {
		foreach ( go_verge_schema_author_profile_dates( $author_id ) as $property => $value ) {
			$profile[ $property ] = $value;
		}
	}
	if ( function_exists( 'go_verge_schema_author_recent_activity' ) ) {
		$activity = go_verge_schema_author_recent_activity( $author_id, 5 );
		if ( $activity ) {
			$profile['hasPart'] = $activity;
		}
	}

	if ( null === $page_key ) {
		go_verge_schema_graph_add_unique( $data, 'goAuthorProfile', $profile );
	} else {
		$data[ $page_key ] = array_replace( $data[ $page_key ], $profile );
		$data[ $page_key ]['@type']      = 'ProfilePage';
		$data[ $page_key ]['mainEntity'] = array( '@id' => $person_id );
	}

	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_rank_math_author_profile_json_ld', 80, 1 );

/** Keep FAQ schema restricted to actual guides. */
function go_verge_faq_schema_only_for_guides( $faq, $post_id = 0 ) {
	$post_id = $post_id ? absint( $post_id ) : get_queried_object_id();
	return go_verge_is_guide_post( $post_id ) ? $faq : null;
}

/**
 * Clean sitemap policy: omit attachment pages and auto-generated promotion
 * records while keeping the useful archive /promocoes/ indexable.
 */
function go_verge_rank_math_sitemap_exclude_post_type( $exclude, $post_type ) {
	if ( in_array( $post_type, array( 'attachment', 'go_promotion' ), true ) ) {
		return true;
	}
	return $exclude;
}
add_filter( 'rank_math/sitemap/exclude_post_type', 'go_verge_rank_math_sitemap_exclude_post_type', 20, 2 );

function go_verge_rank_math_sitemap_exclude_taxonomy( $exclude, $taxonomy ) {
	return 'post_format' === $taxonomy ? true : $exclude;
}
add_filter( 'rank_math/sitemap/exclude_taxonomy', 'go_verge_rank_math_sitemap_exclude_taxonomy', 20, 2 );

function go_verge_core_sitemap_post_types( $post_types ) {
	unset( $post_types['attachment'], $post_types['go_promotion'] );
	return $post_types;
}
add_filter( 'wp_sitemaps_post_types', 'go_verge_core_sitemap_post_types', 20 );

function go_verge_core_sitemap_taxonomies( $taxonomies ) {
	unset( $taxonomies['post_format'] );
	return $taxonomies;
}
add_filter( 'wp_sitemaps_taxonomies', 'go_verge_core_sitemap_taxonomies', 20 );

/** Redirect thin attachment pages to their parent or the media file. */
function go_verge_redirect_attachment_pages() {
	if ( ! is_attachment() ) {
		return;
	}
	$post = get_queried_object();
	if ( $post instanceof WP_Post && $post->post_parent && 'publish' === get_post_status( $post->post_parent ) ) {
		wp_safe_redirect( get_permalink( $post->post_parent ), 301 );
		exit;
	}
	$url = wp_get_attachment_url( get_queried_object_id() );
	if ( $url ) {
		wp_safe_redirect( $url, 301 );
		exit;
	}
}
add_action( 'template_redirect', 'go_verge_redirect_attachment_pages', 2 );

/** Noindex auto-generated promotion records; the archive remains indexable. */
function go_verge_thin_content_robots( $robots ) {
	if ( is_singular( 'go_promotion' ) || is_attachment() ) {
		$robots['noindex'] = true;
		$robots['follow']  = true;
		unset( $robots['index'] );
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_thin_content_robots', 90 );

/**
 * Register key editorial meta for Gutenberg's document sidebar.
 */
function go_verge_register_editorial_meta_rest() {
	$auth = static function () { return current_user_can( 'edit_posts' ); };
	register_post_meta( 'post', '_go_post_subtitle', array(
		'type'              => 'string',
		'single'            => true,
		'show_in_rest'      => true,
		'sanitize_callback' => 'sanitize_textarea_field',
		'auth_callback'     => $auth,
	) );
	register_post_meta( 'post', 'go_linked_game_id', array(
		'type'              => 'integer',
		'single'            => true,
		'show_in_rest'      => true,
		'sanitize_callback' => 'absint',
		'auth_callback'     => $auth,
	) );
}
add_action( 'init', 'go_verge_register_editorial_meta_rest', 8 );

/**
 * Keep classic editor metadata boxes predictable and close to the author flow.
 */
function go_verge_reorder_editorial_meta_boxes() {
	global $wp_meta_boxes;
	if ( empty( $wp_meta_boxes['post'] ) || ! is_array( $wp_meta_boxes['post'] ) ) {
		return;
	}
	// The support line stays first in the main column. Game and technical sheet
	// remain high in the side column. Existing boxes are not removed.
	foreach ( array( 'go-verge-support-line', 'go-verge-review-fields', 'go-verge-critique-fields' ) as $id ) {
		foreach ( array( 'high', 'core', 'default', 'low' ) as $priority ) {
			if ( isset( $wp_meta_boxes['post']['normal'][ $priority ][ $id ] ) ) {
				$box = $wp_meta_boxes['post']['normal'][ $priority ][ $id ];
				unset( $wp_meta_boxes['post']['normal'][ $priority ][ $id ] );
				$wp_meta_boxes['post']['normal']['high'][ $id ] = $box;
			}
		}
	}
}
add_action( 'do_meta_boxes', 'go_verge_reorder_editorial_meta_boxes', 100 );

/**
 * Create trust-page drafts only when missing. Content is intentionally not
 * invented because editors will provide the approved Markdown copy.
 */
function go_verge_prepare_trust_pages() {
	if ( get_option( 'go_verge_trust_pages_prepared_v1' ) ) {
		return;
	}
	$pages = array(
		'sobre-o-overdrive'      => 'Sobre o Overdrive',
		'contato'                 => 'Contato',
		'politica-editorial'      => 'Política editorial',
	);
	foreach ( $pages as $slug => $title ) {
		$existing = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $existing ) {
			continue;
		}
		wp_insert_post( array(
			'post_type'   => 'page',
			'post_status' => 'draft',
			'post_title'  => $title,
			'post_name'   => $slug,
			'post_content'=> '',
		) );
	}
	update_option( 'go_verge_trust_pages_prepared_v1', 1, false );
}
add_action( 'admin_init', 'go_verge_prepare_trust_pages', 40 );

/** Make byline author links explicit for crawlers and assistive technology. */
function go_verge_author_link_rel( $link ) {
	if ( false !== strpos( $link, '<a ' ) && false === strpos( $link, ' rel=' ) ) {
		$link = str_replace( '<a ', '<a rel="author" ', $link );
	}
	return $link;
}
add_filter( 'the_author_posts_link', 'go_verge_author_link_rel', 20 );

/** Keep the legacy review relation in sync when Gutenberg saves sidebar meta. */
function go_verge_sync_linked_game_after_rest( $post, $request, $creating ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) {
		return;
	}
	$game_id = absint( get_post_meta( $post->ID, 'go_linked_game_id', true ) );
	if ( $game_id && 'games' === get_post_type( $game_id ) ) {
		update_post_meta( $post->ID, 'go_review_game_id', $game_id );
	} else {
		delete_post_meta( $post->ID, 'go_review_game_id' );
	}
}
add_action( 'rest_after_insert_post', 'go_verge_sync_linked_game_after_rest', 20, 3 );

/** Site Health guard for readable permalink structure without changing URLs automatically. */
function go_verge_register_permalink_health_test( $tests ) {
	$tests['direct']['go_verge_readable_permalinks'] = array(
		'label' => __( 'URLs legíveis do Overdrive', 'go-verge' ),
		'test'  => 'go_verge_permalink_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_permalink_health_test' );

function go_verge_permalink_health_test() {
	$structure = (string) get_option( 'permalink_structure' );
	$good      = '' !== trim( $structure );
	return array(
		'label'       => $good ? __( 'O site usa URLs legíveis', 'go-verge' ) : __( 'O site usa URLs numéricas', 'go-verge' ),
		'status'      => $good ? 'good' : 'recommended',
		'badge'       => array( 'label' => __( 'SEO', 'go-verge' ), 'color' => 'blue' ),
		'description' => $good
			? '<p>' . esc_html__( 'A estrutura de links permanentes está ativa.', 'go-verge' ) . '</p>'
			: '<p>' . esc_html__( 'Ative uma estrutura de links permanentes legível em Configurações > Links permanentes. O tema não altera URLs existentes automaticamente para evitar quebras e redirecionamentos em massa.', 'go-verge' ) . '</p>',
		'actions'     => $good ? '' : sprintf( '<p><a href="%s">%s</a></p>', esc_url( admin_url( 'options-permalink.php' ) ), esc_html__( 'Abrir Links permanentes', 'go-verge' ) ),
		'test'        => 'go_verge_readable_permalinks',
	);
}

/*
 * Hreflang is intentionally NOT emitted by the theme, and there is no stub
 * function for it either: an uncalled no-op reads like a disabled feature and
 * invites someone to "re-enable" it.
 *
 * Overdrive has one Portuguese version of each URL. hreflang exists to connect
 * real language/region alternates; a self-referencing pt-BR plus an x-default
 * pointing at the same URL adds no alternate and was producing audit conflicts.
 * If localized versions are added later, the translation layer must own the
 * complete reciprocal set.
 */
