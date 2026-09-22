<?php
/**
 * Indexing integrity: self-canonical repair and redirect-aware sitemaps.
 *
 * Found in production on 18/09/2026:
 *
 * 1. 101 published posts (16/05–08/06/2026) stored `rank_math_canonical_url`
 *    = https://gameoverdrive.com.br/?p=<their own ID>. Rank Math printed that
 *    plain URL as canonical, og:url and WebPage @id, and the plain URL
 *    301-redirects back to the article, so Google was told "the official
 *    version is another URL, which redirects here". The theme sitemap also
 *    excluded those posts as "custom canonical".
 * 2. Published posts whose address Rank Math Redirections answers with a 301
 *    were still listed in /sitemap-posts.xml.
 *
 * This module treats any canonical that resolves to the same post as
 * self-canonical (output, sitemap, save), deletes such stored values once, and
 * keeps URLs that Rank Math would redirect out of every sitemap. It also powers
 * the "Integridade de indexação" report in Ferramentas → Sitemap Intelligence.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Repair a verified reverse redirect without changing stored redirect rules.
 * The published ID/current permalink were confirmed through WordPress REST.
 * Rank Math sends this canonical URL to its July alias; WordPress sends that
 * old slug back. Cancel only this proven reverse hop. The supplied Rank Math
 * Redirector exits only when wp_redirect succeeds, so normal rendering resumes.
 * Remove the obsolete provider rule and purge both cached URLs when deploying.
 */
