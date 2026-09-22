<?php
/** Editorial single. One content tree and one hero on every viewport. */
if ( ! defined( 'ABSPATH' ) || empty( $args['post_id'] ) ) { return; }
$c = $args;
$od_classes = array_merge( (array) $c['classes'], array( 'od-article' ) );
if ( $c['is_scored'] ) {
	$od_classes[] = 'go-article--scored';
	$od_classes[] = $c['is_critique'] ? 'go-article--critique' : 'go-article--review';
	$od_classes[] = 'od-review-page';
	if ( ! $c['has_hero'] ) { $od_classes[] = 'od-article--premium'; }
}
$od_kind = $c['is_critique'] ? __( 'Crítica', 'go-verge' ) : ( $c['is_review'] ? __( 'Review', 'go-verge' ) : '' );
$od_work = $c['is_critique'] ? $c['work_name'] : $c['review_game_name'];
?>
<main id="primary" class="go-main go-single-page">
	<article <?php post_class( implode( ' ', $od_classes ) ); ?>>
		<?php if ( $c['is_scored'] && $c['has_hero'] ) : ?>
			<section class="go-scored-masthead<?php echo '' !== $c['score_label'] ? ' has-score' : ' has-no-score'; ?>" aria-labelledby="go-scored-masthead-title">
				<div class="go-scored-masthead__media" aria-hidden="true">
					<?php the_post_thumbnail( $c['hero_size'], array(
						'loading' => 'eager', 'fetchpriority' => 'high', 'decoding' => 'auto',
						'data-go-no-lightbox' => '1', 'data-go-smart-crop' => 'off',
						'alt' => '', 'sizes' => $c['hero_sizes'], 'srcset' => $c['hero_srcset'],
					) ); ?>
				</div>
				<div class="go-scored-masthead__shade" aria-hidden="true"></div>
				<div class="go-container go-scored-masthead__inner">
					<div class="go-scored-masthead__copy">
						<?php if ( $c['breadcrumbs'] ) : ?><div class="go-single__breadcrumbs go-scored-masthead__breadcrumbs"><?php echo $c['breadcrumbs']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
						<div class="go-scored-masthead__kicker"><span><?php echo esc_html( $od_kind ); ?></span><?php if ( $od_work ) : ?><span class="go-scored-masthead__work"><?php echo esc_html( $od_work ); ?></span><?php endif; ?></div>
						<div class="go-scored-masthead__lead">
							<?php if ( '' !== $c['score_label'] ) : ?>
								<div class="go-scored-masthead__score" aria-label="<?php echo esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $c['score_label'] ) ); ?>"><span class="go-scored-masthead__score-value"><?php echo esc_html( $c['score_label'] ); ?></span><span class="go-scored-masthead__score-scale">/10</span></div>
							<?php endif; ?>
							<div class="go-scored-masthead__headline">
								<h1 id="go-scored-masthead-title" class="go-scored-masthead__title"><?php echo esc_html( $c['title'] ); ?></h1>
								<?php if ( $c['deck'] ) : ?><p class="go-scored-masthead__deck"><?php echo esc_html( $c['deck'] ); ?></p><?php endif; ?>
							</div>
						</div>
						<div class="go-scored-masthead__footer">
							<div class="go-scored-masthead__meta">
								<span class="go-scored-masthead__avatar" aria-hidden="true"><?php echo get_avatar( get_the_author_meta( 'ID' ), 44 ); ?></span>
								<div class="go-scored-masthead__meta-copy">
									<div class="go-scored-masthead__byline"><?php echo go_verge_byline( $c['post_id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>
									<span class="go-scored-masthead__meta-line"><?php echo go_verge_article_dateline_html( $c['post_id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span aria-hidden="true">·</span><?php printf( esc_html( _n( '%d min de leitura', '%d min de leitura', $c['reading_minutes'], 'go-verge' ) ), (int) $c['reading_minutes'] ); ?></span>
								</div>
							</div>
							<div class="go-scored-masthead__actions" aria-label="<?php esc_attr_e( 'Ações da matéria', 'go-verge' ); ?>">
								<a class="go-scored-masthead__action go-scored-masthead__action--icon" href="<?php echo esc_url( 'https://twitter.com/intent/tweet?text=' . $c['share_title_encoded'] . '&url=' . $c['share_url_encoded'] ); ?>" target="_blank" rel="noopener noreferrer" aria-label="<?php esc_attr_e( 'Compartilhar no X', 'go-verge' ); ?>"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M18.2 2.3h3.3l-7.2 8.2 8.5 11.2h-6.6L11 14.9l-6 6.8H1.7l7.7-8.8L1.3 2.3h6.8l4.7 6.2 5.4-6.2Zm-1.1 17.5h1.8L7.1 4.2h-2l12 15.6Z"/></svg></a>
								<a class="go-scored-masthead__action go-scored-masthead__action--icon" href="<?php echo esc_url( 'https://api.whatsapp.com/send?text=' . $c['share_title_encoded'] . '%20' . $c['share_url_encoded'] ); ?>" target="_blank" rel="noopener noreferrer" aria-label="<?php esc_attr_e( 'Compartilhar no WhatsApp', 'go-verge' ); ?>"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2a9.7 9.7 0 0 0-8.3 14.7L2.4 22l5.4-1.4A9.8 9.8 0 1 0 12 2Zm0 17.7c-1.4 0-2.7-.4-3.9-1.1l-.3-.2-3.2.8.9-3.1-.2-.3A7.7 7.7 0 1 1 12 19.7Z"/></svg></a>
								<button type="button" class="go-scored-masthead__action go-scored-masthead__action--text" data-go-copy-link data-share-url="<?php echo esc_url( $c['permalink'] ); ?>"><?php esc_html_e( 'Copiar link', 'go-verge' ); ?></button>
								<?php if ( function_exists( 'go_verge_product_save_button' ) ) { go_verge_product_save_button( $c['post_id'] ); } ?>
							</div>
						</div>
					</div>
				</div>
			</section>
			<?php if ( $c['hero_ad'] ) : ?><div class="go-container od-article__hero-ad"><?php echo $c['hero_ad']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
		<?php else : ?>
			<div class="od-article__opening">
				<div class="go-container od-article__intro">
					<header class="od-article__header">
						<?php if ( $c['breadcrumbs'] ) : ?><div class="go-single__breadcrumbs"><?php echo $c['breadcrumbs']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
						<?php if ( $od_kind ) : ?><div class="od-article__eyebrow"><span><?php echo esc_html( $od_kind ); ?></span><?php if ( $od_work ) : ?><span class="od-article__work"><?php echo esc_html( $od_work ); ?></span><?php endif; ?></div><?php endif; ?>
						<div class="od-article__headline<?php echo $c['is_scored'] && '' !== $c['score_label'] ? ' has-score' : ''; ?>">
							<div class="od-article__copy">
								<h1 class="go-single__title"><?php echo esc_html( $c['title'] ); ?></h1>
								<?php if ( $c['deck'] ) : ?><p class="go-single__deck"><?php echo esc_html( $c['deck'] ); ?></p><?php endif; ?>
							</div>
							<?php if ( $c['is_scored'] && '' !== $c['score_label'] ) : ?><div class="od-article__rating" aria-label="<?php echo esc_attr( sprintf( __( 'Nota %s de 10', 'go-verge' ), $c['score_label'] ) ); ?>"><strong><?php echo esc_html( $c['score_label'] ); ?></strong><span>/10</span></div><?php endif; ?>
						</div>
					</header>
					<div class="od-article__toolbar">
						<div class="od-article__byline"><span class="go-single__avatar" aria-hidden="true"><?php echo get_avatar( get_the_author_meta( 'ID' ), 48, '', '' ); ?></span><div class="od-article__author-copy"><div class="od-article__author"><?php echo go_verge_byline( $c['post_id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><div class="od-article__dateline"><?php echo go_verge_article_dateline_html( $c['post_id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?><span class="od-article__reading"><?php printf( esc_html( _n( '%d min de leitura', '%d min de leitura', $c['reading_minutes'], 'go-verge' ) ), (int) $c['reading_minutes'] ); ?></span></div></div></div>
						<div class="od-article__quick-actions" aria-label="<?php esc_attr_e( 'Ações da matéria', 'go-verge' ); ?>">
							<section class="go-article-audio go-article-audio--inline" data-go-article-audio hidden aria-label="<?php esc_attr_e( 'Áudio da matéria', 'go-verge' ); ?>"><div class="go-article-audio__controls"><button type="button" class="go-article-audio__play" data-go-audio-play aria-pressed="false"><?php echo go_verge_icon( 'play', 'go-interface-icon' ); ?><span data-go-audio-play-label><?php esc_html_e( 'Ouvir matéria', 'go-verge' ); ?></span></button><button type="button" class="go-article-audio__secondary" data-go-audio-pause disabled><?php esc_html_e( 'Pausar', 'go-verge' ); ?></button><button type="button" class="go-article-audio__secondary" data-go-audio-stop disabled><?php esc_html_e( 'Parar', 'go-verge' ); ?></button><label class="go-article-audio__speed"><span><?php esc_html_e( 'Velocidade', 'go-verge' ); ?></span><select data-go-audio-rate><option value="0.75">0,75×</option><option value="1" selected>1×</option><option value="1.25">1,25×</option><option value="1.5">1,5×</option><option value="1.75">1,75×</option></select></label></div><span class="screen-reader-text" data-go-audio-status aria-live="polite"></span></section>
							<div class="go-single__actions"><div class="go-share go-share--single" aria-label="<?php esc_attr_e( 'Compartilhar matéria', 'go-verge' ); ?>"><div class="go-share-more" data-go-share-more><button type="button" class="go-share-more__toggle go-share-more__toggle--label" data-go-share-more-toggle aria-expanded="false" aria-haspopup="true" aria-label="<?php esc_attr_e( 'Abrir opções de compartilhamento', 'go-verge' ); ?>"><?php echo go_verge_icon( 'compartilhar', 'go-interface-icon' ); ?><span><?php esc_html_e( 'Compartilhar', 'go-verge' ); ?></span></button><div class="go-share-more__menu" data-go-share-more-menu hidden><a href="<?php echo esc_url( 'https://twitter.com/intent/tweet?text=' . $c['share_title_encoded'] . '&url=' . $c['share_url_encoded'] ); ?>" target="_blank" rel="noopener noreferrer"><?php esc_html_e( 'Compartilhar no X', 'go-verge' ); ?></a><a href="<?php echo esc_url( 'https://api.whatsapp.com/send?text=' . $c['share_title_encoded'] . '%20' . $c['share_url_encoded'] ); ?>" target="_blank" rel="noopener noreferrer">WhatsApp</a><a href="<?php echo esc_url( 'https://www.facebook.com/sharer/sharer.php?u=' . $c['share_url_encoded'] ); ?>" target="_blank" rel="noopener noreferrer">Facebook</a><a href="<?php echo esc_url( 'https://t.me/share/url?url=' . $c['share_url_encoded'] . '&text=' . $c['share_title_encoded'] ); ?>" target="_blank" rel="noopener noreferrer">Telegram</a><a href="<?php echo esc_url( 'https://www.reddit.com/submit?url=' . $c['share_url_encoded'] . '&title=' . $c['share_title_encoded'] ); ?>" target="_blank" rel="noopener noreferrer">Reddit</a><a href="<?php echo esc_url( 'https://pinterest.com/pin/create/button/?url=' . $c['share_url_encoded'] . '&description=' . $c['share_title_encoded'] ); ?>" target="_blank" rel="noopener noreferrer">Pinterest</a><a href="<?php echo esc_url( 'mailto:?subject=' . $c['share_title_encoded'] . '&body=' . $c['share_url_encoded'] ); ?>"><?php esc_html_e( 'E-mail', 'go-verge' ); ?></a><button type="button" data-go-copy-link data-share-url="<?php echo esc_url( $c['permalink'] ); ?>"><?php esc_html_e( 'Copiar link', 'go-verge' ); ?></button><button type="button" class="go-share-more__native" data-go-native-share data-share-url="<?php echo esc_url( $c['permalink'] ); ?>" data-share-title="<?php echo esc_attr( $c['title'] ); ?>" hidden><?php esc_html_e( 'Mais opções no dispositivo', 'go-verge' ); ?></button></div></div></div><?php if ( function_exists( 'go_verge_product_save_button' ) ) { go_verge_product_save_button( $c['post_id'] ); } ?></div>
						</div>
					</div>
				</div>
				<?php if ( $c['has_hero'] ) : ?><div class="go-container go-single__hero-wrap"><figure class="go-single__hero"><div class="go-frame"><?php the_post_thumbnail( $c['hero_size'], array( 'loading'=>'eager','fetchpriority'=>'high','decoding'=>'auto','data-go-no-lightbox'=>'1','data-go-smart-crop'=>'off','alt'=>$c['hero_alt'],'sizes'=>$c['hero_sizes'],'srcset'=>$c['hero_srcset'] ) ); ?></div><?php if ( $c['hero_caption'] ) : ?><figcaption class="go-single__hero-caption"><?php echo esc_html( $c['hero_caption'] ); ?></figcaption><?php endif; ?></figure></div><?php endif; ?>
			</div>
			<?php if ( $c['hero_ad'] ) : ?><div class="go-container od-article__hero-ad"><?php echo $c['hero_ad']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div><?php endif; ?>
		<?php endif; ?>

		<div class="go-container go-single__layout go-article-layout" data-go-single-layout="portal">
			<div class="go-single__main go-article__main" data-go-single-main="1">
				<?php if ( $c['is_scored'] && function_exists( 'go_verge_review_box' ) ) { go_verge_review_box( $c['post_id'] ); } ?>
				<?php if ( function_exists( 'go_verge_render_live_updates' ) ) { go_verge_render_live_updates( $c['post_id'] ); } ?>

				<?php /* Preferred Source sits immediately before the article index. */ ?>
				<?php if ( function_exists( 'go_verge_render_preferred_source_button' ) ) { go_verge_render_preferred_source_button( $c['post_id'] ); } ?>
				<?php if ( count( $c['body']['toc'] ) >= 3 ) : ?>
					<details class="go-toc<?php echo $c['is_guide'] ? ' go-toc--guide' : ''; ?>" data-go-theme-toc="1">
						<summary class="go-toc__title"><?php esc_html_e( 'Tópicos', 'go-verge' ); ?></summary>
						<ul><?php foreach ( $c['body']['toc'] as $toc ) : ?><li<?php echo 3 === (int) ( $toc['level'] ?? 2 ) ? ' class="go-toc__subitem"' : ''; ?>><a href="#<?php echo esc_attr( $toc['id'] ); ?>"><?php echo esc_html( $toc['text'] ); ?></a></li><?php endforeach; ?></ul>
					</details>
				<?php endif; ?>

				<div <?php echo go_verge_ads_article_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>><?php echo $c['body']['content']; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></div>

				<?php if ( function_exists( 'go_verge_render_correction_note' ) ) { go_verge_render_correction_note( $c['post_id'] ); } ?>
				<?php if ( $c['is_scored'] && function_exists( 'go_verge_review_recap' ) ) { go_verge_review_recap( $c['post_id'] ); } ?>

				<?php /* Completion inventory. It lives after editorial content/recap and
				 * before author/recirculation, so it monetizes completion without
				 * interrupting a final paragraph.
				 *
				 * The template renders the OPPORTUNITY; the runtime decides whether it
				 * is worth requesting. A `reading_minutes >= 2` gate used to remove it
				 * from exactly the short Discover posts that have the fewest in-body
				 * positions and therefore need their one completion opportunity most,
				 * and it did so before the engine could weigh reader reach at all. An
				 * unrequested host reserves no height and is invisible. */ ?>
				<?php if ( (int) $c['reading_minutes'] >= 1 && function_exists( 'go_verge_render_adsense_unit' ) ) : ?>
					<?php go_verge_render_adsense_unit( 'article-end', array( 'tag' => 'aside', 'class' => 'go-article-end-revenue-slot', 'data' => array( 'ad-surface' => 'article-completion', 'ad-depth' => 100 ) ) ); ?>
				<?php endif; ?>

				<?php if ( $c['topics'] ) : ?><div class="go-tags" aria-label="<?php esc_attr_e( 'Assuntos da matéria', 'go-verge' ); ?>"><span class="go-tags__label"><?php esc_html_e( 'Assuntos', 'go-verge' ); ?></span><?php foreach ( $c['topics'] as $topic ) : $role = sanitize_html_class( (string) ( $topic['role'] ?? 'related' ) ); ?><a class="go-tag go-tag--<?php echo esc_attr( $role ); ?>" data-go-topic-role="<?php echo esc_attr( $role ); ?>" href="<?php echo esc_url( $topic['url'] ); ?>"><?php echo esc_html( $topic['label'] ); ?></a><?php endforeach; ?></div><?php endif; ?>
				<?php if ( ! empty( $c['follow'] ) && function_exists( 'go_verge_product_follow_button' ) ) : ?><div class="go-product-actions"><?php go_verge_product_follow_button( $c['follow']['id'], $c['follow']['type'] ); ?></div><?php endif; ?>
				<?php go_verge_author_card( $c['post_id'] ); ?>

				<?php /* Post-content inventory. Three editorial boundaries below the prose,
				 * each offering at most one unit from the shared listing pool. The zone
				 * they cover is several screens of scrolled content on a phone and had
				 * none before. The runtime applies the usual stream spacing and density
				 * rules, so a short story still ends up with fewer than three. */ ?>
				<?php if ( function_exists( 'go_verge_ads_render_post_content_unit' ) ) { go_verge_ads_render_post_content_unit( 'after-author' ); } ?>
				<?php if ( function_exists( 'go_verge_v21_render_contextual_next' ) ) { go_verge_v21_render_contextual_next( $c['post_id'] ); } ?>
				<?php if ( function_exists( 'go_verge_render_post_content_recirculation' ) ) { go_verge_render_post_content_recirculation( $c['post_id'] ); } ?>
				<?php if ( function_exists( 'go_verge_ads_render_post_content_unit' ) ) { go_verge_ads_render_post_content_unit( 'after-recirculation' ); } ?>
				<?php if ( function_exists( 'go_verge_render_more_reviews_by_author' ) ) { go_verge_render_more_reviews_by_author( $c['post_id'] ); } ?>
				<?php if ( function_exists( 'go_verge_render_game_content_cluster' ) ) { go_verge_render_game_content_cluster( $c['post_id'] ); } ?>
				<?php if ( function_exists( 'go_verge_render_topic_bar' ) ) { go_verge_render_topic_bar( $c['post_id'] ); } ?>
				<?php if ( function_exists( 'go_verge_ads_render_post_content_unit' ) ) { go_verge_ads_render_post_content_unit( 'before-comments' ); } ?>
				<?php if ( comments_open() || get_comments_number() ) : ?><div class="go-single-comments-wrap go-single-comments-wrap--inline"><?php comments_template(); ?></div><?php endif; ?>
			</div>
			<?php go_verge_article_sidebar( $c['post_id'] ); ?>
		</div>
	</article>

	<?php go_verge_render_after_article_sections( $c['post_id'] ); ?>
	<?php if ( function_exists( 'go_verge_render_explore_overdrive' ) ) { go_verge_render_explore_overdrive( 'single' ); } ?>
</main>
