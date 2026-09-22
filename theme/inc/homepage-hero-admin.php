<?php
/**
 * Manual editorial curation for the six-story homepage hero.
 *
 * Empty slots intentionally remain automatic, so editors can curate only the
 * positions that matter while preserving the homepage's existing ranking
 * rules for the rest of the grid.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Option key used by the homepage hero picker. */
if ( ! defined( 'GO_VERGE_HOMEPAGE_HERO_OPTION' ) ) {
	define( 'GO_VERGE_HOMEPAGE_HERO_OPTION', 'go_verge_homepage_hero_posts' );
}

/** Post meta key used to keep a story out of the homepage hero. */
if ( ! defined( 'GO_VERGE_HOMEPAGE_HERO_EXCLUDE_META' ) ) {
	define( 'GO_VERGE_HOMEPAGE_HERO_EXCLUDE_META', '_go_verge_exclude_homepage_hero' );
}

/**
 * Whether a published story is explicitly blocked from the homepage hero.
 *
 * @param int $post_id Post ID.
 * @return bool
 */
function go_verge_is_post_excluded_from_homepage_hero( $post_id ) {
	$post_id = absint( $post_id );
	return $post_id > 0 && '1' === (string) get_post_meta( $post_id, GO_VERGE_HOMEPAGE_HERO_EXCLUDE_META, true );
}

/**
 * Return IDs explicitly blocked from the homepage hero.
 *
 * The query is intentionally ID-only and cached for the current request.
 *
 * @return int[]
 */
function go_verge_get_homepage_hero_excluded_post_ids() {
	static $excluded_ids = null;

	if ( null !== $excluded_ids ) {
		return $excluded_ids;
	}

	$excluded_ids = get_posts(
		array(
			'post_type'              => 'post',
			'post_status'            => 'publish',
			'posts_per_page'         => -1,
			'fields'                 => 'ids',
			'no_found_rows'          => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
			'meta_key'               => GO_VERGE_HOMEPAGE_HERO_EXCLUDE_META,
			'meta_value'             => '1',
		)
	);

	$excluded_ids = array_values( array_unique( array_filter( array_map( 'absint', $excluded_ids ) ) ) );
	return $excluded_ids;
}

/**
 * Normalise saved hero slots to six unique, published post IDs.
 *
 * @param mixed $value Raw option value.
 * @return int[]
 */
function go_verge_sanitize_homepage_hero_slots( $value ) {
	$value  = is_array( $value ) ? array_values( $value ) : array();
	$slots  = array_fill( 0, 6, 0 );
	$used   = array();

	for ( $index = 0; $index < 6; $index++ ) {
		$post_id = isset( $value[ $index ] ) ? absint( $value[ $index ] ) : 0;
		if ( ! $post_id || in_array( $post_id, $used, true ) ) {
			continue;
		}

		$post = get_post( $post_id );
		if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || 'publish' !== $post->post_status ) {
			continue;
		}
		if ( go_verge_is_post_excluded_from_homepage_hero( $post_id ) ) {
			continue;
		}

		$slots[ $index ] = $post_id;
		$used[]          = $post_id;
	}

	return $slots;
}

/**
 * Return the current six manual slots. Zero means "automatic".
 *
 * @return int[]
 */
function go_verge_get_manual_homepage_hero_ids() {
	return go_verge_sanitize_homepage_hero_slots( get_option( GO_VERGE_HOMEPAGE_HERO_OPTION, array() ) );
}

/** Register the option with the Settings API. */
function go_verge_register_homepage_hero_setting() {
	register_setting(
		'go_verge_homepage_hero_group',
		GO_VERGE_HOMEPAGE_HERO_OPTION,
		array(
			'type'              => 'array',
			'sanitize_callback' => 'go_verge_sanitize_homepage_hero_slots',
			'default'           => array_fill( 0, 6, 0 ),
		)
	);
}
add_action( 'admin_init', 'go_verge_register_homepage_hero_setting' );

/** Let theme administrators save this Appearance screen through options.php. */
function go_verge_homepage_hero_option_page_capability() {
	return 'edit_theme_options';
}
add_filter( 'option_page_capability_go_verge_homepage_hero_group', 'go_verge_homepage_hero_option_page_capability' );

