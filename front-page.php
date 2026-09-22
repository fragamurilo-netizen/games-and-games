<?php
/**
 * Overdrive homepage.
 *
 * The layout keeps the new theme's visual system and brings back the useful
 * editorial modules from the previous site without recreating its CSS debt.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/* Homepage editorial distribution context. Search-first categories are filtered
 * by inc/homepage-search-only.php without changing indexability or archives. */
$GLOBALS['go_verge_homepage_query_context'] = true;

/**
 * Resolve the first existing category from a list of possible slugs.
 */
if ( ! function_exists( 'go_verge_homepage_term' ) ) {
	function go_verge_homepage_term( $slugs ) {
		foreach ( (array) $slugs as $slug ) {
			$term = get_term_by( 'slug', sanitize_title( (string) $slug ), 'category' );
			if ( $term instanceof WP_Term ) {
				return $term;
			}
		}
		return null;
	}
}

/**
 * Resolve an editorial destination. Real category archives have priority over
 * WordPress Pages because several legacy placeholder pages are intentionally
 * empty and must never win over the content archive. A Page remains a safe
 * fallback when no matching category exists.
 */
if ( ! function_exists( 'go_verge_homepage_url' ) ) {
	function go_verge_homepage_url( $page_slugs = array(), $category_slugs = array(), $fallback = '' ) {
		$term = go_verge_homepage_term( $category_slugs );
		if ( $term instanceof WP_Term ) {
			$link = get_term_link( $term );
			if ( ! is_wp_error( $link ) ) {
				return $link;
			}
		}

		foreach ( (array) $page_slugs as $slug ) {
			$page = get_page_by_path( sanitize_title( (string) $slug ) );
			if ( $page instanceof WP_Post ) {
				return get_permalink( $page );
			}
		}

		return $fallback ? $fallback : home_url( '/' );
	}
}

/**
 * Query posts belonging to any matching category slug and register them as
 * already shown. Child categories are included, which is important for the
 * site's editorial hubs.
 */
if ( ! function_exists( 'go_verge_homepage_query_categories' ) ) {
	function go_verge_homepage_query_categories( $slugs, $limit, array &$shown, $extra = array() ) {
		$term_ids = array();

		foreach ( (array) $slugs as $slug ) {
			$term = get_term_by( 'slug', sanitize_title( (string) $slug ), 'category' );
			if ( $term instanceof WP_Term ) {
				$term_ids[] = (int) $term->term_id;
			}
		}

		if ( empty( $term_ids ) ) {
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
			'post__not_in'        => array_values( array_unique( array_map( 'absint', $shown ) ) ),
			'tax_query'           => array(
				array(
					'taxonomy'         => 'category',
					'field'            => 'term_id',
					'terms'            => array_values( array_unique( $term_ids ) ),
					'include_children' => true,
				),
			),
		);

		$query = new WP_Query( wp_parse_args( $extra, $args ) );
		foreach ( $query->posts as $post ) {
			$shown[] = (int) $post->ID;
		}
		$shown = array_values( array_unique( array_map( 'absint', $shown ) ) );

		return $query;
	}
}


/**
 * Resolve category IDs plus descendants for homepage editorial weighting.
 */
if ( ! function_exists( 'go_verge_homepage_category_tree_ids' ) ) {
	function go_verge_homepage_category_tree_ids( $slugs ) {
		$ids = array();
		foreach ( (array) $slugs as $slug ) {
			$term = get_term_by( 'slug', sanitize_title( (string) $slug ), 'category' );
			if ( ! ( $term instanceof WP_Term ) ) {
				continue;
			}
			$ids[] = (int) $term->term_id;
			$children = get_term_children( (int) $term->term_id, 'category' );
			if ( ! is_wp_error( $children ) ) {
				$ids = array_merge( $ids, array_map( 'absint', $children ) );
			}
		}
		return array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
	}
}

/**
 * Check whether a post belongs to one of the resolved category trees.
 */
if ( ! function_exists( 'go_verge_homepage_post_in_category_tree' ) ) {
	function go_verge_homepage_post_in_category_tree( $post_id, $term_ids ) {
		if ( empty( $term_ids ) ) {
			return false;
		}
		$post_terms = wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) );
		if ( is_wp_error( $post_terms ) || empty( $post_terms ) ) {
			return false;
		}
		return (bool) array_intersect( array_map( 'absint', (array) $post_terms ), array_map( 'absint', (array) $term_ids ) );
	}
}


/**
 * Central editorial taxonomy map for homepage distribution.
 *
 * The broad "Games" tree may contain narrower content types such as guides,
 * reviews or lists. Those narrower types must win before a broad vertical can
 * claim the story. Keeping the map in one place prevents each homepage block
 * from inventing slightly different rules.
 */
