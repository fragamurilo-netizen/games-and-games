<?php
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Aba Testes por dia: o resultado de um teste de calendário, lido da receita
 * que o Google realmente reportou.
 *
 * O tema não mede receita e não tenta. A atribuição vive em
 * inc/ads/calendar-trials.php e é aritmética sobre a data: cada dia inteiro
 * roda um braço, todo leitor daquele dia vê a mesma configuração. Esta tela só
 * reúne os dias por braço e mostra os totais que a conta já reportou.
 *
 * Duas leituras, porque uma sozinha engana:
 *
 *  - Os TOTAIS por braço respondem "quanto rendeu no período", mas somam dias
 *    que não são comparáveis entre si.
 *  - As RODADAS emparelham cada braço com os dias vizinhos do outro. Como o
 *    rodízio avança um dia por vez e a semana tem sete, dias consecutivos caem
 *    em dias da semana diferentes: o fim de semana entra nos dois braços em vez
 *    de pertencer a um. A dispersão entre rodadas é a régua honesta da
 *    diferença — se as rodadas se dividem quase meio a meio, a média não
 *    significa nada ainda.
 *
 * O que isto não é: um experimento aleatorizado. Um dia de calendário não é
 * unidade controlada, e um evento de um dia só — uma alta no Discover, uma
 * queda de rede, uma notícia grande — pertence ao braço dono daquela data.
 * Nada aqui estabelece causa.
 */
final class GOAC_View_Trials {

	/** Só dias fechados entram: o dia corrente é parcial e desequilibraria o braço que o possui. */
	private static function complete_days( array $rows, $today ) {
		$out = array();
		foreach ( $rows as $date => $row ) {
			if ( $date < $today ) { $out[ $date ] = $row; }
		}
		return $out;
	}

	/**
	 * Junta os dias reportados aos braços que os possuíam.
	 *
	 * @return array<string,mixed>
	 */
	public static function dataset() {
		if ( ! function_exists( 'go_verge_ads_active_trial' ) ) { return array( 'trial' => null ); }
		$trial = go_verge_ads_active_trial();
		if ( ! $trial ) { return array( 'trial' => null ); }

		$c        = GOAC_UI::context();
		$today    = $c['today'];
		$first    = (string) $c['first_day'];
		/* Nunca antes do dia em que o teste foi visto rodando: dias anteriores
		 * rodaram outra configuração e não pertencem a braço nenhum. */
		$declared = function_exists( 'go_verge_ads_trial_reportable_start' )
			? go_verge_ads_trial_reportable_start( $trial )
			: (string) $trial['start'];
		$start    = $declared > $first ? $declared : ( $first ?: $declared );
		$rows     = self::complete_days( GOAC_UI::rows( $start, $today ), $today );
		$calendar = go_verge_ads_trial_calendar( $start, $today );

		$arms = array();
		foreach ( array_keys( (array) $trial['arms'] ) as $index => $key ) {
			$arms[ $key ] = array( 'key' => $key, 'index' => $index, 'baseline' => 0 === $index, 'dates' => array(), 'rows' => array() );
		}

		$blocks = array();
		foreach ( $rows as $date => $row ) {
			if ( ! isset( $calendar[ $date ] ) ) { continue; }
			$assignment = $calendar[ $date ];
			$arm        = $assignment['arm'];
			if ( ! isset( $arms[ $arm ] ) ) { continue; }
			$arms[ $arm ]['dates'][] = $date;
			$arms[ $arm ]['rows'][]  = $row;
			$blocks[ (int) $assignment['block'] ][ $arm ][] = $row;
		}
		foreach ( $arms as $key => $arm ) {
			$arms[ $key ]['days']  = count( $arm['rows'] );
			$arms[ $key ]['total'] = GOAC_Stats::sum( $arm['rows'] );
		}

		/*
		 * Uma rodada é um giro completo do rodízio: um bloco de cada braço, na
		 * ordem. Só rodadas completas entram, senão o braço que aparece mais
		 * vezes no fim do período carrega a média sozinho.
		 */
		$keys      = array_keys( $arms );
		$count     = max( 1, count( $keys ) );
		$baseline  = $keys[0];
		$rounds    = array();
		ksort( $blocks );
		foreach ( $blocks as $block => $by_arm ) {
			$round = (int) floor( $block / $count );
			foreach ( $by_arm as $arm => $list ) {
				foreach ( $list as $row ) { $rounds[ $round ][ $arm ][] = $row; }
			}
		}
		$paired = array();
		foreach ( $rounds as $round => $by_arm ) {
			if ( count( $by_arm ) !== $count ) { continue; }
			$entry = array( 'round' => $round, 'arms' => array() );
			foreach ( $by_arm as $arm => $list ) { $entry['arms'][ $arm ] = GOAC_Stats::sum( $list ); }
			$base_rpm = $entry['arms'][ $baseline ]['page_rpm'] ?? null;
			if ( null === $base_rpm || $base_rpm <= 0 ) { continue; }
			$entry['delta'] = array();
			foreach ( $entry['arms'] as $arm => $summary ) {
				if ( $arm === $baseline ) { continue; }
				$rpm = $summary['page_rpm'] ?? null;
				$entry['delta'][ $arm ] = ( null === $rpm ) ? null : ( $rpm - $base_rpm ) / $base_rpm;
			}
			$paired[] = $entry;
		}

		/* Resumo emparelhado por braço: média, mediana e quantas rodadas cada
		 * lado venceu. A contagem é o que diz se a média é um sinal ou ruído. */
		$summary = array();
		foreach ( $keys as $arm ) {
			if ( $arm === $baseline ) { continue; }
			$deltas = array();
			foreach ( $paired as $entry ) {
				if ( isset( $entry['delta'][ $arm ] ) && null !== $entry['delta'][ $arm ] ) { $deltas[] = (float) $entry['delta'][ $arm ]; }
			}
			$wins = 0;
			foreach ( $deltas as $delta ) { if ( $delta > 0 ) { $wins++; } }
			$summary[ $arm ] = array(
				'rounds' => count( $deltas ),
				'mean'   => $deltas ? GOAC_Stats::mean( $deltas ) : null,
				'median' => $deltas ? GOAC_Stats::median( $deltas ) : null,
				'wins'   => $wins,
			);
		}

		return array(
			'trial' => $trial, 'arms' => $arms, 'baseline' => $baseline,
			'paired' => $paired, 'summary' => $summary, 'calendar' => $calendar,
			'start' => $start, 'declared_start' => $declared, 'today' => $today,
			'assignment' => function_exists( 'go_verge_ads_trial_assignment' ) ? go_verge_ads_trial_assignment() : null,
		);
	}

