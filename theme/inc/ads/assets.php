<?php
/**
 * Ad presentation, connection warm-up and the manual activation runtime.
 * The canonical Google bootstrap (loader.php) serves manual inventory and eligible Auto ads.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Enqueue the ad presentation stylesheet where a unit can exist. */
function go_verge_ads_enqueue_assets() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	/* Manual inventory can exist on every monetizable template; the compact
	 * disclosure/geometry sheet is therefore loaded for the whole contract. */
	if ( ! go_verge_ads_is_monetizable_request() ) {
		return;
	}

	$css = '/assets/css/go-ads.css';
	wp_enqueue_style( 'go-verge-ads', GO_VERGE_URI . $css, array(), go_verge_asset_version( $css ) );

}
add_action( 'wp_enqueue_scripts', 'go_verge_ads_enqueue_assets', 46990 );

/**
 * Warm the provider origins on monetizable responses.
 *
 * Only the two origins needed earliest are preconnected: each speculative
 * connection costs sockets/CPU that would otherwise go to the LCP resource.
 * The creative host is DNS-warmed only.
 *
 * The connection mode must match the request that will use it, because
 * browsers keep anonymous (CORS) and credentialed sockets in separate pools:
 * adsbygoogle.js is fetched with crossorigin="anonymous", so its origin is
 * warmed anonymously; the ad request itself is a credentialed iframe
 * navigation to googleads.g.doubleclick.net, so that origin is warmed WITHOUT
 * crossorigin. Warming it anonymously (as before 3.85.17) opened a socket the
 * first ad request could not reuse.
 *
 * @param array<int,mixed> $urls          Hint URLs.
 * @param string           $relation_type Hint type.
 * @return array<int,mixed>
 */
function go_verge_ads_resource_hints( $urls, $relation_type ) {
	if ( ! function_exists( 'go_verge_ads_should_bootstrap_client' ) || ! go_verge_ads_should_bootstrap_client() ) {
		return $urls;
	}

	if ( 'preconnect' === $relation_type ) {
		$urls[] = array( 'href' => 'https://pagead2.googlesyndication.com', 'crossorigin' => 'anonymous' );
		$urls[] = array( 'href' => 'https://googleads.g.doubleclick.net' );
	} elseif ( 'dns-prefetch' === $relation_type ) {
		$urls[] = 'https://tpc.googlesyndication.com';
	}

	return $urls;
}
add_filter( 'wp_resource_hints', 'go_verge_ads_resource_hints', 20, 2 );

/**
 * The runtime file to inline: the generated production copy when it is current.
 *
 * `go-ads-runtime.min.js` is the documented source with comments and
 * indentation removed (see tests/build-runtime-min.js). It is roughly a quarter
 * smaller, and since the runtime is inlined into every HTML document that is a
 * saving on every pageview rather than once per cache lifetime.
 * `go-ads-runtime.lean.js` is that same file without the operator diagnostic
 * surface, and is what an anonymous reader receives.
 *
 * It is used ONLY when its modification time is at least as new as the source's.
 * A developer who edits the runtime and forgets to rebuild therefore ships the
 * documented file — slightly larger, always correct — instead of silently
 * serving yesterday's logic. The test suite fails on that drift as well.
 *
 * @return string Absolute path, or '' when no runtime is readable.
 */
