<?php
/**
 * Editorial query and layout helpers.
 *
 * Centralizes archive lists, resilient category discovery, promotion/video
 * queries and below-article modules so templates do not grow one-off CSS or
 * duplicate query rules.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Find category IDs from aliases and, optionally, name/slug fragments.
 */
function go_verge_category_ids( $aliases = array(), $fragments = array() ) {
	$ids = array();

	foreach ( (array) $aliases as $alias ) {
		$term = get_term_by( 'slug', sanitize_title( (string) $alias ), 'category' );
		if ( $term instanceof WP_Term ) {
			$ids[] = (int) $term->term_id;
		}
	}

	$fragments = array_values( array_filter( array_map( 'sanitize_title', (array) $fragments ) ) );
	if ( ! empty( $fragments ) ) {
		$categories = get_categories(
			array(
				'hide_empty' => false,
			)
		);
		if ( ! is_wp_error( $categories ) ) {
			foreach ( $categories as $category ) {
				$haystacks = array(
					sanitize_title( remove_accents( $category->slug ) ),
					sanitize_title( remove_accents( $category->name ) ),
				);
				foreach ( $fragments as $fragment ) {
					foreach ( $haystacks as $haystack ) {
						if ( '' !== $fragment && false !== strpos( $haystack, $fragment ) ) {
							$ids[] = (int) $category->term_id;
							break 2;
						}
					}
				}
			}
		}
	}

	return array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
}

/** Existing format categories remain a fallback only for untyped legacy posts. */
function go_verge_editorial_format_aliases() {
	return array(
		'noticia' => array( 'noticias', 'noticia', 'news' ),
		'review' => array( 'reviews', 'review', 'analises', 'analises-de-jogos' ),
		'critica' => array( 'criticas', 'critica' ),
		'guia' => array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'tutoriais', 'tutorial', 'detonados' ),
		'especial' => array( 'especiais', 'especial', 'reportagens', 'materias-especiais' ),
		'lista' => array( 'listas', 'lista' ),
		'ranking' => array( 'rankings', 'ranking' ),
		'oferta' => array( 'ofertas', 'promocoes', 'promocao', 'cupons', 'jogos-gratis', 'games-gratis' ),
		'guia-de-compra' => array( 'guias-de-compra-2', 'guias-de-compra', 'guia-de-compra' ),
		'onde-assistir' => array( 'onde-assistir', 'onde-assistir-online', 'assistir-online' ),
		'final-explicado' => array( 'final-explicado', 'finais-explicados' ),
		'impressoes' => array( 'impressoes', 'primeiras-impressoes' ),
	);
}

/** Current format OR legacy category with no explicit current format. */
function go_verge_editorial_format_clause( $types, $legacy_ids = null ) {
	$map = go_verge_editorial_format_aliases();
	$types = array_values( array_intersect( array_map( 'sanitize_key', (array) $types ), array_keys( $map ) ) );
	if ( ! $types ) { return array(); }
	if ( null === $legacy_ids ) {
		$aliases = array();
		foreach ( $types as $type ) { $aliases = array_merge( $aliases, $map[ $type ] ); }
		$legacy_ids = go_verge_category_ids( $aliases );
	}
	$legacy = $legacy_ids ? array( 'taxonomy'=>'category', 'field'=>'term_id', 'terms'=>$legacy_ids, 'include_children'=>true ) : array();
	if ( ! taxonomy_exists( 'go_content_type' ) ) { return $legacy; }
	$current = array( 'taxonomy'=>'go_content_type', 'field'=>'slug', 'terms'=>$types, 'operator'=>'IN' );
	if ( ! $legacy ) { return $current; }
	return array( 'relation'=>'OR', $current, array( 'relation'=>'AND',
		array( 'taxonomy'=>'go_content_type', 'operator'=>'NOT EXISTS' ), $legacy ) );
}

/** Request-local desk map, including legacy categories already recognized by the resolver. */
function go_verge_editorial_desk_category_ids( $desk ) {
	if ( function_exists('go_verge_desk_category_ids') ) { return go_verge_desk_category_ids($desk); }
	static $map = null;
	if ( null === $map ) {
		$map = array( 'games'=>array(), 'entretenimento'=>array(), 'tecnologia'=>array(), 'ofertas'=>array() );
		$terms = get_categories( array( 'hide_empty'=>false ) );
		if ( ! is_wp_error( $terms ) ) {
			foreach ( $terms as $term ) {
				$owner = function_exists( 'go_verge_category_editorial_desk' ) ? go_verge_category_editorial_desk( $term ) : ( isset( $map[ $term->slug ] ) ? $term->slug : '' );
				if ( isset( $map[ $owner ] ) ) { $map[ $owner ][] = (int) $term->term_id; }
			}
		}
	}
	return $map[ $desk ] ?? array();
}

/** Small unpaginated recommendation query: one bounded pool, no global fallback.
 * Published legacy posts remain eligible without a content-type backfill.
 * The complete chronological archives keep their own paginated queries. */
function go_verge_editorial_distribution_query( $desk, $types, $limit = 4, $extra = array() ) {
	$limit = max( 1, min( 24, absint( $limit ) ) );
	$tax = array( 'relation'=>'AND' );
	if ( $desk ) {
		$ids = go_verge_editorial_desk_category_ids( $desk );
		if ( ! $ids ) { return new WP_Query( array( 'post_type'=>'post', 'post__in'=>array(0), 'posts_per_page'=>1, 'no_found_rows'=>true ) ); }
		$tax[] = array( 'taxonomy'=>'category', 'field'=>'term_id', 'terms'=>$ids, 'include_children'=>false );
	}
	if ( $types ) {
		$format = go_verge_editorial_format_clause( $types );
		if ( ! $format ) { return new WP_Query( array( 'post_type'=>'post', 'post__in'=>array(0), 'posts_per_page'=>1, 'no_found_rows'=>true ) ); }
		$tax[] = $format;
	}
	if ( ! $desk && ! $types ) { return new WP_Query( array( 'post_type'=>'post', 'post__in'=>array(0), 'posts_per_page'=>1, 'no_found_rows'=>true ) ); }
	$args = wp_parse_args( $extra, array( 'post_type'=>'post', 'post_status'=>'publish',
		'ignore_sticky_posts'=>true, 'no_found_rows'=>true, 'orderby'=>array('date'=>'DESC','ID'=>'DESC') ) );
	if ( ! empty( $args['tax_query'] ) ) { $tax[] = $args['tax_query']; }
	$args['tax_query'] = $tax;
	$args['posts_per_page'] = min( 96, max( 24, $limit * 4 ) );
	$args['no_found_rows'] = true;
	$query = new WP_Query( $args );
	$selected = array();
	foreach ( $query->posts as $post ) {
		if ( ! ( $post instanceof WP_Post ) ) { continue; }
		if ( $desk && function_exists( 'go_verge_post_editorial_desk' ) && $desk !== go_verge_post_editorial_desk( $post->ID ) ) { continue; }
		if ( function_exists( 'go_verge_promotion_has_expired' ) && go_verge_promotion_has_expired( $post->ID ) ) { continue; }
		/* Conflicting explicit formats are not silently presented as a single type. */
		$assigned = taxonomy_exists( 'go_content_type' ) ? get_the_terms( $post->ID, 'go_content_type' ) : false;
		if ( $types && $assigned && ! is_wp_error( $assigned ) && function_exists( 'go_verge_v7_post_content_type' ) && ! in_array( go_verge_v7_post_content_type( $post->ID ), $types, true ) ) { continue; }
		$selected[] = $post;
		if ( count( $selected ) >= $limit ) { break; }
	}
	$query->posts = $selected;
	$query->post_count = count( $selected );
	$query->found_posts = count( $selected );
	$query->max_num_pages = $selected ? 1 : 0;
	$query->rewind_posts();
	return $query;
}

/**
 * Search term used inside editorial archives and Page-based hubs.
 */
