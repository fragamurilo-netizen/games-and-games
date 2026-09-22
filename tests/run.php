<?php
/**
 * CLI test runner for the Overdrive revenue engine.
 *
 *     php tests/run.php
 *
 * Each PHP suite runs in its own process because the bootstrap defines
 * constants and function stubs that cannot be redefined. The browser runtime is
 * exercised separately under Node, against the shared DOM double in
 * tests/helpers/runtime-harness.js, which loads the production runtime file
 * unmodified.
 *
 * @package go-verge
 */

if ( 'cli' !== PHP_SAPI ) {
	http_response_code( 403 );
	exit;
}

$binary = escapeshellarg( PHP_BINARY );
$failed = 0;
$rule   = str_repeat( '=', 60 );

foreach ( array(
	'test-planner.php',
	'stress-planner.php',
	'fuzz-quotes-500.php',
	'fuzz-atomic-text-500.php',
	'fuzz-planner-600.php',
	'fuzz-yield-600.php',
	'planner-structure-1000.php',
	'planner-layouts-5000.php',
	'economics-regime-3000.php',
	'test-economics-contract.php',
	'test-economics-readiness.php',
	'test-manual-financial-decoupling.php',
	'test-headroom-rollback.php',
	'test-composer.php',
	'test-composer-rendered-inventory.php',
	'test-listing-fallback.php',
	'test-listing-continuation.php',
	'test-account-controls.php',
	'test-side-rails-account-mirror.php',
	'test-unified-loader.php',
	'test-topscroll-unified.php',
	'test-topscroll-baseline-admin.php',
	'test-active-view-aggregation.php',
	'test-manual-formats.php',
	'test-manual-formats-invalid.php',
	'test-yield.php',
	'test-calendar-trials.php',
	'test-daypart-delivery.php',
	'test-sitemap-indexing.php',
	'test-seo-delivery.php',
	'test-new-publication.php',
	'test-content-cleanup.php',
	'test-video-feed-cache.php',
	'test-delivery-mode.php',
	'test-manual-architecture-migration.php',
	'test-masthead-editorial.php',
	'test-article-empty-paragraph-integrity.php',
	'test-technology-channel.php',
	'static-integrity.php',
) as $suite ) {
	echo PHP_EOL . $rule . PHP_EOL . 'SUITE: ' . $suite . PHP_EOL . $rule . PHP_EOL;
	passthru( $binary . ' ' . escapeshellarg( __DIR__ . '/' . $suite ), $code );
	if ( 0 !== $code ) {
		$failed++;
	}
}

$node = trim( (string) shell_exec( 'node --version 2>&1' ) );
if ( 0 === strpos( $node, 'v' ) ) {
	putenv( 'GO_TEST_PHP=' . PHP_BINARY );
	foreach ( array(
		'loader-gate.test.js',
		'runtime.test.js',
		'runtime-manual-baseline.test.js',
		'runtime-topscroll-smart.test.js',
		'runtime-masthead-editorial.test.js',
		'runtime-audit-regressions.test.js',
		'runtime-evolution.test.js',
		'runtime-responsive-geometry.test.js',
		'runtime-viewability-proxy.test.js',
		'runtime-context-paint-gate.test.js',
		'runtime-lean-parity.test.js',
		'runtime-final-regressions.test.js',
		'runtime-governor-600.test.js',
		'runtime-density-1000.test.js',
		'runtime-viewport-700.test.js',
		'runtime-critical-release-1000.test.js',
		'runtime-sessions-1200.test.js',
	) as $suite ) {
		echo PHP_EOL . $rule . PHP_EOL . 'SUITE: ' . $suite . ' (node ' . $node . ')' . PHP_EOL . $rule . PHP_EOL;
		passthru( 'node ' . escapeshellarg( __DIR__ . '/' . $suite ), $code );
		if ( 0 !== $code ) {
			$failed++;
		}
	}
} else {
	echo PHP_EOL . 'AVISO: Node nao encontrado; a suite do runtime nao foi executada.' . PHP_EOL;
}

echo PHP_EOL . $rule . PHP_EOL;
echo 0 === $failed ? 'TODAS AS SUITES PASSARAM' : ( $failed . ' SUITE(S) COM FALHA' );
echo PHP_EOL . $rule . PHP_EOL;
exit( 0 === $failed ? 0 : 1 );
