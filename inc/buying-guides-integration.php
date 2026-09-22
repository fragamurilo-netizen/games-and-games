<?php
/**
 * Contextual buying-guide shelves for the two editorial desks.
 *
 * Read-only editorial integration: no recategorisation, permalink changes,
 * migrations or changes to the buying-guide hub / single templates. Only
 * explicitly classified buying guides are candidates. Title signals choose
 * a relevant desk; they never turn a news story or walkthrough into a guide.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Exact legacy aliases, including the canonical category omitted by redirects. */
function go_verge_buying_selection_guide_slugs() {
	return array( 'guias-de-compra', 'guia-de-compra', 'guias-de-compra-2', 'guias-de-compra-3', 'guias-compra' );
}

/**
 * Classify an ALREADY identified buying guide. Never search article copy:
 * incidental mentions of an unrelated product must not drive a recommendation.
 * A clearly named product outranks a stale broad Games category.
 */
function go_verge_buying_selection_classify( $title, $category_slugs = array() ) {
	$title = strtolower( remove_accents( wp_strip_all_tags( (string) $title ) ) );
	$slugs = array_map( 'sanitize_title', (array) $category_slugs );
	$families = array(
		'tablets'   => array( 'Tablets', '\b(?:tablets?|ipads?)\b', 'technology' ),
		'notebooks' => array( 'Notebooks', '\b(?:notebooks?|laptops?|macbooks?|chromebooks?)\b', 'technology' ),
		'celulares' => array( 'Celulares', '\b(?:celular(?:es)?|smartphones?|iphones?|android|motorola|moto[ -]?g|moto[ -]?edge|razr|xiaomi|redmi|poco|realme|honor|nothing[ -]?phone|galaxy(?!\s+(?:book|watch|tab)))\b', 'technology' ),
		'controles' => array( 'Controles', '\b(?:controles?|gamepads?|joysticks?|dualsense|dualshock|volantes?)\b', 'games' ),
		'monitores'=> array( 'Monitores', '\b(?:monitores?|monitor)\b', 'technology' ),
		'tvs'      => array( 'TVs', '\b(?:tvs?|televisor(?:es)?|televisoes|televisao)\b', 'technology' ),
		'audio'    => array( 'Áudio', '\b(?:headsets?|headphones?|fones?|earbuds?|soundbars?|microfones?)\b', 'technology' ),
		'perifericos' => array( 'Periféricos', '\b(?:teclados?|mouses?|perifericos?|cadeiras?)\b', 'technology' ),
		'hardware' => array( 'Hardware', '\b(?:ssds?|hds?|gpus?|placas? de video|placas? mae|processador(?:es)?|memorias?|computador(?:es)?|pcs?|mini pcs?|armazenamento|microsd)\b', 'technology' ),
		'dispositivos' => array( 'Dispositivos', '\b(?:smartwatches?|relogios? inteligentes?|roteadores?|cameras?|projetores?|impressoras?|e-readers?|kindles?)\b', 'technology' ),
		'software' => array( 'Software e serviços', '\b(?:softwares?|antivirus|armazenamento em nuvem|google fotos|microsoft 365)\b', 'technology' ),
		'consoles'  => array( 'Consoles', '\b(?:consoles?|ps[345]|playstation|xbox|nintendo|switch|steam deck|rog ally)\b', 'games' ),
	);
	$gaming = (bool) preg_match( '/\b(?:gamer|gamers|gaming|jogar|jogos?|games?|ps[345]|playstation|xbox|nintendo|steam|game pass)\b/', $title );
	$desks = array();
	$product = 'guias';
	$label = 'Guia de compra';
	foreach ( $families as $key => $family ) {
		if ( 'consoles' === $key && preg_match( '/\b(?:jogos?|games?)\b/', $title ) && ! preg_match( '/\bconsoles?\b/', $title ) ) { continue; }
		if ( ! preg_match( '/' . $family[1] . '/', $title ) ) { continue; }
		$product = $key;
		$label = $family[0];
		$desks[] = $family[2];
		// Gaming notebooks, monitors and headsets are useful in BOTH desks.
		if ( 'technology' === $family[2] && $gaming ) { $desks[] = 'games'; }
		break;
	}
	if ( ! $desks ) {
		if ( $gaming ) {
			$desks[] = 'games';
			$product = 'jogos';
			$label = 'Jogos e serviços';
		} elseif ( ! preg_match( '/\b(?:filmes?|novelas?|doramas?|series|carros?|viagens?|hoteis?)\b/', $title ) ) {
			// Editorial classification remains a useful fallback for unfamiliar products.
			if ( array_intersect( $slugs, array( 'tecnologia', 'tech', 'hardware', 'celulares', 'notebooks', 'tvs-e-monitores', 'apps-software', 'ia' ) ) ) {
				$desks[] = 'technology';
			} elseif ( array_intersect( $slugs, array( 'games', 'jogos' ) ) ) {
				$desks[] = 'games';
			}
		}
	}
	return array( 'desks' => array_values( array_unique( $desks ) ), 'product' => $product, 'label' => $label );
}

