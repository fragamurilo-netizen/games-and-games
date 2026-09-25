<?php
/**
 * Portable custom post types + taxonomies.
 *
 * These were originally registered inside the news-magazine-x theme
 * (more-functions.php, go-editorial-hub.php, go-editorial-extensions.php).
 * Because they live in the theme rather than a plugin, switching themes would
 * make `games`, `go_entity` and `go_promotion` content unreachable. We re-register
 * them here — each guarded so it never conflicts if the old theme (or a future
 * plugin) already registered them.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * games — the game database CPT (archive slug: /games/).
 */
function go_verge_register_games_cpt() {
	if ( post_type_exists( 'games' ) ) {
		return;
	}

	register_post_type( 'games', array(
		'labels'             => array(
			'name'          => __( 'Games', 'go-verge' ),
			'singular_name' => __( 'Game', 'go-verge' ),
			'menu_name'     => __( 'Games', 'go-verge' ),
			'all_items'     => __( 'Todos os games', 'go-verge' ),
			'add_new_item'  => __( 'Adicionar novo game', 'go-verge' ),
			'edit_item'     => __( 'Editar game', 'go-verge' ),
			'search_items'  => __( 'Buscar games', 'go-verge' ),
		),
		'public'             => true,
		'show_ui'            => true,
		'show_in_menu'       => true,
		'show_in_rest'       => true,
		'menu_position'      => 21,
		'menu_icon'          => 'dashicons-games',
		'supports'           => array( 'title', 'editor', 'thumbnail', 'excerpt', 'author', 'revisions' ),
		'taxonomies'         => array( 'post_tag' ),
		'has_archive'        => true,
		'rewrite'            => array( 'slug' => 'games' ),
		'publicly_queryable' => true,
		'capability_type'    => 'post',
	) );
}
add_action( 'init', 'go_verge_register_games_cpt', 9 );

/**
 * game_status — light taxonomy on games (played / playing / backlog / wishlist).
 * Terms already exist in the DB; registering keeps them queryable.
 */
function go_verge_register_game_status_tax() {
	if ( taxonomy_exists( 'game_status' ) ) {
		return;
	}

	register_taxonomy( 'game_status', array( 'games' ), array(
		'labels'            => array(
			'name'          => __( 'Status do game', 'go-verge' ),
			'singular_name' => __( 'Status', 'go-verge' ),
		),
		'public'            => false,
		'show_ui'           => true,
		'show_admin_column' => true,
		'hierarchical'      => false,
		'rewrite'           => false,
	) );
}
add_action( 'init', 'go_verge_register_game_status_tax', 9 );

/**
 * go_entity — editorial entities: platforms, developers, publishers, companies…
 * (archive slug: /universo/), with the go_entity_type taxonomy (slug: /tipo-entidade/).
 */
function go_verge_register_entities() {
	if ( ! post_type_exists( 'go_entity' ) ) {
		register_post_type( 'go_entity', array(
			'labels'       => array(
				'name'               => __( 'Entidades', 'go-verge' ),
				'singular_name'      => __( 'Entidade', 'go-verge' ),
				'menu_name'          => __( 'Entidades', 'go-verge' ),
				'all_items'          => __( 'Todas as entidades', 'go-verge' ),
				'add_new'            => __( 'Adicionar entidade', 'go-verge' ),
				'add_new_item'       => __( 'Adicionar nova entidade', 'go-verge' ),
				'edit_item'          => __( 'Editar entidade', 'go-verge' ),
				'new_item'           => __( 'Nova entidade', 'go-verge' ),
				'view_item'          => __( 'Ver entidade', 'go-verge' ),
				'search_items'       => __( 'Buscar entidades', 'go-verge' ),
				'not_found'          => __( 'Nenhuma entidade encontrada.', 'go-verge' ),
				'not_found_in_trash' => __( 'Nenhuma entidade na lixeira.', 'go-verge' ),
			),
			'public'        => true,
			'show_in_rest'  => true,
			'show_in_menu'  => true,
			'menu_position' => 23,
			'menu_icon'     => 'dashicons-networking',
			'supports'      => array( 'title', 'editor', 'excerpt', 'thumbnail', 'page-attributes' ),
			'has_archive'   => true,
			'hierarchical'  => true,
			'rewrite'       => array( 'slug' => 'universo' ),
		) );
	}

	if ( ! taxonomy_exists( 'go_entity_type' ) ) {
		register_taxonomy( 'go_entity_type', 'go_entity', array(
			'labels'            => array(
				'name'          => __( 'Tipos de entidade', 'go-verge' ),
				'singular_name' => __( 'Tipo de entidade', 'go-verge' ),
			),
			'public'             => false,
			'publicly_queryable' => false,
			'show_ui'            => true,
			'hierarchical'       => true,
			'show_admin_column'  => true,
			'show_in_rest'       => true,
			'show_in_nav_menus'  => false,
			'rewrite'            => false,
		) );
	}
}
add_action( 'init', 'go_verge_register_entities', 9 );

/**
 * go_promotion — deals / promotions CPT (archive slug: /promocoes/).
 */
function go_verge_register_promotions() {
	if ( post_type_exists( 'go_promotion' ) ) {
		return;
	}

	register_post_type( 'go_promotion', array(
		'labels'       => array(
			'name'          => __( 'Promoções', 'go-verge' ),
			'singular_name' => __( 'Promoção', 'go-verge' ),
			'all_items'     => __( 'Promoções', 'go-verge' ),
			'add_new_item'  => __( 'Adicionar promoção', 'go-verge' ),
			'edit_item'     => __( 'Editar promoção', 'go-verge' ),
		),
		'public'       => true,
		'show_in_rest' => true,
		'has_archive'  => true,
		'show_in_menu' => 'edit.php?post_type=games',
		'menu_icon'    => 'dashicons-megaphone',
		'rewrite'      => array( 'slug' => 'promocoes' ),
		'supports'     => array( 'title', 'editor', 'excerpt', 'thumbnail', 'page-attributes' ),
	) );
}
add_action( 'init', 'go_verge_register_promotions', 9 );

/**
 * One-time rewrite flush after activation so the ported CPT archives resolve.
 */
function go_verge_flush_rewrites() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) || get_option( 'go_verge_rewrites_flushed' ) === GO_VERGE_VERSION ) {
		return;
	}
	go_verge_flush_rewrite_rules_once_per_request();
	update_option( 'go_verge_rewrites_flushed', GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_flush_rewrites', 99 );

/**
 * Drop the flush flag on switch so the next load rebuilds rules.
 */
function go_verge_reset_rewrite_flag() {
	delete_option( 'go_verge_rewrites_flushed' );
}
add_action( 'after_switch_theme', 'go_verge_reset_rewrite_flag' );
