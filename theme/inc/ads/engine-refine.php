<?php
/**
 * "Refinar com os números de hoje" — one bounded engine step from today's data.
 *
 * WHAT IT COMPARES
 * The last hour of today against the SAME hour on comparable past days (same
 * weekday first; inc/ads/economics.php, go_verge_ads_econ_peers). Never against
 * this morning: Page RPM falls through the day on this site whatever the engine
 * does (lower-value evening traffic, advertiser budgets spent early), so "it
 * started at 2,70 and is at 2,40" says nothing by itself. "The 17h hour is 12%
 * below a normal 17h" does.
 *
 * WHAT IT MAY DO — one step per click, in one of two directions, both taken from
 * cases this account already lived through (theme 3.53 notes):
 *
 *   less density   impression value down while impressions/page are up.
 *                  11/08: +18% impressions/page, -15% impression RPM, -5 pts
 *                  Active View, page RPM flat — the extra impressions paid
 *                  nothing. Step: +60 px spacing, -0.03 article ratio, -10% lead.
 *   more supply    impressions/page down while impression value holds.
 *                  26/08: 3,88 imp/page at 58% Active View, US$ 2,11 page RPM —
 *                  inventory requested too late to exist. Step: -60 px spacing,
 *                  +0.03 article ratio, +10% lead.
 *
 * WHAT IT REFUSES
 *   - price AND volume down together: the market moved, not the engine;
 *   - Google declining requests (low coverage): density does not fix fill;
 *   - stale data, too few page views, no same-hour history, a click within the
 *     cooldown (a change needs about an hour of new page views to show), or the
 *     daily maximum of refinements already used.
 *
 * Every applied step is saved through go_verge_ads_engine_save(): it is recorded
 * with the numbers that justified it, can be undone, and purges the page cache.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Limits the refine button keeps to, inside the absolute setting bounds. */
function go_verge_ads_engine_refine_limits() {
	return (array) apply_filters(
		'go_verge_ads_engine_refine_limits',
		array(
			'min_gap_mobile'     => array( 240, 600 ),
			'min_gap_desktop'    => array( 300, 700 ),
			'article_ratio'      => array( 0.25, 0.40 ),
			'lead_scale_mobile'  => array( 0.70, 1.30 ),
			'lead_scale_desktop' => array( 0.70, 1.30 ),
			/* Last-hour RPM within this share of a normal hour is left alone. */
			'hold_band'          => 0.97,
			'min_window_page_views' => 150,
			'max_freshness_min'  => 60,
		)
	);
}

/**
 * Context the decision needs beyond the day state.
 *
 * @return array<string,mixed>
 */
function go_verge_ads_engine_refine_context() {
	$context = array( 'now' => time(), 'last_refine_at' => null, 'refines_today' => 0, 'viewability_today' => null, 'viewability_yesterday' => null );
	$today = function_exists( 'go_verge_ads_trial_today' ) ? go_verge_ads_trial_today() : gmdate( 'Y-m-d' );
	if ( class_exists( 'GOAC_API' ) && method_exists( 'GOAC_API', 'today' ) ) {
		$today = GOAC_API::today();
	}
	foreach ( go_verge_ads_engine_history() as $entry ) {
		if ( 'refine' !== ( $entry['source'] ?? '' ) ) {
			continue;
		}
		$at = (int) ( $entry['at'] ?? 0 );
		if ( null === $context['last_refine_at'] ) {
			$context['last_refine_at'] = $at;
		}
		if ( wp_date( 'Y-m-d', $at ) === $today ) {
			$context['refines_today']++;
		}
	}
	if ( class_exists( 'GOAC_Store' ) && method_exists( 'GOAC_Store', 'range' ) ) {
		try {
			$yesterday = ( new DateTimeImmutable( $today . ' 12:00:00' ) )->modify( '-1 day' )->format( 'Y-m-d' );
			$rows = GOAC_Store::range( $yesterday, $today );
			foreach ( array( 'viewability_today' => $today, 'viewability_yesterday' => $yesterday ) as $key => $date ) {
				$value = $rows[ $date ]['viewability'] ?? null;
				if ( is_numeric( $value ) && $value > 0 && $value <= 1 ) {
					$context[ $key ] = (float) $value;
				}
			}
		} catch ( Exception $e ) {
			/* Active View is a tie-breaker only; its absence never blocks. */
		}
	}
	return $context;
}

