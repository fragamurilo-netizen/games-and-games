<?php
/**
 * Plugin Name: GO AdSense Center
 * Plugin URI: https://gameoverdrive.com.br/
 * Description: AdSense Center único do Overdrive em modo leve: histórico, previsões, Data Lab sob demanda, Mega Relatório, otimização de RPM, auditoria de entrega e saúde dos anúncios do tema, orçamento por ciclo de pagamento, divisão 40/40/20, pagamentos, sites e políticas. Nada pesado roda em segundo plano: só 1 sincronização leve por hora.
 * Version: 3.1.2
 * Author: Game Overdrive
 * Requires at least: 6.2
 * Requires PHP: 7.4
 * Text Domain: go-adsense-center
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

// Activation can occur after the theme fallback has already booted this request.
// Reuse that engine now; the plugin owns it from the next request onward.
if ( defined( 'GOAC_VERSION' ) ) {
	register_activation_hook( __FILE__, array( 'GOAC_Plugin', 'activate' ) );
	register_deactivation_hook( __FILE__, array( 'GOAC_Plugin', 'deactivate' ) );
	return;
}

define( 'GOAC_VERSION', '3.1.2' );
define( 'GOAC_FILE', __FILE__ );
define( 'GOAC_DIR', plugin_dir_path( __FILE__ ) );
define( 'GOAC_URL', plugin_dir_url( __FILE__ ) );

require_once GOAC_DIR . 'includes/bootstrap.php';

register_activation_hook( __FILE__, array( 'GOAC_Plugin', 'activate' ) );
register_deactivation_hook( __FILE__, array( 'GOAC_Plugin', 'deactivate' ) );

goac_boot_context();
