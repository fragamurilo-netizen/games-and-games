<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Aba Data Lab: coleta sob demanda, dataset, regimes e Mega Relatório. */
final class GOAC_View_Learning {
	public static function render() {
		$r = GOAC_Learning::readiness( true );
		$state = GOAC_Learning::state();
		$model = GOAC_Learning::model();
		$target = (string) $r['target_date'];
		$today = GOAC_API::today();
		$days = max( 0, GOAC_Stats::days_between( $today, $target ) );

		echo '<section class="goac-learning-hero"><div><span class="goac-eyebrow">DATA LAB · MODO LEVE</span><h2>Data Lab sob demanda</h2><p>Nada daqui roda em segundo plano. A coleta enriquecida só acontece quando você pede um lote, e cada lote faz poucas consultas com tempo limitado, sem pesar no site.</p></div><div class="goac-learning-score"><strong>' . esc_html( number_format_i18n( $r['progress'] * 100, 0 ) . '%' ) . '</strong><span>baseline enriquecido</span></div></section>';
		echo '<div class="goac-meter goac-learning-meter"><i style="width:' . esc_attr( (string) round( $r['progress'] * 100, 2 ) ) . '%"></i></div>';
		if ( $today <= $target && $r['progress'] < 1 ) {
			GOAC_UI::notice( 'info', '<strong>Marco de preparação: ' . esc_html( GOAC_UI::date( $target ) ) . '.</strong> Faltam ' . (int) $days . ' dia(s). Se quiser o baseline completo antes da troca do motor, use <strong>Coletar lote agora</strong> algumas vezes. Cada lote é pequeno.' );
		}

		echo '<div class="goac-kpis goac-kpis-compact">';
		GOAC_UI::kpi( 'Histórico diário', GOAC_UI::number( $r['history_days'] ) . ' dias', 'totais e RPM' );
		GOAC_UI::kpi( 'Jobs enriquecidos', GOAC_UI::number( $r['jobs_done'] ) . '/' . GOAC_UI::number( $r['jobs_total'] ), GOAC_UI::number( $r['queue'] ) . ' na fila' );
		GOAC_UI::kpi( 'URLs por dia', GOAC_UI::number( $r['page_days'] ) . ' dias', 'receita por matéria/página' );
		GOAC_UI::kpi( 'Fechamento diário', ! empty( $r['maintenance_date'] ) ? GOAC_UI::date( $r['maintenance_date'] ) : '—', GOAC_UI::number( $r['maintenance_queue'] ) . ' corte(s) pendentes' );
		GOAC_UI::kpi( 'Intradiário total', GOAC_UI::number( $r['intraday_days'] ) . ' dias', 'curva de renda ao longo do dia' );
		GOAC_UI::kpi( 'Intradiário segmentado', GOAC_UI::number( $r['segment_intraday_days'] ) . ' dias', 'coletado até a 3.0 (não coleta mais)' );
		GOAC_UI::kpi( 'Linhas aprendidas', GOAC_UI::number( $r['rows'] ), esc_html( GOAC_UI::number( $r['daily_rows'] ) . ' históricas · ' . GOAC_UI::number( $r['intraday_rows'] ) . ' parciais' . ( $r['counts_at'] ? ' · contado às ' . wp_date( 'H:i', $r['counts_at'] ) : '' ) ) );
		echo '</div>';

		echo '<div class="goac-grid goac-grid-2">';
		self::collection_card( $r, $state );
		self::export_card( $r );
		echo '</div>';

		self::regime_card();
		self::drivers_card( $model );
		self::coverage_card( $state );
	}

	private static function collection_card( array $r, array $state ) {
		$last = $r['updated_at'] ? wp_date( 'd/m/Y H:i', $r['updated_at'], GOAC_API::tz() ) : 'ainda não executada';
		GOAC_UI::card_open( 'Coleta sob demanda', '<span class="goac-pill">manual</span>' );
		echo '<p>Cada clique em <b>Coletar lote agora</b> faz no máximo 4 consultas ao Google e para em cerca de 15 segundos. Sem cron, sem fila rodando sozinha e sem varredura de arquivos do tema.</p>';
		echo '<ul class="goac-checklist"><li><b>365 dias</b> por plataforma, formato, placement, unidade, tamanho, país, origem, lance, targeting, buyer network e outros.</li><li><b>Interações</b> plataforma × formato, plataforma × placement, formato × placement e origem × plataforma.</li><li><b>30 dias de PAGE_URL por dia</b>, até ' . esc_html( number_format_i18n( GOAC_Learning::REPORT_LIMIT ) ) . ' URLs por consulta, com alerta explícito se a API truncar.</li><li><b>Fechamento D+1</b>: no primeiro lote de cada dia, o dia anterior entra na fila com a estimativa mais recente, ainda sujeita a revisão.</li></ul>';
		echo '<p class="goac-muted">Último lote: ' . esc_html( $last ) . '. Combinações que o Google não disponibiliza são registradas como não suportadas, sem travar o restante.</p>';
		if ( ! empty( $r['page_days_truncated'] ) ) { GOAC_UI::notice( 'warning', '<strong>Atenção:</strong> ' . (int) $r['page_days_truncated'] . ' dia(s) de PAGE_URL ultrapassaram o limite de linhas por consulta. Eles estão marcados como truncados no estado e no Mega Relatório; o painel não considera essa cobertura como silenciosamente completa.' ); }
		echo '<p><a class="button button-primary" href="' . esc_url( GOAC_UI::action_url( 'goac_learning_collect' ) ) . '">Coletar lote agora</a></p>';
		echo '<h3 class="goac-subhead">Espaço no banco</h3>';
		echo '<p class="goac-muted">O dataset granular fica na tabela <code>' . esc_html( GOAC_Learning::table_rows() ) . '</code> e pode ficar grande. Apagar remove só esse dataset e a fila; histórico diário, metas, gastos, previsões e eventos de regime continuam.</p>';
		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '"><input type="hidden" name="action" value="goac_learning_purge">' . wp_nonce_field( 'goac_learning_purge', '_wpnonce', true, false ) . '<button class="button button-link-delete" data-goac-confirm="Apagar todo o dataset do Data Lab? Isso não pode ser desfeito. Histórico diário, metas, gastos e eventos continuam.">Apagar dataset do Data Lab</button></form>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		GOAC_UI::card_close();
	}

