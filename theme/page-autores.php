<?php
/**
 * Public authors directory.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

get_header();

$go_author_users = go_verge_public_author_directory();
$go_author_counts = $go_author_users ? count_many_users_posts( wp_list_pluck( $go_author_users, 'ID' ), 'post', true ) : array();
?>
<main id="primary" class="go-main go-authors-page od-authors">
	<section class="go-container go-authors-page__hero">
		<?php go_verge_breadcrumbs(); ?>
		<div class="go-authors-page__heading">
			<div>
				<h1 class="go-pagehead__title"><?php esc_html_e( 'Autores', 'go-verge' ); ?></h1>
			</div>
			<span class="go-authors-page__count"><?php echo esc_html( number_format_i18n( count( $go_author_users ) ) ); ?> <?php echo esc_html( _n( 'autor', 'autores', count( $go_author_users ), 'go-verge' ) ); ?></span>
		</div>
	</section>

	<section class="go-container go-section go-authors-page__content">
		<?php if ( $go_author_users ) : ?>
			<div class="go-authors-grid">
				<?php foreach ( $go_author_users as $go_author_user ) : ?>
					<?php
					$go_author_id          = absint( $go_author_user->ID );
					$go_author_bio         = function_exists( 'go_verge_author_short_bio' ) ? go_verge_author_short_bio( $go_author_id ) : trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', $go_author_id ) ) );
					$go_author_designation = function_exists( 'go_verge_author_role' ) ? go_verge_author_role( $go_author_id ) : trim( wp_strip_all_tags( (string) get_the_author_meta( 'gamxo_author_designation', $go_author_id ) ) );
					$go_author_count       = (int) ( $go_author_counts[ $go_author_id ] ?? 0 );
					$go_author_url         = get_author_posts_url( $go_author_id );
					?>
					<article class="od-person-card" aria-labelledby="od-author-<?php echo esc_attr( $go_author_id ); ?>">
						<div class="od-person-card__avatar" aria-hidden="true">
							<?php echo get_avatar( $go_author_id, 200, '', '', array( 'loading' => 'lazy' ) ); ?>
						</div>
						<div class="od-person-card__body">
							<?php if ( $go_author_designation ) : ?><span class="od-person-card__role"><?php echo esc_html( $go_author_designation ); ?></span><?php endif; ?>
							<h2 id="od-author-<?php echo esc_attr( $go_author_id ); ?>"><a href="<?php echo esc_url( $go_author_url ); ?>"><?php echo esc_html( $go_author_user->display_name ); ?></a></h2>
							<?php if ( $go_author_bio ) : ?><p><?php echo esc_html( wp_trim_words( $go_author_bio, 28, '…' ) ); ?></p><?php endif; ?>
							<div class="od-person-card__footer">
								<span><strong><?php echo esc_html( number_format_i18n( $go_author_count ) ); ?></strong> <?php echo esc_html( _n( 'publicação', 'publicações', $go_author_count, 'go-verge' ) ); ?></span>
								<span class="od-authors__arrow" aria-hidden="true">↗</span>
							</div>
						</div>
					</article>
				<?php endforeach; ?>
			</div>
		<?php else : ?>
			<div class="go-search-page__empty">
				<h2><?php esc_html_e( 'Nenhum autor encontrado', 'go-verge' ); ?></h2>
			</div>
		<?php endif; ?>
	</section>
</main>
<?php get_footer(); ?>
