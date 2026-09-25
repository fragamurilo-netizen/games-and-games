<?php
/**
 * V46 authority + knowledge graph helpers.
 *
 * This layer connects existing canonical subjects instead of creating new,
 * competing taxonomy pages. It is deliberately conservative: no keyword
 * stuffing, no artificial author credentials and no change to ad markup.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Stable key for comparing internal destinations. */
function go_verge_v46_url_key( $url ) {
	$url = esc_url_raw( (string) $url );
	if ( ! $url ) { return ''; }
	$parts = wp_parse_url( $url );
	if ( ! is_array( $parts ) || empty( $parts['host'] ) ) { return untrailingslashit( strtolower( $url ) ); }
	$scheme = isset( $parts['scheme'] ) ? strtolower( $parts['scheme'] ) : 'https';
	$host   = strtolower( $parts['host'] );
	$path   = isset( $parts['path'] ) ? '/' . ltrim( $parts['path'], '/' ) : '/';
	return untrailingslashit( $scheme . '://' . $host . $path );
}

/** Resolve the one canonical subject used to anchor an article cluster. */
function go_verge_v46_primary_subject( $post_id ) {
	static $cache = array();
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return null; }
	if ( array_key_exists( $post_id, $cache ) ) { return $cache[ $post_id ]; }

	$subject = function_exists( 'go_verge_article_subject' ) ? go_verge_article_subject( $post_id ) : null;
	if ( ! $subject && function_exists( 'go_verge_v17_cluster_subject' ) ) {
		$subject = go_verge_v17_cluster_subject( $post_id );
	}
	if ( ! is_array( $subject ) || empty( $subject['name'] ) || empty( $subject['url'] ) ) {
		$cache[ $post_id ] = null;
		return null;
	}
	$subject['url_key'] = go_verge_v46_url_key( $subject['url'] );
	$cache[ $post_id ] = $subject;
	return $subject;
}

/**
 * Canonical topic URLs attached to an article. The list is cached per request
 * because it is used by the internal-link relation scorer several times.
 */
function go_verge_v46_post_topic_urls( $post_id, $limit = 6 ) {
	static $cache = array();
	$post_id = absint( $post_id );
	$limit   = max( 1, min( 8, absint( $limit ) ) );
	if ( ! $post_id ) { return array(); }
	if ( isset( $cache[ $post_id ] ) ) { return array_slice( $cache[ $post_id ], 0, $limit ); }

	$urls = array();
	$primary = go_verge_v46_primary_subject( $post_id );
	if ( $primary && ! empty( $primary['url_key'] ) ) { $urls[ $primary['url_key'] ] = true; }

	if ( function_exists( 'go_verge_v7_story_topic_chips' ) ) {
		foreach ( go_verge_v7_story_topic_chips( $post_id, 6 ) as $chip ) {
			$key = go_verge_v46_url_key( $chip['url'] ?? '' );
			if ( $key ) { $urls[ $key ] = true; }
		}
	}
	$cache[ $post_id ] = array_keys( $urls );
	return array_slice( $cache[ $post_id ], 0, $limit );
}

/** Content-format slug used to diversify a topic cluster. */
function go_verge_v46_content_type_slug( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return ''; }
	if ( function_exists( 'go_verge_v7_post_content_type' ) ) {
		return sanitize_title( (string) go_verge_v7_post_content_type( $post_id ) );
	}
	$slugs = wp_get_post_terms( $post_id, 'go_content_type', array( 'fields' => 'slugs' ) );
	return is_wp_error( $slugs ) || empty( $slugs ) ? '' : sanitize_title( (string) $slugs[0] );
}

/** Human label for content format. News is intentionally hidden on cards. */
function go_verge_v46_content_type_label( $post_id ) {
	$slug = go_verge_v46_content_type_slug( $post_id );
	if ( ! $slug || 'noticia' === $slug ) { return ''; }
	$term = get_term_by( 'slug', $slug, 'go_content_type' );
	return $term instanceof WP_Term ? trim( (string) $term->name ) : '';
}

/** Manual/editorial inbound links recorded by the existing lightweight index. */
function go_verge_v46_inbound_link_count( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || ! function_exists( 'go_verge_linkpop_counts' ) || ! function_exists( 'go_verge_linkpop_normalize_path' ) ) { return null; }
	static $counts = null;
	if ( null === $counts ) { $counts = go_verge_linkpop_counts(); }
	$path = go_verge_linkpop_normalize_path( get_permalink( $post_id ) );
	return $path ? (int) ( $counts[ $path ] ?? 0 ) : null;
}

