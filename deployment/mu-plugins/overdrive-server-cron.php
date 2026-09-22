<?php
/**
 * Plugin Name: Overdrive Server Cron
 * Description: Serializes the server cron; visitor fallback resumes if its heartbeat expires.
 * Version: 1.0.0
 */
if ( 'cli' === PHP_SAPI && ! defined( 'ABSPATH' ) ) {
    $root = dirname( __DIR__, 2 );
    if ( ! is_file( $root . '/wp-cron.php' ) || ! is_file( $root . '/wp-load.php' ) ) { fwrite( STDERR, "WordPress root unavailable.\n" ); exit( 1 ); }
    $lock = fopen( sys_get_temp_dir() . '/overdrive-cron-' . md5( $root ) . '.lock', 'c' );
    if ( ! $lock || ! flock( $lock, LOCK_EX | LOCK_NB ) ) { exit( 0 ); }
    @ini_set( 'memory_limit', '512M' );
    register_shutdown_function( static function() use ( $lock ) {
        $error = error_get_last();
        $fatal = $error && in_array( $error['type'], array( E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR, E_USER_ERROR ), true );
        if ( ! $fatal && function_exists( 'update_option' ) ) {
            update_option( 'overdrive_server_cron_heartbeat', time(), false );
            echo 'Overdrive cron completed: ' . gmdate( 'c' ) . '; PHP ' . PHP_VERSION . '; peak memory ' . round( memory_get_peak_usage( true ) / 1048576 ) . " MB\n";
        }
        flock( $lock, LOCK_UN ); fclose( $lock );
    } );
    require $root . '/wp-cron.php';
    exit( 0 );
}
if ( ! defined( 'ABSPATH' ) ) { exit; }
// Never disable visit-triggered cron until a real server run has succeeded in loading WordPress.
$overdrive_cron_heartbeat = (int) get_option( 'overdrive_server_cron_heartbeat', 0 );
if ( $overdrive_cron_heartbeat > time() - 600 && ! defined( 'DISABLE_WP_CRON' ) ) { define( 'DISABLE_WP_CRON', true ); }
unset( $overdrive_cron_heartbeat );
