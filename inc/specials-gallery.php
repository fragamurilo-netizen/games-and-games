<?php
/** A published collection of HTML specials, independent of the legacy format archive. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_verge_specials_gallery_is_html( $post_id ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || 'publish' !== $post->post_status || $post->post_password ) { return false; }
	$package = go_verge_specials_get_for_post( $post->ID );
	if ( ! $package ) { return false; }
	if ( 'file' === $package['content_mode'] ) { return true; }
	return 'custom_meta' === $package['content_mode'] && '' !== trim( (string) get_post_meta( $post->ID, '_go_special_custom_html', true ) );
}

/** Two selective ID queries; no scan of the general article archive. */
function go_verge_specials_gallery_ids() {
	$cached = get_transient( 'go_html_specials_gallery_v1' );
	if ( is_array( $cached ) ) { return $cached; }
	$packages = array();
	$slugs = array();
	foreach ( go_verge_specials_registry() as $id => $package ) {
		if ( ! in_array( $package['content_mode'], array( 'file', 'custom_meta' ), true ) ) { continue; }
		$packages[] = $id;
		$slugs = array_merge( $slugs, $package['auto_slugs'] );
	}
	$args = array( 'post_type' => 'post', 'post_status' => 'publish', 'has_password' => false, 'posts_per_page' => -1, 'fields' => 'ids', 'no_found_rows' => true, 'ignore_sticky_posts' => true );
	$ids = array();
	if ( $packages ) {
		$ids = get_posts( array_merge( $args, array( 'meta_query' => array(
			array( 'key' => '_go_special_enabled', 'value' => '1' ),
			array( 'key' => '_go_special_id', 'value' => $packages, 'compare' => 'IN' ),
		) ) ) );
	}
	if ( $slugs ) { $ids = array_merge( $ids, get_posts( array_merge( $args, array( 'post_name__in' => array_unique( $slugs ) ) ) ) ); }
	$ids = array_values( array_unique( array_map( 'absint', $ids ) ) );
	if ( $ids ) { _prime_post_caches( $ids, true, true ); }
	$ids = array_values( array_filter( $ids, 'go_verge_specials_gallery_is_html' ) );
	set_transient( 'go_html_specials_gallery_v1', $ids, 5 * MINUTE_IN_SECONDS );
	return $ids;
}

function go_verge_specials_gallery_clear_cache( $post_id = 0 ) {
	delete_transient( 'go_html_specials_gallery_v1' );
}
add_action( 'save_post_post', 'go_verge_specials_gallery_clear_cache', 1000 );
add_action( 'deleted_post', 'go_verge_specials_gallery_clear_cache' );
add_action( 'after_switch_theme', 'go_verge_specials_gallery_clear_cache' );
function go_verge_specials_gallery_meta_changed( $meta_id, $post_id, $key ) {
	if ( 0 === strpos( $key, '_go_special_' ) ) { go_verge_specials_gallery_clear_cache(); }
}
add_action( 'added_post_meta', 'go_verge_specials_gallery_meta_changed', 10, 3 );
add_action( 'updated_post_meta', 'go_verge_specials_gallery_meta_changed', 10, 3 );
add_action( 'deleted_post_meta', 'go_verge_specials_gallery_meta_changed', 10, 3 );

function go_verge_specials_gallery_url() {
	$page = get_page_by_path( 'especiais', OBJECT, 'page' );
	return $page instanceof WP_Post && 'publish' === $page->post_status ? get_permalink( $page ) : '';
}

/** Add only the missing landing page. Never replace, republish or redirect an existing resource. */
function go_verge_specials_gallery_provision() {
	if ( ! current_user_can( 'manage_options' ) || get_option( 'go_html_specials_gallery_provisioned' ) ) { return; }
	$existing = get_page_by_path( 'especiais', OBJECT, array( 'page', 'post', 'attachment' ) );
	if ( $existing ) { update_option( 'go_html_specials_gallery_provisioned', 'existing', false ); return; }
	if ( 'especiais' !== wp_unique_post_slug( 'especiais', 0, 'publish', 'page', 0 ) ) { return; }
	$category = get_category_by_slug( 'especiais' );
	if ( $category ) {
		$url = get_term_link( $category );
		if ( ! is_wp_error( $url ) && untrailingslashit( $url ) === untrailingslashit( home_url( '/especiais/' ) ) ) { return; }
	}
	$id = wp_insert_post( array( 'post_type' => 'page', 'post_status' => 'publish', 'post_name' => 'especiais', 'post_title' => 'Especiais', 'post_content' => '', 'comment_status' => 'closed', 'ping_status' => 'closed' ), true );
	if ( ! is_wp_error( $id ) && $id ) { update_option( 'go_html_specials_gallery_provisioned', (int) $id, false ); }
}
add_action( 'admin_init', 'go_verge_specials_gallery_provision', 1100 );
add_action( 'after_switch_theme', 'go_verge_specials_gallery_provision', 1100 );

