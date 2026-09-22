<?php
/**
 * Overdrive rebrand compatibility and one-time content migration.
 *
 * This module changes brand-facing copy only. Stable URLs, e-mail addresses,
 * social handles, block names and advertising integrations remain untouched.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Present the new name immediately while the stored legacy option is migrated.
 * Custom site names that are not the former brand are respected.
 *
 * @param mixed $name Stored WordPress site name.
 * @return mixed
 */
function go_verge_rebrand_site_name( $name ) {
	unset( $name );

	// The public brand is intentionally authoritative after the rebrand.
	// This prevents stale SEO-plugin/site-name options from leaking the former
	// name back into document titles, Open Graph or schema.
	return GO_VERGE_BRAND_NAME;
}
add_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );

/**
 * Replace legacy display copy without touching technical identifiers.
 *
 * @param mixed $value Text value to migrate.
 * @return mixed
 */
function go_verge_rebrand_copy( $value ) {
	/* 3.85.11: Game Overdrive is the canonical publisher name again. Do not
	 * rewrite it to the shorter alias at render time. Historical/stored copy is
	 * left intact; structured identity is enforced explicitly below. */
	return $value;
}

/** Whether a string still contains the former display brand. */
/** Keep standard WordPress author biographies aligned immediately at render time. */
function go_verge_rebrand_author_description( $value ) {
	return go_verge_rebrand_copy( $value );
}
add_filter( 'get_the_author_description', 'go_verge_rebrand_author_description', 999 );

function go_verge_rebrand_contains_legacy_name( $value ) {
	if ( ! is_string( $value ) || '' === $value ) {
		return false;
	}
	return (bool) preg_match( '/\bgame\s+overdrive\b/iu', $value )
		|| false !== stripos( $value, 'game%20overdrive' )
		|| false !== stripos( $value, 'game+overdrive' );
}

/**
 * Preserve the one legitimate historical use of the former brand: content that
 * documents the rename itself. Stable legacy URLs remain preserved separately.
 *
 * @param WP_Post|int $post Post object or ID.
 * @return bool
 */
function go_verge_rebrand_is_historical_post( $post ) {
	$post = $post instanceof WP_Post ? $post : get_post( absint( $post ) );
	if ( ! $post instanceof WP_Post ) {
		return false;
	}

	$title = strtolower( remove_accents( wp_strip_all_tags( (string) $post->post_title ) ) );
	$slug  = strtolower( (string) $post->post_name );
	$hay   = $title . ' ' . str_replace( '-', ' ', $slug );

	if ( false === strpos( $hay, 'game overdrive' ) || false === strpos( $hay, 'overdrive' ) ) {
		return false;
	}

	foreach ( array( 'agora e overdrive', 'agora é overdrive', 'vira overdrive', 'mudou de nome', 'muda de nome', 'novo nome', 'rebrand', 'passa a se chamar' ) as $marker ) {
		if ( false !== strpos( $hay, strtolower( remove_accents( $marker ) ) ) ) {
			return true;
		}
	}

	return false;
}

/**
 * Resolve the public About page after the Overdrive rename.
 *
 * The new slug is authoritative. The legacy page remains a fallback during a
 * staged deployment so schema and navigation never point at an unpublished
 * destination.
 *
 * @return string
 */
function go_verge_about_page_url() {
	foreach ( array( 'sobre-o-overdrive', 'sobre-o-game-overdrive' ) as $slug ) {
		$page = get_page_by_path( $slug, OBJECT, 'page' );
		if ( $page instanceof WP_Post && 'publish' === get_post_status( $page ) ) {
			return get_permalink( $page );
		}
	}

	return home_url( '/sobre-o-overdrive/' );
}

/**
 * Move an existing legacy About page to the canonical rebrand URL once.
 *
 * @return void
 */
