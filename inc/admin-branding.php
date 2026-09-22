<?php
/**
 * Overdrive wp-admin brand palette.
 *
 * Applies a restrained Overdrive treatment to the WordPress chrome while
 * keeping plugin interfaces readable. Administrators can change or disable
 * the palette in Appearance > Cores do painel.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/** Option key for the site-wide admin palette. */
function go_verge_admin_branding_option_key() {
	return 'go_verge_admin_branding_v1';
}

/** Default palette mirrors the public Overdrive identity. */
function go_verge_admin_branding_defaults() {
	return array(
		'enabled'    => 1,
		'login'      => 1,
		'accent'     => '#421aff',
		'nav_bg'     => '#17151c',
		'page_bg'    => '#f4f3f7',
		'surface'    => '#ffffff',
		'text'       => '#17151c',
		'muted'      => '#65616d',
	);
}

/** Read and sanitize the stored palette without trusting old option values. */
function go_verge_admin_branding_get_options() {
	$defaults = go_verge_admin_branding_defaults();
	$stored   = get_option( go_verge_admin_branding_option_key(), array() );
	$stored   = is_array( $stored ) ? $stored : array();
	$options  = wp_parse_args( $stored, $defaults );

	foreach ( array( 'accent', 'nav_bg', 'page_bg', 'surface', 'text', 'muted' ) as $key ) {
		$hex = sanitize_hex_color( (string) $options[ $key ] );
		$options[ $key ] = $hex ? $hex : $defaults[ $key ];
	}
	$options['enabled'] = empty( $options['enabled'] ) ? 0 : 1;
	$options['login']   = empty( $options['login'] ) ? 0 : 1;

	return $options;
}

/** Convert a six-digit hex color into an RGB tuple. */
function go_verge_admin_branding_rgb( $hex ) {
	$hex = ltrim( (string) $hex, '#' );
	if ( 3 === strlen( $hex ) ) {
		$hex = $hex[0] . $hex[0] . $hex[1] . $hex[1] . $hex[2] . $hex[2];
	}
	if ( 6 !== strlen( $hex ) || ! ctype_xdigit( $hex ) ) {
		return array( 0, 0, 0 );
	}
	return array( hexdec( substr( $hex, 0, 2 ) ), hexdec( substr( $hex, 2, 2 ) ), hexdec( substr( $hex, 4, 2 ) ) );
}

/** Mix two colors. $weight is the amount of the first color (0..1). */
function go_verge_admin_branding_mix( $first, $second, $weight ) {
	$a = go_verge_admin_branding_rgb( $first );
	$b = go_verge_admin_branding_rgb( $second );
	$w = max( 0, min( 1, (float) $weight ) );
	$r = (int) round( $a[0] * $w + $b[0] * ( 1 - $w ) );
	$g = (int) round( $a[1] * $w + $b[1] * ( 1 - $w ) );
	$bl = (int) round( $a[2] * $w + $b[2] * ( 1 - $w ) );
	return sprintf( '#%02x%02x%02x', $r, $g, $bl );
}

/** WCAG relative luminance. */
function go_verge_admin_branding_luminance( $hex ) {
	$rgb = go_verge_admin_branding_rgb( $hex );
	$channels = array();
	foreach ( $rgb as $channel ) {
		$value = $channel / 255;
		$channels[] = $value <= 0.03928 ? $value / 12.92 : pow( ( $value + 0.055 ) / 1.055, 2.4 );
	}
	return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2];
}

/** Choose black or white according to the stronger contrast ratio. */
function go_verge_admin_branding_contrast( $background ) {
	$luminance = go_verge_admin_branding_luminance( $background );
	$white     = 1.05 / ( $luminance + 0.05 );
	$black     = ( $luminance + 0.05 ) / 0.05;
	return $white >= $black ? '#ffffff' : '#111111';
}

/** Derived colors shared by the admin chrome and Posts workspace. */
function go_verge_admin_branding_tokens() {
	$o            = go_verge_admin_branding_get_options();
	$on_accent    = go_verge_admin_branding_contrast( $o['accent'] );
	$on_nav       = go_verge_admin_branding_contrast( $o['nav_bg'] );
	$accent_hover = go_verge_admin_branding_mix( $o['accent'], '#000000', 0.82 );
	$accent_soft  = go_verge_admin_branding_mix( $o['accent'], $o['surface'], 0.10 );
	$line         = go_verge_admin_branding_mix( $o['text'], $o['surface'], 0.13 );
	$nav_hover    = go_verge_admin_branding_mix( $on_nav, $o['nav_bg'], 0.10 );

	return array_merge(
		$o,
		array(
			'on_accent'    => $on_accent,
			'on_nav'       => $on_nav,
			'accent_hover' => $accent_hover,
			'accent_soft'  => $accent_soft,
			'line'         => $line,
			'nav_hover'    => $nav_hover,
		)
	);
}

