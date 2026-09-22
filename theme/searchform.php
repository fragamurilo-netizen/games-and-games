<?php
/**
 * Reusable search form.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<form role="search" method="get" class="go-searchform" action="<?php echo esc_url( home_url( '/' ) ); ?>">
	<label class="screen-reader-text" for="go-s"><?php esc_html_e( 'Buscar por:', 'go-verge' ); ?></label>
	<input type="search" id="go-s" class="go-searchform__input" name="s" value="<?php echo esc_attr( get_search_query() ); ?>" placeholder="<?php esc_attr_e( 'Jogos, notícias, autores…', 'go-verge' ); ?>">
	<button type="submit" class="go-btn go-btn--mint"><?php esc_html_e( 'Buscar', 'go-verge' ); ?></button>
</form>
