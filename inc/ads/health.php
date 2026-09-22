<?php
/** Lightweight Site Health checks for the active AdSense delivery contract. */
if ( ! defined( 'ABSPATH' ) ) { exit; }

function go_verge_ads_register_health_tests( $tests ) {
	$tests['direct']['go_verge_ads_inventory'] = array(
		'label' => __( 'Inventário AdSense do Overdrive', 'go-verge' ),
		'test'  => 'go_verge_ads_stable_inventory_health_test',
	);
	$tests['direct']['go_verge_ads_loader'] = array(
		'label' => __( 'Configuração local do loader AdSense', 'go-verge' ),
		'test'  => 'go_verge_ads_loader_health_test',
	);
	return $tests;
}
add_filter( 'site_status_tests', 'go_verge_ads_register_health_tests' );

function go_verge_ads_health_result( $label, $status, $description, $test ) {
	return array(
		'label'       => $label,
		'status'      => $status,
		'badge'       => array( 'label' => __( 'Overdrive Ads', 'go-verge' ), 'color' => 'blue' ),
		'description' => '<p>' . esc_html( $description ) . '</p>',
		'actions'     => '',
		'test'        => $test,
	);
}

/**
 * The publisher inventory contract, and the delivery mode it assumes.
 *
 * Registered both as a Site Health test and as the first row of the Ads Center
 * delivery card: one implementation, two surfaces.
 */
function go_verge_ads_default_slot_ids() {
	return array(
		'topscroll'            => '7792311754',
		'site-masthead'        => '3572313419',
		'home-masthead'        => '3572313419',
		'article-hero-overlay' => '5017324239',
		'game-hub-mid'         => '1188364638',
		'sidebar-desktop'      => '6489083385',
		'article-prime'        => '5223365459',
		'article-a1'           => '7131714626',
		'article-a2'           => '4505551284',
		'article-a3'           => '5056215625',
		'article-a4'           => '6568236715',
		'article-a5'           => '8238832024',
		'article-a6'           => '5255155049',
		'listing-f1'           => '4927851985',
		'listing-f2'           => '3996334686',
		'listing-f3'           => '2880273141',
		'listing-f4'           => '4207836686',
		'listing-f5'           => '4704776118',
		'home-mid'             => '6795467428',
		'article-end'          => '5798080525',
		'home-mid-2'           => '6925750357',
	);
}

function go_verge_ads_stable_inventory_health_test() {
	$defaults = go_verge_ads_default_slot_ids();
	$inventory = function_exists( 'go_verge_ads_inventory' ) ? go_verge_ads_inventory() : array();
	$errors = array();
	$custom = array();
	foreach ( $inventory as $placement => $unit ) {
		$slot = (string) ( $unit['slot'] ?? '' );
		if ( ! empty( $unit['enabled'] ) && ! preg_match( '/^\d{6,}$/', $slot ) ) { $errors[] = $placement; }
		if ( isset( $defaults[ $placement ] ) && $slot !== $defaults[ $placement ] ) { $custom[] = $placement; }
		foreach ( (array) ( $unit['slot_variants'] ?? array() ) as $key => $variant ) {
			if ( ! empty( $unit['enabled'] ) && ! preg_match( '/^\d{6,}$/', (string) ( $variant['slot'] ?? '' ) ) ) { $errors[] = $placement . ':' . $key; }
		}
	}
	$config = function_exists( 'go_verge_ads_config' ) ? (array) go_verge_ads_config() : array();
	if ( 'manual_overlays' !== (string) ( $config['delivery_mode'] ?? '' ) ) { $errors[] = 'delivery-mode'; }
	if ( ! $inventory ) { $errors[] = 'inventory-empty'; }
	if ( $errors ) {
		return go_verge_ads_health_result( __( 'A configuração local de anúncios precisa de revisão', 'go-verge' ), 'critical',
			sprintf( __( 'IDs ou contrato local inválidos: %s. O estado das unidades na conta exige consulta separada.', 'go-verge' ), implode( ', ', array_unique( $errors ) ) ), 'go_verge_ads_inventory' );
	}
	return go_verge_ads_health_result( __( 'IDs e modo locais são válidos', 'go-verge' ), 'good',
		sprintf( __( 'Modo: %s. %d posições configuradas; %d IDs diferentes dos padrões. IDs personalizados válidos são aceitos. Isto não confirma o tipo, o estado na conta nem a entrega; consulte o inventário por ID efetivo.', 'go-verge' ), $config['delivery_mode'], count( $inventory ), count( $custom ) ), 'go_verge_ads_inventory' );
}

