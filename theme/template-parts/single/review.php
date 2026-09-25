<?php
/** Premium review summary: only editorially stored judgments and facts. */
if ( ! defined( 'ABSPATH' ) || empty( $args['post_id'] ) || empty( $args['review_data']['has_review'] ) ) { return; }
$c = $args;
$d = $c['review_data'];
$specs = go_verge_review_spec_rows( $d );
$summary = trim( (string) $d['summary'] );
$verdict = trim( (string) $d['verdict'] );
if ( $verdict && go_verge_review_copy_is_duplicate( $summary, $verdict ) ) { $summary = ''; }
$disclosure = go_verge_review_copy_disclosure_text( $c['post_id'] );
?>
<section class="od-review" id="od-review-verdict" aria-labelledby="od-review-title">
	<header class="od-review__head">
		<div><h2 id="od-review-title"><?php esc_html_e( 'Veredito', 'go-verge' ); ?></h2><?php $work = $c['is_critique'] ? $c['work_name'] : $c['review_game_name']; if ( $work ) : ?><p class="od-review__work"><?php echo esc_html( $work ); ?></p><?php endif; ?></div>
		<?php if ( '' !== $c['score_label'] ) : ?><div class="od-review__score" aria-label="<?php echo esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $c['score_label'] ) ); ?>"><strong><?php echo esc_html( $c['score_label'] ); ?></strong><span>/10</span></div><?php endif; ?>
	</header>
	<?php if ( $verdict ) : ?><p class="od-review__verdict"><?php echo esc_html( $verdict ); ?></p><?php endif; ?>
	<?php if ( $summary ) : ?><p class="od-review__summary"><?php echo esc_html( $summary ); ?></p><?php endif; ?>
	<?php if ( $d['pros'] || $d['cons'] ) : ?>
		<div class="od-review__balance">
			<?php foreach ( array( 'pros' => __( 'Pontos positivos', 'go-verge' ), 'cons' => __( 'Pontos negativos', 'go-verge' ) ) as $key => $label ) : if ( empty( $d[ $key ] ) ) { continue; } ?>
				<div class="od-review__<?php echo esc_attr( $key ); ?>"><h3><?php echo esc_html( $label ); ?></h3><ul><?php foreach ( $d[ $key ] as $line ) : ?><li><?php echo esc_html( $line ); ?></li><?php endforeach; ?></ul></div>
			<?php endforeach; ?>
		</div>
	<?php endif; ?>
	<?php if ( $specs ) : ?>
		<details class="od-review__facts" open>
			<summary><?php esc_html_e( 'Ficha técnica', 'go-verge' ); ?><?php echo go_verge_icon( 'seta-direita' ); ?></summary>
			<dl><?php foreach ( $specs as $label => $value ) : ?><div><dt><?php echo esc_html( $label ); ?></dt><dd><?php echo wp_kses_post( $value ); ?></dd></div><?php endforeach; ?></dl>
		</details>
	<?php endif; ?>
	<?php if ( $d['metacritic'] || $d['opencritic'] ) : ?><div class="od-review__external"><?php if ( $d['metacritic'] ) : ?><span>Metacritic <strong><?php echo esc_html( $d['metacritic'] ); ?></strong></span><?php endif; ?><?php if ( $d['opencritic'] ) : ?><span>OpenCritic <strong><?php echo esc_html( $d['opencritic'] ); ?></strong></span><?php endif; ?></div><?php endif; ?>
	<?php if ( $d['reviewer'] ) : ?><p class="od-review__credit"><?php esc_html_e( 'Análise por', 'go-verge' ); ?> <strong><?php echo esc_html( $d['reviewer'] ); ?></strong></p><?php endif; ?>
	<?php if ( $disclosure ) : ?><p class="od-review__disclosure"><?php echo esc_html( $disclosure ); ?></p><?php endif; ?>
</section>
