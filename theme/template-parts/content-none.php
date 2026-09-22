<?php
/**
 * Empty-state — no posts found.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<div class="go-container">
	<div class="go-empty">
		<?php if ( function_exists( 'go_verge_is_editorial_index' ) && go_verge_is_editorial_index() ) : ?>
        <h2 class="go-empty__title"><?php esc_html_e( 'Nenhuma publicação encontrada', 'go-verge' ); ?></h2>
        <?php else : ?>
        <h1 class="go-empty__title"><?php esc_html_e( 'Nenhuma história encontrada', 'go-verge' ); ?></h1>
        <?php endif; ?>
		<p><?php esc_html_e( 'Tente outro termo ou volte para a página inicial.', 'go-verge' ); ?></p>
		<?php get_search_form(); ?>
		<p style="margin-top:24px;">
			<a class="go-btn go-btn--outline-mint" href="<?php echo esc_url( home_url( '/' ) ); ?>"><?php esc_html_e( 'Voltar ao início', 'go-verge' ); ?></a>
		</p>
	</div>
</div>
