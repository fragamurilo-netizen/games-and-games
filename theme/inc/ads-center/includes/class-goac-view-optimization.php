<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Diagnóstico diário de Page RPM baseado no histórico real da própria conta.
 *
 * Princípio: Page RPM = Impression RPM × impressões por page view. Antes de
 * sugerir qualquer mudança de carga, o motor separa preço do inventário,
 * quantidade de impressões, cobertura e viewability. O painel respeita o
 * contrato publicado pelo tema: posições manuais com âncora e vinheta oficiais.
 * Em modo híbrido, Auto Ads in-page e placements manuais são avaliados como
 * camadas complementares; mudanças de conta devem ser experimentos isolados,
 * nunca uma reação automática a um único dia de RPM.
 */
final class GOAC_View_Optimization {
	const MIN_PV = 500;
	const MIN_IMPRESSIONS = 1000;

	public static function render() {
		$c = GOAC_UI::context();
		if ( ! GOAC_Store::has_data() ) {
			GOAC_UI::empty_state( 'Ainda não há histórico suficiente para diagnosticar o RPM.' );
			return;
		}

		$day = isset( $_GET['opt_day'] ) && is_scalar( $_GET['opt_day'] ) ? sanitize_text_field( wp_unslash( $_GET['opt_day'] ) ) : $c['today']; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( ! GOAC_Stats::valid_date( $day ) || $day > $c['today'] ) { $day = $c['today']; }
		$today_partial = $day === $c['today'];
		$base_end = GOAC_Stats::add_days( $day, -1 );
		$base_start = GOAC_Stats::add_days( $base_end, -6 );
		$long_start = GOAC_Stats::add_days( $base_end, -27 );

		$current = GOAC_Stats::sum( GOAC_UI::rows( $day, $day ) );
		$base_rows = GOAC_UI::rows( $base_start, $base_end );
		$long_rows = GOAC_UI::rows( $long_start, $base_end );
		$bench = self::benchmark( $base_rows );
		$long = self::benchmark( $long_rows );
		$sample = self::sample_level( $current );
		$quality = self::observation_quality( $day, $c, $base_rows, GOAC_UI::rows( $day, $day ) );
		$controls = self::controls();

		$aside = '<form method="get" class="goac-inline-form goac-inline-compact"><input type="hidden" name="page" value="goac"><input type="hidden" name="tab" value="optimization"><label>Dia <input type="date" name="opt_day" max="' . esc_attr( $c['today'] ) . '" value="' . esc_attr( $day ) . '"></label><button class="button">Analisar</button></form>';
		GOAC_UI::card_open( 'Otimização de RPM · decisão do dia', $aside, 'goac-optimization-hero' );
		echo '<p class="goac-muted goac-section-intro">Diagnóstico sobre dados reais da conta. O benchmark usa as <strong>somas dos 7 dias anteriores</strong>: RPM ponderado por páginas e RPM de impressão ponderado por impressões. A janela de 28 dias mostra o contexto histórico. ' . ( $today_partial ? 'O dia atual ainda é parcial.' : 'O dia selecionado está fechado no calendário; ganhos estimados ainda podem ser revisados pelo Google.' ) . '</p>';
		echo '<p class="goac-footnote">' . esc_html( implode( ' ', $quality['notes'] ) ) . '</p>';

		$page_delta = self::ratio_delta( $current['page_rpm'], $bench['page_rpm'] );
		$irpm_delta = self::ratio_delta( $current['impression_rpm'], $bench['impression_rpm'] );
		$ipp_delta = self::ratio_delta( $current['impressions_per_page'], $bench['impressions_per_page'] );
		$view_delta = self::point_delta( $current['viewability'], $bench['viewability'] );

		echo '<div class="goac-kpis goac-kpis-opt">';
		GOAC_UI::kpi( 'Page RPM agora', GOAC_UI::money( $current['page_rpm'] ), null === $page_delta ? 'sem base' : GOAC_UI::signed_pct( $page_delta ) . ' vs 7d', array( 'class' => 'is-hero is-accent' ) );
		GOAC_UI::kpi( 'Benchmark 7 dias', GOAC_UI::money( $bench['page_rpm'] ), 'ponderado · ' . count( $base_rows ) . ' dias disponíveis', array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'RPM de impressão', GOAC_UI::money( $current['impression_rpm'] ), null === $irpm_delta ? 'sem base' : GOAC_UI::signed_pct( $irpm_delta ) . ' vs 7d', array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'Impressões / PV', GOAC_UI::number( $current['impressions_per_page'], 2 ), null === $ipp_delta ? 'sem base' : GOAC_UI::signed_pct( $ipp_delta ) . ' vs 7d', array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'Active View', GOAC_UI::pct( $current['viewability'] ), null === $view_delta ? 'sem base' : self::signed_points( $view_delta ) . ' vs 7d', array( 'class' => 'is-hero' ) );
		GOAC_UI::kpi( 'Cobertura', GOAC_UI::pct( $current['coverage'] ), 'match de solicitações', array( 'class' => 'is-hero' ) );
		echo '</div>';

		echo '<div class="goac-opt-formula"><span>Page RPM</span><b>=</b><span>RPM de impressão</span><b>×</b><span>impressões / page view</span><em>Decomposição aritmética do mesmo conjunto de dados; não prova causalidade.</em></div>';
		GOAC_UI::card_close();

		self::controls_card( $day, $controls );
		if ( self::manual_only_mode() ) {
			self::feedback_status_card();
			$selected_rows = $today_partial && empty( $c['has_today'] ) ? array() : GOAC_Stats::slice( $c['account_rows'], $day, $day );
			self::rpm_goals_card( GOAC_Stats::slice( $c['account_rows'], $base_start, $base_end ), $base_start, $base_end, $c['account_currency'], $selected_rows, $day );
		}
		$breakdowns = self::breakdowns( $day, $base_start, $base_end );
		$actions = self::recommendations( $current, $bench, $long, $sample, $breakdowns, $today_partial, $controls, $quality );
		self::actions_card( $actions, $sample, $current, $bench, $controls );
		self::metric_table( $current, $bench, $long );
		self::breakdown_section( $breakdowns, $current );
		self::method_card();
	}

	private static function benchmark( array $rows ) {
		return GOAC_Stats::sum( $rows );
	}

	private static function feedback_status_card() {
		GOAC_UI::card_open( 'Como o motor se adapta hoje', '<span class="goac-pill">estado real</span>' );
		echo '<p><strong>Entrega:</strong> o runtime do tema reavalia elegibilidade, viewport e consentimento, e ajusta a antecipação à latência local de resposta. Esse ajuste não usa o RPM acumulado para cortar posições.</p>';
		echo '<p><strong>Receita:</strong> este painel lê o histórico e apresenta diagnóstico e cenários. Ele não altera a quantidade de anúncios, não escolhe automaticamente um perfil vencedor e não controla os lances do Google.</p>';
		if ( function_exists( 'go_verge_adsense_topscroll_config' ) ) {
			$topscroll = go_verge_adsense_topscroll_config();
			$cap = (int) ( $topscroll['frequency_max'] ?? 0 );
			echo '<p><strong>Top Scroll · limite efetivo:</strong> ' . esc_html( $cap ? $cap . ' preenchimentos por 24 horas' : 'sem limite local de frequência' ) . ' · origem: ' . esc_html( (string) ( $topscroll['frequency_source'] ?? 'não informada' ) ) . '. Com limite 5–6, o 5º preenchimento exige 3+ páginas na sessão ou 60s ativos; o 6º exige 4+ páginas ou 120s ativos. <a href="' . esc_url( admin_url( 'themes.php?page=go-verge-adsense-topscroll' ) ) . '">Revisar em Aparência → Top Scroll</a>. Zero desativa o limite local; uma constante no servidor prevalece sobre o campo. O painel não altera sua escolha.</p>';
		}
		echo '<p class="goac-footnote"><strong>Operação da versão única:</strong> a política de reservas alcançadas e a continuidade das listagens já estão integradas ao motor. Acompanhe receita total, receita por mil páginas, cobertura e exposição nos relatórios habituais, considerando dispositivo, origem, páginas e atualização dos dados. Não é necessário criar grupos ou canais para usar esta versão.</p>';
		GOAC_UI::card_close();
	}

