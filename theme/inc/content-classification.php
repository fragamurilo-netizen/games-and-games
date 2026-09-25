<?php
/**
 * Editorial content classification shared by schema and Google News sitemap.
 *
 * A category named "Games" or "Entretenimento" does not make every post a
 * news article. NewsArticle is emitted only when the post belongs to the
 * newsroom taxonomy: Notícias itself, one of its descendants, or an explicit
 * vertical-news category such as "Notícias de Games" / "Notícias de
 * Entretenimento" / "Notícias de Tecnologia".
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Normalize a category label for semantic matching. */
function go_verge_editorial_term_key( $value ) {
	$value = remove_accents( wp_strip_all_tags( (string) $value ) );
	$value = function_exists( 'mb_strtolower' ) ? mb_strtolower( $value, 'UTF-8' ) : strtolower( $value );
	$value = preg_replace( '/[^a-z0-9]+/i', '-', $value );
	return trim( (string) $value, '-' );
}

/**
 * Existing legacy category IDs grouped by the shared format precedence.
 * Descendants inherit explicit legacy newsroom/specialist branches. No term is
 * created and one cached category read serves every format in the request.
 */
function go_verge_legacy_content_type_category_ids( $type ) {
	static $by_type = null;
	if ( null === $by_type ) {
		$by_type = array();
		$terms = get_terms( array( 'taxonomy' => 'category', 'hide_empty' => false, 'update_term_meta_cache' => false ) );
		foreach ( is_array( $terms ) ? $terms : array() as $term ) {
			if ( ! ( $term instanceof WP_Term ) ) { continue; }
			$slugs = array( $term->slug );
			foreach ( (array) get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
				$ancestor = get_term( $ancestor_id, 'category' );
				if ( $ancestor instanceof WP_Term ) { $slugs[] = $ancestor->slug; }
			}
			$resolved = function_exists( 'go_verge_v7_default_type_for_categories' ) ? go_verge_v7_default_type_for_categories( $slugs ) : '';
			if ( '' === $resolved && go_verge_category_is_news_term( $term ) ) { $resolved = 'noticia'; }
			if ( '' !== $resolved ) { $by_type[ $resolved ][] = (int) $term->term_id; }
		}
	}
	return $by_type[ sanitize_title( $type ) ] ?? array();
}

/** Narrow tag fallback for literal Onde assistir archives used before the format taxonomy. */
function go_verge_legacy_content_type_tag_ids( $type ) {
	if ( 'onde-assistir' !== sanitize_title( $type ) || ! taxonomy_exists( 'post_tag' ) ) { return array(); }
	$ids = array();
	foreach ( array( 'onde-assistir', 'onde-assistir-online', 'assistir-online' ) as $slug ) {
		$term = get_term_by( 'slug', $slug, 'post_tag' );
		if ( $term instanceof WP_Term ) { $ids[] = (int) $term->term_id; }
	}
	return array_values( array_unique( array_filter( $ids ) ) );
}

/**
 * Query one editorial format without losing untyped legacy stories.
 *
 * One explicit valid type wins. Two different valid types remain unresolved.
 * Legacy fallback is allowed only with no type relationship, using the same
 * ordered precedence as the classifier (e.g. Guia de compra before Ofertas).
 * The returned tax_query group can be ANDed with a desk/category constraint.
 */