function go_verge_editorial_search_term() {
	$raw = isset( $_GET['tema'] ) ? wp_unslash( $_GET['tema'] ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$raw = is_string( $raw ) ? $raw : '';
	return mb_substr( sanitize_text_field( $raw ), 0, 100 );
}

/**
 * Resolve the editorial accent key for a queried surface.
 *
 * One product, one restrained palette: each editoria owns a single accent that
 * appears only on the H1 signature, the active filter, hovers and small
 * selected states. Games/entertainment/technology already ship as visual
 * "zones"; this adds Séries, Filmes, Reviews, Críticas and Dicas e Guias so a
 * category archive gets the same colour without a full reskin. Returns '' when
 * the surface has no editorial identity (tags, generic archives, singles).
 *
 * @param WP_Term|WP_Post|null $object Optional queried object. Defaults to the current one.
 * @return string One of games|entertainment|technology|series|filmes|reviews|criticas|guides, or ''.
 */
function go_verge_editorial_accent_key( $object = null ) {
	if ( null === $object ) {
		$object = ! empty( $GLOBALS['go_verge_forced_editorial_term'] ) && $GLOBALS['go_verge_forced_editorial_term'] instanceof WP_Term
			? $GLOBALS['go_verge_forced_editorial_term']
			: get_queried_object();
	}

	$slugs = array();
	if ( $object instanceof WP_Term ) {
		$slugs[] = $object->slug;
		$slugs[] = $object->name;
		foreach ( get_ancestors( $object->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
			$ancestor = get_term( $ancestor_id, 'category' );
			if ( $ancestor instanceof WP_Term ) {
				$slugs[] = $ancestor->slug;
			}
		}
	} elseif ( $object instanceof WP_Post ) {
		$slugs[] = $object->post_name;
		$template = basename( (string) get_page_template_slug( $object->ID ), '.php' );
		if ( '' !== $template ) {
			$slugs[] = $template;
		}
	}

	$slugs = array_filter( array_map( static function ( $value ) {
		return sanitize_title( remove_accents( (string) $value ) );
	}, $slugs ) );
	if ( empty( $slugs ) ) {
		return '';
	}
	$haystack = ' ' . implode( ' ', $slugs ) . ' ';

	// Most specific first so /reviews/ never resolves to games, and Séries wins
	// over the broader Entretenimento pillar.
	$map = array(
		'reviews'       => array( 'reviews', 'review', 'analises', 'analise', 'analises-de-jogos', 'page-reviews' ),
		'criticas'      => array( 'criticas', 'critica', 'page-criticas' ),
		'guides'        => array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'dica', 'tutoriais', 'tutorial', 'detonados', 'guias-e-tutoriais', 'page-dicas-e-guias', 'page-guias' ),
		'series'        => array( 'series', 'serie', 'streaming', 'temporadas' ),
		'filmes'        => array( 'filmes', 'filme', 'cinema', 'cinema-e-tv', 'estreias' ),
		'entertainment' => array( 'entretenimento', 'animes', 'anime', 'cultura-pop', 'novelas', 'page-entretenimento' ),
		'technology'    => array( 'tecnologia', 'tech', 'ciencia-e-tecnologia', 'page-tecnologia' ),
		'games'         => array( 'games', 'jogos', 'analises-de-jogos' ),
	);

	foreach ( $map as $key => $aliases ) {
		foreach ( $aliases as $alias ) {
			if ( false !== strpos( $haystack, ' ' . $alias . ' ' ) || false !== strpos( $haystack, $alias ) ) {
				return $key;
			}
		}
	}

	return '';
}

/**
 * Collapse specific destinations into the three visual editorial families.
 *
 * Reviews and guides inherit Games; critiques, series and films inherit
 * Entertainment. Keeping this separate from the accent key preserves the
 * destination-specific sidebar plans while enforcing one colour per editoria.
 */
function go_verge_editorial_color_group( $accent_key ) {
	$accent_key = sanitize_key( (string) $accent_key );
	if ( in_array( $accent_key, array( 'games', 'reviews', 'guides' ), true ) ) {
		return 'games';
	}
	if ( in_array( $accent_key, array( 'entertainment', 'series', 'filmes', 'criticas' ), true ) ) {
		return 'entertainment';
	}
	if ( 'technology' === $accent_key ) {
		return 'technology';
	}
	return '';
}

/** Platform families used only by the Reviews archive filters. */
function go_verge_review_platform_definitions() {
	return array(
		'playstation' => array( 'label' => 'PlayStation', 'aliases' => array( 'playstation', 'ps5', 'ps4', 'playstation-5', 'playstation-4', 'ps5-pro', 'ps-vr2', 'psvr2' ) ),
		'xbox'        => array( 'label' => 'Xbox', 'aliases' => array( 'xbox', 'xbox-one', 'xbox-series', 'xbox-series-x-s', 'xbox-series-x', 'xbox-series-s', 'game-pass', 'xbox-game-pass' ) ),
		'nintendo'    => array( 'label' => 'Nintendo', 'aliases' => array( 'nintendo', 'switch', 'nintendo-switch', 'switch-2', 'nintendo-switch-2' ) ),
		'pc'          => array( 'label' => 'PC', 'aliases' => array( 'pc', 'pc-gamer', 'computador', 'windows', 'steam', 'epic-games', 'gog' ) ),
		'mobile'      => array( 'label' => 'Mobile', 'aliases' => array( 'mobile', 'mobile-gaming', 'celular', 'android', 'ios', 'iphone', 'ipad' ) ),
	);
}

/** Resolve all real category IDs belonging to one review platform family. */
function go_verge_review_platform_term_ids( $platform_key ) {
	$definitions = go_verge_review_platform_definitions();
	$platform_key = sanitize_key( (string) $platform_key );
	if ( ! isset( $definitions[ $platform_key ] ) ) {
		return array();
	}

	$ids = go_verge_category_ids( $definitions[ $platform_key ]['aliases'] );
	foreach ( $ids as $term_id ) {
		$children = get_term_children( (int) $term_id, 'category' );
		if ( ! is_wp_error( $children ) ) {
			$ids = array_merge( $ids, array_map( 'absint', $children ) );
		}
	}
	return array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
}

/** Current Reviews platform filter. */
function go_verge_review_platform_filter() {
	$platform = isset( $_GET['plataforma'] ) ? sanitize_key( wp_unslash( $_GET['plataforma'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	return isset( go_verge_review_platform_definitions()[ $platform ] ) ? $platform : '';
}

/** Render platform tabs on Reviews instead of category/subeditoria tabs. */
function go_verge_review_platform_chips( $base_url = '' ) {
	if ( '' === $base_url ) {
		$object = get_queried_object();
		if ( $object instanceof WP_Term ) {
			$base_url = get_term_link( $object );
		} elseif ( $object instanceof WP_Post ) {
			$base_url = get_permalink( $object );
		}
	}
	if ( is_wp_error( $base_url ) || ! $base_url ) {
		$base_url = home_url( '/reviews/' );
	}

	$active = go_verge_review_platform_filter();
	$items  = array();
	foreach ( go_verge_review_platform_definitions() as $key => $definition ) {
		if ( go_verge_review_platform_term_ids( $key ) ) {
			$items[ $key ] = $definition['label'];
		}
	}
	if ( empty( $items ) ) {
		return;
	}
	?>
	<nav class="go-chips go-chips--filter go-chips--platform" data-go-editorial-filters aria-label="<?php esc_attr_e( 'Filtrar reviews por plataforma', 'go-verge' ); ?>">
		<a href="<?php echo esc_url( remove_query_arg( 'plataforma', $base_url ) ); ?>" data-go-review-platform-filter=""<?php echo '' === $active ? ' class="is-active" aria-current="page"' : ''; ?>><?php esc_html_e( 'Todas', 'go-verge' ); ?></a>
		<?php foreach ( $items as $key => $label ) : ?>
			<a href="<?php echo esc_url( add_query_arg( 'plataforma', $key, $base_url ) ); ?>" data-go-review-platform-filter="<?php echo esc_attr( $key ); ?>"<?php echo $active === $key ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( $label ); ?></a>
		<?php endforeach; ?>
	</nav>
	<?php
}

/**
 * Render category access mini-hubs inside editorial landing pages.
 *
 * Each definition expects:
 * - label: visible category name;
 * - slugs: exact category slug aliases, checked in order;
 * - accent: optional visual key.
 *
 * @param array  $definitions Section definitions.
 * @param string $context     Optional context class.
 */
function go_verge_render_category_access_sections( $definitions, $context = '', $base_url = '' ) {
	$items   = array();
	$context = sanitize_html_class( (string) $context );

	if ( '' === $base_url ) {
		if ( is_page() ) {
			$base_url = get_permalink( get_queried_object_id() );
		} elseif ( is_post_type_archive( 'go_promotion' ) ) {
			$base_url = get_post_type_archive_link( 'go_promotion' );
		}
	}
	if ( is_wp_error( $base_url ) || ! $base_url ) {
		$base_url = home_url( '/' );
	}
	$base_url = remove_query_arg( array( 'subcategoria', 'paged', 'page' ), $base_url );

	foreach ( (array) $definitions as $definition ) {
		$label  = isset( $definition['label'] ) ? sanitize_text_field( $definition['label'] ) : '';
		$slugs  = isset( $definition['slugs'] ) ? (array) $definition['slugs'] : array();
		$accent = isset( $definition['accent'] ) ? sanitize_html_class( $definition['accent'] ) : 'default';
		$term   = null;

		foreach ( $slugs as $slug ) {
			$candidate = get_term_by(
				'slug',
				sanitize_title( remove_accents( (string) $slug ) ),
				'category'
			);
			if ( $candidate instanceof WP_Term ) {
				$term = $candidate;
				break;
			}
		}

		if ( ! $term instanceof WP_Term ) {
			continue;
		}

		$query = new WP_Query(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => 4,
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'tax_query'           => array(
					array(
						'taxonomy'         => 'category',
						'field'            => 'term_id',
						'terms'            => array( (int) $term->term_id ),
						'include_children' => true,
					),
				),
				'orderby'             => array(
					'date' => 'DESC',
					'ID'   => 'DESC',
				),
			)
		);

		$posts         = array_values(
			array_filter(
				(array) $query->posts,
				static function ( $post ) {
					return $post instanceof WP_Post;
				}
			)
		);
		$feature       = null;
		$feature_image = 0;

		foreach ( $posts as $candidate ) {
			$image_id = absint( get_post_thumbnail_id( $candidate->ID ) );
			if ( $image_id ) {
				$feature       = $candidate;
				$feature_image = $image_id;
				break;
			}
		}

		if ( ! $feature && $posts ) {
			$feature = $posts[0];
		}

		$items[] = array(
			'label'         => $label ? $label : $term->name,
			'term'          => $term,
			'accent'        => $accent,
			'posts'         => $posts,
			'feature'       => $feature,
			'feature_image' => $feature_image,
			'filter_url'    => add_query_arg( 'subcategoria', $term->slug, $base_url ),
		);
	}

	if ( empty( $items ) ) {
		return;
	}

	$classes = array( 'go-category-access' );
	if ( $context ) {
		$classes[] = 'go-category-access--' . $context;
	}
	if ( 1 === count( $items ) ) {
		$classes[] = 'go-category-access--single';
	}
	?>
	<div class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>">
		<?php foreach ( $items as $item ) : ?>
			<?php
			$term_url = get_term_link( $item['term'] );
			if ( is_wp_error( $term_url ) ) {
				continue;
			}
			$feature_id = $item['feature'] instanceof WP_Post ? absint( $item['feature']->ID ) : 0;
			$list_posts = array_values(
				array_filter(
					$item['posts'],
					static function ( $post ) use ( $feature_id ) {
						return $post instanceof WP_Post && $post->ID !== $feature_id;
					}
				)
			);
			$list_posts = array_slice( $list_posts, 0, 3 );
			?>
			<section class="go-category-access__section go-category-access__section--<?php echo esc_attr( $item['accent'] ); ?>">
				<div class="go-category-access__head">
					<h2 class="go-category-access__title">
						<a href="<?php echo esc_url( $item['filter_url'] ); ?>" data-go-category-access-filter="<?php echo esc_attr( $item['term']->slug ); ?>"><?php echo esc_html( $item['label'] ); ?></a>
					</h2>
					<a class="go-category-access__all" href="<?php echo esc_url( $item['filter_url'] ); ?>" data-go-category-access-filter="<?php echo esc_attr( $item['term']->slug ); ?>"><?php esc_html_e( 'Ver tudo', 'go-verge' ); ?></a>
				</div>

				<?php if ( $feature_id ) : ?>
					<a class="go-category-access__feature<?php echo $item['feature_image'] ? ' has-image' : ' no-image'; ?>" href="<?php echo esc_url( get_permalink( $feature_id ) ); ?>">
						<?php if ( $item['feature_image'] ) : ?>
							<span class="go-category-access__media" aria-hidden="true">
								<?php
								echo wp_get_attachment_image(
									$item['feature_image'],
									'go_card',
									false,
									array(
										'loading'  => 'lazy',
										'decoding' => 'async',
										'sizes'    => '(max-width: 700px) calc(100vw - 32px), (max-width: 1100px) 46vw, 520px',
									)
								); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
								?>
							</span>
						<?php endif; ?>
						<span class="go-category-access__veil" aria-hidden="true"></span>
						<span class="go-category-access__feature-copy">
							<span class="go-category-access__eyebrow"><?php echo esc_html( $item['label'] ); ?></span>
							<span class="go-category-access__feature-title"><?php echo esc_html( get_the_title( $feature_id ) ); ?></span>
						</span>
					</a>
				<?php else : ?>
					<a class="go-category-access__feature no-image" href="<?php echo esc_url( $term_url ); ?>">
						<span class="go-category-access__veil" aria-hidden="true"></span>
						<span class="go-category-access__feature-copy">
							<span class="go-category-access__eyebrow"><?php echo esc_html( $item['label'] ); ?></span>
							<span class="go-category-access__feature-title"><?php esc_html_e( 'Ver matérias desta categoria', 'go-verge' ); ?></span>
						</span>
					</a>
				<?php endif; ?>

				<?php if ( $list_posts ) : ?>
					<div class="go-category-access__list">
						<?php foreach ( $list_posts as $list_post ) : ?>
							<a href="<?php echo esc_url( get_permalink( $list_post->ID ) ); ?>">
								<span><?php echo esc_html( get_the_title( $list_post->ID ) ); ?></span>
							</a>
						<?php endforeach; ?>
					</div>
				<?php endif; ?>
			</section>
		<?php endforeach; ?>
	</div>
	<?php
	wp_reset_postdata();
}

/**
 * Render a compact archive search without explanatory copy.
 *
 * @param string $action Optional destination URL. Defaults to the current URL.
 */
function go_verge_render_editorial_search( $action = '' ) {
	static $instance = 0;
	++$instance;

	if ( '' === $action ) {
		$object = get_queried_object();
		if ( $object instanceof WP_Term ) {
			$action = get_term_link( $object );
		} elseif ( $object instanceof WP_Post ) {
			$action = get_permalink( $object );
		}
	}
	if ( is_wp_error( $action ) || ! $action ) {
		$action = home_url( '/' );
	}

	$input_id = 'go-editorial-search-' . $instance;
	?>
	<form class="go-editorial-search" method="get" action="<?php echo esc_url( $action ); ?>" role="search">
		<label class="screen-reader-text" for="<?php echo esc_attr( $input_id ); ?>"><?php esc_html_e( 'Pesquisar', 'go-verge' ); ?></label>
		<input id="<?php echo esc_attr( $input_id ); ?>" type="search" name="tema" value="<?php echo esc_attr( go_verge_editorial_search_term() ); ?>" placeholder="<?php esc_attr_e( 'Pesquisar', 'go-verge' ); ?>" autocomplete="off">
		<button type="submit" aria-label="<?php esc_attr_e( 'Pesquisar', 'go-verge' ); ?>">
			<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><circle cx="11" cy="11" r="6.5"></circle><path d="m16 16 4 4"></path></svg>
			<span class="screen-reader-text"><?php esc_html_e( 'Pesquisar', 'go-verge' ); ?></span>
		</button>
	</form>
	<?php
}

/** Apply the archive search to real category queries. */
function go_verge_filter_editorial_category_search( $query ) {
	if ( is_admin() || ! $query instanceof WP_Query || ! $query->is_main_query() || ! $query->is_category() ) {
		return;
	}
	$term = go_verge_editorial_search_term();
	if ( '' !== $term ) {
		$query->set( 's', $term );
	}

	$queried_term = $query->get_queried_object();
	if ( $queried_term instanceof WP_Term && 'reviews' === go_verge_editorial_accent_key( $queried_term ) ) {
		$platform_ids = go_verge_review_platform_term_ids( go_verge_review_platform_filter() );
		if ( $platform_ids ) {
			$query->set( 'tax_query', array( array(
				'taxonomy'         => 'category',
				'field'            => 'term_id',
				'terms'            => $platform_ids,
				'include_children' => true,
			) ) );
		}
	}
}
add_action( 'pre_get_posts', 'go_verge_filter_editorial_category_search', 12 );

/**
 * Query editorial posts by resilient category matching.
 */
function go_verge_query_editorial_posts( $aliases, $limit = 6, $extra = array(), $fragments = array() ) {
	$term_ids = go_verge_category_ids( $aliases, $fragments );
	$types = array();
	foreach ( go_verge_editorial_format_aliases() as $type => $legacy_aliases ) {
		if ( array_intersect( (array) $aliases, $legacy_aliases ) ) { $types[] = $type; }
	}
	$format_clause = $types ? go_verge_editorial_format_clause( $types, $term_ids ) : array();
	if ( empty( $term_ids ) && ! $format_clause ) {
		return new WP_Query(
			array(
				'post_type'      => 'post',
				'post__in'       => array( 0 ),
				'posts_per_page' => 1,
				'no_found_rows'  => true,
			)
		);
	}

	$args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => max( 1, (int) $limit ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'tax_query'           => array(
			array(
				'taxonomy'         => 'category',
				'field'            => 'term_id',
				'terms'            => $term_ids,
				'include_children' => true,
			),
		),
	);
	if ( $format_clause ) { $args['tax_query'] = array( $format_clause ); }

	return new WP_Query( wp_parse_args( $extra, $args ) );
}

/**
 * Promotion articles. These are regular posts, never go_promotion records.
 */
function go_verge_query_promotion_articles( $limit = 6, $extra = array() ) {
	return go_verge_query_editorial_posts(
		array( 'promocoes', 'promocao', 'ofertas', 'cupons', 'jogos-gratis', 'games-gratis' ),
		$limit,
		$extra,
		array( 'promoc', 'oferta', 'cupom', 'gratis', 'gratuito' )
	);
}

/**
 * Video articles. Category matching is preferred; post-format video is the
 * fallback so the homepage module does not disappear on a different taxonomy.
 */
function go_verge_query_video_articles( $limit = 4, $extra = array() ) {
	$query = go_verge_query_editorial_posts(
		array( 'videos', 'video', 'trailers', 'trailer', 'gameplay', 'galerias' ),
		$limit,
		$extra,
		array( 'video', 'trailer', 'gameplay' )
	);

	if ( $query->have_posts() ) {
		return $query;
	}

	$args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => max( 1, (int) $limit ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'tax_query'           => array(
			array(
				'taxonomy' => 'post_format',
				'field'    => 'slug',
				'terms'    => array( 'post-format-video' ),
			),
		),
	);
	$format_query = new WP_Query( wp_parse_args( $extra, $args ) );
	if ( $format_query->have_posts() ) {
		return $format_query;
	}

	// Gamxo stores a YouTube URL in this legacy meta key. Keeping this final
	// fallback makes the module survive imports where the post format was lost.
	$meta_args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => max( 1, (int) $limit ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'meta_query'          => array(
			array(
				'key'     => 'gamxo_youtube_link',
				'value'   => '',
				'compare' => '!=',
			),
		),
	);

	return new WP_Query( wp_parse_args( $extra, $meta_args ) );
}

/**
 * Render a WordPress Page as a real editorial hub.
 *
 * Several legacy installations still contain empty Pages such as
 * /dicas-e-guias/, /entretenimento/ and /tecnologia/. This renderer keeps
 * those URLs useful by querying their real category trees and composing the
 * same feature + latest-list pattern used by category archives.
 *
 * @param string $title        Page title.
 * @param array  $aliases      Exact category slug aliases.
 * @param array  $fragments    Resilient category name/slug fragments.
 * @param string $latest_title Heading for the latest list.
 * @param string $editorial_zone Optional visual zone key: games, entertainment or technology.
 */
/**
 * Real filters shown inside the three parent editorial hubs.
 * Links remain on the parent page and update only the latest-publications feed.
 */
function go_verge_parent_hub_filter_definitions( $editorial_zone ) {
	$definitions = array(
		'entertainment' => array(
			array( 'label' => __( 'Notícias de entretenimento', 'go-verge' ), 'aliases' => array( 'noticias-de-entretenimento', 'noticias-entretenimento', 'entretenimento-noticias' ) ),
			array( 'label' => __( 'Séries', 'go-verge' ), 'aliases' => array( 'series', 'serie' ) ),
			array( 'label' => __( 'Filmes', 'go-verge' ), 'aliases' => array( 'filmes', 'filme', 'cinema' ) ),
			array( 'label' => __( 'Onde assistir', 'go-verge' ), 'aliases' => array( 'onde-assistir', 'onde-assistir-online', 'assistir-online' ), 'taxonomies' => array( 'post_tag', 'category' ) ),
			array( 'label' => __( 'Final explicado', 'go-verge' ), 'aliases' => array( 'final-explicado', 'finais-explicados', 'final-explicado-de-filmes-e-series' ), 'taxonomies' => array( 'post_tag', 'category' ) ),
			array( 'label' => __( 'Animes', 'go-verge' ), 'aliases' => array( 'animes', 'anime' ) ),
			array( 'label' => __( 'Mangás e Quadrinhos', 'go-verge' ), 'aliases' => array( 'mangas-e-quadrinhos', 'manga-e-quadrinhos', 'mangas', 'manga', 'quadrinhos', 'hqs', 'comics' ) ),
			array( 'label' => __( 'Críticas', 'go-verge' ), 'aliases' => array( 'criticas', 'critica' ) ),
		),
		'technology' => array(
			array( 'label' => __( 'Hardware', 'go-verge' ), 'aliases' => array( 'hardware' ) ),
			array( 'label' => __( 'Celulares', 'go-verge' ), 'aliases' => array( 'celulares', 'smartphones', 'mobile' ) ),
			array( 'label' => __( 'Inteligência artificial', 'go-verge' ), 'aliases' => array( 'inteligencia-artificial', 'ia', 'artificial-intelligence' ) ),
			array( 'label' => __( 'Computadores', 'go-verge' ), 'aliases' => array( 'computadores', 'notebooks', 'pc' ) ),
			array( 'label' => __( 'Apps', 'go-verge' ), 'aliases' => array( 'apps', 'aplicativos' ) ),
		),
	);
	return isset( $definitions[ $editorial_zone ] ) ? $definitions[ $editorial_zone ] : array();
}

/** Resolve only filters backed by a real non-empty category. */
function go_verge_parent_hub_filters( $editorial_zone, $base_url, $root_aliases = array() ) {
	$items = array();
	$used  = array();

	// Keep the editorially preferred destinations first.
	foreach ( go_verge_parent_hub_filter_definitions( $editorial_zone ) as $definition ) {
		$term = null;
		$taxonomies = ! empty( $definition['taxonomies'] ) ? (array) $definition['taxonomies'] : array( 'category' );
		foreach ( $taxonomies as $taxonomy ) {
			foreach ( $definition['aliases'] as $alias ) {
				$candidate = get_term_by( 'slug', sanitize_title( $alias ), $taxonomy );
				if ( $candidate instanceof WP_Term && (int) $candidate->count > 0 ) {
					$term = $candidate;
					break 2;
				}
			}
		}
		if ( ! $term instanceof WP_Term || isset( $used[ $term->term_id ] ) ) {
			continue;
		}
		$used[ $term->term_id ] = true;
		$archive_url = 'category' === $term->taxonomy ? get_term_link( $term ) : '';
		$items[] = array(
			'label'       => $definition['label'],
			'slug'        => $term->slug,
			'term'        => $term,
			'taxonomy'    => $term->taxonomy,
			'url'         => add_query_arg( 'editoria', $term->slug, $base_url ),
			'archive_url' => is_wp_error( $archive_url ) ? '' : esc_url_raw( $archive_url ),
		);
	}

	// Then append every real, non-empty child of the parent editoria. This keeps
	// the filter complete when new subeditorias are created in WordPress, without
	// inventing empty destinations or requiring a code change.
	$root = null;
	foreach ( (array) $root_aliases as $root_alias ) {
		$candidate = get_category_by_slug( sanitize_title( (string) $root_alias ) );
		if ( $candidate instanceof WP_Term ) {
			$root = $candidate;
			break;
		}
	}
	if ( $root instanceof WP_Term ) {
		$children = get_terms(
			array(
				'taxonomy'   => 'category',
				'parent'     => (int) $root->term_id,
				'hide_empty' => true,
				'orderby'    => 'name',
				'order'      => 'ASC',
			)
		);
		if ( ! is_wp_error( $children ) ) {
			foreach ( $children as $child ) {
				// Streaming remains a source category, but is intentionally not a
				// primary Entertainment filter. Discovery is split into the more
				// useful Onde assistir and Final explicado destinations above.
				if ( 'entertainment' === $editorial_zone && 'streaming' === sanitize_title( $child->slug ) ) {
					continue;
				}
				if ( isset( $used[ $child->term_id ] ) ) {
					continue;
				}
				$used[ $child->term_id ] = true;
				$archive_url = get_term_link( $child );
				$items[] = array(
					'label'       => $child->name,
					'slug'        => $child->slug,
					'term'        => $child,
					'taxonomy'    => 'category',
					'url'         => add_query_arg( 'editoria', $child->slug, $base_url ),
					'archive_url' => is_wp_error( $archive_url ) ? '' : esc_url_raw( $archive_url ),
				);
			}
		}
	}

	return $items;
}

/**
 * Render a WordPress Page as a real editorial parent hub.
 *
 * The hero always represents the parent editoria. Its filter tabs use query
 * arguments on the same URL and AJAX-replace only the chronological feed;
 * category links reached from articles continue opening their own archives.
 */
function go_verge_render_editorial_hub_page( $title, $aliases, $fragments = array(), $latest_title = '', $editorial_zone = '', $access_sections = array() ) {
	$paged         = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
	$desk_context  = go_verge_desk_format_context();
	if ( $desk_context ) { $paged = $desk_context['page']; }
	$search_term   = go_verge_editorial_search_term();
	$editorial_zone = sanitize_key( (string) $editorial_zone );
	if ( ! in_array( $editorial_zone, array( 'games', 'entertainment', 'technology' ), true ) ) {
		$editorial_zone = '';
	}
	if ( '' === $latest_title ) {
		$latest_title = __( 'Últimas publicações', 'go-verge' );
	}

	$page_object = get_queried_object();
	if ( 'games' === $editorial_zone && is_post_type_archive( 'games' ) ) {
		$base_url = get_post_type_archive_link( 'games' );
		if ( ! $base_url ) {
			$base_url = home_url( '/games/' );
		}
	} else {
		$base_url = $page_object instanceof WP_Post ? get_permalink( $page_object ) : home_url( '/' );
	}
	$filters = $editorial_zone ? go_verge_parent_hub_filters( $editorial_zone, $base_url, $aliases ) : array();

	$access_requested = isset( $_GET['subcategoria'] )
		? sanitize_title( wp_unslash( $_GET['subcategoria'] ) )
		: ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$access_selected = null;
	if ( $access_requested && $access_sections ) {
		foreach ( (array) $access_sections as $access_definition ) {
			foreach ( (array) ( $access_definition['slugs'] ?? array() ) as $access_slug ) {
				if ( $access_requested !== sanitize_title( remove_accents( (string) $access_slug ) ) ) {
					continue;
				}
				$candidate = get_term_by( 'slug', $access_requested, 'category' );
				if ( $candidate instanceof WP_Term ) {
					$access_selected = $candidate;
				}
				break 2;
			}
		}
	}
	$direct_filter_term = null;
	if ( ! $editorial_zone ) {
		foreach ( (array) $aliases as $alias ) {
			$candidate = get_category_by_slug( sanitize_title( (string) $alias ) );
			if ( $candidate instanceof WP_Term ) {
				$direct_filter_term = $candidate;
				break;
			}
		}
	}
	$requested   = isset( $_GET['editoria'] ) ? sanitize_title( wp_unslash( $_GET['editoria'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$selected    = null;
	foreach ( $filters as $filter_item ) {
		if ( $requested && $requested === $filter_item['slug'] ) {
			$selected = $filter_item['term'];
			break;
		}
	}

	$hero_query = go_verge_query_editorial_posts(
		$aliases,
		5,
		array(
			'posts_per_page' => 5,
			'no_found_rows'  => true,
		),
		$fragments
	);
	$hero_posts = array_values( array_filter( (array) $hero_query->posts, static function ( $post ) { return $post instanceof WP_Post; } ) );
	$hero_ids   = array_map( 'absint', wp_list_pluck( $hero_posts, 'ID' ) );

	$latest_extra = array(
		'posts_per_page' => 10,
		'paged'          => $paged,
		'no_found_rows'  => false,
		's'              => $search_term,
	);
	if ( $access_selected instanceof WP_Term ) {
		$latest_extra['tax_query'] = array(
			array(
				'taxonomy'         => 'category',
				'field'            => 'term_id',
				'terms'            => array( (int) $access_selected->term_id ),
				'include_children' => true,
			),
		);
	} elseif ( $selected instanceof WP_Term ) {
		$root_ids = go_verge_category_ids( $aliases, $fragments );
		$tax_query = array(
			array(
				'taxonomy'         => $selected->taxonomy,
				'field'            => 'term_id',
				'terms'            => array( (int) $selected->term_id ),
				'include_children' => 'category' === $selected->taxonomy,
			),
		);
		if ( $root_ids ) {
			array_unshift(
				$tax_query,
				array(
					'taxonomy'         => 'category',
					'field'            => 'term_id',
					'terms'            => $root_ids,
					'include_children' => true,
				)
			);
			$tax_query['relation'] = 'AND';
		}
		$latest_extra['tax_query'] = $tax_query;
	}
	$latest_query = go_verge_query_editorial_posts( $aliases, 10, $latest_extra, $fragments );
	if ( $desk_context ) { $latest_query = go_verge_desk_format_query(); }
	if ( function_exists( 'go_verge_render_empty_pagination_404' ) && go_verge_render_empty_pagination_404( $latest_query, $paged ) ) {
		return;
	}
	$latest_ids   = array_map( 'absint', wp_list_pluck( $latest_query->posts, 'ID' ) );
	$sidebar      = $editorial_zone && function_exists( 'go_verge_archive_sidebar_modules' )
		? go_verge_archive_sidebar_modules( $editorial_zone, array_merge( $hero_ids, $latest_ids ) )
		: array();

	$main_classes = array( 'go-main' );
	if ( $editorial_zone ) {
		$main_classes[] = 'go-editorial-zone';
		$main_classes[] = 'go-editorial-hub';
		$main_classes[] = 'go-editorial-zone--' . $editorial_zone;
	}

	get_header();
	?>
	<main id="primary" class="<?php echo esc_attr( implode( ' ', $main_classes ) ); ?>">
		<div class="go-container go-pagehead go-pagehead--search">
			<?php go_verge_breadcrumbs(); ?>
			<h1 class="go-pagehead__title"><?php echo esc_html( $title ); ?></h1>
			<?php go_verge_render_editorial_search(); ?>
			<?php go_verge_render_desk_subjects(); ?>
		</div>

		<div class="go-container go-section go-archive-page">
			<?php if ( $hero_posts && ( $desk_context || 1 === $paged ) ) : ?>
				<?php
				$lead = array_shift( $hero_posts );
				$secondary_ids = array_map( 'absint', wp_list_pluck( array_slice( $hero_posts, 0, 4 ), 'ID' ) );
				go_verge_archive_hero( $lead->ID, $secondary_ids, 'default' );
				?>
			<?php endif; ?>

			<?php $desk_map = array( 'games'=>'games', 'entertainment'=>'entretenimento', 'technology'=>'tecnologia', 'offers'=>'ofertas' ); ?>
			<?php $has_desk_formats = isset( $desk_map[ $editorial_zone ] ) && function_exists( 'go_verge_render_desk_format_links' ); ?>
			<?php do_action( 'go_verge_editorial_hub_after_hero', $editorial_zone, $hero_ids, $desk_context ? 1 : $paged, $requested, $search_term ); ?>

			<?php if ( $access_sections && 1 === $paged && function_exists( 'go_verge_render_category_access_sections' ) ) : ?>
				<?php go_verge_render_category_access_sections( $access_sections, 'editorial', $base_url ); ?>
			<?php endif; ?>

			<?php if ( ! $editorial_zone && $direct_filter_term instanceof WP_Term && function_exists( 'go_verge_child_category_chips' ) ) : ?>
				<div class="go-archive-filters">
					<?php
					$direct_filter_root = $direct_filter_term;
					if ( $direct_filter_term->parent ) {
						$direct_filter_parent = get_term( $direct_filter_term->parent, 'category' );
						if ( $direct_filter_parent instanceof WP_Term ) {
							$direct_filter_root = $direct_filter_parent;
						}
					}
					go_verge_child_category_chips( $direct_filter_root, $direct_filter_term->term_id );
					?>
				</div>
			<?php endif; ?>

			<div<?php echo $editorial_zone ? ' data-go-editorial-filter-scope' : ''; ?>>
				<?php /* Desk type controls are rendered inside “Últimas publicações”, next to the list they affect. */ ?>
				<?php if ( ! $has_desk_formats && $filters ) : ?>
					<div class="go-archive-filters">
						<nav class="go-chips go-chips--filter" data-go-editorial-filters aria-label="<?php echo esc_attr( sprintf( __( 'Filtrar %s', 'go-verge' ), $title ) ); ?>">
							<a href="<?php echo esc_url( remove_query_arg( 'editoria', $base_url ) ); ?>" data-go-editorial-filter=""<?php echo $selected ? '' : ' class="is-active" aria-current="page"'; ?>><?php echo esc_html( go_verge_upper( __( 'Todos', 'go-verge' ) ) ); ?></a>
							<?php foreach ( $filters as $filter_item ) : ?>
								<a href="<?php echo esc_url( $filter_item['url'] ); ?>" data-go-editorial-filter="<?php echo esc_attr( $filter_item['slug'] ); ?>"<?php echo ( $selected instanceof WP_Term && $selected->slug === $filter_item['slug'] ) ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( go_verge_upper( $filter_item['label'] ) ); ?></a>
							<?php endforeach; ?>
						</nav>
					</div>
				<?php endif; ?>

				<div class="go-archive-body<?php echo $sidebar ? ' go-archive-body--aside' : ''; ?>">
					<div class="go-archive-main" data-go-editorial-results aria-live="polite">
						<?php if ( $desk_context ) : ?>
							<?php go_verge_render_desk_feed( $latest_query, $latest_title ); ?>
						<?php else : ?>
						<section class="go-archive-section" aria-labelledby="go-parent-latest-title">
							<div class="go-section__head"><h2 id="go-parent-latest-title" class="go-section__title"><?php echo esc_html( $latest_title ); ?></h2></div>
							<?php if ( $latest_query->have_posts() ) : ?>
								<div id="go-parent-latest-feed" class="go-archive-list" data-go-latest-feed<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
									<?php
									while ( $latest_query->have_posts() ) : $latest_query->the_post();
										go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'media_context' => 'latest' ) );
									endwhile;
									wp_reset_postdata();
									?>
								</div>
								<?php go_verge_pagination( $latest_query, array(), array( 'target' => '#go-parent-latest-feed', 'media_context' => 'latest' ) ); ?>
							<?php else : ?>
								<div id="go-parent-latest-feed" class="go-archive-list"><?php get_template_part( 'template-parts/content', 'none' ); ?></div>
							<?php endif; ?>
						</section>
						<?php endif; ?>
					</div>
					<?php if ( $sidebar ) { go_verge_render_archive_sidebar( $sidebar ); } ?>
				</div>
			</div>
		</div>
	</main>
	<?php
	wp_reset_postdata();
	get_footer();
}

/**
 * A single horizontal archive row.
 */
function go_verge_archive_list_item( $post_id, $args = array() ) {
	$args = wp_parse_args(
		$args,
		array(
			'show_excerpt' => true,
			'show_type'    => false,
			'show_score'   => false,
			'format'        => 'default',
			'image_size'    => 'go_card',
			'media_context' => 'card',
		)
	);

	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}

	$excerpt     = go_verge_support_text( $post_id );
	$has_thumb   = has_post_thumbnail( $post_id );
	// With an image the score rides the media corner (media label); a media-less
	// review row keeps an inline flat score in the meta so the verdict never hides.
	$score_chip  = ( 'reviews' === $args['format'] && ! $has_thumb ) ? go_verge_archive_score_chip( $post_id ) : '';
	?>
	<article class="go-archive-row go-archive-row--<?php echo esc_attr( $args['format'] ); ?><?php echo $has_thumb ? '' : ' go-archive-row--no-media'; ?><?php echo $score_chip ? ' go-archive-row--scored' : ''; ?>" data-go-ad-integrity="atomic">
		<?php if ( $has_thumb ) : ?>
			<a class="go-archive-row__media go-frame" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, $args['image_size'], array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id, $args['media_context'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php if ( ! empty( $args['show_score'] ) ) : ?>
					<?php echo go_verge_score_badge( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php endif; ?>
			</a>
		<?php endif; ?>
		<div class="go-archive-row__body">
			<?php if ( $args['show_type'] ) : ?>
				<span class="go-archive-row__type"><?php echo esc_html( get_post_type_object( get_post_type( $post_id ) )->labels->singular_name ?? '' ); ?></span>
			<?php endif; ?>
			<h3 class="go-archive-row__title"><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $args['show_excerpt'] && $excerpt ) : ?>
				<p class="go-archive-row__deck"><?php echo esc_html( wp_trim_words( $excerpt, 30, '…' ) ); ?></p>
			<?php endif; ?>
			<div class="go-archive-row__meta">
				<?php echo $score_chip; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts. ?>
				<?php $subject_link = function_exists( 'go_verge_article_subject_meta_link' ) ? go_verge_article_subject_meta_link( $post_id ) : ''; ?>
				<?php if ( $subject_link ) : ?><?php echo $subject_link; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span class="go-dot" aria-hidden="true">·</span><?php endif; ?>
				<?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php $byline = go_verge_byline( $post_id, true ); ?>
				<?php if ( $byline ) : ?><span class="go-dot" aria-hidden="true">·</span><?php echo $byline; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php endif; ?>
			</div>
		</div>
	</article>
	<?php
	if ( function_exists( 'go_verge_ads_maybe_render_listing_unit' ) ) {
		go_verge_ads_maybe_render_listing_unit();
	}
}

/**
 * Large visual archive feature.
 */
function go_verge_archive_feature( $post_id, $format = 'default' ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$excerpt    = go_verge_support_text( $post_id );
	$has_thumb  = has_post_thumbnail( $post_id );
	$format     = sanitize_html_class( $format ? $format : 'default' );
	// Reviews surface the score as a flat badge on the image corner (via the media
	// label); only a media-less review needs an inline fallback in the meta.
	$score_chip = ( 'reviews' === $format && ! $has_thumb ) ? go_verge_archive_score_chip( $post_id ) : '';
	?>
	<article class="go-archive-feature go-archive-feature--<?php echo esc_attr( $format ); ?><?php echo $has_thumb ? '' : ' go-archive-feature--no-media'; ?>" data-go-ad-integrity="atomic">
		<?php if ( $has_thumb ) : ?>
			<a class="go-archive-feature__media go-frame" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, 'go_hero', array( 'loading' => 'eager', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_score_badge( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			</a>
		<?php endif; ?>
		<div class="go-archive-feature__body">
			<h2 class="go-archive-feature__title"><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h2>
			<?php if ( $excerpt ) : ?><p class="go-archive-feature__deck"><?php echo esc_html( wp_trim_words( $excerpt, 38, '…' ) ); ?></p><?php endif; ?>
			<div class="go-archive-feature__meta"><?php echo $score_chip; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts. ?><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
		</div>
	</article>
	<?php
}

/**
 * Shared archive composition: one feature, then a horizontal latest list.
 */
/* Listing feeds use the manual Revenue Engine cadence. Auto Ads are intentionally disabled;
 * AJAX fragments never emit provider units so reporting identities remain single-use per page. */

/**
 * Editorial format of the current archive surface, used to vary the cover
 * composition and surface format-specific cues (review scores, etc.). Detected
 * from the queried context so every existing caller benefits without changes.
 */
function go_verge_archive_format_context() {
	// During admin-ajax (load more) the conditional tags are false, so the AJAX
	// handler recovers the archive format from the query and forces it here. This
	// keeps redundant format labels suppressed on appended pages too.
	if ( ! empty( $GLOBALS['go_verge_forced_archive_format'] ) ) {
		return (string) $GLOBALS['go_verge_forced_archive_format'];
	}
	if ( is_category( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ) ) || is_page( array( 'reviews', 'review' ) ) ) {
		return 'reviews';
	}
	if ( is_category( array( 'criticas', 'critica' ) ) || is_page( array( 'criticas', 'critica' ) ) ) {
		return 'critiques';
	}
	if ( is_category( array( 'dicas-e-guias', 'guias', 'guia', 'tutoriais', 'guias-de-trofeus', 'trofeus', 'platina' ) ) || is_page( array( 'dicas-e-guias', 'guias', 'guias-e-tutoriais' ) ) ) {
		return 'guides';
	}
	return 'default';
}

/**
 * Editorial format implied by a term (its own slug). Used to recover the archive
 * format inside AJAX requests, where the conditional tags are unavailable.
 */
function go_verge_format_for_term( $term ) {
	if ( ! ( $term instanceof WP_Term ) ) {
		return 'default';
	}
	$slug = $term->slug;
	if ( in_array( $slug, array( 'reviews', 'review', 'analises', 'analises-de-jogos' ), true ) ) {
		return 'reviews';
	}
	if ( in_array( $slug, array( 'criticas', 'critica' ), true ) ) {
		return 'critiques';
	}
	if ( in_array( $slug, array( 'dicas-e-guias', 'guias', 'guia', 'tutoriais', 'guias-de-trofeus', 'trofeus', 'platina' ), true ) ) {
		return 'guides';
	}
	return 'default';
}

/**
 * Compact, non-gated review score chip for the Reviews editorial surface.
 *
 * The sitewide rule hides review scores in cards/lists (go_verge_score_badge is
 * gated by go_verge_should_show_review_scores) to avoid score-shopping noise.
 * The Reviews *editoria* is the one place where finding a review by its verdict
 * is the reader's actual job, so it surfaces the score here on purpose. Scoped
 * to the reviews cover only; documented as a deliberate, reversible exception.
 */
function go_verge_archive_score_chip( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || ! function_exists( 'go_verge_review_score' ) ) {
		return '';
	}
	$score = go_verge_review_score( $post_id );
	if ( null === $score ) {
		return '';
	}
	if ( function_exists( 'go_verge_normalize_review_score' ) ) {
		$score = go_verge_normalize_review_score( $score );
	}
	$tier  = $score >= 8 ? 'is-high' : ( $score >= 5 ? 'is-mid' : 'is-low' );
	$label = function_exists( 'go_verge_review_score_display' )
		? go_verge_review_score_display( $score )
		: rtrim( rtrim( number_format( (float) $score, 1, '.', '' ), '0' ), '.' );
	return sprintf(
		'<span class="go-archive-score %1$s" aria-label="%3$s"><span class="go-archive-score__num">%2$s</span><span class="go-archive-score__scale">/10</span></span>',
		esc_attr( $tier ),
		esc_html( $label ),
		esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $label ) )
	);
}

/**
 * Compact vertical highlight card for the secondary "Destaques" cluster. Its
 * shape sits between the large feature and the horizontal rows so the cover
 * reads as three distinct editorial registers instead of one repeated card.
 */
function go_verge_archive_highlight( $post_id, $format = 'default' ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$has_thumb  = has_post_thumbnail( $post_id );
	$format     = sanitize_html_class( $format ? $format : 'default' );
	$score_chip = ( 'reviews' === $format && ! $has_thumb ) ? go_verge_archive_score_chip( $post_id ) : '';
	?>
	<article class="go-archive-highlight go-archive-highlight--<?php echo esc_attr( $format ); ?><?php echo $has_thumb ? '' : ' go-archive-highlight--no-media'; ?>" data-go-ad-integrity="atomic">
		<?php if ( $has_thumb ) : ?>
			<a class="go-archive-highlight__media go-frame" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, 'go_card', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			</a>
		<?php endif; ?>
		<div class="go-archive-highlight__body">
			<h3 class="go-archive-highlight__title"><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<div class="go-archive-highlight__meta"><?php echo $score_chip; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts. ?><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
		</div>
	</article>
	<?php
}

/**
 * Editorial hero: one lead story at real scale beside up to two stacked
 * secondaries. Replaces the old row of equal cards with a genuine hierarchy —
 * the lead carries image, kicker, title, support line and meta; each secondary
 * carries image, title and time only, with no filler labels or microcopy.
 */
function go_verge_archive_hero( $lead_id, $secondary_ids = array(), $format = 'default' ) {
	$lead_id = absint( $lead_id );
	if ( ! $lead_id ) {
		return;
	}
	$secondary_ids = array_values( array_filter( array_map( 'absint', (array) $secondary_ids ) ) );
	$format        = sanitize_html_class( $format ? $format : 'default' );
	$excerpt       = go_verge_support_text( $lead_id );
	$has_thumb     = has_post_thumbnail( $lead_id );
	$score_chip    = ( 'reviews' === $format && ! $has_thumb ) ? go_verge_archive_score_chip( $lead_id ) : '';
	$has_side      = ! empty( $secondary_ids );
	?>
	<section class="go-archive-hero<?php echo $has_side ? '' : ' go-archive-hero--solo'; ?> go-archive-hero--<?php echo esc_attr( $format ); ?>" aria-label="<?php esc_attr_e( 'Destaque principal', 'go-verge' ); ?>">
		<article class="go-archive-hero__lead<?php echo $has_thumb ? '' : ' go-archive-hero__lead--no-media'; ?>" data-go-ad-integrity="atomic">
			<?php if ( $has_thumb ) : ?>
				<a class="go-archive-hero__media go-frame" href="<?php echo esc_url( get_permalink( $lead_id ) ); ?>" tabindex="-1" aria-hidden="true">
					<?php echo get_the_post_thumbnail( $lead_id, 'go_hero', array( 'loading' => 'eager', 'fetchpriority' => 'high', 'alt' => get_the_title( $lead_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
					<?php echo go_verge_review_media_label( $lead_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
					<?php echo go_verge_score_badge( $lead_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				</a>
			<?php endif; ?>
			<div class="go-archive-hero__body">
				<h2 class="go-archive-hero__title"><a href="<?php echo esc_url( get_permalink( $lead_id ) ); ?>"><?php echo esc_html( get_the_title( $lead_id ) ); ?></a></h2>
				<?php if ( $excerpt ) : ?><p class="go-archive-hero__deck"><?php echo esc_html( wp_trim_words( $excerpt, 34, '…' ) ); ?></p><?php endif; ?>
				<div class="go-archive-hero__meta"><?php echo $score_chip; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- built from escaped parts. ?><?php echo go_verge_time_html( $lead_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
			</div>
		</article>
		<?php if ( $has_side ) : ?>
			<div class="go-archive-hero__side">
				<?php foreach ( $secondary_ids as $go_side_id ) : ?>
					<article class="go-archive-hero__item<?php echo has_post_thumbnail( $go_side_id ) ? '' : ' go-archive-hero__item--no-media'; ?>" data-go-ad-integrity="atomic">
						<?php if ( has_post_thumbnail( $go_side_id ) ) : ?>
							<a class="go-archive-hero__item-media go-frame" href="<?php echo esc_url( get_permalink( $go_side_id ) ); ?>" tabindex="-1" aria-hidden="true">
								<?php echo get_the_post_thumbnail( $go_side_id, 'go_card', array( 'loading' => 'lazy', 'alt' => get_the_title( $go_side_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
								<?php echo go_verge_review_media_label( $go_side_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
							</a>
						<?php endif; ?>
						<div class="go-archive-hero__item-body">
							<h3 class="go-archive-hero__item-title"><a href="<?php echo esc_url( get_permalink( $go_side_id ) ); ?>"><?php echo esc_html( get_the_title( $go_side_id ) ); ?></a></h3>
							<div class="go-archive-hero__item-meta"><?php echo go_verge_time_html( $go_side_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
						</div>
					</article>
				<?php endforeach; ?>
			</div>
		<?php endif; ?>
	</section>
	<?php
}

/**
 * One compact aside entry: thumb (or rank), title and time only.
 */
function go_verge_archive_aside_item( $post_id, $ranked = false, $rank = 0 ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	?>
	<article class="go-aside-item<?php echo $ranked ? ' go-aside-item--ranked' : ''; ?>">
		<?php if ( $ranked ) : ?>
			<span class="go-aside-item__rank" aria-hidden="true"><?php echo esc_html( (string) $rank ); ?></span>
		<?php elseif ( has_post_thumbnail( $post_id ) ) : ?>
			<a class="go-aside-item__media go-frame" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, 'go_square', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			</a>
		<?php endif; ?>
		<div class="go-aside-item__body">
			<h3 class="go-aside-item__title"><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<div class="go-aside-item__meta"><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
		</div>
	</article>
	<?php
}

/**
 * Category tree used by the contextual "Mais lidas" module.
 *
 * Reviews and guides belong to Games; critiques, series and films belong to
 * Entertainment. This prevents the sidebar from mixing unrelated verticals.
 */
function go_verge_archive_popular_term_ids( $accent_key ) {
	$games_aliases = array(
		'games', 'jogos', 'reviews', 'review', 'analises', 'analises-de-jogos',
		'dicas-e-guias', 'guias', 'guia', 'dicas', 'tutoriais', 'listas', 'rankings',
		'especiais', 'promocoes', 'playstation', 'xbox', 'nintendo', 'pc',
	);
	$entertainment_aliases = array(
		'entretenimento', 'noticias-de-entretenimento', 'noticias-entretenimento',
		'criticas', 'critica', 'series', 'serie', 'streaming', 'filmes', 'filme',
		'cinema', 'cinema-e-tv', 'animes', 'anime', 'mangas-e-quadrinhos',
		'manga-e-quadrinhos', 'mangas', 'manga', 'quadrinhos', 'hqs', 'comics',
	);
	$groups = array(
		'games'         => $games_aliases,
		'reviews'       => $games_aliases,
		'guides'        => $games_aliases,
		'entertainment' => $entertainment_aliases,
		'criticas'      => array( 'criticas', 'critica' ),
		'series'        => $entertainment_aliases,
		'filmes'        => $entertainment_aliases,
		'technology'    => array( 'tecnologia', 'technology', 'tech', 'celulares', 'hardware', 'software', 'inteligencia-artificial', 'ia' ),
	);

	$aliases = isset( $groups[ $accent_key ] ) ? $groups[ $accent_key ] : array();
	$ids     = go_verge_category_ids( $aliases );
	foreach ( $ids as $term_id ) {
		$children = get_term_children( (int) $term_id, 'category' );
		if ( ! is_wp_error( $children ) ) {
			$ids = array_merge( $ids, array_map( 'absint', $children ) );
		}
	}

	return array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
}

/**
 * Return popular posts restricted to one editorial vertical.
 *
 * Real tracked pageviews are preferred when the engagement layer is present;
 * comment activity and recency are only a deterministic fallback.
 */
function go_verge_archive_popular_posts( $accent_key, $exclude = array(), $limit = 5 ) {
	$limit    = max( 1, absint( $limit ) );
	$exclude  = array_values( array_unique( array_filter( array_map( 'absint', (array) $exclude ) ) ) );
	$term_ids = go_verge_archive_popular_term_ids( sanitize_key( (string) $accent_key ) );
	if ( empty( $term_ids ) ) {
		return array();
	}

	$ids = array();
	if ( function_exists( 'go_product_get_popular_ids' ) ) {
		$candidates = array_values( array_diff( array_filter( array_map( 'absint', (array) go_product_get_popular_ids( 24, 80, array( 'post' ) ) ) ), $exclude ) );
		if ( $candidates ) {
			$tracked = new WP_Query(
				array(
					'post_type'           => 'post',
					'post_status'         => 'publish',
					'post__in'            => $candidates,
					'category__in'        => $term_ids,
					'orderby'             => 'post__in',
					'posts_per_page'      => $limit,
					'ignore_sticky_posts' => true,
					'no_found_rows'       => true,
					'fields'              => 'ids',
				)
			);
			$ids = array_map( 'absint', $tracked->posts );
		}
	}

	if ( count( $ids ) < $limit ) {
		$fallback = get_posts(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => $limit - count( $ids ),
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'post__not_in'        => array_values( array_unique( array_merge( $exclude, $ids ) ) ),
				'category__in'        => $term_ids,
				'orderby'             => array( 'comment_count' => 'DESC', 'date' => 'DESC' ),
			)
		);
		$ids = array_merge( $ids, array_map( 'absint', wp_list_pluck( $fallback, 'ID' ) ) );
	}

	$ids = array_slice( array_values( array_unique( array_filter( $ids ) ) ), 0, $limit );
	if ( empty( $ids ) ) {
		return array();
	}

	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'post__in'            => $ids,
			'orderby'             => 'post__in',
			'posts_per_page'      => count( $ids ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
		)
	);
	return $query->posts;
}

/**
 * Global popularity for neutral surfaces such as the homepage and /ultimas/.
 */
function go_verge_global_popular_posts( $exclude = array(), $limit = 5 ) {
	$limit   = max( 1, absint( $limit ) );
	$exclude = array_values( array_unique( array_filter( array_map( 'absint', (array) $exclude ) ) ) );
	$ids     = array();

	if ( function_exists( 'go_product_get_popular_ids' ) ) {
		foreach ( (array) go_product_get_popular_ids( 24, 60, array( 'post' ) ) as $candidate_id ) {
			$candidate_id = absint( $candidate_id );
			if ( ! $candidate_id || in_array( $candidate_id, $exclude, true ) ) {
				continue;
			}
			if ( ! empty( $GLOBALS['go_verge_homepage_query_context'] ) && function_exists( 'go_verge_homepage_post_is_search_only' ) && go_verge_homepage_post_is_search_only( $candidate_id ) ) {
				continue;
			}
			$ids[] = $candidate_id;
			if ( count( $ids ) >= $limit ) {
				break;
			}
		}
	}

	if ( count( $ids ) < $limit ) {
		$fallback = get_posts(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => $limit - count( $ids ),
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'post__not_in'        => array_values( array_unique( array_merge( $exclude, $ids ) ) ),
				'orderby'             => array( 'comment_count' => 'DESC', 'date' => 'DESC' ),
				'date_query'          => array( array( 'after' => '30 days ago', 'inclusive' => true ) ),
				'suppress_filters'    => empty( $GLOBALS['go_verge_homepage_query_context'] ),
			)
		);
		$ids = array_merge( $ids, array_map( 'absint', wp_list_pluck( $fallback, 'ID' ) ) );
	}

	$ids = array_slice( array_values( array_unique( array_filter( $ids ) ) ), 0, $limit );
	if ( empty( $ids ) ) {
		return array();
	}

	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'post__in'            => $ids,
			'orderby'             => 'post__in',
			'posts_per_page'      => count( $ids ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
		)
	);
	return $query->posts;
}

/**
 * Build up to three sidebar modules for the editoria, gated by real content.
 *
 * Each editoria draws from the same small shared set (Mais lidas, Reviews
 * recentes, Próximos lançamentos, Guias populares); empty modules simply drop
 * out, so a thin site shows fewer instead of padded filler. "Mais lidas" ranks
 * by real comment activity (recency breaks ties) — no invented metric.
 *
 * @param string $accent_key Editoria key from go_verge_editorial_accent_key().
 * @param array  $exclude    Post IDs already shown on the page.
 * @return array[] Each: array( 'title' => string, 'ranked' => bool, 'posts' => WP_Post[] ).
 */
function go_verge_archive_sidebar_modules( $accent_key = '', $exclude = array() ) {
	$seen = array_values( array_unique( array_map( 'absint', (array) $exclude ) ) );

	$plans = array(
		'reviews'       => array( 'mais_lidas', 'guias_populares' ),
		'criticas'      => array( 'mais_lidas', 'criticas_recentes' ),
		'series'        => array( 'mais_lidas', 'criticas_recentes' ),
		'filmes'        => array( 'mais_lidas', 'criticas_recentes' ),
		'entertainment' => array( 'mais_lidas', 'criticas_recentes' ),
		'guides'        => array( 'mais_lidas', 'guias_populares', 'proximos_lancamentos' ),
		'technology'    => array( 'mais_lidas', 'guias_tecnologia' ),
		'games'         => array( 'mais_lidas', 'reviews_recentes' ),
	);
	$plan = isset( $plans[ $accent_key ] ) ? $plans[ $accent_key ] : array( 'mais_lidas', 'reviews_recentes' );

	$modules = array();
	foreach ( $plan as $module_key ) {
		$posts  = array();
		$ranked = false;
		$title  = '';
		switch ( $module_key ) {
			case 'mais_lidas':
				$title  = __( 'Mais lidas', 'go-verge' );
				$ranked = false;
				$posts  = go_verge_archive_popular_posts( $accent_key, $seen, 5 );
				break;
			case 'reviews_recentes':
				$title = __( 'Reviews recentes', 'go-verge' );
				$posts = go_verge_query_editorial_posts( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ), 4, array( 'post__not_in' => $seen ), array( 'review', 'analise' ) )->posts;
				break;
			case 'criticas_recentes':
				$title = __( 'Críticas recentes', 'go-verge' );
				$posts = go_verge_query_editorial_posts( array( 'criticas', 'critica' ), 4, array( 'post__not_in' => $seen ), array() )->posts;
				break;
			case 'proximos_lancamentos':
				$title = __( 'Próximos lançamentos', 'go-verge' );
				$posts = go_verge_query_editorial_posts( array( 'lancamentos', 'proximos-lancamentos', 'em-breve', 'estreias', 'calendario' ), 4, array( 'post__not_in' => $seen ), array( 'lancamento', 'estreia', 'em-breve' ) )->posts;
				break;
			case 'guias_populares':
				$title = __( 'Guias populares', 'go-verge' );
				$posts = go_verge_query_editorial_posts( array( 'dicas-e-guias', 'guias', 'guia', 'dicas' ), 4, array( 'post__not_in' => $seen, 'orderby' => array( 'comment_count' => 'DESC', 'date' => 'DESC' ) ), array( 'guia', 'dica', 'tutorial' ) )->posts;
				break;
			case 'guias_tecnologia':
				$title = __( 'Guias de tecnologia', 'go-verge' );

				/* V7 deliberately stores one editorial category per story. The old
				 * query required a guide to belong to BOTH a guide category and the
				 * Technology tree, an impossible intersection for the current model.
				 * Reuse the existing buying-guide classifier instead: it already knows
				 * whether a guide is about phones, notebooks, TVs, hardware or software
				 * without recategorising the article or inventing duplicate URLs. */
				$products = array();
				$archive_term = ! empty( $GLOBALS['go_verge_forced_editorial_term'] ) && $GLOBALS['go_verge_forced_editorial_term'] instanceof WP_Term
					? $GLOBALS['go_verge_forced_editorial_term']
					: get_queried_object();
				if ( $archive_term instanceof WP_Term ) {
					$product_map = array(
						'celulares'        => array( 'celulares' ),
						'notebooks'        => array( 'notebooks' ),
						'hardware'         => array( 'hardware', 'perifericos', 'audio' ),
						'tvs-e-monitores'  => array( 'tvs', 'monitores' ),
						'apps-software'    => array( 'software' ),
					);
					$products = $product_map[ sanitize_title( $archive_term->slug ) ] ?? array();
				}
				if ( function_exists( 'go_verge_buying_selection_items' ) ) {
					$guide_items = go_verge_buying_selection_items( 'technology', $seen, 4, $products );
					foreach ( $guide_items as $guide_item ) {
						if ( ! empty( $guide_item['post'] ) && $guide_item['post'] instanceof WP_Post ) {
							$posts[] = $guide_item['post'];
						}
					}
				}

				/* Compatibility fallback for installations where the buying-guide
				 * integration module is unavailable. Legacy multi-category stories can
				 * still populate the shelf, but it is no longer the primary contract. */
				if ( empty( $posts ) ) {
					$guide_ids = go_verge_category_ids( array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'tutoriais', 'guias-de-compra' ), array( 'guia', 'dica', 'tutorial' ) );
					$tech_ids  = go_verge_category_ids( array( 'tecnologia', 'tech' ), array( 'tecnolog' ) );
					if ( $guide_ids && $tech_ids ) {
						$tech_guides = new WP_Query( array(
							'post_type' => 'post', 'post_status' => 'publish', 'posts_per_page' => 4,
							'post__not_in' => $seen, 'ignore_sticky_posts' => true, 'no_found_rows' => true,
							'orderby' => array( 'date' => 'DESC' ),
							'tax_query' => array( 'relation' => 'AND',
								array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => $guide_ids, 'include_children' => true ),
								array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => $tech_ids, 'include_children' => true ),
							),
						) );
						$posts = $tech_guides->posts;
					}
				}
				break;
		}

		$posts = array_values( array_filter( (array) $posts, static function ( $post ) { return $post instanceof WP_Post; } ) );
		if ( empty( $posts ) ) {
			continue;
		}
		foreach ( $posts as $post ) {
			$seen[] = (int) $post->ID;
		}
		$seen      = array_values( array_unique( $seen ) );
		$modules[] = array( 'title' => $title, 'ranked' => $ranked, 'posts' => $posts );
		if ( count( $modules ) >= 3 ) {
			break;
		}
	}

	return $modules;
}

/**
 * Render the editoria sidebar. Titles are clean text; no module renders empty.
 */
function go_verge_render_archive_sidebar( $modules ) {
	$modules = array_values( array_filter( (array) $modules ) );
	if ( empty( $modules ) ) {
		return;
	}
	?>
	<aside class="go-archive-aside" aria-label="<?php esc_attr_e( 'Destaques da editoria', 'go-verge' ); ?>">
		<?php foreach ( $modules as $module ) : ?>
			<section class="go-aside-module">
				<div class="go-section__head go-section__head--quiet"><h2 class="go-section__title go-section__title--minor"><?php echo esc_html( $module['title'] ); ?></h2></div>
				<div class="go-aside-list<?php echo ! empty( $module['ranked'] ) ? ' go-aside-list--ranked' : ''; ?>">
					<?php
					$go_aside_rank = 0;
					foreach ( $module['posts'] as $go_aside_post ) {
						++$go_aside_rank;
						go_verge_archive_aside_item( $go_aside_post->ID, ! empty( $module['ranked'] ), $go_aside_rank );
					}
					?>
				</div>
			</section>
		<?php endforeach; ?>
		<?php /* Archive Rail is retired in the Sep-19 stabilization architecture. */ ?>
	</aside>
	<?php
}

/**
 * Editorial cover for an archive: a hero with real hierarchy (one lead plus two
 * stacked secondaries), then a dense recent stream paired with an editoria
 * sidebar. The hero and sidebar only render on the first page so paging keeps
 * flowing a clean chronological list; thin editorias fold back to lead + list.
 */
function go_verge_render_archive_posts( $posts, $latest_title = 'Últimas publicações' ) {
	$posts = array_values( array_filter( (array) $posts, static function( $post ) { return $post instanceof WP_Post; } ) );
	if ( empty( $posts ) ) {
		get_template_part( 'template-parts/content', 'none' );
		return;
	}

	$format        = function_exists( 'go_verge_archive_format_context' ) ? go_verge_archive_format_context() : 'default';
	$accent_key    = function_exists( 'go_verge_editorial_accent_key' ) ? go_verge_editorial_accent_key() : '';
	$is_first_page = isset( $GLOBALS['go_verge_forced_first_page'] ) ? (bool) $GLOBALS['go_verge_forced_first_page'] : ! is_paged();
	$used          = array();

	if ( $is_first_page ) {
		$lead   = array_shift( $posts );
		$used[] = (int) $lead->ID;

		// Use up to four side cards when the archive has enough depth. This keeps
		// the hero visually useful without consuming the whole chronological feed.
		$secondary_ids   = array();
		$secondary_count = count( $posts ) >= 5 ? 4 : ( count( $posts ) >= 3 ? 2 : 0 );
		if ( $secondary_count ) {
			$secondaries   = array_splice( $posts, 0, $secondary_count );
			$secondary_ids = array_map( 'absint', wp_list_pluck( $secondaries, 'ID' ) );
			$used          = array_merge( $used, $secondary_ids );
		}
		go_verge_archive_hero( $lead->ID, $secondary_ids, $format );

		// Contextual shelves that belong immediately after the visual hero.
		$go_archive_hero_term = ! empty( $GLOBALS['go_verge_forced_editorial_term'] ) && $GLOBALS['go_verge_forced_editorial_term'] instanceof WP_Term
			? $GLOBALS['go_verge_forced_editorial_term']
			: get_queried_object();
		do_action( 'go_verge_archive_after_hero', $go_archive_hero_term, $used, $format );

		// Structural child-category navigation may still live here. Desk content-type
		// filters are intentionally rendered inside the latest-publications section,
		// beside the feed they update, so readers never confuse them with navigation.
		$go_filter_term = ! empty( $GLOBALS['go_verge_forced_editorial_term'] ) && $GLOBALS['go_verge_forced_editorial_term'] instanceof WP_Term
			? $GLOBALS['go_verge_forced_editorial_term']
			: get_queried_object();
		if ( 'reviews' !== $accent_key && $go_filter_term instanceof WP_Term && ! isset( go_verge_editorial_pillars()[ $go_filter_term->slug ] ) && function_exists( 'go_verge_child_category_chips' ) ) {
			echo '<div class="go-archive-filters">';
			go_verge_child_category_chips( $go_filter_term );
			echo '</div>';
		}
	}

	if ( empty( $posts ) ) {
		return;
	}

	$modules     = ( $is_first_page && $accent_key )
		? go_verge_archive_sidebar_modules( $accent_key, array_merge( $used, array_map( 'absint', wp_list_pluck( $posts, 'ID' ) ) ) )
		: array();
	$has_sidebar = ! empty( $modules );
	?>
	<div class="go-archive-body<?php echo $has_sidebar ? ' go-archive-body--aside' : ''; ?>">
		<div class="go-archive-main">
			<section class="go-archive-section" aria-labelledby="go-archive-latest-title">
				<div class="go-section__head"><h2 id="go-archive-latest-title" class="go-section__title"><?php echo esc_html( $latest_title ); ?></h2></div>
				<div class="go-archive-list" data-go-latest-feed<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
					<?php
					foreach ( $posts as $post ) :
						go_verge_archive_list_item( $post->ID, array( 'format' => $format, 'show_score' => false, 'media_context' => in_array( $format, array( 'reviews', 'critiques' ), true ) ? 'card' : 'latest' ) );
					endforeach;
					?>
				</div>
			</section>
		</div>
		<?php if ( $has_sidebar ) { go_verge_render_archive_sidebar( $modules ); } ?>
	</div>
	<?php
}

/**
 * Render a query as horizontal rows and restore global post data.
 */
function go_verge_render_query_list( WP_Query $query, $show_excerpt = true ) {
	if ( ! $query->have_posts() ) {
		return;
	}
	echo '<div class="go-archive-list" data-go-latest-feed' . go_verge_ads_listing_root_attributes() . '>';
	while ( $query->have_posts() ) {
		$query->the_post();
		go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => $show_excerpt ) );
	}
	echo '</div>';
	wp_reset_postdata();
}

/**
 * Render query with a feature followed by list rows.
 */
function go_verge_render_query_feature_list( WP_Query $query, $latest_title = 'Últimas publicações' ) {
	if ( ! $query->have_posts() ) {
		get_template_part( 'template-parts/content', 'none' );
		return;
	}
	go_verge_render_archive_posts( $query->posts, $latest_title );
	wp_reset_postdata();
}

/**
 * Review/critique category detection.
 */
function go_verge_post_is_critique( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$terms = get_the_terms( $post_id, 'category' );
	if ( empty( $terms ) || is_wp_error( $terms ) ) {
		return false;
	}
	foreach ( $terms as $term ) {
		$candidates = array( $term );
		foreach ( get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
			$ancestor = get_term( $ancestor_id, 'category' );
			if ( $ancestor instanceof WP_Term ) {
				$candidates[] = $ancestor;
			}
		}
		foreach ( $candidates as $candidate ) {
			$slug = sanitize_title( remove_accents( $candidate->slug . ' ' . $candidate->name ) );
			if ( false !== strpos( $slug, 'critica' ) ) {
				return true;
			}
		}
	}
	return false;
}

/**
 * Compact visual card used by the three editorial rails below an article.
 */
function go_verge_after_article_card( $post_id, $show_score = false, $variant = 'default' ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$variant = sanitize_html_class( $variant ? $variant : 'default' );
	?>
	<article class="go-after-card go-after-card--<?php echo esc_attr( $variant ); ?>" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'after-card' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<a class="go-after-card__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_card', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-after-card__placeholder"></span>
			<?php endif; ?>
		</a>
		<div class="go-after-card__body">
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<div class="go-after-card__meta">
				<?php if ( $show_score ) : ?>
					<?php echo go_verge_score_badge( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php else : ?>
					<?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php endif; ?>
				<span class="go-after-card__arrow" aria-hidden="true">→</span>
			</div>
		</div>
	</article>
	<?php
}


/**
 * Compact list row for the 'Mais de ...' block below singles.
 */
function go_verge_after_article_related_row( $post_id, $order = 2 ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$deck  = function_exists( 'go_verge_support_text' ) ? go_verge_support_text( $post_id ) : '';
	?>
	<article class="go-after-related-row" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'after-related' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<a class="go-after-related-row__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_square', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-after-card__placeholder"></span>
			<?php endif; ?>
		</a>
		<div class="go-after-related-row__copy">
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $deck ) : ?><p><?php echo esc_html( wp_trim_words( $deck, 18, '…' ) ); ?></p><?php endif; ?>
			<div class="go-after-related-row__meta"><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span aria-hidden="true">→</span></div>
		</div>
	</article>
	<?php
}

/**
 * Featured latest-post card used below singles.
 */
function go_verge_after_article_latest_feature( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$deck = function_exists( 'go_verge_support_text' ) ? go_verge_support_text( $post_id ) : '';
	?>
	<article class="go-after-latest-feature" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'latest-feature' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<a class="go-after-latest-feature__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_feed', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-after-card__placeholder"></span>
			<?php endif; ?>
		</a>
		<div class="go-after-latest-feature__body">
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $deck ) : ?><p><?php echo esc_html( wp_trim_words( $deck, 24, '…' ) ); ?></p><?php endif; ?>
			<div class="go-after-latest-feature__meta">
				<?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php $byline = go_verge_byline( $post_id, true ); if ( $byline ) : ?><span class="go-dot" aria-hidden="true">·</span><?php echo $byline; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php endif; ?>
				<span class="go-dot" aria-hidden="true">·</span><span class="go-mono"><?php echo esc_html( sprintf( _n( '%s min de leitura', '%s min de leitura', go_verge_reading_time( $post_id ), 'go-verge' ), go_verge_reading_time( $post_id ) ) ); ?></span>
			</div>
		</div>
	</article>
	<?php
}

/**
 * Feature review card used in the review rail below singles.
 */
function go_verge_after_article_review_feature( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$deck = function_exists( 'go_verge_support_text' ) ? go_verge_support_text( $post_id ) : '';
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	?>
	<article class="go-after-review-feature" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'review-feature' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<a class="go-after-review-feature__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_feed', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-after-card__placeholder"></span>
			<?php endif; ?>
			<?php echo go_verge_score_badge( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
		</a>
		<div class="go-after-review-feature__body">
			<span class="go-after-review-feature__label"><?php echo esc_html( $is_critique ? __( 'Crítica', 'go-verge' ) : __( 'Review', 'go-verge' ) ); ?></span>
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $deck ) : ?><p><?php echo esc_html( wp_trim_words( $deck, 20, '…' ) ); ?></p><?php endif; ?>
			<div class="go-after-review-feature__meta"><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span aria-hidden="true">→</span></div>
		</div>
	</article>
	<?php
}

/**
 * Compact review row used below singles.
 */
function go_verge_after_article_review_mini( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$deck = function_exists( 'go_verge_support_text' ) ? go_verge_support_text( $post_id ) : '';
	$is_critique = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	?>
	<article class="go-after-review-mini" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'review-mini' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<a class="go-after-review-mini__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_square', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-after-card__placeholder"></span>
			<?php endif; ?>
			<?php echo go_verge_score_badge( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
		</a>
		<div class="go-after-review-mini__copy">
			<span class="go-after-review-mini__label"><?php echo esc_html( $is_critique ? __( 'Crítica', 'go-verge' ) : __( 'Review', 'go-verge' ) ); ?></span>
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $deck ) : ?><p><?php echo esc_html( wp_trim_words( $deck, 14, '…' ) ); ?></p><?php endif; ?>
			<div class="go-after-review-mini__meta"><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span aria-hidden="true">→</span></div>
		</div>
	</article>
	<?php
}

/**
 * Compact row used only by the "Últimas publicações" module below singles.
 */
function go_verge_after_article_latest_row( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$deck = function_exists( 'go_verge_support_text' ) ? go_verge_support_text( $post_id ) : '';
	?>
	<article class="go-after-latest-row" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'latest-row' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<?php if ( has_post_thumbnail( $post_id ) ) : ?>
			<a class="go-after-latest-row__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, 'go_square', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id, 'latest' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			</a>
		<?php endif; ?>
		<div class="go-after-latest-row__copy">
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $deck ) : ?><p><?php echo esc_html( $deck ); ?></p><?php endif; ?>
			<div class="go-after-latest-row__meta">
				<?php $subject_link = function_exists( 'go_verge_article_subject_meta_link' ) ? go_verge_article_subject_meta_link( $post_id ) : ''; ?>
				<?php if ( $subject_link ) : ?><?php echo $subject_link; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span class="go-dot" aria-hidden="true">·</span><?php endif; ?>
				<?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php $byline = go_verge_byline( $post_id, true ); ?>
				<?php if ( $byline ) : ?><span class="go-dot" aria-hidden="true">·</span><?php echo $byline; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php endif; ?>
			</div>
		</div>
	</article>
	<?php
}

/**
 * Review-specific card used by the "Reviews recentes" module below singles.
 */
function go_verge_after_article_review_card( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	?>
	<article class="go-after-review-card" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'after-review' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<a class="go-after-review-card__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_card', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php endif; ?>
			<?php echo go_verge_score_badge( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
		</a>
		<div class="go-after-review-card__body">
			<span class="go-after-review-card__label"><?php esc_html_e( 'Review', 'go-verge' ); ?></span>
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<a class="go-after-review-card__link" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php esc_html_e( 'Ler análise', 'go-verge' ); ?><span class="screen-reader-text">: <?php echo esc_html( get_the_title( $post_id ) ); ?></span><span aria-hidden="true">→</span></a>
		</div>
	</article>
	<?php
}


/**
 * Resolve a useful archive URL from resilient category aliases.
 */
function go_verge_after_section_url( $aliases, $fragments = array(), $fallback = '' ) {
	$ids = go_verge_category_ids( $aliases, $fragments );
	if ( ! empty( $ids ) ) {
		$link = get_term_link( (int) $ids[0], 'category' );
		if ( ! is_wp_error( $link ) ) {
			return $link;
		}
	}
	return $fallback;
}

/**
 * Lightweight monetization-potential proxy used only as a tie-breaker for
 * recommendation ranking. It never replaces editorial relevance: the score is
 * derived from the amount of real content and media a destination can sustain,
 * which correlates with reading depth and legitimate ad opportunities.
 *
 * @param int $post_id Post ID.
 * @return int 0..100.
 */
function go_verge_revenue_potential_score( $post_id ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return 0;
	}
	if ( isset( $cache[ $post_id ] ) ) {
		return $cache[ $post_id ];
	}
	$content = (string) get_post_field( 'post_content', $post_id );
	$words   = function_exists( 'go_verge_ads_word_count' )
		? go_verge_ads_word_count( $content )
		: count( preg_split( '/\s+/u', trim( wp_strip_all_tags( strip_shortcodes( $content ) ) ), -1, PREG_SPLIT_NO_EMPTY ) );
	$images  = preg_match_all( '/<img\b/i', $content, $matches );
	$images  = false === $images ? 0 : (int) $images;
	$score   = min( 58, (int) round( $words / 28 ) );
	$score  += min( 24, $images * 4 );
	if ( has_post_thumbnail( $post_id ) ) {
		$score += 5;
	}
	if ( $words >= 900 ) {
		$score += 5;
	}
	if ( $words >= 1400 ) {
		$score += 4;
	}
	$cache[ $post_id ] = max( 0, min( 100, $score ) );
	return $cache[ $post_id ];
}

/** Recommendation metadata consumed by the cache-safe client intelligence layer. */
function go_verge_reco_data_attributes( $post_id, $source = 'related' ) {
	$post_id = absint( $post_id );
	$source  = sanitize_key( (string) $source );
	$vertical = function_exists( 'go_verge_post_editorial_context' ) ? sanitize_key( (string) go_verge_post_editorial_context( $post_id ) ) : '';
	return sprintf(
		'data-go-reco-card="1" data-go-reco-post-id="%1$d" data-go-reco-source="%2$s" data-go-reco-revenue-score="%3$d" data-go-reco-vertical="%4$s"',
		$post_id,
		esc_attr( $source ),
		go_verge_revenue_potential_score( $post_id ),
		esc_attr( $vertical )
	);
}

/**
 * Score candidate related stories by shared tags, category affinity and
 * recency. This avoids the common "same category = related" false positive.
 *
 * @return WP_Post[]
 */
function go_verge_smart_related_posts( $post_id, $limit = 4, $exclude = array() ) {
	$post_id = absint( $post_id );
	$limit   = max( 1, min( 24, (int) $limit ) );
	$exclude = array_values( array_unique( array_merge( array( $post_id ), array_map( 'absint', (array) $exclude ) ) ) );
	if ( is_singular( 'post' ) && function_exists( 'go_verge_single_recommendation_ids' ) ) {
		return array_map( 'get_post', go_verge_single_recommendation_ids( $post_id, $limit, $exclude ) );
	}
	/* Inline, sidebar and article-tail modules share the same subject ranking.
	 * Freshness/revenue bonuses must never manufacture relevance for an empty
	 * taxonomy, and the primed term cache avoids two extra queries per candidate. */
	if ( function_exists( 'go_verge_related_post_ids' ) ) {
		$ids = go_verge_related_post_ids( $post_id, min(96,max(24,$limit+count($exclude))) );
		$posts = array();
		foreach ( $ids as $id ) {
			if ( in_array( (int)$id, $exclude, true ) ) { continue; }
			$post = get_post( $id );
			if ( ! ( $post instanceof WP_Post ) || 'publish' !== $post->post_status ) { continue; }
			$posts[] = $post;
			if ( count($posts) >= $limit ) { break; }
		}
		return $posts;
	}
	$is_critique_context = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$editorial_context   = $is_critique_context ? 'entertainment' : ( function_exists( 'go_verge_post_editorial_context' ) ? go_verge_post_editorial_context( $post_id ) : '' );

	$tag_ids = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) );
	$cat_ids = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'ids' ) );
	$tag_ids = is_wp_error( $tag_ids ) ? array() : array_map( 'absint', $tag_ids );
	$cat_ids = is_wp_error( $cat_ids ) ? array() : array_map( 'absint', $cat_ids );
	$primary = go_verge_get_primary_term( $post_id );

	$tax_query = array( 'relation' => 'OR' );
	if ( ! empty( $tag_ids ) ) {
		$tax_query[] = array(
			'taxonomy' => 'post_tag',
			'field'    => 'term_id',
			'terms'    => $tag_ids,
		);
	}
	if ( ! empty( $cat_ids ) ) {
		$tax_query[] = array(
			'taxonomy'         => 'category',
			'field'            => 'term_id',
			'terms'            => $cat_ids,
			'include_children' => true,
		);
	}

	$args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => 18,
		'post__not_in'        => $exclude,
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
	);
	if ( count( $tax_query ) > 1 ) {
		$args['tax_query'] = $tax_query;
	}

	$query = new WP_Query( $args );
	$now   = (int) current_time( 'timestamp', true );
	$ranked = array();

	foreach ( $query->posts as $candidate ) {
		$candidate_id   = (int) $candidate->ID;
		if ( $editorial_context && ( ! function_exists( 'go_verge_post_matches_editorial_context' ) || ! go_verge_post_matches_editorial_context( $candidate_id, $editorial_context ) ) ) {
			continue;
		}
		$candidate_tags = wp_get_post_terms( $candidate_id, 'post_tag', array( 'fields' => 'ids' ) );
		$candidate_cats = wp_get_post_terms( $candidate_id, 'category', array( 'fields' => 'ids' ) );
		$candidate_tags = is_wp_error( $candidate_tags ) ? array() : array_map( 'absint', $candidate_tags );
		$candidate_cats = is_wp_error( $candidate_cats ) ? array() : array_map( 'absint', $candidate_cats );

		$shared_tags = count( array_intersect( $tag_ids, $candidate_tags ) );
		$shared_cats = count( array_intersect( $cat_ids, $candidate_cats ) );
		$score       = ( $shared_tags * 12 ) + ( $shared_cats * 4 );

		if ( $primary instanceof WP_Term && in_array( (int) $primary->term_id, $candidate_cats, true ) ) {
			$score += 7;
		}
		if ( has_post_thumbnail( $candidate_id ) ) {
			$score += 1;
		}

		/* Revenue-aware, relevance-first tie-breaker. A maximum eight-point bonus
		 * cannot overpower shared tags/categories, but it prefers destinations that
		 * can sustain a deeper, better-monetized reading session when relevance ties. */
		$score += min( 8, go_verge_revenue_potential_score( $candidate_id ) * 0.08 );

		/* V49: subject/category relevance is already established above; use low
		 * inbound-link count only as a discovery bonus among relevant candidates. */
		if ( $score > 0 && function_exists( 'go_verge_v46_inbound_link_count' ) ) {
			$go_v49_inbound = go_verge_v46_inbound_link_count( $candidate_id );
			if ( 0 === $go_v49_inbound ) {
				$score += 16;
			} elseif ( 1 === $go_v49_inbound ) {
				$score += 12;
			} elseif ( null !== $go_v49_inbound && $go_v49_inbound <= 3 ) {
				$score += 6;
			}
		}

		$published = (int) get_post_time( 'U', true, $candidate_id );
		$age_days  = max( 0, ( $now - $published ) / DAY_IN_SECONDS );
		$score    += max( 0, 6 - min( 6, $age_days / 45 ) );

		$ranked[] = array(
			'post'  => $candidate,
			'score' => $score,
			'date'  => $published,
		);
	}

	usort(
		$ranked,
		function ( $a, $b ) {
			if ( $a['score'] === $b['score'] ) {
				return $b['date'] <=> $a['date'];
			}
			return $b['score'] <=> $a['score'];
		}
	);

	$posts = array_map(
		function ( $row ) {
			return $row['post'];
		},
		array_slice( $ranked, 0, $limit )
	);

	if ( count( $posts ) < $limit ) {
		$fallback_exclude = array_merge( $exclude, wp_list_pluck( $posts, 'ID' ) );
		$fallback_limit   = $limit - count( $posts );
		$fallback_exclude = array_values( array_unique( array_map( 'absint', $fallback_exclude ) ) );

		if ( $editorial_context ) {
			$format_queries = array(
				'ranking' => array(
					'aliases'   => array( 'rankings', 'ranking' ),
					'fragments' => array( 'ranking' ),
				),
				'list' => array(
					'aliases'   => array( 'listas', 'lista' ),
					'fragments' => array( 'lista' ),
				),
				'guide' => array(
					'aliases'   => array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'detonados', 'tutoriais', 'tutorial' ),
					'fragments' => array( 'guia', 'dica', 'detonado', 'tutorial' ),
				),
				'special' => array(
					'aliases'   => array( 'especiais', 'especial', 'reportagens', 'materias-especiais' ),
					'fragments' => array( 'especial', 'reportagem' ),
				),
				'entertainment' => array(
					'aliases'   => array( 'entretenimento', 'series', 'filmes', 'streaming', 'animes', 'cultura-pop' ),
					'fragments' => array( 'entretenimento', 'cinema', 'filme', 'serie', 'streaming', 'anime' ),
				),
			);
			$format_query = $format_queries[ $editorial_context ];
			$fallback = go_verge_query_editorial_posts(
				$format_query['aliases'],
				max( 18, $fallback_limit * 4 ),
				array( 'post__not_in' => $fallback_exclude ),
				$format_query['fragments']
			);
			$fallback_posts = array_filter(
				$fallback->posts,
				static function ( $candidate ) use ( $editorial_context ) {
					return $candidate instanceof WP_Post && function_exists( 'go_verge_post_matches_editorial_context' ) && go_verge_post_matches_editorial_context( $candidate->ID, $editorial_context );
				}
			);
			$posts = array_merge( $posts, array_slice( array_values( $fallback_posts ), 0, $fallback_limit ) );
		} else {
			$fallback_args = array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => $fallback_limit,
				'post__not_in'        => $fallback_exclude,
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
			);
			if ( $primary instanceof WP_Term ) {
				$fallback_args['cat'] = (int) $primary->term_id;
			}
			$fallback = new WP_Query( $fallback_args );
			$posts    = array_merge( $posts, $fallback->posts );
		}
	}

	return array_slice( $posts, 0, $limit );
}

