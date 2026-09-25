/**
 * Overdrive — Verge
 * Vanilla interactions: offcanvas drawer, search overlay, scroll lock, sticky shadow.
 */
(function () {
	'use strict';

	var body = document.body;

	/*
	 * Scroll lock — on <html>, never on <body>. This is the fix for the header
	 * that got stranded in the middle of the page, and the mechanism is worth
	 * stating precisely, because it explains why the bug was intermittent.
	 *
	 * `.go-header` is `position: sticky`, so it sticks inside its nearest
	 * scrolling ancestor. `overflow: hidden` on <body> would normally make <body>
	 * exactly that — but usually does not, because of viewport propagation: while
	 * <html> computes to `overflow: visible`, the UA propagates <body>'s overflow
	 * up to the viewport and <body> itself keeps behaving as `visible`. That is
	 * why the old `body.go-lock { overflow: hidden }` appeared to work.
	 *
	 * It stops working the moment anything else sets an overflow on <html> — a
	 * lightbox, a consent modal, a second scroll-lock implementation, a provider
	 * script. Propagation no longer applies, <body> becomes a real scroll
	 * container, and the sticky header re-anchors to it: measured in the harness,
	 * opening the drawer 2.000px down left the header at -2000px, scrolled away
	 * with the document. Two independently harmless pieces of CSS, one broken
	 * header, only in combination — hence a bug that came and went.
	 *
	 * Locking <html> removes both halves. The viewport stays the sticky
	 * scrollport, the scroll offset is preserved without moving anything, and the
	 * companion rule `html.go-lock body { overflow: visible }` in
	 * header-ads-architecture.css neutralises the legacy declaration even if
	 * something re-adds the class to <body>.
	 */
	var lockRoot = document.documentElement;

	function lock() { lockRoot.classList.add('go-lock'); }
	function unlock() { lockRoot.classList.remove('go-lock'); }

	// `inert` keeps the closed drawer/search out of the tab order and the
	// accessibility tree, so aria-hidden never wraps focusable descendants.
	function openEl(el) { if (el) { el.classList.add('is-open'); el.setAttribute('aria-hidden', 'false'); el.removeAttribute('inert'); } }
	function closeEl(el) { if (el) { el.classList.remove('is-open'); el.setAttribute('aria-hidden', 'true'); el.setAttribute('inert', ''); } }

	// Publisher controls share one state, expose aria-expanded, and restore focus.
	var offcanvas = document.getElementById('go-offcanvas');
	var backdrop = document.getElementById('go-offcanvas-backdrop');
	var search = document.getElementById('go-search');
	var menuTrigger = null;
	var searchTrigger = null;
	var inertedForMenu = [];
	function expanded(name, state) {
		document.querySelectorAll('[data-go-toggle="' + name + '"]').forEach(function (button) {
			button.setAttribute('aria-expanded', state ? 'true' : 'false');
		});
	}
	function restoreFocus(el) {
		if (el && el.isConnected && el.focus) { el.focus({ preventScroll: true }); }
	}
	function openOffcanvas(trigger) {
		if (!offcanvas || offcanvas.classList.contains('is-open')) { return; }
		closeSearch(false);
		menuTrigger = trigger || document.activeElement;
		openEl(offcanvas);
		openEl(backdrop);
		expanded('offcanvas', true);
		lock();
		var first = offcanvas.querySelector('[data-go-close="offcanvas"]');
		if (first) { first.focus({ preventScroll: true }); }
		// Only the page shell becomes inert. Ad nodes/iframes are never mutated.
		inertedForMenu = [];
		['masthead', 'go-main', 'colophon'].forEach(function (id) {
			var node = document.getElementById(id);
			if (node && !node.hasAttribute('inert')) { node.setAttribute('inert', ''); inertedForMenu.push(node); }
		});
	}
	function closeOffcanvas(restore) {
		if (!offcanvas || !offcanvas.classList.contains('is-open')) { return; }
		inertedForMenu.forEach(function (node) { node.removeAttribute('inert'); });
		inertedForMenu = [];
		expanded('offcanvas', false);
		unlock();
		if (restore !== false) { restoreFocus(menuTrigger); }
		closeEl(offcanvas);
		closeEl(backdrop);
	}
	// Anchor to the visible masthead, including Top Scroll and admin-bar offsets.
	function positionSearch() {
		if (!search || !search.classList.contains('is-open')) { return; }
		var masthead = document.getElementById('masthead');
		var anchor = searchTrigger || document.querySelector('[data-go-toggle="search"]');
		if (!masthead || !anchor) { return; }
		var viewport = window.visualViewport;
		var x = viewport ? viewport.offsetLeft : 0;
		var y = viewport ? viewport.offsetTop : 0;
		var vw = viewport ? viewport.width : document.documentElement.clientWidth || window.innerWidth;
		var vh = viewport ? viewport.height : window.innerHeight;
		var width = Math.max(0, Math.min(500, vw - 24));
		var left = Math.max(x + 12, Math.min(anchor.getBoundingClientRect().right - width, x + vw - width - 12));
		var top = Math.max(y + 8, masthead.getBoundingClientRect().bottom + 8);
		// Keep the form usable when the mobile keyboard reduces the viewport.
		top = Math.min(top, Math.max(y + 8, y + vh - 220));
		search.style.setProperty('--od-search-left', Math.round(left) + 'px');
		search.style.setProperty('--od-search-top', Math.round(top) + 'px');
		search.style.setProperty('--od-search-width', Math.floor(width) + 'px');
		search.style.setProperty('--od-search-max-height', Math.max(0, Math.floor(y + vh - top - 12)) + 'px');
	}
	if (window.visualViewport) {
		window.visualViewport.addEventListener('resize', positionSearch, { passive: true });
		window.visualViewport.addEventListener('scroll', positionSearch, { passive: true });
	}
	function openSearch(trigger) {
		if (!search) { return; }
		if (search.classList.contains('is-open')) { closeSearch(); return; }
		closeOffcanvas(false);
		searchTrigger = trigger || document.activeElement;
		openEl(search);
		positionSearch();
		expanded('search', true);
		var input = search.querySelector('input[type="search"]');
		if (input) { input.focus({ preventScroll: true }); }
	}
	function closeSearch(restore) {
		if (!search || !search.classList.contains('is-open')) { return; }
		expanded('search', false);
		if (restore !== false) { restoreFocus(searchTrigger); }
		closeEl(search);
	}

	// ---- Delegated triggers ----
	document.addEventListener('click', function (e) {
		/* The mobile wordmark is navigation, never an offcanvas gesture. */
		var headerBrand = e.target.closest && e.target.closest('.go-header__brand, .od-masthead__brand');
		if (headerBrand) { return; }

		var toggle = e.target.closest('[data-go-toggle]');
		if (toggle) {
			e.preventDefault();
			var what = toggle.getAttribute('data-go-toggle');
			if (what === 'offcanvas') { openOffcanvas(toggle); }
			if (what === 'search') { openSearch(toggle); }
			return;
		}

		var close = e.target.closest('[data-go-close]');
		if (close) {
			e.preventDefault();
			var target = close.getAttribute('data-go-close');
			if (target === 'offcanvas' || target === 'all') { closeOffcanvas(); }
			if (target === 'search' || target === 'all') { closeSearch(); }
			return;
		}

		// In-page destinations must release the modal before scrolling/focusing.
		var menuAnchor = e.target.closest('[data-go-menu-anchor]');
		if (menuAnchor) {
			var anchorId = (menuAnchor.getAttribute('href') || '').slice(1);
			var destination = anchorId ? document.getElementById(anchorId) : null;
			if (destination) {
				e.preventDefault();
				closeOffcanvas(false);
				destination.focus({ preventScroll: true });
				destination.scrollIntoView({ behavior: 'auto', block: 'start' });
			}
			return;
		}

		// Click on the backdrop closes the drawer.
		if (backdrop && e.target === backdrop) { closeOffcanvas(); return; }

		if (
			search
			&& search.classList.contains('is-open')
			&& !e.target.closest('.go-search__inner')
			&& !e.target.closest('[data-go-toggle="search"]')
		) {
			closeSearch(search.contains(document.activeElement));
		}
	});

	// The modal menu traps focus; search is a non-modal popover and dismisses
	// when keyboard focus leaves it. ESC returns to the opening control.
	document.addEventListener('keydown', function (e) {
		if (e.key === 'Escape' || e.keyCode === 27) { closeOffcanvas(); closeSearch(); return; }
		if (e.key !== 'Tab' || !offcanvas || !offcanvas.classList.contains('is-open')) { return; }
		var items = Array.prototype.slice.call(offcanvas.querySelectorAll('a[href],button:not(:disabled),input:not(:disabled),[tabindex="0"]')).filter(function (node) { return !node.closest('[inert], [hidden]') && node.getClientRects().length; });
		if (!items.length) { return; }
		var first = items[0], last = items[items.length - 1];
		if (e.shiftKey && (document.activeElement === first || !offcanvas.contains(document.activeElement))) { e.preventDefault(); last.focus(); }
		else if (!e.shiftKey && (document.activeElement === last || !offcanvas.contains(document.activeElement))) { e.preventDefault(); first.focus(); }
	});
	document.addEventListener('focusin', function (event) {
		if (search && search.classList.contains('is-open') && !search.contains(event.target) && !event.target.closest('[data-go-toggle="search"]')) { closeSearch(false); }
	});

	// ---- Editorial header: Kotaku-like expanded/compact behavior ----
	var header = document.querySelector('.od-masthead, .go-header--editorial');
	var latestBar = document.querySelector('[data-go-latest-bar]');

	if (header) {
		var latestBarHomeMode = !!(latestBar && latestBar.getAttribute('data-go-latest-home') === 'true');
		var headerFrame = 0;

		// The shell keeps its original height while the visible masthead compacts.
		var publisherHeader = header.classList.contains('od-masthead');
		var publisherNav = publisherHeader && header.querySelector('.od-masthead__nav');
		var condensed = false;
		function syncPublisherHeader(y) {
			if (!publisherHeader) { return; }
			var next = condensed ? y > 64 : y > 180;
			if (next === condensed) { return; }
			condensed = next;
			if (publisherNav && next && publisherNav.contains(document.activeElement)) {
				var menuButton = header.querySelector('[data-go-toggle="offcanvas"]');
				if (menuButton) { menuButton.focus({ preventScroll: true }); }
			}
			header.classList.toggle('is-condensed', next);
			if (publisherNav) {
				publisherNav.hidden = next;
				publisherNav.toggleAttribute('inert', next);
				publisherNav.setAttribute('aria-hidden', next ? 'true' : 'false');
			}
			var visibleHeight = Math.round(header.getBoundingClientRect().height);
			if (visibleHeight > 0) { document.documentElement.style.setProperty('--go-header-height', visibleHeight + 'px'); }
		}

		function syncLatestBar(hidden) {
			if (!latestBar) { return; }

			/* Keep the existing editorial rail exclusive to the front page. */
			if (!latestBarHomeMode) { hidden = true; }

			latestBar.classList.toggle('is-hidden', hidden);
			latestBar.setAttribute('aria-hidden', hidden ? 'true' : 'false');

			if (hidden) {
				latestBar.setAttribute('inert', '');
			} else {
				latestBar.removeAttribute('inert');
			}

			try { latestBar.inert = hidden; } catch (error) {}
		}

		/*
		 * The EM ALTA rail is a first-screen orientation device: it earns its
		 * space while the reader is deciding what to read and becomes noise once
		 * they have committed to scrolling. So it retracts on the way down and
		 * comes back at the top.
		 *
		 * Two thresholds, not one, because a single coordinate makes the rail
		 * flicker open and shut for anyone resting near it. It hides after the
		 * opening area and only returns when the reader is genuinely back at top.
		 *
		 * This drives `.is-hidden` ON THE RAIL. It must never drive `is-compact`
		 * on the header: five legacy stylesheets read that class as "hide the
		 * logo too", which is the regression that removed the wordmark from every
		 * page. The rail owns its own visibility.
		 */
		var LATEST_BAR_HIDE_Y = 120;
		var LATEST_BAR_SHOW_Y = 16;
		var latestBarHidden = !latestBarHomeMode;

		function applyHeaderState() {
			headerFrame = 0;
			var y = Math.max(0, window.scrollY || window.pageYOffset || 0);

			/* Compact the publisher masthead; the shell never changes height. */
			header.classList.toggle('is-stuck', y > 8);
			syncPublisherHeader(y);
			positionSearch();

			if (!latestBarHomeMode) { return; }

			if (!latestBarHidden && y >= LATEST_BAR_HIDE_Y) {
				latestBarHidden = true;
				syncLatestBar(true);
			} else if (latestBarHidden && y <= LATEST_BAR_SHOW_Y) {
				latestBarHidden = false;
				syncLatestBar(false);
			}
		}

		function scheduleHeaderState() {
			if (headerFrame) { return; }
			headerFrame = window.requestAnimationFrame(applyHeaderState);
		}

		/*
		 * `is-header-ready` only. Never add `is-compact` here.
		 *
		 * Five stylesheets still read `is-compact` as the two-state design's
		 * "scrolled" signal: it hides `.go-header__logo-full` and collapses the EM
		 * ALTA bar to max-height 0, several with `!important`. Adding it to a
		 * header that is permanently compact hides the logo and the bar on every
		 * page. The compact geometry comes from CSS, unconditionally.
		 */
		header.classList.add('is-header-ready');
		header.classList.remove('is-compact');
		syncLatestBar(!latestBarHomeMode);

		/*
		 * Publish the header's real border-box height so the EM ALTA rail can sit
		 * exactly on its bottom edge.
		 *
		 * The rail is sticky and needs a `top`, but CSS cannot read a sibling's
		 * height, so it used a constant — and the constant was the content height
		 * (58px) while the header actually measures 59px with its bottom border.
		 * One pixel of overlap, plus another two from rounding, which is visible
		 * as the rail sitting slightly over the header's rule.
		 *
		 * Measuring removes the class of bug entirely: change the padding, the
		 * font, the border, or the logo size, and the rail follows without anyone
		 * remembering to update a number.
		 */
		if ('ResizeObserver' in window) {
			var publishHeaderHeight = function () {
				var h = Math.round(header.getBoundingClientRect().height);
				if (h > 0) {
					document.documentElement.style.setProperty('--go-header-height', h + 'px');
				}
			};
			new ResizeObserver(function () { publishHeaderHeight(); positionSearch(); }).observe(header);
			publishHeaderHeight();
		}

		window.addEventListener('scroll', scheduleHeaderState, { passive: true });
		window.addEventListener('resize', scheduleHeaderState, { passive: true });
		window.addEventListener('pageshow', scheduleHeaderState);
		applyHeaderState();
	}

	// ---- Header social menu ----
	var social = document.querySelector('[data-go-social]');
	var socialToggle = social && social.querySelector('[data-go-social-toggle]');
	var socialMenu = social && social.querySelector('[data-go-social-menu]');

	function closeSocial() {
		if (!social || !socialToggle || !socialMenu) { return; }
		social.classList.remove('is-open');
		socialToggle.setAttribute('aria-expanded', 'false');
		socialMenu.setAttribute('aria-hidden', 'true');
	}

	if (social && socialToggle && socialMenu) {
		socialToggle.addEventListener('click', function (e) {
			e.preventDefault();
			e.stopPropagation();
			var open = social.classList.toggle('is-open');
			socialToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
			socialMenu.setAttribute('aria-hidden', open ? 'false' : 'true');
		});

		document.addEventListener('click', function (e) {
			if (!social.contains(e.target)) { closeSocial(); }
		});

		document.addEventListener('keydown', function (e) {
			if (e.key === 'Escape' || e.keyCode === 27) { closeSocial(); }
		});
	}



	// ---- Preferred-source CTA toast ----
	var preferredToast = document.querySelector('[data-go-preferred-toast]');

	if (preferredToast) {
		var preferredClose = preferredToast.querySelector('[data-go-preferred-toast-close]');
		var preferredAccept = preferredToast.querySelector('[data-go-preferred-toast-accept]');
		var preferredKey = 'go-preferred-toast-v5';
		var preferredShown = false;
		var preferredEligible = false;
		var preferredRetry = 0;
		var preferredGuardFrame = 0;

		function preferredState() {
			try {
				var raw = localStorage.getItem(preferredKey) || localStorage.getItem('go-preferred-toast-v4');
				return raw ? JSON.parse(raw) : null;
			} catch (error) {
				return null;
			}
		}

		function preferredSave(kind, days) {
			try {
				localStorage.setItem(preferredKey, JSON.stringify({
					kind: kind,
					until: Date.now() + (days * 86400000)
				}));
			} catch (error) {}
		}

		function preferredAllowed() {
			var state = preferredState();
			var desktop = !window.matchMedia || window.matchMedia('(min-width: 769px)').matches;
			return desktop && (!state || !state.until || Date.now() >= Number(state.until));
		}

		function preferredVideoInView() {
			var nodes = document.querySelectorAll('video, iframe[src*="youtube"], iframe[src*="vimeo"], [data-go-video-hub], .wp-block-embed-youtube, .wp-block-video');
			for (var i = 0; i < nodes.length; i += 1) {
				var rect = nodes[i].getBoundingClientRect();
				var visibleWidth = Math.min(rect.right, window.innerWidth) - Math.max(rect.left, 0);
				var visibleHeight = Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0);
				if (visibleWidth > 40 && visibleHeight > 40) { return true; }
			}
			return false;
		}

		function preferredGuardOpen() {
			if (preferredGuardFrame || !preferredShown || !preferredToast.classList.contains('is-open')) { return; }
			preferredGuardFrame = window.requestAnimationFrame(function () {
				preferredGuardFrame = 0;
				if (preferredVideoInView()) { preferredDismiss('video-visible', 30); }
			});
		}

		function preferredTryOpen() {
			window.clearTimeout(preferredRetry);
			if (!preferredEligible || preferredShown || !preferredAllowed()) { return; }
			if (preferredVideoInView()) {
				preferredRetry = window.setTimeout(preferredTryOpen, 5000);
				return;
			}
			preferredShown = true;
			preferredSave('shown', 30);
			preferredToast.classList.add('is-open');
			preferredToast.setAttribute('aria-hidden', 'false');
			window.removeEventListener('scroll', preferredScrollCheck);
			window.addEventListener('scroll', preferredGuardOpen, { passive: true });
			window.addEventListener('resize', preferredGuardOpen, { passive: true });
		}

		function preferredQualify() {
			if (preferredEligible) { return; }
			preferredEligible = true;
			preferredTryOpen();
		}

		function preferredScrollCheck() {
			var root = document.documentElement;
			var y = Math.max(window.scrollY || 0, window.pageYOffset || 0, root.scrollTop || 0);
			var available = Math.max(1, root.scrollHeight - window.innerHeight);
			if ((y / available) >= 0.60) { preferredQualify(); }
		}

		function preferredDismiss(kind, days) {
			window.clearTimeout(preferredRetry);
			if (preferredGuardFrame) { window.cancelAnimationFrame(preferredGuardFrame); preferredGuardFrame = 0; }
			window.removeEventListener('scroll', preferredGuardOpen);
			window.removeEventListener('resize', preferredGuardOpen);
			preferredToast.classList.remove('is-open');
			preferredToast.setAttribute('aria-hidden', 'true');
			preferredSave(kind, days);
		}

		if (preferredAllowed()) {
			window.addEventListener('scroll', preferredScrollCheck, { passive: true });
			window.setTimeout(preferredQualify, 45000);
			preferredScrollCheck();
		}

		if (preferredClose) {
			preferredClose.addEventListener('click', function () {
				preferredDismiss('dismissed', 30);
			});
		}

		if (preferredAccept) {
			preferredAccept.addEventListener('click', function () {
				preferredDismiss('accepted', 365);
			});
		}

		window.addEventListener('resize', function () {
			if (!preferredAllowed() && preferredToast.classList.contains('is-open')) {
				preferredToast.classList.remove('is-open');
				preferredToast.setAttribute('aria-hidden', 'true');
			}
		}, { passive: true });
	}


	// ---- Current year (footer) ----
	var years = document.querySelectorAll('[data-go-year]');
	if (years.length) {
		var y = new Date().getFullYear();
		years.forEach(function (n) { n.textContent = y; });
	}

	// ---- Color mode toggle ----
	// The <head> inline script already set the initial data-theme before
	// paint (localStorage, falling back to prefers-color-scheme). This just
	// wires the header button to flip it and persist the choice.
	var toggles = document.querySelectorAll('[data-go-theme-toggle]');
	if (toggles.length) {
		toggles.forEach(function (btn) {
			btn.addEventListener('click', function () {
				var current = document.documentElement.getAttribute('data-theme');
				var next = current === 'light-mode' ? 'dark-mode' : 'light-mode';
				document.documentElement.setAttribute('data-theme', next);
				try { localStorage.setItem('go-theme', next); } catch (e) {}
			});
		});
	}
})();

