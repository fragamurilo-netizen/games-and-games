<?php
/**
 * Mídia kit público, montado a partir dos dados de inc/media-kit.php.
 *
 * A estrutura segue o que portais brasileiros publicam nessas páginas:
 * audiência em números redondos, perfil do público, editorias, formatos e
 * contato. Métrica interna de analytics e diagnóstico de SEO ficam de fora.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$mk = go_verge_media_kit_data();
?>
<main id="primary" class="go-main go-mk">

	<header class="go-container go-mk__section go-mk__head">
		<?php if ( function_exists( 'go_verge_breadcrumbs' ) ) { go_verge_breadcrumbs(); } ?>

		<span class="go-eyebrow go-mk__eyebrow"><?php esc_html_e( 'Mídia kit', 'go-verge' ); ?> · <?php echo esc_html( $mk['atualizado_em'] ); ?></span>

		<h1 class="go-mk__title"><?php esc_html_e( 'Overdrive', 'go-verge' ); ?></h1>

		<p class="go-mk__deck">
			<?php esc_html_e( 'Portal brasileiro de games, entretenimento e tecnologia. Publica notícias, reviews, guias e cobertura de jogos, séries, filmes, streaming e tecnologia.', 'go-verge' ); ?>
		</p>

		<div class="go-mk__actions">
			<a class="go-btn go-btn--mint" href="<?php echo esc_url( go_verge_commercial_mailto( 'Mídia kit' ) ); ?>"><?php esc_html_e( 'Receber o mídia kit completo', 'go-verge' ); ?></a>
			<a class="go-btn go-btn--outline-uv" href="<?php echo esc_url( home_url( '/parcerias/' ) ); ?>"><?php esc_html_e( 'Formatos comerciais', 'go-verge' ); ?></a>
		</div>
	</header>

	<section class="go-container go-mk__section" aria-label="<?php esc_attr_e( 'Perfil da audiência', 'go-verge' ); ?>">
		<h2 class="go-mk__h2"><?php esc_html_e( 'Quem lê o Overdrive', 'go-verge' ); ?></h2>

		<div class="go-mk-stats">
			<?php foreach ( $mk['destaques'] as $stat ) : ?>
				<?php go_verge_media_kit_stat( $stat['valor'], $stat['rotulo'] ); ?>
			<?php endforeach; ?>
		</div>

		<?php go_verge_media_kit_source(); ?>
	</section>

	<?php if ( ! empty( $mk['redes'] ) ) : ?>
		<section class="go-container go-mk__section go-mk__section--rule">
			<h2 class="go-mk__h2"><?php esc_html_e( 'Redes sociais', 'go-verge' ); ?></h2>
			<div class="go-mk-stats">
				<?php foreach ( $mk['redes'] as $rede ) : ?>
					<?php go_verge_media_kit_stat( $rede[1], $rede[0] ); ?>
				<?php endforeach; ?>
			</div>
		</section>
	<?php endif; ?>

	<section class="go-container go-mk__section go-mk__section--rule">
		<h2 class="go-mk__h2"><?php esc_html_e( 'Perfil do público', 'go-verge' ); ?></h2>

		<div class="go-mk-grid go-mk-grid--3">

			<div class="go-mk-card">
				<h3 class="go-mk-card__title"><?php esc_html_e( 'Gênero', 'go-verge' ); ?></h3>
				<ul class="go-mk-bars">
					<?php
					foreach ( $mk['genero'] as $g ) {
						go_verge_media_kit_bar( $g[0], $g[1], (float) str_replace( ',', '.', rtrim( $g[1], '%' ) ) );
					}
					?>
				</ul>
			</div>

			<div class="go-mk-card">
				<h3 class="go-mk-card__title"><?php esc_html_e( 'Faixa etária', 'go-verge' ); ?></h3>
				<ul class="go-mk-bars">
					<?php
					foreach ( $mk['idade'] as $faixa ) {
						go_verge_media_kit_bar( $faixa[0], $faixa[1], (float) str_replace( ',', '.', rtrim( $faixa[1], '%' ) ) * 2.6 );
					}
					?>
				</ul>
			</div>

			<div class="go-mk-card">
				<h3 class="go-mk-card__title"><?php esc_html_e( 'Dispositivo', 'go-verge' ); ?></h3>
				<ul class="go-mk-bars">
					<?php
					foreach ( $mk['dispositivos'] as $device ) {
						go_verge_media_kit_bar( $device[0], $device[1], (float) str_replace( ',', '.', rtrim( $device[1], '%' ) ) );
					}
					?>
				</ul>
				<p class="go-mk-card__foot">
					<?php
					$sistemas = array();
					foreach ( $mk['sistemas'] as $so ) {
						$sistemas[] = $so[0] . ' ' . $so[1];
					}
					echo esc_html( sprintf( __( 'Sistemas: %s.', 'go-verge' ), implode( ' · ', $sistemas ) ) );
					?>
				</p>
			</div>

			<div class="go-mk-card">
				<h3 class="go-mk-card__title"><?php esc_html_e( 'Principais praças', 'go-verge' ); ?></h3>
				<ul class="go-mk-list">
					<?php foreach ( $mk['geografia']['cidades'] as $cidade ) : ?>
						<li><span><?php echo esc_html( $cidade[0] ); ?></span><span><?php echo esc_html( $cidade[1] ); ?></span></li>
					<?php endforeach; ?>
				</ul>
				<p class="go-mk-card__foot"><?php echo esc_html( sprintf( __( 'Participação sobre o total. %s da audiência está no Brasil.', 'go-verge' ), $mk['geografia']['brasil_share'] ) ); ?></p>
			</div>

			<div class="go-mk-card">
				<h3 class="go-mk-card__title"><?php esc_html_e( 'Leitura', 'go-verge' ); ?></h3>
				<p class="go-mk-card__hero">
					<strong><?php echo esc_html( $mk['engajamento']['tempo_medio'] ); ?></strong>
					<span><?php esc_html_e( 'por usuário ativo', 'go-verge' ); ?></span>
				</p>
				<p class="go-mk-card__foot"><?php esc_html_e( 'Tempo médio de engajamento por usuário ativo.', 'go-verge' ); ?></p>
			</div>

		</div>

		<?php go_verge_media_kit_source(); ?>
		<p class="go-mk-source"><?php esc_html_e( 'Gênero e faixa etária consideram apenas a parcela da audiência classificada pelo Google Analytics.', 'go-verge' ); ?></p>
	</section>

	<section class="go-container go-mk__section go-mk__section--rule">
		<h2 class="go-mk__h2"><?php esc_html_e( 'Editorias', 'go-verge' ); ?></h2>
		<div class="go-mk-editorias">
			<?php foreach ( $mk['editorias'] as $ed ) : ?>
				<article class="go-mk-editoria">
					<h3><?php echo esc_html( $ed['nome'] ); ?></h3>
					<p><?php echo esc_html( $ed['desc'] ); ?></p>
				</article>
			<?php endforeach; ?>
		</div>
	</section>

	<section class="go-container go-mk__section go-mk__section--rule">
		<div class="go-mk-cta">
			<div>
				<h2 class="go-mk__h2"><?php esc_html_e( 'Mídia kit completo', 'go-verge' ); ?></h2>
				<p><?php esc_html_e( 'Números de audiência e disponibilidade de formatos por e-mail.', 'go-verge' ); ?></p>
			</div>
			<div class="go-mk-cta__actions">
				<a class="go-btn go-btn--mint" href="<?php echo esc_url( go_verge_commercial_mailto( 'Mídia kit' ) ); ?>"><?php esc_html_e( 'Solicitar o mídia kit', 'go-verge' ); ?></a>
				<a class="go-btn go-btn--outline-uv" href="<?php echo esc_url( home_url( '/parcerias/' ) ); ?>"><?php esc_html_e( 'Ver formatos', 'go-verge' ); ?></a>
			</div>
		</div>
	</section>

</main>
<?php get_footer(); ?>
