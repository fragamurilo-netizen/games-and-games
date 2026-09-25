<?php
/**
 * Entertainment taxonomy architecture: Séries + Filmes with smart Streaming routing.
 *
 * Keeps Streaming as an internal source/category when it already exists, but
 * classifies its posts into the reader-facing Séries or Filmes categories.
 * Legacy Cinema e TV/Cinema URLs consolidate into Filmes, while old Série URLs
 * consolidate into Séries.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Canonical and legacy category slugs. */
function go_verge_entertainment_category_config() {
	return array(
		'parent' => array(
			'slug' => 'entretenimento',
			'name' => 'Entretenimento',
		),
		'series' => array(
			'slug'    => 'series',
			'name'    => 'Séries',
			'aliases' => array( 'serie', 'seriados', 'seriado', 'tv', 'televisao' ),
		),
		'films' => array(
			'slug'    => 'filmes',
			'name'    => 'Filmes',
			'aliases' => array( 'filme', 'cinema-e-tv', 'cinema-tv', 'cinema' ),
		),
		'streaming' => array(
			'slug' => 'streaming',
		),
	);
}

/** Resolve or create a category and optionally place it under a parent. */
function go_verge_entertainment_get_or_create_category( $slug, $name, $parent = 0 ) {
	$slug = sanitize_title( (string) $slug );
	$term = get_term_by( 'slug', $slug, 'category' );

	if ( ! ( $term instanceof WP_Term ) ) {
		$created = wp_insert_term(
			$name,
			'category',
			array(
				'slug'   => $slug,
				'parent' => absint( $parent ),
			)
		);
		if ( is_wp_error( $created ) || empty( $created['term_id'] ) ) {
			return null;
		}
		$term = get_term( (int) $created['term_id'], 'category' );
	}

	if ( $term instanceof WP_Term ) {
		$updates = array();
		if ( $name && $term->name !== $name ) {
			$updates['name'] = $name;
		}
		if ( (int) $term->parent !== (int) $parent ) {
			$updates['parent'] = absint( $parent );
		}
		if ( $updates ) {
			$updated = wp_update_term( (int) $term->term_id, 'category', $updates );
			if ( ! is_wp_error( $updated ) ) {
				$term = get_term( (int) $term->term_id, 'category' );
			}
		}
	}

	return $term instanceof WP_Term ? $term : null;
}

/** Build a normalized text corpus from post fields, tags and categories. */
function go_verge_entertainment_post_corpus( $post_id ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) {
		return '';
	}

	$parts = array(
		$post->post_title,
		$post->post_excerpt,
		wp_strip_all_tags( strip_shortcodes( $post->post_content ) ),
		(string) get_post_meta( $post_id, 'go_critique_work_name', true ),
	);

	$terms = wp_get_post_terms( $post_id, array( 'category', 'post_tag' ) );
	if ( ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			$parts[] = $term->name;
			$parts[] = $term->slug;
		}
	}

	$text = strtolower( remove_accents( implode( ' ', array_filter( array_map( 'strval', $parts ) ) ) ) );
	$text = preg_replace( '/\s+/', ' ', $text );
	return trim( (string) $text );
}

/**
 * Classify an entertainment post as series, films or unknown.
 * Explicit editorial metadata wins; wording is only a fallback.
 */