/**
 * Main contextual recommendation below a single article.
 */
function go_verge_after_article_related_feature( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$deck = go_verge_support_text( $post_id );
	?>
	<article class="go-after-related-feature">
		<a class="go-after-related-feature__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
			<?php if ( has_post_thumbnail( $post_id ) ) : ?>
				<?php echo get_the_post_thumbnail( $post_id, 'go_hero', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			<?php else : ?>
				<span class="go-after-card__placeholder"></span>
			<?php endif; ?>
		</a>
		<div class="go-after-related-feature__body">
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
			<?php if ( $deck ) : ?><p><?php echo esc_html( wp_trim_words( $deck, 26, '…' ) ); ?></p><?php endif; ?>
			<div class="go-after-related-feature__footer">
				<?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php esc_html_e( 'Continuar lendo', 'go-verge' ); ?><span aria-hidden="true">→</span></a>
			</div>
		</div>
	</article>
	<?php
}

/**
 * Chronological latest-news row. The first item receives a quiet live marker.
 */
function go_verge_after_article_latest_feed_row( $post_id, $index = 0 ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return;
	}
	$primary = go_verge_get_primary_term( $post_id );
	?>
	<article class="go-after-latest-entry<?php echo 0 === (int) $index ? ' is-first' : ''; ?>" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( $post_id, 'latest-feed' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
		<div class="go-after-latest-entry__time">
			<?php if ( 0 === (int) $index ) : ?><span class="go-after-latest-entry__fresh"><?php esc_html_e( 'Mais recente', 'go-verge' ); ?></span><?php endif; ?>
			<?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
		</div>
		<div class="go-after-latest-entry__copy">
			<?php if ( $primary instanceof WP_Term ) : ?><span class="go-after-latest-entry__section"><?php echo esc_html( $primary->name ); ?></span><?php endif; ?>
			<h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3>
		</div>
		<?php if ( has_post_thumbnail( $post_id ) ) : ?>
			<a class="go-after-latest-entry__media" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, 'go_square', array( 'loading' => 'lazy', 'alt' => get_the_title( $post_id ) ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php echo go_verge_review_media_label( $post_id, 'latest' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
			</a>
		<?php endif; ?>
		<a class="go-after-latest-entry__hit" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Ler: %s', 'go-verge' ), get_the_title( $post_id ) ) ); ?>"></a>
	</article>
	<?php
}

/**
 * Below-article editorial modules: affinity-ranked related stories, plus recent
 * reviews when the reader was already on evaluative ground.
 *
 * Both blocks exclude what the article rail offered, and neither is chronological
 * -- a purely "latest" module recommends by publish time, which under a Netflix
 * recap surfaces whatever unrelated thing shipped that morning.
 */
function go_verge_render_after_article_sections( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$primary = go_verge_get_primary_term( $post_id );
	$is_critique_context = function_exists( 'go_verge_post_is_critique' ) && go_verge_post_is_critique( $post_id );
	$editorial_context   = $is_critique_context ? 'entertainment' : ( function_exists( 'go_verge_post_editorial_context' ) ? go_verge_post_editorial_context( $post_id ) : '' );

	// O rail já ofereceu parte do pool e renderiza antes destes módulos, então
	// entra na exclusão: sem isso o mesmo candidato forte aparece duas vezes na
	// página, uma ao lado do texto e outra embaixo dele.
	$used = array_merge(
		array( $post_id ),
		function_exists( 'go_verge_recirculation_shown_ids' )
			? go_verge_recirculation_shown_ids()
			: ( function_exists( 'go_verge_sidebar_shown_ids' ) ? go_verge_sidebar_shown_ids() : array() )
	);
	$used = array_values( array_unique( array_filter( array_map( 'absint', $used ) ) ) );

	/*
	 * If "Continue neste assunto" already rendered, the next rail must change
	 * intent. A second same-subject recommendation module creates visual
	 * repetition, burns recirculation inventory and makes the end of the page feel
	 * longer without giving the reader a new choice. In that case widen to the
	 * article's editorial vertical and explicitly exclude the subject pool.
	 */
	$contextual_next_rendered = function_exists( 'go_verge_contextual_next_rendered' ) && go_verge_contextual_next_rendered( $post_id );
	$discovery_title = '';
	$discovery_url   = '';
	$related_posts   = array();

	if ( $contextual_next_rendered && ! function_exists( 'go_verge_single_recommendation_ids' ) ) {
		if ( function_exists( 'go_verge_v17_cluster_subject' ) && function_exists( 'go_verge_v17_cluster_post_ids' ) ) {
			$subject = go_verge_v17_cluster_subject( $post_id );
			if ( $subject ) {
				$used = array_values( array_unique( array_merge( $used, array_map( 'absint', go_verge_v17_cluster_post_ids( $post_id, $subject, 6 ) ) ) ) );
			}
		}

		$vertical = function_exists( 'go_verge_article_vertical_bucket' ) ? go_verge_article_vertical_bucket( $post_id, $primary ) : 'direct';
		$verticals = array(
			'games' => array(
				'title'     => __( 'Mais de Games', 'go-verge' ),
				'aliases'   => array( 'games', 'jogos' ),
				'fragments' => array( 'game', 'jogo' ),
				'fallback'  => home_url( '/games/' ),
			),
			'entertainment' => array(
				'title'     => __( 'Mais de Entretenimento', 'go-verge' ),
				'aliases'   => array( 'entretenimento', 'series', 'filmes', 'streaming' ),
				'fragments' => array( 'entretenimento', 'serie', 'filme', 'streaming' ),
				'fallback'  => home_url( '/entretenimento/' ),
			),
			'technology' => array(
				'title'     => __( 'Mais de Tecnologia', 'go-verge' ),
				'aliases'   => array( 'tecnologia', 'apps-software', 'ia', 'hardware', 'celulares', 'ciencia', 'notebooks', 'tvs-e-monitores' ),
				'fragments' => array( 'tecnologia', 'software', 'inteligencia-artificial', 'hardware', 'celular', 'notebook', 'monitor', 'tv' ),
				'fallback'  => home_url( '/tecnologia/' ),
			),
		);

		if ( isset( $verticals[ $vertical ] ) ) {
			$surface = $verticals[ $vertical ];
			$discovery_title = $surface['title'];
			$discovery_url   = go_verge_after_section_url( $surface['aliases'], $surface['fragments'], $surface['fallback'] );
			$q = go_verge_query_editorial_posts(
				$surface['aliases'],
				12,
				array( 'post__not_in' => $used, 'orderby' => 'date', 'order' => 'DESC' ),
				$surface['fragments']
			);
			$related_posts = array_slice( array_values( array_filter( (array) $q->posts ) ), 0, 4 );
		}
	}

	if ( empty( $related_posts ) ) {
		$related_posts = go_verge_smart_related_posts( $post_id, 4, $used );
	}
	if ( function_exists( 'go_verge_single_recommendation_ids' ) ) {
		$discovery = $contextual_next_rendered || ! $related_posts;
		$related_posts = array_map( 'get_post', go_verge_single_recommendation_ids( $post_id, 4, $used, $discovery ) );
		$discovery_title = __( 'Leia também', 'go-verge' );
		$desk = go_verge_post_editorial_desk($post_id);
		$pillars = go_verge_editorial_pillars();
		if ( $discovery && isset($pillars[$desk]) ) { $discovery_title=sprintf(__( 'Mais de %s', 'go-verge' ),$pillars[$desk]['label']); }
		$desk_term = $desk ? get_term_by('slug',$desk,'category') : null;
		if ( $desk_term instanceof WP_Term ) { $link=get_term_link($desk_term); $discovery_url=is_wp_error($link)?'':$link; }
	}
	$used = array_merge( $used, wp_list_pluck( $related_posts, 'ID' ) );
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) && $related_posts ) {
		go_verge_recirculation_shown_ids( $used );
	}

	/* A segunda vitrine acompanha o formato avaliativo que o leitor abriu. */
	$review_context = $is_critique_context || ( function_exists( 'go_verge_is_review_post' ) && go_verge_is_review_post( $post_id ) )
		|| ( $primary instanceof WP_Term && in_array( $primary->slug, array( 'reviews', 'review', 'analises', 'analises-de-jogos', 'games', 'jogos' ), true ) );
	if ( function_exists( 'go_verge_single_recommendation_context' ) ) {
		$review_context = in_array( go_verge_single_recommendation_context($post_id)['type'], array('review','critica','comparativo'), true );
	}

	$evaluation_aliases   = $is_critique_context ? array( 'criticas', 'critica' ) : array( 'reviews', 'review', 'analises', 'analises-de-jogos' );
	$evaluation_fragments = $is_critique_context ? array( 'critica' ) : array( 'review', 'analise' );
	$reviews = $review_context && ! function_exists( 'go_verge_single_recommendation_ids' )
		? go_verge_query_editorial_posts(
			$evaluation_aliases,
			12,
			array( 'post__not_in' => array_values( array_unique( array_map( 'absint', $used ) ) ) ),
			$evaluation_fragments
		)
		: null;
	if ( $review_context && function_exists( 'go_verge_single_recommendation_ids' ) ) {
		$review_ids = array_values(array_filter(go_verge_single_recommendation_ids($post_id,96,$used), static function($id) use ($is_critique_context) {
			$type = go_verge_single_recommendation_context($id)['type'];
			return $is_critique_context ? 'critica'===$type : in_array($type,array('review','comparativo'),true);
		}));
		if ( $review_ids ) { $reviews = new WP_Query(array('post_type'=>'post','post_status'=>'publish','has_password'=>false,'post__in'=>array_slice($review_ids,0,4),'orderby'=>'post__in','posts_per_page'=>4,'no_found_rows'=>true,'ignore_sticky_posts'=>true)); }
	}
	if ( $reviews instanceof WP_Query ) {
		$reviews->posts = array_slice( array_values(
			array_filter(
				$reviews->posts,
				static function ( $candidate ) use ( $is_critique_context, $post_id ) {
					if ( ! ( $candidate instanceof WP_Post ) || ! function_exists( 'go_verge_post_is_critique' ) ) {
						return false;
					}
					if ( function_exists('go_verge_single_recommendation_eligible') && ( !go_verge_single_recommendation_eligible($candidate->ID,$post_id) || go_verge_post_editorial_desk($candidate->ID)!==go_verge_post_editorial_desk($post_id) ) ) { return false; }
					$is_candidate_critique = go_verge_post_is_critique( $candidate->ID );
					return $is_critique_context ? $is_candidate_critique : ! $is_candidate_critique;
				}
			)
		), 0, 4 );
		$reviews->post_count = count( $reviews->posts );
		if ( $reviews->posts && function_exists('go_verge_recirculation_shown_ids') ) { go_verge_recirculation_shown_ids( wp_list_pluck($reviews->posts,'ID') ); }
	}
	$has_reviews = $reviews instanceof WP_Query && $reviews->have_posts();

	if ( empty( $related_posts ) && ! $has_reviews ) {
		return;
	}

	$related_url = '';
	if ( $primary instanceof WP_Term ) {
		$term_link = get_term_link( $primary );
		$related_url = is_wp_error( $term_link ) ? '' : $term_link;
	}
	if ( '' !== $discovery_url ) {
		$related_url = $discovery_url;
	}
	$editorial_sections = array(
		'ranking' => array( 'title' => __( 'Mais de Rankings', 'go-verge' ), 'aliases' => array( 'rankings', 'ranking' ), 'fragments' => array( 'ranking' ), 'fallback' => home_url( '/rankings/' ) ),
		'list'    => array( 'title' => __( 'Mais de Listas', 'go-verge' ), 'aliases' => array( 'listas', 'lista' ), 'fragments' => array( 'lista' ), 'fallback' => home_url( '/listas/' ) ),
		'guide'   => array( 'title' => __( 'Mais de Dicas e Guias', 'go-verge' ), 'aliases' => array( 'dicas-e-guias', 'guias', 'guia', 'dicas' ), 'fragments' => array( 'guia', 'dica', 'tutorial' ), 'fallback' => ( function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'guias' ) : home_url( '/guias/' ) ) ),
		'special' => array( 'title' => __( 'Mais de Especiais', 'go-verge' ), 'aliases' => array( 'especiais', 'especial', 'reportagens' ), 'fragments' => array( 'especial', 'reportagem' ), 'fallback' => home_url( '/especiais/' ) ),
		'entertainment' => array( 'title' => __( 'Mais de Entretenimento', 'go-verge' ), 'aliases' => array( 'entretenimento' ), 'fragments' => array( 'entretenimento' ), 'fallback' => home_url( '/entretenimento/' ) ),
	);
	if ( ! $discovery_url && $editorial_context && isset( $editorial_sections[ $editorial_context ] ) ) {
		$section     = $editorial_sections[ $editorial_context ];
		$related_url = go_verge_after_section_url( $section['aliases'], $section['fragments'], $section['fallback'] );
	}
	$reviews_url = $has_reviews
		? go_verge_after_section_url(
			$evaluation_aliases,
			$evaluation_fragments,
			$is_critique_context ? home_url( '/criticas/' ) : home_url( '/reviews/' )
		)
		: '';
	?>
	<div class="go-container go-after-article go-single-tail">
		<?php if ( ! empty( $related_posts ) ) : ?>
			<section class="go-after-article__section go-after-article__section--related">
				<div class="go-section__head go-after-section-head">
					<?php
					$go_after_related_title = $editorial_context && isset( $editorial_sections[ $editorial_context ] ) ? $editorial_sections[ $editorial_context ]['title'] : ( $primary instanceof WP_Term ? sprintf( __( 'Mais de %s', 'go-verge' ), $primary->name ) : __( 'Mais sobre o assunto', 'go-verge' ) );
					if ( '' !== $discovery_title ) {
						$go_after_related_title = $discovery_title;
					}
					$go_after_is_review = function_exists( 'go_verge_review_data' ) && ( ! function_exists( 'go_verge_post_is_critique' ) || ! go_verge_post_is_critique( $post_id ) ) && ! empty( go_verge_review_data( $post_id )['has_review'] );
					if ( $go_after_is_review || ( $primary instanceof WP_Term && in_array( $primary->slug, array( 'reviews', 'review', 'analises', 'analises-de-jogos' ), true ) ) ) {
						$go_after_related_title = __( 'Mais de Overdrive', 'go-verge' );
					}
					?>
					<h2 class="go-section__title"><?php echo esc_html( $go_after_related_title ); ?></h2>
					<?php if ( $related_url ) : ?>
					<?php $go_after_more_label = trim( preg_replace( '/^Mais\s+(?:de|sobre)\s+/iu', '', wp_strip_all_tags( $go_after_related_title ) ) ); ?>
					<a class="go-after-section-head__link" href="<?php echo esc_url( $related_url ); ?>"><?php echo esc_html( $go_after_more_label ? sprintf( __( 'Ver mais sobre %s', 'go-verge' ), $go_after_more_label ) : __( 'Ver mais conteúdos relacionados', 'go-verge' ) ); ?><span aria-hidden="true">→</span></a>
				<?php endif; ?>
				</div>
				<div class="go-after-related-layout">
					<?php if ( ! empty( $related_posts[0] ) ) : go_verge_after_article_related_feature( $related_posts[0]->ID ); endif; ?>
					<div class="go-after-related-list">
						<?php foreach ( array_slice( $related_posts, 1 ) as $index => $item ) : go_verge_after_article_related_row( $item->ID, $index + 2 ); endforeach; ?>
					</div>
				</div>
			</section>
		<?php endif; ?>

		<?php if ( $has_reviews ) : ?>
			<section class="go-after-article__section go-after-article__section--reviews">
				<div class="go-section__head go-after-section-head">
					<h2 class="go-section__title"><?php echo esc_html( $is_critique_context ? __( 'Críticas recentes', 'go-verge' ) : __( 'Reviews recentes', 'go-verge' ) ); ?></h2>
					<a class="go-after-section-head__link" href="<?php echo esc_url( $reviews_url ); ?>"><?php echo esc_html( $is_critique_context ? __( 'Todas as críticas', 'go-verge' ) : __( 'Todas as reviews', 'go-verge' ) ); ?><span aria-hidden="true">→</span></a>
				</div>
				<div class="go-after-review-layout">
					<?php if ( ! empty( $reviews->posts[0] ) ) : go_verge_after_article_review_feature( $reviews->posts[0]->ID ); endif; ?>
					<div class="go-after-review-stack">
						<?php foreach ( array_slice( $reviews->posts, 1 ) as $item ) : go_verge_after_article_review_mini( $item->ID ); endforeach; ?>
					</div>
				</div>
			</section>
		<?php endif; ?>
	</div>
	<?php
}

