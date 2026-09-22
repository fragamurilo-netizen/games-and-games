<?php
/**
 * Comments: conversation-first layout with an accessible WordPress-native form.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( post_password_required() ) {
	return;
}

$go_comment_count = (int) get_comments_number();
$go_commenter     = wp_get_current_commenter();
$go_require_data  = (bool) get_option( 'require_name_email' );
$go_required      = $go_require_data ? ' required aria-required="true"' : '';
$go_required_mark = $go_require_data ? ' <span class="go-comments__required" aria-hidden="true">*</span>' : '';

$go_comment_fields = array(
	'author' => sprintf(
		'<p class="comment-form-author"><label for="author">%1$s%2$s</label><input id="author" name="author" type="text" value="%3$s" size="30" maxlength="245" autocomplete="name" placeholder="%4$s"%5$s></p>',
		esc_html__( 'Nome', 'go-verge' ),
		$go_required_mark,
		esc_attr( $go_commenter['comment_author'] ),
		esc_attr__( 'Como você quer aparecer', 'go-verge' ),
		$go_required
	),
	'email' => sprintf(
		'<p class="comment-form-email"><label for="go-comment-email">%1$s%2$s</label><input id="go-comment-email" name="email" type="email" value="%3$s" size="30" maxlength="100" autocomplete="email" placeholder="%4$s"%5$s></p>',
		esc_html__( 'E-mail', 'go-verge' ),
		$go_required_mark,
		esc_attr( $go_commenter['comment_author_email'] ),
		esc_attr__( 'Seu e-mail não será publicado', 'go-verge' ),
		$go_required
	),
);
?>

<section id="comments" class="go-comments" aria-labelledby="go-comments-heading">
	<header class="go-comments__head">
		<div>
			<h2 id="go-comments-heading" class="go-comments__title"><?php esc_html_e( 'Comentários', 'go-verge' ); ?></h2>
		</div>
		<?php if ( $go_comment_count > 0 ) : ?>
			<span class="go-comments__count" aria-label="<?php echo esc_attr( sprintf( _n( '%d comentário', '%d comentários', $go_comment_count, 'go-verge' ), $go_comment_count ) ); ?>"><?php echo esc_html( $go_comment_count ); ?></span>
		<?php endif; ?>
	</header>

	<?php if ( function_exists( 'go_verge_editorial_question' ) ) { go_verge_editorial_question( get_the_ID() ); } ?>

	<?php if ( comments_open() ) : ?>
		<div class="go-comments__composer">
			<?php
			comment_form(
				array(
					'fields'               => $go_comment_fields,
					'class_form'           => 'comment-form go-comments__form',
					'class_submit'         => 'go-btn go-btn--mint go-comments__submit',
					'title_reply'          => __( 'Deixe seu comentário', 'go-verge' ),
					'title_reply_to'       => __( 'Responder a %s', 'go-verge' ),
					'cancel_reply_link'    => __( 'Cancelar resposta', 'go-verge' ),
					'label_submit'         => __( 'Publicar comentário', 'go-verge' ),
					'comment_notes_before' => is_user_logged_in() ? '' : '<p class="comment-notes">' . esc_html__( 'Seu e-mail não será publicado. Campos com * são obrigatórios.', 'go-verge' ) . '</p>',
					'comment_notes_after'  => '',
					'logged_in_as'         => sprintf(
						'<p class="logged-in-as">%1$s <a href="%2$s">%3$s</a></p>',
						esc_html__( 'Comentando com sua conta.', 'go-verge' ),
						esc_url( wp_logout_url( get_permalink() ) ),
						esc_html__( 'Sair', 'go-verge' )
					),
					'must_log_in'          => sprintf(
						'<p class="must-log-in">%1$s <a href="%2$s">%3$s</a></p>',
						esc_html__( 'Você precisa entrar para comentar.', 'go-verge' ),
						esc_url( wp_login_url( get_permalink() ) ),
						esc_html__( 'Entrar', 'go-verge' )
					),
					'comment_field'        => '<p class="comment-form-comment"><label for="comment">' . esc_html__( 'Comentário', 'go-verge' ) . ' <span class="go-comments__required" aria-hidden="true">*</span></label><textarea id="comment" name="comment" cols="45" rows="7" maxlength="65525" required aria-required="true" placeholder="' . esc_attr__( 'Escreva seu comentário...', 'go-verge' ) . '"></textarea></p>',
			)
			);
			?>
		</div>
	<?php endif; ?>

	<?php if ( have_comments() ) : ?>
		<div class="go-comments__thread-head">
			<h3><?php esc_html_e( 'Na conversa', 'go-verge' ); ?></h3>
			<span><?php echo esc_html( sprintf( _n( '%d comentário', '%d comentários', $go_comment_count, 'go-verge' ), $go_comment_count ) ); ?></span>
		</div>

		<?php if ( $go_comment_count > 1 ) : ?>
			<?php $go_default_sort = ( 'desc' === strtolower( (string) get_option( 'comment_order' ) ) ) ? 'newest' : 'oldest'; ?>
			<div class="go-comments__sortbar" data-go-comments-sortbar role="group" aria-label="<?php esc_attr_e( 'Ordenar comentários', 'go-verge' ); ?>">
				<span class="go-comments__sortlabel"><?php esc_html_e( 'Ordenar por', 'go-verge' ); ?></span>
				<button type="button" class="go-comments__sortbtn<?php echo 'newest' === $go_default_sort ? ' is-active' : ''; ?>" data-go-comments-sort="newest" aria-pressed="<?php echo 'newest' === $go_default_sort ? 'true' : 'false'; ?>"><?php esc_html_e( 'Mais recentes', 'go-verge' ); ?></button>
				<button type="button" class="go-comments__sortbtn" data-go-comments-sort="likes" aria-pressed="false"><?php esc_html_e( 'Mais votados', 'go-verge' ); ?></button>
				<button type="button" class="go-comments__sortbtn<?php echo 'oldest' === $go_default_sort ? ' is-active' : ''; ?>" data-go-comments-sort="oldest" aria-pressed="<?php echo 'oldest' === $go_default_sort ? 'true' : 'false'; ?>"><?php esc_html_e( 'Mais antigos', 'go-verge' ); ?></button>
			</div>
		<?php endif; ?>

		<ol class="comment-list">
			<?php
			wp_list_comments(
				array(
					'style'       => 'ol',
					'short_ping'  => true,
					'avatar_size' => 36,
					'callback'    => function_exists( 'go_verge_comment_callback' ) ? 'go_verge_comment_callback' : null,
				)
			);
			?>
		</ol>

		<?php the_comments_pagination( array( 'class' => 'go-pagination' ) ); ?>
	<?php elseif ( comments_open() ) : ?>
		<div class="go-comments__empty">
			<strong><?php esc_html_e( 'Ainda sem comentários.', 'go-verge' ); ?></strong>
			<span><?php esc_html_e( 'Puxe o primeiro assunto.', 'go-verge' ); ?></span>
		</div>
	<?php endif; ?>

	<?php if ( ! comments_open() && $go_comment_count ) : ?>
		<p class="go-comments__closed"><?php esc_html_e( 'Os comentários estão encerrados.', 'go-verge' ); ?></p>
	<?php endif; ?>
</section>
