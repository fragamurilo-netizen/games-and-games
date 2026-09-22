<?php
/**
 * Overdrive V47 — one public subject identity + persistent anonymous follow counts.
 *
 * Backend models (Production, Game, Entity, Service, Platform, legacy tag) remain
 * useful editorial data, but readers and internal links should resolve each real
 * concept to one canonical public hub. Follow counts use that same canonical key,
 * so a legacy tag and its Production do not split the audience into two counters.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Map canonical destination kinds to the object types understood by the product UI. */
function go_verge_v47_destination_object_type( $kind ) {
	$kind = sanitize_key( (string) $kind );
	$map  = array(
		'production'  => 'productions',
		'productions' => 'productions',
		'game'        => 'games',
		'games'       => 'games',
		'entity'      => 'go_entity',
		'go_entity'   => 'go_entity',
		'service'     => 'go_service',
		'go_service'  => 'go_service',
		'platform'    => 'go_platform',
		'go_platform' => 'go_platform',
		'section'     => 'category',
		'category'    => 'category',
		'topic'       => 'post_tag',
		'post_tag'    => 'post_tag',
	);
	return $map[ $kind ] ?? '';
}

/** Build one canonical public identity for anything a reader can follow. */
function go_verge_v47_subject_identity( $object_id, $object_type ) {
	$object_id   = absint( $object_id );
	$object_type = sanitize_key( (string) $object_type );
	if ( ! $object_id || ! $object_type ) { return null; }

	/* Legacy tag aliases collapse into their first-class destination. */
	if ( 'post_tag' === $object_type ) {
		$term = get_term( $object_id, 'post_tag' );
		if ( ! ( $term instanceof WP_Term ) || is_wp_error( $term ) ) { return null; }
		if ( function_exists( 'go_verge_v36_topic_destination' ) ) {
			$dest = go_verge_v36_topic_destination( $term->slug );
			if ( is_array( $dest ) && ! empty( $dest['url'] ) ) {
				$type = go_verge_v47_destination_object_type( $dest['type'] ?? '' );
				$id   = absint( $dest['id'] ?? 0 );
				if ( $type && $id ) {
					return go_verge_v47_subject_identity( $id, $type );
				}
			}
		}
		$url = function_exists( 'go_verge_v21_topic_hub_url' ) ? go_verge_v21_topic_hub_url( $term->name ) : get_term_link( $term );
		if ( is_wp_error( $url ) || ! $url ) { return null; }
		return array(
			'key'  => 'topic:' . (int) $term->term_id,
			'id'   => (int) $term->term_id,
			'type' => 'post_tag',
			'name' => trim( wp_strip_all_tags( $term->name ) ),
			'url'  => esc_url_raw( $url ),
		);
	}

	/* Curated entity shadows reuse the structural/work hub they already represent. */
	if ( 'go_entity' === $object_type ) {
		$post = get_post( $object_id );
		if ( ! ( $post instanceof WP_Post ) || 'go_entity' !== $post->post_type ) { return null; }
		if ( function_exists( 'go_verge_v27_entity_canonical_target' ) ) {
			$target = go_verge_v27_entity_canonical_target( $object_id );
			if ( is_array( $target ) && ! empty( $target['url'] ) ) {
				$type = go_verge_v47_destination_object_type( $target['kind'] ?? '' );
				$id   = absint( $target['target_id'] ?? 0 );
				if ( $type && $id ) {
					return go_verge_v47_subject_identity( $id, $type );
				}
			}
		}
		$url = get_permalink( $object_id );
		if ( ! $url ) { return null; }
		return array( 'key'=>'entity:' . $object_id, 'id'=>$object_id, 'type'=>'go_entity', 'name'=>get_the_title( $object_id ), 'url'=>esc_url_raw( $url ) );
	}

	if ( in_array( $object_type, array( 'productions', 'games' ), true ) ) {
		$post = get_post( $object_id );
		if ( ! ( $post instanceof WP_Post ) || $object_type !== $post->post_type || 'publish' !== $post->post_status ) { return null; }
		$url = get_permalink( $object_id );
		if ( ! $url ) { return null; }
		$prefix = 'productions' === $object_type ? 'production' : 'game';
		return array( 'key'=>$prefix . ':' . $object_id, 'id'=>$object_id, 'type'=>$object_type, 'name'=>get_the_title( $object_id ), 'url'=>esc_url_raw( $url ) );
	}

	if ( in_array( $object_type, array( 'go_service', 'go_platform', 'category' ), true ) ) {
		$term = get_term( $object_id, $object_type );
		if ( ! ( $term instanceof WP_Term ) || is_wp_error( $term ) ) { return null; }
		$url = get_term_link( $term );
		if ( is_wp_error( $url ) || ! $url ) { return null; }
		$prefix = array( 'go_service'=>'service', 'go_platform'=>'platform', 'category'=>'section' )[ $object_type ];
		return array( 'key'=>$prefix . ':' . $object_id, 'id'=>$object_id, 'type'=>$object_type, 'name'=>$term->name, 'url'=>esc_url_raw( $url ) );
	}
	return null;
}

