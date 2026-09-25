<?php
/** Editorial subjects, formats and distribution contexts are separate axes. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Subject destinations only. Existing format archives remain untouched. */
function go_verge_editorial_subdesk_blueprint() {
	return array(
		'games' => array( 'lancamentos' => 'Lançamentos', 'industria-games' => 'Indústria dos games', 'esports' => 'eSports', 'jogos-mobile' => 'Jogos mobile' ),
		'entretenimento' => array( 'filmes' => 'Filmes', 'series' => 'Séries', 'anime-e-manga' => 'Anime e Mangá', 'doramas' => 'Doramas', 'producoes-turcas' => 'Novelas e séries turcas', 'musica' => 'Música', 'streaming' => 'Streaming' ),
		'tecnologia' => array( 'celulares' => 'Celulares', 'mobilidade' => 'Auto e Mobilidade', 'internet' => 'Internet', 'hardware' => 'Hardware', 'notebooks' => 'Notebooks', 'tvs-e-monitores' => 'TVs e Monitores', 'eletrodomesticos' => 'Eletrodomésticos', 'casa-inteligente' => 'Casa Inteligente', 'wearables' => 'Wearables', 'apps-software' => 'Apps e Software', 'ia' => 'Inteligência Artificial', 'ciencia' => 'Ciência e Mundo', 'servico' => 'Serviço' ),
		'ofertas' => array( 'ofertas-games' => 'Jogos e consoles', 'jogos-gratis' => 'Jogos grátis', 'ofertas-hardware' => 'Hardware e acessórios', 'ofertas-celulares' => 'Celulares', 'ofertas-servicos' => 'Serviços e assinaturas' ),
	);
}

function go_verge_editorial_category_blueprint() {
	$out = array();
	foreach ( go_verge_editorial_pillars() as $slug => $pillar ) {
		$out[ $slug ] = array( 'name' => $pillar['label'], 'children' => go_verge_editorial_subdesk_blueprint()[ $slug ] );
	}
	return $out;
}

/** Return the stored hierarchy; do not infer parentage from a title or rename it. */
function go_verge_editorial_category_structure( $term ) {
	if ( ! $term instanceof WP_Term ) { $term = get_term( absint( $term ), 'category' ); }
	if ( ! $term instanceof WP_Term || 'category' !== $term->taxonomy ) { return array( 'desk' => '', 'role' => 'unknown', 'path' => '' ); }
	$chain = array(); $seen = array(); $cursor = $term; $valid = true;
	while ( $cursor instanceof WP_Term ) {
		if ( isset( $seen[ $cursor->term_id ] ) ) { $valid = false; break; }
		$seen[ $cursor->term_id ] = true;
		array_unshift( $chain, $cursor );
		if ( ! $cursor->parent ) { break; }
		$cursor = get_term( $cursor->parent, 'category' );
		if ( ! $cursor instanceof WP_Term ) { $valid = false; break; }
	}
	$roots = go_verge_editorial_pillars();
	$root = reset( $chain );
	$desk = $valid && $root && isset( $roots[ $root->slug ] ) && ! $root->parent ? $root->slug : '';
	$role = $desk ? ( $term->term_id === $root->term_id ? 'desk' : 'subject' ) : 'legacy';
	$legacy = array();
	foreach ( go_verge_editorial_legacy_type_categories() as $slugs ) { $legacy = array_merge( $legacy, $slugs ); }
	$maps = go_verge_v7_legacy_maps();
	$contexts = array_merge( array_keys( $maps['platform'] ?? array() ), array_keys( $maps['service'] ?? array() ) );
	foreach ( $chain as $node ) {
		if ( $node === $root ) { continue; }
		// Jogos grátis is a subject collection, even though its old articles infer Oferta.
		if ( 'jogos-gratis' !== $node->slug && in_array( $node->slug, $legacy, true ) ) { $role = 'legacy-format'; }
		if ( in_array( $node->slug, $contexts, true ) ) { $role = 'legacy-context'; }
	}
	return array( 'desk' => $desk, 'role' => $role, 'path' => implode( ' › ', wp_list_pluck( $chain, 'name' ) ) );
}

