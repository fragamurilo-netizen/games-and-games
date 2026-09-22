<?php
/** Cosmetic cleanup must preserve editorial bytes when PCRE fails. No network. */
if ( 'cli' !== PHP_SAPI ) { http_response_code( 403 ); exit; }
$theme = isset( $argv[1] ) ? rtrim( $argv[1], '/' ) : dirname( __DIR__ );
define( 'ABSPATH', $theme . '/' );
$GLOBALS['cleanup_context'] = array( 'admin' => false, 'singular' => true );
$GLOBALS['cleanup_hooks'] = array();
function add_filter( $hook, $callback, $priority = 10 ) { $GLOBALS['cleanup_hooks'][ $hook ][ $callback ] = $priority; }
function add_action() {}
function is_admin() { return $GLOBALS['cleanup_context']['admin']; }
function is_singular() { return $GLOBALS['cleanup_context']['singular']; }
require $theme . '/inc/single-clean.php';
$checks = array();
function check_cleanup( $name, $value, $expected ) {
	$GLOBALS['checks'][] = array( 'name' => $name, 'pass' => $value === $expected );
}
function clean_fixture( $value ) { return go_verge_single_clean_strip_leading_newline_artifacts( $value ); }
$prose = '<p>Texto editorial válido.</p><h2>Próximo assunto</h2><p>Fim.</p>';
check_cleanup( 'normal prose unchanged', clean_fixture( $prose ), $prose );
check_cleanup( 'empty string unchanged', clean_fixture( '' ), '' );
check_cleanup( 'non-string unchanged', clean_fixture( null ), null );
check_cleanup( 'BOM prefix removed', clean_fixture( "\xEF\xBB\xBF" . $prose ), $prose );
foreach ( array( '\\n', '/n', '&#92;n', '&#00092; n', '&bsol;n' ) as $token ) {
	check_cleanup( 'raw artifact ' . $token, clean_fixture( " \n" . $token . ' ' . $token . ' ' . $prose ), $prose );
	check_cleanup( 'artifact paragraph ' . $token, clean_fixture( '<p class="legacy">' . $token . '<br />&nbsp;' . $token . '</p>' . $prose ), $prose );
}
check_cleanup( 'multiple artifact paragraphs removed', clean_fixture( '<p>/n</p> <p>\\n</p>' . $prose ), $prose );
check_cleanup( 'real prose starting with artifact preserved', clean_fixture( '<p>/n faz parte da citação.</p>' . $prose ), '<p>/n faz parte da citação.</p>' . $prose );
check_cleanup( 'interior literal retained', clean_fixture( $prose . '<p>\\n</p>' ), $prose . '<p>\\n</p>' );
check_cleanup( 'pre/code retained', clean_fixture( '<pre><code>\\n/n</code></pre>' . $prose ), '<pre><code>\\n/n</code></pre>' . $prose );
foreach ( array( ' ', '&nbsp;', '<br>' ) as $token ) {
	$input = '<p>' . str_repeat( $token, 10000 ) . 'Texto editorial.</p>' . $prose;
	check_cleanup( 'large valid first paragraph preserved ' . $token, clean_fixture( $input ), $input );
}
$invalid = "\xEF\xBB\xBF<p>Texto\xFF inválido importado.</p>" . $prose;
check_cleanup( 'invalid UTF-8 fails open to complete original', clean_fixture( $invalid ), $invalid );
$GLOBALS['cleanup_context']['admin'] = true;
check_cleanup( 'admin bypass', clean_fixture( '/n' . $prose ), '/n' . $prose );
$GLOBALS['cleanup_context'] = array( 'admin' => false, 'singular' => false );
check_cleanup( 'non-single bypass', clean_fixture( '/n' . $prose ), '/n' . $prose );
check_cleanup( 'hook remains the_content priority 7', $GLOBALS['cleanup_hooks']['the_content']['go_verge_single_clean_strip_leading_newline_artifacts'] ?? null, 7 );
$failed = array_values( array_filter( $checks, static function ( $row ) { return ! $row['pass']; } ) );
echo json_encode( array( 'suite' => 'content-cleanup', 'total' => count( $checks ), 'passed' => count( $checks ) - count( $failed ), 'failed' => $failed, 'pcre_limit' => ini_get( 'pcre.backtrack_limit' ), 'network_requests' => 0 ), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) . "\n";
exit( $failed ? 1 : 0 );