/*
 * Infinite loading lives in assets/js/overdrive-v8-hotfix.js — one controller,
 * one binding, one request in flight. The 250-line duplicate that used to sit
 * here had been disabled with an early `return` and was still being parsed and
 * shipped to every reader.
 */

// Shared utility controls: copy/share, back-to-top and image zoom.
(function () {
	'use strict';

	// Copy-link buttons in the header share menu.
	document.querySelectorAll('[data-go-copy-url]').forEach(function (button) {
		button.addEventListener('click', function () {
			var url = button.getAttribute('data-go-copy-url') || window.location.href;
			var done = function () {
				var original = button.textContent;
				button.textContent = 'Link copiado';
				button.classList.add('is-copied');
				window.setTimeout(function () {
					button.textContent = original;
					button.classList.remove('is-copied');
				}, 1600);
			};

			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(url).then(done).catch(function () {});
			}
		});
	});

	// Native share in the offcanvas, with copy-link fallback on desktop.
	document.querySelectorAll('[data-go-native-share]').forEach(function (button) {
		// The header disclosure owns its own native-share listener below.
		if (button.closest('[data-go-share-more]')) return;
		var feedback = button.querySelector('[data-go-share-feedback]');
		if (!navigator.share && feedback) {
			button.setAttribute('aria-label', 'Copiar link');
			button.title = 'Copiar link';
			feedback.textContent = 'Copiar link';
		}
		button.addEventListener('click', function () {
			var url = button.getAttribute('data-share-url') || button.getAttribute('data-url') || window.location.href;
			var title = button.getAttribute('data-share-title') || button.getAttribute('data-title') || document.title;
			if (navigator.share) {
				navigator.share({ title: title, url: url }).catch(function () {});
				return;
			}
			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(url).then(function () {
					var label = feedback || button;
					var original = label.textContent;
					label.textContent = 'Link copiado';
					button.setAttribute('aria-label', 'Link copiado');
					window.setTimeout(function () { label.textContent = original; button.setAttribute('aria-label', 'Copiar link'); }, 1600);
				}).catch(function () {});
			}
		});
	});

	// Back to top on every page.
	var backtop = document.querySelector('[data-go-backtop]');
	if (backtop) {
		var backtopFrame = 0;
		var updateBacktop = function () {
			backtopFrame = 0;
			backtop.classList.toggle('is-visible', window.scrollY > 520);
		};
		var scheduleBacktop = function () {
			if (!backtopFrame) { backtopFrame = window.requestAnimationFrame(updateBacktop); }
		};
		window.addEventListener('scroll', scheduleBacktop, { passive: true });
		updateBacktop();
		backtop.addEventListener('click', function () {
			window.scrollTo({ top: 0, behavior: 'smooth' });
		});
	}

	// Editorial image viewer. Native WordPress galleries and Gutenberg galleries
	// become real, navigable image sets while standalone article images keep zoom.
	(function () {
		'use strict';

		var imageSelector = [
			'.entry-content.go-single__content img',
			'.go-institutional__hero img',
			'.go-institutional__content img',
			'.single-games .go-gamecard__media img',
			'.single-games .go-gamecard__gallery img'
		].join(', ');
		var images = Array.prototype.slice.call(document.querySelectorAll(imageSelector));
		if (!images.length) { return; }

		var excludedSelector = [
			'.google-auto-placed', '.adsbygoogle-noablate', 'ins.adsbygoogle', '[data-go-ad-placement]',
			'.go-inline-related', '.go-after-article', '.go-author-card', '.go-single__avatar',
			'.go-ad', '.go-newsletter', '.go-promo', '.go-video-card', '.go-video-hub',
			'.go-share', '.go-accessibility', '[data-go-related]', '[data-go-video-item]'
		].join(', ');
		images = images.filter(function (img) {
			return img.getAttribute('data-go-no-lightbox') !== '1' && !img.classList.contains('emoji') && !img.closest(excludedSelector);
		});
		if (!images.length) { return; }

		var gallerySelector = '.wp-block-gallery, .gallery, .blocks-gallery-grid, .go-gamecard__gallery';
		var groups = [];
		var imageMeta = new WeakMap();

		function cleanText(value) {
			return String(value || '').replace(/\s+/g, ' ').trim();
		}

		function fullImageSource(img) {
			var link = img.closest('a[href]');
			var href = link ? link.getAttribute('href') : '';
			if (href && /\.(?:avif|gif|jpe?g|png|webp)(?:[?#].*)?$/i.test(href)) { return href; }
			return img.getAttribute('data-full-url') || img.currentSrc || img.src || '';
		}

		function imageCaption(img) {
			var figure = img.closest('figure, .gallery-item');
			var caption = figure ? figure.querySelector('figcaption, .gallery-caption, .wp-caption-text') : null;
			return cleanText(caption ? caption.textContent : (img.getAttribute('data-caption') || img.getAttribute('title') || ''));
		}

		function buildItem(img) {
			return {
				img: img,
				src: fullImageSource(img),
				alt: cleanText(img.alt || ''),
				caption: imageCaption(img)
			};
		}

		var galleryContainers = [];
		images.forEach(function (img) {
			var container = img.closest(gallerySelector);
			if (container && galleryContainers.indexOf(container) === -1) { galleryContainers.push(container); }
		});

		galleryContainers.forEach(function (container) {
			var galleryImages = images.filter(function (img) { return img.closest(gallerySelector) === container; });
			if (!galleryImages.length) { return; }
			var group = galleryImages.map(buildItem).filter(function (item) { return !!item.src; });
			if (!group.length) { return; }
			var groupIndex = groups.push(group) - 1;
			container.classList.add('go-editorial-gallery');
			container.classList.toggle('is-single', group.length === 1);
			container.classList.toggle('is-pair', group.length === 2);
			container.classList.toggle('is-featured-layout', group.length >= 3);
			container.setAttribute('data-go-gallery-count', String(group.length));
			var wrappers = [];
			group.forEach(function (item, index) {
				imageMeta.set(item.img, { group: groupIndex, index: index });
				var wrapper = item.img.closest('figure, .gallery-item, .blocks-gallery-item');
				if (wrapper && container.contains(wrapper)) {
					wrapper.classList.add('go-editorial-gallery__item');
					wrapper.setAttribute('data-go-slide-index', String(index));
					wrappers.push(wrapper);
					if (index === 0) { wrapper.classList.add('is-active'); }
				}
			});

			if (group.length > 1 && wrappers.length > 1) {
				container.classList.add('go-gallery-slider');
				var controls = document.createElement('div');
				controls.className = 'go-gallery-slider__controls';
				controls.innerHTML = '' +
					'<button type="button" class="go-gallery-slider__button" data-go-gallery-prev aria-label="Foto anterior">‹</button>' +
					'<span class="go-gallery-slider__counter" aria-live="polite">1 / ' + group.length + '</span>' +
					'<button type="button" class="go-gallery-slider__button" data-go-gallery-next aria-label="Próxima foto">›</button>';
				container.appendChild(controls);

				var currentSlide = 0;
				var counterNode = controls.querySelector('.go-gallery-slider__counter');
				var updateSlide = function (nextIndex, smooth) {
					currentSlide = (nextIndex + wrappers.length) % wrappers.length;
					var target = wrappers[currentSlide];
					wrappers.forEach(function (wrapper, index) { wrapper.classList.toggle('is-active', index === currentSlide); });
					if (container.scrollTo) { container.scrollTo({ left: target.offsetLeft, behavior: smooth === false ? 'auto' : 'smooth' }); }
					if (counterNode) { counterNode.textContent = (currentSlide + 1) + ' / ' + wrappers.length; }
				};
				controls.querySelector('[data-go-gallery-prev]').addEventListener('click', function (event) {
					event.preventDefault(); event.stopPropagation(); updateSlide(currentSlide - 1, true);
				});
				controls.querySelector('[data-go-gallery-next]').addEventListener('click', function (event) {
					event.preventDefault(); event.stopPropagation(); updateSlide(currentSlide + 1, true);
				});
				var scrollTimer = 0;
				container.addEventListener('scroll', function () {
					window.clearTimeout(scrollTimer);
					scrollTimer = window.setTimeout(function () {
						var nearest = 0;
						var distance = Infinity;
						wrappers.forEach(function (wrapper, index) {
							var diff = Math.abs(wrapper.offsetLeft - container.scrollLeft);
							if (diff < distance) { distance = diff; nearest = index; }
						});
						currentSlide = nearest;
						wrappers.forEach(function (wrapper, index) { wrapper.classList.toggle('is-active', index === currentSlide); });
						if (counterNode) { counterNode.textContent = (currentSlide + 1) + ' / ' + wrappers.length; }
					}, 80);
				}, { passive: true });
			}
		});

		images.forEach(function (img) {
			if (imageMeta.has(img)) { return; }
			var groupIndex = groups.push([buildItem(img)]) - 1;
			imageMeta.set(img, { group: groupIndex, index: 0 });
		});

		var lightbox = document.createElement('div');
		lightbox.className = 'go-lightbox';
		lightbox.setAttribute('aria-hidden', 'true');
		lightbox.setAttribute('role', 'dialog');
		lightbox.setAttribute('aria-modal', 'true');
		lightbox.setAttribute('aria-label', 'Visualizador de imagens');
		lightbox.innerHTML = '' +
			'<div class="go-lightbox__toolbar" role="toolbar" aria-label="Controles da imagem">' +
				'<button type="button" class="go-lightbox__control" data-go-lightbox-zoom-out aria-label="Afastar">−</button>' +
				'<span class="go-lightbox__level" data-go-lightbox-level>100%</span>' +
				'<button type="button" class="go-lightbox__control" data-go-lightbox-zoom-in aria-label="Aproximar">+</button>' +
				'<button type="button" class="go-lightbox__reset" data-go-lightbox-reset>Resetar</button>' +
			'</div>' +
			'<button type="button" class="go-lightbox__close" aria-label="Fechar imagem">×</button>' +
			'<button type="button" class="go-lightbox__nav go-lightbox__nav--prev" data-go-lightbox-prev aria-label="Imagem anterior"><span aria-hidden="true">‹</span></button>' +
			'<button type="button" class="go-lightbox__nav go-lightbox__nav--next" data-go-lightbox-next aria-label="Próxima imagem"><span aria-hidden="true">›</span></button>' +
			'<div class="go-lightbox__stage" data-go-lightbox-stage>' +
				'<img class="go-lightbox__image" alt="" draggable="false">' +
			'</div>' +
			'<div class="go-lightbox__meta" aria-live="polite">' +
				'<span class="go-lightbox__counter" data-go-lightbox-counter></span>' +
				'<p class="go-lightbox__caption" data-go-lightbox-caption></p>' +
			'</div>' +
			'<div class="go-lightbox__film" data-go-lightbox-film aria-label="Miniaturas da galeria" hidden></div>';
		document.body.appendChild(lightbox);

		var lightboxImage = lightbox.querySelector('.go-lightbox__image');
		var stage = lightbox.querySelector('[data-go-lightbox-stage]');
		var closeButton = lightbox.querySelector('.go-lightbox__close');
		var zoomInButton = lightbox.querySelector('[data-go-lightbox-zoom-in]');
		var zoomOutButton = lightbox.querySelector('[data-go-lightbox-zoom-out]');
		var resetButton = lightbox.querySelector('[data-go-lightbox-reset]');
		var levelLabel = lightbox.querySelector('[data-go-lightbox-level]');
		var prevButton = lightbox.querySelector('[data-go-lightbox-prev]');
		var nextButton = lightbox.querySelector('[data-go-lightbox-next]');
		var counter = lightbox.querySelector('[data-go-lightbox-counter]');
		var caption = lightbox.querySelector('[data-go-lightbox-caption]');
		var film = lightbox.querySelector('[data-go-lightbox-film]');
		var previousFocus = null;
		var activeGroupIndex = 0;
		var activeImageIndex = 0;
		var scale = 1;
		var panX = 0;
		var panY = 0;
		var minScale = 1;
		var maxScale = 5;
		var isDragging = false;
		var dragStartX = 0;
		var dragStartY = 0;
		var panStartX = 0;
		var panStartY = 0;
		var swipeStartX = 0;
		var swipeStartY = 0;

		function hideBrokenImage(img) {
			if (!img || img.dataset.goBroken === '1') { return; }
			img.dataset.goBroken = '1';
			var wrapper = img.closest('figure, .wp-block-image, .wp-caption, .gallery-item');
			if (!wrapper) {
				var parent = img.parentElement;
				if (parent && /^(P|DIV|A)$/i.test(parent.tagName) && parent.children.length === 1) { wrapper = parent; }
			}
			if (wrapper) { wrapper.style.display = 'none'; }
			else { img.style.display = 'none'; }
		}

		function activeGroup() { return groups[activeGroupIndex] || []; }

		function clampPan() {
			if (scale <= 1) { panX = 0; panY = 0; return; }
			var baseWidth = lightboxImage.offsetWidth || 0;
			var baseHeight = lightboxImage.offsetHeight || 0;
			var stageWidth = stage.clientWidth || window.innerWidth;
			var stageHeight = stage.clientHeight || window.innerHeight;
			var maxX = Math.max(0, (baseWidth * scale - stageWidth) / 2 + 24);
			var maxY = Math.max(0, (baseHeight * scale - stageHeight) / 2 + 24);
			panX = Math.max(-maxX, Math.min(maxX, panX));
			panY = Math.max(-maxY, Math.min(maxY, panY));
		}

		function renderTransform() {
			clampPan();
			lightboxImage.style.transform = 'translate3d(' + panX + 'px,' + panY + 'px,0) scale(' + scale + ')';
			lightbox.classList.toggle('is-zoomed', scale > 1);
			stage.classList.toggle('is-draggable', scale > 1);
			if (levelLabel) { levelLabel.textContent = Math.round(scale * 100) + '%'; }
			if (zoomOutButton) { zoomOutButton.disabled = scale <= minScale; }
			if (zoomInButton) { zoomInButton.disabled = scale >= maxScale; }
		}

		function setScale(nextScale) {
			scale = Math.max(minScale, Math.min(maxScale, Math.round(nextScale * 100) / 100));
			if (scale <= 1) { panX = 0; panY = 0; }
			renderTransform();
		}

		function resetLightboxView() {
			scale = 1; panX = 0; panY = 0; isDragging = false;
			renderTransform();
		}

		function prefetchAdjacent() {
			var group = activeGroup();
			if (group.length < 2) { return; }
			[activeImageIndex - 1, activeImageIndex + 1].forEach(function (index) {
				if (index < 0) { index = group.length - 1; }
				if (index >= group.length) { index = 0; }
				if (group[index] && group[index].src) { var preload = new Image(); preload.src = group[index].src; }
			});
		}

		function buildFilmstrip() {
			if (!film) { return; }
			var group = activeGroup();
			film.innerHTML = '';
			if (group.length < 2) { film.hidden = true; lightbox.classList.remove('has-film'); return; }
			group.forEach(function (item, index) {
				var thumb = document.createElement('button');
				thumb.type = 'button';
				thumb.className = 'go-lightbox__thumb';
				thumb.setAttribute('aria-label', 'Imagem ' + (index + 1) + ' de ' + group.length);
				var image = document.createElement('img');
				image.alt = '';
				image.loading = 'lazy';
				image.decoding = 'async';
				image.src = (item.img && (item.img.currentSrc || item.img.src)) || item.src;
				thumb.appendChild(image);
				thumb.addEventListener('click', function (event) {
					event.stopPropagation();
					if (index !== activeImageIndex) { activeImageIndex = index; renderActiveImage(); }
				});
				film.appendChild(thumb);
			});
			film.hidden = false;
			lightbox.classList.add('has-film');
		}

		function updateFilmstripActive() {
			if (!film || film.hidden) { return; }
			var thumbs = film.children;
			for (var i = 0; i < thumbs.length; i++) {
				var on = i === activeImageIndex;
				thumbs[i].classList.toggle('is-active', on);
				if (on) { thumbs[i].setAttribute('aria-current', 'true'); } else { thumbs[i].removeAttribute('aria-current'); }
			}
			var active = thumbs[activeImageIndex];
			if (active && active.scrollIntoView) {
				var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
				active.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'nearest', inline: 'center' });
			}
		}

		function renderActiveImage() {
			var group = activeGroup();
			var item = group[activeImageIndex];
			if (!item) { return; }
			resetLightboxView();
			lightboxImage.src = item.src;
			lightboxImage.alt = item.alt || '';
			var hasGallery = group.length > 1;
			prevButton.hidden = !hasGallery;
			nextButton.hidden = !hasGallery;
			counter.hidden = !hasGallery;
			counter.textContent = hasGallery ? (activeImageIndex + 1) + ' / ' + group.length : '';
			caption.textContent = item.caption || '';
			caption.hidden = !item.caption;
			lightbox.classList.toggle('has-caption', !!item.caption);
			updateFilmstripActive();
			prefetchAdjacent();
		}

		function closeLightbox() {
			lightbox.classList.remove('is-open', 'is-dragging');
			lightbox.setAttribute('aria-hidden', 'true');
			document.documentElement.classList.remove('go-lock');
			resetLightboxView();
			lightboxImage.removeAttribute('src');
			if (film) { film.innerHTML = ''; film.hidden = true; }
			lightbox.classList.remove('has-film');
			if (previousFocus && previousFocus.focus) { previousFocus.focus(); }
		}

		function openLightbox(img) {
			var meta = imageMeta.get(img);
			if (!meta) { return; }
			previousFocus = img;
			activeGroupIndex = meta.group;
			activeImageIndex = meta.index;
			buildFilmstrip();
			renderActiveImage();
			lightbox.classList.add('is-open');
			lightbox.setAttribute('aria-hidden', 'false');
			document.documentElement.classList.add('go-lock');
			closeButton.focus();
		}

		function navigate(direction) {
			var group = activeGroup();
			if (group.length < 2) { return; }
			activeImageIndex = (activeImageIndex + direction + group.length) % group.length;
			renderActiveImage();
		}

		images.forEach(function (img) {
			img.addEventListener('error', function () { hideBrokenImage(img); });
			if (img.complete && typeof img.naturalWidth !== 'undefined' && img.naturalWidth === 0) { hideBrokenImage(img); return; }
			img.classList.add('go-zoomable-image');
			img.setAttribute('tabindex', '0');
			img.setAttribute('role', 'button');
			var meta = imageMeta.get(img);
			var metaGroup = meta ? (groups[meta.group] || []) : [];
			img.setAttribute('aria-label', metaGroup.length > 1 ? 'Abrir imagem da galeria' : 'Ampliar imagem');
			img.addEventListener('click', function (event) {
				event.preventDefault(); event.stopPropagation();
				if (img.dataset.goBroken !== '1') { openLightbox(img); }
			});
			img.addEventListener('keydown', function (event) {
				if (event.key === 'Enter' || event.key === ' ') {
					event.preventDefault();
					if (img.dataset.goBroken !== '1') { openLightbox(img); }
				}
			});
		});

		zoomInButton.addEventListener('click', function () { setScale(scale + 0.5); });
		zoomOutButton.addEventListener('click', function () { setScale(scale - 0.5); });
		resetButton.addEventListener('click', resetLightboxView);
		closeButton.addEventListener('click', closeLightbox);
		prevButton.addEventListener('click', function (event) { event.stopPropagation(); navigate(-1); });
		nextButton.addEventListener('click', function (event) { event.stopPropagation(); navigate(1); });

		stage.addEventListener('wheel', function (event) {
			if (!lightbox.classList.contains('is-open')) { return; }
			event.preventDefault();
			setScale(scale + (event.deltaY < 0 ? 0.25 : -0.25));
		}, { passive: false });

		stage.addEventListener('pointerdown', function (event) {
			swipeStartX = event.clientX; swipeStartY = event.clientY;
			if (scale <= 1 || event.button > 0) { return; }
			isDragging = true;
			dragStartX = event.clientX; dragStartY = event.clientY;
			panStartX = panX; panStartY = panY;
			lightbox.classList.add('is-dragging');
			stage.setPointerCapture(event.pointerId);
		});
		stage.addEventListener('pointermove', function (event) {
			if (!isDragging) { return; }
			panX = panStartX + (event.clientX - dragStartX);
			panY = panStartY + (event.clientY - dragStartY);
			renderTransform();
		});
		function stopDrag(event) {
			if (isDragging) {
				isDragging = false;
				lightbox.classList.remove('is-dragging');
				if (event && stage.hasPointerCapture && stage.hasPointerCapture(event.pointerId)) { stage.releasePointerCapture(event.pointerId); }
				return;
			}
			if (!event || scale > 1) { return; }
			var deltaX = event.clientX - swipeStartX;
			var deltaY = event.clientY - swipeStartY;
			if (Math.abs(deltaX) > 54 && Math.abs(deltaX) > Math.abs(deltaY) * 1.25) { navigate(deltaX < 0 ? 1 : -1); }
		}
		stage.addEventListener('pointerup', stopDrag);
		stage.addEventListener('pointercancel', stopDrag);

		lightboxImage.addEventListener('dblclick', function (event) { event.preventDefault(); setScale(scale > 1 ? 1 : 2); });
		lightbox.addEventListener('click', function (event) {
			if (event.target === lightbox || event.target === stage) { closeLightbox(); }
		});

		document.addEventListener('keydown', function (event) {
			if (!lightbox.classList.contains('is-open')) { return; }
			if (event.key === 'Escape' || event.keyCode === 27) { closeLightbox(); return; }
			if (event.key === 'ArrowLeft' && scale <= 1) { event.preventDefault(); navigate(-1); return; }
			if (event.key === 'ArrowRight' && scale <= 1) { event.preventDefault(); navigate(1); return; }
			if (event.key === '+' || event.key === '=') { event.preventDefault(); setScale(scale + 0.5); }
			if (event.key === '-' || event.key === '_') { event.preventDefault(); setScale(scale - 0.5); }
			if (event.key === '0') { event.preventDefault(); resetLightboxView(); }
			if (event.key === 'Tab') {
				var focusable = Array.prototype.slice.call(lightbox.querySelectorAll('button:not([hidden]):not(:disabled)'));
				if (!focusable.length) { return; }
				var first = focusable[0]; var last = focusable[focusable.length - 1];
				if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
				else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
			}
		});
	})();
})();