/**
 * Rank a subject pool by semantic strength, usefulness and freshness, then
 * introduce restrained format diversity. This prevents a cluster from being
 * four nearly identical breaking-news cards when a useful explainer/guide is
 * available, without allowing an old weak item to outrank a much better match.
 */
function go_verge_v46_rank_cluster_post_ids( $ids, $subject, $limit = 4 ) {
	$ids   = array_values( array_unique( array_filter( array_map( 'absint', (array) $ids ) ) ) );
	$limit = max( 1, min( 6, absint( $limit ) ) );
	if ( ! $ids ) { return array(); }

	$subject_name = trim( wp_strip_all_tags( (string) ( $subject['name'] ?? '' ) ) );
	$subject_key  = function_exists( 'go_verge_v17_cluster_key' ) ? go_verge_v17_cluster_key( $subject_name ) : mb_strtolower( remove_accents( $subject_name ), 'UTF-8' );
	$subject_url  = go_verge_v46_url_key( $subject['url'] ?? '' );
	$now          = current_time( 'timestamp', true );
	$type_weight  = array(
		'final-explicado' => 48,
		'onde-assistir'   => 44,
		'guia'            => 42,
		'especial'        => 34,
		'critica'         => 30,
		'review'          => 30,
		'lista'           => 25,
		'ranking'         => 25,
		'impressoes'      => 22,
		'guia-de-compra'  => 20,
		'noticia'         => 10,
	);
	$bucket_map = array(
		'final-explicado' => 'explain', 'onde-assistir' => 'explain', 'guia' => 'explain', 'especial' => 'explain',
		'critica' => 'analysis', 'review' => 'analysis', 'impressoes' => 'analysis',
		'lista' => 'list', 'ranking' => 'list', 'guia-de-compra' => 'list',
		'noticia' => 'news',
	);

	$ranked = array();
	foreach ( $ids as $id ) {
		if ( 'publish' !== get_post_status( $id ) ) { continue; }
		$score = 100;
		$type  = go_verge_v46_content_type_slug( $id );
		$score += $type_weight[ $type ] ?? 14;

		$title = trim( wp_strip_all_tags( get_the_title( $id ) ) );
		$title_key = function_exists( 'go_verge_v17_cluster_key' ) ? go_verge_v17_cluster_key( $title ) : mb_strtolower( remove_accents( $title ), 'UTF-8' );
		if ( $subject_key && $title_key && false !== strpos( $title_key, $subject_key ) ) { $score += 28; }

		$primary = go_verge_v46_primary_subject( $id );
		if ( $primary && $subject_url && ! empty( $primary['url_key'] ) && $primary['url_key'] === $subject_url ) { $score += 70; }

		$published = (int) get_post_time( 'U', true, $id );
		$age_days  = $published ? max( 0, ( $now - $published ) / DAY_IN_SECONDS ) : 9999;
		if ( $age_days <= 7 ) { $score += 28; }
		elseif ( $age_days <= 30 ) { $score += 20; }
		elseif ( $age_days <= 90 ) { $score += 12; }
		elseif ( $age_days <= 365 ) { $score += 5; }
		if ( has_post_thumbnail( $id ) ) { $score += 4; }

		/* Subject-relevant pages with very few editorial inlinks get a modest
		 * discovery boost. Relevance remains the gate; this never pulls an
		 * unrelated orphan into a cluster. */
		$inbound = go_verge_v46_inbound_link_count( $id );
		if ( 0 === $inbound ) { $score += 16; }
		elseif ( 1 === $inbound ) { $score += 12; }
		elseif ( null !== $inbound && $inbound <= 3 ) { $score += 6; }

		$ranked[ $id ] = array(
			'score'  => $score,
			'bucket' => $bucket_map[ $type ] ?? ( $type ? $type : 'other' ),
		);
	}
	if ( ! $ranked ) { return array(); }

	uksort( $ranked, static function( $a, $b ) use ( $ranked ) {
		if ( $ranked[ $a ]['score'] === $ranked[ $b ]['score'] ) { return (int) $b <=> (int) $a; }
		return $ranked[ $b ]['score'] <=> $ranked[ $a ]['score'];
	} );

	$ordered   = array_map( 'absint', array_keys( $ranked ) );
	$top_score = (int) $ranked[ $ordered[0] ]['score'];
	$selected  = array( $ordered[0] );
	$buckets   = array( $ranked[ $ordered[0] ]['bucket'] => true );

	/* A different format enters early only when it remains close in relevance. */
	foreach ( array_slice( $ordered, 1 ) as $id ) {
		if ( count( $selected ) >= $limit ) { break; }
		$bucket = $ranked[ $id ]['bucket'];
		if ( isset( $buckets[ $bucket ] ) || (int) $ranked[ $id ]['score'] < $top_score - 45 ) { continue; }
		$selected[] = $id;
		$buckets[ $bucket ] = true;
	}
	foreach ( $ordered as $id ) {
		if ( count( $selected ) >= $limit ) { break; }
		if ( ! in_array( $id, $selected, true ) ) { $selected[] = $id; }
	}
	return array_slice( $selected, 0, $limit );
}