if ( ! function_exists( 'go_verge_homepage_editorial_taxonomy_map' ) ) {
	function go_verge_homepage_editorial_taxonomy_map() {
		static $map = null;

		if ( null !== $map ) {
			return $map;
		}

		$map = array(
			'review'        => go_verge_homepage_category_tree_ids( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ) ),
			'critique'      => go_verge_homepage_category_tree_ids( array( 'criticas', 'critica' ) ),
			'guide'         => go_verge_homepage_category_tree_ids( array( 'dicas-e-guias', 'guias', 'guia', 'dicas', 'tutoriais', 'tutorial' ) ),
			'special'       => go_verge_homepage_category_tree_ids( array( 'especiais', 'especial', 'reportagens', 'materias-especiais' ) ),
			'list'          => go_verge_homepage_category_tree_ids( array( 'listas', 'lista', 'rankings', 'ranking' ) ),
			'news'          => go_verge_homepage_category_tree_ids( array( 'noticias', 'noticia', 'news' ) ),
			'games'         => go_verge_homepage_category_tree_ids( array( 'games', 'jogos' ) ),
			'entertainment' => go_verge_homepage_category_tree_ids( array( 'entretenimento', 'series', 'filmes', 'streaming', 'animes', 'anime' ) ),
			'technology'    => go_verge_homepage_category_tree_ids( array( 'tecnologia', 'tech' ) ),
		);

		return $map;
	}
}

/**
 * Build a unique list of category IDs for one or more editorial groups.
 */
if ( ! function_exists( 'go_verge_homepage_editorial_group_ids' ) ) {
	function go_verge_homepage_editorial_group_ids( $groups ) {
		$map = go_verge_homepage_editorial_taxonomy_map();
		$ids = array();

		foreach ( (array) $groups as $group ) {
			if ( isset( $map[ $group ] ) ) {
				$ids = array_merge( $ids, (array) $map[ $group ] );
			}
		}

		return array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
	}
}

/**
 * Query a homepage section using editorial precedence instead of broad,
 * overlapping category trees.
 *
 * Precedence mirrors the publishing workflow:
 * Review > Crítica > Guia > Especial > Lista/Ranking > vertical > notícia.
 *
 * Practical example: a post tagged "Games" + "Dicas e Guias" belongs to the
 * Guides block and is explicitly excluded from "Notícias de Games".
 */
if ( ! function_exists( 'go_verge_homepage_query_editorial_section' ) ) {
	function go_verge_homepage_query_editorial_section( $section, $limit, array &$shown, $extra = array() ) {
		$section = sanitize_key( (string) $section );
		/* A desk contains every story format, including untyped legacy posts.
		 * Merely registering go_content_type is not evidence of a complete backfill. */
		if ( function_exists( 'go_verge_editorial_distribution_query' ) ) {
			$desks = array( 'games'=>'games', 'entertainment'=>'entretenimento', 'technology'=>'tecnologia', 'offers'=>'ofertas' );
			$formats = array( 'review'=>array('review'), 'critique'=>array('critica'), 'guide'=>array('guia'), 'special'=>array('especial'), 'list'=>array('lista','ranking'), 'news'=>array('noticia'), 'buying'=>array('guia-de-compra'), 'promotion'=>array('oferta') );
			$args = $extra;
			$args['post__not_in'] = array_values( array_unique( array_merge( array_map('absint',$shown), array_map('absint',(array)($extra['post__not_in'] ?? array())) ) ) );
			$query = go_verge_editorial_distribution_query( $desks[$section] ?? '', $formats[$section] ?? array(), $limit, $args );
			$shown = array_values( array_unique( array_merge( $shown, array_map('absint',wp_list_pluck($query->posts,'ID')) ) ) );
			return $query;
		}

		/* V7: formats live in go_content_type; categories only describe topic. */
		if ( taxonomy_exists( 'go_content_type' ) ) {
			$type_map = array(
				'review'   => array( 'review' ),
				'critique' => array( 'critica' ),
				'guide'    => array( 'guia' ),
				'special'  => array( 'especial' ),
				'list'     => array( 'lista', 'ranking' ),
				'news'     => array( 'noticia' ),
			);
			$vertical_map = array( 'games'=>'games', 'entertainment'=>'entretenimento', 'technology'=>'tecnologia' );
			$tax_query = array( 'relation'=>'AND' );

			if ( isset( $type_map[$section] ) ) {
				$tax_query[] = array( 'taxonomy'=>'go_content_type', 'field'=>'slug', 'terms'=>$type_map[$section], 'operator'=>'IN' );
			}
			if ( isset( $vertical_map[$section] ) ) {
				$tax_query[] = array( 'taxonomy'=>'category', 'field'=>'slug', 'terms'=>array($vertical_map[$section]), 'operator'=>'IN', 'include_children'=>true );
				$tax_query[] = array( 'taxonomy'=>'go_content_type', 'field'=>'slug', 'terms'=>array('noticia'), 'operator'=>'IN' );
			}
			if ( 'review' === $section || 'guide' === $section ) {
				$tax_query[] = array( 'taxonomy'=>'category', 'field'=>'slug', 'terms'=>array('games'), 'operator'=>'IN', 'include_children'=>true );
			}
			if ( 'critique' === $section ) {
				$tax_query[] = array( 'taxonomy'=>'category', 'field'=>'slug', 'terms'=>array('entretenimento'), 'operator'=>'IN', 'include_children'=>true );
			}

			if ( count( $tax_query ) > 1 ) {
				$args = array(
					'post_type'=>'post','post_status'=>'publish','posts_per_page'=>max(1,(int)$limit),
					'ignore_sticky_posts'=>true,'no_found_rows'=>true,
					'post__not_in'=>array_values(array_unique(array_filter(array_map('absint',$shown)))),
					'tax_query'=>$tax_query,
				);
				$query = new WP_Query( wp_parse_args( $extra, $args ) );
				foreach ( $query->posts as $item ) { $shown[] = (int) $item->ID; }
				$shown = array_values( array_unique( array_filter( array_map( 'absint', $shown ) ) ) );
				return $query;
			}
		}

		$rules = array(
			'review' => array(
				'include' => array( 'review' ),
				'exclude' => array(),
			),
			'critique' => array(
				'include' => array( 'critique' ),
				'exclude' => array( 'review' ),
			),
			'guide' => array(
				'include' => array( 'guide' ),
				'exclude' => array( 'review', 'critique' ),
			),
			'special' => array(
				'include' => array( 'special' ),
				'exclude' => array( 'review', 'critique', 'guide' ),
			),
			'list' => array(
				'include' => array( 'list' ),
				'exclude' => array( 'review', 'critique', 'guide', 'special' ),
			),
			'games' => array(
				'include' => array( 'games' ),
				'exclude' => array( 'review', 'critique', 'guide', 'special', 'list', 'entertainment', 'technology' ),
			),
			'entertainment' => array(
				'include' => array( 'entertainment' ),
				'exclude' => array( 'review', 'critique', 'guide', 'special', 'list' ),
			),
			'technology' => array(
				'include' => array( 'technology' ),
				'exclude' => array( 'review', 'critique', 'guide', 'special', 'list', 'entertainment' ),
			),
			'news' => array(
				'include' => array( 'news' ),
				'exclude' => array( 'review', 'critique', 'guide', 'special', 'list' ),
			),
		);

		if ( ! isset( $rules[ $section ] ) ) {
			return new WP_Query(
				array(
					'post_type'      => 'post',
					'post__in'       => array( 0 ),
					'posts_per_page' => 1,
					'no_found_rows'  => true,
				)
			);
		}

		$include_ids = go_verge_homepage_editorial_group_ids( $rules[ $section ]['include'] );
		$exclude_ids = go_verge_homepage_editorial_group_ids( $rules[ $section ]['exclude'] );

		if ( empty( $include_ids ) ) {
			return new WP_Query(
				array(
					'post_type'      => 'post',
					'post__in'       => array( 0 ),
					'posts_per_page' => 1,
					'no_found_rows'  => true,
				)
			);
		}

		$tax_query = array(
			'relation' => 'AND',
			array(
				'taxonomy'         => 'category',
				'field'            => 'term_id',
				'terms'            => $include_ids,
				'operator'         => 'IN',
				'include_children' => false,
			),
		);

		if ( ! empty( $exclude_ids ) ) {
			$tax_query[] = array(
				'taxonomy'         => 'category',
				'field'            => 'term_id',
				'terms'            => $exclude_ids,
				'operator'         => 'NOT IN',
				'include_children' => false,
			);
		}

		$args = array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => max( 1, (int) $limit ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'post__not_in'        => array_values( array_unique( array_filter( array_map( 'absint', $shown ) ) ) ),
			'tax_query'           => $tax_query,
		);

		$query = new WP_Query( wp_parse_args( $extra, $args ) );

		foreach ( $query->posts as $post ) {
			$shown[] = (int) $post->ID;
		}
		$shown = array_values( array_unique( array_filter( array_map( 'absint', $shown ) ) ) );

		return $query;
	}
}

