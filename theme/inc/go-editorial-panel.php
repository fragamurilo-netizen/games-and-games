<?php
/**
 * Movable all-in-one editorial control panel.
 *
 * The panel centralises the fields needed to publish while deliberately
 * preserving WordPress' native tag selector. Editors keep the tag workflow
 * they already know; categories and presentation stay compact here.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }


/** Contextual help used by the fallback Go Editorial panel and compatible desks. */
function go_verge_editorial_field_help( $label, $help ) {
	if ( function_exists( 'go_verge_admin_metric_help' ) ) { return go_verge_admin_metric_help( $label, $help ); }
	static $seq = 0; $seq++; $id = 'go-ed-tip-' . $seq;
	return '<span class="go-pi-help-wrap"><button type="button" class="go-pi-help" aria-label="' . esc_attr( 'Explicar: ' . wp_strip_all_tags( (string) $label ) ) . '" aria-describedby="' . esc_attr( $id ) . '" data-help="' . esc_attr( $help ) . '" aria-expanded="false">?</button><span class="go-pi-tooltip" role="tooltip" id="' . esc_attr( $id ) . '">' . esc_html( $help ) . '</span></span>';
}

/** Register optional presentation metadata for REST/Gutenberg persistence. */
function go_verge_register_editorial_panel_meta() {
	register_post_meta( 'post', '_go_post_subtitle', array(
		'type'              => 'string',
		'single'            => true,
		'show_in_rest'      => true,
		'revisions_enabled' => true,
		'sanitize_callback' => 'sanitize_textarea_field',
		'auth_callback'     => static function () { return current_user_can( 'edit_posts' ); },
	) );

	register_post_meta( 'post', '_go_article_eyebrow', array(
		'type'              => 'string',
		'single'            => true,
		'show_in_rest'      => true,
		'revisions_enabled' => true,
		'sanitize_callback' => 'sanitize_text_field',
		'auth_callback'     => static function () { return current_user_can( 'edit_posts' ); },
	) );

}
add_action( 'init', 'go_verge_register_editorial_panel_meta', 40 );

/** Add the one movable panel and remove only fields it truly replaces. */
function go_verge_register_editorial_control_box() {
	if ( defined( 'GED_VERSION' ) ) {
		return;
	}
	add_meta_box(
		'go-verge-editorial-control',
		__( 'Go Editorial', 'go-verge' ),
		'go_verge_render_editorial_control_box',
		'post',
		'normal',
		'high'
	);

	remove_meta_box( 'go-verge-article-subject', 'post', 'side' );
	remove_meta_box( 'go-verge-support-line', 'post', 'normal' );
	remove_meta_box( 'categorydiv', 'post', 'side' );
	/* Tags intentionally remain native: do not remove tagsdiv-post_tag. */
}
add_action( 'add_meta_boxes_post', 'go_verge_register_editorial_control_box', 120 );

/** Return categories in true hierarchy order, not one long alphabetical list. */
function go_verge_editorial_category_tree( $terms ) {
	$terms = array_values( array_filter( (array) $terms, static function ( $term ) { return $term instanceof WP_Term; } ) );
	$children = array();
	foreach ( $terms as $term ) {
		$children[ (int) $term->parent ][] = $term;
	}
	foreach ( $children as &$siblings ) {
		usort( $siblings, static function ( $a, $b ) { return strcasecmp( $a->name, $b->name ); } );
	}
	unset( $siblings );

	$out = array();
	$walk = static function ( $parent, $depth ) use ( &$walk, &$out, $children ) {
		if ( empty( $children[ $parent ] ) ) { return; }
		foreach ( $children[ $parent ] as $term ) {
			$out[] = array( 'term' => $term, 'depth' => $depth );
			$walk( (int) $term->term_id, $depth + 1 );
		}
	};
	$walk( 0, 0 );

	/* Orphaned terms are rare, but should never disappear from the editor. */
	$seen = array_map( static function ( $item ) { return (int) $item['term']->term_id; }, $out );
	foreach ( $terms as $term ) {
		if ( ! in_array( (int) $term->term_id, $seen, true ) ) {
			$out[] = array( 'term' => $term, 'depth' => 0 );
		}
	}
	return $out;
}

/** Human-readable breadcrumb path for a category. */
function go_verge_editorial_category_path( WP_Term $term ) {
	$names = array( $term->name );
	foreach ( array_reverse( get_ancestors( $term->term_id, 'category', 'taxonomy' ) ) as $ancestor_id ) {
		$ancestor = get_term( $ancestor_id, 'category' );
		if ( $ancestor instanceof WP_Term ) { array_unshift( $names, $ancestor->name ); }
	}
	return implode( ' › ', $names );
}

/**
 * Pick the durable primary category from the categories actually assigned.
 *
 * Child categories always beat their parent. This is important when an older
 * primary-category meta still points at a root such as Games while the editor
 * has just selected a destination such as Inteligência Artificial or Música.
 */
function go_verge_editorial_pick_primary_category_id( $category_ids, $requested = 0 ) {
	$category_ids = array_values( array_unique( array_filter( array_map( 'absint', (array) $category_ids ) ) ) );
	if ( empty( $category_ids ) ) { return 0; }

	$terms = get_terms( array(
		'taxonomy'   => 'category',
		'hide_empty' => false,
		'include'    => $category_ids,
	) );
	if ( is_wp_error( $terms ) || empty( $terms ) ) { return 0; }

	$by_id     = array();
	$max_depth = -1;
	foreach ( $terms as $term ) {
		if ( ! ( $term instanceof WP_Term ) ) { continue; }
		$depth = count( get_ancestors( $term->term_id, 'category', 'taxonomy' ) );
		$by_id[ (int) $term->term_id ] = array( 'term' => $term, 'depth' => $depth );
		$max_depth = max( $max_depth, $depth );
	}
	if ( empty( $by_id ) ) { return 0; }

	$requested = absint( $requested );
	if ( $requested && isset( $by_id[ $requested ] ) && $by_id[ $requested ]['depth'] === $max_depth ) {
		return $requested;
	}

	/* Keep the submitted category order as the deterministic tie breaker. */
	foreach ( $category_ids as $category_id ) {
		if ( isset( $by_id[ $category_id ] ) && $by_id[ $category_id ]['depth'] === $max_depth ) {
			return (int) $category_id;
		}
	}

	return 0;
}