function go_verge_content_type_tax_query( $type ) {
	$type = sanitize_title( $type );
	$allowed = function_exists( 'go_verge_v3152_content_type_slugs' ) ? go_verge_v3152_content_type_slugs() : array();
	if ( ! in_array( $type, $allowed, true ) ) {
		return array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => array( 0 ), 'include_children' => false );
	}
	$explicit = array( 'relation' => 'AND',
		array( 'taxonomy' => 'go_content_type', 'field' => 'slug', 'terms' => array( $type ), 'include_children' => false ),
		array( 'taxonomy' => 'go_content_type', 'field' => 'slug', 'terms' => array_values( array_diff( $allowed, array( $type ) ) ), 'operator' => 'NOT IN', 'include_children' => false ),
	);
	$legacy_ids = go_verge_legacy_content_type_category_ids( $type );
	$legacy_tag_ids = go_verge_legacy_content_type_tag_ids( $type );
	$legacy_membership = array();
	if ( $legacy_ids ) {
		$legacy_membership[] = array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => $legacy_ids, 'include_children' => false );
	}
	if ( $legacy_tag_ids ) {
		$legacy_membership[] = array( 'taxonomy' => 'post_tag', 'field' => 'term_id', 'terms' => $legacy_tag_ids, 'include_children' => false );
	}
	if ( ! $legacy_membership ) { return $explicit; }
	$legacy_source = 1 === count( $legacy_membership ) ? $legacy_membership[0] : array_merge( array( 'relation' => 'OR' ), $legacy_membership );
	$legacy = array( 'relation' => 'AND',
		array( 'taxonomy' => 'go_content_type', 'operator' => 'NOT EXISTS' ),
		$legacy_source,
	);
	$conflicts = array();
	$priorities = function_exists( 'go_verge_editorial_legacy_type_categories' ) ? array_keys( go_verge_editorial_legacy_type_categories() ) : array();
	foreach ( $priorities as $priority ) {
		if ( $priority === $type ) { break; }
		$conflicts = array_merge( $conflicts, go_verge_legacy_content_type_category_ids( $priority ) );
	}
	if ( $conflicts ) {
		$legacy[] = array( 'taxonomy' => 'category', 'field' => 'term_id', 'terms' => array_values( array_unique( $conflicts ) ), 'operator' => 'NOT IN', 'include_children' => false );
	}
	return array( 'relation' => 'OR', $explicit, $legacy );
}

/**
 * Whether one category term represents the newsroom branch.
 *
 * @param WP_Term $term Category term.
 * @return bool
 */
function go_verge_category_is_news_term( $term ) {
	if ( ! ( $term instanceof WP_Term ) || 'category' !== $term->taxonomy ) {
		return false;
	}

	$keys = array_filter(
		array_unique(
			array(
				go_verge_editorial_term_key( $term->slug ),
				go_verge_editorial_term_key( $term->name ),
			)
		)
	);

	foreach ( $keys as $key ) {
		if ( in_array( $key, array( 'noticia', 'noticias', 'news' ), true ) ) {
			return true;
		}

		/* Covers the actual vertical newsroom naming convention without turning
		 * broad verticals (games/entretenimento/tecnologia) into NewsArticle. */
		if (
			preg_match( '/^(?:noticia|noticias|news)-(?:de-)?(?:games|jogos|entretenimento|tecnologia|tech)(?:-|$)/', $key ) ||
			preg_match( '/^(?:games|jogos|entretenimento|tecnologia|tech)-(?:de-)?(?:noticia|noticias|news)(?:-|$)/', $key )
		) {
			return true;
		}
	}

	/* A child category of /noticias/ is news even when the child itself has a
	 * topic-only slug. This keeps future newsroom subdivisions automatically
	 * aligned with the parent taxonomy. */
	$ancestors = get_ancestors( (int) $term->term_id, 'category', 'taxonomy' );
	foreach ( (array) $ancestors as $ancestor_id ) {
		$ancestor = get_term( (int) $ancestor_id, 'category' );
		if ( is_wp_error( $ancestor ) || ! ( $ancestor instanceof WP_Term ) ) {
			continue;
		}
		$ancestor_key = go_verge_editorial_term_key( $ancestor->slug );
		$name_key     = go_verge_editorial_term_key( $ancestor->name );
		if ( in_array( $ancestor_key, array( 'noticia', 'noticias', 'news' ), true ) || in_array( $name_key, array( 'noticia', 'noticias', 'news' ), true ) ) {
			return true;
		}
	}

	return false;
}