/**
 * Build the six-story homepage hero without category reservations.
 *
 * Manual choices keep their exact positions. Empty slots are filled by the
 * newest eligible post, regardless of editorial category.
 */
if ( ! function_exists( 'go_verge_homepage_hero_query' ) ) {
	function go_verge_homepage_hero_query( $limit, array &$shown ) {
		$limit = max( 1, absint( $limit ) );
		$manual_slots = function_exists( 'go_verge_get_manual_homepage_hero_ids' )
			? array_slice( go_verge_get_manual_homepage_hero_ids(), 0, $limit )
			: array();
		$manual_slots = array_pad( array_map( 'absint', $manual_slots ), $limit, 0 );
		$manual_ids   = array_values( array_unique( array_filter( $manual_slots ) ) );
		$excluded_hero_ids = function_exists( 'go_verge_get_homepage_hero_excluded_post_ids' )
			? array_map( 'absint', go_verge_get_homepage_hero_excluded_post_ids() )
			: array();

		$candidates = new WP_Query(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => max( 48, $limit * 8 ),
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'fields'              => 'ids',
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
				'orderby'             => 'date',
				'order'               => 'DESC',
				'post__not_in'        => array_values(
					array_unique(
						array_merge(
							array_map( 'absint', $shown ),
							$manual_ids,
							$excluded_hero_ids
						)
					)
				),
			)
		);

		$automatic_ids = array_values( array_filter( array_map( 'absint', (array) $candidates->posts ) ) );
		if ( function_exists( 'go_verge_promotion_has_expired' ) ) {
			if ( function_exists( '_prime_post_caches' ) ) { _prime_post_caches( array_merge($automatic_ids,$manual_ids), false, true ); }
			$automatic_ids = array_values( array_filter( $automatic_ids, static function($id) { return ! go_verge_promotion_has_expired($id); } ) );
		}

		$ids        = array();
		$auto_index = 0;
		for ( $slot = 0; $slot < $limit; $slot++ ) {
			$manual_id = isset( $manual_slots[ $slot ] ) ? absint( $manual_slots[ $slot ] ) : 0;
			$manual_blocked = $manual_id && (
				in_array( $manual_id, $excluded_hero_ids, true )
				|| ( function_exists( 'go_verge_is_post_excluded_from_homepage_hero' ) && go_verge_is_post_excluded_from_homepage_hero( $manual_id ) )
				|| ( function_exists( 'go_verge_homepage_post_is_search_only' ) && go_verge_homepage_post_is_search_only( $manual_id ) )
				|| ( function_exists( 'go_verge_promotion_has_expired' ) && go_verge_promotion_has_expired( $manual_id ) )
			);

			if ( $manual_id && ! $manual_blocked && 'publish' === get_post_status( $manual_id ) && ! in_array( $manual_id, $ids, true ) ) {
				$ids[] = $manual_id;
				continue;
			}

			while ( isset( $automatic_ids[ $auto_index ] ) && in_array( (int) $automatic_ids[ $auto_index ], $ids, true ) ) {
				$auto_index++;
			}
			if ( isset( $automatic_ids[ $auto_index ] ) ) {
				$ids[] = (int) $automatic_ids[ $auto_index ];
				$auto_index++;
			}
		}

		$ids = array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) );
		if ( empty( $ids ) ) {
			return new WP_Query( array( 'post_type' => 'post', 'post__in' => array( 0 ), 'posts_per_page' => 1, 'no_found_rows' => true ) );
		}

		$hero = new WP_Query(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => count( $ids ),
				'post__in'            => $ids,
				'orderby'             => 'post__in',
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
			)
		);

		$shown = array_values( array_unique( array_merge( array_map( 'absint', $shown ), $ids ) ) );
		return $hero;
	}
}

