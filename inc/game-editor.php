<?php
/**
 * Professional, backwards-compatible Games editor.
 *
 * Existing `_go_*` fields remain canonical. New optional fields are additive,
 * and saving only touches keys explicitly submitted by this metabox.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! function_exists( 'go_verge_game_editor_schema' ) ) {
	/** Field schema and sanitization rules. */
	function go_verge_game_editor_schema() {
		return array(
			'_go_summary'                 => 'textarea',
			'_go_release_status'          => 'release_status',
			'_go_release_date'            => 'date',
			'_go_early_access_date'       => 'date',
			'go_game_franchise_name'      => 'text',
			'_go_edition'                  => 'text',
			'_go_content_type'             => 'content_type',
			'_go_parent_game_id'           => 'game_id',
			'_go_hero_image_id'            => 'image_id',
			'_go_logo_id'                  => 'image_id',
			'_go_developer'                => 'text',
			'_go_publisher'                => 'text',
			'_go_distributor'              => 'text',
			'_go_director'                 => 'text',
			'_go_engine'                   => 'text',
			'_go_country'                  => 'text',
			'_go_platforms'                => 'list',
			'_go_primary_genre'            => 'text',
			'_go_genres'                   => 'list',
			'_go_modes'                    => 'list',
			'_go_perspective'              => 'text',
			'_go_online_features'          => 'list',
			'_go_players'                  => 'text',
			'_go_coop'                     => 'bool',
			'_go_cross_play'               => 'bool',
			'_go_cross_save'               => 'bool',
			'_go_shared_progression'       => 'bool',
			'_go_languages'                => 'list',
			'_go_ptbr_subtitles'           => 'bool',
			'_go_ptbr_dubbing'             => 'bool',
			'_go_age_rating'               => 'text',
			'_go_official_site_url'        => 'url',
			'_go_trailer_url'              => 'url',
			'_go_price'                    => 'text',
			'_go_subscription_services'    => 'list',
			'_go_physical_edition'         => 'bool',
			'_go_digital_edition'          => 'bool',
		);
	}
}

if ( ! function_exists( 'go_verge_game_editor_value' ) ) {
	/** Read canonical meta with all known historical fallbacks. */
	function go_verge_game_editor_value( $post_id, $key ) {
		$fallbacks = array(
			'_go_release_date' => array( '_go_release_date', '_go_data_lancamento' ),
			'_go_developer'    => array( '_go_developer', '_go_desenvolvedora' ),
			'_go_platforms'    => array( '_go_platforms', '_go_plataforma' ),
			'_go_trailer_url'  => array( '_go_trailer_url', 'go_trailer_url' ),
		);
		$keys = $fallbacks[ $key ] ?? array( $key );
		$value = function_exists( 'go_verge_game_meta' )
			? go_verge_game_meta( $post_id, $keys )
			: get_post_meta( $post_id, $key, true );
		if ( 'go_game_franchise_name' === $key && '' === trim( (string) $value ) && taxonomy_exists( 'game_franchise' ) ) {
			$terms = wp_get_post_terms( $post_id, 'game_franchise', array( 'fields' => 'names' ) );
			if ( ! is_wp_error( $terms ) && $terms ) {
				$value = implode( ', ', $terms );
			}
		}
		return $value;
	}
}

if ( ! function_exists( 'go_verge_game_editor_register_meta_box' ) ) {
	function go_verge_game_editor_register_meta_box() {
		add_meta_box(
			'go-verge-game-editor',
			__( 'Dados editoriais do game', 'go-verge' ),
			'go_verge_game_editor_render_meta_box',
			'games',
			'normal',
			'high',
			array( '__block_editor_compatible_meta_box' => true )
		);
	}
}
add_action( 'add_meta_boxes_games', 'go_verge_game_editor_register_meta_box', 20 );

if ( ! function_exists( 'go_verge_game_editor_remove_duplicate_boxes' ) ) {
	/** Keep related data in one workspace instead of scattered sidebar boxes. */
	function go_verge_game_editor_remove_duplicate_boxes() {
		remove_meta_box( 'tagsdiv-game_status', 'games', 'side' );
		remove_meta_box( 'game_statusdiv', 'games', 'side' );
		remove_meta_box( 'tagsdiv-game_platform', 'games', 'side' );
		remove_meta_box( 'game_platformdiv', 'games', 'side' );
		remove_meta_box( 'tagsdiv-game_franchise', 'games', 'side' );
		remove_meta_box( 'game_franchisediv', 'games', 'side' );
	}
}
add_action( 'add_meta_boxes_games', 'go_verge_game_editor_remove_duplicate_boxes', 100 );

