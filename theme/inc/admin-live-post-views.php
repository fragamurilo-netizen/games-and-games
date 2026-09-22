<?php
/**
 * Overdrive Posts Intelligence 3.50.
 *
 * Turns wp-admin > Posts into a newsroom decision surface: live/Today/lifetime
 * audience, page-level AdSense revenue, recent Search/Discover performance,
 * Google readiness, legitimate discovery/indexing actions and a small daily
 * revenue radar. All expensive Google calls are cached and separated from the
 * 30-second first-party live pulse, which pauses on idle or hidden tabs.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Public performance exists only after a post is actually published.
 *
 * Drafts, pending posts, auto-drafts and revisions can have a provisional
 * permalink whose path collides with historical GA4/Pulse/AdSense data. Never
 * attribute public traffic or revenue to those objects.
 */
function go_verge_admin_post_has_public_history( $post_id ) {
	$post = get_post( absint( $post_id ) );
	return $post instanceof WP_Post && 'post' === $post->post_type && 'publish' === $post->post_status;
}

/** Small accessible help marker used in the Posts intelligence table. */
function go_verge_admin_metric_help( $label, $help ) {
	static $seq = 0; $seq++; $id = 'go-pi-tip-' . $seq;
	return '<span class="go-pi-help-wrap"><button type="button" class="go-pi-help" aria-label="' . esc_attr( 'Explicar: ' . wp_strip_all_tags( (string) $label ) ) . '" aria-describedby="' . esc_attr( $id ) . '" data-help="' . esc_attr( $help ) . '" aria-expanded="false">?</button><span class="go-pi-tooltip" role="tooltip" id="' . esc_attr( $id ) . '" aria-hidden="true" hidden>' . esc_html( $help ) . '</span></span><span class="screen-reader-text"> ' . esc_html( $label ) . '</span>';
}

/** Add only decision-useful columns. */
function go_verge_admin_live_views_column( $columns ) {
	$out = array();
	foreach ( $columns as $key => $label ) {
		$out[ $key ] = $label;
		if ( 'title' === $key ) {
			$out['go_audience']     = __( 'Audiência', 'go-verge' ) . ' ' . go_verge_admin_metric_help( 'Audiência', 'Sinais de consumo da URL: views de hoje, sessões ativas agora e histórico público acumulado. Rascunhos não herdam histórico.' );
			$out['go_revenue']      = __( 'Receita', 'go-verge' ) . ' ' . go_verge_admin_metric_help( 'Receita', 'Receita AdSense atribuída à URL pública usando snapshots persistidos. O wp-admin não espera a API externa para renderizar a lista.' );
			$out['go_index_status'] = __( 'Posição na SERP', 'go-verge' ) . ' ' . go_verge_admin_metric_help( 'Posição na SERP', 'Prioriza a posição média das últimas 24 horas com granularidade horária importada do Search Console; quando ainda não há amostra recente, usa 7 dias como fallback. Os dados horários são preliminares e podem mudar.' );
			$out['go_google']       = __( 'Google 2026', 'go-verge' ) . ' ' . go_verge_admin_metric_help( 'Google 2026', 'Checklist editorial/técnico para indexação e descoberta, mais sinais recentes de Search/Discover. Não é uma nota oficial do Google.' );
		}
	}
	return $out;
}
add_filter( 'manage_post_posts_columns', 'go_verge_admin_live_views_column', 40 );

function go_verge_admin_live_views_cell( $column, $post_id ) {
	$post_id = absint( $post_id );
	$published = go_verge_admin_post_has_public_history( $post_id );
	if ( 'go_audience' === $column ) {
		if ( ! $published ) {
			printf( '<div class="go-pi-audience is-unpublished" data-post-id="%d" data-published="0"><strong>Não publicado</strong><small>Sem audiência pública atribuída.</small><small>Publicar inicia o histórico desta URL.</small></div>', $post_id );
			return;
		}
		printf(
			'<div class="go-pi-audience" data-post-id="%1$d" data-published="1"><strong class="go-pi-today">… hoje %2$s</strong><span class="go-pi-live"><i></i><b>…</b> agora %3$s</span><small class="go-pi-life">Vida da URL: … %4$s</small><small class="go-pi-search"></small></div>',
			$post_id,
			go_verge_admin_metric_help( 'Hoje', 'Visualizações registradas hoje para a URL pública deste post. O Pulse local atualiza rapidamente; GA4 pode ser usado no histórico.' ),
			go_verge_admin_metric_help( 'Agora', 'Sessões vistas nesta URL nos últimos 90 segundos pelo Traffic Pulse local. Não é o mesmo que pageviews.' ),
			go_verge_admin_metric_help( 'Vida da URL', 'Visualizações acumuladas da URL canônica desde que ela existe. Se o slug/URL foi reutilizado no passado, o histórico pertence à URL; rascunhos nunca herdam esse dado.' )
		);
	}
	if ( 'go_revenue' === $column ) {
		if ( ! $published ) {
			printf( '<div class="go-pi-revenue is-unpublished" data-post-id="%d" data-published="0"><strong>—</strong><small>Sem receita pública.</small><small>Rascunho não consulta histórico da URL.</small></div>', $post_id );
			return;
		}
		printf(
			'<div class="go-pi-revenue" data-post-id="%1$d" data-published="1"><strong class="go-pi-money-today">… hoje %2$s</strong><small class="go-pi-money-life">Vida da URL: … %3$s</small><small class="go-pi-rpm">RPM URL hoje: … %4$s</small></div>',
			$post_id,
			go_verge_admin_metric_help( 'Receita hoje', 'Ganhos estimados do AdSense atribuídos à PAGE_URL deste post hoje. É dado por URL, não uma multiplicação do RPM médio do site.' ),
			go_verge_admin_metric_help( 'Receita vida da URL', 'Ganhos estimados acumulados que o AdSense consegue atribuir a esta PAGE_URL no período disponível. É histórico da URL pública.' ),
			go_verge_admin_metric_help( 'Page RPM da URL', 'Receita estimada da URL por mil pageviews hoje: ganhos da própria URL ÷ pageviews da própria URL × 1.000.' )
		);
	}
	if ( 'go_index_status' === $column ) {
		$gsc_ready = class_exists( 'GED_Search_Console' ) && method_exists( 'GED_Search_Console', 'connected' ) && GED_Search_Console::connected();
		if ( ! $published ) {
			printf( '<div class="go-pi-index is-unpublished" data-post-id="%d" data-published="0"><span class="go-pi-index-badge is-muted">Não publicado</span><small>A URL ainda não pode aparecer na SERP.</small></div>', $post_id );
			return;
		}
		if ( ! $gsc_ready ) {
			printf( '<div class="go-pi-index" data-post-id="%1$d" data-published="1"><span class="go-pi-index-badge is-warn">Search Console offline</span><strong class="go-pi-serp-state">Sem dados Search importados</strong><small class="go-pi-serp-detail">Conecte o Search Console para preencher o relatório de Performance.</small><a class="go-pi-connect-gsc" href="%2$s">Conectar Search Console</a></div>', $post_id, esc_url( function_exists( 'go_verge_search_console_setup_url' ) ? go_verge_search_console_setup_url() : admin_url( 'tools.php' ) ) );
			return;
		}
		printf( '<div class="go-pi-index is-loading" data-post-id="%d" data-published="1"><span class="go-pi-index-badge">Consultando…</span><strong class="go-pi-serp-state">Posição recente · 24h</strong><small class="go-pi-serp-detail">Lendo a amostra horária mais recente do Search Console.</small></div>', $post_id );
	}

	if ( 'go_google' === $column ) {
		$readiness = class_exists( 'GED_Rank_Math' ) && method_exists( 'GED_Rank_Math', 'google_readiness' ) ? GED_Rank_Math::google_readiness( $post_id ) : array();
		$gsc_ready = class_exists( 'GED_Search_Console' ) && method_exists( 'GED_Search_Console', 'connected' ) && GED_Search_Console::connected();
		$score = isset( $readiness['score'] ) ? absint( $readiness['score'] ) : null;
		$verdict = isset( $readiness['verdict'] ) ? (string) $readiness['verdict'] : 'Aguardando Lume';
		$badge = null === $score ? '—' : $score . '/100';
		$disabled = ( ! $published || ! $gsc_ready );
		$title = ! $published ? 'Publique a matéria antes de enviar sinais de descoberta ao Google.' : ( $gsc_ready ? 'Atualiza os sitemaps, envia pelo Search Console e consulta a inspeção da URL. Não é uma promessa de indexação.' : 'Conecte o Lume ao Search Console.' );
		printf(
			'<div class="go-pi-google" data-post-id="%1$d" data-published="%5$d"><span class="go-pi-google-score"><strong>%2$s</strong><small>%3$s %6$s</small></span><span class="go-pi-surfaces"></span><button type="button" class="button button-small go-pi-send-google" data-post-id="%1$d"%4$s title="%7$s">Enviar ao Google</button><small class="go-pi-google-status"></small></div>',
			$post_id,
			esc_html( $badge ),
			esc_html( $verdict ),
			$disabled ? ' disabled' : '',
			$published ? 1 : 0,
			go_verge_admin_metric_help( 'Google 2026', 'Checklist técnico/editorial do Lume. Não é uma pontuação oficial do Google nem previsão de ranking.' ),
			esc_attr( $title )
		);
	}
}
add_action( 'manage_post_posts_custom_column', 'go_verge_admin_live_views_cell', 10, 2 );