/**
 * Return the first featured-image ID available in an already-loaded query.
 * Reusing homepage queries keeps the visual navigation inexpensive.
 */
if ( ! function_exists( 'go_verge_homepage_query_image_id' ) ) {
	function go_verge_homepage_query_image_id( WP_Query $query ) {
		foreach ( $query->posts as $post ) {
			$image_id = get_post_thumbnail_id( $post );
			if ( $image_id ) {
				return (int) $image_id;
			}
		}

		return 0;
	}
}

/** Homepage cards own their presentation; shared article/archive cards stay intact. */
if ( ! function_exists( 'go_verge_home_story' ) ) {
    function go_verge_home_story( $args = array() ) {
        $args = wp_parse_args( $args, array( 'id' => get_the_ID(), 'size' => 'standard', 'show_image' => true, 'show_excerpt' => false, 'show_meta' => true, 'show_label' => true, 'show_score' => true, 'title_tag' => 'h3', 'image_size' => 'go_card', 'loading' => 'lazy', 'fetchpriority' => 'low', 'decoding' => 'async', 'sizes' => '(max-width:767px) calc(100vw - 32px), 590px', 'pretitle' => '' ) );
        $id = absint( $args['id'] );
        $has_image = $args['show_image'] && has_post_thumbnail( $id );
        $title_tag = in_array( $args['title_tag'], array( 'h2', 'h3', 'h4' ), true ) ? $args['title_tag'] : 'h3';
        $term = function_exists( 'go_verge_get_primary_term' ) ? go_verge_get_primary_term( $id ) : null;
        $label = $args['pretitle'] ? $args['pretitle'] : ( $term instanceof WP_Term ? $term->name : '' );
        $score = $args['show_score'] && function_exists( 'go_verge_review_score' ) ? go_verge_review_score( $id ) : null;
        ?>
        <article class="od-story od-story--<?php echo esc_attr( sanitize_html_class( $args['size'] ) ); ?><?php echo $has_image ? '' : ' od-story--noimage'; ?>" data-go-ad-integrity="atomic">
            <?php if ( $has_image ) : ?>
                <a class="od-story__media" href="<?php echo esc_url( get_permalink( $id ) ); ?>" tabindex="-1" aria-hidden="true">
                    <?php echo get_the_post_thumbnail( $id, $args['image_size'], array( 'loading' => $args['loading'], 'fetchpriority' => $args['fetchpriority'], 'decoding' => 'async', 'sizes' => $args['sizes'], 'alt' => '' ) ); ?>
                </a>
            <?php endif; ?>
            <div class="od-story__body">
                <?php if ( ( $args['show_label'] && $label ) || null !== $score ) : ?>
                    <div class="od-story__eyebrow">
                        <?php if ( $args['show_label'] && $label ) : ?><span><?php echo esc_html( $label ); ?></span><?php endif; ?>
                        <?php if ( null !== $score ) : ?><span class="od-story__score" aria-label="<?php echo esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $score ) ); ?>"><?php echo esc_html( function_exists( 'go_verge_review_score_display' ) ? go_verge_review_score_display( $score ) : $score ); ?><small>/10</small></span><?php endif; ?>
                    </div>
                <?php endif; ?>
                <<?php echo $title_tag; ?> class="od-story__title"><a href="<?php echo esc_url( get_permalink( $id ) ); ?>"><?php echo esc_html( get_the_title( $id ) ); ?></a></<?php echo $title_tag; ?>>
                <?php if ( $args['show_excerpt'] ) : $deck = go_verge_support_text( $id ); ?>
                    <?php if ( $deck ) : ?><p class="od-story__deck"><?php echo esc_html( wp_trim_words( $deck, 26, '…' ) ); ?></p><?php endif; ?>
                <?php endif; ?>
                <?php if ( $args['show_meta'] ) : ?><div class="od-story__meta"><?php echo go_verge_time_html( $id ); ?></div><?php endif; ?>
            </div>
        </article>
        <?php
    }
}