	/** Reporting gates only: this class never changes the live inventory. */
	public static function observation_quality( $day, array $context, array $baseline, array $current ) {
		$reasons = array();
		$notes = array( 'Volume serve para triagem, não é confiança estatística de ganho. Active View agregado é uma aproximação ponderada pelas impressões mensuráveis disponíveis.' );
		if ( ! $current ) { $reasons[] = 'Não há linha de dados para o dia selecionado; ausência não significa receita zero.'; }
		if ( $day === $context['today'] && ( ! empty( $context['stale'] ) || ! empty( $context['sync_error'] ) || empty( $context['has_today'] ) ) ) {
			$reasons[] = 'A sincronização do dia está ausente, atrasada ou com erro; atualize os dados antes de interpretar a variação.';
		}
		$volume = GOAC_Stats::sum( $baseline );
		if ( count( $baseline ) < 3 || $volume['page_views'] < self::MIN_PV || $volume['impressions'] < self::MIN_IMPRESSIONS ) {
			$reasons[] = 'Referência com menos de 3 dias disponíveis ou volume insuficiente para triagem.';
		}
		$notes[] = 'As janelas podem misturar configurações e origens de tráfego. Compare o mesmo motor, dispositivo, origem e horários antes de atribuir uma mudança de receita.';
		return array( 'ready' => ! $reasons, 'reasons' => $reasons, 'notes' => array_merge( $notes, $reasons ) );
	}

	private static function sample_level( array $row ) {
		$pv = (float) $row['page_views']; $im = (float) $row['impressions'];
		if ( $pv >= 3000 && $im >= 10000 ) { return array( 'key' => 'high', 'label' => 'Alta', 'enough' => true ); }
		if ( $pv >= self::MIN_PV && $im >= self::MIN_IMPRESSIONS ) { return array( 'key' => 'medium', 'label' => 'Média', 'enough' => true ); }
		return array( 'key' => 'low', 'label' => 'Baixa', 'enough' => false );
	}

	private static function ratio_delta( $cur, $base ) {
		return is_numeric( $cur ) && is_numeric( $base ) && abs( (float) $base ) > 0.000001 ? ( (float) $cur / (float) $base ) - 1 : null;
	}

	private static function point_delta( $cur, $base ) {
		return is_numeric( $cur ) && is_numeric( $base ) ? (float) $cur - (float) $base : null;
	}

	private static function signed_points( $value ) {
		if ( ! is_numeric( $value ) ) { return '—'; }
		return ( $value > 0 ? '+' : ( $value < 0 ? '−' : '' ) ) . number_format_i18n( abs( (float) $value ) * 100, 1 ) . ' p.p.';
	}


	private static function delivery_mode() {
		if ( ! function_exists( 'go_verge_ads_config' ) ) { return ''; }
		$config = (array) go_verge_ads_config();
		return (string) ( $config['delivery_mode'] ?? '' );
	}

	/** Motor manual dono das posições in-page (com ou sem sobreposições do Google). */
	private static function manual_only_mode() {
		return 'manual_overlays' === self::delivery_mode();
	}

	/** Manual in-page + âncora/vinheta do Google (contrato do tema 3.85.17+). */
	private static function overlay_mode() {
		return 'manual_overlays' === self::delivery_mode();
	}

	/** A regra de conta que acompanha cada recomendação do motor manual. */
	private static function account_rule() {
		return 'Mantenha Auto Ads geral, âncora e vinheta ligados; banners in-page, Encontrar mais posições, Otimizar anúncios atuais e side rails automáticos desligados.';
	}

	private static function controls() {
		$defaults = array(
			'configured' => 0, 'auto_ads' => 'unknown', 'anchor_ads' => 'unknown', 'vignette_ads' => 'unknown', 'side_rails_ads' => 'unknown', 'banner_ads' => 'unknown', 'find_more' => 'unknown',
			'optimize_existing' => 'unknown', 'max_ads' => null, 'min_distance' => null, 'updated_at' => 0,
		);
		$stored = get_option( 'goac_optimization_controls', array() );
		return wp_parse_args( is_array( $stored ) ? $stored : array(), $defaults );
	}

	private static function tri_select( $name, $value ) {
		$options = array( 'unknown' => 'Não informado', 'on' => 'Ativado', 'off' => 'Desativado' );
		$html = '<select name="' . esc_attr( $name ) . '">';
		foreach ( $options as $key => $label ) { $html .= '<option value="' . esc_attr( $key ) . '"' . selected( $value, $key, false ) . '>' . esc_html( $label ) . '</option>'; }
		return $html . '</select>';
	}

	private static function controls_card( $day, array $cfg ) {
		echo '<p><a class="button" href="' . esc_url( admin_url( 'admin.php?page=go-verge-ads-delivery-mode' ) ) . '">Ver contrato de entrega</a></p>';
		GOAC_UI::card_open( 'Entrega do tema', '<span class="goac-pill ok">MANUAL + SOBREPOSIÇÕES</span>' );
		echo '<p class="goac-muted goac-section-intro"><strong>Posições in-page: do tema.</strong> O inventário respeita os templates e dispositivos configurados. Preserve Auto Ads geral, âncora e vinheta oficiais ligados; banners in-page, Encontrar mais posições, Otimizar anúncios atuais e side rails automáticos desligados. Não há seletor de outra arquitetura. O baseline local é fixo; os indicadores de RPM são diagnósticos e não ajustam automaticamente o volume.</p>';
		echo '<p class="goac-footnote">Este é o contrato local; a API não confirma os formatos ligados na conta. Registre abaixo os controles reais. Os relatórios históricos e por formato continuam disponíveis; receita sem ID de bloco não identifica sozinha uma sobreposição.</p>';
		GOAC_UI::card_close();
		self::controls_mirror( $day, $cfg );
	}