function go_verge_ads_loader_health_test() {
	$client = defined( 'GO_VERGE_ADSENSE_CLIENT' ) ? (string) GO_VERGE_ADSENSE_CLIENT : '';
	$valid  = (bool) preg_match( '/^ca-pub-\d+$/', $client ) && function_exists( 'go_verge_ads_canonical_loader_tag' );
	if ( ! $valid ) {
		return go_verge_ads_health_result(
			__( 'O bootstrap do AdSense precisa de atenção', 'go-verge' ),
			'critical',
			__( 'O publisher ID ou a função do loader canônico não está disponível.', 'go-verge' ),
			'go_verge_ads_loader'
		);
	}
	return go_verge_ads_health_result(
		__( 'Configuração local do loader válida', 'go-verge' ),
		'good',
		__( 'O código local mantém o loader client-qualified para anúncios manuais, âncora e vinheta, com deduplicação própria e integração com Site Kit. Este teste não observa outros plugins, o HTML final, o consentimento do visitante nem os controles atuais da conta.', 'go-verge' ),
		'go_verge_ads_loader'
	);
}

/* ------------------------------------------------------------ local checks */

/**
 * The prose root the runtime queries must be the one the theme renders.
 *
 * `assets/js/go-ads-runtime.js` resolves the article container with
 * `[data-go-manual-ads-root="article"], .go-article__content, .entry-content,
 * .go-single__content`. That node carries the planner telemetry and is the
 * container the whole-article density ratio measures against. If the class list
 * in `go_verge_ads_article_root_attributes()` drifts away from that selector,
 * nothing errors: the body budget silently resolves to zero and in-article
 * inventory stops existing.
 */
function go_verge_ads_article_root_health_test() {
	if ( ! function_exists( 'go_verge_ads_article_root_classes' ) || ! function_exists( 'go_verge_ads_article_root_attributes' ) ) {
		return go_verge_ads_health_result(
			__( 'A raiz do artigo não pôde ser verificada', 'go-verge' ),
			'critical',
			__( 'As funções que declaram o contêiner de prosa não estão disponíveis.', 'go-verge' ),
			'go_verge_ads_article_root'
		);
	}

	$classes    = (array) go_verge_ads_article_root_classes();
	$attributes = (string) go_verge_ads_article_root_attributes();
	$missing    = array();

	/* At least one of these has to survive, or the runtime's selector misses. */
	if ( ! array_intersect( array( 'go-article__content', 'entry-content', 'go-single__content' ), $classes ) ) {
		$missing[] = 'classe de prosa';
	}
	if ( false === strpos( $attributes, 'data-go-manual-ads-root="article"' ) ) {
		$missing[] = 'data-go-manual-ads-root';
	}

	if ( $missing ) {
		return go_verge_ads_health_result(
			__( 'O runtime não encontraria o corpo do artigo', 'go-verge' ),
			'critical',
			sprintf(
				/* translators: %s: list of missing markers. */
				__( 'Faltando: %s. Sem isso o orçamento do corpo resolve para zero e nenhum anúncio in-article é solicitado.', 'go-verge' ),
				implode( ', ', $missing )
			),
			'go_verge_ads_article_root'
		);
	}

	return go_verge_ads_health_result(
		__( 'O runtime encontra o corpo do artigo', 'go-verge' ),
		'good',
		sprintf(
			/* translators: %s: article root identity. */
			__( 'Raiz de prosa estável: %s.', 'go-verge' ),
			function_exists( 'go_verge_ads_article_root_identity' ) ? go_verge_ads_article_root_identity() : implode( '.', $classes )
		),
		'go_verge_ads_article_root'
	);
}

