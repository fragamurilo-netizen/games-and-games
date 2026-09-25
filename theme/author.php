<?php
/**
 * Author archive: editorial profile, lead story and progressive post feed.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$go_verge_author_id    = absint( get_queried_object_id() );
$go_verge_author       = get_userdata( $go_verge_author_id );
$go_verge_author_name  = $go_verge_author instanceof WP_User ? $go_verge_author->display_name : get_the_author_meta( 'display_name', $go_verge_author_id );
$go_verge_author_bio   = trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', $go_verge_author_id ) ) );
$go_verge_author_short_bio = function_exists( 'go_verge_author_short_bio' ) ? go_verge_author_short_bio( $go_verge_author_id ) : $go_verge_author_bio;
$go_verge_author_role  = function_exists( 'go_verge_author_role' ) ? go_verge_author_role( $go_verge_author_id ) : trim( (string) get_the_author_meta( 'gamxo_author_designation', $go_verge_author_id ) );
$go_verge_author_pronouns = function_exists( 'go_verge_author_profile_value' ) ? go_verge_author_profile_value( $go_verge_author_id, 'go_author_pronouns' ) : '';
$go_verge_author_location = function_exists( 'go_verge_author_profile_value' ) ? go_verge_author_profile_value( $go_verge_author_id, 'go_author_location' ) : '';
$go_verge_author_since = function_exists( 'go_verge_author_profile_value' ) ? absint( go_verge_author_profile_value( $go_verge_author_id, 'go_author_since' ) ) : 0;
$go_verge_author_languages = function_exists( 'go_verge_author_profile_value' ) ? go_verge_author_profile_value( $go_verge_author_id, 'go_author_languages' ) : '';
$go_verge_author_credentials = function_exists( 'go_verge_author_profile_value' ) ? go_verge_author_profile_value( $go_verge_author_id, 'go_author_credentials' ) : '';
$go_verge_author_transparency = function_exists( 'go_verge_author_profile_value' ) ? go_verge_author_profile_value( $go_verge_author_id, 'go_author_transparency' ) : '';
$go_verge_author_public_email = function_exists( 'go_verge_author_profile_value' ) ? sanitize_email( go_verge_author_profile_value( $go_verge_author_id, 'go_author_public_email' ) ) : '';
$go_verge_author_portfolio = function_exists( 'go_verge_author_profile_value' ) ? go_verge_author_profile_value( $go_verge_author_id, 'go_author_portfolio_url' ) : '';
$go_verge_author_topics = function_exists( 'go_verge_author_list_meta' )
	? array_values( array_unique( array_merge( go_verge_author_list_meta( $go_verge_author_id, 'go_author_coverage', 8 ), go_verge_author_list_meta( $go_verge_author_id, 'go_author_expertise', 8 ) ) ) )
	: array();
$go_verge_author_socials = function_exists( 'go_verge_author_social_links' ) ? go_verge_author_social_links( $go_verge_author_id ) : array();
$go_verge_author_url   = trim( (string) get_the_author_meta( 'user_url', $go_verge_author_id ) );
$go_verge_author_count = (int) count_user_posts( $go_verge_author_id, 'post', true );
$go_verge_author_paged = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
$go_verge_author_posts = isset( $wp_query ) && $wp_query instanceof WP_Query ? $wp_query->posts : array();
$go_verge_author_lead  = ! empty( $go_verge_author_posts[0] ) ? $go_verge_author_posts[0] : null;
?>

<main id="primary" class="go-main go-author-page od-profile">
	<div class="go-container go-author-page__top">
		<div class="od-profile__navigation"><?php go_verge_breadcrumbs(); ?><?php $directory = get_page_by_path( 'autores' ); if ( $directory instanceof WP_Post && 'publish' === get_post_status( $directory ) ) : ?><a href="<?php echo esc_url( get_permalink( $directory ) ); ?>"><?php esc_html_e( 'Todos os autores', 'go-verge' ); ?> <span aria-hidden="true">↗</span></a><?php endif; ?></div>

		<section class="go-author-hero" aria-labelledby="go-author-name">
			<div class="go-author-hero__avatar" aria-hidden="true">
				<?php echo get_avatar( $go_verge_author_id, 240, '', '', array( 'loading' => 'eager' ) ); ?>
			</div>
			<div class="go-author-hero__copy">
				<?php if ( $go_verge_author_role || $go_verge_author_pronouns ) : ?>
					<div class="go-author-hero__identity">
						<?php if ( $go_verge_author_role ) : ?><span class="go-author-hero__role"><?php echo esc_html( $go_verge_author_role ); ?></span><?php endif; ?>
						<?php if ( $go_verge_author_pronouns ) : ?><span class="go-author-hero__pronouns"><?php echo esc_html( $go_verge_author_pronouns ); ?></span><?php endif; ?>
					</div>
				<?php endif; ?>
				<h1 id="go-author-name" class="go-author-hero__name"><?php echo esc_html( $go_verge_author_paged > 1 ? sprintf( __( 'Publicações de %1$s — página %2$d', 'go-verge' ), $go_verge_author_name, $go_verge_author_paged ) : $go_verge_author_name ); ?></h1>
				<?php if ( $go_verge_author_paged > 1 ) : ?><p class="go-author-hero__profile-link"><a href="<?php echo esc_url( get_author_posts_url( $go_verge_author_id ) ); ?>"><?php echo esc_html( sprintf( __( 'Ver perfil de %s', 'go-verge' ), $go_verge_author_name ) ); ?></a></p><?php endif; ?>
				<?php if ( 1 === $go_verge_author_paged && ( $go_verge_author_bio || $go_verge_author_short_bio ) ) : ?>
					<p class="go-author-hero__bio"><?php echo esc_html( $go_verge_author_bio ?: $go_verge_author_short_bio ); ?></p>
				<?php endif; ?>
				<?php if ( 1 === $go_verge_author_paged && $go_verge_author_topics ) : ?>
					<div class="go-author-hero__topics" aria-label="<?php esc_attr_e( 'Áreas de cobertura e especialidades', 'go-verge' ); ?>">
						<?php foreach ( array_slice( $go_verge_author_topics, 0, 10 ) as $go_verge_author_topic ) : ?><span class="go-author-hero__topic"><?php echo esc_html( $go_verge_author_topic ); ?></span><?php endforeach; ?>
					</div>
				<?php endif; ?>
				<div class="go-author-hero__meta">
					<span><strong><?php echo esc_html( number_format_i18n( $go_verge_author_count ) ); ?></strong> <?php echo esc_html( _n( 'publicação', 'publicações', $go_verge_author_count, 'go-verge' ) ); ?></span>
				</div>
				<?php if ( 1 === $go_verge_author_paged && ( $go_verge_author_location || $go_verge_author_since || $go_verge_author_languages ) ) : ?>
					<dl class="go-author-hero__facts">
						<?php if ( $go_verge_author_location ) : ?><div class="go-author-hero__fact"><dt><?php esc_html_e( 'Base', 'go-verge' ); ?></dt><dd><?php echo esc_html( $go_verge_author_location ); ?></dd></div><?php endif; ?>
						<?php if ( $go_verge_author_since ) : ?><div class="go-author-hero__fact"><dt><?php esc_html_e( 'Jornalismo', 'go-verge' ); ?></dt><dd><?php echo esc_html( sprintf( __( 'Desde %d', 'go-verge' ), $go_verge_author_since ) ); ?></dd></div><?php endif; ?>
						<?php if ( $go_verge_author_languages ) : ?><div class="go-author-hero__fact"><dt><?php esc_html_e( 'Idiomas', 'go-verge' ); ?></dt><dd><?php echo esc_html( $go_verge_author_languages ); ?></dd></div><?php endif; ?>
					</dl>
				<?php endif; ?>
				<?php if ( $go_verge_author_url || $go_verge_author_portfolio || $go_verge_author_public_email || $go_verge_author_socials ) : ?>
					<div class="go-author-hero__links" aria-label="<?php esc_attr_e( 'Links públicos do autor', 'go-verge' ); ?>">
						<?php if ( $go_verge_author_url ) : ?><a href="<?php echo esc_url( $go_verge_author_url ); ?>" target="_blank" rel="me noopener noreferrer"><?php esc_html_e( 'Site', 'go-verge' ); ?><span aria-hidden="true"> ↗</span></a><?php endif; ?>
						<?php if ( $go_verge_author_portfolio && untrailingslashit( $go_verge_author_portfolio ) !== untrailingslashit( $go_verge_author_url ) ) : ?><a href="<?php echo esc_url( $go_verge_author_portfolio ); ?>" target="_blank" rel="me noopener noreferrer"><?php esc_html_e( 'Portfólio', 'go-verge' ); ?><span aria-hidden="true"> ↗</span></a><?php endif; ?>
						<?php foreach ( $go_verge_author_socials as $go_verge_author_social ) : ?><a href="<?php echo esc_url( $go_verge_author_social['url'] ); ?>" target="_blank" rel="me noopener noreferrer"><?php echo esc_html( $go_verge_author_social['label'] ); ?></a><?php endforeach; ?>
						<?php if ( $go_verge_author_public_email ) : ?><a href="mailto:<?php echo esc_attr( antispambot( $go_verge_author_public_email ) ); ?>"><?php esc_html_e( 'E-mail', 'go-verge' ); ?></a><?php endif; ?>
					</div>
				<?php endif; ?>
			</div>
		</section>

		<?php if ( 1 === $go_verge_author_paged && ( $go_verge_author_credentials || $go_verge_author_transparency ) ) : ?>
			<section class="go-author-profile-notes" aria-label="<?php esc_attr_e( 'Experiência e transparência do autor', 'go-verge' ); ?>">
				<?php if ( $go_verge_author_credentials ) : ?>
					<details class="go-author-profile-note">
						<summary><?php esc_html_e( 'Experiência e credenciais', 'go-verge' ); ?></summary>
						<?php echo wpautop( esc_html( $go_verge_author_credentials ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
					</details>
				<?php endif; ?>
				<?php if ( $go_verge_author_transparency ) : ?>
					<details class="go-author-profile-note">
						<summary><?php esc_html_e( 'Transparência', 'go-verge' ); ?></summary>
						<?php echo wpautop( esc_html( $go_verge_author_transparency ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
					</details>
				<?php endif; ?>
			</section>
		<?php endif; ?>
	</div>

	<?php if ( have_posts() ) : ?>
		<div class="go-container go-author-page__content">
			<div class="go-author-section__head">
				<div>
					<h2><?php echo esc_html( $go_verge_author_paged > 1 ? sprintf( __( 'Publicações — página %d', 'go-verge' ), $go_verge_author_paged ) : __( 'Publicações mais recentes', 'go-verge' ) ); ?></h2>
				</div>
			</div>

			<?php if ( $go_verge_author_lead instanceof WP_Post ) : ?>
				<?php
				$go_verge_lead_id   = (int) $go_verge_author_lead->ID;
				$go_verge_lead_deck = go_verge_support_text( $go_verge_lead_id );
				$go_verge_lead_term = go_verge_get_primary_term( $go_verge_lead_id );
				?>
				<article class="go-author-lead<?php echo has_post_thumbnail( $go_verge_lead_id ) ? '' : ' go-author-lead--no-media'; ?>">
					<?php if ( has_post_thumbnail( $go_verge_lead_id ) ) : ?>
						<a class="go-author-lead__media" href="<?php echo esc_url( get_permalink( $go_verge_lead_id ) ); ?>" tabindex="-1" aria-hidden="true">
							<?php echo get_the_post_thumbnail( $go_verge_lead_id, 'go_hero', array( 'loading' => 'eager', 'alt' => '' ) ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
						</a>
					<?php endif; ?>
					<div class="go-author-lead__content">
						<?php if ( $go_verge_lead_term instanceof WP_Term ) : ?>
							<span class="go-author-lead__section"><?php echo esc_html( $go_verge_lead_term->name ); ?></span>
						<?php endif; ?>
						<h2><a href="<?php echo esc_url( get_permalink( $go_verge_lead_id ) ); ?>"><?php echo esc_html( get_the_title( $go_verge_lead_id ) ); ?></a></h2>
						<?php if ( $go_verge_lead_deck ) : ?><p><?php echo esc_html( wp_trim_words( $go_verge_lead_deck, 34, '…' ) ); ?></p><?php endif; ?>
						<div class="go-author-lead__meta">
							<?php echo go_verge_time_html( $go_verge_lead_id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?>
							<span class="go-dot" aria-hidden="true">·</span>
							<span class="go-mono"><?php echo esc_html( sprintf( _n( '%d min de leitura', '%d min de leitura', go_verge_reading_time( $go_verge_lead_id ), 'go-verge' ), go_verge_reading_time( $go_verge_lead_id ) ) ); ?></span>
						</div>
					</div>
				</article>
			<?php endif; ?>

			<div class="go-author-feed"<?php echo go_verge_ads_listing_root_attributes(); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- fixed publisher hooks. ?>>
				<?php
				$go_verge_author_feed = array_slice( $go_verge_author_posts, 1 );
				foreach ( $go_verge_author_feed as $go_verge_author_post ) :
					go_verge_archive_list_item( $go_verge_author_post->ID, array( 'show_excerpt' => true ) );
				endforeach;
				?>
			</div>

			<?php go_verge_pagination( null, array(), array( 'mode' => 'archive-list', 'target' => '.go-author-feed' ) ); ?>
		</div>
	<?php else : ?>
		<div class="go-container go-section">
			<?php get_template_part( 'template-parts/content', 'none' ); ?>
		</div>
	<?php endif; ?>
</main>

<?php
get_footer();
