<?php
/**
 * Promotions V19 — store-first commerce surface using the site's own
 * go_promotion records. No external data or synthetic coupons are created.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Normalize store label from editorial promotion metadata. */
function go_verge_v19_store_label( $raw ) {
	$raw = trim( wp_strip_all_tags( (string) $raw ) );
	if ( '' === $raw ) { return ''; }
	$key = remove_accents( mb_strtolower( $raw, 'UTF-8' ) );
	$map = array(
		'amazon' => 'Amazon',
		'amazon brasil' => 'Amazon',
		'mercado livre' => 'Mercado Livre',
		'mercadolivre' => 'Mercado Livre',
		'nuuvem' => 'Nuuvem',
		'steam' => 'Steam',
		'epic' => 'Epic Games Store',
		'epic games' => 'Epic Games Store',
		'epic games store' => 'Epic Games Store',
		'playstation' => 'PlayStation Store',
		'playstation store' => 'PlayStation Store',
		'ps store' => 'PlayStation Store',
		'xbox' => 'Xbox Store',
		'xbox store' => 'Xbox Store',
		'nintendo' => 'Nintendo eShop',
		'nintendo eshop' => 'Nintendo eShop',
		'kabum' => 'KaBuM!',
		'kabum!' => 'KaBuM!',
		'pichau' => 'Pichau',
		'terabyte' => 'Terabyte',
		'terabyte shop' => 'Terabyte',
		'magalu' => 'Magalu',
		'magazine luiza' => 'Magalu',
		'aliexpress' => 'AliExpress',
	);
	return isset( $map[ $key ] ) ? $map[ $key ] : $raw;
}

/**
 * Group only first-party/platform storefronts for the public promotions hub.
 * Third-party key resellers and general marketplaces stay out of this shelf.
 */
function go_verge_v19_store_platform( $store ) {
	$store = go_verge_v19_store_label( $store );
	$map = array(
		'PlayStation Store' => array( 'key' => 'playstation', 'label' => 'PlayStation' ),
		'Xbox Store'        => array( 'key' => 'xbox',        'label' => 'Xbox' ),
		'Nintendo eShop'    => array( 'key' => 'nintendo',    'label' => 'Nintendo' ),
		'Steam'             => array( 'key' => 'pc',          'label' => 'PC' ),
		'Epic Games Store'  => array( 'key' => 'pc',          'label' => 'PC' ),
	);
	return isset( $map[ $store ] ) ? $map[ $store ] : array();
}

/** Parse only an explicit complete date. Ambiguous editorial text stays unknown.
 * Dates without time remain valid through the end of the site's local day. */
function go_verge_promotion_expiry_timestamp( $raw ) {
	if ( class_exists( 'GO_Promo_Utils' ) ) { return GO_Promo_Utils::expiry_timestamp( $raw ); }
	$raw = trim( (string) $raw );
	if ( preg_match( '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/', $raw ) ) {
		$format = false !== strpos( $raw, '.' ) ? '!Y-m-d\\TH:i:s.uP' : '!Y-m-d\\TH:i:sP';
		$date = DateTimeImmutable::createFromFormat( $format, $raw );
		$errors = DateTimeImmutable::getLastErrors();
		return $date && ( ! is_array( $errors ) || ( ! $errors['warning_count'] && ! $errors['error_count'] ) ) ? $date->getTimestamp() : null;
	}
	if ( ! preg_match( '/^(?:\d{4}-\d{2}-\d{2}|\d{2}\/\d{2}\/\d{4})(?:[ T]\d{2}:\d{2}(?::\d{2})?)?$/', $raw ) ) { return null; }
	$zone = function_exists( 'wp_timezone' ) ? wp_timezone() : new DateTimeZone( 'UTC' );
	$has_time = false !== strpos( $raw, ':' );
	$format = false !== strpos( $raw, '/' ) ? 'd/m/Y' : 'Y-m-d';
	if ( $has_time ) { $format .= ( false !== strpos( $raw, 'T' ) ? '\\T' : ' ' ) . ( substr_count( $raw, ':' ) === 2 ? 'H:i:s' : 'H:i' ); }
	$date = DateTimeImmutable::createFromFormat( '!' . $format, $raw, $zone );
	$errors = DateTimeImmutable::getLastErrors();
	if ( ! $date || ( is_array( $errors ) && ( $errors['warning_count'] || $errors['error_count'] ) ) ) { return null; }
	return ( $has_time ? $date : $date->setTime( 23, 59, 59 ) )->getTimestamp();
}