/** Add the curation screen under Appearance. */
function go_verge_register_homepage_hero_admin_page() {
	add_theme_page(
		__( 'Hero da homepage', 'go-verge' ),
		__( 'Hero da homepage', 'go-verge' ),
		'edit_theme_options',
		'go-verge-homepage-hero',
		'go_verge_render_homepage_hero_admin_page'
	);
}
add_action( 'admin_menu', 'go_verge_register_homepage_hero_admin_page' );


/** Add a per-story control to keep a post out of the homepage hero. */
function go_verge_register_homepage_hero_exclusion_metabox() {
	add_meta_box(
		'go-verge-homepage-hero-exclusion',
		__( 'Hero da homepage', 'go-verge' ),
		'go_verge_render_homepage_hero_exclusion_metabox',
		'post',
		'side',
		'default'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_homepage_hero_exclusion_metabox' );

/** Render the per-story exclusion checkbox. */
function go_verge_render_homepage_hero_exclusion_metabox( $post ) {
	$excluded = go_verge_is_post_excluded_from_homepage_hero( $post->ID );
	wp_nonce_field( 'go_verge_save_homepage_hero_exclusion', 'go_verge_homepage_hero_exclusion_nonce' );
	?>
	<p>
		<label>
			<input type="checkbox" name="go_verge_exclude_homepage_hero" value="1" <?php checked( $excluded ); ?>>
			<strong><?php esc_html_e( 'Não exibir no hero da homepage', 'go-verge' ); ?></strong>
		</label>
	</p>
	<p class="description">
		<?php esc_html_e( 'A restrição vale somente para o hero. A matéria continua disponível normalmente para outros blocos da homepage, categorias, buscas e feeds.', 'go-verge' ); ?>
	</p>
	<?php
}

/** Save the exclusion checkbox and remove an excluded story from manual slots. */
function go_verge_save_homepage_hero_exclusion( $post_id ) {
	if ( ! isset( $_POST['go_verge_homepage_hero_exclusion_nonce'] ) ) {
		return;
	}

	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_homepage_hero_exclusion_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_homepage_hero_exclusion' ) ) {
		return;
	}
	if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
		return;
	}
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}
	if ( ! current_user_can( 'edit_post', $post_id ) ) {
		return;
	}
	if ( 'post' !== get_post_type( $post_id ) ) {
		return;
	}

	$excluded = isset( $_POST['go_verge_exclude_homepage_hero'] ) && '1' === (string) wp_unslash( $_POST['go_verge_exclude_homepage_hero'] );
	if ( $excluded ) {
		update_post_meta( $post_id, GO_VERGE_HOMEPAGE_HERO_EXCLUDE_META, '1' );

		$slots   = get_option( GO_VERGE_HOMEPAGE_HERO_OPTION, array() );
		$slots   = is_array( $slots ) ? array_values( $slots ) : array();
		$changed = false;
		for ( $index = 0; $index < 6; $index++ ) {
			if ( isset( $slots[ $index ] ) && absint( $slots[ $index ] ) === absint( $post_id ) ) {
				$slots[ $index ] = 0;
				$changed         = true;
			}
		}
		if ( $changed ) {
			update_option( GO_VERGE_HOMEPAGE_HERO_OPTION, array_pad( array_slice( $slots, 0, 6 ), 6, 0 ) );
		}
	} else {
		delete_post_meta( $post_id, GO_VERGE_HOMEPAGE_HERO_EXCLUDE_META );
	}
}
add_action( 'save_post_post', 'go_verge_save_homepage_hero_exclusion' );

/**
 * Position labels match the exact visual order in front-page.php.
 *
 * @return array<int,array<string,string>>
 */
function go_verge_homepage_hero_slot_labels() {
	return array(
		array(
			'title'       => __( '1. Destaque principal', 'go-verge' ),
			'description' => __( 'Matéria grande à esquerda. É a chamada mais importante do hero.', 'go-verge' ),
		),
		array(
			'title'       => __( '2. Lateral superior', 'go-verge' ),
			'description' => __( 'Primeira matéria da coluna lateral.', 'go-verge' ),
		),
		array(
			'title'       => __( '3. Lateral inferior', 'go-verge' ),
			'description' => __( 'Segunda matéria da coluna lateral.', 'go-verge' ),
		),
		array(
			'title'       => __( '4. Faixa inferior, esquerda', 'go-verge' ),
			'description' => __( 'Primeira matéria da linha inferior.', 'go-verge' ),
		),
		array(
			'title'       => __( '5. Faixa inferior, centro', 'go-verge' ),
			'description' => __( 'Segunda matéria da linha inferior.', 'go-verge' ),
		),
		array(
			'title'       => __( '6. Faixa inferior, direita', 'go-verge' ),
			'description' => __( 'Terceira matéria da linha inferior.', 'go-verge' ),
		),
	);
}

