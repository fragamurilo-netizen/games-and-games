<?php
/**
 * Overdrive V29 — evidence-based entity/topic classification and publishing.
 *
 * Goals:
 * - keep structural concepts (platforms, services and editorial sections) on their
 *   canonical hubs instead of creating competing entity URLs;
 * - classify true entities/topics into a small controlled vocabulary;
 * - avoid publishing duplicate/ambiguous hubs;
 * - publish only high-confidence hubs with enough published coverage;
 * - keep the process incremental, reversible and visible in wp-admin.
 *
 * No advertising code is touched here.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

const GO_VERGE_ENTITY_INTELLIGENCE_VERSION = '2026-08-25-v36';

/** Controlled editorial types. Type archives are intentionally not public. */
function go_verge_v27_entity_type_blueprint() {
	return array(
		'pessoa'           => 'Pessoa',
		'personagem'       => 'Personagem',
		'obra-franquia'    => 'Obra / franquia',
		'empresa-estudio'  => 'Empresa / estúdio',
		'marca-produto'    => 'Marca / produto',
		'evento'           => 'Evento',
		'assunto-conceito' => 'Assunto / conceito',
	);
}

/** Ensure the controlled entity types exist. */
function go_verge_v27_ensure_entity_types() {
	if ( ! taxonomy_exists( 'go_entity_type' ) ) { return; }
	/* This ran seven term lookups (14 queries) on every request, REST beacons and
	 * admin polls included. The vocabulary only changes with a release: verify it
	 * once per blueprint, and again after a type term is deleted. */
	$signature = md5( (string) wp_json_encode( go_verge_v27_entity_type_blueprint() ) );
	if ( get_option( 'go_verge_entity_types_ready' ) === $signature ) { return; }
	$complete = true;
	foreach ( go_verge_v27_entity_type_blueprint() as $slug => $name ) {
		if ( ! term_exists( $slug, 'go_entity_type' ) ) {
			$complete = ! is_wp_error( wp_insert_term( $name, 'go_entity_type', array( 'slug' => $slug ) ) ) && $complete;
		}
	}
	if ( $complete ) { update_option( 'go_verge_entity_types_ready', $signature, true ); }
}
add_action( 'init', 'go_verge_v27_ensure_entity_types', 12 );
add_action( 'delete_go_entity_type', static function () { delete_option( 'go_verge_entity_types_ready' ); } );

/** Normalize a label for deterministic comparisons. */
function go_verge_v27_entity_key( $value ) {
	$value = remove_accents( wp_strip_all_tags( (string) $value ) );
	$value = function_exists( 'mb_strtolower' ) ? mb_strtolower( $value, 'UTF-8' ) : strtolower( $value );
	$value = str_replace( array( '’', '‘', '`' ), "'", $value );
	$value = preg_replace( '/[^a-z0-9]+/u', '-', $value );
	return trim( (string) $value, '-' );
}

/**
 * Canonical structural aliases that should never become a competing entity hub.
 * Values point to durable destination slugs.
 */
function go_verge_v27_platform_aliases() {
	$map = array(
		'pc' => 'pc', 'playstation' => 'playstation', 'xbox' => 'xbox', 'nintendo' => 'nintendo', 'android' => 'android', 'ios' => 'ios',
		'playstation-4' => 'playstation', 'playstation-5' => 'playstation', 'ps4' => 'playstation', 'ps5' => 'playstation', 'ps5-pro' => 'playstation',
		'xbox-one' => 'xbox', 'xbox-series' => 'xbox', 'xbox-series-x' => 'xbox', 'xbox-series-s' => 'xbox', 'xbox-series-x-s' => 'xbox',
		'nintendo-switch' => 'nintendo', 'nintendo-switch-2' => 'nintendo', 'switch' => 'nintendo', 'switch-2' => 'nintendo',
	);
	if ( function_exists( 'go_verge_v24_platform_consolidation_map' ) ) {
		$map = array_merge( $map, go_verge_v24_platform_consolidation_map() );
	}
	return $map;
}

function go_verge_v27_service_aliases() {
	return array(
		'netflix' => 'netflix', 'prime-video' => 'prime-video', 'amazon-prime-video' => 'prime-video',
		'disney-plus' => 'disney-plus',
		'hbo-max' => 'max', 'max' => 'max', 'apple-tv' => 'apple-tv-plus', 'apple-tv-plus' => 'apple-tv-plus',
		'crunchyroll' => 'crunchyroll', 'globoplay' => 'globoplay', 'steam' => 'steam',
		'playstation-plus' => 'playstation-plus', 'ps-plus' => 'playstation-plus', 'playstation-store' => 'playstation-store', 'ps-store' => 'playstation-store',
		'xbox-game-pass' => 'xbox-game-pass', 'game-pass' => 'xbox-game-pass', 'epic-games-store' => 'epic-games-store', 'geforce-now' => 'geforce-now',
	);
}

function go_verge_v27_section_aliases() {
	return array(
		'games' => 'games', 'guias' => 'guias', 'guia' => 'guias', 'reviews' => 'reviews', 'review' => 'reviews',
		'lancamentos' => 'lancamentos', 'especiais' => 'especiais',
		'series' => 'series', 'filmes' => 'filmes', 'cinema' => 'filmes',
		'producoes-turcas' => 'producoes-turcas', 'series-turcas' => 'producoes-turcas', 'novelas-turcas' => 'producoes-turcas',
		'anime' => 'anime-e-manga', 'anime-e-manga' => 'anime-e-manga', 'streaming' => 'streaming',
		'criticas' => 'criticas', 'critica' => 'criticas',
		'hardware' => 'hardware', 'apps-software' => 'apps-software', 'ia' => 'ia', 'celulares' => 'celulares', 'ciencia' => 'ciencia', 'notebooks' => 'notebooks',
		'software-e-ia' => 'tecnologia', /* retired combined desk: consolidate to the pillar, never recreate the duplicate archive */
		'tvs-e-monitores' => 'tvs-e-monitores', 'tutoriais' => 'tutoriais', 'promocoes' => 'promocoes', 'ofertas' => 'promocoes',
		'guias-de-compra' => 'guias-de-compra', 'jogos-gratis' => 'jogos-gratis',
		'codigos-roblox' => 'guias',
	);
}

/** Resolve a section slug to its canonical URL. */
function go_verge_v27_section_url( $slug ) {
	$slug = sanitize_title( $slug );
	if ( function_exists( 'go_verge_v7_category_url' ) ) {
		$url = go_verge_v7_category_url( $slug );
		if ( $url ) { return $url; }
	}
	$term = get_term_by( 'slug', $slug, 'category' );
	if ( $term instanceof WP_Term ) {
		$url = get_term_link( $term );
		if ( ! is_wp_error( $url ) ) { return $url; }
	}
	return '';
}

/**
 * Determine whether an entity should resolve to an already-existing canonical hub.
 *
 * @return array{kind:string,target_id:int,target_slug:string,url:string}|null
 */
