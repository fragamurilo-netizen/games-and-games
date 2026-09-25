<?php
/**
 * /games/ editorial hub.
 *
 * Uses the same editorial-hub renderer as Entertainment and Technology so the
 * hero, filters, feed, sidebar and pagination stay consistent across pillars.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

go_verge_render_editorial_hub_page(
	__( 'Games', 'go-verge' ),
	array( 'games', 'jogos' ),
	array( 'game', 'jogo' ),
	__( 'Últimas publicações', 'go-verge' ),
	'games'
);
