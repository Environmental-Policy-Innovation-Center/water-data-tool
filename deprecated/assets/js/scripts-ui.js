function mobileResize() {
	$("#container-map-content-bottom").hide();

	$(".mapboxgl-ctrl-top-left").addClass("mapboxgl-search-mobile");

	$("#container-ak-hi").addClass("container-ak-hi-mobile");
	$("#container-ak-hi").removeClass("container-ak-hi-desktop");

	$("#container-menu-10").addClass("filter-menu-mobile");
	$("#container-menu-10").removeClass("filter-menu-desktop");

	$(".map-content-wrapper").addClass("map-content-wrapper-mobile");
	$(".map-content-wrapper").removeClass("map-content-wrapper-desktop");

	$("#container-menu-btn-10").addClass("container-menu-btn-10-mobile");

	$(".show-for-mobile").show();
};


function setLayout() {
	const winHeight = $(window).height();
	const winWidth = $(window).width();

	//$("#container-map").height(winHeight);
	$(".container-main-content").height(winHeight);
	$(".container-nav-panel").height(winHeight);
	resizeDatasetGrid();

	var windowWidth = $(window).width();
	if (windowWidth <=768){
		$(".container-main-content").width(windowWidth);
		document.getElementById("container-map").style.left = "0px";
		document.getElementById("container-datasets").style.left = "0px";
		document.getElementById("container-documentation").style.left = "0px";
		document.getElementById("container-downloads").style.left = "0px";
		$(".container-main-content").height(winHeight-125);

		mobileResize();

	}else{

		if ($("#toggle-button").hasClass("open")) {
		// nav panel is open
		$(".container-main-content").width(windowWidth - 250);
			document.getElementById("container-map").style.left = "250px";
			document.getElementById("container-datasets").style.left = "250px";
			document.getElementById("container-documentation").style.left = "250px";
			document.getElementById("container-downloads").style.left = "250px";
		} else {
			// nav panel is minified
			$(".container-main-content").width(windowWidth - 120);
			document.getElementById("container-map").style.left = "120px";
			document.getElementById("container-datasets").style.left = "120px";
			document.getElementById("container-documentation").style.left = "120px";
			document.getElementById("container-downloads").style.left = "120px";
		}
	}
		

	if (windowWidth >=768){
		$(".container-menu").hide();
		let counter = 0;
		do {
			counter++; // Increment the counter
			$("#container-menu-" + counter).hide();
			$("#container-menu-btn-" + counter).removeClass("active");
		} while (counter < 11);
	}

	// FILTER MENU POSITIONING AND ORGANIZATION RESPONSIVE TO BROWSER WINDOW WIDTH

	// 5. POPULATION
	if (winWidth <= 1440) {
		$("#container-menu-5-items").insertAfter("#more-filter-grp-5");
		$(".filter-5").addClass("hidden");
	}
	if (winWidth > 1440) {
		$("#container-menu-5-items").insertAfter("#main-filter-grp-5");
		$(".filter-5").removeClass("hidden");
	}
	
	// 4. COMPLIANCE
	if (winWidth <= 1290) {
		$("#container-menu-4-items").insertAfter("#more-filter-grp-4");
		$(".filter-4").addClass("hidden");
	}
	if (winWidth > 1290) {
		$("#container-menu-4-items").insertAfter("#main-filter-grp-4");
		$(".filter-4").removeClass("hidden");
	}

	// 3. BOUNDARIES
	if (winWidth <= 1110) {
		$("#container-menu-3-items").insertAfter("#more-filter-grp-3");
		$(".filter-3").addClass("hidden");
	}
	if (winWidth > 1110) {
		$("#container-menu-3-items").insertAfter("#main-filter-grp-3");
		$(".filter-3").removeClass("hidden");
	}
	
	// 2. ATTRIBUTES
	if (winWidth <= 950) {
		$("#container-menu-2-items").insertAfter("#more-filter-grp-2");
		$(".filter-2").addClass("hidden");
	}
	if (winWidth > 950) {
		$("#container-menu-2-items").insertAfter("#main-filter-grp-2");
		$(".filter-2").removeClass("hidden");
	}

	// 1. SOURCE
	if (winWidth <= 768) {
		$("#container-menu-1-items").insertAfter("#more-filter-grp-1");
		$(".filter-1").addClass("hidden");
		//$("#container-menu-btn-10").html("");
		$("#container-menu-btn-10").hide();

		$("#container-map-ui-top").addClass("filters-mobile-display");
		$("#container-map-ui-top").removeClass("filters-desktop-display");

		mobileResize();
	}
	if (winWidth > 768) {
		$("#container-menu-1-items").insertAfter("#main-filter-grp-1");
		$(".filter-1").removeClass("hidden");
		$("#container-menu-btn-10").html("More");
		$("#container-map-ui-top").removeClass("filters-mobile-display");
		$("#container-map-ui-top").addClass("filters-desktop-display");

		$("#container-map-content-bottom").show();

		$(".mapboxgl-ctrl-top-left").removeClass("mapboxgl-search-mobile");

		$("#container-ak-hi").addClass("container-ak-hi-desktop");
		$("#container-ak-hi").removeClass("container-ak-hi-mobile");

		$("#container-menu-10").removeClass("filter-menu-mobile");
		$("#container-menu-10").addClass("filter-menu-desktop");

		$(".map-content-wrapper").removeClass("map-content-wrapper-mobile");
		$(".map-content-wrapper").addClass("map-content-wrapper-desktop");

		$("#container-menu-btn-10").removeClass("container-menu-btn-10-mobile");

		$("#container-menu-btn-10").show();
	}


	// Filter counts
	updateMoreFilterCount();

};
document.addEventListener('DOMContentLoaded', function() {

	$('.btn-close-map-info').click(function(){
		$("#container-map-content-bottom").hide();
	});

	$('.btn-close-map-filters').click(function(){
		$("#container-menu-10").hide();
		$("#container-menu-btn-10").removeClass("active");
	});

	// sizing and positioning
	window.addEventListener('resize', function() {
		// Code to execute when the window is resized

		var windowHeight = $(window).height();
		var windowWidth = $(window).width();
		$("#data-table").height(windowHeight - 250);
		if (windowWidth <=768){
			$(".container-main-content").width(windowWidth);
			document.getElementById("container-map").style.left = "0px";
			document.getElementById("container-datasets").style.left = "0px";
			document.getElementById("container-documentation").style.left = "0px";
			document.getElementById("container-downloads").style.left = "0px";
			document.getElementById("container-table").style.left = "0px";
			$(".show-for-mobile").show();


			
		}else{
			$(".show-for-mobile").hide();

			$(".mobile-btn").addClass("closed");
		$("#container-mobile-menu").hide();
		$(".mm-icon-bars").removeClass("hidden");
		$(".mm-icon-x").addClass("hidden");

			if ($("#toggle-button").hasClass("open")) {
			// nav panel is open
			$(".container-main-content").width(windowWidth - 250);
				document.getElementById("container-map").style.left = "250px";
				document.getElementById("container-datasets").style.left = "250px";
				document.getElementById("container-documentation").style.left = "250px";
				document.getElementById("container-downloads").style.left = "250px";
				document.getElementById("container-table").style.left = "250px";
			} else {
				// nav panel is minified
				$(".container-main-content").width(windowWidth - 120);
				document.getElementById("container-map").style.left = "120px";
				document.getElementById("container-datasets").style.left = "120px";
				document.getElementById("container-documentation").style.left = "120px";
				document.getElementById("container-downloads").style.left = "120px";
				document.getElementById("container-table").style.left = "120px";
			}
		}
	});

	// FILTER EXPAND / COLLAPSE ACTIONS

	// COMPLIANCE: Health violations 5 years
	$('#viols-health-5yrs').click(function(){
		if($(this).is(':checked')){
			$("#filter-subcat-violations-5yrs").slideDown();
			$('.viols-health-5yrs').prop('checked', true);
			$('#loading-mask').show();
			setTimeout(() => {
				//console.log("updating filter from viols-health-5yrs click");
				updateFilter();
				$('#loading-mask').hide();
			},0);		
			//$('.viols-health-5yrs:not(:checked)').trigger('click'); //will show slider for each
		} else {
			$('.viols-health-5yrs').prop('checked', false); 
			$('#loading-mask').show();
			setTimeout(() => {
				//console.log("updating filter from viols-health-5yrs click");
				updateFilter();
				$('#loading-mask').hide();
			},0);		
			//$("#filter-subcat-violations-5yrs").slideUp();
			//$('.viols-health-5yrs:checked').trigger('click'); //will hide slider for each
		}
	});

	// COMPLIANCE: Health violations 10 years
	$('#viols-health').click(function(){
		if($(this).is(':checked')){
			$("#filter-subcat-violations").slideDown();
			$('.viols-health').prop('checked', true);
			$('#loading-mask').show();
			setTimeout(() => {
				//console.log("updating filter from viols-health click");
				updateFilter();
				$('#loading-mask').hide();
			},0);		
			//$('.viols-health:not(:checked)').trigger('click'); //will show slider for each
		} else {
			$('.viols-health').prop('checked', false); 
			$('#loading-mask').show();
			setTimeout(() => {
				//console.log("updating filter from viols-health click");
				updateFilter();
				$('#loading-mask').hide();
			},0);		
			//$("#filter-subcat-violations").slideUp();
			//$('.viols-health:checked').trigger('click'); //will hide slider for each
		}
	});

	// ENVIRONMENTAL: Watershed Hazards
	$('#watershed-hazards').click(function(){
		if($(this).is(':checked')){
			$("#filter-subcat-watershed-hazards").slideDown();
			$('.watershed-hazards').prop('checked', true);
			$('#loading-mask').show();
			setTimeout(() => {
				//console.log("updating filter from watershed-hazards click");
				updateFilter();
				$('#loading-mask').hide();
			},0);		
			//$('.watershed-hazards:not(:checked)').trigger('click'); //will show slider for each
		} else {
			$('.watershed-hazards').prop('checked', false); 
			$('#loading-mask').show();
			setTimeout(() => {
				//console.log("updating filter from watershed-hazards click");
				updateFilter();
				$('#loading-mask').hide();
			},0);		
		}
	});

	


	$('#annual-water-sewer-bill').click(function(){
		if($(this).is(':checked')){
			$("#filter-subcat-water-sewer-bill").slideDown();
		} else {
			$("#filter-subcat-water-sewer-bill").slideUp();
		}
		$(".water-sewer-bill").prop('checked',true); //reset to all checked
		$("#annual-water-sewer-bill-no-info").prop('checked', false);
	});


	$(".btn-toggle-panel").click(function() {
		// check if the nav panel is open or closed
		if ($("#toggle-button").hasClass("open")) {
			// change the width of the left-hand panel to 120px
			$(".container-nav-panel").width(120);

			// change position and width of the map to account for the left-hand panel size change
			document.getElementById("container-map").style.left = "120px";
			$("#container-map").width(windowWidth - 120);

			// shift CSS classes to keep track of toggle state logic
			$("#toggle-button").removeClass("open");
			$("#toggle-button").addClass("close");
			$(".hide-when-collapsed").hide();
			$(".hide-when-collapsed-fade").hide();
			$(".show-when-collapsed").show();

			$("#container-sidebar").addClass("sidebar-minified");

			// trigger a resize to refresh and re-render the MapBox map based on size shifts
			window.dispatchEvent(new Event('resize'));
		} else {
			$(".container-nav-panel").width(250);
			document.getElementById("container-map").style.left = "250px";
			$("#container-map").width(windowWidth - 250);

			$("#toggle-button").addClass("open");
			$("#toggle-button").removeClass("close");
			$(".hide-when-expanded").hide();
			$(".hide-when-collapsed").show();

			$("#container-sidebar").removeClass("sidebar-minified");

			setTimeout(function() {
				$(".hide-when-collapsed-fade").fadeIn(1000);
			}, 0);

			window.dispatchEvent(new Event('resize'));
		}
	});
});

