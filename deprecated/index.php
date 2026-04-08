<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
if ( ! isset($_SERVER['HTTPS']) && $_SERVER["SERVER_NAME"] != 'localhost') {
   header('Location: https://' . $_SERVER["SERVER_NAME"] . $_SERVER['REQUEST_URI']);
}
include "dbFunctions.inc.php";
$db = 'acs';
$schema = 'epic_water_tool'; //staging data schema

if($_SERVER['SCRIPT_NAME'] == '/water-data-tool/wdt_mvt.php' && !$_SERVER['SERVER_NAME'] == 'localhost') {
	$schema = 'epic_water_tool_production';
}

$sql = "select to_char(max(last_import_date), 'MM/DD/YYYY at HH:MI AM EST') as lastupdatedt from $schema.file_import_tracker;";
$lastupdatedt = @get_value_from_db($db,$sql,$host_prod4ro);

?>
<!DOCTYPE html>
<html>

<head>
	<meta charset="utf-8">
	<title>Water Data Tool</title>
	<meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no">

	<!-- Mapbox resources -->
	<link href="https://api.mapbox.com/mapbox-gl-js/v3.14.0/mapbox-gl.css" rel="stylesheet">
	<script src="https://api.mapbox.com/mapbox-gl-js/v3.14.0/mapbox-gl.js"></script>
	<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
	<script src="https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-geocoder/v5.1.0/mapbox-gl-geocoder.min.js"></script>
	<link rel="stylesheet" href="https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-geocoder/v5.1.0/mapbox-gl-geocoder.css" type="text/css">
	<script src="assets/js/scripts.js"></script>

	<script src="assets/js/charts.js"></script>

	<!-- desktop -->
	<link type="text/css" rel="stylesheet" media="all" href="assets/css/styles.css">

	<!-- mobile -->
	<link type="text/css" rel="stylesheet" media="all and (max-width: 768px)" href="assets/css/mobile.css">

	<!-- Highcharts library for histograms -->
	<script src="assets/js/highcharts.js"></script>

	<!-- Isotope library for dataset card filter and sorting -->
	<script src="assets/js/isotope.pkgd.min.js"></script>


	
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Public+Sans:ital,wght@0,100..900;1,100..900&display=swap" rel="stylesheet">

	<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/2.3.7/css/dataTables.dataTables.min.css">
	<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/fixedcolumns/5.0.5/css/fixedColumns.dataTables.min.css">
	<script type="text/javascript" charset="utf8" src="https:////cdn.datatables.net/2.3.7/js/dataTables.min.js"></script>	
	<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/fixedcolumns/5.0.5/js/dataTables.fixedColumns.min.js"></script>	
	<script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/fixedcolumns/5.0.5/js/fixedColumns.dataTables.min.js"></script>	

</head>