/** Internal links to a structural-shadow entity should never point at the shadow URL. */
function go_verge_v47_entity_permalink_to_canonical( $url, $post ) {
	if ( ! ( $post instanceof WP_Post ) || 'go_entity' !== $post->post_type ) { return $url; }
	if ( ! function_exists( 'go_verge_v27_entity_canonical_target' ) ) { return $url; }
	$target = go_verge_v27_entity_canonical_target( $post->ID );
	return ( is_array( $target ) && ! empty( $target['url'] ) ) ? esc_url_raw( $target['url'] ) : $url;
}
add_filter( 'post_type_link', 'go_verge_v47_entity_permalink_to_canonical', 200, 2 );

/** Canonicalize an editorial subject reference when a legacy tag already maps to a real object. */
function go_verge_v47_canonical_subject_reference( $reference ) {
	$reference = trim( (string) $reference );
	if ( ! preg_match( '/^(games|productions|go_entity|post_tag):(\d+)$/', $reference, $m ) ) { return $reference; }
	$identity = go_verge_v47_subject_identity( absint( $m[2] ), sanitize_key( $m[1] ) );
	if ( ! $identity ) { return $reference; }
	if ( in_array( $identity['type'], array( 'games', 'productions', 'go_entity', 'post_tag' ), true ) ) {
		return $identity['type'] . ':' . absint( $identity['id'] );
	}
	return $reference;
}

/** Keep subject meta from storing a duplicate tag representation of the same work/entity. */
function go_verge_v47_normalize_story_subject_meta( $post_id ) {
	if ( 'post' !== get_post_type( $post_id ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) { return; }
	foreach ( array( 'go_primary_subject_ref', 'go_technical_subject_ref', '_go_review_subject_reference', 'go_review_subject_reference', '_go_review_sheet_subject_reference' ) as $key ) {
		$current = trim( (string) get_post_meta( $post_id, $key, true ) );
		if ( ! $current ) { continue; }
		$canonical = go_verge_v47_canonical_subject_reference( $current );
		if ( $canonical && $canonical !== $current ) { update_post_meta( $post_id, $key, $canonical ); }
	}
}
add_action( 'save_post_post', 'go_verge_v47_normalize_story_subject_meta', 245 );

/** Follow table name. */
function go_verge_v47_follow_table() {
	global $wpdb;
	return $wpdb->prefix . 'go_subject_follows';
}

/** Physical follow-table schema version, independent from the theme version. */
function go_verge_v47_follow_schema_version() { return 2; }

/** Validate the table before any query can target it. */
function go_verge_v47_follow_table_ready( $deep = false ) {
	if ( (int) get_option( 'go_verge_follow_schema_v47', 0 ) < go_verge_v47_follow_schema_version() ) {
		return false;
	}
	if ( ! $deep ) { return true; }

	global $wpdb;
	$table = go_verge_v47_follow_table();
	$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) );
	if ( ! is_string( $found ) || $found !== $table ) { return false; }
	$columns = (array) $wpdb->get_col( 'SHOW COLUMNS FROM `' . str_replace( '`', '', $table ) . '`', 0 ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	return ! array_diff( array( 'id','object_key','visitor_hash','created_at' ), $columns );
}

