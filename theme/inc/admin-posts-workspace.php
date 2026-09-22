<?php
/**
 * Stable Overdrive treatment for wp-admin > Posts.
 *
 * This file intentionally keeps the native WordPress list-table DOM untouched.
 * Previous builds moved/wrapped table nodes and changed header positioning;
 * that could make the select-all label cover unrelated controls, hide Quick Edit
 * (it is a button in modern WordPress) and create visible reflow/flicker.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** True only on the regular Posts list screen. */
function go_verge_posts_workspace_is_screen() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	return $screen && 'edit-post' === $screen->id;
}

/** Mark only the Posts screen for scoped styling. */
function go_verge_posts_workspace_body_class( $classes ) {
	if ( go_verge_posts_workspace_is_screen() ) {
		$classes .= ' go-posts-workspace';
	}
	return $classes;
}
add_filter( 'admin_body_class', 'go_verge_posts_workspace_body_class', 30 );

/**
 * Defensive fallback for installations/plugins that accidentally remove the
 * native Quick Edit action. When core already provides it, nothing is changed.
 */
function go_verge_posts_workspace_restore_quick_edit( $actions, $post ) {
	if (
		! ( $post instanceof WP_Post )
		|| 'post' !== $post->post_type
		|| ! current_user_can( 'edit_post', $post->ID )
		|| 'trash' === $post->post_status
	) {
		return $actions;
	}

	foreach ( array_keys( (array) $actions ) as $key ) {
		if ( false !== strpos( (string) $key, 'inline' ) ) {
			return $actions;
		}
	}

	$title = trim( wp_strip_all_tags( get_the_title( $post ) ) );
	if ( '' === $title ) {
		$title = __( '(sem título)', 'go-verge' );
	}

	$actions['inline hide-if-no-js'] = sprintf(
		'<button type="button" class="button-link editinline" aria-label="%1$s" aria-expanded="false">%2$s</button>',
		esc_attr( sprintf( __( 'Edição rápida de “%s”', 'go-verge' ), $title ) ),
		esc_html__( 'Edição rápida', 'go-verge' )
	);

	return $actions;
}
add_filter( 'post_row_actions', 'go_verge_posts_workspace_restore_quick_edit', 999, 2 );

/**
 * Visual polish without moving DOM nodes, reordering rows/columns, attaching
 * selection handlers or changing WordPress' native table positioning contract.
 */
