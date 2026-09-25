<?php
/**
 * wp-admin → Motor de anúncios: live controls, the refine button, undo/reset
 * and the change history. Administrators only.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function go_verge_ads_engine_admin_menu() {
	global $menu;
	$parent = 'tools.php';
	foreach ( (array) $menu as $entry ) {
		if ( 'goac' === ( $entry[2] ?? '' ) ) {
			$parent = 'goac';
			break;
		}
	}
	add_submenu_page( $parent, 'Motor de anúncios', 'Motor de anúncios', 'manage_options', 'go-verge-ads-engine', 'go_verge_ads_engine_admin_page' );
}
add_action( 'admin_menu', 'go_verge_ads_engine_admin_menu', 99 );

/** URL of the panel, optionally with a notice key. */
function go_verge_ads_engine_admin_url( $notice = '' ) {
	$parent = 'admin.php';
	$args   = array( 'page' => 'go-verge-ads-engine' );
	if ( '' !== $notice ) {
		$args['go_engine_notice'] = $notice;
	}
	return add_query_arg( $args, admin_url( $parent ) );
}

function go_verge_ads_engine_admin_guard( $action ) {
	if ( ! current_user_can( 'manage_options' ) ) {
		wp_die( esc_html__( 'Sem permissão.', 'go-verge' ), 403 );
	}
	check_admin_referer( $action );
}

/** Remember the last refine decision for the next page view of this user. */
function go_verge_ads_engine_remember_decision( $decision ) {
	set_transient( 'go_verge_ads_engine_decision_' . get_current_user_id(), $decision, 30 * MINUTE_IN_SECONDS );
}

/* ------------------------------------------------------------ handlers */

function go_verge_ads_engine_handle_save() {
	go_verge_ads_engine_admin_guard( 'go_verge_ads_engine_save' );
	$raw = isset( $_POST['engine'] ) && is_array( $_POST['engine'] ) ? wp_unslash( $_POST['engine'] ) : array(); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput.InputNotSanitized -- sanitized by go_verge_ads_engine_sanitize().
	/* Unchecked boxes are absent from the POST body. */
	foreach ( go_verge_ads_engine_defaults() as $key => $default ) {
		if ( is_bool( $default ) && ! isset( $raw[ $key ] ) ) {
			$raw[ $key ] = false;
		}
	}
	$note = isset( $_POST['engine_note'] ) ? sanitize_text_field( wp_unslash( $_POST['engine_note'] ) ) : '';
	$diff = go_verge_ads_engine_save( $raw, 'manual', '' !== $note ? $note : 'Ajuste manual' );
	wp_safe_redirect( go_verge_ads_engine_admin_url( $diff ? 'saved' : 'unchanged' ) );
	exit;
}
add_action( 'admin_post_go_verge_ads_engine_save', 'go_verge_ads_engine_handle_save' );

function go_verge_ads_engine_handle_refine() {
	go_verge_ads_engine_admin_guard( 'go_verge_ads_engine_refine' );
	$decision = go_verge_ads_engine_refine_run( true );
	go_verge_ads_engine_remember_decision( $decision );
	wp_safe_redirect( go_verge_ads_engine_admin_url( ! empty( $decision['applied'] ) ? 'refined' : 'refine_hold' ) );
	exit;
}
add_action( 'admin_post_go_verge_ads_engine_refine', 'go_verge_ads_engine_handle_refine' );

function go_verge_ads_engine_handle_undo() {
	go_verge_ads_engine_admin_guard( 'go_verge_ads_engine_undo' );
	$history = go_verge_ads_engine_history();
	$last    = $history[0] ?? null;
	if ( ! $last || empty( $last['before'] ) ) {
		wp_safe_redirect( go_verge_ads_engine_admin_url( 'nothing_to_undo' ) );
		exit;
	}
	go_verge_ads_engine_save( $last['before'], 'undo', 'Desfeito: ' . (string) ( $last['note'] ?? '' ) );
	wp_safe_redirect( go_verge_ads_engine_admin_url( 'undone' ) );
	exit;
}
add_action( 'admin_post_go_verge_ads_engine_undo', 'go_verge_ads_engine_handle_undo' );

