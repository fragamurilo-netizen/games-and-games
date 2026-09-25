<?php
/**
 * Curated "Em alta" strip with automatic popularity fallback.
 *
 * Editors can define from zero to ten visible entries in Appearance > EM ALTA.
 * Every position may use a custom keyword/label, a specific post and/or a
 * custom URL. Custom URLs take precedence over the selected post. Empty slots
 * are filled with the site's most-read stories from the current local day,
 * then with broader popularity and recency fallbacks.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Option that stores the curated entries. */
function go_verge_em_alta_option_name() {
	return 'go_verge_em_alta_post_ids';
}

/** Option that stores how many entries are visible. */
function go_verge_em_alta_visible_count_option_name() {
	return 'go_verge_em_alta_visible_count';
}

/** Maximum number of editable/visible entries. */
function go_verge_em_alta_max_items() {
	return 10;
}

/**
 * Default slot structure.
 *
 * @return array<string,mixed>
 */
function go_verge_em_alta_default_item() {
	return array(
		'post_id' => 0,
		'label'   => '',
		'url'     => '',
	);
}

/**
 * Sanitize visible-item count.
 *
 * @param mixed $value Raw setting value.
 * @return int
 */
function go_verge_sanitize_em_alta_visible_count( $value ) {
	return min( go_verge_em_alta_max_items(), max( 0, absint( $value ) ) );
}

/**
 * Return the configured number of visible entries.
 *
 * @return int
 */
function go_verge_get_em_alta_visible_count() {
	return go_verge_sanitize_em_alta_visible_count(
		get_option( go_verge_em_alta_visible_count_option_name(), 5 )
	);
}

/**
 * Validate the curated entries.
 *
 * Supports the old numeric-only format and the structured format.
 *
 * @param mixed $value Raw setting value.
 * @return array<int,array<string,mixed>>
 */
function go_verge_sanitize_em_alta_post_ids( $value ) {
	$items  = array();
	$values = is_array( $value ) ? array_values( $value ) : array();
	$max    = go_verge_em_alta_max_items();

	foreach ( array_slice( $values, 0, $max ) as $candidate ) {
		$slot = go_verge_em_alta_default_item();

		if ( is_array( $candidate ) ) {
			$post_id = isset( $candidate['post_id'] ) ? absint( $candidate['post_id'] ) : 0;
			$label   = isset( $candidate['label'] ) ? sanitize_text_field( wp_unslash( (string) $candidate['label'] ) ) : '';
			$url     = isset( $candidate['url'] ) ? esc_url_raw( wp_unslash( (string) $candidate['url'] ) ) : '';
		} else {
			$post_id = absint( $candidate );
			$label   = '';
			$url     = '';
		}

		if ( $post_id && ( 'post' !== get_post_type( $post_id ) || 'publish' !== get_post_status( $post_id ) ) ) {
			$post_id = 0;
		}

		$slot['post_id'] = $post_id;
		$slot['label']   = $label;
		$slot['url']     = $url;
		$items[]         = $slot;
	}

	return array_pad( array_slice( $items, 0, $max ), $max, go_verge_em_alta_default_item() );
}

/** Register the curated links setting. */
function go_verge_register_em_alta_setting() {
	register_setting(
		'go_verge_em_alta',
		go_verge_em_alta_option_name(),
		array(
			'type'              => 'array',
			'default'           => array_fill( 0, go_verge_em_alta_max_items(), go_verge_em_alta_default_item() ),
			'sanitize_callback' => 'go_verge_sanitize_em_alta_post_ids',
		)
	);

	register_setting(
		'go_verge_em_alta',
		go_verge_em_alta_visible_count_option_name(),
		array(
			'type'              => 'integer',
			'default'           => 5,
			'sanitize_callback' => 'go_verge_sanitize_em_alta_visible_count',
		)
	);
}
add_action( 'admin_init', 'go_verge_register_em_alta_setting' );

/** Add the selector under Appearance. */
function go_verge_register_em_alta_admin_page() {
	add_theme_page(
		__( 'EM ALTA', 'go-verge' ),
		__( 'EM ALTA', 'go-verge' ),
		'edit_theme_options',
		'go-verge-em-alta',
		'go_verge_render_em_alta_admin_page'
	);
}
add_action( 'admin_menu', 'go_verge_register_em_alta_admin_page' );

/**
 * Normalized entries saved for the strip.
 *
 * @return array<int,array<string,mixed>>
 */
function go_verge_get_curated_trending_entries() {
	return go_verge_sanitize_em_alta_post_ids( get_option( go_verge_em_alta_option_name(), array() ) );
}