/**
 * Inspect local disabling constants; this cannot determine auction eligibility.
 *
 * Rollback constants exist so a bad night can be undone in one line. The risk
 * is the opposite one: a constant left behind after the incident keeps cutting
 * inventory for weeks, and nothing on any screen says so.
 */
function go_verge_ads_open_auction_health_test() {
	$blocking = array();

	if ( defined( 'GO_ADS_V3_ENABLED' ) && ! GO_ADS_V3_ENABLED ) {
		$blocking[] = 'GO_ADS_V3_ENABLED';
	}
	if ( defined( 'GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED' ) && ! GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED ) {
		$blocking[] = 'GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED';
	}
	if ( defined( 'GO_ADS_HERO_OVERLAY_ENABLED' ) && ! GO_ADS_HERO_OVERLAY_ENABLED ) {
		$blocking[] = 'GO_ADS_HERO_OVERLAY_ENABLED';
	}
	if ( defined( 'GO_VERGE_ADSENSE_TOPSCROLL_ENABLED' ) && ! GO_VERGE_ADSENSE_TOPSCROLL_ENABLED ) {
		$blocking[] = 'GO_VERGE_ADSENSE_TOPSCROLL_ENABLED';
	}
	if ( defined( 'GO_VERGE_ADS_MASTHEAD_MOBILE' ) && ! GO_VERGE_ADS_MASTHEAD_MOBILE ) {
		$blocking[] = 'GO_VERGE_ADS_MASTHEAD_MOBILE';
	}

	$client = defined( 'GO_VERGE_ADSENSE_CLIENT' ) ? (string) GO_VERGE_ADSENSE_CLIENT : '';
	if ( ! preg_match( '/^ca-pub-\d+$/', $client ) ) {
		$blocking[] = 'publisher id';
	}
	if ( function_exists( 'go_verge_ads_canonical_loader_tag' ) && '' === go_verge_ads_canonical_loader_tag() ) {
		$blocking[] = 'loader canônico';
	}

	if ( $blocking ) {
		return go_verge_ads_health_result(
			__( 'Há inventário desligado por configuração', 'go-verge' ),
			'recommended',
			sprintf(
				/* translators: %s: list of constants. */
				__( 'Configurações locais restritivas: %s. Confirme se são intencionais antes de alterar. Este teste não consulta restrições de veiculação ou o leilão da conta.', 'go-verge' ),
				implode( ', ', $blocking )
			),
			'go_verge_ads_open_auction'
		);
	}

	return go_verge_ads_health_result(
		__( 'Nenhuma constante local de desligamento detectada', 'go-verge' ),
		'good',
		__( 'O publisher local é válido e estas constantes não desligam posições. O modo de entrega ainda controla as unidades manuais; elegibilidade, consentimento, preenchimento e restrições da conta não são comprovados por este teste.', 'go-verge' ),
		'go_verge_ads_open_auction'
	);
}

/**
 * What the theme is built for, against what the operator says the account does.
 *
 * The engine assumes account-level Auto ads runs with overlay formats only.
 * The AdSense API cannot report which formats are enabled, so the Optimization
 * screen asks the operator to record it. This compares the two. A mismatch on
 * in-page banners is the single most expensive one: the page would carry the
 * manual ladder AND Google's automatic in-page units at the same time.
 */