/** Add a body class only when the brand palette is active. */
function go_verge_admin_branding_body_class( $classes ) {
	$options = go_verge_admin_branding_get_options();
	if ( ! empty( $options['enabled'] ) ) {
		$classes .= ' go-admin-branding';
	}
	return $classes;
}
add_filter( 'admin_body_class', 'go_verge_admin_branding_body_class', 20 );

/** Global wp-admin CSS. Intentionally targets the chrome/core primitives only. */
function go_verge_admin_branding_css() {
	$t = go_verge_admin_branding_tokens();
	if ( empty( $t['enabled'] ) ) {
		return;
	}
	?>
	<style id="go-admin-branding-css">
	:root{
		--go-admin-accent:<?php echo esc_html( $t['accent'] ); ?>;
		--go-admin-accent-hover:<?php echo esc_html( $t['accent_hover'] ); ?>;
		--go-admin-on-accent:<?php echo esc_html( $t['on_accent'] ); ?>;
		--go-admin-accent-soft:<?php echo esc_html( $t['accent_soft'] ); ?>;
		--go-admin-nav:<?php echo esc_html( $t['nav_bg'] ); ?>;
		--go-admin-on-nav:<?php echo esc_html( $t['on_nav'] ); ?>;
		--go-admin-nav-hover:<?php echo esc_html( $t['nav_hover'] ); ?>;
		--go-admin-page:<?php echo esc_html( $t['page_bg'] ); ?>;
		--go-admin-surface:<?php echo esc_html( $t['surface'] ); ?>;
		--go-admin-ink:<?php echo esc_html( $t['text'] ); ?>;
		--go-admin-muted:<?php echo esc_html( $t['muted'] ); ?>;
		--go-admin-line:<?php echo esc_html( $t['line'] ); ?>;
	}
	body.go-admin-branding{
		--wp-admin-theme-color:var(--go-admin-accent);
		--wp-admin-theme-color-darker-10:var(--go-admin-accent-hover);
		--wp-admin-theme-color-darker-20:var(--go-admin-accent-hover);
		background:var(--go-admin-page);
		color:var(--go-admin-ink);
	}
	body.go-admin-branding #wpcontent,
	body.go-admin-branding #wpfooter{background:var(--go-admin-page)}
	body.go-admin-branding #wpbody-content{color:var(--go-admin-ink)}
	body.go-admin-branding .wrap>h1,
	body.go-admin-branding .wrap>h2:first-child{color:var(--go-admin-ink)}

	/* Left navigation + top toolbar. */
	body.go-admin-branding #adminmenuback,
	body.go-admin-branding #adminmenuwrap,
	body.go-admin-branding #adminmenu{background:var(--go-admin-nav)}
	body.go-admin-branding #adminmenu a,
	body.go-admin-branding #adminmenu div.wp-menu-image:before,
	body.go-admin-branding #collapse-button{color:var(--go-admin-on-nav)}
	body.go-admin-branding #adminmenu li.menu-top:hover,
	body.go-admin-branding #adminmenu li.opensub>a.menu-top,
	body.go-admin-branding #adminmenu li>a.menu-top:focus,
	body.go-admin-branding #collapse-menu:hover{background:var(--go-admin-nav-hover);color:var(--go-admin-on-nav)}
	body.go-admin-branding #adminmenu .wp-has-current-submenu>a.menu-top,
	body.go-admin-branding #adminmenu .wp-menu-open>a.menu-top,
	body.go-admin-branding #adminmenu li.current>a.menu-top{background:var(--go-admin-accent);color:var(--go-admin-on-accent)}
	body.go-admin-branding #adminmenu .wp-has-current-submenu>a.menu-top .wp-menu-image:before,
	body.go-admin-branding #adminmenu .wp-menu-open>a.menu-top .wp-menu-image:before,
	body.go-admin-branding #adminmenu li.current>a.menu-top .wp-menu-image:before{color:var(--go-admin-on-accent)}
	body.go-admin-branding #adminmenu .wp-submenu{background:var(--go-admin-nav)}
	body.go-admin-branding #adminmenu .wp-submenu a{color:var(--go-admin-on-nav)}
	body.go-admin-branding #adminmenu .wp-submenu a:hover,
	body.go-admin-branding #adminmenu .wp-submenu a:focus{background:var(--go-admin-nav-hover);color:var(--go-admin-on-nav)}
	body.go-admin-branding #adminmenu .wp-submenu .current a{color:var(--go-admin-on-nav);font-weight:700}
	body.go-admin-branding #adminmenu li.wp-menu-separator{border-top:1px solid var(--go-admin-nav-hover)}
	body.go-admin-branding #wpadminbar{background:var(--go-admin-nav);color:var(--go-admin-on-nav)}
	body.go-admin-branding #wpadminbar .ab-item,
	body.go-admin-branding #wpadminbar a.ab-item,
	body.go-admin-branding #wpadminbar>#wp-toolbar span.ab-label,
	body.go-admin-branding #wpadminbar>#wp-toolbar span.noticon{color:var(--go-admin-on-nav)}
	body.go-admin-branding #wpadminbar .menupop .ab-sub-wrapper,
	body.go-admin-branding #wpadminbar .shortlink-input{background:var(--go-admin-nav)}
	body.go-admin-branding #wpadminbar .ab-top-menu>li.hover>.ab-item,
	body.go-admin-branding #wpadminbar.nojq .quicklinks .ab-top-menu>li>.ab-item:focus,
	body.go-admin-branding #wpadminbar .ab-top-menu>li:hover>.ab-item,
	body.go-admin-branding #wpadminbar .ab-top-menu>li>.ab-item:focus{background:var(--go-admin-nav-hover);color:var(--go-admin-on-nav)}
	body.go-admin-branding #wpadminbar .quicklinks .menupop ul li a:hover,
	body.go-admin-branding #wpadminbar .quicklinks .menupop ul li a:focus{color:var(--go-admin-on-nav)}

	/* Core controls get the accent; plugin-specific semantic colors stay intact. */
	body.go-admin-branding .wp-core-ui .button-primary,
	body.go-admin-branding .wp-core-ui .button-primary:visited,
	body.go-admin-branding .page-title-action{border-color:var(--go-admin-accent);background:var(--go-admin-accent);color:var(--go-admin-on-accent);box-shadow:none}
	body.go-admin-branding .wp-core-ui .button-primary:hover,
	body.go-admin-branding .wp-core-ui .button-primary:focus,
	body.go-admin-branding .page-title-action:hover,
	body.go-admin-branding .page-title-action:focus{border-color:var(--go-admin-accent-hover);background:var(--go-admin-accent-hover);color:var(--go-admin-on-accent)}
	body.go-admin-branding .wp-core-ui .button-secondary:focus,
	body.go-admin-branding .wp-core-ui .button:focus{border-color:var(--go-admin-accent);box-shadow:0 0 0 1px var(--go-admin-accent);outline:2px solid transparent}
	body.go-admin-branding input[type=color]:focus,
	body.go-admin-branding input[type=date]:focus,
	body.go-admin-branding input[type=datetime-local]:focus,
	body.go-admin-branding input[type=datetime]:focus,
	body.go-admin-branding input[type=email]:focus,
	body.go-admin-branding input[type=month]:focus,
	body.go-admin-branding input[type=number]:focus,
	body.go-admin-branding input[type=password]:focus,
	body.go-admin-branding input[type=search]:focus,
	body.go-admin-branding input[type=tel]:focus,
	body.go-admin-branding input[type=text]:focus,
	body.go-admin-branding input[type=time]:focus,
	body.go-admin-branding input[type=url]:focus,
	body.go-admin-branding input[type=week]:focus,
	body.go-admin-branding select:focus,
	body.go-admin-branding textarea:focus{border-color:var(--go-admin-accent);box-shadow:0 0 0 1px var(--go-admin-accent);outline:2px solid transparent}
	body.go-admin-branding input[type=checkbox]:checked::before{filter:none;color:var(--go-admin-accent)}
	body.go-admin-branding input[type=radio]:checked::before{background:var(--go-admin-accent)}
	body.go-admin-branding .nav-tab-active,
	body.go-admin-branding .nav-tab-active:hover{border-bottom-color:var(--go-admin-accent);color:var(--go-admin-ink)}
	body.go-admin-branding .subsubsub a.current{color:var(--go-admin-accent)}
	body.go-admin-branding .notice-info{border-left-color:var(--go-admin-accent)}
	body.go-admin-branding .wp-ui-highlight{background:var(--go-admin-accent);color:var(--go-admin-on-accent)}

	/* Surfaces: small amount of authorship without repainting plugin internals. */
	body.go-admin-branding .postbox,
	body.go-admin-branding .stuffbox,
	body.go-admin-branding .card,
	body.go-admin-branding .welcome-panel,
	body.go-admin-branding .health-check-accordion{border-color:var(--go-admin-line);background:var(--go-admin-surface)}
	body.go-admin-branding .postbox,
	body.go-admin-branding .card,
	body.go-admin-branding .welcome-panel{border-radius:10px}
	body.go-admin-branding .widefat,
	body.go-admin-branding .wp-list-table{border-color:var(--go-admin-line)}
	body.go-admin-branding .widefat thead td,
	body.go-admin-branding .widefat thead th,
	body.go-admin-branding .widefat tfoot td,
	body.go-admin-branding .widefat tfoot th{border-color:var(--go-admin-line)}
	body.go-admin-branding .alternate,
	body.go-admin-branding .striped>tbody>:nth-child(odd),
	body.go-admin-branding ul.striped>:nth-child(odd){background:<?php echo esc_html( go_verge_admin_branding_mix( $t['page_bg'], $t['surface'], 0.48 ) ); ?>}
	body.go-admin-branding .wrap a:not(.button):not(.page-title-action):not(.nav-tab):focus{outline:2px solid var(--go-admin-accent);outline-offset:2px;box-shadow:none}

	@media(max-width:782px){
		body.go-admin-branding.auto-fold #adminmenu a,
		body.go-admin-branding.auto-fold #adminmenu div.wp-menu-image:before{color:var(--go-admin-on-nav)}
	}
	</style>
	<?php
}
add_action( 'admin_head', 'go_verge_admin_branding_css', 5 );

