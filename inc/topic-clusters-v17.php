<?php
/**
 * Topic clusters V17.
 *
 * Turns a specific linked subject/tag into an internal recirculation cluster.
 * It never creates terms automatically and prefers specific franchises/titles
 * (Outer Banks, Meu Nome é Farah, Metal Gear Solid) over broad services
 * (Netflix, streaming) whenever both are assigned to the story.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Normalize text for safe subject matching. */
function go_verge_v17_cluster_key( $value ) {
	$value = remove_accents( wp_strip_all_tags( (string) $value ) );
	$value = mb_strtolower( $value, 'UTF-8' );
	$value = preg_replace( '/[^a-z0-9]+/u', ' ', $value );
	return trim( preg_replace( '/\s+/', ' ', (string) $value ) );
}

/** Broad distribution/editorial labels are useful fallbacks, not first choice. */
function go_verge_v17_cluster_is_broad( $name ) {
	$key = go_verge_v17_cluster_key( $name );
	$broad = array(
		'netflix', 'streaming', 'globoplay', 'disney', 'disney plus', 'prime video',
		'amazon prime video', 'max', 'hbo max', 'record', 'recordplus', 'record plus',
		'games', 'jogos', 'entretenimento', 'tecnologia', 'series', 'filmes', 'anime',
		'novelas turcas', 'producoes turcas', 'guias', 'reviews', 'criticas',
	);
	return in_array( $key, $broad, true );
}


/**
 * Search-intent/episode tags are useful taxonomy, but a recurring cluster in
 * the feed should prefer the durable franchise label when both are assigned.
 * Example: MEU NOME É FARAH beats MEU NOME É FARAH 2ª TEMPORADA.
 */
function go_verge_v17_cluster_is_derivative( $name ) {
	$key = go_verge_v17_cluster_key( $name );
	if ( '' === $key ) { return false; }
	$needles = array(
		'temporada', 'episodio', 'episodios', 'capitulo', 'capitulos', 'final explicado',
		'final', 'estreia', 'trailer', 'elenco', 'onde assistir', 'data de estreia',
		'resumo', 'recap', '2 temporada', '3 temporada', '4 temporada', '5 temporada',
	);
	foreach ( $needles as $needle ) {
		if ( false !== strpos( $key, $needle ) ) { return true; }
	}
	return false;
}

/**
 * Turn a V36 canonical topic destination into the subject shape used by cards,
 * article metadata and recirculation clusters.
 *
 * This keeps the public link typed: Production -> Production hub, Game -> Game
 * hub, Entity -> curated entity hub. Generic /assunto/ is reserved for concepts
 * that do not have a first-class catalogue object.
 */
function go_verge_v36_cluster_subject_from_destination( $destination, $source = 'v36-canonical' ) {
	if ( ! is_array( $destination ) || empty( $destination['url'] ) || empty( $destination['name'] ) ) { return null; }
	$type = (string) ( $destination['type'] ?? '' );
	$id   = absint( $destination['id'] ?? 0 );
	$map  = array(
		'games'       => __( 'Jogo', 'go-verge' ),
		'productions' => __( 'Produção', 'go-verge' ),
		'go_entity'   => __( 'Entidade', 'go-verge' ),
		'platform'    => __( 'Plataforma', 'go-verge' ),
		'service'     => __( 'Serviço', 'go-verge' ),
		'section'     => __( 'Editoria', 'go-verge' ),
	);
	$type_label = $map[ $type ] ?? __( 'Assunto', 'go-verge' );
	$image = '';
	if ( $id && in_array( $type, array( 'games', 'productions', 'go_entity' ), true ) ) {
		if ( 'go_entity' === $type ) {
			$types = get_the_terms( $id, 'go_entity_type' );
			if ( $types && ! is_wp_error( $types ) ) { $type_label = $types[0]->name; }
		}
		$image = get_the_post_thumbnail_url( $id, 'thumbnail' ) ?: '';
	}
	/* Do not run a related-content query while rendering every archive row.
	 * The cluster itself queries related IDs only when it is actually rendered. */
	$related_count = 0;
	return array(
		'id'            => $id,
		'type'          => $type ?: 'topic_hub',
		'name'          => (string) $destination['name'],
		'url'           => (string) $destination['url'],
		'image'         => $image,
		'type_label'    => $type_label,
		'related_count' => $related_count,
		'source'        => $source,
	);
}

