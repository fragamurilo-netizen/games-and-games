<?php
/**
 * Manual technical-sheet details for reviews and critiques.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Clean a technical-detail string into a more editorial display.
 * Adds commas to common list-like fields when the editor pasted the value
 * without separators, and gently normalises known formats.
 */
function go_verge_format_technical_detail_value( $field, $value ) {
	$value = trim( wp_strip_all_tags( (string) $value ) );
	if ( '' === $value ) {
		return '';
	}

	$replace_delimiters = static function ( $raw ) {
		$raw = str_replace( array( '•', '|', ';', ' / ' ), ',', (string) $raw );
		$raw = preg_replace( '/\s*,\s*/', ', ', (string) $raw );
		$raw = preg_replace( '/\s{2,}/', ' ', (string) $raw );
		return trim( trim( (string) $raw ), ', ' );
	};

	$human_list_from_dictionary = static function ( $raw, $dictionary ) {
		$normalized = sanitize_title( remove_accents( (string) $raw ) );
		$found      = array();
		foreach ( $dictionary as $needle => $label ) {
			if ( false !== strpos( $normalized, sanitize_title( remove_accents( $needle ) ) ) ) {
				$found[ $needle ] = $label;
			}
		}
		return count( $found ) > 1 ? implode( ', ', array_values( $found ) ) : '';
	};

	if ( 'release_date' === $field && preg_match( '/^(\d{4})-(\d{2})-(\d{2})$/', $value, $matches ) ) {
		return $matches[3] . '/' . $matches[2] . '/' . $matches[1];
	}

	if ( in_array( $field, array( 'platform', 'developer', 'publisher', 'country', 'studio', 'writer', 'cast', 'streaming' ), true ) ) {
		$value = $replace_delimiters( $value );
	}

	if ( 'genre' === $field ) {
		if ( false === strpos( $value, ',' ) ) {
			$guessed = $human_list_from_dictionary(
				$value,
				array(
					'mundo aberto'       => 'Mundo aberto',
					'acao aventura'      => 'Ação e aventura',
					'acao'               => 'Ação',
					'aventura'           => 'Aventura',
					'plataforma'         => 'Plataforma',
					'survival horror'    => 'Survival horror',
					'terror'             => 'Terror',
					'rpg'                => 'RPG',
					'corrida'            => 'Corrida',
					'esporte'            => 'Esportes',
					'estrategia'         => 'Estratégia',
					'fps'                => 'FPS',
					'tiro'               => 'Tiro',
					'cooperativo'        => 'Cooperativo',
					'coop'               => 'Cooperativo',
					'simulacao'          => 'Simulação',
				)
			);
			if ( $guessed ) {
				return $guessed;
			}
		}
		$value = $replace_delimiters( $value );
	}

	if ( 'platform' === $field && false === strpos( $value, ',' ) ) {
		$guessed = $human_list_from_dictionary(
			$value,
			array(
				'playstation 5'     => 'PS5',
				'ps5'               => 'PS5',
				'playstation 4'     => 'PS4',
				'ps4'               => 'PS4',
				'xbox series x|s'   => 'Xbox Series X|S',
				'xbox series x s'   => 'Xbox Series X|S',
				'xbox one'          => 'Xbox One',
				'pc'                => 'PC',
				'steam deck'        => 'Steam Deck',
				'switch 2'          => 'Switch 2',
				'nintendo switch'   => 'Nintendo Switch',
				'mobile'            => 'Mobile',
			)
		);
		if ( $guessed ) {
			return $guessed;
		}
	}

	return $value;
}

/** @return array<string,string> */
function go_verge_technical_detail_fields() {
	return array(
		'go_technical_title'        => 'Título',
		'go_technical_platform'     => 'Plataforma',
		'go_technical_genre'        => 'Gênero',
		'go_technical_developer'    => 'Desenvolvedora',
		'go_technical_publisher'    => 'Publisher',
		'go_technical_release_date' => 'Lançamento',
		'go_technical_director'     => 'Direção',
		'go_technical_writer'       => 'Roteiro',
		'go_technical_cast'         => 'Elenco principal',
		'go_technical_studio'       => 'Estúdio / distribuição',
		'go_technical_duration'     => 'Duração',
		'go_technical_rating'       => 'Classificação',
		'go_technical_country'      => 'País',
		'go_technical_streaming'    => 'Onde assistir',
	);
}

