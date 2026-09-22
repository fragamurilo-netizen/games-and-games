<?php
/**
 * Game pages — shared presentation and read-only catalogue queries.
 *
 * Uses the existing games CPT and metadata. No migrations, new tables or
 * frontend database writes. The same card renders on page one and load-more.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_verge_games_surface_assets() {
	if ( is_admin() || ! ( is_singular( 'games' ) || is_page( 'biblioteca-de-games' ) || is_page_template( 'page-biblioteca-de-games.php' ) ) ) { return; }
	$css = '/assets/css/games-surfaces.css';
	$js  = '/assets/js/games-surfaces.js';
	wp_enqueue_style( 'go-verge-games-surfaces', GO_VERGE_URI . $css, array( 'go-verge-release-38126' ), go_verge_asset_version( $css ) );
	wp_enqueue_script( 'go-verge-games-surfaces', GO_VERGE_URI . $js, array(), go_verge_asset_version( $js ), true );
	wp_script_add_data( 'go-verge-games-surfaces', 'strategy', 'defer' );
}
add_action( 'wp_enqueue_scripts', 'go_verge_games_surface_assets', 49740 );

/** Local UI icons, intentionally independent of icon fonts or remote scripts. */
function go_verge_games_icon( $name ) {
	$paths = array(
		'arrow'    => '<path d="M5 12h14m-6-6 6 6-6 6"/>',
		'external' => '<path d="M14 4h6v6m0-6L10 14M10 5H5v14h14v-5"/>',
		'search'   => '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4 4"/>',
		'game'     => '<path d="M7 7h10c2 0 3 2 3.5 5l.5 4c.3 3-2 4-4 2l-2-2H9l-2 2c-2 2-4.3 1-4-2l.5-4C4 9 5 7 7 7Z"/><path d="M8 10v4m-2-2h4m5-1h.01M18 13h.01"/>',
		'play'     => '<path d="m9 5 11 7-11 7Z"/>',
		'grid'     => '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
		'list'     => '<path d="M9 5h12M9 12h12M9 19h12M3 5h1M3 12h1M3 19h1"/>',
		'close'    => '<path d="m6 6 12 12M6 18 18 6"/>',
		'expand'   => '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/>',
		'chevron'  => '<path d="m9 5 7 7-7 7"/>',
		'filter'   => '<path d="M3 6h18M6 12h12M10 18h4"/>',
	);
	if ( ! isset( $paths[ $name ] ) ) { return ''; }
	return '<svg class="od-games-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' . $paths[ $name ] . '</svg>';
}

/** Do not turn an imprecise release window ("2026", "TBA") into a date. */
function go_verge_games_release_label( $value ) {
	$value = trim( wp_strip_all_tags( (string) $value ) );
	if ( preg_match( '/^(\d{4})-(\d{2})-(\d{2})$/', $value, $m ) && checkdate( (int) $m[2], (int) $m[3], (int) $m[1] ) ) {
		return $m[3] . '/' . $m[2] . '/' . $m[1];
	}
	return $value;
}

function go_verge_games_status_labels() {
	return array( 'announced' => 'Anunciado', 'development' => 'Em desenvolvimento', 'early_access' => 'Acesso antecipado', 'released' => 'Lançado', 'delayed' => 'Adiado', 'cancelled' => 'Cancelado' );
}

function go_verge_games_status( $post_id, $game ) {
	$labels = go_verge_games_status_labels();
	$key = isset( $game['release_status'] ) ? (string) $game['release_status'] : '';
	if ( isset( $labels[ $key ] ) ) { return array( 'key' => $key, 'label' => $labels[ $key ] ); }
	$terms = get_the_terms( $post_id, 'game_status' );
	if ( ! is_wp_error( $terms ) && ! empty( $terms ) ) {
		// The legacy taxonomy also stores personal statuses (played, backlog).
		// Only known release states belong in this public release-status UI.
		foreach ( $terms as $term ) {
			foreach ( $labels as $status_key => $label ) {
				if ( in_array( $term->slug, array( str_replace( '_', '-', $status_key ), sanitize_title( $label ) ), true ) ) {
					return array( 'key' => $status_key, 'label' => $label );
				}
			}
		}
	}
	return array( 'key' => '', 'label' => '' );
}

/** Keep familiar platform families in the UI; match both vocabularies in use. */
function go_verge_games_platforms() {
	return array(
		'pc'          => array( 'label' => 'PC',          'pattern' => '(^|[^[:alnum:]])(PC|Windows|Linux|macOS|Mac)([^[:alnum:]]|$)' ),
		'playstation' => array( 'label' => 'PlayStation', 'pattern' => '(PlayStation|(^|[^[:alnum:]])PS[1-5P]([^[:alnum:]]|$)|PS[[:space:]]Vita)' ),
		'xbox'        => array( 'label' => 'Xbox',        'pattern' => 'Xbox' ),
		'nintendo'    => array( 'label' => 'Nintendo',    'pattern' => '(Nintendo|Switch|Wii|GameCube|(^|[^[:alnum:]])[23]DS([^[:alnum:]]|$))' ),
		'android'     => array( 'label' => 'Android',     'pattern' => 'Android' ),
		'ios'         => array( 'label' => 'iOS',         'pattern' => '(^|[^[:alnum:]])(iOS|iPhone|iPad)([^[:alnum:]]|$)' ),
	);
}