/** Create/update the small deduplicated follow table and verify before marking success. */
function go_verge_v47_install_follow_table() {
	$schema = go_verge_v47_follow_schema_version();
	$current = (int) get_option( 'go_verge_follow_schema_v47', 0 );
	if ( function_exists( 'wp_doing_ajax' ) && wp_doing_ajax() ) { return; }
	if ( $current >= $schema && get_transient( 'go_verge_follow_schema_health_v47' ) ) { return; }
	if ( $current >= $schema && go_verge_v47_follow_table_ready( true ) ) {
		set_transient( 'go_verge_follow_schema_health_v47', 1, 12 * HOUR_IN_SECONDS );
		return;
	}
	if ( get_transient( 'go_verge_follow_schema_installing_v47' ) ) { return; }
	set_transient( 'go_verge_follow_schema_installing_v47', 1, 2 * MINUTE_IN_SECONDS );

	global $wpdb;
	$table   = go_verge_v47_follow_table();
	$charset = $wpdb->get_charset_collate();
	require_once ABSPATH . 'wp-admin/includes/upgrade.php';
	$sql = "CREATE TABLE {$table} (
		id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
		object_key varchar(191) NOT NULL,
		visitor_hash char(64) NOT NULL,
		created_at datetime NOT NULL,
		PRIMARY KEY  (id),
		UNIQUE KEY object_visitor (object_key,visitor_hash),
		KEY object_key (object_key),
		KEY visitor_hash (visitor_hash)
	) {$charset};";
	dbDelta( $sql );

	/* Do not persist a success marker for a partial/failed migration. */
	$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) );
	$columns = is_string( $found ) && $found === $table
		? (array) $wpdb->get_col( 'SHOW COLUMNS FROM `' . str_replace( '`', '', $table ) . '`', 0 ) // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
		: array();
	if ( is_string( $found ) && $found === $table && ! array_diff( array( 'id','object_key','visitor_hash','created_at' ), $columns ) ) {
		update_option( 'go_verge_follow_schema_v47', $schema, false );
		update_option( 'go_verge_follow_table_v47', GO_VERGE_VERSION, false );
		set_transient( 'go_verge_follow_schema_health_v47', 1, 12 * HOUR_IN_SECONDS );
	} else {
		delete_transient( 'go_verge_follow_schema_health_v47' );
		update_option( 'go_verge_follow_schema_v47', min( $current, $schema - 1 ), false );
	}
	delete_transient( 'go_verge_follow_schema_installing_v47' );
}
/*
 * Schema work never runs on public traffic. This used to be hooked to `init`,
 * so every anonymous page view paid for an option read whose only purpose was to
 * decide not to run dbDelta — and, for the one request that arrived first after a
 * version bump, for the dbDelta itself. The table is now created where it is
 * actually needed: on the two write endpoints, in the admin, and on activation.
 */
add_action( 'admin_init', 'go_verge_v47_install_follow_table', 25 );
add_action( 'after_switch_theme', 'go_verge_v47_install_follow_table', 25 );

