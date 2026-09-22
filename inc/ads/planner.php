<?php
/**
 * Manual revenue placement planner.
 *
 * Scans the final server-rendered article without reserializing it. Original
 * byte offsets are preserved, components are treated atomically and malformed
 * markup fails closed. Prime P1 is intentionally the first high-reach
 * opportunity after two substantial paragraphs; A1..A6 then distribute the
 * remaining density through the article. Google still owns auction, creative
 * and fill.
 *
 * @package go-verge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Count natural-language tokens in a HTML fragment.
 *
 * The canonical counter for the whole theme: the planner's capacity ladder, the
 * reading-time estimate in editorial-layouts.php and the recirculation module
 * all size the same article, and until 4.6 they did it with two near-identical
 * copies of this function that disagreed on whitespace handling.
 *
 * Adjacent paragraphs must not merge their last and first words, and entity
 * names such as &nbsp; and &amp; are not editorial words.
 */
function go_verge_ads_word_count( $html ) {
	$html = preg_replace( '~<(script|style|template)\b[^>]*>.*?</\1\s*>|<!--[\s\S]*?-->~is', '', (string) $html );
	$text = trim( html_entity_decode( preg_replace( '/<[^>]*>/', ' ', $html ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ) );
	if ( '' === $text ) {
		return 0;
	}
	return preg_match_all( "/[\p{L}\p{N}]+(?:[’'-][\p{L}\p{N}]+)*/u", $text, $unused ) ?: 0;
}

/**
 * Return top-level blocks and their original byte offsets.
 *
 * Unknown/nested UI remains one atomic block. HTML that would rely on browser
 * error recovery is deliberately rejected rather than receiving ads at guessed
 * boundaries.
 *
 * @param string $html Article HTML.
 * @return array<int,array<string,mixed>>
 */
function go_verge_ads_planner_blocks( $html, $level = 0 ) {
	$html = (string) $html;
	$pattern = '~<!--[\s\S]*?-->|<(script|style|template|textarea|title|xmp|noscript|iframe)\b(?:"[^"]*"|\'[^\']*\'|[^\'">])*?>[\s\S]*?</\1\s*>|<![^>]*>|</?[a-zA-Z][a-zA-Z0-9:-]*\b(?:"[^"]*"|\'[^\']*\'|[^\'">])*>~i';
	if ( ! preg_match_all( $pattern, $html, $tokens, PREG_OFFSET_CAPTURE ) ) {
		return array();
	}

	$voids  = array( 'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr' );
	$stack  = array();
	$blocks = array();
	$start  = 0;
	$tag    = '';
	$cursor = 0;

	foreach ( $tokens[0] as $token ) {
		$raw    = (string) $token[0];
		$offset = (int) $token[1];
		$end    = $offset + strlen( $raw );

		if ( ! $stack && '' !== trim( substr( $html, $cursor, $offset - $cursor ) ) ) {
			return array();
		}
		$cursor = $end;

		if ( 0 === strpos( $raw, '<!' ) ) {
			continue;
		}
		if ( ! preg_match( '~^<(/?)([a-zA-Z0-9:-]+)~', $raw, $match ) ) {
			return array();
		}

		$name    = strtolower( (string) $match[2] );
		$closing = '/' === $match[1];
		$atomic  = in_array( $name, array( 'script', 'style', 'template', 'textarea', 'title', 'xmp', 'noscript', 'iframe' ), true );

		if ( $closing ) {
			if ( ! $stack || array_pop( $stack ) !== $name ) {
				return array();
			}
		} else {
			/* Fail closed when HTML5 would implicitly close/reparent a paragraph. */
			if ( in_array( 'p', $stack, true ) && in_array( $name, array( 'p', 'div', 'section', 'article', 'aside', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'ul', 'ol', 'figure', 'blockquote', 'details', 'address', 'dl', 'fieldset', 'footer', 'form', 'header', 'hr', 'main', 'nav', 'pre' ), true ) ) {
				return array();
			}
			/* In HTML a slash does not close a non-void element. Accept it only
			 * inside foreign SVG/MathML content, where it has that meaning. */
			if ( preg_match( '~/\s*>$~', $raw ) && ! $atomic && ! in_array( $name, $voids, true )
				&& ! in_array( $name, array( 'svg', 'math' ), true )
				&& ! in_array( 'svg', $stack, true ) && ! in_array( 'math', $stack, true ) ) {
				return array();
			}
			if ( ! $stack ) {
				$start = $offset;
				$tag   = $name;
			}
			if ( ! $atomic && ! in_array( $name, $voids, true ) && ! preg_match( '~/\s*>$~', $raw ) ) {
				$stack[] = $name;
			}
		}

		if ( ! $stack ) {
			$fragment = substr( $html, $start, $end - $start );
			preg_match( '~^<[a-zA-Z0-9:-]+\b(?:"[^"]*"|\'[^\']*\'|[^\'">])*>~', $fragment, $opening_match );
			$opening = (string) ( $opening_match[0] ?? '' );
			/* Hidden descendants (for example decorative SVG icons) do not make
			 * their containing paragraph hidden. Only the block's root does. */
			$hidden = (bool) preg_match( '~\shidden(?:\s|=|>)|\saria-hidden\s*=\s*(?:["\']true["\']|true(?=\s|>))|display\s*:\s*none|visibility\s*:\s*hidden~i', $opening );

			/* Ordinary Gutenberg groups are layout-neutral containers. Descend
			 * only through an explicit allowlist: CTA, columns, cards and custom
			 * components retain their atomic boundaries. Byte offsets stay exact. */
			if ( $level < 8 && ! $hidden && in_array( $tag, array( 'div', 'section' ), true )
				&& go_verge_ads_planner_transparent_container( $opening ) ) {
				$inner_start = strlen( $opening );
				$inner_end = strrpos( $fragment, '</' );
				$inner = false !== $inner_end ? substr( $fragment, $inner_start, $inner_end - $inner_start ) : '';
				$children = go_verge_ads_planner_blocks( $inner, $level + 1 );
				if ( $children ) {
					foreach ( $children as $child ) {
						$child['start'] += $start + $inner_start;
						$child['end'] += $start + $inner_start;
						$blocks[] = $child;
					}
					continue;
				}
			}
			$words    = go_verge_ads_word_count( $fragment );
			$kind     = 'component';

			/* Interactive, commercial or structural markup that must stay atomic and
			 * can never be a direct neighbour of a revenue insertion. */
			/* Split dangerous/commercial markup from structural table markup. A plain
			 * data table or definition list is still editorial reading surface, even
			 * though it must stay atomic and can never be an insertion neighbour. */
			$dangerous = (bool) preg_match( '~<(?:details|summary|button|form|input|select|textarea|ins|script|style|template|pre|code)\b|data-go-(?:ad|related|interactive)|adsbygoogle|google-auto-placed|(?:class|id)\s*=\s*["\'][^"\']*(?:faq|spoiler|cta|related|affiliate|afiliad|sticky|go-btn|wp-block-button|go-context|go-inline|go-review)|rel\s*=\s*["\'][^"\']*sponsored|\srole\s*=\s*["\'](?:button|tab|menuitem|slider)|\bon[a-z]+\s*=|position\s*:\s*(?:sticky|fixed)|(?:amzn\.to|amazon\.[^/]+/|[?&](?:tag|aff_id|affiliate)=)~i', $fragment );
			$structural_unsafe = (bool) preg_match( '~<table\b~i', $fragment );
			$unsafe = $dangerous || $structural_unsafe;
			$has_media = (bool) preg_match( '~<(?:img|picture|figure|iframe|video|audio|embed)\b|<[a-z][a-z0-9:-]*\b(?:"[^"]*"|\'[^\']*\'|[^\'">])*?\s(?:class|id|data-provider)\s*=\s*(?:"[^"]*(?:gallery|youtube|instagram|twitter-tweet)[^"]*"|\'[^\']*(?:gallery|youtube|instagram|twitter-tweet)[^\']*\'|(?:gallery|youtube|instagram|twitter-tweet)(?=\s|>))~i', $fragment );
			$atomic_text = in_array( $tag, array( 'table', 'dl' ), true ) && ! $dangerous && ! $has_media;

			if ( preg_match( '/^h[1-6]$/', $tag ) ) {
				$kind = $unsafe ? 'component' : 'heading';
			} elseif ( in_array( $tag, array( 'ul', 'ol' ), true ) && ! $unsafe && ! $has_media ) {
				/*
				 * A plain editorial list is prose, not a widget.
				 *
				 * 14.5 classified every <ul>/<ol> as an atomic component. A 1,500-word
				 * listicle or ranking - a large share of this site's Discover traffic -
				 * therefore reported only a few hundred "prose words", took the smallest
				 * rung of the capacity ladder and frequently failed the
				 * substantial-paragraph test outright, finishing with one or zero in-body
				 * opportunities on an article that structurally supports six. Lists
				 * carrying buttons, affiliate links, embedded media or interactive markup
				 * stay atomic exactly as before.
				 */
				$kind = 'list';
			} elseif ( 'blockquote' === $tag && ! $unsafe && ! $has_media ) {
				/* Editorial quotation is content, not a UI widget. It remains one
				 * atomic block (never insert inside it), but its words and its outer
				 * boundaries are legitimate reading surface. Treating blockquotes as
				 * components made quote-heavy news look hundreds of words shorter. */
				$kind = 'quote';
			} elseif ( $atomic_text ) {
				/* Static tables/definition lists contribute to article length but are
				 * protected atomic islands. Candidate generation deliberately does NOT
				 * treat atomic_text as an eligible neighbour, so no ad is inserted in,
				 * directly before or directly after the structure. */
				$kind = 'atomic_text';
			} elseif ( $unsafe ) {
				$kind = 'component';
			} elseif ( $has_media ) {
				/* Media is markup, not a topic word: an ordinary paragraph or source
				 * link mentioning YouTube/Instagram remains editorial prose. */
				$kind = 'media';
			} elseif ( 'p' === $tag ) {
				$kind = 'prose';
			}

			/* Conservative layout estimate. It is used only for spacing decisions,
			 * never represented as a measured browser pixel position. */
			$height = max( 34, (int) ceil( $words / 11 ) * 29 + 22 );
			if ( 'media' === $kind ) {
				$height += 320;
			}
			if ( 'list' === $kind ) {
				/* Every item starts a new line and carries its own margin, so a
				 * list is materially taller than the same word count as prose. */
				$height += 26 * max( 0, substr_count( strtolower( $fragment ), '<li' ) - 1 );
			}
			if ( 'quote' === $kind ) {
				$height += 28;
			}
			if ( 'atomic_text' === $kind ) {
				/* Tables/definition lists are generally taller than prose with the same
				 * word count. This is only a conservative server estimate; runtime uses
				 * real pixels before any request. */
				$rows = substr_count( strtolower( $fragment ), '<tr' );
				$defs = substr_count( strtolower( $fragment ), '<dt' ) + substr_count( strtolower( $fragment ), '<dd' );
				$height += 26 * max( 1, $rows, $defs );
			}
			if ( 'heading' === $kind ) {
				$height = 68;
			}
			if ( $hidden ) {
				$words  = 0;
				$height = 0;
				$kind   = 'component';
			}

			$blocks[] = array(
				'start'  => $start,
				'end'    => $end,
				'tag'    => $tag,
				'kind'   => $kind,
				'words'  => $words,
				'height' => $height,
			);
		}
	}

	if ( $stack || '' !== trim( substr( $html, $cursor ) ) ) {
		return array();
	}
	return $blocks;
}

/** Whether a wrapper can safely expose its own editorial block boundaries. */
function go_verge_ads_planner_transparent_container( $opening ) {
	if ( ! preg_match( '~^<(?:div|section)\s*(?:class\s*=\s*(["\'])(.*?)\1\s*)?>$~is', $opening, $attributes ) ) {
		return false;
	}
	$allowed = array( 'wp-block-group', 'wp-block-group__inner-container', 'entry-content', 'is-layout-flow', 'is-layout-constrained', 'wp-block-group-is-layout-flow', 'wp-block-group-is-layout-constrained' );
	foreach ( preg_split( '/\s+/', trim( (string) ( $attributes[2] ?? '' ) ) ) as $class ) {
		if ( '' !== $class && ! in_array( $class, $allowed, true ) ) {
			return false;
		}
	}
	return true;
}

/**
 * Total in-content opportunity ladder, INCLUDING Prime P1.
 *
 * P1 replaces the earliest body opportunity instead of simply adding one more ad
 * beside it. Adaptive Yield exposes deeper placements only where
 * structural clearance produces enough safe boundaries.
 */
function go_verge_ads_planner_capacity_from_words( $words, $article_type = '' ) {
	$words = absint( $words );
	/*
	 * Structural ceiling for in-body opportunities, from editorial body length
	 * (prose + plain lists).
	 *
	 * The rungs were recalibrated against this site's own August history and
	 * production failures in 3.90. Historical windows prove that the site can
	 * operate above the current 5.x imp/PV range, but they do not prove that any
	 * one configuration caused the result. The ladder therefore exposes safe
	 * opportunities while leaving real-pixel density, reach and fill to runtime.
	 */
	/*
	 * 4.0.0: words are a coarse safety ceiling, not a proxy for the number of
	 * readers who will reach the slot. 3.90 silently removed the only in-body
	 * opportunity from the 240-259 word class of short Discover/news posts and
	 * then tried to recover the missing delivery with deeper slots on long-form.
	 * That is the wrong side of the reach curve. One early, structurally safe
	 * opportunity on a short story is worth more than another unit at 75% depth.
	 *
	 * The runtime remains the final authority for real-pixel density and never
	 * requests a host that violates its local/whole-article guards. These rungs
	 * merely allow the server planner to expose enough safe opportunities for
	 * that runtime to make the decision on the rendered page.
	 */
	/* Keep truly tiny briefs ad-free in the body. A 240+ word story can expose
	 * one candidate only when the surrounding editorial blocks themselves prove
	 * it is safe; the browser still applies the real-pixel density guard. */
	if ( $words < 240 ) { $rung = 0; }
	elseif ( $words < 280 ) { $rung = 1; }
	elseif ( $words < 400 ) { $rung = 2; }
	elseif ( $words < 550 ) { $rung = 3; }
	elseif ( $words < 680 ) { $rung = 4; }
	elseif ( $words < 900 ) { $rung = 5; }
	elseif ( $words < 1200 ) { $rung = 6; }
	else { $rung = 7; }

	/*
	 * Article type is a reading-behaviour signal, not a length signal.
	 *
	 * Word count alone treats a 900-word news story and a 900-word buying guide
	 * as the same inventory problem, and they are not. A guide, ranking or list
	 * is consumed in sections: the reader scans headings, stops at the item they
	 * came for and stays. Those articles reach their tail far more often than a
	 * news story of the same length, so a deeper opportunity there is genuinely
	 * reachable rather than theoretical.
	 *
	 * This is a small, bounded adjustment to the STRUCTURAL ceiling. It never
	 * forces a placement: editorial clearance, the browser's real-pixel density
	 * rules and the Revenue Governor all still have to agree.
	 */
	$type = sanitize_key( (string) $article_type );
	if ( in_array( $type, array( 'guide', 'ranking', 'list' ), true ) && $rung >= 3 ) {
		$rung = min( 7, $rung + 1 );
	}

	return $rung;
}

/**
 * Editorial clearance between two in-body opportunities.
 *
 * ONE pair of numbers, not a per-density table.
 *
 * The server estimate of rendered height runs roughly 15-20% low on a phone (a
 * narrow column wraps into more lines than the estimator assumes) and is close
 * to accurate on desktop. The browser enforces a real-pixel floor of 240px
 * between creatives on a phone, so the estimated gap is set just under what a
 * single substantial paragraph produces: a pair the planner accepts at 215
 * estimated pixels renders at roughly 250-265 real pixels on a phone, which is
 * what the runtime is about to measure.
 *
 * The two sides must be calibrated against each other. Setting them
 * independently — the 4.x behaviour, with a 170-215px per-density table on the
 * server and a flat 130px floor in the browser — meant the server planned pairs
 * the browser would happily render at 130px apart, and no single rule described
 * the density the reader actually saw.
 *
 * On desktop the same article is far shorter in pixels, so the browser's floor
 * is higher there and some of these pairs are correctly rejected at render
 * time. That is intentional: the plan is cached and shared between devices, so
 * it is calibrated for the phone and the browser adapts it.
 *
 * @return array{words:int,height:int}
 */
function go_verge_ads_planner_clearance() {
	return array( 'words' => 70, 'height' => 215 );
}

/**
 * Structural headroom above the word ladder.
 *
 * The word ladder is deliberately conservative: it has to be safe for a
 * 600-word story that is mostly images as well as one that is solid prose.
 * When the rendered article proves it carries more safe boundaries than the
 * ladder assumed, up to two additional opportunities are exposed.
 *
 * Both steps are earned by evidence from THIS article, never by a revenue
 * target:
 *   - spare structurally-safe boundaries beyond the ladder's own count;
 *   - enough substantial reading units that those boundaries are real pauses;
 *   - a layout that is not media-dominated, where the height estimate is least
 *     reliable.
 *
 * 4.x split this across two functions, and gated the second one on a financial
 * regime arriving from an uncached endpoint — which meant the same cached
 * article could carry different inventory depending on when the browser asked.
 * The evidence tests were sound; the plumbing was not. There is one function
 * here now, it reads only structure, and the session-level question it was
 * really trying to answer — has this READER earned more inventory? — belongs to
 * the Revenue Governor in the browser, which can see scroll depth and dwell.
 *
 * GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED=false restores the plain word ladder.
 *
 * @param array<int|string,mixed>        $metrics    Planner metrics.
 * @param array<int,array<string,mixed>> $candidates Safe candidates.
 * @param int                            $ladder     Word/type ladder capacity.
 * @return int 0, 1 or 2.
 */
function go_verge_ads_planner_structural_headroom( $metrics, $candidates, $ladder ) {
	if ( defined( 'GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED' ) && ! GO_VERGE_ADS_REVENUE_HEADROOM_ENABLED ) {
		return 0;
	}
	$words       = absint( $metrics['bodyWords'] ?? 0 );
	$ladder      = absint( $ladder );
	$safe        = count( (array) $candidates );
	$substantial = absint( $metrics['substantial'] ?? 0 );

	/* Below 480 words there is no room for another reachable position, and at
	 * the top rung the ladder is already at the contract maximum. */
	if ( $words < 480 || $ladder < 3 || $ladder >= 7 ) {
		return 0;
	}
	if ( $safe <= $ladder || $substantial < 4 ) {
		return 0;
	}
	$estimated_height = max( 1, absint( $metrics['estimatedHeight'] ?? 0 ) );
	$media_share = absint( $metrics['mediaHeight'] ?? 0 ) / $estimated_height;
	if ( $media_share > .42 ) {
		return 0;
	}

	/*
	 * The second step is confined to the 550-899-word middle, where the ladder
	 * is most conservative relative to what the page actually renders. It needs
	 * proof of two spare safe hosts and six substantial reading blocks, and is
	 * withheld from media-heavy passages where the height estimate is least
	 * trustworthy.
	 */
	if ( $words >= 550 && $words < 900
		&& $ladder <= 5
		&& $safe >= $ladder + 2
		&& $substantial >= 6
		&& $media_share <= .38 ) {
		return min( 2, 7 - $ladder );
	}

	return 1;
}

/** Editorial depth targets for A-slots, with or without a Prime candidate. */
function go_verge_ads_planner_targets( $capacity ) {
	/*
	 * Prefer earlier editorial boundaries while retaining deeper alternatives.
	 *
	 * The fractions below are targets within the article's editorial word count,
	 * not measured readership, viewability or revenue. When Prime is present,
	 * its clearance constrains the first A-slot. Candidate scores, editorial
	 * boundaries and spacing can select a different depth from these targets.
	 *
	 * Browser checks still apply before a request. Current runtime defaults use
	 * 240px mobile / 300px desktop editorial clearance, a 45% article density
	 * ceiling and 42% mobile / 45% desktop local viewport-band density ceilings.
	 * These are configurable theme safeguards, not universal Google policy
	 * thresholds or permission to exceed the rendered page's usable capacity.
	 */
	$map = array(
		1 => array( .38 ),
		2 => array( .26, .46 ),
		3 => array( .24, .38, .54 ),
		4 => array( .23, .35, .47, .61 ),
		5 => array( .22, .33, .44, .55, .68 ),
		6 => array( .22, .32, .42, .52, .63, .76 ),
	);
	return $map[ max( 1, min( 6, absint( $capacity ) ) ) ] ?? array();
}

/**
 * Pick an early structurally-safe boundary using the capacity-dependent reading
 * and remaining-content requirements below, before the browser's pixel checks.
 *
 * @param array<int,array<string,mixed>> $candidates Candidate boundaries.
 * @param int                            $total_capacity Planned total body opportunities.
 * @return array<string,mixed>|null
 */
function go_verge_ads_planner_prime_candidate( $candidates, $total_capacity ) {
	$minimum_tail = $total_capacity >= 3 ? 110 : 80;
	$best = null;

	/* Capacity >= 4 permits one substantial opening unit and at least 60 words.
	 * Capacities 2-3 require two substantial units and at least 55 words; a
	 * single-opportunity article requires one unit and 65 words. The tail and
	 * protected-boundary checks remain mandatory. These are this planner's
	 * editorial choices, not a claim about Auto Ads or a format-specific rule. */
	$reach_first = $total_capacity >= 4;
	$minimum_substantial = $reach_first ? 1 : 2;
	$minimum_before = $reach_first ? 60 : 55;
	if ( 1 === (int) $total_capacity ) {
		$minimum_substantial = 1;
		$minimum_before = 65;
	}

	foreach ( $candidates as $candidate ) {
		$reasons = array();
		if ( absint( $candidate['substantialBefore'] ?? 0 ) < $minimum_substantial ) {
			$reasons[] = 'prime-before-substantial-paragraphs';
		}
		if ( absint( $candidate['beforeWords'] ?? 0 ) < $minimum_before ) {
			$reasons[] = 'prime-too-early';
		}
		if ( absint( $candidate['afterWords'] ?? 0 ) < $minimum_tail ) {
			$reasons[] = 'prime-insufficient-tail';
		}
		/* Four-paragraph news often reaches its second paragraph near the midpoint.
		 * A short article still needs real editorial tail after Prime; a percentage
		 * cut alone used to remove this high-reach unit. */
		if ( (float) ( $candidate['depth'] ?? 0 ) > ( $total_capacity <= 2 ? .58 : .46 ) ) {
			$reasons[] = 'prime-too-deep';
		}
		if ( $reasons ) {
			continue;
		}

		$score = round(
			95
			- (float) ( $candidate['depth'] ?? 0 ) * 45
			+ min( 8, absint( $candidate['beforeWords'] ?? 0 ) / 35 )
			+ min( 6, absint( $candidate['afterWords'] ?? 0 ) / 100 ),
			2
		);
		$candidate['score'] = $score;
		$candidate['placement'] = 'article-prime';

		/* Earlier safe boundary wins. Score only breaks a same-depth tie. */
		if ( null === $best
			|| absint( $candidate['beforeWords'] ) < absint( $best['beforeWords'] )
			|| ( absint( $candidate['beforeWords'] ) === absint( $best['beforeWords'] ) && $score > $best['score'] )
		) {
			$best = $candidate;
		}
	}
	return $best;
}

/**
 * Choose the fullest feasible, depth-ordered sequence with editorial clearance.
 *
 * Targets rank safe positions; they never veto them. The bounded dynamic
 * program considers up to six placements and uses a running best predecessor,
 * avoiding a quadratic candidate scan. There is no fill-rate/history feedback
 * and no request-device branch, so one cached article has a stable inventory.
 */
function go_verge_ads_planner_select( $candidates, $capacity, $prime, $gap_words, $gap_height ) {
	$candidates = array_values( array_filter( $candidates, static function ( $candidate ) {
		return $candidate['beforeWords'] >= 60 && $candidate['afterWords'] >= 60;
	} ) );
	$count = count( $candidates );
	for ( $wanted = min( 6, $capacity, $count ); $wanted >= 1; $wanted-- ) {
		$targets = go_verge_ads_planner_targets( $wanted );
		$previous_states = array();
		for ( $n = 1; $n <= $wanted; $n++ ) {
			$states = array();
			$cursor = 0;
			$best_previous = null;
			foreach ( $candidates as $j => $candidate ) {
				if ( 1 === $n ) {
					/* A1 sits directly after Prime, the two highest-reach in-body
					 * positions. Their clearance is intentionally a little tighter
					 * than the general rule — those pixels are the most valuable on
					 * the page — but never tighter than the browser's own floor
					 * expects to find once the article renders. */
					if ( $prime && ( $candidate['beforeWords'] - $prime['beforeWords'] < 70
						|| $candidate['estimatedTop'] - $prime['estimatedTop'] < 220 ) ) {
						continue;
					}
					$state = array( 'score' => 0, 'path' => array() );
				} else {
					while ( $cursor < $j
						&& $candidate['beforeWords'] - $candidates[ $cursor ]['beforeWords'] >= $gap_words
						&& $candidate['estimatedTop'] - $candidates[ $cursor ]['estimatedTop'] >= $gap_height ) {
						if ( isset( $previous_states[ $cursor ] ) && ( null === $best_previous
							|| $previous_states[ $cursor ]['score'] > $best_previous['score'] ) ) {
							$best_previous = $previous_states[ $cursor ];
						}
						$cursor++;
					}
					if ( null === $best_previous ) {
						continue;
					}
					$state = $best_previous;
				}
				$candidate['score'] = round( $candidate['baseScore'] + 30 - abs( $candidate['depth'] - $targets[ $n - 1 ] ) * 130, 2 );
				$candidate['placement'] = 'article-a' . $n;
				$state['score'] += $candidate['score'];
				$state['path'][] = $candidate;
				$states[ $j ] = $state;
			}
			$previous_states = $states;
			if ( ! $states ) {
				break;
			}
		}
		if ( $previous_states && $n > $wanted ) {
			$best = null;
			foreach ( $previous_states as $state ) {
				if ( null === $best || $state['score'] > $best['score'] ) {
					$best = $state;
				}
			}
			return $best['path'];
		}
	}
	return array();
}

/**
 * Pick up to two later safe boundaries as adaptive reserves.
 *
 * Reserves are publisher-owned hosts only. They do not increase structural
 * capacity and do not make a request while the primary ladder already occupies
 * the body target. Their purpose is to recover real-world loss: an earlier
 * provider no-fill, a host jumped by a fast reader, or a conservative server
 * estimate that real rendered geometry proves safe. Each reserve has its own
 * AdSense unit identity; the same unit is never refreshed or requested twice.
 *
 * @param array<int,array<string,mixed>> $candidates All safe candidates.
 * @param array<string,mixed>|null       $prime      Prime candidate.
 * @param array<int,array<string,mixed>> $selected   Primary A-slots.
 * @param int                            $gap_words  Editorial word clearance.
 * @param int                            $gap_height Estimated-pixel clearance.
 * @param int                            $limit      Maximum reserves.
 * @return array<int,array<string,mixed>>
 */
function go_verge_ads_planner_reserve_candidates( $candidates, $prime, $selected, $gap_words, $gap_height, $limit = 2 ) {
	$used = array_merge( $prime ? array( $prime ) : array(), (array) $selected );
	$available_ids = max( 0, 6 - count( (array) $selected ) );
	$limit = min( max( 0, absint( $limit ) ), $available_ids );
	if ( $limit < 1 ) {
		return array();
	}

	/*
	 * Reserve hosts are inert candidates, not extra budget. 4.1 only looked
	 * after the last primary slot, which made a reserve impossible exactly in
	 * many medium/short layouts where the planner missed one rung because its
	 * estimated-height spacing was conservative. Keep the primaries stable, but
	 * expose the best unused boundaries anywhere in the article. The browser
	 * may request them only when structural budget is free and its real-pixel
	 * density/spacing checks pass. This is safer than weakening primary gaps and
	 * more useful than a reserve buried after the last slot.
	 */
	$pool = array();
	foreach ( (array) $candidates as $candidate ) {
		if ( $candidate['beforeWords'] < 60 || $candidate['afterWords'] < 60 ) {
			continue;
		}
		$already_used = false;
		foreach ( $used as $existing ) {
			if ( absint( $existing['candidate'] ?? 0 ) === absint( $candidate['candidate'] ?? 0 ) ) {
				$already_used = true;
				break;
			}
		}
		if ( $already_used ) {
			continue;
		}

		$nearest_words = PHP_INT_MAX;
		$nearest_height = PHP_INT_MAX;
		foreach ( $used as $existing ) {
			$nearest_words = min( $nearest_words, abs( (int) $candidate['beforeWords'] - (int) $existing['beforeWords'] ) );
			$nearest_height = min( $nearest_height, abs( (int) $candidate['estimatedTop'] - (int) $existing['estimatedTop'] ) );
		}
		if ( ! $used ) {
			$nearest_words = $gap_words;
			$nearest_height = $gap_height;
		}

		/* Prefer high-reach alternatives that are closest to satisfying the
		 * server estimate on their own. A candidate that loses only because PHP
		 * underestimated rendered height is exactly what runtime should re-check. */
		$compat_words = min( 1, $nearest_words / max( 1, $gap_words ) );
		$compat_height = min( 1, $nearest_height / max( 1, $gap_height ) );
		$candidate['_reserveScore'] = round(
			(float) $candidate['baseScore']
			+ ( 1 - (float) $candidate['depth'] ) * 18
			+ $compat_words * 10
			+ $compat_height * 10,
			3
		);
		$pool[] = $candidate;
	}

	usort( $pool, static function ( $a, $b ) {
		if ( (float) $a['_reserveScore'] === (float) $b['_reserveScore'] ) {
			return (int) $a['beforeWords'] <=> (int) $b['beforeWords'];
		}
		return ( (float) $a['_reserveScore'] > (float) $b['_reserveScore'] ) ? -1 : 1;
	} );

	$reserves = array();
	$next_index = count( (array) $selected ) + 1;
	foreach ( $pool as $candidate ) {
		if ( count( $reserves ) >= $limit ) {
			break;
		}
		/* Avoid two shadow hosts representing effectively the same physical
		 * break. Primary overlap is intentionally allowed: if that primary later
		 * returns explicit `unfilled`, runtime can use this candidate as its safe
		 * replacement after measuring actual pixels. */
		$too_close_to_reserve = false;
		foreach ( $reserves as $existing ) {
			if ( abs( (int) $candidate['beforeWords'] - (int) $existing['beforeWords'] ) < 35
				&& abs( (int) $candidate['estimatedTop'] - (int) $existing['estimatedTop'] ) < 120 ) {
				$too_close_to_reserve = true;
				break;
			}
		}
		if ( $too_close_to_reserve ) {
			continue;
		}
		$candidate['placement'] = 'article-a' . $next_index;
		$candidate['score'] = round( (float) $candidate['_reserveScore'], 2 );
		unset( $candidate['_reserveScore'] );
		$candidate['fallback'] = true;
		$reserves[] = $candidate;
		$next_index++;
	}
	return $reserves;
}

/**
 * Pure planner used by production and CLI tests.
 *
 * @param string $html         Final article HTML.
 * @param string $article_type Editorial format: guide, review, ranking, list,
 *                             special or news. Empty behaves exactly as news.
 * @return array<string,mixed>
 */
function go_verge_ads_plan_article( $html, $article_type = '' ) {
	$article_type = sanitize_key( (string) $article_type );
	$blocks  = go_verge_ads_planner_blocks( (string) $html );
	$metrics = array(
		'words'           => 0,
		'proseWords'      => 0,
		'listWords'       => 0,
		'quoteWords'      => 0,
		'atomicTextWords' => 0,
		/* Prose + safe atomic editorial text: the length that actually determines how
		 * many safe in-body opportunities an article can carry. */
		'bodyWords'       => 0,
		'editorialWords'  => 0,
		'blocks'          => count( $blocks ),
		'substantial'     => 0,
		'lists'           => 0,
		'media'           => 0,
		'headings'        => 0,
		'estimatedHeight' => 0,
		'mediaHeight'     => 0,
	);

	foreach ( $blocks as $block ) {
		$metrics['words']           += absint( $block['words'] );
		$metrics['estimatedHeight'] += absint( $block['height'] );
		if ( 'component' !== $block['kind'] ) {
			$metrics['editorialWords'] += absint( $block['words'] );
		}
		if ( 'prose' === $block['kind'] ) {
			$metrics['proseWords'] += absint( $block['words'] );
			if ( absint( $block['words'] ) >= 22 ) {
				$metrics['substantial']++;
			}
		}
		if ( 'list' === $block['kind'] ) {
			$metrics['lists']++;
			$metrics['listWords'] += absint( $block['words'] );
			/* A list of 30+ words is at least as substantial a reading unit as a
			 * 22-word paragraph, and is a legitimate editorial neighbour. */
			if ( absint( $block['words'] ) >= 30 ) {
				$metrics['substantial']++;
			}
		}
		if ( 'quote' === $block['kind'] ) {
			$metrics['quoteWords'] += absint( $block['words'] );
			if ( absint( $block['words'] ) >= 30 ) {
				$metrics['substantial']++;
			}
		}
		if ( 'atomic_text' === $block['kind'] ) {
			$metrics['atomicTextWords'] += absint( $block['words'] );
		}
		if ( 'media' === $block['kind'] ) {
			$metrics['media']++;
			$metrics['mediaHeight'] += absint( $block['height'] );
		}
		if ( 'heading' === $block['kind'] ) {
			$metrics['headings']++;
		}
	}
	$metrics['bodyWords'] = $metrics['proseWords'] + $metrics['listWords'] + $metrics['quoteWords'] + $metrics['atomicTextWords'];

	$media_share = $metrics['mediaHeight'] / max( 1, $metrics['estimatedHeight'] );
	$profile = $media_share > .42 ? 'MEDIA_HEAVY' : ( $metrics['bodyWords'] < 620 ? 'SHORT_EDITORIAL' : ( $metrics['bodyWords'] >= 1500 ? 'LONG_EDITORIAL' : 'STANDARD_EDITORIAL' ) );

	$before             = 0;
	$height             = 0;
	$substantial_before = 0;
	$candidates         = array();
	$log                = array();
	$count              = count( $blocks );

	for ( $i = 0; $i < $count - 1; $i++ ) {
		$a = $blocks[ $i ];
		$b = $blocks[ $i + 1 ];
		/* CTA/FAQ/widget copy cannot buy more inventory or meet word gaps. */
		$before += 'component' !== $a['kind'] ? absint( $a['words'] ) : 0;
		$height += absint( $a['height'] );
		if ( ( 'prose' === $a['kind'] && absint( $a['words'] ) >= 22 )
			|| ( 'list' === $a['kind'] && absint( $a['words'] ) >= 30 )
			|| ( 'quote' === $a['kind'] && absint( $a['words'] ) >= 30 ) ) {
			$substantial_before++;
		}
		$after   = max( 0, $metrics['editorialWords'] - $before );
		$reasons = array();

		/* Section break: the end of a substantial paragraph right before the next
		 * H2/H3 that opens a section with content. This is the natural pause in
		 * listicles and guides ("H2 + image + paragraph" items), where two
		 * consecutive paragraphs rarely exist; without it a 1,100-word list could
		 * receive a single in-body unit. The ad never separates a heading from its
		 * own text: it closes the previous section. */
		$editorial_a = in_array( $a['kind'], array( 'prose', 'list', 'quote' ), true );
		$editorial_b = in_array( $b['kind'], array( 'prose', 'list', 'quote' ), true );

		$section_break = $editorial_a
			&& 'heading' === $b['kind']
			&& in_array( (string) $b['tag'], array( 'h2', 'h3' ), true )
			&& absint( $a['words'] ) >= 25
			&& isset( $blocks[ $i + 2 ] );

		if ( ! $section_break && ( ! $editorial_a || ! $editorial_b ) ) {
			$reasons[] = 'protected-neighbour:' . $a['kind'] . '/' . $b['kind'];
		}
		if ( ! $section_break && ( absint( $a['words'] ) < 18 || absint( $b['words'] ) < 18 ) ) {
			$reasons[] = 'insufficient-paragraph';
		}

		$penalty = 0;
		/* The block after a section heading is that section's own content (often
		 * its image): it is not a neighbour of the ad, so it is not penalised. */
		foreach ( $section_break ? array( $i - 1 ) : array( $i - 1, $i + 2 ) as $neighbour ) {
			if ( isset( $blocks[ $neighbour ] ) && ! in_array( $blocks[ $neighbour ]['kind'], array( 'prose', 'list', 'quote' ), true ) ) {
				$penalty += 7;
			}
		}
		$pair_words = $section_break ? absint( $a['words'] ) : min( absint( $a['words'] ), absint( $b['words'] ) );

		$entry = array(
			'candidate'         => $i + 1,
			'position'          => absint( $a['end'] ),
			'beforeWords'       => $before,
			'afterWords'        => $after,
			'substantialBefore' => $substantial_before,
			'estimatedTop'      => $height,
			'depth'             => round( $before / max( 1, $metrics['editorialWords'] ), 4 ),
			'sectionBreak'      => $section_break,
			'reasons'           => $reasons,
		);
		$entry['baseScore'] = round(
			28
			+ min( 14, $pair_words / 3 )
			+ min( 9, $before / 55 )
			+ min( 9, $after / 55 )
			- $penalty
			- $media_share * 7,
			2
		);
		$log[] = $entry;
		if ( ! $reasons ) {
			$candidates[] = $entry;
		}
	}

	/*
	 * One structural ceiling, then real safe boundaries and clearance.
	 *
	 * The ladder reads editorial length and format; the headroom step reads
	 * rendered evidence from this specific article. Nothing beyond this point
	 * consults revenue: the question "has this SESSION earned more inventory?"
	 * belongs to the browser, which can see the reader.
	 */
	$ladder = min( go_verge_ads_planner_capacity_from_words( $metrics['bodyWords'], $article_type ), count( $candidates ) );
	$headroom = go_verge_ads_planner_structural_headroom( $metrics, $candidates, $ladder );
	$total_capacity = min( 7, count( $candidates ), $ladder + $headroom );
	/*
	 * Short editorial stories are not categorically zeroed. A single safe
	 * opportunity is allowed from 240 words when there is one substantial
	 * reading unit and real editorial tail. Pages capable of two or more body
	 * units still require at least two substantial units.
	 */
	$minimum_substantial = $total_capacity <= 1 ? 1 : 2;
	if ( $metrics['bodyWords'] < 240 || $metrics['substantial'] < $minimum_substantial ) {
		$total_capacity = 0;
	}
	$prime = $total_capacity ? go_verge_ads_planner_prime_candidate( $candidates, $total_capacity ) : null;
	$clearance  = go_verge_ads_planner_clearance();
	$gap_words  = absint( $clearance['words'] );
	$gap_height = absint( $clearance['height'] );

	/* Prime is valuable, but it must not cost an entire safe body opportunity.
	 * Compare the Prime-first ladder with a no-Prime ladder using the same
	 * editorial clearance. If removing Prime exposes one more structurally safe
	 * host, prefer the fuller ladder; when counts tie, keep Prime as the higher-
	 * reach/value first break. Runtime still enforces actual pixel density. */
	$a_capacity_with_prime = min( 6, max( 0, $total_capacity - ( $prime ? 1 : 0 ) ) );
	$selected_with_prime = go_verge_ads_planner_select( $candidates, $a_capacity_with_prime, $prime, $gap_words, $gap_height );
	$planned_with_prime = count( $selected_with_prime ) + ( $prime ? 1 : 0 );

	$selected_without_prime = go_verge_ads_planner_select( $candidates, min( 6, $total_capacity ), null, $gap_words, $gap_height );
	$planned_without_prime = count( $selected_without_prime );
	if ( $planned_without_prime > $planned_with_prime ) {
		$prime = null;
		$selected = $selected_without_prime;
	} else {
		$selected = $selected_with_prime;
	}
	$a_capacity = min( 6, max( 0, $total_capacity - ( $prime ? 1 : 0 ) ) );
	$planned_count = count( $selected ) + ( $prime ? 1 : 0 );
	/*
	 * Reserve hosts: rendered, inert, and opened only by the Revenue Governor.
	 *
	 * They recover the positions editorial clearance could not place inside the
	 * ceiling, plus exactly one opportunity above it for a reader who proves
	 * real depth and dwell. They are never budget on their own — the browser
	 * only reaches them in EXPANSION, and every density rule still applies.
	 */
	$reserve_limit = min( 2, max( 0, $total_capacity - $planned_count ) + ( $total_capacity > 0 ? 1 : 0 ), max( 0, 7 - $planned_count ) );
	$reserves = go_verge_ads_planner_reserve_candidates( $candidates, $prime, $selected, $gap_words, $gap_height, $reserve_limit );
	$reserve = $reserves ? $reserves[0] : null;
	$decisions = array();
	foreach ( array_merge( $prime ? array( $prime ) : array(), $selected, $reserves ) as $placement ) {
		$decisions[] = array(
			'placement' => $placement['placement'],
			'candidate' => $placement['candidate'],
			'score' => $placement['score'],
			'reasons' => ! empty( $placement['fallback'] ) ? array( 'adaptive-reserve' ) : array(),
		);
	}
	$rendered_count = $planned_count + count( $reserves );
	/*
	 * `totalCapacity` is what EXPANSION may reach: every host actually exposed
	 * to the browser, bounded by the contract maximum. `plannedCount` is the
	 * STANDARD budget. Word length is a ceiling, not proof that N usable hosts
	 * exist, so capacity is never reported above what was rendered.
	 */
	$structural_capacity = min( 7, $rendered_count );
	if ( $planned_count < $total_capacity ) {
		$decisions[] = array(
			'placement' => 'article',
			'candidate' => 0,
			'score' => 0,
			'reasons' => array( 'editorial-clearance-limited' ),
			'planned' => $planned_count,
			'budget' => $total_capacity,
		);
	}

	return array(
		'profile'       => $profile,
		'articleType'   => $article_type,
		'metrics'       => $metrics,
		'ladderCapacity' => $ladder,
		'headroom'      => $headroom,
		'totalCapacity' => $structural_capacity,
		'plannedCount'  => $planned_count,
		'renderedCount' => $rendered_count,
		'reserveCount'  => count( $reserves ),
		'version'       => '19.0.0-manual-governor',
		'capacity'      => $a_capacity,
		'prime'         => $prime,
		'reserve'       => $reserve,
		'reserves'      => $reserves,
		'candidates'    => $log,
		'decisions'     => $decisions,
		'selected'      => $selected,
	);
}
