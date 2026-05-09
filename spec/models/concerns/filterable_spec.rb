require "rails_helper"

RSpec.describe Filterable, type: :model do
  describe ".apply_filters" do
    let!(:system_a) { create(:public_water_system) }
    let!(:system_b) { create(:public_water_system) }

    context "with no filters" do
      it "returns all systems" do
        results = PublicWaterSystem.apply_filters({})
        expect(results).to include(system_a, system_b)
      end
    end

    context "categorical filters" do
      let!(:groundwater_system) { create(:public_water_system, gw_sw_code: "Groundwater", stusps: "VT") }
      let!(:surface_water_system) { create(:public_water_system, gw_sw_code: "Surface Water", stusps: "RI") }

      it "filters by symbology_field" do
        modeled = create(:public_water_system, symbology_field: "Modeled")
        system_sourced = create(:public_water_system, symbology_field: "System Sourced")

        results = PublicWaterSystem.apply_filters(symbology_field: "Modeled")
        expect(results).to include(modeled)
        expect(results).not_to include(system_sourced)
      end

      it "filters by pop_cat_5" do
        small = create(:public_water_system, pop_cat_5: "<=500")
        large = create(:public_water_system, pop_cat_5: ">100,000")

        results = PublicWaterSystem.apply_filters(pop_cat_5: ["<=500"])
        expect(results).to include(small)
        expect(results).not_to include(large)
      end

      it "filters by gw_sw_code" do
        results = PublicWaterSystem.apply_filters(gw_sw_code: "Groundwater")
        expect(results).to include(groundwater_system)
        expect(results).not_to include(surface_water_system)
      end

      it "filters by state" do
        results = PublicWaterSystem.apply_filters(state: "VT")
        expect(results).to include(groundwater_system)
        expect(results).not_to include(surface_water_system)
      end

      it "filters by multiple owner_types (OR within group)" do
        federal = create(:public_water_system, owner_type: "Federal")
        local = create(:public_water_system, owner_type: "Local")
        private_sys = create(:public_water_system, owner_type: "Private")

        results = PublicWaterSystem.apply_filters(owner_type: %w[Federal Local])
        expect(results).to include(federal, local)
        expect(results).not_to include(private_sys)
      end

      it "ANDs between different filter groups" do
        groundwater_ri = create(:public_water_system, gw_sw_code: "Groundwater", stusps: "RI")
        results = PublicWaterSystem.apply_filters(gw_sw_code: "Groundwater", state: "RI")
        expect(results).to contain_exactly(groundwater_ri)
      end
    end

    context "boolean filters" do
      it "filters wholesalers" do
        wholesaler = create(:public_water_system, is_wholesaler: true)
        non_wholesaler = create(:public_water_system, is_wholesaler: false)

        results = PublicWaterSystem.apply_filters(is_wholesaler: "true")
        expect(results).to include(wholesaler)
        expect(results).not_to include(non_wholesaler)
      end

      it "ignores boolean filter when value is not 'true'" do
        wholesaler = create(:public_water_system, is_wholesaler: true)
        non_wholesaler = create(:public_water_system, is_wholesaler: false)

        results = PublicWaterSystem.apply_filters(is_wholesaler: "false")
        expect(results).to include(wholesaler, non_wholesaler)
      end

      it "filters systems with open violations" do
        with_viol = create(:public_water_system, open_health_viol: "Yes")
        without_viol = create(:public_water_system, open_health_viol: "No")

        results = PublicWaterSystem.apply_filters(has_open_violations: "true")
        expect(results).to include(with_viol)
        expect(results).not_to include(without_viol)
      end
    end

    context "range filters" do
      it "filters by area_min" do
        small = create(:public_water_system, area_sq_miles: 5.0)
        large = create(:public_water_system, area_sq_miles: 50.0)

        results = PublicWaterSystem.apply_filters(area_min: "20")
        expect(results).to include(large)
        expect(results).not_to include(small)
      end

      it "treats non-numeric area_min as zero, returning all systems" do
        any_system = create(:public_water_system, area_sq_miles: 1.0)
        results = PublicWaterSystem.apply_filters(area_min: "abc")
        expect(results).to include(any_system)
      end

      it "filters by area_max" do
        small = create(:public_water_system, area_sq_miles: 5.0)
        large = create(:public_water_system, area_sq_miles: 50.0)

        results = PublicWaterSystem.apply_filters(area_max: "10")
        expect(results).to include(small)
        expect(results).not_to include(large)
      end

      it "filters by area range (min AND max)" do
        small = create(:public_water_system, area_sq_miles: 2.0)
        medium = create(:public_water_system, area_sq_miles: 15.0)
        large = create(:public_water_system, area_sq_miles: 80.0)

        results = PublicWaterSystem.apply_filters(area_min: "10", area_max: "20")
        expect(results).to include(medium)
        expect(results).not_to include(small, large)
      end
    end

    context "Non-health violations range filters" do
      it "filters by paperwork_violations_5yr_min" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, paperwork_violations_5yr: 2)
        create(:violations_summary, public_water_system: many, paperwork_violations_5yr: 10)

        results = PublicWaterSystem.apply_filters(paperwork_violations_5yr_min: "5")
        expect(results).to include(many)
        expect(results).not_to include(few)
      end

      it "filters by paperwork_violations_5yr_max" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, paperwork_violations_5yr: 2)
        create(:violations_summary, public_water_system: many, paperwork_violations_5yr: 10)

        results = PublicWaterSystem.apply_filters(paperwork_violations_5yr_max: "5")
        expect(results).to include(few)
        expect(results).not_to include(many)
      end

      it "filters by paperwork_violations_5yr range (min AND max)" do
        low = create(:public_water_system)
        mid = create(:public_water_system)
        high = create(:public_water_system)
        create(:violations_summary, public_water_system: low, paperwork_violations_5yr: 1)
        create(:violations_summary, public_water_system: mid, paperwork_violations_5yr: 5)
        create(:violations_summary, public_water_system: high, paperwork_violations_5yr: 15)

        results = PublicWaterSystem.apply_filters(paperwork_violations_5yr_min: "3", paperwork_violations_5yr_max: "10")
        expect(results).to include(mid)
        expect(results).not_to include(low, high)
      end

      it "filters by paperwork_violations_10yr_min" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, paperwork_violations_10yr: 2)
        create(:violations_summary, public_water_system: many, paperwork_violations_10yr: 10)

        results = PublicWaterSystem.apply_filters(paperwork_violations_10yr_min: "5")
        expect(results).to include(many)
        expect(results).not_to include(few)
      end

      it "filters by paperwork_violations_10yr_max" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, paperwork_violations_10yr: 2)
        create(:violations_summary, public_water_system: many, paperwork_violations_10yr: 10)

        results = PublicWaterSystem.apply_filters(paperwork_violations_10yr_max: "5")
        expect(results).to include(few)
        expect(results).not_to include(many)
      end

      it "filters by paperwork_violations_10yr range (min AND max)" do
        low = create(:public_water_system)
        mid = create(:public_water_system)
        high = create(:public_water_system)
        create(:violations_summary, public_water_system: low, paperwork_violations_10yr: 1)
        create(:violations_summary, public_water_system: mid, paperwork_violations_10yr: 5)
        create(:violations_summary, public_water_system: high, paperwork_violations_10yr: 15)

        results = PublicWaterSystem.apply_filters(paperwork_violations_10yr_min: "3", paperwork_violations_10yr_max: "10")
        expect(results).to include(mid)
        expect(results).not_to include(low, high)
      end
    end

    context "health sub-category filters" do
      it "filters a single 5yr subcat by min only" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, groundwater_rule_5yr: 2)
        create(:violations_summary, public_water_system: many, groundwater_rule_5yr: 10)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_min: "5")
        expect(results).to include(many)
        expect(results).not_to include(few)
      end

      it "filters a single 5yr subcat by max only" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, groundwater_rule_5yr: 2)
        create(:violations_summary, public_water_system: many, groundwater_rule_5yr: 10)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_max: "5")
        expect(results).to include(few)
        expect(results).not_to include(many)
      end

      it "filters a single 5yr subcat by range (min AND max)" do
        low = create(:public_water_system)
        mid = create(:public_water_system)
        high = create(:public_water_system)
        create(:violations_summary, public_water_system: low, groundwater_rule_5yr: 1)
        create(:violations_summary, public_water_system: mid, groundwater_rule_5yr: 5)
        create(:violations_summary, public_water_system: high, groundwater_rule_5yr: 20)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_min: "3", groundwater_rule_5yr_max: "10")
        expect(results).to include(mid)
        expect(results).not_to include(low, high)
      end

      it "filters a single 10yr subcat by range (min AND max)" do
        low = create(:public_water_system)
        mid = create(:public_water_system)
        high = create(:public_water_system)
        create(:violations_summary, public_water_system: low, lead_and_copper_10yr: 1)
        create(:violations_summary, public_water_system: mid, lead_and_copper_10yr: 5)
        create(:violations_summary, public_water_system: high, lead_and_copper_10yr: 20)

        results = PublicWaterSystem.apply_filters(lead_and_copper_10yr_min: "3", lead_and_copper_10yr_max: "10")
        expect(results).to include(mid)
        expect(results).not_to include(low, high)
      end

      it "ignores a subcat when both min and max params are nil" do
        any_system = create(:public_water_system)
        create(:violations_summary, public_water_system: any_system, groundwater_rule_5yr: 5)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_min: nil, groundwater_rule_5yr_max: nil)
        expect(results).to include(any_system)
      end

      it "ORs multiple 5yr subcats — system matches if ANY checked subcat is in range" do
        groundwater_only = create(:public_water_system)
        lead_only = create(:public_water_system)
        neither = create(:public_water_system)
        create(:violations_summary, public_water_system: groundwater_only, groundwater_rule_5yr: 5, lead_and_copper_5yr: 0)
        create(:violations_summary, public_water_system: lead_only, groundwater_rule_5yr: 0, lead_and_copper_5yr: 5)
        create(:violations_summary, public_water_system: neither, groundwater_rule_5yr: 0, lead_and_copper_5yr: 0)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_min: "1", lead_and_copper_5yr_min: "1")
        expect(results).to include(groundwater_only, lead_only)
        expect(results).not_to include(neither)
      end

      it "ORs multiple 10yr subcats — system matches if ANY checked subcat is in range" do
        groundwater_only = create(:public_water_system)
        lead_only = create(:public_water_system)
        neither = create(:public_water_system)
        create(:violations_summary, public_water_system: groundwater_only, groundwater_rule_10yr: 3, lead_and_copper_10yr: 0)
        create(:violations_summary, public_water_system: lead_only, groundwater_rule_10yr: 0, lead_and_copper_10yr: 3)
        create(:violations_summary, public_water_system: neither, groundwater_rule_10yr: 0, lead_and_copper_10yr: 0)

        results = PublicWaterSystem.apply_filters(groundwater_rule_10yr_min: "1", lead_and_copper_10yr_min: "1")
        expect(results).to include(groundwater_only, lead_only)
        expect(results).not_to include(neither)
      end

      it "ORs across time windows — system matches if violations in EITHER window" do
        both_windows = create(:public_water_system)
        only_5yr = create(:public_water_system)
        only_10yr = create(:public_water_system)
        neither = create(:public_water_system)
        create(:violations_summary, public_water_system: both_windows, groundwater_rule_5yr: 5, lead_and_copper_10yr: 3)
        create(:violations_summary, public_water_system: only_5yr, groundwater_rule_5yr: 5, lead_and_copper_10yr: 0)
        create(:violations_summary, public_water_system: only_10yr, groundwater_rule_5yr: 0, lead_and_copper_10yr: 3)
        create(:violations_summary, public_water_system: neither, groundwater_rule_5yr: 0, lead_and_copper_10yr: 0)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_min: "1", lead_and_copper_10yr_min: "1")
        expect(results).to include(both_windows, only_5yr, only_10yr)
        expect(results).not_to include(neither)
      end

      it "ORs paperwork violation windows — system matches if non-health violations in EITHER window" do
        only_5yr = create(:public_water_system)
        only_10yr = create(:public_water_system)
        neither = create(:public_water_system)
        create(:violations_summary, public_water_system: only_5yr, paperwork_violations_5yr: 8, paperwork_violations_10yr: 0)
        create(:violations_summary, public_water_system: only_10yr, paperwork_violations_5yr: 0, paperwork_violations_10yr: 8)
        create(:violations_summary, public_water_system: neither, paperwork_violations_5yr: 0, paperwork_violations_10yr: 0)

        results = PublicWaterSystem.apply_filters(paperwork_violations_5yr_min: "5", paperwork_violations_10yr_min: "5")
        expect(results).to include(only_5yr, only_10yr)
        expect(results).not_to include(neither)
      end

      it "ORs health and paperwork groups within the Violations category" do
        health_only = create(:public_water_system)
        paperwork_only = create(:public_water_system)
        neither = create(:public_water_system)
        create(:violations_summary, public_water_system: health_only, groundwater_rule_5yr: 5, paperwork_violations_5yr: 0)
        create(:violations_summary, public_water_system: paperwork_only, groundwater_rule_5yr: 0, paperwork_violations_5yr: 8)
        create(:violations_summary, public_water_system: neither, groundwater_rule_5yr: 0, paperwork_violations_5yr: 0)

        results = PublicWaterSystem.apply_filters(groundwater_rule_5yr_min: "1", paperwork_violations_5yr_min: "5")
        expect(results).to include(health_only, paperwork_only)
        expect(results).not_to include(neither)
      end
    end

    context "boil water filters" do
      it "filters by boil_water_notices_min" do
        few_notices = create(:public_water_system)
        many_notices = create(:public_water_system)
        create(:boil_water_summary, public_water_system: few_notices, total_notices: 1)
        create(:boil_water_summary, public_water_system: many_notices, total_notices: 8)

        results = PublicWaterSystem.apply_filters(boil_water_notices_min: "5")
        expect(results).to include(many_notices)
        expect(results).not_to include(few_notices)
      end
    end

    context "demographic filters" do
      it "filters by poverty_rate_min" do
        low_poverty = create(:public_water_system)
        high_poverty = create(:public_water_system)
        create(:demographic, public_water_system: low_poverty, poverty_rate: 5.0)
        create(:demographic, public_water_system: high_poverty, poverty_rate: 25.0)

        results = PublicWaterSystem.apply_filters(poverty_rate_min: "20")
        expect(results).to include(high_poverty)
        expect(results).not_to include(low_poverty)
      end
    end

    context "environmental justice filters" do
      it "filters by cejst_disadvantaged_pct_min" do
        low_ej = create(:public_water_system)
        high_ej = create(:public_water_system)
        create(:environmental_justice, public_water_system: low_ej, cejst_disadvantaged_pct: 10.0)
        create(:environmental_justice, public_water_system: high_ej, cejst_disadvantaged_pct: 75.0)

        results = PublicWaterSystem.apply_filters(cejst_disadvantaged_pct_min: "50")
        expect(results).to include(high_ej)
        expect(results).not_to include(low_ej)
      end
    end

    context "rate tier filters" do
      let!(:low_tier) { create(:public_water_system) }
      let!(:high_tier) { create(:public_water_system) }
      let!(:no_tier) { create(:public_water_system) }

      before do
        create(:demographic, public_water_system: low_tier, pwsid: low_tier.pwsid, most_common_rate_tier: "$125-249")
        create(:demographic, public_water_system: high_tier, pwsid: high_tier.pwsid, most_common_rate_tier: "$500-749")
        create(:demographic, public_water_system: no_tier, pwsid: no_tier.pwsid, most_common_rate_tier: nil)
      end

      it "filters by a single rate tier" do
        results = PublicWaterSystem.apply_filters(most_common_rate_tier: ["$125-249"])
        expect(results).to include(low_tier)
        expect(results).not_to include(high_tier, no_tier)
      end

      it "ORs multiple rate tiers" do
        results = PublicWaterSystem.apply_filters(most_common_rate_tier: ["$125-249", "$500-749"])
        expect(results).to include(low_tier, high_tier)
        expect(results).not_to include(no_tier)
      end

      it "includes null-rate systems when no_rate_info is true" do
        results = PublicWaterSystem.apply_filters(no_rate_info: "true")
        expect(results).to include(no_tier)
        expect(results).not_to include(low_tier, high_tier)
      end

      it "ORs rate tier with no_rate_info" do
        results = PublicWaterSystem.apply_filters(most_common_rate_tier: ["$125-249"], no_rate_info: "true")
        expect(results).to include(low_tier, no_tier)
        expect(results).not_to include(high_tier)
      end
    end

    context "funding filters" do
      it "filters by total_srf_assistance_min" do
        low_funded = create(:public_water_system)
        high_funded = create(:public_water_system)
        create(:funding_summary, public_water_system: low_funded, total_srf_assistance: 50_000)
        create(:funding_summary, public_water_system: high_funded, total_srf_assistance: 2_000_000)

        results = PublicWaterSystem.apply_filters(total_srf_assistance_min: "1000000")
        expect(results).to include(high_funded)
        expect(results).not_to include(low_funded)
      end

      it "ORs multiple funding columns" do
        many_times = create(:public_water_system)
        high_amount = create(:public_water_system)
        neither = create(:public_water_system)
        create(:funding_summary, public_water_system: many_times, times_funded: 5, total_srf_assistance: 10_000)
        create(:funding_summary, public_water_system: high_amount, times_funded: 1, total_srf_assistance: 5_000_000)
        create(:funding_summary, public_water_system: neither, times_funded: 0, total_srf_assistance: 0)

        results = PublicWaterSystem.apply_filters(times_funded_min: "3", total_srf_assistance_min: "1000000")
        expect(results).to include(many_times, high_amount)
        expect(results).not_to include(neither)
      end
    end

    context "watershed hazard filters" do
      it "filters by num_facilities_min" do
        low_hazard = create(:public_water_system)
        high_hazard = create(:public_water_system)
        create(:watershed_hazard, public_water_system: low_hazard, num_facilities: 1)
        create(:watershed_hazard, public_water_system: high_hazard, num_facilities: 20)

        results = PublicWaterSystem.apply_filters(num_facilities_min: "10")
        expect(results).to include(high_hazard)
        expect(results).not_to include(low_hazard)
      end

      it "ORs multiple hazard columns" do
        many_facilities = create(:public_water_system)
        many_usts = create(:public_water_system)
        clean = create(:public_water_system)
        create(:watershed_hazard, public_water_system: many_facilities, num_facilities: 50, open_underground_storage_tanks: 1)
        create(:watershed_hazard, public_water_system: many_usts, num_facilities: 1, open_underground_storage_tanks: 30)
        create(:watershed_hazard, public_water_system: clean, num_facilities: 0, open_underground_storage_tanks: 0)

        results = PublicWaterSystem.apply_filters(num_facilities_min: "20", open_underground_storage_tanks_min: "20")
        expect(results).to include(many_facilities, many_usts)
        expect(results).not_to include(clean)
      end
    end

    context "trend filters" do
      it "filters by population_pct_change_capped_min" do
        declining = create(:public_water_system)
        growing = create(:public_water_system)
        create(:trend_datum, public_water_system: declining, population_pct_change_capped: -5.0)
        create(:trend_datum, public_water_system: growing, population_pct_change_capped: 15.0)

        results = PublicWaterSystem.apply_filters(population_pct_change_capped_min: "10")
        expect(results).to include(growing)
        expect(results).not_to include(declining)
      end
    end

    context "place geographic filter" do
      it "filters by place_geoid via crosswalk" do
        place = create(:cartographic_place)
        in_place = create(:public_water_system)
        out_of_place = create(:public_water_system)
        create(:place_system_crosswalk, public_water_system: in_place, cartographic_place: place,
          pwsid: in_place.pwsid, geoid: place.geoid)

        results = PublicWaterSystem.apply_filters(place_geoid: place.geoid)
        expect(results).to include(in_place)
        expect(results).not_to include(out_of_place)
      end
    end

    context "county geographic filter" do
      let!(:county) { create(:cartographic_county) }
      let!(:in_county) { create(:public_water_system) }
      let!(:out_of_county) { create(:public_water_system) }

      before do
        conn = ActiveRecord::Base.connection
        # Give the county a real polygon over Vermont
        conn.execute(
          "UPDATE cartographic_counties SET geom = ST_Multi(ST_GeomFromText('POLYGON((-73.0 43.0,-71.0 43.0,-71.0 45.0,-73.0 45.0,-73.0 43.0))',4326)) WHERE geoid = #{conn.quote(county.geoid)}"
        )
        # Centroid inside the county polygon
        create(:service_area_geometry, public_water_system: in_county)
        conn.execute(
          "UPDATE service_area_geometries SET centroid = ST_GeomFromText('POINT(-72.0 44.0)',4326) WHERE pwsid = #{conn.quote(in_county.pwsid)}"
        )
        # Centroid well outside the county polygon
        create(:service_area_geometry, public_water_system: out_of_county)
        conn.execute(
          "UPDATE service_area_geometries SET centroid = ST_GeomFromText('POINT(-80.0 40.0)',4326) WHERE pwsid = #{conn.quote(out_of_county.pwsid)}"
        )
      end

      it "filters by county_geoid via spatial centroid intersection" do
        results = PublicWaterSystem.apply_filters(county_geoid: county.geoid)
        expect(results).to include(in_county)
        expect(results).not_to include(out_of_county)
      end
    end

    context "bounding box filter" do
      let!(:inside_bounds) { create(:public_water_system) }
      let!(:outside_bounds) { create(:public_water_system) }

      before do
        conn = ActiveRecord::Base.connection
        # Polygon overlapping the Vermont bounding box used in the filter call below
        create(:service_area_geometry, public_water_system: inside_bounds)
        conn.execute(
          "UPDATE service_area_geometries SET geom = ST_Multi(ST_GeomFromText('POLYGON((-72.5 43.5,-71.5 43.5,-71.5 44.5,-72.5 44.5,-72.5 43.5))',4326)) WHERE pwsid = #{conn.quote(inside_bounds.pwsid)}"
        )
        # Polygon far outside the filter bounding box
        create(:service_area_geometry, public_water_system: outside_bounds)
        conn.execute(
          "UPDATE service_area_geometries SET geom = ST_Multi(ST_GeomFromText('POLYGON((-90.5 30.5,-89.5 30.5,-89.5 31.5,-90.5 31.5,-90.5 30.5))',4326)) WHERE pwsid = #{conn.quote(outside_bounds.pwsid)}"
        )
      end

      it "filters by bounding box via spatial intersection" do
        results = PublicWaterSystem.apply_filters(bounds: "-73.0,43.0,-71.0,45.0")
        expect(results).to include(inside_bounds)
        expect(results).not_to include(outside_bounds)
      end

      it "coerces non-numeric bounds values to zero without raising" do
        # "a".to_f == 0.0 for all four coordinates → degenerate envelope near null island.
        # Systems with nil geometry (or geometry far from 0,0) are not matched.
        expect { PublicWaterSystem.apply_filters(bounds: "a,b,c,d").to_a }.not_to raise_error
      end
    end

    context "left_join_once guard" do
      it "returns correct results without duplicates when multiple join-based filter groups are active" do
        # Both systems have both associations — this ensures multiple LEFT JOINs are actually
        # exercised against real rows, not NULLs from absent records.
        matching = create(:public_water_system)
        create(:violations_summary, public_water_system: matching, groundwater_rule_5yr: 10)
        create(:demographic, public_water_system: matching, poverty_rate: 30.0)

        non_matching = create(:public_water_system)
        create(:violations_summary, public_water_system: non_matching, groundwater_rule_5yr: 10)
        create(:demographic, public_water_system: non_matching, poverty_rate: 5.0)

        results = PublicWaterSystem.apply_filters(
          groundwater_rule_5yr_min: "5",
          poverty_rate_min: "20"
        )

        expect(results).to contain_exactly(matching)
        expect(results.count).to eq(1)
      end
    end
  end
end