function go_verge_v27_entity_canonical_target( $entity_id ) {
	$entity = get_post( $entity_id );
	if ( ! ( $entity instanceof WP_Post ) || 'go_entity' !== $entity->post_type ) { return null; }
	$key = go_verge_v27_entity_key( $entity->post_title );
	if ( '' === $key ) { return null; }

	$platforms = go_verge_v27_platform_aliases();
	if ( isset( $platforms[ $key ] ) ) {
		$term = get_term_by( 'slug', $platforms[ $key ], 'go_platform' );
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) {
				return array( 'kind' => 'platform', 'target_id' => (int) $term->term_id, 'target_slug' => $term->slug, 'url' => $url );
			}
		}
	}

	$services = go_verge_v27_service_aliases();
	if ( isset( $services[ $key ] ) ) {
		$term = get_term_by( 'slug', $services[ $key ], 'go_service' );
		if ( $term instanceof WP_Term ) {
			$url = get_term_link( $term );
			if ( ! is_wp_error( $url ) ) {
				return array( 'kind' => 'service', 'target_id' => (int) $term->term_id, 'target_slug' => $term->slug, 'url' => $url );
			}
		}
	}

	$sections = go_verge_v27_section_aliases();
	if ( isset( $sections[ $key ] ) ) {
		$url = go_verge_v27_section_url( $sections[ $key ] );
		if ( $url ) {
			$term = get_term_by( 'slug', $sections[ $key ], 'category' );
			return array( 'kind' => 'section', 'target_id' => $term instanceof WP_Term ? (int) $term->term_id : 0, 'target_slug' => $sections[ $key ], 'url' => $url );
		}
	}

	/* Reuse first-class catalogue hubs instead of creating a duplicate universe
	 * page, but never guess through a collision. A title can legitimately exist
	 * as both a game and a TV/film production (for example adaptations). */
	$declared_type = sanitize_key( get_post_meta( $entity_id, '_go_entity_intelligence_type', true ) );
	$declared_terms = wp_get_object_terms( $entity_id, 'go_entity_type', array( 'fields' => 'slugs' ) );
	if ( is_wp_error( $declared_terms ) ) { $declared_terms = array(); }
	$is_person_like = in_array( $declared_type, array( 'pessoa', 'personagem' ), true )
		|| array_intersect( array( 'pessoa', 'personagem' ), array_map( 'sanitize_key', (array) $declared_terms ) );

	if ( ! $is_person_like ) {
		$catalog_candidates = array();
		foreach ( array( 'productions' => 'production', 'games' => 'game' ) as $post_type => $kind ) {
			if ( ! post_type_exists( $post_type ) ) { continue; }

			$candidates = array();
			$direct = get_page_by_path( $key, OBJECT, $post_type );
			if ( $direct instanceof WP_Post && 'publish' === $direct->post_status ) { $candidates[ $direct->ID ] = $direct; }

			$search = get_posts( array(
				'post_type'              => $post_type,
				'post_status'            => 'publish',
				's'                      => $entity->post_title,
				'posts_per_page'         => 20,
				'no_found_rows'          => true,
				'ignore_sticky_posts'    => true,
				'update_post_meta_cache' => false,
				'update_post_term_cache' => false,
				'suppress_filters'       => false,
			) );
			foreach ( (array) $search as $candidate ) {
				if ( $candidate instanceof WP_Post && $key === go_verge_v27_entity_key( $candidate->post_title ) ) {
					$candidates[ $candidate->ID ] = $candidate;
				}
			}

			/* Multiple catalogue records with the exact normalized name are an
			 * editorial ambiguity, not an excuse to redirect at random. */
			if ( 1 === count( $candidates ) ) {
				$target = reset( $candidates );
				$catalog_candidates[ $kind ] = $target;
			}
		}

		if ( 1 === count( $catalog_candidates ) ) {
			$kind   = (string) array_key_first( $catalog_candidates );
			$target = $catalog_candidates[ $kind ];
			$url    = get_permalink( $target );
			if ( $url ) {
				return array( 'kind'=>$kind, 'target_id'=>(int)$target->ID, 'target_slug'=>$target->post_name, 'url'=>$url );
			}
		}

		if ( isset( $catalog_candidates['production'], $catalog_candidates['game'] ) ) {
			$production = $catalog_candidates['production'];
			$game       = $catalog_candidates['game'];
			$scores     = array( 'production'=>0, 'game'=>0 );
			$sets       = function_exists( 'go_verge_v27_entity_story_sets' ) ? go_verge_v27_entity_story_sets() : array();
			$stories    = array_slice( array_map( 'absint', (array) ( $sets[ $entity_id ] ?? array() ) ), 0, 120 );

			foreach ( $stories as $story_id ) {
				if ( absint( get_post_meta( $story_id, '_go_production_id', true ) ) === (int) $production->ID ) { $scores['production'] += 4; }
				$linked_game = 0;
				foreach ( array( 'go_linked_game_id', '_go_linked_game_id', 'go_review_game_id', '_go_review_game_id' ) as $key_name ) {
					$linked_game = absint( get_post_meta( $story_id, $key_name, true ) );
					if ( $linked_game ) { break; }
				}
				if ( $linked_game === (int) $game->ID ) { $scores['game'] += 4; }

				if ( has_category( array( 'games', 'guias', 'reviews', 'lancamentos' ), $story_id ) ) { $scores['game'] += 1; }
				if ( has_category( array( 'series', 'filmes', 'streaming', 'producoes-turcas', 'anime-e-manga', 'criticas' ), $story_id ) ) { $scores['production'] += 1; }
			}

			$winner = '';
			if ( $scores['production'] >= 2 && $scores['production'] > $scores['game'] ) { $winner = 'production'; }
			if ( $scores['game'] >= 2 && $scores['game'] > $scores['production'] ) { $winner = 'game'; }
			if ( $winner ) {
				$target = $catalog_candidates[ $winner ];
				$url = get_permalink( $target );
				if ( $url ) {
					return array( 'kind'=>$winner, 'target_id'=>(int)$target->ID, 'target_slug'=>$target->post_name, 'url'=>$url );
				}
			}
		}
	}

	return null;
}

/** Build entity => published story IDs from one aggregate database pass. */
function go_verge_v27_entity_story_sets( $force = false ) {
	$cache_key = 'go_entity_story_sets_v27';
	if ( ! $force ) {
		$cached = get_transient( $cache_key );
		if ( is_array( $cached ) ) { return $cached; }
	}
	global $wpdb;
	$rows = $wpdb->get_results( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		$wpdb->prepare(
			"SELECT pm.post_id, pm.meta_value
			 FROM {$wpdb->postmeta} pm
			 INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
			 WHERE pm.meta_key = %s AND p.post_type = %s AND p.post_status = %s",
			'_go_entity_ids', 'post', 'publish'
		), ARRAY_A
	);
	$map = array();
	foreach ( (array) $rows as $row ) {
		$story_id = absint( $row['post_id'] ?? 0 );
		$ids = maybe_unserialize( $row['meta_value'] ?? '' );
		if ( ! $story_id || ! is_array( $ids ) ) { continue; }
		foreach ( array_values( array_unique( array_filter( array_map( 'absint', $ids ) ) ) ) as $entity_id ) {
			if ( ! isset( $map[ $entity_id ] ) ) { $map[ $entity_id ] = array(); }
			$map[ $entity_id ][] = $story_id;
		}
	}
	foreach ( $map as $entity_id => $ids ) {
		$map[ $entity_id ] = array_values( array_unique( array_map( 'absint', $ids ) ) );
	}
	set_transient( $cache_key, $map, 10 * MINUTE_IN_SECONDS );
	return $map;
}

function go_verge_v27_flush_story_sets( $post_id = 0 ) {
	$post_id = absint( $post_id );
	if ( $post_id && 'post' !== get_post_type( $post_id ) ) { return; }
	/* A 60-item intelligence batch may update many relationships. Keep the
	 * request-local snapshot stable and invalidate once at the end instead of
	 * rebuilding the full 1k+ entity map after every row. */
	if ( ! empty( $GLOBALS['go_verge_v27_intelligence_batch_running'] ) ) {
		$GLOBALS['go_verge_v27_intelligence_batch_dirty'] = true;
		return;
	}
	delete_transient( 'go_entity_story_sets_v27' );
	delete_transient( 'go_entity_duplicate_groups_v27' );
}
add_action( 'save_post_post', 'go_verge_v27_flush_story_sets', 1001 );
add_action( 'transition_post_status', static function( $new, $old, $post ) {
	if ( $post instanceof WP_Post && 'post' === $post->post_type && $new !== $old ) {
		go_verge_v27_flush_story_sets( $post->ID );
	}
}, 1001, 3 );

/** Count overlap using the smaller set as denominator; useful for imported duplicate tags. */
function go_verge_v27_story_overlap( $a, $b ) {
	$a = array_values( array_unique( array_filter( array_map( 'absint', (array) $a ) ) ) );
	$b = array_values( array_unique( array_filter( array_map( 'absint', (array) $b ) ) ) );
	if ( ! $a || ! $b ) { return ( ! $a && ! $b ) ? 1.0 : 0.0; }
	$intersection = count( array_intersect( $a, $b ) );
	return $intersection / max( 1, min( count( $a ), count( $b ) ) );
}