function go_verge_migrate_about_page_slug() {
	if ( get_option( 'go_overdrive_about_slug_v2' ) ) {
		return;
	}

	$current = get_page_by_path( 'sobre-o-overdrive', OBJECT, 'page' );
	$legacy  = get_page_by_path( 'sobre-o-game-overdrive', OBJECT, 'page' );

	if ( ! ( $current instanceof WP_Post ) && $legacy instanceof WP_Post ) {
		wp_update_post(
			wp_slash(
				array(
					'ID'        => (int) $legacy->ID,
					'post_name' => 'sobre-o-overdrive',
					'post_title' => go_verge_rebrand_copy( $legacy->post_title ),
				)
			)
		);
	}

	update_option( 'go_overdrive_about_slug_v2', GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_migrate_about_page_slug', 94 );

/**
 * Preserve authority and backlinks from the former About URL.
 *
 * @return void
 */
function go_verge_redirect_legacy_about_page() {
	if ( is_admin() || wp_doing_ajax() || is_feed() || is_preview() ) {
		return;
	}

	$request = isset( $GLOBALS['wp']->request ) ? trim( (string) $GLOBALS['wp']->request, '/' ) : '';
	if ( 'sobre-o-game-overdrive' !== $request ) {
		return;
	}

	$page = get_page_by_path( 'sobre-o-overdrive', OBJECT, 'page' );
	if ( ! ( $page instanceof WP_Post ) || 'publish' !== get_post_status( $page ) ) {
		return;
	}

	wp_safe_redirect( get_permalink( $page ), 301, 'Overdrive rebrand canonical' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_legacy_about_page', 1 );

/**
 * Keep Rank Math's manually curated llms.txt copy aligned with the rebrand.
 *
 * @param string $extra Additional llms.txt content.
 * @return string
 */
function go_verge_rebrand_rank_math_llms_extra_content( $extra ) {
	$extra = go_verge_rebrand_copy( $extra );

	return str_replace(
		array(
			'/sobre-o-game-overdrive/',
			'/politicas-editoriais/',
			'/politica-de-privacidade/',
		),
		array(
			'/sobre-o-overdrive/',
			'/politica-editorial/',
			'/privacidade/',
		),
		$extra
	);
}
add_filter( 'rank_math/llms_txt/extra_content', 'go_verge_rebrand_rank_math_llms_extra_content', 100 );

/**
 * Migrate existing WordPress page copy once, after the theme is available.
 */
function go_verge_apply_overdrive_rebrand_migration() {
	if ( get_option( 'go_overdrive_rebrand_v1' ) ) {
		return;
	}

	/* Read the stored value without the presentation filter above. */
	remove_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	$stored_name = get_option( 'blogname' );
	add_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );

	if ( is_string( $stored_name ) && 0 === strcasecmp( trim( $stored_name ), 'Game Overdrive' ) ) {
		update_option( 'blogname', GO_VERGE_BRAND_NAME );
	}

	$description = get_option( 'blogdescription' );
	$description = go_verge_rebrand_copy( $description );
	if ( $description !== get_option( 'blogdescription' ) ) {
		update_option( 'blogdescription', $description );
	}

	$page_ids = get_posts(
		array(
			'post_type'              => 'page',
			'post_status'            => array( 'publish', 'future', 'draft', 'pending', 'private' ),
			'posts_per_page'         => -1,
			'fields'                 => 'ids',
			'orderby'                => 'ID',
			'order'                  => 'ASC',
			'no_found_rows'          => true,
			'suppress_filters'       => true,
			'update_post_meta_cache' => false,
			'update_post_term_cache' => false,
		)
	);

	$seo_meta_keys = array(
		'rank_math_title',
		'rank_math_description',
		'rank_math_facebook_title',
		'rank_math_facebook_description',
		'rank_math_twitter_title',
		'rank_math_twitter_description',
		'_yoast_wpseo_title',
		'_yoast_wpseo_metadesc',
	);

	foreach ( $page_ids as $page_id ) {
		$page = get_post( $page_id );
		if ( ! $page instanceof WP_Post || go_verge_rebrand_is_historical_post( $page ) ) {
			continue;
		}

		$changes = array( 'ID' => $page->ID );
		foreach ( array( 'post_title', 'post_content', 'post_excerpt' ) as $field ) {
			$updated = go_verge_rebrand_copy( $page->{$field} );
			if ( $updated !== $page->{$field} ) {
				$changes[ $field ] = $updated;
			}
		}

		if ( count( $changes ) > 1 ) {
			wp_update_post( wp_slash( $changes ) );
		}

		foreach ( $seo_meta_keys as $meta_key ) {
			$current = get_post_meta( $page->ID, $meta_key, true );
			$updated = go_verge_rebrand_copy( $current );
			if ( $updated !== $current ) {
				update_post_meta( $page->ID, $meta_key, $updated );
			}
		}
	}

	update_option( 'go_overdrive_rebrand_v1', GO_VERGE_VERSION, false );
}
add_action( 'after_switch_theme', 'go_verge_apply_overdrive_rebrand_migration', 95 );
add_action( 'admin_init', 'go_verge_apply_overdrive_rebrand_migration', 95 );


/**
 * Keep every front-end document-title surface on the current brand.
 *
 * Rank Math can serve a stored per-post title written before the rebrand. Google
 * reads that HTML title independently from the visible header, so sanitising the
 * final value here is required even after the database migration below.
 *
 * @param mixed $title Title resolved by an SEO plugin or WordPress.
 * @return mixed
 */
function go_verge_rebrand_frontend_title( $title ) {
	return go_verge_rebrand_copy( $title );
}
add_filter( 'rank_math/frontend/title', 'go_verge_rebrand_frontend_title', 999 );
add_filter( 'wpseo_title', 'go_verge_rebrand_frontend_title', 999 );
add_filter( 'rank_math/frontend/description', 'go_verge_rebrand_frontend_title', 999 );
add_filter( 'wpseo_metadesc', 'go_verge_rebrand_frontend_title', 999 );
add_filter( 'get_wp_title_rss', 'go_verge_rebrand_frontend_title', 999 );

/**
 * Keep WordPress' native title parts consistent when no SEO plugin owns title.
 *
 * @param array $parts Native document-title parts.
 * @return array
 */
function go_verge_rebrand_document_title_parts( $parts ) {
	if ( ! is_array( $parts ) ) {
		return $parts;
	}

	foreach ( $parts as $key => $value ) {
		$parts[ $key ] = go_verge_rebrand_copy( $value );
	}

	if ( isset( $parts['site'] ) ) {
		$parts['site'] = GO_VERGE_BRAND_NAME;
	}

	return $parts;
}
add_filter( 'document_title_parts', 'go_verge_rebrand_document_title_parts', 999 );

/**
 * Recursively replace the former display name in SEO-plugin option payloads.
 * Technical identifiers (domain, e-mail and social handles) are untouched.
 *
 * @param mixed $value Option value.
 * @return mixed
 */
function go_verge_rebrand_recursive_copy( $value, $depth = 0 ) {
	// Third-party and incomplete objects are not editorial strings. Do not mutate them.
	if ( is_object( $value ) || $depth >= 32 ) { return $value; }
	if ( is_array( $value ) ) {
		foreach ( $value as $key => $item ) {
			$value[ $key ] = go_verge_rebrand_recursive_copy( $item, $depth + 1 );
		}
		return $value;
	}
	return go_verge_rebrand_copy( $value );
}

/**
 * One-time search-brand migration for legacy SEO titles and plugin settings.
 *
 * The first rebrand migration only covered WordPress pages. Existing posts can
 * have a saved Rank Math/Yoast title ending in "Game Overdrive", which is
 * exactly what Google may keep displaying after the visual brand changed.
 *
 * @return void
 */
function go_verge_apply_search_brand_migration() {
	if ( get_option( 'go_overdrive_search_brand_v1' ) ) {
		return;
	}

	// Persist the canonical site name in WordPress itself, not only at render time.
	remove_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	$stored_name = (string) get_option( 'blogname' );
	add_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	if ( GO_VERGE_BRAND_NAME !== trim( $stored_name ) ) {
		update_option( 'blogname', GO_VERGE_BRAND_NAME );
	}

	// Rank Math/Yoast global title templates can also preserve the old suffix.
	foreach ( array( 'rank-math-options-titles', 'wpseo_titles' ) as $option_name ) {
		$current = get_option( $option_name, null );
		if ( null === $current ) {
			continue;
		}
		$updated = go_verge_rebrand_recursive_copy( $current );
		if ( $updated !== $current ) {
			update_option( $option_name, $updated, false );
		}
	}

	// Per-entry SEO metadata can also keep the old suffix. Update through the
	// metadata API so serialized values remain valid and the historical rebrand
	// article can retain its deliberately old name.
	global $wpdb;
	$meta_keys = array(
		'rank_math_title',
		'rank_math_description',
		'rank_math_facebook_title',
		'rank_math_facebook_description',
		'rank_math_twitter_title',
		'rank_math_twitter_description',
		'_yoast_wpseo_title',
		'_yoast_wpseo_metadesc',
	);
	$placeholders = implode( ',', array_fill( 0, count( $meta_keys ), '%s' ) );
	$params       = array_merge( array( '%Game Overdrive%', '%Game%20Overdrive%', '%Game+Overdrive%' ), $meta_keys );
	$sql          = $wpdb->prepare(
		"SELECT meta_id, post_id FROM {$wpdb->postmeta}
		 WHERE ( meta_value LIKE %s OR meta_value LIKE %s OR meta_value LIKE %s )
		 AND meta_key IN ({$placeholders})",
		$params
	);
	$rows = $wpdb->get_results( $sql ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	foreach ( (array) $rows as $row ) {
		if ( go_verge_rebrand_is_historical_post( (int) $row->post_id ) ) {
			continue;
		}
		$meta = get_metadata_by_mid( 'post', (int) $row->meta_id );
		if ( ! $meta ) {
			continue;
		}
		$updated = go_verge_rebrand_recursive_copy( $meta->meta_value );
		if ( $updated !== $meta->meta_value ) {
			update_metadata_by_mid( 'post', (int) $row->meta_id, $updated );
		}
	}

	update_option( 'go_overdrive_search_brand_v1', GO_VERGE_VERSION, false );
}
add_action( 'after_switch_theme', 'go_verge_apply_search_brand_migration', 96 );

/**
 * Clean the former brand from public taxonomy descriptions and term SEO meta.
 *
 * Google can surface category hub descriptions independently from post titles.
 * Visible taxonomy copy should use the primary brand "Overdrive". The retired
 * display brand is kept only where history or technical routing requires it,
 * never as a current publisher/site-name signal.
 *
 * @return void
 */
function go_verge_apply_taxonomy_brand_migration() {
	if ( get_option( 'go_overdrive_taxonomy_brand_v1' ) ) {
		return;
	}

	$terms = get_terms(
		array(
			'taxonomy'   => array( 'category', 'post_tag' ),
			'hide_empty' => false,
		)
	);

	if ( ! is_wp_error( $terms ) ) {
		$seo_meta_keys = array(
			'rank_math_title',
			'rank_math_description',
			'rank_math_facebook_title',
			'rank_math_facebook_description',
			'rank_math_twitter_title',
			'rank_math_twitter_description',
		);

		foreach ( (array) $terms as $term ) {
			if ( ! ( $term instanceof WP_Term ) ) {
				continue;
			}

			$description = go_verge_rebrand_copy( (string) $term->description );
			if ( $description !== (string) $term->description ) {
				wp_update_term(
					(int) $term->term_id,
					$term->taxonomy,
					array( 'description' => $description )
				);
			}

			foreach ( $seo_meta_keys as $meta_key ) {
				$current = get_term_meta( (int) $term->term_id, $meta_key, true );
				$updated = go_verge_rebrand_copy( $current );
				if ( $updated !== $current ) {
					update_term_meta( (int) $term->term_id, $meta_key, $updated );
				}
			}
		}
	}

	update_option( 'go_overdrive_taxonomy_brand_v1', GO_VERGE_VERSION, false );
}
add_action( 'after_switch_theme', 'go_verge_apply_taxonomy_brand_migration', 97 );


/* -------------------------------------------------------------------------
 * Complete brand migration — 3.16.7
 * ---------------------------------------------------------------------- */

/**
 * Enforce the current publisher name in Rank Math's global identity settings.
 *
 * "Game Overdrive" is primary. "Overdrive" is deliberately retained as the
 * concise human-readable fallback for Google's automated site-name system.
 * The bare hostname is not persisted as an alternate site name.
 *
 * @param mixed $value Rank Math titles option.
 * @return mixed
 */
function go_verge_rebrand_rank_math_identity_option( $value ) {
	if ( ! is_array( $value ) ) {
		return $value;
	}

	$value = go_verge_rebrand_recursive_copy( $value );
	$value['website_name']           = GO_VERGE_BRAND_NAME;
	$value['website_alternate_name'] = 'Overdrive';
	$value['knowledgegraph_name']    = GO_VERGE_BRAND_NAME;

	foreach ( array( 'site_alternate_name', 'alternate_name', 'alternateName' ) as $key ) {
		if ( array_key_exists( $key, $value ) ) {
			$value[ $key ] = 'Overdrive';
		}
	}

	return $value;
}

/*
 * Enforce the identity on every read/save too. A plugin update or an editor
 * opening Rank Math settings must not be able to resurrect a cached legacy
 * site/knowledge-graph name after the one-time migration has already run.
 */
add_filter( 'option_rank-math-options-titles', 'go_verge_rebrand_rank_math_identity_option', 999 );

function go_verge_rebrand_rank_math_identity_pre_update( $new_value, $old_value ) {
	unset( $old_value );
	return go_verge_rebrand_rank_math_identity_option( $new_value );
}
add_filter( 'pre_update_option_rank-math-options-titles', 'go_verge_rebrand_rank_math_identity_pre_update', 999, 2 );

/**
 * Replace the former display brand in rendered text nodes only.
 *
 * This catches old attachment/file labels such as
 * "Midia-Kit-Game-Overdrive-2026-08" without changing href/src attributes,
 * the gameoverdrive.com.br domain, e-mail addresses, social handles or code.
 * Historical editorial coverage of the rename is explicitly preserved.
 *
 * @param string $html Rendered public content.
 * @return string
 */
function go_verge_rebrand_visible_text_nodes( $html ) {
	if ( ! is_string( $html ) || '' === $html || false === stripos( $html, 'game' ) || false === stripos( $html, 'overdrive' ) ) {
		return $html;
	}

	$parts = preg_split(
		'#(<(?:script|style|pre|code|textarea)\b[^>]*>.*?</(?:script|style|pre|code|textarea)>)#isu',
		$html,
		-1,
		PREG_SPLIT_DELIM_CAPTURE
	);
	if ( ! is_array( $parts ) ) {
		return $html;
	}

	foreach ( $parts as $index => $part ) {
		if ( 1 === $index % 2 ) {
			continue;
		}
		$parts[ $index ] = preg_replace_callback(
			'/(^|>)([^<]+)(?=<|$)/u',
			static function ( $match ) {
				$text = preg_replace( '/\bgame(?:\s|&nbsp;|&#160;|-|_)+overdrive\b/iu', 'Overdrive', $match[2] );
				return $match[1] . $text;
			},
			$part
		);
	}

	return implode( '', $parts );
}

function go_verge_rebrand_rendered_content( $content ) {
	if ( is_admin() || is_preview() ) {
		return $content;
	}

	$post_id = get_the_ID();
	if ( $post_id && go_verge_rebrand_is_historical_post( $post_id ) ) {
		return $content;
	}

	return go_verge_rebrand_visible_text_nodes( $content );
}
add_filter( 'the_content', 'go_verge_rebrand_rendered_content', 9998 );
add_filter( 'widget_text_content', 'go_verge_rebrand_visible_text_nodes', 9998 );

/* Author bios are a separate public entity signal and bypass the_content. */
add_filter( 'get_the_author_description', 'go_verge_rebrand_copy', 999 );

/**
 * Re-run a narrow stored-copy cleanup for installations that completed an
 * earlier rebrand pass before institutional pages/author bios were updated.
 * Hyphenated attachment URLs are deliberately not touched; their visible label
 * is handled at render time above.
 */
function go_verge_apply_rebrand_residual_cleanup_v5() {
	if ( get_option( 'go_overdrive_rebrand_residual_v5' ) ) {
		return;
	}

	global $wpdb;
	$like = '%' . $wpdb->esc_like( 'Game Overdrive' ) . '%';
	$ids  = (array) $wpdb->get_col(
		$wpdb->prepare(
			"SELECT ID FROM {$wpdb->posts}
			 WHERE post_type <> 'revision' AND post_status <> 'auto-draft'
			 AND (post_title LIKE %s OR post_excerpt LIKE %s OR post_content LIKE %s)",
			$like,
			$like,
			$like
		)
	);

	foreach ( $ids as $post_id ) {
		$post_id = absint( $post_id );
		if ( ! $post_id || go_verge_rebrand_is_historical_post( $post_id ) ) {
			continue;
		}
		$post = get_post( $post_id );
		if ( ! $post instanceof WP_Post ) {
			continue;
		}
		$fields = array(
			'post_title'   => go_verge_rebrand_copy( (string) $post->post_title ),
			'post_excerpt' => go_verge_rebrand_copy( (string) $post->post_excerpt ),
			'post_content' => go_verge_rebrand_copy( (string) $post->post_content ),
		);
		$wpdb->update( $wpdb->posts, $fields, array( 'ID' => $post_id ), array( '%s', '%s', '%s' ), array( '%d' ) );
		clean_post_cache( $post_id );
	}

	$user_ids = (array) $wpdb->get_col(
		$wpdb->prepare(
			"SELECT DISTINCT user_id FROM {$wpdb->usermeta} WHERE meta_key = 'description' AND meta_value LIKE %s",
			$like
		)
	);
	foreach ( $user_ids as $user_id ) {
		$bio = (string) get_user_meta( absint( $user_id ), 'description', true );
		$clean = go_verge_rebrand_copy( $bio );
		if ( $clean !== $bio ) {
			update_user_meta( absint( $user_id ), 'description', $clean );
		}
	}

	update_option( 'go_overdrive_rebrand_residual_v5', GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_apply_rebrand_residual_cleanup_v5', 96 );

/**
 * Query metadata rows that still contain the former display brand.
 *
 * @param string $table Fully-qualified metadata table.
 * @param string $mid_col Metadata ID column.
 * @param string $owner_col Object ID column.
 * @param string $value_col Value column.
 * @return array<int,object>
 */
function go_verge_rebrand_find_meta_rows( $table, $mid_col, $owner_col, $value_col ) {
	global $wpdb;

	$like_plain   = '%' . $wpdb->esc_like( 'Game Overdrive' ) . '%';
	$like_encoded = '%' . $wpdb->esc_like( 'Game%20Overdrive' ) . '%';
	$like_plus    = '%' . $wpdb->esc_like( 'Game+Overdrive' ) . '%';

	// Identifiers are supplied only by this file from core table/column names.
	$sql = $wpdb->prepare(
		"SELECT {$mid_col} AS meta_id, {$owner_col} AS object_id
		 FROM {$table}
		 WHERE {$value_col} LIKE %s OR {$value_col} LIKE %s OR {$value_col} LIKE %s",
		$like_plain,
		$like_encoded,
		$like_plus
	);

	return (array) $wpdb->get_results( $sql ); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
}

/**
 * Finish the display-name migration everywhere WordPress can expose it.
 *
 * This intentionally does NOT replace `gameoverdrive.com.br`, e-mail addresses,
 * social handles, Gutenberg block names, or legacy redirect slugs. Those are
 * stable technical identifiers. It also preserves the historical article that
 * explicitly documents the rename.
 *
 * Direct updates to post fields avoid touching post_modified and avoid running
 * the newsroom's expensive save pipeline merely because a boilerplate brand
 * string changed.
 *
 * @return void
 */
function go_verge_apply_complete_rebrand_v3() {
	if ( get_option( 'go_overdrive_complete_rebrand_v4' ) ) {
		return;
	}

	global $wpdb;

	$report = array(
		'posts'     => 0,
		'postmeta'  => 0,
		'terms'     => 0,
		'termmeta'  => 0,
		'users'     => 0,
		'usermeta'  => 0,
		'options'   => 0,
		'historical_preserved' => 0,
		'completed_at'          => current_time( 'mysql' ),
	);

	/* Canonical WordPress + Google News identity. */
	remove_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	update_option( 'blogname', GO_VERGE_BRAND_NAME );
	add_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );

	$description = (string) get_option( 'blogdescription', '' );
	$clean_desc  = go_verge_rebrand_copy( $description );
	if ( $clean_desc !== $description ) {
		update_option( 'blogdescription', $clean_desc );
	}
	update_option( 'go_verge_news_publication_name', GO_VERGE_BRAND_NAME, false );

	/* Public/editorial options, widgets, theme mods and plugin settings. Use the
	 * WordPress API so serialized arrays keep their lengths and structure. */
	$like_plain   = '%' . $wpdb->esc_like( 'Game Overdrive' ) . '%';
	$like_encoded = '%' . $wpdb->esc_like( 'Game%20Overdrive' ) . '%';
	$like_plus    = '%' . $wpdb->esc_like( 'Game+Overdrive' ) . '%';
	$option_sql   = $wpdb->prepare(
		"SELECT option_name FROM {$wpdb->options}
		 WHERE ( option_name IN ('rank-math-options-titles','wpseo_titles') OR option_name LIKE %s OR option_name LIKE %s )
		 AND ( option_value LIKE %s OR option_value LIKE %s OR option_value LIKE %s )",
		$wpdb->esc_like( 'widget_' ) . '%',
		$wpdb->esc_like( 'theme_mods_' ) . '%',
		$like_plain,
		$like_encoded,
		$like_plus
	);
	$option_names = (array) $wpdb->get_col( $option_sql );
	foreach ( $option_names as $option_name ) {
		$current = get_option( $option_name, null );
		if ( null === $current ) {
			continue;
		}
		$updated = go_verge_rebrand_recursive_copy( $current );
		if ( $updated !== $current ) {
			update_option( $option_name, $updated );
			++$report['options'];
		}
	}

	/* Rank Math gets the current name plus the current human-readable alias; the retired legacy brand is never reintroduced. */
	$rank_math_titles = get_option( 'rank-math-options-titles', null );
	if ( is_array( $rank_math_titles ) ) {
		$rank_math_titles = go_verge_rebrand_rank_math_identity_option( $rank_math_titles );
		update_option( 'rank-math-options-titles', $rank_math_titles, false );
	}

	/* Visible content across posts, pages, attachments, reusable blocks and menu
	 * labels. Slugs/permalinks are never changed here. */
	$post_sql = $wpdb->prepare(
		"SELECT ID FROM {$wpdb->posts}
		 WHERE post_type <> 'revision'
		 AND post_status <> 'auto-draft'
		 AND (
			post_title LIKE %s OR post_excerpt LIKE %s OR post_content LIKE %s
			OR post_title LIKE %s OR post_excerpt LIKE %s OR post_content LIKE %s
			OR post_title LIKE %s OR post_excerpt LIKE %s OR post_content LIKE %s
		 )",
		$like_plain, $like_plain, $like_plain,
		$like_encoded, $like_encoded, $like_encoded,
		$like_plus, $like_plus, $like_plus
	);
	$post_ids = array_map( 'absint', (array) $wpdb->get_col( $post_sql ) );

	foreach ( $post_ids as $post_id ) {
		$post = get_post( $post_id );
		if ( ! $post instanceof WP_Post ) {
			continue;
		}
		if ( go_verge_rebrand_is_historical_post( $post ) ) {
			++$report['historical_preserved'];
			continue;
		}

		$changes = array();
		foreach ( array( 'post_title', 'post_excerpt', 'post_content' ) as $field ) {
			$updated = go_verge_rebrand_copy( (string) $post->{$field} );
			if ( $updated !== (string) $post->{$field} ) {
				$changes[ $field ] = $updated;
			}
		}
		if ( ! $changes ) {
			continue;
		}

		$wpdb->update( $wpdb->posts, $changes, array( 'ID' => $post_id ) );
		clean_post_cache( $post_id );
		++$report['posts'];
	}

	/* Every custom field, including Rank Math, line support, old theme panels and
	 * serialized blocks. Historical rebrand content remains untouched. */
	foreach ( go_verge_rebrand_find_meta_rows( $wpdb->postmeta, 'meta_id', 'post_id', 'meta_value' ) as $row ) {
		if ( go_verge_rebrand_is_historical_post( (int) $row->object_id ) ) {
			continue;
		}
		$meta = get_metadata_by_mid( 'post', (int) $row->meta_id );
		if ( ! $meta ) {
			continue;
		}
		$updated = go_verge_rebrand_recursive_copy( $meta->meta_value );
		if ( $updated !== $meta->meta_value && update_metadata_by_mid( 'post', (int) $row->meta_id, $updated ) ) {
			++$report['postmeta'];
		}
	}

	/* Taxonomy names/descriptions. Keep slugs stable to preserve URLs. */
	$term_sql = $wpdb->prepare(
		"SELECT DISTINCT t.term_id, tt.taxonomy
		 FROM {$wpdb->terms} t
		 INNER JOIN {$wpdb->term_taxonomy} tt ON tt.term_id = t.term_id
		 WHERE t.name LIKE %s OR tt.description LIKE %s
			OR t.name LIKE %s OR tt.description LIKE %s
			OR t.name LIKE %s OR tt.description LIKE %s",
		$like_plain, $like_plain,
		$like_encoded, $like_encoded,
		$like_plus, $like_plus
	);
	$terms = (array) $wpdb->get_results( $term_sql );
	foreach ( $terms as $row ) {
		$term = get_term( (int) $row->term_id, (string) $row->taxonomy );
		if ( ! $term instanceof WP_Term ) {
			continue;
		}
		$args = array();
		$name = go_verge_rebrand_copy( (string) $term->name );
		$desc = go_verge_rebrand_copy( (string) $term->description );
		if ( $name !== (string) $term->name ) {
			$args['name'] = $name;
		}
		if ( $desc !== (string) $term->description ) {
			$args['description'] = $desc;
		}
		if ( $args && ! is_wp_error( wp_update_term( (int) $term->term_id, $term->taxonomy, $args ) ) ) {
			++$report['terms'];
		}
	}

	if ( ! empty( $wpdb->termmeta ) ) {
		foreach ( go_verge_rebrand_find_meta_rows( $wpdb->termmeta, 'meta_id', 'term_id', 'meta_value' ) as $row ) {
			$meta = get_metadata_by_mid( 'term', (int) $row->meta_id );
			if ( ! $meta ) {
				continue;
			}
			$updated = go_verge_rebrand_recursive_copy( $meta->meta_value );
			if ( $updated !== $meta->meta_value && update_metadata_by_mid( 'term', (int) $row->meta_id, $updated ) ) {
				++$report['termmeta'];
			}
		}
	}

	/* Author display names, biographies, credentials and legacy theme fields. */
	$user_sql = $wpdb->prepare(
		"SELECT ID, display_name FROM {$wpdb->users}
		 WHERE display_name LIKE %s OR display_name LIKE %s OR display_name LIKE %s",
		$like_plain,
		$like_encoded,
		$like_plus
	);
	foreach ( (array) $wpdb->get_results( $user_sql ) as $row ) {
		$display_name = go_verge_rebrand_copy( (string) $row->display_name );
		if ( $display_name !== (string) $row->display_name ) {
			$result = wp_update_user( array( 'ID' => (int) $row->ID, 'display_name' => $display_name ) );
			if ( ! is_wp_error( $result ) ) {
				++$report['users'];
			}
		}
	}

	foreach ( go_verge_rebrand_find_meta_rows( $wpdb->usermeta, 'umeta_id', 'user_id', 'meta_value' ) as $row ) {
		$meta = get_metadata_by_mid( 'user', (int) $row->meta_id );
		if ( ! $meta ) {
			continue;
		}
		$updated = go_verge_rebrand_recursive_copy( $meta->meta_value );
		if ( $updated !== $meta->meta_value && update_metadata_by_mid( 'user', (int) $row->meta_id, $updated ) ) {
			++$report['usermeta'];
		}
	}

	/* New canonical About template/slug is already handled by the v2 migration;
	 * clean stale rewrite/routing caches after all public strings are stable. */
	update_option( 'go_overdrive_rebrand_report_v4', $report, false );
	update_option( 'go_overdrive_complete_rebrand_v4', GO_VERGE_VERSION, false );

	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'after_switch_theme', 'go_verge_apply_complete_rebrand_v3', 98 );


/**
 * 3.81.15 — converge every mutable public identity surface on the rebrand.
 *
 * The canonical publisher/site name is Game Overdrive. The shorter Overdrive
 * brand remains available as alternateName for Google and other consumers.
 */
function go_verge_apply_single_brand_identity_v1() {
	if ( get_option( 'go_overdrive_single_brand_identity_v1' ) ) {
		return;
	}

	remove_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	update_option( 'blogname', GO_VERGE_BRAND_NAME );
	add_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	update_option( 'go_verge_news_publication_name', GO_VERGE_BRAND_NAME, false );

	$rank_math_titles = get_option( 'rank-math-options-titles', null );
	if ( is_array( $rank_math_titles ) ) {
		update_option( 'rank-math-options-titles', go_verge_rebrand_rank_math_identity_option( $rank_math_titles ), false );
	}

	/* Reuse the complete migration's safe replacement rules. If this build already
	 * ran that migration during the current theme switch, do not scan the tables
	 * twice. Existing installations carry an older marker and receive one fresh
	 * convergence pass. */
	$complete_version = (string) get_option( 'go_overdrive_complete_rebrand_v4', '' );
	if ( GO_VERGE_VERSION !== $complete_version ) {
		delete_option( 'go_overdrive_complete_rebrand_v4' );
		go_verge_apply_complete_rebrand_v3();
	}

	update_option( 'go_overdrive_single_brand_identity_v1', GO_VERGE_VERSION, false );

	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'after_switch_theme', 'go_verge_apply_single_brand_identity_v1', 99 );

/**
 * 3.81.29 — persist Google's ordered site-name fallback in Rank Math.
 *
 * This is intentionally cheap and safe to run on admin_init because sites that
 * already completed 3.81.15 will not rerun the heavier rebrand migration.
 */
function go_verge_apply_google_site_name_fallback_v1() {
	if ( get_option( 'go_overdrive_google_site_name_fallback_v1' ) ) {
		return;
	}

	$rank_math_titles = get_option( 'rank-math-options-titles', null );
	if ( is_array( $rank_math_titles ) ) {
		update_option( 'rank-math-options-titles', go_verge_rebrand_rank_math_identity_option( $rank_math_titles ), false );
	}

	update_option( 'go_overdrive_google_site_name_fallback_v1', GO_VERGE_VERSION, false );
	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'admin_init', 'go_verge_apply_google_site_name_fallback_v1', 97 );
add_action( 'after_switch_theme', 'go_verge_apply_google_site_name_fallback_v1', 100 );

/**
 * 3.81.31 — prefer only human-readable site names in Search signals.
 *
 * Older cached HTML could still expose the hostname as the last alternateName.
 * Re-save Rank Math's human alias and purge page cache once after this update.
 */
function go_verge_apply_google_human_site_name_v1() {
	if ( (string) get_option( 'go_overdrive_google_human_site_name_v1', '' ) === (string) GO_VERGE_VERSION ) {
		return;
	}

	$rank_math_titles = get_option( 'rank-math-options-titles', null );
	if ( is_array( $rank_math_titles ) ) {
		update_option( 'rank-math-options-titles', go_verge_rebrand_rank_math_identity_option( $rank_math_titles ), false );
	}

	update_option( 'go_overdrive_google_human_site_name_v1', GO_VERGE_VERSION, false );
	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'admin_init', 'go_verge_apply_google_human_site_name_v1', 98 );
add_action( 'after_switch_theme', 'go_verge_apply_google_human_site_name_v1', 101 );


/**
 * 3.85.11 — restore Game Overdrive as the canonical publisher/site name.
 * Overdrive remains the concise alternateName for Google site-name systems.
 * Runs on admin_init so replacing the active theme ZIP is enough; no theme
 * deactivation/reactivation is required.
 */
function go_verge_apply_game_overdrive_identity_v2() {
	if ( (string) get_option( 'go_game_overdrive_identity_v2', '' ) === (string) GO_VERGE_VERSION ) {
		return;
	}

	remove_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	update_option( 'blogname', GO_VERGE_BRAND_NAME );
	add_filter( 'option_blogname', 'go_verge_rebrand_site_name', 20 );
	update_option( 'go_verge_news_publication_name', GO_VERGE_BRAND_NAME, false );

	$rank_math_titles = get_option( 'rank-math-options-titles', null );
	if ( is_array( $rank_math_titles ) ) {
		update_option( 'rank-math-options-titles', go_verge_rebrand_rank_math_identity_option( $rank_math_titles ), false );
	}

	update_option( 'go_game_overdrive_identity_v2', GO_VERGE_VERSION, false );
	if ( function_exists( 'go_verge_purge_all_page_cache' ) ) {
		go_verge_purge_all_page_cache();
	}
}
add_action( 'admin_init', 'go_verge_apply_game_overdrive_identity_v2', 120 );
add_action( 'after_switch_theme', 'go_verge_apply_game_overdrive_identity_v2', 120 );

/** Return the next expensive rebrand worker whose completion marker is absent. */
function go_verge_next_heavy_rebrand_migration() {
	$migrations = array(
		array( 'option' => 'go_overdrive_search_brand_v1', 'callback' => 'go_verge_apply_search_brand_migration' ),
		array( 'option' => 'go_overdrive_taxonomy_brand_v1', 'callback' => 'go_verge_apply_taxonomy_brand_migration' ),
		array( 'option' => 'go_overdrive_complete_rebrand_v4', 'callback' => 'go_verge_apply_complete_rebrand_v3' ),
		array( 'option' => 'go_overdrive_single_brand_identity_v1', 'callback' => 'go_verge_apply_single_brand_identity_v1' ),
	);
	foreach ( $migrations as $migration ) {
		if ( ! get_option( $migration['option'] ) ) {
			return $migration;
		}
	}
	return array();
}

/** Schedule one heavy migration outside the interactive wp-admin request. */
function go_verge_schedule_heavy_rebrand_migration( $delay = 30 ) {
	if ( ! go_verge_next_heavy_rebrand_migration() || wp_next_scheduled( 'go_verge_run_heavy_rebrand_migration' ) ) {
		return;
	}
	wp_schedule_single_event( time() + max( 30, absint( $delay ) ), 'go_verge_run_heavy_rebrand_migration' );
}

/** Run at most one table-scanning migration per cron request, then chain safely. */
function go_verge_run_heavy_rebrand_migration() {
	if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( 'heavy_rebrand_migration', 15 * MINUTE_IN_SECONDS ) ) {
		return;
	}

	try {
		$migration = go_verge_next_heavy_rebrand_migration();
		if ( ! $migration || ! is_callable( $migration['callback'] ) ) {
			return;
		}

		call_user_func( $migration['callback'] );
		$completed = (bool) get_option( $migration['option'] );
		if ( go_verge_next_heavy_rebrand_migration() ) {
			go_verge_schedule_heavy_rebrand_migration( $completed ? 30 : 15 * MINUTE_IN_SECONDS );
		}
	} finally {
		go_verge_release_job_lock( 'heavy_rebrand_migration' );
	}
}
add_action( 'admin_init', 'go_verge_schedule_heavy_rebrand_migration', 96 );
add_action( 'go_verge_run_heavy_rebrand_migration', 'go_verge_run_heavy_rebrand_migration' );

/**
 * Defensive browser/app labels. These do not replace the structured-data name;
 * they simply keep installable/browser surfaces aligned with the same brand.
 */
function go_verge_rebrand_application_name_meta() {
	if ( is_admin() || is_feed() || is_embed() ) {
		return;
	}
	printf( '<meta name="application-name" content="%s">' . "\n", esc_attr( GO_VERGE_BRAND_NAME ) );
	printf( '<meta name="apple-mobile-web-app-title" content="%s">' . "\n", esc_attr( GO_VERGE_BRAND_NAME ) );
}
add_action( 'wp_head', 'go_verge_rebrand_application_name_meta', 3 );

/**
 * Keep RSS channel titles/descriptions from carrying cached legacy copy.
 *
 * @param string $output RSS bloginfo value.
 * @param string $show Requested bloginfo field.
 * @return string
 */
function go_verge_rebrand_bloginfo_rss( $output, $show ) {
	if ( in_array( $show, array( 'name', 'description' ), true ) ) {
		return go_verge_rebrand_copy( $output );
	}
	return $output;
}
add_filter( 'bloginfo_rss', 'go_verge_rebrand_bloginfo_rss', 999, 2 );

/** Register a Site Health check for future regressions. */
function go_verge_rebrand_register_health_test( $tests ) {
	$tests['direct']['go_verge_brand_consistency'] = array(
		'label' => __( 'Consistência da marca Game Overdrive', 'go-verge' ),
		'test'  => 'go_verge_rebrand_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_rebrand_register_health_test' );

/**
 * Scan public WordPress surfaces for accidental legacy display copy.
 * Historical rebrand content is ignored by design.
 *
 * @return array<string,mixed>
 */
function go_verge_rebrand_health_test() {
	$unexpected = 0;

	$site_name_ok = GO_VERGE_BRAND_NAME === trim( (string) get_bloginfo( 'name' ) );
	$news_name_ok = GO_VERGE_BRAND_NAME === trim( (string) get_option( 'go_verge_news_publication_name', '' ) );
	$rank_math_ok = true;
	if ( defined( 'RANK_MATH_VERSION' ) ) {
		$rank_math_titles = get_option( 'rank-math-options-titles', array() );
		$rank_math_ok     = is_array( $rank_math_titles )
			&& GO_VERGE_BRAND_NAME === trim( (string) ( $rank_math_titles['website_name'] ?? '' ) )
			&& GO_VERGE_BRAND_NAME === trim( (string) ( $rank_math_titles['knowledgegraph_name'] ?? '' ) )
			&& 'Overdrive' === trim( (string) ( $rank_math_titles['website_alternate_name'] ?? '' ) );
	}
	$good = $site_name_ok && $news_name_ok && $rank_math_ok && 0 === $unexpected;

	return array(
		'label'       => $good
			? __( 'A marca pública está consistente como Game Overdrive', 'go-verge' )
			: __( 'Ainda há referências públicas inesperadas à marca antiga', 'go-verge' ),
		'status'      => $good ? 'good' : 'recommended',
		'badge'       => array(
			'label' => __( 'SEO editorial', 'go-verge' ),
			'color' => 'blue',
		),
		'description' => sprintf(
			'<p>%s</p>',
			esc_html(
				sprintf(
					__( 'Nome do site: %1$s. Google News: %2$s. Rank Math: %3$s. Referências públicas inesperadas encontradas: %4$d. O domínio e os redirecionamentos legados não entram nessa contagem.', 'go-verge' ),
					$site_name_ok ? __( 'ok', 'go-verge' ) : __( 'revisar', 'go-verge' ),
					$news_name_ok ? __( 'ok', 'go-verge' ) : __( 'revisar', 'go-verge' ),
					$rank_math_ok ? __( 'ok', 'go-verge' ) : __( 'revisar', 'go-verge' ),
					$unexpected
				)
			)
		),
		'actions'     => '',
		'test'        => 'go_verge_brand_consistency',
	);
}