function go_verge_classify_entertainment_post( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$work_type = sanitize_key( (string) get_post_meta( $post_id, 'go_critique_work_type', true ) );
	$sheet     = sanitize_key( (string) get_post_meta( $post_id, 'go_technical_sheet_kind', true ) );

	if ( in_array( $work_type, array( 'serie' ), true ) || in_array( $sheet, array( 'serie' ), true ) ) {
		return 'series';
	}
	if ( in_array( $work_type, array( 'filme', 'documentario' ), true ) || in_array( $sheet, array( 'filme', 'documentario' ), true ) ) {
		return 'films';
	}

	$slugs = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
	$slugs = is_wp_error( $slugs ) ? array() : array_map( 'sanitize_title', $slugs );
	if ( array_intersect( $slugs, array( 'series', 'serie', 'seriados', 'seriado', 'televisao' ) ) ) {
		return 'series';
	}
	if ( array_intersect( $slugs, array( 'filmes', 'filme', 'cinema' ) ) ) {
		return 'films';
	}

	$text         = go_verge_entertainment_post_corpus( $post_id );
	$series_score = 0;
	$films_score  = 0;

	$series_patterns = array(
		'/\bserie\b/'                 => 4,
		'/\bseries\b/'                => 4,
		'/\btemporada\b/'             => 5,
		'/\bepisodio(?:s)?\b/'         => 5,
		'/\bminisserie\b/'            => 5,
		'/\bshowrunner\b/'            => 4,
		'/\bseason\s*[0-9]+\b/'       => 4,
		'/\bepisodio final\b/'        => 5,
		'/\bfinale\b/'                => 4,
		'/\brenovad[ao] para\b/'      => 4,
		'/\bnova temporada\b/'        => 5,
		'/\bserie da netflix\b/'      => 5,
		'/\bserie do prime video\b/'  => 5,
		'/\bserie da hbo\b/'          => 5,
		'/\bserie do disney\+?\b/'   => 5,
	);
	$film_patterns = array(
		'/\bfilme\b/'                    => 4,
		'/\bfilmes\b/'                   => 4,
		'/\blonga(?:-metragem)?\b/'       => 5,
		'/\bcinema\b/'                   => 4,
		'/\bbilheteria\b/'               => 5,
		'/\bestreia nos cinemas\b/'       => 5,
		'/\bem cartaz\b/'                 => 4,
		'/\bsala(?:s)? de cinema\b/'      => 4,
		'/\bmovie\b/'                    => 4,
		'/\bfilm\b/'                     => 3,
		'/\blancamento nos cinemas\b/'    => 5,
		'/\bfilme da netflix\b/'          => 5,
		'/\bfilme do prime video\b/'      => 5,
		'/\bfilme da hbo\b/'              => 5,
		'/\bfilme do disney\+?\b/'       => 5,
	);

	foreach ( $series_patterns as $pattern => $weight ) {
		if ( preg_match( $pattern, $text ) ) {
			$series_score += $weight;
		}
	}
	foreach ( $film_patterns as $pattern => $weight ) {
		if ( preg_match( $pattern, $text ) ) {
			$films_score += $weight;
		}
	}

	if ( $series_score >= 4 && $series_score >= $films_score + 2 ) {
		return 'series';
	}
	if ( $films_score >= 4 && $films_score >= $series_score + 2 ) {
		return 'films';
	}

	return '';
}

/** Return the canonical Séries or Filmes term. */
function go_verge_entertainment_canonical_term( $kind ) {
	$config = go_verge_entertainment_category_config();
	$key    = 'series' === $kind ? 'series' : ( 'films' === $kind ? 'films' : '' );
	if ( ! $key ) {
		return null;
	}
	$parent = get_term_by( 'slug', $config['parent']['slug'], 'category' );
	return go_verge_entertainment_get_or_create_category(
		$config[ $key ]['slug'],
		$config[ $key ]['name'],
		$parent instanceof WP_Term ? (int) $parent->term_id : 0
	);
}

/** Add the smart destination category without removing useful topic terms. */
function go_verge_route_entertainment_post( $post_id, $forced_kind = '' ) {
	$kind = in_array( $forced_kind, array( 'series', 'films' ), true ) ? $forced_kind : go_verge_classify_entertainment_post( $post_id );
	if ( ! $kind ) {
		return '';
	}
	$term = go_verge_entertainment_canonical_term( $kind );
	if ( $term instanceof WP_Term ) {
		wp_set_object_terms( $post_id, array( (int) $term->term_id ), 'category', true );
		return $kind;
	}
	return '';
}