function go_verge_admin_live_views_css() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'edit-post' !== $screen->id ) { return; }
	?>
	<style>
	.column-go_audience{width:170px}.column-go_revenue{width:155px}.column-go_index_status{width:178px}.column-go_google{width:190px}
	.go-pi-audience,.go-pi-revenue,.go-pi-index,.go-pi-google{display:flex;flex-direction:column;gap:3px;line-height:1.25;min-height:54px}.go-pi-audience.is-unpublished,.go-pi-revenue.is-unpublished,.go-pi-index.is-unpublished{opacity:.72}.go-pi-index{min-width:148px}.go-pi-index-badge{display:inline-flex;align-items:center;align-self:flex-start;min-height:21px;padding:0 7px;border-radius:999px;background:#f0f0f1;color:#50575e;font-size:10px;font-weight:750;white-space:nowrap}.go-pi-index-badge.is-ok{background:#dcfce7;color:#166534}.go-pi-index-badge.is-warn{background:#fff7d6;color:#7a4d00}.go-pi-index-badge.is-muted{background:#f0f0f1;color:#646970}.go-pi-index-badge.is-pos-excellent{background:#d9fbe5;color:#06752f}.go-pi-index-badge.is-pos-good{background:#e9f8ed;color:#287a3b}.go-pi-index-badge.is-pos-mid{background:#fff5cc;color:#7a5700}.go-pi-index-badge.is-pos-weak{background:#fff0ee;color:#a53a34}.go-pi-index-badge.is-pos-poor{background:#fde3e0;color:#9b1c17}.go-pi-connect-gsc{display:inline-flex;align-items:center;align-self:flex-start;margin-top:2px;color:#421aff;font-size:10px;font-weight:700;text-decoration:none}.go-pi-connect-gsc:hover,.go-pi-connect-gsc:focus{color:#2f0fc4;text-decoration:underline}.go-pi-serp-state{font-size:12px;color:#1d2327}.go-pi-serp-detail{font-size:10px;line-height:1.3}.go-pi-index.is-loading .go-pi-index-badge:before{content:"";width:6px;height:6px;margin-right:5px;border-radius:50%;background:#421aff;opacity:.55}@media(prefers-reduced-motion:reduce){.go-pi-index.is-loading .go-pi-index-badge:before{animation:none}}.go-pi-help-wrap{position:relative;display:inline-flex;align-items:center;vertical-align:middle}.go-pi-help{box-sizing:border-box;display:inline-grid;place-items:center;width:15px;height:15px;min-width:15px;padding:0;margin-left:3px;border:1px solid #a7aaad;border-radius:50%;background:#fff;color:#646970;font:700 9px/1 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;cursor:help;vertical-align:1px}.go-pi-help:hover,.go-pi-help:focus-visible{outline:none;border-color:#2271b1;color:#135e96;background:#f0f6fc}.go-pi-help:focus-visible{box-shadow:0 0 0 2px #72aee6}.go-pi-tooltip{display:none!important;position:fixed;z-index:1000000;width:min(290px,calc(100vw - 32px));padding:9px 10px;border-radius:6px;background:#1d2327;color:#fff;font-size:11px;font-weight:400;line-height:1.4;letter-spacing:0;text-align:left;white-space:normal;box-shadow:0 6px 20px rgba(0,0,0,.22);pointer-events:none}.go-pi-tooltip[hidden]{display:none!important}.go-pi-tooltip.is-visible:not([hidden]){display:block!important}.go-pi-filterbar{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin:10px 0 0}.go-pi-filterbar label{display:inline-flex;align-items:center;gap:5px;font-size:12px;color:#50575e}.go-pi-filterbar select{min-width:150px}.go-pi-row-hidden{display:none!important}.go-pi-audience small,.go-pi-revenue small,.go-pi-index small,.go-pi-google small{color:#646970}.go-pi-live{display:inline-flex;align-items:center;gap:5px;color:#2271b1;font-size:12px}.go-pi-live i{width:7px;height:7px;border-radius:50%;background:#16a34a;box-shadow:0 0 0 3px rgba(22,163,74,.12)}.go-pi-live b{font-variant-numeric:tabular-nums}.go-pi-money-today{color:#067647}.go-pi-google-score{display:flex;align-items:baseline;gap:6px}.go-pi-google-score strong{font-size:14px}.go-pi-surfaces{display:flex;gap:4px;flex-wrap:wrap}.go-pi-chip{font-size:10px;line-height:1;padding:3px 5px;border-radius:10px;background:#f0f0f1;color:#50575e}.go-pi-chip.ok{background:#dcfce7;color:#166534}.go-pi-chip.warn{background:#fff7d6;color:#7a4d00}.go-pi-google-status{white-space:normal}.go-pi-google-status.ok{color:#166534}.go-pi-google-status.err{color:#b32d2e}.go-pi-send-google{margin-top:2px;align-self:flex-start}
	#go-editorial-revenue-radar{margin:12px 20px 4px 0;padding:14px 16px;background:#fff;border:1px solid #dcdcde;border-left:4px solid #2271b1;border-radius:3px;box-shadow:0 1px 1px rgba(0,0,0,.03)}#go-editorial-revenue-radar h2{font-size:14px;margin:0 0 10px;display:flex;align-items:center;gap:8px}#go-editorial-revenue-radar .go-radar-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}.go-radar-card{padding:10px 12px;border:1px solid #e2e4e7;border-radius:6px;background:#fbfbfc}.go-radar-card strong{display:block;margin-bottom:4px}.go-radar-card p{margin:0;color:#50575e;font-size:12px;line-height:1.4}.go-radar-card a{text-decoration:none}@media(max-width:1100px){#go-editorial-revenue-radar .go-radar-grid{grid-template-columns:1fr}.column-go_google{display:none}}
	</style>
	<?php
}
add_action( 'admin_head-edit.php', 'go_verge_admin_live_views_css' );

function go_verge_admin_revenue_radar_shell() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'edit-post' !== $screen->id ) { return; }
	if ( ! array_diff( array('go_audience','go_revenue','go_index_status','go_google'), get_hidden_columns($screen) ) ) { return; }
	echo '<div id="go-editorial-revenue-radar"><h2>Radar editorial de receita ' . go_verge_admin_metric_help( 'Radar editorial de receita', 'Cruza audiência first-party, receita por URL e sinais Search/Discover para priorizar trabalho editorial. É apoio de decisão: não publica, não altera SEO e não muda dados sozinho.' ) . ' <span class="spinner is-active" style="float:none;margin:0"></span></h2><div class="go-radar-grid"><div class="go-radar-card"><strong>Lendo o dia…</strong><p>AdSense + audiência + Search/Discover.</p></div></div><div class="go-pi-filterbar" data-go-pi-filterbar><label>Mostrar ' . go_verge_admin_metric_help( 'Mostrar', 'Filtra apenas os posts já carregados nesta página por leitores ativos, receita ou superfície Google. Não altera o banco nem o post.' ) . ' <select data-go-pi-filter><option value="all">Todos</option><option value="serp">Com posição na SERP</option><option value="no_serp">Sem dados Search recentes</option><option value="live">Com leitores agora</option><option value="revenue">Rendendo hoje</option><option value="search">Com Search (7d)</option><option value="discover">Com Discover (7d)</option><option value="news">Com Google News (7d)</option><option value="unpublished">Não publicados</option></select></label><label>Ordenar ' . go_verge_admin_metric_help( 'Ordenar', 'Reordena visualmente somente esta página da lista por receita, audiência, presença na SERP ou RPM da URL. A ordem do WordPress permanece intacta.' ) . ' <select data-go-pi-sort><option value="default">Ordem do WordPress</option><option value="serp">Melhor posição SERP</option><option value="revenue">Receita hoje</option><option value="today">Views hoje</option><option value="life">Vida da URL</option><option value="rpm">RPM da URL</option></select></label><span class="description">Search = amostra horária das últimas 24h quando disponível; 7d é apenas fallback. Esta coluna mede Performance, não indexação; ausência de dados não prova desindexação.</span></div></div>';
}
add_action( 'all_admin_notices', 'go_verge_admin_revenue_radar_shell', 80 );

/** Canonical path/hash lookup without schema changes. */
function go_verge_admin_live_views_lookup( array $post_ids ) {
	$lookup = array( 'by_id'=>array(), 'by_hash'=>array(), 'by_path'=>array() );
	foreach ( array_slice( array_values( array_unique( array_filter( array_map( 'absint', $post_ids ) ) ) ), 0, 100 ) as $post_id ) {
		if ( ! go_verge_admin_post_has_public_history( $post_id ) ) { continue; }
		$url = get_permalink( $post_id ); if ( ! $url ) { continue; }
		$path = (string) wp_parse_url( $url, PHP_URL_PATH );
		if ( function_exists( 'go_verge_traffic_clean_path' ) ) { $path = go_verge_traffic_clean_path( $path ); }
		if ( '' === $path ) { $path = '/'; }
		$hash = md5( $path );
		$lookup['by_id'][ $post_id ] = array( 'path'=>$path, 'hash'=>$hash, 'url'=>$url );
		$lookup['by_hash'][ $hash ] = $post_id; $lookup['by_path'][ $path ] = $post_id;
	}
	return $lookup;
}

/**
 * Whether the Traffic Pulse read model exists on this install.
 *
 * Without it the live endpoint can only answer zeros, so the admin screens fill
 * those zeros locally instead of booting WordPress on a timer to learn them.
 */
function go_verge_admin_live_views_available() {
	return function_exists( 'go_verge_traffic_table_names' ) && ( ! function_exists( 'go_verge_traffic_schema_is_ready' ) || go_verge_traffic_schema_is_ready() );
}

/** Existing indexed Pulse tables: today, online now and all data retained locally. */
function go_verge_admin_live_views_query( array $post_ids ) {
	global $wpdb;
	$post_ids = array_slice( array_values( array_unique( array_filter( array_map( 'absint', $post_ids ) ) ) ), 0, 100 );
	$out = array(); foreach ( $post_ids as $id ) { $out[ $id ] = array( 'views'=>0, 'online'=>0, 'pulse_life'=>0 ); }
	if ( ! $post_ids || ! go_verge_admin_live_views_available() ) { return $out; }
	$lookup = go_verge_admin_live_views_lookup( $post_ids ); if ( empty( $lookup['by_id'] ) ) { return $out; }
	$t = go_verge_traffic_table_names(); $day = current_time( 'Y-m-d' ); $hashes = array_keys( $lookup['by_hash'] );
	$hash_ph = implode( ',', array_fill( 0, count( $hashes ), '%s' ) );
	$args = array_merge( array( $day ), $hashes );
	// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$rows = $wpdb->get_results( $wpdb->prepare( "SELECT path_hash,pageviews FROM {$t['pages']} WHERE day_key=%s AND path_hash IN ($hash_ph)", $args ), ARRAY_A );
	foreach ( (array) $rows as $row ) { $id=absint($lookup['by_hash'][(string)$row['path_hash']]??0); if($id){$out[$id]['views']=max(0,(int)$row['pageviews']);} }
	// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$rows = $wpdb->get_results( $wpdb->prepare( "SELECT path_hash,SUM(pageviews) pageviews FROM {$t['pages']} WHERE path_hash IN ($hash_ph) GROUP BY path_hash", $hashes ), ARRAY_A );
	foreach ( (array) $rows as $row ) { $id=absint($lookup['by_hash'][(string)$row['path_hash']]??0); if($id){$out[$id]['pulse_life']=max(0,(int)$row['pageviews']);} }
	$paths = array_keys( $lookup['by_path'] ); $path_ph = implode( ',', array_fill( 0, count( $paths ), '%s' ) ); $cutoff=time()-90;
	$args = array_merge( array( $cutoff ), $paths );
	// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
	$rows = $wpdb->get_results( $wpdb->prepare( "SELECT page_path,COUNT(*) online FROM {$t['sessions']} WHERE last_seen>=%d AND page_path IN ($path_ph) GROUP BY page_path", $args ), ARRAY_A );
	foreach ( (array) $rows as $row ) { $id=absint($lookup['by_path'][(string)$row['page_path']]??0); if($id){$out[$id]['online']=max(0,(int)$row['online']);} }
	return $out;
}