/** Render the hero curation screen. */
function go_verge_render_homepage_hero_admin_page() {
	if ( ! current_user_can( 'edit_theme_options' ) ) {
		return;
	}

	$slots  = go_verge_get_manual_homepage_hero_ids();
	$labels = go_verge_homepage_hero_slot_labels();
	?>
	<div class="wrap go-hero-admin">
		<h1><?php esc_html_e( 'Hero da homepage', 'go-verge' ); ?></h1>
		<p class="go-hero-admin__intro">
			<?php esc_html_e( 'Escolha manualmente as matérias de cada posição. Slots vazios continuam automáticos e seguem as regras editoriais atuais do site.', 'go-verge' ); ?>
		</p>

		<?php settings_errors(); ?>

		<form action="options.php" method="post">
			<?php settings_fields( 'go_verge_homepage_hero_group' ); ?>

			<div class="go-hero-admin__grid">
				<?php foreach ( $labels as $index => $label ) : ?>
					<?php
					$post_id       = isset( $slots[ $index ] ) ? absint( $slots[ $index ] ) : 0;
					$selected_post = $post_id ? get_post( $post_id ) : null;
					$title         = $selected_post instanceof WP_Post ? get_the_title( $selected_post ) : '';
					$thumb         = $selected_post instanceof WP_Post ? get_the_post_thumbnail_url( $selected_post, 'thumbnail' ) : '';
					$edit_link     = $selected_post instanceof WP_Post ? get_edit_post_link( $selected_post->ID, '' ) : '';
					?>
					<section class="go-hero-picker<?php echo $post_id ? ' is-selected' : ''; ?>" data-slot="<?php echo esc_attr( (string) $index ); ?>">
						<div class="go-hero-picker__heading">
							<div>
								<h2><?php echo esc_html( $label['title'] ); ?></h2>
								<p><?php echo esc_html( $label['description'] ); ?></p>
							</div>
							<span class="go-hero-picker__mode"><?php echo $post_id ? esc_html__( 'Manual', 'go-verge' ) : esc_html__( 'Automático', 'go-verge' ); ?></span>
						</div>

						<input
							type="hidden"
							class="go-hero-picker__id"
							name="<?php echo esc_attr( GO_VERGE_HOMEPAGE_HERO_OPTION ); ?>[<?php echo esc_attr( (string) $index ); ?>]"
							value="<?php echo esc_attr( (string) $post_id ); ?>"
						>

						<div class="go-hero-picker__selected"<?php echo $post_id ? '' : ' hidden'; ?>>
							<div class="go-hero-picker__thumb">
								<?php if ( $thumb ) : ?>
									<img src="<?php echo esc_url( $thumb ); ?>" alt="">
								<?php endif; ?>
							</div>
							<div class="go-hero-picker__selected-copy">
								<strong class="go-hero-picker__selected-title"><?php echo esc_html( $title ); ?></strong>
								<div class="go-hero-picker__selected-actions">
									<?php if ( $edit_link ) : ?>
										<a class="go-hero-picker__edit" href="<?php echo esc_url( $edit_link ); ?>"><?php esc_html_e( 'Editar matéria', 'go-verge' ); ?></a>
									<?php else : ?>
										<a class="go-hero-picker__edit" href="#" hidden><?php esc_html_e( 'Editar matéria', 'go-verge' ); ?></a>
									<?php endif; ?>
									<button type="button" class="button-link-delete go-hero-picker__clear"><?php esc_html_e( 'Remover escolha', 'go-verge' ); ?></button>
								</div>
							</div>
						</div>

						<div class="go-hero-picker__search-wrap">
							<label for="go-hero-search-<?php echo esc_attr( (string) $index ); ?>"><?php esc_html_e( 'Buscar matéria', 'go-verge' ); ?></label>
							<div class="go-hero-picker__search-row">
								<input
									type="search"
									id="go-hero-search-<?php echo esc_attr( (string) $index ); ?>"
									class="regular-text go-hero-picker__search"
									placeholder="<?php echo esc_attr__( 'Digite o título da matéria…', 'go-verge' ); ?>"
									autocomplete="off"
								>
								<span class="spinner go-hero-picker__spinner" aria-hidden="true"></span>
							</div>
							<div class="go-hero-picker__results" role="listbox" hidden></div>
						</div>
					</section>
				<?php endforeach; ?>
			</div>

			<div class="go-hero-admin__footer">
				<?php submit_button( __( 'Salvar destaques', 'go-verge' ), 'primary', 'submit', false ); ?>
				<button type="button" class="button go-hero-admin__reset"><?php esc_html_e( 'Voltar tudo para automático', 'go-verge' ); ?></button>
			</div>
		</form>
	</div>
	<?php
}

