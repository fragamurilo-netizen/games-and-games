<?php
/**
 * Página comercial de parcerias: formatos, especificações e contato.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$mk      = go_verge_media_kit_data();
$formats = go_verge_partnership_formats();
?>
<main id="primary" class="go-main go-mk go-partners">

	<header class="go-container go-mk__section go-mk__head">
		<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>

		<span class="go-eyebrow go-mk__eyebrow"><?php esc_html_e( 'Comercial', 'go-verge' ); ?></span>

		<h1 class="go-mk__title"><?php esc_html_e( 'Anuncie no Overdrive', 'go-verge' ); ?></h1>

		<p class="go-mk__deck">
			<?php esc_html_e( 'Formatos publicitários, conteúdo patrocinado e cobertura de lançamentos no Overdrive. Propostas comerciais e envio de material de imprensa pelo e-mail abaixo.', 'go-verge' ); ?>
		</p>

		<div class="go-mk__actions">
			<a class="go-btn go-btn--mint" href="<?php echo esc_url( go_verge_commercial_mailto() ); ?>"><?php esc_html_e( 'Solicitar proposta', 'go-verge' ); ?></a>
			<a class="go-btn go-btn--outline-uv" href="<?php echo esc_url( home_url( '/midia-kit/' ) ); ?>"><?php esc_html_e( 'Perfil da audiência', 'go-verge' ); ?></a>
		</div>
	</header>

	<section class="go-container go-mk__section" aria-label="<?php esc_attr_e( 'Resumo da audiência', 'go-verge' ); ?>">
		<h2 class="go-mk__h2"><?php esc_html_e( 'Quem alcança', 'go-verge' ); ?></h2>
		<?php
		/*
		 * Só proporção aqui também: o volume de audiência vai no kit enviado
		 * por e-mail, onde dá para explicar o contexto do crescimento.
		 */
		?>
		<div class="go-mk-stats">
			<?php foreach ( $mk['destaques'] as $stat ) : ?>
				<?php go_verge_media_kit_stat( $stat['valor'], $stat['rotulo'] ); ?>
			<?php endforeach; ?>
		</div>
		<?php go_verge_media_kit_source(); ?>
	</section>

	<section class="go-container go-mk__section go-mk__section--rule">
		<h2 class="go-mk__h2"><?php esc_html_e( 'Formatos', 'go-verge' ); ?></h2>

		<div class="go-partners-grid">
			<?php foreach ( $formats as $format ) : ?>
				<article class="go-partners-card">
					<h3 class="go-partners-card__title"><?php echo esc_html( $format['nome'] ); ?></h3>
					<p class="go-partners-card__resumo"><?php echo esc_html( $format['resumo'] ); ?></p>
					<ul class="go-partners-card__list">
						<?php foreach ( $format['itens'] as $item ) : ?>
							<li><?php echo esc_html( $item ); ?></li>
						<?php endforeach; ?>
					</ul>
					<a class="go-btn go-btn--outline-uv go-partners-card__action" href="<?php echo esc_url( go_verge_commercial_mailto( $format['nome'] ) ); ?>"><?php echo esc_html( sprintf( __( 'Consultar %s', 'go-verge' ), $format['nome'] ) ); ?></a>
				</article>
			<?php endforeach; ?>
		</div>
	</section>

	<section class="go-container go-mk__section go-mk__section--rule">
		<h2 class="go-mk__h2"><?php esc_html_e( 'Especificações técnicas', 'go-verge' ); ?></h2>

		<div class="go-mk-table-wrap">
			<table class="go-mk-table">
				<caption class="screen-reader-text"><?php esc_html_e( 'Especificações dos formatos de display', 'go-verge' ); ?></caption>
				<thead>
					<tr>
						<th scope="col"><?php esc_html_e( 'Formato', 'go-verge' ); ?></th>
						<th scope="col"><?php esc_html_e( 'Dimensões', 'go-verge' ); ?></th>
						<th scope="col"><?php esc_html_e( 'Dispositivo', 'go-verge' ); ?></th>
						<th scope="col"><?php esc_html_e( 'Peso máx.', 'go-verge' ); ?></th>
					</tr>
				</thead>
				<tbody>
					<tr><th scope="row"><?php esc_html_e( 'Billboard', 'go-verge' ); ?></th><td>970×250</td><td><?php esc_html_e( 'Desktop', 'go-verge' ); ?></td><td>150 KB</td></tr>
					<tr><th scope="row"><?php esc_html_e( 'Leaderboard', 'go-verge' ); ?></th><td>728×90</td><td><?php esc_html_e( 'Desktop', 'go-verge' ); ?></td><td>100 KB</td></tr>
					<tr><th scope="row"><?php esc_html_e( 'Retângulo', 'go-verge' ); ?></th><td>300×250</td><td><?php esc_html_e( 'Desktop e mobile', 'go-verge' ); ?></td><td>100 KB</td></tr>
					<tr><th scope="row"><?php esc_html_e( 'Half-page', 'go-verge' ); ?></th><td>300×600</td><td><?php esc_html_e( 'Desktop', 'go-verge' ); ?></td><td>150 KB</td></tr>
					<tr><th scope="row"><?php esc_html_e( 'Banner mobile', 'go-verge' ); ?></th><td>320×50 · 320×100</td><td><?php esc_html_e( 'Mobile', 'go-verge' ); ?></td><td>80 KB</td></tr>
				</tbody>
			</table>
		</div>
		<p class="go-mk-source"><?php esc_html_e( 'Dimensões de referência, sujeitas à disponibilidade e à aprovação técnica. Confirme o formato na proposta antes de produzir o material. Arquivos aceitos: JPG, PNG, GIF e HTML5. Envio com no mínimo 3 dias úteis de antecedência.', 'go-verge' ); ?></p>
	</section>

	<section class="go-container go-mk__section go-mk__section--rule">
		<div class="go-mk-cta">
			<div>
				<h2 class="go-mk__h2"><?php esc_html_e( 'Contato comercial', 'go-verge' ); ?></h2>
				<p>
					<?php esc_html_e( 'Envie marca, objetivo da campanha, período e formatos de interesse. O botão abre seu aplicativo de e-mail com um roteiro para preencher. Disponibilidade, valores e condições serão confirmados na proposta.', 'go-verge' ); ?>
					<?php
					/*
					 * As regras de conteúdo pago ficam onde já estavam
					 * documentadas, a um clique daqui.
					 */
					printf(
						/* translators: %s: link para a política editorial. */
						' ' . esc_html__( 'Regras de conteúdo pago na %s.', 'go-verge' ),
						'<a href="' . esc_url( home_url( '/politica-editorial/' ) ) . '">' . esc_html__( 'Política Editorial', 'go-verge' ) . '</a>'
					);
					?>
				</p>
			</div>
			<div class="go-mk-cta__actions">
				<a class="go-btn go-btn--mint" href="<?php echo esc_url( go_verge_commercial_mailto() ); ?>"><?php esc_html_e( 'Solicitar proposta', 'go-verge' ); ?></a>
				<a class="go-btn go-btn--outline-uv" href="<?php echo esc_url( home_url( '/midia-kit/' ) ); ?>"><?php esc_html_e( 'Mídia kit', 'go-verge' ); ?></a>
			</div>
		</div>
		<p class="go-mk-source"><?php esc_html_e( 'Prefere escrever diretamente?', 'go-verge' ); ?> <a href="<?php echo esc_url( 'mailto:' . go_verge_commercial_email() ); ?>"><?php echo esc_html( go_verge_commercial_email() ); ?></a></p>
	</section>

</main>
<?php get_footer(); ?>