/** Unknown/missing validity is not silently treated as an expired article. */
function go_verge_promotion_has_expired( $post_id, $now = null ) {
	$expiry = go_verge_promotion_expiry_timestamp( get_post_meta( absint( $post_id ), 'go_promotion_valid_until', true ) );
	return null !== $expiry && ( null === $now ? time() : (int) $now ) > $expiry;
}

/** Public visibility is separate from retaining the editorial record in WordPress. */
function go_verge_promotion_is_current( $post_id ) {
	if ( go_verge_promotion_has_expired( $post_id ) ) { return false; }
	$status = (string) get_post_meta( $post_id, 'go_promotion_status', true );
	if ( $status && 'active' !== $status ) { return false; }
	if ( '1' === (string) get_post_meta( $post_id, 'go_promotion_auto_imported', true ) ) {
		if ( class_exists( 'GO_Promo_Utils' ) ) { return GO_Promo_Utils::record_is_current( $post_id ); }
		$checked = get_post_meta( $post_id, 'go_promotion_last_checked_at', true );
		$time = $checked ? strtotime( $checked . ' UTC' ) : false;
		$settings = get_option( 'go_promo_engine_settings', array() );
		$ttl = max( 6, min( 72, (int) ( $settings['interval_hours'] ?? 2 ) * 3 ) ) * HOUR_IN_SECONDS;
		if ( ! $time || $time > time() + 300 || time() - $time > $ttl ) { return false; }
	}
	return true;
}

function go_verge_promotion_price_value( $raw ) {
	if ( class_exists( 'GO_Promo_Utils' ) ) { return GO_Promo_Utils::parse_numeric_price( $raw ); }
	$raw = preg_replace( '/[^0-9,.-]/', '', (string) $raw );
	if ( false !== strpos( $raw, ',' ) ) { $raw = str_replace( ',', '.', str_replace( '.', '', $raw ) ); }
	return is_numeric( $raw ) ? (float) $raw : null;
}

function go_verge_promotion_has_discount_evidence( $id ) {
	if ( '1' === (string) get_post_meta( $id, 'go_promotion_auto_imported', true ) && 'BRL' !== strtoupper( (string) get_post_meta( $id, 'go_promotion_currency', true ) ) ) { return false; }
	$sale = go_verge_promotion_price_value( get_post_meta( $id, 'go_promotion_sale_price', true ) );
	$regular = go_verge_promotion_price_value( get_post_meta( $id, 'go_promotion_regular_price', true ) );
	$discount = (int) get_post_meta( $id, 'go_promotion_discount_percent', true );
	if ( null === $sale || $sale < 0 ) { return false; }
	if ( null !== $regular ) {
		if ( $regular <= 0 || $sale >= $regular ) { return false; }
		$computed = (int) round( ( 1 - $sale / $regular ) * 100 );
		return ! $discount || abs( $computed - $discount ) <= 1;
	}
	return $discount > 0 && $discount <= 100 && ( ( 100 === $discount ) === ( 0.0 === $sale ) );
}

function go_verge_promotion_display_price( $id ) {
	$raw = get_post_meta( $id, 'go_promotion_sale_price', true );
	$price = go_verge_promotion_price_value( $raw );
	if ( null === $price ) { return ''; }
	$currency = strtoupper( (string) get_post_meta( $id, 'go_promotion_currency', true ) ) ?: 'BRL';
	return ( 'BRL' === $currency ? 'R$ ' : $currency . ' ' ) . number_format_i18n( $price, 2 );
}

/** Coupon provenance is evidence of observation, not a guarantee for every cart. */
function go_verge_coupon_is_current( array $row ) {
	if ( class_exists( 'GO_Promo_Utils' ) ) { return GO_Promo_Utils::coupon_is_current( $row ); }
	if ( in_array( $row['status'] ?? '', array( 'expired', 'inactive', 'unavailable', 'invalid' ), true ) ) { return false; }
	$expiry = go_verge_promotion_expiry_timestamp( $row['valid_until'] ?? $row['expires_at'] ?? '' );
	if ( null !== $expiry && time() > $expiry ) { return false; }
	$manual = in_array( $row['source'] ?? '', array( 'manual', 'verified' ), true );
	if ( $manual && null !== $expiry ) { return true; }
	$checked = $row['checked_at'] ?? $row['verified_at'] ?? '';
	$timestamp = $checked ? strtotime( $checked . ' UTC' ) : false;
	return $timestamp && $timestamp <= time() + 300 && time() - $timestamp <= ( $manual ? 7 * DAY_IN_SECONDS : 6 * HOUR_IN_SECONDS ) && ( $manual || ! empty( $row['source_url'] ) );
}