<style>
	#loading-mask {
		position: absolute;
		top: 0px;
		left: 0px;
		width:100%;
		height:100%;
		z-index: 1002;
		text-align: center;
		background: rgba(0, 0, 0, 0.6);
	}
	#loading-mask p{
		padding-top: 200px;
		font-size:1.4em;
		color:#fff;

	}
	#filter-list-container {
		position: absolute;
		bottom: 60px;
		left: 300px;
		background: white;
		padding: 10px;
		border-radius: 10px;
		z-index: 98;
		max-height: 200px;
		overflow-y: auto;
		border: 2px solid #333;

	}
	
	#filter-list-container ul {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	#filter-list-container ul li {
		font-size: 13px;
		color: #222;
	}

	#filter-list-container button {
		background-color: #fff;
		border: 1px solid #222;
		color: #222;
		border-radius: 8px;
		font-size: 10px;
		width: 16px;
		height: 16px;
		padding: 0;
		margin: 0;
	}	
	.tippy-arrow {
  		color: #dedede;
	}

	.tippy-box {
  		background-color: #dedede;
	}

	.slider-subhead {
		font-weight: bold;
		font-size: 12px;
		margin: 8px 0px 8px 40px;
	}

	.mapping-options {
		text-align: center;
		padding-bottom: 10px;
	}
	.mapping-options p {
		text-align: center;
		margin:0;
		padding:4px;
	}
	.color-selection {
		width: 120px;
		height: 26px;
		border-radius: 3px;
	}
	.color-bar-container {
		margin-top: 4px;
		display:none;
	}
	.key-color {
		display: inline-block;
		position: relative;
		top: 2px;
		margin: 0;
		margin-right: 0px;
		background-color: #fff;
    	margin-right: -4px;
    	border: solid 1px #aaa;
		overflow: hidden;
		width: 20px;
		height: 15px;
	}
	.key-color-first {
		border-top-left-radius: 3px;
		border-bottom-left-radius: 3px;
	}
	.key-color-last {
		border-top-right-radius: 3px;
		border-bottom-right-radius: 3px;
	}
	.key-color-min {
		font-size: 14px;
		margin-right: 5px;
		text-align: right;
		width: 40px;
		border: unset;
	}
	.key-color-max {
		font-size: 14px;
		margin-left: 5px;
		text-align: left;
		width: 40px;
		border: unset;
	}

	.mapboxgl-ctrl-geolocate {
		position: absolute;
  		left: 250px;
		z-index: 1;
		top: -40px;
		border: 1px solid #ccc;
		border-radius: 20px;
	}

	.mapboxgl-ctrl-group button:only-child {
		border-radius: 20px;
		border: 1px solid #bfbfbf;
		background-color:#fff;
	}
	
	.mapboxgl-ctrl-top-left .mapboxgl-ctrl{
		background-color: transparent;
		box-shadow: none;
	}

	.mapboxgl-ctrl-group button:first-child,
	.mapboxgl-ctrl-group button:last-child{
		border-radius: 20px;
  		border: 1px solid #bfbfbf;
  		background-color: #fff;
		width:31px;
		height:31px;
	}

	.mapboxgl-ctrl-group button:first-child:hover,
	.mapboxgl-ctrl button.mapboxgl-ctrl-zoom-out .mapboxgl-ctrl-icon:hover{
		background-color:#f5f5f5;
	}

	.mapboxgl-ctrl-group button + button{
		border-top:none;
		margin-top:5px;
	}

	.mapboxgl-ctrl-geocoder{
		background-color:#fff !important;

	}

	.mapboxgl-ctrl-geocoder--input{
		height:40px;
	}

	div.dt-container .dt-search input{
		border:none;
		padding:0px;
		margin-left: 0px;
		border-radius: 50px;
		padding: 12px 20px;
		font-size: 14px;
		border: 1px solid #bfbfbf;
		background-color: #fff;
		width: 242px;
	}
	.dt-search{
		position: fixed;
		top: 10px;
		margin-left: -10px;
		z-index: 99999;
	}

	.mapboxgl-ctrl-geolocate{
		width: 41px;
  		height: 41px;
  		top: -50px;
	}

	.mapboxgl-ctrl-geocoder--input {
  		color: #000; /* there seems to be some Mapbox setting that reduces the opacity of this value */
	}

	/*
	.mapboxgl-ctrl-geolocate{
		width:40px !important;
		height:40px !important;
	}

	.mapboxgl-ctrl button.mapboxgl-ctrl-geolocate .mapboxgl-ctrl-icon{
		background-image: url('assets/img/icon-find-location.png');
		background-size: 20px;
	}

	@media only screen and (max-width: 768px){
	.mapboxgl-ctrl-geolocate{
		position: inherit;
		width: 33px !important;
		height: 33px !important;
	}
}*/
/* DataTable CSS default overrides */
table.dataTable.row-border > tbody > tr > *, table.dataTable.display > tbody > tr > *{
  font-size:14px;
  text-align:left;
}

table.dataTable th.dt-type-numeric div.dt-column-header, table.dataTable th.dt-type-numeric div.dt-column-footer, table.dataTable th.dt-type-date div.dt-column-header, table.dataTable th.dt-type-date div.dt-column-footer, table.dataTable td.dt-type-numeric div.dt-column-header, table.dataTable td.dt-type-numeric div.dt-column-footer, table.dataTable td.dt-type-date div.dt-column-header, table.dataTable td.dt-type-date div.dt-column-footer{
  flex-direction:inherit !important;
}

div.dt-container .dt-paging .dt-paging-button{
  text-decoration:underline !important;
}

div.dt-container .dt-paging .dt-paging-button.current, div.dt-container .dt-paging .dt-paging-button.current:hover{
border-radius: 20px;
  background: #fff;
  text-decoration: none !important;
  padding: 3px 12px;
}

table.dataTable thead > tr > th.dt-orderable-asc .dt-column-order, table.dataTable thead > tr > th.dt-orderable-desc .dt-column-order, table.dataTable thead > tr > th.dt-ordering-asc .dt-column-order, table.dataTable thead > tr > th.dt-ordering-desc .dt-column-order, table.dataTable thead > tr > td.dt-orderable-asc .dt-column-order, table.dataTable thead > tr > td.dt-orderable-desc .dt-column-order, table.dataTable thead > tr > td.dt-ordering-asc .dt-column-order, table.dataTable thead > tr > td.dt-ordering-desc .dt-column-order{
	margin: 0px 0px 0px 6px;
}

div.dt-container .dt-paging .dt-paging-button:hover{
  background: transparent;
  border: 1px solid #fff;
  color: #000 !important;
}


</style>

