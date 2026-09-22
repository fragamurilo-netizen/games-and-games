<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Entrega & Saúde — ponte entre o plano de controle (este plugin) e a entrega
 * de anúncios, que pertence ao tema Overdrive (inc/ads).
 *
 * Arquitetura única: o tema é o único dono do loader, dos slots, do runtime e
 * da geometria; o plugin é o único dono de OAuth, relatórios, Data Lab e cron.
 * Esta tela lê o contrato real do tema (nunca uma cópia) e cruza cada slot com
 * as unidades da conta AdSense, para que um ID arquivado, inexistente ou
 * duplicado apareça aqui antes de virar perda de receita.
 */
final class GOAC_View_Delivery {
	const CHECKS = 'goac_delivery_checks';

	/** Contrato de entrega publicado pelo tema ativo; null quando o tema não expõe. */
	public static function theme_contract() {
		if ( ! function_exists( 'go_verge_ads_inventory' ) ) { return null; }
		$config = function_exists( 'go_verge_ads_config' ) ? (array) go_verge_ads_config() : array();
		return array(
			'version'     => (string) ( $config['version'] ?? '' ),
			'delivery_mode' => (string) ( $config['delivery_mode'] ?? 'manual_overlays' ),
			'enabled'     => ! empty( $config['enabled'] ),
			'publisher'   => (string) ( $config['publisher'] ?? '' ),
			'breakpoints' => (array) ( $config['breakpoints'] ?? array() ),
			'excluded'    => (array) ( $config['excluded_page_slugs'] ?? array() ),
			'inventory'   => (array) go_verge_ads_inventory(),
			'topscroll'   => function_exists( 'go_verge_adsense_topscroll_config' ) ? (array) go_verge_adsense_topscroll_config() : array(),
			'loader'      => function_exists( 'go_verge_ads_canonical_loader_tag' ) ? (string) go_verge_ads_canonical_loader_tag() : '',
			'gate'        => function_exists( 'go_verge_ads_requires_theme_consent_gate' ) && go_verge_ads_requires_theme_consent_gate(),
		);
	}

	/**
	 * Testes do tema que só leem configuração local (baratos, rodam a cada abertura).
	 *
	 * Estes cinco nomes não existiam em lugar nenhum do tema até a 5.0, e
	 * `health_card()` pula silenciosamente o que não é chamável — por isso o
	 * cartão "Saúde da monetização" apareceu vazio desde que foi escrito. Agora
	 * estão implementados em `inc/ads/health.php`, e
	 * `tests/static-integrity.php` falha se algum deixar de ser chamável.
	 */
	private static function local_tests() {
		return array( 'go_verge_ads_stable_inventory_health_test', 'go_verge_ads_article_root_health_test', 'go_verge_ads_open_auction_health_test', 'go_verge_ads_account_controls_health_test', 'go_verge_ads_data_lab_health_test' );
	}

	/** Testes que fazem requisição HTTP ao próprio site; executados só sob demanda. */
	private static function remote_tests() {
		return array( 'go_verge_ads_runtime_integrity_health_test', 'go_verge_ads_single_loader_health_test', 'go_verge_ads_txt_health_test' );
	}

	/** Handler admin-post: executa os testes remotos e guarda o resultado por 30 minutos. */
	public static function run_checks() {
		$results = array();
		foreach ( self::remote_tests() as $test ) {
			if ( is_callable( $test ) ) {
				$r = call_user_func( $test );
				$results[] = array( 'label' => (string) ( $r['label'] ?? $test ), 'status' => (string) ( $r['status'] ?? 'recommended' ), 'description' => (string) ( $r['description'] ?? '' ) );
			}
		}
		set_transient( self::CHECKS, array( 'at' => time(), 'results' => $results ), 30 * MINUTE_IN_SECONDS );
	}

	private static function slot_from_unit( array $unit ) {
		foreach ( array( 'name', 'reportingDimensionId' ) as $key ) {
			if ( ! empty( $unit[ $key ] ) && preg_match( '/(\d{6,})$/', (string) $unit[ $key ], $m ) ) { return $m[1]; }
		}
		return '';
	}

