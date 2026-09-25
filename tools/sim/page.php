<?php
/**
 * Build a self-contained single-post test page from a theme build.
 *
 *   php tools/sim/page.php <theme-dir> <type> <words> > page.html
 *
 * The article body is composed by the theme's own planner/composer, every ad
 * host comes from the theme's renderer, and the real generated runtime is
 * inlined with the theme's own GOAdsYieldConfig. Editorial blocks around the
 * ads are fixed-height stand-ins for the real template parts, in the same order
 * as template-parts/single/article.php. A fake adsbygoogle (see run.cjs) answers
 * requests; nothing leaves the machine.
 */
require dirname( __DIR__ ) . '/wp-stubs.php';
$theme = rtrim( $argv[1] ?? '', '/' );
$type  = $argv[2] ?? 'news';
$words = max( 200, (int) ( $argv[3] ?? 700 ) );
define( 'GO_VERGE_DIR', $theme );
define( 'GO_VERGE_URI', 'https://example.test/wp-content/themes/overdrive' );
$GLOBALS['__stub_ctx'] = array( 'context' => 'single_post', 'singular' => 'post', 'page_slug' => '' );
if ( is_readable( $theme . '/inc/ads/engine-settings.php' ) ) { require $theme . '/inc/ads/engine-settings.php'; }
foreach ( array( 'mode', 'config', 'calendar-trials', 'economics', 'yield', 'context', 'consent', 'renderer', 'planner', 'composer', 'topscroll' ) as $m ) {
	require $theme . '/inc/ads/' . $m . '.php';
}
add_filter( 'go_verge_ads_article_type', static function () use ( $type ) { return $type; } );

/* Same deterministic corpus generator as tools/plan-bench.php. */
$lorem = explode( ' ', 'o jogo chega ao console com uma proposta ousada de mundo aberto que mistura exploração combate tático e narrativa ramificada enquanto a equipe promete desempenho estável em sessenta quadros por segundo nas plataformas atuais além de suporte a mods e conteúdo adicional gratuito ao longo do primeiro ano de lançamento segundo o estúdio responsável pelo projeto' );
function sim_words( $n ) { global $lorem; $o = array(); for ( $i = 0; $i < $n; $i++ ) { $o[] = $lorem[ mt_rand( 0, count( $lorem ) - 1 ) ]; } return ucfirst( implode( ' ', $o ) ) . '.'; }
mt_srand( 7000 + $words );
$html = ''; $count = 0; $i = 0;
while ( $count < $words ) {
	$i++;
	if ( in_array( $type, array( 'guide', 'ranking', 'list' ), true ) && 1 === $i % 4 && $i > 1 ) {
		$html .= '<h2>' . sim_words( 5 ) . '</h2>';
		if ( 0 === mt_rand( 0, 1 ) ) { $html .= '<figure class="wp-block-image"><img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" width="640" height="360" alt=""></figure>'; }
	} elseif ( 'news' === $type && 0 === $i % 6 ) {
		$html .= '<figure class="wp-block-image"><img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" width="640" height="360" alt=""></figure>';
	}
	$n = mt_rand( 28, 85 );
	$html .= '<p>' . sim_words( $n ) . '</p>';
	$count += $n;
}
$body = go_verge_ads_compose_article_inventory( $html );

