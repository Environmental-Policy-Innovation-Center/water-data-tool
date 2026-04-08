<?php 
set_time_limit(0);
ini_set("memory_limit","512M");
include "dbFunctions.inc.php";
$db = 'acs';
$schema = 'epic_water_tool'; //staging data schema

if($_SERVER['SCRIPT_NAME'] == '/water-data-tool/wdt_mvt.php' && !$_SERVER['SERVER_NAME'] == 'localhost') {
	$schema = 'epic_water_tool_production';
}

$x = $_REQUEST["x"];
$y = $_REQUEST["y"];
$z = $_REQUEST["z"];

if($z <= 4)
	$simp = '.05';
elseif($z < 6)
	$simp = '.01';
elseif($z < 7)
	$simp = '.005';
elseif($z < 8)
	$simp = '.001';
elseif($z < 9)
	$simp = '.0005';
elseif($z < 10)
	$simp = '.0001';
elseif($z < 11)
	$simp = '.00005';
elseif($z < 12)
	$simp = '.00001';
else
	$simp = '0';

//check for cache
$cache = [];
$sql = "select layer from $schema.wdt_mvt where z=$z and x=$x and y=$y;";
$recs = @get_array_from_db($db,$sql,$host_prod4ro);
foreach($recs as $rec)
	array_push($cache, $rec['layer']);

$layer = 'places';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(ST_SimplifyPreserveTopology(cp.geom,$simp),3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
				, cp.geoid, cp.name||', '||cp.stusps name, array_to_json(array_agg(a.pwsid)) as place_pwsids 
				, st_extent(cp.geom) bbox
				from cartographic_places2022 cp 
				left outer join $schema.place_sabs_xtab a on cp.geoid = a.geoid and (frac_sab >= .5 or frac_place >=.5)
				where cp.geom && TileBBox($z,$x,$y,4326)
				group by cp.geoid, cp.name||', '||cp.stusps, cp.geom 
			) a";
	$rec = @exec_sql($db,$sql);	
}

$layer = 'counties';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(ST_SimplifyPreserveTopology(cc.geom,$simp),3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
				, cc.geoid, cc.namelsad||', '||cc.stusps name, array_to_json(array_agg(a.pwsid)) as county_pwsids 
				, st_extent(cc.geom) bbox
				from cartographic_counties2022 cc
				left outer join $schema.epa_sabs_points a on st_intersects(a.geom, cc.geom)
				where cc.geom && TileBBox($z,$x,$y,4326)
				group by cc.geoid, cc.namelsad||', '||cc.stusps, cc.geom 
			) a";
	$rec = @exec_sql($db,$sql);	
}

$layer = 'states';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(ST_SimplifyPreserveTopology(cs.geom,$simp),3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
				, cs.geoid, cs.stusps, cs.name, array_to_json(array_agg(a.pwsid)) as state_pwsids 
				, st_extent(cs.geom) bbox
				from cartographic_state2022 cs
				left outer join $schema.epa_sabs_points a on st_intersects(a.geom, cs.geom)
				where cs.geom && TileBBox($z,$x,$y,4326)
				group by cs.geoid, cs.stusps, cs.name, cs.geom 
			) a";
	$rec = @exec_sql($db,$sql);	
}


$layer = 'pws';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(ST_SimplifyPreserveTopology(a.geom,$simp),3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                ,a.pwsid, b.stusps
                from $schema.epa_sabs_geoms a
                join $schema.epa_sabs_points b on a.pwsid = b.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
			) a";
	$rec = @exec_sql($db,$sql);	
}

//need a point version of this layer to be sure all features are included at low zoom levels
//otherwise, when using map.querySourceFeatures, small polygons may not be included
$layer = 'pws_sabs';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps, c.counties
				, pws_name, primacy_agency, pop_cat_5, population_served_count::int, service_connections_count::int, service_area_type, symbology_field, detailed_facility_report, ewg_report_link, epic_area_mi2::float 
				from $schema.epa_sabs_points a
                join $schema.epa_sabs b on a.pwsid = b.pwsid
				left outer join $schema.pws_counties c on a.pwsid = c.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}


$layer = 'pws_cejst';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, round(a_int_identified_as_disadvantaged::float*100) a_int_identified_as_disadvantaged, pw_int_hh_percent_pre_1960s_housing_lead_paint_indicator::int, pw_int_pop_low_life_expectancy_percentile::float
                from $schema.epa_sabs_points a
                join $schema.cejst c on a.pwsid = c.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_ejscreen';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, a_int_dwater::float, pw_ext_pop_disability::float 
                from $schema.epa_sabs_points a
                join $schema.ejscreen d on a.pwsid = d.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_acs';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, total_pop::int, mhi::int, hh_inc_lowest_quintile::int, black_alone_per::float, asian_alone_per::float, white_alone_per::float, aian_alone_per::float, napi_alone_per::float, other_alone_per::float, mixed_alone_per::float, hisp_alone_per::float, ageunder_5_per::float, age_over_61_per::float, bachelors_per::float, laborforce_unemployed_per::float, water_rate_less_125_per::float, water_rate_between_125_249_per::float, water_rate_between_250_499_per::float, water_rate_between_500_749_per::float, water_rate_between_750_999_per::float, water_rate_over_1000_per::float, hh_below_pov_per::float, hh_rent_home_per::float, hh_own_home_per::float, poc_alone_per::float, pop_in_pov_per::float, no_health_insurance_per::float, epic_pop_density::float, most_common_rate_tidy 
				from $schema.epa_sabs_points a
                join $schema.epa_sabs_xwalk e on a.pwsid = e.pwsid 
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}


