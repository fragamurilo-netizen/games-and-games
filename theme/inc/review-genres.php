<?php
/**
 * Review genre filters.
 *
 * Uses the structured review genre field, technical-sheet metadata, linked game
 * profiles and existing taxonomy terms. No genre is guessed from generic body
 * copy, which avoids classifying every mention of "ação" as an action game.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Fixed public vocabulary for the Reviews archive.
 *
 * A review may belong to more than one group (for example action + RPG).
 */
function go_verge_review_genre_definitions() {
	return array(
		'acao'       => array(
			'label'   => __( 'Ação', 'go-verge' ),
			'aliases' => array( 'acao', 'action', 'shooter', 'fps', 'tps', 'hack and slash', 'hack n slash', 'beat em up', 'arcade', 'soulslike' ),
		),
		'aventura'   => array(
			'label'   => __( 'Aventura', 'go-verge' ),
			'aliases' => array( 'aventura', 'adventure', 'acao e aventura', 'action adventure', 'point and click', 'visual novel', 'narrativo', 'narrative', 'metroidvania' ),
		),
		'rpg'        => array(
			'label'   => 'RPG',
			'aliases' => array( 'rpg', 'jrpg', 'arpg', 'role playing', 'role-playing', 'action rpg', 'tactical rpg', 'soulslike' ),
		),
		'esportes'   => array(
			'label'   => __( 'Esportes', 'go-verge' ),
			'aliases' => array( 'esporte', 'esportes', 'sports', 'futebol', 'football', 'soccer', 'basquete', 'basketball', 'tenis', 'tennis', 'golf', 'skate', 'hockey', 'mma' ),
		),
		'corrida'    => array(
			'label'   => __( 'Corrida', 'go-verge' ),
			'aliases' => array( 'corrida', 'racing', 'automobilismo', 'motorsport', 'kart', 'simulador de corrida', 'driving' ),
		),
		'luta'       => array(
			'label'   => __( 'Luta', 'go-verge' ),
			'aliases' => array( 'luta', 'fighting', 'fighter', 'versus fighter', 'arena fighter', 'beat em up', 'brawler' ),
		),
		'terror'     => array(
			'label'   => __( 'Terror', 'go-verge' ),
			'aliases' => array( 'terror', 'horror', 'survival horror', 'psychological horror', 'terror psicologico' ),
		),
		'estrategia' => array(
			'label'   => __( 'Estratégia', 'go-verge' ),
			'aliases' => array( 'estrategia', 'strategy', 'estrategia em tempo real', 'real time strategy', 'rts', 'turn based', 'turn-based', 'tatico', 'tactical', '4x', 'tower defense' ),
		),
		'simulacao'  => array(
			'label'   => __( 'Simulação', 'go-verge' ),
			'aliases' => array( 'simulacao', 'simulation', 'simulator', 'simulador', 'management', 'gerenciamento', 'gestao', 'tycoon', 'life sim', 'farming sim' ),
		),
		'plataforma' => array(
			'label'   => __( 'Plataforma', 'go-verge' ),
			'aliases' => array( 'plataforma', 'platformer', 'platform', '3d platformer', '2d platformer', 'metroidvania' ),
		),
		'puzzle'     => array(
			'label'   => 'Puzzle',
			'aliases' => array( 'puzzle', 'quebra cabeca', 'quebra-cabeca', 'logic game', 'jogo de logica' ),
		),
		'indies'     => array(
			'label'   => __( 'Indies', 'go-verge' ),
			'aliases' => array( 'indie', 'indies', 'independente', 'independent game', 'jogo independente' ),
		),
	);
}

/** Normalize genre metadata into a word-safe string. */
function go_verge_review_genre_normalize( $value ) {
	$value = remove_accents( wp_strip_all_tags( (string) $value ) );
	$value = function_exists( 'mb_strtolower' ) ? mb_strtolower( $value, 'UTF-8' ) : strtolower( $value );
	$value = preg_replace( '/[^a-z0-9]+/u', ' ', $value );
	return ' ' . trim( preg_replace( '/\s+/u', ' ', (string) $value ) ) . ' ';
}

/**
 * Structured genre sources for a review.
 */