/** Resolve a label/slug to a typed first-class hub when one exists. */
function go_verge_v36_cluster_catalog_subject( $label, $source = 'v36-canonical' ) {
	if ( ! function_exists( 'go_verge_v36_topic_destination' ) ) { return null; }
	$destination = go_verge_v36_topic_destination( sanitize_title( (string) $label ) );
	return go_verge_v36_cluster_subject_from_destination( $destination, $source );
}

/**
 * Pick the best specific assigned tag. Title matches are intentionally strong:
 * if "Outer Banks" is in the headline and is an assigned tag with an archive,
 * it should beat a generic "Netflix" tag even when Netflix has more posts.
 */
function go_verge_v17_specific_tag_subject( $post_id ) {
	$post_id = absint( $post_id );
	$tags = get_the_terms( $post_id, 'post_tag' );
	if ( ! $post_id || empty( $tags ) || is_wp_error( $tags ) ) { return null; }

	$title = go_verge_v17_cluster_key( get_the_title( $post_id ) );
	$slug  = go_verge_v17_cluster_key( (string) get_post_field( 'post_name', $post_id ) );
	$best  = null;
	$best_score = -9999;

	foreach ( $tags as $tag ) {
		if ( ! ( $tag instanceof WP_Term ) || (int) $tag->count < 2 ) { continue; }
		if ( function_exists( 'go_verge_subject_tag_is_specific' ) && ! go_verge_subject_tag_is_specific( $tag ) ) { continue; }
		$key = go_verge_v17_cluster_key( $tag->name );
		if ( '' === $key || mb_strlen( str_replace( ' ', '', $key ) ) < 4 ) { continue; }

		$score = min( 18, max( 0, (int) $tag->count ) );
		$score += min( 22, mb_strlen( $key ) );
		if ( false !== strpos( ' ' . $title . ' ', ' ' . $key . ' ' ) ) { $score += 120; }
		elseif ( false !== strpos( $title, $key ) ) { $score += 92; }
		if ( false !== strpos( $slug, $key ) ) { $score += 42; }
		if ( go_verge_v17_cluster_is_broad( $tag->name ) ) { $score -= 95; }
		if ( go_verge_v17_cluster_is_derivative( $tag->name ) ) { $score -= 34; }

		if ( $score > $best_score ) {
			/* A tag with the same durable title as a Production/Game is only an
			 * alias. Link the canonical object directly instead of leaking an old
			 * /tag/ or /assunto/ URL into archive metadata. */
			$canonical = go_verge_v36_cluster_catalog_subject( $tag->name, 'v36-specific-canonical' );
			if ( $canonical ) {
				$best_score = $score;
				$best = $canonical;
				continue;
			}
			$url = get_term_link( $tag );
			if ( is_wp_error( $url ) ) { continue; }
			$best_score = $score;
			$best = array(
				'id'            => (int) $tag->term_id,
				'type'          => 'post_tag',
				'name'          => $tag->name,
				'url'           => $url,
				'image'         => '',
				'type_label'    => __( 'Assunto', 'go-verge' ),
				'related_count' => (int) $tag->count,
				'source'        => 'v17-specific-tag',
			);
		}
	}
	return $best;
}


/**
 * V19: resolve the durable franchise/title from the headline itself.
 *
 * This fixes cases where an automatically inferred secondary entity ("Kildare")
 * outranks the actual franchise in the headline ("Outer Banks"), and where only
 * a derivative tag ("Meu Nome é Farah 2ª temporada") is assigned. Existing tag
 * archives are preferred. When no canonical base tag exists, a site-search URL
 * is used as a safe fallback so the label still leads to the site's coverage.
 */
