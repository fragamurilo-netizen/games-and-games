<?php
/**
 * Native Burst accuracy mode; no extra tracker, events or counter writes.
 * Runtime-only filters: saved plugin options and privacy choices stay intact.
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_verge_burst_native_accuracy_enabled() {
	$enabled = ! defined( 'GO_VERGE_BURST_ACCURATE_TRACKING' ) || (bool) GO_VERGE_BURST_ACCURATE_TRACKING;
	return (bool) apply_filters( 'go_verge_burst_native_accuracy_enabled', $enabled );
}

/** Keep the native async header mode, not Turbo's later footer start. */
function go_verge_burst_native_accuracy_option( $value ) {
	return go_verge_burst_native_accuracy_enabled() ? false : $value;
}
add_filter( 'burst_option_enable_turbo_mode', 'go_verge_burst_native_accuracy_option', 20 );
// A generated combined file can still embed the old Turbo configuration.
add_filter( 'burst_option_combine_vars_and_script', 'go_verge_burst_native_accuracy_option', 20 );


/**
 * Burst 3.7 considers a reader "live" from the original hit timestamp plus the
 * accumulated active time. Long reads therefore need periodic time-on-page
 * updates; otherwise cohorts can disappear from the live card in one cliff.
 *
 * This calls Burst's own update routine, so it neither creates a pageview nor
 * bypasses consent/DNT. TimeMe itself ignores idle tabs after its idle timeout.
 */
function go_verge_burst_active_heartbeat_script() {
	if ( ! go_verge_burst_native_accuracy_enabled() || is_admin() ) {
		return;
	}

	$script = <<<'JS'
(function(){
	if (window.__goBurstActiveHeartbeat) return;
	var beat = function(){
		if (document.visibilityState !== 'visible' || navigator.onLine === false) return;
		if (typeof window.burst_update_hit !== 'function') return;
		try {
			var pending = window.burst_update_hit(false, false, {});
			if (pending && typeof pending.catch === 'function') pending.catch(function(){});
		} catch (e) {}
	};
	window.__goBurstActiveHeartbeat = window.setInterval(beat, 240000);
	document.addEventListener('visibilitychange', function(){
		if (document.visibilityState === 'visible') beat();
	}, {passive:true});
})();
JS;

	foreach ( array( 'burst', 'b' ) as $handle ) {
		if ( wp_script_is( $handle, 'enqueued' ) ) {
			wp_add_inline_script( $handle, $script, 'after' );
			break;
		}
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_burst_active_heartbeat_script', PHP_INT_MAX );

/** Flag a still-running Burst 3.7 visitor-ID migration without altering it. */
function go_verge_burst_accuracy_health_tests( $tests ) {
	$tests['direct']['go_verge_burst_accuracy'] = array(
		'label' => __( 'Precisão do Burst Statistics', 'go-verge' ),
		'test'  => 'go_verge_burst_accuracy_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_burst_accuracy_health_tests', 260 );

function go_verge_burst_accuracy_health_test() {
	if ( ! defined( 'BURST_VERSION' ) ) {
		return array(
			'label'       => __( 'Burst Statistics não foi detectado', 'go-verge' ),
			'status'      => 'recommended',
			'badge'       => array( 'label' => __( 'Analytics', 'go-verge' ), 'color' => 'blue' ),
			'description' => '<p>' . esc_html__( 'O modo de precisão do tema só atua quando o Burst está ativo.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_burst_accuracy',
		);
	}

	$migrating = (bool) get_option( 'burst_has_db_upgrade', false );
	return array(
		'label'       => $migrating
			? __( 'Burst ainda está migrando o banco de visitantes', 'go-verge' )
			: __( 'Burst está com o modo de precisão do Overdrive ativo', 'go-verge' ),
		'status'      => $migrating ? 'recommended' : 'good',
		'badge'       => array( 'label' => __( 'Analytics', 'go-verge' ), 'color' => $migrating ? 'orange' : 'blue' ),
		'description' => '<p>' . esc_html(
			$migrating
				? __( 'A migração de IDs da versão 3.7 ainda está pendente; visitantes únicos históricos podem aparecer abaixo do real até o backfill terminar. O tracking atual continua ativo.', 'go-verge' )
				: __( 'O script nativo permanece sem Turbo/arquivo combinado e leitores ativos enviam atualização periódica de tempo a cada 4 minutos sem criar pageviews extras.', 'go-verge' )
		) . '</p>',
		'test'        => 'go_verge_burst_accuracy',
	);
}