/**
 * Compact panel used by paired editorial sections.
 */
if ( ! function_exists( 'go_verge_homepage_panel' ) ) {
	function go_verge_homepage_panel( $title, $url, WP_Query $query, $accent = false ) {
		if ( ! $query->have_posts() ) {
			return;
		}
		?>
		<section class="od-panel<?php echo $accent ? ' od-panel--reviews' : ''; ?>">
			<div class="od-panel__head">
				<h2 class="od-panel__title"><?php echo esc_html( $title ); ?></h2>
				<a class="od-panel__link" href="<?php echo esc_url( $url ); ?>"><?php esc_html_e( 'Ver tudo', 'go-verge' ); ?></a>
			</div>
			<div class="od-panel__content">
				<?php
				$first = true;
				while ( $query->have_posts() ) {
					$query->the_post();
					go_verge_home_story(
						array(
							'id'           => get_the_ID(),
							'size'         => $first ? 'standard' : 'compact',
							'accent'       => 'none',
							'show_excerpt' => $first,
							'show_image'   => true,
							'show_score'   => ! $accent || $first,
							'show_label'   => ! $accent || $first,
							'image_size'   => $first ? 'go_card' : 'go_square',
							'sizes'        => $first ? '(max-width: 767px) calc(100vw - 32px), 590px' : '(max-width: 767px) 104px, 120px',
						)
					);
					$first = false;
				}
				wp_reset_postdata();
				?>
			</div>
		</section>
		<?php
	}
}

$go_home_shown = array();
$go_home_hero  = go_verge_homepage_hero_query( 6, $go_home_shown );
if ( $go_home_hero->have_posts() && ! empty( $go_home_hero->posts[0] ) ) {
	$GLOBALS['go_verge_lcp_preload_image_id'] = get_post_thumbnail_id( $go_home_hero->posts[0]->ID );
}

get_header();

/* One source of truth for the "Últimas" hub: go_verge_latest_url() in
 * inc/template-helpers.php resolves the Page that actually owns the stream. */
$go_home_latest = function_exists( 'go_verge_latest_url' ) ? go_verge_latest_url() : home_url( '/ultimas-publicacoes/' );

$go_home_urls = array(
	'noticias'       => $go_home_latest,
	'ultimas'        => $go_home_latest,
	'games'          => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'games' ) : home_url( '/games/' ),
	'reviews'        => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'reviews' ) : home_url( '/reviews/' ),
	'criticas'       => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'criticas' ) : home_url( '/criticas/' ),
	'guias'          => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'dicas-e-guias' ) : home_url( '/games/dicas-e-guias/' ),
	'entretenimento' => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'entretenimento' ) : home_url( '/entretenimento/' ),
	'tecnologia'     => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'tecnologia' ) : home_url( '/tecnologia/' ),
	'promocoes'      => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'ofertas' ) : home_url( '/ofertas/' ),
	'especiais'      => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'especiais' ) : home_url( '/games/especiais/' ),
	'listas'         => go_verge_homepage_url( array( 'listas-e-rankings', 'listas', 'rankings' ), array( 'listas', 'rankings' ), home_url( '/listas-e-rankings/' ) ),
);


/*
 * 3.80.0 homepage distribution.
 *
 * The page deliberately follows a portal hierarchy instead of a long chain of
 * equally weighted modules: lead stories, channels, Compara gateway, vertical
 * desks, depth cards and finally the chronological feed. Every query registers
 * the stories it actually renders so the lower feed remains unique.
 */
$go_home_reviews       = go_verge_homepage_query_editorial_section( 'review', 4, $go_home_shown );
$go_home_critics       = go_verge_homepage_query_editorial_section( 'critique', 1, $go_home_shown );
$go_home_guides        = go_verge_homepage_query_editorial_section( 'guide', 4, $go_home_shown );
$go_home_specials      = go_verge_homepage_query_editorial_section( 'special', 1, $go_home_shown );
$go_home_lists         = go_verge_homepage_query_editorial_section( 'list', 1, $go_home_shown );
$go_home_entertainment = go_verge_homepage_query_editorial_section( 'entertainment', 4, $go_home_shown );
$go_home_technology    = go_verge_homepage_query_editorial_section( 'technology', 4, $go_home_shown );
$go_home_games         = go_verge_homepage_query_editorial_section( 'games', 5, $go_home_shown );

$go_home_promotions = go_verge_homepage_query_editorial_section( 'promotion', 1, $go_home_shown );
foreach ( (array) $go_home_promotions->posts as $go_home_promotion_post ) {
	$go_home_shown[] = absint( $go_home_promotion_post->ID );
}
$go_home_shown = array_values( array_unique( array_filter( array_map( 'absint', $go_home_shown ) ) ) );

$go_home_buying = go_verge_homepage_query_editorial_section( 'buying', 1, $go_home_shown );
foreach ( (array) $go_home_buying->posts as $go_home_buying_post ) {
	$go_home_shown[] = absint( $go_home_buying_post->ID );
}
$go_home_shown = array_values( array_unique( array_filter( array_map( 'absint', $go_home_shown ) ) ) );

$go_home_buying_url = function_exists( 'go_verge_canonical_buying_guides_url' ) ? go_verge_canonical_buying_guides_url() : '';
if ( '' === $go_home_buying_url ) {
	$go_home_buying_term = get_term_by( 'slug', 'guias-de-compra-2', 'category' );
	if ( $go_home_buying_term instanceof WP_Term ) {
		$go_home_buying_link = get_term_link( $go_home_buying_term );
		$go_home_buying_url  = is_wp_error( $go_home_buying_link ) ? '' : $go_home_buying_link;
	}
}