// Homepage authorial video player.
(function () {
	'use strict';
	var hubs = document.querySelectorAll('[data-go-video-hub]');
	if (!hubs.length) { return; }

	hubs.forEach(function (hub) {
		var frame = hub.querySelector('[data-go-video-frame]');
		var title = hub.querySelector('[data-go-video-title]');
		var source = hub.querySelector('[data-go-video-source]');
		var items = hub.querySelectorAll('[data-go-video-item]');
		if (!frame || !items.length) { return; }

		items.forEach(function (item) {
			item.addEventListener('click', function () {
				var videoId = item.getAttribute('data-video-id');
				if (!videoId) { return; }
				items.forEach(function (other) {
					other.classList.remove('is-active');
					other.setAttribute('aria-pressed', 'false');
				});
				item.classList.add('is-active');
				item.setAttribute('aria-pressed', 'true');
				var videoPage = hub.closest('.go-videos-page');
				if (videoPage) {
					Array.prototype.slice.call(videoPage.querySelectorAll('[data-go-video-load]')).forEach(function (externalItem) {
						externalItem.classList.remove('is-active');
					});
				}
				frame.src = 'https://www.youtube-nocookie.com/embed/' + encodeURIComponent(videoId) + '?autoplay=1&rel=0&modestbranding=1';
				frame.title = item.getAttribute('data-video-title') || 'Vídeo';
				if (title) { title.textContent = item.getAttribute('data-video-title') || ''; }
				if (source) { source.textContent = item.getAttribute('data-video-source') || ''; }
			});
		});
	});
})();

