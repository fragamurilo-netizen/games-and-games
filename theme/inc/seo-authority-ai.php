<?php
/**
 * Technical SEO + authority guardrails for Search and generative AI surfaces.
 *
 * Nothing here attempts to create a special "AI Overview" schema. Google uses
 * the normal Search index and snippet eligibility for those experiences.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Resolve an exact legacy redirect without letting a top-level slug hijack nested canonical URLs. */
function go_verge_safe_legacy_redirect_target( $path, $map ) {
	$path = trim( (string) $path, '/' );
	$map  = is_array( $map ) ? $map : array();
	if ( '' === $path ) {
		return '';
	}
	if ( ! empty( $map[ $path ] ) ) {
		return (string) $map[ $path ];
	}
	/* Basename fallback is valid only for old root URLs such as /xbox/. */
	if ( false === strpos( $path, '/' ) ) {
		$base = basename( $path );
		return ! empty( $map[ $base ] ) ? (string) $map[ $base ] : '';
	}
	return '';
}

/** Current author archive page number. */
function go_verge_author_archive_page_number() {
	return max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
}

/** Distinguish paginated author archives in SERP/title surfaces. */
function go_verge_author_pagination_title( $title ) {
	if ( ! is_author() ) {
		return $title;
	}
	$page = go_verge_author_archive_page_number();
	if ( $page <= 1 ) {
		return $title;
	}
	$name = trim( (string) get_the_author_meta( 'display_name', get_queried_object_id() ) );
	return sprintf( __( 'Publicações de %1$s — página %2$d | %3$s', 'go-verge' ), $name, $page, get_bloginfo( 'name' ) );
}
add_filter( 'rank_math/frontend/title', 'go_verge_author_pagination_title', 1300 );
add_filter( 'pre_get_document_title', 'go_verge_author_pagination_title', 1300 );

function go_verge_author_pagination_description( $description ) {
	if ( ! is_author() ) {
		return $description;
	}
	$page = go_verge_author_archive_page_number();
	if ( $page <= 1 ) {
		return $description;
	}
	$name = trim( (string) get_the_author_meta( 'display_name', get_queried_object_id() ) );
	return sprintf( __( 'Arquivo de matérias assinadas por %1$s no Overdrive — página %2$d.', 'go-verge' ), $name, $page );
}
add_filter( 'rank_math/frontend/description', 'go_verge_author_pagination_description', 1300 );