if ( ! function_exists( 'go_verge_game_editor_render_meta_box' ) ) {
	/** Render a compact tabbed workspace using native WordPress controls. */
	function go_verge_game_editor_render_meta_box( $post ) {
		wp_nonce_field( 'go_verge_save_game_editor', 'go_verge_game_editor_nonce' );

		$value = static function ( $key ) use ( $post ) {
			return go_verge_game_editor_value( $post->ID, $key );
		};
		$field = static function ( $key, $label, $type = 'text', $description = '', $options = array() ) use ( $value ) {
			$current = $value( $key );
			$id      = 'go-game-' . sanitize_html_class( ltrim( str_replace( '_', '-', $key ), '-' ) );
			?>
			<div class="go-game-field<?php echo 'textarea' === $type ? ' go-game-field--wide' : ''; ?>">
				<label for="<?php echo esc_attr( $id ); ?>"><strong><?php echo esc_html( $label ); ?></strong><?php echo ! empty( $options['optional'] ) ? ' <span>' . esc_html__( '(opcional)', 'go-verge' ) . '</span>' : ''; ?></label>
				<?php if ( 'textarea' === $type ) : ?>
					<textarea id="<?php echo esc_attr( $id ); ?>" name="go_game_fields[<?php echo esc_attr( $key ); ?>]" rows="3" class="widefat"><?php echo esc_textarea( $current ); ?></textarea>
				<?php elseif ( 'select' === $type ) : ?>
					<select id="<?php echo esc_attr( $id ); ?>" name="go_game_fields[<?php echo esc_attr( $key ); ?>]" class="widefat">
						<?php foreach ( $options['choices'] ?? array() as $choice_value => $choice_label ) : ?>
							<option value="<?php echo esc_attr( $choice_value ); ?>" <?php selected( (string) $current, (string) $choice_value ); ?>><?php echo esc_html( $choice_label ); ?></option>
						<?php endforeach; ?>
					</select>
				<?php elseif ( 'boolean' === $type ) : ?>
					<label class="go-game-toggle"><input id="<?php echo esc_attr( $id ); ?>" type="checkbox" name="go_game_fields[<?php echo esc_attr( $key ); ?>]" value="1" <?php checked( '1', (string) $current ); ?>> <span><?php echo esc_html( $options['toggle_label'] ?? __( 'Sim', 'go-verge' ) ); ?></span></label>
				<?php else : ?>
					<input id="<?php echo esc_attr( $id ); ?>" type="<?php echo esc_attr( $type ); ?>" name="go_game_fields[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( $current ); ?>" class="widefat"<?php echo ! empty( $options['placeholder'] ) ? ' placeholder="' . esc_attr( $options['placeholder'] ) . '"' : ''; ?><?php echo ! empty( $options['datalist'] ) ? ' list="' . esc_attr( $id . '-options' ) . '"' : ''; ?>>
					<?php if ( ! empty( $options['datalist'] ) ) : ?><datalist id="<?php echo esc_attr( $id . '-options' ); ?>"><?php foreach ( array_unique( array_filter( (array) $options['datalist'] ) ) as $suggestion ) : ?><option value="<?php echo esc_attr( go_verge_prepare_game_name( $suggestion ) ); ?>"></option><?php endforeach; ?></datalist><?php endif; ?>
				<?php endif; ?>
				<?php if ( $description ) : ?><p class="description"><?php echo esc_html( $description ); ?></p><?php endif; ?>
			</div>
			<?php
		};

		$image_field = static function ( $key, $label ) use ( $value ) {
			$image_id = absint( $value( $key ) );
			?>
			<div class="go-game-field go-game-media-field" data-go-game-media>
				<label><strong><?php echo esc_html( $label ); ?></strong> <span><?php esc_html_e( '(opcional)', 'go-verge' ); ?></span></label>
				<input type="hidden" name="go_game_fields[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( $image_id ); ?>" data-go-game-media-id>
				<div class="go-game-media-field__preview" data-go-game-media-preview><?php echo $image_id ? wp_get_attachment_image( $image_id, 'medium' ) : ''; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
				<p><button type="button" class="button" data-go-game-media-select><?php esc_html_e( 'Escolher imagem', 'go-verge' ); ?></button> <button type="button" class="button-link-delete" data-go-game-media-remove<?php echo $image_id ? '' : ' hidden'; ?>><?php esc_html_e( 'Remover', 'go-verge' ); ?></button></p>
			</div>
			<?php
		};

		$platform_choices = array( 'PS5', 'PS4', 'Xbox Series X|S', 'Xbox One', 'Nintendo Switch 2', 'Nintendo Switch', 'PC', 'Steam', 'Epic Games Store', 'GOG', 'Android', 'iOS', 'macOS', 'Linux' );
		$genre_choices    = array( 'Ação', 'Aventura', 'RPG', 'Estratégia', 'Simulação', 'Corrida', 'Esportes', 'Luta', 'Terror', 'Sobrevivência', 'Plataforma', 'Puzzle', 'Ritmo', 'Stealth', 'FPS', 'TPS', 'MMO', 'MOBA' );
		$platform_raw     = (string) $value( '_go_platforms' );
		$platform_for_split = preg_replace( '/\bXbox\s+Series\s+X\|S\b/iu', 'Xbox Series X__GO_PIPE__S', $platform_raw );
		$selected_platforms = array_values( array_filter( array_map( static function ( $item ) { return str_replace( '__GO_PIPE__', '|', trim( $item ) ); }, preg_split( '/[,;|]+/u', $platform_for_split ) ) ) );
		$known_normalized = array_map( static function ( $item ) { return strtolower( remove_accents( $item ) ); }, $platform_choices );
		$custom_platforms = array();
		foreach ( $selected_platforms as $selected_platform ) {
			if ( ! in_array( strtolower( remove_accents( $selected_platform ) ), $known_normalized, true ) ) {
				$custom_platforms[] = $selected_platform;
			}
		}
		$genre_raw       = (string) $value( '_go_genres' );
		$selected_genres = array_values( array_filter( array_map( 'trim', preg_split( '/[,;|]+/u', $genre_raw ) ) ) );
		$known_genres    = array_map( static function ( $item ) { return strtolower( remove_accents( $item ) ); }, $genre_choices );
		$custom_genres   = array();
		foreach ( $selected_genres as $selected_genre ) {
			if ( ! in_array( strtolower( remove_accents( $selected_genre ) ), $known_genres, true ) ) {
				$custom_genres[] = $selected_genre;
			}
		}

		$status_terms = get_terms( array( 'taxonomy' => 'game_status', 'hide_empty' => false ) );
		$status_terms = is_wp_error( $status_terms ) ? array() : $status_terms;
		$current_status = wp_get_post_terms( $post->ID, 'game_status', array( 'fields' => 'ids' ) );
		$current_status = is_wp_error( $current_status ) || empty( $current_status ) ? 0 : absint( $current_status[0] );

		$parent_games = get_posts( array( 'post_type' => 'games', 'post_status' => array( 'publish', 'draft', 'private' ), 'posts_per_page' => 200, 'post__not_in' => array( $post->ID ), 'orderby' => 'title', 'order' => 'ASC' ) );
		$entity_names = array();
		if ( post_type_exists( 'go_entity' ) ) {
			$entities = get_posts( array( 'post_type' => 'go_entity', 'post_status' => 'publish', 'posts_per_page' => 300, 'orderby' => 'title', 'order' => 'ASC' ) );
			$entity_names = array_map( static function ( $entity ) { return go_verge_prepare_game_name( $entity->post_title ); }, $entities );
		}
		$franchise_names = array();
		if ( taxonomy_exists( 'game_franchise' ) ) {
			$franchise_terms = get_terms( array( 'taxonomy' => 'game_franchise', 'hide_empty' => false ) );
			if ( ! is_wp_error( $franchise_terms ) ) {
				$franchise_names = wp_list_pluck( $franchise_terms, 'name' );
			}
		}
		$store_links  = maybe_unserialize( get_post_meta( $post->ID, '_go_store_links', true ) );
		$store_links  = is_array( $store_links ) ? $store_links : array();
		$store_names  = array( 'PlayStation Store', 'Microsoft Store', 'Nintendo eShop', 'Steam', 'Epic Games Store', 'GOG', 'App Store', 'Google Play', 'Outra loja' );
		?>
		<div class="go-game-editor" data-go-game-editor>
			<div class="go-game-editor__intro">
				<p><strong><?php esc_html_e( 'Nome oficial:', 'go-verge' ); ?></strong> <?php esc_html_e( 'use o título do WordPress acima. A descrição editorial usa o editor principal e a imagem de capa usa a Imagem destacada.', 'go-verge' ); ?></p>
				<p><?php esc_html_e( 'Campos opcionais só aparecem na ficha quando preenchidos. Dados antigos e importações continuam compatíveis.', 'go-verge' ); ?></p>
			</div>
			<div class="go-game-editor__tabs" role="tablist" aria-label="<?php esc_attr_e( 'Seções dos dados do game', 'go-verge' ); ?>">
				<?php foreach ( array( 'principal' => 'Informações principais', 'producao' => 'Desenvolvimento', 'plataformas' => 'Plataformas', 'caracteristicas' => 'Gêneros e características', 'lojas' => 'Disponibilidade e lojas', 'relacoes' => 'Conteúdo relacionado' ) as $tab => $tab_label ) : ?>
					<button type="button" class="go-game-editor__tab<?php echo 'principal' === $tab ? ' is-active' : ''; ?>" role="tab" aria-selected="<?php echo 'principal' === $tab ? 'true' : 'false'; ?>" aria-controls="go-game-panel-<?php echo esc_attr( $tab ); ?>" data-go-game-tab="<?php echo esc_attr( $tab ); ?>"><?php echo esc_html( $tab_label ); ?></button>
				<?php endforeach; ?>
			</div>

			<section id="go-game-panel-principal" class="go-game-editor__panel is-active" role="tabpanel" data-go-game-panel="principal">
				<div class="go-game-fields">
					<?php $field( '_go_summary', 'Linha de apoio ou descrição curta', 'textarea', 'Resumo curto usado no perfil e na abertura da ficha.', array( 'optional' => true ) ); ?>
					<?php $field( '_go_release_status', 'Status do lançamento', 'select', '', array( 'choices' => array( '' => 'Não definido', 'announced' => 'Anunciado', 'development' => 'Em desenvolvimento', 'early_access' => 'Acesso antecipado', 'released' => 'Lançado', 'delayed' => 'Adiado', 'cancelled' => 'Cancelado' ), 'optional' => true ) ); ?>
					<?php if ( $status_terms || $current_status ) : ?><div class="go-game-field">
						<label><strong><?php esc_html_e( 'Status editorial existente', 'go-verge' ); ?></strong> <span><?php esc_html_e( '(compatibilidade)', 'go-verge' ); ?></span></label>
						<input type="hidden" name="go_game_status_sent" value="1">
						<div class="go-game-choice-list"><label><input type="radio" name="go_game_status" value="" <?php checked( 0, $current_status ); ?>> <?php esc_html_e( 'Sem status', 'go-verge' ); ?></label><?php foreach ( $status_terms as $term ) : ?><label><input type="radio" name="go_game_status" value="<?php echo esc_attr( $term->term_id ); ?>" <?php checked( $current_status, $term->term_id ); ?>> <?php echo esc_html( go_verge_prepare_game_name( $term->name ) ); ?></label><?php endforeach; ?></div>
					</div><?php endif; ?>
					<?php $field( '_go_release_date', 'Data de lançamento', preg_match( '/^\d{4}-\d{2}-\d{2}$/', (string) $value( '_go_release_date' ) ) || '' === $value( '_go_release_date' ) ? 'date' : 'text', 'Formato editorial preferido: AAAA-MM-DD.', array( 'optional' => true ) ); ?>
					<?php $field( '_go_early_access_date', 'Data de acesso antecipado', 'date', '', array( 'optional' => true ) ); ?>
					<?php $field( 'go_game_franchise_name', 'Franquia ou série', 'text', 'Selecione uma franquia existente ou digite uma nova.', array( 'optional' => true, 'datalist' => $franchise_names ) ); ?>
					<?php $field( '_go_edition', 'Edição do jogo', 'text', '', array( 'optional' => true, 'placeholder' => 'Standard, Deluxe, Ultimate…' ) ); ?>
					<?php $field( '_go_content_type', 'Tipo de lançamento', 'select', '', array( 'choices' => array( '' => 'Jogo completo', 'remake' => 'Remake', 'remaster' => 'Remasterização', 'expansion' => 'Expansão', 'dlc' => 'DLC' ), 'optional' => true ) ); ?>
					<div class="go-game-field"><label for="go-game-parent"><strong><?php esc_html_e( 'Jogo principal relacionado', 'go-verge' ); ?></strong> <span><?php esc_html_e( '(opcional)', 'go-verge' ); ?></span></label><select id="go-game-parent" name="go_game_fields[_go_parent_game_id]" class="widefat"><option value=""><?php esc_html_e( 'Nenhum', 'go-verge' ); ?></option><?php foreach ( $parent_games as $parent_game ) : ?><option value="<?php echo esc_attr( $parent_game->ID ); ?>" <?php selected( absint( $value( '_go_parent_game_id' ) ), $parent_game->ID ); ?>><?php echo esc_html( go_verge_game_name( $parent_game ) ); ?></option><?php endforeach; ?></select></div>
					<?php $image_field( '_go_hero_image_id', 'Imagem horizontal ou hero' ); ?>
					<?php $image_field( '_go_logo_id', 'Logo do jogo' ); ?>
				</div>
			</section>

			<section id="go-game-panel-producao" class="go-game-editor__panel" role="tabpanel" data-go-game-panel="producao" hidden><div class="go-game-fields">
				<?php $field( '_go_developer', 'Desenvolvedora', 'text', 'Selecione uma entidade existente ou digite uma nova.', array( 'optional' => true, 'datalist' => $entity_names ) ); ?>
				<?php $field( '_go_publisher', 'Publicadora', 'text', 'Selecione uma entidade existente ou digite uma nova.', array( 'optional' => true, 'datalist' => $entity_names ) ); ?>
				<?php $field( '_go_distributor', 'Distribuidora', 'text', 'Selecione uma entidade existente ou digite uma nova.', array( 'optional' => true, 'datalist' => $entity_names ) ); ?>
				<?php $field( '_go_director', 'Diretor ou criador', 'text', '', array( 'optional' => true, 'datalist' => $entity_names ) ); ?>
				<?php $field( '_go_engine', 'Motor gráfico', 'text', '', array( 'optional' => true ) ); ?>
				<?php $field( '_go_country', 'País de origem', 'text', '', array( 'optional' => true ) ); ?>
			</div></section>

			<section id="go-game-panel-plataformas" class="go-game-editor__panel" role="tabpanel" data-go-game-panel="plataformas" hidden>
				<input type="hidden" name="go_game_platforms_sent" value="1">
				<div class="go-game-platform-grid"><?php foreach ( $platform_choices as $platform ) : $checked = in_array( strtolower( remove_accents( $platform ) ), array_map( static function ( $item ) { return strtolower( remove_accents( $item ) ); }, $selected_platforms ), true ); ?><label><input type="checkbox" name="go_game_platforms[]" value="<?php echo esc_attr( $platform ); ?>" <?php checked( $checked ); ?>> <span><?php echo esc_html( $platform ); ?></span></label><?php endforeach; ?></div>
				<div class="go-game-field go-game-field--wide"><label for="go-game-other-platforms"><strong><?php esc_html_e( 'Outras plataformas', 'go-verge' ); ?></strong> <span><?php esc_html_e( '(opcional)', 'go-verge' ); ?></span></label><input id="go-game-other-platforms" class="widefat" type="text" name="go_game_other_platforms" value="<?php echo esc_attr( implode( ', ', $custom_platforms ) ); ?>"><p class="description"><?php esc_html_e( 'Separe plataformas históricas ou adicionais por vírgulas.', 'go-verge' ); ?></p></div>
			</section>

			<section id="go-game-panel-caracteristicas" class="go-game-editor__panel" role="tabpanel" data-go-game-panel="caracteristicas" hidden><div class="go-game-fields">
				<?php $field( '_go_primary_genre', 'Gênero principal', 'text', '', array( 'optional' => true, 'datalist' => $genre_choices ) ); ?>
				<div class="go-game-field go-game-field--wide"><label><strong><?php esc_html_e( 'Gêneros principais e secundários', 'go-verge' ); ?></strong> <span><?php esc_html_e( '(opcional)', 'go-verge' ); ?></span></label><input type="hidden" name="go_game_genres_sent" value="1"><div class="go-game-platform-grid"><?php $selected_genres_normalized = array_map( static function ( $item ) { return strtolower( remove_accents( $item ) ); }, $selected_genres ); foreach ( $genre_choices as $genre ) : ?><label><input type="checkbox" name="go_game_genres[]" value="<?php echo esc_attr( $genre ); ?>" <?php checked( in_array( strtolower( remove_accents( $genre ) ), $selected_genres_normalized, true ) ); ?>> <span><?php echo esc_html( $genre ); ?></span></label><?php endforeach; ?></div><input class="widefat" type="text" name="go_game_other_genres" value="<?php echo esc_attr( implode( ', ', $custom_genres ) ); ?>" placeholder="Outros gêneros, separados por vírgulas"><p class="description"><?php esc_html_e( 'A exibição usa separadores editoriais e nunca concatena os gêneros sem pontuação.', 'go-verge' ); ?></p></div>
				<?php $field( '_go_modes', 'Modos de jogo', 'text', 'Ex.: Um jogador, Multijogador, Cooperativo.', array( 'optional' => true ) ); ?>
				<?php $field( '_go_perspective', 'Perspectiva', 'text', '', array( 'optional' => true ) ); ?>
				<?php $field( '_go_online_features', 'Recursos online', 'text', 'Separe por vírgulas.', array( 'optional' => true ) ); ?>
				<?php $field( '_go_players', 'Quantidade de jogadores', 'text', '', array( 'optional' => true ) ); ?>
				<?php $field( '_go_languages', 'Idiomas', 'text', 'Separe por vírgulas.', array( 'optional' => true ) ); ?>
				<?php $field( '_go_age_rating', 'Classificação indicativa', 'text', '', array( 'optional' => true ) ); ?>
				<?php foreach ( array( '_go_coop' => 'Suporte a cooperativo', '_go_cross_play' => 'Cross-play', '_go_cross_save' => 'Cross-save', '_go_shared_progression' => 'Progressão compartilhada', '_go_ptbr_subtitles' => 'Legendas em português', '_go_ptbr_dubbing' => 'Dublagem em português' ) as $bool_key => $bool_label ) { $field( $bool_key, $bool_label, 'boolean', '', array( 'optional' => true, 'toggle_label' => 'Disponível' ) ); } ?>
			</div></section>

			<section id="go-game-panel-lojas" class="go-game-editor__panel" role="tabpanel" data-go-game-panel="lojas" hidden>
				<div class="go-game-fields">
					<?php $field( '_go_official_site_url', 'Site oficial', 'url', '', array( 'optional' => true, 'placeholder' => 'https://' ) ); ?>
					<?php $field( '_go_trailer_url', 'Trailer oficial', 'url', '', array( 'optional' => true, 'placeholder' => 'https://' ) ); ?>
					<?php $field( '_go_price', 'Preço sugerido', 'text', '', array( 'optional' => true ) ); ?>
					<?php $field( '_go_subscription_services', 'Serviços de assinatura', 'text', 'Separe por vírgulas.', array( 'optional' => true ) ); ?>
					<?php $field( '_go_physical_edition', 'Edição física', 'boolean', '', array( 'optional' => true, 'toggle_label' => 'Disponível' ) ); ?>
					<?php $field( '_go_digital_edition', 'Edição digital', 'boolean', '', array( 'optional' => true, 'toggle_label' => 'Disponível' ) ); ?>
				</div>
				<div class="go-game-store-editor" data-go-game-stores>
					<div class="go-game-store-editor__head"><h3><?php esc_html_e( 'Links de lojas', 'go-verge' ); ?></h3><button type="button" class="button" data-go-game-store-add><?php esc_html_e( 'Adicionar loja', 'go-verge' ); ?></button></div>
					<input type="hidden" name="go_game_store_links_sent" value="1">
					<div data-go-game-store-rows><?php foreach ( $store_links as $index => $store ) : ?><div class="go-game-store-row"><select name="go_game_store_links[<?php echo esc_attr( $index ); ?>][platform]"><?php $existing_store = sanitize_text_field( $store['platform'] ?? '' ); if ( $existing_store && ! in_array( $existing_store, $store_names, true ) ) : ?><option value="<?php echo esc_attr( $existing_store ); ?>" selected><?php echo esc_html( $existing_store ); ?></option><?php endif; ?><?php foreach ( $store_names as $store_name ) : ?><option value="<?php echo esc_attr( $store_name ); ?>" <?php selected( $existing_store, $store_name ); ?>><?php echo esc_html( $store_name ); ?></option><?php endforeach; ?></select><input type="url" name="go_game_store_links[<?php echo esc_attr( $index ); ?>][url]" value="<?php echo esc_attr( $store['url'] ?? '' ); ?>" placeholder="https://"><input type="text" name="go_game_store_links[<?php echo esc_attr( $index ); ?>][label]" value="<?php echo esc_attr( $store['label'] ?? '' ); ?>" placeholder="Rótulo opcional"><button type="button" class="button-link-delete" data-go-game-store-remove><?php esc_html_e( 'Remover', 'go-verge' ); ?></button></div><?php endforeach; ?></div>
					<script type="text/html" data-go-game-store-template><div class="go-game-store-row"><select name="go_game_store_links[__INDEX__][platform]"><?php foreach ( $store_names as $store_name ) : ?><option value="<?php echo esc_attr( $store_name ); ?>"><?php echo esc_html( $store_name ); ?></option><?php endforeach; ?></select><input type="url" name="go_game_store_links[__INDEX__][url]" value="" placeholder="https://"><input type="text" name="go_game_store_links[__INDEX__][label]" value="" placeholder="Rótulo opcional"><button type="button" class="button-link-delete" data-go-game-store-remove><?php esc_html_e( 'Remover', 'go-verge' ); ?></button></div></script>
				</div>
			</section>

			<section id="go-game-panel-relacoes" class="go-game-editor__panel" role="tabpanel" data-go-game-panel="relacoes" hidden>
				<div class="notice inline notice-info"><p><?php esc_html_e( 'Notícias, guias, reviews, promoções e vídeos usam o relacionamento existente go_linked_game_id, com compatibilidade para go_review_game_id. Nenhuma relação paralela é criada aqui.', 'go-verge' ); ?></p></div>
				<p><a class="button" href="<?php echo esc_url( admin_url( 'edit.php?post_type=post&go_linked_game_id=' . $post->ID ) ); ?>"><?php esc_html_e( 'Ver matérias vinculadas', 'go-verge' ); ?></a> <?php if ( post_type_exists( 'go_promotion' ) ) : ?><a class="button" href="<?php echo esc_url( admin_url( 'edit.php?post_type=go_promotion&go_linked_game_id=' . $post->ID ) ); ?>"><?php esc_html_e( 'Ver promoções vinculadas', 'go-verge' ); ?></a><?php endif; ?></p>
			</section>
		</div>
		<?php
	}
}