/** Count followers for the canonical identity behind any public object. */
function go_verge_v47_follow_count( $object_id, $object_type ) {
	$identity = go_verge_v47_subject_identity( $object_id, $object_type );
	if ( ! $identity || ! go_verge_v47_follow_table_ready() ) { return 0; }
	global $wpdb;
	$table = go_verge_v47_follow_table();
	return (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM {$table} WHERE object_key = %s", $identity['key'] ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
}

/** Format a compact reader-facing count without pretending browsers equal humans. */
function go_verge_v47_follow_count_label( $count ) {
	$count = max( 0, absint( $count ) );
	return 1 === $count ? __( '1 seguidor', 'go-verge' ) : sprintf( __( '%s seguidores', 'go-verge' ), number_format_i18n( $count ) );
}

/** Stable anonymous browser token is HMACed server-side; no IP or email is stored. */
function go_verge_v47_visitor_hash( $visitor ) {
	if ( is_user_logged_in() ) {
		$visitor = 'user:' . get_current_user_id();
	} else {
		$visitor = trim( (string) $visitor );
		if ( ! preg_match( '/^[A-Za-z0-9_-]{20,96}$/', $visitor ) ) { return ''; }
		$visitor = 'browser:' . $visitor;
	}
	return hash_hmac( 'sha256', $visitor, wp_salt( 'auth' ) );
}

/** Public follow endpoint: unique browser + canonical subject + desired state. */
function go_verge_v47_rest_follow( WP_REST_Request $request ) {
	go_verge_v47_install_follow_table();
	if ( ! go_verge_v47_follow_table_ready() ) { return new WP_Error( 'go_follow_db_unavailable', __( 'Banco de seguidores em reparação.', 'go-verge' ), array( 'status'=>503 ) ); }
	$identity = go_verge_v47_subject_identity( absint( $request['id'] ), sanitize_key( $request['type'] ) );
	if ( ! $identity ) { return new WP_Error( 'go_follow_object', __( 'Assunto inválido.', 'go-verge' ), array( 'status'=>404 ) ); }
	$hash = go_verge_v47_visitor_hash( $request['visitor'] );
	if ( ! $hash ) { return new WP_Error( 'go_follow_visitor', __( 'Identificador inválido.', 'go-verge' ), array( 'status'=>400 ) ); }
	$following = rest_sanitize_boolean( $request['following'] );
	global $wpdb;
	$table = go_verge_v47_follow_table();
	if ( $following ) {
		$wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$table} (object_key,visitor_hash,created_at) VALUES (%s,%s,%s)", $identity['key'], $hash, current_time( 'mysql', true ) ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	} else {
		$wpdb->delete( $table, array( 'object_key'=>$identity['key'], 'visitor_hash'=>$hash ), array( '%s','%s' ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery
	}
	$count = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM {$table} WHERE object_key = %s", $identity['key'] ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	return rest_ensure_response( array(
		'following' => (bool) $following,
		'count'     => $count,
		'key'       => $identity['key'],
		'name'      => $identity['name'],
		'url'       => $identity['url'],
		'id'        => $identity['id'],
		'type'      => $identity['type'],
	) );
}

/** Import the pre-V47 local follow list in one request when a returning reader visits. */
function go_verge_v47_rest_follow_sync( WP_REST_Request $request ) {
	go_verge_v47_install_follow_table();
	if ( ! go_verge_v47_follow_table_ready() ) { return new WP_Error( 'go_follow_db_unavailable', __( 'Banco de seguidores em reparação.', 'go-verge' ), array( 'status'=>503 ) ); }
	$hash = go_verge_v47_visitor_hash( $request['visitor'] );
	if ( ! $hash ) { return new WP_Error( 'go_follow_visitor', __( 'Identificador inválido.', 'go-verge' ), array( 'status'=>400 ) ); }
	$tokens = array_slice( array_values( array_unique( array_filter( array_map( 'sanitize_text_field', (array) $request->get_param( 'tokens' ) ) ) ) ), 0, 60 );
	if ( ! $tokens ) { return rest_ensure_response( array( 'synced'=>0 ) ); }
	global $wpdb;
	$table  = go_verge_v47_follow_table();
	$synced = 0;
	foreach ( $tokens as $token ) {
		if ( ! preg_match( '/^(games|productions|go_entity|post_tag|category|go_service|go_platform):(\d+)$/', $token, $m ) ) { continue; }
		$identity = go_verge_v47_subject_identity( absint( $m[2] ), sanitize_key( $m[1] ) );
		if ( ! $identity ) { continue; }
		$result = $wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$table} (object_key,visitor_hash,created_at) VALUES (%s,%s,%s)", $identity['key'], $hash, current_time( 'mysql', true ) ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		if ( false !== $result ) { $synced++; }
	}
	return rest_ensure_response( array( 'synced'=>$synced ) );
}