	/**
	 * O espelho dos controles da conta.
	 *
	 * Até a 3.1.2 este formulário só aparecia no modo híbrido: no modo manual a
	 * função saía antes de imprimi-lo. O cartão acima diz o que a conta DEVE
	 * ter; sem o espelho não havia onde registrar o que ela TEM, então a
	 * verificação de saúde que compara os dois ficava presa em "não registrado"
	 * sem nenhum caminho para sair dali. É no modo manual que essa comparação
	 * mais importa: um banner in-page automático ligado por engano compete
	 * diretamente com as posições do tema.
	 */
	private static function controls_mirror( $day, array $cfg ) {
		$manual = self::manual_only_mode();
		GOAC_UI::card_open(
			'Minha configuração atual do AdSense',
			$cfg['configured'] ? '<span class="goac-muted">salve uma vez e atualize quando mudar</span>' : '<span class="goac-pill warn">NÃO REGISTRADO</span>'
		);
		echo '<p class="goac-muted goac-section-intro">A API do AdSense não expõe a posição atual dos controles de Auto Ads. Este espelho permite que o painel diga <strong>exatamente o que manter ou alterar</strong>, sem fingir que conhece sua configuração.'
			. ( $manual ? ' <strong>Registre aqui o que está ligado de fato na conta</strong> — é a comparação contra o contrato do tema que denuncia um banner automático concorrendo com as posições manuais.' : '' )
			. '</p>';
		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="goac-opt-settings">';
		echo '<input type="hidden" name="action" value="goac_save_optimization_controls"><input type="hidden" name="opt_day" value="' . esc_attr( $day ) . '">';
		wp_nonce_field( 'goac_save_optimization_controls' );
		echo '<div class="goac-opt-settings-grid">';
		echo '<label><span>Auto Ads geral (âncora/vinheta)</span>' . self::tri_select( 'auto_ads', $cfg['auto_ads'] ) . '</label>';
		echo '<label><span>Âncora oficial</span>' . self::tri_select( 'anchor_ads', $cfg['anchor_ads'] ) . '</label>';
		echo '<label><span>Vinheta oficial</span>' . self::tri_select( 'vignette_ads', $cfg['vignette_ads'] ) . '</label>';
		echo '<label><span>Side rails automáticos (contrato: desligados)</span>' . self::tri_select( 'side_rails_ads', $cfg['side_rails_ads'] ) . '</label>';
		echo '<label><span>Anúncios de banner (in-page)</span>' . self::tri_select( 'banner_ads', $cfg['banner_ads'] ) . '</label>';
		echo '<label><span>Encontrar mais posições em artigos</span>' . self::tri_select( 'find_more', $cfg['find_more'] ) . '</label>';
		echo '<label><span>Google otimiza anúncios atuais</span>' . self::tri_select( 'optimize_existing', $cfg['optimize_existing'] ) . '</label>';
		echo '<label><span>Número máximo atual</span><input type="number" min="0" max="100" name="max_ads" value="' . esc_attr( null === $cfg['max_ads'] ? '' : (string) $cfg['max_ads'] ) . '" placeholder="se o AdSense mostrar número"><small>Se houver valor numérico na interface, copie aqui.</small></label>';
		echo '<label><span>Distância mínima atual</span><input type="number" min="0" max="10000" name="min_distance" value="' . esc_attr( null === $cfg['min_distance'] ? '' : (string) $cfg['min_distance'] ) . '" placeholder="se o AdSense mostrar número"><small>Serve para o painel mandar manter o valor exato.</small></label>';
		echo '</div><p><button class="button button-primary">Salvar configuração atual</button></p></form>';
		GOAC_UI::card_close();
	}

	private static function site_host() {
		$host = (string) wp_parse_url( home_url( '/' ), PHP_URL_HOST );
		return preg_replace( '/^www\\./i', '', $host ) ?: 'seu site';
	}

	private static function banner_path() {
		return 'AdSense → Anúncios → Editar ' . self::site_host() . ' → Formatos in-page → Anúncios de banner → Configurações avançadas';
	}

	private static function action( $priority, $area, $title, $instruction, $why, $confidence = 'Alta', array $steps = array(), $do_not = '', $recheck = '' ) {
		return compact( 'priority', 'area', 'title', 'instruction', 'why', 'confidence', 'steps', 'do_not', 'recheck' );
	}