function go_verge_admin_live_views_ajax() {
	if ( ! current_user_can( 'edit_posts' ) ) { wp_send_json_error( array( 'message'=>'forbidden' ), 403 ); }
	check_ajax_referer( 'go_live_post_views', 'nonce' );
	$raw = isset($_POST['post_ids']) ? wp_unslash($_POST['post_ids']) : array(); $ids=is_array($raw)?$raw:explode(',',(string)$raw);
	$ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$ids)))),0,100);
	wp_send_json_success( array( 'counts'=>go_verge_admin_live_views_query($ids), 'as_of'=>time() ) );
}
add_action( 'wp_ajax_go_live_post_views', 'go_verge_admin_live_views_ajax' );

/** Site's earliest published post: stable lower bound for lifetime reporting. */
function go_verge_admin_site_first_publish_date() {
	global $wpdb; $cached=get_transient('go_admin_first_publish_date'); if($cached){return $cached;}
	$value=$wpdb->get_var("SELECT MIN(post_date_gmt) FROM {$wpdb->posts} WHERE post_status='publish' AND post_type='post' AND post_date_gmt>'2000-01-01 00:00:00'"); // phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared
	$date=$value&&'0000-00-00 00:00:00'!==$value?gmdate('Y-m-d',strtotime($value.' UTC')):'2020-01-01'; set_transient('go_admin_first_publish_date',$date,DAY_IN_SECONDS); return $date;
}

/** GA4 lifetime page views for the posts currently on screen, one filtered call. */
function go_verge_admin_ga4_lifetime( array $post_ids ) {
	$out=array(); foreach($post_ids as $id){$out[absint($id)]=0;}
	if(!function_exists('go_verge_ga4_post')||!function_exists('go_verge_traffic_ga4_property_id')||!go_verge_traffic_ga4_property_id()){return array('values'=>$out,'source'=>'Pulse');}
	$lookup=go_verge_admin_live_views_lookup($post_ids); $paths=array_keys($lookup['by_path']); if(!$paths){return array('values'=>$out,'source'=>'GA4');}
	$body=array(
		'dateRanges'=>array(array('startDate'=>go_verge_admin_site_first_publish_date(),'endDate'=>'today')),
		'dimensions'=>array(array('name'=>'pagePath')),
		'metrics'=>array(array('name'=>'screenPageViews')),
		'dimensionFilter'=>array('filter'=>array('fieldName'=>'pagePath','inListFilter'=>array('values'=>$paths,'caseSensitive'=>true))),
		'limit'=>min(100,count($paths)+10),
	);
	$data=go_verge_ga4_post('runReport',$body,10*MINUTE_IN_SECONDS); if(is_wp_error($data)){return array('values'=>$out,'source'=>'Pulse');}
	foreach((array)($data['rows']??array()) as $row){$path=(string)($row['dimensionValues'][0]['value']??'');$id=absint($lookup['by_path'][$path]??0);if($id){$out[$id]=max(0,(int)($row['metricValues'][0]['value']??0));}}
	return array('values'=>$out,'source'=>'GA4');
}

/** Numeric metric helper shared by either AdSense provider. */
function go_verge_admin_adsense_metric_float( $row, $key ) {
	return is_array( $row ) && isset( $row[ $key ] ) && is_numeric( $row[ $key ] ) ? (float) $row[ $key ] : 0.0;
}

/**
 * Aggregate AdSense PAGE_URL rows by canonical path.
 *
 * Reporting/OAuth belongs to the standalone GO AdSense Center plugin. A legacy
 * provider is accepted only as a backwards-compatible fallback during staged
 * deployments, but this theme no longer boots or configures one itself.
 */
function go_verge_admin_adsense_page_metrics( $range = 'today' ) {
	$key = 'go_admin_adsense_pages_' . sanitize_key( $range );
	$cached = get_transient( $key );
	if ( is_array( $cached ) ) { return $cached; }

	$empty   = array( 'by_path' => array(), 'currency' => 'USD', 'error' => '' );
	$metrics = array( 'ESTIMATED_EARNINGS', 'PAGE_VIEWS', 'IMPRESSIONS' );
	$host    = (string) wp_parse_url( home_url(), PHP_URL_HOST );
	$extra   = array( 'limit' => 100000, 'orderBy' => array( '-ESTIMATED_EARNINGS' ) );
	if ( $host ) { $extra['filters'] = array( 'PAGE_URL=@' . $host ); }

	$report = null;
	if ( class_exists( 'GOAC_API' ) && is_callable( array( 'GOAC_API', 'is_connected' ) ) && GOAC_API::is_connected() ) {
		$tz = is_callable( array( 'GOAC_API', 'tz' ) ) ? GOAC_API::tz() : wp_timezone();
		$end = new DateTimeImmutable( 'today', $tz );
		$start = 'life' === $range
			? new DateTimeImmutable( go_verge_admin_site_first_publish_date(), $tz )
			: $end;
		$report = GOAC_API::report_dates( array( 'PAGE_URL' ), $metrics, $start, $end, $extra, 'life' === $range ? 1800 : 300 );
	} elseif ( function_exists( 'go_verge_adsense_report_dates' ) ) {
		/* Compatibility only for an old plugin/provider; the theme itself no
		 * longer loads inc/ads/adsense-api.php. */
		$end = new DateTimeImmutable( current_time( 'Y-m-d' ), wp_timezone() );
		$start = 'life' === $range
			? new DateTimeImmutable( go_verge_admin_site_first_publish_date(), wp_timezone() )
			: $end;
		$report = go_verge_adsense_report_dates( array( 'PAGE_URL' ), $metrics, $start, $end, $extra );
	} else {
		return $empty;
	}

	if ( is_wp_error( $report ) ) {
		$empty['error'] = $report->get_error_message();
		return $empty;
	}

	$out = $empty;
	$out['currency'] = (string) ( $report['currency'] ?? 'USD' );
	if ( ! empty( $report['missing_metrics'] ) ) { $out['error'] = 'Métricas indisponíveis para PAGE_URL: ' . implode( ', ', $report['missing_metrics'] ); }
	foreach ( (array) ( $report['rows'] ?? array() ) as $row ) {
		$url  = (string) ( $row['PAGE_URL'] ?? '' );
		$path = (string) wp_parse_url( $url, PHP_URL_PATH );
		if ( function_exists( 'go_verge_traffic_clean_path' ) ) { $path = go_verge_traffic_clean_path( $path ); }
		if ( ! $path ) { continue; }

		if ( ! isset( $out['by_path'][ $path ] ) ) {
			$out['by_path'][ $path ] = array( 'earnings' => 0.0, 'views' => 0.0, 'impressions' => 0.0 );
		}
		$out['by_path'][ $path ]['earnings']    += go_verge_admin_adsense_metric_float( $row, 'ESTIMATED_EARNINGS' );
		$out['by_path'][ $path ]['views']       += go_verge_admin_adsense_metric_float( $row, 'PAGE_VIEWS' );
		$out['by_path'][ $path ]['impressions'] += go_verge_admin_adsense_metric_float( $row, 'IMPRESSIONS' );
	}

	foreach ( $out['by_path'] as &$metrics_row ) {
		$metrics_row['page_rpm']       = $metrics_row['views'] > 0 ? $metrics_row['earnings'] * 1000 / $metrics_row['views'] : 0;
		$metrics_row['impression_rpm'] = $metrics_row['impressions'] > 0 ? $metrics_row['earnings'] * 1000 / $metrics_row['impressions'] : 0;
	}
	unset( $metrics_row );

	set_transient( $key, $out, 'today' === $range ? 5 * MINUTE_IN_SECONDS : 30 * MINUTE_IN_SECONDS );
	return $out;
}

/** Avoid SQL errors when Lume is loaded but its migration is incomplete. */
function go_verge_admin_external_table_exists( $table ) {
	global $wpdb;
	$table = (string) $table;
	if ( '' === $table ) { return false; }
	static $cache = array();
	if ( array_key_exists( $table, $cache ) ) { return $cache[ $table ]; }
	$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) );
	$cache[ $table ] = is_string( $found ) && $found === $table;
	return $cache[ $table ];
}