/** Register the palette page under Appearance. */
function go_verge_admin_branding_menu() {
	add_theme_page(
		__( 'Cores do painel Overdrive', 'go-verge' ),
		__( 'Cores do painel', 'go-verge' ),
		'manage_options',
		'go-admin-branding',
		'go_verge_admin_branding_render_page'
	);
}
add_action( 'admin_menu', 'go_verge_admin_branding_menu', 60 );

/** Load the native WordPress color picker only on our settings page. */
function go_verge_admin_branding_assets( $hook ) {
	if ( 'appearance_page_go-admin-branding' !== $hook ) {
		return;
	}
	wp_enqueue_style( 'wp-color-picker' );
	wp_enqueue_script( 'wp-color-picker' );
	$preview_script = <<<'JS'
jQuery(function($){
	$('.go-admin-color-field').wpColorPicker({
		change:function(){setTimeout(goAdminPreview,0);},
		clear:function(){setTimeout(goAdminPreview,0);}
	});
	function goAdminPreview(){
		var root=document.querySelector('.go-admin-palette-preview');
		if(!root)return;
		var read=function(n,d){
			var el=document.querySelector('[name="go_admin_branding['+n+']"]');
			return el&&el.value?el.value:d;
		};
		root.style.setProperty('--p-accent',read('accent','#421aff'));
		root.style.setProperty('--p-nav',read('nav_bg','#17151c'));
		root.style.setProperty('--p-page',read('page_bg','#f4f3f7'));
		root.style.setProperty('--p-surface',read('surface','#ffffff'));
		root.style.setProperty('--p-text',read('text','#17151c'));
	}
	$(document).on('input','.go-admin-color-field',goAdminPreview);
	goAdminPreview();
});
JS;
	wp_add_inline_script( 'wp-color-picker', $preview_script );
}
add_action( 'admin_enqueue_scripts', 'go_verge_admin_branding_assets', 40 );