/** Safe scalar input: malformed ?jogo[]=... must not generate a PHP warning. */
function go_verge_games_get_input( $key ) {
	if ( ! isset( $_GET[ $key ] ) || ! is_scalar( $_GET[ $key ] ) ) { return ''; } // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	return wp_html_excerpt( sanitize_text_field( wp_unslash( (string) $_GET[ $key ] ) ), 200, '' ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
}

function go_verge_games_library_state() {
	$platforms = go_verge_games_platforms();
	$statuses = go_verge_games_status_labels();
	$platform = sanitize_key( go_verge_games_get_input( 'plataforma' ) );
	$status = sanitize_key( go_verge_games_get_input( 'status' ) );
	$order = sanitize_key( go_verge_games_get_input( 'ordem' ) );
	return array(
		'jogo'       => go_verge_games_get_input( 'jogo' ),
		'plataforma' => isset( $platforms[ $platform ] ) ? $platform : '',
		'status'     => isset( $statuses[ $status ] ) ? $status : '',
		'ordem'      => in_array( $order, array( 'recentes', 'atualizados', 'az' ), true ) ? $order : 'recentes',
	);
}

function go_verge_games_library_query_args( $state, $page ) {
	$args = array(
		'post_type' => 'games', 'post_status' => 'publish', 'has_password' => false,
		'posts_per_page' => 24, 'paged' => max( 1, absint( $page ) ),
		'orderby' => array( 'date' => 'DESC', 'ID' => 'DESC' ),
		'ignore_sticky_posts' => true, 'no_found_rows' => false,
		'od_games_catalog' => 1, 'od_games_platform' => $state['plataforma'], 'od_games_status' => $state['status'],
	);
	if ( '' !== $state['jogo'] ) { $args['s'] = $state['jogo']; $args['search_columns'] = array( 'post_title' ); }
	if ( 'az' === $state['ordem'] ) { $args['orderby'] = array( 'title' => 'ASC', 'ID' => 'ASC' ); }
	if ( 'atualizados' === $state['ordem'] ) { $args['orderby'] = array( 'modified' => 'DESC', 'ID' => 'DESC' ); }
	return $args;
}

/**
 * OR across a taxonomy and legacy metadata without a join multiplying cards.
 * This only runs on the signed, opt-in catalogue query (also on AJAX page 2).
 * All user choices are closed whitelists; values are always prepared.
 */
function go_verge_games_library_where( $where, $query ) {
	if ( ! $query->get( 'od_games_catalog' ) || 'games' !== $query->get( 'post_type' ) ) { return $where; }
	global $wpdb;
	$platforms = go_verge_games_platforms();
	$key = $query->get( 'od_games_platform' );
	if ( is_string( $key ) && isset( $platforms[ $key ] ) ) {
		$where .= $wpdb->prepare(
			" AND (EXISTS (SELECT 1 FROM {$wpdb->postmeta} od_gp WHERE od_gp.post_id = {$wpdb->posts}.ID AND od_gp.meta_key IN ('_go_platforms','_go_plataforma') AND od_gp.meta_value REGEXP %s) OR EXISTS (SELECT 1 FROM {$wpdb->term_relationships} od_gr INNER JOIN {$wpdb->term_taxonomy} od_gt ON od_gt.term_taxonomy_id = od_gr.term_taxonomy_id INNER JOIN {$wpdb->terms} od_gn ON od_gn.term_id = od_gt.term_id WHERE od_gr.object_id = {$wpdb->posts}.ID AND od_gt.taxonomy IN ('go_platform','game_platform') AND (od_gn.slug = %s OR od_gn.name REGEXP %s)))",
			$platforms[ $key ]['pattern'], $key, $platforms[ $key ]['pattern']
		);
	}
	$statuses = go_verge_games_status_labels();
	$status = $query->get( 'od_games_status' );
	if ( is_string( $status ) && isset( $statuses[ $status ] ) ) {
		$where .= $wpdb->prepare(
			" AND (EXISTS (SELECT 1 FROM {$wpdb->postmeta} od_gs WHERE od_gs.post_id = {$wpdb->posts}.ID AND od_gs.meta_key = '_go_release_status' AND od_gs.meta_value = %s) OR (NOT EXISTS (SELECT 1 FROM {$wpdb->postmeta} od_gx WHERE od_gx.post_id = {$wpdb->posts}.ID AND od_gx.meta_key = '_go_release_status' AND od_gx.meta_value <> '') AND EXISTS (SELECT 1 FROM {$wpdb->term_relationships} od_sr INNER JOIN {$wpdb->term_taxonomy} od_st ON od_st.term_taxonomy_id = od_sr.term_taxonomy_id INNER JOIN {$wpdb->terms} od_sn ON od_sn.term_id = od_st.term_id WHERE od_sr.object_id = {$wpdb->posts}.ID AND od_st.taxonomy = 'game_status' AND od_sn.slug IN (%s,%s))))",
			$status, sanitize_title( $statuses[ $status ] ), str_replace( '_', '-', $status )
		);
	}
	return $where;
}
add_filter( 'posts_where', 'go_verge_games_library_where', 10, 2 );