if ( ! function_exists( 'go_verge_game_editor_save' ) ) {
	/** Save only explicitly submitted fields, with type-specific validation. */
	function go_verge_game_editor_save( $post_id ) {
		if ( ! isset( $_POST['go_verge_game_editor_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_verge_game_editor_nonce'] ) ), 'go_verge_save_game_editor' ) ) {
			return;
		}
		if ( ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! current_user_can( 'edit_post', $post_id ) ) {
			return;
		}
		if ( ! isset( $_POST['go_game_fields'] ) || ! is_array( $_POST['go_game_fields'] ) ) {
			return;
		}

		$submitted = wp_unslash( $_POST['go_game_fields'] );
		$cleared_fields = get_post_meta( $post_id, '_go_editor_cleared_fields', true );
		$cleared_fields = is_array( $cleared_fields ) ? array_values( array_filter( array_map( 'sanitize_key', $cleared_fields ) ) ) : array();
		$mark_cleared = static function ( $key, $is_cleared ) use ( &$cleared_fields ) {
			$key = sanitize_key( $key );
			if ( $is_cleared ) {
				$cleared_fields[] = $key;
				$cleared_fields   = array_values( array_unique( $cleared_fields ) );
			} else {
				$cleared_fields = array_values( array_diff( $cleared_fields, array( $key ) ) );
			}
		};
		foreach ( go_verge_game_editor_schema() as $key => $type ) {
			if ( ! array_key_exists( $key, $submitted ) ) {
				// An omitted checkbox means "off" only when this game already had
				// that field. New boolean defaults are never written onto old games.
				if ( 'bool' === $type && metadata_exists( 'post', $post_id, $key ) ) {
					$submitted[ $key ] = '0';
				} else {
					continue;
				}
			}
			$raw = $submitted[ $key ];
			if ( is_array( $raw ) ) {
				$raw = reset( $raw );
			}
			$value = '';
			switch ( $type ) {
				case 'textarea': $value = sanitize_textarea_field( $raw ); break;
				case 'url': $value = esc_url_raw( $raw ); break;
				case 'bool': $value = empty( $raw ) ? '0' : '1'; break;
				case 'image_id':
					$value = absint( $raw );
					$value = $value && wp_attachment_is_image( $value ) ? $value : '';
					break;
				case 'game_id':
					$value = absint( $raw );
					$value = $value && $value !== (int) $post_id && 'games' === get_post_type( $value ) ? $value : '';
					break;
				case 'date':
					$value = sanitize_text_field( $raw );
					if ( '' !== $value ) {
						$date = DateTime::createFromFormat( '!Y-m-d', $value, wp_timezone() );
						if ( ! $date || $date->format( 'Y-m-d' ) !== $value ) {
							continue 2; // Preserve an unparseable historical value.
						}
					}
					break;
				case 'content_type':
					$value = sanitize_key( $raw );
					$value = in_array( $value, array( '', 'remake', 'remaster', 'expansion', 'dlc' ), true ) ? $value : '';
					break;
				case 'release_status':
					$value = sanitize_key( $raw );
					$value = in_array( $value, array( '', 'announced', 'development', 'early_access', 'released', 'delayed', 'cancelled' ), true ) ? $value : '';
					break;
				case 'list':
					$items = is_array( $raw ) ? $raw : preg_split( '/[,;|]+/u', (string) $raw );
					$items = array_values( array_unique( array_filter( array_map( 'sanitize_text_field', array_map( 'trim', (array) $items ) ) ) ) );
					$value = implode( ', ', $items );
					break;
				default: $value = sanitize_text_field( $raw );
			}
			$current_display = go_verge_game_editor_value( $post_id, $key );
			if ( (string) $value === (string) $current_display && ! metadata_exists( 'post', $post_id, $key ) ) {
				continue;
			}
			if ( '' === $value && '' === trim( (string) $current_display ) && ! metadata_exists( 'post', $post_id, $key ) ) {
				continue;
			}

			if ( '' === $value ) {
				delete_post_meta( $post_id, $key );
				$mark_cleared( $key, true );
			} else {
				update_post_meta( $post_id, $key, $value );
				$mark_cleared( $key, false );
			}
		}

		if ( isset( $_POST['go_game_platforms_sent'] ) ) {
			$platforms = isset( $_POST['go_game_platforms'] ) && is_array( $_POST['go_game_platforms'] ) ? wp_unslash( $_POST['go_game_platforms'] ) : array();
			$other     = isset( $_POST['go_game_other_platforms'] ) ? preg_split( '/[,;]+/u', sanitize_text_field( wp_unslash( $_POST['go_game_other_platforms'] ) ) ) : array();
			$platforms = array_values( array_unique( array_filter( array_map( 'sanitize_text_field', array_merge( $platforms, $other ) ) ) ) );
			$current_platforms = trim( (string) go_verge_game_editor_value( $post_id, '_go_platforms' ) );
			if ( ! $platforms && '' === $current_platforms && ! metadata_exists( 'post', $post_id, '_go_platforms' ) ) {
				// Untouched empty section on a historical game.
			} elseif ( $platforms ) {
				update_post_meta( $post_id, '_go_platforms', implode( ', ', $platforms ) );
				$mark_cleared( '_go_platforms', false );
			} else {
				delete_post_meta( $post_id, '_go_platforms' );
				$mark_cleared( '_go_platforms', true );
			}
			if ( taxonomy_exists( 'game_platform' ) && ( $platforms || '' !== $current_platforms ) ) {
				wp_set_object_terms( $post_id, $platforms, 'game_platform', false );
			}
		}

		if ( isset( $_POST['go_game_status_sent'] ) && taxonomy_exists( 'game_status' ) ) {
			$status_id = isset( $_POST['go_game_status'] ) ? absint( $_POST['go_game_status'] ) : 0;
			$status_id = $status_id && term_exists( $status_id, 'game_status' ) ? $status_id : 0;
			wp_set_object_terms( $post_id, $status_id ? array( $status_id ) : array(), 'game_status', false );
		}

		if ( isset( $_POST['go_game_genres_sent'] ) ) {
			$genres = isset( $_POST['go_game_genres'] ) && is_array( $_POST['go_game_genres'] ) ? wp_unslash( $_POST['go_game_genres'] ) : array();
			$other  = isset( $_POST['go_game_other_genres'] ) ? preg_split( '/[,;|]+/u', sanitize_text_field( wp_unslash( $_POST['go_game_other_genres'] ) ) ) : array();
			$genres = array_values( array_unique( array_filter( array_map( 'sanitize_text_field', array_merge( $genres, $other ) ) ) ) );
			$current_genres = trim( (string) go_verge_game_editor_value( $post_id, '_go_genres' ) );
			if ( ! $genres && '' === $current_genres && ! metadata_exists( 'post', $post_id, '_go_genres' ) ) {
				// Untouched empty section on a historical game.
			} elseif ( $genres ) {
				update_post_meta( $post_id, '_go_genres', implode( ', ', $genres ) );
				$mark_cleared( '_go_genres', false );
			} else {
				delete_post_meta( $post_id, '_go_genres' );
				$mark_cleared( '_go_genres', true );
			}
		}

		if ( taxonomy_exists( 'game_franchise' ) && array_key_exists( 'go_game_franchise_name', $submitted ) ) {
			$franchise = sanitize_text_field( $submitted['go_game_franchise_name'] );
			wp_set_object_terms( $post_id, $franchise ? array( $franchise ) : array(), 'game_franchise', false );
		}

		if ( isset( $_POST['go_game_store_links_sent'] ) ) {
			$rows  = isset( $_POST['go_game_store_links'] ) && is_array( $_POST['go_game_store_links'] ) ? wp_unslash( $_POST['go_game_store_links'] ) : array();
			$clean = array();
			foreach ( $rows as $row ) {
				if ( ! is_array( $row ) ) { continue; }
				$url = esc_url_raw( $row['url'] ?? '' );
				if ( ! $url ) { continue; }
				$clean[] = array( 'platform' => sanitize_text_field( $row['platform'] ?? '' ), 'url' => $url, 'label' => sanitize_text_field( $row['label'] ?? '' ) );
			}
			$had_store_links = metadata_exists( 'post', $post_id, '_go_store_links' );
			if ( ! $clean && ! $had_store_links ) {
				// Do not manufacture an empty state for games that never had stores.
			} elseif ( $clean ) {
				update_post_meta( $post_id, '_go_store_links', $clean );
				$mark_cleared( '_go_store_links', false );
			} else {
				delete_post_meta( $post_id, '_go_store_links' );
				$mark_cleared( '_go_store_links', true );
			}
		}

		if ( $cleared_fields ) {
			update_post_meta( $post_id, '_go_editor_cleared_fields', $cleared_fields );
		} else {
			delete_post_meta( $post_id, '_go_editor_cleared_fields' );
		}
	}
}
add_action( 'save_post_games', 'go_verge_game_editor_save', 40 );

