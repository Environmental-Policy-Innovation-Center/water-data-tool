<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1); // for errors during PHP startup

set_time_limit(0);
ini_set("memory_limit","512M");
include "dbFunctions.inc.php";
$db = 'acs';
$schema = 'epic_water_tool'; //staging data schema

$pwsids = "'".str_replace(",","','",$_REQUEST['pws_ids'])."'";

$sql = "
select row_to_json(fc)
FROM ( 
	SELECT 'FeatureCollection' As type, array_to_json(array_agg(f)) As features
	FROM (
			SELECT 'Feature' As type
			, ST_AsGeoJSON(a.geom)::json As geometry
			, row_to_json((
				SELECT l FROM (
                    select 
                    pws_name
                    ,pwsid
                    ,stusps				
                    ,gw_sw_code
                    ,source_water_protection_code
                    ,owner_type
                    ,primacy_type
                    ,is_wholesaler_ind
                    ,is_school_or_daycare_ind
                    ,symbology_field
                    ,epic_area_mi2
                    ,open_health_viol
                    ,health_viols_5yr																					
                    ,groundwater_rule_healthbased_5yr																					
                    ,surface_water_treatment_rules_healthbased_5yr																					
                    ,lead_and_copper_rule_healthbased_5yr																					
                    ,radionuclides_and_revised_rad_rule_healthbased_5yr																					
                    ,inorganic_chemicals_healthbased_5yr																					
                    ,synthetic_organic_chemicals_healthbased_5yr																					
                    ,volatile_organic_chemicals_healthbased_5yr																					
                    ,total_coliform_rules_healthbased_5yr																					
                    ,stage_1_disinfectants_and_byproducts_rule_healthbased_5yr																					
                    ,stage_2_disinfectants_and_byproducts_rule_healthbased_5yr																					
                    ,health_viols_10yr																					
                    ,groundwater_rule_healthbased_10yr																					
                    ,surface_water_treatment_rules_healthbased_10yr																					
                    ,lead_and_copper_rule_healthbased_10yr																					
                    ,radionuclides_and_revised_rad_rule_healthbased_10yr																					
                    ,inorganic_chemicals_healthbased_10yr																					
                    ,synthetic_organic_chemicals_healthbased_10yr																					
                    ,volatile_organic_chemicals_healthbased_10yr																					
                    ,total_coliform_rules_healthbased_10yr																					
                    ,stage_1_disinfectants_and_byproducts_rule_healthbased_10yr																					
                    ,stage_2_disinfectants_and_byproducts_rule_healthbased_10yr																					
                    ,paperwork_viols_5yr																					
                    ,paperwork_viols_10yr																					
                    ,total_bwn
                    ,total_pop
                    ,epic_pop_density
                    ,total_pop_pct_change_2011_2021
                    ,mhi_pct_change_2011_2021
                    ,hh_below_pov_per
                    ,laborforce_unemployed_per
                    ,mhi
                    ,bachelors_per
                    ,ageunder_5_per
                    ,age_over_61_per
                    ,poc_alone_per
                    ,white_alone_per
                    ,black_alone_per
                    ,aian_alone_per
                    ,napi_alone_per
                    ,asian_alone_per
                    ,hisp_alone_per
                    ,other_alone_per
                    ,mixed_alone_per
                    ,a_int_identified_as_disadvantaged
                    ,pw_int_pop_rpl_themes
                    ,a_int_overall_cvi_score
                    ,most_common_rate_tidy
                    ,times_funded
                    ,total_srf_assistance
                    ,total_principal_forgiveness
                    ,num_facilities
                    ,total_permit_eff_viols
                    ,total_open_usts
                    ,total_facilities_w_rmps
                    ,streams_303d_list
			    ) As l
			)) As properties
		FROM (
                select 
                a.pwsid, b.stusps, a.geom
				, pws_name, primacy_agency, pop_cat_5, population_served_count::int, service_connections_count::int, service_area_type, symbology_field, detailed_facility_report, ewg_report_link, epic_area_mi2::float 
				, round(a_int_identified_as_disadvantaged::float*100) a_int_identified_as_disadvantaged, pw_int_hh_percent_pre_1960s_housing_lead_paint_indicator::int, pw_int_pop_low_life_expectancy_percentile::float
				, a_int_dwater::float, pw_ext_pop_disability::float 
				, total_pop::int, mhi::int, hh_inc_lowest_quintile::int, black_alone_per::float, asian_alone_per::float, white_alone_per::float, aian_alone_per::float, napi_alone_per::float, other_alone_per::float, mixed_alone_per::float, hisp_alone_per::float, ageunder_5_per::float, age_over_61_per::float, bachelors_per::float, laborforce_unemployed_per::float, water_rate_less_125_per::float, water_rate_between_125_249_per::float, water_rate_between_250_499_per::float, water_rate_between_500_749_per::float, water_rate_between_750_999_per::float, water_rate_over_1000_per::float, hh_below_pov_per::float, hh_rent_home_per::float, hh_own_home_per::float, poc_alone_per::float, pop_in_pov_per::float, no_health_insurance_per::float, epic_pop_density::float, most_common_rate_tidy 
				, pw_int_hh_redlining::float, pw_int_pop_life_expectancy::float, pw_int_pop_cancer::float, round(a_int_overall_cvi_score::float*100) a_int_overall_cvi_score 
				, gw_sw_code, primary_source_code, first_reported_date, years_operating::int, owner_type, primacy_type, is_grant_eligible_ind, is_wholesaler_ind, is_school_or_daycare_ind, source_water_protection_code, phone_number, lead_and_copper_rule_healthbased_5yr::int, radionuclides_and_revised_rad_rule_healthbased_5yr::int, groundwater_rule_healthbased_5yr::int, surface_water_treatment_rules_healthbased_5yr::int, total_coliform_rules_healthbased_5yr::int, inorganic_chemicals_healthbased_5yr::int, stage_1_disinfectants_and_byproducts_rule_healthbased_5yr::int, stage_2_disinfectants_and_byproducts_rule_healthbased_5yr::int, synthetic_organic_chemicals_healthbased_5yr::int, volatile_organic_chemicals_healthbased_5yr::int, health_viols_5yr::int, paperwork_viols_5yr::int, health_viols_5yr::int, lead_and_copper_rule_healthbased_10yr::int, radionuclides_and_revised_rad_rule_healthbased_10yr::int, groundwater_rule_healthbased_10yr::int, surface_water_treatment_rules_healthbased_10yr::int, total_coliform_rules_healthbased_10yr::int, inorganic_chemicals_healthbased_10yr::int, stage_1_disinfectants_and_byproducts_rule_healthbased_10yr::int, stage_2_disinfectants_and_byproducts_rule_healthbased_10yr::int, synthetic_organic_chemicals_healthbased_10yr::int, volatile_organic_chemicals_healthbased_10yr::int, health_viols_10yr::int, paperwork_viols_10yr::int, health_viols_10yr::int, violations_all_years::int, open_health_viol 
                , round(pw_int_pop_rpl_themes::float*100) pw_int_pop_rpl_themes	
				, total_pop_pct_change_2011_2021::float, laborforce_unemployed_pct_change_2011_2021::float, mhi_pct_change_2011_2021::float, hh_inc_lowest_quintile_pct_change_2011_2021::float, hh_total_pct_change_2011_2021::float, hh_below_pov_pct_change_2011_2021::float, poc_alone_per_pct_change_2011_2021::float, pop_in_pov_per_pct_change_2011_2021::float, income_change_flag, population_change_flag 
				, date_of_first_advisory, date_of_last_advisory, total_bwn::int, min_reporting_year_for_state, max_reporting_year_for_state, state, data_tool_tip, download_link, clean_date_range 
				, num_facilities::int, npdes_permits::int, total_permit_eff_viols::int, total_open_usts::int, total_facilities_w_rmps::int, streams_303d_list::int 
				, times_funded::int, total_srf_assistance::float, median_srf_assistance::float, total_principal_forgiveness::float 
                from $schema.epa_sabs_geoms a
                join $schema.epa_sabs_points b on a.pwsid = b.pwsid
                left outer join $schema.cejst c on a.pwsid = c.pwsid
                left outer join $schema.ejscreen d on a.pwsid = d.pwsid
                left outer join $schema.epa_sabs_xwalk e on a.pwsid = e.pwsid 
                left outer join $schema.national_bwn_highlevel_summary f on a.pwsid = f.pwsid
				left outer join (
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
                left outer join $schema.pwsid_funded_highlevel_summary h on a.pwsid = h.pwsid
                left outer join $schema.sdwis_viols i on a.pwsid = i.pwsid
                left outer join $schema.svi j on a.pwsid = j.pwsid 
                left outer join $schema.xwalk_pct_change_10yr k on a.pwsid = k.pwsid
                left outer join $schema.cvi m on a.pwsid = m.pwsid
                left outer join $schema.epa_sabs n on a.pwsid = n.pwsid
                where a.pwsid in ($pwsids)
		    ) As a
	    ) As f 
    )  As fc;
 ";

//echo $sql; die;

$rs = @get_value_from_db($db,$sql,$host_prod4ro);	
if ($rs <> "") {
	header('Content-Type: application/json');
    //$json = $rs;
    //echo $json;
    header('Content-Encoding: gzip');
	$gzjson = gzencode($rs);
	echo $gzjson;
}



?>