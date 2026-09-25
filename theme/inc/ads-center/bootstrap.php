<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }
if ( defined( 'GOAC_VERSION' ) ) { return; }
define( 'GOAC_VERSION', '3.1.2' );
define( 'GOAC_FILE', __FILE__ );
define( 'GOAC_DIR', __DIR__ . '/' );
define( 'GOAC_URL', get_template_directory_uri() . '/inc/ads-center/' );
require_once GOAC_DIR . 'includes/bootstrap.php';
goac_boot_context();
