<?php
/**
 * Overdrive Editorial Architecture V7.
 *
 * Categories answer "about what?". Content type answers "what kind of story?".
 * Platform/service answer "where?" and entity/production answer "who/what?".
 * Includes a versioned, idempotent migration from the legacy category/tag tree.
 *
 * @package go-verge
 */
if ( ! defined( 'ABSPATH' ) ) { exit; }

const GO_VERGE_ARCH_V7_VERSION = '2026-08-25-v25';

/** Canonical category tree: the live Overdrive editorial destinations. */
function go_verge_v7_category_blueprint() {
	return array(
		'games' => array(
			'name' => 'Games',
			'children' => array(
				'dicas-e-guias' => 'Dicas e Guias',
				'especiais'     => 'Especiais',
				'lancamentos'   => 'Lançamentos',
				'reviews'       => 'Reviews',
			),
		),
		'entretenimento' => array(
			'name' => 'Entretenimento',
			'children' => array(
				'anime-e-manga'    => 'Anime e Mangá',
				'criticas'         => 'Críticas',
				'doramas'          => 'Doramas',
				'filmes'           => 'Filmes',
				'musica'           => 'Música',
				'producoes-turcas' => 'Novelas e séries turcas',
				'series'           => 'Séries',
				'streaming'        => 'Streaming',
			),
		),
		'ofertas' => array(
			'name' => 'Ofertas e Compras',
			'children' => array(
				'guias-de-compra' => 'Guias de compra',
				'jogos-gratis'    => 'Jogos grátis',
				'promocoes'       => 'Ofertas',
			),
		),
		'tecnologia' => array(
			'name' => 'Tecnologia',
			'children' => array(
				'apps-software'    => 'Apps e Software',
				'celulares'        => 'Celulares',
				'ciencia'          => 'Ciência e Mundo',
				'hardware'         => 'Hardware',
				'ia'               => 'Inteligência Artificial',
				'notebooks'        => 'Notebooks',
				'tvs-e-monitores'  => 'TVs e Monitores',
			),
		),
	);
}

/** Controlled vocabularies. */
function go_verge_v7_vocabularies() {
	return array(
		'go_content_type' => array(
			'labels' => array('name'=>'Tipos de matéria','singular_name'=>'Tipo de matéria'),
			'rewrite' => false,
			'terms' => array(
				'noticia'=>'Notícia','guia'=>'Guia','review'=>'Review','critica'=>'Crítica','lista'=>'Lista',
				'especial'=>'Especial','onde-assistir'=>'Onde assistir','final-explicado'=>'Final explicado','impressoes'=>'Impressões','oferta'=>'Oferta','guia-de-compra'=>'Guia de compra','ranking'=>'Ranking',
			),
		),
		'go_platform' => array(
			'labels' => array('name'=>'Plataformas','singular_name'=>'Plataforma'),
			'rewrite' => array('slug'=>'plataformas','with_front'=>false),
			'terms' => array(
				'pc'=>'PC','playstation'=>'PlayStation','xbox'=>'Xbox','nintendo'=>'Nintendo','android'=>'Android','ios'=>'iOS',
			),
		),
		'go_service' => array(
			'labels' => array('name'=>'Serviços','singular_name'=>'Serviço'),
			'rewrite' => array('slug'=>'servicos','with_front'=>false),
			'terms' => array(
				'netflix'=>'Netflix','prime-video'=>'Prime Video','disney-plus'=>'Disney+','max'=>'Max','apple-tv-plus'=>'Apple TV+',
				'crunchyroll'=>'Crunchyroll','globoplay'=>'Globoplay','steam'=>'Steam','playstation-plus'=>'PlayStation Plus',
				'playstation-store'=>'PlayStation Store','xbox-game-pass'=>'Xbox Game Pass','epic-games-store'=>'Epic Games Store','geforce-now'=>'GeForce NOW',
			),
		),
		'go_guide_type' => array(
			'labels' => array('name'=>'Tipos de guia','singular_name'=>'Tipo de guia'),
			'rewrite' => false,
			'terms' => array(
				'passo-a-passo'=>'Passo a passo','codigo'=>'Código','trofeu-conquista'=>'Troféu/Conquista','build'=>'Build',
				'localizacao'=>'Localização','puzzle'=>'Puzzle','boss'=>'Boss','configuracao'=>'Configuração','como-roda'=>'Como roda?','dicas'=>'Dicas',
			),
		),
	);
}

/** V3.15.2: the Formato field is a closed editorial vocabulary, not a tag bucket. */
function go_verge_v3152_content_type_slugs() {
	$vocab = go_verge_v7_vocabularies();
	return array_keys( (array) ( $vocab['go_content_type']['terms'] ?? array() ) );
}

/** Prevent people/entities/events from being created accidentally as Formato terms. */
function go_verge_v3152_lock_content_type_vocabulary( $term, $taxonomy, $args ) {
	if ( 'go_content_type' !== $taxonomy ) { return $term; }
	$slug = ! empty( $args['slug'] ) ? sanitize_title( $args['slug'] ) : sanitize_title( $term );
	if ( ! in_array( $slug, go_verge_v3152_content_type_slugs(), true ) ) {
		return new WP_Error( 'go_verge_closed_content_type', __( 'Formato aceita apenas os tipos editoriais oficiais do Overdrive.', 'go-verge' ) );
	}
	return $term;
}
add_filter( 'pre_insert_term', 'go_verge_v3152_lock_content_type_vocabulary', 10, 3 );

function go_verge_v7_register_taxonomies() {
	foreach ( go_verge_v7_vocabularies() as $taxonomy => $config ) {
		if ( taxonomy_exists( $taxonomy ) ) { continue; }
		$is_public = in_array( $taxonomy, array( 'go_platform', 'go_service' ), true );
		register_taxonomy( $taxonomy, array( 'post', 'games', 'productions' ), array(
			'labels'            => $config['labels'],
			'public'            => $is_public,
			'publicly_queryable'=> $is_public,
			'show_ui'           => true,
			'show_in_rest'      => true,
			'show_admin_column' => in_array( $taxonomy, array('go_content_type','go_platform','go_service'), true ),
			'hierarchical'      => false,
			'rewrite'           => $config['rewrite'],
			'query_var'         => true,
			'show_in_nav_menus' => $is_public,
		) );
	}
}
add_action( 'init', 'go_verge_v7_register_taxonomies', 8 );


/**
 * V24: consolidate generation-specific console terms into durable platform hubs.
 * Existing stories keep their relationships; old public URLs are redirected.
 */
function go_verge_v24_platform_consolidation_map() {
	return array(
		'playstation-5'    => 'playstation',
		'playstation-4'    => 'playstation',
		'ps5'              => 'playstation',
		'ps4'              => 'playstation',
		'ps5-pro'          => 'playstation',
		'xbox-series'      => 'xbox',
		'xbox-series-x-s'  => 'xbox',
		'xbox-series-x'    => 'xbox',
		'xbox-series-s'    => 'xbox',
		'xbox-one'         => 'xbox',
		'nintendo-switch'  => 'nintendo',
		'nintendo-switch-2'=> 'nintendo',
		'switch'           => 'nintendo',
		'switch-2'         => 'nintendo',
	);
}

function go_verge_v24_consolidate_platform_terms() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) ) { return; }
	if ( '2026-08-25-v24' === (string) get_option( 'go_verge_platform_consolidation_v24', '' ) ) { return; }
	if ( ! taxonomy_exists( 'go_platform' ) ) { return; }

	$canonical = array(
		'playstation' => 'PlayStation',
		'xbox'        => 'Xbox',
		'nintendo'    => 'Nintendo',
	);
	foreach ( $canonical as $slug => $name ) {
		go_verge_v7_ensure_term( 'go_platform', $slug, $name, 0 );
	}

	$redirects = (array) get_option( 'go_verge_v24_platform_redirects', array() );
	foreach ( go_verge_v24_platform_consolidation_map() as $old_slug => $new_slug ) {
		$old = get_term_by( 'slug', $old_slug, 'go_platform' );
		$new = get_term_by( 'slug', $new_slug, 'go_platform' );
		if ( ! ( $new instanceof WP_Term ) ) { continue; }

		$new_url = get_term_link( $new );
		if ( ! is_wp_error( $new_url ) ) {
			$redirects[ 'plataformas/' . $old_slug ] = $new_url;
		}
		if ( ! ( $old instanceof WP_Term ) || (int) $old->term_id === (int) $new->term_id ) { continue; }

		$objects = get_objects_in_term( (int) $old->term_id, 'go_platform' );
		if ( ! is_wp_error( $objects ) ) {
			foreach ( array_map( 'absint', (array) $objects ) as $object_id ) {
				wp_set_object_terms( $object_id, array( (int) $new->term_id ), 'go_platform', true );
				wp_remove_object_terms( $object_id, array( (int) $old->term_id ), 'go_platform' );
			}
		}
		wp_delete_term( (int) $old->term_id, 'go_platform' );
	}

	update_option( 'go_verge_v24_platform_redirects', $redirects, false );
	update_option( 'go_verge_platform_consolidation_v24', '2026-08-25-v24', false );
}
add_action( 'admin_init', 'go_verge_v24_consolidate_platform_terms', 28 );

function go_verge_v24_redirect_legacy_platform_urls() {
	if ( is_admin() || wp_doing_ajax() ) { return; }
	$path = trim( (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH ), '/' );
	if ( ! $path ) { return; }
	$redirects = (array) get_option( 'go_verge_v24_platform_redirects', array() );
	if ( isset( $redirects[ $path ] ) && $redirects[ $path ] ) {
		$current = home_url( '/' . $path . '/' );
		/* A stale migration map must never redirect a URL to itself. When that
		 * happens, fall through to the live term resolver below. */
		if ( untrailingslashit( (string) $redirects[ $path ] ) !== untrailingslashit( (string) $current ) ) {
			wp_safe_redirect( $redirects[ $path ], 301, 'Overdrive durable platform hub' );
			exit;
		}
	}
	if ( preg_match( '#^plataformas/([^/]+)/?$#', $path, $match ) ) {
		$map = go_verge_v24_platform_consolidation_map();
		$old = sanitize_title( $match[1] );
		if ( isset( $map[ $old ] ) ) {
			$new = get_term_by( 'slug', $map[ $old ], 'go_platform' );
			if ( $new instanceof WP_Term ) {
				$url = get_term_link( $new );
				if ( ! is_wp_error( $url ) ) {
					wp_safe_redirect( $url, 301, 'Overdrive durable platform hub' );
					exit;
				}
			}
		}
	}
}
add_action( 'template_redirect', 'go_verge_v24_redirect_legacy_platform_urls', 0 );

/** Production library, parallel to the Games CPT. */
function go_verge_v7_register_productions() {
	if ( ! post_type_exists( 'productions' ) ) {
		register_post_type( 'productions', array(
			'labels' => array(
				'name'=>'Produções','singular_name'=>'Produção','menu_name'=>'Produções',
				'all_items'=>'Biblioteca de produções','add_new_item'=>'Adicionar produção','edit_item'=>'Editar produção','search_items'=>'Buscar produções',
			),
			'public'       => true,
			'show_in_rest' => true,
			'menu_position'=> 22,
			'menu_icon'    => 'dashicons-format-video',
			'supports'     => array('title','editor','thumbnail','excerpt','revisions'),
			'has_archive'  => true,
			'rewrite'      => array('slug'=>'producoes','with_front'=>false),
		) );
	}
}
add_action( 'init', 'go_verge_v7_register_productions', 8 );

function go_verge_v7_register_meta() {
	register_post_meta( 'post', '_go_primary_category_id', array('type'=>'integer','single'=>true,'default'=>0,'show_in_rest'=>true,'sanitize_callback'=>'absint','auth_callback'=>static function(){return current_user_can('edit_posts');}) );
	register_post_meta( 'post', '_go_production_id', array('type'=>'integer','single'=>true,'default'=>0,'show_in_rest'=>true,'sanitize_callback'=>'absint','auth_callback'=>static function(){return current_user_can('edit_posts');}) );
	register_post_meta( 'post', '_go_entity_ids', array(
		'type'=>'array','single'=>true,'default'=>array(),'show_in_rest'=>array('schema'=>array('type'=>'array','items'=>array('type'=>'integer'))),
		'sanitize_callback'=>static function($v){return array_values(array_unique(array_filter(array_map('absint',(array)$v))));},
		'auth_callback'=>static function(){return current_user_can('edit_posts');},
	) );
	foreach ( array('_go_original_title','_go_country','_go_seasons','_go_episodes','_go_cast','_go_watch','_go_production_status','_go_next_release') as $key ) {
		register_post_meta( 'productions', $key, array('type'=>'string','single'=>true,'default'=>'','show_in_rest'=>true,'sanitize_callback'=>'sanitize_text_field','auth_callback'=>static function(){return current_user_can('edit_posts');}) );
	}
}
add_action( 'init', 'go_verge_v7_register_meta', 12 );

function go_verge_v7_ensure_term( $taxonomy, $slug, $name, $parent = 0 ) {
	$term = get_term_by( 'slug', $slug, $taxonomy );
	if ( $term instanceof WP_Term ) {
		$updates=array(); if($term->name!==$name){$updates['name']=$name;} if('category'===$taxonomy && (int)$term->parent!==(int)$parent){$updates['parent']=$parent;}
		if($updates){$updated=wp_update_term($term->term_id,$taxonomy,$updates); if(!is_wp_error($updated)){$term=get_term($term->term_id,$taxonomy);} }
		return $term instanceof WP_Term ? $term : null;
	}
	$created = wp_insert_term( $name, $taxonomy, array_filter(array('slug'=>$slug,'parent'=>$parent)) );
	if ( is_wp_error($created) || empty($created['term_id']) ) { return null; }
	$term=get_term((int)$created['term_id'],$taxonomy); return $term instanceof WP_Term ? $term : null;
}

function go_verge_v7_provision_vocabulary() {
	if ( ! current_user_can('manage_categories') ) { return; }
	foreach ( go_verge_v7_category_blueprint() as $root_slug=>$root ) {
		$parent=go_verge_v7_ensure_term('category',$root_slug,$root['name'],0); if(!$parent){continue;}
		foreach($root['children'] as $slug=>$name){go_verge_v7_ensure_term('category',$slug,$name,(int)$parent->term_id);}
	}
	foreach(go_verge_v7_vocabularies() as $tax=>$config){foreach($config['terms'] as $slug=>$name){go_verge_v7_ensure_term($tax,$slug,$name,0);}}
	$technical=go_verge_v7_ensure_term('category','interno','Interno (não publicar)',0);
	if($technical){update_option('default_category',(int)$technical->term_id,false);}
}

/**
 * Provision the editorial vocabulary only when the theme is switched or when
 * the architecture screen explicitly needs it. Running term inserts/updates on
 * every admin_init made Gutenberg pay taxonomy-migration cost on every DOM/API
 * boot and could leave post-new.php apparently loading forever.
 */
function go_verge_v9_provision_vocabulary_once() {
	if ( ! current_user_can( 'manage_categories' ) ) {
		return;
	}
	$version = GO_VERGE_ARCH_V7_VERSION . '-v9';
	if ( $version === (string) get_option( 'go_verge_editorial_vocab_ready', '' ) ) {
		return;
	}
	go_verge_v7_provision_vocabulary();
	update_option( 'go_verge_editorial_vocab_ready', $version, false );
}
add_action( 'after_switch_theme', 'go_verge_v9_provision_vocabulary_once', 24 );

function go_verge_v9_architecture_screen_provision() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) ) {
		return;
	}
	$page = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( 'go-verge-architecture' !== $page ) {
		return;
	}
	go_verge_v9_provision_vocabulary_once();
}
add_action( 'admin_init', 'go_verge_v9_architecture_screen_provision', 24 );