function go_verge_register_technical_details_meta_box() {
	add_meta_box(
		'go-verge-technical-details-fields',
		__( 'Dados da ficha técnica', 'go-verge' ),
		'go_verge_render_technical_details_meta_box',
		'post',
		'side',
		'high'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_technical_details_meta_box', 30 );

function go_verge_render_technical_details_meta_box( $post ) {
	wp_nonce_field( 'go_verge_save_technical_details', 'go_verge_technical_details_nonce' );
	$kind = (string) get_post_meta( $post->ID, 'go_technical_sheet_kind', true );
	if ( ! in_array( $kind, array( 'auto', 'game', 'filme', 'serie', 'anime', 'documentario', 'outro' ), true ) ) {
		$kind = 'auto';
	}
	$fields = go_verge_technical_detail_fields();
	?>
	<div class="go-technical-details-editor">
		<p style="margin-top:0">
			<label for="go-technical-sheet-kind"><strong><?php esc_html_e( 'Tipo da ficha', 'go-verge' ); ?></strong></label>
			<select id="go-technical-sheet-kind" name="go_technical_sheet_kind" class="widefat" style="margin-top:5px">
				<?php foreach ( array(
					'auto'          => __( 'Automático', 'go-verge' ),
					'game'          => __( 'Jogo', 'go-verge' ),
					'filme'         => __( 'Filme', 'go-verge' ),
					'serie'         => __( 'Série', 'go-verge' ),
					'anime'         => __( 'Anime', 'go-verge' ),
					'documentario'  => __( 'Documentário', 'go-verge' ),
					'outro'         => __( 'Outro', 'go-verge' ),
				) as $value => $label ) : ?>
					<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $kind, $value ); ?>><?php echo esc_html( $label ); ?></option>
				<?php endforeach; ?>
			</select>
		</p>
		<?php foreach ( $fields as $key => $label ) :
			$value = (string) get_post_meta( $post->ID, $key, true );
			$group = in_array( $key, array( 'go_technical_platform', 'go_technical_developer', 'go_technical_publisher' ), true ) ? 'game' : ( in_array( $key, array( 'go_technical_director', 'go_technical_writer', 'go_technical_cast', 'go_technical_studio', 'go_technical_duration', 'go_technical_rating', 'go_technical_country', 'go_technical_streaming' ), true ) ? 'screen' : 'common' );
			?>
			<p class="go-technical-detail-field" data-go-tech-group="<?php echo esc_attr( $group ); ?>" style="margin:9px 0 0">
				<label for="<?php echo esc_attr( $key ); ?>"><strong><?php echo esc_html( $label ); ?></strong></label>
				<input type="text" id="<?php echo esc_attr( $key ); ?>" name="<?php echo esc_attr( $key ); ?>" class="widefat" value="<?php echo esc_attr( $value ); ?>" style="margin-top:4px">
			</p>
		<?php endforeach; ?>
		<p class="description" style="margin-top:10px"><?php esc_html_e( 'Campos vazios podem usar dados do game vinculado. Em críticas, gênero, direção, roteiro, elenco e onde assistir aparecem quando preenchidos; a ficha é exibida automaticamente.', 'go-verge' ); ?></p>
	</div>
	<script>
	(function(){
		var select=document.getElementById('go-technical-sheet-kind');
		if(!select||select.dataset.goBound==='1')return;
		select.dataset.goBound='1';
		function sync(){
			var kind=select.value;
			document.querySelectorAll('#go-verge-technical-details-fields [data-go-tech-group]').forEach(function(field){
				var group=field.getAttribute('data-go-tech-group');
				var show=group==='common'||kind==='auto'||(kind==='game'&&group==='game')||(kind!=='game'&&kind!=='auto'&&group==='screen');
				field.style.display=show?'':'none';
			});
		}
		select.addEventListener('change',sync);sync();
	})();
	</script>
	<?php
}

function go_verge_save_technical_details( $post_id ) {
	if ( ! isset( $_POST['go_verge_technical_details_nonce'] ) ) { return; }
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_technical_details_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_technical_details' ) ) { return; }
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) { return; }
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) { return; }

	$kind = isset( $_POST['go_technical_sheet_kind'] ) ? sanitize_key( wp_unslash( $_POST['go_technical_sheet_kind'] ) ) : 'auto';
	if ( ! in_array( $kind, array( 'auto', 'game', 'filme', 'serie', 'anime', 'documentario', 'outro' ), true ) ) { $kind = 'auto'; }
	update_post_meta( $post_id, 'go_technical_sheet_kind', $kind );

	foreach ( go_verge_technical_detail_fields() as $key => $label ) {
		$value = isset( $_POST[ $key ] ) ? sanitize_text_field( wp_unslash( $_POST[ $key ] ) ) : '';
		if ( '' !== $value ) { update_post_meta( $post_id, $key, $value ); }
		else { delete_post_meta( $post_id, $key ); }
	}
}
add_action( 'save_post_post', 'go_verge_save_technical_details', 30 );

