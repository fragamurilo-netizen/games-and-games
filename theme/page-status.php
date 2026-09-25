<?php
/** Template Name: Status */
if ( ! defined( 'ABSPATH' ) ) { exit; }
get_header();
$services = function_exists( 'go_product_get_services' ) ? go_product_get_services() : array();
$labels   = array('operational'=>'Operacional','degraded'=>'Instabilidade','outage'=>'Indisponível','unknown'=>'Não verificado');
?>
<main id="primary" class="go-main">
	<div class="go-container go-pagehead">
		<?php go_verge_breadcrumbs(); ?>
		<h1 class="go-pagehead__title">Status</h1>
	</div>
	<section class="go-container go-section">
		<div class="go-service-grid">
			<?php foreach ( $services as $service ) :
				$status = $service['status'] ?? 'unknown';
				$checked = ! empty( $service['last_checked'] ) ? strtotime( $service['last_checked'] . ' UTC' ) : 0;
				?>
				<article class="go-service-card">
					<h2><?php echo esc_html( $service['name'] ); ?></h2>
					<span class="go-service-card__status is-<?php echo esc_attr( $status ); ?>"><?php echo esc_html( $labels[$status] ?? $labels['unknown'] ); ?></span>
					<?php if ( $checked ) : ?><p class="go-service-card__checked">Verificado <?php echo esc_html( human_time_diff( $checked, current_time( 'timestamp', true ) ) ); ?> atrás</p><?php endif; ?>
					<p><a href="<?php echo esc_url( $service['url'] ); ?>" target="_blank" rel="noopener noreferrer">Consultar fonte</a></p>
				</article>
			<?php endforeach; ?>
		</div>
		<?php if ( ! $services ) : ?><p class="go-product-empty">O painel de status ainda não está configurado.</p><?php endif; ?>
	</section>
</main>
<?php get_footer();