/** Ensure the newer “Onde assistir” format exists after theme updates too. */
function go_verge_v39_ensure_where_to_watch_type() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) || ! taxonomy_exists( 'go_content_type' ) ) { return; }
	if ( '1' === (string) get_option( 'go_verge_where_to_watch_type_ready', '' ) && get_term_by( 'slug', 'onde-assistir', 'go_content_type' ) instanceof WP_Term ) { return; }
	$term = go_verge_v7_ensure_term( 'go_content_type', 'onde-assistir', 'Onde assistir', 0 );
	if ( $term instanceof WP_Term ) { update_option( 'go_verge_where_to_watch_type_ready', '1', false ); }
}
add_action( 'admin_init', 'go_verge_v39_ensure_where_to_watch_type', 25 );

/** Legacy structural term maps. */
function go_verge_v7_legacy_maps() {
	return array(
		'category' => array(
			'noticias-games'=>'games','noticias-de-games'=>'games','noticias-entretenimento'=>'entretenimento','noticias-de-entretenimento'=>'entretenimento','noticias-tecnologia'=>'tecnologia','noticias-de-tecnologia'=>'tecnologia','consoles'=>'games','mobile'=>'games',
			'especiais-games'=>'especiais','especiais-de-games'=>'especiais','especiais-entretenimento'=>'entretenimento','rankings-games'=>'games','rankings-entretenimento'=>'entretenimento','impressoes'=>'games','guias-de-compra-games'=>'guias-de-compra',
			'cinema'=>'filmes','filme'=>'filmes','manga-e-quadrinhos'=>'anime-e-manga','mangas-e-quadrinhos'=>'anime-e-manga','manga'=>'anime-e-manga','anime'=>'anime-e-manga','animes'=>'anime-e-manga',
			'dicas-e-guias'=>'dicas-e-guias','dicas'=>'dicas-e-guias','dica'=>'dicas-e-guias','guia'=>'dicas-e-guias','guias'=>'dicas-e-guias','codigos'=>'dicas-e-guias','codigo'=>'dicas-e-guias','guia-de-trofeus'=>'dicas-e-guias','trofeus'=>'dicas-e-guias','como-roda'=>'dicas-e-guias',
			'monitores'=>'tvs-e-monitores','tvs'=>'tvs-e-monitores','tv'=>'tvs-e-monitores','softwares'=>'apps-software','software'=>'apps-software','inteligencia-artificial'=>'ia','ia'=>'ia',
			'guias-de-compra-2'=>'guias-de-compra','guias-de-compra-3'=>'guias-de-compra','guia-de-compra'=>'guias-de-compra','promocoes'=>'promocoes','promocoes-games'=>'promocoes','promocoes-eletronicos'=>'promocoes','promocoes-servicos'=>'promocoes','jogos-gratis'=>'jogos-gratis',
		),
		'platform' => array(
			'pc'=>'pc','pc-gamer'=>'pc','playstation'=>'playstation','playstation-5'=>'playstation','playstation-4'=>'playstation','ps5'=>'playstation','ps4'=>'playstation','ps5-pro'=>'playstation','xbox'=>'xbox','xbox-series'=>'xbox','xbox-series-x-s'=>'xbox','xbox-series-x'=>'xbox','xbox-series-s'=>'xbox','xbox-one'=>'xbox','nintendo'=>'nintendo','nintendo-switch'=>'nintendo','nintendo-switch-2'=>'nintendo','switch'=>'nintendo','switch-2'=>'nintendo',
		),
		'service' => array(
			'netflix'=>'netflix','amazon-prime'=>'prime-video','prime-video'=>'prime-video','disney'=>'disney-plus','disney-plus'=>'disney-plus','hbo'=>'max','max'=>'max','apple-tv'=>'apple-tv-plus','apple-tv-plus'=>'apple-tv-plus','crunchyroll'=>'crunchyroll',
			'steam'=>'steam','playstation-plus'=>'playstation-plus','ps-plus'=>'playstation-plus','playstation-store'=>'playstation-store','xbox-game-pass'=>'xbox-game-pass','game-pass'=>'xbox-game-pass','epic-games-store'=>'epic-games-store','geforce-now'=>'geforce-now',
		),
		'content_type' => array(
			'noticias'=>'noticia','noticias-games'=>'noticia','noticias-de-games'=>'noticia','noticias-entretenimento'=>'noticia','noticias-de-entretenimento'=>'noticia','noticias-tecnologia'=>'noticia','noticias-de-tecnologia'=>'noticia',
			'especiais-games'=>'especial','especiais-entretenimento'=>'especial','rankings-games'=>'ranking','rankings-entretenimento'=>'ranking','reviews'=>'review','review'=>'review','criticas'=>'critica','critica'=>'critica','listas'=>'lista','list'=>'lista','rankings'=>'ranking','ranking'=>'ranking','especiais'=>'especial','especial'=>'especial','impressoes'=>'impressoes','onde-assistir'=>'onde-assistir','onde-assistir-online'=>'onde-assistir','assistir-online'=>'onde-assistir',
		),
		'guide_type' => array('codigos'=>'codigo','codigo'=>'codigo','guia-de-trofeus'=>'trofeu-conquista','trofeus'=>'trofeu-conquista','como-roda'=>'como-roda'),
	);
}

function go_verge_v7_post_pillar_guess( $post_id, $legacy_slugs=array() ) {
	$slugs=array_map('sanitize_title',(array)$legacy_slugs); $hay=implode(' ',$slugs).' '.sanitize_title(get_the_title($post_id));
	if(preg_match('/turc|farah|fatmag|novela/',$hay)) return 'producoes-turcas';
	if(preg_match('/anime|manga|quadrinho/',$hay)) return 'anime-e-manga';
	if(preg_match('/filme|cinema/',$hay)) return 'filmes';
	if(preg_match('/serie|stream|netflix|prime|disney|max|hbo|apple-tv|crunchy/',$hay)) return 'series';
	if(preg_match('/hardware|software|windows|android|iphone|monitor|tv|tecnologia|ia|inteligencia-artificial/',$hay)) return 'tecnologia';
	if(preg_match('/oferta|promoc|desconto|gratis|compra/',$hay)) return 'promocoes';
	if(in_array('entretenimento',$slugs,true)) return 'entretenimento';
	if(in_array('tecnologia',$slugs,true)) return 'tecnologia';
	if(in_array('ofertas',$slugs,true)) return 'ofertas';
	return 'games';
}

function go_verge_v7_add_term_slug( $post_id, $taxonomy, $slug ) {
	$term=get_term_by('slug',$slug,$taxonomy); if($term instanceof WP_Term){wp_set_object_terms($post_id,array((int)$term->term_id),$taxonomy,true); return (int)$term->term_id;} return 0;
}

/** Explicit destinations for legacy archives that represented a format, not a topic. */
function go_verge_v7_legacy_format_archive_target( $slug ) {
	$slug = sanitize_title( $slug );
	if ( in_array( $slug, array( 'noticias', 'noticia' ), true ) ) { return function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url() : home_url( '/noticias/' ); }
	$latest = array( 'listas','lista','rankings','ranking' );
	if ( in_array( $slug, $latest, true ) ) { return home_url( '/ultimas-publicacoes/' ); }
	$roots = array(
		'especiais-games'=>'especiais','especiais-de-games'=>'especiais','rankings-games'=>'games','impressoes'=>'games',
		'especiais-entretenimento'=>'entretenimento','rankings-entretenimento'=>'entretenimento',
	);
	return isset( $roots[$slug] ) ? go_verge_v7_category_url( $roots[$slug] ) : '';
}

/** Capture an old URL path before deleting/consolidating a term. */
function go_verge_v7_remember_redirect( $term, $target_url, &$redirects ) {
	if(!($term instanceof WP_Term)||!$target_url)return;
	$link=get_term_link($term); if(!is_wp_error($link)){$path=trim((string)wp_parse_url($link,PHP_URL_PATH),'/'); if($path)$redirects[$path]=$target_url;}
	$redirects['category/'.$term->slug]=$target_url;
	$redirects[$term->slug]=$target_url;
}

/** Versioned migration: reclassify first, then retire redundant category relationships. */
function go_verge_v7_run_migration() {
	if(!current_user_can('manage_categories') || get_option('go_verge_arch_v7_migration')===GO_VERGE_ARCH_V7_VERSION)return;
	go_verge_v7_provision_vocabulary();
	$maps=go_verge_v7_legacy_maps(); $redirects=(array)get_option('go_verge_v7_redirects',array());
	$legacy_terms=get_terms(array('taxonomy'=>'category','hide_empty'=>false)); if(is_wp_error($legacy_terms))return;
	$blue=go_verge_v7_category_blueprint(); $canonical=array('interno'); foreach($blue as $rslug=>$r){$canonical[]=$rslug; $canonical=array_merge($canonical,array_keys($r['children']));}

	foreach($legacy_terms as $term){
		$slug=sanitize_title($term->slug); if(in_array($slug,$canonical,true))continue;
		$posts=get_objects_in_term((int)$term->term_id,'category'); if(is_wp_error($posts))$posts=array();
		foreach(array_map('absint',(array)$posts) as $post_id){
			if('post'!==get_post_type($post_id))continue;
			$existing=wp_get_post_terms($post_id,'category',array('fields'=>'slugs')); $existing=is_wp_error($existing)?array():$existing;
			$target=$maps['category'][$slug]??'';
			/* Legacy "Mobile" mixed Android and iOS. Do not falsely convert the
			 * whole archive to Android: infer only when the story itself says which. */
			if('mobile'===$slug){
				$mobile_hay=sanitize_title(get_the_title($post_id).' '.get_post_field('post_excerpt',$post_id).' '.wp_trim_words(wp_strip_all_tags((string)get_post_field('post_content',$post_id)),120,' '));
				if(preg_match('/(?:^|-)(?:ios|iphone|ipad)(?:-|$)/',$mobile_hay)){go_verge_v7_add_term_slug($post_id,'go_platform','ios');}
				elseif(preg_match('/(?:^|-)android(?:-|$)/',$mobile_hay)){go_verge_v7_add_term_slug($post_id,'go_platform','android');}
			}
			if(isset($maps['platform'][$slug])){go_verge_v7_add_term_slug($post_id,'go_platform',$maps['platform'][$slug]);}
			if(isset($maps['service'][$slug])){go_verge_v7_add_term_slug($post_id,'go_service',$maps['service'][$slug]); if(!$target)$target=go_verge_v7_post_pillar_guess($post_id,$existing);}
			if(isset($maps['content_type'][$slug])){go_verge_v7_add_term_slug($post_id,'go_content_type',$maps['content_type'][$slug]); if(!$target)$target=go_verge_v7_post_pillar_guess($post_id,$existing);}
			if(isset($maps['guide_type'][$slug])){go_verge_v7_add_term_slug($post_id,'go_guide_type',$maps['guide_type'][$slug]); $target='dicas-e-guias'; go_verge_v7_add_term_slug($post_id,'go_content_type','guia');}
			if(in_array($slug,array('sem-categoria','uncategorized','tudo'),true)){$target=go_verge_v7_post_pillar_guess($post_id,$existing);}
			if(!$target && (isset($maps['platform'][$slug])||isset($maps['service'][$slug])))$target=go_verge_v7_post_pillar_guess($post_id,$existing);
			if($target){$new_id=go_verge_v7_add_term_slug($post_id,'category',$target); if($new_id&&!get_post_meta($post_id,'_go_primary_category_id',true))update_post_meta($post_id,'_go_primary_category_id',$new_id);}
			if(isset($maps['category'][$slug])||isset($maps['platform'][$slug])||isset($maps['service'][$slug])||isset($maps['content_type'][$slug])||isset($maps['guide_type'][$slug])||in_array($slug,array('sem-categoria','uncategorized','tudo'),true)){
				wp_remove_object_terms($post_id,array((int)$term->term_id),'category');
			}
		}
		$target_slug=$maps['category'][$slug]??''; if(!$target_slug && (isset($maps['platform'][$slug])||isset($maps['service'][$slug])||isset($maps['content_type'][$slug])))$target_slug='';
		$target_url='';
		if($target_slug){$t=get_term_by('slug',$target_slug,'category'); if($t instanceof WP_Term){$u=get_term_link($t); if(!is_wp_error($u))$target_url=$u;}}
		elseif(in_array($slug,array('tudo','sem-categoria','uncategorized'),true)){$target_url=home_url('/ultimas-publicacoes/');}
		elseif(isset($maps['platform'][$slug])){$t=get_term_by('slug',$maps['platform'][$slug],'go_platform'); if($t instanceof WP_Term){$u=get_term_link($t);if(!is_wp_error($u))$target_url=$u;}}
		elseif(isset($maps['service'][$slug])){$t=get_term_by('slug',$maps['service'][$slug],'go_service'); if($t instanceof WP_Term){$u=get_term_link($t);if(!is_wp_error($u))$target_url=$u;}}
		if(!$target_url){$target_url=go_verge_v7_legacy_format_archive_target($slug);}
		if($target_url)go_verge_v7_remember_redirect($term,$target_url,$redirects);
	}

	/* Move structural tags to the new taxonomies; entity-like tags become controlled entity records. */
	$tags=get_terms(array('taxonomy'=>'post_tag','hide_empty'=>false));
	if(!is_wp_error($tags))foreach($tags as $tag){
		$slug=sanitize_title($tag->slug); $posts=get_objects_in_term((int)$tag->term_id,'post_tag'); if(is_wp_error($posts))$posts=array();
		$struct_tax='';$struct_slug='';
		if(isset($maps['platform'][$slug])){$struct_tax='go_platform';$struct_slug=$maps['platform'][$slug];}
		elseif(isset($maps['service'][$slug])){$struct_tax='go_service';$struct_slug=$maps['service'][$slug];}
		elseif(isset($maps['content_type'][$slug])){$struct_tax='go_content_type';$struct_slug=$maps['content_type'][$slug];}
		if($struct_tax){foreach(array_map('absint',(array)$posts) as $pid){if('post'===get_post_type($pid)){go_verge_v7_add_term_slug($pid,$struct_tax,$struct_slug);wp_remove_object_terms($pid,array((int)$tag->term_id),'post_tag');}}continue;}
		/* Reuse a first-class Game or Production before creating a generic entity. */
		$game = get_page_by_path( $slug, OBJECT, 'games' );
		if ( ! ( $game instanceof WP_Post ) ) {
			$game = get_page_by_title( $tag->name, OBJECT, 'games' );
		}
		if ( $game instanceof WP_Post ) {
			foreach ( array_map( 'absint', (array) $posts ) as $pid ) {
				if ( 'post' !== get_post_type( $pid ) ) { continue; }
				if ( ! absint( get_post_meta( $pid, 'go_linked_game_id', true ) ) ) { update_post_meta( $pid, 'go_linked_game_id', (int) $game->ID ); }
				wp_remove_object_terms( $pid, array( (int) $tag->term_id ), 'post_tag' );
			}
			$redirects['tag/'.$slug] = get_permalink( $game ); $redirects[$slug] = get_permalink( $game );
			continue;
		}

		$production = get_page_by_path( $slug, OBJECT, 'productions' );
		if ( ! ( $production instanceof WP_Post ) ) { $production = get_page_by_title( $tag->name, OBJECT, 'productions' ); }
		if ( $production instanceof WP_Post ) {
			foreach ( array_map( 'absint', (array) $posts ) as $pid ) {
				if ( 'post' !== get_post_type( $pid ) ) { continue; }
				if ( ! absint( get_post_meta( $pid, '_go_production_id', true ) ) ) { update_post_meta( $pid, '_go_production_id', (int) $production->ID ); }
				wp_remove_object_terms( $pid, array( (int) $tag->term_id ), 'post_tag' );
			}
			$redirects['tag/'.$slug] = get_permalink( $production ); $redirects[$slug] = get_permalink( $production );
			continue;
		}

		$entity=get_page_by_path($slug,OBJECT,'go_entity');
		/* V29 closed-world rule: legacy tags may reuse an entity that already
		 * exists, but they never create a new entity automatically. A recurring
		 * cast member, character or incidental noun is not a public hub merely
		 * because it appeared in several articles. */
		if($entity instanceof WP_Post){
			foreach(array_map('absint',(array)$posts) as $pid){if('post'!==get_post_type($pid))continue;$ids=(array)get_post_meta($pid,'_go_entity_ids',true);$ids[]= (int)$entity->ID;update_post_meta($pid,'_go_entity_ids',array_values(array_unique(array_filter(array_map('absint',$ids)))));wp_remove_object_terms($pid,array((int)$tag->term_id),'post_tag');}
			if('publish'===$entity->post_status){$redirects['tag/'.$slug]=get_permalink($entity); $redirects[$slug]=get_permalink($entity);}
		}
		/* One-off/low-volume tags stay as legacy noindex terms. They are hidden
		 * from the editor and sitemap, but are not promoted into thin entity hubs. */
	}

	update_option('go_verge_v7_redirects',$redirects,false);
	update_option('go_verge_arch_v7_migration',GO_VERGE_ARCH_V7_VERSION,false);
	delete_option('go_verge_rewrites_flushed');
	go_verge_flush_rewrite_rules_once_per_request();
}
// V8: full migration is never executed during ordinary editor/admin boot.
// Run structural migration deliberately from maintenance tooling/CLI after backup.