/**
 * Extract a YouTube video ID from common public URL formats.
 */
function go_verge_youtube_video_id( $url ) {
	$url = trim( (string) $url );
	if ( '' === $url ) {
		return '';
	}

	if ( preg_match( '~(?:youtu\.be/|youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/))([A-Za-z0-9_-]{6,})~i', $url, $match ) ) {
		return (string) $match[1];
	}

	$query = wp_parse_url( $url, PHP_URL_QUERY );
	if ( $query ) {
		parse_str( $query, $vars );
		if ( ! empty( $vars['v'] ) && preg_match( '/^[A-Za-z0-9_-]{6,}$/', (string) $vars['v'] ) ) {
			return (string) $vars['v'];
		}
	}

	return '';
}

/**
 * Default official YouTube sources for the homepage video hub.
 * The filter keeps them editable if a channel migrates in the future.
 */
function go_verge_official_video_sources() {
	$sources = array(
		'playstation' => array(
			'label'      => 'PlayStation',
			'channel_id' => 'UC-2Y8dQb0S6DtpxNgAKoJKA',
		),
		'xbox' => array(
			'label'      => 'Xbox',
			'channel_id' => 'UCjBp_7RuDBUYbd1LegWEJ8g',
		),
		'nintendo' => array(
			'label'      => 'Nintendo',
			'channel_id' => 'UCGIY_O-8vW4rfX98KlMkvRg',
		),
		'pc' => array(
			'label'      => 'PC',
			'channel_id' => trim( (string) get_option( 'go_verge_video_channel_pc', get_theme_mod( 'go_video_channel_pc', '' ) ) ),
		),
		'mobile' => array(
			'label'      => 'Mobile',
			'channel_id' => trim( (string) get_option( 'go_verge_video_channel_mobile', get_theme_mod( 'go_video_channel_mobile', '' ) ) ),
		),
	);

	return apply_filters( 'go_verge_official_video_sources', $sources );
}

