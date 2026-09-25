<?php
/** Overdrive Multicolor v2: assets, editor palette and frontend presentation. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/** Isolate brand-specific presentation from legacy component selectors. */
function go_verge_multicolor_body_class( $classes ) {
	$classes[] = 'go-brand-multicolor';
	return $classes;
}
add_filter( 'body_class', 'go_verge_multicolor_body_class' );

function go_verge_multicolor_assets() {
	if ( is_admin() ) { return; }
	$rel = '/assets/css/overdrive-multicolor.css';
	wp_enqueue_style( 'go-verge-multicolor', GO_VERGE_URI . $rel, array( 'go-overdrive-375' ), go_verge_asset_version( $rel ) );
}
add_action( 'wp_enqueue_scripts', 'go_verge_multicolor_assets', 46010 );

/** Browser chrome colors; favicon markup is centralized in functions.php. */
function go_verge_multicolor_head() {
	echo '<meta name="theme-color" content="#111015">' . "\n";
	echo '<meta name="msapplication-TileColor" content="#111015">' . "\n";
}
add_action( 'wp_head', 'go_verge_multicolor_head', 3 );

/** The same approved palette is available to editors without changing saved posts. */
function go_verge_multicolor_editor_palette() {
	add_theme_support( 'editor-color-palette', array(
		array( 'name' => __( 'Carvão Overdrive', 'go-verge' ), 'slug' => 'overdrive-charcoal', 'color' => '#111015' ),
		array( 'name' => __( 'Violeta Overdrive', 'go-verge' ), 'slug' => 'overdrive-violet', 'color' => '#7900FF' ),
		array( 'name' => __( 'Magenta Overdrive', 'go-verge' ), 'slug' => 'overdrive-magenta', 'color' => '#F008E9' ),
		array( 'name' => __( 'Pêssego Overdrive', 'go-verge' ), 'slug' => 'overdrive-peach', 'color' => '#FFBC88' ),
		array( 'name' => __( 'Ciano Overdrive', 'go-verge' ), 'slug' => 'overdrive-cyan', 'color' => '#42E5F5' ),
		array( 'name' => __( 'Lavanda Overdrive', 'go-verge' ), 'slug' => 'overdrive-lavender', 'color' => '#C6A3FF' ),
		array( 'name' => __( 'Branco', 'go-verge' ), 'slug' => 'overdrive-white', 'color' => '#FFFFFF' ),
		array( 'name' => __( 'Papel', 'go-verge' ), 'slug' => 'overdrive-paper', 'color' => '#FAF8F6' ),
	) );
	add_editor_style( 'assets/css/overdrive-multicolor-editor.css' );
}
add_action( 'after_setup_theme', 'go_verge_multicolor_editor_palette', 100 );
