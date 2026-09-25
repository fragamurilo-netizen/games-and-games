<?php
/**
 * Publisher and author authority signals (E-E-A-T).
 *
 * Emit policy links only when their dedicated published pages exist. Report
 * missing pages in Site Health so the newsroom can document actual practices.
 * Generic attribution guidance is not a substitute for an anonymous-source
 * policy. Author credentials come from saved profile fields; a career start
 * year must not be presented as the start of a particular job.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Trust pages this module can publish as machine-readable policy claims.
 *
 * `reuse` is reserved for a separately verified equivalent policy. The current
 * map requires a dedicated published page for each property.
 *
 * @return array<string,array{slug:string,label:string,needs:string,reuse:string}>
 */
function go_verge_eeat_trust_pages() {
	return array(
		'ownershipFundingInfo' => array(
			'slug'  => 'propriedade-e-financiamento',
			'label' => __( 'Propriedade e financiamento', 'go-verge' ),
			'needs' => __( 'Quem é dono da publicação, como ela se sustenta (publicidade, afiliados, assinaturas) e qual a separação entre quem financia e quem decide a pauta.', 'go-verge' ),
			'reuse' => '',
		),
		'missionCoveragePrioritiesPolicy' => array(
			'slug'  => 'missao-e-prioridades-de-cobertura',
			'label' => __( 'Missão e prioridades de cobertura', 'go-verge' ),
			'needs' => __( 'O que a publicação cobre, o que decide não cobrir e por quê — o critério que define a pauta antes de qualquer matéria existir.', 'go-verge' ),
			'reuse' => '',
		),
		'diversityPolicy' => array(
			'slug'  => 'politica-de-diversidade',
			'label' => __( 'Política de diversidade', 'go-verge' ),
			'needs' => __( 'Compromissos sobre diversidade na redação e nas fontes ouvidas. Publique apenas se houver uma política real; uma página genérica não é sinal de autoridade.', 'go-verge' ),
			'reuse' => '',
		),
		'noBylinesPolicy' => array(
			'slug'  => 'politica-de-assinatura',
			'label' => __( 'Política de autoria e matérias sem assinatura', 'go-verge' ),
			'needs' => __( 'Quando uma matéria pode sair sem assinatura individual, quem responde por ela nesse caso e como o leitor pode cobrar.', 'go-verge' ),
			'reuse' => '',
		),
		'unnamedSourcesPolicy' => array(
			'slug'  => 'politica-de-fontes-nao-identificadas',
			'label' => __( 'Política de fontes não identificadas', 'go-verge' ),
			'needs' => __( 'Quando a redação aceita uma fonte sem identificação, que verificação exige antes de publicar e como sinaliza isso ao leitor.', 'go-verge' ),
			/* Attribution and rumour guidance does not establish a policy for
			 * accepting anonymous sources. Require its own published policy. */
			'reuse' => '',
		),
	);
}

/** Published permalink for a page slug, or '' when the page is absent/draft. */
function go_verge_eeat_published_page_url( $slug ) {
	$slug = sanitize_title( (string) $slug );
	if ( '' === $slug ) {
		return '';
	}
	$page = get_page_by_path( $slug, OBJECT, 'page' );
	if ( ! ( $page instanceof WP_Post ) || 'publish' !== get_post_status( $page ) ) {
		return '';
	}
	return (string) get_permalink( $page );
}

/**
 * Resolve the trust properties that currently have a real destination.
 *
 * @return array<string,string> Schema property => URL.
 */
function go_verge_eeat_resolved_trust_urls() {
	$resolved = array();
	foreach ( go_verge_eeat_trust_pages() as $property => $spec ) {
		$url = go_verge_eeat_published_page_url( $spec['slug'] );
		if ( '' === $url && '' !== $spec['reuse'] ) {
			$url = go_verge_eeat_published_page_url( $spec['reuse'] );
		}
		if ( '' !== $url ) {
			$resolved[ $property ] = $url;
		}
	}
	return (array) apply_filters( 'go_verge_eeat_trust_urls', $resolved );
}

/**
 * Publisher-level facts that follow from configuration rather than from a page.
 *
 * These are safe to assert because they restate what the site already is: its
 * language and the market it publishes for. Nothing here is inferred from
 * traffic or invented.
 *
 * @return array<string,mixed>
 */