/** Recent GSC metrics already imported by Lume. */
function go_verge_admin_gsc_metrics( array $post_ids ) {
 global $wpdb;
 $out=array();
 foreach($post_ids as $id){$out[absint($id)]=array(
  'search'=>0,'discover'=>0,'news'=>0,'impressions'=>0,'search_impressions'=>0,'discover_impressions'=>0,'news_impressions'=>0,
  'search_position'=>0.0,'search_best_position'=>0.0,
  'search_impressions_24h'=>0,'search_clicks_24h'=>0,'search_position_24h'=>0.0,'search_best_position_24h'=>0.0,'search_recent_as_of'=>'','search_recent_imported_at'=>'','search_recent_partial'=>false,
 );}
 if(!class_exists('GED_DB')||!method_exists('GED_DB','table')){return $out;}
 $ids=array_values(array_filter(array_map('absint',$post_ids)));if(!$ids){return $out;}$in=implode(',',array_fill(0,count($ids),'%d'));$start=wp_date('Y-m-d',time()-(6*DAY_IN_SECONDS));

 /* Daily channels still feed 7-day clicks/impressions and act as a stable fallback. */
 $perf_table=GED_DB::table('perf_daily');
 if(go_verge_admin_external_table_exists($perf_table)){
  $sql="SELECT post_id,source,SUM(clicks) clicks,SUM(impressions) impressions FROM {$perf_table} WHERE metric_date>=%s AND post_id IN ($in) GROUP BY post_id,source";$args=array_merge(array($start),$ids);
  $rows=$wpdb->get_results($wpdb->prepare($sql,$args),ARRAY_A);
  foreach((array)$rows as $row){$id=absint($row['post_id']);if(!$id||!isset($out[$id]))continue;$clicks=(int)round((float)$row['clicks']);$impressions=(int)round((float)$row['impressions']);$out[$id]['impressions']+=$impressions;
   if('discover'===$row['source']){$out[$id]['discover']+=$clicks;$out[$id]['discover_impressions']+=$impressions;}
   elseif(in_array($row['source'],array('googleNews','news'),true)){$out[$id]['news']+=$clicks;$out[$id]['news_impressions']+=$impressions;}
   else{$out[$id]['search']+=$clicks;$out[$id]['search_impressions']+=$impressions;}}
 }

 /* Prefer Search Console's official hourly API: much fresher than finalized daily data. */
 $hourly_table=GED_DB::table('perf_hourly');$latest_import='';
 if(go_verge_admin_external_table_exists($hourly_table)){
  $cutoff=current_datetime()->modify('-24 hours')->format('Y-m-d H:00:00');
  $sql="SELECT post_id,SUM(clicks) clicks,SUM(impressions) impressions,CASE WHEN SUM(impressions)>0 THEN SUM(position*impressions)/SUM(impressions) ELSE 0 END avg_position,MIN(CASE WHEN position>0 THEN position ELSE NULL END) best_position,MAX(hour_bucket) latest_hour,MAX(updated_at) imported_at,MAX(is_partial) is_partial FROM {$hourly_table} WHERE source='web' AND hour_bucket>=%s AND post_id IN ($in) AND impressions>0 AND position>0 GROUP BY post_id";$args=array_merge(array($cutoff),$ids);
  $hourly_rows=$wpdb->get_results($wpdb->prepare($sql,$args),ARRAY_A);
  foreach((array)$hourly_rows as $row){$id=absint($row['post_id']);if(!$id||!isset($out[$id]))continue;$out[$id]['search_impressions_24h']=(int)round((float)$row['impressions']);$out[$id]['search_clicks_24h']=(int)round((float)$row['clicks']);$out[$id]['search_position_24h']=max(0.0,(float)$row['avg_position']);$out[$id]['search_best_position_24h']=max(0.0,(float)$row['best_position']);$out[$id]['search_recent_as_of']=(string)$row['latest_hour'];$out[$id]['search_recent_imported_at']=(string)$row['imported_at'];$out[$id]['search_recent_partial']=!empty($row['is_partial']);if((string)$row['imported_at']>$latest_import){$latest_import=(string)$row['imported_at'];}}
  if(!$latest_import){$latest_import=(string)$wpdb->get_var("SELECT MAX(updated_at) FROM {$hourly_table} WHERE source='web'");}
  /* Never block wp-admin on a Google request. If the hourly import is stale, nudge Lume's existing cron in the background. */
  if($latest_import&&has_action('ged_gsc_hourly_sync')){$import_ts=strtotime($latest_import.' UTC');if($import_ts&&time()-$import_ts>75*MINUTE_IN_SECONDS&&!get_transient('go_gsc_hourly_nudge')){set_transient('go_gsc_hourly_nudge',1,20*MINUTE_IN_SECONDS);wp_schedule_single_event(time()+8,'ged_gsc_hourly_sync');}}
 }

 /* Stable 7-day query-level position, used only when the hourly page sample has no impressions. */
 $query_table=GED_DB::table('query_daily');
 if(go_verge_admin_external_table_exists($query_table)){
  $sql="SELECT post_id,SUM(impressions) impressions,CASE WHEN SUM(impressions)>0 THEN SUM(position*impressions)/SUM(impressions) ELSE 0 END avg_position,MIN(CASE WHEN position>0 THEN position ELSE NULL END) best_position FROM {$query_table} WHERE metric_date>=%s AND post_id IN ($in) AND impressions>0 AND position>0 GROUP BY post_id";$args=array_merge(array($start),$ids);
  $position_rows=$wpdb->get_results($wpdb->prepare($sql,$args),ARRAY_A);
  foreach((array)$position_rows as $row){$id=absint($row['post_id']);if(!$id||!isset($out[$id]))continue;$out[$id]['search_position']=max(0.0,(float)$row['avg_position']);$out[$id]['search_best_position']=max(0.0,(float)$row['best_position']);$out[$id]['search_impressions']=max((int)$out[$id]['search_impressions'],(int)round((float)$row['impressions']));}
 }
 return $out;
}

/** Build daily editorial bets from actual money first, then Search opportunity. */
function go_verge_admin_editorial_bets( $today_ads ) {
	global $wpdb; $items=array();$by_path=(array)($today_ads['by_path']??array());uasort($by_path,static function($a,$b){return($b['earnings']??0)<=>($a['earnings']??0);});$top_posts=array();$clusters=array();
	foreach(array_slice($by_path,0,60,true) as $path=>$m){$id=url_to_postid(home_url($path));if(!$id||'post'!==get_post_type($id)){continue;}$top_posts[$id]=$m;$cat=absint(get_post_meta($id,'rank_math_primary_category',true));if(!$cat){$cats=wp_get_post_categories($id);$cat=absint($cats[0]??0);}if($cat){if(!isset($clusters[$cat])){$clusters[$cat]=array('earnings'=>0,'views'=>0,'top'=>0,'top_money'=>0);}$clusters[$cat]['earnings']+=(float)$m['earnings'];$clusters[$cat]['views']+=(float)$m['views'];if((float)$m['earnings']>$clusters[$cat]['top_money']){$clusters[$cat]['top_money']=(float)$m['earnings'];$clusters[$cat]['top']=$id;}}if(count($top_posts)>=25){break;}}
	uasort($clusters,static function($a,$b){return$b['earnings']<=>$a['earnings'];});
	foreach(array_slice($clusters,0,2,true) as $cat_id=>$c){$term=get_term($cat_id,'category');if(is_wp_error($term)||!$term){continue;}$items[]=array('kind'=>'cluster','title'=>'Apostar no cluster: '.$term->name,'detail'=>sprintf('US$ %.2f hoje · %s views monetizadas. Puxado por “%s”.',$c['earnings'],number_format_i18n($c['views']),get_the_title($c['top'])),'url'=>get_edit_post_link($c['top'],'raw'));}
	if($top_posts){$id=(int)array_key_first($top_posts);$m=$top_posts[$id];$items[]=array('kind'=>'winner','title'=>'Vencedor de receita agora','detail'=>sprintf('“%s” · US$ %.2f hoje · RPM da URL US$ %.2f. Atualize/recircule e procure uma pauta adjacente, não uma cópia.',get_the_title($id),$m['earnings'],$m['page_rpm']),'url'=>get_edit_post_link($id,'raw'));}
	if(class_exists('GED_DB')&&method_exists('GED_DB','table')&&$top_posts){$ids=array_keys($top_posts);$table=GED_DB::table('query_daily');if(!go_verge_admin_external_table_exists($table)){return array_slice($items,0,6);}$in=implode(',',array_fill(0,count($ids),'%d'));$start=gmdate('Y-m-d',strtotime('-21 days'));$sql="SELECT MAX(query_text) query_text,SUM(impressions) impressions,SUM(clicks) clicks,CASE WHEN SUM(impressions)>0 THEN SUM(position*impressions)/SUM(impressions) ELSE 0 END position FROM {$table} WHERE metric_date>=%s AND post_id IN ($in) GROUP BY query_hash HAVING impressions>=80 AND position BETWEEN 4 AND 20 ORDER BY impressions DESC LIMIT 1";$args=array_merge(array($start),$ids);
		// phpcs:ignore WordPress.DB.PreparedSQL.NotPrepared,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
		$row=$wpdb->get_row($wpdb->prepare($sql,$args),ARRAY_A);if($row){$items[]=array('kind'=>'query','title'=>'Gap de Search para explorar','detail'=>sprintf('“%s” · %s impressões · posição média %.1f. Há demanda no cluster que já está monetizando hoje.',html_entity_decode($row['query_text'],ENT_QUOTES,'UTF-8'),number_format_i18n((float)$row['impressions']),(float)$row['position']),'url'=>'');}}
	return array_slice($items,0,3);
}
function go_verge_admin_editorial_bets_html( $items ) {
	if(!$items){return '<h2>Radar editorial de receita</h2><div class="go-radar-grid"><div class="go-radar-card"><strong>Ainda sem sinal suficiente</strong><p>O radar só sugere apostas quando existe receita por URL e/ou oportunidade real de Search.</p></div></div><div class="go-pi-filterbar" data-go-pi-filterbar></div>';}$html='<h2>Radar editorial de receita '.go_verge_admin_metric_help('Radar editorial de receita','Cruza audiência first-party, receita por URL e sinais Search/Discover para priorizar trabalho editorial. Não executa ações sozinho.').' <small style="font-weight:400;color:#646970">· dinheiro + demanda, não “trend” genérica</small></h2><div class="go-radar-grid">';foreach($items as $item){$title=esc_html($item['title']);if(!empty($item['url'])){$title='<a href="'.esc_url($item['url']).'">'.$title.'</a>';}$html.='<div class="go-radar-card"><strong>'.$title.'</strong><p>'.esc_html($item['detail']).'</p></div>';}$html.='</div><div class="go-pi-filterbar" data-go-pi-filterbar></div>';return $html;
}