function go_verge_v19_title_cluster_subject( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return null; }

	$title = go_verge_v17_cluster_key( get_the_title( $post_id ) );
	if ( '' === $title ) { return null; }

	/* V21 canonical franchise names requested by the editorial navigation model.
	 * These are durable brands/titles, never season/location/character aliases. */
	$canonical_titles = (array) apply_filters( 'go_verge_v21_canonical_topic_titles', array(
		'Outer Banks', 'Meu Nome é Farah', 'One Piece', 'Metal Gear Solid',
	) );
	foreach ( $canonical_titles as $canonical_label ) {
		$canonical_key = go_verge_v17_cluster_key( $canonical_label );
		if ( ! $canonical_key || false === strpos( ' ' . $title . ' ', ' ' . $canonical_key . ' ' ) ) { continue; }
		$catalog_subject = go_verge_v36_cluster_catalog_subject( $canonical_label, 'v36-title-canonical' );
		if ( $catalog_subject ) { return $catalog_subject; }
		$canonical_term = get_term_by( 'name', $canonical_label, 'post_tag' );
		if ( ! ( $canonical_term instanceof WP_Term ) ) { $canonical_term = get_term_by( 'slug', sanitize_title( $canonical_label ), 'post_tag' ); }
		if ( $canonical_term instanceof WP_Term && (int) $canonical_term->count >= 2 ) {
			$url = get_term_link( $canonical_term );
			if ( ! is_wp_error( $url ) ) {
				return array( 'id'=>(int)$canonical_term->term_id, 'type'=>'post_tag', 'name'=>$canonical_term->name, 'url'=>$url, 'image'=>'', 'type_label'=>__( 'Assunto','go-verge' ), 'related_count'=>(int)$canonical_term->count, 'source'=>'v21-canonical-title' );
			}
		}
		return array( 'id'=>0, 'type'=>'topic_hub', 'name'=>$canonical_label, 'url'=>function_exists('go_verge_v21_topic_hub_url')?go_verge_v21_topic_hub_url($canonical_label):home_url(user_trailingslashit('assunto/'.sanitize_title($canonical_label))), 'image'=>'', 'type_label'=>__( 'Assunto','go-verge' ), 'related_count'=>2, 'source'=>'v21-canonical-hub' );
	}

	$build_term = static function ( $term, $source = 'v19-title-tag' ) {
		if ( ! ( $term instanceof WP_Term ) || 'post_tag' !== $term->taxonomy || (int) $term->count < 2 ) {
			return null;
		}
		$canonical = go_verge_v36_cluster_catalog_subject( $term->name, $source . '-canonical' );
		if ( $canonical ) { return $canonical; }
		$url = get_term_link( $term );
		if ( is_wp_error( $url ) ) { return null; }
		return array(
			'id'            => (int) $term->term_id,
			'type'          => 'post_tag',
			'name'          => $term->name,
			'url'           => $url,
			'image'         => '',
			'type_label'    => __( 'Assunto', 'go-verge' ),
			'related_count' => (int) $term->count,
			'source'        => $source,
		);
	};

	/* Cache a bounded set of recurring tags for the whole request. */
	static $candidate_terms = null;
	if ( null === $candidate_terms ) {
		$candidate_terms = get_terms( array(
			'taxonomy'   => 'post_tag',
			'hide_empty' => true,
			'number'     => 500,
			'orderby'    => 'count',
			'order'      => 'DESC',
		) );
		if ( is_wp_error( $candidate_terms ) ) { $candidate_terms = array(); }
	}

	$best = null;
	$best_score = -1;
	foreach ( $candidate_terms as $term ) {
		if ( ! ( $term instanceof WP_Term ) || (int) $term->count < 2 ) { continue; }
		if ( go_verge_v17_cluster_is_broad( $term->name ) || go_verge_v17_cluster_is_derivative( $term->name ) ) { continue; }
		if ( function_exists( 'go_verge_subject_tag_is_specific' ) && ! go_verge_subject_tag_is_specific( $term ) ) { continue; }

		$key = go_verge_v17_cluster_key( $term->name );
		if ( '' === $key || mb_strlen( str_replace( ' ', '', $key ) ) < 4 ) { continue; }
		if ( false === strpos( ' ' . $title . ' ', ' ' . $key . ' ' ) && false === strpos( $title, $key ) ) { continue; }

		/* Long, exact franchise names beat shorter people/character/location tags. */
		$score = 600 + ( mb_strlen( $key ) * 8 ) + min( 30, (int) $term->count );
		if ( 0 === strpos( $title, $key ) ) { $score += 45; }
		if ( $score > $best_score ) {
			$built = $build_term( $term );
			if ( $built ) {
				$best = $built;
				$best_score = $score;
			}
		}
	}
	if ( $best ) { return $best; }

	/*
	 * If only a season/episode tag is assigned, strip the derivative suffix and
	 * try the canonical base tag. This turns "Meu Nome é Farah 2ª temporada"
	 * into "Meu Nome é Farah" and "One Piece 3ª temporada" into "One Piece".
	 */
	$assigned = get_the_terms( $post_id, 'post_tag' );
	if ( $assigned && ! is_wp_error( $assigned ) ) {
		foreach ( $assigned as $tag ) {
			if ( ! ( $tag instanceof WP_Term ) || ! go_verge_v17_cluster_is_derivative( $tag->name ) ) { continue; }

			$base = trim( (string) preg_replace(
				'/\s+(?:(?:\d+|[ivx]+)[ªaºo]?\s*)?(?:temporada|epis[oó]dio|cap[ií]tulo)(?:\s+.*)?$/iu',
				'',
				$tag->name
			) );
			$base = preg_replace( '/\s+(?:final explicado|final|estreia|trailer|elenco|onde assistir|data de estreia|resumo|recap)\b.*$/iu', '', $base );
			$base = trim( (string) $base );
			if ( mb_strlen( preg_replace( '/\s+/u', '', $base ) ) < 4 ) { continue; }

			$base_key = go_verge_v17_cluster_key( $base );
			if ( false === strpos( $title, $base_key ) ) { continue; }

			$canonical = get_term_by( 'name', $base, 'post_tag' );
			if ( ! ( $canonical instanceof WP_Term ) ) {
				$canonical = get_term_by( 'slug', sanitize_title( $base ), 'post_tag' );
			}
			$built = $build_term( $canonical, 'v19-derivative-base' );
			if ( $built ) { return $built; }

			$catalog_subject = go_verge_v36_cluster_catalog_subject( $base, 'v36-derivative-canonical' );
			if ( $catalog_subject ) { return $catalog_subject; }

			/* No taxonomy/catalogue hub exists: only then use the generic topic route. */
			return array(
				'id'            => 0,
				'type'          => 'topic_hub',
				'name'          => $base,
				'url'           => function_exists( 'go_verge_v21_topic_hub_url' ) ? go_verge_v21_topic_hub_url( $base ) : home_url( user_trailingslashit( 'assunto/' . sanitize_title( $base ) ) ),
				'image'         => '',
				'type_label'    => __( 'Assunto', 'go-verge' ),
				'related_count' => max( 2, (int) $tag->count ),
				'source'        => 'v21-topic-hub',
			);
		}
	}

	return null;
}