/** Permanent legacy URL map, independent of whether the old WP term still exists. */
function go_verge_v7_final_redirect_target( $target ) {
	$target = esc_url_raw( (string) $target, array( 'http', 'https' ) );
	if ( ! $target ) { return ''; }
	/* The audit resolver knows the current category-base and entity ownership
	 * rules. Applying it at read time also repairs maps created before Rank Math
	 * removed /category/ from public URLs. */
	if ( function_exists( 'go_verge_audit_direct_internal_destination' ) ) {
		$target = go_verge_audit_direct_internal_destination( $target );
	}
	return esc_url_raw( $target, array( 'http', 'https' ) );
}

/** Destination the permanent V7 map gives a site-relative path, or '' when the path is served. */
function go_verge_v7_legacy_map_target( $path ) {
	$path = trim( (string) $path, '/' );
	if ( '' === $path ) { return ''; }
	$map    = (array) get_option( 'go_verge_v7_redirects', array() );
	$target = go_verge_v7_final_redirect_target( go_verge_safe_legacy_redirect_target( $path, $map ) );
	return ( $target && untrailingslashit( $target ) !== untrailingslashit( home_url( '/' . $path . '/' ) ) ) ? $target : '';
}

/**
 * Whether go_verge_v7_legacy_redirects() answers this path with a 301.
 *
 * WordPress Pages can still exist at retired addresses such as /xbox/ or
 * /rankings/; the XML sitemap uses this to avoid submitting redirects.
 */
function go_verge_v7_path_is_redirected( $path ) {
	$path = trim( (string) $path, '/' );
	if ( '' === $path || 'noticias' === $path || preg_match( '#^noticias/page/[0-9]+$#', $path ) ) { return false; }
	if ( preg_match( '#^(?:category/)?noticia(?:s)?(?:/page/([1-9][0-9]*))?$#', $path ) ) { return true; }
	return '' !== go_verge_v7_legacy_map_target( $path );
}

function go_verge_v7_legacy_redirects() {
	if(is_admin()||wp_doing_ajax()||is_feed())return;
	$path=trim((string)wp_parse_url(isset($_SERVER['REQUEST_URI'])?wp_unslash($_SERVER['REQUEST_URI']):'',PHP_URL_PATH),'/'); if(!$path)return;
	/* /noticias/ is now a first-class newsroom route. Never let a stale V7 map
	 * redirect it back to the catch-all latest feed. Old category URLs converge
	 * on the permanent newsroom instead. */
	if ( 'noticias' === $path || preg_match( '#^noticias/page/[0-9]+$#', $path ) ) { return; }
	if ( preg_match( '#^(?:category/)?noticia(?:s)?(?:/page/([1-9][0-9]*))?$#', $path, $news_legacy ) ) {
		$page = ! empty( $news_legacy[1] ) ? absint( $news_legacy[1] ) : 1;
		$target = function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url( $page ) : home_url( '/noticias/' );
		wp_safe_redirect( $target, 301, 'Overdrive newsroom consolidation' ); exit;
	}
	$target = go_verge_v7_legacy_map_target( $path );
	if ( $target ) { wp_safe_redirect( $target, 301, 'Overdrive architecture V7' ); exit; }
}
add_action('template_redirect','go_verge_v7_legacy_redirects',0);

/** Persist the final destinations once so admin reports and content migrations
 * no longer expose historical two-hop targets. */
function go_verge_v7_normalize_redirect_targets() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) || get_option( 'go_verge_v7_redirect_targets_v355' ) ) { return; }
	$map = (array) get_option( 'go_verge_v7_redirects', array() );
	foreach ( $map as $path => $target ) {
		$map[ $path ] = go_verge_v7_final_redirect_target( $target );
	}
	update_option( 'go_verge_v7_redirects', array_filter( $map ), false );
	update_option( 'go_verge_v7_redirect_targets_v355', GO_VERGE_VERSION, false );
}
add_action( 'admin_init', 'go_verge_v7_normalize_redirect_targets', 61 );

/** Strategic service hub URLs; preserve /netflix/ and use clean streaming hubs. */
function go_verge_v7_service_term_link($url,$term,$taxonomy){
	if('go_service'!==$taxonomy||!($term instanceof WP_Term))return $url;
	$paths=array('netflix'=>'/netflix/','prime-video'=>'/streaming/prime-video/','disney-plus'=>'/streaming/disney-plus/','max'=>'/streaming/max/','apple-tv-plus'=>'/streaming/apple-tv-plus/','crunchyroll'=>'/streaming/crunchyroll/','globoplay'=>'/streaming/globoplay/','steam'=>'/steam/','xbox-game-pass'=>'/game-pass/','playstation-plus'=>'/ps-plus/','playstation-store'=>'/playstation-store/','epic-games-store'=>'/epic-games-store/','geforce-now'=>'/geforce-now/');
	return isset($paths[$term->slug])?home_url($paths[$term->slug]):$url;
}
add_filter('term_link','go_verge_v7_service_term_link',60,3);
function go_verge_v7_service_rewrites(){
	$map=array('netflix'=>'netflix','streaming/prime-video'=>'prime-video','streaming/disney-plus'=>'disney-plus','streaming/max'=>'max','streaming/apple-tv-plus'=>'apple-tv-plus','streaming/crunchyroll'=>'crunchyroll','streaming/globoplay'=>'globoplay','steam'=>'steam','game-pass'=>'xbox-game-pass','ps-plus'=>'playstation-plus','playstation-store'=>'playstation-store','epic-games-store'=>'epic-games-store','geforce-now'=>'geforce-now');
	foreach($map as $path=>$slug){add_rewrite_rule('^'.preg_quote($path,'#').'/?$','index.php?go_service='.$slug,'top'); add_rewrite_rule('^'.preg_quote($path,'#').'/page/([0-9]+)/?$','index.php?go_service='.$slug.'&paged=$matches[1]','top');}
}
add_action('init','go_verge_v7_service_rewrites',18);

/** All legacy tag archives are noindex; entity hubs are the indexable topic surface. */
function go_verge_v7_tag_robots($robots){if(is_tag()){$robots['noindex']=true;$robots['follow']=true;unset($robots['index']);}if(is_category('interno')){$robots['noindex']=true;$robots['follow']=true;unset($robots['index']);}return $robots;}
add_filter('wp_robots','go_verge_v7_tag_robots',200);
function go_verge_v7_rank_math_tag_robots($robots){if(is_tag()||is_category('interno')){$robots['index']='noindex';$robots['follow']='follow';}return $robots;}
add_filter('rank_math/frontend/robots','go_verge_v7_rank_math_tag_robots',200);

/** Hide legacy free-form tags from article editing after migration. */
function go_verge_v7_retire_post_tags_ui(){if(taxonomy_exists('post_tag')){unregister_taxonomy_for_object_type('post_tag','post');}}
add_action('init','go_verge_v7_retire_post_tags_ui',99);
function go_verge_v7_hide_legacy_tag_management(){remove_submenu_page('edit.php','edit-tags.php?taxonomy=post_tag');}
add_action('admin_menu','go_verge_v7_hide_legacy_tag_management',999);

/**
 * Architecture checks are advisory only.
 *
 * Do not downgrade a publish request to draft when category/type metadata is
 * incomplete. The newsroom UI warns the author twice during the native
 * Gutenberg publish flow, while WordPress remains free to save/publish.
 */
function go_verge_v7_has_real_category($post_id){$terms=wp_get_post_terms($post_id,'category');if(is_wp_error($terms))return false;foreach($terms as $t){if('interno'!==$t->slug)return true;}return false;}

/** Content type now owns Article subtype. */
/** A single valid editorial choice; contaminated/ambiguous data is unresolved. */
function go_verge_v7_post_content_type( $post_id ) {
	$terms = get_the_terms( absint( $post_id ), 'go_content_type' );
	if ( ! is_array( $terms ) || ! $terms ) { return ''; }
	$allowed = go_verge_v3152_content_type_slugs();
	$valid = array();
	foreach ( $terms as $term ) {
		if ( ! ( $term instanceof WP_Term ) ) { continue; }
		$slug = sanitize_title( $term->slug );
		if ( in_array( $slug, $allowed, true ) ) { $valid[ $slug ] = true; }
	}
	return 1 === count( $valid ) ? (string) key( $valid ) : '';
}
function go_verge_v7_schema_type($type,$post){if($post instanceof WP_Post){return 'noticia'===go_verge_v7_post_content_type($post->ID)?'NewsArticle':'Article';}return $type;}
add_filter('go_verge_article_schema_type_auto','go_verge_v7_schema_type',200,2);

/** Production meta box. */
function go_verge_v7_production_meta_box(){add_meta_box('go-v7-production-data','Ficha da produção','go_verge_v7_render_production_meta_box','productions','normal','high');}
add_action('add_meta_boxes_productions','go_verge_v7_production_meta_box');
function go_verge_v7_render_production_meta_box($post){wp_nonce_field('go_v7_prod_save','go_v7_prod_nonce');$fields=array('_go_original_title'=>'Título original','_go_country'=>'País','_go_seasons'=>'Temporadas','_go_episodes'=>'Episódios','_go_cast'=>'Elenco','_go_watch'=>'Onde assistir','_go_production_status'=>'Status','_go_next_release'=>'Próxima estreia');echo '<div class="go-v7-prod-grid">';foreach($fields as $key=>$label){printf('<label><span>%s</span><input type="text" class="widefat" name="%s" value="%s"></label>',esc_html($label),esc_attr($key),esc_attr(get_post_meta($post->ID,$key,true)));}echo '</div>';}
function go_verge_v7_save_production_meta($post_id){if(!isset($_POST['go_v7_prod_nonce'])||!wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['go_v7_prod_nonce'])),'go_v7_prod_save')||!current_user_can('edit_post',$post_id))return;foreach(array('_go_original_title','_go_country','_go_seasons','_go_episodes','_go_cast','_go_watch','_go_production_status','_go_next_release') as $key){if(isset($_POST[$key]))update_post_meta($post_id,$key,sanitize_text_field(wp_unslash($_POST[$key])));}}
add_action('save_post_productions','go_verge_v7_save_production_meta');

/** AJAX production/entity search + minimum production creation for the article editor. */
function go_verge_v7_ajax_search(){check_ajax_referer('go_verge_editorial_v7','nonce');if(!current_user_can('edit_posts'))wp_send_json_error(array('message'=>'Sem permissão.'),403);$kind=sanitize_key($_POST['kind']??'');$q=sanitize_text_field(wp_unslash($_POST['q']??''));$type='production'===$kind?'productions':'go_entity';$status='production'===$kind?'publish':array('publish','draft');$items=get_posts(array('post_type'=>$type,'post_status'=>$status,'s'=>$q,'posts_per_page'=>12,'orderby'=>'relevance'));wp_send_json_success(array('items'=>array_map(static function($p){return array('id'=>(int)$p->ID,'title'=>get_the_title($p),'thumb'=>get_the_post_thumbnail_url($p,'thumbnail')?:'','status'=>$p->post_status);},$items)));}
add_action('wp_ajax_go_verge_v7_search','go_verge_v7_ajax_search');
function go_verge_v7_ajax_create_production(){check_ajax_referer('go_verge_editorial_v7','nonce');$post_id=absint($_POST['post_id']??0);if(!$post_id||!current_user_can('edit_post',$post_id))wp_send_json_error(array('message'=>'Sem permissão.'),403);$name=sanitize_text_field(wp_unslash($_POST['name']??''));if(mb_strlen($name)<2)wp_send_json_error(array('message'=>'Informe o nome.'),400);$existing=get_page_by_title($name,OBJECT,'productions');$id=$existing instanceof WP_Post?(int)$existing->ID:wp_insert_post(array('post_type'=>'productions','post_status'=>'publish','post_title'=>$name),true);if(is_wp_error($id))wp_send_json_error(array('message'=>$id->get_error_message()),500);foreach(array('original'=>'_go_original_title','country'=>'_go_country','seasons'=>'_go_seasons','episodes'=>'_go_episodes','cast'=>'_go_cast','watch'=>'_go_watch','status'=>'_go_production_status','next'=>'_go_next_release') as $request=>$meta){if(isset($_POST[$request]))update_post_meta($id,$meta,sanitize_text_field(wp_unslash($_POST[$request])));}if(isset($_POST['cover_id'])){$cover_id=absint($_POST['cover_id']);if($cover_id&&wp_attachment_is_image($cover_id))set_post_thumbnail($id,$cover_id);}update_post_meta($post_id,'_go_production_id',(int)$id);wp_send_json_success(array('item'=>array('id'=>(int)$id,'title'=>get_the_title($id),'thumb'=>get_the_post_thumbnail_url($id,'thumbnail')?:'')));}
add_action('wp_ajax_go_verge_v7_create_production','go_verge_v7_ajax_create_production');

/** Admin/editor assets. */
function go_verge_v7_editor_assets( $hook ) {
	if ( defined( 'GED_VERSION' ) ) { return; }
	if ( ! in_array( $hook, array( 'post.php','post-new.php' ), true ) ) { return; }
	$screen=get_current_screen(); if(!$screen||'post'!==$screen->post_type)return;
	wp_enqueue_media();
	wp_enqueue_script('go-verge-editorial-v7',GO_VERGE_URI.'/assets/js/editorial-architecture-v7.js',array('wp-data','wp-api-fetch','wp-components','wp-element','media-editor'),go_verge_asset_version('/assets/js/editorial-architecture-v7.js'),true);
	wp_enqueue_style('go-verge-editorial-v7',GO_VERGE_URI.'/assets/css/editorial-architecture-v7.css',array('go-verge-editorial-v6'),go_verge_asset_version('/assets/css/editorial-architecture-v7.css'));
	$post_id=isset($_GET['post'])?absint($_GET['post']):0;
	if(!$post_id&&isset($GLOBALS['post'])&&$GLOBALS['post'] instanceof WP_Post){$post_id=(int)$GLOBALS['post']->ID;}
	$production_id=$post_id?absint(get_post_meta($post_id,'_go_production_id',true)):0;
	$entity_ids=$post_id?go_verge_v7_post_entity_ids($post_id):array();
	$production=$production_id?get_post($production_id):null;
	$entities=array(); foreach($entity_ids as $id){$entity=get_post($id);if($entity instanceof WP_Post&&'go_entity'===$entity->post_type)$entities[]=array('id'=>(int)$id,'title'=>get_the_title($id));}

	/* Never hard-code category choices in JavaScript. The editor receives the
	 * real taxonomy currently configured in WordPress, including new desks. */
	$category_options = array();
	$all_categories   = get_categories( array( 'hide_empty' => false, 'orderby' => 'name', 'order' => 'ASC' ) );
	foreach ( (array) $all_categories as $category ) {
		if ( ! ( $category instanceof WP_Term ) ) { continue; }
		$slug = sanitize_title( $category->slug );
		if ( in_array( $slug, go_verge_v7_technical_category_slugs(), true ) || in_array( $slug, go_verge_v7_deprecated_editor_category_slugs(), true ) ) { continue; }
		$category_options[] = array(
			'id'     => (int) $category->term_id,
			'slug'   => $slug,
			'name'   => $category->name,
			'label'  => function_exists( 'go_verge_editorial_category_path' ) ? go_verge_editorial_category_path( $category ) : $category->name,
			'parent' => (int) $category->parent,
			'depth'  => count( get_ancestors( $category->term_id, 'category', 'taxonomy' ) ),
		);
	}
	usort( $category_options, static function( $a, $b ) { return strcasecmp( $a['label'], $b['label'] ); } );

	wp_localize_script('go-verge-editorial-v7','GoVergeEditorialV7',array(
		'ajaxUrl'=>admin_url('admin-ajax.php'),'nonce'=>wp_create_nonce('go_verge_editorial_v7'),'postId'=>$post_id,
		'productionId'=>$production_id,'entityIds'=>$entity_ids,
		'production'=>$production instanceof WP_Post?array('id'=>(int)$production->ID,'title'=>get_the_title($production)):null,
		'entities'=>$entities,
		'entitiesAdminUrl'=>admin_url('edit.php?post_type=go_entity'),
		'newEntityUrl'=>admin_url('post-new.php?post_type=go_entity'),
		'categoryOptions'=>$category_options,
		'editorialStructure'=>function_exists('go_verge_editorial_structure_payload')?go_verge_editorial_structure_payload():null,
		'contentTypeSlugs'=>go_verge_v3152_content_type_slugs(),
		'technicalCategorySlugs'=>go_verge_v7_technical_category_slugs(),
		'taxonomies'=>array('contentType'=>'go_content_type','platform'=>'go_platform','service'=>'go_service','guideType'=>'go_guide_type'),
	));
}
add_action('admin_enqueue_scripts','go_verge_v7_editor_assets',110);

