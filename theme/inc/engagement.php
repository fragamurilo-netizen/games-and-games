<?php
/**
 * Reader engagement: polls, quizzes, prediction boxes, in-article comparator,
 * richer comments (likes, badges, pinning, sorting) and the editorial
 * question shown right above the conversation.
 *
 * Everything is shortcode-first so it works in the classic editor and in
 * Gutenberg, and votes are stored as aggregates only — no reader PII.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/* --------------------------------------------------------------------------
 * Assets
 * ------------------------------------------------------------------------ */

/**
 * Front-end engagement runtime. Loaded only where interaction can happen.
 */
function go_verge_engagement_assets() {
	/* Keep the runtime/nonce off home, archives, search and entity hubs. Posts
	 * use these components by design; other singular types opt in only when
	 * their content or comment area can actually need the interaction runtime. */
	if ( is_admin() || ! is_singular() ) {
		return;
	}

	$should_load = is_singular( 'post' );
	$post        = get_queried_object();

	if ( ! $should_load && $post instanceof WP_Post ) {
		$content = (string) $post->post_content;
		$shortcodes = array( 'go_enquete', 'go_quiz', 'go_previsao', 'go_comparador' );

		foreach ( $shortcodes as $shortcode ) {
			if ( has_shortcode( $content, $shortcode ) ) {
				$should_load = true;
				break;
			}
		}

		if ( ! $should_load && false !== strpos( $content, '<!-- wp:game-overdrive/' ) ) {
			$should_load = true;
		}

		if ( ! $should_load && ( comments_open( $post->ID ) || get_comments_number( $post->ID ) > 0 ) ) {
			$should_load = true;
		}
	}

	if ( ! $should_load ) {
		return;
	}

	$rel = '/assets/js/engagement.min.js';
	wp_enqueue_script(
		'go-verge-engagement',
		GO_VERGE_URI . $rel,
		array(),
		go_verge_asset_version( $rel ),
		true
	);
	wp_script_add_data( 'go-verge-engagement', 'strategy', 'defer' );

	wp_localize_script(
		'go-verge-engagement',
		'GoVergeEngage',
		array(
			'ajaxUrl' => admin_url( 'admin-ajax.php' ),
			'nonce'   => wp_create_nonce( 'go_verge_engage' ),
			'i18n'    => array(
				'voted'        => __( 'Voto registrado', 'go-verge' ),
				'error'        => __( 'Não foi possível registrar agora. Tente de novo.', 'go-verge' ),
				'correct'      => __( 'Você acertou!', 'go-verge' ),
				'wrong'        => __( 'Não foi dessa vez.', 'go-verge' ),
				'yourAnswer'   => __( 'Sua resposta', 'go-verge' ),
				'hit'          => __( 'Você acertou a previsão! 🎯', 'go-verge' ),
				'miss'         => __( 'Sua previsão não se confirmou.', 'go-verge' ),
				'liked'        => __( 'Comentário curtido', 'go-verge' ),
				'unliked'      => __( 'Curtida removida', 'go-verge' ),
				'quizScore'    => __( 'Seu placar: %1$s de %2$s', 'go-verge' ),
				'votes'        => __( 'votos', 'go-verge' ),
			),
		)
	);
}
add_action( 'wp_enqueue_scripts', 'go_verge_engagement_assets', 1650 );

/**
 * Shared visitor-vote guard: one vote per browser per key, kept in a cookie.
 * This is engagement tooling, not an election — cookie dedupe is enough.
 */
function go_verge_engage_has_voted( $key ) {
	// A vote for option 0 stores the string "0", which empty() would swallow.
	return isset( $_COOKIE[ 'go_v_' . $key ] ) && '' !== (string) $_COOKIE[ 'go_v_' . $key ];
}

/** Remember a vote for a year. */
function go_verge_engage_remember_vote( $key, $value = '1' ) {
	setcookie( 'go_v_' . $key, (string) $value, time() + YEAR_IN_SECONDS, '/', '', is_ssl(), false );
}

/* --------------------------------------------------------------------------
 * Enquete (poll) — [go_enquete pergunta="..." opcoes="A|B|C"]
 * ------------------------------------------------------------------------ */

/** Stable storage key for a poll. */
function go_verge_poll_key( $id, $question, $options ) {
	$seed = '' !== $id ? $id : $question . '|' . implode( '|', $options );
	return substr( md5( $seed ), 0, 16 );
}

/** Aggregate counts for a poll (option index => votes). */
function go_verge_poll_counts( $key, $option_total ) {
	$counts = get_option( 'go_verge_poll_' . $key, array() );
	$counts = is_array( $counts ) ? array_map( 'absint', $counts ) : array();
	return array_replace( array_fill( 0, $option_total, 0 ), array_intersect_key( $counts, array_fill( 0, $option_total, 0 ) ) );
}

/**
 * Whether a poll key belongs to a poll that has actually been published.
 *
 * The vote endpoint is public by design, and its key used to come straight from
 * the request into `update_option( 'go_verge_poll_' . $key )`. Anyone holding a
 * (public) engagement nonce could therefore write an unbounded number of rows
 * into wp_options with keys no poll ever used. Registering the row when the poll
 * first renders turns "does this row exist" into a real allowlist, at the cost of
 * exactly one write per poll in the site's lifetime.
 *
 * @param string $key Poll storage key.
 * @return bool
 */
function go_verge_poll_is_registered( $key ) {
	if ( ! preg_match( '/^[a-f0-9]{16}$/', (string) $key ) ) {
		return false;
	}

	return null !== get_option( 'go_verge_poll_' . $key, null );
}

/**
 * Create the storage row for a poll the first time it is rendered.
 *
 * @param string $key          Poll storage key.
 * @param int    $option_total Number of options.
 * @return void
 */
function go_verge_poll_register( $key, $option_total ) {
	if ( ! preg_match( '/^[a-f0-9]{16}$/', (string) $key ) ) {
		return;
	}
	if ( null !== get_option( 'go_verge_poll_' . $key, null ) ) {
		return;
	}

	add_option( 'go_verge_poll_' . $key, array_fill( 0, max( 2, (int) $option_total ), 0 ), '', false );
}

function go_verge_poll_shortcode( $atts ) {
	$atts = shortcode_atts(
		array(
			'pergunta' => '',
			'opcoes'   => '',
			'id'       => '',
		),
		$atts,
		'go_enquete'
	);

	$question = trim( (string) $atts['pergunta'] );
	$options  = array_values( array_filter( array_map( 'trim', explode( '|', (string) $atts['opcoes'] ) ), 'strlen' ) );
	if ( '' === $question || count( $options ) < 2 ) {
		return '';
	}

	$key    = go_verge_poll_key( sanitize_key( $atts['id'] ), $question, $options );
	go_verge_poll_register( $key, count( $options ) );
	$counts = go_verge_poll_counts( $key, count( $options ) );
	$total  = array_sum( $counts );
	$voted  = go_verge_engage_has_voted( $key );

	ob_start();
	?>
	<div class="go-poll" data-go-poll="<?php echo esc_attr( $key ); ?>" data-total="<?php echo esc_attr( $total ); ?>"<?php echo $voted ? ' data-voted="1"' : ''; ?>>
		<p class="go-interactive-kicker"><span aria-hidden="true">◈</span> <?php esc_html_e( 'Enquete', 'go-verge' ); ?></p>
		<p class="go-poll__question"><?php echo esc_html( $question ); ?></p>
		<div class="go-poll__options" role="group" aria-label="<?php echo esc_attr( $question ); ?>">
			<?php foreach ( $options as $index => $option ) : ?>
				<button type="button" class="go-poll__option" data-option="<?php echo esc_attr( $index ); ?>" data-count="<?php echo esc_attr( $counts[ $index ] ); ?>"<?php disabled( $voted ); ?>>
					<span class="go-poll__option-bar" aria-hidden="true"></span>
					<span class="go-poll__option-label"><?php echo esc_html( $option ); ?></span>
					<span class="go-poll__option-pct" data-go-pct hidden></span>
				</button>
			<?php endforeach; ?>
		</div>
		<p class="go-poll__meta">
			<span class="go-poll__status" data-go-poll-status role="status"></span>
			<span class="go-poll__total" data-go-poll-total><?php echo esc_html( sprintf( _n( '%s voto', '%s votos', $total, 'go-verge' ), number_format_i18n( $total ) ) ); ?></span>
		</p>
	</div>
	<?php
	return ob_get_clean();
}
add_shortcode( 'go_enquete', 'go_verge_poll_shortcode' );