/** Apply only to the existing Specials page/template, never /games/especiais/. */
function go_verge_specials_gallery_is_current() {
	return is_page( 'especiais' ) || is_page_template( 'page-especiais.php' );
}
function go_verge_specials_gallery_page() {
	$value = $_GET['pagina'] ?? '1'; // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- public read-only pagination.
	$explicit = is_scalar( $value ) && ctype_digit( (string) $value ) ? (int) $value : 1;
	// Core also recognizes /page/N/ and ?paged=N on a Page. Never serve the
	// first collection under a later-page URL; the template validates its range.
	return max( 1, min( 10000, max( $explicit, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) ) ) );
}
function go_verge_specials_gallery_page_url( $page = 1 ) {
	$url = get_permalink( get_queried_object_id() );
	return $page > 1 ? add_query_arg( 'pagina', (int) $page, $url ) : $url;
}
function go_verge_specials_gallery_canonical( $url = '' ) {
	return go_verge_specials_gallery_is_current() ? go_verge_specials_gallery_page_url( go_verge_specials_gallery_page() ) : $url;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_specials_gallery_canonical', 15000 );
add_filter( 'wpseo_canonical', 'go_verge_specials_gallery_canonical', 15000 );
add_filter( 'get_canonical_url', 'go_verge_specials_gallery_canonical', 15000 );
add_filter( 'go_verge_header_context_identity', static function ( $identity ) {
	return go_verge_specials_gallery_is_current() ? array( 'label' => __( 'Especiais', 'go-verge' ), 'url' => get_permalink( get_queried_object_id() ) ) : $identity;
}, 15000 );
add_filter( 'template_include', static function ( $template ) {
	return go_verge_specials_gallery_is_current() ? locate_template( 'page-especiais.php' ) ?: $template : $template;
}, 100001 );
add_action( 'wp_enqueue_scripts', static function () {
	if ( ! go_verge_specials_gallery_is_current() ) { return; }
	$rel = '/assets/css/specials-gallery.css';
	wp_enqueue_style( 'go-verge-specials-gallery', GO_VERGE_URI . $rel, array( 'go-verge-publisher-navigation' ), go_verge_asset_version( $rel ) );
}, 51000 );

/** Markup shared by the lead and collection cards. */
function go_verge_specials_gallery_card( $post_id, $featured = false ) {
	if ( ! go_verge_specials_gallery_is_html( $post_id ) ) { return; }
	$url = get_permalink( $post_id );
	$desk = function_exists( 'go_verge_post_editorial_desk' ) ? go_verge_post_editorial_desk( $post_id ) : '';
	$pillars = function_exists( 'go_verge_editorial_pillars' ) ? go_verge_editorial_pillars() : array();
	$deck = function_exists( 'go_verge_subtitle' ) ? go_verge_subtitle( $post_id ) : '';
	if ( ! $deck ) { $deck = get_the_excerpt( $post_id ); }
	$author_id = (int) get_post_field( 'post_author', $post_id );
	?>
	<article class="od-special-card<?php echo $featured ? ' od-special-card--lead' : ''; ?>">
		<?php if ( has_post_thumbnail( $post_id ) ) : ?>
			<a class="od-special-card__image" href="<?php echo esc_url( $url ); ?>" tabindex="-1" aria-hidden="true">
				<?php echo get_the_post_thumbnail( $post_id, $featured ? 'go_hero' : 'large', array( 'alt' => '', 'loading' => $featured ? 'eager' : 'lazy', 'fetchpriority' => $featured ? 'high' : 'low', 'decoding' => 'async', 'sizes' => $featured ? '(max-width: 800px) calc(100vw - 40px), 760px' : '(max-width: 650px) calc(100vw - 40px), (max-width: 1000px) 45vw, 400px' ) ); ?>
			</a>
		<?php endif; ?>
		<div class="od-special-card__body">
			<div class="od-special-card__meta"><?php if ( $featured ) : ?><span><?php esc_html_e( 'Em destaque', 'go-verge' ); ?></span><?php endif; ?><?php if ( isset( $pillars[ $desk ] ) ) : ?><span><?php echo esc_html( $pillars[ $desk ]['label'] ); ?></span><?php endif; ?></div>
			<h2><a href="<?php echo esc_url( $url ); ?>"><?php echo esc_html( get_the_title( $post_id ) ); ?></a></h2>
			<?php if ( $deck ) : ?><p><?php echo esc_html( wp_trim_words( wp_strip_all_tags( $deck ), $featured ? 36 : 24, '…' ) ); ?></p><?php endif; ?>
			<div class="od-special-card__byline"><a href="<?php echo esc_url( get_author_posts_url( $author_id ) ); ?>" rel="author"><?php echo esc_html( get_the_author_meta( 'display_name', $author_id ) ); ?></a><time datetime="<?php echo esc_attr( get_post_time( DATE_W3C, true, $post_id ) ); ?>"><?php echo esc_html( get_the_date( 'd.m.Y', $post_id ) ); ?></time></div>
			<?php if ( $featured ) : ?><a class="od-special-card__read" href="<?php echo esc_url( $url ); ?>"><?php esc_html_e( 'Explorar especial', 'go-verge' ); ?><?php echo go_verge_icon( 'seta-direita' ); ?></a><?php endif; ?>
		</div>
	</article>
	<?php
}
