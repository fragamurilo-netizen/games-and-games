<?php
/** Editorial Page hub. @package go-verge */
if ( ! defined( 'ABSPATH' ) ) { exit; }
$go_verge_page = get_queried_object();
$go_verge_title = $go_verge_page instanceof WP_Post ? $go_verge_page->post_title : get_the_title();
go_verge_render_editorial_hub_page(
	$go_verge_title,
	array( 'entretenimento', 'noticias-de-entretenimento', 'noticias-entretenimento', 'series', 'filmes', 'streaming', 'animes', 'anime', 'mangas-e-quadrinhos', 'manga-e-quadrinhos', 'mangas', 'manga', 'quadrinhos', 'hqs', 'comics' ),
	array( 'entreten', 'noticias-entretenimento', 'serie', 'filme', 'streaming', 'anime', 'manga', 'quadrinho', 'comic' ),
	__( 'Últimas publicações', 'go-verge' ),
	'entertainment'
);