/** Build exact-title duplicate groups and choose a safe canonical candidate. */
function go_verge_v27_duplicate_groups( $force = false ) {
	$cache_key = 'go_entity_duplicate_groups_v27';
	if ( ! $force ) {
		$cached = get_transient( $cache_key );
		if ( is_array( $cached ) ) { return $cached; }
	}
	global $wpdb;
	$rows = $wpdb->get_results( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		$wpdb->prepare(
			"SELECT ID, post_title, post_status FROM {$wpdb->posts} WHERE post_type=%s AND post_status<>%s ORDER BY ID ASC",
			'go_entity', 'trash'
		), ARRAY_A
	);
	$sets = go_verge_v27_entity_story_sets();
	$by_key = array();
	foreach ( (array) $rows as $row ) {
		$key = go_verge_v27_entity_key( $row['post_title'] ?? '' );
		$id  = absint( $row['ID'] ?? 0 );
		if ( '' === $key || ! $id ) { continue; }
		$by_key[ $key ][] = array(
			'id' => $id,
			'status' => sanitize_key( $row['post_status'] ?? 'draft' ),
			'count' => isset( $sets[ $id ] ) ? count( $sets[ $id ] ) : 0,
		);
	}
	$groups = array();
	foreach ( $by_key as $key => $members ) {
		if ( count( $members ) < 2 ) { continue; }
		usort( $members, static function( $a, $b ) {
			$a_pub = 'publish' === $a['status'] ? 1 : 0;
			$b_pub = 'publish' === $b['status'] ? 1 : 0;
			if ( $a_pub !== $b_pub ) { return $b_pub <=> $a_pub; }
			if ( $a['count'] !== $b['count'] ) { return $b['count'] <=> $a['count']; }
			return $a['id'] <=> $b['id'];
		} );
		$winner = (int) $members[0]['id'];
		$safe = true;
		foreach ( array_slice( $members, 1 ) as $member ) {
			$a = $sets[ $winner ] ?? array();
			$b = $sets[ (int) $member['id'] ] ?? array();
			/* Empty imports are safe shadows. Non-empty sets require strong containment. */
			if ( $a && $b && go_verge_v27_story_overlap( $a, $b ) < 0.80 ) {
				$safe = false;
				break;
			}
		}
		$groups[ $key ] = array( 'winner' => $winner, 'members' => array_map( 'intval', wp_list_pluck( $members, 'id' ) ), 'safe' => $safe );
	}
	set_transient( $cache_key, $groups, 10 * MINUTE_IN_SECONDS );
	return $groups;
}

/** Curated high-confidence company/studio names found in the editorial universe. */
function go_verge_v27_company_keys() {
	$names = array(
		'Sony','Microsoft','Ubisoft','Rockstar Games','Capcom','Konami','Bandai Namco','Electronic Arts','Square Enix','Take-Two','Take Two','Pocketpair','Rebel Wolves',
		'Xbox Game Studios','FromSoftware','miHoYo','Warner Bros. Games','Warner Bros Games','Valve','Epic Games','CD Projekt Red','Atlus','Sega','Bethesda','BioWare',
		'Blizzard','Activision','Naughty Dog','Insomniac Games','Kojima Productions','Universal Pictures','Sony Pictures','Warner Bros. Discovery','Paramount Pictures',
		'20th Century Studios','Lionsgate','A24','TT Games','Undercoders','Disney','The Walt Disney Company','Netflix','Amazon MGM Studios','HBO','HBO Max',
	);
	return array_fill_keys( array_map( 'go_verge_v27_entity_key', $names ), true );
}

function go_verge_v27_topic_keys() {
	$names = array(
		'RPG','RPG de ação','Aventura','ação','mundo aberto','terror','suspense','survival horror','true crime','ficção científica','metroidvania','soulslike',
		'cooperativo online','multiplayer online','single player','um jogador','TV gamer','Smart TV','novelas verticais','microdramas','romance','comédia','drama',
		'troféus','final explicado','animes','mangá',
	);
	return array_fill_keys( array_map( 'go_verge_v27_entity_key', $names ), true );
}

function go_verge_v27_known_work_keys() {
	$names = array(
		'Meu Nome é Farah','Adım Farah','Fatmagül','A Sonhadora','The Last of Us','Assassin’s Creed','Assassin\'s Creed','Call of Duty','X-Men','A Odisseia',
		'Fortnite','Será Isso Amor','Star Wars','Game of Thrones','Iludida','Amor de Aluguel','Homem-Aranha','Outer Banks','Oppenheimer','Metal Gear Solid',
		'Metal Gear Solid 4','GTA 6','Palworld','Overwatch','Sword Art Online','The Legend of Zelda','Stardew Valley','Until Dawn','Shadow of the Colossus','Spider-Man',
		'Os Simpsons','The Simpsons','A Onda','A Última Casa',
	);
	return array_fill_keys( array_map( 'go_verge_v27_entity_key', $names ), true );
}

/** Real people are deliberately separated from fictional characters. */
function go_verge_v29_known_person_keys() {
	$names = array(
		'Engin Akyürek','Demet Özdemir','Beren Saat','Can Yaman','Hande Erçel','Cansu Dere','Christopher Nolan','Tom Holland','Matt Damon','Özge Özpirinçci','Sadie Sink','Valerie Domínguez','Aaron Pierre',
	);
	return array_fill_keys( array_map( 'go_verge_v27_entity_key', $names ), true );
}

function go_verge_v29_known_character_keys() {
	$names = array(
		'Tahir Lekesiz','Edward Kenway','Rhaenyra Targaryen','Kerimşah','Farah','Tahir','Orhan Koşaner','Homer Simpson','Maggie Simpson','Bart Simpson','Lisa Simpson','Marge Simpson',
	);
	return array_fill_keys( array_map( 'go_verge_v27_entity_key', $names ), true );
}

/** Return a deliberate editor-assigned type, excluding the engine's own type. */
function go_verge_v29_manual_entity_type( $entity_id ) {
	if ( ! taxonomy_exists( 'go_entity_type' ) ) { return ''; }
	$terms = wp_get_object_terms( absint( $entity_id ), 'go_entity_type', array( 'fields' => 'all' ) );
	if ( is_wp_error( $terms ) || ! $terms ) { return ''; }
	$auto = absint( get_post_meta( absint( $entity_id ), '_go_entity_auto_type_term_id', true ) );
	foreach ( $terms as $term ) {
		if ( ! ( $term instanceof WP_Term ) || ( $auto && (int) $term->term_id === $auto ) ) { continue; }
		$slug = sanitize_key( $term->slug );
		if ( isset( go_verge_v27_entity_type_blueprint()[ $slug ] ) ) { return $slug; }
		/* The old combined type is intentionally not treated as authoritative: it
		 * cannot tell a real person from a fictional character. */
	}
	return '';
}

/**
 * Read the stories that actually use an entity and collect contextual evidence.
 * This is intentionally conservative: a word in body copy does not decide a type.
 * Titles/excerpts and explicit linked Game/Production relationships carry the weight.
 */
function go_verge_v29_entity_context_evidence( $entity_id ) {
	$entity_id = absint( $entity_id );
	$entity = get_post( $entity_id );
	$key = $entity instanceof WP_Post ? go_verge_v27_entity_key( $entity->post_title ) : '';
	$sets = go_verge_v27_entity_story_sets();
	$story_ids = array_slice( array_values( array_unique( array_map( 'absint', $sets[ $entity_id ] ?? array() ) ) ), 0, 40 );
	$out = array(
		'work' => 0, 'person' => 0, 'character' => 0, 'company' => 0, 'topic' => 0,
		'exact_work_link' => 0, 'stories' => count( $story_ids ), 'notes' => array(),
	);
	if ( ! $story_ids || ! $key ) { return $out; }

	$work_words = '/\\b(?:s[eé]rie|filme|novela|anime|jogo|game|franquia|temporada|epis[oó]dio|estreia|remake|sequ[eê]ncia|spin[- ]?off)\\b/ui';
	$person_words = '/\\b(?:ator|atriz|diretor|diretora|cineasta|roteirista|showrunner|criador|criadora|produtor|produtora|comediante|cantor|cantora|astro|estrela)\\b/ui';
	$character_words = '/\\b(?:personagem|protagonista|antagonista|vil[aã]o|vil[aã]|her[oó]i|hero[ií]na|interpretad[oa] por|papel de)\\b/ui';
	$company_words = '/\\b(?:empresa|est[uú]dio|publisher|desenvolvedora|desenvolvedor|produtora|distribuidora)\\b/ui';

	foreach ( $story_ids as $story_id ) {
		$story = get_post( $story_id );
		if ( ! ( $story instanceof WP_Post ) || 'publish' !== $story->post_status ) { continue; }
		$linked_game = absint( get_post_meta( $story_id, 'go_linked_game_id', true ) );
		$production = absint( get_post_meta( $story_id, '_go_production_id', true ) );
		foreach ( array( $linked_game, $production ) as $linked_id ) {
			if ( $linked_id && $key === go_verge_v27_entity_key( get_the_title( $linked_id ) ) ) {
				$out['exact_work_link'] += 5;
				$out['work'] += 8;
			}
		}

		$title = (string) get_the_title( $story_id );
		$excerpt = (string) ( $story->post_excerpt ?: wp_trim_words( wp_strip_all_tags( $story->post_content ), 42, '' ) );
		$title_key = go_verge_v27_entity_key( $title );
		$mentions_in_title = false !== strpos( '-' . $title_key . '-', '-' . $key . '-' );
		if ( ! $mentions_in_title ) { continue; }

		if ( preg_match( $work_words, $title ) ) { $out['work'] += 4; }
		if ( preg_match( $person_words, $title ) ) { $out['person'] += 5; }
		if ( preg_match( $character_words, $title ) ) { $out['character'] += 5; }
		if ( preg_match( $company_words, $title ) ) { $out['company'] += 4; }
		if ( preg_match( $work_words, $excerpt ) ) { $out['work'] += 1; }
		if ( preg_match( $person_words, $excerpt ) ) { $out['person'] += 1; }
		if ( preg_match( $character_words, $excerpt ) ) { $out['character'] += 1; }
		if ( preg_match( $company_words, $excerpt ) ) { $out['company'] += 1; }
	}
	return $out;
}