$('input[name=water-source]').on('change', function() {
	$('#water-source-ground').prop('checked', false);
	$('#water-source-surface').prop('checked', false);
	if($(this).prop('id')=='ws-ground' || $(this).prop('id')=='ws-both')
		$('#water-source-ground').prop('checked', true);
	if($(this).prop('id')=='ws-surface' || $(this).prop('id')=='ws-both')
		$('#water-source-surface').prop('checked', true);

	$('#loading-mask').show();
	setTimeout(() => {
		updateFilter();
		$('#loading-mask').hide();
	},0);		
});

$('input[name=boundary-type]').on('change', function() {
	$('#type-modeled').prop('checked', false);
	$('#type-system-sourced').prop('checked', false);
	if($(this).prop('id')=='bt-modeled' || $(this).prop('id')=='bt-both')
		$('#type-modeled').prop('checked', true);
	if($(this).prop('id')=='bt-system' || $(this).prop('id')=='bt-both')
		$('#type-system-sourced').prop('checked', true);

	$('#loading-mask').show();
	setTimeout(() => {
		updateFilter();
		$('#loading-mask').hide();
	},0);
});

function closeSubMenu(menuNum) {
	$("#container-menu-" + menuNum).hide();
};

// check height of datasource content and add link to see more if it is greater than default height of 470px
function resizeDatasetGrid(){
	let counter = 0;
		do {
			counter++;
			var ds_content_height = $(".ds-content-"+counter).height();
			if ((ds_content_height > 470)&&($(".dataset-inner-"+counter).hasClass("default"))){
				$(".ds-expand-"+counter).show();
			} else {
				$(".ds-expand-"+counter).hide();
			}
		} while (counter < 40);
};