// Video cards on /videos/ load directly into the page player.
(function () {
	'use strict';
	var page = document.querySelector('.go-videos-page');
	if (!page) { return; }
	var hub = page.querySelector('[data-go-video-hub]');
	if (!hub) { return; }
	var frame = hub.querySelector('[data-go-video-frame]');
	var title = hub.querySelector('[data-go-video-title]');
	var source = hub.querySelector('[data-go-video-source]');
	var playerSection = document.getElementById('go-video-player') || hub;
	if (!frame) { return; }

	page.addEventListener('click', function (event) {
		var trigger = event.target.closest('[data-go-video-load]');
		if (!trigger || !page.contains(trigger)) { return; }
		var videoId = trigger.getAttribute('data-video-id');
		if (!videoId) { return; }
		event.preventDefault();
		frame.src = 'https://www.youtube-nocookie.com/embed/' + encodeURIComponent(videoId) + '?autoplay=1&rel=0&modestbranding=1';
		frame.title = trigger.getAttribute('data-video-title') || 'Vídeo';
		if (title) { title.textContent = trigger.getAttribute('data-video-title') || ''; }
		if (source) { source.textContent = trigger.getAttribute('data-video-source') || ''; }
		Array.prototype.slice.call(page.querySelectorAll('[data-go-video-load]')).forEach(function (item) {
			item.classList.toggle('is-active', item === trigger);
		});
		Array.prototype.slice.call(hub.querySelectorAll('[data-go-video-item]')).forEach(function (item) {
			item.classList.remove('is-active');
			item.setAttribute('aria-pressed', 'false');
		});
		if (playerSection && typeof playerSection.scrollIntoView === 'function') {
			var rect = playerSection.getBoundingClientRect();
			var alreadyVisible = rect.top >= 70 && rect.top <= Math.max(120, window.innerHeight * 0.28);
			if (!alreadyVisible) {
				playerSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
			}
		}
	});
})();