/** AJAX: register a poll vote and return fresh totals. */
function go_verge_ajax_poll_vote() {
	check_ajax_referer( 'go_verge_engage', 'nonce' );

	$key    = isset( $_POST['poll'] ) ? sanitize_key( wp_unslash( $_POST['poll'] ) ) : '';
	$option = isset( $_POST['option'] ) ? absint( wp_unslash( $_POST['option'] ) ) : 0;
	$total_options = isset( $_POST['options'] ) ? min( 12, max( 2, absint( wp_unslash( $_POST['options'] ) ) ) ) : 2;

	if ( '' === $key || $option >= $total_options || ! go_verge_poll_is_registered( $key ) ) {
		wp_send_json_error( array( 'message' => __( 'Voto inválido.', 'go-verge' ) ), 400 );
	}
	if ( go_verge_engage_has_voted( $key ) ) {
		wp_send_json_error( array( 'message' => __( 'Você já votou nesta enquete.', 'go-verge' ) ), 409 );
	}

	$counts = go_verge_poll_counts( $key, $total_options );
	$counts[ $option ]++;
	update_option( 'go_verge_poll_' . $key, $counts, false );
	go_verge_engage_remember_vote( $key, (string) $option );

	wp_send_json_success(
		array(
			'counts' => array_values( $counts ),
			'total'  => array_sum( $counts ),
		)
	);
}
add_action( 'wp_ajax_go_verge_poll_vote', 'go_verge_ajax_poll_vote' );
add_action( 'wp_ajax_nopriv_go_verge_poll_vote', 'go_verge_ajax_poll_vote' );

/* --------------------------------------------------------------------------
 * Quiz — [go_quiz pergunta="..." opcoes="A|B|C" correta="1" explicacao="..."]
 * Feedback is instant and client-side; when a page has several quizzes the
 * runtime shows a running score after the last answer.
 * ------------------------------------------------------------------------ */

function go_verge_quiz_shortcode( $atts ) {
	$atts = shortcode_atts(
		array(
			'pergunta'   => '',
			'opcoes'     => '',
			'correta'    => '1',
			'explicacao' => '',
		),
		$atts,
		'go_quiz'
	);

	$question = trim( (string) $atts['pergunta'] );
	$options  = array_values( array_filter( array_map( 'trim', explode( '|', (string) $atts['opcoes'] ) ), 'strlen' ) );
	$correct  = max( 1, absint( $atts['correta'] ) );
	if ( '' === $question || count( $options ) < 2 || $correct > count( $options ) ) {
		return '';
	}

	ob_start();
	?>
	<div class="go-quiz" data-go-quiz data-correct="<?php echo esc_attr( $correct - 1 ); ?>">
		<p class="go-interactive-kicker go-interactive-kicker--quiz"><span aria-hidden="true">?</span> <?php esc_html_e( 'Quiz', 'go-verge' ); ?></p>
		<p class="go-quiz__question"><?php echo esc_html( $question ); ?></p>
		<div class="go-quiz__options" role="group" aria-label="<?php echo esc_attr( $question ); ?>">
			<?php foreach ( $options as $index => $option ) : ?>
				<button type="button" class="go-quiz__option" data-option="<?php echo esc_attr( $index ); ?>">
					<span class="go-quiz__letter" aria-hidden="true"><?php echo esc_html( chr( 65 + $index ) ); ?></span>
					<span><?php echo esc_html( $option ); ?></span>
				</button>
			<?php endforeach; ?>
		</div>
		<p class="go-quiz__feedback" data-go-quiz-feedback role="status" hidden></p>
		<?php if ( '' !== trim( (string) $atts['explicacao'] ) ) : ?>
			<p class="go-quiz__explain" data-go-quiz-explain hidden><?php echo esc_html( trim( (string) $atts['explicacao'] ) ); ?></p>
		<?php endif; ?>
		<p class="go-quiz__score" data-go-quiz-score role="status" hidden></p>
	</div>
	<?php
	return ob_get_clean();
}
add_shortcode( 'go_quiz', 'go_verge_quiz_shortcode' );

/* --------------------------------------------------------------------------
 * Caixa de previsão — CPT + [go_previsao id="123"]
 * Readers vote before an event; the editor settles the result afterwards and
 * returning readers see whether they called it.
 * ------------------------------------------------------------------------ */

/** Register the (non-public) prediction content type. */
function go_verge_register_prediction_cpt() {
	register_post_type(
		'go_prediction',
		array(
			'labels'              => array(
				'name'          => __( 'Previsões', 'go-verge' ),
				'singular_name' => __( 'Previsão', 'go-verge' ),
				'add_new_item'  => __( 'Nova previsão', 'go-verge' ),
				'edit_item'     => __( 'Editar previsão', 'go-verge' ),
				'menu_name'     => __( 'Previsões', 'go-verge' ),
			),
			'public'              => false,
			'show_ui'             => true,
			'show_in_menu'        => true,
			'menu_icon'           => 'dashicons-chart-line',
			'menu_position'       => 26,
			'supports'            => array( 'title' ),
			'exclude_from_search' => true,
			'publicly_queryable'  => false,
			'show_in_rest'        => false,
			'capability_type'     => 'post',
		)
	);
}
add_action( 'init', 'go_verge_register_prediction_cpt', 20 );

/** Prediction state helpers. */
function go_verge_prediction_data( $prediction_id ) {
	$prediction = get_post( $prediction_id );
	if ( ! $prediction || 'go_prediction' !== $prediction->post_type || 'publish' !== $prediction->post_status ) {
		return null;
	}

	$options = get_post_meta( $prediction_id, '_go_prediction_options', true );
	$options = is_array( $options ) ? array_values( array_filter( array_map( 'trim', $options ), 'strlen' ) ) : array();
	if ( count( $options ) < 2 ) {
		return null;
	}

	$counts = get_post_meta( $prediction_id, '_go_prediction_counts', true );
	$counts = is_array( $counts ) ? array_map( 'absint', $counts ) : array();
	$counts = array_replace( array_fill( 0, count( $options ), 0 ), array_intersect_key( $counts, array_fill( 0, count( $options ), 0 ) ) );

	$result   = get_post_meta( $prediction_id, '_go_prediction_result', true );
	$result   = ( '' === $result || null === $result ) ? -1 : (int) $result;
	$deadline = (string) get_post_meta( $prediction_id, '_go_prediction_deadline', true );
	$deadline_ts = $deadline ? strtotime( $deadline . ' ' . wp_timezone_string() ) : 0;
	if ( $deadline && ! $deadline_ts ) {
		$deadline_ts = strtotime( $deadline );
	}

	$is_settled = $result >= 0 && $result < count( $options );
	$is_closed  = $is_settled || ( $deadline_ts && time() > $deadline_ts );

	return array(
		'id'          => $prediction_id,
		'question'    => get_the_title( $prediction ),
		'context'     => (string) get_post_meta( $prediction_id, '_go_prediction_context', true ),
		'options'     => $options,
		'counts'      => $counts,
		'total'       => array_sum( $counts ),
		'result'      => $is_settled ? $result : -1,
		'is_settled'  => $is_settled,
		'is_closed'   => $is_closed,
		'deadline_ts' => $deadline_ts,
	);
}