/** Production page query helper. */
function go_verge_v7_production_related_posts($production_id,$limit=12){return get_posts(array('post_type'=>'post','post_status'=>'publish','posts_per_page'=>$limit,'meta_key'=>'_go_production_id','meta_value'=>absint($production_id),'orderby'=>'date','order'=>'DESC'));}

/** Disable old category migrations/redirects now superseded by V7. */
remove_action('admin_init','go_verge_consolidate_guides_categories',31);
remove_action('admin_init','go_verge_consolidate_entertainment_categories',32);
/* V7 editor choice is authoritative. Do not auto-route an explicit Música,
 * Streaming or other Entertainment category back into Séries/Filmes on save. */
remove_action('save_post_post','go_verge_route_saved_entertainment_post',50);
remove_action('template_redirect','go_verge_redirect_legacy_guides_urls',2);
remove_action('template_redirect','go_verge_redirect_legacy_entertainment_urls',3);
remove_filter('term_link','go_verge_canonical_guides_term_link',21);
remove_filter('term_link','go_verge_canonical_entertainment_term_link',22);

/**
 * V7 finalization: one editorial category, one content type, clean hubs and
 * deterministic navigation. These routines intentionally sit after the legacy
 * migration definitions above so they can supersede old theme behavior without
 * deleting historical terms during the first deployment.
 */
function go_verge_v7_technical_category_slugs() {
	return array( 'interno', 'sem-categoria', 'uncategorized', 'tudo' );
}

/** Legacy editorial categories that must no longer be offered for new stories. */
function go_verge_v7_deprecated_editor_category_slugs() {
	return array( 'software-e-ia' );
}

function go_verge_v7_canonical_category_slugs() {
	$slugs = array();
	foreach ( go_verge_v7_category_blueprint() as $root_slug => $root ) {
		$slugs[] = $root_slug;
		$slugs = array_merge( $slugs, array_keys( $root['children'] ) );
	}
	return array_values( array_unique( $slugs ) );
}

function go_verge_v7_category_priority() {
	return array(
		/* Current child destinations. */
		'producoes-turcas','anime-e-manga','doramas','criticas','series','filmes','streaming','musica',
		'dicas-e-guias','reviews','lancamentos','especiais',
		'ia','apps-software','celulares','ciencia','notebooks','hardware','tvs-e-monitores',
		'guias-de-compra','jogos-gratis','promocoes',
		/* Legacy aliases retained only as a safe tie-breaker for old content. */
		'guias','software-e-ia','tutoriais',
		/* Pillars are always less specific than their children. */
		'games','entretenimento','tecnologia','ofertas',
	);
}

/** Ordered, explicit legacy-format aliases shared by reading and save fallbacks. */
function go_verge_editorial_legacy_type_categories() {
	return array(
		'review' => array( 'reviews', 'review' ),
		'critica' => array( 'criticas', 'critica' ),
		'guia-de-compra' => array( 'guias-de-compra', 'guias-de-compra-2', 'guias-de-compra-3', 'guia-de-compra', 'guias-de-compra-games' ),
		'guia' => array( 'dicas-e-guias', 'guias', 'tutoriais', 'guia', 'tutorial', 'dicas', 'dica' ),
		'onde-assistir' => array( 'onde-assistir', 'onde-assistir-online', 'assistir-online' ),
		'final-explicado' => array( 'final-explicado', 'finais-explicados' ),
		'ranking' => array( 'rankings', 'ranking', 'rankings-games', 'rankings-entretenimento' ),
		'lista' => array( 'listas', 'lista' ),
		'especial' => array( 'especiais', 'especial', 'especiais-games', 'especiais-de-games', 'especiais-entretenimento' ),
		'impressoes' => array( 'impressoes' ),
		'oferta' => array( 'promocoes', 'promocao', 'ofertas', 'jogos-gratis', 'promocoes-games', 'promocoes-eletronicos', 'promocoes-servicos' ),
		'noticia' => array( 'noticia', 'noticias', 'news', 'noticias-games', 'noticias-de-games', 'noticias-entretenimento', 'noticias-de-entretenimento', 'noticias-tecnologia', 'noticias-de-tecnologia' ),
	);
}

function go_verge_v7_default_type_for_categories( $slugs ) {
	$slugs = array_map( 'sanitize_title', (array) $slugs );
	foreach ( go_verge_editorial_legacy_type_categories() as $type => $aliases ) {
		if ( array_intersect( $slugs, $aliases ) ) { return $type; }
	}
	foreach ( $slugs as $slug ) {
		if ( in_array( $slug, array( 'noticia', 'noticias', 'news' ), true )
			|| preg_match( '/^(?:noticia|noticias|news)-(?:de-)?(?:games|jogos|entretenimento|tecnologia|tech)(?:-|$)/', $slug ) ) {
			return 'noticia';
		}
	}
	/* An editoria describes subject matter, not whether the story is news. */
	return '';
}

/** Select the most specific real category, without letting stale root meta win. */
function go_verge_v7_pick_primary_category_term( $terms, $post_id = 0 ) {
	$real = array_values( array_filter( (array) $terms, static function( $term ) {
		return $term instanceof WP_Term && ! in_array( sanitize_title( $term->slug ), go_verge_v7_technical_category_slugs(), true );
	} ) );
	if ( empty( $real ) ) { return null; }

	$depths    = array();
	$max_depth = -1;
	foreach ( $real as $term ) {
		$depth = count( get_ancestors( $term->term_id, 'category', 'taxonomy' ) );
		$depths[ (int) $term->term_id ] = $depth;
		$max_depth = max( $max_depth, $depth );
	}
	$candidates = array_values( array_filter( $real, static function( $term ) use ( $depths, $max_depth ) {
		return isset( $depths[ (int) $term->term_id ] ) && $depths[ (int) $term->term_id ] === $max_depth;
	} ) );

	$post_id = absint( $post_id );
	if ( $post_id ) {
		/* An explicit principal in the hierarchy editor survives secondary/legacy categories. */
		foreach ( array( '_go_primary_category_id', 'rank_math_primary_category', '_yoast_wpseo_primary_category' ) as $meta_key ) {
			$primary_id = absint( get_post_meta( $post_id, $meta_key, true ) );
			if ( ! $primary_id ) { continue; }
			$primary_candidates = function_exists( 'go_verge_editorial_structure_payload' ) ? $real : $candidates;
			foreach ( $primary_candidates as $candidate ) {
				if ( (int) $candidate->term_id === $primary_id ) { return $candidate; }
			}
		}
	}

	$priority = array_flip( go_verge_v7_category_priority() );
	usort( $candidates, static function( $a, $b ) use ( $priority ) {
		$a_slug = sanitize_title( $a->slug );
		$b_slug = sanitize_title( $b->slug );
		$a_rank = isset( $priority[ $a_slug ] ) ? $priority[ $a_slug ] : PHP_INT_MAX;
		$b_rank = isset( $priority[ $b_slug ] ) ? $priority[ $b_slug ] : PHP_INT_MAX;
		if ( $a_rank !== $b_rank ) { return $a_rank <=> $b_rank; }
		return (int) $a->term_id <=> (int) $b->term_id;
	} );
	return $candidates ? $candidates[0] : null;
}

/**
 * Detect durable editorial formats that can be inferred with very high
 * confidence from the story itself. This is intentionally narrow: only the
 * literal "final explicado" pattern is automatic, so a ranking, guide or
 * review is never silently reclassified by a fuzzy keyword matcher.
 */
function go_verge_v25_detect_content_type( $post_id ) {
	$post = get_post( absint( $post_id ) );
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) { return ''; }

	$slug  = sanitize_title( (string) $post->post_name );
	$title = strtolower( remove_accents( wp_strip_all_tags( (string) $post->post_title ) ) );

	if ( false !== strpos( $slug, 'onde-assistir' ) || false !== strpos( $title, 'onde assistir' ) ) {
		return 'onde-assistir';
	}
	if ( false !== strpos( $slug, 'final-explicado' ) || false !== strpos( $title, 'final explicado' ) ) {
		return 'final-explicado';
	}
	return '';
}

/** Normalize one story without touching its URL or post body. */
function go_verge_v7_normalize_post_architecture( $post_id ) {
	$post_id = absint( $post_id );
	if ( ! $post_id || 'post' !== get_post_type( $post_id ) ) { return; }
	$terms = wp_get_post_terms( $post_id, 'category' );
	if ( is_wp_error( $terms ) ) { return; }
	$by_slug = array();
	foreach ( $terms as $term ) {
		if ( $term instanceof WP_Term ) { $by_slug[ sanitize_title( $term->slug ) ] = $term; }
	}

	/* Keep incomplete classifications visible to the editor. A title keyword
	 * must never silently assign Games or change an existing article's desk. */
	$real_terms = array_values( array_filter( $terms, static function( $term ) {
		return $term instanceof WP_Term && ! in_array( sanitize_title( $term->slug ), go_verge_v7_technical_category_slugs(), true );
	} ) );

	/*
	 * Exactly one primary editorial category. Child depth is authoritative, so a stale
	 * root meta (for example Games) can never override IA, Música or another
	 * real child selected by the editor. Future categories also work because
	 * this selector is taxonomy-driven rather than an allow-list.
	 */
	$winner = go_verge_v7_pick_primary_category_term( $real_terms, $post_id );
	if ( $winner instanceof WP_Term ) {
		/* Preserve all assigned categories, matching the REST save contract.
		 * Primary metadata expresses precedence without deleting relationships. */
		update_post_meta( $post_id, '_go_primary_category_id', (int) $winner->term_id );
		update_post_meta( $post_id, 'rank_math_primary_category', (int) $winner->term_id );
		update_post_meta( $post_id, '_yoast_wpseo_primary_category', (int) $winner->term_id );
		$category_slugs = array( sanitize_title( $winner->slug ) );
	} else {
		delete_post_meta( $post_id, '_go_primary_category_id' );
		delete_post_meta( $post_id, 'rank_math_primary_category' );
		delete_post_meta( $post_id, '_yoast_wpseo_primary_category' );
		$category_slugs = array_keys( $by_slug );
	}

	/* Every story has one explicit type; highly deterministic formats win over
	 * the generic default, while explicit specialist choices remain untouched. */
	$types      = wp_get_post_terms( $post_id, 'go_content_type', array( 'fields' => 'slugs' ) );
	if ( is_wp_error( $types ) ) { return; }
	$detected   = go_verge_v25_detect_content_type( $post_id );
	$allowed    = go_verge_v3152_content_type_slugs();
	$valid      = is_wp_error( $types ) ? array() : array_values( array_filter( array_map( 'sanitize_title', (array) $types ), static function( $slug ) use ( $allowed ) { return in_array( $slug, $allowed, true ); } ) );
	/* Multiple explicit formats need an editorial choice. Do not pick whichever
	 * term the database happened to return first and erase the others. */
	if ( count( array_unique( $valid ) ) > 1 ) { return; }
	$current    = $valid ? $valid[0] : '';
	$target     = $current ?: ( $detected ?: go_verge_v7_default_type_for_categories( $category_slugs ) );
	/* An explicit current choice always wins, including Notícia/Especial. */
	$target = in_array( sanitize_title( $target ), $allowed, true ) ? sanitize_title( $target ) : '';
	if ( '' === $target || $current === $target ) { return; }
	/* Set exactly one canonical term. This also detaches any contaminated terms. */
	$term = get_term_by( 'slug', $target, 'go_content_type' );
	if ( $term instanceof WP_Term ) { wp_set_object_terms( $post_id, array( (int) $term->term_id ), 'go_content_type', false ); }

	/*
	 * Keep an explicit Schema choice. Tipo de matéria drives the automatic
	 * default, but it must not silently erase a deliberate editor override.
	 */
}

/** V3.15.2: remove invalid Formato terms once and repair only affected posts in small admin batches. */
function go_verge_v3152_prune_invalid_content_types() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) || get_option( 'go_verge_content_type_vocab_v3152' ) ) { return; }
	$allowed = go_verge_v3152_content_type_slugs();
	$terms = get_terms( array( 'taxonomy' => 'go_content_type', 'hide_empty' => false ) );
	$affected = array();
	if ( ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			if ( in_array( sanitize_title( $term->slug ), $allowed, true ) ) { continue; }
			$ids = get_objects_in_term( (int) $term->term_id, 'go_content_type' );
			if ( ! is_wp_error( $ids ) ) { $affected = array_merge( $affected, array_map( 'absint', $ids ) ); }
			wp_delete_term( (int) $term->term_id, 'go_content_type' );
		}
	}
	$affected = array_values( array_unique( array_filter( $affected ) ) );
	if ( $affected ) { update_option( 'go_verge_content_type_repair_v3152', $affected, false ); }
	update_option( 'go_verge_content_type_vocab_v3152', 1, false );
}
add_action( 'admin_init', 'go_verge_v3152_prune_invalid_content_types', 36 );

function go_verge_v3152_repair_content_type_posts() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) ) { return; }
	$queue = get_option( 'go_verge_content_type_repair_v3152', array() );
	if ( ! is_array( $queue ) || ! $queue ) { return; }
	$batch = array_splice( $queue, 0, 40 );
	foreach ( $batch as $post_id ) { go_verge_v7_normalize_post_architecture( absint( $post_id ) ); }
	if ( $queue ) { update_option( 'go_verge_content_type_repair_v3152', $queue, false ); }
	else { delete_option( 'go_verge_content_type_repair_v3152' ); }
}
add_action( 'admin_init', 'go_verge_v3152_repair_content_type_posts', 37 );

/**
 * V3.15.3 architecture migration runner.
 *
 * V3.15.2 deliberately detached the V7 migration from admin_init, but did not
 * attach it to another executor. The audit screen therefore stayed forever at
 * "Pendente/em execução" / "0 matérias percorridas". V3.15.3 runs both phases
 * from WP-Cron, with an atomic lock, a hard wall-clock budget and self-chained
 * single events. Ordinary front-end and Gutenberg requests never perform the
 * migration itself.
 */
function go_verge_v3153_arch_schedule_once( $hook, $delay = 60 ) {
	if ( ! wp_next_scheduled( $hook ) ) {
		wp_schedule_single_event( time() + max( 15, absint( $delay ) ), $hook );
	}
}