	private static function recommendations( array $cur, array $b, array $long, array $sample, array $breakdowns, $partial, array $cfg, array $quality = array() ) {
		/* Partial-day comparisons and small samples can diagnose delivery, but
		 * cannot justify changing page density against complete-day benchmarks. */
		if ( self::manual_only_mode() && ( $partial || ! $sample['enough'] || ( isset( $quality['ready'] ) && ! $quality['ready'] ) ) ) {
			return array( self::action(
				'hold', 'Motor manual', 'Confira a entrega; aguarde o fechamento para avaliar receita',
				'Verifique o carregamento dos espaços elegíveis e mantenha a política unificada de inventário.',
				$partial ? 'O dia selecionado ainda é parcial e tem composição de horários diferente da referência.' : ( ! empty( $quality['reasons'] ) ? implode( ' ', $quality['reasons'] ) : 'A amostra do dia ainda é insuficiente para orientar uma alteração de inventário.' ),
				'Limitada', array( self::account_rule(), 'Abra Anúncios: diagnóstico na página e confira solicitações, respostas e motivos de espera.', 'Corrija erros de entrega reproduzíveis sem esperar por significância de receita.', 'Compare dias fechados com o mesmo motor, dispositivo e origem de tráfego.' ),
				'Não reduza o inventário por silêncio do provedor ou por comparação parcial.', 'Após o fechamento, com ao menos 500 PV e 1.000 impressões para triagem; valide ganhos em vários dias.'
			) );
		}
		$out = array();
		$path = self::banner_path();
		$max = null === $cfg['max_ads'] ? null : (int) $cfg['max_ads'];
		$distance = null === $cfg['min_distance'] ? null : (int) $cfg['min_distance'];
		$keep_distance = null === $distance ? 'Não mova “Distância mínima entre anúncios”.' : 'Mantenha “Distância mínima entre anúncios” em ' . $distance . '.';

		if ( ! $sample['enough'] ) {
			$need_pv = max( 0, self::MIN_PV - (int) $cur['page_views'] );
			$need_im = max( 0, self::MIN_IMPRESSIONS - (int) $cur['impressions'] );
			$out[] = self::action(
				'hold', 'AdSense', 'Não faça nenhuma alteração agora',
				'Mantenha todas as configurações exatamente como estão.',
				'A amostra ainda é pequena: ' . GOAC_UI::number( $cur['page_views'] ) . ' PV e ' . GOAC_UI::number( $cur['impressions'] ) . ' impressões.', 'Alta',
				array( 'Não abra um teste de carga agora.', 'Volte a esta aba depois de pelo menos ' . GOAC_UI::number( $need_pv ) . ' PV adicionais e ' . GOAC_UI::number( $need_im ) . ' impressões adicionais, ou quando o dia fechar.' ),
				'Não aumente máximo, não reduza distância e não ative outro formato com essa amostra.', 'Reavaliar quando atingir 500 PV + 1.000 impressões ou no fechamento do dia.'
			);
			return $out;
		}

		if ( self::manual_only_mode() ) {
			return self::manual_recommendations( $cur, $b, $long, $breakdowns, $partial );
		}

		$pr = self::ratio_delta( $cur['page_rpm'], $b['page_rpm'] );
		$ir = self::ratio_delta( $cur['impression_rpm'], $b['impression_rpm'] );
		$ip = self::ratio_delta( $cur['impressions_per_page'], $b['impressions_per_page'] );
		$vd = self::point_delta( $cur['viewability'], $b['viewability'] );
		$cd = self::point_delta( $cur['coverage'], $b['coverage'] );

		if ( null !== $pr && $pr >= -0.05 ) {
			$out[] = self::action(
				'good', 'AdSense', 'Hoje: não mexa no AdSense',
				'Faça zero alterações de carga hoje.',
				'O Page RPM está dentro de 5% do benchmark de 7 dias ou acima dele.', 'Alta',
				array( 'Mantenha “Número máximo” como está.', $keep_distance, 'Mantenha os formatos atuais e não abra um experimento hoje.' ),
				'Não tente “melhorar” um dia saudável adicionando densidade.', 'Reavaliar amanhã com o dia fechado.'
			);
		}

		if ( null !== $pr && $pr < -0.05 ) {
			if ( null !== $ir && $ir <= -0.10 && ( null === $ip || $ip > -0.08 ) ) {
				$out[] = self::action(
					'high', 'AdSense', 'Hoje: não aumente anúncios',
					'Não altere “Número máximo”, “Distância mínima” nem formatos.',
					'O RPM de impressão caiu ' . GOAC_UI::signed_pct( $ir ) . ', mas impressões/PV não caíram na mesma proporção. O problema está no preço/mix, não na quantidade de oportunidades.', 'Alta',
					array( 'Abra esta aba amanhã e compare o RPM de impressão novamente.', 'Use as tabelas de Plataforma/Formato/Placement abaixo para identificar o mix que perdeu valor.', 'Se o RPM de impressão recuperar sem mudança de carga, mantenha a configuração.' ),
					'Não mova sliders para compensar queda de valor do inventário.', 'Reavaliar no próximo dia fechado.'
				);
			}

			if ( null !== $ip && $ip <= -0.10 ) {
				if ( ( is_numeric( $cur['coverage'] ) && $cur['coverage'] < 0.88 ) || ( null !== $cd && $cd <= -0.05 ) ) {
					$out[] = self::action(
						'high', 'AdSense', 'Primeiro recupere a cobertura; não aumente carga',
						'Não mova os controles de densidade hoje.',
						'Impressões/PV caíram ' . GOAC_UI::signed_pct( $ip ) . ' e a cobertura está em ' . GOAC_UI::pct( $cur['coverage'] ) . '.', 'Alta',
						array(
							'AdSense → Central de políticas: se houver problema ativo para ' . self::site_host() . ', resolva-o antes de testar carga.',
							'AdSense → Anúncios → Editar ' . self::site_host() . ': confirme “Anúncios automáticos” = ativado e “Formatos in-page → Anúncios de banner” = ativado.',
							$keep_distance,
							'Mantenha “Número máximo” sem alteração até a cobertura voltar a pelo menos 88% ou ao benchmark.'
						),
						'Não crie mais solicitações enquanto a cobertura estiver baixa.', 'Reavaliar após a cobertura voltar a ≥ 88% ou no próximo dia fechado.'
					);
				} elseif ( is_numeric( $cur['viewability'] ) && $cur['viewability'] >= 0.52 && ( null === $vd || $vd > -0.04 ) ) {
					if ( 'off' === $cfg['auto_ads'] ) {
						$steps = array( 'AdSense → Anúncios → Editar ' . self::site_host() . '.', 'Ative “Anúncios automáticos”.', 'Em “Formatos in-page”, ative “Anúncios de banner”.', 'Clique “Aplicar ao site” → “Aplicar agora” → “Salvar”.' );
						$instruction = 'Ative Auto Ads in-page; não faça outra mudança de carga no mesmo teste.';
					} elseif ( 'off' === $cfg['banner_ads'] ) {
						$steps = array( 'AdSense → Anúncios → Editar ' . self::site_host() . ' → Formatos in-page.', 'Ative somente “Anúncios de banner”.', $keep_distance, 'Clique “Aplicar ao site” → “Aplicar agora” → “Salvar”.' );
						$instruction = 'Ative “Anúncios de banner” e mantenha o restante igual.';
					} elseif ( 'off' === $cfg['find_more'] ) {
						$steps = array( $path . '.', 'Ative “Encontrar mais posições de anúncio em páginas de artigos”.', 'Não mude “Número máximo” neste mesmo teste.', $keep_distance, 'Clique “Aplicar ao site” → “Aplicar agora” → “Salvar”.' );
						$instruction = 'Ative “Encontrar mais posições em artigos”; não mova nenhum slider hoje.';
					} else {
						$target = null === $max ? 'uma marca para a direita' : 'de ' . $max . ' para ' . ( $max + 1 );
						$steps = array( $path . '.', 'Em “Número máximo de anúncios em uma página”, mude ' . $target . '.', $keep_distance, 'Mantenha “Encontrar mais posições de anúncio em páginas de artigos” ativado.', 'Clique “Aplicar ao site” → “Aplicar agora” → “Salvar”.' );
						$instruction = null === $max ? 'Aumente somente “Número máximo” em uma marca.' : 'Mude “Número máximo” de ' . $max . ' para ' . ( $max + 1 ) . '.';
					}
					$out[] = self::action(
						'high', 'AdSense', 'Ação principal: abra uma oportunidade a mais', $instruction,
						'Impressões/PV estão ' . GOAC_UI::signed_pct( $ip ) . ' abaixo do benchmark, com Active View saudável (' . GOAC_UI::pct( $cur['viewability'] ) . ') e cobertura sem sinal de falta de preenchimento.', 'Alta',
						$steps, 'Não reduza a distância, não ative Multiplex e não mexa em âncora/vinheta no mesmo teste.', $partial ? 'Reavaliar depois de +3.000 PV após a mudança ou amanhã, o que vier depois.' : 'Reavaliar no próximo dia fechado.'
					);
				}
			}
		}

		if ( is_numeric( $cur['viewability'] ) && ( $cur['viewability'] < 0.48 || ( null !== $vd && $vd <= -0.06 ) ) ) {
			if ( null !== $ip && $ip > 0.05 ) {
				$target = null === $max ? 'uma marca para a esquerda' : 'de ' . $max . ' para ' . max( 0, $max - 1 );
				$out[] = self::action(
					'high', 'AdSense', 'Reduza somente o número máximo',
					null === $max ? 'Mova “Número máximo” uma marca para a esquerda.' : 'Mude “Número máximo” de ' . $max . ' para ' . max( 0, $max - 1 ) . '.',
					'Active View caiu para ' . GOAC_UI::pct( $cur['viewability'] ) . ' enquanto a densidade está acima do benchmark.', 'Alta',
					array( $path . '.', 'Em “Número máximo de anúncios em uma página”, mude ' . $target . '.', $keep_distance, 'Não altere “Encontrar mais posições” neste teste.', 'Clique “Aplicar ao site” → “Aplicar agora” → “Salvar”.' ),
					'Não aumente distância e reduza máximo ao mesmo tempo; uma variável por teste.', $partial ? 'Reavaliar depois de +3.000 PV após a mudança ou amanhã.' : 'Reavaliar no próximo dia fechado.'
				);
			} else {
				$out[] = self::action(
					'high', 'AdSense/site', 'Não aumente carga enquanto o Active View estiver baixo',
					'Mantenha os sliders atuais e corrija primeiro o placement com baixa visibilidade.',
					'Active View está em ' . GOAC_UI::pct( $cur['viewability'] ) . ( null !== $vd ? ', ' . self::signed_points( $vd ) . ' contra o benchmark.' : '.' ), 'Alta',
					array( 'Não altere “Número máximo”.', $keep_distance, 'Use a tabela “Placement” abaixo para localizar o tipo que mais perdeu qualidade/participação.', 'Depois de corrigir esse placement, espere o próximo dia fechado antes de tocar nos controles globais.' ),
					'Não tente recuperar RPM adicionando mais impressões pouco visíveis.', 'Reavaliar quando Active View voltar a ≥ 52% ou ao benchmark.'
				);
			}
		}

		if ( null !== $ip && $ip >= 0.12 && null !== $vd && $vd <= -0.05 ) {
			$out[] = self::action(
				'medium', 'AdSense', 'Densidade cresceu mais que a qualidade',
				'Se ainda não houver uma ação de prioridade alta acima, reduza somente “Número máximo” em uma marca.',
				'Há ' . GOAC_UI::signed_pct( $ip ) . ' mais impressões/PV e Active View caiu ' . self::signed_points( $vd ) . '.', 'Média/alta',
				array( $path . '.', 'Mova somente “Número máximo” uma marca para a esquerda.', $keep_distance, 'Aplicar ao site → Aplicar agora → Salvar.' ),
				'Não execute esta ação se já aplicou a recomendação nº 1 hoje.', 'Reavaliar no próximo dia fechado.'
			);
		}

		$mix = self::mix_driver( $breakdowns['platform'] ?? array(), $cur['impression_rpm'] );
		if ( $mix ) {
			$out[] = self::action( 'medium', 'Tráfego', 'Não compense mudança de mix com mais anúncios', 'Faça zero alterações globais de carga por causa deste sinal.', $mix, 'Média', array( 'Mantenha os controles atuais.', 'Compare o conteúdo/aquisição que trouxe a plataforma de RPM menor.', 'Reavalie o mix no próximo dia fechado.' ), 'Não aumente densidade para “corrigir” tráfego de menor valor.', 'Amanhã.' );
		}

		$placement = self::placement_driver( $breakdowns['placement'] ?? array() );
		if ( $placement ) {
			$out[] = self::action( 'medium', 'AdSense/site', 'Mexa no placement, não na carga global', 'Mantenha os controles globais e investigue somente o placement apontado abaixo.', $placement, 'Média', array( 'Não mova “Número máximo”.', $keep_distance, 'Use a tabela Placement para conferir o item que perdeu participação antes de qualquer mudança global.' ), 'Não altere dois controles para tentar compensar um placement isolado.', 'Próximo dia fechado.' );
		}

		if ( ! $out ) {
			$out[] = self::action( 'hold', 'AdSense', 'Sem mudança hoje', 'Mantenha a configuração atual inteira.', 'As métricas não formam um padrão forte o bastante para justificar alteração.', 'Alta', array( 'Faça zero alterações no AdSense hoje.', 'Reabra esta aba quando o dia fechar.' ), 'Sem evidência estável, preserve a entrega e confira a maturidade dos dados.', 'Fechamento do dia.' );
		}

		$order = array( 'high' => 0, 'medium' => 1, 'good' => 2, 'hold' => 3 );
		$title_order = array(
			'Primeiro recupere a cobertura; não aumente carga' => 0,
			'Reduza somente o número máximo' => 1,
			'Não aumente carga enquanto o Active View estiver baixo' => 2,
			'Ação principal: abra uma oportunidade a mais' => 3,
			'Hoje: não aumente anúncios' => 4,
			'Densidade cresceu mais que a qualidade' => 5,
			'Hoje: não mexa no AdSense' => 6,
		);
		foreach ( $out as $i => &$row ) { $row['_seq'] = $i; } unset( $row );
		usort( $out, static function( $a, $b ) use ( $order, $title_order ) {
			$pa = $order[ $a['priority'] ] ?? 9; $pb = $order[ $b['priority'] ] ?? 9;
			if ( $pa !== $pb ) { return $pa <=> $pb; }
			$ta = $title_order[ $a['title'] ] ?? 99; $tb = $title_order[ $b['title'] ] ?? 99;
			return $ta !== $tb ? $ta <=> $tb : ( (int) $a['_seq'] <=> (int) $b['_seq'] );
		} );
		return array_slice( $out, 0, 5 );
	}