$go_home_compara_url = function_exists( 'go_verge_compara_url' ) ? go_verge_compara_url() : home_url( '/compara/' );

$go_home_topics = array();
foreach ( $go_home_hero->posts as $go_topic_post ) {
    foreach ( (array) get_the_tags( $go_topic_post->ID ) as $go_topic ) {
        if ( ! ( $go_topic instanceof WP_Term ) || isset( $go_home_topics[ $go_topic->term_id ] ) ) { continue; }
        $go_topic_url = get_term_link( $go_topic );
        if ( is_wp_error( $go_topic_url ) ) { continue; }
        $go_home_topics[ $go_topic->term_id ] = array( 'label' => $go_topic->name, 'url' => $go_topic_url );
        break; // One distinct topic per selected story.
    }
    if ( count( $go_home_topics ) >= 5 ) { break; }
}

$go_home_depth_cards = array();
if ( ! empty( $go_home_critics->posts[0] ) ) {
	$go_home_depth_cards[] = array( 'label' => 'Crítica', 'url' => $go_home_urls['criticas'], 'post' => $go_home_critics->posts[0] );
}
if ( ! empty( $go_home_specials->posts[0] ) ) {
	$go_home_depth_cards[] = array( 'label' => 'Especial', 'url' => $go_home_urls['especiais'], 'post' => $go_home_specials->posts[0] );
}
if ( ! empty( $go_home_lists->posts[0] ) ) {
	$go_home_depth_cards[] = array( 'label' => 'Lista e Ranking', 'url' => $go_home_urls['listas'], 'post' => $go_home_lists->posts[0] );
}
if ( ! empty( $go_home_buying->posts[0] ) ) {
	$go_home_depth_cards[] = array( 'label' => 'Guia de compra', 'url' => $go_home_buying_url ?: $go_home_urls['guias'], 'post' => $go_home_buying->posts[0] );
}
if ( ! empty( $go_home_promotions->posts[0] ) ) {
	$go_home_depth_cards[] = array( 'label' => 'Oferta', 'url' => $go_home_urls['promocoes'], 'post' => $go_home_promotions->posts[0] );
}
/* Format destinations stay inside the selected story's actual editorial desk. */
if ( function_exists('go_verge_desk_format_url') && function_exists('go_verge_post_editorial_desk') ) {
	$go_depth_types = array('Crítica'=>'critica','Especial'=>'especial','Lista e Ranking'=>'lista','Guia de compra'=>'guia-de-compra','Oferta'=>'oferta');
	foreach ( $go_home_depth_cards as &$go_depth_card ) {
		$go_depth_desk = go_verge_post_editorial_desk($go_depth_card['post']->ID);
		$go_depth_type = function_exists('go_verge_v7_post_content_type') ? go_verge_v7_post_content_type($go_depth_card['post']->ID) : '';
		if ( $go_depth_desk ) { $go_depth_card['url'] = go_verge_desk_format_url($go_depth_desk,$go_depth_type ?: ($go_depth_types[$go_depth_card['label']] ?? '')); }
	}
	unset($go_depth_card);
}
?>