function go_verge_ads_account_controls_health_test() {
	$config   = function_exists( 'go_verge_ads_config' ) ? (array) go_verge_ads_config() : array();
	$contract = (array) ( $config['account_formats'] ?? array() );
	$stored   = get_option( 'goac_optimization_controls', array() );
	$stored   = is_array( $stored ) ? $stored : array();
	$value    = static function ( $key ) use ( $stored ) {
		$raw = isset( $stored[ $key ] ) ? (string) $stored[ $key ] : 'unknown';
		return in_array( $raw, array( 'on', 'off' ), true ) ? $raw : 'unknown';
	};

	$conflicts = array();
	$unknown   = array();

	$in_page = (string) ( $contract['in_page'] ?? 'off' );
	if ( 'unknown' === $value( 'banner_ads' ) ) { $unknown[] = 'banners in-page'; }
	elseif ( $in_page !== $value( 'banner_ads' ) ) {
		$conflicts[] = sprintf( __( 'banners in-page constam como %s no registro manual, enquanto o modo local orienta %s', 'go-verge' ), $value( 'banner_ads' ), $in_page );
	}

	/* Anchor and vignette ride on the account-level Auto ads switch. */
	if ( 'on' === (string) ( $contract['anchor'] ?? 'on' ) || 'on' === (string) ( $contract['vignette'] ?? 'on' ) ) {
		if ( 'off' === $value( 'auto_ads' ) ) {
			$conflicts[] = __( 'Auto Ads geral consta DESLIGADO no registro manual, incompatível com âncora e vinheta ligadas', 'go-verge' );
		} elseif ( 'unknown' === $value( 'auto_ads' ) ) {
			$unknown[] = 'Auto ads (âncora/vinheta)';
		}
	}
	/* The global Auto ads switch alone does not establish either overlay format.
	 * These are operator records, never a claim of a live account API check. */
	foreach ( array( 'anchor' => 'âncora', 'vignette' => 'vinheta' ) as $format => $label ) {
		if ( 'on' !== (string) ( $contract[ $format ] ?? 'on' ) ) { continue; }
		$recorded = $value( $format . '_ads' );
		if ( 'off' === $recorded ) {
			$conflicts[] = sprintf( __( '%s consta como DESLIGADA no registro manual, mas o contrato exige o formato ligado', 'go-verge' ), $label );
		} elseif ( 'unknown' === $recorded ) {
			$unknown[] = $label;
		}
	}
	/* Operator record only: official side rails are outside the fixed contract. */
	if ( 'off' === (string) ( $contract['side_rails'] ?? 'off' ) ) {
		if ( 'on' === $value( 'side_rails_ads' ) ) {
			$conflicts[] = __( 'side rails automáticos constam ligados no registro manual, mas o contrato orienta desligados', 'go-verge' );
		} elseif ( 'unknown' === $value( 'side_rails_ads' ) ) {
			$unknown[] = 'side rails automáticos';
		}
	}
	foreach ( ( 'off' === $in_page ? array( 'find_more' => 'Encontrar mais posições', 'optimize_existing' => 'Otimizar anúncios atuais' ) : array() ) as $key => $label ) {
		if ( 'on' === $value( $key ) ) {
			$conflicts[] = sprintf( /* translators: %s: AdSense control name. */ __( '"%s" consta ligado no registro manual e diverge da distribuição manual pretendida', 'go-verge' ), $label );
		} elseif ( 'unknown' === $value( $key ) ) {
			$unknown[] = $label;
		}
	}

	if ( $conflicts ) {
		return go_verge_ads_health_result(
			__( 'O registro manual diverge do modo local', 'go-verge' ),
			'critical',
			sprintf(
				/* translators: %s: list of conflicts. */
				__( '%s. Confirme os controles atuais no AdSense e atualize o registro em Overdrive Ads > Otimização. Esta verificação não consultou esses controles na conta.', 'go-verge' ),
				implode( '; ', $conflicts )
			),
			'go_verge_ads_account_controls'
		);
	}
	if ( $unknown ) {
		return go_verge_ads_health_result(
			__( 'Os controles da conta ainda não foram registrados', 'go-verge' ),
			'recommended',
			sprintf(
				/* translators: %s: list of unrecorded controls. */
				__( 'Sem registro: %s. A API do AdSense não informa quais formatos estão ligados; registre em Overdrive Ads > Otimização para que esta verificação passe a valer.', 'go-verge' ),
				implode( ', ', array_unique( $unknown ) )
			),
			'go_verge_ads_account_controls'
		);
	}

	return go_verge_ads_health_result(
		__( 'O registro manual acompanha o contrato do tema', 'go-verge' ),
		'good',
		__( 'Os controles registrados são compatíveis com o modo local e preservam âncora e vinheta. Esta verificação não consulta os controles atuais da conta; atualize o registro sempre que mudar o AdSense. Registro compatível não comprova entrega ou receita.', 'go-verge' ),
		'go_verge_ads_account_controls'
	);
}

