<?php
/**
 * Template Name: Preferências da newsletter
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$segments = function_exists( 'go_product_newsletter_segments' )
	? go_product_newsletter_segments()
	: array(
		'diario'        => 'Resumo diário',
		'promocoes'     => 'Promoções',
		'playstation'   => 'PlayStation',
		'xbox'          => 'Xbox',
		'nintendo'      => 'Nintendo',
		'pc'            => 'PC',
		'entretenimento'=> 'Entretenimento',
		'tecnologia'    => 'Tecnologia',
	);

?>

<main id="primary" class="go-main go-newsletter-preferences-page">
	<section class="go-container go-newsletter-preferences" aria-labelledby="go-newsletter-preferences-title">
		<div class="go-newsletter-preferences__intro">
			<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>
			<h1 id="go-newsletter-preferences-title" class="go-newsletter-preferences__title">Preferências da newsletter</h1>
		</div>

		<div class="go-newsletter-preferences__layout">
			<form class="go-preferences-form go-preferences-card" data-go-newsletter-preferences>

				<label class="go-form-field" for="go-newsletter-preferences-email">
					<span class="go-form-field__label">Seu e-mail</span>
					<input id="go-newsletter-preferences-email" type="email" name="email" required autocomplete="email" inputmode="email" placeholder="voce@exemplo.com">
				</label>

				<fieldset class="go-preferences-card__fieldset">
					<legend>Assuntos que você quer acompanhar</legend>
					<div class="go-preference-grid">
						<?php foreach ( $segments as $key => $label ) :
							$key = sanitize_key( $key );
							$input_id = 'go-newsletter-segment-' . $key;
							?>
							<label class="go-preference-option" for="<?php echo esc_attr( $input_id ); ?>">
								<input id="<?php echo esc_attr( $input_id ); ?>" type="checkbox" name="segments[]" value="<?php echo esc_attr( $key ); ?>">
								<span class="go-preference-option__check" aria-hidden="true"></span>
								<span class="go-preference-option__copy">
									<strong><?php echo esc_html( $label ); ?></strong>
								</span>
							</label>
						<?php endforeach; ?>
					</div>
				</fieldset>

				<label class="go-preferences-consent go-check" for="go-newsletter-preferences-consent">
					<input id="go-newsletter-preferences-consent" type="checkbox" name="consent" value="1" required>
					<span class="go-preferences-consent__check" aria-hidden="true"></span>
					<span>Aceito receber a newsletter do Overdrive.</span>
				</label>

				<div class="go-preferences-card__actions">
					<button class="go-btn go-btn--mint go-preferences-submit" type="submit">
						<span data-go-preferences-submit-label>Salvar preferências</span>
					</button>
					<p class="go-preferences-status" data-go-preferences-status aria-live="polite" aria-atomic="true"></p>
				</div>
			</form>
		</div>
	</section>
</main>

<?php get_footer(); ?>