/** Render the editor UI. */
function go_verge_render_em_alta_admin_page() {
	if ( ! current_user_can( 'edit_theme_options' ) ) {
		return;
	}

	$selected     = go_verge_get_curated_trending_entries();
	$visible_count = go_verge_get_em_alta_visible_count();
	$recent       = get_posts(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 500,
			'orderby'             => 'date',
			'order'               => 'DESC',
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
		)
	);

	$posts_by_id = array();
	foreach ( $recent as $post ) {
		$posts_by_id[ (int) $post->ID ] = $post;
	}
	foreach ( $selected as $entry ) {
		$post_id = isset( $entry['post_id'] ) ? absint( $entry['post_id'] ) : 0;
		if ( $post_id && ! isset( $posts_by_id[ $post_id ] ) ) {
			$post = get_post( $post_id );
			if ( $post instanceof WP_Post && 'publish' === $post->post_status && 'post' === $post->post_type ) {
				$posts_by_id[ $post_id ] = $post;
			}
		}
	}
	?>
	<div class="wrap go-em-alta-admin">
		<h1><?php esc_html_e( 'EM ALTA', 'go-verge' ); ?></h1>

		<form method="post" action="options.php">
			<?php settings_fields( 'go_verge_em_alta' ); ?>

			<section class="go-em-alta-admin__visibility">
				<label for="go-em-alta-visible-count"><strong><?php esc_html_e( 'Quantidade de palavras-chave visíveis', 'go-verge' ); ?></strong></label>
				<select id="go-em-alta-visible-count" name="<?php echo esc_attr( go_verge_em_alta_visible_count_option_name() ); ?>">
					<?php for ( $count = 0; $count <= go_verge_em_alta_max_items(); $count++ ) : ?>
						<option value="<?php echo esc_attr( $count ); ?>" <?php selected( $visible_count, $count ); ?>><?php echo esc_html( $count ); ?></option>
					<?php endfor; ?>
				</select>
			</section>

			<div class="go-em-alta-admin__grid">
				<?php for ( $slot = 0; $slot < go_verge_em_alta_max_items(); $slot++ ) : ?>
					<?php
					$label_value = isset( $selected[ $slot ]['label'] ) ? (string) $selected[ $slot ]['label'] : '';
					$post_value  = isset( $selected[ $slot ]['post_id'] ) ? (int) $selected[ $slot ]['post_id'] : 0;
					$url_value   = isset( $selected[ $slot ]['url'] ) ? (string) $selected[ $slot ]['url'] : '';
					?>
					<section class="go-em-alta-admin__slot" data-go-em-alta-slot="<?php echo esc_attr( $slot + 1 ); ?>">
						<h2><?php echo esc_html( sprintf( __( 'Link %d', 'go-verge' ), $slot + 1 ) ); ?></h2>
						<label class="go-em-alta-admin__field">
							<span><?php esc_html_e( 'Palavra-chave', 'go-verge' ); ?></span>
							<input type="text" class="widefat" name="<?php echo esc_attr( go_verge_em_alta_option_name() ); ?>[<?php echo esc_attr( $slot ); ?>][label]" value="<?php echo esc_attr( $label_value ); ?>" maxlength="60" placeholder="<?php esc_attr_e( 'Ex.: GTA 6', 'go-verge' ); ?>">
						</label>
						<label class="go-em-alta-admin__field">
							<span><?php esc_html_e( 'URL específica', 'go-verge' ); ?></span>
							<input type="url" class="widefat" name="<?php echo esc_attr( go_verge_em_alta_option_name() ); ?>[<?php echo esc_attr( $slot ); ?>][url]" value="<?php echo esc_attr( $url_value ); ?>" placeholder="https://">
						</label>
						<label class="go-em-alta-admin__field" for="go-em-alta-search-<?php echo esc_attr( $slot ); ?>">
							<span><?php esc_html_e( 'Matéria vinculada', 'go-verge' ); ?></span>
							<input type="search" id="go-em-alta-search-<?php echo esc_attr( $slot ); ?>" class="widefat go-em-alta-admin__search" data-go-em-alta-search="<?php echo esc_attr( $slot ); ?>" placeholder="<?php esc_attr_e( 'Buscar matéria', 'go-verge' ); ?>" autocomplete="off">
						</label>
						<select id="go-em-alta-select-<?php echo esc_attr( $slot ); ?>" class="widefat go-em-alta-admin__select" data-go-em-alta-select="<?php echo esc_attr( $slot ); ?>" name="<?php echo esc_attr( go_verge_em_alta_option_name() ); ?>[<?php echo esc_attr( $slot ); ?>][post_id]" size="7">
							<option value="0" <?php selected( 0, $post_value ); ?>><?php esc_html_e( 'Automático — mais lida do dia', 'go-verge' ); ?></option>
							<?php foreach ( $posts_by_id as $post_id => $post ) : ?>
								<option value="<?php echo esc_attr( $post_id ); ?>" <?php selected( $post_value, (int) $post_id ); ?>><?php echo esc_html( get_the_date( 'd/m/Y', $post_id ) . ' — ' . get_the_title( $post_id ) ); ?></option>
							<?php endforeach; ?>
						</select>
					</section>
				<?php endfor; ?>
			</div>
			<?php submit_button( __( 'Salvar EM ALTA', 'go-verge' ) ); ?>
		</form>
	</div>
	<style>
		.go-em-alta-admin{max-width:1160px}.go-em-alta-admin__visibility{display:flex;align-items:center;gap:12px;margin-top:22px;padding:16px 18px;border:1px solid #c3c4c7;border-radius:10px;background:#fff}.go-em-alta-admin__visibility select{min-width:84px}.go-em-alta-admin__grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;margin-top:18px}.go-em-alta-admin__slot{padding:18px;border:1px solid #c3c4c7;border-radius:10px;background:#fff}.go-em-alta-admin__slot.is-inactive{opacity:.52}.go-em-alta-admin__slot h2{margin:0 0 14px;font-size:16px}.go-em-alta-admin__field{display:block;margin-bottom:12px}.go-em-alta-admin__field span{display:block;margin:0 0 6px;font-weight:600}.go-em-alta-admin__search{margin:0}.go-em-alta-admin__select{min-height:192px}@media(max-width:900px){.go-em-alta-admin__grid{grid-template-columns:1fr}}
	</style>
	<script>
	(function(){
		var countSelect=document.getElementById('go-em-alta-visible-count');
		var slots=Array.prototype.slice.call(document.querySelectorAll('[data-go-em-alta-slot]'));
		function updateVisibleSlots(){
			var count=countSelect?parseInt(countSelect.value,10):5;
			slots.forEach(function(slot){
				var position=parseInt(slot.getAttribute('data-go-em-alta-slot'),10);
				slot.classList.toggle('is-inactive',position>count);
			});
		}
		if(countSelect){countSelect.addEventListener('change',updateVisibleSlots);updateVisibleSlots();}

		document.querySelectorAll('[data-go-em-alta-search]').forEach(function(input){
			var slot=input.getAttribute('data-go-em-alta-search');
			var select=document.querySelector('[data-go-em-alta-select="'+slot+'"]');
			if(!select){return;}
			var options=Array.prototype.slice.call(select.options);
			input.addEventListener('input',function(){
				var term=input.value.trim().toLocaleLowerCase('pt-BR');
				options.forEach(function(option,index){
					option.hidden=index>0&&term&&option.textContent.toLocaleLowerCase('pt-BR').indexOf(term)===-1&&option.value!==select.value;
				});
			});
		});
	})();
	</script>
	<?php
}