if ( ! function_exists( 'go_verge_game_editor_admin_assets' ) ) {
	function go_verge_game_editor_admin_assets( $hook_suffix ) {
		if ( ! in_array( $hook_suffix, array( 'post.php', 'post-new.php' ), true ) ) {
			return;
		}
		$screen = get_current_screen();
		if ( ! $screen || 'games' !== $screen->post_type ) {
			return;
		}
		wp_enqueue_media();
		wp_enqueue_style( 'go-verge-game-editor', GO_VERGE_URI . '/assets/css/game-editor.css', array(), go_verge_asset_version( '/assets/css/game-editor.css' ) );
		wp_enqueue_script( 'go-verge-game-editor', GO_VERGE_URI . '/assets/js/game-editor.js', array(), go_verge_asset_version( '/assets/js/game-editor.js' ), true );
	}
}
add_action( 'admin_enqueue_scripts', 'go_verge_game_editor_admin_assets', 50 );

if ( ! function_exists( 'go_verge_game_sync_search_compat' ) ) {
	/** Normalize the installed sync plugin's external search before JSON output. */
	function go_verge_game_sync_search_compat() {
		check_ajax_referer( 'go_gs_admin', 'nonce' );
		if ( ! current_user_can( 'edit_posts' ) ) {
			wp_send_json_error( array( 'message' => __( 'Sem permissão.', 'go-verge' ) ), 403 );
		}
		$query = isset( $_POST['query'] ) ? sanitize_text_field( wp_unslash( $_POST['query'] ) ) : '';
		if ( '' === $query ) {
			wp_send_json_error( array( 'message' => __( 'Digite um termo de busca.', 'go-verge' ) ) );
		}
		$client  = new GO_GS_Igdb_Client();
		$results = $client->search( $query );
		if ( is_wp_error( $results ) ) {
			wp_send_json_error( array( 'message' => $results->get_error_message() ) );
		}
		wp_send_json_success( array( 'results' => go_verge_prepare_game_rest_payload( $results ) ) );
	}
}