/** Primed term caches avoid one taxonomy query for every candidate. */
function go_verge_buying_selection_category_slugs( $post_id ) {
	$terms = get_the_terms( $post_id, 'category' );
	if ( is_wp_error( $terms ) || ! $terms ) { return array(); }
	$slugs = array();
	static $parents = array();
	foreach ( $terms as $term ) {
		$slugs[] = $term->slug;
		if ( ! $term->parent ) { continue; }
		if ( ! isset( $parents[ $term->term_id ] ) ) {
			$parents[ $term->term_id ] = array();
			foreach ( get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $id ) {
				$parent = get_term( $id, 'category' );
				if ( $parent instanceof WP_Term ) { $parents[ $term->term_id ][] = $parent->slug; }
			}
		}
		$slugs = array_merge( $slugs, $parents[ $term->term_id ] );
	}
	return array_values( array_unique( $slugs ) );
}

/** Explicit guide gate, also applied after cache hydration. */
function go_verge_buying_selection_profile( $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || 'publish' !== $post->post_status || '' !== (string) $post->post_password ) { return null; }
	$slugs = go_verge_buying_selection_category_slugs( $post->ID );
	$is_guide = (bool) array_intersect( $slugs, go_verge_buying_selection_guide_slugs() );
	if ( ! $is_guide && taxonomy_exists( 'go_content_type' ) ) {
		$types = get_the_terms( $post->ID, 'go_content_type' );
		if ( ! is_wp_error( $types ) && $types ) {
			$is_guide = (bool) array_intersect( wp_list_pluck( $types, 'slug' ), array( 'guia-de-compra', 'guia_compra', 'buying-guide', 'buying_guide' ) );
		}
	}
	return $is_guide ? go_verge_buying_selection_classify( $post->post_title, $slugs ) : null;
}

/**
 * Bounded candidate pool (96 recent guides, NOT the whole post table).
 * Cache contains only IDs and classification, not article bodies. Its lifetime
 * does not depend on a persistent object-cache backend. Write hooks below
 * invalidate it on post or taxonomy edits; unchanged visits reuse the transient.
 */
function go_verge_buying_selection_pool() {
	$signature = '38140|' . get_locale();
	$cache = get_transient( 'go_buying_selection_38140' );
	if ( is_array( $cache ) && isset( $cache['signature'], $cache['items'] ) && $cache['signature'] === $signature ) { return (array) $cache['items']; }
	$clauses = array();
	$category_ids = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => false, 'slug' => go_verge_buying_selection_guide_slugs(), 'fields' => 'ids' ) );
	if ( ! is_wp_error( $category_ids ) && $category_ids ) {
		$clauses[] = array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => array_map( 'absint', $category_ids ), 'include_children' => true );
	}
	if ( taxonomy_exists( 'go_content_type' ) ) {
		$type_ids = get_terms( array( 'taxonomy' => 'go_content_type', 'hide_empty' => false, 'slug' => array( 'guia-de-compra', 'guia_compra', 'buying-guide', 'buying_guide' ), 'fields' => 'ids' ) );
		if ( ! is_wp_error( $type_ids ) && $type_ids ) {
			$clauses[] = array( 'taxonomy' => 'go_content_type', 'field' => 'term_id', 'terms' => array_map( 'absint', $type_ids ), 'include_children' => false );
		}
	}
	$items = array();
	if ( $clauses ) {
		if ( count( $clauses ) > 1 ) { $clauses['relation'] = 'OR'; }
		$query = new WP_Query( array(
			'post_type' => 'post', 'post_status' => 'publish', 'has_password' => false,
			'posts_per_page' => 96, 'no_found_rows' => true, 'ignore_sticky_posts' => true,
			'orderby' => array( 'date' => 'DESC', 'ID' => 'DESC' ),
			'tax_query' => $clauses, 'update_post_meta_cache' => false, 'update_post_term_cache' => true,
		) );
		foreach ( (array) $query->posts as $post ) {
			$profile = go_verge_buying_selection_profile( $post );
			if ( ! $profile || ! $profile['desks'] ) { continue; }
			$items[] = array_merge( array( 'id' => (int) $post->ID ), $profile );
		}
	}
	set_transient( 'go_buying_selection_38140', array( 'signature' => $signature, 'items' => $items ), 10 * MINUTE_IN_SECONDS );
	return $items;
}