/**
 * Read a saved official feed without making readers wait for external HTTP.
 * A missing/expired cache queues one refresh per channel. Failure cooldown is
 * cached too; the last successful pool remains usable for at most seven days.
 */
function go_verge_fetch_official_video_source( $source_key, $source, $limit = 4 ) {
	$channel_id = isset( $source['channel_id'] ) ? trim( (string) $source['channel_id'] ) : '';
	if ( '' === $channel_id ) { return array(); }
	$key = 'go_video_channel_v1_' . md5( $channel_id );
	$record = get_transient( $key );
	if ( ! is_array( $record ) ) {
		$args = array( $channel_id );
		if ( ! wp_next_scheduled( 'go_verge_refresh_video_channel', $args ) ) {
			wp_schedule_single_event( time() + 5, 'go_verge_refresh_video_channel', $args );
		}
		$record = get_option( $key . '_stale', array() );
	}
	$saved_at = is_array( $record ) ? (int) ( $record['saved_at'] ?? 0 ) : 0;
	if ( ! $saved_at || time() - $saved_at > 7 * DAY_IN_SECONDS || empty( $record['items'] ) || ! is_array( $record['items'] ) ) {
		return array();
	}
	$items = array_slice( $record['items'], 0, max( 1, (int) $limit ) );
	$label = isset( $source['label'] ) ? trim( (string) $source['label'] ) : ucfirst( (string) $source_key );
	foreach ( $items as &$item ) {
		$item['channel'] = $label;
		$item['source'] = sanitize_key( $source_key );
	}
	unset( $item );
	return $items;
}