/** One-time taxonomy migration and smart Streaming backfill. */
function go_verge_consolidate_entertainment_categories() {
	if ( ! taxonomy_exists( 'category' ) || ! current_user_can( 'manage_categories' ) ) {
		return;
	}

	$version = '2026-07-17-1';
	if ( $version === get_option( 'go_verge_entertainment_architecture_version' ) ) {
		return;
	}

	$config = go_verge_entertainment_category_config();
	$parent = go_verge_entertainment_get_or_create_category( $config['parent']['slug'], $config['parent']['name'], 0 );
	if ( ! ( $parent instanceof WP_Term ) ) {
		return;
	}
	$series = go_verge_entertainment_get_or_create_category( $config['series']['slug'], $config['series']['name'], (int) $parent->term_id );
	$films  = go_verge_entertainment_get_or_create_category( $config['films']['slug'], $config['films']['name'], (int) $parent->term_id );
	if ( ! ( $series instanceof WP_Term ) || ! ( $films instanceof WP_Term ) ) {
		return;
	}

	$legacy_terms = array();
	$all_aliases  = array_merge( $config['series']['aliases'], $config['films']['aliases'], array( $config['streaming']['slug'] ) );
	foreach ( array_unique( $all_aliases ) as $slug ) {
		$term = get_term_by( 'slug', $slug, 'category' );
		if ( $term instanceof WP_Term ) {
			$legacy_terms[ $slug ] = $term;
		}
	}

	$source_ids = array_map(
		static function ( $term ) {
			return (int) $term->term_id;
		},
		$legacy_terms
	);

	if ( $source_ids ) {
		$post_ids = get_posts(
			array(
				'post_type'      => 'post',
				'post_status'    => 'any',
				'posts_per_page' => -1,
				'fields'         => 'ids',
				'tax_query'      => array(
					array(
						'taxonomy' => 'category',
						'field'    => 'term_id',
						'terms'    => $source_ids,
					),
				),
			)
		);

		foreach ( array_map( 'absint', $post_ids ) as $post_id ) {
			$post_slugs = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
			$post_slugs = is_wp_error( $post_slugs ) ? array() : array_map( 'sanitize_title', $post_slugs );

			$forced = '';
			if ( array_intersect( $post_slugs, $config['series']['aliases'] ) ) {
				$forced = 'series';
			} elseif ( array_intersect( $post_slugs, array( 'filme', 'cinema' ) ) ) {
				$forced = 'films';
			}

			$routed = go_verge_route_entertainment_post( $post_id, $forced );

			/* Cinema e TV becomes Filmes, but explicit series signals are respected. */
			if ( ! $routed && array_intersect( $post_slugs, $config['films']['aliases'] ) ) {
				go_verge_route_entertainment_post( $post_id, 'films' );
			}

			$remove_ids = array();
			foreach ( array_merge( $config['series']['aliases'], $config['films']['aliases'] ) as $alias ) {
				if ( isset( $legacy_terms[ $alias ] ) ) {
					$remove_ids[] = (int) $legacy_terms[ $alias ]->term_id;
				}
			}
			if ( $remove_ids ) {
				wp_remove_object_terms( $post_id, array_values( array_unique( $remove_ids ) ), 'category' );
			}
		}
	}

	/* Streaming remains available as a topic source, but not as a main child chip. */
	if ( isset( $legacy_terms['streaming'] ) && (int) $legacy_terms['streaming']->parent === (int) $parent->term_id ) {
		wp_update_term( (int) $legacy_terms['streaming']->term_id, 'category', array( 'parent' => 0 ) );
	}

	/* Move children before deleting legacy roots. */
	foreach ( $legacy_terms as $slug => $legacy ) {
		if ( 'streaming' === $slug || in_array( $slug, array( 'series', 'filmes' ), true ) ) {
			continue;
		}
		$target_id = in_array( $slug, $config['series']['aliases'], true ) ? (int) $series->term_id : (int) $films->term_id;
		$children  = get_terms(
			array(
				'taxonomy'   => 'category',
				'hide_empty' => false,
				'parent'     => (int) $legacy->term_id,
			)
		);
		if ( ! is_wp_error( $children ) ) {
			foreach ( $children as $child ) {
				$child_text = sanitize_title( $child->slug . '-' . $child->name );
				$child_parent = preg_match( '/serie|seriado|televisao|temporada|episodio/', $child_text ) ? (int) $series->term_id : $target_id;
				wp_update_term( (int) $child->term_id, 'category', array( 'parent' => $child_parent ) );
			}
		}
		wp_delete_term( (int) $legacy->term_id, 'category' );
	}

	clean_term_cache( array( (int) $parent->term_id, (int) $series->term_id, (int) $films->term_id ), 'category' );
	if ( function_exists( 'go_verge_internal_link_bust' ) ) {
		go_verge_internal_link_bust();
	}
	update_option( 'go_verge_entertainment_architecture_version', $version, false );
}
add_action( 'admin_init', 'go_verge_consolidate_entertainment_categories', 32 );

