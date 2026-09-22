<?php
/**
 * Overdrive V25 — Entity newsroom admin.
 *
 * Makes the entity library useful as an editorial publishing queue. Entity/story
 * relationships live in the _go_entity_ids post meta array, so WordPress does
 * not provide native relationship counts as it does for taxonomies.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Return a cached map of entity ID => number of PUBLISHED stories.
 *
 * This deliberately counts only regular editorial posts with post_status=publish.
 * One aggregate read is much cheaper than one WP_Query for every entity row and
 * also lets the admin table filter/sort all 1k+ entities before pagination.
 *
 * @param bool $force Force rebuilding the cache.
 * @return array<int,int>
 */
function go_verge_v25_entity_published_counts( $force = false ) {
	$cache_key = 'go_entity_published_counts_v25';
	if ( ! $force ) {
		$cached = get_transient( $cache_key );
		if ( is_array( $cached ) ) {
			return $cached;
		}
	}

	global $wpdb;
	$values = $wpdb->get_col( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		$wpdb->prepare(
			"SELECT pm.meta_value
			 FROM {$wpdb->postmeta} pm
			 INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
			 WHERE pm.meta_key = %s
			   AND p.post_type = %s
			   AND p.post_status = %s",
			'_go_entity_ids',
			'post',
			'publish'
		)
	);

	$counts = array();
	foreach ( (array) $values as $raw_ids ) {
		$story_entities = maybe_unserialize( $raw_ids );
		if ( ! is_array( $story_entities ) ) {
			continue;
		}

		/* Never count one story twice for the same entity if legacy data has duplicates. */
		$story_entities = array_values( array_unique( array_filter( array_map( 'absint', $story_entities ) ) ) );
		foreach ( $story_entities as $entity_id ) {
			$counts[ $entity_id ] = isset( $counts[ $entity_id ] ) ? $counts[ $entity_id ] + 1 : 1;
		}
	}

	set_transient( $cache_key, $counts, 10 * MINUTE_IN_SECONDS );
	return $counts;
}

/** Count published stories linked to one entity. */
function go_verge_v24_entity_story_count( $entity_id ) {
	$entity_id = absint( $entity_id );
	if ( ! $entity_id ) { return 0; }
	$counts = go_verge_v25_entity_published_counts();
	return isset( $counts[ $entity_id ] ) ? absint( $counts[ $entity_id ] ) : 0;
}

/** Invalidate the aggregate after story relationship/content/status changes. */
function go_verge_v25_flush_entity_published_counts( $post_id = 0 ) {
	$post_id = absint( $post_id );
	if ( $post_id && 'post' !== get_post_type( $post_id ) ) {
		return;
	}
	delete_transient( 'go_entity_published_counts_v25' );
}
add_action( 'save_post_post', 'go_verge_v25_flush_entity_published_counts', 1000 );

/** Also clear when a regular post changes publication status. */
function go_verge_v25_entity_count_transition( $new_status, $old_status, $post ) {
	if ( ! $post instanceof WP_Post || 'post' !== $post->post_type || $new_status === $old_status ) {
		return;
	}
	delete_transient( 'go_entity_published_counts_v25' );
}
add_action( 'transition_post_status', 'go_verge_v25_entity_count_transition', 1000, 3 );

/** Newsroom-oriented columns for the entity library. */
function go_verge_v24_entity_columns( $columns ) {
	$new = array();
	foreach ( (array) $columns as $key => $label ) {
		$new[ $key ] = $label;
		if ( 'title' === $key ) {
			$new['go_entity_stories'] = __( 'Matérias publicadas', 'go-verge' );
		}
	}
	return $new;
}
add_filter( 'manage_go_entity_posts_columns', 'go_verge_v24_entity_columns', 30 );

/** Make the published-story column sortable. */
function go_verge_v25_entity_sortable_columns( $columns ) {
	$columns['go_entity_stories'] = 'go_entity_published_stories';
	return $columns;
}
add_filter( 'manage_edit-go_entity_sortable_columns', 'go_verge_v25_entity_sortable_columns', 30 );

function go_verge_v24_entity_column_content( $column, $post_id ) {
	$post_id = absint( $post_id );
	if ( 'go_entity_stories' === $column ) {
		$count = go_verge_v24_entity_story_count( $post_id );
		$url   = add_query_arg(
			array(
				'post_type'    => 'post',
				'post_status'  => 'publish',
				'go_entity_id' => $post_id,
			),
			admin_url( 'edit.php' )
		);
		printf(
			'<a class="go-entity-count%s" href="%s" aria-label="%s"><strong>%s</strong><span>%s</span></a>',
			$count ? '' : ' is-empty',
			esc_url( $url ),
			esc_attr( sprintf( _n( 'Ver %d matéria publicada vinculada', 'Ver %d matérias publicadas vinculadas', $count, 'go-verge' ), $count ) ),
			esc_html( number_format_i18n( $count ) ),
			esc_html( _n( 'publicada', 'publicadas', $count, 'go-verge' ) )
		);
	}
}
add_action( 'manage_go_entity_posts_custom_column', 'go_verge_v24_entity_column_content', 30, 2 );

