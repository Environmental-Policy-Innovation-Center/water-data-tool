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

    context "violations filters" do
      it "filters by health_violations_5yr_min" do
        clean = create(:public_water_system)
        dirty = create(:public_water_system)
        create(:violations_summary, public_water_system: clean, health_violations_5yr: 0)
        create(:violations_summary, public_water_system: dirty, health_violations_5yr: 5)

        results = PublicWaterSystem.apply_filters(health_violations_5yr_min: "3")
        expect(results).to include(dirty)
        expect(results).not_to include(clean)
      end

      it "filters by health_violations_5yr_max" do
        few = create(:public_water_system)
        many = create(:public_water_system)
        create(:violations_summary, public_water_system: few, health_violations_5yr: 2)
        create(:violations_summary, public_water_system: many, health_violations_5yr: 10)

        results = PublicWaterSystem.apply_filters(health_violations_5yr_max: "5")
        expect(results).to include(few)
        expect(results).not_to include(many)
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
    end

    context "trend filters" do
      it "filters by population_pct_change_min" do
        declining = create(:public_water_system)
        growing = create(:public_water_system)
        create(:trend_datum, public_water_system: declining, population_pct_change: -5.0)
        create(:trend_datum, public_water_system: growing, population_pct_change: 15.0)

        results = PublicWaterSystem.apply_filters(population_pct_change_min: "10")
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
        create(:violations_summary, public_water_system: matching, health_violations_5yr: 10)
        create(:demographic, public_water_system: matching, poverty_rate: 30.0)

        non_matching = create(:public_water_system)
        create(:violations_summary, public_water_system: non_matching, health_violations_5yr: 10)
        create(:demographic, public_water_system: non_matching, poverty_rate: 5.0)

        results = PublicWaterSystem.apply_filters(
          health_violations_5yr_min: "5",
          poverty_rate_min: "20"
        )

        expect(results).to contain_exactly(matching)
        expect(results.count).to eq(1)
      end
    end
  end
end