function go_verge_eeat_publisher_facts() {
	$locale   = (string) get_bloginfo( 'language' );
	$facts    = array();
	if ( '' !== $locale ) {
		$facts['knowsLanguage'] = array( $locale );
	}
	$region = '';
	if ( preg_match( '/^[a-z]{2,3}-([A-Za-z]{2})$/', $locale, $m ) ) {
		$region = strtoupper( $m[1] );
	}
	if ( '' !== $region ) {
		$facts['areaServed'] = array(
			'@type' => 'Country',
			'name'  => $region,
		);
	}
	return (array) apply_filters( 'go_verge_eeat_publisher_facts', $facts );
}

/**
 * Merge the extra trust properties into the canonical publisher node.
 *
 * Runs after go_verge_rank_math_news_policies() (950) so it extends the same
 * node rather than competing with it, and only ever touches the node whose @id
 * is the publication's own organization id.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_eeat_extend_publisher( $data ) {
	if ( ! is_array( $data ) ) {
		return $data;
	}
	$organization_id = home_url( '/#organization' );
	$extra           = array_merge( go_verge_eeat_resolved_trust_urls(), go_verge_eeat_publisher_facts() );
	if ( ! $extra ) {
		return $data;
	}

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || ! isset( $node['@id'] ) || $organization_id !== (string) $node['@id'] ) {
			continue;
		}
		foreach ( $extra as $property => $value ) {
			/* Never overwrite a value another module already resolved. */
			if ( ! isset( $data[ $key ][ $property ] ) || '' === $data[ $key ][ $property ] ) {
				$data[ $key ][ $property ] = is_string( $value ) ? esc_url_raw( $value ) : $value;
			}
		}
	}
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_eeat_extend_publisher', 960, 1 );

/* -------------------------------------------------------------------------
 * Author credentials
 * ---------------------------------------------------------------------- */

/**
 * Add verifiable-credential fields to the author profile.
 *
 * `go_author_credentials` already exists but is free prose: useful to a reader,
 * invisible to a parser. These four are structured because each maps to a
 * schema.org property that states why a byline is qualified.
 *
 * @param array $fields Registered field groups.
 * @return array
 */
function go_verge_eeat_author_fields( $fields ) {
	if ( ! isset( $fields['expertise']['fields'] ) || ! is_array( $fields['expertise']['fields'] ) ) {
		return $fields;
	}
	$fields['expertise']['fields']['go_author_alma_mater'] = array(
		'label'       => __( 'Formação (instituição)', 'go-verge' ),
		'type'        => 'text',
		'placeholder' => __( 'Ex.: PUCRS', 'go-verge' ),
		'description' => __( 'Instituição de ensino. Vira alumniOf nos dados estruturados; separe por vírgulas se houver mais de uma.', 'go-verge' ),
		'maxlength'   => 200,
		'wide'        => true,
	);
	$fields['expertise']['fields']['go_author_memberships'] = array(
		'label'       => __( 'Associações profissionais', 'go-verge' ),
		'type'        => 'text',
		'placeholder' => __( 'Ex.: Abraji, FENAJ', 'go-verge' ),
		'description' => __( 'Entidades das quais o autor é membro. Vira memberOf; separe por vírgulas.', 'go-verge' ),
		'maxlength'   => 300,
		'wide'        => true,
	);
	$fields['expertise']['fields']['go_author_awards'] = array(
		'label'       => __( 'Prêmios e reconhecimentos', 'go-verge' ),
		'type'        => 'text',
		'placeholder' => __( 'Ex.: Prêmio Xyz 2024', 'go-verge' ),
		'description' => __( 'Prêmios verificáveis. Vira award; separe por vírgulas.', 'go-verge' ),
		'maxlength'   => 400,
		'wide'        => true,
	);
	return $fields;
}
add_filter( 'go_verge_author_profile_fields', 'go_verge_eeat_author_fields', 20 );