/** Keep every author pagination URL self-canonical while page 1 remains the identity ProfilePage. */
function go_verge_author_pagination_canonical( $canonical ) {
	if ( ! is_author() ) {
		return $canonical;
	}
	$page = go_verge_author_archive_page_number();
	if ( $page <= 1 ) {
		return $canonical;
	}
	$url = get_pagenum_link( $page );
	return $url ? $url : $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_author_pagination_canonical', 1300 );

/**
 * RSS/Atom feeds are useful for subscribers but not useful Search landing pages.
 * X-Robots-Tag works for non-HTML resources while keeping links crawlable.
 */
function go_verge_feed_x_robots_tag() {
	if ( is_feed() && ! headers_sent() ) {
		header( 'X-Robots-Tag: noindex, follow', true );
	}
}
add_action( 'send_headers', 'go_verge_feed_x_robots_tag', 100 );

/**
 * Consolidate every duplicate "Últimas" surface into the canonical hub.
 *
 * MEASURED PROBLEM (production, 03/09/2026)
 * -----------------------------------------
 * Two published Pages, both titled "Últimas", both rendering
 * page-template/template-latest.php under the same H1 "Tudo do Overdrive":
 *
 *   - ID 25166  /ultimas-publicacoes/   canonical hub, the one in the sitemap
 *   - ID 25248  /ultimas-noticias-2/    duplicate, self-canonical, indexable
 *
 * `/ultimas/` and `/ultimas-noticias/` both 301 to the duplicate, so the
 * friendly slugs delivered readers and crawlers to the wrong URL.
 *
 * This function already existed and never fired: the duplicate is the
 * WordPress **posts page**, and WordPress makes `is_page()` false there —
 * it is `is_home()`, with `<body class="blog">`. Detecting only `is_page()`
 * meant the consolidation was dead code on the one surface it targeted.
 *
 * The check below covers both shapes, so it keeps working whichever Page the
 * site sets as its posts page, and it stays inert when the posts page already
 * *is* the hub (no self-redirect) or when the hub does not exist (no redirect
 * into a 404).
 */
function go_verge_redirect_duplicate_latest_page() {
	if ( is_admin() || wp_doing_ajax() || is_feed() ) {
		return;
	}

	$hub = function_exists( 'go_verge_latest_hub_page' ) ? go_verge_latest_hub_page() : null;
	if ( ! $hub instanceof WP_Post ) {
		return;
	}

	/* The homepage owns a curated cover, not an archive. Its historical
	 * `/page/N/` routes repeat every cover module and change only the secondary
	 * latest feed, producing duplicate/soft-404 space at arbitrary depths. Keep
	 * page one untouched and consolidate deeper pages into the dedicated,
	 * crawlable chronological hub. */
	$page = max( 1, absint( get_query_var( 'paged' ) ), absint( get_query_var( 'page' ) ) );
	if ( is_front_page() ) {
		if ( $page <= 1 ) {
			return;
		}
		$target = function_exists( 'go_verge_latest_url' ) ? go_verge_latest_url( $page ) : home_url( '/ultimas-publicacoes/page/' . $page . '/' );
		wp_safe_redirect( $target, 301, 'Overdrive paginated homepage consolidation' );
		exit;
	}

	$is_duplicate = is_page( 'ultimas-noticias-2' );
	if ( ! $is_duplicate && is_home() ) {
		/* The posts page is a duplicate only while it is some other Page. */
		$posts_page   = absint( get_option( 'page_for_posts' ) );
		$is_duplicate = $posts_page && $posts_page !== (int) $hub->ID;
	}
	if ( ! $is_duplicate || is_page( $hub->ID ) ) {
		return;
	}

	$target = function_exists( 'go_verge_latest_url' ) ? go_verge_latest_url( $page ) : home_url( '/ultimas-publicacoes/' );
	if ( isset( $_GET['editoria'] ) ) {
		$editoria = sanitize_key( wp_unslash( $_GET['editoria'] ) );
		$allowed  = array( 'games', 'entretenimento', 'tecnologia', 'reviews', 'criticas' );
		if ( in_array( $editoria, $allowed, true ) ) {
			$target = add_query_arg( 'editoria', $editoria, $target );
		}
	}

	wp_safe_redirect( $target, 301, 'Overdrive duplicate latest hub consolidation' );
	exit;
}
add_action( 'template_redirect', 'go_verge_redirect_duplicate_latest_page', -2 );

/** Add direct Site Health visibility for public author completeness. */
function go_verge_authority_site_health_tests( $tests ) {
	$tests['direct']['go_verge_author_profiles'] = array(
		'label' => __( 'Perfis públicos de autores', 'go-verge' ),
		'test'  => 'go_verge_authority_site_health_author_profiles',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_authority_site_health_tests' );

function go_verge_authority_site_health_author_profiles() {
	$users   = get_users( array( 'has_published_posts' => array( 'post' ), 'fields' => array( 'ID', 'display_name' ) ) );
	$missing = array();
	$total   = 0;
	foreach ( (array) $users as $user ) {
		$total++;
		$bio  = trim( wp_strip_all_tags( (string) get_the_author_meta( 'description', $user->ID ) ) );
		$role = function_exists( 'go_verge_author_role' ) ? trim( (string) go_verge_author_role( $user->ID ) ) : trim( (string) get_the_author_meta( 'gamxo_author_designation', $user->ID ) );
		if ( '' === $bio || '' === $role ) {
			$missing[] = $user->display_name;
		}
	}

	if ( empty( $missing ) ) {
		return array(
			'label'       => __( 'Autores publicados têm bio e função editorial', 'go-verge' ),
			'status'      => 'good',
			'badge'       => array( 'label' => __( 'Autoridade editorial', 'go-verge' ), 'color' => 'blue' ),
			'description' => '<p>' . esc_html( sprintf( _n( '%d autor publicado está completo.', '%d autores publicados estão completos.', $total, 'go-verge' ), $total ) ) . '</p>',
			'test'        => 'go_verge_author_profiles',
		);
	}

	return array(
		'label'       => __( 'Há autores publicados com perfil incompleto', 'go-verge' ),
		'status'      => 'recommended',
		'badge'       => array( 'label' => __( 'Autoridade editorial', 'go-verge' ), 'color' => 'orange' ),
		'description' => '<p>' . esc_html( sprintf( __( 'Complete bio e função editorial de: %s. Bylines devem levar a informações reais sobre quem produziu o conteúdo.', 'go-verge' ), implode( ', ', array_slice( $missing, 0, 8 ) ) ) ) . '</p>',
		'actions'     => '<p><a href="' . esc_url( admin_url( 'users.php' ) ) . '">' . esc_html__( 'Revisar autores', 'go-verge' ) . '</a></p>',
		'test'        => 'go_verge_author_profiles',
	);
}


/** Filtered versions of the Latest hub are useful UI states, not search landing pages. */
function go_verge_latest_filter_robots( $robots ) {
	if ( is_page( 'ultimas-publicacoes' ) && isset( $_GET['editoria'] ) && '' !== sanitize_key( wp_unslash( $_GET['editoria'] ) ) ) {
		if ( is_array( $robots ) ) {
			$robots['noindex'] = true;
			$robots['follow']  = true;
			unset( $robots['index'] );
		}
	}
	return $robots;
}
add_filter( 'wp_robots', 'go_verge_latest_filter_robots', 220 );

function go_verge_latest_filter_rank_math_robots( $robots ) {
	if ( is_page( 'ultimas-publicacoes' ) && isset( $_GET['editoria'] ) && '' !== sanitize_key( wp_unslash( $_GET['editoria'] ) ) && is_array( $robots ) ) {
		$robots['index']  = 'noindex';
		$robots['follow'] = 'follow';
	}
	return $robots;
}
add_filter( 'rank_math/frontend/robots', 'go_verge_latest_filter_rank_math_robots', 220 );