function sim_block( $label, $height ) { return '<section class="sim-block" style="height:' . (int) $height . 'px">' . esc_html( $label ) . '</section>'; }
function sim_capture( $cb ) { ob_start(); $cb(); return ob_get_clean(); }
$yield = go_verge_ads_yield_config();
if ( getenv( 'SIM_VIEW_MODEL' ) ) {
	/* A plausible seven-day per-unit Active View spread (the shape the Ads
	 * Center syncs), so the per-unit controller has something to act on. The
	 * same model is injected into every build being compared. */
	$yield['decision']['generated_at']  = time();
	$yield['decision']['model_samples'] = 500;
	$yield['decision']['slot_viewability'] = array(
		'7792311754' => 0.70, '3572313419' => 0.65, '5017324239' => 0.45, '5223365459' => 0.55,
		'7131714626' => 0.50, '4505551284' => 0.45, '5056215625' => 0.40, '6568236715' => 0.35,
		'8238832024' => 0.32, '5255155049' => 0.30, '5798080525' => 0.30, '4927851985' => 0.38,
		'3996334686' => 0.30, '2880273141' => 0.30, '1889487031' => 0.50, '9492644884' => 0.35,
	);
}
$runtime = file_get_contents( $theme . '/assets/js/go-ads-runtime.min.js' );
$css = file_get_contents( $theme . '/assets/css/go-ads.css' );
?><!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>sim</title>
<style>
body{margin:0;font:18px/1.7 Georgia,serif;background:#fff;color:#111}
.go-container,.go-single__main{width:calc(100% - 32px);max-width:720px;margin-inline:auto}
.sim-block{box-sizing:border-box;margin:24px 0;padding:12px;background:#f3f1f5;color:#777;font:14px sans-serif}
figure{margin:24px 0}figure img{display:block;width:100%;height:auto;background:#ddd}
h2{font:700 26px/1.2 sans-serif;margin:32px 0 12px}
.go-article__content > p{margin:0 0 1.1em}
</style>
<style><?php echo $css; ?></style>
<script>window.__simFill=window.__simFill||1;</script>
<script>window.GOAdsYieldConfig=<?php echo wp_json_encode( $yield ); ?>;</script>
<script><?php echo $runtime; ?></script>
</head>
<body class="single-post go-verge go-single-clean">
<?php echo sim_block( 'header', 120 ); ?>
<?php echo sim_capture( 'go_verge_adsense_render_topscroll_slot' ); ?>
<main id="primary" class="go-main go-single-page"><article class="go-single od-article">
<div class="go-container"><?php echo sim_block( 'título, linha fina, byline', 260 ); ?></div>
<div class="go-container"><?php echo sim_capture( static function () { go_verge_ads_render_masthead_phone( 'od-article__top-display' ); } ); ?></div>
<div class="go-container"><?php echo sim_block( 'imagem hero', 220 ); ?></div>
<div class="go-container od-article__hero-ad"><?php echo go_verge_adsense_unit_markup( 'article-hero-overlay', array( 'class' => 'go-single__hero-ad', 'data' => array( 'ad-surface' => 'article-hero' ) ) ); ?></div>
<div class="go-container go-single__layout"><div class="go-single__main">
<div <?php echo go_verge_ads_article_root_attributes(); ?>><?php echo $body; ?></div>
<?php go_verge_render_adsense_unit( 'article-end', array( 'class' => 'go-article-end-revenue-slot', 'data' => array( 'ad-surface' => 'article-completion', 'ad-depth' => 100 ) ) ); ?>
<?php echo sim_block( 'assuntos', 60 ); ?>
<?php echo sim_block( 'cartão do autor', 200 ); ?>
<?php go_verge_ads_render_post_content_unit( 'after-author' ); ?>
<?php echo sim_block( 'continue neste assunto', 260 ); ?>
<?php echo sim_block( 'recirculação', 700 ); ?>
<?php go_verge_ads_render_post_content_unit( 'after-recirculation' ); ?>
<?php echo sim_block( 'barra de tópicos', 90 ); ?>
<?php go_verge_ads_render_post_content_unit( 'before-comments' ); ?>
<?php echo sim_block( 'comentários', 900 ); ?>
<?php go_verge_ads_render_post_content_unit( 'after-comments' ); ?>
</div>
<aside class="go-article-sidebar"><?php echo sim_block( 'trilho: ofertas e histórias', 650 ); ?>
<?php go_verge_render_adsense_unit( 'sidebar-desktop', array( 'tag' => 'div', 'class' => 'go-article-sidebar__ad go-article-sidebar__ad--sticky', 'data' => array( 'ad-surface' => 'article-sidebar' ) ) ); ?>
<?php go_verge_render_adsense_unit( 'article-rail-mobile', array( 'tag' => 'div', 'class' => 'go-article-sidebar__ad go-article-sidebar__ad--stacked', 'data' => array( 'ad-surface' => 'rail-stacked-mobile' ) ) ); ?>
</aside></div></article>
<div class="go-container"><?php echo sim_block( 'leia também + segunda vitrine', 1200 ); ?></div>
<?php go_verge_ads_render_post_content_unit( 'after-article-sections', 'go-container go-post-content-revenue' ); ?>
<div class="go-container"><?php echo sim_block( 'explore o overdrive', 420 ); ?></div>
</main>
<?php do_action( 'get_footer', null, array() ); ?>
<?php echo sim_block( 'rodapé', 700 ); ?>
<?php do_action( 'wp_footer' ); ?>
</body></html>