/** Resolve a cluster subject, favoring linked games/entities then a specific tag. */
function go_verge_v17_cluster_subject( $post_id ) {
	$post_id = absint( $post_id );
	$base = function_exists( 'go_verge_article_subject' ) ? go_verge_article_subject( $post_id ) : null;
	$title_subject = function_exists( 'go_verge_v19_title_cluster_subject' ) ? go_verge_v19_title_cluster_subject( $post_id ) : null;
	$specific = go_verge_v17_specific_tag_subject( $post_id );

	/* Manual choice and explicit catalogue relationships are authoritative.
	 * A real Production/Game link must never be replaced by a headline tag. */
	if ( is_array( $base ) && 'explicit' === (string) ( $base['source'] ?? '' ) ) {
		return $base;
	}
	if ( is_array( $base ) && in_array( (string) ( $base['type'] ?? '' ), array( 'games', 'productions' ), true )
		&& in_array( (string) ( $base['source'] ?? '' ), array( 'linked', 'linked-canonical' ), true ) ) {
		return $base;
	}

	$title = go_verge_v17_cluster_key( get_the_title( $post_id ) );
	$base_name = is_array( $base ) ? go_verge_v17_cluster_key( (string) ( $base['name'] ?? '' ) ) : '';

	/*
	 * Headline franchise beats an automatic secondary entity. A linked game/entity
	 * is kept when its own name is actually present in the headline.
	 */
	if ( $title_subject ) {
		if ( ! $base ) { return $title_subject; }
		if ( go_verge_v17_cluster_is_broad( (string) ( $base['name'] ?? '' ) ) ) { return $title_subject; }
		if ( '' === $base_name || false === strpos( $title, $base_name ) ) { return $title_subject; }

		$title_name = go_verge_v17_cluster_key( (string) ( $title_subject['name'] ?? '' ) );
		if ( $title_name && mb_strlen( $title_name ) > mb_strlen( $base_name ) && false !== strpos( $title, $title_name ) ) {
			return $title_subject;
		}
	}

	if ( $specific ) {
		if ( ! $base || go_verge_v17_cluster_is_broad( (string) ( $base['name'] ?? '' ) ) ) { return $specific; }
		$specific_name = go_verge_v17_cluster_key( (string) $specific['name'] );
		if ( false !== strpos( $title, $specific_name ) && ( '' === $base_name || false === strpos( $title, $base_name ) ) ) { return $specific; }
	}

	return $base ?: $title_subject ?: $specific;
}

