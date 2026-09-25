<?php
/**
 * Post-content recirculation.
 *
 * Measured on 28/07/2026: the end of an article went from the tag list straight
 * to the comments, offering the reader nothing to read next. This closes that
 * gap and nothing else — the sidebar keeps the composition it already had.
 *
 * It reuses go_verge_smart_related_posts(), which existed in the theme but was
 * never called on an ordinary article, and it links only to the site's own
 * stories: pages per session is what multiplies advertising revenue, so no paid
 * recommendation widget is used here.
 *
 * Disable with:
 *   add_filter( 'go_verge_recirculation_enabled', '__return_false' );
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

require_once __DIR__ . '/recommendations-single.php';

/**
 * Master switch.
 *
 * @return bool
 */
function go_verge_recirculation_enabled() {
	return (bool) apply_filters( 'go_verge_recirculation_enabled', true );
}

/**
 * Insert one recirculation block in the middle of the article.
 *
 * Measured on 28/07/2026: the end-of-article block sits 12.5 screens down on a
 * phone, so on a 20-screen page almost nobody reaches it. This one lands near
 * 60% of the text — deep enough that the reader is committed, early enough that
 * most of them are still there.
 *
 * It runs after the advertising composer so it can see the units already in
 * place and keep away from them: the same protected-UI guard the density rules
 * use treats `.go-inline-related` and `data-go-ad-placement` as things a block
 * must not land against.
 *
 * @param string $content Rendered content.
 * @return string
 */
function go_verge_insert_mid_content_recirculation( $content ) {
	if ( ! go_verge_recirculation_enabled() || ! is_string( $content ) ) {
		return $content;
	}
	if ( ! is_singular( 'post' ) || ! in_the_loop() || ! is_main_query() ) {
		return $content;
	}
	if ( false !== strpos( $content, 'data-go-related-block="read-more"' ) ) {
		return $content; // The editor already placed one by hand.
	}
	if ( ! function_exists( 'go_verge_content_safe_paragraph_breaks' ) || ! function_exists( 'go_verge_smart_related_posts' ) ) {
		return $content;
	}

	$post_id = absint( get_queried_object_id() );
	$words   = function_exists( 'go_verge_ads_word_count' ) ? go_verge_ads_word_count( $content ) : 0;

	// A short news item has no middle worth interrupting.
	if ( ! $post_id || $words < 600 ) {
		return $content;
	}

	$length = max( 1, strlen( $content ) );
	$target = (int) round( $length * 0.6 );

	$best     = null;
	$distance = PHP_INT_MAX;
	foreach ( go_verge_content_safe_paragraph_breaks( $content, 95 ) as $break ) {
		$offset = (int) ( $break['position'] ?? 0 );
		$share  = $offset / $length;
		if ( (int) ( $break['paragraph'] ?? 0 ) < 2 || $share < 0.45 || $share > 0.75 ) {
			continue;
		}
		if ( function_exists( 'go_verge_ads_break_near_protected_ui' ) && go_verge_ads_break_near_protected_ui( $content, $offset ) ) {
			continue;
		}
		if ( abs( $offset - $target ) < $distance ) {
			$distance = abs( $offset - $target );
			$best     = $offset;
		}
	}

	if ( null === $best ) {
		return $content;
	}

	// Never repeat what the sidebar is already showing on the same page.
	$used    = function_exists( 'go_verge_recirculation_shown_ids' ) ? (array) go_verge_recirculation_shown_ids() : ( function_exists( 'go_verge_sidebar_shown_ids' ) ? (array) go_verge_sidebar_shown_ids() : array() );
	$related = go_verge_smart_related_posts( $post_id, 2, $used );

	$ids = array();
	foreach ( (array) $related as $item ) {
		$ids[] = $item instanceof WP_Post ? (int) $item->ID : absint( $item );
	}
	$ids = array_slice( array_values( array_filter( $ids ) ), 0, 2 );
	if ( count( $ids ) < 2 ) {
		return $content;
	}

	$markup = go_verge_read_more_markup( $ids, __( 'Leia mais', 'go-verge' ) );
	if ( '' === $markup ) {
		return $content;
	}

	/*
	 * Remember these so the end-of-article grid does not offer the same two
	 * stories a few screens later.
	 */
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( array_merge( $used, $ids ) );
	} elseif ( function_exists( 'go_verge_sidebar_shown_ids' ) ) {
		go_verge_sidebar_shown_ids( array_merge( $used, $ids ) );
	}

	return substr( $content, 0, $best ) . "\n" . $markup . "\n" . substr( $content, $best );
}
/* After the advertising composer (9999) so it can see and avoid the units. */
add_filter( 'the_content', 'go_verge_insert_mid_content_recirculation', 10000 );