	private static function status_pill( $status ) {
		$map = array( 'good' => array( 'ok', 'OK' ), 'recommended' => array( 'warn', 'Atenção' ), 'critical' => array( 'bad', 'Crítico' ) );
		$p = $map[ $status ] ?? array( 'warn', $status );
		return '<span class="goac-pill ' . esc_attr( $p[0] ) . '">' . esc_html( $p[1] ) . '</span>';
	}

	public static function render() {
		$contract = self::theme_contract();
		self::revenue_split_card( $contract );
		self::architecture_card( $contract );
		self::health_card( $contract );
		self::pipeline_card();
	}

	private static function architecture_card( $contract ) {
		GOAC_UI::card_open( 'Arquitetura de entrega', '<a class="button" href="' . esc_url( admin_url( 'themes.php?page=go-verge-adsense-topscroll' ) ) . '">Top Scroll</a>' );
		if ( null === $contract ) {
			GOAC_UI::notice( 'warning', 'O tema ativo não publica o contrato de anúncios do Overdrive (<code>go_verge_ads_inventory()</code>). Os relatórios continuam funcionando, mas slots e geometria não podem ser auditados daqui.' );
			GOAC_UI::card_close();
			return;
		}
		if ( function_exists( 'go_verge_ads_delivery_mode_form' ) ) { go_verge_ads_delivery_mode_form(); }
		$units = GOAC_API::is_connected() ? GOAC_API::units() : new WP_Error( 'goac_not_connected', 'Conecte a conta para cruzar os slots com o AdSense.' );
		$by_slot = array();
		if ( ! is_wp_error( $units ) ) { foreach ( (array) $units as $unit ) { $slot = self::slot_from_unit( (array) $unit ); if ( $slot ) { $by_slot[ $slot ] = $unit; } } }
		$perf = array();
		if ( GOAC_API::is_connected() ) {
			$today = GOAC_API::today();
			$report = GOAC_API::breakdown( array( 'AD_UNIT_ID' ), GOAC_Stats::add_days( $today, -7 ), GOAC_Stats::add_days( $today, -1 ), array( 'limit' => 500, 'currency' => GOAC_UI::api_currency() ) );
			if ( ! is_wp_error( $report ) ) { foreach ( $report['rows'] as $row ) { if ( preg_match( '/(\d{6,})$/', (string) $row['dims'][0], $m ) ) { $perf[ $m[1] ] = $row; } } }
		}

		$overlays = 'manual_overlays' === (string) ( $contract['delivery_mode'] ?? '' );
		$mode_note = '<strong>Manual + sobreposições:</strong> as posições in-page são do tema. Preserve Auto Ads geral, âncora e vinheta oficiais ligados na conta; banners in-page, Encontrar mais posições, Otimizar anúncios atuais e side rails automáticos desligados. O bootstrap único atende manuais e sobreposições; esta tela não confirma os controles atuais do Google.';
		echo '<p class="goac-muted">Entrega no tema (<code>inc/ads</code>): loader único, slots, runtime e geometria. Controle neste plugin: OAuth, relatórios, Data Lab e cron. ' . $mode_note . '</p>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed markup.
		echo '<div class="goac-kpis">';
		GOAC_UI::kpi( 'Contrato do tema', $contract['version'] ?: '—', $contract['enabled'] ? 'entrega manual habilitada' : '<b>chave global desligada</b>' );
		GOAC_UI::kpi( 'Publisher', $contract['publisher'] ?: '—', $contract['gate'] ? 'hard gate de consentimento do tema ATIVO' : 'consentimento pela CMP do Google' );
		$ts = $contract['topscroll'];
		GOAC_UI::kpi( 'Top Scroll', ! empty( $ts['enabled'] ) ? 'Habilitado' : 'Desligado', esc_html( sprintf( '%d preenchimentos / 24h · 5º/6º por engajamento', (int) ( $ts['frequency_max'] ?? 0 ) ) ) );
		$bp = $contract['breakpoints'];
		GOAC_UI::kpi( 'Breakpoints', sprintf( '≤%d / ≥%d px', (int) ( $bp['mobile_max'] ?? 767 ), (int) ( $bp['desktop_min'] ?? 1101 ) ), 'mobile / desktop' );
		echo '</div>';

		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Posição</th><th>Slot</th><th>Estado</th><th>Dispositivo</th><th>Geometria</th><th>Reserva (mob/desk)</th><th>Unidade na conta</th><th class="num">Receita 7d</th><th class="num">RPM impr.</th><th class="num">Active View</th><th class="num">CTR impr.</th><th class="num">Cobertura</th></tr></thead><tbody>';
		$seen = array();
		$default_slots = function_exists( 'go_verge_ads_default_slot_ids' ) ? go_verge_ads_default_slot_ids() : array();
		foreach ( $contract['inventory'] as $key => $unit ) {
			if ( ! is_array( $unit ) ) { continue; }
			$slot = preg_replace( '/\D+/', '', (string) ( $unit['slot'] ?? '' ) );
			$enabled = ! empty( $unit['enabled'] );
			$device = ! empty( $unit['mobile_only'] ) ? 'Mobile' : ( ! empty( $unit['desktop_only'] ) ? 'Desktop' : ( ! empty( $unit['min_viewport'] ) ? 'A partir de ' . (int) $unit['min_viewport'] . 'px' : 'Todos' ) );
			if ( 'fixed' === ( $unit['sizing'] ?? '' ) ) {
				$geometry = implode( ' · ', array_map( static function( $s ) { return (int) $s[0] . '×' . (int) $s[1]; }, (array) ( $unit['fixed_sizes'] ?? array() ) ) );
			} else {
				$geometry = 'responsivo ' . (string) ( $unit['format'] ?? 'auto' ) . ( ! empty( $unit['full_width'] ) ? ' · full-width' : '' );
			}
			if ( ! empty( $unit['near_viewport'] ) ) { $geometry .= ' · +' . (int) $unit['near_viewport'] . 'px'; }
			$reserve = (array) ( $unit['reserve'] ?? array() );
			$account = '<span class="goac-pill">sem conexão</span>';
			if ( ! is_wp_error( $units ) ) {
				if ( isset( $by_slot[ $slot ] ) ) {
					$u = $by_slot[ $slot ]; $state = (string) ( $u['state'] ?? '' );
					$account = '<span class="goac-pill ' . ( 'ACTIVE' === $state ? 'ok' : ( $enabled ? 'bad' : '' ) ) . '">' . esc_html( $state ?: '—' ) . '</span> ' . esc_html( (string) ( $u['displayName'] ?? '' ) ) . ' <small class="goac-muted">' . esc_html( (string) ( $u['contentAdsSettings']['type'] ?? '' ) . ' ' . (string) ( $u['contentAdsSettings']['size'] ?? '' ) ) . '</small>';
				} else {
					$account = '<span class="goac-pill ' . ( $enabled ? 'bad' : '' ) . '">não encontrada</span>';
				}
			}
			if ( $enabled && isset( $seen[ $slot ] ) ) {
				$current_templates = array_values( array_filter( (array) ( $unit['templates'] ?? array() ) ) );
				$overlap = false;
				foreach ( (array) $seen[ $slot ] as $prior ) {
					$prior_templates = array_values( array_filter( (array) ( $prior['templates'] ?? array() ) ) );
					if ( ! $current_templates || ! $prior_templates || array_intersect( $current_templates, $prior_templates ) ) { $overlap = true; break; }
				}
				$account .= $overlap
					? ' <span class="goac-pill bad">slot reutilizado com contexto sobreposto</span>'
					: ' <span class="goac-pill ok">slot reutilizado em contextos exclusivos</span>';
			}
			if ( $enabled ) { $seen[ $slot ][] = array( 'key' => $key, 'templates' => (array) ( $unit['templates'] ?? array() ) ); }
			$row = $perf[ $slot ] ?? null;
			echo '<tr' . ( $enabled ? '' : ' class="goac-muted"' ) . '><td><strong>' . esc_html( (string) $key ) . '</strong><br><small>' . esc_html( (string) ( $unit['name'] ?? '' ) ) . '</small></td><td><code>' . esc_html( $slot ) . '</code><br><small>Padrão: ' . esc_html( $default_slots[ $key ] ?? '—' ) . '</small></td>';
			echo '<td>' . ( $enabled ? '<span class="goac-pill ok">habilitado</span>' : '<span class="goac-pill">desabilitado</span>' ) . '</td><td>' . esc_html( $device ) . '</td><td>' . esc_html( $geometry ) . '</td>';
			echo '<td>' . esc_html( (int) ( $reserve['mobile'] ?? 0 ) . ' / ' . (int) ( $reserve['desktop'] ?? 0 ) . ' px' ) . '</td><td>' . $account . '</td>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- escaped above.
			/* Click quality: a manual unit far above the in-content norm (≈0.3–0.9%)
			 * usually means taps near navigation/controls, which feeds smart pricing
			 * (lower CPC for the whole account). Diagnostic only: never a target. */
			$ctr_cell = '—';
			if ( $row && is_numeric( $row['impression_ctr'] ?? null ) ) {
				$ctr_cell = esc_html( GOAC_UI::pct( $row['impression_ctr'], 2 ) );
				if ( (float) $row['impression_ctr'] > 0.015 && (float) ( $row['impressions'] ?? 0 ) >= 500 ) {
					$ctr_cell .= ' <span class="goac-pill warn" title="CTR muito acima do normal para um bloco manual: confira espaçamento em relação a menus, botões e controles de fechar.">revisar cliques</span>';
				}
			}
			echo '<td class="num">' . esc_html( $row ? GOAC_UI::money( $row['earnings'] ) : '—' ) . '</td><td class="num">' . esc_html( $row ? GOAC_UI::money( $row['impression_rpm'] ) : '—' ) . '</td><td class="num">' . esc_html( $row ? GOAC_UI::pct( $row['viewability'] ) : '—' ) . '</td><td class="num">' . $ctr_cell . '</td><td class="num">' . esc_html( $row ? GOAC_UI::pct( $row['coverage'] ) : '—' ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- $ctr_cell escaped above.
		}
		echo '</tbody></table></div>';
		if ( is_wp_error( $units ) && GOAC_API::is_connected() ) { GOAC_UI::notice( 'warning', 'Unidades da conta indisponíveis: ' . esc_html( $units->get_error_message() ) ); }
		if ( $overlays ) {
			$sum_note = 'RPMs por unidade não devem ser somados. A contribuição de cada formato exige receita dividida pelas mesmas pageviews; confirme âncora e vinheta no relatório por formato. ';

		} else {
			$sum_note = 'Receita e RPM por unidade não somam o Page RPM: Auto Ads pode reportar fora destes slots. ';
		}
		echo '<p class="goac-muted">' . esc_html( $sum_note ) . 'Páginas sem anúncio pelo tema: ' . esc_html( implode( ', ', $contract['excluded'] ) ) . '.</p>';
		GOAC_UI::card_close();
	}

	/**
	 * Motor manual × sobreposições.
	 *
	 * O relatório por bloco de anúncio só contém unidades com slot; âncora,
	 * vinheta e qualquer Auto ad não têm bloco. Total da conta − soma dos blocos
	 * é um residual a reconciliar, sem atribuição garantida por formato. Solicitações correspondidas muito
	 * acima das impressões nessa camada são esperadas: a vinheta é pré-carregada
	 * e só conta impressão quando aparece numa navegação.
	 *
	 * @param array<string,mixed>|null $contract Contrato do tema.
	 * @return void
	 */
	private static function revenue_split_card( $contract ) {
		if ( ! GOAC_API::is_connected() || ! GOAC_Store::has_data() ) { return; }
		$today = GOAC_API::today();
		$periods = array(
			array( 'Hoje (parcial)', $today, $today ),
			array( '7 dias fechados', GOAC_Stats::add_days( $today, -7 ), GOAC_Stats::add_days( $today, -1 ) ),
		);
		$overlays = is_array( $contract ) && 'manual_overlays' === ( $contract['delivery_mode'] ?? '' );
		GOAC_UI::card_open( 'Reconciliação: relatório por bloco × total', '<span class="goac-muted">total da conta − soma dos blocos</span>' );
		echo '<p class="goac-muted goac-section-intro">Compara o total com a soma das linhas recebidas no relatório por bloco. O residual não identifica sozinho âncora, vinheta ou banners automáticos: diferenças de escopo, limite de linhas e atualização também precisam ser conciliadas. A separação por formato deve ser confirmada no relatório correspondente; as janelas podem atravessar mudanças de modo.</p>';
		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Período</th><th>Camada</th><th class="num">Receita</th><th class="num">Participação</th><th class="num">Contribuição no Page RPM</th><th class="num">Impr. / PV</th><th class="num">RPM de impressão</th><th class="num">CTR impr.</th><th class="num">Impr. / solicit. corresp.</th></tr></thead><tbody>';
		foreach ( $periods as $period ) {
			list( $label, $start, $end ) = $period;
			$total = GOAC_Stats::sum( GOAC_UI::rows( $start, $end ) );
			$units = GOAC_API::breakdown( array( 'AD_UNIT_ID' ), $start, $end, array( 'limit' => 500, 'currency' => GOAC_UI::api_currency() ) );
			$pv = (float) $total['page_views'];
			if ( is_wp_error( $units ) || $pv <= 0 ) {
				echo '<tr><td>' . esc_html( $label ) . '</td><td colspan="8" class="goac-muted">' . esc_html( is_wp_error( $units ) ? 'Relatório por bloco indisponível: ' . $units->get_error_message() : 'Sem page views no período.' ) . '</td></tr>';
				continue;
			}
			$manual = GOAC_Stats::sum( $units['rows'] );
			/* Reduced metric sets have no request counts; never subtract a missing metric. */
			$has_requests = in_array( (string) ( $units['metric_set'] ?? '' ), array( 'full', 'core', 'no_pages' ), true );
			$outside = GOAC_Stats::empty_row();
			foreach ( GOAC_Stats::ADDITIVE as $k ) {
				if ( 'page_views' === $k ) {
					$outside[ $k ] = $pv;
				} elseif ( ! $has_requests && in_array( $k, array( 'ad_requests', 'matched_requests' ), true ) ) {
					$outside[ $k ] = 0.0;
					$manual[ $k ] = 0.0;
				} else {
					$outside[ $k ] = max( 0.0, (float) $total[ $k ] - (float) $manual[ $k ] );
				}
			}
			$manual['page_views'] = $pv;
			$layers = array(
				'Blocos presentes no relatório' => GOAC_Stats::derive( $manual ),
				'Residual a reconciliar' => GOAC_Stats::derive( $outside ),
			);
			$first = true;
			foreach ( $layers as $layer => $row ) {
				$share = (float) $total['earnings'] > 0 ? (float) $row['earnings'] / (float) $total['earnings'] : null;
				$fill = (float) $row['matched_requests'] > 0 ? (float) $row['impressions'] / (float) $row['matched_requests'] : null;
				echo '<tr><td>' . ( $first ? '<strong>' . esc_html( $label ) . '</strong>' : '' ) . '</td><td>' . esc_html( $layer ) . '</td>';
				echo '<td class="num">' . esc_html( GOAC_UI::money( $row['earnings'] ) ) . '</td><td class="num">' . esc_html( null === $share ? '—' : GOAC_UI::pct( $share ) ) . '</td>';
				echo '<td class="num">' . esc_html( GOAC_UI::money( $row['page_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $row['impressions_per_page'], 2 ) ) . '</td>';
				echo '<td class="num">' . esc_html( GOAC_UI::money( $row['impression_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $row['impression_ctr'], 2 ) ) . '</td><td class="num">' . esc_html( null === $fill ? '—' : GOAC_UI::pct( $fill ) ) . '</td></tr>';
				$first = false;
			}
		}
		echo '</tbody></table></div>';
		if ( $overlays ) {
			echo '<p class="goac-footnote"><strong>Como ler:</strong> o residual não comprova quais formatos foram veiculados. Confira receita, impressões e controles por formato antes de atribuir a mudança. Preserve âncora e vinheta e compare somente períodos com escopo, moeda e atualização compatíveis.</p>';
		}
		GOAC_UI::card_close();
	}

	private static function health_card( $contract ) {
		$aside = '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '"><input type="hidden" name="action" value="goac_delivery_checks">' . wp_nonce_field( 'goac_delivery_checks', '_wpnonce', true, false ) . '<button class="button">Verificar loader e ads.txt agora</button></form>';
		GOAC_UI::card_open( 'Saúde da monetização', $aside );
		if ( null === $contract ) { GOAC_UI::empty_state( 'Sem contrato do tema para verificar.' ); GOAC_UI::card_close(); return; }
		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Verificação</th><th>Status</th><th>Detalhe</th></tr></thead><tbody>';
		foreach ( self::local_tests() as $test ) {
			if ( ! is_callable( $test ) ) { continue; }
			$r = call_user_func( $test );
			echo '<tr><td>' . esc_html( (string) ( $r['label'] ?? $test ) ) . '</td><td>' . self::status_pill( (string) ( $r['status'] ?? '' ) ) . '</td><td>' . wp_kses_post( (string) ( $r['description'] ?? '' ) ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		}
		$checks = get_transient( self::CHECKS );
		if ( is_array( $checks ) && ! empty( $checks['results'] ) ) {
			foreach ( $checks['results'] as $r ) {
				echo '<tr><td>' . esc_html( $r['label'] ) . ' <small class="goac-muted">(' . esc_html( wp_date( 'd/m H:i', (int) $checks['at'] ) ) . ')</small></td><td>' . self::status_pill( $r['status'] ) . '</td><td>' . wp_kses_post( $r['description'] ) . '</td></tr>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
			}
		} else {
			echo '<tr><td colspan="3" class="goac-muted">Loader único e ads.txt fazem uma requisição real à home e ao /ads.txt; use o botão acima para executá-los.</td></tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function pipeline_card() {
		$aside = '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '"><input type="hidden" name="action" value="goac_learning_retry">' . wp_nonce_field( 'goac_learning_retry', '_wpnonce', true, false ) . '<button class="button">Reprocessar dead-letter</button></form>';
		GOAC_UI::card_open( 'Coleta e cron', $aside );
		$r = GOAC_Learning::readiness();
		echo '<div class="goac-kpis">';
		GOAC_UI::kpi( 'Baseline do Data Lab', GOAC_UI::pct( $r['progress'] ), esc_html( sprintf( '%d de %d consultas', $r['jobs_done'], $r['jobs_total'] ) ) );
		GOAC_UI::kpi( 'Fila', GOAC_UI::number( $r['queue'] + $r['maintenance_queue'] ), esc_html( sprintf( '%d em nova tentativa', $r['retrying'] ) ) );
		GOAC_UI::kpi( 'Dead-letter', GOAC_UI::number( $r['dead_letter'] ), $r['dead_letter'] ? 'falharam 5 vezes' : 'nenhuma falha terminal', array( 'class' => $r['dead_letter'] ? 'is-danger' : 'is-good' ) );
		GOAC_UI::kpi( 'Último sucesso', $r['last_success'] ? wp_date( 'd/m H:i', $r['last_success'] ) : '—', $r['cooldown'] ? esc_html( sprintf( 'quota: pausa de %d min', ceil( $r['cooldown'] / 60 ) ) ) : 'sem pausa de quota' );
		echo '</div>';
		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Evento</th><th>Próxima execução</th><th>Função</th></tr></thead><tbody>';
		$events = array( 'goac_quarter_hour_refresh' => 'Sincroniza hoje/ontem e avança o Data Lab (15 min)', 'goac_learning_bootstrap' => 'Fast lane do baseline (enquanto houver fila)', 'goac_backfill_event' => 'Importação do histórico completo', 'odac_tick' => 'Center duplicado do tema 3.83 (deve estar ausente)' );
		foreach ( $events as $hook => $label ) {
			$next = wp_next_scheduled( $hook );
			$cell = $next ? wp_date( 'd/m/Y H:i:s', $next ) : ( 'odac_tick' === $hook ? 'ausente ✓' : 'não agendado' );
			echo '<tr><td><code>' . esc_html( $hook ) . '</code></td><td>' . esc_html( $cell ) . '</td><td>' . esc_html( $label ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		if ( defined( 'DISABLE_WP_CRON' ) && DISABLE_WP_CRON ) { echo '<p class="goac-muted">WP-Cron por visitas está desativado: a tarefa de cron do servidor precisa estar ativa na hospedagem.</p>'; }
		$state = GOAC_Learning::state();
		if ( ! empty( $state['dead_letter'] ) ) {
			echo '<h3 class="goac-subhead">Falhas terminais</h3><ul>';
			foreach ( array_slice( array_reverse( (array) $state['dead_letter'], true ), 0, 10, true ) as $id => $item ) {
				echo '<li><code>' . esc_html( (string) $id ) . '</code> — ' . esc_html( (string) ( $item['error'] ?? '' ) ) . '</li>';
			}
			echo '</ul>';
		}
		GOAC_UI::card_close();
	}
}