function go_verge_v3153_seed_architecture_jobs() {
	if ( ! current_user_can( 'manage_categories' ) ) { return; }
	if ( get_option( 'go_verge_arch_v7_migration' ) !== GO_VERGE_ARCH_V7_VERSION ) {
		go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_terms_batch', 20 );
		return;
	}
	if ( get_option( 'go_verge_arch_v7_cleanup_done' ) !== GO_VERGE_ARCH_V7_VERSION ) {
		go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_cleanup_batch', 30 );
	}
}
add_action( 'admin_init', 'go_verge_v3153_seed_architecture_jobs', 42 );

function go_verge_v3153_next_term_id( $taxonomy, $after_id, $skip_canonical = false ) {
	$ids = get_terms( array(
		'taxonomy'   => $taxonomy,
		'hide_empty' => false,
		'fields'     => 'ids',
		'orderby'    => 'term_id',
		'order'      => 'ASC',
	) );
	if ( is_wp_error( $ids ) ) { return 0; }
	$canonical = $skip_canonical ? array_merge( array( 'interno' ), go_verge_v7_canonical_category_slugs() ) : array();
	foreach ( array_map( 'absint', $ids ) as $term_id ) {
		if ( $term_id <= absint( $after_id ) ) { continue; }
		if ( $skip_canonical ) {
			$term = get_term( $term_id, $taxonomy );
			if ( ! ( $term instanceof WP_Term ) || in_array( sanitize_title( $term->slug ), $canonical, true ) ) { continue; }
		}
		return $term_id;
	}
	return 0;
}

function go_verge_v3153_process_legacy_category_post( $post_id, $term, $maps ) {
	if ( 'post' !== get_post_type( $post_id ) ) { return; }
	$slug     = sanitize_title( $term->slug );
	$existing = wp_get_post_terms( $post_id, 'category', array( 'fields' => 'slugs' ) );
	$existing = is_wp_error( $existing ) ? array() : $existing;
	$target   = isset( $maps['category'][ $slug ] ) ? $maps['category'][ $slug ] : '';

	if ( 'mobile' === $slug ) {
		$mobile_hay = sanitize_title( get_the_title( $post_id ) . ' ' . get_post_field( 'post_excerpt', $post_id ) . ' ' . wp_trim_words( wp_strip_all_tags( (string) get_post_field( 'post_content', $post_id ) ), 120, ' ' ) );
		if ( preg_match( '/(?:^|-)(?:ios|iphone|ipad)(?:-|$)/', $mobile_hay ) ) { go_verge_v7_add_term_slug( $post_id, 'go_platform', 'ios' ); }
		elseif ( preg_match( '/(?:^|-)android(?:-|$)/', $mobile_hay ) ) { go_verge_v7_add_term_slug( $post_id, 'go_platform', 'android' ); }
	}
	if ( isset( $maps['platform'][ $slug ] ) ) { go_verge_v7_add_term_slug( $post_id, 'go_platform', $maps['platform'][ $slug ] ); }
	if ( isset( $maps['service'][ $slug ] ) ) { go_verge_v7_add_term_slug( $post_id, 'go_service', $maps['service'][ $slug ] ); if ( ! $target ) { $target = go_verge_v7_post_pillar_guess( $post_id, $existing ); } }
	if ( isset( $maps['content_type'][ $slug ] ) ) { go_verge_v7_add_term_slug( $post_id, 'go_content_type', $maps['content_type'][ $slug ] ); if ( ! $target ) { $target = go_verge_v7_post_pillar_guess( $post_id, $existing ); } }
	if ( isset( $maps['guide_type'][ $slug ] ) ) { go_verge_v7_add_term_slug( $post_id, 'go_guide_type', $maps['guide_type'][ $slug ] ); $target = 'dicas-e-guias'; go_verge_v7_add_term_slug( $post_id, 'go_content_type', 'guia' ); }
	if ( in_array( $slug, array( 'sem-categoria', 'uncategorized', 'tudo' ), true ) ) { $target = go_verge_v7_post_pillar_guess( $post_id, $existing ); }
	if ( ! $target && ( isset( $maps['platform'][ $slug ] ) || isset( $maps['service'][ $slug ] ) ) ) { $target = go_verge_v7_post_pillar_guess( $post_id, $existing ); }
	if ( $target ) {
		$new_id = go_verge_v7_add_term_slug( $post_id, 'category', $target );
		if ( $new_id && ! get_post_meta( $post_id, '_go_primary_category_id', true ) ) { update_post_meta( $post_id, '_go_primary_category_id', $new_id ); }
	}
	if ( isset( $maps['category'][ $slug ] ) || isset( $maps['platform'][ $slug ] ) || isset( $maps['service'][ $slug ] ) || isset( $maps['content_type'][ $slug ] ) || isset( $maps['guide_type'][ $slug ] ) || in_array( $slug, array( 'sem-categoria', 'uncategorized', 'tudo' ), true ) ) {
		wp_remove_object_terms( $post_id, array( (int) $term->term_id ), 'category' );
	}
}

function go_verge_v3153_finalize_legacy_category_term( $term, $maps, &$redirects ) {
	$slug        = sanitize_title( $term->slug );
	$target_slug = isset( $maps['category'][ $slug ] ) ? $maps['category'][ $slug ] : '';
	$target_url  = '';
	if ( $target_slug ) {
		$t = get_term_by( 'slug', $target_slug, 'category' );
		if ( $t instanceof WP_Term ) { $u = get_term_link( $t ); if ( ! is_wp_error( $u ) ) { $target_url = $u; } }
	} elseif ( in_array( $slug, array( 'tudo', 'sem-categoria', 'uncategorized' ), true ) ) {
		$target_url = home_url( '/ultimas-publicacoes/' );
	} elseif ( isset( $maps['platform'][ $slug ] ) ) {
		$t = get_term_by( 'slug', $maps['platform'][ $slug ], 'go_platform' );
		if ( $t instanceof WP_Term ) { $u = get_term_link( $t ); if ( ! is_wp_error( $u ) ) { $target_url = $u; } }
	} elseif ( isset( $maps['service'][ $slug ] ) ) {
		$t = get_term_by( 'slug', $maps['service'][ $slug ], 'go_service' );
		if ( $t instanceof WP_Term ) { $u = get_term_link( $t ); if ( ! is_wp_error( $u ) ) { $target_url = $u; } }
	}
	if ( ! $target_url ) { $target_url = go_verge_v7_legacy_format_archive_target( $slug ); }
	if ( $target_url ) { go_verge_v7_remember_redirect( $term, $target_url, $redirects ); }
}

function go_verge_v3153_tag_target( $tag, $maps ) {
	$slug = sanitize_title( $tag->slug );
	$out  = array( 'tax' => '', 'struct_slug' => '', 'game' => null, 'production' => null, 'entity' => null );
	if ( isset( $maps['platform'][ $slug ] ) ) { $out['tax'] = 'go_platform'; $out['struct_slug'] = $maps['platform'][ $slug ]; return $out; }
	if ( isset( $maps['service'][ $slug ] ) ) { $out['tax'] = 'go_service'; $out['struct_slug'] = $maps['service'][ $slug ]; return $out; }
	if ( isset( $maps['content_type'][ $slug ] ) ) { $out['tax'] = 'go_content_type'; $out['struct_slug'] = $maps['content_type'][ $slug ]; return $out; }
	$out['game'] = get_page_by_path( $slug, OBJECT, 'games' );
	if ( ! ( $out['game'] instanceof WP_Post ) ) { $out['game'] = get_page_by_title( $tag->name, OBJECT, 'games' ); }
	if ( $out['game'] instanceof WP_Post ) { return $out; }
	$out['production'] = get_page_by_path( $slug, OBJECT, 'productions' );
	if ( ! ( $out['production'] instanceof WP_Post ) ) { $out['production'] = get_page_by_title( $tag->name, OBJECT, 'productions' ); }
	if ( $out['production'] instanceof WP_Post ) { return $out; }
	$out['entity'] = get_page_by_path( $slug, OBJECT, 'go_entity' );
	return $out;
}

function go_verge_v3153_process_legacy_tag_post( $post_id, $tag, $target ) {
	if ( 'post' !== get_post_type( $post_id ) ) { return; }
	if ( $target['tax'] ) {
		go_verge_v7_add_term_slug( $post_id, $target['tax'], $target['struct_slug'] );
		wp_remove_object_terms( $post_id, array( (int) $tag->term_id ), 'post_tag' );
		return;
	}
	if ( $target['game'] instanceof WP_Post ) {
		if ( ! absint( get_post_meta( $post_id, 'go_linked_game_id', true ) ) ) { update_post_meta( $post_id, 'go_linked_game_id', (int) $target['game']->ID ); }
		wp_remove_object_terms( $post_id, array( (int) $tag->term_id ), 'post_tag' );
		return;
	}
	if ( $target['production'] instanceof WP_Post ) {
		if ( ! absint( get_post_meta( $post_id, '_go_production_id', true ) ) ) { update_post_meta( $post_id, '_go_production_id', (int) $target['production']->ID ); }
		wp_remove_object_terms( $post_id, array( (int) $tag->term_id ), 'post_tag' );
		return;
	}
	if ( $target['entity'] instanceof WP_Post ) {
		$ids   = (array) get_post_meta( $post_id, '_go_entity_ids', true );
		$ids[] = (int) $target['entity']->ID;
		update_post_meta( $post_id, '_go_entity_ids', array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) ) );
		wp_remove_object_terms( $post_id, array( (int) $tag->term_id ), 'post_tag' );
	}
}

function go_verge_v3153_finalize_legacy_tag( $tag, $target, &$redirects ) {
	if ( $target['tax'] ) { return; }
	$slug = sanitize_title( $tag->slug );
	if ( $target['game'] instanceof WP_Post ) {
		$url = get_permalink( $target['game'] ); $redirects[ 'tag/' . $slug ] = $url; $redirects[ $slug ] = $url;
	} elseif ( $target['production'] instanceof WP_Post ) {
		$url = get_permalink( $target['production'] ); $redirects[ 'tag/' . $slug ] = $url; $redirects[ $slug ] = $url;
	} elseif ( $target['entity'] instanceof WP_Post && 'publish' === $target['entity']->post_status ) {
		$url = get_permalink( $target['entity'] ); $redirects[ 'tag/' . $slug ] = $url; $redirects[ $slug ] = $url;
	}
}

function go_verge_v3153_arch_terms_batch() {
	if ( get_option( 'go_verge_arch_v7_migration' ) === GO_VERGE_ARCH_V7_VERSION ) { return; }
	if ( ! go_verge_claim_job_lock( 'arch_v7_terms_v3153', 180 ) ) {
		go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_terms_batch', 90 );
		return;
	}
	$deadline = microtime( true ) + 8.0;
	$limit    = 40;
	$handled  = 0;
	$state    = get_option( 'go_verge_arch_v7_terms_state_v3153', array() );
	$state    = wp_parse_args( is_array( $state ) ? $state : array(), array(
		'phase' => 'category', 'last_term_id' => 0, 'active_term_id' => 0, 'last_post_id' => 0, 'processed' => 0,
	) );
	$maps      = go_verge_v7_legacy_maps();
	$redirects = (array) get_option( 'go_verge_v7_redirects', array() );
	go_verge_v7_provision_vocabulary();

	try {
		while ( $handled < $limit && microtime( true ) < $deadline ) {
			$taxonomy = 'category' === $state['phase'] ? 'category' : 'post_tag';
			if ( ! absint( $state['active_term_id'] ) ) {
				$next = go_verge_v3153_next_term_id( $taxonomy, absint( $state['last_term_id'] ), 'category' === $state['phase'] );
				if ( ! $next ) {
					if ( 'category' === $state['phase'] ) {
						$state['phase'] = 'tag'; $state['last_term_id'] = 0; $state['active_term_id'] = 0; $state['last_post_id'] = 0;
						continue;
					}
					update_option( 'go_verge_v7_redirects', $redirects, false );
					update_option( 'go_verge_arch_v7_migration', GO_VERGE_ARCH_V7_VERSION, false );
					delete_option( 'go_verge_arch_v7_terms_state_v3153' );
					delete_option( 'go_verge_rewrites_flushed' );
					go_verge_flush_rewrite_rules_once_per_request();
					wp_clear_scheduled_hook( 'go_verge_v3153_arch_terms_batch' );
					go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_cleanup_batch', 20 );
					return;
				}
				$state['active_term_id'] = $next;
				$state['last_post_id'] = 0;
			}

			$term = get_term( absint( $state['active_term_id'] ), $taxonomy );
			if ( ! ( $term instanceof WP_Term ) ) {
				$state['last_term_id'] = absint( $state['active_term_id'] ); $state['active_term_id'] = 0; $state['last_post_id'] = 0;
				continue;
			}
			$objects = get_objects_in_term( (int) $term->term_id, $taxonomy );
			$objects = is_wp_error( $objects ) ? array() : array_values( array_unique( array_map( 'absint', $objects ) ) );
			sort( $objects, SORT_NUMERIC );
			$remaining = array_values( array_filter( $objects, static function( $id ) use ( $state ) { return $id > absint( $state['last_post_id'] ); } ) );
			if ( ! $remaining ) {
				if ( 'category' === $state['phase'] ) { go_verge_v3153_finalize_legacy_category_term( $term, $maps, $redirects ); }
				else { $target = go_verge_v3153_tag_target( $term, $maps ); go_verge_v3153_finalize_legacy_tag( $term, $target, $redirects ); }
				$state['last_term_id'] = (int) $term->term_id; $state['active_term_id'] = 0; $state['last_post_id'] = 0;
				continue;
			}

			$target = 'tag' === $state['phase'] ? go_verge_v3153_tag_target( $term, $maps ) : null;
			foreach ( array_slice( $remaining, 0, $limit - $handled ) as $post_id ) {
				if ( microtime( true ) >= $deadline ) { break; }
				if ( 'category' === $state['phase'] ) { go_verge_v3153_process_legacy_category_post( $post_id, $term, $maps ); }
				else { go_verge_v3153_process_legacy_tag_post( $post_id, $term, $target ); }
				$state['last_post_id'] = $post_id; $state['processed'] = absint( $state['processed'] ) + 1; $handled++;
			}
		}
		update_option( 'go_verge_v7_redirects', $redirects, false );
		update_option( 'go_verge_arch_v7_terms_state_v3153', $state, false );
		go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_terms_batch', 60 );
	} finally {
		go_verge_release_job_lock( 'arch_v7_terms_v3153' );
	}
}
add_action( 'go_verge_v3153_arch_terms_batch', 'go_verge_v3153_arch_terms_batch' );

/** Existing-post normalization: bounded background batches, never admin_init. */
function go_verge_v7_cleanup_existing_posts_batch() {
	$key      = 'go_verge_arch_v7_cleanup_cursor';
	$done_key = 'go_verge_arch_v7_cleanup_done';
	if ( get_option( $done_key ) === GO_VERGE_ARCH_V7_VERSION ) { return; }
	if ( get_option( 'go_verge_arch_v7_migration' ) !== GO_VERGE_ARCH_V7_VERSION ) {
		go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_terms_batch', 30 );
		return;
	}
	if ( ! go_verge_claim_job_lock( 'arch_v7_cleanup_v3153', 180 ) ) {
		go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_cleanup_batch', 90 );
		return;
	}
	$offset   = max( 0, absint( get_option( $key, 0 ) ) );
	$deadline = microtime( true ) + 8.0;
	$ids      = get_posts( array(
		'post_type' => 'post', 'post_status' => 'any', 'posts_per_page' => 60, 'offset' => $offset,
		'orderby' => 'ID', 'order' => 'ASC', 'fields' => 'ids', 'suppress_filters' => true, 'no_found_rows' => true,
	) );
	$processed = 0;
	try {
		foreach ( $ids as $id ) {
			if ( microtime( true ) >= $deadline ) { break; }
			go_verge_v7_normalize_post_architecture( $id );
			$processed++;
		}
		$offset += $processed;
		if ( $processed === count( $ids ) && count( $ids ) < 60 ) {
			update_option( $done_key, GO_VERGE_ARCH_V7_VERSION, false );
			delete_option( $key );
			wp_clear_scheduled_hook( 'go_verge_v3153_arch_cleanup_batch' );
		} else {
			update_option( $key, $offset, false );
			go_verge_v3153_arch_schedule_once( 'go_verge_v3153_arch_cleanup_batch', 60 );
		}
	} finally {
		go_verge_release_job_lock( 'arch_v7_cleanup_v3153' );
	}
}
add_action( 'go_verge_v3153_arch_cleanup_batch', 'go_verge_v7_cleanup_existing_posts_batch' );

