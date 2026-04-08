		var $grid = $('.grid').isotope({
			// options
			layoutMode: 'fitRows',
			itemSelector: '.grid-item',
			//transitionDuration: 0,
			//sortAscending: false,
			getSortData: {
				frequency: '.frequency',
				score: function( itemElem ) {
					var score = $( itemElem ).find('.score').text();
					return parseFloat( score.replace( /[\(\)]/g, '') );
				},
				// Custom sort function for date
				date: function( itemElem ) {
					// Get the value of the 'data-time' attribute and parse it into a number
					var dateAttr = $( itemElem ).find('.date').attr('data-time');
					return Date.parse(dateAttr);
				}
			}
		});



		// filter items on button click
		$('.filter-button-group').on( 'click', 'button', function() {
			var filterValue = $(this).attr('data-filter');
			$grid.isotope({ filter: filterValue });

			var selEl = document.getElementById("ds-dataSource");
			selEl.options[0].selected = true;
			//$("#ds-dataSource").options[0].selected = true;
			//selEl.onchange();
		});

		// filter items on select list change
		$('.filters-select').on('change', function() {
			// get filter value from option value
			var filterValue = this.value;
			// set Isotope filter
			$grid.isotope({ filter: filterValue });
		});

		// sort items on button click
		$('.sort-by-button-group').on( 'click', 'button', function() {
			var sortByValue = $(this).attr('data-sort-by');
			var sortDirection = $(this).attr('data-sort-direction') === 'asc'; // true for asc, false for desc
			$(".btn-reset-ds-sort").show();

			$grid.isotope({
				sortBy: sortByValue,
				sortAscending: sortDirection
			});
		
			var sortByValue = $(this).attr('data-sort-by');
			$grid.isotope({ sortBy: sortByValue });
			console.log("sort by: "+sortByValue);
		});

		// change is-checked class on buttons
		$('.button-group').each( function( i, buttonGroup ) {
		var $buttonGroup = $( buttonGroup );
		$buttonGroup.on( 'click', 'button', function() {
			$buttonGroup.find('.is-checked').removeClass('is-checked');
			$( this ).addClass('is-checked');
		});
		});

		

		$('#reset-ds-sort').on('click', function() {
			$grid.isotope({ sortBy: 'original-order' });
			$(".btn-reset-ds-sort").hide();
		});

		$('#btn-reset-ds-sort').on('click', function() {
			$grid.isotope({ sortBy: 'original-order' });
			$('.button').removeClass('is-checked');
			$(".btn-reset-ds-sort").hide();
		});