/**
 * Evidence-based classifier. It never decides "person" from capitalization alone.
 *
 * @return array{type:string,confidence:float,reason:string,source:string}
 */
function go_verge_v27_classify_entity_title( $title, $entity_id = 0 ) {
	$key = go_verge_v27_entity_key( $title );
	if ( '' === $key ) { return array( 'type' => '', 'confidence' => 0.0, 'reason' => 'Título vazio.', 'source' => 'empty' ); }

	$manual = $entity_id ? go_verge_v29_manual_entity_type( $entity_id ) : '';
	if ( $manual ) {
		return array( 'type' => $manual, 'confidence' => 1.0, 'reason' => 'Tipo confirmado manualmente no cadastro da entidade.', 'source' => 'manual' );
	}
	$cluster_type = $entity_id ? sanitize_key( (string) get_post_meta( $entity_id, '_go_entity_cluster_type', true ) ) : '';
	if ( $cluster_type && isset( go_verge_v27_entity_type_blueprint()[ $cluster_type ] ) ) {
		return array( 'type' => $cluster_type, 'confidence' => 0.99, 'reason' => 'Assunto recorrente qualificado automaticamente por cobertura editorial.', 'source' => 'cluster' );
	}
	if ( isset( go_verge_v27_company_keys()[ $key ] ) || preg_match( '/(?:^|-)(?:games|studios?|interactive|pictures|entertainment|software|technologies|media)$/', $key ) ) {
		return array( 'type' => 'empresa-estudio', 'confidence' => 0.98, 'reason' => 'Nome/sufixo reconhecido como empresa ou estúdio.', 'source' => 'catalog' );
	}
	if ( preg_match( '/(?:gamescom|summer-game-fest|game-awards|state-of-play|nintendo-direct|xbox-games-showcase|xbox-partner-preview|showcase|comic-con|cinemacon|d23|tudum)/', $key ) ) {
		return array( 'type' => 'evento', 'confidence' => 0.96, 'reason' => 'Padrão reconhecido de evento editorial.', 'source' => 'catalog' );
	}
	if ( isset( go_verge_v27_known_work_keys()[ $key ] ) ) {
		return array( 'type' => 'obra-franquia', 'confidence' => 0.99, 'reason' => 'Obra/franquia reconhecida no catálogo editorial.', 'source' => 'catalog' );
	}
	if ( isset( go_verge_v29_known_person_keys()[ $key ] ) ) {
		return array( 'type' => 'pessoa', 'confidence' => 0.99, 'reason' => 'Pessoa reconhecida no catálogo editorial.', 'source' => 'catalog' );
	}
	if ( isset( go_verge_v29_known_character_keys()[ $key ] ) ) {
		return array( 'type' => 'personagem', 'confidence' => 0.99, 'reason' => 'Personagem reconhecido no catálogo editorial.', 'source' => 'catalog' );
	}
	if ( isset( go_verge_v27_topic_keys()[ $key ] ) ) {
		return array( 'type' => 'assunto-conceito', 'confidence' => 0.97, 'reason' => 'Termo reconhecido como assunto/conceito recorrente.', 'source' => 'catalog' );
	}

	$evidence = $entity_id ? go_verge_v29_entity_context_evidence( $entity_id ) : array();
	if ( ! empty( $evidence['exact_work_link'] ) ) {
		return array( 'type' => 'obra-franquia', 'confidence' => 0.995, 'reason' => 'As matérias vinculadas apontam explicitamente para Game/Produção com o mesmo nome.', 'source' => 'context-exact' );
	}
	$scores = array(
		'obra-franquia'   => absint( $evidence['work'] ?? 0 ),
		'pessoa'          => absint( $evidence['person'] ?? 0 ),
		'personagem'      => absint( $evidence['character'] ?? 0 ),
		'empresa-estudio' => absint( $evidence['company'] ?? 0 ),
	);
	arsort( $scores );
	$types = array_keys( $scores );
	$top_type = $types[0] ?? '';
	$top_score = $top_type ? (int) $scores[ $top_type ] : 0;
	$second_score = isset( $types[1] ) ? (int) $scores[ $types[1] ] : 0;
	if ( $top_score >= 8 && ( $top_score - $second_score ) >= 4 ) {
		$confidence = min( 0.97, 0.88 + ( ( $top_score - $second_score ) * 0.01 ) );
		return array( 'type' => $top_type, 'confidence' => $confidence, 'reason' => 'Classificação baseada no contexto das matérias vinculadas, não apenas no formato do nome.', 'source' => 'context' );
	}

	if ( preg_match( '/(?:^|-)(?:temporada|episodios?|final-explicado|codigos?|trofeus?)(?:-|$)/', $key ) ) {
		return array( 'type' => 'assunto-conceito', 'confidence' => 0.86, 'reason' => 'Padrão editorial/temático, não uma entidade nominal.', 'source' => 'heuristic' );
	}

	$raw = trim( wp_strip_all_tags( (string) $title ) );
	$lower = function_exists( 'mb_strtolower' ) ? mb_strtolower( $raw, 'UTF-8' ) : strtolower( $raw );
	/* Titles beginning with an article are much more often works than people.
	 * Keep below auto-publish confidence unless article context confirms it. */
	if ( preg_match( '/^(?:a|o|as|os|um|uma|the|a|an|la|las|el|los)\\s+/ui', $raw ) ) {
		return array( 'type' => 'obra-franquia', 'confidence' => 0.84, 'reason' => 'Título com artigo favorece obra/franquia; aguarda confirmação contextual.', 'source' => 'heuristic' );
	}
	if ( preg_match( '/\\d/u', $raw ) || preg_match( '/[:–—-]/u', $raw ) || preg_match( '/\\b(?:de|do|da|dos|das|em|the|of|and|para|com|é)\\b/u', $lower ) ) {
		return array( 'type' => 'obra-franquia', 'confidence' => 0.80, 'reason' => 'Formato do título favorece obra/franquia, mas não é evidência suficiente para publicação automática.', 'source' => 'heuristic' );
	}

	/* A capitalized 2–4 word label is NOT sufficient evidence of a person. That
	 * previous shortcut was the source of series/films such as "A Onda" being
	 * misclassified. Leave it unresolved unless story context or an editor says. */
	$tokens = preg_split( '/\\s+/u', $raw, -1, PREG_SPLIT_NO_EMPTY );
	if ( count( $tokens ) >= 2 && count( $tokens ) <= 4 ) {
		return array( 'type' => '', 'confidence' => 0.58, 'reason' => 'Nome próprio possível, mas sem evidência suficiente para distinguir pessoa, personagem ou obra.', 'source' => 'ambiguous-name' );
	}
	return array( 'type' => '', 'confidence' => 0.45, 'reason' => 'Tipo ambíguo; requer revisão editorial.', 'source' => 'ambiguous' );
}

/** Minimum published coverage before an auto-publication recommendation. */
function go_verge_v27_type_threshold( $type ) {
	switch ( $type ) {
		case 'assunto-conceito':
		case 'marca-produto':
		case 'pessoa':
		case 'personagem':
		case 'obra-franquia':
		case 'empresa-estudio':
		case 'evento':
		default: return 6;
	}
}