/** One bounded cron/CLI refresh; removed channels and duplicate workers do no HTTP. */
function go_verge_refresh_official_video_channel( $channel_id ) {
	if ( ! wp_doing_cron() && ! ( defined( 'WP_CLI' ) && WP_CLI ) ) { return; }
	$channel_id = trim( (string) $channel_id );
	if ( '' === $channel_id ) { return; }
	$source_key = '';
	$source = array();
	foreach ( (array) go_verge_official_video_sources() as $candidate_key => $candidate ) {
		if ( $channel_id === trim( (string) ( $candidate['channel_id'] ?? '' ) ) ) {
			$source_key = $candidate_key;
			$source = $candidate;
			break;
		}
	}
	if ( ! $source ) { return; }
	$key = 'go_video_channel_v1_' . md5( $channel_id );
	if ( is_array( get_transient( $key ) ) ) { return; }
	$lock = 'video_channel_' . md5( $channel_id );
	if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( $lock, 90 ) ) { return; }
	try {
		if ( is_array( get_transient( $key ) ) ) { return; }
		// One pool serves the lead and all channel lists, whatever their limits.
		$items = go_verge_request_official_video_source( $source_key, $source, 50 );
		if ( $items ) {
			$record = array( 'saved_at' => time(), 'items' => $items );
			update_option( $key . '_stale', $record, false );
			set_transient( $key, $record, 30 * MINUTE_IN_SECONDS );
		} else {
			$record = get_option( $key . '_stale', array() );
			set_transient( $key, is_array( $record ) ? $record : array(), 10 * MINUTE_IN_SECONDS );
		}
	} finally {
		go_verge_release_job_lock( $lock );
	}
}
add_action( 'go_verge_refresh_video_channel', 'go_verge_refresh_official_video_channel', 10, 1 );

/** Read and normalize Atom only in cron or an explicit WP-CLI context. */
function go_verge_request_official_video_source( $source_key, $source, $limit = 50 ) {
	if ( ! wp_doing_cron() && ! ( defined( 'WP_CLI' ) && WP_CLI ) ) { return array(); }
	$channel_id = isset( $source['channel_id'] ) ? trim( (string) $source['channel_id'] ) : '';
	$label      = isset( $source['label'] ) ? trim( (string) $source['label'] ) : ucfirst( (string) $source_key );
	if ( '' === $channel_id ) {
		return array();
	}

	$url      = add_query_arg( 'channel_id', $channel_id, 'https://www.youtube.com/feeds/videos.xml' );
	$response = wp_remote_get(
		$url,
		array(
			'timeout'     => 4,
			'redirection' => 3,
			'user-agent'  => 'Overdrive/' . ( defined( 'GO_VERGE_VERSION' ) ? GO_VERGE_VERSION : '1.0' ) . '; ' . home_url( '/' ),
		)
	);

	if ( is_wp_error( $response ) || 200 !== (int) wp_remote_retrieve_response_code( $response ) ) {
		return array();
	}

	$body = wp_remote_retrieve_body( $response );
	if ( '' === trim( $body ) || ! function_exists( 'simplexml_load_string' ) ) {
		return array();
	}

	$previous = libxml_use_internal_errors( true );
	$xml      = simplexml_load_string( $body );
	libxml_clear_errors();
	libxml_use_internal_errors( $previous );
	if ( false === $xml ) {
		return array();
	}
	$atom = $xml->children( 'http://www.w3.org/2005/Atom' );
	if ( empty( $atom->entry ) ) {
		return array();
	}

	$items = array();
	foreach ( $atom->entry as $entry ) {
		$yt       = $entry->children( 'http://www.youtube.com/xml/schemas/2015' );
		$video_id = isset( $yt->videoId ) ? trim( (string) $yt->videoId ) : '';
		if ( '' === $video_id || ! preg_match( '/^[A-Za-z0-9_-]{6,}$/', $video_id ) ) {
			continue;
		}

		$title     = trim( wp_strip_all_tags( (string) $entry->title ) );
		$published = strtotime( (string) $entry->published );
		$items[]   = array(
			'id'        => $video_id,
			'title'     => $title,
			'channel'   => $label,
			'source'    => sanitize_key( $source_key ),
			'published' => $published ? (int) $published : 0,
			'url'       => 'https://www.youtube.com/watch?v=' . rawurlencode( $video_id ),
			'thumbnail' => 'https://i.ytimg.com/vi/' . rawurlencode( $video_id ) . '/hqdefault.jpg',
		);

		if ( count( $items ) >= max( 1, (int) $limit ) ) {
			break;
		}
	}

	return $items;
}

/**
 * Cached official PlayStation, Xbox and Nintendo video feed.
 * A stale option keeps the module stable during temporary upstream failures.
 */
function go_verge_official_video_feed( $limit = 6 ) {
	$limit     = max( 1, (int) $limit );
	$cache_key = 'go_verge_official_video_feed_v2';
	$cached    = get_transient( $cache_key );
	if ( false !== $cached && is_array( $cached ) ) {
		return array_slice( $cached, 0, $limit );
	}

	$items = array();
	foreach ( go_verge_official_video_sources() as $source_key => $source ) {
		$items = array_merge( $items, go_verge_fetch_official_video_source( $source_key, $source, 4 ) );
	}

	if ( ! empty( $items ) ) {
		usort(
			$items,
			function ( $a, $b ) {
				return (int) ( $b['published'] ?? 0 ) <=> (int) ( $a['published'] ?? 0 );
			}
		);

		// Keep the feed genuinely multi-channel: reserve the newest item from
		// each available official source, then fill remaining slots by recency.
		$selected = array();
		$seen_ids = array();
		foreach ( array_keys( go_verge_official_video_sources() ) as $source_key ) {
			foreach ( $items as $item ) {
				if ( $source_key === ( $item['source'] ?? '' ) ) {
					$selected[] = $item;
					$seen_ids[] = (string) $item['id'];
					break;
				}
			}
		}
		foreach ( $items as $item ) {
			if ( count( $selected ) >= max( $limit, 8 ) ) {
				break;
			}
			if ( in_array( (string) $item['id'], $seen_ids, true ) ) {
				continue;
			}
			$selected[] = $item;
			$seen_ids[] = (string) $item['id'];
		}
		usort(
			$selected,
			function ( $a, $b ) {
				return (int) ( $b['published'] ?? 0 ) <=> (int) ( $a['published'] ?? 0 );
			}
		);
		$items = array_values( array_slice( $selected, 0, max( $limit, 8 ) ) );
		set_transient( $cache_key, $items, 30 * MINUTE_IN_SECONDS );
		update_option( 'go_verge_official_video_feed_stale', $items, false );
		return array_slice( $items, 0, $limit );
	}

	$stale = get_option( 'go_verge_official_video_feed_stale', array() );
	if ( is_array( $stale ) && ! empty( $stale ) ) {
		set_transient( $cache_key, $stale, 10 * MINUTE_IN_SECONDS );
		return array_slice( $stale, 0, $limit );
	}
	set_transient( $cache_key, array(), 10 * MINUTE_IN_SECONDS );
	return array();
}

/**
 * Local YouTube-backed article fallback for the homepage video hub.
 */