function go_verge_v7_cleanup_notice() {
	if ( function_exists( 'go_verge_editorial_preservation_enabled' ) && go_verge_editorial_preservation_enabled() ) { return; }
	if ( ! current_user_can( 'manage_categories' ) || get_option( 'go_verge_arch_v7_cleanup_done' ) === GO_VERGE_ARCH_V7_VERSION ) { return; }
	$cursor = absint( get_option( 'go_verge_arch_v7_cleanup_cursor', 0 ) );
	$terms_done = get_option( 'go_verge_arch_v7_migration' ) === GO_VERGE_ARCH_V7_VERSION;
	$state = (array) get_option( 'go_verge_arch_v7_terms_state_v3153', array() );
	if ( ! $terms_done ) {
		$phase = 'tag' === ( $state['phase'] ?? 'category' ) ? 'tags' : 'categorias';
		$count = absint( $state['processed'] ?? 0 );
		echo '<div class="notice notice-info"><p><strong>Overdrive V7:</strong> migração editorial em background (' . esc_html( $phase ) . '). ' . esc_html( number_format_i18n( $count ) ) . ' relações processadas; a normalização das matérias começa automaticamente em seguida.</p></div>';
		return;
	}
	echo '<div class="notice notice-info"><p><strong>Overdrive V7:</strong> normalização editorial em background. ' . esc_html( number_format_i18n( $cursor ) ) . ' matérias já percorridas.</p></div>';
}
add_action( 'admin_notices', 'go_verge_v7_cleanup_notice' );

/** New stories are normalized after taxonomy relationships have been persisted. */
function go_verge_v7_normalize_saved_post( $post_id, $post, $update ) {
	if ( wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) || ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type ) { return; }
	if ( defined( 'REST_REQUEST' ) && REST_REQUEST ) { return; } // REST gate/editor already sends the canonical terms.
	go_verge_v7_normalize_post_architecture( $post_id );
}
add_action( 'save_post_post', 'go_verge_v7_normalize_saved_post', 140, 3 );

/**
 * Gutenberg persists categories through the REST API. After WordPress has saved
 * those relationships, reconcile only the primary-category metadata with the
 * categories that actually exist on the post. Never rewrite the categories here.
 */
function go_verge_v7_sync_primary_category_after_rest( $post, $request, $creating ) {
	if ( ! ( $post instanceof WP_Post ) || 'post' !== $post->post_type || ! current_user_can( 'edit_post', $post->ID ) ) { return; }
	$terms = wp_get_post_terms( $post->ID, 'category' );
	if ( is_wp_error( $terms ) ) { return; }
	$primary = go_verge_v7_pick_primary_category_term( $terms, $post->ID );
	if ( $primary instanceof WP_Term ) {
		update_post_meta( $post->ID, '_go_primary_category_id', (int) $primary->term_id );
	} else {
		delete_post_meta( $post->ID, '_go_primary_category_id' );
	}
	if ( function_exists( 'go_verge_sync_primary_category' ) ) {
		go_verge_sync_primary_category( $post->ID, $post );
	}

	/* Categories are already durable at this point. Guarantee the secondary
	 * editorial type as well, because News sitemap membership depends on it. */
	$types   = wp_get_post_terms( $post->ID, 'go_content_type', array( 'fields' => 'slugs' ) );
	if ( is_wp_error( $types ) ) { return; }
	$allowed = go_verge_v3152_content_type_slugs();
	$valid   = is_wp_error( $types ) ? array() : array_values( array_filter( array_map( 'sanitize_title', (array) $types ), static function( $slug ) use ( $allowed ) {
		return in_array( $slug, $allowed, true );
	} ) );
	if ( empty( $valid ) ) {
		$category_slugs = wp_list_pluck( (array) $terms, 'slug' );
		$detected       = go_verge_v25_detect_content_type( $post->ID );
		$target         = $detected ?: go_verge_v7_default_type_for_categories( $category_slugs );
		$target         = in_array( sanitize_title( $target ), $allowed, true ) ? sanitize_title( $target ) : '';
		if ( '' === $target ) { return; }
		$type_term      = get_term_by( 'slug', $target, 'go_content_type' );
		if ( $type_term instanceof WP_Term ) {
			wp_set_object_terms( $post->ID, array( (int) $type_term->term_id ), 'go_content_type', false );
		}
	}
}
add_action( 'rest_after_insert_post', 'go_verge_v7_sync_primary_category_after_rest', 95, 3 );

/**
 * One-time, bounded migration for already-published "final explicado" stories.
 * Uses the post slug/title index directly instead of loading every post in
 * wp-admin. Existing explicit specialist types are respected.
 */
function go_verge_v25_migrate_final_explicado() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) || get_option( 'go_verge_final_explicado_v1' ) ) { return; }
	if ( ! taxonomy_exists( 'go_content_type' ) ) { return; }

	go_verge_v7_ensure_term( 'go_content_type', 'final-explicado', 'Final explicado', 0 );

	global $wpdb;
	$like_slug  = '%' . $wpdb->esc_like( 'final-explicado' ) . '%';
	$like_title = '%' . $wpdb->esc_like( 'final explicado' ) . '%';
	$ids = $wpdb->get_col(
		$wpdb->prepare(
			"SELECT ID FROM {$wpdb->posts}
			 WHERE post_type = 'post'
			   AND post_status NOT IN ('trash','auto-draft')
			   AND (post_name LIKE %s OR LOWER(post_title) LIKE %s)
			 ORDER BY ID ASC
			 LIMIT 1000",
			$like_slug,
			$like_title
		)
	);

	foreach ( array_map( 'absint', (array) $ids ) as $post_id ) {
		$current = wp_get_post_terms( $post_id, 'go_content_type', array( 'fields' => 'slugs' ) );
		if ( is_wp_error( $current ) ) { continue; }
		$current = array_map( 'sanitize_title', (array) $current );
		if ( ! $current || ( 1 === count( $current ) && in_array( $current[0], array( 'noticia', 'especial' ), true ) ) ) {
			$term = get_term_by( 'slug', 'final-explicado', 'go_content_type' );
			if ( $term instanceof WP_Term ) {
				wp_set_object_terms( $post_id, array( (int) $term->term_id ), 'go_content_type', false );
			}
		}
	}
	update_option( 'go_verge_final_explicado_v1', 1, false );
}
add_action( 'admin_init', 'go_verge_v25_migrate_final_explicado', 34 );

/** One-time, bounded migration for literal “onde assistir” stories. */
function go_verge_v39_migrate_onde_assistir() {
	if ( ! is_admin() || ! current_user_can( 'manage_categories' ) || get_option( 'go_verge_onde_assistir_v1' ) ) { return; }
	if ( ! taxonomy_exists( 'go_content_type' ) ) { return; }

	$term = go_verge_v7_ensure_term( 'go_content_type', 'onde-assistir', 'Onde assistir', 0 );
	if ( ! ( $term instanceof WP_Term ) ) { return; }

	global $wpdb;
	$like_slug  = '%' . $wpdb->esc_like( 'onde-assistir' ) . '%';
	$like_title = '%' . $wpdb->esc_like( 'onde assistir' ) . '%';
	$ids = $wpdb->get_col(
		$wpdb->prepare(
			"SELECT ID FROM {$wpdb->posts}
			 WHERE post_type = 'post'
			   AND post_status NOT IN ('trash','auto-draft')
			   AND (post_name LIKE %s OR LOWER(post_title) LIKE %s)
			 ORDER BY ID ASC
			 LIMIT 1000",
			$like_slug,
			$like_title
		)
	);

	foreach ( array_map( 'absint', (array) $ids ) as $post_id ) {
		$current = wp_get_post_terms( $post_id, 'go_content_type', array( 'fields' => 'slugs' ) );
		if ( is_wp_error( $current ) ) { continue; }
		$current = array_map( 'sanitize_title', (array) $current );
		if ( ! $current || ( 1 === count( $current ) && in_array( $current[0], array( 'noticia', 'guia', 'especial' ), true ) ) ) {
			wp_set_object_terms( $post_id, array( (int) $term->term_id ), 'go_content_type', false );
		}
	}
	update_option( 'go_verge_onde_assistir_v1', 1, false );
}
add_action( 'admin_init', 'go_verge_v39_migrate_onde_assistir', 35 );

/** Ensure the new public taxonomy rewrites and platform routes are rebuilt once. */
function go_verge_v25_flush_rewrites_once() {
	if ( ! is_admin() || ! current_user_can( 'manage_options' ) || get_option( 'go_verge_rewrites_v25' ) ) { return; }
	go_verge_flush_rewrite_rules_once_per_request();
	update_option( 'go_verge_rewrites_v25', 1, false );
}
add_action( 'admin_init', 'go_verge_v25_flush_rewrites_once', 99 );

/**
 * Gutenberg publish transport stays native and non-blocking.
 *
 * Previous builds returned WP_Error(400) here for missing category, content
 * type or review score. That turned an editorial checklist into a hard save
 * failure. Keep the function as a compatibility no-op in case an extension
 * calls it directly, but intentionally do not attach it to rest_pre_insert_post.
 */
function go_verge_v7_rest_publish_gate( $prepared_post, $request ) {
	return $prepared_post;
}
// Intentionally NOT attached to rest_pre_insert_post: warnings live in the editor UI.

/** NewsArticle follows the explicit content type, not a category called Notícias. */
function go_verge_v7_news_article_decision( $post ) {
	$post = get_post( $post );
	return $post instanceof WP_Post && 'post' === $post->post_type && 'noticia' === go_verge_v7_post_content_type( $post->ID );
}

/** Retire the manual schema chooser: content type owns the Article subtype. */
function go_verge_v7_retire_schema_metabox() {
	remove_action( 'add_meta_boxes_post', 'go_verge_register_schema_type_metabox', 24 );
}
add_action( 'init', 'go_verge_v7_retire_schema_metabox', 100 );

/** Tags are legacy-only: keep redirects but remove them from every XML sitemap. */
function go_verge_v7_exclude_tag_sitemap_taxonomy( $taxonomies ) {
	if ( is_array( $taxonomies ) ) { unset( $taxonomies['post_tag'] ); }
	return $taxonomies;
}
add_filter( 'wp_sitemaps_taxonomies', 'go_verge_v7_exclude_tag_sitemap_taxonomy', 200 );
function go_verge_v7_rank_math_exclude_tags( $url, $type, $object ) {
	if ( 'term' === $type && $object instanceof WP_Term && 'post_tag' === $object->taxonomy ) { return false; }
	return $url;
}
add_filter( 'rank_math/sitemap/entry', 'go_verge_v7_rank_math_exclude_tags', 200, 3 );

/** Only canonical editorial categories belong in XML sitemaps during transition. */
function go_verge_v7_category_sitemap_args( $args, $taxonomy ) {
	if ( 'category' !== $taxonomy ) { return $args; }
	$ids = array();
	$terms = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => true, 'number' => 5000, 'update_term_meta_cache' => false ) );
	if ( ! is_wp_error( $terms ) ) {
		foreach ( $terms as $term ) {
			$is_editorial = function_exists( 'go_verge_category_parity_is_editorial_term' )
				? go_verge_category_parity_is_editorial_term( $term )
				: in_array( sanitize_title( $term->slug ), go_verge_v7_canonical_category_slugs(), true );
			if ( $is_editorial ) { $ids[] = (int) $term->term_id; }
		}
	}
	if ( $ids ) { $args['include'] = array_values( array_unique( $ids ) ); $args['hide_empty'] = true; }
	return $args;
}
add_filter( 'wp_sitemaps_taxonomies_query_args', 'go_verge_v7_category_sitemap_args', 200, 2 );

function go_verge_v7_rank_math_canonical_category_sitemap( $url, $type, $object ) {
	if ( 'term' === $type && $object instanceof WP_Term && 'category' === $object->taxonomy ) {
		$is_editorial = function_exists( 'go_verge_category_parity_is_editorial_term' )
			? go_verge_category_parity_is_editorial_term( $object )
			: in_array( sanitize_title( $object->slug ), go_verge_v7_canonical_category_slugs(), true );
		if ( ! $is_editorial ) { return false; }
	}
	return $url;
}
add_filter( 'rank_math/sitemap/entry', 'go_verge_v7_rank_math_canonical_category_sitemap', 210, 3 );

/** Canonical category URL helper. Games is a real editorial hub at /games/. */
function go_verge_v7_category_url( $slug ) {
	/* Called dozens of times per page (header, offcanvas, cards, schema); each
	 * call was its own term query. The URL cannot change within one request. */
	static $memo = array(), $by_slug = null;
	$slug = sanitize_title( $slug );
	if ( isset( $memo[ $slug ] ) ) { return $memo[ $slug ]; }
	if ( 'games' === $slug ) { return $memo[ $slug ] = ( get_post_type_archive_link( 'games' ) ?: home_url( '/games/' ) ); }
	if ( null === $by_slug && did_action( 'init' ) ) {
		$by_slug = array();
		$all = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => false, 'update_term_meta_cache' => false ) );
		foreach ( is_array( $all ) ? $all : array() as $candidate ) { if ( $candidate instanceof WP_Term ) { $by_slug[ $candidate->slug ] = $candidate; } }
	}
	$term = is_array( $by_slug ) ? ( $by_slug[ $slug ] ?? null ) : get_term_by( 'slug', $slug, 'category' );
	if ( $term instanceof WP_Term ) { $url = get_term_link( $term ); if ( ! is_wp_error( $url ) ) { return $memo[ $slug ] = $url; } }
	return $memo[ $slug ] = home_url( '/' . $slug . '/' );
}
function go_verge_v7_root_category_link( $url, $term, $taxonomy ) {
	if ( 'category' === $taxonomy && $term instanceof WP_Term && 'games' === $term->slug ) { return get_post_type_archive_link( 'games' ) ?: home_url( '/games/' ); }
	return $url;
}
add_filter( 'term_link', 'go_verge_v7_root_category_link', 90, 3 );

/** Retired Page hubs (slug => destination, redirect reason); the sitemap reads the same list. */
function go_verge_v7_retired_hub_pages() {
	return array(
		'videos'      => array( home_url( '/ultimas-publicacoes/' ), 'Overdrive retired Videos hub' ),
		'plataformas' => array( get_post_type_archive_link( 'games' ) ?: home_url( '/games/' ), 'Overdrive retired Platforms hub' ),
	);
}

/** One URL per concept: redirect duplicate public shells to the canonical hub. */
function go_verge_v7_canonical_hub_redirects() {
	if ( is_admin() || wp_doing_ajax() ) { return; }
	if ( is_category( 'games' ) ) { wp_safe_redirect( get_post_type_archive_link( 'games' ) ?: home_url( '/games/' ), 301, 'Overdrive canonical Games hub' ); exit; }
	if ( is_post_type_archive( 'go_promotion' ) ) { wp_safe_redirect( go_verge_v7_category_url( 'promocoes' ), 301, 'Overdrive canonical Offers hub' ); exit; }
	foreach ( go_verge_v7_retired_hub_pages() as $slug => $hub ) {
		if ( is_page( $slug ) ) { wp_safe_redirect( $hub[0], 301, $hub[1] ); exit; }
	}
}
add_action( 'template_redirect', 'go_verge_v7_canonical_hub_redirects', 1 );

