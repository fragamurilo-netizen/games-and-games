<?php
/** Individual game — editorial overview, coverage, media and technical sheet. */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
while ( have_posts() ) : the_post();
	if ( post_password_required() ) {
		?><main id="primary" class="od-games od-games--single"><div class="od-games__container"><div class="od-games__breadcrumbs"><?php go_verge_breadcrumbs(); ?></div><header class="od-library-heading"><h1><?php the_title(); ?></h1></header><?php echo get_the_password_form(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div></main><?php
		continue;
	}
	$game_id = get_the_ID();
	$game = go_verge_game_data( $game_id );
	$game_name = function_exists( 'go_verge_game_name' ) ? go_verge_game_name( $game_id ) : get_the_title( $game_id );
	$summary = $game['summary'] ? $game['summary'] : go_verge_support_text( $game_id );
	$status = go_verge_games_status( $game_id, $game );
	$embed = go_verge_youtube_embed_url( $game['trailer_url'] );
	$hero_id = ! empty( $game['hero_image_id'] ) ? $game['hero_image_id'] : get_post_thumbnail_id( $game_id );
	$hero_url = $hero_id ? wp_get_attachment_image_url( $hero_id, 'large' ) : ( $game['gallery'][0] ?? '' );
	$hero_meta = $hero_id ? wp_get_attachment_metadata( $hero_id ) : array();
	$hero_portrait = ! empty( $hero_meta['width'] ) && ! empty( $hero_meta['height'] ) && $hero_meta['height'] > $hero_meta['width'];
	$hero_caption = $hero_id ? (string) wp_get_attachment_caption( $hero_id ) : '';
	$hero_credit = $hero_id && function_exists( 'go_verge_image_credit' ) ? go_verge_image_credit( $hero_id ) : array();
	if ( ! empty( $hero_credit['text'] ) && false === stripos( $hero_caption, $hero_credit['text'] ) ) {
		$hero_caption = trim( $hero_caption . ( $hero_caption ? ' — ' : '' ) . $hero_credit['text'] );
	}
	$gallery_items = array_values( array_unique( array_filter( array_map( 'esc_url_raw', (array) $game['gallery'] ) ) ) );
	$game['store_links'] = array_values( array_filter( (array) $game['store_links'], static function( $store ) {
		return is_array( $store ) && ! empty( $store['platform'] ) && ! empty( $store['url'] ) && esc_url( $store['url'] );
	} ) );
	$game['official_site'] = esc_url_raw( $game['official_site'] );
	$game['platforms'] = go_verge_games_platform_text( $game_id, $game );
	$game['platforms'] = function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( $game['platforms'] ) : $game['platforms'];
	$game['genres']    = function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( $game['genres'] ) : $game['genres'];
	$game['modes']     = function_exists( 'go_verge_editorial_display_list' ) ? go_verge_editorial_display_list( $game['modes'] ) : $game['modes'];
	if ( empty( $game['genres'] ) && ! empty( $game['primary_genre'] ) ) {
		$game['genres'] = $game['primary_genre'];
	}

	$content_type_labels = array(
		'remake'    => 'Remake',
		'remaster'  => 'Remasterização',
		'expansion' => 'Expansão',
		'dlc'       => 'DLC',
	);
	$parent_game_name    = ! empty( $game['parent_game'] ) && 'games' === get_post_type( $game['parent_game'] ) ? go_verge_game_name( $game['parent_game'] ) : '';
	$feature_labels      = array_filter(
		array(
			$game['coop'] ? 'Cooperativo' : '',
			$game['cross_play'] ? 'Cross-play' : '',
			$game['cross_save'] ? 'Cross-save' : '',
			$game['shared_progression'] ? 'Progressão compartilhada' : '',
			$game['ptbr_subtitles'] ? 'Legendas em português' : '',
			$game['ptbr_dubbing'] ? 'Dublagem em português' : '',
		)
	);

	$primary_specs = array_filter(
		array(
			'Plataformas' => $game['platforms'],
			'Lançamento'  => go_verge_games_release_label( $game['release_date'] ),
			'Gênero'      => $game['genres'],
		)
	);
	$detail_specs  = array_filter(
		array(
			'Desenvolvedora'   => $game['developer'],
			'Publicadora'      => $game['publisher'],
			'Distribuidora'    => $game['distributor'],
			'Direção'          => $game['director'],
			'Motor gráfico'    => $game['engine'],
			'País de origem'   => $game['country'],
			'Modos'            => $game['modes'],
			'Perspectiva'      => $game['perspective'],
			'Recursos online'  => $game['online'],
			'Jogadores'        => $game['players'],
			'Idiomas'          => $game['languages'],
			'Classificação'    => $game['age_rating'],
			'Recursos'         => implode( ', ', $feature_labels ),
			'Acesso antecipado' => go_verge_games_release_label( $game['early_access'] ),
			'Preço'            => $game['price'],
			'Franquia'         => $game['franchise'],
			'Edição'           => $game['edition'],
			'Tipo'             => $content_type_labels[ $game['content_type'] ] ?? '',
			'Jogo principal'   => $parent_game_name,
			'Assinaturas'      => $game['subscriptions'],
		)
	);

	$all_ids = function_exists( 'go_verge_game_hub_related_ids' )
		? go_verge_game_hub_related_ids( $game_id, 200 )
		: go_verge_product_related_post_ids( $game_id, 'games', 200 );

	$coverage_counts = array(
		'all'     => count( $all_ids ),
		'news'    => 0,
		'guides'  => 0,
		'reviews' => 0,
		'videos'  => 0,
	);

	/* Counts are calculated once for the filter chips, but only the first ten
	 * rows are rendered into the initial HTML. The rest arrive as the reader
	 * scrolls, avoiding a 30/50/100-card DOM on popular game hubs. */
	foreach ( $all_ids as $story_id ) {
		$types = function_exists( 'go_verge_game_coverage_types' )
			? go_verge_game_coverage_types( $story_id )
			: array( 'news' );
		foreach ( $types as $type ) {
			if ( isset( $coverage_counts[ $type ] ) ) {
				$coverage_counts[ $type ]++;
			}
		}
	}

	$coverage_query = null;
	if ( $all_ids ) {
		$coverage_query = new WP_Query(
			array(
				'post_type'              => 'post',
				'post_status'            => 'publish',
				'post__in'               => array_map( 'absint', $all_ids ),
				'orderby'                => 'post__in',
				'posts_per_page'         => 10,
				'paged'                  => max( 1, absint( go_verge_games_get_input( 'cobertura' ) ) ),
				'ignore_sticky_posts'    => true,
				'no_found_rows'          => false,
				'update_post_meta_cache' => true,
				'update_post_term_cache' => true,
			)
		);
	}

	$promos = go_verge_product_game_promotions( $game_id, 6 );
	$has_about = '' !== trim( (string) get_the_content() );
	$has_media = (bool) $embed || ! empty( $gallery_items );
	// Optional commerce renderers may exist while returning no data. Do not
	// create an empty Offers section merely because a plugin is active.
	ob_start();
	if ( function_exists( 'go_verge_render_price_history' ) ) { go_verge_render_price_history( $game_id ); }
	if ( function_exists( 'go_verge_render_price_alert' ) ) { go_verge_render_price_alert( $game_id ); }
	$price_tools = trim( ob_get_clean() );
	$has_offers = $promos->have_posts() || '' !== $price_tools;
	$has_facts = ! empty( $primary_specs ) || ! empty( $detail_specs );
	$has_stores = ! empty( $game['store_links'] ) || ! empty( $game['official_site'] );
	$nav_items = array();
	if ( $has_about ) { $nav_items['sobre'] = 'Sobre o jogo'; }
	if ( $all_ids ) { $nav_items['materias'] = 'Cobertura'; }
	if ( $has_facts ) { $nav_items['ficha-tecnica'] = 'Ficha técnica'; }
	if ( $has_media ) { $nav_items['midia'] = 'Vídeos e imagens'; }
	if ( $has_offers ) { $nav_items['ofertas'] = 'Ofertas'; }
	$library_url = go_verge_game_library_url();
	?>
	<main id="primary" class="od-games od-games--single">
		<div class="od-games__container">
			<div class="od-games__breadcrumbs"><?php go_verge_breadcrumbs(); ?></div>
			<header class="od-game-hero<?php echo $hero_url ? '' : ' od-game-hero--no-media'; ?>" aria-labelledby="od-game-title">
				<div class="od-game-hero__copy">
					<?php if ( $status['label'] ) : ?><div class="od-game-hero__meta"><span class="od-game-status" data-status="<?php echo esc_attr( $status['key'] ); ?>"><?php echo esc_html( $status['label'] ); ?></span></div><?php endif; ?>
					<h1 id="od-game-title"><?php echo esc_html( $game_name ); ?></h1>
					<?php if ( $summary ) : ?><p class="od-game-hero__summary"><?php echo esc_html( $summary ); ?></p><?php endif; ?>
					<div class="od-game-hero__actions">
						<?php if ( function_exists( 'go_verge_product_follow_button' ) ) {
							// Same follow controller and canonical identity; only the old CSS
							// class is replaced, keeping every data/ARIA attribute intact.
							ob_start(); go_verge_product_follow_button( $game_id, 'games', __( 'Seguir jogo', 'go-verge' ) );
							echo str_replace( 'class="go-product-action"', 'class="od-games__button od-games__button--primary"', ob_get_clean() ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
						} ?>
						<?php if ( $embed ) : ?><a class="od-games__button" href="#od-game-trailer"><?php echo go_verge_games_icon( 'play' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><?php esc_html_e( 'Ver trailer', 'go-verge' ); ?></a><?php elseif ( $all_ids ) : ?><a class="od-games__button" href="#materias"><?php esc_html_e( 'Ver cobertura', 'go-verge' ); ?><?php echo go_verge_games_icon( 'arrow' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a><?php endif; ?>
					</div>
				</div>
				<?php if ( $hero_url ) : ?>
					<figure class="od-game-hero__figure">
						<div class="od-game-hero__image<?php echo $hero_portrait ? ' od-game-hero__image--portrait' : ''; ?>">
							<?php if ( $hero_id ) { echo wp_get_attachment_image( $hero_id, 'large', false, array( 'loading' => 'eager', 'fetchpriority' => 'high', 'decoding' => 'async', 'alt' => $game_name, 'sizes' => '(max-width: 767px) calc(100vw - 32px), (max-width: 1303px) 49vw, 640px' ) ); } else { ?><img src="<?php echo esc_url( $hero_url ); ?>" alt="<?php echo esc_attr( $game_name ); ?>" width="1280" height="720" loading="eager" fetchpriority="high" decoding="async"><?php } // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
						</div>
						<?php if ( $hero_caption ) : ?><figcaption><?php echo wp_kses_post( $hero_caption ); ?></figcaption><?php endif; ?>
					</figure>
				<?php endif; ?>
			</header>

			<?php $quick_facts = array_filter( array( 'Lançamento' => go_verge_games_release_label( $game['release_date'] ), 'Plataformas' => $game['platforms'], 'Gênero' => $game['genres'], 'Desenvolvedora' => $game['developer'] ) ); ?>
			<?php if ( $quick_facts ) : ?><dl class="od-game-quickfacts" data-go-ad-integrity="atomic"><?php foreach ( $quick_facts as $label => $value ) : ?><div><dt><?php echo esc_html( $label ); ?></dt><dd><?php echo esc_html( $value ); ?></dd></div><?php endforeach; ?></dl><?php endif; ?>

			<?php if ( $nav_items ) : ?><nav class="od-game-nav" aria-label="<?php esc_attr_e( 'Nesta página do jogo', 'go-verge' ); ?>" data-od-game-nav><?php foreach ( $nav_items as $id => $label ) : ?><a href="#<?php echo esc_attr( $id ); ?>"><?php echo esc_html( $label ); ?></a><?php endforeach; ?></nav><?php endif; ?>

			<div class="od-game-layout<?php echo ( $has_facts || $has_stores || ! empty( $game['logo_id'] ) ) ? '' : ' od-game-layout--full'; ?>">
				<div class="od-game-layout__main">
					<?php if ( $has_about ) : ?>
						<section class="od-game-section" id="sobre" aria-labelledby="od-game-about-title"><header class="od-game-section__head"><h2 id="od-game-about-title"><?php esc_html_e( 'Sobre o jogo', 'go-verge' ); ?></h2></header><div class="entry-content od-game-about"><?php the_content(); ?></div></section>
					<?php endif; ?>
					<?php if ( ( $has_about || $all_ids || $has_media || $has_offers ) && function_exists( 'go_verge_render_adsense_unit' ) ) : ?>
						<?php go_verge_render_adsense_unit( 'game-hub-mid', array( 'tag' => 'aside', 'class' => 'od-game-revenue-slot', 'data' => array( 'ad-surface' => 'game-hub-mid' ) ) ); ?>
					<?php endif; ?>
					<?php if ( $coverage_query instanceof WP_Query && $coverage_query->have_posts() ) { include GO_VERGE_DIR . '/template-parts/games/coverage.php'; } ?>
					<?php if ( $has_media ) { include GO_VERGE_DIR . '/template-parts/games/media.php'; } ?>
					<?php if ( $has_offers ) { include GO_VERGE_DIR . '/template-parts/games/offers.php'; } ?>
					<?php if ( ! $has_about && ! $all_ids && ! $has_media && ! $has_offers ) : ?><section class="od-game-section"><header class="od-game-section__head"><h2><?php esc_html_e( 'Acompanhe este jogo', 'go-verge' ); ?></h2></header><p class="od-games__muted"><?php esc_html_e( 'As novas publicações do Overdrive sobre este jogo aparecerão nesta página.', 'go-verge' ); ?></p><a class="od-games__text-link" href="<?php echo esc_url( $library_url ); ?>"><?php esc_html_e( 'Explorar outros jogos', 'go-verge' ); ?><?php echo go_verge_games_icon( 'arrow' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a></section><?php endif; ?>
				</div>
				<?php if ( $has_facts || $has_stores || ! empty( $game['logo_id'] ) ) : ?>
					<aside class="od-game-sidebar" aria-label="<?php esc_attr_e( 'Informações do jogo', 'go-verge' ); ?>">
						<?php include GO_VERGE_DIR . '/template-parts/games/facts.php'; ?>
						<?php if ( function_exists( 'go_verge_render_adsense_unit' ) ) { go_verge_render_adsense_unit( 'sidebar-desktop', array( 'tag' => 'aside', 'class' => 'go-game-sidebar-revenue go-article-sidebar__ad--sticky', 'data' => array( 'ad-surface' => 'game-sidebar' ) ) ); } ?>
					</aside>
				<?php endif; ?>
			</div>
			<?php
			$more_games = new WP_Query( array( 'post_type' => 'games', 'post_status' => 'publish', 'has_password' => false, 'post__not_in' => array( $game_id ), 'posts_per_page' => 4, 'orderby' => array( 'date' => 'DESC', 'ID' => 'DESC' ), 'no_found_rows' => true, 'ignore_sticky_posts' => true ) );
			if ( $more_games->have_posts() ) : ?>
				<section class="od-game-explore" aria-labelledby="od-game-explore-title"><header class="od-game-section__head"><div><h2 id="od-game-explore-title"><?php esc_html_e( 'Mais jogos na biblioteca', 'go-verge' ); ?></h2></div><a class="od-games__text-link" href="<?php echo esc_url( $library_url ); ?>"><?php esc_html_e( 'Ver biblioteca', 'go-verge' ); ?><?php echo go_verge_games_icon( 'arrow' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></a></header><div class="od-game-catalog"><?php foreach ( $more_games->posts as $more_game ) { go_verge_game_library_card( $more_game->ID ); } ?></div></section>
			<?php endif; ?>
		</div>
	</main>
<?php endwhile; get_footer(); ?>
