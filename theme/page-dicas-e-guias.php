<?php
/** Editorial Page hub. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$go_verge_page = get_queried_object();
$go_verge_title = $go_verge_page instanceof WP_Post ? $go_verge_page->post_title : get_the_title();
go_verge_render_editorial_hub_page(
	$go_verge_title,
	array( 'dicas-e-guias', 'guias', 'dicas', 'tutoriais' ),
	array( 'dica', 'guia', 'tutorial' ),
	__( 'Últimas publicações', 'go-verge' ),
	'',
	array(
		array(
			'label'  => __( 'Guia de troféus', 'go-verge' ),
			'slugs'  => array( 'guia-de-trofeus', 'guias-de-trofeus' ),
			'accent' => 'trophies',
		),
		array(
			'label'  => __( 'Códigos', 'go-verge' ),
			'slugs'  => array( 'codigos' ),
			'accent' => 'codes',
		),
	)
);