	private static function export_card( array $r ) {
		GOAC_UI::card_open( 'Mega Relatório', '<span class="goac-pill">ZIP</span>' );
		echo '<p>Baixa um pacote grande para auditoria, backup ou treinamento externo. Ele leva os dados, não apenas gráficos prontos.</p>';
		echo '<ul class="goac-checklist"><li>histórico diário e métricas derivadas;</li><li>intradiário total e segmentado;</li><li>dataset granular de todos os cortes coletados;</li><li>snapshot de conta, sites, unidades, canais, pagamentos, políticas e alertas;</li><li>modelo aprendido + eventos de mudança de configuração;</li><li>mapa de conteúdo do WordPress para ligar URL, matéria e categoria;</li><li>orçamento, distribuição e configurações do painel.</li></ul>';
		echo '<p><a class="button button-primary button-hero" href="' . esc_url( GOAC_UI::action_url( 'goac_export', array( 'source' => 'mega' ) ) ) . '">Baixar relatório gigantesco</a></p>';
		echo '<p class="goac-footnote">Tokens OAuth, Client Secret e credenciais nunca entram no ZIP. Hoje o baseline enriquecido está em ' . esc_html( number_format_i18n( $r['progress'] * 100, 0 ) ) . '%; o manifest do ZIP registra exatamente a cobertura da coleta.</p>';
		GOAC_UI::card_close();
	}

	private static function regime_card() {
		$event = GOAC_Learning::latest_event( 'engine_launch' );
		GOAC_UI::card_open( 'Troca do motor de anúncios', $event ? '<span class="goac-pill ok">regime marcado</span>' : '<span class="goac-pill warn">marcar na implantação</span>' );
		if ( $event ) {
			$when = get_date_from_gmt( (string) $event['event_time'], 'd/m/Y H:i:s' );
			echo '<p><strong>Regime atual começou em ' . esc_html( $when ) . ':</strong> ' . esc_html( $event['label'] ) . '.</p><p class="goac-muted">O modelo usa o fuso da conta, exclui o dia de transição parcial e compara os dias seguintes com os 14 dias anteriores. A comparação é descritiva e não isola causalidade.</p>';
		} else {
			echo '<p>No instante em que o novo motor entrar no ar, use este botão. Ele registra o horário da mudança no log; a comparação será recalculada com o histórico disponível. Não reconstrói mudanças que não foram registradas.</p>';
		}
		echo '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '" class="goac-inline-form">';
		wp_nonce_field( 'goac_mark_engine' );
		echo '<input type="hidden" name="action" value="goac_mark_engine">';
		echo '<label>Nome da mudança<input type="text" name="label" value="Novo motor de anúncios" maxlength="190"></label>';
		echo '<button class="button button-primary" data-goac-confirm="Marcar agora como início de um novo regime?">Marcar novo motor AGORA</button></form>';
		GOAC_UI::card_close();
	}