function go_verge_prediction_shortcode( $atts ) {
	$atts = shortcode_atts( array( 'id' => 0 ), $atts, 'go_previsao' );
	$data = go_verge_prediction_data( absint( $atts['id'] ) );
	if ( ! $data ) {
		return '';
	}

	$voted_key = 'p' . $data['id'];
	$voted     = go_verge_engage_has_voted( $voted_key );
	$state     = $data['is_settled'] ? 'settled' : ( $data['is_closed'] ? 'closed' : 'open' );

	ob_start();
	?>
	<div class="go-prediction<?php echo 'settled' === $state ? ' is-settled' : ''; ?>" data-go-prediction="<?php echo esc_attr( $data['id'] ); ?>" data-state="<?php echo esc_attr( $state ); ?>" data-result="<?php echo esc_attr( $data['result'] ); ?>"<?php echo $voted ? ' data-voted="1"' : ''; ?>>
		<p class="go-interactive-kicker go-interactive-kicker--prediction"><span aria-hidden="true">◔</span> <?php esc_html_e( 'Caixa de previsão', 'go-verge' ); ?></p>
		<p class="go-prediction__question"><?php echo esc_html( $data['question'] ); ?></p>
		<?php if ( '' !== $data['context'] ) : ?>
			<p class="go-prediction__context"><?php echo esc_html( $data['context'] ); ?></p>
		<?php endif; ?>

		<div class="go-prediction__options" role="group" aria-label="<?php echo esc_attr( $data['question'] ); ?>">
			<?php foreach ( $data['options'] as $index => $option ) : ?>
				<button
					type="button"
					class="go-prediction__option<?php echo $data['is_settled'] && $index === $data['result'] ? ' is-correct' : ''; ?>"
					data-option="<?php echo esc_attr( $index ); ?>"
					data-count="<?php echo esc_attr( $data['counts'][ $index ] ); ?>"
					<?php disabled( $voted || 'open' !== $state ); ?>
				>
					<span class="go-prediction__option-bar" aria-hidden="true"></span>
					<span class="go-prediction__option-label"><?php echo esc_html( $option ); ?></span>
					<span class="go-prediction__option-pct" data-go-pct hidden></span>
					<?php if ( $data['is_settled'] && $index === $data['result'] ) : ?>
						<span class="go-prediction__flag"><?php esc_html_e( 'Aconteceu', 'go-verge' ); ?></span>
					<?php endif; ?>
				</button>
			<?php endforeach; ?>
		</div>

		<p class="go-prediction__verdict" data-go-prediction-verdict role="status" hidden></p>

		<p class="go-prediction__meta">
			<span data-go-prediction-status role="status">
				<?php
				if ( 'settled' === $state ) {
					esc_html_e( 'Resultado confirmado pela redação.', 'go-verge' );
				} elseif ( 'closed' === $state ) {
					esc_html_e( 'Votação encerrada — aguardando o resultado.', 'go-verge' );
				} elseif ( $data['deadline_ts'] ) {
					printf(
						/* translators: %s: localized date. */
						esc_html__( 'Vote até %s.', 'go-verge' ),
						esc_html( wp_date( get_option( 'date_format' ) . ' — H\hi', $data['deadline_ts'] ) )
					);
				} else {
					esc_html_e( 'O resultado será marcado pela redação após o evento.', 'go-verge' );
				}
				?>
			</span>
			<span class="go-prediction__total" data-go-prediction-total><?php echo esc_html( sprintf( _n( '%s previsão registrada', '%s previsões registradas', $data['total'], 'go-verge' ), number_format_i18n( $data['total'] ) ) ); ?></span>
		</p>
	</div>
	<?php
	return ob_get_clean();
}
add_shortcode( 'go_previsao', 'go_verge_prediction_shortcode' );

/** AJAX: register a prediction vote. */
function go_verge_ajax_prediction_vote() {
	check_ajax_referer( 'go_verge_engage', 'nonce' );

	$prediction_id = isset( $_POST['prediction'] ) ? absint( wp_unslash( $_POST['prediction'] ) ) : 0;
	$option        = isset( $_POST['option'] ) ? absint( wp_unslash( $_POST['option'] ) ) : 0;

	$data = go_verge_prediction_data( $prediction_id );
	if ( ! $data || $option >= count( $data['options'] ) ) {
		wp_send_json_error( array( 'message' => __( 'Previsão inválida.', 'go-verge' ) ), 400 );
	}
	if ( $data['is_closed'] ) {
		wp_send_json_error( array( 'message' => __( 'Esta previsão já foi encerrada.', 'go-verge' ) ), 409 );
	}
	if ( go_verge_engage_has_voted( 'p' . $prediction_id ) ) {
		wp_send_json_error( array( 'message' => __( 'Você já registrou sua previsão.', 'go-verge' ) ), 409 );
	}

	$counts = $data['counts'];
	$counts[ $option ]++;
	update_post_meta( $prediction_id, '_go_prediction_counts', $counts );
	go_verge_engage_remember_vote( 'p' . $prediction_id, (string) $option );

	wp_send_json_success(
		array(
			'counts' => array_values( $counts ),
			'total'  => array_sum( $counts ),
		)
	);
}
add_action( 'wp_ajax_go_verge_prediction_vote', 'go_verge_ajax_prediction_vote' );
add_action( 'wp_ajax_nopriv_go_verge_prediction_vote', 'go_verge_ajax_prediction_vote' );

/** Prediction editor: options, deadline, result. */
function go_verge_register_prediction_meta_box() {
	add_meta_box(
		'go-verge-prediction',
		__( 'Configuração da previsão', 'go-verge' ),
		'go_verge_render_prediction_meta_box',
		'go_prediction',
		'normal',
		'high'
	);
}
add_action( 'add_meta_boxes_go_prediction', 'go_verge_register_prediction_meta_box' );

function go_verge_render_prediction_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_prediction', 'go_verge_prediction_nonce' );

	$options  = get_post_meta( $post->ID, '_go_prediction_options', true );
	$options  = is_array( $options ) ? implode( "\n", $options ) : '';
	$counts   = get_post_meta( $post->ID, '_go_prediction_counts', true );
	$counts   = is_array( $counts ) ? array_map( 'absint', $counts ) : array();
	$result   = get_post_meta( $post->ID, '_go_prediction_result', true );
	$result   = ( '' === $result || null === $result ) ? -1 : (int) $result;
	$deadline = (string) get_post_meta( $post->ID, '_go_prediction_deadline', true );
	$context  = (string) get_post_meta( $post->ID, '_go_prediction_context', true );
	$option_list = array_values( array_filter( array_map( 'trim', explode( "\n", $options ) ), 'strlen' ) );
	?>
	<div style="display:grid;gap:14px;">
		<p style="margin:0;color:#646970;">
			<?php esc_html_e( 'O título da previsão é a pergunta (ex.: "Quem vence o GOTY?"). Publique e insira na matéria com o shortcode abaixo.', 'go-verge' ); ?>
		</p>
		<p style="margin:0;">
			<label for="go-prediction-context"><strong><?php esc_html_e( 'Contexto (opcional)', 'go-verge' ); ?></strong></label>
			<input id="go-prediction-context" class="widefat" type="text" name="go_prediction_context" value="<?php echo esc_attr( $context ); ?>" placeholder="<?php esc_attr_e( 'Ex.: A cerimônia acontece em 12 de dezembro.', 'go-verge' ); ?>">
		</p>
		<p style="margin:0;">
			<label for="go-prediction-options"><strong><?php esc_html_e( 'Opções (uma por linha)', 'go-verge' ); ?></strong></label>
			<textarea id="go-prediction-options" class="widefat" rows="5" name="go_prediction_options" placeholder="<?php esc_attr_e( "Sim\nNão", 'go-verge' ); ?>"><?php echo esc_textarea( $options ); ?></textarea>
			<?php if ( ! empty( $counts ) && array_sum( $counts ) > 0 ) : ?>
				<span style="color:#b32d2e;display:block;margin-top:4px;"><?php esc_html_e( 'Atenção: já existem votos. Alterar a ordem das opções embaralha a contagem.', 'go-verge' ); ?></span>
			<?php endif; ?>
		</p>
		<div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;">
			<p style="margin:0;">
				<label for="go-prediction-deadline"><strong><?php esc_html_e( 'Votação aberta até (opcional)', 'go-verge' ); ?></strong></label>
				<input id="go-prediction-deadline" class="widefat" type="datetime-local" name="go_prediction_deadline" value="<?php echo esc_attr( $deadline ); ?>">
			</p>
			<p style="margin:0;">
				<label for="go-prediction-result"><strong><?php esc_html_e( 'Resultado (marque após o evento)', 'go-verge' ); ?></strong></label>
				<select id="go-prediction-result" class="widefat" name="go_prediction_result">
					<option value="-1" <?php selected( $result, -1 ); ?>><?php esc_html_e( '— Pendente —', 'go-verge' ); ?></option>
					<?php foreach ( $option_list as $index => $label ) : ?>
						<option value="<?php echo esc_attr( $index ); ?>" <?php selected( $result, $index ); ?>>
							<?php echo esc_html( sprintf( __( 'Aconteceu: %s', 'go-verge' ), $label ) ); ?>
						</option>
					<?php endforeach; ?>
				</select>
			</p>
		</div>
		<?php if ( ! empty( $option_list ) ) : ?>
			<div>
				<strong><?php esc_html_e( 'Votos até agora', 'go-verge' ); ?></strong>
				<ul style="margin:6px 0 0;">
					<?php foreach ( $option_list as $index => $label ) : ?>
						<li><?php echo esc_html( $label ); ?> — <strong><?php echo esc_html( number_format_i18n( $counts[ $index ] ?? 0 ) ); ?></strong></li>
					<?php endforeach; ?>
				</ul>
			</div>
		<?php endif; ?>
		<?php if ( 'publish' === $post->post_status ) : ?>
			<p style="margin:0;">
				<strong><?php esc_html_e( 'Shortcode para a matéria:', 'go-verge' ); ?></strong>
				<code style="user-select:all;">[go_previsao id="<?php echo esc_html( $post->ID ); ?>"]</code>
			</p>
		<?php endif; ?>
	</div>
	<?php
}