/** Load the picker UI only on its admin screen. */
function go_verge_homepage_hero_admin_assets( $hook_suffix ) {
	if ( 'appearance_page_go-verge-homepage-hero' !== $hook_suffix ) {
		return;
	}

	$css_rel = '/assets/css/homepage-hero-admin.css';
	$js_rel  = '/assets/js/homepage-hero-admin.js';

	wp_enqueue_style(
		'go-verge-homepage-hero-admin',
		GO_VERGE_URI . $css_rel,
		array(),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $css_rel ) : GO_VERGE_VERSION
	);
	wp_enqueue_script(
		'go-verge-homepage-hero-admin',
		GO_VERGE_URI . $js_rel,
		array( 'jquery' ),
		function_exists( 'go_verge_asset_version' ) ? go_verge_asset_version( $js_rel ) : GO_VERGE_VERSION,
		true
	);
	wp_localize_script(
		'go-verge-homepage-hero-admin',
		'GoVergeHeroAdmin',
		array(
			'ajaxUrl'       => admin_url( 'admin-ajax.php' ),
			'nonce'         => wp_create_nonce( 'go_verge_hero_search_posts' ),
			'emptyText'     => __( 'Nenhuma matéria encontrada.', 'go-verge' ),
			'errorText'     => __( 'Não foi possível buscar matérias agora.', 'go-verge' ),
			'automaticText' => __( 'Automático', 'go-verge' ),
			'manualText'    => __( 'Manual', 'go-verge' ),
			'editText'      => __( 'Editar matéria', 'go-verge' ),
		)
	);
}
add_action( 'admin_enqueue_scripts', 'go_verge_homepage_hero_admin_assets' );

/** AJAX search used by all six post pickers. */
function go_verge_ajax_homepage_hero_search_posts() {
	if ( ! current_user_can( 'edit_theme_options' ) ) {
		wp_send_json_error( array( 'message' => __( 'Sem permissão para editar o hero.', 'go-verge' ) ), 403 );
	}

	check_ajax_referer( 'go_verge_hero_search_posts', 'nonce' );

	$query_text = isset( $_GET['q'] ) ? sanitize_text_field( wp_unslash( $_GET['q'] ) ) : '';
	$args       = array(
		'post_type'           => 'post',
		'post_status'         => 'publish',
		'posts_per_page'      => 12,
		'ignore_sticky_posts' => true,
		'no_found_rows'       => true,
		'orderby'             => 'date',
		'order'               => 'DESC',
		'post__not_in'        => go_verge_get_homepage_hero_excluded_post_ids(),
	);

	if ( '' !== $query_text ) {
		$args['s'] = $query_text;
	}

	$posts   = new WP_Query( $args );
	$results = array();

	foreach ( $posts->posts as $post ) {
		$categories = get_the_category( $post->ID );
		$results[]  = array(
			'id'       => (int) $post->ID,
			'title'    => html_entity_decode( wp_strip_all_tags( get_the_title( $post ) ), ENT_QUOTES, get_bloginfo( 'charset' ) ?: 'UTF-8' ),
			'date'     => get_the_date( get_option( 'date_format' ), $post ),
			'category' => ! empty( $categories[0] ) ? $categories[0]->name : '',
			'thumb'    => get_the_post_thumbnail_url( $post, 'thumbnail' ) ?: '',
			'editUrl'  => get_edit_post_link( $post->ID, 'raw' ) ?: '',
		);
	}

	wp_send_json_success( $results );
}
add_action( 'wp_ajax_go_verge_hero_search_posts', 'go_verge_ajax_homepage_hero_search_posts' );