function go_verge_local_video_fallback_items( $limit = 6 ) {
	$query = go_verge_query_video_articles( max( 1, (int) $limit ) * 2 );
	$items = array();
	if ( ! $query->have_posts() ) {
		return $items;
	}

	foreach ( $query->posts as $post ) {
		$urls = array(
			get_post_meta( $post->ID, 'gamxo_youtube_link', true ),
			get_post_meta( $post->ID, '_go_trailer_url', true ),
			get_post_meta( $post->ID, 'go_trailer_url', true ),
		);
		$content = get_post_field( 'post_content', $post->ID );
		if ( preg_match( '~https?://(?:www\.)?(?:youtube\.com/watch\?[^\s"\']*v=[A-Za-z0-9_-]+|youtu\.be/[A-Za-z0-9_-]+)~i', (string) $content, $match ) ) {
			$urls[] = $match[0];
		}

		$video_id = '';
		foreach ( $urls as $url ) {
			$video_id = go_verge_youtube_video_id( $url );
			if ( $video_id ) {
				break;
			}
		}
		if ( ! $video_id ) {
			continue;
		}

		$items[] = array(
			'id'          => $video_id,
			'title'       => get_the_title( $post->ID ),
			'channel'     => __( 'Overdrive', 'go-verge' ),
			'source'      => 'overdrive',
			'published'   => (int) get_post_time( 'U', true, $post->ID ),
			'url'         => get_permalink( $post->ID ),
			'article_url' => get_permalink( $post->ID ),
			'post_id'     => (int) $post->ID,
			'is_article'  => true,
			'thumbnail'   => get_the_post_thumbnail_url( $post->ID, 'go_card' ) ?: 'https://i.ytimg.com/vi/' . rawurlencode( $video_id ) . '/hqdefault.jpg',
		);
		if ( count( $items ) >= max( 1, (int) $limit ) ) {
			break;
		}
	}

	return $items;
}

/**
 * Platform definitions used by the dedicated video hub.
 * Consoles are intentionally grouped under the five editorial platforms.
 */
function go_verge_video_platform_definitions() {
	return array(
		'xbox' => array(
			'label'   => 'Xbox',
			'aliases' => array( 'xbox', 'xbox-one', 'xbox-series', 'xbox-series-x-s', 'series-x', 'series-s' ),
		),
		'nintendo' => array(
			'label'   => 'Nintendo',
			'aliases' => array( 'nintendo', 'switch', 'nintendo-switch', 'switch-2', 'nintendo-switch-2' ),
		),
		'pc' => array(
			'label'   => 'PC',
			'aliases' => array( 'pc', 'computador', 'windows', 'steam', 'epic-games', 'gog' ),
		),
		'playstation' => array(
			'label'   => 'PlayStation',
			'aliases' => array( 'playstation', 'ps5', 'ps4', 'playstation-5', 'playstation-4' ),
		),
		'mobile' => array(
			'label'   => 'Mobile',
			'aliases' => array( 'mobile', 'celular', 'android', 'ios', 'iphone', 'ipad' ),
		),
	);
}

/**
 * Resolve the first YouTube video attached to an article.
 */
function go_verge_post_youtube_video_id( $post_id ) {
	$post_id = (int) $post_id;
	if ( $post_id <= 0 ) {
		return '';
	}

	$urls = array(
		get_post_meta( $post_id, 'gamxo_youtube_link', true ),
		get_post_meta( $post_id, '_go_trailer_url', true ),
		get_post_meta( $post_id, 'go_trailer_url', true ),
	);

	$content = (string) get_post_field( 'post_content', $post_id );
	if ( preg_match_all( '~https?://(?:www\.)?(?:youtube(?:-nocookie)?\.com/(?:watch\?[^\s"\']*v=|embed/|shorts/)|youtu\.be/)[A-Za-z0-9_-]+[^\s"\']*~i', $content, $matches ) ) {
		$urls = array_merge( $urls, (array) $matches[0] );
	}

	foreach ( $urls as $url ) {
		$video_id = go_verge_youtube_video_id( $url );
		if ( $video_id ) {
			return $video_id;
		}
	}

	return '';
}

/**
 * Normalize one article into the same item shape used by official channels.
 */
function go_verge_video_item_from_post( $post_id, $platform_key = '' ) {
	$post_id  = (int) $post_id;
	$video_id = go_verge_post_youtube_video_id( $post_id );
	if ( ! $video_id ) {
		return array();
	}

	$platforms = go_verge_video_platform_definitions();
	$channel   = isset( $platforms[ $platform_key ]['label'] ) ? $platforms[ $platform_key ]['label'] : __( 'Overdrive', 'go-verge' );

	return array(
		'id'          => $video_id,
		'title'       => get_the_title( $post_id ),
		'channel'     => $channel,
		'source'      => $platform_key ? sanitize_key( $platform_key ) : 'overdrive',
		'published'   => (int) get_post_time( 'U', true, $post_id ),
		'url'         => get_permalink( $post_id ),
		'article_url' => get_permalink( $post_id ),
		'post_id'     => $post_id,
		'is_article'  => true,
		'thumbnail'   => get_the_post_thumbnail_url( $post_id, 'go_card' ) ?: 'https://i.ytimg.com/vi/' . rawurlencode( $video_id ) . '/hqdefault.jpg',
	);
}

/**
 * Check categories and tags, including category parents, against a platform.
 */
function go_verge_post_matches_video_platform( $post_id, $platform_key ) {
	$platforms = go_verge_video_platform_definitions();
	if ( empty( $platforms[ $platform_key ] ) ) {
		return false;
	}

	$aliases = array_map( 'sanitize_title', (array) $platforms[ $platform_key ]['aliases'] );
	$terms   = array_merge(
		(array) wp_get_post_terms( $post_id, 'category' ),
		(array) wp_get_post_terms( $post_id, 'post_tag' )
	);

	foreach ( $terms as $term ) {
		if ( ! $term instanceof WP_Term ) {
			continue;
		}
		$candidates = array( sanitize_title( $term->slug ), sanitize_title( $term->name ) );
		if ( array_intersect( $aliases, $candidates ) ) {
			return true;
		}

		if ( 'category' === $term->taxonomy ) {
			$ancestors = get_ancestors( $term->term_id, 'category', 'taxonomy' );
			foreach ( $ancestors as $ancestor_id ) {
				$ancestor = get_term( $ancestor_id, 'category' );
				if ( $ancestor instanceof WP_Term && in_array( sanitize_title( $ancestor->slug ), $aliases, true ) ) {
					return true;
				}
			}
		}
	}

	return false;
}

/**
 * Recent article videos, optionally restricted to one of the five platforms.
 */
function go_verge_local_video_article_items( $limit = 18, $platform_key = '' ) {
	$limit        = max( 1, (int) $limit );
	$platform_key = sanitize_key( $platform_key );
	$cache_key    = 'go_verge_local_video_articles_v4_' . ( $platform_key ?: 'all' ) . '_' . $limit;
	$cached       = get_transient( $cache_key );
	if ( false !== $cached && is_array( $cached ) ) {
		return $cached;
	}

	$candidates = get_transient( 'go_verge_local_video_candidates_v4' );
	if ( false === $candidates || ! is_array( $candidates ) ) {
		$query = new WP_Query(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => 200,
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'orderby'             => 'date',
				'order'               => 'DESC',
				'fields'              => 'ids',
			)
		);

		$candidates = array();
		foreach ( (array) $query->posts as $post_id ) {
			$item = go_verge_video_item_from_post( $post_id );
			if ( empty( $item ) ) {
				continue;
			}
			$candidates[] = $item;
			if ( count( $candidates ) >= 80 ) {
				break;
			}
		}
		set_transient( 'go_verge_local_video_candidates_v4', $candidates, 15 * MINUTE_IN_SECONDS );
	}

	$items = array();
	foreach ( $candidates as $item ) {
		$post_id = isset( $item['post_id'] ) ? (int) $item['post_id'] : 0;
		if ( $platform_key && ( ! $post_id || ! go_verge_post_matches_video_platform( $post_id, $platform_key ) ) ) {
			continue;
		}
		if ( $platform_key ) {
			$platforms       = go_verge_video_platform_definitions();
			$item['source']  = $platform_key;
			$item['channel'] = isset( $platforms[ $platform_key ]['label'] ) ? $platforms[ $platform_key ]['label'] : $item['channel'];
		}
		$items[] = $item;
		if ( count( $items ) >= $limit ) {
			break;
		}
	}

	set_transient( $cache_key, $items, 15 * MINUTE_IN_SECONDS );
	return $items;
}

/**
 * Merge the official platform channel with article videos for the same platform.
 */
function go_verge_platform_video_items( $platform_key, $limit = 6 ) {
	$platform_key = sanitize_key( $platform_key );
	$limit        = max( 1, (int) $limit );
	$sources      = go_verge_official_video_sources();
	$items        = array();

	if ( ! empty( $sources[ $platform_key ] ) ) {
		$items = go_verge_fetch_official_video_source( $platform_key, $sources[ $platform_key ], $limit );
		foreach ( $items as &$item ) {
			$item['is_article'] = false;
		}
		unset( $item );
	}

	$items = array_merge( $items, go_verge_local_video_article_items( $limit, $platform_key ) );
	$unique = array();
	foreach ( $items as $item ) {
		$key = ! empty( $item['id'] ) ? (string) $item['id'] : md5( wp_json_encode( $item ) );
		if ( isset( $unique[ $key ] ) ) {
			continue;
		}
		$unique[ $key ] = $item;
	}

	$items = array_values( $unique );
	usort(
		$items,
		function ( $a, $b ) {
			return (int) ( $b['published'] ?? 0 ) <=> (int) ( $a['published'] ?? 0 );
		}
	);

	return array_slice( $items, 0, $limit );
}

/**
 * Combined platform-channel items for the lead player on /videos/.
 */
function go_verge_all_platform_video_items( $limit_per_platform = 3 ) {
	$items = array();
	foreach ( array_keys( go_verge_video_platform_definitions() ) as $platform_key ) {
		$items = array_merge( $items, go_verge_platform_video_items( $platform_key, $limit_per_platform ) );
	}

	$unique = array();
	foreach ( $items as $item ) {
		if ( empty( $item['id'] ) ) {
			continue;
		}
		$unique[ (string) $item['id'] ] = $item;
	}
	$items = array_values( $unique );
	usort(
		$items,
		function ( $a, $b ) {
			return (int) ( $b['published'] ?? 0 ) <=> (int) ( $a['published'] ?? 0 );
		}
	);
	return $items;
}

/**
 * Final homepage video items with resilient local fallback.
 */
function go_verge_home_video_items( $limit = 6 ) {
	$items = go_verge_official_video_feed( $limit );
	if ( ! empty( $items ) ) {
		return $items;
	}
	return go_verge_local_video_fallback_items( $limit );
}

/**
 * Authorial Overdrive player for the homepage.
 */
function go_verge_render_home_video_hub( $items ) {
	$items = array_values( array_filter( (array) $items ) );
	if ( empty( $items ) ) {
		return;
	}
	$lead = $items[0];
	?>
	<div class="go-video-hub" data-go-video-hub>
		<div class="go-video-hub__player">
			<div class="go-video-hub__chrome">
				<span class="go-video-hub__brand">OVERDRIVE / VÍDEO</span>
				<span class="go-video-hub__source" data-go-video-source><?php echo esc_html( $lead['channel'] ); ?></span>
			</div>
			<div class="go-video-hub__stage">
				<iframe
					data-go-video-frame
					src="<?php echo esc_url( 'https://www.youtube-nocookie.com/embed/' . rawurlencode( $lead['id'] ) . '?rel=0&modestbranding=1' ); ?>"
					title="<?php echo esc_attr( $lead['title'] ); ?>"
					width="1280"
					height="720"
					loading="lazy"
					referrerpolicy="strict-origin-when-cross-origin"
					allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
					allowfullscreen
				></iframe>
			</div>
			<div class="go-video-hub__now">
				<span class="go-video-hub__now-label"><?php esc_html_e( 'Agora no player', 'go-verge' ); ?></span>
				<h3 data-go-video-title><?php echo esc_html( $lead['title'] ); ?></h3>
			</div>
		</div>
		<div class="go-video-hub__playlist" aria-label="<?php esc_attr_e( 'Lista de vídeos', 'go-verge' ); ?>">
			<?php foreach ( $items as $index => $item ) : ?>
				<button
					type="button"
					class="go-video-hub__item<?php echo 0 === $index ? ' is-active' : ''; ?>"
					data-go-video-item
					data-video-id="<?php echo esc_attr( $item['id'] ); ?>"
					data-video-title="<?php echo esc_attr( $item['title'] ); ?>"
					data-video-source="<?php echo esc_attr( $item['channel'] ); ?>"
					aria-pressed="<?php echo 0 === $index ? 'true' : 'false'; ?>"
				>
					<span class="go-video-hub__thumb">
						<img src="<?php echo esc_url( $item['thumbnail'] ); ?>" alt="" width="480" height="270" loading="lazy" decoding="async">
						<span class="go-video-hub__play" aria-hidden="true">▶</span>
					</span>
					<span class="go-video-hub__item-copy">
						<span class="go-video-hub__channel"><?php echo esc_html( $item['channel'] ); ?></span>
						<strong><?php echo esc_html( $item['title'] ); ?></strong>
					</span>
				</button>
			<?php endforeach; ?>
		</div>
	</div>
	<?php
}

/**
 * Render the Nuuvem coupon radar using persisted radar data when available,
 * falling back to go_promotion records. No external data is invented.
 */
function go_verge_render_nuuvem_radar() {
	$stored = get_option( 'go_promotion_coupon_radar', array() );
	$coupons = array();
	$merchant_url = '';

	if ( is_array( $stored ) && ! empty( $stored ) && '0' !== (string) ( $stored['enabled'] ?? '1' ) ) {
		$merchant_url = esc_url_raw( (string) ( $stored['merchant_url'] ?? '' ) );
		foreach ( (array) ( $stored['coupons'] ?? array() ) as $row ) {
			if ( ! is_array( $row ) ) {
				continue;
			}
			$code = trim( (string) ( $row['code'] ?? '' ) );
			$description = trim( (string) ( $row['description'] ?? $row['note'] ?? '' ) );
			$url = esc_url_raw( (string) ( $row['url'] ?? $merchant_url ) );
			if ( '' === $code && '' === $description ) {
				continue;
			}
			$coupons[] = array(
				'code'        => $code,
				'description' => $description,
				'url'         => $url,
				'label'       => trim( (string) ( $row['cta_label'] ?? 'Abrir oferta' ) ),
			);
			if ( count( $coupons ) >= 6 ) {
				break;
			}
		}
	}

	if ( ! empty( $coupons ) ) {
		?>
		<section class="go-promo-radar" aria-labelledby="go-promo-radar-title">
			<div class="go-section__head"><h2 id="go-promo-radar-title" class="go-section__title"><?php esc_html_e( 'Cupons da Nuuvem', 'go-verge' ); ?></h2></div>
			<div class="go-promo-radar__list">
				<?php foreach ( $coupons as $coupon ) : ?>
					<article class="go-promo-radar__item">
						<?php if ( $coupon['code'] ) : ?><strong class="go-promo-radar__code"><?php echo esc_html( $coupon['code'] ); ?></strong><?php endif; ?>
						<?php if ( $coupon['description'] ) : ?><p><?php echo esc_html( $coupon['description'] ); ?></p><?php endif; ?>
						<?php if ( $coupon['url'] ) : ?><a class="go-btn go-btn--outline-mint" href="<?php echo esc_url( $coupon['url'] ); ?>" target="_blank" rel="nofollow sponsored noopener"><?php echo esc_html( $coupon['label'] ?: __( 'Abrir oferta', 'go-verge' ) ); ?></a><?php endif; ?>
					</article>
				<?php endforeach; ?>
			</div>
		</section>
		<?php
		return;
	}

	$query = new WP_Query(
		array(
			'post_type'      => 'go_promotion',
			'post_status'    => 'publish',
			'posts_per_page' => 24,
			'no_found_rows'  => true,
			'meta_query'     => array(
				array(
					'key'     => 'go_promotion_store_name',
					'value'   => 'Nuuvem',
					'compare' => 'LIKE',
				),
			),
		)
	);

	if ( function_exists('go_verge_filter_current_promotion_query') ) {
		$query = go_verge_filter_current_promotion_query($query,6);
	}
	if ( ! $query->have_posts() ) {
		return;
	}
	?>
	<section class="go-promo-radar" aria-labelledby="go-promo-radar-title">
		<div class="go-section__head"><h2 id="go-promo-radar-title" class="go-section__title"><?php esc_html_e( 'Cupons da Nuuvem', 'go-verge' ); ?></h2></div>
		<div class="go-promo-radar__list">
			<?php while ( $query->have_posts() ) : $query->the_post(); ?>
				<?php
				$offer_url  = trim( (string) get_post_meta( get_the_ID(), 'go_promotion_offer_url', true ) );
				$sale_price = trim( (string) get_post_meta( get_the_ID(), 'go_promotion_sale_price', true ) );
				$valid      = trim( (string) get_post_meta( get_the_ID(), 'go_promotion_valid_until', true ) );
				$button     = trim( (string) get_post_meta( get_the_ID(), 'go_promotion_button_label', true ) );
				?>
				<article class="go-promo-radar__item">
					<h3><a href="<?php echo esc_url( $offer_url ? $offer_url : get_permalink() ); ?>"<?php echo $offer_url ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?>><?php the_title(); ?></a></h3>
					<?php if ( $sale_price || $valid ) : ?><p class="go-promo-radar__meta"><?php echo esc_html( trim( $sale_price . ( $sale_price && $valid ? ' · ' : '' ) . ( $valid ? 'Até ' . $valid : '' ) ) ); ?></p><?php endif; ?>
					<a class="go-btn go-btn--outline-mint" href="<?php echo esc_url( $offer_url ? $offer_url : get_permalink() ); ?>"<?php echo $offer_url ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?>><?php echo esc_html( $button ?: __( 'Abrir oferta', 'go-verge' ) ); ?></a>
				</article>
			<?php endwhile; wp_reset_postdata(); ?>
		</div>
	</section>
	<?php
}


/**
 * Reject noisy marketplace text before it reaches the public coupon area.
 * Automatic marketplace coupons need a clear benefit and compact context.
 */
function go_verge_coupon_public_quality( $merchant_key, $row ) {
	if ( ! is_array( $row ) ) { return 0; }
	$source = sanitize_key( (string) ( $row['source'] ?? '' ) );
	$kind   = sanitize_key( (string) ( $row['kind'] ?? '' ) );
	$code   = strtoupper( preg_replace( '/[^A-Z0-9_-]/i', '', trim( (string) ( $row['code'] ?? '' ) ) ) );
	$desc   = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) ( $row['description'] ?? $row['note'] ?? '' ) ) ) );
	$manual = in_array( $source, array( 'manual', 'verified' ), true );

	if ( 'nuuvem' === $merchant_key ) {
		if ( ! $code && ! $desc ) { return 0; }
		if ( ! $code && ( 'activation' !== $kind || ! preg_match( '/cupom|voucher|coupon/iu', $desc ) || ! preg_match( '/\d\s*%|R\$\s*\d|frete\s+gr[aá]tis/iu', $desc ) ) ) { return 0; }
		return 160 + ( $code ? 25 : 0 );
	}

	$length = function_exists( 'mb_strlen' ) ? mb_strlen( $desc ) : strlen( $desc );
	if ( $manual ) {
		return ( $code || $desc ) ? 260 : 0;
	}
	if ( $length < 10 || $length > 180 ) { return 0; }
	if ( count( preg_split( '/\s+/u', $desc ) ) > 24 ) { return 0; }

	$plain = remove_accents( strtolower( $desc ) );
	if ( preg_match( '/pagina anterior|proxima pagina|avaliacoes|mais vendido|ficha tecnica|videos? em 4k|\bip6[78]\b|\b\d+\s*(?:gb|mp|mah|polegadas|pol)\b/', $plain ) ) { return 0; }
	if ( preg_match( '/\b\d+x\s*r\$|sem juros|por ser sua primeira compra.*oferta relampago|oferta relampago.*termina em/', $plain ) ) { return 0; }

	$price_count = preg_match_all( '/R\$\s*\d[\d.]*,?\d*/u', $desc, $prices );
	if ( $price_count > 1 ) { return 0; }
	$percent_count = preg_match_all( '/(?<!\d)(?:\d{1,2}|100)\s*%(?!\d)/u', $desc, $percents );
	if ( $percent_count > 1 || preg_match( '/(?<!\d)\d{3,}\s*%/u', $desc ) ) { return 0; }

	$digits = preg_replace( '/\D/u', '', $desc );
	if ( strlen( $digits ) > max( 12, (int) floor( $length * 0.28 ) ) ) { return 0; }

	$benefit = 0;
	if ( preg_match( '/(?<!\d)(\d{1,2}|100)\s*%(?!\d)/u', $desc, $m ) ) {
		$percent = absint( $m[1] );
		if ( $percent > 0 && $percent <= 100 ) { $benefit += 35 + min( 35, (int) floor( $percent / 2 ) ); }
	}
	if ( preg_match( '/R\$\s*(\d{1,4})(?:[.,]\d{2})?/u', $desc, $m ) ) {
		$value = absint( $m[1] );
		if ( $value > 0 && $value <= 2000 ) { $benefit += 28 + min( 30, (int) floor( $value / 20 ) ); }
	}
	if ( preg_match( '/frete\s+gr[aá]tis|primeira\s+compra|produtos?\s+selecionados|acima\s+de\s+R\$/iu', $desc ) ) { $benefit += 12; }

	$blacklist = array(
		'JUROS','GRATIS','FRETE','PRIMEIRA','COMPRA','PAGINA','ANTERIOR','PROXIMA','ELETRONICOS','INFORMATICA',
		'TABLETS','LAPTOPS','OFF','PIX','SALDO','PRODUTO','PRODUTOS','SELECIONADOS','VENDIDO','MAISVENDIDO','RELAMPAGO',
	);
	if ( $code && in_array( $code, $blacklist, true ) ) { return 0; }

	if ( 'activation' === $kind || ! $code ) {
		if ( $benefit <= 0 || ! preg_match( '/\b(?:cupom|coupon|voucher|desconto|off)\b/iu', $desc ) ) { return 0; }
	} else {
		if ( strlen( $code ) < 4 || strlen( $code ) > 24 ) { return 0; }
		if ( ! preg_match( '/\d/', $code ) && $benefit <= 0 ) { return 0; }
	}

	return 70 + $benefit + ( $code ? 30 : 0 ) + ( in_array( $source, array( 'embedded_data', 'embedded_context' ), true ) ? 18 : 0 );
}