/** Invalidate only this read-only module's cache; no post/taxonomy changes. */
function go_verge_buying_selection_invalidate() {
	delete_transient( 'go_buying_selection_38140' );
}
add_action( 'clean_post_cache', 'go_verge_buying_selection_invalidate', 10, 0 );
add_action( 'clean_term_cache', 'go_verge_buying_selection_invalidate', 10, 0 );

/** Relation-only edits need invalidation even when post data is unchanged. */
function go_verge_buying_selection_terms_changed( $object_id, $terms, $tt_ids, $taxonomy ) {
	if ( in_array( $taxonomy, array( 'category', 'go_content_type' ), true ) ) { go_verge_buying_selection_invalidate(); }
}
add_action( 'set_object_terms', 'go_verge_buying_selection_terms_changed', 10, 4 );

/** Prefer different product families, then fill unused places by recency. */
function go_verge_buying_selection_items( $desk, $excluded = array(), $limit = 4, $products = array() ) {
	if ( ! in_array( $desk, array( 'technology', 'games' ), true ) ) { return array(); }
	$limit = min( 4, max( 1, absint( $limit ) ) );
	$excluded = array_map( 'absint', (array) $excluded );
	$products = array_values( array_unique( array_filter( array_map( 'sanitize_key', (array) $products ) ) ) );
	$eligible = array();
	foreach ( go_verge_buying_selection_pool() as $item ) {
		if ( in_array( $item['id'], $excluded, true ) || ! in_array( $desk, $item['desks'], true ) ) { continue; }
		if ( $products && ! in_array( sanitize_key( (string) $item['product'] ), $products, true ) ) { continue; }
		$eligible[ $item['id'] ] = $item;
	}
	$selected = array();
	$families = array();
	foreach ( $eligible as $id => $item ) {
		if ( isset( $families[ $item['product'] ] ) ) { continue; }
		$selected[ $id ] = $item;
		$families[ $item['product'] ] = true;
		if ( count( $selected ) >= $limit ) { break; }
	}
	foreach ( $eligible as $id => $item ) {
		if ( count( $selected ) >= $limit ) { break; }
		$selected[ $id ] = $item;
	}
	if ( function_exists( '_prime_post_caches' ) && $selected ) { _prime_post_caches( array_keys( $selected ), true, true ); }
	$result = array();
	foreach ( $selected as $item ) {
		$post = get_post( $item['id'] );
		$profile = go_verge_buying_selection_profile( $post );
		if ( ! $profile || ! in_array( $desk, $profile['desks'], true ) ) { continue; }
		$result[] = array_merge( $item, array( 'post' => $post ) );
	}
	return $result;
}