/** Custom service aliases are canonical; /servicos/<slug>/ never competes with them. */
function go_verge_v7_service_alias_canonical_redirect() {
	if ( is_admin() || wp_doing_ajax() || ! is_tax( 'go_service' ) ) { return; }
	$term = get_queried_object();
	if ( ! ( $term instanceof WP_Term ) ) { return; }
	$target = get_term_link( $term );
	if ( is_wp_error( $target ) || ! $target ) { return; }
	$paged = max( 1, absint( get_query_var( 'paged' ) ) );
	if ( $paged > 1 ) { $target = trailingslashit( $target ) . 'page/' . $paged . '/'; }
	$request_path = trim( (string) wp_parse_url( isset($_SERVER['REQUEST_URI']) ? wp_unslash($_SERVER['REQUEST_URI']) : '', PHP_URL_PATH ), '/' );
	$target_path  = trim( (string) wp_parse_url( $target, PHP_URL_PATH ), '/' );
	if ( $request_path && $target_path && $request_path !== $target_path ) { wp_safe_redirect( $target, 301, 'Overdrive canonical service hub' ); exit; }
}
add_action( 'template_redirect', 'go_verge_v7_service_alias_canonical_redirect', 3 );

/** Give entity/service/platform archives enough density to function as real hubs. */
function go_verge_v7_archive_page_size( $query ) {
	if ( is_admin() || ! $query->is_main_query() ) { return; }
	if ( $query->is_post_type_archive( 'productions' ) || $query->is_tax( array( 'go_service', 'go_platform' ) ) ) { $query->set( 'posts_per_page', 24 ); }
}
add_action( 'pre_get_posts', 'go_verge_v7_archive_page_size', 30 );

/** V7 canonical header architecture: category/type/platform are separate concepts. */
function go_verge_v7_nav_blueprint() {
	if ( function_exists( 'go_verge_publisher_navigation_blueprint' ) ) { return go_verge_publisher_navigation_blueprint(); }
	$platform = static function( $slug ) { $t=get_term_by('slug',$slug,'go_platform'); if($t instanceof WP_Term){$u=get_term_link($t);return is_wp_error($u)?'':$u;} return ''; };
	$service  = static function( $slug ) { $t=get_term_by('slug',$slug,'go_service'); if($t instanceof WP_Term){$u=get_term_link($t);return is_wp_error($u)?'':$u;} return ''; };
	return array(
		array('label'=>'Games','url'=>go_verge_v7_category_url('games'),'items'=>array(
			array('Guias',function_exists('go_verge_editorial_guides_url')?go_verge_editorial_guides_url():go_verge_v7_category_url('dicas-e-guias')),array('Reviews',go_verge_v7_category_url('reviews')),array('Lançamentos',go_verge_v7_category_url('lancamentos')),array('Especiais',go_verge_v7_category_url('especiais')),
			array('PC',$platform('pc')),array('PlayStation',$platform('playstation')),array('Xbox',$platform('xbox')),array('Nintendo',$platform('nintendo')),
		)),
		array('label'=>'Entretenimento','url'=>go_verge_v7_category_url('entretenimento'),'items'=>array(
			array('Séries',go_verge_v7_category_url('series')),array('Filmes',go_verge_v7_category_url('filmes')),array('Produções turcas',go_verge_v7_category_url('producoes-turcas')),array('Anime e Mangá',go_verge_v7_category_url('anime-e-manga')),array('Streaming',go_verge_v7_category_url('streaming')),array('Críticas',go_verge_v7_category_url('criticas')),array('Netflix',$service('netflix')),
		)),
		array('label'=>'Tecnologia','url'=>go_verge_v7_category_url('tecnologia'),'items'=>array(
			array('Apps e Software',go_verge_v7_category_url('apps-software')),array('Inteligência Artificial',go_verge_v7_category_url('ia')),array('Hardware',go_verge_v7_category_url('hardware')),array('Celulares',go_verge_v7_category_url('celulares')),array('Notebooks',go_verge_v7_category_url('notebooks')),array('TVs e Monitores',go_verge_v7_category_url('tvs-e-monitores')),array('Ciência e Mundo',go_verge_v7_category_url('ciencia')),
		)),
		array('label'=>'Ofertas','url'=>go_verge_v7_category_url('ofertas'),'items'=>array(
			array('Ofertas',go_verge_v7_category_url('promocoes')),array('Guias de compra',go_verge_v7_category_url('guias-de-compra')),array('Jogos grátis',go_verge_v7_category_url('jogos-gratis')),
		)),
	);
}

function go_verge_v7_render_primary_nav() {
	echo '<ul class="go-nav__list go-nav__list--v7">';
	foreach ( go_verge_v7_nav_blueprint() as $group ) {
		echo '<li class="menu-item menu-item-has-children"><a href="' . esc_url( $group['url'] ) . '">' . esc_html( $group['label'] ) . '</a>';
		$items = array_values( array_filter( $group['items'], static function($i){return !empty($i[1]);} ) );
		if ( $items ) { echo '<ul class="sub-menu">'; foreach($items as $item){echo '<li class="menu-item"><a href="'.esc_url($item[1]).'">'.esc_html($item[0]).'</a></li>';} echo '</ul>'; }
		echo '</li>';
	}
	echo '</ul>';
}

function go_verge_v7_render_offcanvas_nav() {
	echo '<ul class="go-offcanvas__menu go-offcanvas__menu--smart go-offcanvas__menu--curated go-offcanvas__menu--v7">';
	$news_url = function_exists( 'go_verge_newsroom_url' ) ? go_verge_newsroom_url() : home_url( '/noticias/' );
	echo '<li class="go-offcanvas__group go-offcanvas__group--direct"><div class="go-offcanvas__group-row"><a class="go-offcanvas__group-link" href="'.esc_url($news_url).'">'.esc_html(go_verge_upper('Notícias')).'</a></div></li>';
	foreach ( go_verge_v7_nav_blueprint() as $idx => $group ) {
		$id='go-offcanvas-v7-' . $idx;
		echo '<li class="go-offcanvas__group"><div class="go-offcanvas__group-row"><a class="go-offcanvas__group-link" href="'.esc_url($group['url']).'">'.esc_html(go_verge_upper($group['label'])).'</a>';
		echo '<button type="button" class="go-offcanvas__group-toggle" aria-expanded="false" aria-controls="'.esc_attr($id).'" data-go-offcanvas-submenu-toggle><span class="screen-reader-text">'.esc_html(sprintf('Abrir opções de %s',$group['label'])).'</span><span class="go-offcanvas__chevron" aria-hidden="true"></span></button></div>';
		echo '<ul class="go-offcanvas__submenu" id="'.esc_attr($id).'" hidden>';
		foreach($group['items'] as $item){if(!empty($item[1]))echo '<li><a href="'.esc_url($item[1]).'">'.esc_html($item[0]).'</a></li>';}
		echo '</ul></li>';
	}
	echo '</ul>';
}

/** Production/entity helpers for templates and schema/linking modules. */
function go_verge_v7_post_entity_ids( $post_id ) {
	return array_values( array_unique( array_filter( array_map( 'absint', (array) get_post_meta( absint($post_id), '_go_entity_ids', true ) ) ) ) );
}
function go_verge_v7_post_production( $post_id ) {
	$id=absint(get_post_meta(absint($post_id),'_go_production_id',true)); $p=$id?get_post($id):null; return $p instanceof WP_Post && 'productions'===$p->post_type?$p:null;
}


/**
 * Public topic chips rank the primary work/entity first, then other directly
 * relevant entities and only specific recurring legacy tags. This preserves
 * the navigational value readers used to get from tags without recreating a
 * free-form tag cloud.
 *
 * @param int $post_id Post ID.
 * @param int $limit Maximum chips.
 * @return array<int,array{label:string,url:string}>
 */
function go_verge_v7_story_topic_chips( $post_id, $limit = 5 ) {
	$post_id = absint( $post_id );
	$limit   = max( 1, min( 6, absint( $limit ) ) );
	if ( ! $post_id ) { return array(); }

	$candidates = array();
	$normalize = static function ( $value ) {
		$value = remove_accents( wp_strip_all_tags( (string) $value ) );
		$value = mb_strtolower( $value, 'UTF-8' );
		return trim( preg_replace( '/\s+/u', ' ', (string) preg_replace( '/[^a-z0-9]+/u', ' ', $value ) ) );
	};
	$add = static function ( $label, $url, $score, $role = 'related' ) use ( &$candidates, $normalize ) {
		$label = trim( wp_strip_all_tags( (string) $label ) );
		$url   = esc_url_raw( (string) $url );
		$key   = $normalize( $label );
		if ( ! $label || ! $url || ! $key ) { return; }
		$url_key = untrailingslashit( strtolower( $url ) );
		$dedupe  = $key . '|' . $url_key;
		foreach ( $candidates as $existing_key => $existing ) {
			if ( $existing['name_key'] === $key || $existing['url_key'] === $url_key ) {
				if ( (int) $score > (int) $existing['score'] ) {
					$candidates[ $existing_key ]['label'] = $label;
					$candidates[ $existing_key ]['url']   = $url;
					$candidates[ $existing_key ]['score'] = (int) $score;
				}
				if ( 'primary' === $role ) { $candidates[ $existing_key ]['role'] = 'primary'; }
				return;
			}
		}
		$candidates[ $dedupe ] = array(
			'label' => $label, 'url' => $url, 'score' => (int) $score, 'role' => $role,
			'name_key' => $key, 'url_key' => $url_key,
		);
	};

	$evidence_score = static function ( $aliases ) use ( $post_id ) {
		if ( ! function_exists( 'go_verge_subject_candidate_evidence' ) ) { return 0; }
		$e = go_verge_subject_candidate_evidence( $post_id, (array) $aliases );
		$score = (int) ( $e['score'] ?? 0 ) * 8;
		if ( ! empty( $e['signals']['title'] ) )   { $score += 150; }
		if ( ! empty( $e['signals']['focus'] ) )   { $score += 70; }
		if ( ! empty( $e['signals']['support'] ) ) { $score += 55; }
		if ( ! empty( $e['signals']['alt'] ) )     { $score += 35; }
		return $score;
	};

	/* 1. One primary subject. This is what compact feeds use too. */
	$primary = function_exists( 'go_verge_article_subject' ) ? go_verge_article_subject( $post_id ) : null;
	if ( ! $primary && function_exists( 'go_verge_v17_cluster_subject' ) ) { $primary = go_verge_v17_cluster_subject( $post_id ); }
	if ( is_array( $primary ) && ! empty( $primary['name'] ) && ! empty( $primary['url'] ) ) {
		$add( $primary['name'], $primary['url'], 1200, 'primary' );
	}

	/* 2. Durable work/game relationship. It stays visible even when an actor or
	 * character is the headline lead, because it is valuable navigation context. */
	$game_id = function_exists( 'go_verge_product_linked_game_id' ) ? go_verge_product_linked_game_id( $post_id ) : absint( get_post_meta( $post_id, 'go_linked_game_id', true ) );
	if ( $game_id && 'games' === get_post_type( $game_id ) && 'publish' === get_post_status( $game_id ) ) {
		$name = get_the_title( $game_id );
		$add( $name, get_permalink( $game_id ), 820 + $evidence_score( array( $name, get_post_field( 'post_name', $game_id ) ) ), 'work' );
	}
	$production = go_verge_v7_post_production( $post_id );
	if ( $production instanceof WP_Post && 'publish' === $production->post_status ) {
		$name = get_the_title( $production );
		$add( $name, get_permalink( $production ), 820 + $evidence_score( array( $name, $production->post_name ) ), 'work' );
	}

	/* 3. People, characters and other curated entities. Direct headline/support
	 * relevance pushes Demet/Engin/Tahir above generic platform/service labels. */
	foreach ( go_verge_v7_post_entity_ids( $post_id ) as $entity_id ) {
		if ( 'go_entity' !== get_post_type( $entity_id ) || 'publish' !== get_post_status( $entity_id ) ) { continue; }
		$name = get_the_title( $entity_id );
		$score = 610 + $evidence_score( array( $name, get_post_field( 'post_name', $entity_id ) ) );
		$add( $name, get_permalink( $entity_id ), $score, 'entity' );
	}

	/* 4. Preserve the useful navigation value of legacy tags instead of hiding
	 * every tag. Only specific, recurring, assigned tags are exposed. Each link
	 * is routed to the canonical Production/Game/Entity/Platform/Service when one
	 * exists; otherwise it uses the clean /assunto/ hub. */
	$tags = wp_get_post_terms( $post_id, 'post_tag' );
	if ( ! is_wp_error( $tags ) ) {
		foreach ( $tags as $tag ) {
			if ( ! ( $tag instanceof WP_Term ) || (int) $tag->count < 2 ) { continue; }
			if ( function_exists( 'go_verge_subject_tag_is_specific' ) && ! go_verge_subject_tag_is_specific( $tag ) ) { continue; }
			if ( function_exists( 'go_verge_v17_cluster_is_derivative' ) && go_verge_v17_cluster_is_derivative( $tag->name ) ) { continue; }

			$label = $tag->name;
			$url   = '';
			if ( function_exists( 'go_verge_v36_topic_destination' ) ) {
				$dest = go_verge_v36_topic_destination( $tag->slug );
				if ( is_array( $dest ) && ! empty( $dest['url'] ) ) {
					$url = $dest['url'];
					if ( ! empty( $dest['name'] ) ) { $label = $dest['name']; }
				}
			}
			if ( ! $url ) {
				$url = function_exists( 'go_verge_v21_topic_hub_url' ) ? go_verge_v21_topic_hub_url( $tag->name ) : get_term_link( $tag );
			}
			if ( is_wp_error( $url ) || ! $url ) { continue; }
			$score = 430 + $evidence_score( array( $tag->name, $tag->slug ) ) + min( 25, (int) $tag->count );
			$add( $label, $url, $score, 'topic' );
		}
	}

	/* 5. Buying guides use the format category as their one editorial category,
	 * so they otherwise lose the subject breadcrumb a normal Celulares/Hardware
	 * story gets for free. Bridge the article back to the matching Technology
	 * desk with one ordinary internal link; no recategorisation, no duplicate
	 * archive and no synthetic entity are created. */
	if ( function_exists( 'go_verge_buying_selection_profile' ) ) {
		$profile = go_verge_buying_selection_profile( get_post( $post_id ) );
		if ( is_array( $profile ) && in_array( 'technology', (array) ( $profile['desks'] ?? array() ), true ) ) {
			$product = sanitize_key( (string) ( $profile['product'] ?? '' ) );
			$subject_map = array(
				'celulares'   => 'celulares',
				'notebooks'   => 'notebooks',
				'tvs'         => 'tvs-e-monitores',
				'monitores'   => 'tvs-e-monitores',
				'hardware'    => 'hardware',
				'perifericos' => 'hardware',
				'audio'       => 'hardware',
				'software'    => 'apps-software',
				'tablets'     => 'tecnologia',
				'dispositivos'=> 'tecnologia',
			);
			$subject_slug = $subject_map[ $product ] ?? '';
			if ( $subject_slug ) {
				$subject_term = get_term_by( 'slug', $subject_slug, 'category' );
				if ( $subject_term instanceof WP_Term ) {
					$link = get_term_link( $subject_term );
					if ( ! is_wp_error( $link ) ) { $add( $subject_term->name, $link, 360, 'context' ); }
				}
			}
		}
	}

	/* 6. Platform/service is useful context, but deliberately loses to specific
	 * works and people when the row reaches its display limit. */
	foreach ( array( 'go_service', 'go_platform' ) as $taxonomy ) {
		$terms = wp_get_post_terms( $post_id, $taxonomy );
		if ( is_wp_error( $terms ) ) { continue; }
		foreach ( $terms as $term ) {
			$link = get_term_link( $term );
			if ( is_wp_error( $link ) ) { continue; }
			$score = 280 + $evidence_score( array( $term->name, $term->slug ) );
			$add( $term->name, $link, $score, 'context' );
		}
	}

	if ( ! $candidates ) { return array(); }
	uasort( $candidates, static function ( $a, $b ) {
		if ( 'primary' === $a['role'] && 'primary' !== $b['role'] ) { return -1; }
		if ( 'primary' === $b['role'] && 'primary' !== $a['role'] ) { return 1; }
		if ( (int) $a['score'] === (int) $b['score'] ) { return strcasecmp( $a['label'], $b['label'] ); }
		return (int) $b['score'] <=> (int) $a['score'];
	} );

	$out = array();
	foreach ( array_slice( array_values( $candidates ), 0, $limit ) as $item ) {
		$out[] = array( 'label' => $item['label'], 'url' => $item['url'], 'role' => $item['role'] );
	}
	return $out;
}