/** Related IDs for the resolved subject. */
function go_verge_v17_cluster_post_ids( $post_id, $subject, $limit = 4 ) {
	$post_id = absint( $post_id );
	$limit   = max( 1, min( 6, absint( $limit ) ) );
	if ( ! is_array( $subject ) ) { return array(); }
	$type = (string) ( $subject['type'] ?? '' );
	$id   = absint( $subject['id'] ?? 0 );
	$pool_limit = max( 14, $limit * 4 );
	$ids = array();

	if ( 'topic_hub' === $type && function_exists( 'go_verge_v21_topic_query' ) ) {
		$q = go_verge_v21_topic_query( sanitize_title( (string) ( $subject['name'] ?? '' ) ), 1, $pool_limit + 1 );
		$ids = array_values( array_filter( array_map( 'absint', wp_list_pluck( $q->posts, 'ID' ) ), static function( $candidate_id ) use ( $post_id ) { return $candidate_id && $candidate_id !== $post_id; } ) );
	} elseif ( $id && 'post_tag' === $type ) {
		$q = new WP_Query( array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => $pool_limit,
			'post__not_in'        => array( $post_id ),
			'tag_id'              => $id,
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'orderby'             => 'date',
			'order'               => 'DESC',
		) );
		$ids = array_map( 'absint', wp_list_pluck( $q->posts, 'ID' ) );
	} elseif ( $id && in_array( $type, array( 'games', 'productions', 'go_entity' ), true ) && function_exists( 'go_verge_product_related_post_ids' ) ) {
		$ids = array_values( array_filter( array_map( 'absint', go_verge_product_related_post_ids( $id, $type, $pool_limit, array( 'exclude' => array( $post_id ) ) ) ) ) );
	}

	if ( is_singular('post') && function_exists('go_verge_single_recommendation_eligible') ) {
		$desk = go_verge_post_editorial_desk($post_id);
		$ids = array_values(array_filter($ids,static function($id)use($post_id,$desk){
			return go_verge_single_recommendation_eligible($id,$post_id) && (!$desk || $desk===go_verge_post_editorial_desk($id));
		}));
	}
	if ( ! $ids ) { return array(); }
	if ( function_exists( 'go_verge_v46_rank_cluster_post_ids' ) ) {
		return go_verge_v46_rank_cluster_post_ids( $ids, $subject, $limit );
	}
	return array_slice( $ids, 0, $limit );
}

/** Render the internal topic cluster. Returns true only when useful coverage exists. */
function go_verge_render_topic_cluster_v17( $post_id = null ) {
	$post_id = $post_id ? absint( $post_id ) : get_the_ID();
	$subject = go_verge_v17_cluster_subject( $post_id );
	if ( ! $subject || empty( $subject['url'] ) || empty( $subject['name'] ) ) { return false; }

	$ids = go_verge_v17_cluster_post_ids( $post_id, $subject, 4 );
	if ( count( $ids ) < 2 ) { return false; }
	$name = trim( wp_strip_all_tags( (string) $subject['name'] ) );
	?>
	<section class="go-topic-cluster-v17" aria-labelledby="go-topic-cluster-v17-title-<?php echo esc_attr( $post_id ); ?>">
		<div class="go-topic-cluster-v17__head">
			<div>
				<span class="go-topic-cluster-v17__eyebrow"><?php esc_html_e( 'Continue no assunto', 'go-verge' ); ?></span>
				<h2 id="go-topic-cluster-v17-title-<?php echo esc_attr( $post_id ); ?>"><?php echo esc_html( $name ); ?></h2>
			</div>
			<a class="go-topic-cluster-v17__all" href="<?php echo esc_url( $subject['url'] ); ?>"><?php echo esc_html( sprintf( __( 'Ver tudo sobre %s', 'go-verge' ), $name ) ); ?><span aria-hidden="true">→</span></a>
		</div>
		<div class="go-topic-cluster-v17__grid">
			<?php foreach ( $ids as $related_id ) : ?>
				<article class="go-topic-cluster-v17__card">
					<a class="go-topic-cluster-v17__media" href="<?php echo esc_url( get_permalink( $related_id ) ); ?>" aria-hidden="true" tabindex="-1">
						<?php echo get_the_post_thumbnail( $related_id, 'go_card', array( 'loading' => 'lazy', 'decoding' => 'async', 'alt' => '' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
					</a>
					<div class="go-topic-cluster-v17__body">
						<?php $format_label = function_exists( 'go_verge_v46_content_type_label' ) ? go_verge_v46_content_type_label( $related_id ) : ''; ?>
						<?php if ( $format_label ) : ?><span class="go-topic-cluster-v17__format"><?php echo esc_html( $format_label ); ?></span><?php endif; ?>
						<h3><a href="<?php echo esc_url( get_permalink( $related_id ) ); ?>"><?php echo esc_html( get_the_title( $related_id ) ); ?></a></h3>
						<?php if ( function_exists( 'go_verge_time_html' ) ) : ?><div class="go-topic-cluster-v17__meta"><?php echo go_verge_time_html( $related_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
					</div>
				</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
	return true;
}