function ds_expand(el) {
	$(".dataset-inner-" + el).addClass('expanded');
	// trigger the isotope layout to resize elements
	$('.grid').isotope('layout');
	$(".dataset-inner-"+el).removeClass("default");
	resizeDatasetGrid();
	$(".ds-expand-"+el).hide();
	$(this).hide();
};

function showFilters(el) {
	if($(".btn-ds-sort").hasClass("active")){
		$(".container-ds-sort").hide();
		$(".btn-ds-sort").removeClass("active");
		$(".btn-ds-filter").addClass("active");
		$(".container-ds-filter").show();
	} else if($(".btn-ds-filter").hasClass("active")){
		$(".container-ds-filter").slideUp();
		$(".btn-ds-filter").removeClass("active");
	} else {
		$(".container-ds-filter").slideDown();
		$(".btn-ds-filter").addClass("active");
	}
};

function showSort(el) {
	if($(".btn-ds-filter").hasClass("active")){
		$(".container-ds-filter").hide();
		$(".btn-ds-filter").removeClass("active");
		$(".btn-ds-sort").addClass("active");
		$(".container-ds-sort").show();
	} else if($(".btn-ds-sort").hasClass("active")){
		$(".container-ds-sort").slideUp();
		$(".btn-ds-sort").removeClass("active");
	} else {
		$(".container-ds-sort").slideDown();
		$(".btn-ds-sort").addClass("active");
	}
};