/** Author ProfilePage/Person graph is already owned by editorial-trust-seo.php. */


/** Internal link cleanup: replace known legacy paths in post bodies after save. */
function go_verge_v7_update_internal_legacy_links( $post_id ) {
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) { go_verge_defer_post_save_maintenance( $post_id ); return; }
	$post=get_post($post_id); if(!($post instanceof WP_Post)||'post'!==$post->post_type||''===$post->post_content)return;
	$map=(array)get_option('go_verge_v7_redirects',array()); if(!$map)return;
	$content=$post->post_content;$changed=false;
	foreach($map as $path=>$target){$old=home_url('/'.trim($path,'/').'/');if($old!==$target && false!==strpos($content,$old)){$content=str_replace($old,$target,$content);$changed=true;}}
	if($changed){remove_action('save_post_post','go_verge_v7_update_internal_legacy_links',160);wp_update_post(array('ID'=>$post_id,'post_content'=>$content));add_action('save_post_post','go_verge_v7_update_internal_legacy_links',160);}
}
add_action( 'save_post_post', 'go_verge_v7_update_internal_legacy_links', 160 );

/** Convert discovered internal stream parameters to crawlable pagination URLs. */
function go_verge_v7_clean_stream_parameter_urls() {
	if ( is_admin() || wp_doing_ajax() || ! is_front_page() ) { return; }
	$has_junk = isset($_GET['stream_page']) || isset($_GET['exclude_ids']) || isset($_GET['exclude']); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( ! $has_junk ) { return; }
	$page = isset($_GET['stream_page']) ? max(1,absint(wp_unslash($_GET['stream_page']))) : 1; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	$target = $page > 1 ? home_url( '/page/' . $page . '/' ) : home_url('/');
	wp_safe_redirect($target,301,'Overdrive clean infinite pagination'); exit;
}
add_action('template_redirect','go_verge_v7_clean_stream_parameter_urls',-1);

/** Any old /category/... route for a canonical concept resolves to its one term URL. */
function go_verge_v7_clean_category_base_aliases() {
	if ( is_admin() || wp_doing_ajax() ) { return; }
	$path=trim((string)wp_parse_url(isset($_SERVER['REQUEST_URI'])?wp_unslash($_SERVER['REQUEST_URI']):'',PHP_URL_PATH),'/');
	if ( 0 !== strpos($path,'category/') ) { return; }
	$slug=sanitize_title(basename($path)); if(!in_array($slug,go_verge_v7_canonical_category_slugs(),true))return;
	$target=go_verge_v7_category_url($slug);$current=home_url('/'.$path.'/');
	if($target&&untrailingslashit($target)!==untrailingslashit($current)){wp_safe_redirect($target,301,'Overdrive canonical editorial URL');exit;}
}
add_action('template_redirect','go_verge_v7_clean_category_base_aliases',2);

/** Content type is available as a stable CSS hook for templates/layouts. */
function go_verge_v7_content_type_body_class($classes){if(is_singular('post')){$type=go_verge_v7_post_content_type(get_queried_object_id());if($type)$classes[]='go-content-type-'.sanitize_html_class($type);}return $classes;}
add_filter('body_class','go_verge_v7_content_type_body_class',120);

/** Front-end styles for production/service/platform hubs. */
function go_verge_v7_front_assets() {
	if ( is_post_type_archive( 'productions' ) || is_singular( 'productions' ) || is_tax( array( 'go_service', 'go_platform' ) ) ) {
		$rel = '/assets/css/editorial-architecture-v7-front.min.css';
		wp_enqueue_style( 'go-verge-editorial-v7-front', GO_VERGE_URI . $rel, array(), go_verge_asset_version( $rel ) );
	}
}
add_action( 'wp_enqueue_scripts', 'go_verge_v7_front_assets', 95 );

/** Read-only migration audit screen for editors/SEO. */
function go_verge_v7_register_architecture_tools_page() {
	add_management_page(
		'Arquitetura Overdrive',
		'Arquitetura Overdrive',
		'manage_categories',
		'go-verge-architecture-v7',
		'go_verge_v7_render_architecture_tools_page'
	);
}
add_action( 'admin_menu', 'go_verge_v7_register_architecture_tools_page', 90 );

function go_verge_v7_render_architecture_tools_page() {
	if ( ! current_user_can( 'manage_categories' ) ) { return; }
	$redirects = (array) get_option( 'go_verge_v7_redirects', array() );
	ksort( $redirects, SORT_NATURAL | SORT_FLAG_CASE );
	$done   = get_option( 'go_verge_arch_v7_cleanup_done' ) === GO_VERGE_ARCH_V7_VERSION;
	$cursor = absint( get_option( 'go_verge_arch_v7_cleanup_cursor', 0 ) );
	$preserved = function_exists( 'go_verge_editorial_preservation_enabled' ) && go_verge_editorial_preservation_enabled();
	?>
	<div class="wrap">
		<h1>Arquitetura Overdrive</h1>
		<?php if ( $preserved ) : ?>
		<p>Auditoria somente-leitura do acervo editorial V7. A preservação está ativa: esta versão não executa a migração automática de termos ou matérias. Categorias existentes, vínculos e mapas de redirecionamento são mantidos; os números abaixo mostram o histórico já registrado.</p>
		<?php else : ?>
		<p>Auditoria somente-leitura da migração editorial V7. O processamento ocorre em background, com lock e limite de tempo por lote; os termos antigos permanecem disponíveis para os redirects.</p>
		<?php endif; ?>
		<table class="widefat striped" style="max-width:900px;margin:18px 0 26px"><tbody>
			<tr><th style="width:240px">Versão</th><td><?php echo esc_html( GO_VERGE_ARCH_V7_VERSION ); ?></td></tr>
			<?php $terms_done = get_option( 'go_verge_arch_v7_migration' ) === GO_VERGE_ARCH_V7_VERSION; $term_state = (array) get_option( 'go_verge_arch_v7_terms_state_v3153', array() ); ?>
			<tr><th>Migração de termos</th><td><?php echo $terms_done ? 'Concluída anteriormente' : esc_html( ( $preserved ? 'Não executada nesta versão — ' : 'Em background — ' ) . number_format_i18n( absint( $term_state['processed'] ?? 0 ) ) . ' relações processadas (' . ( 'tag' === ( $term_state['phase'] ?? 'category' ) ? 'tags' : 'categorias' ) . ')' ); ?></td></tr>
			<tr><th>Normalização das matérias</th><td><?php echo $done ? 'Concluída anteriormente' : esc_html( ( $preserved ? 'Preservação ativa — ' : '' ) . number_format_i18n( $cursor ) . ' matérias percorridas anteriormente' ); ?></td></tr>
			<tr><th>Redirects registrados</th><td><?php echo esc_html( number_format_i18n( count( $redirects ) ) ); ?></td></tr>
		</tbody></table>
		<h2>Mapa de URLs legado → canônico</h2>
		<?php if ( ! $redirects ) : ?><p>Não há redirecionamentos históricos registrados neste mapa.</p><?php else : ?>
		<table class="widefat striped"><thead><tr><th>Origem</th><th>Destino 301</th></tr></thead><tbody>
		<?php foreach ( $redirects as $path => $target ) : ?>
			<tr><td><code><?php echo esc_html( '/' . trim( $path, '/' ) . '/' ); ?></code></td><td><a href="<?php echo esc_url( $target ); ?>" target="_blank" rel="noopener noreferrer"><?php echo esc_html( $target ); ?></a></td></tr>
		<?php endforeach; ?>
		</tbody></table>
		<?php endif; ?>
	</div>
	<?php
}

/** When a controlled entity is deliberately published, retire its matching legacy tag. */
function go_verge_v7_promote_legacy_tag_to_entity( $new_status, $old_status, $post ) {
	if ( 'publish' !== $new_status || ! ( $post instanceof WP_Post ) || 'go_entity' !== $post->post_type ) { return; }
	$slug = sanitize_title( $post->post_name ?: $post->post_title );
	$tag  = get_term_by( 'slug', $slug, 'post_tag' );
	if ( ! ( $tag instanceof WP_Term ) ) { return; }
	$posts = get_objects_in_term( (int) $tag->term_id, 'post_tag' );
	if ( is_wp_error( $posts ) ) { $posts = array(); }
	foreach ( array_map( 'absint', (array) $posts ) as $post_id ) {
		if ( 'post' !== get_post_type( $post_id ) ) { continue; }
		$ids = (array) get_post_meta( $post_id, '_go_entity_ids', true );
		$ids[] = (int) $post->ID;
		update_post_meta( $post_id, '_go_entity_ids', array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) ) );
		wp_remove_object_terms( $post_id, array( (int) $tag->term_id ), 'post_tag' );
	}
	$redirects = (array) get_option( 'go_verge_v7_redirects', array() );
	go_verge_v7_remember_redirect( $tag, get_permalink( $post ), $redirects );
	update_option( 'go_verge_v7_redirects', $redirects, false );
}
add_action( 'transition_post_status', 'go_verge_v7_promote_legacy_tag_to_entity', 30, 3 );

/** Creating a Production also consolidates a same-slug legacy tag into the entity. */
function go_verge_v7_promote_legacy_tag_to_production( $post_id, $post, $update ) {
	if ( wp_is_post_revision( $post_id ) || ! ( $post instanceof WP_Post ) || 'productions' !== $post->post_type || 'publish' !== $post->post_status ) { return; }
	$slug = sanitize_title( $post->post_name ?: $post->post_title );
	$tag  = get_term_by( 'slug', $slug, 'post_tag' );
	if ( ! ( $tag instanceof WP_Term ) ) { return; }
	$posts = get_objects_in_term( (int) $tag->term_id, 'post_tag' );
	if ( is_wp_error( $posts ) ) { $posts = array(); }
	foreach ( array_map( 'absint', (array) $posts ) as $story_id ) {
		if ( 'post' !== get_post_type( $story_id ) ) { continue; }
		if ( ! absint( get_post_meta( $story_id, '_go_production_id', true ) ) ) { update_post_meta( $story_id, '_go_production_id', (int) $post_id ); }
		wp_remove_object_terms( $story_id, array( (int) $tag->term_id ), 'post_tag' );
	}
	$redirects = (array) get_option( 'go_verge_v7_redirects', array() );
	go_verge_v7_remember_redirect( $tag, get_permalink( $post_id ), $redirects );
	update_option( 'go_verge_v7_redirects', $redirects, false );
}
add_action( 'save_post_productions', 'go_verge_v7_promote_legacy_tag_to_production', 160, 3 );

/**
 * V42: concise service descriptions used when an editor has not written one.
 * They describe the user's likely intent, not the taxonomy implementation.
 */
function go_verge_v42_service_fallback_description( $slug, $name = '' ) {
	$slug = sanitize_title( (string) $slug );
	$name = trim( wp_strip_all_tags( (string) $name ) );
	$copy = array(
		'netflix'            => 'Estreias, séries, filmes, catálogo e novidades da Netflix.',
		'prime-video'        => 'Estreias, séries, filmes e novidades do Prime Video.',
		'disney-plus'        => 'Estreias, séries, filmes e novidades do Disney+.',
		'max'                => 'Estreias, séries, filmes e novidades da HBO Max.',
		'apple-tv-plus'      => 'Estreias, séries, filmes e novidades do Apple TV+.',
		'crunchyroll'        => 'Animes, estreias, calendário e novidades da Crunchyroll.',
		'globoplay'          => 'Estreias, novelas, séries, filmes e novidades do Globoplay.',
		'steam'              => 'Jogos, lançamentos, ofertas e novidades da Steam.',
		'playstation-plus'   => 'Jogos do catálogo, novidades e mudanças do PlayStation Plus.',
		'playstation-store'  => 'Lançamentos, preços, promoções e novidades da PlayStation Store.',
		'xbox-game-pass'     => 'Jogos do catálogo, novidades e mudanças do Xbox Game Pass.',
		'epic-games-store'   => 'Jogos grátis, lançamentos, ofertas e novidades da Epic Games Store.',
		'geforce-now'        => 'Jogos compatíveis, planos e novidades do GeForce NOW.',
	);
	if ( isset( $copy[ $slug ] ) ) { return $copy[ $slug ]; }
	return $name ? sprintf( __( 'Notícias, lançamentos e novidades de %s.', 'go-verge' ), $name ) : '';
}

/**
 * V42: surface only recurring, specific topics already present in this service
 * archive. No extra discovery query is created: the current page's posts are
 * reused, keeping the masthead cheap and preventing a generic tag cloud.
 *
 * @param WP_Post[] $posts Current main-query posts.
 * @param WP_Term   $service Current service term.
 * @param int       $limit Maximum links.
 * @return array<int,array{label:string,url:string,count:int}>
 */
function go_verge_v42_service_top_topics( $posts, $service, $limit = 5 ) {
	if ( ! ( $service instanceof WP_Term ) || 'go_service' !== $service->taxonomy || ! function_exists( 'go_verge_v7_story_topic_chips' ) ) {
		return array();
	}
	$limit = max( 1, min( 5, absint( $limit ) ) );
	$posts = array_slice( array_values( array_filter( (array) $posts, static function ( $post ) { return $post instanceof WP_Post; } ) ), 0, 20 );
	if ( count( $posts ) < 2 ) { return array(); }

	$service_url = get_term_link( $service );
	$service_url = is_wp_error( $service_url ) ? '' : untrailingslashit( strtolower( (string) $service_url ) );
	$service_key = sanitize_title( remove_accents( $service->name ) );
	$items = array();

	foreach ( $posts as $post ) {
		$seen_in_post = array();
		foreach ( go_verge_v7_story_topic_chips( $post->ID, 5 ) as $chip ) {
			$label = trim( wp_strip_all_tags( (string) ( $chip['label'] ?? '' ) ) );
			$url   = esc_url_raw( (string) ( $chip['url'] ?? '' ) );
			$role  = sanitize_key( (string) ( $chip['role'] ?? 'related' ) );
			if ( ! $label || ! $url || 'context' === $role ) { continue; }

			$url_key   = untrailingslashit( strtolower( $url ) );
			$label_key = sanitize_title( remove_accents( $label ) );
			if ( $url_key === $service_url || $label_key === $service_key || isset( $seen_in_post[ $url_key ] ) ) { continue; }
			$seen_in_post[ $url_key ] = true;

			$weight = 'primary' === $role ? 5 : ( 'work' === $role ? 4 : ( 'entity' === $role ? 3 : 2 ) );
			if ( ! isset( $items[ $url_key ] ) ) {
				$items[ $url_key ] = array( 'label' => $label, 'url' => $url, 'count' => 0, 'weight' => 0 );
			}
			$items[ $url_key ]['count']++;
			$items[ $url_key ]['weight'] += $weight;
		}
	}

	/* A masthead link must represent a real mini-cluster, not one isolated post. */
	$items = array_filter( $items, static function ( $item ) { return (int) $item['count'] >= 2; } );
	if ( ! $items ) { return array(); }

	uasort( $items, static function ( $a, $b ) {
		if ( (int) $a['count'] !== (int) $b['count'] ) { return (int) $b['count'] <=> (int) $a['count']; }
		if ( (int) $a['weight'] !== (int) $b['weight'] ) { return (int) $b['weight'] <=> (int) $a['weight']; }
		return strcasecmp( $a['label'], $b['label'] );
	} );

	$out = array();
	foreach ( array_slice( array_values( $items ), 0, $limit ) as $item ) {
		$out[] = array( 'label' => $item['label'], 'url' => $item['url'], 'count' => (int) $item['count'] );
	}
	return $out;
}