/**
 * "Leia também" — the block between the author card and the comments, where the
 * intent to keep reading is highest.
 *
 * @param int $post_id Current post.
 * @return void
 */
function go_verge_render_post_content_recirculation( $post_id = 0 ) {
	if ( ! go_verge_recirculation_enabled() ) {
		return;
	}

	$post_id = $post_id ? absint( $post_id ) : absint( get_queried_object_id() );
	if ( ! $post_id || ! function_exists( 'go_verge_smart_related_posts' ) ) {
		return;
	}

	// Never repeat what the sidebar already offered on the same page.
	$used    = function_exists( 'go_verge_recirculation_shown_ids' ) ? (array) go_verge_recirculation_shown_ids() : ( function_exists( 'go_verge_sidebar_shown_ids' ) ? (array) go_verge_sidebar_shown_ids() : array() );
	$related = go_verge_smart_related_posts( $post_id, 6, $used );

	$ids = array();
	foreach ( (array) $related as $item ) {
		$ids[] = $item instanceof WP_Post ? (int) $item->ID : absint( $item );
	}
	$ids = array_values( array_filter( $ids ) );
	$label = __( 'Leia também', 'go-verge' );
	if ( count( $ids ) < 2 && function_exists( 'go_verge_single_recommendation_ids' ) ) {
		$ids = go_verge_single_recommendation_ids( $post_id, 4, $used, true );
		$desk = go_verge_post_editorial_desk( $post_id );
		$pillars = go_verge_editorial_pillars();
		if ( isset( $pillars[$desk] ) ) { $label = sprintf( __( 'Continue em %s', 'go-verge' ), $pillars[$desk]['label'] ); }
	}
	// One valid recommendation is useful; an empty framed module is not.
	if ( ! $ids ) {
		return;
	}

	/*
	 * Reserve these recommendations before later modules run. This makes the
	 * request-wide registry authoritative instead of sidebar-only and prevents
	 * "Continue neste assunto" / "Mais de ..." from recycling this same set.
	 */
	if ( function_exists( 'go_verge_recirculation_shown_ids' ) ) {
		go_verge_recirculation_shown_ids( array_merge( $used, $ids ) );
	} elseif ( function_exists( 'go_verge_sidebar_shown_ids' ) ) {
		go_verge_sidebar_shown_ids( array_merge( $used, $ids ) );
	}

	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'has_password'        => false,
			'post__in'            => $ids,
			'orderby'             => 'post__in',
			'posts_per_page'      => count( $ids ),
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
		)
	);
	if ( ! $query->have_posts() ) {
		return;
	}
	?>
	<section class="go-recirc" aria-labelledby="go-recirc-title">
		<h2 class="go-recirc__title" id="go-recirc-title"><?php echo esc_html( $label ); ?></h2>
		<div class="go-recirc__grid">
			<?php while ( $query->have_posts() ) : $query->the_post(); ?>
				<a class="go-recirc__card" href="<?php the_permalink(); ?>" <?php echo function_exists( 'go_verge_reco_data_attributes' ) ? go_verge_reco_data_attributes( get_the_ID(), 'post-content' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>>
					<span class="go-recirc__media">
						<?php
						if ( has_post_thumbnail() ) {
							the_post_thumbnail( 'medium_large', array( 'loading' => 'lazy', 'alt' => '' ) );
						}
						?>
					</span>
					<span class="go-recirc__copy">
						<strong class="go-recirc__headline"><?php the_title(); ?></strong>
						<?php echo function_exists( 'go_verge_time_html' ) ? go_verge_time_html( get_the_ID() ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
					</span>
				</a>
			<?php endwhile; wp_reset_postdata(); ?>
		</div>
	</section>
	<?php
}
