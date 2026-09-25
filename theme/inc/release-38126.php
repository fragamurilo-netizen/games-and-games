<?php
/**
 * Release 3.81.26 — archive polish, loader centering and commerce cleanup.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

/**
 * Short editorial archive descriptions. These replace robotic/overlong copy on
 * the main category hubs while keeping a natural newsroom tone.
 *
 * @param WP_Term $term Category term.
 * @return string
 */
function go_verge_38126_archive_description( $term ) {
	if ( ! ( $term instanceof WP_Term ) || 'category' !== $term->taxonomy ) {
		return '';
	}

	$map = array(
		'ofertas'          => '',
		'dicas-e-guias'    => 'Passo a passo, códigos, builds e respostas para avançar nos principais jogos.',
		'guias'            => 'Passo a passo, códigos, builds e respostas para avançar nos principais jogos.',
		'games'            => 'Notícias, análises, lançamentos e guias do universo gamer.',
		'entretenimento'   => 'Séries, filmes, streaming, novelas turcas, anime e cultura pop.',
		'tecnologia'       => 'Celulares, IA, hardware, software e guias para comprar melhor.',
		'smartphones'      => 'Lançamentos, comparativos e guias para escolher o celular certo.',
		'celulares'        => 'Lançamentos, comparativos, atualizações e guias para escolher e usar melhor seu celular.',
		'apps-software'    => 'Apps, sistemas, atualizações e soluções práticas para celular e computador.',
		'ciencia'          => 'Ciência, espaço, mobilidade e inovações que ajudam a entender o que vem pela frente.',
		'hardware'         => 'Componentes, periféricos, desempenho e guias para montar ou atualizar seu setup.',
		'ia'               => 'Ferramentas, modelos, recursos e impactos da inteligência artificial no dia a dia.',
		'notebooks'        => 'Lançamentos, comparativos e guias para escolher notebooks para trabalho, estudo e jogos.',
		'tvs-e-monitores'  => 'TVs e monitores, tecnologias de tela, configurações e guias de compra.',
		'filmes'           => 'Estreias, listas, bastidores e tudo sobre cinema.',
		'series'           => 'Estreias, elenco, episódios e novidades das principais séries.',
		'anime'            => 'Lançamentos, listas e novidades do mundo dos animes.',
		'anime-e-manga'    => 'Estreias, episódios, mangás, adaptações e novidades de anime.',
		'criticas'         => 'Críticas de filmes, séries e outras produções, com contexto e análise editorial.',
		'doramas'          => 'Doramas, estreias, episódios, elenco e guias para acompanhar produções asiáticas.',
		'musica'           => 'Lançamentos, artistas, trilhas e notícias que conectam música e cultura pop.',
		'producoes-turcas' => 'Novelas e séries turcas, com episódios, elenco, finais e onde assistir.',
		'streaming'        => 'Netflix, Prime Video, Disney+, Max e outros serviços: estreias, catálogos e guias.',
		'especiais'        => 'Reportagens, listas, bastidores e análises que vão além da notícia do dia.',
		'lancamentos'      => 'Datas, plataformas, preços e tudo o que importa nos próximos lançamentos de jogos.',
		'reviews'          => 'Reviews de jogos com análise, desempenho, pontos fortes, limitações e veredito editorial.',
		'guias-de-compra'  => 'Comparativos, recomendações e critérios para escolher tecnologia e acessórios com mais segurança.',
		'jogos-gratis'     => 'Jogos gratuitos, resgates, períodos grátis e oportunidades para jogar sem pagar.',
		'promocoes'        => 'Promoções, quedas de preço e ofertas verificadas em jogos, tecnologia e acessórios.',
	);

	if ( array_key_exists( $term->slug, $map ) ) {
		return trim( (string) $map[ $term->slug ] );
	}

	$raw = trim( wp_strip_all_tags( category_description( $term ) ) );
	$raw = preg_replace( '/\s+/', ' ', $raw );

	return trim( (string) $raw );
}