/** Render article links, not product offers or generated buying recommendations. */
function go_verge_render_buying_selection( $desk, $excluded = array() ) {
	$items = go_verge_buying_selection_items( $desk, $excluded );
	if ( ! $items ) { return; }
	$url = function_exists( 'go_verge_canonical_buying_guides_url' ) ? go_verge_canonical_buying_guides_url() : '';
	$title_id = wp_unique_id( 'go-buying-selection-title-' );
	?>
	<section class="go-buying-selection go-buying-selection--<?php echo esc_attr( $desk ); ?>" aria-labelledby="<?php echo esc_attr( $title_id ); ?>">
		<header class="go-buying-selection__head">
			<div>
				<span class="go-buying-selection__eyebrow"><?php echo 'games' === $desk ? esc_html__( 'Para jogar', 'go-verge' ) : esc_html__( 'Para escolher seu próximo dispositivo', 'go-verge' ); ?></span>
				<h2 id="<?php echo esc_attr( $title_id ); ?>" class="go-buying-selection__title"><?php esc_html_e( 'Guias de compra', 'go-verge' ); ?></h2>
			</div>
			<?php if ( $url && ! is_wp_error( $url ) ) : ?><a class="go-buying-selection__all" href="<?php echo esc_url( $url ); ?>"><?php esc_html_e( 'Todos os guias', 'go-verge' ); ?><span aria-hidden="true">&#8594;</span></a><?php endif; ?>
		</header>
		<div class="go-buying-selection__grid" data-count="<?php echo (int) count( $items ); ?>">
			<?php foreach ( $items as $item ) : $post_id = (int) $item['id']; ?>
				<article class="go-buying-selection__card" data-go-ad-integrity="atomic">
					<a class="go-buying-selection__link" href="<?php echo esc_url( get_permalink( $post_id ) ); ?>">
						<?php if ( has_post_thumbnail( $post_id ) ) : ?>
							<div class="go-buying-selection__media"><?php echo get_the_post_thumbnail( $post_id, 'go_card', array( 'loading' => 'lazy', 'decoding' => 'async', 'alt' => '', 'sizes' => '(max-width: 600px) 112px, (max-width: 1000px) 45vw, 280px' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- WP thumbnail markup. ?></div>
						<?php endif; ?>
						<div class="go-buying-selection__copy">
							<span class="go-buying-selection__topic"><?php echo esc_html( $item['label'] ); ?></span>
							<h3><?php echo esc_html( get_the_title( $post_id ) ); ?></h3>
							<span class="go-buying-selection__meta"><?php echo function_exists( 'go_verge_time_html' ) ? go_verge_time_html( $post_id ) : '<time datetime="' . esc_attr( get_the_date( 'c', $post_id ) ) . '">' . esc_html( get_the_date( 'd/m/Y', $post_id ) ) . '</time>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- canonical theme helper returns escaped time markup. ?></span>
						</div>
					</a>
				</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
}

/** Hubs keep their own hero, chronological feed, filtering and pagination. */
function go_verge_buying_selection_after_hero( $desk, $hero_ids, $paged, $requested, $search ) {
	// Like the existing hero, this collection belongs to the parent desk.
	// AJAX filters replace only the latest feed, so keep the shelf consistent
	// on direct filtered URLs as well. No new filter parameters are introduced.
	if ( 1 !== (int) $paged ) { return; }
	if ( in_array( $desk, array( 'technology', 'games' ), true ) ) { go_verge_render_buying_selection( $desk, $hero_ids ); }
}
add_action( 'go_verge_editorial_hub_after_hero', 'go_verge_buying_selection_after_hero', 10, 5 );

/** Only root categories: child archives retain their narrower subject and feed. */
function go_verge_buying_selection_archive_after_hero( $term, $used = array(), $format = 'default' ) {
	if ( ! ( $term instanceof WP_Term ) ) { return; }
	$map = array( 'games' => 'games', 'jogos' => 'games', 'tecnologia' => 'technology', 'tech' => 'technology' );
	if ( ! isset( $map[ $term->slug ] ) ) { return; }
	go_verge_render_buying_selection( $map[ $term->slug ], array_map( 'absint', (array) $used ) );
}
add_action( 'go_verge_archive_after_hero', 'go_verge_buying_selection_archive_after_hero', 10, 3 );

/* Kept as a compatibility shim for external calls; category.php no longer uses it. */
function go_verge_buying_selection_category( $term, $paged ) {
	if ( 1 !== (int) $paged ) { return; }
	go_verge_buying_selection_archive_after_hero( $term, array(), 'default' );
}

function go_verge_buying_selection_assets() {
	if ( is_admin() || ! ( is_post_type_archive( 'games' ) || is_page( 'tecnologia' ) || is_page_template( 'page-tecnologia.php' ) || is_category( array( 'games', 'jogos', 'tecnologia', 'tech' ) ) ) ) { return; }
	$css = '/assets/css/buying-guides-integration.css';
	wp_enqueue_style( 'go-verge-buying-selection', GO_VERGE_URI . $css, array( 'go-verge-release-38126' ), go_verge_asset_version( $css ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_buying_selection_assets', 49750 );