/** Save/reset handler for the palette. */
function go_verge_admin_branding_save() {
	if ( ! current_user_can( 'manage_options' ) ) {
		wp_die( esc_html__( 'Você não tem permissão para alterar esta configuração.', 'go-verge' ) );
	}
	check_admin_referer( 'go_admin_branding_save' );

	if ( isset( $_POST['go_admin_branding_reset'] ) ) {
		delete_option( go_verge_admin_branding_option_key() );
		wp_safe_redirect( add_query_arg( array( 'page' => 'go-admin-branding', 'reset' => '1' ), admin_url( 'themes.php' ) ) );
		exit;
	}

	$defaults = go_verge_admin_branding_defaults();
	$raw      = isset( $_POST['go_admin_branding'] ) && is_array( $_POST['go_admin_branding'] ) ? wp_unslash( $_POST['go_admin_branding'] ) : array();
	$clean    = $defaults;
	$clean['enabled'] = empty( $raw['enabled'] ) ? 0 : 1;
	$clean['login']   = empty( $raw['login'] ) ? 0 : 1;

	foreach ( array( 'accent', 'nav_bg', 'page_bg', 'surface', 'text', 'muted' ) as $key ) {
		$value = isset( $raw[ $key ] ) ? sanitize_hex_color( (string) $raw[ $key ] ) : '';
		$clean[ $key ] = $value ? $value : $defaults[ $key ];
	}

	update_option( go_verge_admin_branding_option_key(), $clean, false );
	wp_safe_redirect( add_query_arg( array( 'page' => 'go-admin-branding', 'updated' => '1' ), admin_url( 'themes.php' ) ) );
	exit;
}
add_action( 'admin_post_go_verge_admin_branding_save', 'go_verge_admin_branding_save' );