function go_verge_ads_engine_handle_reset() {
	go_verge_ads_engine_admin_guard( 'go_verge_ads_engine_reset' );
	go_verge_ads_engine_save( go_verge_ads_engine_defaults(), 'reset', 'Perfil 3.53 restaurado' );
	wp_safe_redirect( go_verge_ads_engine_admin_url( 'reset' ) );
	exit;
}
add_action( 'admin_post_go_verge_ads_engine_reset', 'go_verge_ads_engine_handle_reset' );

/* ------------------------------------------------------------ page */

function go_verge_ads_engine_admin_button( $action, $label, $class = 'button', $confirm = '' ) {
	echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" style="display:inline-block;margin:0 8px 8px 0">';
	echo '<input type="hidden" name="action" value="' . esc_attr( $action ) . '">';
	wp_nonce_field( $action );
	echo '<button type="submit" class="' . esc_attr( $class ) . '"' . ( $confirm ? ' onclick="return confirm(' . esc_attr( wp_json_encode( $confirm ) ) . ')"' : '' ) . '>' . esc_html( $label ) . '</button>';
	echo '</form>';
}

function go_verge_ads_engine_money( $value ) {
	return null === $value ? '—' : 'US$ ' . number_format_i18n( (float) $value, 2 );
}

function go_verge_ads_engine_labels() {
	return array(
		'body_format'           => 'Formato do corpo',
		'body_max_rung'         => 'Degraus máximos no corpo',
		'min_gap_mobile'        => 'Distância mínima entre anúncios (celular, px)',
		'min_gap_desktop'       => 'Distância mínima entre anúncios (desktop, px)',
		'article_ratio'         => 'Máximo do artigo ocupado por anúncio',
		'units_in_window'       => 'Anúncios por janela de ~2 telas',
		'stream_gap_mobile'     => 'Distância em listagens (celular, px)',
		'stream_gap_desktop'    => 'Distância em listagens (desktop, px)',
		'lead_mobile'           => 'Antecedência por nível (celular, telas)',
		'lead_desktop'          => 'Antecedência por nível (desktop, telas)',
		'lead_scale_mobile'     => 'Multiplicador de antecedência (celular)',
		'lead_scale_desktop'    => 'Multiplicador de antecedência (desktop)',
		'max_lookahead_mobile'  => 'Antecedência máxima com rolagem rápida (celular, telas)',
		'max_lookahead_desktop' => 'Antecedência máxima com rolagem rápida (desktop, telas)',
		'warmup_lookahead'      => 'Antecedência antes do leitor interagir (telas)',
		'masthead_billboard'    => 'Topo do desktop em 970×250 fixo',
		'hero_overlay'          => 'Anúncio após a imagem de capa (hero)',
		'surface_multiplex'     => 'Multiplex após a recirculação',
		'surface_post_content'  => 'Anúncios abaixo do texto (autor / antes dos comentários)',
		'surface_rail_mobile'   => 'Anúncio no trilho empilhado do celular',
		'refine_min_page_views' => 'Refino: pageviews mínimas no dia',
		'refine_cooldown_min'   => 'Refino: intervalo mínimo (min)',
		'refine_max_per_day'    => 'Refino: máximo por dia',
	);
}

