/* 
 * 
 * 
 * Data migration to Production 
 * 
 * 
 * */

--check file_import_log for last updates
select 
substring(file_url, 
	(length(file_url) - position(reverse('/') IN reverse(file_url)) + 2),
	(length(file_url) - position(reverse('.') IN reverse(file_url)) - (length(file_url) - position(reverse('/') IN reverse(file_url)) + 1) )
) 
, '  --'||file_url
from epic_water_tool.file_import_tracker 
where last_import_date >= '2026-02-20 14:00:00.000'
order by epic_water_tool.file_import_tracker.last_import_date desc

--check for new or changed column names

select a.table_name, a.column_name 
from (
select table_name, column_name
from information_schema.columns 
where table_schema = 'epic_water_tool'
and table_name in (select table_name from information_schema.columns where table_schema = 'epic_water_tool' and column_name = 'pwsid')
and table_name not like '%2025%'
and table_name not like '%2026%'
order by table_name, ordinal_position
) a 
left outer join (
select table_name, column_name
from information_schema.columns 
where table_schema = 'epic_water_tool_production'
and table_name in (select table_name from information_schema.columns where table_schema = 'epic_water_tool_production' and column_name = 'pwsid')
and table_name not like '%2025%'
and table_name not like '%2026%'
order by table_name, ordinal_position
) b on a.table_name = b.table_name and a.column_name = b.column_name 
where b.column_name is null

pws_counties	counties
pwsid_funded_highlevel_summary	times_funded
pwsid_funded_highlevel_summary	total_srf_assistance
pwsid_funded_highlevel_summary	median_srf_assistance
pwsid_funded_highlevel_summary	total_principal_forgiveness
xwalk_pct_change_10yr	total_pop_pct_change_2011_2021_cap
xwalk_pct_change_10yr	mhi_pct_change_2011_2021_cap

--check the reverse for renamed columns original name
select a.table_name, a.column_name 
from (
select table_name, column_name
from information_schema.columns 
where table_schema = 'epic_water_tool_production'
and table_name in (select table_name from information_schema.columns where table_schema = 'epic_water_tool_production' and column_name = 'pwsid')
and table_name not like '%2025%'
and table_name not like '%2026%'
order by table_name, ordinal_position
) a 
left outer join (
select table_name, column_name
from information_schema.columns 
where table_schema = 'epic_water_tool'
and table_name in (select table_name from information_schema.columns where table_schema = 'epic_water_tool' and column_name = 'pwsid')
and table_name not like '%2025%'
and table_name not like '%2026%'
order by table_name, ordinal_position
) b on a.table_name = b.table_name and a.column_name = b.column_name 
where b.column_name is null

--generate truncate and insert into statements (exclude any unneeded lines)
select 'truncate table epic_water_tool_production.'||table_name||';'
, 'insert into epic_water_tool_production.'||table_name||' select * from epic_water_tool.'||table_name||';'
from information_schema.tables 
where table_schema = 'epic_water_tool'
and table_name not like '%2025%'
and table_name not like '%2026%'
order by table_name;



/* 
 * 
 * prepare scripts that need to be run and run them altogether
 * to update everything at once at low-usage time
 * 
 * if there are any new tables, create them and create indexes
 * otherwise alter tables to rename or add columns
 * 
 * script truncate and insert into queries
 * 
 * promote any code changes after updating production
 * 
 */
alter table epic_water_tool_production.pwsid_funded_highlevel_summary	rename column times_funded_2009_2021 to times_funded;
alter table epic_water_tool_production.pwsid_funded_highlevel_summary	rename column total_srf_assistance_2009_2021 to total_srf_assistance;
alter table epic_water_tool_production.pwsid_funded_highlevel_summary	rename column median_srf_assistance_2009_2021 to median_srf_assistance;
alter table epic_water_tool_production.pwsid_funded_highlevel_summary	rename column total_principal_forgiveness_2009_2021 to total_principal_forgiveness;

alter table epic_water_tool_production.xwalk_pct_change_10yr	add column total_pop_pct_change_2011_2021_cap text;
alter table epic_water_tool_production.xwalk_pct_change_10yr	add column mhi_pct_change_2011_2021_cap text;

--we need 1 row in file_import_log just to get the last update date
truncate table epic_water_tool_production.file_import_tracker; 
insert into epic_water_tool_production.file_import_tracker (file_url, last_import_date)
select file_url, last_import_date from epic_water_tool.file_import_tracker order by last_import_date desc limit 1;

--tables without geoms (faster)
truncate table epic_water_tool_production.cejst;	insert into epic_water_tool_production.cejst select * from epic_water_tool.cejst;
truncate table epic_water_tool_production.cvi;	insert into epic_water_tool_production.cvi select * from epic_water_tool.cvi;
truncate table epic_water_tool_production.ejscreen;	insert into epic_water_tool_production.ejscreen select * from epic_water_tool.ejscreen;
truncate table epic_water_tool_production.epa_sabs;	insert into epic_water_tool_production.epa_sabs select * from epic_water_tool.epa_sabs;
truncate table epic_water_tool_production.epa_sabs_xwalk;	insert into epic_water_tool_production.epa_sabs_xwalk select * from epic_water_tool.epa_sabs_xwalk;
truncate table epic_water_tool_production.national_bwn_highlevel_summary;	insert into epic_water_tool_production.national_bwn_highlevel_summary select * from epic_water_tool.national_bwn_highlevel_summary;
truncate table epic_water_tool_production.place_sabs_xtab;	insert into epic_water_tool_production.place_sabs_xtab select * from epic_water_tool.place_sabs_xtab;
truncate table epic_water_tool_production.pws_counties;	insert into epic_water_tool_production.pws_counties select * from epic_water_tool.pws_counties;
truncate table epic_water_tool_production.pwsid_funded_highlevel_summary;	insert into epic_water_tool_production.pwsid_funded_highlevel_summary select * from epic_water_tool.pwsid_funded_highlevel_summary;
truncate table epic_water_tool_production.pwsid_npdes_usts_rmps_imp;	insert into epic_water_tool_production.pwsid_npdes_usts_rmps_imp select * from epic_water_tool.pwsid_npdes_usts_rmps_imp;
truncate table epic_water_tool_production.sdwis_viols;	insert into epic_water_tool_production.sdwis_viols select * from epic_water_tool.sdwis_viols;
truncate table epic_water_tool_production.svi;	insert into epic_water_tool_production.svi select * from epic_water_tool.svi;
truncate table epic_water_tool_production.xwalk_pct_change_10yr;	insert into epic_water_tool_production.xwalk_pct_change_10yr select * from epic_water_tool.xwalk_pct_change_10yr;

--tables with geoms (slower)
truncate table epic_water_tool_production.epa_sabs_points;	insert into epic_water_tool_production.epa_sabs_points select * from epic_water_tool.epa_sabs_points;
truncate table epic_water_tool_production.epa_sabs_geoms;	insert into epic_water_tool_production.epa_sabs_geoms select * from epic_water_tool.epa_sabs_geoms;

--update the cache last
truncate table epic_water_tool_production.wdt_mvt;	insert into epic_water_tool_production.wdt_mvt select * from epic_water_tool.wdt_mvt;
