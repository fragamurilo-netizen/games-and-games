<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }
/* Register classes without parsing analytics/admin modules on public requests. */
spl_autoload_register( static function ( $class ) {
    if ( 0 !== strpos( $class, 'GOAC_' ) || ! preg_match( '/^GOAC_[A-Za-z_]+$/', $class ) ) { return; }
    /*
     * Classes that share a file with another class.
     *
     * The autoloader derives the filename from the class name, so a class that
     * does not own its file is simply never found: the screen fatals on first
     * use. Five classes are in that position, and without this map "Meses e
     * anos", "Pagamentos", "Sites", "Unidades" and "Gestão / Configurações" all
     * break. Keep it in sync when a class moves; tests/static-integrity.php
     * fails when a GOAC_* class stops resolving.
     */
    $shared = array(
        'GOAC_View_History'  => 'goac-view-days',
        'GOAC_View_Payments' => 'goac-view-account',
        'GOAC_View_Sites'    => 'goac-view-account',
        'GOAC_View_Units'    => 'goac-view-account',
        'GOAC_View_Admin'    => 'goac-view-account',
    );
    $name = isset( $shared[ $class ] ) ? $shared[ $class ] : strtolower( str_replace( '_', '-', $class ) );
    $file = GOAC_DIR . 'includes/class-' . $name . '.php';
    if ( is_file( $file ) ) { require_once $file; }
} );
function goac_boot_context() {
    /* admin-ajax.php counts as admin: heartbeat, the theme and other plugins do
     * not need the AdSense Center parsed on every one of those requests. */
    if ( wp_doing_ajax() ) {
        $action = isset( $_REQUEST['action'] ) && is_string( $_REQUEST['action'] ) ? $_REQUEST['action'] : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended,WordPress.Security.ValidatedSanitizedInput
        if ( 0 !== strpos( $action, 'goac_' ) ) { return; }
    }
    if ( is_admin() || wp_doing_cron() || ( defined( 'WP_CLI' ) && WP_CLI ) ) {
        GOAC_Plugin::instance();
    }
}
