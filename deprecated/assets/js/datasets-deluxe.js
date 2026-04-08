

function clearSelectList(el) {
	$("#ds-dataSource").removeClass('filter-is-checked');
}


$(document).ready(function() {
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

    // Store the filter value for each group
    var filters = {};

    // Handle button clicks
    $('.option-set').on('click', 'button', function() {
        var $this = $(this);
        // Change the "selected" class (optional, for styling)
        $this.addClass('is-checked').siblings().removeClass('is-checked');
        
        // Get group key and set filter value for group
        var group = $this.parent().attr('data-filter-group');
        filters[group] = $this.attr('data-filter-value');
        
        // Combine and apply filters
        applyCombinationFilters($grid, filters);
		//resizeDatasetGrid();
		
    });

	

    // Handle select list changes
    $('.filters-select').on('change', function() {
        var $this = $(this);
        
        // Get group key and set filter value for group
        var group = $this.attr('data-filter-group');
        filters[group] = this.value;
        
        // Combine and apply filters
        applyCombinationFilters($grid, filters);

		// Handle other UI elements
		$(".container-show-all").show();
		$(".ds-no-filters").hide();
		$("#ds-dataSource").addClass('filter-is-checked');
		//console.log("group: "+group);
		//resizeDatasetGrid();
    });

    function applyCombinationFilters($grid, filters) {
        // Flatten object by concatenating values
        // This function joins all active filter values into a single selector string (e.g., ".red.square")
        var filterValue = Object.values(filters).join('');
        
        // Apply the filter to the Isotope grid
        $grid.isotope({ filter: filterValue });
		//console.log("filters: "+filterValue);
		//resizeDatasetGrid();
    }

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
			//console.log("sort by: "+sortByValue);
		});

		// change is-checked class on buttons
		$('.button-group').each( function( i, buttonGroup ) {
			var $buttonGroup = $( buttonGroup );
			$buttonGroup.on( 'click', 'button', function() {
			$buttonGroup.find('.is-checked').removeClass('is-checked');
			$( this ).addClass('is-checked');
			});
		});
		$grid.on( 'arrangeComplete', function( event, filteredItems ) {
			//console.log( filteredItems.length );

			$(".filtered-sources-num").html(filteredItems.length);
			if ( filteredItems.length === 0 ) {
				// Show 'no results' message
				$('#no-results').show();
			} else {
				// Hide 'no results' message
				$('#no-results').hide();
			}

			if ( filteredItems.length === 27 ) {
				$(".container-show-all").hide();
				$(".ds-no-filters").show();
			}
			resizeDatasetGrid();
		});

		$('#btn-reset-ds-sort').on('click', function() {
			$grid.isotope({ sortBy: 'original-order' });
			$('.btn-sort').removeClass('is-checked');
			$(".btn-reset-ds-sort").hide();
		});

		
		$('.btn-filter').on('click', function() {
			$(".container-show-all").show();
			$(".ds-no-filters").hide();

		});
		$('.btn-show-all').on('click', function() {
			filters = {};
    		$grid.isotope({ filter: '*' });
			var selEl = document.getElementById("ds-dataSource");
			selEl.options[0].selected = true;
			$('.btn-filter').removeClass('is-checked');
			$("#ds-dataSource").removeClass('filter-is-checked');
			$(".container-show-all").hide();
			$(".ds-no-filters").show();
		});
		

});
