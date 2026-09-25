<?php
/**
 * Reusable search form.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
$go_search_field_id = wp_unique_id( 'go-s-' );
?>
<form role="search" method="get" class="go-searchform" action="<?php echo esc_url( home_url( '/' ) ); ?>">
	<label class="screen-reader-text" for="<?php echo esc_attr( $go_search_field_id ); ?>"><?php esc_html_e( 'Buscar por:', 'go-verge' ); ?></label>
	<input type="search" id="<?php echo esc_attr( $go_search_field_id ); ?>" class="go-searchform__input" name="s" value="<?php echo esc_attr( get_search_query() ); ?>" placeholder="<?php esc_attr_e( 'Jogos, notícias, autores…', 'go-verge' ); ?>">
	<button type="submit" class="go-btn go-btn--mint"><?php esc_html_e( 'Buscar', 'go-verge' ); ?></button>
</form>