/**
 * Whether the seven-day per-unit model has anything to say yet.
 *
 * Its absence never removes inventory: without it, simultaneously eligible
 * positions are simply ordered by their tier prior.
 */
function go_verge_ads_data_lab_health_test() {
	if ( ! function_exists( 'go_verge_ads_econ_slot_economics' ) ) {
		return go_verge_ads_health_result(
			__( 'O modelo econômico não está disponível', 'go-verge' ),
			'recommended',
			__( 'O módulo de economia do tema não foi carregado.', 'go-verge' ),
			'go_verge_ads_data_lab'
		);
	}

	$econ    = (array) go_verge_ads_econ_slot_economics();
	$samples = absint( $econ['samples'] ?? 0 );
	$window  = (string) ( $econ['window'] ?? '' );

	if ( $samples < 3 ) {
		return go_verge_ads_health_result(
			__( 'O Data Lab ainda não tem sete dias por bloco', 'go-verge' ),
			'recommended',
			sprintf(
				/* translators: %d: number of ad units with data. */
				__( 'Apenas %d bloco(s) com histórico fechado. Até lá, posições simultaneamente elegíveis são ordenadas pelo prior do tier — nenhuma oportunidade estrutural deixa de existir por isso.', 'go-verge' ),
				$samples
			),
			'go_verge_ads_data_lab'
		);
	}

	return go_verge_ads_health_result(
		__( 'O modelo por bloco está alimentado', 'go-verge' ),
		'good',
		sprintf(
			/* translators: 1: number of ad units, 2: date window. */
			__( '%1$d blocos com receita por request na janela %2$s. Esse valor decide a ORDEM dos leilões, nunca se uma posição segura pode existir.', 'go-verge' ),
			$samples,
			$window ? $window : '7d'
		),
		'go_verge_ads_data_lab'
	);
}

/* ----------------------------------------------------------- remote checks */

/** One HTTP read of the site's own front page or /ads.txt. */
function go_verge_ads_health_fetch( $url ) {
	return wp_remote_get(
		$url,
		array(
			'timeout'     => 8,
			'redirection' => 2,
			'headers'     => array( 'Cache-Control' => 'no-cache' ),
			'user-agent'  => 'Overdrive Ads Health/1.0',
		)
	);
}