/** Classify newly saved Streaming/Cinema/TV posts automatically. */
function go_verge_route_saved_entertainment_post( $post_id, $post, $update ) {
	unset( $update );
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	$slugs = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
	$slugs = is_wp_error( $slugs ) ? array() : array_map( 'sanitize_title', $slugs );
	$config = go_verge_entertainment_category_config();
	$relevant = array_merge(
		array( 'entretenimento', 'streaming', 'series', 'filmes' ),
		$config['series']['aliases'],
		$config['films']['aliases']
	);
	if ( ! array_intersect( $slugs, $relevant ) ) {
		return;
	}
	go_verge_route_entertainment_post( $post_id );

	/* Do not keep duplicate legacy category relationships after routing. */
	$remove_ids = array();
	foreach ( array_merge( $config['series']['aliases'], $config['films']['aliases'] ) as $alias ) {
		$legacy = get_term_by( 'slug', $alias, 'category' );
		if ( $legacy instanceof WP_Term ) {
			$remove_ids[] = (int) $legacy->term_id;
		}
	}
	if ( $remove_ids ) {
		wp_remove_object_terms( $post_id, array_values( array_unique( $remove_ids ) ), 'category' );
	}
}
add_action( 'save_post_post', 'go_verge_route_saved_entertainment_post', 50, 3 );

/** Canonical archive URL for Séries or Filmes. */
function go_verge_entertainment_canonical_url( $kind ) {
	$config = go_verge_entertainment_category_config();
	$key    = 'series' === $kind ? 'series' : 'films';
	$term   = get_term_by( 'slug', $config[ $key ]['slug'], 'category' );
	if ( $term instanceof WP_Term ) {
		$url = get_term_link( $term );
		if ( ! is_wp_error( $url ) ) {
			return $url;
		}
	}
	return home_url( 'series' === $kind ? '/series/' : '/filmes/' );
}

