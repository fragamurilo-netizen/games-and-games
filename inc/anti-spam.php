<?php
/**
 * Comment anti-spam — no external plugin, no CAPTCHA friction.
 *
 * Layered heuristics that stop automated / fake-account spam:
 *   1. Honeypot field bots fill and humans never see.
 *   2. Signed time-trap: real readers take more than a few seconds to comment.
 *   3. Link cap + author-name-as-URL rejection (classic SEO spam shape).
 *   4. The comment "website" field — a pure spam magnet — is removed.
 *   5. Trackbacks/pingbacks that slip through are rejected.
 *
 * Trusted moderators bypass every check.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * A per-render signed timestamp token so we can measure submit latency and
 * reject direct POSTs that never loaded the form.
 *
 * @return array{ts:int,sig:string}
 */
function go_verge_antispam_token() {
	$ts  = time();
	$sig = hash_hmac( 'sha256', (string) $ts, wp_salt( 'nonce' ) );
	return array( 'ts' => $ts, 'sig' => $sig );
}

/**
 * Remove the "website"/URL field — the single biggest comment-spam incentive.
 *
 * @param array $fields Default comment fields.
 * @return array
 */
function go_verge_antispam_remove_url_field( $fields ) {
	unset( $fields['url'] );
	return $fields;
}
add_filter( 'comment_form_default_fields', 'go_verge_antispam_remove_url_field' );

/**
 * Inject the honeypot + signed time-trap into every comment form.
 */
function go_verge_antispam_fields() {
	$token = go_verge_antispam_token();
	?>
	<input type="hidden" name="go_ct" value="<?php echo esc_attr( $token['ts'] ); ?>">
	<input type="hidden" name="go_ct_sig" value="<?php echo esc_attr( $token['sig'] ); ?>">
	<p class="go-hp-field" style="position:absolute!important;left:-9999px!important;top:-9999px!important;height:1px;width:1px;overflow:hidden;" aria-hidden="true">
		<label for="go_hp_url"><?php esc_html_e( 'Deixe este campo em branco', 'go-verge' ); ?></label>
		<input type="text" id="go_hp_url" name="go_hp_url" value="" tabindex="-1" autocomplete="off">
	</p>
	<?php
}
add_action( 'comment_form_after_fields', 'go_verge_antispam_fields' );
add_action( 'comment_form_logged_in_after', 'go_verge_antispam_fields' );

/**
 * Gatekeeper: validate every incoming comment before WordPress stores it.
 *
 * @param array $commentdata Prepared comment data.
 * @return array
 */
function go_verge_antispam_check( $commentdata ) {
	// Trusted moderators are exempt.
	if ( is_user_logged_in() && current_user_can( 'moderate_comments' ) ) {
		return $commentdata;
	}

	// Only guard human comments; reject any trackback/pingback that slips in.
	$type = isset( $commentdata['comment_type'] ) ? $commentdata['comment_type'] : '';
	if ( '' !== $type && 'comment' !== $type ) {
		go_verge_antispam_reject();
	}

	// 1) Honeypot must be empty.
	if ( ! empty( $_POST['go_hp_url'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Missing
		go_verge_antispam_reject();
	}

	// 2) Signed time-trap: token must exist, verify, and be at least 4s old.
	$ts  = isset( $_POST['go_ct'] ) ? absint( wp_unslash( $_POST['go_ct'] ) ) : 0; // phpcs:ignore WordPress.Security.NonceVerification.Missing
	$sig = isset( $_POST['go_ct_sig'] ) ? sanitize_text_field( wp_unslash( $_POST['go_ct_sig'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Missing
	$expected = hash_hmac( 'sha256', (string) $ts, wp_salt( 'nonce' ) );
	if ( ! $ts || '' === $sig || ! hash_equals( $expected, $sig ) ) {
		go_verge_antispam_reject();
	}
	if ( ( time() - $ts ) < 4 ) {
		go_verge_antispam_reject( __( 'Aguarde alguns segundos e envie o comentário novamente.', 'go-verge' ) );
	}

	$content = isset( $commentdata['comment_content'] ) ? (string) $commentdata['comment_content'] : '';
	$author  = isset( $commentdata['comment_author'] ) ? (string) $commentdata['comment_author'] : '';

	// 3) Content sanity + link cap.
	if ( mb_strlen( trim( wp_strip_all_tags( $content ) ) ) < 2 ) {
		go_verge_antispam_reject();
	}
	$link_count = preg_match_all( '#\b(?:https?://|www\.)#i', $content, $ignored )
		+ preg_match_all( '#\[url[=\]]#i', $content, $ignored2 )
		+ preg_match_all( '#<a\s#i', $content, $ignored3 );
	if ( $link_count > 2 ) {
		go_verge_antispam_reject( __( 'Comentários com muitos links não são permitidos.', 'go-verge' ) );
	}

	// 4) Author name must not be a URL or contain markup.
	if ( preg_match( '#https?://|www\.|<a\s#i', $author ) ) {
		go_verge_antispam_reject();
	}

	return $commentdata;
}
add_filter( 'preprocess_comment', 'go_verge_antispam_check', 5 );

/**
 * Reject a submission cleanly.
 *
 * @param string $message Optional human-facing message.
 */
function go_verge_antispam_reject( $message = '' ) {
	if ( '' === $message ) {
		$message = __( 'Seu comentário foi identificado como spam e não pôde ser enviado.', 'go-verge' );
	}
	wp_die(
		esc_html( $message ),
		esc_html__( 'Comentário bloqueado', 'go-verge' ),
		array( 'response' => 403, 'back_link' => true )
	);
}

/**
 * Belt-and-braces: keep the URL field empty even if a cached form still shows
 * it, so scraped/legacy forms can't seed link spam.
 *
 * @param string $url Author URL.
 * @return string
 */
function go_verge_antispam_strip_author_url( $url ) {
	return '';
}
add_filter( 'pre_comment_author_url', 'go_verge_antispam_strip_author_url', 99 );