function go_verge_ads_runtime_path() {
	$source = GO_VERGE_DIR . '/assets/js/go-ads-runtime.js';

	/*
	 * Who is reading decides which generated copy is served.
	 *
	 * inspect(), explain() and the diagnostic snapshot are about a sixth of the
	 * runtime, and an anonymous reader can never call any of them — but they
	 * were re-sent and re-parsed on every pageview anyway, inline, ahead of the
	 * body. The public copy leaves them out; a logged-in administrator still
	 * gets the full file, so nothing an operator relies on disappears from the
	 * site, only from the critical path of people who never use it.
	 *
	 * This is safe for page caches in both directions. An administrator bypasses
	 * the page cache, so the public HTML keeps the lean copy; and if a cache
	 * ever did serve one audience the other's copy, the only difference is size:
	 * both files run the identical delivery engine, generated from one source.
	 *
	 * The lean copy still answers the documented install check
	 * (`GOAdsRuntime.inspect().version`) and says where the detail went.
	 */
	$operator = function_exists( 'is_user_logged_in' ) && is_user_logged_in()
		&& function_exists( 'current_user_can' ) && current_user_can( 'manage_options' );
	$operator = (bool) apply_filters( 'go_verge_ads_serve_full_runtime', $operator );

	$built = GO_VERGE_DIR . '/assets/js/go-ads-runtime' . ( $operator ? '.min.js' : '.lean.js' );
	if ( ! is_readable( $built ) ) {
		/* A missing lean copy must never cost the operator surface AND the
		 * smaller file: fall back to the full generated copy, then to source. */
		$built = GO_VERGE_DIR . '/assets/js/go-ads-runtime.min.js';
	}
	if ( is_readable( $built ) ) {
		$built_time  = (int) @filemtime( $built );
		$source_time = is_readable( $source ) ? (int) @filemtime( $source ) : 0;
		if ( $built_time > 0 && $built_time >= $source_time ) {
			return $built;
		}
	}
	return is_readable( $source ) ? $source : '';
}

/**
 * Print the manual runtime before body parsing, inline.
 *
 * Each placement's mount call runs right after its own markup; inlining keeps
 * that call synchronous when the inline script executes normally. Optimizer
 * exclusions request the original ordering; the independent footer bootstrap
 * below recovers the engine when it did not initialize through this path.
 *
 * It stays inline rather than becoming an external file on purpose. Most of
 * this site's sessions arrive from Discover or Search and are one pageview
 * long, so an external file would trade a guaranteed extra round trip on the
 * page that matters for a cache hit on pages that often never happen — and it
 * would add a round trip for every reader. The external source is used only
 * for recovery when the inline API is missing.
 */
function go_verge_ads_print_manual_runtime() {
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return ; }
	if ( ! go_verge_ads_context_has_inventory() ) {
		return;
	}
	$path = go_verge_ads_runtime_path();
	if ( '' === $path ) {
		return;
	}
	$yield = function_exists( 'go_verge_ads_yield_config' ) ? go_verge_ads_yield_config() : array();
	/* Reuse this exact policy if the browser needs the independent footer boot. */
	$GLOBALS['go_verge_ads_runtime_yield'] = $yield;
	echo '<script id="go-ads-yield-config" data-cfasync="false" data-no-optimize="1" data-no-defer="1">window.GOAdsYieldConfig=';
	// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- config is server-owned and JSON-encoded.
	echo wp_json_encode( $yield, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT );
	echo ';</script>' . "\n";
	echo '<script id="go-ads-manual-runtime" data-cfasync="false" data-no-optimize="1" data-no-defer="1">';
	// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- local static JavaScript, no user input.
	echo file_get_contents( $path );
	echo "</script>\n";
}
add_action( 'wp_head', 'go_verge_ads_print_manual_runtime', 4 );

/**
 * Independent recovery for an absent/blocked/deferred inline manual runtime.
 *
 * The renderer deliberately keeps provider INS elements in inert templates.
 * Its mount calls only wait for go:ads-runtime-ready; they cannot load a missing
 * engine. A missing head bootstrap therefore used to leave every unit pending
 * forever even when adsbygoogle.js itself was present.
 *
 * Check actual emitted hosts at the footer, not the first generated PHP markup:
 * the composer may discard that markup or keep it in an inert listing reserve.
 * The normal head path adds no network request. Recovery loads the documented
 * source once, avoiding a stale generated copy, and delegates all mounting,
 * consent, geometry and provider requests to that same engine.
 */