function showOptions(filter) {
	$("#container-filter-" + filter).slideDown();
	$("#container-filter-" + filter).removeClass('hidden');
	$(".btn-filter-" + filter).addClass('active');
};

function hideOptions(filter) {
	$("#container-filter-" + filter).slideUp();
	$("#container-filter-" + filter).addClass('hidden');
	$(".btn-filter-" + filter).removeClass('active');
};

function popSize(bin) {
	if ($(".pop-size-" + bin).hasClass('active')) {
		$(".pop-size-" + bin).removeClass('active');
		// code to show selected population bin data
	} else {
		$(".pop-size-" + bin).addClass('active');
		// code to hide selected population bin data
	}
	
	// exception for first element to handle border width
	if ($(".pop-size-1").hasClass('active')) {
		$(".pop-size-1").addClass('active-first');
	} else {
		$(".pop-size-1").removeClass('active-first');
	}
};



function wsb(b) {
	$(".wsb-box").removeClass("active");
	$(".wsb-size-box").removeClass("active");
	$(".wsb-" + b).addClass("active");

	// exception for first element to handle border width
	if ($(".wsb-1").hasClass('active')) {
		$(".wsb-1").addClass('active-first');
	} else {
		$(".wsb-1").removeClass('active-first');
	}

	// reset all checkboxes
	$(".water-sewer-bill").prop('checked', false);

	// set checkboxes based on selection
	switch(b) {
		case 1:
			// any
			$(".water-sewer-bill").prop('checked', true);
			$("#annual-water-sewer-bill-no-info").prop('checked', false);
			break;
		case 2:
			// less than 125
			$("#annual-water-sewer-bill-lt125").prop('checked', true);
			break;
		case 3:
			// less than 250
			$("#annual-water-sewer-bill-lt125").prop('checked', true);
			$("#annual-water-sewer-bill-125-249").prop('checked', true);
			break;
		case 4:
			// less than 500
			$("#annual-water-sewer-bill-lt125").prop('checked', true);
			$("#annual-water-sewer-bill-125-249").prop('checked', true);
			$("#annual-water-sewer-bill-250-499").prop('checked', true);
			break;
		case 5:
			// less than 750
			$("#annual-water-sewer-bill-lt125").prop('checked', true);
			$("#annual-water-sewer-bill-125-249").prop('checked', true);
			$("#annual-water-sewer-bill-250-499").prop('checked', true);
			$("#annual-water-sewer-bill-500-749").prop('checked', true);
			break;
		case 6:
			// less than 1000
			$("#annual-water-sewer-bill-lt125").prop('checked', true);
			$("#annual-water-sewer-bill-125-249").prop('checked', true);
			$("#annual-water-sewer-bill-250-499").prop('checked', true);
			$("#annual-water-sewer-bill-500-749").prop('checked', true);
			$("#annual-water-sewer-bill-750-999").prop('checked', true);
			break;
		case 7:
			// more than 1000
			$("#annual-water-sewer-bill-gt1000").prop('checked', true);
			break;
		case 8:
			// no info only
			$("#annual-water-sewer-bill-no-info").prop('checked', true);
			break;
	}

	

	$('#loading-mask').show();
	setTimeout(() => {
		updateFilter();
		$('#loading-mask').hide();
	},0);		
}