function go_verge_is_verified_reverse_redirect( $source, $destination, $status = 301 ) {
	$source_path = '/codigos-99-noites-na-floresta-2026/';
	$old_path = '/codigos-99-noites-na-floresta-julho-2026/';
	if ( 301 !== (int) $status || wp_parse_url( (string) $source, PHP_URL_PATH ) !== $source_path || wp_parse_url( (string) $destination, PHP_URL_PATH ) !== $old_path ) { return false; }
	if ( 'post' !== get_post_type( 32393 ) || 'publish' !== get_post_status( 32393 ) || post_password_required( 32393 ) ) { return false; }
	$canonical = (string) get_permalink( 32393 );
	if ( wp_parse_url( $canonical, PHP_URL_PATH ) !== $source_path ) { return false; }
	$canonical_host = wp_parse_url( $canonical, PHP_URL_HOST );
	foreach ( array( $source, $destination ) as $url ) {
		$host = wp_parse_url( (string) $url, PHP_URL_HOST );
		if ( $host && strtolower( $host ) !== strtolower( (string) $canonical_host ) ) { return false; }
		if ( $host && wp_parse_url( (string) $url, PHP_URL_PORT ) !== wp_parse_url( $canonical, PHP_URL_PORT ) ) { return false; }
		$scheme = wp_parse_url( (string) $url, PHP_URL_SCHEME );
		if ( $host && $scheme && $scheme !== wp_parse_url( $canonical, PHP_URL_SCHEME ) ) { return false; }
	}
	return true;
}
function go_verge_preserve_verified_story_permalink( $location, $status ) {
	if ( is_admin() || wp_doing_ajax() || ! is_singular( 'post' ) || 32393 !== (int) get_queried_object_id() ) { return $location; }
	$request = isset( $_SERVER['REQUEST_URI'] ) && is_string( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '';
	return go_verge_is_verified_reverse_redirect( $request, $location, $status ) ? false : $location;
}
add_filter( 'wp_redirect', 'go_verge_preserve_verified_story_permalink', 9999, 2 );

const GO_VERGE_SELF_CANONICAL_CLEANUP_OPTION = 'go_verge_self_canonical_cleanup_v1';

/**
 * Host + path identity for URL comparison: scheme, "www." and a trailing slash
 * do not make two addresses different documents.
 *
 * @param string $url Absolute URL.
 * @return string Empty when the URL has no host.
 */
function go_verge_indexing_url_key( $url ) {
	$parts = wp_parse_url( trim( (string) $url ) );
	if ( ! is_array( $parts ) || empty( $parts['host'] ) ) {
		return '';
	}
	$host = strtolower( (string) preg_replace( '/^www\./i', '', (string) $parts['host'] ) );
	$path = rtrim( (string) ( $parts['path'] ?? '' ), '/' );
	return $host . ( '' === $path ? '/' : $path );
}

/**
 * Every public address WordPress uses for one post: its permalink and, for a
 * post that is not published yet, the permalink it will have (sample link).
 *
 * @param int $post_id Post ID.
 * @return string[]
 */
function go_verge_indexing_self_urls( $post_id ) {
	$post = get_post( $post_id );
	if ( ! ( $post instanceof WP_Post ) ) {
		return array();
	}
	$urls = array( (string) get_permalink( $post ) );
	if ( 'publish' !== $post->post_status && '' !== (string) $post->post_name ) {
		$sample              = clone $post;
		$sample->post_status = 'publish';
		$sample->filter      = 'sample';
		$urls[]              = (string) get_permalink( $sample );
	}
	return array_values( array_unique( array_filter( $urls ) ) );
}

/**
 * Whether a canonical value points at the post it belongs to.
 *
 * Covers the plain link (/?p=ID, /?page_id=ID), relative values, and the
 * permalink written with another scheme, "www." or trailing slash. A canonical
 * with extra query arguments, another path or another host is a deliberate
 * canonical and is left alone.
 *
 * @param string $url     Canonical value.
 * @param int    $post_id Post the value belongs to.
 * @return bool
 */
function go_verge_canonical_points_to_self( $url, $post_id ) {
	$url     = trim( (string) $url );
	$post_id = absint( $post_id );
	if ( '' === $url || ! $post_id ) {
		return false;
	}
	if ( 0 === strpos( $url, '/' ) && 0 !== strpos( $url, '//' ) ) {
		$url = home_url( $url );
	}
	$parts = wp_parse_url( $url );
	if ( ! is_array( $parts ) || empty( $parts['host'] ) ) {
		return false;
	}
	$home      = wp_parse_url( home_url( '/' ) );
	$site_host = strtolower( (string) preg_replace( '/^www\./i', '', (string) ( $home['host'] ?? '' ) ) );
	if ( strtolower( (string) preg_replace( '/^www\./i', '', (string) $parts['host'] ) ) !== $site_host ) {
		return false;
	}
	/* Standard http/https variants are the documented self aliases. A custom
	 * port identifies a different origin and must never be erased by cleanup. */
	$port_key = static function ( $value ) {
		$scheme = strtolower( (string) ( $value['scheme'] ?? 'https' ) );
		$port = isset( $value['port'] ) ? (int) $value['port'] : 0;
		if ( ( 'https' === $scheme && 443 === $port ) || ( 'http' === $scheme && 80 === $port ) ) { return 0; }
		return $port;
	};
	if ( $port_key( $parts ) !== $port_key( $home ) ) { return false; }

	if ( ! empty( $parts['query'] ) ) {
		parse_str( (string) $parts['query'], $query );
		/* A plain permalink contains one decimal identifier, without additional
		 * parameters. absint alone also accepted -42 and 42suffix as post 42. */
		if ( 1 !== count( $query ) || 1 !== count( explode( '&', (string) $parts['query'] ) ) ) { return false; }
		$home_path = rtrim( (string) ( $home['path'] ?? '' ), '/' );
		$path      = rtrim( (string) ( $parts['path'] ?? '' ), '/' );
		if ( $path !== $home_path && $path !== $home_path . '/index.php' ) {
			return false;
		}
		foreach ( array( 'p', 'page_id' ) as $key ) {
			if ( isset( $query[ $key ] ) && is_string( $query[ $key ] ) && preg_match( '/^[0-9]+$/D', $query[ $key ] ) && (int) $query[ $key ] === $post_id ) {
				return true;
			}
		}
		return false;
	}

	$key = go_verge_indexing_url_key( $url );
	foreach ( go_verge_indexing_self_urls( $post_id ) as $candidate ) {
		if ( '' !== $key && $key === go_verge_indexing_url_key( $candidate ) ) {
			return true;
		}
	}
	return false;
}

/**
 * Output: a self-equivalent canonical is printed as the permalink itself.
 *
 * Rank Math uses this value for <link rel="canonical">, og:url and the WebPage
 * @id/url of the schema graph, so one correction fixes all three.
 *
 * @param string $canonical Canonical chosen by Rank Math.
 * @return string
 */
function go_verge_indexing_self_canonical( $canonical ) {
	if ( ! is_singular() || '' === trim( (string) $canonical ) ) {
		return $canonical;
	}
	$post_id   = absint( get_queried_object_id() );
	$permalink = $post_id ? (string) get_permalink( $post_id ) : '';
	if ( '' === $permalink || $permalink === $canonical ) {
		return $canonical;
	}
	return go_verge_canonical_points_to_self( $canonical, $post_id ) ? $permalink : $canonical;
}
add_filter( 'rank_math/frontend/canonical', 'go_verge_indexing_self_canonical', 5 );

/**
 * Save: an override equal to the post's own address means "no override".
 * The value is removed instead of stored, so it cannot come back through an
 * import, a copy of the Rank Math box or an editor pasting the plain link.
 *
 * @param null|bool $check      Short-circuit value.
 * @param int       $object_id  Post ID.
 * @param string    $meta_key   Meta key.
 * @param mixed     $meta_value New value.
 * @return null|bool
 */
function go_verge_indexing_refuse_self_canonical_meta( $check, $object_id, $meta_key, $meta_value ) {
	if ( null !== $check || 'rank_math_canonical_url' !== $meta_key || ! is_string( $meta_value ) || '' === trim( $meta_value ) ) {
		return $check;
	}
	if ( ! go_verge_canonical_points_to_self( $meta_value, $object_id ) ) {
		return $check;
	}
	delete_post_meta( $object_id, 'rank_math_canonical_url' );
	return true;
}
add_filter( 'update_post_metadata', 'go_verge_indexing_refuse_self_canonical_meta', 10, 4 );
add_filter( 'add_post_metadata', 'go_verge_indexing_refuse_self_canonical_meta', 10, 4 );

/**
 * One-time repair of stored self-canonicals (admin, idempotent, batched).
 *
 * Runs on the first administrator request after the update. Each repaired post
 * is purged from LiteSpeed and the sitemap epoch is bumped once, so the
 * articles re-enter /sitemap-posts.xml with their real canonical.
 *
 * @return void
 */
function go_verge_indexing_repair_self_canonicals() {
	if ( ! is_admin() || wp_doing_ajax() || ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$state = get_option( GO_VERGE_SELF_CANONICAL_CLEANUP_OPTION, array() );
	if ( is_array( $state ) && ! empty( $state['done'] ) ) {
		return;
	}
	$state = is_array( $state ) ? $state : array();

	global $wpdb;
	$after = absint( $state['cursor'] ?? 0 );
	$rows  = $wpdb->get_results( // phpcs:ignore WordPress.DB.DirectDatabaseQuery
		$wpdb->prepare(
			"SELECT meta_id, post_id, meta_value FROM {$wpdb->postmeta} WHERE meta_key = 'rank_math_canonical_url' AND meta_value <> '' AND meta_id > %d ORDER BY meta_id ASC LIMIT 400",
			$after
		),
		ARRAY_A
	);

	$fixed = isset( $state['fixed'] ) && is_array( $state['fixed'] ) ? $state['fixed'] : array();
	foreach ( (array) $rows as $row ) {
		$state['cursor'] = absint( $row['meta_id'] );
		$post_id         = absint( $row['post_id'] );
		if ( ! $post_id || ! go_verge_canonical_points_to_self( (string) $row['meta_value'], $post_id ) ) {
			continue;
		}
		delete_post_meta( $post_id, 'rank_math_canonical_url' );
		do_action( 'litespeed_purge_post', $post_id );
		if ( count( $fixed ) < 500 ) {
			$fixed[] = array( 'id' => $post_id, 'was' => substr( (string) $row['meta_value'], 0, 190 ) );
		}
		$state['count'] = absint( $state['count'] ?? 0 ) + 1;
	}
	$state['fixed'] = $fixed;

	if ( count( (array) $rows ) < 400 ) {
		$state['done'] = true;
		$state['time'] = time();
		if ( ! empty( $state['count'] ) && function_exists( 'go_verge_smart_sitemap_bump' ) ) {
			go_verge_smart_sitemap_bump();
		}
	}
	update_option( GO_VERGE_SELF_CANONICAL_CLEANUP_OPTION, $state, false );
}
add_action( 'admin_init', 'go_verge_indexing_repair_self_canonicals', 99 );

/**
 * Active Rank Math redirection rules, loaded once per request.
 *
 * Exact sources go to a hash map (the common case); other comparisons keep
 * Rank Math's own matcher, DB::compare_sources(), so the sitemap decides
 * exactly like the redirector that answers the visitor.
 *
 * @return array{exact: array<string,string>, rules: array<int,array<string,mixed>>}
 */
function go_verge_rank_math_redirection_rules() {
	static $rules = null;
	if ( null !== $rules ) {
		return $rules;
	}
	$rules = array( 'exact' => array(), 'exact_codes' => array(), 'rules' => array() );
	if ( ! class_exists( '\\RankMath\\Redirections\\DB' ) || ! method_exists( '\\RankMath\\Redirections\\DB', 'compare_sources' ) ) {
		return $rules;
	}
	if ( class_exists( '\\RankMath\\Helper' ) && method_exists( '\\RankMath\\Helper', 'is_module_active' ) && ! \RankMath\Helper::is_module_active( 'redirections' ) ) {
		return $rules;
	}

	global $wpdb;
	$table = $wpdb->prefix . 'rank_math_redirections';
	if ( $table !== $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) ) ) { // phpcs:ignore WordPress.DB.DirectDatabaseQuery
		return $rules;
	}
	$rows = $wpdb->get_results( "SELECT sources, url_to, header_code FROM {$table} WHERE status = 'active'", ARRAY_A ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	foreach ( (array) $rows as $row ) {
		$sources = maybe_unserialize( $row['sources'] );
		if ( ! is_array( $sources ) || ! $sources ) {
			continue;
		}
		$target = '' !== trim( (string) $row['url_to'] ) ? (string) $row['url_to'] : 'http-' . absint( $row['header_code'] );
		$other  = array();
		foreach ( $sources as $source ) {
			if ( ! is_array( $source ) || ! isset( $source['pattern'] ) ) {
				continue;
			}
			if ( 'exact' === ( $source['comparison'] ?? 'exact' ) ) {
				$key = trim( (string) $source['pattern'], '/' );
				$key = isset( $source['ignore'] ) && 'case' === $source['ignore'] ? strtolower( $key ) : $key;
				if ( '' !== $key && ! isset( $rules['exact'][ $key ] ) ) {
					$rules['exact'][ $key ] = $target;
					$rules['exact_codes'][ $key ] = absint( $row['header_code'] );
				}
			} else {
				$other[] = $source;
			}
		}
		if ( $other ) {
			$rules['rules'][] = array( 'sources' => $other, 'to' => $target, 'header_code' => absint( $row['header_code'] ) );
		}
	}
	return $rules;
}

/**
 * Destination Rank Math Redirections would send this public URL to.
 *
 * @param string $url Absolute URL on this site.
 * @return string Target URL, "http-410"-style marker, or '' when not redirected.
 */
function go_verge_rank_math_redirect_target( $url ) {
	$rules = go_verge_rank_math_redirection_rules();
	if ( ! $rules['exact'] && ! $rules['rules'] ) {
		return '';
	}
	$path      = trim( (string) wp_parse_url( (string) $url, PHP_URL_PATH ), '/' );
	$home_path = trim( (string) wp_parse_url( home_url( '/' ), PHP_URL_PATH ), '/' );
	if ( '' !== $home_path && 0 === strpos( $path . '/', $home_path . '/' ) ) {
		$path = trim( substr( $path, strlen( $home_path ) ), '/' );
	}
	if ( '' === $path ) {
		return '';
	}
	if ( isset( $rules['exact'][ $path ] ) ) {
		$target = $rules['exact'][ $path ];
		return go_verge_is_verified_reverse_redirect( $url, $target, $rules['exact_codes'][ $path ] ?? 0 ) ? '' : $target;
	}
	if ( isset( $rules['exact'][ strtolower( $path ) ] ) ) {
		$key = strtolower( $path );
		$target = $rules['exact'][ $key ];
		return go_verge_is_verified_reverse_redirect( $url, $target, $rules['exact_codes'][ $key ] ?? 0 ) ? '' : $target;
	}
	foreach ( $rules['rules'] as $rule ) {
		if ( \RankMath\Redirections\DB::compare_sources( $rule['sources'], $path ) ) {
			return go_verge_is_verified_reverse_redirect( $url, $rule['to'], $rule['header_code'] ?? 0 ) ? '' : $rule['to'];
		}
	}
	return '';
}

/**
 * A redirect added, edited or removed in Rank Math changes which URLs may be
 * listed; bump the sitemap epoch instead of waiting for the hourly rebuild.
 *
 * @return void
 */
function go_verge_indexing_redirections_changed() {
	if ( function_exists( 'go_verge_smart_sitemap_bump' ) ) {
		go_verge_smart_sitemap_bump();
	}
}
add_action( 'rank_math/redirection/deleted', 'go_verge_indexing_redirections_changed' );
add_action( 'rank_math/redirection/post_updated', 'go_verge_indexing_redirections_changed' );
add_action( 'rank_math/redirection/term_updated', 'go_verge_indexing_redirections_changed' );

/**
 * Report data for Ferramentas → Sitemap Intelligence.
 *
 * Whole-site checks with light SQL (post_name/meta only), never page fetches.
 *
 * @return array<string,mixed>
 */
function go_verge_indexing_integrity_report() {
	global $wpdb;
	$report = array();

	/* Published posts that Rank Math answers with a redirect: the URL is gone
	 * for Google, so the post only competes with its own destination. */
	$redirected = array();
	$rules      = go_verge_rank_math_redirection_rules();
	if ( $rules['exact'] || $rules['rules'] ) {
		$ids = array_map( 'absint', (array) $wpdb->get_col( "SELECT ID FROM {$wpdb->posts} WHERE post_type = 'post' AND post_status = 'publish' AND post_password = '' ORDER BY post_date DESC" ) ); // phpcs:ignore WordPress.DB.DirectDatabaseQuery
		foreach ( array_chunk( $ids, 500 ) as $chunk ) {
			_prime_post_caches( $chunk, false, false );
		}
		foreach ( $ids as $id ) {
			$target = go_verge_rank_math_redirect_target( (string) get_permalink( (int) $id ) );
			if ( '' !== $target ) {
				$redirected[] = array( 'id' => (int) $id, 'to' => $target );
			}
		}
	}
	$report['redirected'] = $redirected;

	/* The same story published twice: "slug" and "slug-2" both live. */
	$report['duplicates'] = $wpdb->get_results( // phpcs:ignore WordPress.DB.DirectDatabaseQuery
		"SELECT a.ID AS dup_id, b.ID AS base_id FROM {$wpdb->posts} a
		 INNER JOIN {$wpdb->posts} b ON b.post_name = LEFT( a.post_name, CHAR_LENGTH( a.post_name ) - 2 )
		 WHERE a.post_type = 'post' AND a.post_status = 'publish' AND b.post_type = 'post' AND b.post_status = 'publish'
		   AND a.post_name REGEXP '-[2-9]$' AND a.ID <> b.ID
		 ORDER BY a.post_date DESC LIMIT 300",
		ARRAY_A
	);

	/* Slugs that leaked the editor placeholder ("rascunho-automatico…"). Only
	 * unambiguous placeholders are listed; real words are never guessed at. */
	$report['bad_slugs'] = $wpdb->get_col( // phpcs:ignore WordPress.DB.DirectDatabaseQuery
		"SELECT ID FROM {$wpdb->posts} WHERE post_type = 'post' AND post_status = 'publish'
		 AND ( post_name LIKE 'rascunho%' OR post_name LIKE 'auto-draft%' OR post_name LIKE 'sem-titulo%' )
		 ORDER BY post_date DESC LIMIT 100"
	);

	/* Remaining stored canonicals that point elsewhere (deliberate, but worth a look). */
	$report['custom_canonicals'] = (int) $wpdb->get_var( // phpcs:ignore WordPress.DB.DirectDatabaseQuery
		"SELECT COUNT(*) FROM {$wpdb->postmeta} pm INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
		 WHERE pm.meta_key = 'rank_math_canonical_url' AND pm.meta_value <> '' AND p.post_type = 'post' AND p.post_status = 'publish'"
	);

	$report['cleanup'] = get_option( GO_VERGE_SELF_CANONICAL_CLEANUP_OPTION, array() );
	return $report;
}

/**
 * Printed inside the Sitemap Intelligence screen.
 *
 * @return void
 */
function go_verge_indexing_integrity_render() {
	$r       = go_verge_indexing_integrity_report();
	$cleanup = is_array( $r['cleanup'] ) ? $r['cleanup'] : array();
	$link    = static function ( $id ) {
		$id   = absint( $id );
		$edit = get_edit_post_link( $id );
		$html = '<a href="' . esc_url( (string) get_permalink( $id ) ) . '" target="_blank" rel="noopener">' . esc_html( get_the_title( $id ) ) . '</a>';
		return $edit ? $html . ' · <a href="' . esc_url( $edit ) . '">editar</a>' : $html;
	};
	?>
	<hr style="max-width:980px;margin:22px 0">
	<h2>Integridade de indexação (site inteiro)</h2>
	<p style="max-width:980px">Verificação de todas as matérias publicadas, não só das 80 recentes. Um item aqui não é penalidade do Google: é um sinal técnico ou editorial contraditório que o tema já corrige quando pode e aponta quando a decisão é editorial.</p>

	<h3>1. Canonical apontando para a própria matéria por outro endereço</h3>
	<?php if ( ! empty( $cleanup['done'] ) ) : ?>
		<p><strong><?php echo esc_html( number_format_i18n( absint( $cleanup['count'] ?? 0 ) ) ); ?></strong> canonical(s) do tipo <code>/?p=ID</code> ou equivalente foram removidos em <?php echo esc_html( wp_date( 'd/m/Y H:i', absint( $cleanup['time'] ?? time() ) ) ); ?>. Essas matérias voltaram ao sitemap com o endereço real e o tema impede que o valor volte a ser salvo.</p>
		<?php if ( ! empty( $cleanup['fixed'] ) ) : ?>
			<details style="max-width:980px"><summary>Ver matérias corrigidas</summary><ul>
			<?php foreach ( array_slice( (array) $cleanup['fixed'], 0, 200 ) as $item ) : ?>
				<li><?php echo $link( $item['id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- escaped in $link. ?> <small>(era <code><?php echo esc_html( (string) $item['was'] ); ?></code>)</small></li>
			<?php endforeach; ?>
			</ul></details>
		<?php endif; ?>
	<?php else : ?>
		<p>A correção roda automaticamente no painel (em lotes); recarregue esta página para concluir.</p>
	<?php endif; ?>
	<p>Canonicals deliberados para outra URL ainda gravados: <strong><?php echo esc_html( number_format_i18n( $r['custom_canonicals'] ) ); ?></strong> (ficam fora do sitemap por decisão editorial).</p>

	<h3>2. Matérias publicadas que o Rank Math redireciona</h3>
	<?php if ( empty( $r['redirected'] ) ) : ?>
		<p>Nenhuma.</p>
	<?php else : ?>
		<p><strong><?php echo esc_html( number_format_i18n( count( $r['redirected'] ) ) ); ?></strong> matéria(s) publicadas têm regras de redirecionamento e ficam fora do sitemap. Confirme se cada regra é intencional, se o destino preserva o conteúdo e se não existe um ciclo. Corrija apenas a regra comprovadamente errada em Rank Math → Redirecionamentos; não despublique o acervo em lote.</p>
		<table class="widefat striped" style="max-width:980px"><thead><tr><th>Matéria publicada</th><th>Redireciona para</th></tr></thead><tbody>
		<?php foreach ( array_slice( $r['redirected'], 0, 150 ) as $item ) : ?>
			<tr><td><?php echo $link( $item['id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></td><td><code><?php echo esc_html( (string) $item['to'] ); ?></code></td></tr>
		<?php endforeach; ?>
		</tbody></table>
	<?php endif; ?>

	<h3>3. Endereços semelhantes para revisão (<code>slug</code> e <code>slug-2</code>)</h3>
	<?php if ( empty( $r['duplicates'] ) ) : ?>
		<p>Nenhuma.</p>
	<?php else : ?>
		<p><strong><?php echo esc_html( number_format_i18n( count( $r['duplicates'] ) ) ); ?></strong> par(es) com slugs semelhantes. Isso não comprova conteúdo duplicado. Compare o texto, a intenção e os dados do Search Console antes de decidir por atualização ou consolidação. Preserve informações exclusivas e prepare redirecionamento somente quando houver equivalência editorial.</p>
		<table class="widefat striped" style="max-width:980px"><thead><tr><th>Original</th><th>Duplicada</th></tr></thead><tbody>
		<?php foreach ( $r['duplicates'] as $pair ) : ?>
			<tr><td><?php echo $link( $pair['base_id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></td><td><?php echo $link( $pair['dup_id'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></td></tr>
		<?php endforeach; ?>
		</tbody></table>
	<?php endif; ?>

	<h3>4. Endereços com resto de rascunho</h3>
	<?php if ( empty( $r['bad_slugs'] ) ) : ?>
		<p>Nenhum.</p>
	<?php else : ?>
		<p>Revise os endereços abaixo. Só altere uma URL publicada quando a correção for necessária; nesse caso, preserve o endereço antigo com um redirecionamento para o novo e verifique os dois sentidos para evitar ciclos.</p>
		<ul><?php foreach ( $r['bad_slugs'] as $id ) : ?><li><?php echo $link( $id ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?> <code><?php echo esc_html( (string) get_post_field( 'post_name', (int) $id ) ); ?></code></li><?php endforeach; ?></ul>
	<?php endif; ?>
	<?php
}
