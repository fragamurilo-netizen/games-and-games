<?php
/**
 * Platforms index.
 *
 * The public hub exposes the five main editorial ecosystems and follows each
 * one with recent stories matched by real platform, console and service terms.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$go_verge_platforms = array(
	array(
		'label'       => 'Xbox',
		'slug'        => 'xbox',
		'category'    => array( 'xbox' ),
		'entity'      => array( 'xbox' ),
		'aliases'     => array( 'xbox', 'xbox-one', 'xbox-series', 'xbox-series-x-s', 'series-x', 'series-s', 'game-pass', 'xbox-game-pass' ),
		'description' => __( 'Xbox Series X|S, Xbox One, Game Pass, jogos e serviços da Microsoft.', 'go-verge' ),
	),
	array(
		'label'       => 'Nintendo',
		'slug'        => 'nintendo',
		'category'    => array( 'nintendo' ),
		'entity'      => array( 'nintendo' ),
		'aliases'     => array( 'nintendo', 'switch', 'nintendo-switch', 'switch-2', 'nintendo-switch-2', 'nintendo-eshop', 'nintendo-switch-online' ),
		'description' => __( 'Nintendo Switch 2, Nintendo Switch, eShop, jogos e serviços da Nintendo.', 'go-verge' ),
	),
	array(
		'label'       => 'PC',
		'slug'        => 'pc',
		'category'    => array( 'pc', 'pc-gamer' ),
		'entity'      => array( 'pc', 'pc-gamer' ),
		'aliases'     => array( 'pc', 'pc-gamer', 'windows', 'steam', 'epic-games', 'epic-games-store', 'gog', 'pc-game-pass' ),
		'description' => __( 'Steam, Epic Games Store, lançamentos, hardware, análises e guias para PC.', 'go-verge' ),
	),
	array(
		'label'       => 'PlayStation',
		'slug'        => 'playstation',
		'category'    => array( 'playstation' ),
		'entity'      => array( 'playstation' ),
		'aliases'     => array( 'playstation', 'ps5', 'ps4', 'playstation-5', 'playstation-4', 'ps-vr2', 'playstation-vr2', 'playstation-plus', 'ps-plus' ),
		'description' => __( 'PlayStation 5, PlayStation 4, PS VR2, PlayStation Plus, jogos e lançamentos da Sony.', 'go-verge' ),
	),
	array(
		'label'       => 'Mobile',
		'slug'        => 'mobile',
		'category'    => array( 'mobile', 'mobile-gaming', 'celular' ),
		'entity'      => array( 'mobile', 'mobile-gaming' ),
		'aliases'     => array( 'mobile', 'mobile-gaming', 'celular', 'android', 'ios', 'iphone', 'ipad', 'apple-arcade', 'google-play' ),
		'description' => __( 'Jogos para Android, iPhone e iPad, além de Apple Arcade e Google Play.', 'go-verge' ),
	),
);

$go_verge_resolve_platform = static function ( $platform ) {
	$resolved = array(
		'label'       => $platform['label'],
		'slug'        => $platform['slug'],
		'description' => $platform['description'],
		'url'         => '',
		'image_id'    => 0,
		'initial'     => function_exists( 'mb_substr' ) ? mb_substr( $platform['label'], 0, 1 ) : substr( $platform['label'], 0, 1 ),
		'aliases'     => $platform['aliases'],
	);

	$term = null;
	foreach ( (array) $platform['category'] as $candidate ) {
		$maybe_term = get_term_by( 'slug', $candidate, 'category' );
		if ( $maybe_term instanceof WP_Term ) {
			$term = $maybe_term;
			break;
		}
	}

	$entity = null;
	if ( post_type_exists( 'go_entity' ) ) {
		foreach ( (array) $platform['entity'] as $candidate ) {
			$maybe_entity = get_page_by_path( $candidate, OBJECT, 'go_entity' );
			if ( $maybe_entity instanceof WP_Post && 'publish' === $maybe_entity->post_status ) {
				$entity = $maybe_entity;
				break;
			}
		}
	}

	if ( $term instanceof WP_Term ) {
		$term_link = get_term_link( $term );
		if ( ! is_wp_error( $term_link ) ) {
			$resolved['url'] = $term_link;
		}
	}
	if ( '' === $resolved['url'] && $entity instanceof WP_Post ) {
		$resolved['url'] = get_permalink( $entity );
	}
	if ( $entity instanceof WP_Post && has_post_thumbnail( $entity ) ) {
		$resolved['image_id'] = (int) get_post_thumbnail_id( $entity );
	}

	if ( ! $resolved['image_id'] ) {
		$tax_query = array( 'relation' => 'OR' );
		foreach ( array( 'category', 'post_tag' ) as $taxonomy ) {
			$ids = array();
			foreach ( (array) $platform['aliases'] as $alias ) {
				$alias_term = get_term_by( 'slug', sanitize_title( $alias ), $taxonomy );
				if ( $alias_term instanceof WP_Term ) {
					$ids[] = (int) $alias_term->term_id;
				}
			}
			if ( $ids ) {
				$tax_query[] = array( 'taxonomy' => $taxonomy, 'field' => 'term_id', 'terms' => array_values( array_unique( $ids ) ) );
			}
		}
		if ( count( $tax_query ) > 1 ) {
			$latest = new WP_Query(
				array(
					'post_type'           => 'post',
					'post_status'         => 'publish',
					'posts_per_page'      => 1,
					'tax_query'           => $tax_query,
					'ignore_sticky_posts' => true,
					'no_found_rows'       => true,
					'fields'              => 'ids',
				)
			);
			if ( ! empty( $latest->posts[0] ) ) {
				$resolved['image_id'] = (int) get_post_thumbnail_id( (int) $latest->posts[0] );
			}
		}
	}

	if ( '' === $resolved['url'] ) {
		$resolved['url'] = home_url( '/?s=' . rawurlencode( $platform['label'] ) );
	}

	return $resolved;
};

$go_verge_platform_posts = static function ( $platform, $limit = 4 ) {
	$tax_query = array( 'relation' => 'OR' );
	foreach ( array( 'category', 'post_tag' ) as $taxonomy ) {
		$term_ids = array();
		foreach ( (array) $platform['aliases'] as $alias ) {
			$term = get_term_by( 'slug', sanitize_title( $alias ), $taxonomy );
			if ( $term instanceof WP_Term ) {
				$term_ids[] = (int) $term->term_id;
			}
		}
		if ( $term_ids ) {
			$tax_query[] = array(
				'taxonomy' => $taxonomy,
				'field'    => 'term_id',
				'terms'    => array_values( array_unique( $term_ids ) ),
			);
		}
	}
	if ( count( $tax_query ) < 2 ) {
		return array();
	}
	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => max( 1, (int) $limit ),
			'tax_query'           => $tax_query,
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'orderby'             => 'date',
			'order'               => 'DESC',
			'fields'              => 'ids',
		)
	);
	return array_map( 'absint', (array) $query->posts );
};

$go_verge_platform_cards = array_map( $go_verge_resolve_platform, $go_verge_platforms );
?>

<main id="primary" class="go-main go-platforms-page">
	<section class="go-platforms-hero">
		<div class="go-container">
			<?php go_verge_breadcrumbs(); ?>
			<div class="go-platforms-hero__copy">
				<h1 class="go-platforms-hero__title"><?php esc_html_e( 'Plataformas', 'go-verge' ); ?></h1>
			</div>
			<nav class="go-platforms-chips" aria-label="<?php esc_attr_e( 'Plataformas', 'go-verge' ); ?>">
				<?php foreach ( $go_verge_platform_cards as $go_verge_platform ) : ?>
					<a href="#go-platform-<?php echo esc_attr( $go_verge_platform['slug'] ); ?>"><?php echo esc_html( $go_verge_platform['label'] ); ?></a>
				<?php endforeach; ?>
			</nav>
		</div>
	</section>

	<div class="go-container go-platforms-content">
		<section class="go-platforms-group" aria-labelledby="go-platforms-main-title">
			<div class="go-platforms-group__head"><h2 id="go-platforms-main-title"><?php esc_html_e( 'Xbox, Nintendo, PC, PlayStation e Mobile', 'go-verge' ); ?></h2></div>
			<div class="go-platforms-grid go-platforms-grid--primary">
				<?php foreach ( $go_verge_platform_cards as $go_verge_platform ) : ?>
					<article class="go-platform-card go-platform-card--<?php echo esc_attr( sanitize_html_class( $go_verge_platform['slug'] ) ); ?>">
						<a class="go-platform-card__media" href="<?php echo esc_url( $go_verge_platform['url'] ); ?>" tabindex="-1" aria-hidden="true">
							<?php if ( $go_verge_platform['image_id'] ) : ?>
								<?php echo wp_get_attachment_image( $go_verge_platform['image_id'], 'go_card', false, array( 'loading' => 'lazy', 'alt' => '' ) ); ?>
							<?php else : ?>
								<span><?php echo esc_html( $go_verge_platform['initial'] ); ?></span>
							<?php endif; ?>
						</a>
						<div class="go-platform-card__body">
							<h3><a href="<?php echo esc_url( $go_verge_platform['url'] ); ?>"><?php echo esc_html( $go_verge_platform['label'] ); ?></a></h3>
							<p><?php echo esc_html( $go_verge_platform['description'] ); ?></p>
							<a class="go-platform-card__link" href="<?php echo esc_url( $go_verge_platform['url'] ); ?>"><?php echo esc_html( sprintf( __( 'Ver %s', 'go-verge' ), $go_verge_platform['label'] ) ); ?><span aria-hidden="true">→</span></a>
						</div>
					</article>
				<?php endforeach; ?>
			</div>
		</section>

		<?php if ( function_exists( 'go_verge_ads_render_listing_unit' ) ) : ?>
			<?php go_verge_ads_render_listing_unit( 'platforms-directory', 1 ); ?>
		<?php endif; ?>

		<div class="go-platforms-editorial-sections">
			<?php $go_verge_platform_section_index = 0; ?>
			<?php foreach ( $go_verge_platform_cards as $go_verge_platform ) : ?>
				<?php $go_verge_platform_section_index++; ?>
				<?php $go_verge_posts = $go_verge_platform_posts( $go_verge_platform, 4 ); ?>
				<section class="go-platform-editorial" id="go-platform-<?php echo esc_attr( $go_verge_platform['slug'] ); ?>" aria-labelledby="go-platform-title-<?php echo esc_attr( $go_verge_platform['slug'] ); ?>">
					<div class="go-platform-editorial__head">
						<h2 id="go-platform-title-<?php echo esc_attr( $go_verge_platform['slug'] ); ?>"><?php echo esc_html( $go_verge_platform['label'] ); ?></h2>
						<a href="<?php echo esc_url( $go_verge_platform['url'] ); ?>"><?php echo esc_html( sprintf( __( 'Ver %s', 'go-verge' ), $go_verge_platform['label'] ) ); ?><span aria-hidden="true">→</span></a>
					</div>
					<?php if ( $go_verge_posts ) : ?>
						<div class="go-platform-editorial__grid">
							<?php foreach ( $go_verge_posts as $go_verge_post_id ) : ?>
								<article class="go-platform-story">
									<a class="go-platform-story__media" href="<?php echo esc_url( get_permalink( $go_verge_post_id ) ); ?>" tabindex="-1" aria-hidden="true">
										<?php if ( has_post_thumbnail( $go_verge_post_id ) ) : ?><?php echo get_the_post_thumbnail( $go_verge_post_id, 'go_card', array( 'loading' => 'lazy', 'alt' => '' ) ); ?><?php endif; ?>
									</a>
									<div class="go-platform-story__body">
										<h3><a href="<?php echo esc_url( get_permalink( $go_verge_post_id ) ); ?>"><?php echo esc_html( get_the_title( $go_verge_post_id ) ); ?></a></h3>
										<time datetime="<?php echo esc_attr( get_the_date( DATE_W3C, $go_verge_post_id ) ); ?>"><?php echo esc_html( get_the_date( '', $go_verge_post_id ) ); ?></time>
									</div>
								</article>
							<?php endforeach; ?>
						</div>
					<?php endif; ?>
				</section>
				<?php if ( in_array( $go_verge_platform_section_index, array( 2, 4, 6 ), true ) && function_exists( 'go_verge_ads_render_listing_unit' ) ) : ?>
					<?php go_verge_ads_render_listing_unit( 'platforms-editorial', $go_verge_platform_section_index ); ?>
				<?php endif; ?>
			<?php endforeach; ?>
		</div>
	</div>
</main>

<?php get_footer();
