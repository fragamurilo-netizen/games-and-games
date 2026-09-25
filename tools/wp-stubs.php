<?php
/**
 * Minimal WordPress stubs so the theme's pure ad modules (config, planner,
 * renderer, composer) can run from the CLI. Only what those files touch.
 */
define( 'ABSPATH', __DIR__ . '/' );
if ( ! defined( 'DAY_IN_SECONDS' ) ) { define( 'DAY_IN_SECONDS', 86400 ); }
if ( ! defined( 'MINUTE_IN_SECONDS' ) ) { define( 'MINUTE_IN_SECONDS', 60 ); }
if ( ! defined( 'HOUR_IN_SECONDS' ) ) { define( 'HOUR_IN_SECONDS', 3600 ); }
$GLOBALS['__stub_filters'] = array();
$GLOBALS['__stub_ctx'] = array( 'context' => 'single_post', 'singular' => 'post', 'page_slug' => '' );
function add_filter( $hook, $cb, $prio = 10, $args = 1 ) { $GLOBALS['__stub_filters'][ $hook ][] = array( $cb, $args ); return true; }
function add_action( $hook, $cb, $prio = 10, $args = 1 ) { return add_filter( $hook, $cb, $prio, $args ); }
function has_filter( $hook ) { return ! empty( $GLOBALS['__stub_filters'][ $hook ] ); }
function apply_filters( $hook, $value, ...$rest ) {
	foreach ( $GLOBALS['__stub_filters'][ $hook ] ?? array() as $f ) { $value = call_user_func_array( $f[0], array_slice( array_merge( array( $value ), $rest ), 0, max( 1, $f[1] ) ) ); }
	return $value;
}
function do_action( $hook, ...$args ) { foreach ( $GLOBALS['__stub_filters'][ $hook ] ?? array() as $f ) { call_user_func_array( $f[0], array_slice( $args, 0, $f[1] ) ); } }
function sanitize_key( $k ) { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $k ) ); }
function sanitize_html_class( $c ) { return preg_replace( '/[^A-Za-z0-9_-]/', '', (string) $c ); }
function sanitize_text_field( $s ) { return trim( strip_tags( (string) $s ) ); }
function absint( $n ) { return abs( (int) $n ); }
function esc_attr( $s ) { return htmlspecialchars( (string) $s, ENT_QUOTES, 'UTF-8' ); }
function esc_html( $s ) { return htmlspecialchars( (string) $s, ENT_QUOTES, 'UTF-8' ); }
function esc_url( $s ) { return (string) $s; }
function esc_attr__( $s ) { return esc_attr( $s ); }
function esc_html__( $s ) { return esc_html( $s ); }
function __( $s ) { return $s; }
function wp_json_encode( $v, $f = 0 ) { return json_encode( $v, $f ); }
function wp_parse_args( $a, $d ) { return array_merge( $d, (array) $a ); }
function get_option( $k, $d = false ) { return $d; }
function get_transient( $k ) { return false; }
function set_transient() { return true; }
function delete_transient() { return true; }
function is_admin() { return false; }
function is_feed() { return false; }
function is_404() { return false; }
function is_preview() { return false; }
function wp_doing_ajax() { return false; }
function is_user_logged_in() { return false; }
function current_user_can() { return false; }
function post_password_required() { return false; }
function is_privacy_policy() { return false; }
function is_front_page() { return 'home' === $GLOBALS['__stub_ctx']['context']; }
function is_home() { return false; }
function is_singular( $type = '' ) { $s = $GLOBALS['__stub_ctx']['singular']; return '' === $type ? '' !== $s : $s === $type; }
function is_page( $slug = '' ) { return 'editorial_page' === $GLOBALS['__stub_ctx']['context'] && ( '' === $slug || in_array( $GLOBALS['__stub_ctx']['page_slug'], (array) $slug, true ) ); }
function is_page_template() { return false; }
function is_search() { return 'search' === $GLOBALS['__stub_ctx']['context']; }
function is_author() { return 'author' === $GLOBALS['__stub_ctx']['context']; }
function is_tag() { return 'tag' === $GLOBALS['__stub_ctx']['context']; }
function is_category( $s = '' ) { return 'category' === $GLOBALS['__stub_ctx']['context'] && '' === $s; }
function is_archive() { return in_array( $GLOBALS['__stub_ctx']['context'], array( 'category', 'tag', 'author' ), true ); }
function is_post_type_archive() { return false; }
function get_queried_object_id() { return 1; }
function get_post_field() { return $GLOBALS['__stub_ctx']['page_slug']; }
function get_the_ID() { return 1; }
function get_query_var() { return 1; }
function is_readable_stub() { return true; }
function error_log_stub() {}