/**
 * Human-friendly coupon description. Scraped feeds chegam com fragmentos de
 * navegação colados ("…Itens para CasaCondiçõesConferir produtosArteecasa"),
 * percentual por extenso ("60 Por cento OFF") e aberturas truncadas
 * ("ivulgação até às 23h59…"). O card precisa ler como uma linha editorial.
 *
 * @param string $description Raw stored description.
 * @param int    $words       Maximum words for display.
 * @return string
 */
function go_verge_coupon_display_description( $description, $words = 18 ) {
	$text = trim( preg_replace( '/\s+/u', ' ', wp_strip_all_tags( (string) $description ) ) );
	if ( '' === $text ) {
		return '';
	}

	// Pontuação/aspas perdidas no início do texto raspado.
	$text = preg_replace( '/^[\s"\'\x{201C}\x{201D}\x{2018}\x{2019}`´\-\x{2013}\x{2014}.,:;]+/u', '', $text );

	// "60 Por cento OFF" → "60% OFF".
	$text = preg_replace( '/(\d{1,3})\s*por\s*cento/iu', '$1%', $text );

	// Corta a navegação/regulamento colados após o benefício — inclusive quando
	// o marcador chega grudado na palavra anterior ("CasaCondiçõesConferir…").
	$text = preg_replace(
		'/\s*(?:condi[cç][oõ]es|conferir\s*(?:produtos?|ofertas?)|ver\s*(?:produtos?|ofertas?|regulamento)|regulamento|termos\s+de\s+uso|saiba\s+mais|aproveitar?\s+(?:agora|a\s+oferta)|compre\s+agora|acesse\s+o\s+site|clique\s+aqui).*$/iu',
		'',
		$text
	);

	// Abertura truncada pelo raspador: prefere a primeira frase inteira que
	// descreve o benefício ("Desconto de até 12%…").
	if ( preg_match( '/^\p{Ll}/u', $text ) ) {
		$sentences = preg_split( '/(?<=[.!?])\s+/u', $text );
		if ( is_array( $sentences ) && count( $sentences ) > 1 ) {
			foreach ( $sentences as $index => $sentence ) {
				if ( preg_match( '/^\p{Lu}/u', $sentence ) && preg_match( '/desconto|cupom|%|r\$|frete|off\b/iu', $sentence ) ) {
					$text = implode( ' ', array_slice( $sentences, $index ) );
					break;
				}
			}
		}
	}
	if ( preg_match( '/^(\p{Ll})/u', $text, $go_first ) && function_exists( 'mb_strtoupper' ) && function_exists( 'mb_substr' ) ) {
		$text = mb_strtoupper( $go_first[1] ) . mb_substr( $text, 1 );
	}

	// Conectores capitalizados no meio da frase pelas headings raspadas.
	$text = preg_replace_callback(
		'/\s(Em|De|Do|Da|Dos|Das|Para|Com|Ou|No|Na|Nos|Nas)\s/u',
		static function ( $m ) {
			return ' ' . ( function_exists( 'mb_strtolower' ) ? mb_strtolower( $m[1] ) : strtolower( $m[1] ) ) . ' ';
		},
		$text
	);

	$text = trim( preg_replace( '/\s+/u', ' ', $text ), " \t.,;:-" );
	if ( '' === $text ) {
		return '';
	}

	return sanitize_text_field( wp_trim_words( $text, max( 6, (int) $words ) ) );
}

/**
 * Build one normalized coupon stream for the public promotions hub.
 * Verified/manual records win, then stronger discounts, then coded coupons.
 */
function go_verge_coupon_center_items() {
	$items = array();
	$push  = static function ( $merchant_key, $merchant_label, $row, $fallback_url = '' ) use ( &$items ) {
		if ( ! is_array( $row ) ) {
			return;
		}
		if ( function_exists( 'go_verge_coupon_is_current' ) && ! go_verge_coupon_is_current( $row ) ) { return; }
		$code        = trim( (string) ( $row['code'] ?? '' ) );
		$description = trim( wp_strip_all_tags( (string) ( $row['description'] ?? $row['note'] ?? '' ) ) );
		$url         = esc_url_raw( (string) ( $row['url'] ?? $fallback_url ) );
		$kind        = sanitize_key( (string) ( $row['kind'] ?? ( $code ? 'code' : 'activation' ) ) );
		$source      = sanitize_key( (string) ( $row['source'] ?? '' ) );
		if ( ! $url || ! wp_http_validate_url( $url ) ) { return; }
		$quality     = go_verge_coupon_public_quality( $merchant_key, $row );
		// Marketplace discovery is intentionally conservative on the public page.
		// Weak automatic candidates stay in diagnostics instead of becoming cards.
		$minimum_quality = in_array( $source, array( 'manual', 'verified' ), true ) ? 1 : ( 'nuuvem' === $merchant_key ? 70 : 110 );
		if ( $quality < $minimum_quality || ( '' === $code && '' === $description ) ) {
			return;
		}
		$description = go_verge_coupon_display_description( $description );
		if ( 'activation' !== $kind ) {
			$kind = $code ? 'code' : 'activation';
		}

		$score = $quality;
		if ( 'manual' === $source || 'verified' === $source ) {
			$score += 120;
		}
		if ( $code ) {
			$score += 18;
		}
		if ( preg_match( '/(?<!\d)(\d{1,2}|100)\s*%(?!\d)/u', $description, $m ) ) {
			$score += min( 90, absint( $m[1] ) );
		}
		if ( preg_match( '/R\$\s*([\d.]+)(?:,\d{2})?/u', $description, $m ) ) {
			$money = (float) str_replace( '.', '', $m[1] );
			$score += min( 60, (int) floor( $money / 5 ) );
		}

		$key = $merchant_key . '|' . ( $code ? strtoupper( $code ) : md5( strtolower( $description . '|' . $url ) ) );
		if ( isset( $items[ $key ] ) && (int) $items[ $key ]['score'] >= $score ) { return; }
		$items[ $key ] = array(
			'merchant'       => sanitize_key( $merchant_key ),
			'merchant_label' => $merchant_label,
			'code'           => $code,
			'description'    => $description,
			'url'            => $url,
			'kind'           => $kind,
			'source'         => $source,
			'quality'        => $quality,
			'score'          => $score,
			'valid_until'    => (string) ( $row['valid_until'] ?? $row['expires_at'] ?? '' ),
			'checked_at'     => (string) ( $row['checked_at'] ?? $row['verified_at'] ?? '' ),
			'source_url'     => (string) ( $row['source_url'] ?? $url ),
		);
	};

	$nuuvem = get_option( 'go_promotion_coupon_radar', array() );
	if ( is_array( $nuuvem ) && '0' !== (string) ( $nuuvem['enabled'] ?? '1' ) ) {
		$merchant_url = esc_url_raw( (string) ( $nuuvem['merchant_url'] ?? '' ) );
		foreach ( (array) ( $nuuvem['coupons'] ?? array() ) as $row ) {
			$push( 'nuuvem', 'Nuuvem', $row, $merchant_url );
		}
	}

	// Preserve a real Nuuvem fallback when the persisted radar is empty.
	$has_nuuvem = false;
	foreach ( $items as $item ) {
		if ( 'nuuvem' === $item['merchant'] ) { $has_nuuvem = true; break; }
	}
	if ( ! $has_nuuvem ) {
		$query = new WP_Query( array(
			'post_type'      => 'go_promotion',
			'post_status'    => 'publish',
			'posts_per_page' => 6,
			'no_found_rows'  => true,
			'meta_query'     => array( array( 'key' => 'go_promotion_store_name', 'value' => 'Nuuvem', 'compare' => 'LIKE' ) ),
		) );
		foreach ( $query->posts as $post ) {
			if ( ! get_post_meta( $post->ID, 'go_promotion_coupon_code', true ) || ( function_exists( 'go_verge_promotion_is_current' ) && ! go_verge_promotion_is_current( $post->ID ) ) ) { continue; }
			$push( 'nuuvem', 'Nuuvem', array(
				'code'        => get_post_meta( $post->ID, 'go_promotion_coupon_code', true ),
				'description' => get_the_title( $post ),
				'url'         => get_post_meta( $post->ID, 'go_promotion_offer_url', true ) ?: get_permalink( $post ),
				'kind'        => get_post_meta( $post->ID, 'go_promotion_coupon_code', true ) ? 'code' : 'activation',
				'source'      => 'manual',
				'valid_until' => get_post_meta( $post->ID, 'go_promotion_valid_until', true ),
				'verified_at' => get_post_field( 'post_modified_gmt', $post->ID ),
			) );
		}
		wp_reset_postdata();
	}


	/*
	 * V19: promotion records with a real coupon code are editorially managed
	 * coupons too. Previously only Nuuvem CPT records entered this stream,
	 * which made Amazon/Mercado Livre/other store coupons disappear even when
	 * they existed in WordPress.
	 */
	if ( post_type_exists( 'go_promotion' ) ) {
		$coupon_posts = get_posts( array(
			'post_type'      => 'go_promotion',
			'post_status'    => 'publish',
			'posts_per_page' => 24,
			'no_found_rows'  => true,
			'meta_query'     => array(
				array(
					'key'     => 'go_promotion_coupon_code',
					'value'   => '',
					'compare' => '!=',
				),
			),
			'orderby' => 'date',
			'order'   => 'DESC',
		) );
		foreach ( $coupon_posts as $coupon_post ) {
			if ( function_exists( 'go_verge_promotion_is_current' ) && ! go_verge_promotion_is_current( $coupon_post->ID ) ) { continue; }
			$store_raw = trim( (string) get_post_meta( $coupon_post->ID, 'go_promotion_store_name', true ) );
			$store_label = function_exists( 'go_verge_v19_store_label' ) ? go_verge_v19_store_label( $store_raw ) : $store_raw;
			if ( '' === $store_label ) { continue; }
			$store_key = sanitize_key( str_replace( '-', '', sanitize_title( $store_label ) ) );
			$push( $store_key, $store_label, array(
				'code'        => get_post_meta( $coupon_post->ID, 'go_promotion_coupon_code', true ),
				'description' => get_the_title( $coupon_post->ID ),
				'url'         => get_post_meta( $coupon_post->ID, 'go_promotion_offer_url', true ) ?: get_permalink( $coupon_post->ID ),
				'kind'        => 'code',
				'source'      => 'manual',
				'valid_until' => get_post_meta( $coupon_post->ID, 'go_promotion_valid_until', true ),
				'verified_at' => get_post_field( 'post_modified_gmt', $coupon_post->ID ),
			) );
		}
	}

	$marketplaces = get_option( 'go_promotion_marketplace_coupons', array() );
	$merchant_map = array(
		'amazon'       => 'Amazon',
		'mercadolivre' => 'Mercado Livre',
	);
	foreach ( $merchant_map as $merchant_key => $merchant_label ) {
		$merchant = isset( $marketplaces[ $merchant_key ] ) && is_array( $marketplaces[ $merchant_key ] ) ? $marketplaces[ $merchant_key ] : array();
		$fallback = esc_url_raw( (string) ( $merchant['merchant_url'] ?? '' ) );
		foreach ( (array) ( $merchant['coupons'] ?? array() ) as $row ) {
			$push( $merchant_key, $merchant_label, $row, $fallback );
		}
	}

	$items = array_values( $items );
	usort( $items, static function ( $a, $b ) {
		if ( (int) $a['score'] === (int) $b['score'] ) {
			return strcmp( $a['merchant_label'], $b['merchant_label'] );
		}
		return (int) $b['score'] <=> (int) $a['score'];
	} );
	$selected = array();
	$per_merchant = array();
	foreach ( $items as $item ) {
		$key = (string) $item['merchant'];
		if ( (int) ( $per_merchant[ $key ] ?? 0 ) >= 2 ) { continue; }
		$selected[] = $item;
		$per_merchant[ $key ] = (int) ( $per_merchant[ $key ] ?? 0 ) + 1;
		if ( count( $selected ) >= 6 ) { break; }
	}
	return $selected;
}

/**
 * Accessible coupon center: merchant filters, one-click copy and activation
 * actions without inventing a code when the retailer exposes none.
 */
function go_verge_render_coupon_center() {
	$items = go_verge_coupon_center_items();
	if ( empty( $items ) ) {
		echo '<section class="go-coupon-center" aria-labelledby="go-coupon-center-title">';
		echo '<div class="go-coupon-center__head"><h2 id="go-coupon-center-title" class="go-section__title">' . esc_html__( 'Cupons de promoções', 'go-verge' ) . '</h2></div>';
		echo '<p class="go-coupon-center__empty">' . esc_html__( 'Nenhum cupom com confirmação recente está disponível agora.', 'go-verge' ) . '</p>';
		echo '</section>';
		return;
	}

	$counts = array();
	foreach ( $items as $item ) {
		$counts[ $item['merchant'] ] = (int) ( $counts[ $item['merchant'] ] ?? 0 ) + 1;
	}
	$labels = array();
	foreach ( $items as $item ) {
		$labels[ (string) $item['merchant'] ] = (string) $item['merchant_label'];
	}
	?>
	<section class="go-coupon-center" data-go-coupon-center aria-labelledby="go-coupon-center-title">
		<div class="go-coupon-center__head">
			<h2 id="go-coupon-center-title" class="go-section__title"><?php esc_html_e( 'Cupons de promoções', 'go-verge' ); ?></h2>
			<div class="go-coupon-center__filters" role="group" aria-label="<?php esc_attr_e( 'Filtrar cupons por loja', 'go-verge' ); ?>">
				<button type="button" class="is-active" data-go-coupon-filter="all" aria-pressed="true"><?php esc_html_e( 'Todos', 'go-verge' ); ?></button>
				<?php foreach ( $labels as $key => $label ) : if ( empty( $counts[ $key ] ) ) { continue; } ?>
					<button type="button" data-go-coupon-filter="<?php echo esc_attr( $key ); ?>" aria-pressed="false"><?php echo esc_html( $label ); ?></button>
				<?php endforeach; ?>
			</div>
		</div>
		<div class="go-coupon-center__grid">
			<?php foreach ( $items as $index => $coupon ) : ?>
				<article class="go-coupon-card<?php echo 'activation' === $coupon['kind'] ? ' is-activation' : ''; ?>" data-go-coupon-merchant="<?php echo esc_attr( $coupon['merchant'] ); ?>">
					<div class="go-coupon-card__top">
						<span class="go-coupon-card__merchant go-coupon-card__merchant--<?php echo esc_attr( $coupon['merchant'] ); ?>"><?php echo esc_html( $coupon['merchant_label'] ); ?></span>
						<?php if ( 'manual' === $coupon['source'] || 'verified' === $coupon['source'] ) : ?><span class="go-coupon-card__verified"><?php esc_html_e( 'Verificado', 'go-verge' ); ?></span><?php endif; ?>
					</div>
					<?php if ( $coupon['description'] ) : ?><p class="go-coupon-card__description"><?php echo esc_html( $coupon['description'] ); ?></p><?php endif; ?>
					<?php if ( $coupon['code'] ) : ?>
						<div class="go-coupon-card__code-row">
							<code><?php echo esc_html( $coupon['code'] ); ?></code>
							<button type="button" class="go-coupon-card__copy" data-go-copy-coupon data-coupon-code="<?php echo esc_attr( $coupon['code'] ); ?>" aria-label="<?php echo esc_attr( sprintf( __( 'Copiar cupom %s', 'go-verge' ), $coupon['code'] ) ); ?>"><?php esc_html_e( 'Copiar', 'go-verge' ); ?></button>
						</div>
					<?php endif; ?>
					<?php if ( $coupon['url'] ) : ?>
						<a class="go-coupon-card__action" href="<?php echo esc_url( $coupon['url'] ); ?>" target="_blank" rel="nofollow sponsored noopener"><?php echo esc_html( $coupon['code'] ? __( 'Ir para a loja', 'go-verge' ) : __( 'Ativar cupom', 'go-verge' ) ); ?><span aria-hidden="true">→</span></a>
					<?php endif; ?>
				</article>
			<?php endforeach; ?>
		</div>
		<p class="go-sr-only" data-go-coupon-status aria-live="polite" aria-atomic="true"></p>
	</section>
	<?php
}

/**
 * Render verified/discovered marketplace coupons synced by the promotion
 * engine. Empty merchants stay hidden instead of showing filler cards.
 */
function go_verge_render_marketplace_coupons() {
	$stored = get_option( 'go_promotion_marketplace_coupons', array() );
	if ( ! is_array( $stored ) || empty( $stored ) ) {
		return;
	}

	$headings = array(
		'amazon'       => 'Cupons da Amazon',
		'mercadolivre' => 'Cupons do Mercado Livre',
	);

	foreach ( $headings as $key => $heading ) {
		$merchant = isset( $stored[ $key ] ) && is_array( $stored[ $key ] ) ? $stored[ $key ] : array();
		$coupons  = isset( $merchant['coupons'] ) && is_array( $merchant['coupons'] ) ? $merchant['coupons'] : array();
		if ( empty( $coupons ) ) {
			continue;
		}
		$section_id = 'go-coupons-' . sanitize_html_class( $key );
		?>
		<section class="go-promo-radar go-promo-radar--marketplace" aria-labelledby="<?php echo esc_attr( $section_id ); ?>">
			<div class="go-section__head"><h2 id="<?php echo esc_attr( $section_id ); ?>" class="go-section__title"><?php echo esc_html( $heading ); ?></h2></div>
			<div class="go-promo-radar__list">
				<?php foreach ( array_slice( $coupons, 0, 6 ) as $coupon ) : ?>
					<?php
					$code = trim( (string) ( $coupon['code'] ?? '' ) );
					$description = go_verge_coupon_display_description( $coupon['description'] ?? '', 22 );
					$kind = sanitize_key( (string) ( $coupon['kind'] ?? ( $code ? 'code' : 'activation' ) ) );
					$url = esc_url_raw( (string) ( $coupon['url'] ?? $merchant['merchant_url'] ?? '' ) );
					if ( '' === $code && '' === $description ) { continue; }
					?>
					<article class="go-promo-radar__item<?php echo 'activation' === $kind ? ' is-activation' : ''; ?>">
						<?php if ( $code ) : ?><strong class="go-promo-radar__code"><?php echo esc_html( $code ); ?></strong><?php endif; ?>
						<?php if ( $description ) : ?><p><?php echo esc_html( $description ); ?></p><?php endif; ?>
						<?php if ( $url ) : ?><a class="go-btn go-btn--outline-mint" href="<?php echo esc_url( $url ); ?>" target="_blank" rel="nofollow sponsored noopener"><?php echo esc_html( $code ? __( 'Usar cupom', 'go-verge' ) : __( 'Abrir cupom', 'go-verge' ) ); ?></a><?php endif; ?>
					</article>
				<?php endforeach; ?>
			</div>
		</section>
		<?php
	}
}