/**
 * Return the manually curated IDs in their editorial order.
 *
 * @return int[]
 */
function go_verge_get_curated_trending_post_ids() {
	$ids = array();
	foreach ( array_slice( go_verge_get_curated_trending_entries(), 0, go_verge_get_em_alta_visible_count() ) as $entry ) {
		$post_id = isset( $entry['post_id'] ) ? absint( $entry['post_id'] ) : 0;
		if ( $post_id && ! in_array( $post_id, $ids, true ) ) {
			$ids[] = $post_id;
		}
	}
	return $ids;
}

/**
 * Produce a fallback label for an external URL.
 *
 * @param string $url URL.
 * @return string
 */
function go_verge_em_alta_url_fallback_label( $url ) {
	$host = wp_parse_url( $url, PHP_URL_HOST );
	if ( is_string( $host ) && '' !== $host ) {
		return preg_replace( '/^www\./i', '', $host );
	}
	return __( 'Em alta', 'go-verge' );
}

/**
 * Return the curated/most-read entries used by the header strip.
 *
 * @param int   $limit   Maximum number of entries.
 * @param array $exclude Post IDs that must not be returned.
 * @return array<int,array<string,mixed>>
 */
function go_verge_get_trending_items( $limit = 0, $exclude = array() ) {
	$configured_limit = go_verge_get_em_alta_visible_count();
	$limit            = $limit > 0 ? min( absint( $limit ), $configured_limit ) : $configured_limit;
	$exclude          = array_values( array_unique( array_filter( array_map( 'absint', (array) $exclude ) ) ) );

	if ( $limit < 1 ) {
		return array();
	}

	$entries = array_slice( go_verge_get_curated_trending_entries(), 0, $limit );
	$items   = array_fill( 0, $limit, null );
	$used    = array();

	foreach ( $entries as $index => $entry ) {
		$post_id    = isset( $entry['post_id'] ) ? absint( $entry['post_id'] ) : 0;
		$custom_url = isset( $entry['url'] ) ? esc_url_raw( (string) $entry['url'] ) : '';
		$label      = isset( $entry['label'] ) ? trim( (string) $entry['label'] ) : '';

		if ( $post_id && in_array( $post_id, $exclude, true ) ) {
			$post_id = 0;
		}

		if ( $custom_url ) {
			if ( $post_id && ! in_array( $post_id, $used, true ) ) {
				$used[] = $post_id;
			}
			$items[ $index ] = array(
				'post_id' => $post_id,
				'label'   => $label ?: ( $post_id ? get_the_title( $post_id ) : go_verge_em_alta_url_fallback_label( $custom_url ) ),
				'url'     => $custom_url,
				'is_auto' => false,
			);
			continue;
		}

		if ( $post_id && ! in_array( $post_id, $used, true ) ) {
			$used[] = $post_id;
			$items[ $index ] = array(
				'post_id' => $post_id,
				'label'   => $label ?: get_the_title( $post_id ),
				'url'     => get_permalink( $post_id ),
				'is_auto' => false,
			);
		}
	}

	/* The tracker works with rolling hours. Restrict that window to the hours
	 * elapsed since midnight in the WordPress timezone. */
	$now           = current_datetime();
	$midnight      = ( clone $now )->setTime( 0, 0, 0 );
	$hours         = max( 1, (int) ceil( ( $now->getTimestamp() - $midnight->getTimestamp() ) / HOUR_IN_SECONDS ) );
	$candidate_ids = array();

	if ( function_exists( 'go_product_get_popular_ids' ) ) {
		$candidate_ids = array_merge(
			$candidate_ids,
			(array) go_product_get_popular_ids( $hours, max( 30, $limit * 15 ), array( 'post' ) )
		);
	}

	if ( count( $candidate_ids ) < $limit && function_exists( 'go_verge_global_popular_posts' ) ) {
		$fallback_posts = go_verge_global_popular_posts( array_values( array_unique( array_merge( $exclude, $used ) ) ), $limit * 2 );
		foreach ( (array) $fallback_posts as $fallback_post ) {
			$candidate_ids[] = $fallback_post instanceof WP_Post ? (int) $fallback_post->ID : absint( $fallback_post );
		}
	}

	if ( count( $candidate_ids ) < $limit * 2 ) {
		$recent = get_posts(
			array(
				'post_type'           => 'post',
				'post_status'         => 'publish',
				'posts_per_page'      => $limit * 2,
				'fields'              => 'ids',
				'ignore_sticky_posts' => true,
				'no_found_rows'       => true,
				'post__not_in'        => array_values( array_unique( array_merge( $exclude, $used ) ) ),
				'orderby'             => 'date',
				'order'               => 'DESC',
			)
		);
		$candidate_ids = array_merge( $candidate_ids, array_map( 'absint', (array) $recent ) );
	}

	$candidate_ids = array_values( array_unique( array_filter( array_map( 'absint', $candidate_ids ) ) ) );
	$candidate_pos = 0;

	foreach ( $items as $index => $item ) {
		if ( null !== $item ) {
			continue;
		}

		while ( isset( $candidate_ids[ $candidate_pos ] ) ) {
			$candidate_id = absint( $candidate_ids[ $candidate_pos ] );
			$candidate_pos++;

			if ( ! $candidate_id || in_array( $candidate_id, $exclude, true ) || in_array( $candidate_id, $used, true ) ) {
				continue;
			}
			if ( 'post' !== get_post_type( $candidate_id ) || 'publish' !== get_post_status( $candidate_id ) ) {
				continue;
			}

			$entry_label = isset( $entries[ $index ]['label'] ) ? trim( (string) $entries[ $index ]['label'] ) : '';
			$items[ $index ] = array(
				'post_id' => $candidate_id,
				'label'   => $entry_label ?: get_the_title( $candidate_id ),
				'url'     => get_permalink( $candidate_id ),
				'is_auto' => true,
			);
			$used[] = $candidate_id;
			break;
		}
	}

	return array_values( array_filter( $items ) );
}

/**
 * Return the curated/most-read post IDs used by the header strip.
 *
 * @param int   $limit   Maximum number of posts.
 * @param array $exclude Post IDs that must not be returned.
 * @return int[]
 */
function go_verge_get_trending_post_ids( $limit = 0, $exclude = array() ) {
	$items = go_verge_get_trending_items( $limit, $exclude );
	$ids   = array();
	foreach ( $items as $item ) {
		$post_id = isset( $item['post_id'] ) ? absint( $item['post_id'] ) : 0;
		if ( $post_id && ! in_array( $post_id, $ids, true ) ) {
			$ids[] = $post_id;
		}
	}
	return $ids;
}