function go_verge_save_prediction_meta( $post_id ) {
	if ( ! isset( $_POST['go_verge_prediction_nonce'] ) ) {
		return;
	}
	if ( ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_prediction_nonce'] ) ), 'go_verge_save_prediction' ) ) {
		return;
	}
	if ( ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) || wp_is_post_revision( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}

	$options_raw = isset( $_POST['go_prediction_options'] ) ? sanitize_textarea_field( wp_unslash( $_POST['go_prediction_options'] ) ) : '';
	$options     = array_values( array_filter( array_map( 'trim', explode( "\n", $options_raw ) ), 'strlen' ) );
	$options     = array_slice( $options, 0, 12 );
	update_post_meta( $post_id, '_go_prediction_options', $options );

	$context = isset( $_POST['go_prediction_context'] ) ? sanitize_text_field( wp_unslash( $_POST['go_prediction_context'] ) ) : '';
	update_post_meta( $post_id, '_go_prediction_context', $context );

	$deadline = isset( $_POST['go_prediction_deadline'] ) ? sanitize_text_field( wp_unslash( $_POST['go_prediction_deadline'] ) ) : '';
	if ( $deadline && ! preg_match( '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/', $deadline ) ) {
		$deadline = '';
	}
	update_post_meta( $post_id, '_go_prediction_deadline', $deadline );

	$result = isset( $_POST['go_prediction_result'] ) ? (int) $_POST['go_prediction_result'] : -1;
	if ( $result < 0 || $result >= count( $options ) ) {
		delete_post_meta( $post_id, '_go_prediction_result' );
	} else {
		update_post_meta( $post_id, '_go_prediction_result', $result );
	}
}
add_action( 'save_post_go_prediction', 'go_verge_save_prediction_meta' );

/** Admin list columns: state + votes at a glance. */
function go_verge_prediction_columns( $columns ) {
	$columns['go_state'] = __( 'Status', 'go-verge' );
	$columns['go_votes'] = __( 'Votos', 'go-verge' );
	unset( $columns['date'] );
	$columns['date'] = __( 'Data', 'go-verge' );
	return $columns;
}
add_filter( 'manage_go_prediction_posts_columns', 'go_verge_prediction_columns' );

function go_verge_prediction_column_content( $column, $post_id ) {
	if ( 'go_state' === $column ) {
		$data = go_verge_prediction_data( $post_id );
		if ( ! $data ) {
			echo '<em>' . esc_html__( 'Incompleta', 'go-verge' ) . '</em>';
		} elseif ( $data['is_settled'] ) {
			printf( '<strong style="color:#00a32a;">%s</strong> — %s', esc_html__( 'Resolvida', 'go-verge' ), esc_html( $data['options'][ $data['result'] ] ) );
		} elseif ( $data['is_closed'] ) {
			echo '<strong style="color:#996800;">' . esc_html__( 'Encerrada (aguardando resultado)', 'go-verge' ) . '</strong>';
		} else {
			echo '<strong>' . esc_html__( 'Aberta', 'go-verge' ) . '</strong>';
		}
	}
	if ( 'go_votes' === $column ) {
		$counts = get_post_meta( $post_id, '_go_prediction_counts', true );
		echo esc_html( number_format_i18n( is_array( $counts ) ? array_sum( array_map( 'absint', $counts ) ) : 0 ) );
	}
}
add_action( 'manage_go_prediction_posts_custom_column', 'go_verge_prediction_column_content', 10, 2 );

/* --------------------------------------------------------------------------
 * Comparador — [go_comparador titulo="A vs B" a="A" b="B" veredito="..."]
 * Body lines: "Rótulo | valor A | valor B" — prefix the winning value with *.
 * ------------------------------------------------------------------------ */

function go_verge_comparator_shortcode( $atts, $content = '' ) {
	$atts = shortcode_atts(
		array(
			'titulo'   => '',
			'a'        => 'A',
			'b'        => 'B',
			'veredito' => '',
		),
		$atts,
		'go_comparador'
	);

	$rows  = array();
	$lines = preg_split( '/\r\n|\r|\n/', wp_strip_all_tags( strip_shortcodes( (string) $content ) ) );
	foreach ( $lines as $line ) {
		$line = trim( $line );
		if ( '' === $line ) {
			continue;
		}
		$parts = array_map( 'trim', explode( '|', $line ) );
		if ( count( $parts ) < 3 ) {
			continue;
		}
		$win_a = 0 === strpos( $parts[1], '*' );
		$win_b = 0 === strpos( $parts[2], '*' );
		$rows[] = array(
			'label' => $parts[0],
			'a'     => ltrim( $parts[1], '* ' ),
			'b'     => ltrim( $parts[2], '* ' ),
			'win_a' => $win_a && ! $win_b,
			'win_b' => $win_b && ! $win_a,
		);
	}
	if ( empty( $rows ) ) {
		return '';
	}

	$wins_a = count( array_filter( wp_list_pluck( $rows, 'win_a' ) ) );
	$wins_b = count( array_filter( wp_list_pluck( $rows, 'win_b' ) ) );

	ob_start();
	?>
	<div class="go-compare">
		<p class="go-interactive-kicker go-interactive-kicker--compare"><span aria-hidden="true">⇄</span> <?php esc_html_e( 'Comparativo', 'go-verge' ); ?></p>
		<?php if ( '' !== trim( (string) $atts['titulo'] ) ) : ?>
			<p class="go-compare__title"><?php echo esc_html( trim( (string) $atts['titulo'] ) ); ?></p>
		<?php endif; ?>
		<div class="go-compare__table" role="table" aria-label="<?php echo esc_attr( '' !== trim( (string) $atts['titulo'] ) ? trim( (string) $atts['titulo'] ) : __( 'Tabela comparativa', 'go-verge' ) ); ?>">
			<div class="go-compare__row go-compare__row--head" role="row">
				<span class="go-compare__cell go-compare__cell--label" role="columnheader"></span>
				<span class="go-compare__cell go-compare__cell--head" role="columnheader"><?php echo esc_html( $atts['a'] ); ?><?php if ( $wins_a || $wins_b ) : ?><small><?php echo esc_html( sprintf( _n( '%d ponto', '%d pontos', $wins_a, 'go-verge' ), $wins_a ) ); ?></small><?php endif; ?></span>
				<span class="go-compare__vs" aria-hidden="true">vs</span>
				<span class="go-compare__cell go-compare__cell--head" role="columnheader"><?php echo esc_html( $atts['b'] ); ?><?php if ( $wins_a || $wins_b ) : ?><small><?php echo esc_html( sprintf( _n( '%d ponto', '%d pontos', $wins_b, 'go-verge' ), $wins_b ) ); ?></small><?php endif; ?></span>
			</div>
			<?php foreach ( $rows as $row ) : ?>
				<div class="go-compare__row" role="row">
					<span class="go-compare__cell go-compare__cell--label" role="rowheader"><?php echo esc_html( $row['label'] ); ?></span>
					<span class="go-compare__cell<?php echo $row['win_a'] ? ' is-win' : ''; ?>" role="cell">
						<?php if ( $row['win_a'] ) : ?><span class="go-compare__check" aria-hidden="true">✓</span><span class="screen-reader-text"><?php esc_html_e( 'Vantagem: ', 'go-verge' ); ?></span><?php endif; ?>
						<?php echo esc_html( $row['a'] ); ?>
					</span>
					<span class="go-compare__vs" aria-hidden="true"></span>
					<span class="go-compare__cell<?php echo $row['win_b'] ? ' is-win' : ''; ?>" role="cell">
						<?php if ( $row['win_b'] ) : ?><span class="go-compare__check" aria-hidden="true">✓</span><span class="screen-reader-text"><?php esc_html_e( 'Vantagem: ', 'go-verge' ); ?></span><?php endif; ?>
						<?php echo esc_html( $row['b'] ); ?>
					</span>
				</div>
			<?php endforeach; ?>
		</div>
		<?php if ( '' !== trim( (string) $atts['veredito'] ) ) : ?>
			<p class="go-compare__verdict"><strong><?php esc_html_e( 'Veredito GO:', 'go-verge' ); ?></strong> <?php echo esc_html( trim( (string) $atts['veredito'] ) ); ?></p>
		<?php endif; ?>
	</div>
	<?php
	return ob_get_clean();
}
add_shortcode( 'go_comparador', 'go_verge_comparator_shortcode' );