/** Split a comma/semicolon list into clean, bounded values. */
function go_verge_eeat_split_list( $value, $limit = 6 ) {
	$parts = preg_split( '/[,;\n]+/u', (string) $value );
	$parts = array_map( 'sanitize_text_field', array_map( 'trim', (array) $parts ) );
	$parts = array_values( array_unique( array_filter( $parts ) ) );
	return array_slice( $parts, 0, max( 1, (int) $limit ) );
}

/**
 * Enrich every author Person node in the graph with its credentials.
 *
 * Works on whatever Person nodes are already present rather than adding new
 * ones, which is the same collision-safe contract the rest of the SEO layer
 * uses: an existing node is extended, never replaced.
 *
 * @param array $data Rank Math graph.
 * @return array
 */
function go_verge_eeat_extend_author( $data ) {
	if ( ! is_array( $data ) || ! function_exists( 'go_verge_author_profile_value' ) ) {
		return $data;
	}
	$author_id = 0;
	if ( is_singular() ) {
		$author_id = (int) get_post_field( 'post_author', get_queried_object_id() );
	} elseif ( is_author() ) {
		$author_id = (int) get_queried_object_id();
	}
	if ( $author_id <= 0 ) {
		return $data;
	}

	$person_id = get_author_posts_url( $author_id ) . '#person';
	$additions = array();

	$alma = go_verge_eeat_split_list( go_verge_author_profile_value( $author_id, 'go_author_alma_mater' ), 4 );
	if ( $alma ) {
		$additions['alumniOf'] = array_map(
			static function ( $name ) {
				return array( '@type' => 'EducationalOrganization', 'name' => $name );
			},
			$alma
		);
	}
	$members = go_verge_eeat_split_list( go_verge_author_profile_value( $author_id, 'go_author_memberships' ), 6 );
	if ( $members ) {
		$additions['memberOf'] = array_map(
			static function ( $name ) {
				return array( '@type' => 'Organization', 'name' => $name );
			},
			$members
		);
	}
	$awards = go_verge_eeat_split_list( go_verge_author_profile_value( $author_id, 'go_author_awards' ), 8 );
	if ( $awards ) {
		$additions['award'] = $awards;
	}

	/* hasOccupation restates the existing role as a typed node, and carries the
	 * beat as occupationalCategory. Both come from fields the newsroom already
	 * fills, so this adds structure rather than a new claim. */
	$role = function_exists( 'go_verge_author_role' ) ? trim( (string) go_verge_author_role( $author_id ) ) : '';
	if ( '' !== $role ) {
		$occupation = array( '@type' => 'Occupation', 'name' => $role );
		if ( function_exists( 'go_verge_author_list_meta' ) ) {
			$beats = go_verge_author_list_meta( $author_id, 'go_author_coverage', 6 );
			if ( $beats ) {
				$occupation['occupationalCategory'] = $beats;
			}
		}
		/* go_author_since is the start of the author's journalism career, not
		 * the start of this particular role. Do not infer a job start date. */
		$additions['hasOccupation'] = $occupation;
	}

	if ( ! $additions ) {
		return $data;
	}

	foreach ( $data as $key => $node ) {
		if ( ! is_array( $node ) || ! isset( $node['@id'] ) || $person_id !== (string) $node['@id'] ) {
			continue;
		}
		foreach ( $additions as $property => $value ) {
			if ( ! isset( $data[ $key ][ $property ] ) ) {
				$data[ $key ][ $property ] = $value;
			}
		}
	}
	return $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_eeat_extend_author', 962, 1 );

/* -------------------------------------------------------------------------
 * Numeric hygiene
 * ---------------------------------------------------------------------- */

/**
 * Properties that schema.org types as Number/Integer.
 *
 * Rank Math serialises these as strings — `"width": "1600"`, `"position": "1"`,
 * `"wordCount": "1649"` — which validators flag and which forces every consumer
 * to coerce. Casting them is lossless and removes a whole class of warning.
 *
 * @return array<int,string>
 */
function go_verge_eeat_numeric_properties() {
	return array( 'width', 'height', 'position', 'wordCount', 'commentCount', 'ratingValue', 'bestRating', 'worstRating', 'ratingCount', 'reviewCount', 'numberOfEmployees' );
}

/**
 * Recursively cast numeric-typed schema properties to real numbers.
 *
 * @param mixed $value Graph fragment.
 * @return mixed
 */
function go_verge_eeat_normalize_numbers( $value ) {
	if ( ! is_array( $value ) ) {
		return $value;
	}
	$numeric = array_flip( go_verge_eeat_numeric_properties() );
	foreach ( $value as $key => $item ) {
		if ( is_array( $item ) ) {
			$value[ $key ] = go_verge_eeat_normalize_numbers( $item );
			continue;
		}
		if ( ! is_string( $key ) || ! isset( $numeric[ $key ] ) || ! is_string( $item ) ) {
			continue;
		}
		$trimmed = trim( $item );
		if ( '' === $trimmed || ! is_numeric( $trimmed ) ) {
			continue;
		}
		$value[ $key ] = ( (string) (int) $trimmed === $trimmed ) ? (int) $trimmed : (float) $trimmed;
	}
	return $value;
}

/** Apply numeric hygiene last, after every other module has finished writing. */
function go_verge_eeat_normalize_graph( $data ) {
	return is_array( $data ) ? go_verge_eeat_normalize_numbers( $data ) : $data;
}
add_filter( 'rank_math/json_ld', 'go_verge_eeat_normalize_graph', 2100, 1 );

/* -------------------------------------------------------------------------
 * Reporting
 * ---------------------------------------------------------------------- */

/** Turn the remaining trust gaps into an actionable Site Health checklist. */
function go_verge_eeat_health_test() {
	$badge   = array( 'label' => __( 'Search', 'go-verge' ), 'color' => 'blue' );
	$pages   = go_verge_eeat_trust_pages();
	$present = go_verge_eeat_resolved_trust_urls();
	$missing = array_diff_key( $pages, $present );

	if ( ! $missing ) {
		return array(
			'label'       => __( 'Todas as políticas de confiança do publisher estão publicadas', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: %d: number of policy properties emitted. */
					__( 'As %d propriedades de confiança adicionais do NewsMediaOrganization apontam para páginas publicadas e são emitidas no grafo.', 'go-verge' ),
					count( $present )
				)
			) . '</p>',
			'test'        => 'go_verge_eeat_trust',
		);
	}

	$items = '';
	foreach ( $missing as $property => $spec ) {
		$items .= '<li><strong>' . esc_html( $spec['label'] ) . '</strong> <code>' . esc_html( $property ) . '</code><br>'
			. esc_html( $spec['needs'] )
			. '<br><em>' . esc_html( sprintf( /* translators: %s: page slug. */ __( 'Slug esperado: /%s/', 'go-verge' ), $spec['slug'] ) ) . '</em></li>';
	}

	return array(
		'label'       => __( 'Há políticas de confiança do publisher ainda não publicadas', 'go-verge' ),
		'status'      => 'recommended',
		'badge'       => $badge,
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: 1: emitted count, 2: total count. */
				__( '%1$d de %2$d propriedades extras de confiança estão sendo emitidas. O tema não inventa as demais: uma propriedade de política é a afirmação de que existe uma página dizendo aquilo, e apontá-la para uma página genérica é violação de dados estruturados, não ganho de autoridade. Publique a página e a propriedade passa a ser emitida sozinha.', 'go-verge' ),
				count( $present ),
				count( $pages )
			)
		) . '</p><ul>' . $items . '</ul>', // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
		'actions'     => '<p><a href="' . esc_url( admin_url( 'edit.php?post_type=page' ) ) . '">' . esc_html__( 'Revisar páginas institucionais', 'go-verge' ) . '</a></p>',
		'test'        => 'go_verge_eeat_trust',
	);
}