/**
 * Pure decision: day state + settings + context -> what to do.
 *
 * @param array<string,mixed> $state    go_verge_ads_econ_day_state().
 * @param array<string,mixed> $settings Current engine settings.
 * @param array<string,mixed> $context  go_verge_ads_engine_refine_context().
 * @return array<string,mixed>
 */
function go_verge_ads_engine_refine_decide( array $state, array $settings, array $context ) {
	$limits = go_verge_ads_engine_refine_limits();
	$out = array( 'status' => 'blocked', 'action' => 'none', 'headline' => '', 'reasons' => array(), 'metrics' => array(), 'next' => $settings, 'changes' => array() );

	$day    = (array) ( $state['day'] ?? array() );
	$window = is_array( $state['window'] ?? null ) ? $state['window'] : null;
	$peers  = is_array( $state['peers'] ?? null ) ? $state['peers'] : null;
	$view   = $context['viewability_today'] ?? $context['viewability_yesterday'] ?? null;
	$cover  = isset( $day['coverage'] ) && is_numeric( $day['coverage'] ) ? (float) $day['coverage'] : null;

	$out['metrics'] = array(
		'day_page_views'      => (int) round( (float) ( $day['page_views'] ?? 0 ) ),
		'day_page_rpm'        => round( (float) ( $day['page_rpm'] ?? 0 ), 3 ),
		'day_impression_rpm'  => round( (float) ( $day['impression_rpm'] ?? 0 ), 3 ),
		'day_impressions_pv'  => round( (float) ( $day['impressions_pv'] ?? 0 ), 2 ),
		'coverage'            => null === $cover ? null : round( $cover, 4 ),
		'viewability'         => null === $view ? null : round( (float) $view, 4 ),
		'freshness_min'       => $state['freshness_min'] ?? null,
		'hour_page_views'     => $window ? (int) round( (float) ( $window['page_views'] ?? 0 ) ) : null,
		'hour_page_rpm'       => $window && isset( $window['page_rpm'] ) ? round( (float) $window['page_rpm'], 3 ) : null,
		'hour_impression_rpm' => $window && isset( $window['impression_rpm'] ) ? round( (float) $window['impression_rpm'], 3 ) : null,
		'hour_impressions_pv' => $window && isset( $window['impressions_pv'] ) ? round( (float) $window['impressions_pv'], 2 ) : null,
		'normal_page_rpm'     => $peers ? round( (float) $peers['page_rpm'], 3 ) : null,
		'normal_impression_rpm' => $peers ? round( (float) $peers['impression_rpm'], 3 ) : null,
		'normal_impressions_pv' => $peers ? round( (float) $peers['impressions_pv'], 2 ) : null,
		'normal_days'         => $peers ? (int) $peers['count'] : 0,
		'projection_page_rpm' => $state['projection']['page_rpm'] ?? null,
	);

	/* ---- guards ---------------------------------------------------------- */
	if ( empty( $state['available'] ) ) {
		$out['headline'] = 'Sem números de hoje no Ads Center.';
		$out['reasons'][] = 'Confira se a conta está conectada e a sincronização de 15 minutos está rodando.';
		return $out;
	}
	if ( null !== ( $state['freshness_min'] ?? null ) && (int) $state['freshness_min'] > (int) $limits['max_freshness_min'] ) {
		$out['headline'] = 'Os números de hoje estão desatualizados.';
		$out['reasons'][] = sprintf( 'Último dado recebido há %d min; o refino só usa dados com até %d min.', (int) $state['freshness_min'], (int) $limits['max_freshness_min'] );
		return $out;
	}
	if ( (float) ( $day['page_views'] ?? 0 ) < (float) $settings['refine_min_page_views'] ) {
		$out['headline'] = 'Ainda há poucas visitas hoje para decidir.';
		$out['reasons'][] = sprintf( '%s pageviews até agora; o mínimo configurado é %s.', number_format_i18n( (float) ( $day['page_views'] ?? 0 ) ), number_format_i18n( (float) $settings['refine_min_page_views'] ) );
		return $out;
	}
	if ( ! $window || empty( $window['price_signal_usable'] ) || (float) ( $window['page_views'] ?? 0 ) < (float) $limits['min_window_page_views'] ) {
		$out['headline'] = 'A última hora ainda não tem sinal utilizável.';
		$out['reasons'][] = 'É preciso pelo menos ' . (int) $limits['min_window_page_views'] . ' pageviews na última hora, sem revisão do AdSense no intervalo.';
		return $out;
	}
	if ( ! $peers || (int) ( $peers['count'] ?? 0 ) < 3 || (float) $peers['page_rpm'] <= 0 || (float) $peers['impression_rpm'] <= 0 || (float) $peers['impressions_pv'] <= 0 ) {
		$out['headline'] = 'Falta histórico da mesma hora para comparar.';
		$out['reasons'][] = 'São necessários pelo menos 3 dias recentes com dados deste horário no Ads Center.';
		return $out;
	}
	$last = $context['last_refine_at'] ?? null;
	$cooldown = (int) $settings['refine_cooldown_min'] * 60;
	if ( $last && ( (int) $context['now'] - (int) $last ) < $cooldown ) {
		$out['headline'] = 'O último refino ainda está fazendo efeito.';
		$out['reasons'][] = sprintf( 'Último refino há %d min; o intervalo mínimo é %d min, o tempo para a última hora refletir a mudança.', (int) floor( ( (int) $context['now'] - (int) $last ) / 60 ), (int) $settings['refine_cooldown_min'] );
		return $out;
	}
	if ( (int) ( $context['refines_today'] ?? 0 ) >= (int) $settings['refine_max_per_day'] ) {
		$out['headline'] = 'Limite de refinos de hoje atingido.';
		$out['reasons'][] = sprintf( '%d refinos hoje; o máximo configurado é %d. Ajustes manuais continuam liberados.', (int) $context['refines_today'], (int) $settings['refine_max_per_day'] );
		return $out;
	}

	/* ---- signals: last hour against a normal hour ------------------------ */
	$r_rpm  = (float) $window['page_rpm'] / (float) $peers['page_rpm'];
	$r_irpm = (float) $window['impression_rpm'] / (float) $peers['impression_rpm'];
	$r_vol  = (float) $window['impressions_pv'] / (float) $peers['impressions_pv'];
	$out['metrics']['ratio_page_rpm']       = round( $r_rpm, 3 );
	$out['metrics']['ratio_impression_rpm'] = round( $r_irpm, 3 );
	$out['metrics']['ratio_impressions_pv'] = round( $r_vol, 3 );
	$pct = static function ( $ratio ) {
		$delta = ( $ratio - 1 ) * 100;
		return ( $delta >= 0 ? '+' : '' ) . number_format_i18n( $delta, 0 ) . '%';
	};
	$summary = sprintf( 'Última hora contra o normal deste horário (%d dias): RPM %s, valor por impressão %s, impressões por página %s.', (int) $peers['count'], $pct( $r_rpm ), $pct( $r_irpm ), $pct( $r_vol ) );
	$out['reasons'][] = $summary;
	$out['status'] = 'hold';

	$action = 'hold';
	if ( $r_rpm >= (float) $limits['hold_band'] ) {
		$out['headline'] = 'RPM dentro do normal para este horário. Nada a corrigir.';
	} elseif ( null !== $cover && $cover < 0.75 ) {
		$out['headline'] = 'O Google está recusando pedidos. Densidade não resolve isso.';
		$out['reasons'][] = sprintf( 'Cobertura de hoje em %s%%. Com cobertura baixa, mudar a quantidade de anúncios não recupera receita; verifique bloqueios e o relatório por formato.', number_format_i18n( $cover * 100, 1 ) );
	} elseif ( $r_irpm < 0.88 && $r_vol > 1.03 ) {
		$action = 'density_down';
		$out['headline'] = 'Mais impressões valendo menos: reduzir densidade.';
		$out['reasons'][] = 'Mesmo padrão de 11/08: impressões extras sem receita diluem o valor de todas as outras.';
	} elseif ( $r_vol < 0.92 && $r_irpm >= 0.92 ) {
		$action = 'supply_up';
		$out['headline'] = 'Preço normal, volume curto: abrir mais oferta.';
		$out['reasons'][] = 'Mesmo padrão de 26/08: anúncios pedidos tarde demais deixam de existir.';
	} elseif ( $r_irpm < 0.88 ) {
		$out['headline'] = 'O preço caiu no mercado, não no motor. Mantido.';
		$out['reasons'][] = 'Valor por impressão e volume caíram juntos. Mexer na quantidade de anúncios agora compraria impressões mais baratas.';
	} elseif ( null !== $view && $view > 0.58 && $r_vol < 1.0 ) {
		$action = 'supply_up';
		$out['headline'] = 'Active View acima da faixa e volume abaixo do normal: abrir oferta.';
		$out['reasons'][] = sprintf( 'Active View em %s%%; acima de ~58%% este site historicamente perde volume (26/08).', number_format_i18n( $view * 100, 1 ) );
	} elseif ( null !== $view && $view < 0.46 && $r_vol > 1.0 ) {
		$action = 'density_down';
		$out['headline'] = 'Active View baixo com volume alto: reduzir densidade.';
		$out['reasons'][] = sprintf( 'Active View em %s%% com mais impressões por página que o normal.', number_format_i18n( $view * 100, 1 ) );
	} else {
		$out['headline'] = 'Queda pequena, sem padrão claro. Mantido.';
		$out['reasons'][] = 'Nenhum dos padrões conhecidos se aplica; um ajuste agora seria no escuro.';
	}

	if ( 'hold' === $action ) {
		$out['action'] = 'hold';
		return $out;
	}

	/* ---- one bounded step ------------------------------------------------ */
	$next = $settings;
	$sign = 'supply_up' === $action ? -1 : 1;
	$step = static function ( $key, $delta ) use ( &$next, $limits ) {
		$range = $limits[ $key ];
		$next[ $key ] = max( $range[0], min( $range[1], $next[ $key ] + $delta ) );
	};
	$step( 'min_gap_mobile', 60 * $sign );
	$step( 'min_gap_desktop', 60 * $sign );
	$step( 'article_ratio', -0.03 * $sign );
	$step( 'lead_scale_mobile', -0.10 * $sign );
	$step( 'lead_scale_desktop', -0.10 * $sign );
	$next['article_ratio']      = round( $next['article_ratio'], 2 );
	$next['lead_scale_mobile']  = round( $next['lead_scale_mobile'], 2 );
	$next['lead_scale_desktop'] = round( $next['lead_scale_desktop'], 2 );

	$changes = go_verge_ads_engine_diff( $settings, go_verge_ads_engine_sanitize( $next ) );
	if ( ! $changes ) {
		$out['action'] = 'hold';
		$out['headline'] .= ' O motor já está no limite desta direção.';
		return $out;
	}
	$out['status']  = 'apply';
	$out['action']  = $action;
	$out['next']    = $next;
	$out['changes'] = $changes;
	return $out;
}

/**
 * Run the decision on live data and, when it says so, apply it.
 *
 * @param bool $apply False only previews.
 * @return array<string,mixed> The decision, plus `applied` => bool.
 */
function go_verge_ads_engine_refine_run( $apply = true ) {
	$state = function_exists( 'go_verge_ads_econ_day_state' ) ? go_verge_ads_econ_day_state( true ) : array();
	$decision = go_verge_ads_engine_refine_decide( (array) $state, go_verge_ads_engine_settings(), go_verge_ads_engine_refine_context() );
	$decision['applied'] = false;
	if ( $apply && 'apply' === $decision['status'] ) {
		$decision['changes'] = go_verge_ads_engine_save( $decision['next'], 'refine', $decision['headline'], array( 'metrics' => $decision['metrics'], 'reasons' => $decision['reasons'], 'action' => $decision['action'] ) );
		$decision['applied'] = ! empty( $decision['changes'] );
	}
	return $decision;
}