// Smart off-canvas groups: label navigates, chevron expands only the submenu.
(function () {
	'use strict';
	document.addEventListener('click', function (event) {
		var toggle = event.target.closest('[data-go-offcanvas-submenu-toggle]');
		if (!toggle) { return; }
		var id = toggle.getAttribute('aria-controls');
		var menu = id ? document.getElementById(id) : null;
		if (!menu) { return; }
		event.preventDefault();
		var expanded = toggle.getAttribute('aria-expanded') === 'true';
		toggle.setAttribute('aria-expanded', expanded ? 'false' : 'true');
		menu.hidden = expanded;
	});
})();

// Content polish for non-article legacy surfaces. Single article DOM must stay stable after parse.
(function () {
	'use strict';

	if (document.body && document.body.classList.contains('single-post')) { return; }

	var articles = document.querySelectorAll('.single .go-article__content, .single .entry-content');
	if (!articles.length) { return; }
	var providerSelector = '.google-auto-placed,.adsbygoogle-noablate,ins.adsbygoogle,[data-go-ad-placement],[id^="aswift_"],[id^="google_ads_"]';
	function containsAdvertising(el) {
		return !!(el && el.nodeType === 1 && (el.closest(providerSelector) || el.querySelector(providerSelector)));
	}

	// Shared helpers for the FAQ transform below. A question is either a
	// sub-heading or an editor's "bold paragraph ending in a question mark", so
	// the same collapsible cards render whether the FAQ was written with H3/H4
	// headings or with bold <p> lines.
	function goFaqLevel(el) {
		var m = el && /^H([1-6])$/i.exec(el.tagName || '');
		return m ? parseInt(m[1], 10) : 0;
	}
	function goFaqIsBoldQuestion(el) {
		if (!el || !/^(P|DIV)$/i.test(el.tagName || '')) { return false; }
		var text = (el.textContent || '').trim().replace(/\s+/g, ' ');
		if (!text || text.length > 260 || !/\?\s*$/.test(text)) { return false; }
		if (el.classList && (el.classList.contains('go-faq-question') ||
			el.classList.contains('schema-faq-question') ||
			el.classList.contains('rank-math-question-title'))) { return true; }
		var bold = Array.prototype.slice.call(el.querySelectorAll('strong, b')).map(function (b) {
			return b.textContent || '';
		}).join(' ').trim().replace(/\s+/g, ' ');
		return !!bold && bold === text;
	}
	function goFaqIsBoundary(el) {
		if (!el || el.nodeType !== 1) { return false; }
		if (containsAdvertising(el)) { return true; }
		if (/^(SCRIPT|STYLE|ASIDE)$/i.test(el.tagName || '')) { return true; }
		if (el.classList) {
			var tokens = ['go-adsense-placement', 'go-smart-ad', 'adsbygoogle', 'go-context-block', 'go-review-box', 'go-spoiler-alert'];
			for (var i = 0; i < tokens.length; i += 1) {
				if (el.classList.contains(tokens[i])) { return true; }
			}
		}
		var id = (el.id || '').toLowerCase();
		return id.indexOf('google_ads_') === 0 || id.indexOf('adsense') !== -1;
	}
	function goFaqDirectSummary(details) {
		for (var i = 0; i < details.children.length; i += 1) {
			if (/^SUMMARY$/i.test(details.children[i].tagName || '')) { return details.children[i]; }
		}
		return null;
	}

	articles.forEach(function (content) {
		// Raw and Gutenberg tables get a safe horizontal scroller on small screens.
		Array.prototype.slice.call(content.querySelectorAll('table')).forEach(function (table) {
			if (containsAdvertising(table)) { return; }
			function accessibleScroller(el) { el.tabIndex = 0; el.setAttribute('role', 'region'); el.setAttribute('aria-label', 'Tabela — role horizontalmente para ver todas as colunas'); }
			if (table.closest('.go-table-scroll')) { accessibleScroller(table.closest('.go-table-scroll')); return; }
			var parent = table.parentElement;
			if (parent && parent.classList.contains('wp-block-table')) {
				parent.classList.add('go-table-scroll');
				accessibleScroller(parent);
				return;
			}
			var wrap = document.createElement('div');
			wrap.className = 'go-table-scroll';
			accessibleScroller(wrap);
			table.parentNode.insertBefore(wrap, table);
			wrap.appendChild(table);
		});

		Array.prototype.slice.call(content.children).forEach(function (node) {
			if (!node || !node.parentNode) { return; }
			if (containsAdvertising(node)) { return; }
			var label = (node.textContent || '').trim().replace(/\s+/g, ' ');
			if (!label) { return; }

			if (/^(?:Leia também|Leia mais):?$/i.test(label)) {
				var next = node.nextElementSibling;
				if (next && /^(UL|OL)$/i.test(next.tagName) && !next.classList.contains('go-context-links')) {
					var wrap = document.createElement('section');
					wrap.className = 'go-context-block go-context-block--related go-context-block--primary';
					var title = document.createElement('div');
					title.className = 'go-context-block__title';
					title.textContent = 'Relacionado';
					wrap.appendChild(title);
					next.classList.add('go-context-links');
					Array.prototype.slice.call(next.querySelectorAll('a')).forEach(function (link) {
						link.classList.add('go-context-links__link');
					});
					node.parentNode.insertBefore(wrap, node);
					wrap.appendChild(next);
					node.remove();
				}
			}

			// Keep this alternation in sync with go_verge_faq_heading_variants() in
			// inc/seo.php. Editors write "Perguntas rápidas", "Dúvidas comuns" and
			// "Perguntas e respostas" as often as the canonical heading; if only one
			// side recognises a variant, the story gets the cards without the schema
			// or the schema without the cards. Accent-tolerant on purpose.
			if (/^(?:perguntas?\s+(?:mais\s+)?frequentes?|perguntas?\s+r[áa]pidas?|perguntas?\s+(?:comuns|comum)|perguntas?\s+e\s+respostas|d[úu]vidas?\s+(?:mais\s+)?frequentes?|d[úu]vidas?\s+r[áa]pidas?|d[úu]vidas?\s+(?:comuns|comum)|principais\s+d[úu]vidas|tire\s+suas\s+d[úu]vidas|FAQ)(?:(?:\s+sobre\b|\s*[:—–-]\s*).*)?\s*$/i.test(label)) {
				node.classList.add('go-faq-heading');

				// Same-or-higher headings close the FAQ block. Each question (a
				// deeper heading or a bold "…?" paragraph) becomes a collapsible
				// card; its answer runs until the next question, heading, boundary
				// or an already-authored <details>.
				var stopLevel = goFaqLevel(node) || 2;
				var cursor = node.nextElementSibling;
				while (cursor) {
					var current = cursor;
					var currentLevel = goFaqLevel(current);
					var next = current.nextElementSibling;

					if (currentLevel && currentLevel <= stopLevel) { break; }

					/* Ads and injected editorial modules may sit between FAQ items. They
					 * are not the end of the FAQ: leave them in place and keep scanning
					 * so every authored question receives the same accordion treatment. */
					if (goFaqIsBoundary(current)) { cursor = next; continue; }

					if (/^DETAILS$/i.test(current.tagName || '')) {
						if (goFaqDirectSummary(current)) { current.classList.add('go-faq-item'); }
						cursor = next;
						continue;
					}

					var isQuestion = (currentLevel && currentLevel > stopLevel) || goFaqIsBoldQuestion(current);
					if (!isQuestion) { cursor = next; continue; }

					var details = document.createElement('details');
					details.className = 'go-faq-item';
					var summary = document.createElement('summary');
					while (current.firstChild) { summary.appendChild(current.firstChild); }
					details.appendChild(summary);
					current.parentNode.insertBefore(details, current);
					current.remove();

					var answer = next;
					while (answer) {
						/* Keep ad/context modules outside the <details>, but do not let
						 * them cut the FAQ short. This is common after ad insertion. */
						if (goFaqIsBoundary(answer)) {
							answer = answer.nextElementSibling;
							continue;
						}
						if (goFaqLevel(answer) || goFaqIsBoldQuestion(answer) || /^DETAILS$/i.test(answer.tagName || '')) { break; }
						var moveNode = answer;
						answer = answer.nextElementSibling;
						details.appendChild(moveNode);
					}
					cursor = answer;
				}
			}
		});
	});
})();