/** Slow/cached business intelligence for visible rows. */
function go_verge_admin_post_intelligence_ajax() {
	if(!current_user_can('edit_posts')){wp_send_json_error(array('message'=>'forbidden'),403);}check_ajax_referer('go_post_intelligence','nonce');$raw=isset($_POST['post_ids'])?wp_unslash($_POST['post_ids']):array();$ids=is_array($raw)?$raw:explode(',',(string)$raw);$ids=array_slice(array_values(array_unique(array_filter(array_map('absint',$ids)))),0,100);$lookup=go_verge_admin_live_views_lookup($ids);$pulse=go_verge_admin_live_views_query($ids);$ga=go_verge_admin_ga4_lifetime($ids);$today=go_verge_admin_adsense_page_metrics('today');$life=go_verge_admin_adsense_page_metrics('life');$gsc=go_verge_admin_gsc_metrics($ids);$rows=array();
	foreach($ids as $id){
		if(!go_verge_admin_post_has_public_history($id)){$rows[$id]=array('published'=>false,'life_views'=>0,'life_source'=>'','earnings_today'=>0.0,'earnings_life'=>0.0,'page_rpm_today'=>0.0,'impression_rpm_today'=>0.0,'currency'=>(string)($today['currency']??'USD'),'search_7d'=>0,'discover_7d'=>0,'news_7d'=>0,'search_impressions_7d'=>0,'search_position_7d'=>0.0,'search_best_position_7d'=>0.0,'search_impressions_24h'=>0,'search_position_24h'=>0.0,'search_best_position_24h'=>0.0,'search_recent_as_of'=>'','search_recent_partial'=>false,'serp_source'=>'none','serp_visible'=>false,'index_confirmed'=>false,'readiness'=>array());continue;}
		$path=(string)($lookup['by_id'][$id]['path']??'');$tm=(array)($today['by_path'][$path]??array());$lm=(array)($life['by_path'][$path]??array());$life_views=(int)($ga['values'][$id]??0);$life_source=$ga['source'];if($life_views<=0){$life_views=(int)($pulse[$id]['pulse_life']??0);$life_source='Pulse';}$readiness=class_exists('GED_Rank_Math')&&method_exists('GED_Rank_Math','google_readiness')?GED_Rank_Math::google_readiness($id):array();$gm=(array)($gsc[$id]??array());
		$recent_position=(float)($gm['search_position_24h']??0.0);$recent_impressions=(int)($gm['search_impressions_24h']??0);$fallback_position=(float)($gm['search_position']??0.0);$fallback_impressions=(int)($gm['search_impressions']??0);$serp_source=($recent_position>0&&$recent_impressions>0)?'24h':(($fallback_position>0&&$fallback_impressions>0)?'7d':'none');$display_position='24h'===$serp_source?$recent_position:$fallback_position;$display_impressions='24h'===$serp_source?$recent_impressions:$fallback_impressions;
		$rows[$id]=array('published'=>true,'life_views'=>$life_views,'life_source'=>$life_source,'earnings_today'=>(float)($tm['earnings']??0),'earnings_life'=>(float)($lm['earnings']??0),'page_rpm_today'=>(float)($tm['page_rpm']??0),'impression_rpm_today'=>(float)($tm['impression_rpm']??0),'currency'=>(string)($today['currency']??'USD'),'search_7d'=>(int)($gm['search']??0),'discover_7d'=>(int)($gm['discover']??0),'news_7d'=>(int)($gm['news']??0),'search_impressions_7d'=>$fallback_impressions,'search_position_7d'=>$fallback_position,'search_best_position_7d'=>(float)($gm['search_best_position']??0.0),'search_impressions_24h'=>$recent_impressions,'search_clicks_24h'=>(int)($gm['search_clicks_24h']??0),'search_position_24h'=>$recent_position,'search_best_position_24h'=>(float)($gm['search_best_position_24h']??0.0),'search_recent_as_of'=>(string)($gm['search_recent_as_of']??''),'search_recent_partial'=>!empty($gm['search_recent_partial']),'serp_source'=>$serp_source,'serp_visible'=>($display_position>0&&$display_impressions>0),'index_confirmed'=>($recent_impressions>0||$fallback_impressions>0),'readiness'=>$readiness);
	}
	wp_send_json_success(array('rows'=>$rows,'bets_html'=>go_verge_admin_editorial_bets_html(go_verge_admin_editorial_bets($today)),'as_of'=>time(),'ads_error'=>(string)($today['error']??'')));
}
add_action('wp_ajax_go_post_intelligence','go_verge_admin_post_intelligence_ajax');