/** Platform text falls back to assigned terms when the old field is empty. */
function go_verge_games_platform_text( $post_id, $game ) {
	$value = trim( (string) ( $game['platforms'] ?? '' ) );
	if ( '' !== $value ) { return $value; }
	foreach ( array( 'go_platform', 'game_platform' ) as $taxonomy ) {
		$terms = get_the_terms( $post_id, $taxonomy );
		if ( ! is_wp_error( $terms ) && $terms ) { return implode( ', ', wp_list_pluck( $terms, 'name' ) ); }
	}
	return '';
}

/** Rendering is deliberately shared with functions.php's AJAX card callback. */
function go_verge_games_catalog_card( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return; }
	$game = go_verge_game_data( $post_id );
	$name = function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $post_id ) : get_the_title( $post_id );
	$status = go_verge_games_status( $post_id, $game );
	$platforms = go_verge_games_platform_text( $post_id, $game );
	$release = go_verge_games_release_label( $game['release_date'] );
	$image_id = get_post_thumbnail_id( $post_id );
	if ( ! $image_id && ! empty( $game['hero_image_id'] ) ) { $image_id = $game['hero_image_id']; }
	$meta = $image_id ? wp_get_attachment_metadata( $image_id ) : array();
	$portrait = ! empty( $meta['width'] ) && ! empty( $meta['height'] ) && $meta['height'] > $meta['width'];
	?>
	<article class="od-game-card">
		<a class="od-game-card__link" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>">
			<div class="od-game-card__media<?php echo $portrait ? ' od-game-card__media--portrait' : ''; ?>">
				<?php if ( $image_id ) : ?>
					<?php echo wp_get_attachment_image( $image_id, 'medium_large', false, array( 'loading' => 'lazy', 'decoding' => 'async', 'alt' => '', 'sizes' => '(max-width: 359px) calc(100vw - 32px), (max-width: 639px) calc((100vw - 46px)/2), (max-width: 1023px) 30vw, 290px' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
				<?php elseif ( ! empty( $game['gallery'][0] ) ) : ?>
					<img src="<?php echo esc_url( $game['gallery'][0] ); ?>" width="640" height="360" loading="lazy" decoding="async" alt="">
				<?php else : ?>
					<span class="od-game-card__placeholder" aria-hidden="true"><?php echo go_verge_games_icon( 'game' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span>
				<?php endif; ?>
			</div>
			<div class="od-game-card__body">
				<?php if ( $status['label'] ) : ?><span class="od-game-card__status"><?php echo esc_html( $status['label'] ); ?></span><?php endif; ?>
				<h3 class="od-game-card__title"><?php echo esc_html( $name ); ?></h3>
				<?php if ( $platforms ) : ?><p class="od-game-card__platforms"><?php echo esc_html( $platforms ); ?></p><?php endif; ?>
				<div class="od-game-card__foot"><span><?php echo $release ? esc_html( $release ) : esc_html__( 'Ver jogo', 'go-verge' ); ?></span><?php echo go_verge_games_icon( 'arrow' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
			</div>
		</a>
	</article>
	<?php
}

/** Chronological story row, shared by initial coverage and AJAX continuation. */
function go_verge_games_story_card( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id ) { return; }
	$types = go_verge_game_coverage_types( $post_id );
	$excerpt = go_verge_support_text( $post_id );
	$has_image = has_post_thumbnail( $post_id );
	?>
	<article class="od-game-story<?php echo $has_image ? '' : ' od-game-story--no-media'; ?>" data-go-coverage-item data-go-coverage-types="<?php echo esc_attr( implode( ' ', $types ) ); ?>" data-go-ad-integrity="atomic">
		<?php if ( $has_image ) : ?><a class="od-game-story__image" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>" tabindex="-1" aria-hidden="true"><?php echo get_the_post_thumbnail( $post_id, 'go_card', array( 'loading' => 'lazy', 'decoding' => 'async', 'alt' => '', 'sizes' => '(max-width: 639px) 112px, 220px' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a><?php endif; ?>
		<div class="od-game-story__body"><h3><a href="<?php echo esc_url( get_permalink( $post_id ) ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h3><?php if ( $excerpt ) : ?><p><?php echo esc_html( wp_trim_words( $excerpt, 25, '…' ) ); ?></p><?php endif; ?><div class="od-game-story__meta"><?php echo go_verge_time_html( $post_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php $byline = go_verge_byline( $post_id, true ); if ( $byline ) : ?><span aria-hidden="true">·</span><?php echo $byline; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php endif; ?></div></div>
	</article>
	<?php
}