	private static function actions_card( array $actions, array $sample, array $current, array $bench, array $cfg ) {
		$top = $actions[0];
		$classes = array( 'high' => 'danger', 'medium' => 'warn', 'good' => 'ok', 'hold' => 'neutral' );
		GOAC_UI::card_open( 'O que fazer hoje', '<span class="goac-pill ' . esc_attr( $classes[ $top['priority'] ] ?? 'neutral' ) . '">volume para triagem: ' . esc_html( $sample['label'] ) . '</span>' );
		echo '<div class="goac-opt-command is-' . esc_attr( $top['priority'] ) . '"><span>FAÇA ISSO AGORA</span><h2>' . esc_html( $top['title'] ) . '</h2><p>' . esc_html( $top['instruction'] ) . '</p>';
		if ( ! empty( $top['steps'] ) ) { echo '<ol>'; foreach ( $top['steps'] as $step ) { echo '<li>' . esc_html( $step ) . '</li>'; } echo '</ol>'; }
		if ( ! empty( $top['do_not'] ) ) { echo '<p class="goac-opt-dont"><strong>Não faça:</strong> ' . esc_html( $top['do_not'] ) . '</p>'; }
		if ( ! empty( $top['recheck'] ) ) { echo '<p class="goac-opt-recheck"><strong>Quando medir de novo:</strong> ' . esc_html( $top['recheck'] ) . '</p>'; }
		echo '</div>';
		if ( ! self::manual_only_mode() && empty( $cfg['configured'] ) ) { echo '<p class="goac-opt-config-warning"><strong>Para o painel escrever “6 → 7” em vez de “uma marca”:</strong> preencha “Minha configuração atual do AdSense” acima.</p>'; }
		echo '<h3 class="goac-opt-secondary-title">Sinais secundários</h3><div class="goac-opt-actions">';
		foreach ( array_slice( $actions, 1 ) as $i => $a ) {
			echo '<article class="goac-opt-action is-' . esc_attr( $a['priority'] ) . '"><div class="goac-opt-rank">' . esc_html( (string) ( $i + 2 ) ) . '</div><div><div class="goac-opt-meta"><span>' . esc_html( $a['area'] ) . '</span><span>Sinal: ' . esc_html( $a['confidence'] ) . '</span></div><h3>' . esc_html( $a['title'] ) . '</h3><p class="goac-opt-instruction">' . esc_html( $a['instruction'] ) . '</p><p class="goac-muted">' . esc_html( $a['why'] ) . '</p></div></article>';
		}
		if ( 1 === count( $actions ) ) { echo '<p class="goac-muted">Nenhum sinal secundário forte. Execute apenas a ação principal.</p>'; }
		echo '</div>';
		echo '<p class="goac-footnote">Regra do motor: <strong>uma mudança de monetização por vez</strong>. Compare posições identificáveis e altere uma variável de densidade, elegibilidade ou carregamento. Preserve âncora e vinheta ligadas e banners automáticos in-page desligados. O registro da conta é um espelho operacional, não uma confirmação pela API.</p>';
		GOAC_UI::card_close();
	}