function go_verge_posts_workspace_css() {
	if ( ! go_verge_posts_workspace_is_screen() ) {
		return;
	}
	?>
	<style id="go-posts-workspace-css">
	body.go-posts-workspace{
		--go-work-accent:var(--go-admin-accent,#421aff);
		--go-work-accent-hover:var(--go-admin-accent-hover,#2f0fc4);
		--go-work-on-accent:var(--go-admin-on-accent,#fff);
		--go-work-ink:var(--go-admin-ink,#17151c);
		--go-work-muted:var(--go-admin-muted,#65616d);
		--go-work-line:var(--go-admin-line,#e2e0e7);
		--go-work-soft:var(--go-admin-accent-soft,#eeeafd);
		--go-work-page:var(--go-admin-page,#f4f3f7);
		--go-work-card:var(--go-admin-surface,#fff);
	}
	body.go-posts-workspace #wpcontent{background:var(--go-work-page)}
	body.go-posts-workspace #wpbody-content{padding-bottom:42px}
	body.go-posts-workspace .wrap{margin:20px 22px 0 20px}
	body.go-posts-workspace .wrap>h1.wp-heading-inline{margin:0 10px 14px 0;color:var(--go-work-ink);font-size:28px;line-height:1.15;font-weight:760;letter-spacing:-.02em}

	/* Keep Add post above any plugin/table layer and preserve its native link. */
	body.go-posts-workspace .page-title-action{
		position:relative!important;
		z-index:30!important;
		pointer-events:auto!important;
		top:-4px;
		padding:4px 11px;
		border-color:var(--go-work-accent);
		border-radius:8px;
		background:var(--go-work-accent);
		color:var(--go-work-on-accent);
		font-weight:650;
		box-shadow:none;
	}
	body.go-posts-workspace .page-title-action:hover,
	body.go-posts-workspace .page-title-action:focus{border-color:var(--go-work-accent-hover);background:var(--go-work-accent-hover);color:var(--go-work-on-accent)}

	/* Native status tabs and toolbar; no JS relocation, so there is no late jump. */
	body.go-posts-workspace .subsubsub{box-sizing:border-box;float:none;display:flex;align-items:center;gap:2px;flex-wrap:wrap;width:100%;margin:0 0 10px;padding:7px 9px;border:1px solid var(--go-work-line);border-radius:11px;background:var(--go-work-card);box-shadow:0 1px 2px rgba(18,16,24,.025);font-size:0}
	body.go-posts-workspace .subsubsub li{margin:0;padding:0;font-size:0}
	body.go-posts-workspace .subsubsub a{display:inline-flex;align-items:center;min-height:29px;padding:0 8px;border-radius:7px;color:var(--go-work-muted);font-size:12px;text-decoration:none}
	body.go-posts-workspace .subsubsub a.current{background:var(--go-work-soft);color:var(--go-work-accent);font-weight:700}
	body.go-posts-workspace .subsubsub a:hover{background:var(--go-work-soft);color:var(--go-work-ink)}
	body.go-posts-workspace .subsubsub .count{color:var(--go-work-muted)}

	body.go-posts-workspace .tablenav.top{box-sizing:border-box;clear:both;min-height:50px;height:auto;margin:0 0 10px;padding:8px 9px;border:1px solid var(--go-work-line);border-radius:11px;background:var(--go-work-card)}
	body.go-posts-workspace .tablenav.top .actions select,
	body.go-posts-workspace .tablenav.top .button,
	body.go-posts-workspace .search-box input[type=search],
	body.go-posts-workspace .search-box input[type=text]{min-height:34px;border-radius:7px}

	/*
	 * Critical interaction contract: DO NOT force thead th/td to position:static.
	 * WordPress' select-all checkbox/label relies on the native header positioning.
	 * Also do not add user-select/pointer/z-index rules to every table descendant.
	 */
	body.go-posts-workspace .wp-list-table.posts{
		width:100%;
		border-color:var(--go-work-line);
		background:var(--go-work-card);
		box-shadow:none;
	}
	body.go-posts-workspace .wp-list-table.posts thead th,
	body.go-posts-workspace .wp-list-table.posts thead td,
	body.go-posts-workspace .wp-list-table.posts tfoot th,
	body.go-posts-workspace .wp-list-table.posts tfoot td{background:var(--go-work-page)!important;border-color:var(--go-work-line);color:var(--go-work-muted);font-size:11px;font-weight:720;line-height:1.25;vertical-align:middle}
	body.go-posts-workspace .wp-list-table.posts thead th a{color:var(--go-work-ink);font-weight:720;text-decoration:none}
	body.go-posts-workspace .wp-list-table.posts thead th a:hover{color:var(--go-work-accent)}
	body.go-posts-workspace .wp-list-table.posts tbody tr{background:var(--go-work-card);transition:none!important;animation:none!important}
	body.go-posts-workspace .wp-list-table.posts tbody tr:nth-child(even){background:color-mix(in srgb,var(--go-work-page) 30%,var(--go-work-card))}
	body.go-posts-workspace .wp-list-table.posts tbody tr:hover{box-shadow:inset 2px 0 0 color-mix(in srgb,var(--go-work-accent) 72%,transparent)}
	body.go-posts-workspace .wp-list-table.posts tbody td,
	body.go-posts-workspace .wp-list-table.posts tbody th{border-bottom-color:var(--go-work-line);vertical-align:top}

	/* Checkbox/header geometry is intentionally left 100% to WordPress core.
	 * Do not position, clip or change pointer-events on .check-column/labels: the
	 * select-all control must never grow into an invisible click overlay. */
	body.go-posts-workspace .wp-list-table.posts .column-title .row-title{color:var(--go-work-ink);font-size:13px;line-height:1.42;font-weight:740;text-decoration:none}
	body.go-posts-workspace .wp-list-table.posts .column-title .row-title:hover,
	body.go-posts-workspace .wp-list-table.posts .column-title .row-title:focus{color:var(--go-work-accent);text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:3px}

	/* Quick Edit is a BUTTON in current WordPress. Never inherit font-size:0. */
	body.go-posts-workspace .wp-list-table.posts .row-actions{position:static!important;visibility:visible!important;opacity:1!important;margin-top:7px!important;color:var(--go-work-muted)}
	body.go-posts-workspace .wp-list-table.posts .row-actions>span{display:inline-block!important;font-size:11px!important}
	body.go-posts-workspace .wp-list-table.posts .row-actions :is(a,button.button-link){display:inline-flex!important;align-items:center;min-height:25px;margin:0 3px 3px 0;padding:0 7px!important;border:1px solid var(--go-work-line)!important;border-radius:6px;background:var(--go-work-card)!important;color:var(--go-work-muted)!important;font-size:10px!important;font-weight:600!important;line-height:1!important;text-decoration:none!important;box-shadow:none!important;cursor:pointer!important}
	body.go-posts-workspace .wp-list-table.posts .row-actions :is(a,button.button-link):hover,
	body.go-posts-workspace .wp-list-table.posts .row-actions :is(a,button.button-link):focus{border-color:var(--go-work-accent)!important;color:var(--go-work-accent)!important}
	body.go-posts-workspace .wp-list-table.posts .row-actions .edit :is(a,button),
	body.go-posts-workspace .wp-list-table.posts .row-actions .inline :is(a,button){border-color:color-mix(in srgb,var(--go-work-accent) 35%,var(--go-work-line))!important;color:var(--go-work-accent)!important;font-weight:700!important}
	body.go-posts-workspace .wp-list-table.posts .row-actions .trash :is(a,button){color:#b32d2e!important}

	/* Avoid visual pulsing/reflow in a control-heavy table. Data still refreshes. */
	body.go-posts-workspace .go-pi-index.is-loading .go-pi-index-badge:before{animation:none!important;transform:none!important;opacity:.55!important}
	body.go-posts-workspace .go-pv.is-loading .go-pv__fresh i,
	body.go-posts-workspace .go-pv.is-updated .go-pv__today strong{animation:none!important;transform:none!important;opacity:1!important}
	body.go-posts-workspace .wp-list-table.posts *,
	body.go-posts-workspace .tablenav *{scroll-behavior:auto}

	/* Decorative pseudo-elements can never become click surfaces. */
	body.go-posts-workspace .wrap::before,
	body.go-posts-workspace .wrap::after,
	body.go-posts-workspace .wp-list-table.posts::before,
	body.go-posts-workspace .wp-list-table.posts::after{pointer-events:none!important}

	@media(max-width:1320px){body.go-posts-workspace .wrap{margin-right:14px;margin-left:14px}}
	@media(max-width:782px){
		body.go-posts-workspace .wrap{margin:16px 10px 0}
		body.go-posts-workspace .wrap>h1.wp-heading-inline{font-size:24px}
		body.go-posts-workspace .tablenav.top{padding:10px}
	}
	</style>
	<?php
}
add_action( 'admin_head-edit.php', 'go_verge_posts_workspace_css', 120 );
