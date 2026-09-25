<?php
/**
 * The single AdSense bootstrap for this site.
 *
 * The theme is the only loader owner. Site Kit's duplicate tag is suppressed
 * while its reporting remains untouched. One canonical script serves both the
 * theme's manual inventory and the account's Auto ads (including in-page
 * formats); Site Kit must not emit a second bootstrap.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function go_verge_ads_should_bootstrap_client() {
	if ( function_exists( 'go_verge_ads_is_monetizable_request' ) ) {
		return (bool) go_verge_ads_is_monetizable_request();
	}
	return false;
}

function go_verge_ads_theme_owns_loader() {
	$owns = go_verge_ads_should_bootstrap_client()
		&& (bool) apply_filters( 'go_verge_ads_owns_adsense_loader', true );
	return (bool) apply_filters( 'go_verge_ads_should_print_loader', $owns );
}

function go_verge_ads_should_print_loader() {
	return go_verge_ads_theme_owns_loader() && empty( $GLOBALS['go_verge_ads_loader_claimed'] );
}

/** Prevent Site Kit from emitting a second adsbygoogle.js tag. */
function go_verge_ads_block_site_kit_adsense_tag( $blocked = false ) {
	if ( $blocked || go_verge_ads_theme_owns_loader() ) { return true; }
	/* Site Kit checks this at template_redirect, before Compare's templates
	 * declare their resolved content. Reserve the shared loader for the theme
	 * throughout that lifecycle; normal eligibility still decides whether the
	 * theme emits it. Empty/invalid Compare screens therefore stay excluded.
	 * Use the plugin's public request API, not URL or user-agent heuristics. */
	if ( is_callable( array( 'GOC_Frontend', 'is_comparator_request' ) ) && GOC_Frontend::is_comparator_request() ) {
		$owns = (bool) apply_filters( 'go_verge_ads_owns_adsense_loader', true );
		return (bool) apply_filters( 'go_verge_ads_should_print_loader', $owns );
	}
	return false;
}
add_filter( 'googlesitekit_adsense_tag_blocked', 'go_verge_ads_block_site_kit_adsense_tag', 20 );

/** @return string */
function go_verge_ads_canonical_loader_tag() {
	$client = defined( 'GO_VERGE_ADSENSE_CLIENT' ) ? trim( (string) GO_VERGE_ADSENSE_CLIENT ) : '';
	if ( '' === $client ) {
		return '';
	}
	return sprintf(
		'<script async data-cfasync="false" data-no-optimize="1" data-no-defer="1" src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=%s" crossorigin="anonymous"></script>',
		esc_attr( rawurlencode( $client ) )
	);
}

/** Print the one canonical provider loader as early as practical. */
function go_verge_ads_print_loader() {
	if ( ! go_verge_ads_should_print_loader() ) {
		return;
	}
	$tag = go_verge_ads_canonical_loader_tag();
	if ( '' === $tag ) {
		return;
	}
	$GLOBALS['go_verge_ads_loader_claimed'] = true;

	/* Optional publisher hard gate. Default is off: the certified CMP/Google owns consent. */
	if ( function_exists( 'go_verge_ads_requires_theme_consent_gate' ) && go_verge_ads_requires_theme_consent_gate() ) {
		$client = trim( (string) GO_VERGE_ADSENSE_CLIENT );
		?>
		<script id="go-ads-consent-loader-gate" data-cfasync="false" data-no-optimize="1" data-no-defer="1">
		(function(w,d,c){'use strict';var loaded=false;
		function ok(){try{return w.GOAdsConsent?w.GOAdsConsent.permitted()===true:(typeof w.wp_has_consent==='function'&&w.wp_has_consent('marketing')===true);}catch(e){return false;}}
		function load(){if(loaded||!ok())return;loaded=true;if(d.querySelector('script[src*="/pagead/js/adsbygoogle.js"],script[src*="/adsbygoogle.js"]'))return;var s=d.createElement('script');s.async=true;s.crossOrigin='anonymous';s.src='https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client='+encodeURIComponent(c);(d.head||d.documentElement).appendChild(s);}
		['wp_listen_for_consent_change','wp_consent_type_defined','go:consent-change','go:ads-consent-update'].forEach(function(n){d.addEventListener(n,load);});load();if(!loaded&&d.readyState==='loading')d.addEventListener('DOMContentLoaded',load,{once:true});
		})(window,document,<?php echo wp_json_encode( $client ); ?>);
		</script>
		<?php
		return;
	}

	echo $tag . "\n"; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- escaped above.
}
add_action( 'wp_head', 'go_verge_ads_print_loader', 3 );