/** Register the authority checklist. */
function go_verge_register_eeat_health( $tests ) {
	$tests['direct']['go_verge_eeat_trust'] = array(
		'label' => __( 'Autoridade e E-E-A-T do publisher', 'go-verge' ),
		'test'  => 'go_verge_eeat_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_eeat_health' );

/* -------------------------------------------------------------------------
 * robots.txt ownership
 * ---------------------------------------------------------------------- */

/**
 * Detect a physical robots.txt shadowing the dynamic one.
 *
 * WordPress only serves a generated robots.txt when no real file exists at the
 * document root. The theme's `robots_txt` filters — which strip the legacy
 * `/sitemap_index.xml` directive and publish `/sitemap.xml` plus
 * `/news-sitemap.xml` — therefore never run on a site that has a physical file,
 * and the two silently diverge.
 *
 * Measured on production 01/09/2026: the served robots.txt still announced
 * `Sitemap: https://gameoverdrive.com.br/sitemap_index.xml`, a URL that 301s to
 * `/sitemap.xml`. Search Console follows the redirect but reports against the
 * submitted URL, so the canonical index was never the one being measured.
 */
function go_verge_eeat_physical_robots_path() {
	$path = ABSPATH . 'robots.txt';
	return is_file( $path ) ? $path : '';
}

/** Compare the physical file against what the theme would have generated. */
function go_verge_eeat_robots_health_test() {
	$badge = array( 'label' => __( 'Search', 'go-verge' ), 'color' => 'blue' );
	$file  = go_verge_eeat_physical_robots_path();

	if ( '' === $file ) {
		return array(
			'label'       => __( 'O robots.txt é gerado pelo WordPress e pelo tema', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html__( 'Não existe arquivo físico na raiz, então os filtros do tema controlam as diretivas de sitemap e o índice canônico permanece único.', 'go-verge' ) . '</p>',
			'test'        => 'go_verge_eeat_robots',
		);
	}

	$contents = (string) @file_get_contents( $file ); // phpcs:ignore WordPress.PHP.NoSilencedErrors.Discouraged,WordPress.WP.AlternativeFunctions.file_get_contents_file_get_contents
	$stale    = array();
	foreach ( array( '/sitemap_index.xml', '/wp-sitemap.xml' ) as $legacy ) {
		if ( false !== strpos( $contents, $legacy ) ) {
			$stale[] = $legacy;
		}
	}
	$canonical = function_exists( 'go_verge_search_main_sitemap_url' ) ? go_verge_search_main_sitemap_url() : home_url( '/sitemap.xml' );
	$has_canonical = false !== strpos( $contents, $canonical );

	if ( ! $stale && $has_canonical ) {
		return array(
			'label'       => __( 'O robots.txt físico está alinhado com o índice canônico', 'go-verge' ),
			'status'      => 'good',
			'badge'       => $badge,
			'description' => '<p>' . esc_html(
				sprintf(
					/* translators: %s: canonical sitemap URL. */
					__( 'Existe um arquivo físico na raiz — os filtros do tema não são aplicados — mas ele já declara %s e não anuncia índices legados.', 'go-verge' ),
					$canonical
				)
			) . '</p>',
			'test'        => 'go_verge_eeat_robots',
		);
	}

	$problems = array();
	if ( $stale ) {
		$problems[] = sprintf(
			/* translators: %s: legacy sitemap paths. */
			__( 'anuncia índice legado (%s), que responde por redirecionamento', 'go-verge' ),
			implode( ', ', $stale )
		);
	}
	if ( ! $has_canonical ) {
		$problems[] = sprintf(
			/* translators: %s: canonical sitemap URL. */
			__( 'não declara o índice canônico %s', 'go-verge' ),
			$canonical
		);
	}

	return array(
		'label'       => __( 'O robots.txt físico está desatualizado em relação ao tema', 'go-verge' ),
		'status'      => 'recommended',
		'badge'       => $badge,
		'description' => '<p>' . esc_html(
			sprintf(
				/* translators: 1: file path, 2: list of problems. */
				__( 'O arquivo %1$s existe na raiz, então o WordPress serve ele e os filtros do tema nunca rodam. O conteúdo servido %2$s. Substitua o arquivo pelo modelo em deployment/robots.txt do tema, ou apague-o para que o WordPress volte a gerar as diretivas dinamicamente.', 'go-verge' ),
				$file,
				implode( '; ', $problems )
			)
		) . '</p>',
		'test'        => 'go_verge_eeat_robots',
	);
}

/** Register the robots.txt ownership check. */
function go_verge_register_eeat_robots_health( $tests ) {
	$tests['direct']['go_verge_eeat_robots'] = array(
		'label' => __( 'Propriedade do robots.txt', 'go-verge' ),
		'test'  => 'go_verge_eeat_robots_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_register_eeat_robots_health' );