// Dedicated /videos/ platform tabs.
(function () {
	'use strict';
	var roots = document.querySelectorAll('[data-go-video-platform-tabs]');
	if (!roots.length) { return; }

	roots.forEach(function (root) {
		var tabs = Array.prototype.slice.call(root.querySelectorAll('[data-go-video-platform-tab]'));
		var panels = Array.prototype.slice.call(root.querySelectorAll('[data-go-video-platform-panel]'));
		if (!tabs.length || !panels.length) { return; }

		function activate(key) {
			tabs.forEach(function (tab) {
				var active = tab.getAttribute('data-go-video-platform-tab') === key;
				tab.classList.toggle('is-active', active);
				tab.setAttribute('aria-selected', active ? 'true' : 'false');
				tab.tabIndex = active ? 0 : -1;
			});
			panels.forEach(function (panel) {
				var active = panel.getAttribute('data-go-video-platform-panel') === key;
				panel.classList.toggle('is-active', active);
				panel.hidden = !active;
			});
		}

		tabs.forEach(function (tab, index) {
			tab.addEventListener('click', function () {
				activate(tab.getAttribute('data-go-video-platform-tab') || '');
			});
			tab.addEventListener('keydown', function (event) {
				var next = index;
				if (event.key === 'ArrowRight') { next = (index + 1) % tabs.length; }
				else if (event.key === 'ArrowLeft') { next = (index + tabs.length - 1) % tabs.length; }
				else if (event.key === 'Home') { next = 0; }
				else if (event.key === 'End') { next = tabs.length - 1; }
				else { return; }
				event.preventDefault();
				activate(tabs[next].getAttribute('data-go-video-platform-tab') || '');
				tabs[next].focus();
			});
		});
	});
})();