/** Lightweight public count endpoint for components rendered from stale full-page caches. */
function go_verge_v47_rest_follow_count( WP_REST_Request $request ) {
	$identity = go_verge_v47_subject_identity( absint( $request['id'] ), sanitize_key( $request['type'] ) );
	if ( ! $identity ) { return new WP_Error( 'go_follow_object', __( 'Assunto inválido.', 'go-verge' ), array( 'status'=>404 ) ); }
	return rest_ensure_response( array( 'count'=>go_verge_v47_follow_count( $identity['id'], $identity['type'] ), 'key'=>$identity['key'] ) );
}

function go_verge_v47_register_follow_routes() {
	register_rest_route( 'go-verge/v1', '/follows', array(
		'methods'             => WP_REST_Server::CREATABLE,
		'callback'            => 'go_verge_v47_rest_follow',
		'permission_callback' => '__return_true',
		'args'                => array(
			'id'        => array( 'required'=>true, 'sanitize_callback'=>'absint' ),
			'type'      => array( 'required'=>true, 'sanitize_callback'=>'sanitize_key' ),
			'visitor'   => array( 'required'=>false, 'sanitize_callback'=>'sanitize_text_field' ),
			'following' => array( 'required'=>true, 'sanitize_callback'=>'rest_sanitize_boolean' ),
		),
	) );
	register_rest_route( 'go-verge/v1', '/follows/sync', array(
		'methods'             => WP_REST_Server::CREATABLE,
		'callback'            => 'go_verge_v47_rest_follow_sync',
		'permission_callback' => '__return_true',
		'args'                => array(
			'visitor' => array( 'required'=>false, 'sanitize_callback'=>'sanitize_text_field' ),
			'tokens'  => array( 'required'=>true ),
		),
	) );
	register_rest_route( 'go-verge/v1', '/follows/count', array(
		'methods'             => WP_REST_Server::READABLE,
		'callback'            => 'go_verge_v47_rest_follow_count',
		'permission_callback' => '__return_true',
		'args'                => array(
			'id'   => array( 'required'=>true, 'sanitize_callback'=>'absint' ),
			'type' => array( 'required'=>true, 'sanitize_callback'=>'sanitize_key' ),
		),
	) );
}
add_action( 'rest_api_init', 'go_verge_v47_register_follow_routes', 40 );

/** Resolve an aggregate follow key back into an admin-readable subject. */
function go_verge_v47_identity_from_key( $key ) {
	$key = trim( (string) $key );
	if ( ! preg_match( '/^(production|game|entity|service|platform|section|topic):(\d+)$/', $key, $m ) ) { return null; }
	$type = array(
		'production'=>'productions', 'game'=>'games', 'entity'=>'go_entity',
		'service'=>'go_service', 'platform'=>'go_platform', 'section'=>'category', 'topic'=>'post_tag',
	)[ $m[1] ];
	return go_verge_v47_subject_identity( absint( $m[2] ), $type );
}

/** Admin analytics: the newsroom can finally quantify what readers follow. */
function go_verge_v47_followers_admin_menu() {
	add_management_page( __( 'Seguidores', 'go-verge' ), __( 'Seguidores', 'go-verge' ), 'edit_others_posts', 'go-verge-followers', 'go_verge_v47_followers_admin_page' );
}
add_action( 'admin_menu', 'go_verge_v47_followers_admin_menu', 92 );

