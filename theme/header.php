<?php
/**
 * Header: masthead, primary nav, search overlay + offcanvas triggers.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<!doctype html>
<html <?php language_attributes(); ?>>
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, viewport-fit=cover">
	<link rel="profile" href="https://gmpg.org/xfn/11">
	<script>
	(function () {
		var fallback = window.matchMedia && window.matchMedia( '(prefers-color-scheme: light)' ).matches ? 'light-mode' : 'dark-mode';
		var stored = '';
		try {
			stored = localStorage.getItem( 'go-theme' ) || '';
		} catch ( e ) {}
		if ( stored !== 'light-mode' && stored !== 'dark-mode' ) {
			stored = fallback;
		}
		document.documentElement.setAttribute( 'data-theme', stored );
	})();
	</script>
	<style id="go-critical-shell">
		html{background:#111015;width:100%;min-width:0;max-width:100%}html[data-theme="light-mode"]{background:#FAF8F6}body{margin:0;width:100%;min-width:0;max-width:100%}@media(max-width:767px){html,body{overflow-x:clip}}@supports not (overflow:clip){@media(max-width:767px){html,body{overflow-x:hidden}}}
        /* 3.80: reserved geometry matches publisher-shell.css before first paint. */
        .od-masthead-shell{position:sticky;top:0;z-index:60;height:122px;pointer-events:none}.od-masthead{position:relative;pointer-events:auto;background:#121216;color:#fff;height:122px}
        .od-masthead__bar{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;height:76px;width:min(1240px,calc(100% - 64px));margin:auto}
        .od-masthead__brand{display:flex;align-items:center;justify-content:center}
        .od-masthead__brand .go-brand-image--dark{display:block!important;width:184px!important;height:auto!important;max-height:44px!important}
        .od-masthead__brand .go-brand-image--light{display:none!important}
        .od-masthead__nav{height:46px;overflow-x:auto}
        @media(max-width:767px){.od-masthead-shell,.od-masthead{height:106px}.od-masthead__bar{height:62px;width:calc(100% - 24px)}.od-masthead__brand .go-brand-image--dark{width:146px!important;max-height:36px!important}.od-masthead__nav{height:44px}}
        @media(max-width:359px){.od-masthead__brand .go-brand-image--dark{width:120px!important}}
        body.admin-bar .od-masthead-shell{top:32px}@media(max-width:782px){body.admin-bar .od-masthead-shell{top:46px}}@media(max-width:600px){body.admin-bar .od-masthead-shell{top:0}}

		/* Stable first-paint Top Scroll geometry. The 44px publisher-control row
		   (label + close button, 8px clear of the creative) and a 14px tap-safety gap
		   above the masthead's Menu/Search buttons sit outside the responsive
		   creative. Full-width responsive creatives on phones are ~5:6 of the
		   viewport (300x250 scaled), so that height is reserved up front instead of
		   growing after the auction; the high-water reserve keeps it. */
		body.go-verge>.go-adsense-topscroll{box-sizing:border-box;display:block;width:100%;min-height:var(--go-ad-resolved-reserve,max(308px,calc(min(83.334vw,360px) + 58px)));margin:0;padding:44px 0 14px;background:#111015;text-align:center}
		body.go-verge>.go-adsense-topscroll[data-go-ad-sizing="fixed"]{min-height:var(--go-ad-resolved-reserve,var(--go-ad-reserve-mobile,132px))}
		html[data-theme="light-mode"] body.go-verge>.go-adsense-topscroll{background:#FAF8F6}
		@media(min-width:768px){body.go-verge>.go-adsense-topscroll:not([data-go-ad-requested="1"]){display:none;min-height:0;padding:0}}
	</style>
	<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<a class="skip-link screen-reader-text" href="#primary"><?php esc_html_e( 'Pular para o conteúdo', 'go-verge' ); ?></a>

<?php
/*
 * Manual AdSense top-scroll. It is the first visible block, directly before the
 * masthead. Its responsive creative has a 308px baseline including the control
 * row and the tap-safety gap. Empty auctions keep that small reservation for the
 * page view rather than causing a late upward shift. It is independent of the
 * Google overlay formats (anchor/vignette), which the account keeps enabled; the
 * anchor should be bottom-only so it never stacks on this block.
 *
 * Clever's 320x50 anchor is docked above it, in normal flow. Its 50px strip is
 * printed here and shown only on the phone pageview that opens Clever's
 * rotation (inc/ads/clever.php); every other pageview renders nothing new.
 */
if ( function_exists( 'go_verge_clever_render_anchor_slot' ) ) {
	go_verge_clever_render_anchor_slot();
}
if ( function_exists( 'go_verge_adsense_render_topscroll_slot' ) ) {
	go_verge_adsense_render_topscroll_slot();
}
?>


<?php
/* Publisher identity and canonical editorial destinations. */
$go_header_identity = function_exists( 'go_verge_header_context_identity' ) ? go_verge_header_context_identity() : array( 'label' => '', 'url' => '' );
$go_header_section = go_verge_publisher_current_desk();
if ( ! $go_header_section && go_verge_is_latest_hub() ) { $go_header_section = 'latest'; }
if ( is_page( array( 'compara', 'overdrive-compara', 'comparador' ) ) ) { $go_header_section = 'compara'; }
$go_header_links = array(
    array( 'key' => 'latest', 'label' => 'Últimas', 'url' => function_exists( 'go_verge_latest_url' ) ? go_verge_latest_url() : home_url( '/ultimas-publicacoes/' ) ),
    array( 'key' => 'games', 'label' => 'Games', 'url' => function_exists( 'go_verge_v7_category_url' ) ? go_verge_v7_category_url( 'games' ) : home_url( '/games/' ) ),
    array( 'key' => 'entretenimento', 'label' => 'Entretenimento', 'url' => go_verge_v7_category_url( 'entretenimento' ) ),
    array( 'key' => 'tecnologia', 'label' => 'Tecnologia', 'url' => go_verge_v7_category_url( 'tecnologia' ) ),
    array( 'key' => 'ofertas', 'label' => 'Ofertas', 'url' => go_verge_v7_category_url( 'ofertas' ) ),
    array( 'key' => 'compara', 'label' => 'Compare', 'url' => function_exists( 'go_verge_compara_url' ) ? go_verge_compara_url() : home_url( '/compara/' ) ),
);
?>
<div class="od-masthead-shell">
<header class="od-masthead" id="masthead">
    <div class="od-masthead__bar">
        <div class="od-masthead__leading">
            <button type="button" class="od-masthead__button od-masthead__menu" data-go-toggle="offcanvas" aria-label="<?php esc_attr_e( 'Abrir menu', 'go-verge' ); ?>" aria-controls="go-offcanvas" aria-expanded="false">
                <?php echo go_verge_icon( 'menu', '' ); ?><span>Menu</span>
            </button>
            <?php if ( ! is_front_page() && ! empty( $go_header_identity['label'] ) ) : ?>
                <a class="od-masthead__context" href="<?php echo esc_url( $go_header_identity['url'] ); ?>"><?php echo esc_html( $go_header_identity['label'] ); ?></a>
            <?php endif; ?>
        </div>
        <a class="od-masthead__brand" href="<?php echo esc_url( home_url( '/' ) ); ?>" rel="home" aria-label="<?php esc_attr_e( 'Overdrive — página inicial', 'go-verge' ); ?>"><?php go_verge_logo_large(); ?></a>
        <div class="od-masthead__actions">
            <button type="button" class="od-masthead__button od-masthead__theme" data-go-theme-toggle aria-label="<?php esc_attr_e( 'Alternar modo claro e escuro', 'go-verge' ); ?>" title="<?php esc_attr_e( 'Alternar modo claro e escuro', 'go-verge' ); ?>">
                <?php echo go_verge_icon( 'theme-sun', 'go-theme-toggle__sun' ); ?>
                <?php echo go_verge_icon( 'theme-moon', 'go-theme-toggle__moon' ); ?>
            </button>
            <button type="button" class="od-masthead__button od-masthead__search" data-go-toggle="search" aria-label="<?php esc_attr_e( 'Buscar no Overdrive', 'go-verge' ); ?>" aria-controls="go-search" aria-expanded="false">
                <?php echo go_verge_icon( 'busca', '' ); ?><span>Buscar</span>
            </button>
        </div>
    </div>
    <nav class="od-masthead__nav" aria-label="<?php esc_attr_e( 'Editorias', 'go-verge' ); ?>">
        <ul class="od-masthead__links">
        <?php foreach ( $go_header_links as $go_header_link ) : ?>
            <li><a class="od-masthead__link<?php echo 'compara' === $go_header_link['key'] ? ' od-masthead__link--compara' : ''; ?>" href="<?php echo esc_url( $go_header_link['url'] ); ?>"<?php echo $go_header_section === $go_header_link['key'] ? ' aria-current="location"' : ''; ?>><?php echo esc_html( $go_header_link['label'] ); ?><?php if ( 'compara' === $go_header_link['key'] ) : ?><svg class="od-masthead__compare-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" aria-hidden="true" focusable="false"><path d="M8 4v16M16 4v16M5 8h6M13 16h6"/><circle cx="8" cy="8" r="2.5" fill="#121216"/><circle cx="16" cy="16" r="2.5" fill="#121216"/></svg><?php endif; ?></a></li>
        <?php endforeach; ?>
        </ul>
    </nav>
</header>
</div>

<?php get_template_part( 'template-parts/offcanvas' ); ?>

<div class="go-search go-search--compact" id="go-search" aria-hidden="true" inert role="dialog" aria-modal="false" aria-labelledby="go-search-title">
	<div class="go-search__inner">
		<div class="go-search__head">
			<div class="go-search__heading">
				<span class="go-search__eyebrow"><?php esc_html_e( 'Pesquisa', 'go-verge' ); ?></span>
				<strong class="go-search__title" id="go-search-title"><?php esc_html_e( 'O que você procura?', 'go-verge' ); ?></strong>
			</div>
			<button type="button" class="go-iconbtn go-search__close" data-go-close="search" aria-label="<?php esc_attr_e( 'Fechar busca', 'go-verge' ); ?>">
				<?php echo go_verge_icon( 'fechar', '' ); ?>
			</button>
		</div>

		<form method="get" action="<?php echo esc_url( home_url( '/' ) ); ?>" role="search">
			<label class="screen-reader-text" for="go-search-field"><?php esc_html_e( 'Buscar no Overdrive', 'go-verge' ); ?></label>
			<div class="go-search__field-wrap">
				<?php echo go_verge_icon( 'busca', 'go-search__field-icon' ); ?>
				<input id="go-search-field" type="search" name="s" value="<?php echo esc_attr( get_search_query() ); ?>" placeholder="<?php esc_attr_e( 'Jogos, reviews, notícias…', 'go-verge' ); ?>" autocomplete="off">
			</div>
			<button type="submit" class="go-btn go-btn--mint go-search__submit">
				<?php esc_html_e( 'Pesquisar', 'go-verge' ); ?>
			</button>
		</form>
	</div>
</div>

<div class="go-site" id="go-main">

<?php
/*
 * Manual top inventory for non-home surfaces. On the front page the desktop
 * Top Display is rendered by front-page.php immediately after the hero, so it
 * never sits above the lead stories. Mobile home keeps Top Scroll only, by
 * publisher decision. The AdSense bootstrap is printed once in wp_head by the
 * ads loader.
 *
 * On posts, phones get the Top Display as an exact 320x100 in a host of its own
 * (go_verge_ads_masthead_phone_mode()): below the byline for the standard story
 * layout (printed by template-parts/single/article.php), or right here for the
 * review/critique opening with a hero and for Specials. This host then serves
 * tablets and desktop only, exactly as before.
 */
if ( function_exists( 'go_verge_render_adsense_unit' ) && ! is_front_page() ) {
	$go_masthead_placement = is_home() ? 'home-masthead' : 'site-masthead';
	$go_masthead_phone     = ( 'site-masthead' === $go_masthead_placement && function_exists( 'go_verge_ads_masthead_phone_mode' ) ) ? go_verge_ads_masthead_phone_mode() : '';
	go_verge_render_adsense_unit(
		$go_masthead_placement,
		array(
			'tag'      => 'aside',
			'class'    => 'go-container go-site-masthead-ad go-revenue-parity-top-display',
			'viewport' => '' !== $go_masthead_phone ? 'tablet-up' : '',
			'data'     => array( 'ad-surface' => 'masthead' ),
		)
	);
	if ( 'header' === $go_masthead_phone && function_exists( 'go_verge_ads_render_masthead_phone' ) ) {
		go_verge_ads_render_masthead_phone();
	}
	unset( $go_masthead_placement, $go_masthead_phone );
}
?>