// Expanded sharing menu on article singles.
(function () {
	'use strict';
	var roots = Array.prototype.slice.call(document.querySelectorAll('[data-go-share-more]'));
	if (!roots.length) { return; }

	function setOpen(root, open) {
		var toggle = root.querySelector('[data-go-share-more-toggle]');
		var menu = root.querySelector('[data-go-share-more-menu]');
		if (!toggle || !menu) { return; }
		var restoreFocus = !open && menu.contains(document.activeElement);
		root.classList.toggle('is-open', open);
		toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
		menu.hidden = !open;
		if (restoreFocus) { toggle.focus({ preventScroll: true }); }
	}

	function fallbackCopy(value) {
		var area = document.createElement('textarea');
		area.value = value;
		area.setAttribute('readonly', 'readonly');
		area.style.position = 'fixed';
		area.style.opacity = '0';
		document.body.appendChild(area);
		area.select();
		try { document.execCommand('copy'); } catch (error) { /* no-op */ }
		document.body.removeChild(area);
	}

	roots.forEach(function (root) {
		var toggle = root.querySelector('[data-go-share-more-toggle]');
		var copy = root.querySelector('[data-go-copy-link]');
		var nativeShare = root.querySelector('[data-go-native-share]');
		if (!toggle) { return; }

		toggle.addEventListener('click', function (event) {
			event.stopPropagation();
			var open = toggle.getAttribute('aria-expanded') !== 'true';
			roots.forEach(function (other) { if (other !== root) { setOpen(other, false); } });
			setOpen(root, open);
		});

		if (copy) {
			copy.addEventListener('click', function () {
				var url = copy.getAttribute('data-share-url') || window.location.href;
				var done = function () {
					var original = copy.getAttribute('data-original-label') || copy.textContent;
					copy.setAttribute('data-original-label', original);
					copy.textContent = 'Link copiado';
					window.setTimeout(function () { copy.textContent = original; }, 1800);
				};
				if (navigator.clipboard && window.isSecureContext) {
					navigator.clipboard.writeText(url).then(done).catch(function () { fallbackCopy(url); done(); });
				} else {
					fallbackCopy(url);
					done();
				}
			});
		}

		if (nativeShare && typeof navigator.share === 'function') {
			nativeShare.hidden = false;
			nativeShare.addEventListener('click', function () {
				navigator.share({
					title: nativeShare.getAttribute('data-share-title') || document.title,
					url: nativeShare.getAttribute('data-share-url') || window.location.href
				}).catch(function () { /* User cancellation is expected. */ });
			});
		}
	});

	document.addEventListener('click', function (event) {
		roots.forEach(function (root) {
			if (!root.contains(event.target)) { setOpen(root, false); }
		});
	});
	document.addEventListener('keydown', function (event) {
		if (event.key !== 'Escape') { return; }
		roots.forEach(function (root) { setOpen(root, false); });
	});
})();

// Accessible coupon filters and one-click copy on /promocoes/.
(function () {
	'use strict';
	var roots = Array.prototype.slice.call(document.querySelectorAll('[data-go-coupon-center]'));
	if (!roots.length) { return; }

	function fallbackCopy(value) {
		var area = document.createElement('textarea');
		area.value = value;
		area.setAttribute('readonly', 'readonly');
		area.style.position = 'fixed';
		area.style.opacity = '0';
		document.body.appendChild(area);
		area.select();
		try { document.execCommand('copy'); } catch (error) { /* no-op */ }
		document.body.removeChild(area);
	}

	roots.forEach(function (root) {
		var filters = Array.prototype.slice.call(root.querySelectorAll('[data-go-coupon-filter]'));
		var cards = Array.prototype.slice.call(root.querySelectorAll('[data-go-coupon-merchant]'));
		var status = root.querySelector('[data-go-coupon-status]');

		filters.forEach(function (button) {
			button.addEventListener('click', function () {
				var key = button.getAttribute('data-go-coupon-filter') || 'all';
				var visible = 0;
				filters.forEach(function (item) {
					var active = item === button;
					item.classList.toggle('is-active', active);
					item.setAttribute('aria-pressed', active ? 'true' : 'false');
				});
				cards.forEach(function (card) {
					var show = key === 'all' || card.getAttribute('data-go-coupon-merchant') === key;
					card.hidden = !show;
					if (show) { visible += 1; }
				});
				if (status) { status.textContent = visible + (visible === 1 ? ' cupom exibido.' : ' cupons exibidos.'); }
			});
		});

		root.addEventListener('click', function (event) {
			var button = event.target.closest('[data-go-copy-coupon]');
			if (!button || !root.contains(button)) { return; }
			var code = button.getAttribute('data-coupon-code') || '';
			if (!code) { return; }
			var done = function () {
				var original = button.getAttribute('data-original-label') || button.textContent;
				button.setAttribute('data-original-label', original);
				button.textContent = 'Copiado';
				button.classList.add('is-copied');
				if (status) { status.textContent = 'Cupom ' + code + ' copiado.'; }
				window.setTimeout(function () {
					button.textContent = original;
					button.classList.remove('is-copied');
				}, 1800);
			};
			if (navigator.clipboard && window.isSecureContext) {
				navigator.clipboard.writeText(code).then(done).catch(function () { fallbackCopy(code); done(); });
			} else {
				fallbackCopy(code);
				done();
			}
		});
	});
})();

// Accessibility: inputs rendered by third-party form plugins (e.g. Mailchimp)
// often ship placeholder-only fields. Mirror the placeholder into aria-label
// when no other accessible name exists.
(function () {
	'use strict';
	function label() {
		Array.prototype.slice.call(document.querySelectorAll('input[placeholder], textarea[placeholder]')).forEach(function (field) {
			if (field.getAttribute('aria-label') || field.getAttribute('aria-labelledby')) { return; }
			if (field.closest('label')) { return; }
			if (field.id && document.querySelector('label[for="' + (window.CSS && CSS.escape ? CSS.escape(field.id) : field.id) + '"]')) { return; }
			var hint = (field.getAttribute('placeholder') || '').trim();
			if (hint) { field.setAttribute('aria-label', hint); }
		});
	}
	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', label, { once: true });
	} else {
		label();
	}
})();