/* --------------------------------------------------------------------------
 * Pergunta editorial — defined per post, rendered right above the comments.
 * ------------------------------------------------------------------------ */

function go_verge_register_editorial_question_meta_box() {
	add_meta_box(
		'go-verge-editorial-question',
		__( 'Pergunta para os leitores', 'go-verge' ),
		'go_verge_render_editorial_question_meta_box',
		'post',
		'side',
		'default'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_editorial_question_meta_box' );

function go_verge_render_editorial_question_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_editorial_question', 'go_verge_editorial_question_nonce' );
	$question = (string) get_post_meta( $post->ID, '_go_editorial_question', true );
	?>
	<p style="margin:0 0 6px;color:#646970;">
		<?php esc_html_e( 'Aparece em destaque logo acima dos comentários e vira o ponto de partida da conversa.', 'go-verge' ); ?>
	</p>
	<textarea class="widefat" rows="3" name="go_editorial_question" placeholder="<?php esc_attr_e( 'Ex.: Qual chefe mais te deu trabalho? / Você concorda com a nota 8,5?', 'go-verge' ); ?>"><?php echo esc_textarea( $question ); ?></textarea>
	<?php
}

function go_verge_save_editorial_question_meta( $post_id ) {
	if ( ! isset( $_POST['go_verge_editorial_question_nonce'] ) ) {
		return;
	}
	if ( ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_editorial_question_nonce'] ) ), 'go_verge_save_editorial_question' ) ) {
		return;
	}
	if ( ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) || wp_is_post_revision( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}
	$question = isset( $_POST['go_editorial_question'] ) ? sanitize_textarea_field( wp_unslash( $_POST['go_editorial_question'] ) ) : '';
	if ( '' === $question ) {
		delete_post_meta( $post_id, '_go_editorial_question' );
	} else {
		update_post_meta( $post_id, '_go_editorial_question', $question );
	}
}
add_action( 'save_post_post', 'go_verge_save_editorial_question_meta' );

/** Editorial question block rendered by comments.php. */
function go_verge_editorial_question( $post_id ) {
	$question = trim( (string) get_post_meta( $post_id, '_go_editorial_question', true ) );
	if ( '' === $question ) {
		return;
	}
	?>
	<div class="go-editorial-question">
		<p class="go-editorial-question__kicker"><?php esc_html_e( 'A redação quer saber', 'go-verge' ); ?></p>
		<p class="go-editorial-question__text"><?php echo esc_html( $question ); ?></p>
		<button type="button" class="go-btn go-btn--mint go-editorial-question__cta" data-go-answer-question><?php esc_html_e( 'Responder nos comentários', 'go-verge' ); ?></button>
	</div>
	<?php
}

/* --------------------------------------------------------------------------
 * Comments: likes, badges, pinning, sorting.
 * ------------------------------------------------------------------------ */

/** Number of likes on a comment. */
function go_verge_comment_likes( $comment_id ) {
	return max( 0, (int) get_comment_meta( $comment_id, 'go_likes', true ) );
}

/** Comment ids this browser already liked (cookie, comma separated). */
function go_verge_liked_comment_ids() {
	if ( empty( $_COOKIE['go_cliked'] ) ) {
		return array();
	}
	return array_filter( array_map( 'absint', explode( ',', sanitize_text_field( wp_unslash( $_COOKIE['go_cliked'] ) ) ) ) );
}

/** AJAX: toggle a like on a comment. */
function go_verge_ajax_comment_like() {
	check_ajax_referer( 'go_verge_engage', 'nonce' );

	$comment_id = isset( $_POST['comment'] ) ? absint( wp_unslash( $_POST['comment'] ) ) : 0;
	$comment    = $comment_id ? get_comment( $comment_id ) : null;
	if ( ! $comment || '1' !== (string) $comment->comment_approved ) {
		wp_send_json_error( array( 'message' => __( 'Comentário não encontrado.', 'go-verge' ) ), 404 );
	}

	$liked   = go_verge_liked_comment_ids();
	$likes   = go_verge_comment_likes( $comment_id );
	$has     = in_array( $comment_id, $liked, true );

	if ( $has ) {
		$likes = max( 0, $likes - 1 );
		$liked = array_values( array_diff( $liked, array( $comment_id ) ) );
	} else {
		$likes++;
		$liked[] = $comment_id;
		$liked   = array_slice( array_unique( $liked ), -200 );
	}

	update_comment_meta( $comment_id, 'go_likes', $likes );
	setcookie( 'go_cliked', implode( ',', $liked ), time() + YEAR_IN_SECONDS, '/', '', is_ssl(), false );

	wp_send_json_success(
		array(
			'likes' => $likes,
			'liked' => ! $has,
		)
	);
}
add_action( 'wp_ajax_go_verge_comment_like', 'go_verge_ajax_comment_like' );
add_action( 'wp_ajax_nopriv_go_verge_comment_like', 'go_verge_ajax_comment_like' );

/** AJAX: pin/unpin a comment (editors only). */
function go_verge_ajax_comment_pin() {
	check_ajax_referer( 'go_verge_engage', 'nonce' );

	if ( ! current_user_can( 'moderate_comments' ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão.', 'go-verge' ) ), 403 );
	}

	$comment_id = isset( $_POST['comment'] ) ? absint( wp_unslash( $_POST['comment'] ) ) : 0;
	$comment    = $comment_id ? get_comment( $comment_id ) : null;
	if ( ! $comment ) {
		wp_send_json_error( array( 'message' => __( 'Comentário não encontrado.', 'go-verge' ) ), 404 );
	}

	$pinned = (bool) get_comment_meta( $comment_id, 'go_pinned', true );
	if ( $pinned ) {
		delete_comment_meta( $comment_id, 'go_pinned' );
	} else {
		update_comment_meta( $comment_id, 'go_pinned', 1 );
	}

	wp_send_json_success( array( 'pinned' => ! $pinned ) );
}
add_action( 'wp_ajax_go_verge_comment_pin', 'go_verge_ajax_comment_pin' );

/**
 * Hoist pinned comments to the top of their page and remember which comment
 * is currently the most useful (most liked, minimum of 2).
 */
function go_verge_order_comments( $comments ) {
	if ( empty( $comments ) || ! is_array( $comments ) ) {
		return $comments;
	}

	$most_useful_id  = 0;
	$most_useful_max = 1; // Requires at least 2 likes to earn the badge.
	foreach ( $comments as $comment ) {
		if ( (int) $comment->comment_parent > 0 ) {
			continue;
		}
		$likes = go_verge_comment_likes( $comment->comment_ID );
		if ( $likes > $most_useful_max ) {
			$most_useful_max = $likes;
			$most_useful_id  = (int) $comment->comment_ID;
		}
	}
	$GLOBALS['go_verge_most_useful_comment'] = $most_useful_id;

	$pinned = array();
	$rest   = array();
	foreach ( $comments as $comment ) {
		if ( (int) $comment->comment_parent === 0 && get_comment_meta( $comment->comment_ID, 'go_pinned', true ) ) {
			$pinned[] = $comment;
		} else {
			$rest[] = $comment;
		}
	}

	return array_merge( $pinned, $rest );
}
add_filter( 'comments_array', 'go_verge_order_comments', 20 );

/**
 * Comment renderer: avatar, byline badges, like/pin controls and reply link.
 * WordPress closes the <li> itself.
 */
function go_verge_comment_callback( $comment, $args, $depth ) {
	$comment_id  = (int) $comment->comment_ID;
	$post        = get_post( $comment->comment_post_ID );
	$is_author   = $post && (int) $post->post_author > 0 && (int) $comment->user_id === (int) $post->post_author;
	$is_staff    = ! $is_author && $comment->user_id && user_can( (int) $comment->user_id, 'edit_others_posts' );
	$is_pinned   = (bool) get_comment_meta( $comment_id, 'go_pinned', true );
	$likes       = go_verge_comment_likes( $comment_id );
	$liked       = in_array( $comment_id, go_verge_liked_comment_ids(), true );
	$most_useful = ! empty( $GLOBALS['go_verge_most_useful_comment'] ) && (int) $GLOBALS['go_verge_most_useful_comment'] === $comment_id;
	$is_reply    = (int) $comment->comment_parent > 0;

	$classes   = array( 'go-comment' );
	if ( $is_author ) {
		$classes[] = 'go-comment--author';
	}
	if ( $is_pinned ) {
		$classes[] = 'go-comment--pinned';
	}
	?>
	<li id="comment-<?php echo esc_attr( $comment_id ); ?>" <?php comment_class( implode( ' ', $classes ), $comment ); ?> data-go-comment="<?php echo esc_attr( $comment_id ); ?>" data-likes="<?php echo esc_attr( $likes ); ?>" data-date="<?php echo esc_attr( get_comment_date( 'U', $comment ) ); ?>" data-pinned="<?php echo $is_pinned ? '1' : '0'; ?>">
		<article class="go-comment__body">
			<?php if ( $is_pinned ) : ?>
				<p class="go-comment__pinned-tag"><span aria-hidden="true">📌</span> <?php esc_html_e( 'Fixado pela redação', 'go-verge' ); ?></p>
			<?php endif; ?>

			<header class="go-comment__head">
				<span class="go-comment__avatar"><?php echo get_avatar( $comment, 44 ); ?></span>
				<div class="go-comment__id">
					<span class="go-comment__author">
						<?php echo esc_html( get_comment_author( $comment ) ); ?>
						<?php if ( $is_author ) : ?>
							<span class="go-comment-badge go-comment-badge--author"><?php echo $is_reply ? esc_html__( 'Resposta do autor', 'go-verge' ) : esc_html__( 'Autor da matéria', 'go-verge' ); ?></span>
						<?php elseif ( $is_staff ) : ?>
							<span class="go-comment-badge go-comment-badge--staff"><?php esc_html_e( 'Redação', 'go-verge' ); ?></span>
						<?php endif; ?>
						<?php if ( $most_useful ) : ?>
							<span class="go-comment-badge go-comment-badge--useful"><?php esc_html_e( 'Mais útil', 'go-verge' ); ?></span>
						<?php endif; ?>
					</span>
					<a class="go-comment__time" href="<?php echo esc_url( get_comment_link( $comment ) ); ?>">
						<time datetime="<?php echo esc_attr( get_comment_date( 'c', $comment ) ); ?>"><?php echo esc_html( sprintf( __( '%s atrás', 'go-verge' ), human_time_diff( (int) get_comment_date( 'U', $comment ), (int) current_time( 'timestamp' ) ) ) ); ?></time>
					</a>
				</div>
			</header>

			<?php if ( '0' === (string) $comment->comment_approved ) : ?>
				<p class="go-comment__moderation"><?php esc_html_e( 'Seu comentário aguarda moderação.', 'go-verge' ); ?></p>
			<?php endif; ?>

			<div class="go-comment__content">
				<?php comment_text( $comment ); ?>
			</div>

			<footer class="go-comment__actions">
				<button type="button" class="go-comment-like<?php echo $liked ? ' is-liked' : ''; ?>" data-go-comment-like="<?php echo esc_attr( $comment_id ); ?>" aria-pressed="<?php echo $liked ? 'true' : 'false'; ?>">
					<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><path fill="currentColor" d="M12 21s-6.7-4.3-9.3-8.1C.8 10 1.7 6.2 4.8 5c2-.8 4.2-.1 5.6 1.5L12 8.2l1.6-1.7C15 4.9 17.2 4.2 19.2 5c3.1 1.2 4 5 2.1 7.9C18.7 16.7 12 21 12 21Z"/></svg>
					<span class="go-comment-like__label"><?php esc_html_e( 'Curtir', 'go-verge' ); ?></span>
					<span class="go-comment-like__count" data-go-like-count<?php echo $likes ? '' : ' hidden'; ?>><?php echo esc_html( number_format_i18n( $likes ) ); ?></span>
				</button>
				<?php
				comment_reply_link(
					array_merge(
						$args,
						array(
							'depth'      => $depth,
							'max_depth'  => $args['max_depth'],
							'reply_text' => __( 'Responder', 'go-verge' ),
							'before'     => '<span class="go-comment__reply">',
							'after'      => '</span>',
						)
					),
					$comment
				);
				?>
				<?php if ( current_user_can( 'moderate_comments' ) && ! $is_reply ) : ?>
					<button type="button" class="go-comment-pin" data-go-comment-pin="<?php echo esc_attr( $comment_id ); ?>" aria-pressed="<?php echo $is_pinned ? 'true' : 'false'; ?>">
						<?php echo $is_pinned ? esc_html__( 'Desafixar', 'go-verge' ) : esc_html__( 'Fixar', 'go-verge' ); ?>
					</button>
				<?php endif; ?>
			</footer>
		</article>
	<?php
}

/* --------------------------------------------------------------------------
 * Editor: "Blocos interativos" metabox — inserts ready-to-fill shortcodes in
 * both the classic editor and Gutenberg.
 * ------------------------------------------------------------------------ */

function go_verge_register_interactive_meta_box() {
	if ( function_exists( 'use_block_editor_for_post_type' ) && use_block_editor_for_post_type( 'post' ) ) {
		return;
	}
	add_meta_box(
		'go-verge-interactive-blocks',
		__( 'Blocos interativos', 'go-verge' ),
		'go_verge_render_interactive_meta_box',
		'post',
		'side',
		'default'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_interactive_meta_box' );

function go_verge_render_interactive_meta_box( $post ) {
	$poll_template = '[go_enquete pergunta="Sua pergunta aqui" opcoes="Opção 1|Opção 2|Opção 3"]';
	$quiz_template = '[go_quiz pergunta="Sua pergunta aqui" opcoes="Alternativa A|Alternativa B|Alternativa C" correta="1" explicacao="Explique por que essa é a resposta certa."]';
	$compare_template = '[go_comparador titulo="Produto A vs Produto B" a="Produto A" b="Produto B" veredito="Qual leva a melhor e para quem."]' . "\n"
		. 'Preço | *R$ 2.499 | R$ 2.899' . "\n"
		. 'Desempenho | 60 fps | *120 fps' . "\n"
		. 'Bateria | *10h | 7h' . "\n"
		. '[/go_comparador]';

	$predictions = get_posts(
		array(
			'post_type'      => 'go_prediction',
			'post_status'    => 'publish',
			'posts_per_page' => 30,
			'orderby'        => 'date',
			'order'          => 'DESC',
		)
	);
	?>
	<div class="go-interactive-metabox" data-go-interactive-metabox>
		<p style="margin:0 0 10px;color:#646970;">
			<?php esc_html_e( 'Insira no ponto atual do texto. Depois é só editar a pergunta e as opções.', 'go-verge' ); ?>
		</p>
		<div style="display:grid;gap:6px;">
			<button type="button" class="button" data-go-insert-block="<?php echo esc_attr( $poll_template ); ?>">
				<?php esc_html_e( '◈ Enquete (leitores votam)', 'go-verge' ); ?>
			</button>
			<button type="button" class="button" data-go-insert-block="<?php echo esc_attr( $quiz_template ); ?>">
				<?php esc_html_e( '? Quiz com resposta certa', 'go-verge' ); ?>
			</button>
			<button type="button" class="button" data-go-insert-block="<?php echo esc_attr( $compare_template ); ?>">
				<?php esc_html_e( '⇄ Comparador (A vs B)', 'go-verge' ); ?>
			</button>
		</div>

		<hr style="margin:12px 0;">

		<p style="margin:0 0 6px;"><strong><?php esc_html_e( 'Caixa de previsão', 'go-verge' ); ?></strong></p>
		<?php if ( $predictions ) : ?>
			<select class="widefat" data-go-prediction-picker>
				<?php foreach ( $predictions as $prediction ) : ?>
					<option value="<?php echo esc_attr( $prediction->ID ); ?>"><?php echo esc_html( get_the_title( $prediction ) ); ?></option>
				<?php endforeach; ?>
			</select>
			<button type="button" class="button" style="margin-top:6px;" data-go-insert-prediction>
				<?php esc_html_e( '◔ Inserir previsão selecionada', 'go-verge' ); ?>
			</button>
		<?php else : ?>
			<p style="margin:0;color:#646970;"><?php esc_html_e( 'Nenhuma previsão publicada ainda.', 'go-verge' ); ?></p>
		<?php endif; ?>
		<p style="margin:8px 0 0;">
			<a href="<?php echo esc_url( admin_url( 'post-new.php?post_type=go_prediction' ) ); ?>" target="_blank">
				<?php esc_html_e( '+ Criar nova previsão', 'go-verge' ); ?>
			</a>
		</p>
	</div>
	<?php
}

/** Editor assets for the interactive-blocks metabox. */
function go_verge_interactive_editor_assets( $hook_suffix ) {
	if ( function_exists( 'use_block_editor_for_post_type' ) && use_block_editor_for_post_type( 'post' ) ) {
		return;
	}
	if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
		return;
	}
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}
	wp_enqueue_script(
		'go-verge-editor-interactive',
		GO_VERGE_URI . '/assets/js/editor-interactive.js',
		array( 'jquery' ),
		go_verge_asset_version( '/assets/js/editor-interactive.js' ),
		true
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_interactive_editor_assets', 40 );

/* --------------------------------------------------------------------------
 * Gutenberg: native Overdrive interactive blocks.
 * ------------------------------------------------------------------------ */

/** Add a dedicated inserter category for the newsroom interactive blocks. */
function go_verge_interactive_block_category( $categories ) {
	$slug = 'game-overdrive-interativos';
	foreach ( $categories as $category ) {
		if ( isset( $category['slug'] ) && $slug === $category['slug'] ) {
			return $categories;
		}
	}
	array_unshift(
		$categories,
		array(
			'slug'  => $slug,
			'title' => __( 'Overdrive · Interativos', 'go-verge' ),
			'icon'  => null,
		)
	);
	return $categories;
}
add_filter( 'block_categories_all', 'go_verge_interactive_block_category', 10, 1 );

/** Editor script and styles used by the native Gutenberg interactive blocks. */
function go_verge_register_gutenberg_interactive_assets() {
	wp_register_script(
		'go-verge-gutenberg-interactives',
		GO_VERGE_URI . '/assets/js/gutenberg-interactives.js',
		array( 'wp-blocks', 'wp-element', 'wp-components', 'wp-block-editor', 'wp-i18n' ),
		go_verge_asset_version( '/assets/js/gutenberg-interactives.js' ),
		true
	);
	wp_register_style(
		'go-verge-gutenberg-interactives',
		GO_VERGE_URI . '/assets/css/gutenberg-interactives.css',
		array( 'wp-edit-blocks' ),
		go_verge_asset_version( '/assets/css/gutenberg-interactives.css' )
	);
}
add_action( 'init', 'go_verge_register_gutenberg_interactive_assets', 18 );

/** Render native poll block through the same proven front-end component. */
function go_verge_render_poll_block( $attributes ) {
	$options = isset( $attributes['opcoes'] ) ? preg_split( '/\r\n|\r|\n/', (string) $attributes['opcoes'] ) : array();
	$options = array_values( array_filter( array_map( 'trim', $options ), 'strlen' ) );
	return go_verge_poll_shortcode(
		array(
			'pergunta' => isset( $attributes['pergunta'] ) ? sanitize_text_field( $attributes['pergunta'] ) : '',
			'opcoes'   => implode( '|', array_map( 'sanitize_text_field', $options ) ),
		)
	);
}

/** Render native quiz block through the existing quiz runtime. */
function go_verge_render_quiz_block( $attributes ) {
	$options = isset( $attributes['opcoes'] ) ? preg_split( '/\r\n|\r|\n/', (string) $attributes['opcoes'] ) : array();
	$options = array_values( array_filter( array_map( 'trim', $options ), 'strlen' ) );
	return go_verge_quiz_shortcode(
		array(
			'pergunta'   => isset( $attributes['pergunta'] ) ? sanitize_text_field( $attributes['pergunta'] ) : '',
			'opcoes'     => implode( '|', array_map( 'sanitize_text_field', $options ) ),
			'correta'    => isset( $attributes['correta'] ) ? max( 1, absint( $attributes['correta'] ) ) : 1,
			'explicacao' => isset( $attributes['explicacao'] ) ? sanitize_textarea_field( $attributes['explicacao'] ) : '',
		)
	);
}

/** Render native comparator block through the existing comparator component. */
function go_verge_render_comparator_block( $attributes ) {
	return go_verge_comparator_shortcode(
		array(
			'titulo'   => isset( $attributes['titulo'] ) ? sanitize_text_field( $attributes['titulo'] ) : '',
			'a'        => isset( $attributes['a'] ) ? sanitize_text_field( $attributes['a'] ) : 'A',
			'b'        => isset( $attributes['b'] ) ? sanitize_text_field( $attributes['b'] ) : 'B',
			'veredito' => isset( $attributes['veredito'] ) ? sanitize_textarea_field( $attributes['veredito'] ) : '',
		),
		isset( $attributes['linhas'] ) ? sanitize_textarea_field( $attributes['linhas'] ) : ''
	);
}

/** Render a published prediction selected in the native block. */
function go_verge_render_prediction_block( $attributes ) {
	$prediction_id = isset( $attributes['predictionId'] ) ? absint( $attributes['predictionId'] ) : 0;
	return $prediction_id ? go_verge_prediction_shortcode( array( 'id' => $prediction_id ) ) : '';
}

/** Register all four dynamic blocks so they appear in the native inserter. */
function go_verge_register_native_interactive_blocks() {
	$common = array(
		'editor_script' => 'go-verge-gutenberg-interactives',
		'editor_style'  => 'go-verge-gutenberg-interactives',
	);

	register_block_type(
		'game-overdrive/enquete',
		array_merge(
			$common,
			array(
				'attributes'      => array(
					'pergunta' => array( 'type' => 'string', 'default' => 'Qual é a sua opinião?' ),
					'opcoes'   => array( 'type' => 'string', 'default' => "Opção 1\nOpção 2\nOpção 3" ),
				),
				'render_callback' => 'go_verge_render_poll_block',
			)
		)
	);

	register_block_type(
		'game-overdrive/quiz',
		array_merge(
			$common,
			array(
				'attributes'      => array(
					'pergunta'   => array( 'type' => 'string', 'default' => 'Qual é a resposta correta?' ),
					'opcoes'     => array( 'type' => 'string', 'default' => "Alternativa A\nAlternativa B\nAlternativa C" ),
					'correta'    => array( 'type' => 'number', 'default' => 1 ),
					'explicacao' => array( 'type' => 'string', 'default' => '' ),
				),
				'render_callback' => 'go_verge_render_quiz_block',
			)
		)
	);

	register_block_type(
		'game-overdrive/comparador',
		array_merge(
			$common,
			array(
				'attributes'      => array(
					'titulo'   => array( 'type' => 'string', 'default' => 'Produto A vs Produto B' ),
					'a'        => array( 'type' => 'string', 'default' => 'Produto A' ),
					'b'        => array( 'type' => 'string', 'default' => 'Produto B' ),
					'linhas'   => array( 'type' => 'string', 'default' => "Preço | *R$ 2.499 | R$ 2.899\nDesempenho | 60 fps | *120 fps\nBateria | *10h | 7h" ),
					'veredito' => array( 'type' => 'string', 'default' => '' ),
				),
				'render_callback' => 'go_verge_render_comparator_block',
			)
		)
	);

	register_block_type(
		'game-overdrive/previsao',
		array_merge(
			$common,
			array(
				'attributes'      => array(
					'predictionId' => array( 'type' => 'number', 'default' => 0 ),
				),
				'render_callback' => 'go_verge_render_prediction_block',
			)
		)
	);
}
add_action( 'init', 'go_verge_register_native_interactive_blocks', 30 );

/** Supply the prediction picker used by the native Prediction block. */
function go_verge_gutenberg_interactive_editor_data() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->post_type ) {
		return;
	}

	$predictions = get_posts(
		array(
			'post_type'      => 'go_prediction',
			'post_status'    => 'publish',
			'posts_per_page' => 50,
			'orderby'        => 'date',
			'order'          => 'DESC',
		)
	);
	$data = array();
	foreach ( $predictions as $prediction ) {
		$prediction_data = go_verge_prediction_data( $prediction->ID );
		$data[] = array(
			'id'      => absint( $prediction->ID ),
			'title'   => html_entity_decode( wp_strip_all_tags( get_the_title( $prediction ) ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ),
			'context' => $prediction_data && isset( $prediction_data['context'] ) ? (string) $prediction_data['context'] : '',
			'options' => $prediction_data && isset( $prediction_data['options'] ) ? array_values( $prediction_data['options'] ) : array(),
		);
	}
	wp_localize_script(
		'go-verge-gutenberg-interactives',
		'GoVergeGutenbergInteractives',
		array(
			'predictions'      => $data,
			'newPredictionUrl' => admin_url( 'post-new.php?post_type=go_prediction' ),
		)
	);
}
add_action( 'enqueue_block_editor_assets', 'go_verge_gutenberg_interactive_editor_data', 30 );

/**
 * Reading progress bar.
 *
 * The visual design for this already existed in assets/css/editorial-reading.css
 * — but that stylesheet is not enqueued anywhere, so the feature had been
 * designed and never wired up. Rather than switching on 950 lines of untested
 * CSS, the twenty lines that matter were moved into the polish layer and only
 * this piece was shipped.
 *
 * Why it earns its place: the site's measured bottleneck is viewability (43%
 * of impressions are never seen). A progress indicator is one of the few
 * interface elements that demonstrably increases scroll depth, and scroll depth
 * is what turns a served impression into a viewed one.
 */
function go_verge_render_reading_progress() {
	if ( ! is_singular( 'post' ) || is_feed() ) {
		return;
	}
	if ( function_exists( 'go_verge_is_amp_request' ) && go_verge_is_amp_request() ) {
		return;
	}

	echo '<div class="go-reading-meter" data-go-reading-meter aria-hidden="true"><span class="go-reading-meter__bar" data-go-reading-bar></span></div>';
	?>
<script>
/* The page meter tracks only the editorial body. Comments, recommendations,
   ads after the article and the footer no longer distort the percentage. */
(function () {
	function init() {
	var meter = document.querySelector('[data-go-reading-meter]');
	var bar = meter ? meter.querySelector('[data-go-reading-bar]') : null;
	var article = document.querySelector('.entry-content.go-single__content');
	var header = document.querySelector('.go-header');
	if (!meter || !bar || !article) { return; }

	var ticking = false;
	var headerSyncFrame = 0;
	var meterTop = -1;
	var metrics = { start: 0, end: 1 };

	function clamp(value, min, max) {
		return Math.min(max, Math.max(min, value));
	}

	function positionMeter() {
		/*
		 * Do not derive the fixed meter's top from headerRect.bottom. A sticky
		 * transition can make geometry transient for a frame and one sampled
		 * document coordinate is enough to strand the meter mid-viewport. The
		 * final CSS layer uses the measured --go-header-height directly.
		 */
		if (meterTop !== 0) {
			meter.style.removeProperty('--go-reading-meter-top');
			meterTop = 0;
		}
	}

	function syncHeaderTransition() {
		var started = null;
		if (headerSyncFrame) { window.cancelAnimationFrame(headerSyncFrame); }
		function frame(now) {
			if (started === null) { started = now; }
			positionMeter();
			if (now - started < 420) {
				headerSyncFrame = window.requestAnimationFrame(frame);
			} else {
				headerSyncFrame = 0;
			}
		}
		headerSyncFrame = window.requestAnimationFrame(frame);
	}

	function measure() {
		var rect = article.getBoundingClientRect();
		var top = rect.top + (window.scrollY || window.pageYOffset || 0);
		var viewport = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);
		var headerHeight = header ? Math.max(0, header.getBoundingClientRect().height) : 0;

		positionMeter();
		metrics.start = Math.max(0, top - headerHeight);
		metrics.end = Math.max(
			metrics.start + 1,
			top + article.offsetHeight - viewport
		);
	}

	function update() {
		ticking = false;
		positionMeter();
		var y = window.scrollY || window.pageYOffset || 0;
		var ratio = clamp((y - metrics.start) / (metrics.end - metrics.start), 0, 1);

		bar.style.transform = 'scaleX(' + ratio.toFixed(4) + ')';
		meter.classList.toggle('is-visible', y >= metrics.start - 24);
	}

	function request() {
		if (ticking) { return; }
		ticking = true;
		window.requestAnimationFrame(update);
	}

	function remeasure() {
		measure();
		request();
	}

	window.addEventListener('scroll', request, { passive: true });
	window.addEventListener('resize', remeasure, { passive: true });
	window.addEventListener('load', remeasure, { once: true });

	if (header) {
		header.addEventListener('transitionrun', syncHeaderTransition);
		header.addEventListener('transitionend', positionMeter);
	}

	if ('ResizeObserver' in window) {
		var resizeObserver = new ResizeObserver(remeasure);
		resizeObserver.observe(article);
		if (header) { resizeObserver.observe(header); }
	}
	if (document.fonts && document.fonts.ready) {
		document.fonts.ready.then(remeasure).catch(function () {});
	}

	remeasure();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', init, { once: true });
	} else {
		init();
	}
}());
</script>
	<?php
}
add_action( 'wp_body_open', 'go_verge_render_reading_progress', 5 );