/**
 * True for posts explicitly classified as timely news by editorial signals.
 *
 * @param int|WP_Post $post Post ID/object.
 * @return bool
 */
function go_verge_post_is_news_article( $post, $respect_override = true ) {
	$post = get_post( $post );
	if ( ! $post || 'post' !== $post->post_type ) {
		return false;
	}

	/*
	 * The explicit editor decision is the strongest semantic signal.  This is
	 * intentionally checked before the V7 editorial format: a timely final
	 * explained, special or service story may be genuine news even though its
	 * newsroom format is not literally `noticia`.  Conversely, an editor may
	 * deliberately keep a story as Article/BlogPosting.  The old order ignored
	 * this selector for News sitemap eligibility, so the UI and output could
	 * disagree.
	 */
	if ( $respect_override && function_exists( 'go_verge_article_schema_type_override' ) ) {
		$override = go_verge_article_schema_type_override( $post->ID );
		if ( 'NewsArticle' === $override ) {
			return true;
		}
		if ( in_array( $override, array( 'Article', 'BlogPosting' ), true ) ) {
			return false;
		}
	}

	if ( function_exists( 'go_verge_v7_post_content_type' ) ) {
		$type = go_verge_v7_post_content_type( $post->ID );
		if ( '' !== $type ) {
			return 'noticia' === $type;
		}
	}

	/* A malformed/ambiguous explicit classification must not fall back to news.
	 * get_the_terms uses the object-term cache already primed for story lists. */
	$types = get_the_terms( $post->ID, 'go_content_type' );
	if ( is_wp_error( $types ) || ( is_array( $types ) && $types ) ) { return false; }

	$terms = get_the_category( $post->ID );
	/* Known specialist legacy categories remain non-news even if a stale
	 * Notícias parent/category is also assigned. Broad desks prove no format. */
	if ( function_exists( 'go_verge_v7_default_type_for_categories' ) ) {
		$slugs = wp_list_pluck( (array) $terms, 'slug' );
		foreach ( (array) $terms as $term ) {
			foreach ( (array) get_ancestors( $term->term_id, 'category', 'taxonomy' ) as $ancestor_id ) {
				$ancestor = get_term( $ancestor_id, 'category' );
				if ( $ancestor instanceof WP_Term ) { $slugs[] = $ancestor->slug; }
			}
		}
		$fallback_type = go_verge_v7_default_type_for_categories( $slugs );
		if ( '' !== $fallback_type && 'noticia' !== $fallback_type ) { return false; }
	}
	foreach ( (array) $terms as $term ) {
		if ( go_verge_category_is_news_term( $term ) ) {
			return true;
		}
	}

	return false;
}

/** Post meta holding an editor's explicit schema type decision. */
const GO_VERGE_SCHEMA_TYPE_META = '_go_schema_article_type';

/**
 * Schema types an editor may select, and what each one means editorially.
 *
 * Deliberately small: this selector controls only the Article subtype. Review
 * markup is generated separately when a scored review/critique has valid data.
 *
 * @return array<string,string>
 */
function go_verge_article_schema_type_choices() {
	return array(
		''            => __( 'Automático (recomendado)', 'go-verge' ),
		'NewsArticle' => __( 'NewsArticle — cobertura noticiosa', 'go-verge' ),
		'Article'     => __( 'Article — conteúdo editorial geral', 'go-verge' ),
		'BlogPosting' => __( 'BlogPosting — coluna, opinião, bastidores', 'go-verge' ),
	);
}

/**
 * The editor's stored choice, or an empty string when it is "automatic".
 *
 * @param int $post_id Post ID.
 * @return string
 */
function go_verge_article_schema_type_override( $post_id ) {
	$value = (string) get_post_meta( absint( $post_id ), GO_VERGE_SCHEMA_TYPE_META, true );
	$valid = go_verge_article_schema_type_choices();
	unset( $valid[''] );

	return isset( $valid[ $value ] ) ? $value : '';
}

