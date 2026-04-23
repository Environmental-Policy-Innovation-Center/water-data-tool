require "rails_helper"
require "rake"

RSpec.describe "db:seed:states rake task" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:seed:states")
  end

  let(:task) { Rake::Task["db:seed:states"] }
  let(:tmp_dir) { Rails.root.join("tmp/seed_states_spec") }

  before do
    task.reenable
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
    allow($stdout).to receive(:print)
    allow($stderr).to receive(:write)

    ENV["ETL_SOURCE_URL"] = "https://example.test/data"
    allow(SeedImport).to receive(:download_data_files).and_return(tmp_dir)

    # Skip the two side-effect steps at the end of the task.
    allow(Rake::Task["cartographic:load"]).to receive(:invoke)
    allow(Etl::PostImportSteps).to receive(:call)

    write_fixture_files
  end

  after do
    FileUtils.rm_rf(tmp_dir)
    ENV.delete("ETL_SOURCE_URL")
  end

  it "aborts when no states are provided" do
    expect { task.invoke }.to raise_error(SystemExit)
  end

  it "upserts a PublicWaterSystem and its ServiceAreaGeometry from the downloaded files" do
    expect {
      task.invoke("VT")
    }.to change(PublicWaterSystem, :count).by(1)
      .and change(ServiceAreaGeometry, :count).by(1)

    pws = PublicWaterSystem.find("VT0000001")
    expect(pws.stusps).to eq("VT")
    expect(pws.pws_name).to eq("Test Water System")

    geom = ServiceAreaGeometry.find_by(pwsid: "VT0000001")
    expect(geom).to be_present
    expect(geom.geom).to be_present
  end

  it "filters out rows that do not belong to the requested states" do
    task.invoke("RI")

    expect(PublicWaterSystem.where(pwsid: "VT0000001")).to be_empty
    expect(ServiceAreaGeometry.where(pwsid: "VT0000001")).to be_empty
  end

  it "updates existing geometries on re-run (ON CONFLICT upsert path)" do
    task.invoke("VT")
    task.reenable
    expect { task.invoke("VT") }.not_to change(ServiceAreaGeometry, :count)
  end

  context "tribal systems" do
    # Tribal pwsids use numeric EPA region prefixes (e.g. "08...") and are never
    # matched by the state-prefix filter. Step 1b collects them via primacy_type in
    # sdwis_viols.csv and loads their epa_sabs rows as a second pass.
    before do
      write_csv("sdwis_viols.csv",
        %w[pwsid gw_sw_code primary_source_code primacy_type],
        ["VT0000001", "GW", "GW", "State"],
        ["08UT0001", "GW", "GW", "Tribal"])

      write_csv("epa_sabs.csv",
        %w[pwsid pws_name primacy_agency pop_cat_5 population_served_count service_connections_count
          service_area_type symbology_field detailed_facility_report ewg_report_link epic_area_mi2],
        ["VT0000001", "Test Water System", "Vermont DEC", "<=500", "250", "100",
          "Residential Area", "System Sourced", "", "", "5.25"],
        ["08UT0001", "Tribal Water System", "Tribal Agency", "<=500", "100", "50",
          "Residential Area", "System Sourced", "", "", "2.5"])
    end

    it "seeds tribal systems alongside state systems" do
      expect { task.invoke("VT") }.to change(PublicWaterSystem, :count).by(2)

      tribal_pws = PublicWaterSystem.find_by(pwsid: "08UT0001")
      expect(tribal_pws).to be_present
      expect(tribal_pws.pws_name).to eq("Tribal Water System")
    end

    it "sets stusps to the numeric prefix for tribal systems" do
      task.invoke("VT")
      expect(PublicWaterSystem.find_by(pwsid: "08UT0001").stusps).to eq("08")
    end

    it "does not seed tribal systems already present via the state filter" do
      # If a tribal system's pwsid happens to start with a state prefix (unusual but
      # possible), the deduplication guard prevents it from being inserted twice.
      write_csv("sdwis_viols.csv",
        %w[pwsid gw_sw_code primary_source_code primacy_type],
        ["VT0000001", "GW", "GW", "Tribal"])

      write_csv("epa_sabs.csv",
        %w[pwsid pws_name primacy_agency pop_cat_5 population_served_count service_connections_count
          service_area_type symbology_field detailed_facility_report ewg_report_link epic_area_mi2],
        ["VT0000001", "Test Water System", "Vermont DEC", "<=500", "250", "100",
          "Residential Area", "System Sourced", "", "", "5.25"])

      expect { task.invoke("VT") }.to change(PublicWaterSystem, :count).by(1)
    end
  end

  private

  # Write a minimal set of fixture CSVs + a GeoJSON so the task can run end-to-end.
  # Only epa_sabs.csv and epa_sabs_geoms.geojson contain a VT row — everything
  # else has headers only, which exercises the empty-group code paths.
  def write_fixture_files
    FileUtils.mkdir_p(tmp_dir)

    write_csv("epa_sabs.csv",
      %w[pwsid pws_name primacy_agency pop_cat_5 population_served_count service_connections_count
        service_area_type symbology_field detailed_facility_report ewg_report_link epic_area_mi2],
      ["VT0000001", "Test Water System", "Vermont DEC", "<=500", "250", "100",
        "Residential Area", "System Sourced", "", "", "5.25"])

    write_csv("sdwis_viols.csv", %w[pwsid gw_sw_code primary_source_code primacy_type])
    write_csv("epa_sabs_xwalk.csv", %w[pwsid total_pop])
    write_csv("xwalk_pct_change_10yr.csv", %w[pwsid total_pop_pct_change_2011_2021])
    write_csv("cejst.csv", %w[pwsid a_int.identified_as_disadvantaged])
    write_csv("ejscreen.csv", %w[pwsid a_int.dwater])
    write_csv("svi.csv", %w[pwsid pw_int_pop.rpl_themes])
    write_csv("cvi.csv", %w[pwsid pw_int_hh.redlining])
    write_csv("national_bwn_highlevel_summary.csv", %w[pwsid total_bwn])
    write_csv("pwsid_funded_highlevel_summary.csv", %w[pwsid times_funded])
    write_csv("pwsid_npdes_usts_rmps_imp.csv", %w[pwsid num_facilities])

    File.write(tmp_dir.join("epa_sabs_geoms.geojson"), {
      type: "FeatureCollection",
      features: [{
        type: "Feature",
        properties: {pwsid: "VT0000001"},
        geometry: {
          type: "Polygon",
          coordinates: [[[-72.6, 44.0], [-72.5, 44.0], [-72.5, 44.1], [-72.6, 44.1], [-72.6, 44.0]]]
        }
      }]
    }.to_json)
  end

  def write_csv(filename, headers, *rows)
    CSV.open(tmp_dir.join(filename), "w") do |csv|
      csv << headers
      rows.each { |r| csv << r }
    end
  end
end