/** Filter a bounded, unpaginated promotion pool before deciding to render it. */
function go_verge_filter_current_promotion_query( $query, $limit = 6 ) {
	$query->posts = array_slice( array_values( array_filter( (array)$query->posts, static function($post) {
		return $post instanceof WP_Post && go_verge_promotion_is_current($post->ID) && go_verge_promotion_has_discount_evidence($post->ID);
	} ) ), 0, max(1,min(24,absint($limit))) );
	$query->post_count = count($query->posts);
	$query->rewind_posts();
	return $query;
}

/** Get current promotion records ready for a public store grid. */
function go_verge_v19_store_promotions( $limit = 12, $manual_only = false ) {
	if ( ! post_type_exists( 'go_promotion' ) ) { return array(); }
	$limit = max( 1, min( 24, absint( $limit ) ) );

	$query = new WP_Query( array(
		'post_type'           => 'go_promotion',
		'post_status'         => 'publish',
		'has_password'        => false,
		'posts_per_page'      => min( 160, max( 48, $limit * 8 ) ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'orderby'             => array( 'menu_order' => 'ASC', 'date' => 'DESC' ),
		'meta_query'          => $manual_only ? array( 'relation'=>'OR', array( 'key'=>'go_promotion_auto_imported', 'compare'=>'NOT EXISTS' ), array( 'key'=>'go_promotion_auto_imported', 'value'=>'1', 'compare'=>'!=' ) ) : array(),
	) );

	$items = array();
	foreach ( $query->posts as $post ) {
		$post_id = (int) $post->ID;
		if ( $manual_only && '1' === (string) get_post_meta( $post_id, 'go_promotion_auto_imported', true ) ) { continue; }
		if ( ! go_verge_promotion_is_current( $post_id ) || ! go_verge_promotion_has_discount_evidence( $post_id ) ) { continue; }
		$store = go_verge_v19_store_label( get_post_meta( $post_id, 'go_promotion_store_name', true ) );
		if ( '' === $store ) { continue; }
		$platform = go_verge_v19_store_platform( $store );
		if ( empty( $platform ) ) { continue; }

		$url = trim( (string) get_post_meta( $post_id, 'go_promotion_offer_url', true ) );
		if ( '' === $url ) { $url = get_permalink( $post_id ); }
		$price = go_verge_promotion_display_price( $post_id );
		$valid = trim( (string) get_post_meta( $post_id, 'go_promotion_valid_until', true ) );
		$code  = trim( (string) get_post_meta( $post_id, 'go_promotion_coupon_code', true ) );
		$cta   = trim( (string) get_post_meta( $post_id, 'go_promotion_button_label', true ) );
		$image = get_the_post_thumbnail_url( $post_id, 'go_card' ) ?: esc_url_raw( get_post_meta( $post_id, 'go_promotion_source_image_url', true ) );
		if ( $code && ! go_verge_coupon_is_current( array( 'source'=>'manual', 'valid_until'=>$valid, 'verified_at'=>get_post_field( 'post_modified_gmt', $post_id ) ) ) ) { $code = ''; }

		$items[] = array(
			'id'    => $post_id,
			'title' => get_the_title( $post_id ),
			'store'          => $store,
			'key'            => sanitize_title( $store ),
			'platform_key'   => $platform['key'],
			'platform_label' => $platform['label'],
			'url'   => $url,
			'price' => $price,
			'valid' => $valid,
			'code'  => $code,
			'cta'   => $cta ?: __( 'Ver oferta', 'go-verge' ),
			'image' => $image ?: '',
		);
		if ( count( $items ) >= $limit ) { break; }
	}

	wp_reset_postdata();
	return $items;
}

/**
 * Store offers renderer. Returns true only when real go_promotion records exist.
 */
function go_verge_render_store_promotions_v19( $limit = 12, $manual_only = false ) {
	$items = go_verge_v19_store_promotions( $limit, $manual_only );
	if ( empty( $items ) ) { return false; }

	$stores = array();
	foreach ( $items as $item ) {
		$stores[ $item['platform_key'] ] = $item['platform_label'];
	}
	?>
	<section class="go-store-market-v19" aria-labelledby="go-store-market-v19-title">
		<div class="go-store-market-v19__head">
			<div>
				<h2 id="go-store-market-v19-title"><?php esc_html_e( 'Ofertas por plataforma', 'go-verge' ); ?></h2>
			</div>
		</div>

		<?php if ( count( $stores ) > 1 ) : ?>
			<nav class="go-store-market-v19__stores" aria-label="<?php esc_attr_e( 'Plataformas com promoções', 'go-verge' ); ?>">
				<?php foreach ( $stores as $key => $label ) : ?>
					<a href="#go-platform-<?php echo esc_attr( $key ); ?>"><?php echo esc_html( $label ); ?></a>
				<?php endforeach; ?>
			</nav>
		<?php endif; ?>

		<div class="go-store-market-v19__grid">
			<?php $go_seen_stores = array(); ?>
			<?php foreach ( $items as $item ) : ?>
				<?php $go_store_anchor = empty( $go_seen_stores[ $item['platform_key'] ] ) ? 'go-platform-' . $item['platform_key'] : ''; $go_seen_stores[ $item['platform_key'] ] = true; ?>
				<article class="go-store-offer-v19"<?php echo $go_store_anchor ? ' id="' . esc_attr( $go_store_anchor ) . '"' : ''; ?>>
					<a class="go-store-offer-v19__media" href="<?php echo esc_url( $item['url'] ); ?>"<?php echo get_permalink( $item['id'] ) !== $item['url'] ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?> tabindex="-1" aria-hidden="true">
						<?php if ( $item['image'] ) : ?>
							<img src="<?php echo esc_url( $item['image'] ); ?>" alt="" width="640" height="360" loading="lazy" decoding="async" data-go-decorative="1">
						<?php else : ?>
							<span aria-hidden="true"><?php echo esc_html( mb_substr( $item['store'], 0, 1 ) ); ?></span>
						<?php endif; ?>
					</a>
					<div class="go-store-offer-v19__body">
						<div class="go-store-offer-v19__top">
							<span class="go-store-offer-v19__store"><?php echo esc_html( $item['store'] ); ?></span>
							<?php if ( $item['code'] ) : ?><code><?php echo esc_html( $item['code'] ); ?></code><?php endif; ?>
						</div>
						<h3><a href="<?php echo esc_url( $item['url'] ); ?>"<?php echo get_permalink( $item['id'] ) !== $item['url'] ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?>><?php echo esc_html( $item['title'] ); ?></a></h3>
						<div class="go-store-offer-v19__foot">
							<?php if ( $item['price'] ) : ?><strong><?php echo esc_html( $item['price'] ); ?></strong><?php endif; ?>
							<?php if ( $item['valid'] ) : ?><small><?php echo esc_html( sprintf( __( 'Até %s', 'go-verge' ), $item['valid'] ) ); ?></small><?php endif; ?>
							<a class="go-store-offer-v19__cta" href="<?php echo esc_url( $item['url'] ); ?>"<?php echo get_permalink( $item['id'] ) !== $item['url'] ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?>><?php echo esc_html( $item['cta'] ); ?><span aria-hidden="true">→</span></a>
						</div>
					</div>
				</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
	return true;
}

/** Canonical Offers hub: live game deals plus distinct editorial store offers. */
function go_verge_render_verified_promotions( $limit = 12 ) {
	$has_engine = class_exists( 'GO_Promo_Renderer' );
	if ( $has_engine ) { GO_Promo_Renderer::render_deals( array( 'limit' => $limit ) ); }
	$manual = go_verge_render_store_promotions_v19( $limit, $has_engine );
	if ( ! $has_engine && ! $manual ) { echo '<p class="go-auto-deals__empty">' . esc_html__( 'Nenhuma promoção com desconto confirmado está disponível agora.', 'go-verge' ) . '</p>'; }
}


/**
 * Game-linked promotions for the canonical /ofertas/ hub.
 *
 * A deal counts as a game promotion only when it is explicitly linked to a
 * Games record by one of the relationship keys used by the current/legacy
 * promotion editors. This prevents hardware offers from leaking into the game
 * shelf simply because their title happens to contain a game name.
 */
function go_verge_v73_game_promotions( $limit = 12 ) {
	if ( ! post_type_exists( 'go_promotion' ) ) { return array(); }
	$limit = max( 1, min( 24, absint( $limit ) ) );

	$query = new WP_Query( array(
		'post_type'           => 'go_promotion',
		'post_status'         => 'publish',
		'posts_per_page'      => min( 96, max( 24, $limit * 4 ) ),
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'orderby'             => array( 'menu_order' => 'ASC', 'date' => 'DESC' ),
		'meta_query'          => array(
			'relation' => 'OR',
			array( 'key'=>'go_promotion_linked_game_id', 'value'=>0, 'compare'=>'>', 'type'=>'NUMERIC' ),
			array( 'key'=>'go_linked_game_id', 'value'=>0, 'compare'=>'>', 'type'=>'NUMERIC' ),
			array( 'key'=>'_go_linked_game_id', 'value'=>0, 'compare'=>'>', 'type'=>'NUMERIC' ),
		),
	) );

	$items = array();
	foreach ( $query->posts as $promotion ) {
		$post_id = absint( $promotion->ID );
		if ( ! go_verge_promotion_is_current( $post_id ) || ! go_verge_promotion_has_discount_evidence( $post_id ) ) { continue; }
		$game_id = 0;
		foreach ( array( 'go_promotion_linked_game_id', 'go_linked_game_id', '_go_linked_game_id' ) as $key ) {
			$game_id = absint( get_post_meta( $post_id, $key, true ) );
			if ( $game_id ) { break; }
		}
		if ( ! $game_id || 'games' !== get_post_type( $game_id ) ) { continue; }

		$url = trim( (string) get_post_meta( $post_id, 'go_promotion_offer_url', true ) );
		if ( ! $url ) { $url = get_permalink( $post_id ); }
		$items[] = array(
			'id'      => $post_id,
			'game_id' => $game_id,
			'game'    => get_the_title( $game_id ),
			'title'   => get_the_title( $post_id ),
			'store'   => go_verge_v19_store_label( get_post_meta( $post_id, 'go_promotion_store_name', true ) ),
			'url'     => $url,
			'price'   => go_verge_promotion_display_price( $post_id ),
			'code'    => trim( (string) get_post_meta( $post_id, 'go_promotion_coupon_code', true ) ),
			'cta'     => trim( (string) get_post_meta( $post_id, 'go_promotion_button_label', true ) ) ?: __( 'Ver oferta', 'go-verge' ),
			'image'   => get_the_post_thumbnail_url( $post_id, 'go_card' ) ?: get_the_post_thumbnail_url( $game_id, 'go_card' ),
		);
		if ( count( $items ) >= $limit ) { break; }
	}
	wp_reset_postdata();
	return $items;
}

/** Render a dedicated, game-only deal shelf. */
function go_verge_render_game_promotions_v73( $limit = 12 ) {
	$items = go_verge_v73_game_promotions( $limit );
	if ( empty( $items ) ) { return false; }
	?>
	<section class="go-store-market-v19 go-game-market-v73" aria-labelledby="go-game-market-v73-title">
		<div class="go-store-market-v19__head">
			<div>
				<span class="go-store-market-v19__eyebrow"><?php esc_html_e( 'Radar de preço', 'go-verge' ); ?></span>
				<h2 id="go-game-market-v73-title"><?php esc_html_e( 'Promoções de jogos', 'go-verge' ); ?></h2>
			</div>
			<p><?php esc_html_e( 'Ofertas vinculadas diretamente aos jogos acompanhados pelo Overdrive.', 'go-verge' ); ?></p>
		</div>
		<div class="go-store-market-v19__grid">
			<?php foreach ( $items as $item ) : ?>
				<article class="go-store-offer-v19 go-game-offer-v73">
					<a class="go-store-offer-v19__media" href="<?php echo esc_url( $item['url'] ); ?>"<?php echo get_permalink( $item['id'] ) !== $item['url'] ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?> tabindex="-1" aria-hidden="true">
						<?php if ( $item['image'] ) : ?><img src="<?php echo esc_url( $item['image'] ); ?>" alt="" width="640" height="360" loading="lazy" decoding="async" data-go-decorative="1"><?php else : ?><span aria-hidden="true">GO</span><?php endif; ?>
					</a>
					<div class="go-store-offer-v19__body">
						<div class="go-store-offer-v19__top">
							<span class="go-store-offer-v19__store"><?php echo esc_html( $item['store'] ?: __( 'Oferta', 'go-verge' ) ); ?></span>
							<?php if ( $item['code'] ) : ?><code><?php echo esc_html( $item['code'] ); ?></code><?php endif; ?>
						</div>
						<span class="go-game-offer-v73__game"><?php echo esc_html( $item['game'] ); ?></span>
						<h3><a href="<?php echo esc_url( $item['url'] ); ?>"<?php echo get_permalink( $item['id'] ) !== $item['url'] ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?>><?php echo esc_html( $item['title'] ); ?></a></h3>
						<div class="go-store-offer-v19__foot">
							<?php if ( $item['price'] ) : ?><strong><?php echo esc_html( $item['price'] ); ?></strong><?php endif; ?>
							<a class="go-store-offer-v19__cta" href="<?php echo esc_url( $item['url'] ); ?>"<?php echo get_permalink( $item['id'] ) !== $item['url'] ? ' target="_blank" rel="nofollow sponsored noopener"' : ''; ?>><?php echo esc_html( $item['cta'] ); ?><span aria-hidden="true">→</span></a>
						</div>
					</div>
				</article>
			<?php endforeach; ?>
		</div>
	</section>
	<?php
	return true;
}