// Game hub: long editorial summaries become a wall of text on small screens.
// Clamp them behind an accessible "Ler mais" toggle; desktop keeps full text.
(function () {
	'use strict';
	function enhance() {
		var summary = document.querySelector('.go-game-overview__summary');
		if (!summary || summary.dataset.goSummaryClamped) { return; }
		if (!window.matchMedia || !window.matchMedia('(max-width: 767px)').matches) { return; }
		if (summary.scrollHeight < 240) { return; }

		summary.dataset.goSummaryClamped = '1';
		summary.classList.add('is-clamped');
		summary.id = summary.id || 'go-game-summary';

		var toggle = document.createElement('button');
		toggle.type = 'button';
		toggle.className = 'go-game-overview__summary-toggle';
		toggle.setAttribute('aria-expanded', 'false');
		toggle.setAttribute('aria-controls', summary.id);
		toggle.textContent = 'Ler mais';
		toggle.addEventListener('click', function () {
			var expanded = summary.classList.toggle('is-clamped') === false;
			toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
			toggle.textContent = expanded ? 'Ler menos' : 'Ler mais';
		});
		summary.parentNode.insertBefore(toggle, summary.nextSibling);
	}
	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', enhance, { once: true });
	} else {
		enhance();
	}
})();

// AJAX editorial filters: only the story area is replaced. The page shell,
// header and scroll position remain intact, while the URL stays shareable.
(function () {
	'use strict';

	if (typeof window.fetch !== 'function' || typeof window.DOMParser !== 'function') { return; }

	/*
	 * After a filter swaps the results list, the new sentinel is picked up by the
	 * V8 controller through the `go:content-updated` event dispatched below. The
	 * second loader that used to be rebound here was already short-circuited and
	 * is gone.
	 */

	var pending = null;
	var serial = 0;
	var displayedUrl = window.location.pathname + window.location.search;
	var filterAttributes = ['data-go-latest-filter', 'data-go-editorial-filter', 'data-go-review-platform-filter', 'data-go-review-genre-filter', 'data-go-category-access-filter'];
	var filterSelector = filterAttributes.map(function (attribute) { return '[' + attribute + ']'; }).join(', ');

	// The server is authoritative for selected filters, including back/forward,
	// invalid parameters and legacy category URLs. Do not infer state from a click.
	function updateActiveFilters(parsed, href) {
		var fresh = Array.prototype.slice.call(parsed.querySelectorAll(filterSelector));
		var activeCategory = new URL(href, window.location.href).searchParams.get('subcategoria') || '';
		document.querySelectorAll(filterSelector).forEach(function (item) {
			// Access cards predate the server-rendered pill state contract.
			if (item.hasAttribute('data-go-category-access-filter')) {
				var active = item.getAttribute('data-go-category-access-filter') === activeCategory;
				item.classList.toggle('is-active', active);
				if (active) { item.setAttribute('aria-current', 'page'); }
				else { item.removeAttribute('aria-current'); }
				return;
			}
			var match = fresh.find(function (candidate) {
				return candidate.getAttribute('href') === item.getAttribute('href') && filterAttributes.every(function (attribute) {
					return candidate.getAttribute(attribute) === item.getAttribute(attribute);
				});
			});
			if (!match) { return; }
			item.classList.toggle('is-active', match.classList.contains('is-active'));
			if (match.hasAttribute('aria-current')) { item.setAttribute('aria-current', match.getAttribute('aria-current')); }
			else { item.removeAttribute('aria-current'); }
		});
	}
	function clearBusy(root) {
		root.removeAttribute('aria-busy');
		root.classList.remove('is-filtering');
	}

	function replaceFilteredContent(link, kind, pushState) {
		var isElement = !!(link && typeof link.closest === 'function');
		var href = typeof link === 'string' ? link : (link ? link.href : '');
		var editorialScope = kind === 'editorial' && isElement ? link.closest('[data-go-editorial-filter-scope]') : null;
		var reviewScope = kind === 'review-latest' && isElement ? link.closest('[data-go-review-filter-scope]') : null;
		var currentRoot = kind === 'latest'
			? document.querySelector('[data-go-latest-results]')
			: (kind === 'review-latest'
				? (reviewScope ? reviewScope.querySelector('[data-go-review-latest-results]') : document.querySelector('[data-go-review-latest-results]'))
				: (kind === 'category-access'
					? document.querySelector('[data-go-editorial-results], [data-go-promotion-results]')
					: (editorialScope ? editorialScope.querySelector('[data-go-editorial-results]') : document.querySelector('[data-go-editorial-results]'))));
		if (!href || !currentRoot || new URL(href, window.location.href).origin !== window.location.origin) { return false; }
		var requestId = ++serial;
		if (pending) {
			if (pending.controller) { pending.controller.abort(); }
			clearBusy(pending.root);
		}
		var controller = 'AbortController' in window ? new AbortController() : null;
		pending = { root: currentRoot, controller: controller };

		currentRoot.setAttribute('aria-busy', 'true');
		currentRoot.classList.add('is-filtering');
		fetch(href, {
			method: 'GET',
			credentials: 'same-origin',
			headers: { 'X-Requested-With': 'XMLHttpRequest' },
			signal: controller ? controller.signal : undefined
		})
			.then(function (response) {
				if (!response.ok) { throw new Error('Request failed'); }
				return response.text();
			})
			.then(function (html) {
				if (requestId !== serial || !currentRoot.isConnected) { return; }
				var parsed = new DOMParser().parseFromString(html, 'text/html');
				var nextRoot = kind === 'latest'
					? parsed.querySelector('[data-go-latest-results]')
					: (kind === 'review-latest'
						? parsed.querySelector('[data-go-review-latest-results]')
						: (kind === 'category-access'
							? parsed.querySelector(currentRoot.hasAttribute('data-go-promotion-results') ? '[data-go-promotion-results]' : '[data-go-editorial-results]')
							: parsed.querySelector('[data-go-editorial-results]')));
				if (!nextRoot) { throw new Error('Missing filtered results'); }

				currentRoot.innerHTML = nextRoot.innerHTML;
				currentRoot.className = nextRoot.className;
				clearBusy(currentRoot);
				pending = null;
				updateActiveFilters(parsed, href);
				if (pushState !== false) { window.history.pushState({ goFilteredArchive: true }, '', href); }
				displayedUrl = window.location.pathname + window.location.search;
				document.dispatchEvent(new CustomEvent('go:content-updated', { detail: { scope: currentRoot } }));
			})
			.catch(function (error) {
				if (requestId !== serial || (error && error.name === 'AbortError')) { return; }
				clearBusy(currentRoot);
				pending = null;
				window.location.href = href;
			});
		return true;
	}

	document.addEventListener('click', function (event) {
		if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) { return; }
		var latestFilter = event.target.closest('[data-go-latest-filter]');
		if (latestFilter) {
			if (replaceFilteredContent(latestFilter, 'latest')) { event.preventDefault(); }
			return;
		}

		var reviewGenreFilter = event.target.closest('[data-go-review-genre-filter]');
		if (reviewGenreFilter && reviewGenreFilter.closest('[data-go-review-filter-scope]')) {
			if (replaceFilteredContent(reviewGenreFilter, 'review-latest')) { event.preventDefault(); }
			return;
		}

		var categoryAccessFilter = event.target.closest('[data-go-category-access-filter]');
		if (categoryAccessFilter) {
			if (replaceFilteredContent(categoryAccessFilter, 'category-access')) { event.preventDefault(); }
			return;
		}

		var editorialFilter = event.target.closest('[data-go-editorial-filter], [data-go-review-platform-filter]');
		if (editorialFilter && editorialFilter.closest('[data-go-editorial-filter-scope]')) {
			if (replaceFilteredContent(editorialFilter, 'editorial')) { event.preventDefault(); }
		}
	});

	window.addEventListener('popstate', function () {
		/* Desk format navigation owns its smaller feed fragment. */
		if (document.querySelector('[data-od-desk-feed]')) { return; }
		if (displayedUrl === window.location.pathname + window.location.search) {
			// Returning to the still-visible history entry cancels an unfinished
			// transition to a different entry; its response must not replace this UI.
			if (pending) {
				serial += 1;
				if (pending.controller) { pending.controller.abort(); }
				clearBusy(pending.root);
				pending = null;
			}
			return;
		}
		if (document.querySelector('[data-go-promotion-results]')) {
			replaceFilteredContent(window.location.href, 'category-access', false);
			return;
		}
		if (document.querySelector('[data-go-editorial-results]')) {
			replaceFilteredContent(window.location.href, 'editorial', false);
			return;
		}
		if (document.querySelector('[data-go-latest-results]')) {
			replaceFilteredContent(window.location.href, 'latest', false);
			return;
		}
		if (document.querySelector('[data-go-review-latest-results]')) {
			replaceFilteredContent(window.location.href, 'review-latest', false);
		}
	});
})();


/* v29 — normalize loose right-arrow glyphs into one polished UI control. */
(function () {
	'use strict';

	function decorateArrows(root) {
		var scope = root && root.querySelectorAll ? root : document;
		scope.querySelectorAll('span, a, button').forEach(function (element) {
			if (element.classList.contains('go-ui-arrow')) { return; }
			if (element.children.length === 0 && element.textContent.trim() === '→') {
				element.classList.add('go-ui-arrow');
			}
		});
	}

	function initArrows() {
		decorateArrows(document);
		document.addEventListener('go:content-updated', function (event) {
			var scope = event.detail && event.detail.scope ? event.detail.scope : event.target;
			decorateArrows(scope || document);
		});
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', initArrows, { once: true });
	} else {
		initArrows();
	}
})();