function showSection(el) {
	//console.log("#container-" + el);
	$(".container-main-content").addClass("hidden");
	$(".nav-item").removeClass("active");
	$("#container-" + el).removeClass('hidden');
	$(".nav-" + el).addClass('active');
	$(".mobile-btn").addClass("closed");
	$("#container-mobile-menu").hide();
	$(".mm-icon-bars").removeClass("hidden");
	$(".mm-icon-x").addClass("hidden");
	$("#filter-list-container").addClass("hidden");

	window.dispatchEvent(new Event('resize'));
	if (el == "map"){
		$("#filter-list-container").removeClass("hidden");
	}
	if (el == "datasets"){
		resizeDatasetGrid();
	}
	$('.container-main-content').scrollTop(0);
};

function showMap(el) {
	$(".container-main-content").addClass("hidden");
	$(".nav-item").removeClass("active");
	//console.log("#container-" + el);
	$("#container-table").addClass("hidden");
	$(".nav-table").removeClass("active");
	$("#container-" + el).removeClass('hidden');
	$(".nav-map-toggle").addClass('active');
	$(".nav-map").addClass('active');

	$(".hide-for-table").show();

	if(!$('#boil-water-notices').is(':checked'))
		$('.bwn-content-wrapper').hide();

	$(".mapboxgl-ctrl-group").show();

	$(".map-white").show();
	$(".map-dark").hide();
	$(".table-white").hide();
	$(".table-dark").show();
	$(".mapboxgl-ctrl-top-left").show();

	$(".mobile-btn").addClass("closed");
	$("#container-mobile-menu").hide();
	$(".mm-icon-bars").removeClass("hidden");
	$(".mm-icon-x").addClass("hidden");

	
	window.dispatchEvent(new Event('resize'));
	if (el == "map"){
		$("#filter-list-container").removeClass("hidden");
	}
	
};

function showTable(el) {

	//console.log("#container-" + el);
	//$(".container-main-content").addClass("hidden");
	//$(".nav-item").removeClass("active");
	$(".nav-map-toggle").removeClass("active");
	$("#container-" + el).removeClass('hidden');
	$(".nav-" + el).addClass('active');

	$(".hide-for-table").hide();
	$(".mapboxgl-ctrl-group").hide();

	$(".map-white").hide();
	$(".map-dark").show();
	$(".table-white").show();
	$(".table-dark").hide();

	$(".mapboxgl-ctrl-top-left").hide();

	window.dispatchEvent(new Event('resize'));
	if (el == "map"){
		$("#filter-list-container").removeClass("hidden");
	}

	$('#loading-mask').show();
	setTimeout(() => {
		//console.log("updating filter from clear filter click");
		populateTable();
		$('#loading-mask').hide();
	},0);
	var winHeight = $(window).height();
	$("#data-table").height(windowHeight - 250);
	window.dispatchEvent(new Event('resize'));
};