/** Fresh on editor load; the plugin's old vocabulary cache cannot hide new desks. */
function go_verge_editorial_structure_payload() {
	$terms = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => false, 'update_term_meta_cache' => false ) );
	$rows = array(); $desks = array();
	foreach ( go_verge_editorial_pillars() as $slug => $pillar ) { $desks[ $slug ] = array( 'slug' => $slug, 'name' => $pillar['label'], 'id' => 0 ); }
	foreach ( is_wp_error( $terms ) ? array() : $terms as $term ) {
		$info = go_verge_editorial_category_structure( $term );
		$rows[] = array_merge( array( 'id' => (int) $term->term_id, 'slug' => $term->slug, 'name' => $term->name, 'parent' => (int) $term->parent ), $info );
		if ( 'desk' === $info['role'] ) { $desks[ $info['desk'] ]['id'] = (int) $term->term_id; }
	}
	return array( 'version' => 1, 'automaticFormatRoutes' => false, 'desks' => array_values( $desks ), 'categories' => $rows );
}

/** Validate only a new explicit primary selection; legacy saves remain possible. */
function go_verge_editorial_validate_primary_request( $prepared, $request ) {
	$meta = $request->get_param( 'meta' );
	if ( ! is_array( $meta ) || ! isset( $meta['_go_primary_category_id'] ) ) { return $prepared; }
	$id = absint( $request->get_param( 'id' ) );
	$primary = absint( $meta['_go_primary_category_id'] );
	if ( ! $primary || $primary === absint( get_post_meta( $id, '_go_primary_category_id', true ) ) ) { return $prepared; }
	$categories = $request->get_param( 'categories' );
	if ( null === $categories ) { $categories = $id ? wp_get_post_categories( $id ) : array(); }
	$info = go_verge_editorial_category_structure( $primary );
	if ( ! in_array( $primary, array_map( 'absint', (array) $categories ), true ) || ! in_array( $info['role'], array( 'desk', 'subject' ), true ) ) {
		return new WP_Error( 'go_editorial_invalid_primary', 'Escolha uma editoria ou subeditoria vinculada à matéria. Categorias antigas continuam preservadas nos vínculos adicionais.', array( 'status' => 400 ) );
	}
	return $prepared;
}
add_filter( 'rest_pre_insert_post', 'go_verge_editorial_validate_primary_request', 99, 2 );

/** The current frontend queries formats independently; no category routing needed. */
add_filter( 'ged_automatic_format_routes', '__return_false' );