function go_verge_review_genre_source( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) {
		return '';
	}

	$parts = array();
	foreach ( array( 'review_genre', 'go_technical_genre', '_go_review_genre', 'game_genre', 'game_genres' ) as $meta_key ) {
		$value = get_post_meta( $post_id, $meta_key, true );
		if ( is_array( $value ) ) {
			$value = implode( ' ', array_map( 'strval', $value ) );
		}
		if ( '' !== trim( (string) $value ) ) {
			$parts[] = $value;
		}
	}

	foreach ( array( 'post_tag', 'category' ) as $taxonomy ) {
		$terms = get_the_terms( $post_id, $taxonomy );
		if ( ! empty( $terms ) && ! is_wp_error( $terms ) ) {
			foreach ( $terms as $term ) {
				$parts[] = $term->name;
				$parts[] = $term->slug;
			}
		}
	}

	if ( function_exists( 'go_verge_review_game_profile' ) ) {
		$profile = go_verge_review_game_profile( $post_id );
		if ( is_array( $profile ) && ! empty( $profile['id'] ) && function_exists( 'go_verge_game_data' ) ) {
			$game_data = go_verge_game_data( absint( $profile['id'] ) );
			if ( ! empty( $game_data['genres'] ) ) {
				$parts[] = $game_data['genres'];
			}
		}
	}

	return go_verge_review_genre_normalize( implode( ' ', $parts ) );
}

/** Classify one review into all matching public genre groups. */
function go_verge_review_genre_keys_for_post( $post_id ) {
	$source = go_verge_review_genre_source( $post_id );
	if ( '' === trim( $source ) ) {
		return array();
	}

	$keys = array();
	foreach ( go_verge_review_genre_definitions() as $key => $definition ) {
		foreach ( $definition['aliases'] as $alias ) {
			$needle = trim( go_verge_review_genre_normalize( $alias ) );
			if ( '' !== $needle && false !== strpos( $source, ' ' . $needle . ' ' ) ) {
				$keys[] = $key;
				break;
			}
		}
	}

	/* A short editorial fallback catches explicit genre wording in titles and
	 * support lines when old posts have no structured genre field. Generic words
	 * such as "ação" and "aventura" are deliberately excluded here. */
	$editorial = go_verge_review_genre_normalize( get_the_title( $post_id ) . ' ' . get_the_excerpt( $post_id ) );
	$editorial_aliases = array(
		'acao'       => array( 'shooter', 'fps', 'tps', 'hack and slash', 'soulslike', 'brawler', 'beat em up' ),
		'aventura'   => array( 'visual novel', 'point and click', 'metroidvania' ),
		'rpg'        => array( 'rpg', 'jrpg', 'arpg', 'role playing', 'soulslike' ),
		'esportes'   => array( 'sports', 'esporte', 'futebol', 'football', 'basquete', 'basketball', 'tenis', 'tennis', 'golf', 'skate', 'hockey', 'mma' ),
		'corrida'    => array( 'corrida', 'racing', 'formula 1', 'f1', 'rally', 'kart', 'motorsport' ),
		'luta'       => array( 'luta', 'fighting', 'fighter', 'brawler', 'mma', 'ufc' ),
		'terror'     => array( 'terror', 'horror', 'survival horror', 'terror psicologico' ),
		'estrategia' => array( 'estrategia', 'strategy', 'rts', 'tactical', 'tatico', 'turn based', 'tower defense' ),
		'simulacao'  => array( 'simulacao', 'simulation', 'simulator', 'simulador', 'tycoon', 'management' ),
		'plataforma' => array( 'plataforma', 'platformer', 'metroidvania' ),
		'puzzle'     => array( 'puzzle', 'quebra cabeca', 'quebra-cabeca' ),
		'indies'     => array( 'indie', 'indies', 'jogo independente', 'estudio independente' ),
	);
	foreach ( $editorial_aliases as $key => $aliases ) {
		if ( in_array( $key, $keys, true ) ) {
			continue;
		}
		foreach ( $aliases as $alias ) {
			$needle = trim( go_verge_review_genre_normalize( $alias ) );
			if ( '' !== $needle && false !== strpos( $editorial, ' ' . $needle . ' ' ) ) {
				$keys[] = $key;
				break;
			}
		}
	}

	return array_values( array_unique( $keys ) );
}

/** Cached map of genre key => review post IDs. */
function go_verge_review_genre_index() {
	static $index = null;
	if ( is_array( $index ) ) {
		return $index;
	}

	$cached = get_transient( 'go_verge_review_genre_index_v2' );
	if ( is_array( $cached ) ) {
		$index = $cached;
		return $index;
	}

	$definitions = go_verge_review_genre_definitions();
	$index       = array_fill_keys( array_keys( $definitions ), array() );
	$index['outros'] = array();

	$review_term_ids = function_exists( 'go_verge_category_ids' )
		? go_verge_category_ids( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ), array( 'review', 'analise' ) )
		: array();
	if ( empty( $review_term_ids ) ) {
		set_transient( 'go_verge_review_genre_index_v2', $index, HOUR_IN_SECONDS );
		return $index;
	}

	$review_ids = get_posts(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => -1,
			'fields'              => 'ids',
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'tax_query'           => array(
				array(
					'taxonomy'         => 'category',
					'field'            => 'term_id',
					'terms'            => $review_term_ids,
					'include_children' => true,
				),
			),
		)
	);

	foreach ( array_map( 'absint', $review_ids ) as $review_id ) {
		$keys = go_verge_review_genre_keys_for_post( $review_id );
		if ( empty( $keys ) ) {
			$index['outros'][] = $review_id;
			continue;
		}
		foreach ( $keys as $key ) {
			if ( isset( $index[ $key ] ) ) {
				$index[ $key ][] = $review_id;
			}
		}
	}

	set_transient( 'go_verge_review_genre_index_v2', $index, 6 * HOUR_IN_SECONDS );
	return $index;
}