	private static function metric_table( array $cur, array $b, array $long ) {
		$metrics = array(
			array( 'Page RPM', 'page_rpm', 'money' ),
			array( 'RPM de impressão', 'impression_rpm', 'money' ),
			array( 'Impressões / PV', 'impressions_per_page', 'decimal' ),
			array( 'Active View', 'viewability', 'pct' ),
			array( 'Cobertura', 'coverage', 'pct' ),
			array( 'CTR por impressão', 'impression_ctr', 'pct' ),
		);
		GOAC_UI::card_open( 'Decomposição do diagnóstico', '<span class="goac-muted">agora × 7 dias × 28 dias</span>' );
		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Métrica</th><th class="num">Dia</th><th class="num">Ponderado 7d</th><th class="num">Δ 7d</th><th class="num">Ponderado 28d</th></tr></thead><tbody>';
		foreach ( $metrics as $m ) {
			list( $label, $key, $format ) = $m;
			$c = $cur[ $key ] ?? null; $s = $b[ $key ] ?? null; $l = $long[ $key ] ?? null;
			$delta = 'pct' === $format ? self::point_delta( $c, $s ) : self::ratio_delta( $c, $s );
			echo '<tr><td><strong>' . esc_html( $label ) . '</strong></td><td class="num">' . esc_html( self::format_metric( $c, $format ) ) . '</td><td class="num">' . esc_html( self::format_metric( $s, $format ) ) . '</td><td class="num">' . esc_html( 'pct' === $format ? self::signed_points( $delta ) : GOAC_UI::signed_pct( $delta ) ) . '</td><td class="num">' . esc_html( self::format_metric( $l, $format ) ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		GOAC_UI::card_close();
	}

	private static function format_metric( $value, $format ) {
		if ( 'money' === $format ) { return GOAC_UI::money( $value ); }
		if ( 'pct' === $format ) { return GOAC_UI::pct( $value ); }
		return GOAC_UI::number( $value, 2 );
	}

	private static function breakdowns( $day, $base_start, $base_end ) {
		$out = array();
		$map = array( 'platform' => 'PLATFORM_TYPE_NAME', 'format' => 'AD_FORMAT_NAME', 'placement' => 'AD_PLACEMENT_NAME' );
		foreach ( $map as $key => $dim ) {
			$current = GOAC_API::breakdown( array( $dim ), $day, $day, array( 'limit' => 100, 'currency' => GOAC_UI::api_currency(), 'ttl' => GOAC_API::report_ttl( $day ) ) );
			$base = GOAC_API::breakdown( array( $dim ), $base_start, $base_end, array( 'limit' => 100, 'currency' => GOAC_UI::api_currency(), 'ttl' => GOAC_API::report_ttl( $base_end ) ) );
			if ( is_wp_error( $current ) || is_wp_error( $base ) ) { $out[ $key ] = array( 'error' => true, 'rows' => array() ); continue; }
			$out[ $key ] = array( 'error' => false, 'rows' => self::compare_dimension_rows( $current['rows'], $base['rows'] ) );
		}
		return $out;
	}

	private static function compare_dimension_rows( array $current, array $base ) {
		$cm = array(); $bm = array(); $ct = GOAC_Stats::sum( $current ); $bt = GOAC_Stats::sum( $base );
		foreach ( $current as $row ) { $cm[ (string) ( $row['dims'][0] ?? '—' ) ] = $row; }
		foreach ( $base as $row ) { $bm[ (string) ( $row['dims'][0] ?? '—' ) ] = $row; }
		$keys = array_unique( array_merge( array_keys( $cm ), array_keys( $bm ) ) );
		$out = array();
		foreach ( $keys as $key ) {
			$c = $cm[ $key ] ?? GOAC_Stats::derive( GOAC_Stats::empty_row() );
			$b = $bm[ $key ] ?? GOAC_Stats::derive( GOAC_Stats::empty_row() );
			$out[] = array(
				'label' => $key,
				'current' => $c,
				'base' => $b,
				'current_impression_share' => $ct['impressions'] > 0 ? (float) $c['impressions'] / $ct['impressions'] : 0,
				'base_impression_share' => $bt['impressions'] > 0 ? (float) $b['impressions'] / $bt['impressions'] : 0,
				'current_earning_share' => $ct['earnings'] > 0 ? (float) $c['earnings'] / $ct['earnings'] : 0,
				'base_earning_share' => $bt['earnings'] > 0 ? (float) $b['earnings'] / $bt['earnings'] : 0,
			);
		}
		usort( $out, static function( $a, $b ) { return $b['current_earning_share'] <=> $a['current_earning_share']; } );
		return $out;
	}

	private static function manual_recommendations( array $cur, array $b, array $long, array $breakdowns, $partial ) {
		$out = array();
		$pr = self::ratio_delta( $cur['page_rpm'], $b['page_rpm'] );
		$ir = self::ratio_delta( $cur['impression_rpm'], $b['impression_rpm'] );
		$ip = self::ratio_delta( $cur['impressions_per_page'], $b['impressions_per_page'] );
		$vd = self::point_delta( $cur['viewability'], $b['viewability'] );
		$cd = self::point_delta( $cur['coverage'], $b['coverage'] );
		$placement = self::placement_driver( $breakdowns['placement'] ?? array() );

		if ( is_numeric( $cur['coverage'] ) && ( $cur['coverage'] < 0.82 || ( null !== $cd && $cd <= -0.06 ) ) ) {
			$out[] = self::action(
				'high', 'Motor manual', 'Primeiro recupere a cobertura; não aumente densidade',
				'Mantenha o teto atual de placements e investigue unidades com unfilled/cobertura baixa.',
				'Cobertura atual de ' . GOAC_UI::pct( $cur['coverage'] ) . ( null !== $cd ? ' (' . self::signed_points( $cd ) . ' vs 7d).' : '.' ), 'Alta',
				array( self::account_rule(), 'Abra Entrega & Saúde e compare cobertura por unidade.', 'Não adicione A7 nem aumente a cadência de listagens enquanto a cobertura estiver fraca.', 'Confirme que Prime P1 + A1–A6 continuam com uma única solicitação por oportunidade.' ),
				'Não tente compensar unfilled com mais requests.', $partial ? 'Reavaliar após +3.000 PV ou amanhã.' : 'Reavaliar no próximo dia fechado.'
			);
		}

		if ( is_numeric( $cur['viewability'] ) && ( $cur['viewability'] < 0.48 || ( null !== $vd && $vd <= -0.06 ) ) ) {
			$out[] = self::action(
				'high', 'Motor manual', 'Proteja Active View antes de abrir mais inventário',
				'Não aumente o número máximo de oportunidades; ajuste timing/placement das unidades menos visíveis.',
				'Active View está em ' . GOAC_UI::pct( $cur['viewability'] ) . ( null !== $vd ? ' (' . self::signed_points( $vd ) . ' vs 7d).' : '.' ), 'Alta',
				array( self::account_rule(), 'Compare Prime P1 + A1–A6, Hero, Masthead e Sidebar por Active View e receita por mil páginas.', 'Identifique se o anúncio chegou tarde ou se foi solicitado cedo demais antes de ajustar sua antecipação.', 'Confirme o sinal em vários dias com o mesmo motor; uma queda diária não deve eliminar placements.', 'Use GOAdsRuntime.inspect() para conferir distância e momento do request.' ),
				'Não reduza qualidade para perseguir impressões/PV.', 'Reavaliar quando Active View recuperar o benchmark ou ≥ 52%.'
			);
		}

		if ( null !== $pr && $pr >= -0.05 ) {
			$out[] = self::action(
				'good', 'Motor manual', 'Mantenha a densidade manual atual',
				'Não altere placements hoje.',
				'O Page RPM está dentro de 5% do benchmark de 7 dias ou acima dele.', 'Alta',
				array( self::account_rule(), 'Preserve a cadência Prime P1 + A1–A6 e F1–F5 nas fronteiras elegíveis.', 'Acompanhe amostras por unidade com período e denominadores compatíveis.' ),
				'Não crie um novo placement apenas porque a receita de um dia oscilou.', 'Próximo dia fechado.'
			);
		}

		if ( null !== $pr && $pr < -0.05 && null !== $ir && $ir <= -0.10 && ( null === $ip || $ip >= -0.05 ) ) {
			$out[] = self::action(
				'medium', 'Leilão/inventário', 'Investigue a queda de valor por impressão',
				'Mantenha a densidade e investigue quais unidades perderam RPM de impressão.',
				'RPM de impressão está ' . GOAC_UI::signed_pct( $ir ) . ' vs 7d enquanto impressões/PV não estão materialmente abaixo.', 'Alta',
				array( self::account_rule(), 'Compare receita por mil páginas, RPM de impressão e Active View por unidade.', 'Compare cada posição em períodos equivalentes, controlando dispositivo, origem e páginas; posições diferentes não isolam efeito de formato.', 'Investigue a causa se a perda de receita por mil páginas persistir em vários dias com configuração estável.' ),
				'Não aumente requests para mascarar queda de preço.', 'Próximo dia fechado.'
			);
		}

		if ( null !== $pr && $pr < -0.05 && null !== $ip && $ip <= -0.08 && is_numeric( $cur['coverage'] ) && $cur['coverage'] >= 0.85 && is_numeric( $cur['viewability'] ) && $cur['viewability'] >= 0.52 ) {
			$out[] = self::action(
				'medium', 'Motor manual', 'Há espaço para recuperar oportunidades manuais',
				'Antes de criar novos slots, confirme se A4–A6 estão sendo alcançados e requisitados conforme o scroll real.',
				'Impressões/PV estão ' . GOAC_UI::signed_pct( $ip ) . ' vs 7d, com cobertura e Active View saudáveis.', 'Média/alta',
				array( self::account_rule(), 'Inspecione request rate e scroll depth de A3–A6.', 'Se os candidatos existem mas chegam tarde, ajuste apenas a janela preditiva.', 'Só aumente elegibilidade editorial se os placements atuais continuarem visíveis e preenchidos.' ),
				'Não adicione A7/A8 sem provar que A4–A6 têm qualidade.', $partial ? 'Reavaliar após +3.000 PV.' : 'Reavaliar no próximo dia fechado.'
			);
		}

		if ( $placement ) {
			$out[] = self::action( 'medium', 'Placement', 'Ataque o placement que perdeu participação', 'Mantenha a densidade global e investigue somente o placement apontado.', $placement, 'Média', array( 'Use a tabela Placement e Entrega & Saúde.', 'Cruze RPM de impressão, Active View e cobertura antes de mudar o planner.' ), 'Não altere todo o motor por causa de uma única unidade.', 'Próximo dia fechado.' );
		}

		$mix = self::mix_driver( $breakdowns['platform'] ?? array(), $cur['impression_rpm'] );
		if ( $mix ) {
			$out[] = self::action( 'medium', 'Tráfego', 'Não compense mudança de mix com mais anúncios', 'Faça zero alterações globais de densidade por causa deste sinal.', $mix, 'Média', array( 'Mantenha o motor manual atual.', 'Compare conteúdo/aquisição da plataforma de RPM menor.', 'Reavalie o mix no próximo dia fechado.' ), 'Não use densidade para corrigir tráfego de menor valor.', 'Amanhã.' );
		}

		if ( ! $out ) {
			$out[] = self::action( 'hold', 'Motor manual', 'Sem mudança hoje', 'Mantenha o Revenue Engine atual.', 'Os sinais não são fortes o bastante para justificar alteração.', 'Alta', array( self::account_rule(), 'Não altere cadência, timing ou número de placements hoje.', 'Reabra esta aba quando o dia fechar.' ), 'Sem sinal claro, não mexa.', 'Fechamento do dia.' );
		}

		$order = array( 'high' => 0, 'medium' => 1, 'good' => 2, 'hold' => 3 );
		foreach ( $out as $i => &$row ) { $row['_seq'] = $i; } unset( $row );
		usort( $out, static function( $a, $b ) use ( $order ) {
			$pa = $order[ $a['priority'] ] ?? 9; $pb = $order[ $b['priority'] ] ?? 9;
			return $pa !== $pb ? $pa <=> $pb : ( (int) $a['_seq'] <=> (int) $b['_seq'] );
		} );
		return array_slice( $out, 0, 5 );
	}

	private static function mix_driver( array $section, $overall_irpm ) {
		if ( ! empty( $section['error'] ) ) { return ''; }
		foreach ( (array) ( $section['rows'] ?? array() ) as $row ) {
			$shift = $row['current_impression_share'] - $row['base_impression_share'];
			$irpm = $row['current']['impression_rpm'] ?? null;
			if ( $shift >= 0.10 && is_numeric( $irpm ) && is_numeric( $overall_irpm ) && $irpm < (float) $overall_irpm * 0.82 ) {
				return $row['label'] . ' ganhou ' . number_format_i18n( $shift * 100, 1 ) . ' p.p. de participação nas impressões, mas roda com RPM de impressão de ' . GOAC_UI::money( $irpm ) . ', abaixo da média do dia (' . GOAC_UI::money( $overall_irpm ) . ').';
			}
		}
		return '';
	}

	private static function placement_driver( array $section ) {
		if ( ! empty( $section['error'] ) ) { return ''; }
		foreach ( (array) ( $section['rows'] ?? array() ) as $row ) {
			$shift = $row['current_impression_share'] - $row['base_impression_share'];
			$base_irpm = $row['base']['impression_rpm'] ?? null;
			if ( $shift <= -0.08 && is_numeric( $base_irpm ) && $base_irpm > 0 ) {
				return $row['label'] . ' perdeu ' . number_format_i18n( abs( $shift ) * 100, 1 ) . ' p.p. das impressões versus os 7 dias anteriores; no benchmark esse placement tinha RPM de impressão de ' . GOAC_UI::money( $base_irpm ) . '.';
			}
		}
		return '';
	}

	private static function breakdown_section( array $breakdowns, array $current ) {
		$labels = array( 'platform' => 'Plataforma', 'format' => 'Formato', 'placement' => 'Placement' );
		echo '<div class="goac-grid goac-grid-3 goac-opt-breakdowns">';
		foreach ( $labels as $key => $title ) {
			GOAC_UI::card_open( $title, '<span class="goac-muted">participação no dia</span>' );
			$section = $breakdowns[ $key ] ?? array( 'error' => true );
			if ( ! empty( $section['error'] ) ) {
				GOAC_UI::empty_state( 'A API não aceitou esta quebra para a conta.' );
				GOAC_UI::card_close();
				continue;
			}
			echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Item</th><th class="num">Impr.</th><th class="num">RPM impr.</th><th class="num">Active View</th><th class="num">Δ share</th></tr></thead><tbody>';
			foreach ( array_slice( (array) $section['rows'], 0, 8 ) as $row ) {
				$c = $row['current']; $shift = $row['current_impression_share'] - $row['base_impression_share'];
				echo '<tr><td><strong>' . esc_html( $row['label'] ?: '—' ) . '</strong></td><td class="num">' . esc_html( GOAC_UI::pct( $row['current_impression_share'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $c['impression_rpm'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $c['viewability'] ?? null ) ) . '</td><td class="num">' . esc_html( self::signed_points( $shift ) ) . '</td></tr>';
			}
			echo '</tbody></table></div>';
			GOAC_UI::card_close();
		}
		echo '</div>';
	}

	/** Mathematical scenarios, never an instruction to reach a request quota. */
	public static function rpm_goal_scenarios( array $rows ) {
		$total = GOAC_Stats::sum( $rows );
		$scenarios = array();
		foreach ( array( 3.0, 4.0 ) as $goal ) {
			$scenarios[] = array(
				'goal' => $goal,
				'gap' => is_numeric( $total['page_rpm'] ) ? max( 0, $goal - $total['page_rpm'] ) : null,
				'growth' => is_numeric( $total['page_rpm'] ) && $total['page_rpm'] > 0 ? max( 0, $goal / $total['page_rpm'] - 1 ) : null,
				'target_revenue' => $total['page_views'] > 0 ? $goal * $total['page_views'] / 1000 : null,
				'revenue_gap' => $total['page_views'] > 0 ? max( 0, $goal * $total['page_views'] / 1000 - $total['earnings'] ) : null,
				'impressions_per_page' => is_numeric( $total['impression_rpm'] ) && $total['impression_rpm'] > 0 ? $goal / $total['impression_rpm'] : null,
				'impression_rpm' => is_numeric( $total['impressions_per_page'] ) && $total['impressions_per_page'] > 0 ? $goal / $total['impressions_per_page'] : null,
			);
		}
		return array( 'total' => $total, 'days' => count( $rows ), 'scenarios' => $scenarios );
	}

	private static function rpm_goals_card( array $rows, $from, $to, $currency, array $selected_rows = array(), $selected_day = '' ) {
		$data = self::rpm_goal_scenarios( $rows );
		$total = $data['total'];
		GOAC_UI::card_open( 'Metas de Page RPM: 3 e 4', '<span class="goac-muted">moeda da conta: ' . esc_html( $currency ) . '</span>' );
		if ( $selected_day ) {
			$selected = self::rpm_goal_scenarios( $selected_rows );
			$observed = $selected['total'];
			echo '<p><strong>Dia selecionado: ' . esc_html( $selected_day ) . '</strong> · ' . esc_html( GOAC_UI::number( $selected_rows ? $observed['page_views'] : null ) ) . ' páginas · receita estimada ' . esc_html( GOAC_UI::money( $selected_rows ? $observed['earnings'] : null, 2, $currency ) ) . ' · RPM ' . esc_html( GOAC_UI::money( $observed['page_rpm'], 2, $currency ) ) . '.</p>';
			if ( $observed['page_views'] <= 0 ) {
				echo '<p class="goac-muted">Sem páginas observadas: não há base para calcular receita faltante. Atualize a coleta; não interprete ausência como desempenho zero.</p>';
			} else {
				echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Meta</th><th class="num">Receita nas mesmas páginas</th><th class="num">Receita adicional necessária</th><th class="num">Ganho relativo</th></tr></thead><tbody>';
				foreach ( $selected['scenarios'] as $scenario ) {
					echo '<tr><td>' . esc_html( GOAC_UI::money( $scenario['goal'], 2, $currency ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $scenario['target_revenue'], 2, $currency ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $scenario['revenue_gap'], 2, $currency ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $scenario['growth'] ) ) . '</td></tr>';
				}
				echo '</tbody></table></div><p class="goac-footnote">Fotografia aritmética das páginas já observadas. Novas páginas mudam a receita necessária; a diferença não é uma previsão de quanto falta receber hoje. Use o diagnóstico abaixo para separar entrega de preço/mix.</p>';
			}
		}
		echo '<p>Referência: ' . esc_html( $from . ' a ' . $to ) . ' · ' . esc_html( (string) $data['days'] ) . ' de 7 dias disponíveis. RPM ponderado: <strong>' . esc_html( GOAC_UI::money( $total['page_rpm'], 2, $currency ) ) . '</strong> = receita total ÷ page views totais × 1.000. O dia selecionado não entra nesta referência.</p>';
		if ( $data['days'] < 7 ) { echo '<p class="goac-muted">Há dias ausentes nesta janela; a referência cobre somente os dias disponíveis.</p>'; }
		echo '<div class="goac-table-wrap"><table class="widefat goac-table"><thead><tr><th>Meta</th><th class="num">Ganho necessário</th><th class="num">Impressões/PV se o preço ficar igual</th><th class="num">RPM de impressão se a entrega ficar igual</th></tr></thead><tbody>';
		foreach ( $data['scenarios'] as $row ) {
			echo '<tr><td>' . esc_html( GOAC_UI::money( $row['goal'], 2, $currency ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $row['growth'] ) ) . '</td><td class="num">' . esc_html( GOAC_UI::number( $row['impressions_per_page'], 2 ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $row['impression_rpm'], 2, $currency ) ) . '</td></tr>';
		}
		echo '</tbody></table></div><p class="goac-footnote">Cenários aritméticos, não previsão de receita nem cota de solicitações. O preço pode cair ao adicionar impressões. A janela pode misturar versões do motor: valide a meta em pelo menos 7 dias fechados com uma configuração estável, comparando origem, dispositivo, formato, cobertura e visibilidade. Nenhuma meta altera a entrega automaticamente.</p>';
		GOAC_UI::card_close();
	}

	private static function method_card() {
		GOAC_UI::card_open( 'Como interpretar as sugestões', '<span class="goac-muted">guardrails</span>' );
		echo '<div class="goac-opt-guardrails"><p><strong>Aumentar anúncios</strong> só aparece quando impressões/PV estão claramente abaixo do benchmark, cobertura e Active View continuam saudáveis e a amostra é suficiente.</p><p><strong>Alterações de densidade</strong> exigem comparação estável e uma variável por vez. Variação isolada de RPM ou Active View não justifica cortes automáticos.</p><p><strong>Não mexer</strong> é uma decisão válida: quando o RPM de impressão cai, aumentar carga geralmente não corrige o preço do inventário.</p><p><strong>CTR não é alvo de otimização.</strong> O painel mostra CTR apenas como diagnóstico e nunca recomenda posicionamentos para gerar cliques. Os limiares de volume servem para triagem; não são um teste de significância nem prova de ganho.</p></div>';
		echo '<p class="goac-footnote"><strong>Se o preço/mix cair:</strong> confira a autorização de ads.txt em AdSense → Sites, eventuais restrições de veiculação e mudanças de público, páginas ou dispositivos. Revise bloqueios amplos em Segurança da marca → Conteúdo sem presumir que esta tela conhece a configuração da conta. Uma queda isolada do preço não justifica aumentar indiscriminadamente a carga.</p>';
		echo '<p class="goac-footnote">O painel acompanha posições mensuráveis do tema e conserva o histórico por formato. Âncora e vinheta oficiais permanecem ligadas. Alterações de densidade são avaliadas uma variável por vez no motor manual; o painel não muda os controles da conta.</p>';
		GOAC_UI::card_close();
	}
}