function go_verge_admin_live_views_script() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( $screen && ! array_diff( array('go_audience','go_revenue','go_index_status','go_google'), get_hidden_columns($screen) ) ) { return; }
	if ( ! $screen || 'edit-post' !== $screen->id ) { return; }
	$cfg = array(
		'url'          => admin_url( 'admin-ajax.php' ),
		'liveNonce'    => wp_create_nonce( 'go_live_post_views' ),
		'intelNonce'   => wp_create_nonce( 'go_post_intelligence' ),
		'googleNonce'  => wp_create_nonce( 'ged_google_indexing' ),
		'liveInterval' => 30000,
		'intelInterval'=> 180000,
		'idleAfter'    => 600000,
		'liveEnabled'  => go_verge_admin_live_views_available(),
		'gscConnected' => class_exists( 'GED_Search_Console' ) && method_exists( 'GED_Search_Console', 'connected' ) ? GED_Search_Console::connected() : false,
	);
	?>
	<script>
	(function(){
		'use strict';
		const cfg=<?php echo wp_json_encode( $cfg ); ?>;
		let liveBusy=false,intelBusy=false,lastRadarHtml="";
		const fmt=n=>{try{return new Intl.NumberFormat('pt-BR').format(Number(n)||0)}catch(e){return String(n||0)}};
		const money=(n,c='USD')=>{try{return new Intl.NumberFormat('pt-BR',{style:'currency',currency:c||'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(n)||0)}catch(e){return 'US$ '+(Number(n)||0).toFixed(2)}};
		const pos=n=>{n=Number(n)||0;if(n<=0)return '—';try{return new Intl.NumberFormat('pt-BR',{minimumFractionDigits:n<10?1:0,maximumFractionDigits:1}).format(n)}catch(e){return n.toFixed(n<10?1:0)}};
		function ids(){return Array.from(document.querySelectorAll('.go-pi-index[data-post-id],.go-pi-audience[data-post-id]')).map(el=>Number(el.dataset.postId)||0).filter((id,i,a)=>id>0&&a.indexOf(id)===i).slice(0,100)}
		async function post(action,nonce,extra={},timeoutMs=12000){
			const body=new URLSearchParams({action,nonce,...extra});
			if(extra.post_ids)delete extra.post_ids;
			ids().forEach(id=>body.append('post_ids[]',String(id)));
			const controller=typeof AbortController!=='undefined'?new AbortController():null;
			const timer=controller?setTimeout(()=>controller.abort(),timeoutMs):null;
			try{
				const r=await fetch(cfg.url,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},body:body.toString(),cache:'no-store',signal:controller?controller.signal:undefined});
				const text=await r.text();let j=null;
				try{j=JSON.parse(text)}catch(_e){throw new Error('Resposta inválida do WordPress ('+r.status+').')}
				if(!r.ok||!j||!j.success)throw new Error((j&&j.data&&j.data.message)||('HTTP '+r.status));
				return j;
			}finally{if(timer)clearTimeout(timer)}
		}
		function showIntelError(message){
			const radar=document.getElementById('go-editorial-revenue-radar');
			if(radar){const spinner=radar.querySelector('.spinner');if(spinner)spinner.remove();const grid=radar.querySelector('.go-radar-grid');if(grid)grid.innerHTML='<div class="go-radar-card"><strong>Dados temporariamente indisponíveis</strong><p>'+String(message||'O servidor não respondeu. O painel tentará novamente automaticamente.').replace(/[<>&]/g,'')+'</p></div>';}
			document.querySelectorAll('.go-pi-revenue[data-published="1"]').forEach(r=>{const mt=r.querySelector('.go-pi-money-today'),ml=r.querySelector('.go-pi-money-life'),rr=r.querySelector('.go-pi-rpm');if(mt&&mt.textContent.indexOf('…')===0)mt.childNodes[0].nodeValue='— hoje ';if(ml&&ml.textContent.indexOf('…')!==-1)ml.childNodes[0].nodeValue='Vida da URL: — ';if(rr&&rr.textContent.indexOf('…')!==-1)rr.childNodes[0].nodeValue='RPM URL hoje: — ';});
		}
		async function refreshLive(){
			if(liveBusy||document.hidden||!ids().length)return;liveBusy=true;
			try{
				const j=cfg.liveEnabled?await post('go_live_post_views',cfg.liveNonce,{},8000):{data:{counts:Object.fromEntries(ids().map(id=>[id,{views:0,online:0}]))}};const counts=j.data.counts||{};
				Object.keys(counts).forEach(id=>{const c=counts[id]||{};const box=document.querySelector('.go-pi-audience[data-post-id="'+id+'"]'),tr=(box&&box.closest('tr'))||document.getElementById('post-'+id);if(box){const today=box.querySelector('.go-pi-today'),live=box.querySelector('.go-pi-live b');if(today&&today.childNodes.length)today.childNodes[0].nodeValue=fmt(c.views)+' hoje ';if(live)live.textContent=fmt(c.online);}if(tr){if(tr.dataset.goViewsSource!=='burst')tr.dataset.goToday=Number(c.views)||0;tr.dataset.goLive=Number(c.online)||0;}});applyTableView();
			}catch(e){console.warn('[Overdrive Posts Intelligence] live',e)}finally{liveBusy=false}
		}
		async function refreshIntel(){
			if(intelBusy||document.hidden)return;intelBusy=true;
			try{
				const j=await post('go_post_intelligence',cfg.intelNonce,{},12000);const rows=j.data.rows||{},adsError=String(j.data.ads_error||'');
				Object.keys(rows).forEach(id=>{
					const d=rows[id]||{},a=document.querySelector('.go-pi-audience[data-post-id="'+id+'"]'),r=document.querySelector('.go-pi-revenue[data-post-id="'+id+'"]'),ix=document.querySelector('.go-pi-index[data-post-id="'+id+'"]'),g=document.querySelector('.go-pi-google[data-post-id="'+id+'"]');
					if(d.published===false){const tr=(a||r||ix||g)&&((a||r||ix||g).closest('tr'));if(tr){tr.dataset.goPublished='0';tr.dataset.goRevenue='0';tr.dataset.goLife='0';tr.dataset.goRpm='0';tr.dataset.goSearch='0';tr.dataset.goDiscover='0';tr.dataset.goNews='0';tr.dataset.goSerp='0';tr.dataset.goSearchImpressions='0';tr.dataset.goSerpPosition='0';}return;}
					if(a){const life=a.querySelector('.go-pi-life');if(life&&life.childNodes.length)life.childNodes[0].nodeValue='Vida da URL: '+fmt(d.life_views)+' · '+(d.life_source||'')+' ';const search=[];if(Number(d.search_7d)>0)search.push('Search '+fmt(d.search_7d));if(Number(d.discover_7d)>0)search.push('Discover '+fmt(d.discover_7d));if(Number(d.news_7d)>0)search.push('News '+fmt(d.news_7d));const se=a.querySelector('.go-pi-search');if(se)se.textContent=search.length?search.join(' · ')+' / 7d':'';}
					if(r){const mt=r.querySelector('.go-pi-money-today'),ml=r.querySelector('.go-pi-money-life'),rr=r.querySelector('.go-pi-rpm');if(adsError){if(mt&&mt.childNodes.length)mt.childNodes[0].nodeValue='— hoje ';if(ml&&ml.childNodes.length)ml.childNodes[0].nodeValue='Vida da URL: — ';if(rr&&rr.childNodes.length)rr.childNodes[0].nodeValue='RPM URL hoje: — ';r.title=adsError;}else{if(mt&&mt.childNodes.length)mt.childNodes[0].nodeValue=money(d.earnings_today,d.currency)+' hoje ';if(ml&&ml.childNodes.length)ml.childNodes[0].nodeValue='Vida da URL: '+money(d.earnings_life,d.currency)+' ';if(rr&&rr.childNodes.length)rr.childNodes[0].nodeValue='RPM URL hoje: '+money(d.page_rpm_today,d.currency)+' ';r.removeAttribute('title');}}
					const tr=(a||r||ix||g)&&((a||r||ix||g).closest('tr'));if(tr){tr.dataset.goPublished='1';tr.dataset.goRevenue=adsError?0:(Number(d.earnings_today)||0);tr.dataset.goLife=Number(d.life_views)||0;tr.dataset.goRpm=adsError?0:(Number(d.page_rpm_today)||0);tr.dataset.goSearch=Number(d.search_7d)||0;tr.dataset.goDiscover=Number(d.discover_7d)||0;tr.dataset.goNews=Number(d.news_7d)||0;tr.dataset.goSerp=d.serp_visible?'1':'0';const recentSerp=d.serp_source==='24h';tr.dataset.goSearchImpressions=Number(recentSerp?d.search_impressions_24h:d.search_impressions_7d)||0;tr.dataset.goSerpPosition=Number(recentSerp?d.search_position_24h:d.search_position_7d)||0;}
					if(ix&&!ix.dataset.fastSearch){
						const badge=ix.querySelector('.go-pi-index-badge'),state=ix.querySelector('.go-pi-serp-state'),detail=ix.querySelector('.go-pi-serp-detail'),recent=d.serp_source==='24h',imps=Number(recent?d.search_impressions_24h:d.search_impressions_7d)||0,position=Number(recent?d.search_position_24h:d.search_position_7d)||0,best=Number(recent?d.search_best_position_24h:d.search_best_position_7d)||0;
						ix.classList.remove('is-loading');
						if(position>0&&imps>0){
							let tone='is-pos-poor';if(position<=3)tone='is-pos-excellent';else if(position<=10)tone='is-pos-good';else if(position<=20)tone='is-pos-mid';else if(position<=50)tone='is-pos-weak';
							if(badge){badge.className='go-pi-index-badge '+tone;badge.textContent='#'+pos(position);}
							if(state)state.textContent=recent?'Posição recente · 24h':'Posição média · 7d (fallback)';
							if(detail){let tail=best>0?(recent?' · melhor hora #'+pos(best):' · melhor #'+pos(best)) : '';if(recent&&d.search_recent_as_of){const stamp=String(d.search_recent_as_of).slice(11,16);tail+=' · até '+stamp;}detail.textContent=fmt(imps)+' impressões'+tail+(recent?' · preliminar':'');}
							ix.title=recent?'Posição média ponderada pelas impressões das últimas 24 horas importadas pela API horária do Search Console. É dado preliminar e pode mudar nas próximas horas.':'Ainda não há amostra horária desta URL; mostrando a média estável dos últimos 7 dias como fallback.';
						}else if(!cfg.gscConnected){
							if(badge){badge.className='go-pi-index-badge is-warn';badge.textContent='GSC offline';}
							if(state)state.textContent='Sem dados Search importados';if(detail)detail.textContent='Conecte o Search Console para preencher o relatório de Performance.';ix.title='Esta coluna depende dos dados de Performance importados do Search Console; ela não é uma verificação de indexação.';
						}else{
							if(badge){badge.className='go-pi-index-badge is-muted';badge.textContent='Sem dados Search';}
							if(state)state.textContent='Sem impressões no relatório recente';if(detail)detail.textContent='Esta coluna mede Performance Search (24h/7d), não indexação. A URL pode estar indexada normalmente.';ix.title='Sem dados no relatório de Performance não significa que a URL esteja fora do índice. Dados horários chegam com atraso e podem ser preliminares; use a Inspeção de URL do Search Console para confirmar indexação.';
						}
					}
					if(g&&d.readiness&&Object.keys(d.readiness).length){const rd=d.readiness,score=g.querySelector('.go-pi-google-score strong'),caption=g.querySelector('.go-pi-google-score small'),surfaces=g.querySelector('.go-pi-surfaces');if(score)score.textContent=fmt(rd.score)+'/100';if(caption)caption.childNodes[0]?caption.childNodes[0].nodeValue=(rd.verdict||'')+' ':caption.textContent=rd.verdict||'';const chips=[];chips.push('<span class="go-pi-chip '+(rd.indexable?'ok':'warn')+'">'+(rd.indexable?'Indexável':'Bloqueado')+'</span>');if(rd.discover_ready)chips.push('<span class="go-pi-chip ok">Discover técnico</span>');if(rd.news_ready)chips.push('<span class="go-pi-chip ok">News 48h</span>');if(surfaces)surfaces.innerHTML=chips.join('');}
				});
				const radar=document.getElementById('go-editorial-revenue-radar'),nextRadarHtml=String(j.data.bets_html||''),radarKey=nextRadarHtml+'|'+(adsError?'1':'0');if(radar&&nextRadarHtml&&radarKey!==lastRadarHtml){const oldFilter=document.querySelector('[data-go-pi-filter]'),oldSort=document.querySelector('[data-go-pi-sort]'),fv=oldFilter?oldFilter.value:'all',sv=oldSort?oldSort.value:'default';radar.innerHTML=nextRadarHtml;lastRadarHtml=radarKey;ensureFilterbar();const nf=document.querySelector('[data-go-pi-filter]'),ns=document.querySelector('[data-go-pi-sort]');if(nf)nf.value=fv;if(ns)ns.value=sv;if(adsError){const h=radar.querySelector('h2');if(h)h.insertAdjacentHTML('beforeend',' <small style="font-weight:400;color:#b32d2e">· financeiro atualizando</small>');}}
				applyTableView();
			}catch(e){showIntelError(e&&e.name==='AbortError'?'Tempo limite ao carregar os dados.':(e.message||'Falha ao carregar os dados.'));console.warn('[Overdrive Posts Intelligence] intel',e)}finally{intelBusy=false}
		}
		function ensureFilterbar(){const host=document.querySelector('[data-go-pi-filterbar]');if(!host||host.querySelector('select'))return;host.innerHTML='<label>Mostrar <select data-go-pi-filter><option value="all">Todos</option><option value="serp">Com posição na SERP</option><option value="no_serp">Sem dados Search recentes</option><option value="live">Com leitores agora</option><option value="revenue">Rendendo hoje</option><option value="search">Com Search (7d)</option><option value="discover">Com Discover (7d)</option><option value="news">Com Google News (7d)</option><option value="unpublished">Não publicados</option></select></label><label>Ordenar <select data-go-pi-sort><option value="default">Ordem do WordPress</option><option value="serp">Melhor posição SERP</option><option value="revenue">Receita hoje</option><option value="today">Views hoje</option><option value="life">Vida da URL</option><option value="rpm">RPM da URL</option></select></label><span class="description">Search = amostra horária das últimas 24h quando disponível; 7d é apenas fallback. Esta coluna mede Performance, não indexação; ausência de dados não prova desindexação.</span>';}
		function applyTableView(){ensureFilterbar();const f=(document.querySelector('[data-go-pi-filter]')||{}).value||'all',sort=(document.querySelector('[data-go-pi-sort]')||{}).value||'default',body=document.querySelector('.wp-list-table.posts tbody');if(!body)return;const rows=Array.from(body.querySelectorAll('tr[id^="post-"]'));rows.forEach(tr=>{let show=true;if(f==='serp')show=tr.dataset.goSerp==='1';else if(f==='no_serp')show=tr.dataset.goPublished==='1'&&tr.dataset.goSerp==='0';else if(f==='live')show=Number(tr.dataset.goLive||0)>0;else if(f==='revenue')show=Number(tr.dataset.goRevenue||0)>0;else if(f==='search')show=Number(tr.dataset.goSearch||0)>0;else if(f==='discover')show=Number(tr.dataset.goDiscover||0)>0;else if(f==='news')show=Number(tr.dataset.goNews||0)>0;else if(f==='unpublished')show=tr.dataset.goPublished==='0';tr.classList.toggle('go-pi-row-hidden',!show);});if(sort!=='default'){const key={serp:'goSerpPosition',revenue:'goRevenue',today:'goToday',life:'goLife',rpm:'goRpm'}[sort];if(key){rows.sort((a,b)=>{if(sort==='serp'){const av=Number(a.dataset[key]||0),bv=Number(b.dataset[key]||0);if(av<=0&&bv<=0)return 0;if(av<=0)return 1;if(bv<=0)return -1;return av-bv;}return Number(b.dataset[key]||0)-Number(a.dataset[key]||0);}).forEach(tr=>body.appendChild(tr));}}}
		document.addEventListener('change',e=>{if(e.target.matches('[data-go-pi-filter],[data-go-pi-sort]'))applyTableView();});
		document.addEventListener('go:postviews-updated',()=>applyTableView());
		document.addEventListener('click',async e=>{const b=e.target.closest('.go-pi-send-google');if(!b||b.disabled)return;const id=Number(b.dataset.postId)||0;if(!id)return;b.disabled=true;const old=b.textContent;b.textContent='Enviando…';const status=b.parentNode.querySelector('.go-pi-google-status');status.textContent='';status.className='go-pi-google-status';try{const body=new URLSearchParams({action:'ged_send_to_google',nonce:cfg.googleNonce,post_id:String(id)});const r=await fetch(cfg.url,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},body:body.toString(),cache:'no-store'});const j=await r.json();if(!j||!j.success)throw new Error((j&&j.data&&j.data.message)||'Falha ao enviar');const d=j.data||{};try{await navigator.clipboard.writeText(d.url||'')}catch(_e){}const ins=d.inspection||{};status.classList.add('ok');status.innerHTML=(ins.coverage?('Google: '+ins.coverage+'. '):'')+(d.message||'Enviado.')+(d.console_url?' <a href="'+d.console_url+'" target="_blank" rel="noopener">Abrir inspeção</a>':'');b.textContent='Enviado';}catch(err){status.classList.add('err');status.textContent=err.message||'Falha';b.textContent=old;}finally{setTimeout(()=>{b.disabled=false;if(b.textContent==='Enviado')b.textContent='Enviar novamente'},1800)}});
		/* Each pulse boots WordPress on the host. Pause while the list is not being
		 * used, and never poll the live endpoint when it can only answer zeros. */
		let lastInput=Date.now();const idleAfter=Math.max(60000,Number(cfg.idleAfter)||600000),active=()=>Date.now()-lastInput<=idleAfter;
		const wake=()=>{const wasIdle=!active();lastInput=Date.now();if(wasIdle&&!document.hidden){refreshLive();refreshIntel();}};
		['pointerdown','keydown','wheel','touchstart'].forEach(t=>document.addEventListener(t,wake,{passive:true,capture:true}));
		document.addEventListener('mousemove',()=>{if(Date.now()-lastInput>15000)wake();},{passive:true});
		document.addEventListener('visibilitychange',()=>{if(!document.hidden){lastInput=Date.now();refreshLive();refreshIntel()}});
		refreshLive();refreshIntel();
		if(cfg.liveEnabled)setInterval(()=>{if(active())refreshLive()},Math.max(15000,Number(cfg.liveInterval)||30000));
		setInterval(()=>{if(active())refreshIntel()},Math.max(60000,Number(cfg.intelInterval)||180000));
	})();
	</script>
	<?php
}
add_action( 'admin_footer-edit.php', 'go_verge_admin_live_views_script', 90 );