/** Active genre filter from the URL. */
function go_verge_review_genre_filter() {
	$key = isset( $_GET['genero'] ) ? sanitize_key( wp_unslash( $_GET['genero'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$allowed = array_keys( go_verge_review_genre_definitions() );
	$allowed[] = 'outros';
	return in_array( $key, $allowed, true ) ? $key : '';
}

/** IDs matching the active or supplied genre. */
function go_verge_review_ids_for_genre( $key = '' ) {
	$key = $key ? sanitize_key( $key ) : go_verge_review_genre_filter();
	if ( '' === $key ) {
		return array();
	}
	$index = go_verge_review_genre_index();
	return isset( $index[ $key ] ) ? array_values( array_unique( array_map( 'absint', $index[ $key ] ) ) ) : array();
}

/** Apply genre selection to arbitrary WP_Query arguments. */
function go_verge_review_genre_query_args( $args ) {
	$key = go_verge_review_genre_filter();
	if ( '' === $key ) {
		return $args;
	}

	$ids      = go_verge_review_ids_for_genre( $key );
	$existing = ! empty( $args['post__in'] ) ? array_map( 'absint', (array) $args['post__in'] ) : array();
	if ( $existing ) {
		$ids = array_values( array_intersect( $existing, $ids ) );
	}
	$args['post__in'] = $ids ? $ids : array( 0 );
	return $args;
}

/** Filter the real Reviews category archive. Genre links intentionally reload. */
function go_verge_filter_review_archive_by_genre( $query ) {
	if ( is_admin() || ! $query instanceof WP_Query || ! $query->is_main_query() || '' === go_verge_review_genre_filter() ) {
		return;
	}
	if ( ! $query->is_category( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ) ) ) {
		return;
	}
	$query->set( 'post__in', go_verge_review_ids_for_genre() ?: array( 0 ) );
}
add_action( 'pre_get_posts', 'go_verge_filter_review_archive_by_genre', 30 );

/** Render review genre tabs for the independently filterable latest-review stream. */
function go_verge_review_genre_chips( $base_url = '' ) {
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

	$base_url = remove_query_arg( array( 'genero', 'paged', 'page' ), $base_url );
	$search   = function_exists( 'go_verge_editorial_search_term' ) ? go_verge_editorial_search_term() : '';
	if ( '' !== $search ) {
		$base_url = add_query_arg( 'tema', $search, $base_url );
	}

	$active      = go_verge_review_genre_filter();
	$definitions = go_verge_review_genre_definitions();
	$index       = go_verge_review_genre_index();
	$items       = array();
	foreach ( $definitions as $key => $definition ) {
		if ( ! empty( $index[ $key ] ) ) {
			$items[ $key ] = $definition['label'];
		}
	}
	if ( ! empty( $index['outros'] ) ) {
		$items['outros'] = __( 'Outros', 'go-verge' );
	}
	if ( empty( $items ) ) {
		return;
	}
	?>
	<nav class="go-review-genre-filters" aria-label="<?php esc_attr_e( 'Filtrar reviews por gênero', 'go-verge' ); ?>">
		<a href="<?php echo esc_url( $base_url ); ?>" data-go-review-genre-filter=""<?php echo '' === $active ? ' class="is-active" aria-current="page"' : ''; ?>><?php esc_html_e( 'Todos', 'go-verge' ); ?></a>
		<?php foreach ( $items as $key => $label ) : ?>
			<a href="<?php echo esc_url( add_query_arg( 'genero', $key, $base_url ) ); ?>" data-go-review-genre-filter="<?php echo esc_attr( $key ); ?>"<?php echo $active === $key ? ' class="is-active" aria-current="page"' : ''; ?>><?php echo esc_html( $label ); ?></a>
		<?php endforeach; ?>
	</nav>
	<?php
}

/** Bust the genre map whenever editorial metadata changes. */
function go_verge_review_genre_bust_cache( $post_id = 0 ) {
	delete_transient( 'go_verge_review_genre_index_v2' );
}
add_action( 'save_post_post', 'go_verge_review_genre_bust_cache', 250 );
add_action( 'save_post_games', 'go_verge_review_genre_bust_cache', 250 );
add_action( 'deleted_post', 'go_verge_review_genre_bust_cache', 20 );

/**
 * Render the Reviews landing page with a fixed editorial cover and an
 * independently filterable latest-review stream.
 *
 * Genre links replace only the "Últimas reviews" block through progressive
 * enhancement; their hrefs remain fully functional when JavaScript is off.
 *
 * @param string $title        Page heading.
 * @param bool   $breadcrumbs  Whether to print breadcrumbs above the heading.
 * @param string $base_url     Canonical Reviews archive URL.
 */
function go_verge_render_reviews_landing( $title, $breadcrumbs = false, $base_url = '' ) {
	$paged      = max( 1, (int) get_query_var( 'paged' ), (int) get_query_var( 'page' ) );
	$search     = function_exists( 'go_verge_editorial_search_term' ) ? go_verge_editorial_search_term() : '';
	$review_ids = function_exists( 'go_verge_category_ids' )
		? go_verge_category_ids( array( 'reviews', 'review', 'analises', 'analises-de-jogos' ), array( 'review', 'analise' ) )
		: array();

	if ( ! $base_url ) {
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

	$tax_query = array(
		array(
			'taxonomy'         => 'category',
			'field'            => 'term_id',
			'terms'            => $review_ids ? $review_ids : array( 0 ),
			'include_children' => true,
		),
	);

	/* Cover is deliberately unfiltered: changing genre only updates the latest
	 * stream below, exactly as on the three parent editorial hubs. */
	$cover_query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 5,
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			's'                   => $search,
			'tax_query'           => $tax_query,
		)
	);
	$cover_posts = array_values( array_filter( $cover_query->posts, static function ( $post ) { return $post instanceof WP_Post; } ) );
	$cover_ids   = array_map( 'absint', wp_list_pluck( $cover_posts, 'ID' ) );

	$latest_args = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => 12,
		'paged'               => $paged,
		'ignore_sticky_posts' => true,
		'no_found_rows'       => false,
		's'                   => $search,
		'tax_query'           => $tax_query,
	);
	$latest_args  = go_verge_review_genre_query_args( $latest_args );
	$latest_query = new WP_Query( $latest_args );
	$latest_ids   = array_map( 'absint', wp_list_pluck( $latest_query->posts, 'ID' ) );
	$sidebar      = function_exists( 'go_verge_archive_sidebar_modules' )
		? go_verge_archive_sidebar_modules( 'reviews', array_merge( $cover_ids, $latest_ids ) )
		: array();

	get_header();
	?>
	<main id="primary" class="go-main go-review-index go-review-index--review go-editorial-zone go-editorial-zone--games">
		<div class="go-container go-pagehead go-pagehead--search">
			<?php if ( $breadcrumbs && function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
			<h1 class="go-pagehead__title"><?php echo esc_html( $title ); ?></h1>
			<?php if ( function_exists( 'go_verge_render_editorial_search' ) ) { go_verge_render_editorial_search( $base_url ); } ?>
		</div>

		<div class="go-container go-section go-archive-page">
			<?php if ( $cover_posts ) : ?>
				<?php
				$lead = array_shift( $cover_posts );
				go_verge_archive_hero( $lead->ID, array_map( 'absint', wp_list_pluck( $cover_posts, 'ID' ) ), 'reviews' );
				?>
			<?php endif; ?>

			<div class="go-review-filter-scope" data-go-review-filter-scope>
				<div class="go-review-genre-filter-wrap">
					<?php go_verge_review_genre_chips( $base_url ); ?>
				</div>

				<div class="go-archive-body<?php echo $sidebar ? ' go-archive-body--aside' : ''; ?>">
					<div class="go-archive-main">
						<section class="go-archive-section go-review-latest" aria-labelledby="go-review-latest-title">
							<div class="go-section__head"><h2 id="go-review-latest-title" class="go-section__title"><?php esc_html_e( 'Últimas reviews', 'go-verge' ); ?></h2></div>
							<div data-go-review-latest-results aria-live="polite">
								<?php if ( $latest_query->have_posts() ) : ?>
									<div id="go-review-latest-feed" class="go-archive-list">
										<?php
										foreach ( $latest_query->posts as $review_post ) :
											go_verge_archive_list_item( $review_post->ID, array( 'format' => 'reviews', 'show_excerpt' => true, 'show_score' => false ) );
										endforeach;
										?>
									</div>
									<?php go_verge_pagination( $latest_query, array(), array( 'target' => '#go-review-latest-feed' ) ); ?>
								<?php else : ?>
									<div id="go-review-latest-feed" class="go-archive-list">
										<?php get_template_part( 'template-parts/content', 'none' ); ?>
									</div>
								<?php endif; ?>
							</div>
						</section>
					</div>
					<?php if ( $sidebar ) { go_verge_render_archive_sidebar( array_slice( $sidebar, 0, 2 ) ); } ?>
				</div>
			</div>
		</div>
	</main>
	<?php
	wp_reset_postdata();
	get_footer();
}