function go_verge_ads_engine_admin_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$s        = go_verge_ads_engine_settings();
	$defaults = go_verge_ads_engine_defaults();
	$labels   = go_verge_ads_engine_labels();
	$tiers    = array( 'reach' => 'P1 / topo', 'premium' => 'A1–A2', 'standard' => 'A3–A4', 'deep' => 'A5–A6', 'completion' => 'Fim do artigo' );
	$notice   = isset( $_GET['go_engine_notice'] ) ? sanitize_key( wp_unslash( $_GET['go_engine_notice'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- display only.
	$messages = array(
		'saved'           => array( 'success', 'Ajustes salvos. O cache foi limpo; as próximas visitas já recebem o motor novo.' ),
		'unchanged'       => array( 'info', 'Nada mudou.' ),
		'refined'         => array( 'success', 'Refino aplicado e cache limpo. Veja abaixo o que mudou e por quê.' ),
		'refine_hold'     => array( 'info', 'O refino analisou os números e não mudou nada. Veja abaixo o motivo.' ),
		'undone'          => array( 'success', 'Última alteração desfeita. O cache foi limpo.' ),
		'nothing_to_undo' => array( 'warning', 'Não há alteração para desfazer.' ),
		'reset'           => array( 'success', 'Perfil 3.53 restaurado. O cache foi limpo.' ),
	);
	$decision = get_transient( 'go_verge_ads_engine_decision_' . get_current_user_id() );
	$state    = function_exists( 'go_verge_ads_econ_day_state' ) ? go_verge_ads_econ_day_state() : array();
	$preview  = go_verge_ads_engine_refine_decide( (array) $state, $s, go_verge_ads_engine_refine_context() );
	$m        = $preview['metrics'];

	echo '<div class="wrap"><h1>Motor de anúncios</h1>';
	echo '<p style="max-width:860px">Tudo aqui vale para o site inteiro assim que é salvo: cada alteração limpa o cache da página e fica no histórico, e qualquer uma pode ser desfeita. Os valores padrão são o perfil da versão 3.53, o motor do dia de referência (30/08: RPM US$ 4,79, RPM de impressão US$ 0,73, Active View 54,84%).</p>';
	if ( isset( $messages[ $notice ] ) ) {
		echo '<div class="notice notice-' . esc_attr( $messages[ $notice ][0] ) . ' is-dismissible"><p>' . esc_html( $messages[ $notice ][1] ) . '</p></div>';
	}

	/* ---- today ----------------------------------------------------------- */
	echo '<div style="background:#fff;border:1px solid #dcdcde;padding:16px 20px;margin:16px 0;max-width:1100px">';
	echo '<h2 style="margin-top:0">Hoje, comparado ao mesmo horário em dias parecidos</h2>';
	echo '<p style="color:#50575e;margin-top:-6px">O RPM cai ao longo do dia em qualquer versão do motor. Por isso a comparação é hora contra hora, nunca contra o começo do dia.</p>';
	echo '<table class="widefat striped" style="max-width:780px"><thead><tr><th></th><th>RPM de página</th><th>RPM de impressão</th><th>Impressões / página</th><th>Pageviews</th></tr></thead><tbody>';
	printf( '<tr><th>Última hora</th><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>', esc_html( go_verge_ads_engine_money( $m['hour_page_rpm'] ) ), esc_html( go_verge_ads_engine_money( $m['hour_impression_rpm'] ) ), esc_html( null === $m['hour_impressions_pv'] ? '—' : number_format_i18n( $m['hour_impressions_pv'], 2 ) ), esc_html( null === $m['hour_page_views'] ? '—' : number_format_i18n( $m['hour_page_views'] ) ) );
	printf( '<tr><th>Normal deste horário%s</th><td>%s</td><td>%s</td><td>%s</td><td></td></tr>', $m['normal_days'] ? ' (' . (int) $m['normal_days'] . ' dias)' : '', esc_html( go_verge_ads_engine_money( $m['normal_page_rpm'] ) ), esc_html( go_verge_ads_engine_money( $m['normal_impression_rpm'] ) ), esc_html( null === $m['normal_impressions_pv'] ? '—' : number_format_i18n( $m['normal_impressions_pv'], 2 ) ) );
	printf( '<tr><th>Dia até agora</th><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>', esc_html( go_verge_ads_engine_money( $m['day_page_rpm'] ?: null ) ), esc_html( go_verge_ads_engine_money( $m['day_impression_rpm'] ?: null ) ), esc_html( $m['day_impressions_pv'] ? number_format_i18n( $m['day_impressions_pv'], 2 ) : '—' ), esc_html( number_format_i18n( $m['day_page_views'] ) ) );
	echo '</tbody></table>';
	printf(
		'<p>Cobertura: <strong>%s</strong> · Active View: <strong>%s</strong> · Projeção do RPM do dia: <strong>%s</strong> · Dados de %s</p>',
		esc_html( null === $m['coverage'] ? '—' : number_format_i18n( $m['coverage'] * 100, 1 ) . '%' ),
		esc_html( null === $m['viewability'] ? '—' : number_format_i18n( $m['viewability'] * 100, 1 ) . '%' ),
		esc_html( go_verge_ads_engine_money( $m['projection_page_rpm'] ) ),
		esc_html( null === $m['freshness_min'] ? '—' : 'há ' . (int) $m['freshness_min'] . ' min' )
	);
	echo '<p><strong>Leitura agora:</strong> ' . esc_html( $preview['headline'] ) . '</p><ul style="list-style:disc;margin-left:20px">';
	foreach ( (array) $preview['reasons'] as $reason ) {
		echo '<li>' . esc_html( $reason ) . '</li>';
	}
	echo '</ul>';
	if ( 'apply' === $preview['status'] ) {
		echo '<p>O refino faria agora:</p><ul style="list-style:disc;margin-left:20px">';
		foreach ( $preview['changes'] as $key => $pair ) {
			echo '<li>' . esc_html( go_verge_ads_engine_change_label( $key ) . ': ' . go_verge_ads_engine_value( $pair[0] ) . ' → ' . go_verge_ads_engine_value( $pair[1] ) ) . '</li>';
		}
		echo '</ul>';
	}
	go_verge_ads_engine_admin_button( 'go_verge_ads_engine_refine', 'Refinar com os números de hoje', 'button button-primary button-hero' );
	echo '<p style="color:#50575e;max-width:860px">Um passo por clique, em uma de duas direções: menos densidade quando mais impressões estão valendo menos (padrão de 11/08) ou mais oferta quando falta volume com preço normal (padrão de 26/08). Quando preço e volume caem juntos, o problema é o mercado e nada muda. Depois de aplicar, espere cerca de uma hora: é o tempo para a última hora refletir a mudança.</p>';
	if ( is_array( $decision ) ) {
		echo '<h3>Resultado do último clique</h3><p><strong>' . esc_html( $decision['headline'] ) . '</strong></p>';
		if ( ! empty( $decision['applied'] ) ) {
			echo '<ul style="list-style:disc;margin-left:20px">';
			foreach ( (array) $decision['changes'] as $key => $pair ) {
				echo '<li>' . esc_html( go_verge_ads_engine_change_label( $key ) . ': ' . go_verge_ads_engine_value( $pair[0] ) . ' → ' . go_verge_ads_engine_value( $pair[1] ) ) . '</li>';
			}
			echo '</ul>';
		}
	}
	echo '</div>';

	/* ---- actions ----------------------------------------------------------- */
	go_verge_ads_engine_admin_button( 'go_verge_ads_engine_undo', 'Desfazer a última alteração' );
	go_verge_ads_engine_admin_button( 'go_verge_ads_engine_reset', 'Restaurar perfil 3.53', 'button', 'Voltar todos os ajustes para o perfil 3.53?' );

	/* ---- settings form ----------------------------------------------------- */
	echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" style="background:#fff;border:1px solid #dcdcde;padding:16px 20px;margin:16px 0;max-width:1100px">';
	echo '<input type="hidden" name="action" value="go_verge_ads_engine_save">';
	wp_nonce_field( 'go_verge_ads_engine_save' );
	echo '<h2 style="margin-top:0">Ajustes do motor</h2>';

	$number = static function ( $key, $step, $help = '' ) use ( $s, $defaults, $labels ) {
		$bounds = go_verge_ads_engine_bounds()[ $key ] ?? array( '', '' );
		printf(
			'<tr><th scope="row"><label for="engine-%1$s">%2$s</label></th><td><input type="number" id="engine-%1$s" name="engine[%1$s]" value="%3$s" min="%4$s" max="%5$s" step="%6$s" class="small-text"> <span style="color:#646970">padrão %7$s%8$s</span></td></tr>',
			esc_attr( $key ), esc_html( $labels[ $key ] ?? $key ), esc_attr( (string) $s[ $key ] ), esc_attr( (string) $bounds[0] ), esc_attr( (string) $bounds[1] ), esc_attr( (string) $step ),
			esc_html( (string) $defaults[ $key ] ), $help ? ' · ' . esc_html( $help ) : ''
		);
	};
	$check = static function ( $key, $help = '' ) use ( $s, $defaults, $labels ) {
		printf(
			'<tr><th scope="row">%2$s</th><td><label><input type="checkbox" name="engine[%1$s]" value="1"%3$s> ligado</label> <span style="color:#646970">padrão %4$s%5$s</span></td></tr>',
			esc_attr( $key ), esc_html( $labels[ $key ] ?? $key ), checked( ! empty( $s[ $key ] ), true, false ), $defaults[ $key ] ? 'ligado' : 'desligado', $help ? ' · ' . esc_html( $help ) : ''
		);
	};

	echo '<h3>Corpo do artigo</h3><table class="form-table" role="presentation">';
	printf(
		'<tr><th scope="row"><label for="engine-body_format">%s</label></th><td><select id="engine-body_format" name="engine[body_format]"><option value="inarticle"%s>In-article nativo (perfil 3.53)</option><option value="display"%s>Display responsivo (5.6.7)</option></select></td></tr>',
		esc_html( $labels['body_format'] ), selected( $s['body_format'], 'inarticle', false ), selected( $s['body_format'], 'display', false )
	);
	$number( 'body_max_rung', 1, 'P1 + este número de posições; 7–8 usam as unidades Display A7/A8' );
	$number( 'min_gap_mobile', 10, 'perfil 3.53: 240 nas posições principais; maior = menos anúncios' );
	$number( 'min_gap_desktop', 10 );
	$number( 'article_ratio', 0.01, '0,35 = até 35% da altura do texto' );
	$number( 'units_in_window', 1 );
	echo '</table>';

	echo '<h3>Quando pedir o anúncio (antecedência)</h3><p style="color:#50575e;max-width:860px">Quantas telas antes de o leitor chegar cada posição pede o anúncio. Mais antecedência = mais impressões e Active View menor; menos antecedência = o contrário. Pelos seus números, o ponto bom é Active View entre 50% e 55% (13/08, 19/08, 30/08).</p>';
	echo '<table class="widefat" style="max-width:780px"><thead><tr><th>Nível</th><th>Celular</th><th>Desktop</th></tr></thead><tbody>';
	foreach ( $tiers as $tier => $tier_label ) {
		printf(
			'<tr><td>%1$s</td><td><input type="number" step="0.05" min="0.3" max="2" name="engine[lead_mobile][%2$s]" value="%3$s" class="small-text"> <span style="color:#646970">%4$s</span></td><td><input type="number" step="0.05" min="0.3" max="2" name="engine[lead_desktop][%2$s]" value="%5$s" class="small-text"> <span style="color:#646970">%6$s</span></td></tr>',
			esc_html( $tier_label ), esc_attr( $tier ), esc_attr( (string) $s['lead_mobile'][ $tier ] ), esc_html( (string) $defaults['lead_mobile'][ $tier ] ), esc_attr( (string) $s['lead_desktop'][ $tier ] ), esc_html( (string) $defaults['lead_desktop'][ $tier ] )
		);
	}
	echo '</tbody></table><table class="form-table" role="presentation">';
	$number( 'lead_scale_mobile', 0.05, 'multiplica toda a coluna do celular; é o que o botão de refino move' );
	$number( 'lead_scale_desktop', 0.05 );
	$number( 'max_lookahead_mobile', 0.05 );
	$number( 'max_lookahead_desktop', 0.05 );
	$number( 'warmup_lookahead', 0.05 );
	echo '</table>';

	echo '<h3>Posições</h3><table class="form-table" role="presentation">';
	$check( 'masthead_billboard', 'em tablet vira 728×90' );
	$check( 'hero_overlay' );
	$check( 'surface_multiplex', 'pior unidade medida na 3.53: 13,96% de Active View' );
	$check( 'surface_post_content', 'Display abaixo do texto; não existia na 3.53' );
	$check( 'surface_rail_mobile', 'não existia na 3.53' );
	$number( 'stream_gap_mobile', 10 );
	$number( 'stream_gap_desktop', 10 );
	echo '</table>';

	echo '<h3>Botão de refino</h3><table class="form-table" role="presentation">';
	$number( 'refine_min_page_views', 50 );
	$number( 'refine_cooldown_min', 5 );
	$number( 'refine_max_per_day', 1 );
	echo '</table>';

	echo '<p><label>Anotação (opcional): <input type="text" name="engine_note" class="regular-text" placeholder="ex.: teste de mais antecedência no celular"></label></p>';
	submit_button( 'Salvar e aplicar (limpa o cache)' );
	echo '</form>';

	/* ---- history ----------------------------------------------------------- */
	echo '<h2>Histórico</h2><table class="widefat striped" style="max-width:1100px"><thead><tr><th>Quando</th><th>Origem</th><th>Nota</th><th>O que mudou</th></tr></thead><tbody>';
	$sources = array( 'manual' => 'Manual', 'refine' => 'Refino', 'undo' => 'Desfazer', 'reset' => 'Perfil 3.53' );
	$rows = array_slice( go_verge_ads_engine_history(), 0, 20 );
	if ( ! $rows ) {
		echo '<tr><td colspan="4">Nenhuma alteração ainda. O motor está no perfil padrão.</td></tr>';
	}
	foreach ( $rows as $row ) {
		$user = get_userdata( (int) ( $row['user'] ?? 0 ) );
		$changes = array();
		foreach ( (array) ( $row['diff'] ?? array() ) as $key => $pair ) {
			$changes[] = go_verge_ads_engine_change_label( $key ) . ': ' . go_verge_ads_engine_value( $pair[0] ) . ' → ' . go_verge_ads_engine_value( $pair[1] );
		}
		printf(
			'<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>',
			esc_html( wp_date( 'd/m H:i', (int) ( $row['at'] ?? 0 ) ) ),
			esc_html( ( $sources[ $row['source'] ?? '' ] ?? (string) ( $row['source'] ?? '' ) ) . ( $user ? ' · ' . $user->display_name : '' ) ),
			esc_html( (string) ( $row['note'] ?? '' ) ),
			$changes ? implode( '<br>', array_map( 'esc_html', $changes ) ) : '—'
		);
	}
	echo '</tbody></table></div>';
}

function go_verge_ads_engine_change_label( $key ) {
	$labels = go_verge_ads_engine_labels();
	$tiers  = array( 'reach' => 'P1/topo', 'premium' => 'A1–A2', 'standard' => 'A3–A4', 'deep' => 'A5–A6', 'completion' => 'fim do artigo' );
	if ( false !== strpos( $key, '.' ) ) {
		list( $base, $sub ) = explode( '.', $key, 2 );
		return ( $labels[ $base ] ?? $base ) . ' — ' . ( $tiers[ $sub ] ?? $sub );
	}
	return $labels[ $key ] ?? $key;
}

function go_verge_ads_engine_value( $value ) {
	if ( is_bool( $value ) ) {
		return $value ? 'ligado' : 'desligado';
	}
	if ( null === $value ) {
		return '—';
	}
	if ( 'inarticle' === $value ) {
		return 'In-article';
	}
	if ( 'display' === $value ) {
		return 'Display';
	}
	return is_float( $value ) ? number_format_i18n( $value, 2 ) : (string) $value;
}