/**
 * Related subjects inferred from the articles already displayed on a hub.
 * A subject must recur across at least two stories, which avoids rebuilding a
 * noisy tag cloud while preserving the navigation readers actually use.
 */
function go_verge_v46_related_subjects_from_posts( $post_ids, $exclude_url = '', $limit = 5 ) {
	$post_ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $post_ids ) ) ) );
	$limit    = max( 1, min( 6, absint( $limit ) ) );
	if ( count( $post_ids ) < 2 || ! function_exists( 'go_verge_v7_story_topic_chips' ) ) { return array(); }

	$exclude_key = go_verge_v46_url_key( $exclude_url );
	$role_weight = array( 'primary'=>12, 'work'=>10, 'entity'=>8, 'topic'=>6, 'context'=>3, 'related'=>4 );
	$pool = array();
	foreach ( array_slice( $post_ids, 0, 18 ) as $post_id ) {
		$seen_for_post = array();
		foreach ( go_verge_v7_story_topic_chips( $post_id, 6 ) as $chip ) {
			$url = esc_url_raw( (string) ( $chip['url'] ?? '' ) );
			$key = go_verge_v46_url_key( $url );
			$label = trim( wp_strip_all_tags( (string) ( $chip['label'] ?? '' ) ) );
			if ( ! $key || ! $label || $key === $exclude_key || isset( $seen_for_post[ $key ] ) ) { continue; }
			$seen_for_post[ $key ] = true;
			$role = sanitize_key( (string) ( $chip['role'] ?? 'related' ) );
			if ( ! isset( $pool[ $key ] ) ) { $pool[ $key ] = array( 'label'=>$label, 'url'=>$url, 'count'=>0, 'score'=>0 ); }
			$pool[ $key ]['count']++;
			$pool[ $key ]['score'] += $role_weight[ $role ] ?? 4;
		}
	}
	$pool = array_filter( $pool, static function( $item ) { return (int) $item['count'] >= 2; } );
	uasort( $pool, static function( $a, $b ) {
		$as = (int) $a['score'] + min( 20, (int) $a['count'] * 4 );
		$bs = (int) $b['score'] + min( 20, (int) $b['count'] * 4 );
		if ( $as === $bs ) { return strcasecmp( $a['label'], $b['label'] ); }
		return $bs <=> $as;
	} );
	return array_slice( array_values( $pool ), 0, $limit );
}

/** Compact cross-cluster navigation for the bottom of first-page subject hubs. */
function go_verge_v46_render_related_subjects( $post_ids, $exclude_url = '', $limit = 5 ) {
	$items = go_verge_v46_related_subjects_from_posts( $post_ids, $exclude_url, $limit );
	if ( ! $items ) { return false; }
	?>
	<nav class="go-related-subjects-v46" aria-label="<?php esc_attr_e( 'Assuntos relacionados', 'go-verge' ); ?>">
		<span class="go-related-subjects-v46__label"><?php esc_html_e( 'Explore também', 'go-verge' ); ?></span>
		<div class="go-related-subjects-v46__links">
			<?php foreach ( $items as $item ) : ?><a href="<?php echo esc_url( $item['url'] ); ?>"><?php echo esc_html( $item['label'] ); ?></a><?php endforeach; ?>
		</div>
	</nav>
	<?php
	return true;
}

/** Late presentation layer for visible trust + cluster navigation. */
function go_verge_enqueue_overdrive_v46_authority_knowledge() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-v46-authority-knowledge.min.css';
	wp_enqueue_style(
		'go-verge-overdrive-v46-authority-knowledge',
		GO_VERGE_URI . $rel,
		array( 'go-verge-overdrive-v40-topic-hero' ),
		go_verge_asset_version( $rel )
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_enqueue_overdrive_v46_authority_knowledge', 39500 );