if ( ! function_exists( 'go_verge_game_sync_install_search_compat' ) ) {
	function go_verge_game_sync_install_search_compat() {
		if ( ! class_exists( 'GO_GS_Admin' ) || ! class_exists( 'GO_GS_Igdb_Client' ) ) {
			return;
		}
		remove_action( 'wp_ajax_go_gs_search', array( 'GO_GS_Admin', 'ajax_search' ) );
		add_action( 'wp_ajax_go_gs_search', 'go_verge_game_sync_search_compat' );
	}
}
add_action( 'admin_init', 'go_verge_game_sync_install_search_compat', 20 );

if ( ! function_exists( 'go_verge_game_editor_filter_related_admin' ) ) {
	/** Make the related-content buttons use the existing relation meta. */
	function go_verge_game_editor_filter_related_admin( $query ) {
		if ( ! is_admin() || ! $query->is_main_query() || empty( $_GET['go_linked_game_id'] ) ) {
			return;
		}
		$game_id = absint( $_GET['go_linked_game_id'] );
		if ( ! $game_id ) {
			return;
		}
		$query->set(
			'meta_query',
			array(
				'relation' => 'OR',
				array( 'key' => 'go_linked_game_id', 'value' => $game_id, 'compare' => '=' ),
				array( 'key' => 'go_review_game_id', 'value' => $game_id, 'compare' => '=' ),
				array( 'key' => 'go_promotion_linked_game_id', 'value' => $game_id, 'compare' => '=' ),
			)
		);
	}
}
add_action( 'pre_get_posts', 'go_verge_game_editor_filter_related_admin' );