<main id="primary" class="od-home">
	<h1 class="screen-reader-text"><?php bloginfo( 'name' ); ?></h1>

	<?php if ( $go_home_hero->have_posts() ) : ?>
		<?php $go_home_hero_posts = $go_home_hero->posts; ?>
		<section class="od-wrap od-home__hero" aria-label="<?php esc_attr_e( 'Destaques', 'go-verge' ); ?>">
			<div class="od-home__hero-grid<?php echo count( $go_home_hero_posts ) < 2 ? ' od-home__hero-grid--solo' : ''; ?>">
				<div class="od-home__hero-lead">
					<?php if ( ! empty( $go_home_hero_posts[0] ) ) : ?>
						<?php go_verge_home_story( array( 'id' => $go_home_hero_posts[0]->ID, 'size' => 'feature', 'show_excerpt' => false, 'show_subtitle' => false, 'show_meta' => true, 'title_tag' => 'h3', 'image_size' => 'go_hero', 'loading' => 'eager', 'fetchpriority' => 'high', 'decoding' => 'async', 'sizes' => '(max-width: 767px) calc(100vw - 32px), (max-width: 1303px) 62vw, 806px', 'media_context' => 'homepage-hero' ) ); ?>
					<?php endif; ?>
				</div>
				<div class="od-home__hero-side">
					<?php foreach ( array_slice( $go_home_hero_posts, 1, 2 ) as $go_home_hero_post ) : ?>
						<?php go_verge_home_story( array( 'id' => $go_home_hero_post->ID, 'size' => 'standard', 'show_excerpt' => false, 'show_meta' => false, 'image_size' => 'go_card', 'sizes' => '(max-width: 767px) 112px, (max-width: 1303px) 32vw, 402px', 'loading' => 'lazy', 'fetchpriority' => 'low', 'decoding' => 'async', 'media_context' => 'homepage-hero' ) ); ?>
					<?php endforeach; ?>
				</div>
			</div>
			<?php if ( count( $go_home_hero_posts ) > 3 ) : ?>
				<div class="od-home__headline-rail">
					<?php foreach ( array_slice( $go_home_hero_posts, 3, 3 ) as $go_home_hero_post ) : ?>
						<?php go_verge_home_story( array( 'id' => $go_home_hero_post->ID, 'size' => 'compact', 'show_image' => false, 'show_excerpt' => false, 'show_meta' => false, 'show_label' => true, 'show_score' => false, 'title_tag' => 'h3' ) ); ?>
					<?php endforeach; ?>
				</div>
			<?php endif; ?>
		</section>
		<?php wp_reset_postdata(); ?>
	<?php endif; ?>

	<?php
	/* Desktop-only Top Display: on the homepage it belongs below the hero.
	 * Mobile home deliberately has no masthead — Top Scroll already owns the top
	 * of that template and a second display unit there changes the front page's
	 * look for comparatively little circulation. */
	if ( function_exists( 'go_verge_render_adsense_unit' ) ) {
		go_verge_render_adsense_unit(
			'home-masthead',
			array(
				'tag'   => 'aside',
				'class' => 'go-container go-site-masthead-ad go-revenue-parity-top-display',
				'data'  => array( 'ad-surface' => 'home-after-hero' ),
			)
		);
	}
	?>

    <?php if ( $go_home_topics ) : ?>
    <nav class="od-wrap od-home__topics" aria-label="<?php esc_attr_e( 'Assuntos em pauta', 'go-verge' ); ?>">
        <span class="od-home__topics-label">Em pauta</span>
        <div class="od-home__topics-links">
        <?php foreach ( $go_home_topics as $go_home_topic ) : ?>
            <a href="<?php echo esc_url( $go_home_topic['url'] ); ?>"><?php echo esc_html( $go_home_topic['label'] ); ?></a>
        <?php endforeach; ?>
        </div>
    </nav>
    <?php endif; ?>


	<?php if ( $go_home_games->have_posts() ) : ?>
		<?php $go_home_games_posts = $go_home_games->posts; ?>
		<section class="od-wrap od-home__section od-home__games" aria-labelledby="go-home-games-title">
			<div class="od-home__section-head"><h2 id="go-home-games-title">Games</h2><a href="<?php echo esc_url( $go_home_urls['games'] ); ?>">Ver tudo</a></div>
			<div class="od-home__games-grid">
				<div class="od-home__games-lead">
					<?php if ( ! empty( $go_home_games_posts[0] ) ) : ?>
						<?php go_verge_home_story( array( 'id' => $go_home_games_posts[0]->ID, 'size' => 'feature', 'show_excerpt' => true, 'show_meta' => true, 'image_size' => 'go_hero', 'sizes' => '(max-width:767px) calc(100vw - 28px), (max-width:1199px) 56vw, 680px' ) ); ?>
					<?php endif; ?>
				</div>
				<div class="od-home__games-cards">
					<?php foreach ( array_slice( $go_home_games_posts, 1, 4 ) as $go_home_game_post ) : ?>
						<?php go_verge_home_story( array( 'id' => $go_home_game_post->ID, 'size' => 'standard', 'show_excerpt' => false, 'show_meta' => false, 'image_size' => 'go_card', 'sizes' => '(max-width:767px) 112px, 290px' ) ); ?>
					<?php endforeach; ?>
				</div>
			</div>
		</section>
	<?php endif; ?>

	<section class="od-wrap od-home__compara" aria-labelledby="go-home-compara-title">
		<a href="<?php echo esc_url( $go_home_compara_url ); ?>" class="od-home__compara-link">
			<div class="od-home__compara-brand">
				<span>Overdrive</span>
				<h2 id="go-home-compara-title">Compare</h2>
			</div>
			<p class="od-home__compara-copy">Compare antes de comprar.<span>Celulares, notebooks, TVs, consoles e mais.</span></p>
			<strong>Ver Compare <span aria-hidden="true">→</span></strong>
		</a>
	</section>

	<?php if ( function_exists( 'go_verge_render_adsense_unit' ) ) : ?>
		<?php go_verge_render_adsense_unit( 'home-mid', array( 'tag' => 'aside', 'class' => 'od-wrap go-home-mid-revenue-slot', 'data' => array( 'ad-surface' => 'home-after-compare' ) ) ); ?>
	<?php endif; ?>


	<?php if ( $go_home_reviews->have_posts() || $go_home_guides->have_posts() ) : ?>
		<div class="od-wrap od-home__section od-home__duo od-home__duo--service" data-go-ad-integrity="atomic">
			<?php go_verge_homepage_panel( __( 'Reviews', 'go-verge' ), $go_home_urls['reviews'], $go_home_reviews, true ); ?>
			<?php go_verge_homepage_panel( __( 'Dicas e Guias', 'go-verge' ), $go_home_urls['guias'], $go_home_guides, false ); ?>
		</div>
	<?php endif; ?>


	<?php if ( $go_home_entertainment->have_posts() || $go_home_technology->have_posts() ) : ?>
		<div class="od-wrap od-home__section od-home__duo" data-go-ad-integrity="atomic">
			<?php go_verge_homepage_panel( __( 'Entretenimento', 'go-verge' ), $go_home_urls['entretenimento'], $go_home_entertainment, false ); ?>
			<?php go_verge_homepage_panel( __( 'Tecnologia', 'go-verge' ), $go_home_urls['tecnologia'], $go_home_technology, false ); ?>
		</div>
	<?php endif; ?>

	<?php if ( ( $go_home_entertainment->have_posts() || $go_home_technology->have_posts() ) && function_exists( 'go_verge_render_adsense_unit' ) ) : ?>
		<?php go_verge_render_adsense_unit( 'home-mid-2', array( 'tag' => 'aside', 'class' => 'od-wrap go-home-mid-revenue-slot go-home-mid-revenue-slot--m2', 'data' => array( 'ad-surface' => 'home-deep-module-break' ) ) ); ?>
	<?php endif; ?>


	<?php if ( $go_home_depth_cards ) : ?>
		<section class="od-wrap od-home__section od-home__depth" aria-labelledby="go-home-depth-title">
			<div class="od-home__section-head"><h2 id="go-home-depth-title">Mais no Overdrive</h2></div>
			<div class="od-home__depth-grid">
				<?php foreach ( $go_home_depth_cards as $go_home_depth_card ) : ?>
					<div class="od-home__depth-card">
						<a class="od-home__depth-label" href="<?php echo esc_url( $go_home_depth_card['url'] ); ?>"><?php echo esc_html( $go_home_depth_card['label'] ); ?></a>
						<?php go_verge_home_story( array( 'id' => $go_home_depth_card['post']->ID, 'size' => 'standard', 'show_excerpt' => false, 'show_meta' => false, 'show_label' => false, 'image_size' => 'go_card', 'sizes' => '(max-width:767px) 78vw, 290px' ) ); ?>
					</div>
				<?php endforeach; ?>
			</div>
		</section>
	<?php endif; ?>

	<?php
	$go_home_shown = array_values( array_unique( array_filter( array_map( 'absint', $go_home_shown ) ) ) );
	$go_home_latest_feed = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 10,
			'paged'               => max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => false,
			'post__not_in'        => $go_home_shown,
		)
	);
	$go_home_latest_ids     = array_map( 'absint', wp_list_pluck( $go_home_latest_feed->posts, 'ID' ) );
	$go_home_trending_posts = function_exists( 'go_verge_global_popular_posts' )
		? go_verge_global_popular_posts( array_values( array_unique( array_merge( $go_home_shown, $go_home_latest_ids ) ) ), 8 )
		: array();
	if ( function_exists( 'go_verge_homepage_post_is_search_only' ) ) {
		$go_home_trending_posts = array_values( array_filter( $go_home_trending_posts, static function ( $post ) {
			return $post instanceof WP_Post && ! go_verge_homepage_post_is_search_only( $post->ID );
		} ) );
	}
	$go_home_trending_posts = array_slice( $go_home_trending_posts, 0, 5 );
	$go_home_sidebar_modules = $go_home_trending_posts
		? array(
			array(
				'title'  => __( 'Mais lidas', 'go-verge' ),
				'ranked' => true,
				'posts'  => $go_home_trending_posts,
			),
		)
		: array();
	$go_home_latest_exclude = implode( ',', $go_home_shown );
	?>

	<?php if ( $go_home_latest_feed->have_posts() ) : ?>
		<section id="ultimas-publicacoes" class="od-wrap od-home__section od-home__latest">
			<div class="od-home__section-head"><h2>Últimas publicações</h2><a href="<?php echo esc_url( $go_home_urls['ultimas'] ); ?>">Ver todas</a></div>
			<div class="go-archive-body<?php echo $go_home_sidebar_modules ? ' go-archive-body--aside' : ''; ?>">
				<div class="go-archive-main go-home-feed">
					<div id="go-home-latest-feed" class="go-archive-list" data-go-latest-feed aria-live="polite"<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
						<?php while ( $go_home_latest_feed->have_posts() ) : $go_home_latest_feed->the_post(); ?>
							<?php go_verge_archive_list_item( get_the_ID(), array( 'show_excerpt' => true, 'media_context' => 'latest' ) ); ?>
						<?php endwhile; wp_reset_postdata(); ?>
					</div>
					<?php if ( $go_home_latest_feed->max_num_pages > 1 ) : ?>
						<div class="go-home-feed__controls">
							<?php $go_home_latest_page = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) ); ?>
							<a class="go-home-feed__more" data-go-load-latest aria-controls="go-home-latest-feed" data-page="<?php echo esc_attr( $go_home_latest_page ); ?>" data-max="<?php echo esc_attr( $go_home_latest_feed->max_num_pages ); ?>" data-exclude="<?php echo esc_attr( $go_home_latest_exclude ); ?>" href="<?php echo esc_url( get_pagenum_link( $go_home_latest_page + 1 ) ); ?>" rel="next"><?php esc_html_e( 'Carregar mais', 'go-verge' ); ?></a>
						</div>
					<?php endif; ?>
				</div>
				<?php if ( $go_home_sidebar_modules ) { go_verge_render_archive_sidebar( $go_home_sidebar_modules ); } ?>
			</div>
		</section>
	<?php endif; ?>

	<section class="od-wrap go-section go-home-continue" data-go-home-continue hidden>
		<div class="go-section__head"><h2 class="go-section__title"><?php esc_html_e( 'Continue lendo', 'go-verge' ); ?></h2><a class="go-btn" href="<?php echo esc_url( home_url( '/para-voce/' ) ); ?>"><?php esc_html_e( 'Ver tudo', 'go-verge' ); ?></a></div>
		<div data-go-home-continue-list></div>
	</section>
</main>

<?php get_footer(); ?>
