/* 
 * After importing updated data via Python script, run scripts below to index data, etc.
 */

--generate sql to create indexes on all new tables with pwsid column, copy and pasted to run
select '	create index on '||table_schema||'.'||table_name||' ('||column_name||');'
from information_schema.columns 
where table_schema = 'epic_water_tool'
and table_name not like '%2025%' --exclude archived tables renamed with datetime during import
and table_name not like '%2026%' --exclude archived tables renamed with datetime during import
and column_name = 'pwsid'
order by table_name, ordinal_position

	create index on epic_water_tool.cejst (pwsid);
	create index on epic_water_tool.cvi (pwsid);
	create index on epic_water_tool.ejscreen (pwsid);
	create index on epic_water_tool.epa_sabs (pwsid);
	create index on epic_water_tool.epa_sabs_geoms (pwsid);
	create index on epic_water_tool.epa_sabs_xwalk (pwsid);
	create index on epic_water_tool.national_bwn_highlevel_summary (pwsid);
	create index on epic_water_tool.national_bwn_summary (pwsid);
	create index on epic_water_tool.pwsid_funded_highlevel_summary (pwsid);
	create index on epic_water_tool.pwsid_npdes_usts_rmps_imp (pwsid);
	create index on epic_water_tool.pwsid_summarized_funding_data (pwsid);
	create index on epic_water_tool.sdwis_viols (pwsid);
	create index on epic_water_tool.svi (pwsid);
	create index on epic_water_tool.xwalk_pct_change_10yr (pwsid);



/* 
 * 
 * if epa_sabs_geoms was imported, there are several scripts that need to be run
 *  
 */
	
	--execute the following update statetment to fix any invalid geometries
	--execute 1 or more times until 0 rows are updated
	update epic_water_tool.epa_sabs_geoms set geom = st_buffer(geom,0) where st_isvalid(geom) = false;
	
	--drop existing index on previous table (or give new index a different name)
	drop index CONCURRENTLY if exists epic_water_tool.sidx_epa_sabs_geoms_geom;
	--create index on new table
	create index CONCURRENTLY sidx_epa_sabs_geoms_geom ON epic_water_tool.epa_sabs_geoms USING gist (geom);
	--cluster on index
	alter table epic_water_tool.epa_sabs_geoms cluster on sidx_epa_sabs_geoms_geom;


	--truncate epa_sabs_points table, repopulate from new data, and then add stusps
	truncate epic_water_tool.epa_sabs_points;
	
	insert into epic_water_tool.epa_sabs_points (pwsid,geom)
	select pwsid,st_pointonsurface(geom)
	from epic_water_tool.epa_sabs_geoms;
	
	update epic_water_tool.epa_sabs_points
	set stusps = cs.stusps
	from cartographic_state2022 cs 
	where st_intersects(epic_water_tool.epa_sabs_points.geom, cs.geom);

	--truncate pws_counties and then repopulate from new data
	truncate table epic_water_tool.pws_counties;
	
	insert into epic_water_tool.pws_counties
	select 
	a.pwsid, array_to_string(array_agg(cc.namelsad||', '||cc.stusps),'; ') as counties 
	from cartographic_counties2022 cc
	join epic_water_tool.epa_sabs_geoms a on st_intersects(a.geom, cc.geom)
	where geometrytype(st_intersection(a.geom,cc.geom)) in ('POLYGON','MULTIPOLYGON') 
	--and st_area(st_intersection(a.geom,cc.geom))/st_area(a.geom) > .2
	group by a.pwsid
	
	--truncate place_sabs_xtab and then repopulate from new data
	truncate table epic_water_tool.place_sabs_xtab;
	
	insert into epic_water_tool.place_sabs_xtab (geoid, pwsid)
	select cp.geoid, a.pwsid
	from cartographic_places2022 cp 
	join epic_water_tool.epa_sabs_geoms a on st_intersects(a.geom,cp.geom);

	update epic_water_tool.place_sabs_xtab 
	set frac_sab = a.frac_sab, frac_place = a.frac_place
	from ( 
		select cp.geoid, a.pwsid 
		, st_area(st_intersection(a.geom,cp.geom))/st_area(a.geom) frac_sab
		, st_area(st_intersection(a.geom,cp.geom))/st_area(cp.geom) frac_place
		from cartographic_places2022 cp 
		join epic_water_tool.place_sabs_xtab x on cp.geoid = x.geoid
		join epic_water_tool.epa_sabs_geoms a on a.pwsid = x.pwsid
	) a 
	where epic_water_tool.place_sabs_xtab.geoid = a.geoid and epic_water_tool.place_sabs_xtab.pwsid = a.pwsid ;

	delete 
	from epic_water_tool.place_sabs_xtab
	where frac_sab = 0 or frac_place = 0;
	
	delete 
	from epic_water_tool.place_sabs_xtab
	where frac_sab < 0.01 or frac_place < 0.01;

/*
 * if any table or column names changed, or any new tables or columns there will code changes to make
 * the sql below will provide the column names for each table to copy and paste into wdt_mvt.php
 * all raw data is imported as text, so casting to integer or float is required in the select statements in wdt_mvt.php
 */

	select table_name, ','||array_to_string(array_agg(column_name), ', ')
	from (
		select table_name, column_name
		from information_schema.columns 
		where table_schema = 'epic_water_tool'
		and column_name <> 'pwsid'
		and table_name not like '%2025%'
		and table_name not like '%2026%'
		order by table_name, ordinal_position
	) a 
	group by a.table_name 
	order by a.table_name; 


/*
 * Once all the data has been indexed and any code changes required have been made to generate map data
 * then the cache must be cleared by either truncating the wdt_mvt table when all tables have been updated
 * or deleting specific layers when only some of the tables have been updated
 * (look in wdt_mvt.php to identify tables used for each layer)
 */

truncate table epic_water_tool.wdt_mvt;

select layer, count(*)
from epic_water_tool.wdt_mvt 
group by layer 
order by layer;

--clear cache for specific layers
delete from epic_water_tool.wdt_mvt 
where layer in ('pws_sabs', 'pws_viols')