/**
 * URL intelligence in Edit/Add Post.
 *
 * This is deliberately an AJAX shell: opening the editor never waits for GA4
 * or AdSense. Published posts read the same local Pulse + persisted financial
 * snapshots used by the Posts list; drafts never inherit metrics from a
 * provisional/reused URL.
 */
function go_verge_admin_editor_intelligence_metabox_register() {
	if ( ! current_user_can( 'edit_posts' ) ) { return; }
	add_meta_box(
		'go-editor-url-intelligence',
		__( 'Audiência, receita e Google', 'go-verge' ),
		'go_verge_admin_editor_intelligence_metabox_render',
		'post',
		'side',
		'high',
		array( '__block_editor_compatible_meta_box' => true )
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_admin_editor_intelligence_metabox_register', 35 );

/** Render the non-blocking shell shown on post.php/post-new.php. */
function go_verge_admin_editor_intelligence_metabox_render( $post ) {
	$post_id   = $post instanceof WP_Post ? absint( $post->ID ) : 0;
	$published = $post_id && go_verge_admin_post_has_public_history( $post_id );
	$help = array(
		'today'    => 'Visualizações registradas hoje para a URL pública desta matéria. O Pulse local é rápido; não é um número financeiro.',
		'now'      => 'Sessões vistas nesta URL nos últimos 90 segundos pelo Traffic Pulse local. Não é o mesmo que pageviews.',
		'life'     => 'Visualizações acumuladas da URL canônica. Se um slug foi reutilizado, o histórico pertence à URL pública; rascunhos não herdam esse histórico.',
		'rev_today'=> 'Ganhos estimados do AdSense atribuídos à PAGE_URL desta matéria hoje. O editor lê snapshot persistido e nunca espera a API do Google para abrir.',
		'rev_life' => 'Ganhos estimados acumulados atribuíveis a esta PAGE_URL no período financeiro disponível. É histórico da URL pública.',
		'rpm'      => 'Page RPM da própria URL: receita estimada da URL ÷ pageviews da URL × 1.000. Não é o RPM médio do site.',
		'search'   => 'Cliques de Google Search dos últimos 7 dias importados pelo Lume/Search Console. Não são impressões.',
		'discover' => 'Cliques de Google Discover dos últimos 7 dias importados pelo Search Console. Não é uma métrica em tempo real.',
		'google'   => 'Checklist técnico/editorial do Lume. Não é uma nota oficial do Google e não prevê ranking ou entrada no Discover.',
	);
	?>
	<div id="go-editor-intelligence" class="go-editor-intelligence" data-post-id="<?php echo esc_attr( $post_id ); ?>" data-published="<?php echo $published ? '1' : '0'; ?>">
		<p class="go-editor-intelligence__freshness"><strong>Como ler</strong> <?php echo go_verge_admin_metric_help( 'Audiência, receita e Google', 'Resumo operacional desta URL dentro do editor. Audiência e receita são leitura; Google 2026 é checklist interno. Nenhum desses indicadores publica, indexa ou modifica a matéria automaticamente.' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></p>
		<p class="go-editor-intelligence__state <?php echo $published ? 'is-loading' : 'is-draft'; ?>" data-go-editor-state>
			<?php echo $published ? esc_html__( 'Carregando os snapshots desta URL…', 'go-verge' ) : esc_html__( 'Ainda sem histórico público.', 'go-verge' ); ?>
		</p>
		<div class="go-editor-intelligence__grid">
			<div class="go-editor-intelligence__metric"><span>Views hoje <?php echo go_verge_admin_metric_help( 'Views hoje', $help['today'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="today"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Agora <?php echo go_verge_admin_metric_help( 'Agora', $help['now'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="now"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Vida da URL <?php echo go_verge_admin_metric_help( 'Vida da URL', $help['life'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="life"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Receita hoje <?php echo go_verge_admin_metric_help( 'Receita hoje', $help['rev_today'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="revenue_today"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Receita vida <?php echo go_verge_admin_metric_help( 'Receita vida', $help['rev_life'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="revenue_life"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Page RPM URL <?php echo go_verge_admin_metric_help( 'Page RPM URL', $help['rpm'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="rpm"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Search · 7d <?php echo go_verge_admin_metric_help( 'Search 7 dias', $help['search'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="search"><?php echo $published ? '…' : '—'; ?></strong></div>
			<div class="go-editor-intelligence__metric"><span>Discover · 7d <?php echo go_verge_admin_metric_help( 'Discover 7 dias', $help['discover'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span><strong data-go-editor-metric="discover"><?php echo $published ? '…' : '—'; ?></strong></div>
		</div>
		<div class="go-editor-intelligence__google">
			<span>Google 2026 <?php echo go_verge_admin_metric_help( 'Google 2026', $help['google'] ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></span>
			<strong data-go-editor-metric="google"><?php echo $published ? '…' : '—'; ?></strong>
			<small data-go-editor-google-verdict><?php echo $published ? esc_html__( 'Lendo checklist…', 'go-verge' ) : esc_html__( 'Publique para iniciar histórico e sinais de descoberta.', 'go-verge' ); ?></small>
		</div>
		<p class="go-editor-intelligence__freshness" data-go-editor-freshness>
			<?php echo $published ? esc_html__( 'Pulse local + snapshots financeiros persistidos.', 'go-verge' ) : esc_html__( 'A URL provisória do rascunho não consulta nem herda receita/audiência.', 'go-verge' ); ?>
		</p>
	</div>
	<?php
}

/** Styling shared by Classic Editor and the legacy metabox area in Gutenberg. */
function go_verge_admin_editor_intelligence_css() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->id ) { return; }
	?>
	<style>
	#go-editor-url-intelligence .inside{margin:0;padding:12px}.go-editor-intelligence{font-variant-numeric:tabular-nums}.go-editor-intelligence__state{margin:0 0 10px;padding:8px 9px;border-radius:5px;background:#f0f6fc;color:#1d2327;font-size:11px;line-height:1.35}.go-editor-intelligence__state.is-draft{background:#f6f7f7;color:#50575e}.go-editor-intelligence__state.is-error{background:#fcf0f1;color:#8a2424}.go-editor-intelligence__grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1px;border:1px solid #dcdcde;border-radius:6px;overflow:visible;background:#dcdcde}.go-editor-intelligence__metric{min-width:0;padding:9px;background:#fff}.go-editor-intelligence__metric>span,.go-editor-intelligence__google>span{display:flex;align-items:center;color:#646970;font-size:10px;font-weight:600;line-height:1.2}.go-editor-intelligence__metric>strong{display:block;margin-top:4px;color:#1d2327;font-size:13px;line-height:1.15;overflow-wrap:anywhere}.go-editor-intelligence__google{position:relative;margin-top:9px;padding:9px;border:1px solid #dcdcde;border-radius:6px;background:#fff}.go-editor-intelligence__google>strong{display:block;margin-top:4px;color:#067647;font-size:14px}.go-editor-intelligence__google small{display:block;margin-top:3px;color:#646970;font-size:10px;line-height:1.35}.go-editor-intelligence__freshness{margin:9px 1px 0;color:#646970;font-size:10px;line-height:1.35}.go-pi-help-wrap{position:relative;display:inline-flex;align-items:center}.go-pi-help{box-sizing:border-box;display:inline-grid;place-items:center;flex:0 0 14px;width:14px;height:14px;min-width:14px;padding:0;margin-left:4px;border:1px solid #a7aaad;border-radius:50%;background:#fff;color:#646970;font:700 9px/1 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;cursor:help}.go-pi-help:hover,.go-pi-help:focus-visible{outline:none;border-color:#2271b1;color:#135e96;background:#f0f6fc}.go-pi-help:focus-visible{box-shadow:0 0 0 2px #72aee6}.go-pi-tooltip{display:none!important;position:fixed;z-index:1000000;width:min(290px,calc(100vw - 32px));padding:9px 10px;border-radius:6px;background:#1d2327;color:#fff;font-size:11px;font-weight:400;line-height:1.4;letter-spacing:0;text-align:left;white-space:normal;box-shadow:0 6px 20px rgba(0,0,0,.22);pointer-events:none}.go-pi-tooltip[hidden]{display:none!important}.go-pi-tooltip.is-visible:not([hidden]){display:block!important}@media(max-width:782px){.go-editor-intelligence__grid{grid-template-columns:1fr 1fr}}
	</style>
	<?php
}
add_action( 'admin_head-post.php', 'go_verge_admin_editor_intelligence_css' );
add_action( 'admin_head-post-new.php', 'go_verge_admin_editor_intelligence_css' );

/** Non-blocking editor refresh: no Google request is performed on this request. */
function go_verge_admin_editor_intelligence_script() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'post' !== $screen->id ) { return; }
	$post_id = isset( $_GET['post'] ) ? absint( $_GET['post'] ) : 0; // phpcs:ignore WordPress.Security.NonceVerification.Recommended -- read-only screen context.
	if ( ! $post_id && isset( $GLOBALS['post'] ) && $GLOBALS['post'] instanceof WP_Post ) { $post_id = absint( $GLOBALS['post']->ID ); }
	$cfg = array(
		'url'        => admin_url( 'admin-ajax.php' ),
		'postId'     => $post_id,
		'liveNonce'  => wp_create_nonce( 'go_live_post_views' ),
		'intelNonce' => wp_create_nonce( 'go_post_intelligence' ),
		'liveEnabled'=> go_verge_admin_live_views_available(),
	);
	?>
	<script>
	(function(){
		'use strict';
		const root=document.getElementById('go-editor-intelligence');if(!root||root.dataset.published!=='1')return;
		const cfg=<?php echo wp_json_encode( $cfg ); ?>,id=Number(root.dataset.postId||cfg.postId)||0;if(!id)return;
		const metric=k=>root.querySelector('[data-go-editor-metric="'+k+'"]'),state=root.querySelector('[data-go-editor-state]'),fresh=root.querySelector('[data-go-editor-freshness]');
		const fmt=n=>{try{return new Intl.NumberFormat('pt-BR').format(Number(n)||0)}catch(e){return String(n||0)}};
		const money=(n,c='USD')=>{try{return new Intl.NumberFormat('pt-BR',{style:'currency',currency:c||'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(n)||0)}catch(e){return 'US$ '+(Number(n)||0).toFixed(2)}};
		async function request(action,nonce,timeoutMs){const body=new URLSearchParams({action,nonce});body.append('post_ids[]',String(id));const controller='AbortController'in window?new AbortController():null,timer=controller?setTimeout(()=>controller.abort(),timeoutMs):null;try{const r=await fetch(cfg.url,{method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8'},body:body.toString(),cache:'no-store',signal:controller?controller.signal:undefined});const text=await r.text();let j;try{j=JSON.parse(text)}catch(e){throw new Error('Resposta inválida do WordPress.')}if(!r.ok||!j||!j.success)throw new Error((j&&j.data&&j.data.message)||('HTTP '+r.status));return j.data||{};}finally{if(timer)clearTimeout(timer)}}
		async function live(){try{const d=cfg.liveEnabled?await request('go_live_post_views',cfg.liveNonce,8000):{counts:{[id]:{views:0,online:0}}},c=(d.counts||{})[id]||{};if(metric('today'))metric('today').textContent=fmt(c.views);if(metric('now'))metric('now').textContent=fmt(c.online);}catch(e){console.warn('[Overdrive Editor Intelligence] live',e)}}
		async function intel(){try{const d=await request('go_post_intelligence',cfg.intelNonce,12000),r=(d.rows||{})[id]||{};if(r.published===false)return;if(metric('life'))metric('life').textContent=fmt(r.life_views);if(metric('search'))metric('search').textContent=fmt(r.search_7d);if(metric('discover'))metric('discover').textContent=fmt(r.discover_7d);if(metric('google')&&r.readiness&&Object.keys(r.readiness).length){metric('google').textContent=fmt(r.readiness.score)+'/100';const v=root.querySelector('[data-go-editor-google-verdict]');if(v)v.textContent=r.readiness.verdict||'Checklist carregado.';}if(d.ads_error){if(metric('revenue_today'))metric('revenue_today').textContent='—';if(metric('revenue_life'))metric('revenue_life').textContent='—';if(metric('rpm'))metric('rpm').textContent='—';if(state){state.textContent='Audiência carregada · financeiro atualizando em background.';state.className='go-editor-intelligence__state';}}else{if(metric('revenue_today'))metric('revenue_today').textContent=money(r.earnings_today,r.currency);if(metric('revenue_life'))metric('revenue_life').textContent=money(r.earnings_life,r.currency);if(metric('rpm'))metric('rpm').textContent=money(r.page_rpm_today,r.currency);if(state){state.textContent='Dados da URL carregados.';state.className='go-editor-intelligence__state';}}if(fresh){const t=new Date((Number(d.as_of)||Math.floor(Date.now()/1000))*1000);fresh.textContent='Atualizado '+t.toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'})+' · Pulse local + snapshots persistidos.';}}catch(e){if(state){state.textContent=e&&e.name==='AbortError'?'Tempo limite; usando o último estado disponível.':'Dados temporariamente indisponíveis; o editor continua normalmente.';state.className='go-editor-intelligence__state is-error';}console.warn('[Overdrive Editor Intelligence] intel',e)}}
		/* The editor stays open for long sessions: refresh slowly, and not at all
		 * after ten minutes without input or while the tab is in the background. */
		let lastInput=Date.now();const active=()=>!document.hidden&&Date.now()-lastInput<=600000;
		const wake=()=>{const wasIdle=Date.now()-lastInput>600000;lastInput=Date.now();if(wasIdle&&!document.hidden){live();intel();}};
		['pointerdown','keydown','wheel','touchstart'].forEach(t=>document.addEventListener(t,wake,{passive:true,capture:true}));
		live();intel();if(cfg.liveEnabled)setInterval(()=>{if(active())live()},60000);setInterval(()=>{if(active())intel()},300000);document.addEventListener('visibilitychange',()=>{if(!document.hidden){lastInput=Date.now();live();intel();}});
	})();
	</script>
	<?php
}
add_action( 'admin_footer-post.php', 'go_verge_admin_editor_intelligence_script', 91 );
add_action( 'admin_footer-post-new.php', 'go_verge_admin_editor_intelligence_script', 91 );


/** Keyboard/mouse runtime for accessible admin help popovers. */
function go_verge_admin_help_tooltip_runtime() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || ! in_array( $screen->base, array( 'edit', 'post' ), true ) || 'post' !== $screen->post_type ) { return; }
	?>
	<script>
	(function(){'use strict';let active=null,hideTimer=0;function tip(b){const id=b&&b.getAttribute('aria-describedby');return id?document.getElementById(id):null}function closeAll(except){clearTimeout(hideTimer);document.querySelectorAll('.go-pi-tooltip').forEach(t=>{if(t!==except){t.classList.remove('is-visible');t.hidden=true;t.setAttribute('aria-hidden','true');t.style.removeProperty('left');t.style.removeProperty('top')}});document.querySelectorAll('.go-pi-help').forEach(b=>{if(!except||tip(b)!==except)b.setAttribute('aria-expanded','false')});if(!except)active=null}function hide(){closeAll(null)}function laterHide(){clearTimeout(hideTimer);hideTimer=setTimeout(hide,80)}function show(b){const t=tip(b);if(!t)return;closeAll(t);t.hidden=false;t.setAttribute('aria-hidden','false');t.classList.add('is-visible');b.setAttribute('aria-expanded','true');active=t;requestAnimationFrame(()=>{const r=b.getBoundingClientRect(),q=t.getBoundingClientRect(),p=10;let l=Math.max(p,Math.min(innerWidth-q.width-p,r.left+r.width/2-q.width/2)),y=r.bottom+7;if(y+q.height>innerHeight-p)y=Math.max(p,r.top-q.height-7);t.style.left=l+'px';t.style.top=y+'px'})}document.addEventListener('mouseover',e=>{const b=e.target.closest&&e.target.closest('.go-pi-help');if(b)show(b)});document.addEventListener('mouseout',e=>{const b=e.target.closest&&e.target.closest('.go-pi-help');if(b&&!b.contains(e.relatedTarget))laterHide()});document.addEventListener('focusin',e=>{const b=e.target.closest&&e.target.closest('.go-pi-help');if(b)show(b)});document.addEventListener('focusout',e=>{const b=e.target.closest&&e.target.closest('.go-pi-help');if(b)hide()});document.addEventListener('click',e=>{const b=e.target.closest&&e.target.closest('.go-pi-help');if(b){e.stopPropagation();show(b);return}if(active)hide()});document.addEventListener('keydown',e=>{if(e.key==='Escape'&&active)hide()});addEventListener('blur',hide);addEventListener('resize',hide);addEventListener('scroll',hide,true);function hardReset(){active=null;clearTimeout(hideTimer);document.querySelectorAll('.go-pi-tooltip').forEach(t=>{t.classList.remove('is-visible');t.hidden=true;t.setAttribute('aria-hidden','true');t.style.removeProperty('left');t.style.removeProperty('top')});document.querySelectorAll('.go-pi-help').forEach(b=>b.setAttribute('aria-expanded','false'))}hardReset();addEventListener('pageshow',hardReset);
		const deskHelp={
			'Título':'Título editorial visível. Deve descrever a matéria com clareza; não precisa ser idêntico ao título SEO.',
			'Título SEO':'Título pensado para a SERP. Mantenha intenção e entidade principal sem prometer algo que o texto não entrega.',
			'Linha de apoio':'Complementa o título com informação nova; evite apenas repetir a mesma frase.',
			'Slug':'Trecho da URL. Prefira curto, descritivo e estável depois da publicação para evitar quebrar histórico/canonical.',
			'Meta description':'Resumo da página para mecanismos de busca. Ajuda entendimento e clique, mas não garante snippet nem ranking.',
			'Categoria principal':'Hierarquia editorial/canônica da matéria e base do breadcrumb.',
			'Breadcrumb':'Caminho hierárquico da matéria derivado da categoria principal.',
			'Tags':'Entidades e subtemas específicos presentes no conteúdo. Evite tags genéricas e sinônimos duplicados.',
			'Assunto':'Entidade central usada para relacionar matérias e reforçar consistência editorial.',
			'Assunto principal':'Entidade que melhor representa o foco da matéria; use seleção manual quando o automático ficar ambíguo.',
			'Tipo de matéria':'Classificação de formato editorial, como notícia, lista, guia ou review. Deve refletir a entrega real.',
			'Schema':'Dados estruturados enviados no HTML. Escolha o tipo compatível com o conteúdo; schema não substitui conteúdo nem garante rich result.',
			'Indexação':'Estado/ação referente à descoberta da URL pelo Google. Solicitar indexação não garante rastreamento ou ranking imediato.',
			'Palavra-chave':'Consulta/intenção principal usada como referência editorial. Não force repetição literal no texto.',
			'Imagem destacada':'Imagem principal usada em cards e compartilhamentos. Priorize enquadramento limpo e resolução adequada.'
		};
		let seq=0,enhanceTimer=0;
		function ownText(el){return Array.from(el.childNodes||[]).filter(n=>n.nodeType===3).map(n=>n.textContent).join(' ').replace(/\s+/g,' ').trim()}
		function enhanceDesk(){document.querySelectorAll('[id*="ged" i],[class*="ged-" i],[id*="editorial" i],[class*="editorial" i]').forEach(root=>{root.querySelectorAll('label>span,label,h3,.components-base-control__label,.components-input-control__label').forEach(el=>{if(el.querySelector&&el.querySelector('.go-pi-help-wrap'))return;const key=ownText(el).replace(/[:?]+$/,'').trim();const help=deskHelp[key];if(!help)return;const id='go-desk-tip-js-'+(++seq),w=document.createElement('span'),b=document.createElement('button'),t=document.createElement('span');w.className='go-pi-help-wrap';b.type='button';b.className='go-pi-help';b.textContent='?';b.setAttribute('aria-label','Explicar: '+key);b.setAttribute('aria-describedby',id);b.setAttribute('aria-expanded','false');t.className='go-pi-tooltip';t.id=id;t.setAttribute('role','tooltip');t.setAttribute('aria-hidden','true');t.hidden=true;t.textContent=help;w.append(b,t);el.appendChild(w)})})}
		function scheduleEnhance(){clearTimeout(enhanceTimer);enhanceTimer=setTimeout(enhanceDesk,120)}
		enhanceDesk();new MutationObserver(scheduleEnhance).observe(document.body,{childList:true,subtree:true});
	})();
	</script>
	<?php
}
add_action( 'admin_footer-edit.php', 'go_verge_admin_help_tooltip_runtime', 99 );
add_action( 'admin_footer-post.php', 'go_verge_admin_help_tooltip_runtime', 99 );
add_action( 'admin_footer-post-new.php', 'go_verge_admin_help_tooltip_runtime', 99 );

require_once __DIR__ . '/admin-fast-search.php';
