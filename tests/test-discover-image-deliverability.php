<?php
/**
 * One answer to "can Google fetch this article's image?".
 *
 * Before this contract the three consumers disagreed: og:image refused AVIF,
 * Article.image accepted it, and the Site Health readiness signal only measured
 * pixels. On a server that answers `.avif` with `Content-Type: text/plain` the
 * result was an article with no share image, a schema image Google drops, and a
 * green dashboard.
 */
if ( 'cli' !== PHP_SAPI ) { exit; }
require_once __DIR__ . '/bootstrap.php';
require_once GO_VERGE_DIR . '/inc/image-deliverability.php';

if ( ! function_exists( 'wp_parse_url' ) ) {
	function wp_parse_url( $url, $component = -1 ) {
		return parse_url( (string) $url, $component ); // phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
	}
}

/* The og:image policy, lifted from inc/rank-math-compat.php. It stays narrower
 * than the schema policy on purpose — a format can be a valid Google Images
 * input and a poor social card. What the two may not disagree about is whether
 * the file ARRIVES. */
function go_verge_og_image_format_supported( $url ) {
	$path = (string) wp_parse_url( (string) $url, PHP_URL_PATH );
	$ext  = strtolower( (string) pathinfo( $path, PATHINFO_EXTENSION ) );
	if ( '' === $ext ) {
		return false;
	}
	if ( ! go_verge_image_format_deliverable( $url ) ) {
		return false;
	}
	$blocked = (array) apply_filters( 'go_verge_og_image_blocked_formats', array( 'avif', 'jxl', 'heic', 'heif' ) );
	return ! in_array( $ext, $blocked, true );
}

/* The schema policy, lifted from inc/seo.php after the fix. */
function go_verge_schema_image_format_supported( $url ) {
	$path = (string) wp_parse_url( (string) $url, PHP_URL_PATH );
	$ext  = strtolower( (string) pathinfo( $path, PATHINFO_EXTENSION ) );
	if ( ! in_array( $ext, array( 'bmp', 'gif', 'jpg', 'jpeg', 'png', 'webp', 'svg', 'avif' ), true ) ) {
		return false;
	}
	return go_verge_image_format_deliverable( $url );
}

$base = 'https://gameoverdrive.com.br/wp-content/uploads/2026/09/capa';

go_test_section( 'Formats this server delivers correctly' );
foreach ( array( 'jpg', 'jpeg', 'png', 'webp', 'gif' ) as $ext ) {
	go_test_ok( go_verge_image_format_deliverable( $base . '.' . $ext ), strtoupper( $ext ) . ' is deliverable' );
	go_test_ok( go_verge_schema_image_format_supported( $base . '.' . $ext ), strtoupper( $ext ) . ' is a valid schema image' );
}

go_test_section( 'Formats this server breaks, or Google will not use as a preview' );
foreach ( array( 'avif', 'avifs', 'jxl', 'heic', 'heif', 'svg', 'svgz', 'tif', 'tiff' ) as $ext ) {
	go_test_equals( false, go_verge_image_format_deliverable( $base . '.' . $ext ), strtoupper( $ext ) . ' is not deliverable' );
	go_test_equals( false, go_verge_schema_image_format_supported( $base . '.' . $ext ), strtoupper( $ext ) . ' never becomes Article.image' );
}

go_test_section( 'An article is never left with a share image and no schema image, or the reverse' );
foreach ( array( 'jpg', 'png', 'webp', 'gif', 'avif', 'svg', 'heic', 'bmp', 'tiff' ) as $ext ) {
	$url = $base . '.' . $ext;
	$og  = go_verge_og_image_format_supported( $url );
	$schema = go_verge_schema_image_format_supported( $url );
	/* The schema list is broader by design (BMP is a valid Google Images input
	 * and a poor social card), so schema may accept what og:image rejects. The
	 * forbidden direction is og:image naming a file the schema chain has already
	 * judged undeliverable: that is the state where the story ships a preview
	 * Google cannot fetch. */
	go_test_ok( ! $og || go_verge_image_format_deliverable( $url ), strtoupper( $ext ) . ': og:image never names an undeliverable file' );
	go_test_ok( ! $og || $schema, strtoupper( $ext ) . ': a share image always has a matching schema image' );
}

go_test_section( 'A fixed server re-enables everything with one filter' );
add_filter( 'go_verge_allow_avif_uploads', static function () { return true; } );
go_test_ok( go_verge_image_format_deliverable( $base . '.avif' ), 'AVIF becomes deliverable once the host serves image/avif' );
go_test_ok( go_verge_schema_image_format_supported( $base . '.avif' ), 'AVIF becomes a valid schema image again' );
go_test_equals( false, go_verge_image_format_deliverable( $base . '.svg' ), 'SVG stays excluded: it is not a preview asset at all' );

go_test_section( 'Edge cases' );
go_test_equals( false, go_verge_image_format_deliverable( '' ), 'An empty URL is not deliverable' );
go_test_equals( false, go_verge_image_format_deliverable( 'https://gameoverdrive.com.br/sem-extensao' ), 'A URL with no extension is not deliverable' );
go_test_ok( go_verge_image_format_deliverable( $base . '.JPG' ), 'Extension matching is case-insensitive' );
go_test_ok( go_verge_image_format_deliverable( $base . '.jpg?v=3' ), 'A cache-busting query string does not hide the extension' );