	private static function arm_label( array $trial, $key ) {
		$arms = (array) $trial['arms'];
		return empty( $arms[ $key ] ) ? $key . ' (linha de base)' : $key;
	}

	public static function render() {
		$data = self::dataset();

		if ( empty( $data['trial'] ) ) {
			GOAC_UI::card_open( 'Testes por dia de calendário' );
			GOAC_UI::empty_state( 'Nenhum teste habilitado. Enquanto não houver um, a tabela de entrega do tema vale para todos os dias, sem alteração.' );
			echo '<p class="description">Um teste é declarado pelo filtro <code>go_verge_ads_trials</code>, com data de início e pelo menos dois braços — o primeiro sendo a linha de base, que não sobrescreve nada. O rodízio avança um dia por vez: todo leitor do mesmo dia recebe a mesma configuração, e os relatórios diários do AdSense separam os braços sozinhos. Não há sorteio de grupos nem divisão de audiência.</p>';
			GOAC_UI::card_close();
			return;
		}

		$trial = $data['trial'];
		$today_arm = $data['assignment'];

		GOAC_UI::card_open(
			'Teste por dia: ' . (string) ( $trial['label'] ?? $trial['id'] ),
			$today_arm ? '<span class="goac-pill">Hoje: ' . esc_html( self::arm_label( $trial, $today_arm['arm'] ) ) . '</span>' : ''
		);
		if ( ! empty( $trial['note'] ) ) {
			echo '<p class="description">' . esc_html( (string) $trial['note'] ) . '</p>';
		}
		echo '<p class="description">Início em ' . esc_html( GOAC_UI::date( $trial['start'] ) ) . ', rodízio a cada ' . esc_html( (string) (int) $trial['days'] ) . ' dia(s). Só dias fechados entram; o dia corrente é parcial.';
		if ( ! empty( $data['declared_start'] ) && $data['declared_start'] > $trial['start'] ) {
			echo ' <strong>A contagem começa em ' . esc_html( GOAC_UI::date( $data['declared_start'] ) ) . '</strong>, primeiro dia em que o teste foi visto rodando — dias anteriores rodaram outra configuração e ficam de fora.';
		}
		echo '</p>';

		echo '<div class="goac-kpis">';
		foreach ( $data['arms'] as $key => $arm ) {
			$total = $arm['total'];
			GOAC_UI::kpi(
				self::arm_label( $trial, $key ),
				GOAC_UI::money( $total['page_rpm'], 2 ) . ' RPM',
				esc_html( $arm['days'] . ' dia(s) · ' . GOAC_UI::money( $total['earnings'] ) . ' · ' . GOAC_UI::number( $total['page_views'] ) . ' PV' )
			);
		}
		echo '</div>';
		GOAC_UI::card_close();

		GOAC_UI::card_open( 'Comparação emparelhada por rodada' );
		if ( empty( $data['paired'] ) ) {
			GOAC_UI::empty_state( 'Ainda não há uma rodada completa — cada braço precisa de pelo menos um bloco fechado no mesmo giro do rodízio.' );
		} else {
			echo '<table class="goac-table"><thead><tr><th scope="col">Braço</th><th scope="col" class="num">Rodadas</th><th scope="col" class="num">Diferença média de Page RPM</th><th scope="col" class="num">Mediana</th><th scope="col" class="num">Rodadas a favor</th></tr></thead><tbody>';
			foreach ( $data['summary'] as $arm => $row ) {
				echo '<tr><th scope="row">' . esc_html( $arm ) . ' vs ' . esc_html( $data['baseline'] ) . '</th>'
					. '<td class="num">' . esc_html( GOAC_UI::number( $row['rounds'] ) ) . '</td>'
					. '<td class="num">' . esc_html( GOAC_UI::signed_pct( $row['mean'] ) ) . '</td>'
					. '<td class="num">' . esc_html( GOAC_UI::signed_pct( $row['median'] ) ) . '</td>'
					. '<td class="num">' . esc_html( $row['wins'] . ' de ' . $row['rounds'] ) . '</td></tr>';
			}
			echo '</tbody></table>';
			echo '<p class="description"><strong>Como ler:</strong> a contagem de rodadas a favor vale mais que a média. Perto de metade, a diferença é ruído do dia a dia, por maior que a média pareça. Um teste de calendário remove o que varia devagar — dia da semana e, com rodadas suficientes, tendência e sazonalidade —, mas não remove um evento de um dia só, e não estabelece causa.</p>';
		}
		GOAC_UI::card_close();

		GOAC_UI::card_open( 'Dias' );
		echo '<table class="goac-table"><thead><tr><th scope="col">Dia</th><th scope="col">Braço</th><th scope="col" class="num">Receita</th><th scope="col" class="num">Page views</th><th scope="col" class="num">Page RPM</th><th scope="col" class="num">Impr./PV</th></tr></thead><tbody>';
		$listed = array();
		foreach ( $data['arms'] as $key => $arm ) {
			foreach ( $arm['dates'] as $index => $date ) {
				$listed[ $date ] = array( 'arm' => $key, 'row' => GOAC_Stats::derive( $arm['rows'][ $index ] ) );
			}
		}
		krsort( $listed );
		foreach ( array_slice( $listed, 0, 120, true ) as $date => $item ) {
			echo '<tr><th scope="row">' . esc_html( GOAC_UI::date( $date ) . ' ' . GOAC_UI::weekday( $date ) ) . '</th>'
				. '<td>' . esc_html( $item['arm'] ) . '</td>'
				. '<td class="num">' . esc_html( GOAC_UI::money( $item['row']['earnings'] ) ) . '</td>'
				. '<td class="num">' . esc_html( GOAC_UI::number( $item['row']['page_views'] ) ) . '</td>'
				. '<td class="num">' . esc_html( GOAC_UI::money( $item['row']['page_rpm'], 2 ) ) . '</td>'
				. '<td class="num">' . esc_html( GOAC_UI::number( $item['row']['impressions_per_page'], 2 ) ) . '</td></tr>';
		}
		echo '</tbody></table>';
		GOAC_UI::card_close();
	}
}