/** Redirect old Cinema e TV/Cinema/Série URLs to the new reader-facing hubs. */
function go_verge_redirect_legacy_entertainment_urls() {
	if ( is_admin() || wp_doing_ajax() || is_feed() ) {
		return;
	}
	$config = go_verge_entertainment_category_config();
	$requested = '';
	$category_path = trim( (string) get_query_var( 'category_name' ), '/' );
	if ( $category_path ) {
		$requested = sanitize_title( basename( $category_path ) );
	} elseif ( is_page() ) {
		$page = get_queried_object();
		$requested = $page instanceof WP_Post ? sanitize_title( $page->post_name ) : '';
	} else {
		$page_path = trim( (string) get_query_var( 'pagename' ), '/' );
		$requested = $page_path ? sanitize_title( basename( $page_path ) ) : '';
	}

	$kind = in_array( $requested, $config['series']['aliases'], true ) ? 'series' : ( in_array( $requested, $config['films']['aliases'], true ) ? 'films' : '' );
	if ( ! $kind ) {
		return;
	}

	$url  = go_verge_entertainment_canonical_url( $kind );
	$term = function_exists( 'go_verge_editorial_search_term' ) ? go_verge_editorial_search_term() : '';
	if ( $term ) {
		$url = add_query_arg( 'tema', $term, $url );
	}
	wp_safe_redirect( $url, 301, 'Overdrive entertainment category architecture' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_legacy_entertainment_urls', 3 );

/** Keep generated links canonical while old terms still exist before migration. */
function go_verge_canonical_entertainment_term_link( $url, $term, $taxonomy ) {
	if ( 'category' !== $taxonomy || ! ( $term instanceof WP_Term ) ) {
		return $url;
	}
	$config = go_verge_entertainment_category_config();
	if ( in_array( $term->slug, $config['series']['aliases'], true ) ) {
		return go_verge_entertainment_canonical_url( 'series' );
	}
	if ( in_array( $term->slug, $config['films']['aliases'], true ) ) {
		return go_verge_entertainment_canonical_url( 'films' );
	}
	return $url;
}
add_filter( 'term_link', 'go_verge_canonical_entertainment_term_link', 22, 3 );

/**
 * Rewrite legacy visible menu items without requiring a manual Appearance > Menus edit.
 * Existing canonical items win, preventing duplicate Séries/Filmes links.
 */
function go_verge_rewrite_entertainment_nav_items( $items, $args ) {
	unset( $args );
	if ( ! is_array( $items ) ) {
		return $items;
	}

	$series_url = go_verge_entertainment_canonical_url( 'series' );
	$films_url  = go_verge_entertainment_canonical_url( 'films' );
	$has_series = false;
	$has_films  = false;

	foreach ( $items as $item ) {
		if ( ! is_object( $item ) ) {
			continue;
		}
		$title = sanitize_title( wp_strip_all_tags( (string) $item->title ) );
		$path  = sanitize_title( basename( trim( (string) wp_parse_url( (string) $item->url, PHP_URL_PATH ), '/' ) ) );
		if ( in_array( $title, array( 'series', 'serie' ), true ) || in_array( $path, array( 'series', 'serie' ), true ) ) {
			$has_series = true;
		}
		if ( in_array( $title, array( 'filmes', 'filme' ), true ) || in_array( $path, array( 'filmes', 'filme' ), true ) ) {
			$has_films = true;
		}
	}

	$output = array();
	foreach ( $items as $item ) {
		if ( ! is_object( $item ) ) {
			$output[] = $item;
			continue;
		}
		$title = sanitize_title( wp_strip_all_tags( (string) $item->title ) );
		$path  = sanitize_title( basename( trim( (string) wp_parse_url( (string) $item->url, PHP_URL_PATH ), '/' ) ) );

		$is_streaming = 'streaming' === $title || 'streaming' === $path;
		$is_old_films = in_array( $title, array( 'cinema-e-tv', 'cinema-tv', 'cinema' ), true ) || in_array( $path, array( 'cinema-e-tv', 'cinema-tv', 'cinema' ), true );

		if ( $is_streaming ) {
			if ( $has_series ) {
				continue;
			}
			$item->title = 'Séries';
			$item->url   = $series_url;
			$has_series  = true;
		} elseif ( $is_old_films ) {
			if ( $has_films ) {
				continue;
			}
			$item->title = 'Filmes';
			$item->url   = $films_url;
			$has_films   = true;
		}
		$output[] = $item;
	}

	return $output;
}
add_filter( 'wp_nav_menu_objects', 'go_verge_rewrite_entertainment_nav_items', 24, 2 );