/**
 * Resolve technical details with manual values first and linked-game values as fallback.
 *
 * @return array<string,string>
 */
function go_verge_review_technical_details( $post_id, $is_critique = false ) {
	$post_id = absint( $post_id );
	$kind = (string) get_post_meta( $post_id, 'go_technical_sheet_kind', true );
	if ( ! in_array( $kind, array( 'auto', 'game', 'filme', 'serie', 'anime', 'documentario', 'outro' ), true ) ) { $kind = 'auto'; }
	if ( 'auto' === $kind ) {
		$work_type = (string) get_post_meta( $post_id, 'go_critique_work_type', true );
		$kind = $is_critique && in_array( $work_type, array( 'filme', 'serie', 'anime', 'documentario', 'outro' ), true ) ? $work_type : 'game';
	}

	$data = array( 'kind' => $kind );
	foreach ( go_verge_technical_detail_fields() as $key => $label ) {
		$field_key = str_replace( 'go_technical_', '', $key );
		$data[ $field_key ] = go_verge_format_technical_detail_value( $field_key, get_post_meta( $post_id, $key, true ) );
	}

	$profile = function_exists( 'go_verge_review_game_profile' ) ? go_verge_review_game_profile( $post_id ) : null;
	if ( 'game' === $kind && is_array( $profile ) && ! empty( $profile['id'] ) && function_exists( 'go_verge_game_data' ) ) {
		$game = go_verge_game_data( (int) $profile['id'] );
		$fallbacks = array(
			'title'        => get_the_title( (int) $profile['id'] ),
			'platform'     => $game['platforms'] ?? '',
			'genre'        => $game['genres'] ?? '',
			'developer'    => $game['developer'] ?? '',
			'publisher'    => $game['publisher'] ?? '',
			'release_date' => $game['release_date'] ?? '',
		);
		foreach ( $fallbacks as $field => $value ) {
			if ( empty( $data[ $field ] ) && '' !== trim( (string) $value ) ) { $data[ $field ] = go_verge_format_technical_detail_value( $field, $value ); }
		}
	}

	// Preserve legacy editorial fields when the new manual fields are empty.
	if ( 'game' === $kind ) {
		$legacy = array(
			'platform'     => array( 'review_platform' ),
			'genre'        => array( 'review_genre' ),
			'developer'    => array( 'review_developer' ),
			'publisher'    => array( 'review_publisher' ),
			'release_date' => array( 'review_release_date' ),
		);
		foreach ( $legacy as $field => $keys ) {
			if ( empty( $data[ $field ] ) && function_exists( 'go_verge_review_meta' ) ) { $data[ $field ] = go_verge_format_technical_detail_value( $field, go_verge_review_meta( $post_id, $keys ) ); }
		}
	} elseif ( empty( $data['title'] ) ) {
		$data['title'] = trim( (string) get_post_meta( $post_id, 'go_critique_work_name', true ) );
	}

	return $data;
}
