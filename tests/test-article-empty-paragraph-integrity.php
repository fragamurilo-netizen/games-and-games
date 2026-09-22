<?php
/** No WordPress boot, network or advertising requests. */
define( 'ABSPATH', __DIR__ . '/' );
function add_action() {}
function add_filter() {}
function add_shortcode() {}
$theme_root = isset( $argv[1] ) ? $argv[1] : dirname( __DIR__ );
require $theme_root . '/inc/template-helpers.php';
$passed = 0;
$failed = 0;
function check_cleanup( $label, $input, $expected ) {
	global $passed, $failed;
	$actual = go_verge_normalize_article_flow_markup( $input );
	if ( $actual === $expected ) { ++$passed; echo "PASS $label\n"; }
	else { ++$failed; echo "FAIL $label\n"; }
}
$normal = '<p class="wp-block-paragraph">Texto editorial <strong>preservado</strong>.</p>';
check_cleanup( 'ordinary prose byte-identical', $normal, $normal );
check_cleanup( 'remove only empty paragraphs', '<p></p>' . $normal . '<p>&nbsp; &#160; &#x00A0;<br /></p>', $normal );
check_cleanup( 'quoted greater-than attribute', '<p data-label="a > b"> </p>' . $normal, $normal );
foreach ( array( 'script', 'style', 'template', 'textarea', 'pre', 'code' ) as $tag ) {
	$island = '<' . $tag . ' data-example="x > y"><p></p><p>&nbsp;<br></p></' . $tag . '>';
	check_cleanup( "preserve $tag bytes", '<p></p>' . $island . '<p> </p>' . $normal, $island . $normal );
}
$comment = '<!-- wp:html {"example":"<p></p>"} -->';
check_cleanup( 'preserve comment bytes', '<p></p>' . $comment . '<p></p>', $comment );
$json = '<script type="application/json">{"html":"<p></p>","example":"<code>"}</script>';
check_cleanup( 'raw-text tag-like data', '<p></p>' . $json . $normal, $json . $normal );
$nested = '<template><p></p><template><p></p></template><p></p></template>';
check_cleanup( 'nested templates intact', '<p></p>' . $nested . '<p></p>', $nested );
$nested = '<pre><code><p></p></code></pre>';
check_cleanup( 'nested code intact', '<p></p>' . $nested . $normal, $nested . $normal );
foreach ( array( '<pre><p></p>', '<template><p></p>', '<script>{"x":"<p></p>"}', '<!-- <p></p>', '<pre><code></pre>' ) as $bad ) {
	check_cleanup( 'malformed protected block fails open', '<p></p>' . $bad, '<p></p>' . $bad );
}
$invalid = "<p></p><p>\xFF</p>";
check_cleanup( 'invalid UTF-8 fails open', $invalid, $invalid );
$long = '<p>' . str_repeat( ' ', 10000 ) . '</p>' . $normal;
check_cleanup( 'long blank paragraph preserves prose', $long, $normal );
echo "$passed passed, $failed failed\n";
exit( $failed ? 1 : 0 );