/** Render Appearance > Cores do painel. */
function go_verge_admin_branding_render_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}
	$o = go_verge_admin_branding_get_options();
	$fields = array(
		'accent'  => array( 'Cor principal', 'Botões, item ativo, foco e destaques.' ),
		'nav_bg'  => array( 'Menu e barra superior', 'Fundo da navegação do WordPress.' ),
		'page_bg' => array( 'Fundo do painel', 'Área externa das telas administrativas.' ),
		'surface' => array( 'Cards e superfícies', 'Tabelas, caixas e cartões.' ),
		'text'    => array( 'Texto principal', 'Títulos e conteúdo de alto contraste.' ),
		'muted'   => array( 'Texto secundário', 'Metadados, descrições e informações auxiliares.' ),
	);
	?>
	<div class="wrap go-admin-branding-settings">
		<h1><?php esc_html_e( 'Cores do painel Overdrive', 'go-verge' ); ?></h1>
		<p class="description" style="max-width:760px"><?php esc_html_e( 'A paleta é aplicada ao wp-admin inteiro, incluindo menu lateral, barra superior, botões e superfícies. O contraste de texto sobre a cor principal e sobre o menu é calculado automaticamente.', 'go-verge' ); ?></p>
		<?php if ( isset( $_GET['updated'] ) ) : // phpcs:ignore WordPress.Security.NonceVerification.Recommended ?>
			<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Paleta do painel salva.', 'go-verge' ); ?></p></div>
		<?php elseif ( isset( $_GET['reset'] ) ) : // phpcs:ignore WordPress.Security.NonceVerification.Recommended ?>
			<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Paleta padrão do Overdrive restaurada.', 'go-verge' ); ?></p></div>
		<?php endif; ?>

		<div class="go-admin-branding-grid" style="display:grid;grid-template-columns:minmax(0,620px) minmax(280px,420px);gap:24px;align-items:start;margin-top:22px">
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" class="card" style="max-width:none;margin:0;padding:22px">
				<input type="hidden" name="action" value="go_verge_admin_branding_save">
				<?php wp_nonce_field( 'go_admin_branding_save' ); ?>
				<table class="form-table" role="presentation" style="margin-top:0">
					<tr><th scope="row"><?php esc_html_e( 'Aplicação', 'go-verge' ); ?></th><td>
						<label><input type="checkbox" name="go_admin_branding[enabled]" value="1" <?php checked( $o['enabled'], 1 ); ?>> <?php esc_html_e( 'Usar a identidade Overdrive no wp-admin', 'go-verge' ); ?></label><br>
						<label><input type="checkbox" name="go_admin_branding[login]" value="1" <?php checked( $o['login'], 1 ); ?>> <?php esc_html_e( 'Aplicar também na tela de login', 'go-verge' ); ?></label>
					</td></tr>
					<?php foreach ( $fields as $key => $field ) : ?>
						<tr>
							<th scope="row"><label for="go-admin-<?php echo esc_attr( $key ); ?>"><?php echo esc_html( $field[0] ); ?></label></th>
							<td><input id="go-admin-<?php echo esc_attr( $key ); ?>" class="go-admin-color-field" type="text" name="go_admin_branding[<?php echo esc_attr( $key ); ?>]" value="<?php echo esc_attr( $o[ $key ] ); ?>" data-default-color="<?php echo esc_attr( go_verge_admin_branding_defaults()[ $key ] ); ?>"><p class="description"><?php echo esc_html( $field[1] ); ?></p></td>
						</tr>
					<?php endforeach; ?>
				</table>
				<?php submit_button( __( 'Salvar cores', 'go-verge' ) ); ?>
				<button type="submit" class="button" name="go_admin_branding_reset" value="1" onclick="return confirm('<?php echo esc_js( __( 'Restaurar as cores padrão do Overdrive?', 'go-verge' ) ); ?>')"><?php esc_html_e( 'Restaurar padrão Overdrive', 'go-verge' ); ?></button>
			</form>

			<div class="go-admin-palette-preview" style="--p-accent:<?php echo esc_attr( $o['accent'] ); ?>;--p-nav:<?php echo esc_attr( $o['nav_bg'] ); ?>;--p-page:<?php echo esc_attr( $o['page_bg'] ); ?>;--p-surface:<?php echo esc_attr( $o['surface'] ); ?>;--p-text:<?php echo esc_attr( $o['text'] ); ?>;overflow:hidden;border:1px solid #dcdcde;border-radius:14px;background:var(--p-page);box-shadow:0 8px 28px rgba(0,0,0,.08)">
				<div style="height:34px;background:var(--p-nav)"></div>
				<div style="display:grid;grid-template-columns:72px 1fr;min-height:250px">
					<div style="background:var(--p-nav);padding:14px 9px"><i style="display:block;height:28px;margin-bottom:8px;border-radius:6px;background:var(--p-accent)"></i><i style="display:block;height:8px;margin:12px 6px;border-radius:10px;background:rgba(255,255,255,.55)"></i><i style="display:block;height:8px;margin:12px 6px;border-radius:10px;background:rgba(255,255,255,.3)"></i><i style="display:block;height:8px;margin:12px 6px;border-radius:10px;background:rgba(255,255,255,.3)"></i></div>
					<div style="padding:22px"><strong style="display:block;margin-bottom:14px;color:var(--p-text);font-size:20px"><?php esc_html_e( 'Posts', 'go-verge' ); ?></strong><div style="padding:14px;border:1px solid rgba(0,0,0,.12);border-radius:10px;background:var(--p-surface)"><span style="display:inline-block;padding:7px 11px;border-radius:7px;background:var(--p-accent);color:white;font-weight:700"><?php esc_html_e( 'Adicionar post', 'go-verge' ); ?></span><div style="height:9px;margin:18px 0 10px;border-radius:10px;background:rgba(0,0,0,.12)"></div><div style="height:9px;width:76%;border-radius:10px;background:rgba(0,0,0,.08)"></div></div></div>
				</div>
			</div>
		</div>
	</div>
	<style>@media(max-width:1050px){.go-admin-branding-grid{grid-template-columns:1fr!important}.go-admin-palette-preview{max-width:620px}}</style>
	<?php
}