/**
 * Recover the support line from a known backup/legacy key.
 *
 * No text is generated here. The canonical meta is restored only when an
 * identical value already exists in a trusted historical field.
 */
function go_verge_editorial_recover_support_line( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return '';
	}

	$current = trim(
		(string) get_post_meta(
			$post_id,
			'_go_post_subtitle',
			true
		)
	);

	if ( '' !== $current ) {
		return $current;
	}

	foreach ( array(
		'_go_editorial_backup_post_subtitle',
		'go_post_subtitle',
		'_subtitle',
	) as $source_key ) {
		$candidate = trim(
			(string) get_post_meta(
				$post_id,
				$source_key,
				true
			)
		);

		if ( '' === $candidate ) {
			continue;
		}

		update_post_meta(
			$post_id,
			'_go_post_subtitle',
			$candidate
		);

		return $candidate;
	}

	return '';
}

function go_verge_render_editorial_control_box( $post ) {
	go_verge_editorial_recover_support_line( $post->ID );

	wp_nonce_field( 'go_verge_save_editorial_control', 'go_verge_editorial_control_nonce' );

	$categories = get_categories( array( 'hide_empty' => false, 'orderby' => 'name', 'order' => 'ASC' ) );
	$tree       = go_verge_editorial_category_tree( $categories );
	$selected_categories = array_map( 'absint', wp_get_post_categories( $post->ID ) );
	$native_tags = wp_get_post_tags( $post->ID );
	$native_tags = is_wp_error( $native_tags ) ? array() : (array) $native_tags;

	$current_subject = trim( (string) get_post_meta( $post->ID, 'go_primary_subject_ref', true ) );
	$current_subject = $current_subject ?: 'auto';
	$selected_subject_item = function_exists( 'go_verge_editor_catalog_selected_item' ) ? go_verge_editor_catalog_selected_item( $current_subject ) : null;

	$post_title = get_the_title( $post );
	$support    = go_verge_editorial_recover_support_line( $post->ID );
	$primary_category = absint( get_post_meta( $post->ID, '_go_primary_category_id', true ) );
	/* Never resurrect a stale primary by checking its category again. */
	if ( $primary_category && ! in_array( $primary_category, $selected_categories, true ) ) {
		$primary_category = 0;
	}
	if ( ! $primary_category && ! empty( $selected_categories ) ) {
		$primary_category = go_verge_editorial_pick_primary_category_id( $selected_categories, 0 );
	}
	$primary_term = $primary_category ? get_term( $primary_category, 'category' ) : null;
	$breadcrumb_preview = $primary_term instanceof WP_Term ? go_verge_editorial_category_path( $primary_term ) : __( 'Automático pela categoria principal', 'go-verge' );
	?>
	<div class="go-editorial-control" data-go-editorial-control>
		<div class="go-editorial-control__toolbar">
			<div><strong><?php esc_html_e( 'Publicação completa', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Publicação completa', 'Centraliza os campos editoriais essenciais. Preencher aqui atualiza os metadados do post; os indicadores de audiência/receita ao lado são apenas leitura.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></strong><p><?php esc_html_e( 'Preencha os campos essenciais sem sair deste quadro.', 'go-verge' ); ?></p></div>

		</div>

		<div class="go-editorial-control__media-quick" data-go-smart-crop-panel>
			<div class="go-editorial-control__media-quick-copy">
				<span class="dashicons dashicons-format-image" aria-hidden="true"></span>
				<div><strong><?php esc_html_e( 'Fotos da matéria em 16:9', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Fotos 16:9', 'Smart crop prepara enquadramentos 16:9 consistentes para cards/Discover sem transformar isso em requisito de ranking. Revise rostos, logos e elementos importantes antes de publicar.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></strong><span data-go-smart-crop-status><?php esc_html_e( 'Smart crop automático', 'go-verge' ); ?></span></div>
			</div>
			<button type="button" class="button button-secondary" data-go-smart-crop-all hidden><?php esc_html_e( 'Aplicar 16:9 em todas', 'go-verge' ); ?></button>
		</div>

		<section class="go-editorial-control__section go-editorial-control__section--publication">
			<div class="go-editorial-control__section-head"><h3><?php esc_html_e( 'Texto da publicação', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Texto da publicação', 'Campos que formam a apresentação editorial principal: título e linha de apoio. Devem informar com precisão, sem duplicar a mesma promessa.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></h3><span><?php esc_html_e( 'Título e linha de apoio', 'go-verge' ); ?></span></div>
			<div class="go-editorial-control__publication-grid">
				<label><span><?php esc_html_e( 'Título', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Título', 'Título editorial visível da matéria. Priorize clareza, entidade principal e promessa verdadeira; não precisa ser idêntico ao título SEO.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><input type="text" name="go_editorial_post_title" class="widefat" value="<?php echo esc_attr( $post_title ); ?>" data-go-post-title><small data-go-count="post-title"><?php echo esc_html( mb_strlen( $post_title ) ); ?> caracteres</small></label>
				<label><span><?php esc_html_e( 'Linha de apoio', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Linha de apoio', 'Complementa o título com informação nova e contexto. Evite repetir o título; use para responder rapidamente por que a matéria importa.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><textarea id="go-verge-support-line-field" name="go_verge_support_line" rows="3" class="widefat" maxlength="320" data-go-support-line placeholder="<?php esc_attr_e( 'Informação nova logo abaixo do título', 'go-verge' ); ?>"><?php echo esc_textarea( $support ); ?></textarea><small data-go-count="support-line"><?php echo esc_html( mb_strlen( $support ) ); ?>/320</small></label>
			</div>
		</section>

		<div class="go-editorial-control__grid">
			<section class="go-editorial-control__section">
				<div class="go-editorial-control__section-head"><h3><?php esc_html_e( 'Classificação', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Classificação', 'Organização editorial do post. Categorias definem a hierarquia principal; tags descrevem entidades/recortes específicos e não devem substituir categorias.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></h3><span><?php esc_html_e( 'Categorias e breadcrumb', 'go-verge' ); ?></span></div>
				<input type="search" class="widefat go-editorial-control__search" data-go-filter-list="categories" placeholder="<?php esc_attr_e( 'Pesquisar categorias…', 'go-verge' ); ?>">
				<div class="go-editorial-control__term-list" data-go-term-list="categories">
					<?php foreach ( $tree as $item ) : $category = $item['term']; $depth = min( 4, absint( $item['depth'] ) ); ?>
						<label class="go-editorial-control__term go-editorial-control__term--depth-<?php echo esc_attr( $depth ); ?>" data-go-term-name="<?php echo esc_attr( remove_accents( strtolower( $category->name . ' ' . $category->slug ) ) ); ?>" data-go-category-id="<?php echo esc_attr( $category->term_id ); ?>" data-go-category-label="<?php echo esc_attr( $category->name ); ?>" data-go-category-path="<?php echo esc_attr( go_verge_editorial_category_path( $category ) ); ?>">
							<input type="checkbox" name="go_editorial_categories[]" value="<?php echo esc_attr( $category->term_id ); ?>" <?php checked( in_array( (int) $category->term_id, $selected_categories, true ) ); ?>>
							<span><?php echo esc_html( $category->name ); ?></span>
						</label>
					<?php endforeach; ?>
				</div>
				<label class="go-editorial-control__primary"><span><?php esc_html_e( 'Categoria principal', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Categoria principal', 'Categoria canônica usada para hierarquia editorial e breadcrumb. Escolha a que melhor representa a intenção principal da matéria.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span>
					<select name="go_editorial_primary_category" class="widefat" data-go-primary-category>
						<option value="0"><?php esc_html_e( 'Automática', 'go-verge' ); ?></option>
						<?php foreach ( $categories as $category ) : if ( ! in_array( (int) $category->term_id, $selected_categories, true ) ) { continue; } ?><option value="<?php echo esc_attr( $category->term_id ); ?>" data-path="<?php echo esc_attr( go_verge_editorial_category_path( $category ) ); ?>" <?php selected( $primary_category, $category->term_id ); ?>><?php echo esc_html( $category->name ); ?></option><?php endforeach; ?>
					</select>
				</label>
				<div class="go-editorial-control__breadcrumb"><span><?php esc_html_e( 'Breadcrumb', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Breadcrumb', 'Caminho hierárquico derivado da categoria principal. Ajuda navegação e consistência estrutural; este preview mostra o caminho que será usado.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-breadcrumb-preview><?php echo esc_html( $breadcrumb_preview ); ?></strong><small><?php esc_html_e( 'Gerado pela categoria principal e sua hierarquia.', 'go-verge' ); ?></small></div>
				<div class="go-editorial-control__native-tags" data-go-native-tags-preview>
					<span><?php esc_html_e( 'Tags', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Tags', 'Use poucas tags específicas para entidades e subtemas realmente presentes. Evite criar sinônimos duplicados ou tags genéricas só por SEO.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?> <small data-go-tag-count><?php echo esc_html( count( $native_tags ) ); ?>/3–5</small></span>
					<div class="go-editorial-control__tag-chips" data-go-tag-chips>
						<?php if ( $native_tags ) : foreach ( $native_tags as $tag ) : ?><span><?php echo esc_html( $tag->name ); ?></span><?php endforeach; else : ?><em><?php esc_html_e( 'Nenhuma tag selecionada', 'go-verge' ); ?></em><?php endif; ?>
					</div>
					<small data-go-tag-guidance><?php esc_html_e( 'A seleção continua no painel nativo do WordPress. Recomendação editorial: aceite de 3 a 5 tags específicas sugeridas pelo conteúdo.', 'go-verge' ); ?></small>
				</div>
			</section>

			<section class="go-editorial-control__section">
				<div class="go-editorial-control__section-head"><h3><?php esc_html_e( 'Assunto', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Assunto', 'Entidade central usada para relacionar a matéria ao catálogo editorial e melhorar recirculação/consistência semântica.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></h3><span><?php esc_html_e( 'Entidade principal da matéria', 'go-verge' ); ?></span></div>

				<label><span><?php esc_html_e( 'Assunto principal', 'go-verge' ); ?> <?php echo go_verge_editorial_field_help( 'Assunto principal', 'Selecione a entidade que melhor descreve o foco da matéria. Automático estrito só aceita sinais fortes; escolha manualmente quando houver ambiguidade.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><input type="search" class="widefat" data-go-subject-search data-go-catalog-search data-go-catalog-target="go-editorial-primary-subject-ref" data-go-catalog-types="games,productions,go_entity,post_tag" placeholder="<?php esc_attr_e( 'Digite 2+ letras para buscar…', 'go-verge' ); ?>"></label>
				<select id="go-editorial-primary-subject-ref" name="go_primary_subject_ref" class="widefat go-editorial-control__subject" size="6" data-go-subject-select>
					<option data-go-catalog-static="1" value="auto" <?php selected( $current_subject, 'auto' ); ?>><?php esc_html_e( 'Automático estrito', 'go-verge' ); ?></option>
					<option data-go-catalog-static="1" value="none" <?php selected( $current_subject, 'none' ); ?>><?php esc_html_e( 'Não exibir assunto', 'go-verge' ); ?></option>
					<?php if ( $selected_subject_item ) : ?><option data-go-catalog-pinned="1" value="<?php echo esc_attr( $selected_subject_item['value'] ); ?>" selected><?php echo esc_html( $selected_subject_item['text'] ); ?></option><?php endif; ?>
				</select>
				<p class="description"><?php esc_html_e( 'O automático só aceita sinais fortes do título, linha de apoio ou tags. Página canônica tem prioridade; sem página, abre a tag.', 'go-verge' ); ?></p>
			</section>

		</div>
	</div>
	<style>
		.go-editorial-control{--go-ed:#C6A3FF}.go-editorial-control .go-pi-help-wrap{display:inline-flex!important;vertical-align:middle!important}.go-editorial-control .go-pi-help{margin-left:4px!important}.go-editorial-control .go-pi-tooltip{text-transform:none!important;letter-spacing:0!important}.go-editorial-control__toolbar{display:flex;justify-content:space-between;gap:16px;align-items:center;padding:0 0 14px;border-bottom:1px solid #dcdcde}.go-editorial-control__toolbar p{margin:3px 0 0;color:#646970}.go-editorial-control__move{display:flex;gap:6px;flex-wrap:wrap}.go-editorial-control__grid{display:grid;grid-template-columns:1.08fr 1fr;gap:16px;padding-top:16px}.go-editorial-control__section{border:1px solid #dcdcde;border-radius:9px;padding:14px;background:#fff}.go-editorial-control__section--publication{margin-top:16px}.go-editorial-control__publication-grid{display:grid;grid-template-columns:1.15fr 1fr;gap:14px}.go-editorial-control__section-head{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-bottom:12px}.go-editorial-control__section-head h3{margin:0;font-size:14px}.go-editorial-control__section-head span{font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:#646970}.go-editorial-control label{display:block;margin:0 0 12px}.go-editorial-control label>span,.go-editorial-control__breadcrumb>span,.go-editorial-control__native-tags>span{display:block;font-weight:600;margin-bottom:5px}.go-editorial-control__search{margin:0 0 8px}.go-editorial-control__term-list{display:grid;grid-template-columns:1fr 1fr;gap:2px 8px;max-height:235px;overflow:auto;padding:7px;border:1px solid #dcdcde;border-radius:6px;background:#f8f9fa}.go-editorial-control__term{display:flex!important;align-items:flex-start;gap:6px;margin:0!important;padding:5px 6px!important;border-radius:4px}.go-editorial-control__term:hover{background:#fff}.go-editorial-control__term>span{font-weight:400!important;margin:0!important}.go-editorial-control__term--depth-1{padding-left:18px!important}.go-editorial-control__term--depth-2{padding-left:31px!important}.go-editorial-control__term--depth-3,.go-editorial-control__term--depth-4{padding-left:44px!important}.go-editorial-control__term--depth-1>span:before,.go-editorial-control__term--depth-2>span:before,.go-editorial-control__term--depth-3>span:before,.go-editorial-control__term--depth-4>span:before{content:'↳ ';color:#8c8f94}.go-editorial-control__primary{margin-top:11px!important}.go-editorial-control__breadcrumb,.go-editorial-control__native-tags{margin-top:11px;padding:10px;border:1px solid #e2e4e7;border-radius:6px;background:#f8f9fa}.go-editorial-control__breadcrumb strong{display:block;line-height:1.45}.go-editorial-control__breadcrumb small,.go-editorial-control__native-tags small{display:block;margin-top:4px;color:#646970}.go-editorial-control__native-tags small.is-warning{color:#b32d2e;font-weight:600}.go-editorial-control__tag-chips{display:flex;gap:5px;flex-wrap:wrap}.go-editorial-control__tag-chips span{padding:3px 7px;border-radius:999px;background:#eef0f2;font-size:11px}.go-editorial-control__tag-chips em{color:#646970}.go-editorial-control__subject{margin-top:7px;min-height:205px}.go-editorial-control small[data-go-count]{float:right;color:#646970;margin-top:3px}.go-editorial-control .description{margin-top:-7px;margin-bottom:12px}.go-editorial-control input:focus,.go-editorial-control textarea:focus,.go-editorial-control select:focus{border-color:#769900;box-shadow:0 0 0 1px #769900}.go-editorial-control input[type=checkbox]:checked:before{content:'';background:#769900;clip-path:polygon(14% 44%,0 59%,39% 100%,100% 18%,84% 3%,38% 70%)}#side-sortables .go-editorial-control__grid,#side-sortables .go-editorial-control__publication-grid{grid-template-columns:1fr}#side-sortables .go-editorial-control__toolbar{align-items:flex-start;flex-direction:column}#side-sortables .go-editorial-control__term-list{grid-template-columns:1fr}@media(max-width:1180px){.go-editorial-control__grid{grid-template-columns:1fr 1fr}}@media(max-width:782px){.go-editorial-control__grid,.go-editorial-control__publication-grid{grid-template-columns:1fr}.go-editorial-control__toolbar{align-items:flex-start;flex-direction:column}.go-editorial-control__term-list{grid-template-columns:1fr}}
	</style>
	<style>
		.go-editorial-control__media-quick{display:flex;align-items:center;justify-content:space-between;gap:14px;margin-top:14px;padding:11px 12px;border:1px solid #dcdcde;border-radius:9px;background:linear-gradient(135deg,#f8f9fa 0%,#fff 70%)}
		.go-editorial-control__media-quick-copy{display:flex;align-items:center;gap:10px;min-width:0}.go-editorial-control__media-quick-copy>.dashicons{display:grid;place-items:center;width:34px;height:34px;border-radius:8px;background:#181421;color:#C6A3FF;font-size:18px;line-height:34px}.go-editorial-control__media-quick-copy>div{display:flex;flex-direction:column;gap:2px;min-width:0}.go-editorial-control__media-quick-copy strong{font-size:13px;line-height:1.25}.go-editorial-control__media-quick-copy span[data-go-smart-crop-status]{color:#646970;font-size:11px;line-height:1.3}.go-editorial-control__media-quick [data-go-smart-crop-all]{flex:0 0 auto;border-color:#7900FF;color:#7900FF;font-weight:600}.go-editorial-control__media-quick [data-go-smart-crop-all]:hover,.go-editorial-control__media-quick [data-go-smart-crop-all]:focus{border-color:#6200CE;color:#6200CE}.go-editorial-control__media-quick.is-running{border-color:#C6A3FF}.go-editorial-control__media-quick.is-success{border-color:#769900;background:#fbfff0}.go-editorial-control__media-quick.is-error{border-color:#d63638;background:#fff7f7}#side-sortables .go-editorial-control__media-quick{align-items:flex-start;flex-direction:column}#side-sortables .go-editorial-control__media-quick [data-go-smart-crop-all]{width:100%}@media(max-width:782px){.go-editorial-control__media-quick{align-items:flex-start;flex-direction:column}.go-editorial-control__media-quick [data-go-smart-crop-all]{width:100%}}
	</style>
	<script>
	(function(){
		var root=document.querySelector('[data-go-editorial-control]');if(!root||root.dataset.bound)return;root.dataset.bound='1';
		function norm(v){return (v||'').toLocaleLowerCase('pt-BR').normalize('NFD').replace(/[\u0300-\u036f]/g,'');}
		function markDirty(key){
			key=String(key||'');if(!key)return;
			var selector='input[type="hidden"][data-go-editorial-dirty="'+key.replace(/"/g,'')+'"]';
			if(root.querySelector(selector))return;
			var input=document.createElement('input');
			input.type='hidden';
			input.name='go_editorial_dirty['+key+']';
			input.value='1';
			input.setAttribute('data-go-editorial-dirty',key);
			root.appendChild(input);
		}
		var title=root.querySelector('[data-go-post-title]'),support=root.querySelector('[data-go-support-line]');
		var syncingTitle=false,syncingSupport=false;
		function count(field,key,max){var out=root.querySelector('[data-go-count="'+key+'"]');if(out)out.textContent=field.value.length+(max?'/'+max:' caracteres');}
		function setTitleEverywhere(value,source){
			value=String(value||'');if(syncingTitle)return;syncingTitle=true;
			if(title&&title!==source&&title.value!==value){title.value=value;count(title,'post-title');}
			try{if(window.wp&&wp.data&&wp.data.dispatch){var d=wp.data.dispatch('core/editor');if(d&&d.editPost)d.editPost({title:value});}}catch(e){}
			var classic=document.getElementById('title');if(classic&&classic!==source&&classic.value!==value){classic.value=value;classic.dispatchEvent(new Event('input',{bubbles:true}));classic.dispatchEvent(new Event('change',{bubbles:true}));}
			document.dispatchEvent(new CustomEvent('go:editorial-title-sync',{detail:{value:value}}));
			syncingTitle=false;
		}
		function setSupportEverywhere(value,source){
			value=String(value||'');if(syncingSupport)return;syncingSupport=true;
			if(support&&support!==source&&support.value!==value){support.value=value;count(support,'support-line',320);}
			try{if(window.wp&&wp.data&&wp.data.dispatch&&wp.data.select){var d=wp.data.dispatch('core/editor'),sel=wp.data.select('core/editor');if(d&&d.editPost&&sel){var meta=Object.assign({},sel.getEditedPostAttribute('meta')||{});meta._go_post_subtitle=value;d.editPost({meta:meta});}}}catch(e){}
			document.querySelectorAll('[data-go-subtitle-input]').forEach(function(input){if(input!==source&&input.value!==value){input.value=value;}});
			document.dispatchEvent(new CustomEvent('go:editorial-support-sync',{detail:{value:value}}));
			syncingSupport=false;
		}
		if(title){title.addEventListener('input',function(){count(title,'post-title');setTitleEverywhere(title.value,title);});}
		if(support){support.addEventListener('input',function(){markDirty('support');count(support,'support-line',320);setSupportEverywhere(support.value,support);});}
		var eyebrowField=root.querySelector('[name="go_article_eyebrow"]');if(eyebrowField){eyebrowField.addEventListener('input',function(){markDirty('eyebrow');});}
		var subjectField=root.querySelector('[name="go_primary_subject_ref"]');if(subjectField){subjectField.addEventListener('change',function(){markDirty('subject');});}
		var classicTitle=document.getElementById('title');if(classicTitle){classicTitle.addEventListener('input',function(){setTitleEverywhere(classicTitle.value,classicTitle);});}
		document.addEventListener('go:editorial-title-sync',function(event){var value=event&&event.detail?event.detail.value:'';if(title&&document.activeElement!==title&&title.value!==value){title.value=value;count(title,'post-title');}});
		document.addEventListener('go:editorial-support-sync',function(event){var value=event&&event.detail?event.detail.value:'';if(support&&document.activeElement!==support&&support.value!==value){support.value=value;count(support,'support-line',320);}});
		root.querySelectorAll('[data-go-filter-list]').forEach(function(input){input.addEventListener('input',function(){var term=norm(input.value),name=input.getAttribute('data-go-filter-list');root.querySelectorAll('[data-go-term-list="'+name+'"] [data-go-term-name]').forEach(function(row){row.hidden=!!(term&&norm(row.getAttribute('data-go-term-name')).indexOf(term)===-1);});});});
		var primary=root.querySelector('[data-go-primary-category]'),crumb=root.querySelector('[data-go-breadcrumb-preview]');
		function checkedCategoryRows(){return Array.prototype.slice.call(root.querySelectorAll('input[name="go_editorial_categories[]"]:checked')).map(function(input){return input.closest('[data-go-category-id]');}).filter(Boolean);}
		function rebuildPrimary(){if(!primary)return;var current=primary.value,rows=checkedCategoryRows();primary.innerHTML='';var auto=document.createElement('option');auto.value='0';auto.textContent='<?php echo esc_js( __( 'Automática', 'go-verge' ) ); ?>';primary.appendChild(auto);rows.forEach(function(row){var option=document.createElement('option');option.value=row.getAttribute('data-go-category-id');option.textContent=row.getAttribute('data-go-category-label');option.dataset.path=row.getAttribute('data-go-category-path');primary.appendChild(option);});if(Array.prototype.some.call(primary.options,function(o){return o.value===current;}))primary.value=current;else primary.value='0';updateBreadcrumb();}
		function updateBreadcrumb(){if(!primary||!crumb)return;var option=primary.options[primary.selectedIndex];crumb.textContent=option&&option.value!=='0'?(option.dataset.path||option.textContent):'<?php echo esc_js( __( 'Automático pela categoria principal', 'go-verge' ) ); ?>';}
		function categoryIds(){return checkedCategoryRows().map(function(row){return Number(row.getAttribute('data-go-category-id'));}).filter(Boolean);}
		function syncCategoriesToEditor(){
			var ids=categoryIds();rebuildPrimary();var primaryId=primary?Number(primary.value||0):0;
			if(ids.length===1&&primaryId!==ids[0]){primaryId=ids[0];if(primary){primary.value=String(primaryId);updateBreadcrumb();}markDirty('primary_category');}
			else if(primaryId&&ids.indexOf(primaryId)===-1){primaryId=0;if(primary){primary.value='0';updateBreadcrumb();}markDirty('primary_category');}
			try{if(window.wp&&wp.data&&wp.data.dispatch){var d=wp.data.dispatch('core/editor'),e=wp.data.select&&wp.data.select('core/editor');if(d&&d.editPost){var attrs={categories:ids};if(e&&e.getEditedPostAttribute){attrs.meta=Object.assign({},e.getEditedPostAttribute('meta')||{},{_go_primary_category_id:primaryId});}d.editPost(attrs);}}}catch(e){}
			document.querySelectorAll('input[name="post_category[]"]').forEach(function(i){i.checked=ids.indexOf(Number(i.value))>-1;});
		}
		root.querySelectorAll('input[name="go_editorial_categories[]"]').forEach(function(i){i.addEventListener('change',function(){markDirty('categories');syncCategoriesToEditor();});});
		if(primary)primary.addEventListener('change',function(){markDirty('primary_category');updateBreadcrumb();});
		var lastCats='',lastEditorTitle='',lastEditorSupport=null,lastTagSig=null;
		function renderNativeTagPreview(tagIds){
			var chips=root.querySelector('[data-go-tag-chips]'),counter=root.querySelector('[data-go-tag-count]'),guide=root.querySelector('[data-go-tag-guidance]');
			if(counter)counter.textContent=tagIds.length+'/3–5';
			if(guide){guide.classList.toggle('is-warning',tagIds.length>0&&(tagIds.length<3||tagIds.length>5));guide.textContent=tagIds.length<3?'Adicione de 3 a 5 tags específicas do conteúdo.':(tagIds.length>5?'Reduza para no máximo 5 tags relevantes.':'Quantidade ideal de tags.');}
			if(!chips)return;
			if(!tagIds.length){chips.innerHTML='';var empty=document.createElement('em');empty.textContent='Nenhuma tag selecionada';chips.appendChild(empty);return;}
			if(!(window.wp&&wp.data&&wp.data.select))return;
			var core=wp.data.select('core');if(!core||!core.getEntityRecords)return;
			var terms=core.getEntityRecords('taxonomy','post_tag',{include:tagIds,per_page:Math.max(1,tagIds.length),orderby:'include'});
			if(!Array.isArray(terms))return;
			chips.innerHTML='';terms.slice(0,5).forEach(function(term){var span=document.createElement('span');span.textContent=term.name;chips.appendChild(span);});
			if(!terms.length){var em=document.createElement('em');em.textContent='Nenhuma tag selecionada';chips.appendChild(em);}
		}
		try{if(window.wp&&wp.data&&wp.data.subscribe){
			var goEditorialStateTimer=0;
			wp.data.subscribe(function(){
				window.clearTimeout(goEditorialStateTimer);
				goEditorialStateTimer=window.setTimeout(function(){

			var e=wp.data.select('core/editor');if(!e||!e.getEditedPostAttribute)return;
			var ids=(e.getEditedPostAttribute('categories')||[]).map(Number).sort(function(a,b){return a-b;});var sig=ids.join(',');if(sig!==lastCats){lastCats=sig;root.querySelectorAll('input[name="go_editorial_categories[]"]').forEach(function(i){i.checked=ids.indexOf(Number(i.value))>-1;});rebuildPrimary();}
			var editorTitle=String(e.getEditedPostAttribute('title')||'');if(editorTitle!==lastEditorTitle){lastEditorTitle=editorTitle;if(title&&document.activeElement!==title&&title.value!==editorTitle){title.value=editorTitle;count(title,'post-title');}}
			var meta=e.getEditedPostAttribute('meta')||{},editorSupport=String(meta._go_post_subtitle||'');
			if(lastEditorSupport===null){
				lastEditorSupport=editorSupport;
				if(!editorSupport&&support&&support.value){
					lastEditorSupport=String(support.value||'');
					setSupportEverywhere(lastEditorSupport,support);
				}else if(editorSupport&&support&&document.activeElement!==support&&support.value!==editorSupport){
					support.value=editorSupport;count(support,'support-line',320);
				}
			}else if(editorSupport!==lastEditorSupport){
				lastEditorSupport=editorSupport;
				if(support&&document.activeElement!==support){
					/*
					 * Gutenberg may briefly expose an empty meta object while it
					 * hydrates. Never let that transient state erase a saved field.
					 */
					if(editorSupport||!support.value){
						support.value=editorSupport;count(support,'support-line',320);
					}else{
						setSupportEverywhere(support.value,support);
						lastEditorSupport=String(support.value||'');
					}
				}
				document.querySelectorAll('[data-go-subtitle-input]').forEach(function(input){
					if(document.activeElement!==input&&input.value!==lastEditorSupport)input.value=lastEditorSupport;
				});
			}
			var tagIds=(e.getEditedPostAttribute('tags')||[]).map(Number).filter(Boolean),tagSig=tagIds.join(',');
			if(lastTagSig===null){lastTagSig=tagSig;renderNativeTagPreview(tagIds);}
			else if(tagSig!==lastTagSig){lastTagSig=tagSig;markDirty('tags');renderNativeTagPreview(tagIds);}

				},180);
			});
		}}catch(e){}
		document.addEventListener('input',function(event){var target=event.target;if(target&&target.closest&&target.closest('#tagsdiv-post_tag'))markDirty('tags');},true);
		document.addEventListener('change',function(event){var target=event.target;if(target&&target.closest&&target.closest('#tagsdiv-post_tag'))markDirty('tags');},true);
		/* Subject catalog search is handled by the shared AJAX search runtime. */

		/* Category is replaced by this panel. Tags deliberately remain native. */
		try{if(window.wp&&wp.data&&wp.data.dispatch){var d=wp.data.dispatch('core/edit-post');if(d&&d.removeEditorPanel)d.removeEditorPanel('taxonomy-panel-category');}}catch(e){}
	})();
	</script>
	<?php
}

/** Use the panel title as the real WordPress title before the post is saved. */
function go_verge_editorial_control_post_data( $data, $postarr ) {
	if ( 'post' !== ( $data['post_type'] ?? '' ) || ! isset( $_POST['go_verge_editorial_control_nonce'], $_POST['go_editorial_post_title'] ) ) { return $data; }
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_editorial_control_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_save_editorial_control' ) ) { return $data; }
	$data['post_title'] = sanitize_text_field( wp_unslash( $_POST['go_editorial_post_title'] ) );
	return $data;
}
add_filter( 'wp_insert_post_data', 'go_verge_editorial_control_post_data', 120, 2 );


/**
 * A brand-new newsroom story belongs to the editor who is actually creating it.
 *
 * WordPress normally does this itself, but author-capable editorial layers can
 * carry a stale author into the auto-draft created by post-new.php. Correct the
 * initial record once, before Gutenberg hydrates it. Existing posts are never
 * touched, and editors can still deliberately change the author afterwards when
 * they have edit_others_posts.
 *
 * @param array $data    Sanitized post data.
 * @param array $postarr Raw post data.
 * @return array
 */
function go_verge_new_story_uses_current_editor( $data, $postarr ) {
	if ( 'post' !== ( $data['post_type'] ?? '' ) || ! empty( $postarr['ID'] ) ) {
		return $data;
	}

	$user_id = get_current_user_id();
	if ( ! $user_id || ! current_user_can( 'edit_posts' ) ) {
		return $data;
	}

	$status = sanitize_key( (string) ( $data['post_status'] ?? '' ) );
	if ( ! in_array( $status, array( 'auto-draft', 'draft', 'pending' ), true ) ) {
		return $data;
	}

	/* Scope the override to an authenticated editorial request. This keeps CLI,
	 * imports and background integrations free to supply their own author. */
	$is_editor_request = is_admin() || ( defined( 'REST_REQUEST' ) && REST_REQUEST );
	if ( ! $is_editor_request ) {
		return $data;
	}

	$data['post_author'] = $user_id;
	return $data;
}
add_filter( 'wp_insert_post_data', 'go_verge_new_story_uses_current_editor', 5, 2 );

/**
 * Whether one field was explicitly changed inside Go Editorial.
 *
 * Missing fields must never be interpreted as empty. Gutenberg and the legacy
 * metabox transport do not always submit the same collection of controls.
 */
function go_verge_editorial_request_field_is_dirty( $key ) {
	if ( empty( $_POST['go_editorial_dirty'] ) || ! is_array( $_POST['go_editorial_dirty'] ) ) {
		return false;
	}

	$dirty = wp_unslash( $_POST['go_editorial_dirty'] );
	return ! empty( $dirty[ $key ] );
}

/** Verify that the current request genuinely belongs to Go Editorial. */
function go_verge_editorial_request_is_valid() {
	if ( empty( $_POST['go_verge_editorial_control_nonce'] ) ) {
		return false;
	}

	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_editorial_control_nonce'] ) );
	return wp_verify_nonce( $nonce, 'go_verge_save_editorial_control' );
}

/** Persistent backups used only to restore values that disappear unexpectedly. */
function go_verge_editorial_refresh_integrity_backups( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return;
	}

	$meta_map = array(
		'_go_post_subtitle'       => '_go_editorial_backup_post_subtitle',
		'_go_article_eyebrow'     => '_go_editorial_backup_article_eyebrow',
		'go_primary_subject_ref'  => '_go_editorial_backup_primary_subject_ref',
	);

	foreach ( $meta_map as $source => $backup ) {
		$value = get_post_meta( $post_id, $source, true );
		if ( is_string( $value ) && '' !== trim( $value ) && $value !== get_post_meta( $post_id, $backup, true ) ) {
			update_post_meta( $post_id, $backup, $value );
		}
	}

	$tag_ids = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) );
	if ( ! is_wp_error( $tag_ids ) && ! empty( $tag_ids ) ) {
		$tag_ids = array_values( array_map( 'absint', $tag_ids ) );
		if ( $tag_ids !== (array) get_post_meta( $post_id, '_go_editorial_backup_tag_ids', true ) ) {
			update_post_meta( $post_id, '_go_editorial_backup_tag_ids', $tag_ids );
		}
	}

	$category_ids = wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) );
	if ( ! empty( $category_ids ) ) {
		$category_ids = array_values( array_map( 'absint', $category_ids ) );
		if ( $category_ids !== (array) get_post_meta( $post_id, '_go_editorial_backup_category_ids', true ) ) {
			update_post_meta( $post_id, '_go_editorial_backup_category_ids', $category_ids );
		}
	}
}

/** Snapshot values before WordPress or another plugin changes the post. */
function go_verge_editorial_snapshot_before_update( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return;
	}

	$GLOBALS['go_verge_editorial_pre_save_snapshot'][ $post_id ] = array(
		'meta'       => array(
			'_go_post_subtitle'       => get_post_meta( $post_id, '_go_post_subtitle', true ),
			'_go_article_eyebrow'     => get_post_meta( $post_id, '_go_article_eyebrow', true ),
			'go_primary_subject_ref'  => get_post_meta( $post_id, 'go_primary_subject_ref', true ),
		),
		'tags'       => wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) ),
		'categories' => wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) ),
	);
}
add_action( 'pre_post_update', 'go_verge_editorial_snapshot_before_update', 5 );


/** Save the panel without treating omitted controls as empty values. */
function go_verge_save_editorial_control_box( $post_id ) {
	if ( ! go_verge_editorial_request_is_valid() ) {
		return;
	}

	if (
		( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE )
		|| wp_is_post_revision( $post_id )
		|| wp_is_post_autosave( $post_id )
		|| ! current_user_can( 'edit_post', $post_id )
	) {
		return;
	}

	/*
	 * Categories are saved only when the editor actually changed them. A
	 * missing checkbox collection is not permission to erase relationships,
	 * unless the panel explicitly marked the category field as dirty.
	 */
	$categories_were_submitted = isset( $_POST['go_editorial_categories'] ) || go_verge_editorial_request_field_is_dirty( 'categories' );
	if ( $categories_were_submitted ) {
		$raw_categories = isset( $_POST['go_editorial_categories'] )
			? (array) wp_unslash( $_POST['go_editorial_categories'] )
			: array();
		$category_ids = array_values(
			array_unique(
				array_filter(
					array_map( 'absint', $raw_categories )
				)
			)
		);
		wp_set_post_categories( $post_id, $category_ids, false );
		/* Re-read because WordPress may apply the site's default category. */
		$category_ids = wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) );
	} else {
		$category_ids = wp_get_post_categories( $post_id, array( 'fields' => 'ids' ) );
	}

	/* Tags remain owned by the native WordPress selector. */

	if ( isset( $_POST['go_verge_support_line'] ) ) {
		$support = mb_substr(
			sanitize_textarea_field(
				wp_unslash( $_POST['go_verge_support_line'] )
			),
			0,
			320
		);

		if ( '' !== $support ) {
			update_post_meta( $post_id, '_go_post_subtitle', $support );
			update_post_meta( $post_id, '_go_editorial_backup_post_subtitle', $support );
		} elseif ( go_verge_editorial_request_field_is_dirty( 'support' ) ) {
			delete_post_meta( $post_id, '_go_post_subtitle' );
			delete_post_meta( $post_id, '_go_editorial_backup_post_subtitle' );
		}
	}

	if ( isset( $_POST['go_article_eyebrow'] ) ) {
		$eyebrow = mb_substr(
			sanitize_text_field(
				wp_unslash( $_POST['go_article_eyebrow'] )
			),
			0,
			90
		);

		if ( '' !== $eyebrow ) {
			update_post_meta( $post_id, '_go_article_eyebrow', $eyebrow );
		} elseif ( go_verge_editorial_request_field_is_dirty( 'eyebrow' ) ) {
			delete_post_meta( $post_id, '_go_article_eyebrow' );
		}
	}

	if ( isset( $_POST['go_primary_subject_ref'] ) ) {
		$subject       = sanitize_text_field( wp_unslash( $_POST['go_primary_subject_ref'] ) );
		$valid_subject = in_array( $subject, array( 'auto', 'none' ), true );

		if (
			! $valid_subject
			&& preg_match( '/^(games|productions|go_entity|post_tag):(\d+)$/', $subject, $match )
		) {
			$id = absint( $match[2] );

			if ( 'post_tag' === $match[1] ) {
				$valid_subject = get_term( $id, 'post_tag' ) instanceof WP_Term;
			} else {
				$valid_subject = $id
					&& $match[1] === get_post_type( $id )
					&& 'publish' === get_post_status( $id );
			}
		}

		if ( $valid_subject ) {
			update_post_meta( $post_id, 'go_primary_subject_ref', $subject );
		}
	}


	/*
	 * Primary category must always be derived from the relationships that were
	 * actually saved. This prevents a historical Games primary meta from
	 * overriding a newly selected Música/IA category on the next save.
	 */
	$primary_was_submitted = isset( $_POST['go_editorial_primary_category'] );
	if ( $categories_were_submitted || $primary_was_submitted || go_verge_editorial_request_field_is_dirty( 'primary_category' ) ) {
		$requested_primary = $primary_was_submitted
			? absint( wp_unslash( $_POST['go_editorial_primary_category'] ) )
			: 0;
		$next_primary = go_verge_editorial_pick_primary_category_id( $category_ids, $requested_primary );

		if ( $next_primary ) {
			update_post_meta( $post_id, '_go_primary_category_id', $next_primary );
		} else {
			delete_post_meta( $post_id, '_go_primary_category_id' );
		}

		/* Mirror the corrected choice to Rank Math/Yoast after relationships exist. */
		if ( function_exists( 'go_verge_sync_primary_category' ) ) {
			go_verge_sync_primary_category( $post_id );
		}
	}

	go_verge_editorial_refresh_integrity_backups( $post_id );
}
add_action( 'save_post_post', 'go_verge_save_editorial_control_box', 130 );

/**
 * Last-line protection against another save handler clearing untouched values.
 */
function go_verge_editorial_restore_unintended_empty_fields( $post_id ) {
	if ( ! go_verge_editorial_request_is_valid() ) {
		return;
	}

	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) {
		return;
	}

	$snapshot = $GLOBALS['go_verge_editorial_pre_save_snapshot'][ $post_id ] ?? array();
	$meta     = isset( $snapshot['meta'] ) && is_array( $snapshot['meta'] )
		? $snapshot['meta']
		: array();

	$meta_rules = array(
		'_go_post_subtitle'       => 'support',
		'_go_article_eyebrow'     => 'eyebrow',
		'go_primary_subject_ref'  => 'subject',
	);

	foreach ( $meta_rules as $meta_key => $dirty_key ) {
		if ( go_verge_editorial_request_field_is_dirty( $dirty_key ) ) {
			continue;
		}

		$current = get_post_meta( $post_id, $meta_key, true );
		if ( is_string( $current ) && '' !== trim( $current ) ) {
			continue;
		}

		$candidate = isset( $meta[ $meta_key ] )
			? $meta[ $meta_key ]
			: '';

		if ( ! is_string( $candidate ) || '' === trim( $candidate ) ) {
			$backup_key = '_go_editorial_backup_' . ltrim( $meta_key, '_' );
			$candidate  = get_post_meta( $post_id, $backup_key, true );
		}

		if ( is_string( $candidate ) && '' !== trim( $candidate ) ) {
			update_post_meta( $post_id, $meta_key, $candidate );
		}
	}

	if ( ! go_verge_editorial_request_field_is_dirty( 'tags' ) ) {
		$current_tags = wp_get_post_terms( $post_id, 'post_tag', array( 'fields' => 'ids' ) );

		if ( ! is_wp_error( $current_tags ) && empty( $current_tags ) ) {
			$previous_tags = $snapshot['tags'] ?? get_post_meta(
				$post_id,
				'_go_editorial_backup_tag_ids',
				true
			);

			$previous_tags = array_values(
				array_filter(
					array_map(
						'absint',
						(array) $previous_tags
					)
				)
			);

			if ( ! empty( $previous_tags ) ) {
				wp_set_post_terms( $post_id, $previous_tags, 'post_tag', false );
			}
		}
	}

	if ( ! go_verge_editorial_request_field_is_dirty( 'categories' ) ) {
		$current_categories = wp_get_post_categories(
			$post_id,
			array( 'fields' => 'ids' )
		);

		if ( empty( $current_categories ) ) {
			$previous_categories = $snapshot['categories'] ?? get_post_meta(
				$post_id,
				'_go_editorial_backup_category_ids',
				true
			);

			$previous_categories = array_values(
				array_filter(
					array_map(
						'absint',
						(array) $previous_categories
					)
				)
			);

			if ( ! empty( $previous_categories ) ) {
				wp_set_post_categories(
					$post_id,
					$previous_categories,
					false
				);
			}
		}
	}

	go_verge_editorial_recover_support_line( $post_id );
	go_verge_editorial_refresh_integrity_backups( $post_id );
}
add_action( 'save_post_post', 'go_verge_editorial_restore_unintended_empty_fields', 999 );