/**
 * Whether this post can legitimately carry a Review entity.
 *
 * Review is the one selectable type with mandatory properties: Google needs a
 * rating and an `itemReviewed` of a type it supports. A scored game review
 * always qualifies; a critique qualifies only when its work type maps to Movie
 * or TVSeries. Anything else would publish an entity Search Console rejects, so
 * the selection silently falls back to the automatic type instead.
 *
 * @param int $post_id Post ID.
 * @return bool
 */
function go_verge_article_review_schema_available( $post_id ) {
	if ( ! function_exists( 'go_verge_review_data' ) ) {
		return false;
	}
	$data = go_verge_review_data( absint( $post_id ) );
	if ( empty( $data['has_review'] ) || ! isset( $data['score'] ) || null === $data['score'] || ! is_numeric( $data['score'] ) ) {
		return false;
	}
	if ( empty( $data['is_critique'] ) ) {
		return true;
	}

	return in_array( (string) ( $data['work_type'] ?? '' ), array( 'filme', 'documentario', 'serie', 'anime' ), true );
}

/**
 * The Google-supported Article subtype implied by the editorial taxonomy.
 *
 * Google currently documents Article, NewsArticle and BlogPosting for the
 * Article rich-result feature.  Overdrive is a publication rather than a
 * personal blog, so automatic classification deliberately uses NewsArticle
 * only for real newsroom stories and Article for the remaining editorial
 * formats.  More specific formats (Review, Lista, Final explicado, etc.) are
 * expressed through dedicated nodes/properties instead of inventing an
 * unsupported Article subtype.
 */
function go_verge_article_schema_type_auto( $post ) {
	$post = get_post( $post );
	if ( ! $post || 'post' !== $post->post_type ) {
		return 'Article';
	}

	if ( function_exists( 'go_verge_v7_post_content_type' ) ) {
		$content_type = go_verge_v7_post_content_type( $post->ID );
		if ( '' !== $content_type ) {
			return 'noticia' === $content_type ? 'NewsArticle' : 'Article';
		}
	}

	return go_verge_post_is_news_article( $post, false ) ? 'NewsArticle' : 'Article';
}

/**
 * The schema.org Article type for a post: editorial taxonomy by default, with
 * an explicit editor override when one is selected.
 *
 * Review is intentionally NOT mixed into the Article @type. Google documents
 * Article and Review as distinct structured-data features with different
 * properties, so a scored review keeps its Article/NewsArticle identity and a
 * separate Review entity carries reviewRating + itemReviewed.
 *
 * @param int|WP_Post $post Post ID or object.
 * @return string
 */
function go_verge_article_schema_type( $post ) {
	$post = get_post( $post );
	if ( ! $post || 'post' !== $post->post_type ) {
		return 'Article';
	}

	/*
	 * A deliberate editor choice must win.  The V7 architecture previously
	 * deleted/ignored this value, which made the Schema selector look functional
	 * while every non-news content type still rendered as generic Article.
	 */
	$override = go_verge_article_schema_type_override( $post->ID );
	if ( '' !== $override ) {
		return $override;
	}

	/**
	 * Automatic schema type before any override is considered.
	 *
	 * @param string  $type Resolved type.
	 * @param WP_Post $post Post object.
	 */
	return (string) apply_filters( 'go_verge_article_schema_type_auto', go_verge_article_schema_type_auto( $post ), $post );
}

/**
 * Back-compat shim for older integrations. Review is now always its own node.
 *
 * @param mixed $type Resolved article type.
 * @return bool
 */
function go_verge_article_type_carries_review( $type ) {
	return false;
}

/* -------------------------------------------------------------------------
 * Editorial control
 * ---------------------------------------------------------------------- */

/** Expose the decision to the block editor and the REST API. */
function go_verge_register_schema_type_meta() {
	register_post_meta(
		'post',
		GO_VERGE_SCHEMA_TYPE_META,
		array(
			'type'              => 'string',
			'single'            => true,
			'show_in_rest'      => true,
			'default'           => '',
			'sanitize_callback' => 'go_verge_sanitize_schema_type',
			'auth_callback'     => static function () {
				return current_user_can( 'edit_posts' );
			},
		)
	);
}
add_action( 'init', 'go_verge_register_schema_type_meta', 8 );