/**
 * Add newsroom count filters to the native entity list toolbar.
 *
 * Editors can combine these with WordPress' existing status views, e.g.:
 * Rascunhos + Pelo menos + 5 => draft entities with 5+ published stories.
 */
function go_verge_v25_entity_count_filters( $post_type, $which ) {
	if ( 'go_entity' !== $post_type || 'top' !== $which ) {
		return;
	}

	$compare = isset( $_GET['go_entity_story_compare'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_story_compare'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$count   = isset( $_GET['go_entity_story_count'] ) ? absint( $_GET['go_entity_story_count'] ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	?>
	<label class="screen-reader-text" for="go-entity-story-compare"><?php esc_html_e( 'Comparação de matérias publicadas', 'go-verge' ); ?></label>
	<select name="go_entity_story_compare" id="go-entity-story-compare">
		<option value=""><?php esc_html_e( 'Matérias publicadas: qualquer', 'go-verge' ); ?></option>
		<option value="gte" <?php selected( $compare, 'gte' ); ?>><?php esc_html_e( 'Pelo menos', 'go-verge' ); ?></option>
		<option value="eq" <?php selected( $compare, 'eq' ); ?>><?php esc_html_e( 'Exatamente', 'go-verge' ); ?></option>
		<option value="lte" <?php selected( $compare, 'lte' ); ?>><?php esc_html_e( 'No máximo', 'go-verge' ); ?></option>
	</select>
	<label class="screen-reader-text" for="go-entity-story-count"><?php esc_html_e( 'Número de matérias publicadas', 'go-verge' ); ?></label>
	<input
		type="number"
		min="0"
		step="1"
		name="go_entity_story_count"
		id="go-entity-story-count"
		value="<?php echo '' === $count ? '' : esc_attr( $count ); ?>"
		placeholder="<?php esc_attr_e( 'Nº de matérias', 'go-verge' ); ?>"
		class="small-text go-entity-story-count-input"
	/>
	<?php
}
add_action( 'restrict_manage_posts', 'go_verge_v25_entity_count_filters', 20, 2 );

/** Get every entity ID. Used only on the go_entity admin list. */
function go_verge_v25_all_entity_ids() {
	global $wpdb;
	$ids = $wpdb->get_col( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		$wpdb->prepare(
			"SELECT ID FROM {$wpdb->posts} WHERE post_type = %s",
			'go_entity'
		)
	);
	return array_values( array_filter( array_map( 'absint', (array) $ids ) ) );
}

/** Test an entity count against an admin filter. */
function go_verge_v25_entity_count_matches( $actual, $compare, $wanted ) {
	$actual = absint( $actual );
	$wanted = absint( $wanted );
	switch ( $compare ) {
		case 'gte':
			return $actual >= $wanted;
		case 'eq':
			return $actual === $wanted;
		case 'lte':
			return $actual <= $wanted;
		default:
			return true;
	}
}

/**
 * Apply count filtering and sorting before WordPress paginates the entity table.
 *
 * We filter with post__in rather than replacing WP_List_Table, preserving search,
 * status views, pagination, Rank Math columns and bulk actions.
 */
function go_verge_v25_filter_entity_admin_query( $query ) {
	if ( ! is_admin() || ! $query->is_main_query() ) { return; }
	global $pagenow;
	if ( 'edit.php' !== $pagenow || 'go_entity' !== $query->get( 'post_type' ) ) { return; }

	$compare = isset( $_GET['go_entity_story_compare'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_story_compare'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$has_count = isset( $_GET['go_entity_story_count'] ) && '' !== (string) $_GET['go_entity_story_count']; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$wanted = $has_count ? absint( $_GET['go_entity_story_count'] ) : 0; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$is_filter = $has_count && in_array( $compare, array( 'gte', 'eq', 'lte' ), true );
	$is_sort   = 'go_entity_published_stories' === $query->get( 'orderby' );

	if ( ! $is_filter && ! $is_sort ) { return; }

	$counts = go_verge_v25_entity_published_counts();
	$ids    = go_verge_v25_all_entity_ids();

	if ( $is_filter ) {
		$ids = array_values( array_filter(
			$ids,
			static function( $entity_id ) use ( $counts, $compare, $wanted ) {
				$actual = isset( $counts[ $entity_id ] ) ? absint( $counts[ $entity_id ] ) : 0;
				return go_verge_v25_entity_count_matches( $actual, $compare, $wanted );
			}
		) );
	}

	if ( $is_sort ) {
		$order = 'ASC' === strtoupper( (string) $query->get( 'order' ) ) ? 'ASC' : 'DESC';
		usort(
			$ids,
			static function( $a, $b ) use ( $counts, $order ) {
				$a_count = isset( $counts[ $a ] ) ? absint( $counts[ $a ] ) : 0;
				$b_count = isset( $counts[ $b ] ) ? absint( $counts[ $b ] ) : 0;
				if ( $a_count === $b_count ) {
					$result = $a <=> $b;
				} else {
					$result = $a_count <=> $b_count;
				}
				return 'ASC' === $order ? $result : -$result;
			}
		);
		$query->set( 'orderby', 'post__in' );
	}

	/* Empty post__in means "no restriction" in WP_Query, so use [0] for no matches. */
	$query->set( 'post__in', $ids ? $ids : array( 0 ) );
}
add_action( 'pre_get_posts', 'go_verge_v25_filter_entity_admin_query', 35 );

/** Filter Posts when the editor clicks an entity count. */
function go_verge_v24_filter_posts_by_entity( $query ) {
	if ( ! is_admin() || ! $query->is_main_query() ) { return; }
	global $pagenow;
	if ( 'edit.php' !== $pagenow || 'post' !== $query->get( 'post_type' ) ) { return; }

	$entity_id = isset( $_GET['go_entity_id'] ) ? absint( $_GET['go_entity_id'] ) : 0; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( ! $entity_id ) { return; }

	$query->set( 'post_status', 'publish' );
	$query->set( 'meta_query', array( // phpcs:ignore WordPress.DB.SlowDBQuery.slow_db_query_meta_query
		array(
			'key'     => '_go_entity_ids',
			'value'   => 'i:' . $entity_id . ';',
			'compare' => 'LIKE',
		),
	) );
}
add_action( 'pre_get_posts', 'go_verge_v24_filter_posts_by_entity', 40 );

/** Explicit publishing action for the filtered newsroom workflow. */
function go_verge_v25_entity_bulk_actions( $actions ) {
	$actions['go_publish_entities'] = __( 'Publicar entidades selecionadas', 'go-verge' );
	return $actions;
}
add_filter( 'bulk_actions-edit-go_entity', 'go_verge_v25_entity_bulk_actions', 30 );

function go_verge_v25_handle_entity_bulk_publish( $redirect_to, $action, $post_ids ) {
	if ( 'go_publish_entities' !== $action ) { return $redirect_to; }

	$post_type = get_post_type_object( 'go_entity' );
	if ( ! $post_type || ! current_user_can( $post_type->cap->publish_posts ) ) {
		return add_query_arg( 'go_entities_publish_denied', 1, $redirect_to );
	}

	$published = 0;
	foreach ( array_map( 'absint', (array) $post_ids ) as $entity_id ) {
		if ( ! $entity_id || 'go_entity' !== get_post_type( $entity_id ) || ! current_user_can( 'edit_post', $entity_id ) ) {
			continue;
		}
		if ( 'publish' === get_post_status( $entity_id ) ) {
			continue;
		}
		$result = wp_update_post(
			array(
				'ID'          => $entity_id,
				'post_status' => 'publish',
			),
			true
		);
		if ( ! is_wp_error( $result ) ) {
			$published++;
		}
	}

	return add_query_arg( 'go_entities_published', $published, $redirect_to );
}
add_filter( 'handle_bulk_actions-edit-go_entity', 'go_verge_v25_handle_entity_bulk_publish', 30, 3 );

/** Explain the active entity filter above the Posts table and publish results. */
function go_verge_v24_entity_filter_notice() {
	$screen = get_current_screen();
	if ( ! $screen ) { return; }

	if ( 'edit-post' === $screen->id ) {
		$entity_id = isset( $_GET['go_entity_id'] ) ? absint( $_GET['go_entity_id'] ) : 0; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		if ( $entity_id && 'go_entity' === get_post_type( $entity_id ) ) {
			$clear = admin_url( 'edit.php' );
			printf(
				'<div class="notice notice-info inline go-entity-filter-notice"><p><strong>%s</strong> %s <a href="%s">%s</a></p></div>',
				esc_html( get_the_title( $entity_id ) ),
				esc_html__( '— mostrando apenas matérias PUBLICADAS vinculadas a esta entidade.', 'go-verge' ),
				esc_url( $clear ),
				esc_html__( 'Limpar filtro', 'go-verge' )
			);
		}
		return;
	}

	if ( 'edit-go_entity' !== $screen->id ) { return; }

	if ( isset( $_GET['go_entities_published'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$count = absint( $_GET['go_entities_published'] ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		printf(
			'<div class="notice notice-success is-dismissible"><p>%s</p></div>',
			esc_html( sprintf( _n( '%d entidade publicada.', '%d entidades publicadas.', $count, 'go-verge' ), $count ) )
		);
	}

	if ( isset( $_GET['go_entities_publish_denied'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		echo '<div class="notice notice-error is-dismissible"><p>' . esc_html__( 'Você não tem permissão para publicar entidades.', 'go-verge' ) . '</p></div>';
	}

	$compare = isset( $_GET['go_entity_story_compare'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_story_compare'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$has_count = isset( $_GET['go_entity_story_count'] ) && '' !== (string) $_GET['go_entity_story_count']; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( ! $has_count || ! in_array( $compare, array( 'gte', 'eq', 'lte' ), true ) ) { return; }

	$count = absint( $_GET['go_entity_story_count'] ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$labels = array(
		'gte' => __( 'pelo menos', 'go-verge' ),
		'eq'  => __( 'exatamente', 'go-verge' ),
		'lte' => __( 'no máximo', 'go-verge' ),
	);
	printf(
		'<div class="notice notice-info inline go-entity-filter-notice"><p>%s <strong>%s %s</strong>. %s</p></div>',
		esc_html__( 'Filtro ativo: entidades com', 'go-verge' ),
		esc_html( $labels[ $compare ] ),
		esc_html( sprintf( _n( '%d matéria publicada', '%d matérias publicadas', $count, 'go-verge' ), $count ) ),
		esc_html__( 'A contagem ignora rascunhos, agendadas, privadas e lixeira.', 'go-verge' )
	);
}
add_action( 'admin_notices', 'go_verge_v24_entity_filter_notice' );

/** Small visual hierarchy for the newsroom controls. */
function go_verge_v24_entity_admin_css() {
	$screen = get_current_screen();
	if ( ! $screen || ! in_array( $screen->id, array( 'edit-go_entity', 'edit-post' ), true ) ) { return; }
	?>
	<style>
		body.post-type-go_entity .wrap>h1{font-weight:650;letter-spacing:-.015em}
		body.post-type-go_entity .subsubsub{margin:12px 0 10px}
		body.post-type-go_entity .tablenav.top{min-height:42px;margin:8px 0 12px}
		body.post-type-go_entity .tablenav.top .actions{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
		body.post-type-go_entity .tablenav.top select,body.post-type-go_entity .tablenav.top input[type=number]{min-height:34px;border-color:#c3c4c7;border-radius:6px;background:#fff}
		body.post-type-go_entity .wp-list-table{border-color:#dcdcde;border-radius:8px;overflow:hidden;box-shadow:0 1px 2px rgba(0,0,0,.03)}
		body.post-type-go_entity .wp-list-table thead th,body.post-type-go_entity .wp-list-table thead td{background:#f6f7f7;border-bottom-color:#dcdcde}
		body.post-type-go_entity .wp-list-table tbody tr:hover{background:#fbfcfd}
		body.post-type-go_entity .wp-list-table .column-title .row-title{font-weight:650}
		.column-taxonomy-go_entity_type{width:16%}.column-go_entity_stories{width:156px}
		.go-entity-count{display:inline-flex;align-items:center;gap:5px;min-height:30px;padding:4px 9px;border:1px solid #dcdcde;border-radius:7px;background:#fff;color:#2c3338;text-decoration:none;box-shadow:0 1px 1px rgba(0,0,0,.02)}
		.go-entity-count:hover,.go-entity-count:focus-visible{border-color:#2271b1;color:#135e96;box-shadow:0 0 0 1px #2271b1}.go-entity-count strong{font-size:14px}.go-entity-count span{color:#646970;font-size:11px}.go-entity-count.is-empty{opacity:.58}
		.go-entity-filter-notice{margin:10px 0 8px!important;border-left-color:#2271b1!important}
		.go-entity-story-count-input{width:112px!important;min-width:112px;margin-left:0!important}
		@media(max-width:782px){body.post-type-go_entity .tablenav.top .actions{display:block}.go-entity-story-count-input{min-height:40px;width:130px!important}.column-go_entity_stories{width:auto}}
	</style>
	<?php
}
add_action( 'admin_head', 'go_verge_v24_entity_admin_css' );