/** Classic editor uses the same contract and appends only an explicit selection. */
function go_verge_editorial_classic_box( $post ) {
	if ( function_exists( 'use_block_editor_for_post' ) && use_block_editor_for_post( $post ) ) { return; }
	$payload = go_verge_editorial_structure_payload();
	$primary = absint( get_post_meta( $post->ID, '_go_primary_category_id', true ) );
	$current = go_verge_editorial_category_structure( $primary );
	wp_nonce_field( 'go_editorial_structure', 'go_editorial_structure_nonce' );
	echo '<input type="hidden" name="go_editorial_structure_dirty" id="go-editorial-structure-dirty" value="0">';
	wp_enqueue_script( 'go-editorial-structure-classic', GO_VERGE_URI . '/assets/js/editorial-structure-classic.js', array(), go_verge_asset_version( '/assets/js/editorial-structure-classic.js' ), true );
	echo '<p><label for="go-editorial-desk">1. Editoria</label><br><select id="go-editorial-desk" name="go_editorial_desk" class="widefat"><option value="">Manter classificação atual</option>';
	foreach ( $payload['desks'] as $desk ) { echo '<option value="' . esc_attr( $desk['slug'] ) . '"' . selected( $current['desk'], $desk['slug'], false ) . ( $desk['id'] ? '' : ' disabled' ) . '>' . esc_html( $desk['name'] ) . '</option>'; }
	echo '</select></p><p><label for="go-editorial-primary">2. Subeditoria</label><br><select id="go-editorial-primary" name="go_editorial_primary" class="widefat"><option value="0">Geral da editoria</option>';
	foreach ( $payload['categories'] as $row ) {
		if ( 'subject' !== $row['role'] ) { continue; }
		echo '<option data-desk="' . esc_attr( $row['desk'] ) . '" value="' . (int) $row['id'] . '"' . selected( $primary, $row['id'], false ) . '>' . esc_html( $row['path'] ) . '</option>';
	}
	echo '</select></p><p><label for="go-editorial-type">3. Tipo de matéria</label><br><select id="go-editorial-type" name="go_editorial_type" class="widefat"><option value="">Manter tipo atual</option>';
	foreach ( go_verge_v7_vocabularies()['go_content_type']['terms'] as $slug => $label ) { echo '<option value="' . esc_attr( $slug ) . '">' . esc_html( $label ) . '</option>'; }
	echo '</select></p><p>Plataformas e serviços têm campos próprios. Categorias vinculadas (preservadas ao trocar a principal):</p><ul>';
	foreach ( (array) get_the_category( $post->ID ) as $term ) { echo '<li>' . esc_html( go_verge_editorial_category_structure( $term )['path'] ) . ( $primary === (int) $term->term_id ? ' · principal' : '' ) . '</li>'; }
	echo '</ul>';
	$types = get_the_terms( $post->ID, 'go_content_type' );
	if ( $types && ! is_wp_error( $types ) ) { echo '<p>Tipo atual: ' . esc_html( implode( ', ', wp_list_pluck( $types, 'name' ) ) ) . '</p>'; }
}

function go_verge_editorial_register_classic_box( $post ) {
	if ( function_exists( 'use_block_editor_for_post' ) && use_block_editor_for_post( $post ) ) { return; }
	add_meta_box( 'go-editorial-structure', 'Organização editorial', 'go_verge_editorial_classic_box', 'post', 'side', 'high' );
}
add_action( 'add_meta_boxes_post', 'go_verge_editorial_register_classic_box' );
function go_verge_editorial_classic_save( $id ) {
	if ( ! isset( $_POST['go_editorial_structure_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['go_editorial_structure_nonce'] ) ), 'go_editorial_structure' ) || ! current_user_can( 'edit_post', $id ) || wp_is_post_revision( $id ) || wp_is_post_autosave( $id ) ) { return; }
	$desk = sanitize_key( wp_unslash( $_POST['go_editorial_desk'] ?? '' ) );
	$primary = absint( $_POST['go_editorial_primary'] ?? 0 );
	if ( ! $primary && isset( go_verge_editorial_pillars()[ $desk ] ) ) {
		$root = get_term_by( 'slug', $desk, 'category' );
		$primary = $root instanceof WP_Term ? (int) $root->term_id : 0;
	}
	$info = go_verge_editorial_category_structure( $primary );
	if ( '1' === ( $_POST['go_editorial_structure_dirty'] ?? '' ) && $desk === $info['desk'] && in_array( $info['role'], array( 'desk', 'subject' ), true ) ) {
		wp_set_post_categories( $id, array( $primary ), true );
		foreach ( array( '_go_primary_category_id', 'rank_math_primary_category', '_yoast_wpseo_primary_category' ) as $key ) { update_post_meta( $id, $key, $primary ); }
	}
	$type = sanitize_key( wp_unslash( $_POST['go_editorial_type'] ?? '' ) );
	if ( in_array( $type, go_verge_v3152_content_type_slugs(), true ) ) {
		$term = get_term_by( 'slug', $type, 'go_content_type' );
		if ( $term instanceof WP_Term ) { wp_set_object_terms( $id, array( (int) $term->term_id ), 'go_content_type', false ); }
	}
}
add_action( 'save_post_post', 'go_verge_editorial_classic_save', 200 );