function closeReport() {
	$("#filter-list-container").removeClass("hidden");
	$("#container-map").removeClass("hidden");
	$("#container-report").addClass('hidden');
	window.dispatchEvent(new Event('resize'));
};



function mobileMenu() {
	if($(".mobile-btn").hasClass("closed")){
		$(".mobile-btn").removeClass("closed");
		$("#container-mobile-menu").show();
		$(".mm-icon-bars").addClass("hidden");
		$(".mm-icon-x").removeClass("hidden");
	}else{
		$(".mobile-btn").addClass("closed");
		$("#container-mobile-menu").hide();
		$(".mm-icon-bars").removeClass("hidden");
		$(".mm-icon-x").addClass("hidden");
	}
};

function showMenu(menuNum) {
	if ($("#container-menu-btn-" + menuNum).hasClass("active")) {
		// hide filter menu 
		$("#container-menu-" + menuNum).hide();
		$("#container-menu-btn-" + menuNum).removeClass("active");
	} else {
		// otherwise hide any open menu before ...
		let counter = 0;
		do {
			counter++;
			$("#container-menu-" + counter).hide();
			$("#container-menu-btn-" + counter).removeClass("active");
			setLayout();

		} while (counter < 11);


		// ... showing the selected filter menu and handling a bunch of conditional positioning logic
		$("#container-menu-" + menuNum).show();
		$("#container-menu-btn-" + menuNum).addClass("active");

		// get current width of window viewport
		const winWidth = $(window).width();
		const winHeight = $(window).height();

		document.getElementById("container-menu-" + menuNum).style.maxHeight = (450) + 'px';

		// Define various elements for size and positioning
		const elementSideBar = document.getElementById('container-sidebar');

		const elementMenu = document.getElementById('container-menu-' + menuNum);

		// Get element positions relative to the viewport
		const rectSidebar = elementSideBar.getBoundingClientRect();

		const rectMenu = elementMenu.getBoundingClientRect();
		var sidebarWidth = rectSidebar.width;
		var menuWidth = rectMenu.width;

		var elementMenuBtn = document.getElementById('container-menu-btn-' + menuNum);
		var rectMenuBtn = elementMenuBtn.getBoundingClientRect();
		var menuBTNWidth = rectMenuBtn.width;


		// set the menu position aligned left of parent button
		var menuPos = rectMenuBtn.left;

		// get the width of the menu as positionally aligned left of parent button
		var menuExtent = (menuWidth + menuPos + 20);

		///console.logenuExtent width: "+menuExtent);
		///console.logindow width: "+winWidth);

		// check if menu width at position exceeds viewport width
		if (menuExtent <= winWidth) {
			// if fits within window width, set position minus the sidebar width
			menuPos -= sidebarWidth;
		} else if (((menuExtent > winWidth) || (menuNum == 10))) {
			// otherwise calculate right-hand alignment of parent button
			menuPos -= (sidebarWidth + menuWidth) - menuBTNWidth;
		}

		// determine positioning for visible menus or those absorbed into the more
		document.getElementById("container-menu-" + menuNum).style.left = 'initial';
		document.getElementById("container-menu-" + menuNum).style.right = 'initial';
		document.getElementById("container-menu-" + menuNum).style.left = (menuPos + "px");

		$('.container-menu').scrollTop(0);


		/*//console.log					top: rectMenuBtn.top, // Distance from viewport top
			left: rectMenuBtn.left, // Distance from viewport left
			bottom: rectMenuBtn.bottom, // Distance from viewport top to element bottom
			right: rectMenuBtn.right, // Distance from viewport left to element right
			width: rectMenuBtn.width, // Element's width including padding
			height: rectMenuBtn.height // Element's height including padding
		});*/
	}
};

var windowWidth = $(window).width();
var windowHeight = $(window).height();

window.addEventListener("resize", setLayout);
setLayout();

function showThis(el) {
	$(el).show();
};