function go_verge_v47_followers_admin_page() {
	if ( ! current_user_can( 'edit_others_posts' ) ) { return; }
	go_verge_v47_install_follow_table();
	if ( ! go_verge_v47_follow_table_ready() ) {
		echo '<div class="wrap"><h1>' . esc_html__( 'Seguidores dos assuntos', 'go-verge' ) . '</h1><div class="notice notice-warning inline"><p>' . esc_html__( 'Banco de seguidores em reparação. Recarregue esta tela depois que a migration terminar.', 'go-verge' ) . '</p></div></div>';
		return;
	}
	global $wpdb;
	$table = go_verge_v47_follow_table();
	$rows = $wpdb->get_results( "SELECT object_key, COUNT(*) AS followers FROM {$table} GROUP BY object_key ORDER BY followers DESC, object_key ASC LIMIT 200", ARRAY_A ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$total_follows = (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$table}" ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$unique_readers = (int) $wpdb->get_var( "SELECT COUNT(DISTINCT visitor_hash) FROM {$table}" ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$total_subjects = (int) $wpdb->get_var( "SELECT COUNT(DISTINCT object_key) FROM {$table}" ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	?>
	<div class="wrap"><h1><?php esc_html_e( 'Seguidores dos assuntos', 'go-verge' ); ?></h1>
	<p><?php esc_html_e( 'Contagem anônima por navegador. O mesmo assunto usa uma única identidade mesmo quando veio de Produção, Entidade ou tag antiga. Nenhum IP ou e-mail é armazenado.', 'go-verge' ); ?></p>
	<div style="display:grid;grid-template-columns:repeat(3,minmax(180px,1fr));gap:12px;max-width:900px;margin:20px 0">
		<div class="card"><h2 style="margin-top:0"><?php echo esc_html( number_format_i18n( $total_follows ) ); ?></h2><p><?php esc_html_e( 'seguimentos ativos', 'go-verge' ); ?></p></div>
		<div class="card"><h2 style="margin-top:0"><?php echo esc_html( number_format_i18n( $unique_readers ) ); ?></h2><p><?php esc_html_e( 'navegadores únicos seguindo algo', 'go-verge' ); ?></p></div>
		<div class="card"><h2 style="margin-top:0"><?php echo esc_html( number_format_i18n( $total_subjects ) ); ?></h2><p><?php esc_html_e( 'assuntos com seguidores', 'go-verge' ); ?></p></div>
	</div>
	<table class="widefat striped"><thead><tr><th><?php esc_html_e( 'Assunto', 'go-verge' ); ?></th><th><?php esc_html_e( 'Tipo interno', 'go-verge' ); ?></th><th style="width:140px"><?php esc_html_e( 'Seguidores', 'go-verge' ); ?></th><th><?php esc_html_e( 'Destino canônico', 'go-verge' ); ?></th></tr></thead><tbody>
	<?php if ( $rows ) : foreach ( $rows as $row ) : $identity = go_verge_v47_identity_from_key( $row['object_key'] ); if ( ! $identity ) { continue; } ?>
	<tr><td><strong><?php echo esc_html( $identity['name'] ); ?></strong></td><td><code><?php echo esc_html( $identity['type'] ); ?></code></td><td><?php echo esc_html( number_format_i18n( (int) $row['followers'] ) ); ?></td><td><a href="<?php echo esc_url( $identity['url'] ); ?>" target="_blank" rel="noopener"><?php echo esc_html( wp_parse_url( $identity['url'], PHP_URL_PATH ) ?: $identity['url'] ); ?></a></td></tr>
	<?php endforeach; else : ?><tr><td colspan="4"><?php esc_html_e( 'Ainda não há seguimentos registrados nesta versão.', 'go-verge' ); ?></td></tr><?php endif; ?>
	</tbody></table></div>
	<?php
}

/** Add quick follower counts to first-class subject lists in wp-admin. */
function go_verge_v47_followers_post_columns( $columns ) {
	$columns['go_followers'] = __( 'Seguidores', 'go-verge' );
	return $columns;
}
foreach ( array( 'games', 'productions', 'go_entity' ) as $go_v47_pt ) {
	add_filter( 'manage_' . $go_v47_pt . '_posts_columns', 'go_verge_v47_followers_post_columns', 80 );
}
function go_verge_v47_followers_post_column( $column, $post_id ) {
	if ( 'go_followers' !== $column ) { return; }
	echo esc_html( number_format_i18n( go_verge_v47_follow_count( $post_id, get_post_type( $post_id ) ) ) );
}
foreach ( array( 'games', 'productions', 'go_entity' ) as $go_v47_pt ) {
	add_action( 'manage_' . $go_v47_pt . '_posts_custom_column', 'go_verge_v47_followers_post_column', 80, 2 );
}