$layer = 'pws_cvi';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, pw_int_hh_redlining::float, pw_int_pop_life_expectancy::float, pw_int_pop_cancer::float, round(a_int_overall_cvi_score::float*100) a_int_overall_cvi_score 
                from $schema.epa_sabs_points a
                join $schema.cvi c on a.pwsid = c.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_viols';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, gw_sw_code, primary_source_code, first_reported_date, years_operating::int, owner_type, primacy_type, is_grant_eligible_ind, is_wholesaler_ind, is_school_or_daycare_ind, source_water_protection_code, phone_number, lead_and_copper_rule_healthbased_5yr::int, radionuclides_and_revised_rad_rule_healthbased_5yr::int, groundwater_rule_healthbased_5yr::int, surface_water_treatment_rules_healthbased_5yr::int, total_coliform_rules_healthbased_5yr::int, inorganic_chemicals_healthbased_5yr::int, stage_1_disinfectants_and_byproducts_rule_healthbased_5yr::int, stage_2_disinfectants_and_byproducts_rule_healthbased_5yr::int, synthetic_organic_chemicals_healthbased_5yr::int, volatile_organic_chemicals_healthbased_5yr::int, health_viols_5yr::int, paperwork_viols_5yr::int, total_viols_5yr::int, lead_and_copper_rule_healthbased_10yr::int, radionuclides_and_revised_rad_rule_healthbased_10yr::int, groundwater_rule_healthbased_10yr::int, surface_water_treatment_rules_healthbased_10yr::int, total_coliform_rules_healthbased_10yr::int, inorganic_chemicals_healthbased_10yr::int, stage_1_disinfectants_and_byproducts_rule_healthbased_10yr::int, stage_2_disinfectants_and_byproducts_rule_healthbased_10yr::int, synthetic_organic_chemicals_healthbased_10yr::int, volatile_organic_chemicals_healthbased_10yr::int, health_viols_10yr::int, paperwork_viols_10yr::int, total_viols_10yr::int, violations_all_years::int, open_health_viol 
                from $schema.epa_sabs_points a
                join $schema.sdwis_viols i on a.pwsid = i.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_svi';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
                , round(pw_int_pop_rpl_themes::float*100) pw_int_pop_rpl_themes	
                from $schema.epa_sabs_points a
                join $schema.svi j on a.pwsid = j.pwsid 
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_10yr';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, total_pop_pct_change_2011_2021::float, laborforce_unemployed_pct_change_2011_2021::float, mhi_pct_change_2011_2021::float, hh_inc_lowest_quintile_pct_change_2011_2021::float, hh_total_pct_change_2011_2021::float, hh_below_pov_pct_change_2011_2021::float, poc_alone_per_pct_change_2011_2021::float, pop_in_pov_per_pct_change_2011_2021::float, income_change_flag, population_change_flag, total_pop_pct_change_2011_2021_cap::float, mhi_pct_change_2011_2021_cap::float 
                from $schema.epa_sabs_points a
                join $schema.xwalk_pct_change_10yr k on a.pwsid = k.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}


$layer = 'pws_bwn';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, date_of_first_advisory, date_of_last_advisory, total_bwn::int, min_reporting_year_for_state, max_reporting_year_for_state, state, data_tool_tip, download_link, clean_date_range 
                from $schema.epa_sabs_points a
                join $schema.national_bwn_highlevel_summary f on a.pwsid = f.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_npdes';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
				ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
				, a.pwsid, a.stusps--, huc12
				, num_facilities::int, npdes_permits::int, total_permit_eff_viols::int, total_open_usts::int, total_facilities_w_rmps::int, streams_303d_list::int 
				from $schema.epa_sabs_points a
				join (
					select pwsid
					, sum(num_facilities::int) num_facilities
					, sum(npdes_permits::int) npdes_permits
					, sum(total_permit_eff_viols::int) total_permit_eff_viols
					, sum(total_open_usts::int) total_open_usts
					, sum(total_facilities_w_rmps::int) total_facilities_w_rmps
					, sum(streams_303d_list::int) streams_303d_list
					from $schema.pwsid_npdes_usts_rmps_imp
					group by pwsid
					order by pwsid
				) g on a.pwsid = g.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}

$layer = 'pws_funding';
if (!in_array($layer,$cache)) {

	$sql = "insert into $schema.wdt_mvt (layer, z,x,y,mvt)
			SELECT '$layer', $z, $x, $y, ST_AsMVT(a, '$layer', 4096, 'mvtgeom') as mvt
			from (
				select 
                ST_AsMVTGeom(st_transform(a.geom,3857),TileBBox($z,$x,$y,3857), 4096, 0, false) as mvtgeom
                , a.pwsid, a.stusps
				, times_funded::int, total_srf_assistance::float, median_srf_assistance::float, total_principal_forgiveness::float 
                from $schema.epa_sabs_points a
                join $schema.pwsid_funded_highlevel_summary h on a.pwsid = h.pwsid
				where a.geom && TileBBox($z,$x,$y,4326)
				order by stusps, a.pwsid
			) a";
				
	$rec = @exec_sql($db,$sql);	
}




$sql = "select mvt from $schema.wdt_mvt where z=$z and x=$x and y=$y;";
$recs = @get_array_from_db($db,$sql,$host_prod4ro);

header('Content-type: application/x-protobuf;');
$len = 0;
foreach($recs as $rec)
	$len = $len + strlen(pg_unescape_bytea($rec['mvt']));

header("Content-Length: ".$len."");
header('Cache-Control: max-age=600');

foreach($recs as $rec)
	echo pg_unescape_bytea($rec['mvt']); 
?>