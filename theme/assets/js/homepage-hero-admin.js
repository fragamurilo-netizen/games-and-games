(function ($) {
	'use strict';

	var config = window.GoVergeHeroAdmin || {};

	function escapeHtml(value) {
		return $('<div>').text(value || '').html();
	}

	function selectedIds() {
		var ids = [];
		$('.go-hero-picker__id').each(function () {
			var id = parseInt($(this).val(), 10) || 0;
			if (id) {
				ids.push(id);
			}
		});
		return ids;
	}

	function renderResults($picker, items) {
		var $results = $picker.find('.go-hero-picker__results');
		var activeId = parseInt($picker.find('.go-hero-picker__id').val(), 10) || 0;
		var used = selectedIds();

		if (!items || !items.length) {
			$results.html('<p class="go-hero-picker__empty">' + escapeHtml(config.emptyText) + '</p>').prop('hidden', false);
			return;
		}

		var html = items.map(function (item) {
			var id = parseInt(item.id, 10) || 0;
			var duplicate = id !== activeId && used.indexOf(id) !== -1;
			var meta = [item.category, item.date].filter(Boolean).join(' · ');
			var thumb = item.thumb
				? '<img src="' + escapeHtml(item.thumb) + '" alt="">'
				: '<span class="dashicons dashicons-format-image" aria-hidden="true"></span>';

			return '<button type="button" class="go-hero-result" role="option"' +
				(duplicate ? ' disabled aria-disabled="true"' : '') +
				' data-id="' + id + '" data-title="' + escapeHtml(item.title) + '" data-thumb="' + escapeHtml(item.thumb || '') + '" data-edit-url="' + escapeHtml(item.editUrl || '') + '">' +
				'<span class="go-hero-result__thumb">' + thumb + '</span>' +
				'<span class="go-hero-result__copy"><strong>' + escapeHtml(item.title) + '</strong><small>' + escapeHtml(meta) + (duplicate ? ' · já escolhida' : '') + '</small></span>' +
				'</button>';
		}).join('');

		$results.html(html).prop('hidden', false);
	}

	function searchPosts($picker, query) {
		var serial = (parseInt($picker.data('request-serial'), 10) || 0) + 1;
		$picker.data('request-serial', serial);
		var $spinner = $picker.find('.go-hero-picker__spinner');
		$spinner.addClass('is-active');

		$.ajax({
			url: config.ajaxUrl,
			method: 'GET',
			dataType: 'json',
			data: {
				action: 'go_verge_hero_search_posts',
				nonce: config.nonce,
				q: query || ''
			}
		}).done(function (response) {
			if (serial !== (parseInt($picker.data('request-serial'), 10) || 0)) {
				return;
			}
			if (response && response.success) {
				renderResults($picker, response.data || []);
				return;
			}
			$picker.find('.go-hero-picker__results')
				.html('<p class="go-hero-picker__empty">' + escapeHtml(config.errorText) + '</p>')
				.prop('hidden', false);
		}).fail(function () {
			if (serial !== (parseInt($picker.data('request-serial'), 10) || 0)) {
				return;
			}
			$picker.find('.go-hero-picker__results')
				.html('<p class="go-hero-picker__empty">' + escapeHtml(config.errorText) + '</p>')
				.prop('hidden', false);
		}).always(function () {
			if (serial === (parseInt($picker.data('request-serial'), 10) || 0)) {
				$spinner.removeClass('is-active');
			}
		});
	}

	function clearPicker($picker) {
		$picker.removeClass('is-selected');
		$picker.find('.go-hero-picker__id').val('0');
		$picker.find('.go-hero-picker__selected').prop('hidden', true);
		$picker.find('.go-hero-picker__selected-title').text('');
		$picker.find('.go-hero-picker__thumb').empty();
		$picker.find('.go-hero-picker__edit').attr('href', '#').prop('hidden', true);
		$picker.find('.go-hero-picker__mode').text(config.automaticText || 'Automático');
	}

	function selectPost($picker, $result) {
		var id = parseInt($result.attr('data-id'), 10) || 0;
		var title = $result.attr('data-title') || '';
		var thumb = $result.attr('data-thumb') || '';
		var editUrl = $result.attr('data-edit-url') || '';
		var $thumb = $picker.find('.go-hero-picker__thumb');

		$picker.addClass('is-selected');
		$picker.find('.go-hero-picker__id').val(id);
		$picker.find('.go-hero-picker__selected').prop('hidden', false);
		$picker.find('.go-hero-picker__selected-title').text(title);
		$picker.find('.go-hero-picker__mode').text(config.manualText || 'Manual');
		$picker.find('.go-hero-picker__search').val('');
		$picker.find('.go-hero-picker__results').prop('hidden', true).empty();

		$thumb.empty();
		if (thumb) {
			$('<img>', { src: thumb, alt: '' }).appendTo($thumb);
		}

		var $edit = $picker.find('.go-hero-picker__edit');
		if (editUrl) {
			$edit.attr('href', editUrl).prop('hidden', false);
		} else {
			$edit.attr('href', '#').prop('hidden', true);
		}
	}

	$(function () {
		$('.go-hero-picker').each(function () {
			var $picker = $(this);
			var $search = $picker.find('.go-hero-picker__search');
			var timer = null;

			$search.on('focus', function () {
				var $results = $picker.find('.go-hero-picker__results');
				if ($results.children().length) {
					$results.prop('hidden', false);
					return;
				}
				searchPosts($picker, $search.val());
			});

			$search.on('input', function () {
				clearTimeout(timer);
				var query = $search.val();
				timer = setTimeout(function () {
					searchPosts($picker, query);
				}, 250);
			});

			$picker.on('click', '.go-hero-result:not(:disabled)', function () {
				selectPost($picker, $(this));
			});

			$picker.on('click', '.go-hero-picker__clear', function () {
				clearPicker($picker);
				$search.trigger('focus');
			});
		});

		$('.go-hero-admin__reset').on('click', function () {
			$('.go-hero-picker').each(function () {
				clearPicker($(this));
			});
		});

		$(document).on('click', function (event) {
			if (!$(event.target).closest('.go-hero-picker__search-wrap').length) {
				$('.go-hero-picker__results').prop('hidden', true);
			}
		});
	});
})(jQuery);
