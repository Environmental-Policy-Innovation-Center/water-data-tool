<div id="container-map" class="container-main-content">
		<div id="container-map-ui-top" class="container-map-ui">
			<ul>
				<li class="filter-1">
					<div class="container-filter-count container-filter-count-menu-1">
						<span class="filter-count-group-1">0</span>
					</div>
					<a href="javascript:void(0);" onclick="showMenu(1);" id="container-menu-btn-1">Source</a>
				</li>
				<li class="filter-2">
					<div class="container-filter-count container-filter-count-menu-2">
						<span class="filter-count-group-2">0</span>
					</div>
					<a href="javascript:void(0);" onclick="showMenu(2);" id="container-menu-btn-2">Attributes</a>
				</li>
				<li class="filter-3">
					<div class="container-filter-count container-filter-count-menu-3">
						<span class="filter-count-group-3">0</span>
					</div>
					<a href="javascript:void(0);" onclick="showMenu(3);" id="container-menu-btn-3">Boundaries</a>
				</li>
				<li class="filter-4">
					<div class="container-filter-count container-filter-count-menu-4">
						<span class="filter-count-group-4">0</span>
					</div>
					<a href="javascript:void(0);" onclick="showMenu(4);" id="container-menu-btn-4">Compliance</a>
				</li>
				<li class="filter-5">
					<div class="container-filter-count container-filter-count-menu-5">
						<span class="filter-count-group-5">0</span>
					</div>
					<a href="javascript:void(0);" onclick="showMenu(5);" id="container-menu-btn-5">Population</a>
				</li>
				<li>
					<div class="container-filter-count container-filter-count-menu-10">
						<span class="filter-count-group-10">0</span>
					</div>
					<a href="javascript:void(0);" onclick="showMenu(10);" id="container-menu-btn-10"><span class="map-filter-txt-desktop hide-for-mobile">More</span><span class="map-filter-txt-mobile hide-for-desktop">Mobile</span></a>
				</li>
			</ul>

		</div>

		<!-- 1. SOURCE -->
		<div id="container-menu-1" class="container-menu" style="display:none;">
			<div id="main-filter-grp-1"></div>
				<div id="container-menu-1-items">
					<h3>Primary type <a id="tt-source" class="tippy-tooltip"><img src="assets/img/icon-tooltip-white.png" class="visible-in-main" /><img src="assets/img/icon-tooltip-dark.png" class="visible-in-more" /></a></h3>
					<ul>
						<li><input type="radio" name="water-source" id="ws-both" checked="checked" /><label for="ws-both">Both ground and surface</label></li>
						<li><input type="radio" name="water-source" id="ws-ground" /><label for="ws-ground">Ground only</label></li>
						<li><input type="radio" name="water-source" id="ws-surface" /><label for="ws-surface">Surface only</label></li>
						<div style="display:none;">
							<li><input type="checkbox" class="toggle default-checked" checked="checked" id="water-source-ground" /><label for="water-source-ground">Ground</label></li>
							<div class="filter-cat-indent" style="display:none;">
								<li><input type="checkbox" class="toggle default-checked" checked="checked" id="water-source-ground-purchased" /><label for="water-source-ground-purchased">Purchased</label></li>
								<li><input type="checkbox" class="toggle default-checked" checked="checked" id="water-source-ground-non-purchased" /><label for="water-source-ground-non-purchased">Non-purchased</label></li>
								<li><input type="checkbox" class="toggle" id="water-source-ground-surface-influenced" /><label for="water-source-ground-surface-influenced">Ground (surface influenced)</label></li>
								<li><input type="checkbox" class="toggle" id="water-source-ground-purchased-surface-influenced"/><label for="water-source-ground-purchased-surface-influenced">Ground (purchased, surface influenced)</label></li>
							</div>
							<li><input type="checkbox" class="toggle default-checked" checked="checked" id="water-source-surface" /><label for="water-source-surface">Surface</label></li>
							<div class="filter-cat-indent" style="display:none;">
								<li><input type="checkbox" class="toggle default-checked" checked="checked" id="water-source-surface-purchased" /><label for="water-source-surface-purchased">Purchased</label></li>
								<li><input type="checkbox" class="toggle default-checked" checked="checked" id="water-source-surface-non-purchased" /><label for="water-source-surface-non-purchased">Non-purchased</label></li>
							</div>
						</div>
					</ul>

					<h3>Protection</h3>
					<ul>
						<li><input type="checkbox" class="toggle" id="has-source-water-protection"><label for="has-source-water-protection">Has source protection</label> <a id="tt-protection" class="tippy-tooltip"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					</ul>
				</div>
				<div class="filter-menu-footer">
					<a href="javascript:void(0);" onclick="resetByCategory('container-menu-1');" id="" class="btn-filters">Reset</a>
					<a href="javascript:void(0);" id="" class="btn-filters btn-apply-filters">Apply</a>
				</div>
		</div>

		<!-- 2. ATTRIBUTES -->
		<div id="container-menu-2" class="container-menu" style="display:none;">
			<div id="main-filter-grp-2"></div>
				<div id="container-menu-2-items">
					<h3>Ownership</h3>
					<ul>
						<li><input type="checkbox" class="toggle select-all default-checked rounded-checkbox" id="type-deselect-all" checked="checked"><label for="type-deselect-all" id="type-deselect-all-txt">Deselect all</label></li>
						<li><input type="checkbox" class="toggle default-checked checkbox-type" checked="checked" id="type-federal-government"><label for="type-federal-government">Federal</label></li>
						<li><input type="checkbox" class="toggle default-checked checkbox-type" checked="checked" id="type-state-government"><label for="type-state-government">State</label></li>
						<li><input type="checkbox" class="toggle default-checked checkbox-type" checked="checked" id="type-local-government"><label for="type-local-government">Local</label></li>
						<li><input type="checkbox" class="toggle default-checked checkbox-type" checked="checked" id="type-native-american"><label for="type-native-american">Tribal</label></li>
						<li><input type="checkbox" class="toggle default-checked checkbox-type" checked="checked" id="type-private"><label for="type-private">Private</label></li>
						<li><input type="checkbox" class="toggle default-checked checkbox-type" checked="checked" id="type-public-private"><label for="type-public-private">Public/Private partnership</label></li>
						
					</ul>

					<h3>Authority</h3>
					<ul>
						<li><input type="checkbox" class="toggle default-checked" checked="checked" id="primacy-type-state"><label for="primacy-type-state">State</label></li>
						<li><input type="checkbox" class="toggle default-checked" checked="checked" id="primacy-type-tribal"><label for="primacy-type-tribal">Tribal</label></li>
						<li><input type="checkbox" class="toggle default-checked" checked="checked" id="primacy-type-territory"><label for="primacy-type-territory">Territory</label></li>
					</ul>

					<h3>Distribution</h3>
					<ul>
						<li><input type="checkbox" class="toggle" id="is-wholesaler"><label for="is-wholesaler">Wholesaler</label> <a id="tt-wholesaler" class="tippy-tooltip"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					</ul>

					<h3>Facility type</h3>
					<ul>
						<li><input type="checkbox" class="toggle" id="is-school-or-daycare"><label for="is-school-or-daycare">School or daycare</label></li>
					</ul>
				</div>

				<div class="filter-menu-footer">
					<a href="javascript:void(0);" onclick="resetByCategory('container-menu-2');" id="" class="btn-filters">Reset</a>
					<a href="javascript:void(0);" id="" class="btn-filters btn-apply-filters">Apply</a>
				</div>
		</div>

		<!-- 3. BOUNDARIES -->
		<div id="container-menu-3" class="container-menu" style="display:none;">
			<div id="main-filter-grp-3"></div>
				<div id="container-menu-3-items">
					<h3>Type <a id="tt-type" class="tippy-tooltip"><img src="assets/img/icon-tooltip-white.png" /></a></h3>
					<ul>
						<li><input type="radio" name="boundary-type" id="bt-both" checked="checked" /><label for="bt-both">Both modeled and system sourced</label></li>
						<li><input type="radio" name="boundary-type" id="bt-modeled" /><label for="bt-modeled">Modeled only</label></li>
						<li><input type="radio" name="boundary-type" id="bt-system" /><label for="bt-system">System sourced only</label></li>
						<div style="display:none;">
							<li><input type="checkbox" class="toggle default-checked" checked="checked" id="type-modeled"><label for="type-modeled">Modeled</label></li>
							<li><input type="checkbox" class="toggle default-checked" checked="checked" id="type-system-sourced"><label for="type-system-sourced">System sourced</label></li>
						</div>
					</ul>

					<h3>Size</h3>
					<p><strong>Area in square miles</strong></p>
					<div class="dropdown-selectors">
						<select id="area-min" class="toggle-select min-select left">
							<option value="0"selected>No minimum</option>
							<option value="1">1</option>
							<option value="2">2</option>
							<option value="4">4</option>
							<option value="5">5</option>
							<option value="10">10</option>
							<option value="15">15</option>
							<option value="20">20</option>
							<option value="25">25</option>
							<option value="50">50</option>
							<option value="100">100</option>
							<option value="250">250</option>
							<option value="500">500</option>
						</select>
						<select id="area-max" class="toggle-select max-select right">
							<option value="1">1</option>
							<option value="2">2</option>
							<option value="4">4</option>
							<option value="5">5</option>
							<option value="10">10</option>
							<option value="15">15</option>
							<option value="20">20</option>
							<option value="25">25</option>
							<option value="50">50</option>
							<option value="100">100</option>
							<option value="250">250</option>
							<option value="500">500</option>
							<option value="999999" selected>No maximum</option>
						</select>
					</div>
				</div>
				<div class="filter-menu-footer">
					<a href="javascript:void(0);" onclick="resetByCategory('container-menu-3');" id="" class="btn-filters">Reset</a>
					<a href="javascript:void(0);" id="" class="btn-filters btn-apply-filters">Apply</a>
				</div>
		</div>

		<!-- 4. COMPLIANCE -->
		<div id="container-menu-4" class="container-menu" >
			<div id="main-filter-grp-4"></div>
			<div id="container-menu-4-items">
				<h3>Violations <a id="tt-violations" class="tippy-tooltip"><img src="assets/img/icon-tooltip-white.png" class="visible-in-main" /><img src="assets/img/icon-tooltip-dark.png" class="visible-in-more" /></a></h3>
				<ul>
					<li><input type="checkbox" class="toggle" id="compliance-open-violations"><label for="compliance-open-violations">Open violations</label></li>
					
					<li><input type="checkbox" class="" id="viols-health-5yrs"><label for="viols-health-5yrs">Health violations in the last 5 years</label></li>
					<div id="filter-subcat-violations-5yrs" class="filter-cat-indent hidden default-hidden">
						<?php //rangeSliderHistogram('viols-health-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-groundwater-5yrs"><label for="viols-groundwater-5yrs">Ground water rule</label> <a class="tippy-tooltip tt-groundwater-rules"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-groundwater-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-surface-water-5yrs"><label for="viols-surface-water-5yrs">Surface water treatment rules</label> <a class="tippy-tooltip tt-surface-water-rules"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-surface-water-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-lead-copper-5yrs"><label for="viols-lead-copper-5yrs">Lead &amp; copper</label> <a class="tippy-tooltip tt-lead-copper"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-lead-copper-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-radionuclides-5yrs"><label for="viols-radionuclides-5yrs">Radionuclides</label> <a class="tippy-tooltip tt-radionuclides"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-radionuclides-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-inorganic-5yrs"><label for="viols-inorganic-5yrs">Inorganic chemicals</label> <a class="tippy-tooltip tt-inorganic-chemicals"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-inorganic-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-synthetic-5yrs"><label for="viols-synthetic-5yrs">Synthetic organic chemicals</label> <a class="tippy-tooltip tt-synthetic-organic-chemicals"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-synthetic-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-vocs-5yrs"><label for="viols-vocs-5yrs">Volatile organic chemicals</label> <a class="tippy-tooltip tt-volatile-organic-chemicals"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-vocs-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-coliform-5yrs"><label for="viols-coliform-5yrs">Coliform</label> <a class="tippy-tooltip tt-coliform"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-coliform-5yrs', 'Number of violations',''); ?>						
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-stage-1-disinfectants-5yrs"><label for="viols-stage-1-disinfectants-5yrs">Stage 1 disinfectants</label> <a class="tippy-tooltip tt-stage-1-disinfectants"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-stage-1-disinfectants-5yrs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health-5yrs" id="viols-stage-2-disinfectants-5yrs"><label for="viols-stage-2-disinfectants-5yrs">Stage 2 disinfectants</label> <a class="tippy-tooltip tt-stage-2-disinfectants"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-stage-2-disinfectants-5yrs', 'Number of violations',''); ?>
					</div>
					
					<li><input type="checkbox" class="" id="viols-health"><label for="viols-health">Health violations in the last 10 years</label></li>
					<div id="filter-subcat-violations" class="filter-cat-indent hidden default-hidden">
						<?php //rangeSliderHistogram('viols-health', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-groundwater"><label for="viols-groundwater">Ground water rule</label> <a class="tt-groundwater-rules tippy-tooltip"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-groundwater', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-surface-water"><label for="viols-surface-water">Surface water treatment rules</label> <a class="tippy-tooltip tt-surface-water-rules"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-surface-water', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-lead-copper"><label for="viols-lead-copper">Lead &amp; copper</label> <a class="tippy-tooltip tt-lead-copper"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-lead-copper', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-radionuclides"><label for="viols-radionuclides">Radionuclides</label> <a class="tippy-tooltip tt-radionuclides"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-radionuclides', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-inorganic"><label for="viols-inorganic">Inorganic chemicals</label> <a class="tippy-tooltip tt-inorganic-chemicals"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-inorganic', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-synthetic"><label for="viols-synthetic">Synthetic organic chemicals</label> <a class="tippy-tooltip tt-synthetic-organic-chemicals"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-synthetic', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-vocs"><label for="viols-vocs">Volatile organic chemicals</label> <a class="tippy-tooltip tt-volatile-organic-chemicals"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-vocs', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-coliform"><label for="viols-coliform">Coliform</label> <a class="tippy-tooltip tt-coliform"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-coliform', 'Number of violations',''); ?>						
						<li><input type="checkbox" class="toggle viols-health" id="viols-stage-1-disinfectants"><label for="viols-stage-1-disinfectants">Stage 1 disinfectants</label> <a class="tippy-tooltip tt-stage-1-disinfectants"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-stage-1-disinfectants', 'Number of violations',''); ?>
						<li><input type="checkbox" class="toggle viols-health" id="viols-stage-2-disinfectants"><label for="viols-stage-2-disinfectants">Stage 2 disinfectants</label> <a class="tippy-tooltip tt-stage-2-disinfectants"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
						<?php rangeSliderHistogram('viols-stage-2-disinfectants', 'Number of violations',''); ?>
					</div>

					<li><input type="checkbox" class="toggle" id="viols-paperwork-5yrs"><label for="viols-paperwork-5yrs">Non-health violations in the last 5 years</label></li>
					<?php rangeSliderHistogram('viols-paperwork-5yrs', 'Number of violations',''); ?>
					<li><input type="checkbox" class="toggle" id="viols-paperwork"><label for="viols-paperwork">Non-health violations in the last 10 years</label></li>
					<?php rangeSliderHistogram('viols-paperwork', 'Number of violations',''); ?>
				</ul>

				<h3>Notices 
					<a id="tt-notices" class="tippy-tooltip tt-notices"><img src="assets/img/icon-tooltip-white.png" class="visible-in-main" /><img src="assets/img/icon-tooltip-dark.png" class="visible-in-more" /></a>
				</h3>
				<ul>
					<li><input type="checkbox" class="toggle" disabled="disabled" id="boil-water-notices"><label style="color: #888;" for="boil-water-notices">Boil water notices <span class="bwn-disabled-txt">(data unavailable <span class="geo-filter"></span>)</span></label></li>
					<?php rangeSliderHistogram('boil-water-notices', 'Number of notices',''); ?>
				</ul>
				
				<?php /*
				<h3>Drinking water non-compliance indicator</h3>
				<ul>
					<li><input type="checkbox" class="toggle" id="ejscreen-dwater"><label for="ejscreen-dwater">2024 EJScreen Score</label></li>
					<?php rangeSliderHistogram('ejscreen-dwater', 'Score as percentile',''); ?>
				</ul>
				*/ ?>
				
			</div>

			<div class="filter-menu-footer">
					<a href="javascript:void(0);" onclick="resetByCategory('container-menu-4');" id="" class="btn-filters">Reset</a>
					<a href="javascript:void(0);" id="" class="btn-filters btn-apply-filters">Apply</a>
			</div>
			


		</div>


		<!-- 5. POPULATION -->
		<div id="container-menu-5" class="container-menu" >

			<div id="main-filter-grp-5"></div>
			
			<div id="container-menu-5-items">

				<h3 class="visible-in-more">Population size <a class="tippy-tooltip tt-size"><img src="assets/img/icon-tooltip-white.png" class="visible-in-main" /><img src="assets/img/icon-tooltip-dark.png" class="visible-in-more" /></a></h3>
				<h3 class="visible-in-main">Size <a class="tippy-tooltip tt-size"><img src="assets/img/icon-tooltip-white.png" class="visible-in-main" /><img src="assets/img/icon-tooltip-dark.png" class="visible-in-more" /></a></h3>
				<div class="container-population-filter-grid">
						<a href="javascript:void(0);" onclick="popSize(1);" id="pop-very-small" class="toggle pop-size-box pop-size-box-first pop-size-1">Very small<span>500 or less</span></a><a href="javascript:void(0);" onclick="popSize(2);" id="pop-small" class="toggle pop-size-box pop-size-2">Small<span>501 - 3,300</span></a><a href="javascript:void(0);" onclick="popSize(3);"id="pop-medium" class="toggle pop-size-box pop-size-3">Medium<span>3,301 - 10,000</span></a><a href="javascript:void(0);" onclick="popSize(4);" id="pop-large" class="toggle pop-size-box pop-size-4">Large<span>10,001 - 100,000</span></a><a href="javascript:void(0);" onclick="popSize(5);" id="pop-very-large" class="toggle pop-size-box pop-size-box-last pop-size-5">Very large<span>100,000+</span></a>
						<div class="clear"></div>
				</div>

				<h3>Density</h3>
				<p><strong>People per square mile</strong></p>
				<div class="dropdown-selectors">
					<select id="density-min" class="toggle-select min-select left">
						<option value="0"selected>No minimum</option>
						<option value="1">1</option>
						<option value="10">10</option>
						<option value="20">20</option>
						<option value="50">50</option>
						<option value="100">100</option>
						<option value="250">250</option>
						<option value="500">500</option>
						<option value="1000">1000</option>
						<option value="2000">2000</option>
						<option value="4000">4000</option>
						<option value="8000">8000</option>
						<option value="10000">10000</option>
					</select>
					<select id="density-max" class="toggle-select max-select right">
						<option value="1">1</option>
						<option value="10">10</option>
						<option value="20">20</option>
						<option value="50">50</option>
						<option value="100">100</option>
						<option value="250">250</option>
						<option value="500">500</option>
						<option value="1000">1000</option>
						<option value="2000">2000</option>
						<option value="4000">4000</option>
						<option value="8000">8000</option>
						<option value="10000">10000</option>
						<option value="999999" selected>No maximum</option>
					</select>
				</div>

				<h3>Change</h3>
				<ul>
					<li><input type="checkbox" class="toggle" id="pop-change"><label for="pop-change">Change in people the last 10 years</label></li>
					<?php rangeSliderHistogram('pop-change','Percentage of change','%'); ?>
					<li><input type="checkbox" class="toggle" id="mhi-change"><label for="mhi-change">Change in income the last 10 years</label></li>
					<?php rangeSliderHistogram('mhi-change','Percentage of change','%'); ?>
				</ul>
				
				<h3>Socioeconomics</h3>
				<ul>
					<li><input type="checkbox" class="toggle" id="poverty"><label for="poverty">Households below the poverty line</label></li>
					<?php rangeSliderHistogram('poverty', 'Percentage of households',''); ?>
					<li><input type="checkbox" class="toggle" id="unemployment"><label for="unemployment">Unemployment</label></li>
					<?php rangeSliderHistogram('unemployment', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="mhi"><label for="mhi">Annual median household income</label></li>
					<?php rangeSliderHistogram('mhi', 'Total dollar amount','$'); ?>
					<li><input type="checkbox" class="toggle" id="bachelors"><label for="bachelors">Higher education attainment</label></li>
					<?php rangeSliderHistogram('bachelors', 'Percentage of the population with a bachelor\'s degree','%'); ?>

					<li><input type="checkbox" class="toggle" id="under5"><label for="under5">Children under 5</label></li>
					<?php rangeSliderHistogram('under5', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="over61"><label for="over61">Elderly over 61</label></li>
					<?php rangeSliderHistogram('over61', 'Percentage of the population','%'); ?>
				</ul>


				<h3>Race/Ethnicity</h3>
				<ul>
					<li><input type="checkbox" class="toggle" id="poc"><label for="poc">People of color</label></li>
					<?php rangeSliderHistogram('poc', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="white"><label for="white">White</label></li>
					<?php rangeSliderHistogram('white', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="black"><label for="black">Black</label></li>
					<?php rangeSliderHistogram('black', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="aian"><label for="aian">American Indian and Alaskan Native</label></li>
					<?php rangeSliderHistogram('aian', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="napi"><label for="napi">Native Hawaiian and Pacific Islanders</label></li>
					<?php rangeSliderHistogram('napi', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="asian"><label for="asian">Asian</label></li>
					<?php rangeSliderHistogram('asian', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="hisp"><label for="hisp">Latino/a</label></li>
					<?php rangeSliderHistogram('hisp', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="race-other"><label for="race-other">Other</label></li>
					<?php rangeSliderHistogram('race-other', 'Percentage of the population','%'); ?>
					<li><input type="checkbox" class="toggle" id="race-mixed"><label for="race-mixed">Mixed race</label></li>
					<?php rangeSliderHistogram('race-mixed', 'Percentage of the population','%'); ?>
				</ul>

				

				<h3>Vulnerability</h3>
				<ul>
					<li><input type="checkbox" class="toggle" id="disadvantaged"><label for="disadvantaged">Disadvantaged area</label> <a class="tippy-tooltip" id="tt-disadvantaged-area"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('disadvantaged', 'Percentage of the area','%'); ?>
					<li><input type="checkbox" class="toggle" id="svi"><label for="svi">Social Vultnerability Index</label> <a class="tippy-tooltip" id="tt-social-vulnerability-index"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('svi', 'Percentile of the population',''); ?>
					<li><input type="checkbox" class="toggle" id="cvi"><label for="cvi">Climate Vulnerability Index</label> <a class="tippy-tooltip" id="tt-climate-vulnerability-index"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('cvi', 'Percentile of vulnerability',''); ?>
				</ul>
			</div>


			<div class="filter-menu-footer">
					<a href="javascript:void(0);" onclick="resetByCategory('container-menu-5');" id="" class="btn-filters">Reset</a>
					<a href="javascript:void(0);" id="" class="btn-filters btn-apply-filters">Apply</a>
			</div>

		</div>


		<!-- MORE -->
		<div id="container-menu-10" class="container-menu container-menu-more" >

			<h2 class="hide-for-mobile">More filters</h2>
			<div class="mobile-header-map-filters hide-for-desktop">
				<h2 class="map-filter-mobile-header">Map filters</h2>
				<a href="javascript:void(0);" class="btn-close-map-filters"></a>
			</div>
			
			<div id="more-filter-grp-1"></div>
			<div id="more-filter-grp-2"></div>
			<div id="more-filter-grp-3"></div>
			<div id="more-filter-grp-4"></div>
			<div id="more-filter-grp-5"></div>

			

			<!-- FINANCIAL -->
			
			<h3>Financial <a class="tippy-tooltip" id="tt-financial"><img src="assets/img/icon-tooltip-dark.png" /></a></h3>
			<ul>
				<li><input type="checkbox" class="toggle" id="annual-water-sewer-bill"><label for="annual-water-sewer-bill">Annual water and sewer bill</label></li>
				<div id="filter-subcat-water-sewer-bill" class="filter-cat-indent hidden default-hidden">

				<div class="slider-subhead">Amount paid by most customers</div>

				<div class="container-water-sewer-bill-filter-grid">
					<a href="javascript:void(0);" onclick="wsb(1);" id="wsb-any" class="toggle wsb-box wsb-box-first wsb-1 active active-first default-checked wsb-1line">Any</a><a href="javascript:void(0);" onclick="wsb(2);" id="wsb-125" class="toggle wsb-box wsb-2"><span>less than</span>$125</a><a href="javascript:void(0);" onclick="wsb(3);" id="wsb-250" class="toggle wsb-box wsb-3"><span>less than</span>$250</a><a href="javascript:void(0);" onclick="wsb(4);" id="wsb-500" class="toggle wsb-box wsb-4"><span>less than</span>$500</a><a href="javascript:void(0);" onclick="wsb(5);" id="wsb-750" class="toggle wsb-box wsb-5"><span>less than</span>$750</a><a href="javascript:void(0);" onclick="wsb(6);" id="wsb-1000" class="toggle wsb-box wsb-6"><span>less than</span>$1000</a><a href="javascript:void(0);" onclick="wsb(7);" id="wsb-1000-plus" class="toggle wsb-box wsb-box-last wsb-7"><span>more than</span>$1000</a><div class="clear"></div>
				</div>

				<div style="display:none;">
					<li><input type="checkbox" class="toggle water-sewer-bill default-checked" id="annual-water-sewer-bill-lt125" checked="checked">Most pay < $125 for water & sewer</li>
					<li><input type="checkbox" class="toggle water-sewer-bill default-checked" id="annual-water-sewer-bill-125-249" checked="checked">Most pay between $125-249 for water & sewer</li>
					<li><input type="checkbox" class="toggle water-sewer-bill default-checked" id="annual-water-sewer-bill-250-499" checked="checked">Most pay between $250-499 for water & sewer</li>
					<li><input type="checkbox" class="toggle water-sewer-bill default-checked" id="annual-water-sewer-bill-500-749" checked="checked">Most pay between $500-749 for water & sewer</li>
					<li><input type="checkbox" class="toggle water-sewer-bill default-checked" id="annual-water-sewer-bill-750-999" checked="checked">Most pay between $750-999 for water & sewer</li>
					<li><input type="checkbox" class="toggle water-sewer-bill default-checked" id="annual-water-sewer-bill-gt1000" checked="checked">Most pay > $1000 for water & sewer</li>
				</div>
				<li><input type="checkbox" onclick="setTimeout(() => {if($(this).is(':checked')) wsb(8); else wsb(1);},0);" class="toggle water-sewer-bill" id="annual-water-sewer-bill-no-info">Show systems with no available information on rates</li>
				</div>
			</ul>

			<!-- FUNDING -->
			<h3>Funding (2021 - 2025) <a class="tippy-tooltip" id="tt-funding"><img src="assets/img/icon-tooltip-dark.png" /></a></h3>
			<ul>
				<li><input type="checkbox" class="toggle" id="projs-funded"><label for="projs-funded">State revolving fund financing</label></li>
				<?php rangeSliderHistogram('projs-funded','Number of times received',''); ?>
				<li><input type="checkbox" class="toggle" id="total-assistance"><label for="total-assistance">State revolving fund assistance</label></li>
				<?php rangeSliderHistogram('total-assistance','Amount received in dollars','$'); ?>
				<li><input type="checkbox" class="toggle" id="total-prin-forgive"><label for="total-prin-forgive">State revolving fund principal forgiveness</label></li>
				<?php rangeSliderHistogram('total-prin-forgive', 'Amount forgiven in dollars','$'); ?>
			</ul>

			<!-- ENVIRONMENTAL -->
			<h3>Environmental</h3>
			<ul>
				<li><input type="checkbox" class="" id="watershed-hazards"><label for="watershed-hazards">Potential Watershed Hazards</label> <a class="tippy-tooltip" id="tt-watershed-hazards"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
				<div id="filter-subcat-watershed-hazards" class="filter-cat-indent hidden default-hidden">
					<li><input type="checkbox" class="toggle watershed-hazards" id="num-facilities"><label for="num-facilities">Source water connections</label> <a class="tippy-tooltip" id="tt-source-water-connections"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('num-facilities','Number of well or intake locations',''); ?>
					<li><input type="checkbox" class="toggle watershed-hazards" id="permit-violations"><label for="permit-violations">Pollution permits with breaches</label> <a class="tippy-tooltip" id="tt-pollution-permits-w-breaches"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('permit-violations','Number of permit breaches',''); ?>
					<li><input type="checkbox" class="toggle watershed-hazards" id="open-usts"><label for="open-usts">Underground storage tanks</label> <a class="tippy-tooltip" id="tt-underground-storage-tanks"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('open-usts','Number of open tanks',''); ?>
					<li><input type="checkbox" class="toggle watershed-hazards" id="rmps"><label for="rmps">Risk management plan facilities</label> <a class="tippy-tooltip" id="tt-risk-mgnt-plan-facilities"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('rmps','Number of facilities',''); ?>
					<li><input type="checkbox" class="toggle watershed-hazards" id="streams"><label for="streams">Streams with impaired or threatened surface waters</label> <a class="tippy-tooltip" id="tt-streams-impared-threatened"><img src="assets/img/icon-tooltip-dark.png" /></a></li>
					<?php rangeSliderHistogram('streams','Number of streams',''); ?>
				</div>
			</ul>

			<div class="filter-menu-footer">
					<a href="javascript:void(0);" onclick="resetByCategory('container-map');" id="" class="btn-filters">Reset All</a>
					<a href="javascript:void(0);" id="" class="btn-filters btn-apply-filters">Apply</a>
			</div>
			

		</div>


		

		<div id="container-zoom-to-loc" style="display:none;">
			<a href="javascript:void(0);" id="tt-zoom-to-location"><img src="assets/img/icon-zoom-to-location.png"/></a>
		</div>
		
		<div id="container-ak-hi" class="hide-for-table">
			<a id="48-zoom" href="javascript:void(0);" title="Zoom to 48 states">48</a>
			<a id="ak-zoom" href="javascript:void(0);" title="Zoom to Alaska">AK</a>
			<a id="hi-zoom" href="javascript:void(0);" title="Zoom to Hawaii">HI</a>
		</div>

		<div id="mobile-btn-filters" class="hide-for-desktop show-for-mobile">
			<a href="javascript:void(0);" onclick="showThis('#container-menu-10');"></a>
		</div>
		<div id="mobile-btn-info" class="hide-for-desktop show-for-mobile">
			<a href="javascript:void(0);" onclick="showThis('#container-map-content-bottom');"></a>
		</div>

		<div id="container-map-content-bottom" class="hide-for-table">
			
			<div class="bwn-content-wrapper hide-for-table" style="display:none;">
				<p><strong>Boil water notices:</strong></p>
				<div class="bwn-content">
					<p id='tt-notices-or' class='tt-notices'>Continuous data collection started on Oct 2nd, 2025, and updates are completed quarterly. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://yourwater.oregon.gov/advisories.php?areasw=x&areap=x&popa=x&popv=x&open=x&lifted=x&begin=&end=&sort=start">Source link</a></p>
					<p id='tt-notices-wv' class='tt-notices'>Continuous data collection started on Oct 2nd, 2025, and updates are completed quarterly. Please note that a water system in this dataset may report multiple & potentially separate advisories on the same day. They are treated as distinct advisories, and therefore numbers may appear large. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://oehsportal.wvdhhr.org/boilwater">Source link</a></p>
					<p id='tt-notices-nm' class='tt-notices'>Continuous data collection started on Oct 2nd, 2025, and updates are completed quarterly. This is not a comprehensive record, as water system IDs are not always provided. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://www.env.nm.gov/drinking_water/boil-water-advisories/">Source link</a></p>
					<p id='tt-notices-oh' class='tt-notices'>The last update of this dataset occurred on July 30th, 2025. This dataset is no longer maintained by the state of Ohio, and is not a comprehensive record. Please refer to your water system for the most current information.<br /><br /><a target="_blank" href="https://geo.epa.ohio.gov/portal/apps/experiencebuilder/experience/?id=72cf2af9e2dd459aa5d758b54fb10c0c&page=Page-1&views=About">Source link</a></p>
					<p id='tt-notices-ri' class='tt-notices'>The last update of this dataset occurred on July 30th, 2025, and we are working on updating this dataset. Some records may be missing the date the advisory was issued because that information is not provided for recently lifted advisories. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://health.ri.gov/drinking-water-quality/information/public-water-emergency-information-consumers">Source link</a></p>
					<p id='tt-notices-wa' class='tt-notices'>Continuous data collection started on Sept 12th, 2025, and updates are completed quarterly. This is not a comprehensive record, as water system IDs are not always provided. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://doh.wa.gov/community-and-environment/drinking-water/active-alerts?county=All&combine=">Source link</a></p>
					<p id='tt-notices-mo' class='tt-notices'>Continuous data collection started on Sept 25th, 2025, and updates are completed quarterly. This is not a comprehensive record, as this dataset only contains advisories from long-term contaminant issues. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://data.mo.gov/Regulatory/DNR-WPP-Boil-Order-Report/j2a5-itxh/data_preview">Source link</a></p>
					<p id='tt-notices-me' class='tt-notices'>Continuous data collection started on Sept 12th, 2025, and updates are completed quarterly. This is not a comprehensive record, as water system IDs are not always provided. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://www.maine.gov/dhhs/mecdc/healthy-living/health-safety/drinking-water-safety/information-for-consumers/drinking-water-safety-alerts">Source link</a></p>
					<p id='tt-notices-ak' class='tt-notices'>Continuous data collection started on Sept 10th, 2025, and updates are completed quarterly. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://gis.data.alaska.gov/datasets/ADEC::boil-water-and-do-not-drink-notice-open/explore?location=56.210819%2C-157.551116%2C7.85&showTable=true">Source link</a></p>
					<p id='tt-notices-ar' class='tt-notices'>The last update of this dataset occurred on Feb 3rd, 2026. This is not a comprehensive record. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://health.arkansas.gov/wa_engTraining/boilwaterorder.aspx">Source link</a></p>
					<p id='tt-notices-fl' class='tt-notices'>Continuous data collection started on Oct 2nd, 2025, and updates are completed quarterly. This is not a comprehensive record - Florida only lists advisories declared during a natural disaster, such as a hurricane or tropical weather event. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://www.floridahealth.gov/environmental-health/drinking-water/boil-water-notices/index.html">Source link</a></p>
					<p id='tt-notices-ma' class='tt-notices'>The last update of this dataset occurred on Oct 30th, 2025 and we are working on updating this dataset. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://eeaonline.eea.state.ma.us/DEP/Boil_Order/">Source link</a></p>
					<p id='tt-notices-la' class='tt-notices'>The last update of this dataset was completed on July 9th, 2025. Due to data download limits, this dataset includes system-issued boil water notices from 2024-2025, and state-issued boil water advisories that were open from 2020-2025. This is not a comprehensive record. Please refer to the source link for the most current information.<br /><br /><a target="_blank" href="https://sdw.ldh.la.gov/">Source link</a></p>
					<p id='tt-notices-tx' class='tt-notices'>The last update of this dataset was completed on April 17th, 2024 through a Freedom of Information Act Request (FOIA). This is not a comprehensive record, and we are working to automatically update this dataset in the future using the data contained in the source link. Please refer to the source link for the most current information, as it is provided on the state SDWIS website.<br /><br /><a target="_blank" href="https://dww2.tceq.texas.gov/DWW/JSP/SearchDispatch?number=&name=&ActivityStatusCD=All&county=All&WaterSystemType=All&SourceWaterType=All&SampleType=null&begin_date=10%2F28%2F2023&end_date=10%2F28%2F2025&action=Search+For+Water+Systems">Source link</a></p>
				</div>
			</div>

			<div class="map-content-wrapper map-content-intro hide-for-table">
				<a href="javascript:void(0);" class="btn-close-map-info hide-for-desktop"></a>
				<div class="intro-content"> 
					<p><strong>How to use this tool:</strong></p>
					<p>Search or zoom into the map to see information about public drinking water systems in areas of interest. Use the filters to customize the display.</p>
				</div>
				<div class="sabs-stats" style="display:none;">
					<!--<h2>Service Area Boundaries (SABs) statistics:</h2>-->
					<ul class="stats-list">
						<li><strong>Systems count:</strong> <span class="sumstat stat-count">0</span> of <span class="sumstat stat-count-total"></span> <span class="sumstat geo-filter"></span></li>
						<li><strong>Customers served:</strong> <span class="sumstat stat-served">0</span></li>
						<li><strong>Area Median Income:</strong> ~$<span class="sumstat stat-ami">0</span></li>
						<li><strong>Violations:</strong> <span class="sumstat stat-open-viols">0</span> open health</li>
					</ul>
				</div>
			</div>
		</div>

		<div id="container-map-ui-bottom" class="container-map-ui hide-for-mobile">
			<ul>
				<li><a href="javascript:void(0);" onclick="showMap('map');" class="nv-item nav-map-toggle active"><img src="assets/img/icon-map-toggle-white.png" class="map-white"/><img src="assets/img/icon-map-toggle-dark.png" class="map-dark" style="display:none;"/> Map</a></li>
				<li><a href="javascript:void(0);" onclick="showTable('table');" class="nav-item nav-table"><img src="assets/img/icon-table-dark.png" class="table-dark" /><img src="assets/img/icon-table-white.png" class="table-white" style="display:none;"/>Table</a></li>
			</ul>
		</div>

		<div id="map"></div>

		<div class="clearfix"></div>
	</div>