function go_verge_ads_print_manual_runtime_recovery() {
	if ( ! empty( $GLOBALS['go_verge_ads_runtime_recovery_printed'] ) ) { return; }
	if ( function_exists( 'go_verge_ads_manual_delivery_enabled' ) && ! go_verge_ads_manual_delivery_enabled() ) { return; }
	if ( ! go_verge_ads_context_has_inventory() ) { return; }
	$path = GO_VERGE_DIR . '/assets/js/go-ads-runtime.js';
	if ( ! is_readable( $path ) ) { $path = go_verge_ads_runtime_path(); }
	if ( '' === $path ) { return; }
	$digest = hash_file( 'sha256', $path );
	if ( false === $digest ) { return; }
	$version = defined( 'GO_VERGE_VERSION' ) ? GO_VERGE_VERSION : 'runtime';
	$payload = array(
		'src' => GO_VERGE_URI . '/assets/js/' . basename( $path ) . '?ver=' . rawurlencode( $version . '-' . substr( $digest, 0, 16 ) ),
		'config' => isset( $GLOBALS['go_verge_ads_runtime_yield'] )
			? $GLOBALS['go_verge_ads_runtime_yield']
			: ( function_exists( 'go_verge_ads_yield_config' ) ? go_verge_ads_yield_config() : array() ),
	);
	$json = wp_json_encode( $payload, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT );
	if ( false === $json ) { return; }
	$GLOBALS['go_verge_ads_runtime_recovery_printed'] = true;
	?>
	<script id="go-ads-runtime-recovery" data-cfasync="false" data-no-optimize="1" data-no-defer="1">
	(function(w,d,p){'use strict';
	function ready(){return !!(w.GOAdsRuntime&&typeof w.GOAdsRuntime.mount==='function'&&typeof w.GOAdsRuntime.scan==='function');}
	if(ready())return;
	if(w.GOAdsRuntimeBoot&&typeof w.GOAdsRuntimeBoot.ensure==='function'){w.GOAdsRuntimeBoot.ensure();return;}
	var boot=w.GOAdsRuntimeBoot={state:'idle',attempted:false,error:null};
	function stop(){d.removeEventListener('DOMContentLoaded',ensure);d.removeEventListener('go:content-updated',ensure);}
	function settle(){if(ready()){boot.state='ready';boot.error=null;stop();w.GOAdsRuntime.scan(d);}else{boot.state='error';boot.error='runtime-did-not-initialize';stop();}}
	function ensure(){
		if(ready()){boot.state='ready';boot.error=null;stop();return;}
		if(boot.attempted||!d.querySelector('[data-go-ad-placement][data-go-ad-options]'))return;
		boot.attempted=true;
		if(w.GOAdsRuntime){boot.state='error';boot.error='runtime-api-incomplete';stop();return;}
		if(!w.GOAdsYieldConfig||typeof w.GOAdsYieldConfig!=='object'||Array.isArray(w.GOAdsYieldConfig))w.GOAdsYieldConfig=p.config;
		boot.state='loading';
		var script=d.createElement('script');script.id='go-ads-runtime-recovery-source';script.async=true;script.src=p.src;
		script.setAttribute('data-cfasync','false');script.setAttribute('data-no-optimize','1');script.setAttribute('data-no-defer','1');
		script.onload=settle;script.onerror=function(){if(ready()){settle();return;}boot.state='error';boot.error='runtime-load-failed';stop();};
		try{(d.head||d.documentElement).appendChild(script);}catch(error){if(ready()){settle();return;}boot.state='error';boot.error='runtime-append-failed';stop();}
	}
	boot.ensure=ensure;
	d.addEventListener('DOMContentLoaded',ensure,{once:true});d.addEventListener('go:content-updated',ensure);
	ensure();
	})(window,document,<?php echo $json; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- JSON_HEX encoded above. ?>);
	</script>
	<?php
}
add_action( 'wp_footer', 'go_verge_ads_print_manual_runtime_recovery', 1 );