/** Optional login-screen palette. */
function go_verge_admin_branding_login_css() {
	$t = go_verge_admin_branding_tokens();
	if ( empty( $t['enabled'] ) || empty( $t['login'] ) ) {
		return;
	}
	?>
	<style id="go-admin-branding-login-css">
	body.login{background:<?php echo esc_html( $t['page_bg'] ); ?>;color:<?php echo esc_html( $t['text'] ); ?>}
	body.login #loginform,body.login #registerform,body.login #lostpasswordform{border:1px solid <?php echo esc_html( $t['line'] ); ?>;border-radius:14px;background:<?php echo esc_html( $t['surface'] ); ?>;box-shadow:0 10px 35px rgba(18,16,24,.07)}
	body.login .button-primary{border-color:<?php echo esc_html( $t['accent'] ); ?>;background:<?php echo esc_html( $t['accent'] ); ?>;color:<?php echo esc_html( $t['on_accent'] ); ?>;box-shadow:none}
	body.login .button-primary:hover,body.login .button-primary:focus{border-color:<?php echo esc_html( $t['accent_hover'] ); ?>;background:<?php echo esc_html( $t['accent_hover'] ); ?>;color:<?php echo esc_html( $t['on_accent'] ); ?>}
	body.login input[type=text]:focus,body.login input[type=password]:focus,body.login input[type=email]:focus{border-color:<?php echo esc_html( $t['accent'] ); ?>;box-shadow:0 0 0 1px <?php echo esc_html( $t['accent'] ); ?>}
	body.login #nav a,body.login #backtoblog a,body.login .privacy-policy-page-link a{color:<?php echo esc_html( $t['accent'] ); ?>}
	</style>
	<?php
}
add_action( 'login_head', 'go_verge_admin_branding_login_css', 30 );