/** Only a value from the published vocabulary is storable. */
function go_verge_sanitize_schema_type( $value ) {
	$value = sanitize_text_field( (string) $value );
	$valid = go_verge_article_schema_type_choices();

	return isset( $valid[ $value ] ) ? $value : '';
}

/** Compact classic/Gutenberg side panel next to the other editorial controls. */
function go_verge_register_schema_type_metabox() {
	add_meta_box(
		'go-verge-schema-type',
		__( 'Tipo de Schema', 'go-verge' ),
		'go_verge_render_schema_type_metabox',
		'post',
		'side',
		'default'
	);
}
add_action( 'add_meta_boxes_post', 'go_verge_register_schema_type_metabox', 24 );

/**
 * Render the selector plus the type that would be used automatically, so the
 * editor can see what they are overriding before they override it.
 *
 * @param WP_Post $post Post being edited.
 */
function go_verge_render_schema_type_metabox( $post ) {
	wp_nonce_field( 'go_verge_schema_type_save', 'go_verge_schema_type_nonce' );

	$current = go_verge_article_schema_type_override( $post->ID );
	$auto    = go_verge_article_schema_type_auto( $post );
	?>
	<p>
		<label for="go-verge-schema-type" class="screen-reader-text"><?php esc_html_e( 'Tipo de Schema', 'go-verge' ); ?></label>
		<select name="go_verge_schema_type" id="go-verge-schema-type" style="width:100%">
			<?php foreach ( go_verge_article_schema_type_choices() as $value => $label ) : ?>
				<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $current, $value ); ?>>
					<?php echo esc_html( $label ); ?>
				</option>
			<?php endforeach; ?>
		</select>
	</p>
	<p class="description">
		<?php
		printf(
			/* translators: %s: effective automatic Article subtype. */
			esc_html__( 'No automático, esta matéria usa %s conforme o Tipo de matéria.', 'go-verge' ),
			'<code>' . esc_html( $auto ) . '</code>'
		);
		?>
	</p>
	<p class="description">
		<?php esc_html_e( 'O seletor controla o tipo-base do artigo. Se você escolher NewsArticle, a matéria também poderá entrar no news-sitemap.xml durante a janela de 48 horas, desde que esteja publicada e indexável. Use NewsArticle somente quando houver cobertura noticiosa real e atual — inclusive em Final explicado ou Especial quando a pauta estiver ligada a um acontecimento recente. Guias evergreen, listas atemporais e conteúdo de serviço continuam como Article.', 'go-verge' ); ?>
	</p>
	<?php
}

/** Persist the editor's decision. */
function go_verge_save_schema_type( $post_id ) {
	if ( ! isset( $_POST['go_verge_schema_type_nonce'] ) ) {
		return;
	}
	$nonce = sanitize_text_field( wp_unslash( $_POST['go_verge_schema_type_nonce'] ) );
	if ( ! wp_verify_nonce( $nonce, 'go_verge_schema_type_save' ) ) {
		return;
	}
	if ( ! current_user_can( 'edit_post', $post_id ) || wp_is_post_revision( $post_id ) || wp_is_post_autosave( $post_id ) ) {
		return;
	}

	$value = isset( $_POST['go_verge_schema_type'] )
		? go_verge_sanitize_schema_type( wp_unslash( $_POST['go_verge_schema_type'] ) )
		: '';

	if ( '' === $value ) {
		delete_post_meta( $post_id, GO_VERGE_SCHEMA_TYPE_META );
		return;
	}

	update_post_meta( $post_id, GO_VERGE_SCHEMA_TYPE_META, $value );
}
add_action( 'save_post_post', 'go_verge_save_schema_type', 30 );