<body>
	<div class="mobile-header hide-for-desktop">
		<div class="m-header-left"><img src="assets/img/logo-drinking-water-explorer.png" class="logo" /></div>
		<h1>Drinking Water Explorer</h1>
		<div class="m-header-right"><a href="javascript:void(0)" onclick="mobileMenu();" class="mobile-btn closed"><img src="assets/img/icon-mobile-menu.png" class="mm-icon-bars"/><img src="assets/img/icon-mobile-menu-x.png" class="mm-icon-x hidden"/></a></div>
	</div>

	<div id="loading-mask">
		<p>LOADING DATA...</p>
	</div>
	<div id="filter-list-container" style="display:none;">
		<small>Active Filters</small>
		<ul id="filter-list">
			<!-- Filled dynamically -->
		</ul>
	</div>

	<!-- Include: Sidebar Nav -->
	 <?php include "inc-sidebar.php"; ?>

	<!-- Include: Map and filter UI system -->
	 <?php include "inc-map.php"; ?>

	 <!-- Include: Datasets -->
	 <?php include "inc-datasets.php"; ?>

	<div id="container-documentation" class="container-main-content hidden">
		<div class="container-section-inner">
			<h3 class="placeholder">Documentation</h3>

		</div>

	</div>

	<!-- Include: Downloads -->
	 <?php include "inc-downloads.php"; ?>

	<div id="container-table" class="container-main-content hidden">
		<div class="container-section-inner">

			<div class="table-header">
				<div class="table-head-col-1">
					<p><strong>Public Water Utilities <span class="geo-filter"></span></strong></p>
				</div>
				<div class="table-head-col-2">
					<a href="javascript:void(0);" class="btn-export"><img src="assets/img/icon-downloads-white.png"/>Export</a>
					<input type="radio" name="file-type" id="file-csv" checked="checked"/><label for="file-csv">.csv</label>
					<input type="radio" name="file-type" id="file-geojson" class="file-geojson" /><label for="file-geojson" class="file-geojson" >.geojson</label>
				</div>
			</div>
			
			<table id="data-table" class="display stripe"></table>
			
		</div>
	</div>

	<div id="container-report" class="hidden">
		<a href="javascript:void(0);" onclick="window.print()" id="tt-print-report" class="tippy-tooltip btn-report btn-print-report"><img src="assets/img/icon-print.png"/></a>
		<a href="javascript:void(0);" onclick="closeReport();" id="tt-close-report" class="tippy-tooltip btn-report btn-close-report"><img src="assets/img/icon-close.png"/></a>
		
		<div class="container-report-section-inner">
			<div class="header">
				<div class="header-logo">
					<div class="id-logo">
						<img src="assets/img/logo-drinking-water-explorer.png" class="logo" />
					</div>
					<div class="id-text">
						<p>Drinking</p>
						<p>Water</p>
						<p>Explorer</p>
					</div>
				</div>
				<div class="header-title">
					<p style="margin-bottom:10px;">Utility Report</p>
					<p><strong>Utility Name: </strong><span class="report-utility-name">XYZ</span></p>
					<p><strong>System ID: </strong><span class="report-system-id">1234577</span></p>
					<p><strong><span class="report-city">City</span>, <span class="report-state">State</span></strong></p>
				</div>
			</div>
			<div class="clearfix"></div>
			<div class="container-report-body">
				<h2>Overview</h2>

			</div>
		</div>
	</div>

	<div class="mobile-footer hide-for-desktop">
		<img src="assets/img/EPIC-logo.png">
		<p>Last updated on <?php echo $lastupdatedt; ?></p>
		<p>(cc) Environmental Policy Innovation Center (EPIC)</p>
	</div>
	
	<div id="container-mobile-menu" class="" style="display:none;">
		<div class="container-mobile-menu-inner">

			<p><strong>How to use this tool:</strong></p>
			<p>Search or zoom into the map to see information about public drinking water systems in areas of interest. Use the filters to customize the display.</p>
			<ul>
				<li class="nav-1"><a href="javascript:void(0);" onclick="showMap('map');" class="nav-item nav-1 nav-map active">Explore the Map</a></li>
				<li class="nav-2"><a href="javascript:void(0);" onclick="showSection('datasets');" class="nav-item nav-2 nav-datasets">Datasets</a></li>
				<li class="nav-3"><a href="https://tech-team-data.s3.us-east-1.amazonaws.com/national-dw-tool/public-data-downloads/EPIC's+Drinking+Water+Explorer+Tool+-+Methodology.pdf" target="_blank" class="nav-item nav-3 nav-documentation">Documentation</a></li>
				<li class="nav-4"><a href="javascript:void(0);" onclick="showSection('downloads');" class="nav-item nav-4 nav-downloads">Downloads</a></li>
				<li class="nav-5"><a href="https://github.com/Environmental-Policy-Innovation-Center/national-dw-tool-public" target="_blank" class="nav-item nav-5 nav-github">Github</a></li>
				<li class="nav-6"><a href="https://docs.google.com/forms/d/e/1FAIpQLSdj-JcAmFNHnyEGoou74kyL_R1YOUtsFG4dKlYl0TWWwkUcrg/viewform" target="_blank" class="nav-item nav-6 nav-feedback">Feedback</a></li>
				<li class="nav-7"><a href="mailto:watertool@policyinnovation.org" class="nav-item nav-7 nav-contact">Contact EPIC</a></li>
			</ul>
			<p style="margin:40px 0px 0px 20px;">(<a href="https://creativecommons.org/share-your-work/cclicenses/" target="_blank">cc</a>) Environmental Policy<br/>Center (EPIC)</p>
		</div>

	</div>

	<script src="assets/js/datasets-deluxe.js"></script>

	<script src="assets/js/scripts-ui.js"></script>


	<!-- Tooltip: Development -->
	<script src="https://unpkg.com/@popperjs/core@2/dist/umd/popper.min.js"></script>
	<script src="https://unpkg.com/tippy.js@6/dist/tippy-bundle.umd.js"></script>

	<!-- Tooltip: Production -->
	<!--<script src="https://unpkg.com/@popperjs/core@2"></script>-->
	<!--<script src="https://unpkg.com/tippy.js@6"></script>-->

	<script src="assets/js/tooltips.js"></script>

	

	<form id="download-geojson-request" method="post">
		<input type="hidden" name="pws_ids" id="pws_ids" value="">
	</form>