/** Assign one controlled type term, replacing prior automatic suggestions only. */
function go_verge_v27_assign_entity_type( $entity_id, $type ) {
	if ( ! isset( go_verge_v27_entity_type_blueprint()[ $type ] ) || ! taxonomy_exists( 'go_entity_type' ) ) { return; }
	$term = get_term_by( 'slug', $type, 'go_entity_type' );
	if ( ! ( $term instanceof WP_Term ) ) { return; }
	$current = wp_get_object_terms( $entity_id, 'go_entity_type', array( 'fields' => 'ids' ) );
	if ( is_wp_error( $current ) ) { $current = array(); }
	/* Respect a deliberate manual type unless it was previously set by this engine. */
	$auto = absint( get_post_meta( $entity_id, '_go_entity_auto_type_term_id', true ) );
	if ( $current && ( ! $auto || ! in_array( $auto, array_map( 'absint', $current ), true ) ) ) { return; }
	wp_set_object_terms( $entity_id, array( (int) $term->term_id ), 'go_entity_type', false );
	update_post_meta( $entity_id, '_go_entity_auto_type_term_id', (int) $term->term_id );
}

/** Replace one entity relationship with a canonical structural relationship when safe. */
function go_verge_v27_migrate_entity_relationships_to_target( $entity_id, $target ) {
	$sets = go_verge_v27_entity_story_sets();
	$stories = $sets[ $entity_id ] ?? array();
	if ( ! $stories || empty( $target['kind'] ) ) { return; }
	foreach ( array_map( 'absint', $stories ) as $story_id ) {
		if ( 'post' !== get_post_type( $story_id ) ) { continue; }
		$safe_remove = false;
		switch ( $target['kind'] ) {
			case 'platform':
				wp_set_object_terms( $story_id, array( absint( $target['target_id'] ) ), 'go_platform', true );
				$safe_remove = true;
				break;
			case 'service':
				wp_set_object_terms( $story_id, array( absint( $target['target_id'] ) ), 'go_service', true );
				$safe_remove = true;
				break;
			case 'section':
				if ( ! empty( $target['target_id'] ) ) {
					wp_set_object_terms( $story_id, array( absint( $target['target_id'] ) ), 'category', true );
					$safe_remove = true;
				}
				break;
			case 'game':
				$current = absint( get_post_meta( $story_id, 'go_linked_game_id', true ) );
				if ( ! $current || $current === absint( $target['target_id'] ) ) {
					update_post_meta( $story_id, 'go_linked_game_id', absint( $target['target_id'] ) );
					$safe_remove = true;
				}
				break;
			case 'production':
				$current = absint( get_post_meta( $story_id, '_go_production_id', true ) );
				if ( ! $current || $current === absint( $target['target_id'] ) ) {
					update_post_meta( $story_id, '_go_production_id', absint( $target['target_id'] ) );
					$safe_remove = true;
				}
				break;
		}
		if ( $safe_remove ) {
			$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) get_post_meta( $story_id, '_go_entity_ids', true ) ) ) ) );
			$ids = array_values( array_diff( $ids, array( absint( $entity_id ) ) ) );
			update_post_meta( $story_id, '_go_entity_ids', $ids );

			/* Rewrite legacy subject selectors as well. Merely moving the structural
			 * relationship is not enough: an old go_primary_subject_ref can still
			 * print a green metadata link to the retired entity URL. */
			$replacement_ref = '';
			if ( 'production' === $target['kind'] ) {
				$replacement_ref = 'productions:' . absint( $target['target_id'] );
			} elseif ( 'game' === $target['kind'] ) {
				$replacement_ref = 'games:' . absint( $target['target_id'] );
			}
			if ( $replacement_ref ) {
				$legacy_ref = 'go_entity:' . absint( $entity_id );
				foreach ( array( 'go_primary_subject_ref', 'go_technical_subject_ref', '_go_review_subject_reference', 'go_review_subject_reference', '_go_review_sheet_subject_reference' ) as $ref_key ) {
					if ( $legacy_ref === trim( (string) get_post_meta( $story_id, $ref_key, true ) ) ) {
						update_post_meta( $story_id, $ref_key, $replacement_ref );
					}
				}
			}
		}
	}
	go_verge_v27_flush_story_sets();
	if ( function_exists( 'go_verge_v25_flush_entity_published_counts' ) ) { go_verge_v25_flush_entity_published_counts(); }
}

/** Safely merge an imported exact-title duplicate into its winner. */
function go_verge_v27_merge_duplicate( $loser_id, $winner_id ) {
	$loser_id = absint( $loser_id ); $winner_id = absint( $winner_id );
	if ( ! $loser_id || ! $winner_id || $loser_id === $winner_id ) { return false; }
	if ( 'go_entity' !== get_post_type( $loser_id ) || 'go_entity' !== get_post_type( $winner_id ) ) { return false; }
	$sets = go_verge_v27_entity_story_sets();
	foreach ( $sets[ $loser_id ] ?? array() as $story_id ) {
		$ids = array_values( array_unique( array_filter( array_map( 'absint', (array) get_post_meta( $story_id, '_go_entity_ids', true ) ) ) ) );
		$ids = array_values( array_diff( $ids, array( $loser_id ) ) );
		$ids[] = $winner_id;
		update_post_meta( $story_id, '_go_entity_ids', array_values( array_unique( $ids ) ) );
	}
	/* Preserve useful editorial assets on the winner. */
	if ( ! has_post_thumbnail( $winner_id ) && has_post_thumbnail( $loser_id ) ) { set_post_thumbnail( $winner_id, get_post_thumbnail_id( $loser_id ) ); }
	$winner = get_post( $winner_id ); $loser = get_post( $loser_id );
	if ( $winner instanceof WP_Post && $loser instanceof WP_Post ) {
		$update = array( 'ID' => $winner_id );
		$changed = false;
		if ( '' === trim( (string) $winner->post_excerpt ) && '' !== trim( (string) $loser->post_excerpt ) ) { $update['post_excerpt'] = $loser->post_excerpt; $changed = true; }
		if ( '' === trim( (string) $winner->post_content ) && '' !== trim( (string) $loser->post_content ) ) { $update['post_content'] = $loser->post_content; $changed = true; }
		if ( $changed ) { wp_update_post( wp_slash( $update ) ); }
	}
	update_post_meta( $loser_id, '_go_entity_duplicate_of', $winner_id );
	update_post_meta( $loser_id, '_go_entity_intelligence_status', 'duplicate' );
	update_post_meta( $loser_id, '_go_entity_intelligence_reason', 'Duplicata exata consolidada com segurança no hub canônico.' );
	go_verge_v27_flush_story_sets();
	if ( function_exists( 'go_verge_v25_flush_entity_published_counts' ) ) { go_verge_v25_flush_entity_published_counts(); }
	return true;
}