	private static function drivers_card( array $model ) {
		GOAC_UI::card_open( 'O que o algoritmo já sabe sobre a renda', ! empty( $model['trained_at'] ) ? '<span class="goac-pill ok">treinado</span>' : '' );
		if ( empty( $model['drivers'] ) ) { GOAC_UI::empty_state( 'O primeiro modelo será montado assim que os cortes enriquecidos começarem a chegar.' ); GOAC_UI::card_close(); return; }
		echo '<p class="goac-footnote">Modelo calculado em ' . esc_html( (string) ( $model['trained_at'] ?? 'não informado' ) ) . '; dados até ' . esc_html( (string) ( $model['training_window'][1] ?? 'não informado' ) ) . '. Atualização sob demanda, sem controle automático do inventário. Active View agregado é aproximado e exclui observações ausentes.</p>';
		if ( (int) ( $model['version'] ?? 0 ) < 3 ) { echo '<p class="goac-muted">Modelo anterior à correção de métricas: colete um lote para recalcular os cortes e regimes com a versão atual.</p>'; }
		$base = (array) ( $model['baseline_90d'] ?? array() );
		if ( $base ) {
			$weighted = GOAC_Stats::derive( $base );
			echo '<div class="goac-kpis goac-kpis-compact goac-kpis-inside">';
			GOAC_UI::kpi( 'Page RPM ponderado · 90d', GOAC_UI::money( $weighted['page_rpm'] ?? null, 2, GOAC_Store::currency() ), '' );
			GOAC_UI::kpi( 'RPM impressão ponderado', GOAC_UI::money( $weighted['impression_rpm'] ?? null, 2, GOAC_Store::currency() ), '' );
			GOAC_UI::kpi( 'Impressões/PV', GOAC_UI::number( $base['impressions_per_page'] ?? null, 2 ), '' );
			GOAC_UI::kpi( 'Cobertura mediana', GOAC_UI::pct( $base['coverage_median'] ?? null ), '' );
			GOAC_UI::kpi( 'Active View mediano', GOAC_UI::pct( $base['viewability_median'] ?? null ), '' );
			echo '</div>';
		}
		$ref = (array) ( $model['reference_success'] ?? array() );
		if ( $ref ) {
			$reference = GOAC_Stats::derive( $ref );
			echo '<p class="goac-muted"><strong>Benchmark preservado 13–19/08:</strong> Page RPM ponderado ' . esc_html( GOAC_UI::money( $reference['page_rpm'] ?? null, 2, GOAC_Store::currency() ) ) . ' · RPM de impressão ' . esc_html( GOAC_UI::money( $reference['impression_rpm'] ?? null, 2, GOAC_Store::currency() ) ) . ' · ' . esc_html( GOAC_UI::number( $ref['impressions_per_page'] ?? null, 2 ) ) . ' impressões/PV. O valor é recalculado dos dados coletados, não hardcoded.</p>';
		}
		$profile = (array) ( $model['intraday_profile'] ?? array() );
		if ( $profile ) { echo '<p class="goac-muted"><strong>Curva intradiária:</strong> ' . esc_html( (string) ( $profile['source'] ?? 'default' ) ) . ' com ' . (int) ( $profile['days'] ?? 0 ) . ' dia(s) úteis de amostra. Ela é recalculada ao atualizar o modelo com os lotes coletados; source=default não é aprendizagem observada.</p>'; }
		echo '<div class="goac-table-wrap"><table class="widefat goac-table goac-table-compact"><thead><tr><th>Corte</th><th>Maior fonte de receita</th><th class="num">Participação</th><th class="num">RPM imp.</th><th class="num">Active View</th></tr></thead><tbody>';
		foreach ( $model['drivers'] as $driver ) {
			$top = (array) ( $driver['values'][0] ?? array() ); if ( ! $top ) { continue; }
			echo '<tr><th>' . esc_html( $driver['label'] ) . '</th><td class="goac-dim-cell" title="' . esc_attr( $top['value'] ) . '">' . esc_html( $top['value'] ?: '(sem valor)' ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $top['share'] ?? null ) ) . '</td><td class="num">' . esc_html( GOAC_UI::money( $top['impression_rpm'] ?? null, 2, GOAC_Store::currency() ) ) . '</td><td class="num">' . esc_html( GOAC_UI::pct( $top['viewability'] ?? null ) ) . '</td></tr>';
		}
		echo '</tbody></table></div>';
		echo '<p class="goac-footnote">“Saber” aqui significa ter evidência quantitativa do seu próprio inventário. O painel não trata correlação como causalidade; mudanças de motor/configuração são registradas separadamente justamente para comparar o antes e o depois.</p>';
		GOAC_UI::card_close();
	}

	private static function coverage_card( array $state ) {
		$unsupported = (array) $state['unsupported']; $failed = (array) $state['failed'];
		GOAC_UI::card_open( 'Cobertura e falhas da coleta' );
		if ( ! $unsupported && ! $failed ) {
			echo '<p><span class="goac-pill ok">sem erros permanentes</span> Nenhuma falha registrada nos lotes coletados.</p>';
		} else {
			echo '<p>' . count( $unsupported ) . ' job(s) incompatíveis com a combinação oferecida pela API e ' . count( $failed ) . ' tentativa(s) temporárias registradas.</p>';
			if ( $unsupported ) { echo '<details class="goac-generic"><summary>Combinações não suportadas</summary><pre>' . esc_html( wp_json_encode( array_slice( $unsupported, 0, 50, true ), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE ) ) . '</pre></details>'; }
			if ( $failed ) { echo '<details class="goac-generic"><summary>Erros temporários/retries</summary><pre>' . esc_html( wp_json_encode( array_slice( $failed, 0, 50, true ), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE ) ) . '</pre></details>'; }
		}
		GOAC_UI::card_close();
	}
}