/** Inspect tags in one HTTP response; do not execute scripts or infer live delivery. */
function go_verge_ads_single_loader_health_test() {
	$response = go_verge_ads_health_fetch( home_url( '/' ) );
	if ( is_wp_error( $response ) ) {
		return go_verge_ads_health_result(
			__( 'Não foi possível ler a home para contar os loaders', 'go-verge' ),
			'recommended',
			$response->get_error_message(),
			'go_verge_ads_single_loader'
		);
	}

	$status = (int) wp_remote_retrieve_response_code( $response );
	if ( 200 !== $status ) {
		return go_verge_ads_health_result( __( 'A resposta da home não permite auditar o loader', 'go-verge' ), 'recommended',
			sprintf( __( 'HTTP %d nesta consulta. Uma falha ou desafio do servidor não demonstra o estado do loader para visitantes ou rastreadores.', 'go-verge' ), $status ), 'go_verge_ads_single_loader' );
	}

	$body  = (string) wp_remote_retrieve_body( $response );
	$count = preg_match_all( '~<script[^>]+src=["\'][^"\']*(?:/pagead/js/adsbygoogle\.js|/adsbygoogle\.js)[^"\']*["\']~i', $body, $unused );

	if ( 1 === (int) $count ) {
		return go_verge_ads_health_result(
			__( 'O HTML consultado contém uma tag do AdSense', 'go-verge' ),
			'good',
			__( 'Esta resposta contém uma tag do provider. A consulta não executa JavaScript nem confirma requisições, preenchimento, consentimento ou formatos da conta.', 'go-verge' ),
			'go_verge_ads_single_loader'
		);
	}
	if ( 0 === (int) $count ) {
		return go_verge_ads_health_result(
			__( 'Nenhuma tag imediata do AdSense no HTML consultado', 'go-verge' ),
			'recommended',
			__( 'O carregamento pode ser posterior ao consentimento ou ocorrer por outro script. Confira a chave global, a propriedade do loader, o consentimento e o cache no HTML final antes de concluir ausência de entrega.', 'go-verge' ),
			'go_verge_ads_single_loader'
		);
	}

	return go_verge_ads_health_result(
		__( 'Há mais de um bootstrap do AdSense na página', 'go-verge' ),
		'critical',
		sprintf(
			/* translators: %d: number of loader script tags found. */
			__( '%d tags encontradas no HTML desta resposta. Revise a origem de cada tag e a integração dos plugins antes de remover uma cópia; preserve um loader oficial elegível. Esta consulta não identifica automaticamente o responsável nem comprova perda financeira.', 'go-verge' ),
			(int) $count
		),
		'go_verge_ads_single_loader'
	);
}

/** The publisher line has to be reachable at /ads.txt or the demand thins out. */
function go_verge_ads_txt_health_test() {
	$response = go_verge_ads_health_fetch( home_url( '/ads.txt' ) );
	if ( is_wp_error( $response ) ) {
		return go_verge_ads_health_result(
			__( 'Não foi possível ler o ads.txt', 'go-verge' ),
			'recommended',
			$response->get_error_message(),
			'go_verge_ads_txt'
		);
	}

	$code = (int) wp_remote_retrieve_response_code( $response );
	$body = (string) wp_remote_retrieve_body( $response );
	if ( 200 !== $code ) {
		return go_verge_ads_health_result(
			__( 'O ads.txt não está acessível', 'go-verge' ),
			'critical',
			sprintf( /* translators: %d: HTTP status code. */ __( 'A resposta de /ads.txt foi HTTP %d. Sem ads.txt válido a demanda programática cai.', 'go-verge' ), $code ),
			'go_verge_ads_txt'
		);
	}

	$publisher = preg_replace( '/^ca-/', '', defined( 'GO_VERGE_ADSENSE_CLIENT' ) ? (string) GO_VERGE_ADSENSE_CLIENT : '' );
	$declared  = '' !== $publisher
		&& false !== stripos( $body, 'google.com' )
		&& false !== stripos( $body, $publisher )
		&& false !== stripos( $body, 'DIRECT' );

	if ( ! $declared ) {
		return go_verge_ads_health_result(
			__( 'O ads.txt não declara este publisher', 'go-verge' ),
			'critical',
			sprintf(
				/* translators: %s: expected ads.txt line. */
				__( 'Esperado: %s. Sem essa linha, compradores programáticos tratam o inventário como não autorizado.', 'go-verge' ),
				'google.com, ' . $publisher . ', DIRECT, f08c47fec0942fa0'
			),
			'go_verge_ads_txt'
		);
	}

	return go_verge_ads_health_result(
		__( 'O ads.txt declara este publisher', 'go-verge' ),
		'good',
		__( 'A linha DIRECT do Google está publicada e acessível.', 'go-verge' ),
		'go_verge_ads_txt'
	);
}