</body>

<?php

//set numBins for PHP and JS below (next 2 lines)
$numBins = 50;
function rangeSliderHistogram($slider, $unitDescription, $units, $numBins = 50)
{

	//echo html based on the following template and naming convention
	echo '
	<div id="container-filter-' . $slider . '" class="container-filter hidden">
		<div class="slider-subhead">' . $unitDescription . '</div>
		<div id="container-hc-' . $slider . '" class="container-hc"></div>
		<div class="slider-container" id="slider-container-' . $slider . '">
			<div class="range-slider">
			<div class="slider-track"></div>
			<div class="slider-range" id="sliderRange-' . $slider . '" style=""></div>
			<input type="range" id="minSlider-' . $slider . '" min="0" max="' . ($numBins - 1) . '" step="1" value="0">
			<input type="range" id="maxSlider-' . $slider . '" min="0" max="' . ($numBins - 1) . '" step="1" value="' . ($numBins - 1) . '">
			</div>
		</div>
		<div class="slider-minmax-label">
		<span class="slider-label-min">';
	if ($units == "$") echo '$'; 
	echo '<span id="minLabel-' . $slider . '">1</span>';
	if ($units == "%") echo '%'; 
	echo '</span>
		<span class="slider-label-max">';
	if ($units == "$") echo '$'; 
	echo '<span id="maxLabel-' . $slider . '">999,999,999</span>';
	if ($units == "%") echo '%'; 
	echo '
		</span>
		<span class="slider-input-min"><input class="input-number" type="hidden" name="minInput-' . $slider . '" id="minInput-' . $slider . '" min="0" max="999" step="1" value="0" /></span>
		<span class="slider-input-max"><input class="input-number" type="hidden" name="maxInput-' . $slider . '" id="maxInput-' . $slider . '" min="0" max="999" step="1" value="99" /></span>
		</div>
		<div class="clearfix"></div>
		<div class="mapping-options" id="mapping-options-' . $slider . '">
			<p><select class="color-selection" id="color-selection-' . $slider . '">
				<option value="blue" selected>Blue</option>
				<option value="green">Green</option>
				<option value="purple">Purple</option>
				<option value="red">Red</option>
				<option value="yellow">Yellow</option>
			</select><p>
			<p><input type="checkbox" id="map-' . $slider . '" class="map-checkbox" value="' . $slider . '" /> <label for="map-' . $slider . '">Continuous display</label></p>
			<div id="color-bar-' . $slider . '" class="color-bar-container">
				<div class="key-color key-color-min">1</div>
				<div class="key-color key-color-first" style="background-color: #eff6fb;"></div>
				<div class="key-color" style="background-color: #d9e8f6;"></div>
				<div class="key-color" style="background-color: #aacdec;"></div>
				<div class="key-color" style="background-color: #73b3e7;"></div>
				<div class="key-color" style="background-color: #4f97d1;"></div>
				<div class="key-color" style="background-color: #2378c3;"></div>
				<div class="key-color" style="background-color: #2c608a;"></div>
				<div class="key-color" style="background-color: #1f303e;"></div>
				<div class="key-color key-color-last" style="background-color: #11181d;"></div>
				<div class="key-color key-color-max">100</div>
			</div>
		</div>
	</div>
	';
}

echo "<script>
let numBins=" . $numBins . ";
</script>";


?>