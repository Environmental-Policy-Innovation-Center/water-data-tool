<div id="container-datasets" class="container-main-content hidden">
		<div class="container-section-inner">
			<div class="dataset-header">
				
				<div class="col-1">
					<h3>Datasets</h3>
					<p class="ds-no-filters">27 datasets available</p>
					<div class="container-fs-group filter-group filter-group-3 container-show-all" style="display:none;">
							<p>Showing <span class="filtered-sources-num"></span> of 27 datasets available</p>
							<button class="button btn-show-all">show all</button>
						</div>
					<p>This inventory of drinking water datasets includes information from various public data providers. Here, you can learn details about specific sources and considerations for use. Please visit the documentation for additional information.</p>
				</div>

				<div class="col-2">
					<div class="inner">
						<a href="https://docs.google.com/forms/d/e/1FAIpQLSc6H73GVlF-dlmJrjpRa1J-kgkbzGIHoys5Tcnn3DNzCZlt4Q/viewform?usp=dialog" target="_blank" class="btn-rounded btn-recommend-datasets">Recommend Datasets</a>
						<p>EPIC wants to know what other datasets should be included in the tool.</p>
						<div class="ds-ui">
							<a href="javascript:void(0);" onclick="showFilters('filter');" class="btn-ds-ui btn-rounded btn-ds-filter">Filter</a>
							<a href="javascript:void(0);" onclick="showSort('sort');" class="btn-ds-ui btn-rounded btn-ds-sort">Sort</a>
						</div>
					</div>
				</div>
				<div class="clearfix"></div>
				<div class="container-ds-filter filters" style="display:none;">
					<p><strong>Filter</strong></p>
					<div class="button-group filter-button-group">
						<div class="container-fs-group filter-group filter-group-1">
							<p><em>Data source:</em></p>
							<select class="filters-select" name="ds-dataSource" id="ds-dataSource" data-filter-group="ds-sel-source">
								<option id="ds-source-show-all" value="*" selected = "selected" onclick="clearSelectList();" >Show all</option>
								<option value=".AK-Department-of-Environmental-Conservation">AK Department of Environmental Conservation</option>
								<option value=".AR-Department-of-Health">AR Department of Health</option>
								<option value=".Center-for-Disease-Control">Center for Disease Control</option>
								<option value=".Environmental-Defense-Fund">Environmental Defense Fund</option>
								<option value=".Florida-Health">Florida Health</option>
								<option value=".Louisiana-Department-of-Health">Louisiana Department of Health</option>
								<option value=".Maine-Department-of-Health-and-Human-Services">Maine Department of Health and Human Services</option>
								<option value=".Massachusetts-Department-of-Environmental-Protection">Massachusetts Department of Environmental Protection</option>
								<option value=".New-Mexico-Environment-Department">New Mexico Environment Department</option>
								<option value=".Ohio-Environmental-Protection-Agency">Ohio Environmental Protection Agency</option>
								<option value=".opha">Oregon Public Health Authority</option>
								<option value=".Public-Environmental-Data-Partners">Public Environmental Data Partners</option>
								<option value=".Rhode-Island-Department-of-Health">Rhode Island Department of Health</option>
								<option value=".State-of-Missouri-Data-Portal">State of Missouri Data Portal</option>
								<option value=".TCEQ">Texas Commission on Environmental Quality (TCEQ)</option>
								<option value=".census">U.S. Census Bureau</option>
								<option value=".epa">U.S. Environmental Protection Agency (EPA)</option>
								<option value=".Washington-Department-of-Health">Washington Department of Health</option>
								<option value=".WV-Department-of-Health-and-Human-Services">WV Department of Health and Human Services</option>


							</select>
						</div>
						<div class="container-fs-group filter-group filter-group-2">
							<p><em>Update frequency:</em></p>
							<div class="option-set" data-filter-group="update-frequency">
								<button class="button btn-filter" data-filter-value=".annually">Annually</button>
								<button class="button btn-filter" data-filter-value=".quarterly">Quarterly</button>
								<button class="button btn-filter" data-filter-value=".static">Static</button>
							</div>
						</div>
						
						<div class="clearfix"></div>
					</div>
				</div>

				<div class="container-ds-sort" style="display:none;">
					<p><strong>Sort by:</strong></p>
					<div class="container-fs-group button-group sort-by-button-group">	
						<p><em>Last updated</em></p>
						<button class="button btn-sort" data-sort-by="date" data-sort-direction="desc">Newest</button>
						<button class="button btn-sort" data-sort-by="date" data-sort-direction="asc">Oldest</button>
						<a href="javascript:void(0);" class="button btn-reset-ds-sort" id="btn-reset-ds-sort" style="display:none;">reset order</a>
					</div>
					<!--<div class="container-fs-group filter-group filter-group-3 container-show-all" style="display:none;">
						<p><em>showing <span class="filtered-sources-num"></span> of 27 data sources</em></p>
						<button class="button btn-show-all">show all</button>
					</div>-->
					<div class="clearfix"></div>
				</div>
				

			</div>


			<div class="grid">
				<!-- 1. Community Water System Service Area Boundaries -->
				<div class="grid-item xgrid-sizer epa annually">
					<div class="dataset-inner default dataset-inner-1">
						<div class="ds-content ds-content-1">

						<h2>Community Water System Service Area Boundaries</h2>
						<p class="ds-description">This dataset contains geographic service area boundaries for U.S. Community Water Systems in the U.S. and select territories (Puerto Rico, Guam, Northern Mariana Islands). As of October 2025, over half of the  approximately 50,000 water system boundaries come from authoritative data sources.</p>
						<div class="ds-callout">
							<p class="ds-source">Data source: <a href="https://www.epa.gov/ground-water-and-drinking-water/community-water-system-service-area-boundaries" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
							<p>Last updated: <span class="date" data-time="2026-1-27">1/27/2026</span></p>
							<p class="ds-update-frequecy">Update frequency: Annually</p>
						</div>
						
						<p><strong>Things you should know</strong></p>
						<ul>
							<li>For many systems, this dataset uses modeled boundaries that approximate, not confirm, the true service area of a water system</li>
							<li>Modeled areas are derived from population and infrastructure inference methods</li>
							<li>Overlapping boundaries may occur between neighboring systems</li>
							<li>Some boundaries map to multiple water system IDs</li>
							<li>Releases generally occur annually but have come more frequently</li>
						</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('1');" class="expand ds-expand-1" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 2. Safe Drinking Water Information System (SDWIS) -->
				<div class="grid-item grid-sizer epa quarterly">
					<div class="dataset-inner default dataset-inner-2">
						<div class="ds-content ds-content-2">
							<h2>Safe Drinking Water Information System</h2>
							<p class="ds-description">Water system violation, enforcement, and system information submitted by states and utilities.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.epa.gov/ground-water-and-drinking-water/safe-drinking-water-information-system-sdwis-federal-reporting" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-20">2/20/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quartely</p>
							</div>
							<p><strong>Things you should know</strong></p>
								<ul>
									<li>Several variables in SDWIS reflect regulatory reporting structures rather than underlying infrastructure conditions</li>
									<li>Violations are known to be underreported and vary with enforcement practices</li>
									<li>In some instances, system age represents the first regulatory record rather than the construction date</li>
									<li>The maximum age of any system in this dataset is 45 years due to data reporting beginning in 1979</li>
								</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('2');" class="expand ds-expand-2" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 3. U.S. Census -->
				<div class="grid-item census annually">
					<div class="dataset-inner default dataset-inner-3">
						<div class="ds-content ds-content-3">
							<h2>U.S. Census</h2>
							<p class="ds-description">The dataset combines 2021 American Community Survey (ACS) demographic and socioeconomic estimates with EPA drinking water system service area boundaries. EPIC allocated ACS census variables to system service areas using spatial crosswalk methods based on EPA boundary files. The result is a set of estimated community characteristics for each drinking water system, not direct measurements of the populations served.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.census.gov/programs-surveys/acs.html" target="_blank">U.S. Census Bureau</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-2">2/2/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Anually</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Values are statistical estimates and include uncertainty</li>
								<li>Population characteristics are modeled using an EPA crosswalk rather than statistics observed at the system level</li>
								<li>Income fields are interpolated estimates derived between known values</li>
								<li>Results represent characteristics of the estimated service population, not confirmed customer records</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('3');" class="expand ds-expand-3" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 4. National Pollutant Discharge Elimination System (NPDES) Permits  -->
				<div class="grid-item epa quarterly">
					<div class="dataset-inner default dataset-inner-4">
						<div class="ds-content ds-content-4">
							<h2>National Pollutant Discharge Elimination System (NPDES) Permits</h2>
							<p class="ds-description">This dataset includes permitted discharge outfalls from the EPA National Pollutant Discharge Elimination System (NPDES). NPDES documents point-source pollutant discharges to surface waters under the Clean Water Act. EPIC links permitted discharge locations to nearby drinking water systems to identify potential upstream pollution pressures. The dataset reflects regulated discharge activity, not measured drinking water contamination or human exposure.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.epa.gov/npdes" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quartely</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>This dataset indicates the presence of regulated discharges, not contamination at a drinking water intake</li>
								<li>Water system treatment processes may remove pollutants</li>
								<li>A single permitted facility may appear in multiple watersheds due to multiple outfalls</li>
								<li>Violation records reflect regulatory compliance status, not magnitude of pollutant transport</li>
								<li>EPIC is working to pinpoint specific features in violation for future tool updates</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('4');" class="expand ds-expand-4" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 5. 303(d) Impaired Waterways -->
				<div class="grid-item epa quarterly">
					<div class="dataset-inner default dataset-inner-5">
						<div class="ds-content ds-content-5">
							<h2>303(d) Impaired Waterways</h2>
							<p class="ds-description">This dataset contains impaired surface waters reported by states to EPA under Clean Water Act Sections 303(d) and 305(b) through the Integrated Report. States identify assessment units that do not meet one or more designated water quality uses and require corrective action. EPIC links impaired waters to nearby drinking water systems as a potential indicator of source water characteristics, not treated drinking water quality.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.epa.gov/waterdata/attains" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quartely</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>This dataset represents regulatory impairment status, not contaminant concentrations at drinking water intakes</li>
								<li>Listing criteria and assessment coverage vary significantly by state</li>
								<li>Drinking water treatment may remove listed pollutants</li>
								<li>Not all waters are assessed each cycle</li>
								<li>A listed water body does not imply customer exposure or Safe Drinking Water Act violations</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('5');" class="expand ds-expand-5" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 6. Oregon Drinking Water Advisories -->
				<div class="grid-item opha quarterly">
					<div class="dataset-inner default dataset-inner-6">
						<div class="ds-content ds-content-6">
							<h2>Oregon Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Oregon. Provided by the Oregon Public Health Authority.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://yourwater.oregon.gov/advisories.php?areasw=x&areap=x&popa=x&popv=x&open=x&lifted=x&begin=&end=&sort=start" target="_blank">Oregon Public Health Authority</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quartely</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('6');" class="expand ds-expand-6" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 7. Climate and Economic Justice Screening Tool -->
				<div class="grid-item Public-Environmental-Data-Partners quarterly">
					<div class="dataset-inner default dataset-inner-7">
						<div class="ds-content ds-content-7">
							<h2>Climate and Economic Justice Screening Tool</h2>
							<p class="ds-description">Built for Biden&rsquo;s Justice40 initiative, the CEJST uses datasets that are indicators of burdens in eight categories: climate change, energy, health, housing, legacy pollution, transportation, water and wastewater, and workforce development.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://public-environmental-data-partners.github.io/j40-cejst-2/en/#3/33.47/-97.5" target="_blank">Public Environmental Data Partners</a></p>
								<p>Last updated: <span class="date" data-time="2026-1-29">1/29/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data were interpolated using a mix of population, household, and areal interpolation. As a result, some variables for some water systems could not be calculated.</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('7');" class="expand ds-expand-7" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 8. Climate Vulnerability Index -->
				<div class="grid-item Environmental-Defense-Fund quarterly">
					<div class="dataset-inner default dataset-inner-8">
						<div class="ds-content ds-content-8">
							<h2>Climate Vulnerability Index</h2>
							<p class="ds-description">The U.S. Climate Vulnerability Index helps you see which communities face the greatest challenges from the impacts of a changing climate.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://climatevulnerabilityindex.org/" target="_blank">Environmental Defense Fund</a></p>
								<p>Last updated: <span class="date" data-time="2026-1-29">1/29/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data were interpolated using a mix of population, household, and areal interpolation. As a result, some variables for some water systems could not be calculated.</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('8');" class="expand ds-expand-8" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 9. Social Vulnerability Index -->
				<div class="grid-item Center-for-Disease-Control quarterly">
					<div class="dataset-inner default dataset-inner-9">
						<div class="ds-content ds-content-9">
							<h2>Social Vulnerability Index</h2>
							<p class="ds-description">This SVI tool is a place-based index, database, and mapping application designed to identify and quantify communities experiencing social vulnerability. It uses 16 U.S. Census variables from the 5-year American Community Survey (ACS) to identify communities that may need support before, during, or after disasters.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.atsdr.cdc.gov/place-health/php/svi/index.html" target="_blank">Center for Disease Control</a></p>
								<p>Last updated: <span class="date" data-time="2026-1-29">1/29/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data were interpolated using a mix of population, household, and areal interpolation. As a result, some variables for some water systems could not be calculated.</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('9');" class="expand ds-expand-9" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 10. Drinking Water State Revolving Funds Awards -->
				<div class="grid-item epa annually">
					<div class="dataset-inner default dataset-inner-10">
						<div class="ds-content ds-content-10">
							<h2>Drinking Water State Revolving Funds Awards</h2>
							<p class="ds-description">These data represent funding awards for drinking water investment and improvement from the Drinking Water State Revolving Fund. Disseminated by states, awards are given largely in the form of loans to communities based on federal allotments and state-based programs.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://sdwis.epa.gov/ords/sfdw_pub/r/sfdw/owsrf_public/assistance-agreement-report-filters" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-20">02/20/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Annually</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>This dataset contains downloaded data from EPA&rsquo;s State Revolving Fund Public Portal for federal fiscal years 2021-2025</li>
								<li>Principle forgiveness represents "Additional Subsidy Amount", which includes direct principle forgiveness, as well as negative interest rates and grants</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('10');" class="expand ds-expand-10" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 11. Water System Watersheds for Well & Intake Locations -->
				<div class="grid-item epa static">
					<div class="dataset-inner default dataset-inner-11">
						<div class="ds-content ds-content-11">
							<h2>Water System Watersheds for Well & Intake Locations</h2>
							<p class="ds-description">These data show the relationship between a water system, and its source watershed. While data on specific intake locations is private given security concerns, this match between a water system and a watershed is shared by the EPA.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://mywaterway.epa.gov/" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2024-10-7">10/07/2024</span></p>
								<p class="ds-update-frequecy">Update frequency: Static</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>This data is static and reflects a snapshot of the information contained in EPA's How's My Waterway</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('11');" class="expand ds-expand-11" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 12. Facilities with Risk Management Plans -->
				<div class="grid-item epa quarterly">
					<div class="dataset-inner default dataset-inner-12">
						<div class="ds-content ds-content-12">
							<h2>Facilities with Risk Management Plans</h2>
							<p class="ds-description">These data contains location and facility identification information from EPA's Facility Registry Service (FRS) for the subset of facilities that link to the Risk Management Plan (RMP) System. The Risk Management Plan (RMP) database stores the risk management plans reported by companies that handle, manufacture, use, or store certain flammable or toxic substances.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://catalog.data.gov/dataset/epa-facility-registry-service-frs-rmp6" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>This dataset is aimed to communicate potential hazards, rather than an actual risk to drinking water</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('12');" class="expand ds-expand-12" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 13. Underground Storage Tanks -->
				<div class="grid-item epa static">
					<div class="dataset-inner default dataset-inner-13">
						<div class="ds-content ds-content-13">
							<h2>Underground Storage Tanks</h2>
							<p class="ds-description">This data provides the attributes and locations of active and closed Underground Storage Tanks (USTs), UST facilities, and UST releases in states as of 2018-2019, US territories as of 2020-2021, and Tribal lands as of 2025.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.epa.gov/ust/ust-finder" target="_blank">U.S. Environmental Protection Agency (EPA)</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Static</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Please note this dataset is static, and only contains a snapshot of information from 2018 - 2019.</li>
								<li>Because the exact location of underground storage tanks are not provided, it is assumed that facilities with underground storage tanks are close in proximity to the storage tanks they manage.</li>
								<li>Both "open" and "temporarily out of service" tanks are included in this calculation to be consistent with EPA standards</li>
								<li>This dataset is aimed to communicate potential hazards, rather than an actual risk to drinking water"</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('13');" class="expand ds-expand-13" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 14. Percent Change in U.S. Census Variables -->
				<div class="grid-item census annually">
					<div class="dataset-inner default dataset-inner-14">
						<div class="ds-content ds-content-14">
							<h2>Percent Change in U.S. Census Variables</h2>
							<p class="ds-description">This dataset contains the 10-year percent change (2011 ACS vs 2021 ACS) in ~70 differerent census variables for EPA's Service Area Boundaries. EPIC used the EPA ORD crosswalk and NHGIS crosswalk files to estimate counts for 2011 data, and household-weighted interpolation for income variables.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.census.gov/programs-surveys/acs.html" target="_blank">U.S. Census Bureau</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Annually</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Not all census variables were available for the 2011 ACS 5-year estimate</li>
								<li>Water systems with duplicated boundaries could not be calculated (approximately 7 water systems)</li>
								<li>For the purposes of the application, percent change is capped at 200%</li>
								<li>Income variables were adjusted for inflation using methods identical to the BLS CPI Inflation calculator</li>
								<li>Calculated from 5-year ACS estimates from 2011 and 2021. See Github methods & documentation for more details</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('14');" class="expand ds-expand-14" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 15. West Virginia Drinking Water Advisories -->
				<div class="grid-item WV-Department-of-Health-and-Human-Services quarterly">
					<div class="dataset-inner default dataset-inner-15">
						<div class="ds-content ds-content-15">
							<h2>West Virginia Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in West Virginia. Provided by the West Virginia Department of Health and Human Resources.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://oehsportal.wvdhhr.org/boilwater" target="_blank">WV Department of Health and Human Services</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('15');" class="expand ds-expand-15" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 16. New Mexico Drinking Water Advisories -->
				<div class="grid-item New-Mexico-Environment-Department quarterly">
					<div class="dataset-inner default dataset-inner-16">
						<div class="ds-content ds-content-16">
							<h2>New Mexico Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in New Mexico. Provided by the New Mexico Environment Department.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.env.nm.gov/drinking_water/boil-water-advisories/" target="_blank">New Mexico Environment Department</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>Please note that if an advisory listed multiple water system IDs, the record was duplicated for each water system</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('16');" class="expand ds-expand-16" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 17. Ohio Drinking Water Advisories -->
				<div class="grid-item Ohio-Environmental-Protection-Agency static">
					<div class="dataset-inner default dataset-inner-17">
						<div class="ds-content ds-content-17">
							<h2>Ohio Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Ohio. Previously provided by the Ohio Environmental Protection Agency.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://geo.epa.ohio.gov/portal/apps/experiencebuilder/experience/?id=72cf2af9e2dd459aa5d758b54fb10c0c&page=Page-1&views=About" target="_blank">Ohio Environmental Protection Agency</a></p>
								<p>Last updated: <span class="date" data-time="2025-7-30">7/30/2025</span></p>
								<p class="ds-update-frequecy">Update frequency: Static</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>This dataset is no longer being maintained by the state of Ohio</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('17');" class="expand ds-expand-17" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 18. Rhode Island Drinking Water Advisories -->
				<div class="grid-item Rhode-Island-Department-of-Health static">
					<div class="dataset-inner default dataset-inner-18">
						<div class="ds-content ds-content-18">
							<h2>Rhode Island Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Rhode Island. Provided by the Rhode Island Department of Health.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://health.ri.gov/drinking-water-quality/information/public-water-emergency-information-consumers" target="_blank">Rhode Island Department of Health</a></p>
								<p>Last updated: <span class="date" data-time="2025-7-30">7/30/2025</span></p>
								<p class="ds-update-frequecy">Update frequency: Static</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>The last update of this dataset occurred on July 30th, 2025. Our team is working on updating this dataset</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('18');" class="expand ds-expand-18" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 19. Washington Drinking Water Advisories -->
				<div class="grid-item Washington-Department-of-Health quarterly">
					<div class="dataset-inner default dataset-inner-19">
						<div class="ds-content ds-content-19">
							<h2>Washington Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Washington. Provided by the Washington Department of Health.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://doh.wa.gov/community-and-environment/drinking-water/active-alerts?county=All&combine=" target="_blank">Washington Department of Health</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-4">2/4/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('19');" class="expand ds-expand-19" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 20. Missouri Drinking Water Advisories -->
				<div class="grid-item State-of-Missouri-Data-Portal quarterly">
					<div class="dataset-inner default dataset-inner-20">
						<div class="ds-content ds-content-20">
							<h2>Missouri Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available advisories for systems with long-term contaminant issues in Missouri. Provided by the State of Missouri Data Portal.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://data.mo.gov/Regulatory/DNR-WPP-Boil-Order-Report/j2a5-itxh/data_preview" target="_blank">State of Missouri Data Portal</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>This is not a comprehensive record, as this dataset only contains advisories from long-term contaminant issues</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('20');" class="expand ds-expand-20" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 21. Maine Drinking Water Advisories -->
				<div class="grid-item Maine-Department-of-Health-and-Human-Services quarterly">
					<div class="dataset-inner default dataset-inner-21">
						<div class="ds-content ds-content-21">
							<h2>Maine Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Maine. Provided by the Maine Department of Health and Human Services.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.maine.gov/dhhs/mecdc/healthy-living/health-safety/drinking-water-safety/information-for-consumers/drinking-water-safety-alerts" target="_blank">Maine Department of Health and Human Services</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-4">2/4/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('21');" class="expand ds-expand-21" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 22. Alaska Drinking Water Advisories -->
				<div class="grid-item AK-Department-of-Environmental-Conservation quarterly">
					<div class="dataset-inner default dataset-inner-22">
						<div class="ds-content ds-content-22">
							<h2>Alaska Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Alaska. Provided by Alaska's Department of Environmental Conservation.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://gis.data.alaska.gov/datasets/ADEC::boil-water-and-do-not-drink-notice-open/explore?location=56.210819%2C-157.551116%2C7.85&showTable=true" target="_blank">AK Department of Environmental Conservation</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-4">2/4/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('22');" class="expand ds-expand-22" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 23. Arkansas Drinking Water Advisories -->
				<div class="grid-item AR-Department-of-Health quarterly">
					<div class="dataset-inner default dataset-inner-23">
						<div class="ds-content ds-content-23">
							<h2>Arkansas Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Arkansas. Provided by the Arkansas Department of Health.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://health.arkansas.gov/wa_engTraining/boilwaterorder.aspx" target="_blank">AR Department of Health</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>Please note there was a gap in our data collection from May 21st, 2025 to Feb 3rd, 2026</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('23');" class="expand ds-expand-23" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 24. Florida Drinking Water Advisories -->
				<div class="grid-item Florida-Health quarterly">
					<div class="dataset-inner default dataset-inner-24">
						<div class="ds-content ds-content-24">
							<h2>Florida Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Florida during extreme weather events. Provided by Florida Health.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.floridahealth.gov/environmental-health/drinking-water/boil-water-notices/index.html" target="_blank">Florida Health</a></p>
								<p>Last updated: <span class="date" data-time="2026-2-3">2/3/2026</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>This is not a comprehensive record - Florida only lists advisories declared during a natural disaster, such as a hurricane or tropical weather event</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('24');" class="expand ds-expand-24" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 25. Massachusetts Drinking Water Advisories -->
				<div class="grid-item Massachusetts-Department-of-Environmental-Protection quarterly">
					<div class="dataset-inner default dataset-inner-25">
						<div class="ds-content ds-content-25">
							<h2>Massachusetts Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Massachusetts. Provided by Massachusetts Department of Environmental Protection.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://eeaonline.eea.state.ma.us/DEP/Boil_Order/" target="_blank">Massachusetts Department of Environmental Protection</a></p>
								<p>Last updated: <span class="date" data-time="2025-10-30">10/30/2025</span></p>
								<p class="ds-update-frequecy">Update frequency: Quarterly</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('25');" class="expand ds-expand-25" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 26. Louisiana Drinking Water Advisories -->
				<div class="grid-item Louisiana-Department-of-Health static">
					<div class="dataset-inner default dataset-inner-26">
						<div class="ds-content ds-content-26">
							<h2>Louisiana Drinking Water Advisories</h2>
							<p class="ds-description">Publicly available drinking water advisories for water systems located in Louisiana. Provided by Louisiana Department of Health. Last update was July 9th 2025.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://sdw.ldh.la.gov/" target="_blank">Louisiana Department of Health</a></p>
								<p>Last updated: <span class="date" data-time="2025-7-9">7/9/2025</span></p>
								<p class="ds-update-frequecy">Update frequency: Static</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>Due to data download limits, this dataset includes system-issued boil water notices from 2024-2025, and state-issued boil water advisories from 2015-2025</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('26');" class="expand ds-expand-26" style="display:none;">show more</a>
					</div>
				</div>

				<!-- 27. Texas Drinking Water Advisories -->
				<div class="grid-item TCEQ static">
					<div class="dataset-inner default dataset-inner-27">
						<div class="ds-content ds-content-27">
							<h2>Texas Drinking Water Advisories</h2>
							<p class="ds-description">FOIA&rsquo;d drinking water advisories for water systems located in Texas. Provided by the Texas Commission on Environmental Quality.</p>
							<div class="ds-callout">
								<p class="ds-source">Data source: <a href="https://www.tceq.texas.gov/" target="_blank">Texas Commission on Environmental Quality (TCEQ)</a></p>
								<p>Last updated: <span class="date" data-time="2024-4-17">4/17/2024</span></p>
								<p class="ds-update-frequecy">Update frequency: Static</p>
							</div>
							<p><strong>Things you should know</strong></p>
							<ul>
								<li>Data represents historical advisory events, not current drinking water conditions</li>
								<li>The official state site should be used for real-time public health information</li>
								<li>Advisories include precautionary notices such as boil water alerts, service interruptions, and planned maintenance events, not just contamination incidents</li>
								<li>Please note this dataset only contains records from 2018 - 2024 from a FOIA request. Our team is working on updating this dataset</li>
								<li>It is assumed that a system would have maximum one advisory on a given day, and advisories that have been edited by the state are considered a distinct advisory</li>
							</ul>
						</div>
						<a href="javascript:void(0);" onclick="ds_expand('27');" class="expand ds-expand-27" style="display:none;">show more</a>
					</div>
				</div>

			</div>
			<div id="no-results" style="display:none;">
					<p>No results for the selected filters</p>
			</div>
		</div>

	</div>