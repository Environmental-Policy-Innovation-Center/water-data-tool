--
-- PostgreSQL database dump
--

-- Dumped from database version 15.12
-- Dumped by pg_dump version 16.4 (Ubuntu 16.4-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: acs; Type: DATABASE; Schema: -; Owner: nobody
--

CREATE DATABASE acs WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';


ALTER DATABASE acs OWNER TO nobody;

\connect acs

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


--
-- Name: acs; Type: DATABASE PROPERTIES; Schema: -; Owner: nobody
--

ALTER DATABASE acs SET search_path TO '$user', 'public', 'sde';


\connect acs

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: postgis_raster; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_raster WITH SCHEMA public;


--
-- Name: EXTENSION postgis_raster; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_raster IS 'PostGIS raster types and functions';


--
-- Name: epic_water_tool; Type: SCHEMA; Schema: -; Owner: nobody
--

CREATE SCHEMA epic_water_tool;


ALTER SCHEMA epic_water_tool OWNER TO nobody;

--
-- Name: epic_water_tool_production; Type: SCHEMA; Schema: -; Owner: nobody
--

CREATE SCHEMA epic_water_tool_production;


ALTER SCHEMA epic_water_tool_production OWNER TO nobody;




--
-- Name: cejst; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.cejst (
    pwsid text,
    a_int_identified_as_disadvantaged text,
    pw_int_hh_percent_pre_1960s_housing_lead_paint_indicator text,
    pw_int_pop_low_life_expectancy_percentile text
);


ALTER TABLE epic_water_tool.cejst OWNER TO nobody;

--
-- Name: cvi; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.cvi (
    pwsid text,
    pw_int_hh_redlining text,
    pw_int_pop_life_expectancy text,
    pw_int_pop_cancer text,
    a_int_overall_cvi_score text
);


ALTER TABLE epic_water_tool.cvi OWNER TO nobody;

--
-- Name: ejscreen; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.ejscreen (
    pwsid text,
    a_int_dwater text,
    pw_ext_pop_disability text
);


ALTER TABLE epic_water_tool.ejscreen OWNER TO nobody;

--
-- Name: epa_sabs; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.epa_sabs (
    pwsid text,
    pws_name text,
    primacy_agency text,
    pop_cat_5 text,
    population_served_count text,
    service_connections_count text,
    service_area_type text,
    symbology_field text,
    detailed_facility_report text,
    ewg_report_link text,
    epic_area_mi2 text
);


ALTER TABLE epic_water_tool.epa_sabs OWNER TO nobody;

--
-- Name: epa_sabs_geoms; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.epa_sabs_geoms (
    gid integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    pwsid text
);


ALTER TABLE epic_water_tool.epa_sabs_geoms OWNER TO nobody;

--
-- Name: epa_sabs_geoms_gid_seq; Type: SEQUENCE; Schema: epic_water_tool; Owner: nobody
--

CREATE SEQUENCE epic_water_tool.epa_sabs_geoms_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE epic_water_tool.epa_sabs_geoms_gid_seq OWNER TO nobody;

--
-- Name: epa_sabs_geoms_gid_seq; Type: SEQUENCE OWNED BY; Schema: epic_water_tool; Owner: nobody
--

ALTER SEQUENCE epic_water_tool.epa_sabs_geoms_gid_seq OWNED BY epic_water_tool.epa_sabs_geoms.gid;


--
-- Name: epa_sabs_points; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.epa_sabs_points (
    stusps character varying(2),
    pwsid text,
    geom public.geometry
);


ALTER TABLE epic_water_tool.epa_sabs_points OWNER TO nobody;

--
-- Name: epa_sabs_xwalk; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.epa_sabs_xwalk (
    pwsid text,
    total_pop text,
    mhi text,
    hh_inc_lowest_quintile text,
    black_alone_per text,
    asian_alone_per text,
    white_alone_per text,
    aian_alone_per text,
    napi_alone_per text,
    other_alone_per text,
    mixed_alone_per text,
    hisp_alone_per text,
    ageunder_5_per text,
    age_over_61_per text,
    bachelors_per text,
    laborforce_unemployed_per text,
    water_rate_less_125_per text,
    water_rate_between_125_249_per text,
    water_rate_between_250_499_per text,
    water_rate_between_500_749_per text,
    water_rate_between_750_999_per text,
    water_rate_over_1000_per text,
    hh_below_pov_per text,
    hh_rent_home_per text,
    hh_own_home_per text,
    poc_alone_per text,
    pop_in_pov_per text,
    no_health_insurance_per text,
    epic_pop_density text,
    most_common_rate_tidy text
);


ALTER TABLE epic_water_tool.epa_sabs_xwalk OWNER TO nobody;

--
-- Name: file_import_tracker; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.file_import_tracker (
    file_url character varying,
    last_import_date timestamp without time zone
);


ALTER TABLE epic_water_tool.file_import_tracker OWNER TO nobody;

--
-- Name: national_bwn_highlevel_summary; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.national_bwn_highlevel_summary (
    pwsid text,
    date_of_first_advisory text,
    date_of_last_advisory text,
    total_bwn text,
    min_reporting_year_for_state text,
    max_reporting_year_for_state text,
    state text,
    data_tool_tip text,
    download_link text,
    clean_date_range text
);


ALTER TABLE epic_water_tool.national_bwn_highlevel_summary OWNER TO nobody;

--
-- Name: place_sabs_xtab; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.place_sabs_xtab (
    geoid character varying(7),
    pwsid text,
    frac_sab numeric,
    frac_place numeric
);


ALTER TABLE epic_water_tool.place_sabs_xtab OWNER TO nobody;

--
-- Name: pws_counties; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.pws_counties (
    pwsid text,
    counties text
);


ALTER TABLE epic_water_tool.pws_counties OWNER TO nobody;

--
-- Name: pwsid_funded_highlevel_summary; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.pwsid_funded_highlevel_summary (
    pwsid text,
    times_funded text,
    total_srf_assistance text,
    median_srf_assistance text,
    total_principal_forgiveness text
);


ALTER TABLE epic_water_tool.pwsid_funded_highlevel_summary OWNER TO nobody;

--
-- Name: pwsid_npdes_usts_rmps_imp; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.pwsid_npdes_usts_rmps_imp (
    pwsid text,
    huc12 text,
    num_facilities text,
    npdes_permits text,
    total_permit_eff_viols text,
    total_open_usts text,
    total_facilities_w_rmps text,
    streams_303d_list text
);


ALTER TABLE epic_water_tool.pwsid_npdes_usts_rmps_imp OWNER TO nobody;

--
-- Name: sdwis_viols; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.sdwis_viols (
    pwsid text,
    gw_sw_code text,
    primary_source_code text,
    first_reported_date text,
    years_operating text,
    owner_type text,
    primacy_type text,
    is_grant_eligible_ind text,
    is_wholesaler_ind text,
    is_school_or_daycare_ind text,
    source_water_protection_code text,
    phone_number text,
    lead_and_copper_rule_healthbased_5yr text,
    radionuclides_and_revised_rad_rule_healthbased_5yr text,
    groundwater_rule_healthbased_5yr text,
    surface_water_treatment_rules_healthbased_5yr text,
    total_coliform_rules_healthbased_5yr text,
    inorganic_chemicals_healthbased_5yr text,
    stage_1_disinfectants_and_byproducts_rule_healthbased_5yr text,
    stage_2_disinfectants_and_byproducts_rule_healthbased_5yr text,
    synthetic_organic_chemicals_healthbased_5yr text,
    volatile_organic_chemicals_healthbased_5yr text,
    health_viols_5yr text,
    paperwork_viols_5yr text,
    total_viols_5yr text,
    lead_and_copper_rule_healthbased_10yr text,
    radionuclides_and_revised_rad_rule_healthbased_10yr text,
    groundwater_rule_healthbased_10yr text,
    surface_water_treatment_rules_healthbased_10yr text,
    total_coliform_rules_healthbased_10yr text,
    inorganic_chemicals_healthbased_10yr text,
    stage_1_disinfectants_and_byproducts_rule_healthbased_10yr text,
    stage_2_disinfectants_and_byproducts_rule_healthbased_10yr text,
    synthetic_organic_chemicals_healthbased_10yr text,
    volatile_organic_chemicals_healthbased_10yr text,
    health_viols_10yr text,
    paperwork_viols_10yr text,
    total_viols_10yr text,
    violations_all_years text,
    open_health_viol text
);


ALTER TABLE epic_water_tool.sdwis_viols OWNER TO nobody;

--
-- Name: svi; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.svi (
    pwsid text,
    pw_int_pop_rpl_themes text
);


ALTER TABLE epic_water_tool.svi OWNER TO nobody;

--
-- Name: wdt_mvt; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.wdt_mvt (
    layer character varying NOT NULL,
    z integer NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    mvt bytea
);


ALTER TABLE epic_water_tool.wdt_mvt OWNER TO nobody;

--
-- Name: xwalk_pct_change_10yr; Type: TABLE; Schema: epic_water_tool; Owner: nobody
--

CREATE TABLE epic_water_tool.xwalk_pct_change_10yr (
    pwsid text,
    total_pop_pct_change_2011_2021 text,
    laborforce_unemployed_pct_change_2011_2021 text,
    mhi_pct_change_2011_2021 text,
    hh_inc_lowest_quintile_pct_change_2011_2021 text,
    hh_total_pct_change_2011_2021 text,
    hh_below_pov_pct_change_2011_2021 text,
    poc_alone_per_pct_change_2011_2021 text,
    pop_in_pov_per_pct_change_2011_2021 text,
    income_change_flag text,
    population_change_flag text,
    total_pop_pct_change_2011_2021_cap text,
    mhi_pct_change_2011_2021_cap text
);


ALTER TABLE epic_water_tool.xwalk_pct_change_10yr OWNER TO nobody;

--
-- Name: cartographic_counties2022; Type: TABLE; Schema: public; Owner: nobody
--

CREATE TABLE public.cartographic_counties2022 (
    gid integer NOT NULL,
    statefp character varying(2),
    countyfp character varying(3),
    countyns character varying(8),
    affgeoid character varying(14),
    geoid character varying(5),
    name character varying(100),
    namelsad character varying(100),
    stusps character varying(2),
    state_name character varying(100),
    lsad character varying(2),
    aland double precision,
    awater double precision,
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public.cartographic_counties2022 OWNER TO nobody;

--
-- Name: cartographic_counties2022_gid_seq; Type: SEQUENCE; Schema: public; Owner: nobody
--

CREATE SEQUENCE public.cartographic_counties2022_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cartographic_counties2022_gid_seq OWNER TO nobody;

--
-- Name: cartographic_counties2022_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nobody
--

ALTER SEQUENCE public.cartographic_counties2022_gid_seq OWNED BY public.cartographic_counties2022.gid;


--
-- Name: cartographic_places2022; Type: TABLE; Schema: public; Owner: nobody
--

CREATE TABLE public.cartographic_places2022 (
    gid integer NOT NULL,
    statefp character varying(2),
    placefp character varying(5),
    placens character varying(8),
    affgeoid character varying(16),
    geoid character varying(7),
    name character varying(100),
    namelsad character varying(100),
    stusps character varying(2),
    state_name character varying(100),
    lsad character varying(2),
    aland double precision,
    awater double precision,
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public.cartographic_places2022 OWNER TO nobody;

--
-- Name: cartographic_places2022_gid_seq; Type: SEQUENCE; Schema: public; Owner: nobody
--

CREATE SEQUENCE public.cartographic_places2022_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cartographic_places2022_gid_seq OWNER TO nobody;

--
-- Name: cartographic_places2022_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nobody
--

ALTER SEQUENCE public.cartographic_places2022_gid_seq OWNED BY public.cartographic_places2022.gid;


--
-- Name: cartographic_state2022; Type: TABLE; Schema: public; Owner: nobody
--

CREATE TABLE public.cartographic_state2022 (
    gid integer NOT NULL,
    statefp character varying(2),
    statens character varying(8),
    affgeoid character varying(11),
    geoid character varying(2),
    stusps character varying(2),
    name character varying(100),
    lsad character varying(2),
    aland double precision,
    awater double precision,
    geom public.geometry(MultiPolygon,4326)
);


ALTER TABLE public.cartographic_state2022 OWNER TO nobody;

--
-- Name: cartographic_state2022_gid_seq; Type: SEQUENCE; Schema: public; Owner: nobody
--

CREATE SEQUENCE public.cartographic_state2022_gid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cartographic_state2022_gid_seq OWNER TO nobody;

--
-- Name: cartographic_state2022_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: nobody
--

ALTER SEQUENCE public.cartographic_state2022_gid_seq OWNED BY public.cartographic_state2022.gid;


--
-- Name: epa_sabs_geoms gid; Type: DEFAULT; Schema: epic_water_tool; Owner: nobody
--

ALTER TABLE ONLY epic_water_tool.epa_sabs_geoms ALTER COLUMN gid SET DEFAULT nextval('epic_water_tool.epa_sabs_geoms_gid_seq'::regclass);


--
-- Name: cartographic_counties2022 gid; Type: DEFAULT; Schema: public; Owner: nobody
--

ALTER TABLE ONLY public.cartographic_counties2022 ALTER COLUMN gid SET DEFAULT nextval('public.cartographic_counties2022_gid_seq'::regclass);


--
-- Name: cartographic_places2022 gid; Type: DEFAULT; Schema: public; Owner: nobody
--

ALTER TABLE ONLY public.cartographic_places2022 ALTER COLUMN gid SET DEFAULT nextval('public.cartographic_places2022_gid_seq'::regclass);


--
-- Name: cartographic_state2022 gid; Type: DEFAULT; Schema: public; Owner: nobody
--

ALTER TABLE ONLY public.cartographic_state2022 ALTER COLUMN gid SET DEFAULT nextval('public.cartographic_state2022_gid_seq'::regclass);



--
-- Name: epa_sabs_geoms epa_sabs_geoms_pkey; Type: CONSTRAINT; Schema: epic_water_tool; Owner: nobody
--

ALTER TABLE ONLY epic_water_tool.epa_sabs_geoms
    ADD CONSTRAINT epa_sabs_geoms_pkey PRIMARY KEY (gid);


--
-- Name: wdt_mvt wdt_mvt_pk; Type: CONSTRAINT; Schema: epic_water_tool; Owner: nobody
--

ALTER TABLE ONLY epic_water_tool.wdt_mvt
    ADD CONSTRAINT wdt_mvt_pk PRIMARY KEY (layer, z, x, y);


--
-- Name: cartographic_counties2022 cartographic_counties2022_pkey; Type: CONSTRAINT; Schema: public; Owner: nobody
--

ALTER TABLE ONLY public.cartographic_counties2022
    ADD CONSTRAINT cartographic_counties2022_pkey PRIMARY KEY (gid);


--
-- Name: cartographic_places2022 cartographic_places2022_pkey; Type: CONSTRAINT; Schema: public; Owner: nobody
--

ALTER TABLE ONLY public.cartographic_places2022
    ADD CONSTRAINT cartographic_places2022_pkey PRIMARY KEY (gid);


--
-- Name: cartographic_state2022 cartographic_state2022_pkey; Type: CONSTRAINT; Schema: public; Owner: nobody
--

ALTER TABLE ONLY public.cartographic_state2022
    ADD CONSTRAINT cartographic_state2022_pkey PRIMARY KEY (gid);


--
-- Name: cejst_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX cejst_pwsid_idx ON epic_water_tool.cejst USING btree (pwsid);


--
-- Name: cvi_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX cvi_pwsid_idx ON epic_water_tool.cvi USING btree (pwsid);


--
-- Name: ejscreen_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX ejscreen_pwsid_idx ON epic_water_tool.ejscreen USING btree (pwsid);


--
-- Name: epa_sabs_geoms_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX epa_sabs_geoms_pwsid_idx ON epic_water_tool.epa_sabs_geoms USING btree (pwsid);


--
-- Name: epa_sabs_points_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX epa_sabs_points_pwsid_idx ON epic_water_tool.epa_sabs_points USING btree (pwsid);


--
-- Name: epa_sabs_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX epa_sabs_pwsid_idx ON epic_water_tool.epa_sabs USING btree (pwsid);


--
-- Name: epa_sabs_xwalk_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX epa_sabs_xwalk_pwsid_idx ON epic_water_tool.epa_sabs_xwalk USING btree (pwsid);


--
-- Name: national_bwn_highlevel_summary_pwsid_idx1; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX national_bwn_highlevel_summary_pwsid_idx1 ON epic_water_tool.national_bwn_highlevel_summary USING btree (pwsid);


--
-- Name: place_sabs_xtab_geoid_pwsid_idx1; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX place_sabs_xtab_geoid_pwsid_idx1 ON epic_water_tool.place_sabs_xtab USING btree (geoid, pwsid);


--
-- Name: pws_counties_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX pws_counties_pwsid_idx ON epic_water_tool.pws_counties USING btree (pwsid);


--
-- Name: pwsid_funded_highlevel_summary_pwsid_idx1; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX pwsid_funded_highlevel_summary_pwsid_idx1 ON epic_water_tool.pwsid_funded_highlevel_summary USING btree (pwsid);


--
-- Name: pwsid_npdes_usts_rmps_imp_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX pwsid_npdes_usts_rmps_imp_pwsid_idx ON epic_water_tool.pwsid_npdes_usts_rmps_imp USING btree (pwsid);


--
-- Name: sdwis_viols_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX sdwis_viols_pwsid_idx ON epic_water_tool.sdwis_viols USING btree (pwsid);


--
-- Name: sidx_epa_sabs_geoms_geom; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX sidx_epa_sabs_geoms_geom ON epic_water_tool.epa_sabs_geoms USING gist (geom);

ALTER TABLE epic_water_tool.epa_sabs_geoms CLUSTER ON sidx_epa_sabs_geoms_geom;


--
-- Name: sidx_epa_sabs_points_geom; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX sidx_epa_sabs_points_geom ON epic_water_tool.epa_sabs_points USING gist (geom);

ALTER TABLE epic_water_tool.epa_sabs_points CLUSTER ON sidx_epa_sabs_points_geom;


--
-- Name: svi_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX svi_pwsid_idx ON epic_water_tool.svi USING btree (pwsid);


--
-- Name: wdt_mvt_z_x_y_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX wdt_mvt_z_x_y_idx ON epic_water_tool.wdt_mvt USING btree (z, x, y);


--
-- Name: xwalk_pct_change_10yr_pwsid_idx; Type: INDEX; Schema: epic_water_tool; Owner: nobody
--

CREATE INDEX xwalk_pct_change_10yr_pwsid_idx ON epic_water_tool.xwalk_pct_change_10yr USING btree (pwsid);


--
-- Name: cartographic_counties2022_geom_idx; Type: INDEX; Schema: public; Owner: nobody
--

CREATE INDEX cartographic_counties2022_geom_idx ON public.cartographic_counties2022 USING gist (geom);

ALTER TABLE public.cartographic_counties2022 CLUSTER ON cartographic_counties2022_geom_idx;


--
-- Name: cartographic_counties2022_namelsad_stusps_idx; Type: INDEX; Schema: public; Owner: nobody
--

CREATE INDEX cartographic_counties2022_namelsad_stusps_idx ON public.cartographic_counties2022 USING btree (namelsad, stusps);


--
-- Name: cartographic_places2022_affgeoid_idx; Type: INDEX; Schema: public; Owner: nobody
--

CREATE INDEX cartographic_places2022_affgeoid_idx ON public.cartographic_places2022 USING btree (affgeoid);


--
-- Name: cartographic_places2022_geoid_idx; Type: INDEX; Schema: public; Owner: nobody
--

CREATE INDEX cartographic_places2022_geoid_idx ON public.cartographic_places2022 USING btree (geoid);


--
-- Name: cartographic_places2022_geom_idx; Type: INDEX; Schema: public; Owner: nobody
--

CREATE INDEX cartographic_places2022_geom_idx ON public.cartographic_places2022 USING gist (geom);

ALTER TABLE public.cartographic_places2022 CLUSTER ON cartographic_places2022_geom_idx;


--
-- PostgreSQL database dump complete
--