/** Analyze and optionally publish one entity. */
function go_verge_v27_analyze_entity( $entity_id, $allow_publish = false ) {
	$entity_id = absint( $entity_id );
	$post = get_post( $entity_id );
	if ( ! ( $post instanceof WP_Post ) || 'go_entity' !== $post->post_type || 'trash' === $post->post_status ) { return array(); }

	$target = go_verge_v27_entity_canonical_target( $entity_id );
	if ( $target ) {
		update_post_meta( $entity_id, '_go_entity_intelligence_status', 'canonical' );
		update_post_meta( $entity_id, '_go_entity_intelligence_score', 0 );
		update_post_meta( $entity_id, '_go_entity_intelligence_reason', sprintf( 'Usar hub canônico de %s; não criar URL concorrente.', $target['kind'] ) );
		update_post_meta( $entity_id, '_go_entity_canonical_url', esc_url_raw( $target['url'] ) );
		update_post_meta( $entity_id, '_go_entity_intelligence_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION );
		go_verge_v27_migrate_entity_relationships_to_target( $entity_id, $target );
		return array( 'status' => 'canonical', 'score' => 0, 'type' => '', 'reason' => 'Hub estrutural canônico.', 'target' => $target );
	}

	$groups = go_verge_v27_duplicate_groups();
	$key = go_verge_v27_entity_key( $post->post_title );
	if ( isset( $groups[ $key ] ) && count( $groups[ $key ]['members'] ) > 1 ) {
		$group = $groups[ $key ];
		$winner = absint( $group['winner'] );
		if ( ! empty( $group['safe'] ) && $entity_id !== $winner ) {
			go_verge_v27_merge_duplicate( $entity_id, $winner );
			update_post_meta( $entity_id, '_go_entity_intelligence_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION );
			return array( 'status' => 'duplicate', 'score' => 0, 'type' => '', 'reason' => 'Duplicata exata consolidada.', 'winner' => $winner );
		}
		if ( empty( $group['safe'] ) ) {
			update_post_meta( $entity_id, '_go_entity_intelligence_status', 'review' );
			update_post_meta( $entity_id, '_go_entity_intelligence_score', 20 );
			update_post_meta( $entity_id, '_go_entity_intelligence_reason', 'Mesmo título aparece em grupos de matérias pouco sobrepostos; revisar antes de consolidar/publicar.' );
			update_post_meta( $entity_id, '_go_entity_intelligence_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION );
			return array( 'status' => 'review', 'score' => 20, 'type' => '', 'reason' => 'Duplicata ambígua.' );
		}
	}

	$classification = go_verge_v27_classify_entity_title( $post->post_title, $entity_id );
	$type = sanitize_key( $classification['type'] ?? '' );
	$confidence = (float) ( $classification['confidence'] ?? 0 );
	$source = sanitize_key( $classification['source'] ?? '' );
	$sets = go_verge_v27_entity_story_sets();
	$count = isset( $sets[ $entity_id ] ) ? count( $sets[ $entity_id ] ) : 0;
	$threshold = go_verge_v27_type_threshold( $type );

	if ( $type && $confidence >= 0.70 ) { go_verge_v27_assign_entity_type( $entity_id, $type ); }

	$score = min( 50, $count * ( 'assunto-conceito' === $type ? 4 : 6 ) );
	$score += (int) round( min( 25, $confidence * 25 ) );
	if ( strlen( trim( $post->post_title ) ) >= 3 && strlen( trim( $post->post_title ) ) <= 90 ) { $score += 5; }
	if ( has_post_thumbnail( $entity_id ) ) { $score += 8; }
	if ( '' !== trim( (string) $post->post_excerpt ) || '' !== trim( wp_strip_all_tags( (string) $post->post_content ) ) ) { $score += 7; }
	$score = min( 100, max( 0, $score ) );

	if ( ! $type || $confidence < 0.70 ) {
		$status = 'review';
		$reason = 'Tipo ambíguo; revisar antes de publicar. ' . ( $classification['reason'] ?? '' );
	} elseif ( $confidence < 0.90 ) {
		/* Heuristics are useful for categorization, not strong enough to create an
		 * indexable hub automatically. This prevents titles such as an unknown
		 * game with two capitalized words from being mistaken for a person. */
		$status = 'review';
		$reason = sprintf( 'Tipo sugerido (%s), mas a confiança de %.0f%% exige revisão humana antes de publicar.', $type, $confidence * 100 );
	} elseif ( $count < $threshold ) {
		$status = 'hold';
		$reason = sprintf( 'Aguardar mais cobertura: %d de %d matérias publicadas necessárias para este tipo.', $count, $threshold );
	} else {
		$status = 'ready';
		$reason = sprintf( 'Cobertura suficiente (%d matérias), classificação com confiança de %.0f%% e sem conflito canônico/duplicado.', $count, $confidence * 100 );
	}

	if ( 'ready' === $status && 'publish' === $post->post_status ) {
		$status = 'published';
		$reason = 'Hub já publicado e aprovado pelos critérios atuais de cobertura, classificação e canonicalização.';
	}

	update_post_meta( $entity_id, '_go_entity_intelligence_status', $status );
	update_post_meta( $entity_id, '_go_entity_intelligence_score', $score );
	update_post_meta( $entity_id, '_go_entity_intelligence_reason', $reason );
	update_post_meta( $entity_id, '_go_entity_intelligence_confidence', round( $confidence, 3 ) );
	update_post_meta( $entity_id, '_go_entity_intelligence_type', $type );
	update_post_meta( $entity_id, '_go_entity_intelligence_source', $source );
	update_post_meta( $entity_id, '_go_entity_intelligence_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION );
	delete_post_meta( $entity_id, '_go_entity_canonical_url' );

	$auto_publish_sources = array( 'manual', 'catalog', 'context-exact', 'cluster' );
	$non_person_types = array( 'obra-franquia', 'empresa-estudio', 'evento', 'marca-produto', 'assunto-conceito' );
	$auto_publish_safe = $confidence >= 0.95
		&& in_array( $source, $auto_publish_sources, true )
		&& ( in_array( $type, $non_person_types, true ) || ( 'manual' === $source && in_array( $type, array( 'pessoa', 'personagem' ), true ) ) );
	/* People and characters are never batch-published from inference. If an editor
	 * explicitly confirms the type, normal publication/bulk publication remains
	 * available. This avoids turning every cast/character mention into SEO inventory. */
	if ( $allow_publish && $auto_publish_safe && 'ready' === $status && 'draft' === $post->post_status && current_user_can( 'publish_posts' ) ) {
		wp_update_post( array( 'ID' => $entity_id, 'post_status' => 'publish' ) );
		update_post_meta( $entity_id, '_go_entity_auto_published_v29', current_time( 'mysql', true ) );
		$status = 'published';
		$reason = 'Publicado automaticamente porque o tipo foi confirmado por fonte editorial forte e há cobertura suficiente.';
		update_post_meta( $entity_id, '_go_entity_intelligence_status', $status );
		update_post_meta( $entity_id, '_go_entity_intelligence_reason', $reason );
	}
	return array( 'status' => $status, 'score' => $score, 'type' => $type, 'reason' => $reason, 'source' => $source, 'count' => $count, 'threshold' => $threshold );
}

/** Incremental first-run classification/publishing. Safe for ordinary admin requests. */
function go_verge_v27_run_entity_intelligence_batch() {
	if ( ! is_admin() || wp_doing_ajax() || ! current_user_can( 'manage_categories' ) ) { return; }
	if ( get_option( 'go_verge_entity_intelligence_done' ) === GO_VERGE_ENTITY_INTELLIGENCE_VERSION ) { return; }
	if ( ! function_exists( 'go_verge_claim_job_lock' ) || ! go_verge_claim_job_lock( 'entity_intelligence_batch', 5 * MINUTE_IN_SECONDS ) ) { return; }
	$run_version = (string) get_option( 'go_verge_entity_intelligence_run_version', '' );
	if ( GO_VERGE_ENTITY_INTELLIGENCE_VERSION !== $run_version ) {
		update_option( 'go_verge_entity_intelligence_run_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION, false );
		delete_option( 'go_verge_entity_intelligence_cursor' );
	}
	$cursor = absint( get_option( 'go_verge_entity_intelligence_cursor', 0 ) );
	global $wpdb;
	$ids = $wpdb->get_col( $wpdb->prepare( // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
		"SELECT ID FROM {$wpdb->posts} WHERE post_type=%s AND post_status IN ('draft','publish','pending','private') AND ID>%d ORDER BY ID ASC LIMIT 60",
		'go_entity', $cursor
	) );
	$ids = array_values( array_filter( array_map( 'absint', (array) $ids ) ) );
	if ( ! $ids ) {
		update_option( 'go_verge_entity_intelligence_done', GO_VERGE_ENTITY_INTELLIGENCE_VERSION, false );
		delete_option( 'go_verge_entity_intelligence_cursor' );
		go_verge_release_job_lock( 'entity_intelligence_batch' );
		return;
	}
	$GLOBALS['go_verge_v27_intelligence_batch_running'] = true;
	$GLOBALS['go_verge_v27_intelligence_batch_dirty']   = false;
	foreach ( $ids as $entity_id ) { go_verge_v27_analyze_entity( $entity_id, true ); }
	$GLOBALS['go_verge_v27_intelligence_batch_running'] = false;
	if ( ! empty( $GLOBALS['go_verge_v27_intelligence_batch_dirty'] ) ) {
		delete_transient( 'go_entity_story_sets_v27' );
		delete_transient( 'go_entity_duplicate_groups_v27' );
		if ( function_exists( 'go_verge_v25_flush_entity_published_counts' ) ) { go_verge_v25_flush_entity_published_counts(); }
	}
	update_option( 'go_verge_entity_intelligence_cursor', max( $ids ), false );
	go_verge_release_job_lock( 'entity_intelligence_batch' );
}
add_action( 'admin_init', 'go_verge_v27_run_entity_intelligence_batch', 55 );

/** Re-analyze directly affected entities whenever an editorial story changes. */
function go_verge_v27_reanalyze_story_entities( $post_id ) {
	if ( wp_is_post_revision( $post_id ) || 'post' !== get_post_type( $post_id ) ) { return; }
	if ( function_exists( 'go_verge_editor_rest_save_in_progress' ) && go_verge_editor_rest_save_in_progress() ) {
		go_verge_defer_post_save_maintenance( $post_id );
		return;
	}
	foreach ( array_map( 'absint', (array) get_post_meta( $post_id, '_go_entity_ids', true ) ) as $entity_id ) {
		if ( 'go_entity' === get_post_type( $entity_id ) ) { go_verge_v27_analyze_entity( $entity_id, false ); }
	}
}
add_action( 'save_post_post', 'go_verge_v27_reanalyze_story_entities', 1200 );

/** Redirect any published legacy/canonical-shadow entity URL to its one real destination. */
function go_verge_v27_redirect_entity_shadow() {
	if ( ! is_singular( 'go_entity' ) ) { return; }
	$entity_id = get_queried_object_id();
	$duplicate_of = absint( get_post_meta( $entity_id, '_go_entity_duplicate_of', true ) );
	if ( $duplicate_of && 'publish' === get_post_status( $duplicate_of ) ) {
		$url = get_permalink( $duplicate_of );
		if ( $url ) { wp_safe_redirect( $url, 301, 'Overdrive entity duplicate canonical' ); exit; }
	}

	$url = esc_url_raw( get_post_meta( $entity_id, '_go_entity_canonical_url', true ) );
	if ( $url ) { wp_safe_redirect( $url, 301, 'Overdrive entity structural canonical' ); exit; }

	/* V35 self-healing canonicalization. The catalogue can evolve after the
	 * original migration. Re-check a published entity on request so an old
	 * /universo/Outer-Banks style shadow can never remain as a zero-content hub
	 * after the real Production/Game record exists.
	 */
	$target = go_verge_v27_entity_canonical_target( $entity_id );
	if ( $target && ! empty( $target['url'] ) ) {
		update_post_meta( $entity_id, '_go_entity_intelligence_status', 'canonical' );
		update_post_meta( $entity_id, '_go_entity_intelligence_score', 0 );
		update_post_meta( $entity_id, '_go_entity_intelligence_reason', sprintf( 'Usar hub canônico de %s; URL de entidade aposentada automaticamente.', $target['kind'] ) );
		update_post_meta( $entity_id, '_go_entity_canonical_url', esc_url_raw( $target['url'] ) );
		update_post_meta( $entity_id, '_go_entity_intelligence_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION );
		if ( function_exists( 'go_verge_v27_migrate_entity_relationships_to_target' ) ) {
			go_verge_v27_migrate_entity_relationships_to_target( $entity_id, $target );
		}
		wp_safe_redirect( $target['url'], 301, 'Overdrive entity live canonical repair' );
		exit;
	}
}
add_action( 'template_redirect', 'go_verge_v27_redirect_entity_shadow', -5 );

/**
 * Whether a published entity URL is served or answered with a 301.
 *
 * Read-only mirror of go_verge_v27_redirect_entity_shadow() for XML sitemaps:
 * duplicates, stored structural canonicals and live catalogue/platform shadows
 * all redirect, so none of them may be submitted as an indexable URL.
 */
function go_verge_v27_entity_is_redirected( $entity_id ) {
	$entity_id    = absint( $entity_id );
	$duplicate_of = absint( get_post_meta( $entity_id, '_go_entity_duplicate_of', true ) );
	if ( $duplicate_of && 'publish' === get_post_status( $duplicate_of ) && get_permalink( $duplicate_of ) ) { return true; }
	if ( esc_url_raw( get_post_meta( $entity_id, '_go_entity_canonical_url', true ) ) ) { return true; }
	$target = go_verge_v27_entity_canonical_target( $entity_id );
	return $target && ! empty( $target['url'] );
}

/** Keep duplicate/structural-shadow URLs out of Rank Math's sitemap. */
function go_verge_v27_rank_math_sitemap_entry( $url, $type, $object ) {
	if ( 'post' !== $type || ! ( $object instanceof WP_Post ) || 'go_entity' !== $object->post_type ) { return $url; }
	$status = sanitize_key( get_post_meta( $object->ID, '_go_entity_intelligence_status', true ) );
	if ( in_array( $status, array( 'duplicate', 'canonical' ), true ) ) { return false; }
	return $url;
}
add_filter( 'rank_math/sitemap/entry', 'go_verge_v27_rank_math_sitemap_entry', 30, 3 );

/** Add intelligence columns immediately after the story count. */
function go_verge_v27_entity_columns( $columns ) {
	$new = array();
	foreach ( $columns as $key => $label ) {
		$new[ $key ] = $label;
		if ( 'go_entity_stories' === $key ) {
			$new['go_entity_intelligence'] = __( 'Situação editorial', 'go-verge' );
			$new['go_entity_score'] = __( 'Score', 'go-verge' );
		}
	}
	return $new;
}
add_filter( 'manage_go_entity_posts_columns', 'go_verge_v27_entity_columns', 50 );

function go_verge_v27_entity_column_content( $column, $post_id ) {
	if ( 'go_entity_intelligence' === $column ) {
		$status = sanitize_key( get_post_meta( $post_id, '_go_entity_intelligence_status', true ) );
		$reason = (string) get_post_meta( $post_id, '_go_entity_intelligence_reason', true );
		$labels = array(
			'published' => 'Publicado', 'ready' => 'Pronto', 'hold' => 'Aguardar', 'review' => 'Revisar', 'canonical' => 'Canônico em outro hub', 'duplicate' => 'Duplicata',
		);
		$label = $labels[ $status ] ?? 'Não analisado';
		printf( '<span class="go-entity-intel go-entity-intel--%1$s" title="%2$s">%3$s</span>%4$s', esc_attr( $status ?: 'none' ), esc_attr( $reason ), esc_html( $label ), $reason ? '<small class="go-entity-intel-reason">' . esc_html( $reason ) . '</small>' : '' );
	}
	if ( 'go_entity_score' === $column ) {
		$score = absint( get_post_meta( $post_id, '_go_entity_intelligence_score', true ) );
		echo '<strong>' . esc_html( $score ) . '</strong><span class="screen-reader-text">/100</span>';
	}
}
add_action( 'manage_go_entity_posts_custom_column', 'go_verge_v27_entity_column_content', 50, 2 );

/** Admin filters for readiness/type. */
function go_verge_v27_entity_admin_filters( $post_type, $which ) {
	if ( 'go_entity' !== $post_type || 'top' !== $which ) { return; }
	$current = isset( $_GET['go_entity_intel_status'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_intel_status'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	?>
	<label class="screen-reader-text" for="go-entity-intel-status"><?php esc_html_e( 'Situação editorial', 'go-verge' ); ?></label>
	<select name="go_entity_intel_status" id="go-entity-intel-status">
		<option value=""><?php esc_html_e( 'Situação: qualquer', 'go-verge' ); ?></option>
		<option value="ready" <?php selected( $current, 'ready' ); ?>><?php esc_html_e( 'Prontas para publicar', 'go-verge' ); ?></option>
		<option value="published" <?php selected( $current, 'published' ); ?>><?php esc_html_e( 'Publicadas / aprovadas', 'go-verge' ); ?></option>
		<option value="review" <?php selected( $current, 'review' ); ?>><?php esc_html_e( 'Precisam de revisão', 'go-verge' ); ?></option>
		<option value="hold" <?php selected( $current, 'hold' ); ?>><?php esc_html_e( 'Aguardando cobertura', 'go-verge' ); ?></option>
		<option value="canonical" <?php selected( $current, 'canonical' ); ?>><?php esc_html_e( 'Já têm hub canônico', 'go-verge' ); ?></option>
		<option value="duplicate" <?php selected( $current, 'duplicate' ); ?>><?php esc_html_e( 'Duplicatas', 'go-verge' ); ?></option>
	</select>
	<?php
	$type_current = isset( $_GET['go_entity_type_filter'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_type_filter'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	echo '<label class="screen-reader-text" for="go-entity-type-filter">' . esc_html__( 'Tipo de entidade', 'go-verge' ) . '</label>';
	echo '<select name="go_entity_type_filter" id="go-entity-type-filter"><option value="">' . esc_html__( 'Tipo: qualquer', 'go-verge' ) . '</option>';
	foreach ( go_verge_v27_entity_type_blueprint() as $slug => $label ) {
		printf( '<option value="%1$s"%2$s>%3$s</option>', esc_attr( $slug ), selected( $type_current, $slug, false ), esc_html( $label ) );
	}
	echo '</select>';
}
add_action( 'restrict_manage_posts', 'go_verge_v27_entity_admin_filters', 30, 2 );

function go_verge_v27_filter_entity_admin( $query ) {
	if ( ! is_admin() || ! $query->is_main_query() ) { return; }
	global $pagenow;
	if ( 'edit.php' !== $pagenow || 'go_entity' !== $query->get( 'post_type' ) ) { return; }
	$status = isset( $_GET['go_entity_intel_status'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_intel_status'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( in_array( $status, array( 'ready','published','review','hold','canonical','duplicate' ), true ) ) {
		$meta_query = (array) $query->get( 'meta_query' );
		$meta_query[] = array( 'key' => '_go_entity_intelligence_status', 'value' => $status, 'compare' => '=' );
		$query->set( 'meta_query', $meta_query );
	}
	$type = isset( $_GET['go_entity_type_filter'] ) ? sanitize_key( wp_unslash( $_GET['go_entity_type_filter'] ) ) : ''; // phpcs:ignore WordPress.Security.NonceVerification.Recommended
	if ( isset( go_verge_v27_entity_type_blueprint()[ $type ] ) ) {
		$query->set( 'tax_query', array( array( 'taxonomy' => 'go_entity_type', 'field' => 'slug', 'terms' => array( $type ) ) ) );
	}
}
add_action( 'pre_get_posts', 'go_verge_v27_filter_entity_admin', 45 );

/** Manual rescue actions for selected rows. */
function go_verge_v27_bulk_actions( $actions ) {
	$actions['go_entity_reanalyze_v27'] = __( 'Reanalisar inteligência', 'go-verge' );
	$actions['go_entity_publish_ready_v27'] = __( 'Publicar somente as recomendadas', 'go-verge' );
	return $actions;
}
add_filter( 'bulk_actions-edit-go_entity', 'go_verge_v27_bulk_actions', 60 );

function go_verge_v27_handle_bulk_actions( $redirect, $action, $ids ) {
	if ( ! in_array( $action, array( 'go_entity_reanalyze_v27', 'go_entity_publish_ready_v27' ), true ) ) { return $redirect; }
	$done = 0; $published = 0;
	foreach ( array_map( 'absint', (array) $ids ) as $entity_id ) {
		if ( ! $entity_id || 'go_entity' !== get_post_type( $entity_id ) || ! current_user_can( 'edit_post', $entity_id ) ) { continue; }
		$result = go_verge_v27_analyze_entity( $entity_id, 'go_entity_publish_ready_v27' === $action );
		++$done;
		if ( 'published' === ( $result['status'] ?? '' ) ) { ++$published; }
	}
	return add_query_arg( array( 'go_entity_intel_processed' => $done, 'go_entity_intel_published' => $published ), $redirect );
}
add_filter( 'handle_bulk_actions-edit-go_entity', 'go_verge_v27_handle_bulk_actions', 60, 3 );

function go_verge_v27_admin_notices() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'edit-go_entity' !== $screen->id ) { return; }
	$done = get_option( 'go_verge_entity_intelligence_done' ) === GO_VERGE_ENTITY_INTELLIGENCE_VERSION;
	$cursor = absint( get_option( 'go_verge_entity_intelligence_cursor', 0 ) );
	if ( ! $done ) {
		echo '<div class="notice notice-info"><p><strong>Entidades inteligentes:</strong> classificação por evidência, deduplicação segura e publicação conservadora estão sendo processadas em lotes. O processo continua a cada acesso administrativo sem travar o editor.';
		if ( $cursor ) { echo ' Último ID processado: <code>' . esc_html( $cursor ) . '</code>.'; }
		echo '</p></div>';
	}
	if ( isset( $_GET['go_entity_intel_processed'] ) ) { // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$processed = absint( $_GET['go_entity_intel_processed'] ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		$published = absint( $_GET['go_entity_intel_published'] ?? 0 ); // phpcs:ignore WordPress.Security.NonceVerification.Recommended
		printf( '<div class="notice notice-success is-dismissible"><p>%s</p></div>', esc_html( sprintf( '%d entidades analisadas; %d publicadas por atenderem aos critérios.', $processed, $published ) ) );
	}
}
add_action( 'admin_notices', 'go_verge_v27_admin_notices', 40 );

/** Light admin styling for status readability. */
function go_verge_v27_admin_css() {
	$screen = function_exists( 'get_current_screen' ) ? get_current_screen() : null;
	if ( ! $screen || 'edit-go_entity' !== $screen->id ) { return; }
	?>
	<style>
	.column-go_entity_intelligence{width:220px}.column-go_entity_score{width:68px;text-align:center}.go-entity-intel{display:inline-flex;align-items:center;min-height:24px;padding:1px 8px;border-radius:999px;font-weight:650;font-size:12px;line-height:1.6;background:#f0f0f1;color:#2c3338}.go-entity-intel--ready,.go-entity-intel--published{background:#edfaef;color:#135e26}.go-entity-intel--review{background:#fff8e5;color:#8a4b00}.go-entity-intel--canonical{background:#eaf2ff;color:#135e96}.go-entity-intel--duplicate{background:#f6f7f7;color:#50575e}.go-entity-intel--hold{background:#f6f7f7;color:#646970}.go-entity-intel-reason{display:block;max-width:220px;margin-top:5px;color:#646970;line-height:1.35}.column-go_entity_score strong{display:inline-block;min-width:34px;padding:3px 5px;border-radius:6px;background:#f0f0f1}
	@media(max-width:782px){.column-go_entity_intelligence,.column-go_entity_score{width:auto}.go-entity-intel-reason{max-width:none}}
	</style>
	<?php
}
add_action( 'admin_head', 'go_verge_v27_admin_css', 60 );

/**
 * V35: when a Production/Game catalogue item is saved, immediately retire an
 * exact-title generic entity shadow. This keeps future editor work from creating
 * two competing hubs for the same work.
 */
function go_verge_v35_sync_catalog_shadow_entities( $catalog_id, $post = null ) {
	$catalog_id = absint( $catalog_id );
	$post = $post instanceof WP_Post ? $post : get_post( $catalog_id );
	if ( ! ( $post instanceof WP_Post ) || ! in_array( $post->post_type, array( 'productions', 'games' ), true ) || 'publish' !== $post->post_status ) { return; }
	if ( wp_is_post_revision( $catalog_id ) || wp_is_post_autosave( $catalog_id ) ) { return; }

	$key = go_verge_v27_entity_key( $post->post_title );
	if ( ! $key ) { return; }
	$candidates = get_posts( array(
		'post_type' => 'go_entity',
		'post_status' => array( 'publish', 'draft' ),
		's' => $post->post_title,
		'posts_per_page' => 20,
		'no_found_rows' => true,
		'suppress_filters' => false,
	) );
	$kind = 'productions' === $post->post_type ? 'production' : 'game';
	$url = get_permalink( $catalog_id );
	if ( ! $url ) { return; }
	foreach ( $candidates as $entity ) {
		if ( ! ( $entity instanceof WP_Post ) || $key !== go_verge_v27_entity_key( $entity->post_title ) ) { continue; }
		$type = sanitize_key( get_post_meta( $entity->ID, '_go_entity_intelligence_type', true ) );
		$terms = wp_get_object_terms( $entity->ID, 'go_entity_type', array( 'fields' => 'slugs' ) );
		if ( is_wp_error( $terms ) ) { $terms = array(); }
		/* Only retire generic work/franchise shadows automatically. A real person
		 * or character can legitimately share a title with a work. */
		if ( $type && 'obra-franquia' !== $type && ! in_array( 'obra-franquia', $terms, true ) ) { continue; }
		$target = array( 'kind'=>$kind, 'target_id'=>$catalog_id, 'target_slug'=>$post->post_name, 'url'=>$url );
		update_post_meta( $entity->ID, '_go_entity_intelligence_status', 'canonical' );
		update_post_meta( $entity->ID, '_go_entity_canonical_url', esc_url_raw( $url ) );
		update_post_meta( $entity->ID, '_go_entity_intelligence_version', GO_VERGE_ENTITY_INTELLIGENCE_VERSION );
		go_verge_v27_migrate_entity_relationships_to_target( $entity->ID, $target );
	}
}
add_action( 'save_post_productions', 'go_verge_v35_sync_catalog_shadow_entities', 100, 2 );
add_action( 'save_post_games', 'go_verge_v35_sync_catalog_shadow_entities', 100, 2 );
